FROM debian:stretch
LABEL maintainer="Axelor <support@axelor.com>"

RUN set -x \
	&& DEBIAN_FRONTEND=noninteractive apt-get update \
	&& DEBIAN_FRONTEND=noninteractive apt-get install -y gnupg dirmngr curl apt-transport-https \
	&& apt-key adv --fetch-keys http://nginx.org/keys/nginx_signing.key \
	&& echo "deb http://nginx.org/packages/debian/ stretch nginx" >> /etc/apt/sources.list \
	&& apt-key adv --fetch-keys https://www.postgresql.org/media/keys/ACCC4CF8.asc \
	&& echo 'deb http://apt.postgresql.org/pub/repos/apt/ stretch-pgdg main' > /etc/apt/sources.list.d/pgdg.list \
	&& apt-key adv --fetch-keys https://deb.nodesource.com/gpgkey/nodesource.gpg.key \
	&& echo 'deb https://deb.nodesource.com/node_8.x stretch main' > /etc/apt/sources.list.d/nodesource.list \
	&& apt-key adv --fetch-keys https://dl.yarnpkg.com/debian/pubkey.gpg \
	&& echo 'deb https://dl.yarnpkg.com/debian/ stable main' > /etc/apt/sources.list.d/yarn.list \
	&& DEBIAN_FRONTEND=noninteractive apt-get update \
	&& DEBIAN_FRONTEND=noninteractive apt-get install -y \
		supervisor gosu postgresql-9.6 postgresql-contrib-9.6 \
		libapr1 nginx git-core nodejs yarn \
		dpkg-dev gcc libapr1-dev libssl-dev make

# update locale
RUN localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8
ENV LANG en_US.utf8

# jdk
ENV JAVA_HOME /opt/java/default
ENV JAVA_OPTS "-Djava.awt.headless=true -XX:+UseConcMarkSweepGC"

RUN set -x \
	&& export JAVA_VERSION="8u172" \
	&& export JAVA_BUILD="b11" \
	&& export JAVA_DL_HASH="a58eab1ec242421181065cdc37240b08" \
	&& export JAVA_MD5="1e4cdd3c3e8c524c02f52981b6ddfc0e" \
	&& export JAVA_PKG="server-jre-${JAVA_VERSION}-linux-x64.tar.gz" \
	&& mkdir -p /opt/java \
	&& cd /opt/java \
	&& curl -L -O -b oraclelicense=a "http://download.oracle.com/otn-pub/java/jdk/${JAVA_VERSION}-${JAVA_BUILD}/${JAVA_DL_HASH}/${JAVA_PKG}" \
	&& echo "$JAVA_MD5 $JAVA_PKG" | md5sum -c - \
	&& tar -xf $JAVA_PKG \
	&& rm -f $JAVA_PKG \
	&& cd - \
	&& export JAVA_DIR=$(ls -1 -d /opt/java/*) \
	&& ln -s $JAVA_DIR /opt/java/latest \
	&& ln -s $JAVA_DIR /opt/java/default \
	&& update-alternatives --install /usr/bin/java java $JAVA_DIR/bin/java 20000 \
	&& update-alternatives --install /usr/bin/javac javac $JAVA_DIR/bin/javac 20000 \
	&& update-alternatives --install /usr/bin/jar jar $JAVA_DIR/bin/jar 20000

# tomcat
ENV TOMCAT_USER tomcat
ENV TOMCAT_GROUP tomcat

ENV CATALINA_HOME /opt/tomcat/default
ENV CATALINA_BASE /var/lib/tomcat

RUN set -x \
	&& addgroup --system "$TOMCAT_GROUP" --quiet \
	&& adduser \
		--system --home "$CATALINA_BASE" --no-create-home \
		--ingroup "$TOMCAT_GROUP" --disabled-password --shell /bin/false "$TOMCAT_USER"

RUN set -x \
	&& export TOMCAT_MAJOR="8" \
	&& export TOMCAT_VERSION="8.5.30" \
	&& export TOMCAT_SHA1="95798f8fe05549f72be84f927a7f8fe6342211a0" \
	&& export TOMCAT_PKG="apache-tomcat-$TOMCAT_VERSION.tar.gz" \
	&& mkdir /opt/tomcat \
	&& cd /opt/tomcat \
	&& curl -L -O "https://www.apache.org/dyn/closer.cgi?action=download&filename=tomcat/tomcat-$TOMCAT_MAJOR/v$TOMCAT_VERSION/bin/$TOMCAT_PKG" \
	&& echo "$TOMCAT_SHA1 $TOMCAT_PKG" | sha1sum -c - \
	&& tar -xf $TOMCAT_PKG \
	&& rm -f $TOMCAT_PKG \
	&& cd - \
	&& export TOMCAT_DIR=$(ls -1 -d /opt/tomcat/*) \
	&& ln -s $TOMCAT_DIR /opt/tomcat/latest \
	&& ln -s $TOMCAT_DIR /opt/tomcat/default \
	&& update-alternatives --install /usr/bin/tomcat tomcat $TOMCAT_DIR/bin/catalina.sh 20000 \
	&& update-alternatives --install /usr/bin/tomcat-digest tomcat-digest $TOMCAT_DIR/bin/digest.sh 20000 \
	&& update-alternatives --install /usr/bin/tomcat-tool-wrapper tomcat-tool-wrapper $TOMCAT_DIR/bin/tool-wrapper.sh 20000 \
	&& chmod 755 $TOMCAT_DIR/bin \
	&& chmod 755 $TOMCAT_DIR/lib \
	&& chmod 755 $TOMCAT_DIR/conf \
	&& chmod 644 $TOMCAT_DIR/bin/* \
	&& chmod 644 $TOMCAT_DIR/lib/* \
	&& chmod 644 $TOMCAT_DIR/conf/* \
	&& chmod 755 $TOMCAT_DIR/bin/*.sh \
	&& chown root:$TOMCAT_GROUP $TOMCAT_DIR/conf/* \
	&& mkdir -p $CATALINA_BASE/conf \
	&& mkdir -p $CATALINA_BASE/temp \
	&& mkdir -p $CATALINA_BASE/webapps \
	&& cp $CATALINA_HOME/conf/tomcat-users.xml $CATALINA_BASE/conf/ \
	&& cp $CATALINA_HOME/conf/logging.properties $CATALINA_BASE/conf/ \
	&& cp $CATALINA_HOME/conf/server.xml $CATALINA_BASE/conf/ \
	&& cp $CATALINA_HOME/conf/web.xml $CATALINA_BASE/conf/ \
	&& sed -i 's/directory="logs"/directory="\/var\/log\/tomcat"/g' $CATALINA_BASE/conf/server.xml \
	&& sed -i 's/\${catalina\.base}\/logs/\/var\/log\/tomcat/g' $CATALINA_BASE/conf/logging.properties \
	&& mkdir -p /var/log/tomcat \
	&& chown -R $TOMCAT_USER:$TOMCAT_GROUP $CATALINA_BASE \
	&& chown -R $TOMCAT_USER:$TOMCAT_GROUP /var/log/tomcat

# tomcat-native lib path
ENV TOMCAT_NATIVE_LIBDIR $CATALINA_HOME/native-jni-lib
ENV LD_LIBRARY_PATH ${LD_LIBRARY_PATH:+$LD_LIBRARY_PATH:}$TOMCAT_NATIVE_LIBDIR

# build tomcat-native
RUN set -x \
	&& export NATIVE_BUILD_DIR="$(mktemp -d)" \
	&& tar -xvf $CATALINA_HOME/bin/tomcat-native.tar.gz -C "$NATIVE_BUILD_DIR" --strip-components=1 \
	&& cd $NATIVE_BUILD_DIR/native \
	&& ./configure \
		--build="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)" \
		--libdir="$TOMCAT_NATIVE_LIBDIR" \
		--prefix="$CATALINA_HOME" \
		--with-apr="$(which apr-1-config)" \
		--with-java-home="$JAVA_HOME" \
		--with-ssl=yes \
	&& make -j "$(nproc)" \
	&& make install \
	&& rm -rf $NATIVE_BUILD_DIR \
	&& rm $CATALINA_HOME/bin/tomcat-native.tar.gz

# clean up
RUN set -x \
	&& DEBIAN_FRONTEND=noninteractive apt-get purge -y --autoremove dpkg-dev gcc libapr1-dev libssl-dev make \
	&& rm -rf /var/lib/apt/lists/*

# postgres
ENV POSTGRES_USER axelor
ENV POSTGRES_PASSWORD axelor
ENV POSTGRES_DB axelor

ENV PATH $PATH:/usr/lib/postgresql/9.6/bin
ENV PGDATA /var/lib/postgresql/9.6/main

RUN set -x \
	&& echo "host all all all md5" >> /etc/postgresql/9.6/main/pg_hba.conf \
	&& echo "listen_addresses='localhost'" >> /etc/postgresql/9.6/main/postgresql.conf

VOLUME /var/lib/tomcat
VOLUME /var/lib/postgresql
VOLUME /var/log/tomcat
VOLUME /var/log/postgresql

EXPOSE 80
EXPOSE 8080
EXPOSE 5432

COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh && mkdir /docker-entrypoint-initdb.d

ENTRYPOINT ["docker-entrypoint.sh"]

CMD ["start"]

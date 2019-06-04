FROM adoptopenjdk/openjdk8:alpine
MAINTAINER Atlassian Confluence

ENV RUN_USER            daemon
ENV RUN_GROUP           daemon

# https://confluence.atlassian.com/doc/confluence-home-and-other-important-directories-590259707.html
ENV CONFLUENCE_HOME          /var/atlassian/application-data/confluence
ENV CONFLUENCE_INSTALL_DIR   /opt/atlassian/confluence

VOLUME ["${CONFLUENCE_HOME}"]

# Expose HTTP and Synchrony ports
EXPOSE 8090
EXPOSE 8091

WORKDIR $CONFLUENCE_HOME

CMD ["/entrypoint.sh", "-fg"]
ENTRYPOINT ["/sbin/tini", "--"]

RUN apk add --no-cache ca-certificates wget curl openssh bash procps openssl perl ttf-dejavu tini

COPY entrypoint.sh              /entrypoint.sh
COPY confluenceCrack.jar        ${CONFLUENCE_INSTALL_DIR}/confluenceCrack.jar
COPY mysql-connector-java-5.1.42.jar        ${CONFLUENCE_INSTALL_DIR}/confluence/WEB-INF/lib/mysql-connector-java-5.1.42.jar

RUN chmod a+x /entrypoint.sh \
    && chmod a+x ${CONFLUENCE_INSTALL_DIR}/confluenceCrack.jar

ARG CONFLUENCE_VERSION=6.15.4
ARG DOWNLOAD_URL=http://www.atlassian.com/software/confluence/downloads/binary/atlassian-confluence-${CONFLUENCE_VERSION}.tar.gz

COPY . /tmp

RUN mkdir -p                             ${CONFLUENCE_INSTALL_DIR} \
    && curl -L --silent                  ${DOWNLOAD_URL} | tar -xz --strip-components=1 -C "$CONFLUENCE_INSTALL_DIR" \
    && chown -R ${RUN_USER}:${RUN_GROUP} ${CONFLUENCE_INSTALL_DIR}/ \
    && sed -i -e 's/-Xms\([0-9]\+[kmg]\) -Xmx\([0-9]\+[kmg]\)/-Xms\${JVM_MINIMUM_MEMORY:=\1} -Xmx\${JVM_MAXIMUM_MEMORY:=\2} \${JVM_SUPPORT_RECOMMENDED_ARGS} -Dconfluence.home=\${CONFLUENCE_HOME} -javaagent:${CONFLUENCE_INSTALL_DIR}\/confluenceCrack.jar/g' ${CONFLUENCE_INSTALL_DIR}/bin/setenv.sh \
    && sed -i -e 's/port="8090"/port="8090" secure="${catalinaConnectorSecure}" scheme="${catalinaConnectorScheme}" proxyName="${catalinaConnectorProxyName}" proxyPort="${catalinaConnectorProxyPort}"/' ${CONFLUENCE_INSTALL_DIR}/conf/server.xml  \
    && sed -i -e 's/Context path=""/Context path="${catalinaContextPath}"/' ${CONFLUENCE_INSTALL_DIR}/conf/server.xml

# Workaround for AdoptOpenJDK fontconfig bug
RUN ln -s /usr/lib/libfontconfig.so.1 /usr/lib/libfontconfig.so \
    && ln -s /lib/libuuid.so.1 /usr/lib/libuuid.so.1 \
    && ln -s /lib/libc.musl-x86_64.so.1 /usr/lib/libc.musl-x86_64.so.1
ENV LD_LIBRARY_PATH /usr/lib

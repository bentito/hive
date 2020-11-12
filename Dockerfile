FROM fedora:28 as build

RUN yum -y update && yum clean all

RUN yum -y install \
        java-1.8.0-openjdk maven \
    && yum clean all \
    && rm -rf /var/cache/yum

RUN mkdir /build
COPY .git /build/.git
COPY accumulo-handler /build/accumulo-handler
COPY beeline /build/beeline
COPY bin /build/bin
COPY binary-package-licenses /build/binary-package-licenses
COPY checkstyle /build/checkstyle
COPY cli /build/cli
COPY common /build/common
COPY conf /build/conf
COPY contrib /build/contrib
COPY data /build/data
COPY dev-support /build/dev-support
COPY docs /build/docs
COPY druid-handler /build/druid-handler
COPY hbase-handler /build/hbase-handler
COPY hcatalog /build/hcatalog
COPY hplsql /build/hplsql
COPY itests /build/itests
COPY jdbc-handler /build/jdbc-handler
COPY jdbc /build/jdbc
COPY lib /build/lib
COPY llap-client /build/llap-client
COPY llap-common /build/llap-common
COPY llap-ext-client /build/llap-ext-client
COPY llap-server /build/llap-server
COPY llap-tez /build/llap-tez
COPY metastore /build/metastore
COPY packaging /build/packaging
COPY ql /build/ql
COPY serde /build/serde
COPY service-rpc /build/service-rpc
COPY service /build/service
COPY shims /build/shims
COPY spark-client /build/spark-client
COPY storage-api /build/storage-api
COPY testutils /build/testutils
COPY vector-code-gen /build/vector-code-gen
COPY classification /build/classification
COPY streaming /build/streaming
COPY kryo-registrator /build/kryo-registrator
COPY standalone-metastore /build/standalone-metastore
COPY upgrade-acid /build/upgrade-acid
COPY pom.xml /build/pom.xml

WORKDIR /build

RUN mvn -B -e -T 1C -DskipTests=true -DfailIfNoTests=false -Dtest=false clean package -Pdist
RUN mvn dependency:copy -Dartifact=org.postgresql:postgresql:42.2.16:jar -DoutputDirectory=/build/postgresql-jdbc.jar

FROM quay.io/btofel/metering-hadoop:metering-rel-rel-3.3.0

ENV HIVE_VERSION=3.1.2
ENV HIVE_HOME=/opt/hive
ENV PATH=$HIVE_HOME/bin:$PATH

RUN mkdir -p /opt
WORKDIR /opt

USER root

RUN yum install --setopt=skip_missing_names_on_install=False -y \
        openssl \
#        mysql-connector-java \
    && yum clean all \
    && rm -rf /var/cache/yum

COPY --from=build /build/packaging/target/apache-hive-$HIVE_VERSION-bin/apache-hive-$HIVE_VERSION-bin $HIVE_HOME
COPY --from=build /build/postgresql-jdbc.jar /usr/share/java/postgresql-jdbc.jar
WORKDIR $HIVE_HOME

ENV HADOOP_CLASSPATH $HIVE_HOME/hcatalog/share/hcatalog/*:${HADOOP_CLASSPATH}
ENV JAVA_HOME=/etc/alternatives/jre

# Configure Hadoop AWS Jars to be available to hive
RUN ln -s ${HADOOP_HOME}/share/hadoop/tools/lib/*aws* $HIVE_HOME/lib
# Configure MySQL connector jar to be available to hive
RUN ln -s /usr/share/java/mysql-connector-java.jar "$HIVE_HOME/lib/mysql-connector-java.jar"
# Configure Postgesql connector jar to be available to hive
RUN ln -s /usr/share/java/postgresql-jdbc.jar "$HIVE_HOME/lib/postgresql-jdbc.jar"

# https://docs.oracle.com/javase/7/docs/technotes/guides/net/properties.html
# Java caches dns results forever, don't cache dns results forever:
RUN sed -i '/networkaddress.cache.ttl/d' $JAVA_HOME/lib/security/java.security
RUN sed -i '/networkaddress.cache.negative.ttl/d' $JAVA_HOME/lib/security/java.security
RUN echo 'networkaddress.cache.ttl=0' >> $JAVA_HOME/lib/security/java.security
RUN echo 'networkaddress.cache.negative.ttl=0' >> $JAVA_HOME/lib/security/java.security

# imagebuilder expects the directory to be created before VOLUME
RUN mkdir -p /var/lib/hive /.beeline $HOME/.beeline
# to allow running as non-root
RUN chown -R 1002:0 $HIVE_HOME $HADOOP_HOME /var/lib/hive /.beeline $HOME/.beeline /etc/passwd $JAVA_HOME/lib/security/cacerts && \
    chmod -R 774 $HIVE_HOME $HADOOP_HOME /var/lib/hive /.beeline $HOME/.beeline /etc/passwd $JAVA_HOME/lib/security/cacerts

# fix guava library conflict
RUN rm /opt/hive/lib/guava-19.0.jar
RUN cp /opt/hadoop/share/hadoop/common/lib/guava-27.0-jre.jar /opt/hive/lib/

VOLUME /var/lib/hive

USER 1002

LABEL io.k8s.display-name="OpenShift Hive" \
      io.k8s.description="This is an image used by the Metering Operator to install and run Apache Hive." \
      summary="This is an image used by the Metering Operator to install and run Apache Hive." \
      io.openshift.tags="openshift" \
      maintainer="metering-team@redhat.com"

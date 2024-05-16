FROM broadinstitute/gatk:latest

ARG VERSION=${VERSION}

RUN apt-get update
RUN apt-get install -y python3.10 && ln -s /usr/bin/python3.10 /usr/bin/python
COPY README* *build.d /build.d/
RUN bash -c 'for i in $(ls /build.d/*.sh 2>/dev/null | sort) ; do source $i ; done'

RUN apt-get update

RUN apt-get install -y git

WORKDIR /home/gradle/

RUN git clone https://github.com/ssadedin/SavvySuite.git \
&& cd SavvySuite && ./gradlew shadowJar

ENV CLASSPATH="/home/gradle/gatk-4.2.6.1/gatk-package-4.2.6.1-local.jar:/home/gradle/SavvySuite/build/libs/SavvySuite-all.jar:${CLASSPATH}"

CMD []

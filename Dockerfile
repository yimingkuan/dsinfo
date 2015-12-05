FROM alpine:3.2

ENV DOCKER_VERSION 1.9.1

RUN apk update && \
    apk fetch procps sysstat dmidecode && \
    apk add procps sysstat dmidecode

ADD https://get.docker.com/builds/Linux/x86_64/docker-${DOCKER_VERSION} /usr/local/bin/docker
RUN chmod +x /usr/local/bin/docker

ADD https://raw.githubusercontent.com/docker/docker/master/contrib/check-config.sh /check-config.sh
RUN chmod +x /check-config.sh

ADD dsinfo.sh /dsinfo.sh
RUN chmod +x /dsinfo.sh

ENV TAG latest

CMD /dsinfo.sh -b 2>/dev/null

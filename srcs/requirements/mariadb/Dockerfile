FROM debian:12-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
 && apt-get install -y --no-install-recommends mariadb-server ca-certificates tzdata \
 && rm -rf /var/lib/apt/lists/*

COPY ./conf/50-server.cnf /etc/mysql/mariadb.conf.d/50-server.cnf

COPY ./tools/script.sh /script.sh

EXPOSE 3306
ENTRYPOINT ["/bin/sh","/script.sh"]


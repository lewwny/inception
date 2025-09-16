FROM debian:12-slim

RUN apt-get update -y
RUN apt-get install mariadb-server -y

COPY ./tools/50-server.cnd /etc/mysql/mariadb.conf.d/

COPY ./tools/script.sh /

CMD [ "/script.sh" ]


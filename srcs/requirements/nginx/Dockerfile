FROM debian:12-slim

RUN apt-get update 
RUN apt-get install -y nginx
RUN apt-get install openssl -y

COPY ./tools/script.sh /

CMD [ "/script.sh" ]

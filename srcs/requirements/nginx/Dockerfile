FROM debian:12-slim

RUN apt-get update -y

RUN apt-get install -y nginx
RUN apt-get install openssl -y

RUN mkdir -p /etc/nginx/ssl

RUN openssl req -x509 -nodes -out /etc/nginx/ssl/inception.crt -keyout /etc/nginx/ssl/inception.key -subj "/C=FR/ST=IDF/L=Paris/O=42/OU=42/CN=lengarci.42.fr/UID=lengarci"

RUN mkdir -p /var/run/nginx

COPY conf/nginx.conf /etc/nginx/nginx.conf


CMD ["nginx", "-g", "daemon off;"]

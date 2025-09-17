FROM debian:12-slim

ENV DEBIAN_FRONTEND=noninteractive
WORKDIR /var/www/html

RUN apt-get update && apt-get install -y \
		ca-certificates curl wget tar \
		php php-fpm php-mysql php-xml php-mbstring php-gd php-zip php-intl php-curl \
		mariadb-client \
 && rm -rf /var/lib/apt/lists/*

COPY ./tools/script.sh /script.sh
RUN chmod +x /script.sh

EXPOSE 9000
CMD ["/script.sh"]
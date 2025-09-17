FROM debian:12-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update -y && \
    apt-get install -y --no-install-recommends \
      php-fpm php-mysql php-cli curl ca-certificates less \
      default-mysql-client \
    && rm -rf /var/lib/apt/lists/*

# Installer wp-cli
RUN curl -fsSL https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar -o /usr/local/bin/wp \
    && chmod +x /usr/local/bin/wp

# Préparer dossier runtime php-fpm
RUN mkdir -p /run/php

# Script d’entrypoint
COPY ./tools/script.sh /script.sh
RUN chmod +x /script.sh

# WordPress vivra ici (monte ton volume compose sur /var/www/html)
RUN mkdir -p /var/www/html && chown -R www-data:www-data /var/www

# Expose FPM (si tu utilises Nginx en frontal)
EXPOSE 9000

CMD ["/script.sh"]


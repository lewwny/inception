FROM debian:12-slim

RUN apt-get update -y
RUN apt-get upgrade -y

RUN apt-get -y install wget
RUN apt-get install -y php8.2\
	php-fpm\
	php-mysql\
	mariadb-client

RUN wget https://fr.wordpress.org/wordpress-6.8-fr_FR.tar.gz -P /var/www
RUN cd /var/www && tar -xvzf wordpress-6.8-fr_FR.tar.gz && rm wordpress-6.8-fr_FR.tar.gz

COPY ./conf/www.conf /etc/php/8.2/fpm/pool.d/www.conf

RUN chown -R root:root /var/www/wordpress

RUN wget https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar

RUN chmod +x wp-cli.phar
RUN mv wp-cli.phar /usr/local/bin/wp

COPY ./tools/script.sh /
RUN chmod +x /script.sh

CMD ["/script.sh"]

#CMD ["/usr/sbin/php-fpm8.2", "-F"]

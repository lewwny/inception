#!/bin/sh

sleep 10

if [ ! -f /var/www/wordpress/wp-config.php ]; then
	wp config create --allow-root \
		--dbname=${SQL_DATABASE} \
		--dbuser=${SQL_USER} \
		--dbpass=${SQL_PASSWORD} \
		--dbhost=mariadb:3306 \
		--path='/var/www/wordpress'
	wp core install --allow-root \
		--url=${WP_URL} \
		--title=${WP_TITLE} \
		--admin_user=${WP_ADMIN_USER} \
		--admin_password=${WP_ADMIN_PASSWORD} \
		--admin_email=${WP_ADMIN_EMAIL} \
		--path='/var/www/wordpress'
	wp user create --allow-root \
		${WP_USER} ${WP_USER_EMAIL} \
		--user_pass=${WP_USER_PASSWORD} \
		--role=author \
		--path='/var/www/wordpress'
fi


if command -v php-fpm8.2 >/dev/null 2>&1; then
  exec /usr/sbin/php-fpm8.2 -F
else
  echo "php-fpm introuvable. Installe php-fpm (et php-mysql)." >&2
  exit 1
fi


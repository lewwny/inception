#!/usr/bin/env bash
set -euo pipefail

# --- Vars & defaults ---
DOCROOT="/var/www/html"
WPCONFIG="${DOCROOT}/wp-config.php"

# Requis (provenant de ton .env)
: "${WP_DB_HOST:?WP_DB_HOST manquant}"
: "${WP_DB_NAME:?WP_DB_NAME manquant}"
: "${WP_DB_USER:?WP_DB_USER manquant}"
: "${WP_DB_PASSWORD:?WP_DB_PASSWORD manquant}"

# Optionnels (du .env présenté)
: "${DOMAIN_NAME:=http://localhost}"
: "${WP_TITLE:=MySite}"
: "${WP_ADMIN_USR:=admin}"
: "${WP_ADMIN_PWD:=admin}"
: "${WP_ADMIN_EMAIL:=admin@example.com}"
: "${WP_USR:=}"
: "${WP_EMAIL:=}"
: "${WP_PWD:=}"
: "${WP_DEBUG:=0}"
: "${WP_TABLE_PREFIX:=wp_}"

# --- PHP-FPM en TCP:9000 (Nginx -> FastCGI) ---
if grep -q "^listen = " /etc/php/*/fpm/pool.d/www.conf; then
	sed -ri "s|^listen = .*|listen = 0.0.0.0:9000|" /etc/php/*/fpm/pool.d/www.conf
fi
mkdir -p /run/php

# --- Télécharger WordPress si absent ---
if [ ! -e "${DOCROOT}/wp-includes/version.php" ]; then
	echo "==> Téléchargement de WordPress…"
	TMP="$(mktemp -d)"
	curl -fsSL https://wordpress.org/latest.tar.gz -o "${TMP}/wp.tgz"
	tar -xzf "${TMP}/wp.tgz" -C "${TMP}"
	cp -R "${TMP}/wordpress/." "${DOCROOT}/"
	rm -rf "${TMP}"
fi

# --- Génération de wp-config.php si manquant ---
if [ ! -f "${WPCONFIG}" ]; then
	echo "==> Génération wp-config.php"
	SALTS="$(curl -fsSL https://api.wordpress.org/secret-key/1.1/salt/ || true)"
	if [ -z "${SALTS}" ]; then
		SALTS=$'define("AUTH_KEY","changeme");\ndefine("SECURE_AUTH_KEY","changeme");\ndefine("LOGGED_IN_KEY","changeme");\ndefine("NONCE_KEY","changeme");\ndefine("AUTH_SALT","changeme");\ndefine("SECURE_AUTH_SALT","changeme");\ndefine("LOGGED_IN_SALT","changeme");\ndefine("NONCE_SALT","changeme");'
	fi

	cat > "${WPCONFIG}" <<PHP
<?php
define('DB_NAME', '${WP_DB_NAME}');
define('DB_USER', '${WP_DB_USER}');
define('DB_PASSWORD', '${WP_DB_PASSWORD}');
define('DB_HOST', '${WP_DB_HOST}');
define('DB_CHARSET', 'utf8mb4');
define('DB_COLLATE', '');

${SALTS}

\$table_prefix = '${WP_TABLE_PREFIX}';
define('WP_DEBUG', ${WP_DEBUG} ? true : false);

# Force HTTPS admin si le domaine est https
PHP;
	if echo "${DOMAIN_NAME}" | grep -qi '^https://'; then
		cat >> "${WPCONFIG}" <<PHP
define('FORCE_SSL_ADMIN', true);
if (strpos(\$_SERVER['HTTP_X_FORWARDED_PROTO'] ?? '', 'https') !== false) {
	\$_SERVER['HTTPS'] = 'on';
}
PHP
	fi

	# Optionnel: fixer WP_HOME / WP_SITEURL (utile derrière proxy)
	cat >> "${WPCONFIG}" <<PHP
define('WP_HOME', '${DOMAIN_NAME}');
define('WP_SITEURL', '${DOMAIN_NAME}');
if (!defined('ABSPATH')) define('ABSPATH', __DIR__ . '/');
require_once ABSPATH . 'wp-settings.php';
PHP
fi

# --- Attendre que MariaDB soit dispo ---
echo "==> Attente MariaDB (${WP_DB_HOST})…"
TRIES=60
until mysqladmin ping -h "${WP_DB_HOST%:*}" -P "${WP_DB_HOST##*:}" --silent >/dev/null 2>&1 || [ $TRIES -le 0 ]; do
	TRIES=$((TRIES-1))
	sleep 2
done
if [ $TRIES -le 0 ]; then
	echo "ERREUR: MariaDB indisponible sur ${WP_DB_HOST}" >&2
	exit 1
fi

# S’assurer que la base existe (au cas où)
mysql -h "${WP_DB_HOST%:*}" -P "${WP_DB_HOST##*:}" -u"${WP_DB_USER}" -p"${WP_DB_PASSWORD}" \
	-e "CREATE DATABASE IF NOT EXISTS \`${WP_DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" >/dev/null 2>&1 || true

# --- Installer WP via WP-CLI si non installé ---
# Installer WP-CLI localement
if ! command -v wp >/dev/null 2>&1; then
	curl -fsSL https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar -o /usr/local/bin/wp
	chmod +x /usr/local/bin/wp
fi

# Déterminer si WP est déjà installé
if ! wp core is-installed --path="${DOCROOT}" --allow-root >/dev/null 2>&1; then
	echo "==> Installation WordPress"
	wp core install \
		--url="${DOMAIN_NAME}" \
		--title="${WP_TITLE}" \
		--admin_user="${WP_ADMIN_USR}" \
		--admin_password="${WP_ADMIN_PWD}" \
		--admin_email="${WP_ADMIN_EMAIL}" \
		--path="${DOCROOT}" --skip-email --allow-root

	# Créer un utilisateur secondaire si fourni
	if [ -n "${WP_USR}" ] && [ -n "${WP_EMAIL}" ] && [ -n "${WP_PWD}" ]; then
		wp user create "${WP_USR}" "${WP_EMAIL}" --user_pass="${WP_PWD}" --role=author \
			--path="${DOCROOT}" --allow-root || true
	fi
fi

# Permissions propres
chown -R www-data:www-data "${DOCROOT}"

# --- Lancer php-fpm en foreground ---
exec php-fpm -F
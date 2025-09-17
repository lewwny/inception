#!/bin/bash
set -euo pipefail

# === Vars attendues (depuis .env / compose) ===
: "${DOMAIN_NAME:=http://localhost}"   # utilisé pour l'install WP si besoin
: "${WP_TITLE:=MySite}"
: "${WP_ADMIN_USR:=admin}"
: "${WP_ADMIN_PWD:=adminpass}"
: "${WP_ADMIN_EMAIL:=admin@example.com}"
: "${WP_USR:=author}"
: "${WP_EMAIL:=author@example.com}"
: "${WP_PWD:=authorpass}"

# DB côté WordPress (doit matcher MariaDB)
: "${WP_DB_HOST:=mariadb:3306}"
: "${WP_DB_NAME:?Missing WP_DB_NAME}"
: "${WP_DB_USER:?Missing WP_DB_USER}"
: "${WP_DB_PASSWORD:?Missing WP_DB_PASSWORD}"

# --- Préparer répertoires ---
mkdir -p /var/www/html /run/php
chown -R www-data:www-data /var/www/html

cd /var/www/html

# --- Télécharger WordPress si nécessaire ---
if [ ! -f wp-includes/version.php ]; then
  echo "Downloading WordPress..."
  wp core download --allow-root
fi

# --- Créer wp-config.php si absent ---
if [ ! -f wp-config.php ]; then
  echo "Creating wp-config.php..."
  wp config create \
    --dbname="$WP_DB_NAME" \
    --dbuser="$WP_DB_USER" \
    --dbpass="$WP_DB_PASSWORD" \
    --dbhost="$WP_DB_HOST" \
    --dbprefix=wp_ \
    --skip-check \
    --allow-root
fi

# --- Attendre la DB (DNS + port ouverts) ---
echo -n "Waiting for DB at ${WP_DB_HOST}..."
DB_HOSTNAME="$(echo "$WP_DB_HOST" | cut -d: -f1)"
DB_PORT="$(echo "$WP_DB_HOST" | cut -sd: -f2)"; DB_PORT="${DB_PORT:-3306}"

for i in {1..60}; do
  if getent hosts "$DB_HOSTNAME" >/dev/null 2>&1 && \
     (echo >/dev/tcp/"$DB_HOSTNAME"/"$DB_PORT") >/dev/null 2>&1; then
    echo " ok"
    break
  fi
  echo -n "."
  sleep 1
done

# --- Vérifier la connexion DB ---
set +e
wp db check --allow-root >/dev/null 2>&1
DB_OK=$?
set -e
if [ "$DB_OK" -ne 0 ]; then
  echo "ERROR: cannot connect to DB at $WP_DB_HOST with provided credentials."
  exit 1
fi

# --- Installer WP si pas encore installé ---
if ! wp core is-installed --allow-root; then
  echo "Installing WordPress..."
  wp core install \
    --url="${DOMAIN_NAME%/}/" \
    --title="$WP_TITLE" \
    --admin_user="$WP_ADMIN_USR" \
    --admin_password="$WP_ADMIN_PWD" \
    --admin_email="$WP_ADMIN_EMAIL" \
    --skip-email \
    --allow-root

  # Créer un auteur optionnel
  wp user create "$WP_USR" "$WP_EMAIL" --role=author --user_pass="$WP_PWD" --allow-root || true

  # Exemple de thème & plugin
  wp theme install astra --activate --allow-root || true
  wp plugin install redis-cache --activate --allow-root || true
  wp plugin update --all --allow-root || true

  # Activer object cache Redis si tu as un service redis
  if getent hosts redis >/dev/null 2>&1; then
    wp redis enable --allow-root || true
  fi
fi

# --- Configurer php-fpm 8.2 à écouter sur TCP 9000 (pour Nginx) ---
if [ -f /etc/php/8.2/fpm/pool.d/www.conf ]; then
  sed -ri 's|^;?listen\s*=.*$|listen = 0.0.0.0:9000|' /etc/php/8.2/fpm/pool.d/www.conf
fi

# --- Lancer php-fpm en foreground (PID 1) ---
PHP_FPM_BIN="$(command -v php-fpm || command -v php-fpm8.2 || true)"
if [ -z "$PHP_FPM_BIN" ]; then
  echo "php-fpm introuvable"
  exit 1
fi

exec "$PHP_FPM_BIN" -F


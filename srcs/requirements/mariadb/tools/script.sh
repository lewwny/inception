#!/bin/bash
set -euo pipefail

# Vars attendues : db1_name, db1_user, db1_pwd
: "${db1_name:?Missing db1_name}"
: "${db1_user:?Missing db1_user}"
: "${db1_pwd:?Missing db1_pwd}"

# 1) Préparer les répertoires requis
mkdir -p /run/mysqld /var/log/mysql
chown -R mysql:mysql /run/mysqld /var/log/mysql
chmod 775 /run/mysqld

# 2) Si le datadir est vide, initialiser (utile si tu ne relies pas un volume déjà peuplé)
if [ -z "$(ls -A /var/lib/mysql || true)" ]; then
  echo "Initializing database..."
  mariadb-install-db --user=mysql --datadir=/var/lib/mysql > /dev/null
fi

# 3) Démarrage temporaire en background pour config initiale
echo "Starting MariaDB (bootstrap)..."
mysqld --user=mysql --datadir=/var/lib/mysql \
       --pid-file=/run/mysqld/mysqld.pid \
       --socket=/run/mysqld/mysqld.sock \
       --bind-address=0.0.0.0 \
       --log-error=/var/log/mysql/error.log &
BOOT_PID=$!

# 4) Attendre que ça réponde
echo -n "Waiting for MariaDB to be ready"
for i in {1..60}; do
  if mysqladmin ping --socket=/run/mysqld/mysqld.sock --silent; then
    echo " - ready."
    break
  fi
  echo -n "."
  sleep 1
done

# 5) Configuration initiale (DB, user, root password)
cat > /tmp/db1.sql <<SQL
CREATE DATABASE IF NOT EXISTS \`${db1_name}\`;
CREATE USER IF NOT EXISTS '${db1_user}'@'%' IDENTIFIED BY '${db1_pwd}';
GRANT ALL PRIVILEGES ON \`${db1_name}\`.* TO '${db1_user}'@'%';
ALTER USER 'root'@'localhost' IDENTIFIED BY '12345';
FLUSH PRIVILEGES;
SQL

# Important : on passe par le socket tant que c’est local
mysql --socket=/run/mysqld/mysqld.sock -uroot < /tmp/db1.sql

# 6) Arrêt propre du bootstrap
mysqladmin --socket=/run/mysqld/mysqld.sock -uroot -p'12345' shutdown

wait "$BOOT_PID" || true

# 7) Démarrage final en foreground (PID 1)
echo "Starting MariaDB in foreground..."
exec mysqld --user=mysql --datadir=/var/lib/mysql \
            --pid-file=/run/mysqld/mysqld.pid \
            --socket=/run/mysqld/mysqld.sock \
            --bind-address=0.0.0.0 \
            --log-error=/var/log/mysql/error.log


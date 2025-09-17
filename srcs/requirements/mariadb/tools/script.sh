#!/bin/sh
set -e

# Chemins par défaut (doivent correspondre à ta conf)
DATADIR=/var/lib/mysql
SOCKET=/run/mysqld/mysqld.sock

# 0) Pré-requis runtime
mkdir -p "$(dirname "$SOCKET")"
chown -R mysql:mysql "$(dirname "$SOCKET")" "$DATADIR"

# 1) Init du datadir si nécessaire (premier lancement)
if [ ! -d "$DATADIR/mysql" ]; then
  echo "[init] Initialising MariaDB datadir…"
  mariadb-install-db --user=mysql --datadir="$DATADIR" --auth-root-authentication-method=normal
fi

# 2) Démarre le serveur en arrière-plan (socket locale)
echo "[boot] Starting mysqld_safe…"
/usr/bin/mysqld_safe --datadir="$DATADIR" --socket="$SOCKET" &
PID=$!

# 3) Attends que le serveur réponde
echo "[wait] Waiting for MariaDB…"
i=0
until mysqladmin --protocol=socket -S "$SOCKET" ping >/dev/null 2>&1; do
  i=$((i+1)); [ $i -gt 60 ] && echo "Timeout: mysqld ne démarre pas." && exit 1
  sleep 1
done
echo "[ok] MariaDB up."

# 4) Configuration initiale (idempotente)
#    NB: root n’a PAS de mdp juste après l’init ci-dessus.
mysql --protocol=socket -S "$SOCKET" <<SQL
CREATE DATABASE IF NOT EXISTS \`${SQL_DATABASE}\` CHARACTER SET ${SQL_CHARSET:-utf8mb4} COLLATE ${SQL_COLLATE:-utf8mb4_unicode_ci};
CREATE USER IF NOT EXISTS \`${SQL_USER}\`@'%' IDENTIFIED BY '${SQL_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${SQL_DATABASE}\`.* TO \`${SQL_USER}\`@'%';
ALTER USER 'root'@'localhost' IDENTIFIED BY '${SQL_ROOT_PASSWORD}';
FLUSH PRIVILEGES;
SQL

# 5) Redémarre proprement en avant-plan (pour Docker)
mysqladmin -u root -p"${SQL_ROOT_PASSWORD}" --protocol=socket -S "$SOCKET" shutdown
echo "[run] Launching mysqld_safe in foreground…"
exec /usr/bin/mysqld_safe --datadir="$DATADIR" --socket="$SOCKET"


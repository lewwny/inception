#!/bin/sh
set -e

DATADIR=/var/lib/mysql
SOCKET=/run/mysqld/mysqld.sock

mkdir -p "$(dirname "$SOCKET")"
chown -R mysql:mysql "$(dirname "$SOCKET")" "$DATADIR"

if [ ! -d "$DATADIR/mysql" ]; then
  mariadb-install-db --user=mysql --datadir="$DATADIR" --auth-root-authentication-method=normal
fi

/usr/bin/mysqld_safe --datadir="$DATADIR" --socket="$SOCKET" &
i=0; until mysqladmin --protocol=socket -S "$SOCKET" ping >/dev/null 2>&1; do
  i=$((i+1)); [ $i -gt 60 ] && echo "Timeout" && exit 1; sleep 1; done

try_nopass() { mysql --protocol=socket -S "$SOCKET" -uroot -e 'SELECT 1' >/dev/null 2>&1; }
try_pass()   { mysql --protocol=socket -S "$SOCKET" -uroot -p"$SQL_ROOT_PASSWORD" -e 'SELECT 1' >/dev/null 2>&1; }

if try_nopass; then
  mysql --protocol=socket -S "$SOCKET" -uroot <<SQL
CREATE DATABASE IF NOT EXISTS \`${SQL_DATABASE}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS \`${SQL_USER}\`@'%' IDENTIFIED BY '${SQL_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${SQL_DATABASE}\`.* TO \`${SQL_USER}\`@'%';
ALTER USER 'root'@'localhost' IDENTIFIED BY '${SQL_ROOT_PASSWORD}';
FLUSH PRIVILEGES;
SQL
elif try_pass; then
  mysql --protocol=socket -S "$SOCKET" -uroot -p"$SQL_ROOT_PASSWORD" <<SQL
CREATE DATABASE IF NOT EXISTS \`${SQL_DATABASE}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS \`${SQL_USER}\`@'%' IDENTIFIED BY '${SQL_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${SQL_DATABASE}\`.* TO \`${SQL_USER}\`@'%';
FLUSH PRIVILEGES;
SQL
else
  echo "Échec d’auth root (ni sans mdp, ni avec SQL_ROOT_PASSWORD). Vérifie SQL_ROOT_PASSWORD et le datadir." >&2
  exit 1
fi

mysqladmin -uroot -p"$SQL_ROOT_PASSWORD" --protocol=socket -S "$SOCKET" shutdown
exec /usr/bin/mysqld_safe --datadir="$DATADIR" --socket="$SOCKET"


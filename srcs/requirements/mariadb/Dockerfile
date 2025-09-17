FROM debian:12-slim

ENV DEBIAN_FRONTEND=noninteractive

# Paquets
RUN apt-get update \
 && apt-get install -y --no-install-recommends mariadb-server ca-certificates tzdata \
 && rm -rf /var/lib/apt/lists/*

# Conf serveur MariaDB (doit matcher socket/datadir du script)
COPY ./conf/50-server.cnf /etc/mysql/mariadb.conf.d/50-server.cnf

# Script d’entrée
COPY ./tools/script.sh /script.sh
# Anti-CRLF + exécutable
RUN sed -i 's/\r$//' /script.sh && chmod +x /script.sh

EXPOSE 3306
# ENTRYPOINT explicite pour éviter les soucis d’exec format / shebang
ENTRYPOINT ["/bin/sh","/script.sh"]


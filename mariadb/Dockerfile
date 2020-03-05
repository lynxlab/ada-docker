# mariadb dockerfile
FROM mariadb:10.4
LABEL maintainer="g.consorti@lynxlab.com"

ARG ADA_OR_WISP

# utf8 everywhere
COPY utf8.cnf /etc/mysql/mariadb.conf.d/
COPY $ADA_OR_WISP-empty-common.sql /docker-entrypoint-initdb.d/00-empty-common.sql
COPY init.sh /docker-entrypoint-initdb.d/99-init.sh
RUN chmod -R 644 /etc/mysql/mariadb.conf.d/

#!/bin/bash

## SET THE PASSWORD PROVIDED IN ${ADA_ADMIN_PASSWORD} FOR USER 'adminAda'

echo "UPDATE utente SET password=SHA1(\"${ADA_ADMIN_PASSWORD}\") WHERE id_utente=1 AND password=\"\";" | \
mysql -ss -hlocalhost -u${MYSQL_USER} -p${MYSQL_PASSWORD} ${MYSQL_DATABASE}


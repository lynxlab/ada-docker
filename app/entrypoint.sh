#!/bin/bash
# set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Extract the protocol (includes trailing "://").
PARSED_PROTO="$(echo $HTTP_ROOT_DIR | sed -nr 's,^(.*://).*,\1,p')"
# Remove the protocol from the URL.
PARSED_URL="$(echo ${HTTP_ROOT_DIR/$PARSED_PROTO/})"
# Extract the user (includes trailing "@").
PARSED_USER="$(echo $PARSED_URL | sed -nr 's,^(.*@).*,\1,p')"
# Remove the user from the URL.
PARSED_URL="$(echo ${PARSED_URL/$PARSED_USER/})"
# Extract the port (includes leading ":").
PARSED_PORT="$(echo $PARSED_URL | sed -nr 's,.*(:[0-9]+).*,\1,p')"
# Remove the port from the URL.
PARSED_URL="$(echo ${PARSED_URL/$PARSED_PORT/})"
# Extract the path (includes leading "/" or ":").
PARSED_PATH="$(echo $PARSED_URL | sed -nr 's,[^/:]*([/:].*),\1,p')"
# Remove the path from the URL.
PARSED_HOST="$(echo ${PARSED_URL/$PARSED_PATH/})"

## put here filenames to be imported in the common db and each provider db if multiprovider eq 0
# inBothIfNonMulti=(ada_gdpr_policy.sql ada_login_module.sql)
inBothIfNonMulti=()
## put here filenames to be imported in the common db if multiprovider eq 1
inCommonIfMulti=(ada_gdpr_policy.sql ada_login_module.sql)
## put here filenames to be ALWAYS imported in the common db
inCommon=(ada_apps_module.sql ada_secretquestion_module.sql ada_impexport_module.sql)
## store current working dir
basepath=$(pwd)

function importSQL() {
    dbname=$1
    filename=$2
    echo -n "$dbname "
    RESULT=0
    mysql -ss -h${MYSQL_HOST} -u${MYSQL_USER} -p${MYSQL_PASSWORD} --default_character_set utf8 $dbname < $filename >/dev/null || RESULT=$?
    if [[ $RESULT -eq 1 ]]; then
      # echo
      echo -ne "${RED}WARNING!${NC} MySQL returned an error, this could be normal if you're redeploying or restaring the container"
    fi
}

## usage: file_env VAR [DEFAULT]
##    ie: file_env 'XYZ_DB_PASSWORD' 'example'
## (will allow for "$XYZ_DB_PASSWORD_FILE" to fill in the value of
##  "$XYZ_DB_PASSWORD" from a file, especially for Docker's secrets feature)
## courtesy of maria db entrypoint file: https://github.com/docker-library/mariadb/blob/master/10.4/docker-entrypoint.sh
file_env() {
	local var="$1"
	local fileVar="${var}_FILE"
	local def="${2:-}"
	if [ "${!var:-}" ] && [ "${!fileVar:-}" ]; then
		echo "${RED}Both $var and $fileVar are set (but are exclusive)${NC}"
        exit -3
	fi
	local val="$def"
	if [ "${!var:-}" ]; then
		val="${!var}"
	elif [ "${!fileVar:-}" ]; then
		val="$(< "${!fileVar}")"
	fi
	export "$var"="$val"
	unset "$fileVar"
}

## courtesy of: https://stackoverflow.com/a/13777424
## will echo 0 if IP is valid
function valid_ip() {
    local  ip=$1
    local  stat=1

    if [[ ! -z "$ip" &&  $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        OIFS=$IFS
        IFS='.'
        ip=($ip)
        IFS=$OIFS
        [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 \
            && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
        stat=$?
    fi
    echo $stat
}

if [[ ${MULTIPROVIDER} -eq 0 && $(valid_ip ${PARSED_HOST}) -eq 0 ]]; then
    echo -e "${RED}Trying to use an IP with non multiprovider, this is not going to work! ** Aborted **${NC}"
    exit -2
fi

if [ -f "index.php" ]; then
    firstinstall=0
else
    firstinstall=1
fi

if [ ! -z "${GIT_URL}" ]; then
    file_env 'GIT_PASSWORD'
    repourl=$(echo ${GIT_URL/'${GIT_PASSWORD}'/$GIT_PASSWORD})
    unset GIT_URL
else
    if [ ! -z "${ADA_OR_WISP}" ] && [ ${ADA_OR_WISP} == "ada" ]; then
        repourl="https://github.com/lynxlab/ada.git"
    elif [ ! -z "${ADA_OR_WISP}" ] && [ ${ADA_OR_WISP} == "wisp" ]; then
        repourl="https://github.com/lynxlab/ada-wisp.git"
    else
        echo Please set a REPOSITORY_URL or ADA_OR_WISP env var to either 'ada' or 'wisp'.
        exit -1
    fi
fi

## perform initial configuration steps

## set the apache ServerName in its config file
echo -e "${GREEN}Apache ServerName will be ${PARSED_HOST}${NC}"
sed -i -e "s/\${PARSED_HOST}/${PARSED_HOST}/" /etc/apache2/sites-available/000-default.conf

## clone or update the git repository
if [ ! -z $repourl ]; then
    if [[ $firstinstall -eq 1 ]]; then
        echo "cloning from ${repourl/$GIT_PASSWORD/'${GIT_PASSWORD}'}"
        git clone $repourl .
        if [ ! -z "${GIT_BRANCH}" ]; then
            git checkout ${GIT_BRANCH}
        fi
        ## copy ada/wisp base config files
        cp config_path_DEFAULT.inc.php config_path.inc.php
        cp config/config_install_DEFAULT.inc.php config/config_install.inc.php
    else
        echo "pulling git repo"
        git pull
    fi
fi

## create common database modules tables
if [[ -d "modules" ]]; then
    ## find with sorting by filename magic, courtesy of: https://unix.stackexchange.com/a/13609
    find ./modules -name "*.sql" -type f | awk -vFS=/ -vOFS=/ '{ print $NF,$0 }' | sort -n -t / | cut -f2- -d/ | while read sqlfile; do
        # echo $sqlfile
        dirname=$(dirname $sqlfile)
        if [[ $sqlfile != *"/db/"* ]]; then
            modulename=$(echo $dirname | cut -c 3-)
        else
            modulename=$(dirname $dirname | cut -c 3-)
        fi
        # import the SQL even if the module is disabled to let the module be enabled
        # in the future without rebuilding the whole database
        if [[
            # files containig the "menu" word are always imported in the commonDB
            $sqlfile == *"menu"* ||
            # files in the inCommon array are always imported in the commonDB
            " ${inCommon[@]} " =~ " $(basename $sqlfile) " ||
            # files in the inCommonIfMulti are imported in the commonDB only if MULTIPROVIDER is 1
            (${MULTIPROVIDER} -eq 1 && " ${inCommonIfMulti[@]} " =~ " $(basename $sqlfile) ") ||
            # files in the inBothIfNonMulti are imported in the commonDB only if MULTIPROVIDER is 0
            (${MULTIPROVIDER} -eq 0 && " ${inBothIfNonMulti[@]} " =~ " $(basename $sqlfile) ")
        ]]; then
            echo -n "importing $sqlfile in "
            importSQL ${MYSQL_DATABASE} $sqlfile
            echo ""
        fi
    done
fi
## done create common database modules tables

## create providers dirs and databases
providers=($(echo "${PROVIDERS_LIST}" | tr -d ' ' | tr ',' '\n'))
pointers=($(echo "${PROVIDERS_POINTERS}" | tr -d ' '| tr ',' '\n'))
for provider in "${providers[@]}"; do
    let "n=(`echo ${providers[@]} | tr -s " " "\n" | grep -n "${provider}" | cut -d":" -f 1`)-1"
    if [[ ! -z ${pointers[n]} ]]; then
        pointer=${pointers[n]}
    else
        pointer=${provider}
    fi
    # check if database exists
    DB_EXISTS=0
    mysql -h${MYSQL_HOST} -u${MYSQL_USER} -p${MYSQL_PASSWORD} ${provider}_provider -e exit >/dev/null 2>&1 || DB_EXISTS=$?
    if [ $DB_EXISTS != 0 ]; then
        echo ${provider}_provider database does not exists
        ## create the provider database
        echo "create database \`${provider}_provider\`; grant all privileges on \`${provider}_provider\`.* to '${MYSQL_USER}'@'%'; flush privileges;" |
            mysql -h${MYSQL_HOST} -uroot -p${MYSQL_ROOT_PASSWORD} ${MYSQL_DATABASE}
        ## import the tables structure
        mysql -h${MYSQL_HOST} -u${MYSQL_USER} -p${MYSQL_PASSWORD} ${provider}_provider < ./db/ada_provider_empty.sql
        ## copy the administrator user in the provider
        echo "INSERT INTO \`${provider}_provider\`.utente SELECT * FROM ${MYSQL_DATABASE}.utente WHERE id_utente=1; INSERT INTO amministratore_sistema (id_utente_amministratore_sist) VALUES (1);" |
            mysql -h${MYSQL_HOST} -u${MYSQL_USER} -p${MYSQL_PASSWORD} ${provider}_provider
        ## create the provider in the common db and associate the admin user to it
        echo "INSERT INTO tester(nome,puntatore) VALUES ('${provider}', '${pointer}'); INSERT INTO utente_tester(id_utente, id_tester) VALUES (1, LAST_INSERT_ID());" |
            mysql -h${MYSQL_HOST} -u${MYSQL_USER} -p${MYSQL_PASSWORD} ${MYSQL_DATABASE}
    else
        echo ${provider}_provider database access granted
    fi
    ## create provider database modules tables
    if [[ -d 'modules' ]]; then
        ## find with sorting by filename magic, courtesy of: https://unix.stackexchange.com/a/13609
        find ./modules -name "*.sql" -type f | awk -vFS=/ -vOFS=/ '{ print $NF,$0 }' | sort -n -t / | cut -f2- -d/ | while read sqlfile; do
            dirname=$(dirname $sqlfile)
            if [[ $sqlfile != *"/db/"* ]]; then
                modulename=$(echo $dirname | cut -c 3-)
            else
                modulename=$(dirname $dirname | cut -c 3-)
            fi
            # import the SQL even if the module is disabeld to let the module be enabled
            # in the future without rebuilding the whole database
            if [[ $sqlfile != *"menu"* && ! " ${inCommon[@]} " =~ " $(basename $sqlfile) " && ! ( ${MULTIPROVIDER} -eq 1 && " ${inCommonIfMulti[@]} " =~ " $(basename $sqlfile) " ) ]]; then
                echo -n "importing $sqlfile in "
                importSQL ${provider}_provider $sqlfile
                echo ""
            fi
        done
    fi
    ## done create provider database modules tables

    if [ ! -d ./clients/${pointer} ]; then
        mkdir -p -v ./clients/${pointer}
    fi

    ## build provider config files
    if [[ ${MULTIPROVIDER} -eq 0 ]]; then
        ## check if $PARSED_HOST has a 3rd level
        dotcount=$(echo ${PARSED_HOST} | grep -o "\." | wc -l)
        if [[ $dotcount -ge 2 ]]; then
            ## PARSED_HOST has 2 or more dots, i.e. is xxxx.domain.ext or yyy.xxxx.domain.ext, etc
            ## substitute everything up to the fisrt '.' with provider in lower case
            SERVERALIAS=$(echo "$provider" | tr '[:upper:]' '[:lower:]')$(echo $PARSED_HOST | sed -nr 's,[^/.]*([/.].*),\1,p')
        else
            ## PARSED_HOST has 1 or 0 dots, i.e. is domain.ext, or domain
            ## prepend provider in lower case to the parsed host
            SERVERALIAS=$(echo "$provider" | tr '[:upper:]' '[:lower:]').$PARSED_HOST
        fi
        PROV_HTTP=$PARSED_PROTO$SERVERALIAS

        ## configure apache serveralias
        export SERVERALIAS=$SERVERALIAS
        ## note: grep exits with 0 if the string is FOUND
        TEXTFOUND=0
        cat /etc/apache2/sites-available/000-default.conf | grep -iq ${SERVERALIAS} || TEXTFOUND=$?
        if [ $TEXTFOUND != 0 ]; then
            ## append a ServerAlias after ServerName in apache vhost
            echo -e "Adding Apache ServerAlias ${GREEN}${SERVERALIAS}${NC}"
            sed -i.$(date +%F) -e '/ServerName/a\' -e '    ServerAlias '$SERVERALIAS /etc/apache2/sites-available/000-default.conf
        fi
        unset SERVERALIAS
    else
        ## if multiprovider is 1, the provider url is the passed host
        PROV_HTTP=$PARSED_PROTO$PARSED_HOST
    fi

    if [[ ! -z $PARSED_PORT ]]; then
        PROV_HTTP=$PROV_HTTP$PARSED_PORT
    fi
    if [[ ! -z $PARSED_PATH ]]; then
        PROV_HTTP=$PROV_HTTP$PARSED_PATH
    fi

    export ASISPROVIDER=$provider
    export UPPERPROVIDER=$(echo "$pointer" | tr '[:lower:]' '[:upper:]')
    export PROV_HTTP=$PROV_HTTP

    echo -e "URL for ${GREEN}${ASISPROVIDER}${NC} will be ${GREEN}${PROV_HTTP}${NC}"

    # do the variable substitution on each file of the clients config dir
    find clients_DEFAULT/docker-templates/ -type f -print0 | while read -d $'\0' fullpath; do
        filename=${fullpath//clients_DEFAULT\/docker-templates\//}
        if [ ! -f ./clients/$pointer/$filename ]; then
            echo Generating ./clients/$pointer/$filename
            envsubst '$PROV_HTTP,$UPPERPROVIDER,$ASISPROVIDER' < $fullpath > ./clients/$pointer/$filename
        fi
    done

    unset ASISPROVIDER
    unset UPPERPROVIDER
    unset PROV_HTTP

done

## look for composer.json files and run proper action
find . -name "composer.json" -type f -print0 | while read -d $'\0' fullpath; do
    if [[ $fullpath != *"vendor"* && $fullpath != *"dompdf"* ]]; then
        dirname=$(dirname $fullpath)
        cd $basepath/$dirname
        if [ -d "vendor" ]; then
            composeraction="update"
        else
            composeraction="install"
        fi

        if [[ $composeraction == "install" || ( ${COMPOSER_UPDATE_ONRESTART} -eq 1 && $composeraction == "update" ) ]]; then
            echo $composeraction $dirname
            composer -q -n $composeraction --no-dev
            # exit if composer fails
            if [[ ! $? -eq 0 ]]; then
                exit $?
            fi
        fi
    fi
done
cd $basepath

## copy/enable modules
if [ -d "modules" ]; then
    cd modules
    disableArr=($(echo "${MODULES_DISABLE}" | tr ',' '\n'))
    find . -name "*DEFAULT*" -type f -print0 | while read -d $'\0' fullpath; do
        dirname=$(dirname $fullpath)
        modulename=$(dirname $dirname | cut -c 3-)
        if [[ ! " ${disableArr[@]} " =~ " ${modulename} " ]]; then
            destfile=${fullpath//_DEFAULT/}
            if [ ! -f $destfile ]; then
                cp -v $fullpath ${fullpath//_DEFAULT/}
            else
                echo "$destfile already exists, skipped"
            fi
        else
            echo "skipped $modulename as requested"
        fi
    done
fi
cd $basepath

## enforce https with a .htaccess if needed
if [[ $PARSED_PROTO =~ "https" ]]; then
   cat <<EOF >> .htaccess
# ensure https
RewriteEngine On
RewriteCond %{HTTP:X-Forwarded-Proto} !https
RewriteCond %{HTTPS} off
RewriteRule ^ https://%{HTTP_HOST}%{REQUEST_URI} [L,R=301]
EOF
fi
## lastly, recursively chown the dir
chown -R www-data:www-data .

## do not propagate these to PHP
unset MYSQL_ROOT_PASSWORD
unset MODULES_DISABLE
unset GIT_PASSWORD
unset GIT_PASSWORD_FILE
unset COMPOSE_PROJECT_NAME
unset COMPOSER_UPDATE_ONRESTART

exec "$@"

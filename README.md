# ADA docker installation HOWTO

1. clone this repository ```git clone https://github.com/lynxlab/ada-docker.git```
2. copy the provided ```env.template``` to ```.env```
3. edit the .env file using your own desired values
4. start the build process using the provided ```docker-compose.yml``` file: ```docker-compose [--build] -d```
5. have some coffee, wait the build process, and check ```docker-compose logs -tf app``` when the apache process is running (might take a while, something like 10 minutes)
6. visit ${HTTP_ROOT_DIR} in your browser and login with user adminAda, password ${ADA_ADMIN_PASSWORD} (see below notes for env vars)

## Containers built by the docker-compose

After running docker-compose, you should have 4 containers running and 3 volumes created:

### Containers

| Container Name | Description |
|-----|-----|
| **mariadb** | database engine used to store application data |
| **redis** |  key/value store to keep php sessions data |
| **app** |  application core container |
| **pma** | phpMyAdmin application reachable on port 9090 |

### Volumes

| Volume Name | Used to |
|-----|-----|
| **db-data** | store mariadb files |
| **redis-data** | store redis files |
| **app** | store the whole application itself |

## Supported Environment variables

| Variable Name | Description | Default value (if any) | Optional |
| ------------- |----|---|---|
| COMPOSE_PROJECT_NAME | docker-compose project name, to avoid typing '-p yourprojectname' at every docker-compose command | adastack | YES |
| GIT_URL | url of the git repo to be cloned. If empty or not set, will clone the default public git repo | https://github.com/lynxlab/ada.git | NO |
| GIT_BRANCH | is the branch to be checked out after clone. If empty or not set, will use the master branch | master | YES |
| GIT_PASSWORD | repository password if needed. does not need a docker secret, and will set the password in the environment | - | YES |
| GIT_PASSWORD_FILE | needs a docker secret to be set up in the app service, and must point to the file of the secret inside the container | - | YES |
| | USE EITHER GIT_PASSORD OR GIT_PASSWORD_FILE | | |
| COMPOSER_UPDATE_ONRESTART |php composer configuration, set to 1 if you wish to run composer update on all of the dependencies when restarting the container |0 | YES |
| MYSQL_ROOT_PASSWORD | password of the root MySQL user. Does not need a docker secret, and will set the password in the environment | - | NO |
| MYSQL_ROOT_PASSWORD_FILE | needs a docker secret to be set up in the app and mariadb services, and must point to the file of the secret inside the container | - | NO |
| | USE EITHER MYSQL_ROOT_PASSWORD OR MYSQL_ROOT_PASSWORD_FILE | | |
| MYSQL_DATABASE | is the ADA common database name, if you need to change it go to the docker-compose file This is here just for reference and to show the default value | ada_common | NO |
| MYSQL_USER | is the ADA database user name for all the application dbs, if you need to change it go to the docker-compose file. This is here just for reference and to show the default value| ada_DBUSER | NO |
| MYSQL_PASSWORD | is the password for the MYSQL_USER. Setting it in a secret is not supported. | - | NO |
| MYSQL_HOST | is the hostname that the app service will use to make mysql connections to the mariadb service | mariadb | NO |
| ADA_ADMIN_PASSWORD | is the ADA password for the 'adminAda' predefined user, if you need to change it go to the docker-compose file. This is here just for reference and to show the default value | adminada | NO |
| MULTIPROVIDER | tells ADA if you are setting up a multipirovider or non multipirovider (aka multitenant) installation. Use 0 for non multipirovider, 1 for multiprovider (the default) | 1 | YES |
| HTTP_ROOT_DIR | must point the the URL of your installation<br/>If non multipirovider, must be the url to access all common static contents: img, js, css etc. so if non multipirovider pls set it to something like: http[s]://ada.lynxlab.com:8888 then the setup will substitute the 3rd level name with the provider name (for each provider)<br/>**IMPORTANT NOTE** docker-compose.yml file will expose port 8888, so if your URL has a port other than 8888 please edit the app service in the docker-compose file accordingly | - | NO |
| PROVIDERS_LIST | is a comma separated list of providers that must be created at startup | client0, client1 | NO |
| PROVIDERS_POINTERS | is a comma separated list of provider's pointers that must be linked to each provider at startup | client0ptr, client1ptr | NO |
| DEFAULT_PROVIDER | is the default provider | client0 | NO |
| DEFAULT_PROVIDER_DB | is the ADA default provider databse name, if you need to change it go to the docker-compose file. This is here just for reference and to show the default value | ${DEFAULT_PROVIDER}_provider | NO |
| MODULES_DISABLE | is a comma separated list of modules that you do not want to enable (e.g.: secretquestion,code_man) | secretquestion,code_man | - | YES |
| PORTAL_NAME | is the page title to be used:<br/>- if not set, ADA_OR_WISP will be used<br/>- if multipirovider will be the same for every provider<br/>- if non ,ultiprovider the provider name in uppercase will be appended to the string | - | YES |
| ADA_ADMIN_MAIL_ADDRESS | is the application admin email address | - | YES |
| ADA_ADMIN_MAIL_ADDRESS is the application noreply email address | - | YES |
| REDIS_URL | is the URL to reach the redis server, for storing session data | tcp://redis:6379 | NO |

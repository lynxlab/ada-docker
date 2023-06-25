#!/bin/bash
# wait-for-mysql.sh

set -e

cmd="$@"

timeout=1800     # wait 30 minutes and commit suicide
initialsleep=60 # 5.5 minutes, empirically set
loopsleep=15     # 15 seconds of sleep while looping

function timeout_monitor() {
   sleep $timeout
   kill -9 "$1"
}

function mysqlcheck() {
    MYSQL_CONNECT=0
    mysql -ss -h${MYSQL_HOST} -u${MYSQL_USER} -p${MYSQL_PASSWORD}  ${MYSQL_DATABASE} -e exit > /dev/null 2>&1 || MYSQL_CONNECT=$?
    echo $MYSQL_CONNECT
}

# start the timeout monitor in background and pass the PID:
timeout_monitor "$$" &
timeout_monitor_pid=$!

if [[ $(mysqlcheck) != 0 ]]; then
  ## initial sleep of 5 minutes, set empirically
  echo "Waiting $initialsleep seconds for MySQL real connection, initial sleeping..."
  sleep $initialsleep
  until [[ $(mysqlcheck) == 0 ]]; do
    echo "MySQL is unavailable - sleeping"
    sleep $loopsleep
  done
fi

echo "MySQL is up - executing command"
# kill timeout monitor when terminating:
kill -9 "$timeout_monitor_pid"
exec $cmd


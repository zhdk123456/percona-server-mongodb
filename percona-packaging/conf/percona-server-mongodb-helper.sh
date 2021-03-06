#!/bin/bash
#
PATH="${PATH}:/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin"
#
touch /var/run/mongod.pid
touch /var/log/@@LOGDIR@@/mongod.{stdout,stderr}
chown mongod:mongod /var/run/mongod.pid
chown -R mongod:mongod /var/log/@@LOGDIR@@
#
KTHP=/sys/kernel/mm/transparent_hugepage
#
[ -z "${CONF}" ] && CONF=/etc/mongod.conf
#
print_error(){
  echo " * Error disabling Transparent Huge pages, exiting"
  exit 1
}
#
. /etc/@@LOCATION@@/mongod
DAEMON_OPTS="${OPTIONS}"
#
# Handle NUMA access to CPUs (SERVER-3574)
# This verifies the existence of numactl as well as testing that the command works
NUMACTL_ARGS="--interleave=all"
if which numactl >/dev/null 2>/dev/null && numactl $NUMACTL_ARGS ls / >/dev/null 2>/dev/null
then
    NUMACTL="numactl $NUMACTL_ARGS"
    DAEMON_OPTS=${DAEMON_OPTS:-"--config $CONF"}
else
    NUMACTL=""
    DAEMON_OPTS=${DAEMON_OPTS:-"--config $CONF"}
fi
#
# checking if storageEngine is defined twice (in default and config file)
defaults=$(echo "${OPTIONS}" | egrep -o 'storageEngine.*' | tr -d '[[:blank:]]' | awk -F'=' '{print $NF}' 2>/dev/null)
config=$(egrep -o '^[[:blank:]]+engine.*' ${CONF} | tr -d '[[:blank:]]' | awk -F':' '{print $NF}' 2>/dev/null)
#
if [ -n "${defaults}" ] && [ -n "${config}" ]; then # engine is set in 2 places
  if [ "${defaults}" ==  "${config}" ]; then # it's OK
    echo " * Warning, engine is set both in defaults file and mongod.conf!"
  else
    echo " * Error, different engines are set in the same time!"
    exit 1
  fi
fi
# disable THP
fgrep '[always]' ${KTHP}/enabled  > /dev/null 2>&1 && (echo never > ${KTHP}/enabled 2> /dev/null || print_error) || true
fgrep '[always]' ${KTHP}/defrag   > /dev/null 2>&1 && (echo never > ${KTHP}/defrag  2> /dev/null || print_error) || true

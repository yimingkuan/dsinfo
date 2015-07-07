#!/usr/bin/env sh

# dsinfo.sh
#
# Collect Docker/System information

if [ "$(id -u)" != "0" ]; then
  printf "This script must be ran as root or sudo!\n"
  exit 1
fi

# working directory
TD=/tmp/dsinfo
TR=$TD/dsinfo.txt

# number of log lines to collect
LOGLINES=5000

# OS
OSNAME=$(cat /etc/*release | grep "^NAME" | cut -d'"' -f2)

bline() {
  echo "" >> ${TR}
}


header() {
  printf "%0.s=" $(seq 1 25) >> ${TR}
  echo "" >> ${TR}
  echo $* >> ${TR}
  printf "%0.s=" $(seq 1 25) >> ${TR}
  bline
}


execute() {
  bline
  command=$*
  echo ${command} >> ${TR}
  printf "%0.s~" $(seq 1 ${#command}) >> ${TR}
  bline

  ex=$(echo "${command}" | cut -d" " -f1)
  if command -v "${ex}" >/dev/null 2>&1; then
    eval "${command}" >> ${TR}
  else
    echo "'${ex}' command not found" >> ${TR}
  fi
}


set_opts() {
  dopts=$(cat $* | grep "^OPTIONS")

  if [ -z "${dopts}" ]; then
    echo "OPTIONS='-D'" >> $*
  else
    sed -i "s/^OPTIONS='/OPTIONS='-D /g" $*
  fi
}


set_dopts() {
  dopts=$(cat $* | grep "^DOCKER_OPTS")

  if [ -z "${dopts}" ]; then
    echo 'DOCKER_OPTS="-D"' >> $*
  else
    sed -i 's/^DOCKER_OPTS="/DOCKER_OPTS="-D /g' $*
  fi
}


# begin
echo
echo "*************************** dsinfo.sh ***************************"
echo
echo "Beginning data collection ..."
echo

# check debug
# Note: Boot2Docker has debug enabled by default.
dbug=$(docker info | grep "Debug mode (server)" | grep -o "true")

if [ "${dbug}" != "true" ]; then
  echo
  echo "The Docker daemon is not running with debug logging enabled!"
  echo ""
  read -p "Enable debug logging and restart the Docker daemon? [y/n]: " answer
  case ${answer} in

    [yY] | [yY][Ee][Ss] )
      case ${OSNAME} in
        "CentOS Linux")
          set_opts '/etc/sysconfig/docker'
          systemctl restart docker
          ;;
        "Debian GNU/Linux")
          set_dopts '/etc/default/docker'
          service docker restart
          ;;
        "NAME=Fedora")
          set_opts '/etc/sysconfig/docker'
          systemctl restart docker
          ;;
        "Red Hat Enterprise Linux Server")
          set_opts '/etc/sysconfig/docker'
          systemctl restart docker
          ;;
        "Ubuntu")
          set_dopts '/etc/default/docker'
          service docker restart
          ;;
        *)
          echo
          echo "Can't determine the location of the Docker config file."
          echo "Enable debug logging manually and restart the Docker daemon"
          exit 1
          ;;
      esac

      echo
      echo "Debug logging enabled and daemon restarted."
      echo "Run the 'dsinf.sh' data collection script again when you're ready ..."
      exit 1
      ;;
    *)
      echo
      echo "Continuing without enabling debug logging ..."
      ;;
  esac
fi
if [ -d ${TD} ]; then
  rm -r ${TD}*
fi

# tmp directories
mkdir -p ${TD}/dtr/generatedConfigs
mkdir -p ${TD}/dtr/logs
mkdir -p ${TD}/inspect
mkdir -p ${TD}/logs


# initialize
header 'Docker/System Information'
bline
echo $(date) >> ${TR}
bline

# docker
# ~~~~~~
header 'Docker Info'

execute 'docker version'
execute 'docker info'
execute 'docker images --no-trunc'
execute 'docker ps -a -n 20 --no-trunc'

if command -v bash >/dev/null 2>&1; then
  bline
  echo "check-config.sh" >> ${TR}
  echo "~~~~~~~~~~~~~~~" >> ${TR}
  curl -sSL https://raw.githubusercontent.com/docker/docker/master/contrib/check-config.sh | sudo bash >> ${TR}
fi

# daemon logs - config file
case ${OSNAME} in
  "NAME=Boot2Docker")
    tail -n ${LOGLINES} /var/log/docker.log > ${TD}/daemon.log
    cp /var/log/boot2docker.log ${TD}/boot2docker.log
    ;;
  "CentOS Linux")
    tail -n ${LOGLINES} /var/log/messages | grep docker > ${TD}/daemon.log
    cp /etc/sysconfig/docker ${TD}/docker.cfg
    ;;
  "Debian GNU/Linux")
    tail -n ${LOGLINES} /var/log/daemon.log | grep docker > ${TD}/daemon.log
    cp /etc/default/docker ${TD}/docker.cfg
    ;;
  "NAME=Fedora")
    journalctl -n ${LOGLINES} -u docker.service > ${TD}/daemon.log
    cp /etc/sysconfig/docker ${TD}/docker.cfg
    ;;
  "Red Hat Enterprise Linux Server")
    tail -n ${LOGLINES} /var/log/messages | grep docker > ${TD}/daemon.log
    cp /etc/sysconfig/docker ${TD}/docker.cfg
    ;;
  "Ubuntu")
    tail -n ${LOGLINES} /var/log/upstart/docker.log > ${TD}/daemon.log
    cp /etc/default/docker ${TD}/docker.cfg
    ;;
esac

# inspect, logs
for container in $(docker ps -a -n 20 -q); do
  docker logs ${container} | tail -n ${LOGLINES} >> ${TD}/logs/${container}.log
  docker inspect ${container} >> ${TD}/inspect/${container}.txt
done

# dtr
# ~~~
DTR=/usr/local/etc/dtr
if [ -d ${DTR} ]; then
  cp ${DTR}/*.yml ${TD}/dtr
  cp ${DTR}/generatedConfigs/*.conf ${TD}/dtr/generatedConfigs
  cp ${DTR}/generatedConfigs/*.yml ${TD}/dtr/generatedConfigs

  for log in ${DTR}/logs/*
  do
    logbase=$(basename ${log})
    tail -n ${LOGLINES} ${log} > ${TD}/dtr/logs/${logbase}.log
  done
else
  bline
  header 'Docker Trusted Registry'
  bline
  echo "The '/usr/local/etc/dtr' directory does not exist." >> ${TR}
fi

# system
# ~~~~~~
bline
bline
header 'System Info'
bline

execute 'hostname'
execute 'cat /etc/*release'
execute 'cat /proc/version'
execute 'cat /proc/cpuinfo'
execute 'cat /proc/meminfo'
execute 'cat /proc/cgroups'
execute 'cat /proc/self/cgroup'
execute 'df -h'
execute 'mount'
execute 'ifconfig'
execute 'ps aux | grep docker'
execute 'netstat -npl'
execute 'sestatus'
execute 'dmidecode'

# tar
cd /tmp
tar -zcf /tmp/dsinfo.tar.gz dsinfo

# instructions
echo "
Data collection complete ...

Notes
=====

This script created the directories:
  - /tmp/dsinfo
  - /tmp/dsinfo/dtr
  - /tmp/dsinfo/dtr/generatedConfigs
  - /tmp/dsinfo/dtr/logs
  - /tmp/dsinfo/inspect
  - /tmp/dsinfo/logs

This script collected the following:
  - Docker daemon configuration and logs
  - Inspect results and logs from the last 20 containers
  - Miscellaneous system information (Output to: /tmp/dsinfo/report.md)

All files/directories were compressed to: /tmp/dsinfo.tar.gz

---------------------------------------------------------------------------------

*** Important ***

Before sharing the dsinfo.tar.gz archive, review all collected files for
private information and edit/delete if necessary.

If you do edit/remove any files, recreate the tar file with the following command:

  sudo tar -zcf /tmp/dsinfo.tar.gz /tmp/dsinfo
"

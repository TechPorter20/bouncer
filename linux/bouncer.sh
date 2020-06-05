#!/bin/bash
#source /etc/profile

# =================== Custom config start ===================
#export JAVA_HOME=/usr/java8_64/jre   #replace system default JDK 替换系统默认JDK

BOUNCER_MEM_MB=${BOUNCER_MEM_MB:-512}    #默认内存512M

# =================== Custom config end ===================


cd `dirname "$0"`/..
BOUNCER_HOME=`pwd`

export PATH=$PATH:$JAVA_HOME/bin
export CLASSPATH=.:$JAVA_HOME/lib/tools.jar:$JAVA_HOME/lib/dt.jar

#BOUNCER_HOME=${BOUNCER_HOME:-/opt/bouncer}
BOUNCER_CONF=${BOUNCER_CONF:-bouncer.conf}

#修改Garbage Collection垃圾回收器  -XX:+UseG1GC -XX:MaxGCPauseMillis=200    默认 内存10G 无使用 引发2020-05-13T18:48:15.424+0800: 11431.492: [GC (Allocation Failure) [PSYoungGen: 513536K->85481K(599040K)] 513536K->97369K(1968640K), 0.5781144 secs] [Times: user=6.35 sys=0.00, real=0.58 secs]
BOUNCER_OPTS_DEF="-verbose:gc -XX:+PrintGCDetails -XX:+PrintGCDateStamps -XX:+PrintGCTimeStamps -showversion -XX:+PrintCommandLineFlags -XX:-PrintFlagsFinal -XX:+UseG1GC -XX:MaxGCPauseMillis=200"
BOUNCER_OPTS="${BOUNCER_OPTS:-${BOUNCER_OPTS_DEF}}"
BOUNCER_CLASSPATH=$(echo $BOUNCER_HOME/lib/*.jar | tr ' ' ':')
#
do_reload () {
  touch ${BOUNCER_HOME}/conf/${BOUNCER_CONF}
}
do_keygen () {
  # org.javastack.bouncer.KeyGenerator <bits> <days> <CommonName> <filename-without-extension>
  local bits="${1}" days="${2}" cn="${3}" filebase="${4}"
  if [ "$filebase" = "" ]; then
    echo "$0 keygen <bits> <days> <CommonName> <filename-without-extension>"
    echo "Sample:"
    echo "$0 keygen 2048 365 host1.acme.com host1"
    exit 1;
  fi
  cd "${BOUNCER_HOME}/keys/"
  $JAVA_HOME/bin/java \
    -cp "${BOUNCER_CLASSPATH}" \
    org.javastack.bouncer.KeyGenerator $bits $days $cn $filebase
  #chmod go-rwx "${filebase}.key"
  ls -al "${BOUNCER_HOME}/keys/${filebase}."*
}
do_run () {
  cd ${BOUNCER_HOME}
  $JAVA_HOME/bin/java -Dprogram.name=bouncer ${BOUNCER_OPTS} -Xmx${BOUNCER_MEM_MB}m \
    -cp "${BOUNCER_HOME}/conf/:${BOUNCER_HOME}/keys/:${BOUNCER_CLASSPATH}" \
    org.javastack.bouncer.Bouncer ${BOUNCER_CONF}
}
do_start () {
  cd ${BOUNCER_HOME}
  echo "$(date +%Y-%m-%d) $(date +%H:%-M:%-S) Starting" >> ${BOUNCER_HOME}/log/bouncer.bootstrap
  nohup $JAVA_HOME/bin/java -Dprogram.name=bouncer ${BOUNCER_OPTS} -Xmx${BOUNCER_MEM_MB}m \
    -cp "${BOUNCER_HOME}/conf/:${BOUNCER_HOME}/keys/:${BOUNCER_CLASSPATH}" \
    -Dlog.stdOutFile=${BOUNCER_HOME}/log/bouncer.out \
    -Dlog.stdErrFile=${BOUNCER_HOME}/log/bouncer.err \
    org.javastack.bouncer.Bouncer ${BOUNCER_CONF} 1>>${BOUNCER_HOME}/log/bouncer.bootstrap 2>&1 &
  PID="$!"
 # echo "Bouncer: STARTED [${PID}]"
  
sleep 3
pid=`ps -ef | grep $BOUNCER_HOME'/lib/bouncer-' | grep -v grep | awk '{print $2}'`
if [ "$pid" ] ;then
 echo 'Bouncer start success'
else
 echo 'Bouncer start failed'
fi


}
do_stop () {
  PID="$(ps axwww | grep "program.name=bouncer" | grep -v grep | while read _pid _r; do echo ${_pid}; done)"
  if [ "${PID}" = "" ]; then
    echo "Bouncer: NOT RUNNING"
  else
    echo "$(date +%Y-%m-%d) $(date +%H:%-M:%-S) Killing: ${PID}" >> ${BOUNCER_HOME}/log/bouncer.bootstrap
    echo -n "Bouncer: KILLING [${PID}]"
    kill -TERM ${PID}
    echo -n "["
    while [ -f "/proc/${PID}/status" ]; do
      echo -n "."
      sleep 1
    done
    echo "]"
  fi
}
do_status () {
  PID="$(ps axwww | grep "program.name=bouncer" | grep -v grep | while read _pid _r; do echo ${_pid}; done)"
  if [ "${PID}" = "" ]; then
    echo "Bouncer: NOT RUNNING"
  else
    echo "Bouncer: RUNNING [${PID}]"
  fi
}
case "$1" in
  run)
    do_stop
    trap do_stop SIGINT SIGTERM
    do_run
  ;;
  start)
    do_stop
    do_start
  ;;
  stop)
    do_stop
  ;;
  restart)
    do_stop
    do_start
  ;;
  reload)
    do_reload
  ;;
  status)
    do_status
  ;;
  keygen)
    do_keygen $2 $3 $4 $5
  ;;
  *)
    echo "$0 <run|start|stop|restart|reload|status|keygen>"
  ;;
esac

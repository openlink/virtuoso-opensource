#! /bin/sh
#
# virtuoso	OpenLink Virtuoso Open-Source Edition
#
#		Written by OpenLink Virtuoso Maintainer 
#		<vos.admin@openlinksw.com>
#
# Version:	@(#)virtuoso  6.1.7  22-JUL-2013	vos.admin@openlinksw.com
#

### BEGIN INIT INFO
# Provides:		virtuoso
# Required-Start: 	$syslog
# Required-Stop: 	$syslog
# Default-Start:	2 3 4 5
# Default-Stop: 	0 1 6
# Short-Description:	Start Virtuoso database server on startup
# Description:		Start and stop the primary instance of Virtuoso running
# 	in /var/lib/virtuoso/db/. The first time this runs, it loads the
# 	Conductor administrative package.
### END INIT INFO


PATH=/sbin:/bin:/usr/sbin:/usr/bin
DAEMON=/usr/bin/virtuoso-t
NAME=virtuoso
DESC="OpenLink Virtuoso Open-Source Edition"
DBBASE=/var/lib/virtuoso/db

test -x $DAEMON || exit 0

LOGDIR=/var/log/virtuoso-opensource
PIDFILE=$DBBASE/$NAME.lck
DODTIME=1                   # Time to wait for the server to die, in seconds
                            # If this value is set too low you might not
                            # let some servers to die gracefully and
                            # 'restart' will not work

# Include virtuoso-opensource defaults if available
if [ -f /etc/default/virtuoso-opensource ] ; then
	. /etc/default/virtuoso-opensource
fi

set -e

running_pid()
{
    # Check if a given process pid's cmdline matches a given name
    pid=$1
    name=$2
    [ -z "$pid" ] && return 1
    [ ! -d /proc/$pid ] &&  return 1
    cmd=`cat /proc/$pid/cmdline | tr "\000" "\n"|head -n 1 |cut -d : -f 1`
    # Is this the expected child?
    [ "$cmd" != "$name" ] &&  return 1
    return 0
}

running()
{
# Check if the process is running looking at /proc
# (works for all users)

    # No pidfile, probably no daemon present
    [ ! -f "$PIDFILE" ] && return 1
    # Obtain the pid and check it against the binary name
    . $PIDFILE
    pid="$VIRT_PID"
    running_pid $pid $DAEMON || return 1
    return 0
}

force_stop() {
# Forcefully kill the process
    [ ! -f "$PIDFILE" ] && return
    if running ; then
        kill -15 $pid
        # Is it really dead?
        [ -n "$DODTIME" ] && sleep "$DODTIME"s
        if running ; then
            kill -9 $pid
            [ -n "$DODTIME" ] && sleep "$DODTIME"s
            if running ; then
                echo "Cannot kill $LABEL (pid=$pid)!"
                exit 1
            fi
        fi
    fi
    rm -f $PIDFILE
    return 0
}

case "$1" in
  start)
	echo -n "Starting $DESC: "
	cd "$DBBASE" || exit -1
	$DAEMON -c $NAME +wait
        if running ; then
            echo "$NAME."
        else
            echo " ERROR."
        fi
	;;
  stop)
	echo -n "Stopping $DESC: "
	cd "$DBBASE" || exit -1
	. ./virtuoso.lck
	if running ; then
	    kill $VIRT_PID
	fi
	echo "$NAME."
	;;
  force-stop)
	echo -n "Forcefully stopping $DESC: "
        force_stop
        if ! running ; then
            echo "$NAME."
        else
            echo " ERROR."
        fi
	;;
  #reload)
	#
	#	If the daemon can reload its config files on the fly
	#	for example by sending it SIGHUP, do it here.
	#
	#	If the daemon responds to changes in its config file
	#	directly anyway, make this a do-nothing entry.
	#
	# echo "Reloading $DESC configuration files."
	# start-stop-daemon --stop --signal 1 --quiet --pidfile \
	#	/var/run/$NAME.pid --exec $DAEMON
  #;;
  force-reload)
	#
	#	If the "reload" option is implemented, move the "force-reload"
	#	option to the "reload" entry above. If not, "force-reload" is
	#	just the same as "restart" except that it does nothing if the
	#   daemon isn't already running.
	# check wether $DAEMON is running. If so, restart
	start-stop-daemon --stop --test --quiet --pidfile \
		/var/run/$NAME.pid --exec $DAEMON \
	&& $0 restart \
	|| exit 0
	;;
  status)
    echo -n "$LABEL is "
    if running ;  then
        echo "running"
    else
        echo " not running."
        exit 1
    fi
    ;;
  *)
	N=/etc/init.d/$NAME
	# echo "Usage: $N {start|stop|restart|reload|force-reload}" >&2
	echo "Usage: $N {start|stop|restart|force-reload|status|force-stop}" >&2
	exit 1
	;;
esac

exit 0

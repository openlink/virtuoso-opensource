#!/bin/sh
#
#  tplugin_load.sh
#
#  A plugin listed twice in [Plugins] is connected once.
#
#  The loader connected a plugin once for every LoadN line that named it, and
#  a plugin's connect function registers its BIFs.  A library listed twice
#  therefore registered each of its names a second time, and the server died
#  at startup with "GPF: sqlbif.c ... bif name cannot be redefined" (exit 139)
#  before it ever listened.
#
#  This driver starts the real server (M2 cannot load plugins) with each
#  available plugin listed twice, and asserts that the server starts, that
#  the first line connects the library and that the second is logged as
#  skipped.  graphql is built by default; vonnx is added when it is built.
#  With neither built the driver skips, and a plugin that does not load at
#  all on this machine is skipped rather than failed.
#
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#
#  Copyright (C) 1998-2026 OpenLink Software
#
#  This project is free software; you can redistribute it and/or modify it
#  under the terms of the GNU General Public License as published by the
#  Free Software Foundation; only version 2 of the License, dated June 1991.
#
#  This program is distributed in the hope that it will be useful, but
#  WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
#  General Public License for more details.
#
#  You should have received a copy of the GNU General Public License along
#  with this program; if not, write to the Free Software Foundation, Inc.,
#  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
#

LOGFILE=`pwd`/tplugin_load.output
export LOGFILE
. $VIRTUOSO_TEST/testlib.sh

rm -f $LOGFILE

BANNER "STARTED plugin load test (tplugin_load.sh)"

case "$SERVER" in
  *[Mm]2*)
    LOG "SKIPPED: $SERVER cannot load plugins; this driver needs virtuoso-t"
    BANNER "COMPLETED plugin load test (tplugin_load.sh)"
    exit 0
    ;;
esac

if [ "$CURRENT_VIRTUOSO_CAPACITY" = "multiple" ]
then
    LOG "SKIPPED: single-server test"
    BANNER "COMPLETED plugin load test (tplugin_load.sh)"
    exit 0
fi

#  The plugins to list twice, copied next to the database (LoadPath = .).
PLUGINS=""
if [ -f "$VIRTUOSO_BUILD/binsrc/graphql/.libs/graphql.so" ]
then
    cp "$VIRTUOSO_BUILD/binsrc/graphql/.libs/graphql.so" .
    PLUGINS="graphql"
fi
if ONNX_LOCATE
then
    cp "$ONNX_PLUGIN_DIR/vonnx.so" .
    PLUGINS="$PLUGINS vonnx"
fi
if [ -z "$PLUGINS" ]
then
    LOG "SKIPPED: no plugin is built (graphql, vonnx)"
    BANNER "COMPLETED plugin load test (tplugin_load.sh)"
    exit 0
fi

#  Load1/Load2 = the first plugin, Load3/Load4 = the second.
: > tplugin_load.loads
n=0
for p in $PLUGINS
do
    n=`expr $n + 1`
    echo "Load$n = plain, $p" >> tplugin_load.loads
    n=`expr $n + 1`
    echo "Load$n = plain, $p" >> tplugin_load.loads
done

rm -f $DBLOGFILE $DBFILE $SRVMSGLOGFILE $LOCKFILE virtuoso.tdb virtuoso.ttr
MAKECFG_FILE $VIRTUOSO_TEST/$TESTCFGFILE $PORT $CFGFILE
sed -e '/^Load[0-9]/d' -e '/^LoadPath/r tplugin_load.loads' $CFGFILE > tplugin_load.ini
mv -f tplugin_load.ini $CFGFILE
LOG "+ [Plugins] of this run:"
sed -n '/^\[Plugins\]/,/^\[/p' $CFGFILE | grep '^Load' >> $LOGFILE

#  Start the server as START_SERVER does, but stop waiting as soon as the log
#  shows a GPF instead of waiting out the whole timeout.
RUNSERVER $SERVER $PORT &
started=0
n=0
while [ $n -lt 90 ]
do
    sleep 2
    if $NETSTAT -an 2>/dev/null | grep "[\.\:]$PORT " | grep LISTEN > /dev/null
    then
	started=1
	break
    fi
    if LC_ALL=C grep -a 'GPF' $SRVMSGLOGFILE > /dev/null 2>&1
    then
	break
    fi
    n=`expr $n + 1`
done

if [ $started -eq 1 ]
then
    LOG "PASSED: the server starts with each plugin listed twice in [Plugins] ($PLUGINS )"
else
    LOG "***FAILED: the server did not start with a plugin listed twice in [Plugins]: `LC_ALL=C grep -a 'GPF' $SRVMSGLOGFILE | head -1`"
fi

n=0
for p in $PLUGINS
do
    n=`expr $n + 1`
    first=$n
    n=`expr $n + 1`
    second=$n
    if LC_ALL=C grep -a "FAILED  plugin $first:" $SRVMSGLOGFILE > /dev/null 2>&1
    then
	LOG "SKIPPED: $p does not load on this machine: `LC_ALL=C grep -a "FAILED  plugin $first:" $SRVMSGLOGFILE | head -1`"
	continue
    fi
    if LC_ALL=C grep -a "SUCCESS plugin $first:" $SRVMSGLOGFILE > /dev/null 2>&1
    then
	LOG "PASSED: Load$first connects $p"
    else
	LOG "***FAILED: Load$first did not connect $p"
    fi
    if LC_ALL=C grep -a "SKIPPED plugin $second: .* is already loaded" $SRVMSGLOGFILE > /dev/null 2>&1
    then
	LOG "PASSED: Load$second, $p again, is logged as already loaded and skipped"
    else
	LOG "***FAILED: Load$second, $p again, is not logged as skipped"
    fi
    if LC_ALL=C grep -a "SUCCESS plugin $second:" $SRVMSGLOGFILE > /dev/null 2>&1
    then
	LOG "***FAILED: Load$second connected $p a second time"
    else
	LOG "PASSED: Load$second does not connect $p a second time"
    fi
done

if [ $started -eq 1 ]
then
    SHUTDOWN_SERVER
    n=0
    while [ -f "$LOCKFILE" -a $n -lt 30 ]
    do
	sleep 2
	n=`expr $n + 1`
    done
fi

CHECK_LOG
BANNER "COMPLETED plugin load test (tplugin_load.sh)"

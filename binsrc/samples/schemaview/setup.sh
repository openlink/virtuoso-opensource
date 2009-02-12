#! /bin/bash
#  
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#  
#  Copyright (C) 1998-2006 OpenLink Software
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
#  

# ----------------------------------------------------------------------
#  Fix issues with LOCALE
# ----------------------------------------------------------------------
LANG=C
LC_ALL=POSIX
export LANG LC_ALL



PORT=3332
SERVER=localhost
VERSION=`cat VERSION | sed 's/.*<\(.*\)>/\1/g'`
VIRT=virtuoso-t
USR=SCHEMAVIEW
PASSWD=SCHEMAVIEW
ISQL=isql
VERBOSE=


SERVER_P=$SERVER:$PORT

SETCOLOR_SUCCESS="echo -en \\033[1;32m"
SETCOLOR_FAILURE="echo -en \\033[1;31m"
SETCOLOR_COMMAND="echo -en \\033[1;33m"
SETCOLOR_NORMAL="echo -en \\033[0;39m"

comm() {
if [ ! -z $VERBOSE ] ; then
    $SETCOLOR_COMMAND
    echo -n Command
    $SETCOLOR_NORMAL
    echo " \"$1\"..."
fi
$1
if [ ! -z $VERBOSE ] ; then
    $SETCOLOR_SUCCESS
    echo done
    $SETCOLOR_NORMAL
fi
}

log() {
    $SETCOLOR_COMMAND
    echo $1
    $SETCOLOR_NORMAL
}

cat load_cfg.isql.meta | sed "s/<VERSION>/$VERSION/g" > load_cfg.isql
if [ "$1" = "-test" ] ; then 
 exit;
fi  
log "Schema sample, version=$VERSION"
if [ -f db/virtuoso.lck ] ; then
 log "Stopping server..."
 echo `echo 'shutdown;' | $ISQL $SERVER_P dba dba` > /dev/null
fi

log "Starting virtuoso server..."
comm "$VIRT +wait"
log "Creating users..."
comm "$ISQL $SERVER_P dba dba  load_users.isql"
log "Creating tables..."
comm "$ISQL $SERVER_P $USR $PASSWD load_tables.isql"
log "Utilities..."
comm "$ISQL $SERVER_P $USR $PASSWD vsputils.isql"
log "Configuration..."
comm "$ISQL $SERVER_P $USR $PASSWD load_cfg.isql"
log "Configuration..."
comm "$ISQL $SERVER_P $USR $PASSWD load_docs.isql"
log "Loading documents..."



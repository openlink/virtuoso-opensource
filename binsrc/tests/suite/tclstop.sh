#!/bin/sh
PORT=${PORT-1111}
CLUSTER=yes
export CLUSTER
LOGFILE=tcl.output
export LOGFILE
. $VIRTUOSO_TEST/testlib.sh

STOP_SERVER 

#!/bin/sh
PORT=${PORT-1111}
CLUSTER=yes
export CLUSTER
LOGFILE=tcl.output
export LOGFILE
. ./test_fn.sh

STOP_SERVER 

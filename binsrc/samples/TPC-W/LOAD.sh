#!/bin/bash

DATABASE='localhost'
USER=dba
PASSWORD=dba
ISQL="isql $DATABASE:$PORT $USER $PASSWORD"

$ISQL ./setup.isql >> $LOGFILE

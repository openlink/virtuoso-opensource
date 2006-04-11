#! /bin/sh
if [ -e db/virtuoso.lck ]
then
	echo ''
else
	echo 'Starting Virtuoso DocBookView...'
	virtuoso -w && echo ' ... OK' || echo ' ... FAILED'
fi
isql localhost:1120 $*

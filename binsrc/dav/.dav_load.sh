#!/bin/sh
#
# ----------------------------------------------------------------------
#  Fix issues with LOCALE
# ----------------------------------------------------------------------
LANG=C
LC_ALL=POSIX
export LANG LC_ALL


isql $PORT dba dba .dav_load.sql > .dav_load.log 2>&1
cat .dav_load.log | sed 's/^\(in lines .*\)$//g' | sed 's/^\([#]line .*\)$//g' | sed 's/Virtuoso Driver//g' | sed 's/Virtuoso Server//g' > .dav_load.log.tmp
diff -i -u .dav_load.etalon .dav_load.log.tmp > .dav_load.diff
if grep 'Error' .dav_load.diff > /dev/null
then
mcedit .dav_load.diff
else
echo OK
fi

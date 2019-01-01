#!/bin/sh
#
#  $Id$
#
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#
#  Copyright (C) 1998-2019 OpenLink Software
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

# ----------------------------------------------------------------------
#  Fix issues with LOCALE
# ----------------------------------------------------------------------
LANG=C
LC_ALL=POSIX
export LANG LC_ALL


# WebDAV test parameters
USR=user_
PWD=pass_
LOGFILE=dav.log
STATFILE=dav.stat
CURDIR=`pwd`
sqlfile=init_dav_metr.sql
FEXT=.BIN

. $HOME/binsrc/tests/suite/test_fn.sh

rm -f $sqlfile

# SQL script for initializing a schema
cat > $sqlfile <<ENDF
create procedure
make_file ()
{
  declare _string any;
  declare _add any;
  declare len, _size integer;
  _size := \$U{_SIZE};
  _string := 'This is test file!\n';
  len := length (_string);
  _add := repeat (_string, (_size*1024/len) + 1);
  string_to_file (concat ('\$U{_HOME}','/test_dav'), _add, 0);
}
;

delete from WS.WS.SYS_DAV_USER where U_NAME like 'user_%';
delete from WS.WS.SYS_DAV_COL where COL_NAME like 'user_%';
delete from WS.WS.SYS_DAV_RES where RES_FULL_PATH like '/DAV/user_%';

create procedure
make_users ()
{
  declare idx, len integer;
  declare _user, _pass varchar;
  idx := 1;
  len := \$U{_USERS} + 1;
  while (idx < len)
    {
      _user := concat ('user_', cast (idx as varchar));
      _pass := concat ('pass_', cast (idx as varchar));
      insert soft WS.WS.SYS_DAV_USER (U_ID, U_NAME, U_FULL_NAME, U_E_MAIL, U_PWD,
	   U_GROUP, U_DEF_PERMS, U_ACCOUNT_DISABLED)
	   values (idx + 2, _user, 'DAV test user', 'test@suite.com', _pass, 1, '110100000', 0);
      insert into WS.WS.SYS_DAV_COL (COL_ID, COL_NAME, COL_PARENT, COL_OWNER,
	   COL_GROUP, COL_PERMS, COL_CR_TIME, COL_MOD_TIME)
           values (WS.WS.GETID ('C'), _user, 1, idx + 2, 1, '110100000R', now (), now ());
      idx := idx + 1;
    }
}
;


create procedure
make_uri ()
{
  declare _text, _name, _user_dir varchar;
  declare idx, len, loops, dlen, rn integer;
  declare dl any;
  idx := 1;
  loops := \$U{_LOOPS};
  if ('\$U{_SIZE}' = 'random')
    rn := 1;
  else
    rn := 0;
  if (rn)
    {
      dl := sys_dirlist ('\$U{_HOME}/files', 1);
      dlen := length (dl);
    }
  len := \$U{_USERS} + 1;
  while (idx < len)
    {
      _user_dir := concat ('user_', cast (idx as varchar), '/');
      if (not rn)
	{
          _text := concat ('1 PUT /DAV/', _user_dir, 'test_dav', cast (idx as varchar),'$FEXT HTTP/1.1\n');
          _text := concat (_text, '1 GET /DAV/user_', cast (idx as varchar), '/test_dav', cast (idx as varchar),'$FEXT HTTP/1.1\n');
	}
      else
	{
	  declare fn varchar;
	  declare ix integer;
          ix := 0;
          _text := '';
	  while (ix < loops)
	    {
              fn := aref (dl, rnd (dlen));
              _text := concat (_text, '1 PUT /DAV/', _user_dir, fn, ' HTTP/1.1\n');
              _text := concat (_text, '1 GET /DAV/', _user_dir, fn, ' HTTP/1.1\n');
              ix := ix + 1;
	    }
	}
      if (not rn)
        _text := repeat (_text, loops);
      _text := concat (sprintf ('localhost %s\n', server_http_port ()), _text);
      string_to_file (concat ('\$U{_HOME}', '/uri_', cast (idx as varchar), '.url'), _text, 0);
      idx := idx + 1;
    }
}
;

make_file ();

make_users ();

make_uri ();
ENDF

chmod 644 $sqlfile

# Waits until last client finished
waitAll ()
{
   clients=3
   while [ "$clients" -gt "2" ]
     do
       sleep 5
       clients=`ps -e | grep urlsimu | grep -v grep | wc -l`
       echo -e "Clients remaining: $clients      \r"
     done
}

# Cleanup logs and help files
rm -f test_dav* uri_*.url cli_*.log $LOGFILE *$FEXT *.txt
cp files/*.txt .

  if [ "$#" -eq 3 ]
    then
     ECHO "Started WebDAV metrics test (clients: $1, size $2 Kb, R/W $3)"
  else
     ECHO
     ECHO "      Usage $0 users file_size(Kb.) time_repeats"
     ECHO
     ECHO "      Usage $0 10 1000 5"
     ECHO
     exit
  fi

#
# CREATE FIRST FILE AND USERS (user_n, pass_n)
#

#echo "$ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u \"_SIZE=$2 _USERS=$1 _LOOPS=$3 _HOME=$CURDIR\" < $sqlfile"
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u "_SIZE=$2 _USERS=$1 _LOOPS=$3 _HOME=$CURDIR" < $sqlfile



#
# CREATE TEST FILES
#

 count=1
 while [ "$count" -le "$1" ]
   do
     cp test_dav test_dav$count$FEXT > /dev/null
     count=`expr $count + 1`
   done

 rm -f test_dav

 # Start N-1 times urlsimu background and one in foreground
 count=1
 while [ "$count" -lt "$1" ]
   do
     URLPUT="$HOME/binsrc/tests/urlsimu -u user_$count -p pass_$count -t cli_$count.bin"
     $URLPUT uri_$count.url > cli_$count.log &
     count=`expr $count + 1`
   done

 URLPUT="$HOME/binsrc/tests/urlsimu -u user_$count -p pass_$count -t cli_$count.bin"
 $URLPUT -u "$USR$count" -p "$PWD$count" uri_$count.url -t cli_$count.bin | tee cli_$count.log

 # Wait until last finishes
 waitAll
 sleep 1

 echo "" >> $STATFILE
 echo "" >> $STATFILE
 echo "" >> $STATFILE

# Printout the result of test
 echo "=================== RESULTS =======================" | tee -a $STATFILE
 echo "Initial clients: $1, file size $2 Kb, total R/W $3" | tee -a $STATFILE
 echo "Clients:  `grep Total cli_*.log | wc -l`"  | tee -a $STATFILE
 echo "------------------- Counts ------------------------" | tee -a $STATFILE
#grep -h Total cli_*.log > total.log

#cat total.log | tee -a  $STATFILE
 grep -h Total cli_*.log | cut -d ' ' -f 27- | tee -a  $STATFILE
 echo "------------------- Average -----------------------" | tee -a $STATFILE
#gawk -f total.awk total.log | tee -a $STATFILE

 avr=0
 tmp=0
 cnt=0
 for f in cli_*.log
  do
   tmp=`grep 'Total' $f | cut -d '/' -f 2`
   avr=`expr $avr + $tmp`
   cnt=`expr $cnt + 1`
  done
 avr=`expr $avr \/ $cnt`

 echo "Average: $avr" | tee -a $STATFILE

 RUN $ISQL $DSN '"EXEC=checkpoint;"' ERRORS=STDOUT
 RUN $ISQL $DSN '"EXEC=status();"' ERRORS=STDOUT

 grep 'Lock Status:' $LOGFILE | tee -a  $STATFILE

 ok_n=`grep 'HTTP/1.1 2' cli_*.log | wc -l`
 tot_ok=`expr $ok_n / 2 / $count`

 echo "Total successful R/W:  $tot_ok  of ($3)" | tee -a $STATFILE

 echo "=================== END ===========================" | tee -a $STATFILE

 echo "" >> $STATFILE
 echo "" >> $STATFILE
 echo "" >> $STATFILE

# END OF WebDAV metrics test

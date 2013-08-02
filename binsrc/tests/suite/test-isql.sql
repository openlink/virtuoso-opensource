--
--  test-isql.sql
--
--  $Id: test-isql.sql,v 1.1.2.7 2013/01/02 16:15:06 source Exp $
--
--  Various nvarchar tests.
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2013 OpenLink Software
--
--  This project is free software; you can redistribute it and/or modify it
--  under the terms of the GNU General Public License as published by the
--  Free Software Foundation; only version 2 of the License, dated June 1991.
--
--  This program is distributed in the hope that it will be useful, but
--  WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
--  General Public License for more details.
--
--  You should have received a copy of the GNU General Public License along
--  with this program; if not, write to the Free Software Foundation, Inc.,
--  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
--
--

set echo off;

select sys_stat ('db_default_columnstore');
set U{COLUMNSTORE} $LAST[1];
echoln both "ColumnStore = " $U{COLUMNSTORE};

drop table ISQLTEST;
create table ISQLTEST (ID int not null primary key, DATA varchar);

ECHO "ARGV[6] = " $ARGV[6] " ARGV[7] = " $ARGV[7] "\n";
#if $if $NEQ $ARGV[6] YES 1 $NEQ $ARGV[7] NO
  ECHO "*** ABORTED: the test should be started like this: 'isql PORT dba dba test-isql.sql -i YES NO'\n";
  exit;
#endif

select
        #if $EQU $ARGV[6] YES
          'TRUE'
        #else
          'FALSE'
        #endif
;
ECHOLN $IF $EQU $STATE 37000  "PASSED" "*** FAILED" ": #IF inside a statement STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
#if $EQU $STATE OK
ECHOLN $IF $EQU $LAST[1] TRUE "PASSED" "*** FAILED" ": #IF inside a statement STATE=" $STATE " MESSAGE=" $MESSAGE " result=" $LAST[1] "\n";
#endif

sparql
select ?s ?p ?o
where {
       ?s ?p ?o
filter regex(?s, 
        #if $EQU $ARGV[6] YES
          "bif:"
        #else
          "http://"
        #endif
       )
}
order by ?s
limit 10
;
ECHOLN $IF $EQU $STATE 37000 "PASSED" "*** FAILED" ": #IF inside SPARQL STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

#if $EQU $ARGV[6] YES
	insert into ISQLTEST (ID, DATA) values (1, 'IFPART');
	ECHO $IF $EQU $ROWCNT 1 "PASSED" "*** FAILED";
	ECHO ": conditional on TRUE, branch true, STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
#else
        insert into ISQLTEST (ID, DATA) values (1, 'ELSEPART');
        ECHO $IF $EQU $ROWCNT 1 "*** FAILED" "*** FAILED";
        ECHO ": SHOULD NOT BE REACHED: conditional on TRUE, branch false, STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
#endif

select ID, DATA from ISQLTEST where ID = 1;
ECHO $IF $EQU $LAST[2] IFPART "PASSED" "*** FAILED";
ECHO ": doind TRUE conditional IF in isql STATE=" $STATE " MESSAGE=" $MESSAGE " result=" $LAST[2] "\n";

#if $EQU $ARGV[6] NO
        insert into ISQLTEST (ID, DATA) values (2, 'IFPART');
        ECHO $IF $EQU $ROWCNT 1 "*** FAILED" "*** FAILED";
        ECHO ": SHOULD NOT BE REACHED: conditional on FALSE, branch true, STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
#else
        insert into ISQLTEST (ID, DATA) values (2, 'ELSEPART');
        ECHO $IF $EQU $ROWCNT 1 "PASSED" "*** FAILED";
        ECHO ": conditional on FALSE, branch false, STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
#endif

select ID, DATA from ISQLTEST where ID = 2;
ECHO $IF $EQU $LAST[2] ELSEPART "PASSED" "*** FAILED";
ECHO ": doing FALSE conditional IF in isql STATE=" $STATE " MESSAGE=" $MESSAGE " result=" $LAST[2] "\n";

-- ********************************************************************************************************
#if $EQU $ARGV[6] YES
   #if $EQU $ARGV[7] NO
        insert into ISQLTEST (ID, DATA) values (3, 'IFNESTED');
        ECHO $IF $EQU $ROWCNT 1 "PASSED" "*** FAILED";
        ECHO ": NESTED conditional on TRUE branch TRUE, STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
   #endif
#else
        insert into ISQLTEST (ID, DATA) values (3, 'ELSEPART');
        ECHO $IF $EQU $ROWCNT 1 "PASSED" "*** FAILED";
        ECHO ": SHOULD NOT BE REACHED: NESTED conditional on TRUE, branch TRUE, STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
#endif

select ID, DATA from ISQLTEST where ID = 3;
ECHO $IF $EQU $LAST[2] IFNESTED "PASSED" "*** FAILED";
ECHO ": NESTED conditional IF in isql STATE=" $STATE " MESSAGE=" $MESSAGE " result=" $LAST[2] "\n";

SET u{UNEXISTING_VAR} 0;

#if $EQU $u{UNEXISTING_VAR} YES
   ECHO "*** FAILED: UNEXISTING conditional should be false\n";
#endif

#if $u{UNEXISTING_VAR}
   ECHO "*** FAILED: UNEXISTING conditional without relational operation, should be false\n";
#endif

select sys_stat ('db_default_columnstore');
#if $EQU $U{COLUMNSTORE} 0                                                                                                                        
    echoln both $IF $EQU $LAST[1] 0 "PASSED" "***FAILED" ": #IF on COLUMNSTORE";
#else
    echoln both $IF $EQU $LAST[1] 1 "PASSED" "***FAILED" ": #IF on COLUMNSTORE";
#endif

ECHOLN $IF $EQU $+ 7 6 13 "PASSED" "*** FAILED" ": ISQL macro '+'";
ECHOLN $IF $EQU $- 7 6  1 "PASSED" "*** FAILED" ": ISQL macro '-'";
ECHOLN $IF $EQU $* 7 6 42 "PASSED" "*** FAILED" ": ISQL macro '*'";
ECHOLN $IF $EQU $/ 42 7 6 "PASSED" "*** FAILED" ": ISQL macro '/'";

ECHO "PASSED: reaching end of the code.\n";

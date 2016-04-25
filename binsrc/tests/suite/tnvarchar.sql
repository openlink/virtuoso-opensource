--
--  tnvarchar.sql
--
--  $Id: tnvarchar.sql,v 1.1.2.3 2013/01/02 16:15:14 source Exp $
--
--  Various nvarchar tests.
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2016 OpenLink Software
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

drop table WIDEZTEST;
create table WIDEZTEST (ID int not null primary key, DATA nvarchar);

--insert into WIDEZTEST (ID, DATA) values (1, N'\5\0\1\0\2\0\3\0\4');
--ECHO BOTH $IF $NEQ $STATE OK "PASSED" "*** FAILED";
--ECHO BOTH ": inserting \\0 into nvarchar column STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--
--insert into WIDEZTEST (ID, DATA) values (2, N'\x5\x0\x1\x0\x2\x0\x3\x0\x4');
--ECHO BOTH $IF $NEQ $STATE OK "PASSED" "*** FAILED";
--ECHO BOTH ": inserting \\x0 into nvarchar column STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
--
--select length ( cast ('\x5\x0\x1\x0\x2\x0\x3\x0\x4' as nvarchar) );
--ECHO BOTH $IF $EQU $LAST[1] 9 "PASSED" "*** FAILED";
--ECHO BOTH ": casting narrow binary zeroes string into nvarchar STATE=" $STATE " MESSAGE=" $MESSAGE " length (DATA)=" $LAST[1] ", should be 9\n";
--select length ( cast ('Abcdefghi' as nvarchar) );
--ECHO BOTH $IF $EQU $LAST[1] 9 "PASSED" "*** FAILED";
--ECHO BOTH ": casting narrow binary zeroes string into nvarchar STATE=" $STATE " MESSAGE=" $MESSAGE " length (DATA)=" $LAST[1] ", should be 9\n";

insert into WIDEZTEST (ID, DATA) values (3, cast ('Abcdefghi' as nvarchar));
select length (DATA) from WIDEZTEST where ID = 3;
ECHO BOTH $IF $EQU $LAST[1] 9 "PASSED" "*** FAILED";
ECHO BOTH ": casting narrow string into nvarchar column STATE=" $STATE " MESSAGE=" $MESSAGE "length (DATA)=" $LAST[1] ", should be 9\n";

exit;

insert into WIDEZTEST (ID, DATA) values (4, 0x81);
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": inserting invalid varbinary into nvarchar column STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select * from (select xssfdsd from WIDEZTEST) a;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": select from a subquery containing invalid column STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

alter table WIDEZTEST add D2 varchar;
select COL_PREC, COL_SCALE, COL_CHECK from DB.DBA.SYS_COLS where "COLUMN" = 'D2' and "TABLE" = 'DB.DBA.WIDEZTEST';
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "*** FAILED";
ECHO BOTH ": alter table add D2 varchar have precision " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[2] NULL "PASSED" "*** FAILED";
ECHO BOTH ": alter table add D2 varchar have scale " $LAST[2] "\n";
ECHO BOTH $IF $EQU $LAST[3] '' "PASSED" "*** FAILED";
ECHO BOTH ": alter table add D2 varchar have COL_CHECK " $LAST[3] "\n";

alter table WIDEZTEST add Z2 varchar(0);
select COL_PREC, COL_SCALE, COL_CHECK from DB.DBA.SYS_COLS where "COLUMN" = 'Z2' and "TABLE" = 'DB.DBA.WIDEZTEST';
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "*** FAILED";
ECHO BOTH ": alter table add Z2 varchar(0) have precision " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[2] NULL "PASSED" "*** FAILED";
ECHO BOTH ": alter table add Z2 varchar(0) have scale " $LAST[2] "\n";
ECHO BOTH $IF $EQU $LAST[3] '' "PASSED" "*** FAILED";
ECHO BOTH ": alter table add Z2 varchar(0) have COL_CHECK " $LAST[3] "\n";


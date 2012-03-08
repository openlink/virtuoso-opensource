--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2012 OpenLink Software
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
echo BOTH "\nSTARTED: string session tests (tstrses.sql)\n";
SET ARGV[0] 0;
SET ARGV[1] 0;

drop table tb;

create table tb (ch long varchar);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": create table tb : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create procedure fill (inout _read any)
{
   http (repeat ('a', 2000) || '\r\n', _read);
   http (repeat ('b', 2000) || '\r\n', _read);
   http (repeat ('c', 2000) || '\r\n', _read);
   http (repeat ('c', 2000) || '\r\n', _read);
   http (repeat ('d', 2000) || '\r\n', _read);
   http (repeat ('e', 2000) || '\r\n', _read);
   http (repeat ('f', 2000) || '\r\n', _read);
}
;

create procedure t1n ()
{
   declare _read any;
   declare _res varchar;

   _read := string_output ();

   fill (_read);

   _res :=  string_output_string (_read);
   return length (_res);
}
;

select t1n ();
ECHO BOTH $IF $EQU $LAST[1] 14014 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": using memory session : STATE=" $STATE "\n";

create procedure t1 ()
{
   declare _read any;
   declare _res varchar;

   _read := string_output (5000);

   fill (_read);

   _res :=  string_output_string (_read);

   return length (_res);
}
;

select t1 ();
ECHO BOTH $IF $EQU $LAST[1] 14014 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": using limited session session : STATE=" $STATE " LAST=" $LAST[1] "\n";

create procedure t2 ()
{
   declare _read any;

   _read := string_output (5000);

   fill (_read);

   insert into tb values (_read);
}
;
select t2 ();
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": insert into table tb : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select length(ch) from tb;
ECHO BOTH $IF $EQU $LAST[1] 14014 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": select length(ch) from tb; : STATE=" $STATE " LAST=" $LAST[1] "\n";


create procedure t3 ()
{
   declare _read, _res any;

   _read := string_output (5000);

   fill (_read);

   string_to_file ('test_file', _read, -2);
   _res := file_to_string ('test_file');

   return length(_res);
}
;

select t3();
ECHO BOTH $IF $EQU $LAST[1] 14014 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": test string session write to file : STATE=" $STATE "LAST=" $LAST[1] "\n";

drop table TBLOB_HANDLE_SER;
create table TBLOB_HANDLE_SER (ID int primary key, BVC LONG VARCHAR, BWC LONG NVARCHAR);

insert into TBLOB_HANDLE_SER (ID, BVC, BWC) values (1, make_string (30000), make_wstring (30000));

select blob_to_string (deserialize (serialize (BVC))) from TBLOB_HANDLE_SER;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": serialization of a narrow blob handle : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select blob_to_string (deserialize (serialize (BWC))) from TBLOB_HANDLE_SER;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": serialization of a wide blob handle : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

echo BOTH "COMPLETED: string session tests (tstrses.sql) WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED\n\n";

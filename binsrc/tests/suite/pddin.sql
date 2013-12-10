--  
--  $Id$
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
set charset='CP866';

drop table "pdd";

create table "pdd" ("a" integer,"b" long varchar,"c" long nvarchar, "d" long varbinary);
ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
ECHO BOTH ": Creating pdd table; STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
 
insert into "pdd" ("a","b","c","d") values (1, NULL,NULL,NULL);
ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
ECHO BOTH ": inserting narrow data; STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

insert into "pdd" ("a","b","c","d") values (2, NULL,NULL,NULL);
ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
ECHO BOTH ": inserting narrow data; STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

FOREACH BLOB IN pdd.txt update "pdd" set "d"= ? where "a"=1;
ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
ECHO BOTH ": inserting narrow data; STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

FOREACH BLOB IN pdd.txt update "pdd" set "d"= ? where "a"=2;
ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
ECHO BOTH ": inserting narrow data; STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

update "pdd" set "c"= charset_recode(blob_to_string("d"),'IBM866','IBM866') where "a"=1;
ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
ECHO BOTH ": convering narrow data; STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

update "pdd" set "b"= charset_recode(blob_to_string("d"),'IBM866','IBM866') where "a"=1;
ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
ECHO BOTH ": convering narrow data; STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

update "pdd" set "c"= charset_recode(blob_to_string("d"),'IBM866','_WIDE_') where "a"=2;
ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
ECHO BOTH ": convering narrow data; STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

update "pdd" set "b"= charset_recode(blob_to_string("d"),'IBM866','_WIDE_') where "a"=2;
ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
ECHO BOTH ": convering narrow data; STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


select string_to_file('pddd1.txt',blob_to_string("b"),-2) from "pdd" where "a" = 1;
select string_to_file('pddd2.txt',blob_to_string("c"),-2) from "pdd" where "a" = 1;
select string_to_file('pddd3.txt',blob_to_string("b"),-2) from "pdd" where "a" = 2;
select string_to_file('pddd4.txt',blob_to_string("c"),-2) from "pdd" where "a" = 2;
select string_to_file('pddd5.txt',blob_to_string("d"),-2) from "pdd" where "a" = 2;

--
--  tschema2.sql
--
--  $Id: tschema2.sql,v 1.4.10.1 2013/01/02 16:15:22 source Exp $
--
--  Test DDL functionality #2
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2019 OpenLink Software
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

ECHO BOTH "STARTED: Schema Evolution Test, part 2\n";

-- Run after twords.sql

drop index revword;
set maxrows 10;
select word from words order by revword;
ECHO BOTH $IF $EQU $LAST[1] "endecasílaba" "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " is 10th word sort ordered by revword.\n";

create index revword on words (revword);

select   word from words order by revword;
-- have different text so as not to use cached compilation.
ECHO BOTH $IF $EQU $LAST[1] "endecasílaba" "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " is 10th word index ordered by revword.\n";
checkpoint;

drop table TEMP_BLOB;
create table TEMP_BLOB (ID int not null primary key, DATA1 varchar, DATA2 varchar);

insert into TEMP_BLOB (ID, DATA1, DATA2) values (1, repeat ('a', 100), repeat ('b', 900));
ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
ECHO BOTH ": Inserted a row with 1900 bytes\n";

select DATA1 as DDATA1, DATA1 as DDATA2, DATA2 as DDATA3, DATA2 as DDATA4 from TEMP_BLOB order by DATA1;
ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
ECHO BOTH ": Select with temp blob storage in temp space\n";

ECHO BOTH "COMPLETED: Schema Evolution Test, part 2\n";

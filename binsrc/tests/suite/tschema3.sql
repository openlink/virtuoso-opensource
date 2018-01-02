--
--  tschema3.sql
--
--  $Id: tschema3.sql,v 1.5.10.1 2013/01/02 16:15:22 source Exp $
--
--  Test DDL functionality #3
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2018 OpenLink Software
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

ECHO BOTH "STARTED: CONCURRENT SCHEMA HISTORY TEST\n";

set readmode=snapshot;
backup '/dev/null' &
sleep 3;
set readmode=normal;
create table ttmp (a integer, b integer);

set readmode=snapshot;
select count (*) from words w1  where exists (select 1 from words w2 where w2.revword = w1.word) &
set readmode=normal;
sleep 3;
alter table words add wlen2 integer;
update words set wlen2 = length (word);

WAIT_FOR_CHILDREN;

ECHO BOTH "COMPLETED: CONCURRENT SCHEMA HISTORY TEST\n";

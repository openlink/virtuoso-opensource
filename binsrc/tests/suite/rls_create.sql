--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2017 OpenLink Software
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
drop table RLS_T2;
drop table RLS_T3;
drop table RLS_T1;
drop table RLS_PROT;
drop table RLS_SVT;
drop view RLS_SV;
drop view RLS_PV;
drop view RLS_SV;
drop view RLS_PV;
drop user RLS_USR;

create table RLS_T1 (ID integer primary key);
create table RLS_PROT (OP varchar PRIMARY KEY, COND varchar);
insert into RLS_PROT values ('S', 'DATA is not NULL');
insert into RLS_PROT values ('I', 'DATA is not NULL');
insert into RLS_PROT values ('U', 'DATA is not NULL');
insert into RLS_PROT values ('D', 'DATA is not NULL');
create user RLS_USR;

reconnect RLS_USR;

create table RLS_T2 (ID integer primary key, DATA varchar);
create table RLS_SVT (ID INTEGER primary key, DATA1 varchar, DATA2 varchar);
create VIEW RLS_SV as SELECT ID, DATA1 from RLS_SVT;
create PROCEDURE VIEW RLS_PV as RLS_PVP() (ID INTEGER);
insert into RLS_SVT values (1, 'a', 'aa');
insert into RLS_SVT values (2, 'b', 'bb');

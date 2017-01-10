--
--  rtest1-1.sql
--
--  $Id$
--
--  Remote database testing
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

create table misc (m_id integer not null primary key,
		     m_short any, m_long long varchar);

create table numtest(nt_id integer not null primary key,
    m_numeric numeric(20, 2));

create table VIEWANDTEST (ID int identity not null primary key, STATE varchar, TOWN varchar);
insert into VIEWANDTEST (STATE, TOWN) values ('PV', 'Plovdiv');
insert into VIEWANDTEST (STATE, TOWN) values ('SF', 'Sofia');
insert into VIEWANDTEST (STATE, TOWN) values ('BU', 'Burgas');

create table B3202 (ID integer primary key);

create table XMLT (
	ID integer primary key,
	XMLTYPE_DATA XMLType,
	LONG_XMLTYPE_DATA XMLType,
	LONGXML_DATA LONG XML);
insert into XMLT (ID, XMLTYPE_DATA, LONG_XMLTYPE_DATA, LONGXML_DATA)
	values (1, '<a/>', '<a/>', '<a/>');
insert into XMLT (ID, XMLTYPE_DATA, LONG_XMLTYPE_DATA, LONGXML_DATA)
	values (2, N'<\x413\x435\x43e\x440\x433\x438/>', N'<\x413\x435\x43e\x440\x433\x438/>', N'<\x413\x435\x43e\x440\x433\x438/>');

drop table B9680_TB;
create table B9680_TB (ID int primary key, DATA varchar);

foreach integer between 1 10 insert into B9680_TB values (?, sprintf ('data %d', ?));

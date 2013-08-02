--
--  tnwords_create.sql
--
--  $Id: tnwords_create.sql,v 1.3.10.1 2013/01/02 16:15:15 source Exp $
--
--  Creates the tables for Word tests
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

CONNECT;

ECHO BOTH "Creating tables for tnwords.sql\n";

drop table nwords;
create table nwords(word nvarchar, revword nvarchar, len integer, primary key (word));
drop table nwordcounts;
create table nwordcounts(num integer, totsum integer,
             avg1len double precision, avg2len double precision,
             wholefile long varchar, primary key(num, totsum));

--
--  ttrigt.sql
--
--  $Id$
--
--  Trigger testing
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2015 OpenLink Software
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

drop table T_WAREHOUSE;
drop table T_ORDER;
drop table T_ORDER_LINE;

create table T_WAREHOUSE (W_ID integer default 1,
			  W_ORDER_VALUE float default 0,
			  W_DATA varchar,
			  primary key (W_ID));

create table T_ORDER (O_ID integer not null primary key, O_C_ID integer,
		      O_W_ID integer default 1,
		      O_VALUE numeric default 0,
		      O_MODIFIED datetime);

create table T_ORDER_LINE (OL_O_ID integer,
			   OL_I_ID integer,
			   OL_QTY integer,
			   OL_MODIFIED timestamp,
			   OL_I_PRICE float default 1,
			   primary key (OL_O_ID, OL_I_ID));

create index OL_I_ID on T_ORDER_LINE (OL_I_ID);

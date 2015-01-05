--  
--  $Id: rls_attach.sql,v 1.3.10.1 2013/01/02 16:14:53 source Exp $
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

attach table RLS_T1 as RLS_T1 from '$U{PORT}' user 'dba' password 'dba';
attach table RLS_PROT as RLS_PROT from '$U{PORT}' user 'dba' password 'dba';
create user RLS_USR;

attach table RLS_T2 as RLS_USR.RLS_T2 from '$U{PORT}' user 'dba' password 'dba';
attach table RLS_SVT as RLS_USR.RLS_SVT from '$U{PORT}' user 'dba' password 'dba';
grant all privileges on RLS_T2 to RLS_USR;
grant all privileges on RLS_SVT to RLS_USR;

reconnect RLS_USR;
create VIEW RLS_SV as SELECT ID, DATA1 from RLS_SVT;
create PROCEDURE VIEW RLS_PV as RLS_PVP() (ID INTEGER);

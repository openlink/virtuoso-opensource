--
--  ttrigr.sql
--
--  $Id: ttrigr.sql,v 1.4.10.1 2013/01/02 16:15:30 source Exp $
--
--  Trigger testing
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2023 OpenLink Software
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

attach table T_ORDER from '$U{PORT}' user 'dba' password 'dba';
attach table T_ORDER_LINE from '$U{PORT}';
attach table T_WAREHOUSE from '$U{PORT}';

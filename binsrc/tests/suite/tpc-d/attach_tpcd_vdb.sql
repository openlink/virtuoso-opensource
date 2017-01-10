--
--  attach_tpcd.sql
--
--  $Id$
--
--  TPC-D Benchmark
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

attach table $U{QUAL}CUSTOMER as CUSTOMER from '$U{DSN}' user '$U{UID}' password '$U{PWD}';
attach table $U{QUAL}LINEITEM as LINEITEM from '$U{DSN}';
attach table $U{QUAL}PARTSUPP as PARTSUPP from '$U{DSN}';
attach table $U{QUAL}SUPPLIER as SUPPLIER from '$U{DSN}';
attach table $U{QUAL}HISTORY as HISTORY from '$U{DSN}';
attach table $U{QUAL}NATION as NATION from '$U{DSN}';
attach table $U{QUAL}REGION as REGION from '$U{DSN}';
attach table $U{QUAL}ORDERS as ORDERS from '$U{DSN}';
attach table $U{QUAL}PART as PART from '$U{DSN}';

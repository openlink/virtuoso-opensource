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
vhost_define (vhost=>'*ini*', lhost=>'*ini*', lpath=>'/bpel4ws/interop/', ppath=>'/bpel4ws/', vsp_user=>'dba', def_page=>'home.vspx');

load bpel4ws/tables.sql;

load SecLoan/LoanFlow.sql;

load RMLoan/LoanFlow.sql;

load SecRMLoan/LoanFlow.sql;

load echo/echo.sql;

load Aecho/echo.sql;

load SecAecho/echo.sql;

load RMecho/echo.sql;

load bpel4ws/interop_install.sql;

--  
--  $Id$
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



create procedure bp_host ()
{
  return 'localhost:$U{HTTPPORTBP}';
}
;
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH " bp_host status:" $STATE "\n";

create procedure db_host ()
{
  return 'localhost:$U{HTTPPORTDB}';
}
;
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH " db_host status:" $STATE "\n";


create procedure td_host ()
{
  return 'localhost:$U{HTTPPORTTD}';
}
;
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH " td_host status:" $STATE "\n";


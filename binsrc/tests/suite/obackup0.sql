--
--  obackup0.sql
--
--  $Id: obackup0.sql,v 1.6.6.1.4.1 2013/01/02 16:14:49 source Exp $
--
--  Online Backup stage 0
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

echo BOTH "STARTED: Online-Backup stage 0\n";

checkpoint;
update t1 set fi2 = row_no;

update "Demo.demo.Order_Details" set "UnitPrice" = 1;
ECHO BOTH "update Order_Details (set all to 1)"
checkpoint;

select cpt_remap_pages();
--ECHO BOTH $IF $EQU $LAST[1] 0 "***FAILED" "PASSED";
ECHO BOTH ": " $LAST[1] " checkpoint remap pages\n";

backup_max_dir_size (300000);
backup_online ('nwdemo_i_#', 150,0, vector ('nw1', 'nw2', 'nw3', 'nw4', 'nw5'));








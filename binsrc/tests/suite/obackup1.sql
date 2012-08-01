--
--  obackup1.sql
--
--  $Id$
--
--  Online Backup stage 0
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2012 OpenLink Software
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

echo BOTH "STARTED: Online-Backup stage 1\n";

select cpt_remap_pages();
ECHO BOTH $LAST[1] " checkpoint remap pages\n";

select backup_pages();
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": pages changed since last backup (in checkpoint space) = " $LAST[1] "\n";

ECHO BOTH "update Orders\n";
update "Demo"."demo"."Orders" set "Freight" = "Freight" + 1;

ECHO BOTH "update Order_Details\n";
update "Demo"."demo"."Order_Details" set "UnitPrice" = "UnitPrice" + 1;

checkpoint;

select cpt_remap_pages();
ECHO BOTH $IF $EQU $LAST[1] 0 "***FAILED" "PASSED";
ECHO BOTH ": " $LAST[1] " checkpoint remap pages\n";

backup_max_dir_size (300000);
backup_online ('nwdemo_i_#', 150,0, vector ('nw1', 'nw2', 'nw3', 'nw4', 'nw5'));

shutdown;

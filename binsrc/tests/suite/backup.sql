--
--  backup.sql
--
--  $Id$
--
--  Make an On-Line Backup
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

checkpoint;

ECHO BOTH "STARTED: On-Line Backup Test, part 1\n";
-- delete from iutest &
-- not on O12, backup not supported, no read from checkpoint space exists
-- Was: set ro;
create table deleted_table_test (id int primary key);
drop table deleted_table_test;
set readmode snapshot;
set timeout 3000;
ECHO BOTH "Starting backup itself, into file backup.log\n";
cl_exec ('backup \'backup.log\'');
wait_for_children;
cl_exec ('backup \'backup2.log\'');
wait_for_children;
ECHO BOTH "COMPLETED: On-Line Backup Test, part 1, recovery check soon follows\n";

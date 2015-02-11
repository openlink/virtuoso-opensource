--
--  tcp_cpts.sql
--
--  $Id$
--
--  Do regular checkpoints
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

--
--  Start the test
--
SET ARGV[0] 0;
SET ARGV[1] 0;

connect;
sleep 10;
backup_online ('tpcc-', 100000);
status ();
select no_d_id, count (*) from new_order group by no_d_id;

sleep 5;
backup_online ('tpcc-', 100000);
status ();
select no_d_id, count (*) from new_order group by no_d_id;

sleep 2;
backup_online ('tpcc-', 100000);
status ();
select no_d_id, count (*) from new_order group by no_d_id;

backup_online ('tpcc-', 100000);
backup_online ('tpcc-', 100000);
backup_online ('tpcc-', 100000);
backup_online ('tpcc-', 100000);
sleep 1;
backup_online ('tpcc-', 100000);
sleep 10;
backup_online ('tpcc-', 100000);
status ();
select no_d_id, count (*) from new_order group by no_d_id;

sleep 90;
backup_online ('tpcc-', 100000);
status ();
select no_d_id, count (*) from new_order group by no_d_id;

sleep 90;
backup_online ('tpcc-', 100000);
status ();
select no_d_id, count (*) from new_order group by no_d_id;

sleep 90;
backup_online ('tpcc-', 100000);
status ();
select no_d_id, count (*) from new_order group by no_d_id;

sleep 90;
backup_online ('tpcc-', 100000);
status ();
select no_d_id, count (*) from new_order group by no_d_id;

sleep 90;
backup_online ('tpcc-', 100000);
status ();
select no_d_id, count (*) from new_order group by no_d_id;

sleep 90;
backup_online ('tpcc-', 100000);
status ();
select no_d_id, count (*) from new_order group by no_d_id;

sleep 90;
backup_online ('tpcc-', 100000);
status ();
select no_d_id, count (*) from new_order group by no_d_id;

sleep 90;
backup_online ('tpcc-', 100000);
status ();
select no_d_id, count (*) from new_order group by no_d_id;

sleep 90;
backup_online ('tpcc-', 100000);
status ();
select no_d_id, count (*) from new_order group by no_d_id;

sleep 90;
backup_online ('tpcc-', 100000);
status ();
select no_d_id, count (*) from new_order group by no_d_id;

sleep 90;
backup_online ('tpcc-', 100000);
status ();
select no_d_id, count (*) from new_order group by no_d_id;

sleep 90;
backup_online ('tpcc-', 100000);
status ();
select no_d_id, count (*) from new_order group by no_d_id;

sleep 90;
backup_online ('tpcc-', 100000);
status ();
select no_d_id, count (*) from new_order group by no_d_id;

sleep 90;
backup_online ('tpcc-', 100000);
status ();
select no_d_id, count (*) from new_order group by no_d_id;

sleep 90;
backup_online ('tpcc-', 100000);
status ();
select no_d_id, count (*) from new_order group by no_d_id;

sleep 90;
backup_online ('tpcc-', 100000);
status ();
select no_d_id, count (*) from new_order group by no_d_id;

sleep 90;
backup_online ('tpcc-', 100000);
status ();
select no_d_id, count (*) from new_order group by no_d_id;

sleep 90;
backup_online ('tpcc-', 100000);
status ();
select no_d_id, count (*) from new_order group by no_d_id;

sleep 90;
backup_online ('tpcc-', 100000);
status ();
select no_d_id, count (*) from new_order group by no_d_id;

sleep 90;
backup_online ('tpcc-', 100000);
status ();
select no_d_id, count (*) from new_order group by no_d_id;

sleep 90;
backup_online ('tpcc-', 100000);
status ();
select no_d_id, count (*) from new_order group by no_d_id;

sleep 90;
backup_online ('tpcc-', 100000);
status ();
select no_d_id, count (*) from new_order group by no_d_id;

sleep 90;
backup_online ('tpcc-', 100000);
status ();
select no_d_id, count (*) from new_order group by no_d_id;

sleep 90;
backup_online ('tpcc-', 100000);
status ();
select no_d_id, count (*) from new_order group by no_d_id;

sleep 90;
backup_online ('tpcc-', 100000);
status ();
select no_d_id, count (*) from new_order group by no_d_id;

sleep 90;
backup_online ('tpcc-', 100000);
status ();
select no_d_id, count (*) from new_order group by no_d_id;

sleep 90;
backup_online ('tpcc-', 100000);
status ();
select no_d_id, count (*) from new_order group by no_d_id;

sleep 90;
backup_online ('tpcc-', 100000);
status ();
select no_d_id, count (*) from new_order group by no_d_id;

sleep 90;
backup_online ('tpcc-', 100000);
status ();
select no_d_id, count (*) from new_order group by no_d_id;

sleep 90;
backup_online ('tpcc-', 100000);
status ();
select no_d_id, count (*) from new_order group by no_d_id;

sleep 90;
backup_online ('tpcc-', 100000);
status ();
select no_d_id, count (*) from new_order group by no_d_id;



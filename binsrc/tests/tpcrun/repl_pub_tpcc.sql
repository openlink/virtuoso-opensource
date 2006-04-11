--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2006 OpenLink Software
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
repl_publish ('tpcc', 'tpcc.log');
repl_pub_add ('tpcc', 'DB.DBA.WAREHOUSE', 2, 0, 0);
repl_pub_add ('tpcc', 'DB.DBA.DISTRICT', 2, 0, 0);
repl_pub_add ('tpcc', 'DB.DBA.CUSTOMER', 2, 0, 0);
repl_pub_add ('tpcc', 'DB.DBA.HISTORY', 2, 0, 0);
repl_pub_add ('tpcc', 'DB.DBA.NEW_ORDER', 2, 0, 0);
repl_pub_add ('tpcc', 'DB.DBA.ORDERS', 2, 0, 0);
repl_pub_add ('tpcc', 'DB.DBA.ORDER_LINE', 2, 0, 0);
repl_pub_add ('tpcc', 'DB.DBA.ITEM', 2, 0, 0);
repl_pub_add ('tpcc', 'DB.DBA.STOCK', 2, 0, 0);
checkpoint;
repl_pub_init_image ('tpcc', 'tpccdb.log', 500000000);

--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2016 OpenLink Software
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
repl_pub_add ('tpcc', 'DB.DBA.warehouse', 2, 0, 0);
repl_pub_add ('tpcc', 'DB.DBA.district', 2, 0, 0);
repl_pub_add ('tpcc', 'DB.DBA.customer', 2, 0, 0);
repl_pub_add ('tpcc', 'DB.DBA.history', 2, 0, 0);
repl_pub_add ('tpcc', 'DB.DBA.new_order', 2, 0, 0);
repl_pub_add ('tpcc', 'DB.DBA.orders', 2, 0, 0);
repl_pub_add ('tpcc', 'DB.DBA.order_line', 2, 0, 0);
repl_pub_add ('tpcc', 'DB.DBA.item', 2, 0, 0);
repl_pub_add ('tpcc', 'DB.DBA.stock', 2, 0, 0);
checkpoint;

--  
--  $Id$
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
attach table DB.DBA.WAREHOUSE  as REP..WAREHOUSE  from 'localhost:1112' user 'dba' password 'dba';
attach table DB.DBA.DISTRICT   as REP..DISTRICT   from 'localhost:1112' user 'dba' password 'dba';
attach table DB.DBA.CUSTOMER   as REP..CUSTOMER   from 'localhost:1112' user 'dba' password 'dba';
attach table DB.DBA.HISTORY    as REP..HISTORY    from 'localhost:1112' user 'dba' password 'dba';
attach table DB.DBA.NEW_ORDER  as REP..NEW_ORDER  from 'localhost:1112' user 'dba' password 'dba';
attach table DB.DBA.ORDERS     as REP..ORDERS     from 'localhost:1112' user 'dba' password 'dba';
attach table DB.DBA.ORDER_LINE as REP..ORDER_LINE from 'localhost:1112' user 'dba' password 'dba';
attach table DB.DBA.ITEM       as REP..ITEM       from 'localhost:1112' user 'dba' password 'dba';
attach table DB.DBA.STOCK      as REP..STOCK      from 'localhost:1112' user 'dba' password 'dba';

--  
--  $Id$
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
set types off;
select count(*) as "*** WAREHOUSE"  from DB.DBA.WAREHOUSE  except select count(*) from REP..WAREHOUSE;
select count(*) as "*** DISTRICT"   from DB.DBA.DISTRICT   except select count(*) from REP..DISTRICT;
select count(*) as "*** CUSTOMER"   from DB.DBA.CUSTOMER   except select count(*) from REP..CUSTOMER;
select count(*) as "*** HISTORY"    from DB.DBA.HISTORY    except select count(*) from REP..HISTORY;
select count(*) as "*** NEW_ORDER"  from DB.DBA.NEW_ORDER  except select count(*) from REP..NEW_ORDER;
select count(*) as "*** ORDERS"     from DB.DBA.ORDERS     except select count(*) from REP..ORDERS;
select count(*) as "*** ORDER_LINE" from DB.DBA.ORDER_LINE except select count(*) from REP..ORDER_LINE;
select count(*) as "*** ITEM"       from DB.DBA.ITEM       except select count(*) from REP..ITEM;
select count(*) as "*** STOCK"      from DB.DBA.STOCK      except select count(*) from REP..STOCK;
set types on;

--select * from DB.DBA.warehouse  except select * from rep..warehouse;
--select * from DB.DBA.district   except select * from rep..district;
--select * from DB.DBA.customer   except select * from rep..customer;
--select * from DB.DBA.history    except select * from rep..history;
--select * from DB.DBA.new_order  except select * from rep..new_order;
--select * from DB.DBA.orders     except select * from rep..orders;
--select * from DB.DBA.order_line except select * from rep..order_line;
--select * from DB.DBA.item       except select * from rep..item;
--select * from DB.DBA.stock      except select * from rep..stock;


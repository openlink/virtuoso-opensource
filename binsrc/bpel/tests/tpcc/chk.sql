--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2014 OpenLink Software
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
select o_id,o_d_id,o_w_id,o_carrier_id from td_orders
except
select o_id,o_d_id,o_w_id,o_carrier_id from DSDB.orders where o_id > 3000;
ECHO BOTH $IF $EQU $ROWCNT 0 "PASSED" "***FAILED";
ECHO BOTH ": " $IF $EQU $ROWCNT 0 0 "some" " orders are different.\n";

select count(*) from (select o_id from td_orders except select o_id from DSDB.orders where o_id > 3000) sub1;
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": " $IF $EQU $LAST[1] 0 0 $LAST[1] " orders are different.\n";

select o_id,o_d_id,o_w_id,o_carrier_id from DSDB.orders where o_id > 3000
except
select o_id,o_d_id,o_w_id,o_carrier_id from td_orders;
ECHO BOTH $IF $EQU $ROWCNT 0 "PASSED" "***FAILED";
ECHO BOTH ": " $IF $EQU $ROWCNT 0 0 "some" " orders are different.\n";

select count(*) from (
    select o_id from DSDB.orders where o_id > 3000
    except
    select o_id from td_orders
    ) sub1;
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": " $IF $EQU $LAST[1] 0 0 $LAST[1] " orders are different.\n";

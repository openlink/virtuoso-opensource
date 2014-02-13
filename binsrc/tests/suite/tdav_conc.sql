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
ECHO BOTH "starting DAV update test\n";
set DEADLOCK_RETRIES = 200;

CONNECT; SET AUTOCOMMIT=ON; foreach integer between 1 64 c_test(1, ?) &
CONNECT; SET AUTOCOMMIT=ON; foreach integer between 1 64 c_test(2, ?) &
CONNECT; SET AUTOCOMMIT=ON; foreach integer between 1 64 c_test(3, ?) &
CONNECT; SET AUTOCOMMIT=ON; foreach integer between 1 64 c_test(4, ?) &
SET AUTOCOMMIT=OFF;
WAIT_FOR_CHILDREN;

SLEEP 5;

ECHO BOTH "DAV update test done\n";
ECHO BOTH "starting DAV insert test\n";
set DEADLOCK_RETRIES = 200;

CONNECT; SET AUTOCOMMIT=ON; foreach integer between 1 64 c_itest(1, ?) &
CONNECT; SET AUTOCOMMIT=ON; foreach integer between 1 64 c_itest(2, ?) &
CONNECT; SET AUTOCOMMIT=ON; foreach integer between 1 64 c_itest(3, ?) &
CONNECT; SET AUTOCOMMIT=ON; foreach integer between 1 64 c_itest(4, ?) &
SET AUTOCOMMIT=OFF;
WAIT_FOR_CHILDREN;

SLEEP 5;
ECHO BOTH "DAV insert test done\n";

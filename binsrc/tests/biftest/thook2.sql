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

select sl_user, sl_logged_in, sl_logged_out from sec_log order by sl_logged_out desc;
ECHO BOTH $IF $EQU $ROWCNT 4 "PASSED" "*** FAILED";
ECHO BOTH ': checking the number of users entered the server during the test = ' $ROWCNT '\n';
ECHO BOTH $IF $EQU $LAST[1] dba "PASSED" "*** FAILED";
ECHO BOTH ': the last user is ' $LAST[1] '\n';
ECHO BOTH $IF $EQU $LAST[3] 'NULL' "PASSED" "*** FAILED";
ECHO BOTH ': ' $LAST[1] ' is still logged in.\n';

raw_exit();

--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2013 OpenLink Software
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

select R_AUTHOR, R_TEXT from REPORT;
SET U{result} '*** FAILED';
SET U{result1} $IF $EQU $UID 'MANAGER' $IF $EQU $ROWCNT 3 'PASSED' $U{result} $U{result};
SET U{result2} $IF $EQU $UID 'OUTSIDER' $IF $EQU $ROWCNT 1 'PASSED' $U{result1} $U{result1};
SET U{result3} $IF $EQU $UID 'U' $IF $EQU $ROWCNT 2 'PASSED' $U{result2} $U{result2};
ECHO BOTH $U{result3} ": Row count for " $UID " = " $ROWCNT "\n";

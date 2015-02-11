--
--  obackup_userck2.sql
--
--  $Id: obackup_userck2.sql,v 1.6.6.1.4.1 2013/01/02 16:14:50 source Exp $
--
--  Concurrency test #N..
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



echo BOTH "STARTED: Online-Backup registry test\n";

select cpt_remap_pages();
ECHO BOTH $LAST[1] " checkpoint remap pages\n";

select backup_pages();
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH " number of pages changed since last backup = " $LAST[1] "\n";

select check_seqs ('h', 10000, 1);
ECHO BOTH $IF $EQU $LAST[1] "EQUAL" "PASSED" "***FAILED";
ECHO BOTH " all sequences hNNNN are " $LAST[1] " to 1\n";

select check_seqs ('x', 10000, 1);
ECHO BOTH $IF $EQU $LAST[1] "EQUAL" "PASSED" "***FAILED";
ECHO BOTH " all sequence xNNNN = " $LAST[1] " to 0\n";

select check_seqs ('ax', 10000, 1);
ECHO BOTH $IF $EQU $LAST[1] "EQUAL" "PASSED" "***FAILED";
ECHO BOTH " all sequence axNNNN = " $LAST[1] " to 0\n";

select check_seqs ('bx', 10000, 1);
ECHO BOTH $IF $EQU $LAST[1] "EQUAL" "PASSED" "***FAILED";
ECHO BOTH " all sequence bxNNNN = " $LAST[1] " to 0\n";


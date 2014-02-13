--
--  blobs.sql
--
--  $Id$
--
--  Check Blob fields
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

ECHO BOTH "STARTED: Blob Check-Up\n";

select count (*) from BLOBS;

ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Table BLOBS contains, count(*)=" $LAST[1] " lines\n";

select sum (length (B1)) from BLOBS;

ECHO BOTH $IF $EQU $LAST[1] 1000000 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BLOBS sum(length (B1))= " $LAST[1] " lines\n";

select sum (length (B3)) from BLOBS;

ECHO BOTH $IF $EQU $LAST[1] 1000000 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BLOBS sum(length (B3))= " $LAST[1] " lines\n";

update BLOBS set B1 = NULL, B2 = '1234567890', B3 = N'1234567890' where ROW_NO = 1;

select sum (length (B1)), sum (length (B2)), sum (length (B3)) from BLOBS;

ECHO BOTH $IF $EQU $LAST[1] 500000 "PASSED" "***FAILED";
ECHO BOTH ": BLOBS  sum(length (B1))= " $LAST[1] " \n";

ECHO BOTH $IF $EQU $LAST[2] 250010 "PASSED" "***FAILED";
ECHO BOTH ": BLOBS  sum(length (B2))= " $LAST[2] " \n";

ECHO BOTH $IF $EQU $LAST[3] 500010 "PASSED" "***FAILED";
ECHO BOTH ": BLOBS  sum(length (B3))= " $LAST[2] " \n";

insert into BLOBS (ROW_NO, B1, B2, B3) values (3, '1234567890', NULL, N'1234567890');

select sum (length (B1)), sum (length (B2)), sum (length (B3)) from BLOBS;

ECHO BOTH $IF $EQU $LAST[1] 500010 "PASSED" "***FAILED";
ECHO BOTH ": BLOBS  sum(length (B1))= " $LAST[1] " \n";

ECHO BOTH $IF $EQU $LAST[2] 250010 "PASSED" "***FAILED";
ECHO BOTH ": BLOBS  sum(length (B2))= " $LAST[2] " \n";

ECHO BOTH $IF $EQU $LAST[3] 500020 "PASSED" "***FAILED";
ECHO BOTH ": BLOBS  sum(length (B3))= " $LAST[2] " \n";

ECHO BOTH "COMPLETED: Blob Check-Up\n";

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

-- ECHO BOTH "TEST MS SQL Server TPC-D Result\n";

select count(*) from MS_OUT_Q1;
ECHO BOTH $IF $EQU $LAST[1] 4 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $LAST[1] " Result loaded\n";

select count(*) from MS_OUT_Q2;
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $LAST[1] " Result loaded\n";

select count(*) from MS_OUT_Q3;
ECHO BOTH $IF $EQU $LAST[1] 98 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $LAST[1] " Result loaded\n";

select count(*) from MS_OUT_Q4;
ECHO BOTH $IF $EQU $LAST[1] 5 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $LAST[1] " Result loaded\n";

select count(*) from MS_OUT_Q5;
ECHO BOTH $IF $EQU $LAST[1] 5 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $LAST[1] " Result loaded\n";

select count(*) from MS_OUT_Q6;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $LAST[1] " Result loaded\n";

select count(*) from MS_OUT_Q7;
ECHO BOTH $IF $EQU $LAST[1] 4 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $LAST[1] " Result loaded\n";

select count(*) from MS_OUT_Q8;
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $LAST[1] " Result loaded\n";

select count(*) from MS_OUT_Q9;
ECHO BOTH $IF $EQU $LAST[1] 174 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $LAST[1] " Result loaded\n";

select count(*) from MS_OUT_Q10;
ECHO BOTH $IF $EQU $LAST[1] 392 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $LAST[1] " Result loaded\n";

select count(*) from MS_OUT_Q11;
ECHO BOTH $IF $EQU $LAST[1] 470 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $LAST[1] " Result loaded\n";

select count(*) from MS_OUT_Q12;
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $LAST[1] " Result loaded\n";

select count(*) from MS_OUT_Q13;
ECHO BOTH $IF $EQU $LAST[1] 25 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $LAST[1] " Result loaded\n";

select count(*) from MS_OUT_Q14;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $LAST[1] " Result loaded\n";

select count(*) from MS_OUT_Q15;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $LAST[1] " Result loaded\n";

select count(*) from MS_OUT_Q16;
ECHO BOTH $IF $EQU $LAST[1] 273 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $LAST[1] " Result loaded\n";

select count(*) from MS_OUT_Q17;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $LAST[1] " Result loaded\n";

select count(*) from MS_OUT_Q18;
ECHO BOTH $IF $EQU $LAST[1] 59 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $LAST[1] " Result loaded\n";

select count(*) from MS_OUT_Q19;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $LAST[1] " Result loaded\n";

select count(*) from MS_OUT_Q20;
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $LAST[1] " Result loaded\n";

select count(*) from MS_OUT_Q21;
ECHO BOTH $IF $EQU $LAST[1] 4 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $LAST[1] " Result loaded\n";

select count(*) from MS_OUT_Q22;
ECHO BOTH $IF $EQU $LAST[1] 7 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $LAST[1] " Result loaded\n";

-- ECHO BOTH "TEST MS SQL Server TPC-D Result Complete\n";

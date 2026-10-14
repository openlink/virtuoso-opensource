--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2026 OpenLink Software
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

-- Check datetime parse errors in strict SQL CAST and QUIETCAST.
ECHO BOTH "STARTED: datetime QUIETCAST tests\n";
SET ARGV[0] 0;
SET ARGV[1] 0;

-- Strict CAST must still report an invalid datetime lexical form.
SELECT CAST ('T23' AS DATETIME);
ECHO BOTH $IF $EQU $STATE 22007 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": strict narrow CAST state = " $STATE "\n";

-- Strict CAST must still report an invalid datetime lexical form.
SELECT CAST (N'T23' AS DATETIME);
ECHO BOTH $IF $EQU $STATE 22007 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": strict wide CAST state = " $STATE "\n";

-- Check narrow QUIETCAST without aborting valid rows.
SELECT CASE WHEN CAST ('T23' AS DATETIME) IS NULL THEN 1 ELSE 0 END
FROM DB.DBA.SYS_USERS WHERE U_NAME = 'dba' OPTION (QUIETCAST);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": narrow QUIETCAST query state\n";
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": narrow QUIETCAST row count\n";
ECHO BOTH $IF $EQU $LAST[1] "1" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": narrow QUIETCAST value = " $LAST[1] "\n";

-- Check wide QUIETCAST without aborting valid rows.
SELECT CASE WHEN CAST (N'T23' AS DATETIME) IS NULL THEN 1 ELSE 0 END
FROM DB.DBA.SYS_USERS WHERE U_NAME = 'dba' OPTION (QUIETCAST);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": wide QUIETCAST query state\n";
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": wide QUIETCAST row count\n";
ECHO BOTH $IF $EQU $LAST[1] "1" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": wide QUIETCAST value = " $LAST[1] "\n";

-- Check valid narrow CAST without aborting valid rows.
SELECT YEAR (CAST ('1798-01-01T00:00:00Z' AS DATETIME));
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": valid narrow CAST query state\n";
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": valid narrow CAST row count\n";
ECHO BOTH $IF $EQU $LAST[1] "1798" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": valid narrow CAST value = " $LAST[1] "\n";

-- Check valid wide CAST without aborting valid rows.
SELECT YEAR (CAST (N'1798-01-01T00:00:00Z' AS DATETIME));
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": valid wide CAST query state\n";
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": valid wide CAST row count\n";
ECHO BOTH $IF $EQU $LAST[1] "1798" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": valid wide CAST value = " $LAST[1] "\n";

-- Check SPARQL filter cast error without aborting valid rows.
SPARQL PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
SELECT ?v WHERE { VALUES ?v { "T23" "1798-01-01T00:00:00Z" }
FILTER (xsd:dateTime (?v) < "1900-01-01T00:00:00Z"^^xsd:dateTime) };
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": SPARQL filter cast error query state\n";
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": SPARQL filter cast error row count\n";
ECHO BOTH $IF $EQU $LAST[1] "1798-01-01T00:00:00Z" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": SPARQL filter cast error value = " $LAST[1] "\n";

ECHO BOTH "COMPLETED WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED: datetime QUIETCAST tests\n";

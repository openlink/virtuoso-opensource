--  
--  $Id: uri_wide_test.sql,v 1.1.6.1 2013/01/02 16:15:38 source Exp $
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

echo BOTH "STARTED: wide URI parser tests\n";

SET ARGV[0] 0;
SET ARGV[1] 0;

select WS.WS.EXPAND_URL (N'http://a/b/c/d;p?q#f', N'g:h');
ECHO BOTH $IF $EQU $LAST[1] 'g:h'  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ABSOLUTE URI g:h : " $LAST[1] "\n";

select WS.WS.EXPAND_URL (N'http://a/b/c/d;p?q#f', N'g');
ECHO BOTH $IF $EQU $LAST[1] 'http://a/b/c/g'  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ABSOLUTE URI http://a/b/c/g : " $LAST[1] "\n";

select WS.WS.EXPAND_URL (N'http://a/b/c/d;p?q#f', N'./g');
ECHO BOTH $IF $EQU $LAST[1] 'http://a/b/c/g'  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ABSOLUTE URI http://a/b/c/g : " $LAST[1] "\n";

select WS.WS.EXPAND_URL (N'http://a/b/c/d;p?q#f', N'g/');
ECHO BOTH $IF $EQU $LAST[1] 'http://a/b/c/g/'  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ABSOLUTE URI http://a/b/c/g/ : " $LAST[1] "\n";

select WS.WS.EXPAND_URL (N'http://a/b/c/d;p?q#f', N'/g');
ECHO BOTH $IF $EQU $LAST[1] 'http://a/g'  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ABSOLUTE URI http://a/g : " $LAST[1] "\n";

select WS.WS.EXPAND_URL (N'http://a/b/c/d;p?q#f', N'//g');
ECHO BOTH $IF $EQU $LAST[1] 'http://g/'  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ABSOLUTE URI http://g/ : " $LAST[1] "\n";

select WS.WS.EXPAND_URL (N'http://a/b/c/d;p?q#f', N'?y');
ECHO BOTH $IF $EQU $LAST[1] 'http://a/b/c/d;p?y'  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ABSOLUTE URI http://a/b/c/d;p?y : " $LAST[1] "\n";

select WS.WS.EXPAND_URL (N'http://a/b/c/d;p?q#f', N'g?y');
ECHO BOTH $IF $EQU $LAST[1] 'http://a/b/c/g?y'  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ABSOLUTE URI http://a/b/c/g?y : " $LAST[1] "\n";

select WS.WS.EXPAND_URL (N'http://a/b/c/d;p?q#f', N'g?y/./x');
ECHO BOTH $IF $EQU $LAST[1] 'http://a/b/c/g?y/./x'  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ABSOLUTE URI http://a/b/c/g?y/./x : " $LAST[1] "\n";

select WS.WS.EXPAND_URL (N'http://a/b/c/d;p?q#f', N'#s');
ECHO BOTH $IF $EQU $LAST[1] 'http://a/b/c/d;p?q#s'  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ABSOLUTE URI http://a/b/c/d;p?q#s : " $LAST[1] "\n";

select WS.WS.EXPAND_URL (N'http://a/b/c/d;p?q#f', N'g#s');
ECHO BOTH $IF $EQU $LAST[1] 'http://a/b/c/g#s'  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ABSOLUTE URI http://a/b/c/g#s : " $LAST[1] "\n";

select WS.WS.EXPAND_URL (N'http://a/b/c/d;p?q#f', N'g#s/./x');
ECHO BOTH $IF $EQU $LAST[1] 'http://a/b/c/g#s/./x'  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ABSOLUTE URI http://a/b/c/g#s/./x : " $LAST[1] "\n";

select WS.WS.EXPAND_URL (N'http://a/b/c/d;p?q#f', N'g?y#s');
ECHO BOTH $IF $EQU $LAST[1] 'http://a/b/c/g?y#s'  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ABSOLUTE URI http://a/b/c/g?y#s : " $LAST[1] "\n";

select WS.WS.EXPAND_URL (N'http://a/b/c/d;p?q#f', N';x');
ECHO BOTH $IF $EQU $LAST[1] 'http://a/b/c/d;x'  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ABSOLUTE URI http://a/b/c/d;x : " $LAST[1] "\n";

select WS.WS.EXPAND_URL (N'http://a/b/c/d;p?q#f', N'g;x');
ECHO BOTH $IF $EQU $LAST[1] 'http://a/b/c/g;x'  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ABSOLUTE URI http://a/b/c/g;x : " $LAST[1] "\n";

select WS.WS.EXPAND_URL (N'http://a/b/c/d;p?q#f', N'g;x?y#s');
ECHO BOTH $IF $EQU $LAST[1] 'http://a/b/c/g;x?y#s'  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ABSOLUTE URI http://a/b/c/g;x?y#s : " $LAST[1] "\n";

select WS.WS.EXPAND_URL (N'http://a/b/c/d;p?q#f', N'.');
ECHO BOTH $IF $EQU $LAST[1] 'http://a/b/c/'  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ABSOLUTE URI http://a/b/c/ : " $LAST[1] "\n";

select WS.WS.EXPAND_URL (N'http://a/b/c/d;p?q#f', N'./');
ECHO BOTH $IF $EQU $LAST[1] 'http://a/b/c/'  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ABSOLUTE URI http://a/b/c/ : " $LAST[1] "\n";

select WS.WS.EXPAND_URL (N'http://a/b/c/d;p?q#f', N'..');
ECHO BOTH $IF $EQU $LAST[1] 'http://a/b/'  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ABSOLUTE URI http://a/b/ : " $LAST[1] "\n";

select WS.WS.EXPAND_URL (N'http://a/b/c/d;p?q#f', N'../');
ECHO BOTH $IF $EQU $LAST[1] 'http://a/b/'  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ABSOLUTE URI http://a/b/ : " $LAST[1] "\n";

select WS.WS.EXPAND_URL (N'http://a/b/c/d;p?q#f', N'../g');
ECHO BOTH $IF $EQU $LAST[1] 'http://a/b/g'  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ABSOLUTE URI http://a/b/g : " $LAST[1] "\n";

select WS.WS.EXPAND_URL (N'http://a/b/c/d;p?q#f', N'../..');
ECHO BOTH $IF $EQU $LAST[1] 'http://a/'  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ABSOLUTE URI http://a/ : " $LAST[1] "\n";

select WS.WS.EXPAND_URL (N'http://a/b/c/d;p?q#f', N'../../');
ECHO BOTH $IF $EQU $LAST[1] 'http://a/'  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ABSOLUTE URI http://a/ : " $LAST[1] "\n";

select WS.WS.EXPAND_URL (N'http://a/b/c/d;p?q#f', N'../../g');
ECHO BOTH $IF $EQU $LAST[1] 'http://a/g'  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ABSOLUTE URI http://a/g : " $LAST[1] "\n";

-- Abnormal relative URI
-- RFC 1808 recommendation http://a/../g
select WS.WS.EXPAND_URL (N'http://a/b/c/d;p?q#f', N'../../../g');
ECHO BOTH $IF $EQU $LAST[1] 'http://a/g'  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ABSOLUTE URI http://a/g : " $LAST[1] "\n";


-- RFC 1808 recommendation http://a/../../g
select WS.WS.EXPAND_URL (N'http://a/b/c/d;p?q#f', N'../../../../g');
ECHO BOTH $IF $EQU $LAST[1] 'http://a/g'  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ABSOLUTE URI http://a/g : " $LAST[1] "\n";

select WS.WS.EXPAND_URL (N'http://a/b/c/d;p?q#f', N'/./g');
ECHO BOTH $IF $EQU $LAST[1] 'http://a/./g'  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ABSOLUTE URI http://a/./g : " $LAST[1] "\n";

select WS.WS.EXPAND_URL (N'http://a/b/c/d;p?q#f', N'/../g');
ECHO BOTH $IF $EQU $LAST[1] 'http://a/../g'  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ABSOLUTE URI http://a/../g : " $LAST[1] "\n";

select WS.WS.EXPAND_URL (N'http://a/b/c/d;p?q#f', N'g.');
ECHO BOTH $IF $EQU $LAST[1] 'http://a/b/c/g.'  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ABSOLUTE URI http://a/b/c/g. : " $LAST[1] "\n";

select WS.WS.EXPAND_URL (N'http://a/b/c/d;p?q#f', N'.g');
ECHO BOTH $IF $EQU $LAST[1] 'http://a/b/c/.g'  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ABSOLUTE URI http://a/b/c/.g : " $LAST[1] "\n";

select WS.WS.EXPAND_URL (N'http://a/b/c/d;p?q#f', N'g..');
ECHO BOTH $IF $EQU $LAST[1] 'http://a/b/c/g..'  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ABSOLUTE URI http://a/b/c/g.. : " $LAST[1] "\n";

select WS.WS.EXPAND_URL (N'http://a/b/c/d;p?q#f', N'..g');
ECHO BOTH $IF $EQU $LAST[1] 'http://a/b/c/..g'  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ABSOLUTE URI http://a/b/c/..g : " $LAST[1] "\n";

select WS.WS.EXPAND_URL (N'http://a/b/c/d;p?q#f', N'./../g');
ECHO BOTH $IF $EQU $LAST[1] 'http://a/b/g'  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ABSOLUTE URI http://a/b/g : " $LAST[1] "\n";

select WS.WS.EXPAND_URL (N'http://a/b/c/d;p?q#f', N'./g/.');
ECHO BOTH $IF $EQU $LAST[1] 'http://a/b/c/g/'  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ABSOLUTE URI http://a/b/c/g/ : " $LAST[1] "\n";

select WS.WS.EXPAND_URL (N'http://a/b/c/d;p?q#f', N'g/./h');
ECHO BOTH $IF $EQU $LAST[1] 'http://a/b/c/g/h'  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ABSOLUTE URI http://a/b/c/g/h : " $LAST[1] "\n";

select WS.WS.EXPAND_URL (N'http://a/b/c/d;p?q#f', N'g/../h');
ECHO BOTH $IF $EQU $LAST[1] 'http://a/b/c/h'  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ABSOLUTE URI http://a/b/c/h : " $LAST[1] "\n";

select WS.WS.EXPAND_URL (N'http://a/b/c/d;p?q#f', N'http:g');
ECHO BOTH $IF $EQU $LAST[1] 'http:g'  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ABSOLUTE URI http:g : " $LAST[1] "\n";

select WS.WS.EXPAND_URL (N'http://a/b/c/d;p?q#f', N'http:');
ECHO BOTH $IF $EQU $LAST[1] 'http:'  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ABSOLUTE URI http: : " $LAST[1] "\n";

ECHO BOTH "COMPLETED WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED: wide URI parser tests\n";

--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2017 OpenLink Software
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
--ECHO BOTH "\nnwxml3c - Attribute tests\n"

select count(*) from XML_TEXT2 where XT_FILE like '%proce%' and xcontains (XT_TEXT, '//sect1[@id = "whilestmt"]');
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " rows in xcontains //sect1[@id = ''whilestmt''] where XT_FILE like '%proce%'\n";

select count(*) from XML_TEXT2 where XT_FILE like '%proce%' and xcontains (XT_TEXT, '//sect2[@id like "whilestmt"]');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " rows in xcontains //sect2[@id like ''whilestmt''] where XT_FILE like '%proce%'\n";

select count(*) from XML_TEXT2 where XT_FILE like '%proce%' and xcontains (XT_TEXT, '//sect2[@id = "whilestmt"]');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " rows in xcontains //sect2[@id = ''whilestmt''] where XT_FILE like '%proce%'\n";

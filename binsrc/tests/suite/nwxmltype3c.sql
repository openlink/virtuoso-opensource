--
--  $Id: nwxmltype3c.sql,v 1.3.10.1 2013/01/02 16:14:48 source Exp $
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2019 OpenLink Software
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
--echo both "\nnwxml3c - Attribute tests\n"

select count(*) from XML_TEXT2 where XT_FILE like '%proce%' and xcontains (XT_TEXT, '//sect1[@id = "whilestmt"]');
echo both $if $equ $last[1] 0 "PASSED" "*** FAILED";
echo both ": " $last[1] " rows in xcontains //sect1[@id = ''whilestmt''] where XT_FILE like '%proce%'\n";

select count(*) from XML_TEXT2 where XT_FILE like '%proce%' and xcontains (XT_TEXT, '//sect2[@id like "whilestmt"]');
echo both $if $equ $last[1] 1 "PASSED" "*** FAILED";
echo both ": " $last[1] " rows in xcontains //sect2[@id like ''whilestmt''] where XT_FILE like '%proce%'\n";

select count(*) from XML_TEXT2 where XT_FILE like '%proce%' and xcontains (XT_TEXT, '//sect2[@id = "whilestmt"]');
echo both $if $equ $last[1] 1 "PASSED" "*** FAILED";
echo both ": " $last[1] " rows in xcontains //sect2[@id = ''whilestmt''] where XT_FILE like '%proce%'\n";

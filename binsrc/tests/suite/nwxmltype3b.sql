--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2012 OpenLink Software
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
select count(*) from XML_TEXT_FRAGS where cast(XTF_FRAG1 as varchar) <> cast(XTF_FRAG2 as varchar);
echo both $if $equ $last[1] 0 "PASSED" "*** FAILED";
echo both ": " $last[1] " explicitly cropped XMLType instances were recovered from log with errors\n";
select count(*) from XML_TEXT_FRAGS where cast(XTF_FRAG1 as varchar) <> cast(XTF_FRAG3 as varchar);
echo both $if $equ $last[1] 0 "PASSED" "*** FAILED";
echo both ": " $last[1] " implicitly cropped XMLType instances were recovered from log with errors\n";

select LXML_NAME, FRAG from LONG_XML_TEXTS where xpath_contains (LXML_DOC, '//*', FRAG);
select count (FRAG) from LONG_XML_TEXTS where xpath_contains (LXML_DOC, '//*', FRAG);
-- There was an bug here: must be 19 frags, not 11 or 15.
echo both $if $equ $last[1] 19 "PASSED" "*** FAILED";
echo both ": " $last[1] " fragments in XMLType column after log replay\n";

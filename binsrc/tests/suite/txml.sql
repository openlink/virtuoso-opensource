--
--  txml.sql
--
--  $Id: txml.sql,v 1.8.10.1 2013/01/02 16:15:36 source Exp $
--
--  XML tests
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

echo BOTH "STARTED: XML TEST\n";

CONNECT;

-- Insert a simple xml document
insertxml('<?xml version="1.0"?><!DOCTYPE book ><book></book>',NULL,NULL,1);
ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
ECHO BOTH ": Simple XML document inserted STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- Check if the number of entities is correct
select count (*) from VXML_ENTITY;
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " entities.\n";

-- Delete the xml document
delxml('00000008');
select count (*) from VXML_ENTITY;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " entities.\n";

-- Insert a simple xml document with a comment
insertxml('<?xml version="1.0"?><!DOCTYPE book ><book><!-- A comment --></book>',NULL,NULL,1);
ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
ECHO BOTH ": Simple XML document inserted STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- Check if the number of entities is correct
select count (*) from VXML_ENTITY;
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " entities.\n";

-- Delete the xml document
delxml('00000008');
select count (*) from VXML_ENTITY;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " entities.\n";

-- Insert a xml document
insertxml('<?xml version="1.0"?><!DOCTYPE book ><book>My book<chapter>My first chapter
in two parts
<para>My first paragraph</para>
Just a simple text fragment
<para>My second paragraph</para>
The end of my chapter
</chapter>
</book>',NULL,NULL,1);
ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
ECHO BOTH ": XML document without attributes inserted STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- Check if the number of entities is correct
select count (*) from VXML_ENTITY;
ECHO BOTH $IF $EQU $LAST[1] 6 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " entities.\n";

-- Delete the xml document
delxml('00000008');
select count (*) from VXML_ENTITY;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " entities.\n";

-- Insert a xml document with attributes
insertxml('<?xml version="1.0"?><!DOCTYPE book ><book>My book<chapter>My first chapter
in two parts
<para align="right">My first paragraph</para>
Just a simple text fragment
<para align="left">My second paragraph</para>
The end of my chapter
</chapter>
</book>',NULL,NULL,1);
ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
ECHO BOTH ": XML document with attributes inserted STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- Check if the number of entities is correct
select count (*) from VXML_ENTITY;
ECHO BOTH $IF $EQU $LAST[1] 6 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " entities.\n";

-- Delete the xml document
delxml('00000008');
select count (*) from VXML_ENTITY;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " entities.\n";

-- Insert a xml document with attributes into a entity mapped table
drop table para;
create table para (under VXML_ENTITY, align varchar, style varchar);
ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
ECHO BOTH ": Entity table with attributes created STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

xml_attr('align');
ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
ECHO BOTH ": align attribute inserted STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

xml_attr('style');
ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
ECHO BOTH ": style attribute inserted STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

xml_element_table('DB.DBA.PARA','para',vector('ALIGN','align'));
xml_element_table('DB.DBA.PARA','para',vector('STYLE','style'));
ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
ECHO BOTH ": align, style attributes mapped STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

insertxml('<?xml version="1.0"?><!DOCTYPE book ><book>My book<chapter>My first chapter
in two parts
<para align="right" style="bold">My first paragraph</para>
Just a simple text fragment
<para align="left" style="italic">My second paragraph</para>
The end of my chapter
</chapter>
</book>',NULL,NULL,1);
ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
ECHO BOTH ": XML document with attributes inserted STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- Check if the number of entities is correct
select count (*) from VXML_ENTITY;
ECHO BOTH $IF $EQU $LAST[1] 6 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " entities.\n";

select count (*) from DB.DBA.PARA;
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " entities with align, style attribute.\n";

-- Delete the xml document
delxml('00000008');
select count (*) from VXML_ENTITY;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " entities.\n";

echo BOTH "COMPLETED: XML TEST\n";

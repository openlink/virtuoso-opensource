--  
--  $Id: txmlload.sql,v 1.7.10.1 2013/01/02 16:15:36 source Exp $
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

-- xml_test ('http://localhost:$U{HTTPPORT}/docsrc/altable.xml');
xml_test ('http://localhost:$U{HTTPPORT}/docsrc/dbconcepts.xml');
xml_test ('http://localhost:$U{HTTPPORT}/docsrc/intl.xml');
xml_test ('http://localhost:$U{HTTPPORT}/docsrc/odbcimplementation.xml');
xml_test ('http://localhost:$U{HTTPPORT}/docsrc/ptune.xml');
xml_test ('http://localhost:$U{HTTPPORT}/docsrc/repl.xml');
xml_test ('http://localhost:$U{HTTPPORT}/docsrc/server.xml');
xml_test ('http://localhost:$U{HTTPPORT}/docsrc/sqlfunctions.xml');
xml_test ('http://localhost:$U{HTTPPORT}/docsrc/sqlprocedures.xml');
xml_test ('http://localhost:$U{HTTPPORT}/docsrc/sqlreference.xml');
xml_test ('http://localhost:$U{HTTPPORT}/docsrc/user.xml');
xml_test ('http://localhost:$U{HTTPPORT}/docsrc/vdbconcepts.xml');
xml_test ('http://localhost:$U{HTTPPORT}/docsrc/virtdocs.xml');


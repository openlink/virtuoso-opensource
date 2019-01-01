--
--  $Id: tsxml.sql,v 1.5.10.2 2013/01/02 16:15:29 source Exp $
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

xml_add_system_path('file://schemasource/system');
select xml_load_schema_decl('file://schemasource/xmlsource/schema', 'docbook.xsd', 'UTF-8', 'x-any');
select xml_load_schema_decl('file://schemasource/xmlsource/test0000', 'test0002.xsd', 'UTF-8', 'x-any');
select xml_load_schema_decl('file://schemasource/xmlsource/test0000', 'tmain.xsd', 'UTF-8', 'x-any');
select xml_load_schema_decl('file://schemasource/xmlsource/test0001', 'keys-primer.xsd', 'UTF-8', 'x-any');

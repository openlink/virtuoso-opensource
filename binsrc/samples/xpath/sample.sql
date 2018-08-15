--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2018 OpenLink Software
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
select xpath_eval('//book',xtree_doc(file_to_string('file://../tests/wb/inputs/XqW3cUseCases/bib.xml')),0);

document("bib.xml")/bib/book[publisher = "Addison-Wesley" and @year > 1991]
select xpath_eval('//section[section.title = "Procedure"]',xtree_doc(file_to_string('xpath/data/report1.xml')),2); 
select xpath_eval('//item_tuple [start_date <= "1999-02-15" and end_date >= "1999-02-15" and contains(description, "Bicycle")]',xtree_doc(file_to_string('xpath/data/items.xml')),2); 

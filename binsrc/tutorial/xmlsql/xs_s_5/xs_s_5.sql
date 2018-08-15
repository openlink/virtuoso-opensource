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
drop table xs_s_5;

create table xs_s_5 (tr_file varchar primary key, tr_text long varchar);

create procedure xs_s_5_trf ()
{
  declare result any;
  for select xt_file, xt_text from xml_text2 do
    {
      result := xslt (TUTORIAL_XSL_DIR () || '/tutorial/xmlsql/xs_s_5/xs_s_5.xsl', xml_tree_doc (xt_text));
      insert into xs_s_5 values (xt_file, result);
    }
}
;

xs_s_5_trf ();

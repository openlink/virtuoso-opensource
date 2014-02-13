--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2014 OpenLink Software
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
create procedure make_vspx_docs (in base varchar)
{
  declare arr any;
  declare i, l int;
  arr := xpath_eval ('/vspx-elements/refentry',xslt ('file:/vspx/xsd2doc.xsl', xml_tree_doc (file_to_string (base || 'binsrc/vspx/vspx.xsd'))), 0);
  i := 0; l := length (arr);
  while (i < l)
    {
      declare res, xt, name any;
      res := string_output ();
      http_value (arr[i], null, res);
      res := string_output_string (res);
      name := cast (xpath_eval ('/refentry/@id', xml_tree_doc (res)) as varchar);
      --if (not (name like 'after_%' or name like 'before_%' or name like 'on_post%'))
      string_to_file (concat (base, 'binsrc/vspx/docs/',name,'.xml'), res, -2);
      i := i + 1;
    }
}
;

make_vspx_docs('/home/virtuoso/');

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
drop function MKVSPXDOC;
create function MKVSPXDOC () returns varchar
{
  declare _meta any;
  declare _doc any;
  declare _ses, _arr any;
  declare i, l any;
  _meta := xtree_doc (
    file_to_string ('vspx/vspxmeta.xml'),
    0,
    'file://vspx/vspxdoc.xml',
    'LATIN-1');
  xslt_stale ('file://vspx/vspxmeta2doc.xsl');
  _doc := xslt ('file://vspx/vspxmeta2doc.xsl', _meta);
  _ses := string_output();
  http_value (_doc, 0, _ses);
  string_to_file ('docsrc/xmlsource/vspxdoc.xml', string_output_string(_ses), -2);

  _arr := xpath_eval ('/sect2/refentry', _doc, 0);
  i := 0; l := length (_arr);
  while (i < l)
    {
      declare name any;
      _ses := string_output ();
      http_value (_arr[i], null, _ses);
      name := cast (xpath_eval ('@id', _arr[i]) as varchar);
      --if (not (name like 'after_%' or name like 'before_%' or name like 'on_post%'))
      string_to_file (concat ('docsrc/xmlsource/vspx_ref/',name,'.xml'), string_output_string(_ses), -2);
      i := i + 1;
    }

  return 'Done';
}
;

select MKVSPXDOC();

ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": Composing VSPX reference items: STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

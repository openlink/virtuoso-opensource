--  
--  $Id: nwxml2_vad.sql,v 1.1.8.1 2013/01/02 16:14:46 source Exp $
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

create procedure xml_text_load (in f varchar)
{
  if (exists (select 1 from XML_TEXT where XT_FILE = f))
    update XML_TEXT set XT_TEXT = DB.DBA.get_blob_from_dav (concat('/DAV/' , f)) where XT_FILE = f;
  else
    insert into XML_TEXT (XT_ID, XT_FILE, XT_TEXT)
      values (sequence_next ('XML_TEXT'), f, DB.DBA.get_blob_from_dav (concat('/DAV/' , f)));
}
;

create procedure xml_text_load_r (in f varchar)
{
  declare str any;
  declare ni int;
  str := file_to_string (f);
  if (exists (select 1 from XML_TEXT where XT_FILE = f))
    update XML_TEXT set XT_TEXT = file_to_string (f) where XT_FILE = f;
  else
    {
      ni := coalesce ((select xt_id + 1 from xml_text order by xt_id desc), 1);
      insert into XML_TEXT (XT_ID, XT_FILE, XT_TEXT)
        values (ni, f, str);
    }
}
;

create procedure xml_text_insert (in f varchar)
{
            insert into XML_TEXT (XT_ID, XT_FILE, XT_TEXT)
      values (sequence_next ('XML_TEXT'), NULL,  f);
}
;

create procedure xml_html_load (in f varchar)
{
  declare text, tree, s any;
  whenever sqlstate '40001' goto deadl;
 again:
  text := file_to_string (f);
  tree := xml_tree (text, 1, '', 'LATIN-1');
  if (not (isarray (tree)))
      signal ('XML00', 'Malformed html file');
  s := string_output ();
  http_value (xml_tree_doc (tree), null, s);
  if (exists (select 1 from XML_TEXT where XT_FILE = f))
    update XML_TEXT set XT_TEXT = s where XT_FILE = f;
  else
    insert into XML_TEXT (XT_ID, XT_FILE, XT_TEXT)
      values (sequence_next ('XML_TEXT'), f, s);
  return;
 deadl:
  rollback work;
  goto again;
}
;


create procedure pxml_html_load (in f varchar)
{
  declare text, tree, s, xper any;
  whenever sqlstate '40001' goto deadl;
 again:
  text := file_to_string (f);
  tree := xml_tree (text, 1, '', 'LATIN-1');
  if (not (isarray (tree)))
      signal ('XML00', 'Malformed html file');
  s := string_output ();
  http_value (xml_tree_doc (tree), null, s);
  xper := xml_persistent (string_output_string (s));
  if (exists (select 1 from XML_TEXT where XT_FILE = f))
    update XML_TEXT set XT_TEXT = xper where XT_FILE = f;
  else
    insert into XML_TEXT (XT_ID, XT_FILE, XT_TEXT)
      values (sequence_next ('XML_TEXT'), f, xper);
  return;
 deadl:
  rollback work;
  goto again;
}
;
xml_text_load ('docsrc/dbconcepts.xml');
xml_text_load ('docsrc/intl.xml');
xml_text_load ('docsrc/odbcimplementation.xml');
xml_text_load ('docsrc/ptune.xml');
xml_text_load ('docsrc/repl.xml');
xml_text_load ('docsrc/server.xml');
xml_text_load ('docsrc/sqlprocedures.xml');
xml_text_load ('docsrc/sqlreference.xml');
xml_text_load ('docsrc/vdbconcepts.xml');
xml_text_load ('docsrc/virtdocs.xml');

DB.DBA.vt_inc_index_DB_DBA_XML_TEXT ();

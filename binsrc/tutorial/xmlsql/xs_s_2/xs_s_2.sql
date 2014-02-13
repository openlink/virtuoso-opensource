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
drop index XT_FILE;

drop table XML_TEXT3;

create table XML_TEXT3 (XT_ID integer, XT_FILE varchar, XT_TEXT long varchar identified by XT_FILE, primary key (XT_ID));

create index XT_FILE on XML_TEXT3 (XT_FILE);

create text xml index on XML_TEXT3 (XT_TEXT) with key XT_ID;

sequence_set ('XML_TEXT3', 1, 0);

vt_batch_update ('XML_TEXT3', 'ON', NULL);

vt_index_DB_DBA_XML_TEXT3 (0);

create procedure remove_entity (in f varchar)
{
  declare r, f1 varchar;
  f1 := f;
  while ((r := regexp_match ('&[^#;]*;', f1)) is not null)
    {
      if (r not in ('&amp;', '&lt;', '&gt;', '&apos;'))
        f := replace (f, r, '');
      f1 := replace (f1, r, '');
    }
  return f;
};

create procedure xml_per_load (in f varchar)
{
  declare text, text1, tree, s, xper any;
  whenever sqlstate '40001' goto deadl;
 again:
  text1 := coalesce ((select blob_to_string (RES_CONTENT) from WS.WS.SYS_DAV_RES where RES_FULL_PATH = concat ('/DAV/', f)), null);
  if (text1 is null)
    return;
  text1 := remove_entity (text1);
  text := xml_persistent (text1);
  if (exists (select 1 from XML_TEXT3 where XT_FILE = f))
    update XML_TEXT3 set XT_TEXT = text where XT_FILE = f;
  else
    insert into XML_TEXT3 (XT_ID, XT_FILE, XT_TEXT)
      values (sequence_next ('XML_TEXT3'), f, text);
  return;
 deadl:
  rollback work;
  goto again;
};

xml_per_load ('docsrc/dbconcepts.xml');

xml_per_load ('docsrc/intl.xml');

xml_per_load ('docsrc/odbcimplementation.xml');

xml_per_load ('docsrc/ptune.xml');

xml_per_load ('docsrc/repl.xml');

xml_per_load ('docsrc/server.xml');

xml_per_load ('docsrc/sqlfunctions.xml');

xml_per_load ('docsrc/sqlprocedures.xml');

xml_per_load ('docsrc/sqlreference.xml');

xml_per_load ('docsrc/vdbconcepts.xml');

--xml_per_load ('docsrc/virtdocs.xml');

vt_inc_index_DB_DBA_XML_TEXT3 ();


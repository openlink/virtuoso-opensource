--
--  $Id: nwxmlco.sql,v 1.4.10.1 2013/01/02 16:14:47 source Exp $
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2016 OpenLink Software
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



drop table xml_text_xt_text_words;

alter table xml_text add xt_tsid any not null;

update xml_text set xt_tsid = composite (- xt_id, xt_id);

create unique index xt_tsid on xml_text (xt_tsid);

create text index on xml_text (xt_text) with key xt_tsid clustered with (xt_file);

select xt_id from xml_text where contains (xt_text, 'database and transaction',0,r, 'desc', 'start_id', composite (7));

vt_batch_update ('DB.DBA.XML_TEXT', 'ON', 0);

delete from xml_text;

vt_inc_index_db_dba_xml_text ();

select count (*) from xml_text_xt_text_words;

create procedure xml_text_load (in f varchar)
{
  if (exists (select 1 from XML_TEXT where XT_FILE = f))
    update XML_TEXT set XT_TEXT = file_to_string (f) where XT_FILE = f;
  else
    {
      declare id integer;
      id := sequence_next ('XML_TEXT');
      insert into XML_TEXT (XT_ID, xt_tsid, XT_FILE, XT_TEXT)
	values (id, composite (id, id), f, file_to_string (f));
    }
}

xml_text_load ('docsrc/dbconcepts.xml');
xml_text_load ('docsrc/intl.xml');
xml_text_load ('docsrc/odbcimplementation.xml');
xml_text_load ('docsrc/ptune.xml');
xml_text_load ('docsrc/repl.xml');
xml_text_load ('docsrc/server.xml');
xml_text_load ('docsrc/sqlfunctions.xml');
xml_text_load ('docsrc/sqlprocedures.xml');
xml_text_load ('docsrc/sqlreference.xml');
xml_text_load ('docsrc/vdbconcepts.xml');
xml_text_load ('docsrc/virtdocs.xml');
xml_text_load ('ce.xml');

vt_inc_index_db_dba_xml_text ();

select XT_FILE from xml_text where contains (xt_text, 'database', 'offband',  xt_fffile);

select XT_FILE from xml_text where contains (xt_text, 'database', 'offband',  xt_file);

select XT_FILE from xml_text where contains (xt_text, '"datab* serv*"');
select XT_FILE from xml_text where contains (xt_text, '"datab* serv*"', 'desc');

select XT_FILE from xml_text where contains (xt_text, 'virtuoso', start_id, 3, end_id, 7);
select XT_FILE from xml_text where contains (xt_text, 'virtuoso', start_id, 7, end_id, 3,  descending);




create text trigger on xml_text (xt_text);

"tt_query_XML_TEXT" ('transaction and autocommit', 0, 'comment', null);;

vt_batch_update ('DB.DBA.XML_TEXT', 'OFF', 0);

update xml_text set xt_text = xt_text;

select count (*) from xml_text_xt_text_hit;



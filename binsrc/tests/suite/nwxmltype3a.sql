--
--  $Id: nwxmltype3a.sql,v 1.5.10.1 2013/01/02 16:14:48 source Exp $
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
--set echo on;
--set verbose on;

drop table XML_TEXT_FRAGS;
create table XML_TEXT_FRAGS
  (
	XTF_ID		integer,
	XTF_FRAG1	DB.DBA.XMLType,
	XTF_FRAG2	DB.DBA.XMLType,
	XTF_FRAG3	DB.DBA.XMLType,
	primary key (XTF_ID)
  );

drop table LONG_XML_TEXTS;
create table LONG_XML_TEXTS
  (
	LXML_NAME varchar not null primary key,
	LXML_DOC long xml identified by LXML_NAME
  );

create procedure fill_xtf_1_2()
{
  declare _id integer;
  _id := 1;
  delete from XML_TEXT_FRAGS;
  for
    select _frag
      from XML_TEXT2
      where xpath_contains(XT_TEXT,'//*',_frag)
      order by XT_ID
  do
  {
    _id := _id + 1;
    insert into XML_TEXT_FRAGS
	( XTF_ID	, XTF_FRAG1		, XTF_FRAG2	)
    values
	( _id		, xper_cut(_frag)	, _frag		);
  }
}
;

create procedure fill_xtf_3()
{
  declare _id integer;
  _id := 1;
  for
    select _frag
      from XML_TEXT2
      where xpath_contains(XT_TEXT,'//*',_frag)
      order by XT_ID
  do
  {
    _id := _id + 1;
    update XML_TEXT_FRAGS
      set
	XTF_FRAG2	= xper_cut(_frag),
	XTF_FRAG3	= _frag
      where XTF_ID = _id;
  }
}
;

fill_xtf_1_2();

select count(*) from XML_TEXT_FRAGS where cast(XTF_FRAG1 as varchar) <> cast(XTF_FRAG2 as varchar);
echo both $if $equ $last[1] 0 "PASSED" "*** FAILED";
echo both ": " $last[1] " XMLType instances were cropped with errors\n";

insert into LONG_XML_TEXTS (LXML_NAME, LXML_DOC) values ('/Doc'	, '<a/>');
insert into LONG_XML_TEXTS (LXML_NAME, LXML_DOC) values ('/Doc/cha1'	, '<a/>');
insert into LONG_XML_TEXTS (LXML_NAME, LXML_DOC) values ('/Doc/cha2'	, '<a/>');
insert into LONG_XML_TEXTS (LXML_NAME, LXML_DOC) values ('/Doc/sub11'	, '<a/>');
insert into LONG_XML_TEXTS (LXML_NAME, LXML_DOC) values ('/Doc/sub12'	, '<a/>');
insert into LONG_XML_TEXTS (LXML_NAME, LXML_DOC) values ('/Doc/sub21'	, '<a/>');
insert into LONG_XML_TEXTS (LXML_NAME, LXML_DOC) values ('/Doc/sub22'	, '<a/>');

checkpoint;

fill_xtf_3();

select count(*) from XML_TEXT_FRAGS where cast(XTF_FRAG1 as varchar) <> cast(XTF_FRAG2 as varchar);
echo both $if $equ $last[1] 0 "PASSED" "*** FAILED";
echo both ": " $last[1] " explicitly cropped XMLType instances were filled with errors\n";
select count(*) from XML_TEXT_FRAGS where cast(XTF_FRAG1 as varchar) <> cast(XTF_FRAG3 as varchar);
echo both $if $equ $last[1] 0 "PASSED" "*** FAILED";
echo both ": " $last[1] " implicitly cropped XMLType instances were filled with errors\n";

update LONG_XML_TEXTS set LXML_DOC = '<?xml version="1.0"?>
<!DOCTYPE book [
  <!ENTITY cha1ref SYSTEM "Doc/cha1">
  <!ENTITY cha2ref SYSTEM "Doc/cha2">
  <!ENTITY sub11ref SYSTEM "Doc/sub11">
  <!ENTITY sub12ref SYSTEM "Doc/sub12">
  <!ENTITY sub21ref SYSTEM "Doc/sub21">
  <!ENTITY sub22ref SYSTEM "Doc/sub22">
  ]>
<!-- Book --> <book>&cha1ref;&cha2ref;<cha id="3"><sub id="3.1">TEXT31</sub>TEXT3</cha></book>'
where LXML_NAME = '/Doc';

update LONG_XML_TEXTS set LXML_DOC =
'<!-- Cha1 --> <cha id="1">&sub11ref;&sub12ref; <sub id="1.3">TEXT13</sub>TEXT1</cha> '
where LXML_NAME = '/Doc/cha1';

update LONG_XML_TEXTS set LXML_DOC =
'<!-- Cha2 --> <cha id="2">&sub21ref;&sub22ref; <sub id="2.3">TEXT23</sub>TEXT2</cha> '
where LXML_NAME = '/Doc/cha2';

update LONG_XML_TEXTS set LXML_DOC =
'<!-- Sub11 --> <sub id="1.1">TEXT11</sub> '
where LXML_NAME = '/Doc/sub11';

update LONG_XML_TEXTS set LXML_DOC =
'<!-- Sub12 --> <sub id="1.2">TEXT12</sub> '
where LXML_NAME = '/Doc/sub12';

update LONG_XML_TEXTS set LXML_DOC =
'<!-- Sub21 --> <sub id="2.1">TEXT21</sub> '
where LXML_NAME = '/Doc/sub21';

update LONG_XML_TEXTS set LXML_DOC =
'<!-- Sub21 --> <sub id="2.2">TEXT22</sub> '
where LXML_NAME = '/Doc/sub22';

select LXML_NAME, FRAG from LONG_XML_TEXTS where xpath_contains (LXML_DOC, '//*', FRAG);
select count (FRAG) from LONG_XML_TEXTS where xpath_contains (LXML_DOC, '//*', FRAG);
-- There was an bug here: must be 19 frags, not 11 or 15.
echo both $if $equ $last[1] 19 "PASSED" "*** FAILED";
echo both ": " $last[1] " fragments in XMLType column before log replay\n";

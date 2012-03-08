--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2012 OpenLink Software
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


--DB.DBA.VHOST_REMOVE (lpath=>'/xquery/')
--;
--DB.DBA.VHOST_DEFINE (lpath=>'/xquery/', ppath=>'/xquery/', vsp_user=>'XQ')
--;

--drop table "XP"."XP"."TEST_FILES";
create table "XP"."XP"."TEST_FILES" (
	ID	integer not null,
	NAME	varchar,
	TEXT	long varchar identified by NAME,
	XPER	long varchar identified by NAME,
	COMMENT	varchar,
	primary key (ID)	)
;
grant all on "XP"."XP"."TEST_FILES" to public;
--drop table "XP"."XP"."TEST_CASES";
create table "XP"."XP"."TEST_CASES" (
	ID	integer not null,
	NAME	varchar,
	DESCR	long varchar identified by NAME,
	ORIGIN  varchar,
	_XPATH	long varchar identified by NAME,
	ETALON	long varchar identified by NAME,
	primary key (ID)	)
;

create procedure "XP"."XP"."__XP_SQL_XML" (in _stmt varchar, in _name varchar, in _root varchar, in _sty varchar, in _refresh integer)
{
  declare _col_id, _r_id integer;
  declare ses any;
  declare _res varchar;
 
  _name := concat (_name, '.xml'); 
  _res := concat ('/DAV/xpdemo/', _name);
  _sty := coalesce (_sty, '');
  _root := coalesce (_root, 'root');

  if (_refresh = -1)
    {
      ses := '';
    }
  else
    {
      ses := string_output ();
      xml_auto (_stmt, vector(), ses);
      ses := string_output_string (ses);
      if (_root <> '')
        ses := concat ('<', _root, '>\n', ses, '</', _root, '>\n');
      if (_refresh > 0)
        insert replacing DB.DBA.SYS_SCHEDULED_EVENT (SE_NAME, SE_START, SE_SQL, SE_INTERVAL)
             values (_res, now (), sprintf ('WS.WS.XML_AUTO_SCHED (''%s'')', _res), _refresh); 	
      else 
	delete from DB.DBA.SYS_SCHEDULED_EVENT where SE_NAME = _res;
    }	   
          
  delete from WS.WS.SYS_DAV_RES where RES_FULL_PATH = _res;  
  WS.WS.FINDCOL (vector ('DAV', 'xpdemo'), _col_id);
  _r_id := WS.WS.GETID ('R');    
	insert into WS.WS.SYS_DAV_RES 
		    (RES_ID, 
		     RES_NAME, 
		     RES_COL, 
		     RES_TYPE, 
		     RES_CONTENT,
		     RES_CR_TIME,
		     RES_MOD_TIME,
		     RES_OWNER,
		     RES_GROUP,
		     RES_PERMS)
	       values (_r_id,
		       _name,
		       _col_id,
		       'text/xml',
		       ses,
		       now (),
		       now (),
		       1,
		       1,
		       '110100100N');
	if (_sty <> '' and exists (select 1 from WS.WS.SYS_DAV_RES where RES_FULL_PATH = _sty))
	  insert replacing WS.WS.SYS_DAV_PROP (PROP_ID, PROP_NAME, PROP_TYPE, PROP_PARENT_ID, PROP_VALUE) 
	       values (WS.WS.GETID ('P'), 'xml-stylesheet', 'R', _r_id, 
		   concat ('virt://WS.WS.SYS_DAV_RES.RES_FULL_PATH.RES_CONTENT:', _sty));
	if (_stmt <> '') 
	  insert replacing WS.WS.SYS_DAV_PROP (PROP_ID, PROP_NAME, PROP_TYPE, PROP_PARENT_ID, PROP_VALUE) 
	      values (WS.WS.GETID ('P'), 'xml-sql', 'R', _r_id, _stmt);
	if (_root <> '')
	  insert replacing WS.WS.SYS_DAV_PROP (PROP_ID, PROP_NAME, PROP_TYPE, PROP_PARENT_ID, PROP_VALUE) 
	       values (WS.WS.GETID ('P'), 'xml-sql-root', 'R', _r_id, _root);
}
;

create procedure "XP"."XP"."__XP_POST_INIT" ()
{
  declare _ctr integer;
  declare _tf any;
  declare _path varchar;
  declare _cases any;
  declare _case_id varchar;

  _tf := "XP"."XP"."LIST_TEST_FILES"();

  delete from "XP"."XP"."TEST_FILES";
  delete from "XP"."XP"."TEST_CASES";

  _ctr := 0;
  while (_ctr < length (_tf))
  {
    _path := concat ('xpdemo/', aref (aref (_tf, _ctr), 0));
    if (not exists (select 1 from "XP"."XP"."TEST_FILES" where "NAME" = _path))
      {
	insert into "XP"."XP"."TEST_FILES" ("ID", "NAME", "COMMENT", "TEXT")
	values (sequence_next('_'), _path, aref (aref (_tf, _ctr), 1), "XP"."XP"."GET_DAV_DATA" (_path));
      }
    _ctr := _ctr+1;
  }

--  whenever sqlstate '39000' goto abort_reading;
--  update "XP"."XP"."TEST_FILES" set "TEXT" = "XP"."XP"."GET_DAV_DATA" ("NAME") where "TEXT" is null;
  update "XP"."XP"."TEST_FILES" set "XPER" = xper_doc ("TEXT") where "NAME" like '%xml' and "TEXT" is not null and "XPER" is null;

  for select "NAME" as _use_coll_name, "TEXT" as _text from "XP"."XP"."TEST_FILES" where "NAME"='xpdemo/30010608.xml' and "TEXT" is not null do
    {
	  for select use_case from "XP"."XP"."TEST_FILES" where "NAME"=_use_coll_name and xpath_contains ("XPER", '//case', use_case) do
	    {
	      _case_id := xpath_eval ('@id', use_case);
	      insert into "XP"."XP"."TEST_CASES" ("ID", "NAME", "DESCR", "ORIGIN", "_XPATH", "ETALON")
		  values (sequence_next('_'), _case_id, 
		    xpath_eval ('.//descr', use_case),
		    xpath_eval ('.//origin', use_case),
		    xpath_eval ('.//xpath', use_case),
		    xpath_eval ('.//etalon', use_case) );
	    }
    }
}
;

create procedure "XP"."XP"."__XP_TREAT_FILE" ( in fname varchar, in comment varchar )
{
  declare _ctr integer;
  declare _tf any;
  declare _path varchar;
  declare _cases any;
  declare _case_id varchar;

  _path := concat ('xpdemo/', fname);

  if (not exists (select 1 from "XP"."XP"."TEST_FILES" where "NAME" = _path))
    {
      insert into "XP"."XP"."TEST_FILES" ("ID", "NAME", "COMMENT", "TEXT")
	values (sequence_next('_'), _path, comment, "XP"."XP"."GET_DAV_DATA" (_path));
    }
  else
    update "XP"."XP"."TEST_FILES" set "TEXT" = "XP"."XP"."GET_DAV_DATA" (_path), "COMMENT" = comment where "NAME" = _path;

  update "XP"."XP"."TEST_FILES" set "XPER" = xper_doc ("TEXT") where "NAME" = _path and "TEXT" is not null and "XPER" is null;
}
;
grant execute on "XP"."XP"."__XP_TREAT_FILE" to public;

"XP"."XP"."__XP_SQL_XML"  ('
	SELECT  
		1 as Tag, 
		NULL as Parent, 
		NULL as [users!1!user_tuple!element], 
		NULL as [user_tuple!2!userid!element],
		NULL as [user_tuple!2!name!element], 
		NULL as [user_tuple!2!rating!element] 
	FROM "Demo"."demo"."XPUsers" 
	UNION ALL 
	SELECT  
		2,
		1,
		1, 
		"xpusers"."UserID",
		"xpusers"."Name",
		"xpusers"."Rating"
	FROM "Demo"."demo"."XPUsers" "xpusers" 
	ORDER BY 3 FOR XML EXPLICIT
', 'users', 'users', NULL, -1);

"XP"."XP"."__XP_SQL_XML"  ('
	SELECT  
		1 as Tag, 
		NULL as Parent, 
		NULL as [items!1!item_tuple!element], 
		NULL as [item_tuple!2!itemno!element],
		NULL as [item_tuple!2!description!element], 
		NULL as [item_tuple!2!offered_by!element],
		NULL as [item_tuple!2!start_date!element],
		NULL as [item_tuple!2!end_date!element],
		NULL as [item_tuple!2!reserve_price!element]
	FROM "Demo"."demo"."XPItems" 
	UNION ALL 
	SELECT  
		2,
		1,
		1,
		"xpitems"."Itemno",
		"xpitems"."Description",
		"xpitems"."Offered_by", 
		substring(cast("xpitems"."Start_date" as varchar), 0, 10),
		substring(cast("xpitems"."End_date" as varchar), 0, 10),
		"xpitems"."Reserve_price"
	FROM "Demo"."demo"."XPItems" "xpitems" 
	ORDER BY 3 FOR XML EXPLICIT
', 'items', 'items', NULL, -1);

"XP"."XP"."__XP_SQL_XML"  ('
	SELECT  
		1 as Tag, 
		NULL as Parent, 
		NULL as [bids!1!bid_tuple!element], 
		NULL as [bid_tuple!2!userid!element],
		NULL as [bid_tuple!2!itemno!element], 
		NULL as [bid_tuple!2!bid!element],
		NULL as [bid_tuple!2!bid_date!element] 
	FROM "Demo"."demo"."XPBids" 
	UNION ALL 
	SELECT  
		2,
		1,
		1,
		"xpbids"."UserID",
		"xpbids"."Itemno",
		"xpbids"."Bid", 
		substring(cast("xpbids"."Bid_date" as varchar), 0, 10)
	FROM "Demo"."demo"."XPBids" "xpbids" 
	ORDER BY 3 FOR XML EXPLICIT
', 'bids', 'bids', '', 10);
;

"XP"."XP"."__XP_POST_INIT"()
;


--checkpoint;

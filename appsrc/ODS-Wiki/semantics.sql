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

create function WV.WIKI.NEW_PLAIN_PRED_ID () returns integer
{
  declare _res integer;
  while (1)
    {
      _res := 100000000 + rand (899999999); -- exactly 9-digit integers
      if (not exists (select top 1 1 from WV.WIKI.PREDICATE where PRED_ID = _res))
	 return _res;
    }
}
;

create function WV.WIKI.NEW_PLAIN_SEM_ID () returns integer
{
  declare _res integer;
  while (1)
    {
      _res := 100000000 + rand (899999999); -- exactly 9-digit integers
      if (not exists (select top 1 1 from WV.WIKI.SEMANTIC_OBJ where SO_ID = _res))
	 return _res;
    }
}
;

create procedure WV.WIKI.ADD_FACT (in _topic WV.WIKI.TOPICINFO, 
	in _predicate varchar,
	in _subject varchar,
	in _type varchar)
{
  declare exit handler for sqlstate '*' {
    --dbg_obj_princ (__SQL_STATE, ':', __SQL_MESSAGE);
    resignal;
  }
  ;
  declare _predid int;
  _predid := (select PRED_ID from WV.WIKI.PREDICATE where PRED_DESCR = _predicate);
  if (_predid is null)
    {
       _predid := WV.WIKI.NEW_PLAIN_PRED_ID ();
       insert into WV.WIKI.PREDICATE (PRED_CLUSTER_ID, PRED_ID, PRED_DESCR)
       	values (_topic.ti_cluster_id, _predid, _predicate);
    }
  if (not exists (select 1 from WV.WIKI.SEMANTIC_OBJ 
  		   where SO_CLUSTER_ID = _topic.ti_cluster_id
		   and SO_OBJECT_ID = _topic.ti_id
		   and SO_PRED = _predid
		   and SO_SUBJECT = _subject))		  
    insert into WV.WIKI.SEMANTIC_OBJ (SO_CLUSTER_ID, SO_ID,SO_OBJECT_ID,SO_PRED,SO_SUBJECT,SO_TYPE)
      values (_topic.ti_cluster_id, WV.WIKI.NEW_PLAIN_SEM_ID(), _topic.ti_id, _predid, _subject, _type);
}
;
	

  

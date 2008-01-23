--
--  upstream.sql
--
--  $Id$
--
--  Atom publishing protocol support.
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2006 OpenLink Software
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

wiki_exec_no_error ('
   alter table WV..UPSTREAM add UP_RCLUSTER varchar
')
;

use WV
;

create method ti_register_for_upstream (in optype varchar(1)) returns any for WV.WIKI.TOPICINFO
{
  if (self.ti_local_name = '.DS_Store')
    return;
  for select UP_ID from UPSTREAM where UP_CLUSTER_ID = self.ti_cluster_id do
    {
      if (optype = 'D')
       	  insert into UPSTREAM_ENTRY (UE_STREAM_ID, UE_CLUSTER_NAME, UE_LOCAL_NAME, UE_OP)
	  	 values (UP_ID, self.ti_cluster_name, self.ti_local_name, optype);
      else 
      	  insert into UPSTREAM_ENTRY (UE_STREAM_ID, UE_TOPIC_ID, UE_OP)
       	      values (UP_ID, self.ti_id, optype);
    }
}
;

create procedure PROCESS_UPSTREAMS ()
{
  declare cr static cursor for select UE_ID, UE_STREAM_ID, UE_TOPIC_ID, UE_CLUSTER_NAME, UE_LOCAL_NAME, UE_OP from UPSTREAM_ENTRY where UE_STATUS is null order by UE_ID;
  
  declare id, streamid, _topicid, res int;
  declare clustername, localname, op varchar;
  declare bm any;
whenever not found goto complete;
  open cr (exclusive, prefetch 1);
  fetch cr first into id, streamid, _topicid, clustername, localname, op;
again:
  bm := bookmark (cr);    
  close cr;

  if (op = 'D')
    res := PROCESS_ATOM_DELETE (streamid, clustername, localname);
  else
    {      
      declare _topic WV.WIKI.TOPICINFO;
      _topic := WV.WIKI.TOPICINFO();
      _topic.ti_id := _topicid;
      _topic.ti_find_metadata_by_id ();
      if (op = 'I')
        res := PROCESS_ATOM_INSERT (streamid, _topic);
      else if (op = 'U')
        res := PROCESS_ATOM_UPDATE (streamid, _topic);
    }
  update UPSTREAM_ENTRY set UE_LAST_TRY = now(), UE_STATUS = res where UE_ID = id;
  commit work;
  open cr (exclusive, prefetch 1);
  fetch cr bookmark bm into id, streamid, _topicid, clustername, localname, op;
  goto again;
complete:
  close cr;
}
;

create procedure UPSTREAM_SCHEDULED_JOB ()
{
  delete from UPSTREAM_ENTRY where UE_STATUS = 1;
  commit work;
  PROCESS_UPSTREAMS();
  update UPSTREAM_ENTRY set UE_STATUS = null where UE_STATUS <> 1;
}
;

create procedure WV.WIKI.UPSTREAM_TOPIC_NOW (in topicid int)
{
  delete from UPSTREAM_ENTRY where UE_STATUS = 1 and UE_TOPIC_ID = topicid;
  commit work;

  declare cr static cursor for select UE_ID, UE_STREAM_ID, UE_TOPIC_ID, UE_CLUSTER_NAME, UE_LOCAL_NAME, UE_OP from UPSTREAM_ENTRY where UE_STATUS is null and UE_TOPIC_ID = topicid order by UE_ID;

  declare id, streamid, _topicid, res int;
  declare clustername, localname, op varchar;
  declare bm any;

  whenever not found goto complete;

  open cr (exclusive, prefetch 1);
  fetch cr first into id, streamid, _topicid, clustername, localname, op;
again:
  bm := bookmark (cr);
  close cr;
  if (op = 'D')
    res := PROCESS_ATOM_DELETE (streamid, clustername, localname);
  else
    {
      declare _topic WV.WIKI.TOPICINFO;
      _topic := WV.WIKI.TOPICINFO();
      _topic.ti_id := _topicid;
      _topic.ti_find_metadata_by_id ();
      if (op = 'I')
        res := PROCESS_ATOM_INSERT (streamid, _topic);
      else if (op = 'U')
        res := PROCESS_ATOM_UPDATE (streamid, _topic);
    }
  update UPSTREAM_ENTRY set UE_LAST_TRY = now(), UE_STATUS = res where UE_ID = id and UE_TOPIC_ID = topicid;
  commit work;
  open cr (exclusive, prefetch 1);
  fetch cr bookmark bm into id, streamid, _topicid, clustername, localname, op;
  goto again;
complete:
  close cr;
  update UPSTREAM_ENTRY set UE_STATUS = null where UE_STATUS <> 1 and UE_TOPIC_ID = topicid;
}
;


create function WV.DBA.ATOM_RTOPIC (
    in rcluster varchar,
    in default_cluster varchar,
    in local_name varchar)
{
-- target cluster is prohibited for now
   return local_name;
    if (rcluster is null
	or rcluster = '')
      return default_cluster || '.' || local_name;
    return rcluster || '.' || local_name;
}
;

create procedure WV.DBA.ATOM_UUID ()
{
  return 'urn:uuid:{' || uuid() || '}';
}
;

create procedure WV.DBA.ATOM_ENTRY (
       in _title varchar,
       in _id varchar,
       in _updated datetime,
       in _published datetime,
       in _summary varhar,
       in _text varchar
)
{
   declare ss any;
   ss := string_output ();
   http ('<entry xmlns="http://www.w3.org/2005/Atom">', ss);
   http (sprintf ('<title type="text">%s</title>', _title), ss);
   http (sprintf ('<id>%s</id>', _id ), ss);
   http (sprintf ('<updated>%s</updated>', WV.WIKI.DATEFORMAT (_updated, 'iso8601')), ss);
   http (sprintf ('<published>%s</published>', WV.WIKI.DATEFORMAT(_published, 'iso8601')), ss);
   http (sprintf ('<summary type="text"></summary>', _summary), ss);
   http (sprintf ('<content type="text"><![CDATA[%s]]></content>', _text), ss);
   http ('</entry>', ss);
   return string_output_string (ss);
}
;

create procedure C_RESP (in hdr any)
{
  declare line, code varchar;
  if (hdr is null or __tag (hdr) <> 193)
    return (502);
  if (length (hdr) < 1)
    return (502);
  line := aref (hdr, 0);
  if (length (line) < 12)
    return (502);
  code := substring (line, strstr (line, 'HTTP/1.') + 9, length (line));
  while ((length (code) > 0) and (aref (code, 0) < ascii ('0') or aref (code, 0) > ascii ('9')))
    code := substring (code, 2, length (code) - 1);
  if (length (code) < 3)
    return (502);
  code := substring (code, 1, 3);
  code := atoi (code);
  return code;
}
;


create function HDR_TERM (in _user varchar, in _pwd varchar)
{
  return concat ('Authorization: Basic ',  encode_base64 (_user || ':' || _pwd),  '\r\nContent-Type: application/atom+xml');
}
;

create procedure PROCESS_ATOM_INSERT (in streamid int, inout _topic WV.WIKI.TOPICINFO)
{
   declare exit handler for sqlstate '*' {
	rollback work;
	ADD_LOG_ENTRY (streamid, sprintf ('[%s] %s',__SQL_STATE, __SQL_MESSAGE));
	commit work;
	return 0;
   };
   declare res varchar;
   for select UP_URI, UP_USER, UP_PASSWD, UP_RCLUSTER from UPSTREAM where UP_ID = streamid do
     {
      declare rc, rcc any;
      res := WV.DBA.ATOM_ENTRY (WV.DBA.ATOM_RTOPIC (UP_RCLUSTER, _topic.ti_cluster_name, _topic.ti_local_name),
                         WV.DBA.ATOM_UUID(),
                         now(),
                         now(),
                         '',
                         _topic.ti_text);
      http_get (UP_URI, rc, 'POST', HDR_TERM (UP_USER, UP_PASSWD), res);
      commit work;

      rcc := C_RESP (rc);
      if (not (rcc < 300 and rcc >= 200))
        signal('22023', trim(rc[0], '\r\n'), 'EN000');
	 return 1;
     }
   return 0;
}
;

create procedure PROCESS_ATOM_UPDATE (in streamid int, inout _topic WV.WIKI.TOPICINFO)
{
   declare exit handler for sqlstate '*' {
	rollback work;
	ADD_LOG_ENTRY (streamid, sprintf ('[%s] %s',__SQL_STATE, __SQL_MESSAGE));
	commit work;
	return 0;
   };

  declare res varchar;
   for select UP_URI, UP_USER, UP_PASSWD, UP_RCLUSTER from UPSTREAM where UP_ID = streamid do
     {
      declare rc, rcc any;

      res := WV.DBA.ATOM_ENTRY (WV.DBA.ATOM_RTOPIC (UP_RCLUSTER, _topic.ti_cluster_name, _topic.ti_local_name),
                         WV.DBA.ATOM_UUID(),
                         now(),
                         now(),
                         '',
                         _topic.ti_text);
      http_get (UP_URI, rc, 'PUT', HDR_TERM (UP_USER, UP_PASSWD), res);
      commit work;
      rcc := C_RESP (rc);
      if (not (rcc < 300 and rcc >= 200))
        signal('22023', trim(rc[0], '\r\n'), 'EN000');
	 return 1;
     }
  return 0;
}
;

create procedure PROCESS_ATOM_DELETE (in streamid int, in clustername varchar, in localname varchar)
{
   declare exit handler for sqlstate '*' {
	rollback work;
	ADD_LOG_ENTRY (streamid, sprintf ('[%s] %s',__SQL_STATE, __SQL_MESSAGE));
	commit work;
	return 0;
   };

  declare res varchar;
   for select UP_URI, UP_USER, UP_PASSWD, UP_RCLUSTER from UPSTREAM where UP_ID = streamid do
     {
       declare http_res varchar;
      declare rc, rcc any;

      res := WV.DBA.ATOM_ENTRY (WV.DBA.ATOM_RTOPIC (UP_RCLUSTER, clustername, localname),
                         WV.DBA.ATOM_UUID(),
                         now(),
                         now(),
                         '',
                         '');
       http_res := http_get (UP_URI, rc, 'DELETE', HDR_TERM(UP_USER, UP_PASSWD), res);
      commit work;

      rcc := C_RESP (rc);
      if (not (rcc < 300 and rcc >= 200))
        signal('22023', trim(rc[0], '\r\n'), 'EN000');
	 return 1;
     }
  return 0;
}
;

create procedure MAX_LOG_COUNT ()
{
  return 7;
}
;

create procedure ADD_LOG_ENTRY (in streamid int, in message varchar)
{
  declare _cnt int;
  _cnt := (select count(*) from UPSTREAM_LOG where UL_UPSTREAM_ID = streamid);
  insert into UPSTREAM_LOG (UL_UPSTREAM_ID, UL_ID, UL_DT, UL_MESSAGE) 
	values (streamid, _cnt + 1, now(), message);
  if (_cnt + 1 > MAX_LOG_COUNT())
    TRUNCATE_LOG(streamid, _cnt + 1);
}
;

create procedure TRUNCATE_LOG (in streamid int, in _cnt int)
{
  delete from UPSTREAM_LOG where UL_UPSTREAM_ID = streamid and UL_ID <= (_cnt - MAX_LOG_COUNT());
  update UPSTREAM_LOG set UL_ID = UL_ID - (_cnt - MAX_LOG_COUNT());
}
;

create procedure UPSTREAM_ALL (in streamid int)
{
  declare _cluster int;
  _cluster := (select UP_CLUSTER_ID from UPSTREAM where UP_ID = streamid);
  if (_cluster is not null) { 
    for select TOPICID from WV.WIKI.TOPIC where CLUSTERID = _cluster do {
      insert into UPSTREAM_ENTRY (UE_STREAM_ID, UE_TOPIC_ID, UE_OP)
 	      values (streamid, TOPICID, 'I');
    }
  }
}
;


insert replacing DB.DBA.SYS_SCHEDULED_EVENT (SE_NAME, SE_START, SE_SQL, SE_INTERVAL) values ('wiki upstream', now(), 'WV..UPSTREAM_SCHEDULED_JOB()', 5)
;


use DB
;

create trigger WIKI_UPSTREAM_D before delete on WV..UPSTREAM order 10 referencing old as O
{
   delete from WV..UPSTREAM_ENTRY where UE_STREAM_ID = O.UP_ID;
}
;

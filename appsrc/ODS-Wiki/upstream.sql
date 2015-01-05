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

use WV;

-------------------------------------------------------------------------------
--
create method ti_register_for_upstream (in action varchar(1)) returns any for WV.WIKI.TOPICINFO
{
  if (self.ti_local_name = '.DS_Store')
    return;

  for select UP_ID from UPSTREAM where UP_CLUSTER_ID = self.ti_cluster_id do
    {
    if (action = 'D')
    {
      if (exists (select 1 from WV..UPSTREAM_ENTRY where UE_STREAM_ID = UP_ID and UE_TOPIC_ID = self.ti_id and UE_OP = 'I' and UE_STATUS is null))
      {
        delete from WV..UPSTREAM_ENTRY where UE_STREAM_ID = UP_ID and UE_TOPIC_ID = self.ti_id and UE_STATUS is null;
      }
      else 
      {
        if (exists (select 1 from WV..UPSTREAM_ENTRY where UE_STREAM_ID = UP_ID and UE_TOPIC_ID = self.ti_id and UE_OP = 'U' and UE_STATUS is null))
        {
          delete from WV..UPSTREAM_ENTRY where UE_STREAM_ID = UP_ID and UE_TOPIC_ID = self.ti_id and UE_OP = 'U' and UE_STATUS is null;
        }
        insert into WV..UPSTREAM_ENTRY (UE_STREAM_ID, UE_CLUSTER_NAME, UE_LOCAL_NAME, UE_OP)
          values (UP_ID, self.ti_cluster_name, self.ti_local_name, action);
      }
    }
    else if (action = 'I')
    {
      insert into WV..UPSTREAM_ENTRY (UE_STREAM_ID, UE_TOPIC_ID, UE_CLUSTER_NAME, UE_LOCAL_NAME, UE_OP)
        values (UP_ID, self.ti_id, self.ti_cluster_name, self.ti_local_name, action);
    }
    else if (action = 'U')
    {
      if (not exists (select 1 from WV..UPSTREAM_ENTRY where UE_STREAM_ID = UP_ID and UE_TOPIC_ID = self.ti_id and (UE_OP = 'I' or UE_OP = 'U') and UE_STATUS is null))
      {
        insert into WV..UPSTREAM_ENTRY (UE_STREAM_ID, UE_TOPIC_ID, UE_CLUSTER_NAME, UE_LOCAL_NAME, UE_OP)
          values (UP_ID, self.ti_id, self.ti_cluster_name, self.ti_local_name, action);
      }
    }
    }
}
;

-------------------------------------------------------------------------------
--
create procedure WV..PROCESS_UPSTREAMS ()
{
  declare cr static cursor for select UE_ID, UE_STREAM_ID, UE_TOPIC_ID, UE_LOCAL_NAME, UE_OP from WV..UPSTREAM_ENTRY where UE_STATUS is null order by UE_ID;
  
  declare id, streamID, topicID, res int;
  declare localName, action varchar;
  declare bm any;

  whenever not found goto _complete;

  open cr (exclusive, prefetch 1);
  fetch cr first into id, streamID, topicID, localName, action;

_again:
  bm := bookmark (cr);    
  close cr;

  res := WV..PROCESS_UPSTREAM_ENTRY (action, streamID, topicID, localName);
  update WV..UPSTREAM_ENTRY set UE_LAST_TRY = now(), UE_STATUS = res where UE_ID = id;
  commit work;
  open cr (exclusive, prefetch 1);
  fetch cr bookmark bm into id, streamID, topicID, localName, action;
  goto _again;

_complete:
  close cr;
}
;

-------------------------------------------------------------------------------
--
create procedure WV..UPSTREAM_SCHEDULED_JOB ()
{
  delete from WV..UPSTREAM_ENTRY where UE_STATUS = 1;
  commit work;
  PROCESS_UPSTREAMS();
  update WV..UPSTREAM_ENTRY set UE_STATUS = null where UE_STATUS <> 1;
}
;

-------------------------------------------------------------------------------
--
create procedure WV.WIKI.UPSTREAM_TOPIC_NOW (
  in topicID integer)
{
  delete from WV..UPSTREAM_ENTRY where UE_STATUS = 1 and UE_TOPIC_ID = topicID;
  commit work;

  declare cr static cursor for select UE_ID, UE_STREAM_ID, UE_LOCAL_NAME, UE_OP from WV..UPSTREAM_ENTRY where UE_STATUS is null and UE_TOPIC_ID = topicID order by UE_ID;

  declare id, streamID, res integer;
  declare localName, action varchar;
  declare bm any;

  whenever not found goto _complete;

  open cr (exclusive, prefetch 1);
  fetch cr first into id, streamID, localName, action;

_again:
  bm := bookmark (cr);
  close cr;

  res := WV..PROCESS_UPSTREAM_ENTRY (action, streamID, topicID, localName);
  update WV..UPSTREAM_ENTRY set UE_LAST_TRY = now(), UE_STATUS = res where UE_ID = id and UE_TOPIC_ID = topicID;
  commit work;
  open cr (exclusive, prefetch 1);
  fetch cr bookmark bm into id, streamID, localName, action;
  goto _again;

_complete:
  close cr;
  update WV..UPSTREAM_ENTRY set UE_STATUS = null where UE_STATUS <> 1 and UE_TOPIC_ID = topicID;
}
;

-------------------------------------------------------------------------------
--
create procedure WV..PROCESS_UPSTREAM_ENTRY (
  in action varchar,
  in streamID integer,
  in topicID integer,
  in localName varchar)
{
  declare rc integer;
  declare topic WV.WIKI.TOPICINFO;

  if (action = 'D')
{
    rc := WV..PROCESS_ATOM_ENTRY ('DELETE', streamID, null, localName);
}
  else
{
    declare exit handler for sqlstate '*'
    {
    	rc := 0;
    	ADD_LOG_ENTRY (streamid, sprintf ('[%s] %s', __SQL_STATE, __SQL_MESSAGE));
    	goto _next;
    };
    topic := WV.WIKI.TOPICINFO();
    topic.ti_id := topicID;
    topic.ti_find_metadata_by_id ();
    if (action = 'I')
    {
      rc := WV..PROCESS_ATOM_ENTRY ('POST', streamID, topic, coalesce (topic.ti_local_name, localName));
    }
    else if (action = 'U')
    {
      rc := WV..PROCESS_ATOM_ENTRY ('POST', streamID, topic, coalesce (topic.ti_local_name, localName));
    }
  }
_next:
  return rc;
}
;

-------------------------------------------------------------------------------
--
create procedure WV..PROCESS_ATOM_ENTRY (
  in reqAction varchar,
  in streamID integer,
  in topic WV.WIKI.TOPICINFO,
  in localName varchar)
{
  declare resHdr, reqHdr, rc, resp any;
  declare attachments_path varchar;
  declare attachments_list any;
   declare ss any;
  declare exit handler for sqlstate '*'
  {
    -- dbg_obj_print (now (), __SQL_STATE, __SQL_MESSAGE);
    rollback work;
    WV..ADD_LOG_ENTRY (streamid, sprintf ('[%s] %s', __SQL_STATE, __SQL_MESSAGE));
    commit work;
    return 0;
  };

  for select UP_URI, UP_USER, UP_PASSWD, UP_RCLUSTER from UPSTREAM where UP_ID = streamID do
  {
    attachments_list := vector ();
   ss := string_output ();

  http ('<entry xmlns="http://www.w3.org/2005/Atom" xmlns:wv="http://www.openlinksw.com/Virtuoso/WikiV/">', ss);
    http ('<wv:version>3.0</wv:version>', ss);
    http (sprintf ('<title type="text">%s</title>', localName), ss);
    http (sprintf ('<id>%s</id>', WV..ATOM_UUID()), ss);
    http (sprintf ('<updated>%s</updated>', WV.WIKI.DATEFORMAT (now (), 'iso8601')), ss);
    http (sprintf ('<published>%s</published>', WV.WIKI.DATEFORMAT(now (), 'iso8601')), ss);
    if (not isnull (topic) and topic.ti_id)
    {
   http ('<content type="text">', ss);
      http_escape (coalesce (topic.ti_text, ''), 1, ss, 1, 1);
   http ('</content>', ss);

      -- attachments
      attachments_path := DB.DBA.DAV_SEARCH_PATH (topic.ti_col_id, 'C') || topic.ti_local_name || '/';
      attachments_list := DB.DBA.DAV_DIR_LIST (attachments_path, 0, 'dav', (select pwd_magic_calc (U_NAME, U_PWD, 1) from WS.WS.SYS_DAV_USER where U_ID = http_dav_uid()));
      if (not isinteger (attachments_list) and length (attachments_list))
    {
      http ('<wv:attachments>', ss);
        foreach (any attachment in attachments_list) do
      {
        http ('<wv:attachment>', ss);
          http (sprintf ('<wv:name>%s</wv:name>', attachment[10]), ss);
        http ('</wv:attachment>', ss);
      }
      http ('</wv:attachments>', ss);
    }
  }
   http ('</entry>', ss);
    ss := string_output_string (ss);

    reqHdr := WV..HDR_TERM (UP_USER, UP_PASSWD);
    resp := http_client_ext (url=>UP_URI,
                     http_method=>reqAction,
                     http_headers=>reqHdr,
                     headers=>resHdr,
                     body=>ss);
    commit work;
    rc := WV..C_RESP (resHdr);
    if (not (rc < 300 and rc >= 200))
      signal('22023', trim(resHdr[0], '\r\n'), 'EN000');

    -- attachments
    if (not isinteger (attachments_list) and length (attachments_list))
    {
      declare _type, _content any;

      foreach (any attachment in attachments_list) do
      {
        DB.DBA.DAV_RES_CONTENT_INT (attachment[4], _content, _type, 0, 0);
        reqHdr := WV..HDR_TERM (UP_USER, UP_PASSWD, _type, localName || '/' || attachment[10], 'WIKI-ATTACHMENT');
        http_client_ext (url=>UP_URI,
                         http_method=>'PUT',
                         http_headers=>reqHdr,
                         headers=>resHdr,
                         body=>cast (_content as varchar));
        commit work;
        rc := C_RESP (resHdr);
        if (not (rc < 300 and rc >= 200))
          signal('22023', trim(resHdr[0], '\r\n'), 'EN000');
      }
    }
    return 1;
  }
  return 0;
}
;

-------------------------------------------------------------------------------
--
create procedure WV..ATOM_UUID ()
{
  return 'urn:uuid:{' || uuid() || '}';
}
;

-------------------------------------------------------------------------------
--
create procedure WV..C_RESP (
  in hdr any)
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

-------------------------------------------------------------------------------
--
create procedure WV..HDR_TERM (
  in _user varchar,
  in _pwd varchar,
  in _type varchar := 'application/atom+xml',
  in _name varchar := '',
  in _description varchar := '')
{
  declare S varchar;

  S := 'Authorization: Basic ' || encode_base64 (_user || ':' || _pwd);
  if (length (_type))
    S := S || '\r\nContent-Type: ' || _type;
  if (length (_name))
    S := S || sprintf ('\r\nContent-Disposition: inline; filename="%s"', _name);
  if (length (_description))
    S := S || '\r\nContent-Description: ' || _description;

  return S;
}
;

-------------------------------------------------------------------------------
--
create procedure WV..ADD_LOG_ENTRY (
  in streamID int,
  in message varchar)
{
  declare _cnt integer;
  declare _log_count integer;

  _log_count := 7;
  _cnt := (select count(*) from UPSTREAM_LOG where UL_UPSTREAM_ID = streamID) + 1;
  insert into UPSTREAM_LOG (UL_UPSTREAM_ID, UL_ID, UL_DT, UL_MESSAGE)
    values (streamID, _cnt, now(), message);
  if (_cnt > _log_count)
{
    delete from UPSTREAM_LOG where UL_UPSTREAM_ID = streamID and UL_ID <= (_cnt - _log_count);
    update UPSTREAM_LOG set UL_ID = UL_ID - (_cnt - _log_count);
}
}
;

-------------------------------------------------------------------------------
--
create procedure WV..UPSTREAM_ALL (
  in streamID integer)
{
  for (select topicID from WV.WIKI.TOPIC, UPSTREAM where CLUSTERID = UP_CLUSTER_ID and UP_ID = streamID) do
{
    insert into WV..UPSTREAM_ENTRY (UE_STREAM_ID, UE_TOPIC_ID, UE_OP)
      values (streamID, topicID, 'I');
  }
}
;


insert replacing DB.DBA.SYS_SCHEDULED_EVENT (SE_NAME, SE_START, SE_SQL, SE_INTERVAL) values ('wiki upstream', now(), 'WV..UPSTREAM_SCHEDULED_JOB()', 5)
;

create trigger WIKI_UPSTREAM_D before delete on WV..UPSTREAM order 10 referencing old as O
{
   delete from WV..UPSTREAM_ENTRY where UE_STREAM_ID = O.UP_ID;
}
;

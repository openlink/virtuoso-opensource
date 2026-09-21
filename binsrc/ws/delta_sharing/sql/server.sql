--
--  $Id$
--
--  Delta Sharing server procedures
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2026 OpenLink Software
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

create procedure DELTA.DBA."delta-sharing"(in request any default null __soap_http 'application/json',
    in limitHint int default null, in startingVersion int default null, in endingVersion int default null) 
    __soap_options (__soap_http := 'application/json', Security := 'VAL')
{
  declare path, params, lines any;
  declare method varchar;
  declare q, sch, table_name, action varchar;
  declare len int;
  declare val_uname varchar;

  q := sch := table_name := null;
  method := http_request_get('REQUEST_METHOD');
  val_uname := connection_get ('SPARQLUserId');

  if (method = 'OPTIONS')
    return '';

  path := split_and_decode (trim(http_path(),'/'), 0, '\0\0/');
  params := http_param();
  lines := http_request_header();

  len := length(path);

  action := aref(path,len - 1);
  if (action not in ('shares', 'tables', 'schemas', 'query', 'all-tables', 'version', 'metadata', 'changes'))
    action := aref(path,len - 2);
  if (action not in ('shares', 'tables', 'schemas', 'query', 'all-tables', 'version', 'metadata', 'changes', 'files'))
    {
      http_status_set(400);
      return '';
    }
  if (len > 6)
    table_name := aref(path,6);
  if (len > 4)
    sch := aref(path,4);
  if (len > 2)
    q := aref(path,2);

  if (registry_get ('delta-sharing-debug') = '1')
    dbg_obj_print('DS method: ', method, ' path:', path, ' params:', params, ' q:', q, ' o:', sch, ' n:', table_name, ' action:', action);
  declare obj, vec any;
  obj := null;
  if (action = 'shares')
    {
      if (q is not null)
        {
          obj := json_box_object('share', json_box_object('name', q));
        }
      else
        {
          vectorbld_init(vec);
          for select distinct name_part(KEY_TABLE,0) as qual from DB.DBA.SYS_KEYS where __any_grants_to_user (KEY_TABLE,val_uname) do {
            vectorbld_concat_acc(vec, vector(json_box_object('name', qual)));
          }
          vectorbld_final(vec);
          obj := json_box_object('items', vec);
        }
    }
  if (action = 'schemas')
    {
      if (sch is not null)
        {
          http_status_set(400);
          return '';
        }
      vectorbld_init(vec);
      for select distinct name_part(KEY_TABLE,1) as o from DB.DBA.SYS_KEYS where name_part(KEY_TABLE,0) = q and __any_grants_to_user (KEY_TABLE,val_uname) do {
        vectorbld_concat_acc(vec, vector(json_box_object('name', o, 'share', q)));
      }
      vectorbld_final(vec);
      obj := json_box_object('items', vec);
    }
  if (action = 'tables' or action = 'all-tables')
    {
      if (table_name is not null)
        {
          http_status_set(405);
          return '';
        }
      vectorbld_init(vec);
      for select distinct name_part(KEY_TABLE,2) as n from DB.DBA.SYS_KEYS
        where name_part(KEY_TABLE,0) = q and (name_part(KEY_TABLE,1) = sch or sch is null) and __any_grants_to_user (KEY_TABLE,val_uname) do {
        vectorbld_concat_acc(vec, vector(json_box_object('name', n, 'schema', sch, 'share', q)));
      }
      vectorbld_final(vec);
      obj := json_box_object('items', vec);
    }
  declare full_table_name varchar;
  if (table_name is not null)
    full_table_name := complete_table_name(concat(q,'.',sch,'.',table_name), 1);
  if (action = 'metadata')
    {
      if (not __any_grants_to_user(full_table_name, val_uname))
        {
          http_status_set(403);
          return '';
        }
      http_header('Delta-Table-Version: 1\r\nContent-Type: application/x-ndjson; charset=utf-8\r\n');
      http(DB.DBA.OBJ2JSON(json_box_object ('protocol', json_box_object('minReaderVersion', 1))));
      http('\r\n');
      http(DB.DBA.OBJ2JSON(DELTA.DBA.TABLE_META(full_table_name)));
      http('\r\n');
      obj := null;
    }
  if (action = 'query')
    {
      declare jt any;
      jt := null;
      request := string_output_string(http_body_read());
      if (registry_get ('delta-sharing-debug') = '1')
        dbg_obj_print('req:', request);
      if (length(request)) 
        {
          jt := json_parse(request);
          limitHint := get_keyword('limitHint', jt);
        }
      if (not __any_grants_to_user(full_table_name, val_uname))
        {
          http_status_set(403);
          return '';
        }
      http_header('Delta-Table-Version: 1\r\nContent-Type: application/x-ndjson; charset=utf-8\r\n');
      http(DB.DBA.OBJ2JSON(json_box_object ('protocol', json_box_object('minReaderVersion', 1))));
      http('\r\n');
      http(DB.DBA.OBJ2JSON(DELTA.DBA.TABLE_META(full_table_name)));
      http('\r\n');
      http(DB.DBA.OBJ2JSON(DELTA.DBA.TABLE_FILES(full_table_name, limitHint)));
      http('\r\n');
      obj := null;
    }
  if (action = 'changes')
    {
      http_status_set(400);
      obj := json_box_object('errorCode','INVALID_PARAMETER_VALUE','message','cdf is not enabled on table');
    }
  if (action = 'version')
    {
      http_header('Delta-Table-Version: 1\r\n');
      obj := null;
    }
  if (action = 'files')
    {
      declare tmp_name varchar;
      declare _http_ranges_header, content, ses any;
      limitHint := atoi(get_keyword('limitHint', params));
      tmp_name := tmp_file_name ('delta-','parquet');
      DELTA.DBA.DUMP_TABLE_TO_PARQUET (full_table_name, tmp_name, limit=>limitHint);
      content := file_to_string(tmp_name);
      _http_ranges_header := http_sys_parse_ranges_header (length (content));
      if (isarray (_http_ranges_header))
        {
          http_header (concat('Content-Type: application/vnd.apache.parquet\r\n',
                 sprintf ('Content-Range: bytes %ld-%ld/%ld\r\n', _http_ranges_header[0], _http_ranges_header[1], length (content))));
          http_status_set(206);
          http (subseq(content, _http_ranges_header[0], _http_ranges_header[1]+1));
        }
      else
        {
          http_header ('Content-Type: application/vnd.apache.parquet\r\n');
          http (content);
        }
      sys_unlink(tmp_name);
      obj := null;
    }

  if (obj is null)
    return '';

  return DB.DBA.OBJ2JSON(obj);
}
;

create procedure DELTA.DBA.TABLE_FILES(in full_table_name varchar, in limit int default null, in offset int default null)
{
  declare tmp_name, url, serviceId, realm, sid varchar;
  declare sz, id int;
  declare ses, obj any;

  serviceId := connection_get('NetId');
  realm := VAL.DBA.get_default_realm ();
  tmp_name := tmp_file_name ('delta-','parquet');
  sid := VAL.DBA.new_user_session (serviceId, realm, 0, vector ());
  DELTA.DBA.DUMP_TABLE_TO_PARQUET (full_table_name, tmp_name, limit=>limit);
  sz := file_stat(tmp_name, 1);
  if (sz)
    sys_unlink(tmp_name);
  id := (select KEY_ID from SYS_KEYS where KEY_TABLE = full_table_name);
  url := sprintf ('https://%{WSHost}s/delta-sharing/shares/%U/schemas/%U/tables/%U/files/%d.parquet',
         name_part(full_table_name,0),
         name_part(full_table_name,1),
         name_part(full_table_name,2),
         id);
  if (limit is not null)
    url := WS.WS.URI_ADD_PARAM(url, 'limitHint', limit);
  url := WS.WS.URI_ADD_PARAM(url, 'key', sid);
  obj := json_box_object ('file', 
    json_box_object ('url', url, 'id', id, 'size', sz, 'partitionValues', vector(composite(),'')));
  return obj;
}
;

create procedure DELTA.DBA.TABLE_META(in full_table_name varchar)
{
  declare definitions, vec, obj any;
  declare id int;
  vectorbld_init(vec);
  for select "COLUMN", COL_DTP, COL_NULLABLE from DB.DBA.SYS_COLS where "TABLE" = full_table_name order by COL_ID do {
    vectorbld_concat_acc(vec, vector(json_box_object('name', "COLUMN", 'type', DELTA.DBA.DTP2TYPE(COL_DTP),
            'nullable', soap_boolean(__not(isnull(COL_NULLABLE))), 'metadata', vector(composite(),''))));
  }
  vectorbld_final(vec);
  id := (select KEY_ID from SYS_KEYS where KEY_TABLE = full_table_name);
  definitions := json_box_object('type', 'struct', 'fields', vec);
  obj := json_box_object ('metaData', json_box_object('id', id, 'name', full_table_name, 'format', json_box_object('provider', 'parquet'),
    'schemaString', DB.DBA.OBJ2JSON(definitions), 'configuration', vector(composite(),''), 'partitionColumns', vector()));
  return obj;
}
;

create function DELTA.DBA.DTP2TYPE(in dtp int)
{
  if (dtp = __tag of int)
    return 'integer';
  if (dtp = __tag of bigint)
    return 'long';
  if (dtp = __tag of varchar or dtp = __tag of uname)
    return 'string';
  if (dtp = __tag of  smallint)
    return 'short';
  if (dtp = __tag of float)
    return 'float';
  if (dtp = __tag of double precision)
    return 'double';
  if (dtp = __tag of numeric)
    return 'decimal';
  if (dtp = __tag of date)
    return 'date';
  if (dtp = __tag of datetime or dtp = __tag of time or dtp = __tag of timestamp)
    return 'timestamp';
  return 'binary';
}
;

create procedure DELTA.DBA.DUMP_TABLE_TO_PARQUET (in table_name varchar, in file_name varchar,
    in start_offset int default 0, in limit int default null, in "encoding" varchar default null, in compression int default 1)
{
  declare sql_query, top_exp varchar;
  top_exp := '';
  if (limit is not null)
    {
      if (start_offset)
        top_exp := sprintf ('TOP %d,%d', start_offset, limit);
      else
        top_exp := sprintf ('TOP %d', limit);
    }
  sql_query := sprintf ('SELECT %s * FROM "%I"."%I"."%I"', top_exp, name_part(table_name,0), name_part(table_name,1), name_part(table_name,2));
  DELTA.DBA.DUMP_SQL_QUERY_TO_PARQUET (sql_query, file_name, "encoding", compression);
  return;
}
;

create procedure DELTA.DBA.AUTHENTICATE(in realm varchar)
{
  declare http_method, call_name varchar;
  declare val_serviceId, val_sid, val_realm, val_uname, val_webidGraph, scope, client_ip, val_cert, sid varchar;
  declare val_authenticated, perms, val_isRealUser int;
  declare path, lines any;
  
  lines := http_request_header();
  if (registry_get ('delta-sharing-debug') = '1')
    dbg_obj_print(lines);

  http_method := http_request_get('REQUEST_METHOD');
  if (http_method = 'OPTIONS')
    return 1;
  path := string_split (http_path(), '/');
  --dbg_obj_print (path);
  --if (length(path) > 7 and aref(path,7) = 'files')
  --  return 1;
  val_authenticated := 0;
  perms := 0;
  if (DB.DBA.VAD_CHECK_VERSION ('VAL') is not null)
    {
      val_realm := VAL.DBA.get_default_realm();
      client_ip := http_client_ip();
      scope := VAL.DBA.get_query_scope();
      if (DB.DBA.DBEV_ACLS_ENABLED_FOR_SCOPE (scope, val_realm))
        {
          val_webidGraph := concat ('urn:delta-sharing:auth:', uuid());
          connection_set('__val_JAK_ApiId__', 'urn:openlink:virtuoso:delta-sharing:1.0');
          val_authenticated := VAL.DBA.get_authentication_details_for_connection (
              sid=>val_sid,
              serviceId=>val_serviceId,
              uname=>val_uname,
              isRealUser=>val_isRealUser,
              sidParamName=>'key',
              realm=>val_realm,
              cert=>val_cert,
              webidGraph=>val_webidGraph);
           -- Permission to access OPAL system
           perms := VAL.DBA.check_access_mode_for_resource (
              serviceId=>val_serviceId,
              resource=>'urn:virtuoso:services:delta-sharing',
              realm=>val_realm,
              mode=>VAL.DBA.oplacl_iri ('Read'),
              scope=>scope,
              webidGraph=>val_webidGraph,
              certificate=>val_cert,
              honorScopeState=>1,
              evalRecursiveRules=>1);
           if (VAL.DBA.is_admin_user (val_uname))
             {
               perms := 1;
             }
          sparql clear graph ?:val_webidGraph;
          commit work;
        }
    }
  return perms;
}
;

create procedure DELTA.DBA.DUMP_SQL_QUERY_TO_PARQUET (in sql_query varchar, in file_name varchar, 
     in "encoding" varchar default null, in compression int default 1)
{
  declare meta, data any;
  declare val_uname varchar;
  val_uname := connection_get ('SPARQLUserId','nobody');
  set_user_id(val_uname);
  exec (sql_query, null, null, vector(), 0, meta, data);
  export_parquet_file(aref(meta,0), data, file_name, "encoding", compression);
  return;
}
;

create procedure DELTA.DBA.INIT()
{
  if (user_to_uid('DeltaSharing') < 0)
    DB.DBA.USER_CREATE ('DeltaSharing', sha1_digest(uuid())); 
  DB.DBA.EXEC_STMT('grant execute on DELTA.DBA."delta-sharing" to "DeltaSharing"',0);
  DB.DBA.VHOST_REMOVE (vhost=>'*ini*', lhost=>'*ini*', lpath=>'/delta-sharing/shares');
  DB.DBA.VHOST_DEFINE (vhost=>'*ini*',
                      lhost=>'*ini*',
                      lpath=>'/delta-sharing/shares',
                      ppath=>'/SOAP/Http/delta-sharing',
                      is_dav=>0,
                      is_brws=>0,
                      realm=>'DeltaSharing',
                      auth_fn=>'DELTA.DBA.AUTHENTICATE',
                      soap_user=>'DeltaSharing',
                      opts=>vector ('cors', '*', 'cors_allow_headers', '*', 'cors_restricted', 0, 'http_options_no_exec', 1));
}
;

DELTA.DBA.INIT()
;


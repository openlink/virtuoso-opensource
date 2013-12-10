--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2013 OpenLink Software
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

-------------------------------------------------------------------------------
--
-- Freeze Functions
--
-------------------------------------------------------------------------------
create procedure OMAIL.WA.session_domain (
  inout params any)
{
  declare aPath, domain_id, options any;

  declare exit handler for sqlstate '*'
  {
    domain_id := -1;
    goto _end;
  };

  options := http_map_get('options');
  if (not is_empty_or_null (options))
  {
    domain_id := get_keyword ('domain', options);
  }
  if (is_empty_or_null (domain_id))
  {
    aPath := split_and_decode (trim (http_path (), '/'), 0, '\0\0/');
    domain_id := cast(aPath[1] as integer);
  }
  if (not exists (select 1 from DB.DBA.WA_INSTANCE where WAI_ID = domain_id))
    domain_id := -1;

_end:;
  return cast (domain_id as integer);
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.frozen_check (
  in domain_id integer,
  in sid varchar)
{
  declare user_id integer;
  declare vsState any;

  declare exit handler for not found { return 1; };

  vsState := coalesce ((select deserialize(VS_STATE) from DB.DBA.VSPX_SESSION where VS_SID = sid), vector());
  user_id := (select U_ID from SYS_USERS where U_NAME = get_keyword ('vspx_user', vsState, ''));

  if (exists (select 1 from DB.DBA.SYS_USERS where U_ACCOUNT_DISABLED = 1 and U_ID = user_id))
    return 1;

  if (is_empty_or_null((select WAI_IS_FROZEN from DB.DBA.WA_INSTANCE where WAI_ID = domain_id)))
    return 0;

  if (OMAIL.WA.check_admin(user_id))
    return 0;

  declare owner_id integer;
  owner_id := (select U_ID from SYS_USERS where U_NAME = get_keyword ('owner_user', vsState, ''));

  if (OMAIL.WA.check_admin (owner_id))
    return 0;

  return 1;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.frozen_page(in domain_id integer)
{
  return (select WAI_FREEZE_REDIRECT from DB.DBA.WA_INSTANCE where WAI_ID = domain_id);
}
;

-------------------------------------------------------------------------------
--
-- User Functions
--
-------------------------------------------------------------------------------
create procedure OMAIL.WA.check_admin(
  in user_id integer) returns integer
{
  declare group_id integer;

  if (user_id = 0)
    return 1;
  if (user_id = http_dav_uid ())
    return 1;

  group_id := (select U_GROUP from SYS_USERS where U_ID = user_id);
  if (group_id = 0)
    return 1;
  if (group_id = http_dav_uid ())
    return 1;
  if(group_id = http_dav_uid()+1)
    return 1;
  return 0;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_account_info(
  in _user_info any)
{
  declare _all_cnt,_new_cnt,_domain_id,_user_id integer;

  _user_id   := get_keyword('user_id',_user_info);
  _domain_id := 1;

  select COUNT(*), SUM(either(MSTATUS,0,1))
    INTO _all_cnt,_new_cnt
    from OMAIL.WA.MESSAGES
   where DOMAIN_ID = _domain_id
     and USER_ID   = _user_id;

  _new_cnt := either(isnull(_new_cnt),0,_new_cnt);
  return sprintf('<eml><new_msg>%d</new_msg><all_msg>%d</all_msg></eml>', _new_cnt, _all_cnt);
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_addr(
  inout path any,
  inout lines any,
  inout params any)
{
  -- www procedure

  declare _rs,_sid,_realm,_sql_result1,_pnames varchar;
  declare _params,_page_params any;
  declare _user_info any;
  declare _user_id,_domain_id,_acount integer;

  _sid       := get_keyword('sid',params,'');
  _realm     := get_keyword('realm',params,'');
  _user_info := get_keyword('user_info',params);

  -- TEMP constants -----------------------------
  _user_id   := get_keyword('user_id',_user_info);
  _domain_id := 1;

  -- Set constants  -------------------------------------------------------------------
  _page_params := vector(0,0,0,0,0,0,0,0,0,0,0,0);

  -- Set Params --------------------------------------------------------------------
  _pnames := '';
  _params := OMAIL.WA.omail_str2params(_pnames,get_keyword('ap',params,'0,0,0'),',');

  -- SQL Statement-------------------------------------------------------------------
  _sql_result1 := sprintf('<addr_book>%s</addr_book>',ADR..search_res(_domain_id,_user_id,0,1000,0,_acount));

  aset(_page_params,0,vector('sid',_sid));
  aset(_page_params,1,vector('realm',_realm));
  aset(_page_params,2,vector('user_info', OMAIL.WA.array2xml(_user_info)));

  -- XML structure-------------------------------------------------------------------
  return concat(OMAIL.WA.omail_page_params(_page_params), _sql_result1);
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_address2str(
  in _node varchar,
  in _values varchar,
  in _mode  integer)
{
  declare N integer;
  declare _name, _email, _rs, _del varchar;
  declare _arr any;

  _rs := '';
  if (not is_empty_or_null (_values))
  {
  _del := '';
  _arr := (xpath_eval(concat('//', _node), xml_tree_doc(xml_tree( _values)),0));
    for (N := 0; N < length (_arr); N := N + 1)
    {
    _email := cast(xpath_eval('email', _arr[N]) as varchar);
    _name  := cast(xpath_eval('name', _arr[N]) as varchar);
    if (_mode = 1) {
      _rs := _rs || _del || _name;
    } else if (_mode = 2) {
      _rs := _rs || _del || _email;
    } else if (_mode = 3) {
      if (length(_name) or length(_email))
        _rs := _rs || _del || trim(_name || ' ' || _email);
    } else {
      _rs := _rs || OMAIL.WA.xml2string(_arr[N]);
    }
    _del := ', ';
  }
  }
  return _rs;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_address2xml(
  in _node varchar,
  in _values varchar,
  in _count integer)
{
  declare N, _x integer;
  declare _rs, _loc, _name, _addr varchar;
  declare _arr_1, _arr_2 any;

  _rs     := '';
  _values := replace(_values,'"','');
  _arr_1  := split_and_decode(_values, 0, '\0\0,');
  for (N := 0; N < length (_arr_1); N := N + 1)
  {
    _name  := '';
    _addr  := '';
    _loc   := _arr_1[N];
    _loc   := replace(_loc,'<','');
    _loc   := replace(_loc,'>','');
    _loc   := replace(_loc,'\t',' ');
    _arr_2 := split_and_decode(ltrim(_loc),0,'\0\0 ');
    for (_x := 0; _x < length (_arr_2); _x := _x + 1)
    {
      if (isnull (strchr(_arr_2[_x], '@')) = 0)
      {
        _addr  := _arr_2[_x];
      } else {
        _name  := _name || ' ' || _arr_2[_x];
      }
    }
    if (_count = 1)
      return either(length (_name),OMAIL.WA.utl_decode_field (trim (_name)),trim (_addr));
    if (_count = 2)
      return trim (_addr);
    if (length(_name) > 0)
      _name  := sprintf ('<name>%V</name>',OMAIL.WA.utl_decode_field (trim (_name)),_x);
    if (length(_addr) > 0)
      _addr  := sprintf ('<email>%V</email>',_addr);

    _rs := sprintf('%s<%s>%s%s</%s>',_rs,_node,_name,_addr,_node);
  }
  return _rs;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_replyAddress(
  in _user_id  integer,
  in _address  varchar)
{
  declare N, _found integer;
  declare _rs, _s, _n, _m varchar;
  declare _array any;

  _found := 0;
  _rs    := '';
  _array := xpath_eval('/addres_list/*', xml_tree_doc(xml_tree( _address)),0);
  for (N := 0; N < length (_array); N := N + 1)
  {
    _s := '';
    _n := cast(xpath_eval('name()', _array[N]) as varchar);
    _m := cast(xpath_eval('./email', _array[N]) as varchar);
    if (not _found)
    {
      for (select WAI_NAME from DB.DBA.WA_MEMBER, DB.DBA.WA_INSTANCE where WAM_INST = WAI_NAME and WAM_USER = _user_id and WAI_TYPE_NAME = 'oMail' order by WAI_ID) do
      {
        if (WAI_NAME = _m)
          _found := 1;
      }
      _s := OMAIL.WA.xml2string(_array[N]);
      if (_found)
      {
        _s := replace(_s, '<' || _n || '>', '<from>');
        _s := replace(_s, '</' || _n || '>', '</from>');
      }
    } else {
      _s := OMAIL.WA.xml2string(_array[N]);
      if (_n = 'from')
      {
        _s := replace(_s, '<' || _n || '>', '<to>');
        _s := replace(_s, '</' || _n || '>', '</to>');
      }
    }
    _rs := _rs || _s;
  }
  return _rs;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_composeAddr(
  in _name varchar,
  in _mail varchar)
{
  if ((not is_empty_or_null (_name)) and (not is_empty_or_null (_mail)))
    return _name || ' <' || _mail || '>';

  if (not is_empty_or_null (_mail))
    return _mail;

  return '';
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_array2string(
  in _array     any,
  in _delimiter varchar)
{
  declare N integer;
  declare _rs, _del varchar;

  _del := '';
  _rs  := '';
  for (N := 0; N < length (_array); N := N + 1)
  {
    _rs  := sprintf('%s%s%s', _rs, _del, cast(aref(_array, N) as varchar));
    _del := _delimiter;
  }
  return _rs;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.array2xml(
  in V any,
  in lowerCase integer := 1,
  in root varchar := null)
{
  declare N integer;
  declare S, node, value varchar;

  S  := '';
  for (N := 0; N < length (V); N := N + 2)
  {
    if (isstring(V[N]))
    {
      node := cast (V[N] as varchar);
      if (lowerCase)
        node := lcase (node);
      if (isarray(V[N+1]) and not isstring(V[N+1]))
      {
        value := OMAIL.WA.array2xml(V[N+1], lowerCase) ;
      }
      else if (isnull (V[N+1]))
      {
  	    value := '';
      }
      else
      {
  	    value := cast(V[N+1] as varchar);
  	  }
  	  S := sprintf('%s<%s>%s</%s>\n', S, node, value, node);
    }
  }
  if (not isnull (root))
    S := sprintf ('<%s>%s</%s>', root, S, root);
  return S;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_attach(
  inout path any,
  inout lines any,
  inout params any)
{
  -- www procedure

  declare _rs,_sid,_realm,_sql_result1,_pnames,_eparams_url varchar;
  declare _params,_page_params any;
  declare _user_info any;
  declare _user_id,_error,_domain_id integer;

  _sid       := get_keyword('sid',params,'');
  _realm     := get_keyword('realm',params,'');
  _user_info := get_keyword('user_info',params);

  -- TEMP constants -----------------------------
  _user_id   := get_keyword('user_id',_user_info);
  _domain_id := 1;

  -- Set constants  -------------------------------------------------------------------
  _page_params := vector(0,0,0,0,0,0,0,0,0,0,0,0);
  _sql_result1 := '';

  -- Set Params --------------------------------------------------------------------
  _pnames := 'msg_id,faction,part_id';
  _params := OMAIL.WA.omail_str2params(_pnames,get_keyword('ap',params,'0,0,0'),',');

  _eparams_url := '';
  if (get_keyword('eparams',params,'') <> '') {
    _eparams_url := get_keyword('eparams',params,'');
  } else if (get_keyword('return',params,'') <> '') {
    _eparams_url := concat(_sql_result1,OMAIL.WA.omail_external_params_url(params));
  }

  -- Form Action---------------------------------------------------------------------
  if (get_keyword('fa.x',params,'') <> '') {
    -- save new attachment
    OMAIL.WA.omail_insert_attachment(_domain_id,_user_id,params,OMAIL.WA.omail_getp('msg_id',_params),_error);
    if (_error = 0) {
      OMAIL.WA.utl_redirect(sprintf('attach.vsp?sid=%s&&realm=%s&ap=%d%s',_sid,_realm,OMAIL.WA.omail_getp('msg_id',_params),_eparams_url));
    } else {
      OMAIL.WA.utl_redirect(sprintf('err.vsp?sid=%s&realm=%s&err=%d',_sid,_realm,_error));
    }
    return;

  }
  if (OMAIL.WA.omail_getp('faction',_params) = 1) {
    -- delete attachment
    OMAIL.WA.omail_delete_attachment(_domain_id,_user_id,OMAIL.WA.omail_getp('msg_id',_params),OMAIL.WA.omail_getp('part_id',_params),_error);
    if (_error = 0) {
      if (get_keyword('back', params,'') = 'write') {
        OMAIL.WA.utl_redirect(sprintf('write.vsp?sid=%s&realm=%s&wp=%d%s',_sid,_realm, OMAIL.WA.omail_getp('msg_id',_params),_eparams_url));
      } else if (get_keyword('back', params,'') = 'open') {
        OMAIL.WA.utl_redirect(sprintf('open.vsp?sid=%s&realm=%s&op=%d%s',_sid,_realm, OMAIL.WA.omail_getp('msg_id',_params),_eparams_url));
      } else {
        OMAIL.WA.utl_redirect(sprintf('attach.vsp?sid=%s&realm=%s&ap=%d%s',_sid,_realm,OMAIL.WA.omail_getp('msg_id',_params),_eparams_url));
      }
      return;
    }
    OMAIL.WA.utl_redirect(sprintf('err.vsp?sid=%s&realm=%s&err=%d',_sid,_realm,_error));
    return;
  }

  -- SQL Statement-------------------------------------------------------------------
  _sql_result1 := sprintf('%s',OMAIL.WA.omail_select_attachment(_domain_id,_user_id,OMAIL.WA.omail_getp('msg_id',_params),0));
  _sql_result1 := concat(_sql_result1,OMAIL.WA.omail_external_params_xml(params));

  aset(_page_params,0,vector('sid',_sid));
  aset(_page_params,1,vector('realm',_realm));
  aset(_page_params,2,vector('msg_id',OMAIL.WA.omail_getp('msg_id',_params)));
  aset(_page_params,3,vector('ap',OMAIL.WA.omail_params2str(_pnames,_params,',')));
  aset(_page_params,4,vector('user_info',OMAIL.WA.array2xml(_user_info)));

  -- XML structure-------------------------------------------------------------------
  return concat(OMAIL.WA.omail_page_params(_page_params), _sql_result1);
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_attachment_get(
  in _domain_id integer,
  in _user_id   integer,
  in _msg_id    integer,
  in _part_id   integer)
{
  declare _type_id,_tdata,_aparams,_bdata,_encoding any;

  select TYPE_ID, TDATA, BDATA, APARAMS
    INTO _type_id,_tdata,_bdata,_aparams
    from OMAIL.WA.MSG_PARTS
   where DOMAIN_ID = _domain_id
     and USER_ID   = _user_id
     and MSG_ID    = _msg_id
     and PART_ID   = _part_id;

  _tdata := concat(_bdata,_tdata);
  _encoding := OMAIL.WA.omail_get_encoding(_aparams);

  if ((_encoding = 'quoted-printable') or strstr(_tdata,'=3D'))
  {
    _tdata := replace(_tdata,'\r\n','\n');
    _tdata := replace(_tdata,'=\n','');
    _tdata := split_and_decode(_tdata,0,'=');
  }
  else if ((_encoding = 'base64'))
  {
    _tdata := encode_base64(_tdata);
  }
  return vector('type_id',_type_id,'data',_tdata,'params',_aparams);
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_attachments_copy(
  in  _domain_id  integer,
  in  _user_id    integer,
  in  _msg_id     integer,
  in  _re_msg_id  integer)
{
  declare _freetext_id, _part_id integer;

  _part_id := coalesce((select MAX(PART_ID) from OMAIL.WA.MSG_PARTS  where   DOMAIN_ID = _domain_id and USER_ID = _user_id and MSG_ID = _msg_id), 0);
  for (select DOMAIN_ID _DOMAIN_ID,
              USER_ID _USER_ID,
              TYPE_ID _TYPE_ID,
              CONTENT_ID _CONTENT_ID,
              BDATA _BDATA,
              DSIZE _DSIZE,
              APARAMS _APARAMS,
              PDEFAULT _PDEFAULT,
              FNAME _FNAME
         from OMAIL.WA.MSG_PARTS
        where DOMAIN_ID = _domain_id
          and USER_ID   = _user_id
          and MSG_ID    = _re_msg_id
          and PDEFAULT <> 1) do
  {
    _part_id := _part_id + 1;
    _freetext_id := sequence_next ('OMAIL.WA.omail_seq_eml_freetext_id');
    insert into OMAIL.WA.MSG_PARTS (DOMAIN_ID,USER_ID,MSG_ID,PART_ID,TYPE_ID,CONTENT_ID,BDATA,DSIZE,APARAMS,PDEFAULT,FNAME,FREETEXT_ID)
      values (_DOMAIN_ID,_USER_ID,_msg_id,_part_id,_TYPE_ID,_CONTENT_ID,_BDATA,_DSIZE,_APARAMS,_PDEFAULT,_FNAME,_freetext_id);
  }
  OMAIL.WA.omail_update_msg_attached (_domain_id, _user_id, _msg_id);
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_box(
  inout path any,
  inout lines any,
  inout params any)
{
  -- www procedure

  declare _rs, _sid, _realm, _bp, _sql_result1, _sql_result2, _sql_result3, _faction, _pnames, _ip varchar;
  declare _order,_direction,_params,_page_params any;
  declare _user_info, _settings any;
  declare _pageSize, _domain_id, _user_id, _folder_id, _msg_id integer;

  -- SECURITY CHECK ------------------------------------------------------------------
  _sid       := get_keyword('sid',params,'');
  _realm     := get_keyword('realm',params,'');
  _user_info := get_keyword('user_info',params);

  -- TEMP constants -------------------------------------------------------------------
  _user_id   := get_keyword('user_id',_user_info);
  _domain_id := 1;
  _pageSize  := 10;

  _msg_id    := cast (get_keyword ('id', params, '-1') as integer);
  if (_msg_id <> -1)
  {
    OMAIL.WA.utl_redirect (OMAIL.WA.omail_open_url (_sid, _realm, OMAIL.WA.domain_id2 (_user_id), _user_id, _msg_id));
    return;
  }

  -- GET SETTINGS ------------------------------
  _settings := OMAIL.WA.omail_get_settings(_domain_id, _user_id, 'base_settings');

  -- Set constants  -------------------------------------------------------------------
  _page_params := vector(0,0,0,0,0,0,0,0,0,0,0,0);

  -- Set Variable--------------------------------------------------------------------
  if (get_keyword ('fa_move.x',params,'') <> '')
  {
    _faction := 'move';
  }
  else if (get_keyword ('fa_delete.x',params,'') <> '')
  {
    _faction := 'delete';
  }
  else if (get_keyword ('fa_erase.x',params,'') <> '')
  {
    _faction := 'erase';
  }
  else if (get_keyword ('fa_group.x', params, '') <> '')
  {
    OMAIL.WA.omail_setparam ('groupBy', _settings, cast (get_keyword ('fa_group.x', params) as integer));
    OMAIL.WA.omail_setparam ('update_flag', _settings, 1);
  }
  _folder_id  := get_keyword('fid',params,'');

  -- Set Arrays----------------------------------------------------------------------
  _pnames := 'folder_id,skiped,order,direction';
  _params := OMAIL.WA.omail_str2params(_pnames,get_keyword('bp',params, '100,0,0,0,0'),',');

  OMAIL.WA.getOrderDirection (_order, _direction);

  -- Check Params for illegal values---------------------------------------------------
  if (OMAIL.WA.folder_check_id (_domain_id,_user_id, get_keyword ('folder_id',_params)) = 0)
  {
    -- check FOLDER_ID
    OMAIL.WA.utl_redirect(sprintf('err.vsp?sid=%s&realm=%s&err=%d',_sid,_realm,1100));
    return;
  }

  if (not OMAIL.WA.omail_check_interval(get_keyword ('skiped',_params),0,100000))
  {
    -- check SKIPED
    OMAIL.WA.utl_redirect(sprintf('err.vsp?sid=%s&realm=%s&err=%d',_sid,_realm,1101));
    return;
  }

  if (not OMAIL.WA.omail_check_interval(get_keyword ('order',_params),1,(length (_order)-1)))
  { -- check ORDER BY
    OMAIL.WA.omail_setparam('order',_params,get_keyword('msg_order',_settings)); -- get from settings
  }
  else if (get_keyword ('order',_params) <> get_keyword ('msg_order',_settings))
  {
    OMAIL.WA.omail_setparam('msg_order',_settings,get_keyword('order',_params)); -- update new value in settings
    OMAIL.WA.omail_setparam('update_flag',_settings,1);
  }

  if (not OMAIL.WA.omail_check_interval(get_keyword ('direction',_params),1,(length (_direction)-1)))
  {
    -- check ORDER WAY
    OMAIL.WA.omail_setparam('direction',_params,get_keyword('msg_direction',_settings));
  }
  else if (get_keyword ('direction',_params) <> get_keyword ('msg_direction',_settings))
  {
    OMAIL.WA.omail_setparam ('msg_direction',_settings, get_keyword ('direction',_params));
    OMAIL.WA.omail_setparam('update_flag',_settings,1);
  }

  -- Form Action---------------------------------------------------------------------
  if (_faction = 'move')
    {
    -- > 'move msg to folder'
    OMAIL.WA.messages_move (_domain_id, _user_id, params);
      _bp := OMAIL.WA.omail_params2str(_pnames,_params,',');

    OMAIL.WA.utl_redirect_adv(sprintf('box.vsp?sid=%s&realm=%s&bp=%s',_sid,_realm,_bp),params);
    return;
  }
  if (_faction = 'delete')
  {
    -- > 'move msg to trash or delete if it's in trash'
    OMAIL.WA.messages_delete (_domain_id,_user_id, params);
    _bp := OMAIL.WA.omail_params2str(_pnames,_params,',');

    OMAIL.WA.utl_redirect_adv(sprintf('box.vsp?sid=%s&realm=%s&bp=%s',_sid,_realm,_bp),params);
    return;
  }
  if (_faction = 'erase')
  {
    -- > 'unconditional delete'
    OMAIL.WA.message_erase (_domain_id, _user_id, cast (get_keyword ('ch_msg', params) as integer));
    _bp := OMAIL.WA.omail_params2str(_pnames,_params,',');

    OMAIL.WA.utl_redirect_adv(sprintf('box.vsp?sid=%s&realm=%s&bp=%s',_sid,_realm,_bp),params);
    return;
  }

  -- Page Params---------------------------------------------------------------------
  aset(_page_params,0,vector('sid',_sid));
  aset(_page_params,1,vector('realm',_realm));
  aset(_page_params,2,vector('folder_id',get_keyword('folder_id',_params)));
  aset (_page_params, 3, vector ('folder_type', OMAIL.WA.folder_type (_domain_id, _user_id, get_keyword ('folder_id',_params))));
  aset (_page_params,4,vector ('bp',OMAIL.WA.omail_params2str(_pnames,_params,',')));
  aset (_page_params,5,vector ('user_info', OMAIL.WA.array2xml(_user_info)));

  if (get_keyword ('msg_result',_settings) <> '')
  {
    OMAIL.WA.omail_setparam('aresults',_params,get_keyword('msg_result',_settings));
  } else {
    OMAIL.WA.omail_setparam('aresults',_params,_pageSize);
  }
  OMAIL.WA.omail_setparam ('groupBy', _params, get_keyword ('groupBy', _settings));
  OMAIL.WA.omail_set_settings(_domain_id, _user_id, 'base_settings', _settings);

  -- SQL Statement-------------------------------------------------------------------
  _sql_result1 := OMAIL.WA.messages_list (_domain_id, _user_id, _params);
  _sql_result2 := OMAIL.WA.folders_list (_domain_id, _user_id);
  _sql_result3 := OMAIL.WA.folders_combo_list (_domain_id, _user_id, OMAIL.WA.omail_getp ('folder_id', _params));

  -- XML structure-------------------------------------------------------------------
  _rs := '';
  _rs := sprintf('%s%s' ,_rs, OMAIL.WA.omail_page_params(_page_params));
  _rs := sprintf ('%s<groupBy>%d</groupBy>',_rs, get_keyword ('groupBy', _settings));
  _rs := sprintf('%s<messages>%s</messages>' ,_rs,_sql_result1);
  _rs := sprintf('%s%s' ,_rs,_sql_result2);
  _rs := sprintf ('%s%s', _rs, _sql_result3);
  _rs := sprintf('%s%s' ,_rs,OMAIL.WA.omail_external_params_xml(params));
  _rs := sprintf('%s%s' ,_rs,OMAIL.WA.omail_external_params_lines(params,_params));

  -- Save Settings --------------------------------------------------------------
  return _rs;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_ch_pop3(
  inout path any,
  inout lines any,
  inout params any)
{
  -- www procedure

  declare _rs, _sid, _realm,_bp,_sql_result1, _pnames, _node varchar;
  declare _params,_page_params any;
  declare _user_info, _settings any;
  declare _user_id,_folder_id,_domain_id,_error,_new_msg integer;

  _sid       := get_keyword('sid',params,'');
  _realm     := get_keyword('realm',params,'');
  _user_info := get_keyword('user_info',params);

  -- TEMP constants -------------------------------------------------------------------
  _user_id   := get_keyword('user_id',_user_info);
  _domain_id := 1;

  -- GET SETTINGS ------------------------------
  _settings := OMAIL.WA.omail_get_settings(_domain_id, _user_id, 'base_settings');

  -- Set constants  -------------------------------------------------------------------
  _page_params := vector(0,0,0,0,0,0,0,0,0,0,0,0);

  -- Set Arrays----------------------------------------------------------------------
  _pnames := 'acc_id,action,new_msg,ch_acc_id';
  _params := OMAIL.WA.omail_str2params(_pnames,get_keyword('cp',params,'0'),',');

  -- Form Action---------------------------------------------------------------------
  if (get_keyword ('fa_save.x',params,'') <> '')
  {
    -- > save or edit account
    _error := OMAIL.WA.external_account_update (_domain_id, _user_id, params);
    if (_error = 0)
    {
      OMAIL.WA.utl_redirect (sprintf ('ch_pop3.vsp?sid=%s&realm=%s', _sid, _realm));
    } else {
      OMAIL.WA.utl_redirect (sprintf ('err.vsp?sid=%s&realm=%s&err=%d', _sid, _realm,_error));
  }
    return;
  }
  if (OMAIL.WA.omail_getp ('action',_params) = 1)
  {
    -- > check now account
    _error := OMAIL.WA.external_account_check (OMAIL.WA.omail_getp ('acc_id',_params), _new_msg);
    if (_error = 0)
    {
      OMAIL.WA.utl_redirect(sprintf('ch_pop3.vsp?sid=%s&realm=%s&cp=0,0,%d,%d',_sid,_realm,_new_msg,OMAIL.WA.omail_getp('acc_id',_params)));
    } else {
      OMAIL.WA.utl_redirect(sprintf('ch_pop3.vsp?sid=%s&realm=%s',_sid,_realm));
    }
    return;
    }
  if (OMAIL.WA.omail_getp ('action',_params) = 2)
  {
    -- > check all acc
    _error := OMAIL.WA.external_account_check_all (_domain_id, _user_id);
    if (_error = 0)
    {
      OMAIL.WA.utl_redirect(sprintf('box.vsp?sid=%s&realm=%s',_sid,_realm));
    } else {
      OMAIL.WA.utl_redirect(sprintf('err.vsp?sid=%s&realm=%s&err=%d',_sid,_realm,_error));
    }
    return;
  }
  if (OMAIL.WA.omail_getp ('action',_params) = 3)
  {
    -- > save or edit account
    _error := OMAIL.WA.external_account_delete (_domain_id, _user_id, _params);
    if (_error = 0)
    {
      OMAIL.WA.utl_redirect(sprintf('ch_pop3.vsp?sid=%s&realm=%s',_sid,_realm));
    } else {
      OMAIL.WA.utl_redirect(sprintf('err.vsp?sid=%s&realm=%s&err=%d',_sid,_realm,_error));
    }
    return;
  }

  -- Page Params---------------------------------------------------------------------
  aset(_page_params,0,vector('sid',_sid));
  aset(_page_params,1,vector('realm',_realm));
  aset(_page_params,2,vector('user_info',OMAIL.WA.array2xml(_user_info)));

  -- SQL Statement-------------------------------------------------------------------
  _sql_result1 := OMAIL.WA.external_account_get (_domain_id, _user_id, OMAIL.WA.omail_getp ('acc_id',_params));
  _node := case when (OMAIL.WA.omail_getp ('acc_id',_params) = 0) then 'accounts' else 'account' end;

  -- XML structure-------------------------------------------------------------------
  _rs := '';
  _rs := sprintf('%s%s' ,_rs,OMAIL.WA.omail_page_params(_page_params));
  _rs := sprintf('%s<%s>' ,_rs,_node);
  _rs := sprintf('%s%s' ,_rs,_sql_result1);
  _rs := sprintf('%s</%s>' ,_rs,_node);
  _rs := sprintf('%s<new_msg>%d</new_msg>' , _rs, OMAIL.WA.omail_getp('new_msg',_params));
  _rs := sprintf('%s<ch_acc_id>%d</ch_acc_id>', _rs, OMAIL.WA.omail_getp('ch_acc_id',_params));

  return _rs;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.external_account_info (
  in    _domain_id integer,
  in    _user_id integer,
  in    _source_id integer,
  inout _server varchar,
  inout _user varchar,
  inout _password varchar)
{
  declare _retValue integer;

  _retValue := 0;
  for (select * from OMAIL.WA.EXTERNAL_ACCOUNT where EA_DOMAIN_ID = _domain_id and EA_USER_ID = _user_id and EA_ID = _source_id and EA_TYPE = 'imap') do
  {
    _server := sprintf ('%s:%d', EA_HOST, EA_PORT);
    _user := EA_USER;
    _password := pwd_magic_calc ('pop3', EA_PASSWORD);

    _retValue := 1;
  }
  return _retValue;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.external_account_schedule ()
{
  declare msg_count integer;

  for (select EA_ID
         from OMAIL.WA.EXTERNAL_ACCOUNT
        where (EA_CHECK_DATE is null or EA_CHECK_DATE < dateadd (case when EA_CHECK_INTERVAL = 1 then 'day' else 'hour' end, -1, now()))
      ) do
  {
    OMAIL.WA.external_account_check (EA_ID, msg_count);
  }
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.external_account_check_all (
  in domain_id integer,
  in user_id integer)
{
  declare msg_count integer;

    -- check all accounts
  for (select EA_ID
         from OMAIL.WA.EXTERNAL_ACCOUNT
        where EA_DOMAIN_ID = domain_id
          and EA_USER_ID = user_id
          and EA_CHECK_DATE < dateadd ('minute', -1, now())
      ) do
  {
    OMAIL.WA.external_account_check (EA_ID, msg_count);
  }
  return 0;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.external_account_check (
  in id integer,
  out msg_count integer)
{
  declare _error, _checked, _folders, _folderNames, _folderParts, _folderDelimiter, _folderId, _folderParentId, _folderName, _folderPath any;
  declare _msgId, _messages, _mlist any;
  declare N, M, _server, _connectType, _password, _check, _buffer integer;

  DECLARE EXIT HANDLER FOR SQLSTATE '2E000'
  {
    -- bad_server:
    OMAIL.WA.external_account_check_set (id, 1);
    return 1811;
  };
  DECLARE EXIT HANDLER FOR SQLSTATE '08006'
  {
    -- bad_user:
    OMAIL.WA.external_account_check_set (id, 2);
    return 1812;
  };
  DECLARE EXIT HANDLER FOR SQLSTATE '08001'
  {
    -- Cannot connect in pop3_get
    OMAIL.WA.external_account_check_set (id, 3);
    return 1813;
  };
  DECLARE EXIT HANDLER FOR SQLSTATE '*'
  {
    --dbg_obj_print ('', __SQL_STATE, __SQL_MESSAGE);
    ;
  };

  commit work;
  for (select * from OMAIL.WA.EXTERNAL_ACCOUNT where EA_ID = id) do
  {
    -- server parameters ---------------------------------------------------------
    _server := sprintf ('%s:%d', EA_HOST, EA_PORT);
    _connectType := case when EA_CONNECT_TYPE = 'ssl' then 1 else 0 end;
    _password := pwd_magic_calc ('pop3', EA_PASSWORD);
    _buffer    := 10000000;
    _mlist     := vector();

    if (EA_TYPE = 'pop3')
    {
      -- get list with unique msg ids from server
      _messages := pop3_get (_server, EA_USER, _password, _buffer, 'UIDL', null, _connectType);

      -- check for duplicate messages
    for (N := 0; N < length (_messages); N := N + 1)
    {
        if (exists (select 1 from OMAIL.WA.MESSAGES where DOMAIN_ID = EA_DOMAIN_ID and USER_ID = EA_USER_ID and MSG_SOURCE = EA_ID and UNIQ_MSG_ID = _messages[N]))
        _mlist := vector_concat (_mlist, vector (_messages[N]));
    }
      _messages := pop3_get (_server, EA_USER, _password, _buffer, either (equ (EA_MCOPY, 0), 'DELETE', ''), _mlist, _connectType);

      -- insert messages
      msg_count := length (_messages);
    for (N := 0; N < length (_messages); N := N + 1)
    {
        OMAIL.WA.omail_receive_message (EA_DOMAIN_ID, EA_USER_ID, null, _messages[N][1], subseq (_messages[N][0], 0, 100), EA_ID, EA_FOLDER_ID);
      }
    }
    if (EA_TYPE = 'imap')
    {
      declare X integer;
      declare X2 string;

      X2 := '';

      -- check authentication
      imap_get (_server, EA_USER, _password, _buffer);

      -- load folders
      msg_count := 0;
      _folders := imap_get (_server, EA_USER, _password, _buffer, 'list', '*');
      if (length (_folders))
      {
        _checked := vector ();
        foreach (any _folder in _folders) do
        {
          _folderParts := regexp_parse('\\((.*)\\)\\s\\"(.*)\\"\\s\\"(.*)\\"', _folder, 0);
          if (length (_folderParts) = 8)
          {
            _error := 0;
            _folderPath := '';
            _folderParentId := EA_FOLDER_ID;
            _folderDelimiter := subseq (_folder, _folderParts[4], _folderParts[5]);
            _folderName := subseq (_folder, _folderParts[6], _folderParts[7]);
            _folderParts := split_and_decode (_folderName, 0, '\0\0' || _folderDelimiter);
            for (M := 0; M < length (_folderParts); M := M + 1)
            {
              _folderPath := trim (_folderPath || _folderDelimiter || _folderParts[M], _folderDelimiter);
              _folderId := OMAIL.WA.folder_name_exists (EA_DOMAIN_ID, EA_USER_ID, _folderParentId, _folderParts[M]);
              if (_folderId = 0)
              {
                _folderId := OMAIL.WA.folder_create (EA_DOMAIN_ID, EA_USER_ID, vector ('parent_id', _folderParentId, 'name', _folderParts[M], 'data', _folderPath, 'source', EA_ID), _error);
                if (_error <> 0)
                  goto _exit;
              }
              _folderParentId := _folderId;
            }
            if ((_folderPath = _folderName) and not OMAIL.WA.vector_contains (_checked, _folderName))
            {
              _checked := vector_concat (_checked, vector (_folderName));
              _messages := imap_get (_server, EA_USER, _password, _buffer, 'select', _folderName);
              foreach (any _message in _messages) do
              {
                _msgId := (select MSG_ID from OMAIL.WA.MESSAGES where DOMAIN_ID = EA_DOMAIN_ID and USER_ID = EA_USER_ID and MSG_SOURCE = EA_ID and UNIQ_MSG_ID = _message[0]);
                if (isnull (_msgId))
                {
                  -- if (X < 1)
                  -- {
                  --   declare tmp any;
                  --
                  --   tmp :=  mime_tree(_message[2]);
                  --   if (not (isarray(tmp)))
                  --   {
                  --     X2 := X2 || _message[2] || '\n\n--------------------------\n\n';
                  --     X := X + 1;
                  --     dbg_obj_print ('', mime_header(_message[2]));
                  --   }
                  -- }

                  if (OMAIL.WA.omail_receive_message (EA_DOMAIN_ID, EA_USER_ID, null, _message[2], _message[0], EA_ID, _folderId, 1))
                    msg_count := msg_count + 1;
                }
                else
                {
                  OMAIL.WA.message_move (EA_DOMAIN_ID, EA_USER_ID, _msgId, _folderId, 0);
                }
              }
            }
          _exit:;
          }
        }
        for (select FOLDER_ID, DATA from OMAIL.WA.FOLDERS where DOMAIN_ID = EA_DOMAIN_ID and USER_ID = EA_USER_ID and F_SOURCE = EA_ID) do
        {
          if (not is_empty_or_null (DATA) and not OMAIL.WA.vector_contains (_checked, DATA))
          {
            OMAIL.WA.folder_erase (EA_DOMAIN_ID, EA_USER_ID, FOLDER_ID, 0);
          }
        }
      }
      -- string_to_file (sprintf('bad-imap-mail%d.dmp', id), X2, 0);
    }

    -- set flag for successful download ----------------------------------------
    OMAIL.WA.external_account_check_set (id, 0);
  }
  return 0;
}
;

create procedure OMAIL.WA.external_account_check_set (
  in id integer,
  in error integer)
{
  update OMAIL.WA.EXTERNAL_ACCOUNT
     set EA_CHECK_DATE = now(),
         EA_CHECK_ERROR = error
   where EA_ID = id;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.external_account_update (
  in _domain_id  integer,
  in _user_id    integer,
  inout _params any)
{
  declare _id, _check_interval, _mcopy, _folder_id, _error, _port integer;
  declare _name, _type, _host, _connect_type, _user, _password, _folder_name varchar;

  _id             := cast (get_keyword ('id', _params, 0) as integer);
  _name           := trim (get_keyword ('name', _params));
  _type           := trim (get_keyword ('type', _params, 'pop3'));
  _host           := trim (get_keyword ('host', _params));
  _port           := cast (get_keyword ('port', _params, case when _type = 'pop3' then 110 else 143 end) as integer);
  _connect_type   := trim (get_keyword ('connect_type', _params, 'none'));
  _user           := trim (get_keyword ('user', _params,''));
  _password       := trim (get_keyword ('password', _params));
  _check_interval := cast (get_keyword ('check_interval', _params, 2) as integer);
  _mcopy          := cast (get_keyword ('mcopy', _params, 1) as integer);
  _folder_id      := cast (get_keyword ('folder_id', _params, case when _type = 'pop3' then 100 else 0 end) as integer);
  _folder_name    := trim (get_keyword ('folder_name', _params));

  OMAIL.WA.test (_name, vector ('name', 'Account Name', 'class', 'varchar', 'canEmpty', 0));
  OMAIL.WA.test (_host, vector ('name', 'Server Address', 'class', 'varchar', 'canEmpty', 0));
  OMAIL.WA.test (_user, vector ('name', 'User Name', 'class', 'varchar', 'canEmpty', 0));
  OMAIL.WA.test (_folder_name, vector ('name', 'Folder Name', 'class', 'folder', 'canEmpty', case when _type = 'pop3' or _id <> 0 then 1 else 0 end, 'minLength', 1, 'maxLength', 20));
  if (length (_folder_name))
  {
    declare _folderParams any;

    _folderParams := vector ('parent_id', _folder_id, 'name', _folder_name);
    if (_type = 'imap')
      _folderParams := vector_concat (_folderParams, vector ('systemFlag', 'S'));
    if (_type = 'imap')
      _folderParams := vector_concat (_folderParams, vector ('seqNo', 10));

    _folder_id := OMAIL.WA.folder_create (_domain_id, _user_id, _folderParams, _error);
    if (_error <> 0)
      return _error;
}
  OMAIL.WA.test (_folder_id, vector ('name', 'Folder', 'class', 'integer', 'canEmpty', case when _id <> 0 then 0 else 1 end));

  if (_id <> 0)
{
    update OMAIL.WA.EXTERNAL_ACCOUNT
       set EA_NAME = _name,
           EA_TYPE = _type,
           EA_HOST = _host,
           EA_PORT = _port,
           EA_CONNECT_TYPE = _connect_type,
           EA_USER = _user,
           EA_FOLDER_ID = _folder_id,
           EA_CHECK_INTERVAL = _check_interval,
           EA_MCOPY = _mcopy
     where EA_DOMAIN_ID = _domain_id
       and EA_USER_ID = _user_id
       and EA_ID = _id;

    if (_password <> '**********')
    {
      update OMAIL.WA.EXTERNAL_ACCOUNT
         set EA_PASSWORD = pwd_magic_calc ('pop3', _password)
       where EA_DOMAIN_ID = _domain_id
         and EA_USER_ID = _user_id
         and EA_ID = _id;
}
  }
  else
{
    insert into OMAIL.WA.EXTERNAL_ACCOUNT (EA_DOMAIN_ID, EA_USER_ID, EA_NAME, EA_TYPE, EA_HOST, EA_PORT, EA_CONNECT_TYPE, EA_USER, EA_PASSWORD, EA_FOLDER_ID, EA_CHECK_INTERVAL, EA_MCOPY, EA_CHECK_ERROR)
      values (_domain_id, _user_id, _name, _type, _host, _port, _connect_type, _user, pwd_magic_calc ('pop3', _password), _folder_id, _check_interval, _mcopy, 0);

    _id := (select EA_ID from OMAIL.WA.EXTERNAL_ACCOUNT where EA_DOMAIN_ID = _domain_id and EA_USER_ID = _user_id and EA_NAME = _name);
  }
  if (_type = 'imap')
    update OMAIL.WA.FOLDERS set F_SOURCE = _id where DOMAIN_ID = _domain_id and USER_ID = _user_id and FOLDER_ID = _folder_id;

    return 0;
}
;


-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.external_account_delete (
  in  _domain_id integer,
  in  _user_id   integer,
  inout _params any)
{
  declare _id, _path any;

  _id := OMAIL.WA.omail_getp ('acc_id', _params);
  for (select * from OMAIL.WA.EXTERNAL_ACCOUNT where EA_DOMAIN_ID = _domain_id and EA_USER_ID = _user_id and EA_ID = _id and EA_TYPE = 'imap') do
  {
    _path := (select PATH from OMAIl.WA.FOLDERS where DOMAIN_ID = _domain_id and USER_ID = _user_id and FOLDER_ID = EA_FOLDER_ID and F_SOURCE = _id);
    if (not isnull (_path))
    {
      for (select FOLDER_ID from OMAIL.WA.FOLDERS where DOMAIN_ID = _domain_id and USER_ID = _user_id and F_SOURCE = _id and PATH like _path || '%' order by PATH desc) do
      {
        OMAIL.WA.folder_erase (_domain_id, _user_id, FOLDER_ID, 0);
      }
    }
  }
  delete
    from OMAIL.WA.EXTERNAL_ACCOUNT
   where EA_DOMAIN_ID = _domain_id
     and EA_USER_ID = _user_id
     and EA_ID = _id;

  return 0;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.folders_list (
  in  _domain_id integer,
  in _user_id integer)
{
  return sprintf ('<folders>\n%s\n</folders>', OMAIL.WA.folders_list_work (_domain_id, _user_id));
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.folders_combo_list (
  in  _domain_id integer,
  in  _user_id   integer,
  in _folder_id any := null)
{
  declare _start_id, _source, _path any;

  OMAIL.WA.imap_folder_info (_domain_id, _user_id, _folder_id, _start_id, _source, _path);
  return sprintf ('<foldersCombo>\n%s\n</foldersCombo>', OMAIL.WA.folders_list_work (_domain_id, _user_id, _start_id, _source));
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.folders_list_work (
  in _domain_id integer,
  in _user_id   integer,
  in _folder_id  integer := 0,
  in _source     integer := null,
  in _level      integer := 0,
  in _ftree      varchar := '')
{
  declare _rs,_s,_ftree_loc varchar;
  declare _all_cnt,_new_cnt,N,_len,_all_size integer;

  N := 0;
  _rs := '';
  _len := (select COUNT(*) from OMAIL.WA.FOLDERS where DOMAIN_ID = _domain_id and USER_ID = _user_id and PARENT_ID = _folder_id and (coalesce(F_SOURCE, 0) = _source or isnull (_source)));
  for (select * from OMAIL.WA.FOLDERS where DOMAIN_ID = _domain_id and USER_ID = _user_id and PARENT_ID = _folder_id and (coalesce(F_SOURCE, 0) = _source or isnull (_source)) order by SEQ_NO, NAME) do
  {
    OMAIL.WA.messages_count(_domain_id, _user_id, FOLDER_ID, _all_cnt, _new_cnt, _all_size);
    if (length (_ftree) > 0)
      _ftree := concat(substring(_ftree,1,(length (_ftree)-16)),replace (substring(_ftree,length (_ftree)-15,16),'<fnode>-</fnode>','<fnode>.</fnode>'));

    _ftree := replace (_ftree, 'F', 'I');
    _ftree_loc := sprintf ('%s<fnode>%s</fnode>', _ftree, case when (N + 1 = _len) then '-' else 'F' end);

    _rs := sprintf ('%s<folder id="%d" systemFlag="%s" smartFlag="%s" source="%d">\n', _rs, FOLDER_ID, SYSTEM_FLAG, SMART_FLAG, coalesce(F_SOURCE, 0));
    _rs := sprintf ('%s<name>%V</name>\n', _rs, NAME);
    _rs := sprintf ('%s<level str="%s" num="%d" />\n', _rs, repeat('~',_level),_level);
    _rs := sprintf ('%s<ftree>%s</ftree>\n', _rs, _ftree_loc);
    _rs := sprintf ('%s<all_cnt>%d</all_cnt>\n', _rs ,_all_cnt);
    _rs := sprintf ('%s<all_size>%d</all_size>\n', _rs, _all_size);
    _rs := sprintf ('%s<new_cnt>%d</new_cnt>\n', _rs, _new_cnt);
    _s  := OMAIL.WA.folders_list_work (_domain_id, _user_id, FOLDER_ID, _source, _level+1, _ftree_loc);
    if (_s <> '')
      _rs := sprintf ('%s<folders>\n%s\n</folders>\n', _rs, _s);
    _rs := sprintf ('%s</folder>\n', _rs);
    N := N + 1;
  }
  return _rs;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.folder_test (
  in  _params any)
{
  declare tmp, tmp2 any;

  if (isnull (_params))
    return;

  tmp := get_keyword ('q_after', _params);
  OMAIL.WA.test (tmp, vector ('name', 'Received after', 'type', 'date', 'canEmpty', 1));
  tmp := get_keyword ('q_before', _params);
  OMAIL.WA.test (tmp, vector ('name', 'Received before', 'type', 'date', 'canEmpty', 1));
  tmp := get_keyword ('q_from', _params);
  if ((tmp <> '') and is_empty_or_null (OMAIL.WA.email_search_str (tmp)))
    signal ('TEST', 'Field ''From'' contains invalid characters!<>');
  tmp := get_keyword ('q_to', _params);
  if ((tmp <> '') and is_empty_or_null (OMAIL.WA.email_search_str (tmp)))
    signal ('TEST', 'Field ''To'' contains invalid characters!<>');
  tmp := get_keyword ('q_body', _params);
  if (tmp <> '')
  {
    OMAIL.WA.test (tmp, vector ('name', 'Body', 'class', 'free-text'));
    if (is_empty_or_null (FTI_MAKE_SEARCH_STRING (tmp)) and (tmp <> ''))
      signal ('TEST', 'Field ''Body'' contains invalid characters!<>');
  }
  tmp := get_keyword ('q_tags', _params);
  OMAIL.WA.test (tmp, vector ('name', 'Tags', 'class', 'tags', 'message', 'One of the tags is too short or contains bad characters or is a noise word!'));
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.folder_name (
  in  _domain_id integer,
  in  _user_id   integer,
  in _folder_id integer)
{
  return coalesce((select NAME from OMAIL.WA.FOLDERS where DOMAIN_ID = _domain_id and USER_ID = _user_id and FOLDER_ID = _folder_id), '');
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.folder_create (
  in  _domain_id integer,
  in  _user_id integer,
  in  _params any,
  out _error integer)
{
  return OMAIL.WA.folder_edit (_domain_id, _user_id, 0, 0, _params, _error);
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.folder_create_path (
  in  _domain_id integer,
  in  _user_id integer,
  in  _path varchar,
  in  _delimiter varchar,
  in  _params any,
  out _error integer)
{
  declare M, _folder_id, _parent_id integer;
  declare _parts any;

  _folder_id := 0;
  _parent_id := 0;
  _parts := split_and_decode (_path, 0, '\0\0' || _delimiter);
  for (M := 0; M < length (_parts); M := M + 1)
  {
    _folder_id := OMAIL.WA.folder_name_exists (_domain_id, _user_id, _parent_id, _parts[M]);
    if (_folder_id = 0)
      _folder_id := OMAIL.WA.folder_create (_domain_id, _user_id, vector_concat (_params, vector ('parent_id', _parent_id, 'name', _parts[M])), _error);
    if (_error <> 0)
      return 0;
    _parent_id := _folder_id;
  }
  return _folder_id;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.folder_edit (
  in  _domain_id integer,
  in  _user_id integer,
  in  _folder_id integer,
  in  _action_id integer,
  in  _params any,
  out _error integer)
{
  declare N, _trash_id, _parent_id integer;
  declare _folder_name, _folder_name2 varchar;
  declare _data, _smartFlag any;

  _error := 0;
  if (_action_id = 0)
  {
    -- edit folder
    _parent_id := get_keyword ('parent_id', _params);
    _folder_name := get_keyword ('name', _params);
    if (length (_folder_name) > 20)
    {
      _error := 1201;
    }
    else if (length (_folder_name) < 1)
    {
      _error := 1202;
    }
    else if (OMAIL.WA.folder_name_exists (_domain_id, _user_id, _parent_id, _folder_name, _folder_id))
    {
      _error := 1203;
    }
    else
    {
      _data := get_keyword ('data', _params);
      _smartFlag := get_keyword ('smartFlag', _params, 'N');
      if (_smartFlag = 'S')
      {
        OMAIL.WA.folder_test (_data);
        _data := serialize (_data);
      }
      if (_folder_id = 0)
      {
        _folder_id := sequence_next('OMAIL.WA.omail_seq_eml_folder_id');
        insert into OMAIL.WA.FOLDERS (DOMAIN_ID, USER_ID, FOLDER_ID, PARENT_ID, SYSTEM_FLAG, SMART_FLAG, SEQ_NO, NAME, DATA, F_SOURCE)
          values (_domain_id, _user_id, _folder_id, _parent_id, get_keyword ('systemFlag', _params, 'N'), _smartFlag, get_keyword ('seqNo', _params, 0), _folder_name, _data, get_keyword ('source', _params));
      }
      else
      {
        _error := OMAIL.WA.folder_check_parent (_domain_id, _user_id, _folder_id, _parent_id);
        if (_error = 0)
        {
          update OMAIL.WA.FOLDERS
             set PARENT_ID = _parent_id,
                 NAME      = _folder_name,
                 DATA      = _data
           where DOMAIN_ID = _domain_id
             and USER_ID   = _user_id
             and FOLDER_ID = _folder_id;
        }
      }
      return _folder_id;
    }
  }
  else if (_action_id = 1)
  {
    -- delete (move) folder
    OMAIL.WA.folder_delete (_domain_id, _user_id, _folder_id);
  }
  else if (_action_id = 2)
  {
    -- empty folder
    for (select MSG_ID from OMAIL.WA.MESSAGES where DOMAIN_ID = _domain_id and USER_ID = _user_id and FOLDER_ID = _folder_id) do
      OMAIL.WA.message_delete (_domain_id, _user_id, MSG_ID);
  }
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.folder_delete (
  in _domain_id integer,
  in _user_id integer,
  in _folder_id integer,
  in _full_mode integer := 1)
{
  if (OMAIL.WA.folder_isSystem (_domain_id, _user_id, _folder_id))
    return;

  if (OMAIL.WA.folder_isSmart(_domain_id, _user_id, _folder_id))
    return OMAIL.WA.folder_erase (_domain_id, _user_id, _folder_id, _full_mode);

  if (OMAIL.WA.folder_isErasable (_domain_id, _user_id, _folder_id))
    return OMAIL.WA.folder_erase (_domain_id, _user_id, _folder_id, _full_mode);

  -- move to trash
  return OMAIL.WA.folder_move (_domain_id, _user_id, _folder_id, OMAIL.WA.folder_trash (_domain_id, _user_id, _folder_id));
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.folder_erase (
  in _domain_id integer,
  in _user_id integer,
  in _folder_id integer,
  in _full_mode integer := 1)
{
  declare _parent_id integer;

  for (select MSG_ID from OMAIL.WA.MESSAGES where DOMAIN_ID = _domain_id and USER_ID = _user_id and FOLDER_ID = _folder_id) do
  {
    if (not OMAIL.WA.message_erase (_domain_id, _user_id, MSG_ID, _full_mode))
      return 0;
  }
  for (select FOLDER_ID from OMAIL.WA.FOLDERS where DOMAIN_ID = _domain_id and USER_ID = _user_id and PARENT_ID = _folder_id) do
  {
    if (not OMAIL.WA.folder_erase (_domain_id, _user_id, FOLDER_ID, _full_mode))
      return 0;
  }

  _parent_id := (select PARENT_ID from OMAIL.WA.FOLDERS where DOMAIN_ID = _domain_id and USER_ID = _user_id and FOLDER_ID = _folder_id);
  if (not is_empty_or_null (_parent_id))
  {
    update OMAIL.WA.EXTERNAL_ACCOUNT
       set EA_FOLDER_ID = _parent_id
     where EA_DOMAIN_ID = _domain_id
       and EA_USER_ID   = _user_id
       and EA_FOLDER_ID = _folder_id;
  }

  if (_full_mode and not OMAIL.WA.imap_folder_erase (_domain_id, _user_id, _folder_id))
    return 0;

  delete
    from OMAIL.WA.FOLDERS
   where DOMAIN_ID = _domain_id
     and USER_ID = _user_id
     and FOLDER_ID = _folder_id;

  return 1;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.folder_move (
  in _domain_id integer,
  in _user_id   integer,
  in _folder_id integer,
  in _parent_id integer)
{
  declare N integer;
  declare _folder_name, _folder_name2 varchar;

  N := 1;
  _folder_name := OMAIL.WA.folder_name (_domain_id, _user_id, _folder_id);
  _folder_name2 := _folder_name;
  while (OMAIL.WA.folder_name_exists (_domain_id, _user_id, _parent_id, _folder_name2) and OMAIL.WA.folder_name_exists (_domain_id, _user_id, _folder_id, _folder_name2))
  {
    _folder_name2 := sprintf ('%s (%d)', _folder_name, N);
    N := N + 1;
  }
  if (_folder_name <> _folder_name2)
  {
    if (not OMAIL.WA.folder_rename (_domain_id, _user_id, _folder_id, _folder_name2))
      return 0;
  }

  if (not OMAIL.WA.imap_folder_move (_domain_id, _user_id, _folder_id, _parent_id))
    return 0;

  update OMAIL.WA.FOLDERS
     set PARENT_ID = _parent_id
   where DOMAIN_ID = _domain_id
     and USER_ID   = _user_id
     and FOLDER_ID = _folder_id;

  return 1;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.folder_rename (
  in _domain_id integer,
  in _user_id   integer,
  in _folder_id integer,
  in _name      varchar)
  {
  if (not OMAIL.WA.imap_folder_rename (_domain_id, _user_id, _folder_id, _name))
    return 0;

  update OMAIL.WA.FOLDERS
     set NAME = _name
       where DOMAIN_ID = _domain_id
         and USER_ID   = _user_id
         and FOLDER_ID = _folder_id;

  return 1;
  }
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.folder_check_id (
  in _domain_id integer,
  in _user_id   integer,
  in _folder_id integer)
{
  return coalesce ((select 1 from OMAIL.WA.FOLDERS where DOMAIN_ID = _domain_id and USER_ID = _user_id and FOLDER_ID = _folder_id), 0);
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.folder_name_exists (
  in _domain_id integer,
  in _user_id   integer,
  in _parent_id   integer,
  in _folder_name varchar,
  in _folder_id   integer := 0)
{
  declare retValue integer;

  retValue := coalesce ((select FOLDER_ID from OMAIL.WA.FOLDERS where DOMAIN_ID = _domain_id and USER_ID = _user_id and PARENT_ID = _parent_id and NAME = _folder_name), 0);
  if (_folder_id = 0)
    return retValue;

  if (retValue = 0)
    return retValue;

  if (retValue <> _folder_id)
    return 1;

  return 0;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.folder_isTrash (
  in  _domain_id integer,
  in  _user_id   integer,
  in  _folder_id integer)
{
  if (_folder_id = 110)
    return 1;

  for (select PARENT_ID, F_TYPE from OMAIL.WA.FOLDERS where DOMAIN_ID = _domain_id and USER_ID = _user_id and FOLDER_ID = _folder_id) do
  {
    if (PARENT_ID = 110)
      return 1;

    if (F_TYPE = 'TRASH')
      return 1;

    if (PARENT_ID)
      return OMAIL.WA.folder_isTrash(_domain_id, _user_id, PARENT_ID);
  }
  return 0;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.folder_isSpam (
  in  _domain_id integer,
  in  _user_id   integer,
  in  _folder_id integer)
{
  if (_folder_id = 125)
    return 1;

  for (select PARENT_ID, F_TYPE from OMAIL.WA.FOLDERS where DOMAIN_ID = _domain_id and USER_ID = _user_id and FOLDER_ID = _folder_id) do
  {
    if (PARENT_ID = 125)
      return 1;

    if (F_TYPE = 'SPAM')
      return 1;

    if (PARENT_ID)
      return OMAIL.WA.folder_isSpam(_domain_id, _user_id, PARENT_ID);
  }
  return 0;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.folder_isErasable (
  in  _domain_id integer,
  in  _user_id   integer,
  in  _folder_id integer)
{
  if (OMAIL.WA.folder_isTrash(_domain_id, _user_id, _folder_id))
    return 1;

  if (OMAIL.WA.folder_isSpam(_domain_id, _user_id, _folder_id))
    return 1;

  return 0;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.folder_isSmart (
  in  _domain_id integer,
  in  _user_id   integer,
  in  _folder_id integer)
{
  if ((select SMART_FLAG from OMAIL.WA.FOLDERS where DOMAIN_ID = _domain_id and USER_ID = _user_id and FOLDER_ID = _folder_id) = 'S')
    return 1;

  return 0;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.folder_isSystem(
  in  _domain_id integer,
  in  _user_id   integer,
  in  _folder_id integer)
{
  if ((select SYSTEM_FLAG from OMAIL.WA.FOLDERS where DOMAIN_ID = _domain_id and USER_ID = _user_id and FOLDER_ID = _folder_id) = 'S')
    return 1;

  return 0;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.folder_trash (
  in  _domain_id integer,
  in  _user_id   integer,
  in  _folder_id integer)
{
  declare _source integer;

  _source := coalesce((select F_SOURCE from OMAIL.WA.FOLDERS where DOMAIN_ID = _domain_id and USER_ID = _user_id and FOLDER_ID = _folder_id), 0);
  for (select FOLDER_ID from OMAIL.WA.FOLDERS where DOMAIN_ID = _domain_id and USER_ID = _user_id and coalesce (F_SOURCE, 0) = _source and F_TYPE = 'TRASH') do
    return FOLDER_ID;

  return 110;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.folder_type (
  in  _domain_id integer,
  in  _user_id   integer,
  in  _folder_id integer)
{
  declare _parent_id integer;

  if (_folder_id in (100, 110, 125))
    return 'R';

  if (_folder_id in (120, 130))
    return 'S';

  if (OMAIL.WA.folder_isSmart (_domain_id, _user_id, _folder_id))
    return 'R';

  for (select F_TYPE, PARENT_ID from OMAIL.WA.FOLDERS where DOMAIN_ID = _domain_id and USER_ID = _user_id and FOLDER_ID = _folder_id) do
  {
    if (F_TYPE in ('INBOX', 'TRASH', 'SPAM'))
      return 'R';

    if (F_TYPE in ('SENT', 'DRAFTS'))
      return 'S';

    if (PARENT_ID > 0)
      return OMAIL.WA.folder_type (_domain_id, _user_id, PARENT_ID);
  }
  return 'R';
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.folder_check_parent (
  in _domain_id integer,
  in _user_id   integer,
  in _folder_id integer,
  in _parent_id integer)
{
  declare _parent_loc integer;
  WHENEVER NOT FOUND GOTO ERR_EXIT;

  if (_parent_id is null)
    return 0;

  select PARENT_ID
    INTO _parent_loc
    from OMAIL.WA.FOLDERS
   where DOMAIN_ID = _domain_id
     and USER_ID = _user_id
     and FOLDER_ID = _parent_id;

  if ((_parent_loc = _folder_id) or (_parent_id = _folder_id))
    return 1401;

  if (is_empty_or_null(_parent_loc))
    return 0;

  return OMAIL.WA.folder_check_parent (_domain_id, _user_id, _folder_id, _parent_loc);

ERR_EXIT:
  return 1402;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.imap_folder_info (
  in _domain_id integer,
  in _user_id integer,
  in _folder_id integer,
  inout _source_start_id integer,
  inout _source_id integer,
  inout _path varchar)
{
  declare _retValue integer;

  _source_id := 0;
  _path := '';
  _source_start_id := 0;
  for (select DATA, F_SOURCE from OMAIL.WA.FOLDERS where DOMAIN_ID = _domain_id and USER_ID = _user_id and FOLDER_ID = _folder_id and F_SOURCE <> 0) do
  {
    _retValue := 1;
    _source_id := F_SOURCE;
    _path := DATA;
    _source_start_id := (select FOLDER_ID from OMAIL.WA.FOLDERS where DOMAIN_ID = _domain_id and USER_ID = _user_id and PARENT_ID = 0 and F_SOURCE = _source_id);
  }
  return _retValue;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.imap_folder_erase (
  in _domain_id integer,
  in _user_id integer,
  in _folder_id integer)
{
  declare _start_id, _source, _folder any;
  declare _server, _user, _password, _buffer, _retCode any;
  declare exit handler for SQLSTATE '*' {return 0;};

  if (not OMAIL.WA.imap_folder_info (_domain_id, _user_id, _folder_id, _start_id, _source, _folder))
    return 1;

  if (not OMAIL.WA.external_account_info (_domain_id, _user_id, _source, _server, _user, _password))
    return 0;

  _buffer := 10000000;
  _retCode := imap_get (_server, _user, _password, _buffer, 'delete', _folder);

  return 1;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.imap_folder_move (
  in _domain_id integer,
  in _user_id integer,
  in _folder_id integer,
  in _parent_id integer)
{
  declare _start_id, _source, _folder, _newFolder any;
  declare _start_id2, _source2, _folder2 any; -- parent
  declare _server, _user, _password, _buffer, _retCode any;
  declare exit handler for SQLSTATE '*' {return 0;};

  if (not OMAIL.WA.imap_folder_info (_domain_id, _user_id, _folder_id, _start_id, _source, _folder))
    return 1;

  if (not OMAIL.WA.imap_folder_info (_domain_id, _user_id, _parent_id, _start_id2, _source2, _folder2))
    return 0;

  if (_source <> _source2)
    return 0;

  if (not OMAIL.WA.external_account_info (_domain_id, _user_id, _source, _server, _user, _password))
    return 0;

  _newFolder := _folder2 || '.' || OMAIL.WA.folder_name (_domain_id, _user_id, _folder_id);
  _buffer := 10000000;
  _retCode := imap_get (_server, _user, _password, _buffer, 'rename', '', vector (_folder, _newFolder));

  return 1;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.imap_folder_rename (
  in _domain_id integer,
  in _user_id integer,
  in _folder_id integer,
  in _name varchar)
{
  declare _start_id, _source, _folder, _newFolder any;
  declare _server, _user, _password, _buffer, _retCode any;
  declare exit handler for SQLSTATE '*' {return 0;};

  if (not OMAIL.WA.imap_folder_info (_domain_id, _user_id, _folder_id, _start_id, _source, _folder))
    return 1;

  if (not OMAIL.WA.external_account_info (_domain_id, _user_id, _source, _server, _user, _password))
    return 0;

  _newFolder := _folder || '.' || _name;
  _buffer := 10000000;
  _retCode := imap_get (_server, _user, _password, _buffer, 'rename', '', vector (_folder, _newFolder));

  return 1;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_check_interval(
  in _value  any,
  in _lt integer,
  in _gt integer)
{
  declare exit handler for SQLSTATE '*' {return 0;};

  _value := cast (_value as integer);
  if ((_value >= _lt) and (_value <= _gt))
    return 1;
  return 0;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_construct_mail (
  inout path any,
  inout lines any,
  inout params any)
{
  -- www procedure

  declare _sql_result1,_sql_result2,_xslt_url,_rs,_boundary any;
  declare _user_id,_msg_id integer;

  _rs := '';
  _user_id := 1001;
  _msg_id  := 1009;

  _xslt_url := OMAIL.WA.omail_xslt_full('construct_mail.xsl');

  _sql_result1 := sprintf ('%s',OMAIL.WA.omail_open_message(_user_id, vector ('msg_id', _msg_id), 1, 1));
  _sql_result2 := sprintf ('%s',OMAIL.WA.omail_select_attachment(_user_id,_msg_id,1));
  _boundary := sprintf ('------_NextPart_%s', md5(cast (now() as varchar)));

  -- XML structure-------------------------------------------------------------------
  _rs := sprintf ('%s<message>', _rs);
  _rs := sprintf ('%s<boundary>%s</boundary>', _rs, _boundary);
  _rs := sprintf ('%s%s', _rs, _sql_result1);
  _rs := sprintf ('%s%s', _rs, _sql_result2);
  _rs := sprintf ('%s</message>', _rs);

  -- XSL Transformation--------------------------------------------------------------
  declare _view varchar;
  _view := get_keyword ('vv', params, 'h');
  OMAIL.WA.utl_myhttp (_view, _rs, _xslt_url, null, null, null);
  return;
}
;

-----------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_dav_api_params(
  inout userInfo any,
  out vspx_user varchar,
  out vspx_pwd varchar)
{
  declare vspx_uid integer;

  vspx_uid := get_keyword ('user_id', userInfo);
  vspx_user := coalesce((select U_NAME from WS.WS.SYS_DAV_USER where U_ID = vspx_uid), '');
  vspx_pwd := coalesce((select U_PWD from WS.WS.SYS_DAV_USER where U_ID = vspx_uid), '');
  if (vspx_pwd[0] = 0)
    vspx_pwd := pwd_magic_calc(vspx_user, vspx_pwd, 1);
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_delete_attachment(
  in  _domain_id integer,
  in  _user_id    integer,
  in  _msg_id     integer,
  in  _part_id    integer,
  out _error      integer)
{
  delete
     from OMAIL.WA.MSG_PARTS
    where DOMAIN_ID = _domain_id and USER_ID = _user_id and MSG_ID = _msg_id and PART_ID = _part_id;

   OMAIL.WA.omail_update_msg_attached(_domain_id,_user_id,_msg_id);
   _error := 0;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.domain_id(
  in _domain_name varchar)
{
  return (select WAI_ID from DB.DBA.WA_INSTANCE where WAI_NAME = _domain_name);
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.domain_id2 (
  in _user_id integer)
{
  return (select TOP 1 WAI_ID from DB.DBA.WA_INSTANCE, DB.DBA.WA_MEMBER where WAI_TYPE_NAME = 'oMail' and WAI_NAME = WAM_INST and WAM_MEMBER_TYPE = 1 and WAM_USER = _user_id);
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.domain_name(
  in _domain_id integer)
{
  return coalesce((select WAI_NAME from DB.DBA.WA_INSTANCE where WAI_ID = _domain_id), 'Mail Instance');
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.domain_description(
  in _domain_id integer)
{
  return coalesce((select coalesce(WAI_DESCRIPTION, WAI_NAME) from DB.DBA.WA_INSTANCE where WAI_ID = _domain_id), 'Mail Description');
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.domain_nntp_name (
  in domain_id integer)
{
  return sprintf ('ods.mail.%s.%s', OMAIL.WA.domain_owner_name (domain_id), OMAIL.WA.string2nntp (OMAIL.WA.domain_name (domain_id)));
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.domain_owner_id (
  inout _domain_id integer)
{
  return (select A.WAM_USER from WA_MEMBER A, WA_INSTANCE B where A.WAM_MEMBER_TYPE = 1 and A.WAM_INST = B.WAI_NAME and B.WAI_ID = _domain_id);
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.domain_owner_name (
  in domain_id integer)
{
  return (select U_NAME from WS.WS.SYS_DAV_USER where U_ID = OMAIL.WA.domain_owner_id (domain_id));
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.domain_sioc_url (
  in domain_id integer,
  in sid varchar := null,
  in realm varchar := null)
{
  declare S varchar;

  S := OMAIL.WA.iri_fix (SIOC..mail_iri (OMAIL.WA.domain_name (domain_id)));
  return OMAIL.WA.url_fix (S, sid, realm);
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.account_name (
  in account_id integer)
{
  return coalesce((select U_NAME from DB.DBA.SYS_USERS where U_ID = account_id), '');
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.account_password (
  in account_id integer)
{
  return coalesce ((select pwd_magic_calc(U_NAME, U_PWD, 1) from WS.WS.SYS_DAV_USER where U_ID = account_id), '');
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.account_fullName (
  in account_id integer)
{
  return coalesce ((select OMAIL.WA.user_name (U_NAME, U_FULL_NAME) from DB.DBA.SYS_USERS where U_ID = account_id), '');
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.account_mail(
  in account_id integer)
{
  return coalesce((select U_E_MAIL from DB.DBA.SYS_USERS where U_ID = account_id), '');
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.account_basicAuthorization (
  in account_id integer)
{
  declare account_name, account_password varchar;

  account_name := OMAIL.WA.account_name (account_id);
  account_password := OMAIL.WA.account_password (account_id);
  return sprintf ('Basic %s', encode_base64 (account_name || ':' || account_password));
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.account_sioc_url (
  in domain_id integer,
  in sid varchar := null,
  in realm varchar := null)
{
  declare S varchar;

  S := OMAIL.WA.iri_fix (SIOC..person_iri (SIOC..user_iri (OMAIL.WA.domain_owner_id (domain_id), null)));
  return OMAIL.WA.url_fix (S, sid, realm);
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.user_name (
  in u_name any,
  in u_full_name any) returns varchar
{
  if (not is_empty_or_null(trim(u_full_name)))
    return trim (u_full_name);
  return u_name;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.iri_fix (
  in S varchar)
{
  if (is_https_ctx ())
  {
    declare V any;

    V := rfc1808_parse_uri (S);
    V [0] := 'https';
    V [1] := http_request_header (http_request_header(), 'Host', null, registry_get ('URIQADefaultHost'));
    S := DB.DBA.vspx_uri_compose (V);
  }
  return S;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.url_fix (
  in S varchar,
  in sid varchar := null,
  in realm varchar := null)
{
  declare T varchar;

  T := '?';
  if (not is_empty_or_null (sid))
  {
    S := S || T || 'sid=' || sid;
    T := '&';
  }
  if (not is_empty_or_null (realm))
  {
    S := S || T || 'realm=' || realm;
  }
  return S;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_delete_user_data(
 in _domain_id integer,
 in _user_id integer)
{
  delete from OMAIL.WA.MSG_PARTS        where DOMAIN_ID = _domain_id and USER_ID = _user_id;
  delete from OMAIL.WA.MESSAGES         where DOMAIN_ID = _domain_id and USER_ID = _user_id;
  delete from OMAIL.WA.EXTERNAL_ACCOUNT where EA_DOMAIN_ID = _domain_id and EA_USER_ID = _user_id;

  for (select FOLDER_ID from OMAIL.WA.FOLDERS where DOMAIN_ID = _domain_id and USER_ID = _user_id and PARENT_ID = 0) do
    OMAIL.WA.folder_erase (_domain_id, _user_id, FOLDER_ID, 0);

  delete from OMAIL.WA.SETTINGS         where DOMAIN_ID = _domain_id and USER_ID = _user_id;

  if (_domain_id <> 1)
    OMAIL.WA.nntp_update (_domain_id, 1, 0);
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_dload(
  inout path any,
  inout lines any,
  inout params any)
{
  -- www procedure

  declare _domain_id,_user_id integer;
  declare _mime_type,_pnames,_fname,_aparams,_encoding varchar;
  declare _tdata,_bdata,_params,_user_info any;

  _user_info := get_keyword('user_info',params);

  -- TEMP constants -----------------------------
  _user_id   := get_keyword('user_id',_user_info);
  _domain_id := 1;

  WHENEVER NOT FOUND GOTO _NO_ATT;

  -- Set Params --------------------------------------------------------------------
  _pnames := 'msg_id,part_id,download,gzip';
  _params := OMAIL.WA.omail_str2params(_pnames,get_keyword('dp',params,'0,0,0,0'),',');

  select blob_to_string(TDATA),blob_to_string(BDATA),MIME_TYPE,FNAME,APARAMS
    INTO _tdata,_bdata,_mime_type,_fname,_aparams
    from OMAIL.WA.MSG_PARTS A,
         OMAIL.WA.RES_MIME_TYPES T
   where A.TYPE_ID   = T.ID
     and A.DOMAIN_ID = _domain_id
     and A.USER_ID   = _user_id
     and A.MSG_ID    = OMAIL.WA.omail_getp('msg_id',_params)
     and A.PART_ID   = OMAIL.WA.omail_getp('part_id',_params);

  _bdata := either(isnull(_bdata),_tdata,_bdata);
  _fname := either(isnull(_fname),'no.name',_fname);

  _encoding := OMAIL.WA.omail_get_encoding(_aparams);

  -- Decoded data -------------------------------------------------------------
  if ((_encoding = 'quoted-printable') or (strstr(_tdata,'=3D')))
  {
    _bdata := replace(_bdata,'\r\n','\n');
    _bdata := replace(_bdata,'=\n','');
    _bdata := split_and_decode(_bdata,0,'=');
  }

  -- Download or View ---------------------------------------------------------
  if (OMAIL.WA.omail_getp('download',_params) = 1)
    _mime_type := 'application/octet-stream';

  -- GZ compress file ---------------------------------------------------------
  if (OMAIL.WA.omail_getp('gzip',_params) = 1) {
    _bdata := gz_compress(_bdata);
    _mime_type := 'application/x-gzip-compressed';
    _mime_type := 'application/octet-stream';
  };

  -- Print output -------------------------------------------------------------
  http_rewrite();
  http_request_status ('HTTP/1.1 200 OK');
  http_header (sprintf ('Content-type: %s\r\nContent-Disposition: inline; filename="%s"\r\n', _mime_type,_fname));

  http(_bdata);
  signal('90005','Make download');
  return;

_NO_ATT:
  http('No attachment found');
  return;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_err(
  inout path any,
  inout lines any,
  inout params any)
{
  declare _sid, _realm, _rs varchar;
  declare _page_params, _user_info any;

  _sid       := get_keyword('sid',params,'');
  _realm     := get_keyword('realm',params,'');
  _user_info := get_keyword('user_info',params);

  -- Page Params---------------------------------------------------------------------
  _page_params := vector(0,0,0,0);

  aset(_page_params,0,vector('sid',_sid));
  aset(_page_params,1,vector('realm',_realm));
  aset(_page_params,2,vector('user_info',OMAIL.WA.array2xml(_user_info)));

  -- XML structure-------------------------------------------------------------
  _rs := '';
  _rs := sprintf('%s%s', _rs, OMAIL.WA.omail_page_params(_page_params));
  _rs := sprintf('%s<msg><![CDATA[%s]]></msg>', _rs, get_keyword('msg', params, ''));
  _rs := sprintf('%s<p>%s</p>', _rs, get_keyword('p', params, ''));
  _rs := sprintf('%s<error>%s</error>', _rs, get_keyword('err', params, '0'));
  _rs := sprintf('%s%s', _rs, blob_to_string(xml_uri_get(OMAIL.WA.omail_get_xslt(), 'errors.xml')));

  return _rs;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_fix_some_bugs(
  inout _body varchar)
{
  -- fix explorer bug
  _body := replace(_body,'<TBODY>','');
  _body := replace(_body,'</TBODY>','');

  -- fix tree_doc() bug
  _body := replace(_body,'<html>','');
  _body := replace(_body,'</html>','');

  -- fix xslt() bug
  _body := replace(_body,'<DIV','<DIVA');
  _body := replace(_body,'</DIV>','</DIVA>');
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_folders(
  inout path any,
  inout lines any,
  inout params any)
{
  -- www procedure
  declare _rs, _sid, _realm, _sql_result1, _faction varchar;
  declare _user_info, _page_params, _pnames, _params any;
  declare _user_id, _error, _domain_id integer;
  declare _folder_id, _parent_id, _folder_name, _systemFlag, _smartFlag any;

  _sid       := get_keyword('sid',params,'');
  _realm     := get_keyword('realm',params,'');
  _user_info := get_keyword('user_info',params);

  -- TEMP constants -----------------------------
  _user_id   := get_keyword('user_id',_user_info);
  _domain_id := 1;

  -- Set constants  -------------------------------------------------------------
  _page_params := vector(0,0,0,0,0,0,0,0,0,0,0,0);

  _pnames := 'folder_id,faction';
  _params := OMAIL.WA.omail_str2params (_pnames, get_keyword ('fp', params, '0'), ',');

  _sql_result1 := '';
  -- Form Action---------------------------------------------------------------
  if (get_keyword ('fa_save.x',params,'') <> '')
  {
    -- > save folder
    declare folderData, data any;

    _folder_id := cast (get_keyword ('folder_id', params, 0) as integer);
    _systemFlag := get_keyword ('systemFlag', params, 'N');
    _smartFlag := get_keyword ('smartFlag', params, 'N');
    _parent_id := cast (get_keyword ('parent_id', params, 0) as integer);
    _folder_name := get_keyword ('name', params, '');

    data := null;
    if (_smartFlag = 'S')
    {
      data := vector ();
      data := vector_concat (data, vector ('q_from', get_keyword ('q_from', params,'')));
      data := vector_concat (data, vector ('q_to', get_keyword ('q_to', params, '')));
      data := vector_concat (data, vector ('q_subject', get_keyword ('q_subject', params, '')));
      data := vector_concat (data, vector ('q_body', get_keyword ('q_body', params, '')));
      data := vector_concat (data, vector ('q_tags', get_keyword ('q_tags', params, '')));
      data := vector_concat (data, vector ('q_fid', get_keyword ('q_fid', params,'')));
      data := vector_concat (data, vector ('q_attach', get_keyword ('q_attach', params,'')));
      data := vector_concat (data, vector ('q_read', get_keyword ('q_read', params,'')));
      data := vector_concat (data, vector ('q_after', get_keyword ('q_after', params, '')));
      data := vector_concat (data, vector ('q_before', get_keyword ('q_before', params, '')));
    }
    folderData := vector ('folder_id', _folder_id,
                          'parent_id', _parent_id,
                          'systemFlag', _systemFlag,
                          'smartFlag', _smartFlag,
                          'name', _folder_name,
                          'data', data
                         );

    if (_folder_id = 0)
    {
      OMAIL.WA.folder_create (_domain_id, _user_id, folderData, _error);
    } else {
      OMAIL.WA.folder_edit (_domain_id, _user_id, _folder_id, 0, folderData, _error);
    }
    if (_error = 0)
    {
      OMAIL.WA.utl_redirect (sprintf ('folders.vsp?sid=%s&realm=%s', _sid, _realm));
    } else {
      OMAIL.WA.utl_redirect(sprintf('err.vsp?sid=%s&realm=%s&err=%d',_sid,_realm,_error));
    }
    return;
  }
  else if (get_keyword ('fa_cancel.x',params,'') <> '')
  {
    OMAIL.WA.utl_redirect (sprintf ('folders.vsp?sid=%s&realm=%s', _sid, _realm));
    return;
  }

  _folder_id := cast (get_keyword ('folder_id', _params, '0') as integer);
  _faction := get_keyword ('faction', _params, '');
  if ((_faction = -1) or (_faction = -2))
  {
    -- create normal and smart folders
    _sql_result1 := OMAIL.WA.folder_list (_domain_id, _user_id, _faction);
  }
  else if (_faction = 1)
  {
    -- edit folder
    _sql_result1 := OMAIL.WA.folder_list (_domain_id, _user_id, _folder_id);
}
  else if ((_faction = 2) or (_faction = 3))
{
    -- empty and delete folder
    OMAIL.WA.folder_edit (_domain_id, _user_id, _folder_id, _faction-1, null, _error);
}
  else if (get_keyword ('folder_id', params, '') <> '')
{
    _sql_result1 := _sql_result1 || sprintf ('<object id="%s" systemFlag="%s" smartFlag="%s">', get_keyword ('folder_id', params), get_keyword ('systemFlag', _params, 'N'), get_keyword ('smartFlag', params, 'N'));
    _sql_result1 := _sql_result1 || sprintf ('<name>%V</name>', get_keyword ('name', params, ''));
    _sql_result1 := _sql_result1 || sprintf ('<parent_id>%s</parent_id>', get_keyword ('parent_id', params, ''));
    if (get_keyword ('smartFlag', params, 'N') = 'S')
  {
      _sql_result1 := _sql_result1 || '<query>';
      _sql_result1 := _sql_result1 || sprintf ('<q_from><![CDATA[%s]]></q_from>', get_keyword ('q_from', params, ''));
      _sql_result1 := _sql_result1 || sprintf ('<q_to><![CDATA[%s]]></q_to>', get_keyword ('q_to', params, ''));
      _sql_result1 := _sql_result1 || sprintf ('<q_subject><![CDATA[%s]]></q_subject>', get_keyword ('q_subject', params, ''));
      _sql_result1 := _sql_result1 || sprintf ('<q_body><![CDATA[%s]]></q_body>', get_keyword ('q_body', params, ''));
      _sql_result1 := _sql_result1 || sprintf ('<q_tags><![CDATA[%s]]></q_tags>', get_keyword ('q_tags', params, ''));
      _sql_result1 := _sql_result1 || sprintf ('<q_fid>%s</q_fid>', get_keyword ('q_fid', params, ''));
      _sql_result1 := _sql_result1 || sprintf ('<q_attach>%s</q_attach>', get_keyword ('q_attach', params, ''));
      _sql_result1 := _sql_result1 || sprintf ('<q_read>%s</q_read>', get_keyword ('q_read', params, ''));
      _sql_result1 := _sql_result1 || sprintf ('<q_after>%s</q_after>', get_keyword ('q_after', params, ''));
      _sql_result1 := _sql_result1 || sprintf ('<q_before>%s</q_before>', get_keyword ('q_before', params, ''));
      _sql_result1 := _sql_result1 || '</query>';
    }
    _sql_result1 := _sql_result1 || '</object>';
  }

  -- Page Params---------------------------------------------------------------
  aset (_page_params,0,vector ('sid', _sid));
  aset (_page_params,1,vector ('realm', _realm));
  aset (_page_params,2,vector ('user_info', OMAIL.WA.array2xml(_user_info)));

  -- XML structure-------------------------------------------------------------
  _rs := OMAIL.WA.omail_page_params(_page_params) ||
         _sql_result1 ||
         OMAIL.WA.folders_list (_domain_id, _user_id);
  return _rs;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_action (
  inout path any,
  inout lines any,
  inout params any)
{
  -- www procedure

  declare id, _domain_id, _account_id integer;
  declare sid, realm, action, subAction varchar;
  declare _user_info, returnData any;

  sid := get_keyword ('sid', params, '');
  realm := get_keyword ('realm', params, '');

  id := cast (get_keyword ('id', params, '0') as integer);
  action := get_keyword ('a', params, '');
  subAction := get_keyword ('sa', params, '');

  _user_info := get_keyword ('user_info', params, vector ());
  _domain_id  := cast (get_keyword ('domain_id', _user_info, '0') as integer);
  _account_id := cast (get_keyword ('user_id', _user_info, '0') as integer);

  if (action = 'search')
  {
    returnData := vector ();
    if (subAction = 'metas')
    {
      declare predicateMetas, compareMetas, actionMetas, folders any;

      OMAIL.WA.dc_predicateMetas (predicateMetas);
      OMAIL.WA.dc_compareMetas (compareMetas);
      OMAIL.WA.dc_actionMetas (actionMetas);
      folders := OMAIL.WA.folder_list (1, _account_id, null, 'N');
      returnData := vector (predicateMetas, compareMetas, actionMetas, folders);
    }
    http_rewrite ();
    http_header ('Content-Type: text/plain\r\n');
    http (OMAIL.WA.obj2json (returnData, 5));
  }
  else if (action = 'about')
  {
    http_rewrite ();
    http_header ('Content-Type: text/plain\r\n');
    http (         '<div style="padding: 1em;">');
    http (         '<table style="width: 100%;">');
    http (         '  <tr>');
    http (         '    <td align="right" width="50%">');
    http (         '      <b>Server Version:</b>');
    http (         '    </td>');
    http (         '    <td>');
    http (sprintf ('      %s', sys_stat('st_dbms_ver')));
    http (         '    </td>');
    http (         '  </tr>');
    http (         '  <tr>');
    http (         '    <td align="right">');
    http (         '      <b>Server Build Date:</b>');
    http (         '    </td>');
    http (         '    <td>');
    http (sprintf ('      %s', sys_stat('st_build_date')));
    http (         '  </tr>');
    http (         '  <tr><td align="center" colspan="2"><hr /><td></tr>');
    http (         '  <tr>');
    http (         '    <td align="right">');
    http (         '      <b>ODS Webmail Version:</b>');
    http (         '    </td>');
    http (         '    <td>');
    http (sprintf ('      %s', registry_get('_oMail_version_')));
    http (         '    </td>');
    http (         '  </tr>');
    http (         '  <tr>');
    http (         '    <td align="right">');
    http (         '     <b>ODS Webmail Build Date:</b>');
    http (         '    </td>');
    http (         '    <td>');
    http (sprintf ('     %s', registry_get('_oMail_build_')));
    http (         '    </td>');
    http (         '  </tr>');
    http (         '  <tr><td align="center" colspan="2"><hr /><td></tr>');
    http (         '  <tr>');
    http (         '    <td align="center" colspan="2">');
    http (         '      <input type="button" value="OK" onclick="javascript: aboutDialog.hide(); return false;" />');
    http (         '    <td>');
    http (         '  </tr>');
    http (         '</table>');
    http (         '</div>');
  }
  signal('90005', 'AJAX Call');
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_filters (
  inout path any,
  inout lines any,
  inout params any)
{
  -- www procedure

  declare N, C, A, seqNo integer;
  declare _user_id, _domain_id integer;
  declare _rs, _sid, _realm, _node, _sql_result varchar;
  declare _page_params, _user_info any;
  declare _folder_id, _filter_id, _filter_name, _filter_active, _filter_mode, _filter_criteria, _filter_actions any;
  declare fField, fCriteria, fValue, fAction, fSuffix any;

  declare exit handler for SQLSTATE '*'
  {
    OMAIL.WA.utl_redirect (sprintf ('err.vsp?sid=%s&realm=%s&err=%s&msg=%U',_sid, _realm, 'TEST', OMAIL.WA.test_clear (__SQL_MESSAGE)));
    return;
  };

  _sid       := get_keyword ('sid', params, '');
  _realm     := get_keyword ('realm', params, '');
  _user_info := get_keyword ('user_info', params);

  -- TEMP constants -----------------------------
  _user_id   := get_keyword ('user_id',_user_info);
  _domain_id := 1;
  _filter_id := cast (get_keyword ('filter_id', params) as integer);

  if (get_keyword ('fa_save.x', params, '') <> '')
  {
    _filter_name := get_keyword ('filter_name', params);
    _filter_active := cast (get_keyword ('filter_active', params, 0) as integer);
    _filter_mode := cast (get_keyword ('filter_mode', params, 0) as integer);
    C := 0;
    A := 0;
    _filter_criteria := OMAIL.WA.dc_xml ('criteria');
    _filter_actions := OMAIL.WA.dc_xml ('actions');
    for (N := 0; N < length (params); N := N + 2)
    {
      if (params[N] like 'search_fld_1_%')
      {
        fField := params[N+1];
        fSuffix := replace (params [N], 'search_fld_1_', '');
        fCriteria := get_keyword ('search_fld_2_' || fSuffix, params);
        fValue := get_keyword ('search_fld_3_' || fSuffix, params);
        OMAIL.WA.dc_set_criteria (_filter_criteria, cast (C as varchar), fField, fCriteria, fValue);
        C := C + 1;
      }
      else if (params[N] like 'action_fld_1_%')
      {
        fAction := params[N+1];
        fSuffix := replace (params [N], 'action_fld_1_', '');
        fValue := get_keyword ('action_fld_2_' || fSuffix, params);
        OMAIL.WA.dc_set_action (_filter_actions, cast (A as varchar), fAction, fValue);
        A := A + 1;
      }
    }
    if ((A = 0) or (C = 0))
      signal ('TEST', 'Filter must have at least one criteria and one action!<>');
    OMAIL.WA.filter_save (_user_id, _filter_id, _filter_name, _filter_active, _filter_mode, _filter_criteria, _filter_actions);
    _filter_id := 0;
  }
  else if (get_keyword ('fa_delete.x', params,'') <> '')
  {
    for (N := 0; N < length (params); N := N + 2)
    {
      if (params[N] = 'cb_item')
        OMAIL.WA.filter_delete (_user_id, cast (params[N+1] as integer));
      }
    }
  else if (get_keyword ('fa_run.x', params,'') <> '')
  {
    declare _filter_ids any;

    _filter_ids := vector ();
    for (N := 0; N < length (params); N := N + 2)
    {
      if (params[N] = 'cb_item')
        _filter_ids := vector_concat (_filter_ids, vector (cast (params[N+1] as integer)));
      }
    _folder_id := cast (get_keyword ('folder_id', params) as integer);
    OMAIL.WA.filter_run (_domain_id, _user_id, _folder_id, _filter_ids);
  }
  else if (get_keyword ('fa_cancel.x', params,'') <> '')
  {
    _filter_id := 0;
  }

  -- Set constants  -------------------------------------------------------------
  _page_params := vector (0,0,0,0,0,0,0,0,0,0,0,0);

  -- Page Params---------------------------------------------------------------------
  aset (_page_params, 0, vector ('sid', _sid));
  aset (_page_params, 1, vector ('realm', _realm));
  aset (_page_params, 2, vector ('user_info', OMAIL.WA.array2xml (_user_info)));

  -- XML structure-------------------------------------------------------------------
  _rs := OMAIL.WA.omail_page_params (_page_params) ||
         OMAIL.WA.filter_list (_user_id, _filter_id) ||
         OMAIL.WA.folders_list (_domain_id, _user_id);
  return _rs;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.filter_list (
  in _domain_id integer,
  in _filter_id integer := 0)
{
  declare _rs varchar;

  _rs  := '';
  if (is_empty_or_null (_filter_id))
  { -- list
    _rs := '<filters>';
    for (select * from OMAIL.WA.FILTERS where F_DOMAIN_ID = _domain_id) do
    {
      _rs  := sprintf ('%s<filter type="list">',_rs);
      _rs  := sprintf ('%s<id>%d</id>', _rs, F_ID);
      _rs  := sprintf ('%s<name>%V</name>', _rs, F_NAME);
      _rs  := sprintf ('%s<mode>%d</mode>', _rs, F_MODE);
      _rs  := sprintf ('%s<active>%d</active>', _rs, F_ACTIVE);
      _rs  := sprintf ('%s</filter>',_rs);
    }
    _rs := _rs || '</filters>';
  }
  else if (_filter_id = -1)
  { -- new
    _rs  := sprintf ('%s<filter type="edit">',_rs);
    _rs  := sprintf ('%s<id>-1</id>', _rs);
    _rs  := sprintf ('%s<name />', _rs);
    _rs  := sprintf ('%s<mode>0</mode>', _rs);
    _rs  := sprintf ('%s<active>1</active>', _rs);
    _rs  := sprintf ('%s<criteria />', _rs);
    _rs  := sprintf ('%s<actions />', _rs);
    _rs  := sprintf ('%s</filter>',_rs);

  }
  else
  { -- edit
    for (select * from OMAIL.WA.FILTERS where F_DOMAIN_ID = _domain_id and F_ID = _filter_id) do
    {
      _rs  := sprintf ('%s<filter type="edit">',_rs);
      _rs  := sprintf ('%s<id>%d</id>', _rs, F_ID);
      _rs  := sprintf ('%s<name>%V</name>', _rs, F_NAME);
      _rs  := sprintf ('%s<mode>%d</mode>', _rs, F_MODE);
      _rs  := sprintf ('%s<active>%d</active>', _rs, F_ACTIVE);
      _rs  := sprintf ('%s%s', _rs, coalesce (F_CRITERIA, OMAIL.dc_xml ('criteria')));
      _rs  := sprintf ('%s%s', _rs, coalesce (F_ACTIONS, OMAIL.dc_xml ('actions')));
      _rs  := sprintf ('%s</filter>',_rs);
    }
  }
  return _rs;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.filter_save (
  in _domain_id integer,
  in _filter_id integer,
  in _filter_name varchar,
  in _filter_active integer,
  in _filter_mode integer,
  in _filter_criteria varchar := null,
  in _filter_Actions varchar := null)
{
  if (_filter_id = -1)
  { -- new
    insert into OMAIL.WA.FILTERS (F_DOMAIN_ID, F_NAME, F_ACTIVE, F_MODE, F_CRITERIA, F_ACTIONS)
      values (_domain_id, _filter_name, _filter_active, _filter_mode, _filter_criteria, _filter_actions);
  }
  else
  { -- edit
    update OMAIL.WA.FILTERS
       set F_NAME = _filter_name,
           F_ACTIVE = _filter_active,
           F_MODE = _filter_mode,
           F_CRITERIA = _filter_criteria,
           F_ACTIONS = _filter_Actions
     where F_ID = _filter_id;
  }
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.filter_delete (
  in _domain_id integer,
  in _filter_id integer)
{
  delete from OMAIL.WA.FILTERS where F_DOMAIN_ID = _domain_id and F_ID = _filter_id;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.filter_run (
  in _domain_id integer,
  in _user_id integer,
  in _folder_id integer,
  in _filter_ids any)
{
  declare _msg_id, _fields, _filter, tmp any;

  whenever not found goto _done;
  declare cr static cursor for select MSG_ID from OMAIL.WA.MESSAGES where DOMAIN_ID = _domain_id and USER_ID = _user_id and FOLDER_ID = _folder_id;

  open cr (exclusive, prefetch 1);

  while (1)
  {
    fetch cr into _msg_id;
    _fields := OMAIL.WA.omail_get_message (_domain_id, _user_id, _msg_id, 1);
    if (length (_fields))
    {
      for (select * from OMAIL.WA.FILTERS where F_DOMAIN_ID = _user_id and OMAIL.WA.vector_contains (_filter_ids, F_ID) and F_ACTIVE = 1) do
      {
        _filter := OMAIL.WA.filter_prepare (F_MODE, F_CRITERIA, F_ACTIONS);
        OMAIL.WA.filter_apply (_domain_id, _user_id, _filter, _fields);
      }
    }
  }
_done:;
  close cr;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.filter_run_message (
  in _domain_id integer,
  in _user_id integer,
  in _msg_id integer)
{
  declare _fields, _filter, tmp any;

  _fields := OMAIL.WA.omail_get_message (_domain_id, _user_id, _msg_id, 1);
  if (length (_fields))
  {
    for (select * from OMAIL.WA.FILTERS where F_DOMAIN_ID = _user_id and F_ACTIVE = 1) do
    {
      _filter := OMAIL.WA.filter_prepare (F_MODE, F_CRITERIA, F_ACTIONS);
      OMAIL.WA.filter_apply (_domain_id, _user_id, _filter, _fields);
    }
  }
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.filter_prepare (
  in _filter_mode any,
  in _filter_criteria any,
  in _filter_action any)
{
  declare I, N integer;
  declare _criteria, _action, _xml, _entry any;
  declare f0, f1, f2 any;

  _criteria := vector ();
  _xml := OMAIL.WA.dc_xml_doc (_filter_criteria, 'criteria');
  I := xpath_eval ('count(/criteria/entry)', _xml);
  for (N := 1; N <= I; N := N + 1)
  {
    _entry := xpath_eval ('/criteria/entry', _xml, N);
    f0 := cast (xpath_eval ('@field', _entry) as varchar);
    f1 := cast (xpath_eval ('@criteria', _entry) as varchar);
    f2 := cast (xpath_eval ('.', _entry) as varchar);
    _criteria := vector_concat (_criteria, vector (vector (f0, f1, f2)));
  }

  _action := vector ();
  _xml := OMAIL.WA.dc_xml_doc (_filter_action, 'actions');
  I := xpath_eval ('count(/actions/entry)', _xml);
  for (N := 1; N <= I; N := N + 1)
  {
    _entry := xpath_eval ('/actions/entry', _xml, N);
    f0 := cast (xpath_eval ('@action', _entry) as varchar);
    f1 := cast (xpath_eval ('.', _entry) as varchar);
    _action := vector_concat (_action, vector (vector (f0, f1)));
  }

  return vector (_filter_mode, _criteria, _action);
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.filter_apply (
  in _domain_id integer,
  in _user_id integer,
  in _filter any,
  in _fields any)
{
  declare N, M, L integer;
  declare criteria, actions any;
  declare predicate, predicateMetas, compare, compareMetas, action, actionMetas any;
  declare S, valueMatch, header, valueType, pattern, patternExpression, condition, conditionResult any;
  declare st, msg, meta, rows any;

  OMAIL.WA.dc_predicateMetas (predicateMetas);
  OMAIL.WA.dc_compareMetas (compareMetas);
  for (N := 0; N < length (_filter[1]); N := N + 1)
  {
    conditionResult := 0;
    criteria := _filter[1][N];
    condition := criteria[1];
    pattern := criteria[2];
    if (lcase (pattern) in ('%to%', '%from%', '%cc', '%return-path%', 'subject', 'body'))
    {
      pattern := lcase (trim (pattern, '%'));
      pattern := OMAIL.WA.filter_value (pattern, _fields);
    }

    predicate := get_keyword (criteria[0], predicateMetas);
    if (not isnull (predicate))
    {
      compare := get_keyword (condition, compareMetas);
      valueType := predicate[3];
      patternExpression := compare[3];
      valueMatch := OMAIL.WA.filter_value (criteria[0], _fields);
      if (not isnull (valueMatch))
      {
        if (valueType in ('varchar', 'datetime'))
        {
          valueMatch := sprintf ('\'%s\'', valueMatch);
          pattern := sprintf ('\'%s\'', pattern);
        }
        patternExpression := replace (patternExpression, '^{value}^', valueMatch);
        patternExpression := replace (patternExpression, '^{pattern}^', pattern);

        st := '00000';
        exec ('select ' || patternExpression, st, msg, vector (), 0, meta, rows);
        if (('00000' = st) and length (rows))
          conditionResult := rows[0][0];

        if ((conditionResult = 0) and (_filter[1] = 1))
          goto _end;

        if ((conditionResult = 1) and (_filter[1] = 0))
          goto _apply;
      }
    }
  }

_apply:;
  if (conditionResult = 1)
  {
    declare _msg_id integer;

    _msg_id := get_keyword ('msg_id', _fields);
    for (N := 0; N < length (_filter[2]); N := N + 1)
    {
      action := _filter[2][N];
      if (action[0] = 'move')
      {
        OMAIL.WA.message_move (_domain_id, _user_id, _msg_id, cast (action[1] as integer));
      }
      else if (action[0] = 'copy')
      {
        OMAIL.WA.message_copy (_domain_id, _user_id, _msg_id, cast (action[1] as integer));
      }
      else if (action[0] = 'delete')
      {
        OMAIL.WA.message_delete (_domain_id, _user_id, _msg_id);
      }
      else if (action[0] = 'forward')
      {
        OMAIL.WA.message_forward (_domain_id, _user_id, _msg_id, _fields, action[1]);
      }
      else if (action[0] = 'tag')
      {
        OMAIL.WA.message_tag (_domain_id, _user_id, _msg_id, action[1]);
      }
      else if (action[0] = 'mark')
      {
        OMAIL.WA.omail_mark_msg (_domain_id, _user_id, _msg_id, 1);
      }
      else if (action[0] = 'priority')
      {
        OMAIL.WA.message_priority (_domain_id, _user_id, _msg_id, cast (action[1] as integer));
      }
    }
  }

_end:;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.filter_value (
  in _valueType any,
  in _fields any)
{
  declare retValue, data any;

  if (_valueType = 'return-path')
  {
    data := split_and_decode(get_keyword ('header', _fields, ''), 1, '=_\n:');
    retValue := trim (replace (get_keyword_ucase ('RETURN-PATH', data), '\r', ''));
    retValue := OMAIL.WA.omail_address2xml ('to', retValue, 2);
  }
  else if (_valueType in ('to', 'from', 'cc'))
  {
    data := get_keyword ('address', _fields);
    retValue := OMAIL.WA.omail_address2str (_valueType, data, 2);
  }
  else if (_valueType in ('ssl', 'sslVerified', 'webID', 'webIDVerified'))
  {
    data := get_keyword ('options', _fields);
    retValue := null;
    if (not isnull (data))
      retValue := cast (xpath_eval ('//' || _valueType, xml_tree_doc (xml_tree (data))) as varchar);

    if (isnull (retValue))
    {
      if (_valueType in ('ssl', 'sslVerified', 'webIDVerified'))
      retValue := '0';

      if (_valueType in ('webID'))
        retValue := '';
    }
  }
  else
  {
    retValue := cast (get_keyword_ucase (_valueType, _fields) as varchar);
  }
  return retValue;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.message_move (
  in _domain_id integer,
  in _user_id integer,
  in _msg_id integer,
  in _folder_id any,
  in _full_mode integer := 1)
{
  declare _old_folder_id integer;

  _old_folder_id := (select FOLDER_ID from OMAIL.WA.MESSAGES where DOMAIN_ID = _domain_id and USER_ID = _user_id and MSG_ID = _msg_id);
  if (isnull (_old_folder_id) and (_old_folder_id = _folder_id))
    return;

  if (_full_mode and not OMAIL.WA.imap_message_move (_domain_id, _user_id, _msg_id, _folder_id))
    return;

    update OMAIL.WA.MESSAGES
       set FOLDER_ID = _folder_id
   where DOMAIN_ID = _domain_id
     and USER_ID = _user_id
     and MSG_ID = _msg_id;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.message_copy (
  in _domain_id integer,
  in _user_id integer,
  in _msg_id integer,
  in _folder_id integer := 130,
  in _check integer := 1)
{
  declare _old_folder_id, _new_msg_id, _new_freetext_id integer;

  _old_folder_id := (select FOLDER_ID from OMAIL.WA.MESSAGES where DOMAIN_ID = _domain_id and USER_ID = _user_id and MSG_ID = _msg_id);
  if ((_check = 0) or (not isnull (_old_folder_id) and (_old_folder_id <> _folder_id)))
  {
    _new_msg_id := sequence_next ('OMAIL.WA.omail_seq_eml_msg_id');
    _new_freetext_id := sequence_next ('OMAIL.WA.omail_seq_eml_freetext_id');
    insert into OMAIL.WA.MESSAGES (MSG_ID, FREETEXT_ID, FOLDER_ID, DOMAIN_ID, USER_ID, ADDRES_INFO, MSTATUS, ATTACHED, ADDRESS, RCV_DATE, SND_DATE, MHEADER, DSIZE, PRIORITY, SUBJECT, SRV_MSG_ID, REF_ID, PARENT_ID, UNIQ_MSG_ID, MSG_SOURCE)
      select _new_msg_id, _new_freetext_id, _folder_id, _domain_id, _user_id, ADDRES_INFO, MSTATUS, ATTACHED, ADDRESS, RCV_DATE, SND_DATE, MHEADER, DSIZE, PRIORITY, SUBJECT, SRV_MSG_ID, REF_ID, PARENT_ID, UNIQ_MSG_ID, MSG_SOURCE from OMAIL.WA.MESSAGES where DOMAIN_ID = _domain_id and USER_ID = _user_id and MSG_ID = _msg_id;

    for (select PART_ID as _part_id, TYPE_ID as _type_id, TDATA as _tdata, BDATA as _bdata, TAGS as _tags, DSIZE as _dsize, APARAMS as _aparams, PDEFAULT as _pdefault, FNAME as _fname from OMAIL.WA.MSG_PARTS where DOMAIN_ID = _domain_id and USER_ID = _user_id and MSG_ID = _msg_id) do
    {
      insert into  OMAIL.WA.MSG_PARTS (MSG_ID, FREETEXT_ID, DOMAIN_ID, USER_ID, PART_ID, TYPE_ID, TDATA, BDATA, TAGS, DSIZE, APARAMS, PDEFAULT, FNAME)
        values (_new_msg_id, _new_freetext_id, _domain_id, _user_id, _part_id, _type_id, _tdata, _bdata, _tags, _dsize, _aparams, _pdefault, _fname);
      _new_freetext_id := sequence_next ('OMAIL.WA.omail_seq_eml_freetext_id');
    }
    _msg_id := _new_msg_id;
  }
  return _msg_id;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.message_forward (
  in _domain_id integer,
  in _user_id integer,
  in _msg_id integer,
  in _fields any,
  in _new_to varchar)
{
  declare _new_msg_id integer;
  declare _addresses, _address varchar;
  declare _error, _message, _new_subject, _new_message, _new_from any;
  declare _request, _respond any;

  _new_msg_id := OMAIL.WA.message_copy (_domain_id, _user_id, _msg_id, 130, 0);

  _new_subject := 'Fw: ' || OMAIL.WA.omail_getp ('subject', _fields);

  _message := OMAIL.WA.omail_getp ('message', _fields);
  OMAIL.WA.omail_open_message_body_ind (_message);

  _new_message := '----- Original Message -----';
  _addresses := get_keyword ('address', _fields);
  _address := OMAIL.WA.omail_address2str ('from', _addresses, 3);
  if (not is_empty_or_null (_address))
    _new_message := _new_message || '\n> From: ' || _address;
  _address := OMAIL.WA.omail_address2str ('to', _addresses, 3);
  if (not is_empty_or_null (_address))
    _new_message := _new_message || '\n> To: ' || _address;
  _address := OMAIL.WA.omail_address2str ('cc', _addresses, 3);
  if (not is_empty_or_null (_address))
    _new_message := _new_message || '\n> CC: ' || _address;
  _new_message := _new_message || '\n> Subject: ' || get_keyword ('subject', _fields);
  _new_message := _new_message || '\n> Sent: ' || OMAIL.WA.dt_format (get_keyword  ('rcv_date', _fields), 'Y-M-D H:N:S');
  _new_message := _new_message || _message;

  _new_from := (select TOP 1 WAI_NAME from DB.DBA.WA_MEMBER, DB.DBA.WA_INSTANCE where WAM_INST = WAI_NAME and WAM_USER = _user_id and WAI_TYPE_NAME = 'oMail' order by WAI_ID);
  OMAIL.WA.omail_setparam ('message', _fields, _new_message);
  OMAIL.WA.omail_setparam ('subject', _fields, _new_subject);
  OMAIL.WA.omail_setparam ('from', _fields, _new_from);
  OMAIL.WA.omail_setparam ('to', _fields, _new_to);
  OMAIL.WA.omail_setparam ('cc', _fields, '');
  OMAIL.WA.omail_setparam ('bcc', _fields, '');
  OMAIL.WA.omail_setparam ('folder_id', _fields, 130);

  OMAIL.WA.omail_save_msg (_domain_id, _user_id, _fields, _new_msg_id, _error);
  commit work;
  _request := sprintf ('http://' || DB.DBA.http_get_host () || '/oMail/res/flush.vsp?did=%d&uid=%d&mid=%d', _domain_id, _user_id, _new_msg_id);
  http_get (_request, _respond);
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.message_delete (
  in    _domain_id  integer,
  in    _user_id     integer,
  in _msg_id integer,
  in _full_mode integer := 1)
{
  declare _folder_id integer;

  _folder_id := (select FOLDER_ID from OMAIL.WA.MESSAGES where DOMAIN_ID = _domain_id and USER_ID = _user_id and MSG_ID = _msg_id);

  -- check delete
  if (OMAIL.WA.folder_isErasable (_domain_id, _user_id, _folder_id))
    return OMAIL.WA.message_erase (_domain_id, _user_id, _msg_id, _full_mode);

  -- move
  return OMAIL.WA.message_move (_domain_id, _user_id, _msg_id, OMAIL.WA.folder_trash (_domain_id, _user_id, _folder_id), _full_mode);
  }
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.message_erase (
  in _domain_id integer,
  in _user_id integer,
  in _msg_id integer,
  in _full_mode integer := 1)
  {
  for (select MSG_ID from OMAIL.WA.MESSAGES where DOMAIN_ID = _domain_id and USER_ID = _user_id and PARENT_ID = _msg_id) do
    OMAIL.WA.message_erase (_domain_id,_user_id, MSG_ID, _full_mode);

  if (_full_mode and not OMAIL.WA.imap_message_erase (_domain_id, _user_id, _msg_id))
    return 0;

  delete
    from OMAIL.WA.MSG_PARTS
   where DOMAIN_ID = _domain_id and USER_ID = _user_id and MSG_ID = _msg_id;

  delete
    from OMAIL.WA.MESSAGES
   where DOMAIN_ID = _domain_id and USER_ID = _user_id and MSG_ID = _msg_id;

  commit work;

  return 1;
}
;

---------------------------------------------------------------------------------
--
create procedure OMAIL.WA.message_tag (
  in _domain_id integer,
  in _user_id integer,
  in _msg_id integer,
  in _tags varchar)
{
  declare _old_tags varchar;

  _old_tags := (select TAGS from OMAIL.WA.MSG_PARTS where DOMAIN_ID = _domain_id and USER_ID = _user_id and MSG_ID =_msg_id and PART_ID = 1);
  update OMAIL.WA.MSG_PARTS
     set TAGS = OMAIL.WA.tags_join (_tags, _old_tags)
   where DOMAIN_ID = _domain_id
     and USER_ID = _user_id
     and MSG_ID =_msg_id
     and PART_ID = 1;
}
;

---------------------------------------------------------------------------------
--
create procedure OMAIL.WA.message_priority (
  in _domain_id integer,
  in _user_id integer,
  in _msg_id integer,
  in _priority integer)
{
  update OMAIL.WA.MESSAGES
     set PRIORITY = _priority
   where DOMAIN_ID = _domain_id and USER_ID = _user_id and MSG_ID = _msg_id;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.message_folder (
  in _domain_id integer,
  in _user_id integer,
  in _msg_id integer)
{
  return (select FOLDER_ID from OMAIL.WA.MESSAGES where DOMAIN_ID = _domain_id and USER_ID = _user_id and MSG_ID = _msg_id);
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.messages_move (
  in _domain_id integer,
  in _user_id   integer,
  inout _params any)
{
  declare N, _folder_id integer;

  _folder_id  := cast (get_keyword ('fid', _params, '') as integer);
  for (N := 0; N < length (_params); N := N + 2)
  {
    if (_params[N] = 'ch_msg')
      OMAIL.WA.message_move (_domain_id, _user_id, cast (_params[N + 1] as integer), _folder_id);
  }
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.messages_delete (
  in _domain_id integer,
  in _user_id   integer,
  inout params  any)
{
  declare N integer;

  for (N := 0; N < length (params); N := N + 2)
  {
    if (params[N] = 'ch_msg')
      OMAIL.WA.message_delete (_domain_id, _user_id, cast (params[N + 1] as integer));
  }
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.messages_count (
  in  _domain_id integer,
  in  _user_id   integer,
  in  _folder_id integer,
  out _all_cnt   integer,
  out _new_cnt   integer,
  out _all_size  integer)
{
  select COUNT(*),
         SUM(either(MSTATUS,0,1)),
         SUM(DSIZE)
    INTO _all_cnt,
         _new_cnt,
         _all_size
    from OMAIL.WA.MESSAGES
   where PARENT_ID IS NULL
     and DOMAIN_ID = _domain_id
     and USER_ID   = _user_id
     and FOLDER_ID = _folder_id;

  _new_cnt  := either (isnull (_new_cnt), 0, _new_cnt);
  _all_size := either (isnull (_all_size), 0, _all_size);
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.message_folder (
  in _domain_id integer,
  in _user_id integer,
  in _msg_id integer)
{
  return (select FOLDER_ID from OMAIL.WA.MESSAGES where DOMAIN_ID = _domain_id and USER_ID = _user_id and MSG_ID = _msg_id);
}
;

-----------------------------------------------------------------------------------------
--
create procedure OMAIL.WA.imap_message_info (
  in _domain_id integer,
  in _user_id integer,
  in _msg_id integer,
  inout _folder_id integer,
  inout _source_id integer,
  inout _unique_id integer)
{
  declare _server, _password, _buffer, _folder, _retCode any;

  for (select FOLDER_ID, MSG_SOURCE, UNIQ_MSG_ID from OMAIL.WA.MESSAGES where DOMAIN_ID = _domain_id and USER_ID = _user_id and MSG_ID = _msg_id and MSG_SOURCE > 0) do
  {
    _folder_id := FOLDER_ID;
    _source_id := MSG_SOURCE;
    _unique_id := UNIQ_MSG_ID;

    return 1;
  }
  return 0;
}
;

-----------------------------------------------------------------------------------------
--
create procedure OMAIL.WA.imap_message_erase (
  in _domain_id integer,
  in _user_id integer,
  in _msg_id integer)
{
  declare _folder_id, _source_id, _unique_id integer;
  declare _server, _user, _password, _buffer, _folder, _retCode any;
  declare exit handler for SQLSTATE '*' {return 0;};

  if (not OMAIL.WA.imap_message_info (_domain_id, _user_id, _msg_id, _folder_id, _source_id, _unique_id))
    return 1;

  if (not OMAIL.WA.external_account_info (_domain_id, _user_id, _source_id, _server, _user, _password))
    return 0;

  _folder := (select DATA from OMAIL.WA.FOLDERS where DOMAIN_ID = _domain_id and USER_ID = _user_id and FOLDER_ID = _folder_id);
  if (isnull (_folder))
    return 0;

  _buffer := 10000000;
  _retCode := imap_get (_server, _user, _password, _buffer, 'message_delete', _folder, vector (cast (_unique_id as integer)));

  return 1;
    }
;

-----------------------------------------------------------------------------------------
--
create procedure OMAIL.WA.imap_message_move (
  in _domain_id integer,
  in _user_id integer,
  in _msg_id integer,
  in _move_id integer)
{
  declare _folder_id, _source_id, _unique_id integer;
  declare _server, _user, _password, _buffer, _folder, _move, _retCode any;
  declare exit handler for SQLSTATE '*' {return 0;};

  if (not OMAIL.WA.imap_message_info (_domain_id, _user_id, _msg_id, _folder_id, _source_id, _unique_id))
    return 1;

  if (not OMAIL.WA.external_account_info (_domain_id, _user_id, _source_id, _server, _user, _password))
    return 0;

  _folder := (select DATA from OMAIL.WA.FOLDERS where DOMAIN_ID = _domain_id and USER_ID = _user_id and FOLDER_ID = _folder_id);
  if (isnull (_folder))
    return 0;

  _move := (select DATA from OMAIL.WA.FOLDERS where DOMAIN_ID = _domain_id and USER_ID = _user_id and FOLDER_ID = _move_id and F_SOURCE = _source_id);
  if (isnull(_move))
    return 0;

  _buffer := 10000000;
  _retCode := imap_get (_server, _user, _password, _buffer, 'message_copy', _folder, vector (_move, cast (_unique_id as integer)));
  _retCode := imap_get (_server, _user, _password, _buffer, 'message_delete', _folder, vector (cast (_unique_id as integer)));

  return 1;
}
;-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_form_select(
  in aname     varchar,
  in avlabels  varchar,     -- 'val1 # lab1 # .............'
  in asepar    varchar,     --  #
  in aselected varchar)
{
  declare arr any;
  declare res varchar;
  declare len,ind integer;

  arr := split_and_decode(avlabels,0,concat('\0\0',asepar));
  len := length(arr);
  if (mod(len, 2) <> 0)
    signal('69000','ARRAY_NO_ASSOCIATIVE');
  res := '';
  for (ind := 0; ind < len; ind := ind + 2)
  { -- find how many element to remove
    if (aselected = aref(arr,ind))
    {
      res := sprintf('%s\n<option value="%s" selected="1">%s</option>',res,aref(arr,ind),aref(arr,ind+1));
    }
    else
    {
      res := sprintf('%s\n<option value="%s">%s</option>',res,aref(arr,ind),aref(arr,ind+1));
    }
  }
  return sprintf('<select name="%s">%s\n</select>',aname,res);
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_get_att_parts(
  in    _domain_id  integer,
  in    _user_id    integer,
  in    _msg_id     integer,
  inout _part_id    integer,
  inout _source     any,
  in    _level      integer)
{
  declare _body_parts any;
  declare _aparams,_encoding,_mime_type,_content_id,_att_fname,_body_src varchar;
  declare _body_beg,_body_end,_pdefault,_dsize,_type_id,_freetext_id integer;

  _body_parts  := mime_tree(_source);

  _freetext_id := sequence_next ('OMAIL.WA.omail_seq_eml_freetext_id');
  _aparams     := OMAIL.WA.array2xml(aref(_body_parts,0));
  _encoding    := get_keyword_ucase('Content-Transfer-Encoding',aref(_body_parts,0),'');
  _mime_type   := get_keyword_ucase('Content-Type',aref(_body_parts,0),'');
  _content_id  := get_keyword_ucase('Content-ID',aref(_body_parts,0),'');
  _att_fname   := get_keyword_ucase('filename',aref(_body_parts,0),'');
  _att_fname   := get_keyword_ucase('name',aref(_body_parts,0),'');
  _body_beg    := aref(aref(_body_parts,1),0);
  _body_end    := aref(aref(_body_parts,1),1);
  _body_src    := subseq (blob_to_string (_source), _body_beg, _body_end + 1);
  _pdefault    := 0;
  _part_id     := _part_id + 1;
  _dsize       := length(_body_src);
  _content_id  := replace(_content_id,'<','');
  _content_id  := replace(_content_id,'>','');

  _type_id := OMAIL.WA.res_get_mimetype_id(_mime_type);

  -- binary document
  if (_encoding = 'base64')
    _body_src := decode_base64(_body_src);

  insert into OMAIL.WA.MSG_PARTS(DOMAIN_ID,MSG_ID,USER_ID,PART_ID,TYPE_ID,CONTENT_ID,BDATA,DSIZE,APARAMS,PDEFAULT,FNAME,FREETEXT_ID)
    values (_domain_id,_msg_id,_user_id,_part_id,_type_id,_content_id,_body_src,_dsize,_aparams,_pdefault,_att_fname,_freetext_id);
  return;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_get_def_message(
  in  _domain_id  integer,
  in  _user_id    integer,
  in  _msg_id     integer,
  in  _atype_id   integer,
  out _part_id    integer)
{
  declare _rs,_name varchar;

  _rs := '';
  _part_id := 1;
  for (select PART_ID,TYPE_ID
         from OMAIL.WA.MSG_PARTS
        where DOMAIN_ID = _domain_id and USER_ID = _user_id and MSG_ID = _msg_id and PDEFAULT = 1)  do
  {
    _rs := sprintf('%s<mime_types>%d</mime_types>',_rs,TYPE_ID);
    if (cast(TYPE_ID as integer) = _atype_id)
      _part_id := PART_ID;
  };
  return _rs;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_get_encoding(
  in _params  any,
  in _element varchar := '')
{
  declare _aparams_xml,_encoding any;

  if (_element = '')
    _element := 'content-transfer-encoding';
  _aparams_xml := xml_tree_doc(xml_tree(_params,2));
  _encoding := (cast (xpath_eval ('//' || _element, _aparams_xml) as varchar));
  _encoding := either(isnull(_encoding),'',_encoding);

  return _encoding;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_get_message(
  in _domain_id integer,
  in _user_id   integer,
  in _msg_id    integer,
  in _part_id   integer)
{
  declare _fields, N any;
  declare _to, _cc, _bcc, _dcc, _body, _tags, _type_id, _aparams varchar;

  _fields := vector();
  for (select MSG_ID, FOLDER_ID, SRV_MSG_ID, REF_ID, MSTATUS, ATTACHED, ADDRESS, RCV_DATE, SND_DATE, MHEADER, DSIZE, PRIORITY, SUBJECT, ADDRES_INFO, PARENT_ID, M_OPTIONS, MSG_SOURCE, UNIQ_MSG_ID
         from OMAIL.WA.MESSAGES
        where DOMAIN_ID = _domain_id
          and USER_ID   = _user_id
          and MSG_ID    =_msg_id) do
  {
    _to  := OMAIL.WA.omail_address2str('to',  ADDRESS, 0);
    _cc  := OMAIL.WA.omail_address2str('cc',  ADDRESS, 0);
    _bcc := OMAIL.WA.omail_address2str('bcc', ADDRESS, 0);
    _dcc := OMAIL.WA.omail_address2str('dcc', ADDRESS, 0);
    PARENT_ID := coalesce (PARENT_ID,0);

    if (MSG_SOURCE > 0)
    {
      declare _size, _count integer;

      for (select DSIZE from OMAIL.WA.MSG_PARTS where DOMAIN_ID = _domain_id and USER_ID = _user_id and MSG_ID = _msg_id) do
      {
        _size := _size + DSIZE;
        _count := _count + 1;
      }
      if (_size = 0 and _count <= 1)
        OMAIL.WA.omail_receive_message_imap_body (_domain_id, _user_id, _msg_id, PARENT_ID, FOLDER_ID, MSG_SOURCE, UNIQ_MSG_ID);
    }
    for (select TYPE_ID, TDATA, APARAMS, TAGS
           from OMAIL.WA.MSG_PARTS
          where DOMAIN_ID = _domain_id
            and USER_ID   = _user_id
            and MSG_ID    = _msg_id
            and PART_ID   = _part_id) do
    {
      _body    := TDATA;
      _type_id := TYPE_ID;
      _aparams := APARAMS;
      _tags    := TAGS;
    }
    if (_part_id <> 1)
      _tags := OMAIL.WA.tags_select(_domain_id, _user_id, _msg_id);
    _fields := vector ('_res', 1,
                       'msg_id', MSG_ID,
                       'to', _to,
                       'cc', _cc,
                       'bcc', _bcc,
                       'dcc', _dcc,
                       'address', ADDRESS,
                       'subject', SUBJECT,
                       'tags', _tags,
                       'mt', _type_id,
                       'type_id', _type_id,
                       'priority', PRIORITY,
                       'message', cast (_body as varchar),
                       'folder_id', FOLDER_ID,
                       'mstatus', MSTATUS,
                       'attached', ATTACHED,
                       'rcv_date', RCV_DATE,
                       'dsize', DSIZE,
                       'aparams', _aparams,
                       'srv_msg_id', SRV_MSG_ID,
                       'ref_id', REF_ID,
                       'parent_id', PARENT_ID,
                       'header', MHEADER,
                       'options', M_OPTIONS);

    for (N := 0; N < length(_fields); N := N + 1)
      _fields[N] := coalesce(_fields[N], '');
  }
  return _fields;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_get_mime_handlers(
  in    _type_id integer,
  inout _data    varchar,
  in    _params  any,
  out   _rs      varchar)
{
  declare _out any;

  _rs := '';
  OMAIL.WA.utl_decode_qp(_data,OMAIL.WA.omail_get_encoding(_params,''));
  for (select PNAME from OMAIL.WA.MIME_HANDLERS where TYPE_ID = _type_id) do
  {
    call (PNAME)(_data, _out);
    _rs := sprintf('%s%s', _rs, _out);
  }
  if (length (_rs) > 0)
  {
    _rs := sprintf('<handlers>%s</handlers>',_rs);
    return 1;
  }
  return 0;

}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_get_mime_parts(
  in    _domain_id  integer,
  in    _user_id    integer,
  in    _msg_id     integer,
  in    _parent_id  integer,
  in    _folder_id  integer,
  inout _part_id    integer,
  inout _source     any,
  inout _mime_parts any,
  in    _level       integer)
{
  declare N,_body_beg,_body_end,_type_id,_pdefault,_dsize,_content_id,_att_fname,_freetext_id integer;
  declare _aparams,_encoding,_mime_type,_body,_dispos,_att_name varchar;

  for (N := 0; N < length (_mime_parts); N := N + 1)
  {
    if (isarray (aref(_mime_parts[N], 0)))
    {
      if (isarray (aref (_mime_parts[N], 2)))
      {
        OMAIL.WA.omail_get_mime_parts (_domain_id, _user_id, _msg_id, _parent_id, _folder_id, _part_id, _source, aref(_mime_parts[N],2), _level + 1);
      }
      else if (isarray(aref(aref(_mime_parts[N],1),2)))
      {
        _body_beg    := aref(aref(_mime_parts[N],1),0);
        _body_end    := aref(aref(_mime_parts[N],1),1);
        _body        := subseq (blob_to_string (_source), _body_beg, _body_end + 1);
        OMAIL.WA.omail_receive_message(_domain_id,_user_id,_msg_id,_body,null,null,_folder_id);
      }
      else
      {
        _freetext_id := sequence_next ('OMAIL.WA.omail_seq_eml_freetext_id');
        _aparams     := OMAIL.WA.array2xml(aref(_mime_parts[N],0));
        _encoding    := get_keyword_ucase('Content-Transfer-Encoding',aref(_mime_parts[N],0),'');
        _dispos      := get_keyword_ucase('Content-Disposition',aref(_mime_parts[N],0),'');
        _mime_type   := get_keyword_ucase('Content-Type',aref(_mime_parts[N],0),'');
        _body_beg    := aref(aref(_mime_parts[N],1),0);
        _body_end    := aref(aref(_mime_parts[N],1),1);
        _body        := subseq (blob_to_string (_source), _body_beg, _body_end + 1);
        _content_id  := get_keyword_ucase('Content-ID',aref(_mime_parts[N],0),'');
        _att_fname   := get_keyword_ucase('name',aref(_mime_parts[N],0),'');
        _att_name    := get_keyword_ucase('filename',aref(_mime_parts[N],0),'');
        _att_fname   := either(length(_att_fname),_att_fname,_att_name);
        _att_fname   := substring(_att_fname,1,100);

        _content_id  := replace(_content_id,'<','');
        _content_id  := replace(_content_id,'>','');
        _content_id  := substring(_content_id,1,100);

        _pdefault    := 0;
        _type_id     := OMAIL.WA.res_get_mimetype_id(_mime_type);
        if (_encoding = 'base64') {
          -- binary document
          _body   := decode_base64(_body);
        } else if (_dispos = 'inline' or _dispos = '') {
          -- text document
          _pdefault := 1;
        };
        _dsize  := length(_body);
        insert into OMAIL.WA.MSG_PARTS(DOMAIN_ID,MSG_ID,USER_ID,PART_ID,TYPE_ID,CONTENT_ID,TDATA,DSIZE,APARAMS,PDEFAULT,FNAME,FREETEXT_ID)
          values (_domain_id,_msg_id,_user_id,_part_id,_type_id,_content_id,_body,_dsize,_aparams,_pdefault,_att_fname,_freetext_id);
        _part_id := _part_id + 1;
      }
    }
  }
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_get_mimetype_name(
  in  _id   integer,
  out _name varchar)
{
  _name := coalesce((select MIME_TYPE from OMAIL.WA.RES_MIME_TYPES where ID = _id), 'application/octet-stream');
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_get_mm_priority(
  inout _name  varchar,
  inout _value integer)
{
  if (isnull(_name) and isnull(_value)) {
    _name  := 'Normal';
    _value := 1;
    return;
  };

  declare _priority any;
  _priority := vector(1,'Low',2,'Lower',3,'Normal',4,'High',5,'Higher','Low',1,'Lower',2,'Normal',3,'High',4,'Higher',5);

  if (_name <> '') {
    _value := get_keyword_ucase(_name,_priority,'3');
  } else {
    _name  := get_keyword_ucase(_value,_priority,'Normal');
  };
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.external_account_get (
  in _domain_id integer,
  in _user_id   integer,
  in _id integer)
{
  declare _rs, _sql varchar;

  _rs  := '';
  _sql := OMAIL.WA.folders_list (_domain_id, _user_id);
  if (_id = 0)
  { -- list
    for (select * from OMAIL.WA.EXTERNAL_ACCOUNT where EA_DOMAIN_ID = _domain_id and EA_USER_ID = _user_id) do
    {
      _rs  := sprintf ('%s<account>', _rs);
      _rs  := sprintf ('%s<id>%d</id>', _rs, EA_ID);
      _rs  := sprintf ('%s<name>%V</name>', _rs, EA_NAME);
      _rs  := sprintf ('%s<type>%s</type>', _rs, EA_TYPE);
      _rs  := sprintf ('%s<host>%V</host>', _rs, EA_HOST);
      _rs  := sprintf ('%s<port>%d</port>', _rs, EA_PORT);
      _rs  := sprintf ('%s<connect_type>%s</connect_type>', _rs, EA_TYPE);
      _rs  := sprintf ('%s<user>%V</user>', _rs, EA_USER);
      _rs  := sprintf ('%s<folder_id>%d</folder_id>', _rs, EA_FOLDER_ID);
      _rs  := sprintf ('%s<check_date>%V</check_date>', _rs, case when isnull (EA_CHECK_DATE) then '' else cast (EA_CHECK_DATE as varchar) end);
      _rs  := sprintf ('%s<check_error>%d</check_error>', _rs, EA_CHECK_ERROR);
      _rs  := sprintf ('%s<check_interval>%d</check_interval>', _rs, EA_CHECK_INTERVAL);
      _rs  := sprintf ('%s</account>', _rs);
    }
  }
  else if (_id = -1)
  { -- new
    _rs  := '<id>0</id>' ||
            '<port>100</port>' ||
            '<check_interval>1</check_interval>' ||
            '<mcopy>1</mcopy>' ||
            _sql;

  }
  else
  { -- edit
    for (select * from OMAIL.WA.EXTERNAL_ACCOUNT where EA_DOMAIN_ID = _domain_id and EA_USER_ID = _user_id and EA_ID = _id) do
    {
      _rs := sprintf ('<id>%d</id>', EA_ID) ||
             sprintf ('<name>%V</name>', EA_NAME) ||
             sprintf ('<type>%s</type>', EA_TYPE) ||
             sprintf ('<host>%V</host>', EA_HOST) ||
             sprintf ('<port>%d</port>', EA_PORT) ||
             sprintf ('<connect_type>%s</connect_type>', EA_CONNECT_TYPE) ||
             sprintf ('<user>%V</user>', EA_USER) ||
             sprintf ('<password>%V</password>', '**********') ||
             sprintf ('<folder_id>%d</folder_id>', EA_FOLDER_ID) ||
             sprintf ('<mcopy>%d</mcopy>', EA_MCOPY) ||
             sprintf ('<check_date>%V</check_date>', case when isnull (EA_CHECK_DATE) then '' else cast (EA_CHECK_DATE as varchar) end) ||
             sprintf ('<check_error>%d</check_error>', EA_CHECK_ERROR) ||
             sprintf ('<check_interval>%d</check_interval>', EA_CHECK_INTERVAL) ||
             _sql;
    }
  }
  return _rs;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_get_settings (
  in   _domain_id integer,
  in   _user_id   integer,
  in   _keyword   varchar := 'base_settings')
{
  declare N integer;
  declare _settings any;

  _settings := coalesce((select deserialize(SVALUES) from OMAIL.WA.SETTINGS where DOMAIN_ID = _domain_id and USER_ID = _user_id and SNAME = _keyword), vector ());
  for (N := 1; N < length(_settings); N := N + 2)
  {
    if (isnull(_settings[N]))
      aset(_settings, N, '');
  }

  if (mod(length(_settings),2) <> 0)
    _settings := vector_concat(_settings,vector(''));

  if (OMAIL.WA.omail_getp('msg_order', _settings) not in (1,2,3,4,5,6,7))
    OMAIL.WA.omail_setparam('msg_order', _settings, 5);

  if (OMAIL.WA.omail_getp('msg_direction', _settings) not in (1,2))
    OMAIL.WA.omail_setparam('msg_direction',_settings, 2);

  if (OMAIL.WA.omail_getp('folder_view', _settings) not in (1,2))
    OMAIL.WA.omail_setparam('folder_view',_settings, 1);

  if (OMAIL.WA.omail_getp ('groupBy', _settings) not in (1,2,3,4,5,6,7,8))
    OMAIL.WA.omail_setparam ('groupBy',_settings, 0);

  if (OMAIL.WA.omail_getp('usr_sig_inc', _settings) not in (0,1))
    OMAIL.WA.omail_setparam('usr_sig_inc', _settings,0);

  if (OMAIL.WA.omail_getp('usr_sig_inc',_settings) = 0)
    OMAIL.WA.omail_setparam('usr_sig_txt', _settings, '');

  if (cast (OMAIL.WA.omail_getp ('msg_result', _settings) as integer) <= 5)
    OMAIL.WA.omail_setparam('msg_result',_settings, 10);

  if (OMAIL.WA.omail_getp('msg_name', _settings) not in (0,1))
    OMAIL.WA.omail_setparam('msg_name', _settings, 0);

  if (OMAIL.WA.omail_getp('msg_name',_settings) = 0)
    OMAIL.WA.omail_setparam('msg_name_txt',_settings, '');

  if (OMAIL.WA.omail_getp('atom_version',_settings) = '')
    OMAIL.WA.omail_setparam('atom_version',_settings, '1.0');

  if (OMAIL.WA.omail_getp ('spam_msg_action', _settings) not in (0,1,2))
    OMAIL.WA.omail_setparam('spam_msg_action', _settings, 0);

  if (OMAIL.WA.omail_getp ('spam_msg_state', _settings) not in (0,1))
    OMAIL.WA.omail_setparam('spam_msg_state', _settings, 0);

  if (cast (OMAIL.WA.omail_getp ('spam_msg_clean', _settings) as integer) <= 0)
    OMAIL.WA.omail_setparam('spam_msg_clean', _settings, 0);

  if (cast (OMAIL.WA.omail_getp ('spam_msg_header', _settings) as integer) <= 0)
    OMAIL.WA.omail_setparam('spam_msg_header', _settings, 0);

  if (OMAIL.WA.omail_getp('spam', _settings) not in (0,1,2,3,4,5))
    OMAIL.WA.omail_setparam('spam',_settings, 0);

  if (OMAIL.WA.omail_getp('conversation', _settings) not in (0,1))
    OMAIL.WA.omail_setparam('conversation',_settings, 0);

  if (isnull (OMAIL.WA.omail_getp ('security_sign', _settings)))
  {
    OMAIL.WA.omail_setparam ('security_sign', _settings, '');
  } else {
    if (not OMAIL.WA.certificateExist (_user_id, OMAIL.WA.omail_getp ('security_sign', _settings)))
    {
      OMAIL.WA.omail_setparam ('security_sign', _settings, '');
    }
  }
  if ((OMAIL.WA.omail_getp ('security_sign_mode', _settings) not in (0, 1)) or (OMAIL.WA.omail_getp ('security_sign', _settings) = ''))
  {
    OMAIL.WA.omail_setparam ('security_sign_mode', _settings, 0);
  }

  if (isnull (OMAIL.WA.omail_getp ('security_encrypt', _settings)))
  {
    OMAIL.WA.omail_setparam ('security_encrypt', _settings, '');
  } else {
    if (not OMAIL.WA.certificateExist (_user_id, OMAIL.WA.omail_getp ('security_encrypt', _settings)))
    {
      OMAIL.WA.omail_setparam ('security_encrypt', _settings, '');
    }
  }
  if ((OMAIL.WA.omail_getp ('security_encrypt_mode', _settings) not in (0, 1)) or (OMAIL.WA.omail_getp ('security_encrypt', _settings) = ''))
  {
    OMAIL.WA.omail_setparam ('security_encrypt_mode', _settings, 0);
  }

  OMAIL.WA.omail_setparam ('discussion', _settings, OMAIL.WA.discussion_check ());
  OMAIL.WA.omail_setparam('update_flag', _settings, 0);

  OMAIL.WA.omail_setparam ('app', _settings, DB.DBA.WA_USER_APP_ENABLE (_user_id));

  return _settings;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_set_settings_data(
  in _domain_id integer,
  in _user_id   integer,
  in _keyword varchar,
  inout         _settings any)
{
  insert replacing OMAIL.WA.SETTINGS (DOMAIN_ID, USER_ID, SNAME, SVALUES)
    values (_domain_id, _user_id, _keyword, serialize(_settings));
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.dashboard_rs (
  in p0 integer,
  in p1 integer)
{
  declare S, posts, _id, _title, _time any;
  declare c0 integer;
  declare c1 varchar;
  declare c2 datetime;

  result_names(c0, c1, c2);
  S := OMAIL.WA.dashboard_get (p0, p1);
  if (S <> '')
  {
    posts := xpath_eval ('//mail', xml_tree_doc (xml_tree(S)), 0);
    foreach (any post in posts) do
    {
      _id    := cast (xpath_eval ('@id', post) as integer);
      _title := serialize_to_UTF8_xml (xpath_eval ('string(./title)', post));
      _time  := stringdate (xpath_eval ('string(./dt)', post));
      result (_id, _title, _time);
    }
  }
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.dashboard_get(
  in _domain_id integer,
  in _user_id integer)
{
  return coalesce((select SVALUES from OMAIL.WA.SETTINGS where DOMAIN_ID = _domain_id and USER_ID = _user_id and SNAME = 'dashboard'), '');
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.dashboard_set(
  in _domain_id integer,
  in _user_id   integer,
  inout _dashboard any)
{
  insert replacing OMAIL.WA.SETTINGS (SVALUES, DOMAIN_ID, USER_ID, SNAME)
    values (_dashboard, _domain_id, _user_id, 'dashboard');
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.dashboard_update(
  in _domain_id integer,
  in _user_id   integer,
  in _msg_id    integer,
  in _title     integer,
  in _date      datetime,
  in _from      varchar,
  in _fromEMail varchar)
{
  declare waID integer;
  declare dashboard, S varchar;
  declare stream any;

  dashboard := OMAIL.WA.dashboard_get(_domain_id, _user_id);

  stream := string_output ();
  http ('<mail-db>', stream);

  if (not is_empty_or_null(dashboard))
  {
    declare xt, xp, xn any;
    declare i, l int;

    xt := xtree_doc (dashboard);
    xn := xpath_eval (sprintf('//mail[@id="%d"]', _msg_id), xt, 1);

    xp := xpath_eval ('/mail-db/*', xt, 0);
    l := length (xp);
    if (l > 10)
      l := 10;
    i := 0;
    if ((l = 10) and isnull(xn))
      i := 1;
    for (;i < l; i := i + 1)
    {
      if (cast(xpath_eval ('number(@id)', xp[i], 1) as integer) <> _msg_id)
  	    http (serialize_to_UTF8_xml (xp[i]), stream);
  	}
  }

  waID := coalesce((select top 1 WAI_ID from DB.DBA.WA_MEMBER, DB.DBA.WA_INSTANCE where WAM_INST = WAI_NAME and WAM_USER = _user_id and WAI_TYPE_NAME = 'oMail' order by WAI_ID), 0);
  S := sprintf (
         '<mail id="%d">'||
           '<title><![CDATA[%s]]></title>'||
           '<dt>%s</dt>'||
           '<link>%V</link>' ||
           '<from><![CDATA[%s]]></from>'||
           '<email><![CDATA[%s]]></email>'||
         '</mail>',
         _msg_id, _title, OMAIL.WA.dt_iso8601 (_date), SIOC..mail_post_iri (_user_id, _msg_id), _from, _fromEMail);
  http (S, stream);

  http ('</mail-db>', stream);

  OMAIL.WA.dashboard_set(_domain_id, _user_id, string_output_string (stream));
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.dashboard_delete(
  in _domain_id integer,
  in _user_id   integer,
  in _msg_id    integer)
{
  declare dashboard varchar;
  declare stream any;

  dashboard := OMAIL.WA.dashboard_get(_domain_id, _user_id);

  stream := string_output ();
  http ('<mail-db>', stream);

  if (not is_empty_or_null(dashboard))
  {
    declare xt, xp any;
    declare i, l int;

    xt := xtree_doc (dashboard);
    xp := xpath_eval ('/mail-db/*', xt, 0);
    l := length (xp);
    for (i := 0; i < l; i := i + 1)
    {
      if (cast(xpath_eval ('number(@id)', xp[i], 1) as integer) <> _msg_id)
  	    http (serialize_to_UTF8_xml (xp[i]), stream);
	  }
  }

  http ('</mail-db>', stream);

  OMAIL.WA.dashboard_set(_domain_id, _user_id, string_output_string (stream));
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.host_protocol ()
{
  return case when is_https_ctx () then 'https://' else 'http://' end;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.host_url ()
{
  declare host varchar;

  declare exit handler for sqlstate '*' { goto _default; };

  if (is_http_ctx ())
  {
    host := http_request_header (http_request_header ( ) , 'Host' , null , sys_connected_server_address ());
    if (isstring (host) and strchr (host , ':') is null)
    {
      declare hp varchar;
      declare hpa any;

      hp := sys_connected_server_address ();
      hpa := split_and_decode ( hp , 0 , '\0\0:');
      host := host || ':' || hpa [1];
    }
    goto _exit;
  }

_default:;
  host := cfg_item_value (virtuoso_ini_path (), 'URIQA', 'DefaultHost');
  if (host is null)
  {
    host := sys_stat ('st_host_name');
    if (server_http_port () <> '80')
      host := host || ':' || server_http_port ();
  }

_exit:;
  if (host not like OMAIL.WA.host_protocol () || '%')
    host := OMAIL.WA.host_protocol () || host;

  return host;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_url (
  in _domain_id integer)
{
  return concat(OMAIL.WA.host_url(), '/oMail/', cast(_domain_id as varchar), '/');
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.banner_links (
  in domain_id integer,
  in sid varchar := null,
  in realm varchar := null)
{
  if (domain_id <= 0)
    return 'Public Mails';

  return sprintf ('<a href="%s" title="%s" onclick="javascript: return myA(this);">%s</a> (<a href="%s" title="%s" onclick="javascript: return myA(this);">%s</a>)',
                  OMAIL.WA.domain_sioc_url (domain_id),
                  OMAIL.WA.domain_name (domain_id),
                  OMAIL.WA.domain_name (domain_id),
                  OMAIL.WA.account_sioc_url (domain_id),
                  OMAIL.WA.account_fullName (OMAIL.WA.domain_owner_id (domain_id)),
                  OMAIL.WA.account_fullName (OMAIL.WA.domain_owner_id (domain_id))
                 );
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_open_url (
  in _sid varchar,
  in _realm varchar,
  in _domain_id integer,
  in _user_id integer,
  in _msg_id integer)
{
  return concat(OMAIL.WA.omail_url(_domain_id), sprintf('open.vsp?sid=%s&realm=%s&op=%d', _sid, _realm, _msg_id));
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_get_xslt()
{
  declare sHost varchar;

  sHost := cast(registry_get('_oMail_path_') as varchar);
  if (sHost = '0')
    return 'file://apps/WebMail/xslt/';
  if (isnull(strstr(sHost, '/DAV/VAD')))
    return sprintf('file://%sxslt/', sHost);
  return sprintf('virt://WS.WS.SYS_DAV_RES.RES_FULL_PATH.RES_CONTENT:%sxslt/', sHost);
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_xslt_full(in xslt_file varchar)
{
  return concat(OMAIL.WA.omail_get_xslt(), xslt_file);
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_getp(in _names varchar, in _params any)
{
  return get_keyword(_names, _params, '');
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_init_user_data(
  in _domain_id integer,
  in _user_id   integer,
  in _address   varchar := null)
{
  insert soft OMAIL.WA.FOLDERS (DOMAIN_ID, USER_ID, FOLDER_ID, PARENT_ID, NAME, F_TYPE)
    values (_domain_id, _user_id, 100, 0, 'Inbox', 'INBOX');
  insert soft OMAIL.WA.FOLDERS (DOMAIN_ID, USER_ID, FOLDER_ID, PARENT_ID, NAME, F_TYPE)
    values (_domain_id, _user_id, 110, 0, 'Trash', 'TRASH');
  insert soft OMAIL.WA.FOLDERS (DOMAIN_ID, USER_ID, FOLDER_ID, PARENT_ID, NAME, F_TYPE)
    values (_domain_id, _user_id, 120, 0, 'Sent', 'SENT');
  insert soft OMAIL.WA.FOLDERS (DOMAIN_ID, USER_ID, FOLDER_ID, PARENT_ID, NAME, F_TYPE)
    values (_domain_id, _user_id, 130, 0, 'Drafts', 'DRAFTS');
  insert soft OMAIL.WA.FOLDERS (DOMAIN_ID, USER_ID, FOLDER_ID, PARENT_ID, NAME, F_TYPE)
    values (_domain_id, _user_id, 125, 0, 'Spam', 'SPAM');
  insert soft OMAIL.WA.FOLDERS (DOMAIN_ID, USER_ID, FOLDER_ID, PARENT_ID, NAME)
    values (_domain_id, _user_id, 115, 0, 'Smart Folders');
  insert soft OMAIL.WA.FOLDERS (DOMAIN_ID, USER_ID, FOLDER_ID, PARENT_ID, NAME)
    values (_domain_id, _user_id, 116, 115, 'Unread Mails');

  update OMAIL.WA.FOLDERS
     set PARENT_ID = 0, SEQ_NO = 1, NAME = 'Inbox', SYSTEM_FLAG = 'S'
   where DOMAIN_ID = _domain_id and USER_ID = _user_id and FOLDER_ID = 100;
  update OMAIL.WA.FOLDERS
     set PARENT_ID = 0, SEQ_NO = 5, NAME = 'Trash', SYSTEM_FLAG = 'S'
   where DOMAIN_ID = _domain_id and USER_ID = _user_id and FOLDER_ID = 110;
  update OMAIL.WA.FOLDERS
     set PARENT_ID = 0, SEQ_NO = 2, NAME = 'Sent', SYSTEM_FLAG = 'S'
   where DOMAIN_ID = _domain_id and USER_ID = _user_id and FOLDER_ID = 120;
  update OMAIL.WA.FOLDERS
     set PARENT_ID = 0, SEQ_NO = 3, NAME = 'Drafts', SYSTEM_FLAG = 'S'
   where DOMAIN_ID = _domain_id and USER_ID = _user_id and FOLDER_ID = 130;
  update OMAIL.WA.FOLDERS
     set PARENT_ID = 0, SEQ_NO = 4, NAME = 'Spam', SYSTEM_FLAG = 'S'
   where DOMAIN_ID = _domain_id and USER_ID = _user_id and FOLDER_ID = 125;
  update OMAIL.WA.FOLDERS
     set PARENT_ID = 0, SEQ_NO = 6, NAME = 'Smart Folders', SYSTEM_FLAG = 'S', SMART_FLAG = 'S'
   where DOMAIN_ID = _domain_id and USER_ID = _user_id and FOLDER_ID = 115;
  update OMAIL.WA.FOLDERS
     set PARENT_ID = 115, NAME = 'Unread Mails', SYSTEM_FLAG = 'S', SMART_FLAG = 'S', DATA = serialize (vector ('q_read', '1'))
   where DOMAIN_ID = _domain_id and USER_ID = _user_id and FOLDER_ID = 116;

  -- insert welcome message
  if (not isnull (_address))
  OMAIL.WA.omail_welcome_msg(_domain_id, _user_id, _address);
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_welcome_msg(
  in _domain_id integer,
  in _user_id   integer,
  in _address   varchar)
{
  declare _text any;

  _text := OMAIL.WA.omail_welcome_msg_1 ('Mail admin','admin@domain.com',_address,_address,OMAIL.WA.dt_rfc822(now()));
  OMAIL.WA.omail_receive_message(_domain_id,_user_id, null, _text, null, -1, 100);
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_insert_attachment(
  in    _domain_id integer,
  in    _user_id   integer,
  inout _params    any,
  in    _msg_id    integer,
  out   _error     integer)
{
  WHENEVER NOT FOUND goto err;

  declare _attach any;
  declare _att_attrs, _att_fname, _att_name, _att_type, _att_encoding varchar;

  _error := 0;
  _attach := '';
  if (get_keyword ('att_source', _params, '-1') = '0')
  {
    _attach    := get_keyword ('att_1', _params, '', 1);
    _att_attrs := get_keyword_ucase ('attr-att_1', _params);
    _att_fname := trim(get_keyword_ucase ('filename', _att_attrs));
    if (is_empty_or_null(_att_fname))
      return;
    _att_name  := substring(_att_fname,OMAIL.WA.omail_locate_last('\\',_att_fname)+1,length(_att_fname));
    _att_type  := get_keyword_ucase ('Content-Type', _att_attrs);
  }
  else if (get_keyword ('att_source', _params, '-1') = '1')
  {
    declare reqHdr, resHdr varchar;
    declare vspx_user, vspx_pwd varchar;
    declare userInfo any;

    _att_fname := trim(get_keyword ('att_2', _params, ''));
    if (is_empty_or_null(_att_fname))
      return;

    userInfo := vector('user_id', _user_id);
    OMAIL.WA.omail_dav_api_params(userInfo, vspx_user, vspx_pwd);
    OMAIL.WA.omail_dav_content (OMAIL.WA.host_url () || _att_fname, _attach, _att_type, vspx_user, vspx_pwd);
    if (isnull (_attach))
    {
      _error := 3003;
      return;
    }
    _att_name := substring(_att_fname,OMAIL.WA.omail_locate_last('/',_att_fname)+1,length (_att_fname));
  }

  -- Insert attachments -----------------------------------------------------------------------------------------
  if (length (_attach) > 0)
  {
    declare _part_id any;
    declare _type_id,_aparams,_freetext_id integer;

    if (subseq(_att_type,0, locate('/',_att_type)-1) = 'text')
      _att_encoding := 'quoted-printable';
    else if (subseq(_att_type,0, locate('/',_att_type)-1) = 'multipart')
      _att_encoding := '';
    else if (subseq(_att_type,0, locate('/',_att_type)-1) = 'message')
      _att_encoding := '';
    else
      _att_encoding := 'base64';
    _aparams := sprintf('<content-type>%s</content-type><name>%s</name><filename>%s</filename><content-transfer-encoding>%s</content-transfer-encoding>',_att_type,_att_name,_att_fname,_att_encoding);

    _freetext_id := sequence_next ('OMAIL.WA.omail_seq_eml_freetext_id');
    _type_id := OMAIL.WA.res_get_mimetype_id(_att_type);
    _part_id := coalesce((select MAX(PART_ID) from OMAIL.WA.MSG_PARTS where DOMAIN_ID = _domain_id and USER_ID = _user_id and MSG_ID = _msg_id), 0) + 1;
    insert into OMAIL.WA.MSG_PARTS(DOMAIN_ID, MSG_ID, USER_ID, PART_ID, TYPE_ID, CONTENT_ID, TDATA, DSIZE, APARAMS, PDEFAULT, FNAME, FREETEXT_ID)
      values (_domain_id, _msg_id, _user_id, _part_id, _type_id, '',_attach, length(_attach), _aparams, 0, _att_name, _freetext_id);
    update OMAIL.WA.MESSAGES
       set ATTACHED = ATTACHED + 1
     where DOMAIN_ID = _domain_id
       and USER_ID = _user_id
       and MSG_ID = _msg_id;
  } else {
    _error := 3002;
  }
  return;

err:
  _error := 3001;
  return;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_dav_content (
  in uri varchar,
  out content any,
  out content_type any,
  in auth_uid varchar := null,
  in auth_pwd varchar := null)
{
  declare exit handler for sqlstate '*'
  {
    return null;
  };

  declare N integer;
  declare oldUri, newUri, reqHdr, resHdr varchar;
  declare xt any;

  content := null;
  content_type := null;
  newUri := replace (uri, ' ', '%20');
  reqHdr := sprintf ('Authorization: Basic %s', encode_base64(auth_uid || ':' || auth_pwd));

_again:
  N := N + 1;
  oldUri := newUri;
  commit work;
  content := http_get (newUri, resHdr, 'GET', reqHdr);
  if (resHdr[0] like 'HTTP/1._ 30_ %')
  {
    newUri := http_request_header (resHdr, 'Location');
    newUri := WS.WS.EXPAND_URL (oldUri, newUri);
    if (N > 15)
      return null;
    if (newUri <> oldUri)
      goto _again;
  }
  if (resHdr[0] like 'HTTP/1._ 4__ %' or resHdr[0] like 'HTTP/1._ 5__ %')
  {
    content := null;
  } else
  {
    content_type := http_request_header (resHdr, 'Content-Type', null, 'application/octet-stream');
  }
  return content;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_locate_last(
  in _str1 varchar,
  in _str2 varchar)
{
  declare _start, _rez integer;
  _start := 1;
  while(1) {
    _rez := locate(_str1,_str2,_start);
    if (not(_rez))
      return _start-length(_str1);
    _start := _rez+length(_str1);
  };
  return _rez;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_mark_msg(
  in _domain_id  integer,
  in _user_id    integer,
  in _msg_id     integer,
  in _mstatus    integer)
{
  update OMAIL.WA.MESSAGES
     set MSTATUS = either(lt(MSTATUS,2),_mstatus,MSTATUS)
   where DOMAIN_ID = _domain_id
     and USER_ID = _user_id
     and MSG_ID = _msg_id;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_message(
  inout path any,
  inout lines any,
  inout params any)
{
  -- www procedure

  declare _rs, _sid, _realm, _op, _sql_result1, _sql_result2, _sql_result3, _sql_result4, _sql_result5, _sql_result6, _pnames varchar;
  declare _params,_page_params any;
  declare _user_info,_settings any;
  declare _user_id,_folder_id,_error,_domain_id integer;

  _sid       := get_keyword('sid',params,'');
  _realm     := get_keyword('realm',params,'');
  _user_info := get_keyword('user_info',params);

  -- TEMP constants -----------------------------
  _user_id   := get_keyword('user_id',_user_info);
  _domain_id := 1;

  -- GET SETTINGS ------------------------------
  _settings := OMAIL.WA.omail_get_settings(_domain_id, _user_id, 'base_settings');

  -- Set constants  -------------------------------------------------------------------
  _page_params := vector(0,0,0,0,0,0,0,0,0,0,0,0);

  -- Set Variable--------------------------------------------------------------------
  _folder_id   := get_keyword('fid',params,'');

  -- Set Params --------------------------------------------------------------------
  _pnames := 'msg_id,list_pos,mime_type,folder_view,ch_mstatus';
  _params := OMAIL.WA.omail_str2params(_pnames,get_keyword('op',params,'0,0,0,0,0'),',');

  OMAIL.WA.omail_setparam('sid',_params,_sid);
  OMAIL.WA.omail_setparam('realm',_params,_realm);
  OMAIL.WA.omail_setparam('order',_params,OMAIL.WA.omail_getp('msg_order',_settings)); -- get from settings
  OMAIL.WA.omail_setparam('direction',_params,OMAIL.WA.omail_getp('msg_direction',_settings));
  OMAIL.WA.omail_setparam('aresults',_params,10);

  -- Form Action---------------------------------------------------------------------
  if (get_keyword ('fa_move.x', params,'') <> '')
  {
    OMAIL.WA.messages_move (_domain_id, _user_id, params);
      _op := OMAIL.WA.omail_params2str(_pnames,_params,',');
      OMAIL.WA.utl_redirect(sprintf('open.vsp?sid=%s&realm=%s&op=%s',_sid,_realm,_op));
      return;
    }
  else if (get_keyword ('fa_mark.x', params,'') <> '')
  {
    -- > 'mark msg'
    OMAIL.WA.omail_setparam('ch_mstatus',_params,1);
    OMAIL.WA.omail_mark_msg(_domain_id,_user_id, OMAIL.WA.omail_getp('msg_id',_params), atoi(get_keyword('ms',params,'1')));
    if (_error = 0)
    {
      _op := OMAIL.WA.omail_params2str(_pnames,_params,',');
       OMAIL.WA.utl_redirect(sprintf('open.vsp?sid=%s&realm=%s&op=%s%s',_sid,_realm,_op,OMAIL.WA.omail_external_params_url(params)));
      return;
    }
    OMAIL.WA.utl_redirect(sprintf('err.vsp?sid=%s&realm=%s&err=%d',_sid,_realm,_error));
    return;

  }
  else if (get_keyword ('fa_tags_save.x', params, '') <> '')
  {
    declare tags varchar;

    -- save tags
    tags := trim(get_keyword('tags', params, ''));
    if (tags <> '')
      if (not OMAIL.WA.validate_tags (tags))
      {
        OMAIL.WA.utl_redirect(sprintf('err.vsp?sid=%s&realm=%s&err=%d',_sid,_realm,4001));
        return;
      }
          OMAIL.WA.tags_update(_domain_id,_user_id,OMAIL.WA.omail_getp('msg_id',_params), tags);
  }

  -- Change Settings --------------------------------------------------------------------
  if (not OMAIL.WA.omail_check_interval(OMAIL.WA.omail_getp ('folder_view',_params),1,2))
  {
    OMAIL.WA.omail_setparam('folder_view',_params,OMAIL.WA.omail_getp('folder_view',_settings));
  }
  else if (OMAIL.WA.omail_getp ('folder_view',_params) <> OMAIL.WA.omail_getp ('folder_view',_settings))
  {
      OMAIL.WA.omail_setparam('folder_view',_settings,OMAIL.WA.omail_getp('folder_view',_params));
      OMAIL.WA.omail_setparam('update_flag',_settings,1);
    }
  if (OMAIL.WA.omail_getp('ch_mstatus',_params) <> 1)
    OMAIL.WA.omail_mark_msg(_domain_id,_user_id,OMAIL.WA.omail_getp('msg_id',_params),1);

  -- SQL Statement-------------------------------------------------------------------
  _sql_result1 := OMAIL.WA.omail_open_message(_domain_id,_user_id,_params, 1, 1);
  _sql_result2 := OMAIL.WA.omail_select_next_prev(_domain_id,_user_id,_params);
  _sql_result3 := OMAIL.WA.omail_select_attachment(_domain_id,_user_id,OMAIL.WA.omail_getp ('msg_id',_params), 0);
  _sql_result4 := OMAIL.WA.omail_select_attachment_msg(_domain_id, _user_id, OMAIL.WA.omail_getp ('msg_id',_params), 0);
  _sql_result5 := OMAIL.WA.folders_list (_domain_id, _user_id);
  _sql_result6 := OMAIL.WA.folders_combo_list (_domain_id, _user_id, OMAIL.WA.message_folder (_domain_id, _user_id, OMAIL.WA.omail_getp ('msg_id',_params)));

  -- Page Params---------------------------------------------------------------------
  aset(_page_params,0,vector('sid',_sid));
  aset(_page_params,1,vector('realm',_realm));
  aset(_page_params,2,vector('op',OMAIL.WA.omail_params2str(_pnames,_params,',')));
  aset(_page_params,3,vector('list_pos',OMAIL.WA.omail_getp('list_pos',_params)));
  aset(_page_params,4,vector('user_info',OMAIL.WA.array2xml(_user_info)));

  -- XML structure-------------------------------------------------------------------
  _rs := OMAIL.WA.omail_page_params(_page_params);
  _rs := sprintf('%s<message>', _rs);
  _rs := sprintf ('%s%s%s', _rs, _sql_result1, _sql_result2);
  _rs := sprintf('%s</message>', _rs);
  _rs := sprintf ('%s%s%s%s%s', _rs, _sql_result3, _sql_result4, _sql_result5, _sql_result6);
  _rs := sprintf('%s%s',_rs,OMAIL.WA.omail_external_params_xml(params));

  return _rs;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_message_body(
  in _domain_id integer,
  in _user_id   integer,
  in _msg_id    integer)
{
  declare _body any;

  _body := get_keyword('message', OMAIL.WA.omail_get_message(_domain_id, _user_id, _msg_id, 1));
  if (is_empty_or_null(_body))
    _body := '~No Body~';
  return _body;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_message_body_parse(
  in _domain_id integer,
  in _user_id   integer,
  in _msg_id    integer,
  inout _body   varchar)
{
  declare _content_id any;

  _content_id := md5(concat(cast(now() as varchar),cast(_domain_id as varchar),cast(_user_id as varchar),cast(_msg_id as varchar)));

  update OMAIL.WA.MSG_PARTS
     set CONTENT_ID = OMAIL.WA.omail_message_body_parse_func(_content_id,PART_ID,_body)
   where DOMAIN_ID = _domain_id
     and USER_ID = _user_id
     and MSG_ID = _msg_id
     and PDEFAULT = 0;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_message_body_parse_func(
  in _content_id varchar,
  in _part_id    integer,
  inout _body   varchar)
{
  declare _pattern, _img_tag any;

  _pattern := sprintf('[pic|%d]',_part_id);
  if (strstr(_body, _pattern))
  {
    _content_id := md5(concat(_content_id,cast(_part_id as varchar)));
    _img_tag    := sprintf('<img src="cid:%s" hspace="5" vspace="5" align="left">', _content_id);
    _body       := replace(_body, _pattern, _img_tag);
    return _content_id;
  }
  return '';
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_message_list(
  in _user_id    integer,
  in _folder_id  integer,
  in _skipped    integer,
  in _pageSize   integer,
  in _sortby     varchar)
{
  declare _rs  varchar;
  declare N integer;
  declare _descr, _rows any;

  _descr := vector('SUBJECT','ATTACHED','ADDRESS','DSIZE','MSG_ID','MSTATUS','PRIORITY','RCV_DATE','ATTACHED');
  N := 0;
  _rs := '';
  for (select SUBJECT,ATTACHED,ADDRESS,DSIZE,MSG_ID,MSTATUS,PRIORITY,RCV_DATE
         from OMAIL.WA.MESSAGES
        where USER_ID = _user_id
          and FOLDER_ID = _folder_id
        ORDER BY MSTATUS) do
  {
    if (N >= (_skipped + _pageSize))
      return _rs;
    _rows := vector(SUBJECT,ATTACHED,ADDRESS,DSIZE,MSG_ID,MSTATUS,PRIORITY,RCV_DATE);
    _rs   := sprintf('%s%s',_rs,OMAIL.WA.omail_result2xml(_descr,_rows,N,_skipped));
    N  := N + 1;
  };
  _rs := sprintf('%s<order>%s</order><direction>%s</direction>',_rs,substring (_sortby,1,1),substring (_sortby,2,1));
  return _rs;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.messages_list (
  in _domain_id integer,
  in _user_id integer,
  in _params any)
{
  declare _folder_id integer;
  declare _sql_statm,_sql_params, _order, _orderIndex, _direction, _directionIndex, _group, _groupIndex, _groupDirection any;

  _folder_id := OMAIL.WA.omail_getp ('folder_id', _params);
  for (select * from OMAIL.WA.FOLDERS where DOMAIN_ID = _domain_id and USER_ID = _user_id and FOLDER_ID = _folder_id) do
  {
    if (SMART_FLAG = 'S')
    {
      declare _data any;

      _data := coalesce (deserialize (DATA), vector ());
      _params := vector_concat (_data, _params);
      _params := vector_concat (_params, vector ('mode', 'advanced'));

      return OMAIL.WA.omail_msg_search (_domain_id, _user_id, _params);
    }
  }
  OMAIL.WA.getOrderDirection (_order, _direction);
  _orderIndex := cast (OMAIL.WA.omail_getp ('order', _params) as integer);
  _directionIndex := cast (OMAIL.WA.omail_getp ('direction',_params) as integer);
  _group := _order;
  _group[0] := 'MSG_ID';
  _groupIndex := cast (OMAIL.WA.omail_getp ('groupBy', _params) as integer);
  _groupDirection := 'asc';
  if (_groupDirection in (2, 4, 6, 7))
    _groupDirection := 'desc';
  if (_groupIndex = _orderIndex)
    _groupDirection := _direction[_directionIndex];
  _sql_statm  := sprintf ('select SUBJECT, ATTACHED, ADDRESS, DSIZE DSIZE, MSG_ID, MSTATUS, PRIORITY, RCV_DATE, OMAIL.WA.omail_groupBy(DOMAIN_ID, USER_ID, MSG_ID, \'%s\', %s) GROUP_BY, OMAIL.WA.omail_groupBy_show (DOMAIN_ID, USER_ID, MSG_ID, \'%s\', %s) GROUP_SHOW from OMAIL.WA.MESSAGES where DOMAIN_ID = ? and USER_ID = ? and FOLDER_ID = ? and PARENT_ID IS NULL ORDER BY GROUP_BY %s, %s %s, RCV_DATE desc', _group[_groupIndex], _group[_groupIndex], _group[_groupIndex], _group[_groupIndex], _groupDirection, _order[_orderIndex], _direction[_directionIndex]);
  _sql_params := vector (1, _user_id, _folder_id);
  return OMAIL.WA.omail_sql_exec (_domain_id, _user_id, _sql_statm, _sql_params, OMAIL.WA.omail_getp ('skiped', _params), OMAIL.WA.omail_getp ('aresults', _params), cast (_orderIndex as varchar) || cast (_directionIndex as varchar));
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_subject_clean (
  inout subject varchar)
{
  declare tmp, pos any;

  while (1)
  {
    tmp := subject;
    pos := strstr (subject, 'RE:');
    if (not isnull (pos))
      subject := subseq (subject, length('RE:'));
    pos := strstr (subject, 're:');
    if (not isnull (pos))
      subject := subseq (subject, length('RE:'));
    pos := strstr (subject, 'Re:');
    if (not isnull (pos))
      subject := subseq (subject, length('RE:'));
    subject := trim (subject);
    if (tmp = subject)
      goto _exit;
  }
_exit:;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_groupBy (
  in _domain_id integer,
  in _user_id   integer,
  in _msg_id    integer,
  in groupType  varchar,
  in groupValue any)
{
  if (groupType = 'SUBJECT')
  {
    OMAIL.WA.omail_subject_clean (groupValue);
  }
  else if (groupType = 'ATTACHED')
    {
    if (groupValue = 1)
    {
      groupValue := 0;
    } else {
      groupValue := 1;
    }
  }
  else if (groupType = 'ADDRES_INFO')
  {
    groupValue := cast (groupValue as varchar);
  }
  else if (groupType = 'DSIZE')
  {
    if (groupValue < 10 * 1024)
    {
      groupValue := 0;
    }
    else if (groupValue < 25 * 1024)
    {
      groupValue := 1;
    }
    else if (groupValue < 100 * 1024)
    {
      groupValue := 2;
    }
    else if (groupValue < 512 * 1024)
    {
      groupValue := 3;
    }
    else if (groupValue < 1024 * 1024)
    {
      groupValue := 4;
    }
    else if (groupValue < 5 * 1024 * 1024)
    {
      groupValue := 5;
    }
    else
    {
      groupValue := 6;
    }
  }
  else if (groupType = 'MSTATUS')
  {
    if (groupValue = 0)
    {
      groupValue := 3;
    }
    else if (groupValue = 1)
    {
      groupValue := 2;
    }
    else if (groupValue = 5)
    {
      groupValue := 1;
    }
    else
    {
      groupValue := 0;
    }
  }
  else if (groupType = 'PRIORITY')
  {
    ;
  }
  else if (groupType = 'RCV_DATE')
  {
    declare currDate any;

    currDate := OMAIL.WA.dt_curdate ();
    groupValue := OMAIL.WA.dt_dateClear (groupValue);
    if (currDate = groupValue)
    {
      groupValue := 4;
    }
    else if (OMAIL.WA.dt_BeginOfWeek (currDate) = OMAIL.WA.dt_BeginOfWeek (groupValue))
    {
      groupValue := 3;
    }
    else if (OMAIL.WA.dt_BeginOfMonth (currDate) = OMAIL.WA.dt_BeginOfMonth (groupValue))
    {
      groupValue := 2;
    }
    else if (OMAIL.WA.dt_BeginOfYear (currDate) = OMAIL.WA.dt_BeginOfYear (groupValue))
    {
      groupValue := 1;
    }
    else
    {
      groupValue := 0;
    }
  }
  else if (groupType = 'REF_ID')
  {
    declare pos integer;

    if (is_empty_or_null (groupValue))
    {
      groupValue := (select SRV_MSG_ID from OMAIL.WA.MESSAGES where DOMAIN_ID = _domain_id and USER_ID = _user_id and MSG_ID = _msg_id);
    } else {
      groupValue := trim (groupValue);
      pos := strstr (groupValue, ' ');
      if (not isnull (pos))
        groupValue := subseq (groupValue, 0, pos);
    }
  }
  else
  {
    groupValue := '';
  }
  return cast (groupValue as varchar);
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_groupBy_show (
  in _domain_id integer,
  in _user_id   integer,
  in _msg_id    integer,
  in groupType  varchar,
  in groupValue any)
{
  declare prefix any;

  if (groupType = 'SUBJECT')
  {
    prefix := 'Subject: ';
    OMAIL.WA.omail_subject_clean (groupValue);
  }
  else if (groupType = 'ATTACHED')
  {
    prefix := 'Attached: ';
    if (groupValue = 1)
    {
      groupValue := 'With Attachments';
    } else {
      groupValue := 'Without Attachments';
    }
  }
  else if (groupType = 'ADDRES_INFO')
  {
    prefix := 'Address: ';
    groupValue := cast (groupValue as varchar);
  }
  else if (groupType = 'DSIZE')
  {
    prefix := 'Size: ';
    if (groupValue < 10 * 1024)
    {
      groupValue := 'Tiny (less than 10 KB)';
    }
    else if (groupValue < 25 * 1024)
    {
      groupValue := 'Small (10-25 KB)';
    }
    else if (groupValue < 100 * 1024)
    {
      groupValue := 'Medium (25-100 KB)';
    }
    else if (groupValue < 512 * 1024)
    {
      groupValue := 'Large (100-500 KB)';
    }
    else if (groupValue < 1024 * 1024)
    {
      groupValue := 'Very Large (100 KB - 1 MB)';
    }
    else if (groupValue < 5 * 1024 * 1024)
    {
      groupValue := 'Huge (1 - 5 MB)';
    }
    else
    {
      groupValue := 'Very Huge (greater than 5 MB)';
    }
  }
  else if (groupType = 'MSTATUS')
  {
    prefix := 'Status: ';
    if (groupValue = 0)
    {
      groupValue := 'Not Read';
    }
    else if (groupValue = 1)
    {
      groupValue := 'Read';
    }
    else if (groupValue = 5)
    {
      groupValue := 'Sent';
    }
    else
    {
      groupValue := '~ Bad Status ~';
    }
  }
  else if (groupType = 'PRIORITY')
  {
    prefix := 'Priority: ';
    if (groupValue = 1)
    {
      groupValue := 'Highest Priority';
    }
    else if (groupValue = 2)
    {
      groupValue := 'High Priority';
    }
    else if (groupValue = 4)
    {
      groupValue := 'Low Priority';
    }
    else if (groupValue = 5)
    {
      groupValue := 'Lowest Priority';
    }
    else
    {
      groupValue := 'Normal';
    }
  }
  else if (groupType = 'RCV_DATE')
  {
    declare currDate any;

    prefix := 'Date: ';
    currDate := OMAIL.WA.dt_curdate ();
    groupValue := OMAIL.WA.dt_dateClear (groupValue);
    if (currDate = groupValue)
    {
      groupValue := 'Today';
    }
    else if (OMAIL.WA.dt_BeginOfWeek (currDate) = OMAIL.WA.dt_BeginOfWeek (groupValue))
    {
      groupValue := 'This Week';
    }
    else if (OMAIL.WA.dt_BeginOfMonth (currDate) = OMAIL.WA.dt_BeginOfMonth (groupValue))
    {
      groupValue := 'This Month';
    }
    else if (OMAIL.WA.dt_BeginOfYear (currDate) = OMAIL.WA.dt_BeginOfYear (groupValue))
    {
      groupValue := 'This Year';
    }
    else
    {
      groupValue := 'Older';
    }
  }
  else if (groupType = 'REF_ID')
  {
    prefix := 'Conversation: ';
    groupValue := coalesce ((select SUBJECT from OMAIL.WA.MESSAGES where DOMAIN_ID = _domain_id and USER_ID = _user_id and MSG_ID = _msg_id), '~no subject~');
    OMAIL.WA.omail_subject_clean (groupValue);
  }
  else
  {
    prefix := '';
    groupValue := '';
  }
  return prefix || groupValue;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_msg_rfc(
  in _domain_id integer,
  in _user_id   integer,
  in _msg_id    integer,
  out _body     any)
{
  declare _sql_result1,_sql_result2,_xslt_url any;

  WHENEVER NOT FOUND GOTO _NOT_FOUND;
  _body := '';

  _xslt_url := OMAIL.WA.omail_xslt_full('construct_mail_pop3.xsl');

  -- execute procedure ---------------------------------------------------------
  _sql_result1 := sprintf('%s',OMAIL.WA.omail_open_message_full(_domain_id,_user_id,_msg_id));
  _sql_result2 := sprintf('%s',OMAIL.WA.omail_select_attachment_msg_full(_domain_id,_user_id,_msg_id));

  -- XML structure -------------------------------------------------------------
  _body := sprintf('%s<message>\n', _body);
  _body := sprintf('%s%s\n',_body,_sql_result1);
  _body := sprintf('%s%s\n',_body,_sql_result2);
  _body := sprintf('%s</message>', _body);

  --string_to_file('debug.txt',_body,-2);--return;

  _body := xslt(_xslt_url,xml_tree_doc(xml_tree(_body)));
  _body := cast(_body as varchar);

  return (1);

_NOT_FOUND:
  return (0);
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.email_search_str(
  in S varchar)
{
  declare N, L integer;
  declare V, V1, T, C, rs any;

  S := replace(S, '"', '');
  S := replace(S, '<', '');
  S := replace(S, '>', '');
  S := replace(S, '@', ' ');
  V := split_and_decode(S, 0, '\0\0,');

  rs := '';
  C := '';
  for (N := 0; N < length (V); N := N + 1)
  {
    if (length (trim (V[L])))
    {
      V1 := split_and_decode(trim(V[N]), 0, '\0\0 ');
      for (L := 0; L < length (V1); L := L + 1)
      {
        T := trim(V1[L]);
        T := replace(T, '&', '&amp;');
        T := replace(T, '\\', '&#092;');
        T := trim(T, '~');
        T := trim(T, '|');
        if (OMAIL.WA.validate_xcontains(T))
        {
          if ((N = length(V)-1) and (L = length(V1)-1))
            T := concat(T, '*');
          rs := concat(rs, C, '''', T, '''');
          C := ' and ';
        }
      }
    }
  }
  return rs;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_msg_search(
  in _domain_id  integer,
  in _user_id    integer,
  in _params     any,
  in _exec       integer := 1)
{
  declare tmp, _empty, _sql, _sql_statm, _sql_params, _aquery, _order, _orderIndex, _direction, _directionIndex, _group, _groupIndex, _groupDirection any;

  OMAIL.WA.getOrderDirection (_order, _direction);
  _orderIndex := cast (OMAIL.WA.omail_getp ('order', _params) as integer);
  _directionIndex := cast (OMAIL.WA.omail_getp ('direction',_params) as integer);
  _group := _order;
  _group[0] := 'MSG_ID';
  _groupIndex := cast (OMAIL.WA.omail_getp ('groupBy', _params) as integer);
  _groupDirection := 'asc';
  if (_groupDirection in (2, 4, 6, 7))
  _groupDirection := 'desc';
  if (_groupIndex = _orderIndex)
    _groupDirection := _direction[_directionIndex];

  _sql_params  := vector(_domain_id, _user_id);
  _empty       := 0;

  ------------------------------------------------------------------------------
  -- Search string -------------------------------------------------------------
  ------------------------------------------------------------------------------
  if (get_keyword ('mode',_params,'') = 'advanced')
  {
    -- advance search
    _sql_statm  := concat (' select distinct <MAX> M.SUBJECT, \n',
                          '        M.ATTACHED, \n',
                          '        cast(M.ADDRESS as varchar) ADDRESS, \n',
                          '        M.DSIZE DSIZE, \n',
                          '        M.MSG_ID, \n',
                          '        M.MSTATUS, \n',
                          '        M.PRIORITY, \n',
                          '        M.RCV_DATE, \n',
                          '        OMAIL.WA.omail_groupBy (M.DOMAIN_ID, M.USER_ID, M.MSG_ID, \'%s\', M.%s) GROUP_BY, \n',
                          '        OMAIL.WA.omail_groupBy_show (M.DOMAIN_ID, M.USER_ID, M.MSG_ID, \'%s\', M.%s) GROUP_SHOW \n',
                          '   from OMAIL.WA.MSG_PARTS P, \n',
                          '        OMAIL.WA.MESSAGES M \n',
                          '  where M.DOMAIN_ID = P.DOMAIN_ID',
                          '    and M.USER_ID = P.USER_ID \n',
                          '    and M.MSG_ID = P.MSG_ID \n',
                          '    and M.DOMAIN_ID = ? \n',
                          '    and M.USER_ID = ? ');
    _sql_statm  := sprintf (_sql_statm, _group[_groupIndex], _group[_groupIndex], _group[_groupIndex], _group[_groupIndex]);
    _sql := _sql_statm;

    if (atoi (get_keyword ('q_fid', _params, '0')) <> 0)
    {
      _sql_statm  := sprintf('%s and FOLDER_ID = ?',_sql_statm);
      _sql_params := vector_concat(_sql_params,vector(cast(get_keyword('q_fid',_params,'') as integer)));
    }
    if (get_keyword ('q_attach', _params) = '1')
      _sql_statm  := sprintf('%s and ATTACHED > 0', _sql_statm);
    if (get_keyword ('q_read', _params) = '1')
      _sql_statm  := sprintf ('%s and MSTATUS = 0', _sql_statm);

    tmp := get_keyword ('q_after', _params);
    tmp := OMAIL.WA.test (tmp, vector ('name', 'Received after', 'type', 'date', 'canEmpty', 1));
    if (not is_empty_or_null (tmp))
    {
      _sql_statm  := sprintf('%s and RCV_DATE > ?',_sql_statm);
      _sql_params := vector_concat(_sql_params, vector(tmp)); --stringdate(
    }
    tmp := get_keyword ('q_before', _params);
    tmp := OMAIL.WA.test (tmp, vector ('name', 'Received before', 'type', 'date', 'canEmpty', 1));
    if (not is_empty_or_null (tmp))
    {
      _sql_statm  := sprintf('%s and RCV_DATE < ?',_sql_statm);
      _sql_params := vector_concat(_sql_params, vector(tmp));
    }

    _aquery := '';
    tmp := OMAIL.WA.email_search_str(get_keyword ('q_from', _params, ''));
    if ((tmp = '') and (get_keyword('q_from', _params, '') <> ''))
      signal ('TEST', 'Field ''From'' contains invalid characters!<>');

    if (tmp <> '')
      _aquery := sprintf('%s and //from[text-contains(.,"%s")]', _aquery, tmp);

    tmp := OMAIL.WA.email_search_str (get_keyword ('q_to', _params, ''));
    if ((tmp = '') and (get_keyword('q_to', _params, '') <> ''))
      signal ('TEST', 'Field ''To'' contains invalid characters!<>');
    if (tmp <> '')
      _aquery := sprintf('%s and //to[text-contains(.,"%s")]', _aquery, tmp);

    if (_aquery <> '')
    {
      _sql_statm  := sprintf('%s and XCONTAINS(ADDRESS,?) ',_sql_statm);
      _sql_params := vector_concat(_sql_params,vector(substring(_aquery,5,length(_aquery))));
    }

    if (get_keyword ('q_subject',_params,'') <> '')
    {
      _sql_statm  := sprintf('%s and ucase(SUBJECT) LIKE ucase(?)',_sql_statm);
      _sql_params := vector_concat(_sql_params,vector(concat('%',get_keyword('q_subject',_params,''),'%')));
    }

    _aquery := '';
    OMAIL.WA.test(get_keyword('q_body', _params, ''), vector('name', 'Body', 'class', 'free-text'));
    tmp := FTI_MAKE_SEARCH_STRING(get_keyword('q_body', _params, ''));
    if (is_empty_or_null(tmp) and (get_keyword('q_body', _params, '') <> ''))
      signal ('TEST', 'Field ''Body'' contains invalid characters!<>');
    if (tmp <> '')
      _aquery := sprintf('%s and %s', _aquery, tmp);

    OMAIL.WA.test(get_keyword('q_tags', _params, ''), vector ('name', 'Tags', 'class', 'tags', 'message', 'One of the tags is too short or contains bad characters or is a noise word!'));
    tmp := OMAIL.WA.tags2search(get_keyword('q_tags', _params, ''));
    if (tmp <> '')
      _aquery := sprintf('%s and %s', _aquery, tmp);

    if (_aquery <> '')
    {
      _sql_statm  := sprintf ('%s and CONTAINS (P.TDATA, ?)', _sql_statm);
      _sql_params := vector_concat(_sql_params,vector(substring(_aquery,5,length(_aquery))));
    }
    if (_sql = _sql_statm)
      _empty := 1;
    tmp := OMAIL.WA.test(get_keyword('q_max', _params, '100'), vector('name', 'Max results', 'class', 'integer', 'minValue', 1, 'maxValue', 1000));
    _sql_statm := replace(_sql_statm, '<MAX>', 'TOP '||cast(tmp as varchar));
  }
  else
  {
    ----------------------------------------------------------------------------
    -- sample search

    _sql_statm := concat (' select distinct M.SUBJECT, \n',
                         '        M.ATTACHED, \n',
                         '        cast(M.ADDRESS as varchar) ADDRESS, \n',
                         '        M.DSIZE DSIZE, \n',
                         '        M.MSG_ID, \n',
                         '        M.MSTATUS, \n',
                         '        M.PRIORITY, \n',
                         '        M.RCV_DATE, \n',
                         '        OMAIL.WA.omail_groupBy (M.DOMAIN_ID, M.USER_ID, M.MSG_ID, \'%s\', M.%s) GROUP_BY, \n',
                         '        OMAIL.WA.omail_groupBy_show (M.DOMAIN_ID, M.USER_ID, M.MSG_ID, \'%s\', M.%s) GROUP_SHOW \n',
                         '   from OMAIL.WA.MESSAGES M \n',
                         '  where M.DOMAIN_ID = ? \n',
                         '    and M.USER_ID = ? \n');
    _sql_statm  := sprintf (_sql_statm, _group[_groupIndex], _group[_groupIndex], _group[_groupIndex], _group[_groupIndex]);
    _sql := _sql_statm;

    _aquery := '';
    tmp := OMAIL.WA.email_search_str(get_keyword ('q', _params, ''));
    if (tmp <> '') {
      _aquery := sprintf('and //*[text-contains(.,"%s")]', tmp);

      _sql_statm  := sprintf('%s and XCONTAINS(ADDRESS,?) \n',_sql_statm);
      _sql_params := vector_concat(_sql_params, vector(substring(_aquery,5,length(_aquery))));
    }
    if (_sql = _sql_statm)
      _empty := 1;
  }
  tmp := '';
  if (_order[_orderIndex] <> '')
    tmp := sprintf ('%s %s, ', _order[_orderIndex], _direction[_directionIndex]);
  _sql_statm := sprintf (_sql_statm || ' ORDER BY GROUP_BY %s, %s RCV_DATE desc', _groupDirection, tmp);

  if (not _exec)
    return vector(_sql_statm, _sql_params);
  if (_empty)
    return sprintf('<skiped>0</skiped><show_res>%d</show_res><all_res>0</all_res>', get_keyword('aresults', _params,10));
  return OMAIL.WA.omail_sql_exec(_domain_id, _user_id, _sql_statm, _sql_params, get_keyword('skiped',_params,0), get_keyword('aresults',_params,10), concat(cast(get_keyword('order',_params,'5') as varchar), cast(get_keyword('direction',_params,'0') as varchar)), cast(get_keyword('q_cloud',_params,'0') as integer));
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_open(
  inout path any,
  inout lines any,
  inout params any)
{
  return OMAIL.WA.omail_message(path,lines,params);
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_open_message(
  in    _domain_id  integer,
  in    _user_id    integer,
  inout _params     any,
  in    _part_id    integer,
  in    _html_parse integer)
{
  declare _rs, _body, _re_msg, _address, _reAddress, _mime_list, _from, _to, _cc, _replyTo, _displayName, _addContact, _sid, _realm, _dload_url, _encoding varchar;
  declare _msg_id, _type_id, _ab_id, N, _error integer;
  declare _fields,_settings any;

  _rs        := '';
  _sid       := get_keyword('sid',_params,'');
  _realm     := get_keyword('realm',_params,'');
  _dload_url := sprintf('dload.vsp?sid=%s&realm=%s&dp=%s',_sid,_realm,'%d,%d');

  if (OMAIL.WA.omail_getp ('re_mode', _params) in (1, 2))
  {
    -- user make reply msg (1 - reply; 2 - reply to all)
    --
    _fields := OMAIL.WA.omail_get_message(_domain_id, _user_id, OMAIL.WA.omail_getp('re_msg_id', _params), 1);
    if (length(_fields) = 0)
      return _rs;

    _body := OMAIL.WA.omail_getp('message',_fields);
    _encoding := OMAIL.WA.omail_get_encoding(OMAIL.WA.omail_getp('aparams',_fields));
    OMAIL.WA.utl_decode_qp(_body,_encoding);
    OMAIL.WA.omail_open_message_body_ind(_body); -- indent message text with '>'

    _from := OMAIL.WA.omail_address2str('from', get_keyword('address',_fields, ''), 3);
    _to := OMAIL.WA.omail_address2str('to', get_keyword('address', _fields, ''), 3);
    _cc := OMAIL.WA.omail_address2str('cc', get_keyword('address', _fields, ''), 3);
    _reAddress := OMAIL.WA.omail_address2xml('from', _from, 0) ||
                  OMAIL.WA.omail_address2xml('to', _to, 0) ||
                  OMAIL.WA.omail_address2xml('cc', _cc, 0);
    if (OMAIL.WA.omail_getp ('re_mode',_params) = 1)
    {
      -- get TO or Reply-To
      if (trim(mail_header(get_keyword('header', _fields, ''), 'Reply-To')) <> '')
        _address := OMAIL.WA.omail_address2xml('to', trim(mail_header(get_keyword ('header', _fields, ''), 'Reply-To')), 0);
      else
        _address := OMAIL.WA.omail_address2xml('to', _from, 0); -- from -> to
    } else if (OMAIL.WA.omail_getp('re_mode',_params) = 2) {
      -- get FROM, TO, CC and BCC field
      _address := OMAIL.WA.omail_replyAddress(_user_id, get_keyword('address', _fields, ''));
    }
    _rs := sprintf('%s<re_mode>%d</re_mode>\n' , _rs, OMAIL.WA.omail_getp('re_mode',_params));
    _rs := sprintf ('%s<ref_id>%s</ref_id>\n', _rs, trim (OMAIL.WA.omail_getp ('ref_id', _fields) || ' ' || OMAIL.WA.omail_getp ('srv_msg_id', _fields)));
    _rs := sprintf('%s<address>\n', _rs);
    _rs := sprintf('%s<addres_list>%s</addres_list>\n' , _rs, _address);
    _rs := sprintf('%s</address>\n', _rs);
    _rs := sprintf('%s<subject>Re: %s</subject>\n', _rs, OMAIL.WA.omail_getp('subject',_fields));
    _rs := sprintf('%s<dsize>%d</dsize>\n' ,_rs,OMAIL.WA.omail_getp('dsize',_fields));
    _rs := sprintf('%s<type_id>%d</type_id>\n' ,_rs,OMAIL.WA.omail_getp('type_id',_fields));
    _rs := sprintf('%s<mbody>\n' ,_rs);
    _rs := sprintf('%s <title>----- Original Message -----</title>\n',_rs);
    _rs := sprintf('%s <mtext><![CDATA[%s]]></mtext>\n' ,_rs, _body);
    _rs := sprintf('%s<address>\n', _rs);
    _rs := sprintf('%s<addres_list>%s</addres_list>\n' , _rs, _reAddress);
    _rs := sprintf('%s</address>\n' ,_rs);
    _rs := sprintf('%s<subject>%s</subject>\n', _rs, OMAIL.WA.omail_getp('subject', _fields));
    _rs := sprintf('%s <rcv_date>%s</rcv_date>\n' ,_rs, OMAIL.WA.dt_format(OMAIL.WA.omail_getp('rcv_date',_fields), 'Y-M-D H:N:S'));
    _rs := sprintf('%s</mbody>\n' ,_rs);

    OMAIL.WA.omail_setparam('re_mode',_params,0);
    OMAIL.WA.omail_setparam('re_msg_id',_params,0);

  }
  else if (OMAIL.WA.omail_getp ('re_mode',_params) = 3)
  {
    -- user make forward msg
    --
    -- get message
    --
    _fields := OMAIL.WA.omail_get_message(_domain_id,_user_id,OMAIL.WA.omail_getp('re_msg_id',_params),1);
    if (length(_fields) = 0)
      return _rs;

    _body := OMAIL.WA.omail_getp('message',_fields);
    OMAIL.WA.omail_open_message_body_ind(_body);-- indent message text with '>'

    if (OMAIL.WA.omail_getp ('attached',_fields) > 0)
    {
      OMAIL.WA.omail_setparam('folder_id',_fields,130);
      _msg_id := OMAIL.WA.omail_save_msg(_domain_id,_user_id,_fields,0,_error);
      OMAIL.WA.omail_attachments_copy(_domain_id,_user_id,_msg_id,OMAIL.WA.omail_getp('re_msg_id',_params));
      OMAIL.WA.omail_setparam('msg_id',_params,_msg_id);
      _rs := sprintf('%s<msg_id>%d</msg_id>',_rs,OMAIL.WA.omail_getp('msg_id',_fields));
      _rs := sprintf('%s<attached>%d</attached>',_rs,OMAIL.WA.omail_getp('attached',_fields));
    }

    _from := OMAIL.WA.omail_address2str('from', get_keyword('address',_fields, ''), 3);
    _to   := OMAIL.WA.omail_address2str('to', get_keyword('address', _fields, ''), 3);
    _cc   := OMAIL.WA.omail_address2str('cc', get_keyword('address', _fields, ''), 3);
    _reAddress := OMAIL.WA.omail_address2xml('from', _from, 0) ||
                  OMAIL.WA.omail_address2xml('to', _to, 0) ||
                  OMAIL.WA.omail_address2xml('cc', _cc, 0);

    _rs := sprintf('%s<re_mode>%d</re_mode>' ,_rs,OMAIL.WA.omail_getp('re_mode',_params));
    _rs := sprintf('%s<subject>Fw: %s</subject>' ,_rs,OMAIL.WA.omail_getp('subject',_fields));
    _rs := sprintf('%s<dsize>%d</dsize>' ,_rs,OMAIL.WA.omail_getp('dsize',_fields));
    _rs := sprintf('%s<type_id>%d</type_id>' ,_rs,OMAIL.WA.omail_getp('type_id',_fields));
    _rs := sprintf('%s<mbody>' ,_rs);
    _rs := sprintf('%s <title>----- Original Message -----</title>', _rs);
    _rs := sprintf('%s <mtext><![CDATA[%s]]></mtext>', _rs, _body);
    _rs := sprintf('%s<address>\n' ,_rs);
    _rs := sprintf('%s<addres_list>%s</addres_list>\n' , _rs, _reAddress);
    _rs := sprintf('%s</address>\n' ,_rs);
    _rs := sprintf('%s<subject>%s</subject>\n', _rs, OMAIL.WA.omail_getp('subject', _fields));
    _rs := sprintf('%s <rcv_date>%s</rcv_date>', _rs, OMAIL.WA.dt_format(OMAIL.WA.omail_getp('rcv_date',_fields), 'Y-M-D H:N:S'));
    _rs := sprintf('%s</mbody>',_rs);

    OMAIL.WA.omail_setparam('re_mode',_params,0);
    OMAIL.WA.omail_setparam('re_msg_id',_params,0);
  }
  else
  {
    -- User Opening Message
    --
    _type_id := 10110; -- default MIME-TYPE

    if (OMAIL.WA.omail_getp('mime_type',_params) <> 0)
      _type_id := OMAIL.WA.omail_getp('mime_type',_params);

    _mime_list := OMAIL.WA.omail_get_def_message(_domain_id,_user_id,OMAIL.WA.omail_getp('msg_id',_params),_type_id,_part_id);
    _fields    := OMAIL.WA.omail_get_message(_domain_id,_user_id,OMAIL.WA.omail_getp('msg_id',_params),_part_id);
    if (length(_fields) = 0)
      return '';
    _type_id   := OMAIL.WA.omail_getp('type_id',_fields);

    -- Decode Message Body
    _body := OMAIL.WA.omail_getp('message',_fields);

    OMAIL.WA.utl_decode_qp(_body,OMAIL.WA.omail_get_encoding(OMAIL.WA.omail_getp('aparams',_fields),''));
    OMAIL.WA.omail_open_message_images(_domain_id,_user_id,OMAIL.WA.omail_getp('msg_id',_params),20000,_dload_url,_body); -- 20000 -> images
    OMAIL.WA.omail_setparam('folder_id',_params,OMAIL.WA.omail_getp('folder_id',_fields));

    -- Get Settings
    _settings := OMAIL.WA.omail_get_settings(_domain_id, _user_id, 'base_settings');

    _replyTo := trim(get_keyword('msg_reply',_settings,''));
    if (is_empty_or_null(_replyTo))
      _replyTo := OMAIL.WA.omail_address2str('from', OMAIL.WA.omail_getp('address',_fields), 3);

    _displayName := '';
    if (get_keyword('msg_name',_settings, 0))
      _displayName := trim(get_keyword('msg_name_txt',_settings,''));
    if (_displayName = '')
      _displayName := coalesce((select U_FULL_NAME from DB.DBA.SYS_USERS where U_ID = _user_id), '');

    _addContact := '';
    if (_domain_id = 1)
    {
    _ab_id := OMAIL.WA.check_app (_user_id, 'AddressBook');
    if (_ab_id <> 0)
        _addContact := AB.WA.forum_iri (_ab_id);
    }
    _rs := sprintf ('%s<msg_id>%d</msg_id>\n', _rs, get_keyword ('msg_id', _fields));
    _rs := sprintf ('%s<ref_id>%s</ref_id>\n', _rs, get_keyword ('ref_id', _fields));
    _rs := sprintf('%s<parent_id>%d</parent_id>\n', _rs, get_keyword('parent_id',_fields));
    _rs := sprintf ('%s<subject><![CDATA[%s]]></subject>\n' , _rs, get_keyword ('subject', _fields));
    _rs := sprintf ('%s<type_id>%d</type_id>\n', _rs, get_keyword ('type_id', _fields));
    _rs := sprintf ('%s<folder_id>%d</folder_id>\n', _rs, get_keyword ('folder_id', _fields));
    _rs := sprintf ('%s<mstatus>%d</mstatus>\n', _rs, get_keyword ('mstatus', _fields));
    _rs := sprintf ('%s<attached>%d</attached>\n', _rs, get_keyword ('attached', _fields));
    _rs := sprintf ('%s<priority>%d</priority>\n', _rs, get_keyword ('priority', _fields));
    _rs := sprintf ('%s<dsize>%d</dsize>\n', _rs, get_keyword ('dsize', _fields));
    _rs := sprintf ('%s<tags>%s</tags>\n', _rs, get_keyword ('tags', _fields));
    _rs := sprintf('%s<mime_list>%s</mime_list>\n', _rs, _mime_list);
    _rs := sprintf ('%s<rcv_date>%s</rcv_date>\n', _rs, cast(get_keyword ('rcv_date', _fields) as varchar));
    _rs := sprintf ('%s<to_snd_date>%s</to_snd_date>\n', _rs, OMAIL.WA.dt_rfc822 (get_keyword ('rcv_date', _fields, '')));
    _rs := sprintf ('%s<address>%s</address>\n', _rs, get_keyword ('address', _fields));
    _rs := sprintf ('%s<mheader><![CDATA[%s]]></mheader>\n', _rs, coalesce(get_keyword ('header', _fields), ''));
    _rs := sprintf('%s<replyTo><![CDATA[%s]]></replyTo>\n', _rs, _replyTo);
    _rs := sprintf('%s<displayName><![CDATA[%s]]></displayName>\n', _rs, _displayName);
    _rs := sprintf ('%s<addContact>%s</addContact>\n', _rs, OMAIL.WA.xml2string (_addContact));
    _rs := sprintf ('%s%s\n', _rs, get_keyword ('options', _fields));

    if ((_type_id = 10110) and (OMAIL.WA.omail_getp ('_html_parse',_params) <> 0))
    {
      -- html version
      _body := xml_tree (_body, 2, '', 'UTF8');
      if (not isarray(_body))
        signal('9001', 'open_message error');
      _body := xml_tree_doc(_body);

      -- XQUERY --------------------------------------------------------------
      xml_tree_doc_set_output (_body,'xhtml');
      _body := OMAIL.WA.xml2string (_body);

    } else {
      _body := replace(_body,']]>',']]>]]<![CDATA[>');
      _body := sprintf('<mtext><![CDATA[%s]]></mtext>\n',_body);
    }
    _rs := sprintf('%s<mbody>%s</mbody>\n',_rs,_body);
  }
  return _rs;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_open_message_body(
  in    _user_id integer,
  inout _body    varchar,
  in    _params  any,
  in    _type_id integer)
{
  declare _rs,_re_head varchar;
  declare _body_lines any;
  declare N integer;
  _rs := '';
  _re_head := '';

  _body := cast(_body as varchar);
  if (OMAIL.WA.omail_getp ('re_mode',_params) = 1)
  { -- user make reply msg
    _re_head := sprintf('%s\n\n\n----- Original Message ----- \n',_re_head);
    _re_head := sprintf('%sFrom: \n',_re_head);
    _re_head := sprintf('%sTo: \n',_re_head);
    _re_head := sprintf('%sSent:: \n',_re_head);
    _re_head := sprintf('%sSubject: \n',_re_head);
    _body_lines := split_and_decode(_body,0,'\0\r\n');
    N := 0;
    _body := '';
    while (N < length (_body_lines))
    {
      _body := sprintf('%s\n&lt; %s',_body,aref(_body_lines,N));
      N := N + 1;
    }
  } else {
    open_message_images(_user_id,OMAIL.WA.omail_getp('_msg_id',_params),499,'dload.vsp?dp=%d,%d',_body);
  };

  _rs := sprintf ('%s<mbody><![CDATA[%s]]></mbody>',_rs, _re_head || _body);
 return _rs;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_open_message_body_ind(inout _body varchar)
{
  declare _body_lines varchar;
  declare N integer;

  _body_lines := split_and_decode(_body,0,'\0\r\n');
  _body := '';
  for (N := 0; N < length(_body_lines); N := N + 1)
    _body := sprintf('%s\n> %s', _body, _body_lines[N]); -- indent re-text whit '>'
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_open_message_full(
  in    _domain_id  integer,
  in    _user_id    integer,
  in    _msg_id     any)
{
  declare _boundary,_b,_e,_rs,mstatus,attached,address,mheader,N,_hh any;

  mheader := coalesce( (select MHEADER from OMAIL.WA.MESSAGES where DOMAIN_ID = _domain_id and USER_ID = _user_id and MSG_ID =_msg_id), '');
      _b := locate('boundary="',mheader,1);
  if (_b > 0)
  {
        _e := locate('"',mheader,_b+10);
        _boundary := sprintf('<boundary>%s</boundary>\n',subseq(mheader,_b+9,_e-1));
      } else {
        _boundary := '';
  }

      -- decode message body
  N := 0;
  _rs := '';
  _hh := sprintf ('<mheader><![CDATA[%s]]></mheader>\n%s\n', mheader, _boundary);
  for (select TDATA, BDATA, APARAMS
             from OMAIL.WA.MSG_PARTS
        where DOMAIN_ID = _domain_id and USER_ID = _user_id and MSG_ID = _msg_id and PDEFAULT = 1) do
  {
          _rs := sprintf('%s<mbody>\n',_rs);
          _rs := sprintf('%s<aparams>%s</aparams>\n',_rs,coalesce(APARAMS,''));
          _rs := sprintf('%s<mtext><![CDATA[%s]]></mtext>\n',_rs,coalesce(TDATA,BDATA));
          _rs := sprintf('%s</mbody>\n',_rs);
          N := N + 1;
  }

  if (N > 1)
  {
         _hh := sprintf('%s<alternative>\n',_hh);
         _hh := sprintf ('%s<boundary2>%s</boundary2>\n', _hh,sprintf ('------2_NextPart_%s',md5 (concat (cast (now() as varchar), 'xx'))));
         _hh := sprintf('%s%s',_hh,_rs);
         _hh := sprintf('%s</alternative>\n',_hh);

      } else {
         _hh := sprintf('%s%s',_hh,_rs);
  }
  return _hh || OMAIL.WA.omail_select_attachment(_domain_id, _user_id, _msg_id, 1);
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_open_message_images(
  in    _domain_id  integer,
  in    _user_id    integer,
  in    _msg_id     integer,
  in    _type_id    integer,
  in    _url        varchar,
  inout _body       varchar)
{
  for(select MSG_ID,PART_ID,CONTENT_ID
        from OMAIL.WA.MSG_PARTS
        where DOMAIN_ID = _domain_id and USER_ID = _user_id and MSG_ID = _msg_id and TYPE_ID >= _type_id and TYPE_ID < (_type_id + 10000) and CONTENT_ID IS NOT NULL) do
  {
    _body := replace(_body,concat('cid:',CONTENT_ID),sprintf(_url,MSG_ID,PART_ID));
  }
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_page_params(
  in _params any)
{
  declare _rs varchar;
  declare N integer;
  declare _cell any;

  _rs :='';
  if (isarray (_params))
  {
    for (N :=0; N < length (_params); N := N + 1)
    {
      _cell := _params[N];
    if (isarray(_cell))
        _rs := sprintf ('%s<%s>%s</%s>\n', _rs, _cell[0], cast (_cell[1] as varchar), _cell[0]);
   }
  }
  return _rs;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_params2str(
  in _names      varchar,
  in _params     any,
  in _separator varchar)
{
  declare _string, _names_arr any;
  declare N integer;

  _string := '';
  _names_arr  := split_and_decode(_names,0,concat('\0\0',_separator));
  for (N := 0; N < length (_names_arr); N := N + 1)
    _string := sprintf ('%s,%d',_string, get_keyword(_names_arr[N], _params, ''));

  return substring(_string,2,length(_string));
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_preview(
  inout path any,
  inout lines any,
  inout params any)
{
  -- www procedure

  -- master error handler

  declare _rs,_sid,_realm,_wp,_sql_result1,_sql_result2,_faction,_pnames varchar;
  declare _params,_page_params,_xslt_url any;
  declare _sql_statm,_sql_params,_user_info any;
  declare N,_len,_user_id,_folder_id,_error,_msg_id,_domain_id integer;

  _sid       := get_keyword('sid',params,'');
  _realm     := get_keyword('realm',params,'');
  _user_info := get_keyword('user_info',params);

  -- TEMP constants -------------------------------------------------------------------
  _user_id   := get_keyword('user_id',_user_info);
  _domain_id := 1;

  -- Set constants  -------------------------------------------------------------------
  _xslt_url := vector('EML','write.xsl','common.xsl');
  _sql_params  := vector(0,0,0,0,0,0);
  _page_params := vector(0,0,0,0,0,0,0,0,0,0,0,0);
  _sql_result1 := '';
  _sql_result2 := '';

  -- Set Variable--------------------------------------------------------------------
  _faction     := get_keyword('fa',params,''); -- mmtf -> "move msg to folder"

  -- Set Arrays----------------------------------------------------------------------
  _pnames := 'msg_id,preview';
  _params := OMAIL.WA.omail_str2params(_pnames,get_keyword('wp',params,'100,0,0,0'),',');

  -- SQL Statement-------------------------------------------------------------------
  if (OMAIL.WA.omail_getp ('msg_id',_params) <> 0)
  {
    _sql_result1 := sprintf('%s',OMAIL.WA.omail_open_message(_domain_id,_user_id,OMAIL.WA.omail_getp('msg_id',_params),1,1));
    _sql_result2 := sprintf('%s',OMAIL.WA.omail_select_attachment(_domain_id,_user_id,OMAIL.WA.omail_getp('msg_id',_params),0));
    if (length (_sql_result1) = 0)
    {
      OMAIL.WA.utl_redirect(sprintf('write.vsp?sid=%s&realm=%s&wp=%d',_sid,_realm,0));
      return;
    }
  }

  -- XML structure-------------------------------------------------------------------
  return '<message>' || _sql_result1 || '</message>';
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_print(
  inout path any,
  inout lines any,
  inout params any)
{
  -- www procedure

  declare _rs,_sid,_realm,_sql_result1,_sql_result3,_pnames varchar;
  declare _params,_page_params any;
  declare _user_info,_settings any;
  declare _user_id,_domain_id integer;

  _sid       := get_keyword('sid',params,'');
  _realm     := get_keyword('realm',params,'');
  _user_info := get_keyword('user_info',params);

  -- TEMP constants -----------------------------
  _user_id   := get_keyword('user_id',_user_info);
  _domain_id := 1;

  -- GET SETTINGS ------------------------------
  _settings := OMAIL.WA.omail_get_settings(_domain_id,_user_id,'base_settings');

  -- Set constants  -------------------------------------------------------------------
  _page_params := vector(0,0,0,0,0,0,0,0,0,0,0,0);

  -- Set Params --------------------------------------------------------------------
  _pnames := 'msg_id,list_pos,mime_type';
  _params := OMAIL.WA.omail_str2params(_pnames,get_keyword('pp',params,'0,0,0'),',');

  OMAIL.WA.omail_setparam('sid',_params,_sid);
  OMAIL.WA.omail_setparam('realm',_params,_realm);

  -- SQL Statement-------------------------------------------------------------------
  _sql_result1 := OMAIL.WA.omail_open_message (_domain_id, _user_id, _params, 1, 1);
  _sql_result3 := OMAIL.WA.omail_select_attachment (_domain_id, _user_id, OMAIL.WA.omail_getp ('msg_id', _params), 0);

  -- Page Params---------------------------------------------------------------------
  aset(_page_params,0,vector('sid',_sid));
  aset(_page_params,1,vector('realm',_realm));
  aset(_page_params,2,vector('op',OMAIL.WA.omail_params2str(_pnames,_params,',')));
  aset(_page_params,3,vector('list_pos',OMAIL.WA.omail_getp('list_pos',_params)));
  aset(_page_params,4,vector('user_info',OMAIL.WA.array2xml(_user_info)));

  -- XML structure-------------------------------------------------------------------
  _rs := OMAIL.WA.omail_page_params (_page_params) || '<message>' || _sql_result1 || '</message>' || _sql_result3;
  return _rs;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.spam_clean_schedule ()
{
  declare _days integer;
  declare _now datetime;

  _now := now ();
  for (select DOMAIN_ID as _domain_id, USER_ID as _user_id, deserialize (SVALUES) as _settings from OMAIL.WA.SETTINGS where SNAME = 'base_settings') do
  {
    _days := cast (get_keyword ('spam_msg_clean', _settings, '0') as integer);
    if (_days > 0)
    {
      for (select MSG_ID as _msg_id from OMAIL.WA.MESSAGES
            where DOMAIN_ID = _domain_id
              and USER_ID = _user_id
              and FOLDER_ID = 125
              and RCV_DATE < dateadd ('day', -_days, _now)) do
      {
        OMAIL.WA.message_erase (_domain_id, _user_id, _msg_id);
      }
    }
  }
  return 0;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.is_spam (
  in _user_id integer,
  in _mail varchar,
  in _level integer := 1)
{
  if (OMAIL.WA.is_spam_int (_user_id, _mail, 'foaf:mbox', _level))
    return OMAIL.WA.is_spam_int (_user_id, _mail, 'foaf:mbox_sha1sum', _level);
  return 0;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.is_spam_int (
  in _user_id integer,
  in _mail varchar,
  in _foafParam varchar,
  in _level integer := 1)
{
  declare N integer;
  declare sql, S, T varchar;
  declare st, msg, meta, rows any;

  S := 'sparql \n' ||
       'PREFIX foaf: <http://xmlns.com/foaf/0.1/> \n' ||
       '   ASK \n' ||
       '  from <%s> \n' ||
       ' WHERE { \n' ||
       '         <%s> foaf:knows %s ?x. \n' ||
       '         ?x <FOAF_PARAM> ?mail. \n' ||
       '         FILTER (?mail = ''%s''). \n' ||
       '       }';
  S := replace (S, '<FOAF_PARAM>', _foafParam);             
  T := '';
  for (N := 0; N < _level; N := N + 1)
  {
    sql := sprintf (S, SIOC..get_graph (), SIOC..person_iri (SIOC..user_iri (_user_id)), T, _mail);
    st := '00000';
    exec (sql, st, msg, vector (), 0, meta, rows);
    if (('00000' = st) and length (rows))
      return 0;
    T := T || sprintf (' ?x%d. ?x%d foaf:knows', N, N);  
  }
  return 1;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.is_spam2 (
  in _user_id integer,
  in _mail varchar)
{
  declare S varchar;
  declare st, msg, meta, rows any;

  S := 'sparql
        PREFIX foaf: <http://xmlns.com/foaf/0.1/>
        select ?mbox, ?mbox_sha1sum
        from <%s>
        WHERE
        {
          <%s> foaf:knows ?x.
          optional { ?x foaf:mbox ?mbox}.
          optional { ?x foaf:mbox_sha1sum ?mbox_sha1sum}.
        }';
	S := sprintf (S, SIOC..get_graph (), SIOC..user_iri (_user_id));
  st := '00000';
  exec (S, st, msg, vector (), 0, meta, rows);
  if ('00000' = st)
    foreach (any row in rows) do {
      if ((not isnull (row[0])) and (not isnull (strstr (row[0], _mail))))
        return 0;
      if ((not isnull (row[1])) and (not isnull (strstr (row[1], _mail))))
        return 0;
    }
  return 1;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_receive_message(
  in    _domain_id   integer,
  in    _user_id     integer,
  in    _parent_id   integer,
  inout _source      any,
  in    _uniq_msg_id integer,
  in    _msg_source  integer, -- ( '-1' ->SMTP; '0' ->inside; '>0' - from POP3 account)
  in    _folder_id   integer,
  in    _mode        integer := 0)
{
  declare _subject, _tags, _from, _returnPath, _to, _cc, _bcc, _srv_msg_id, _ref_id, _mime_type, _protocol, _options, _address, _address_info, _mstatus, _attached, _mheader, _att_fname varchar;
  declare _body, _bodys, _parts, _attrs,_snd_date,_rcv_date,_body_parts,_message,_usern, _settings any;
  declare _body_beg, _body_end,_msg_id,_priority,_dsize,N,_freetext_id integer;

  if (not(isstring(_source)))
    signal('0001','Not a mail msg');

  _message := mime_tree(_source);
  if (not (isarray (_message)) and _mode)
    _message := vector (mime_header (_source), vector (3, 0), 0);

  if (not(isarray(_message)))
    return 0;

  if (not (isarray(_message[0])))
    return 0;

  _attrs := _message[0];
  _bodys := _message[1];
  _parts := _message[2];

  _msg_id        := sequence_next ('OMAIL.WA.omail_seq_eml_msg_id');
  _freetext_id   := sequence_next ('OMAIL.WA.omail_seq_eml_freetext_id');
  _from          := get_keyword_ucase('From',_attrs,'');
  _returnPath    := get_keyword_ucase ('Return-Path',_attrs, '');
  _to            := get_keyword_ucase('To',_attrs,'');
  _cc            := get_keyword_ucase('CC',_attrs,'');
  _bcc           := get_keyword_ucase('BCC',_attrs,'');
  _srv_msg_id    := get_keyword_ucase('Message-ID',_attrs,'');
  _ref_id        := get_keyword_ucase('References',_attrs,'');
  _snd_date      := get_keyword_ucase('Date',_attrs,'');
  _address_info  := OMAIL.WA.omail_address2xml('from',_from,1);
  _mime_type     := get_keyword_ucase('Content-Type', _attrs, '');
  if (_mime_type = '')
    _mime_type := 'text/plain';

  _options       := vector ();
  _mstatus       := 0;
  _attached      := 0;
  _tags          := '';
  _settings      := OMAIL.WA.omail_get_settings (_domain_id, _user_id, 'base_settings');

  -- encrypted
  --
  if (_mime_type = 'application/x-pkcs7-mime')
  {
    declare _decrypted, _keys any;

    _keys := OMAIL.WA.certificate (_domain_id, _user_id);
    _source := smime_decrypt (_source, _keys[0], _keys[1], null);
    _message := mime_tree (_source);
    if (not (isarray (_message)) and _mode)
      _message := vector (mime_header (_source), vector (3, 0), 0);

    if (not (isarray (_message)))
      return 0;

    if (not (isarray(_message[0])))
      return 0;

    _attrs := _message[0];
    _bodys := _message[1];
    _parts := _message[2];
  }
  _mime_type := get_keyword_ucase ('Content-Type', _attrs, '');
  _subject   := OMAIL.WA.utl_decode_field (get_keyword_ucase ('Subject',_attrs,''));

  -- signature
  --
  if (_mime_type = 'multipart/signed')
  {
    if (get_keyword_ucase ('protocol', _attrs, '') in ('application/x-pkcs7-signature', 'application/pkcs7-signature'))
    {
      declare tmp, certificate any;

      certificate := null;
      {
        declare continue handler for SQLSTATE '*'
        {
          _options := vector ();
          goto _1;
        };
        tmp := smime_verify (_source, X509_ROOT_CA_CERTS (), certificate);
  }
      OMAIL.WA.omail_setparam ('ssl', _options, 1);
      if (not isnull (tmp))
        OMAIL.WA.omail_setparam ('sslVerified', _options, 1);

    _1:;
      if (not isnull (certificate))
      {
        declare webID any;

        webID := DB.DBA.FOAF_SSL_WEBID_GET (certificate[0]);
        if (not isnull (webID))
        {
          OMAIL.WA.omail_setparam ('webID', _options, webID);
          if (DB.DBA.FOAF_CHECK_WEBID (webID))
            OMAIL.WA.omail_setparam ('webIDVerified', _options, 1);
        }
      }
    }
  }
  -- spam sender?
  if (cast(get_keyword ('spam', _settings, '0') as integer) > 0)
  {
    if (OMAIL.WA.omail_address2xml ('from', _from, 2) <> OMAIL.WA.omail_address2xml ('to', _to, 2))
    {
      if (OMAIL.WA.omail_address2xml ('from', _from, 2) <> OMAIL.WA.omail_address2xml ('returnPath', _returnPath, 2))
      {
        _folder_id := 125;
      }
      else if (OMAIL.WA.is_spam (_user_id, OMAIL.WA.omail_address2xml ('returnPath', _returnPath, 2), cast (get_keyword ('spam', _settings, '0') as integer)))
      {
          _folder_id := 125;
      }
    }
  }
  -- spam header?
  if (cast (get_keyword ('spam_msg_header', _settings, '0') as integer) = 1)
  {
    -- SpamAssassin - condition="OR (\"X-Spam-Status\",begins with,Yes) OR (\"X-Spam-Flag\",begins with,YES) OR (subject,begins with,***SPAM***)"
    if (_folder_id <> 125)
      if (
          (get_keyword_ucase ('X-Spam-Status', _attrs, '') like 'Yes%') or
          (get_keyword_ucase ('X-Spam-Flag', _attrs, '') like 'YES%') or
          (_subject like '***SPAM***%')
         )
      {
        _folder_id := 125;
      }
    -- SpamPal - X-SpamPal: PASS or : SPAM
    if (_folder_id <> 125)
      if (cast (get_keyword ('spam_msg_header', _settings, '0') as integer) = 2)
      {
        if (get_keyword_ucase ('X-SpamPal', _attrs, '') like 'SPAM%')
        {
          _folder_id := 125;
        }
      }
  }

  if (_folder_id = 125)
    {
    if (cast (get_keyword ('spam_msg_action', _settings, '0') as integer) = 2)
      return 0;

    if (cast (get_keyword ('spam_msg_state', _settings, '0') as integer) <> 0)
      _mstatus := 1;
    }
  if (get_keyword_ucase('X-MSMail-Priority',_attrs,'') <> '')
  {
    OMAIL.WA.omail_get_mm_priority(get_keyword_ucase('X-MSMail-Priority',_attrs,''),_priority);
  } else {
    _priority  := 3;
  }

  _address  := '<addres_list>' ||
              OMAIL.WA.omail_address2xml ('to',   _to,   0) ||
              OMAIL.WA.omail_address2xml ('from', _from, 0) ||
              OMAIL.WA.omail_address2xml ('cc',   _cc,   0) ||
              OMAIL.WA.omail_address2xml ('bcc',  _bcc,  0) ||
              '</addres_list>';

  _rcv_date := now();
  _snd_date := OMAIL.WA.dt_convert (_snd_date);
  _mheader  := subseq (_source, 0, case when (_bodys[0]-3) < 1000 then _bodys[0]-3 else 1000 end);
  _dsize    := length(_source);

  _srv_msg_id := replace(_srv_msg_id,'<','');
  _srv_msg_id := replace(_srv_msg_id,'>','');
  _ref_id     := replace(_ref_id,'<','');
  _ref_id     := replace(_ref_id,'>','');
  _subject    := replace(_subject,'>','&gt;');
  _subject    := replace(_subject,'<','&lt;');

  insert into OMAIL.WA.MESSAGES (FREETEXT_ID, DOMAIN_ID, MSG_ID, USER_ID, ADDRES_INFO, FOLDER_ID, MSTATUS, ATTACHED, ADDRESS, RCV_DATE, SND_DATE, MHEADER, DSIZE, PRIORITY, SUBJECT, SRV_MSG_ID, REF_ID, PARENT_ID, UNIQ_MSG_ID, MSG_SOURCE, M_CONTENT, M_OPTIONS)
    values (_freetext_id,_domain_id,_msg_id,_user_id,_address_info,_folder_id,_mstatus,_attached,_address,_rcv_date,_snd_date,_mheader, _dsize, _priority, _subject,_srv_msg_id, _ref_id, _parent_id, _uniq_msg_id, _msg_source, _source, OMAIL.WA.array2xml(_options, 0, 'options'));

  -- parts
  OMAIL.WA.omail_receive_message_parts (_domain_id, _user_id, _msg_id, _freetext_id, _parent_id, _folder_id, _mime_type, _source, _bodys, _parts);

  OMAIL.WA.omail_update_msg_size (_domain_id,_user_id,_msg_id);
  OMAIL.WA.omail_update_msg_attached (_domain_id,_user_id,_msg_id);
  OMAIL.WA.filter_run_message (_domain_id, _user_id, _msg_id);

  return 1;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_receive_message_parts (
  in  _domain_id   integer,
  in  _user_id     integer,
  in  _msg_id      integer,
  in  _freetext_id integer,
  in  _parent_id   integer,
  in  _folder_id   integer,
  in  _mime_type   varchar,
  in  _source      varchar,
  in  _bodys       any,
  in  _parts       any)
{
  declare _aparams any;
  declare _body, _tags, _fname varchar;
  declare _part_id,_type_id,_pdefault integer;

  _part_id := 1;
  if (isarray(_parts))
  {
    -- mime body
    OMAIL.WA.omail_get_mime_parts (_domain_id, _user_id, _msg_id, _parent_id, _folder_id, _part_id, _source, _parts, 0);
  }
  else
  {
    -- plain text or special body
    _fname     := '';
    _body      := subseq (blob_to_string (_source), _bodys[0], _bodys[1] + 1);
    _type_id   := OMAIL.WA.res_get_mimetype_id(_mime_type);
    _pdefault  := 1;
    if (not _freetext_id)
      _freetext_id := sequence_next ('OMAIL.WA.omail_seq_eml_freetext_id');

    if (_type_id not in (10100, 10110))
    {
      _aparams  := OMAIL.WA.array2xml(vector('content-type','text/plain'));
      insert into OMAIL.WA.MSG_PARTS(DOMAIN_ID,MSG_ID,USER_ID,PART_ID,TYPE_ID,TDATA,DSIZE,APARAMS,PDEFAULT,FREETEXT_ID)
        values (_domain_id,_msg_id,_user_id,_part_id,_type_id,'',0,_aparams,_pdefault,_freetext_id);
      _freetext_id := sequence_next ('OMAIL.WA.omail_seq_eml_freetext_id');
      _pdefault    := 0;
      _part_id     := 10;
      _fname       := subseq(_mime_type,locate('/',_mime_type),length(_mime_type));
    }
    _aparams := OMAIL.WA.array2xml(vector('content-type',_mime_type));
    _tags := OMAIL.WA.tags_rules(_user_id, _body);
    insert into OMAIL.WA.MSG_PARTS(DOMAIN_ID,MSG_ID,USER_ID,PART_ID,TYPE_ID,TDATA,TAGS,DSIZE,APARAMS,PDEFAULT,FREETEXT_ID,FNAME)
      values (_domain_id, _msg_id, _user_id, _part_id, _type_id, _body, _tags, length (_body), _aparams, _pdefault, _freetext_id, _fname);
  }
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_receive_message_imap_body (
  in _domain_id integer,
  in _user_id   integer,
  in _msg_id    integer,
  in _parent_id integer,
  in _folder_id integer,
  in _source_id integer,
  in _unique_id integer)
{
  declare _message, _messages, _mime_type any;
  declare _server, _user, _password, _buffer, _folder, _retCode any;

  if (not OMAIL.WA.external_account_info (_domain_id, _user_id, _source_id, _server, _user, _password))
    return 0;

  _folder := (select DATA from OMAIL.WA.FOLDERS where DOMAIN_ID = _domain_id and USER_ID = _user_id and FOLDER_ID = _folder_id);
  if (isnull (_folder))
    return 0;

  _buffer := 10000000;
  _messages := imap_get (_server, _user, _password, _buffer, 'fetch', _folder, vector (cast (_unique_id as integer)));
  if (length (_messages) = 1)
  {
    _message := mime_tree(_messages[0][1]);
    if (not (isarray(_message)))
      return 0;

    -- parts
    _mime_type := get_keyword_ucase ('Content-Type', _message[0], '');
    delete from OMAIL.WA.MSG_PARTS where DOMAIN_ID = _domain_id and USER_ID = _user_id and MSG_ID = _msg_id;
    OMAIL.WA.omail_receive_message_parts (_domain_id, _user_id, _msg_id, 0, _parent_id, _folder_id, _mime_type, _messages[0][1], _message[1], _message[2]);
  }
  return 1;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_result2xml(
  in _descr    any,
  in _rows      any,
  in _ind      integer,
  in _skipped  integer)
{
  declare _i integer;
  declare _rs,_cell varchar;

  if (_ind < _skipped)
    return '';

  _rs := '<message>';
  for (_i := 0; _i < length (_descr); _i := _i + 1)
  {
    _cell := lower (_descr[_i]);
    _rs   := sprintf ('%s<%s>%V</%s>', _rs, _cell, cast (_rows[_i] as varchar), _cell);
  }
  return _rs || '</message>';
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_save_msg(
  in _domain_id integer,
  in _user_id   integer,
  in _params    any,
  in _msg_id    integer,
  out _error    integer)
{
  declare _address, _subject, _tags, _mheader, _mstatus, _from, _to, _cc, _bcc, _dcc, _address_info, _certificates, _certificate, _mail, _pdata, _aparams, _ref_id varchar;
  declare N, _folder_id, _priority, _dsize, _attached, _part_id, _type_id, _dsize, _pdefault, _freetext_id, _msg_source integer;
  declare _rcv_date, _snd_date any;
  declare _options, _rfc_id, _rfc_references any;

  _error := 0;

  _folder_id  := cast(get_keyword('folder_id',_params, '130') as integer);
  _priority   := cast(get_keyword('priority', _params, '3') as integer);
  _subject    := trim(get_keyword('subject',  _params, ''));
  _ref_id     := get_keyword ('ref_id',_params,'');
  _mheader    := '';
  _rcv_date   := now();
  _snd_date   := now();
  _mstatus    := 5;
  _attached   := 0;
  _pdefault   := 1;
  _msg_source := 0; -- '-1' ->from SMTP; '0' ->inside; '>0' - from POP3 account

  _from := trim (get_keyword ('from',_params, get_keyword ('email', get_keyword ('user_info', _params, ''), '')));
  _to   := trim(get_keyword('to', _params,''));
  _cc   := trim(get_keyword('cc', _params,''));
  _bcc  := trim(get_keyword('bcc', _params,''));
  _dcc  := trim(get_keyword('dcc', _params,''));

  _part_id := 1;
  _type_id := case when (get_keyword ('mt', _params,'') = 'html') then 10110 else 10100 end;
  _pdata   := get_keyword('message',_params,'');
  _dsize   := length(_pdata);
  _aparams := '<params/>';

  _to      := either(length(_to), _to, '~no address~');
  _subject := either(length(_subject), _subject, '~no subject~');
  _tags    := OMAIL.WA.tags_join(OMAIL.WA.tags_rules(_user_id, _pdata), get_keyword('tags', _params, ''));

  if (_dcc <> '')
  {
    declare _dcc_address, _dcc_addresses any;

    _dcc_address := OMAIL.WA.dcc_address(_dcc, _from);
    if (isnull(strstr(_cc, _dcc_address)))
    {
      if (_cc = '')
        _cc := _dcc_address;
      else
        _cc := concat(_cc, ', ', _dcc_address);
    }
    if (_dcc_address <> '')
    {
      _dcc_addresses := '<addres_list>' ||
                        OMAIL.WA.omail_address2xml ('to', _from,0) ||
                        OMAIL.WA.omail_address2xml ('to', _to,  0) ||
                        OMAIL.WA.omail_address2xml ('to', _cc,  0) ||
                        OMAIL.WA.omail_address2xml ('to', _bcc, 0) ||
                        '</addres_list>';
      OMAIL.WA.dcc_update(_dcc_address, _dcc_addresses);
    }
  }

  _address_info := OMAIL.WA.omail_address2xml('to', _to, 1); -- return first name or address
  _address :=  '<addres_list>' ||
               OMAIL.WA.omail_address2xml ('from', _from, 0) ||
               OMAIL.WA.omail_address2xml ('to',   _to,   0) ||
               OMAIL.WA.omail_address2xml ('cc',   _cc,   0) ||
               OMAIL.WA.omail_address2xml ('bcc',  _bcc,  0) ||
               OMAIL.WA.omail_address2xml ('dcc',  _dcc,  0) ||
               '</addres_list>';

  _rfc_id  :=  get_keyword('rfc_id', _params,'');
  _rfc_references := get_keyword('rfc_references', _params,'');

  _options := vector ();

  OMAIL.WA.omail_setparam ('securitySign', _options, get_keyword ('ssign', _params, '0'));
  OMAIL.WA.omail_setparam ('securityEncrypt', _options, get_keyword ('sencrypt', _params, '0'));

  _certificates := vector ();
  for (N := 0; N < length (_params); N := N + 2)
  {
    if (_params[N] like 'modulus_%')
    {
      _mail := replace (_params[N], 'modulus_', '');
      _certificate := vector ('mail', OMAIL.WA.omail_address2xml ('to', _mail, 2), 'modulus', _params[N+1], 'public_exponent', get_keyword ('public_exponent_' || _mail, _params));
      _certificates := vector_concat (_certificates, vector ('certificate', _certificate));
    }
  }
  if (length (_certificates))
    OMAIL.WA.omail_setparam ('certificates', _options, _certificates);

  if (_msg_id = 0)
  {
    _msg_id      := sequence_next ('OMAIL.WA.omail_seq_eml_msg_id');
    _freetext_id := sequence_next ('OMAIL.WA.omail_seq_eml_freetext_id');

    insert into OMAIL.WA.MESSAGES (DOMAIN_ID, MSG_ID, USER_ID, ADDRES_INFO, FOLDER_ID, MSTATUS, ATTACHED, ADDRESS, RCV_DATE, SND_DATE, MHEADER, DSIZE, PRIORITY, SUBJECT, SRV_MSG_ID, REF_ID, FREETEXT_ID, MSG_SOURCE, M_RFC_ID, M_RFC_REFERENCES, M_OPTIONS)
      values (_domain_id, _msg_id, _user_id, _address_info, _folder_id, _mstatus, _attached, _address, _rcv_date, _snd_date, _mheader, _dsize, _priority, _subject, OMAIL.WA.rfc_id(), _ref_id, _freetext_id, _msg_source, _rfc_id, _rfc_references, OMAIL.WA.array2xml(_options, 0, 'options'));

    insert into OMAIL.WA.MSG_PARTS(DOMAIN_ID,MSG_ID,USER_ID,PART_ID,TYPE_ID,TDATA,TAGS,DSIZE,APARAMS,PDEFAULT,FREETEXT_ID)
      values (_domain_id,_msg_id,_user_id,_part_id,_type_id,_pdata,_tags,_dsize,_aparams,_pdefault,_freetext_id);
  }
  else
  {
    update OMAIL.WA.MESSAGES
       set ADDRES_INFO = _address_info,
           FOLDER_ID   = _folder_id,
           ADDRESS     = _address,
           RCV_DATE    = _rcv_date,
           DSIZE       = cast(_dsize as varchar),
           PRIORITY    = _priority,
           SUBJECT     = _subject,
           M_OPTIONS   = OMAIL.WA.array2xml(_options, 0, 'options')
     where DOMAIN_ID   = _domain_id
       and USER_ID     = _user_id
       and MSG_ID      = _msg_id;

    update OMAIL.WA.MSG_PARTS
       set TYPE_ID     = _type_id,
           TDATA       = _pdata,
           DSIZE       = _dsize,
           APARAMS     = _aparams,
           TAGS        = _tags
     where DOMAIN_ID   = _domain_id
       and USER_ID     = _user_id
       and MSG_ID      = _msg_id
       and PART_ID     = 1;
  }
  return _msg_id;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_search(
  inout path any,
  inout lines any,
  inout params any)
{
  -- www procedure

  declare _pageSize, _user_id, _folder_id, _domain_id integer;
  declare _rs, _sid, _realm, _sql_result1, _sql_result2, _pnames varchar;
  declare _order, _direction, _params, _page_params any;
  declare _user_info, _settings any;

  _sid       := get_keyword('sid',params,'');
  _realm     := get_keyword('realm',params,'');
  _user_info := get_keyword('user_info',params);

  -- TEMP constants -------------------------------------------------------------------
  _user_id   := get_keyword('user_id',_user_info);
  _domain_id := 1;
  _pageSize  := 10;

  declare exit handler for SQLSTATE '*'
  {
    if (__SQL_STATE = '1901')
    {
      OMAIL.WA.utl_redirect(sprintf('err.vsp?sid=%s&realm=%s&err=%s',_sid, _realm, __SQL_STATE));
    } else {
      OMAIL.WA.utl_redirect(sprintf('err.vsp?sid=%s&realm=%s&err=%s&msg=%U',_sid, _realm, 'TEST', OMAIL.WA.test_clear(__SQL_MESSAGE)));
    }
    return;
  };

  -- GET SETTINGS ------------------------------
  _settings := OMAIL.WA.omail_get_settings(_domain_id, _user_id, 'base_settings');

  -- Set constants  -------------------------------------------------------------------
  _page_params := vector(0,0,0,0,0,0,0,0,0,0,0,0);
  _sql_result1 := '';

  -- Set Arrays----------------------------------------------------------------------
  _pnames := 'folder_id,skiped,order,direction,folder_view';
  _params := OMAIL.WA.omail_str2params(_pnames,get_keyword('bp',params, ',0,0,0,0'),',');
  if (get_keyword ('search.x',params,'') <> '')
  {
    OMAIL.WA.omail_setparam('order', _params, cast(get_keyword('q_order', params, get_keyword('order', _params)) as integer));
    OMAIL.WA.omail_setparam('direction', _params, cast(get_keyword('q_direction', params, get_keyword('direction', _params)) as integer));
  }

  OMAIL.WA.getOrderDirection (_order, _direction);

  if (OMAIL.WA.omail_getp ('msg_result',_settings) <> '')
  {
    OMAIL.WA.omail_setparam('aresults',_params,OMAIL.WA.omail_getp('msg_result',_settings));
  } else {
    OMAIL.WA.omail_setparam('aresults',_params,10);
  }

  -- Check Params for illegal values---------------------------------------------------
  if (not OMAIL.WA.omail_check_interval(OMAIL.WA.omail_getp ('skiped',_params),0,100000))
  { -- check SKIPED
    OMAIL.WA.utl_redirect(sprintf('%s?sid=%s&realm=%s&err=%d','err.vsp',_sid,_realm,1101));
    return;
  }

  if (not OMAIL.WA.omail_check_interval(OMAIL.WA.omail_getp ('order',_params),1,(length (_order)-1)))
  { -- check ORDER BY
    OMAIL.WA.omail_setparam('order',_params,OMAIL.WA.omail_getp('msg_order',_settings)); -- get from settings
  }
  else if (OMAIL.WA.omail_getp ('order',_params) <> OMAIL.WA.omail_getp ('msg_order',_settings))
  {
    OMAIL.WA.omail_setparam('msg_order',_settings,OMAIL.WA.omail_getp('order',_params)); -- update new value in settings
    OMAIL.WA.omail_setparam('update_flag',_settings,1);
  }

  if (not OMAIL.WA.omail_check_interval(OMAIL.WA.omail_getp ('direction',_params),1,(length (_direction)-1)))
  { -- check ORDER WAY
    OMAIL.WA.omail_setparam('direction',_params,OMAIL.WA.omail_getp('msg_direction',_settings));
  }
  else if (OMAIL.WA.omail_getp ('direction',_params) <> OMAIL.WA.omail_getp ('msg_direction',_settings))
  {
    OMAIL.WA.omail_setparam('msg_direction',_settings,OMAIL.WA.omail_getp('direction',_params));
    OMAIL.WA.omail_setparam('update_flag',_settings,1);
  }

  -- Export URL-------------------------------------------------------------------
  declare tmp varchar;

  tmp := '';
  if (get_keyword ('mode', params, '') = 'advanced')
  {
    tmp := concat(tmp, '&amp;mode=advanced');
    if (get_keyword ('q_fid', params, '0') <> '0')
      tmp := concat(tmp, sprintf ('&amp;fid=%U', get_keyword ('q_fid', params)));
    if (get_keyword ('q_attach', params, '0') = '1')
      tmp := concat(tmp, sprintf ('&amp;attach=%U', get_keyword ('q_attach', params)));
    if (get_keyword ('q_read', params, '0') = '1')
      tmp := concat(tmp, sprintf ('&amp;read=%U', get_keyword ('q_read', params)));
    if (get_keyword ('q_after', params, '') <> '')
      tmp := concat(tmp, sprintf ('&amp;after=%U', get_keyword ('q_after', params, '')));
    if (get_keyword ('q_before', params, '') <> '')
      tmp := concat(tmp, sprintf ('&amp;before=%U', get_keyword ('q_before', params, '')));
    if (get_keyword ('q_from', params, '') <> '')
      tmp := concat(tmp, sprintf ('&amp;from=%U', get_keyword ('q_from', params)));
    if (get_keyword ('q_to', params, '') <> '')
      tmp := concat(tmp, sprintf ('&amp;to=%U', get_keyword ('q_to', params)));
    if (get_keyword ('q_subject', params, '') <> '')
      tmp := concat(tmp, sprintf ('&amp;subject=%U', get_keyword ('q_subject', params)));
    if (get_keyword ('q_body', params, '') <> '')
      tmp := concat(tmp, sprintf ('&amp;body=%U', get_keyword ('q_body', params)));
    if (get_keyword ('q_tags', params, '') <> '')
      tmp := concat(tmp, sprintf ('&amp;tags=%U', get_keyword ('q_tags', params)));
    if (get_keyword ('q_max', params, '') <> '')
      tmp := concat(tmp, sprintf ('&amp;max=%U', get_keyword ('q_max', params)));
    if (get_keyword ('q_cloud', params, '') <> '')
      tmp := concat(tmp, sprintf ('&amp;cloud=%U', get_keyword ('q_cloud', params)));
  }
  else if (get_keyword ('q', params, '0') <> '0')
  {
    tmp := concat(tmp, sprintf ('&amp;q=%U', get_keyword ('q', params, '')));
  }
  if (not is_empty_or_null(get_keyword ('order', params)))
    tmp := concat(tmp, sprintf ('&amp;order=%d', get_keyword ('order', params)));
  if (not is_empty_or_null(get_keyword ('direction', params)))
    tmp := concat(tmp, sprintf ('&amp;direction=%d', get_keyword ('direction', params)));

  -- Form Action---------------------------------------------------------------------
  if (get_keyword ('fa_cancel.x',params,'') <> '')
  {
    OMAIL.WA.utl_doredirect(sprintf ('box.vsp?sid=%s&realm=%s&bp=100', _sid, _realm), get_keyword ('domain_id', _user_info));
    return;
  }
  else if (get_keyword ('fa_save.x', params, '') <> '')
  {
    OMAIL.WA.utl_doredirect(sprintf ('folders.vsp?sid=%s&realm=%s&folder_id=0&smartFlag=S&parent_id=115&%s', _sid, _realm, replace (tmp, '&amp;', '&q_')), get_keyword ('domain_id', _user_info));
    return;
  }
  else if (get_keyword ('fa_move.x', params,'') <> '')
  {
    _rs := OMAIL.WA.messages_move(_domain_id, _user_id, params);
  }
  else if (get_keyword ('fa_delete.x', params,'') <> '')
  {
    OMAIL.WA.messages_delete (_domain_id, _user_id, params);
  }
  else if (get_keyword ('fa_group.x', params, '') <> '')
  {
    OMAIL.WA.omail_setparam ('groupBy', _settings, cast (get_keyword ('fa_group.x', params) as integer));
    OMAIL.WA.omail_setparam ('update_flag', _settings, 1);
  }
  OMAIL.WA.omail_set_settings(_domain_id, _user_id, 'base_settings', _settings);

  if (get_keyword('c_tag', params, '') <> '')
    OMAIL.WA.omail_setparam('q_tags', params, OMAIL.WA.tags_join(get_keyword('q_tags', params, ''), get_keyword('c_tag', params, '')));

  _params := vector_concat(_params, params);
  _sql_result1 := OMAIL.WA.omail_msg_search(_domain_id, _user_id, _params);

  -- Page Params---------------------------------------------------------------------
  aset(_page_params,0,vector('sid', _sid));
  aset(_page_params,1,vector('realm', _realm));
  aset(_page_params,2,vector('mode', get_keyword('mode',params, '')));
  aset(_page_params,3,vector('bp', OMAIL.WA.omail_params2str(_pnames,_params,',')));
  aset(_page_params,4,vector('atom_version', get_keyword('atom_version',_settings,'1.0')));
  aset(_page_params,5,vector('user_info', OMAIL.WA.array2xml(_user_info)));

  -- SQL Statement-------------------------------------------------------------------
  _sql_result2 := OMAIL.WA.folders_list(_domain_id, _user_id);

  -- XML structure-------------------------------------------------------------------
  _rs := '';
  _rs := sprintf('%s%s', _rs, OMAIL.WA.omail_page_params(_page_params));
  _rs := sprintf ('%s<groupBy>%d</groupBy>', _rs, OMAIL.WA.omail_getp ('groupBy', _settings));
  _rs := sprintf('%s<export>%s</export>', _rs, tmp);
  _rs := sprintf('%s<query>' ,_rs);
  _rs := sprintf('%s<q>%s</q>' ,_rs, get_keyword('q', params,''));
  _rs := sprintf('%s<q_step>%s</q_step>', _rs, get_keyword('q_step', params,'0'));
  _rs := sprintf('%s<q_from><![CDATA[%s]]></q_from>',_rs, get_keyword('q_from', params,''));
  _rs := sprintf('%s<q_to><![CDATA[%s]]></q_to>' ,_rs, get_keyword('q_to', params,''));
  _rs := sprintf('%s<q_subject><![CDATA[%s]]></q_subject>' ,_rs, get_keyword('q_subject',   params,''));
  _rs := sprintf('%s<q_body><![CDATA[%s]]></q_body>',_rs, get_keyword('q_body', params,''));
  _rs := sprintf('%s<q_tags><![CDATA[%s]]></q_tags>',_rs, get_keyword('q_tags', params,''));
  _rs := sprintf('%s<q_fid>%s</q_fid>' ,_rs, get_keyword('q_fid',   params,''));
  _rs := sprintf('%s<q_attach>%s</q_attach>' ,_rs, get_keyword('q_attach', params,''));
  _rs := sprintf ('%s<q_read>%s</q_read>', _rs, get_keyword ('q_read', params,''));
  _rs := sprintf ('%s<q_after>%s</q_after>', _rs, get_keyword ('q_after', params, ''));
  _rs := sprintf ('%s<q_before>%s</q_before>', _rs, get_keyword ('q_before',params, ''));
  _rs := sprintf('%s<q_max>%s</q_max>' ,_rs, get_keyword('q_max', params, '100'));
  _rs := sprintf('%s<q_cloud>%s</q_cloud>', _rs, get_keyword('q_cloud', params, '0'));
  _rs := sprintf('%s</query>' ,_rs);
  _rs := sprintf('%s<messages>' ,_rs);
  _rs := sprintf('%s%s' ,_rs, _sql_result1);
  _rs := sprintf('%s</messages>' ,_rs);
  _rs := sprintf('%s%s' ,_rs,_sql_result2);

  return _rs;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_select_attachment(
  in _domain_id integer,
  in _user_id   integer,
  in _msg_id    integer,
  in _mode      integer)
{
  declare _rs,_mime_type,_out,_buff1,_buff2,_encoding varchar;

  _rs := '';
  _buff1 := '';
  _buff2 := '';

  for (select FNAME,CONTENT_ID,PART_ID,DSIZE,TYPE_ID,BDATA,TDATA,APARAMS
         from OMAIL.WA.MSG_PARTS
        where DOMAIN_ID  = _domain_id
          and USER_ID    = _user_id
          and MSG_ID     = _msg_id
          and PDEFAULT   = 0
          and FNAME      <> 'smime.p7s'
        ORDER BY TYPE_ID) do
  {
    OMAIL.WA.omail_get_mimetype_name(TYPE_ID,_mime_type);
    FNAME      := either(isnull(FNAME),'~no name~',FNAME);
    CONTENT_ID := either(isnull(CONTENT_ID),'~no name~',CONTENT_ID);
    _encoding  := OMAIL.WA.omail_get_encoding(APARAMS,'content-transfer-encoding');

    _rs := sprintf('%s<pname>%s</pname>',_rs,replace(FNAME,'&','&amp;'));
    _rs := sprintf('%s<content_id>%s</content_id>',_rs,CONTENT_ID);
    _rs := sprintf('%s<part_id>%d</part_id>',_rs,PART_ID);
    _rs := sprintf('%s<dsize>%d</dsize>',_rs,DSIZE);
    _rs := sprintf('%s<type_id>%d</type_id>',_rs,TYPE_ID);
    _rs := sprintf('%s<mime_type>%s</mime_type>',_rs,_mime_type);
    _rs := sprintf('%s<mime_ext_id>%d</mime_ext_id>',_rs,OMAIL.WA.res_get_mime_ext_id(coalesce(FNAME,'')));

    BDATA := coalesce(BDATA,TDATA);
    if (_mode = 1)
      if (_encoding = 'base64')
      {
        _rs := sprintf('%s<bdata>%s</bdata>', _rs, encode_base64(blob_to_string(BDATA)));
      } else {
        BDATA := replace(blob_to_string(BDATA),']]>',']]>]]<![CDATA[>');
        _rs := sprintf('%s<bdata><![CDATA[%s]]></bdata>',_rs,BDATA);
      }

    if (OMAIL.WA.omail_get_mime_handlers(TYPE_ID,BDATA,APARAMS,_out) and _mode = 0)
      _buff1 := sprintf('%s<attachment_preview>%s%s</attachment_preview>',_buff1,_rs,_out);
    else
      _buff2 := sprintf('%s<attachment>%s</attachment>',_buff2,_rs);
    _rs := '';
  }

  if (length(_buff2) > 0)
    _buff2 := sprintf('<attachments>%s</attachments>',_buff2);

  return concat(_buff1,_buff2);
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_select_attachment_msg(
  in _domain_id integer,
  in _user_id   integer,
  in _msg_id    integer,
  in _mode      integer)
{
  declare _rs varchar;

  _rs := '';
  for(select * from OMAIL.WA.MESSAGES where DOMAIN_ID = _domain_id and USER_ID = _user_id and PARENT_ID = _msg_id ORDER BY MSG_ID) do
  {
    _rs := sprintf('%s<attachment_msg>',_rs);
    _rs := sprintf('%s<msg_id>%d</msg_id>',_rs,MSG_ID);
    _rs := sprintf('%s<subject><![CDATA[%s]]></subject>',_rs,SUBJECT);
    _rs := sprintf('%s<address>%s</address>',_rs,ADDRESS);
    _rs := sprintf('%s<attached>%d</attached>',_rs,ATTACHED);
    _rs := sprintf('%s<rcv_date>%s</rcv_date>', _rs, datestring(RCV_DATE));
    _rs := sprintf('%s<dsize>%d</dsize>',_rs,DSIZE);
    _rs := sprintf('%s<type_id>%d</type_id>',_rs,125);
    _rs := sprintf('%s<mime_type>%s</mime_type>',_rs,'plain/rfc822');
    _rs := sprintf('%s</attachment_msg>',_rs);
  }
  if (length(_rs) > 0)
    return sprintf('<attachments_msg>%s</attachments_msg>',_rs);
  return _rs;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_select_attachment_msg_full(
  in _domain_id integer,
  in _user_id   integer,
  in _msg_id    integer)
{
  declare _rs varchar;

  _rs := '';
  for(select MSG_ID,SUBJECT from OMAIL.WA.MESSAGES where DOMAIN_ID = _domain_id and USER_ID = _user_id and PARENT_ID = _msg_id ORDER BY MSG_ID) do
  {
    _rs := sprintf('%s<attachment_msg>',_rs);
    _rs := sprintf('%s<file_name>%s</file_name>',_rs,SUBJECT);
    _rs := sprintf('%s<message>%s</message>',_rs,OMAIL.WA.omail_open_message_full(_domain_id,_user_id,MSG_ID));
    _rs := sprintf('%s</attachment_msg>',_rs);

  }
  if (length(_rs) > 0)
    return sprintf('<attachments_msg>%s</attachments_msg>',_rs);

  return '';
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_select_exec(
 in _sql  varchar,
 in _params any)
{
  declare _ind,_len integer;
  declare _state, _rs, _msg varchar;
  declare _descr,_rows any;

  _state := '00000';
  exec(_sql, _state, _msg, _params, 1000, _descr, _rows);
  if (_state <> '00000')
    return (sprintf('Error: %s', _state));

  if (isarray(_rows))
  {
  _rs := '';
    _len := length(_rows);
    for (_ind := 0; _ind < _len; _ind := _ind + 1)
      _rs := _rs || OMAIL.WA.omail_select_xml(_descr[0], _rows[_ind]);
    return _rs;
  }
  return '1';
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_select_next_prev(
  in    _domain_id  integer,
  in    _user_id    integer,
  inout _params     any)
{
  declare _sql varchar;
  declare _order, _direction, _sql_params any;

  OMAIL.WA.getOrderDirection (_order, _direction);
  _sql := sprintf ('select MSG_ID from OMAIL.WA.MESSAGES where DOMAIN_ID = ? and USER_ID = ? and FOLDER_ID = ? and PARENT_ID IS NULL ORDER BY %s %s,RCV_DATE desc', _order[OMAIL.WA.omail_getp ('order',_params)], _direction[OMAIL.WA.omail_getp ('direction',_params)]);
  _sql_params := vector(_domain_id, _user_id, OMAIL.WA.omail_getp('folder_id', _params));
  return OMAIL.WA.omail_select_next_prev_exec(_sql,_sql_params,_params);
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_select_next_prev_exec(
 in _sql varchar,
 in _sql_params any,
 in _params any)
{
  declare _state,_rs,_msg varchar;
  declare _ind,_len,_buf integer;
  declare _descr,_rows any;

  _state := '00000';
  exec(_sql, _state, _msg, _sql_params, 1000, _descr, _rows);

  if (_state <> '00000')
    return (sprintf('Error: %s', _state));

  _rs := '';
  _buf := '';
  if (isarray(_rows))
  {
    _len := length(_rows);
    for (_ind := 0; _ind < _len; _ind := _ind + 1)
    {
      if (_rows[_ind][0] = OMAIL.WA.omail_getp ('msg_id',_params))
      {
        _rs := sprintf('%s <prev>%s</prev>',_rs,cast(_buf as varchar));
        if (_ind + 1 < _len)
          _rs := sprintf('%s <next>%d</next>',_rs,aref(aref(_rows,_ind + 1),0));
        return _rs;
      }
      _buf := _rows[_ind][0];
    }
  }
  return _rs;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_select_xml(in _descr any, in _values any)
{
  declare _i integer;
  declare _rs,_cell varchar;
  declare _value any;

  _rs := '';
  for (_i := 0; _i < length (_descr); _i := _i + 1)
  {
    _cell := lower (_descr[_i][0]);
    _value := _values[_i];
    if (isnull (_value))
    {
      if (_descr[_i][1] = 189)
        _value := 0;
              else
        _value := '';
    }
    _value := cast(_value as varchar);
    _value := replace(_value, '&', '&amp;');
    _rs := sprintf('%s<%s>%s</%s>', _rs, _cell, _value, _cell);
        }
  return _rs;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_send_msg(
  in    _domain_id integer,
  in    _user_id   integer,
  inout _params    any,
  in    _msg_id    integer,
  in    _skip      varchar,
  out   _error     integer)
{
  declare _sql_result1, _sql_result2, _xslt_url, _xslt_url2, _xslt_url3, _tmp, _body any;
  declare _sender, _rec, _smtp_server any;
  declare _sid, _realm, _fields, _options, _settings, _signed, _sencrypt, _type_id, _replyTo, _displayName, _dloadUrl any;
  declare exit handler for SQLSTATE '2E000'
  {
    _error := 1901;
    return;
  };
  declare exit handler for SQLSTATE '08006'
  {
    _error := 1902;
    return;
  };

  declare exit handler for SQLSTATE '01903'
  {
    _error := 1903;
    return;
  };

  declare exit handler for SQLSTATE '01904'
  {
    _error := 1904;
    return;
  };

  _error     := 0;
  _xslt_url  := OMAIL.WA.omail_xslt_full('construct_mail.xsl');
  _xslt_url2 := OMAIL.WA.omail_xslt_full('construct_recip.xsl');
  _xslt_url3 := OMAIL.WA.omail_xslt_full ('construct_body.xsl');

  -- Open Message
  --
  _fields    := OMAIL.WA.omail_get_message(_domain_id, _user_id, _msg_id, 1);
  _type_id   := OMAIL.WA.omail_getp ('type_id', _fields);

  _sender := cast (xslt (_xslt_url2, xml_tree_doc (xml_tree (sprintf ('<fr><address>%s</address></fr>', get_keyword ('address', _fields))))) as varchar);
  _rec    := cast (xslt (_xslt_url2, xml_tree_doc (xml_tree (sprintf ('<to><address>%s</address></to>', get_keyword ('address', _fields))))) as varchar);
  if (not isnull (_skip))
  {
    _rec := replace (_rec, sprintf ('<%s>', _skip), '');
    _rec := trim (trim (_rec), ',');
  }
  _rec := trim (_rec);

  -- Get Settings
  _settings := OMAIL.WA.omail_get_settings(_domain_id, _user_id, 'base_settings');

  _replyTo := trim (get_keyword ('msg_reply', _settings, ''));
  if (is_empty_or_null(_replyTo))
    _replyTo := OMAIL.WA.omail_address2str ('from', OMAIL.WA.omail_getp ('address', _fields), 3);

  _displayName := '';
  if (get_keyword ('msg_name', _settings, 0))
  {
    _displayName := trim (get_keyword ('msg_name_txt',_settings, ''));
    if (_displayName = '')
      _displayName := coalesce((select U_FULL_NAME from DB.DBA.SYS_USERS where U_ID = _user_id), '');
  }
  _sql_result1 := sprintf ('<ref_id>%s</ref_id>\n', get_keyword ('ref_id', _fields)) ||
                  sprintf ('<subject><![CDATA[%s]]></subject>\n', get_keyword ('subject', _fields)) ||
                  sprintf ('<priority>%d</priority>\n', get_keyword ('priority', _fields)) ||
                  sprintf ('<to_snd_date>%s</to_snd_date>\n', OMAIL.WA.dt_rfc822 (get_keyword ('rcv_date', _fields, ''))) ||
                  sprintf ('<address>%s</address>\n', get_keyword ('address', _fields)) ||
                  sprintf ('<replyTo><![CDATA[%s]]></replyTo>\n', _replyTo) ||
                  sprintf ('<displayName><![CDATA[%s]]></displayName>\n', _displayName) ||
                  sprintf ('<type_id>%d</type_id>\n', get_keyword ('type_id', _fields));

  -- Decode Message Body
  _body := OMAIL.WA.omail_getp ('message', _fields);

  OMAIL.WA.utl_decode_qp (_body, OMAIL.WA.omail_get_encoding (OMAIL.WA.omail_getp ('aparams', _fields), ''));
  _sid      := get_keyword ('sid',_params,'');
  _realm    := get_keyword ('realm',_params,'');
  _dloadUrl := sprintf ('dload.vsp?sid=%s&realm=%s&dp=%s', _sid, _realm, '%d,%d');
  OMAIL.WA.omail_open_message_images (_domain_id, _user_id, _msg_id, 20000, _dloadUrl, _body); -- 20000 -> images

  _body := replace (_body,']]>',']]>]]<![CDATA[>');
  OMAIL.WA.omail_message_body_parse (_domain_id, _user_id, _msg_id, _body);

  _signed := OMAIL.WA.omail_getp ('ssign', _params);
  if (_signed = '1')
  {
    declare _cert any;

    set_user_id (OMAIL.WA.account_name (_user_id));
    _cert := xenc_pem_export (get_keyword ('security_sign', _settings), 1);
    set_user_id ('dba');
    if (isnull (_cert))
      signal ('01903', '');

    _tmp := '<message>' ||
            sprintf ('<boundary>%s</boundary>', '------_NextPart_' || md5 (cast (now() as varchar))) ||
            sprintf ('<charset>%s</charset>', 'us-ascii') ||
            sprintf ('<srv_msg_id>%s</srv_msg_id>', OMAIL.WA.rfc_id ()) ||
            sprintf ('<type_id>%d</type_id>\n', get_keyword ('type_id', _fields)) ||
            sprintf ('<mbody><mtext><![CDATA[%s]]></mtext></mbody>\n', _body) ||
            OMAIL.WA.omail_select_attachment (_domain_id, _user_id, _msg_id, 1) ||
            '</message>';
    _tmp := xslt (_xslt_url3, xml_tree_doc (xml_tree (_tmp)));
    _tmp := replace (cast (_tmp as varchar), CHR(10), '\r\n');
    _body := smime_sign (_tmp, _cert, _cert, '', vector (), flags=>4*16);

    _sql_result2 := '';
  } else {
  _sql_result2 := OMAIL.WA.omail_select_attachment(_domain_id,_user_id,_msg_id,1);
  }
  _sql_result1 := _sql_result1 || sprintf ('<mbody><mtext><![CDATA[%s]]></mtext></mbody>\n', _body);

  -- XML structure -------------------------------------------------------------
  _body := '<message>' ||
           sprintf ('<boundary>%s</boundary>', '------_NextPart_' || md5 (cast (now() as varchar))) ||
           sprintf ('<charset>%s</charset>', 'us-ascii') ||
           sprintf ('<srv_msg_id>%s</srv_msg_id>', OMAIL.WA.rfc_id ()) ||
           sprintf ('<signed>%s</signed>', _signed) ||
           _sql_result1 ||
           _sql_result2 ||
           '</message>';
  _body := xslt(_xslt_url, xml_tree_doc(xml_tree(_body)));
  _body := replace (cast (_body as varchar), CHR(10), '\r\n');

  _sencrypt := OMAIL.WA.omail_getp ('sencrypt', _params);
  if (_sencrypt = '1')
  {
    declare N integer;
    declare _addr, _addrs, _cert, _certs, _key, _modulus, _modulusBin, _public_exponent  any;

    --_options := OMAIL.WA.omail_getp ('options', _fields);
    --if (not isnull (_options))
    --  _options := xml_tree_doc (xml_tree (_options));

    _certs := vector ();
    _addrs := split_and_decode (_rec, 0, '\0\0,');
    for (N := 0; N < length (_addrs); N := N + 1)
    {
      _addr := OMAIL.WA.omail_address2xml ('to', _addrs[N], 2);
      _cert := OMAIL.WA.contact_certificate (_user_id, _addr);
      if (isnull (_cert))
      {
--        if (not isnull (_options))
--        {
--          _key := xenc_rand_bytes (8, 1);
--          _modulus := cast (xpath_eval (sprintf ('//certificate[mail = "%s"]/modulus', _addr), _options, 1) as varchar);
--          _public_exponent := cast (xpath_eval (sprintf ('//certificate[mail = "%s"]/public_exponent', _addr), _options, 1) as integer);
--          xenc_key_RSA_construct (_key, OMAIL.WA.hex2bin (_modulus),  OMAIL.WA.hex2bin (sprintf ('%02X', _public_exponent)));
--          _cert :=  xenc_pubkey_pem_export (_key);
--        }
--        if (isnull (_cert))
        signal ('01904', '');
      }
      _certs := vector_concat (_certs, vector (_cert));
    }
    _body := smime_encrypt (_body, _certs, 'aes256');
  }
  _smtp_server := cfg_item_value(virtuoso_ini_path(), 'HTTPServer', 'DefaultMailServer');
  smtp_send(_smtp_server, _sender, _rec, _body);

  if (_domain_id = 1)
  {
    if (OMAIL.WA.omail_getp ('scopy', _params) = '1')
    {
      -- move msg to Sent
      update OMAIL.WA.MESSAGES
         set FOLDER_ID = 120
       where DOMAIN_ID = _domain_id
         and USER_ID   = _user_id
         and MSG_ID    = _msg_id;
    } else {
      -- delete msg
      OMAIL.WA.message_erase (_domain_id, _user_id, _msg_id);
    }
  }
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.contact_certificate (
  in _user_id integer,
  in _addr varchar)
{
  declare _cert, webid, domain, host_info, xrd, template, url any;
  declare xt, xd, tmpcert any;

  _cert := null;
  if (__proc_exists ('AB.WA.contact_certificate'))
    _cert := AB.WA.contact_certificate (_user_id, _addr);

  if (is_empty_or_null (_cert))
  {
    declare exit handler for sqlstate '*'
    {
      -- connection error or parse error
      return null;
    };

    domain := subseq (_addr, position ('@', _addr));
    host_info := http_get (sprintf ('http://%s/.well-known/host-meta', domain));
    xd := xtree_doc (host_info);
    template := cast (xpath_eval ('/XRD/Link[@rel="lrdd"]/@template', xd) as varchar);
    url := replace (template, '{uri}', 'acct:' || _addr);
    xrd := http_get (url);
    xd := xtree_doc (xrd);
    xt := xpath_eval ('/XRD/Property[@type="certificate"]/@href', xd, 0);
    foreach (any x in xt) do
    {
      _cert := http_get (cast (x as varchar));
      if ((DB.DBA.FOAF_SSL_MAIL_GET (_cert) = _addr))
        return _cert;
    }
  }
  else
  {
    if ((DB.DBA.FOAF_SSL_MAIL_GET (_cert) = _addr))
      return _cert;
  }
  return null;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_sendok(
  inout path any,
  inout lines any,
  inout params any)
{
  -- www procedure

  declare _domain_id, _user_id integer;
  declare _rs, _sid, _realm, _pnames, _to varchar;
  declare _user_info, _params, _page_params any;

  _sid       := get_keyword('sid',params,'');
  _realm     := get_keyword('realm',params,'');
  _user_info := get_keyword('user_info',params);

  _user_id   := get_keyword('user_id',_user_info);
  _domain_id := 1;

  _to        := get_keyword('to',params, '');

  -- Set constants  -------------------------------------------------------------------
  _page_params := vector(0,0,0,0,0,0,0,0,0,0,0,0);

  -- Set Arrays----------------------------------------------------------------------
  _pnames := 'msg_id';
  _params := OMAIL.WA.omail_str2params(_pnames, get_keyword('sp',params,'0,0,0,0'),',');

  -- Page Params---------------------------------------------------------------------
  aset(_page_params,0,vector('sid',_sid));
  aset(_page_params,1,vector('realm',_realm));
  aset(_page_params,2,vector('user_info',OMAIL.WA.array2xml(_user_info)));


  -- XML structure-------------------------------------------------------------------
  return concat(OMAIL.WA.omail_page_params(_page_params),
                OMAIL.WA.omail_external_params_lines(params, _params),
                sprintf('<to><![CDATA[%s]]></to>', _to));
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_set_mail(
  inout path any,
  inout lines any,
  inout params any)
{
  -- www procedure

  declare _rs,_sid,_realm varchar;
  declare _page_params any;
  declare _user_info, _settings any;
  declare _user_id, _domain_id integer;

  _sid       := get_keyword('sid',params,'');
  _realm     := get_keyword('realm',params,'');
  _user_info := get_keyword('user_info',params);

  -- TEMP constants -------------------------------------------------------------------
  _user_id   := get_keyword('user_id',_user_info);
  _domain_id := 1;

  -- GET SETTINGS ------------------------------
  _settings := OMAIL.WA.omail_get_settings(_domain_id, _user_id, 'base_settings');

  -- Set constants  -------------------------------------------------------------------
  _page_params := vector(0,0,0,0,0,0,0,0,0,0,0,0);

  -- Form Action---------------------------------------------------------------------
  if (get_keyword ('fa_save.x',params,'') <> '')
  {
    -- check params for illegal values---------------------------------------------------

    if (OMAIL.WA.omail_check_interval(get_keyword('msg_name',params), 0, 1))
      -- check display name
      OMAIL.WA.omail_setparam('msg_name', _settings, cast(get_keyword('msg_name',params) as integer));

    if (OMAIL.WA.omail_getp('msg_name',_settings) = 1)
      -- set display name
      OMAIL.WA.omail_setparam('msg_name_txt', _settings, trim(get_keyword('msg_name_txt',params)));

    if (OMAIL.WA.omail_check_interval(get_keyword('msg_result',params), 5, 1000))
      -- check messages per page
      OMAIL.WA.omail_setparam('msg_result', _settings, cast(get_keyword('msg_result',params) as integer));
    else
      OMAIL.WA.utl_redirect(sprintf('err.vsp?sid=%s&realm=%s&err=%d',_sid,_realm,1701));

    if (OMAIL.WA.omail_check_interval(get_keyword('usr_sig_inc',params), 0, 1))
      -- check include signature
      OMAIL.WA.omail_setparam('usr_sig_inc', _settings, cast(get_keyword('usr_sig_inc',params) as integer));

    if (OMAIL.WA.omail_getp('usr_sig_inc',_settings) = 1)
      OMAIL.WA.omail_setparam('usr_sig_txt', _settings, trim(get_keyword('usr_sig_txt', params)));

    OMAIL.WA.omail_setparam('msg_reply', _settings, get_keyword('msg_reply', params));
    OMAIL.WA.omail_setparam('atom_version', _settings, get_keyword('atom_version', params, '1.0'));
    if (cast (get_keyword ('spam_msg_action', params, '0') as integer) > 0)
    {
      OMAIL.WA.omail_setparam ('spam_msg_action', _settings, cast (get_keyword ('spam_msg_action_radio', params, '0') as integer));
    } else {
      OMAIL.WA.omail_setparam ('spam_msg_action', _settings, cast (get_keyword ('spam_msg_action', params, '0') as integer));
    }
    OMAIL.WA.omail_setparam ('spam_msg_state', _settings, cast (get_keyword ('spam_msg_state', params, '0') as integer));
      -- check clean spam interval
    if (OMAIL.WA.omail_check_interval (get_keyword ('spam_msg_clean', params), 0, 1000))
    {
      OMAIL.WA.omail_setparam ('spam_msg_clean', _settings, cast (get_keyword ('spam_msg_clean', params, '0') as integer));
    } else {
      OMAIL.WA.utl_redirect (sprintf ('err.vsp?sid=%s&realm=%s&err=%d',_sid,_realm,1702));
    }

    OMAIL.WA.omail_setparam ('spam_msg_header', _settings, cast (get_keyword ('spam_msg_header', params, '0') as integer));
    OMAIL.WA.omail_setparam('spam', _settings, cast(get_keyword ('spam', params, '0') as integer));

    -- security
    OMAIL.WA.omail_setparam ('security_sign', _settings, get_keyword ('security_sign', params, ''));
    OMAIL.WA.omail_setparam ('security_sign_mode', _settings, cast (get_keyword ('security_sign_mode', params, '0') as integer));
    OMAIL.WA.omail_setparam ('security_encrypt', _settings, get_keyword ('security_encrypt', params, ''));
    OMAIL.WA.omail_setparam ('security_encrypt_mode', _settings, cast (get_keyword ('security_encrypt_mode', params, '0') as integer));

    OMAIL.WA.omail_setparam('conversation', _settings, cast(get_keyword('conversation', params, '0') as integer));

    OMAIL.WA.omail_setparam('update_flag', _settings, 1);

    -- Save Settings --------------------------------------------------------------
    OMAIL.WA.omail_set_settings(_domain_id, _user_id, 'base_settings', _settings, get_keyword('domain_id', _user_info));
    commit work;
  }
  if ((get_keyword ('fa_cancel.x',params,'') <> '') or (get_keyword ('fa_save.x',params,'') <> ''))
  {
    OMAIL.WA.utl_doredirect(sprintf ('box.vsp?sid=%s&realm=%s&bp=100', _sid, _realm), get_keyword ('domain_id', _user_info));
    return;
  }

  -- Page Params---------------------------------------------------------------------
  aset(_page_params,0,vector('sid',_sid));
  aset(_page_params,1,vector('realm',_realm));
  aset(_page_params,2,vector('user_info',OMAIL.WA.array2xml(_user_info)));

  -- XML structure-------------------------------------------------------------------
  _rs := OMAIL.WA.omail_page_params(_page_params);
  _rs := sprintf('%s<settings>', _rs);
  _rs := sprintf('%s<msg_name selected="%d"><![CDATA[%s]]></msg_name>',_rs, OMAIL.WA.omail_getp('msg_name',_settings), OMAIL.WA.omail_getp('msg_name_txt',_settings));
  _rs := sprintf('%s<msg_reply><![CDATA[%s]]></msg_reply>', _rs, OMAIL.WA.omail_getp('msg_reply',_settings));
  _rs := sprintf('%s<msg_result>%d</msg_result>', _rs, OMAIL.WA.omail_getp('msg_result',_settings));
  _rs := sprintf('%s<usr_sig_inc selected="%d"><![CDATA[%s]]></usr_sig_inc>', _rs, OMAIL.WA.omail_getp('usr_sig_inc',_settings),OMAIL.WA.omail_getp('usr_sig_txt',_settings));
  _rs := sprintf('%s<atom_version>%s</atom_version>', _rs, OMAIL.WA.omail_getp('atom_version', _settings));
  _rs := sprintf ('%s<spam_msg_action>%d</spam_msg_action>', _rs, OMAIL.WA.omail_getp ('spam_msg_action', _settings));
  _rs := sprintf ('%s<spam_msg_state>%d</spam_msg_state>', _rs, OMAIL.WA.omail_getp ('spam_msg_state', _settings));
  _rs := sprintf ('%s<spam_msg_clean>%d</spam_msg_clean>', _rs, OMAIL.WA.omail_getp ('spam_msg_clean', _settings));
  _rs := sprintf ('%s<spam_msg_header>%d</spam_msg_header>', _rs, OMAIL.WA.omail_getp ('spam_msg_header', _settings));
  _rs := sprintf ('%s<spam>%d</spam>', _rs, OMAIL.WA.omail_getp('spam', _settings));
  _rs := sprintf ('%s<security_sign>%V%s</security_sign>', _rs, OMAIL.WA.omail_getp ('security_sign', _settings), OMAIL.WA.certificateList (_user_id, OMAIL.WA.omail_getp ('security_sign', _settings)));
  _rs := sprintf ('%s<security_sign_mode>%d</security_sign_mode>', _rs, OMAIL.WA.omail_getp ('security_sign_mode', _settings));
  _rs := sprintf ('%s<security_encrypt>%V%s</security_encrypt>', _rs, OMAIL.WA.omail_getp ('security_encrypt', _settings), OMAIL.WA.certificateList (_user_id, OMAIL.WA.omail_getp ('security_encrypt', _settings)));
  _rs := sprintf ('%s<security_encrypt_mode>%d</security_encrypt_mode>', _rs, OMAIL.WA.omail_getp ('security_encrypt_mode', _settings));
  _rs := sprintf('%s<conversation>%d</conversation>', _rs, OMAIL.WA.omail_getp('conversation', _settings));
  _rs := sprintf('%s<discussion>%d</discussion>', _rs, OMAIL.WA.discussion_check ());
  _rs := sprintf('%s</settings>', _rs);
  return _rs;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_set_settings(
  in domain_id integer,
  in user_id   integer,
  in keyword   varchar,
  in settings  any,
  in wa_id integer := null)
{
  if (OMAIL.WA.omail_getp('update_flag', settings) <> 1)
    return;

  if (isnull (wa_id))
  {
    OMAIL.WA.omail_set_settings_data(domain_id, user_id, keyword, settings);
    return;
  }

  declare oSettings, oConversation, nConversation any;

  oSettings := OMAIL.WA.omail_get_settings(domain_id, user_id, keyword);
  oConversation := cast(get_keyword('conversation', oSettings, '0') as integer);
  nConversation := cast(get_keyword('conversation', settings, '0') as integer);
  OMAIL.WA.omail_set_settings_data(domain_id, user_id, keyword, settings);
  OMAIL.WA.nntp_update(wa_id, oConversation, nConversation);
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_setparam(
  in    _name   varchar,
  inout _params any,
  in    _value  any)
{
  declare N integer;

  for (N := 0; N < length (_params); N := N + 2)
  {
    if (_params[N] = _name)
    {
      aset(_params,N+1,_value);
      return;
    }
  }
  _params := vector_concat(_params,vector(_name,_value));
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_smtp_message_deliver(
  in _recipient varchar,
  in _source any)
{
  declare _folder_id, _domain_id, _user_id, _msg_source integer;

  _folder_id  := 100; -- Inbox
  _msg_source := -1;  -- SMTP
  _domain_id  := OMAIL.WA.domain_id(_recipient);
  if (not isnull (_domain_id))
  {
    _user_id   := OMAIL.WA.domain_owner_id(_domain_id);
    _domain_id := 1;  -- normal mail
  }
  else
  {
    _domain_id := (select C_DOMAIN_ID from OMAIL.WA.CONVERSATION where C_ADDRESS = _recipient);
    if (isnull(_domain_id))
      return 0;

    _user_id   := OMAIL.WA.domain_owner_id(_domain_id);
  }
  _source := OMAIL.WA.omail_receive_message (_domain_id, _user_id, null, _source, null, _msg_source, _folder_id);

  return 1;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_check_mailbox (in _mailbox varchar) returns integer
{
  declare frozen any;

  declare exit handler for not found { goto _end; };

  select WAI_IS_FROZEN into frozen from DB.DBA.WA_INSTANCE where WAI_NAME = _mailbox;
  if (is_empty_or_null(frozen))
    return 1;

_end:
  if (exists(select 1 from OMAIL.WA.CONVERSATION where C_ADDRESS = _mailbox))
    return 1;

  return 0;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_split_decode_cast(
  in _string     varchar,
  in _decode     integer,
  in _separator varchar,
  in _length    integer)
{
  declare _params any;
  declare _len,_ind integer;

  _params := split_and_decode(_string,_decode,_separator);
  _len := length(_params);
  for (_ind := 0; _ind < _len; _ind := _ind + 1)
    aset(_params,_ind,cast(_params[_ind] as integer));

  if (_len < _length)
  {
    while (_ind < _length)
    {
      _params := vector_concat(_params,vector(0));
      _ind := _ind + 1;
    }
  }
  return _params;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_split_ename(
  in _recipient varchar,
  out _user_name varchar)
{
  declare _usern any;

  _usern := split_and_decode(_recipient,0,'\0\0-');
  _usern := split_and_decode(aref(_usern,2),0,'\0\0@');

  _user_name := aref(_usern,0);
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_sql_exec(
  in _domain_id integer,
  in _user_id integer,
  in _sql_statm  any,
  in _sql_params any,
  in _skipped integer,
  in _pageSize integer,
  in _sortby varchar,
  in _cloud integer := 0)
{
  declare _ind, _len, _min, _max integer;
  declare _state,_rs, _msg varchar;
  declare _descr, _rows, _object, _tags, _dict any;

  _state := '00000';
  _sql_statm := concat(_sql_statm, ' FOR XML AUTO OPTION (ORDER)');
  exec(_sql_statm, _state, _msg, _sql_params, 1000, _descr, _rows);

  if (_state <> '00000')
  {
    signal(_state, _msg);
    return;
  }

  _rs := ' ';
  _len := length(_rows);
  if (_skipped >= _len)
  {
    _skipped := floor((_len - 1) / _pageSize) * _pageSize;
    if (_skipped < 0)
      _skipped := 0;
  }
  _max := 1;
  _min := 1000000;
  _dict := dict_new();
  for (_ind := 0; _ind < _len; _ind := _ind + 1)
  {
    if (_ind + 1 = _skipped)
      _rs := sprintf('%s<prev_msg>%d</prev_msg>\n', _rs, _rows[_ind][4]);
    if (_ind = (_skipped + _pageSize))
      _rs := sprintf('%s<next_msg>%d</next_msg>\n', _rs, _rows[_ind][4]);
    if ((_ind >= _skipped) and  (_ind < (_skipped + _pageSize)))
    {
      _rs := sprintf('%s<message>\n',_rs);
      _rs := sprintf('%s<position>%d</position>\n%s\n', _rs, _ind+1, OMAIL.WA.omail_select_xml(_descr[0], _rows[_ind]));
      _rs := sprintf('%s</message>',_rs);
    }
    if (_cloud)
    {
      _tags := OMAIL.WA.tags_select(_domain_id, _user_id, _rows[_ind][4]);
      if (_tags <> '')
      {
        _tags := split_and_decode (_tags, 0, '\0\0,');
        foreach (any _tag in _tags) do
        {
          _object := dict_get(_dict, lcase(_tag), vector(lcase(_tag), 0));
          _object[1] := _object[1] + 1;
          if (_object[1] < _min)
            _min := _object[1];
          if (_object[1] > _max)
            _max := _object[1];
          dict_put(_dict, lcase(_tag), _object);
        }
      }
    }
  }
  if (_cloud)
  {
    _rs := _rs || '<ctags>';
    for (select p.* from OMAIL.WA.tagsDictionary2rs(p0)(_tag varchar, _cnt integer) p where p0 = _dict order by _tag) do
      _rs := _rs || sprintf('<ctag style="%V">%s</ctag>', ODS.WA.tag_style(_cnt, _min, _max), _tag);
    _rs := _rs || '</ctags>';
  }
  return sprintf('%s<order>%s</order><direction>%s</direction><skiped>%d</skiped><show_res>%d</show_res><all_res>%d</all_res>', _rs, substring (_sortby,1,1), substring (_sortby,2,1), _skipped, _pageSize, _len);
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_str2params(
  in _names     varchar,
  in _values    varchar,
  in _separator varchar)
{
  if (length(_values) > 1000)
    return vector(100,0,0,0,0,0);

  declare _params,_names_arr,_values_arr any;
  declare _len,_ind,_int integer;

  _params := vector();
  _names_arr  := split_and_decode(_names,0,concat('\0\0',_separator));
  _values_arr := split_and_decode(_values,0,concat('\0\0',_separator));

  for (_ind := 0; _ind < length(_names_arr); _ind := _ind + 1)
    _params := vector_concat(_params, vector('', 0));

  _ind := 0;
  _int := 0;
  while((_ind < length(_names_arr))) {
    aset(_params, _int, cast(_names_arr[_ind] as varchar));
    _int := _int + 1;
    if (_ind < length(_values_arr))
      aset(_params,_int,cast(_values_arr[_ind] as integer));
    _int := _int + 1;
    _ind := _ind + 1;
  }
  return _params;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_tools(
  inout path any,
  inout lines any,
  inout params any)
{
  -- www procedure

  declare _rs,_sid,_realm,_result1,_tp varchar;
  declare _params,_page_params any;
  declare _user_info any;
  declare _user_id,_domain_id,_error integer;

  _sid       := get_keyword('sid',params,'');
  _realm     := get_keyword('realm',params,'');
  _user_info := get_keyword('user_info',params);

  -- TEMP constants -----------------------------
  _user_id   := get_keyword('user_id',_user_info);
  _domain_id := 1;

  -- Set constants  -------------------------------------------------------------------
  _page_params := vector(0,0,0,0,0,0,0,0,0,0,0,0);
  _error       := 0;

  -- Set Variable--------------------------------------------------------------------
  _tp := get_keyword('tp',params,'0,0,0,0'); -- [0]_id, [1]action, [2]confirm, [3]return to url

  -- Set Arrays----------------------------------------------------------------------
  _params := OMAIL.WA.omail_split_decode_cast(_tp,0,'\0\0,',10);

  -- Form Action---------------------------------------------------------------------
  if (_params[2] = 1)
  {
    -- > confirm action
    OMAIL.WA.folder_edit (_domain_id, _user_id, _params[0], _params[1], null, _error);
    if (_error <> 0)
      OMAIL.WA.utl_redirect(sprintf('err.vsp?sid=%s&realm=%s&err=%d',_sid,_realm,_error));
    else if (_params[3] = 1)
      OMAIL.WA.utl_redirect(sprintf('box.vsp?sid=%s&realm=%s&bp=110',_sid,_realm));
    else
      OMAIL.WA.utl_redirect(sprintf('folders.vsp?sid=%s&realm=%s',_sid,_realm));
    return;
  }

  _result1 := OMAIL.WA.omail_tools_action(_domain_id,_user_id, _params[0], _params [1],_error);
  if (_error <> 0)
  {
    OMAIL.WA.utl_redirect(sprintf('err.vsp?sid=%s&realm=%s&err=%d',_sid,_realm,_error));
    return;
  }

  -- Page Params---------------------------------------------------------------------
  aset(_page_params,0,vector('sid', _sid));
  aset(_page_params,1,vector('realm', _realm));
  aset(_page_params,2,vector('object_id', _params[0]));
  aset (_page_params,3,vector ('object_name', sprintf ('<![CDATA[%s]]>', OMAIL.WA.folder_name(_domain_id, _user_id, _params[0]))));
  aset(_page_params,4,vector('tp',_tp));
  aset(_page_params,5,vector('user_info', OMAIL.WA.array2xml(_user_info)));

  -- XML structure-------------------------------------------------------------------
  _rs := concat(OMAIL.WA.omail_page_params(_page_params), _result1);

  return _rs;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_export(
  inout path any,
  inout lines any,
  inout params any)
{
  -- www procedure

  declare _user_id, _domain_id integer;
  declare _rs,_sid, _realm varchar;
  declare _params, _user_info any;
  declare _output varchar;

  _sid       := get_keyword('sid',params,'');
  _realm     := get_keyword('realm',params,'');
  _user_info := get_keyword('user_info',params);

  -- TEMP constants -----------------------------
  _user_id   := get_keyword('user_id',_user_info);
  _domain_id := 1;

  _output    := get_keyword('output', params, '');
  if (_output in ('rss', 'rdf', 'xbel', 'atom03', 'atom10'))
  {
    declare _from, _to, _subject, _body, _tags, _after, _before, _fid, _attach, _read  varchar;
    declare _max, _order, _direction varchar;
    declare tmp any;

    declare sql, state, msg, meta, result any;

    _max       := get_keyword('max', params, '100');
    _order     := get_keyword('order', params, '');
    _direction := get_keyword('direction', params, '');

    _params    := vector();
    if (get_keyword ('mode', params, '') = 'advanced')
    {
      _from      := get_keyword('from', params, '');
      _to        := get_keyword('to', params, '');
      _subject   := get_keyword('subject', params, '');
      _body      := get_keyword('body', params, '');
      _tags      := get_keyword('tags', params, '');
      _after     := get_keyword('after', params, '');
      _before    := get_keyword('before', params, '');
      _fid       := get_keyword('fid', params, '');
      _attach    := get_keyword('attach', params, '');
      _read      := get_keyword ('read', params, '');

      _params    := vector_concat(_params, vector('mode', 'advanced'));
      _params    := vector_concat(_params, vector('q_from', _from));
      _params    := vector_concat(_params, vector('q_to', _to));
      _params    := vector_concat(_params, vector('q_subject', _subject));
      _params    := vector_concat(_params, vector('q_body', _body));
      _params    := vector_concat(_params, vector('q_tags', _tags));
      _params    := vector_concat (_params, vector ('q_after', _after));
      _params    := vector_concat (_params, vector ('q_before', _before));
      _params    := vector_concat(_params, vector('q_attach', _attach));
      _params    := vector_concat (_params, vector ('q_read', _read));
      _params    := vector_concat(_params, vector('q_fid', _fid));
    }
    else
    {
      _params    := vector_concat(_params, vector('q', get_keyword('q', params, '')));
    }
    _params    := vector_concat(_params, vector('q_max', _max));
    _params    := vector_concat(_params, vector('order', _order));
    _params    := vector_concat(_params, vector('direction', _direction));

    sql   := OMAIL.WA.omail_msg_search(_domain_id, _user_id, _params, 0);
    state := '00000';
    exec(sql[0], state, msg, sql[1], 0, meta, result);
    if (state <> '00000')
      goto _error;

    set http_charset = 'UTF-8';
    http_rewrite ();
    http_header ('Content-Type: text/xml; charset=UTF-8\r\n');

    -- update standard header
    declare psh, hdr varchar;

    psh := (select WS_FEEDS_HUB from DB.DBA.WA_SETTINGS);
    if (length (psh))
    {
      hdr := http_header_get ();
  	  http_header (hdr || sprintf ('Link: <%s>; rel="hub"; title="PubSubHub"\r\n', psh));
  	}

    http ('<rss version="2.0">\n');
    http ('<channel>\n');
    for (select U_FULL_NAME, U_E_MAIL from DB.DBA.SYS_USERS where U_ID = _user_id) do
    {
      http ('<title>');
        http_value (OMAIL.WA.utf2wide(OMAIL.WA.domain_name(_domain_id)));
      http ('</title>\n');
      http ('<description>');
        http_value (OMAIL.WA.utf2wide(OMAIL.WA.domain_description(_domain_id)));
      http ('</description>\n');
      http ('<managingEditor>');
        http_value (U_E_MAIL);
      http ('</managingEditor>\n');
      http ('<pubDate>');
        http_value (OMAIL.WA.dt_rfc1123(now()));
      http ('</pubDate>\n');
      http ('<generator>');
        http_value ('Virtuoso Universal Server ' || sys_stat('st_dbms_ver'));
      http ('</generator>\n');
      http ('<webMaster>');
        http_value (U_E_MAIL);
      http ('</webMaster>\n');
      http ('<link>');
        http_value (OMAIL.WA.omail_url(_domain_id));
      http ('</link>\n');
    }
    foreach (any row in result) do
    {
      http ('<item>\n');
        http ('<title>');
          http_value (OMAIL.WA.utf2wide(row[0]));
        http ('</title>\n');
        http ('<link>');
          http_value (OMAIL.WA.omail_open_url(_sid, _realm, _domain_id, _user_id, row[4]));
        http ('</link>\n');
        http ('<pubDate>');
          http_value (OMAIL.WA.dt_rfc1123 (row[7]));
        http ('</pubDate>\n');
        if (_output <> 'rss') {
          http ('<ods:modified xmlns:ods:="http://www.openlinksw.com/ods/">');
            http_value (OMAIL.WA.dt_iso8601 (row[7]));
          http ('</ods:modified>\n');
        }
        http ('<description><![CDATA[');
          http_value (OMAIL.WA.utf2wide(OMAIL.WA.omail_message_body(_domain_id, _user_id, row[4])));
        http (']]></description>\n');
      http ('</item>\n');
    }
    http ('</channel>\n');
    http ('</rss>');

    if (_output = 'rdf')
 	    http_xslt (OMAIL.WA.omail_xslt_full ('export/rss2rdf.xsl'));

    else if (_output = 'xbel')
	    http_xslt (OMAIL.WA.omail_xslt_full ('export/rss2xbel.xsl'));

    else if (_output = 'atom03')
	    http_xslt (OMAIL.WA.omail_xslt_full ('export/rss2atom03.xsl'));

    else if (_output = 'atom10')
	    http_xslt (OMAIL.WA.omail_xslt_full ('export/rss2atom.xsl'));

    goto _end;
  }
_error:
  http('<?xml version="1.0" ?><empty />');

_end:
  signal('90005','Make export');
  return;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_tools_action(
  in  _domain_id  integer,
  in  _user_id    integer,
  in  _object_id  integer,
  in  _action_id  integer,
  out _error      integer)
{
  declare _rs,_sql_result1,_sql_result2,_object_name,_sql_statm varchar;
  declare _parent_id integer;
  declare _sql_params any;

  _error := 0;
  _object_name := '';
  _parent_id := 0;

  if (_action_id = 0)
  { -- edit folder
    if (_object_id <= 130)
    {
       _error := 1301;
       return '';
    }

    select NAME,
           PARENT_ID
      INTO _object_name,
           _parent_id
      from OMAIL.WA.FOLDERS
     where DOMAIN_ID = _domain_id and USER_ID = _user_id and FOLDER_ID = _object_id;

    _sql_result1 := sprintf ('<parent_id>%s</parent_id>', cast (coalesce (_parent_id, '') as varchar));
    _sql_statm   := vector ('select FOLDER_ID,NAME from OMAIL.WA.FOLDERS where DOMAIN_ID = ? and USER_ID = ? and PARENT_ID');
    _sql_params  := vector(vector(_domain_id,_user_id,''),vector(''));-- user_id
    _sql_result1 := sprintf ('%s%s', _sql_result1, OMAIL.WA.folders_list(_domain_id, _user_id));
  }
  else if (_action_id = 1)
  { -- delete folder
    if (_object_id <= 130)
    {
      _error := 1302;
      return '';
    }
    select NAME
      INTO _object_name
      from OMAIL.WA.FOLDERS
     where DOMAIN_ID = _domain_id and USER_ID = _user_id and FOLDER_ID = _object_id;

    select COUNT(*)
      INTO _sql_result1
      from OMAIL.WA.MESSAGES
     where DOMAIN_ID = _domain_id and USER_ID = _user_id and FOLDER_ID = _object_id;

    select COUNT(*)
      INTO _sql_result2
      from OMAIL.WA.FOLDERS
     where DOMAIN_ID = _domain_id and USER_ID = _user_id and PARENT_ID = _object_id;

    _sql_result1 := sprintf('<count_m>%s</count_m>',cast(_sql_result1 as varchar));
    _sql_result1 := sprintf('%s<count_f>%s</count_f>',_sql_result1,cast(_sql_result2 as varchar));
  }
  else if (_action_id = 2)
  { -- empty folder
    select NAME
      INTO _object_name
      from OMAIL.WA.FOLDERS
     where DOMAIN_ID = _domain_id and USER_ID = _user_id and FOLDER_ID = _object_id;

    select COUNT(*)
      INTO _sql_result1
      from OMAIL.WA.MESSAGES
     where DOMAIN_ID = _domain_id and USER_ID = _user_id and FOLDER_ID = _object_id;

    select COUNT(*)
      INTO _sql_result2
      from OMAIL.WA.FOLDERS
     where DOMAIN_ID = _domain_id and USER_ID = _user_id and PARENT_ID = _object_id;

    _sql_result1 := sprintf('<count_m>%s</count_m>',cast(_sql_result1 as varchar));
    _sql_result1 := sprintf('%s<count_f>%s</count_f>',_sql_result1,cast(_sql_result2 as varchar));
  }

  _rs := sprintf('<object action_id="%d">',_action_id);
  _rs := sprintf('%s<object_name><![CDATA[%s]]></object_name>',_rs,_object_name);
  _rs := sprintf('%s<object_id>%d</object_id>',_rs,_object_id);
  _rs := sprintf('%s%s',_rs,_sql_result1);
  _rs := sprintf('%s</object>',_rs);

  return _rs;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_update_msg_attached(
  in _domain_id integer,
  in _user_id   integer,
  in _msg_id    integer)
{
  declare _attached integer;
  select COUNT(*)
    INTO _attached
    from OMAIL.WA.MSG_PARTS
   where DOMAIN_ID = _domain_id and USER_ID = _user_id and MSG_ID = _msg_id and PDEFAULT <> 1 and FNAME <> 'smime.p7s';

  update OMAIL.WA.MESSAGES
     set ATTACHED = _attached
   where DOMAIN_ID = _domain_id and USER_ID = _user_id and MSG_ID = _msg_id;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_update_msg_size(
  in _domain_id integer,
  in _user_id   integer,
  in _msg_id    integer)
{
  declare _dsize_h,_dsize_b integer;
  select length (MHEADER)
    INTO _dsize_h
    from OMAIL.WA.MESSAGES
   where DOMAIN_ID = _domain_id and USER_ID = _user_id and MSG_ID = _msg_id;

  select SUM(DSIZE)
    INTO _dsize_b
    from OMAIL.WA.MSG_PARTS
   where DOMAIN_ID = _domain_id and USER_ID = _user_id and MSG_ID = _msg_id;

  update OMAIL.WA.MESSAGES
     set DSIZE = (_dsize_h + _dsize_b)
   where DOMAIN_ID = _domain_id and USER_ID = _user_id and MSG_ID = _msg_id;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_vec_values(
  inout _vector any,
  in _el_1 integer,
  in _value any)
{
  declare _temp any;

  _temp := aref(_vector,_el_1);

  aset(_temp,(length(_vector)-1),_value);
  aset(_vector,_el_1,_temp);
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_write(
  inout path any,
  inout lines any,
  inout params any)
{
  -- www procedure

  declare _rs,_sid,_realm,_wp,_sql_result1,_sql_result2,_faction,_pnames,_signature,_to,_cc,_bcc,_dcc,_subject,_tags,_eparams_url,_scopy,_html,_priority,_body varchar;
  declare _params,_page_params,_settings any;
  declare _sql_statm,_sql_params,_user_info any;
  declare _ind,_len,_user_id,_folder_id,_error,_msg_id,_domain_id integer;

  _sid       := get_keyword('sid',params,'');
  _realm     := get_keyword('realm',params,'');
  _user_info := get_keyword('user_info',params);

  -- TEMP constants -----------------------------
  _user_id   := get_keyword('user_id',_user_info);
  _domain_id := 1;

  -- GET SETTINGS ------------------------------
  _settings := OMAIL.WA.omail_get_settings(_domain_id, _user_id, 'base_settings');

  -- Set constants  -------------------------------------------------------------------
  _sql_params  := vector(0,0,0,0,0,0);
  _page_params := vector (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0);
  _sql_result1 := '';
  _sql_result2 := '';
  _faction     := '';
  _eparams_url := '';

  -- Set Variable--------------------------------------------------------------------
  if (get_keyword('fa_send.x',params,'') <> '')
    _faction := 'send';
  else if (get_keyword('fa_save.x',params,'') <> '')
    _faction := 'save';
  else if (get_keyword('fa_preview.x',params,'') <> '')
    _faction := 'preview';
  else if (get_keyword('fa_attach.x',params,'') <> '')
    _faction := 'attach';
  else if (get_keyword('fa_dav.x',params,'') <> '')
    _faction := 'DAV';

  _to       := replace(get_keyword('to', params, ''), 'mailto:', '');
  _cc       := get_keyword('cc', params, '');
  _bcc      := get_keyword('bcc', params, '');
  _dcc      := get_keyword('dcc', params, '');
  _subject  := get_keyword('subject', params, '');
  _tags     := get_keyword('tags', params, '');
  _scopy    := case when (isnull (get_keyword ('to', params))) then get_keyword ('save_copy', _settings, '1') else get_keyword ('scopy', params, '0') end;
  _html     := get_keyword('html', params, '1');
  _priority := get_keyword('priority', params, '');
  _body     := get_keyword('body', params, '');

  -- Set Arrays----------------------------------------------------------------------
  _pnames := 'msg_id,preview,re_mode,re_msg_id';
  _params := OMAIL.WA.omail_str2params(_pnames,get_keyword('wp',params,'0,0,0,0'),',');
  OMAIL.WA.omail_setparam('_html_parse',_params,0);

  -- SET SETTINGS --------------------------------------------------------------------
  if (_scopy <> get_keyword ('save_copy',_settings, '1'))
  {
    OMAIL.WA.omail_setparam('save_copy', _settings, _scopy);
    OMAIL.WA.omail_setparam('update_flag', _settings, 1);
  }
  if (get_keyword('eparams',params,'') <> '')
    _eparams_url := get_keyword('eparams',params,'');

  -- Form Action---------------------------------------------------------------------
  if (_faction = 'send')
  {
    -- > 'save new /update/  message into Draft'
    _msg_id := OMAIL.WA.omail_save_msg(_domain_id,_user_id, params, OMAIL.WA.omail_getp('msg_id', _params), _error);
    OMAIL.WA.omail_set_settings(_domain_id,_user_id, 'base_settings', _settings);
    OMAIL.WA.omail_send_msg(_domain_id, _user_id, params, _msg_id, null, _error);
    if (_error = 0)
      OMAIL.WA.utl_redirect(sprintf('sendok.vsp?sid=%s&realm=%s&sp=%d&to=%U%s',_sid,_realm,_msg_id,_to,_eparams_url));
    else
      OMAIL.WA.utl_redirect(sprintf('err.vsp?sid=%s&realm=%s&err=%d&p=%d',_sid,_realm,_error,_msg_id));
    return;
  }
  if (_faction = 'save')
  {
    -- > save new /update/  message into 'Draft'
    _msg_id := OMAIL.WA.omail_save_msg(_domain_id,_user_id,params,OMAIL.WA.omail_getp('msg_id',_params),_error);
    OMAIL.WA.omail_set_settings(_domain_id, _user_id, 'base_settings', _settings);
    if (_error = 0)
      OMAIL.WA.utl_redirect(sprintf('write.vsp?sid=%s&realm=%s&wp=%d%s',_sid,_realm,_msg_id,_eparams_url));
    else
      OMAIL.WA.utl_redirect(sprintf('err.vsp?sid=%s&realm=%s&err=%d',_sid,_realm,_error));
    return;
  }
  if (_faction = 'DAV')
  {
    -- > save new /update/ message and attached into 'Draft'
    _msg_id := OMAIL.WA.omail_save_msg(_domain_id,_user_id, params, OMAIL.WA.omail_getp('msg_id',_params), _error);
    OMAIL.WA.omail_set_settings(_domain_id, _user_id, 'base_settings', _settings);
    if (_error <> 0)
      goto _end;

    -- save attached
    declare N integer;
    declare fileName, fParams any;
    N := 1;
    while (1)
    {
      fileName := get_keyword(sprintf('f%d', N), params, '');
      if (fileName = '')
        goto _end;
      fParams := vector ('att_source', '1', 'att_2', fileName);
      OMAIL.WA.omail_insert_attachment(_domain_id, _user_id, fParams, _msg_id, _error);
      if (_error <> 0)
        goto _end;
      N := N + 1;
    }
  _end:;
    if (_error = 0)
      OMAIL.WA.utl_redirect(sprintf('write.vsp?sid=%s&realm=%s&wp=%d%s',_sid,_realm,_msg_id, OMAIL.WA.omail_external_params_url(params)));
    else
      OMAIL.WA.utl_redirect(sprintf('err.vsp?sid=%s&realm=%s&err=%d',_sid,_realm,_error));
    return;
  }
  if (_faction = 'preview')
  {
    -- > 'HTML preview'
    _msg_id := OMAIL.WA.omail_save_msg(_domain_id,_user_id,params,OMAIL.WA.omail_getp('msg_id',_params),_error);
    OMAIL.WA.omail_set_settings(_domain_id, _user_id, 'base_settings', _settings);
    if (_error = 0)
      OMAIL.WA.utl_redirect(sprintf('write.vsp?sid=%s&realm=%s&wp=%d,%d',_sid,_realm,_msg_id,1));
    else
      OMAIL.WA.utl_redirect(sprintf('err.vsp?sid=%s&realm=%s&err=%d',_sid,_realm,_error));
    return;
  }
  if (_faction = 'attach')
  {
    -- > 'save new /update/  message into Draft and goto Attachment page'
    _msg_id := OMAIL.WA.omail_save_msg(_domain_id, _user_id, params, OMAIL.WA.omail_getp('msg_id',_params), _error);
    OMAIL.WA.omail_set_settings(_domain_id, _user_id, 'base_settings', _settings);
    if (_error = 0)
    {
      OMAIL.WA.utl_redirect(sprintf('attach.vsp?sid=%s&realm=%s&ap=%d%s',_sid,_realm,_msg_id,_eparams_url));
    } else {
      OMAIL.WA.utl_redirect(sprintf('err.vsp?sid=%s&realm=%s&err=%d',_sid,_realm,_error));
    }
    return;
  }

  -- SQL Statement-------------------------------------------------------------------
  if ((OMAIL.WA.omail_getp ('msg_id',_params) <> 0) or (OMAIL.WA.omail_getp ('re_mode',_params) <> 0))
  {
    _sql_result1 := OMAIL.WA.omail_open_message(_domain_id,_user_id,_params, 1, 1);
    _sql_result2 := OMAIL.WA.omail_select_attachment(_domain_id,_user_id,OMAIL.WA.omail_getp('msg_id',_params),0);
  }
  else
  {
    if (_to <> '' or _cc <> '' or _bcc <> '' or _dcc <> '')
      _sql_result1 := sprintf ('<address><addres_list>\n<to><email>%V</email></to>\n<cc><email>%V</email></cc>\n<bcc><email>%V</email></bcc>\n<dcc><email>%V</email></dcc>\n</addres_list></address>\n', _to, _cc, _bcc, _dcc);

    if (_subject <> '')
      _sql_result1 := sprintf('%s<subject>%s</subject>\n',_sql_result1,_subject);

    if (_tags <> '')
      _sql_result1 := sprintf('%s<tags>%s</tags>\n',_sql_result1,_tags);

    if (_html = '1')
      _sql_result1 := sprintf('%s<type_id>10110</type_id>\n',_sql_result1);

    if (_priority <> '')
      _sql_result1 := sprintf('%s<priority>%s</priority>\n',_sql_result1,_priority);

    if (_body <> '')
      _sql_result1 := sprintf('%s<mbody><mtext>%s</mtext></mbody>\n',_sql_result1,OMAIL.WA.xml2string(_body));
  }
  _sql_result1 := concat(_sql_result1, OMAIL.WA.omail_external_params_xml(params));

  _signature := '';
  if ((OMAIL.WA.omail_getp('usr_sig_inc',_settings) = 1) and (OMAIL.WA.omail_getp('msg_id',_params) = 0))
    _signature := sprintf('<signature><![CDATA[%s]]></signature>\n',OMAIL.WA.omail_getp('usr_sig_txt',_settings));

  -- PAGE PARAMS --------------------------------------------------------------------
  aset(_page_params,0,vector('sid',_sid));
  aset(_page_params,1,vector('realm',_realm));
  aset(_page_params,2,vector('wp',OMAIL.WA.omail_params2str(_pnames,_params,',')));
  aset(_page_params, 3, vector('user_info', OMAIL.WA.array2xml(_user_info)));
  aset(_page_params,4,vector('save_copy', get_keyword('save_copy', _settings, '1')));
  aset (_page_params, 5, vector ('app', get_keyword ('app', _settings, '0')));
  aset (_page_params, 6, vector ('spam_msg_action', get_keyword ('spam_msg_action', _settings, '0')));
  aset (_page_params, 7, vector ('spam_msg_state', get_keyword ('spam_msg_state', _settings, '0')));
  aset (_page_params, 8, vector ('spam_msg_clean', get_keyword ('spam_msg_clean', _settings, '0')));
  aset (_page_params, 9, vector ('spam_msg_header', get_keyword ('spam_msg_header', _settings, '0')));
  aset (_page_params,10, vector ('spam', get_keyword ('spam', _settings, '0')));
  aset (_page_params,11, vector ('security_sign', get_keyword ('security_sign', _settings, '')));
  aset (_page_params,12, vector ('security_sign_mode', get_keyword ('security_sign_mode', _settings, '0')));
  aset (_page_params,13, vector ('security_encrypt', get_keyword ('security_encrypt', _settings, '')));
  aset (_page_params,14, vector ('security_encrypt_mode', get_keyword ('security_encrypt_mode', _settings, '0')));
  aset (_page_params,15, vector ('conversation', get_keyword ('conversation', _settings, '0')));
  aset (_page_params,16, vector ('discussion', OMAIL.WA.discussion_check ()));

  -- If massage is saved, that we open the Draft folder in Folders tree
  if (OMAIL.WA.omail_getp('msg_id',_params) <> 0)
    aset (_page_params, 17, vector ('folder_id', 130));

  -- XML structure-------------------------------------------------------------------
  _rs := '';
  _rs := sprintf('%s%s\n',_rs,OMAIL.WA.omail_page_params(_page_params));
  _rs := sprintf('%s%s\n',_rs,either(OMAIL.WA.omail_getp('preview',_params),'<preview/>',''));
  _rs := sprintf('%s<msg_id>%d</msg_id>',_rs,OMAIL.WA.omail_getp('msg_id',_params));
  _rs := sprintf ('%s%s', _rs, OMAIL.WA.folders_list(_domain_id, _user_id));
  _rs := sprintf('%s<message>\n', _rs);
  _rs := sprintf('%s%s\n',_rs,_sql_result1);
  _rs := sprintf('%s</message>\n', _rs);
  _rs := sprintf('%s%s\n', _rs,_signature);
  _rs := sprintf('%s%s\n',_rs,_sql_result2);
  _rs := sprintf('%s%s\n',_rs,OMAIL.WA.omail_accounts_list(_user_id));

  return _rs;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_external_params_url(
  inout params any)
{
  declare _i integer;
  declare _eparams varchar;

  _eparams := '';
  for (_i := 0; _i < length(params); _i := _i + 2)
    if (isstring(params[_i]) and (substring(params[_i],1,2) = 'p_' or substring(params[_i],1,2) = 's_' or substring(params[_i],1,2) = 'x_') or params[_i] = 'return')
      _eparams := sprintf('%s&%s=%s',_eparams,params[_i],params[_i+1]);

  return _eparams;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_external_params_xml(
  inout params any)
{
  declare _eparams varchar;

  _eparams := OMAIL.WA.omail_external_params_url(params);
  if (_eparams <> '')
    _eparams := sprintf('<eparams><![CDATA[%s]]></eparams>',_eparams);

  return _eparams;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_external_params_lines(
  inout params  any,
  inout _params any)
{
  declare _i integer;
  declare _name,_eparams,_sql_result1,_value varchar;

  _eparams := '';
  _sql_result1 := '';

  if (get_keyword ('return', params, '') <> '')
  {
    -- Special mode

    if (strstr(get_keyword('return', params, ''), '.')) {
      -- Action: Return to URL

      for (_i := 0; _i < length (params); _i := _i + 2)
      {
        if (isstring(params[_i]) and substring(params[_i],1,2) = 'p_') {
          _name := substring(params[_i],3,length(params[_i]));
          _eparams := sprintf('%s&%s=%s',_eparams,_name,params[_i+1]);
        }
      }

      for (_i := 0; _i < length (params); _i := _i + 2)
      {
        if (isstring(params[_i]) and substring(params[_i],1,2) = 's_')
        {
          _name := substring(params[_i],3,length(params[_i]));
          _value := params[_i+1];
          if (_value = 'msg_id' and get_keyword ('msg_id',_params,-1) <> -1)
          {
            _value := cast(get_keyword('msg_id',_params,0) as varchar);
          } else if (_value = 'acc_id'){
            _value := cast(get_keyword('acc_id',_params,'') as varchar);
          }
          _eparams := sprintf('%s&%s=%s',_eparams,_name,_value);
        }
      }

      if (_eparams <> '')
        _sql_result1 := sprintf('%s<eparams><![CDATA[%s]]></eparams>',_sql_result1,_eparams);

      _sql_result1 := sprintf('%s<return type="url">%s</return>',_sql_result1,get_keyword('return',params,''));
      _eparams := sprintf('%s&return=%s',_eparams,get_keyword('return',params,''));

    } else {
      -- Action: Set fileds, submit form and close

      for (_i := 0; _i < length (params); _i := _i + 2)
      {
        if (isstring(params[_i]) and substring(params[_i],1,2) = 'p_')
        {
          _name := substring(params[_i],3,length(params[_i]));
          _eparams := sprintf('%s<%s>%s</%s>', _eparams, _name, params[_i+1],_name);
        }
      }

      for (_i := 0; _i < length (params); _i := _i + 2)
      {
        if (isstring(params[_i]) and substring(params[_i],1,2) = 's_')
        {
          _name := substring(params[_i],3,length(params[_i]));
          _value := params[_i+1];

          if (_value = 'msg_id' and get_keyword ('msg_id',_params,-1) <> -1)
          {
            _value := cast(get_keyword('msg_id',_params,0) as varchar);
          } else if (_value = 'acc_id'){
            _value := cast(get_keyword('acc_id',_params,'') as varchar);
          }
          _eparams := sprintf('%s<%s>%s</%s>',_eparams,_name,_value,_name);
        }
      }

      if (_eparams <> '')
        _sql_result1 := sprintf('%s<external_params>%s</external_params>',_sql_result1,_eparams);

      _sql_result1 := sprintf('%s<return type="form">%s</return>',_sql_result1,get_keyword('return',params,''));
    }
  }
  return _sql_result1;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_accounts_list(
  inout _user_id integer)
{
  declare _xml varchar;

  _xml := '';
  for(select WAM_INST
        from WA_MEMBER M,
             DB.DBA.WA_INSTANCE I
       where M.WAM_INST = I.WAI_NAME
         and WAM_USER = _user_id
         and I.WAI_TYPE_NAME = 'oMail') do
    _xml := sprintf('%s<account>%s</account>',_xml,WAM_INST);

  if (_xml <> '')
    _xml := sprintf('<accounts>%s</accounts>',_xml);
  return _xml;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_welcome_msg_1(
  in _sender_name varchar,
  in _sender_mail varchar,
  in _recipient_name varchar,
  in _recipient_mail varchar,
  in _date any)
{
return concat('From ',_sender_mail,' Sat May 15 23:58:27 2004
Return-path: <',_sender_mail,'>
Delivery-date: Sat, 15 May 2004 23:58:27 +0300
Received: from [213.91.206.121] (helo=leon)
  by mail2.openlinksw.com with asmtp (Exim 4.30)
  id 1BP6Ec-0000JW-6d; Sat, 15 May 2004 16:58:18 -0400
Message-ID: ', OMAIL.WA.rfc_id (), '
From: "',_sender_name,'" <',_sender_mail,'>
To: "',_recipient_name,'" <',_recipient_mail,'>
Subject: Welcome to your mail box
Date: Sat, 15 May 2004 23:58:15 +0300
Reply-To: <', _sender_mail, '>
MIME-Version: 1.0
Content-Type: multipart/alternative;
  boundary="----=_NextPart_000_0005_01C43AD8.7CF0F690"
X-Priority: 3
X-MSMail-Priority: Normal
X-Mailer: Microsoft Outlook Express 6.00.2800.1409
X-MimeOLE: Produced By Microsoft MimeOLE V6.00.2800.1409

This is a multi-part message in MIME format.

------=_NextPart_000_0005_01C43AD8.7CF0F690
Content-Type: text/plain;
  charset="koi8-r"
Content-Transfer-Encoding: quoted-printable

Hello,
Welcome to your mailbox.
Have a nice day.

Your admin

------=_NextPart_000_0005_01C43AD8.7CF0F690
Content-Type: text/html;
  charset="koi8-r"
Content-Transfer-Encoding: quoted-printable

<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.0 Transitional//EN">
<HTML><HEAD>
<META http-equiv=3DContent-Type content=3D"text/html; charset=3Dkoi8-r">
<META content=3D"MSHTML 6.00.2800.1400" name=3DGENERATOR>
<STYLE></STYLE>
</HEAD>
<BODY bgColor=3D#ffffff>
  <h3>Hello</h3>
  Welcome to your mailbox.<br />
  Have a nice day.<br /><br />

  Your admin

</BODY></HTML>

------=_NextPart_000_0005_01C43AD8.7CF0F690--');
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_mails (
  inout path any,
  inout lines any,
  inout params any)
{
  -- www procedure

  declare _user_id, _domain_id integer;
  declare _rs, _sid, _realm, _set, _return, _certificate, _where, _what varchar;
  declare _page_params, _user_info any;

  _sid       := get_keyword ('sid', params, '');
  _realm     := get_keyword ('realm', params, '');
  _user_info := get_keyword ('user_info', params);
  _set       := get_keyword ('set', params, '');
  _return      := get_keyword ('return', params, '');
  _certificate := get_keyword ('certificate', params, '0');
  _where       := get_keyword ('where', params, '1');
  _what        := get_keyword ('what', params, '');

  -- TEMP constants -------------------------------------------------------------------
  _user_id   := get_keyword ('user_id',_user_info);
  _domain_id := 1;

  -- Page Params---------------------------------------------------------------------
  _page_params := vector (0,0,0,0,0,0,0,0);
  aset (_page_params, 0, vector ('sid', _sid));
  aset (_page_params, 1, vector ('realm', _realm));
  aset (_page_params, 2, vector ('user_info', OMAIL.WA.array2xml(_user_info)));
  aset (_page_params, 3, vector ('set', _set));
  aset (_page_params, 4, vector ('return', _return));
  aset (_page_params, 5, vector ('certificate', _certificate));
  aset (_page_params, 6, vector ('where', _where));
  aset (_page_params, 7, vector ('what', _what));

  -- XML structure-------------------------------------------------------------------
  _rs := OMAIL.WA.omail_page_params(_page_params);
  _rs := sprintf ('%s<mails>', _rs);

  declare S, C, Cname, name, mail, certificate varchar;
  declare IRIs, st, msg, meta, rows any;

  if (_certificate = '1')
  {
    cName := ', ?modulus, ?public_exponent';
    C := '?identity cert:identity ?x ; rsa:public_exponent ?public_exponent ; rsa:modulus ?modulus .';
  } else {
    cName := '';
    C := '';
  }

  -- Local contacts
  if (_where = '1')
  {
  S := 'sparql
        prefix foaf: <http://xmlns.com/foaf/0.1/>
          prefix cert: <http://www.w3.org/ns/auth/cert#>
          prefix rsa: <http://www.w3.org/ns/auth/rsa#>
          select ?nick, ?firstName, ?family_name, ?mbox, ?x
        from <%s>
        where
        {
          <%s> foaf:knows ?x.
            ?x foaf:mbox ?mbox.
            %s
          optional { ?x foaf:nick ?nick}.
          optional { ?x foaf:firstName ?firstName}.
          optional { ?x foaf:family_name ?family_name}.
        }';
    S := sprintf (S, SIOC..get_graph (), SIOC..person_iri (SIOC..user_iri (_user_id)), C);

    IRIs := vector ();
  st := '00000';
  exec (S, st, msg, vector (), 0, meta, rows);
  if ('00000' = st)
  {
    foreach (any row in rows) do
    {
        mail := row[3];
        if (isnull (mail))
          goto _skip;

      name := '';
      if (not isnull (row[0]))
        name := row[0];
      if ((not isnull (row[1])) and (not isnull (row[2])))
        name := row[1] || ' ' || row[2];

        if ((_what <> '') and (lcase (name) not like ('%' || lcase(_what) || '%')))
          goto _skip;

        _rs := sprintf ('%s<mail><name>%s</name><email>%s</email></mail>', _rs, name, OMAIL.WA.xml2string (OMAIL.WA.omail_composeAddr (name, mail)));
        IRIs := vector_concat (IRIs, vector (row[4]));

      _skip:;
    }
  }
    S := 'select P_NAME, P_FIRST_NAME, P_LAST_NAME, P_MAIL, P_CERTIFICATE, P_ID, P_DOMAIN_ID
          from AB.WA.PERSONS
         where DB.DBA.is_empty_or_null (P_MAIL) = 0
           and P_DOMAIN_ID in (select WAI_ID
                                 from DB.DBA.WA_MEMBER,
                                      DB.DBA.WA_INSTANCE
                                where WAM_USER = ?
                                  and WAM_MEMBER_TYPE = 1
                                  and WAM_INST = WAI_NAME)
       ';
  st := '00000';
  exec (S, st, msg, vector (_user_id), 0, meta, rows);
  if ('00000' = st)
  {
    foreach (any row in rows) do
    {
        name := '';
        mail := '';
        if ((_certificate = '1') and (length (row[4]) = 0))
          goto _skip2;

        if (OMAIL.WA.vector_contains (IRIs, SIOC..socialnetwork_contact_iri (row[6], row[5])))
          goto _skip2;

        name := '';
        if (not DB.DBA.is_empty_or_null (row[0]))
          name := row[0];
        if ((not DB.DBA.is_empty_or_null (row[1])) and (not DB.DBA.is_empty_or_null (row[2])))
          name := row[1] || ' ' || row[2];

        if ((_what <> '') and (lcase (name) not like ('%' || lcase(_what) || '%')))
          goto _skip2;

        mail := row[3];

        _rs := sprintf ('%s<mail><name>%s</name><email>%s</email></mail>', _rs, name, OMAIL.WA.xml2string (OMAIL.WA.omail_composeAddr (name, row[3])));

      _skip2:;
      }
    }
  }

  -- LOD contacts
  if (_where = '2')
  {
    S := 'prefix foaf: <http://xmlns.com/foaf/0.1/>
          prefix cert: <http://www.w3.org/ns/auth/cert#>
          prefix rsa: <http://www.w3.org/ns/auth/rsa#>
          select DISTINCT ?firstName, ?family_name, ?mbox
          where
          {
            ?x a foaf:Person.
            ?x foaf:mbox ?mbox.
            %s
            optional { ?x foaf:firstName ?firstName}.
            optional { ?x foaf:family_name ?family_name}.
            filter (?mbox = iri("mailto:%s"))
          }
          limit 10 offset 0';
    S := sprintf (S, cName, C, _what);
    {
      declare exit handler for sqlstate '*'
      {
        goto _end;
      };
      declare xmlData, xmlItems, tmp any;

      rows := http_client (url=>sprintf ('http://lod.openlinksw.com/sparql?query=%U&format=xml', S), timeout=>30);
      xmlData := xml_tree_doc (rows);
      xmlItems := xpath_eval ('//results/result', xmlData, 0);
      foreach (any xmlItem in xmlItems) do
      {
        name := '';
        tmp := trim (serialize_to_UTF8_xml (xpath_eval ('string(binding[@name="firstName"]/literal)', xmlItem, 1)));
        if (not DB.DBA.is_empty_or_null (tmp))
          name := tmp;
        tmp := trim (serialize_to_UTF8_xml (xpath_eval ('string(binding[@name="family_name"]/literal)', xmlItem, 1)));
        if (not DB.DBA.is_empty_or_null (tmp))
          name := name || ' ' || tmp;
        name := trim (name);

        mail := replace (serialize_to_UTF8_xml (xpath_eval ('string(binding[@name="mbox"]/uri)', xmlItem, 1)), 'mailto:', '');

        _rs := sprintf ('%s<mail><name>%s</name><email>%s</email></mail>', _rs, name, OMAIL.WA.xml2string (OMAIL.WA.omail_composeAddr (name, mail)));
      }
    }
  }

_end:;
  _rs := sprintf ('%s</mails>', _rs);
  return _rs;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_api_get_message(
  in _user_id integer,
  in _msg_id  integer)
{
  declare _params,_xml any;

  _params := vector('msg_id',_msg_id);
  _xml := OMAIL.WA.omail_open_message(1, _user_id, _params, 1, 1);
  if (_xml <> '')
    _xml := sprintf('<message>%s</message>',_xml);
  return _xml;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_api_get_url(
  in url_type varchar){

  if (url_type = 'list')
    return '/mail/box.vsp';

  if (url_type = 'write')
    return '/mail/write.vsp';

  if (url_type = 'show')
    return '/mail/open.vsp';
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_api_share(
  in pApp_id varchar,
  in pUser_id integer,
  in pObj_id integer,
  in pObj_type char,
  in pGranted_uid integer,
  in pG_type char)
{
  declare share_id integer;
  share_id := sequence_next('seq_OMAIL.WA.omail_share');

  OMAIL.WA.omail_api_share_check_params(pApp_id,pUser_id,pObj_id,pObj_type,pGranted_uid,pG_type);

  if (exists(select 1 from OMAIL.WA.SHARES where APP_ID = pApp_id and USER_ID = pUser_id and OBJ_ID = pObj_id and OBJ_TYPE = pObj_type and GRANTED_UID = pGranted_uid))
    signal('00006','This share rule already exist');

  insert into OMAIL.WA.SHARES (SHARE_ID,APP_ID,USER_ID,OBJ_ID,OBJ_TYPE,GRANTED_UID,G_TYPE)
    values (share_id,pApp_id,pUser_id,pObj_id,pObj_type,pGranted_uid,pG_type);

  return 1;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_api_unshare(
  in pApp_id varchar,
  in pUser_id integer,
  in pObj_id integer,
  in pObj_type char,
  in pGranted_uid integer)
{
  OMAIL.WA.omail_api_share_check_params(pApp_id,pUser_id,pObj_id,pObj_type,pGranted_uid,'RO');

  if (isnull (pGranted_uid) and isnull (pObj_id))
  {
    -- delete all share rules
    delete from OMAIL.WA.SHARES where APP_ID = pApp_id and USER_ID = pUser_id;

    return 1;
  }
  if (isnull (pObj_id))
  {
    -- delete all share rules for current GRANTED_UID
    delete
      from OMAIL.WA.SHARES
     where APP_ID = pApp_id and USER_ID = pUser_id and GRANTED_UID = pGranted_uid;

    return 2;
  }
  if (isnull (pGranted_uid))
  {
    -- delete all share rules for current pObj_id
    delete
      from OMAIL.WA.SHARES
           where   APP_ID = pApp_id and USER_ID = pUser_id and OBJ_ID = pObj_id and OBJ_TYPE = pObj_type;

    return 3;
  }
    -- delete all share rules for current pObj_id and current GRANTED_UID
  delete
    from OMAIL.WA.SHARES
         where   APP_ID = pApp_id and USER_ID = pUser_id and OBJ_ID = pObj_id and OBJ_TYPE = pObj_type and GRANTED_UID = pGranted_uid;

    return 4;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_api_share_check(
  in pApp_id varchar,
  in pUser_id integer,
  in pObj_id integer,
  in pObj_type char,
  in pGranted_uid integer,
  in pG_type char)
{
  OMAIL.WA.omail_api_share_check_params(pApp_id,pUser_id,pObj_id,pObj_type,pGranted_uid,pG_type);

  -- check for current GRANTED_UID and current OBJ_ID;
  if (exists(select 1 from OMAIL.WA.SHARES  where   APP_ID = pApp_id and USER_ID = pUser_id and OBJ_ID = pObj_id and OBJ_TYPE = pObj_type and GRANTED_UID = pGranted_uid and G_TYPE = pG_type))
    return 1;

  -- check for all GRANTED_UID and current OBJ_ID);
  if (exists(select 1 from OMAIL.WA.SHARES  where   APP_ID = pApp_id and USER_ID = pUser_id and OBJ_ID = pObj_id and OBJ_TYPE = pObj_type and GRANTED_UID IS NULL  and G_TYPE = pG_type))
    return 2;

  -- check for current GRANTED_UID and all OBJ_ID);
  if (exists(select 1 from OMAIL.WA.SHARES  where   APP_ID = pApp_id and USER_ID = pUser_id and OBJ_ID IS NULL and OBJ_TYPE = pObj_type and GRANTED_UID = pGranted_uid and G_TYPE = pG_type))
    return 3;

  -- check for all GRANTED_UID and all OBJ_ID);
  if (exists(select 1 from OMAIL.WA.SHARES  where   APP_ID = pApp_id and USER_ID = pUser_id and OBJ_ID IS NULL and OBJ_TYPE = pObj_type and GRANTED_UID IS NULL and G_TYPE = pG_type))
    return 4;

  return 0;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_api_share_check_params(
  in pApp_id integer,
  in pUser_id integer,
  in pObj_id integer,
  in pObj_type char,
  in pGranted_uid integer,
  in pG_type char)
{
  if (not exists(select 1 from DB.DBA.SYS_USERS  where   U_ID = pUser_id and U_IS_ROLE = 0))
    signal('00001','Non existing user');

  if (not isnull(pGranted_uid) and not exists(select 1 from DB.DBA.SYS_USERS  where   U_ID = pGranted_uid and U_IS_ROLE = 0))
    signal('00002','Non existing granted user');

  if (pGranted_uid = pUser_id)
    signal('00002','user ID = Granted User ID');

  if (pObj_type <> 'MS' and pObj_type <> 'FL')
    signal('00004','Non existing object type');

  if (not isnull(pObj_id) and pObj_type = 'MS' and not exists(select 1 from OMAIL.WA.MESSAGES  where   MSG_ID = pObj_id))
    signal('00003','Non existing object');

  if (not isnull(pObj_id) and pObj_type = 'FL' and not exists(select 1 from OMAIL.WA.FOLDERS  where   FOLDER_ID = pObj_id))
    signal('00003','Non existing object');

  if (pG_type <> 'RO' and pG_type <> 'RW')
    signal('00005','Non existing share type');
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_api_message_create_recu(
  inout pParams any,
  in    pLevel  any := null)
{
  declare _rs any;

  _rs := '';
  _rs := sprintf('%s<ref_id>%s</ref_id>\n',                               _rs, get_keyword('ref_id',    pParams));
  _rs := sprintf('%s<parent_id>%d</parent_id>\n',                         _rs, get_keyword('parent_id', pParams));
  _rs := sprintf('%s<subject><![CDATA[%s]]></subject>\n' ,                _rs, get_keyword('subject',   pParams));
  _rs := sprintf('%s<type_id>%d</type_id>\n',                             _rs, get_keyword('type_id',   pParams));
  _rs := sprintf('%s<folder_id>%d</folder_id>\n',                         _rs, get_keyword('folder_id', pParams));
  _rs := sprintf('%s<mstatus>%d</mstatus>\n',                             _rs, get_keyword('mstatus',   pParams));
  _rs := sprintf('%s<attached>%d</attached>\n',                           _rs, get_keyword('attached',  pParams));
  _rs := sprintf('%s<priority>%d</priority>\n',                           _rs, get_keyword('priority',  pParams));
  _rs := sprintf('%s<tags>%s</tags>\n',                                   _rs, get_keyword('tags',      pParams));
  _rs := sprintf('%s<address><addres_list>%s</addres_list></address>\n',  _rs, OMAIL.WA.array2xml(get_keyword('address', pParams)));
  return _rs;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_api_message_send(
  inout pParams  any,
  in    aBodyXML any := null)
{
  -----------------------------------------------------------------------------
  -- Descr: Send mail (RFC-822) through SMPT Virtuoso client
  -- Supported by: Veselin Malezanov <vmalezanov@openlinksw.bg>
  --
  -- IN:
  --  pParams -> associative array of params (subject,address,body,...)
  -- OUT: <none>
  --
  -- Structure of pParams:
  -- pParams := vector('subject',  'tema',
  --                   'mime_type','html', ['text','custom...']
  --                   'charset',  'win-1251',
  --                   'priority', '3',
  --                   'address',   vector('from',vector('name', 'veselin malezanov',
  --                                                     'email','vmalezanov@openlinksw.bg'),
  --                                       'to',  vector('name', 'vesko',
  --                                                     'email','vmalezanov@openlinksw.bg'),
  --                                       'to',  vector('name', 'tester',
  --                                                     'email','tester@example.com')),
  --                   'message_body',vector('body',Hello test test',
  --                                         'attachment',vector('name', 'filename.doc',
  --                                                         'mime-type','image/gif',
  --                                                         'content_id','43556yhgrhge456yve56y56yb56y5v6@pesho',
  --                                                         'content_transfer_encoding','base64',
  --                                                         'data','gsdfgfdgdsfgsdfgdgegegergerergergre'));

  declare sBody, sBoundary, sXsltPath, sXsltPath2, sSender, sRec varchar;
  declare pXMLMsg any;

  sXsltPath  := OMAIL.WA.omail_xslt_full('construct_mail.xsl');
  sXsltPath2 := OMAIL.WA.omail_xslt_full('construct_recip.xsl');
  sBoundary  := sprintf('------_NextPart_%s',md5(cast(now() as varchar)));
  pXMLMsg    := OMAIL.WA.omail_api_message_create_recu(pParams, 0);

  -- Construct body
  sBody := '<message>';
  sBody := sprintf('%s<boundary>%s</boundary>',sBody,sBoundary);
  sBody := sprintf('%s<charset_default>%s</charset_default>',sBody,'windows-1251');
  sBody := sprintf('%s<srv_msg_id>%s</srv_msg_id>',sBody,md5(concat(cast(now() as varchar))));
  sBody := sprintf ('%s<to_snd_date>%s</to_snd_date>',sBody,OMAIL.WA.dt_rfc822(now()));
  sBody := sprintf('%s%s',sBody,pXMLMsg);
  sBody := sprintf('%s%s',sBody,aBodyXML);
  sBody := sprintf('%s</message>',sBody);

  sBody := xslt(sXsltPath,xml_tree_doc(xml_tree(sBody)));
  sBody := cast(sBody as varchar);
  sBody := replace(sBody,CHR(10),concat('\r\n'));

  sSender := xslt(sXsltPath2,xml_tree_doc(xml_tree(concat('<fr>',pXMLMsg,'</fr>'))));
  sSender := cast(sSender as varchar);
  sRec    := xslt(sXsltPath2,xml_tree_doc(xml_tree(concat('<to>',pXMLMsg,'</to>'))));
  sRec    := cast(sRec as varchar);

  --OMAIL.WA.smtp_send_debug ('null', sSender, sRec, sBody);
  return;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_api_message_send_recu(
  in pArray any,
  in iLevel integer)
{
  if (iLevel > 15)
    signal('90002','Too deep');

  declare ind integer;
  declare sRes, sNode, sValue varchar;

  sRes := '';
  for (ind  := 0; ind < length (pArray); ind := ind + 2)
  {
    if (isstring(aref(pArray, ind)))
    {
      sNode  := lower(cast(aref(pArray, ind) as varchar));
      if (isarray(aref(pArray,ind+1)) and not isstring(aref(pArray, ind+1)))
      {
        sValue := OMAIL.WA.omail_api_message_create_recu(aref(pArray, ind+1), iLevel+1);
      }
      else if (isnull (aref(pArray,ind+1)))
      {
        sValue := '';
      } else
      {
        sValue := cast(aref(pArray,ind+1) as varchar);
        sValue := sprintf('<![CDATA[%s]]>',sValue);
      }
      sRes := sprintf('%s<%s>%s</%s>\n', sRes, sNode, sValue, sNode);
    }
  }
  return sRes;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.smtp_send_debug (
  in sServer   varchar,
  in sSender  varchar,
  in sRec     varchar,
  in sBody    varchar)
{
  -- Debug -------------
  declare _debug any;

  _debug := '\n';
  _debug := concat(_debug,'Server:',sServer,'\n=============================================================================\n');
  _debug := concat(_debug,'Recip:',sRec,'\n=============================================================================\n');
  _debug := concat(_debug,'Sender:',sSender,'\n=============================================================================\n');
  _debug := concat(_debug,sBody,'\n=============================================================================\n');

  string_to_file('debug.txt',_debug,-1);
  return;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_api_message_create(
  in _domain_id integer,
  in _user_id integer,
  in params any)
{
  declare _msg_id, _error integer;

  _msg_id := OMAIL.WA.omail_save_msg(_domain_id, _user_id, params, 0, _error);
  OMAIL.WA.omail_insert_attachment(_domain_id,_user_id,params,_msg_id,_error);
}
;

-----------------------------------------------------------------------------------------
--
create procedure OMAIL.WA.getOrderDirection (
  inout _order any,
  inout _direction any)
{
  _order     := vector ('', 'MSTATUS', 'PRIORITY', 'ADDRES_INFO', 'SUBJECT', 'RCV_DATE', 'DSIZE', 'ATTACHED', 'REF_ID');
  _direction := vector ('',' ','desc');
}
;

-----------------------------------------------------------------------------------------
--
create procedure OMAIL.WA.test_clear (
  in S any)
{
  declare N integer;

  return substring(S, 1, coalesce(strstr(S, '<>'), length(S)));
}
;

-----------------------------------------------------------------------------------------
--
create procedure OMAIL.WA.test (
  in value any,
  in params any := null)
{
  declare valueType, valueClass, valueName, valueMessage, tmp any;

  declare exit handler for SQLSTATE '*'
  {
    if (not is_empty_or_null(valueMessage))
      signal ('TEST', valueMessage || '<>');
    if (__SQL_STATE = 'EMPTY')
      signal ('TEST', sprintf('Field ''%s'' cannot be empty!<>', valueName));
    if (__SQL_STATE = 'CLASS') {
      if (valueType in ('free-text', 'tags')) {
        signal ('TEST', sprintf('Field ''%s'' contains invalid characters or noise words!<>', valueName));
      } else {
      signal ('TEST', sprintf('Field ''%s'' contains invalid characters!<>', valueName));
      }
    }
    if (__SQL_STATE = 'TYPE')
      signal ('TEST', sprintf('Field ''%s'' contains invalid characters for \'%s\'!<>', valueName, valueType));
    if (__SQL_STATE = 'MIN')
      signal ('TEST', sprintf ('''%s'' value should be greater than %s!<>', valueName, cast (tmp as varchar)));
    if (__SQL_STATE = 'MAX')
      signal ('TEST', sprintf ('''%s'' value should be less than %s!<>', valueName, cast (tmp as varchar)));
    if (__SQL_STATE = 'MINLENGTH')
      signal ('TEST', sprintf ('The length of field ''%s'' should be greater than %s characters!<>', valueName, cast (tmp as varchar)));
    if (__SQL_STATE = 'MAXLENGTH')
      signal ('TEST', sprintf ('The length of field ''%s'' should be less than %s characters!<>', valueName, cast (tmp as varchar)));
    signal ('TEST', 'Unknown validation error!<>');
    --resignal;
  };
  if (isstring (value))
  value := trim(value);

  if (is_empty_or_null(params))
    return value;

  valueClass := coalesce(get_keyword('class', params), get_keyword('type', params));
  valueType := coalesce(get_keyword('type', params), get_keyword('class', params));
  valueName := get_keyword('name', params, 'Field');
  valueMessage := get_keyword('message', params, '');
  tmp := get_keyword('canEmpty', params);
  if (isnull (tmp))
  {
    if (not isnull (get_keyword ('minValue', params)))
    {
      tmp := 0;
    }
    else if (get_keyword ('minLength', params, 0) <> 0)
    {
      tmp := 0;
    }
  }
  if (not isnull (tmp) and (tmp = 0) and is_empty_or_null (value))
  {
    signal('EMPTY', '');
  }
  else if (is_empty_or_null(value))
  {
    return value;
  }

  value := OMAIL.WA.validate2 (valueClass, cast (value as varchar));
  if (valueType = 'integer')
  {
    tmp := get_keyword('minValue', params);
    if ((not isnull(tmp)) and (value < tmp))
      signal('MIN', cast(tmp as varchar));

    tmp := get_keyword('maxValue', params);
    if (not isnull(tmp) and (value > tmp))
      signal('MAX', cast(tmp as varchar));
  }
  else if (valueType = 'float')
  {
    tmp := get_keyword('minValue', params);
    if (not isnull(tmp) and (value < tmp))
      signal('MIN', cast(tmp as varchar));

    tmp := get_keyword('maxValue', params);
    if (not isnull(tmp) and (value > tmp))
      signal('MAX', cast(tmp as varchar));
  }
  else if (valueType = 'varchar')
  {
    tmp := get_keyword('minLength', params);
    if (not isnull(tmp) and (length(value) < tmp))
      signal('MINLENGTH', cast(tmp as varchar));

    tmp := get_keyword('maxLength', params);
    if (not isnull(tmp) and (length(value) > tmp))
      signal('MAXLENGTH', cast(tmp as varchar));
  }
  return value;
}
;

-----------------------------------------------------------------------------------------
--
create procedure OMAIL.WA.validate2 (
  in propertyType varchar,
  in propertyValue varchar)
{
  declare exit handler for SQLSTATE '*'
  {
    if (__SQL_STATE = 'CLASS')
      resignal;
    signal('TYPE', propertyType);
    return;
  };

  if (propertyType = 'boolean')
  {
    if (propertyValue not in ('Yes', 'No'))
      goto _error;
  } else if (propertyType = 'integer') {
    if (isnull(regexp_match('^[0-9]+\$', propertyValue)))
      goto _error;
    return cast(propertyValue as integer);
  } else if (propertyType = 'float') {
    if (isnull(regexp_match('^[-+]?([0-9]*\.)?[0-9]+([eE][-+]?[0-9]+)?\$', propertyValue)))
      goto _error;
    return cast(propertyValue as float);
  } else if (propertyType = 'dateTime') {
    if (isnull(regexp_match('^((?:19|20)[0-9][0-9])[- /.](0[1-9]|1[012])[- /.](0[1-9]|[12][0-9]|3[01]) ([01]?[0-9]|[2][0-3])(:[0-5][0-9])?\$', propertyValue)))
      goto _error;
    return cast(propertyValue as datetime);
  } else if (propertyType = 'dateTime2') {
    if (isnull(regexp_match('^((?:19|20)[0-9][0-9])[- /.](0[1-9]|1[012])[- /.](0[1-9]|[12][0-9]|3[01]) ([01]?[0-9]|[2][0-3])(:[0-5][0-9])?\$', propertyValue)))
      goto _error;
    return cast(propertyValue as datetime);
  } else if (propertyType = 'date') {
    if (isnull(regexp_match('^((?:19|20)[0-9][0-9])[- /.](0[1-9]|1[012])[- /.](0[1-9]|[12][0-9]|3[01])\$', propertyValue)))
      goto _error;
    return cast(propertyValue as datetime);
  } else if (propertyType = 'date2') {
    if (isnull(regexp_match('^(0[1-9]|[12][0-9]|3[01])[- /.](0[1-9]|1[012])[- /.]((?:19|20)[0-9][0-9])\$', propertyValue)))
      goto _error;
    return stringdate(OMAIL.WA.dt_reformat(propertyValue, 'd.m.Y', 'Y-M-D'));
  } else if (propertyType = 'time') {
    if (isnull(regexp_match('^([01]?[0-9]|[2][0-3])(:[0-5][0-9])?\$', propertyValue)))
      goto _error;
    return cast(propertyValue as time);
  } else if (propertyType = 'folder') {
    if (isnull(regexp_match('^[^\\\/\?\*\"\'\>\<\:\|]*\$', propertyValue)))
      goto _error;
  } else if ((propertyType = 'uri') or (propertyType = 'anyuri')) {
    if (isnull(regexp_match('^(ht|f)tp(s?)\:\/\/[0-9a-zA-Z]([-.\w]*[0-9a-zA-Z])*(:(0-9)*)*(\/?)([a-zA-Z0-9\-\.\?\,\'\/\\\+&amp;%\$#_=:]*)?\$', propertyValue)))
      goto _error;
  } else if (propertyType = 'email') {
    if (isnull(regexp_match('^([a-zA-Z0-9_\-])+(\.([a-zA-Z0-9_\-])+)*@((\[(((([0-1])?([0-9])?[0-9])|(2[0-4][0-9])|(2[0-5][0-5])))\.(((([0-1])?([0-9])?[0-9])|(2[0-4][0-9])|(2[0-5][0-5])))\.(((([0-1])?([0-9])?[0-9])|(2[0-4][0-9])|(2[0-5][0-5])))\.(((([0-1])?([0-9])?[0-9])|(2[0-4][0-9])|(2[0-5][0-5]))\]))|((([a-zA-Z0-9])+(([\-])+([a-zA-Z0-9])+)*\.)+([a-zA-Z])+(([\-])+([a-zA-Z0-9])+)*))\$', propertyValue)))
      goto _error;
  } else if (propertyType = 'free-text') {
    if (length(propertyValue))
      if (not OMAIL.WA.validate_freeTexts(propertyValue))
        goto _error;
  } else if (propertyType = 'free-text-expression') {
    if (length(propertyValue))
      if (not OMAIL.WA.validate_freeText(propertyValue))
        goto _error;
  } else if (propertyType = 'tags') {
    if (not OMAIL.WA.validate_tags(propertyValue))
      goto _error;
  }
  return propertyValue;

_error:
  signal('CLASS', propertyType);
}
;

-----------------------------------------------------------------------------------------
--
create procedure OMAIL.WA.validate_xcontains (
  in S varchar)
{
  declare st, msg varchar;

  if (upper(S) in ('AND', 'NOT', 'NEAR', 'OR'))
    return 0;
  if (length (S) < 2)
    return 0;
  if (vt_is_noise (OMAIL.WA.wide2utf(S), 'utf-8', 'x-any'))
    return 0;
  return 1;
}
;

-----------------------------------------------------------------------------------------
--
create procedure OMAIL.WA.validate_freeText (
  in S varchar)
{
  declare st, msg varchar;

  if (upper(S) in ('AND', 'NOT', 'NEAR', 'OR'))
    return 0;
  if (length (S) < 2)
    return 0;
  if (vt_is_noise (OMAIL.WA.wide2utf(S), 'utf-8', 'x-ViDoc'))
    return 0;
  st := '00000';
  exec ('vt_parse (?)', st, msg, vector (S));
  if (st <> '00000')
    return 0;
  return 1;
}
;

-----------------------------------------------------------------------------------------
--
create procedure OMAIL.WA.validate_freeTexts (
  in S any)
{
  declare w varchar;

  w := regexp_match ('["][^"]+["]|[''][^'']+['']|[^"'' ]+', S, 1);
  while (w is not null)
  {
    w := trim (w, '"'' ');
    if (not OMAIL.WA.validate_freeText(w))
      return 0;
    w := regexp_match ('["][^"]+["]|[''][^'']+['']|[^"'' ]+', S, 1);
  }
  return 1;
}
;

-----------------------------------------------------------------------------------------
--
create procedure OMAIL.WA.validate_tag (
  in S varchar)
{
  S := replace(trim(S), '+', '_');
  S := replace(trim(S), ' ', '_');
  if (not OMAIL.WA.validate_freeText(S))
    return 0;
  if (not isnull(strstr(S, '"')))
    return 0;
  if (not isnull(strstr(S, '''')))
    return 0;
  if (length(S) < 2)
    return 0;
  if (length(S) > 50)
    return 0;
  return 1;
}
;

-----------------------------------------------------------------------------------------
--
create procedure OMAIL.WA.validate_tags (
  in S varchar)
{
  declare N integer;
  declare V any;

  V := OMAIL.WA.tags2vector(S);
  if (is_empty_or_null(V))
    return 0;
  if (length(V) <> length(OMAIL.WA.tags2unique(V)))
    return 0;
  for (N := 0; N < length(V); N := N + 1)
    if (not OMAIL.WA.validate_tag(V[N]))
      return 0;
  return 1;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.xml2string(
  in pXml any)
{
  declare sStream any;

  sStream := string_output();
  http_value(pXml, null, sStream);
  return string_output_string(sStream);
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.string2nntp (
  in S varchar)
{
  S := replace (S, '.', '[dot]');
  S := replace (S, '@', '[at]');
  return sprintf ('%U', S);
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.utf2wide (
  inout S any)
{
  declare exit handler for sqlstate '*' { return S; };
  return charset_recode (S, 'UTF-8', '_WIDE_');
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.wide2utf (
  inout S any)
{
  if (iswidestring (S))
  return charset_recode (S, '_WIDE_', 'UTF-8' );
  return S;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.vector_contains (
  inout aVector any,
  in value varchar)
{
  declare N integer;

  for (N := 0; N < length (aVector); N := N + 1)
    if (value = aVector[N])
      return 1;
  return 0;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.vector_unique(
  inout aVector any,
  in minLength integer := 0)
{
  declare aResult any;
  declare N, M integer;

  aResult := vector();
  for (N := 0; N < length (aVector); N := N + 1)
  {
    if ((minLength = 0) or (length (aVector[N]) >= minLength))
    {
      for (M := 0; M < length(aResult); M := M + 1)
        if (trim(aResult[M]) = trim(aVector[N]))
          goto _next;
      aResult := vector_concat(aResult, vector(trim(aVector[N])));
    }
  _next:;
  }
  return aResult;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.vector2str(
  inout aVector any,
  in delimiter varchar := ' ')
{
  declare tmp, aResult any;
  declare N integer;

  aResult := '';
  for (N := 0; N < length (aVector); N := N + 1)
  {
    tmp := trim(aVector[N]);
    if (strchr (tmp, ' ') is not null)
      tmp := concat('''', tmp, '''');
    if (N = 0)
    {
      aResult := tmp;
    } else {
      aResult := concat(aResult, delimiter, tmp);
    }
  }
  return aResult;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.vector2rs(
  inout aVector any)
{
  declare N integer;
  declare c0 varchar;

  result_names(c0);
  for (N := 0; N < length(aVector); N := N + 1)
    result(aVector[N]);
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.tagsDictionary2rs(
  inout aDictionary any)
{
  declare N integer;
  declare c0 varchar;
  declare c1 integer;
  declare V any;

  V := dict_to_vector(aDictionary, 1);
  result_names(c0, c1);
  for (N := 1; N < length(V); N := N + 2)
    result(V[N][0], V[N][1]);
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.vector2src(
  inout aVector any)
{
  declare N integer;
  declare aResult any;

  aResult := 'vector(';
  for (N := 0; N < length(aVector); N := N + 1) {
    if (N = 0)
      aResult := concat(aResult, '''', trim(aVector[N]), '''');
    if (N <> 0)
      aResult := concat(aResult, ', ''', trim(aVector[N]), '''');
  }
  return concat(aResult, ')');
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.ft2vector(
  in S any)
{
  declare w varchar;
  declare aResult any;

  aResult := vector();
  w := regexp_match ('["][^"]+["]|[''][^'']+['']|[^"'' ]+', S, 1);
  while (w is not null)
  {
    w := trim (w, '"'' ');
    if (upper(w) not in ('AND', 'NOT', 'NEAR', 'OR') and length (w) > 1 and not vt_is_noise (OMAIL.WA.wide2utf(w), 'utf-8', 'x-ViDoc'))
      aResult := vector_concat(aResult, vector(w));
    w := regexp_match ('["][^"]+["]|[''][^'']+['']|[^"'' ]+', S, 1);
  }
  return aResult;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.tag_prepare(
  inout tag varchar)
{
  if (not is_empty_or_null(tag))
  {
    tag := trim(tag);
    tag := replace(tag, '  ', ' ');
  }
  return tag;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.tag_delete(
  inout tags varchar,
  inout T any)
{
  declare N integer;
  declare new_tags any;

  new_tags := OMAIL.WA.tags2vector (tags);
  tags := '';
  N := 0;
  foreach (any new_tag in new_tags) do
  {
    if (isstring(T) and (new_tag <> T))
      tags := concat(tags, ',', new_tag);
    if (isinteger(T) and (N <> T))
      tags := concat(tags, ',', new_tag);
    N := N + 1;
  }
  return trim(tags, ',');
}
;

---------------------------------------------------------------------------------
--
create procedure OMAIL.WA.tags_rules(
  in _user_id integer,
  in _content any)
{
  declare exit handler for SQLSTATE '*' { goto _end;};

  declare i integer;
  declare rules, vectorTags, tags any;

	rules := user_tag_rules (_user_id);
	vectorTags := tag_document (_content, 0, rules);
  tags := '';
  for (i := 0; i < length(vectorTags); i := i + 2)
    tags := concat (tags, ',', vectorTags[i]);
  tags := trim(tags, ',');

_end:
  return tags;
}
;

---------------------------------------------------------------------------------
--
create procedure OMAIL.WA.tags_select(
  in  _domain_id  integer,
  in  _user_id    integer,
  in  _msg_id     integer)
{
  return coalesce((select TAGS from OMAIL.WA.MSG_PARTS where DOMAIN_ID = _domain_id and USER_ID = _user_id and MSG_ID =_msg_id and PART_ID = 1), '');
}
;

---------------------------------------------------------------------------------
--
create procedure OMAIL.WA.tags_update(
  in  _domain_id  integer,
  in  _user_id    integer,
  in  _msg_id     integer,
  in  _tags       varchar)
{
  update OMAIL.WA.MSG_PARTS
     set TAGS = _tags
   where DOMAIN_ID = _domain_id and USER_ID = _user_id and MSG_ID =_msg_id and PART_ID = 1;
}
;

---------------------------------------------------------------------------------
--
create procedure OMAIL.WA.tags_join(
  in tags varchar,
  in tags2 varchar)
{
  declare resultTags any;

  if (is_empty_or_null(tags))
    tags := '';
  if (is_empty_or_null(tags2))
    tags2 := '';

  resultTags := trim (concat(tags, ',', tags2), ',');
  resultTags := OMAIL.WA.tags2vector(resultTags);
  resultTags := OMAIL.WA.tags2unique(resultTags);
  resultTags := OMAIL.WA.vector2tags(resultTags);
  return resultTags;
}
;

---------------------------------------------------------------------------------
--
create procedure OMAIL.WA.tags2vector(
  inout tags varchar)
{
  return split_and_decode(trim(tags, ','), 0, '\0\0,');
}
;

---------------------------------------------------------------------------------
--
create procedure OMAIL.WA.tags2search(
  in tags varchar)
{
  declare S varchar;
  declare V any;

  S := '';
  V := OMAIL.WA.tags2vector(tags);
  foreach (any tag in V) do
    S := concat(S, ' ^T', replace (replace (trim(lcase(tag)), ' ', '_'), '+', '_'));
  return FTI_MAKE_SEARCH_STRING(trim(S, ','));
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.vector2tags(
  inout aVector any)
{
  declare N integer;
  declare aResult any;

  aResult := '';
  for (N := 0; N < length(aVector); N := N + 1)
    if (N = 0)
    {
      aResult := trim(aVector[N]);
    } else {
      aResult := concat(aResult, ',', trim(aVector[N]));
    }
  return aResult;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.tags2unique(
  inout aVector any)
{
  declare aResult any;
  declare N, M integer;

  aResult := vector();
  for (N := 0; N < length (aVector); N := N + 1)
  {
    for (M := 0; M < length(aResult); M := M + 1)
      if (trim(lcase(aResult[M])) = trim(lcase(aVector[N])))
        goto _next;
    aResult := vector_concat(aResult, vector(trim(aVector[N])));
  _next:;
  }
  return aResult;
}
;

---------------------------------------------------------------------------------
--
create procedure OMAIL.WA.str2vector (
  in S varchar,
  in delimiter varchar := ',')
{
  return split_and_decode(trim (S, delimiter), 0, '\0\0'||delimiter);
}
;

-------------------------------------------------------------------------------
--
-- Date / Time functions
--
-------------------------------------------------------------------------------
-- returns system time in GMT
--
create procedure OMAIL.WA.dt_current_time()
{
  return dateadd('minute', - timezone(now()),now());
}
;

-------------------------------------------------------------------------------
--
-- convert from GMT date to user timezone;
--
create procedure OMAIL.WA.dt_gmt2user(
  in pDate datetime,
  in pUser varchar := null)
{
  declare tz integer;

  if (isnull(pDate))
    return null;
  if (isnull(pUser))
    pUser := connection_get('owner_user');
  if (isnull(pUser))
    pUser := connection_get('vspx_user');
  if (isnull(pUser))
    return pDate;
  tz := cast(coalesce(USER_GET_OPTION(pUser, 'TIMEZONE'), timezone(now())/60) as integer) * 60;
  return dateadd('minute', tz, pDate);
}
;

-------------------------------------------------------------------------------
--
-- convert from the user timezone to GMT date
--
create procedure OMAIL.WA.dt_user2gmt(
  in pDate datetime,
  in pUser varchar := null)
{
  declare tz integer;

  if (isnull(pDate))
    return null;
  if (isnull(pUser))
    pUser := connection_get('owner_user');
  if (isnull(pUser))
    pUser := connection_get('vspx_user');
  if (isnull(pUser))
    return pDate;
  tz := cast(coalesce(USER_GET_OPTION(pUser, 'TIMEZONE'), 0) as integer) * 60;
  return dateadd('minute', -tz, pDate);
}
;

-----------------------------------------------------------------------------
--
create procedure OMAIL.WA.dt_value(
  in pDate datetime,
  in pDefault datetime := null,
  in pUser datetime := null)
{
  if (isnull(pDefault))
    pDefault := now();
  if (isnull(pDate))
    pDate := pDefault;
  pDate := OMAIL.WA.dt_gmt2user(pDate, pUser);
  if (OMAIL.WA.dt_format(pDate, 'D.M.Y') = OMAIL.WA.dt_format(now(), 'D.M.Y'))
    return concat('today ', OMAIL.WA.dt_format(pDate, 'H:N'));
  return OMAIL.WA.dt_format(pDate, 'D.M.Y H:N');
}
;

-----------------------------------------------------------------------------
--
create procedure OMAIL.WA.dt_format(
  in pDate datetime,
  in pFormat varchar := 'd.m.Y')
{
  declare N integer;
  declare ch, S varchar;

  declare exit handler for sqlstate '*' {
    return '';
  };

  S := '';
  for (N := 1; N <= length(pFormat); N := N + 1)
  {
    ch := substring(pFormat, N, 1);
    if (ch = 'M')
    {
      S := concat(S, xslt_format_number(month(pDate), '00'));
    }
    else if (ch = 'm')
      {
        S := concat(S, xslt_format_number(month(pDate), '##'));
    }
    else if (ch = 'Y')
        {
          S := concat(S, xslt_format_number(year(pDate), '0000'));
    }
    else if (ch = 'y')
          {
            S := concat(S, substring(xslt_format_number(year(pDate), '0000'),3,2));
    }
    else if (ch = 'd')
            {
              S := concat(S, xslt_format_number(dayofmonth(pDate), '##'));
    }
    else if (ch = 'D')
              {
                S := concat(S, xslt_format_number(dayofmonth(pDate), '00'));
    }
    else if (ch = 'H')
                {
                  S := concat(S, xslt_format_number(hour(pDate), '00'));
    }
    else if (ch = 'h')
                  {
                    S := concat(S, xslt_format_number(hour(pDate), '##'));
    }
    else if (ch = 'N')
                    {
                      S := concat(S, xslt_format_number(minute(pDate), '00'));
    }
    else if (ch = 'n')
                      {
                        S := concat(S, xslt_format_number(minute(pDate), '##'));
    }
    else if (ch = 'S')
                        {
                          S := concat(S, xslt_format_number(second(pDate), '00'));
    }
    else if (ch = 's')
                          {
                            S := concat(S, xslt_format_number(second(pDate), '##'));
    }
    else
                          {
                            S := concat(S, ch);
    }
  }
  return S;
}
;

-----------------------------------------------------------------------------------------
--
create procedure OMAIL.WA.dt_deformat(
  in pString varchar,
  in pFormat varchar := 'd.m.Y')
{
  declare y, m, d integer;
  declare N, I integer;
  declare ch varchar;

  I := 0;
  d := 0;
  m := 0;
  y := 0;
  for (N := 1; N <= length (pFormat); N := N + 1)
  {
    ch := upper(substring(pFormat, N, 1));
    if (ch = 'M')
      m := OMAIL.WA.dt_deformat_tmp(pString, I);
    if (ch = 'D')
      d := OMAIL.WA.dt_deformat_tmp(pString, I);
    if (ch = 'Y')
    {
      y := OMAIL.WA.dt_deformat_tmp(pString, I);
      if (y < 50)
        y := 2000 + y;
      if (y < 100)
        y := 1900 + y;
    }
  }
  return stringdate(concat(cast(m as varchar), '.', cast(d as varchar), '.', cast(y as varchar)));
}
;

-----------------------------------------------------------------------------
--
create procedure OMAIL.WA.dt_deformat_tmp(
  in S varchar,
  inout N varchar)
{
  declare V any;

  V := regexp_parse('[0-9]+', S, N);
  if (length (V) > 1)
  {
    N := aref(V,1);
    return atoi(subseq(S, aref(V, 0), aref(V,1)));
  }
  N := N + 1;
  return 0;
}
;

-----------------------------------------------------------------------------
--
create procedure OMAIL.WA.dt_reformat(
  in pString varchar,
  in pInFormat varchar := 'd.m.Y',
  in pOutFormat varchar := 'm.d.Y')
{
  return OMAIL.WA.dt_format(OMAIL.WA.dt_deformat(pString, pInFormat), pOutFormat);
};

-----------------------------------------------------------------------------------------
--
create procedure OMAIL.WA.dt_convert(
  in pString varchar,
  in pDefault any := null)
{
  declare exit handler for sqlstate '*' { goto _1; };
  return stringdate(pString);

_1:
  declare exit handler for sqlstate '*' { goto _2; };
  return http_string_date(pString);

_2:
  declare exit handler for sqlstate '*' { goto _end; };
  return OMAIL.WA.dt_fromRFC822 (pString);

_end:
  return pDefault;
}
;

-----------------------------------------------------------------------------------------
--
create procedure OMAIL.WA.dt_rfc1123 (
  in dt datetime)
{
  return soap_print_box (dt, '', 1);
}
;

-----------------------------------------------------------------------------------------
--
create procedure OMAIL.WA.dt_iso8601 (
  in dt datetime)
{
  return soap_print_box (dt, '', 0);
}
;

-------------------------------------------------------------------------------
--
-- Get mail format time GMT
--      and return "DAY, DD MON YYYY HH:MI:SS {+,-}HHMM"
--
------------------------------------------------------------
create procedure OMAIL.WA.dt_rfc822 (
  inout pDateTime datetime)
{
  declare d, e, h, m, y, s, k, z, zh, zm, zz varchar;
  declare days, months any;

  days := vector ('01','SUN','02','Mon','03','Thu','04','Wed','05','Thu','06','Fri','07','Sat');
  months := vector ('01','Jan','02','Feb','03','Mar','04','Apr','05','May','06','Jun','07','Jul','08','Aug','09','Sep','10','Oct','11','Nov','12','Dec');

  d  := xslt_format_number (dayofmonth (pDateTime), '00');
  m  := xslt_format_number (month (pDateTime), '00');
  h  := xslt_format_number (hour (pDateTime), '00');
  e  := xslt_format_number (minute (pDateTime), '00');
  s  := xslt_format_number (second (pDateTime), '00');
  k  := xslt_format_number (dayofweek (pDateTime), '00');
  y  := cast (year (pDateTime) as varchar);
  z  := timezone (pDateTime);
  if (z < 0)
  {
    zz := '-';
    z := z-(2*z);
  } else {
    zz := '+';
  }
  zh := xslt_format_number (z/60, '00');
  zm := xslt_format_number (mod (z, 60), '00');

  return sprintf ('%s, %s %s %s %s:%s:%s %s%s%s', get_keyword (k, days), d, get_keyword (m, months), y, h, e, s, zz, zh, zm);
}
;

-------------------------------------------------------------------------------
--
-- Get mail format "DAY, DD MON YYYY HH:MI:SS {+,-}HHMM"
--		  and return "DD.MM.YYYY HH:MI:SS" GMT
--
-------------------------------------------------------------------------------
create procedure OMAIL.WA.dt_fromRFC822 (
  in _mdate varchar)
{
	declare _arr, months, rs, tzone_z, tzone_h, tzone_m any;
	declare d, m, y, hms, tzone varchar;

	_arr := split_and_decode (trim(_mdate), 0, '\0\0 ');
	if (length(_arr) = 6)
	{
	  months := vector ('JAN', '01', 'FEB', '02', 'MAR', '03', 'APR', '04', 'MAY', '05', 'JUN', '06', 'JUL', '07', 'AUG', '08', 'SEP', '09', 'OCT', '10', 'NOV', '11', 'DEC', '12');
		d   := _arr[1];
		m   := get_keyword (upper(_arr[2]), months);
		y   := _arr[3];
		hms := _arr[4];
		tzone   := _arr[5];
		tzone_z := substring (tzone, 1, 1);
		tzone_h := atoi (substring (tzone, 2, 2));
		tzone_m := atoi (substring (tzone, 4, 2));
	  if (tzone_z = '+')
	  {
	    tzone_h := tzone_h - 2 * tzone_h;
	    tzone_m := tzone_m - 2 * tzone_m;
		}
	  rs := stringdate (sprintf ('%s.%s.%s %s', m, d, y, hms));
	  rs := dateadd ('hour',   tzone_h, rs);
	  rs := dateadd ('minute', tzone_m, rs);
	}
	else
	{
	  rs := stringdate('01.01.1900 00:00:00'); -- set system date
	}
	return rs;
}
;

-----------------------------------------------------------------------------------------
--
create procedure OMAIL.WA.dt_string (
  in d varchar,
  in m varchar,
  in y varchar)
{
  return sprintf('%s.%s.%s', right(concat('0', d), 2), right(concat('0', m), 2), y);
}
;

create procedure OMAIL.WA.dt_now (
  in tz integer := null)
{
  if (isnull (tz))
    tz := timezone (now());
  return dateadd ('minute', tz - timezone (now()), now());
}
;

-----------------------------------------------------------------------------
--
create procedure OMAIL.WA.dt_decode (
  inout pDateTime datetime,
  inout pYear integer,
  inout pMonth integer,
  inout pDay integer,
  inout pHour integer,
  inout pMinute integer)
{
  pYear := year (pDateTime);
  pMonth := month (pDateTime);
  pDay := dayofmonth (pDateTime);
  pHour := hour (pDateTime);
  pMinute := minute (pDateTime);
}
;

-----------------------------------------------------------------------------
--
create procedure OMAIL.WA.dt_encode (
  in pYear integer,
  in pMonth integer,
  in pDay integer,
  in pHour integer,
  in pMinute integer,
  in pSeconds integer := 0)
{
  return stringdate (sprintf ('%d.%d.%d %d:%d:%d', pYear, pMonth, pDay, pHour, pMinute, pSeconds));
}
;

-----------------------------------------------------------------------------
--
create procedure OMAIL.WA.dt_dateDecode(
  inout pDate date,
  inout pYear integer,
  inout pMonth integer,
  inout pDay integer)
{
  pYear := year (pDate);
  pMonth := month (pDate);
  pDay := dayofmonth (pDate);
}
;

-----------------------------------------------------------------------------
--
create procedure OMAIL.WA.dt_dateEncode(
  in pYear integer,
  in pMonth integer,
  in pDay integer)
{
  return cast (stringdate (sprintf ('%d.%d.%d', pYear, pMonth, pDay)) as date);
}
;

--------------------------------------------------------------------------------
--
create procedure OMAIL.WA.dt_curdate (
  in tz integer := null)
{
  declare pYear, pMonth, pDay integer;
  declare dt date;

  if (isnull (tz))
    tz := timezone (now());
  return OMAIL.WA.dt_dateClear (dateadd ('minute', tz - timezone (now()), now()));
}
;

--------------------------------------------------------------------------------
--
create procedure OMAIL.WA.dt_dateClear (
  in pDate date)
{
  declare pYear, pMonth, pDay integer;

  if (isnull (pDate))
    return pDate;
  OMAIL.WA.dt_dateDecode (pDate, pYear, pMonth, pDay);
  return OMAIL.WA.dt_dateEncode (pYear, pMonth, pDay);
}
;

create procedure OMAIL.WA.dt_WeekDay (
  in dt datetime,
  in weekStarts varchar := 'm')
{
  declare dw integer;

  dw := dayofweek (dt);
  if (weekStarts = 'm')
  {
    if (dw = 1)
      return 7;
    return dw - 1;
  }
  return dw;
}
;

-----------------------------------------------------------------------------------------
--
create procedure OMAIL.WA.dt_BeginOfWeek (
  in dt date,
  in weekStarts varchar := 'm')
{
  return OMAIL.WA.dt_dateClear (dateadd ('day', 1-OMAIL.WA.dt_WeekDay (dt, weekStarts), dt));
}
;

-----------------------------------------------------------------------------------------
--
create procedure OMAIL.WA.dt_EndOfWeek (
  in dt date,
  in weekStarts varchar := 'm')
{
  return OMAIL.WA.dt_dateClear (dateadd ('day', -1, dateadd ('day', 7, OMAIL.WA.dt_BeginOfWeek (dt, weekStarts))));
}
;

-----------------------------------------------------------------------------------------
--
create procedure OMAIL.WA.dt_BeginOfMonth (
  in dt datetime)
{
  return dateadd ('day', -(dayofmonth (dt)-1), dt);
}
;

-----------------------------------------------------------------------------------------
--
create procedure OMAIL.WA.dt_EndOfMonth (
  in dt datetime)
{
  return dateadd ('day', -1, dateadd ('month', 1, OMAIL.WA.dt_BeginOfMonth (dt)));
}
;

-----------------------------------------------------------------------------------------
--
create procedure OMAIL.WA.dt_LastDayOfMonth (
  in dt datetime)
{
  return dayofmonth (OMAIL.WA.dt_EndOfMonth (dt));
}
;

-----------------------------------------------------------------------------------------
--
create procedure OMAIL.WA.dt_BeginOfYear (
  in dt datetime)
{
  declare pYear, pMonth, pDay integer;

  if (isnull (dt))
    return dt;
  OMAIL.WA.dt_dateDecode (dt, pYear, pMonth, pDay);
  return OMAIL.WA.dt_dateEncode (pYear, 1, 1);
}
;

-----------------------------------------------------------------------------------------
--
create procedure OMAIL.WA.hex2number (
  in S varchar)
{
  if (S <= '9')
    return cast (S as integer);

  S := lcase (S);
  return 10 + S[0] - ascii('a');
}
;

-----------------------------------------------------------------------------------------
--
create procedure OMAIL.WA.hex2bin (
  in S varchar)
{
  declare N integer;
  declare retValue varchar;

  retValue := repeat (' ', length (S) / 2);
  for (N := 0; N < length (retValue); N := N + 1)
  {
    retValue[N] := OMAIL.WA.hex2number (substring(S, 2*N+1, 1))*16 + OMAIL.WA.hex2number (substring(S, 2*N+2, 1));
  }
  return retValue;
}
;

-----------------------------------------------------------------------------------------
--
-- DCC procedures
--
-----------------------------------------------------------------------------------------
create procedure OMAIL.WA.discussion_check ()
{
  if (isnull (VAD_CHECK_VERSION ('Discussion')))
    return 0;
  return 1;
}
;

-----------------------------------------------------------------------------------------
--
create procedure OMAIL.WA.dcc_address (
  in _dcc integer,
  in _from varchar)
{
  declare N integer;
  declare domain_id, user_id, conversaton_id integer;
  declare dcc_domain, dcc_address varchar;

  domain_id := OMAIL.WA.domain_id(_from);
  if (isnull(domain_id))
    return '';

  user_id := OMAIL.WA.domain_owner_id(domain_id);
  if (isnull(user_id))
    return '';

  whenever not found goto _skip;

  conversaton_id := null;
  dcc_address := null;
  select C_ID, C_ADDRESS into conversaton_id, dcc_address from OMAIL.WA.CONVERSATION where C_DOMAIN_ID = domain_id and C_DESCRIPTION = _dcc;

_skip:
  if (not isnull(dcc_address))
    return dcc_address;
	N := strchr (_from, '@');
	dcc_address := subseq (_from, N, length (_from));
  insert into OMAIL.WA.CONVERSATION (C_DOMAIN_ID, C_USER_ID, C_ADDRESS, C_ADDRESSES, C_DESCRIPTION, C_TS)
    values (domain_id, user_id, dcc_address, _from, _dcc, now());

  insert soft OMAIL.WA.FOLDERS(DOMAIN_ID, USER_ID, FOLDER_ID, NAME)
    values (domain_id, user_id, 100, 'Inbox');

  return connection_get('conversation_address');
}
;

-----------------------------------------------------------------------------------------
--
create procedure OMAIL.WA.dcc_update (
  in address varchar,
  in addresses varchar)
{
  update OMAIL.WA.CONVERSATION
     set C_ADDRESSES = addresses
   where C_ADDRESS = address;
}
;

-----------------------------------------------------------------------------------------
--
create procedure OMAIL.WA.rfc_id ()
{
  return sprintf ('%s@%s', uuid (), sys_stat ('st_host_name'));
}
;

-----------------------------------------------------------------------------------------
--
-- NNTP Conversation
--
-----------------------------------------------------------------------------------------
--
create procedure OMAIL.WA.make_rfc_id (
  in conversation_id integer,
  in comment_id integer := null)
{
  declare hashed, host any;

  hashed := md5 (uuid ());
  host := sys_stat ('st_host_name');
  if (isnull(comment_id))
    return sprintf ('<%d.%s@%s>', conversation_id, hashed, host);
  return sprintf ('<%d.%d.%s@%s>', conversation_id, comment_id, hashed, host);
}
;

-----------------------------------------------------------------------------------------
--
create procedure OMAIL.WA.make_mail_subject (
  in txt any,
  in id varchar := null)
{
  declare enc any;

  enc := encode_base64 (OMAIL.WA.wide2utf (txt));
  enc := replace (enc, '\r\n', '');
  txt := concat ('Subject: =?UTF-8?B?', enc, '?=\r\n');
  if (not isnull(id))
    txt := concat (txt, 'X-Virt-NewsID: ', uuid (), ';', id, '\r\n');
  return txt;
}
;

-----------------------------------------------------------------------------------------
--
create procedure OMAIL.WA.make_post_rfc_header (
  in mid varchar,
  in refs varchar,
  in gid varchar,
  in title varchar,
  in rec datetime,
  in author_mail varchar)
{
  declare ses any;

  ses := string_output ();
  http (OMAIL.WA.make_mail_subject (title), ses);
  http (sprintf ('Date: %s\r\n', DB.DBA.date_rfc1123 (rec)), ses);
  http (sprintf ('Message-Id: %s\r\n', mid), ses);
  if (not isnull(refs))
    http (sprintf ('References: %s\r\n', refs), ses);
  http (sprintf ('From: %s\r\n', author_mail), ses);
  http ('Content-Type: text/html; charset=UTF-8\r\n', ses);
  http (sprintf ('Newsgroups: %s\r\n\r\n', gid), ses);
  ses := string_output_string (ses);
  return ses;
}
;

-----------------------------------------------------------------------------------------
--
create procedure OMAIL.WA.make_post_rfc_msg (
  inout head varchar,
  inout body varchar,
  in tree int := 0)
{
  declare ses any;

  ses := string_output ();
  http (coalesce(head, ''), ses);
  http (coalesce(body, ''), ses);
  http ('\r\n.\r\n', ses);
  ses := string_output_string (ses);
  if (tree)
    ses := serialize (mime_tree (ses));
  return ses;
}
;

-----------------------------------------------------------------------------------------
--
create procedure OMAIL.WA.nntp_update (
  in _domain_id integer,
  in oConversation integer,
  in nConversation integer)
{
  declare nntpGroup integer;
  declare nInstance, nDescription varchar;

  if (isnull(nConversation))
    return;

  if (nConversation = 0 and oConversation = 0)
    return;

  nInstance := OMAIL.WA.domain_nntp_name (_domain_id);
  if (oConversation = 1 and nConversation = 0)
  {
    delete from DB.DBA.NEWS_MULTI_MSG where NM_GROUP = nntpGroup;
    nntpGroup := (select NG_GROUP from DB..NEWS_GROUPS where NG_NAME = nInstance);
    delete from DB.DBA.NEWS_MULTI_MSG where NM_GROUP = nntpGroup;
    delete from DB.DBA.NEWS_GROUPS where NG_NAME = nInstance;

    delete from OMAIL.WA.CONVERSATION where C_DOMAIN_ID = _domain_id;
    if (_domain_id <> 1) {
      delete from OMAIL.WA.MSG_PARTS where DOMAIN_ID = _domain_id;
      delete from OMAIL.WA.MESSAGES  where DOMAIN_ID = _domain_id;
      delete from OMAIL.WA.FOLDERS   where DOMAIN_ID = _domain_id;
    }
    return;
  }

  nDescription := OMAIL.WA.domain_description(_domain_id);
  if (oConversation = 0 and nConversation = 1) {
    declare exit handler for sqlstate '*' { return; };

    if (not exists (select 1 from DB..NEWS_GROUPS where NG_NAME = nInstance))
      insert into DB.DBA.NEWS_GROUPS (NG_NEXT_NUM, NG_NAME, NG_DESC, NG_SERVER, NG_POST, NG_UP_TIME, NG_CREAT, NG_UP_INT, NG_PASS, NG_UP_MESS, NG_NUM, NG_FIRST, NG_LAST, NG_LAST_OUT, NG_CLEAR_INT, NG_TYPE)
        values (0, nInstance, nDescription, null, 1, now(), now(), 30, 0, 0, 0, 0, 0, 0, 120, 'MAIL');
    return;
  }
}
;

-----------------------------------------------------------------------------------------
--
create procedure OMAIL.WA.mail_address_split (
  in author any,
  out person any,
  out email any)
{
  declare pos int;

  person := '';
  pos := strchr (author, '<');
  if (pos is not NULL)
  {
    person := "LEFT" (author, pos);
    email := subseq (author, pos, length (author));
    email := replace (email, '<', '');
    email := replace (email, '>', '');
    person := trim (replace (person, '"', ''));
  } else {
    pos := strchr (author, '(');
    if (pos is not NULL) {
	    email := trim ("LEFT" (author, pos));
	    person :=  subseq (author, pos, length (author));
	    person := replace (person, '(', '');
	    person := replace (person, ')', '');
	  }
  }
}
;

-----------------------------------------------------------------------------------------
--
create procedure OMAIL.WA.nntp_decode_subject (
  inout str varchar)
{
  declare match varchar;
  declare inx int;

  inx := 50;

  str := replace (str, '\t', '');

  match := regexp_match ('=\\?[^\\?]+\\?[A-Z]\\?[^\\?]+\\?=', str);
  while (match is not null and inx > 0)
  {
    declare enc, ty, dat, tmp, cp, dec any;

    cp := match;
    tmp := regexp_match ('^=\\?[^\\?]+\\?[A-Z]\\?', match);

    match := substring (match, length (tmp)+1, length (match) - length (tmp) - 2);

    enc := regexp_match ('=\\?[^\\?]+\\?', tmp);

    tmp := replace (tmp, enc, '');

    enc := trim (enc, '?=');
    ty := trim (tmp, '?');

    if (ty = 'B') {
	    dec := decode_base64 (match);
	  } else if (ty = 'Q') {
	    dec := uudecode (match, 12);
	  } else {
	    dec := '';
	  }
    declare exit handler for sqlstate '2C000' { return;};
    dec := charset_recode (dec, enc, 'UTF-8');

    str := replace (str, cp, dec);

    match := regexp_match ('=\\?[^\\?]+\\?[A-Z]\\?[^\\?]+\\?=', str);
    inx := inx - 1;
  }
}
;

-----------------------------------------------------------------------------------------
--
create procedure OMAIL.WA.nntp_process_parts (
  in parts any,
  inout body varchar,
  inout amime any,
  out result any,
  in any_part int)
{
  declare name1, mime1, name, mime, enc, content, charset varchar;
  declare i, i1, l1, is_allowed int;
  declare part any;

  if (not isarray (result))
    result := vector ();

  if (not isarray (parts) or not isarray (parts[0]))
    return 0;

  part := parts[0];

  name1 := get_keyword_ucase ('filename', part, '');
  if (name1 = '')
    name1 := get_keyword_ucase ('name', part, '');

  mime1 := get_keyword_ucase ('Content-Type', part, '');
  charset := get_keyword_ucase ('charset', part, '');

  if (mime1 = 'application/octet-stream' and name1 <> '')
    mime1 := http_mime_type (name1);

  is_allowed := 0;
  i1 := 0;
  l1 := length (amime);
  while (i1 < l1)
  {
    declare elm any;
    elm := trim(amime[i1]);
    if (mime1 like elm)
    {
      is_allowed := 1;
      i1 := l1;
    }
    i1 := i1 + 1;
  }

  declare _cnt_disp any;
  _cnt_disp := get_keyword_ucase('Content-Disposition', part, '');

  if (is_allowed and (any_part or (name1 <> '' and _cnt_disp in ('attachment', 'inline'))))
  {
    name := name1;
    mime := mime1;
    enc := get_keyword_ucase ('Content-Transfer-Encoding', part, '');
    content := subseq (body, parts[1][0], parts[1][1]);
    if (enc = 'base64')
      content := decode_base64 (content);
    result := vector_concat (result, vector (vector (name, mime, content, _cnt_disp, enc, charset)));
    return 1;
  }

  -- process the parts
  if (isarray (parts[2]))
    for (i := 0; i < length (parts[2]); i := i + 1)
      OMAIL.WA.nntp_process_parts (parts[2][i], body, amime, result, any_part);

  return 0;
}
;

-----------------------------------------------------------------------------------------
--
DB.DBA.NNTP_NEWS_MSG_ADD (
'MAIL',
'select
   \'MAIL\',
   C_RFC_ID,
   C_RFC_REFERENCES,
   0,    -- NM_READ
   C_USER_ID,
   C_TS,
   0,    -- NM_STAT
   null, -- NM_TRY_POST
   0,    -- NM_DELETED
   OMAIL.WA.make_post_rfc_msg (C_RFC_HEADER, C_DESCRIPTION, 1), -- NM_HEAD
   OMAIL.WA.make_post_rfc_msg (C_RFC_HEADER, C_DESCRIPTION),
   C_ID
 from OMAIL.WA.CONVERSATION

 union all

 select
   \'MAIL\',
   a.M_RFC_ID,
   a.M_RFC_REFERENCES,
   0,    -- NM_READ
   a.USER_ID,
   a.RCV_DATE,
   0,    -- NM_STAT
   null, -- NM_TRY_POST
   0,    -- NM_DELETED
   OMAIL.WA.make_post_rfc_msg (a.M_RFC_HEADER, b.TDATA, 1), -- NM_HEAD
   OMAIL.WA.make_post_rfc_msg (a.M_RFC_HEADER, b.TDATA),
   a.FREETEXT_ID
 from OMAIL.WA.MESSAGES a
        join OMAIL.WA.MSG_PARTS b ON b.DOMAIN_ID = a.DOMAIN_ID and b.USER_ID = a.USER_ID and b.MSG_ID = a.MSG_ID and b.PART_ID = 1
          join OMAIL.WA.CONVERSATION c ON c.C_DOMAIN_ID = a.DOMAIN_ID and c.C_USER_ID = a.USER_ID
 where a.DOMAIN_ID <> 1
'
)
;

-----------------------------------------------------------------------------------------
--
create procedure DB.DBA.MAIL_NEWS_MSG_I (
  inout N_NM_ID any,
  inout N_NM_REF any,
  inout N_NM_READ any,
  inout N_NM_OWN any,
  inout N_NM_REC_DATE any,
  inout N_NM_STAT any,
  inout N_NM_TRY_POST any,
  inout N_NM_DELETED any,
  inout N_NM_HEAD any,
  inout N_NM_BODY any)
{
  declare _domain_id, _user_id, _address, _addresses, _msg_id, _params, _error any;
  declare tree, head, contentType, cset, content, subject, refs any;
  declare _request, _respond any;

  if (isnull (N_NM_REF) and isnull (connection_get ('vspx_user')))
    signal ('CONVA', 'The post cannot be done via news client, this requires authentication.');

  tree        := deserialize (N_NM_HEAD);
  head        := tree [0];

  subject := get_keyword_ucase ('Subject', head);
  if (not isnull(subject))
    OMAIL.WA.nntp_decode_subject (subject);

  contentType := get_keyword_ucase ('Content-Type', head, 'text/plain');
  cset        := upper (get_keyword_ucase ('charset', head));
  if (contentType like 'text/%')
  {
    declare st, en int;
    declare last any;

    st := tree[1][0];
    en := tree[1][1];

    if (en > st + 5)
    {
	    last := subseq (N_NM_BODY, en - 4, en);
  	  if (last = '\r\n.\r')
	      en := en - 4;
	  }
    content := subseq (N_NM_BODY, st, en);
    if (cset is not null and cset <> 'UTF-8')
    {
	    declare exit handler for sqlstate '2C000' { goto next_1;};
	    content := charset_recode (content, cset, 'UTF-8');
	  }
  next_1:;
  }
  else if (contentType like 'multipart/%')
  {
    declare res, best_cnt any;

    declare exit handler for sqlstate '*' {	signal ('CONVX', __SQL_MESSAGE);};

    OMAIL.WA.nntp_process_parts (tree, N_NM_BODY, vector ('text/%'), res, 1);

    best_cnt := null;
    content := null;
    foreach (any elm in res) do
    {
      if (elm[1] = 'text/html' and (content is null or best_cnt = 'text/plain'))
      {
	      best_cnt := 'text/html';
	      content := elm[2];
        if (elm[4] = 'quoted-printable')
        {
		      content := uudecode (content, 12);
		    } else if (elm[4] = 'base64') {
		      content := decode_base64 (content);
		    }
		    cset := elm[5];
      }
      else if (best_cnt is null and elm[1] = 'text/plain')
      {
	      content := elm[2];
	      best_cnt := 'text/plain';
	      cset := elm[5];
	    }
  	  if (elm[1] not like 'text/%')
	      signal ('CONVX', sprintf ('The post contains parts of type [%s] which is prohibited.', elm[1]));
	  }
    if (length (cset) and cset <> 'UTF-8')
    {
	    declare exit handler for sqlstate '2C000' { goto next_2;};
	    content := charset_recode (content, cset, 'UTF-8');
	  }
  next_2:;
  } else
    signal ('CONVX', sprintf ('The content type [%s] is not supported', contentType));

  if (not isnull (N_NM_REF))
  {
    refs := split_and_decode (N_NM_REF, 0, '\0\0 ');
    if (length (refs))
    {
      select C_DOMAIN_ID,
             C_USER_ID,
             C_ADDRESS,
             C_ADDRESSES
        into _domain_id,
             _user_id,
             _address,
             _addresses
        from OMAIL.WA.CONVERSATION
       where C_RFC_ID = refs[0];

      _params := vector('folder_id', 100,
                        'from',      _address,
                         'to',             OMAIL.WA.omail_address2str ('to', _addresses, 3),
                        'subject',   subject,
                        'message',   content,
                        'rfc_id',    N_NM_ID,
                         'rfc_references', N_NM_REF);
    }
    _msg_id := 0;
    _msg_id := OMAIL.WA.omail_save_msg (_domain_id, _user_id, _params, _msg_id, _error);
    _request := sprintf ('http://' || DB.DBA.http_get_host () || '/oMail/res/flush.vsp?did=%s&uid=%s&mid=%s&addr=%U', cast(_domain_id as varchar), cast(_user_id as varchar), cast(_msg_id as varchar), _address);
    http_get (_request, _respond);
    
  } else {
      declare  _to,_use_ngroup varchar;
      declare _ngroups any;
      declare i int;

      _use_ngroup:='';


      _ngroups := split_and_decode (get_keyword_ucase ('Newsgroups', head, ''), 0, '\0\0,');
      for (i:=0;i<length(_ngroups);i:=i+1)
      {
        if(locate('ods.mail',_ngroups[i]))
        {
           _use_ngroup:=_ngroups[i];
      if(length(_use_ngroup)=0)
            signal ('CONVX', 'There is no ODS mail newsgroup to post.');
      

      {
      declare exit handler for not found{
                                             signal ('CONVX', 'Newsgroup does not corresponds to mail instance.');
                                        };
      
      select  WAI_ID,WAI_NAME,WAM_USER into _domain_id,_to,_user_id from WA_INSTANCE,WA_MEMBER,NEWS_GROUPS
              where OMAIL.WA.domain_nntp_name (WAI_ID)=NG_NAME and
                    WAI_NAME=WAM_INST and
                    WAM_MEMBER_TYPE =1 and
                    NG_NAME=_use_ngroup;
      }             
      

      _address :=  get_keyword_ucase ('From', head, 'nobody@unknown');
          if(not exists(select 1 from OMAIL.WA.FOLDERS where domain_id=_domain_id and user_id=_user_id and folder_id=100) )
          {
              OMAIL.WA.dcc_address(_address,_to);
          }
      _params := vector ('folder_id',      100,
                         'from',           _address,
                         'to',             _to,
                         'dcc',            _to,
                         'subject',        subject,
                         'message',        content,
                         'rfc_id',         N_NM_ID  
                        );
    
      _msg_id := 0;
      _msg_id := OMAIL.WA.omail_save_msg (_domain_id, _user_id, _params, _msg_id, _error);
      _request := sprintf('http://' || DB.DBA.http_get_host () || '/oMail/res/flush.vsp?did=%s&uid=%s&mid=%s&addr=%U', cast(_domain_id as varchar), cast(_user_id as varchar), cast(_msg_id as varchar), _address);
      http_get (_request, _respond);
    
}
      }

  }

}
;


-----------------------------------------------------------------------------------------
--
create procedure DB.DBA.MAIL_NEWS_MSG_U (
  inout O_NM_ID any,
  inout N_NM_ID any,
  inout N_NM_REF any,
  inout N_NM_READ any,
  inout N_NM_OWN any,
  inout N_NM_REC_DATE any,
  inout N_NM_STAT any,
  inout N_NM_TRY_POST any,
  inout N_NM_DELETED any,
  inout N_NM_HEAD any,
  inout N_NM_BODY any)
{
  return;
}
;

-----------------------------------------------------------------------------------------
--
create procedure DB.DBA.MAIL_NEWS_MSG_D (
  inout O_NM_ID any)
{
  signal ('CONV3', 'Delete of a mail comment is not allowed');
}
;

-----------------------------------------------------------------------------------------
--
create procedure OMAIL.WA.GET_ODS_BAR (
  inout _params any,
  inout _lines any)
{
  return ODS.BAR._EXEC('oMail', deserialize(_params), deserialize(_lines));
}
;

-----------------------------------------------------------------------------------------
--
create procedure OMAIL.WA.get_copyright ()
{
  return coalesce ((select top 1 wa_utf8_to_wide (replace (WS_COPYRIGHT, '&copy;', '(C)')) from WA_SETTINGS), '');
}
;

-----------------------------------------------------------------------------------------
--
grant execute on OMAIL.WA.GET_ODS_BAR to public;
grant execute on OMAIL.WA.get_copyright to public;

xpf_extension ('http://www.openlinksw.com/mail/:getODSBar', 'OMAIL.WA.GET_ODS_BAR');
xpf_extension ('http://www.openlinksw.com/mail/:getCopyright', 'OMAIL.WA.get_copyright');

-----------------------------------------------------------------------------------------
--
create procedure OMAIL.WA.check_app (
  in _user_id integer,
  in _app_type varchar)
{
  return coalesce((select top 1 WAI_ID from DB.DBA.WA_MEMBER, DB.DBA.WA_INSTANCE where WAM_INST = WAI_NAME and WAM_USER = _user_id and WAI_TYPE_NAME = _app_type order by WAI_ID), 0);
}
;

-----------------------------------------------------------------------------------------
--
create procedure OMAIL.WA.spam_update ()
{
  if (registry_get ('_oMail_spam_') <> '1')
  {
    for (select DOMAIN_ID as _domain_id, USER_ID as _user_id from OMAIL.WA.FOLDERS where FOLDER_ID = 100) do
     insert soft OMAIL.WA.FOLDERS(DOMAIN_ID, USER_ID, FOLDER_ID, NAME) values (_domain_id, _user_id, 125, 'Spam');
}
  registry_set ('_oMail_spam_', '1');
}
;

OMAIL.WA.spam_update ()
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.obj2json (
  in o any,
  in d integer := 2)
{
  declare N, M integer;
  declare R, T any;
  declare retValue any;

  if (d = 0)
    return '[maximum depth achieved]';

  T := vector ('\b', '\\b', '\t', '\\t', '\n', '\\n', '\f', '\\f',  '\r', '\\r', '"', '\\"', '\\', '\\\\');
  retValue := '';
  if (isnumeric (o))
  {
    retValue := cast (o as varchar);
  }
  else if (isstring (o))
  {
    for (N := 0; N < length(o); N := N + 1)
    {
      R := chr (o[N]);
      for (M := 0; M < length(T); M := M + 2)
      {
        if (R = T[M])
          R := T[M+1];
      }
      retValue := retValue || R;
    }
    retValue := '"' || retValue || '"';
  }
  else if (isarray (o))
  {
    retValue := '[';
    for (N := 0; N < length(o); N := N + 1)
    {
      retValue := retValue || OMAIL.WA.obj2json (o[N], d-1);
      if (N <> length(o)-1)
        retValue := retValue || ',\n';
    }
    retValue := retValue || ']';
  }
  return retValue;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.json2obj (
  in o any)
{
  return json_parse (o);
}
;

-----------------------------------------------------------------------------
--
create procedure OMAIL.WA.dc_predicateMetas (inout anArray any)
{
  anArray := vector (
    'subject'     , vector (1, 'Subject',     'varchar',  'varchar',  vector ()),
    'message'     , vector (1, 'Body',        'text',     'varchar',  vector ()),
    'from'        , vector (1, 'From',        'address',  'varchar',  vector ()),
    'to'          , vector (1, 'To',          'address',  'varchar',  vector ()),
    'cc'          , vector (1, 'CC',          'address',  'varchar',  vector ()),
    'return-path' , vector (1, 'Return-path', 'address',  'varchar',  vector ()),
    'rcv_date'    , vector (1, 'Date',        'datetime', 'datetime', vector ('size', '10', 'onclick', 'datePopup(\'-FIELD-\')', 'button', '<img id="-FIELD-_select" border="0" src="/oMail/i/pick_calendar.gif" onclick="javascript: datePopup(\'-FIELD-\');" />')),
    'priority'    , vector (1, 'Priority',    'priority', 'integer',  vector ()),
    'status'      , vector (0, 'Status',      'varchar',  'varchar',  vector ()),
    'dsize'        , vector (1, 'Size',              'integer',  'integer',  vector ()),
    'ssl'          , vector (1, 'Signed',            'boolean',  'boolean',  vector ()),
    'sslVerified'  , vector (1, 'Signed (Verified)', 'boolean',  'boolean',  vector ()),
    'webID'        , vector (1, 'WebID',             'varchar',  'varchar',  vector ()),
    'webIDVerified', vector (1, 'WebID (Verified)',  'boolean',  'boolean',  vector ())
  );
}
;

-----------------------------------------------------------------------------
--
create procedure OMAIL.WA.dc_compareMetas (inout anArray any)
{
  anArray := vector (
    '=',                      vector ('equal to'                 , vector ('integer', 'datetime', 'varchar', 'address', 'priority', 'boolean'), 1, 'case when (^{value}^ = ^{pattern}^) then 1 else 0 end'),
    '<>',                     vector ('not equal to'             , vector ('integer', 'datetime', 'varchar', 'address', 'priority', 'boolean'), 1, 'case when (^{value}^ <> ^{pattern}^) then 1 else 0 end'),
    '<',                      vector ('less than'                , vector ('integer', 'datetime', 'priority'), 1, 'case when (^{value}^ <= ^{pattern}^) then 1 else 0 end'),
    '>',                      vector ('greater than'             , vector ('integer', 'datetime', 'priority')                      , 1, 'case when (^{value}^ > ^{pattern}^) then 1 else 0 end'),
    '>=',                     vector ('greater than or equal to' , vector ('integer', 'datetime', 'priority')                      , 1, 'case when (^{value}^ >= ^{pattern}^) then 1 else 0 end'),
    'like',                   vector ('like'                     , vector ('varchar', 'address')                                   , 1, 'case when (^{value}^ like ^{pattern}^) then 1 else 0 end'),
    'is_substring_of',        vector ('is substring of'          , vector ('varchar')                                              , 1, 'case when (strstr (^{pattern}^, ^{value}^) is not null) then 1 else 0 end'),
    'contains_substring',     vector ('contains substring'       , vector ('varchar', 'address')                                   , 1, 'case when (strstr (^{value}^, ^{pattern}^) is not null) then 1 else 0 end'),
    'not_contains_substring', vector ('not contains substring'   , vector ('varchar', 'address')                                   , 1, 'case when (strstr (^{value}^, ^{pattern}^) is null) then 1 else 0 end'),
    'starts_with',            vector ('starts with'              , vector ('varchar', 'address')                                   , 1, 'case when (^{value}^ between ^{pattern}^ and (^{pattern}^ || ''\\377\\377\\377\\377'')) then 1 else 0 end'),
    'not_starts_with',        vector ('not starts with'          , vector ('varchar', 'address')                                   , 1, 'case when (not (^{value}^ between ^{pattern}^ and (^{pattern}^ || ''\\377\\377\\377\\377''))) then 1 else 0 end'),
    'ends_with',              vector ('ends with'                , vector ('varchar', 'address')                                   , 1, 'case (sign (length (^{value}^) - length (^{pattern}^))) when -1 then 0 else equ (subseq (^{value}^, length (^{value}^) - length (^{pattern}^)), ^{pattern}^) end'),
    'not_ends_with',          vector ('not ends with'            , vector ('varchar', 'address')                                   , 1, 'case (sign (length (^{value}^) - length (^{pattern}^))) when -1 then 1 else neq (subseq (^{value}^, length (^{value}^) - length (^{pattern}^)), ^{pattern}^) end'),
    'is_null',                vector ('is null'                  , vector ('address')                                              , 0, 'case when (DB.DBA.is_empty_or_null (^{value}^)) then 1 else 0 end'),
    'is_not_null',            vector ('is not null'              , vector ('address')                                              , 0, 'case when (not DB.DBA.is_empty_or_null (^{value}^)) then 1 else 0 end'),
    'contains_text',          vector ('contains text'            , vector ('text'), 1, null)
  );
}
;

-----------------------------------------------------------------------------
--
create procedure OMAIL.WA.dc_actionMetas (inout anArray any)
{
  anArray := vector (
    'move',     vector (1, 'Move To',                    'select', 'folder'),
    'copy',     vector (1, 'Copy To',                    'select', 'folder'),
    'delete',   vector (1, 'Delete',                     null               ),
    'forward',  vector (1, 'Forward To',                 'input',  'varchar'),
    'tag',      vector (1, 'Tags (comma separated)',     'input',  'varchar'),
    'mark',     vector (1, 'Mark as Read',               null),
    'priority', vector (1, 'Set Priority To',            'select', 'priority')
  );
}
;

-----------------------------------------------------------------------------
create procedure OMAIL.WA.dc_xml (
  in tag varchar)
{
  return sprintf ('<?xml version="1.0" encoding="UTF-8"?><%s />', tag);
}
;

-----------------------------------------------------------------------------
--
create procedure OMAIL.WA.dc_xml_doc (
  in search varchar,
  in tag varchar)
{
  declare exit handler for SQLSTATE '*'
  {
    return xtree_doc (OMAIL.WA.dc_xml (tag));
  };
  return xtree_doc (search);
}
;

-----------------------------------------------------------------------------
--
create procedure OMAIL.WA.dc_set_criteria (
  inout search varchar,
  in id varchar,
  in fField any,
  in fCriteria any,
  in fValue any)
{
  declare S varchar;

  S := '';
  if (not isnull (fField))
    S := sprintf ('%s field="%V"', S, fField);
  if (not isnull (fCriteria))
    S := sprintf ('%s criteria="%V"', S, fCriteria);
  return OMAIL.WA.dc_set (search, 'criteria', id, sprintf('<entry ID="%s" %s>%V</entry>', id, S, coalesce (fValue, '')));
}
;

-----------------------------------------------------------------------------
--
create procedure OMAIL.WA.dc_set_action (
  inout search varchar,
  in id varchar,
  in fAction any,
  in fValue any)
{
  declare S varchar;

  S := '';
  if (not isnull (fAction))
    S := sprintf ('%s action="%V"', S, fAction);
  return OMAIL.WA.dc_set (search, 'actions', id, sprintf('<entry ID="%s" %s>%V</entry>', id, S, coalesce (fValue, '')));
}
;

-----------------------------------------------------------------------------
--
create procedure OMAIL.WA.dc_set (
  inout search varchar,
  in tag varchar,
  in id varchar,
  in anEntry varchar)
{
  declare aXml, aEntity any;

  aXml := OMAIL.WA.dc_xml_doc (search, tag);
  aEntity := xpath_eval (sprintf('/%s/entry[@ID = "%s"]', tag, id), aXml);
  if (not isnull(aEntity))
    aXml := XMLUpdate(aXml, sprintf('/%s/entry[@ID = "%s"]', tag, id), null);

  aEntity := xpath_eval (sprintf('/%s', tag), aXml);
  XMLAppendChildren (aEntity, xtree_doc (anEntry));
  search := OMAIL.WA.dc_restore_ns (OMAIL.WA.xml2string (aXml));
  return search;
}
;

-----------------------------------------------------------------------------
--
create procedure OMAIL.WA.dc_restore_ns(inout pXml varchar)
{
  pXml := replace (pXml, 'n0:', 'vmd:');
  pXml := replace (pXml, 'xmlns:n0', 'xmlns:vmd');
  return pXml;
};

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.folder_list (
  in _domain_id integer,
  in _user_id integer,
  in _folder_id integer := null,
  in _folder_type varchar := null)
{
  declare retValue any;

  if (isnull (_folder_id))
  {
    -- list
  retValue := vector ();
    for (select FOLDER_ID, NAME, SMART_FLAG from OMAIL.WA.FOLDERS where DOMAIN_ID = _domain_id and USER_ID = _user_id and PARENT_ID = 0 order by SEQ_NO, NAME) do
    {
      if (isnull (_folder_type) or (SMART_FLAG = _folder_type))
  {
    retValue := vector_concat (retValue, vector (FOLDER_ID, NAME));
    OMAIL.WA.folder_list_tmp (retValue, _domain_id, _user_id, FOLDER_ID, NAME);
  }
  }
  }
  else if (_folder_id = -1)
  {
    -- new
    retValue := '<object id="0" systemFlag="N" smartFlag="N">';
    retValue := retValue || '<name></name>';
    retValue := retValue || '</object>';

  }
  else if (_folder_id = -2)
  {
    -- new
    retValue := '<object id="0" systemFlag="N" smartFlag="S">';
    retValue := retValue || '<name></name>';
    retValue := retValue || '<parent_id>115</parent_id>';
    retValue := retValue || '<query></query>';
    retValue := retValue || '</object>';

  } else {
    -- edit
    retValue := '';
    for (select * from OMAIL.WA.FOLDERS where DOMAIN_ID = _domain_id and USER_ID = _user_id and FOLDER_ID = _folder_id) do
    {
      retValue := retValue || sprintf ('<object id="%d" systemFlag="%s" smartFlag="%s">', FOLDER_ID, SYSTEM_FLAG, SMART_FLAG);
      retValue := retValue || sprintf ('<name>%V</name>', NAME);
      retValue := retValue || sprintf ('<parent_id>%d</parent_id>', PARENT_ID);
      if (SMART_FLAG = 'S')
      {
        declare params any;

        params   := deserialize (DATA);
        retValue := retValue || '<query>';
        if (not isnull (params))
        {
          retValue := retValue || sprintf ('<q_from><![CDATA[%s]]></q_from>', get_keyword ('q_from', params,''));
          retValue := retValue || sprintf ('<q_to><![CDATA[%s]]></q_to>', get_keyword ('q_to', params, ''));
          retValue := retValue || sprintf ('<q_subject><![CDATA[%s]]></q_subject>', get_keyword ('q_subject', params, ''));
          retValue := retValue || sprintf ('<q_body><![CDATA[%s]]></q_body>', get_keyword ('q_body', params, ''));
          retValue := retValue || sprintf ('<q_tags><![CDATA[%s]]></q_tags>', get_keyword ('q_tags', params, ''));
          retValue := retValue || sprintf ('<q_fid>%s</q_fid>', get_keyword ('q_fid', params,''));
          retValue := retValue || sprintf ('<q_attach>%s</q_attach>', get_keyword ('q_attach', params,''));
          retValue := retValue || sprintf ('<q_read>%s</q_read>', get_keyword ('q_read', params,''));
          retValue := retValue || sprintf ('<q_after>%s</q_after>', get_keyword ('q_after', params, ''));
          retValue := retValue || sprintf ('<q_before>%s</q_before>', get_keyword ('q_before', params, ''));
        }
        retValue := retValue || '</query>';
      }
      retValue := retValue || '</object>';
    }
  }
  return retValue;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.folder_list_tmp (
  inout retValue any,
  in _domain_id integer,
  in _user_id integer,
  in _parent_id integer,
  in _parent_path varchar)
{
  for (select FOLDER_ID, NAME from OMAIL.WA.FOLDERS where DOMAIN_ID = _domain_id and USER_ID = _user_id and PARENT_ID = _parent_id) do
  {
    retValue := vector_concat (retValue, vector (FOLDER_ID, _parent_path || '/' || NAME));
    OMAIL.WA.folder_list_tmp (retValue, _domain_id, _user_id, FOLDER_ID, _parent_path || '/' || NAME);
  }
}
;

-----------------------------------------------------------------------------------------
--
create procedure OMAIL.WA.tmp_update ()
{
  if (registry_get ('omail_version_upgrade') = '0')
    return;
  registry_set ('omail_version_upgrade', '1');
  for (select WAI_ID, WAM_USER
         from DB.DBA.WA_MEMBER join DB.DBA.WA_INSTANCE on WAI_NAME = WAM_INST
        where WAI_TYPE_NAME = 'oMail' and WAM_MEMBER_TYPE = 1) do
  {
    OMAIL.WA.omail_init_user_data (1, WAM_USER);
  }
}
;
OMAIL.WA.tmp_update ()
;

-----------------------------------------------------------------------------------------
--
-- Certificates
--
-----------------------------------------------------------------------------------------
create procedure OMAIL.WA.certificateExist (
  in user_id integer,
  in certificate varchar)
{
  if (exists (select 1
                from DB.DBA.ods_user_keys (username) (xenc_key varchar) x
               where username = OMAIL.WA.account_name (user_id)
                 and x.xenc_key = certificate))
    return 1;

  return 0;
}
;

-----------------------------------------------------------------------------------------
--
create procedure OMAIL.WA.certificateList (
  in user_id integer,
  in certificate varchar)
{
  declare S varchar;
  declare stream any;

  stream := string_output ();
  http ('<certificates>', stream);

  if ((certificate <> '') and not OMAIL.WA.certificateExist (user_id, certificate))
    certificate := (select WAUI_SALMON_KEY from WA_USER_INFO where WAUI_U_ID = user_id);

  for (select x.xenc_key, x.xenc_type
         from DB.DBA.ods_user_keys (username) (xenc_key varchar, xenc_type varchar) x
        where username = OMAIL.WA.account_name (user_id)) do
  {
    S := case when (xenc_key = certificate) then ' selected="selected"' else '' end;
    http (sprintf ('<certificate%s>%V</certificate>', S, xenc_key), stream);
  }
  http ('</certificates>', stream);

  return string_output_string (stream);
}
;

-----------------------------------------------------------------------------------------
--
create procedure OMAIL.WA.certificate (
  in _domain_id integer,
  in _user_id integer)
{
  declare _settings, _name, _certificate, _pem, _key varchar;

  _settings := OMAIL.WA.omail_get_settings (_domain_id, _user_id, 'base_settings');
  _name := OMAIL.WA.omail_getp ('security_encrypt', _settings);
  set_user_id (OMAIL.WA.account_name (_user_id));
  _pem := xenc_pem_export(_name);
  _key := xenc_pem_export(_name, 1);
  set_user_id ('dba');

  return vector (_pem, _key);
}
;
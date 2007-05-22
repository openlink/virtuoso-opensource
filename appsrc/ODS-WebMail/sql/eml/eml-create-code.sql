--
--  $Id$
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

-------------------------------------------------------------------------------
--
-- Freeze Functions
--
-------------------------------------------------------------------------------
create procedure OMAIL.WA.frozen_check(in domain_id integer, in sid varchar)
{
  declare user_id integer;
  declare vsState integer;

  declare exit handler for not found { return 1; };

  if (is_empty_or_null((select WAI_IS_FROZEN from DB.DBA.WA_INSTANCE where WAI_ID = domain_id)))
    return 0;

  vsState := (select deserialize(VS_STATE) from DB.DBA.VSPX_SESSION where VS_SID = sid);

  user_id := (select U_ID from SYS_USERS where U_NAME = get_keyword('vspx_user', vsState, ''));
  if (OMAIL.WA.check_admin(user_id))
    return 0;

  user_id := (select U_ID from SYS_USERS where U_NAME = get_keyword('owner_user', vsState, ''));
  if (OMAIL.WA.check_admin(user_id))
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
  group_id := (select U_GROUP from SYS_USERS where U_ID = user_id);

  if (user_id = 0)
    return 1;
  if (user_id = http_dav_uid ())
    return 1;
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

  SELECT COUNT(*), SUM(either(MSTATUS,0,1))
    INTO _all_cnt,_new_cnt
    FROM OMAIL.WA.MESSAGES
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
  _del := '';
  _arr := (xpath_eval(concat('//', _node), xml_tree_doc(xml_tree( _values)),0));
  for (N := 0; N < length(_arr); N := N + 1) {
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
  for (N := 0; N < length(_arr_1); N := N + 1) {
    _name  := '';
    _addr  := '';
    _loc   := _arr_1[N];
    _loc   := replace(_loc,'<','');
    _loc   := replace(_loc,'>','');
    _loc   := replace(_loc,'\t',' ');
    _arr_2 := split_and_decode(ltrim(_loc),0,'\0\0 ');
    for (_x := 0; _x < length(_arr_2); _x := _x + 1) {
      if (isnull(strchr(_arr_2[_x], '@')) = 0) {
        _addr  := _arr_2[_x];
      } else {
        _name  := _name || ' ' || _arr_2[_x];
      }
    }
    if (_count = 1)
      return either(length(_name),trim(_name),trim(_addr));
    if (_count = 2)
      return trim (_addr);
    if (length(_name) > 0)
      _name  := sprintf('<name><![CDATA[%s]]></name>',trim(_name),_x);
    if (length(_addr) > 0)
      _addr  := sprintf('<email><![CDATA[%s]]></email>',_addr);

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
  for (N := 0; N < length(_array); N := N + 1) {
    _s := '';
    _n := cast(xpath_eval('name()', _array[N]) as varchar);
    _m := cast(xpath_eval('./email', _array[N]) as varchar);
    if (not _found) {
      for (select WAI_NAME from DB.DBA.WA_MEMBER, DB.DBA.WA_INSTANCE where WAM_INST = WAI_NAME and WAM_USER = _user_id and WAI_TYPE_NAME = 'oMail' order by WAI_ID) do {
        if (WAI_NAME = _m)
          _found := 1;
      }
      _s := OMAIL.WA.xml2string(_array[N]);
      if (_found) {
        _s := replace(_s, '<' || _n || '>', '<from>');
        _s := replace(_s, '</' || _n || '>', '</from>');
      }
    } else {
      _s := OMAIL.WA.xml2string(_array[N]);
      if (_n = 'from') {
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
  for (N := 0; N < length(_array); N := N + 1) {
    _rs  := sprintf('%s%s%s', _rs, _del, cast(aref(_array, N) as varchar));
    _del := _delimiter;
  }
  return _rs;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.array2xml(
  in V any)
{
  declare N integer;
  declare S, node, value varchar;

  S  := '';
  for (N := 0; N < length(V); N := N + 2) {
  	if (isstring(V[N])) {
  	  node := lower(cast(V[N] as varchar));
  	  if (isarray(V[N+1]) and not isstring(V[N+1])) {
  	    value := OMAIL.WA.array2xml(V[N+1]) ;

  	  } else if (isnull(V[N+1])) {
  	    value := '';

  	  } else {
  	    value := cast(V[N+1] as varchar);
  	  }
  	  S := sprintf('%s<%s>%s</%s>\n', S, node, value, node);
    }
  }
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

  SELECT TYPE_ID, TDATA, BDATA, APARAMS
    INTO _type_id,_tdata,_bdata,_aparams
    FROM OMAIL.WA.MSG_PARTS
   where DOMAIN_ID = _domain_id
     and USER_ID   = _user_id
     and MSG_ID    = _msg_id
     and PART_ID   = _part_id;

  _tdata := concat(_bdata,_tdata);
  _encoding := OMAIL.WA.omail_get_encoding(_aparams);

  if ((_encoding = 'quoted-printable') or strstr(_tdata,'=3D')) {
    _tdata := replace(_tdata,'\r\n','\n');
    _tdata := replace(_tdata,'=\n','');
    _tdata := split_and_decode(_tdata,0,'=');
  } else if ((_encoding = 'base64')) {
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
  declare _freetext_id,_part_id,_cnt integer;

  _part_id := coalesce((SELECT MAX(PART_ID) FROM OMAIL.WA.MSG_PARTS  where   DOMAIN_ID = _domain_id and USER_ID = _user_id and MSG_ID = _msg_id), 0);
  _cnt := 0;

  for (SELECT DOMAIN_ID V_DOMAIN_ID,USER_ID V_USER_ID,TYPE_ID V_TYPE_ID,CONTENT_ID V_CONTENT_ID,BDATA V_BDATA,DSIZE V_DSIZE,APARAMS V_APARAMS,PDEFAULT V_PDEFAULT,FNAME V_FNAME
         FROM OMAIL.WA.MSG_PARTS
        where DOMAIN_ID = _domain_id
          and USER_ID   = _user_id
          and MSG_ID    = _re_msg_id
          and PDEFAULT <> 1)
  do {
    _freetext_id := sequence_next ('OMAIL.WA.omail_seq_eml_freetext_id');
    _part_id := _part_id + 1;
    insert into OMAIL.WA.MSG_PARTS (DOMAIN_ID,USER_ID,MSG_ID,PART_ID,TYPE_ID,CONTENT_ID,BDATA,DSIZE,APARAMS,PDEFAULT,FNAME,FREETEXT_ID)
      values (V_DOMAIN_ID,V_USER_ID,_msg_id,_part_id,V_TYPE_ID,V_CONTENT_ID,V_BDATA,V_DSIZE,V_APARAMS,V_PDEFAULT,V_FNAME,_freetext_id);
    _cnt := _cnt + 1;
  }

  UPDATE OMAIL.WA.MESSAGES
     SET ATTACHED = ATTACHED + _cnt
   where DOMAIN_ID = _domain_id
     and USER_ID   = _user_id
     and MSG_ID    = _msg_id;
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

  declare _rs,_sid,_realm,_bp,_sql_result1,_sql_result2,_faction,_pnames,_ip varchar;
  declare _order,_direction,_params,_page_params any;
  declare _user_info, _settings any;
  declare _pageSize,_user_id,_folder_id,_domain_id integer;

  -- SECURITY CHECK ------------------------------------------------------------------
  _sid       := get_keyword('sid',params,'');
  _realm     := get_keyword('realm',params,'');
  _user_info := get_keyword('user_info',params);

  -- TEMP constants -------------------------------------------------------------------
  _user_id   := get_keyword('user_id',_user_info);
  _domain_id := 1;
  _pageSize  := 10;

  -- GET SETTINGS ------------------------------
  _settings := OMAIL.WA.omail_get_settings(_domain_id, _user_id, 'base_settings');

  -- Set constants  -------------------------------------------------------------------
  _page_params := vector(0,0,0,0,0,0,0,0,0,0,0,0);

  -- Set Variable--------------------------------------------------------------------
  if (get_keyword('fa_move.x',params,'') <> '') {
    _faction := 'move';

  } else if (get_keyword('fa_delete.x',params,'') <> '') {
    _faction := 'delete';

  } else if (get_keyword('fa_erase.x',params,'') <> '') {
    _faction := 'erase';
  }

  _folder_id  := get_keyword('fid',params,'');

  -- Set Arrays----------------------------------------------------------------------
  _pnames := 'folder_id,skiped,order,direction,folder_view';
  _params := OMAIL.WA.omail_str2params(_pnames,get_keyword('bp',params, '100,0,0,0,0'),',');

  _order     := vector('','MSTATUS','PRIORITY','ADDRES_INFO','SUBJECT','RCV_DATE','DSIZE','ATTACHED');
  _direction := vector('',' ','desc');

  -- Check Params for ilegal values---------------------------------------------------
  if (OMAIL.WA.omail_check_folder_id(_domain_id,_user_id, get_keyword('folder_id',_params)) = 0) {
    -- check FOLDER_ID
    OMAIL.WA.utl_redirect(sprintf('err.vsp?sid=%s&realm=%s&err=%d',_sid,_realm,1100));
    return;
  }

  if (not OMAIL.WA.omail_check_interval(get_keyword('skiped',_params),0,100000)) {
    -- check SKIPED
    OMAIL.WA.utl_redirect(sprintf('err.vsp?sid=%s&realm=%s&err=%d',_sid,_realm,1101));
    return;
  }

  if (not OMAIL.WA.omail_check_interval(get_keyword('order',_params),1,(length(_order)-1))) { -- check ORDER BY
    OMAIL.WA.omail_setparam('order',_params,get_keyword('msg_order',_settings)); -- get from settings
  } else if (get_keyword('order',_params) <> get_keyword('msg_order',_settings)) {
    OMAIL.WA.omail_setparam('msg_order',_settings,get_keyword('order',_params)); -- update new value in settings
    OMAIL.WA.omail_setparam('update_flag',_settings,1);
  }

  if (not OMAIL.WA.omail_check_interval(get_keyword('direction',_params),1,(length(_direction)-1))) {
    -- check ORDER WAY
    OMAIL.WA.omail_setparam('direction',_params,get_keyword('msg_direction',_settings));
  } else if (get_keyword('direction',_params) <> get_keyword('msg_direction',_settings)) {
    OMAIL.WA.omail_setparam('msg_direction',_settings,get_keyword('direction',_params));
    OMAIL.WA.omail_setparam('update_flag',_settings,1);
  }

  if (not OMAIL.WA.omail_check_interval(get_keyword('folder_view',_params),1,2)) { -- check Folder View
    OMAIL.WA.omail_setparam('folder_view',_params,get_keyword('folder_view',_settings));
  } else if (get_keyword('folder_view',_params) <> get_keyword('folder_view',_settings)){
    OMAIL.WA.omail_setparam('folder_view',_settings,get_keyword('folder_view',_params));
    OMAIL.WA.omail_setparam('update_flag',_settings,1);
  }

  -- Form Action---------------------------------------------------------------------
  if (_faction = 'move') { -- > 'move msg to folder'
    _rs := OMAIL.WA.omail_move_msg(_domain_id,_user_id,params);
    if (_rs = '1') {
      _bp := OMAIL.WA.omail_params2str(_pnames,_params,',');
      OMAIL.WA.utl_redirect_adv(sprintf('box.vsp?sid=%s&realm=%s&bp=%s',_sid,_realm,_bp),params);
      return;
    }
    _bp := OMAIL.WA.omail_params2str(_pnames,_params,',');
    OMAIL.WA.utl_redirect_adv(sprintf('box.vsp?sid=%s&realm=%s&bp=%s',_sid,_realm,_bp),params);
    return;
  }
  if (_faction = 'delete') { -- > 'move msg to trash or delete if it's in trash'
    OMAIL.WA.omail_delete_message(_domain_id,_user_id,params,_params);
    _bp := OMAIL.WA.omail_params2str(_pnames,_params,',');

    OMAIL.WA.utl_redirect_adv(sprintf('box.vsp?sid=%s&realm=%s&bp=%s',_sid,_realm,_bp),params);
    return;
  }
  if (_faction = 'erase') { -- > 'unconditional delete'
    OMAIL.WA.omail_del_message(_domain_id,_user_id,cast(get_keyword('ch_msg',params) as integer));
    _bp := OMAIL.WA.omail_params2str(_pnames,_params,',');
    OMAIL.WA.utl_redirect_adv(sprintf('box.vsp?sid=%s&realm=%s&bp=%s',_sid,_realm,_bp),params);
    return;
  }

  -- Page Params---------------------------------------------------------------------
  aset(_page_params,0,vector('sid',_sid));
  aset(_page_params,1,vector('realm',_realm));
  aset(_page_params,2,vector('folder_id',get_keyword('folder_id',_params)));
  aset(_page_params,3,vector('bp',OMAIL.WA.omail_params2str(_pnames,_params,',')));
  aset(_page_params,4,vector('user_info', OMAIL.WA.array2xml(_user_info)));

  if (get_keyword('msg_result',_settings) <> '') {
    OMAIL.WA.omail_setparam('aresults',_params,get_keyword('msg_result',_settings));
  } else {
    OMAIL.WA.omail_setparam('aresults',_params,_pageSize);
  }

  OMAIL.WA.omail_set_settings(_domain_id, _user_id, 'base_settings', _settings);

  -- SQL Statement-------------------------------------------------------------------
  _sql_result1 := OMAIL.WA.omail_msg_list(_domain_id,_user_id,_params);
  _sql_result2 := sprintf('<folders>%s</folders>',OMAIL.WA.omail_folders_list(_domain_id,_user_id,vector()));

  -- XML structure-------------------------------------------------------------------
  _rs := '';
  _rs := sprintf('%s%s' ,_rs, OMAIL.WA.omail_page_params(_page_params));
  _rs := sprintf('%s<messages>%s</messages>' ,_rs,_sql_result1);
  _rs := sprintf('%s<folder_view>%d</folder_view>',_rs,get_keyword('folder_view',_params));
  _rs := sprintf('%s%s' ,_rs,_sql_result2);
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

  declare _rs,_sid,_realm,_bp,_sql_result1,_sql_result2,_faction,_pnames,_ip,_node varchar;
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

  -- Set Variable--------------------------------------------------------------------
  if (get_keyword('fa_save.x',params,'') <> '') {
    _faction := 'save';
  } else  if (OMAIL.WA.omail_getp('action',_params) = 1) {
    _faction := 'check';
  } else if (OMAIL.WA.omail_getp('action',_params) = 2) {
    _faction := 'check_all';
  }

  -- Form Action---------------------------------------------------------------------
  if (_faction = 'check') {
    -- > check now account
    _error := OMAIL.WA.omail_ch_pop3_acc_now(_domain_id,_user_id,OMAIL.WA.omail_getp('acc_id',_params), _new_msg);
    if (_error = 0) {
      OMAIL.WA.utl_redirect(sprintf('ch_pop3.vsp?sid=%s&realm=%s&cp=0,0,%d,%d',_sid,_realm,_new_msg,OMAIL.WA.omail_getp('acc_id',_params)));
    } else {
      OMAIL.WA.utl_redirect(sprintf('ch_pop3.vsp?sid=%s&realm=%s',_sid,_realm));
    }
    return;

  } else if (_faction = 'save') {
    -- > save or edit account
    _error := OMAIL.WA.omail_save_pop3_acc(_domain_id, _user_id, params);
    if (_error = 0) {
      OMAIL.WA.utl_redirect(sprintf('ch_pop3.vsp?sid=%s&realm=%s',_sid,_realm));
    } else {
      OMAIL.WA.utl_redirect(sprintf('err.vsp?sid=%s&realm=%s&err=%d',_sid,_realm,_error));
    }
    return;

  } else if (_faction = 'check_all') {
    -- > check all acc
    _error := OMAIL.WA.omail_ch_pop3_acc_all(_domain_id,_user_id, 0);
    if (_error = 0) {
      OMAIL.WA.utl_redirect(sprintf('box.vsp?sid=%s&realm=%s',_sid,_realm));
    } else {
      OMAIL.WA.utl_redirect(sprintf('err.vsp?sid=%s&realm=%s&err=%d',_sid,_realm,_error));
    }
    return;

  } else if (get_keyword('del_acc_id',params,0) <> 0) {
    -- > delete account
    _error := OMAIL.WA.omail_del_pop3_acc(_domain_id,_user_id,cast(get_keyword('del_acc_id',params,0) as integer));
    if (_error = 0) {
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
  _sql_result1 := sprintf(' %s',OMAIL.WA.omail_get_pop3_acc(_domain_id,_user_id,OMAIL.WA.omail_getp('acc_id',_params)));

  if (OMAIL.WA.omail_getp('acc_id',_params) = 0){
    _node := 'accounts';
  } else {
    _node := 'account';
  }

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
create procedure OMAIL.WA.omail_ch_pop3_acc(
  in _domain_id integer,
  in _user_id   integer,
  in _acc_id    integer,
  out _new_msg  integer)
{
  declare _messages any;
  declare N integer;

  declare exit handler for SQLSTATE '2E000' {
    -- err_bad_server:
    OMAIL.WA.omail_ch_pop3_acc_update(_domain_id, _user_id, _acc_id, 1);
    return 1811;
  };
  declare exit handler for SQLSTATE '08006'{
    --err_bad_user:
    OMAIL.WA.omail_ch_pop3_acc_update(_domain_id, _user_id, _acc_id, 2);
    return 1812;
  };

  commit work;

  _new_msg := 0;
  for (SELECT USER_NAME, USER_PASS, POP_SERVER, POP_PORT, MCOPY, FOLDER_ID
         FROM OMAIL.WA.EXTERNAL_POP_ACC
        where DOMAIN_ID = _domain_id
          and USER_ID = _user_id
          and ACC_ID = _acc_id) do
  {
    _messages := pop3_get (concat(POP_SERVER, ':', cast(POP_PORT as varchar)), USER_NAME, USER_PASS, 10000000, either(equ(MCOPY,0),'DELETE',''));
    N := 0;
    while(N < length(_messages)) {
      if (not exists(SELECT MSG_ID FROM OMAIL.WA.MESSAGES  where   DOMAIN_ID = _domain_id and USER_ID = _user_id and SRV_MSG_ID = aref(aref(_messages,N),0))) {
        OMAIL.WA.omail_receive_message(_domain_id,_user_id,aref(aref(_messages,N),1),FOLDER_ID);
        _new_msg := _new_msg + 1;
      };
      N := N + 1;
    }
    OMAIL.WA.omail_ch_pop3_acc_update(_domain_id, _user_id, _acc_id, 0);
  }
  return 0;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_ch_pop3_acc_all(
  in _domain_id integer,
  in _user_id   integer,
  in _period    integer) -- 1-daily; 2-per hour
{
  declare _new_msg,_limit integer;
  _limit := -1; -- min period between two check (in minutes)

  if (_period = 0) {
    -- check all accounts
    for (SELECT ACC_ID
           FROM OMAIL.WA.EXTERNAL_POP_ACC
          where DOMAIN_ID = _domain_id
            and USER_ID = _user_id
            and LAST_CHECK < dateadd('minute',_limit, now())) do
      OMAIL.WA.omail_ch_pop3_acc_now(_domain_id,_user_id,ACC_ID,_new_msg);
  } else {
    -- check only account, includes in this period (1-daily; 2-per hour;)
    for (SELECT ACC_ID
           FROM OMAIL.WA.EXTERNAL_POP_ACC
          where DOMAIN_ID = _domain_id
            and USER_ID = _user_id
            and LAST_CHECK < dateadd('minute',_limit, now())
            and CH_INTERVAL = _period
          ORDER BY LAST_CHECK) do
      OMAIL.WA.omail_ch_pop3_acc_now(_domain_id,_user_id,ACC_ID,_new_msg);
  };
  return 0;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_ch_pop3_acc_now(
  in _domain_id integer,
  in _user_id   integer,
  in _acc_id    integer,
  out _new_msg  integer)
{
  declare _messages,_mlist any;
  declare N,_check,_buffer integer;

  DECLARE EXIT HANDLER FOR SQLSTATE '2E000' {
    -- bad_server:
    OMAIL.WA.omail_ch_pop3_acc_update(_domain_id, _user_id, _acc_id, 1);
    return 1811;
  };
  DECLARE EXIT HANDLER FOR SQLSTATE '08006' {
    -- bad_user:
    OMAIL.WA.omail_ch_pop3_acc_update(_domain_id, _user_id, _acc_id, 2);
    return 1812;
  };

  DECLARE EXIT HANDLER FOR SQLSTATE '08001' {
    -- Cannot connect in pop3_get
    OMAIL.WA.omail_ch_pop3_acc_update(_domain_id, _user_id, _acc_id, 3);
    return 1813;
  };

  commit work;

  for (SELECT *
         FROM OMAIL.WA.EXTERNAL_POP_ACC
        where DOMAIN_ID = _domain_id
          and USER_ID = _user_id
          and ACC_ID = _acc_id) do
  {
    -- POP3 parameters ---------------------------------------------------------
    POP_SERVER := concat(POP_SERVER,':', cast(POP_PORT as varchar));
    USER_PASS  := pwd_magic_calc ('pop3',USER_PASS);
    _buffer    := 10000000;
    _mlist     := vector();

    -- get list with unique msg ids from server --------------------------------
    _messages := pop3_get (POP_SERVER, USER_NAME, USER_PASS, 10000000, 'UIDL');

    -- check for duplicate messages --------------------------------------------
    while(N < length(_messages)){
      if (exists(SELECT 1 FROM OMAIL.WA.MESSAGES where DOMAIN_ID = _domain_id and USER_ID = _user_id and MSG_SOURCE = ACC_ID and UNIQ_MSG_ID = aref(_messages,N)))
        _mlist := vector_concat(_mlist,vector(aref(_messages,N)));
      N := N + 1;
    };

    _messages := pop3_get (POP_SERVER, USER_NAME, USER_PASS, _buffer, either(equ(MCOPY,0),'DELETE',''), _mlist);

    -- insert message into DB --------------------------------------------------
    N := 0;
    while(N < length(_messages)){
      OMAIL.WA.omail_receive_message(_domain_id,_user_id,null,aref(aref(_messages,N),1),subseq(aref(aref(_messages,N),0),0,100),ACC_ID,FOLDER_ID);
      N := N + 1;
    };
    -- count new messages ------------------------------------------------------
    _new_msg := length(_messages);

    -- set flag for successful download ----------------------------------------
    OMAIL.WA.omail_ch_pop3_acc_update(_domain_id, _user_id, _acc_id, 0);
  };
  return 0;
}
;

create procedure OMAIL.WA.omail_ch_pop3_acc_update(
  in _domain_id  integer,
  in _user_id    integer,
  in _acc_id     integer,
  in _error      integer)
{
  UPDATE OMAIL.WA.EXTERNAL_POP_ACC
     SET LAST_CHECK = now(),
         CH_ERROR   = _error
   where DOMAIN_ID  = _domain_id
     and USER_ID    = _user_id
     and ACC_ID     = _acc_id;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_check_folder_id(
  in _domain_id  integer,
  in _user_id    integer,
  in _folder_id  integer)
{
  return coalesce((SELECT 1 FROM OMAIL.WA.FOLDERS where DOMAIN_ID = _domain_id and USER_ID = _user_id and FOLDER_ID = _folder_id), 0);
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_check_folder_name(
  in _domain_id   integer,
  in _user_id     integer,
  in _parent_id   integer,
  in _folder_name varchar,
  in _folder_id   integer := 0)
{
  declare retValue integer;

  retValue := coalesce((SELECT FOLDER_ID FROM OMAIL.WA.FOLDERS where DOMAIN_ID = _domain_id and USER_ID = _user_id and PARENT_ID = _parent_id and NAME = _folder_name), 0);
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
create procedure OMAIL.WA.omail_check_istrash(
  in  _domain_id integer,
  in  _user_id   integer,
  in  _folder_id integer,
  out _error     integer)
{
  declare _parent_loc integer;
  _error := 0;
  whenever not found goto err_exit;
  if (_folder_id = 110)
    return -1;

  SELECT PARENT_ID into _parent_loc FROM OMAIL.WA.FOLDERS where DOMAIN_ID = _domain_id and USER_ID = _user_id and FOLDER_ID = _folder_id;

  if (_parent_loc = 110)
    return -1;
  if (_parent_loc is null)
    return 0;
  return OMAIL.WA.omail_check_istrash(_domain_id,_user_id,_parent_loc,_error);

err_exit:
  _error := 1602;
  return;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_check_parent(
  in _domain_id integer,
  in _user_id   integer,
  in _folder_id  integer,
  in _parent_id integer)
{
  declare _parent_loc integer;
  WHENEVER NOT FOUND GOTO ERR_EXIT;

  SELECT PARENT_ID
    INTO _parent_loc
    FROM OMAIL.WA.FOLDERS
   where DOMAIN_ID = _domain_id
     and USER_ID = _user_id
     and FOLDER_ID = _parent_id;

  if ((_parent_loc = _folder_id) or (_parent_id = _folder_id))
    return 1401;
  if (_parent_loc is null)
    return 0;
  return OMAIL.WA.omail_check_parent(_domain_id,_user_id,_folder_id,_parent_loc);

ERR_EXIT:
  return 1402;
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

  _value := cast(_value as integer);
  if ((_value >= _lt) and (_value <= _gt))
    return 1;
  return 0;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_cnt_message(
  in  _domain_id integer,
  in  _user_id   integer,
  in  _folder_id integer,
  out _all_cnt  integer,
  out _new_cnt  integer,
  out _all_size integer )
{
  SELECT COUNT(*),
         SUM(either(MSTATUS,0,1)),
         SUM(DSIZE)
    INTO _all_cnt,_new_cnt,_all_size
    FROM OMAIL.WA.MESSAGES
   where PARENT_ID IS NULL
     and DOMAIN_ID = _domain_id
     and USER_ID   = _user_id
     and FOLDER_ID = _folder_id;

  _new_cnt  := either(isnull(_new_cnt),0,_new_cnt);
  _all_size := either(isnull(_all_size),0,_all_size);
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_cnt_msg(
  in _mstatus varchar,
  in _status varchar,
  in _value integer)
  returns integer
{
  if (_mstatus = _status)
    return _value;
  return 0;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_conctruct_address(
  in _address varchar,
  in _mode    integer)
{
  return '';
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_construct_mail(
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

  _sql_result1 := sprintf('%s',OMAIL.WA.omail_open_message(_user_id,vector('msg_id',_msg_id),1,1));
  _sql_result2 := sprintf('%s',OMAIL.WA.omail_select_attachment(_user_id,_msg_id,1));
  _boundary := sprintf('------_NextPart_%s',md5(cast(now() as varchar)));

  -- XML structure-------------------------------------------------------------------
  _rs := sprintf('%s<message>', _rs);
  _rs := sprintf('%s<boundary>%s</boundary>', _rs,_boundary);
  _rs := sprintf('%s%s',_rs,_sql_result1);
  _rs := sprintf('%s%s',_rs,_sql_result2);
  _rs := sprintf('%s</message>', _rs);

  -- XSL Transformation--------------------------------------------------------------

  declare _view varchar;
  _view := get_keyword('vv',params,'h');
  OMAIL.WA.utl_myhttp (_view, _rs, _xslt_url, null, null, null);
  return;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_convert_date (IN atime  datetime ){

  declare result,d,e,h,m,y varchar;
  declare m_time datetime;

  m_time := atime;

  d := either(lt(cast(dayofmonth(m_time) as integer),10),sprintf('%d%d',0,dayofmonth(m_time)),cast(dayofmonth(m_time)as varchar));
  m := either(lt(cast(month(m_time)      as integer),10),sprintf('%d%d',0,month(m_time)) ,cast(month(m_time)as varchar));
  h := either(lt(cast(hour(m_time)       as integer),10),sprintf('%d%d',0,hour(m_time)) ,cast(hour(m_time)as varchar));
  e := either(lt(cast(minute(m_time)     as integer),10),sprintf('%d%d',0,minute(m_time)) ,cast(minute(m_time)as varchar));
  y := cast(year(m_time)as varchar);

  result := sprintf('%s:%s %s.%s.%s',h,e,m,d,y);

  RETURN result;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_convert_date_split (in atime  datetime ){
  declare _rs,d,e,h,m,y,s,w varchar;
  declare m_time datetime;

  m_time := atime;
  if (isnull(atime)) return '';

  h := either(lt(cast(hour(m_time) as integer),10),sprintf('%d%d',0,hour(m_time)),cast(hour(m_time)as varchar));
  e := either(lt(cast(minute(m_time) as integer),10),sprintf('%d%d',0,minute(m_time)),cast(minute(m_time)as varchar));
  s := either(lt(cast(second(m_time) as integer),10),sprintf('%d%d',0,second (m_time)),cast(second(m_time)as varchar));
  d := either(lt(cast(dayofmonth(m_time) as integer),10),sprintf('%d%d',0,dayofmonth(m_time)),cast(dayofmonth(m_time)as varchar));
  m := either(lt(cast(month(m_time) as integer),10),sprintf('%d%d',0,month(m_time)),cast(month(m_time)as varchar));
  w := cast(dayofweek(m_time) as varchar);
  y := cast(year(m_time)as varchar);

  _rs := '';
  --_rs := sprintf('<ddate>');
  _rs := sprintf('%s<hour>%s</hour>',_rs,h);
  _rs := sprintf('%s<minute>%s</minute>',_rs,e);
  _rs := sprintf('%s<second>%s</second>',_rs,s);
  _rs := sprintf('%s<day>%s</day>',_rs,d);
  _rs := sprintf('%s<wday>%s</wday>',_rs,w);
  _rs := sprintf('%s<month>%s</month>',_rs,m);
  _rs := sprintf('%s<year>%s</year>',_rs,y);
  --_rs := sprintf('%s</ddate>',_rs);

  RETURN _rs;
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

  vspx_uid := get_keyword('user_id', userInfo);
  vspx_user := coalesce((SELECT U_NAME FROM WS.WS.SYS_DAV_USER where U_ID = vspx_uid), '');
  vspx_pwd := coalesce((SELECT U_PWD FROM WS.WS.SYS_DAV_USER where U_ID = vspx_uid), '');
  if (vspx_pwd[0] = 0)
    vspx_pwd := pwd_magic_calc(vspx_user, vspx_pwd, 1);
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_date2xml (in atime  time ){
  declare _rs,d,e,h,m,y,s,w varchar;
  declare m_time TIME;

  m_time := atime;
  if (isnull(atime)) return '';

  h := either(lt(cast(hour(m_time) as integer),10),sprintf('%d%d',0,hour(m_time)),cast(hour(m_time)as varchar));
  e := either(lt(cast(minute(m_time) as integer),10),sprintf('%d%d',0,minute(m_time)),cast(minute(m_time)as varchar));
  s := either(lt(cast(second(m_time) as integer),10),sprintf('%d%d',0,second (m_time)),cast(second(m_time)as varchar));
  d := either(lt(cast(dayofmonth(m_time) as integer),10),sprintf('%d%d',0,dayofmonth(m_time)),cast(dayofmonth(m_time)as varchar));
  m := either(lt(cast(month(m_time) as integer),10),sprintf('%d%d',0,month(m_time)),cast(month(m_time)as varchar));
  w := cast(dayofweek(m_time) as varchar);
  y := cast(year(m_time)as varchar);

  _rs := '';
  --_rs := sprintf('<ddate>');
  _rs := sprintf('%s<hour>%s</hour>',_rs,h);
  _rs := sprintf('%s<minute>%s</minute>',_rs,e);
  _rs := sprintf('%s<second>%s</second>',_rs,s);
  _rs := sprintf('%s<day>%s</day>',_rs,d);
  _rs := sprintf('%s<wday>%s</wday>',_rs,w);
  _rs := sprintf('%s<month>%s</month>',_rs,m);
  _rs := sprintf('%s<year>%s</year>',_rs,y);
  --_rs := sprintf('%s</ddate>',_rs);

  return _rs;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_del_folder(
  in _domain_id integer,
  in _user_id   integer,
  in _folder_id integer,
  in _mode      integer)
{
  for (SELECT MSG_ID FROM OMAIL.WA.MESSAGES where DOMAIN_ID = _domain_id and USER_ID = _user_id and FOLDER_ID = _folder_id) do
    OMAIL.WA.omail_del_message(_domain_id,_user_id, MSG_ID);

  for (SELECT FOLDER_ID FROM OMAIL.WA.FOLDERS where DOMAIN_ID = _domain_id and USER_ID = _user_id and PARENT_ID = _folder_id) do
    OMAIL.WA.omail_del_folder(_domain_id,_user_id,FOLDER_ID, _mode);

  if (_mode = 1) {
    declare _parent_id integer;

    _parent_id := (select PARENT_ID FROM OMAIL.WA.FOLDERS where DOMAIN_ID = _domain_id and USER_ID = _user_id and FOLDER_ID = _folder_id);
    if (not isnull(_parent_id))
      update OMAIL.WA.EXTERNAL_POP_ACC
         set FOLDER_ID = _parent_id
       where DOMAIN_ID = _domain_id and USER_ID = _user_id and FOLDER_ID = _folder_id;

    delete from OMAIL.WA.FOLDERS where DOMAIN_ID = _domain_id and USER_ID = _user_id and FOLDER_ID = _folder_id;
  }
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_del_message(
  in _domain_id integer,
  in _user_id   integer,
  in _msg_id    integer)
{
  for (SELECT MSG_ID FROM OMAIL.WA.MESSAGES where DOMAIN_ID = _domain_id and USER_ID = _user_id and PARENT_ID = _msg_id) do
    OMAIL.WA.omail_del_message(_domain_id,_user_id, MSG_ID);

  DELETE
    FROM OMAIL.WA.MSG_PARTS
   where DOMAIN_ID = _domain_id and USER_ID = _user_id and MSG_ID = _msg_id;

  DELETE
    FROM OMAIL.WA.MESSAGES
   where DOMAIN_ID = _domain_id and USER_ID = _user_id and MSG_ID = _msg_id;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_del_pop3_acc(
  in _domain_id integer,
  in _user_id   integer,
  in _del_acc_id integer)
{
  DELETE
    FROM OMAIL.WA.EXTERNAL_POP_ACC
   where DOMAIN_ID = _domain_id
     and USER_ID = _user_id
     and ACC_ID = _del_acc_id;

  return 0;
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
   DELETE
     FROM OMAIL.WA.MSG_PARTS
    where DOMAIN_ID = _domain_id and USER_ID = _user_id and MSG_ID = _msg_id and PART_ID = _part_id;

   OMAIL.WA.omail_update_msg_attached(_domain_id,_user_id,_msg_id);
   _error := 0;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_delete_domain_data(
  in _domain_id integer)
{
  delete from OMAIL.WA.MSG_PARTS        where DOMAIN_ID = _domain_id;
  delete from OMAIL.WA.MESSAGES         where DOMAIN_ID = _domain_id;
  delete from OMAIL.WA.EXTERNAL_POP_ACC where DOMAIN_ID = _domain_id;
  delete from OMAIL.WA.FOLDERS          where DOMAIN_ID = _domain_id;
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
create procedure OMAIL.WA.omail_delete_message(
  in _domain_id integer,
  in _user_id   integer,
  inout params  any,
  inout _params any)
{
  declare N integer;

  if (OMAIL.WA.omail_getp('folder_id',_params) = 110) {
    N := 0;
    while(N < length(params)) {
      if (params[N] = 'ch_msg')
        OMAIL.WA.omail_del_message(_domain_id, _user_id, cast(params[N + 1] as integer));
      N := N + 2;
    }
  } else {
    OMAIL.WA.omail_setparam('fid', params, 110);
    OMAIL.WA.omail_move_msg(_domain_id, _user_id, params);
  };
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
  delete from OMAIL.WA.EXTERNAL_POP_ACC where DOMAIN_ID = _domain_id and USER_ID = _user_id;
  for (select FOLDER_ID from OMAIL.WA.FOLDERS where DOMAIN_ID = _domain_id and USER_ID = _user_id and PARENT_ID IS NULL) do
    OMAIL.WA.omail_del_folder(_domain_id,_user_id,FOLDER_ID,0);
  delete from OMAIL.WA.SETTINGS         where DOMAIN_ID = _domain_id and USER_ID = _user_id;
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

  SELECT blob_to_string(TDATA),blob_to_string(BDATA),MIME_TYPE,FNAME,APARAMS
    INTO _tdata,_bdata,_mime_type,_fname,_aparams
    FROM OMAIL.WA.MSG_PARTS A,
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
  if ((_encoding = 'quoted-printable') or (strstr(_tdata,'=3D'))) {
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
create procedure OMAIL.WA.omail_edit_folder(
  in  _domain_id   integer,
  in  _user_id     integer,
  in  _folder_id    integer,
  in  _action_id    integer,
  in  _folder_name varchar,
  in  _parent_id    integer,
  out _error       integer)
{
  _error := 0;
  if (_action_id = 0) {
    -- edit folder
    if (length(_folder_name) > 20)
      _error := 1201;
    else if (length(_folder_name) < 2)
      _error := 1202;
    else if (OMAIL.WA.omail_check_folder_name(_domain_id,_user_id,_parent_id,_folder_name, _folder_id))
      _error := 1203;

    else {
      _error := OMAIL.WA.omail_check_parent(_domain_id,_user_id,_folder_id,_parent_id);
      if (_error = 0)
        UPDATE OMAIL.WA.FOLDERS
           SET PARENT_ID = _parent_id,
               NAME      = _folder_name
         where DOMAIN_ID = _domain_id
           and USER_ID   = _user_id
           and FOLDER_ID = _folder_id;
    }
  } else if (_action_id = 1) {
    -- delete(move to Trash) folder and message
    _parent_id := 110;
    _error := OMAIL.WA.omail_check_parent(_domain_id,_user_id,_folder_id,_parent_id);
    if (_error = 0) {
      if (OMAIL.WA.omail_check_istrash(_domain_id,_user_id,_folder_id,_error) = -1) {
        if (_error = 0)
          OMAIL.WA.omail_del_folder(_domain_id,_user_id,_folder_id,1);
      } else {
        if (_error = 0) {
          declare N integer;
          declare _folder_name, _folder_name2 varchar;

          N := 2;
          _folder_name := (SELECT NAME FROM OMAIL.WA.FOLDERS where DOMAIN_ID = _domain_id and USER_ID = _user_id and FOLDER_ID = _folder_id);
          _folder_name2 := _folder_name;

          while (OMAIL.WA.omail_check_folder_name(_domain_id, _user_id, _parent_id, _folder_name2)) {
            _folder_name2 := sprintf('%s-%d', _folder_name, N);
            N := N + 1;
          }
          UPDATE OMAIL.WA.FOLDERS
             SET NAME = concat('_x_y_z_', _folder_name2)
           where DOMAIN_ID = _domain_id
             and USER_ID   = _user_id
             and FOLDER_ID = _folder_id;
          UPDATE OMAIL.WA.FOLDERS
             SET PARENT_ID = _parent_id
           where DOMAIN_ID = _domain_id
             and USER_ID   = _user_id
             and FOLDER_ID = _folder_id;
          UPDATE OMAIL.WA.FOLDERS
             SET NAME = _folder_name2
           where DOMAIN_ID = _domain_id
             and USER_ID   = _user_id
             and FOLDER_ID = _folder_id;
        }
      }
    }
  } else if (_action_id = 2) {
    -- empty folder to Trash
    _parent_id := 110;
    if (OMAIL.WA.omail_check_istrash(_domain_id,_user_id,_folder_id,_error) = -1) {
      if (_error = 0)
        OMAIL.WA.omail_del_folder(_domain_id,_user_id,_folder_id,0);
    } else {
      if (_error = 0)
        UPDATE OMAIL.WA.MESSAGES SET FOLDER_ID = _parent_id where DOMAIN_ID = _domain_id and USER_ID = _user_id and FOLDER_ID = _folder_id;
    }
  }
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

  declare _rs,_sid,_realm,_sql_result1,_faction,_folder_name varchar;
  declare _page_params any;
  declare _sql_statm,_sql_params,_user_info any;
  declare _user_id,_folder_id,_parent_id,_error,_domain_id integer;

  _sid       := get_keyword('sid',params,'');
  _realm     := get_keyword('realm',params,'');
  _user_info := get_keyword('user_info',params);

  -- TEMP constants -----------------------------
  _user_id   := get_keyword('user_id',_user_info);
  _domain_id := 1;

  -- Set constants  -------------------------------------------------------------
  _sql_params  := vector(0,0,0,0,0,0);
  _page_params := vector(0,0,0,0,0,0,0,0,0,0,0,0);

  -- Set Variable--------------------------------------------------------------
  _faction     := get_keyword('fa',params,'');  -- cnf -> "create new folder"
  _parent_id   := get_keyword('pid',params,''); -- parent_id on folder
  _folder_id   := get_keyword('fid',params,''); -- folder_id
  _folder_name := trim(get_keyword('fname',params,'')); -- name for new folder

  -- Form Action---------------------------------------------------------------
  if (_faction = 'cnf') {
    -- > 'create new folder'
    OMAIL.WA.test(_folder_name, vector('name', 'Folder name', 'class', 'folder', 'type', 'varchar', 'minLength', 2, 'maxLength', 20));
    _folder_id := OMAIL.WA.omail_folder_create(_domain_id,_user_id,_parent_id,_folder_name,_error);
    if (_error = 0)
      OMAIL.WA.utl_redirect(sprintf('folders.vsp?sid=%s&realm=%s&bp=%d',_sid,_realm,_folder_id));
    else
      OMAIL.WA.utl_redirect(sprintf('err.vsp?sid=%s&realm=%s&err=%d',_sid,_realm,_error));
    return;
  };

  -- Page Params---------------------------------------------------------------
  aset(_page_params,0,vector('sid',_sid));
  aset(_page_params,1,vector('realm',_realm));
  aset(_page_params,2,vector('parent_id',_parent_id));
  aset(_page_params,3,vector('user_info',OMAIL.WA.array2xml(_user_info)));

  -- SQL Statement-------------------------------------------------------------
  _sql_statm  := vector('SELECT FOLDER_ID,NAME FROM OMAIL.WA.FOLDERS where DOMAIN_ID = ? and USER_ID = ? and PARENT_ID');
  _sql_statm  := vector_concat(_sql_statm,vector('SELECT COUNT(*) as "ALL_CNT",SUM(DSIZE) as "ALL_SIZE",SUM(OMAIL.WA.omail_cnt_msg(MSTATUS,\'NW\',1)) as "NEW_CNT",SUM(OMAIL.WA.omail_cnt_msg(MSTATUS,\'NW\',DSIZE)) as "NEW_SIZE" FROM OMAIL.WA.MESSAGES where DOMAIN_ID = ? and USER_ID = ? and FOLDER_ID = ?'));
  _sql_params := vector(vector(_domain_id,_user_id,''),vector(_domain_id,_user_id,''));-- user_id

  _sql_result1:= sprintf('%s',OMAIL.WA.omail_folders_list(_domain_id,_user_id,vector()));

  -- XML structure-------------------------------------------------------------
  _rs := OMAIL.WA.omail_page_params(_page_params);
  _rs := sprintf('%s<folders>' ,_rs);
  _rs := sprintf('%s%s' ,_rs,_sql_result1);
  _rs := sprintf('%s</folders>' ,_rs);

  return _rs;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_folder_name(
  in _domain_id   integer,
  in _user_id     integer,
  in _folder_id   integer)
{
  return coalesce((SELECT NAME FROM OMAIL.WA.FOLDERS where DOMAIN_ID = _domain_id and USER_ID = _user_id and FOLDER_ID = _folder_id), '');
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_folder_create(
  in  _domain_id   integer,
  in  _user_id     integer,
  in  _parent_id    integer,
  in  _folder_name varchar,
  out _error       integer)
{
  declare _folder_id integer;
  _error := 0;

  if (length(_folder_name) > 20)
    _error := 1201;

  else if (length(_folder_name) < 2)
    _error := 1202;

  else if (OMAIL.WA.omail_check_folder_name(_domain_id, _user_id, _parent_id, _folder_name))
    _error := 1203;

  else {
    _folder_id := sequence_next('OMAIL.WA.omail_seq_eml_folder_id');
    insert into OMAIL.WA.FOLDERS(DOMAIN_ID, USER_ID, FOLDER_ID, PARENT_ID, NAME)
      values (_domain_id, _user_id, _folder_id, _parent_id, _folder_name);

    return _folder_id;
  };
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_folders_list(
  in _domain_id integer,
  in _user_id   integer,
  inout _params any)
{
  declare _rs,_s,_ftree_loc,_ftree,_m_list varchar;
  declare _all_cnt,_new_cnt,N,_len,_level,_all_size integer;

  _rs := '';
  N := 0;
  _ftree :='';

  SELECT COUNT(*) into _len FROM OMAIL.WA.FOLDERS where DOMAIN_ID = _domain_id and USER_ID = _user_id and PARENT_ID IS NULL;

  for (SELECT * FROM OMAIL.WA.FOLDERS where DOMAIN_ID = _domain_id and USER_ID = _user_id and PARENT_ID IS NULL) do {
    _m_list := '';
    if (OMAIL.WA.omail_getp('folder_id',_params) = FOLDER_ID) {
      OMAIL.WA.omail_setparam('skiped',_params,ceiling((cast(OMAIL.WA.omail_getp('list_pos',_params) as integer) - 1)/10)*10);
      _m_list := sprintf('<m_list>%s</m_list>\n',OMAIL.WA.omail_msg_list(_domain_id,_user_id,_params));
    }

    OMAIL.WA.omail_cnt_message(_domain_id,_user_id,FOLDER_ID,_all_cnt,_new_cnt,_all_size);
    if (length(_ftree) > 0)
      _ftree := concat(substring(_ftree,1,(length(_ftree)-16)),replace(substring(_ftree,length(_ftree)-15,16),'<fnode>-</fnode>','<fnode>.</fnode>'));
    _ftree := replace(_ftree,'F','I');
    if (N + 1 = _len)
      _ftree_loc := sprintf('%s<fnode>%s</fnode>',_ftree,'-');
    else
      _ftree_loc := sprintf('%s<fnode>%s</fnode>',_ftree,'F');

    _rs := sprintf('%s<folder>\n', _rs);
    _rs := sprintf('%s<folder_id>%d</folder_id>\n',_rs, FOLDER_ID);
    _rs := sprintf('%s<name><![CDATA[%s]]></name>\n', _rs, NAME);
    _rs := sprintf('%s<level str="" num="0" />\n' ,_rs);
    _rs := sprintf('%s<ftree>%s</ftree>\n', _rs, _ftree_loc);
    _rs := sprintf('%s%s\n', _rs, _m_list);
    _rs := sprintf('%s<all_cnt>%d</all_cnt>\n',_rs,_all_cnt);
    _rs := sprintf('%s<all_size>%d</all_size>\n',_rs,_all_size);
    _rs := sprintf('%s<new_cnt>%d</new_cnt>\n',_rs,_new_cnt);
    _s  := OMAIL.WA.omail_folders_list_recu(_domain_id,_user_id,FOLDER_ID,_params,_level+1,_ftree_loc);
    if (_s <> '')
      _rs := sprintf('%s<folders>\n%s\n</folders>\n', _rs, _s);
    _rs := sprintf('%s</folder>\n' , _rs);
    N := N + 1;
  };
  return _rs;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_folders_list_recu(
  in    _domain_id  integer,
  in    _user_id     integer,
  in    _folder_id  integer,
  inout _params      any,
  in    _level      integer,
  in    _ftree      varchar)
{
  declare _rs,_s,_ftree_loc,_m_list varchar;
  declare _all_cnt,_new_cnt,N,_len,_all_size integer;

  _rs := '';
  N := 0;

  SELECT COUNT(*) into _len FROM OMAIL.WA.FOLDERS where DOMAIN_ID = _domain_id and USER_ID = _user_id and PARENT_ID = _folder_id;

  for (SELECT * FROM OMAIL.WA.FOLDERS where DOMAIN_ID = _domain_id and USER_ID = _user_id and PARENT_ID = _folder_id) do {
    _m_list := '';
    if (OMAIL.WA.omail_getp('folder_id',_params) = FOLDER_ID) {
      OMAIL.WA.omail_setparam('skiped',_params,ceiling((cast(OMAIL.WA.omail_getp('list_pos',_params) as integer) - 1)/10)*10);
      _m_list := sprintf('<m_list>%s</m_list>\n',OMAIL.WA.omail_msg_list(_domain_id,_user_id,_params));
    }
    OMAIL.WA.omail_cnt_message(_domain_id,_user_id,FOLDER_ID,_all_cnt,_new_cnt,_all_size);
    if (length(_ftree) > 0)
      _ftree := concat(substring(_ftree,1,(length(_ftree)-16)),replace(substring(_ftree,length(_ftree)-15,16),'<fnode>-</fnode>','<fnode>.</fnode>'));
    _ftree := replace(_ftree,'F','I');
    if (N + 1 = _len){
       _ftree_loc := sprintf('%s<fnode>%s</fnode>',_ftree,'-');
    } else {
       _ftree_loc := sprintf('%s<fnode>%s</fnode>',_ftree,'F');
    }
    _rs := sprintf('%s<folder>\n' ,_rs);
    _rs := sprintf('%s<folder_id>%d</folder_id>\n' ,_rs,FOLDER_ID);
    _rs := sprintf('%s<name><![CDATA[%s]]></name>\n',_rs,NAME);
    _rs := sprintf('%s<level str="%s" num="%d" />\n',_rs,repeat('-',_level),_level);
    _rs := sprintf('%s<ftree>%s</ftree>\n' ,_rs,_ftree_loc);
    _rs := sprintf('%s%s' ,_rs,_m_list);
    _rs := sprintf('%s<all_cnt>%d</all_cnt>\n', _rs ,_all_cnt);
    _rs := sprintf('%s<all_size>%d</all_size>\n' ,_rs,_all_size);
    _rs := sprintf('%s<new_cnt>%d</new_cnt>\n' ,_rs,_new_cnt);
    _s  := OMAIL.WA.omail_folders_list_recu(_domain_id,_user_id,FOLDER_ID,_params,_level+1,_ftree_loc);
    if (_s <> '')
      _rs := sprintf('%s<folders>\n%s\n</folders>\n', _rs, _s);
    _rs := sprintf('%s</folder>\n', _rs);
    N := N + 1;
  };
  return _rs;

}
;

-------------------------------------------------------------------------------
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
  if (mod(len,2) <> 0) signal('69000','ARRAY_NO_ASSOCIATIVE');
  res := '';
  ind := 0;
  while(ind < len){  -- find how many element to remove
    if (aselected = aref(arr,ind))
      res := sprintf('%s\n<option value="%s" selected="1">%s</option>',res,aref(arr,ind),aref(arr,ind+1));
    else
      res := sprintf('%s\n<option value="%s">%s</option>',res,aref(arr,ind),aref(arr,ind+1));
    ind := ind + 2;
  };
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
  for (SELECT PART_ID,TYPE_ID
         FROM OMAIL.WA.MSG_PARTS
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
  _encoding := (cast(xpath_eval(concat('//',_element), _aparams_xml) as varchar));
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
  for (SELECT MSG_ID, FOLDER_ID, SRV_MSG_ID, REF_ID, MSTATUS, ATTACHED, ADDRESS, RCV_DATE, SND_DATE, MHEADER, DSIZE, PRIORITY, SUBJECT, ADDRES_INFO, PARENT_ID
         FROM OMAIL.WA.MESSAGES
        where DOMAIN_ID = _domain_id
          and USER_ID   = _user_id
          and MSG_ID    =_msg_id) do {
    _to  := OMAIL.WA.omail_address2str('to',  ADDRESS, 0);
    _cc  := OMAIL.WA.omail_address2str('cc',  ADDRESS, 0);
    _bcc := OMAIL.WA.omail_address2str('bcc', ADDRESS, 0);
    _dcc := OMAIL.WA.omail_address2str('dcc', ADDRESS, 0);
    PARENT_ID := coalesce (PARENT_ID,0);

    for (SELECT TYPE_ID, TDATA, APARAMS, TAGS
           FROM OMAIL.WA.MSG_PARTS
          where DOMAIN_ID = _domain_id
            and USER_ID   = _user_id
            and MSG_ID    = _msg_id
            and PART_ID   = _part_id) do {
      _body    := TDATA;
      _type_id := TYPE_ID;
      _aparams := APARAMS;
      _tags    := TAGS;
    }
    if (_part_id <> 1)
      _tags := OMAIL.WA.tags_select(_domain_id, _user_id, _msg_id);
    _fields := vector('_res',1,'msg_id',MSG_ID,'to',_to,'cc',_cc,'bcc',_bcc,'dcc',_dcc,'address',ADDRESS,'subject',SUBJECT,'tags',_tags,'mt',_type_id,'type_id',_type_id,'priority',PRIORITY,'message',cast(_body as varchar),'folder_id',FOLDER_ID,'mstatus',MSTATUS,'attached',ATTACHED,'rcv_date',RCV_DATE,'dsize',DSIZE,'aparams',_aparams,'srv_msg_id',SRV_MSG_ID,'ref_id',REF_ID,'parent_id',PARENT_ID,'header',MHEADER);

    for (N := 0; N < length(_fields); N := N + 1)
      aset(_fields, N, coalesce(_fields[N], ''));
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

  for (SELECT PNAME FROM OMAIL.WA.MIME_HANDLERS where TYPE_ID = _type_id) do {
    call (PNAME)(_data, _out);
    _rs := sprintf('%s%s', _rs, _out);
  };
  if (length(_rs) > 0) {
    _rs := sprintf('<handlers>%s</handlers>',_rs);
    return 1;
  };
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
  in    _level      integer)
{
  declare N,_body_beg,_body_end,_type_id,_pdefault,_dsize,_content_id,_att_fname,_freetext_id integer;
  declare _aparams,_encoding,_mime_type,_body,_dispos,_att_name varchar;

  N := 0;
  while (N < length(_mime_parts)) {
    if (isarray(aref(aref(_mime_parts,N), 0))) {
      if (isarray(aref(aref(_mime_parts,N), 2))) {
        OMAIL.WA.omail_get_mime_parts(_domain_id,_user_id,_msg_id,_parent_id,_folder_id,_part_id,_source,aref(aref(_mime_parts,N),2),_level + 1);

      } else if (isarray(aref(aref(aref(_mime_parts,N),1),2))) {
        _body_beg    := aref(aref(aref(_mime_parts,N),1),0);
        _body_end    := aref(aref(aref(_mime_parts,N),1),1);
        _body        := subseq (blob_to_string (_source), _body_beg, _body_end + 1);
        OMAIL.WA.omail_receive_message(_domain_id,_user_id,_msg_id,_body,null,null,_folder_id);

      } else {
        _freetext_id := sequence_next ('OMAIL.WA.omail_seq_eml_freetext_id');
        _aparams     := OMAIL.WA.array2xml(aref(aref(_mime_parts,N),0));
        _encoding    := get_keyword_ucase('Content-Transfer-Encoding',aref(aref(_mime_parts,N),0),'');
        _dispos      := get_keyword_ucase('Content-Disposition',aref(aref(_mime_parts,N),0),'');
        _mime_type   := get_keyword_ucase('Content-Type',aref(aref(_mime_parts,N),0),'');
        _body_beg    := aref(aref(aref(_mime_parts,N),1),0);
        _body_end    := aref(aref(aref(_mime_parts,N),1),1);
        _body        := subseq (blob_to_string (_source), _body_beg, _body_end + 1);
        _content_id  := get_keyword_ucase('Content-ID',aref(aref(_mime_parts,N),0),'');
        _att_fname   := get_keyword_ucase('name',aref(aref(_mime_parts,N),0),'');
        _att_name    := get_keyword_ucase('filename',aref(aref(_mime_parts,N),0),'');
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
    N := N + 1;
  }
  return;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_get_mimetype_name(
  in  _id   integer,
  out _name varchar)
{
  _name := coalesce((SELECT MIME_TYPE FROM OMAIL.WA.RES_MIME_TYPES where ID = _id), 'application/octet-stream');
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
create procedure OMAIL.WA.omail_get_pop3_acc(
  in _domain_id integer,
  in _user_id   integer,
  in _acc_id    integer)
{
  declare _rs,_sql_result1 varchar;
  declare N integer;

  N := 0;
  _rs  := '';

  _sql_result1 := sprintf('<folders>%s</folders>',OMAIL.WA.omail_folders_list(_domain_id,_user_id,vector()));
  if (_acc_id = 0) { -- list
    for (SELECT * FROM OMAIL.WA.EXTERNAL_POP_ACC where DOMAIN_ID = _domain_id and USER_ID = _user_id) do {
      _rs  := sprintf('%s<acc>',_rs);
      _rs  := sprintf('%s<acc_id>%d</acc_id>', _rs, ACC_ID);
      _rs  := sprintf('%s<acc_name><![CDATA[%s]]></acc_name>', _rs, ACC_NAME);
      _rs  := sprintf('%s<pop_server><![CDATA[%s]]></pop_server>', _rs, POP_SERVER);
      _rs  := sprintf('%s<pop_port>%d</pop_port>',_rs, POP_PORT);
      _rs  := sprintf('%s<user_name><![CDATA[%s]]></user_name>',_rs, USER_NAME);
      _rs  := sprintf('%s<folder_id>%d</folder_id>',_rs, FOLDER_ID);
      _rs  := sprintf('%s<last_check><![CDATA[%s]]></last_check>',_rs, case when isnull(LAST_CHECK) then '' else cast(LAST_CHECK as varchar) end);
      _rs  := sprintf('%s<ch_error>%d</ch_error>',_rs, CH_ERROR);
      _rs  := sprintf('%s%s', _rs, _sql_result1);
      _rs  := sprintf('%s<intervals>%d</intervals>',_rs,CH_INTERVAL);
      _rs  := sprintf('%s</acc>',_rs);
      N := N + 1;
    }
  } else if (_acc_id = -1) { -- new
      _rs  := sprintf('%s<acc_edit>',_rs);
      _rs  := sprintf('%s<acc_id>%d</acc_id>',_rs,0);
      _rs  := sprintf('%s<pop_port>%d</pop_port>',_rs,110);
      _rs  := sprintf('%s<mcopy>%d</mcopy>',_rs,0);
      _rs  := sprintf('%s%s',_rs,_sql_result1);
      _rs  := sprintf('%s<intervals>%d</intervals>',_rs,1);
      _rs  := sprintf('%s<mcopy>%d</mcopy>',_rs,1);
      _rs  := sprintf('%s</acc_edit>',_rs);

  } else { -- edit
    for (SELECT * FROM OMAIL.WA.EXTERNAL_POP_ACC where DOMAIN_ID = _domain_id and USER_ID = _user_id and ACC_ID = _acc_id) do {
      _rs  := sprintf('%s<acc_edit>',_rs);
      _rs  := sprintf('%s<acc_id>%d</acc_id>', _rs, ACC_ID);
      _rs  := sprintf('%s<acc_name><![CDATA[%s]]></acc_name>', _rs, ACC_NAME);
      _rs  := sprintf('%s<pop_server><![CDATA[%s]]></pop_server>', _rs, POP_SERVER);
      _rs  := sprintf('%s<pop_port>%d</pop_port>',_rs,POP_PORT);
      _rs  := sprintf('%s<user_name><![CDATA[%s]]></user_name>', _rs, USER_NAME);
      _rs  := sprintf('%s<user_pass><![CDATA[%s]]></user_pass>',_rs,'**********');
      _rs  := sprintf('%s<folder_id>%d</folder_id>', _rs, FOLDER_ID);
      _rs  := sprintf('%s%s',_rs,_sql_result1);
      _rs  := sprintf('%s<intervals>%d</intervals>',_rs, CH_INTERVAL);
      _rs  := sprintf('%s<mcopy>%d</mcopy>',_rs, MCOPY);
      _rs  := sprintf('%s</acc_edit>',_rs);
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
    if (isnull(_settings[N]))
      aset(_settings, N, '');

  if (mod(length(_settings),2) <> 0)
    _settings := vector_concat(_settings,vector(''));

  if (OMAIL.WA.omail_getp('msg_order', _settings) not in (1,2,3,4,5,6,7))
    OMAIL.WA.omail_setparam('msg_order', _settings, 5);

  if (OMAIL.WA.omail_getp('msg_direction', _settings) not in (1,2))
    OMAIL.WA.omail_setparam('msg_direction',_settings, 2);

  if (OMAIL.WA.omail_getp('folder_view', _settings) not in (1,2))
    OMAIL.WA.omail_setparam('folder_view',_settings, 1);

  if (OMAIL.WA.omail_getp('usr_sig_inc', _settings) not in (0,1))
    OMAIL.WA.omail_setparam('usr_sig_inc', _settings,0);

  if (OMAIL.WA.omail_getp('usr_sig_inc',_settings) = 0)
    OMAIL.WA.omail_setparam('usr_sig_txt', _settings, '');

  if (OMAIL.WA.omail_getp('msg_result',_settings) <= 0)
    OMAIL.WA.omail_setparam('msg_result',_settings, 10);

  if (OMAIL.WA.omail_getp('msg_name', _settings) not in (0,1))
    OMAIL.WA.omail_setparam('msg_name', _settings, 0);

  if (OMAIL.WA.omail_getp('msg_name',_settings) = 0)
    OMAIL.WA.omail_setparam('msg_name_txt',_settings, '');

  if (OMAIL.WA.omail_getp('atom_version',_settings) = '')
    OMAIL.WA.omail_setparam('atom_version',_settings, '1.0');

  if (OMAIL.WA.omail_getp('spam', _settings) not in (0,1))
    OMAIL.WA.omail_setparam('spam',_settings, 0);

  if (OMAIL.WA.omail_getp('conversation', _settings) not in (0,1))
    OMAIL.WA.omail_setparam('conversation',_settings, 0);

  OMAIL.WA.omail_setparam ('discussion', _settings, OMAIL.WA.discussion_check ());
  OMAIL.WA.omail_setparam('update_flag', _settings, 0);
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

  if (not is_empty_or_null(dashboard)) {
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
    for (;i < l; i := i + 1) {
      if (cast(xpath_eval ('number(@id)', xp[i], 1) as integer) <> _msg_id)
  	    http (serialize_to_UTF8_xml (xp[i]), stream);
  	}
  }

  waID := coalesce((select top 1 WAI_ID from DB.DBA.WA_MEMBER, DB.DBA.WA_INSTANCE where WAM_INST = WAI_NAME and WAM_USER = _user_id and WAI_TYPE_NAME = 'oMail' order by WAI_ID), 0);
  S := sprintf (
         '<mail id="%d">'||
           '<title><![CDATA[%s]]></title>'||
           '<dt>%s</dt>'||
           '<link>/oMail/%d/open.vsp?op=%d</link>'||
           '<from><![CDATA[%s]]></from>'||
           '<email><![CDATA[%s]]></email>'||
         '</mail>',
         _msg_id, _title, OMAIL.WA.dt_iso8601 (_date), waID, _msg_id, _from, _fromEMail);

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

  if (not is_empty_or_null(dashboard)) {
    declare xt, xp any;
    declare i, l int;

    xt := xtree_doc (dashboard);
    xp := xpath_eval ('/mail-db/*', xt, 0);
    l := length (xp);
    for (i := 0; i < l; i := i + 1) {
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
create procedure OMAIL.WA.host_url ()
{
  declare ret varchar;

  --return '';
  if (is_http_ctx ()) {
    ret := http_request_header (http_request_header ( ) , 'Host' , null , sys_connected_server_address ());
    if (isstring (ret) and strchr (ret , ':') is null) {
      declare hp varchar;
      declare hpa any;

      hp := sys_connected_server_address ();
      hpa := split_and_decode ( hp , 0 , '\0\0:');
      ret := ret || ':' || hpa [1];
    }
  } else {
    ret := sys_connected_server_address ();
    if (ret is null)
      ret := sys_stat ('st_host_name') || ':' || server_http_port ();
  }
  return 'http://' || ret ;
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
    return 'file://apps/oMail/xslt/';
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
  in _address   varchar)
{
  insert soft OMAIL.WA.FOLDERS(DOMAIN_ID, USER_ID, FOLDER_ID, NAME) values (_domain_id, _user_id, 100, 'Inbox');
  insert soft OMAIL.WA.FOLDERS(DOMAIN_ID, USER_ID, FOLDER_ID, NAME) values (_domain_id, _user_id, 110, 'Trash');
  insert soft OMAIL.WA.FOLDERS(DOMAIN_ID, USER_ID, FOLDER_ID, NAME) values (_domain_id, _user_id, 120, 'Sent');
  insert soft OMAIL.WA.FOLDERS(DOMAIN_ID, USER_ID, FOLDER_ID, NAME) values (_domain_id, _user_id, 130, 'Draft');
  insert soft OMAIL.WA.FOLDERS(DOMAIN_ID, USER_ID, FOLDER_ID, NAME) values (_domain_id, _user_id, 125, 'Spam');

  -- insert welcome message
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

  _text := OMAIL.WA.omail_welcome_msg_1('Mail admin','admin@domain.com',_address,_address,OMAIL.WA.omail_tstamp_to_mdate(now()));
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
  if (get_keyword ('att_source', _params, '-1') = '0') {
    _attach    := get_keyword ('att_1', _params, '', 1);
    _att_attrs := get_keyword_ucase ('attr-att_1', _params);
    _att_fname := trim(get_keyword_ucase ('filename', _att_attrs));
    if (is_empty_or_null(_att_fname))
      return;
    _att_name  := substring(_att_fname,OMAIL.WA.omail_locate_last('\\',_att_fname)+1,length(_att_fname));
    _att_type  := get_keyword_ucase ('Content-Type', _att_attrs);

  } else if (get_keyword ('att_source', _params, '-1') = '1') {
    declare reqHdr, resHdr varchar;
    declare vspx_user, vspx_pwd varchar;
    declare userInfo any;

    _att_fname := trim(get_keyword ('att_2', _params, ''));
    if (is_empty_or_null(_att_fname))
      return;

    userInfo := vector('user_id', _user_id);
    OMAIL.WA.omail_dav_api_params(userInfo, vspx_user, vspx_pwd);
    reqHdr := sprintf('Authorization: Basic %s', encode_base64(vspx_user || ':' || vspx_pwd));
    commit work;
    _attach := http_get (OMAIL.WA.host_url () || _att_fname, resHdr, 'GET', reqHdr);
    if (resHdr[0] like 'HTTP/1._ 200 %') {
      _att_type := http_request_header(resHdr, 'Content-Type', null, 'application/octet-stream');
      _att_name := substring(_att_fname,OMAIL.WA.omail_locate_last('/',_att_fname)+1,length(_att_fname));
    } else {
      _error := 3003;
      return;
    }
  } else {
    return;
  }

  -- Insert attachments -----------------------------------------------------------------------------------------
  if (length(_attach) > 0) {
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
    _part_id := coalesce((SELECT MAX(PART_ID) FROM OMAIL.WA.MSG_PARTS where DOMAIN_ID = _domain_id and USER_ID = _user_id and MSG_ID = _msg_id), 0) + 1;
    insert into OMAIL.WA.MSG_PARTS(DOMAIN_ID, MSG_ID, USER_ID, PART_ID, TYPE_ID, CONTENT_ID, TDATA, DSIZE, APARAMS, PDEFAULT, FNAME, FREETEXT_ID)
      values (_domain_id, _msg_id, _user_id, _part_id, _type_id, '',_attach, length(_attach), _aparams, 0, _att_name, _freetext_id);
    UPDATE OMAIL.WA.MESSAGES
       SET ATTACHED = ATTACHED + 1
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
  UPDATE OMAIL.WA.MESSAGES
     SET MSTATUS = either(lt(MSTATUS,2),_mstatus,MSTATUS)
   where DOMAIN_ID = _domain_id
     and USER_ID = _user_id
     and MSG_ID = _msg_id;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_mdate_to_tstamp(in _mdate varchar)
{
  ----------------------------------------------------------
  -- Get mail format "DAY, DD MON YYYY HH:MI:SS {+,-}HHMM"
  --      and return "DD.MM.YYYY HH:MI:SS" GMT
  ------------------------------------------------------------
  declare _arr, _months, _tzones, _rs, _tzone_z, _tzone_h, _tzone_m any;
  declare _date,_month,_year,_hms,_tzone varchar;

  _months := vector ('JAN', '01',
                     'FEB', '02',
                     'MAR', '03',
                     'APR', '04',
                     'MAY', '05',
                     'JUN', '06',
                     'JUL', '07',
                     'AUG', '08',
                     'SEP', '09',
                     'OCT', '10',
                     'NOV', '11',
                     'DEC', '12'
                    );
  _tzones := vector ('Z',   '+0000',
                     'A',   '-0100',
                     'B',   '-0200',
                     'C',   '-0300',
                     'D',   '-0400',
                     'E',   '-0500',
                     'F',   '-0600',
                     'G',   '-0700',
                     'H',   '-0800',
                     'I',   '-0900',
                     'K',   '-1010',
                     'L',   '-1100',
                     'M',   '-1200',
                     'N',   '+0100',
                     'O',   '+0200',
                     'P',   '+0300',
                     'Q',   '+0400',
                     'R',   '+0500',
                     'S',   '+0600',
                     'T',   '+0700',
                     'U',   '+0800',
                     'V',   '+0900',
                     'W',   '+1010',
                     'X',   '+1100',
                     'Y',   '+1200',
                     'UT',  '+0000',
                     'GMT', '+0000',
                     'EST', '-0500',
                     'EDT', '-0400',
                     'CST', '-0600',
                     'CDT', '-0500',
                     'MST', '-0700',
                     'MDT', '-0600',
                     'PST', '-0800',
                     'PDT', '-0700'
                    );
  _arr := split_and_decode(ltrim(_mdate),0,'\0\0 ');

  if (length(_arr) = 6) {
    _date  := _arr[1];
    _month := _arr[2];
    _year  := _arr[3];
    _hms   := _arr[4];
    _tzone := _arr[5];

    _month := get_keyword_ucase (_month, _months, '');

    _tzone := get_keyword_ucase (_arr[5], _tzones, '');
    if (_tzone = '')
      _tzone := _arr[5];

    _tzone_z := substring(_tzone,1,1);
    declare continue handler for SQLSTATE '*' {
      _tzone_h := 0;
      _tzone_m := 0;
      goto _skip;
    };
    _tzone_h := atoi(substring(_tzone,2,2));
    _tzone_m := atoi(substring(_tzone,4,2));

  _skip:
    if (_tzone_z = '+'){
      _tzone_h := -_tzone_h;
      _tzone_m := -_tzone_m;
    }
    _rs := sprintf('%s.%s.%s %s',_month,_date,_year,_hms);
    _rs := stringdate(_rs);
    _rs := dateadd ('hour',   _tzone_h, _rs);
    _rs := dateadd ('minute', _tzone_m, _rs);

  } else {
    _rs := '01.01.1900 00:00:00'; -- set system date
  };
  return _rs;
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

  declare _rs,_sid,_realm,_op,_sql_result1,_sql_result2,_sql_result3,_sql_result4,_sql_result5,_pnames varchar;
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
  if (get_keyword('fa_move.x', params,'') <> '') {
    _rs := OMAIL.WA.omail_move_msg(_domain_id,_user_id,params);
    if (_rs = '1') {
      OMAIL.WA.omail_setparam('folder_id',_params,atoi(_folder_id));
      _op := OMAIL.WA.omail_params2str(_pnames,_params,',');
      OMAIL.WA.utl_redirect(sprintf('open.vsp?sid=%s&realm=%s&op=%s%s',_sid,_realm,_op,OMAIL.WA.omail_external_params_url(params)));
      return;
    } else {
      _op := OMAIL.WA.omail_params2str(_pnames,_params,',');
      OMAIL.WA.utl_redirect(sprintf('open.vsp?sid=%s&realm=%s&op=%s',_sid,_realm,_op));
      return;
    }

  } else if (get_keyword('fa_mark.x', params,'') <> '') { -- > 'mark msg'
    OMAIL.WA.omail_setparam('ch_mstatus',_params,1);
    OMAIL.WA.omail_mark_msg(_domain_id,_user_id, OMAIL.WA.omail_getp('msg_id',_params), atoi(get_keyword('ms',params,'1')));
    if (_error = 0){
      _op := OMAIL.WA.omail_params2str(_pnames,_params,',');
       OMAIL.WA.utl_redirect(sprintf('open.vsp?sid=%s&realm=%s&op=%s%s',_sid,_realm,_op,OMAIL.WA.omail_external_params_url(params)));
      return;
    }
    OMAIL.WA.utl_redirect(sprintf('err.vsp?sid=%s&realm=%s&err=%d',_sid,_realm,_error));
    return;

  } else if (get_keyword('fa_tags_save.x', params, '') <> '') {
    declare tags varchar;

    -- save tags
    tags := trim(get_keyword('tags', params, ''));
    if (tags <> '')
      if (not OMAIL.WA.validate_tags (tags)) {
        OMAIL.WA.utl_redirect(sprintf('err.vsp?sid=%s&realm=%s&err=%d',_sid,_realm,4001));
        return;
      }
          OMAIL.WA.tags_update(_domain_id,_user_id,OMAIL.WA.omail_getp('msg_id',_params), tags);
  }

  -- Change Settings --------------------------------------------------------------------
  if (not OMAIL.WA.omail_check_interval(OMAIL.WA.omail_getp('folder_view',_params),1,2)) { -- check FOLDER_VIEW
    OMAIL.WA.omail_setparam('folder_view',_params,OMAIL.WA.omail_getp('folder_view',_settings));
  } else {
    if (OMAIL.WA.omail_getp('folder_view',_params) <> OMAIL.WA.omail_getp('folder_view',_settings)){
      OMAIL.WA.omail_setparam('folder_view',_settings,OMAIL.WA.omail_getp('folder_view',_params));
      OMAIL.WA.omail_setparam('update_flag',_settings,1);
    }
  }

  if (OMAIL.WA.omail_getp('ch_mstatus',_params) <> 1)
    OMAIL.WA.omail_mark_msg(_domain_id,_user_id,OMAIL.WA.omail_getp('msg_id',_params),1);

  -- SQL Statement-------------------------------------------------------------------
  _sql_result1 := sprintf('%s',OMAIL.WA.omail_open_message(_domain_id,_user_id,_params, 1, 1));
  _sql_result2 := sprintf('%s',OMAIL.WA.omail_select_next_prev(_domain_id,_user_id,_params));
  _sql_result3 := sprintf('%s',OMAIL.WA.omail_select_attachment(_domain_id,_user_id,OMAIL.WA.omail_getp('msg_id',_params),0));
  _sql_result5 := sprintf('%s',OMAIL.WA.omail_select_attachment_msg(_domain_id,_user_id,OMAIL.WA.omail_getp('msg_id',_params),0));
  _sql_result4:= sprintf('<folders>%s</folders>',OMAIL.WA.omail_folders_list(_domain_id,_user_id,_params));

  -- Page Params---------------------------------------------------------------------
  aset(_page_params,0,vector('sid',_sid));
  aset(_page_params,1,vector('realm',_realm));
  aset(_page_params,2,vector('op',OMAIL.WA.omail_params2str(_pnames,_params,',')));
  aset(_page_params,3,vector('list_pos',OMAIL.WA.omail_getp('list_pos',_params)));
  aset(_page_params,4,vector('user_info',OMAIL.WA.array2xml(_user_info)));

  -- XML structure-------------------------------------------------------------------
  _rs := '';
  _rs := sprintf('%s%s',_rs,OMAIL.WA.omail_page_params(_page_params));
  _rs := sprintf('%s<message>', _rs);
  _rs := sprintf('%s%s',_rs,_sql_result1);
  _rs := sprintf('%s%s',_rs,_sql_result2);
  _rs := sprintf('%s</message>', _rs);
  _rs := sprintf('%s%s',_rs,_sql_result3);
  _rs := sprintf('%s%s',_rs,_sql_result5);
  _rs := sprintf('%s<folder_view>%d</folder_view>',_rs,OMAIL.WA.omail_getp('folder_view',_params));
  _rs := sprintf('%s%s',_rs,_sql_result4);
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

  UPDATE OMAIL.WA.MSG_PARTS
     SET CONTENT_ID = OMAIL.WA.omail_message_body_parse_func(_content_id,PART_ID,_body)
   where DOMAIN_ID = _domain_id and USER_ID = _user_id and MSG_ID = _msg_id and PDEFAULT = 0;
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
  if (strstr(_body, _pattern)){
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
  for (SELECT SUBJECT,ATTACHED,ADDRESS,DSIZE,MSG_ID,MSTATUS,PRIORITY,RCV_DATE
         FROM OMAIL.WA.MESSAGES
        where USER_ID = _user_id
          and FOLDER_ID = _folder_id
        ORDER BY MSTATUS)
  do {
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
create procedure OMAIL.WA.omail_move_msg(
  in _domain_id integer,
  in _user_id   integer,
  inout _params any)
{
  declare N,_folder_id integer;
  declare _sql varchar;
  declare _msgs,_sql_params,_pit any;

  N  := 0;
  _msgs := vector();
  _pit  := vector();
  _folder_id  := cast(get_keyword('fid',_params,'') as integer);

  while(N < length(_params)){
    if (_params[N] = 'ch_msg') {
      _msgs := vector_concat(_msgs,vector(cast(_params[N + 1] as integer)));
      _pit  := vector_concat(_pit,vector('?'));
    }
    N := N + 2;
  }

  if (length(_msgs) > 0) {
    _sql := sprintf('UPDATE OMAIL.WA.MESSAGES SET FOLDER_ID = ? where DOMAIN_ID = ? and USER_ID = ? and MSG_ID IN (%s)',OMAIL.WA.omail_array2string(_pit,','));
    _sql_params := vector_concat(vector(_folder_id,_domain_id,_user_id),_msgs); -- [0]folder_id,[1]domain_id,[2]user_id,[3][4]... -> MSG_IDs
    return OMAIL.WA.omail_select_exec(_sql,_sql_params);
  }
  return '0';
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_msg_list(
  in _domain_id integer,
  in _user_id integer,
  in _params any)
{
  declare _sql_statm,_sql_params,_order,_direction any;

  _order      := vector('','MSTATUS','PRIORITY','ADDRES_INFO','SUBJECT','RCV_DATE','DSIZE','ATTACHED');
  _direction  := vector('',' ','desc');
  _sql_statm  := sprintf('SELECT SUBJECT,ATTACHED,ADDRESS,DSIZE DSIZE,MSG_ID,MSTATUS,PRIORITY,RCV_DATE FROM OMAIL.WA.MESSAGES where DOMAIN_ID = ? and USER_ID = ? and FOLDER_ID = ? and PARENT_ID IS NULL ORDER BY %s %s,RCV_DATE desc', _order[OMAIL.WA.omail_getp('order',_params)], _direction[OMAIL.WA.omail_getp('direction',_params)]);
  _sql_params := vector(1, _user_id, OMAIL.WA.omail_getp('folder_id',_params));

  return OMAIL.WA.omail_sql_exec(_domain_id, _user_id, _sql_statm, _sql_params, OMAIL.WA.omail_getp('skiped',_params),OMAIL.WA.omail_getp('aresults',_params),concat(cast(OMAIL.WA.omail_getp('order',_params) as varchar),cast(OMAIL.WA.omail_getp('direction',_params) as varchar)));
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
create procedure OMAIL.WA.omail_email_search_str(
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
  for (N := 0; N < length(V); N := N + 1) {
    if (length(trim(V[L]))) {
      V1 := split_and_decode(trim(V[N]), 0, '\0\0 ');
      for (L := 0; L < length(V1); L := L + 1) {
        T := trim(V1[L]);
        T := replace(T, '&', '&amp;');
        T := replace(T, '\\', '&#092;');
        T := trim(T, '~');
        T := trim(T, '|');
        if (OMAIL.WA.validate_xcontains(T)) {
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
  declare tmp, _empty, _sql, _sql_statm, _sql_params, _order, _direction, _aquery any;

  _order       := vector('','MSTATUS','PRIORITY','ADDRES_INFO','SUBJECT','RCV_DATE','DSIZE','ATTACHED');
  _direction   := vector('',' ','desc');
  _sql_params  := vector(_domain_id, _user_id);
  _empty       := 0;

  ------------------------------------------------------------------------------
  -- Search string -------------------------------------------------------------
  ------------------------------------------------------------------------------
  if (get_keyword('mode',_params,'') = 'advanced') {
    ----------------------------------------------------------------------------
    -- advance search

    _sql_statm  := concat(' SELECT distinct <MAX> M.SUBJECT, \n',
                          '        M.ATTACHED, \n',
                          '        cast(M.ADDRESS as varchar) ADDRESS, \n',
                          '        M.DSIZE DSIZE, \n',
                          '        M.MSG_ID, \n',
                          '        M.MSTATUS, \n',
                          '        M.PRIORITY, \n',
                          '        M.RCV_DATE \n',
                          '   FROM OMAIL.WA.MESSAGES M, \n',
                          '        OMAIL.WA.MSG_PARTS P \n',
                          '  where M.DOMAIN_ID = P.DOMAIN_ID',
                          '    and M.USER_ID = P.USER_ID \n',
                          '    and M.MSG_ID = P.MSG_ID \n',
                          '    and M.DOMAIN_ID = ? \n',
                          '    and M.USER_ID = ? ');
    _sql := _sql_statm;

    if (atoi(get_keyword('q_fid', _params, '0')) <> 0) {
      _sql_statm  := sprintf('%s and FOLDER_ID = ?',_sql_statm);
      _sql_params := vector_concat(_sql_params,vector(cast(get_keyword('q_fid',_params,'') as integer)));
    }

    if (get_keyword('q_attach', _params, '') = '1')
      _sql_statm  := sprintf('%s and ATTACHED > 0', _sql_statm);

    if (get_keyword('q_after', _params, '') = '1') {
      tmp         := OMAIL.WA.dt_string(get_keyword('q_after_d', _params, ''), get_keyword('q_after_m', _params, ''), get_keyword('q_after_y', _params, ''));
      tmp         := OMAIL.WA.test(tmp, vector('name', 'Received after', 'class', 'date2', 'type', 'date'));
      _sql_statm  := sprintf('%s and RCV_DATE > ?',_sql_statm);
      _sql_params := vector_concat(_sql_params, vector(tmp)); --stringdate(
    }

    if (get_keyword('q_before', _params,'') = '1') {
      tmp         := OMAIL.WA.dt_string(get_keyword('q_before_d', _params, ''), get_keyword('q_before_m', _params, ''), get_keyword('q_before_y', _params, ''));
      tmp         := OMAIL.WA.test(tmp, vector('name', 'Received before', 'class', 'date2', 'type', 'date'));
      _sql_statm  := sprintf('%s and RCV_DATE < ?',_sql_statm);
      _sql_params := vector_concat(_sql_params, vector(tmp));
    }

    _aquery := '';
    tmp := OMAIL.WA.omail_email_search_str(get_keyword('q_from', _params, ''));
    if ((tmp = '') and (get_keyword('q_from', _params, '') <> ''))
      signal ('TEST', 'Field ''From'' contains invalid characters!<>');

    if (tmp <> '')
      _aquery := sprintf('%s and //from[text-contains(.,"%s")]', _aquery, tmp);

    tmp := OMAIL.WA.omail_email_search_str(get_keyword('q_to', _params, ''));
    if ((tmp = '') and (get_keyword('q_to', _params, '') <> ''))
      signal ('TEST', 'Field ''To'' contains invalid characters!<>');
    if (tmp <> '')
      _aquery := sprintf('%s and //to[text-contains(.,"%s")]', _aquery, tmp);

    if (_aquery <> '') {
      _sql_statm  := sprintf('%s and XCONTAINS(ADDRESS,?) ',_sql_statm);
      _sql_params := vector_concat(_sql_params,vector(substring(_aquery,5,length(_aquery))));
    }

    if (get_keyword('q_subject',_params,'') <> '') {
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

    if (_aquery <> '') {
      _sql_statm  := sprintf('%s and CONTAINS (TDATA, ?)', _sql_statm);
      _sql_params := vector_concat(_sql_params,vector(substring(_aquery,5,length(_aquery))));
    }

    if (_sql = _sql_statm)
      _empty := 1;
    tmp := OMAIL.WA.test(get_keyword('q_max', _params, '100'), vector('name', 'Max results', 'class', 'integer', 'minValue', 1, 'maxValue', 1000));
    _sql_statm := replace(_sql_statm, '<MAX>', 'TOP '||cast(tmp as varchar));

  } else {
    ----------------------------------------------------------------------------
    -- sample search

    _sql_statm := concat(' SELECT distinct M.SUBJECT, \n',
                         '        M.ATTACHED, \n',
                         '        cast(M.ADDRESS as varchar) ADDRESS, \n',
                         '        M.DSIZE DSIZE, \n',
                         '        M.MSG_ID, \n',
                         '        M.MSTATUS, \n',
                         '        M.PRIORITY, \n',
                         '        M.RCV_DATE \n',
                         '   FROM OMAIL.WA.MESSAGES M \n',
                         '  where M.DOMAIN_ID = ? \n',
                         '    and M.USER_ID = ? \n');
    _sql := _sql_statm;

    _aquery := '';
    tmp := OMAIL.WA.omail_email_search_str(get_keyword('q', _params, ''));
    if (tmp <> '') {
      _aquery := sprintf('and //*[text-contains(.,"%s")]', tmp);

      _sql_statm  := sprintf('%s and XCONTAINS(ADDRESS,?) \n',_sql_statm);
      _sql_params := vector_concat(_sql_params, vector(substring(_aquery,5,length(_aquery))));
    }
    if (_sql = _sql_statm)
      _empty := 1;
  }
  _sql_statm   := concat(_sql_statm, ' ORDER BY %s %s, RCV_DATE desc');
  _sql_statm   := sprintf(_sql_statm, aref(_order, cast(get_keyword('order',_params,'5') as integer)), aref(_direction, cast(get_keyword('direction',_params,'0') as integer)));

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

  if ((OMAIL.WA.omail_getp('re_mode',_params) = 1) or (OMAIL.WA.omail_getp('re_mode',_params) = 2)) {
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
    if (OMAIL.WA.omail_getp('re_mode',_params) = 1) {
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
    _rs := sprintf('%s<ref_msg_id>%s</ref_msg_id>\n' ,_rs,OMAIL.WA.omail_getp('srv_msg_id',_fields));
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

  } else if (OMAIL.WA.omail_getp('re_mode',_params) = 3) {
    -- user make forward msg
    --
    -- get message
    --
    _fields := OMAIL.WA.omail_get_message(_domain_id,_user_id,OMAIL.WA.omail_getp('re_msg_id',_params),1);
    if (length(_fields) = 0)
      return _rs;

    _body := OMAIL.WA.omail_getp('message',_fields);
    OMAIL.WA.omail_open_message_body_ind(_body);-- indent message text with '>'

    if (OMAIL.WA.omail_getp('attached',_fields) > 0) {
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

  } else {
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
    if (_domain_id = 1) {
    _ab_id := OMAIL.WA.check_app (_user_id, 'AddressBook');
    if (_ab_id <> 0)
      _addContact := AB.WA.ab_url (_ab_id);
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
    _rs := sprintf ('%s<to_snd_date>%s</to_snd_date>\n', _rs, OMAIL.WA.omail_tstamp_to_mdate (get_keyword ('rcv_date', _fields, '')));
    _rs := sprintf ('%s<address>%s</address>\n', _rs, get_keyword ('address', _fields));
    _rs := sprintf ('%s<mheader><![CDATA[%s]]></mheader>\n', _rs, coalesce(get_keyword ('header', _fields), ''));
    _rs := sprintf('%s<replyTo><![CDATA[%s]]></replyTo>\n', _rs, _replyTo);
    _rs := sprintf('%s<displayName><![CDATA[%s]]></displayName>\n', _rs, _displayName);
    _rs := sprintf ('%s<addContact>%s</addContact>\n', _rs, OMAIL.WA.xml2string (_addContact));

    if ((_type_id = 10110) and (OMAIL.WA.omail_getp('_html_parse',_params) <> 0)) {
      -- html version
      _body := xml_tree(_body, 2);
      if (not isarray(_body))
        signal('9001', 'open_message error');
      _body := xml_tree_doc(_body);

      -- XQUERY --------------------------------------------------------------
      xml_tree_doc_set_output (_body,'xhtml');
      _body := OMAIL.WA.utl_xml2str(_body);

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
  if (OMAIL.WA.omail_getp('re_mode',_params) = 1) { -- user make reply msg
    _re_head := sprintf('%s\n\n\n----- Original Message ----- \n',_re_head);
    _re_head := sprintf('%sFrom: \n',_re_head);
    _re_head := sprintf('%sTo: \n',_re_head);
    _re_head := sprintf('%sSent:: \n',_re_head);
    _re_head := sprintf('%sSubject: \n',_re_head);
    _body_lines := split_and_decode(_body,0,'\0\r\n');
    N := 0;
    _body := '';
    while(N < length(_body_lines)){
      _body := sprintf('%s\n&lt; %s',_body,aref(_body_lines,N));
      N := N + 1;
    }
  } else {
    open_message_images(_user_id,OMAIL.WA.omail_getp('_msg_id',_params),499,'dload.vsp?dp=%d,%d',_body);
  };

  _body := sprintf('%s%s',_re_head,_body);
  --_rs := sprintf('%s<type_id>%s</type_id>',_rs,_type_id);
  _rs := sprintf('%s<mbody><![CDATA[%s]]></mbody>',_rs,_body);
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
  declare _boundary,_b,_e,_rs,folder_id,srv_msg_id,ref_id,mstatus,attached,address,rcv_date,snd_date,mheader,dsize,priority,subject,addres_info,parent_id,N,_hh any;
  _rs  := '';
  N := 0;

      SELECT MHEADER
        INTO mheader
      FROM OMAIL.WA.MESSAGES where DOMAIN_ID = _domain_id and USER_ID = _user_id and MSG_ID =_msg_id;

      mheader := coalesce(mheader,'');
      _b := locate('boundary="',mheader,1);
      if (_b > 0){
        _e := locate('"',mheader,_b+10);
        _boundary := sprintf('<boundary>%s</boundary>\n',subseq(mheader,_b+9,_e-1));
      } else {
        _boundary := '';
      };

      -- decode message body
      _hh := sprintf('<mheader><![CDATA[%s]]></mheader>\n',mheader);
      _hh := sprintf('%s%s\n',_hh,_boundary);


      for (SELECT TYPE_ID,CONTENT_ID,FNAME,TDATA,BDATA,PDEFAULT,APARAMS,PART_ID
             FROM OMAIL.WA.MSG_PARTS
            where DOMAIN_ID = _domain_id and USER_ID = _user_id and MSG_ID = _msg_id and PDEFAULT = 1)
      do{
          _rs := sprintf('%s<mbody>\n',_rs);
          _rs := sprintf('%s<aparams>%s</aparams>\n',_rs,coalesce(APARAMS,''));
          _rs := sprintf('%s<mtext><![CDATA[%s]]></mtext>\n',_rs,coalesce(TDATA,BDATA));
          _rs := sprintf('%s</mbody>\n',_rs);
          N := N + 1;
      };

      if (N > 1){
         _hh := sprintf('%s<alternative>\n',_hh);
         _hh := sprintf('%s<boundary2>%s</boundary2>\n', _hh,sprintf('------2_NextPart_%s',md5(concat(cast(now() as varchar),cast('xx' as varchar)))));
         _hh := sprintf('%s%s',_hh,_rs);
         _hh := sprintf('%s</alternative>\n',_hh);

      } else {
         _hh := sprintf('%s%s',_hh,_rs);
      };

  _hh := sprintf('%s%s',_hh,OMAIL.WA.omail_select_attachment(_domain_id,_user_id,_msg_id,1));
  return _hh;
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
  for(SELECT MSG_ID,PART_ID,CONTENT_ID
        FROM OMAIL.WA.MSG_PARTS
       where DOMAIN_ID = _domain_id and USER_ID = _user_id and MSG_ID = _msg_id and TYPE_ID >= _type_id and TYPE_ID < (_type_id + 10000) and CONTENT_ID IS NOT NULL)
  do {
    _body := replace(_body,concat('cid:',CONTENT_ID),sprintf(_url,MSG_ID,PART_ID));
  }
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_page_params(in _params any){
  declare _rs varchar;
  declare N,_len integer;
  declare _cell any;
  _rs :='';
  N :=0;

  if (isarray(_params)){
   _len := length(_params);
   while(N<_len){
    _cell := aref(_params,N);
    if (isarray(_cell))
      _rs := sprintf('%s<%s>%s</%s>\n',_rs,aref(_cell,0),cast(aref(_cell,1)as varchar),aref(_cell,0));
    N := N + 1;
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
  declare _string,_names_arr,_values_arr any;
  declare _len,N,_int integer;
  _string := '';
  _names_arr  := split_and_decode(_names,0,concat('\0\0',_separator));

  N := 0;
  _len := length(_names_arr);
  while(N < _len){
     _string := sprintf('%s,%d',_string,get_keyword(aref(_names_arr,N),_params,''));
     N := N + 1;
  }
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
  if (OMAIL.WA.omail_getp('msg_id',_params) <> 0) {
    _sql_result1 := sprintf('%s',OMAIL.WA.omail_open_message(_domain_id,_user_id,OMAIL.WA.omail_getp('msg_id',_params),1,1));
    _sql_result2 := sprintf('%s',OMAIL.WA.omail_select_attachment(_domain_id,_user_id,OMAIL.WA.omail_getp('msg_id',_params),0));
    if (length(_sql_result1) = 0) {
      OMAIL.WA.utl_redirect(sprintf('write.vsp?sid=%s&realm=%s&wp=%d',_sid,_realm,0));
      return;
    }
  }

  -- XML structure-------------------------------------------------------------------
  _rs := '';
  _rs := sprintf('%s<message>', _rs);
  _rs := sprintf('%s%s',_rs,_sql_result1);
  _rs := sprintf('%s</message>', _rs);

  return _rs;
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
  _sql_result1 := sprintf('%s',OMAIL.WA.omail_open_message(_domain_id,_user_id,_params,1,1));
  _sql_result3 := sprintf('%s',OMAIL.WA.omail_select_attachment(_domain_id,_user_id,OMAIL.WA.omail_getp('msg_id',_params),0));

  -- Page Params---------------------------------------------------------------------
  aset(_page_params,0,vector('sid',_sid));
  aset(_page_params,1,vector('realm',_realm));
  aset(_page_params,2,vector('op',OMAIL.WA.omail_params2str(_pnames,_params,',')));
  aset(_page_params,3,vector('list_pos',OMAIL.WA.omail_getp('list_pos',_params)));
  aset(_page_params,4,vector('user_info',OMAIL.WA.array2xml(_user_info)));

  -- XML structure-------------------------------------------------------------------
  _rs := '';
  _rs := sprintf('%s%s',_rs,OMAIL.WA.omail_page_params(_page_params));
  _rs := sprintf('%s<message>', _rs);
  _rs := sprintf('%s%s',_rs,_sql_result1);
  _rs := sprintf('%s</message>', _rs);
  _rs := sprintf('%s%s',_rs,_sql_result3);

  return _rs;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.is_spam (
  in _user_id integer,
  in _mail varchar)
{
  declare S varchar;
  declare st, msg, meta, rows any;

  S := 'sparql
        PREFIX foaf: <http://xmlns.com/foaf/0.1/>
        SELECT ?mbox, ?mbox_sha1sum
        FROM <%s>
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
  in    _folder_id   integer)
{
  declare _subject, _tags, _from, _returnPath, _to, _cc, _bcc,_srv_msg_id,_ref_id,_address,_address_info,_mstatus,_attached,_mheader,_att_fname varchar;
  declare _body, _bodys, _parts, _attrs,_snd_date,_rcv_date,_body_parts,_message,_usern, _settings any;
  declare _body_beg, _body_end,_msg_id,_priority,_dsize,N,_freetext_id integer;

  if (not(isstring(_source)))
    signal('0001','Not a mail msg');

  _message := mime_tree(_source);
  if (not(isarray(_message)))
    return 0;

  _attrs   := aref(_message, 0);
  _bodys   := aref(_message, 1);
  _parts   := aref(_message, 2);

  if (not(isarray(_attrs)))
    return 0;

  _msg_id        := sequence_next ('OMAIL.WA.omail_seq_eml_msg_id');
  _freetext_id   := sequence_next ('OMAIL.WA.omail_seq_eml_freetext_id');
  _subject       := get_keyword_ucase('Subject',_attrs,'');
  _from          := get_keyword_ucase('From',_attrs,'');
  _returnPath    := get_keyword_ucase ('Return-Path',_attrs, '');
  _to            := get_keyword_ucase('To',_attrs,'');
  _cc            := get_keyword_ucase('CC',_attrs,'');
  _bcc           := get_keyword_ucase('BCC',_attrs,'');
  _srv_msg_id    := get_keyword_ucase('Message-ID',_attrs,'');
  _ref_id        := get_keyword_ucase('References',_attrs,'');
  _snd_date      := get_keyword_ucase('Date',_attrs,'');
  _address_info  := OMAIL.WA.omail_address2xml('from',_from,1);
  _mstatus       := 0;
  _attached      := 0;
  _tags          := '';
  _settings      := OMAIL.WA.omail_get_settings (_domain_id, _user_id, 'base_settings');
  if (cast(get_keyword ('spam', _settings, '0') as integer) = 1)
    if (OMAIL.WA.omail_address2xml ('from', _from, 2) <> OMAIL.WA.omail_address2xml ('to', _to, 2)) {
      if (OMAIL.WA.omail_address2xml ('from', _from, 2) <> OMAIL.WA.omail_address2xml ('returnPath', _returnPath, 2)) {
        _folder_id := 125;
      } else {
        if (OMAIL.WA.is_spam (_user_id, OMAIL.WA.omail_address2xml ('returnPath', _returnPath, 2)))
          _folder_id := 125;
      }
    }


  if (get_keyword_ucase('X-MSMail-Priority',_attrs,'') <> '')
    OMAIL.WA.omail_get_mm_priority(get_keyword_ucase('X-MSMail-Priority',_attrs,''),_priority);
  else
    _priority  := 3;

  _address  := '<addres_list>';
  _address  := sprintf('%s%s',_address,OMAIL.WA.omail_address2xml('to', _to,0));
  _address  := sprintf('%s%s',_address,OMAIL.WA.omail_address2xml('from', _from,0));
  _address  := sprintf('%s%s',_address,OMAIL.WA.omail_address2xml('cc', _cc,0));
  _address  := sprintf('%s%s',_address,OMAIL.WA.omail_address2xml('bcc', _bcc,0));
  _address  := sprintf('%s</addres_list>',_address);


  _rcv_date := now();
  _snd_date := OMAIL.WA.omail_mdate_to_tstamp(_snd_date);
  _mheader  := substring(subseq (_source, 0, aref(_bodys,0) - 3),1,1000);
  _dsize    := length(_source);

  _srv_msg_id := replace(_srv_msg_id,'<','');
  _srv_msg_id := replace(_srv_msg_id,'>','');
  _ref_id     := replace(_ref_id,'<','');
  _ref_id     := replace(_ref_id,'>','');
  _subject    := replace(_subject,'>','&gt;');
  _subject    := replace(_subject,'<','&lt;');

  insert into OMAIL.WA.MESSAGES(FREETEXT_ID,DOMAIN_ID,MSG_ID,USER_ID,ADDRES_INFO,FOLDER_ID,MSTATUS,ATTACHED,ADDRESS,RCV_DATE,SND_DATE,MHEADER,DSIZE,PRIORITY,SUBJECT,SRV_MSG_ID,REF_ID,PARENT_ID,UNIQ_MSG_ID,MSG_SOURCE)
    values (_freetext_id,_domain_id,_msg_id,_user_id,_address_info,_folder_id,_mstatus,_attached,_address,_rcv_date,_snd_date,_mheader,_dsize,_priority,_subject,_srv_msg_id,_ref_id,_parent_id,_uniq_msg_id,_msg_source);

  ----------------------------------------------------------------------------
  -- PARTS -------------------------------------------------------------------
  ----------------------------------------------------------------------------
  declare _mime_parts,_aparams any;
  declare _encoding,_mime_type,_fname varchar;
  declare _part_id,_type_id,_pdefault integer;
  _part_id := 1;
  _fname   := '';

  if (isarray(_parts)) {
    -- mime body
    OMAIL.WA.omail_get_mime_parts(_domain_id,_user_id,_msg_id,_parent_id,_folder_id,_part_id,_source,_parts,0);
  } else {
    -- plain text or special body
    _body_beg  := aref(_bodys,0);
    _body_end  := aref(_bodys,1);
    _body      := subseq (blob_to_string (_source), _body_beg, _body_end + 1);
    _dsize     := length(_body);
    _mime_type := get_keyword_ucase('Content-Type',_attrs, '');
    if (_mime_type = '')
      _mime_type := 'text/plain';

    _type_id   := OMAIL.WA.res_get_mimetype_id(_mime_type);
    _pdefault  := 1;
    if (_type_id not in (10100, 10110)) {
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
      values (_domain_id,_msg_id,_user_id,_part_id,_type_id,_body,_tags,_dsize,_aparams,_pdefault,_freetext_id,_fname);

  }
  OMAIL.WA.omail_update_msg_size(_domain_id,_user_id,_msg_id);
  OMAIL.WA.omail_update_msg_attached(_domain_id,_user_id,_msg_id);
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
  declare _val any;
  _rs := '';
  _i := 0;

  if (_ind < _skipped)
    return '';

  _rs   := sprintf('<message>');
  while(_i < length(_descr)){
    _cell := lower (aref(_descr,_i));
    _val  := aref(_rows,_i);
    _val  := replace(_val,'&','&amp;');

    _rs := sprintf('%s<%s>%s</%s>',_rs,_cell,cast(_val as varchar),_cell);
    _i := _i + 1;
  }
  return sprintf('%s</message>',_rs);
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
  declare _address,_subject,_tags,_mheader,_mstatus,_from,_to,_cc,_bcc,_dcc,_address_info,_pdata,_aparams,_ref_id varchar;
  declare _folder_id,_priority,_dsize,_attached,_part_id,_type_id,_dsize,_pdefault,_freetext_id,_msg_source integer;
  declare _rcv_date, _snd_date any;
  declare _rfc_id, _rfc_references any;

  _error := 0;

  _folder_id  := cast(get_keyword('folder_id',_params, '130') as integer);
  _priority   := cast(get_keyword('priority', _params, '3') as integer);
  _subject    := trim(get_keyword('subject',  _params, ''));
  _ref_id     := get_keyword('rmid',_params,'');
  _mheader    := '';
  _rcv_date   := now();
  _snd_date   := now();
  _mstatus    := 5;
  _attached   := 0;
  _pdefault   := 1;
  _msg_source := 0; -- '-1' ->from SMTP; '0' ->inside; '>0' - from POP3 account

  _from := trim(get_keyword('from',_params, ''));
  if (_from = '')
    _from := get_keyword('email', get_keyword('user_info', _params, ''), '');

  _to   := trim(get_keyword('to', _params,''));
  _cc   := trim(get_keyword('cc', _params,''));
  _bcc  := trim(get_keyword('bcc', _params,''));
  _dcc  := trim(get_keyword('dcc', _params,''));

  _part_id := 1;
  _type_id := 10100;
  if (get_keyword('mt',_params,'') = 'html')
    _type_id := 10110;

  _pdata   := get_keyword('message',_params,'');
  _dsize   := length(_pdata);
  _aparams := '<params/>';

  _to      := either(length(_to), _to, '~no address~');
  _subject := either(length(_subject), _subject, '~no subject~');
  _tags    := OMAIL.WA.tags_join(OMAIL.WA.tags_rules(_user_id, _pdata), get_keyword('tags', _params, ''));

  if (_dcc <> '') {
    declare _dcc_address, _dcc_addresses any;

    _dcc_address := OMAIL.WA.dcc_address(_dcc, _from);
    if (isnull(strstr(_cc, _dcc_address)))
      if (_cc = '')
        _cc := _dcc_address;
      else
        _cc := concat(_cc, ', ', _dcc_address);
    if (_dcc_address <> '') {
      _dcc_addresses := '';
      _dcc_addresses := _dcc_addresses || OMAIL.WA.omail_address2xml('to', _from,0);
      _dcc_addresses := _dcc_addresses || OMAIL.WA.omail_address2xml('to', _to,  0);
      _dcc_addresses := _dcc_addresses || OMAIL.WA.omail_address2xml('to', _cc,  0);
      _dcc_addresses := _dcc_addresses || OMAIL.WA.omail_address2xml('to', _bcc, 0);
      _dcc_addresses := sprintf('<addres_list>%s</addres_list>', _dcc_addresses);
      OMAIL.WA.dcc_update(_dcc_address, _dcc_addresses);
    }
  }

  _address_info := OMAIL.WA.omail_address2xml('to', _to, 1); -- return first name or address
  _address :=  '<addres_list>';
  _address :=  sprintf('%s%s', _address, OMAIL.WA.omail_address2xml('from', _from,0));
  _address :=  sprintf('%s%s', _address, OMAIL.WA.omail_address2xml('to',   _to,  0));
  _address :=  sprintf('%s%s', _address, OMAIL.WA.omail_address2xml('cc',   _cc,  0));
  _address :=  sprintf('%s%s', _address, OMAIL.WA.omail_address2xml('bcc', _bcc,  0));
  _address :=  sprintf('%s%s', _address, OMAIL.WA.omail_address2xml('dcc', _dcc,  0));
  _address :=  sprintf('%s</addres_list>',_address);

  _rfc_id  :=  get_keyword('rfc_id', _params,'');
  _rfc_references := get_keyword('rfc_references', _params,'');
  if (_msg_id = 0) {
    _msg_id      := sequence_next ('OMAIL.WA.omail_seq_eml_msg_id');
    _freetext_id := sequence_next ('OMAIL.WA.omail_seq_eml_freetext_id');

    insert into OMAIL.WA.MESSAGES(DOMAIN_ID,MSG_ID,USER_ID,ADDRES_INFO,FOLDER_ID,MSTATUS,ATTACHED,ADDRESS,RCV_DATE,SND_DATE,MHEADER,DSIZE,PRIORITY,SUBJECT,REF_ID,FREETEXT_ID,MSG_SOURCE, M_RFC_ID, M_RFC_REFERENCES)
      values (_domain_id,_msg_id,_user_id,_address_info,_folder_id,_mstatus,_attached,_address,_rcv_date,_snd_date,_mheader,_dsize,_priority,_subject,_ref_id,_freetext_id,_msg_source, _rfc_id, _rfc_references);

    insert into OMAIL.WA.MSG_PARTS(DOMAIN_ID,MSG_ID,USER_ID,PART_ID,TYPE_ID,TDATA,TAGS,DSIZE,APARAMS,PDEFAULT,FREETEXT_ID)
      values (_domain_id,_msg_id,_user_id,_part_id,_type_id,_pdata,_tags,_dsize,_aparams,_pdefault,_freetext_id);

  } else {
    UPDATE OMAIL.WA.MESSAGES
       SET ADDRES_INFO = _address_info,
           FOLDER_ID   = _folder_id,
           ADDRESS     = _address,
           RCV_DATE    = _rcv_date,
           DSIZE       = cast(_dsize as varchar),
           PRIORITY    = _priority,
           SUBJECT     = _subject
     where DOMAIN_ID   = _domain_id
       and USER_ID     = _user_id
       and MSG_ID      = _msg_id;

    UPDATE OMAIL.WA.MSG_PARTS
       SET TYPE_ID     = _type_id,
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
create procedure OMAIL.WA.omail_save_pop3_acc(
  in _domain_id integer,
  in _user_id   integer,
  inout _params any)
{
  declare _acc_id,_ch_interval,_mcopy,_del_acc_id,_folder_id,_error,_pop_port integer;
  declare _acc_name,_pop_server,_user_name,_user_pass,_fname varchar;

  _acc_name    := trim(get_keyword('acc_name', _params, '~no name~'));
  _pop_server  := trim(get_keyword('pop_server', _params,''));
  _user_name   := trim(get_keyword('user_name', _params,''));
  _user_pass   := get_keyword('user_pass', _params);
  _fname       := get_keyword('fname', _params);
  _pop_port    := cast(get_keyword('pop_port', _params,110) as integer);
  _ch_interval := cast(get_keyword('ch_interval', _params, 2) as integer);
  _mcopy       := cast(get_keyword('mcopy', _params, 1) as integer);
  _acc_id      := cast(get_keyword('acc_id', _params, 0) as integer);
  _del_acc_id  := cast(get_keyword('del_acc_id', _params, 0) as integer);
  _folder_id   := cast(get_keyword('fid',_params, 100) as integer);

  OMAIL.WA.test(_acc_name, vector('name', 'Account Name', 'class', 'varchar', 'canEmpty', 0));
  OMAIL.WA.test(_pop_server, vector('name', 'Server Address', 'class', 'varchar', 'canEmpty', 0));
  OMAIL.WA.test(_user_name, vector('name', 'User Name', 'class', 'varchar', 'canEmpty', 0));

  if (length(_fname) <> 0) {
    OMAIL.WA.test(_fname, vector('name', 'Folder name', 'class', 'folder', 'type', 'varchar', 'minLength', 2, 'maxLength', 20));
    _folder_id := OMAIL.WA.omail_folder_create(_domain_id,_user_id,_folder_id,_fname,_error);
    if (_error <> 0)
      return _error;
  };

  if (_acc_id <> 0) {
    UPDATE OMAIL.WA.EXTERNAL_POP_ACC
       SET ACC_NAME = _acc_name,
           POP_SERVER = _pop_server,
           POP_PORT = _pop_port,
           USER_NAME = _user_name,
           FOLDER_ID = _folder_id,
           CH_INTERVAL = _ch_interval,
           MCOPY = _mcopy
     where DOMAIN_ID = _domain_id
       and USER_ID = _user_id
       and ACC_ID = _acc_id;

    if (_user_pass <> '**********') {
      UPDATE OMAIL.WA.EXTERNAL_POP_ACC
         SET USER_PASS = pwd_magic_calc ('pop3',_user_pass)
       where DOMAIN_ID = _domain_id
         and USER_ID = _user_id
         and ACC_ID = _acc_id;
    };

  } else {
    _acc_id := sequence_next ('OMAIL.WA.omail_seq_eml_external_acc_id');
    insert into OMAIL.WA.EXTERNAL_POP_ACC(DOMAIN_ID,USER_ID,ACC_ID,ACC_NAME,POP_SERVER,POP_PORT,USER_NAME,USER_PASS,FOLDER_ID,CH_INTERVAL,MCOPY,CH_ERROR)
      values (_domain_id,_user_id,_acc_id,_acc_name,_pop_server,_pop_port,_user_name,pwd_magic_calc ('pop3',_user_pass),_folder_id,_ch_interval,_mcopy,0);
  };
  return 0;
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

  declare exit handler for SQLSTATE '*' {
    if (__SQL_STATE = '1901') {
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
  if (get_keyword('search.x',params,'') <> '') {
    OMAIL.WA.omail_setparam('order', _params, cast(get_keyword('q_order', params, get_keyword('order', _params)) as integer));
    OMAIL.WA.omail_setparam('direction', _params, cast(get_keyword('q_direction', params, get_keyword('direction', _params)) as integer));
  }

  _order := vector('','MSTATUS','PRIORITY','ADDRES_INFO','SUBJECT','RCV_DATE','DSIZE','ATTACHED');
  _direction := vector('',' ','desc');

  if (OMAIL.WA.omail_getp('msg_result',_settings) <> '') {
    OMAIL.WA.omail_setparam('aresults',_params,OMAIL.WA.omail_getp('msg_result',_settings));
  } else {
    OMAIL.WA.omail_setparam('aresults',_params,10);
  }

  -- Check Params for ilegal values---------------------------------------------------
  if (not OMAIL.WA.omail_check_interval(OMAIL.WA.omail_getp('skiped',_params),0,100000)) { -- check SKIPED
    OMAIL.WA.utl_redirect(sprintf('%s?sid=%s&realm=%s&err=%d','err.vsp',_sid,_realm,1101));
    return;
  }

  if (not OMAIL.WA.omail_check_interval(OMAIL.WA.omail_getp('order',_params),1,(length(_order)-1))) { -- check ORDER BY
    OMAIL.WA.omail_setparam('order',_params,OMAIL.WA.omail_getp('msg_order',_settings)); -- get from settings
  } else if (OMAIL.WA.omail_getp('order',_params) <> OMAIL.WA.omail_getp('msg_order',_settings)) {
    OMAIL.WA.omail_setparam('msg_order',_settings,OMAIL.WA.omail_getp('order',_params)); -- update new value in settings
    OMAIL.WA.omail_setparam('update_flag',_settings,1);
  }

  if (not OMAIL.WA.omail_check_interval(OMAIL.WA.omail_getp('direction',_params),1,(length(_direction)-1))) { -- check ORDER WAY
    OMAIL.WA.omail_setparam('direction',_params,OMAIL.WA.omail_getp('msg_direction',_settings));
  } else if (OMAIL.WA.omail_getp('direction',_params) <> OMAIL.WA.omail_getp('msg_direction',_settings)) {
    OMAIL.WA.omail_setparam('msg_direction',_settings,OMAIL.WA.omail_getp('direction',_params));
    OMAIL.WA.omail_setparam('update_flag',_settings,1);
  }

  if (not OMAIL.WA.omail_check_interval(OMAIL.WA.omail_getp('folder_view',_params),1,2)) { -- check FOLDER_VIEW
    OMAIL.WA.omail_setparam('folder_view',_params,OMAIL.WA.omail_getp('folder_view',_settings));
  } else if (OMAIL.WA.omail_getp('folder_view',_params) <> OMAIL.WA.omail_getp('folder_view',_settings)){
    OMAIL.WA.omail_setparam('folder_view',_settings,OMAIL.WA.omail_getp('folder_view',_params));
    OMAIL.WA.omail_setparam('update_flag',_settings,1);
  }

  -- Form Action---------------------------------------------------------------------
  if (get_keyword('fa_cancel.x',params,'') <> '') {
    OMAIL.WA.utl_doredirect(sprintf('box.vsp?sid=%s&realm=%s&bp=110',_sid,_realm));
    return;
  }

  if (get_keyword('fa_move.x',params,'') <> '') {
    _rs := OMAIL.WA.omail_move_msg(_domain_id,_user_id,params);
  } else if (get_keyword('fa_delete.x',params,'') <> '') {
    OMAIL.WA.omail_delete_message(_domain_id,_user_id,params,_params);
  }

  if (get_keyword('c_tag', params, '') <> '')
    OMAIL.WA.omail_setparam('q_tags', params, OMAIL.WA.tags_join(get_keyword('q_tags', params, ''), get_keyword('c_tag', params, '')));

  _params := vector_concat(_params, params);
  _sql_result1 := OMAIL.WA.omail_msg_search(_domain_id, _user_id, _params);

  -- GET SETTINGS ------------------------------
  _settings := OMAIL.WA.omail_get_settings(_domain_id, _user_id, 'base_settings');

  -- Page Params---------------------------------------------------------------------
  aset(_page_params,0,vector('sid', _sid));
  aset(_page_params,1,vector('realm', _realm));
  aset(_page_params,2,vector('mode', get_keyword('mode',params, '')));
  aset(_page_params,3,vector('bp', OMAIL.WA.omail_params2str(_pnames,_params,',')));
  aset(_page_params,4,vector('atom_version', get_keyword('atom_version',_settings,'1.0')));
  aset(_page_params,5,vector('user_info', OMAIL.WA.array2xml(_user_info)));

  -- SQL Statement-------------------------------------------------------------------
  _sql_result2 := sprintf('<folders>%s</folders>',OMAIL.WA.omail_folders_list(_domain_id,_user_id,vector()));

  -- Export URL-------------------------------------------------------------------
  declare tmp varchar;


  tmp := '';
  if (get_keyword('mode',_params,'') = 'advanced') {
    tmp := concat(tmp, '&amp;mode=advanced');
    if (get_keyword('q_fid', _params, '0') <> '0')
      tmp := concat(tmp, sprintf('&amp;fid=%U', get_keyword('q_fid', _params)));
    if (get_keyword('q_attach', _params, '0') = '1')
      tmp := concat(tmp, sprintf('&amp;attach=%U', get_keyword('q_attach', _params)));
    if (get_keyword('q_after', _params, '') = '1')
      tmp := concat(tmp, sprintf('&amp;after=%U', OMAIL.WA.dt_string(get_keyword('q_after_d', _params, ''), get_keyword('q_after_m', _params, ''), get_keyword('q_after_y', _params, ''))));
    if (get_keyword('q_before', _params, '') = '1')
      tmp := concat(tmp, sprintf('&amp;before=%U', OMAIL.WA.dt_string(get_keyword('q_before_d', _params, ''), get_keyword('q_before_m', _params, ''), get_keyword('q_before_y', _params, ''))));
    if (get_keyword('q_from', _params, '') <> '')
      tmp := concat(tmp, sprintf('&amp;from=%U', get_keyword('q_from', _params)));
    if (get_keyword('q_to', _params, '') <> '')
      tmp := concat(tmp, sprintf('&amp;to=%U', get_keyword('q_to', _params)));
    if (get_keyword('q_subject', _params, '') <> '')
      tmp := concat(tmp, sprintf('&amp;subject=%U', get_keyword('q_subject', _params)));
    if (get_keyword('q_body', _params, '') <> '')
      tmp := concat(tmp, sprintf('&amp;body=%U', get_keyword('q_body', _params)));
    if (get_keyword('q_tags', _params, '') <> '')
      tmp := concat(tmp, sprintf('&amp;tags=%U', get_keyword('q_tags', _params)));
    if (get_keyword('q_max', _params, '') <> '')
      tmp := concat(tmp, sprintf('&amp;max=%U', get_keyword('q_max', _params)));
    if (get_keyword('q_cloud', _params, '') <> '')
      tmp := concat(tmp, sprintf('&amp;cloud=%U', get_keyword('q_cloud', _params)));
  } else {
    if (get_keyword('q', _params, '0') <> '0')
      tmp := concat(tmp, sprintf('&amp;q=%U', get_keyword('q', _params, '')));
  }
  if (not is_empty_or_null(get_keyword('order', _params)))
    tmp := concat(tmp, sprintf('&amp;order=%d', get_keyword('order', _params)));
  if (not is_empty_or_null(get_keyword('direction', _params)))
    tmp := concat(tmp, sprintf('&amp;direction=%d', get_keyword('direction', _params)));

  -- XML structure-------------------------------------------------------------------
  _rs := '';
  _rs := sprintf('%s%s', _rs, OMAIL.WA.omail_page_params(_page_params));
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
  _rs := sprintf('%s<q_after use="%s">' ,_rs, get_keyword('q_after',params,''));
  _rs := sprintf('%s%s' ,_rs, OMAIL.WA.utl_form_select_day  ('q_after_d', get_keyword('q_after_d',params,''), now()));
  _rs := sprintf('%s%s' ,_rs, OMAIL.WA.utl_form_select_month('q_after_m', get_keyword('q_after_m',params,''), now()));
  _rs := sprintf('%s%s' ,_rs, OMAIL.WA.utl_form_select_year ('q_after_y', get_keyword('q_after_y',params,''), now()));
  _rs := sprintf('%s</q_after>' ,_rs);
  _rs := sprintf('%s<q_before use="%s">' ,_rs, get_keyword('q_before',params,''));
  _rs := sprintf('%s%s' ,_rs, OMAIL.WA.utl_form_select_day  ('q_before_d', get_keyword('q_before_d',params,''), now()));
  _rs := sprintf('%s%s' ,_rs, OMAIL.WA.utl_form_select_month('q_before_m', get_keyword('q_before_m',params,''), now()));
  _rs := sprintf('%s%s' ,_rs, OMAIL.WA.utl_form_select_year ('q_before_y', get_keyword('q_before_y',params,''), now()));
  _rs := sprintf('%s</q_before>' ,_rs);
  _rs := sprintf('%s<q_max>%s</q_max>' ,_rs, get_keyword('q_max', params, '100'));
  _rs := sprintf('%s<q_cloud>%s</q_cloud>', _rs, get_keyword('q_cloud', params, '0'));
  _rs := sprintf('%s</query>' ,_rs);
  _rs := sprintf('%s<messages>' ,_rs);
  _rs := sprintf('%s%s' ,_rs, _sql_result1);
  _rs := sprintf('%s</messages>' ,_rs);
  _rs := sprintf('%s<folder_view>%d</folder_view>' ,_rs,OMAIL.WA.omail_getp('folder_view',_settings));
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

  for (SELECT FNAME,CONTENT_ID,PART_ID,DSIZE,TYPE_ID,BDATA,TDATA,APARAMS
         FROM OMAIL.WA.MSG_PARTS
        where DOMAIN_ID  = _domain_id
          and USER_ID    = _user_id
          and MSG_ID     = _msg_id
          and PDEFAULT   = 0
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
      if (_encoding = 'base64') {
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
  };

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
  for(SELECT * FROM OMAIL.WA.MESSAGES where DOMAIN_ID = _domain_id and USER_ID = _user_id and PARENT_ID = _msg_id ORDER BY MSG_ID)
  do {
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
  for(SELECT MSG_ID,SUBJECT FROM OMAIL.WA.MESSAGES where DOMAIN_ID = _domain_id and USER_ID = _user_id and PARENT_ID = _msg_id ORDER BY MSG_ID) do {
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

  if (isarray(_rows)){
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

  _order := vector('','MSTATUS','PRIORITY','ADDRES_INFO','SUBJECT','RCV_DATE','DSIZE');
  _direction := vector('',' ','desc');
  _sql := sprintf('SELECT MSG_ID FROM OMAIL.WA.MESSAGES where DOMAIN_ID = ? and USER_ID = ? and FOLDER_ID = ? and PARENT_ID IS NULL ORDER BY %s %s,RCV_DATE desc', _order[OMAIL.WA.omail_getp('order',_params)], _direction[OMAIL.WA.omail_getp('direction',_params)]);
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
  if (isarray(_rows)) {
    _ind := 0;
    _len := length(_rows);

    while(_ind < _len) {
      if (_rows[_ind][0] = OMAIL.WA.omail_getp('msg_id',_params)) {
        _rs := sprintf('%s <prev>%s</prev>',_rs,cast(_buf as varchar));
        if (_ind + 1 < _len)
          _rs := sprintf('%s <next>%d</next>',_rs,aref(aref(_rows,_ind + 1),0));
        return _rs;
      }
      _buf := _rows[_ind][0];
      _ind := _ind + 1;
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
  for (_i := 0; _i < length(_descr); _i := _i + 1) {
    _cell := lower (_descr[_i][0]);
    _value := _values[_i];
    if (isnull(_value)) {
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
  declare _sql_result1,_sql_result2,_xslt_url,_xslt_url2,_rs,_boundary,_body any;

  declare exit handler for SQLSTATE '2E000' {
    _error := 1901;
    return;
  };
  declare exit handler for SQLSTATE '08006'{
    _error := 1902;
    return;
  };

  _error     := 0;
  _xslt_url  := OMAIL.WA.omail_xslt_full('construct_mail.xsl');
  _xslt_url2 := OMAIL.WA.omail_xslt_full('construct_recip.xsl');

  OMAIL.WA.omail_setparam('msg_id', _params, _msg_id);
  OMAIL.WA.omail_setparam('_html_parse', _params, 0);

  -- execute procedure ---------------------------------------------------------
  _sql_result1 := OMAIL.WA.omail_open_message(_domain_id,_user_id, _params, 1, 0);
  OMAIL.WA.omail_message_body_parse(_domain_id,_user_id,_msg_id,_sql_result1);
  _sql_result2 := OMAIL.WA.omail_select_attachment(_domain_id,_user_id,_msg_id,1);
  _boundary    := sprintf('------_NextPart_%s',md5(cast(now() as varchar)));

  -- XML structure -------------------------------------------------------------
  _body := '<message>';
  _body := sprintf('%s<boundary>%s</boundary>', _body, _boundary);
  _body := sprintf('%s<charset>%s</charset>', _body, 'us-ascii');
  _body := sprintf('%s<srv_msg_id>%s</srv_msg_id>', _body, md5(concat(cast(_domain_id as varchar),cast(_user_id as varchar),cast(_msg_id as varchar),cast(now() as varchar))));
  _body := sprintf('%s%s%s</message>', _body, _sql_result1, _sql_result2);
  _body := xslt(_xslt_url, xml_tree_doc(xml_tree(_body)));

  _body := cast(_body as varchar);
  _body := replace(_body, CHR(10), '\r\n');

  declare _sender, _rec, _smtp_server any;

  _sender      := cast(xslt(_xslt_url2, xml_tree_doc(xml_tree(concat('<fr>',_sql_result1,'</fr>')))) as varchar);
  _rec         := cast(xslt(_xslt_url2, xml_tree_doc(xml_tree(concat('<to>',_sql_result1,'</to>')))) as varchar);
  if (not isnull(_skip)) {
    _rec := replace(_rec, sprintf('<%s>', _skip), '');
    _rec := trim(_rec);
    _rec := trim(_rec, ',');
    _rec := trim(_rec);
  }
  _smtp_server := cfg_item_value(virtuoso_ini_path(), 'HTTPServer', 'DefaultMailServer');
  smtp_send(_smtp_server, _sender, _rec, _body);

  if (_domain_id = 1) {
    if (OMAIL.WA.omail_getp('scopy', _params) = '1') {
      -- move msg to Sent
      update OMAIL.WA.MESSAGES
         set FOLDER_ID = 120
       where DOMAIN_ID = _domain_id
         and USER_ID   = _user_id
         and MSG_ID    = _msg_id;
    } else {
      -- delete msg
      OMAIL.WA.omail_del_message(_domain_id, _user_id, _msg_id);
    }
  }
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
  if (get_keyword('fa_save.x',params,'') <> '') {
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
    OMAIL.WA.omail_setparam('spam', _settings, cast(get_keyword ('spam', params, '0') as integer));
    OMAIL.WA.omail_setparam('conversation', _settings, cast(get_keyword('conversation', params, '0') as integer));

    OMAIL.WA.omail_setparam('update_flag', _settings, 1);

    -- Save Settings --------------------------------------------------------------
    OMAIL.WA.omail_set_settings(_domain_id, _user_id, 'base_settings', _settings, get_keyword('domain_id', _user_info));
    commit work;
  }
  if ((get_keyword ('fa_cancel.x',params,'') <> '') or (get_keyword ('fa_save.x',params,'') <> '')) {
    OMAIL.WA.utl_doredirect(sprintf('box.vsp?sid=%s&realm=%s&bp=100',_sid,_realm));
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
  _rs := sprintf ('%s<spam>%d</spam>', _rs, OMAIL.WA.omail_getp('spam', _settings));
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

  if (isnull(wa_id)) {
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

  for (N := 0; N < length(_params); N := N + 2){
    if (_params[N] = _name) {
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
  if (not isnull(_domain_id)) {
    _user_id   := OMAIL.WA.domain_owner_id(_domain_id);
    _domain_id := 1;  -- normal mail
  } else {
    _domain_id := (select C_DOMAIN_ID from OMAIL.WA.CONVERSATION where C_ADDRESS = _recipient);
    if (isnull(_domain_id))
      goto _end;
    _user_id   := OMAIL.WA.domain_owner_id(_domain_id);
  }
  OMAIL.WA.omail_receive_message(_domain_id, _user_id, null, _source, null, _msg_source, _folder_id);
  return (1);

_end:
  return (0);
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

  _ind := 0;
  _len := length(_params);
  while(_ind < _len){
    aset(_params,_ind,cast(_params[_ind] as integer));
    _ind := _ind + 1;
  }

  if (_len < _length){
    while(_ind < _length){
      _params := vector_concat(_params,vector(0));
      _ind := _ind + 1;
    };
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
  _sql_statm := concat(_sql_statm, ' FOR XML AUTO');
  exec(_sql_statm, _state, _msg, _sql_params, 1000, _descr, _rows);

  if (_state <> '00000') {
    signal(_state, _msg);
    return;
  }

  _rs := ' ';
  _len := length(_rows);
  if (_skipped >= _len) {
    _skipped := floor((_len - 1) / _pageSize) * _pageSize;
    if (_skipped < 0)
      _skipped := 0;
  }
  _max := 1;
  _min := 1000000;
  _dict := dict_new();
  for (_ind := 0; _ind < _len; _ind := _ind + 1) {
    if (_ind + 1 = _skipped)
      _rs := sprintf('%s<prev_msg>%d</prev_msg>\n', _rs, _rows[_ind][4]);
    if (_ind = (_skipped + _pageSize))
      _rs := sprintf('%s<next_msg>%d</next_msg>\n', _rs, _rows[_ind][4]);
    if ((_ind >= _skipped) and  (_ind < (_skipped + _pageSize))) {
      _rs := sprintf('%s<message>\n',_rs);
      _rs := sprintf('%s<position>%d</position>\n%s\n', _rs, _ind+1, OMAIL.WA.omail_select_xml(_descr[0], _rows[_ind]));
      _rs := sprintf('%s</message>',_rs);
    }
    if (_cloud) {
      _tags := OMAIL.WA.tags_select(_domain_id, _user_id, _rows[_ind][4]);
      if (_tags <> '') {
        _tags := split_and_decode (_tags, 0, '\0\0,');
        foreach (any _tag in _tags) do {
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
  if (_cloud) {
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
  if (aref(_params,2) = 1) { -- > confirm action
    OMAIL.WA.omail_edit_folder(_domain_id,_user_id,aref(_params,0),aref(_params,1),trim(get_keyword('oname',params,'')),atoi(get_keyword('pid',params,'')),_error);
    if (_error <> 0)
      OMAIL.WA.utl_redirect(sprintf('err.vsp?sid=%s&realm=%s&err=%d',_sid,_realm,_error));
    else if (aref(_params,3) = 1)
      OMAIL.WA.utl_redirect(sprintf('box.vsp?sid=%s&realm=%s&bp=110',_sid,_realm));
    else
      OMAIL.WA.utl_redirect(sprintf('folders.vsp?sid=%s&realm=%s',_sid,_realm));
    return;
  };

  _result1 := OMAIL.WA.omail_tools_action(_domain_id,_user_id,aref(_params,0),aref(_params,1),_error);
  if (_error <> 0) {
    OMAIL.WA.utl_redirect(sprintf('err.vsp?sid=%s&realm=%s&err=%d',_sid,_realm,_error));
    return;
  };

  -- Page Params---------------------------------------------------------------------
  aset(_page_params,0,vector('sid', _sid));
  aset(_page_params,1,vector('realm', _realm));
  aset(_page_params,2,vector('object_id', _params[0]));
  aset(_page_params,3,vector('object_name', sprintf('<![CDATA[%s]]>', OMAIL.WA.omail_folder_name(_domain_id, _user_id, _params[0]))));
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

  if (_output in ('rss', 'rdf', 'xbel', 'atom03', 'atom10')) {
    declare _from, _to, _subject, _body, _tags, _after, _before, _fid, _attach  varchar;
    declare _max, _order, _direction varchar;
    declare tmp any;

    declare sql, state, msg, meta, result any;

    _max       := get_keyword('max', params, '100');
    _order     := get_keyword('order', params, '');
    _direction := get_keyword('direction', params, '');

    _params    := vector();
    if (get_keyword('mode', params, '') = 'advanced') {
      _from      := get_keyword('from', params, '');
      _to        := get_keyword('to', params, '');
      _subject   := get_keyword('subject', params, '');
      _body      := get_keyword('body', params, '');
      _tags      := get_keyword('tags', params, '');
      _after     := get_keyword('after', params, '');
      _before    := get_keyword('before', params, '');
      _fid       := get_keyword('fid', params, '');
      _attach    := get_keyword('attach', params, '');

      _params    := vector_concat(_params, vector('mode', 'advanced'));
      _params    := vector_concat(_params, vector('q_from', _from));
      _params    := vector_concat(_params, vector('q_to', _to));
      _params    := vector_concat(_params, vector('q_subject', _subject));
      _params    := vector_concat(_params, vector('q_body', _body));
      _params    := vector_concat(_params, vector('q_tags', _tags));
      if (_after <> '') {
        tmp := OMAIL.WA.dt_deformat(_after);
        _params  := vector_concat(_params, vector('q_after', '1'));
        _params  := vector_concat(_params, vector('q_after_d', cast(dayofmonth(tmp) as varchar)));
        _params  := vector_concat(_params, vector('q_after_m', cast(month(tmp) as varchar)));
        _params  := vector_concat(_params, vector('q_after_y', cast(year(tmp) as varchar)));
      }
      if (_before <> '') {
        tmp := OMAIL.WA.dt_deformat(_before);
        _params  := vector_concat(_params, vector('q_before', '1'));
        _params  := vector_concat(_params, vector('q_before_d', cast(dayofmonth(tmp) as varchar)));
        _params  := vector_concat(_params, vector('q_before_m', cast(month(tmp) as varchar)));
        _params  := vector_concat(_params, vector('q_before_y', cast(year(tmp) as varchar)));
      }
      _params    := vector_concat(_params, vector('q_attach', _attach));
      _params    := vector_concat(_params, vector('q_fid', _fid));

    } else {
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
    http ('<rss version="2.0">\n');
    http ('<channel>\n');
    for (select U_FULL_NAME, U_E_MAIL from DB.DBA.SYS_USERS where U_ID = _user_id) do {
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
    foreach (any row in result) do {
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

  if (_action_id = 0){ -- edit folder
    if (_object_id <= 130){
       _error := 1301;
       return '';
    };

    SELECT NAME,PARENT_ID
      INTO _object_name,_parent_id
      FROM OMAIL.WA.FOLDERS
     where DOMAIN_ID = _domain_id and USER_ID = _user_id and FOLDER_ID = _object_id;

    _sql_result1 := sprintf('<parent_id>%d</parent_id>',_parent_id);
    _sql_statm   := vector('SELECT FOLDER_ID,NAME FROM OMAIL.WA.FOLDERS where DOMAIN_ID = ? and USER_ID = ? and PARENT_ID');
    _sql_params  := vector(vector(_domain_id,_user_id,''),vector(''));-- user_id
    _sql_result1 := sprintf('%s<folders>%s</folders>',_sql_result1,OMAIL.WA.omail_folders_list(_domain_id,_user_id,vector()));

  } else if (_action_id = 1){ -- delete folder
    if (_object_id <= 130) {
      _error := 1302;
      return '';
    }
    SELECT NAME
      INTO _object_name
      FROM OMAIL.WA.FOLDERS
     where DOMAIN_ID = _domain_id and USER_ID = _user_id and FOLDER_ID = _object_id;

    SELECT COUNT(*)
      INTO _sql_result1
      FROM OMAIL.WA.MESSAGES
     where DOMAIN_ID = _domain_id and USER_ID = _user_id and FOLDER_ID = _object_id;

    SELECT COUNT(*)
      INTO _sql_result2
      FROM OMAIL.WA.FOLDERS
     where DOMAIN_ID = _domain_id and USER_ID = _user_id and PARENT_ID = _object_id;

    _sql_result1 := sprintf('<count_m>%s</count_m>',cast(_sql_result1 as varchar));
    _sql_result1 := sprintf('%s<count_f>%s</count_f>',_sql_result1,cast(_sql_result2 as varchar));

  } else if (_action_id = 2){ -- empty folder
    SELECT NAME
      INTO _object_name
      FROM OMAIL.WA.FOLDERS
     where DOMAIN_ID = _domain_id and USER_ID = _user_id and FOLDER_ID = _object_id;

    SELECT COUNT(*)
      INTO _sql_result1
      FROM OMAIL.WA.MESSAGES
     where DOMAIN_ID = _domain_id and USER_ID = _user_id and FOLDER_ID = _object_id;

    SELECT COUNT(*)
      INTO _sql_result2
      FROM OMAIL.WA.FOLDERS
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
create procedure OMAIL.WA.omail_tstamp_to_mdate(in atime time)
{
  ----------------------------------------------------------
  -- Get mail format time GMT
  --      and return "DAY, DD MON YYYY HH:MI:SS {+,-}HHMM"
  ------------------------------------------------------------

  declare result,d,e,h,m,y,s,k,z,zh,zm,zz varchar;
  declare m_time TIME;
  declare daysofweek,months any;
  daysofweek := vector('01','SUN','02','Mon','03','Thu','04','Wed','05','Thu','06','Fri','07','Sat');
  months := vector('01','Jan','02','Feb','03','Mar','04','Apr','05','May','06','Jun','07','Jul','08','Aug','09','Sep','10','Oct','11','Nov','12','Dec');
  m_time := atime;

  d  := either(lt(cast(dayofmonth(m_time) as integer),10),sprintf('%d%d',0,dayofmonth(m_time)),cast(dayofmonth(m_time)as varchar));
  m  := either(lt(cast(month(m_time)      as integer),10),sprintf('%d%d',0,month(m_time)) ,cast(month(m_time)     as varchar));
  h  := either(lt(cast(hour(m_time)       as integer),10),sprintf('%d%d',0,hour(m_time)) ,cast(hour(m_time)      as varchar));
  e  := either(lt(cast(minute(m_time)     as integer),10),sprintf('%d%d',0,minute(m_time)) ,cast(minute(m_time)    as varchar));
  s  := either(lt(cast(second(m_time)     as integer),10),sprintf('%d%d',0,second (m_time)) ,cast(second(m_time)    as varchar));
  k  := either(lt(cast(dayofweek(m_time)  as integer),10),sprintf('%d%d',0,dayofweek(m_time)) ,cast(dayofweek(m_time) as varchar));
  y  := cast(year(m_time)as varchar);
  z  := timezone(m_time);
  if (z < 0) {zz := '-'; z := z-(2*z);} else{ zz := '+';};
  zh := either(lt(cast((z/60)    as integer),10),sprintf('%d%d',0,(z/60)) ,cast((z/60)   as varchar));
  zm := either(lt(cast(mod(z,60) as integer),10),sprintf('%d%d',0,mod(z,60)),cast(mod(z,60)as varchar));
  z  := sprintf('%s%s%s',zz,zh,zm);
  z  := cast(z as varchar);
  result := sprintf('%s, %s %s %s %s:%s:%s %s',get_keyword(k,daysofweek,''),d,get_keyword(m,months,''),y, h,e,s,z);

  RETURN result;
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
  SELECT COUNT(*)
    INTO _attached
    FROM OMAIL.WA.MSG_PARTS
   where DOMAIN_ID = _domain_id and USER_ID = _user_id and MSG_ID = _msg_id and PDEFAULT <> 1;

  UPDATE OMAIL.WA.MESSAGES
     SET ATTACHED = _attached
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
  SELECT length(MHEADER)
    INTO _dsize_h
    FROM OMAIL.WA.MESSAGES
   where DOMAIN_ID = _domain_id and USER_ID = _user_id and MSG_ID = _msg_id;

  SELECT SUM(DSIZE)
    INTO _dsize_b
    FROM OMAIL.WA.MSG_PARTS
   where DOMAIN_ID = _domain_id and USER_ID = _user_id and MSG_ID = _msg_id;

  UPDATE OMAIL.WA.MESSAGES
     SET DSIZE = (_dsize_h + _dsize_b)
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
  _page_params := vector (0,0,0,0,0,0,0,0,0,0,0,0,0,0);
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
  _scopy    := get_keyword('ch_scopy', params, get_keyword('save_copy', _settings, '1'));
  _html     := get_keyword('html', params, '1');
  _priority := get_keyword('priority', params, '');
  _body     := get_keyword('body', params, '');

  declare _data any;

  -- Set Arrays----------------------------------------------------------------------
  _pnames := 'msg_id,preview,re_mode,re_msg_id';
  _params := OMAIL.WA.omail_str2params(_pnames,get_keyword('wp',params,'0,0,0,0'),',');
  OMAIL.WA.omail_setparam('_html_parse',_params,0);

  -- SET SETTINGS --------------------------------------------------------------------
  if (_scopy <> get_keyword('save_copy',_settings, '1')) {
    OMAIL.WA.omail_setparam('save_copy', _settings, _scopy);
    OMAIL.WA.omail_setparam('update_flag', _settings, 1);
  }
  if (get_keyword('eparams',params,'') <> '')
    _eparams_url := get_keyword('eparams',params,'');

  -- Form Action---------------------------------------------------------------------
  if (_faction = 'send') {
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
  if (_faction = 'save') {
    -- > save new /update/  message into 'Draft'
    _msg_id := OMAIL.WA.omail_save_msg(_domain_id,_user_id,params,OMAIL.WA.omail_getp('msg_id',_params),_error);
    OMAIL.WA.omail_set_settings(_domain_id, _user_id, 'base_settings', _settings);
    if (_error = 0)
      OMAIL.WA.utl_redirect(sprintf('write.vsp?sid=%s&realm=%s&wp=%d%s',_sid,_realm,_msg_id,_eparams_url));
    else
      OMAIL.WA.utl_redirect(sprintf('err.vsp?sid=%s&realm=%s&err=%d',_sid,_realm,_error));
    return;
  }
  if (_faction = 'DAV') {
    -- > save new /update/ message and attached into 'Draft'
    _msg_id := OMAIL.WA.omail_save_msg(_domain_id,_user_id, params, OMAIL.WA.omail_getp('msg_id',_params), _error);
    OMAIL.WA.omail_set_settings(_domain_id, _user_id, 'base_settings', _settings);
    if (_error <> 0)
      goto _end;

    -- save attached
    declare N integer;
    declare fileName, fParams any;
    N := 1;
    while (1) {
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
  if (_faction = 'preview'){
    -- > 'HTML preview'
    _msg_id := OMAIL.WA.omail_save_msg(_domain_id,_user_id,params,OMAIL.WA.omail_getp('msg_id',_params),_error);
    OMAIL.WA.omail_set_settings(_domain_id, _user_id, 'base_settings', _settings);
    if (_error = 0)
      OMAIL.WA.utl_redirect(sprintf('write.vsp?sid=%s&realm=%s&wp=%d,%d',_sid,_realm,_msg_id,1));
    else
      OMAIL.WA.utl_redirect(sprintf('err.vsp?sid=%s&realm=%s&err=%d',_sid,_realm,_error));
    return;
  }
  if (_faction = 'attach'){
    -- > 'save new /update/  message into Draft and goto Attachment page'
    _msg_id := OMAIL.WA.omail_save_msg(_domain_id, _user_id, params, OMAIL.WA.omail_getp('msg_id',_params), _error);
    OMAIL.WA.omail_set_settings(_domain_id, _user_id, 'base_settings', _settings);
    if (_error = 0) {
      OMAIL.WA.utl_redirect(sprintf('attach.vsp?sid=%s&realm=%s&ap=%d%s',_sid,_realm,_msg_id,_eparams_url));
    } else {
      OMAIL.WA.utl_redirect(sprintf('err.vsp?sid=%s&realm=%s&err=%d',_sid,_realm,_error));
    }
    return;
  }

  -- SQL Statement-------------------------------------------------------------------
  if ((OMAIL.WA.omail_getp('msg_id',_params) <> 0) or (OMAIL.WA.omail_getp('re_mode',_params) <> 0)) {
    _sql_result1 := OMAIL.WA.omail_open_message(_domain_id,_user_id,_params, 1, 1);
    _sql_result2 := OMAIL.WA.omail_select_attachment(_domain_id,_user_id,OMAIL.WA.omail_getp('msg_id',_params),0);

  } else {
    if (_to <> '' or _cc <> '' or _bcc <> '' or _dcc <> '') {
      _sql_result1 := '<address><addres_list>\n';
      _sql_result1 := sprintf('%s<to><email><![CDATA[%s]]></email></to>\n',_sql_result1,_to);
      _sql_result1 := sprintf('%s<cc><email><![CDATA[%s]]></email></cc>\n',_sql_result1,_cc);
      _sql_result1 := sprintf('%s<bcc><email><![CDATA[%s]]></email></bcc>\n',_sql_result1,_bcc);
      _sql_result1 := sprintf('%s<dcc><email><![CDATA[%s]]></email></dcc>\n',_sql_result1,_dcc);
      _sql_result1 := sprintf('%s</addres_list></address>\n',_sql_result1);
    }
    if (_subject <> '')
      _sql_result1 := sprintf('%s<subject>%s</subject>\n',_sql_result1,_subject);

    if (_tags <> '')
      _sql_result1 := sprintf('%s<tags>%s</tags>\n',_sql_result1,_tags);

    if (_scopy = '1')
      OMAIL.WA.omail_setparam('save_copy', _settings, 1);

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
  aset (_page_params, 5, vector ('spam', get_keyword ('spam', _settings, '0')));
  aset (_page_params, 6, vector ('conversation', get_keyword ('conversation', _settings, '0')));
  aset (_page_params, 7, vector ('discussion', OMAIL.WA.discussion_check ()));

  -- If massage is saved, that we open the Draft folder in Folders tree
  if (OMAIL.WA.omail_getp('msg_id',_params) <> 0)
    aset (_page_params, 8, vector ('folder_id', 130));

  -- XML structure-------------------------------------------------------------------
  _rs := '';
  _rs := sprintf('%s%s\n',_rs,OMAIL.WA.omail_page_params(_page_params));
  _rs := sprintf('%s%s\n',_rs,either(OMAIL.WA.omail_getp('preview',_params),'<preview/>',''));
  _rs := sprintf('%s<msg_id>%d</msg_id>',_rs,OMAIL.WA.omail_getp('msg_id',_params));
  _rs := sprintf('%s<folder_view>%d</folder_view>',_rs,1);
  _rs := sprintf('%s<folders>%s</folders>',_rs,OMAIL.WA.omail_folders_list(_domain_id,_user_id,vector()));

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

  if (get_keyword('return', params, '') <> '') {
    -- Special mode

    if (strstr(get_keyword('return', params, ''), '.')) {
      -- Action: Return to URL

      for (_i := 0; _i < length(params); _i := _i + 2) {
        if (isstring(params[_i]) and substring(params[_i],1,2) = 'p_') {
          _name := substring(params[_i],3,length(params[_i]));
          _eparams := sprintf('%s&%s=%s',_eparams,_name,params[_i+1]);
        }
      }

      for (_i := 0; _i < length(params); _i := _i + 2) {
        if (isstring(params[_i]) and substring(params[_i],1,2) = 's_') {
          _name := substring(params[_i],3,length(params[_i]));
          _value := params[_i+1];
          if (_value = 'msg_id' and get_keyword('msg_id',_params,-1) <> -1) {
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

      for (_i := 0; _i < length(params); _i := _i + 2) {
        if (isstring(params[_i]) and substring(params[_i],1,2) = 'p_') {
          _name := substring(params[_i],3,length(params[_i]));
          _eparams := sprintf('%s<%s>%s</%s>', _eparams, _name, params[_i+1],_name);
        }
      }

      for (_i := 0; _i < length(params); _i := _i + 2) {
        if (isstring(params[_i]) and substring(params[_i],1,2) = 's_') {
          _name := substring(params[_i],3,length(params[_i]));
          _value := params[_i+1];

          if (_value = 'msg_id' and get_keyword('msg_id',_params,-1) <> -1) {
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
  for(SELECT WAM_INST
        FROM WA_MEMBER M,
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
Message-ID: <000801c43abf5992e4600100a8c0@leon>
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
  declare _rs, _sid, _realm, _set varchar;
  declare _page_params, _user_info any;

  _sid       := get_keyword ('sid', params, '');
  _realm     := get_keyword ('realm', params, '');
  _user_info := get_keyword ('user_info', params);
  _set       := get_keyword ('set', params, '');

  -- TEMP constants -------------------------------------------------------------------
  _user_id   := get_keyword ('user_id',_user_info);
  _domain_id := 1;

  -- Page Params---------------------------------------------------------------------
  _page_params := vector (0,0,0,0);
  aset (_page_params, 0, vector ('sid', _sid));
  aset (_page_params, 1, vector ('realm', _realm));
  aset (_page_params, 2, vector ('user_info', OMAIL.WA.array2xml(_user_info)));
  aset (_page_params, 3, vector ('set', _set));

  -- XML structure-------------------------------------------------------------------
  _rs := OMAIL.WA.omail_page_params(_page_params);
  _rs := sprintf ('%s<mails>', _rs);

  declare S, name varchar;
  declare st, msg, meta, rows any;

  S := 'sparql
        PREFIX foaf: <http://xmlns.com/foaf/0.1/>
        SELECT ?nick, ?firstName, ?family_name, ?mbox, ?mbox_sha1sum
        FROM <%s>
        WHERE
        {
          <%s> foaf:knows ?x.
          optional { ?x foaf:nick ?nick}.
          optional { ?x foaf:firstName ?firstName}.
          optional { ?x foaf:family_name ?family_name}.
          optional { ?x foaf:mbox ?mbox}.
          optional { ?x foaf:mbox_sha1sum ?mbox_sha1sum}.
        }';
	S := sprintf (S, SIOC..get_graph (), SIOC..user_iri (_user_id));
  st := '00000';
  exec (S, st, msg, vector (), 0, meta, rows);
  if ('00000' = st) {
    foreach (any row in rows) do {
      name := '';
      if (not isnull (row[0]))
        name := row[0];
      if ((not isnull (row[1])) and (not isnull (row[2])))
        name := row[1] || ' ' || row[2];
      if (not isnull (row[3]))
        _rs := sprintf ('%s<mail><name>%s</name><email>%s</email></mail>', _rs, name, OMAIL.WA.xml2string (OMAIL.WA.omail_composeAddr (name, row[3])));
      if (not isnull (row[4]))
        _rs := sprintf ('%s<mail><name>%s</name><email>%s</email></mail>', _rs, name, OMAIL.WA.xml2string (OMAIL.WA.omail_composeAddr (name, row[4])));
    }
  }
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

  if (exists(SELECT 1 FROM OMAIL.WA.SHARES where APP_ID = pApp_id and USER_ID = pUser_id and OBJ_ID = pObj_id and OBJ_TYPE = pObj_type and GRANTED_UID = pGranted_uid))
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

  if (isnull(pGranted_uid) and isnull(pObj_id)){
    -- delete all share rules
    delete from OMAIL.WA.SHARES where APP_ID = pApp_id and USER_ID = pUser_id;

    return 1;
  } else if (isnull(pObj_id)){
    -- delete all share rules for current GRANTED_UID
    delete from OMAIL.WA.SHARES where APP_ID = pApp_id and USER_ID = pUser_id and GRANTED_UID = pGranted_uid;

    return 2;

  } else if (isnull(pGranted_uid)){
    -- delete all share rules for current pObj_id
    delete from OMAIL.WA.SHARES
           where   APP_ID = pApp_id and USER_ID = pUser_id and OBJ_ID = pObj_id and OBJ_TYPE = pObj_type;

    return 3;

  } else {
    -- delete all share rules for current pObj_id and current GRANTED_UID
    delete from OMAIL.WA.SHARES
         where   APP_ID = pApp_id and USER_ID = pUser_id and OBJ_ID = pObj_id and OBJ_TYPE = pObj_type and GRANTED_UID = pGranted_uid;

    return 4;
  };
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
  if (exists(SELECT 1 FROM OMAIL.WA.SHARES  where   APP_ID = pApp_id and USER_ID = pUser_id and OBJ_ID = pObj_id and OBJ_TYPE = pObj_type and GRANTED_UID = pGranted_uid and G_TYPE = pG_type))
    return 1;

  -- check for all GRANTED_UID and current OBJ_ID);
  if (exists(SELECT 1 FROM OMAIL.WA.SHARES  where   APP_ID = pApp_id and USER_ID = pUser_id and OBJ_ID = pObj_id and OBJ_TYPE = pObj_type and GRANTED_UID IS NULL  and G_TYPE = pG_type))
    return 2;

  -- check for current GRANTED_UID and all OBJ_ID);
  if (exists(SELECT 1 FROM OMAIL.WA.SHARES  where   APP_ID = pApp_id and USER_ID = pUser_id and OBJ_ID IS NULL and OBJ_TYPE = pObj_type and GRANTED_UID = pGranted_uid and G_TYPE = pG_type))
    return 3;

  -- check for all GRANTED_UID and all OBJ_ID);
  if (exists(SELECT 1 FROM OMAIL.WA.SHARES  where   APP_ID = pApp_id and USER_ID = pUser_id and OBJ_ID IS NULL and OBJ_TYPE = pObj_type and GRANTED_UID IS NULL and G_TYPE = pG_type))
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
  sBody := sprintf('%s<to_snd_date>%s</to_snd_date>',sBody,OMAIL.WA.omail_tstamp_to_mdate(now()));
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
    signal('90002','Too deeeeep');

  declare ind integer;
  declare sRes, sNode, sValue varchar;

  sRes := '';
  ind  := 0;
  while(ind < length(pArray)) {
    if (isstring(aref(pArray, ind))) {
      sNode  := lower(cast(aref(pArray, ind) as varchar));

      if (isarray(aref(pArray,ind+1)) and not isstring(aref(pArray, ind+1))) {
        sValue := OMAIL.WA.omail_api_message_create_recu(aref(pArray, ind+1), iLevel+1);

      } else if (isnull(aref(pArray,ind+1))) {
        sValue := '';

      } else {
        sValue := cast(aref(pArray,ind+1) as varchar);
        sValue := sprintf('<![CDATA[%s]]>',sValue);
      }
      sRes := sprintf('%s<%s>%s</%s>\n', sRes, sNode, sValue, sNode);
    }
    ind := ind + 2;
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

  declare exit handler for SQLSTATE '*' {
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
      signal ('TEST', sprintf('''%s'' value should be greater then %s!<>', valueName, cast(tmp as varchar)));
    if (__SQL_STATE = 'MAX')
      signal ('TEST', sprintf('''%s'' value should be less then %s!<>', valueName, cast(tmp as varchar)));
    if (__SQL_STATE = 'MINLENGTH')
      signal ('TEST', sprintf('The length of field ''%s'' should be greater then %s characters!<>', valueName, cast(tmp as varchar)));
    if (__SQL_STATE = 'MAXLENGTH')
      signal ('TEST', sprintf('The length of field ''%s'' should be less then %s characters!<>', valueName, cast(tmp as varchar)));
    signal ('TEST', 'Unknown validation error!<>');
    --resignal;
  };

  value := trim(value);
  if (is_empty_or_null(params))
    return value;

  valueClass := coalesce(get_keyword('class', params), get_keyword('type', params));
  valueType := coalesce(get_keyword('type', params), get_keyword('class', params));
  valueName := get_keyword('name', params, 'Field');
  valueMessage := get_keyword('message', params, '');
  tmp := get_keyword('canEmpty', params);
  if (isnull(tmp)) {
    if (not isnull(get_keyword('minValue', params))) {
      tmp := 0;
    } else if (get_keyword('minLength', params, 0) <> 0) {
      tmp := 0;
    }
  }
  if (not isnull(tmp) and (tmp = 0) and is_empty_or_null(value)) {
    signal('EMPTY', '');
  } else if (is_empty_or_null(value)) {
    return value;
  }

  value := OMAIL.WA.validate2 (valueClass, value);

  if (valueType = 'integer') {
    tmp := get_keyword('minValue', params);
    if ((not isnull(tmp)) and (value < tmp))
      signal('MIN', cast(tmp as varchar));

    tmp := get_keyword('maxValue', params);
    if (not isnull(tmp) and (value > tmp))
      signal('MAX', cast(tmp as varchar));

  } else if (valueType = 'float') {
    tmp := get_keyword('minValue', params);
    if (not isnull(tmp) and (value < tmp))
      signal('MIN', cast(tmp as varchar));

    tmp := get_keyword('maxValue', params);
    if (not isnull(tmp) and (value > tmp))
      signal('MAX', cast(tmp as varchar));

  } else if (valueType = 'varchar') {
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
  declare exit handler for SQLSTATE '*' {
    if (__SQL_STATE = 'CLASS')
      resignal;
    signal('TYPE', propertyType);
    return;
  };

  if (propertyType = 'boolean') {
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
  while (w is not null) {
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
create procedure OMAIL.WA.vector_unique(
  inout aVector any,
  in minLength integer := 0)
{
  declare aResult any;
  declare N, M integer;

  aResult := vector();
  for (N := 0; N < length(aVector); N := N + 1) {
    if ((minLength = 0) or (length(aVector[N]) >= minLength)) {
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
  for (N := 0; N < length(aVector); N := N + 1) {
    tmp := trim(aVector[N]);
    if (strchr (tmp, ' ') is not null)
      tmp := concat('''', tmp, '''');
    if (N = 0) {
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
  while (w is not null) {
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
  if (not is_empty_or_null(tag)) {
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
  foreach (any new_tag in new_tags) do {
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

  resultTags := concat(tags, ',', tags2);
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
    if (N = 0) {
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
  for (N := 0; N < length(aVector); N := N + 1) {
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
  declare
    N integer;
  declare
    ch,
    S varchar;

  S := '';
  N := 1;
  while (N <= length(pFormat))
  {
    ch := substring(pFormat, N, 1);
    if (ch = 'M')
    {
      S := concat(S, xslt_format_number(month(pDate), '00'));
    } else {
      if (ch = 'm')
      {
        S := concat(S, xslt_format_number(month(pDate), '##'));
      } else
      {
        if (ch = 'Y')
        {
          S := concat(S, xslt_format_number(year(pDate), '0000'));
        } else
        {
          if (ch = 'y')
          {
            S := concat(S, substring(xslt_format_number(year(pDate), '0000'),3,2));
          } else {
            if (ch = 'd')
            {
              S := concat(S, xslt_format_number(dayofmonth(pDate), '##'));
            } else
            {
              if (ch = 'D')
              {
                S := concat(S, xslt_format_number(dayofmonth(pDate), '00'));
              } else
              {
                if (ch = 'H')
                {
                  S := concat(S, xslt_format_number(hour(pDate), '00'));
                } else
                {
                  if (ch = 'h')
                  {
                    S := concat(S, xslt_format_number(hour(pDate), '##'));
                  } else
                  {
                    if (ch = 'N')
                    {
                      S := concat(S, xslt_format_number(minute(pDate), '00'));
                    } else
                    {
                      if (ch = 'n')
                      {
                        S := concat(S, xslt_format_number(minute(pDate), '##'));
                      } else
                      {
                        if (ch = 'S')
                        {
                          S := concat(S, xslt_format_number(second(pDate), '00'));
                        } else
                        {
                          if (ch = 's')
                          {
                            S := concat(S, xslt_format_number(second(pDate), '##'));
                          } else
                          {
                            S := concat(S, ch);
                          };
                        };
                      };
                    };
                  };
                };
              };
            };
          };
        };
      };
    };
    N := N + 1;
  };
  return S;
}
;

-----------------------------------------------------------------------------------------
--
create procedure OMAIL.WA.dt_deformat(
  in pString varchar,
  in pFormat varchar := 'd.m.Y')
{
  declare
    y,
    m,
    d integer;
  declare
    N,
    I integer;
  declare
    ch varchar;

  I := 0;
  d := 0;
  m := 0;
  y := 0;
  for (N := 1; N <= length(pFormat); N := N + 1) {
    ch := upper(substring(pFormat, N, 1));
    if (ch = 'M')
      m := OMAIL.WA.dt_deformat_tmp(pString, I);
    if (ch = 'D')
      d := OMAIL.WA.dt_deformat_tmp(pString, I);
    if (ch = 'Y') {
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
  declare
    V any;

  V := regexp_parse('[0-9]+', S, N);
  if (length(V) > 1) {
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
  declare exit handler for sqlstate '*' { goto _next; };
  return stringdate(pString);
_next:
  declare exit handler for sqlstate '*' { goto _end; };
  return http_string_date(pString);

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

  insert soft OMAIL.WA.FOLDERS(DOMAIN_ID, USER_ID, FOLDER_ID, NAME) values (domain_id, user_id, 100, 'Inbox');

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
  if (oConversation = 1 and nConversation = 0) {

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
  if (pos is not NULL) {
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
  while (match is not null and inx > 0) {
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
  while (i1 < l1) {
    declare elm any;
    elm := trim(amime[i1]);
    if (mime1 like elm) {
      is_allowed := 1;
      i1 := l1;
    }
    i1 := i1 + 1;
  }

  declare _cnt_disp any;
  _cnt_disp := get_keyword_ucase('Content-Disposition', part, '');

  if (is_allowed and (any_part or (name1 <> '' and _cnt_disp in ('attachment', 'inline')))) {
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
  if (contentType like 'text/%') {
    declare st, en int;
    declare last any;

    st := tree[1][0];
    en := tree[1][1];

    if (en > st + 5) {
	    last := subseq (N_NM_BODY, en - 4, en);
  	  if (last = '\r\n.\r')
	      en := en - 4;
	  }
    content := subseq (N_NM_BODY, st, en);
    if (cset is not null and cset <> 'UTF-8')	{
	    declare exit handler for sqlstate '2C000' { goto next_1;};
	    content := charset_recode (content, cset, 'UTF-8');
	  }
  next_1:;
  } else if (contentType like 'multipart/%') {
    declare res, best_cnt any;

    declare exit handler for sqlstate '*' {	signal ('CONVX', __SQL_MESSAGE);};

    OMAIL.WA.nntp_process_parts (tree, N_NM_BODY, vector ('text/%'), res, 1);

    best_cnt := null;
    content := null;
    foreach (any elm in res) do {
	    if (elm[1] = 'text/html' and (content is null or best_cnt = 'text/plain')) {
	      best_cnt := 'text/html';
	      content := elm[2];
	      if (elm[4] = 'quoted-printable') {
		      content := uudecode (content, 12);
		    } else if (elm[4] = 'base64') {
		      content := decode_base64 (content);
		    }
		    cset := elm[5];
	    } else if (best_cnt is null and elm[1] = 'text/plain') {
	      content := elm[2];
	      best_cnt := 'text/plain';
	      cset := elm[5];
	    }
  	  if (elm[1] not like 'text/%')
	      signal ('CONVX', sprintf ('The post contains parts of type [%s] which is prohibited.', elm[1]));
	  }
    if (length (cset) and cset <> 'UTF-8') {
	    declare exit handler for sqlstate '2C000' { goto next_2;};
	    content := charset_recode (content, cset, 'UTF-8');
	  }
  next_2:;
  } else
    signal ('CONVX', sprintf ('The content type [%s] is not supported', contentType));

  if (not isnull (N_NM_REF)) {
    --declare exit handler for sqlstate '*' { return dbg_obj_print(__SQL_MESSAGE);};

    refs := split_and_decode (N_NM_REF, 0, '\0\0 ');
    if (length (refs)) {
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
      _msg_id := 0;
      _msg_id := OMAIL.WA.omail_save_msg (_domain_id, _user_id, _params, _msg_id, _error);
      _request := sprintf('http://' || DB.DBA.http_get_host () || '/oMail/res/flush.vsp?did=%s&uid=%s&mid=%s&addr=%U', cast(_domain_id as varchar), cast(_user_id as varchar), cast(_msg_id as varchar), _address);
      http_get (_request, _respond);
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
    for (select DOMAIN_ID as _domain_id, USER_ID as _user_id from OMAIL.WA.FOLDERS where FOLDER_ID = 100) do
     insert soft OMAIL.WA.FOLDERS(DOMAIN_ID, USER_ID, FOLDER_ID, NAME) values (_domain_id, _user_id, 125, 'Spam');
}
;

OMAIL.WA.spam_update ()
;
registry_set ('_oMail_spam_', '1')
;

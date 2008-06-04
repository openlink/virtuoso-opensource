
--!
--! ODS API for accessing & data manipulation
--! All requests are authorized via one of :
--! 1) HTTP authentication (not yet supported)
--! 2) OAuth
--! 3) VSPX session (sid & realm)
--! 4) username=<user>&password=<pass>
--! The effective user is authenticated account
--!
--! Important:
--! Any API method MUST follow namin convention as follows
--! methods : ods.<object type>.<action>
--! parameters : <lower_case>
--! composite patameters: atom-pub, OpenSocial XML format
--! response : GData format , i.e. Atom extension
--
-- Note: some of methods bellow uses ods_api.sql code


use ODS;

-- User account activity

--! User registration
--! name: desired user account name
--! password: desired password
--! email: user's e-mail address
create procedure ODS.ODS_API."user.register" (
    	in name varchar,
	in "password" varchar,
	in "email" varchar
	) __soap_http 'text/xml'
{
  declare ret any;
  declare msg varchar;

  declare exit handler for sqlstate '*' {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  ret := DB.DBA.ODS_CREATE_USER (name, "password", "email");
  if (isinteger (ret))
    msg := 'Created';
  else
    {
      msg := ret;
      ret := -1;
    }
  return ods_serialize_int_res (ret);
}
;

create procedure ods_serialize_int_res (in rc any, in msg varchar := '')
{
  if (isarray (rc) and length (rc) = 2 and __tag (rc[0]) = 255)
    rc := rc[1];
  rc := cast (rc as int);
  if (msg = '')
    {
      if (rc < 0)
        msg := DB.DBA.DAV_PERROR (rc);
      else
	msg := 'Success';
    }
  if (rc >= 0)
    return sprintf ('<result><code>%d</code><message>%V</message></result>', rc, msg);
  else
    return sprintf ('<failed><code>%d</code><message>%V</message></failed>', rc, msg);
}
;

create procedure ods_serialize_sql_error (in state varchar, in message varchar)
{
  return sprintf ('<failed><code>%s</code><message>%V</message></failed>', state, message);
}
;

--! Performs HTTP, OAuth, session based authentication in same order
create procedure ods_check_auth (out uname varchar, in inst_id int := null, in mode char := 'owner')
{
  declare rc int;
  declare params, lines any;

  params := http_param ();
  lines := http_request_header ();
  rc := 0;

  whenever not found goto nf;

  -- check authentication
  if (OAUTH..check_authentication_safe (params, lines, uname, inst_id))
    rc := 1;
  else if (http_request_header (lines, 'Authentication', null, null) is not null) -- not supported
    {
      ;
    }
  else if (get_keyword ('sid', params) is not null and get_keyword ('realm', params) is not null)
    {
      select VS_UID into uname from DB.DBA.VSPX_SESSION where VS_SID = get_keyword ('sid', params) and VS_REALM = get_keyword ('realm', params);
      rc := 1;
    }
  else if (get_keyword ('user_name', params) is not null and get_keyword ('password_hash', params) is not null)
    {
      declare pwd any;
      uname := get_keyword ('user_name', params);
      select pwd_magic_calc (U_NAME, U_PASSWORD, 1) into pwd from DB.DBA.SYS_USERS where U_NAME = uname;
      if (_hex_sha1_digest (uname||pwd) = get_keyword ('password_hash', params))
	rc := 1;
    }
  -- check ACL
  if (inst_id > 0 and rc > 0)
    {
      declare member_type int;
      if (mode = 'owner')
	member_type := 1;
      else
       {
	 member_type := (select WMT_ID from DB.DBA.WA_MEMBER_TYPE, DB.DBA.WA_INSTANCE where
	   WAI_ID = inst_id and WMT_NAME = mode and WMT_APP = WAI_TYPE_NAME);
       }
      if (not exists (select 1 from DB.DBA.WA_MEMBER, DB.DBA.SYS_USERS
	    where WAM_USER = U_ID and U_NAME = uname and WAM_MEMBER_TYPE <= member_type))
	rc := 0;
    }
nf:
  return rc;
}
;

create procedure get_ses (in uname varchar)
{
  declare params, lines any;
  declare sid any;

  params := http_param ();
  lines := http_request_header ();

  sid := get_keyword ('sid', params);
  --if (sid is null)
  --  sid := OAUTH.DBA.get_sid (params, lines);
  if (sid is null)
    {
      sid := DB.DBA.vspx_sid_generate ();
      insert into DB.DBA.VSPX_SESSION (VS_SID, VS_REALM, VS_UID, VS_EXPIRY) values (sid, 'wa', uname, now ());
    }
  return sid;
}
;

create procedure close_ses (in sid1 varchar)
{
  declare params, lines any;
  declare sid any;

  params := http_param ();
  lines := http_request_header ();

  sid := get_keyword ('sid', params);
  if (sid is null)
    sid := OAUTH.DBA.get_sid (params, lines);
  if (sid is null)
    {
      delete from DB.DBA.VSPX_SESSION where VS_SID = sid1 and  VS_REALM = 'wa';
    }
}
;

create procedure exec_sparql (in qr varchar)
{
  declare ses, stat, msg, metas, rset any;
  declare accept, fmt varchar;

  accept := 'application/sparql-results+xml';

  set http_charset='utf-8';
  declare exit handler for sqlstate '*'
    {
      stat := __SQL_STATE;
      msg := __SQL_MESSAGE;
      goto reporterr;
    };

  set_user_id ('SPARQL');
  stat := '00000';
  qr := 'SPARQL define output:valmode "LONG" ' ||
  ' define input:inference "' || sioc..get_graph() || '"' ||
  sioc..std_pref_declare () || qr;
  dbg_printf ('%s', qr);
  exec (qr, stat, msg, vector (), 0, metas, rset);
  if (stat <> '00000')
    {
reporterr:
      http (ods_serialize_int_res (-500, msg));
      return;
    }
  ses := string_output ();
  DB.DBA.SPARQL_RESULTS_WRITE (ses, metas, rset, accept, 0);
  http_header ('Content-Type: application/sparql-results+xml\r\n');
  http (ses);
}
;
create procedure ods_auth_failed ()
{
  return '<failed>Authentication failed</failed>';
}
;

--! Authenticate ODS account using name & password hash
--! Will estabilish a session in VSPX_SESSION table
create procedure ODS.ODS_API."user.authenticate" (
    	in user_name varchar,
	in password_hash varchar
	) __soap_http 'text/plain'
{
  declare uname varchar;
  declare sid varchar;
  declare exit handler for sqlstate '*' {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  if (not ods_check_auth (uname))
    return ods_auth_failed ();
  sid := DB.DBA.vspx_sid_generate ();
  insert into DB.DBA.VSPX_SESSION (VS_SID, VS_REALM, VS_UID, VS_EXPIRY) values (sid, 'wa', uname, now ());
  return sid;
}
;


create procedure ODS.ODS_API."user.update" (
	in user_info any
	) __soap_http 'text/xml'
{
  declare uname varchar;
  declare rc int;
  declare pars any;

  declare exit handler for sqlstate '*' {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  if (not ods_check_auth (uname))
    return ods_auth_failed ();
  pars := split_and_decode (user_info, 0, '%\0,='); -- XXX: FIXME


  for (declare i, l int, i := 0, l := length (pars); i < l; i := i + 2)
    {
      declare k, v any;
      k := pars[i];
      v := pars [i + 1];
      k := upper (k);
      if (k <> 'E_MAIL')
        k := 'WAUI_' || k;
      DB.DBA.WA_USER_EDIT (uname, k, v);
      rc := 1;
    }
  return ods_serialize_int_res (rc, 'Profile was updated');
}
;

create procedure ODS.ODS_API."user.password_change" (
	in new_password varchar
	) __soap_http 'text/xml'
{
  declare uname, msg varchar;
  declare rc int;

  declare exit handler for sqlstate '*' {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  if (not ods_check_auth (uname))
    return ods_auth_failed ();
  declare exit handler for sqlstate '*' { msg := __SQL_MESSAGE; goto ret; };
  rc := -1;
  msg := 'Success';
  set_user_id ('dba');
  DB.DBA.USER_PASSWORD_SET (uname, new_password);
  rc := 1;
  ret:
  return ods_serialize_int_res (rc, msg);
}
;

-- ODS admin privilege
create procedure ODS.ODS_API."user.delete" (in name varchar) __soap_http 'text/xml'
{
  declare uname varchar;
  declare rc int;

  declare exit handler for sqlstate '*' {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  if (not ods_check_auth (uname))
    return ods_auth_failed ();
  if (uname in ('dav', 'dba'))
    {
      delete from DB.DBA.SYS_USERS where U_NAME = name;
      rc := row_count ();
    }
  else
    rc := -13;
  return ods_serialize_int_res (rc);
}
;

-- ODS admin privilege
create procedure ODS.ODS_API."user.freeze" (in name varchar) __soap_http 'text/xml'
{
  declare uname varchar;
  declare rc int;

  declare exit handler for sqlstate '*' {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  if (not ods_check_auth (uname))
    return ods_auth_failed ();
  if (uname in ('dav', 'dba'))
    {
      DB.DBA.USER_SET_OPTION (name, 'DISABLED', 1);
      rc := 1;
    }
  else
    rc := -13;
  return ods_serialize_int_res (rc);
}
;

create procedure ODS.ODS_API."user.get" (in name varchar) __soap_http 'text/xml'
{
  declare q varchar;
  declare exit handler for sqlstate '*' {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  q := sprintf (
  'select * from <%s> where '||
  ' { ?user a sioc:User ; sioc:id "%s" ; ?property ?value } ',
  sioc..get_graph(), name);
  exec_sparql (q);
  return '';
}
;

create procedure ODS.ODS_API."user.search" (in pattern varchar) __soap_http 'text/xml'
{
  declare q varchar;
  declare exit handler for sqlstate '*' {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  q := sprintf (
  'select * from <%s> where '||
  ' { ?user a sioc:User ; ?property ?value . ?value bif:contains "%s" } ',
  sioc..get_graph(), pattern);
  exec_sparql (q);
  return '';
}
;

-- Social Network activity

create procedure ODS.ODS_API."user.invite" (in friends_email varchar, in custom_message varchar := '') __soap_http 'text/xml'
{
  declare uname varchar;
  declare rc int;
  declare i, uids, sn_id, msg, url any;
  declare copy varchar;
  declare _u_full_name, _u_e_mail varchar;
  declare msg varchar;

  declare exit handler for sqlstate '*' {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  if (not ods_check_auth (uname))
    return ods_auth_failed ();

  url := WS.WS.EXPAND_URL (HTTP_URL_HANDLER (), 'login.vspx?URL=sn_rec_inv.vspx');
  copy := (select top 1 WS_WEB_TITLE from DB.DBA.WA_SETTINGS);
  if (copy = '' or copy is null)
    copy := sys_stat ('st_host_name');

  whenever not found goto ret;
  msg := '';
  select U_FULL_NAME, U_E_MAIL into _u_full_name, _u_e_mail from DB.DBA.SYS_USERS where U_NAME = uname;
  sn_id := (select sne_id from DB.DBA.sn_person where sne_name = uname);
  msg := DB.DBA.WA_GET_EMAIL_TEMPLATE ('SN_INV_TEMPLATE', 1);
  msg := replace (msg, '%app%', copy);
  msg := replace (msg, '%invitation%', custom_message);
  msg := replace (msg, '%user%', DB.DBA.WA_WIDE_TO_UTF8 (_u_full_name));
  msg := replace (msg, '%url%', url);

  uids := split_and_decode (friends_email, 0, '\0\0,');

  if (not length (uids))
    {
      rc := -1;
      msg := 'Please enter at least one mail address';
      goto ret;
    }

  i := 0;

  foreach (any mail in uids) do
    {
      mail := trim (mail);
      msg := replace (msg, '%name%', mail);
      msg := replace (msg, '%url%', url);

      insert soft DB.DBA.sn_invitation (sni_from, sni_to, sni_status) values (sn_id, mail, 0);
      rc := rc + row_count();

      if (row_count () > 0)
	{
	  declare exit handler for sqlstate '*'
	    {
	      rollback work;
	      if (__SQL_STATE not like 'WA%')
		msg := 'The e-mail address(es) is not valid and mail cannot be sent.';
	      else
		msg := __SQL_MESSAGE;
              rc := -1;
              goto ret;
	    };
	  DB.DBA.WA_SEND_MAIL (_u_e_mail, mail, 'Join my network', msg);
	  commit work;
	  i := i + 1;
	}
    }

  if (i <> length (uids))
    {
      msg := 'Some of the e-mail addresses entered already have a pending invitation, the mail was not sent to he/she.';
    }
ret:
  return ods_serialize_int_res (rc, msg);
}
;

create procedure ODS.ODS_API."user.invitation" (in invitation_id int, in approve smallint) __soap_http 'text/xml'
{
  declare uname varchar;
  declare rc int;
  declare sn_me, sn_from int;
  declare e_mail varchar;
  declare msg varchar;

  declare exit handler for sqlstate '*' {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  if (not ods_check_auth (uname))
    return ods_auth_failed ();

  whenever not found goto ret;
  msg := 'No pending invitations';
  rc := -1;
  select U_E_MAIL into e_mail from DB.DBA.SYS_USERS where U_NAME = uname;
  select sni_from into sn_from from DB.DBA.sn_invitation where sni_id = invitation_id and sni_to = e_mail;
  sn_me := (select sne_id from DB.DBA.sn_person where sne_name = uname);

  if (approve)
    {
      insert soft DB.DBA.sn_related (snr_from, snr_to, snr_since, snr_serial, snr_source)
	  values (sn_from, sn_me, now (), 0, 1);
      delete from DB.DBA.sn_invitation where sni_id = invitation_id and sni_to = e_mail;
    }
  else
    {
      update DB.DBA.sn_invitation set sni_status = -1 where sni_id = invitation_id and sni_to = e_mail;
    }
  msg := '';
  rc := 1;
ret:
  return ods_serialize_int_res (rc);
}
;

create procedure ODS.ODS_API."user.invitations.get" () __soap_http 'text/xml'
{
  declare uname varchar;
  declare rc int;
  declare sn_me, sn_from int;
  declare e_mail varchar;

  declare exit handler for sqlstate '*' {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  if (not ods_check_auth (uname))
    return ods_auth_failed ();

  -- XXX: add sparql_exec after RDF data update triggers is done
ret:
  return ods_serialize_int_res (rc);
}
;

create procedure ODS.ODS_API."user.relation_terminate" (in friend varchar) __soap_http 'text/xml'
{
  declare uname varchar;
  declare rc, sn_id, f_sn_id int;

  declare exit handler for sqlstate '*' {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  if (not ods_check_auth (uname))
    return ods_auth_failed ();
  sn_id := (select sne_id from DB.DBA.sn_person where sne_name = uname);
  f_sn_id := (select sne_id from DB.DBA.sn_person where sne_name = friend);
  delete from DB.DBA.sn_related where (snr_from = f_sn_id and snr_to = sn_id) or (snr_to = f_sn_id and snr_from = sn_id);
  rc := row_count ();
  return ods_serialize_int_res (rc);
}
;

create procedure ODS.ODS_API."user.relation_update" (in friend varchar, in relation_details any) __soap_http 'text/xml'
{
  return;
}
;

-- User Settings

-- Tagging Rules
create procedure ODS.ODS_API."user.tagging_rules.add" (in rulelist_name varchar, in rules any, in is_public int := 1) __soap_http 'text/xml'
{
  declare uname varchar;
  declare rc int;
  declare aps_id, apc_id, id, _u_id, ord int;
  declare msg varchar;

  declare exit handler for sqlstate '*' {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  if (not ods_check_auth (uname))
    return ods_auth_failed ();

  msg := '';
  rc := -1;
  rulelist_name := trim (rulelist_name);
  if (length (rulelist_name) = 0)
    {
      msg := 'The ruleset name cannot be empty';
      goto ret;
    }

  aps_id := ANN_GETID ('S');
  apc_id := coalesce ((select top 1 APC_ID from DB.DBA.SYS_ANN_PHRASE_CLASS where APC_OWNER_UID = _u_id), ANN_GETID ('C'));
  _u_id := (select U_ID from DB.DBA.SYS_USERS where U_NAME = uname);

  declare exit handler for sqlstate '23000'
    {
      rollback work;
      msg := 'The ruleset name is already used, please enter unique rule name';
      rc := -1;
      goto ret;
    };

  insert into DB.DBA.tag_rule_set (trs_name, trs_owner, trs_is_public, trs_apc_id, trs_aps_id)
      values (rulelist_name, _u_id, is_public, apc_id, aps_id);
  id := identity_value ();
  rc := id;
  ord := coalesce ((select top 1 tu_order from DB.DBA.tag_user where tu_u_id = _u_id order by tu_order desc), 0);
  ord := ord + 1;
  insert into DB.DBA.tag_user (tu_u_id, tu_trs, tu_order) values (_u_id, id, ord);
  delete from DB.DBA.tag_rules where rs_trs = id;

  delete from DB.DBA.tag_content_tc_text_query where tt_tag_set = id;
  delete from DB.DBA.SYS_ANN_PHRASE where AP_APS_ID = aps_id;

  insert soft DB.DBA.SYS_ANN_PHRASE_CLASS (APC_ID, APC_NAME, APC_OWNER_UID, APC_READER_GID, APC_CALLBACK, APC_APP_ENV)
      values (apc_id, uname || '\'s Tagging Rule Class', _u_id, http_nogroup_gid (), null, null);

  insert soft DB.DBA.SYS_ANN_PHRASE_SET (APS_ID, APS_NAME, APS_OWNER_UID, APS_READER_GID,
				APS_APC_ID, APS_LANG_NAME, APS_APP_ENV, APS_SIZE, APS_LOAD_AT_BOOT)
      values (aps_id, uname || '\'s ' || rulelist_name, _u_id, http_nogroup_gid (), apc_id, 'x-any', null, 10000, 1);

  foreach (any r in rules) do
    {
      insert into DB.DBA.tag_rules (rs_trs, rs_query, rs_tag, rs_is_phrase)
	  values (id, r[0], r[1], r[2]);
      if (r[2] = 1)
	{
	  ap_add_phrases (aps_id, vector ( vector (r[0], r[1]) ));
	}
      else
	{
	  DB.DBA.tt_query_tag_content (r[0], _u_id, '', '', serialize (vector (id, r[1], r[2])));
	}
    }
ret:
  return ods_serialize_int_res (rc, msg);
}
;

create procedure ODS.ODS_API."user.tagging_rules.delete" (in rulelist_name varchar) __soap_http 'text/xml'
{
  declare uname varchar;
  declare rc int;
  declare _aps_id, _apc_id, id, _u_id int;
  declare msg varchar;

  declare exit handler for sqlstate '*' {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  if (not ods_check_auth (uname))
    return ods_auth_failed ();

  msg := '';
  rc := -1;
  rulelist_name := trim (rulelist_name);
  if (length (rulelist_name) = 0)
    {
      msg := 'The ruleset name cannot be empty';
      goto ret;
    }

  _u_id := (select U_ID from DB.DBA.SYS_USERS where U_NAME = uname);

  declare exit handler for sqlstate '23000'
    {
      rollback work;
      msg := 'The ruleset name is already used, please enter unique rule name';
      rc := -1;
      goto ret;
    };

  select trs_id, trs_apc_id, trs_aps_id into id, _apc_id, _aps_id from DB.DBA.tag_rule_set
      where trs_owner = _u_id and trs_name = rulelist_name;

  delete from DB.DBA.tag_rules where rs_trs = id;
  delete from DB.DBA.tag_content_tc_text_query where tt_tag_set = id;
  delete from DB.DBA.tag_rule_set where trs_owner = _u_id and trs_name = rulelist_name;
  delete from DB.DBA.SYS_ANN_PHRASE where AP_APS_ID = _aps_id;
  delete from DB.DBA.SYS_ANN_PHRASE_CLASS  where APC_ID = _apc_id and APC_OWNER_UID = _u_id;
  delete from DB.DBA.SYS_ANN_PHRASE_SET where APS_ID = _aps_id and APS_OWNER_UID = _u_id;
  rc := row_count ();
ret:
  return ods_serialize_int_res (rc, msg);
}
;

create procedure ODS.ODS_API."user.tagging_rules.update" (in rulelist_name varchar, in rules any) __soap_http 'text/xml'
{
  declare uname varchar;
  declare rc int;
  declare aps_id, apc_id, id, _u_id int;
  declare msg varchar;

  declare exit handler for sqlstate '*' {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  if (not ods_check_auth (uname))
    return ods_auth_failed ();

  rulelist_name := trim (rulelist_name);
  msg := '';
  rc := -1;
  if (length (rulelist_name) = 0)
    {
      msg := 'The ruleset name cannot be empty';
      goto ret;
    }

  _u_id := (select U_ID from DB.DBA.SYS_USERS where U_NAME = uname);

  declare exit handler for sqlstate '23000'
    {
      rollback work;
      msg := 'The ruleset name is already used, please enter unique rule name';
      rc := -1;
      goto ret;
    };

  select trs_id, trs_apc_id, trs_aps_id into id, apc_id, aps_id from DB.DBA.tag_rule_set
      where trs_owner = _u_id and trs_name = rulelist_name;

  rc := id;

  delete from DB.DBA.tag_rules where rs_trs = id;
  delete from DB.DBA.tag_content_tc_text_query where tt_tag_set = id;
  delete from DB.DBA.SYS_ANN_PHRASE where AP_APS_ID = aps_id;

  foreach (any r in rules) do
    {
      insert into DB.DBA.tag_rules (rs_trs, rs_query, rs_tag, rs_is_phrase)
	  values (id, r[0], r[1], r[2]);
      if (r[2] = 1)
	{
	  ap_add_phrases (aps_id, vector ( vector (r[0], r[1]) ));
	}
      else
	{
	  DB.DBA.tt_query_tag_content (r[0], _u_id, '', '', serialize (vector (id, r[1], r[2])));
	}
    }
ret:
  return ods_serialize_int_res (rc, msg);
}
;


-- Hyperlinking Rules
create procedure ODS.ODS_API."user.hyperlinking_rules.add" (in rules any) __soap_http 'text/xml'
{
  declare uname varchar;
  declare rc int;
  declare aps_id, apc_id, id, _u_id int;
  declare ap_name varchar;
  declare msg varchar;

  declare exit handler for sqlstate '*' {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  if (not ods_check_auth (uname))
    return ods_auth_failed ();

  msg := '';
  rc := -1;
  _u_id := (select U_ID from DB.DBA.SYS_USERS where U_NAME = uname);
  ap_name := sprintf ('Hyperlinking-%d', _u_id);
  aps_id := (select APS_ID from DB.DBA.SYS_ANN_PHRASE_SET where APS_OWNER_UID = _u_id and APS_NAME = ap_name);
  if (aps_id is null)
    {
      declare c_id, s_id int;
      c_id := ANN_GETID ('C');
      s_id := ANN_GETID ('S');
      DB.DBA.ANN_PHRASE_CLASS_ADD_INT (c_id, ap_name, _u_id, http_nogroup_gid (), null, null);
      DB.DBA.ANN_PHRASE_SET_ADD_INT (s_id, ap_name, _u_id, http_nogroup_gid (), c_id, 'x-any', null, 100000, 1);
      aps_id := s_id;
    }
  foreach (any elm in rules) do
    {
      ap_add_phrases (aps_id, vector (vector (elm[0], elm[1])));
    }
  rc := 1;
  return ods_serialize_int_res (rc, msg);
}
;

create procedure ODS.ODS_API."user.hyperlinking_rules.update" (in rules any) __soap_http 'text/xml'
{
  return;
}
;

create procedure ODS.ODS_API."user.hyperlinking_rules.delete" (in rules any) __soap_http 'text/xml'
{
  declare uname varchar;
  declare rc int;
  declare aps_id, apc_id, id, _u_id int;
  declare ap_name varchar;

  declare exit handler for sqlstate '*' {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  if (not ods_check_auth (uname))
    return ods_auth_failed ();

  _u_id := (select U_ID from DB.DBA.SYS_USERS where U_NAME = uname);
  ap_name := sprintf ('Hyperlinking-%d', _u_id);
  aps_id := (select APS_ID from DB.DBA.SYS_ANN_PHRASE_SET where APS_OWNER_UID = _u_id and APS_NAME = ap_name);
  foreach (any elm in rules) do
    {
      delete from DB.DBA.SYS_ANN_PHRASE where AP_APS_ID = aps_id and AP_TEXT = elm[0] and AP_CHKSUM = elm[1];
    }
  rc := 1;
  return ods_serialize_int_res (rc);
}
;



-- Application instance activity

create procedure ODS.ODS_API."instance.create" (
	in "type" varchar,
    	in name varchar,
	in description varchar,
	in model int,
	in "public" int
	) __soap_http 'text/xml'
{
  declare uname varchar;
  declare rc int;
  declare msg varchar;

  declare exit handler for sqlstate '*' {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  if (not ods_check_auth (uname))
    return ods_auth_failed ();

  msg := '';
  rc := DB.DBA.ODS_CREATE_NEW_APP_INST ("type", name, uname, model, "public", description);
  if (not isinteger (rc))
    {
      msg := rc;
      rc := -1;
    }
  return ods_serialize_int_res (rc);
}
;


create procedure ODS.ODS_API."instance.update" (
	in inst_id int,
    	in name varchar,
	in description varchar,
	in model int,
	in "public" int
	) __soap_http 'text/xml'
{
  declare uname varchar;
  declare rc int;
  declare dummy int;
  declare msg varchar;

  declare exit handler for sqlstate '*' {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  if (not ods_check_auth (uname, inst_id))
    return ods_auth_failed ();

  whenever not found goto ret;
  msg := 'No such instance';
  rc := -1;
  select WAI_ID into dummy from DB.DBA.WA_INSTANCE, DB.DBA.WA_MEMBER, DB.DBA.SYS_USERS
      where WAI_NAME = WAM_INST and WAM_MEMBER_TYPE = 1 and WAM_USER = U_ID and U_NAME = uname and WAI_ID = inst_id;

  update DB.DBA.WA_INSTANCE set WAI_NAME = name, WAI_DESCRIPTION = description, WAI_MEMBER_MODEL = model,
	 WAI_IS_PUBLIC = "public" where WAI_ID = inst_id;
  rc := row_count ();
  msg := '';
ret:
  return ods_serialize_int_res (rc);
}
;

create procedure ODS.ODS_API."instance.delete" (in inst_id int) __soap_http 'text/xml'
{
  declare uname varchar;
  declare rc int;
  declare inst any;
  declare h any;
  declare msg varchar;

  declare exit handler for sqlstate '*' {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  if (not ods_check_auth (uname, inst_id))
    return ods_auth_failed ();

  whenever not found goto ret;
  msg := 'No such instance';
  rc := -1;
  select WAI_INST into inst from DB.DBA.WA_INSTANCE, DB.DBA.WA_MEMBER, DB.DBA.SYS_USERS
      where WAI_NAME = WAM_INST and WAM_MEMBER_TYPE = 1 and WAM_USER = U_ID and U_NAME = uname and WAI_ID = inst_id;

  h := udt_implements_method (inst, 'wa_drop_instance');
  declare exit handler for sqlstate '*' {
                                            msg := __SQL_MESSAGE;
					    rc := -1;
                                            rollback work;
                                            goto ret;
                                        };
  commit work;
  rc := call (h) (inst);
  msg := '';
  rc := 1;
ret:
  return ods_serialize_int_res (rc);
}
;

create procedure ODS.ODS_API."instance.join" (in inst_id int) __soap_http 'text/xml'
{
  declare _wai_name, acc_type, app_type any;
  declare uname varchar;
  declare rc int;
  declare _u_id, _result any;
  declare msg varchar;

  declare exit handler for sqlstate '*' {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  if (not ods_check_auth (uname))
    return ods_auth_failed ();

  msg := '';
  rc := -1;
  declare exit handler for sqlstate '*', not found
    {
      msg := __SQL_MESSAGE;
      rc := -1;
      rollback work;
      goto ret;
    };

  select U_ID into _u_id from DB.DBA.SYS_USERS where U_NAME = uname;
  select WAI_NAME, WAI_TYPE_NAME into _wai_name, app_type from DB.DBA.WA_INSTANCE where WAI_ID = inst_id;
  acc_type := (select max(WMT_ID) from DB.DBA.WA_MEMBER_TYPE where WMT_APP = app_type);

  insert into DB.DBA.WA_MEMBER (WAM_USER, WAM_INST, WAM_MEMBER_TYPE, WAM_STATUS)
      values (_u_id, _wai_name, acc_type, 3);
  _result := connection_get('join_result');
  rc := 1;
  if (_result = 'approved')
    msg := 'Your join request approved.';
  else if (_result = 'ownerwait')
    {
      msg := 'Application owner notified about your join request. You will get e-mail message after approval.';
      rc := 0;
    }
ret:
  return ods_serialize_int_res (rc, msg);
}
;

create procedure ODS.ODS_API."instance.disjoin" (in inst_id int) __soap_http 'text/xml'
{
  declare uname varchar;
  declare rc int;

  declare exit handler for sqlstate '*' {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  if (not ods_check_auth (uname))
    return ods_auth_failed ();
  delete from DB.DBA.WA_MEMBER where
      WAM_INST = (select WAI_NAME from DB.DBA.WA_INSTANCE where WAI_ID = inst_id)
      and
      WAM_USER = (select U_ID from DB.DBA.SYS_USERS where U_NAME = uname);
  rc := row_count ();
  return ods_serialize_int_res (rc);
}
;

create procedure ODS.ODS_API."instance.join_approve" (in inst_id int, in uname varchar) __soap_http 'text/xml'
{
  return;
}
;

create procedure ODS.ODS_API."notification.services" () __soap_http 'text/xml'
{
  declare q varchar;
  declare exit handler for sqlstate '*' {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  q := sprintf (
  'select * from <%s> where '||
  ' { <%s> sioc:has_service ?svc . ?svc dc:identifier ?id ; rdfs:label ?label  } ',
  sioc..get_graph(), sioc..get_graph());
  exec_sparql (q);
  return '';
}
;

create procedure ODS.ODS_API."instance.notification.services" (in inst_id int) __soap_http 'text/xml'
{
  declare uname varchar;
  declare rc, dummy int;

  declare exit handler for sqlstate '*' {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  if (not ods_check_auth (uname, inst_id))
    return ods_auth_failed ();
ret:
  return '';
}
;


create procedure ODS.ODS_API."instance.notification.set" (in inst_id int, in services any) __soap_http 'text/xml'
{
  declare uname varchar;
  declare rc, dummy int;

  declare exit handler for sqlstate '*' {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  if (not ods_check_auth (uname, inst_id))
    return ods_auth_failed ();

  whenever not found goto ret;
  rc := 'No enough permissions, must be instance owner';
  select WAI_ID into dummy from DB.DBA.WA_INSTANCE, DB.DBA.WA_MEMBER, DB.DBA.SYS_USERS
      where WAI_NAME = WAM_INST and WAM_MEMBER_TYPE = 1 and WAM_USER = U_ID and U_NAME = uname and WAI_ID = inst_id;
   foreach (any psi in services) do
     {
	if (psi > 0)
          insert soft ODS..APP_PING_REG (AP_HOST_ID, AP_WAI_ID) values (psi, inst_id);
     }
  rc := row_count ();
ret:
  return ods_serialize_int_res (rc);
}
;

create procedure ODS.ODS_API."instance.notification.cancel" (in inst_id int, in services any) __soap_http 'text/xml'
{
  declare uname varchar;
  declare rc, dummy int;
  declare msg varchar;

  declare exit handler for sqlstate '*' {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  if (not ods_check_auth (uname, inst_id))
    return ods_auth_failed ();

  whenever not found goto ret;
  msg := 'No enough permissions, must be instance owner';
  rc := -13;
  select WAI_ID into dummy from DB.DBA.WA_INSTANCE, DB.DBA.WA_MEMBER, DB.DBA.SYS_USERS
      where WAI_NAME = WAM_INST and WAM_MEMBER_TYPE = 1 and WAM_USER = U_ID and U_NAME = uname and WAI_ID = inst_id;
   foreach (any psi in services) do
     {
       delete from ODS..APP_PING_REG where AP_HOST_ID = psi and AP_WAI_ID = inst_id;
     }

  rc := row_count ();
  msg := '';
ret:
  return ods_serialize_int_res (rc, msg);
}
;

create procedure ODS.ODS_API."instance.notification.log" (in inst_id int) __soap_http 'text/xml'
{
  return;
}
;


create procedure ODS.ODS_API."instance.search" (in pattern varchar) __soap_http 'text/xml'
{
  declare q varchar;
  declare exit handler for sqlstate '*' {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  q := sprintf (
  'select * from <%s> where '||
  ' { ?inst a sioc:Container ; dc:identifier ?inst_id ; ?property ?value . ?value bif:contains "%s" } ',
  sioc..get_graph(), pattern);
  exec_sparql (q);
  return '';
}
;

create procedure ODS.ODS_API."instance.get" (in inst_id int) __soap_http 'text/xml'
{
  declare q varchar;
  declare exit handler for sqlstate '*' {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  q := sprintf (
  'select * from <%s> where '||
  ' { ?inst a sioc:Container ; dc:identifier %d ; ?property ?value . } ',
  sioc..get_graph(), inst_id);
  exec_sparql (q);
  return '';
}
;


-- global actions

create procedure ODS.ODS_API."site.search" (in pattern varchar, in options any) __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*' {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  ODS.DBA.search_do_rdf (pattern, options, vector ('Accept: application/sparql-results+xml\r\n'), 100);
  return '';
}
;

create procedure ODS.ODS_API.error_handler () __soap_http 'text/xml'
{
  declare code, msg any;
  code := http_param ('__SQL_STATE');
  msg  := http_param ('__SQL_MESSAGE');
  if (isstring (code) and isstring (msg))
    return ods_serialize_sql_error (code, msg);
  return '<failed><code>-500</code><message>Can not process your request, please check parameters</message></failed>';
}
;

DB.DBA.USER_CREATE ('ODS_API', uuid(), vector ('DISABLED', 1, 'LOGIN_QUALIFIER', 'ODS'));
DB.DBA.VHOST_REMOVE (lpath=>'/ods/api');
DB.DBA.VHOST_DEFINE (lpath=>'/ods/api', ppath=>'/SOAP/Http', soap_user=>'ODS_API', opts=>vector ('500_page', 'error_handler'));

grant execute on ODS.ODS_API.error_handler to ODS_API;

grant execute on ODS.ODS_API."user.register" to ODS_API;
grant execute on ODS.ODS_API."user.authenticate" to ODS_API;
grant execute on ODS.ODS_API."user.update" to ODS_API;
grant execute on ODS.ODS_API."user.password_change" to ODS_API;
grant execute on ODS.ODS_API."user.delete" to ODS_API;
grant execute on ODS.ODS_API."user.freeze" to ODS_API;
grant execute on ODS.ODS_API."user.get" to ODS_API;
grant execute on ODS.ODS_API."user.search" to ODS_API;
grant execute on ODS.ODS_API."user.invite" to ODS_API;
grant execute on ODS.ODS_API."user.invitation" to ODS_API;
grant execute on ODS.ODS_API."user.invitations.get" to ODS_API;
grant execute on ODS.ODS_API."user.relation_terminate" to ODS_API;
grant execute on ODS.ODS_API."user.relation_update" to ODS_API;
grant execute on ODS.ODS_API."user.tagging_rules.add" to ODS_API;
grant execute on ODS.ODS_API."user.tagging_rules.update" to ODS_API;
grant execute on ODS.ODS_API."user.tagging_rules.delete" to ODS_API;
grant execute on ODS.ODS_API."user.hyperlinking_rules.add" to ODS_API;
grant execute on ODS.ODS_API."user.hyperlinking_rules.update" to ODS_API;
grant execute on ODS.ODS_API."user.hyperlinking_rules.delete" to ODS_API;
grant execute on ODS.ODS_API."instance.create" to ODS_API;
grant execute on ODS.ODS_API."instance.update" to ODS_API;
grant execute on ODS.ODS_API."instance.delete" to ODS_API;
grant execute on ODS.ODS_API."instance.join" to ODS_API;
grant execute on ODS.ODS_API."instance.disjoin" to ODS_API;
grant execute on ODS.ODS_API."instance.join_approve" to ODS_API;
grant execute on ODS.ODS_API."notification.services" to ODS_API;
grant execute on ODS.ODS_API."instance.notification.set" to ODS_API;
grant execute on ODS.ODS_API."instance.notification.cancel" to ODS_API;
grant execute on ODS.ODS_API."instance.notification.log" to ODS_API;
grant execute on ODS.ODS_API."instance.search" to ODS_API;
grant execute on ODS.ODS_API."instance.get" to ODS_API;
grant execute on ODS.ODS_API."site.search" to ODS_API;


create procedure __user_password (in uname varchar)
{
  return (select pwd_magic_calc (U_NAME, U_PASSWORD, 1) from Db.DBA.SYS_USERS where U_NAME = uname);
}
;


-- WebDAV

create procedure get_briefcase_inst (in path varchar)
{
  declare uname, arr varchar;
  declare inst_id int;
  arr := sprintf_inverse (path, '/DAV/home/%s/%s', 1);
  if (length (arr) <> 2)
    return 0;
  uname := arr[0];
  inst_id := 0;
  whenever not found goto ret;
  select WAI_ID into inst_id from DB.DBA.WA_INSTANCE, DB.DBA.WA_MEMBER, DB.DBA.SYS_USERS where
      WAM_USER = U_ID and U_NAME = uname and WAI_TYPE_NAME = 'oDrive' and WAM_INST = WAI_NAME and WAM_MEMBER_TYPE = 1;
ret:
  return inst_id;
}
;

create procedure ODS.ODS_API."briefcase.resource.get" (in path varchar) __soap_http 'text/xml'
{
  declare uname varchar;
  declare rc int;
  declare content, tp any;
  declare inst_id int;

  declare exit handler for sqlstate '*' {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  inst_id := get_briefcase_inst (path);
  if (not ods_check_auth (uname, inst_id))
    return ods_auth_failed ();

  rc := DB.DBA.DAV_RES_CONTENT_INT (DB.DBA.DAV_SEARCH_ID (path, 'R'), content, tp, 0, 0, uname, null);
  if (rc < 0)
    return ods_serialize_int_res (rc);
  else
    {
      http_header (sprintf ('Content-Type: %s\r\n', tp));
      http (content);
    }
  return '';
}
;

create procedure ODS.ODS_API."briefcase.resource.store" (
	in path varchar,
	in content varchar,
	in "type" varchar := null,
	in permissions varchar := '110100100RM'
	)
	__soap_http 'text/xml'
{
  declare uname varchar;
  declare rc int;
  declare uid, gid int;
  declare inst_id int;

  declare exit handler for sqlstate '*' {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  inst_id := get_briefcase_inst (path);

  if (not ods_check_auth (uname, inst_id))
    return ods_auth_failed ();

  whenever not found goto ret;
  select U_ID, U_GROUP into uid, gid from DB.DBA.SYS_USERS where U_NAME = uname;
  rc := DB.DBA.DAV_RES_UPLOAD_STRSES_INT (path, content, "type", permissions, uid, gid, uname, null, 0, null, null, null, null, null, 1);
ret:
  return ods_serialize_int_res (rc);
}
;

create procedure ODS.ODS_API."briefcase.resource.delete" (in path varchar) __soap_http 'text/xml'
{
  declare uname varchar;
  declare rc int;
  declare inst_id int;

  declare exit handler for sqlstate '*' {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  inst_id := get_briefcase_inst (path);

  if (not ods_check_auth (uname, inst_id))
    return ods_auth_failed ();

  rc := DB.DBA.DAV_DELETE_INT (path, 0, uname, null);
ret:
  return ods_serialize_int_res (rc);
}
;

create procedure ODS.ODS_API."briefcase.collection.create" (in path varchar, in permissions varchar := '110100100RM') __soap_http 'text/xml'
{
  declare uname varchar;
  declare rc int;
  declare uid, gid int;
  declare inst_id int;

  declare exit handler for sqlstate '*' {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  inst_id := get_briefcase_inst (path);

  if (not ods_check_auth (uname, inst_id))
    return ods_auth_failed ();

  whenever not found goto ret;
  select U_ID, U_GROUP into uid, gid from DB.DBA.SYS_USERS where U_NAME = uname;
  rc := DB.DBA.DAV_COL_CREATE_INT (path, permissions, uid, gid, uname, null, 1, 0, 1, null, null);
ret:
  return ods_serialize_int_res (rc);
}
;


create procedure ODS.ODS_API."briefcase.collection.delete" (in path varchar) __soap_http 'text/xml'
{
  declare uname varchar;
  declare rc int;
  declare inst_id int;

  declare exit handler for sqlstate '*' {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  inst_id := get_briefcase_inst (path);

  if (not ods_check_auth (uname, inst_id))
    return ods_auth_failed ();

  rc := DB.DBA.DAV_DELETE_INT (path, 0, uname, null, 0);
ret:
  return ods_serialize_int_res (rc);
}
;

create procedure ODS.ODS_API."briefcase.copy"
(in from_path varchar, in to_path varchar, in overwrite int := 0, in permissions varchar := '110100000RR')
__soap_http 'text/xml'
{
  declare uname varchar;
  declare rc int;
  declare uid, gid int;
  declare inst_id, inst_id2 int;

  declare exit handler for sqlstate '*' {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  inst_id := get_briefcase_inst (from_path);
  inst_id2 := get_briefcase_inst (to_path);
  if (inst_id <> inst_id2)
    inst_id := 0;

  if (not ods_check_auth (uname, inst_id))
    return ods_auth_failed ();

  whenever not found goto ret;
  select U_ID, U_GROUP into uid, gid from DB.DBA.SYS_USERS where U_NAME = uname;
  rc := DB.DBA.DAV_COPY_INT (from_path, to_path, overwrite, permissions, uid, gid, uname, null, 0);
ret:
  return ods_serialize_int_res (rc);
}
;

create procedure ODS.ODS_API."briefcase.move" (in from_path varchar, in to_path varchar) __soap_http 'text/xml'
{
  declare uname varchar;
  declare rc int;
  declare inst_id, inst_id2 int;

  declare exit handler for sqlstate '*' {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  inst_id := get_briefcase_inst (from_path);
  inst_id2 := get_briefcase_inst (to_path);
  if (inst_id <> inst_id2)
    inst_id := 0;

  if (not ods_check_auth (uname, inst_id))
    return ods_auth_failed ();

  rc := DB.DBA.DAV_MOVE_INT (from_path, to_path, 0, uname, null, 0);
ret:
  return ods_serialize_int_res (rc);
}
;

create procedure ODS.ODS_API."briefcase.property.set" (in path varchar, in property varchar, in value varchar) __soap_http 'text/xml'
{
  declare uname varchar;
  declare rc int;
  declare inst_id int;

  declare exit handler for sqlstate '*' {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  inst_id := get_briefcase_inst (path);

  if (not ods_check_auth (uname, inst_id))
    return ods_auth_failed ();

  rc := DB.DBA.DAV_PROP_SET_INT (path, property, value, uname, null, 0, 1, 0);
ret:
  return ods_serialize_int_res (rc);
}
;

create procedure ODS.ODS_API."briefcase.property.remove" (in path varchar, in property varchar) __soap_http 'text/xml'
{
  declare uname varchar;
  declare rc int;
  declare inst_id int;

  declare exit handler for sqlstate '*' {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  inst_id := get_briefcase_inst (path);

  if (not ods_check_auth (uname, inst_id))
    return ods_auth_failed ();

  rc := DB.DBA.DAV_PROP_REMOVE_INT (path, property, uname, null, 0);
ret:
  return ods_serialize_int_res (rc);
}
;

create procedure ODS.ODS_API."briefcase.property.get" (in path varchar, in property varchar := null)
__soap_http 'text/xml'
{
  declare uname varchar;
  declare rc int;
  declare st char;
  declare inst_id int;

  declare exit handler for sqlstate '*' {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  inst_id := get_briefcase_inst (path);
  if (not ods_check_auth (uname, inst_id))
    return ods_auth_failed ();

  if ((path <> '') and (path[length(path)-1] = 47))
    st := 'C';
  else
    st := 'R';
  rc := DB.DBA.DAV_PROP_GET_INT (DB.DBA.DAV_SEARCH_ID (path, st), st, property, 0, uname);
ret:
  if (rc < 0)
    return ods_serialize_int_res (rc);
  else
    return rc;
}
;

db.dba.wa_exec_no_error ('grant SPARQL_SELECT to ODS_API');
grant execute on DB.DBA.XML_URI_GET_STRING_OR_ENT to ODS_API;
grant execute on DB.DBA.RDF_SPONGE_UP to ODS_API;
grant select on WS.WS.SYS_DAV_RES to ODS_API;

grant execute on ODS.ODS_API."briefcase.resource.get" to ODS_API;
grant execute on ODS.ODS_API."briefcase.resource.store" to ODS_API;
grant execute on ODS.ODS_API."briefcase.resource.delete" to ODS_API;
grant execute on ODS.ODS_API."briefcase.collection.create" to ODS_API;
grant execute on ODS.ODS_API."briefcase.collection.delete" to ODS_API;
grant execute on ODS.ODS_API."briefcase.copy" to ODS_API;
grant execute on ODS.ODS_API."briefcase.move" to ODS_API;
grant execute on ODS.ODS_API."briefcase.property.set" to ODS_API;
grant execute on ODS.ODS_API."briefcase.property.remove" to ODS_API;
grant execute on ODS.ODS_API."briefcase.property.get" to ODS_API;
use DB;

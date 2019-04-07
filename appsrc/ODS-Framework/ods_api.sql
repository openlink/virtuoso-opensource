
-- ODS API
-- Contains 2 procedures accessible by SOAP
--  ODS_CREATE_USER                       -- Automatic creation of new user without going trough web registration procedure.
--  in _username varchar,                -- login for user to create
--  in _passwd varchar,                  -- password for created user
--  in _email varchar,                   -- email address for user
--  in _host varchar := '',              -- desired domain for which user will be created, if not supplied URIQA default host will be taken
--  in _creator_username varchar :='',   -- if registration for domain is prohibited authentication of administrator of the domain is required in order to authorize account create
--  in _creator_passwd varchar :=''      -- password for authorized administrator
--  in _is_searchable integer := 0       -- optional value to determine if new user data is searchable
--  in _show_activity integer := 0       -- optional value to determine if new user is shown on activity dashboard on ODS home page
--
--  result is INTEGER (created user id) if successful, otherwise varchar - ERROR MESSAGE;
--
--  ODS_CREATE_NEW_APP_INST        -- creates instance of determined type for given user
--  in app_type varchar,          -- VALID WA_TYPE of application to create
--  in inst_name varchar,         -- desired name for the instance
--  in owner varchar,             -- username of the owner of the instance
--  in model int := 0,            -- refers to Membership model (Open,Closed,Invitation only,Approval based
--  in pub int := 0,              -- refers to Visible to public property
--  in inst_descr varchar := null -- description for the instance
--
-- result is INTEGER (instance id)if successful, otherwise varchar - ERROR MESSAGE
--
-- Access to procedures granted to GDATA_ODS SOAP user using /ods_services endpoint.

use DB;

DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('ods_svc_rule1', 1,
  '/ods_services/search/(.*)', vector ('par'), 1,
  '/sparql?query=prefix%%20rdfs%%3A%%20%%3Chttp%%3A//www.w3.org/2000/01/rdf-schema%%23%%3E%%20select%%20distinct%%20%%3Fu%%20%%3Ft%%20%%3Fl%%20from%%20%%3Chttp%%3A//^{URIQADefaultHost}^/dataspace%%3E%%20where%%20%%7B%%20%%3Fu%%20a%%20%%3Ft%%20%%3B%%20rdfs%%3Alabel%%20%%3Fl%%20%%3B%%20%%3Fp%%20%%3Fo%%20.%%20filter%%20bif%%3Acontains%%20%%28%%3Fo%%2C%%20%%27%U%%27%%29%%20%%20%%7D%%20LIMIT%%20100&format=application/sparql-results%2Bxml', vector ('par'), 'DB.DBA.ODS_API_FTI_MAKE_SEARCH_STRING', null, 2, null);

DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('ods_svc_rule2', 1,
  '/ods_services/search_ecrm/(.*)', vector ('par'), 1,
  '/sparql?query=prefix%%20rdfs%%3A%%20%%3Chttp%%3A//www.w3.org/2000/01/rdf-schema%%23%%3E%%20select%%20distinct%%20%%3Fu%%20%%3Ft%%20%%3Fl%%20from%%20%%3Chttp%%3A//^{URIQADefaultHost}^/ecrm%%3E%%20where%%20%%7B%%20%%3Fu%%20a%%20%%3Ft%%20%%3B%%20rdfs%%3Alabel%%20%%3Fl%%20%%3B%%20%%3Fp%%20%%3Fo%%20.%%20filter%%20bif%%3Acontains%%20%%28%%3Fo%%2C%%20%%27%U%%27%%29%%20%%20%%7D%%20LIMIT%%20100&format=application/sparql-results%2Bxml', vector ('par'), 'DB.DBA.ODS_API_FTI_MAKE_SEARCH_STRING', null, 2, null);

DB.DBA.URLREWRITE_CREATE_RULELIST ('ods_svc_rule_list1', 1, vector ('ods_svc_rule1', 'ods_svc_rule2'));

-- move into ods_define_common_vd
--DB.DBA.VHOST_REMOVE (vhost=>'*ini*',lhost=>'*ini*',lpath=>'/ods_services');
--DB.DBA.VHOST_DEFINE (vhost=>'*ini*',lhost=>'*ini*',lpath=>'/ods_services',ppath=>'/SOAP/',soap_user=>'GDATA_ODS', opts=>vector ('url_rewrite', 'ods_svc_rule_list1'))
;


create procedure DB.DBA.ODS_API_FTI_MAKE_SEARCH_STRING (in par varchar, in fmt varchar, in val varchar)
{
  declare v any;
  v := split_and_decode (val);
  v := regexp_replace (v[0],'<[^>]+>', '', 1, null);
  v := regexp_replace (v,'&[^;]+;', '', 1, null);
  --dbg_printf ('%s', v);
  return sprintf (fmt, replace (DB.DBA.FTI_MAKE_SEARCH_STRING (v), '\'', '\\\''));
};

create procedure get_tag_meanings_from_moat (
  in tag varchar)
{
  declare cnt, url any;
  declare arr, srv, res any;

  srv := registry_get ('MOAT_SERVER');
  if (not isstring (srv) or not length (srv))
    srv := 'http://tags.moat-project.org';
  url := sprintf ('%s/tag/%U/json/light', srv, tag);
  declare exit handler for sqlstate '*'
    {
      return vector ();
    };
  cnt := http_get (url);
  arr := json_parse (cnt);
  arr := get_keyword ('bindings',  get_keyword ('results', arr));
  res := vector ();
  foreach (any elm in arr) do
    {
      declare uri any;
      uri := get_keyword ('value', get_keyword ('uri', elm));
      res := vector_concat (res, vector (uri));
    }
  return res;
}
;

create procedure tag_meanings (
  in tag varchar,
  in inst int,
  in post int) __SOAP_HTTP 'text/html'
{
  declare cnt, url, ses, str, vec, uid, trs any;
  declare arr, srv any;

  arr := get_tag_meanings_from_moat (tag);
  ses := string_output ();
  str := '';
  vec := vector ();
  http ('{ "results": { "bindings": [ ', ses);
  if (not exists (select 1 from moat.DBA.moat_meanings where m_tag = tag and m_inst = inst and m_id = post))
    {
      uid := (select U_ID from SYS_USERS, WA_MEMBER, WA_INSTANCE where U_ID = WAM_USER and WAM_INST = WAI_NAME and WAM_MEMBER_TYPE = 1 and WAI_ID = inst);
      for select mu_url from moat.DBA.moat_user_meanings, DB.DBA.tag_user where mu_tag = tag and mu_trs_id = tu_trs
	and tu_u_id = uid order by tu_order do
	  {
	    http (sprintf ('{ "uri": { "value":"%s", "checked":true } }, ', mu_url), ses);
	    vec := vector_concat (vec, vector (mu_url));
	  }
    }
  foreach (any elm in arr) do
    {
      declare uri any;
      uri := elm;
      if (0 = position (uri, vec))
        {
	  if (exists (select 1 from moat.DBA.moat_meanings where m_tag = tag and m_inst = inst and m_id = post and m_uri = uri))
	    {
	      http (sprintf ('{ "uri": { "value":"%s", "checked":true } }, ', uri), ses);
	      vec := vector_concat (vec, vector (uri));
	    }
	  else
	    http (sprintf ('{ "uri": { "value":"%s", "checked":false } }, ', uri), ses);
        }
    }
  for select m_uri from moat.DBA.moat_meanings where m_tag = tag and m_inst = inst and m_id = post
    and 0 = position (m_uri, vec) do
      {
        http (sprintf ('{ "uri": { "value":"%s", "checked":true } }, ', m_uri), ses);
      }
  http (' null ] } }', ses);
  return string_output_string (ses);
}
;

grant execute on tag_meanings to GDATA_ODS;

create procedure OdsIriDescribe (
  in iri varchar,
  in accept varchar := 'application/rdf+xml') __SOAP_HTTP 'text/xml'
{
  declare qr, stat, msg any;
  declare rset, metas, this_iri, type_iri, label_iri, name_iri, g_iri any;
  declare ses any;
  declare dict, triples any;

  set http_charset='utf-8';
  qr := sprintf ('SPARQL DESCRIBE <%s> FROM <%s>', iri, sioc..get_graph ());
  stat := '00000';
  set_user_id ('SPARQL');
  exec (qr, stat, msg, vector (), 0, metas, rset);
--  accept := 'text/rdf+n3';
  if (stat = '00000')
    {
      declare http_hdr varchar;
      http_hdr := http_header_get ();
      ses := string_output ();
      if (accept <> 'text/rdf+n3')
	{
	  if (strcasestr (http_hdr, 'Content-Type:') is null)
	    http_header (http_hdr || 'Content-Type: application/rdf+xml; charset=UTF-8\r\n');
	  sioc..rdf_head (ses);
	  if ((1 = length (rset)) and (1 = length (rset[0])) and (214 = __tag (rset[0][0])))
	    {
	      triples := dict_list_keys (rset[0][0], 1);
	      DB.DBA.RDF_TRIPLES_TO_RDF_XML_TEXT (triples, 0, ses);
	    }
	}
      else
	{
	  if (strcasestr (http_hdr, 'Content-Type:') is null)
	    http_header (http_hdr || 'Content-Type: text/rdf+n3; charset=UTF-8\r\n');
	  DB.DBA.SPARQL_RESULTS_WRITE (ses, metas, rset, accept, 0);
	}
    }
  else
    signal (stat, msg);

  this_iri := iri_to_id (iri);
  type_iri := iri_to_id (sioc..rdf_iri ('type'));
  label_iri := iri_to_id (sioc..rdfs_iri ('label'));
  name_iri := iri_to_id (sioc..foaf_iri ('name'));
  g_iri := iri_to_id (sioc..get_graph ());

  dict := dict_new ();

  if ((1 = length (rset)) and
    (1 = length (rset[0])) and
    (214 = __tag (rset[0][0])) )
    {
      declare triples any;
      triples := dict_list_keys (rset[0][0], 1);
      foreach (any tr in triples) do
	{
	  declare subj, obj any;
	  subj := tr[0];
	  obj := tr[2];
          if (isiri_id (subj) and this_iri <> subj)
	    {
	      --dbg_obj_print ('subj:', subj);
	      for select S, P, O from DB.DBA.RDF_QUAD where G = g_iri and S = subj and P in (type_iri, label_iri, name_iri)  do
		{
		  dict_put (dict, vector (S, P, O), 0);
		}
	    }
	  else if (isiri_id (obj) and obj <> this_iri)
	    {
	      --dbg_obj_print ('obj:', obj);
	      for select S, P, O from DB.DBA.RDF_QUAD where G = g_iri and S = obj and P in (type_iri, label_iri)  do
		{
		  dict_put (dict, vector (S, P, O), 0);
		}
	    }
	}
      triples := dict_list_keys (dict, 1);
      if (accept = 'text/rdf+n3')
        DB.DBA.RDF_TRIPLES_TO_TTL (triples, ses);
      else
        DB.DBA.RDF_TRIPLES_TO_RDF_XML_TEXT (triples, 0, ses);
    }
  if (accept <> 'text/rdf+n3')
    sioc..rdf_tail (ses);
  http (ses);
  return '';
}
;

grant execute on OdsIriDescribe to GDATA_ODS;

create procedure ODS_CREATE_USER (
  in _username varchar,
  in _passwd varchar,
  in _email varchar,
  in _host varchar := '',
  in _creator_username varchar := '',
  in _creator_passwd varchar := '',
  in _is_searchable integer := 0,
  in _show_activity integer := 0)
{
   declare dom_reg int;
   declare country, city, lat, lng, xt, xp any;
   declare _err,_port,default_host,default_port,vhost varchar;
   declare _arr any;

   _username := trim(_username);
  if(length(_host)=0)
    _host := cfg_item_value (virtuoso_ini_path (), 'URIQA', 'DefaultHost');

  _arr := split_and_decode (_host, 0, '\0\0:');
  if (length (_arr) > 1)
    {
      default_host := _arr[0];
      default_port := _arr[1];
      vhost := _host;
      _port := ':'||default_port;
    }
  else if (length (_arr) = 1)
    {
      default_host := _host;
      default_port := '80';
      vhost := _host || ':80';
      _port := ':'||default_port;
    }
  else
  {
    _err:='Given domain is incorrect.';
    goto report_err;
  }

  -- Check input parameter: email and username
  if (_email is null or _email = '' or length (_email) > 40)
  {
    _err := sprintf('The E-mail address cannot be empty or longer then 40 chars: %s', _email);
    goto report_err;
  }
  else if (regexp_match ('[^@ ]+@([^\. ]+\.)+[^\. ]+', _email) is null)
  {
    _err := sprintf('Invalid E-mail address provided: %s', _email);
    goto report_err;
  }

  if (_username is null or length (_username) < 1 or length (_username) > 20)
  {
    _err := 'Login name cannot be empty or longer than 20 chars';
    goto report_err;
  }
  else if (regexp_match ('^[A-Za-z0-9_.@-]+\$', _username) is null)
  {
    _err := sprintf('The login name contains invalid characters: %s', _username);
    goto report_err;
  }

  if (_passwd is null or length (_passwd) < 1 or length (_passwd) > 40)
  {
    _err := 'Password cannot be empty or longer then 40 chars';
    goto report_err;
  }


   dom_reg := null;
   whenever not found goto nfd;
  select WD_MODEL into dom_reg from WA_DOMAINS where WD_HOST = vhost and WD_LISTEN_HOST = _port and WD_LPATH = '/ods';

   nfd:;
   if (dom_reg is not null)
   {
    if (dom_reg = 0 or not exists (select 1 from WA_SETTINGS where WS_REGISTER = 1))
       {
           if(web_user_password_check(_creator_username,_creator_passwd)=0
              or
              not exists(select 1 from SYS_USERS where U_NAME=_creator_username and U_GROUP in (0,3))
             )
           {
              _err := 'Registration is not allowed and user creator\'s authentication is incorrect or creator is not administrator.';
              goto report_err;
           }
       }
   }


   declare uid int;
   declare exit handler for sqlstate '*'
   {
     _err := concat (__SQL_STATE,' ',__SQL_MESSAGE);
     rollback work;
     goto report_err;
   };

   -- check if this login already exists
   if (exists(select 1 from DB.DBA.SYS_USERS where U_NAME = _username))
   {
    _err := sprintf('The username "%s" is already registered', _username);
    goto report_err;
  }

  if (exists (select 1 from DB.DBA.SYS_USERS where U_E_MAIL = _email) and exists (select 1 from DB.DBA.WA_SETTINGS where WS_UNIQUE_MAIL = 1))
  {
    _err := sprintf('The e-mail "%s" address is already registered', _email);
     goto report_err;
   }

   -- determine if mail verification is necessary
   declare _mail_verify_on any;
   _mail_verify_on := coalesce((select 1 from WA_SETTINGS where WS_MAIL_VERIFY = 1), 0);

    declare _disabled any;
    -- create user initially disabled
  uid := USER_CREATE (_username,
                      _passwd,
         vector ('E-MAIL', _email,
                 'HOME', '/DAV/home/' || _username || '/',
                 'DAV_ENABLE' , 1,
                 'SQL_ENABLE', 0));
   update SYS_USERS set U_ACCOUNT_DISABLED = _mail_verify_on where U_ID = uid;
  DB.DBA.DAV_HOME_DIR_CREATE (_username);

  declare _det_col_id integer;
  _det_col_id := DB.DBA.DAV_MAKE_DIR ('/DAV/home/'||_username||'/RDFData/', uid, http_nogroup_gid (), '110100100N');
  update WS.WS.SYS_DAV_COL set COL_DET = 'RDFData' where COL_ID = _det_col_id;

   WA_USER_SET_INFO(_username, '', '');
   WA_USER_TEXT_SET(uid, _username||' '||_email);
   wa_reg_register (uid, _username);

   WA_USER_EDIT (_username, 'WAUI_SEARCHABLE', _is_searchable);
   WA_USER_EDIT (_username, 'WAUI_SHOWACTIVE', _show_activity);
  if (0) -- don't use IP location service, since this api can be run locally
   {
     declare coords any;
     declare exit handler for sqlstate '*';
     xt := http_client (sprintf ('http://api.hostip.info/?ip=%s', http_client_ip ()));
     xt := xtree_doc (xt);
     country := cast (xpath_eval ('string (//countryName)', xt) as varchar);
     city := cast (xpath_eval ('string (//Hostip/name)', xt) as varchar);
     coords := cast (xpath_eval ('string(//ipLocation//coordinates)', xt) as varchar);
     lat := null;
     lng := null;
     if (country is not null and length (country) > 2)
     {
         country := (select WC_NAME from WA_COUNTRY where upper (WC_NAME) = country);
         if (country is not null)
         {
             declare exit handler for not found;
             select WC_LAT, WC_LNG into lat, lng from WA_COUNTRY where WC_NAME = country;
             WA_USER_EDIT (_username, 'WAUI_HCOUNTRY', country);
         }
     }
     WA_USER_EDIT (_username, 'WAUI_HCITY', city);
     if (coords is not null)
     {
         coords := split_and_decode (coords, 0, '\0\0\,');
         if (length (coords) = 2)
         {
           lat := atof (coords [0]);
           lng := atof (coords [1]);
         }
     }
     if (lat is not null and lng is not null)
      {
         WA_USER_EDIT (_username, 'WAUI_LAT', lat);
         WA_USER_EDIT (_username, 'WAUI_LNG', lng);
         WA_USER_EDIT (_username, 'WAUI_LATLNG_HBDEF', 0);
      }
   }

   insert soft sn_person (sne_name, sne_org_id) values (_username, uid);

    if (_mail_verify_on)
    {
        -- create session
        declare sid any;
        sid := md5 (concat (datestring (now ()), cast(randomize(999999) as varchar), wa_link(), '/register.vspx'));
        declare _expire integer;
        _expire:=24;
        _expire := coalesce((select top 1 WS_REGISTRATION_EMAIL_EXPIRY from WA_SETTINGS), 1);
        set triggers off;
        insert into VSPX_SESSION (VS_REALM, VS_SID, VS_UID, VS_STATE, VS_EXPIRY)
               values ('wa', sid, _username, serialize (vector ('vspx_user', _username)), dateadd ('hour', _expire, now()));
        set triggers on;

       -- determine existing default mail server
       declare _smtp_server any;
    if((select max(WS_USE_DEFAULT_SMTP) from WA_SETTINGS) = 1 or (select length(max(WS_SMTP)) from WA_SETTINGS) = 0)
         _smtp_server := cfg_item_value(virtuoso_ini_path(), 'HTTPServer', 'DefaultMailServer');
       else
         _smtp_server := (select max(WS_SMTP) from WA_SETTINGS);
       if (_smtp_server = 0)
       {
         _err := 'Mail is obligatory but verification impossible. Default Mail Server is not defined. ';
         rollback work;
         goto report_err;
       }
       declare msg, _sender_address, body, body1 varchar;
    body := (select coalesce(blob_to_string(RES_CONTENT), 'Not found...') from WS.WS.SYS_DAV_RES where  RES_FULL_PATH = '/DAV/VAD/wa/tmpl/WS_REG_TEMPLATE');
       body1 := WA_MAIL_TEMPLATES(body, null, _username, sprintf('%s/conf.vspx?sid=%s&realm=wa', rtrim(WA_LINK(1),'/'),sid ));
    msg := 'Subject: Account registration confirmation\r\nContent-Type: text/plain\r\n' || body1;
       _sender_address := (select U_E_MAIL from SYS_USERS where U_ID = http_dav_uid ());
       {
         declare exit handler for sqlstate '*'
         {
           declare _use_sys_errors, _sys_error, _error any;
           _sys_error := concat (__SQL_STATE,' ',__SQL_MESSAGE);
        _error := '
          Due to a transient problem in the system, your registration could not be
             processed at the moment. The system administrators have been notified. Please
             try again later';
           _use_sys_errors := (select top 1 WS_SHOW_SYSTEM_ERRORS from WA_SETTINGS);
           if(_use_sys_errors)
           {
             _err := _error || ' ' || _sys_error;
           }
           else
           {
             _err := _error;
           }
           rollback work;
           goto report_err;
         };

         smtp_send(_smtp_server, _sender_address, _email, msg);
       }
    }
    return uid;

report_err:;

 return _err;

};

grant execute on ODS_CREATE_USER to GDATA_ODS;



create procedure ODS_CREATE_NEW_APP_INST (
  in app_type varchar,
  in inst_name varchar,
  in owner varchar,
  in model integer := 1,
  in pub integer := 0,
  in inst_descr varchar := null)
{
  declare inst web_app;
  declare ty, h, id any;
  declare _err varchar;
  declare _u_id, _wai_id, visible integer;
  declare lpath varchar;

  _err:='';

  -- check for correct instance name
  if ((length(coalesce(inst_name, '')) < 1) or (length(coalesce(inst_name, '')) > 55))
  {
       _err:='Instance name should not be empty and not longer than 55 characters;';
       goto report_err;
  }


  --check for existing instance with the same name
   if (exists(select 1 from WA_INSTANCE where WAI_NAME = inst_name))
   {
       _err:='Instance with name - '||inst_name||' already exists;';
       goto report_err;
   }

  --check that user is correct/exists
   {
    declare exit handler for not found
           {
            _err:='User - '||owner||' does not exist;';
            goto report_err;
           };

    select U_ID into _u_id from SYS_USERS where U_NAME=owner;
   }


  --check for correct/installed application_type
  {
   declare exit handler for not found
          {
           _err:='Application type - '||app_type||' does not exist; ';
           goto report_err;
          };
   select WAT_TYPE into ty from WA_TYPES where WAT_NAME = app_type;
  }
  visible := case when app_type in ('oDrive', 'oMail', 'IM') then 0 else 1 end;

  inst := __udt_instantiate_class (fix_identifier_case (ty), 0);
  inst.wa_name := inst_name;
  inst.wa_member_model := model;
  if (app_type = 'oWiki')
  {
    declare N integer;

    N := 0;
    lpath := sprintf('/%U/%U', owner, 'wiki');
    while (exists (select 1 from DB.DBA.HTTP_PATH where HP_LPATH = lpath))
    {
      N := N + 1;
      lpath := sprintf('/%U/wiki/%d', owner, N);
    }
    connection_set ('wiki_home', lpath);
  }
  h := udt_implements_method (inst, 'wa_new_inst');
  if (h<>0)
  {
    {
     declare exit handler for sqlstate '*'
     {
	      _err := 'Cannot create "'|| inst_name ||'" of type '||app_type ||' for '||owner||'. SQL_ERR: '||
	      concat (__SQL_STATE, ' ', __SQL_MESSAGE) ||';';
       goto report_err;
     };

     id := call (h) (inst, owner);
    }

      if (id <> 0)
	{
      update WA_INSTANCE
             set WAI_MEMBER_MODEL = model,
                 WAI_IS_PUBLIC = pub,
        		 WAI_MEMBERS_VISIBLE = visible,
                 WAI_NAME = inst_name,
                 WAI_DESCRIPTION = coalesce(inst_descr,inst_name || ' Description')
           where WAI_ID = id;
	}
      else
    {
       _err:='Cannot update properties for '|| inst_name ||' of type '|| app_type ||' for '||owner||';';
       goto report_err;
    }
    }
  else
  {
    _err:='Application type '|| app_type ||' do not support wa_new_inst() method;';
    goto report_err;
  }

 -- ensure default domain
 {
   commit work;
   declare exit handler for sqlstate '*'
     {
       rollback work;
       goto relaxing;
     };
    if (app_type <> 'oWiki')
    {
   lpath := DB.DBA.wa_set_url_t (inst);
      if ((lpath like '%.vspx') or (lpath like '%.vsp'))
      {
        declare pos integer;

        pos := strrchr (lpath, '/');
        if (not isnull (pos))
          lpath := subseq (lpath, 0, pos);
      }
    }
    else if (app_type = 'oWiki')
    {
      DB.DBA.WA_SET_APP_URL (id, lpath, null, '{Default Domain}', null, null, null, 1);
    }
   DB.DBA.WA_SET_APP_URL (id, lpath, null, DB.DBA.wa_default_domain (), null, null, null, 1);
    if (app_type <> 'oMail')
   DB.DBA.WA_SET_APP_URL (id, lpath, null, '{Default HTTPS}', null, null, null, 1);
 }
relaxing:
 return id;

report_err:;
 return _err;
};

grant execute on ODS_CREATE_NEW_APP_INST to GDATA_ODS;


create procedure ODS_DELETE_USER (
  in _username varchar,
  in _delDAV integer := 1,
  in _auth_username varchar := '',
  in _auth_passwd varchar := '' )
{
  declare _err varchar;

  _err:='';
  if(web_user_password_check(_auth_username,_auth_passwd)=0
     or
     not exists(select 1 from SYS_USERS where U_NAME=_auth_username and U_GROUP in (0,3))
    )
  {
     _err := 'Authentication is incorrect.';
     goto report_err;
  }

  connection_set('odsapi_auth_username',_auth_username);
  connection_set('odsapi_auth_userpass',_auth_passwd);
  connection_set('odsapi_deldav',_delDAV);

  declare exit handler for SQLSTATE '*' { ROLLBACK WORK; RESIGNAL; };
  delete from DB.DBA.SYS_USERS where U_NAME=_username;

  return 1;

report_err:;
 return _err;
}
;

grant execute on ODS_DELETE_USER to GDATA_ODS;

-- This procedure is called inside trigger SYS_USERS_ON_DELETE_WA_FK on SYS_USERS;
create procedure ODS_DELETE_USER_DATA (
  in _username varchar,
  in _delDAV integer := 1,
  in _auth_username varchar :='',
  in _auth_passwd varchar :='' )
{
  declare _u_name,_err varchar;
  declare _u_id integer;

  if(is_http_ctx())
  {
      if(http_map_get('mounted')='/SOAP/')
      {
        if(_auth_username='')
        {
          _auth_username:= coalesce(connection_get('odsapi_auth_username'),'');
          _auth_passwd  := coalesce(connection_get('odsapi_auth_userpass'),'');

            if(web_user_password_check(_auth_username,_auth_passwd)=0
               or
               not exists(select 1 from SYS_USERS where U_NAME=_auth_username and U_GROUP in (0,3))
              )
            {
               _err := 'Authentication is incorrect.';
               goto report_err;
            }
      }
      else
        {
          if(web_user_password_check(_auth_username,_auth_passwd)=0
             or
             not exists(select 1 from SYS_USERS where U_NAME=_auth_username and U_GROUP in (0,3))
            )
          {
             _err := 'Authentication is incorrect.';
             goto report_err;
          }

          connection_set('odsapi_auth_username',_auth_username);
          connection_set('odsapi_auth_userpass',_auth_passwd);
          connection_set('odsapi_deldav',_delDAV);
        }
      }
  }

  _u_id := (select U_ID from DB.DBA.SYS_USERS where U_NAME = _username);
  if (isnull (_u_id))
  {
    _err := 'Given user name is not DB user name.';
    goto report_err;
  }
    {
    declare _sne_id integer;
    declare exit handler for not found
    {
      goto skip_sn;
    };
    select sne_id into _sne_id from sn_entity where sne_org_id = _u_id;

    delete from DB.DBA.sn_alias where sna_entity = _sne_id;
    delete from DB.DBA.sn_invitation where sni_from = _sne_id;
    delete from DB.DBA.sn_related where snr_from = _sne_id or snr_to=_sne_id;
    delete from DB.DBA.sn_member  where snm_group = _sne_id or snm_entity=_sne_id;
    delete from DB.DBA.sn_person  where sne_org_id = _u_id;
    }

skip_sn:;
  _u_name := (select U_NAME from DB.DBA.SYS_USERS, DB.DBA.WA_USER_INFO where U_ID = WAUI_U_ID and U_NAME = _username);
  if (isnull (_u_name))
  {
    _err := 'Given user name is not ODS user name.';
    goto report_err;
  }
  {
    declare exit handler for SQLSTATE '*'
    {
      rollback work;
      resignal;
    };

    declare _p_res any;

    _p_res:=ODS_DELETE_USER_INSTANCES(_u_id);
    if(_p_res<>1)
    {
       _err := _p_res;
       goto report_err;
    }
    delete from DB.DBA.WA_USERS where WAU_U_ID = _u_id;
    delete from DB.DBA.WA_USER_INFO where WAUI_U_ID = _u_id;
    if(_delDAV)
    {
      _p_res:=ODS_DELETE_USER_DAV(_u_name);
      if(_p_res<>1)
         {
           _err := _p_res;
           goto report_err;
         }
    }

  }

 return 1;

report_err:;

 return _err;

}
;

create procedure ODS_DELETE_USER_INSTANCES (
  in _user_id integer)
{
  declare _err varchar;

  _err:='';
  if (is_http_ctx())
  {
    if(http_map_get('mounted')='/SOAP/')
    {
     declare _auth_username,_auth_passwd varchar;
     _auth_username:= coalesce(connection_get('odsapi_auth_username'),'');
     _auth_passwd  := coalesce(connection_get('odsapi_auth_userpass'),'');

       if(web_user_password_check(_auth_username,_auth_passwd)=0
          or
          not exists(select 1 from SYS_USERS where U_NAME=_auth_username and U_GROUP in (0,3))
         )
       {
          _err := 'Authentication is incorrect.';
          goto report_err;
       }
    }
  }

  for select WAI_INST from DB.DBA.WA_INSTANCE,DB.DBA.WA_MEMBER where WAI_NAME=WAM_INST and WAM_USER=_user_id do
  {
     declare h, id any;
     h := udt_implements_method(WAI_INST, 'wa_drop_instance');
     declare exit handler for sqlstate '*'{
                                            _err:=WA_RETRIEVE_MESSAGE(concat(__SQL_STATE,' ',__SQL_MESSAGE));
                                            rollback work;
                                            goto report_err;
                                          };
     commit work;
     id := call (h) (WAI_INST);
  }

 return 1;
report_err:;

 return _err;

}
;

create procedure ODS_DELETE_USER_DAV (
  in _user_name varchar)
{
  declare _err varchar;
  _err:='';

  if (is_http_ctx())
  {
    if(http_map_get('mounted')='/SOAP/')
    {
     declare _auth_username,_auth_passwd varchar;
     _auth_username:= coalesce(connection_get('odsapi_auth_username'),'');
     _auth_passwd  := coalesce(connection_get('odsapi_auth_userpass'),'');

       if(web_user_password_check(_auth_username,_auth_passwd)=0
          or
          not exists(select 1 from SYS_USERS where U_NAME=_auth_username and U_GROUP in (0,3))
         )
       {
          _err := 'Authentication is incorrect.';
          goto report_err;
       }
    }
  }


  declare _davadmin, _davadminpwd, _user_homepath varchar;
  _davadmin := 'dav';
  _davadminpwd := (select pwd_magic_calc (U_NAME, U_PASSWORD, 1) from DB.DBA.SYS_USERS where U_NAME = 'dav');
  _user_homepath := '/DAV/home/'||_user_name||'/';

  declare rc integer;
  rc := DB.DBA.DAV_DELETE (_user_homepath, 0, _davadmin, _davadminpwd);

  if(rc<>1)
  {
    _err:='DAV resource delete failed with code: '||cast(rc as varchar);
    goto report_err;
  }

  return 1;

report_err:;

 return _err;

}
;

create procedure ODS..openid_url_set (
  in uid integer,
  in url varchar)
{
  declare oi_ident, hdr, cnt, xt, oi_srv, oi2_srv, oi_delegate, profile_page, xrds, xrds_url any;

  declare exit handler for sqlstate '*'
    {
      return 'Invalid OpenID URL.';
    };

  if (not length (url))
    {
      oi_ident := null;
      oi_srv := null;
      goto clear_auth;
    }

  profile_page := ODS.DBA.WF_PROFILE_GET (url);
  if (profile_page is not null)
    url := profile_page;
  else  
    {
      profile_page := ODS..FINGERPOINT_WEBID_GET (null, url);
      if (profile_page is not null)
	url := profile_page;
    }
  oi_ident := url;
again:
  hdr := null;
  cnt := DB.DBA.HTTP_CLIENT_EXT (url=>url, headers=>hdr);
  if (hdr [0] like 'HTTP/1._ 30_ %')
    {
      declare loc any;
      loc := http_request_header (hdr, 'Location', null, null);
      url := WS.WS.EXPAND_URL (url, loc);
      oi_ident := url;
      goto again;
    }
  xt := xtree_doc (cnt, 2);
  oi_srv := cast (xpath_eval ('//link[contains (@rel, "openid.server")]/@href', xt) as varchar);
  oi2_srv := cast (xpath_eval ('//link[contains (@rel, "openid2.provider")]/@href', xt) as varchar);
  oi_delegate := cast (xpath_eval ('//link[contains (@rel, "openid.delegate")]/@href', xt) as varchar);
  xrds_url := http_request_header (hdr, 'X-XRDS-Location');

  if (oi2_srv is not null)
    oi_srv := oi2_srv;

  if (oi_srv is null and xrds_url is not null)
    {
       xrds := http_client (xrds_url, n_redirects=>15);
       xrds := xtree_doc (xrds);
       oi_srv := cast (xpath_eval ('/XRDS/XRD/Service[Type/text() = "http://specs.openid.net/auth/2.0/signon"]/URI/text()', xrds) as varchar);
    }

  if (oi_srv is null)
    return 'Cannot locate OpenID server.';

  if (oi_delegate is not null)
    oi_ident := oi_delegate;

  -- if we want to change OpenID URI to local we would get same as it is will find delegate
  if (exists (select 1 from WA_USER_INFO where WAUI_OPENID_URL = oi_ident and WAUI_U_ID = uid))
    {
      oi_ident := url;
    }

  if (exists (select 1 from WA_USER_INFO where WAUI_OPENID_URL = oi_ident and WAUI_U_ID <> uid))
    return 'This OpenID identity is already registered.';

clear_auth:
  update DB.DBA.WA_USER_INFO
     set WAUI_OPENID_URL = oi_ident,
         WAUI_OPENID_SERVER = oi_srv
   where WAUI_U_ID = uid;

  -- success
  return null;
}
;

create procedure search_compose_inst_qry (
  in q any,
  in iri varchar)
{
  declare ses any;
  declare qr varchar;
  declare node, graph varchar;

  ses := string_output ();
  graph := sioc..get_graph ();

  http ('sparql ', ses);
  --http ('define input:inference <' || graph || '> \n', ses);
  http (sioc.DBA.std_pref_declare (), ses);
  http (sprintf ('\n construct { ?x ?y ?z } \n from <%s> where { \n', graph), ses);

  qr := DB.DBA.FTI_MAKE_SEARCH_STRING (q);

  node := sprintf (' ?x ?y ?z ; sioc:has_container <%S> . ?z bif:contains \'%S\' ', iri, qr);
  http (node, ses);
  http ('\n }', ses);
  return string_output_string (ses);
}
;

create procedure search_compose_qry (
  in q any,
  in pars varchar)
{
  declare ses any;
  declare arr any;
  declare tp varchar;
  declare qr varchar;
  declare node, tmp, graph varchar;
  declare all_cnt int;

  arr := split_and_decode (pars, 0, '\0\0,');
  ses := string_output ();
  graph := sioc..get_graph ();

  http ('sparql ', ses);
  http ('define input:inference <' || graph || '> \n', ses);
  http (sioc.DBA.std_pref_declare (), ses);
  http (sprintf ('\n construct { ?x ?y ?z } \n from <%s> where { \n', graph), ses);

  all_cnt := 1;
  qr := DB.DBA.FTI_MAKE_SEARCH_STRING (q);

  node := '{ ?x ?y ?z ; a %s . ?z bif:contains \'%S\' } \n union \n';
  foreach (any app in arr) do
    {
       if (lower (app) = 'people')
	 http (sprintf (node, 'sioc:User', qr), ses);
       else if (lower (app) = 'apps')
	 http (sprintf (node, 'sioc:Container', qr), ses);
       else if (lower (app) = 'weblog')
	 http (sprintf (node, 'sioct:BlogPost', qr), ses);
       else if (lower (app) = 'dav')
	 http (sprintf (node, 'foaf:Document', qr), ses);
       else if (lower (app) = 'feeds')
	 http (sprintf (node, 'atom:Entry', qr), ses);
       else if (lower (app) = 'wiki')
	 http (sprintf (node, 'wiki:Article', qr), ses);
       else if (lower (app) = 'mail')
	 http (sprintf (node, 'sioct:MailMessage', qr), ses);
       else if (lower (app) = 'bookmark')
	 http (sprintf (node, 'bm:Bookmark', qr), ses);
       else if (lower (app) = 'polls')
	 http (sprintf (node, 'sioct:Poll', qr), ses);
       else if (lower (app) = 'addressbook')
	 http (sprintf (node, 'vcard:vCard', qr), ses);
       else if (lower (app) = 'calendar')
	 {
	   http (sprintf (node, 'vcal:todo', qr), ses);
	   http (sprintf (node, 'vcal:vevent', qr), ses);
	 }
       else if (lower (app) = 'discussion')
	 http (sprintf (node, 'sioct:BoardPost', qr), ses);
       all_cnt := 0;
    }

  if (all_cnt)
    {
      http (sprintf (' ?x ?y ?z . ?z bif:contains \'%S\' ', qr), ses);
      tmp := ses;
    }
  else
    tmp := subseq (ses, 0, length (ses) - 9);

  return string_output_string (tmp) || '\n }';
}
;


create procedure ODS.DBA.search_do_rdf (
  in q varchar,
  in pars any,
  in lines any,
  in nrows int,
  in iri varchar := null)
{
  declare qr, ses, stat, msg, metas, rset any;
  declare accept, fmt varchar;

  accept := http_request_header (lines, 'Accept');
  if (not isstring (accept))
    accept := '';
  if (regexp_match ('(application/rdf.xml)|(text/rdf.n3)|(text/rdf.turtle)|(text/rdf.ttl)|(application/sparql-results+xml)', accept) is null)
    return 0;

  set http_charset='utf-8';
  declare exit handler for sqlstate '*'
    {
      stat := __SQL_STATE;
      msg := __SQL_MESSAGE;
      goto reporterr;
    };

  if (iri is null)
  qr := search_compose_qry (q, pars);
  else
    qr := search_compose_inst_qry (q, iri);
--  dbg_printf ('%s', qr);
  stat := '00000';
  if (nrows is null or nrows < 0)
    nrows := 0;
  exec (qr, stat, msg, vector (), 0, metas, rset);
  if (stat <> '00000')
    {
reporterr:
      http_status_set (500);
      http ('Error: %V', msg);
    }
  if (strstr (accept, 'application/rdf+xml') is not null)
    fmt := 'rdf';
  else if (strstr (accept, 'text/rdf+n3') is not null)
    fmt := 'n3';
  else if (strstr (accept, 'application/sparql-results+xml') is not null)
    fmt := 'sparql-results';
  else
    signal ('22023', 'Content type is not supported');
  ses := string_output ();
  if (fmt = 'rdf')
    sioc..rdf_head (ses);
  if (fmt = 'rdf')
    {
      declare triples any;
      if ((1 = length (rset)) and (1 = length (rset[0])) and (214 = __tag (rset[0][0])))
	{
	  triples := dict_list_keys (rset[0][0], 1);
	  DB.DBA.RDF_TRIPLES_TO_RDF_XML_TEXT (triples, 0, ses);
	}
    }
  else
    {
      DB.DBA.SPARQL_RESULTS_WRITE (ses, metas, rset, accept, 0);
    }
  if (fmt = 'rdf')
    sioc..rdf_tail (ses);
  if (fmt = 'n3')
    http_header ('Content-Type: text/rdf+n3\r\n');
  else if (fmt = 'sparql-results')
    http_header ('Content-Type: application/sparql-results+xml\r\n');
  else
    http_header ('Content-Type: application/rdf+xml\r\n');
  http_rewrite ();
  http (ses);
  return 1;
}
;

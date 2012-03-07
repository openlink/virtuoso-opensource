DB.DBA.EXEC_STMT ('create table FOAF_SSL_ACL (FS_URI varchar primary key, FS_UID varchar not null)', 0)
;

create procedure FOAF_SSL_QR (in gr varchar, in uri varchar)
{
    return sprintf ('sparql 
    define input:storage ""  
    prefix cert: <http://www.w3.org/ns/auth/cert#>  
    prefix rsa: <http://www.w3.org/ns/auth/rsa#>  
    select (str (?exp)) (str (?mod))  
    from <%S>  
    where 
    {  	  
      { ?id cert:identity <%S> ; rsa:public_exponent ?exp ; rsa:modulus ?mod .  } 	  
      union 
      { ?id cert:identity <%S> ; rsa:public_exponent ?exp1 ; rsa:modulus ?mod1 . ?exp1 cert:decimal ?exp . ?mod1 cert:hex ?mod . }  	  
      union 
      { <%S> cert:key ?key . ?key cert:exponent ?exp . ?key cert:modulus ?mod .  }        
    }', gr, uri, uri, uri);
}
;

create procedure FOAF_SSL_QR_BY_ACCOUNT (in gr varchar, in agent varchar)
{
  declare qr any;
  qr := sprintf (
        'sparql define input:storage "" '||
  	' prefix cert: <http://www.w3.org/ns/auth/cert#> prefix rsa: <http://www.w3.org/ns/auth/rsa#> ' ||
  	' select (str (bif:coalesce (?exp_val, ?exp))) (str (bif:coalesce (?mod_val, ?mod))) '||
	' from <%S> '||
  	' where { <%S> <http://xmlns.com/foaf/0.1/holdsAccount> ?acc . ?id cert:identity ?acc ; rsa:public_exponent ?exp ; rsa:modulus ?mod . '||
	' optional { ?exp cert:decimal ?exp_val . ?mod cert:hex ?mod_val . } } ',
	gr, agent);
  return qr;      
}
;

create procedure FOAF_SSL_WEBID_GET (in cert any := null, in cert_type int := 0)
{
  declare agent, alts any;
  agent := get_certificate_info (7, cert, cert_type, '', '2.5.29.17');
  if (agent is not null)
    {
      alts := regexp_replace (agent, ',[ ]*', ',', 1, null);
      alts := split_and_decode (alts, 0, '\0\0,:');
      if (alts is null)
	return null;
      agent := get_keyword ('URI', alts);
    }
  return agent;
}
;

create procedure FOAF_SSL_MAIL_GET (in cert any := null, in cert_type int := 0)
{
  declare alts, mail any;
  mail := get_certificate_info (10, cert, cert_type, '', 'emailAddress');
  if (mail is null)
    {
      alts := get_certificate_info (7, cert, cert_type, '', '2.5.29.17');
      if (alts is not null)
	{
	  alts := regexp_replace (alts, ',[ ]*', ',', 1, null);
	  alts := split_and_decode (alts, 0, '\0\0,:');
	  mail := get_keyword ('email', alts);
	}
    }
  return mail;
}
;


--
-- WHEN USE try_loading_webid must clear the graph named as webid
-- 
create procedure FOAF_SSL_WEBFINGER (in cert any := null, in try_loading_webid int := 0, in cert_type int := 0)
{
  declare mail, webid, domain, host_info, xrd, template, url any;
  declare xt, xd, tmpcert any;

  mail := FOAF_SSL_MAIL_GET (cert, cert_type);
  if (mail is null)
    return null;

  declare exit handler for sqlstate '*'
    {
      -- connection error or parse error
      return null;
    };

  domain := subseq (mail, position ('@', mail));
  host_info := http_get (sprintf ('http://%s/.well-known/host-meta', domain));
  xd := xtree_doc (host_info);
  template := cast (xpath_eval ('/XRD/Link[@rel="lrdd"]/@template', xd) as varchar);
  url := replace (template, '{uri}', 'acct:' || mail);
  xrd := http_get (url);
  xd := xtree_doc (xrd);
  xt := xpath_eval ('/XRD/Property[@type="certificate"]/@href', xd, 0);
  foreach (any x in xt) do
    {
      x := cast (x as varchar);
      tmpcert := http_get (x);
      if (get_certificate_info (6, cert, cert_type, '') = get_certificate_info (6, tmpcert, 0, ''))
	{
	  webid := null;
	  if (try_loading_webid)
	    {
	      declare hf, gr, graph, qr, stat, msg any;
	  webid := cast (xpath_eval ('/XRD/Property[@type="webid"]/@href', xd) as varchar);
	      hf := rfc1808_parse_uri (webid);
	      hf[5] := '';
	      gr := DB.DBA.vspx_uri_compose (hf);
	      graph := uuid ();
	      qr := sprintf ('sparql load <%S> into graph <%S>', gr, graph);
	      stat := '00000';
	      exec (qr, stat, msg);
	      commit work;
	      if (stat = '00000')
		return graph;
	      else
		return null;
	    }
	  return coalesce (webid, 'acct:' || mail);
	}
    }
  return null;
}
;

create procedure DB.DBA.FOAF_MOD (in m any)
{
  declare modulus any;
  modulus := lower (regexp_replace (m, '[^A-Z0-9a-f]', '', 1, null));	      
  --dbg_obj_print_vars (modulus);
  return modulus;
}
;

create procedure FOAF_SSL_AUTH (in realm varchar)
{
  return FOAF_SSL_AUTH_GEN (realm, 0);
}
;

create procedure WEBID_AUTH_GEN (in cert any, in ctype int, in realm varchar, in allow_nobody int := 0, in use_session int := 1)
{
  declare stat, msg, meta, data, info, qr, hf, graph, fing, gr, modulus, alts, dummy any;
  declare agent varchar;
  declare acc int;
  declare ret_code, done int;

  ret_code := 0;
  acc := 0;
  done := 0;
  declare exit handler for sqlstate '*'
    {
      rollback work;
      goto err_ret;
    }
  ;

  gr := uuid ();
  info := get_certificate_info (9, cert, ctype);
  fing := get_certificate_info (6, cert, ctype);
  agent := FOAF_SSL_WEBID_GET (cert, ctype);

  if (not isarray (info))
    return 0;
  if (agent is null)
    {
      agent := FOAF_SSL_WEBFINGER (cert, 0, ctype);
      if (agent is not null)
	{
	  goto authenticated;
	}
      else
	{
	  agent := ODS..FINGERPOINT_WEBID_GET (cert, null, ctype);
	}
    }
  if (agent is null)
    return 0;

  for select VS_UID from VSPX_SESSION where VS_SID = fing and VS_REALM = 'FOAF+SSL' do
    {
      connection_set ('SPARQLUserId', VS_UID);
      return 1;
    }

  if (agent like 'ldap://%' and DB.DBA.FOAF_SSL_LDAP_CHECK_CERT_INT (agent, cert, ctype, dummy))
    goto authenticated;

  hf := rfc1808_parse_uri (agent);
  hf[5] := '';
  graph := DB.DBA.vspx_uri_compose (hf);
  qr := sprintf ('sparql load <%S> into graph <%S>', graph, gr);
  stat := '00000';
  exec (qr, stat, msg);
  commit work;
  qr := FOAF_SSL_QR (gr, agent);    
  stat := '00000';
--  dbg_printf ('%s', qr);
  exec (qr, stat, msg, vector (), 0, meta, data);
  again_check:;
  if (stat = '00000' and length (data))
    {
      foreach (any _row in data) do
	{
	  if (_row[0] = cast (info[1] as varchar) and DB.DBA.FOAF_MOD (_row[1]) = bin2hex (info[2]))
    {
      declare arr, uid any;
	      authenticated:
	      uid := coalesce ((select FS_UID from FOAF_SSL_ACL where agent like FS_URI), 'nobody');
      if ('nobody' = uid and allow_nobody = 0)
	goto err_ret;
      connection_set ('SPARQLUserId', uid);
	      if (use_session)
      insert into VSPX_SESSION (VS_SID, VS_REALM, VS_UID, VS_EXPIRY) values (fing, 'FOAF+SSL', uid, now ());
      exec (sprintf ('sparql clear graph <%S>', gr), stat, msg);
      commit work;
      return 1;
    }
	}
    }
  else if (acc = 0)
    {
      qr := FOAF_SSL_QR_BY_ACCOUNT (gr, agent);
      stat := '00000';
      --  dbg_printf ('%s', qr);
      exec (qr, stat, msg, vector (), 0, meta, data);
      acc := 1;
      goto again_check;
    }
  err_ret:
--  dbg_obj_print (stat, data);
  exec (sprintf ('sparql clear graph <%S>', gr), stat, msg);
  commit work;
  {
    declare page, xt, xp varchar;
    declare exit handler for sqlstate '*'
      {
	goto ret;
      };
    page := http_client (url=>graph, n_redirects=>15);
    verify:
    xt := xtree_doc (page, 2);
    xp := xpath_eval ('string (.)', xt);
    xp := cast (xp as varchar);
    if (strstr (xp, '#SHA1') is not null)
      fing := get_certificate_info (6, cert, ctype, null, 'sha1');
    fing := replace (fing, ':', '');  
    if (strstr (xp, sprintf ('Fingerprint:%s', fing)) is not null)
      {
	ret_code := 1;
        goto ret;	
      }
    if (graph like 'http://twitter.com/%')
      {
	declare acco, arr, json, res any;
	arr := sprintf_inverse (graph, 'http://twitter.com/%s', 1);
	acco := arr[0];
        json := http_get (sprintf ('http://search.twitter.com/search.json?q=%%40Fingerprint%%3A%U%%20from%%3A%U', fing, acco));
	arr := json_parse (json);
        res := get_keyword ('results', arr);
	if (length (res) > 0)
	  {
	    ret_code := 1;
	    goto ret;	
	  }
	fing := get_certificate_info (6, cert, ctype, null, 'sha1');
	fing := replace (fing, ':', '');  
        json := http_get (sprintf ('http://search.twitter.com/search.json?q=%%40Fingerprint%%3A%U%%20from%%3A%U', fing, acco));
	arr := json_parse (json);
        res := get_keyword ('results', arr);
	if (length (res) > 0)
	  {
	    ret_code := 1;
	    goto ret;	
	  }
      }
    if (not done and graph like 'http://graph.facebook.com/%')
      {
	declare tok, og_id, tree, nick any;
	tree := json_parse (page);
	og_id := get_keyword ('id', tree);
	nick := get_keyword ('username', tree);
	tok := DB.DBA.OPENGRAPH_GET_ACCESS_TOKEN (og_id);
	if (tok is null)
	  goto ret;
	page := http_get (sprintf ('https://graph.facebook.com/%U/feed?access_token=%U', nick, tok));
	done := 1;
	goto verify;
      }
    if (not done and graph like 'http://%.linkedin.com/in/%')
      {
	declare oauth_keys, arr, opts, url, api_url, cnt any;
	declare consumer_key, consumer_secret, oauth_token, oauth_secret, person_id varchar;
	opts := (select RM_OPTIONS from DB..SYS_RDF_MAPPERS where RM_HOOK = 'DB.DBA.RDF_LOAD_LINKEDIN');
	oauth_keys := DB.DBA.LINKEDIN_GET_ACCESS_TOKEN (graph);
	oauth_token := oauth_keys[0];
	oauth_secret := oauth_keys[1];
	consumer_key := get_keyword ('consumer_key', opts);
	consumer_secret := get_keyword ('consumer_secret', opts);
	api_url := sprintf ('https://api.linkedin.com/v1/people/url=%U:(id)', graph);
	url := DB.DBA.sign_request ('GET', api_url, '', consumer_key, consumer_secret, oauth_token, oauth_secret, 1);
	cnt := http_get (url);
	xt := xtree_doc (cnt);
        person_id := cast (xpath_eval ('/person/id/text()', xt) as varchar);
	url := DB.DBA.sign_request ('GET', sprintf ('http://api.linkedin.com/v1/people/%s/network', person_id), 'type=SHAR&scope=self', consumer_key, consumer_secret, oauth_token, oauth_secret, 1);
	page := http_get (url);
	done := 1;
	goto verify;
      }
    exec (sprintf (
    'sparql define get:soft "soft" prefix opl: <http://www.openlinksw.com/schemas/cert#> select ?f ?dgst from <%S> { ?s opl:hasCertificate ?c . ?c opl:fingerprint ?f ; opl:fingerprint-digest ?dgst . }', 
    	graph), stat, msg, vector (), 0, meta, data);
    if (length (data))
     {
       foreach (any x in data) do
    	 {
	   declare fng, fng2 any;
	   fng := get_certificate_info (6, cert, ctype, null, x[1]);
	   fng := replace (fng, ':', '');  
	   fng2 := x[0];
	   fng2 := replace (fng2, ':', '');  
    	   if (fng2 = fng)
    	     {
    	       ret_code := 1;
    	       goto ret;
    	     }
    	 }
      }

  }
  ret:
  return ret_code;
}
;

create procedure FOAF_SSL_AUTH_GEN (in realm varchar, in allow_nobody int := 0, in use_session int := 1)
{
  declare cert any;
  cert := client_attr ('client_certificate');
  return WEBID_AUTH_GEN (cert, 0, realm, allow_nobody, use_session);
}
;

create procedure FOAF_CHECK_WEBID (in agent varchar)
{
  declare stat, msg, meta, data, info, qr, hf, graph, fing, gr any;
  declare acc int;
  acc := 0;

  declare exit handler for sqlstate '*'
    {
      rollback work;
      goto err_ret;
    }
  ;

  if (agent like 'ldap://%')
   return DB.DBA.FOAF_SSL_LDAP_CHECK (agent);

  hf := rfc1808_parse_uri (agent);
  hf[5] := '';
  graph := DB.DBA.vspx_uri_compose (hf);
  gr := uuid ();
  delete from DB.DBA.RDF_QUAD where G = DB.DBA.RDF_IID_OF_QNAME (gr);
  commit work;
  qr := sprintf ('sparql load <%S> into graph <%S>', graph, gr);
  stat := '00000';
  exec (qr, stat, msg);
  commit work;
  qr := FOAF_SSL_QR (gr, agent);    
  stat := '00000';
--  dbg_printf ('%s', qr);
  exec (qr, stat, msg, vector (), 0, meta, data);
  again_check:;
  if (stat = '00000' and length (data) and length (data[0][0]) and length (data[0][1]))
    {
      delete from DB.DBA.RDF_QUAD where G = DB.DBA.RDF_IID_OF_QNAME (gr);
      commit work;
      return 1;
    }
  else if (acc = 0)
    {
      qr := FOAF_SSL_QR_BY_ACCOUNT (gr, agent);
      stat := '00000';
      --  dbg_printf ('%s', qr);
      exec (qr, stat, msg, vector (), 0, meta, data);
      acc := 1;
      goto again_check;
    }
  err_ret:
  delete from DB.DBA.RDF_QUAD where G = DB.DBA.RDF_IID_OF_QNAME (gr);
--  dbg_obj_print (stat, data);
  commit work;
  return 0;
}
;

DB.DBA.VHOST_REMOVE (vhost=>'*sslini*', lhost=>'*sslini*', lpath=>'/sparql-ssl');
DB.DBA.VHOST_DEFINE (vhost=>'*sslini*', lhost=>'*sslini*', lpath=>'/sparql-ssl',
    ppath => '/!sparql/', is_dav => 1, vsp_user => 'dba', opts => vector('noinherit', 1), auth_fn=>'DB.DBA.FOAF_SSL_AUTH');

create procedure FOAF_SSL_AUTH_ACL (in acl varchar, in realm varchar)
{
  declare stat, msg, meta, data, info, qr, hf, graph, fing, gr, modulus, alts any;
  declare agent varchar;
  declare acc, rc, wf int;
  acc := 0;
  rc := 0;
  wf := 0;  -- authenticated via webfinger
  declare exit handler for sqlstate '*'
    {
      rollback work;
      goto err_ret;
    }
  ;

  info := get_certificate_info (9);
  fing := get_certificate_info (6);
  agent := FOAF_SSL_WEBID_GET ();

  if (not isarray (info) or agent is null)
    return 0;
  if (agent is null)
    {
      agent := FOAF_SSL_WEBFINGER ();
      wf := 1;
    }
  if (agent is null)
    return 0;

  if (http_acl_get (acl, agent, '*') <> 0)
    {
      return 0;
    }

  for select VS_UID from VSPX_SESSION where VS_SID = fing and VS_REALM = realm do
    {
      return 1;
    }

  gr := uuid ();

  if (wf) 
    goto authenticated;

  hf := rfc1808_parse_uri (agent);
  hf[5] := '';
  graph := DB.DBA.vspx_uri_compose (hf);
  qr := sprintf ('sparql load <%S> into graph <%S>', graph, gr);
  stat := '00000';
  exec (qr, stat, msg);
  commit work;
  qr := FOAF_SSL_QR (gr, agent);    
  stat := '00000';
  exec (qr, stat, msg, vector (), 0, meta, data);
  again_check:; 
  if (stat = '00000' and length (data)) 
    {
      foreach (any _row in data) do
        {
	  if (_row [0] = cast (info[1] as varchar) and DB.DBA.FOAF_MOD (_row [1]) = bin2hex (info[2]))
    {
	      authenticated:
      insert into VSPX_SESSION (VS_SID, VS_REALM, VS_UID, VS_EXPIRY) values (fing, realm, 'nobody', now ());
      rc := 1;
      goto err_ret;
    }
	}
    }
  else if (acc = 0)
    {
      qr := FOAF_SSL_QR_BY_ACCOUNT (gr, agent);
      stat := '00000';
      exec (qr, stat, msg, vector (), 0, meta, data);
      acc := 1;
      goto again_check;
    }
  err_ret:
  exec (sprintf ('sparql clear graph <%S>', gr), stat, msg);
  commit work;
  return rc;
}
;

create procedure DB.DBA.FOAF_SSL_LDAP_CHECK (in agent varchar := null)
{
  declare dummy any;
  return DB.DBA.FOAF_SSL_LDAP_CHECK_INT (agent, dummy);
}
;

create procedure DB.DBA.FOAF_SSL_LDAP_CHECK_INT (in agent varchar := null, out data any)
{
  return DB.DBA.FOAF_SSL_LDAP_CHECK_CERT_INT (agent, null, 0, data);
}
;

create procedure DB.DBA.FOAF_SSL_LDAP_CHECK_CERT_INT (in agent varchar := null, in incert any := null, in incert_type int := 0, out data any)
{
  declare host, str, ss varchar;
  declare arr, rc, cert, res any;
  declare i int;
  res := 0;
  data := null;
  if (incert is null)
    incert := client_attr ('client_certificate');
  if (agent is null)
    agent := FOAF_SSL_WEBID_GET (incert, incert_type);
  if (agent is null or agent not like 'ldap://%')
    goto failed;
  arr := sprintf_inverse (agent, 'ldap://%s/%s', 1);
  if (length (arr) <> 2) 
    goto failed;
  host := arr[0];
  if (strchr (host, ':') is null)
    host := host || ':389';
  host := 'ldap://' || host;
  arr[1] := replace (arr[1], '%2C', ',');
  str := split_and_decode (arr[1], 0, '%+,=');
  ss := '(&';
  for (i := 0; i < length (str); i := i + 2)
    {
      ss := ss || sprintf ('(%s=%s)', str[i], str[i+1]);
    }
  ss := ss || ')';
  for select * from SYS_LDAP_SERVERS where LS_ADDRESS = host do
    {
      declare exit handler for sqlstate '*' { goto failed; };
      rc := ldap_search (host, LS_TRY_SSL, LS_BASE, ss, sprintf('%s=%s, %s', LS_UID_FLD, LS_ACCOUNT, LS_BIND_DN), LS_PASSWORD);
      if (isvector (rc) and length (rc) > 1)
        {	
          cert := get_keyword ('userCertificate;binary', rc[1]);
          if (isvector (cert) and length (cert) and get_certificate_info (6, incert, incert_type) = get_certificate_info (6, cert[0], 1))
	    {
	    res := 1;
	      data := rc;
	    }
        }
    }
failed:
  return res;
}
;

DB.DBA.EXEC_STMT ('create table FOAF_SSL_ACL (FS_URI varchar primary key, FS_UID varchar not null)', 0)
;

create procedure FOAF_SSL_QR (in gr varchar, in agent varchar)
{
  declare qr any;
  qr := sprintf (
        'sparql define input:storage "" '||
	' prefix cert: <http://www.w3.org/ns/auth/cert#> '||
	' prefix rsa: <http://www.w3.org/ns/auth/rsa#> ' ||
  	' select (str (bif:coalesce (?exp_val, ?exp))) (str (bif:coalesce (?mod_val, ?mod))) '||
	' from <%S> '||
  	' where { '||
	' 	  ?id cert:identity <%S> ; rsa:public_exponent ?exp ; rsa:modulus ?mod . ' ||
	' 	  optional { ?exp cert:decimal ?exp_val . ?mod cert:hex ?mod_val . } '||
	'       } ',
	gr, agent);
  return qr;      
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

create procedure FOAF_SSL_WEBID_GET (in cert any := null)
{
  declare agent, alts any;
  agent := get_certificate_info (7, cert, 0, '', '2.5.29.17');
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

create procedure FOAF_SSL_MAIL_GET (in cert any := null)
{
  declare alts, mail any;
  mail := get_certificate_info (10, cert, 0, '', 'emailAddress');
  if (mail is null)
    {
      alts := get_certificate_info (7, cert, 0, '', '2.5.29.17');
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
create procedure FOAF_SSL_WEBFINGER (in cert any := null, in try_loading_webid int := 0)
{
  declare mail, webid, domain, host_info, xrd, template, url any;
  declare xt, xd, tmpcert any;

  mail := FOAF_SSL_MAIL_GET (cert);
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
      if (get_certificate_info (6, cert, 0, '') = get_certificate_info (6, tmpcert, 0, ''))
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

create procedure FOAF_SSL_AUTH_GEN (in realm varchar, in allow_nobody int := 0)
{
  declare stat, msg, meta, data, info, qr, hf, graph, fing, gr, modulus, alts any;
  declare agent varchar;
  declare acc int;
  acc := 0;
  declare exit handler for sqlstate '*'
    {
      rollback work;
      goto err_ret;
    }
  ;

  gr := uuid ();
  info := get_certificate_info (9);
  fing := get_certificate_info (6);
  agent := FOAF_SSL_WEBID_GET ();

  if (not isarray (info))
    return 0;
  if (agent is null)
    {
      agent := FOAF_SSL_WEBFINGER ();
      if (agent is not null)
	{
	  goto authenticated;
	}
      else
	{
	  agent := ODS..FINGERPOINT_WEBID_GET ();
	}
    }
  if (agent is null)
    return 0;

  for select VS_UID from VSPX_SESSION where VS_SID = fing and VS_REALM = 'FOAF+SSL' do
    {
      connection_set ('SPARQLUserId', VS_UID);
      return 1;
    }
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
      uid := coalesce ((select FS_UID from FOAF_SSL_ACL where FS_URI = agent), 'nobody');
      if ('nobody' = uid and allow_nobody = 0)
	goto err_ret;
      connection_set ('SPARQLUserId', uid);
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
  exec (sprintf ('sparql clear graph <%S>', gr), stat, msg);
  commit work;
--  dbg_obj_print (stat, data);
  return 0;
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

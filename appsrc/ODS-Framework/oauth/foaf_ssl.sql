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
  declare stat, msg, meta, data, info, qr, hf, graph, fing, gr, modulus any;
  declare agent varchar;
  declare acc int;
  acc := 0;

  declare exit handler for sqlstate '*'
    {
      rollback work;
      goto err_ret;
    }
  ;

  info := get_certificate_info (9);
  fing := get_certificate_info (6);
  agent := get_certificate_info (7, null, null, null, '2.5.29.17');

  if (not isarray (info) or agent is null or agent not like 'URI:%')
    return 0;

  agent := subseq (agent, 4);

  for select VS_UID from VSPX_SESSION where VS_SID = fing and VS_REALM = 'FOAF+SSL' do
    {
      connection_set ('SPARQLUserId', VS_UID);
      return 1;
    }

  hf := rfc1808_parse_uri (agent);
  hf[5] := '';
  gr := uuid ();
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
  if (stat = '00000' and length (data) and data[0][0] = cast (info[1] as varchar) and DB.DBA.FOAF_MOD (data[0][1]) = bin2hex (info[2]))
    {
      declare arr, uid any;
      uid := coalesce ((select FS_UID from FOAF_SSL_ACL where FS_URI = agent), 'nobody');
      if ('nobody' = uid and allow_nobody = 0)
	goto err_ret;
      connection_set ('SPARQLUserId', uid);
      insert into VSPX_SESSION (VS_SID, VS_REALM, VS_UID, VS_EXPIRY) values (fing, 'FOAF+SSL', uid, now ());
      exec (sprintf ('sparql clear graph <%S>', gr), stat, msg);
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
  declare stat, msg, meta, data, info, qr, hf, graph, fing, gr, modulus any;
  declare agent varchar;
  declare acc, rc int;
  acc := 0;
  rc := 0;
  declare exit handler for sqlstate '*'
    {
      rollback work;
      goto err_ret;
    }
  ;

  info := get_certificate_info (9);
  fing := get_certificate_info (6);
  agent := get_certificate_info (7, null, null, null, '2.5.29.17');

  if (not isarray (info) or agent is null or agent not like 'URI:%')
    return 0;

  agent := subseq (agent, 4);

  if (http_acl_get (acl, agent, '*') <> 0)
    {
      return 0;
    }

  for select VS_UID from VSPX_SESSION where VS_SID = fing and VS_REALM = realm do
    {
      return 1;
    }

  hf := rfc1808_parse_uri (agent);
  hf[5] := '';
  gr := uuid ();
  graph := DB.DBA.vspx_uri_compose (hf);
  qr := sprintf ('sparql load <%S> into graph <%S>', graph, gr);
  stat := '00000';
  exec (qr, stat, msg);
  commit work;
  qr := FOAF_SSL_QR (gr, agent);    
  stat := '00000';
  exec (qr, stat, msg, vector (), 0, meta, data);
  again_check:; 
  if (stat = '00000' and length (data) and data[0][0] = cast (info[1] as varchar) and DB.DBA.FOAF_MOD (data[0][1]) = bin2hex (info[2]))
    {
      insert into VSPX_SESSION (VS_SID, VS_REALM, VS_UID, VS_EXPIRY) values (fing, realm, 'nobody', now ());
      rc := 1;
      goto err_ret;
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

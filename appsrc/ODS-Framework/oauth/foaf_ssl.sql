DB.DBA.EXEC_STMT ('create table FOAF_SSL_ACL (FS_URI varchar primary key, FS_UID varchar not null)', 0)
;

create procedure FOAF_SSL_AUTH (in realm varchar)
{
  declare stat, msg, meta, data, info, qr, hf, graph, fing, gr any;
  declare agent varchar;

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

  for select VS_UID from VSPX_SESSION where VS_SID = fing and VS_REALM = 'foaf+ssl' do
    {
      connection_set ('SPARQLUserId', VS_UID);
      return 1;
    }

  hf := rfc1808_parse_uri (agent);
  hf[5] := '';
  gr := uuid ();
  graph := DB.DBA.vspx_uri_compose (hf);
  delete from DB.DBA.RDF_QUAD where G = DB.DBA.RDF_IID_OF_QNAME (gr);
  commit work;
  qr := sprintf ('sparql load <%S> into graph <%S>', graph, gr);
  stat := '00000';
  exec (qr, stat, msg);
  commit work;
  qr := sprintf ('sparql prefix cert: <http://www.w3.org/ns/auth/cert#> prefix rsa: <http://www.w3.org/ns/auth/rsa#> ' ||
  	'select ?exp_val ?mod_val from <%S> '||
  	' where { ?id cert:identity <%S> ; rsa:public_exponent ?exp ; rsa:modulus ?mod . ?exp cert:decimal ?exp_val . ?mod cert:hex ?mod_val . }',
	gr, agent);
  stat := '00000';
--  dbg_printf ('%s', qr);
  exec (qr, stat, msg, vector (), 0, meta, data);
  if (stat = '00000' and length (data) and data[0][0] = cast (info[1] as varchar) and data[0][1] = bin2hex (info[2]))
    {
      declare arr, uid any;
      whenever not found goto err_ret;
      select FS_UID into uid from FOAF_SSL_ACL where FS_URI = agent;
      connection_set ('SPARQLUserId', uid);
      insert into VSPX_SESSION (VS_SID, VS_REALM, VS_UID, VS_EXPIRY) values (fing, 'foaf+ssl', uid, now ());
      delete from DB.DBA.RDF_QUAD where G = DB.DBA.RDF_IID_OF_QNAME (gr);
      commit work;
      return 1;
    }
  err_ret:
  delete from DB.DBA.RDF_QUAD where G = DB.DBA.RDF_IID_OF_QNAME (gr);
  commit work;
--  dbg_obj_print (stat, data);
  return 0;
}
;

create procedure FOAF_CHECK_WEBID (in agent varchar)
{
  declare stat, msg, meta, data, info, qr, hf, graph, fing, gr any;

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
  qr := sprintf ('sparql prefix cert: <http://www.w3.org/ns/auth/cert#> prefix rsa: <http://www.w3.org/ns/auth/rsa#> ' ||
  	'select ?exp_val ?mod_val from <%S> '||
  	' where { ?id cert:identity <%S> ; rsa:public_exponent ?exp ; rsa:modulus ?mod . ?exp cert:decimal ?exp_val . ?mod cert:hex ?mod_val . }',
	gr, agent);
  stat := '00000';
--  dbg_printf ('%s', qr);
  exec (qr, stat, msg, vector (), 0, meta, data);
  if (stat = '00000' and length (data) and length (data[0][0]) and length (data[0][1]))
    {
      delete from DB.DBA.RDF_QUAD where G = DB.DBA.RDF_IID_OF_QNAME (gr);
      commit work;
      return 1;
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

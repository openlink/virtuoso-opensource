use ODS;

create procedure ODS.ODS_API."salmon_endpoint" () __SOAP_HTTP 'text/plain'
{
  declare body, xt, msg, sig, enc, orig, alg, data_type, m, ks, rc any;

  set_user_id ('dba');
  body := http_param ('content');
  if (body = 0)
    body := http_body_read ();
  if (length (body) = 0)
    body := http_param ('magic_env');  
  xt := xtree_doc (body);
  msg := cast (xpath_eval ('/env/data', xt) as varchar);
  data_type := cast (xpath_eval ('/env/data/@type', xt) as varchar);
  enc := cast (xpath_eval ('/env/encoding', xt) as varchar);
  sig := cast (xpath_eval ('/env/sig', xt) as varchar);
  alg := cast (xpath_eval ('/env/alg', xt) as varchar);
  orig := msg;
  orig := regexp_replace (orig, '[^A-Za-z0-9\\-_=]', '', 1, null);
  sig  := regexp_replace (sig, '[^A-Za-z0-9\\-_=]', '', 1, null);
  --dbg_obj_print_vars (enc, sig, alg, data_type, orig);
  if (enc <> 'base64url')
    signal ('SALM0', 'Encoding is not supported');
  if (alg <> 'RSA-SHA256')
    signal ('SALM0', 'Signing Algorithm is not supported');
  -- get the key
  msg := decode_base64 (replace (replace (msg, '-', '+'), '_', '/'));
  --k := ods..sp_decode_rsa_key ('data:application/magic-public-key,RSA.mVgY8RN6URBTstndvmUUPb4UZTdwvwmddSKE5z_jvKUEK6yk1u3rrC9yN8k6FilGj9K0eeUPe2hf4Pj-5CmHww.AQAB');    
  --k := ods..sp_decode_rsa_key ('data:application/magic-public-key,RSA.mVgY8RN6URBTstndvmUUPb4UZTdwvwmddSKE5z_jvKUEK6yk1u3rrC9yN8k6FilGj9K0eeUPe2hf4Pj-5CmHww==.AQAB.Lgy_yL3hsLBngkFdDw1Jy9TmSRMiH6yihYetQ8jy-jZXdsZXd8V5ub3kuBHHk4M39i3TduIkcrjcsiWQb77D8Q==');
  --m := concat (orig, '.', sp_base64url (data_type), '.', sp_base64url (enc), '.', sp_base64url (alg)); 
  m := orig;
  ks := sp_webfinger_users_keys (msg);
  rc := 0;
  foreach (any k in ks) do
    {
--      dbg_obj_print (k);
      --dbg_obj_print_vars (m, k, xenc_dsig_sign (m, k, sp_meth ('rsa-sha256')), sig);
      if (xenc_dsig_verify (m, k, sp_meth ('rsa-sha256'), replace (replace (sig, '-', '+'), '_', '/')))
	{
	  rc := 1;
	  goto endc;
	}
    }
  endc:
  foreach (any k in ks) do
    {
      xenc_key_remove (k);
    }
  if (not rc)
    signal ('SALM1', 'Invalid signature');
  --dbg_obj_print_vars (msg);
  sp_process_message (msg);
  return msg;
}
;

create procedure sp_process_message (in msg varchar)
{
  declare xt, xp, arr, mail, graph, uname, uid, content any;
  xt := xtree_doc (msg);
  xp := cast (xpath_eval ('/entry/link[@rel="salmon"]/@href', xt) as varchar);
  if (xp is not null) -- mention
    {
      arr :=  WS.WS.PARSE_URI (xp);
      mail := arr[2];
      graph := sioc..get_graph ();
      uname := (select top 1 U_NAME from DB.DBA.SYS_USERS where U_E_MAIL = mail order by U_ID);
      if (uname is null)
	{
	  uname := (sparql define input:storage "" 
	  prefix owl: <http://www.w3.org/2002/07/owl#> 
	  prefix foaf: <http://xmlns.com/foaf/0.1/> 
	  select ?nick 
	  where { graph `iri(?:graph)` { ?s owl:sameAs `iri(?:xp)` ; foaf:nick ?nick . }});
	}
      if (uname is null)
	signal ('22023', sprintf ('The user account "%s" does not exist', xp));
      uid := (select U_ID from DB.DBA.SYS_USERS where U_NAME = uname);
      content := cast (xpath_eval ('/entry/content', xt) as varchar);
      insert into DB.DBA.WA_MESSAGES (WM_SENDER_UID, WM_RECIPIENT_UID, WM_TS, WM_MESSAGE, WM_SENDER_MSGSTATUS, WM_RECIPIENT_MSGSTATUS)
	   values (http_dav_uid (), uid, now(), content, 0, 0);
--      dbg_obj_print (uname);
      return;
    }
  xp := trim (cast (xpath_eval ('/entry/in-reply-to', xt) as varchar), ' \t\n\r');
--  dbg_obj_print_vars (xp);
  if (xp is not null and xp like 'http://%/dataspace/%/weblog/%/%')
    {
      declare postid, uri, name, comment, title, rc varchar;
      arr := sprintf_inverse (xp, 'http://%s/dataspace/%s/weblog/%s/%s', 0);
      postid := arr [3];
      name := cast (xpath_eval ('/entry/author/name', xt) as varchar);
      uri  := cast (xpath_eval ('/entry/author/uri', xt) as varchar);
      mail := '';
      arr :=  WS.WS.PARSE_URI (uri);
      if (arr[0] = '')
	uri := 'acct:' || arr[2];
      title  := cast (xpath_eval ('/entry/title', xt) as varchar);
      comment  := cast (xpath_eval ('/entry/content', xt) as varchar);
      rc := ODS.ODS_API."weblog.comment.new" (postid, title, name, mail, uri, comment);
--      dbg_obj_print_vars (postid, title, name, uri, comment, rc);
    }
}
;

create procedure sp_template ()
{
  declare ses any;
  ses := string_output ();
  http('<?xml version=\'1.0\' encoding=\'UTF-8\'?>\n', ses);
  http('<me:env xmlns:me=\'http://salmon-protocol.org/ns/magic-env\'>\n', ses);
  http('  <me:data type=\'application/atom+xml\'>\n', ses);
  http('%s\n', ses);
  http('  </me:data>\n', ses);
  http('  <me:encoding>base64url</me:encoding>\n', ses);
  http('  <me:alg>RSA-SHA256</me:alg>\n', ses);
  http('  <me:sig>', ses); http('%s', ses); http('</me:sig>\n', ses);
  http('</me:env>\n', ses);
  return string_output_string (ses);
}
;

create procedure sp_sign (in msg varchar, in uname varchar)
{
  declare m, s, k, x varchar;
  k := (select WAUI_SALMON_KEY from DB.DBA.WA_USER_INFO, DB.DBA.SYS_USERS where WAUI_U_ID = U_ID and U_NAME = uname);
  if (k is null)
    signal ('22023', 'Cannot find key to sign');
  x := encode_base64 (msg);
  x := replace (x, '/', '_');
  x := replace (x, '+', '-');
  m := regexp_replace (x, '[^A-Za-z0-9\\-_=]', '', 1, null);
  set_user_id (uname);
  set_qualifier ('ODS');
  s := xenc_dsig_sign (m, k, sp_meth ('rsa-sha256'));
  msg := sprintf (sp_template (), x, replace (replace (s, '/', '_'), '+', '-'));
  return msg;
}
;

create procedure sp_webfinger_users_keys (in x any)
{
  declare ret, xrd, acct any;
  
  acct := cast (xpath_eval ('/entry/author/uri', xtree_doc (x)) as varchar);
  xrd := WF_USER_XRD_GET (acct);
  ret := sp_load_rsa_keys (xrd);
  return ret;
}
;

create procedure sp_meth (in x any)
{
  return concat ('http://www.w3.org/2000/09/xmldsig#', x);
}
;

create procedure sp_base64url (in x any)
{
  x := encode_base64 (x);
  x := replace (x, '/', '_');
  x := replace (x, '+', '-');
  x := regexp_replace (x, '[^A-Za-z0-9\\-_=]', '', 1, null);
  return x;
}
;

create procedure sp_decode_base64url (in x any)
{
  x := replace (x, '_', '/');
  x := replace (x, '-', '+');
  return decode_base64 (x);
}
;

create procedure sp_decode_rsa_key (in x any)
{
  declare a, n, kr any;
  a := null;
  n := null;
  if (x like 'data:application/magic-public-key,RSA.%.%.%')
    a := sprintf_inverse (x, 'data:application/magic-public-key,RSA.%s.%s.%s', 0);
  else if (x like 'data:application/magic-public-key,RSA.%.%')
    a := sprintf_inverse (x, 'data:application/magic-public-key,RSA.%s.%s', 0);
--  dbg_obj_print_vars (a);  
  kr := xenc_rand_bytes (8, 1);
  if (length (a) = 2)
    n := xenc_key_RSA_construct (kr, sp_decode_base64url (a[0]), sp_decode_base64url (a[1]));
  else if (length (a) = 3)
    n := xenc_key_RSA_construct (kr, sp_decode_base64url (a[0]), sp_decode_base64url (a[1]), sp_decode_base64url (a[2]));
  return n;
}
;

create procedure sp_load_rsa_keys (in x any)
{
  declare xd, xp, ret, n any;
  
  if (isstring (x))
    xd := xtree_doc (x);
  else
    xd := x;
  xp := xpath_eval ('//*[@rel="magic-public-key"]/@href', xd, 0);
--  dbg_obj_print (xp);
  vectorbld_init (ret);
  foreach (any e in xp) do
    {
      n := sp_decode_rsa_key (cast (e as varchar));
      if (n is not null)
	vectorbld_acc (ret, n);
    }
  if (is_https_ctx ())
    {
      declare k, kn any;
      k := client_attr ('client_certificate');
      if (k is not null)
	{ 
	  kn := xenc_rand_bytes (8, 1);
	  xenc_key_create_cert (kn, k, 'X.509');
	  vectorbld_acc (ret, kn);
	}
    } 
  vectorbld_final (ret);
  return ret;
}
;

create procedure sp_send_all_mentioned (in sender varchar, in refid varchar, in msg varchar)
{
  declare xt, xp any;
  xt := xtree_doc (msg, 2);
  xp := xpath_eval ('//a[not (img)]/@href', xt, 0);
  foreach (any x in xp) do
    {
      x := cast (x as varchar);
      if (x like 'mailto:%' or x like 'acct:%')
	{
	  declare exit handler for sqlstate '*' { goto next; };
	  sp_message_mention (sender, x, refid, msg);
	  next:;
	}
    }
}
;

create procedure sp_message_mention (in sender varchar, in acct varchar, in refid varchar, in msg varchar)
{
  declare ses any;
  declare sender_name, sender_email, ep, m, xrd varchar;

  xrd := WF_USER_XRD_GET (acct);
  ep := cast (xpath_eval ('/XRD/Link[@rel="salmon"]/@href', xrd) as varchar);

  for select U_FULL_NAME, U_E_MAIL from DB.DBA.SYS_USERS where U_NAME = sender do
    {
      sender_name := coalesce (U_FULL_NAME, sender); 
      sender_email := U_E_MAIL;
    }
  ses := string_output ();
  http ('<entry xmlns="http://www.w3.org/2005/Atom">\n', ses);
  http ('    <author>\n', ses);
  http ('      <name>%V</name>\n', ses);
  http ('      <uri>%V</uri>\n', ses);
  http ('    </author>\n', ses);
  http ('    <id>%V</id>\n', ses);
  http ('    <link rel="salmon" href="%V" />\n', ses); 
  -- XXX: for reply message
  --http ('    <updated>%V</updated>', ses);
  --http ('    <thr:in-reply-to xmlns:thr="http://purl.org/syndication/thread/1.0" ref="%V"/>', ses);
  --http ('    <title>%V</title>', ses);
  http ('    <content>%V</content>\n', ses);
  http ('</entry>\n', ses);
  ses := string_output_string (ses);
  m := sprintf (ses, sender_name, sender_email, refid, acct, msg);
  return sp_client (ep, m, sender);
}
;

create procedure sp_client (in ep varchar, in msg varchar, in uid varchar)
{
  declare ret any;
  commit work;
  ret := http_get (ep, null, 'GET', 'Content-Type: application/magic-envelope+xml', ods..sp_sign (msg, uid));
  return ret;
}
;

grant execute on ODS.ODS_API."salmon_endpoint" to ODS_API;

DB.DBA.VHOST_REMOVE (lpath=>'/ods/salmon');
DB.DBA.VHOST_DEFINE (lpath=>'/ods/salmon', ppath=>'/SOAP/Http/salmon_endpoint', soap_user=>'ODS_API');

use DB;

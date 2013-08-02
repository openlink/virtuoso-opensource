DB.DBA.EXEC_STMT ('create table FOAF_SSL_ACL (FS_URI varchar, FS_UID varchar not null,
      FS_TYPE int default 0, FS_REALM varchar, FS_APP_DATA any, FS_PRIORITY int default 0, primary key (FS_REALM, FS_URI))', 0)
;

create procedure webid_add_col (in tbl varchar, in col varchar, in coltype varchar)
{
  if (exists (select top 1 1 from DB.DBA.SYS_COLS where upper("TABLE") = upper(tbl) and upper("COLUMN") = upper(col))) 
    return;
  exec (sprintf ('alter table %s add column %s %s', tbl, col, coltype));
}
;

webid_add_col ('DB.DBA.FOAF_SSL_ACL', 'FS_TYPE', 'int default 0');
webid_add_col ('DB.DBA.FOAF_SSL_ACL', 'FS_REALM', 'varchar');
webid_add_col ('DB.DBA.FOAF_SSL_ACL', 'FS_APP_DATA', 'any');
webid_add_col ('DB.DBA.FOAF_SSL_ACL', 'FS_PRIORITY', 'int default 0');
update DB.DBA.FOAF_SSL_ACL set FS_REALM = 'GENERIC' where FS_REALM is null;
DB.DBA.EXEC_STMT ('alter table SPARQL_WEBID_ACL drop foreign key (SWA_RULE) references DB.DBA.FOAF_SSL_ACL (FS_URI)', 0);
DB.DBA.EXEC_STMT ('alter table DB.DBA.FOAF_SSL_ACL modify primary key (FS_REALM, FS_URI)', 0);

exec_quiet ('create table SPARQL_WEBID_ACL (SWA_RULE varchar, SWA_REALM varchar,
    SWA_ID int, SWA_PROP varchar, SWA_OP varchar, SWA_VAL varchar, SWA_QUERY varchar, 
    primary key (SWA_RULE, SWA_REALM, SWA_ID))');
webid_add_col ('DB.DBA.SPARQL_WEBID_ACL', 'SWA_REALM', 'varchar');
update DB.DBA.SPARQL_WEBID_ACL set SWA_REALM = 'GENERIC' where SWA_REALM is null;
DB.DBA.EXEC_STMT ('alter table DB.DBA.SPARQL_WEBID_ACL modify primary key (SWA_RULE, SWA_REALM, SWA_ID)', 0);

--!
-- \ingroup ods_devel_api
--
-- \brief Get the SQL user accociated with a WebID.
--
-- In ODS each WebID needs to be accociated with an SQL user. This method handles the
-- mapping.
--
-- \param webID The WebID URI to translate to an SQL user.
-- \param createMode If 1 a new SQL user will be created and accociated with the given
-- WebID if it does not exist yet.
--
-- \return The SQL user account name accociated with the given WebID or an empty string
-- if it does not exist and was not requested to be created.
--
-- FIXME: what about owl_sameAs WebIDs? What if I set a WebID as my owl:sameAs that already
-- has an accociated SQL user?
--/
create procedure FOAF_WEBID_USER (
  inout webID varchar,
  inout createMode integer := 0)
{
  declare uid varchar;

  uid := (select FS_UID from DB.DBA.FOAF_SSL_ACL where FS_URI = webID);
  if (createMode and isnull (uid))
  {
    uid := sprintf ('SPUID%d', sequence_next ('__SPUID'));
    USER_CREATE (uid, uuid());
    USER_GRANT_ROLE (uid, 'SPARQL_SELECT');
    USER_SET_OPTION (uid, 'DISABLED', 1);
    insert into DB.DBA.FOAF_SSL_ACL (FS_URI, FS_UID)
      values (webID, uid);
  }
  return uid;
}
;

create procedure WEBID_CERT_PROPS (in cert any)
{
  declare x, valid_from, valid_to, exp any;

  valid_from := X509_STRING_DATE (get_certificate_info (4, cert));
  valid_to := X509_STRING_DATE (get_certificate_info (5, cert));
  exp := 0;
  if (valid_to < now () or valid_from > now ())
    exp := 1;
  x := vector (
      'webIDVerified', 1,
      'certExpiration', exp, 
      'certSerial', get_certificate_info (1, cert),
      'webID', FOAF_SSL_WEBID_GET_ALL (cert),          
      'certMail', get_certificate_info (10, cert, 0, null, 'emailAddress'),      
      'certSubject', get_certificate_info (2, cert),    
      'certIssuer' , get_certificate_info (3, cert),    
      'certStartDate', valid_from, 
      'certEndDate', valid_to,    
      'certDigest', get_certificate_info (6, cert),     
      'certSparqlASK', 'query'  
      );
   return x;
};

create procedure WEBID_GEN_ACL_PROC (in rule varchar, in realm varchar := null)
{
  declare s, ops, op, exp any;

  if (realm is null)
    realm := 'GENERIC';

  ops := vector (
    'eq'           , '(^{value}^ = ^{pattern}^)',
    'neq'          , '(^{value}^ <> ^{pattern}^)',
    'lt'           , '(^{value}^ < ^{pattern}^)',
    'lte'          , '(^{value}^ <= ^{pattern}^)',
    'gt'           , '(^{value}^ > ^{pattern}^)',
    'gte'          , '(^{value}^ >= ^{pattern}^)',
    'contains'     , '(bif:isnull (bif:strstr (bif:ucase (^{value}^), bif:ucase (^{pattern}^))) = 0)',
    'notContains'  , '(bif:isnull (bif:strstr (bif:ucase (^{value}^), bif:ucase (^{pattern}^))) = 1)',
    'startsWith'   , '(bif:starts_with (bif:ucase (^{value}^), bif:ucase (^{pattern}^)) = 1)',
    'notStartsWith', '(bif:starts_with (bif:ucase (^{value}^), bif:ucase (^{pattern}^)) = 0)',
    'endsWith'     , '(bif:ends_with (bif:ucase (^{value}^), bif:ucase (^{pattern}^)) = 1)',
    'notEndsWith'  , '(bif:ends_with (bif:ucase (^{value}^), bif:ucase (^{pattern}^)) = 0)',
    'isNull'       , '(DB.DBA.is_empty_or_null (^{value}^) = 1)',
    'isNotNull'    , '(DB.DBA.is_empty_or_null (^{value}^) = 0)'
  );
  s := string_output ();
  http (sprintf ('create procedure "WEBID_ACL_CHECK__%s_%s" (in cert any, in graph any) { ', rule, realm), s);
  http ('\n', s);
  http (sprintf (' declare val, vals, webid, rc any;'), s);
  http ('\n', s);
  http (sprintf (' vals := WEBID_CERT_PROPS (cert);'), s);
  http ('\n', s);
  for select * from SPARQL_WEBID_ACL where SWA_RULE = rule do
    {
      if (SWA_PROP = 'certSparqlASK')
	{
	  op := SWA_QUERY;
	  http (sprintf ('\n-- rule %d\n', SWA_ID), s);
      http (sprintf (' val := get_keyword (%s, vals);\n', SYS_SQL_VAL_PRINT ('webID')), s);
	  http ('\n', s);
	  exp := replace (op,  '^{webid}^', '?:webid');
	  exp := replace (exp, '^{graph}^', '?:graph');
	  exp := replace (exp, '^{value}^', '?:val');
	  if (strstr (op, '^{webid}^') is not null)
	    {
	      http (sprintf (' rc := 0;\n'), s);
	      http (sprintf (' foreach (any w in val) do { \n'), s);
        http (sprintf ('   webid := w;\n'), s);
	      http (sprintf ('  if (exists (sparql %s)) rc := 1;\n', exp), s);
	      http (sprintf (' } \n'), s);
	      http (sprintf (' if (rc = 0) return 0;\n'), s);
	    }
	  else
	    {
	      http (sprintf (' if (not exists (sparql %s)) return 0;', exp), s);
	    }
	  http ('\n', s);
	}
    else if (SWA_PROP = 'certSparqlTriplet')
    {
      op := sprintf (
        ' prefix sioc: <http://rdfs.org/sioc/ns#> \n' ||
        ' prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> \n' ||
        ' prefix foaf: <http://xmlns.com/foaf/0.1/> \n' ||
        ' ASK \n' ||
        ' WHERE \n' ||
        '   { \n' ||
        '     ^{webid}^ %s ?v. \n' ||
        '     FILTER (%s). \n' ||
        '   }',
        SWA_QUERY,
        replace (get_keyword (SWA_OP, ops), ' <> ', ' != '));
      http (sprintf ('\n-- rule %d\n', SWA_ID), s);
      http (sprintf ('  val := get_keyword (%s, vals);\n', SYS_SQL_VAL_PRINT ('webID')), s);
      http ('\n', s);
      exp := replace (op,  '^{webid}^', '?:webid');
      exp := replace (exp, '^{graph}^', '?:graph');
      exp := replace (exp, '^{value}^', 'str (?v)');
      exp := replace (exp, '^{pattern}^', SYS_SQL_VAL_PRINT (SWA_VAL));
      if (strstr (op, '^{webid}^') is not null)
      {
        http (sprintf ('  rc := 0;\n'), s);
        http (sprintf ('  foreach (any w in val) do { \n'), s);
        http (sprintf ('    webid := w;\n'), s);
        http (sprintf ('    if (exists (\n sparql \n%s)) rc := 1;\n', exp), s);
        http (sprintf ('  } \n'), s);
        http (sprintf ('  if (rc = 0) return 0;\n'), s);
      }
      http ('\n', s);
    }
      else if (SWA_PROP = 'webID')
	{
	  http (sprintf ('\n-- rule %d\n', SWA_ID), s);
      http (sprintf (' val := get_keyword (%s, vals);\n', SYS_SQL_VAL_PRINT (SWA_PROP)), s);
	  http ('\n', s);
	  op := get_keyword (SWA_OP, ops);
      op := replace (op, 'bif:', '');
	  exp := replace (op, '^{value}^', 'w');
	  exp := replace (exp, '^{pattern}^', SYS_SQL_VAL_PRINT (SWA_VAL));
	  http (sprintf (' rc := 0;\n'), s);
	  http (sprintf (' foreach (any w in val) do { \n'), s);
	  http (sprintf (' if (%s) rc := 1;', exp), s);
	  http ('\n', s);
	  http (sprintf (' } \n'), s);
	  http (sprintf (' if (rc = 0) return 0;\n'), s);
	}
      else
	{
	  http (sprintf ('\n-- rule %d\n', SWA_ID), s);
      http (sprintf (' val := cast (get_keyword (%s, vals) as varchar);', SYS_SQL_VAL_PRINT (SWA_PROP)), s);
	  http ('\n', s);
	  op := get_keyword (SWA_OP, ops);
      op := replace (op, 'bif:', '');
	  exp := replace (op, '^{value}^', 'val');
	  if (SWA_PROP like '%Date')
	    exp := replace (exp, '^{pattern}^', 'stringdate (' || SYS_SQL_VAL_PRINT (SWA_VAL) || ')');
	  else  
	    exp := replace (exp, '^{pattern}^', SYS_SQL_VAL_PRINT (SWA_VAL));
	  http (sprintf (' if (not %s) return 0;', exp), s);
	  http ('\n', s);
	}
    }
  http (sprintf (' return 1;'), s);
  http ('\n', s);
  http (sprintf (''), s);
  http (sprintf ('}'), s);
  http ('\n', s);
  return string_output_string (s);  
}
;


--!
-- \brief Create query string to fetch a certificate.
--
-- This method builds a query that fetches the certificates identified with a given URI.
--
-- \param gr The graph to query.
-- \param uri The URI the certificates should be related to.
--
-- \return A query string.
--/
create procedure FOAF_SSL_QR (in gr varchar, in uri varchar)
{
    return sprintf ('sparql
    define input:storage ""
    define input:same-as "yes"
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

--!
-- \brief Query string to fetch the certificate by foaf:holdsAccount instead of the WebID directly.
--
-- FIXME: Is this backwards-compatibility legacy stuff?
--/
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

--!
-- \ingroup ods_devel_api
--
-- \brief Extract the first WebID URI from a X.509 certificate.
--
-- \param cert An optional certificate to extract the WebID from. By default the current client-provided
--             certificate is uses.
-- \param cert_type The optional format of the provided certificate.
-- - 0 (default) - PEM
-- - 1 - DER (raw)
-- - 2 - PKCS#12
--
-- \return The WebID embedded in the corresponding extension or \p null in case there is no WebID
-- extension found in the certificate or an error occurred.
--/
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

--!
-- \ingroup ods_devel_api
--
-- \brief Extract all WebID URIs from a X.509 certificate.
--
-- \param cert An optional certificate to extract the WebID from. By default the current client-provided
--             certificate is uses.
-- \param cert_type The optional format of the provided certificate.
-- - 0 (default) - PEM
-- - 1 - DER (raw)
-- - 2 - PKCS#12
--
-- \return The WebIDs embedded in the corresponding extension or \p null in case there is no WebID
-- extension found in the certificate or an error occurred.
--/
create procedure FOAF_SSL_WEBID_GET_ALL (in cert any := null, in cert_type int := 0)
{
  declare agents, agent, tmp, alts any;
  agent := get_certificate_info (7, cert, cert_type, '', '2.5.29.17');
  agents := null;
  if (agent is not null)
    {
      declare inx int;
      alts := regexp_replace (agent, ',[ ]*', ',', 1, null);
      alts := split_and_decode (alts, 0, '\0\0,:');
      if (alts is null)
	return null;
      while (0 <> (tmp := adm_next_keyword ('URI', alts, inx)))
	{
	  agents := vector_concat (agents, vector (tmp));
	}
    }
  return agents;
}
;

--!
-- \ingroup ods_devel_api
--
-- \brief Extract issuerAltName URIs from a X.509 certificate.
--
-- \param cert An optional certificate to extract the WebID from. By default the current client-provided
--             certificate is uses.
-- \param cert_type The optional format of the provided certificate.
-- - 0 (default) - PEM
-- - 1 - DER (raw)
-- - 2 - PKCS#12
--
-- \return The IAN embedded in the corresponding extension or \p null in case there is no IAN
-- extension found in the certificate or an error occurred.
--/
create procedure WEBID_GET_IAN (in cert any := null, in cert_type int := 0)
{
  declare agents, agent, tmp, alts any;
  agent := get_certificate_info (7, cert, cert_type, '', '2.5.29.18');
  if (agent is not null)
    {
      declare inx int;
      alts := regexp_replace (agent, ',[ ]*', ',', 1, null);
      alts := split_and_decode (alts, 0, '\0\0,:');
      if (alts is null)
	return null;
      tmp := get_keyword ('URI', alts);
      return tmp;
    }
  return NULL;
}
;

--!
-- \ingroup ods_devel_api
--
-- \brief Extract the first EMail address from a X.509 certificate.
--
-- The function looks both in the ceritifacte and in the altName extension.
--
-- \param cert An optional certificate to extract the WebID from. By default the current client-provided
--             certificate is uses.
-- \param cert_type The optional format of the provided certificate.
-- - 0 (default) - PEM
-- - 1 - DER (raw)
-- - 2 - PKCS#12
--
-- \return The EMail address embedded in the corresponding extension or \p null in case none is
-- found in the certificate or an error occurred.
--/
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

--!
-- \ingroup ods_devel_api
--
-- \brief Extract all EMail addresses from a X.509 certificate.
--
-- The function looks both in the ceritifacte and in the altName extension.
--
-- \param cert An optional certificate to extract the WebID from. By default the current client-provided
--             certificate is uses.
-- \param cert_type The optional format of the provided certificate.
-- - 0 (default) - PEM
-- - 1 - DER (raw)
-- - 2 - PKCS#12
--
-- \return The EMail addresss embedded in the corresponding extension or \p null in case none is
-- found in the certificate or an error occurred.
--/
create procedure FOAF_SSL_MAIL_GET_ALL (in cert any := null, in cert_type int := 0)
{
  declare alts, mail, ret any;
  ret := vector ();
  mail := get_certificate_info (10, cert, cert_type, '', 'emailAddress');
  if (mail is not null)
    ret := vector_concat (ret, vector (mail));
  alts := get_certificate_info (7, cert, cert_type, '', '2.5.29.17');
  if (alts is not null)
    {
      alts := regexp_replace (alts, ',[ ]*', ',', 1, null);
      alts := split_and_decode (alts, 0, '\0\0,:');
      mail := get_keyword ('email', alts);
      if (mail is not null and not position (mail, ret)) 
        ret := vector_concat (ret, vector (mail));
    }
  return ret;
}
;


--
-- WHEN USE try_loading_webid must clear the graph named as webid
--
--!
-- \ingroup ods_devel_api
--
-- \brief Fetches the WebID or WebFinder address for a given certificate.
--
-- \param An optional certificate to extract the WebID from. By default the current client-provided
--        certificate is uses.
-- \param try_loading_webid If \p 1 the function looks for a WebID in the retrieved WebFinger profile
--        and returns it instead of the WebFinger address.
-- \param cert_type The optional format of the provided certificate.
-- - 0 (default) - PEM
-- - 1 - DER (raw)
-- - 2 - PKCS#12
--
-- \return The WebID or the WebFinger address based on the value of try_loading_webid and the contents
-- of the WebFinger profile which matches the given certificate. If no matching profile is found \p null
-- is returned.
--
-- FIXME: Why does this function not clear the WebID graph itself?
--/
create procedure FOAF_SSL_WEBFINGER (in cert any := null, in try_loading_webid int := 0, in cert_type int := 0)
{
  declare mails, webid, domain, host_info, xrd, template, url, h any;
  declare xt, xd, tmpcert any;

  mails := FOAF_SSL_MAIL_GET_ALL (cert, cert_type);

  declare exit handler for sqlstate '*'
    {
      -- connection error or parse error
      return null;
    };

  foreach (varchar mail in mails) do
    {
      domain := subseq (mail, position ('@', mail));
      h := null;
      host_info := http_get (sprintf ('http://%s/.well-known/host-meta', domain), h, 'GET', null, null, null, 10, 15);
      if (h is null or h[0] not like 'HTTP/1._ 200')
	goto next_mail;
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
      next_mail:;
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

grant execute on DB.DBA.FOAF_MOD to SPARQL_SELECT
;

create procedure FOAF_SSL_AUTH (in realm varchar)
{
  return FOAF_SSL_AUTH_GEN (realm, 0);
}
;

create procedure WEBID_AUTH (in realm varchar)
{
  return FOAF_SSL_AUTH_GEN (realm, 0);
}
;

create procedure WEBID_DI_SPLIT (in str varchar)
{
  declare di, h, dgst varchar;
  declare ret any;
  ret := vector ();
  while (di := regexp_match ('di:[^ <>]+', str, 1) is not null)
    {
      h := WS.WS.PARSE_URI (di);
      dgst := bin2hex (cast (decode_base64 (replace (replace (cast (h[3] as varchar), '-', '+'), '_', '/')) as varbinary));
      ret := vector_concat (ret, vector (vector (cast (h[2] as varchar), dgst)));
    }
  return ret;
}
;

create procedure DB.DBA.X509_STRING_DATE (in val varchar)
{
  declare ret, tmp any;
  ret := NULL;
  declare exit handler for sqlstate '*'
    {
      return null;
    };
  val := regexp_replace (val, '[ ]+', ' ', 1, null);
  -- Jan 11 14:36:33 2012 GMT
  if (val is not null and regexp_match ('[[:upper:]][[:lower:]]{2} [0-9]{1,} [0-9]{2}:[0-9]{2}:[0-9]{2} [0-9]{4,} GMT', val) is not null)
    {
      tmp := sprintf_inverse (val, '%s %s %s %s GMT', 0);
      if (tmp is not null and length (tmp) > 3)
	{
	  ret := http_string_date (sprintf ('Wee, %s %s %s %s GMT', tmp[1], tmp[0], tmp[3], tmp[2]));
	  ret := dt_set_tz (ret, 0);
	}
    }    
  return ret;
}
;

create procedure WEBID_CHECK_ACL (in ag any, in gr any, in cert any, in realm any, out env any)
{
  declare uid varchar;
  env := null;
  for select FS_URI, FS_UID, FS_APP_DATA from FOAF_SSL_ACL where ag like FS_URI and FS_TYPE < 2 and FS_REALM = realm order by FS_PRIORITY do
    {
      connection_set ('WebID-rule-id', FS_URI);
      env := FS_APP_DATA;
      return FS_UID;
    }
  for select FS_URI, FS_UID, FS_APP_DATA from FOAF_SSL_ACL, RDF_WEBID_ACL_GROUPS where AG_GROUP = FS_URI and FS_TYPE < 2 and AG_WEBID = ag and FS_REALM = realm order by FS_PRIORITY do
    {
      connection_set ('WebID-rule-id', FS_URI);
      env := FS_APP_DATA;
      return FS_UID;
    }
  uid := 'nobody';
  if (uid = 'nobody')
    {
      for select FS_URI, FS_UID, FS_APP_DATA from FOAF_SSL_ACL where FS_TYPE = 2 and FS_REALM = realm order by FS_PRIORITY do
	{
	  declare pname varchar;
	  pname := sprintf ('DB.DBA.WEBID_ACL_CHECK__%s_%s', FS_URI, realm);
	  if (__proc_exists (pname) is null)
	    log_text (sprintf ('Broken advanced WebID rule: %s', FS_URI));
	  else if (call (pname) (cert, gr) > 0)
	    {
	      connection_set ('WebID-rule-id', FS_URI);
	      env := FS_APP_DATA;
	    return FS_UID;
	}
    }    
    }
  return uid;     
}
;

create procedure WEBID_CTYPE_TO_XENC_TYPE (in ctype int)
{
  if (ctype = 0)
    return 1;
  if (ctype = 1)
    return 3;
  if (ctype = 2)
    return 2;
  return 1;
}
;

--!
-- \brief Authenticate via WebID, WebFinger, etc.
--
-- \param An optional certificate to extract the WebID from. By default the current client-provided
--        certificate is uses.
-- \param ctype The optional format of the provided certificate.
-- - 0 (default) - PEM
-- - 1 - DER (raw)
-- - 2 - PKCS#12
-- \param realm \p unused
-- \param allow_nobody If \p 1 authentication is also allowed for WebIDs, WebFingers, and other identifiers without an ODS account.
-- \param use_session If \p 1 a new authentication session is created for the WebID/WebFinger. FIXME: use_session is ignored for Twitter and friends!
-- \param ag[out] The detected WebID if any.
-- \param _gr The graph to load the profile into. If empty a random graph URI will be used.
-- \param check_expiration If \p 1 the expiration date of the certificate will be checked. And if not valid \0 is returned.
-- \param validation_type[out] The type of authentication validation that was used:
-- - 0 - WebID
-- - 1 - WebFinger
-- - 2 - DI digest
-- - 3 - search FIXME: what exactly does this do?
-- - 4 - sponge FIXME: what exactly does this do?
-- - 5 - LDAP
-- \param validate_ian A flag to validate issuerAltName if exists
--
-- \return \p 1 on successful authentication, \p 0 otherwise. On success the connection's SPARQLUserId is set to the corresponding
-- ODS user and an optional authentication session is created.
--
-- FIXME: apparently WEBID_AUTH_GEN is not used and can be removed in favor of WEBID_AUTH_GEN_2.
--/
create procedure WEBID_AUTH_GEN_2 (
	in cert any,    		-- certificate
	in ctype int, 			-- certificate type see get_certificate_info for details 
	in realm varchar, 		-- application realm
	in allow_nobody int := 0, 	-- anonymous access
	in use_session int := 1, 	-- use session table
	out ag any,   			-- detected webid URI
	inout _gr any,			-- if non null data from webid URI will be loaded in the graph name in _gr
	in check_expiration int := 0,
	out validation_type int,	-- if valid, the way it was done : 0 - rdf graph, 1 - webfinger, 2 - DI, 3 - search, 4 - sponge
	in validate_ian int := 0
	)			
{
  declare stat, msg, meta, data, info, qr, hf, graph, fing, gr, modulus, alts, dummy any;
  declare agent varchar;
  declare acc int;
  declare ret_code, done, is_di, deadl int;
  declare agents, di_arr, dgst, dhash, fing_b64u, ian any;
  declare valid_from, valid_to datetime;

  if (realm is null)
    realm := 'GENERIC';

again:  
  ret_code := 0;
  acc := 0;
  done := 0;
  is_di := 0;
  ag := null;
  deadl := 0;
  validation_type := null;
  declare exit handler for sqlstate '*'
    {
      rollback work;
      deadl := deadl + 1;
      if (__SQL_STATE = '40001' and deadl < 10)
	goto again;
      --log_message (sprintf ('webid main %s %s', cast (__SQL_STATE as varchar), cast (__SQL_MESSAGE as varchar)));
      goto ret;
    }
  ;

  if (cert is null and client_attr ('client_certificate') = 0)
    return 0;

  fing := get_certificate_info (6, cert, ctype);
  if (_gr is null)
    gr := 'http:' || replace (fing, ':', '');
  else
    gr := _gr;
  info := get_certificate_info (9, cert, ctype);
  valid_from := X509_STRING_DATE (get_certificate_info (4, cert, ctype)); 
  valid_to := X509_STRING_DATE (get_certificate_info (5, cert, ctype)); 
  if (check_expiration = 1 and (valid_to < now () or valid_from > now ()))
    return 0;
  agents := FOAF_SSL_WEBID_GET_ALL (cert, ctype);
  if (not isarray (info))
    return 0;
  if (use_session)
    {
      -- If we already have a session for the given certificate (fingerprint) use it
      -- FIXME: security risk: in theory a WebID certificate could have been compromised in between
      -- calls. At that point a third party could login with the old certificate key/fingerprint even
      -- if the actual owner of the WebID had changed their certificate key in the meantime.
      for select VS_UID, VS_STATE from VSPX_SESSION where VS_SID = fing and VS_REALM = realm do
	{
	  declare st, uid, env any;
	  st := deserialize (VS_STATE);
	  ag := get_keyword ('agent', st);
	  uid := WEBID_CHECK_ACL (ag, gr, cert, realm, env);
	  if (exists (select 1 from SYS_USERS where U_NAME = VS_UID) and VS_UID = uid)
	    {
	  validation_type := get_keyword ('vtype', st);
	  connection_set ('SPARQLUserId', VS_UID);
	      connection_set ('WebID-app-data', env);
	  return 1;
	}
	  else
	    {
	      uid := VS_UID;
	      delete from VSPX_SESSION x where x.VS_REALM = realm and x.VS_UID = uid;
	    }
	}
    }

  if (agents is null)
    goto verify_mails;

  if (validate_ian)
    {
      declare certname varchar;
      declare icx int;
      icx := sequence_next ('webid_cert_key_inx');
      certname := sprintf ('webid_key_%d', icx); 
      xenc_key_create_cert (certname, cert, 'X.509', WEBID_CTYPE_TO_XENC_TYPE (ctype));
      ian := WEBID_GET_IAN (cert, ctype);
      if (ian is null) goto ian_ok;
      hf := rfc1808_parse_uri (ian);
      hf[5] := '';
      graph := DB.DBA.vspx_uri_compose (hf);
      qr := sprintf ('sparql define get:soft "add" select count(*) from <%S> { ?s ?p ?o }', graph);
      stat := '00000';
      exec (qr, stat, msg, vector (), 0, meta, data);
      for select "m", "e" from 
      (sparql prefix cert: <http://www.w3.org/ns/auth/cert#> select * { graph `iri(?:graph)` { [] cert:exponent ?e ; cert:modulus ?m }}) x do
	{
	  declare hexm, hexe, kname varchar;
	  declare ix, rc any;
	  hexm := cast (hex2bin ("m") as varchar);
	  hexe := sprintf ('%x', "e");
	  if (mod (length (hexe), 2)) hexe := '0' || hexe;
	  hexe := cast (hex2bin (hexe) as varchar);
	  ix := sequence_next ('webid_ian_key_inx');
	  kname := sprintf ('ian_key_%d', ix);
	  xenc_key_RSA_construct (kname, hexm, hexe);
	  rc := x509_verify (certname, kname);
	  xenc_key_remove (kname);
	  if (rc) goto ian_ok;
	}
      xenc_key_remove (certname);
      return 0;
      ian_ok:;
      xenc_key_remove (certname);
    }

  foreach (any _agent in agents) do
    {
      agent := _agent;
      agent_fp:
      ag := agent;
      if (agent like 'ldap://%' and DB.DBA.FOAF_SSL_LDAP_CHECK_CERT_INT (agent, cert, ctype, dummy))
	{
	  validation_type := 5;
	  goto authenticated;
	}

      hf := rfc1808_parse_uri (agent);
      hf[5] := '';
      graph := DB.DBA.vspx_uri_compose (hf);
      qr := sprintf ('sparql define get:soft "add" define get:uri <%S> select count(*) from <%S> { ?s ?p ?o }', graph, gr);
      stat := '00000';
      exec (qr, stat, msg, vector (), 0, meta, data);
      if (stat = '40001')
	{
	  deadl := deadl + 1;
	  goto again;
	}
      --if (stat <> '00000')
	--log_message (sprintf ('webid load %s %s %s', cast (stat as varchar), cast (msg as varchar), sys_sql_val_print (data)));
      commit work;
      qr := FOAF_SSL_QR (gr, agent);    
      stat := '00000';
    --  dbg_printf ('%s', qr);
      exec (qr, stat, msg, vector (), 0, meta, data);
      if (stat = '40001')
	{
	  deadl := deadl + 1;
	  goto again;
	}
      --if (stat <> '00000')
	--log_message (sprintf ('webid exec %s %s', cast (stat as varchar), cast (msg as varchar)));
      validation_type := 0;
      again_check:; 
      if (stat = '00000' and length (data))
	{
	  foreach (any _row in data) do
	    {
	      --dbg_obj_print (_row[0], cast (info[1] as varchar), DB.DBA.FOAF_MOD (_row[1]), bin2hex (info[2]));
	      if (_row[0] = cast (info[1] as varchar) and DB.DBA.FOAF_MOD (_row[1]) = bin2hex (info[2]))
		{
		  declare arr, uid, env any;
		  authenticated:
		  ag := agent;
		  --_gr := graph;
		  uid := WEBID_CHECK_ACL (ag, gr, cert, realm, env);
		  if ('nobody' = uid and allow_nobody = 0)
		    goto ret;
		  connection_set ('SPARQLUserId', uid);
		  connection_set ('WebID-app-data', env);
		  if (use_session)
		    insert replacing VSPX_SESSION (VS_SID, VS_REALM, VS_UID, VS_EXPIRY, VS_STATE) 
			values (fing, realm, uid, now (), serialize (vector ('agent', ag, 'vtype', validation_type)));
		  --if (_gr is null)
		  --  exec (sprintf ('sparql clear graph <%S>', gr), stat, msg);
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
    }
  verify_mails:
  agent := FOAF_SSL_WEBFINGER (cert, 0, ctype);
  if (agent is not null)
    {
      validation_type := 1;
      goto authenticated;
    }
  validation_type := null;
  {
    ag := graph;
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
    di_arr := WEBID_DI_SPLIT (xp);
    if (length (di_arr) > 1)
      {
	foreach (any elm in di_arr) do
	  {
	    dgst := elm [0];
	    dhash := elm [1]; 
	    fing := get_certificate_info (6, cert, ctype, null, dgst);
	    fing := lower (replace (fing, ':', ''));
	    fing_b64u := encode_base64url (cast (hex2bin (fing) as varchar));
	    if (fing = dhash)
	      {
		validation_type := 2;
		ret_code := 1;
		goto ret;	
	      }
	    is_di := 1;
	  }
      }
    else
      {
	if (strstr (xp, '#SHA1') is not null)
	  fing := get_certificate_info (6, cert, ctype, null, 'sha1');
	fing := replace (fing, ':', '');  
      }
    if (strstr (xp, sprintf ('Fingerprint:%s', fing)) is not null)
      {
	validation_type := 2;
	ret_code := 1;
        goto ret;	
      }
    if (graph like 'http://twitter.com/%')
      {
	declare acco, arr, json, res, url any;
	arr := sprintf_inverse (graph, 'http://twitter.com/%s', 1);
	acco := arr[0];
	if (is_di)
	  {
	    url := sprintf ('http://search.twitter.com/search.json?q=%%40%%23X509Cert%%20di:%s;%s%%20from%%3A%U', dgst, fing_b64u, acco);
	  }
	else
	  {
	    url := sprintf ('http://search.twitter.com/search.json?q=%%40Fingerprint%%3A%U%%20from%%3A%U', fing, acco);
	  }
        json := http_get (url);
	arr := json_parse (json);
        res := get_keyword ('results', arr);
	if (length (res) > 0)
	  {
	    validation_type := 3;
	    ret_code := 1;
	    goto ret;	
	  }
	if (not is_di)
	  {
	    fing := get_certificate_info (6, cert, ctype, null, 'sha1');
	    fing := replace (fing, ':', '');  
	    json := http_get (sprintf ('http://search.twitter.com/search.json?q=%%40Fingerprint%%3A%U%%20from%%3A%U', fing, acco));
	    arr := json_parse (json);
	    res := get_keyword ('results', arr);
	    if (length (res) > 0)
	      {
		validation_type := 3;
		ret_code := 1;
		goto ret;	
	      }
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
    'sparql define get:soft "add" prefix opl: <http://www.openlinksw.com/schemas/cert#> select ?f ?dgst from <%S> { ?s opl:hasCertificate ?c . ?c opl:fingerprint ?f ; opl:fingerprint-digest ?dgst . }', 
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
	   fng2 := DB.DBA.FOAF_MOD (fng2);
    	   if (lower (fng2) = lower (fng))
    	     {
	       validation_type := 4;
    	       ret_code := 1;
    	       goto ret;
    	     }
    	 }
      }

  }
  ret:
  --if (_gr is null)
  --  exec (sprintf ('sparql clear graph <%S>', gr), stat, msg);
  if (0 = ret_code)
    ag := null;
  commit work;
  return ret_code;
}
;

--!
-- FIXME: FOAF_SSL_AUTH_GEN seems completely redundant in favor of WEBID_AUTH_GEN_2
--/
create procedure FOAF_SSL_AUTH_GEN (in realm varchar, in allow_nobody int := 0, in use_session int := 1)
{
  declare cert, gr, w, vtype any;
  cert := client_attr ('client_certificate');
  gr := null;
  return WEBID_AUTH_GEN_2 (cert, 0, realm, allow_nobody, use_session, w, gr, 0, vtype);
}
;

--!
-- \ingroup ods_devel_api
--
-- \brief Check if a URI is a valid WebID with a certificate.
--
-- \param agent The URI to check.
--
-- \return \p 1 if the profile accessible at \p agent does contain a certificate public key.
--/
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

DB.DBA.VHOST_REMOVE (vhost=>'*sslini*', lhost=>'*sslini*', lpath=>'/sparql-webid');
DB.DBA.VHOST_DEFINE (vhost=>'*sslini*', lhost=>'*sslini*', lpath=>'/sparql-webid',
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

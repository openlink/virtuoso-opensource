use SEMPING;

--drop table CLI_QUEUE;
--drop table PINGBACKS;

-- client queue
DB.DBA.EXEC_STMT (
'create table CLI_QUEUE (
    			CQ_SOURCE varchar,
			CQ_TARGET varchar,
			CQ_SERVER varchar,
			CQ_PROTO  varchar,
			CQ_STATE  int default 0,
			CQ_ERR	  long varchar,
			CQ_TS 	  timestamp,
			primary key (CQ_SOURCE, CQ_TARGET)
    			)', 0);

-- server's pingbacks 
DB.DBA.EXEC_STMT (
'create table PINGBACKS (
    			P_SOURCE varchar,
			P_TARGET varchar,
			P_PROP	 varchar,
			P_MAIL   varchar,
			P_STATE  int default 0,
			P_ERR	 long varchar,
			P_IP	 varchar,
			P_TS	 timestamp,
			primary key (P_SOURCE, P_TARGET)
    			)
create index PINGBACKS_STAT on PINGBACKS (P_STATE, P_TS, P_SOURCE, P_TARGET, P_PROP, P_MAIL)', 0);


-- /* must be called when adding external links */
create procedure CLI_PING (in src varchar, in tgt varchar)
{
  declare aq any;
  insert soft CLI_QUEUE (CQ_SOURCE, CQ_TARGET) values (src, tgt);
  commit work;
  if (row_count () > 0)
    {
      aq := async_queue (1);
      aq_request (aq, 'SEMPING.DBA.CLI_PING_SRV', vector (src, tgt));
    }
  return;
}
;

create procedure CLI_PING_SRV (in src varchar, in tgt varchar)
{
  declare hf any;
  declare gr, url, pserv, proto varchar;

  hf := rfc1808_parse_uri (tgt);
  hf[5] := '';
  gr := 'urn:temp.semping:' || uuid ();
  url := WS.WS.VFS_URI_COMPOSE (hf);
  sparql load ?:url into graph ?:gr;
  pserv := (sparql prefix pingback: <http://purl.org/net/pingback/> select ?ps where { graph ?:gr { ?:tgt pingback:service ?ps }});
  proto := 'REST';  
  if (pserv is null)
    {
      pserv := (sparql prefix pingback: <http://purl.org/net/pingback/> select ?ps where { graph ?:gr { ?:tgt pingback:to ?ps }});
      proto := 'RPC';  
    }
  sparql clear ?:gr;  
  update CLI_QUEUE set CQ_SERVER = pserv, CQ_PROTO = proto, CQ_STATE = 1 where CQ_SOURCE = src and CQ_TARGET = tgt;
  commit work;
  if (pserv is not null)
    {
      declare ret any;
      declare exit handler for sqlstate '*'
	{
	  rollback work; 
	  update CLI_QUEUE set CQ_ERR = __SQL_MESSAGE, CQ_STATE = 3 where CQ_SOURCE = src and CQ_TARGET = tgt;
	  return;
	};
      if (proto = 'RPC')
	{
	  ret := DB.DBA.XMLRPC_CALL (pserv, 'pingback.ping', vector (src, tgt));
	  ret := serialize_to_UTF8_xml (xml_tree_doc (ret));
	}
      else
	{
	  declare pars, head any;
	  pars := sprintf ('source=%U&target=%U', src, tgt);
	  ret := http_client_ext (url=>pserv, headers=>head, http_method=>'POST', body=>pars);
	}
      update CLI_QUEUE set CQ_STATE = 2, CQ_ERR = ret where CQ_SOURCE = src and CQ_TARGET = tgt;
    }
  else
    {
      update CLI_QUEUE set CQ_ERR = 'Cannot determine semantick pingback server', CQ_STATE = 3 where CQ_SOURCE = src and CQ_TARGET = tgt;
    }

  return pserv;
}
;


create procedure SEMPING_INIT ()
{
  if (exists (select 1 from "DB"."DBA"."SYS_USERS" where U_NAME = 'SEMPING'))
    return;
  DB.DBA.USER_CREATE ('SEMPING', uuid(), vector ('DISABLED', 1, 'LOGIN_QUALIFIER', 'SEMPING'));
}
;

SEMPING_INIT()
;

DB.DBA.VHOST_REMOVE ( lhost=>'*ini*', vhost=>'*ini*', lpath=>'/semping');

DB.DBA.VHOST_DEFINE ( lhost=>'*ini*', vhost=>'*ini*', lpath=>'/semping', ppath=>'/SOAP/', is_dav=>0, soap_user=>'SEMPING',
    soap_opts=>vector ('XML-RPC', 'yes')
    );


    

-- pingback server
create procedure "pingback.ping" (in source varchar, in target varchar) 
{
  declare aq, hf any;
  declare qr, src, tgt, srcgr, tgtgr, pred, mail varchar;

  if (http_acl_get ('SemanticPingback', source, target) = 1)
    {
      signal ('42000', 'Access denied');
    }

  hf := rfc1808_parse_uri (source); hf[5] := '';
  src := WS.WS.VFS_URI_COMPOSE (hf);
  hf := rfc1808_parse_uri (target); hf[5] := '';
  tgt := WS.WS.VFS_URI_COMPOSE (hf);

  set_user_id ('dba');

  srcgr := 'urn:temp.semping.src:' || uuid ();
  tgtgr := 'urn:temp.semping.tgt:' || uuid ();
  sparql load ?:src into graph ?:srcgr;
  sparql load ?:tgt into graph ?:tgtgr;

  pred := (sparql select ?p where { graph `iri(?:srcgr)` { `iri(?:source)` ?p `iri(?:target)` . }});
  mail := (sparql prefix foaf: <http://xmlns.com/foaf/0.1/> select ?mbox where { graph `iri(?:tgtgr)` { `iri(?:target)` foaf:mbox ?mbox . }}); 

--  dbg_obj_print_vars (pred, mail);

  sparql clear ?:srcgr;
  sparql clear ?:tgtgr;

  if (mail like 'mailto:%')
    mail := subseq (mail, 7);

  if (pred is null)
    signal ('22023', 'Source does not contains any rellation to target');
  if (mail is null)
    signal ('22023', 'Cannot determine the notification e-mail from traget');

  insert soft PINGBACKS (P_SOURCE, P_TARGET, P_PROP, P_MAIL, P_IP) 
      values (source, target, pred, mail, http_client_ip ());
  if (0 = row_count ())
    signal ('22023', 'Pingback already done');

  commit work;
  aq := async_queue (1);
  aq_request (aq, 'SEMPING.DBA.CLI_NOTIFY', vector ());

  return 'Success';
}
;

grant execute on "pingback.ping" to SEMPING;

create procedure GET_TEMPLATE ()
{
  return 
      sprintf ('Date: %s \r\n', DB.DBA.date_rfc1123 (now ())) ||
      sprintf ('X-Mailer: OpenLink Virtuoso Mail Client (%s)\r\n', sys_stat('st_dbms_ver')) ||
      'Content-Type: text/plain\r\n' ||
      'Subject: Semantic Pingback Notification\r\n\r\n' ||
      'The entity <s> is updated with relation <p> connecting to your WebID: <t>\r\n' ||
      'You may wish add the reciprocal relation in your space.\r\n' ||
      '\r\n' ||
      'You are receiving this e-mail because you are enabled pingback notification for WebID <t>.\r\n' ||
      'Please do not answer on this e-mail, it is automatically generated as semantic pingback notification.\r\n' 
      ;
}
;

-- notification 
create procedure CLI_NOTIFY ()
{
  declare src, tgt, prop, mail, adm_mail, body varchar;

  adm_mail := (select U_E_MAIL from DB.DBA.SYS_USERS where U_NAME = 'dav');
  commit work;

again:
  whenever not found goto done;
  select P_SOURCE, P_TARGET, P_PROP, P_MAIL into src, tgt, prop, mail from PINGBACKS where P_STATE = 0 order by P_TS desc with (prefetch 1);
  update PINGBACKS set P_STATE = 1 where P_SOURCE = src and P_TARGET = tgt;
  commit work;

  body := GET_TEMPLATE ();
  body := replace (body, '<s>', src);
  body := replace (body, '<t>', tgt);
  body := replace (body, '<p>', prop);
  {
    declare continue handler for sqlstate '*'
      {
	rollback work;
	update PINGBACKS set P_STATE = 3, P_ERR = __SQL_MESSAGE where P_SOURCE = src and P_TARGET = tgt;
      };
    smtp_send (null, adm_mail, mail, body);
    update PINGBACKS set P_STATE = 2, P_ERR = null where P_SOURCE = src and P_TARGET = tgt;
  }
  
  commit work;
  goto again;
  done:
  return;
}
;

use DB;

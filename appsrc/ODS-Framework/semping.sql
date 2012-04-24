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

DB.DBA.EXEC_STMT (
'create table PING_RULES (
    			PR_IRI 		varchar,
  			PR_U_ID		int not null,
			PR_GRAPH 	varchar,
			PR_EMAIL	varchar,
			PR_FLAG		int default 0,
			primary key (PR_IRI)
    			)', 0);
DB.DBA.EXEC_STMT ('create table PING_LOCK (ID int primary key)', 0);

insert soft PING_LOCK values (0);

create trigger PING_RULES_I after insert on PING_RULES referencing new as N
{
  declare ep varchar;
  if (0 = length (N.PR_GRAPH))
    return;
  ep := sprintf ('http://%s/semping/rest', sioc..get_cname ());
  sparql insert into graph iri(?:N.PR_GRAPH) { `iri(?:N.PR_IRI)` <http://purl.org/net/pingback/to> `iri(?:ep)` . };
}
;

create trigger PING_RULES_U after update on PING_RULES referencing old as O, new as N
{
  declare ep varchar;
  if (0 = length (N.PR_GRAPH))
    return;
  ep := sprintf ('http://%s/semping/rest', sioc..get_cname ());
  sparql delete from graph iri(?:O.PR_GRAPH) { `iri(?:O.PR_IRI)` <http://purl.org/net/pingback/to> `iri(?:ep)` . };
  sparql insert into graph iri(?:N.PR_GRAPH) { `iri(?:N.PR_IRI)` <http://purl.org/net/pingback/to> `iri(?:ep)` . };
}
;

create trigger PING_RULES_D after delete on PING_RULES referencing old as O
{
  declare ep varchar;
  if (0 = length (O.PR_GRAPH))
    return;
  ep := sprintf ('http://%s/semping/rest', sioc..get_cname ());
  sparql delete from graph iri(?:O.PR_GRAPH) { `iri(?:O.PR_IRI)` <http://purl.org/net/pingback/to> `iri(?:ep)` . };
}
;

-- /* must be called when adding external links */
create procedure CLI_PING (in src varchar, in tgt varchar)
{
  declare aq any;
  -- debug code
  -- dbg_obj_print ('CLI_PING:', current_proc_name (1));
  if (registry_get ('semping-debug') = 'on') 
    {
      dbg_obj_print_vars (src, tgt);
      return; 
    }   
  insert soft CLI_QUEUE (CQ_SOURCE, CQ_TARGET) values (src, tgt);
  commit work;
      aq := async_queue (1);
      aq_request (aq, 'SEMPING.DBA.CLI_PING_SRV', vector (src, tgt));
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
  proto := 'RPC';
  if (pserv is null)
    {
      pserv := (sparql prefix pingback: <http://purl.org/net/pingback/> select ?ps where { graph ?:gr { ?:tgt pingback:to ?ps }});
      proto := 'REST';
    }
  sparql clear graph ?:gr;
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

DB.DBA.VHOST_REMOVE ( lhost=>'*ini*', vhost=>'*ini*', lpath=>'/semping/rest');

DB.DBA.VHOST_DEFINE ( lhost=>'*ini*', vhost=>'*ini*', lpath=>'/semping/rest', ppath=>'/SOAP/Http/semping-rest', is_dav=>0, soap_user=>'SEMPING'
    );
    

create procedure "semping-rest" (in source varchar := null, in target varchar := null) returns varchar __SOAP_HTTP 'text/plain'
{
  if (source is null or target is null)
    {
      http_header ('Content-Type: text/html\r\n');
      http (
      '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML+RDFa 1.0//EN" "http://www.w3.org/MarkUp/DTD/xhtml-rdfa-1.dtd">
      <html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" xmlns:pingback="http://purl.org/net/pingback/">
      <head> <title>Pingback Service</title> <meta http-equiv="Content-Type" content="text/html;charset=utf-8" /> </head>
      <body typeof="pingback:Container">
      <form method="post" action="">
      <p>source: <input type="text" property="pingback:source" name="source" /></p>
      <p>target: <input type="text" property="pingback:target" name="target" /></p>
      <p>comment: <input maxlength="256" type="text" name="comment" /></p>
      <p><input type="submit" name="submit" value="Send" /></p>
      </form>
      </body>
      </html>'
      );
      return '';
    }
  return "pingback.ping" (source, target);
}
;

-- pingback server
create procedure "pingback.ping" (in source varchar, in target varchar) 
{
  declare aq, hf, xx any;
  declare qr, src, tgt, srcgr, tgtgr, pred, mail varchar;


  if (http_acl_get ('SemanticPingback', source, target) = 1)
    {
      signal ('42000', 'Access denied');
    }

  dbg_obj_print ('------------------------------------');
  dbg_obj_print_vars (source, target);
  set_user_id ('dba');

  srcgr := 'urn:temp.semping.src:' || uuid ();
  tgtgr := 'urn:temp.semping.tgt:' || uuid ();

  set isolation = 'serializable';
  select id into xx from PING_LOCK where ID = 0 for update;

  hf := rfc1808_parse_uri (source); hf[5] := '';
  src := WS.WS.VFS_URI_COMPOSE (hf);
  sparql load ?:src into graph ?:srcgr;
  hf := rfc1808_parse_uri (target); hf[5] := '';
  tgt := WS.WS.VFS_URI_COMPOSE (hf);
  sparql load ?:tgt into graph ?:tgtgr;

  pred := (sparql select ?p where { graph `iri(?:srcgr)` { `iri(?:source)` ?p `iri(?:target)` . }});
  if (0 and pred is null)
    {
      declare src1 any;
      src1 := (sparql prefix sioc: <http://rdfs.org/sioc/ns#> select ?s where { graph `iri(?:srcgr)` { `iri(?:source)` sioc:reply_of ?s . }});
      if (src1 is not null)
	{
	  hf := rfc1808_parse_uri (src1); hf[5] := '';
	  src := WS.WS.VFS_URI_COMPOSE (hf);
	  sparql load ?:src into graph ?:srcgr;
	  pred := (sparql prefix sioc: <http://rdfs.org/sioc/ns#> select ?p where { graph `iri(?:srcgr)` { `iri(?:src1)` ?p `iri(?:target)` . }});
	}
    }
  mail := (sparql prefix foaf: <http://xmlns.com/foaf/0.1/> select ?mbox where { graph `iri(?:tgtgr)` { `iri(?:target)` foaf:mbox ?mbox . }}); 

  dbg_obj_print_vars (pred, mail);
  sparql clear graph iri(?:srcgr);
  sparql clear graph iri(?:tgtgr);

  if (mail like 'mailto:%')
    mail := subseq (mail, 7);

  if (pred is null)
    signal ('22023', 'Source does not contains any relation to target');

--  dbg_obj_print_vars (source, target, pred, mail);
  insert replacing PINGBACKS (P_SOURCE, P_TARGET, P_PROP, P_MAIL, P_IP, P_STATE) 
      values (source, target, pred, mail, http_client_ip (), 0);

  if (0 = row_count ())
    signal ('22023', 'Pingback already done');

  commit work;
  aq := async_queue (1);
  aq_request (aq, 'SEMPING.DBA.CLI_NOTIFY', vector ());

  return 'Success';
}
;

grant execute on "pingback.ping" to SEMPING;
grant execute on "semping-rest" to SEMPING;

create procedure GET_TEMPLATE ()
{
  return 
      sprintf ('Date: %s \r\n', DB.DBA.date_rfc1123 (now ())) ||
      sprintf ('X-Mailer: OpenLink Virtuoso Mail Client (%s)\r\n', sys_stat('st_dbms_ver')) ||
      'Content-Type: text/plain\r\n' ||
      'Subject: Semantic Pingback Notification\r\n\r\n' ||
      'The Data Space Entity: <s> has been updated with a new relation <p> that references <t> .\r\n'||
      'You may also wish to make a reciprocal entry in your Data Space.' ||
      '\r\n' ||
      'Note: you are receiving this mail because you enabled Semantic Pingback notification (with email as notice mechanism)\r\n'||
      'for your Personal Profile Management Data Space for WebID: <t>. You do not need to respond to this automated email.'
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

  for select PR_U_ID, PR_EMAIL, PR_GRAPH, PR_FLAG from PING_RULES where PR_IRI = tgt do
    {
      if (length (PR_EMAIL))
        mail := PR_EMAIL;
      if (PR_FLAG = 1)
	{
          sparql insert into graph iri(?:PR_GRAPH) { `iri(?:tgt)` `iri(?:prop)` `iri(?:src)` };	
	  insert into DB.DBA.WA_USER_RELATED_RES (WUR_U_ID, WUR_P_IRI, WUR_SEEALSO_IRI) values (PR_U_ID, prop, src);
	  commit work;
	}
    }

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
    if (length (mail))
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

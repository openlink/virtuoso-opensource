create procedure rq_s_3_exec_no_error(in expr varchar) {
  declare state, message, meta, result any;
  exec(expr, state, message, vector(), 0, meta, result);
};

rq_s_3_exec_no_error('USER_GRANT_ROLE (''demo'', ''SPARQL_SELECT'')');


drop table rq_s_3_log;
create table rq_s_3_log (rid varchar primary key, rurl varchar, rerr long varchar, rstate int default 0);

create procedure Demo..rq_s_3_worker (in id varchar, in url varchar, in mt varchar)
{

  declare cnt int;
  insert replacing rq_s_3_log (rid, rurl, rerr, rstate) values (id, url, null, 0);
  if (regexp_match ('http://[^/]+(/)?.*', url) is null)
    {
      update rq_s_3_log set rerr = '<img src="cross.gif" border="0"/> Invalid URL', rstate = -1 where rid = id;
      commit work;
      return;
    }
  commit work;
  {
    declare exit handler for sqlstate '*'
      {
	rollback work;
	update rq_s_3_log set rerr = '<img src="cross.gif" border="0"/> ' || regexp_match ('[^\r\n]*', __SQL_MESSAGE), rstate = -1 where rid = id;
	commit work;
	return;
      };
    if (mt <> 'true')
      {
	exec (sprintf ('SPARQL define get:soft "soft" SELECT * FROM <%s> WHERE { ?s ?p ?o }', url));
      }
    else
      {
	declare cnt, hdr, tp any;
	cnt := http_get (url, hdr, 'GET', 'Accept: application/rdf+xml, text/rdf+n3, application/rdf+turtle, application/x-turtle, application/turtle');
	if (hdr[0] not like 'HTTP%200%')
	  signal ('22023', hdr[0]);
	tp := http_request_header (hdr, 'Content-Type');
	delete from DB.DBA.RDF_QUAD where G = DB.DBA.RDF_MAKE_IID_OF_QNAME (url);
	if (strstr (tp, 'application/rdf+xml') is not null)
	  {
	    DB.DBA.RDF_LOAD_RDFXML_MT (cnt, url, url);
	  }
	else if
	  (
	   strstr (tp, 'text/rdf+n3') is not null or
	   strstr (tp, 'text/rdf+ttl') is not null or
	   strstr (tp, 'application/rdf+n3') is not null or
	   strstr (tp, 'application/rdf+turtle') is not null or
	   strstr (tp, 'application/turtle') is not null or
	   strstr (tp, 'application/x-turtle') is not null
	  )
	  {
            DB.DBA.TTLP_MT (cnt, url, url);
	  }
	else
          {
          rq_s_3_workerlog (id);
	  signal ('22023', 'Cannot import content of type '||tp);
          };
      }
  }
  cnt := (select count(*) from DB.DBA.RDF_QUAD where G = DB.DBA.RDF_MAKE_IID_OF_QNAME (url));
  update rq_s_3_log set rstate = 1, rerr = '<img src="check.gif" border="0"/> Imported ' || cast (cnt as varchar) || ' tripplets' where rid = id;
  commit work;
  DB.DBA.RDF_SW_PING ('http://rpc.pingthesemanticweb.com/', url);
};


grant execute on Demo..rq_s_3_worker to demo;
grant execute on DB.DBA.TTLP_EV_TRIPLE_L_W to demo;
grant execute on DB.DBA.TTLP_EV_TRIPLE_L_A to demo;
grant execute on DB.DBA.TTLP_EV_TRIPLE_A to demo;
grant execute on DB.DBA.TTLP_EV_TRIPLE_W to demo;
grant execute on DB.DBA.TTLP_EV_NEW_BLANK to demo;
grant execute on DB.DBA.RDF_SPONGE_UP to demo;
--grant execute on DB.DBA.RDF_QUAD to demo;

create procedure Demo..rq_s_3_workerlog (in PID any)
{
  declare ss long varchar;

  ss:= '';

  for select rerr, rstate from rq_s_3_log where rid = PID do
  {
    if (rstate <> 0)
    {
      if (rstate > 0)
      {
        return rerr;
      }
      else
      {
        --ss:=concat(ss, '<font style="color:red">');
        --ss:=concat(ss, rerr);
        --ss:=concat(ss, '</font>');
        return sprintf('<font style="color:red">%s</font>',rerr);
      };
    }
    else
      return 'importing';
  };

  return ss;
};

grant execute on Demo..rq_s_3_workerlog to demo;

select rerr, rstate from rq_s_3_log;

create procedure DB.DBA.rq_s_3_workeriso ()
{
  set isolation='uncommitted';
};

grant execute on DB.DBA.rq_s_3_workeriso to demo;


create procedure DB.DBA.rq_s_3_workerasync (in id varchar, in url varchar, in mt varchar)
{
  declare aq, res, err any;
  declare n int;
  aq := async_queue (1);
  res := aq_request (aq, 'Demo..rq_s_3_worker', vector (id, url, mt));
  return;
};

grant execute on DB.DBA.rq_s_3_workerasync to demo;


create procedure DB.DBA.rq_s_3_workeruuid ()
{
  return uuid();
};

grant execute on DB.DBA.rq_s_3_workeruuid to demo;


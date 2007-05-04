drop table ri_s_1_log;
create table ri_s_1_log (rid varchar primary key, rurl varchar, rerr long varchar, rstate int default 0);

create procedure ri_s_1_worker (in id varchar, in url varchar, in mt varchar)
{
  declare cnt int;

  insert replacing ri_s_1_log (rid, rurl, rerr, rstate) values (id, url, null, 0);
  if (regexp_match ('http://[^/]+(/)?.*', url) is null)
    {
      update ri_s_1_log set rerr = '<img src="cross.gif" border="0"/> Invalid URL', rstate = -1 where rid = id;
      commit work;
      return;
    }
  commit work;
  {
    declare exit handler for sqlstate '*'
      {
	rollback work;
	update ri_s_1_log set rerr = '<img src="cross.gif" border="0"/> ' || regexp_match ('[^\r\n]*', __SQL_MESSAGE), rstate = -1 where rid = id;
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
	  signal ('22023', 'Cannot import content of type '||tp);
      }
  }
  cnt := (select count(*) from DB.DBA.RDF_QUAD where G = DB.DBA.RDF_MAKE_IID_OF_QNAME (url));
  update ri_s_1_log set rstate = 1, rerr = '<img src="check.gif" border="0"/> Imported ' || cast (cnt as varchar) || ' tripplets' where rid = id;
  commit work;
  DB.DBA.RDF_SW_PING ('http://rpc.pingthesemanticweb.com/', url);
};

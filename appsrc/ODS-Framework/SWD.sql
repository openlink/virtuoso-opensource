use ODS;

create procedure swd_get_app_type (in svc varchar)
{
  declare app, arr varchar;
  arr := sprintf_inverse (svc, 'urn:openlinksw.com:ods:%s', 0);
  app := arr[0];
  return db.dba.wa_app_to_type (app);
}
;

create procedure "simple-web-discovery" (in principal varchar, in service varchar) __SOAP_HTTP 'application/json'
{
  declare host, mail, uname varchar;
  declare arr, tmp, graph, app any;
  declare f int;

  host := http_host ();
  arr := WS.WS.PARSE_URI (principal);
  graph := sioc..get_graph ();

  if (arr [0] = 'http')
    {
      tmp := (sparql define input:storage "" 
        prefix foaf: <http://xmlns.com/foaf/0.1/> 
      	select ?mbox where 
	 { graph `iri(?:graph)` { `iri(?:principal)` foaf:mbox ?mbox }});
      if (tmp is not null)
        {
	  arr := WS.WS.PARSE_URI (tmp);
	}	  
    } 
  mail := arr[2];
  uname := (select top 1 U_NAME from DB.DBA.SYS_USERS where U_E_MAIL = mail order by U_ID);
  if (uname is null)
    {
      uname := (sparql define input:storage "" 
      	prefix owl: <http://www.w3.org/2002/07/owl#> 
        prefix foaf: <http://xmlns.com/foaf/0.1/> 
      	select ?nick 
         where { graph `iri(?:graph)` { ?s owl:sameAs `iri(?:principal)` ; foaf:nick ?nick . }});
    }
  if (uname is null)
    signal ('22023', sprintf ('The user account "%s" does not exist', principal));
  app := swd_get_app_type (service);
  http ('{\n');
  http (' "locations":[\n');
  for select WAM_HOME_PAGE, WAM_INST, WAM_APP_TYPE 
    from DB.DBA.SYS_USERS, DB.DBA.WA_MEMBER where WAM_USER = U_ID and U_NAME = uname and WAM_MEMBER_TYPE = 1 and WAM_APP_TYPE = app do
    {
      declare url varchar; 
      url := sioc..forum_iri (WAM_APP_TYPE, WAM_INST, uname);
      if (not f)
	f := 1;
      else
	http (',');
      http (sprintf ('   "%s"\n', url));
    }
  http ('   ] \n');
  http ('}\n');
  return '';
}
;

create procedure SWD_INIT ()
{
  DB.DBA.VHOST_REMOVE (lpath=>'/.well-known/simple-web-discovery');
  DB.DBA.VHOST_DEFINE (lpath=>'/.well-known/simple-web-discovery', ppath=>'/SOAP/Http/simple-web-discovery', soap_user=>'ODS_API');
}
;

SWD_INIT ();

grant execute on ODS.DBA."simple-web-discovery" to ODS_API;

use DB;

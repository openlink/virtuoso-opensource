create procedure DB.DBA.LOAD_TUTNW_ONTOLOGY_FROM_DAV()
{
  declare content, urihost varchar;
  whenever not found goto endpoint;
  select cast (RES_CONTENT as varchar) into content from WS.WS.SYS_DAV_RES where RES_FULL_PATH = '/DAV/VAD/tutorial/rdfview/rd_v_1/rd_v_1.owl';
  if (content is null or content = '')
    goto endpoint;
  DB.DBA.RDF_LOAD_RDFXML_MT (content, 'http://demo.openlinksw.com/schemas/tutorial/northwind#', 'http://demo.openlinksw.com/schemas/TutorialNorthwindOntology/1.0/');
  if (urihost = 'demo.openlinksw.com')
  {
    DB.DBA.VHOST_REMOVE (lpath=>'/schemas/tutorial/northwind#');
    DB.DBA.VHOST_DEFINE (lpath=>'/schemas/tutorial/northwind#', ppath=>'/DAV/VAD/tutorial/rdfview/rd_v_1/rd_v_1.owl', vsp_user=>'dba', is_dav=>1, is_brws=>0);
    DB.DBA.VHOST_REMOVE (lpath=>'/schemas/tutorial/northwind');
    DB.DBA.VHOST_DEFINE (lpath=>'/schemas/tutorial/northwind', ppath=>'/DAV/VAD/tutorial/rdfview/rd_v_1/rd_v_1.owl', vsp_user=>'dba', is_dav=>1, is_brws=>0);
  }
  endpoint:
  ;
}
;

DB.DBA.LOAD_TUTNW_ONTOLOGY_FROM_DAV()
;

drop procedure DB.DBA.LOAD_TUTNW_ONTOLOGY_FROM_DAV
;

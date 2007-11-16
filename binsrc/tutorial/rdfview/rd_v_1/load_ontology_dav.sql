create procedure DB.DBA.LOAD_TUTNW_ONTOLOGY_FROM_DAV()
{
  declare content varchar;
  select cast (RES_CONTENT as varchar) into content from WS.WS.SYS_DAV_RES where RES_FULL_PATH = '/DAV/VAD/tutorial/rdfview/rd_v_1/rd_v_1.owl';
  DB.DBA.RDF_LOAD_RDFXML_MT (content, 'http://demo.openlinksw.com/schemas/tutorial/northwind#', 'http://demo.openlinksw.com/schemas/TutorialNorthwindOntology/1.0/');
}
;

DB.DBA.LOAD_NW_ONTOLOGY_FROM_DAV()
;

drop procedure DB.DBA.LOAD_NW_ONTOLOGY_FROM_DAV
;

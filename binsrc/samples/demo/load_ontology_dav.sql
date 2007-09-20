create procedure DB.DBA.LOAD_NW_ONTOLOGY_FROM_DAV()
{
  declare content1 varchar;
  select cast (RES_CONTENT as varchar) into content1 from WS.WS.SYS_DAV_RES where RES_FULL_PATH = '/DAV/VAD/demo/sql/nw.owl';
  DB.DBA.RDF_LOAD_RDFXML (content1, 'http://www.openlinksw.com/schemas/demo#', 'http://www.openlinksw.com/schemas/NorthwindOntology/1.0/');
};

DB.DBA.LOAD_NW_ONTOLOGY_FROM_DAV();

drop procedure DB.DBA.LOAD_NW_ONTOLOGY_FROM_DAV;
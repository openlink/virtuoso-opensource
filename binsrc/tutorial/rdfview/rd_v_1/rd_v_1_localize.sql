create procedure DB.DBA.rd_v_1_localize()
{
  declare file_text, uriqa varchar;
  uriqa := registry_get('URIQADefaultHost');
  file_text := (select blob_to_string (RES_CONTENT) from WS.WS.SYS_DAV_RES 
    where RES_FULL_PATH='/DAV/VAD/tutorial/rdfview/rd_v_1/rd_v_1.sql');
  file_text := replace(file_text, 'URIQA2_MACRO', uriqa);
  update WS.WS.SYS_DAV_RES set RES_CONTENT=file_text where RES_FULL_PATH='/DAV/VAD/tutorial/rdfview/rd_v_1/rd_v_1.sql';

  file_text := (select blob_to_string (RES_CONTENT) from WS.WS.SYS_DAV_RES 
    where RES_FULL_PATH='/DAV/VAD/tutorial/rdfview/rd_v_1/rd_v_1.owl');
  file_text := replace(file_text, 'URIQA_MACRO', uriqa);
  update WS.WS.SYS_DAV_RES set RES_CONTENT=file_text where RES_FULL_PATH='/DAV/VAD/tutorial/rdfview/rd_v_1/rd_v_1.owl';
}
;

DB.DBA.rd_v_1_localize()
;

drop procedure DB.DBA.rd_v_1_localize
;

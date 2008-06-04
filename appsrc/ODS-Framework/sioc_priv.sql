use sioc;

-- private graph policy
-- XXX: disabled until tested
--DB.DBA.TABLE_DROP_POLICY ('DB.DBA.RDF_QUAD', 'S');

create procedure ODS.DBA.RDF_POLICY (in tb varchar, in op varchar)
{
  declare chost, ret varchar;
  chost := DB.DBA.WA_CNAME ();
  ret := sprintf ('(ID_TO_IRI (G) NOT LIKE \'http://%s/dataspace/%%/private#\' ' ||
  'OR G = IRI_TO_ID (sprintf (\'http://%s/dataspace/%%U/private#\', USER)))', chost, chost);
  return ret;
}
;

grant execute on ODS.DBA.RDF_POLICY to public;

--DB.DBA.TABLE_SET_POLICY ('DB.DBA.RDF_QUAD', 'ODS.DBA.RDF_POLICY', 'S');


create procedure priv_graph (in uname varchar)
{
  return sprintf ('%s/%U/private#', get_graph (), uname);
}
;

create procedure inv_iri (in uname varchar, in id varchar)
{
  return sprintf ('%s/%U/invitation/%s', get_graph (), uname, id);
}
;

create procedure log_iri (in site_iri varchar, in host_id int, in log_id int)
{
  return sprintf ('%s/logs/%d/%s', site_iri, host_id, log_id);
}
;

create procedure ods_init_private_graph (in uname varchar)
{
  declare graph_iri, site_iri, svc, container, user_iri, iri any;

  graph_iri := priv_graph (uname);
  site_iri := get_graph ();
  user_iri := user_obj_iri (uname);
  for select AP_HOST_ID, WAI_TYPE_NAME, WAI_NAME from ODS.DBA.APP_PING_REG, DB.DBA.WA_INSTANCE, DB.DBA.WA_MEMBER, DB.DBA.SYS_USERS where
    WAI_ID = AP_WAI_ID and WAI_NAME = WAM_INST and U_NAME = uname and WAM_USER = U_ID do
      {
	container := forum_iri (WAI_TYPE_NAME, WAI_NAME);
	svc := service_iri (site_iri, AP_HOST_ID);
	DB.DBA.RDF_QUAD_URI (graph_iri, container, sioc_iri ('has_service'), svc);
	DB.DBA.RDF_QUAD_URI (graph_iri, svc, sioc_iri ('service_of'), container);
      }
  for select WAM_APP_TYPE, WI_TO_MAIL, WI_INSTANCE, WI_SID, WI_STATUS from DB.DBA.WA_INVITATIONS, DB.DBA.WA_MEMBER, DB.DBA.SYS_USERS
    where WAM_INST = WI_INSTANCE and WAM_USER = U_ID and U_NAME = uname do
      {
	container := forum_iri (WAM_APP_TYPE, WI_INSTANCE);
	iri := inv_iri (uname, WI_SID);
	DB.DBA.RDF_QUAD_URI (graph_iri, user_iri, foaf_iri ('made'), iri);
	DB.DBA.RDF_QUAD_URI (graph_iri, iri, foaf_iri ('maker'), user_iri);
	DB.DBA.RDF_QUAD_URI (graph_iri, iri, rdf_iri ('type'), ext_iri ('Invitation'));
	DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, rdfs_iri ('label'), 'Invitation for '||WI_INSTANCE);
	DB.DBA.RDF_QUAD_URI (graph_iri, iri, dc_iri ('identifier'), WI_SID);
      }
  for select WAM_APP_TYPE, WAI_NAME, APL_HOST_ID, APL_WAI_ID, APL_P_TITLE, APL_P_URL, APL_STAT, APL_SENT, APL_ERROR, APL_SEQ from
    ODS.DBA.APP_PING_LOG, DB.DBA.WA_MEMBER, DB.DBA.SYS_USERS, DB.DBA.WA_INSTANCE where
	WAM_INST = WAI_NAME and APL_WAI_ID = WAI_ID and WAM_USER = U_ID and U_NAME = uname do
      {
	svc := service_iri (site_iri, APL_HOST_ID);
	iri := log_iri (site_iri, APL_HOST_ID, APL_SEQ);
	container := forum_iri (WAM_APP_TYPE, WAI_NAME);
	DB.DBA.RDF_QUAD_URI (graph_iri, svc, sioc_iri ('container_of'), iri);
	DB.DBA.RDF_QUAD_URI (graph_iri, iri, sioc_iri ('has_container'), svc);

	DB.DBA.RDF_QUAD_URI (graph_iri, iri, rdf_iri ('type'), ext_iri ('LogEntry'));
	DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, dc_iri ('date'), APL_SENT);
	DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, dc_iri ('description'), APL_ERROR);
	DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, ext_iri ('status'), APL_STAT);
	DB.DBA.RDF_QUAD_URI_L (graph_iri, iri, dc_iri ('identifier'), APL_SEQ);
      }
}
;

use DB;

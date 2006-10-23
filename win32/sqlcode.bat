rm -f sql_code.c sql_code_1.c sql_code_ddk.c sql_code_adm.c sql_code_dav.c sql_code_vad.c sql_code_dbp.c sql_code_uddi.c sql_code_imsg.c sql_code_auto.c sql_code_2pc.c sql_code_vdb.c sql_code_sparql.c 

set SQL_FILES=../../binsrc/vsp/vsp_auth.sql snapshot_repl.sql system.sql system2.sql soap.sql xmla.sql wsrp_ultim.xsl wsrp_resp.xsl wsrp_interm.xsl wsrp_error.xsl soap_sch.xsl soap_import_sch.xsl  odbccat.sql useraggr.sql wsdl_expand.xsl wsdl_parts.xsl wsdl_import.xsl xmlrpc_soap.xsl soap_xmlrpc.xsl soap12_router.xsl ../../binsrc/ws/wsrm/wsrm_ddl.sql ../../binsrc/ws/wsrm/wsrm_xsd.sql ../../binsrc/ws/wsrm/wsrmcli.sql ../../binsrc/ws/wsrm/wsrmsrv.sql ../../binsrc/ws/wstr/wstr_ddl.sql ../../binsrc/ws/wstr/wstrcli.sql ../../binsrc/ws/wstr/wstrsrv.sql ../../binsrc/sync/syncml.sql ../../binsrc/sync/wbxml.sql ../../binsrc/ws/wsrm/wsrmcall.xsl cov_report.xsl cov_time.xsl
gawk -f sql_to_c.awk -v pl_stats=PLDBG %SQL_FILES% > sql_code.c

set SQL_FILES_1=oledb.sql information_schema.sql http_auth.sql xmla.sql vt_text.sql xml_view.sql openxml.sql ../../binsrc/vspx/vspx.sql ../../binsrc/vspx/vspx_add_locations.xsl ../../binsrc/vspx/vspx_pre_xsd.xsl ../../binsrc/vspx/vspx_expand.xsl ../../binsrc/vspx/vspx_pre_sql.xsl ../../binsrc/vspx/vspx_log_format.xsl ../../binsrc/vspx/vspx.xsd ../../binsrc/vspx/vspx.xsl hosting.sql
gawk -f sql_to_c.awk -v init_name=_1 -v pl_stats=PLDBG %SQL_FILES_1% > sql_code_1.c

set SQL_FILES_DDK=users.sql replddk.sql ../../binsrc/tests/dav/davddk.sql mail_cli.sql ../../binsrc/vsp/admin/admin_ddl.sql ../../binsrc/vsp/admin/admin_dav/vfsddk.sql virtual_dir.sql
gawk -f sql_to_c.awk -v init_name=_ddk -v pl_stats=PLDBG %SQL_FILES_DDK% > sql_code_ddk.c

set SQL_FILES_ADM=../../binsrc/vsp/admin/admin.sql ../../binsrc/vspx/browser/admin_dav_browser.sql repl.sql
gawk -f sql_to_c.awk -v init_name=_adm -v pl_stats=PLDBG %SQL_FILES_ADM% > sql_code_adm.c

set SQL_FILES_DAV=../../binsrc/tests/dav/dav.sql ../../binsrc/tests/dav/dav_api.sql ../../binsrc/tests/dav/dav_acct.sql ../../binsrc/tests/dav/dav_meta.sql ../../binsrc/tests/dav/dav_rdf_quad.sql ../../binsrc/vsp/admin/admin_dav/vfs.sql ../../binsrc/tests/dav/davxml2rdfxml.xsl ../../binsrc/tests/dav/davxml2n3xml.xsl ../../binsrc/tests/dav/rdfxml2n3xml.xsl ../../binsrc/tests/dav/n3xml2uriqahtml.xsl ../../binsrc/tests/dav/uriqa.sql ../../binsrc/tests/dav/DET_CatFilter.sql ../../binsrc/tests/dav/DET_HostFs.sql ../../binsrc/tests/dav/DET_ResFilter.sql ../../binsrc/tests/dav/DET_PropFilter.sql ../../binsrc/tests/dav/Versioning/DET_Versioning.sql ../../binsrc/tests/dav/erdf2rdfxml.xsl ../../binsrc/tests/dav/rdfa2rdfxml.xsl
gawk -f sql_to_c.awk -v init_name=_dav -v pl_stats=PLDBG %SQL_FILES_DAV% > sql_code_dav.c

set SQL_FILES_VAD=../../binsrc/vad/vad_root.sql ../../binsrc/vad/vad_misc.sql ../../binsrc/vad/oper_pars.sql ../../binsrc/vad/pars_init.sql ../../binsrc/vad/vad_make.sql
gawk -f sql_to_c.awk -v init_name=_vad -v pl_stats=PLDBG %SQL_FILES_VAD% > sql_code_vad.c

set SQL_FILES_DBP=../../binsrc/vsp/admin/dbpump/dbpump_root.sql ../../binsrc/vsp/admin/dbpump/oper_pars.sql ../../binsrc/vsp/admin/dbpump/components.sql ../../binsrc/vsp/admin/dbpump/comp_html.sql ../../binsrc/vsp/admin/dbpump/comp_misc.sql ../../binsrc/vsp/admin/dbpump/comp_rpath.sql ../../binsrc/vsp/admin/dbpump/comp_tables.sql ../../binsrc/vsp/admin/dbpump/pars_init.sql
gawk -f sql_to_c.awk -v init_name=_dbp -v pl_stats=PLDBG %SQL_FILES_DBP% > sql_code_dbp.c

set SQL_FILES_UDDI=uddi.sql
gawk -f sql_to_c.awk -v init_name=_uddi -v pl_stats=PLDBG %SQL_FILES_UDDI% > sql_code_uddi.c
 
set SQL_FILES_IMSG=pop3_svr.sql ftp.sql nn_svr.sql ../../binsrc/vsp/admin/admin_news/admin_news.sql
gawk -f sql_to_c.awk -v init_name=_imsg -v pl_stats=PLDBG %SQL_FILES_IMSG% > sql_code_imsg.c

set SQL_FILES_AUTO=autoexec.sql
gawk -f sql_to_c.awk -v init_name=_auto -v pl_stats=PLDBG %SQL_FILES_AUTO% > sql_code_auto.c

set SQL_FILES_2PC=2pc.sql
gawk -f sql_to_c.awk -v init_name=_2pc -v pl_stats=PLDBG %SQL_FILES_2PC% > sql_code_2pc.c

set SQL_FILES_VDB=vdb.sql
gawk -f sql_to_c.awk -v init_name=_vdb -v pl_stats=PLDBG %SQL_FILES_VDB% > sql_code_vdb.c

set SQL_FILES_SPARQL=sparql.sql 
gawk -f sql_to_c.awk -v init_name=_sparql -v pl_stats=PLDBG %SQL_FILES_SPARQL% > sql_code_sparql.c

gawk -f "jso_reformat.awk" -v "output_mode=h" -v "h_wrapper=__RDF_MAPPING_JSO_H" rdf_mapping.jso > rdf_mapping_jso.h

gawk -f "jso_reformat.awk" -v "output_mode=c" rdf_mapping.jso > rdf_mapping_jso.c

gawk -f "jso_reformat.awk" -v "output_mode=ttl" rdf_mapping.jso > rdf_mapping_jso.ttl

gawk -f "jso_reformat.awk" -v "output_mode=ttl-sample" rdf_mapping.jso > rdf_mapping_jso.ttl-sample

@echo #include "sql_code_cache_impl.c" > sql_code_cache.c
@echo #include "../../binsrc/cached_resources/cached_resources.c" >> sql_code_cache.c

bash list_lex_props.sh sparql_p.y sparql_lex_props.c
bash list_lex_props.sh turtle_p.y turtle_lex_props.c 


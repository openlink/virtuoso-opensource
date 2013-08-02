set SQL_FILES=system.sql system2.sql odbccat.sql vt_text.sql phrasematch.sql hosting.sql
set SQL_FILES_1=oledb.sql information_schema.sql
set SQL_FILES_WS=../../binsrc/vsp/vsp_auth.sql soap.sql wsrp_ultim.xsl wsrp_resp.xsl wsrp_interm.xsl wsrp_error.xsl soap_sch.xsl soap_import_sch.xsl wsdl_expand.xsl wsdl_parts.xsl wsdl_import.xsl wsdl2rdf.xsl xmlrpc_soap.xsl soap_xmlrpc.xsl soap12_router.xsl ../../binsrc/ws/wsrm/wsrm_ddl.sql ../../binsrc/ws/wsrm/wsrm_xsd.sql ../../binsrc/ws/wsrm/wsrmcli.sql ../../binsrc/ws/wsrm/wsrmsrv.sql ../../binsrc/ws/wstr/wstr_ddl.sql ../../binsrc/ws/wstr/wstrcli.sql ../../binsrc/ws/wstr/wstrsrv.sql ../../binsrc/ws/wsrm/wsrmcall.xsl rdf_net.sql simile.sql http_auth.sql xmla.sql openxml.sql ../../binsrc/vspx/vspx.sql ../../binsrc/vspx/vspx_add_locations.xsl ../../binsrc/vspx/vspx_expand.xsl ../../binsrc/vspx/vspx_pre_xsd.xsl ../../binsrc/vspx/vspx_pre_sql.xsl ../../binsrc/vspx/vspx_log_format.xsl ../../binsrc/vspx/vspx.xsd ../../binsrc/vspx/vspx.xsl
set SQL_FILES_REPL=snapshot_repl.sql repl.sql
set SQL_FILES_DAV=../../binsrc/dav/dav.sql ../../binsrc/dav/dav_api.sql ../../binsrc/dav/dav_meta.sql ../../binsrc/dav/dav_acct.sql ../../binsrc/dav/dav_rdf_quad.sql ../../binsrc/vsp/admin/admin_dav/vfs.sql ../../binsrc/dav/davxml2rdfxml.xsl ../../binsrc/dav/davxml2n3xml.xsl ../../binsrc/dav/rdfxml2n3xml.xsl ../../binsrc/dav/n3xml2uriqahtml.xsl ../../binsrc/dav/uriqa.sql ../../binsrc/dav/DET_CatFilter.sql ../../binsrc/dav/DET_HostFs.sql ../../binsrc/dav/DET_ResFilter.sql ../../binsrc/dav/DET_PropFilter.sql ../../binsrc/dav/DET_RDFData.sql ../../binsrc/dav/Versioning/DET_Versioning.sql xml_view.sql ../../binsrc/dav/DET_S3.sql
set SQL_FILES_DDK=replddk.sql ../../binsrc/dav/davddk.sql mail_cli.sql ../../binsrc/vsp/admin/admin_ddl.sql ../../binsrc/vsp/admin/admin_dav/vfsddk.sql virtual_dir.sql url_rewrite.sql
set SQL_FILES_SYS=users.sql qlog.sql
set SQL_FILES_UDDI=uddi.sql
set SQL_FILES_IMSG=pop3_svr.sql ftp.sql nn_svr.sql ../../binsrc/vsp/admin/admin_news/admin_news.sql
set SQL_FILES_AUTO=autoexec.sql
set SQL_FILES_ADM=../../binsrc/vsp/admin/admin.sql ../../binsrc/vspx/browser/admin_dav_browser.sql
set SQL_FILES_2PC=2pc.sql
@rem set SQL_FILES_BLOG=../../binsrc/weblog2/widgets/rss2rdf.xsl
set SQL_FILES_VDB=vdb.sql
set SQL_FILES_PLDBG=cov_report.xsl cov_time.xsl
set SQL_FILES_VAD=../../binsrc/vad/vad_root.sql ../../binsrc/vad/vad_misc.sql ../../binsrc/vad/oper_pars.sql ../../binsrc/vad/pars_init.sql ../../binsrc/vad/vad_make.sql
set SQL_FILES_DBP=../../binsrc/vsp/admin/dbpump/dbpump_root.sql ../../binsrc/vsp/admin/dbpump/oper_pars.sql ../../binsrc/vsp/admin/dbpump/components.sql ../../binsrc/vsp/admin/dbpump/comp_html.sql ../../binsrc/vsp/admin/dbpump/comp_misc.sql ../../binsrc/vsp/admin/dbpump/comp_rpath.sql ../../binsrc/vsp/admin/dbpump/comp_tables.sql ../../binsrc/vsp/admin/dbpump/pars_init.sql
set SQL_FILES_SPARQL=sparql.sql sparql_io.sql rdf_sponge.sql rdf_schema_objects.sql rdf_void.sql rdflddir2.sql ttlpv.sql
set SQL_FILES_SPARQL_INIT=useraggr.sql sparql_init.sql

rm -f sql_code.c sql_code_1.c sql_code_ws.c sql_code_repl.c sql_code_dav.c sql_code_ddk.c sql_code_sys.c sql_code_uddi.c 
rm -f sql_code_imsg.c sql_code_auto.c sql_code_adm.c sql_code_2pc.c sql_code_vdb.c sql_code_pldbg.c 
rm -f sql_code_vad.c sql_code_dbp.c sql_code_sparql.c

gawk -f sql_to_c.awk                    -v pl_stats=PLDBG  %SQL_FILES%      > sql_code.c
gawk -f sql_to_c.awk -v init_name=_1 -v pl_stats=PLDBG %SQL_FILES_1% > sql_code_1.c
gawk -f sql_to_c.awk -v init_name=_ws   -v pl_stats=PLDBG  %SQL_FILES_WS%   > sql_code_ws.c
gawk -f sql_to_c.awk -v init_name=_repl -v pl_stats=PLDBG  %SQL_FILES_REPL% > sql_code_repl.c
gawk -f sql_to_c.awk -v init_name=_dav -v pl_stats=PLDBG %SQL_FILES_DAV% > sql_code_dav.c
gawk -f sql_to_c.awk -v init_name=_ddk  -v pl_stats=PLDBG  %SQL_FILES_DDK%  > sql_code_ddk.c
gawk -f sql_to_c.awk -v init_name=_sys  -v pl_stats=PLDBG  %SQL_FILES_SYS%  > sql_code_sys.c
gawk -f sql_to_c.awk -v init_name=_uddi -v pl_stats=PLDBG %SQL_FILES_UDDI% > sql_code_uddi.c
gawk -f sql_to_c.awk -v init_name=_imsg -v pl_stats=PLDBG %SQL_FILES_IMSG% > sql_code_imsg.c
gawk -f sql_to_c.awk -v init_name=_auto -v pl_stats=PLDBG %SQL_FILES_AUTO% > sql_code_auto.c
gawk -f sql_to_c.awk -v init_name=_adm  -v pl_stats=PLDBG  %SQL_FILES_ADM%  > sql_code_adm.c
gawk -f sql_to_c.awk -v init_name=_2pc -v pl_stats=PLDBG %SQL_FILES_2PC% > sql_code_2pc.c
@rem gawk -f sql_to_c.awk -v init_name=_blog -v pl_stats=PLDBG  %SQL_FILES_BLOG% > sql_code_blog.c
gawk -f sql_to_c.awk -v init_name=_vdb -v pl_stats=PLDBG %SQL_FILES_VDB% > sql_code_vdb.c
gawk -f sql_to_c.awk -v init_name=_pldbg -v pl_stats=PLDBG %SQL_FILES_PLDBG% > sql_code_pldbg.c
gawk -f sql_to_c.awk -v init_name=_vad  -v pl_stats=PLDBG  %SQL_FILES_VAD% > sql_code_vad.c
gawk -f sql_to_c.awk -v init_name=_dbp  -v pl_stats=PLDBG  %SQL_FILES_DBP% > sql_code_dbp.c
gawk -f sql_to_c.awk -v init_name=_sparql -v pl_stats=PLDBG %SQL_FILES_SPARQL% > sql_code_sparql.c
gawk -f sql_to_c.awk -v init_name=_sparql_init -v pl_stats=PLDBG %SQL_FILES_SPARQL_INIT% > sql_code_sparql_init.c

gawk -f "jso_reformat.awk" -v "output_mode=h" -v "h_wrapper=__RDF_MAPPING_JSO_H" -v "init_name=rdf_mapping" rdf_mapping.jso > rdf_mapping_jso.h

gawk -f "jso_reformat.awk" -v "output_mode=c" -v "init_name=rdf_mapping" rdf_mapping.jso > rdf_mapping_jso.c

gawk -f "jso_reformat.awk" -v "output_mode=ttl" -v "init_name=rdf_mapping" rdf_mapping.jso > rdf_mapping_jso.ttl

gawk -f "jso_reformat.awk" -v "output_mode=ttl-sample" -v "init_name=rdf_mapping" rdf_mapping.jso > rdf_mapping_jso.ttl-sample

cd ../../binsrc/cached_resources
bash cache_gen.sh > cached_resources.c
cd ../../libsrc/Wi

@echo #include "sql_code_cache_impl.c" > sql_code_cache.c
@echo #include "../../binsrc/cached_resources/cached_resources.c" >> sql_code_cache.c

bash list_lex_props.sh sparql_p.y sparql_lex_props.c
bash list_lex_props.sh turtle_p.y turtle_lex_props.c 


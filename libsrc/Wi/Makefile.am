#  
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#  
#  Copyright (C) 1998-2006 OpenLink Software
#  
#  This project is free software; you can redistribute it and/or modify it
#  under the terms of the GNU General Public License as published by the
#  Free Software Foundation; only version 2 of the License, dated June 1991.
#  
#  This program is distributed in the hope that it will be useful, but
#  WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
#  General Public License for more details.
#  
#  You should have received a copy of the GNU General Public License along
#  with this program; if not, write to the Free Software Foundation, Inc.,
#  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
#  
#  

if WITH_IODBC
    IODBC_LIBS = libwi_odbc.la
endif

if WITH_LDAP
    LDAP_BIF=bif_ldapcli.c
endif

if WITH_KERBEROS
    KRB_BIF=bif_kerberoscli.c
endif

if WITH_IMSG
    IMSG_BIF= bif_pop3.c bif_nntp.c
endif

noinst_LTLIBRARIES = libwi.la libwic.la $(IODBC_LIBS)
noinst_HEADERS = \
	2pc_client.h 2pc.h arith.h bif_text.h bif_xper.h blobio.h CLI.h \
	crsr.h date.h datesupp.h eqlcomp.h hosting.h http_client.h http.h \
	iodbcinst.h ksrvext.h ksrvextphp.h lisprdr.h list2.h log.h ltrx.h \
	map_schema.h msdtc.h mts_client.h mts_com.h mts.h multibyte.h \
	numeric.h odbcinc.h pldebug.h rdf_core.h recovery.h remote.h \
	rendezvous.h repl.h replsr.h schspace.h security.h sha.h shuric.h \
	soap.h sparql2sql.h sparql.h sparql_p.h sql3.h sqlbif.h sqlcmps.h \
	sqlcomp.h sqlcstate.h sqlfn.h sqlintrp.h sqlnode.h sqlocr.h sqlofn.h \
	sqlo.h sqloinv.h sqlopcod.h sqlparext.h sqlpar.h sqlpfn.h sqlrcomp.h \
	sqltype_c.h sqltype.h sqlver.h sqlwords.h srvmultibyte.h srvstat.h \
	statuslog.h strlike.h subseq.h text.h turtle_p.h uuencode_impl.h \
	virtext.h virtpwd.h widd.h widisk.h widv.h wifn.h wi.h wirpce.h \
	wiservic.h wi_xid.h xmlenc_algos.h xmlenc.h xmlenc_test.h xmlgen.h \
	xml.h xmlnode.h xmlres.h xmltree.h xpath.h xpathp.h xpathp_impl.h \
	xpf.h xqf.h xslt_impl.h


generated_code = \
	scn3.c \
	sparql_l.c \
	sparql_p.c \
	sparql_p.h \
	sql3.c \
	sqlwords.h \
	turtle_l.c \
	turtle_p.c \
	turtle_p.h \
	xpathp.c \
	xpathp.h \
	xpscn.c \
	sql_code.c \
	sql_code_1.c \
	sql_code_2pc.c \
	sql_code_adm.c \
	sql_code_auto.c \
	sql_code_cache.c \
	sql_code_dav.c \
	sql_code_dbp.c \
	sql_code_ddk.c \
	sql_code_imsg.c \
	sql_code_sparql.c \
	sql_code_uddi.c \
	sql_code_vad.c \
	sql_code_vdb.c

BUILT_SOURCES = $(generated_code)
CLEANFILES = \
	$(generated_code) \
	sparql_p.output sql3.output turtle_p.output xpathp.output


libwi_la_SOURCES = \
        sql3.c \
        scn3.c \
        xpathp.c \
        xpscn.c \
	sparql_l.c \
	sparql_p.c \
	turtle_l.c \
	turtle_p.c \
	schspace.c \
	arith.c \
	auxfiles.c \
	bif_diff.c \
	bif_intl.c \
	bif_regexp.c \
	blob.c \
	blobio.c \
	datesupp.c \
	ddlrun.c \
	dks_esc.c \
	disk.c \
	eqlcomp.c \
	gate.c \
	http.c \
	insert.c \
	lisprdr.c \
	lock.c \
	log.c \
	meta.c \
	mtwrite.c \
	multibyte.c \
	neodisk.c \
	numeric.c \
	obackup.c \
	recovery.c \
	regist.c \
	rltrx.c \
	row.c \
	search.c \
	hash.c \
	security.c \
	sort.c \
	space.c \
	sqlbif.c \
	sqlbif2.c \
	sqlcomp.c \
	sqlcomp2.c \
	sqlcr.c \
	sqlexp.c \
	sqlintrp.c \
	sqlorder.c \
	sqloinx.c \
	sqlpfn.c \
	sqlprocc.c \
	sqlo.c \
	sqldf.c \
	sqloby.c \
	sqlcost.c \
	sqloprt.c \
	sqlgen.c \
	sqlhash.c \
	sqlovdb.c \
	sqlocr.c \
	sqloinv.c \
	sqlprt.c \
	sqlrun.c \
	inxop.c \
	sqlsrv.c \
	sqlstmts.c \
	sqltrig.c \
	sqlver.c \
	sqlview.c \
	srvcr.c \
	srvmultibyte.c \
	srvstat.c \
	string.c \
	update.c \
	wirpc.c \
	wiservic.c \
	bif_crypto.c \
	sql_code.c \
	sql_code_1.c \
	sql_code_dav.c \
	sql_code_ddk.c \
	sql_code_uddi.c \
	sql_code_imsg.c \
	sql_code_auto.c \
	sql_code_adm.c \
	sql_code_2pc.c \
	sql_code_cache.c \
	sql_code_blog.c \
	sql_code_vdb.c \
	sql_code_sparql.c \
	bif_uuencode.c \
	map_schema.c \
	uuencode.c \
	sqltype.c \
	hosting.c \
	plugin_loader.c \
	bif_diff.c \
	sql_code_vad.c \
	sql_code_dbp.c \
	rendezvous.c \
	rdf_core.c
	
libwi_odbc_la_SOURCES = \
        sql3.c \
        scn3.c \
        xpathp.c \
        xpscn.c \
	sparql_l.c \
	sparql_p.c \
	turtle_l.c \
	turtle_p.c \
	schspace.c \
	arith.c \
	auxfiles.c \
	bif_diff.c \
	bif_intl.c \
	bif_regexp.c \
	blob.c \
	blobio.c \
	datesupp.c \
	ddlrun.c \
	dks_esc.c \
	disk.c \
	eqlcomp.c \
	gate.c \
	http.c \
	insert.c \
	lisprdr.c \
	lock.c \
	log.c \
	meta.c \
	mtwrite.c \
	multibyte.c \
	neodisk.c \
	numeric.c \
	obackup.c \
	recovery.c \
	regist.c \
	rltrx.c \
	row.c \
	search.c \
	hash.c \
	security.c \
	sort.c \
	space.c \
	sqlbif.c \
	sqlbif2.c \
	sqlcomp.c \
	sqlcomp2.c \
	sqlcr.c \
	sqlexp.c \
	sqlintrp.c \
	sqlorder.c \
	sqloinx.c \
	sqlpfn.c \
	sqlprocc.c \
	sqlo.c \
	sqldf.c \
	sqloby.c \
	sqlcost.c \
	sqloprt.c \
	sqlgen.c \
	sqlhash.c \
	sqlovdb.c \
	sqlocr.c \
	sqloinv.c \
	sqlprt.c \
	sqlrun.c \
	inxop.c \
	sqlsrv.c \
	sqlstmts.c \
	sqltrig.c \
	sqlver.c \
	sqlview.c \
	srvcr.c \
	srvmultibyte.c \
	srvstat.c \
	string.c \
	update.c \
	wirpc.c \
	wiservic.c \
	bif_crypto.c \
	sql_code.c \
	sql_code_1.c \
	sql_code_dav.c \
	sql_code_ddk.c \
	sql_code_uddi.c \
	sql_code_imsg.c \
	sql_code_auto.c \
	sql_code_adm.c \
	sql_code_2pc.c \
	sql_code_cache.c \
	sql_code_blog.c \
	sql_code_vdb.c \
	sql_code_sparql.c \
	bif_uuencode.c \
	map_schema.c \
	uuencode.c \
	sqltype.c \
	hosting.c \
	plugin_loader.c \
	bif_diff.c \
	sql_code_vad.c \
	sql_code_dbp.c \
	rendezvous.c \
	rdf_core.c
	
# can make that conditional if need be SPARQL
libwi_la_SOURCES += \
	sparql2sql.c \
	sparql2sqltext.c \
	sparql_core.c

libwi_odbc_la_SOURCES += \
	sparql2sql.c \
	sparql2sqltext.c \
	sparql_core.c

#KUBL_REPL_FILES
libwi_la_SOURCES += \
	repldb.c \
	replsri.c \
	replsub.c \
	replpush.c

libwi_odbc_la_SOURCES += \
	repldb.c \
	replsri.c \
	replsub.c \
	replpush.c

#PLDEBUG_FILES
libwi_la_SOURCES += \
	pldebug.c

libwi_odbc_la_SOURCES += \
	pldebug.c

#BIF_FILES
libwi_la_SOURCES += \
	bif_dav.c \
	bif_soap.c \
	bif_text.c \
	bif_phrasematch.c \
	bif_tidy.c \
	shuric.c \
	text.c \
	xmlschema.c \
	xmlsearch.c \
	xmlsql.c \
	xmltree.c \
	xslt.c \
	xslt_fmt.c \
	xslt_opt.c \
	xpath.c \
	xpf.c \
	xqf.c \
	xmlenc.c \
	xmlenc_algos.c \
	xmlenc-dec.c \
	subseq.c \
	bif_date.c \
	bif_explain.c \
	bif_file.c \
	bif_smtp.c \
	http_client.c \
	$(LDAP_BIF) \
	$(KRB_BIF) \
	$(IMSG_BIF)

libwi_odbc_la_SOURCES += \
	bif_dav.c \
	bif_soap.c \
	bif_text.c \
	bif_phrasematch.c \
	bif_tidy.c \
	shuric.c \
	text.c \
	xmlschema.c \
	xmlsearch.c \
	xmlsql.c \
	xmltree.c \
	xslt.c \
	xslt_fmt.c \
	xslt_opt.c \
	xpath.c \
	xpathp.c \
	xpf.c \
	xqf.c \
	xmlenc.c \
	xmlenc_algos.c \
	xmlenc-dec.c \
	subseq.c \
	bif_date.c \
	bif_explain.c \
	bif_file.c \
	bif_smtp.c \
	http_client.c \
	$(LDAP_BIF) \
	$(KRB_BIF) \
	$(IMSG_BIF)

#BIF_XPER
libwi_la_SOURCES += \
	bif_xper.c

libwi_odbc_la_SOURCES += \
	bif_xper.c

libwi_base_la_cflags  = @VIRT_AM_CFLAGS@
libwi_base_la_cflags  += -Dlint -DNEW_HASH 
libwi_base_la_cflags  += -I$(top_srcdir)/libsrc
libwi_base_la_cflags  += -I$(top_srcdir)/libsrc/Dk 
libwi_base_la_cflags  += -I$(top_srcdir)/libsrc/zlib 
libwi_base_la_cflags  += -I$(top_srcdir)/libsrc/Wi 
libwi_base_la_cflags  += -I$(top_srcdir)/libsrc/langfunc 
libwi_base_la_cflags  += -I$(top_srcdir)/libsrc/plugin 
libwi_base_la_cflags  += -I$(top_srcdir)/libsrc/Tidy 
libwi_base_la_cflags  += -I$(top_srcdir)/libsrc/Xml.new
libwi_base_la_cflags  += -I$(top_srcdir)/libsrc/odbcsdk/include
libwi_base_la_cflags  += -DVAD
libwi_base_la_cflags  += -DDBP
libwi_base_la_cflags  += -DBIF_XPER -DOPSYS=\"@OPSYS@\" -DHOST=\"@host@\"
libwi_base_la_ldlags  = -static

#KUBL_UNIV_FILES
libwi_la_SOURCES += \
	sqlrbuf.c \
	sqlrcomp.c \
	sqlrrun.c \
	odbccat.c \
	bif_repl.c \
	2pc.c \
	wi_xid.c \
	bif_xml.c \
	$(libwi_base_la_sources)

libwi_la_CFLAGS  = $(libwi_base_la_cflags)
libwi_la_LDLAGS  = -static

#KUBL_UNIV_FILES_ODBC
libwi_odbc_la_SOURCES += \
	sqlrbuf.c \
	sqlrcomp.c \
	sqlrrun.c \
	odbccat.c \
	bif_repl.c \
	2pc.c \
	wi_xid.c \
	bif_xml.c

libwi_odbc_la_CFLAGS  = $(libwi_base_la_cflags)
libwi_odbc_la_CFLAGS  += -DUNIX_ODBC
libwi_odbc_la_LDLAGS  = -static

libwic_la_SOURCES = \
	CLIuti.c \
	CLIsql1.c \
	CLIsql2.c \
	CLIsql3.c \
	CLIodbc3.c \
	wirpc.c \
	wi_xid.c \
	blobio.c \
	datesupp.c \
	numeric.c \
	CLIcr.c \
	multibyte.c \
	CLIsql3W.c \
	CLIw.c

#PLDEBUG_CLI_FILES
libwic_la_SOURCES += \
	pldbgcli.c

libwic_la_CFLAGS  = @VIRT_AM_CFLAGS@
libwic_la_CFLAGS  += -I$(top_srcdir)/libsrc
libwic_la_CFLAGS  += -I$(top_srcdir)/libsrc/Dk 
libwic_la_CFLAGS  += -I$(top_srcdir)/libsrc/plugin 
libwic_la_CFLAGS  += -I$(top_srcdir)/libsrc/langfunc
libwic_la_CFLAGS  += -I$(top_srcdir)/libsrc/odbcsdk/include
libwic_la_LDLAGS  = -static

###################################################################
#generated stuff
SQL_FILES		= \
	$(top_srcdir)/binsrc/vsp/vsp_auth.sql \
	snapshot_repl.sql \
	system.sql \
	system2.sql \
	soap.sql \
	wsrp_ultim.xsl \
	wsrp_resp.xsl \
	wsrp_interm.xsl \
	wsrp_error.xsl \
	soap_sch.xsl \
	soap_import_sch.xsl \
	odbccat.sql \
	useraggr.sql \
	wsdl_expand.xsl \
	wsdl_parts.xsl \
	wsdl_import.xsl \
	xmlrpc_soap.xsl \
	soap_xmlrpc.xsl \
	soap12_router.xsl \
	$(top_srcdir)/binsrc/ws/wsrm/wsrm_ddl.sql \
	$(top_srcdir)/binsrc/ws/wsrm/wsrm_xsd.sql \
	$(top_srcdir)/binsrc/ws/wsrm/wsrmcli.sql \
	$(top_srcdir)/binsrc/ws/wsrm/wsrmsrv.sql \
	$(top_srcdir)/binsrc/ws/wstr/wstr_ddl.sql \
	$(top_srcdir)/binsrc/ws/wstr/wstrcli.sql \
	$(top_srcdir)/binsrc/ws/wstr/wstrsrv.sql \
	$(top_srcdir)/binsrc/sync/syncml.sql \
	$(top_srcdir)/binsrc/sync/wbxml.sql \
	$(top_srcdir)/binsrc/ws/wsrm/wsrmcall.xsl \
	cov_report.xsl \
	cov_time.xsl

#SQL_FILES_BLOG		= \
#	$(top_srcdir)/binsrc/weblog2/widgets/rss2rdf.xsl 

SQL_FILES_VDB		= \
	vdb.sql

SQL_FILES_SPARQL	= \
	sparql.sql \
	$(top_srcdir)/binsrc/tests/rdf/rdf-exp-load.xsl \
	$(top_srcdir)/binsrc/tests/rdf/rdf-exp-rdfxml2dict.xsl

SQL_FILES_1		= \
	oledb.sql \
        information_schema.sql

SQL_FILES_DDK		= \
	users.sql \
	replddk.sql \
	$(top_srcdir)/binsrc/tests/dav/davddk.sql \
	mail_cli.sql \
	$(top_srcdir)/binsrc/vsp/admin/admin_ddl.sql \
	$(top_srcdir)/binsrc/vsp/admin/admin_dav/vfsddk.sql \
	virtual_dir.sql

SQL_FILES_DBP		= \
	$(top_srcdir)/binsrc/vsp/admin/dbpump/dbpump_root.sql \
	$(top_srcdir)/binsrc/vsp/admin/dbpump/oper_pars.sql \
	$(top_srcdir)/binsrc/vsp/admin/dbpump/components.sql \
	$(top_srcdir)/binsrc/vsp/admin/dbpump/comp_html.sql \
	$(top_srcdir)/binsrc/vsp/admin/dbpump/comp_misc.sql \
	$(top_srcdir)/binsrc/vsp/admin/dbpump/comp_rpath.sql \
	$(top_srcdir)/binsrc/vsp/admin/dbpump/comp_tables.sql \
	$(top_srcdir)/binsrc/vsp/admin/dbpump/pars_init.sql

SQL_FILES_2PC		= \
	2pc.sql

SQL_FILES_1		+= \
	http_auth.sql \
	xmla.sql \
	vt_text.sql \
	xml_view.sql \
	openxml.sql \
	$(top_srcdir)/binsrc/vspx/vspx.sql \
	$(top_srcdir)/binsrc/vspx/vspx_add_locations.xsl \
	$(top_srcdir)/binsrc/vspx/vspx_expand.xsl \
	$(top_srcdir)/binsrc/vspx/vspx_pre_xsd.xsl \
	$(top_srcdir)/binsrc/vspx/vspx_pre_sql.xsl \
	$(top_srcdir)/binsrc/vspx/vspx_log_format.xsl \
	$(top_srcdir)/binsrc/vspx/vspx.xsd \
	$(top_srcdir)/binsrc/vspx/vspx.xsl \
	hosting.sql 

#	$(top_srcdir)/binsrc/tags/phrasematch.sql 

SQL_FILES_AUTO		= \
	autoexec.sql

SQL_FILES_ADM		= \
	$(top_srcdir)/binsrc/vsp/admin/admin.sql \
	$(top_srcdir)/binsrc/vspx/browser/admin_dav_browser.sql

SQL_FILES_DAV		= \
	$(top_srcdir)/binsrc/tests/dav/dav.sql \
	$(top_srcdir)/binsrc/tests/dav/dav_api.sql \
	$(top_srcdir)/binsrc/tests/dav/dav_acct.sql \
	$(top_srcdir)/binsrc/vsp/admin/admin_dav/vfs.sql \
	davxml2rdfxml.xsl \
	davxml2n3xml.xsl \
	rdfxml2n3xml.xsl \
	n3xml2uriqahtml.xsl \
	$(top_srcdir)/binsrc/tests/dav/uriqa.sql \
	$(top_srcdir)/binsrc/tests/dav/DET_CatFilter.sql \
	$(top_srcdir)/binsrc/tests/dav/DET_HostFs.sql \
	$(top_srcdir)/binsrc/tests/dav/DET_ResFilter.sql \
	$(top_srcdir)/binsrc/tests/dav/DET_PropFilter.sql \
	$(top_srcdir)/binsrc/tests/dav/Versioning/DET_Versioning.sql

SQL_FILES_VAD		= \
	$(top_srcdir)/binsrc/vad/vad_root.sql \
	$(top_srcdir)/binsrc/vad/vad_misc.sql \
	$(top_srcdir)/binsrc/vad/oper_pars.sql \
	$(top_srcdir)/binsrc/vad/pars_init.sql \
	$(top_srcdir)/binsrc/vad/vad_make.sql

SQL_FILES_UDDI		= \
	uddi.sql

SQL_FILES_ADM		+= repl.sql

if WITH_IMSG
SQL_FILES_IMSG		 = pop3_svr.sql \
			   ftp.sql \
			   nn_svr.sql \
			   ../../binsrc/vsp/admin/admin_news/admin_news.sql
endif

sqlwords.h: sqlwords.gperf
if HAVE_GPERF
	$(GPERF) -aCDGptr -Kkeiiyword -L ANSI-C -k1,2,3,6,9,$$ sqlwords.gperf -Nlex_hash_kw | sed -e 's/char \*keyword/char *keiiyword/g' >sqlwords.h
else
	$(SHELL) $(top_srcdir)/binsrc/config/missing gperf -v
	touch sqlwords.h
endif

sql3.c: sql3.y
	$(YACC) -vd -osql3.c ../../libsrc/Wi/sql3.y

sql3.h: sql3.c
	## Recover from the removal of $@
	@if test -f $@; then :; else \
	  rm -f sql3.c; \
	  $(MAKE) $(AM_MAKEFLAGS) sql3.c; \
	fi

scn3.c: scn3.l sql3.c sqlwords.h
	$(LEX) -i -oscn3.c ../../libsrc/Wi/scn3.l

sql_code_cache.c: ../../binsrc/cached_resources/cached_resources.c sql_code_cache_impl.c
	@echo "#include \"sql_code_cache_impl.c\"" > $@
	@echo "#include \"../../binsrc/cached_resources/cached_resources.c\"" >> $@

xpathp.c: xpathp.y
	$(YACC) -vd -oxpathp.c -pxpyy ../../libsrc/Wi/xpathp.y

xpathp.h: xpathp.c
	## Recover from the removal of $@
	@if test -f $@; then :; else \
	  rm -f xpathp.c; \
	  $(MAKE) $(AM_MAKEFLAGS) xpathp.c; \
	fi

xpathp_lex_props.c: list_lex_props.sh xpathp.y
	list_lex_props.sh xpathp.y xpathp_lex_props.c

xpscn.c: xpscn.l xpathp.h
	$(LEX) -Pxpyy -oxpscn.c ../../libsrc/Wi/xpscn.l

sparql_p.c: sparql_p.y
	$(YACC) -vd -osparql_p.c -psparyy ../../libsrc/Wi/sparql_p.y

sparql_p.h: sparql_p.c
	## Recover from the removal of $@
	@if test -f $@; then :; else \
	  rm -f sparql_p.c; \
	  $(MAKE) $(AM_MAKEFLAGS) sparql_p.c; \
	fi

sparql_lex_props.c: list_lex_props.sh sparql_p.y
	list_lex_props.sh sparql_p.y sparql_lex_props.c

sparql_l.c: sparql_l.l sparql_p.h
	$(LEX) -8 -Psparyy -osparql_l.c ../../libsrc/Wi/sparql_l.l

turtle_p.c: turtle_p.y
	$(YACC) -vd -oturtle_p.c -pttlyy ../../libsrc/Wi/turtle_p.y

turtle_p.h: turtle_p.c
	## Recover from the removal of $@
	@if test -f $@; then :; else \
	  rm -f turtle_p.c; \
	  $(MAKE) $(AM_MAKEFLAGS) turtle_p.c; \
	fi

turtle_lex_props.c: list_lex_props.sh turtle_p.y
	list_lex_props.sh turtle_p.y turtle_lex_props.c

turtle_l.c: turtle_l.l turtle_p.h
	$(LEX) -8 -Pttlyy -oturtle_l.c ../../libsrc/Wi/turtle_l.l

sql_code.c: $(SQL_FILES) $(AWK_FILES)
	@echo "Generating sql_code.c"
	@-LANG=C gawk -f sql_to_c.awk -v pl_stats=$(PLSTATS) $(SQL_FILES) > sql_code.c.tmp
	@-[ -s sql_code.c.tmp ] && mv sql_code.c.tmp sql_code.c
	@touch sql_code.c

sql_code_1.c: $(SQL_FILES_1) $(AWK_FILES)
	@echo "Generating sql_code_1.c"
	@-LANG=C gawk -f sql_to_c.awk -v init_name=_1 -v pl_stats=$(PLSTATS) $(SQL_FILES_1) > sql_code_1.c.tmp
	@-[ -s sql_code_1.c.tmp ] && mv sql_code_1.c.tmp sql_code_1.c
	@touch sql_code_1.c

sql_code_ddk.c: $(SQL_FILES_DDK) $(AWK_FILES)
	@echo "Generating sql_code_ddk.c"
	@-LANG=C gawk -f sql_to_c.awk -v init_name=_ddk -v pl_stats=$(PLSTATS) $(SQL_FILES_DDK) > sql_code_ddk.c.tmp
	@-[ -s sql_code_ddk.c.tmp ] && mv sql_code_ddk.c.tmp sql_code_ddk.c
	@touch sql_code_ddk.c

sql_code_adm.c: $(SQL_FILES_ADM) $(AWK_FILES)
	@echo "Generating sql_code_adm.c"
	@-LANG=C gawk -f sql_to_c.awk -v init_name=_adm -v pl_stats=$(PLSTATS) $(SQL_FILES_ADM) > sql_code_adm.c.tmp
	@-[ -s sql_code_adm.c.tmp ] && mv sql_code_adm.c.tmp sql_code_adm.c
	@touch sql_code_adm.c

sql_code_dav.c: $(SQL_FILES_DAV) $(AWK_FILES)
	@echo "Generating sql_code_dav.c"
	@-LANG=C gawk -f sql_to_c.awk -v init_name=_dav -v pl_stats=$(PLSTATS) $(SQL_FILES_DAV) > sql_code_dav.c.tmp
	@-[ -s sql_code_dav.c.tmp ] && mv sql_code_dav.c.tmp sql_code_dav.c
	@touch sql_code_dav.c

sql_code_vad.c: $(SQL_FILES_VAD) $(AWK_FILES)
	@echo "Generating sql_code_vad.c"
	@-LANG=C gawk -f sql_to_c.awk -v init_name=_vad -v pl_stats=$(PLSTATS) $(SQL_FILES_VAD) > sql_code_vad.c.tmp
	@-[ -s sql_code_vad.c.tmp ] && mv sql_code_vad.c.tmp sql_code_vad.c
	@touch sql_code_vad.c

sql_code_dbp.c: $(SQL_FILES_DBP) $(AWK_FILES)
	@echo "Generating sql_code_dbpump.c"
	@-LANG=C gawk -f sql_to_c.awk -v init_name=_dbp -v pl_stats=$(PLSTATS) $(SQL_FILES_DBP) > sql_code_dbp.c.tmp
	@-[ -s sql_code_dbp.c.tmp ] && mv sql_code_dbp.c.tmp sql_code_dbp.c
	@touch sql_code_dbp.c

sql_code_uddi.c: $(SQL_FILES_UDDI) $(AWK_FILES)
	@echo "Generating sql_code_uddi.c"
	@-LANG=C gawk -f sql_to_c.awk -v init_name=_uddi -v pl_stats=$(PLSTATS) $(SQL_FILES_UDDI) > sql_code_uddi.c.tmp
	@-[ -s sql_code_uddi.c.tmp ] && mv sql_code_uddi.c.tmp sql_code_uddi.c
	@touch sql_code_uddi.c

sql_code_imsg.c: $(SQL_FILES_IMSG) $(AWK_FILES)
	@echo "Generating sql_code_imsg.c"
	@-LANG=C gawk -f sql_to_c.awk -v init_name=_imsg -v pl_stats=$(PLSTATS) $(SQL_FILES_IMSG) > sql_code_imsg.c.tmp
	@-[ -s sql_code_imsg.c.tmp ] && mv sql_code_imsg.c.tmp sql_code_imsg.c
	@touch sql_code_imsg.c

sql_code_auto.c: $(SQL_FILES_AUTO) $(AWK_FILES)
	@echo "Generating sql_code_auto.c"
	@-LANG=C gawk -f sql_to_c.awk -v init_name=_auto -v pl_stats=$(PLSTATS) $(SQL_FILES_AUTO) > sql_code_auto.c.tmp
	@-[ -s sql_code_auto.c.tmp ] && mv sql_code_auto.c.tmp sql_code_auto.c
	@touch sql_code_auto.c

sql_code_2pc.c: $(SQL_FILES_2PC) $(AWK_FILES)
	@echo "Generating sql_code_2pc.c"
	@-LANG=C gawk -f sql_to_c.awk -v init_name=_2pc -v pl_stats=$(PLSTATS) $(SQL_FILES_2PC) > sql_code_2pc.c.tmp
	@-[ -s sql_code_2pc.c.tmp ] && mv sql_code_2pc.c.tmp sql_code_2pc.c
	@touch sql_code_2pc.c

#sql_code_blog.c: $(SQL_FILES_BLOG) $(AWK_FILES)
#	@echo "Generating sql_code_blog.c"
#	@-LANG=C gawk -f sql_to_c.awk -v init_name=_blog -v pl_stats=$(PLSTATS) $(SQL_FILES_BLOG) > sql_code_blog.c.tmp
#	@-[ -s sql_code_blog.c.tmp ] && mv sql_code_blog.c.tmp sql_code_blog.c
#	@touch sql_code_blog.c

sql_code_vdb.c: $(SQL_FILES_VDB) $(AWK_FILES)
	@echo "Generating sql_code_vdb.c"
	@-LANG=C gawk -f sql_to_c.awk -v init_name=_vdb -v pl_stats=$(PLSTATS) $(SQL_FILES_VDB) > sql_code_vdb.c.tmp
	@-[ -s sql_code_vdb.c.tmp ] && mv sql_code_vdb.c.tmp sql_code_vdb.c
	@touch sql_code_vdb.c

sql_code_sparql.c: $(SQL_FILES_SPARQL) $(AWK_FILES)
	@echo "Generating sql_code_sparql.c"
	@-gawk -f sql_to_c.awk -v init_name=_sparql -v pl_stats=$(PLSTATS) $(SQL_FILES_SPARQL) > sql_code_sparql.c.tmp
	@-[ -s sql_code_sparql.c.tmp ] && mv sql_code_sparql.c.tmp sql_code_sparql.c
	@touch sql_code_sparql.c

blog_pages.sql: FORCE
	(cd $(top_srcdir)/binsrc/weblog ; gmake)

davxml2rdfxml.xsl: ../../binsrc/tests/dav/davxml2rdfxml.xsl
	cp ../../binsrc/tests/dav/davxml2rdfxml.xsl davxml2rdfxml.xsl

davxml2n3xml.xsl: ../../binsrc/tests/dav/davxml2n3xml.xsl
	cp ../../binsrc/tests/dav/davxml2n3xml.xsl davxml2n3xml.xsl

rdfxml2n3xml.xsl: ../../binsrc/tests/dav/rdfxml2n3xml.xsl
	cp ../../binsrc/tests/dav/rdfxml2n3xml.xsl rdfxml2n3xml.xsl

n3xml2uriqahtml.xsl: ../../binsrc/tests/dav/n3xml2uriqahtml.xsl
	cp ../../binsrc/tests/dav/n3xml2uriqahtml.xsl n3xml2uriqahtml.xsl

.PHONY: generated
generated: \
	sqlwords.h sql3.c scn3.c \
	xpathp.c xpathp.h xpscn.c \
	sparql_p.c sparql_p.h sparql_l.c \
	turtle_p.c turtle_p.h turtle_l.c \
	sql_code.c sql_code_1.c sql_code_ddk.c sql_code_adm.c sql_code_dav.c sql_code_vad.c sql_code_dbp.c \
	sql_code_uddi.c sql_code_imsg.c sql_code_auto.c sql_code_2pc.c sql_code_cache.c sql_code_vdb.c sql_code_sparql.c




# ----------------------------------------------------------------------
#
#  Additional files to distribute
#
# ----------------------------------------------------------------------
EXTRA_DIST = \
	sql_to_c.awk \
	sqlwords.gperf \
	list_lex_props.sh \
	2pc.sql autoexec.sql ftp.sql hosting.sql http_auth.sql \
	information_schema.sql mail_cli.sql nn_svr.sql odbccat.sql \
	oledb.sql openxml.sql pop3_svr.sql replddk.sql repl.sql \
	snapshot_repl.sql soap.sql sparql.sql system2.sql system.sql \
	uddi.sql useraggr.sql users.sql vdb.sql virtual_dir.sql vt_text.sql \
	xml_a.sql xmla.sql xml_view.sql \
	blog.xsl cov_report.xsl cov_time.xsl davxml2n3xml.xsl \
	davxml2rdfxml.xsl n3xml2uriqahtml.xsl rdfxml2n3xml.xsl \
	soap12_router.xsl soap_import_sch.xsl soap_sch.xsl soap_xmlrpc.xsl \
	wsdl_expand.xsl wsdl_import.xsl wsdl_parts.xsl wsrp_error.xsl \
	wsrp_interm.xsl wsrp_resp.xsl wsrp_ultim.xsl xmlrpc_soap.xsl \
	scn3.l sparql_l.l turtle_l.l xpscn.l \
	sparql_p.y sql3.y turtle_p.y xpathp.y \
	2pc_client.c bif_gnw.c bif_mts.c bif_purify.c crypt.c \
	iodbcinst.c mts_client.c mts_com.cpp mtx.cpp name.c \
	plugin_gate.c sql3_vc.c sql_code_cache_impl.c ssl.c \
	string_tmpl.c


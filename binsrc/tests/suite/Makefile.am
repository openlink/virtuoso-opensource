#  
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#  
#  Copyright (C) 1998-2023 OpenLink Software
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

SUBDIRS	= . tpc-d

TOP=@TOP@

check_SCRIPTS = \
	bpel.sh \
	byteorder.sh \
	clean.sh \
	epilog.sh \
	go_functions.sh \
	gtkbench.sh \
	inprocess.sh \
	large_db.sh \
	lowerall.sh \
	msdtc.sh \
	nwxml.sh \
	obackup.sh \
	oledb.sh \
	prepare_t1.sh \
	prolog.sh \
	release.sh \
	rtest.sh \
	summary.sh \
	tblob_recode.sh \
	tcl.sh \
	tclstart.sh \
	tclstop.sh \
	tdatetime.sh \
	tdav.sh \
	tdav_meta.sh \
	tdbp.sh \
	tdconv.sh \
	tdrop.sh \
	test_cluster.sh \
	test_fn.sh \
	test_ldp.sh \
	test_run.sh \
	test_server.sh \
	testall.sh \
	testlib.sh \
	tgraphql.sh \
	thttp.sh \
	timsg.sh \
	tjdbc.sh \
	tlubm.sh \
	toptiremote.sh \
	toptitpcd.sh \
	tp.sh \
	tpcd.sh \
	tproviders.sh \
	tproxy.sh \
	trecov.sh \
	trecov_schema.sh \
	trepl.sh \
	trepl_rdf.sh \
	treplh.sh \
	tsec.sh \
	tsoap12.sh \
	tsql.sh \
	tsql2.sh \
	tsql3.sh \
	tsqllite.sh \
	tsqlo.sh \
	tstriping.sh \
	tsxml.sh \
	ttpch.sh \
	ttutorial.sh \
	tupgrade_recov.sh \
	tvad.sh \
	tvad2.sh \
	tvsp.sh \
	tvspx.sh \
	tvspxex.sh \
	twcopy.sh \
	twiki.sh \
	txslt.sh \
	wtf.sh

#TESTS=test_server.sh
TESTS_ENVIRONMENT= \
	HOME="$(TOP)" \
	VIRTDEV_HOME="$(TOP)" \
	VIRTUOSO_BUILD="$(TOP)" \
	HOST=localhost \
	JDK4="@ac_jdk4_path@" \
	JDK4_1="@ac_jdk4_1_path@" \
	JDK4_2="@ac_jdk4_2_path@" \
	JDK4_3="@ac_jdk4_3_path@" \
	MAKE=$(MAKE) \
	PATH="$(TOP)/binsrc/virtuoso:$(TOP)/binsrc/tests:.:$$PATH" \
	PORT=$(PORT) \
	SERVER=virtuoso-t \
	TOP="$(TOP)"

check-local:
	env $(TESTS_ENVIRONMENT) $(SHELL) ./test_server.sh

test:
	env $(TESTS_ENVIRONMENT) $(SHELL) ./test_server.sh $(T)

clean-local:
	TOP="$(TOP)" ./clean.sh


# ----------------------------------------------------------------------
#
#  Additional files to distribute
#
# ----------------------------------------------------------------------
EXTRA_DIST= \
	$(check_SCRIPTS) \
	$(srcdir)/*.dtd \
	$(srcdir)/*.eml \
	$(srcdir)/*.nq \
	$(srcdir)/*.pem \
	$(srcdir)/*.sql \
	$(srcdir)/*.ttl \
	$(srcdir)/*.txt \
	$(srcdir)/*.vsp \
	$(srcdir)/*.xml \
	$(srcdir)/*.xsl \
	$(srcdir)/actstrm_tests.tar.gz \
	$(srcdir)/cluster-test.ini \
	$(srcdir)/docsrc/*.xml \
	$(srcdir)/docsrc/*.xsl \
	$(srcdir)/etalon_ouput_gz \
	$(srcdir)/grddl-tests.tar.gz \
	$(srcdir)/ldp/*.ttl \
	$(srcdir)/pdd_txt.gz \
	$(srcdir)/r4/*.sql \
	$(srcdir)/r4/*.xsd \
	$(srcdir)/spanish.coll \
	$(srcdir)/spotlight_test.tar.gz \
	$(srcdir)/tdav_meta_050512.zip \
	$(srcdir)/tdav_meta_050528.zip \
	$(srcdir)/tgql_intro.ql \
	$(srcdir)/tpcd.sh \
	$(srcdir)/tpc-h/*.sql \
	$(srcdir)/treplh-dsn-odbc.cfg \
	$(srcdir)/treplh-test-odbc.cfg \
	$(srcdir)/tsparup/*.sql \
	$(srcdir)/tsparup/tsparup_1/*.xml \
	$(srcdir)/tsparup/tsparup_2/*.xml \
	$(srcdir)/tsparup/tsparup_3/*.xml \
	$(srcdir)/tsparup/tsparup_4/*.xml \
	$(srcdir)/tsparup/tsparup_5/*.xml \
	$(srcdir)/tsparup/tsparup_6/*.xml \
	$(srcdir)/tsparup/tsparup_7/*.xml \
	$(srcdir)/tsparup/tsparup_8/*.xml \
	$(srcdir)/tvspxex.awk \
	$(srcdir)/txslt.cmp \
	$(srcdir)/vad_test/vsp/vad_test1/*.sql \
	$(srcdir)/vad_test/vsp/vad_test1/*.vsp \
	$(srcdir)/vad_test/vsp/vad_test2/*.sql \
	$(srcdir)/vad_test/vsp/vad_test2/*.vsp \
	$(srcdir)/virtuoso-1111.ini \
	$(srcdir)/virtuoso-cl.ini \
	$(srcdir)/virtuoso-striping.ini \
	$(srcdir)/wi-striping-1-large.cfg \
	$(srcdir)/wi-striping.cfg \
	$(srcdir)/wi-striping-large.cfg \
	$(srcdir)/witest.cfg \
	$(srcdir)/words.esp \
	$(srcdir)/xsl_samples/*.xml \
	$(srcdir)/xsl_samples/*.xsl

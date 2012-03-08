#  
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#  
#  Copyright (C) 1998-2012 OpenLink Software
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

SUBDIRS	= tpc-d .

TOP=@TOP@

check_SCRIPTS = \
	bpel.sh \
	byteorder.sh \
	clean.sh \
	gtkbench.sh \
	inprocess.sh \
	large_db.sh \
	lowerall.sh \
	msdtc.sh \
	nwxml.sh \
	obackup.sh \
	oledb.sh \
	rtest.sh \
	tblob_recode.sh \
	tclstart.sh \
	tclstop.sh \
	tcpt.sh \
	tdav.sh \
	tdav_meta.sh \
	tdbp.sh \
	tdconv.sh \
	tdrop.sh \
	test_fn.sh \
	test_server.sh \
	testall.sh \
	thttp.sh \
	timsg.sh \
	tjdbc.sh \
	tp.sh \
	tpcd.sh \
	tproviders.sh \
	tproxy.sh \
	trecov.sh \
	trecov_schema.sh \
	trepl.sh \
	treplh.sh \
	tsec.sh \
	tsoap12.sh \
	tsparql.sh \
	tsparql_demo.sh \
	tsql.sh \
	tsql2.sh \
	tsql3.sh \
	tsqllite.sh \
	tsqlo.sh \
	tstriping.sh \
	tsxml.sh \
	ttutorial.sh \
	tupgrade_recov.sh \
	tvad.sh \
	tvad2.sh \
	tvsp.sh \
	tvspx.sh \
	tvspxex.sh \
	twcopy.sh \
	twiki.sh \
	txslt.sh

TESTS=test_server.sh
TESTS_ENVIRONMENT=PATH="$(TOP)/binsrc/virtuoso:$(TOP)/binsrc/tests:.:$$PATH" \
	PORT=$(PORT) HOME="$(TOP)" JDK2="@ac_jdk2_path@" JDK3="@ac_jdk3_path@" HOST=localhost SERVER=virtuoso-t

clean-local:
	./clean.sh


# ----------------------------------------------------------------------
#
#  Additional files to distribute
#
# ----------------------------------------------------------------------
EXTRA_DIST= \
	$(check_SCRIPTS) \
	*.dtd \
	*.sql \
	*.txt \
	*.vsp \
	*.xml \
	*.xsl \
	cert.pem \
	docsrc/*.xml \
	docsrc/*.xsl \
	eml1.eml \
	eml2.eml \
	etalon_ouput_gz \
	grddl-tests.tar.gz \
	pdd_txt.gz \
	pk.pem \
	r4/r4.tmp \
	r4/*.sql \
	r4/*.xsd \
	rtest.sh \
	spanish.coll \
	spotlight_test.tar.gz \
	tdav_meta_050512.zip \
	tdav_meta_050528.zip \
	test_news_server_file \
	treplh-dsn-odbc.cfg \
	treplh-test-odbc.cfg \
	tvspxex.awk \
	txslt.cmp \
	vad_test/vsp/vad_test1/*.sql \
	vad_test/vsp/vad_test1/*.vsp \
	vad_test/vsp/vad_test2/*.sql \
	vad_test/vsp/vad_test2/*.vsp \
	virtuoso-1111.ini \
	virtuoso-striping.ini \
	wi-striping-1-large.cfg \
	wi-striping.cfg \
	wi-striping-large.cfg \
	witest.cfg \
	words.esp \
	xsl_samples/*.xml \
	xsl_samples/*.xsl

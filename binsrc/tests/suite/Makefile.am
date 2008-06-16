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

SUBDIRS	= tpc-d .

TOP=@TOP@

TESTS=test_server.sh
TESTS_ENVIRONMENT=PATH="$(TOP)/binsrc/virtuoso:$(TOP)/binsrc/tests:.:$$PATH" \
	PORT=$(PORT) HOME="$(TOP)" JDK2="$(JDK2)" JDK3="$(JDK3)" HOST=localhost SERVER=virtuoso-t

clean-local:
	./clean.sh


# ----------------------------------------------------------------------
#
#  Additional files to distribute
#
# ----------------------------------------------------------------------
EXTRA_DIST= \
	bpel.sh \
	byteorder.sh \
	cert.pem \
	clean.sh \
	docsrc/*.xml \
	docsrc/*.xsl \
	*.dtd \
	eml1.eml \
	eml2.eml \
	etalon_ouput_gz \
	gtkbench.sh \
	grddl-tests.tar.gz \
	inprocess.sh \
	large_db.sh \
	lowerall.sh \
	msdtc.sh \
	nwxml.sh \
	obackup.sh \
	oledb.sh \
	pdd_txt.gz \
	pk.pem \
	r4/r4.tmp \
	r4/*.sql \
	r4/*.xsd \
	rtest.sh \
	spanish.coll \
	spotlight_test.tar.gz \
	*.sql \
	tblob_recode.sh \
	tdav_meta_050512.zip \
	tdav_meta_050528.zip \
	tdav_meta.sh \
	tdav.sh \
	tdbp.sh \
	tdconv.sh \
	tdrop.sh \
	test_1947.db.test \
	testall.sh \
	test_fn.sh \
	test_news_server_file \
	test_server.sh \
	thttp.sh \
	timsg.sh \
	tjdbc.sh \
	tpcd.sh \
	tproxy.sh \
	tp.sh \
	trecov_schema.sh \
	trecov.sh \
	treplh-dsn-odbc.cfg \
	treplh.sh \
	treplh-test-odbc.cfg \
	trepl.sh \
	tsec.sh \
	tsoap12.sh \
	tsql2.sh \
	tsql3.sh \
	tsqlo.sh \
	tsql.sh \
	tstriping.sh \
	tsxml.sh \
	ttutorial.sh \
	tupgrade_recov.sh \
	tvad2.sh \
	tvad.sh \
	tvsp.sh \
	tvspxex.awk \
	tvspxex.sh \
	tvspx.sh \
	twiki.sh \
	twcopy.sh \
	txslt.cmp \
	txslt.sh \
	*.txt \
	vad_test/vsp/vad_test1/*.sql \
	vad_test/vsp/vad_test1/*.vsp \
	vad_test/vsp/vad_test2/*.sql \
	vad_test/vsp/vad_test2/*.vsp \
	virtuoso-1111.ini \
	virtuoso-striping.ini \
	*.vsp \
	wi-striping-1-large.cfg \
	wi-striping.cfg \
	wi-striping-large.cfg \
	witest.cfg \
	words.esp \
	*.xml \
	*.xsl \
	xsl_samples/*.xml \
	xsl_samples/*.xsl

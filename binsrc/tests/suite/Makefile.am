#  
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#  
#  Copyright (C) 1998-2013 OpenLink Software
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
	tdav.sh \
	tdav_meta.sh \
	tdbp.sh \
	tdconv.sh \
	tdrop.sh \
	test_cluster.sh \
	test_fn.sh \
	test_run.sh \
	test_server.sh \
	testall.sh \
	testlib.sh \
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

TESTS=test_server.sh
TESTS_ENVIRONMENT=PATH="$(TOP)/binsrc/virtuoso:$(TOP)/binsrc/tests:.:$$PATH" \
	PORT=$(PORT) TOP="$(TOP)" HOME="$(TOP)" JDK2="@ac_jdk2_path@" JDK3="@ac_jdk3_path@" HOST=localhost SERVER=virtuoso-t MAKE=$(MAKE)

clean-local:
	VIRTDEV_HOME="$(TOP)" ./clean.sh


# ----------------------------------------------------------------------
#
#  Additional files to distribute
#
# ----------------------------------------------------------------------
EXTRA_DIST= \
	$(check_SCRIPTS) \
	*.dtd \
	*.eml \
	*.nq \
	*.pem \
	*.sql \
	*.txt \
	*.vsp \
	*.xml \
	*.xsl \
	cluster-test.ini \
	grddl-tests.tar.gz \
	pdd_txt.gz \
	spanish.coll \
	spotlight_test.tar.gz \
	tdav_meta_050512.zip \
	tdav_meta_050528.zip \
	tpcd.sh \
	treplh-dsn-odbc.cfg \
	treplh-test-odbc.cfg \
	tvspxex.awk \
	txslt.cmp \
	virtuoso-1111.ini \
	virtuoso-cl.ini \
	virtuoso-striping.ini \
	wi-striping-1-large.cfg \
	wi-striping-large.cfg \
	wi-striping.cfg \
	witest.cfg \
	words.esp

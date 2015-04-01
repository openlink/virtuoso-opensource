#  
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#  
#  Copyright (C) 1998-2015 OpenLink Software
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

TOP=@TOP@

if WITH_BPEL_VAD
nodist_vad_DATA = bpel_dav.vad
endif

BUILD_FILES = bpel_dav.vad bpel_filesystem.vad
CLEANFILES =  \
	vad.db \
	vad.log \
	vad.trx \
	vad_dav.xml \
	vad_fs.xml \
	virtuoso.ini \
	virtuoso.pxa \
	virtuoso.tdb \
	bpel4ws.vad \
	bpel4ws_dev.vad \
	make_bpel_vad.log \
	make_bpel_vad.xml \
	bpel_dav.vad \
	bpel_filesystem.vad

bpel_dav.vad bpel_filesystem.vad: $(EXTRA_DIST)
	PATH="$(TOP)/binsrc/virtuoso:$(TOP)/binsrc/tests:.:$$PATH" PORT=$(PORT) HOME="$(TOP)" HOST=localhost $(SHELL) ./make_vad.sh

clean-local:
	-rm -rf vad

# ----------------------------------------------------------------------
#
#  Additional files to distribute
#
# ----------------------------------------------------------------------
EXTRA_DIST = \
	$(srcdir)/*.css \
	$(srcdir)/*.gif \
	$(srcdir)/*.jpg \
	$(srcdir)/*.sql \
	$(srcdir)/*.txt \
	$(srcdir)/*.vsp \
	$(srcdir)/*.vspx \
	$(srcdir)/*.xsl \
	$(srcdir)/101.HelloWorld/*.bpel \
	$(srcdir)/101.HelloWorld/*.wsdl \
	$(srcdir)/101.HelloWorld/*.xml \
	$(srcdir)/106.ParallelFlows/*.bpel \
	$(srcdir)/106.ParallelFlows/*.wsdl \
	$(srcdir)/106.ParallelFlows/*.xml \
	$(srcdir)/109.CorrelationSets/*.wsdl \
	$(srcdir)/109.CorrelationSets/*.xml \
	$(srcdir)/109.CorrelationSets/Buyer/*.bpel \
	$(srcdir)/109.CorrelationSets/Buyer/*.wsdl \
	$(srcdir)/109.CorrelationSets/Buyer/*.xml \
	109.CorrelationSets/Buyer/.project \
	$(srcdir)/109.CorrelationSets/Seller/*.bpel \
	$(srcdir)/109.CorrelationSets/Seller/*.wsdl \
	$(srcdir)/109.CorrelationSets/Seller/*.xml \
	109.CorrelationSets/Seller/.project \
	bpel.xsd \
	bpelv.xsd \
	bpelx.xsd \
	bpel_adaptor.cs \
	$(srcdir)/help/*.xml \
	$(srcdir)/i/*.gif \
	$(srcdir)/i/*.jpg \
	$(srcdir)/i/*.png \
	i/Thumbs.db \
	make_vad.sh \
	system/bpel/bpel.xsd \
	$(srcdir)/tests/*.vsp \
	$(srcdir)/tests/*.xml \
	$(srcdir)/tests/bpel_engines/activeBPEL/*.txt \
	$(srcdir)/tests/bpel_engines/Twister/*.txt \
	$(srcdir)/tests/bpel_engines/Twister/*.xml \
	$(srcdir)/tests/echo/*.bpel \
	$(srcdir)/tests/echo/*.sql \
	$(srcdir)/tests/echo/*.vsp \
	$(srcdir)/tests/echo/*.wsdl \
	$(srcdir)/tests/echo/*.xml \
	$(srcdir)/tests/echo/ini.sh \
	$(srcdir)/tests/echovirt/*.bpel \
	$(srcdir)/tests/echovirt/*.sql \
	$(srcdir)/tests/echovirt/*.wsdl \
	$(srcdir)/tests/echovirt/*.xml \
	$(srcdir)/tests/fault1/*.bpel \
	$(srcdir)/tests/fault1/*.sql \
	$(srcdir)/tests/fault1/*.vsp \
	$(srcdir)/tests/fault1/*.wsdl \
	$(srcdir)/tests/fault1/*.xml \
	$(srcdir)/tests/fi/*.bpel \
	$(srcdir)/tests/fi/*.sql \
	$(srcdir)/tests/fi/*.vsp \
	$(srcdir)/tests/fi/*.wsdl \
	$(srcdir)/tests/fi/*.xml \
	$(srcdir)/tests/Flow/*.bpel \
	$(srcdir)/tests/Flow/*.sql \
	$(srcdir)/tests/Flow/*.wsdl \
	$(srcdir)/tests/Flow/*.xml \
	$(srcdir)/tests/interop/site/*.html \
	$(srcdir)/tests/interop/site/*.sql \
	$(srcdir)/tests/interop/site/Aecho/*.bpel \
	$(srcdir)/tests/interop/site/Aecho/*.sql \
	$(srcdir)/tests/interop/site/Aecho/*.wsdl \
	$(srcdir)/tests/interop/site/Aecho/*.xml \
	$(srcdir)/tests/interop/site/bpel4ws/*.css \
	$(srcdir)/tests/interop/site/bpel4ws/*.gif \
	$(srcdir)/tests/interop/site/bpel4ws/*.jpg \
	$(srcdir)/tests/interop/site/bpel4ws/*.png \
	$(srcdir)/tests/interop/site/bpel4ws/*.sql \
	$(srcdir)/tests/interop/site/bpel4ws/*.vsp \
	$(srcdir)/tests/interop/site/bpel4ws/*.vspx \
	$(srcdir)/tests/interop/site/bpel4ws/*.xml \
	$(srcdir)/tests/interop/site/bpel4ws/*.xsl \
	$(srcdir)/tests/interop/site/bpel4ws/clients/*.vspx \
	$(srcdir)/tests/interop/site/bpel4ws/clients/*.xsl \
	$(srcdir)/tests/interop/site/echo/*.bpel \
	$(srcdir)/tests/interop/site/echo/*.sql \
	$(srcdir)/tests/interop/site/echo/*.wsdl \
	$(srcdir)/tests/interop/site/echo/*.xml \
	$(srcdir)/tests/interop/site/RMecho/*.bpel \
	$(srcdir)/tests/interop/site/RMecho/*.sql \
	$(srcdir)/tests/interop/site/RMecho/*.wsdl \
	$(srcdir)/tests/interop/site/RMecho/*.xml \
	$(srcdir)/tests/interop/site/RMLoan/*.bpel \
	$(srcdir)/tests/interop/site/RMLoan/*.sql \
	$(srcdir)/tests/interop/site/RMLoan/*.vsp \
	$(srcdir)/tests/interop/site/RMLoan/*.wsdl \
	$(srcdir)/tests/interop/site/RMLoan/*.xml \
	$(srcdir)/tests/interop/site/SecAecho/*.bpel \
	$(srcdir)/tests/interop/site/SecAecho/*.sql \
	$(srcdir)/tests/interop/site/SecAecho/*.wsdl \
	$(srcdir)/tests/interop/site/SecAecho/*.xml \
	$(srcdir)/tests/interop/site/SecLoan/*.bpel \
	$(srcdir)/tests/interop/site/SecLoan/*.sql \
	$(srcdir)/tests/interop/site/SecLoan/*.vsp \
	$(srcdir)/tests/interop/site/SecLoan/*.wsdl \
	$(srcdir)/tests/interop/site/SecLoan/*.xml \
	tests/interop/site/SecLoan/ClientPrivate.pfx \
	tests/interop/site/SecLoan/ClientPublic.cer \
	tests/interop/site/SecLoan/ServerPrivate.pfx \
	tests/interop/site/SecLoan/ServerPublic.cer \
	$(srcdir)/tests/interop/site/SecRMLoan/*.bpel \
	$(srcdir)/tests/interop/site/SecRMLoan/*.sql \
	$(srcdir)/tests/interop/site/SecRMLoan/*.vsp \
	$(srcdir)/tests/interop/site/SecRMLoan/*.wsdl \
	$(srcdir)/tests/interop/site/SecRMLoan/*.xml \
	$(srcdir)/tests/interop/UseCases/*.bpel \
	$(srcdir)/tests/interop/UseCases/*.sql \
	$(srcdir)/tests/interop/UseCases/*.vsp \
	$(srcdir)/tests/interop/UseCases/*.wsdl \
	$(srcdir)/tests/interop/UseCases/*.xml \
	$(srcdir)/tests/interop/WSE2.0/*.bpel \
	$(srcdir)/tests/interop/WSE2.0/*.sql \
	$(srcdir)/tests/interop/WSE2.0/*.wsdl \
	tests/interop/WSE2.0/README \
	tests/interop/WSE2.0/SecClient/Makefile \
	tests/interop/WSE2.0/SecClient/SecClient.cs \
	tests/interop/WSE2.0/SecClient/SecClient.exe.config \
	tests/interop/WSE2.0/SecSvc/Makefile \
	tests/interop/WSE2.0/SecSvc/SecSvc.asmx \
	tests/interop/WSE2.0/SecSvc/SecSvc.asmx.cs \
	tests/interop/WSE2.0/SecSvc/Web.config \
	$(srcdir)/tests/LoanFlow/*.bpel \
	$(srcdir)/tests/LoanFlow/*.sql \
	$(srcdir)/tests/LoanFlow/*.vsp \
	$(srcdir)/tests/LoanFlow/*.wsdl \
	$(srcdir)/tests/LoanFlow/*.xml \
	$(srcdir)/tests/mix/*.bpel \
	$(srcdir)/tests/mix/*.sql \
	$(srcdir)/tests/mix/*.wsdl \
	$(srcdir)/tests/order/*.bpel \
	$(srcdir)/tests/order/*.sql \
	$(srcdir)/tests/order/*.vsp \
	$(srcdir)/tests/order/*.wsdl \
	$(srcdir)/tests/order/*.xml \
	$(srcdir)/tests/pick/*.bpel \
	$(srcdir)/tests/pick/*.sql \
	$(srcdir)/tests/pick/*.wsdl \
	$(srcdir)/tests/pick1/*.bpel \
	$(srcdir)/tests/pick1/*.sql \
	$(srcdir)/tests/pick1/*.wsdl \
	$(srcdir)/tests/pick1/*.xml \
	$(srcdir)/tests/post/*.bpel \
	$(srcdir)/tests/post/*.sql \
	$(srcdir)/tests/post/*.wsdl \
	$(srcdir)/tests/post/*.xml \
	$(srcdir)/tests/processXQuery/*.bpel \
	$(srcdir)/tests/processXQuery/*.sql \
	$(srcdir)/tests/processXQuery/*.vsp \
	$(srcdir)/tests/processXQuery/*.wsdl \
	$(srcdir)/tests/processXQuery/*.xml \
	tests/processXQuery/books.xq \
	tests/processXQuery/invoice.xq \
	$(srcdir)/tests/processXSLT/*.bpel \
	$(srcdir)/tests/processXSLT/*.sql \
	$(srcdir)/tests/processXSLT/*.vsp \
	$(srcdir)/tests/processXSLT/*.wsdl \
	$(srcdir)/tests/processXSLT/*.xml \
	$(srcdir)/tests/processXSLT/*.xslt \
	$(srcdir)/tests/processXSQL/*.bpel \
	$(srcdir)/tests/processXSQL/*.sql \
	$(srcdir)/tests/processXSQL/*.vsp \
	$(srcdir)/tests/processXSQL/*.wsdl \
	$(srcdir)/tests/processXSQL/*.xml \
	tests/processXSQL/selectCustomer.xsql \
	tests/processXSQL/selectProduct.xsql \
	$(srcdir)/tests/sqlexec/*.bpel \
	$(srcdir)/tests/sqlexec/*.sql \
	$(srcdir)/tests/sqlexec/*.vsp \
	$(srcdir)/tests/sqlexec/*.wsdl \
	$(srcdir)/tests/sqlexec/*.xml \
	$(srcdir)/tests/t1/buyer/*.bpel \
	$(srcdir)/tests/t1/buyer/*.sql \
	$(srcdir)/tests/t1/buyer/*.wsdl \
	$(srcdir)/tests/t1/seller/*.bpel \
	$(srcdir)/tests/t1/seller/*.sql \
	$(srcdir)/tests/t1/seller/*.wsdl \
	$(srcdir)/tests/t2/*.bpel \
	$(srcdir)/tests/t2/*.sql \
	$(srcdir)/tests/t2/*.wsdl \
	$(srcdir)/tests/t2/*.xml \
	$(srcdir)/tests/tevent/*.bpel \
	$(srcdir)/tests/tevent/*.sql \
	$(srcdir)/tests/tevent/*.wsdl \
	$(srcdir)/tests/tevent/*.xml \
	$(srcdir)/tests/tevent/AsyncBPELService/*.bpel \
	$(srcdir)/tests/tevent/AsyncBPELService/*.wsdl \
	$(srcdir)/tests/tevent/AsyncBPELService/*.xml \
	$(srcdir)/tests/tpcc/*.bpel \
	$(srcdir)/tests/tpcc/*.sql \
	$(srcdir)/tests/tpcc/*.wsdl \
	tests/tpcc/run.sh \
	$(srcdir)/tests/tver/*.bpel \
	$(srcdir)/tests/tver/*.sql \
	$(srcdir)/tests/tver/*.wsdl \
	$(srcdir)/tests/wsrm/*.bpel \
	$(srcdir)/tests/wsrm/*.sql \
	$(srcdir)/tests/wsrm/*.wsdl \
	$(srcdir)/tests/wss/*.bpel \
	$(srcdir)/tests/wss/*.sql \
	$(srcdir)/tests/wss/*.wsdl \
	tests/wss/ClientPrivate.pfx \
	tests/wss/ClientPublic.cer \
	tests/wss/dsa.pfx \
	tests/wss/ServerPrivate.pfx \
	tests/wss/ServerPublic.cer \
	vad_version \
	wsdl.xsd \
	xsql.xsd

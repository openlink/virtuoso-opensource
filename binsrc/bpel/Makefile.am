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
	PATH="$(TOP)/binsrc/virtuoso:$(TOP)/binsrc/tests:.:$$PATH" PORT=$(PORT) HOME="$(TOP)" HOST=localhost ./make_vad.sh

clean-local:
	-rm -rf vad

# ----------------------------------------------------------------------
#
#  Additional files to distribute
#
# ----------------------------------------------------------------------
EXTRA_DIST = \
	*.css \
	*.gif \
	*.jpg \
	*.sql \
	*.txt \
	*.vsp \
	*.vspx \
	*.xsl \
	101.HelloWorld/*.bpel \
	101.HelloWorld/*.wsdl \
	101.HelloWorld/*.xml \
	106.ParallelFlows/*.bpel \
	106.ParallelFlows/*.wsdl \
	106.ParallelFlows/*.xml \
	109.CorrelationSets/*.wsdl \
	109.CorrelationSets/*.xml \
	109.CorrelationSets/Buyer/*.bpel \
	109.CorrelationSets/Buyer/*.wsdl \
	109.CorrelationSets/Buyer/*.xml \
	109.CorrelationSets/Buyer/.project \
	109.CorrelationSets/Seller/*.bpel \
	109.CorrelationSets/Seller/*.wsdl \
	109.CorrelationSets/Seller/*.xml \
	109.CorrelationSets/Seller/.project \
	bpel.xsd \
	bpelv.xsd \
	bpelx.xsd \
	bpel_adaptor.cs \
	help/*.xml \
	i/*.gif \
	i/*.jpg \
	i/*.png \
	i/Thumbs.db \
	make_vad.sh \
	system/bpel/bpel.xsd \
	tests/*.vsp \
	tests/*.xml \
	tests/bpel_engines/activeBPEL/*.txt \
	tests/bpel_engines/Twister/*.txt \
	tests/bpel_engines/Twister/*.xml \
	tests/echo/*.bpel \
	tests/echo/*.sql \
	tests/echo/*.vsp \
	tests/echo/*.wsdl \
	tests/echo/*.xml \
	tests/echo/ini.sh \
	tests/echovirt/*.bpel \
	tests/echovirt/*.sql \
	tests/echovirt/*.wsdl \
	tests/echovirt/*.xml \
	tests/fault1/*.bpel \
	tests/fault1/*.sql \
	tests/fault1/*.vsp \
	tests/fault1/*.wsdl \
	tests/fault1/*.xml \
	tests/fi/*.bpel \
	tests/fi/*.sql \
	tests/fi/*.vsp \
	tests/fi/*.wsdl \
	tests/fi/*.xml \
	tests/Flow/*.bpel \
	tests/Flow/*.sql \
	tests/Flow/*.wsdl \
	tests/Flow/*.xml \
	tests/interop/site/*.html \
	tests/interop/site/*.sql \
	tests/interop/site/Aecho/*.bpel \
	tests/interop/site/Aecho/*.sql \
	tests/interop/site/Aecho/*.wsdl \
	tests/interop/site/Aecho/*.xml \
	tests/interop/site/bpel4ws/*.css \
	tests/interop/site/bpel4ws/*.gif \
	tests/interop/site/bpel4ws/*.jpg \
	tests/interop/site/bpel4ws/*.png \
	tests/interop/site/bpel4ws/*.sql \
	tests/interop/site/bpel4ws/*.vsp \
	tests/interop/site/bpel4ws/*.vspx \
	tests/interop/site/bpel4ws/*.xml \
	tests/interop/site/bpel4ws/*.xsl \
	tests/interop/site/bpel4ws/clients/*.vspx \
	tests/interop/site/bpel4ws/clients/*.xsl \
	tests/interop/site/echo/*.bpel \
	tests/interop/site/echo/*.sql \
	tests/interop/site/echo/*.wsdl \
	tests/interop/site/echo/*.xml \
	tests/interop/site/RMecho/*.bpel \
	tests/interop/site/RMecho/*.sql \
	tests/interop/site/RMecho/*.wsdl \
	tests/interop/site/RMecho/*.xml \
	tests/interop/site/RMLoan/*.bpel \
	tests/interop/site/RMLoan/*.sql \
	tests/interop/site/RMLoan/*.vsp \
	tests/interop/site/RMLoan/*.wsdl \
	tests/interop/site/RMLoan/*.xml \
	tests/interop/site/SecAecho/*.bpel \
	tests/interop/site/SecAecho/*.sql \
	tests/interop/site/SecAecho/*.wsdl \
	tests/interop/site/SecAecho/*.xml \
	tests/interop/site/SecLoan/*.bpel \
	tests/interop/site/SecLoan/*.sql \
	tests/interop/site/SecLoan/*.vsp \
	tests/interop/site/SecLoan/*.wsdl \
	tests/interop/site/SecLoan/*.xml \
	tests/interop/site/SecLoan/ClientPrivate.pfx \
	tests/interop/site/SecLoan/ClientPublic.cer \
	tests/interop/site/SecLoan/ServerPrivate.pfx \
	tests/interop/site/SecLoan/ServerPublic.cer \
	tests/interop/site/SecRMLoan/*.bpel \
	tests/interop/site/SecRMLoan/*.sql \
	tests/interop/site/SecRMLoan/*.vsp \
	tests/interop/site/SecRMLoan/*.wsdl \
	tests/interop/site/SecRMLoan/*.xml \
	tests/interop/UseCases/*.bpel \
	tests/interop/UseCases/*.sql \
	tests/interop/UseCases/*.vsp \
	tests/interop/UseCases/*.wsdl \
	tests/interop/UseCases/*.xml \
	tests/interop/WSE2.0/*.bpel \
	tests/interop/WSE2.0/*.sql \
	tests/interop/WSE2.0/*.wsdl \
	tests/interop/WSE2.0/README \
	tests/interop/WSE2.0/SecClient/Makefile \
	tests/interop/WSE2.0/SecClient/SecClient.cs \
	tests/interop/WSE2.0/SecClient/SecClient.exe.config \
	tests/interop/WSE2.0/SecSvc/Makefile \
	tests/interop/WSE2.0/SecSvc/SecSvc.asmx \
	tests/interop/WSE2.0/SecSvc/SecSvc.asmx.cs \
	tests/interop/WSE2.0/SecSvc/Web.config \
	tests/LoanFlow/*.bpel \
	tests/LoanFlow/*.sql \
	tests/LoanFlow/*.vsp \
	tests/LoanFlow/*.wsdl \
	tests/LoanFlow/*.xml \
	tests/mix/*.bpel \
	tests/mix/*.sql \
	tests/mix/*.wsdl \
	tests/order/*.bpel \
	tests/order/*.sql \
	tests/order/*.vsp \
	tests/order/*.wsdl \
	tests/order/*.xml \
	tests/pick/*.bpel \
	tests/pick/*.sql \
	tests/pick/*.wsdl \
	tests/pick1/*.bpel \
	tests/pick1/*.sql \
	tests/pick1/*.wsdl \
	tests/pick1/*.xml \
	tests/post/*.bpel \
	tests/post/*.sql \
	tests/post/*.wsdl \
	tests/post/*.xml \
	tests/processXQuery/*.bpel \
	tests/processXQuery/*.sql \
	tests/processXQuery/*.vsp \
	tests/processXQuery/*.wsdl \
	tests/processXQuery/*.xml \
	tests/processXQuery/books.xq \
	tests/processXQuery/invoice.xq \
	tests/processXSLT/*.bpel \
	tests/processXSLT/*.sql \
	tests/processXSLT/*.vsp \
	tests/processXSLT/*.wsdl \
	tests/processXSLT/*.xml \
	tests/processXSLT/*.xslt \
	tests/processXSQL/*.bpel \
	tests/processXSQL/*.sql \
	tests/processXSQL/*.vsp \
	tests/processXSQL/*.wsdl \
	tests/processXSQL/*.xml \
	tests/processXSQL/selectCustomer.xsql \
	tests/processXSQL/selectProduct.xsql \
	tests/sqlexec/*.bpel \
	tests/sqlexec/*.sql \
	tests/sqlexec/*.vsp \
	tests/sqlexec/*.wsdl \
	tests/sqlexec/*.xml \
	tests/t1/buyer/*.bpel \
	tests/t1/buyer/*.sql \
	tests/t1/buyer/*.wsdl \
	tests/t1/seller/*.bpel \
	tests/t1/seller/*.sql \
	tests/t1/seller/*.wsdl \
	tests/t2/*.bpel \
	tests/t2/*.sql \
	tests/t2/*.wsdl \
	tests/t2/*.xml \
	tests/tevent/*.bpel \
	tests/tevent/*.sql \
	tests/tevent/*.wsdl \
	tests/tevent/*.xml \
	tests/tevent/AsyncBPELService/*.bpel \
	tests/tevent/AsyncBPELService/*.wsdl \
	tests/tevent/AsyncBPELService/*.xml \
	tests/tpcc/*.bpel \
	tests/tpcc/*.sql \
	tests/tpcc/*.wsdl \
	tests/tpcc/run.sh \
	tests/tver/*.bpel \
	tests/tver/*.sql \
	tests/tver/*.wsdl \
	tests/wsrm/*.bpel \
	tests/wsrm/*.sql \
	tests/wsrm/*.wsdl \
	tests/wss/*.bpel \
	tests/wss/*.sql \
	tests/wss/*.wsdl \
	tests/wss/ClientPrivate.pfx \
	tests/wss/ClientPublic.cer \
	tests/wss/dsa.pfx \
	tests/wss/ServerPrivate.pfx \
	tests/wss/ServerPublic.cer \
	vad_version \
	wsdl.xsd \
	xsql.xsd

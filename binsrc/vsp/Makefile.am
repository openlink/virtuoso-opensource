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

#SUBDIRS=admin vsmx mime images 

#dist_httproot_DATA = *.html *.css *.txt

install-data-local:
	@echo Installing in "$(httprootdir)" 
	mkdir -p "$(DESTDIR)$(httprootdir)"
	mkdir -p "$(DESTDIR)$(httprootdir)"/images
	mkdir -p "$(DESTDIR)$(httprootdir)"/admin
	mkdir -p "$(DESTDIR)$(httprootdir)"/vsmx
	$(INSTALL_DATA) *.html "$(DESTDIR)$(httprootdir)"
	$(INSTALL_DATA) *.css "$(DESTDIR)$(httprootdir)"
	$(INSTALL_DATA) *.txt "$(DESTDIR)$(httprootdir)"
	$(INSTALL_DATA) admin/index_left.vsp "$(DESTDIR)$(httprootdir)"/admin
	$(INSTALL_DATA) images/*.gif "$(DESTDIR)$(httprootdir)"/images
	$(INSTALL_DATA) images/*.png "$(DESTDIR)$(httprootdir)"/images
	$(INSTALL_DATA) images/*.jpg "$(DESTDIR)$(httprootdir)"/images
	$(INSTALL_DATA) vsmx/*.* "$(DESTDIR)$(httprootdir)"/vsmx


uninstall-local:
	rm -rf "$(DESTDIR)$(httprootdir)"/*


# ----------------------------------------------------------------------
#
#  Additional files to distribute
#
# ----------------------------------------------------------------------
EXTRA_DIST =  \
	*.css \
	*.html \
	*.sql \
	*.txt \
	*.vsp \
	admin/*.css \
	admin/*.html \
	admin/*.js \
	admin/*.sql \
	admin/*.vsp \
	admin/*.vspx \
	admin/admin_dav/*.css \
	admin/admin_dav/*.html \
	admin/admin_dav/*.js \
	admin/admin_dav/*.sql \
	admin/admin_dav/*.vsp \
	admin/admin_dav/*.vspx \
	admin/admin_dav/*.xml \
	admin/admin_dav/*.xsl \
	admin/admin_dav/images/16x16/*.gif \
	admin/admin_news/*.sql \
	admin/admin_news/*.vsp \
	admin/admin_repl/*.js \
	admin/admin_repl/*.vsp \
	admin/admin_trx_repl/*.vsp \
	admin/dbpump/*.html \
	admin/dbpump/*.sql \
	admin/dbpump/*.txt \
	admin/dbpump/*.vsp \
	admin/dbpump/*.xsl \
	admin/dbpump/oper.pars \
	admin/dbpump/operpars.awk \
	admin/dbpump/parse_oper_pars.sh \
	admin/dbpump/root.isql \
	admin/dbpump/schema.osql \
	admin/debug/*.sql \
	admin/debug/*.vspx \
	admin/debug/filter.awk \
	admin/debug/make_vad.sh \
	admin/debug/read.me \
	admin/debug/run_tests.sh \
	admin/images/*.gif \
	admin/images/*.jpg \
	admin/vad/*.gif \
	admin/vad/*.vsp \
	admin/vad/vad_sticker.dtd \
	doc/*.css \
	doc/*.gif \
	doc/*.jpg \
	doc/*.png \
	doc/*.vsp \
	doc/*.vspx \
	doc/*.xsl \
	images/*.gif \
	images/*.jpg \
	images/*.png \
	install.sh \
	mime/*.htm \
	mime/*.vsp \
	soapdemo/*.css \
	soapdemo/*.html \
	soapdemo/*.java \
	soapdemo/*.sql \
	soapdemo/*.vsp \
	soapdemo/demo.jar \
	soapdemo/GNUmakefile \
	soapdemo/r4/*.sql \
	soapdemo/r4/complex-doc-1.xsd \
	soapdemo/r4/complex-doc-2.xsd \
	soapdemo/r4/complex-doc-3.xsd \
	soapdemo/r4/complex-rpc-encoded.xsd \
	soapdemo/r4/dime-doc.xsd \
	soapdemo/r4/dime-rpc.xsd \
	soapdemo/r4/round4xsd-1.xsd \
	soapdemo/r4/round4xsd-2.xsd \
	soapdemo/r4/round4xsd-3.xsd \
	soapdemo/r4/round4xsd-4.xsd \
	soapdemo/r4/simple-doc-literal-1.xsd \
	soapdemo/r4/simple-doc-literal-2.xsd \
	soapdemo/r4/simple-doc-literal-3.xsd \
	soapdemo/r4/simple-rpc-encoded.xsd \
	soapdemo/round2-base.vb \
	soapdemo/saxapi.jar \
	soapdemo/soaprt.jar \
	soapdemo/xerces.jar \
	vsmx/*.css \
	vsmx/*.gif \
	vsmx/*.jpg \
	vsmx/*.vspx \
	vsmx/*.xsl

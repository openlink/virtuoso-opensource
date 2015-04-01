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

#SUBDIRS=admin vsmx mime images 

#dist_httproot_DATA = *.html *.css *.txt

install-data-local:
	@echo Installing in "$(httprootdir)" 
	mkdir -p "$(DESTDIR)$(httprootdir)"
	mkdir -p "$(DESTDIR)$(httprootdir)"/images
	mkdir -p "$(DESTDIR)$(httprootdir)"/admin
	mkdir -p "$(DESTDIR)$(httprootdir)"/vsmx
	$(INSTALL_DATA) $(srcdir)/*.html "$(DESTDIR)$(httprootdir)"
	$(INSTALL_DATA) $(srcdir)/*.css "$(DESTDIR)$(httprootdir)"
	$(INSTALL_DATA) $(srcdir)/*.txt "$(DESTDIR)$(httprootdir)"
	$(INSTALL_DATA) $(srcdir)/admin/index_left.vsp "$(DESTDIR)$(httprootdir)"/admin
	$(INSTALL_DATA) $(srcdir)/images/*.gif "$(DESTDIR)$(httprootdir)"/images
	$(INSTALL_DATA) $(srcdir)/images/*.png "$(DESTDIR)$(httprootdir)"/images
	$(INSTALL_DATA) $(srcdir)/images/*.jpg "$(DESTDIR)$(httprootdir)"/images
	$(INSTALL_DATA) $(srcdir)/vsmx/*.* "$(DESTDIR)$(httprootdir)"/vsmx


uninstall-local:
	rm -rf "$(DESTDIR)$(httprootdir)"/*


# ----------------------------------------------------------------------
#
#  Additional files to distribute
#
# ----------------------------------------------------------------------
EXTRA_DIST =  \
	$(srcdir)/*.css \
	$(srcdir)/*.html \
	$(srcdir)/*.sql \
	$(srcdir)/*.txt \
	$(srcdir)/*.vsp \
	$(srcdir)/admin/*.css \
	$(srcdir)/admin/*.html \
	$(srcdir)/admin/*.js \
	$(srcdir)/admin/*.sql \
	$(srcdir)/admin/*.vsp \
	$(srcdir)/admin/*.vspx \
	$(srcdir)/admin/admin_dav/*.css \
	$(srcdir)/admin/admin_dav/*.html \
	$(srcdir)/admin/admin_dav/*.js \
	$(srcdir)/admin/admin_dav/*.sql \
	$(srcdir)/admin/admin_dav/*.vsp \
	$(srcdir)/admin/admin_dav/*.vspx \
	$(srcdir)/admin/admin_dav/*.xml \
	$(srcdir)/admin/admin_dav/*.xsl \
	$(srcdir)/admin/admin_dav/images/16x16/*.gif \
	$(srcdir)/admin/admin_news/*.sql \
	$(srcdir)/admin/admin_news/*.vsp \
	$(srcdir)/admin/admin_repl/*.js \
	$(srcdir)/admin/admin_repl/*.vsp \
	$(srcdir)/admin/admin_trx_repl/*.vsp \
	$(srcdir)/admin/dbpump/*.html \
	$(srcdir)/admin/dbpump/*.sql \
	$(srcdir)/admin/dbpump/*.txt \
	$(srcdir)/admin/dbpump/*.vsp \
	$(srcdir)/admin/dbpump/*.xsl \
	admin/dbpump/oper.pars \
	admin/dbpump/operpars.awk \
	admin/dbpump/parse_oper_pars.sh \
	admin/dbpump/root.isql \
	admin/dbpump/schema.osql \
	$(srcdir)/admin/debug/*.sql \
	$(srcdir)/admin/debug/*.vspx \
	admin/debug/filter.awk \
	admin/debug/make_vad.sh \
	admin/debug/read.me \
	admin/debug/run_tests.sh \
	$(srcdir)/admin/images/*.gif \
	$(srcdir)/admin/images/*.jpg \
	$(srcdir)/admin/vad/*.gif \
	$(srcdir)/admin/vad/*.vsp \
	admin/vad/vad_sticker.dtd \
	$(srcdir)/doc/*.css \
	$(srcdir)/doc/*.gif \
	$(srcdir)/doc/*.jpg \
	$(srcdir)/doc/*.png \
	$(srcdir)/doc/*.vsp \
	$(srcdir)/doc/*.vspx \
	$(srcdir)/doc/*.xsl \
	$(srcdir)/images/*.gif \
	$(srcdir)/images/*.jpg \
	$(srcdir)/images/*.png \
	install.sh \
	$(srcdir)/mime/*.htm \
	$(srcdir)/mime/*.vsp \
	$(srcdir)/soapdemo/*.css \
	$(srcdir)/soapdemo/*.html \
	$(srcdir)/soapdemo/*.java \
	$(srcdir)/soapdemo/*.sql \
	$(srcdir)/soapdemo/*.vsp \
	soapdemo/demo.jar \
	soapdemo/GNUmakefile \
	$(srcdir)/soapdemo/r4/*.sql \
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
	$(srcdir)/vsmx/*.css \
	$(srcdir)/vsmx/*.gif \
	$(srcdir)/vsmx/*.jpg \
	$(srcdir)/vsmx/*.vspx \
	$(srcdir)/vsmx/*.xsl

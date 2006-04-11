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

#SUBDIRS=admin vsmx mime images 

#dist_httproot_DATA = *.html *.css *.txt

install-data-local:
	@echo Installing in "$(httprootdir)" 
	mkdir -p "$(httprootdir)"
	mkdir -p "$(httprootdir)"/images
	mkdir -p "$(httprootdir)"/admin
	$(INSTALL_DATA) *.html "$(httprootdir)"
	$(INSTALL_DATA) *.css "$(httprootdir)"
	$(INSTALL_DATA) *.txt "$(httprootdir)"
	$(INSTALL_DATA) admin/index_left.vsp "$(httprootdir)"/admin
	$(INSTALL_DATA) images/*.gif "$(httprootdir)"/images
	$(INSTALL_DATA) images/*.png "$(httprootdir)"/images
	$(INSTALL_DATA) images/*.jpg "$(httprootdir)"/images

uninstall-local:
	rm -rf "$(httprootdir)"/*


# ----------------------------------------------------------------------
#
#  Additional files to distribute
#
# ----------------------------------------------------------------------
EXTRA_DIST =  \
	admin/admin_dav/*.css \
	admin/admin_dav/*.html \
	admin/admin_dav/images/16x16/*.gif \
	admin/admin_dav/*.js \
	admin/admin_dav/*.sql \
	admin/admin_dav/*.vsp \
	admin/admin_dav/*.vspx \
	admin/admin_dav/*.xml \
	admin/admin_dav/*.xsl \
	admin/admin_news/*.sql \
	admin/admin_news/*.vsp \
	admin/admin_repl/*.js \
	admin/admin_repl/*.vsp \
	admin/admin_trx_repl/*.vsp \
	admin/*.css \
	admin/dbpump/*.html \
	admin/dbpump/*.isql \
	admin/dbpump/oper.pars \
	admin/dbpump/operpars.awk \
	admin/dbpump/parse_oper_pars.sh \
	admin/dbpump/schema.osql \
	admin/dbpump/*.sql \
	admin/dbpump/*.txt \
	admin/dbpump/*.vsp \
	admin/dbpump/*.xsl \
	admin/debug/filter.awk \
	admin/debug/make_vad.sh \
	admin/debug/read.me \
	admin/debug/run_tests.sh \
	admin/debug/*.sql \
	admin/debug/*.vspx \
	admin/*.html \
	admin/images/*.gif \
	admin/images/*.jpg \
	admin/*.js \
	admin/*.sql \
	admin/vad/*.dtd \
	admin/vad/*.gif \
	admin/vad/*.vsp \
	admin/*.vsp \
	admin/*.vspx \
	*.css \
	doc/*.css \
	doc/*.gif \
	doc/*.png \
	doc/*.vsp \
	doc/*.vspx \
	doc/*.xsl \
	*.html \
	images/*.gif \
	images/*.jpg \
	images/*.png \
	install.sh \
	mime/*.htm \
	mime/*.vsp \
	soapdemo/*.css \
	soapdemo/demo.jar \
	soapdemo/GNUmakefile \
	soapdemo/*.html \
	soapdemo/*.java \
	soapdemo/r4/*.sql \
	soapdemo/r4/*.xsd \
	soapdemo/round2-base.vb \
	soapdemo/saxapi.jar \
	soapdemo/soaprt.jar \
	soapdemo/*.sql \
	soapdemo/*.vsp \
	soapdemo/xerces.jar \
	*.sql \
	*.txt \
	vsmx/*.css \
	vsmx/*.gif \
	vsmx/*.jpg \
	vsmx/*.vspx \
	vsmx/*.xsl \
	*.vsp

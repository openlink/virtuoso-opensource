#  
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#  
#  Copyright (C) 1998-2026 OpenLink Software
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
	mkdir -p "$(DESTDIR)$(httprootdir)"/favicon
	$(INSTALL_DATA) *.html "$(DESTDIR)$(httprootdir)"
	$(INSTALL_DATA) *.css "$(DESTDIR)$(httprootdir)"
	$(INSTALL_DATA) *.txt "$(DESTDIR)$(httprootdir)"
	$(INSTALL_DATA) *.ico "$(DESTDIR)$(httprootdir)"
	$(INSTALL_DATA) admin/index_left.vsp "$(DESTDIR)$(httprootdir)"/admin
	$(INSTALL_DATA) images/*.gif "$(DESTDIR)$(httprootdir)"/images
	$(INSTALL_DATA) images/*.png "$(DESTDIR)$(httprootdir)"/images
	$(INSTALL_DATA) images/*.jpg "$(DESTDIR)$(httprootdir)"/images
	$(INSTALL_DATA) vsmx/*.* "$(DESTDIR)$(httprootdir)"/vsmx
	$(INSTALL_DATA) favicon/*.* "$(DESTDIR)$(httprootdir)"/favicon


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
	admin/*.vsp \
	admin/admin_dav/images/16x16/*.gif \
	admin/debug/filter.awk \
	doc/*.css \
	doc/*.gif \
	doc/*.jpg \
	doc/*.png \
	doc/*.vsp \
	doc/*.vspx \
	doc/*.xsl \
	favicon.ico \
	favicon/*.png \
	favicon/*.svg \
	favicon/manifest.webmanifest \
	images/*.gif \
	images/*.jpg \
	images/*.png \
	install.sh \
	vsmx/*.css \
	vsmx/*.gif \
	vsmx/*.jpg \
	vsmx/*.vspx \
	vsmx/*.xsl

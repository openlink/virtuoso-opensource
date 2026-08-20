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
	$(srcdir)/*.css \
	$(srcdir)/*.html \
	$(srcdir)/*.txt \
	$(srcdir)/admin/*.vsp \
	$(srcdir)/favicon.ico \
	$(srcdir)/favicon/*.png \
	$(srcdir)/favicon/*.svg \
	$(srcdir)/favicon/manifest.webmanifest \
	$(srcdir)/images/*.gif \
	$(srcdir)/images/*.jpg \
	$(srcdir)/images/*.png \
	$(srcdir)/vsmx/*.css \
	$(srcdir)/vsmx/*.gif \
	$(srcdir)/vsmx/*.jpg \
	$(srcdir)/vsmx/*.vspx

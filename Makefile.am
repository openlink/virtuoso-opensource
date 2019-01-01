#  
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#  
#  Copyright (C) 1998-2019 OpenLink Software
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

AUTOMAKE_OPTIONS	= gnu
ACLOCAL_AMFLAGS 	= -I binsrc/config


SUBDIRS = . docsrc libsrc binsrc appsrc

dist_doc_DATA = \
	$(srcdir)/AUTHORS \
	$(srcdir)/COPYING \
	$(srcdir)/COPYING.md \
	$(srcdir)/CREDITS \
	$(srcdir)/CREDITS.md \
	$(srcdir)/INSTALL \
	$(srcdir)/INSTALL.md \
	$(srcdir)/LICENSE \
	$(srcdir)/LICENSE.md \
	$(srcdir)/NEWS \
	$(srcdir)/NEWS.md \
	$(srcdir)/README \
	$(srcdir)/README.GIT.md \
	$(srcdir)/README.GeoSPARQL.md \
	$(srcdir)/README.hibernate.md \
	$(srcdir)/README.jena.md \
	$(srcdir)/README.jsse.md \
	$(srcdir)/README.MACOSX.md \
	$(srcdir)/README.OpenSSL.md \
	$(srcdir)/README.php5.md \
	$(srcdir)/README.sesame2.md \
	$(srcdir)/README.sesame3.md \
	$(srcdir)/README.UPGRADE.md \
	$(srcdir)/README.WINDOWS.md

# ----------------------------------------------------------------------
#
#  Maintainers only
# 
# ----------------------------------------------------------------------

MAINTAINERCLEANFILES	= aclocal.m4 configure


if MAINTAINER_MODE

#
#  Create a tar file containing a binary installation
#
binary-tar:
	-mkdir @build@
	$(MAKE) install DESTDIR="`pwd`/@build@/$(PACKAGE)/tmp/" prefix=..
	(cd @build@/$(PACKAGE) && rm -f hosting/*.a hosting/*.la lib/*.a lib/*.la)
	(cd @build@/$(PACKAGE)/database && mv virtuoso.ini virtuoso.ini.sample)
	(cd @build@ && tar cvf ../$(PACKAGE).@build@.tar virtuoso-opensource)
	gzip -9vf $(PACKAGE).@build@.tar
	rm -rf @build@


#
#  Create an official release package
#
release:
	$(MAKE) distcheck

#
#  Generate ChangeLog
#
.PHONY: changelog
changelog:
	git2cl --since=2009/10/17 --format='%s%n%n%b%n' --strip-tab --strip-cherry-pick > ChangeLog

endif

#
#  Create a source snapshot package
#
snapshot:
	$(MAKE) dist distdir=$(PACKAGE)-`date +"%Y%m%d"`


# ----------------------------------------------------------------------
#
#  Additional files to distribute
#
# ----------------------------------------------------------------------
EXTRA_DIST = \
	$(srcdir)/AUTHORS \
	$(srcdir)/COPYING \
	$(srcdir)/COPYING.md \
	$(srcdir)/CREDITS.md \
	$(srcdir)/INSTALL.md \
	$(srcdir)/LICENSE.md \
	$(srcdir)/NEWS.md \
	$(srcdir)/README \
	$(srcdir)/README.GIT.md \
	$(srcdir)/README.MACOSX.md \
	$(srcdir)/README.OpenSSL.md \
	$(srcdir)/README.UPGRADE.md \
	$(srcdir)/README.WINDOWS.md \
	$(srcdir)/README.hibernate.md \
	$(srcdir)/README.jena.md \
	$(srcdir)/README.jsse.md \
	$(srcdir)/README.php5.md \
	$(srcdir)/README.sesame2.md \
	$(srcdir)/README.sesame3.md \
	$(srcdir)/autogen.sh \
	$(srcdir)/bin/generate \
	$(srcdir)/bin/installer/virtuoso.ini bin/installer/demo.ini \
	$(srcdir)/bin/libtool.macosx \
	$(srcdir)/bin/makever \
	$(srcdir)/debian/NEWS.Debian \
	$(srcdir)/debian/README.Debian \
	$(srcdir)/debian/TODO.Debian \
	$(srcdir)/debian/changelog \
	$(srcdir)/debian/compat \
	$(srcdir)/debian/control \
	$(srcdir)/debian/copyright \
	$(srcdir)/debian/dirs \
	$(srcdir)/debian/docs \
	$(srcdir)/debian/libvirtjdbc0.dirs \
	$(srcdir)/debian/libvirtjdbc0.install \
	$(srcdir)/debian/libvirtmono0-cil.install \
	$(srcdir)/debian/libvirtodbc0.config \
	$(srcdir)/debian/libvirtodbc0.dirs \
	$(srcdir)/debian/libvirtodbc0.install \
	$(srcdir)/debian/libvirtodbc0.postinst \
	$(srcdir)/debian/libvirtodbc0.prerm \
	$(srcdir)/debian/libvirtodbc0.templates \
	$(srcdir)/debian/odbc.ini \
	$(srcdir)/debian/odbcinst.ini \
	$(srcdir)/debian/po/*.po \
	$(srcdir)/debian/po/POTFILES.in \
	$(srcdir)/debian/po/templates.pot \
	$(srcdir)/debian/rules \
	$(srcdir)/debian/virtuoso-mono.pc \
	$(srcdir)/debian/virtuoso-opensource-7-bin.install \
	$(srcdir)/debian/virtuoso-opensource-7-common.install \
	$(srcdir)/debian/virtuoso-opensource-7.config \
	$(srcdir)/debian/virtuoso-opensource-7.default \
	$(srcdir)/debian/virtuoso-opensource-7.init \
	$(srcdir)/debian/virtuoso-opensource-7.install \
	$(srcdir)/debian/virtuoso-opensource-7.postinst \
	$(srcdir)/debian/virtuoso-opensource-7.prerm \
	$(srcdir)/debian/virtuoso-opensource-7.templates \
	$(srcdir)/debian/virtuoso-vad-bpel.install \
	$(srcdir)/debian/virtuoso-vad-conductor.install \
	$(srcdir)/debian/virtuoso-vad-demo.install \
	$(srcdir)/debian/virtuoso-vad-isparql.install \
	$(srcdir)/debian/virtuoso-vad-ods.install \
	$(srcdir)/debian/virtuoso-vad-rdfmappers.install \
	$(srcdir)/debian/virtuoso-vad-sparqldemo.install \
	$(srcdir)/debian/virtuoso-vad-syncml.install \
	$(srcdir)/debian/virtuoso-vad-tutorial.install \
	$(srcdir)/debian/virtuoso-vsp-startpage.install \
	$(srcdir)/windows/*.bat \
	$(srcdir)/windows/*.sln \
	$(srcdir)/windows/*.vcxproj

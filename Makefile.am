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

AUTOMAKE_OPTIONS	= gnu
ACLOCAL_AMFLAGS 	= -I binsrc/config


SUBDIRS = . docsrc libsrc binsrc appsrc

dist_doc_DATA = \
	AUTHORS \
	COPYING \
	CREDITS \
	INSTALL \
	LICENSE \
	NEWS \
	README*

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
	$(MAKE) install DESTDIR="`pwd`/@build@/tmp/" prefix=..
	tar cvf @build@.tar @build@
	gzip -9vf @build@.tar
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
	autogen.sh \
	bin/makever \
	bin/generate \
	bin/libtool.macosx \
	bin/installer/virtuoso.ini bin/installer/demo.ini \
	debian/changelog \
	debian/compat \
	debian/control \
	debian/copyright \
	debian/dirs \
	debian/docs \
	debian/libvirtjdbc0.dirs \
	debian/libvirtjdbc0.install \
	debian/libvirtodbc0.config \
	debian/libvirtodbc0.dirs \
	debian/libvirtodbc0.install \
	debian/libvirtodbc0.postinst \
	debian/libvirtodbc0.prerm \
	debian/libvirtodbc0.templates \
	debian/libvirtuoso5.5-cil.install \
	debian/NEWS.Debian \
	debian/odbc.ini \
	debian/odbcinst.ini \
	debian/po/*.po \
	debian/po/POTFILES.in \
	debian/po/templates.pot \
	debian/README.Debian \
	debian/rules \
	debian/TODO.Debian \
	debian/virtuoso-5.5.pc \
	debian/virtuoso-opensource-7-bin.install \
	debian/virtuoso-opensource-7-common.install \
	debian/virtuoso-opensource-7.config \
	debian/virtuoso-opensource-7.default \
	debian/virtuoso-opensource-7.init \
	debian/virtuoso-opensource-7.install \
	debian/virtuoso-opensource-7.postinst \
	debian/virtuoso-opensource-7.prerm \
	debian/virtuoso-opensource-7.templates \
	debian/virtuoso-vad-bpel.install \
	debian/virtuoso-vad-conductor.install \
	debian/virtuoso-vad-demo.install \
	debian/virtuoso-vad-isparql.install \
	debian/virtuoso-vad-ods.install \
	debian/virtuoso-vad-rdfmappers.install \
	debian/virtuoso-vad-sparqldemo.install \
	debian/virtuoso-vad-syncml.install \
	debian/virtuoso-vad-tutorial.install \
	debian/virtuoso-vsp-startpage.install \
	windows/*.bat \
	windows/*.sln \
	windows/*.vcxproj

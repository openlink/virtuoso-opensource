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
	cvs2cl -F V6_0_0-DEVEL --no-ancestors --no-wrap --utc --hide-filenames --prune --window 86400

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
	debian/files \
	debian/init.d \
	debian/README.Debian \
	debian/rules \
	debian/virtuoso-opensource.postinst.debhelper \
	debian/virtuoso-opensource.postrm.debhelper \
	debian/virtuoso-opensource.prerm.debhelper \
	debian/virtuoso-opensource.substvars \
	windows/*.bat \
	windows/*.sln \
	windows/*.vcxproj

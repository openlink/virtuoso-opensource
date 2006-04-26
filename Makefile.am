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

AUTOMAKE_OPTIONS	= gnu 1.5

SUBDIRS = . docsrc libsrc binsrc


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
	$(MAKE) install prefix=`pwd`/@build@
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
changelog:
	cvs2cl --no-wrap --utc --hide-filenames --prune --window 86400

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
	AUTHORS \
	COPYING \
	CREDITS \
	INSTALL \
	LICENSE \
	NEWS \
	README* \
	autogen.sh \
	bin/makever \
	bin/libtool.macosx \
	bin/installer/virtuoso.ini bin/installer/demo.ini \
	win32/mkperlenv.pl \
	win32/mkpythonenv.py \
	win32/*.bat \
	win32/*.vcproj \
	win32/*.sln

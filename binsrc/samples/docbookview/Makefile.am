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

CLEANFILES = virtuoso isql xmlsource/releasenotes xmlsource

clean-local:
	-rm -rf db

.PHONY: all
all: db virtuoso isql xmlsource xmlsource/releasenotes

db:
	mkdir db

virtuoso:
	-rm -f virtuoso
	$(LN_S) $(top_builddir)/binsrc/virtuoso/virtuoso virtuoso

isql:
	-rm -f isql
	$(LN_S) $(top_builddir)/binsrc/tests/isql isql

xmlsource:
	-rm -f xmlsource
	$(LN_S) $(top_srcdir)/docsrc/xmlsource xmlsource

xmlsource/releasenotes:
	-rm -f xmlsource/releasenotes
	$(LN_S) ../releasenotes xmlsource/releasenotes


# ----------------------------------------------------------------------
#
#  Additional files to distribute
#
# ----------------------------------------------------------------------
EXTRA_DIST = \
	docbookview.sh \
	http/*.vsp \
	*.isql \
	*.sql \
	virtuoso.ini

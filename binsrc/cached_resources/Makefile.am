#  
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#  
#  Copyright (C) 1998-2018 OpenLink Software
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

noinst_SCRIPTS	= cache_gen.sh
BUILT_SOURCES	= cached_resources.c
DISTCLEANFILES  = cached_resources.c

DEPS	= \
	$(srcdir)/Makefile.am \
	$(srcdir)/cache_gen.sh \
	$(srcdir)/res_to_c.awk \
	$(srcdir)/w3-1999-xhtml/vocab \
	$(srcdir)/w3-2000-01/rdf-schema \
	$(srcdir)/w3-TR-xhtml1-DTD/*.dtd \
	$(srcdir)/w3-TR-xhtml1-DTD/*.ent

all: cached_resources.c

cached_resources.c:FORCE $(DEPS)
	@echo Generating cached_resources.c 
	@$(SHELL) $(srcdir)/cache_gen.sh > cached_resources.c.tmp
	@cmp cached_resources.c cached_resources.c.tmp >/dev/null 2>/dev/null || mv cached_resources.c.tmp cached_resources.c
	@rm -f *.tmp

.PHONY: clean
clean:
	-rm -f *.tmp

FORCE:

# ----------------------------------------------------------------------
#
#  Additional files to distribute
#
# ----------------------------------------------------------------------
EXTRA_DIST = \
	cached_resources.c \
	cache_gen.sh \
	openlinksw-sparql/*.ttl \
	res_to_c.awk \
	w3-1999-xhtml/vocab \
	w3-2000-01/*.txt \
	w3-2000-01/rdf-schema \
	w3-TR-xhtml1-DTD/*.txt \
	w3-TR-xhtml1-DTD/*.ent \
	w3-TR-xhtml1-DTD/*.dtd

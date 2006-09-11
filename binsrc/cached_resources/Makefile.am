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

noinst_SCRIPTS	= cache_gen.sh

all: cached_resources.c

cached_resources.c: \
	w3-TR-xhtml1-DTD/xhtml-lat1.ent \
	w3-TR-xhtml1-DTD/xhtml-special.ent \
	w3-TR-xhtml1-DTD/xhtml-symbol.ent \
	w3-TR-xhtml1-DTD/xhtml1-frameset.dtd \
	w3-TR-xhtml1-DTD/xhtml1-strict.dtd \
	w3-TR-xhtml1-DTD/xhtml1-transitional.dtd \
	openlinksw-sparql/virtrdf-data-formats.ttl \
	res_to_c.awk cache_gen.sh
	@cache_gen.sh > cached_resources.c

.PHONY: clean
clean:
	-rm *.tmp

# ----------------------------------------------------------------------
#
#  Additional files to distribute
#
# ----------------------------------------------------------------------
EXTRA_DIST = \
	cache_gen.sh res_to_c.awk \
	cached_resources.c \
	openlinksw-sparql/virtrdf-data-formats.ttl \
	w3-2000-01/rdf-schema \
	w3-2000-01/README.txt \
	w3-TR-xhtml1-DTD/README.txt \
	w3-TR-xhtml1-DTD/xhtml1-frameset.dtd \
	w3-TR-xhtml1-DTD/xhtml1-strict.dtd \
	w3-TR-xhtml1-DTD/xhtml1-transitional.dtd \
	w3-TR-xhtml1-DTD/xhtml-lat1.ent \
	w3-TR-xhtml1-DTD/xhtml-special.ent \
	w3-TR-xhtml1-DTD/xhtml-symbol.ent

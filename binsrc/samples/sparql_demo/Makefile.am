#  
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#  
#  Copyright (C) 1998-2025 OpenLink Software
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

if WITH_SPARQLDEMO_VAD
nodist_vad_DATA = sparql_demo_dav.vad
endif

NEED_VERSION    = 07.20.3226
STICKER         = sparql_demo_sticker.xml
VERBOSE         = #--verbose
VERSION         = `cat vad_version`

DAV_FLAGS       = $(VERBOSE) \
                --var="BASE_PATH=/DAV/VAD" \
                --var="ISDAV=1" \
                --var="NEED_VERSION=$(NEED_VERSION)" \
                --var="TYPE=dav" \
                --var="VERSION=$(VERSION)"

sparql_demo_dav.vad: $(EXTRA_DIST) Makefile data
	$(PYTHON) $(top_srcdir)/binsrc/vadpacker/vadpacker.py \
		-o $(builddir)/sparql_demo_dav.vad \
		$(DAV_FLAGS) \
		$(srcdir)/$(STICKER)

.PHONY: data
data:
	$(RM) -r data sparql_dawg
	tar xfz $(top_srcdir)/binsrc/tests/rdf/demo_data/sparql_dawg.tar.gz
	tar xfz $(top_srcdir)/binsrc/tests/rdf/demo_data/sparql_extensions.tar.gz
	mv sparql_dawg data

# ----------------------------------------------------------------------
#
#  Cleanup
#
# ----------------------------------------------------------------------
CLEANFILES = \
	*.log \
	make_sparql_demo_vad.xml \
	sparql_demo_dav.vad \
	virtuoso.db \
	virtuoso.ini \
	virtuoso.lck \
	virtuoso.log \
	virtuoso.pxa \
	virtuoso.tdb \
	virtuoso.trx

clean-local:
	-rm -rf vad data

# ----------------------------------------------------------------------
#
#  Additional files to distribute
#
# ----------------------------------------------------------------------
EXTRA_DIST = \
	$(srcdir)/$(STICKER) \
	$(srcdir)/*.css \
	$(srcdir)/*.js \
	$(srcdir)/*.sql \
	$(srcdir)/*.vsp \
	$(srcdir)/images/*.gif \
	$(srcdir)/images/*.jpg \
	$(srcdir)/images/*.png \
	$(srcdir)/Makefile.am \
	$(srcdir)/syntax/*.js \
	$(srcdir)/vad_version

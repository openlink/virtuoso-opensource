#  
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#  
#  Copyright (C) 1998-2024 OpenLink Software
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

TOP=@TOP@

if WITH_RDB2RDF_VAD
nodist_vad_DATA = rdb2rdf_dav.vad
endif

NEED_VERSION    = 07.20.3226
STICKER		= rdb2rdf_sticker.xml
VERBOSE         = #--verbose
VERSION         = `cat vad_version`

DAV_FLAGS       = $(VERBOSE) \
                --prefix "$(srcdir)"    \
                --var="BASE_PATH=/DAV/VAD" \
                --var="ISDAV=1" \
                --var="NEED_VERSION=$(NEED_VERSION)" \
                --var="TYPE=dav" \
                --var="VERSION=$(VERSION)"


rdb2rdf_dav.vad: $(EXTRA_DIST) Makefile
	$(PYTHON) $(top_srcdir)/binsrc/vadpacker/vadpacker.py \
		-o $(builddir)/rdb2rdf_dav.vad \
		$(DAV_FLAGS) \
		$(srcdir)/$(STICKER)


# ----------------------------------------------------------------------
#
#  Cleanup
#
# ----------------------------------------------------------------------
CLEANFILES =  \
	make_vad.output \
	make_rdb2rdf_vad.output \
	rdb2rdf_dav.vad

clean-local:
	-rm -rf vad


# ----------------------------------------------------------------------
#
#  Additional files to distribute
#
# ----------------------------------------------------------------------
EXTRA_DIST = \
	$(srcdir)/$(STICKER) \
	$(srcdir)/*.sql \
	$(srcdir)/*.ttl \
	$(srcdir)/*.xml \
	$(srcdir)/vad_version

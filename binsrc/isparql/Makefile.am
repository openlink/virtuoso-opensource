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

if WITH_ISPARQL_VAD
nodist_vad_DATA = isparql_dav.vad
endif

NEED_VERSION    = 07.20.3226
STICKER         = isparql_sticker.xml
VERBOSE         = #--verbose
VERSION         = `cat vad_version`
PACKDATE=`date +"%Y-%m-%d %H:%M"`

DAV_FLAGS       = $(VERBOSE) \
                --prefix "$(srcdir)"    \
                --var="BASE_PATH=/DAV/VAD" \
                --var="ISDAV=1" \
                --var="NEED_VERSION=$(NEED_VERSION)" \
                --var="TYPE=dav" \
                --var="VERSION=$(VERSION)"

isparql_dav.vad: $(EXTRA_DIST) Makefile
	$(PYTHON) $(top_srcdir)/binsrc/vadpacker/vadpacker.py \
		-o $(builddir)/isparql_dav.vad \
		$(DAV_FLAGS) \
		$(srcdir)/$(STICKER)


# ----------------------------------------------------------------------
#
#  Cleanup
#
# ----------------------------------------------------------------------
CLEANFILES =  \
	make_isparql_vad.* \
	isparql*.vad \
	virtuoso.* \
	version

clean-local:
	-rm -rf vad

# ----------------------------------------------------------------------
#
#  Additional files to distribute
#
# ----------------------------------------------------------------------
EXTRA_DIST = \
	$(srcdir)/isparql_sticker.xml \
	$(srcdir)/*.html \
	$(srcdir)/*.vsp \
	$(srcdir)/images/*.gif \
	$(srcdir)/images/*.jpg \
	$(srcdir)/images/*.png \
	$(srcdir)/js/*.js \
	$(srcdir)/sql/*.sql \
	$(srcdir)/styles/*.css \
	$(srcdir)/vad_version \
	$(srcdir)/xslt/*.xsl

FORCE:

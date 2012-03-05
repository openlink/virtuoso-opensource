#
#  $Id$
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

TOP=@TOP@

if WITH_FCT_VAD
nodist_vad_DATA = fct_dav.vad
endif

CLEANFILES =  \
	*.log \
	*.vad \
	virtuoso.db \
	virtuoso.ini \
	virtuoso.lck \
	virtuoso.log \
	virtuoso.pxa \
	virtuoso.tdb \
	virtuoso.trx \
        vad_dav.xml \
        vad_fs.xml

fct_dav.vad: $(EXTRA_DIST)
	PATH="$(TOP)/binsrc/virtuoso:$(TOP)/binsrc/tests:.:$$PATH" PORT=$(PORT) HOME="$(TOP)" HOST=localhost sh ./make_vad.sh

clean-local:
	-rm -rf vad

# ----------------------------------------------------------------------
#
#  Additional files to distribute
#
# ----------------------------------------------------------------------
EXTRA_DIST = \
	$(srcdir)/*.html \
	$(srcdir)/*.js \
	$(srcdir)/*.sql \
	$(srcdir)/*.txt \
	$(srcdir)/*.vsp \
	$(srcdir)/*.xsl \
	$(srcdir)/images/*.gif \
	$(srcdir)/images/*.png \
	$(srcdir)/images/rdf_w3c.svg \
	$(srcdir)/images/sw-vert-v.svg \
	$(srcdir)/make_vad.sh \
	$(srcdir)/rdfdesc/*.sql \
	$(srcdir)/rdfdesc/*.vsp \
	$(srcdir)/s/*.js \
	$(srcdir)/styles/*.css \
	$(srcdir)/vad_version \
	$(srcdir)/VirtTripleLoader/.classpath \
	$(srcdir)/VirtTripleLoader/.project \
	$(srcdir)/VirtTripleLoader/src/virtTripleLoaderInit/*.java \
	$(srcdir)/www/*.css \
	$(srcdir)/www/*.html \
	$(srcdir)/www/*.sql \
	$(srcdir)/www/*.vsp

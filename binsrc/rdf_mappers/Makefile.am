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

if WITH_RDFMAPPERS_VAD
nodist_vad_DATA = rdf_mappers_dav.vad
endif

noinst_SCRIPTS = make_vad.sh

CLEANFILES = \
	make_rdf_mappers_vad.log \
	rdf_mappers_dav.vad \
	rdf_mappers_filesystem.vad \
	vad.db \
	vad.log \
	vad.trx \
	vad_dav.xml \
	vad_fs.xml \
	virtuoso.ini \
	virtuoso.pxa \
	virtuoso.tdb

rdf_mappers_dav.vad: $(EXTRA_DIST)
	PATH="$(TOP)/binsrc/virtuoso:$(TOP)/binsrc/tests:.:$$PATH" PORT=$(PORT) HOME="$(TOP)" HOST=localhost sh ./make_vad.sh

clean-local:
	-rm -rf vad

# ----------------------------------------------------------------------
#
#  Additional files to distribute
#
# ----------------------------------------------------------------------
EXTRA_DIST = \
	*.sql \
	make_vad.sh \
	data/*.sql \
	data/nyt_people.nt.gz \
	ontologies/owl/*.owl \
	ontologies/xbrl/*.owl \
	rdfdesc/*.sql \
	rdfdesc/*.vsp \
	rdfdesc/images/*.gif \
	rdfdesc/images/*.png \
	rdfdesc/statics/*.css \
	rdfdesc/statics/*.gif \
	rdfdesc/statics/*.js \
	rdfdesc/statics/*.png \
	rdfdesc/statics/*.svg \
	rdfdesc/style/*.css \
	sponger_front_page/*.js \
	sponger_front_page/*.vsp \
	sponger_front_page/skin/i/*.gif \
	sponger_front_page/skin/i/*.jpg \
	sponger_front_page/skin/i/*.png \
	sponger_front_page/skin/ss/*.css \
	vad_version \
	xslt/main/*.xsl

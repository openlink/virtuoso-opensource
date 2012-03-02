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

if WITH_DBPEDIA_VAD
nodist_vad_DATA = dbpedia_dav.vad
endif

noinst_SCRIPTS = make_vad.sh
CLEANFILES =  \
	dbpedia_dav.vad \
	dbpedia_filesystem.vad \
	make_dbpedia_vad.log \
	make_vad.output \
	vad_dav.xml \
	vad_fs.xml \
	virtuoso.pxa


dbpedia_filesystem.vad dbpedia_dav.vad: $(EXTRA_DIST)
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
	vad_version \
	vsp/*.sql \
	vsp/*.vsp \
	vsp/images/*.gif \
	vsp/images/*.png \
	vsp/statics/*.css \
	vsp/statics/*.gif \
	vsp/statics/*.js \
	vsp/statics/*.png \
	vsp/statics/*.svg \
	vsp/style/*.css

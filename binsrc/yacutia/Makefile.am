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

if WITH_CONDUCTOR_VAD
nodist_vad_DATA = conductor_dav.vad
endif

noinst_SCRIPTS = mkvad.sh
CLEANFILES =  \
	mkvad.output \
	yacutia_dav.vad \
	yacutia_filesystem.vad \
	conductor_dav.vad \
	conductor_filesystem.vad \
	vad_dav.xml \
	vad_fs.xml \
	virtuoso.pxa

conductor_filesystem.vad conductor_dav.vad: $(EXTRA_DIST)
	PATH="$(TOP)/binsrc/virtuoso:$(TOP)/binsrc/tests:.:$$PATH" PORT=$(PORT) HOME="$(TOP)" HOST=localhost sh ./mkvad.sh

clean-local:
	-rm -rf vad

# ----------------------------------------------------------------------
#
#  Additional files to distribute
#
# ----------------------------------------------------------------------
EXTRA_DIST = \
	*.css \
	*.htm \
	*.html \
	*.js \
	*.sql \
	*.vsp \
	*.vspx \
	*.xml \
	*.xsl \
	conductor.list \
	ent.dtd \
	help/*.xml \
	images/*.gif \
	images/*.jpg \
	images/*.png \
	images/dav_browser/*.png \
	images/icons/*.gif \
	images/icons/*.png \
	INSTALL \
	mkvad.ini \
	mkvad.sh \
	README \
	syntax/*.css \
	syntax/*.js \
	vad_version

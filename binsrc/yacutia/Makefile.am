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

TOP=@TOP@

nodist_vad_DATA = conductor_filesystem.vad conductor_dav.vad


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

conductor_filesystem.vad conductor_dav.vad: mkvad.sh
	PATH="$(TOP)/binsrc/virtuoso:$(TOP)/binsrc/tests:.:$$PATH" PORT=$(PORT) HOME="$(TOP)" HOST=localhost sh ./mkvad.sh

clean-local:
	-rm -rf vad

# ----------------------------------------------------------------------
#
#  Additional files to distribute
#
# ----------------------------------------------------------------------
EXTRA_DIST = \
	conductor.list \
	*.css \
	*.dtd \
	help/*.xml \
	*.htm \
	*.html \
	ie7/compatibility/complexspiral/*.css \
	ie7/compatibility/complexspiral/*.gif \
	ie7/compatibility/complexspiral/*.html \
	ie7/compatibility/complexspiral/*.jpg \
	ie7/compatibility/*.css \
	ie7/compatibility/*.gif \
	ie7/compatibility/*.htm \
	ie7/compatibility/*.html \
	ie7/compatibility/*.jpg \
	ie7/compatibility/*.js \
	ie7/compatibility/*.png \
	ie7/compatibility/*.xml \
	ie7/*.css \
	ie7/*.gif \
	ie7/*.htm \
	ie7/*.html \
	ie7/*.js \
	ie7/license \
	ie7/*.png \
	ie7/src/*.htm \
	ie7/src/*.js \
	ie7/*.txt \
	images/dav_browser/*.png \
	images/*.gif \
	images/icons/*.gif \
	images/icons/*.png \
	images/*.jpg \
	images/*.png \
	INSTALL \
	*.js \
	mkvad.ini \
	mkvad.sh \
	README \
	*.sql \
	syntax/*.css \
	syntax/*.js \
	toolkit/AUTHORS \
	toolkit/COPYING \
	toolkit/docs/*.css \
	toolkit/docs/*.html \
	toolkit/docs/*.js \
	toolkit/HOWTO \
	toolkit/images/*.gif \
	toolkit/images/*.png \
	toolkit/*.js \
	toolkit/LICENSE \
	*.vsp \
	*.vspx \
	*.xml \
	*.xsl

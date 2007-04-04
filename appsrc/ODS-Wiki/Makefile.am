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

SUBDIRS = plugin


nodist_vad_DATA = ods_wiki_dav.vad

CLEANFILES = \
	*.vad \
	make_wiki_vad.log \
	make_wiki_vad.xml \
	vad.db \
	vad.trx \
	vad.log \
	virtuoso.db \
	virtuoso.ini \
	virtuoso.lck \
	virtuoso.log \
	virtuoso.pxa \
	virtuoso.tdb \
	virtuoso.trx

ods_wiki_dav.vad: $(EXTRA_DIST)
	PATH="$(TOP)/binsrc/virtuoso:$(TOP)/binsrc/tests:.:$$PATH" PORT=$(PORT) HOME="$(TOP)" HOST=localhost sh ./make_vad.sh

clean-local:
	-rm -rf vad


# ----------------------------------------------------------------------
#
#  Additional files to distribute
#
# ----------------------------------------------------------------------
EXTRA_DIST =  \
	*.sql \
	generate_drop_proc.sh \
	http/*.css \
	http/*.vsp \
	http/*.vspx \
	http/*.xsl \
	http/*.xslt \
	http/images/*.gif \
	http/images/*.jpg \
	http/images/*.png \
	initial/Main/*.txt \
	initial/Wiki/*.txt \
	kupu/common/*.css \
	kupu/common/*.js \
	kupu/common/kupu.pox \
	kupu/common/kupu.pox.jspx \
	kupu/common/kupudrawers/*.xml \
	kupu/common/kupudrawers/*.xsl \
	kupu/common/kupudrawers/drawer.xsl.metadata \
	kupu/common/kupudrawers/logos/*.gif \
	kupu/common/kupudrawers/logos/*.png \
	kupu/common/kupuimages/*.gif \
	kupu/common/kupuimages/*.png \
	kupu/common/kupupopups/*.html \
	make_vad.sh \
	retry.sh \
	setup.isql \
	Skins/default/*.css \
	Skins/default/*.png \
	Skins/default/*.xslt \
	Template/*.txt \
	version.base \
	version.curr

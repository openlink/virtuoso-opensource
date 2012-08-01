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

SUBDIRS = plugin

if WITH_ODS_VAD
nodist_vad_DATA = ods_wiki_dav.vad
endif

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
	*.dox \
	*.sql \
	generate_drop_proc.sh \
	http/*.css \
	http/*.vsp \
	http/*.vspx \
	http/*.xml \
	http/*.xsl \
	http/*.xslt \
	http/images/*.gif \
	http/images/*.jpg \
	http/images/*.png \
	initial/Main/*.txt \
	initial/Main/Attachments/*.sql \
	initial/Wiki/*.txt \
	js/*.js \
	make_vad.sh \
	retry.sh \
	setup.isql \
	Skins/default/*.css \
	Skins/default/*.png \
	Skins/default/*.xslt \
	Template/*.txt \
	vad_version

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

if WITH_ODS_VAD
nodist_vad_DATA = ods_discussion_dav.vad
endif

CLEANFILES =  \
	*.vad \
	make_nntpf_vad.log \
	make_nntpf_vad.xml \
	vad.db \
	virtuoso.ini \
	vad.lck \
	vad.log \
	virtuoso.pxa \
	virtuoso.tdb \
	vad.trx

ods_discussion_dav.vad: $(EXTRA_DIST)
	PATH="$(TOP)/binsrc/virtuoso:$(TOP)/binsrc/tests:.:$$PATH" PORT=$(PORT) HOME="$(TOP)" HOST=localhost sh ./make_vad.sh

clean-local:
	-rm -rf vad

EXTRA_DIST = \
	*.dox \
	*.css \
	*.js \
	*.sql \
	*.vsp \
	*.vspx \
	*.xhtml \
	*.xsl \
	vad_version \
	comp/*.xsl \
	images/*.gif \
	images/*.jpg \
	images/*.png \
	make_vad.sh

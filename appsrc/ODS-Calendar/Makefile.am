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
nodist_vad_DATA = ods_calendar_dav.vad
endif

CLEANFILES = \
	*.vad \
	make_ods_calendar_vad.log \
	make_ods_calendar_vad.xml \
	virtuoso.db \
	virtuoso.ini \
	virtuoso.lck \
	virtuoso.log \
	virtuoso.pxa \
	virtuoso.tdb \
	virtuoso.trx

ods_calendar_dav.vad: $(EXTRA_DIST)
	PATH="$(TOP)/binsrc/virtuoso:$(TOP)/binsrc/tests:.:$$PATH" PORT=$(PORT) HOME="$(TOP)" HOST=localhost sh ./make_vad.sh

clean-local:
	-rm -rf vad

EXTRA_DIST = \
	*.dox \
	make_vad.sh \
	sql/*.sql \
	vad_version \
	www/*.vsp \
	www/*.vspx \
	www/css/*.css \
	www/image/*.gif \
	www/image/*.jpg \
	www/image/*.png \
	www/js/*.js \
	www/template/*.vspx \
	www/template/*.xsl \
	xslt/*.xsl

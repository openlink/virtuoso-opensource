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

nodist_vad_DATA = ods_framework_dav.vad

CLEANFILES =  \
	*.vad \
	make_ods_vad.log \
	make_ods_vad.xml \
	virtuoso.db \
	virtuoso.ini \
	virtuoso.lck \
	virtuoso.log \
	virtuoso.pxa \
	virtuoso.tdb \
	virtuoso.trx

ods_framework_dav.vad: $(EXTRA_DIST)
	PATH="$(TOP)/binsrc/virtuoso:$(TOP)/binsrc/tests:.:$$PATH" PORT=$(PORT) HOME="$(TOP)" HOST=localhost sh ./make_vad.sh

clean-local:
	-rm -rf vad

EXTRA_DIST = \
	*.css \
	*.html \
	*.js \
	*.sql \
	*.txt \
	*.vsp \
	*.vspx \
	*.xml \
	*.xsl \
	comp/*.js \
	comp/*.xml \
	comp/*.xsl \
	icons/*.gif \
	icons/*.png \
	images/*.gif \
	images/*.htm \
	images/*.jfif \
	images/*.jpg \
	images/*.png \
	images/*.psd \
	images/app_ads/*.jpg \
	images/dav_browser/*.png \
	images/skin/default/*.png \
	images/skin/pager/*.png \
	make_vad.sh \
	tmpl/SN_INV_TEMPLATE \
	tmpl/WS_APPROVE_BY_USER_TEMPLATE \
	tmpl/WS_CHANGE_BY_OWNER_TEMPLATE \
	tmpl/WS_INV_TEMPLATE \
	tmpl/WS_JOIN_APPROVE_TEMPLATE \
	tmpl/WS_JOIN_REJECT_TEMPLATE \
	tmpl/WS_MEM_TEMPLATE \
	tmpl/WS_NOT_TEMPLATE \
	tmpl/WS_REG_TEMPLATE \
	tmpl/WS_REJECT_BY_USER_TEMPLATE \
	tmpl/WS_TERM_BY_OWNER_TEMPLATE \
	tmpl/WS_TERM_BY_USER_TEMPLATE \
	users/*.html \
	users/*.php \
	users/*.sql \
	users/*.txt \
	users/*.vsp \
	users/css/*.css \
	users/js/*.js \
	users/users.jsp \
	users/users.rb \
	vad_version \
	version.base \
	version.curr

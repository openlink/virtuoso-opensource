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
nodist_vad_DATA = ods_framework_dav.vad
endif

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
	*.dox \
	*.css \
	*.html \
	*.js \
	*.php \
	*.sql \
	*.txt \
	*.vsp \
	*.vspx \
	*.xml \
	*.xsl \
	ckeditor/*.css \
	ckeditor/*.html \
	ckeditor/*.js \
	ckeditor/images/*.gif \
	ckeditor/lang/*.js \
	ckeditor/plugins/clipboard/dialogs/*.js \
	ckeditor/plugins/colordialog/dialogs/*.js \
	ckeditor/plugins/dialog/*.js \
	ckeditor/plugins/find/dialogs/*.js \
	ckeditor/plugins/flash/dialogs/*.js \
	ckeditor/plugins/flash/images/*.png \
	ckeditor/plugins/image/dialogs/*.js \
	ckeditor/plugins/link/dialogs/*.js \
	ckeditor/plugins/link/images/*.gif \
	ckeditor/plugins/pastetext/dialogs/*.js \
	ckeditor/plugins/scayt/dialogs/*.css \
	ckeditor/plugins/scayt/dialogs/*.js \
	ckeditor/plugins/showblocks/images/*.png \
	ckeditor/plugins/smiley/dialogs/*.js \
	ckeditor/plugins/smiley/images/*.gif \
	ckeditor/plugins/specialchar/dialogs/*.js \
	ckeditor/plugins/specialchar/lang/*.js \
	ckeditor/plugins/styles/styles/*.js \
	ckeditor/plugins/table/dialogs/*.js \
	ckeditor/plugins/tabletools/dialogs/*.js \
	ckeditor/plugins/templates/dialogs/*.js \
	ckeditor/plugins/templates/templates/*.js \
	ckeditor/plugins/templates/templates/images/*.gif \
	ckeditor/plugins/wsc/dialogs/*.css \
	ckeditor/plugins/wsc/dialogs/*.html \
	ckeditor/plugins/wsc/dialogs/*.js \
	ckeditor/skins/kama/*.css \
	ckeditor/skins/kama/*.js \
	ckeditor/skins/kama/*.png \
	ckeditor/skins/kama/images/*.gif \
	ckeditor/skins/kama/images/*.png \
	ckeditor/themes/default/*.js \
	comp/*.js \
	comp/*.xml \
	comp/*.xsl \
	icons/*.gif \
	icons/*.png \
	images/app_ads/*.jpg \
	images/dav_browser/*.png \
	images/*.gif \
	images/*.htm \
	images/*.jfif \
	images/*.jpg \
	images/*.png \
	images/*.psd \
	images/services/*.jpg \
	images/skin/default/*.png \
	images/skin/pager/*.png \
	make_vad.sh \
	oauth/*.css \
	oauth/images/*.gif \
	oauth/images/*.png \
	oauth/make_vad.sh \
	oauth/*.sql \
	oauth/*.vsp \
	oauth/*.vspx \
	oauth/vad_version \
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
	users/css/*.css \
	users/*.html \
	users/*.php \
	users/*.txt \
	users/*.vsp \
	users/*.xsl \
	users/js/*.js \
	users/users.jsp \
	users/users.rb \
	vad_version

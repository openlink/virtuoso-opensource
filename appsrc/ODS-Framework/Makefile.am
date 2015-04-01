#
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#
#  Copyright (C) 1998-2015 OpenLink Software
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
	$(srcdir)/*.dox \
	$(srcdir)/*.css \
	$(srcdir)/*.html \
	$(srcdir)/*.js \
	$(srcdir)/*.php \
	$(srcdir)/*.sql \
	$(srcdir)/*.txt \
	$(srcdir)/*.vsp \
	$(srcdir)/*.vspx \
	$(srcdir)/*.xml \
	$(srcdir)/*.xsl \
	$(srcdir)/ckeditor/*.css \
	$(srcdir)/ckeditor/*.html \
	$(srcdir)/ckeditor/*.js \
	$(srcdir)/ckeditor/images/*.gif \
	$(srcdir)/ckeditor/lang/*.js \
	$(srcdir)/ckeditor/plugins/clipboard/dialogs/*.js \
	$(srcdir)/ckeditor/plugins/colordialog/dialogs/*.js \
	$(srcdir)/ckeditor/plugins/dialog/*.js \
	$(srcdir)/ckeditor/plugins/find/dialogs/*.js \
	$(srcdir)/ckeditor/plugins/flash/dialogs/*.js \
	$(srcdir)/ckeditor/plugins/flash/images/*.png \
	$(srcdir)/ckeditor/plugins/image/dialogs/*.js \
	$(srcdir)/ckeditor/plugins/link/dialogs/*.js \
	$(srcdir)/ckeditor/plugins/link/images/*.gif \
	$(srcdir)/ckeditor/plugins/pastetext/dialogs/*.js \
	$(srcdir)/ckeditor/plugins/scayt/dialogs/*.css \
	$(srcdir)/ckeditor/plugins/scayt/dialogs/*.js \
	$(srcdir)/ckeditor/plugins/showblocks/images/*.png \
	$(srcdir)/ckeditor/plugins/smiley/dialogs/*.js \
	$(srcdir)/ckeditor/plugins/smiley/images/*.gif \
	$(srcdir)/ckeditor/plugins/specialchar/dialogs/*.js \
	$(srcdir)/ckeditor/plugins/specialchar/lang/*.js \
	$(srcdir)/ckeditor/plugins/styles/styles/*.js \
	$(srcdir)/ckeditor/plugins/table/dialogs/*.js \
	$(srcdir)/ckeditor/plugins/tabletools/dialogs/*.js \
	$(srcdir)/ckeditor/plugins/templates/dialogs/*.js \
	$(srcdir)/ckeditor/plugins/templates/templates/*.js \
	$(srcdir)/ckeditor/plugins/templates/templates/images/*.gif \
	$(srcdir)/ckeditor/plugins/wsc/dialogs/*.css \
	$(srcdir)/ckeditor/plugins/wsc/dialogs/*.html \
	$(srcdir)/ckeditor/plugins/wsc/dialogs/*.js \
	$(srcdir)/ckeditor/skins/kama/*.css \
	$(srcdir)/ckeditor/skins/kama/*.js \
	$(srcdir)/ckeditor/skins/kama/*.png \
	$(srcdir)/ckeditor/skins/kama/images/*.gif \
	$(srcdir)/ckeditor/skins/kama/images/*.png \
	$(srcdir)/ckeditor/themes/default/*.js \
	$(srcdir)/comp/*.js \
	$(srcdir)/comp/*.xml \
	$(srcdir)/comp/*.xsl \
	$(srcdir)/icons/*.gif \
	$(srcdir)/icons/*.png \
	$(srcdir)/images/app_ads/*.jpg \
	$(srcdir)/images/dav_browser/*.png \
	$(srcdir)/images/*.gif \
	$(srcdir)/images/*.htm \
	$(srcdir)/images/*.jfif \
	$(srcdir)/images/*.jpg \
	$(srcdir)/images/*.png \
	$(srcdir)/images/*.psd \
	$(srcdir)/images/services/*.jpg \
	$(srcdir)/images/skin/default/*.png \
	$(srcdir)/images/skin/pager/*.png \
	make_vad.sh \
	$(srcdir)/oauth/*.css \
	$(srcdir)/oauth/images/*.gif \
	$(srcdir)/oauth/images/*.png \
	oauth/make_vad.sh \
	$(srcdir)/oauth/*.sql \
	$(srcdir)/oauth/*.vsp \
	$(srcdir)/oauth/*.vspx \
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
	$(srcdir)/users/css/*.css \
	$(srcdir)/users/*.html \
	$(srcdir)/users/*.php \
	$(srcdir)/users/*.txt \
	$(srcdir)/users/*.vsp \
	$(srcdir)/users/*.xsl \
	$(srcdir)/users/js/*.js \
	users/users.jsp \
	users/users.rb \
	vad_version

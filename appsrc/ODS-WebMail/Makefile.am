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

nodist_vad_DATA = ods_webmail_dav.vad

CLEANFILES =  \
	*.vad \
	virtuoso.db \
	virtuoso.ini \
	virtuoso.lck \
	virtuoso.log \
	virtuoso.pxa \
	virtuoso.tdb \
	virtuoso.trx

ods_webmail_dav.vad: $(EXTRA_DIST)
	PATH="$(TOP)/binsrc/virtuoso:$(TOP)/binsrc/tests:.:$$PATH" PORT=$(PORT) HOME="$(TOP)" HOST=localhost sh ./make_vad.sh

clean-local:
	-rm -rf vad

EXTRA_DIST = \
	install/odbc_mail.ini \
	make_vad.sh \
	sql/*.sql \
	sql/eml/*.sql \
	sql/install.bat \
	sql/res/*.sql \
	sql/uninstall.bat \
	sql/utl/*.sql \
	www-root/*.vsp \
	www-root/mail/i/*.gif \
	www-root/mail/i/*.jpg \
	www-root/mail/i/*.png \
	www-root/mail/i/css/*.css \
	www-root/mail/i/dav/*.gif \
	www-root/mail/i/js/*.js \
	www-root/mail/i/rte/css/*.css \
	www-root/mail/i/rte/images/*.gif \
	www-root/mail/i/rte/js/*.htm \
	www-root/mail/i/rte/js/*.js \
	www-root/mail/p/*.vsp \
	www-root/mail/p/*.xml \
	www-root/mail/p/*.xsl \
	www-root/res/*.vsp \
	www-root/res/*.vspx \
	www-root/res/css/*.css \
	www-root/res/image/*.png \
	www-root/res/image/dav_browser/*.png \
	www-root/res/template/*.xsl \
	xslt/*.xml \
	xslt/*.xsl \
	xslt/export/*.xsl

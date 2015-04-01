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
nodist_vad_DATA = ods_webmail_dav.vad
endif

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
	$(srcdir)/install/*.htm \
	install/odbc_mail.ini \
	make_vad.sh \
	$(srcdir)/sql/*.sql \
	$(srcdir)/sql/eml/*.sql \
	$(srcdir)/sql/res/*.sql \
	$(srcdir)/sql/utl/*.sql \
	vad_version \
	$(srcdir)/www-root/*.vsp \
	$(srcdir)/www-root/mail/i/*.gif \
	$(srcdir)/www-root/mail/i/*.jpg \
	$(srcdir)/www-root/mail/i/*.png \
	$(srcdir)/www-root/mail/i/css/*.css \
	$(srcdir)/www-root/mail/i/dav/*.gif \
	$(srcdir)/www-root/mail/i/js/*.js \
	$(srcdir)/www-root/mail/p/*.vsp \
	$(srcdir)/www-root/mail/p/*.xml \
	$(srcdir)/www-root/mail/p/*.xsl \
	$(srcdir)/www-root/res/*.vsp \
	$(srcdir)/xslt/*.xml \
	$(srcdir)/xslt/*.xsl \
	$(srcdir)/xslt/export/*.xsl

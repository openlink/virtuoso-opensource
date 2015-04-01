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
nodist_vad_DATA = ods_blog_dav.vad
endif

CLEANFILES = \
	*.vad \
	make_ods_blog_vad.log \
	make_ods_blog_vad.xml \
	virtuoso.db \
	virtuoso.ini \
	virtuoso.lck \
	virtuoso.log \
	virtuoso.pxa \
	virtuoso.tdb \
	virtuoso.trx

ods_blog_dav.vad: $(EXTRA_DIST)
	PATH="$(TOP)/binsrc/virtuoso:$(TOP)/binsrc/tests:.:$$PATH" PORT=$(PORT) HOME="$(TOP)" HOST=localhost sh ./make_vad.sh

clean-local:
	-rm -rf vad

EXTRA_DIST = \
	$(srcdir)/*.dox \
	$(srcdir)/*.sql \
	$(srcdir)/*.vsp \
	$(srcdir)/*.vspx \
	make_vad.sh \
	$(srcdir)/public/*.vsp \
	$(srcdir)/public/*.vspx \
	$(srcdir)/public/css/*.css \
	$(srcdir)/public/images/*.gif \
	$(srcdir)/public/images/*.jpg \
	$(srcdir)/public/images/*.png \
	$(srcdir)/public/images/dav_browser/*.png \
	public/images/fav.ico \
	$(srcdir)/public/images/smileys/*.gif \
	$(srcdir)/public/scripts/*.js \
	$(srcdir)/templates/*.vspx \
	$(srcdir)/templates/atlantis/*.css \
	$(srcdir)/templates/atlantis/*.vspx \
	$(srcdir)/templates/autumn/*.css \
	$(srcdir)/templates/autumn/*.vspx \
	$(srcdir)/templates/blue_left/*.css \
	$(srcdir)/templates/blue_left/*.vspx \
	$(srcdir)/templates/columns_clean/*.css \
	$(srcdir)/templates/columns_clean/*.vspx \
	$(srcdir)/templates/default/*.css \
	$(srcdir)/templates/default/*.vspx \
	$(srcdir)/templates/digital_bazaar/*.css \
	$(srcdir)/templates/digital_bazaar/*.vspx \
	$(srcdir)/templates/digital_bazaar/images/*.jpg \
	$(srcdir)/templates/digital_bazaar/images/*.png \
	$(srcdir)/templates/micro/*.css \
	$(srcdir)/templates/micro/*.vspx \
	$(srcdir)/templates/modern/*.css \
	$(srcdir)/templates/modern/*.vspx \
	$(srcdir)/templates/newspaper_view/*.css \
	$(srcdir)/templates/newspaper_view/*.vspx \
	$(srcdir)/templates/newspaper_view/images/*.png \
	$(srcdir)/templates/openlink/*.css \
	$(srcdir)/templates/openlink/*.vspx \
	$(srcdir)/templates/openlink_classic/*.css \
	$(srcdir)/templates/round_the_corner/*.css \
	$(srcdir)/templates/round_the_corner/*.vspx \
	$(srcdir)/templates/round_the_corner/images/*.gif \
	$(srcdir)/templates/round_wheat/*.css \
	$(srcdir)/templates/round_wheat/*.vspx \
	$(srcdir)/templates/seattle/*.css \
	$(srcdir)/templates/seattle/*.vspx \
	$(srcdir)/templates/spring/*.css \
	$(srcdir)/templates/spring/*.vspx \
	$(srcdir)/templates/squeaky_clean/*.css \
	$(srcdir)/templates/squeaky_clean/*.vspx \
	$(srcdir)/templates/squeaky_clean_2col/*.css \
	$(srcdir)/templates/squeaky_clean_2col/*.vspx \
	$(srcdir)/templates/thin_clean/*.css \
	$(srcdir)/templates/thin_clean/*.vspx \
	$(srcdir)/templates/thin_pastel/*.css \
	$(srcdir)/templates/thin_pastel/*.vspx \
	vad_version \
	$(srcdir)/widgets/*.xsl

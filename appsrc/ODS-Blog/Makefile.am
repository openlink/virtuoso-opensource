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
	*.dox \
	*.sql \
	*.vsp \
	*.vspx \
	make_vad.sh \
	public/*.vsp \
	public/*.vspx \
	public/css/*.css \
	public/images/*.gif \
	public/images/*.jpg \
	public/images/*.png \
	public/images/dav_browser/*.png \
	public/images/fav.ico \
	public/images/smileys/*.gif \
	public/scripts/*.js \
	templates/*.vspx \
	templates/atlantis/*.css \
	templates/atlantis/*.vspx \
	templates/autumn/*.css \
	templates/autumn/*.vspx \
	templates/blue_left/*.css \
	templates/blue_left/*.vspx \
	templates/columns_clean/*.css \
	templates/columns_clean/*.vspx \
	templates/default/*.css \
	templates/default/*.vspx \
	templates/digital_bazaar/*.css \
	templates/digital_bazaar/*.vspx \
	templates/digital_bazaar/images/*.jpg \
	templates/digital_bazaar/images/*.png \
	templates/micro/*.css \
	templates/micro/*.vspx \
	templates/modern/*.css \
	templates/modern/*.vspx \
	templates/newspaper_view/*.css \
	templates/newspaper_view/*.vspx \
	templates/newspaper_view/images/*.png \
	templates/openlink/*.css \
	templates/openlink/*.vspx \
	templates/openlink_classic/*.css \
	templates/round_the_corner/*.css \
	templates/round_the_corner/*.vspx \
	templates/round_the_corner/images/*.gif \
	templates/round_wheat/*.css \
	templates/round_wheat/*.vspx \
	templates/seattle/*.css \
	templates/seattle/*.vspx \
	templates/spring/*.css \
	templates/spring/*.vspx \
	templates/squeaky_clean/*.css \
	templates/squeaky_clean/*.vspx \
	templates/squeaky_clean_2col/*.css \
	templates/squeaky_clean_2col/*.vspx \
	templates/thin_clean/*.css \
	templates/thin_clean/*.vspx \
	templates/thin_pastel/*.css \
	templates/thin_pastel/*.vspx \
	vad_version \
	widgets/*.xsl

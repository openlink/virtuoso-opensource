#  
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#  
#  Copyright (C) 1998-2024 OpenLink Software
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

if WITH_CONDUCTOR_VAD
nodist_vad_DATA = conductor_dav.vad
endif

NEED_VERSION	= 07.20.3226
STICKER		= conductor_sticker.xml
VERBOSE		= #--verbose
VERSION		= `cat vad_version`

DAV_FLAGS	= $(VERBOSE) \
		--prefix "$(srcdir)" 	\
		--var="BASE_PATH=/DAV/VAD" \
		--var="ISDAV=1" \
		--var="NEED_VERSION=$(NEED_VERSION)" \
		--var="TYPE=dav" \
		--var="VERSION=$(VERSION)"

conductor_dav.vad: $(EXTRA_DIST) Makefile
	$(PYTHON) $(top_srcdir)/binsrc/vadpacker/vadpacker.py \
		-o $(builddir)/conductor_dav.vad \
		$(DAV_FLAGS) \
		$(srcdir)/$(STICKER)


# ----------------------------------------------------------------------
#
#  Cleanup
#
# ----------------------------------------------------------------------
CLEANFILES =  \
	conductor_dav.vad \
	conductor_filesystem.vad \
	mkvad.output \
	mkvad.pxa \
	mkvad.tdb \
	vad_dav.xml \
	vad_fs.xml \
	yacutia_dav.vad \
	yacutia_filesystem.vad

clean-local:
	-$(RM) -rf vad
	-$(RM) sticker.out


# ----------------------------------------------------------------------
#
#  Additional files to distribute
#
# ----------------------------------------------------------------------
EXTRA_DIST = \
	$(srcdir)/$(STICKER) \
	$(srcdir)/*.dtd \
	$(srcdir)/*.htm \
	$(srcdir)/*.html \
	$(srcdir)/*.vsp \
	$(srcdir)/*.vspx \
	$(srcdir)/*.xml \
	$(srcdir)/*.xsl \
	$(srcdir)/INSTALL \
	$(srcdir)/README \
	$(srcdir)/conductor.list \
	$(srcdir)/css/*.css \
	$(srcdir)/dav/*.css \
	$(srcdir)/dav/*.js \
	$(srcdir)/dav/*.sql \
	$(srcdir)/dav/*.vsp \
	$(srcdir)/dav/*.xsl \
	$(srcdir)/dav/image/*.gif \
	$(srcdir)/dav/image/*.png \
	$(srcdir)/dav/image/dav/*.gif \
	$(srcdir)/dav/image/dav/*.png \
	$(srcdir)/help/*.xml \
	$(srcdir)/images/*.gif \
	$(srcdir)/images/*.jpg \
	$(srcdir)/images/*.png \
	$(srcdir)/images/buttons/*.png \
	$(srcdir)/images/dav_browser/*.png \
	$(srcdir)/images/icons/*.gif \
	$(srcdir)/images/icons/*.png \
	$(srcdir)/images/icons/*.svg \
	$(srcdir)/images/pager/*.png \
	$(srcdir)/js/*.js \
	$(srcdir)/sql/*.sql \
	$(srcdir)/syntax/*.css \
	$(srcdir)/syntax/*.js \
	$(srcdir)/vad_version

#
#  $Id$
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

if WITH_FCT_VAD
nodist_vad_DATA = fct_dav.vad
endif


VERSION		= `cat vad_version`
NEED_VERSION	= 07.20.3226
FCT_STICKER	= fct_sticker.xml

CLEANFILES =  \
	*.log \
	*.vad \
	virtuoso.db \
	virtuoso.ini \
	virtuoso.lck \
	virtuoso.log \
	virtuoso.pxa \
	virtuoso.tdb \
	virtuoso.trx \
        vad_dav.xml \
        vad_fs.xml

fct_dav.vad: oat $(EXTRA_DIST) Makefile
	$(PYTHON) $(top_srcdir)/binsrc/vadpacker/vadpacker.py \
		-o fct_dav.vad \
		--var="VERSION=$(VERSION)" \
		--var="BASE_PATH=/DAV/VAD" \
		--var="TYPE=dav" \
		--var="ISDAV=1" \
		--var="NEED_VERSION=$(NEED_VERSION)" \
		$(FCT_STICKER)

oat:
	ln -sf $(top_srcdir)/binsrc/oat .

clean-local:
	-rm -rf vad
	-$(RM) -f oat

# ----------------------------------------------------------------------
#
#  Additional files to distribute
#
# ----------------------------------------------------------------------
EXTRA_DIST = \
	$(srcdir)/*.html \
	$(srcdir)/*.txt \
	$(srcdir)/*.vsp \
	$(srcdir)/conductor/*.js \
	$(srcdir)/conductor/*.sql \
	$(srcdir)/conductor/*.vspx \
	$(srcdir)/css/*.css \
	$(srcdir)/images/*.gif \
	$(srcdir)/images/*.png \
	$(srcdir)/images/*.svg \
	$(srcdir)/js/*.js \
	$(srcdir)/owl/*.owl \
	$(srcdir)/rdfdesc/*.vsp \
	$(srcdir)/sql/*.sql \
	$(srcdir)/xslt/*.xsl \
	$(srcdir)/vad_version \
	$(srcdir)/VirtTripleLoader/.classpath \
	$(srcdir)/VirtTripleLoader/.project \
	$(srcdir)/VirtTripleLoader/src/virtTripleLoaderInit/*.java \
	$(srcdir)/www/*.html \
	$(srcdir)/www/*.vsp

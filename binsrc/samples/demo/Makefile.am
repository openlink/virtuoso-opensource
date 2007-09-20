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

noinst_DATA = demo.db demo.ini
nodist_vad_DATA = doc_dav.vad demo_dav.vad

if WITH_HTMLDOC
#dist_htmldoc_DATA = $(top_srcdir)/docsrc/html_virt/*.html
#dist_pdfdoc_DATA = $(top_srcdir)/docsrc/pdf/virtdocs.pdf
endif

install-data-local:
	mkdir -p "$(dbdir)"
	$(INSTALL_DATA) default.ini "$(DESTDIR)$(dbdir)"/virtuoso.ini
if WITH_HTMLDOC
	mkdir -p "$(htmldocdir)"
	$(INSTALL_DATA) $(top_srcdir)/docsrc/html_virt/*.html "$(DESTDIR)$(htmldocdir)"
endif

uninstall-local:
	rm -f "$(DESTDIR)$(dbdir)/virtuoso.ini"
if WITH_HTMLDOC
	rm -f "$(DESTDIR)$(htmldocdir)"/*.html
endif


CLEANFILES =  \
	*.log \
	*.output \
	*.vad \
	art.tar \
	default.ini \
	demo.db \
	demo.ini \
	demo.lck \
	demo.tdb \
	demo.trx \
	doc.db \
	doc.trx \
	doc_vad_dav.xml \
	flags.tar \
	make__demo_vad.xml \
	mkdemo.tdb \
	mkdoc.tdb \
	srv_errors.txt \
	virtuoso.db \
	virtuoso.ini \
	virtuoso.pxa \
	virtuoso.tdb \
	virtuoso.trx \
	xmemdump.txt

clean-local:
	-rm -rf art flags vad plugin classlib

demo.db: mkdemo.sh mkdemo.sql mkdemo.ini doc_dav.vad demo_dav.vad
	PATH="$(TOP)/binsrc/virtuoso:$(TOP)/binsrc/tests:.:$$PATH" PORT=$(PORT) HOME="$(TOP)" HTMLDOC="$(HTMLDOC)" \
	     prefix="$(prefix)" HOST=localhost sh mkdemo.sh

doc_dav.vad: mkdoc.sh mksearch.sql drop.sql mkdemo.ini
	PATH="$(TOP)/binsrc/virtuoso:$(TOP)/binsrc/tests:.:$$PATH" PORT=$(PORT) HOME="$(TOP)" HTMLDOC="$(HTMLDOC)" \
	     HOST=localhost sh mkdoc.sh

demo_dav.vad: make_vad.sh $(EXTRA_DIST)
	PATH="$(TOP)/binsrc/virtuoso:$(TOP)/binsrc/tests:.:$$PATH" PORT=$(PORT) HOME="$(TOP)" HTMLDOC="$(HTMLDOC)" \
	     HOST=localhost sh make_vad.sh



# ----------------------------------------------------------------------
#
#  Additional files to distribute
#
# ----------------------------------------------------------------------
EXTRA_DIST = \
	*.owl \
	*.sql \
	*.txt \
	art.tar.gz \
	CAT1 \
	CAT2 \
	CAT3 \
	CAT4 \
	CAT5 \
	CAT6 \
	CAT7 \
	CAT8 \
	EMP1 \
	EMP2 \
	EMP3 \
	EMP4 \
	EMP5 \
	EMP6 \
	EMP7 \
	EMP8 \
	EMP9 \
	flags.tar.gz \
	make_vad.sh \
	mkdemo.bat \
	mkdemo.ini \
	mkdemo.sh \
	mkdoc.sh \
	vad_version

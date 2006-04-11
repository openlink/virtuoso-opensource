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

nodist_demo_DATA = demo.db demo.ini
nodist_vad_DATA = doc_dav.vad

if WITH_HTMLDOC
#dist_htmldoc_DATA = $(top_srcdir)/docsrc/html_virt/*.html
#dist_pdfdoc_DATA = $(top_srcdir)/docsrc/pdf/virtdocs.pdf
endif

install-data-local:
	mkdir -p "$(dbdir)"
	$(INSTALL_DATA) default.ini "$(dbdir)"/virtuoso.ini
	mkdir -p "$(htmldocdir)"
	$(INSTALL_DATA) $(top_srcdir)/docsrc/html_virt/*.html "$(htmldocdir)"

uninstall-local:
	rm -f "$(dbdir)/virtuoso.ini"
	rm -f "$(htmldocdir)"/*.html

CLEANFILES =  \
	demo.db \
	demo.trx \
	demo.log \
	demo.lck \
	demo.tdb \
	demo.ini \
	default.ini \
	mkdemo.output \
	virtuoso.tdb \
	srv_errors.txt \
	xmemdump.txt \
	virtuoso.ini \
	virtuoso.pxa \
	*.vad \
	doc_vad_dav.xml \
	mkdoc.output

#	$(top_srcdir)/binsrc/tutorial/tutorial_dav.vad $(top_srcdir)/binsrc/yacutia/conductor_dav.vad $(top_srcdir)/binsrc/bpel/bpel_dav.vad
demo.db: mkdemo.sh mkdemo.sql mkdemo.ini doc_dav.vad 
	PATH="$(TOP)/binsrc/virtuoso:$(TOP)/binsrc/tests:.:$$PATH" PORT=$(PORT) HOME="$(TOP)" HTMLDOC="$(HTMLDOC)" \
	     prefix="$(prefix)" HOST=localhost sh mkdemo.sh

doc_dav.vad: mkdoc.sh mksearch.sql drop.sql mkdemo.ini
	PATH="$(TOP)/binsrc/virtuoso:$(TOP)/binsrc/tests:.:$$PATH" PORT=$(PORT) HOME="$(TOP)" HTMLDOC="$(HTMLDOC)" \
	     HOST=localhost sh mkdoc.sh


# ----------------------------------------------------------------------
#
#  Additional files to distribute
#
# ----------------------------------------------------------------------
EXTRA_DIST = \
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
	mkdemo.bat \
	mkdemo.ini \
	mkdemo.sh \
	mkdoc.sh \
	*.sql \
	*.txt

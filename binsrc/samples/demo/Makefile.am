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

if WITH_DEMO_VAD
nodist_vad_DATA = doc_dav.vad demo_dav.vad
endif

if WITH_HTMLDOC
#dist_htmldoc_DATA = $(top_srcdir)/docsrc/html_virt/*.html
#dist_pdfdoc_DATA = $(top_srcdir)/docsrc/pdf/virtdocs.pdf
endif


# ----------------------------------------------------------------------
#  Test loading of vad packages by creating demo.db
# ----------------------------------------------------------------------
TESTS=mkdemo.sh
TESTS_ENVIRONMENT=PATH="$(TOP)/binsrc/virtuoso:$(TOP)/binsrc/tests:.:$$PATH" \
	PORT=$(PORT) \
	HOME="$(TOP)" \
	HTMLDOC="$(HTMLDOC)" \
	prefix="$(prefix)" \
	HOST=localhost 


# ----------------------------------------------------------------------
#
#  Building documentation vad
#
# ----------------------------------------------------------------------
doc_dav.vad: mkdoc.sh mksearch.sql drop.sql mkdemo.ini
	PATH="$(TOP)/binsrc/virtuoso:$(TOP)/binsrc/tests:.:$$PATH" \
	PORT=$(PORT) \
	HOME="$(TOP)" \
	HTMLDOC="$(HTMLDOC)" \
	HOST=localhost \
	$(SHELL) mkdoc.sh


# ----------------------------------------------------------------------
#
#  Building demo vad
#
# ----------------------------------------------------------------------
DEMO_DEPS=\
	*.owl \
	*.sql \
	*.txt \
	art.tar.gz \
	flags.tar.gz \
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
	thalia_test/*.rq \
	thalia_test/*.sql \
	thalia_test/*.owl \
	tpc-h/*.sql \
	vad_version \
	make_vad.sh

demo_dav.vad: make_vad.sh $(DEMO_DEPS) doc_dav.vad
	PATH="$(TOP)/binsrc/virtuoso:$(TOP)/binsrc/tests:.:$$PATH" \
	PORT=$(PORT) \
	HOME="$(TOP)" \
	HTMLDOC="$(HTMLDOC)" \
	HOST=localhost \
	$(SHELL) make_vad.sh



# ----------------------------------------------------------------------
#
#  Building demo database
#
# ----------------------------------------------------------------------
demo.db: mkdemo.sh mkdemo.ini doc_dav.vad demo_dav.vad
	PATH="$(TOP)/binsrc/virtuoso:$(TOP)/binsrc/tests:.:$$PATH" \
	PORT=$(PORT) \
	HOME="$(TOP)" \
	HTMLDOC="$(HTMLDOC)" \
	prefix="$(prefix)" \
	HOST=localhost \
	$(SHELL) mkdemo.sh


# ----------------------------------------------------------------------
#
#  Installing components
#
# ----------------------------------------------------------------------

if !WITH_IM
REM_IM_C=;
endif
if !WITH_HSL
REM_HSL_C=;
endif
if !WITH_WBXML2
REM_WBXML2_C=;
endif
if !HAVE_PHP5
REM_PHP5_C=;
endif
if !WITH_PYTHON
REM_PYTHON_C=;
endif
if !WITH_PERL
REM_PERL_C=;
endif
if !WITH_RUBY
REM_RUBY_C=;
endif

do_subst = \
	sed -e 's,[@]PREFIX[@],$(prefix),g' \
            -e 's,[@]DESTDIR[@],$(DESTDIR),g' \
            -e 's,[@]VADDIR[@],$(vaddir),g' \
            -e 's,[@]HOSTINGDIR[@],$(hostingdir),g' \
            -e 's,[@]DBDIR[@],$(dbdir),g' \
            -e 's,[@]DEMODIR[@],$(demodir),g' \
            -e 's,[@]HTTPROOTDIR[@],$(httprootdir),g' \
	    -e 's,[@]REM_IM[@],$(REM_IM_C),g' \
	    -e 's,[@]REM_HSL[@],$(REM_HSL_C),g' \
	    -e 's,[@]REM_WBXML2[@],$(REM_WBXML2_C),g' \
	    -e 's,[@]REM_PHP5[@],$(REM_PHP5_C),g' \
	    -e 's,[@]REM_PYTHON[@],$(REM_PYTHON_C),g' \
	    -e 's,[@]REM_PERL[@],$(REM_PERL_C),g' \
	    -e 's,[@]REM_RUBY[@],$(REM_RUBY_C),g'

install-data-local:
	$(do_subst) < "$(srcdir)/install_ini.sh.in" > "install_ini.sh"
	chmod +x install_ini.sh
	mkdir -p "$(DESTDIR)$(dbdir)"
	$(SHELL) install_ini.sh database
if WITH_HTMLDOC
	mkdir -p "$(DESTDIR)$(htmldocdir)"
	$(INSTALL_DATA) $(top_srcdir)/docsrc/html_virt/*.html "$(DESTDIR)$(htmldocdir)"
	mkdir -p "$(DESTDIR)$(htmldocdir)/../images"
	(cd $(top_srcdir)/docsrc/images; find . -name \*.gif -print | cpio -dump "$(DESTDIR)$(htmldocdir)/../images")
	(cd $(top_srcdir)/docsrc/images; find . -name \*.jpg -print | cpio -dump "$(DESTDIR)$(htmldocdir)/../images")
	(cd $(top_srcdir)/docsrc/images; find . -name \*.png -print | cpio -dump "$(DESTDIR)$(htmldocdir)/../images")
	(cd $(top_srcdir)/docsrc/images; find . -name \*.ico -print | cpio -dump "$(DESTDIR)$(htmldocdir)/../images")
endif

uninstall-local:
	rm -f "$(DESTDIR)$(dbdir)/virtuoso.ini"
if WITH_HTMLDOC
	rm -rf "$(DESTDIR)$(htmldocdir)/../images"
	rm -rf "$(DESTDIR)$(htmldocdir)"
endif


# ----------------------------------------------------------------------
#
#  Cleanup
#
# ----------------------------------------------------------------------
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
	xmemdump.txt \
	install_ini.sh

clean-local:
	-rm -rf art flags vad plugin classlib


# ----------------------------------------------------------------------
#
#  Additional files to distribute
#
# ----------------------------------------------------------------------
EXTRA_DIST = \
	$(DEMO_DEPS) \
	install_ini.sh.in \
	default-virtuoso.ini \
	mkdemo.bat \
	mkdemo.ini \
	mkdemo.sh \
	mkdoc.sh

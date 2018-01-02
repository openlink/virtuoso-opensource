#  
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#  
#  Copyright (C) 1998-2018 OpenLink Software
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


include ../../../Makeconfig
include ../../../Makerules
include ../../../virtappl.inc

DEST_DIR=$(TOP)/binsrc/hosting/lib

DARWIN_OPSYS := $(filter "Darwin", $(OPSYS))

LDFLAGS += $(FCGI_LDFLAGS)
CFLAGS += $(FCGI_CFLAGS)
CCINCL += -I$(TOP)/libsrc/Wi -I$(TOP)/libsrc/plugin -I$(TOP)/libsrc/langfunc

PLUGIN_GENERATED_SRC = \
	import_gate_virtuoso.c
        		       

PLUGIN_SRC = \
	hosting_fcgi.c \
	cgi_fcgi.c \
	$(PLUGIN_GENERATED_SRC)

PLUGIN_OBJ =  $(patsubst %.c, %.o, $(PLUGIN_SRC))
LT_PLUGIN_OBJ =  $(patsubst %.c, %.lo, $(PLUGIN_SRC))

.PHONY: all
all: hosting_fcgi.la

.PHONY: install
install: $(DEST_DIR)/hosting_fcgi.la

$(DEST_DIR)/hosting_fcgi.la : hosting_fcgi.la
	$(LIBTOOL) --mode=install $(INSTALL) hosting_fcgi.la $(DEST_DIR)
	$(LIBTOOL) --finish $(DEST_DIR)

hosting_fcgi.la: $(LT_PLUGIN_OBJ) GNUmakefile
	$(LIBTOOL) --mode=link $(CC) -module $(FCGI_LDFLAGS) \
		-export-dynamic -rpath $(DEST_DIR) -version-info 1:0 \
		-o $@ -lc \
		$(LT_PLUGIN_OBJ)

import_gate_virtuoso.c: ../../../libsrc/plugin/import_gate_virtuoso.c
	$(LN_S) $< $@

.PHONY: generated
generated: $(PLUGIN_GENERATED_SRC)

.PHONY: clean
clean:
	$(RM) $(PLUGIN_GENERATED_SRC)
	$(LIBTOOL) $(RM) *.lo
	$(LIBTOOL) $(RM) hosting_fcgi.la
	$(LIBTOOL) $(RM) $(DEST_DIR)/hosting_fcgi.la

ifeq ($(findstring gcc, $(CC)),gcc)
SRC_PLUGIN_DEPS=$(PLUGIN_SRC:%.c=.deps/%.d)

.PHONY: deps
deps:	depfc.mk

depfc.mk: $(SRC_PLUGIN_DEPS) GNUmakefile
	@echo "making deprb.mk"
	@cat $(SRC_PLUGIN_DEPS) > depfc.mk
endif

have_deprb=$(wildcard depfc.mk)
ifeq ($(have_depfc),depfc.mk)
include depfc.mk
endif

distdir:

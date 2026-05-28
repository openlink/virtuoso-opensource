#
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#
#  Copyright (C) 1998-2026 OpenLink Software
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
VOS_ROOT ?= ../../..
PLUGIN_DIR := $(VOS_ROOT)/libsrc/plugin

CC ?= cc
UNAME_S := $(shell uname -s)

CFLAGS_COMMON := -D_GNU_SOURCE -DGLOBALREF=extern -D_USRDLL -DHAVE_CONFIG_H -fPIC
CFLAGS_COMMON += -I$(VOS_ROOT)/libsrc
CFLAGS_COMMON += -I$(VOS_ROOT)/libsrc/Dk
CFLAGS_COMMON += -I$(VOS_ROOT)/libsrc/Wi
CFLAGS_COMMON += -I$(VOS_ROOT)/libsrc/plugin
CFLAGS_COMMON += -I$(VOS_ROOT)/libsrc/Xml.new
CFLAGS_COMMON += -I$(VOS_ROOT)/libsrc/langfunc
CFLAGS_COMMON += -I$(VOS_ROOT)/libsrc/odbcsdk/include

ifeq ($(UNAME_S),Darwin)
  OPENSSL_PREFIX ?= $(firstword $(wildcard /opt/homebrew/opt/openssl@3 /opt/homebrew/opt/openssl /usr/local/opt/openssl@3 /usr/local/opt/openssl))
  ifneq ($(OPENSSL_PREFIX),)
    CFLAGS_COMMON += -I$(OPENSSL_PREFIX)/include
  endif
  SHARED_FLAGS := -bundle -undefined dynamic_lookup
  PLUGIN_EXT := so
else
  SHARED_FLAGS := -shared -Wl,--allow-shlib-undefined
  PLUGIN_EXT := so
endif

TARGET := opencypher_plugin.$(PLUGIN_EXT)
SOURCES := opencypher_plugin.c opencypher_translate.c opencypher_arena.c opencypher_lexer.c opencypher_box.c $(PLUGIN_DIR)/import_gate_virtuoso.c

.PHONY: all clean check-allocators check-symbols install info

all: check-allocators $(TARGET)
	@echo "Build complete: $(TARGET)"
	@echo "Run 'make check-symbols' to verify plugin symbols"

$(TARGET): $(SOURCES) opencypher_translate.h opencypher_arena.h opencypher_lexer.h opencypher_box.h
	$(CC) $(CFLAGS_COMMON) $(CFLAGS) $(SHARED_FLAGS) -o $@ $(SOURCES)

check-allocators:
	@if [ -x ./check_allocators.sh ]; then ./check_allocators.sh; fi

check-symbols: $(TARGET)
	@echo "Checking plugin symbols..."
	@echo "Gate symbol:"
	@nm -gU $(TARGET) 2>/dev/null | grep _gate || echo "WARNING: _gate not found"
	@echo "Entry point:"
	@nm -gU $(TARGET) 2>/dev/null | grep _opencypher_plugin_check || echo "WARNING: _opencypher_plugin_check not found"
	@echo "BIF functions:"
	@nm -gU $(TARGET) 2>/dev/null | grep bif_opencypher || echo "BIFs found above"

HOSTING_DIR ?= $(VOS_ROOT)/binsrc/hosting

install: $(TARGET)
	@mkdir -p $(HOSTING_DIR)
	cp $(TARGET) $(HOSTING_DIR)/
	@echo "Installed $(TARGET) -> $(HOSTING_DIR)/"
	@echo "Plugin is optional; enable it explicitly in the target virtuoso.ini,"
	@echo "for example:"
	@echo "  LoadN = plain, opencypher_plugin"
	@echo "Restart Virtuoso, then verify:"
	@echo "  SELECT DB.DBA.OPENCYPHER_PLUGIN_VERSION();"
	@echo "  SELECT DB.DBA.OPENCYPHER_PLUGIN_AVAILABLE();  -- expect 1"

info:
	@echo "openCypher VSEI Plugin - Phase 11 Build"
	@echo "==================================="
	@echo "Target: $(TARGET)"
	@echo "Sources: $(SOURCES)"
	@echo "CC: $(CC)"
	@echo "Platform: $(UNAME_S)"

clean:
	rm -f $(TARGET)

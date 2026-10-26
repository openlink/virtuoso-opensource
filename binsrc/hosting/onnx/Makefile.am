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
# ONNX Plugin for Virtuoso
#
# Requires a static ONNX Runtime library (libonnxruntime.a), which is linked
# into the plugin and the helper. Pass its installation prefix
# (containing include/ and lib/ subdirectories) to configure.
#
# Example:
#   ./configure --enable-onnxruntime=/usr/local/onnxruntime
#   make
#

if WITH_ONNX
hosting_LTLIBRARIES = vonnx.la
hosting_PROGRAMS = onnx_helper

# Run by users to prepare their own models, so it goes in bin.
dist_bin_SCRIPTS = virtuoso-export-embedding-model

# ONNX Runtime is linked into the plugin and the helper, so its license and
# the notices for the libraries it includes ship with them.
onnxdocdir = $(docdir)/onnxruntime
dist_onnxdoc_DATA = \
	LICENSE-onnxruntime \
	ThirdPartyNotices-onnxruntime.txt
endif

vonnx_la_SOURCES = \
	$(srcdir)/onnx_plugin.c \
	$(top_srcdir)/libsrc/plugin/import_gate_virtuoso.c

vonnx_la_CFLAGS  = @VIRT_AM_CFLAGS@
vonnx_la_CFLAGS += -std=c99 -D_USRDLL -DHAVE_CONFIG_H
vonnx_la_CFLAGS += -I$(top_srcdir)/libsrc
vonnx_la_CFLAGS += -I$(top_srcdir)/libsrc/Dk
vonnx_la_CFLAGS += -I$(top_srcdir)/libsrc/Wi
vonnx_la_CFLAGS += -I$(top_srcdir)/libsrc/plugin
vonnx_la_CFLAGS += -I$(top_srcdir)/libsrc/langfunc
vonnx_la_CFLAGS += -I$(top_srcdir)/libsrc/odbcsdk/include
vonnx_la_CFLAGS += @ONNXRUNTIME_CFLAGS@

# -shared: a plugin is only ever dlopen'ed, so no static archive is built or
# installed.
vonnx_la_LDFLAGS = -module -shared -avoid-version -export-dynamic
vonnx_la_LDFLAGS += -export-symbols vonnx.exp
vonnx_la_LIBADD = @ONNXRUNTIME_LIBS@

onnx_helper_SOURCES = $(srcdir)/onnx_helper.c $(srcdir)/onnx_bpe_classes.h
onnx_helper_CFLAGS = -std=gnu11 -D_GNU_SOURCE @ONNXRUNTIME_CFLAGS@
onnx_helper_LDADD = @ONNXRUNTIME_LIBS@ -lm

if WITH_ONNX
all-local: stage-onnx-runtime

# Verify the default model before staging it, fetching it first if needed.
#
# The model is a binary artifact that nothing else validates: a truncated
# download or a substituted file does not fail loudly, it produces confident
# and wrong embeddings.  Checking the recorded SHA-256 here is therefore a
# correctness control, not just packaging hygiene.
#
# model.onnx is not kept in git.  fetch-onnx-model verifies a present copy and
# downloads only files that are missing or fail the checksum, so a tree that
# already holds the model never needs the network.
#
# stage-onnx-runtime depends on this target, so under make -j the model is
# never copied before the fetch and checksum check have finished.
.PHONY: verify-onnx-model stage-onnx-runtime

all-local: verify-onnx-model

.PHONY: verify-onnx-model

verify-onnx-model:
	@$(SHELL) "$(srcdir)/fetch-onnx-model" \
	    --dir "$(srcdir)/onnx-models/granite-embedding-30m-english"

install-data-local:
	@$(MKDIR_P) "$(DESTDIR)$(hostingdir)/onnx-models/granite-embedding-30m-english"; \
	  for f in model.onnx vocab.json merges.txt LICENSE README.md SHA256SUMS; do \
	    $(INSTALL_DATA) "$(srcdir)/onnx-models/granite-embedding-30m-english/$$f" "$(DESTDIR)$(hostingdir)/onnx-models/granite-embedding-30m-english/$$f"; \
	  done

uninstall-local:
	@rm -rf "$(DESTDIR)$(hostingdir)/onnx-models/granite-embedding-30m-english"
endif

# ----------------------------------------------------------------------
#
#  Additional files to distribute
#
# ----------------------------------------------------------------------
EXTRA_DIST = \
	vonnx.exp \
	fetch-onnx-model \
	gen_bpe_classes.py \
	onnx-models/granite-embedding-30m-english/LICENSE \
	onnx-models/granite-embedding-30m-english/README.md \
	onnx-models/granite-embedding-30m-english/SHA256SUMS \
	onnx-models/granite-embedding-30m-english/merges.txt \
	onnx-models/granite-embedding-30m-english/vocab.json

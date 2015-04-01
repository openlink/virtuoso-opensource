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

BUILT_SOURCES=wsrm_xsd.sql

SCH_FILES = \
	$(srcdir)/wsrm.xsd \
	$(srcdir)/wsp.xsd \
	$(srcdir)/wsa.xsd \
	$(srcdir)/utility.xsd \
	$(srcdir)/utility200306.xsd \
	$(srcdir)/wss.xsd \
	$(srcdir)/wss0212.xsd \
	$(srcdir)/wsa200403.xsd \
	$(srcdir)/oasis200401wssutility.xsd \
	$(srcdir)/orabpel.xsd \
	$(srcdir)/wsrm_2005_02.xsd \
	$(srcdir)/wsa200408.xsd

GEN=$(SHELL) ${top_srcdir}/bin/generate

wsrm_xsd.sql: $(SCH_FILES) xsd2sql.awk Makefile
	@${GEN} ${GAWK} \
                -o wsrm_xsd.sql \
                -f $(srcdir)/xsd2sql.awk \
                -v prefix=wsrm \
                $(SCH_FILES)

# ----------------------------------------------------------------------
#
#  Additional files to distribute
#
# ----------------------------------------------------------------------
EXTRA_DIST = \
	$(srcdir)/*.sql \
	$(srcdir)/*.xsd \
	$(srcdir)/xsd2sql.awk \
	$(srcdir)/*.xsl

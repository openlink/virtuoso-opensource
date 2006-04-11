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

TARGETS	= wsrm_xsd.sql

SCH_FILES = \
	wsrm.xsd \
	wsp.xsd \
	wsa.xsd \
	utility.xsd \
	utility200306.xsd \
	wss.xsd \
	wss0212.xsd \
	wsa200403.xsd \
	oasis200401wssutility.xsd \
	orabpel.xsd \
	wsrm_2005_02.xsd \
	wsa200408.xsd


.PHONY: all
all: $(TARGETS)

generate: $(TARGETS)


wsrm_xsd.sql: $(SCH_FILES) xsd2sql.awk Makefile
	@echo "Generating wsrm_xsd.sql"
	@-LANG=C gawk -v prefix=wsrm -f xsd2sql.awk $(SCH_FILES) > wsrm_xsd.tmp
	@-[ -s wsrm_xsd.tmp ] && mv wsrm_xsd.tmp wsrm_xsd.sql
	@rm -f wsrm_xsd.tmp
	

# ----------------------------------------------------------------------
#
#  Additional files to distribute
#
# ----------------------------------------------------------------------
EXTRA_DIST = \
	*.sql \
	*.xsd \
	xsd2sql.awk \
	*.xsl

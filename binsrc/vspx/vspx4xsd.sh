#!/bin/sh
#
#  $Id$
#  
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#  
#  Copyright (C) 1998-2016 OpenLink Software
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

# ----------------------------------------------------------------------
#  Fix issues with LOCALE
# ----------------------------------------------------------------------
LANG=C
LC_ALL=POSIX
export LANG LC_ALL

echo '<v:page schemaLocation="http://master.iv.dev.null:8351/vspx/vspx.xsd" name="upd_customer" xmlns:v="http://www.openlinksw.com/vspx/" xmlns:xhtml="http://www.w3.org/1999/xhtml">' > vspx4xsd.xml
cat `cat vspx4xsd.lst` | \
	sed 's/<v:/~v:/g' | \
	sed 's/<!--/~!--/g' | \
	sed 's/="--/="=/g' | \
	sed 's/<?/[?/g' | \
	sed 's/<\/v:/~\/v:/g' | \
	sed 's/<!\[CDATA\[/~!\[CDATA\[/g' | \
	sed 's/<?/~?/g' | \
	sed 's/</\[/g' | \
	sed 's/v:page/v:template/g' | \
	sed 's/~/\</g' | \
	sed 's/xhtml:\([A-Za-z]*\)="\([^"]*\)"//g' >> vspx4xsd.xml
echo '</v:page>' >> vspx4xsd.xml

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

noinst_SCRIPTS = tclrsrv.sh

check:
	./tclrsrv.sh

clean-local:
	rm -rf *.dll
	rm -rf tclrsrv.output
	rm -rf tclr.*
	rm -rf clrsrv.*

# ----------------------------------------------------------------------
#
#  Additional files to distribute
#
# ----------------------------------------------------------------------
EXTRA_DIST = \
	tclrsrv.sh \
	clr_suite_types.sql \
	clr_test2.sql \
	Point.cs \
	Point_ho_s_10.cs \
	sample.cs \
	tax.cs \
	test_point_clr.sql \
	test_tax_clr.sql

/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2016 OpenLink Software
 *
 *  This project is free software; you can redistribute it and/or modify it
 *  under the terms of the GNU General Public License as published by the
 *  Free Software Foundation; only version 2 of the License, dated June 1991.
 *
 *  This program is distributed in the hope that it will be useful, but
 *  WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 *  General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License along
 *  with this program; if not, write to the Free Software Foundation, Inc.,
 *  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
 *
 */

package virtTripleLoaderInit;

import java.sql.SQLException;
import java.util.Date;

public class Logger {
	public String getTS () {
		Date d = new Date ();
		return d.toString ();
	}
	public void error (SQLException e) {
		System.err.print (getTS());
		System.err.printf (": SQL Error: %s, %s, %d\n",
							e.getSQLState(), e.getMessage(), e.getErrorCode());
	}
	public void error (String error_msg) {
		System.err.println (error_msg);
	}
	public void output (String error_msg) {
		System.out.println (error_msg);
	}
}

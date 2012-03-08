/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2012 OpenLink Software
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

/* #English locale & DEFAULT#*/

package virtuoso.javax;

import java.util.*;

public class messages_x extends ListResourceBundle {

  public messages_x() {
  }
  static final Object[][] contents = new String[][]{

//##
//###jdbcx error messages
//##
   { "jdbcx.err.1", "Physical Connection is closed"},
   { "jdbcx.err.2", "Connection is closed"},
   { "jdbcx.err.3", "Unexpected state of cache... cache_unit hasn't found"},
   { "jdbcx.err.4", "Connection failed : loginTimeout has expired"},
   { "jdbcx.err.5", "ConnectionPoolDataSource is closed"},
   { "jdbcx.err.6", "Statement is closed"},
   { "jdbcx.err.7", "ResultSet is closed"},
   { "jdbcx.err.8", "Invalid column count"},
   { "jdbcx.err.9", "Column Index out of range"},
   { "jdbcx.err.10", "Unknown type of parameter"},
   { "jdbcx.err.11", "SQL query is undefined"},
   { "jdbcx.err.12", "Invalid parameter index {0}"},

   { "jdbcx.err.13", "Invalid column name: {0}"},
   { "jdbcx.err.14", " {0} was called when the insert row is off"},
   { "jdbcx.err.15", "Could not convert parameter to {0}"},
   { "jdbcx.err.16", "Names of columns are not found"},
   { "jdbcx.err.17", "Could not set {0} value to field"},

   { "jdbcx.err.18", "Could not call {0} when the cursor on the insert row."},
   { "jdbcx.err.19", "Could not call {0} on a TYPE_FORWARD_ONLY result set."},
   { "jdbcx.err.20", "Could not call {0} on a CONCUR_READ_ONLY result set."},
   { "jdbcx.err.21", "No row is currently available."},
   { "jdbcx.err.22", "Invalid hex number"},

   { "jdbcx.err.23", "The name of table is not defined"},
   { "jdbcx.err.24", "RowSetWriter is not defined"},
   { "jdbcx.err.25", "acceptChanges Failed"},
   { "jdbcx.err.26", "Invalid key columns"},
   { "jdbcx.err.27", "Illegal operation on non-inserted row"},
   { "jdbcx.err.28", "Invalid row number for {0}."},
   { "jdbcx.err.29", "Failed to insert Row"},
   { "jdbcx.err.30", "Invalid cursor position"},
   { "jdbcx.err.31", "Unable to get Connection"},
   { "jdbcx.err.32", "RowSetMetaData is not defined"},
   { "jdbcx.err.33", "{0} can not determine the table name."},
   { "jdbcx.err.34", "{0} can not determine the keyCols."},
   { "jdbcx.err.35", "Method {0} not yet implemented."},
   { "jdbcx.err.36", "Unable to unwrap to: {0}"},


   };


  protected Object[][] getContents() {
    return contents;
  }
}

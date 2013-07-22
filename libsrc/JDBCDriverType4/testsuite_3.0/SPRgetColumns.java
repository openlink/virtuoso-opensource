/*
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2013 OpenLink Software
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

package testsuite;
import java.sql.*;


public class SPRgetColumns
{
  public static void main(String[] args) throws SQLException, ClassNotFoundException
    {
      try
	{
	  String url;
	  System.out.print("bug 1743: metadata calls ");
	  if(args.length == 0)
	    url = "jdbc:virtuoso://localhost:1111";
	  else
	    url = args[0];
	  Class.forName("virtuoso.jdbc3.Driver");
	  Connection conn = DriverManager.getConnection(url, "dba", "dba");
	  DatabaseMetaData dbmd = conn.getMetaData();
	  ResultSet rs = dbmd.getColumns("", "", "", "");

	  // GET ALL RESULTS
	  StringBuffer buf = new StringBuffer();
	  ResultSetMetaData rsmd = rs.getMetaData();
	  int numCols = rsmd.getColumnCount();
	  int i, rowcount = 0;

	  // get column header info
	  for (i=1; i <= numCols; i++) {
	    if (i > 1) buf.append(",");
	    buf.append(rsmd.getColumnLabel(i));
	  }
	  buf.append("\n");

	  // break it off at 100 rows max
	  while (rs.next() && rowcount < 100) {
	    // Loop through each column, getting the column
	    // data and displaying

	    for (i=1; i <= numCols; i++) {
	      if (i > 1) buf.append(",");
	      buf.append(rs.getString(i));
	    }
	    buf.append("\n");
	    rowcount++;
	  }

	  rs.close();
	  conn.close();
	  System.out.println("    PASSED");
	}
      catch (Exception e)
	{
	  System.out.println("    FAILED");
	  e.printStackTrace();
	  System.exit(-1);
	}
    }
}

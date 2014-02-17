/*
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2014 OpenLink Software
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

// test for bug #2308
import java.sql.*;
import java.io.*;
import java.util.Properties;
import java.sql.ResultSetMetaData;

public class TestScrollPrepare {

  public static void main (String[] args)
    {

      try
	{
	  String driver = "virtuoso.jdbc2.Driver";
	  Class.forName( driver );
	  String url;
	  if(args.length == 0)
	    url = "jdbc:virtuoso://localhost:1111";
	  else
	    url = args[0];

	  System.out.println("--------------------- Test of scrollable prepareStatement -------------------");
	  System.out.println ("URL -  " + url);
	  Connection con = DriverManager.getConnection(url, "dba", "dba");
	  System.out.println ("@JBDC connection established through " + driver);

	  System.out.print("Create a preparedStatement scrollable class");
	  // if I use the following prepared statement, the query executes, results
	  // are obtained, but virtuoso crashes when the "stmt.close()" executes.
	  PreparedStatement stmt = con.prepareStatement("select * from sys_users",
	      java.sql.ResultSet.TYPE_SCROLL_INSENSITIVE,
	      java.sql.ResultSet.CONCUR_READ_ONLY);

	  // if I use the following prepared statement, everything works fine
	  //PreparedStatement stmt = con.prepareStatement("select * from s_group");

	  ResultSet resultSet = stmt.executeQuery();

	  ResultSetMetaData rsmd = resultSet.getMetaData();
	  int numCols = rsmd.getColumnCount() ;

	  for (int i = 1 ; i <= numCols ; i++)
	    {
	      String colName = rsmd.getColumnName(i) ;
	      System.out.println(" .. colName = " + colName);
	    }

	  while (resultSet.next())
	    {
	      String primaryKey = resultSet.getString(1);
	      System.out.println ("primary key :"+primaryKey) ;
	    }

	  resultSet.close();
	  System.out.println("@ResultSet closed");
	  stmt.close();
	  System.out.println("@Statement closed");

	  con.close();
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

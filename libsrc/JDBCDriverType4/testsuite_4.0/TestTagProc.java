/*
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2017 OpenLink Software
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

import java.util.*;
import java.io.*;
import java.sql.*;

public class TestTagProc
{

  // ************************************************************
  public static void main(String[] args) throws Exception
  {

     // DriverManager.setLogStream(System.out);
     System.err.println("driver");
     Connection conn = null;
     if (args.length == 0)
     {
        System.err.println("Usage: TestTagProc ora | eds | edsj | ms7");
        System.exit(1);
     }
     System.err.println("connect");
     if (args[0].equals("eds"))
     {
        Class.forName("sun.jdbc.odbc.JdbcOdbcDriver");
        conn = DriverManager.getConnection("jdbc:odbc:Local ES","EWSYS","EWSYS");
     }
     else if (args[0].equals("ora"))
     {
        System.err.println("connect");
        Class.forName("oracle.jdbc.driver.OracleDriver");
//        DriverManager.registerDriver(new oracle.jdbc.driver.OracleDriver());
        conn = DriverManager.getConnection ("jdbc:oracle:thin:@localhost:1521:ent70071","EWSYS","EWSYS");
     }
     else if (args[0].equals("edsj"))
     {
        System.err.println("connect");
        Class.forName("virtuoso.jdbc4.Driver");
        // conn = DriverManager.getConnection ("jdbc:virtuoso://localhost:1111/timeout=60","EWSYS","EWSYS");
        conn = DriverManager.getConnection ("jdbc:virtuoso://localhost:1111/timeout=60","dba","dba");
     }
     else if (args[0].equals("edso"))
     {
        System.err.println("connect");
        Class.forName("openlink.jdbc4.Driver");
        conn = DriverManager.getConnection ("jdbc:openlink://ODBC/DSN=Local ES","dba","dba");
        // jdbc:openlink://ODBC/DSN=<dsn_name>/UID=<uid>/PWD=<pwd>
     }
     else
     {
        Class.forName("sun.jdbc.odbc.JdbcOdbcDriver");
        conn = DriverManager.getConnection("jdbc:odbc:Local ES MS7","EWSYS","EWSYS");
     }
     conn.setAutoCommit(false);
     System.err.println("connected");
     int transactionIsolation = conn.getTransactionIsolation();
     System.err.println("connected: default isolation="+transactionIsolation+":"+Connection.TRANSACTION_NONE);
     // DriverManager.setLogStream(System.out);

     boolean commitData = true;
          if (args.length == 2)
		commitData = args[1].equals("1");

     try
     {

          System.err.println( "DRIVER NAME:" + conn.getMetaData().getDriverName() );
          System.err.println( "DRIVER VER:" + conn.getMetaData().getDriverVersion() );

          PreparedStatement ps = conn.prepareStatement("SELECT name, tag_proc() FROM tag_proc_table");
          ResultSet rs = ps.executeQuery();
          if ( rs == null )
            System.err.println  ( "Result set is null!!!" );

            System.err.println  ( "Result set metadata " );
          ResultSetMetaData metaData = rs.getMetaData();
          for ( int colIndex = 0; colIndex < metaData.getColumnCount(); colIndex++ )
          {
            System.err.println  ( "Result set column metadata " + colIndex);
            System.err.println  ( "Result set column metadata: ...column name = " + metaData.getColumnName(colIndex+1) );
            System.err.println  ( "Result set column metadata: ... display size = " + metaData.getColumnDisplaySize(colIndex+1) );
            System.err.println  ( "Result set column metadata: ... scale = " + metaData.getPrecision(colIndex+1) );
            System.err.println  ( "Result set column metadata: ... precision = " + metaData.getScale(colIndex+1) );
            // these cause a Tag 0 error
            System.err.println  ( "Result set column metadata: ...column type name = " + metaData.getColumnTypeName(colIndex+1) );
            System.err.println  ( "Result set column metadata: ...sqlType = " + metaData.getColumnType(colIndex+1));
/*
	    switch (colIndex)
	      {
		case 0: if (metaData.getColumnType(colIndex+1)) !=
*/

          }

          int ct = 0;
          while ( rs.next() )
          {
            System.err.println("RS1");
            System.err.println ( "" + ct + ",ROW:" + rs.getString(1) + ":" + rs.getString(2));
            ct++;
            /*
            if ( ct  > 3 )
                break;
                */
            System.err.println("RS2");
          }
          System.err.println ( "close result:");
          rs.close();

          System.err.println ( "close prep:");
          ps.close();
          System.err.println ( "commit 3:");
          conn.commit();
          System.err.println ( "commit 4:");

            /*
            ps = conn.prepareStatement("SELECT u_name FROM sys_users");
            System.err.println("select execute");
            ResultSet rs2 = ps.executeQuery();
            while ( rs2.next() )
            {
                System.err.println ( "select results: user=" + rs2.getString(1) );
            }
            rs2.close();
            ps.close();
            */
	  System.out.println ( "PASSED");

     }
     catch ( SQLException e )
     {
        System.err.println ( "SQL EXP:" + e);
        System.err.println ( "SQL EXP(error code):" + e.getErrorCode() );
        System.err.println ( "SQL EXP(sql state):" + e.getSQLState() );
        e.printStackTrace();
     }
     catch ( Exception e )
     {
        System.err.println ( "GEN EXP:" + e);
        e.printStackTrace();
     }
     conn.close();
     System.err.println("done");
  }

}

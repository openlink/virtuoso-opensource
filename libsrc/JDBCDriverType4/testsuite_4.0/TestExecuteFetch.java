/*
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2019 OpenLink Software
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

public class TestExecuteFetch
{
   public static void main(String args[])
   {
      try
      {
         String url;
         if(args.length == 0)
            url = "jdbc:virtuoso://localhost:1111";
         else
            url = args[0];
         Class.forName("virtuoso.jdbc4.Driver");
         System.out.println("--------------------- Test of the fetch execute -------------------");
         System.out.print("Establish connection at " + url);
         Connection connection = DriverManager.getConnection(url,"dba","dba");
         if(connection instanceof virtuoso.jdbc4.VirtuosoConnection)
            System.out.println("    PASSED");
         else
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
         System.out.print("Create a Statement class attached to this connection");
         Statement stmt = connection.createStatement();
         if(stmt instanceof virtuoso.jdbc4.VirtuosoStatement)
            System.out.println("    PASSED");
         else
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
         System.out.print("Set fetch size attached to this statement");
         stmt.setMaxRows(10);
         stmt.setFetchSize(10);
         if(stmt.getMaxRows() == 10 && stmt.getFetchSize() == 10)
            System.out.println("    PASSED");
         else
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
         System.out.println("Execute select * from INFORMATION_SCHEMA.TABLES");
         boolean more = stmt.execute("select * from INFORMATION_SCHEMA.TABLES");
         ResultSetMetaData data = stmt.getResultSet().getMetaData();
         for(int i = 1;i <= data.getColumnCount();i++)
            System.out.println(data.getColumnLabel(i) + "\t" + data.getColumnTypeName(i));
         while(more)
         {
            ResultSet rs = stmt.getResultSet();
            while(rs.next())
               for(int i = 1;i <= data.getColumnCount();i++)
               {
                  if(i == 1 || i == 2)
                  {
                     String s = stmt.getResultSet().getString(i);
                     if(stmt.getResultSet().wasNull())
                        System.out.print("NULL\t");
                     else
                        System.out.print(s + "\t");
                  }
               }
            System.out.println();
            more = stmt.getMoreResults();
         }
         System.out.println("    PASSED");
         System.out.print("Close statement at " + url);
         stmt.close();
         System.out.println("    PASSED");
         System.out.print("Close connection at " + url);
         connection.close();
         System.out.println("    PASSED");
         System.out.println("-------------------------------------------------------------------");
         System.exit(0);
      }
      catch(Exception e)
      {
         System.out.println("    FAILED");
         e.printStackTrace();
         System.exit(-1);
      }
   }

}


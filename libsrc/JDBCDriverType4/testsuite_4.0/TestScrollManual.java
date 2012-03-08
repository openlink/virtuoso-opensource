/*
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

package testsuite;

import java.sql.*;

public class TestScrollManual
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
         System.out.println("--------------------- Test of scrollable cursor in manual commit -------------------");
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
         Statement stmt = connection.createStatement(ResultSet.TYPE_SCROLL_INSENSITIVE,ResultSet.CONCUR_READ_ONLY);
         if(stmt instanceof virtuoso.jdbc4.VirtuosoStatement)
            System.out.println("    PASSED");
         else
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }

	 try {
	   stmt.executeUpdate ("drop table EX..DEMO");
	 } catch (Exception e) { }

         System.out.print("Execute CREATE TABLE");
         if(stmt.executeUpdate("create table EX..DEMO (ID integer,FILLER integer,primary key(ID))") == 0)
            System.out.println("    PASSED");
         else
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
         System.out.print("Create a PStatement class attached to this connection");
         PreparedStatement pstmt = connection.prepareStatement("INSERT INTO EX..DEMO(ID,FILLER) VALUES (?,?)");
         System.out.println("    PASSED");
         System.out.print("Execute INSERT INTO");
         for(int i = 0;i < 100;i++)
         {
            pstmt.setInt(1,i);
            pstmt.setInt(2,i);
            if(pstmt.executeUpdate() != 1)
            {
               System.out.println("    FAILED");
               System.exit(-1);
            }
         }
         System.out.println("    PASSED");
         pstmt.close();
	 connection.setAutoCommit (false);
         System.out.print("Execute SELECT");
         stmt.setMaxRows(100);
         stmt.setFetchSize(10);
         stmt.execute("SELECT * from EX..DEMO");
         System.out.println("    PASSED");
         System.out.print("Get the result set");
         ResultSet rs = stmt.getResultSet();
         if(rs instanceof virtuoso.jdbc4.VirtuosoResultSet)
         {
            System.out.println("    PASSED");
         }
         else
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
         System.out.print("Execute the resultset.beforeFirst()");
         rs.beforeFirst();
         System.out.println("    PASSED");
         System.out.print("Execute the resultset.next()");
         for(int i = 0;i < 100;i++)
         {
            rs.next();
            if(rs.getInt(2) != i)
            {
               System.out.println("    FAILED");
               System.exit(-1);
            }
         }
         System.out.println("    PASSED");
         System.out.print("Execute the resultset.afterLast()");
         rs.afterLast();
         System.out.println("    PASSED");
         System.out.print("Execute the resultset.previous()");
         for(int i = 99;i >= 0;i--)
         {
            rs.previous();
            if(rs.getInt(2) != i)
            {
               System.out.println("    FAILED");
               System.exit(-1);
            }
         }
         System.out.println("    PASSED");
         System.out.print("Execute the resultset.first()");
         rs.first();
         System.out.println("    PASSED");
         System.out.print("Execute the resultset.next()");
         for(int i = 0;i < 100;i++)
         {
            if(rs.getInt(2) != i)
            {
               System.out.println("    FAILED");
               System.exit(-1);
            }
            rs.next();
         }
         System.out.println("    PASSED");
         System.out.print("Execute the resultset.last()");
         rs.last();
         System.out.println("    PASSED");
         System.out.print("Execute the resultset.previous()");
         for(int i = 99;i >= 0;i--)
         {
            if(rs.getInt(2) != i)
            {
               System.out.println("    FAILED");
               System.exit(-1);
            }
            rs.previous();
         }
         System.out.println("    PASSED");
         System.out.print("Execute the resultset.absolute(>0)");
         for(int i = 0;i != 100;i++)
         {
            rs.absolute(i + 1);
            if(rs.getInt(2) != i)
            {
               System.out.println("    FAILED");
               System.exit(-1);
            }
         }
         System.out.println("    PASSED");
         System.out.print("Execute the resultset.absolute(<0)");
         for(int i = -1, j = 99;i != -101;i--, j--)
         {
            rs.absolute(i);
            if(rs.getInt(2) != j)
            {
               System.out.println("    FAILED");
               System.exit(-1);
            }
         }
         System.out.println("    PASSED");
         System.out.print("Execute the resultset.absolute(50)");
         rs.absolute(50);
         System.out.println("    PASSED");
         System.out.print("Execute the resultset.relative(>0)");
         for(int i = 50;i != 90;i++)
         {
            if(rs.getInt(2) != i - 1)
            {
               System.out.println("    FAILED");
               System.exit(-1);
            }
            rs.relative(1);
         }
         System.out.println("    PASSED");
         System.out.print("Execute the resultset.absolute(50)");
         rs.absolute(50);
         System.out.println("    PASSED");
         System.out.print("Execute the resultset.relative(<0)");
         for(int i = 50;i != 10;i--)
         {
            if(rs.getInt(2) != i - 1)
            {
               System.out.println("    FAILED");
               System.exit(-1);
            }
            rs.relative(-1);
         }
         System.out.println("    PASSED");
         System.out.print("Execute the resultset.first()");
         rs.first();
         System.out.println("    PASSED");
         System.out.print("Update rows in the table");
         for(int i = 0;i != 2;i++)
         {
            rs.updateInt("FILLER",i * 2);
            rs.updateRow();
            rs.refreshRow();
            if(rs.getInt(2) != i * 2)
            {
               System.out.println("    FAILED");
               System.exit(-1);
            }
            rs.next();
         }
         System.out.println("    PASSED");
         System.out.print("Execute DELETE");
         pstmt = connection.prepareStatement("DELETE FROM EX..DEMO WHERE ID=?");
         for(int i = 0;i < 100;i++)
         {
            pstmt.setInt(1,i);
            if(pstmt.executeUpdate() != 1)
            {
               System.out.println("    FAILED");
               System.exit(-1);
            }
         }
         System.out.println("    PASSED");
         pstmt.close();
         stmt.close();
         stmt = connection.createStatement(ResultSet.TYPE_SCROLL_INSENSITIVE,ResultSet.CONCUR_READ_ONLY);
         System.out.print("Execute DROP TABLE");
         if(stmt.executeUpdate("DROP TABLE EX..DEMO") == 0)
            System.out.println("    PASSED");
         else
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
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


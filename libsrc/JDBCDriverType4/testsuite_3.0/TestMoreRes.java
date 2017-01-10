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

import java.sql.*;
import virtuoso.jdbc3.*;

public class TestMoreRes
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
         Class.forName("virtuoso.jdbc3.Driver");
         System.out.println("--------------------- Test of scrollable cursor -------------------");
         System.out.print("Establish connection at " + url);
         Connection connection = DriverManager.getConnection(url,"dba","dba");
         if(connection instanceof virtuoso.jdbc3.VirtuosoConnection)
            System.out.println("    PASSED");
         else
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
         System.out.print("Create a Statement class attached to this connection");
         Statement stmt = ((VirtuosoConnection)connection).createStatement(VirtuosoResultSet.TYPE_SCROLL_INSENSITIVE,VirtuosoResultSet.CONCUR_READ_ONLY);
         if(stmt instanceof virtuoso.jdbc3.VirtuosoStatement)
            System.out.println("    PASSED");
         else
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }

         try{
           stmt.executeUpdate("drop procedure ex..pdemo");
         }catch(Exception e) {}

         System.out.print("Execute CREATE PROCEDURE");
         if(stmt.executeUpdate("create procedure ex..pdemo () { result_names('a1'); result(1); end_result(); result_names('b1','b2'); result(2,3); end_result(); }") == 0)
            System.out.println("    PASSED");
         else
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }

         System.out.print("Execute procedure");
         stmt.executeQuery("{call ex..pdemo()}");
         System.out.println("    PASSED");

         System.out.print("Get the result set");
         ResultSet rs = stmt.getResultSet();
         if(rs instanceof virtuoso.jdbc3.VirtuosoResultSet)
         {
            System.out.println("    PASSED");
         }
         else
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
         System.out.println("Get Data");
         System.out.print("Execute the resultset.next()");
           if(rs.next())
           {
             if(rs.getInt(1) != 1)
               {
                 System.out.println("    FAILED");
                 System.exit(-1);
               }
           }else{
               System.out.println("    FAILED");
               System.exit(-1);
           }
         System.out.println("    PASSED");

         System.out.print("Execute the getMoreResults()");
         if (!stmt.getMoreResults())
         {
               System.out.println("    FAILED");
               System.exit(-1);
         }
         System.out.println("    PASSED");

         System.out.print("Get the result set");
         rs = stmt.getResultSet();
         if(rs instanceof virtuoso.jdbc3.VirtuosoResultSet)
         {
            System.out.println("    PASSED");
         }
         else
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
         System.out.print("Get Data");
         System.out.print("Execute the resultset.next()");
           if(rs.next()){
             if(rs.getInt(1) != 2)
               {
                 System.out.println("    FAILED");
                 System.exit(-1);
               }
             if(rs.getInt(2) != 3)
               {
                 System.out.println("    FAILED");
                 System.exit(-1);
               }
           }else{
               System.out.println("    FAILED");
               System.exit(-1);
           }
         System.out.println("    PASSED");
         System.out.print("Execute the getMoreResults()");
         if (!stmt.getMoreResults())
         {
               System.out.println("    FAILED");
               System.exit(-1);
         }
         if (stmt.getMoreResults())
         {
               System.out.println("    FAILED");
               System.exit(-1);
         }
         System.out.println("    PASSED");


         stmt.close();
	 stmt = connection.createStatement();
         System.out.print("Execute DROP PROCEDURE");
         if(stmt.executeUpdate("DROP PROCEDURE ex..pdemo") == 0)
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


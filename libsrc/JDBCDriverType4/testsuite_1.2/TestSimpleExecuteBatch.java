/*
 *  
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *  
 *  Copyright (C) 1998-2006 OpenLink Software
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
 *  
*/
package testsuite;

import java.sql.*;
import virtuoso.jdbc.*;

public class TestSimpleExecuteBatch 
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
         Class.forName("virtuoso.jdbc.Driver");
         System.out.println("------------------------- Test batch update -----------------------");
         System.out.print("Establish connection at " + url);
         Connection connection = DriverManager.getConnection(url,"dba","dba");
         if(connection instanceof virtuoso.jdbc.VirtuosoConnection)
            System.out.println("    PASSED");
         else
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
         System.out.print("Create a Statement class attached to this connection");
         Statement stmt = connection.createStatement();
         if(stmt instanceof virtuoso.jdbc.VirtuosoStatement)
            System.out.println("    PASSED");
         else
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
         System.out.print("Execute CREATE TABLE");
         if(stmt.executeUpdate("create table ex..demo (Id integer,filler integer,primary key(Id))") == 0)
            System.out.println("    PASSED");
         else
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
         System.out.print("Put batch INSERT");
         for(int i = 0;i < 20;i++)
            ((VirtuosoStatement)stmt).addBatch("INSERT INTO ex..demo(Id,filler) VALUES (" + i + ",100)");
         System.out.println("    PASSED");
         System.out.print("Execute batch");
         int[] res = ((VirtuosoStatement)stmt).executeBatch();
         for(int i = 0;i < 20;i++)
            if(res[i] != 1)
            {
               System.out.println(i + " " + res[i]);
               System.out.print("    FAILED");
               System.exit(-1);
            }
         System.out.println("    PASSED");
         System.out.print("Put batch DELETE");
         for(int i = 0;i < 20;i++)
            ((VirtuosoStatement)stmt).addBatch("DELETE FROM ex..demo WHERE Id=" + i);
         System.out.println("    PASSED");
         System.out.print("Execute batch");
         res = ((VirtuosoStatement)stmt).executeBatch();
         for(int i = 0;i < 20;i++)
            if(res[i] != 1)
            {
               System.out.print("    FAILED");
               System.exit(-1);
            }
         System.out.println("    PASSED");
         System.out.print("Execute DROP TABLE");
         if(stmt.executeUpdate("DROP TABLE ex..demo") == 0)
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


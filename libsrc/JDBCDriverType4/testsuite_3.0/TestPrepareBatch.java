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

public class TestPrepareBatch
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
         System.out.println("---------------- Test of batch in PreparedStatement ---------------");
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
         Statement stmt = connection.createStatement();
         if(stmt instanceof virtuoso.jdbc3.VirtuosoStatement)
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
         System.out.print("Put batch INSERT");
         for(int i = 0;i < 100;i++)
         {
            pstmt.setInt(1,i);
            pstmt.setInt(2,i);
            pstmt.addBatch();
            pstmt.clearParameters();
         }
         System.out.println("    PASSED");
         System.out.print("Execute batch");
         int[] res = pstmt.executeBatch();
         pstmt.close();
         for(int i = 0;i < 100;i++)
            if(res[i] != 1)
            {
               System.out.println(i + " " + res[i]);
               System.out.println("    FAILED");
               System.exit(-1);
            }
         System.out.println("    PASSED");
         System.out.println("Execute SELECT");
         pstmt = connection.prepareStatement("SELECT * from EX..DEMO WHERE ID=?");
         for(int i = 0;i < 100;i++)
         {
            pstmt.setInt(1,i);
            ResultSet rs = pstmt.executeQuery();
            while(rs.next())
               for(int j = 1;j <= rs.getMetaData().getColumnCount();j++)
                  System.out.print(rs.getInt(j) + "\t");
            System.out.println();
            pstmt.clearParameters();
         }
         System.out.println("    PASSED");
         pstmt.close();
         System.out.print("Put batch DELETE");
         pstmt = connection.prepareStatement("DELETE FROM EX..DEMO WHERE ID=?");
         for(int i = 0;i < 100;i++)
         {
            pstmt.setInt(1,i);
            pstmt.addBatch();
            pstmt.clearParameters();
         }
         System.out.println("    PASSED");
         System.out.print("Execute batch");
         res = pstmt.executeBatch();
         pstmt.close();
         for(int i = 0;i < 100;i++)
            if(res[i] != 1)
            {
               System.out.print("    FAILED");
               System.exit(-1);
            }
         System.out.println("    PASSED");
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


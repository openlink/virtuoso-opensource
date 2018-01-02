/*
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2018 OpenLink Software
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

public class TestPrepareExecute
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
         System.out.println("--------------------- Test of PreparedStatement -------------------");
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
         }
         System.out.println("    PASSED");
         pstmt.close();
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
         System.out.print("Create a Statement class attached to this connection");
         stmt = connection.createStatement();
         if(stmt instanceof virtuoso.jdbc4.VirtuosoStatement)
            System.out.println("    PASSED");
         else
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
         System.out.print("Execute CREATE TABLE");
         if(stmt.executeUpdate("create table EX..DEMO (ID integer,FILLER varchar(255),ADATE DATETIME)") == 0)
            System.out.println("    PASSED");
         else
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
         System.out.print("Create a PStatement class attached to this connection");
         pstmt = connection.prepareStatement("INSERT INTO EX..DEMO(ID,FILLER,ADATE) VALUES (?,?,?)");
         System.out.print("Execute INSERT INTO");
         pstmt.setNull(1, Types.INTEGER);
         pstmt.setNull(2, Types.VARCHAR);
         pstmt.setNull(3, Types.TIMESTAMP);
         if(pstmt.executeUpdate() != 1)
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
         System.out.println("    PASSED");
         pstmt.close();
         System.out.print("Create a Statement class attached to this connection");
         stmt = connection.createStatement();
         System.out.print("Execute SELECT");
         ResultSet rs = stmt.executeQuery("select * from EX..DEMO");
         while(rs.next())
         {
            if(!(rs.getInt(1)==0 && rs.wasNull()))
			   {
              System.out.println("    FAILED");
              System.exit(-1);
            }
            if(!(rs.getString(2)==null && rs.wasNull()))
				{
              System.out.println("    FAILED");
              System.exit(-1);
				}
            if(!(rs.getTimestamp(3)==null && rs.wasNull()))
				{
              System.out.println("    FAILED");
              System.exit(-1);
				}
			}
         System.out.println("    PASSED");
//         stmt.close();
         System.out.print("Execute DROP TABLE");
         if(stmt.executeUpdate("DROP TABLE EX..DEMO") == 0)
            System.out.println("    PASSED");
         else
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
         System.out.print("Execute CREATE TABLE");
         if(stmt.executeUpdate("create table EX..DEMO (ID integer,FILLER varchar(255))") == 0)
            System.out.println("    PASSED");
         else
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
         System.out.print("Create a PStatement class attached to this connection");
         pstmt = connection.prepareStatement("INSERT INTO EX..DEMO(ID,FILLER) VALUES (?,?)");
         System.out.print("Execute INSERT INTO");
         pstmt.setInt(1, 0);
         pstmt.setString(2, "");
         if(pstmt.executeUpdate() != 1)
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
         System.out.println("    PASSED");
         pstmt.close();
         System.out.print("Create a Statement class attached to this connection");
         stmt = connection.createStatement();
         System.out.print("Execute SELECT");
         rs = stmt.executeQuery("select * from EX..DEMO");
         while(rs.next())
			{
			   if(!(rs.getInt(1)==0 && !rs.wasNull()))
            {
              System.out.println("    FAILED");
              System.exit(-1);
            }
	         if(!(rs.getString(2).equals("") && !rs.wasNull()))
				{
              System.out.println("    FAILED");
              System.exit(-1);
				}
			}
         System.out.println("    PASSED");
//         stmt.close();
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


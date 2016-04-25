/*
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2016 OpenLink Software
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

public class TestExecuteClob
{
   public static void main(String args[])
   {
      try
      {
         String url, filename;
         if(args.length != 2)
         {
            url = "jdbc:virtuoso://localhost:1111";
            filename = "termcap";
         }
         else
         {
            url = args[1];
            filename = args[0];
         }
         Class.forName("virtuoso.jdbc3.Driver");
         System.out.println("--------------------- Test of the clob features (varchar) ------------");
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
	    stmt.executeUpdate ("drop table EX..ECLOB");
         } catch (Exception e) { }

         System.out.print("Execute CREATE TABLE");
         if(stmt.executeUpdate("create table EX..ECLOB (ID integer,FILLER long varchar,primary key(ID))") == 0)
            System.out.println("    PASSED");
         else
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
         System.out.print("Execute INSERT INTO");
         java.io.FileInputStream fs = new java.io.FileInputStream(filename);
         PreparedStatement pstmt = connection.prepareStatement("insert into EX..ECLOB(id,FILLER) values(?,?)");
         pstmt.setLong(1,3000);
         pstmt.setAsciiStream(2,fs,1024 * 20);
         pstmt.execute();
         System.out.println("    PASSED");
         System.out.println("Execute SELECT");
         ResultSet rs = stmt.executeQuery("select * from EX..ECLOB");
         rs.next();
         Clob clob = rs.getClob(2);
         System.out.println(new String(clob.getSubString(4060,1024 * 2)));
         System.out.println("    PASSED");
         System.out.print("Execute DROP TABLE");
         stmt.executeUpdate("drop table EX..ECLOB");
         System.out.println("    PASSED");

         System.out.println("--------------------- Test of the clob features (nvarchar)-----------");
         System.out.print("Execute CREATE TABLE");
         if(stmt.executeUpdate("create table EX..ECLOB (ID integer,FILLER long nvarchar,primary key(ID))") == 0)
            System.out.println("    PASSED");
         else
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
         System.out.print("Execute INSERT INTO");
         fs = new java.io.FileInputStream(filename);
         pstmt = connection.prepareStatement("insert into EX..ECLOB(id,FILLER) values(?,?)");
         pstmt.setLong(1,3000);
         pstmt.setAsciiStream(2,fs,1024 * 20);
         pstmt.execute();
         System.out.println("    PASSED");
         System.out.println("Execute SELECT");
         rs = stmt.executeQuery("select * from EX..ECLOB");
         rs.next();
         clob = rs.getClob(2);
         System.out.println(new String(clob.getSubString(4060,1024 * 2)));
         System.out.println("    PASSED");
         System.out.print("Execute DROP TABLE");
         stmt.executeUpdate("drop table EX..ECLOB");
         System.out.println("    PASSED");
         System.out.print("Close statement at " + url);
         pstmt.close();
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

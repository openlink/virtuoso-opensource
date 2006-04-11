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
import java.io.*;
import virtuoso.jdbc.*;

public class TestExecuteBlob 
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
         Class.forName("virtuoso.jdbc.Driver");
         System.out.println("--------------------- Test of the blob features -------------------");
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
         if(stmt.executeUpdate("create table ex..eblob (Id integer,filler long varbinary,primary key(Id))") == 0)
            System.out.println("    PASSED");
         else
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
         System.out.print("Execute INSERT INTO");
         java.io.FileInputStream fs = new java.io.FileInputStream(filename);
         PreparedStatement pstmt = connection.prepareStatement("insert into ex..eblob(id,filler) values(?,?)");
         pstmt.setLong(1,3000);
         pstmt.setBinaryStream(2,fs,1024 * 20);
         pstmt.execute();
         System.out.println("    PASSED");
         System.out.print("Execute SELECT");
         ResultSet rs = stmt.executeQuery("select * from ex..eblob");
         rs.next();
         VirtuosoBlob blob = ((VirtuosoResultSet)rs).getBlob(2);
         System.out.println(new String(blob.getBytes(4060,1024 * 2)));
         System.out.println("    PASSED");
         System.out.print("Execute DROP TABLE");
         stmt.executeUpdate("drop table ex..eblob");
         System.out.println("    PASSED");
         System.out.print("Close statement at " + url);
         pstmt.close();
         stmt.close();
         System.out.println("    PASSED");
         System.out.print("Create a Statement class attached to this connection");
         stmt = connection.createStatement();
         if(stmt instanceof virtuoso.jdbc.VirtuosoStatement)
            System.out.println("    PASSED");
         else
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
         System.out.print("Execute CREATE TABLE");
         if(stmt.executeUpdate("create table ex..eclob (Id integer,filler long varchar,primary key(Id))") == 0)
            System.out.println("    PASSED");
         else
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
         System.out.print("Execute INSERT INTO");
         String value = "  declare x integer; x := 5; return x;  ";
         pstmt = connection.prepareStatement("insert into ex..eclob(id,filler) values(?,?)");
         pstmt.setLong(1,1);
         pstmt.setAsciiStream(2,new ByteArrayInputStream(value.getBytes()),value.length());
         if(pstmt.executeUpdate()!=1)
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
         System.out.println("    PASSED");
         System.out.print("Execute SELECT");
         rs = stmt.executeQuery("select * from ex..eclob");
         rs.next();
         if(rs.getInt(1) != 1)
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
         InputStream instream = rs.getAsciiStream(2);
         StringBuffer buf = new StringBuffer();
         int ch;
         while((ch = instream.read()) != -1)
            buf.append((char)ch);
         if(!buf.toString().equals(value))
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
         byte []array = rs.getBytes(2);
         if(!(new String(array).equals(value)))
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
         System.out.println("    PASSED");
         System.out.print("Execute DROP TABLE");
         stmt.executeUpdate("drop table ex..eclob");
         System.out.println("    PASSED");
         System.out.print("Close statement at " + url);
         pstmt.close();
         stmt.close();
         System.out.println("    PASSED");
         System.out.print("Create a Statement class attached to this connection");
         stmt = connection.createStatement();
         if(stmt instanceof virtuoso.jdbc.VirtuosoStatement)
            System.out.println("    PASSED");
         else
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
         System.out.print("Execute CREATE TABLE");
         if(stmt.executeUpdate("create table ex..eclob (Id integer,filler long varchar,primary key(Id))") == 0)
            System.out.println("    PASSED");
         else
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
         System.out.print("Execute INSERT INTO");
         value = "  declare x integer; x := 5; return x;  ";
         pstmt = connection.prepareStatement("insert into ex..eclob(id,filler) values(?,?)");
         pstmt.setLong(1,1);
         pstmt.setBytes(2,value.getBytes());
         if(pstmt.executeUpdate()!=1)
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
         System.out.println("    PASSED");
         System.out.print("Execute SELECT");
         rs = stmt.executeQuery("select * from ex..eclob");
         rs.next();
         if(rs.getInt(1) != 1)
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
         array = rs.getBytes(2);
         if(!(new String(array).equals(value)))
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
         System.out.println("    PASSED");
         System.out.print("Execute DROP TABLE");
         stmt.executeUpdate("drop table ex..eclob");
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


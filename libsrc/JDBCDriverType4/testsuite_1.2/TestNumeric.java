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

import virtuoso.jdbc.*;
import java.sql.*;

public class TestNumeric 
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
         System.out.println("-------------------------- Test of Numeric ------------------------");
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
         if(stmt.executeUpdate("create table ex..demo (id integer,val numeric(9,0))") == 0)
            System.out.println("    PASSED");
         else
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
         System.out.print("Execute INSERT INTO");
         if(stmt.executeUpdate("INSERT INTO ex..demo(id,val) VALUES (1,1.0)") == 1)
            System.out.println("    PASSED");
         else
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
         System.out.print("Execute SELECT");
         ResultSet rs = stmt.executeQuery("SELECT * from ex..demo");
	 rs.next();
	 if(rs.getInt(1) == 1 && rs.getFloat(2) == 1.0f)
            System.out.println("    PASSED");
         else
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
         System.out.print("Execute SELECT");
         rs = stmt.executeQuery("SELECT id from ex..demo");
	 rs.next();
	 if(rs.getInt(1) == 1)
            System.out.println("    PASSED");
         else
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
         System.out.print("Execute SELECT");
         rs = stmt.executeQuery("SELECT val from ex..demo");
	 rs.next();
	 if(rs.getFloat(1) == 1.0f)
            System.out.println("    PASSED");
         else
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
         System.out.print("Execute DROP TABLE");
         if(stmt.executeUpdate("DROP TABLE ex..demo") == 0)
            System.out.println("    PASSED");
         else
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
         System.out.print("Execute CREATE TABLE");
         if(stmt.executeUpdate("create table ex..demo (id integer,val numeric(10,0))") == 0)
            System.out.println("    PASSED");
         else
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
         System.out.print("Execute INSERT INTO");
         if(stmt.executeUpdate("INSERT INTO ex..demo(id,val) VALUES (1,1.0)") == 1)
            System.out.println("    PASSED");
         else
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
         System.out.print("Execute SELECT");
         rs = stmt.executeQuery("SELECT * from ex..demo");
	 rs.next();
	 if(rs.getInt(1) == 1 && rs.getFloat(2) == 1.0f)
            System.out.println("    PASSED");
         else
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
         System.out.print("Execute SELECT");
         rs = stmt.executeQuery("SELECT id from ex..demo");
	 rs.next();
	 if(rs.getInt(1) == 1)
            System.out.println("    PASSED");
         else
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
         System.out.print("Execute SELECT");
         rs = stmt.executeQuery("SELECT val from ex..demo");
	 rs.next();
	 if(rs.getFloat(1) == 1.0f)
            System.out.println("    PASSED");
         else
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
         System.out.print("Execute DROP TABLE");
         if(stmt.executeUpdate("DROP TABLE ex..demo") == 0)
            System.out.println("    PASSED");
         else
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
         System.out.print("Execute CREATE TABLE");
         if(stmt.executeUpdate("create table ex..demo (id integer,val numeric(15,3))") == 0)
            System.out.println("    PASSED");
         else
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
         System.out.print("Execute INSERT INTO");
         if(stmt.executeUpdate("INSERT INTO ex..demo(id,val) VALUES (1,1.23)") == 1)
            System.out.println("    PASSED");
         else
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
         System.out.print("Execute SELECT");
         rs = stmt.executeQuery("SELECT * from ex..demo");
	 rs.next();
	 if(rs.getInt(1) == 1 && rs.getFloat(2) == 1.23f)
            System.out.println("    PASSED");
         else
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
         System.out.print("Execute INSERT INTO");
         if(stmt.executeUpdate("INSERT INTO ex..demo(id,val) VALUES (2,0)") == 1)
            System.out.println("    PASSED");
         else
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
         System.out.print("Execute SELECT");
         rs = stmt.executeQuery("SELECT * from ex..demo");
	 rs.next(); rs.next();
	 if(rs.getInt(1) == 2 && rs.getFloat(2) == 0.0f)
            System.out.println("    PASSED");
         else
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
         System.out.print("Execute SELECT");
         rs = stmt.executeQuery("SELECT * from ex..demo where id=1");
	 rs.next();
	 if(rs.getInt(1) == 1 && rs.getString(2).equals("1.23"))
            System.out.println("    PASSED");
         else
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
         System.out.print("Execute DROP TABLE");
         if(stmt.executeUpdate("DROP TABLE ex..demo") == 0)
            System.out.println("    PASSED");
         else
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
         System.out.print("Execute CREATE TABLE");
         if(stmt.executeUpdate("create table ex..demo (id integer,val numeric(15,3))") == 0)
            System.out.println("    PASSED");
         else
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
         System.out.print("Execute INSERT INTO");
         if(stmt.executeUpdate("INSERT INTO ex..demo(id,val) VALUES (1,887)") == 1)
            System.out.println("    PASSED");
         else
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
         System.out.print("Execute SELECT");
         rs = stmt.executeQuery("SELECT * from ex..demo");
	 rs.next();
	 if(rs.getInt(1) == 1 && rs.getFloat(2) == 887f && rs.getString(2).equals("887"))
            System.out.println("    PASSED");
         else
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
         System.out.print("Execute DROP TABLE");
         if(stmt.executeUpdate("DROP TABLE ex..demo") == 0)
            System.out.println("    PASSED");
         else
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
         System.out.print("Execute CREATE TABLE");
         if(stmt.executeUpdate("create table ex..demo (id integer,val numeric(15,3))") == 0)
            System.out.println("    PASSED");
         else
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
         System.out.print("Execute INSERT INTO");
         if(stmt.executeUpdate("INSERT INTO ex..demo(id,val) VALUES (1,893)") == 1)
            System.out.println("    PASSED");
         else
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
         System.out.print("Execute SELECT");
         rs = stmt.executeQuery("SELECT * from ex..demo");
	 rs.next();
	 if(rs.getInt(1) == 1 && rs.getFloat(2) == 893f && rs.getString(2).equals("893"))
            System.out.println("    PASSED");
         else
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
         System.out.print("Execute DROP TABLE");
         if(stmt.executeUpdate("DROP TABLE ex..demo") == 0)
            System.out.println("    PASSED");
         else
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
         System.out.print("Execute CREATE TABLE");
         if(stmt.executeUpdate("create table ex..demo (id integer,val numeric(15,3))") == 0)
            System.out.println("    PASSED");
         else
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
         System.out.print("Execute INSERT INTO");
         if(stmt.executeUpdate("INSERT INTO ex..demo(id,val) VALUES (1,73.872)") == 1)
            System.out.println("    PASSED");
         else
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
         System.out.print("Execute SELECT");
         rs = stmt.executeQuery("SELECT * from ex..demo");
	 rs.next();
	 if(rs.getInt(1) == 1 && rs.getFloat(2) == 73.872f && rs.getString(2).equals("73.872"))
            System.out.println("    PASSED");
         else
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
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


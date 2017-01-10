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

import virtuoso.jdbc2.*;
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
         Class.forName("virtuoso.jdbc2.Driver");
         System.out.println("-------------------------- Test of Numeric ------------------------");
         System.out.print("Establish connection at " + url);
         Connection connection = DriverManager.getConnection(url,"dba","dba");
         if(connection instanceof virtuoso.jdbc2.VirtuosoConnection)
            System.out.println("    PASSED");
         else
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
	 System.out.print("Create a Statement class attached to this connection");
         Statement stmt = connection.createStatement();
         if(stmt instanceof virtuoso.jdbc2.VirtuosoStatement)
            System.out.println("    PASSED");
         else
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }

         try {
	    stmt.executeUpdate ("drop table EX..DEMO");
         } catch (Exception e) { }
         try {
	    stmt.executeUpdate ("drop procedure test_int");
         } catch (Exception e) { }

         System.out.print("Execute CREATE TABLE");
         if(stmt.executeUpdate("create table EX..DEMO (ID integer,VAL numeric(9,0))") == 0)
            System.out.println("    PASSED");
         else
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
         System.out.print("Execute INSERT INTO");
         if(stmt.executeUpdate("INSERT INTO EX..DEMO(ID,VAL) VALUES (1,1.0)") == 1)
            System.out.println("    PASSED");
         else
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
         System.out.print("Execute SELECT");
         ResultSet rs = stmt.executeQuery("SELECT * from EX..DEMO");
	 rs.next();
	 if(rs.getInt(1) == 1 && rs.getFloat(2) == 1.0f)
            System.out.println("    PASSED");
         else
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
         System.out.print("Execute SELECT");
         rs = stmt.executeQuery("SELECT ID from EX..DEMO");
	 rs.next();
	 if(rs.getInt(1) == 1)
            System.out.println("    PASSED");
         else
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
         System.out.print("Execute SELECT");
         rs = stmt.executeQuery("SELECT VAL from EX..DEMO");
	 rs.next();
	 if(rs.getFloat(1) == 1.0f)
            System.out.println("    PASSED");
         else
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
         System.out.print("Execute DROP TABLE");
         if(stmt.executeUpdate("DROP TABLE EX..DEMO") == 0)
            System.out.println("    PASSED");
         else
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
         System.out.print("Execute CREATE TABLE");
         if(stmt.executeUpdate("create table EX..DEMO (ID integer,VAL numeric(10,0))") == 0)
            System.out.println("    PASSED");
         else
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
         System.out.print("Execute INSERT INTO");
         if(stmt.executeUpdate("INSERT INTO EX..DEMO(ID,VAL) VALUES (1,1.0)") == 1)
            System.out.println("    PASSED");
         else
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
         System.out.print("Execute SELECT");
         rs = stmt.executeQuery("SELECT * from EX..DEMO");
	 rs.next();
	 if(rs.getInt(1) == 1 && rs.getFloat(2) == 1.0f)
            System.out.println("    PASSED");
         else
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
         System.out.print("Execute SELECT");
         rs = stmt.executeQuery("SELECT ID from EX..DEMO");
	 rs.next();
	 if(rs.getInt(1) == 1)
            System.out.println("    PASSED");
         else
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
         System.out.print("Execute SELECT");
         rs = stmt.executeQuery("SELECT VAL from EX..DEMO");
	 rs.next();
	 if(rs.getFloat(1) == 1.0f)
            System.out.println("    PASSED");
         else
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
         System.out.print("Execute DROP TABLE");
         if(stmt.executeUpdate("DROP TABLE EX..DEMO") == 0)
            System.out.println("    PASSED");
         else
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
         System.out.print("Execute CREATE TABLE");
         if(stmt.executeUpdate("create table EX..DEMO (ID integer,VAL numeric(15,3))") == 0)
            System.out.println("    PASSED");
         else
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
         System.out.print("Execute INSERT INTO");
         if(stmt.executeUpdate("INSERT INTO EX..DEMO(ID,VAL) VALUES (1,1.23)") == 1)
            System.out.println("    PASSED");
         else
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
         System.out.print("Execute SELECT");
         rs = stmt.executeQuery("SELECT * from EX..DEMO");
	 rs.next();
	 if(rs.getInt(1) == 1 && rs.getFloat(2) == 1.23f)
            System.out.println("    PASSED");
         else
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
         System.out.print("Execute INSERT INTO");
         if(stmt.executeUpdate("INSERT INTO EX..DEMO(ID,VAL) VALUES (2,0)") == 1)
            System.out.println("    PASSED");
         else
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
         System.out.print("Execute SELECT");
         rs = stmt.executeQuery("SELECT * from EX..DEMO");
	 rs.next(); rs.next();
	 if(rs.getInt(1) == 2 && rs.getFloat(2) == 0.0f)
            System.out.println("    PASSED");
         else
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
         System.out.print("Execute SELECT");
         rs = stmt.executeQuery("SELECT * from EX..DEMO where ID=1");
	 rs.next();
	 if(rs.getInt(1) == 1 && rs.getString(2).equals("1.23"))
            System.out.println("    PASSED");
         else
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
         System.out.print("Execute DROP TABLE");
         if(stmt.executeUpdate("DROP TABLE EX..DEMO") == 0)
            System.out.println("    PASSED");
         else
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
         System.out.print("Execute CREATE TABLE");
         if(stmt.executeUpdate("create table EX..DEMO (ID integer,VAL numeric(15,3))") == 0)
            System.out.println("    PASSED");
         else
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
         System.out.print("Execute INSERT INTO");
         if(stmt.executeUpdate("INSERT INTO EX..DEMO(ID,VAL) VALUES (1,887)") == 1)
            System.out.println("    PASSED");
         else
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
         System.out.print("Execute SELECT");
         rs = stmt.executeQuery("SELECT * from EX..DEMO");
	 rs.next();
	 if(rs.getInt(1) == 1 && rs.getFloat(2) == 887f && rs.getString(2).equals("887"))
            System.out.println("    PASSED");
         else
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
         System.out.print("Execute DROP TABLE");
         if(stmt.executeUpdate("DROP TABLE EX..DEMO") == 0)
            System.out.println("    PASSED");
         else
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
         System.out.print("Execute CREATE TABLE");
         if(stmt.executeUpdate("create table EX..DEMO (ID integer,VAL numeric(15,3))") == 0)
            System.out.println("    PASSED");
         else
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
         System.out.print("Execute INSERT INTO");
         if(stmt.executeUpdate("INSERT INTO EX..DEMO(ID,VAL) VALUES (1,893)") == 1)
            System.out.println("    PASSED");
         else
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
         System.out.print("Execute SELECT");
         rs = stmt.executeQuery("SELECT * from EX..DEMO");
	 rs.next();
	 if(rs.getInt(1) == 1 && rs.getFloat(2) == 893f && rs.getString(2).equals("893"))
            System.out.println("    PASSED");
         else
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
         System.out.print("Execute DROP TABLE");
         if(stmt.executeUpdate("DROP TABLE EX..DEMO") == 0)
            System.out.println("    PASSED");
         else
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
         System.out.print("Execute CREATE TABLE");
         if(stmt.executeUpdate("create table EX..DEMO (ID integer,VAL numeric(15,3))") == 0)
            System.out.println("    PASSED");
         else
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
         System.out.print("Execute INSERT INTO");
         if(stmt.executeUpdate("INSERT INTO EX..DEMO(ID,VAL) VALUES (1,73.872)") == 1)
            System.out.println("    PASSED");
         else
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
         System.out.print("Execute SELECT");
         rs = stmt.executeQuery("SELECT * from EX..DEMO");
	 rs.next();
	 if(rs.getInt(1) == 1 && rs.getFloat(2) == 73.872f && rs.getString(2).equals("73.872"))
            System.out.println("    PASSED");
         else
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
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


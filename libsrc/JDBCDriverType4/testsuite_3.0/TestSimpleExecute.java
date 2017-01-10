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

public class TestSimpleExecute
{
   public static void main(String args[])
   {
      try
      {
	Connection connection;
         String url;
         if(args.length == 0)
            url = "jdbc:virtuoso://localhost:1111";
         else
            url = args[0];
         Class.forName("virtuoso.jdbc3.Driver");
         System.out.println("----------------------- Test of basic queries ---------------------");
         System.out.print("Establish connection at " + url + " with UPPER passwd");
         try
	 {
           connection = DriverManager.getConnection(url,"dba","DBA");
           if(connection instanceof virtuoso.jdbc3.VirtuosoConnection)
           {
              System.out.println("    FAILED");
              System.exit(-1);
           }
         }
	 catch(Exception e)
	 {
           System.out.println("    PASSED");
	 }
         System.out.print("Establish connection at " + url);
         connection = DriverManager.getConnection(url,"dba","dba");
         if(connection instanceof virtuoso.jdbc3.VirtuosoConnection)
            System.out.println("    PASSED");
         else
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
         System.out.print("Establish connection at " + url + "/UID=dba/PWD=DBA");
         try
	 {
           connection = DriverManager.getConnection(url+"/UID=dba/PWD=DBA");
           if(connection instanceof virtuoso.jdbc3.VirtuosoConnection)
           {
              System.out.println("    FAILED");
              System.exit(-1);
           }
         }
	 catch(Exception e)
	 {
           System.out.println("    PASSED");
	 }
         System.out.print("Establish connection at " + url);
         connection = DriverManager.getConnection(url,"dba","dba");
         if(connection instanceof virtuoso.jdbc3.VirtuosoConnection)
            System.out.println("    PASSED");
         else
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
	 /*
	 System.out.print("Establish connection at " + url + " with UPPER usrname");
         try
	 {
           connection = DriverManager.getConnection(url,"DBA","dba");
           if(connection instanceof virtuoso.jdbc3.VirtuosoConnection)
           {
	     System.out.println("    PASSED");
           }
         }
	 catch(Exception e)
	 {
              System.out.println("    FAILED");
              System.exit(-1);
	 }
         System.out.print("Establish connection at " + url);
         connection = DriverManager.getConnection(url,"dba","dba");
         if(connection instanceof virtuoso.jdbc3.VirtuosoConnection)
            System.out.println("    PASSED");
         else
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
	 System.out.print("Establish connection at " + url + "/UID=DBA/PWD=dba");
         try
	 {
           connection = DriverManager.getConnection(url+"/UID=DBA/PWD=dba");
           if(connection instanceof virtuoso.jdbc3.VirtuosoConnection)
           {
              System.out.println("    FAILED");
              System.exit(-1);
           }
         }
	 catch(Exception e)
	 {
           System.out.println("    PASSED");
	 }
         System.out.print("Establish connection at " + url);
         connection = DriverManager.getConnection(url,"dba","dba");
         if(connection instanceof virtuoso.jdbc3.VirtuosoConnection)
            System.out.println("    PASSED");
         else
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
	 */
         System.out.print("Establish connection at " + url + " with UPPER usrname+passwd");
         try
	 {
           connection = DriverManager.getConnection(url,"DBA","DBA");
           if(connection instanceof virtuoso.jdbc3.VirtuosoConnection)
           {
              System.out.println("    FAILED");
              System.exit(-1);
           }
         }
	 catch(Exception e)
	 {
           System.out.println("    PASSED");
	 }
         System.out.print("Establish connection at " + url);
         connection = DriverManager.getConnection(url,"dba","dba");
         if(connection instanceof virtuoso.jdbc3.VirtuosoConnection)
            System.out.println("    PASSED");
         else
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
         System.out.print("Establish connection at " + url + "/UID=DBA/PWD=DBA");
         try
	 {
           connection = DriverManager.getConnection(url+"/UID=DBA/PWD=DBA");
           if(connection instanceof virtuoso.jdbc3.VirtuosoConnection)
           {
              System.out.println("    FAILED");
              System.exit(-1);
           }
         }
	 catch(Exception e)
	 {
           System.out.println("    PASSED");
	 }
         System.out.print("Establish connection at " + url);
         connection = DriverManager.getConnection(url,"dba","dba");
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
         System.out.print("Execute INSERT INTO");
         if(stmt.executeUpdate("INSERT INTO EX..DEMO(ID,FILLER) VALUES (100,0)") == 1)
            System.out.println("    PASSED");
         else
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
         System.out.print("Execute SELECT");
         ResultSet rs = stmt.executeQuery("SELECT * from EX..DEMO");
         rs.next();
         System.out.println("    PASSED");
         System.out.print("Execute getInt(1)");
         int id = rs.getInt(1);
         if(id == 100)
            System.out.println("    PASSED");
         else
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
         System.out.print("Execute getInt(\"ID\")");
         id = rs.getInt("ID");
         if(id == 100)
            System.out.println("    PASSED");
         else
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
         System.out.print("Execute UPDATE");
         if(stmt.executeUpdate("UPDATE EX..DEMO SET FILLER=1000 WHERE ID=100") == 1)
            System.out.println("    PASSED");
         else
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
         System.out.print("Execute DELETE");
         if(stmt.executeUpdate("DELETE FROM EX..DEMO WHERE ID=100") == 1)
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
         if(stmt.executeUpdate("create table EX..DEMO (ID integer,FILLER integer,DUMMY integer)") == 0)
            System.out.println("    PASSED");
         else
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
         System.out.print("Execute INSERT INTO");
         if(stmt.executeUpdate("INSERT INTO EX..DEMO(ID,FILLER,DUMMY) VALUES (100,0,0)") == 1)
            System.out.println("    PASSED");
         else
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
         System.out.print("Execute SELECT");
         rs = stmt.executeQuery("SELECT * from EX..DEMO");
         rs.next();
         System.out.println("    PASSED");
         System.out.print("Execute getInt(1)");
         id = rs.getInt(1);
         if(id == 100)
            System.out.println("    PASSED");
         else
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
         System.out.print("Execute getInt(\"ID\")");
         id = rs.getInt("ID");
         if(id == 100)
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
         System.out.print("Check if the connection is closed");
         if(connection.isClosed())
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
         System.out.println("    PASSED");
         System.out.print("Close connection at " + url);
         connection.close();
         System.out.println("    PASSED");
         System.out.print("Check if the connection is closed");
         if(!connection.isClosed())
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
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


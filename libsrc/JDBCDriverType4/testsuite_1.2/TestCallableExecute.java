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

public class TestCallableExecute
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
         System.out.println("--------------------- Test of CallableStatement -------------------");
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
         if(stmt.executeUpdate("CREATE TABLE tpca..branches (Bid integer,Bbalance integer,filler character(92),primary key (Bid))") == 0)
            if(stmt.executeUpdate("CREATE TABLE tpca..tellers (Tid integer,Bid integer,Tbalance integer,filler character(88),primary key (Tid),foreign key (Bid) references tpca..branches)") == 0)
               if(stmt.executeUpdate("CREATE TABLE tpca..accounts (Aid integer,Bid integer,Abalance integer,filler character(88),primary key (Aid),foreign key (Bid) references tpca..branches)") == 0)
                  if(stmt.executeUpdate("CREATE TABLE tpca..history (Tid integer,Bid integer,Aid integer,delta integer,ti timestamp,filler character(24),foreign key (Tid) references tpca..tellers,foreign key (Bid) references tpca..branches,foreign key (Aid) references tpca..accounts)") == 0)
                     System.out.println("    PASSED");
                  else
                  {
                     System.out.println("    FAILED");
                     System.exit(-1);
                  }
               else
               {
                  System.out.println("    FAILED");
                  System.exit(-1);
               }
            else
            {
               System.out.println("    FAILED");
               System.exit(-1);
            }
         else
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
         stmt.execute("create procedure ODBC_BENCHMARK(IN br integer,IN delta integer,OUT Bbalance integer) { declare cr cursor for select Bbalance from tpca..branches where Bid=br; update tpca..branches set Bbalance = Bbalance + delta where Bid = br; open cr; fetch cr into Bbalance;  close cr; }");
         System.out.print("Execute INSERT INTO");
         if(stmt.executeUpdate("INSERT INTO tpca..branches(Bid,Bbalance) VALUES (0,0)") == 1)
            System.out.println("    PASSED");
         else
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
         System.out.print("Create a CallableStatement class attached to this connection");
         CallableStatement stmtc = connection.prepareCall("{fn ODBC_BENCHMARK(?,?,?) }");
         if(stmtc instanceof virtuoso.jdbc.VirtuosoCallableStatement)
            System.out.println("    PASSED");
         else
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
         System.out.print("Execute procedure");
         stmtc.setInt(1,0);
         stmtc.setInt(2,100);
         stmtc.registerOutParameter(3,Types.INTEGER);
         if(stmtc.executeUpdate() == 0)
            if(stmtc.getInt(3) == 100)
               System.out.println("    PASSED");
            else
            {
               System.out.println("    FAILED");
               System.exit(-1);
            }
         else
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
         System.out.print("Execute cleanup");
         stmt.executeUpdate("DELETE FROM sys_procedures");
         if(stmt.executeUpdate("DROP TABLE tpca..history") == 0)
            if(stmt.executeUpdate("DROP TABLE tpca..accounts") == 0)
               if(stmt.executeUpdate("DROP TABLE tpca..tellers") == 0)
                  if(stmt.executeUpdate("DROP TABLE tpca..branches") == 0)
                     System.out.println("    PASSED");
                  else
                  {
                     System.out.println("    FAILED");
                     System.exit(-1);
                  }
               else
               {
                  System.out.println("    FAILED");
                  System.exit(-1);
               }
            else
            {
               System.out.println("    FAILED");
               System.exit(-1);
            }
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


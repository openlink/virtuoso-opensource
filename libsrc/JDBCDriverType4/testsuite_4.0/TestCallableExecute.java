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
         Class.forName("virtuoso.jdbc4.Driver");
         System.out.println("--------------------- Test of CallableStatement -------------------");
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
           stmt.executeUpdate("DROP PROCEDURE VJDBC_BENCHMARK");
         } catch (Exception e) {}
         try {
           stmt.executeUpdate("DROP TABLE ex..history");
         } catch (Exception e) {}
         try {
           stmt.executeUpdate("DROP TABLE ex..accounts");
         } catch (Exception e) {}
         try {
           stmt.executeUpdate("DROP TABLE ex..tellers");
         } catch (Exception e) {}
         try {
           stmt.executeUpdate("DROP TABLE ex..branches");
         } catch (Exception e) {}

         System.out.print("Execute CREATE TABLE");
         if(stmt.executeUpdate("CREATE TABLE ex..branches (Bid integer,Bbalance integer,filler character(92),primary key (Bid))") == 0)
            if(stmt.executeUpdate("CREATE TABLE ex..tellers (Tid integer,Bid integer,Tbalance integer,filler character(88),primary key (Tid),foreign key (Bid) references ex..branches)") == 0)
               if(stmt.executeUpdate("CREATE TABLE ex..accounts (Aid integer,Bid integer,Abalance integer,filler character(88),primary key (Aid),foreign key (Bid) references ex..branches)") == 0)
                  if(stmt.executeUpdate("CREATE TABLE ex..history (Tid integer,Bid integer,Aid integer,delta integer,ti timestamp,filler character(24),foreign key (Tid) references ex..tellers,foreign key (Bid) references ex..branches,foreign key (Aid) references ex..accounts)") == 0)
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
         stmt.execute("create procedure VJDBC_BENCHMARK(IN br integer,IN delta integer,OUT Bbalance integer) { declare cr cursor for select Bbalance from ex..branches where Bid=br; update ex..branches set Bbalance = Bbalance + delta where Bid = br; open cr; fetch cr into Bbalance;  close cr; }");
         System.out.print("Execute INSERT INTO");
         if(stmt.executeUpdate("INSERT INTO ex..branches(Bid,Bbalance) VALUES (0,0)") == 1)
            System.out.println("    PASSED");
         else
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
         System.out.print("Create a CallableStatement class attached to this connection");
         CallableStatement stmtc = connection.prepareCall("{fn VJDBC_BENCHMARK(?,?,?) }");
         if(stmtc instanceof virtuoso.jdbc4.VirtuosoCallableStatement)
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
         stmt.executeUpdate("DROP PROCEDURE VJDBC_BENCHMARK");
         if(stmt.executeUpdate("DROP TABLE ex..history") == 0)
            if(stmt.executeUpdate("DROP TABLE ex..accounts") == 0)
               if(stmt.executeUpdate("DROP TABLE ex..tellers") == 0)
                  if(stmt.executeUpdate("DROP TABLE ex..branches") == 0)
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


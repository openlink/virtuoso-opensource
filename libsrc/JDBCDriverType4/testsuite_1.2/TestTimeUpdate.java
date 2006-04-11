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
// for bug #3037
public class TestTimeUpdate
{
  public static void main (String [] args) throws Exception
    {
      try
	{
         String url;
         if(args.length == 0)
            url = "jdbc:virtuoso://localhost:1111";
         else
            url = args[0];
         Class.forName("virtuoso.jdbc.Driver");
         System.out.println("--------------------- Test of the update col with setTime -------------------");
         System.out.print("Establish connection at " + url);
	 Connection c = DriverManager.getConnection (url, "dba", "dba");
         System.out.println("    PASSED");

         Statement stmt = c.createStatement();

         System.out.print("Execute CREATE TABLE");
         stmt.executeUpdate("create table ex..tstTIME (tstTIME time)");
         System.out.println("    PASSED");


         System.out.print("Execute INSERT INTO");
	 PreparedStatement ps = c.prepareStatement ("insert into ex..tstTIME (tstTIME) values (?)");
	 ps.setTime (1, Time.valueOf("08:48:40"));
	 ps.executeUpdate();
         System.out.println("    PASSED");

         System.out.print("Execute DROP TABLE");
         stmt.executeUpdate("drop table ex..tstTIME");
         System.out.println("    PASSED");

         System.out.println("-------------------------------------------------------------------");
	}
      catch(Exception e)
	{
	  System.out.println("    FAILED");
	  e.printStackTrace();
	  System.exit(-1);
	}
    }
}

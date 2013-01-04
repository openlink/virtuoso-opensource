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

public class TestURL
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
         System.out.println("-------------------------- Test of JDBC URL ------------------------");
         System.out.print("JDBC url : " + url);
         Driver driver = DriverManager.getDriver(url);
         if(driver instanceof virtuoso.jdbc2.Driver)
            System.out.println("    PASSED");
         System.out.print("JDBC url : " + url + "/UID=dba/PWD=dba");
         driver = DriverManager.getDriver(url + "/UID=dba/PWD=dba");
         if(driver instanceof virtuoso.jdbc2.Driver)
            System.out.println("    PASSED");
         System.out.print("JDBC url : " + url + "/UID=dba/PWD=dba/DATABASE=db");
         driver = DriverManager.getDriver(url + "/UID=dba/PWD=dba/DATABASE=db");
         if(driver instanceof virtuoso.jdbc2.Driver)
            System.out.println("    PASSED");
         System.out.print("JDBC url : jdbc:none://localhost:1111");
         try
         {
            driver = DriverManager.getDriver("jdbc:none://localhost:1111");
            if(!(driver instanceof virtuoso.jdbc2.Driver))
               System.out.println("    PASSED");
         }
         catch(SQLException e)
         {
            if(e.toString().equals("java.sql.SQLException: No suitable driver"))
               System.out.println("    PASSED");
            else
            {
               System.out.println("    FAILED");
               e.printStackTrace();
            }
         }
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


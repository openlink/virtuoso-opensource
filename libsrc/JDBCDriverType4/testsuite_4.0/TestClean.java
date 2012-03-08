/*
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2012 OpenLink Software
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

public class TestClean
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
         Connection connection = DriverManager.getConnection(url,"dba","dba");
         Statement stmt = connection.createStatement();
         try
         {
            stmt.executeQuery("drop table EX..DEMO");
         }
         catch(SQLException e)
         {
         }
         try
         {
            stmt.executeQuery("drop table EX..EBLOB");
         }
         catch(SQLException e)
         {
         }
         try
         {
            stmt.executeQuery("drop table EX..ECLOB");
         }
         catch(SQLException e)
         {
         }
         stmt.close();
         connection.close();
         System.exit(0);
      }
      catch(Exception e)
      {
         System.exit(1);
      }
   }

}


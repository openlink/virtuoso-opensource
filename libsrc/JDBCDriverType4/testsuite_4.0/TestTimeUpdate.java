/*
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2014 OpenLink Software
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
         Class.forName("virtuoso.jdbc4.Driver");
         System.out.println("--------------------- Test of the update col with setTime -------------------");
         System.out.print("Establish connection at " + url);
	 Connection c = DriverManager.getConnection (url, "dba", "dba");
         System.out.println("    PASSED");

         Statement stmt = c.createStatement();
	 PreparedStatement ps;
	 ResultSet rs;

	 try {
	   stmt.executeUpdate ("drop table EX..TSTTIME");
	 } catch (Exception e) { }

         System.out.print("Execute CREATE TABLE");
         stmt.executeUpdate("create table EX..TSTTIME (TSTTIME time)");
         System.out.println("    PASSED");


         System.out.print("Execute INSERT INTO");
	 ps = c.prepareStatement ("insert into EX..TSTTIME (TSTTIME) values (?)");
	 ps.setTime (1, Time.valueOf("08:48:40"));
	 ps.executeUpdate();
         System.out.println("    PASSED");

         System.out.print("Execute DROP TABLE");
         stmt.executeUpdate("drop table EX..TSTTIME");
         System.out.println("    PASSED");

         System.out.print("Receiving a date");
	 rs = stmt.executeQuery("select aref (vector ({d '1972-07-29'}), 0)");
	 rs.next();
	 System.out.print(" as " + rs.getObject(1).getClass().getName());
	 if (rs.getObject(1) instanceof java.sql.Date)
	   System.out.println("    PASSED");
	 else
	   System.out.println("    FAILED");
	 rs.close();

         System.out.print("Receiving a time");
	 rs = stmt.executeQuery("select aref (vector ({t '15:30:20'}), 0)");
	 rs.next();
	 System.out.print(" as " + rs.getObject(1).getClass().getName());
	 if (rs.getObject(1) instanceof java.sql.Time)
	   System.out.println("    PASSED");
	 else
	   System.out.println("    FAILED");
	 rs.close();

         System.out.print("Receiving a timestamp");
	 rs = stmt.executeQuery("select aref (vector ({ts '1972-07-29 15:30:20'}), 0)");
	 rs.next();
	 System.out.print(" as " + rs.getObject(1).getClass().getName());
	 if (rs.getObject(1) instanceof java.sql.Timestamp)
	   System.out.println("    PASSED");
	 else
	   System.out.println("    FAILED");
	 rs.close();


         System.out.print("Sending a 1972-07-29 date");
	 ps = c.prepareStatement ("select cast (? as varchar)");
	 ps.setDate (1, new java.sql.Date(72, 6, 29));
	 rs = ps.executeQuery();
	 rs.next();
	 System.out.print(" (recv as " + rs.getString(1) + ")");
	 if (rs.getString(1).equals ("1972-07-29"))
	   System.out.println("    PASSED");
	 else
	   System.out.println("    FAILED");
	 rs.close();

         System.out.print("Sending a 15:30:45 time");
	 ps = c.prepareStatement ("select cast (? as varchar)");
	 ps.setTime (1, new java.sql.Time(15, 30, 45));
	 rs = ps.executeQuery();
	 rs.next();
	 System.out.print(" (recv as " + rs.getString(1) + " trim=[" + rs.getString(1) + "])");
	 if (rs.getString(1).equals ("15:30:45"))
	   System.out.println("    PASSED");
	 else
	   System.out.println("    FAILED");
	 rs.close();

         System.out.print("Sending a 1972-07-29 15:30:45.000012 timestamp");
	 ps = c.prepareStatement ("select cast (? as varchar)");
	 ps.setTimestamp (1, new java.sql.Timestamp(72, 6, 29, 15, 30, 45, 12));
	 rs = ps.executeQuery();
	 rs.next();
	 String q = rs.getString(1);
	 System.out.print(" (recv as " + rs.getString(1) + " trim=[" + rs.getString(1).substring(0, 26) + "])");
	 if (rs.getString(1).substring(0, 26).equals ("1972-07-29 15:30:45.000012"))
	   System.out.println("    PASSED");
	 else
	   System.out.println("    FAILED");
	 rs.close();

         System.out.print("Sending a 1972-07-29 15:30:45.123456 timestamp");
	 ps = c.prepareStatement ("select cast (? as varchar)");
	 ps.setTimestamp (1, new java.sql.Timestamp(72, 6, 29, 15, 30, 45, 123456));
	 rs = ps.executeQuery();
	 rs.next();
	 q = rs.getString(1);
	 System.out.print(" (recv as " + rs.getString(1) + " trim=[" + rs.getString(1).substring(0, 26) + "])");
	 if (rs.getString(1).substring(0, 26).equals ("1972-07-29 15:30:45.123456"))
	   System.out.println("    PASSED");
	 else
	   System.out.println("    FAILED");
	 rs.close();

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

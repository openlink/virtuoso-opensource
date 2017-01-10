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

import java.lang.*;
import java.sql.*;
import java.util.*;

public class test2276
{

  //2276
  public static void test2276(String [] args) throws Exception
    {
      try
	{
	  int x;
	  Connection conn = null;
	  String driver = "virtuoso.jdbc2.Driver";
	  Class.forName(driver);
	  String url;
	  if(args.length == 0)
	    url = "jdbc:virtuoso://localhost:1111";
	  else
	    url = args[0];
	  System.out.println("--------------------- Test of Bug #2276 -------------------");
	  System.out.println ("URL -  " + url);
	  conn = DriverManager.getConnection
	      (url,"dba","dba");
	  System.out.println ("@JBDC connection established through " + driver);
	  Statement stmt = conn.createStatement();
	  ResultSet rs = stmt.executeQuery ("select cast ({ts '2001-07-29 17:30:00'} as date) as xx date");
	  rs.next();
	  System.out.println (rs.getString(1));
	  System.out.println (rs.getDate(1).toString());
	  if (!rs.getString(1).equals (rs.getDate(1).toString()))
	    System.out.print ("*** FAILED");
	  else
	    System.out.print ("PASSED");
	}
      catch (Exception e)
	{
	  e.printStackTrace();
	  System.out.print ("*** FAILED");
	}
      System.out.println (": Bug #2276 - dates with getString()");
    }

  public static void test4033(String [] args) throws Exception
    {
      try
	{
	  int x;
	  // SSL testing
	  Connection conn = null;
	  String driver = "virtuoso.jdbc2.Driver";
	  Class.forName(driver);
	  String url;
	  if(args.length == 0)
	    url = "jdbc:virtuoso://localhost:1111";
	  else
	    url = args[0];
	  System.out.println("--------------------- Test of Bug #4033 -------------------");
	  System.out.println ("URL -  " + url);
	  conn = DriverManager.getConnection
	      (url,"dba","dba");
	  System.out.println ("@JBDC connection established through " + driver);

	  PreparedStatement stmt = null;
	  stmt = conn.prepareStatement ("select ?");

	  java.util.Date date;
	  java.util.Calendar c = java.util.Calendar.getInstance ();
	  c.set (2001, 5, 10, 1, 2, 3);
	  date = c.getTime ();

	  Timestamp ts = new Timestamp (date.getTime ());
	  ts.setNanos (0);
	  stmt.setTimestamp (1, ts);

	  System.out.println ("insert time: " + ts);
	  ResultSet rs = stmt.executeQuery ();

	  rs.next ();
	  Timestamp ts_ret = rs.getTimestamp (1);
	  System.out.println ("fetch date: " + ts_ret);

 	  if (!ts_ret.equals (ts))
	    System.out.print ("*** FAILED");
	  else
	    System.out.print ("PASSED");
	}
      catch (Exception e)
	{
	  e.printStackTrace();
	  System.out.print ("*** FAILED");
	}
      System.out.println (": Bug #4033 - compat for the dt subtypes");
    }

  public static void main(String [] args) throws Exception
    {
      test2276(args);
      test4033(args);
    }
}

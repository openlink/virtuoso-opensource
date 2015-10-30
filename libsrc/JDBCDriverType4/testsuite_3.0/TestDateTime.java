/*
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2015 OpenLink Software
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
import virtuoso.jdbc4.*;

public class TestDateTime
{
  public static final String URL = "jdbc:virtuoso://localhost:1111";

  static int g_PASSED = 0;
  static int g_FAILED = 0;
  static int g_testCounter = 0;

  static int PASSED = 0;
  static int FAILED = 0;
  static int testCounter = 0;

  public static void resetTests()
  {
    PASSED = 0;
    FAILED = 0;
    testCounter = 0;
  }

  public static void startTest(String id)
  {
    testCounter++;
    System.out.println("== TEST " + id + ": " + " : Start");
  }

  public static void endTest(String id, boolean OK)
  {
    System.out.println("== TEST " + id + ": " + " : End");
    System.out.println((OK ? "PASSED:" : "***FAILED:") + " TEST " + id + "\n");
    if (OK) PASSED++;
    else FAILED++;
  }

  public static void getTestTotal()
  {
    System.out.println("============================");
    System.out.println("PASSED:" + PASSED + " FAILED:" + FAILED);
    g_PASSED += PASSED;
    g_FAILED += FAILED;
    g_testCounter += testCounter;
    resetTests();
  }

  public static void getTotal()
  {
    System.out.println("\n=======TOTAL===================");
    System.out.println("PASSED:" + g_PASSED + " FAILED:" + g_FAILED);
    if (g_FAILED > 0)
      System.exit(-1);
  }

  public static void log(String mess)
  {
    System.out.println("   " + mess);
  }

  public static void assertEquals(Object v1, Object v2) throws Exception
  {
    if (!v1.equals(v2))
      throw new Exception("Equals failed: Received=["+v1+"]  Expected=["+v2+"]");
  }

  public static void main(String[] args)
  {
    String url;
    if(args.length == 0)
      url = URL;
    else
      url = args[0];

    Test_SQL(url);
    Test_SPARQL(url);

    getTotal();
  }


  public static void Test_SQL(String url)
  {
    log("\n  TEST SQL");


    Connection c = null;
    Statement stmt;
    PreparedStatement ps;
    ResultSet rs;


    try
    {
      Class.forName("virtuoso.jdbc3.Driver");
      System.out.println("---------------------");
      System.out.print("Establish connection at " + url);
      c = DriverManager.getConnection (url, "dba", "dba");
      System.out.println("    PASSED");

      boolean ok = true;
      String query = null;

      String s_d = "2010-07-29";
      String s_t = "15:30:20";
      String s_dt = "2010-07-29 15:30:20.0";
      String q_create = "create table EX..TSTDT(id integer, f_d date, f_t time, f_dt datetime)";
      String q_drop = "drop table EX..TSTDT";


      startTest("1"); ok = true;
      try
      {
        log("Insert data via subst to query");

        stmt = c.createStatement();

        try {
          stmt.executeUpdate(q_drop);
        } catch(Exception e){}

        stmt.executeUpdate(q_create);

        stmt.executeUpdate("insert into EX..TSTDT values(1, {d '"+s_d+"'}, {t '"+s_t+"'}, {ts '"+s_dt+"'})");

        rs = stmt.executeQuery("select * from EX..TSTDT where id=1");
        rs.next();
        assertEquals(rs.getDate(2).toString(), s_d);
        assertEquals(rs.getTime(3).toString(), s_t);
        assertEquals(rs.getTimestamp(4).toString(), s_dt);
        rs.close();

        stmt.executeUpdate(q_drop);

      } catch (Exception e) {
        log("***FAILED Test " + e);
        ok = false;
      }
      endTest("1", ok);

      startTest("2"); ok = true;
      try
      {
        log("Insert data via parameter binding");
        stmt = c.createStatement();

        try {
          stmt.executeUpdate(q_drop);
        } catch(Exception e){}

        stmt.executeUpdate(q_create);

        ps = c.prepareStatement("insert into EX..TSTDT values(1, ?, ?, ?)");
        ps.setDate(1, Date.valueOf(s_d));
        ps.setTime(2, Time.valueOf(s_t));
        ps.setTimestamp(3, Timestamp.valueOf(s_dt));
        ps.executeUpdate();
        ps.close();

        rs = stmt.executeQuery("select * from EX..TSTDT where id=1");
        rs.next();
        assertEquals(rs.getDate(2).toString(), s_d);
        assertEquals(rs.getTime(3).toString(), s_t);
        assertEquals(rs.getTimestamp(4).toString(), s_dt);
        rs.close();

        stmt.executeUpdate(q_drop);

      } catch (Exception e) {
        log("***FAILED Test " + e);
        ok = false;
      }
      endTest("2", ok);


      getTestTotal();

    }catch (Exception e){
      System.out.println("ERROR Test Failed.");
      e.printStackTrace();
    }
    finally {
      try {
        c.close();
      }
      catch (Exception e) {}
    }
  }

  public static String createRdfType(String val, String v_type)
  {
    return "\""+val+"\"^^<"+v_type+">";
  }

  public static Object execSparqlSelect1(Statement stmt, String q) throws SQLException
  {
    ResultSet rs = stmt.executeQuery(q);
    rs.next();
    Object o = rs.getObject(1);
    rs.close();
    return o;
  }


  public static void Test_SPARQL(String url)
  {
    log("\n  TEST SPARQL");


    Connection c = null;
    Statement stmt;
    PreparedStatement ps;
    ResultSet rs;


    try
    {
      Class.forName("virtuoso.jdbc3.Driver");
      System.out.println("---------------------");
      System.out.print("Establish connection at " + url);
      c = DriverManager.getConnection (url, "dba", "dba");
      System.out.println("    PASSED");

      boolean ok = true;
      String query = null;

      String s_d1  = "1999-05-31";
      String s_d2  = "1938-01-01";
      String s_d3  = "2101-01-01";

      String s_t1  = "13:24:00.000Z";
      String s_t2  = "13:21:00.000+04:30";
      String s_t3  = "13:22:00.000+04:00";
      String s_t4  = "13:23:00.000-05:00";

      String s_dt1 = "1999-05-31T13:25:00-05:00";
      String s_dt2 = "1999-05-31T13:24:00Z";
      String s_dt3 = "1999-05-31T13:25:00.001-05:00";
      String s_dt4 = "1999-05-31T13:24:00.002Z";

      String s_y1 = "2005";

      String t_d  = "http://www.w3.org/2001/XMLSchema#date";
      String t_t  = "http://www.w3.org/2001/XMLSchema#time";
      String t_dt = "http://www.w3.org/2001/XMLSchema#dateTime";
      String t_y = "http://www.w3.org/2001/XMLSchema#gYear";

      startTest("1"); ok = true;
      try
      {
        Object o;

        stmt = c.createStatement();

        stmt.executeUpdate("sparql clear graph <ex_dt>");

        stmt.executeUpdate("sparql insert into graph <ex_dt> {<a> <d1>  "+createRdfType(s_d1, t_d)+" }");
        stmt.executeUpdate("sparql insert into graph <ex_dt> {<a> <d2>  "+createRdfType(s_d2, t_d)+" }");
        stmt.executeUpdate("sparql insert into graph <ex_dt> {<a> <d3>  "+createRdfType(s_d3, t_d)+" }");

        stmt.executeUpdate("sparql insert into graph <ex_dt> {<a> <t1>  "+createRdfType(s_t1, t_t)+" }");
        stmt.executeUpdate("sparql insert into graph <ex_dt> {<a> <t2>  "+createRdfType(s_t1, t_t)+" }");
        stmt.executeUpdate("sparql insert into graph <ex_dt> {<a> <t3>  "+createRdfType(s_t1, t_t)+" }");
        stmt.executeUpdate("sparql insert into graph <ex_dt> {<a> <t4>  "+createRdfType(s_t1, t_t)+" }");

        stmt.executeUpdate("sparql insert into graph <ex_dt> {<a> <dt1> "+createRdfType(s_dt1, t_dt)+" }");
        stmt.executeUpdate("sparql insert into graph <ex_dt> {<a> <dt2> "+createRdfType(s_dt2, t_dt)+" }");

        stmt.executeUpdate("sparql insert into graph <ex_dt> {<a> <y1> "+createRdfType(s_y1, t_y)+" }");

        o = execSparqlSelect1(stmt, "sparql select ?o from <ex_dt> where {<a> <d1> ?o}");
        assertEquals(o.getClass(), VirtuosoDate.class);
        assertEquals(((VirtuosoDate)o).toXSD_String(), s_d1);

        o = execSparqlSelect1(stmt, "sparql select ?o from <ex_dt> where {<a> <d2> ?o}");
        assertEquals(o.getClass(), VirtuosoDate.class);
        assertEquals(((VirtuosoDate)o).toXSD_String(), s_d2);

        o = execSparqlSelect1(stmt, "sparql select ?o from <ex_dt> where {<a> <d3> ?o}");
        assertEquals(o.getClass(), VirtuosoDate.class);
        assertEquals(((VirtuosoDate)o).toXSD_String(), s_d3);

        o = execSparqlSelect1(stmt, "sparql select ?o from <ex_dt> where {<a> <t1> ?o}");
        assertEquals(o.getClass(), VirtuosoTime.class);
        assertEquals(((VirtuosoTime)o).toXSD_String(), s_t1);


        o = execSparqlSelect1(stmt, "sparql select ?o from <ex_dt> where {<a> <dt1> ?o}");
        assertEquals(o.getClass(), VirtuosoTimestamp.class);
        assertEquals(((VirtuosoTimestamp)o).toXSD_String(), s_dt1);

        o = execSparqlSelect1(stmt, "sparql select ?o from <ex_dt> where {<a> <dt2> ?o}");
        assertEquals(o.getClass(), VirtuosoTimestamp.class);
        assertEquals(((VirtuosoTimestamp)o).toXSD_String(), s_dt2);

        o = execSparqlSelect1(stmt, "sparql select ?o from <ex_dt> where {<a> <y1> ?o}");
        assertEquals(o.getClass(), VirtuosoRdfBox.class);
        assertEquals(((VirtuosoRdfBox)o).toString(), s_y1);
        assertEquals(((VirtuosoRdfBox)o).getType(), t_y);

      } catch (Exception e) {
        log("***FAILED Test " + e);
        ok = false;
      }
      endTest("1", ok);



      getTestTotal();

    }catch (Exception e){
      System.out.println("ERROR Test Failed.");
      e.printStackTrace();
    }
    finally {
      try {
        c.close();
      }
      catch (Exception e) {}
    }
  }


}

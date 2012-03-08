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
import org.w3c.dom.*;

public class TestLongXml
{
   static final int ntimes = 1500000;
   public static void main(String args[])
   {
      try
      {
         String url;
         if(args.length == 0)
            url = "jdbc:virtuoso://localhost:1111";
         else
            url = args[0];
         Class.forName("virtuoso.jdbc3.Driver");
         System.out.println("------------------------- Test of LONG XML -----------------------");
         System.out.print("Establish connection at " + url);
         Connection connection = DriverManager.getConnection(url,"dba","dba");
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
	    stmt.executeUpdate ("drop table EX..DEMO_XML");
         } catch (Exception e) { }
         try {
	    stmt.executeUpdate ("drop procedure EX..DEMO_XML_PROC");
         } catch (Exception e) { }

         System.out.print("Execute CREATE TABLE");
         if(stmt.executeUpdate("create table EX..DEMO_XML (VAL int primary key, data varchar)") == 0)
            System.out.println("    PASSED");
         else
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
         System.out.print("Execute CREATE PROC");
         if(stmt.executeUpdate(
		     "create procedure EX..DEMO_XML_PROC (in x integer) {\n" +
		     " declare inx integer; \n" +
		     " delete from EX..DEMO_XML;\n" +
		     " for (inx := 0; inx < x; inx := inx + 1) { \n" +
		     "   insert into EX..DEMO_XML (VAL, data) values (inx + 1, 'bcd'); \n" +
		     " }\n" +
		     "}") == 0)
            System.out.println("    PASSED");
         else
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
         System.out.print("Execute INSERT INTO");
         stmt.executeUpdate("EX..DEMO_XML_PROC (" + ntimes + ")");
	 System.out.println("    PASSED");
	 System.out.print("Execute SELECT");
         ResultSet resultset = stmt.executeQuery(
		 "SELECT \n" +
		 " XMLELEMENT (\"r\", XMLAGG (XMLELEMENT (\"a\", data))) from EX..DEMO_XML\n");
         System.out.println("    PASSED");
         System.out.print("Get metadata of the last result");
	 ResultSetMetaData meta = resultset.getMetaData();
         if(meta instanceof virtuoso.jdbc3.VirtuosoResultSetMetaData)
            System.out.println("    PASSED");
         else
         {
            System.out.println("    FAILED");
            System.exit(-1);
         }
         System.out.print("Get the column type of the meta data");
	 if(meta.getColumnType(1) == -10)
            System.out.println("=-10    PASSED");
         else
         {
            System.out.println("=" + meta.getColumnType(1) + "    FAILED");
            System.exit(-1);
         }

         System.out.print("Check the returned value");
	 resultset.next ();
	 Document doc = (Document) resultset.getObject (1);
	 Element elt = doc.getDocumentElement ();
	 String tagName = elt.getTagName ();
	 int childs = elt.getElementsByTagName ("a").getLength ();
	 if (tagName != "r" || childs != ntimes)
            System.out.println(" tag=["+ tagName + "] childs=" + childs + "    PASSED");
         else
         {
            System.out.println(" tag=["+ tagName + "] childs=" + childs + "    FAILED");
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


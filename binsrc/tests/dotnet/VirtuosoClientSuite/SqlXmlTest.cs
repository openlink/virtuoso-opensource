//
//  $Id$
//
//  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
//  project.
//
//  Copyright (C) 1998-2018 OpenLink Software
//
//  This project is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the
//  Free Software Foundation; only version 2 of the License, dated June 1991.
//
//  This program is distributed in the hope that it will be useful, but
//  WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
//  General Public License for more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
//
//

using System;
using System.Data;
#if ODBC_CLIENT
using OpenLink.Data.VirtuosoOdbcClient;
#elif CLIENT
using OpenLink.Data.VirtuosoClient;
#else
using OpenLink.Data.Virtuoso;
#endif
using OpenLink.Testing.Framework;
using OpenLink.Testing.Util;
using System.Xml;

namespace VirtuosoClientSuite
{
  [TestSuite ("SqlXml Tests")]
  internal class SqlXmlTest : TestCase
    {
      private VirtuosoConnection connection;
      private DataTable checkTable;

      protected override void SetUp ()
	{
	  string host = TestSettings.GetString ("HOST");
	  string connectionString = "HOST=" + host + ";UID=dba;PWD=dba;";
	  connection = new VirtuosoConnection (connectionString);
	  connection.Open ();

	  DropTable ();
	  CreateTable ();
	}

      protected override void TearDown ()
	{
	  DropTable ();

	  connection.Close();
	  connection = null;
	}

      [TestCase ("Select LONG XML as String")]
      public void TestGetString (TestCaseResult result)
	{
	  InsertRowText ();

	  VirtuosoCommand cmd = connection.CreateCommand ();
	  cmd.CommandText = "select data from xmlt";

	  VirtuosoDataReader rdr = cmd.ExecuteReader ();
	  rdr.Read ();
	  String x = rdr.GetString (0);

	  FailIfXmlNotEqual (result, x, TheXml);
	}

      [TestCase ("Select LONG XML in GetValue")]
      public void TestGetValue (TestCaseResult result)
	{
	  InsertRowText ();

	  VirtuosoCommand cmd = connection.CreateCommand ();
	  cmd.CommandText = "select data from xmlt";

	  VirtuosoDataReader rdr = cmd.ExecuteReader ();
	  rdr.Read ();
	  object obj = rdr.GetValue (0);
	  result.FailIfNotEqual (typeof (SqlXml).Name, obj.GetType().Name);
	  SqlXml x = (SqlXml) obj;
	  FailIfXmlNotEqual (result, x.ToString (), TheXml);
	}

      [TestCase ("Select LONG XML in GetSqlXml")]
      public void TestGetSqlXml (TestCaseResult result)
	{
	  InsertRowText ();

	  VirtuosoCommand cmd = connection.CreateCommand ();
	  cmd.CommandText = "select data from xmlt";

	  VirtuosoDataReader rdr = cmd.ExecuteReader ();
	  rdr.Read ();
	  SqlXml x = rdr.GetSqlXml (0);

	  FailIfXmlNotEqual (result, x.ToString (), TheXml);
	}

      [TestCase ("Select LONG XML in GetSqlXml.CreateXmlReader")]
      public void TestGetSqlXmlReader (TestCaseResult result)
	{
	  InsertRowText ();

	  VirtuosoCommand cmd = connection.CreateCommand ();
	  cmd.CommandText = "select data from xmlt";

	  VirtuosoDataReader rdr = cmd.ExecuteReader ();
	  rdr.Read ();
	  SqlXml x = rdr.GetSqlXml (0);

	  XmlDocument doc = new XmlDocument ();
	  doc.Load (x.CreateReader ());

	  FailIfXmlNotEqual (result, doc.OuterXml, TheXml);
	}

      [TestCase ("Insert SqlXml into LONG XML col")]
      public void TestInsertSqlXml (TestCaseResult result)
	{
	  VirtuosoCommand insert = connection.CreateCommand();
	  insert.CommandText = "insert into xmlt (id, data) values (1, ?)";
	  insert.Parameters.Add (new VirtuosoParameter (":0", new SqlXml (TheXml)));
	  insert.ExecuteNonQuery();
	  insert.Dispose();

	  VirtuosoCommand cmd = connection.CreateCommand ();
	  cmd.CommandText = "select data from xmlt";

	  VirtuosoDataReader rdr = cmd.ExecuteReader ();
	  rdr.Read ();
	  SqlXml x = rdr.GetSqlXml (0);

	  FailIfXmlNotEqual (result, x.ToString (), TheXml);
	}

      private void DropTable ()
	{
	  VirtuosoCommand drop = connection.CreateCommand ();
	  drop.CommandText = "drop table xmlt";
	  try
	    {
	      drop.ExecuteNonQuery();
	    }
	  catch (Exception)
	    {
	    }
	  finally
	    {
	      drop.Dispose();
	    }
	}

      private void CreateTable ()
	{
	  VirtuosoCommand create = connection.CreateCommand ();
	  create.CommandText = "create table xmlt (id int primary key, data long xml)";
	  create.ExecuteNonQuery();
	  create.Dispose();
	}

      private static string TheXml =
	  "<?xml version='1.0'?>\n" +
	  "<family>\n" +
	  "  <person>\n" +
	  "    <given-name age='10'>\n" +
	  "      <name>Fred</name>\n" +
	  "      <nick-name>Freddy</nick-name>\n" +
	  "    </given-name>\n" +
	  "    <family-name>Smith</family-name>\n" +
	  "  </person>\n" +
	  "  <person>\n" +
	  "    <given-name age='10'>\n" +
	  "      <name>Robert</name>\n" +
	  "      <nick-name>Bob</nick-name>\n" +
	  "    </given-name>\n" +
	  "    <family-name>Smith</family-name>\n" +
	  "  </person>\n" +
	  "</family>";

      private void InsertRowText ()
	{
	  VirtuosoCommand insert = connection.CreateCommand();
	  insert.CommandText = "insert into xmlt (id, data) values (1, ?)";
	  insert.Parameters.Add (new VirtuosoParameter (":0", TheXml));
	  insert.ExecuteNonQuery();
	  insert.Dispose();
	}

      private void FailIfXmlNotEqual (TestCaseResult result, String ret, String orig)
	{
	  XmlDocument xd_ret = new XmlDocument ();
	  XmlDocument xd_orig = new XmlDocument ();

	  xd_ret.LoadXml (ret);
	  xd_orig.LoadXml (orig);

	  xd_ret.Normalize ();
	  xd_orig.Normalize ();

	  result.FailIfNotEqual (xd_ret.DocumentElement.OuterXml, xd_orig.DocumentElement.OuterXml);
	}
    }
}

//
//  $Id$
//
//  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
//  project.
//
//  Copyright (C) 1998-2012 OpenLink Software
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
using System.Data.SqlClient;
using OpenLink.Testing.Framework;
using OpenLink.Testing.Util;

namespace VirtuosoClientSuite
{
	[TestSuite ("SqlServer Tests")]
	internal class SqlServerTest : TestCase
	{
		static string connectionString = TestSettings.Get ("SSCS"); // SQL Server Connection String

		DataSet dataset;
		SqlConnection connection;
		SqlDataAdapter adapter;
		SqlCommandBuilder builder;

		protected override void SetUp ()
		{
			dataset = new DataSet ();

			connection = new SqlConnection (connectionString);
			connection.Open ();

			DropTable ();
			CreateTable ();
			InsertRow (1);
			InsertRow (2);

			adapter = new SqlDataAdapter ();
			adapter.SelectCommand = new SqlCommand ("select * from foo", connection);
			adapter.Fill (dataset, "table");

			builder = new SqlCommandBuilder ();

			adapter.RowUpdating += new SqlRowUpdatingEventHandler (SqlHandler1);
			builder.DataAdapter = adapter;
			adapter.RowUpdating += new SqlRowUpdatingEventHandler (SqlHandler2);
		}

		protected override void TearDown ()
		{
			if (builder != null)
			{
				builder.Dispose ();
				builder = null;
			}
			if (adapter != null)
			{
				adapter.Dispose ();
				adapter = null;
			}
			if (connection != null)
			{
				connection.Close();
				connection = null;
			}
		}

		private void SqlHandler1 (object sender, SqlRowUpdatingEventArgs e)
		{
			WriteRowUpdating ("Handler 1:", e);
		}

		private void SqlHandler2 (object sender, SqlRowUpdatingEventArgs e)
		{
			WriteRowUpdating ("Handler 2:", e);
		}

		[TestCase ("Get Methods")]
		public void GetMethods (TestCaseResult result)
		{
			WriteCommand ("builder.GetDeleteCommand ():", builder.GetDeleteCommand ());
			WriteCommand ("builder.GetInsertCommand ():", builder.GetInsertCommand ());
			WriteCommand ("builder.GetUpdateCommand ():", builder.GetUpdateCommand ());
		}

		[TestCase ("RowUpdatingHandler")]
		public void RowUpdatingHandler (TestCaseResult result)
		{
			WriteCommand ("SelectCommand", adapter.SelectCommand);

			DataSet dataset = new DataSet ();
			adapter.Fill (dataset, "table");

			DataTable table = dataset.Tables["table"];
			if (table.Rows.Count > 0)
			{
				DataRow row = table.Rows[0];
				row.Delete ();
			}
			if (table.Rows.Count > 1)
			{
				DataRow row = table.Rows[1];
				row["j"] = 555;
				row["s"] = "bbb";
			}
			DataRow newrow = table.NewRow ();
			newrow["i"] = 3;
			newrow["n"] = 333;
			table.Rows.Add (newrow);

			adapter.Update (dataset, "table");
		}

		private void WriteCommand (string title, SqlCommand command)
		{
			Console.WriteLine (title);

			if (command == null)
			{
				Console.WriteLine (command);
				return;
			}

			Console.WriteLine ("CommandText: {0}", command.CommandText);
			Console.WriteLine ("CommandTimeout: {0}", command.CommandTimeout);
			Console.WriteLine ("CommandType: {0}", command.CommandType);
			for (int i = 0; i < command.Parameters.Count; i++)
			{
				Console.WriteLine ("Parameter {0}", i);
				Console.WriteLine ("ParameterName: {0}", command.Parameters[i].ParameterName);
				Console.WriteLine ("Direction: {0}", command.Parameters[i].Direction);
				Console.WriteLine ("SourceColumn: {0}", command.Parameters[i].SourceColumn);
				Console.WriteLine ("SourceVersion: {0}", command.Parameters[i].SourceVersion);
				Console.WriteLine ("Value: {0}", command.Parameters[i].Value);
			}
			Console.WriteLine ("UpdatedRowSource: {0}", command.UpdatedRowSource);
			Console.WriteLine ("");
		}

		private void WriteRowUpdating (string title, SqlRowUpdatingEventArgs e)
		{
			Console.WriteLine (title);

			Console.WriteLine ("Status: {0}", e.Status);
			Console.WriteLine ("StatementType: {0}", e.StatementType);
			WriteCommand ("Command", e.Command);
			Console.WriteLine ("");
		}

		private void ExecuteNonQuery (string text)
		{
			SqlCommand command = connection.CreateCommand ();
			command.CommandText = text;
			try
			{
				command.ExecuteNonQuery ();
			}
			finally
			{
				command.Dispose ();
			}
		}

		private void ExecuteDropCommand (string text)
		{
			SqlCommand command = connection.CreateCommand ();;
			command.CommandText = text;
			try
			{
				command.ExecuteNonQuery();
			}
			catch (Exception)
			{
			}
			finally
			{
				command.Dispose ();
			}
		}

		private void DropTable ()
		{
			ExecuteDropCommand ("drop table foo");
		}

		private void CreateTable ()
		{
			ExecuteNonQuery ("create table foo (i int primary key, j int, k int unique, m int identity, n int not null, s varchar (20), t text, ts timestamp)");
		}

		private void InsertRow (int i)
		{
			string query = String.Format ("insert into foo (i, j, k, n, s, t) values ({0}, {1}, {2}, {3}, {4}, {5})", i, i, i, i, "''", "''");
			ExecuteNonQuery (query);
		}
	}
}

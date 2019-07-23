//
//  $Id$
//
//  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
//  project.
//
//  Copyright (C) 1998-2019 OpenLink Software
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

namespace VirtuosoClientSuite
{
	[TestSuite ("Transaction Tests")]
	internal class TransactionTest : TestCase
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

		private void CheckTransactionCapable (TestCaseResult result)
		{
		        String host = TestSettings.GetString ("HOST");
			if (host != null && host.StartsWith (":in-process:"))
				result.Skip ("Transaction tests are disabled for in-process client.");
		}

		[TestCase ("Commit No Work")]
		public void CommitNoWork (TestCaseResult result)
		{
			CheckTransactionCapable (result);

			CheckTable (result);
			VirtuosoTransaction t = connection.BeginTransaction ();
			result.FailIfNotSame (connection, t.Connection);
			t.Commit ();
			CheckTable (result);
		}

		[TestCase ("Rollback No Work")]
		public void RollbackNoWork (TestCaseResult result)
		{
			CheckTransactionCapable (result);

			CheckTable (result);
			VirtuosoTransaction t = connection.BeginTransaction ();
			result.FailIfNotSame (connection, t.Connection);
			t.Rollback ();
			CheckTable (result);
		}

		[TestCase ("Commit Work")]
		public void Commit (TestCaseResult result)
		{
			CheckTransactionCapable (result);

			CheckTable (result);
			VirtuosoTransaction t = connection.BeginTransaction ();
			InsertRow (3);
			InsertRow (4);
			CheckTable (result);
			t.Commit ();
			CheckTable (result);
		}

		[TestCase ("Rollback Work")]
		public void Rollback (TestCaseResult result)
		{
			CheckTransactionCapable (result);

			CheckTable (result);
			VirtuosoTransaction t = connection.BeginTransaction ();
			InsertRow (3);
			InsertRow (4);
			CheckTable (result);
			t.Rollback ();
			DeleteRow (3);
			DeleteRow (4);
			CheckTable (result);
		}

		private void DropTable ()
		{
			VirtuosoCommand drop = connection.CreateCommand ();
			drop.CommandText = "drop table foo";
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
			create.CommandText = "create table foo (id int primary key, txt varchar(100))";
			create.ExecuteNonQuery();
			create.Dispose();

			checkTable = new DataTable ();
			checkTable.Columns.Add ("id", typeof (int));
			checkTable.Columns.Add ("txt", typeof (string));

			InsertRow (1);
			InsertRow (2);
		}

		private void InsertRow (int i)
		{
			string s = new string (new char[3] { (char) ('a' + i), (char) ('b' + i), (char) ('c' + i) });

			VirtuosoCommand insert = connection.CreateCommand();
			insert.CommandText = "insert into foo values (" + i + ", '" + s + "')";
			insert.ExecuteNonQuery();
			insert.Dispose();

			DataRow row = checkTable.NewRow ();
			row["id"] = i;
			row["txt"] = s;
			checkTable.Rows.Add (row);
		}

		private void DeleteRow (int i)
		{
			foreach (DataRow row in checkTable.Rows)
			{
				if ((int) row["id"] == i)
				{
					checkTable.Rows.Remove (row);
					break;
				}
			}
		}

		private void CheckTable (TestCaseResult result)
		{
			VirtuosoCommand select = connection.CreateCommand ();
			select.CommandText = "select * from foo";

			VirtuosoDataAdapter adapter = new VirtuosoDataAdapter ();
			adapter.SelectCommand = (VirtuosoCommand) select;

			DataSet dataset = new DataSet ();
			adapter.Fill (dataset);

			DataTable table = dataset.Tables["Table"];

			result.FailIfNotEqual (checkTable.Rows.Count, table.Rows.Count);
			result.FailIfNotEqual (checkTable.Columns.Count, table.Columns.Count);
			for (int i = 0; i < table.Rows.Count; i++)
			{
				DataRow row = table.Rows[i];
				DataRow checkRow = checkTable.Rows[i];
				for (int j = 0; j < table.Columns.Count; j++)
				{
					string name = table.Columns[j].ColumnName;
					result.FailIfNotEqual (checkRow[name], row[name]);
				}
			}
		}
	}
}

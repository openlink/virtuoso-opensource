//
//  $Id$
//
//  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
//  project.
//
//  Copyright (C) 1998-2013 OpenLink Software
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
using System.EnterpriseServices;
#if ODBC_CLIENT
using OpenLink.Data.VirtuosoOdbcClient;
#elif CLIENT
using OpenLink.Data.VirtuosoClient;
#else
using OpenLink.Data.Virtuoso;
#endif
using OpenLink.Testing.Framework;
using OpenLink.Testing.Util;

namespace VirtuosoDtcClientSuite
{
	[TransactionAttribute(TransactionOption.Required)]
	public class XAction : ServicedComponent
	{
		public XAction ()
		{
		}

		public Guid GetId ()
		{
			return ContextUtil.TransactionId;
		}

		public VirtuosoConnection Connect (string connectionString)
		{
			VirtuosoConnection connection = new VirtuosoConnection (connectionString);
			connection.Open ();
			return connection;
		}

		public void Enlist (VirtuosoConnection conn)
		{
			conn.EnlistDistributedTransaction ((ITransaction) ContextUtil.Transaction);
		}

		public void UnEnlist (VirtuosoConnection conn)
		{
			conn.EnlistDistributedTransaction (null);
		}

		public void DoWork (VirtuosoConnection conn, Worker worker)
		{
			worker.InsertRow (conn, 3);
			worker.InsertRow (conn, 4);
		}

		public void Commit ()
		{
			ContextUtil.SetComplete ();
		}

		public void Abort ()
		{
			ContextUtil.SetAbort ();
		}
	}

	public class Worker
	{
		private DataTable checkTable;

		public void DropTable (VirtuosoConnection connection)
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

		public void CreateTable (VirtuosoConnection connection)
		{
			VirtuosoCommand create = connection.CreateCommand ();
			create.CommandText = "create table foo (id int primary key, txt varchar(100))";
			create.ExecuteNonQuery();
			create.Dispose();

			checkTable = new DataTable ();
			checkTable.Columns.Add ("id", typeof (int));
			checkTable.Columns.Add ("txt", typeof (string));

			InsertRow (connection, 1);
			InsertRow (connection, 2);
		}

		public void InsertRow (VirtuosoConnection connection, int i)
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

		public void DeleteRow (int i)
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

		public void CheckTable (VirtuosoConnection connection, TestCaseResult result)
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

	[TestSuite ("Distributed Transaction Tests")]
	internal class DtcTest : TestCase
	{
		private VirtuosoConnection connection;
		private Worker worker;

		protected override void SetUp ()
		{
			string host = TestSettings.GetString ("HOST", "localhost");
			string connectionString = "HOST=" + host + ";UID=dba;PWD=dba;";
			connection = new VirtuosoConnection (connectionString);
			connection.Open ();

			worker = new Worker ();
			worker.DropTable (connection);
			worker.CreateTable (connection);
		}

		protected override void TearDown ()
		{
			worker.DropTable (connection);

			connection.Close();
			connection = null;
		}

		private void CheckDtcEnabled (TestCaseResult result)
		{
			if (!TestSettings.GetBoolean ("DTC_TEST", false))
				result.Skip ("DTC_TEST is not set -- DTC tests are not enabled.");
		}

		[TestCase ("Manual Transaction Enlistment")]
		public void Enlist (TestCaseResult result)
		{
			CheckDtcEnabled (result);

			XAction x = new XAction ();
			x.Enlist (connection);
			x.UnEnlist (connection);
		}

		[TestCase ("Automatic Transaction Enlistment -- Commit Work")]
		public void Commit (TestCaseResult result)
		{
			CheckDtcEnabled (result);

			worker.CheckTable (connection, result);
			XAction x = new XAction ();
			VirtuosoConnection xconn = null;
			try
			{
				string host = TestSettings.GetString ("HOST", "localhost");
				string connectionString = "HOST=" + host + ";UID=dba;PWD=dba;Pooling=True;";
				xconn = x.Connect (connectionString);

				x.DoWork (xconn, worker);
				worker.CheckTable (xconn, result);
				x.Commit ();
				worker.CheckTable (connection, result);
			}
			finally
			{
				if (xconn != null)
					xconn.Close ();
			}
		}

		[TestCase ("Automatic Transaction Enlistment -- Rollback Work")]
		public void Rollback (TestCaseResult result)
		{
			CheckDtcEnabled (result);

			worker.CheckTable (connection, result);
			XAction x = new XAction ();
			VirtuosoConnection xconn = null;
			try
			{
				string host = TestSettings.GetString ("HOST", "localhost");
				string connectionString = "HOST=" + host + ";UID=dba;PWD=dba;Pooling=True;";
				xconn = x.Connect (connectionString);

				x.DoWork (xconn, worker);
				worker.CheckTable (xconn, result);
				x.Abort ();
				worker.DeleteRow (3);
				worker.DeleteRow (4);
				worker.CheckTable (connection, result);
			}
			finally
			{
				if (xconn != null)
					xconn.Close ();
			}
		}
	}
}

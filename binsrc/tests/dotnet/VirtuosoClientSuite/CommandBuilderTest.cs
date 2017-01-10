//
//  $Id$
//
//  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
//  project.
//
//  Copyright (C) 1998-2017 OpenLink Software
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
	[TestSuite ("CommandBuilder Tests")]
	internal class CommandBuilderTest : TestCase
	{
		private VirtuosoConnection connection;

		protected override void SetUp ()
		{
			string host = TestSettings.GetString ("HOST");
			string connectionString = "HOST=" + host + ";UID=dba;PWD=dba;";
			connection = new VirtuosoConnection (connectionString);
			connection.Open ();
		}

		protected override void TearDown ()
		{
			connection.Close();
			connection = null;
		}

		private void CheckParameter (
			TestCaseResult result,
			VirtuosoParameter parameter,
			string parameterName,
			ParameterDirection direction,
			VirtDbType vdbType,
			DbType dbType,
			int size,
			byte precision,
			byte scale)
		{
			result.FailIfNotEqual (this, "ParameterName", parameterName, parameter.ParameterName);
			result.FailIfNotEqual (this, parameterName + ".Direction", direction, parameter.Direction);
			result.FailIfNotEqual (this, parameterName + ".VirtDbType", vdbType, parameter.VirtDbType);
			result.FailIfNotEqual (this, parameterName + ".DbType", dbType, parameter.DbType);
			result.FailIfNotEqual (this, parameterName + ".Size", size, parameter.Size);
			result.FailIfNotEqual (this, parameterName + ".Precision", precision, parameter.Precision);
			result.FailIfNotEqual (this, parameterName + ".Scale", scale, parameter.Scale);
		}

		[TestCase ("Derive Parameters")]
		public void DeriveParamters (TestCaseResult result)
		{
			DropProcedure ();
			ExecuteNonQuery (
				"create function BAR (in X integer, out Y integer, inout Z integer, in V varchar(20), in W nvarchar(20), in D numeric(20, 5)) returns real\n" +
				"{\n" +
				"  return 0.0;\n" +
				"}\n"
				);

			VirtuosoCommand command = connection.CreateCommand ();
			command.CommandType = CommandType.StoredProcedure;
			command.CommandText = "BAR";

			try
			{
				VirtuosoCommandBuilder.DeriveParameters (command);
				result.FailIfNotEqual ("Parameter Count", 7, command.Parameters.Count);
				CheckParameter (result,	command.Parameters[0],
					"ReturnValue", ParameterDirection.ReturnValue, VirtDbType.Real, DbType.Single,
					4, 0, 0); // FIXME: The precision should be 7.
				CheckParameter (result,	command.Parameters[1],
					"X", ParameterDirection.Input, VirtDbType.Integer, DbType.Int32,
					4, 10, 0);
				CheckParameter (result,	command.Parameters[2],
					"Y", ParameterDirection.Output, VirtDbType.Integer, DbType.Int32,
					4, 10, 0);
				CheckParameter (result, command.Parameters[3],
					"Z", ParameterDirection.InputOutput, VirtDbType.Integer, DbType.Int32,
					4, 10, 0);
				CheckParameter (result, command.Parameters[4],
					"V", ParameterDirection.Input, VirtDbType.VarChar, DbType.AnsiString,
					20, 0, 0);
				CheckParameter (result, command.Parameters[5],
					"W", ParameterDirection.Input, VirtDbType.NVarChar, DbType.String,
					20, 0, 0);
				CheckParameter (result, command.Parameters[6],
					"D", ParameterDirection.Input, VirtDbType.Decimal, DbType.Decimal,
					19, 20, 5);
			}
			finally
			{
				command.Dispose ();
			}
		}

		[TestCase ("Get Methods")]
		public void GetMethods (TestCaseResult result)
		{
			DropTable ();
			CreateTable ();

			DataSet dataset = new DataSet ();
			VirtuosoDataAdapter adapter = null;
			VirtuosoCommandBuilder builder = null;
			try
			{
				adapter = new VirtuosoDataAdapter ();
				adapter.SelectCommand = new VirtuosoCommand ("select * from foo", connection);
				adapter.Fill (dataset, "table");

				builder = new VirtuosoCommandBuilder ();
				builder.DataAdapter = adapter;

				VirtuosoCommand delete = builder.GetDeleteCommand ();
				VirtuosoCommand insert = builder.GetInsertCommand ();
				VirtuosoCommand update = builder.GetUpdateCommand ();

				// dummy thing to evade the delete,insert,update not used warnings
				if (delete != null || insert != null || update != null)
				  adapter = null;
			}
			finally
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
			}
		}

		[TestCase ("Table Update")]
		public void TableUpdate (TestCaseResult result)
		{
			DropTable ();
			CreateTable ();
			InsertRow (1);
			InsertRow (2);

			DataSet dataset = new DataSet ();
			VirtuosoDataAdapter adapter = null;
			VirtuosoCommandBuilder builder = null;
			try
			{
				adapter = new VirtuosoDataAdapter ();
				adapter.SelectCommand = new VirtuosoCommand ("select * from foo", connection);
				adapter.Fill (dataset, "table");

				builder = new VirtuosoCommandBuilder ();
				builder.DataAdapter = adapter;

				DataTable table = dataset.Tables["table"];
				if (table.Rows.Count > 0)
				{
					DataRow row = table.Rows[0];
					row.Delete ();
				}
				//if (table.Rows.Count > 1)
				//{
				//	DataRow row = table.Rows[1];
				//	row["j"] = 555;
				//	row["s"] = "bbb";
				//}
				DataRow newrow = table.NewRow ();
				newrow["i"] = 3;
				newrow["n"] = 333;
				table.Rows.Add (newrow);

				adapter.Update (dataset, "Table");
			}
			finally
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
			}
		}

		private void ExecuteNonQuery (string text)
		{
			VirtuosoCommand command = connection.CreateCommand ();
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
			VirtuosoCommand command = connection.CreateCommand ();;
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

		private void DropProcedure ()
		{
			ExecuteDropCommand ("drop procedure bar");
		}

		private void CreateTable ()
		{
			ExecuteNonQuery ("create table foo (i int primary key, j int, k int unique,"
				+ " m int identity, n int not null, s varchar (20), t long varchar, ts timestamp)");
		}

		private void InsertRow (int i)
		{
			string query = String.Format ("insert into foo (i, j, k, n, s, t) values ({0}, {1}, {2}, {3}, {4}, {5})",
				i, i, i, i, "''", "''");
			ExecuteNonQuery (query);
		}
	}
}

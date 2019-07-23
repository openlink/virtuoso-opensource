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
using System.Diagnostics;
using System.Threading;
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
	[TestSuite ("Command Tests")]
	internal class CommandTest : TestCase
	{
		private VirtuosoConnection connection;
		private DataTable checkTable;

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

		[TestCase ("Dispose New Command")]
		public void DisposeNewCommand (TestCaseResult result)
		{
			VirtuosoCommand command = connection.CreateCommand ();
			command.Dispose ();
		}

		[TestCase ("Insert With Parameters")]
		public void CheckInsert (TestCaseResult result)
		{
			DropTable ();
			CreateTable ();
			InsertRow (0);
			InsertRow (1);
			InsertRow (2);
			CheckTable (result);
		}

		/*
		class CommandKiller
		{
			private VirtuosoCommand command;

			internal CommandKiller (VirtuosoCommand command)
			{
				this.command = command;
			}

			internal void Kill ()
			{
				Thread.Sleep (2000);
				Console.WriteLine ("Cancel enter");
				command.Cancel ();
				Console.WriteLine ("Cancel exited");
			}
		};

		[TestCase ("Cancel Method")]
		public void CheckCancelMethod (TestCaseResult result)
		{
			VirtuosoCommand command = connection.CreateCommand ();
			command.CommandText = "delay";
			command.CommandType = CommandType.StoredProcedure;
			VirtuosoParameter parameter = command.CreateParameter ();
			parameter.ParameterName = "seconds";
			parameter.VirtDbType = VirtDbType.Int;
			parameter.Value = 10;
			command.Parameters.Add (parameter);

			CommandKiller killer = new CommandKiller (command);
			Thread thread = new Thread (new ThreadStart (killer.Kill));
			thread.Start ();

			try
			{
				Console.WriteLine ("ExecuteNonQuery enter");
				command.ExecuteNonQuery ();
				Console.WriteLine ("ExecuteNonQuery exited");
			}
			finally
			{
				thread.Join ();
				command.Dispose ();
			}
		}
		*/

		[TestCase ("Procedure With Output Parameters")]
		public void OutputParameters (TestCaseResult result)
		{
			DropProcedure ();
			ExecuteNonQuery (
				"create procedure bar (in x integer, out y integer, inout z integer)\n" +
				"{\n" +
				"  y := x * 2;\n" +
				"  z := z * 2;\n" +
				"  return y + z;\n" +
				"}\n"
				);

			VirtuosoCommand command = connection.CreateCommand ();
			command.CommandType = CommandType.StoredProcedure;
			command.CommandText = "bar";

			VirtuosoParameter returnValue = command.CreateParameter ();
			returnValue.ParameterName = "ReturnValue";
			returnValue.Direction = ParameterDirection.ReturnValue;
			returnValue.VirtDbType = VirtDbType.Integer;
			command.Parameters.Add (returnValue);

			VirtuosoParameter x = command.CreateParameter ();
			x.ParameterName = "x";
			x.Direction = ParameterDirection.Input;
			x.VirtDbType = VirtDbType.Integer;
			x.Value = 2;
			command.Parameters.Add (x);

			VirtuosoParameter y = command.CreateParameter ();
			y.ParameterName = "y";
			y.Direction = ParameterDirection.Output;
			y.VirtDbType = VirtDbType.Integer;
			command.Parameters.Add (y);

			VirtuosoParameter z = command.CreateParameter ();
			z.ParameterName = "z";
			z.Direction = ParameterDirection.InputOutput;
			z.VirtDbType = VirtDbType.Integer;
			z.Value = 3;
			command.Parameters.Add (z);

			try
			{
				command.ExecuteNonQuery ();
				result.FailIfNotEqual (this, "Return Value", 10, returnValue.Value);
				result.FailIfNotEqual (this, "Out Parameter", 4, y.Value);
				result.FailIfNotEqual (this, "InOut Parameter", 6, z.Value);
			}
			finally
			{
				command.Dispose ();
			}
		}

		[TestCase ("Procedure Generating Multiple Result Sets")]
		public void MultipleResultSets (TestCaseResult result)
		{
			DropProcedure ();
			ExecuteNonQuery (
				"create procedure bar ()\n" +
				"{\n" +
				"  declare i int;\n" +
				"  declare c char;\n" +
				"  result_names (i);\n" +
				"  result (1);\n" +
				"  result (2);\n" +
				"  end_result ();\n" +
				"  result_names (c);\n" +
				"  result ('a');\n" +
				"  result ('b');\n" +
				"  return 0;\n" +
				"}\n"
				);

			VirtuosoCommand command = connection.CreateCommand ();
			command.CommandType = CommandType.StoredProcedure;
			command.CommandText = "bar";

			VirtuosoDataReader reader = null;
			try
			{
				reader = command.ExecuteReader ();
				result.FailIfNotEqual (1, reader.FieldCount);
				result.FailIfNotEqual ("i", reader.GetName (0).ToLower ());
				result.FailIfNotEqual (typeof (int), reader.GetFieldType (0));
				result.FailIfNotEqual (true, reader.Read ());
				result.FailIfNotEqual (1, reader["i"]);
				result.FailIfNotEqual (true, reader.Read ());
				result.FailIfNotEqual (2, reader["i"]);
				result.FailIfNotEqual (false, reader.Read ());
				result.FailIfNotEqual (true, reader.NextResult ());
				result.FailIfNotEqual (1, reader.FieldCount);
				result.FailIfNotEqual ("c", reader.GetName (0).ToLower ());
				result.FailIfNotEqual (typeof (string), reader.GetFieldType (0));
				result.FailIfNotEqual (true, reader.Read ());
				result.FailIfNotEqual ("a", reader["c"]);
				result.FailIfNotEqual (true, reader.Read ());
				result.FailIfNotEqual ("b", reader["c"]);
				result.FailIfNotEqual (false, reader.NextResult ());
			}
			finally
			{
				if (reader != null)
					reader.Close ();
				command.Dispose ();
			}
		}

		[TestCase ("Procedure With Output Parameters Generating a Result Set")]
		public void ResultSetAndOutputParameters (TestCaseResult result)
		{
			DropProcedure ();
			DropProcedure ();
			ExecuteNonQuery (
				"create procedure bar (out x integer)\n" +
				"{\n" +
				"  declare i int;\n" +
				"  result_names (i);\n" +
				"  result (1);\n" +
				"  result (2);\n" +
				"  x := 3;\n" +
				"  return 4;\n" +
				"}\n"
				);

			VirtuosoCommand command = connection.CreateCommand ();
			command.CommandType = CommandType.StoredProcedure;
			command.CommandText = "bar";

			VirtuosoParameter returnValue = command.CreateParameter ();
			returnValue.ParameterName = "ReturnValue";
			returnValue.Direction = ParameterDirection.ReturnValue;
			returnValue.VirtDbType = VirtDbType.Integer;
			command.Parameters.Add (returnValue);

			VirtuosoParameter x = command.CreateParameter ();
			x.ParameterName = "x";
			x.Direction = ParameterDirection.Output;
			x.VirtDbType = VirtDbType.Integer;
			command.Parameters.Add (x);

			VirtuosoDataReader reader = null;
			bool closed = false;
			try
			{
				reader = command.ExecuteReader ();
				result.FailIfNotEqual (1, reader.FieldCount);
				result.FailIfNotEqual ("i", reader.GetName (0).ToLower ());
				result.FailIfNotEqual (typeof (int), reader.GetFieldType (0));
				result.FailIfNotEqual (true, reader.Read ());
				result.FailIfNotEqual (1, reader["i"]);
				result.FailIfNotEqual (true, reader.Read ());
				result.FailIfNotEqual (2, reader["i"]);
				result.FailIfNotEqual (false, reader.Read ());

				reader.Close ();
				closed = true;

				result.FailIfNotEqual ("Out Parameter", 3, x.Value);
				result.FailIfNotEqual ("Return Value", 4, returnValue.Value);
			}
			finally
			{
				if (reader != null && !closed)
					reader.Close ();
				command.Dispose ();
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
			ExecuteNonQuery (
				"create table foo (\n"
				+ "id int primary key,\n"
				+ "i int,\n"
				+ "si smallint,\n"
				+ "d double precision,\n"
				+ "r real,\n"
				+ "n numeric,\n"
				+ "dt date,\n"
				+ "tm time,\n"
				+ "dtm datetime,\n"
				+ "c char (128),\n"
				+ "vc varchar (128),\n"
				+ "lvc long varchar,\n"
				+ "nc nchar(128),\n"
				+ "nvc nvarchar(128),\n"
				+ "lnvc long nvarchar,\n"
				+ "b binary (128),\n"
				+ "vb varbinary (128),\n"
				+ "lvb long varbinary)\n"
				);

			checkTable = new DataTable ();
			checkTable.Columns.Add ("id", typeof (int));
			checkTable.Columns.Add ("i", typeof (int));
			checkTable.Columns.Add ("si", typeof (short));
			checkTable.Columns.Add ("d", typeof (double));
			checkTable.Columns.Add ("r", typeof (float));
			checkTable.Columns.Add ("n", typeof (decimal));
			checkTable.Columns.Add ("dt", typeof (DateTime));
			checkTable.Columns.Add ("tm", typeof (TimeSpan));
			checkTable.Columns.Add ("dtm", typeof (DateTime));
			checkTable.Columns.Add ("c", typeof (string));
			checkTable.Columns.Add ("vc", typeof (string));
			checkTable.Columns.Add ("lvc", typeof (string));
			checkTable.Columns.Add ("nc", typeof (string));
			checkTable.Columns.Add ("nvc", typeof (string));
			checkTable.Columns.Add ("lnvc", typeof (string));
			checkTable.Columns.Add ("b", typeof (byte[]));
			checkTable.Columns.Add ("vb", typeof (byte[]));
			checkTable.Columns.Add ("lvb", typeof (byte[]));
		}

		private void InsertRow (int id)
		{
			object i, si, d, r, n, year, month, day, dt, tm, dtm, str, bin;

			if (id == 0)
			{
				i = si = d = r = n = year = month = day = dt = tm = dtm = str = bin = DBNull.Value;
			}
			else
			{
				i = id + 1000;
				si = (short) (id + 2000);
				d = id * 1000.0001;
				r = (float) (id * 100.001);
				n = (decimal) id * 10000001;
				year = 1990 + id;
				month = (id - 1) % 12 + 1;
				day = (id - 1) % DateTime.DaysInMonth ((int) year, (int) month) + 1;
				dt = new DateTime ((int) year, (int) month, (int) day);
				tm = new TimeSpan (id % 24, id % 60, id % 60);
				dtm = new DateTime ((int) year, (int) month, (int) day, id % 24, id % 60, id % 60);

				int length = id % 128;
				char[] chars = new char[length];
				byte[] bytes = new byte[length];
				for (int count = 0; count < length; count++)
				{
					chars[count] = (char) ('a' + (id + count) % 26 - 1);
					bytes[count] = (byte) (id + count);
				}
				str = new String (chars);
				bin = bytes;
			}

			VirtuosoCommand insert = connection.CreateCommand();
			insert.CommandText =
				"insert into foo "
				+ "(id, i, si, d, r, n, dt, tm, dtm, c, vc, lvc, nc, nvc, lnvc, b, vb, lvb) "
				+ "values "
				+ "(?,  ?,  ?, ?, ?, ?,  ?,  ?,   ?, ?,  ?,   ?,  ?,   ?,    ?, ?,  ?,   ?)";

			VirtuosoParameterCollection parameters = insert.Parameters;

			VirtuosoParameter idParam = insert.CreateParameter ();
			idParam.ParameterName = "id";
			idParam.DbType = DbType.Int32;
			idParam.Value = id;
			parameters.Add (idParam);

			VirtuosoParameter iParam = insert.CreateParameter ();
			iParam.ParameterName = "i";
			iParam.DbType = DbType.Int32;
			iParam.Value = i;
			parameters.Add (iParam);

			VirtuosoParameter siParam = insert.CreateParameter ();
			siParam.ParameterName = "si";
			siParam.DbType = DbType.Int16;
			siParam.Value = si;
			parameters.Add (siParam);

			VirtuosoParameter dParam = insert.CreateParameter ();
			dParam.ParameterName = "d";
			dParam.DbType = DbType.Double;
			dParam.Value = d;
			parameters.Add (dParam);

			VirtuosoParameter rParam = insert.CreateParameter ();
			rParam.ParameterName = "r";
			rParam.DbType = DbType.Single;
			rParam.Value = r;
			parameters.Add (rParam);

			VirtuosoParameter nParam = insert.CreateParameter ();
			nParam.ParameterName = "n";
			nParam.DbType = DbType.Decimal;
			nParam.Value = n;
			parameters.Add (nParam);

			VirtuosoParameter dtParam = insert.CreateParameter ();
			dtParam.ParameterName = "dt";
			dtParam.DbType = DbType.Date;
			dtParam.Value = dt;
			parameters.Add (dtParam);

			VirtuosoParameter tmParam = insert.CreateParameter ();
			tmParam.ParameterName = "tm";
			tmParam.DbType = DbType.Time;
			tmParam.Value = tm;
			parameters.Add (tmParam);

			VirtuosoParameter dtmParam = insert.CreateParameter ();
			dtmParam.ParameterName = "dtm";
			dtmParam.DbType = DbType.DateTime;
			dtmParam.Value = dtm;
			parameters.Add (dtmParam);

			VirtuosoParameter cParam = insert.CreateParameter ();
			cParam.ParameterName = "c";
			cParam.DbType = DbType.AnsiStringFixedLength;
			cParam.Value = str;
			parameters.Add (cParam);

			VirtuosoParameter vcParam = insert.CreateParameter ();
			vcParam.ParameterName = "vc";
			vcParam.DbType = DbType.AnsiString;
			vcParam.Value = str;
			parameters.Add (vcParam);

			VirtuosoParameter lvcParam = insert.CreateParameter ();
			lvcParam.ParameterName = "lvc";
			lvcParam.DbType = DbType.AnsiString;
			lvcParam.Value = str;
			parameters.Add (lvcParam);

			VirtuosoParameter ncParam = insert.CreateParameter ();
			ncParam.ParameterName = "nc";
			ncParam.DbType = DbType.StringFixedLength;
			ncParam.Value = str;
			parameters.Add (ncParam);

			VirtuosoParameter nvcParam = insert.CreateParameter ();
			nvcParam.ParameterName = "nvc";
			nvcParam.DbType = DbType.String;
			nvcParam.Value = str;
			parameters.Add (nvcParam);

			VirtuosoParameter lnvcParam = insert.CreateParameter ();
			lnvcParam.ParameterName = "lnvc";
			lnvcParam.DbType = DbType.String;
			lnvcParam.Value = str;
			parameters.Add (lnvcParam);

			VirtuosoParameter bParam = insert.CreateParameter ();
			bParam.ParameterName = "b";
			bParam.DbType = DbType.Binary;
			bParam.Value = bin;
			parameters.Add (bParam);

			VirtuosoParameter vbParam = insert.CreateParameter ();
			vbParam.ParameterName = "vb";
			vbParam.DbType = DbType.Binary;
			vbParam.Value = bin;
			parameters.Add (vbParam);

			VirtuosoParameter lvbParam = insert.CreateParameter ();
			lvbParam.ParameterName = "lvb";
			lvbParam.DbType = DbType.Binary;
			lvbParam.Value = bin;
			parameters.Add (lvbParam);

			try
			{
				insert.ExecuteNonQuery();
			}
			finally
			{
				insert.Dispose();
				insert = null;
			}

			DataRow row = checkTable.NewRow ();
			row["id"] = id;
			row["i"] = i;
			row["si"] = si;
			row["d"] = d;
			row["r"] = r;
			row["n"] = n;
			row["dt"] = dt;
			row["tm"] = tm;
			row["dtm"] = dtm;
			row["c"] = str;
			row["vc"] = str;
			row["lvc"] = str;
			row["nc"] = str;
			row["nvc"] = str;
			row["lnvc"] = str;
			row["b"] = bin;
			row["vb"] = bin;
			row["lvb"] = bin;
			checkTable.Rows.Add (row);
		}

		private void DeleteRow (int id)
		{
			foreach (DataRow row in checkTable.Rows)
			{
				if ((int) row["id"] == id)
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

			DataTable table = dataset.Tables["table"];

			result.FailIfNotEqual (checkTable.Rows.Count, table.Rows.Count);
			result.FailIfNotEqual (checkTable.Columns.Count, table.Columns.Count);
			for (int i = 0; i < table.Rows.Count; i++)
			{
				Debug.WriteLine ("row #" + i);
				DataRow row = table.Rows[i];
				DataRow checkRow = checkTable.Rows[i];
				for (int j = 0; j < table.Columns.Count; j++)
				{
					string name = table.Columns[j].ColumnName;
					result.FailIfNotEqual (this, "Comparison failed for column " + name + ": ", checkRow[name], row[name]);
				}
			}
		}
	}
}

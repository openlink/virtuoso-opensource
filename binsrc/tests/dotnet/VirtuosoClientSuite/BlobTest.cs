//
//  $Id$
//
//  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
//  project.
//
//  Copyright (C) 1998-2016 OpenLink Software
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
	[TestSuite ("BLOB Tests")]
	internal class BlobTest : TestCase
	{
		const int NRows = 20;
		const int BufferSize = 1000;

		enum Selector
		{
			//GetValue,
			GetChars,
			GetBytes,
		}

		enum Sequence
		{
			GetAll,
			GetHalf,
			GetTwice,
		}

		private VirtuosoConnection connection;
		private DataTable checkTable;

		protected override void SetUp ()
		{
			string host = TestSettings.GetString ("HOST");
			string connectionString = "HOST=" + host + ";UID=dba;PWD=dba;DATABASE=db;";
			connection = new VirtuosoConnection (connectionString);
			connection.Open ();

			CreateTable ();
			for (int i = 0; i < NRows; i++)
			{
				InsertRow (i);
			}
		}

		protected override void TearDown ()
		{
			connection.Close();
			connection = null;
		}

		[TestCase ("DataSet Table with BLOBs")]
		public void TestDataSetTable (TestCaseResult result)
		{
			CheckDataSetTable (result);
		}

		[TestCase ("GetChars with CommandBehavior.Default on LONG VARCHAR")]
		public void TestGetCharsDefaultChar (TestCaseResult result)
		{
			DoGetDataTest (result, "select c from foo order by id", 0,
				CommandBehavior.Default, Selector.GetChars, Sequence.GetAll);
		}

		[TestCase ("GetChars with CommandBehavior.Default on LONG NVARCHAR")]
		public void TestGetCharsDefaultNChar (TestCaseResult result)
		{
			DoGetDataTest (result, "select nc from foo order by id", 0,
				CommandBehavior.Default, Selector.GetChars, Sequence.GetAll);
		}

		[TestCase ("GetChars with CommandBehavior.Default on LONG VARBINARY")]
		public void TestGetCharsDefaultBin (TestCaseResult result)
		{
			DoGetDataTest (result, "select b from foo order by id", 0,
				CommandBehavior.Default, Selector.GetBytes, Sequence.GetAll);
		}

		[TestCase ("GetChars with CommandBehavior.SequentialAccess on LONG VARCHAR")]
		public void TestGetCharsSequentialChar (TestCaseResult result)
		{
			DoGetDataTest (result, "select c from foo order by id", 0,
				CommandBehavior.SequentialAccess, Selector.GetChars, Sequence.GetAll);
		}

		[TestCase ("GetChars with CommandBehavior.SequentialAccess on LONG NVARCHAR")]
		public void TestGetCharsSequentialNChar (TestCaseResult result)
		{
			DoGetDataTest (result, "select nc from foo order by id", 0,
				CommandBehavior.SequentialAccess, Selector.GetChars, Sequence.GetAll);
		}

		[TestCase ("GetChars with CommandBehavior.SequentialAccess on LONG VARBINARY")]
		public void TestGetCharsSequentialBin (TestCaseResult result)
		{
			DoGetDataTest (result, "select b from foo order by id", 0,
				CommandBehavior.SequentialAccess, Selector.GetBytes, Sequence.GetAll);
		}

		[TestCase ("GetChars with CommandBehavior.SequentialAccess on LONG VARCHAR skipping some data")]
		public void TestGetCharsSequentialCharSkip (TestCaseResult result)
		{
			DoGetDataTest (result, "select c from foo order by id", 0,
				CommandBehavior.SequentialAccess, Selector.GetChars, Sequence.GetHalf);
		}

		[TestCase ("GetChars with CommandBehavior.SequentialAccess on LONG NVARCHAR skipping some data")]
		public void TestGetCharsSequentialNCharSkip (TestCaseResult result)
		{
			DoGetDataTest (result, "select nc from foo order by id", 0,
				CommandBehavior.SequentialAccess, Selector.GetChars, Sequence.GetHalf);
		}

		[TestCase ("GetChars with CommandBehavior.SequentialAccess on LONG VARBINARY skipping some data")]
		public void TestGetCharsSequentialBinSkip (TestCaseResult result)
		{
			DoGetDataTest (result, "select b from foo order by id", 0,
				CommandBehavior.SequentialAccess, Selector.GetBytes, Sequence.GetHalf);
		}

		[TestCase ("GetChars with CommandBehavior.SequentialAccess on LONG VARCHAR reading some data twice")]
		public void TestGetCharsSequentialCharTwice (TestCaseResult result)
		{
			DoGetDataTest (result, "select c from foo order by id", 0,
				CommandBehavior.SequentialAccess, Selector.GetChars, Sequence.GetTwice);
		}

		[TestCase ("GetChars with CommandBehavior.SequentialAccess on LONG NVARCHAR reading some data twice")]
		public void TestGetCharsSequentialNCharTwice (TestCaseResult result)
		{
			DoGetDataTest (result, "select nc from foo order by id", 0,
				CommandBehavior.SequentialAccess, Selector.GetChars, Sequence.GetTwice);
		}

		[TestCase ("GetChars with CommandBehavior.SequentialAccess on LONG VARBINARY reading some data twice")]
		public void TestGetCharsSequentialBinTwice (TestCaseResult result)
		{
			DoGetDataTest (result, "select b from foo order by id", 0,
				CommandBehavior.SequentialAccess, Selector.GetBytes, Sequence.GetTwice);
		}

		private void CreateTable ()
		{
			VirtuosoCommand cmd = new VirtuosoCommand ();
			cmd.Connection = connection;

			try
			{
				cmd.CommandText = "drop table foo";
				cmd.ExecuteNonQuery ();
			}
			catch (Exception)
			{
			}

			cmd.CommandText = "create table foo (id int primary key, c long varchar, nc long nvarchar, b long varbinary)";
			cmd.ExecuteNonQuery ();
			cmd.Dispose ();

			checkTable = new DataTable ();
			checkTable.Columns.Add ("id", typeof (int));
			checkTable.Columns.Add ("c", typeof (string));
			checkTable.Columns.Add ("nc", typeof (string));
			checkTable.Columns.Add ("b", typeof (byte[]) );
		}

		private void InsertRow (int id)
		{
			object c, nc, b;

			if (id == 0)
			{
				c = nc = b = DBNull.Value;
			}
			else
			{
				int length = 1 << (id - 1);
				char[] chars = new char[length];
				byte[] bytes = new byte[length];
				for (int i = 0; i < length; i++)
				{
					chars[i] = (char) (' ' + i % (127 - ' '));
					bytes[i] = (byte) (i % 256);
				}
				c = nc = new String (chars);
				b = bytes;
			}

			VirtuosoCommand insert = connection.CreateCommand();
			insert.CommandText =
				"insert into foo "
				+ "(id, c, nc, b) "
				+ "values "
				+ "(?,  ?,  ?, ?)";

			VirtuosoParameterCollection parameters = insert.Parameters;

			VirtuosoParameter idParam = insert.CreateParameter ();
			idParam.ParameterName = "id";
			idParam.DbType = DbType.Int32;
			idParam.Value = id;
			parameters.Add (idParam);

			VirtuosoParameter cParam = insert.CreateParameter ();
			cParam.ParameterName = "c";
			cParam.DbType = DbType.AnsiString;
			cParam.Value = c;
			parameters.Add (cParam);

			VirtuosoParameter ncParam = insert.CreateParameter ();
			ncParam.ParameterName = "nc";
			ncParam.DbType = DbType.String;
			ncParam.Value = nc;
			parameters.Add (ncParam);

			VirtuosoParameter bParam = insert.CreateParameter ();
			bParam.ParameterName = "b";
			bParam.DbType = DbType.Binary;
			bParam.Value = b;
			parameters.Add (bParam);

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
			row["c"] = c;
			row["nc"] = nc;
			row["b"] = b;
			checkTable.Rows.Add (row);
		}

		private void CheckDataSetTable (TestCaseResult result)
		{
			VirtuosoCommand select = connection.CreateCommand ();
			select.CommandText = "select * from foo order by id";

			VirtuosoDataAdapter adapter = new VirtuosoDataAdapter ();
			adapter.SelectCommand = (VirtuosoCommand) select;

			DataSet dataset = new DataSet ();
			adapter.Fill (dataset);

			DataTable table = dataset.Tables["table"];

			result.FailIfNotEqual (checkTable.Rows.Count, table.Rows.Count);
			result.FailIfNotEqual (checkTable.Columns.Count, table.Columns.Count);
			for (int i = 0; i < table.Rows.Count; i++)
			{
				DataRow row = table.Rows[i];
				DataRow checkRow = checkTable.Rows[i];
				for (int j = 0; j < table.Columns.Count; j++)
				{
					string name = table.Columns[j].ColumnName;
					result.FailIfNotEqual (this, "Comparison failed for column " + name + ": ", checkRow[name], row[name]);
				}
			}
		}

		private void DoGetDataTest (TestCaseResult result, string text, int column,
			CommandBehavior behavior, Selector selector, Sequence sequence)
		{
			VirtuosoCommand cmd = null;
			VirtuosoDataReader dr = null;
			try
			{
				cmd = new VirtuosoCommand (text, connection);
				dr = cmd.ExecuteReader (behavior);
				CheckGetData (result, dr, column, selector, sequence);
			}
			finally
			{
				if (dr != null)
					dr.Close ();
				if (cmd != null)
					cmd.Dispose ();
			}
		}

		private void CheckGetData (TestCaseResult result,
			VirtuosoDataReader dr, int column, Selector selector, Sequence sequence)
		{
			string name = dr.GetName (column);
			int tableColumn = checkTable.Columns.IndexOf (name);
			for (int row = 0; dr.Read (); row++)
			{
				//if (dr.IsDBNull (column))
				if (row == 0)
					continue;

				long length;
				if (selector == Selector.GetBytes)
					length = dr.GetBytes (column, 0, null, 0, 0);
				else //if (selector == Selector.GetChars)
					length = dr.GetChars (column, 0, null, 0, 0);

				//Console.WriteLine ("row: {0}", row);
				//Console.WriteLine ("length: {0}", length);

				CompareSize (result, row, tableColumn, selector, length, 0);

				long offset = 0;
				byte[] bytes = new byte[BufferSize];
				char[] chars = new char[BufferSize];
				int count = 0;
				while (offset < length)
				{
					//Console.WriteLine ("offset: {0}", offset);

					long nextLength;
					if (selector == Selector.GetBytes)
					{
						for (int i = 0; i < bytes.Length; i++)
							bytes[i] = 0;
						nextLength = dr.GetBytes (column, offset, bytes, 0, bytes.Length);
					}
					else //if (selector == Selector.GetChars)
					{
						for (int i = 0; i < chars.Length; i++)
							chars[i] = (char) 0;
						nextLength = dr.GetChars (column, offset, chars, 0, chars.Length);
					}

					result.FailIfEqual (this, 0, nextLength);
					if (offset + nextLength < length)
						result.FailIfNotEqual (this, (long) BufferSize, nextLength);
					else
						result.FailIfNotEqual (this, (long) (length - offset), nextLength);

					if (selector == Selector.GetBytes)
						CompareData (result, row, tableColumn, bytes, nextLength, offset);
					else //if (selector == Selector.GetChars)
						CompareData (result, row, tableColumn, chars, nextLength, offset);

					if (sequence == Sequence.GetAll)
					{
						offset += nextLength;
					}
					else if (sequence == Sequence.GetHalf)
					{
						offset += 2 * nextLength;
					}
					else //if (sequence == Sequence.GetTwice)
					{
						count++;
						if (count == 2)
						{
							count = 0;
							offset += 2 * nextLength;
						}
					}
				}
			}
		}

		private void CompareSize (TestCaseResult result,
			int row, int column, Selector selector,
			long length, long offset)
		{
			DataRow dataRow = checkTable.Rows[row];
			object columnData = dataRow[column];
			if (selector == Selector.GetBytes)
			{
				byte[] bytes = (byte[]) columnData;
				if (offset > bytes.Length)
					result.FailIfNotEqual (this, 0, length);
				else
					result.FailIfNotEqual (this, bytes.Length - offset, length);
			}
			if (selector == Selector.GetChars)
			{
				char[] chars = columnData.ToString().ToCharArray();
				if (offset > chars.Length)
					result.FailIfNotEqual (this, 0, length);
				else
					result.FailIfNotEqual (this, chars.Length - offset, length);
			}
			/*
			if (selector == Selector.GetValue)
			{
				throw new NotSupportedException ();
			}
			*/
		}

		private void CompareData (TestCaseResult result,
			int row, int column, byte[] data,
			long length, long offset)
		{
			DataRow dataRow = checkTable.Rows[row];
			byte[] bytes = (byte[]) dataRow[column];
			byte[] expected = new byte[length];
			byte[] actual = new byte[length];
			Array.Copy (bytes, (int) offset, expected, 0, (int) length);
			Array.Copy (data, 0, actual, 0, (int) length);
			result.FailIfNotEqual (this, expected, actual);
		}

		private void CompareData (TestCaseResult result,
			int row, int column, char[] data,
			long length, long offset)
		{
			DataRow dataRow = checkTable.Rows[row];
			char[] chars = dataRow[column].ToString().ToCharArray();
			char[] expected = new char[length];
			char[] actual = new char[length];
			Array.Copy (chars, (int) offset, expected, 0, (int) length);
			Array.Copy (data, 0, actual, 0, (int) length);
			result.FailIfNotEqual (this, expected, actual);
		}
	}
}

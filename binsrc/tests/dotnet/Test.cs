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
using System.Collections.Specialized;
using System.Data;
using System.Windows.Forms;
using OpenLink.Data.VirtuosoClient;

namespace VirtuosoClientTest
{
	/// <summary>
	/// Summary description for Class1.
	/// </summary>
	class Test : Form
	{
		private DataSet dataset;
		private DataGrid datagrid;

		private static int instance_count;

		Test (DataSet dataset, String tableName)
		{
			this.dataset = dataset;
			this.datagrid = new DataGrid ();
			this.AutoScaleBaseSize = new System.Drawing.Size (5, 13);
			this.Text = "Test";
			this.ClientSize = new System.Drawing.Size (348, 232);

			this.datagrid.CaptionText = "Grid";
			this.datagrid.Dock = DockStyle.Fill;
			this.Controls.Add (this.datagrid);

			this.datagrid.SetDataBinding (dataset, tableName);
		}

		private static void Test_Closed (object sender, EventArgs e)
		{
			if (--instance_count == 0)
				Application.ExitThread ();
		}

		private static void TestPooling (string connString)
		{
			const int n = 1000/*, m = 100*/;
			string connStringPool = connString + ";Pooling=true";
			string connStringNoPool = connString + ";Pooling=false";
			VirtuosoConnection first, conn = null;
			DateTime start;
			int i;

			first = new VirtuosoConnection (connStringNoPool);
			start = DateTime.Now;
			System.Console.WriteLine ("before Open(): {0}.{1:000}", DateTime.Now.Second, DateTime.Now.Millisecond);
			first.Open ();
			System.Console.WriteLine ("after Open(): {0}.{1:000}", DateTime.Now.Second, DateTime.Now.Millisecond);
			System.Console.WriteLine ("open first connection {0}", DateTime.Now - start);

			System.Console.WriteLine ("With pooling enabled");
			conn = new VirtuosoConnection (connStringPool);
			start = DateTime.Now;
			for (i = 0; i < n; i++)
			{
				//if ((i % m) == 0)
				//	System.Console.WriteLine ("i={0}", i);
				conn.Open ();
				conn.Close ();
			}
			System.Console.WriteLine ("{0} connections: {1}", n, DateTime.Now - start);

			System.Console.WriteLine ("With pooling disabled");
			conn = new VirtuosoConnection (connStringNoPool);
			start = DateTime.Now;
			for (i = 0; i < n; i++)
			{
				//if ((i % m) == 0)
				//	System.Console.WriteLine ("i={0}", i);
				conn.Open ();
				conn.Close ();
			}
			System.Console.WriteLine ("{0} connections: {1}", n, DateTime.Now - start);

			start = DateTime.Now;
			first.Close ();
			System.Console.WriteLine ("close first connection {0}", DateTime.Now - start);
		}

		/// <summary>
		/// The main entry point for the application.
		/// </summary>
		[STAThread]
		static void Main (string[] args)
		{
			try
			{
				VirtuosoConnection conn;
				if (args.Length > 0)
				{
					TestPooling (args[0]);
					if (args.Length > 1 && args[1] == "-e")
						return;
					conn = new VirtuosoConnection (args[0]);
				}
				else
					conn = new VirtuosoConnection ();
				conn.Open ();

				IDbCommand drop = conn.CreateCommand();
				drop.CommandText = "drop table foo";
				try
				{
					drop.ExecuteNonQuery();
				}
				catch (Exception e)
				{
					Console.WriteLine("Got an Exception.");
					Console.WriteLine("{0}", e.Message);
					Console.WriteLine("StackTrace:");
					Console.WriteLine("{0}", e.StackTrace);
				}
				finally
				{
					drop.Dispose();
				}

				IDbCommand create = conn.CreateCommand();
				create.CommandText = "create table foo (id int primary key, txt varchar(100))";
				create.ExecuteNonQuery();
				create.Dispose();

				int rc;

				IDbCommand insert_1 = conn.CreateCommand();
				insert_1.CommandText = "insert into foo foo values (1, 'lorem')";
				rc = insert_1.ExecuteNonQuery();
				insert_1.Dispose();

				Console.WriteLine("rc: {0}", rc);

				IDbCommand insert_2 = conn.CreateCommand();
				insert_2.CommandText = "insert into foo foo values (2, 'ipsum')";
				rc = insert_2.ExecuteNonQuery();
				insert_2.Dispose();

				Console.WriteLine("rc: {0}", rc);

				IDbCommand select = conn.CreateCommand();
				select.CommandText = "select * from foo";
				IDataReader reader = select.ExecuteReader();

				DataSet dataset = new DataSet();

				DataTable schemaTable = reader.GetSchemaTable ();
				dataset.Tables.Add (schemaTable);

				VirtuosoDataAdapter adapter = new VirtuosoDataAdapter();
				adapter.SelectCommand = (VirtuosoCommand)select;
				adapter.Fill(dataset);

				//reader.Dispose();
				//select.Dispose();
				//conn.Dispose();

				Form[] forms = new Form[dataset.Tables.Count];
				instance_count = 0;
				foreach (DataTable t in dataset.Tables)
				{
					forms[instance_count] = new Test (dataset, t.TableName);
					forms[instance_count].Closed += new EventHandler (Test_Closed);
					forms[instance_count].Show ();
					instance_count++;
				}
				Application.Run ();
			}
			catch (Exception e)
			{
				Console.WriteLine("Got an Exception.");
				Console.WriteLine("{0}", e.Message);
				Console.WriteLine("StackTrace:");
				Console.WriteLine("{0}", e.StackTrace);
			}
		}

		private void InitializeComponent()
		{
			//
			// Test
			//
			this.AutoScaleBaseSize = new System.Drawing.Size(5, 13);
			this.ClientSize = new System.Drawing.Size(292, 273);
			this.Name = "Test";
		}
	}
}

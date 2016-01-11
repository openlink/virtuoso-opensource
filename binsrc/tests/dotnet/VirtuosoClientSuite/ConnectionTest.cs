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
	[TestSuite ("Connection Tests")]
	internal class ConnectionTest : TestCase
	{
		[TestCase ("Dispose new Connection")]
		public void DisposeNew (TestCaseResult result)
		{
			VirtuosoConnection conn = new VirtuosoConnection ();
			conn.Dispose ();
		}

		[TestCase ("Dispose new Connection with invalid connection string")]
		public void DisposeInvalid (TestCaseResult result)
		{
			VirtuosoConnection conn = null;
			try
			{
				string connectionString = "InvalidConnectionString";
				conn = new VirtuosoConnection (connectionString);
			}
			catch (ArgumentException)
			{
				// suppress ArgumentException
			}
			finally
			{
				if (conn != null)
					conn.Dispose ();
			}
		}

		[TestCase ("Connection State")]
		public void State (TestCaseResult result)
		{
			string host = TestSettings.GetString ("HOST");
			string connectionString = "HOST=" + host + ";UID=dba;PWD=dba;";
			VirtuosoConnection conn = new VirtuosoConnection (connectionString);
			try
			{
				result.FailIfNotEqual (ConnectionState.Closed, conn.State);
				conn.Open ();
				result.FailIfNotEqual (ConnectionState.Open, conn.State);
				conn.Close ();
				result.FailIfNotEqual (ConnectionState.Closed, conn.State);
			}
			finally
			{
				conn.Dispose ();
			}
		}

		[TestCase ("Connection String")]
		public void ConnectionString (TestCaseResult result)
		{
			string host = TestSettings.GetString ("HOST");
			string connectionString = "HOST=" + host + ";UID=dba;PWD=dba;";
			string secureConnectionString = "HOST=" + host + ";UID=dba;";
			VirtuosoConnection conn = new VirtuosoConnection (connectionString);
			try
			{
				result.FailIfNotEqual (connectionString, conn.ConnectionString);
				conn.Open ();
				result.FailIfNotEqual (secureConnectionString, conn.ConnectionString);
				conn.Close ();
				result.FailIfNotEqual (secureConnectionString, conn.ConnectionString);
			}
			finally
			{
				conn.Dispose ();
			}
		}

		[TestCase ("Persist Security Info")]
		public void PersistSecurityInfo (TestCaseResult result)
		{
			string host = TestSettings.GetString ("HOST");
			string connectionString = "HOST=" + host + ";UID=dba;PWD=dba;Persist Security Info=true;";
			VirtuosoConnection conn = new VirtuosoConnection (connectionString);
			try
			{
				result.FailIfNotEqual (connectionString, conn.ConnectionString);
				conn.Open ();
				result.FailIfNotEqual (connectionString, conn.ConnectionString);
				conn.Close ();
				result.FailIfNotEqual (connectionString, conn.ConnectionString);
			}
			finally
			{
				conn.Dispose ();
			}
		}

		[TestCase ("Open Connection With Connection Pooling")]
		public void OdbcConnectionWithPooling (TestCaseResult result)
		{
			string host = TestSettings.GetString ("HOST");
			string connectionString = "HOST=" + host + ";UID=dba;PWD=dba;Pooling=True;";
			VirtuosoConnection conn = new VirtuosoConnection (connectionString);
			try
			{
				conn.Open ();
				conn.Close ();
			}
			finally
			{
				conn.Dispose ();
			}
		}

		[TestCase ("Open Connection Without Connection Pooling")]
		public void OdbcConnectionWithoutPooling (TestCaseResult result)
		{
			string host = TestSettings.GetString ("HOST");
			string connectionString = "HOST=" + host + ";UID=dba;PWD=dba;Pooling=False;";
			VirtuosoConnection conn = new VirtuosoConnection (connectionString);
			try
			{
				conn.Open ();
				conn.Close ();
			}
			finally
			{
				conn.Dispose ();
			}
		}
	}
}

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
	[TestSuite ("Command Timeout Tests")]
	internal class TimeoutTest : TestCase
	{
		private VirtuosoConnection connection;

		protected override void SetUp ()
		{
			string host = TestSettings.GetString ("HOST");
			string connectionString = "HOST=" + host + ";UID=dba;PWD=dba;Pooling=False;";
			connection = new VirtuosoConnection (connectionString);
			connection.Open ();
		}

		protected override void TearDown ()
		{
			connection.Close();
			connection = null;
		}

		[TestCase ("Delay less than timeout.")]
		public void DelayLessThanTimeout (TestCaseResult result)
		{
			VirtuosoCommand command = connection.CreateCommand ();
			try
			{
				command.CommandTimeout = 50;
				command.CommandText = "delay(5)";
				command.ExecuteNonQuery ();
			}
			finally
			{
				command.Dispose ();
			}
		}

		[TestCase ("Delay more than timeout.")]
		public void DelayMoreThanTimeout (TestCaseResult result)
		{
			VirtuosoCommand command = connection.CreateCommand ();
			bool thrown = false;
			try
			{
				command.CommandTimeout = 5;
				command.CommandText = "delay(50)";
				command.ExecuteNonQuery ();
			}
			catch (SystemException)
			{
				thrown = true;
			}
			finally
			{
				command.Dispose ();
			}
			result.FailIfNot ("No timeout exception is thrown", thrown);
		}

		class Sleeper
		{
			private string name;
			private VirtuosoCommand command;
			private int timeout, delay;

			internal Sleeper (string name, VirtuosoCommand command, int delay, int timeout)
			{
				this.name = name;
				this.command = command;
				this.delay = delay;
				this.timeout = timeout;
			}

			internal void Sleep ()
			{
				command.CommandText = "delay(" + delay + ")";
				command.CommandTimeout = timeout;
				Console.WriteLine (name + ": started (" + command.CommandText + ").");
				try
				{
					command.ExecuteNonQuery ();
				}
				catch (SystemException e)
				{
					Console.WriteLine (name + ":" + e);
				}
				Console.WriteLine (name + ": finished.");
			}
		};

		[TestCase ("Three Commands")]
		public void ThreeCommands (TestCaseResult result)
		{
			/*
			VirtuosoCommand cmd1 = connection.CreateCommand ();
			Sleeper sleeper1 = new Sleeper ("first", cmd1, 30, 60);
			Thread thread1 = new Thread (new ThreadStart (sleeper1.Sleep));
			*/

			VirtuosoCommand cmd2 = connection.CreateCommand ();
			Sleeper sleeper2 = new Sleeper ("second", cmd2, 20, 40);
			Thread thread2 = new Thread (new ThreadStart (sleeper2.Sleep));

			VirtuosoCommand cmd3 = connection.CreateCommand ();
			Sleeper sleeper3 = new Sleeper ("third", cmd3, 10, 20);
			Thread thread3 = new Thread (new ThreadStart (sleeper3.Sleep));

			try
			{
				//thread1.Start ();
				//Thread.Sleep (2000);
				thread2.Start ();
				Thread.Sleep (2000);
				thread3.Start ();
			}
			finally
			{
				//thread1.Join ();
				thread2.Join ();
				thread3.Join ();
				//cmd1.Dispose ();
				cmd2.Dispose ();
				cmd3.Dispose ();
			}
		}
	}
}

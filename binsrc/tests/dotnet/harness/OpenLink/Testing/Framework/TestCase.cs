//
//  $Id$
//
//  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
//  project.
//
//  Copyright (C) 1998-2015 OpenLink Software
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

namespace OpenLink.Testing.Framework
{
	public delegate void TestDelegate (TestCaseResult result);

	public class TestCase : ITest
	{
		private string name;
		private TestDelegate test;

		public TestCase ()
			: this (null)
		{
		}

		public TestCase (string name)
			: this (name, (TestDelegate) null)
		{
		}

		public TestCase (string name, TestDelegate test)
		{
			this.name = name;
			this.test = test;
		}

		public TestCase (string name, string methodName)
		{
			this.name = name;
			this.test = (TestDelegate) Delegate.CreateDelegate (typeof (TestDelegate), this, methodName);
		}

		public string Name
		{
			get { return name; }
			set { name = value; }
		}

		public TestDelegate Test
		{
			get { return test; }
			set { test = value; }
		}

		public int CountTestCases ()
		{
			return 1;
		}

		/// <summary>
		/// A convenience method to run the test.
		/// </summary>
		/// <returns></returns>
		public TestResult Run ()
		{
			TestResult testResult = CreateTestResult ();
			Run (testResult);
			return testResult;
		}

		public void Run (TestResult testResult)
		{
			TestCaseResult testCaseResult = CreateTestCaseResult (testResult);
			testResult.RunCase (this, testCaseResult);
		}

		public void RunCase (TestCaseResult result)
		{
			SetUp ();
			try
			{
				PerformTest (result);
			}
			finally
			{
				TearDown ();
			}
		}

		protected virtual void SetUp ()
		{
		}

		protected virtual void TearDown ()
		{
		}

		protected virtual TestResult CreateTestResult ()
		{
			return new TestResult ();
		}

		protected virtual TestCaseResult CreateTestCaseResult (TestResult testResult)
		{
			return new TestCaseResult (testResult);
		}

		protected virtual void PerformTest (TestCaseResult result)
		{
			if (test == null)
			{
				test = (TestDelegate) Delegate.CreateDelegate (typeof (TestDelegate), this, name);
			}
			test (result);
		}
	}
}

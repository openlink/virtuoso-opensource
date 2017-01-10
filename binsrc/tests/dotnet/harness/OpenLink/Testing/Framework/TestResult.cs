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
using System.Collections;

namespace OpenLink.Testing.Framework
{
	public class TestResult
	{
		private ArrayList listeners;
		private int runCount;
		private int skippedCount;
		private int passedCount;
		private int errorCount;
		private int failureCount;
		private int warningCount;

		public TestResult ()
		{
			listeners = new ArrayList ();
			runCount = 0;
			passedCount = 0;
			errorCount = 0;
			failureCount = 0;
			warningCount = 0;
		}

		public int RunCount
		{
			get { return runCount; }
		}

		public int SkippedCount
		{
			get { return skippedCount; }
		}

		public int PassedCount
		{
			get { return passedCount; }
		}

		public int ErrorCount
		{
			get { return errorCount; }
		}

		public int FailureCount
		{
			get { return failureCount; }
		}

		public int WarningCount
		{
			get { return warningCount; }
		}

		public bool HasPassed ()
		{
			return runCount == passedCount;
		}

		public void AddListener (ITestListener listener)
		{
			lock (listeners.SyncRoot)
			{
				listeners.Add (listener);
			}
		}

		public void RemoveListener (ITestListener listener)
		{
			lock (listeners.SyncRoot)
			{
				listeners.Remove (listener);
			}
		}

		public void StatusNotify (TestCase testCase, TestStatus status)
		{
			lock (listeners.SyncRoot)
			{
				switch (status.Code)
				{
				case TestStatusCode.Skipped:
					skippedCount++;
					break;
				case TestStatusCode.Warning:
					warningCount++;
					break;
				case TestStatusCode.Failure:
					failureCount++;
					break;
				case TestStatusCode.Error:
					errorCount++;
					break;
				}
				foreach (ITestListener listener in listeners)
				{
					listener.StatusNotify (testCase, status);
				}
			}
		}

		public void RunCase (TestCase testCase, TestCaseResult testCaseResult)
		{
			StartTest (testCase);
			testCaseResult.RunCase (testCase);
			EndTest (testCase, testCaseResult);
		}

		private void StartTest (TestCase testCase)
		{
			lock (listeners.SyncRoot)
			{
				runCount++;
				foreach (ITestListener listener in listeners)
				{
					listener.StartTest (testCase);
				}
			}
		}

		private void EndTest (TestCase testCase, TestCaseResult testCaseResult)
		{
			lock (listeners.SyncRoot)
			{
				if (testCaseResult.HasPassed ())
				{
					passedCount++;
				}
				foreach (ITestListener listener in listeners)
				{
					listener.EndTest (testCase, testCaseResult);
				}
			}
		}
	}
}

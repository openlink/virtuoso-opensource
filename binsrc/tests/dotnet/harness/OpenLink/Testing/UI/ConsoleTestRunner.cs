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
using System.Collections;
using System.Diagnostics;
using System.IO;
using OpenLink.Testing.Framework;
using OpenLink.Testing.Util;

namespace OpenLink.Testing.UI
{
	public class ConsoleTestRunner : BaseTestRunner
	{
		public override void StartTest (TestCase testCase)
		{
			Console.WriteLine ("STARTED: {0}", testCase.Name);
		}

		public override void EndTest (TestCase testCase, TestCaseResult result)
		{
			if (result.HasSkipped ())
				Console.WriteLine ("SKIPPED: {0}", testCase.Name);
			else if (result.HasPassed ())
				Console.WriteLine ("PASSED: {0}", testCase.Name);
#if false
			else if (result.HasWarnings ())
				Console.WriteLine ("PASSED with warnings: {0}", testCase.Name);
#endif
			else
				Console.WriteLine ("***FAILED: {0}", testCase.Name);
		}

		public override void StatusNotify (TestCase testCase, TestStatus status)
		{
			Console.WriteLine ("{0}", status);
		}

		public void WriteResult (TestResult result)
		{
			Console.WriteLine ("Tests run: {0}", result.RunCount);
			Console.WriteLine ("Tests skipped: {0}", result.SkippedCount);
			Console.WriteLine ("Tests passed: {0}", result.PassedCount);
			Console.WriteLine ("Errors: {0}", result.ErrorCount);
			Console.WriteLine ("Failures: {0}", result.FailureCount);
			Console.WriteLine ("Warnings: {0}", result.WarningCount);
		}

		public static void Main (string[] args)
		{
			ConsoleTestRunner runner = new ConsoleTestRunner ();
			runner.Run (args);
		}

		protected void Run (string[] args)
		{
			ITest test = ProcessArguments (args);
			if (test == null)
				return;

			TraceListener debugListener = GetListener ("debug");
			if (debugListener != null)
				Debug.Listeners.Add (debugListener);

			TraceListener traceListener = GetListener ("trace");
			if (traceListener != null)
				Trace.Listeners.Add (traceListener);

			TestResult result = new TestResult ();
			result.AddListener (this);
			test.Run (result);
			WriteResult (result);
		}

		private TraceListener GetListener (string name)
		{
			object value = TestSettings.Get (name);
			if (value == null)
				return null;
			if (value is string)
				return LookupListener ((string) value);
			if (value is bool)
			{
				if ((bool) value)
					return new TextWriterTraceListener (System.Console.Out);
				return null;
			}
			throw new InvalidCastException ("The '" + name + "' setting has invalid data type.");
		}

		private class ListenerEntry
		{
			internal string fileName;
			internal TraceListener listener;
		}

		private ArrayList listeners = new ArrayList (3);

		private TraceListener LookupListener (string fileName)
		{
			ListenerEntry entry;

			for (int i = 0; i < listeners.Count; i++)
			{
				entry = (ListenerEntry) listeners[i];
				// FIXME: what to do on case-sensitive filesystems?
				if (String.Compare (entry.fileName, fileName, true) == 0)
					return entry.listener;
			}

			entry = new ListenerEntry ();
			entry.fileName = fileName;
			entry.listener = new TextWriterTraceListener (fileName);
			listeners.Add (entry);
			return entry.listener;
		}
	}
}

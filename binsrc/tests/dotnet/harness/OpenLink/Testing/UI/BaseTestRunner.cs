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
using System.Collections.Specialized;
using System.Reflection;
using OpenLink.Testing.Framework;
using OpenLink.Testing.Util;

namespace OpenLink.Testing.UI
{
	public abstract class BaseTestRunner : ITestListener
	{
		public const string SUITE_PROPERTY_NAME = "Suite";

		public abstract void StartTest (TestCase testCase);
		public abstract void EndTest (TestCase testCase, TestCaseResult testCaseResult);
		public abstract void StatusNotify (TestCase testCase, TestStatus status);

		public ITest ProcessArguments (string[] args)
		{
			NameValueCollection map = GetArgumentMap ();
			string[] assemblies = TestSettings.ProcessArguments (map, args);
			return ProcessAssemblies (assemblies);
		}

		public ITest ProcessAssemblies (string[] assemblies)
		{
			if (assemblies == null)
				return null;

			ArrayList testList = new ArrayList ();
			foreach (string assembly in assemblies)
			{
				CollectAssemblyTests (testList, assembly);
			}
			if (testList.Count == 0)
				return null;
			if (testList.Count == 1)
				return (ITest) testList[0];

			TestSuite suite = new TestSuite ();
			foreach (ITest test in testList)
			{
				suite.AddTest (test);
			}
			return suite;
		}

		public void CollectAssemblyTests (ArrayList testList, string assemblyName)
		{
			Assembly assembly = null;
			try
			{
				assembly = Assembly.LoadFrom (assemblyName);
			}
			catch (Exception e)
			{
				runFailed (e);
			}
			if (assembly == null)
				return;

			Type[] types = assembly.GetExportedTypes ();
			foreach (Type type in types)
			{
				CollectTests (testList, type);
			}
		}

		public void CollectTests (ArrayList testList, Type type)
		{
			PropertyInfo propertyInfo = type.GetProperty (
				SUITE_PROPERTY_NAME,
				BindingFlags.Public | BindingFlags.Static,
				null, typeof (ITest), Type.EmptyTypes, null);
			if (propertyInfo == null)
				return;

			ITest test = (ITest) propertyInfo.GetValue (null, null);
			testList.Add (test);
		}

		protected virtual NameValueCollection GetArgumentMap ()
		{
			return null;
		}

		protected virtual void runFailed (Exception e)
		{
		}
	}
}

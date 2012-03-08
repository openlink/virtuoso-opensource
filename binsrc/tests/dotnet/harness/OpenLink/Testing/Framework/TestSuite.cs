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
using System.Collections;
using System.Reflection;

namespace OpenLink.Testing.Framework
{
	public class TestSuite : ITest
	{
		private string name = null;
		private ArrayList tests = new ArrayList ();

		private class Warning : TestCase
		{
			private string message;

			public Warning (string message)
				: base ("warning")
			{
				this.message = message;
			}

			protected override void PerformTest (TestCaseResult result)
			{
				result.Fail (message);
			}
		}

		public TestSuite ()
		{
		}

		public TestSuite (string name)
		{
			this.name = name;
		}

		public TestSuite (Type type)
		{
			AddTests (type);
			this.name = GetTestSuiteName (type);
		}

		public TestSuite (Type type, string name)
		{
			AddTests (type);
			this.name = name;
		}

		public string Name
		{
			get { return name; }
			set { name = value; }
		}

		public void AddTest (ITest test)
		{
			tests.Add (test);
		}

		public void AddTestSuite (Type type)
		{
			tests.Add (new TestSuite (type));
		}

		public int Count
		{
			get { return tests.Count; }
		}

		public ITest this [int index]
		{
			get { return (ITest) tests[index]; }
		}

		public int CountTestCases ()
		{
			int count = 0;
			foreach (ITest test in tests)
			{
				count += test.CountTestCases ();
			}
			return count;
		}

		public void Run (TestResult result)
		{
			foreach (ITest test in tests)
			{
				test.Run (result);
			}
		}

		private void AddTests (Type type)
		{
			ConstructorInfo ctor = GetConstructor (type);
			if (ctor == null)
			{
				tests.Add (new Warning ("The test suite has no suitable constructor."));
				return;
			}

			MethodInfo[] methods = type.GetMethods (BindingFlags.Instance | BindingFlags.Public);
			if (methods == null)
			{
				tests.Add (new Warning ("The test suite has no methods."));
				return;
			}

			foreach (MethodInfo method in methods)
			{
				if (IsTestMethod (method))
					AddTest (ctor, method);
			}
		}

		private bool IsTestMethod (MethodInfo method)
		{
			if (method.ReturnType != typeof (void))
				return false;

			ParameterInfo[] parameters = method.GetParameters ();
			if (parameters.Length != 1)
				return false;
			if (parameters[0].ParameterType != typeof (TestCaseResult))
				return false;

			return method.IsDefined (typeof (TestCaseAttribute), false);
		}

		private void AddTest (ConstructorInfo ctor, MethodInfo method)
		{
			string name = GetTestCaseName (method);

			object test;
			if (ctor.GetParameters().Length != 0)
			{
				test = ctor.Invoke (new String[1] {name});
			}
			else
			{
				test = ctor.Invoke (new Object[0]);
				if (test is TestCase)
					((TestCase) test).Name = name;
			}

			TestCase testCase = test is TestCase ? (TestCase) test : new TestCase (name);
			testCase.Test = (TestDelegate) Delegate.CreateDelegate (typeof (TestDelegate), test, method.Name);
			tests.Add (testCase);
		}

		private string GetTestSuiteName (Type type)
		{
			string name = null;
			TestSuiteAttribute attribute = (TestSuiteAttribute) Attribute.GetCustomAttribute (type, typeof (TestSuiteAttribute));
			if (attribute != null)
				name = attribute.Name;
			if (name == null)
				name = type.Name;
			return name;
		}

		private string GetTestCaseName (MethodInfo method)
		{
			string name = null;
			TestCaseAttribute attribute = (TestCaseAttribute) Attribute.GetCustomAttribute (method, typeof (TestCaseAttribute));
			if (attribute != null)
				name = attribute.Name;
			if (name == null)
				name = method.Name;
			return name;
		}

		private ConstructorInfo GetConstructor (Type type)
		{
			ConstructorInfo ctor = type.GetConstructor (new Type[] { typeof (string) });
			if (ctor != null)
				return ctor;
			return type.GetConstructor (Type.EmptyTypes);
		}
	}
}

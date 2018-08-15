//
//  $Id$
//
//  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
//  project.
//
//  Copyright (C) 1998-2018 OpenLink Software
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
	public class TestCaseResult
	{
		private TestResult testResult;
		private bool skipped;
		private bool hasErrors;
		private bool hasFailures;
		private bool hasWarnings;

		public TestCaseResult (TestResult testResult)
		{
			this.testResult = testResult;
			this.hasErrors = false;
			this.hasFailures = false;
			this.hasWarnings = false;
		}

		public bool HasSkipped ()
		{
			return skipped;
		}

		public bool HasPassed ()
		{
			return !hasErrors && !hasFailures;
		}

		public bool HasErrors ()
		{
			return hasErrors;
		}

		public bool HasFailures ()
		{
			return hasFailures;
		}

		public bool HasWarnings ()
		{
			return hasWarnings;
		}

		public void Skip ()
		{
			Skip (null);
		}

		public void Skip (string message)
		{
			throw new TestSkippedException (message);
		}

		public void Fail ()
		{
			Fail ((string) null);
		}

		public void Fail (string message)
		{
			throw new TestFailedException (message);
		}

		public void Fail (TestCase testCase)
		{
			Fail (testCase, null);
		}

		public void Fail (TestCase testCase, string message)
		{
			AddFailure (testCase, new TestFailedException (message));
		}

		public void Warn (TestCase testCase)
		{
			Warn (testCase, null);
		}

		public void Warn (TestCase testCase, string message)
		{
			AddWarning (testCase, new TestFailedException (message));
		}

		public void FailIf (bool condition)
		{
			FailIf ((string) null, condition);
		}

		public void FailIf (string message, bool condition)
		{
			if (condition)
				throw new TestFailedException (message);
		}

		public void FailIf (TestCase testCase, bool condition)
		{
			FailIf (testCase, null, condition);
		}

		public void FailIf (TestCase testCase, string message, bool condition)
		{
			if (condition)
				AddFailure (testCase, new TestFailedException (message));
		}

		public void WarnIf (TestCase testCase, bool condition)
		{
			WarnIf (testCase, null, condition);
		}

		public void WarnIf (TestCase testCase, string message, bool condition)
		{
			if (condition)
				AddWarning (testCase, new TestFailedException (message));
		}

		public void FailIfNot (bool condition)
		{
			FailIf (!condition);
		}

		public void FailIfNot (string message, bool condition)
		{
			FailIf (message, !condition);
		}

		public void FailIfNot (TestCase testCase, bool condition)
		{
			FailIf (testCase, !condition);
		}

		public void FailIfNot (TestCase testCase, string message, bool condition)
		{
			FailIf (testCase, message, !condition);
		}

		public void WarnIfNot (TestCase testCase, bool condition)
		{
			WarnIf (testCase, !condition);
		}

		public void WarnIfNot (TestCase testCase, string message, bool condition)
		{
			WarnIf (testCase, message, !condition);
		}

		public void FailIfEqual (object expected, object actual)
		{
			FailIfEqual ((string) null, expected, actual);
		}

		public void FailIfEqual (string message, object expected, object actual)
		{
			if (AreEqual (expected, actual))
				throw new ComparisonException (message, expected, actual);
		}

		public void FailIfEqual (TestCase testCase, object expected, object actual)
		{
			FailIfEqual (testCase, null, expected, actual);
		}

		public void FailIfEqual (TestCase testCase, string message, object expected, object actual)
		{
			if (AreEqual (expected, actual))
				AddFailure (testCase, new ComparisonException (message, expected, actual));
		}

		public void WarnIfEqual (TestCase testCase, object expected, object actual)
		{
			WarnIfEqual (testCase, null, expected, actual);
		}

		public void WarnIfEqual (TestCase testCase, string message, object expected, object actual)
		{
			if (AreEqual (expected, actual))
				AddWarning (testCase, new ComparisonException (message, expected, actual));
		}

		public void FailIfNotEqual (object expected, object actual)
		{
			FailIfNotEqual ((string) null, expected, actual);
		}

		public void FailIfNotEqual (string message, object expected, object actual)
		{
			if (!AreEqual (expected, actual))
				throw new ComparisonException (message, expected, actual);
		}

		public void FailIfNotEqual (TestCase testCase, object expected, object actual)
		{
			FailIfNotEqual (testCase, null, expected, actual);
		}

		public void FailIfNotEqual (TestCase testCase, string message, object expected, object actual)
		{
			if (!AreEqual (expected, actual))
				AddFailure (testCase, new ComparisonException (message, expected, actual));
		}

		public void WarnIfNotEqual (TestCase testCase, object expected, object actual)
		{
			WarnIfNotEqual (testCase, null, expected, actual);
		}

		public void WarnIfNotEqual (TestCase testCase, string message, object expected, object actual)
		{
			if (!AreEqual (expected, actual))
				AddWarning (testCase, new ComparisonException (message, expected, actual));
		}

		public void FailIfSame (object expected, object actual)
		{
			FailIfSame ((string) null, expected, actual);
		}

		public void FailIfSame (string message, object expected, object actual)
		{
			FailIf (ConcatMessages (message, "Expected the same reference value."), expected == actual);
		}

		public void FailIfSame (TestCase testCase, object expected, object actual)
		{
			FailIfSame (testCase, null, expected, actual);
		}

		public void FailIfSame (TestCase testCase, string message, object expected, object actual)
		{
			FailIf (testCase, ConcatMessages (message, "Expected the same reference value."), expected == actual);
		}

		public void WarnIfSame (TestCase testCase, object expected, object actual)
		{
			WarnIfSame (testCase, null, expected, actual);
		}

		public void WarnIfSame (TestCase testCase, string message, object expected, object actual)
		{
			WarnIf (testCase, ConcatMessages (message, "Expected not same reference value."), expected == actual);
		}

		public void FailIfNotSame (object expected, object actual)
		{
			FailIfNotSame ((string) null, expected, actual);
		}

		public void FailIfNotSame (string message, object expected, object actual)
		{
			FailIf (ConcatMessages (message, "Expected the same reference value."), expected != actual);
		}

		public void FailIfNotSame (TestCase testCase, object expected, object actual)
		{
			FailIfNotSame (testCase, null, expected, actual);
		}

		public void FailIfNotSame (TestCase testCase, string message, object expected, object actual)
		{
			FailIf (testCase, ConcatMessages (message, "Expected the same reference value."), expected != actual);
		}

		public void WarnIfNotSame (TestCase testCase, object expected, object actual)
		{
			WarnIfNotSame (testCase, null, expected, actual);
		}

		public void WarnIfNotSame (TestCase testCase, string message, object expected, object actual)
		{
			WarnIf (testCase, ConcatMessages (message, "Expected the same reference value."), expected != actual);
		}

		public void RunCase (TestCase testCase)
		{
			try
			{
				testCase.RunCase (this);
			}
			catch (TestSkippedException e)
			{
				SkipTest (testCase, e);
			}
			catch (TestFailedException e)
			{
				AddFailure (testCase, e);
			}
			catch (Exception e)
			{
				AddError (testCase, e);
			}
		}

		protected virtual void SkipTest (TestCase testCase, TestSkippedException e)
		{
			if (testResult != null)
			{
				testResult.StatusNotify (testCase, new TestStatus (TestStatusCode.Skipped, e.Message));
			}
			skipped = true;
		}

		protected virtual void AddError (TestCase testCase, Exception e)
		{
			if (testResult != null)
			{
				testResult.StatusNotify (testCase, new TestStatus (TestStatusCode.Error, e));
			}
			hasErrors = true;
		}

		protected virtual void AddFailure (TestCase testCase, TestFailedException e)
		{
			if (testResult != null)
			{
				testResult.StatusNotify (testCase, new TestStatus (TestStatusCode.Failure, e));
			}
			hasFailures = true;
		}

		protected virtual void AddWarning (TestCase testCase, TestFailedException e)
		{
			if (testResult != null)
			{
				testResult.StatusNotify (testCase, new TestStatus (TestStatusCode.Warning, e));
			}
			hasWarnings = true;
		}

		private bool AreEqual (object expected, object actual)
		{
			if (expected == null)
				return actual == null;
			if (actual == null)
				return false;

			if (expected is System.Collections.IList && actual is System.Collections.IList)
			{
				System.Collections.IList expectedCollection = (System.Collections.IList) expected;
				System.Collections.IList actualCollection = (System.Collections.IList) actual;
				int expectedLength = expectedCollection.Count;
				int actualLength = actualCollection.Count;
				if (expectedLength != actualLength)
					return false;
				for (int i = 0; i < expectedLength; i++)
				{
					if (!AreEqual (expectedCollection[i], actualCollection[i]))
						return false;
				}
				return true;
			}

			return expected.Equals (actual);
		}

		private string ConcatMessages (string m1, string m2)
		{
			if (m2 == null)
				return m1;
			if (m1 == null)
				return m2;
			return m1 + Environment.NewLine + m2;
		}
	}
}

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
	public class ComparisonException : TestFailedException
	{
		private object expectedValue;
		private object actualValue;

		public ComparisonException ()
		{
		}

		public ComparisonException (string message)
			: base (message)
		{
		}

		public ComparisonException (string message, object expected, object actual)
			: base (message)
		{
			this.expectedValue = expected;
			this.actualValue = actual;
		}

		public override string Message
		{
			get
			{
				string message = base.Message;
				if (message == null)
					message = "Comparison failed.";
				if (expectedValue != null)
				{
					message += Environment.NewLine + "Expected value: "	+ expectedValue.GetType () + " <";
					if (expectedValue is ICollection)
					{
						bool firstElt = true;
						ICollection collection = (ICollection) expectedValue;
						foreach (object elt in collection)
						{
							if (firstElt)
								firstElt = false;
							else
								message += ", ";
							message += elt.ToString ();
						}
					}
					else
					{
						message += expectedValue.ToString ();
					}
					message += ">";
				}
				if (actualValue != null)
				{
					message += Environment.NewLine + "Actual value was: " + actualValue.GetType () + " <";
					if (actualValue is ICollection)
					{
						bool firstElt = true;
						ICollection collection = (ICollection) actualValue;
						foreach (object elt in collection)
						{
							if (firstElt)
								firstElt = false;
							else
								message += ", ";
							message += elt.ToString ();
						}
					}
					else
					{
						message += actualValue.ToString ();
					}
					message += ">";
				}
				return message;
			}
		}

		public object ExpectedValue
		{
			get { return expectedValue; }
		}

		public object ActualValue
		{
			get { return actualValue; }
		}
	}
}

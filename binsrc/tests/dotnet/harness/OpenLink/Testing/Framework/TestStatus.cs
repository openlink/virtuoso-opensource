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

namespace OpenLink.Testing.Framework
{
	public class TestStatus
	{
		private TestStatusCode code;
		private string text;
		private Exception exception;

		public TestStatus (TestStatusCode code)
			: this (code, null, null)
		{
		}

		public TestStatus (TestStatusCode code, string text)
			: this (code, text, null)
		{
		}

		public TestStatus (TestStatusCode code, Exception exception)
			: this (code, null, exception)
		{
		}

		public TestStatus (TestStatusCode code, string text, Exception exception)
		{
			this.code = code;
			this.text = text;
			this.exception = exception;
		}

		public TestStatusCode Code
		{
			get { return code; }
		}

		public string Text
		{
			get { return text; }
		}

		public Exception Exception
		{
			get { return exception; }
		}

		public override string ToString ()
		{
			string status;
			switch (code)
			{
			case TestStatusCode.Skipped:
				status = "Skipped";
				break;
			case TestStatusCode.Warning:
				status = "Warning";
				break;
			case TestStatusCode.Failure:
				status = "Failure";
				break;
			case TestStatusCode.Error:
				status = "Error";
				break;
			default:
				status = "UNKNOWN STATUS";
				break;
			}
			return (status
				+ (text == null ? "" : (": " + text))
				+ (exception == null ? "" : (":" + Environment.NewLine + exception)));
		}
	}
}

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
using OpenLink.Testing.Framework;
using OpenLink.Testing.Util;

namespace VirtuosoClientSuite
{
	/// <summary>
	/// </summary>
	public class VirtuosoClientTests
	{
		public static ITest Suite
		{
			get
			{
				TestSuite suite = new TestSuite ("VirtuosoClient tests");
				suite.AddTestSuite (typeof (ConnectionTest));
				suite.AddTestSuite (typeof (CommandTest));
				suite.AddTestSuite (typeof (CommandBuilderTest));
				suite.AddTestSuite (typeof (TransactionTest));
				suite.AddTestSuite (typeof (BlobTest));
				suite.AddTestSuite (typeof (SqlXmlTest));
				return suite;
			}
		}
	}
}

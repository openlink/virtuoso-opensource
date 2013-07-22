//  
//  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
//  project.
//  
//  Copyright (C) 1998-2013 OpenLink Software
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
//
// $Id$
//

using System;

#if ODBC_CLIENT
namespace OpenLink.Data.VirtuosoOdbcClient
#elif CLIENT
namespace OpenLink.Data.VirtuosoClient
#else
namespace OpenLink.Data.Virtuoso
#endif
{
	internal class Service
	{
		internal class Argument
		{
			internal BoxTag type;
			internal bool nullable;

			internal Argument (BoxTag type, bool nullable)
			{
				this.type = type;
				this.nullable = nullable;
			}
		}

		internal string name;
		internal Argument[] arguments;

		private Service (string name, Argument[] arguments)
		{
			this.name = name;
			this.arguments = arguments;
		}

		internal static Service CallerId = new Service (
			"caller_identification",
			new Argument[] {
					       new Argument (BoxTag.DV_C_STRING, true)
				       }
			);

		internal static Service Cancel = new Service (
			"CANCEL",
			new Argument[0]
			);

		internal static Service Connect = new Service (
			"SCON",
			new Argument[] {
					       new Argument (BoxTag.DV_C_STRING, true),
					       new Argument (BoxTag.DV_SHORT_STRING, true),
					       new Argument (BoxTag.DV_C_STRING, true),
					       new Argument (BoxTag.DV_ARRAY_OF_POINTER, true)
				       }
			);

		internal static Service Transaction = new Service (
			"TRXC",
			new Argument[] {
					       new Argument (BoxTag.DV_LONG_INT, true),
					       new Argument (BoxTag.DV_LONG_INT, true)
				       }
			);

		internal static Service Prepare = new Service (
			"PREP",
			new Argument[] {
					       new Argument (BoxTag.DV_SHORT_STRING, false),
					       new Argument (BoxTag.DV_SHORT_STRING, false),
					       new Argument (BoxTag.DV_LONG_INT, true),
					       new Argument (BoxTag.DV_ARRAY_OF_LONG, true)
				       }
			);

		internal static Service Execute = new Service (
			"EXEC",
			new Argument[] {
					       new Argument (BoxTag.DV_SHORT_STRING, false),	// id
					       new Argument (BoxTag.DV_SHORT_STRING, true),	// text
					       new Argument (BoxTag.DV_SHORT_STRING, true),	// cursor name
					       new Argument (BoxTag.DV_ARRAY_OF_POINTER, false),// params
					       new Argument (BoxTag.DV_ARRAY_OF_POINTER, true),	// current ofs
					       new Argument (BoxTag.DV_ARRAY_OF_LONG, true)	// options
				       }
			);

		internal static Service Fetch = new Service (
			"FTCH",
			new Argument[] {
					       new Argument (BoxTag.DV_SHORT_STRING, false),
					       new Argument (BoxTag.DV_LONG_INT, true)
				       }
			);

		internal static Service FreeStmt = new Service (
			"FRST",
			new Argument[] {
					       new Argument (BoxTag.DV_SHORT_STRING, false),
					       new Argument (BoxTag.DV_LONG_INT, true)
				       }
			);

		internal static Service GetData = new Service (
			"GETDA",
			new Argument[] {
					       new Argument (BoxTag.DV_LONG_INT, true), // page no
					       new Argument (BoxTag.DV_LONG_INT, true), // how much
					       new Argument (BoxTag.DV_LONG_INT, true), // pos in page
					       new Argument (BoxTag.DV_LONG_INT, true), // key id
					       new Argument (BoxTag.DV_LONG_INT, true), // frag no
					       new Argument (BoxTag.DV_LONG_INT, true), // page dir 1st page
					       new Argument (BoxTag.DV_LONG_STRING, true), // array of page
					       new Argument (BoxTag.DV_LONG_INT, true), // is wide
					       new Argument (BoxTag.DV_LONG_INT, true)  // timestamp
				       }
			);

		internal static Service TransactionEnlist = new Service (
			"TPTRX",
			new Argument[] {
					       new Argument (BoxTag.DV_LONG_INT, true),
					       new Argument (BoxTag.DV_STRING, true)
				       }
			);
	}
}

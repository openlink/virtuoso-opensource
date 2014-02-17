//  
//  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
//  project.
//  
//  Copyright (C) 1998-2014 OpenLink Software
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
using System.Data;

#if ODBC_CLIENT
namespace OpenLink.Data.VirtuosoOdbcClient
#elif CLIENT
namespace OpenLink.Data.VirtuosoClient
#else
namespace OpenLink.Data.Virtuoso
#endif
{
	interface IInnerCommand : IDisposable
	{
		void Cancel ();

		void SetTimeout (int timeout);

		void SetCommandBehavior (CommandBehavior behavior);

		void SetParameters (VirtuosoParameterCollection parameters);
		void GetParameters ();

		void Execute (string query);
		void Prepare (string query);
		void Execute ();
		bool Fetch ();
		bool GetNextResult ();
		void CloseCursor (bool isExecuted);

		int GetRowCount ();
		ColumnData[] GetColumnMetaData ();
		object GetColumnData (int i, ColumnData[] columns);

		bool IsDBNull (int i, ColumnData[] columns);
		long GetChars (int i, ColumnData[] columns, long fieldOffset,
			char[] buffer, int bufferOffset, int length);
		long GetBytes (int i, ColumnData[] columns, long fieldOffset,
			byte[] buffer, int bufferOffset, int length);

		void GetProcedureColumns (string text);
	}
}

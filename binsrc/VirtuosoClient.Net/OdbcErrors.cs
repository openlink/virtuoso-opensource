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
//
// $Id$
//

using System;
using System.Diagnostics;
using System.Runtime.InteropServices;

#if ODBC_CLIENT
namespace OpenLink.Data.VirtuosoOdbcClient
#elif CLIENT
namespace OpenLink.Data.VirtuosoClient
#else
namespace OpenLink.Data.Virtuoso
#endif
{
	internal class OdbcErrors
	{
		private OdbcErrors () {}

		internal static VirtuosoErrorCollection CreateErrors (CLI.HandleType handleType, IntPtr handle)
		{
			VirtuosoErrorCollection errors = new VirtuosoErrorCollection ();

			MemoryHandle sqlState = null;
			MemoryHandle messageText = null;
			try
			{
				sqlState = new MemoryHandle ((CLI.SQL_SQLSTATE_SIZE + 1) * Platform.WideCharSize);
				messageText = new MemoryHandle ((CLI.SQL_MAX_MESSAGE_LEN + 1) * Platform.WideCharSize);

				for (short recNumber = 1; ;recNumber++)
				{
					int nativeError;
					short textLength;
					CLI.ReturnCode rc = (CLI.ReturnCode) CLI.SQLGetDiagRec (
						(short) handleType,
						handle,
						recNumber,
						sqlState.Handle,
						out nativeError,
						messageText.Handle,
						(short) (messageText.Length / Platform.WideCharSize),
						out textLength);
					if (rc != CLI.ReturnCode.SQL_SUCCESS && rc != CLI.ReturnCode.SQL_SUCCESS_WITH_INFO)
						break;

#if false
					//System.Console.WriteLine ("length: {0}", textLength);
					string sMessageText = Platform.WideCharsToString (messageText.Handle, textLength);
					string sSqlState = Platform.WideCharsToString (sqlState.Handle, CLI.SQL_SQLSTATE_SIZE);
#else
					string sMessageText = Marshal.PtrToStringAnsi (messageText.Handle, textLength);
					string sSqlState = Marshal.PtrToStringAnsi (sqlState.Handle, CLI.SQL_SQLSTATE_SIZE);
#endif
					VirtuosoError error = new VirtuosoError (sMessageText, sSqlState);
					errors.Add (error);
				}
			} 
			finally 
			{
				if (sqlState != null)
					sqlState.Dispose ();
				if (messageText != null)
					messageText.Dispose ();
			}

			return errors;
		}
	}
}

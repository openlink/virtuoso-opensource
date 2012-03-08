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
//
// $Id$
//

using System;
using System.Text;
using System.Runtime.InteropServices;
using System.Data;

#if ODBC_CLIENT
namespace OpenLink.Data.VirtuosoOdbcClient
#elif CLIENT
namespace OpenLink.Data.VirtuosoClient
#else
namespace OpenLink.Data.Virtuoso
#endif
{
	internal sealed class Diagnostics
	{
		private Diagnostics () {}

		internal static void HandleResult (
			CLI.ReturnCode returnCode,
			ICreateErrors source,
			IDbConnection connection)
		{
			if (returnCode == CLI.ReturnCode.SQL_SUCCESS_WITH_INFO)
				HandleWarnings (source, connection);
			else if (returnCode != CLI.ReturnCode.SQL_SUCCESS)
				HandleErrors (returnCode, source);
		}

		internal static void HandleErrors (CLI.ReturnCode returnCode, ICreateErrors source)
		{
			VirtuosoErrorCollection errors = null;
			if (returnCode == CLI.ReturnCode.SQL_ERROR)
				errors = source.CreateErrors ();
			else
				errors = CreateErrors (returnCode);
			throw new VirtuosoException (returnCode, errors);
		}

		internal static void HandleWarnings (ICreateErrors source, IDbConnection connection)
		{
			VirtuosoErrorCollection errors = source.CreateErrors ();
			VirtuosoInfoMessageEventArgs args = new VirtuosoInfoMessageEventArgs (errors);
			((VirtuosoConnection)connection).OnInfoMessage (args);
		}

		private static VirtuosoErrorCollection CreateErrors (CLI.ReturnCode rc)
		{
			string message = null;
			switch (rc)
			{
			case CLI.ReturnCode.SQL_INVALID_HANDLE:
				message = "Invalid Handle";
				break;
			case CLI.ReturnCode.SQL_NEED_DATA:
				message = "Need Data";
				break;
			case CLI.ReturnCode.SQL_STILL_EXECUTING:
				message = "Still Executing";
				break;
			default:
				message = "Unexpected Return Code";
				break;
			}

			VirtuosoErrorCollection errors = new VirtuosoErrorCollection ();
			VirtuosoError error = new VirtuosoError (message, "");
			errors.Add (error);
			return errors;
		}

#if UNMANAGED_ODBC
		// deprecated
		internal static void HandleResult (
			CLI.ReturnCode returnCode,
			CLI.HandleType handleType,
			IntPtr handle,
			VirtuosoConnection connection)
		{
			if (returnCode == CLI.ReturnCode.SQL_SUCCESS_WITH_INFO)
				HandleWarnings (handleType, handle, connection);
			else if (returnCode != CLI.ReturnCode.SQL_SUCCESS)
				HandleErrors (returnCode, handleType, handle);
		}

		// deprecated
		internal static void HandleErrors (
			CLI.ReturnCode returnCode,
			CLI.HandleType handleType,
			IntPtr handle)
		{
			VirtuosoErrorCollection errors = null;
			if (returnCode == CLI.ReturnCode.SQL_ERROR)
				errors = OdbcErrors.CreateErrors (handleType, handle);
			else
				errors = CreateErrors (returnCode);
			throw new VirtuosoException (returnCode, errors);
		}

		// deprecated
		internal static void HandleWarnings (
			CLI.HandleType handleType,
			IntPtr handle,
			VirtuosoConnection connection)
		{
			VirtuosoInfoMessageEventArgs args = new VirtuosoInfoMessageEventArgs (OdbcErrors.CreateErrors (handleType, handle));
			connection.OnInfoMessage (args);
		}
#endif
	}
}

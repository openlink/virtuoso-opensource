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
using System.Collections;
using System.Diagnostics;

#if ODBC_CLIENT
namespace OpenLink.Data.VirtuosoOdbcClient
#elif CLIENT
namespace OpenLink.Data.VirtuosoClient
#else
namespace OpenLink.Data.Virtuoso
#endif
{
	internal class ManagedErrors
	{
		private VirtuosoErrorCollection errors = null;

		internal void AddServerError (string state, string virtState, string message)
		{
			string message2;
			if (message != null)
				message2 = "[Virtuoso Server]" + message;
			else
				message2 = null;
			AddError (state, virtState, message2);
		}

		internal void AddServerWarning (string state, string virtState, string message)
		{
			string message2;
			if (message != null)
				message2 = "[Virtuoso Server]" + message;
			else
				message2 = null;
			AddWarning (state, virtState, message2);
		}

		internal void AddError (string state, string virtState, string message)
		{
			string message2;
			if (virtState != null)
			{
				if (message != null)
					message2 = "[Virtuoso .NET Data Provider]" + virtState + ": " + message;
				else
					message2 = "[Virtuoso .NET Data Provider]" + virtState + ": ";
			}
			else
			{
				if (message != null)
					message2 = "[Virtuoso .NET Data Provider]" + message;
				else
					message2 = "[Virtuoso .NET Data Provider]Unknown error.";
			}
			AddError (state, message2);
		}

		internal void AddWarning (string state, string virtState, string message)
		{
			string message2;
			if (virtState != null)
			{
				if (message != null)
					message2 = "[Virtuoso .NET Data Provider]" + virtState + ": " + message;
				else
					message2 = "[Virtuoso .NET Data Provider]" + virtState + ": ";
			}
			else
			{
				if (message != null)
					message2 = "[Virtuoso .NET Data Provider]" + message;
				else
					message2 = "[Virtuoso .NET Data Provider]Unknown error.";
			}
			AddWarning (state, message2);
		}

		internal void AddError (string state, string message)
		{
			Debug.WriteLineIf (CLI.FnTrace.Enabled, "ManagedErrors.AddError (state = '" + state + "', message = '" + message + "')");
			if (errors == null)
				errors = new VirtuosoErrorCollection ();
			errors.Add (new VirtuosoError (message, state));
		}

		internal void AddWarning (string state, string message)
		{
			Debug.WriteLineIf (CLI.FnTrace.Enabled, "ManagedErrors.Warning (state = '" + state + "', message = '" + message + "')");
			if (errors == null)
				errors = new VirtuosoErrorCollection ();
			errors.Add (new VirtuosoWarning (message, state));
		}
		internal void Clear ()
		{
			errors = null;
		}

		internal VirtuosoErrorCollection CreateErrors ()
		{
			return errors;
		}
	}
}

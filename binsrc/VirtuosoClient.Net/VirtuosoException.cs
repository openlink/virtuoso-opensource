//  
//  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
//  project.
//  
//  Copyright (C) 1998-2016 OpenLink Software
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
using System.Data.Common;
using System.Text;
using System.Runtime.InteropServices;

#if ODBC_CLIENT
namespace OpenLink.Data.VirtuosoOdbcClient
#elif CLIENT
namespace OpenLink.Data.VirtuosoClient
#else
namespace OpenLink.Data.Virtuoso
#endif
{
	/// <summary>
	/// Summary description for VirtuosoException.
	/// </summary>
#if ADONET2
	public sealed class VirtuosoException : DbException
#else
	public sealed class VirtuosoException : SystemException
#endif
	{
		CLI.ReturnCode returnCode;
		VirtuosoErrorCollection errors;

		internal VirtuosoException (CLI.ReturnCode returnCode, VirtuosoErrorCollection errors)
		{
			this.returnCode = returnCode;
			this.errors = errors;
		}

		public VirtuosoErrorCollection Errors
		{
			get { return errors; }
		}

		public override string Message
		{
			get
			{
				StringBuilder sb = new StringBuilder();
				sb.Append("Virtuoso Error: ");
				sb.Append(returnCode);
				sb.Append(Environment.NewLine);
				if (errors.Count > 0)
				{
					IVirtuosoError error = errors[0];
					sb.Append("SQLSTATE: ");
					sb.Append(error.SQLState);
					sb.Append(Environment.NewLine);
					sb.Append("Message: ");
					sb.Append(error.Message);
					sb.Append(Environment.NewLine);
				}
				return sb.ToString();
			}
		}
	}
}

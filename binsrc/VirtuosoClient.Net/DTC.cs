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
using System.EnterpriseServices;
using System.Runtime.InteropServices;

#if ODBC_CLIENT
namespace OpenLink.Data.VirtuosoOdbcClient
#elif CLIENT
namespace OpenLink.Data.VirtuosoClient
#else
namespace OpenLink.Data.Virtuoso
#endif
{
	internal sealed class DTC
	{
		internal static ITransactionExport GetTransactionExport (ITransaction transaction, byte[] whereabouts)
		{
			if (transaction == null || whereabouts == null)
				return null;

			IGetDispenser pIGetDispenser = transaction as IGetDispenser;
			if (pIGetDispenser == null)
				return null;

			object dispenser = null;
			Guid iid_ITransactionDispenser = new Guid ("3A6AD9E1-23B9-11cf-AD60-00AA00A74CCD");
			pIGetDispenser.GetDispenser (ref iid_ITransactionDispenser, out dispenser);
			ITransactionExportFactory factory = dispenser as ITransactionExportFactory;
			if (factory == null)
				return null;

			object export = null;
			factory.Create ((uint) whereabouts.Length, whereabouts, out export);
			return (ITransactionExport) export;
		}

		internal static byte[] GetTransactionCookie (ITransaction transaction, ITransactionExport export)
		{
			uint size;
			export.Export (transaction, out size);

			uint length;
			byte[] cookie = new byte[size];
			export.GetTransactionCookie (transaction, size, cookie, out length);

			return cookie;
		}

		[InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
		[Guid ("c23cc370-87ef-11ce-8081-0080c758527e")]
		internal interface IGetDispenser
		{
			void GetDispenser (
				[In] ref Guid iid,
				[Out, MarshalAs (UnmanagedType.IUnknown)] out object ppvObject
				);
		}

		[InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
		[Guid ("E1CF9B53-8745-11ce-A9BA-00AA006C3706")]
		internal interface ITransactionExportFactory
		{
			void GetRemoteClassId (
				[Out] out Guid pclsid
				);

			void Create (
				[In] uint cbWhereabouts,
				[In, MarshalAs (UnmanagedType.LPArray)] byte[] rgbWhereabouts,
				[Out, MarshalAs (UnmanagedType.IUnknown)] out object ppExport
				);
		}

		[InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
		[Guid ("0141fda5-8fc0-11ce-bd18-204c4f4f5020")]
		internal interface ITransactionExport
		{
			void Export (
				[In, MarshalAs (UnmanagedType.IUnknown)] object pUnkTransaction,
				[Out] out uint pcbTransactionCookie
				);

			void GetTransactionCookie (
				[In, MarshalAs (UnmanagedType.IUnknown)] object pUnkTransaction,
				[In] uint cbTransactionCookie,
				[Out, MarshalAs (UnmanagedType.LPArray)] byte[] rgbTransactionCookie,
				[Out] out uint pcbUsed
				);

			void RemoteGetTransactionCookie (
				[In, MarshalAs (UnmanagedType.IUnknown)] object pUnkTransaction,
				[Out] out uint pcbUsed,
				[In] uint cbTransactionCookie,
				[Out, MarshalAs (UnmanagedType.LPArray)] byte[] rgbTransactionCookie
				);
		}
	}
}

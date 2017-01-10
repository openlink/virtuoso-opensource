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
// 
// $Id$
//

using System;
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
	/// Native heap buffer.
	/// </summary>
	internal sealed class MemoryHandle : IDisposable
	{
		int length;
		IntPtr handle;

		internal MemoryHandle (int length)
		{
			this.length = length;
			this.handle = IntPtr.Zero;
		}

		~MemoryHandle ()
		{
			Dispose (false);
		}

		public void Dispose ()
		{
			Dispose (true);
			GC.SuppressFinalize (this);
		}

		private void Dispose (bool disposing)
		{
			if (handle != IntPtr.Zero)
			{
				Platform.MarshalFree (handle);
				handle = IntPtr.Zero;
			}
			GC.KeepAlive (this);
		}

		internal void Reserve (int length)
		{
			if (handle != IntPtr.Zero)
				handle = Platform.MarshalReAlloc (handle, length);
			this.length = length;
			GC.KeepAlive (this);
		}

		internal int Length
		{
			get { return length; }
		}

		internal IntPtr Handle
		{
			get
			{
				if (handle == IntPtr.Zero)
					handle = Platform.MarshalAlloc (length);
				return handle;
			}
		}

		internal IntPtr GetAddress (int offset)
		{
			return (System.IntPtr.Size == 8)
				? (IntPtr) ((System.Int64) Handle + offset)
				: (IntPtr) ((System.Int32) Handle + offset);
		}
	}
}

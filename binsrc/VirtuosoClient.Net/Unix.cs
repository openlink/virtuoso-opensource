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
//
// $Id$
//

using System;
using System.Runtime.InteropServices;
using System.Text;

#if ODBC_CLIENT
namespace OpenLink.Data.VirtuosoOdbcClient
#elif CLIENT
namespace OpenLink.Data.VirtuosoClient
#else
namespace OpenLink.Data.Virtuoso
#endif
{
	internal sealed class UnixMono : PlatformBase
	{
		public override IntPtr MarshalAlloc (int size)
		{
			return Marshal.AllocHGlobal (size);
		}

		public override IntPtr MarshalReAlloc (IntPtr handle, int size)
		{
			return Marshal.ReAllocHGlobal (handle, (IntPtr) size);
		}

		public override void MarshalFree (IntPtr handle)
		{
			Marshal.FreeHGlobal (handle);
		}

		public override int WideCharSize
		{
			get { return 4; }
		}

		public override int StringToWideChars (string source, IntPtr buffer, int length)
		{
			length /= 4;

			int size = source.Length;
			if (size > length - 1)
				size = length - 1;

			for (int i = 0; i < size; i++)
			{
				int c = (int) source[i];
				Marshal.WriteInt32 (buffer, i * 4, c);
			}
			Marshal.WriteInt32 (buffer, size * 4, 0);

			return size * 4;
		}

		public override string WideCharsToString (IntPtr buffer, int length)
		{
			length /= 4;

			StringBuilder sb = new StringBuilder (length);
			for (int i = 0; i < length; i++)
			{
				int c = Marshal.ReadInt32 (buffer, i * 4);
				sb.Append (c < UInt16.MaxValue ? (char) c : '?');
			}

			return sb.ToString ();
		}

		public override char[] WideCharsToArray (IntPtr buffer, int length)
		{
			length /= 4;

			char[] chars = new char[length];
			for (int i = 0; i < length; i++)
			{
				int c = Marshal.ReadInt32 (buffer, i * 4);
				chars[i] = (c < UInt16.MaxValue ? (char) c : '?');
			}

			return chars;
		}

		public override int CaseInsensitiveCompare (string strA, string strB)
		{
			return String.Compare (strA, strB, true);
		}
	}
}

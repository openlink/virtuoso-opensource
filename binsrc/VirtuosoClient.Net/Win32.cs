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
using System.Diagnostics;
using System.Globalization;
using System.Runtime.InteropServices;

#if ODBC_CLIENT
namespace OpenLink.Data.VirtuosoOdbcClient
#elif CLIENT
namespace OpenLink.Data.VirtuosoClient
#else
namespace OpenLink.Data.Virtuoso
#endif
{
	internal abstract class Win32Base : PlatformBase
	{
		public override int WideCharSize
		{
			get { return 2; }
		}

		public override int StringToWideChars (string source, IntPtr buffer, int length)
		{
			length /= 2;

			int size = source.Length;
			if (size > length - 1)
				size = length - 1;

			Marshal.Copy (source.ToCharArray (), 0, buffer, size);
			Marshal.WriteInt16 (buffer, size * 2, 0);

			return size * 2;
		}

		public override string WideCharsToString (IntPtr buffer, int length)
		{
			length /= 2;
			return Marshal.PtrToStringUni (buffer, length);
		}

		public override char[] WideCharsToArray (IntPtr buffer, int length)
		{
			length /= 2;
			char[] chars = new char[length];
			Marshal.Copy (buffer, chars, 0, length);
			return chars;
		}

#if WIN32_ONLY
		public override IntPtr GetDesktopWindow ()
		{
			return PI_GetDesktopWindow ();
		}

		public override IntPtr GetForegroundWindow ()
		{
			return PI_GetForegroundWindow ();
		}

		[DllImport("user32.dll", EntryPoint="GetDesktopWindow")]
		private static extern IntPtr PI_GetDesktopWindow ();

		[DllImport("user32.dll", EntryPoint="GetForegroundWindow")]
		private static extern IntPtr PI_GetForegroundWindow ();
#endif

#if WIN32_FINALIZERS
		public override int InterlockedExchange (IntPtr target, int value)
		{
			return PI_InterlockedExchange (target, value);
		}

		public override int InterlockedIncrement (IntPtr target)
		{
			return PI_InterlockedIncrement (target);
		}

		public override int InterlockedDecrement (IntPtr target)
		{
			return PI_InterlockedDecrement (target);
		}

		[DllImport("kernel32.dll", EntryPoint="InterlockedExchange")]
		private static extern int PI_InterlockedExchange (IntPtr target, int value);

		[DllImport("kernel32.dll", EntryPoint="InterlockedIncrement")]
		private static extern int PI_InterlockedIncrement (IntPtr target);

		[DllImport("kernel32.dll", EntryPoint="InterlockedDecrement")]
		private static extern int PI_InterlockedDecrement (IntPtr target);
#endif
	}

	internal sealed class Win32DotNet : Win32Base
	{
		public override int CaseInsensitiveCompare (string strA, string strB)
		{
			return CultureInfo.CurrentCulture.CompareInfo.Compare (strA, strB, CompareOptions.IgnoreKanaType | CompareOptions.IgnoreWidth | CompareOptions.IgnoreCase);
		}

		public override bool HasDtc ()
		{
			return true;
		}
	}

	internal sealed class Win32Mono : Win32Base
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

		public override int CaseInsensitiveCompare (string strA, string strB)
		{
			return String.Compare (strA, strB, true);
		}
	}
}

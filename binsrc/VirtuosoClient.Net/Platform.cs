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
	internal interface IPlatform
	{
		IntPtr MarshalAlloc (int size);

		IntPtr MarshalReAlloc (IntPtr handle, int size);

		void MarshalFree (IntPtr handle);

		int WideCharSize { get;	}

		int StringToWideChars (string source, IntPtr buffer, int length);

		string WideCharsToString (IntPtr buffer, int length);

		char[] WideCharsToArray (IntPtr buffer, int length);

		int CaseInsensitiveCompare (string strA, string strB);

		IntPtr GetDesktopWindow ();

		IntPtr GetForegroundWindow ();

#if WIN32_FINALIZERS
		int InterlockedExchange (IntPtr target, int value);

		int InterlockedIncrement (IntPtr target);

		int InterlockedDecrement (IntPtr target);
#endif

		bool HasDtc ();
	}

	internal abstract class PlatformBase : IPlatform
	{
		public virtual IntPtr MarshalAlloc (int size)
		{
			return Marshal.AllocCoTaskMem (size);
		}

		public virtual IntPtr MarshalReAlloc (IntPtr handle, int size)
		{
			return Marshal.ReAllocCoTaskMem (handle, size);
		}

		public virtual void MarshalFree (IntPtr handle)
		{
			Marshal.FreeCoTaskMem (handle);
		}

		public abstract int WideCharSize { get;	}

		public abstract int StringToWideChars (string source, IntPtr buffer, int length);

		public abstract string WideCharsToString (IntPtr buffer, int length);

		public abstract char[] WideCharsToArray (IntPtr buffer, int length);

		public abstract int CaseInsensitiveCompare (string strA, string strB);

		public virtual IntPtr GetDesktopWindow ()
		{
			return IntPtr.Zero;
		}

		public virtual IntPtr GetForegroundWindow ()
		{
			return IntPtr.Zero;
		}

#if WIN32_FINALIZERS
		public virtual int InterlockedExchange (IntPtr target, int value)
		{
			throw new NotSupportedException ();
		}

		public virtual int InterlockedIncrement (IntPtr target)
		{
			throw new NotSupportedException ();
		}

		public virtual int InterlockedDecrement (IntPtr target)
		{
			throw new NotSupportedException ();
		}
#endif

		public virtual bool HasDtc ()
		{
			return false;
		}
	}

	internal sealed class Platform
	{
		internal readonly static BooleanSwitch Switch = 
		    new BooleanSwitch ("VirtuosoClient.Platform", "Platform.cs");
		private static IPlatform platform;

		private Platform () {}

		internal static IPlatform GetPlatform ()
		{
			if (platform == null)
			{
			        bool is_unix = false;
				try
				  {
				    System.Reflection.Assembly ass = System.Reflection.Assembly.Load ("mscorlib");
				    if (null != ass.GetType ("Mono.Runtime", true))
				      is_unix = true;
				  }
				catch (Exception /*e*/)
				  {
				  }
				
				if (is_unix)
				{
					if (((int) Environment.OSVersion.Platform) == 128)
					{
						Debug.WriteLineIf (Switch.Enabled, "Platform: Mono on Unix");
						platform = new UnixMono ();
					}
					else
					{
						platform = new Win32Mono ();
						Debug.WriteLineIf (Switch.Enabled, "Platform: Mono on Win32");
					}
				}
				else
				{
					platform = new Win32DotNet ();
					Debug.WriteLineIf (Switch.Enabled, "Platform: MSFT.NET");
				}
			}
			return platform;
		}

		internal static IntPtr MarshalAlloc (int size)
		{
			return GetPlatform () . MarshalAlloc (size);
		}

		internal static IntPtr MarshalReAlloc (IntPtr handle, int size)
		{
			return GetPlatform () . MarshalReAlloc (handle, size);
		}

		internal static void MarshalFree (IntPtr handle)
		{
			GetPlatform () . MarshalFree (handle);
		}

		internal static int WideCharSize
		{
			get { return GetPlatform () . WideCharSize; }
		}

		internal static int StringToWideChars (string source, IntPtr buffer, int length)
		{
			return GetPlatform () . StringToWideChars (source, buffer, length);
		}

		internal static string WideCharsToString (IntPtr buffer, int length)
		{
			return GetPlatform () . WideCharsToString (buffer, length);
		}

		internal static char[] WideCharsToArray (IntPtr buffer, int length)
		{
			return GetPlatform () . WideCharsToArray (buffer, length);
		}

		internal static int CaseInsensitiveCompare (string strA, string strB)
		{
			return GetPlatform () . CaseInsensitiveCompare (strA, strB);
		}

		internal static IntPtr GetDesktopWindow ()
		{
			return GetPlatform () . GetDesktopWindow ();
		}

		internal static IntPtr GetForegroundWindow ()
		{
			return GetPlatform () . GetForegroundWindow ();
		}

#if WIN32_FINALIZERS
		internal static int InterlockedExchange (IntPtr target, int value)
		{
			return GetPlatform () . InterlockedExchange (target, value);
		}

		internal static int InterlockedIncrement (IntPtr target)
		{
			return GetPlatform () . InterlockedIncrement (target);
		}

		internal static int InterlockedDecrement (IntPtr target)
		{
			return GetPlatform () . InterlockedDecrement (target);
		}
#endif

		internal static bool HasDtc ()
		{
			return GetPlatform () . HasDtc ();
		}
	}
}

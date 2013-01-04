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
using System.Collections;
using System.Collections.Specialized;
using System.Diagnostics;
using System.Threading;

#if ODBC_CLIENT
namespace OpenLink.Data.VirtuosoOdbcClient
#elif CLIENT
namespace OpenLink.Data.VirtuosoClient
#else
namespace OpenLink.Data.Virtuoso
#endif
{
	internal sealed class FutureList
	{
		internal readonly static BooleanSwitch Switch = 
		    new BooleanSwitch ("VirtuosoClient.FutureList", "Marshaling");
		internal IDictionary futures = new ListDictionary ();

		private bool read_lock = false;
		private ManualResetEvent read_event = new ManualResetEvent (true);

		internal bool ReadLock ()
		{
			//return (Interlocked.Exchange (ref read_lock, 1) == 0);
			lock (this)
			{
				if (read_lock)
					return false;
				read_lock = true;
				read_event.Reset ();
				return true;
			}
		}

		internal void ReadUnlock ()
		{
			//Interlocked.Exchange (ref read_lock, 0);
			lock (this)
			{
				read_lock = false;
				read_event.Set ();
			}
		}

		internal bool ReadWait (int timeout)
		{
			return read_event.WaitOne (timeout, false);
		}

		internal void Add (Future future)
		{
			Debug.Assert (future != null);
			Debug.WriteLineIf (CLI.FnTrace.Enabled, "Futures.Add ()");
			lock (futures)
			{
				futures.Add (future.RequestNo, future);
				Debug.WriteLineIf (Switch.Enabled, "add future: " + future.RequestNo);
			}
		}

		internal void Remove (Future future)
		{
			Debug.Assert (future != null);
			Debug.WriteLineIf (CLI.FnTrace.Enabled, "Futures.Remove ()");
			lock (futures)
			{
				futures.Remove (future.RequestNo);
				Debug.WriteLineIf (Switch.Enabled, "remove future: " + future.RequestNo);
			}
		}

		internal Future this[int id]
		{
			get
			{
				lock (futures)
				{
					return (Future) futures[id];
				}
			}
		}

		internal void Clear ()
		{
			lock (futures)
			{
				futures.Clear ();
			}
		}
	}
}

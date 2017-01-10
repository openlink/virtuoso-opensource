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

#if false

using System;
using System.Collections;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Threading;

#if ODBC_CLIENT
namespace OpenLink.Data.VirtuosoOdbcClient
#elif CLIENT
namespace OpenLink.Data.VirtuosoClient
#else
namespace OpenLink.Data.Virtuoso
#endif
{
	internal struct StatementList
	{
#if !WIN32_FINALIZERS

		private class Item
		{
			internal Item (IntPtr hstmt, VirtuosoCommand command)
			{
				this.hstmt = hstmt;
				this.weakCommand = command == null ? null : new WeakReference (command);
			}

			internal IntPtr hstmt;
			internal WeakReference weakCommand;
		};

		private ArrayList list;

#else

		// struct Head
		// {
		//	int spinlock;
		//	int refcount;
		//	int eltcount;
		//	IntPtr* elts;
		// };
		private const int INITIAL_ELT_COUNT = 16;
		private readonly static int ELT_SIZE = IntPtr.Size;
		private IntPtr head;
		private ArrayList commands;

#endif

		internal StatementList (int eltcount)
		{
#if !WIN32_FINALIZERS
			if (eltcount != 0)
				list = new ArrayList (eltcount);
			else
				list = new ArrayList ();
#else
			if (eltcount != 0)
				commands = new ArrayList (eltcount);
			else
				commands = new ArrayList ();

			int size = 12 + IntPtr.Size;
			head = Marshal.AllocCoTaskMem (size);
			Marshal.WriteInt32 (head, 0, 0);
			Marshal.WriteInt32 (head, 4, 0);
			Marshal.WriteInt32 (head, 8, 0);
			Marshal.WriteIntPtr (head, 12, IntPtr.Zero);
			if (eltcount > 0)
			{
				IntPtr elts = Marshal.AllocCoTaskMem (eltcount * ELT_SIZE);
				for (int i = 0; i < eltcount; i++)
					Marshal.WriteIntPtr (elts, i * ELT_SIZE, IntPtr.Zero);
				Marshal.WriteInt32 (head, 8, eltcount);
				Marshal.WriteIntPtr (head, 12, elts);
			}
			Reference ();
#endif
		}

		internal void Add (IntPtr hstmt, VirtuosoCommand command)
		{
			Debug.WriteLineIf (CLI.FnTrace.Enabled, "StatementList.Add (" + hstmt + ")");
#if !WIN32_FINALIZERS
			lock (list)
			{
				list.Add (new Item (hstmt, command));
				CloseFinalizedCommands ();
			}
#else
			if (command != null)
			{
				lock (commands)
				{
					commands.Add (new WeakReference (command));
				}
			}

			Lock ();
			int eltcount = Marshal.ReadInt32 (head, 8);
			IntPtr elts = Marshal.ReadIntPtr (head, 12);
			for (int i = 0; i < eltcount; i++)
			{
				IntPtr h = Marshal.ReadIntPtr (elts, i * ELT_SIZE);
				if (h == IntPtr.Zero)
				{
					Marshal.WriteIntPtr (elts, i * ELT_SIZE, hstmt);
					Unlock ();
					return;
				}
			}
			int neweltcount = eltcount == 0 ? INITIAL_ELT_COUNT : eltcount * 2;
			IntPtr newelts = Marshal.ReAllocCoTaskMem (elts, neweltcount * ELT_SIZE);
			for (int i = eltcount + 1; i < neweltcount; i++)
				Marshal.WriteIntPtr (newelts, i * ELT_SIZE, IntPtr.Zero);
			Marshal.WriteIntPtr (newelts, eltcount * ELT_SIZE, hstmt);
			Marshal.WriteInt32 (head, 8, neweltcount);
			Marshal.WriteIntPtr (head, 12, newelts);
			Unlock ();
#endif
		}

		internal bool Remove (IntPtr hstmt, VirtuosoCommand command)
		{
			Debug.WriteLineIf (CLI.FnTrace.Enabled, "StatementList.Remove (" + hstmt + ")");
#if !WIN32_FINALIZERS
			lock (list)
			{
				for (int i = 0; i < list.Count; i++)
				{
					Item item = (Item) list[i];
					if (item.hstmt == hstmt)
					{
						list.RemoveAt (i);
						CLI.SQLFreeHandle ((short) CLI.HandleType.SQL_HANDLE_STMT, hstmt);
					}
				}
				CloseFinalizedCommands ();
			}
#else
			if (commands != null)
			{
				lock (commands)
				{
					int i = 0;
					while (i < commands.Count)
					{
						WeakReference weak = (WeakReference) commands[i];
						VirtuosoCommand target = (VirtuosoCommand) weak.Target;
						if (target == null || target == command)
							commands.RemoveAt (i);
						else
							i++;
					}
				}
			}

			Lock ();
			int eltcount = Marshal.ReadInt32 (head, 8);
			IntPtr elts = Marshal.ReadIntPtr (head, 12);
			for (int i = 0; i < eltcount; i++)
			{
				IntPtr h = Marshal.ReadIntPtr (elts, i * ELT_SIZE);
				if (h == hstmt)
				{
					Marshal.WriteIntPtr (elts, i * ELT_SIZE, IntPtr.Zero);
					Unlock ();
					CLI.SQLFreeHandle ((short) CLI.HandleType.SQL_HANDLE_STMT, hstmt);
					return true;
				}
			}
			Unlock ();
#endif
			return false;
		}

		internal void CloseAll ()
		{
			Debug.WriteLineIf (CLI.FnTrace.Enabled, "StatementList.CloseAll ()");
#if !WIN32_FINALIZERS
			lock (list)
			{
				for (int i = 0; i < list.Count; i++)
				{
					Item item = (Item) list[i];
					VirtuosoCommand command = item.weakCommand == null ? null : (VirtuosoCommand) item.weakCommand.Target;
					if (command != null)
					{
						command.OnConnectionClose ();
						item.weakCommand = null;
					}
					else
					{
						CLI.SQLFreeHandle ((short) CLI.HandleType.SQL_HANDLE_STMT, item.hstmt);
					}
				}
				list.Clear ();
			}
#else
			if (commands != null)
			{
				lock (commands)
				{
					for (int i = 0; i < commands.Count; i++)
					{
						WeakReference weak = (WeakReference) commands[i];
						VirtuosoCommand target = (VirtuosoCommand) weak.Target;
						if (target != null)
						{
							target.OnConnectionClose ();
							weak.Target = null;
						}
					}
				}
				commands.Clear ();
			}

			FinalizeAll ();
#endif
		}

		internal void FinalizeAll ()
		{
#if !WIN32_FINALIZERS
			// no-op
#else
			Lock ();
			int eltcount = Marshal.ReadInt32 (head, 8);
			IntPtr elts = Marshal.ReadIntPtr (head, 12);
			for (int i = 0; i < eltcount; i++)
			{
				IntPtr hstmt = Marshal.ReadIntPtr (elts, i * ELT_SIZE);
				if (hstmt != IntPtr.Zero)
				{
					Marshal.WriteIntPtr (elts, i * ELT_SIZE, IntPtr.Zero);
					CLI.SQLFreeHandle ((short) CLI.HandleType.SQL_HANDLE_STMT, hstmt);
				}
			}
			Unlock ();
			//Unreference (list);
#endif
		}

#if !WIN32_FINALIZERS

		private void CloseFinalizedCommands ()
		{
			for (int i = 0; i < list.Count; i++)
			{
				Item item = (Item) list[i];
				if (item.weakCommand != null && item.weakCommand.Target == null)
				{
					IntPtr hstmt = item.hstmt;
					list.RemoveAt (i);
					CLI.SQLFreeHandle ((short) CLI.HandleType.SQL_HANDLE_STMT, hstmt);
				}
			}
		}

#else

		internal int Reference ()
		{
			Debug.WriteLineIf (CLI.FnTrace.Enabled, "StatementList.Reference ()");
			return Platform.InterlockedIncrement (GetAddress (4));
		}

		internal int Unreference ()
		{
			Debug.WriteLineIf (CLI.FnTrace.Enabled, "StatementList.Unreference ()");
			if (head != IntPtr.Zero)
			{
				int refcount = Platform.InterlockedDecrement (GetAddress (4));
				if (refcount == 0)
					Release ();
				return refcount;
			}
			return 0;
		}

		private void Lock ()
		{
			while (0 != Platform.InterlockedExchange (head, 1))
				Thread.Sleep (0);
		}

		private void Unlock ()
		{
			Platform.InterlockedExchange (head, 0);
		}

		private void Release ()
		{
			Debug.WriteLineIf (CLI.FnTrace.Enabled, "StatementList.Release ()");
			IntPtr elts = Marshal.ReadIntPtr (head, 12);
			if (elts != IntPtr.Zero)
				Marshal.FreeCoTaskMem (elts);
			Marshal.FreeCoTaskMem (head);
			head = IntPtr.Zero;
		}

		private IntPtr GetAddress (int offset)
		{
			return System.IntPtr.Size == 8
				? (IntPtr) ((System.Int64) head + offset)
				: (IntPtr) ((System.Int32) head + offset);
		}
#endif
	}
}
#endif

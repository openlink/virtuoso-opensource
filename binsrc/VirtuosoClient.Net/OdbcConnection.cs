//  
//  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
//  project.
//  
//  Copyright (C) 1998-2015 OpenLink Software
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
using System.Configuration;
using System.Diagnostics;
using System.EnterpriseServices;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;

#if ODBC_CLIENT
namespace OpenLink.Data.VirtuosoOdbcClient
#elif CLIENT
namespace OpenLink.Data.VirtuosoClient
#else
namespace OpenLink.Data.Virtuoso
#endif
{
	internal sealed class OdbcConnection : InnerConnectionBase, ICreateErrors, IDisposable
	{
		private static string driver = "OpenLink Virtuoso Driver";

		/// <summary>
		/// ODBC environment handle.
		/// </summary>
		private static IntPtr henv;

		/// <summary>
		/// connection count.
		/// </summary>
		private static int connections;

		/// <summary>
		/// ODBC connection handle.
		/// </summary>
		internal IntPtr hdbc;

		//
		// List of statements
		//
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

		static OdbcConnection ()
		{
#if MONO || !ADONET2
			string d = System.Configuration.ConfigurationSettings.AppSettings["driver"];
#else
			string d = System.Configuration.ConfigurationManager.AppSettings["driver"];
#endif
			if (d != null && d != "")
				driver = d;

			henv = IntPtr.Zero;
			connections = 0;
		}

		internal OdbcConnection ()
			: this (0)
		{
		}

		internal OdbcConnection (int eltcount)
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

		public VirtuosoErrorCollection CreateErrors ()
		{
			if (hdbc == IntPtr.Zero)
				return OdbcErrors.CreateErrors (CLI.HandleType.SQL_HANDLE_ENV, henv);
			else
				return OdbcErrors.CreateErrors (CLI.HandleType.SQL_HANDLE_DBC, hdbc);
		}

#if ADONET2
// jch todo
        public override string ServerVersion
        {
            get
            {
                string version = "";
                return version;
            }
        }

        public override string ServerName
        {
            get
            {
                string name = "";
                return name;
            }
        }

        public override CLI.IdentCase IdentCase
        {
            get
            {
                int caseMode = 0;
                if (caseMode == 2)
                  return CLI.IdentCase.SQL_IC_MIXED;
                else if (caseMode == 1)
                  return CLI.IdentCase.SQL_IC_UPPER;
                else
                  return CLI.IdentCase.SQL_IC_SENSITIVE;
            }
        }

        public override CLI.IdentCase QuotedIdentCase
        {
            get
            {
                return CLI.IdentCase.SQL_IC_SENSITIVE;
            }
        }

        public override string UserName
        {
            get
            {
                string username = "";
                return username;
            }
        }

#endif

		public override bool IsValid ()
		{
			Debug.WriteLineIf (CLI.FnTrace.Enabled, "OdbcConnection.IsValid ()");

			if (hdbc == IntPtr.Zero)
				return false;

			int value = 0, length;
			CLI.ReturnCode rc;
			unsafe
			{
				IntPtr valuePtr = new IntPtr (&value);
				rc = (CLI.ReturnCode) CLI.SQLGetConnectAttr (hdbc,
					(int) CLI.ConnectionAttribute.SQL_ATTR_CONNECTION_DEAD,
					valuePtr, (int) CLI.LengthCode.SQL_IS_UINTEGER, out length);
			}
			if (rc != CLI.ReturnCode.SQL_SUCCESS)
				return false;

			return (value == 0);
		}

		public override void Open (ConnectionOptions options)
		{
			Debug.WriteLineIf (CLI.FnTrace.Enabled, "OdbcConnection.Open ()");

			OnConnect ();
			try
			{
				Connect (options);
			}
			catch (Exception)
			{
				OnDisconnect ();
				throw;
			}
		}

		public override void Close ()
		{
			Debug.WriteLineIf (CLI.FnTrace.Enabled, "OdbcConnection.Close ()");

			//statementList.CloseAll ();
			CloseAll ();
			Disconnect ();
			OnDisconnect ();
		}

		public override void Pool ()
		{
			Debug.WriteLineIf (CLI.FnTrace.Enabled, "OdbcConnection.Pool ()");

			//statementList.CloseAll ();
			CloseAll ();
		}

		public override IInnerCommand CreateInnerCommand (VirtuosoCommand outerCommand)
		{
			IntPtr hstmt;

			CLI.ReturnCode rc = (CLI.ReturnCode) CLI.SQLAllocHandle (
				(short) CLI.HandleType.SQL_HANDLE_STMT,
				hdbc,
				out hstmt);
			if (rc != CLI.ReturnCode.SQL_SUCCESS)
				HandleConnectionErrors (rc);

			try
			{
				//statementList.Add (hstmt, outerCommand);
				Add (hstmt, outerCommand);
			}
			catch (Exception)
			{
				CLI.SQLFreeHandle ((short) CLI.HandleType.SQL_HANDLE_STMT, hstmt);
				throw;
			}

			GC.KeepAlive (this);
			return new OdbcCommand (hstmt, outerCommand);
		}

		public void DeleteInnerCommand (OdbcCommand odbcCommand, VirtuosoCommand outerCommand)
		{
			//statementList.Remove (odbcCommand.hstmt, outerCommand);
			Remove (odbcCommand.hstmt, outerCommand);
		}

		public override void BeginTransaction (CLI.IsolationLevel level)
		{
			CLI.ReturnCode rc = (CLI.ReturnCode) CLI.SQLSetConnectAttr (
				hdbc,
				(int) CLI.ConnectionAttribute.SQL_ATTR_AUTOCOMMIT,
				(IntPtr) (int) CLI.AutoCommit.SQL_AUTOCOMMIT_OFF,
				(int) CLI.LengthCode.SQL_IS_UINTEGER);
			if (rc != CLI.ReturnCode.SQL_SUCCESS)
				HandleConnectionErrors (rc);
			rc = (CLI.ReturnCode) CLI.SQLSetConnectAttr (
				hdbc,
				(int) CLI.ConnectionAttribute.SQL_ATTR_TXN_ISOLATION,
				(IntPtr) (int) level,
				(int) CLI.LengthCode.SQL_IS_UINTEGER);
			if (rc != CLI.ReturnCode.SQL_SUCCESS)
			{
				if (rc == CLI.ReturnCode.SQL_SUCCESS_WITH_INFO)
					Diagnostics.HandleWarnings (this, OuterConnection);
				else
				{
					try
					{
						Diagnostics.HandleErrors (rc, CLI.HandleType.SQL_HANDLE_DBC, hdbc);
					}
					finally
					{
						CLI.SQLSetConnectAttr (
							hdbc,
							(int) CLI.ConnectionAttribute.SQL_ATTR_AUTOCOMMIT,
							(IntPtr) (int) CLI.AutoCommit.SQL_AUTOCOMMIT_ON,
							(int) CLI.LengthCode.SQL_IS_UINTEGER);
					}
				}
			}

			GC.KeepAlive (this);
		}

		public override void EndTransaction (bool commit)
		{
			CLI.ReturnCode rc = (CLI.ReturnCode) CLI.SQLEndTran (
				(short) CLI.HandleType.SQL_HANDLE_DBC, hdbc,
				(short) (commit ? CLI.CompletionType.SQL_COMMIT : CLI.CompletionType.SQL_ROLLBACK));
			if (rc != CLI.ReturnCode.SQL_SUCCESS)
				HandleConnectionErrors (rc);

			rc = (CLI.ReturnCode) CLI.SQLSetConnectAttr (
				hdbc,
				(int) CLI.ConnectionAttribute.SQL_ATTR_AUTOCOMMIT,
				(IntPtr) (int) CLI.AutoCommit.SQL_AUTOCOMMIT_ON,
				(int) CLI.LengthCode.SQL_IS_UINTEGER);
			if (rc != CLI.ReturnCode.SQL_SUCCESS)
				HandleConnectionErrors (rc);

			GC.KeepAlive (this);
		}

		public override void Enlist (object distributedTransaction)
		{
			ITransaction transaction = (ITransaction) distributedTransaction;

			IntPtr pIUnknown = IntPtr.Zero;
			if (transaction != null)
				pIUnknown = Marshal.GetIUnknownForObject (transaction);

			CLI.ReturnCode rc = (CLI.ReturnCode) CLI.SQLSetConnectAttr (
				hdbc,
				(int) CLI.ConnectionAttribute.SQL_ATTR_ENLIST_IN_DTC,
				pIUnknown,
				(int) CLI.LengthCode.SQL_IS_POINTER);
			if (rc != CLI.ReturnCode.SQL_SUCCESS)
				HandleConnectionErrors (rc);

			GC.KeepAlive (this);
		}

		public override string GetCurrentCatalog ()
		{
			MemoryHandle buffer = new MemoryHandle ((CLI.SQL_MAX_COLUMN_NAME_LEN + 1) * Platform.WideCharSize);
			int length;
			CLI.ReturnCode rc = (CLI.ReturnCode) CLI.SQLGetConnectAttr (
				hdbc,
				(int) CLI.ConnectionAttribute.SQL_ATTR_CURRENT_CATALOG,
				buffer.Handle,
				buffer.Length,
				out length);
			if (rc != CLI.ReturnCode.SQL_SUCCESS)
				HandleConnectionErrors (rc);

			GC.KeepAlive (this);
			return Platform.WideCharsToString (buffer.Handle, length);
		}

		public override void SetCurrentCatalog (string name)
		{
			IntPtr buffer = IntPtr.Zero;
			try
			{
				int length = (name.Length + 1) * Platform.WideCharSize;
				buffer = Platform.MarshalAlloc (length);
				Platform.StringToWideChars (name, buffer, length);
				CLI.ReturnCode rc = (CLI.ReturnCode) CLI.SQLSetConnectAttr (
					hdbc,
					(int) CLI.ConnectionAttribute.SQL_ATTR_CURRENT_CATALOG,
					buffer,
					(int) CLI.LengthCode.SQL_NTS);
				if (rc != CLI.ReturnCode.SQL_SUCCESS)
					HandleConnectionErrors (rc);
			}
			finally
			{
				if (buffer != IntPtr.Zero)
					Platform.MarshalFree (buffer);
			}

			GC.KeepAlive (this);
		}

		internal void HandleConnectionErrors (CLI.ReturnCode rc)
		{
			Diagnostics.HandleResult (rc, this, OuterConnection);
		}

		private string GetOdbcString (ConnectionOptions options)
		{
			StringBuilder sb = new StringBuilder ("DRIVER={" + driver + "};");
			if (options.DataSource!= null)
				sb.AppendFormat ("HOST={0};", options.DataSource);
			if (options.UserId != null)
				sb.AppendFormat ("UID={0};", options.UserId);
			if (options.Password != null)
				sb.AppendFormat ("PWD={0};", options.Password);
			if (options.Database != null)
				sb.AppendFormat ("DATABASE={0};", options.Database);
			if (options.Charset != null)
				sb.AppendFormat ("CHARSET={0};", options.Charset);
			if (options.Encrypt != null)
				sb.AppendFormat ("ENCRYPT={0};", options.Encrypt);
			return sb.ToString ();
		}

		private void Connect (ConnectionOptions options)
		{
			Debug.WriteLineIf (CLI.FnTrace.Enabled, "OdbcConnection.Connect ()");

			string connectionString = GetOdbcString (options);

			CLI.ReturnCode rc = (CLI.ReturnCode) CLI.SQLAllocHandle (
				(short) CLI.HandleType.SQL_HANDLE_DBC,
				henv,
				out hdbc);
			if (rc != CLI.ReturnCode.SQL_SUCCESS)
				Diagnostics.HandleResult (rc, CLI.HandleType.SQL_HANDLE_ENV, henv, OuterConnection);

#if false
			IntPtr hwnd = Platform.GetDesktopWindow ();
#else
			IntPtr hwnd = Platform.GetForegroundWindow ();
#endif

#if WIDE_CHAR_CONNECT && !WIN32_ONLY
			MemoryHandle inBuffer = null;
#endif
			MemoryHandle outBuffer = null;
			try
			{
				short length;
				int bufferSize = (CLI.SQL_MAX_CONNECTION_STRING_LEN + 1) * Platform.WideCharSize;
				outBuffer = new MemoryHandle (bufferSize);

#if WIDE_CHAR_CONNECT && !WIN32_ONLY
				inBuffer = new MemoryHandle (bufferSize);
				Platform.StringToWideChars (connectionString, inBuffer, bufferSize);
				rc = (CLI.ReturnCode) CLI.SQLDriverConnect (
					hdbc, hwnd,
					inBuffer, (short) CLI.LengthCode.SQL_NTS,
					outBuffer.Handle, (short) outBuffer.Length, out length,
					(short) CLI.DriverCompletion.SQL_DRIVER_COMPLETE);
#else
				rc = (CLI.ReturnCode) CLI.SQLDriverConnect (
					hdbc, hwnd,
					connectionString, (short) CLI.LengthCode.SQL_NTS,
					outBuffer.Handle, (short) outBuffer.Length, out length,
					(short) CLI.DriverCompletion.SQL_DRIVER_COMPLETE);
#endif
				if (rc != CLI.ReturnCode.SQL_SUCCESS)
				{
					if (rc == CLI.ReturnCode.SQL_NO_DATA)
						throw new InvalidOperationException ("The connection was canceled by the user.");
					HandleConnectionErrors (rc);
				}

#if WIDE_CHAR_CONNECT
				connectionString = Platform.WideCharsToString (outBuffer.Handle, length);
#else
				connectionString = Marshal.PtrToStringAnsi (outBuffer.Handle, length);
#endif	
			}
			catch (Exception)
			{
				CLI.SQLFreeHandle ((short) CLI.HandleType.SQL_HANDLE_DBC, hdbc);
				hdbc = IntPtr.Zero;
				throw;
			}
			finally
			{
#if WIDE_CHAR_CONNECT && !WIN32_ONLY
				if (inBuffer != null)
					inBuffer.Dispose ();
#endif
				if (outBuffer != null)
					outBuffer.Dispose ();
			}

			try
			{
				rc = (CLI.ReturnCode) CLI.SQLSetConnectAttr (
					hdbc,
					(int) CLI.ConnectionAttribute.SQL_ATTR_CONNECTION_TIMEOUT,
					(IntPtr) options.ConnectionTimeout,
					(int) CLI.LengthCode.SQL_IS_INTEGER);
				if (rc != CLI.ReturnCode.SQL_SUCCESS)
					HandleConnectionErrors (rc);
			}
			catch (Exception)
			{
				Disconnect ();
				throw;
			}

			GC.KeepAlive (this);
		}

		private void Disconnect ()
		{
			CLI.SQLDisconnect (hdbc);
			CLI.SQLFreeHandle ((short) CLI.HandleType.SQL_HANDLE_DBC, hdbc);
			hdbc = IntPtr.Zero;

			GC.KeepAlive (this);
		}

		private static void OnConnect ()
		{
			if (1 == Interlocked.Increment (ref connections))
			{
				try
				{
					InitHEnv ();
				} 
				catch (Exception) 
				{
					Interlocked.Decrement (ref connections);
					throw;
				}
			}
		}

		private static void OnDisconnect ()
		{
			if (0 == Interlocked.Decrement (ref connections))
			{
				FreeHEnv ();
			}
		}

		private static void InitHEnv ()
		{
			CLI.ReturnCode rc;

#if USE_DRIVER_MANAGER
			rc = (CLI.ReturnCode) CLI.SQLSetEnvAttr (
				IntPtr.Zero,
				(int) CLI.EnvironmentAttribute.SQL_ATTR_CONNECTION_POOLING,
				(IntPtr) (int) CLI.ConnectionPooling.SQL_CP_OFF,
				(int) CLI.LengthCode.SQL_IS_INTEGER);
			if (rc != CLI.ReturnCode.SQL_SUCCESS && rc != CLI.ReturnCode.SQL_SUCCESS_WITH_INFO)
				Diagnostics.HandleErrors (rc, CLI.HandleType.SQL_HANDLE_ENV, IntPtr.Zero);
#endif

			rc = (CLI.ReturnCode) CLI.SQLAllocHandle (
				(short) CLI.HandleType.SQL_HANDLE_ENV,
				CLI.SQL_NULL_HANDLE,
				out henv);
			if (rc != CLI.ReturnCode.SQL_SUCCESS)
				Diagnostics.HandleErrors (rc, CLI.HandleType.SQL_HANDLE_ENV, IntPtr.Zero);

			rc = (CLI.ReturnCode) CLI.SQLSetEnvAttr (
				henv,
				(int) CLI.EnvironmentAttribute.SQL_ATTR_ODBC_VERSION,
				(IntPtr) (int) CLI.OdbcVersion.SQL_OV_ODBC3,
				(int) CLI.LengthCode.SQL_IS_INTEGER);
			if (rc != CLI.ReturnCode.SQL_SUCCESS)
			{
				try
				{
					Diagnostics.HandleErrors (rc, CLI.HandleType.SQL_HANDLE_ENV, henv);
				}
				finally
				{
					FreeHEnv ();
				}
			}
		}

		private static void FreeHEnv ()
		{
			CLI.SQLFreeHandle ((short) CLI.HandleType.SQL_HANDLE_ENV, henv);
			henv = IntPtr.Zero;
		}

		protected override void Dispose (bool disposing)
		{
		  Debug.WriteLineIf (CLI.FnTrace.Enabled, "OdbcConnection.Dispose ()");
			try
			{
			if (disposing)
			{
				Close ();
			}
			else if (hdbc != IntPtr.Zero)
			{
				EndTransaction (false);
				//statementList.FinalizeAll ();
				FinalizeAll ();
				Disconnect ();
				OnDisconnect ();
			}

#if WIN3#if WIN32_FINALIZERS
			//statementList.Unreference ();
			Unreference ();
#endif
		}
			catch (Exception e)
			{
				// Dispose method should never throw an exception
				Debug.WriteLineIf(CLI.FnTrace.Enabled,
					"OdbcConnection.Dispose caught exception: " + e.Message);
			}
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

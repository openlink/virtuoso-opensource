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
using System.Collections.Generic;
using System.Collections;
using System.Diagnostics;
using System.EnterpriseServices;

#if ODBC_CLIENT
namespace OpenLink.Data.VirtuosoOdbcClient
#elif CLIENT
namespace OpenLink.Data.VirtuosoClient
#else
namespace OpenLink.Data.Virtuoso
#endif
{
	internal abstract class ManagedConnection : InnerConnectionBase, ICreateErrors
	{
		internal readonly static BooleanSwitch Switch = 
		    new BooleanSwitch ("VirtuosoClient.ManagedConnection", "Marshaling");

		internal FutureList futures = null;

		internal string currentCatalog = null;

		internal string charsetName;
		internal string charsetTable;
		internal Hashtable charsetMap;

		internal bool autocommit = true;
		internal CLI.IsolationLevel isolation = CLI.IsolationLevel.SQL_TXN_READ_COMMITED;

		internal protected string peer = null;
		internal protected string backendVersion;
		internal protected int caseMode;
		internal protected int prefetchRows;
		internal protected int prefetchBytes;
		internal protected int txnTimeout;
		internal protected int queryTimeout;
		internal protected bool utf8Execs;
		internal protected bool charset_utf8;
		internal protected bool noCharCEscape;
		internal protected bool binaryTimeStamp;

        internal protected Dictionary<int, string> rdf_type_hash = new Dictionary<int, string>();
        internal protected Dictionary<int, string> rdf_lang_hash = new Dictionary<int, string>();
		internal protected Hashtable rdf_type_rev = new Hashtable();
        internal protected Hashtable rdf_lang_rev = new Hashtable();

		private ManagedErrors errors = null;

		private string commandIdPrefix = null;
		private int nextCommandId = 0;

		private ArrayList commands = null;

		internal ManagedConnection ()
		{
			futures = new FutureList ();
			errors = new ManagedErrors ();
		}

		public VirtuosoErrorCollection CreateErrors ()
		{
			VirtuosoErrorCollection e = errors.CreateErrors ();
			errors.Clear ();
			return e;
		}

		internal abstract ISession Session
		{
			get;
		}

#if ADONET2
        public override string ServerVersion
        {
            get
            {
                string version = "";
                ManagedCommand cmd = new ManagedCommand (this);
                cmd.SetParameters (null);
                try
                {
                    cmd.Execute ("select sys_stat ('st_dbms_ver')");
                    if (cmd.Fetch ())
                    {
					    object data = cmd.GetColumnData (0, cmd.GetColumnMetaData ());
					    if (data != null && data is string)
						  version = (string) data;
                    }
                }
                finally
                {
                    cmd.CloseCursor (true);
                    cmd.Dispose ();
                }
                return version;
            }
        }

        public override string ServerName
        {
            get
            {
                string name = "";
                ManagedCommand cmd = new ManagedCommand (this);
                cmd.SetParameters (null);
                try
                {
                    cmd.Execute ("select sys_stat ('st_dbms_name')");
                    if (cmd.Fetch ())
                    {
					    object data = cmd.GetColumnData (0, cmd.GetColumnMetaData ());
					    if (data != null && data is string)
						  name = (string) data;
                    }
                }
                finally
                {
                    cmd.CloseCursor (true);
                    cmd.Dispose ();
                }
                return name;
            }
        }

        public override CLI.IdentCase IdentCase
        {
            get
            {
                string caseMode = "";
                ManagedCommand cmd = new ManagedCommand (this);
                cmd.SetParameters (null);
                try
                {
                    cmd.Execute ("select sys_stat ('st_case_mode')");
                    if (cmd.Fetch ())
                    {
					    object data = cmd.GetColumnData (0, cmd.GetColumnMetaData ());
					    if (data != null && data is string)
						  caseMode = (string) data;
                    }
                }
                finally
                {
                    cmd.CloseCursor (true);
                    cmd.Dispose ();
                }
                if (caseMode == "2")
                  return CLI.IdentCase.SQL_IC_MIXED;
                else if (caseMode == "1")
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
                string name = "";
                ManagedCommand cmd = new ManagedCommand (this);
                cmd.SetParameters (null);
                try
                {
                    cmd.Execute ("select username()");
                    if (cmd.Fetch ())
                    {
					    object data = cmd.GetColumnData (0, cmd.GetColumnMetaData ());
					    if (data != null && data is string)
						  name = (string) data;
                    }
                }
                finally
                {
                    cmd.CloseCursor (true);
                    cmd.Dispose ();
                }
                return name;
            }
        }

#endif
		public override void Close ()
		{
			if (futures != null)
			{
				futures.Clear ();
				futures = null;
			}

			if (commands != null)
			{
				for (int i = 0; i < commands.Count; i++)	
                                {
					WeakReference weak = (WeakReference) commands[i];
					VirtuosoCommand target = (VirtuosoCommand) weak.Target;
					if (target != null)
					{
						target.OnConnectionClose();
						weak.Target = null;
					}
				}
			}
		}

		public override IInnerCommand CreateInnerCommand (VirtuosoCommand outerCommand)
		{
			if (commands == null)
				commands = new ArrayList();

			commands.Add (new WeakReference (outerCommand));

			return new ManagedCommand(this);
		}

		public override void RemoveCommand (VirtuosoCommand outerCommand)
		{
                        if (commands == null)
                          return;

			int i = 0;
			while (i < commands.Count)
			{
				WeakReference weak = (WeakReference) commands[i];
				VirtuosoCommand target = (VirtuosoCommand) weak.Target;
				if (target == null || target == outerCommand)
					commands.RemoveAt(i);
				else
					i++;
			}
		}

		public override void BeginTransaction (CLI.IsolationLevel level)
		{
			autocommit = false;
			isolation = level;
		}

		public override void EndTransaction (bool commit)
		{
		        Debug.WriteLineIf (CLI.FnTrace.Enabled, String.Format (
			      "ManagedConnection.EndTransaction ({0})", commit));
			  CLI.CompletionType completion = commit ? 
			      CLI.CompletionType.SQL_COMMIT : 
			      CLI.CompletionType.SQL_ROLLBACK;
			  Future future = new Future (
			      Service.Transaction, (int) completion, null);
			  object result = null;
			  try 
			  {
			 	  futures.Add (future);
				  future.SendRequest (Session);
				  result = future.GetNextResult (Session, futures);
				  Debug.WriteLineIf (CLI.FnTrace.Enabled, String.Format (
				      "ManagedConnection.EndTransaction ({0}) success", commit));
			  }
			  finally
			  {
				  futures.Remove (future);
			  }
			  if (result is object[])
			  {
			    Debug.WriteLineIf (CLI.FnTrace.Enabled, String.Format (
				"ManagedConnection.EndTransaction ({0}) error", commit));
				  object[] results = (object[]) result;
				  errors.AddServerError ((string) results[1], null, (string) results[2]);
				  Diagnostics.HandleErrors (CLI.ReturnCode.SQL_ERROR, this);
			  }

			autocommit = true;
			isolation = CLI.IsolationLevel.SQL_TXN_READ_COMMITED;
		        Debug.WriteLineIf (CLI.FnTrace.Enabled, String.Format (
			      "ManagedConnection.EndTransaction ({0}) done", commit));
		}

		public override void Enlist (object distributedTransaction)
		{
			ITransaction transaction = (ITransaction) distributedTransaction;
			if (transaction == null)
			{
				Future future = new Future (Service.TransactionEnlist, (int) DtpFlags.SQL_TP_UNENLIST, null);
				object result = null;
				try
				{
					futures.Add (future);
					future.SendRequest (Session);
					result = future.GetNextResult (Session, futures);
				}
				finally
				{
					futures.Remove (future);
				}
				if (result != null && result is object[])
				{
					object[] results = (object[]) result;
					errors.AddServerError ((string) results[1], null, (string) results[2]);
					Diagnostics.HandleErrors (CLI.ReturnCode.SQL_ERROR, this);
				}
			}
			else
			{
				byte[] whereabouts = GetServerDtcWhereabouts ();
				DTC.ITransactionExport export = DTC.GetTransactionExport (transaction, whereabouts);
				byte[] cookie = DTC.GetTransactionCookie (transaction, export);
				string cookie_encoded = Encode (cookie);

				ManagedCommand cmd = new ManagedCommand (this);
				cmd.SetParameters (null);
				try
				{
					cmd.Execute ("select mts_enlist_transaction('" + cookie_encoded + "')");
					if (cmd.Fetch ())
					{
						autocommit = false;
					}
				}
				finally
				{
					cmd.CloseCursor (true);
					cmd.Dispose ();
				}
			}
		}

		public override string GetCurrentCatalog ()
		{
			return currentCatalog;
		}

		public override void SetCurrentCatalog (string name)
		{
			VirtuosoParameterCollection p = new VirtuosoParameterCollection (null);
			p.Add ("name", name);

			ManagedCommand cmd = new ManagedCommand (this);
			cmd.SetParameters (p);
			try
			{
				cmd.Execute ("set_qualifier(?)");
			}
			finally
			{
				cmd.CloseCursor (true);
				cmd.Dispose ();
			}
		}

		internal string GetNewId ()
		{
			if (commandIdPrefix == null)
			{
				Debug.Assert (peer != null);
				int end = peer.IndexOf ((char) 0);
				string peerz = end < 0 ? peer : peer.Substring (0, end);
				int colon = peerz.IndexOf (':');
				if (colon < 0)
					commandIdPrefix = "s" + peerz + "_";
				else
					commandIdPrefix = "s" + peerz.Substring (0, colon) + "_" + peerz.Substring (colon + 1) + "_";
			}
			return commandIdPrefix + nextCommandId++;
		}

        internal protected void SetConnectionOptions (object[] results)
		{
			Debug.WriteLineIf (CLI.FnTrace.Enabled, "ManagedConnection.SetConnectionOptions ()");

			currentCatalog = (string) results[1];
			backendVersion = (string) results[2];
			caseMode = (int) results[3];
			Debug.WriteLineIf (Switch.Enabled, "currentCatalog: " + currentCatalog);
			Debug.WriteLineIf (Switch.Enabled, "backendVersion: " + backendVersion);
			Debug.WriteLineIf (Switch.Enabled, "caseMode: " + caseMode);

			int _dbgen = int.Parse (backendVersion.Substring (6));
			Debug.WriteLineIf (Switch.Enabled, "dbgen: " + _dbgen);
			if (_dbgen < 2303)
				throw new InvalidOperationException ("Old Virtuoso server version.");

            dbgen = _dbgen.ToString();

            if (results.Length > 4)
			{
				object[] opts = (object[]) results[4];
				prefetchRows = GetConnectionOption (opts, "SQL_PREFETCH_ROWS", Values.SELECT_PREFETCH_QUOTA);
				prefetchBytes = GetConnectionOption (opts, "SQL_PREFETCH_BYTES", 0);
				txnTimeout = GetConnectionOption (opts, "SQL_TXN_TIMEOUT", 0);
				queryTimeout = GetConnectionOption (opts, "SQL_QUERY_TIMEOUT", 0);
				noCharCEscape = (0 != GetConnectionOption (opts, "SQL_NO_CHAR_C_ESCAPE", 0));
				utf8Execs = (0 != GetConnectionOption (opts, "SQL_UTF8_EXECS", 0));
				binaryTimeStamp = (0 != GetConnectionOption (opts, "SQL_BINARY_TIMESTAMP", 1));

				Debug.WriteLineIf (Switch.Enabled, "SQL_PREFETCH_ROWS: " + prefetchRows);
				Debug.WriteLineIf (Switch.Enabled, "SQL_PREFETCH_BYTES: " + prefetchBytes);
				Debug.WriteLineIf (Switch.Enabled, "SQL_TXN_TIMEOUT: " + txnTimeout);
				Debug.WriteLineIf (Switch.Enabled, "SQL_QUERY_TIMEOUT: " + queryTimeout);
				Debug.WriteLineIf (Switch.Enabled, "SQL_NO_CHAR_C_ESCAPE: " + noCharCEscape);
				Debug.WriteLineIf (Switch.Enabled, "SQL_UTF8_EXECS: " + utf8Execs);
				Debug.WriteLineIf (Switch.Enabled, "SQL_BINARY_TIMESTAMP: " + binaryTimeStamp);
			}

			if (results.Length > 5 && results[5] != null && results[5] is object[])
			{
				object[] csinfo = (object[]) results[5];
				if (csinfo.Length > 1)
				{
					charsetName = (string) csinfo[0];
					charsetTable = (string) csinfo[1];
					Debug.WriteLineIf (Switch.Enabled, "charsetName: " + charsetName);
					Debug.WriteLineIf (Switch.Enabled, "charsetTable: " + charsetTable);
					charsetMap = new Hashtable (256);
					for (int i = 0; i < 255; i++)
					{
						if (i < charsetTable.Length)
							charsetMap[charsetTable[i]] = (byte) (i + 1);
						else
							charsetMap[(char) (i + 1)] = (byte) (i + 1);
					}
				}
			}
		}

		internal protected int GetConnectionOption (object[] opts, string name, int defaultValue)
		{
			if (opts != null)
			{
				for (int i = 0; i < opts.Length; i += 2)
				{
					if (name == (string) opts[i])
						return (int) opts[i + 1];
				}
			}
			return defaultValue;
		}

		private byte[] GetServerDtcWhereabouts ()
		{
			ManagedCommand cmd = new ManagedCommand (this);
			cmd.SetParameters (null);
			try
			{
				cmd.Execute ("select mts_get_rmcookie()");
				if (cmd.Fetch ())
				{
					object data = cmd.GetColumnData (0, cmd.GetColumnMetaData ());
					if (data != null && data is string)
						return Decode ((string) data);
				}
			}
			finally
			{
				cmd.CloseCursor (true);
				cmd.Dispose ();
			}
			return null;
		}

		private static string Encode (byte[] bytes)
		{
			char[] chars = new char[bytes.Length * 4];
			for (int i = 0, offset = 0; i < bytes.Length; i++)
			{
				byte b = bytes[i];
				chars[offset++] = '/';
				chars[offset++] = (char) (b / 100 + '0');
				b %= 100;
				chars[offset++] = (char) (b / 10 + '0');
				chars[offset++] = (char) (b % 10 + '0');
			}
			return new string (chars);
		}

		private static byte[] Decode (string data)
		{
			int length = data.Length / 4;
			if (length == 0)
				return null;

			byte[] bytes = new byte[length];
			for (int i = 0, offset = 0; i < length; i++, offset += 4)
			{
				if (data[offset] != '/')
					return null;
				bytes[i] = (byte) ((data[offset + 1] - '0') * 100 + (data[offset + 2] - '0') * 10 + (data[offset + 3] - '0'));
			}

			return bytes;
		}
	}
}

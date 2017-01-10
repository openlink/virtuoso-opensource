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
using System.Data;
using System.Data.Common;
using System.Diagnostics;

#if ODBC_CLIENT
namespace OpenLink.Data.VirtuosoOdbcClient
#elif CLIENT
namespace OpenLink.Data.VirtuosoClient
#else
namespace OpenLink.Data.Virtuoso
#endif
{
	public sealed class VirtuosoTransaction : 
#if ADONET2
        DbTransaction, IDbTransaction, IDisposable
#else
        MarshalByRefObject, IDbTransaction, IDisposable
#endif
	{
		private VirtuosoConnection connection;
		private IsolationLevel isolation;
		private bool ended;

		internal VirtuosoTransaction (VirtuosoConnection connection, System.Data.IsolationLevel isolation)
		{
			this.connection = connection;
			this.isolation = isolation;
			this.ended = false;
		}

		~VirtuosoTransaction ()
		{
			Dispose (false);
		}

#if ADONET2
		public new void Dispose ()
#else
		public void Dispose ()
#endif
		{
			Dispose (true);
			GC.SuppressFinalize (this);
		}

#if ADONET2
		protected override DbConnection DbConnection
		{
			get { return connection; }
		}
#else

		IDbConnection IDbTransaction.Connection
		{
			get { return connection; }
		}
#endif

#if MONO && !ADONET2
		public VirtuosoConnection Connection
#else
		public new VirtuosoConnection Connection
#endif
		{
		        get { return connection; }
		}

#if ADONET2
		public override IsolationLevel IsolationLevel 
#else
		public IsolationLevel IsolationLevel 
#endif
		{
			get { return isolation; }
		}

#if ADONET2
        public override void Commit ()
#else
		public void Commit ()
#endif
		{
			End (true);
		}

#if ADONET2
        public override void Rollback ()
#else
		public void Rollback ()
#endif
		{
			End (false);
		}

		private void End (bool commit)
		{
			if (connection == null)
				throw new InvalidOperationException ("The transaction is disposed.");
			if (ended)
				throw new InvalidOperationException ("The transaction has already been committed or rolled back.");
			connection.EndTransaction (commit);
			ended = true;
		}

#if ADONET2
		protected override void Dispose (bool disposing)
#else
		private void Dispose (bool disposing)
#endif
		{
			if (disposing)
			{
				if (!ended)
                {
                    try
                    {
					Rollback ();
			}
                    catch (Exception e)
                    {
                        // Dispose method should never throw an exception.
                        // So just log any messages.
                        Debug.WriteLineIf(CLI.FnTrace.Enabled, "VirtuosoTransaction.Dispose caught exception: " + e.Message);
                    }
                }
			}
			connection = null;
#if ADONET2
            base.Dispose(disposing);
#endif
		}
	}
}

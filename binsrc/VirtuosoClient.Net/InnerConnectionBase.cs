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

#if ODBC_CLIENT
namespace OpenLink.Data.VirtuosoOdbcClient
#elif CLIENT
namespace OpenLink.Data.VirtuosoClient
#else
namespace OpenLink.Data.Virtuoso
#endif
{
	internal abstract class InnerConnectionBase : IInnerConnection
	{
		private DateTime timestamp;

		private WeakReference outerConnectionWeakRef;

		private object distributedTransaction;
		private object distributedTransactionId;
        private string serverName;
        private CLI.IdentCase identCase;
        private CLI.IdentCase quotedIdentCase;

		~InnerConnectionBase ()
		{
			Dispose (false);
		}

		public DateTime TimeStamp
		{
			get { return timestamp; }
			set { timestamp = value; }
		}

		public WeakReference OuterConnectionWeakRef
		{
			get { return outerConnectionWeakRef; }
			set { outerConnectionWeakRef = value; }
		}

		public VirtuosoConnection OuterConnection
		{
			get
			{
				if (outerConnectionWeakRef == null)
					return null;
				return (VirtuosoConnection) outerConnectionWeakRef.Target;
			}
		}

		public object DistributedTransaction
		{
			get { return distributedTransaction; }
			set { distributedTransaction = value; }
		}

		public object DistributedTransactionId
		{
			get { return distributedTransactionId; }
			set { distributedTransactionId = value; }
		}

		public virtual bool IsValid ()
		{
			return true;
		}

		public virtual void Pool ()
		{
		}

		public void Dispose ()
		{
			Dispose (true);
			GC.SuppressFinalize (this);
		}

		protected virtual void Dispose (bool disposing)
		{
		}

		public abstract void Open (ConnectionOptions options);
		public abstract void Close ();
		public abstract IInnerCommand CreateInnerCommand (VirtuosoCommand outerCommand);
		public abstract void RemoveCommand (VirtuosoCommand outerCommand);
		public abstract void BeginTransaction (CLI.IsolationLevel level);
		public abstract void EndTransaction (bool commit);
		public abstract void Enlist (object transaction);
		public abstract string GetCurrentCatalog ();
		public abstract void SetCurrentCatalog (string name);

        internal string dbgen = Values.VERSION;
#if !ADONET2
        public string ServerVersion
        {
            get
            {
                return dbgen.ToString();
            }
        }
#else
        public abstract string ServerVersion { get; }
        public abstract string ServerName { get; }
        public abstract CLI.IdentCase IdentCase { get ;}
        public abstract CLI.IdentCase QuotedIdentCase { get ;}
        public abstract string UserName { get; }
#endif
    }
}

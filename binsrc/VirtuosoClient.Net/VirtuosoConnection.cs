//  
//  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
//  project.
//  
//  Copyright (C) 1998-2006 OpenLink Software
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
using System.Data;
#if ADONET2
using System.Data.Common;
#endif
using System.Diagnostics;
//using System.EnterpriseServices;
using System.Runtime.InteropServices;
using System.Threading;

using System.ComponentModel;

#if ODBC_CLIENT
namespace OpenLink.Data.VirtuosoOdbcClient
#elif CLIENT
namespace OpenLink.Data.VirtuosoClient
#else
namespace OpenLink.Data.Virtuoso
#endif
{
#if (!MONO) // for now Mono doesn't have an IDE
    [System.Drawing.ToolboxBitmapAttribute(typeof(VirtuosoConnection), "OpenLink.Data.VirtuosoClient.VirtuosoConnection.bmp") ]
#endif
    public sealed class VirtuosoConnection : 
#if ADONET2
    DbConnection, ICloneable, IDbConnection
#else    
    System.ComponentModel.Component, ICloneable, IDbConnection
#endif    
    {
        internal static VirtuosoPermission permission = new VirtuosoPermission ();

        /// <summary>
        /// The state of the connection.
        /// </summary>
        internal ConnectionState state;

        /// <summary>
        /// The field to keep connection string options.
        /// </summary>
        internal ConnectionOptions options;

        internal IInnerConnection innerConnection = null;

        internal ConnectionPool pool;

        private bool autocommit;
	private VirtuosoTransaction transactionStrongRef;

        private bool disposed = false;

        // Always have a default constructor.
        public VirtuosoConnection ()
            : this (null)
        {
        }

        // Have a constructor that takes a connection string.
        public VirtuosoConnection (string connectionString)
        {
            Debug.WriteLineIf (CLI.FnTrace.Enabled, "VirtuosoConnection.ctor()");

            // Initialize the connection object into a closed state.
            state = ConnectionState.Closed;

            autocommit = true;

            if (connectionString != null)
                options = ParseConnectionString (connectionString);
            else
                options = new ConnectionOptions ();
        }

        /*
                 * Now inherited from the System.ComponentModel.Component 
                 * 
                ~VirtuosoConnection ()
                {
                        Dispose (false);
                }
                */

        /*
                 * Now inherited from the System.ComponentModel.Component 
                 * 
                public void Dispose ()
                {
                        Dispose (true);
                        GC.SuppressFinalize (this);
                }
                */

        object ICloneable.Clone ()
        {
            VirtuosoConnection conn = new VirtuosoConnection ();
            conn.options = this.options;
            return conn;
        }

#if !MONO
        [Editor(
             VirtuosoConstants.VirtuosoDesignNSPrefix + ".VirtuosoConnectionStringEditor, " +
             VirtuosoConstants.VirtuosoDesignSN, 
             typeof (System.Drawing.Design.UITypeEditor))]
//        [Description ("hahaahha")]
        [Category("Data")]
#endif

#if ADONET2
        public override string ConnectionString
#else
        public string ConnectionString
#endif
        {
            get
            {
                return options.ConnectionString;
            }
            set
            {
                if (state != ConnectionState.Closed)
                    throw new InvalidOperationException ("The connection is open.");
                if (value != null)
                  options = ParseConnectionString (value);
            }
        }

#if !MONO
//        [Description ("hahaahha")]
        [Category("Data")]
#endif
#if ADONET2
        public override int ConnectionTimeout
#else
        public int ConnectionTimeout
#endif
        {
            get
            {
                // Returns the connection time-out value set in the connection
                // string. Zero indicates an indefinite time-out period.
                return options.ConnectionTimeout;
            }
        }

#if !MONO
//        [Description ("hahaahha")]
        [Category("Data")]
#endif
#if ADONET2
        public override string Database
#else
        public string Database
#endif
        {
            get
            {
                // Returns an initial database as set in the connection string.
                // An empty string indicates not set - do not return a null reference.
                String database;
                if (state == ConnectionState.Closed)
                    database = options.Database;
                else
                    database = innerConnection.GetCurrentCatalog ();
                return database == null ? "" : database;
            }
        }

#if !MONO
//        [Description ("hahaahha")]
        [Category("Data")]
#endif
#if ADONET2
        public override ConnectionState State
#else
        public ConnectionState State
#endif
        {
            get { return state; }
        }

        IDbTransaction IDbConnection.BeginTransaction ()
        {
            return BeginTransaction ();
        }

#if !ADONET2
        public VirtuosoTransaction BeginTransaction ()

        {
            return BeginTransaction (IsolationLevel.ReadCommitted);
        }
#endif
        IDbTransaction IDbConnection.BeginTransaction(IsolationLevel level)
        {
            return BeginTransaction (level);
        }

#if ADONET2
        protected override DbTransaction BeginDbTransaction (IsolationLevel level)
#else
        public VirtuosoTransaction BeginTransaction (IsolationLevel level)
#endif
        {
            Debug.WriteLineIf (CLI.FnTrace.Enabled, "VirtuosoConnection.BeginTransaction (level = " + level + ")");

            if (state == ConnectionState.Closed)
                throw new InvalidOperationException ("The connection is closed");

            CLI.IsolationLevel isolation;
            switch (level)
            {
                case IsolationLevel.ReadUncommitted:
                    isolation = CLI.IsolationLevel.SQL_TXN_READ_UNCOMMITTED;
                    break;
                case IsolationLevel.ReadCommitted:
                    isolation = CLI.IsolationLevel.SQL_TXN_READ_COMMITED;
                    break;
                case IsolationLevel.RepeatableRead:
                    isolation = CLI.IsolationLevel.SQL_TXN_REPEATABLE_READ;
                    break;
                case IsolationLevel.Serializable:
                    isolation = CLI.IsolationLevel.SQL_TXN_SERIALIZABLE;
                    break;
                default:
                    throw new Exception ("Unknown or unsupported isolation level");
            }

            VirtuosoTransaction transaction = null;
            if (!autocommit && transactionStrongRef != null)
            {
                transaction = (VirtuosoTransaction) transactionStrongRef;
                if (transaction != null)
                    throw new InvalidOperationException ("Another transaction is running.");
                EndTransaction (false);
            }

            innerConnection.BeginTransaction (isolation);

            autocommit = false;
            transaction = new VirtuosoTransaction (this, level);
            transactionStrongRef = transaction;

            return transaction;
        }
#if ADONET2
        public override void ChangeDatabase (string dbName)
#else
        public void ChangeDatabase (string dbName)
#endif
        {
            /*
                         * Change the database setting on the back-end. Note that it is a method
                         * and not a property because the operation requires an expensive
                         * round trip.
                         */
            Debug.WriteLineIf (CLI.FnTrace.Enabled, "VirtuosoConnection.ChangeDatabase (dbName = '" + dbName + "')");

            if (dbName == null || dbName.Trim () == "")
                throw new ArgumentException ("Invalid database name");
            if (state == ConnectionState.Closed)
                throw new InvalidOperationException ("The connection is closed");

            innerConnection.SetCurrentCatalog (dbName);
        }

#if ADONET2
        public override void Close ()
#else
        public void Close ()
#endif
        {
            /*
                         * Close the database connection and set the ConnectionState
                         * property. If the underlying connection to the server is
                         * being pooled, Close() will release it back to the pool.
                         */
            Debug.WriteLineIf (CLI.FnTrace.Enabled, "VirtuosoConnection.Close ()");

            if (state != ConnectionState.Closed)
            {
                if (!autocommit && transactionStrongRef != null)
                {
                    VirtuosoTransaction transaction = (VirtuosoTransaction) transactionStrongRef;
                    if (transaction != null)
                        transaction.Dispose ();
                    else
                        EndTransaction (false);
                }

                if (pool != null)
                    pool.PutConnection (innerConnection);
                else
                    innerConnection.Close ();
                innerConnection = null;

                state = ConnectionState.Closed;
                OnClose ();
            }
        }

        IDbCommand IDbConnection.CreateCommand ()
        {
            return CreateCommand ();
        }

#if ADONET2
        protected override DbCommand CreateDbCommand ()
#else
        public VirtuosoCommand CreateCommand ()
#endif
        {
            // Return a new instance of a command object.
            Debug.WriteLineIf (CLI.FnTrace.Enabled, "VirtuosoConnection.CreateCommand()");

            VirtuosoCommand command = new VirtuosoCommand ();
            command.Connection = this;
            return command;
        }

#if ADONET2
        public override void EnlistDistributedTransaction (System.EnterpriseServices.ITransaction transaction)
#else
        public void EnlistDistributedTransaction (System.EnterpriseServices.ITransaction transaction)
#endif
        {
            Debug.WriteLineIf (CLI.FnTrace.Enabled, "VirtuosoConnection.EnlistDistributedTransaction ();");

            if (state == ConnectionState.Closed)
                throw new InvalidOperationException ("The connection is closed");
            if (!Platform.HasDtc ())
                throw new InvalidOperationException ("Transaction enlistment is not supported on this platform.");
            if (transactionStrongRef != null)
                throw new InvalidOperationException ("A local transaction is active");

            innerConnection.Enlist (transaction);
            autocommit = false;
        }

#if ADONET2
        public override void Open ()
#else
        public void Open ()
#endif
        {
            /*
                         * Open the database connection and set the ConnectionState
                         * property. If the underlying connection to the server is 
                         * expensive to obtain, the implementation should provide
                         * implicit pooling of that connection.
                         * 
                         * If the provider also supports automatic enlistment in 
                         * distributed transactions, it should enlist during Open().
                         */
            Debug.WriteLineIf (CLI.FnTrace.Enabled, "VirtuosoConnection.Open ()");

            if (state != ConnectionState.Closed)
                throw new InvalidOperationException ("The connection has already been open.");

            permission.Demand ();

            if (options.Pooling)
            {
                if (pool == null)
                    pool = ConnectionPool.GetPool (options);
                innerConnection = pool.GetConnection (options, this);
            }
            else
            {
                innerConnection = CreateInnerConnection (options, true);
            }
            state = ConnectionState.Open;
            options.Secure ();
            OnOpen ();
        }

#if !MONO
//        [Description ("hahaahha")]
        [Category("Data")]
#endif
        public event StateChangeEventHandler StateChange;

        private void OnOpen ()
        {
            if (StateChange != null)
            {
                StateChangeEventArgs args = new StateChangeEventArgs (ConnectionState.Closed, ConnectionState.Open);
                StateChange (this, args);
            }
        }

        private void OnClose ()
        {
            if (StateChange != null)
            {
                StateChangeEventArgs args = new StateChangeEventArgs (ConnectionState.Open, ConnectionState.Closed);
                StateChange (this, args);
            }
        }

#if !MONO
//        [Description ("hahaahha")]
        [Category("Data")]
#endif
        public event VirtuosoInfoMessageEventHandler InfoMessage;

        internal void OnInfoMessage (VirtuosoInfoMessageEventArgs args)
        {
            if (InfoMessage != null)
            {
                InfoMessage (this, args);
            }
        }

        internal void EndTransaction (bool commit)
        {
            if (state == System.Data.ConnectionState.Closed)
                throw new InvalidOperationException ("The connection is closed.");
            if (autocommit)
                throw new InvalidOperationException ("No transaction is active.");

            innerConnection.EndTransaction (commit);

            transactionStrongRef = null;
            autocommit = true;
        }

        internal VirtuosoTransaction CheckTransaction (VirtuosoTransaction transaction)
        {
            if (transactionStrongRef != null)
            {
                VirtuosoTransaction currentTransaction = (VirtuosoTransaction) transactionStrongRef;
                if (currentTransaction != transaction)
                {
                    if (currentTransaction == null)
                        EndTransaction (false);
                    if (transaction == null)
                        throw new InvalidOperationException ("The transaction is not set.");
                    else
                        throw new InvalidOperationException ("The transaction is not associated with the connection.");
                }
            }
            else if (transaction != null)
            {
                if (transaction.Connection != null)
                    throw new InvalidOperationException ("The transaction is not associated with the connection.");
                transaction = null;
            }
            return transaction;
        }

        protected override void Dispose (bool disposing)
        {
            if (disposed)
                return;

            disposed = true;

            if (disposing)
            {
                Close ();
            }
            innerConnection = null;
            options = null;

            base.Dispose (disposing);
        }

        private ConnectionOptions ParseConnectionString (string connectionString)
        {
            pool = null;
            ConnectionStringParser parser = new ConnectionStringParser ();
            ConnectionOptions newOptions = new ConnectionOptions ();
            parser.Parse (connectionString, newOptions); // can throw an exception
            newOptions.Verify (); // can throw an exception
            return newOptions;
        }

        internal IInnerConnection CreateInnerConnection (ConnectionOptions options, bool enlist)
        {
            Debug.WriteLineIf (CLI.FnTrace.Enabled, "VirtuosoConnection.CreateInnerConnection()");

            IInnerConnection conn;
            if (options.UseOdbc)
                conn = new OdbcConnection ();
            else
                conn = new TcpConnection ();

            conn.OuterConnectionWeakRef = new WeakReference (this);

            conn.Open (options);
#if MTS 
			if (enlist && options.Enlist && ContextUtil.IsInTransaction)
			 	EnlistInnerConnection (conn);
#endif			

            return conn;
        }

        internal void EnlistInnerConnection (IInnerConnection conn)
        {
            try
            {
                object dt = System.EnterpriseServices.ContextUtil.Transaction;
                conn.Enlist (dt);
                conn.DistributedTransaction = dt;
                conn.DistributedTransactionId = System.EnterpriseServices.ContextUtil.TransactionId;
                autocommit = false;
            }
            catch
            {
                conn.Close ();
                throw;
            }
        }

        public string GetConnectionOption (string name)
        {
            return options.GetOption (name).ToString ();
        }

#region ADO.NET 2.0
#if ADONET2
        //TODO: FIX THAT
        //string m_dataSourceName;
        public override string  DataSource
        {
	      get { return  "DummyDataSource"; }
        }

        public override string  ServerVersion
        {
            get { return this.innerConnection.ServerVersion; }
        }

#endif
#endregion
        }
}

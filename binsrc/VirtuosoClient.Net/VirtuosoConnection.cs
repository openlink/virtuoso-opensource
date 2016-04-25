//  
//  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
//  project.
//  
//  Copyright (C) 1998-2016 OpenLink Software
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
using System.Text;
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
    DbConnection, ICloneable
#else    
    System.ComponentModel.Component, ICloneable, IDbConnection
#endif    
    {
        /// <summary>
        /// Constants relating to SpecialColumns metadata restrictions
        /// </summary>
        public sealed class SpecialColumnsRestrictions
        {
            // IDENTIFIER_TYPE restriction values
            public static readonly string IDENTIFIER_TYPE_BEST_ROWID = "BEST_ROWID";
            public static readonly string IDENTIFIER_TYPE_ROWVER = "ROWVER";

            // SCOPE restriction values
            public static readonly string SCOPE_CURROW = "CURROW";
            public static readonly string SCOPE_TRANSACTION = "TRANSACTION";
            public static readonly string SCOPE_SESSION = "SESSION";

            // NULLABLE restriction values
            public static readonly string NO_NULLS = "NO NULLS";
            public static readonly string NULLABLE = "NULLABLE";
        }

        internal const string VARCHAR_UNSPEC_SIZE = "4070";
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

#if ADONET2 || ADONET1_SCHEMA_EXTS
        private static string SqlReservedWords =
            "ABSOLUTE,ACTION,ADA,ADD,ALL,ALLOCATE,ALTER,AND,ANY,ARE,AS," +
            "ASC,ASSERTION,AT,AUTHORIZATION,AVG,BEGIN,BETWEEN,BIT," +
            "BIT_LENGTH,BIGINT,BOTH,BY,CASCADE,CASCADED,CASE,CAST,CATALOG," +
            "CHAR," +
            "CHAR_LENGTH,CHARACTER,CHARACTER_LENGTH,CHECK,CLOSE,COALESCE," +
            "COLLATE,COLLATION,COLUMN,COMMIT,CONNECT,CONNECTION,CONSTRAINT," +
            "CONSTRAINTS,CONTINUE,CONVERT,CORRESPONDING,COUNT,CREATE,CROSS," +
            "CURRENT,CURRENT_DATE,CURRENT_TIME,CURRENT_TIMESTAMP," +
            "CURRENT_USER,CURSOR,DATE,DAY,DEALLOCATE,DEC,DECIMAL,DECLARE," +
            "DEFAULT,DEFERRABLE,DEFERRED,DELETE,DESC,DESCRIBE,DESCRIPTOR," +
            "DIAGNOSTICS,DISCONNECT,DISTINCT,DOMAIN,DOUBLE,DROP,ELSE,END," +
            "END-EXEC,ESCAPE,EXCEPT,EXCEPTION,EXEC,EXECUTE,EXISTS,EXTERNAL," +
            "EXTRACT,FALSE,FETCH,FIRST,FLOAT,FOR,FOREIGN,FORTRAN,FOUND,FROM," +
            "FULL,GET,GLOBAL,GO,GOTO,GRANT,GROUP,HAVING,HOUR,IDENTITY," +
            "IMMEDIATE,IN,INCLUDE,INDEX,INDICATOR,INITIALLY,INNER,INPUT," +
            "INSENSITIVE,INSERT,INT,INTEGER,INTERSECT,INTERVAL,INTO,IS," +
            "ISOLATION,JOIN,KEY,LANGUAGE,LAST,LEADING,LEFT,LEVEL,LIKE,LOCAL," +
            "LOWER,MATCH,MAX,MIN,MINUTE,MODULE,MONTH,NAMES,NATIONAL,NATURAL," +
            "NCHAR,NEXT,NO,NONE,NOT,NULL,NULLIF,NUMERIC,OCTET_LENGTH,OF,ON," +
            "ONLY,OPEN,OPTION,OR,ORDER,OUTER,OUTPUT,OVERLAPS,PAD,PARTIAL," +
            "PASCAL,POSITION,PRECISION,PREPARE,PRESERVE,PRIMARY,PRIOR," +
            "PRIVILEGES,PROCEDURE,PUBLIC,READ,REAL,REFERENCES,RELATIVE," +
            "RESTRICT,REVOKE,RIGHT,ROLLBACK,ROWS,SCHEMA,SCROLL,SECOND," +
            "SECTION,SELECT,SESSION,SESSION_USER,SET,SIZE,SMALLINT,SOME," +
            "SPACE,SQL,SQLCA,SQLCODE,SQLERROR,SQLSTATE,SQLWARNING,SUBSTRING," +
            "SUM,SYSTEM_USER,TABLE,TEMPORARY,THEN,TIME,TIMESTAMP," +
            "TIMEZONE_HOUR,TIMEZONE_MINUTE,TO,TRAILING,TRANSACTION,TRANSLATE," +
            "TRANSLATION,TRIM,TRUE,UNION,UNIQUE,UNKNOWN,UPDATE,UPPER,USAGE," +
            "USER,USING,VALUE,VALUES,VARCHAR,VARYING,VIEW,WHEN,WHENEVER," +
            "WHERE,WITH,WORK,WRITE,YEAR,ZONE," +
            // Virtuoso specific
            "CHAR,INT,LONG,OBJECT_ID,REPLACING,SMALLINT,SOFT,VALUES" 
            ;
#endif

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
                try
                {
                     options = ParseConnectionString (value);
                }
                catch
                {
                    throw;
                }
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

#if ADONET2
        public string UserName
        {
            get
            {
                 String username;
                if (state == ConnectionState.Closed)
                  username = options.UserId;
                else
                  username = innerConnection.UserName;
                return username;
            }
        }
#endif

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

#if ADONET2
        public new VirtuosoTransaction BeginTransaction ()
#else
        public VirtuosoTransaction BeginTransaction ()
#endif

        {
            return BeginTransaction (IsolationLevel.ReadCommitted);
        }

#if ADONET2
        public new VirtuosoTransaction BeginTransaction (IsolationLevel level)
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
                case IsolationLevel.Unspecified:
                    isolation = CLI.IsolationLevel.SQL_TXN_READ_COMMITED;
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
        protected override DbTransaction BeginDbTransaction (IsolationLevel level)
#else
        IDbTransaction IDbConnection.BeginTransaction(IsolationLevel level)
#endif
        {
            return BeginTransaction (level);
        }

#if !ADONET2
        IDbTransaction IDbConnection.BeginTransaction ()
        {
            return BeginTransaction ();
        }
#endif

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

#if ADONET2
        protected override DbCommand CreateDbCommand ()
#else
        IDbCommand IDbConnection.CreateCommand ()
#endif
        {
            return CreateCommand ();
        }

#if ADONET2
        public new VirtuosoCommand CreateCommand ()
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

        public void EnlistDistributedTransaction (System.EnterpriseServices.ITransaction transaction)
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
#if ADONET2 && !MONO1231
        public override event StateChangeEventHandler StateChange;
#else
        public event StateChangeEventHandler StateChange;
#endif

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
	    try
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
	    catch (Exception e)
	    {
	        Debug.WriteLineIf(CLI.FnTrace.Enabled,
		    "VirtuosoConnection.Dispose caught exception: " + e.Message);
	    }
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
#if UNMANAGED_ODBC
            if (options.UseOdbc)
                conn = new OdbcConnection ();
            else
#endif
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

#if ADONET2
        // 
        // Empties the connection pool associated with the specified connection.
        // ClearPool clears the connection pool that is associated with the 
        // connection. If additional connections associated with the pool 
        // are in use at the time of the call, they are marked appropriately
        // and are discarded (instead of being returned to the pool) when 
        // Close is called on them.
        // 
        public static void ClearPool(VirtuosoConnection connection)
        {
            if (connection == null)
                throw new ArgumentNullException("connection");
            if (!connection.options.Pooling || connection.pool == null)
                throw new InvalidOperationException("This connection is not pooled.");
            ConnectionPool.ClearPool(connection.options.ConnectionString);
        }

        // 
        // ClearAllPools resets (or empties) the connection pool. If there
        // are connections in use at the time of the call, they are marked
        // appropriately and will be discarded (instead of being returned
        // to the pool) when Close is called on them.
        // 
        public static void ClearAllPools()
        {
            ConnectionPool.ClearAllPools();
        }

        // Returns the MetaDataCollections schema.
        public override DataTable  GetSchema()
        {
            // Note: 
            // No base class functionality available. DbConnection.GetSchema()
            // simply throws a NotSupportedException.
            return GetSchema("MetaDataCollections", null);
        }

        // Returns schema information for the specific collection.
        public override DataTable GetSchema(string collectionName)
        {
            return GetSchema(collectionName, null);
        }

        // Retrieves schema information using the specified constraint(s) for 
        // the specified collection.
        public override DataTable GetSchema(string collectionName, string[] restrictionValues)
        {
            Debug.WriteLineIf (CLI.FnTrace.Enabled, "GetSchema" + collectionName + restrictionValues);
            if (state != ConnectionState.Open)
                throw new InvalidOperationException("The connection is not open.");
            string[] parms = new string[6]; // Assume no schema supports > 6 restrictions
            if (restrictionValues != null)
                restrictionValues.CopyTo(parms, 0);

            // bug 13648
            // Virtuoso DBA userid is "dba", but the corresponding schema qualifier is "DBA"
            // Convert any schema qualifier restrictions for this user to uppercase.
            if (restrictionValues != null)
            {
                switch (collectionName.ToUpper())
                {
                    case "COLUMNPRIVILEGES":
                    case "COLUMNS":
                    case "INDEXES":
                    case "PRIMARY KEYS":
                    case "PROCEDURES":
                    case "PROCEDURECOLUMNS":
                    case "PROCEDUREPARAMETERS":
                    case "TABLEPRIVILEGES":
                    case "TABLES":
                    case "VIEWS":
                        if (parms[1] != null && parms[1].Equals("dba"))
                            parms[1] = parms[1].ToUpper();
                        break;
                    case "SPECIALCOLUMNS":
                        if (parms[2] != null && parms[2].Equals("dba"))
                            parms[2] = parms[2].ToUpper();
                        break;
                    case "FOREIGNKEYS":
                        if (parms[1] != null && parms[1].Equals("dba"))
                            parms[1] = parms[1].ToUpper();
                        if (parms[4] != null && parms[4].Equals("dba"))
                            parms[4] = parms[4].ToUpper();
                        break;
                }
            }
            // bug 13648

            DataTable dt = null;
            switch (collectionName.ToUpper())
            {
                case "METADATACOLLECTIONS":
                    dt = GetSchemaMetaDataCollections();
                    break;
                case "DATASOURCEINFORMATION":
                    dt = GetSchemaDataSourceInformation();
                    break;
                case "DATATYPES":
                    dt = GetSchemaDataTypes();
                    break;
                case "RESTRICTIONS":
                    dt = GetSchemaRestrictions();
                    break;
                case "RESERVEDWORDS":
                    dt = GetSchemaReservedWords();
                    break;
                case "COLUMNPRIVILEGES":
                    dt = GetSchemaColumnPrivileges(parms[0], parms[1], parms[2], parms[3]);
                    break;
                case "COLUMNS":
                    dt = GetSchemaColumns(parms[0], parms[1], parms[2], parms[3]);
                    break;
                case "FOREIGNKEYS":
                    dt = GetSchemaForeignKeys(parms[0], parms[1], parms[2], parms[3],
                        parms[4], parms[5]);
                    break;
                case "INDEXES":
                    dt = GetSchemaIndexes(parms[0], parms[1], parms[2], parms[3]);
                    break;
                case "PRIMARYKEYS":
                    dt = GetSchemaPrimaryKeys(parms[0], parms[1], parms[2]);
                    break;
                case "PROCEDURES":
                    dt = GetSchemaProcedures(parms[0], parms[1], parms[2], parms[3]);
                    break;
                case "PROCEDURECOLUMNS":
                    dt = GetSchemaProcedureColumns(parms[0], parms[1], parms[2], parms[3]);
                    break;
                case "PROCEDUREPARAMETERS":
                    dt = GetSchemaProcedureParameters(parms[0], parms[1], parms[2], parms[3]);
                    break;
                case "SPECIALCOLUMNS":
                    dt = GetSchemaSpecialColumns(parms[0], parms[1], parms[2], parms[3],
                        parms[4], parms[5]);
                    break;
                case "TABLEPRIVILEGES":
                    dt = GetSchemaTablePrivileges(parms[0], parms[1], parms[2]);
                    break;
                case "TABLES":
                    dt = GetSchemaTables(parms[0], parms[1], parms[2], parms[3]);
                    break;
                case "VIEWS":
                    dt = GetSchemaViews(parms[0], parms[1], parms[2]);
                    break;
                default:
                    throw new ArgumentOutOfRangeException("Unsupported metadata collection name");
            }
            return dt;
        }

        private DataTable GetSchemaMetaDataCollections()
        {
            DataTable dt = new DataTable(DbMetaDataCollectionNames.MetaDataCollections);

            dt.Columns.Add(DbMetaDataColumnNames.CollectionName, typeof(String));
            dt.Columns.Add(DbMetaDataColumnNames.NumberOfRestrictions, typeof(Int32));
            dt.Columns.Add(DbMetaDataColumnNames.NumberOfIdentifierParts, typeof(Int32));

            dt.BeginLoadData();

            dt.Rows.Add(new object[] { DbMetaDataCollectionNames.MetaDataCollections, 0, 0 });
            dt.Rows.Add(new object[] { DbMetaDataCollectionNames.DataSourceInformation, 0, 0 });
            dt.Rows.Add(new object[] { DbMetaDataCollectionNames.DataTypes, 0, 0 });
            dt.Rows.Add(new object[] { DbMetaDataCollectionNames.Restrictions, 0, 0 });
            dt.Rows.Add(new object[] { DbMetaDataCollectionNames.ReservedWords, 0, 0 });
            dt.Rows.Add(new object[] { "ColumnPrivileges", 4, 4 });
            dt.Rows.Add(new object[] { "Columns", 4, 4 });
            dt.Rows.Add(new object[] { "ExtendedDataSourceInformation", 0, 0 });
            dt.Rows.Add(new object[] { "ForeignKeys", 6, 4 });
            dt.Rows.Add(new object[] { "Indexes", 4, 4 });
            dt.Rows.Add(new object[] { "PrimaryKeys", 3, 4 });
            dt.Rows.Add(new object[] { "Procedures", 4, 3 });
            dt.Rows.Add(new object[] { "ProcedureColumns", 4, 4 });
            dt.Rows.Add(new object[] { "ProcedureParameters", 4, 4 });
            dt.Rows.Add(new object[] { "SpecialColumns", 6, 3 });
            dt.Rows.Add(new object[] { "TablePrivileges", 3, 3 });
            dt.Rows.Add(new object[] { "Tables", 4, 3 });
            dt.Rows.Add(new object[] { "Views", 3, 3 });

            dt.AcceptChanges();
            dt.EndLoadData();
            return dt;
        }

        private DataTable GetSchemaDataSourceInformation()
        {
            CLI.IdentCase identCase = innerConnection.IdentCase;
            CLI.IdentCase quotedIdentCase = innerConnection.QuotedIdentCase;
            string dbmsName = innerConnection.ServerName;
            string dbmsVer = innerConnection.ServerVersion;
            bool orderByColsInSelect = false;
            CLI.GroupBy groupByBehavior = CLI.GroupBy.SQL_GB_GROUP_BY_CONTAINS_SELECT;
            CLI.OuterJoin supportedJoinOps = CLI.OuterJoin.SQL_OJ_LEFT | CLI.OuterJoin.SQL_OJ_RIGHT | CLI.OuterJoin.SQL_OJ_NESTED;


            DataTable dt = new DataTable(DbMetaDataCollectionNames.DataSourceInformation);

            dt.Columns.Add(DbMetaDataColumnNames.CompositeIdentifierSeparatorPattern, typeof(string));
            dt.Columns.Add(DbMetaDataColumnNames.DataSourceProductName, typeof(string));
            dt.Columns.Add(DbMetaDataColumnNames.DataSourceProductVersion, typeof(string));
            dt.Columns.Add(DbMetaDataColumnNames.DataSourceProductVersionNormalized, typeof(string));
            dt.Columns.Add(DbMetaDataColumnNames.GroupByBehavior, typeof(int));
            dt.Columns.Add(DbMetaDataColumnNames.IdentifierPattern, typeof(string));
            dt.Columns.Add(DbMetaDataColumnNames.IdentifierCase, typeof(int));
            dt.Columns.Add(DbMetaDataColumnNames.OrderByColumnsInSelect, typeof(bool));
            dt.Columns.Add(DbMetaDataColumnNames.ParameterMarkerFormat, typeof(string));
            dt.Columns.Add(DbMetaDataColumnNames.ParameterMarkerPattern, typeof(string));
            dt.Columns.Add(DbMetaDataColumnNames.ParameterNameMaxLength, typeof(int));
            dt.Columns.Add(DbMetaDataColumnNames.ParameterNamePattern, typeof(string));
            dt.Columns.Add(DbMetaDataColumnNames.QuotedIdentifierPattern, typeof(string));
            dt.Columns.Add(DbMetaDataColumnNames.QuotedIdentifierCase, typeof(int));
            dt.Columns.Add(DbMetaDataColumnNames.StatementSeparatorPattern, typeof(string));
            dt.Columns.Add(DbMetaDataColumnNames.StringLiteralPattern, typeof(string));
            dt.Columns.Add(DbMetaDataColumnNames.SupportedJoinOperators, typeof(int));

            dt.Rows.Add(new object[]
            {
                // CompositeIdentifierSeparatorPattern
                @"\.",
                // DataSourceProductName
                // jch Check this
                "Virtuoso",
                // DataSourceProductVersion
                dbmsVer,
                // DataSourceProductVersionNormalized
                dbmsVer,
                // GroupByBehavior
                groupByBehavior,
                // IdentifierPattern 
                // c.f. MS ODBC provider returns null
                null,
                // IdentifierCase
                identCase,
                // OrderByColumnsInSelect
                orderByColsInSelect,
                // ParameterMarkerFormat
                "?",
                // ParameterMarkerPattern
                "?",
                // ParameterNameMaxLength
                0,
                // ParameterNamePattern 
                // c.f. MS ODBC provider returns null
                null,
                // QuotedIdentifierPattern
                "\"(([^\"]|\"\")*)\"",
                // QuotedIdentifierCase
                quotedIdentCase,
                // StatementSeparatorPattern
                // c.f. MS ODBC provider returns null
                null,
                // StringLiteralPattern
                @"'(([^']|'')*)'",
                // SupportedJoinOperators
                supportedJoinOps
            });
            dt.AcceptChanges();
            dt.EndLoadData();

            return dt;
        }


        private DataTable GetSchemaDataTypes()
        {
            DataTable dt = new DataTable(DbMetaDataCollectionNames.DataTypes);
            dt.Columns.Add(DbMetaDataColumnNames.TypeName, typeof(string));
            dt.Columns.Add(DbMetaDataColumnNames.ProviderDbType, typeof(int));
            dt.Columns.Add(DbMetaDataColumnNames.ColumnSize, typeof(long));
            dt.Columns.Add(DbMetaDataColumnNames.CreateFormat, typeof(string));
            dt.Columns.Add(DbMetaDataColumnNames.CreateParameters, typeof(string));
            dt.Columns.Add(DbMetaDataColumnNames.DataType, typeof(string));
            dt.Columns.Add(DbMetaDataColumnNames.IsAutoIncrementable, typeof(bool));
            dt.Columns.Add(DbMetaDataColumnNames.IsBestMatch, typeof(bool));
            dt.Columns.Add(DbMetaDataColumnNames.IsCaseSensitive, typeof(bool));
            dt.Columns.Add(DbMetaDataColumnNames.IsFixedLength, typeof(bool));
            dt.Columns.Add(DbMetaDataColumnNames.IsFixedPrecisionScale, typeof(bool));
            dt.Columns.Add(DbMetaDataColumnNames.IsLong, typeof(bool));
            dt.Columns.Add(DbMetaDataColumnNames.IsNullable, typeof(bool));
            dt.Columns.Add(DbMetaDataColumnNames.IsSearchable, typeof(bool));
            dt.Columns.Add(DbMetaDataColumnNames.IsSearchableWithLike, typeof(bool));
            dt.Columns.Add(DbMetaDataColumnNames.IsUnsigned, typeof(bool));
            dt.Columns.Add(DbMetaDataColumnNames.MaximumScale, typeof(short));
            dt.Columns.Add(DbMetaDataColumnNames.MinimumScale, typeof(short));
            dt.Columns.Add(DbMetaDataColumnNames.IsConcurrencyType, typeof(bool));
            dt.Columns.Add(DbMetaDataColumnNames.IsLiteralSupported, typeof(bool));
            dt.Columns.Add(DbMetaDataColumnNames.LiteralPrefix, typeof(string));
            dt.Columns.Add(DbMetaDataColumnNames.LiteralSuffix, typeof(string));

            dt.Rows.Add(new object[]{"character", 1, 4070, null, "length", 
                "System.String", 0, null, 1, 1, 0, 0, 1, 1, 1, 0, null, null, 
                null, null, "''", "''"}); 
            dt.Rows.Add(new object[]{"numeric", 2, 40, null, "precision,scale", 
                "System.Decimal", 0, null, 1, 1, 0, 0, 1, 1, 0, 0, 15, 0, 
                null, null, "", ""}); 
            dt.Rows.Add(new object[]{"decimal", 3, 40, null, "precision,scale", 
                "System.Decimal", 0, null, 1, 1, 0, 0, 1, 1, 0, 0, 15, 0, 
                null, null, "", ""}); 
            dt.Rows.Add(new object[]{"integer", 4, 10, null, null, 
                "System.Int32", 0, null, 1, 1, 0, 0, 1, 1, 0, 0, 10, 0, 
                null, null, "", ""}); 
            dt.Rows.Add(new object[]{"smallint", 5, 3, null, null, 
                "System.Int16", 0, null, 1, 1, 0, 0, 1, 1, 0, 0, null, null, 
                null, null, "", ""}); 
            dt.Rows.Add(new object[]{"smallint", -7, 3, null, null, 
                "System.Int16", 0, null, 1, 1, 0, 0, 1, 1, 0, 0, null, null, 
                null, null, "", ""}); 
            dt.Rows.Add(new object[]{"bigint", -5, 20, null, null, 
                "System.Int64", 0, null, 1, 1, 0, 0, 1, 1, 0, 0, null, null, 
                null, null, "", ""}); 
            dt.Rows.Add(new object[]{"float", 6, 16, null, null, 
                "System.Double", 0, null, 1, 1, 0, 0, 1, 1, 0, 0, null,null, 
                null, null, "", "e0"}); 
            dt.Rows.Add(new object[]{"real", 7, 16, null, null, 
                "real", 0, null, 1, 1, 0, 0, 1, 1, 0, 0, null, null, 
                null, null, "", "e0"}); 
            dt.Rows.Add(new object[]{"double precision", 8, 16, null, null, 
                "System.Double", 0, null, 1, 1, 0, 0, 1, 1, 0, 0, null, null,
                null, null, "", "e0"}); 
            dt.Rows.Add(new object[]{"varchar", 12, 4070, null, "length", 
                "System.String", 0, null, 1, 0, 0, 0, 1, 1, 1, 0, null, null, 
                null, null, "''", "''"}); 
            dt.Rows.Add(new object[]{"long varchar", -1, 2147483647, null,null, 
                "System.String", 0, null, 1, 0, 0, 1, 1, 0, 0, 0, null, null,
                null, null, "''", "''"}); 
            dt.Rows.Add(new object[]{"long varbinary", -4,2147483647,null,null, 
                "System.Byte[]", 0, null, 1, 0, 0, 1, 1, 0, 0, 0, null, null,
                null, null, "''", "''"}); 
            dt.Rows.Add(new object[]{"datetime", 93, 19, null, null, 
                "System.DateTime", 0, null, 1, 1, 0, 0, 1, 1, 1, 0, null, null, 
                null, null, "{ts", "}"}); 
            dt.Rows.Add(new object[]{"timestamp", -2, 10, null, null, 
                "System.Byte[]", 0, null, 0, 1, 0, 0, 0, 1, 0, 0, null, null, 
                null, null, "0x", null}); 
            dt.Rows.Add(new object[]{"time", 92, 8, null, null, 
                "System.DateTime", 0, null, 1, 1, 0, 0, 1, 1, 0, 0, null, null, 
                null, null, "{t", "}"}); 
            dt.Rows.Add(new object[]{"date", 91, 10, null, null, 
                "System.DateTime", 0, null, 1, 1, 0, 0, 1, 1, 0, 0, null, null, 
                null, null, "{d", "}"}); 
            dt.Rows.Add(new object[]{"binary", -2, 4070, null, "length", 
                "System.Byte[]", 0, null, 1, 1, 0, 0, 1, 1, 0, 0, null, null, 
                null, null, "0x", ""}); 
            dt.Rows.Add(new object[]{"varbinary", -3, 4070, null, "length", 
                "System.Byte[]", 0, null, 1, 0, 0, 0, 1, 1, 0, 0, null, null, 
                null, null, "0x", ""}); 
            dt.Rows.Add(new object[]{"nchar", -8, 4070, null, "length", 
                "System.String", 0, null, 1, 1, 0, 0, 1, 1, 1, 0, null, null, 
                null, null, "N''", "''"}); 
            dt.Rows.Add(new object[]{"nvarchar", -9, 4070, null, "length", 
                "System.String", 0, null, 1, 0, 0, 0, 1, 1, 1, 0, null, null, 
                null, null, "N''", "''"}); 
            dt.Rows.Add(new object[]{"long nvarchar", -10,1073741823,null,null, 
                "System.String", 0, null, 1, 0, 0, 1, 1, 0, 0, 0, null, null,
                null, null, "N''", "''"}); 
            dt.Rows.Add(new object[]{"any", 12, 4070, null, null, 
                "System.Object", 0, null, 1, 1, 0, 0, 1, 1, 1, 0, null, null, 
                null, null, "''", "''"}); 

            dt.AcceptChanges();
            dt.EndLoadData();

            return dt;
        }

        private DataTable GetSchemaRestrictions()
        {
            DataTable dt = new DataTable("Restrictions");
            dt.Columns.Add("CollectionName", typeof(string));
            dt.Columns.Add("RestrictionName", typeof(string));
            dt.Columns.Add("RestrictionDefault", typeof(string));
            dt.Columns.Add("RestrictionNumber", typeof(int));

            dt.BeginLoadData();

            dt.Rows.Add(new object[] { "ColumnPrivileges", "TABLE_CAT", null, 1 });
            dt.Rows.Add(new object[] { "ColumnPrivileges", "TABLE_SCHEM", null, 2 });
            dt.Rows.Add(new object[] { "ColumnPrivileges", "TABLE_NAME", null, 3 });
            dt.Rows.Add(new object[] { "ColumnPrivileges", "COLUMN_NAME", null, 4 });
            dt.Rows.Add(new object[] { "Columns", "TABLE_CAT", null, 1 });
            dt.Rows.Add(new object[] { "Columns", "TABLE_SCHEM", null, 2 });
            dt.Rows.Add(new object[] { "Columns", "TABLE_NAME", null, 3 });
            dt.Rows.Add(new object[] { "Columns", "COLUMN_NAME", null, 4 });
            dt.Rows.Add(new object[] { "ForeignKeys", "PK_CAT_NAME", null, 1 });
            dt.Rows.Add(new object[] { "ForeignKeys", "PK_SCHEM_NAME", null, 2 });
            dt.Rows.Add(new object[] { "ForeignKeys", "PK_TABLE_NAME", null, 3 });
            dt.Rows.Add(new object[] { "ForeignKeys", "FK_CAT_NAME", null, 4 });
            dt.Rows.Add(new object[] { "ForeignKeys", "FK_SCHEM_NAME", null, 5 });
            dt.Rows.Add(new object[] { "ForeignKeys", "FK_TABLE_NAME", null, 6 });
            dt.Rows.Add(new object[] { "Indexes", "TABLE_CAT", null, 1 });
            dt.Rows.Add(new object[] { "Indexes", "TABLE_SCHEM", null, 2 });
            dt.Rows.Add(new object[] { "Indexes", "TABLE_NAME", null, 3 });
            dt.Rows.Add(new object[] { "Indexes", "INDEX_NAME", null, 4 });
            dt.Rows.Add(new object[] { "PrimaryKeys", "TABLE_CAT", null, 1 });
            dt.Rows.Add(new object[] { "PrimaryKeys", "TABLE_SCHEM", null, 2 });
            dt.Rows.Add(new object[] { "PrimaryKeys", "TABLE_NAME", null, 3 });
            dt.Rows.Add(new object[] { "Procedures", "PROCEDURE_CAT", null, 1 });
            dt.Rows.Add(new object[] { "Procedures", "PROCEDURE_SCHEM", null, 2 });
            dt.Rows.Add(new object[] { "Procedures", "PROCEDURE_NAME", null, 3 });
            dt.Rows.Add(new object[] { "Procedures", "PROCEDURE_TYPE", null, 4 });
            dt.Rows.Add(new object[] { "ProcedureColumns", "PROCEDURE_CAT", null, 1 });
            dt.Rows.Add(new object[] { "ProcedureColumns", "PROCEDURE_SCHE", null, 2 });
            dt.Rows.Add(new object[] { "ProcedureColumns", "PROCEDURE_NAME", null, 3 });
            dt.Rows.Add(new object[] { "ProcedureColumns", "COLUMN_NAME", null, 4 });
            dt.Rows.Add(new object[] { "ProcedureParameters", "PROCEDURE_CAT", null, 1 });
            dt.Rows.Add(new object[] { "ProcedureParameters", "PROCEDURE_SCHEM", null, 2 });
            dt.Rows.Add(new object[] { "ProcedureParameters", "PROCEDURE_NAME", null, 3 });
            dt.Rows.Add(new object[] { "ProcedureParameters", "COLUMN_NAME", null, 4 });
            dt.Rows.Add(new object[] { "SpecialColumns", "IDENTIFIER_TYPE", null, 1 });
            dt.Rows.Add(new object[] { "SpecialColumns", "TABLE_CAT", null, 2 });
            dt.Rows.Add(new object[] { "SpecialColumns", "TABLE_SCHEM", null, 3 });
            dt.Rows.Add(new object[] { "SpecialColumns", "TABLE_NAME", null, 4 });
            dt.Rows.Add(new object[] { "SpecialColumns", "SCOPE", null, 5 });
            dt.Rows.Add(new object[] { "SpecialColumns", "NULLABLE", null, 6 });
            dt.Rows.Add(new object[] { "TablePrivileges", "TABLE_CAT", null, 1 });
            dt.Rows.Add(new object[] { "TablePrivileges", "TABLE_SCHEM", null, 2 });
            dt.Rows.Add(new object[] { "TablePrivileges", "TABLE_NAME", null, 3 });
            dt.Rows.Add(new object[] { "Tables", "TABLE_CAT", null, 1 });
            dt.Rows.Add(new object[] { "Tables", "TABLE_SCHEM", null, 2 });
            dt.Rows.Add(new object[] { "Tables", "TABLE_NAME", null, 3 });
            dt.Rows.Add(new object[] { "Tables", "TABLE_TYPE", null, 4 });
            dt.Rows.Add(new object[] { "Views", "TABLE_CAT", null, 1 });
            dt.Rows.Add(new object[] { "Views", "TABLE_SCHEM", null, 2 });
            dt.Rows.Add(new object[] { "Views", "TABLE_NAME", null, 3 });

            dt.AcceptChanges();
            dt.EndLoadData();

            return dt;
        }

        private DataTable GetSchemaReservedWords()
        {
            // The MS ODBC provider returns a list of:
            //   a) all the ODBC reserved keywords listed in Appendix C 
            //      (SQL Grammar) of the ODBC specification
            // followed by
            //   b) the keywords returned by SQLGetInfo(SQL_KEYWORDS)
            // jch TODO Needs checking for Virtuoso
            StringBuilder reservedWords = new StringBuilder(SqlReservedWords);

            string[] splitWords = reservedWords.ToString().Split(new Char[] { ',' });

            DataTable dt = new DataTable(DbMetaDataCollectionNames.ReservedWords);
            dt.Columns.Add(DbMetaDataColumnNames.ReservedWord, typeof(string));

            dt.BeginLoadData();
            foreach (String reservedWord in splitWords)
            {
                string trimmedWord;
                if (!reservedWord.Equals(string.Empty) &&
                    (trimmedWord = reservedWord.Trim()) != "")
                    dt.Rows.Add(new object[] { trimmedWord });
            }
            dt.AcceptChanges();
            dt.EndLoadData();

            return dt;
        }

        private DataTable GetSchemaColumnPrivileges(string catalog, string schema, string table, string column)
        {
            DataTable dt = new DataTable("ColumnPrivileges");
            StringBuilder cmdText = new StringBuilder ("select * from INFORMATION_SCHEMA.COLUMN_PRIVILEGES where ");

            if (catalog != null && catalog.Length != 0)
              cmdText.Append ("TABLE_CATALOG like '" + catalog + "' AND ");
            if (schema != null && schema.Length != 0)
              cmdText.Append ("TABLE_SCHEMA like '" + schema + "' AND ");
            if (table != null && table.Length != 0)
              cmdText.Append ("TABLE_NAME like '" + table + "' AND ");
            if (column != null && column.Length != 0)
              cmdText.Append ("COLUMN_NAME like '" + column + "' AND ");
            cmdText.Append ("0 = 0");

            VirtuosoCommand cmd = new VirtuosoCommand (cmdText.ToString() ,this);
            VirtuosoDataReader reader = (VirtuosoDataReader)cmd.ExecuteReader();
            dt.Load(reader);

            return dt;
        }

        private DataTable GetSchemaTablePrivileges(string catalog, string schema, string table)
        {
            DataTable dt = new DataTable("TablePrivileges");
            StringBuilder cmdText = new StringBuilder ("select * from INFORMATION_SCHEMA.TABLE_PRIVILEGES where ");

            if (catalog != null && catalog.Length != 0)
              cmdText.Append ("TABLE_CATALOG like '" + catalog + "' AND ");
            if (schema != null && schema.Length != 0)
              cmdText.Append ("TABLE_SCHEMA like '" + schema + "' AND ");
            if (table != null && table.Length != 0)
              cmdText.Append ("TABLE_NAME like '" + table + "' AND ");
            cmdText.Append ("0 = 0");

            VirtuosoCommand cmd = new VirtuosoCommand (cmdText.ToString() ,this);
            VirtuosoDataReader reader = (VirtuosoDataReader)cmd.ExecuteReader();
            dt.Load(reader);

            return dt;
        }

   private static String getWideColumnsText_case0 =
       "SELECT " +
         "charset_recode (name_part(k.KEY_TABLE,0), 'UTF-8', '_WIDE_') AS TABLE_CAT NVARCHAR(128), " +
	 "charset_recode (name_part(k.KEY_TABLE,1), 'UTF-8', '_WIDE_') AS TABLE_SCHEM NVARCHAR(128), " +
	 "charset_recode (name_part(k.KEY_TABLE,2), 'UTF-8', '_WIDE_') AS TABLE_NAME NVARCHAR(128), " +
	 "charset_recode (c.\"COLUMN\", 'UTF-8', '_WIDE_') AS COLUMN_NAME NVARCHAR(128), " +
	 "dv_to_sql_type(c.COL_DTP) AS DATA_TYPE SMALLINT, " +
	 "dv_type_title(c.COL_DTP) AS TYPE_NAME VARCHAR(128), " +
	 "c.COL_PREC AS COLUMN_SIZE INTEGER, " +
	 "NULL AS BUFFER_LENGTH INTEGER, " +
	 "c.COL_SCALE AS DECIMAL_DIGITS SMALLINT, " +
	 "2 AS NUM_PREC_RADIX SMALLINT, " +
	 "either(isnull(c.COL_NULLABLE),2,c.COL_NULLABLE) AS NULLABLE SMALLINT, " +
	 "NULL AS REMARKS VARCHAR(254), " +
	 "NULL AS COLUMN_DEF VARCHAR(128), " +
	 "NULL AS SQL_DATA_TYPE INTEGER, " +
	 "NULL AS SQL_DATETIME_SUB INTEGER, " +
	 "NULL AS CHAR_OCTET_LENGTH INTEGER, " +
	 "NULL AS ORDINAL_POSITION INTEGER, " +
	 "NULL AS IS_NULLABLE VARCHAR(10) " +
       "FROM " +
         "DB.DBA.SYS_KEYS k, " +
	 "DB.DBA.SYS_KEY_PARTS kp, " +
	 "DB.DBA.SYS_COLS c " +
       "WHERE " +
         "name_part(k.KEY_TABLE,0) LIKE ? " +
	 "AND name_part(k.KEY_TABLE,1) LIKE ? " +
	 "AND name_part(k.KEY_TABLE,2) LIKE ? " +
	 "AND c.\"COLUMN\" LIKE ? " +
	 "AND c.\"COLUMN\" <> '_IDN' " +
	 "AND k.KEY_IS_MAIN = 1 " +
	 "AND k.KEY_MIGRATE_TO is null " +
	 "AND kp.KP_KEY_ID = k.KEY_ID " +
	 "AND COL_ID = KP_COL " +
       "ORDER BY k.KEY_TABLE, c.COL_ID";
   private static String getWideColumnsText_case2 =
       "SELECT " +
         "charset_recode (name_part(k.KEY_TABLE,0), 'UTF-8', '_WIDE_') AS TABLE_CAT NVARCHAR(128), " +
	 "charset_recode (name_part(k.KEY_TABLE,1), 'UTF-8', '_WIDE_') AS TABLE_SCHEM NVARCHAR(128), " +
	 "charset_recode (name_part(k.KEY_TABLE,2), 'UTF-8', '_WIDE_') AS TABLE_NAME NVARCHAR(128), "  +
	 "charset_recode (c.\"COLUMN\", 'UTF-8', '_WIDE_') AS COLUMN_NAME NVARCHAR(128), " +
	 "dv_to_sql_type(c.COL_DTP) AS DATA_TYPE SMALLINT," +
	 "dv_type_title(c.COL_DTP) AS TYPE_NAME VARCHAR(128), " +
	 "c.COL_PREC AS COLUMN_SIZE INTEGER, " +
	 "NULL AS BUFFER_LENGTH INTEGER, " +
	 "c.COL_SCALE AS DECIMAL_DIGITS SMALLINT," +
	 "2 AS NUM_PREC_RADIX SMALLINT, " +
	 "either(isnull(c.COL_NULLABLE),2,c.COL_NULLABLE) AS NULLABLE SMALLINT,"+
	 "NULL AS REMARKS VARCHAR(254), " +
	 "NULL AS COLUMN_DEF VARCHAR(128), " +
	 "NULL AS SQL_DATA_TYPE INTEGER, " +
	 "NULL AS SQL_DATETIME_SUB INTEGER," +
	 "NULL AS CHAR_OCTET_LENGTH INTEGER, " +
	 "NULL AS ORDINAL_POSITION INTEGER, " +
	 "NULL AS IS_NULLABLE VARCHAR(10) " +
       "FROM " +
         "DB.DBA.SYS_KEYS k, " +
	 "DB.DBA.SYS_KEY_PARTS kp, " +
	 "DB.DBA.SYS_COLS c " +
       "WHERE " +
         "charset_recode (upper(charset_recode (name_part(k.KEY_TABLE,0), 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8')" +
	 " LIKE charset_recode (upper(charset_recode (?, 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8') " +
	 "AND charset_recode (upper(charset_recode (name_part(k.KEY_TABLE,1), 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8')" +
	 " LIKE charset_recode (upper(charset_recode (?, 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8') " +
	 "AND charset_recode (upper(charset_recode (name_part(k.KEY_TABLE,2), 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8')" +
	 " LIKE charset_recode (upper(charset_recode (?, 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8') " +
	 "AND charset_recode (upper (charset_recode (c.\"COLUMN\", 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8')" +
	 " LIKE charset_recode (upper(charset_recode (?, 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8') " +
	 "AND c.\"COLUMN\" <> '_IDN' " +
	 "AND k.KEY_IS_MAIN = 1 " +
	 "AND k.KEY_MIGRATE_TO is null " +
	 "AND kp.KP_KEY_ID = k.KEY_ID " +
	 "AND COL_ID = KP_COL " +
     "ORDER BY k.KEY_TABLE, c.COL_ID";

   /**
    * Gets a description of table columns available in
    * the specified catalog.
    *
    * <P>Only column descriptions matching the catalog, schema, table
    * and column name criteria are returned.  They are ordered by
    * TABLE_SCHEM, TABLE_NAME and ORDINAL_POSITION.
    *
    * <P>Each column description has the following columns:
    *  <OL>
    *	<LI><B>TABLE_CAT</B> String => table catalog (may be null)
    *	<LI><B>TABLE_SCHEM</B> String => table schema (may be null)
    *	<LI><B>TABLE_NAME</B> String => table name
    *	<LI><B>COLUMN_NAME</B> String => column name
    *	<LI><B>DATA_TYPE</B> short => SQL type from java.sql.Types
    *	<LI><B>TYPE_NAME</B> String => Data source dependent type name,
    *  for a UDT the type name is fully qualified
    *	<LI><B>COLUMN_SIZE</B> int => column size.  For char or date
    *	    types this is the maximum number of characters, for numeric or
    *	    decimal types this is precision.
    *	<LI><B>BUFFER_LENGTH</B> is not used.
    *	<LI><B>DECIMAL_DIGITS</B> int => the number of fractional digits
    *	<LI><B>NUM_PREC_RADIX</B> int => Radix (typically either 10 or 2)
    *	<LI><B>NULLABLE</B> int => is NULL allowed?
    *      <UL>
    *      <LI> columnNoNulls - might not allow NULL values
    *      <LI> columnNullable - definitely allows NULL values
    *      <LI> columnNullableUnknown - nullability unknown
    *      </UL>
    *	<LI><B>REMARKS</B> String => comment describing column (may be null)
    * <LI><B>COLUMN_DEF</B> String => default value (may be null)
    *	<LI><B>SQL_DATA_TYPE</B> int => unused
    *	<LI><B>SQL_DATETIME_SUB</B> int => unused
    *	<LI><B>CHAR_OCTET_LENGTH</B> int => for char types the
    *       maximum number of bytes in the column
    *	<LI><B>ORDINAL_POSITION</B> int	=> index of column in table
    *      (starting at 1)
    *	<LI><B>IS_NULLABLE</B> String => "NO" means column definitely
    *      does not allow NULL values; "YES" means the column might
    *      allow NULL values.  An empty string means nobody knows.
    *  </OL>
    *
    * @param catalog a catalog name; "" retrieves those without a
    * catalog; null means drop catalog name from the selection criteria
    * @param schemaPattern a schema name pattern; "" retrieves those
    * without a schema
    * @param tableNamePattern a table name pattern
    * @param columnNamePattern a column name pattern
    * @return ResultSet - each row is a column description
    * @exception virtuoso.jdbc2.VirtuosoException if a database access error
    * occurs
    * @see #getSearchStringEscape
    */

         private DataTable GetSchemaColumns(string catalog, string schema, string table, string column)
         {
            DataTable dt = new DataTable("Columns");

            // Following schema mirrors System.Data.Odbc provider.
            // System.Data.SqlClient provider schema differs significantly.
            dt.Columns.Add("TABLE_CAT", typeof(string));
            dt.Columns.Add("TABLE_SCHEM", typeof(string));
            dt.Columns.Add("TABLE_NAME", typeof(string));
            dt.Columns.Add("COLUMN_NAME", typeof(string));
            dt.Columns.Add("DATA_TYPE", typeof(short));
            dt.Columns.Add("TYPE_NAME", typeof(string));
            dt.Columns.Add("COLUMN_SIZE", typeof(int));
            dt.Columns.Add("BUFFER_LENGTH", typeof(int));
            dt.Columns.Add("DECIMAL_DIGITS", typeof(short));
            dt.Columns.Add("NUM_PREC_RADIX", typeof(short));
            dt.Columns.Add("NULLABLE", typeof(short));
            dt.Columns.Add("REMARKS", typeof(string));
            dt.Columns.Add("COLUMN_DEF", typeof(string));
            dt.Columns.Add("SQL_DATA_TYPE", typeof(short));
            dt.Columns.Add("SQL_DATETIME_SUB", typeof(short));
            dt.Columns.Add("CHAR_OCTET_LENGTH", typeof(int));
            dt.Columns.Add("ORDINAL_POSITION", typeof(int));
            dt.Columns.Add("IS_NULLABLE", typeof(string));

            if(catalog == null)
               catalog = "";
            if(schema == null)
               schema = "";
            if(table == null)
               table = "";
            if(column == null)
               column = "";
            catalog = (catalog.Length == 0) ? "%" : catalog;
            schema = (schema.Length == 0) ? "%" : schema;
            table = (table.Length == 0) ? "%" : table;
            column = (column.Length == 0) ? "%" : column;
   
            DataTable dtColumns = new DataTable("Columns");
            String cmdText;
            cmdText = (innerConnection.IdentCase ==
          		CLI.IdentCase.SQL_IC_MIXED) ? getWideColumnsText_case2 :
          			getWideColumnsText_case0;
            VirtuosoCommand cmd = new VirtuosoCommand(cmdText ,this);
   
            VirtuosoParameter p1 = (VirtuosoParameter) cmd.CreateParameter();
            p1.Value = catalog;
            p1.ParameterName = ("@catalog");
            cmd.Parameters.Add (p1);
            VirtuosoParameter p2 = (VirtuosoParameter) cmd.CreateParameter();
            p2.Value = schema;
            p2.ParameterName = ("@schema");
            cmd.Parameters.Add (p2);
            VirtuosoParameter p3 = (VirtuosoParameter) cmd.CreateParameter();
            p3.Value = table;
            p3.ParameterName = ("@table");
            cmd.Parameters.Add (p3);
            VirtuosoParameter p4 = (VirtuosoParameter) cmd.CreateParameter();
            p4.Value = column;
            p4.ParameterName = ("@column");
            cmd.Parameters.Add (p4);
   
            VirtuosoDataReader reader = (VirtuosoDataReader)cmd.ExecuteReader();
            dtColumns.Load(reader);

            return dt;
         }

/* Half-way implementation by AK 12-APR-1997:
   fColType must be SQL_ROWVER and fScope and fNullable are ignored.
   13-APR-1997 AK Added also SQL_BEST_ROWID functionality.

   Because SQLSpecialColumns should return the results as a standard
   result set, ordered by SCOPE, and because SCOPE is always constant
   in this implementation (0 or NULL), we can use our own additional
   sorting with ORDER BY clause.
 */
    private static String sql_special_columnsw1_casemode_0 =
      "select" +
      " 0 AS \\SCOPE SMALLINT," +
      " charset_recode (SYS_COLS.\\COLUMN, 'UTF-8', '_WIDE_') AS \\COLUMN_NAME NVARCHAR(128),"	/* NOT NULL */ +
      " dv_to_sql_type(SYS_COLS.COL_DTP) AS \\DATA_TYPE SMALLINT,"/* NOT NULL */ +
      " case when (SYS_COLS.COL_DTP in (125, 132) and get_keyword ('xml_col', coalesce (SYS_COLS.COL_OPTIONS, vector ())) is not null) then 'XMLType' else dv_type_title(SYS_COLS.COL_DTP) end AS TYPE_NAME VARCHAR(128),\n" /*DV_BLOB=125, DV_BLOB_WIDE=132 */ +
      " case when (SYS_COLS.COL_PREC = 0 and SYS_COLS.COL_DTP in (125, 132)) then " + VARCHAR_UNSPEC_SIZE + " when (SYS_COLS.COL_PREC = 0 and SYS_COLS.COL_DTP = 225) then " + VARCHAR_UNSPEC_SIZE + " else SYS_COLS.COL_PREC end AS \\PRECISION INTEGER,\n" +
      " SYS_COLS.COL_PREC AS \\LENGTH INTEGER," +
      " SYS_COLS.COL_SCALE AS \\SCALE SMALLINT," +
      " 1 AS \\PSEUDO_COLUMN SMALLINT "	/* = SQL_PC_NOT_PSEUDO */ +
      "from DB.DBA.SYS_KEYS SYS_KEYS, DB.DBA.SYS_KEY_PARTS SYS_KEY_PARTS," +
      " DB.DBA.SYS_COLS SYS_COLS " +
      " where name_part(SYS_KEYS.KEY_TABLE,0) like ?" +
      "  and __any_grants (KEY_TABLE) " +
      "  and name_part(SYS_KEYS.KEY_TABLE,1) like ?" +
      "  and name_part(SYS_KEYS.KEY_TABLE,2) like ?" +
      "  and SYS_KEYS.KEY_IS_MAIN = 1" +
      "  and SYS_KEYS.KEY_MIGRATE_TO is NULL" +
      "  and SYS_KEY_PARTS.KP_KEY_ID = SYS_KEYS.KEY_ID" +
      "  and SYS_KEY_PARTS.KP_NTH < SYS_KEYS.KEY_DECL_PARTS" +
      "  and SYS_COLS.COL_ID = SYS_KEY_PARTS.KP_COL " +
      " order by SYS_KEYS.KEY_TABLE, SYS_KEY_PARTS.KP_NTH";

    private static String sql_special_columnsw1_casemode_2 =
      "select" +
      " 0 AS \\SCOPE SMALLINT," +
      " charset_recode (SYS_COLS.\\COLUMN, 'UTF-8', '_WIDE_') AS \\COLUMN_NAME NVARCHAR(128),"	/* NOT NULL */ +
      " dv_to_sql_type(SYS_COLS.COL_DTP) AS \\DATA_TYPE SMALLINT,"/* NOT NULL */ +
      " case when (SYS_COLS.COL_DTP in (125, 132) and get_keyword ('xml_col', coalesce (SYS_COLS.COL_OPTIONS, vector ())) is not null) then 'XMLType' else dv_type_title(SYS_COLS.COL_DTP) end AS TYPE_NAME VARCHAR(128),\n" /*DV_BLOB=125, DV_BLOB_WIDE=132 */ +
      " case when (SYS_COLS.COL_PREC = 0 and SYS_COLS.COL_DTP in (125, 132)) then " + VARCHAR_UNSPEC_SIZE + "  when (SYS_COLS.COL_PREC = 0 and SYS_COLS.COL_DTP = 225) then " + VARCHAR_UNSPEC_SIZE + " else SYS_COLS.COL_PREC end AS \\PRECISION INTEGER,\n" +
      " SYS_COLS.COL_PREC AS \\LENGTH INTEGER," +
      " SYS_COLS.COL_SCALE AS \\SCALE SMALLINT," +
      " 1 AS \\PSEUDO_COLUMN SMALLINT "	/* = SQL_PC_NOT_PSEUDO */ +
      "from DB.DBA.SYS_KEYS SYS_KEYS, DB.DBA.SYS_KEY_PARTS SYS_KEY_PARTS," +
      " DB.DBA.SYS_COLS SYS_COLS " +
      " where charset_recode (upper(charset_recode (name_part(SYS_KEYS.KEY_TABLE,0), 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8') like charset_recode (upper(charset_recode (?, 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8')" +
      "  and __any_grants (KEY_TABLE) " +
      "  and charset_recode (upper(charset_recode (name_part(SYS_KEYS.KEY_TABLE,1), 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8') like charset_recode (upper(charset_recode (?, 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8')" +
      "  and charset_recode (upper(charset_recode (name_part(SYS_KEYS.KEY_TABLE,2), 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8') like charset_recode (upper(charset_recode (?, 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8')" +
      "  and SYS_KEYS.KEY_IS_MAIN = 1" +
      "  and SYS_KEYS.KEY_MIGRATE_TO is NULL" +
      "  and SYS_KEY_PARTS.KP_KEY_ID = SYS_KEYS.KEY_ID" +
      "  and SYS_KEY_PARTS.KP_NTH < SYS_KEYS.KEY_DECL_PARTS" +
      "  and SYS_COLS.COL_ID = SYS_KEY_PARTS.KP_COL " +
      " order by SYS_KEYS.KEY_TABLE, SYS_KEY_PARTS.KP_NTH";

    private static String sql_special_columnsw2_casemode_0 =
      "select" +
      " null as \\SCOPE smallint," +
      " charset_recode (\\COLUMN, 'UTF-8', '_WIDE_') as \\COLUMN_NAME nvarchar(128),"	/* not null */ +
      " dv_to_sql_type(COL_DTP) as \\DATA_TYPE smallint,"	/* not null */ +
      " case when (SYS_COLS.COL_DTP in (125, 132) and get_keyword ('xml_col', coalesce (SYS_COLS.COL_OPTIONS, vector ())) is not null) then 'XMLType' else dv_type_title(SYS_COLS.COL_DTP) end AS TYPE_NAME VARCHAR(128),\n" /* DV_BLOB=125, DV_BLOB_WIDE=132 */ +
      " case when (SYS_COLS.COL_PREC = 0 and SYS_COLS.COL_DTP in (125, 132)) then " + VARCHAR_UNSPEC_SIZE + "  when (SYS_COLS.COL_PREC = 0 and SYS_COLS.COL_DTP = 225) then " + VARCHAR_UNSPEC_SIZE + " else SYS_COLS.COL_PREC end AS \\PRECISION INTEGER,\n" +
      " COL_PREC as \\LENGTH integer," +
      " COL_SCALE as \\SCALE smallint," +
      " 1 as \\PSEUDO_COLUMN smallint "	/* = sql_pc_not_pseudo */ +
      "from DB.DBA.SYS_COLS " +
      "where \\COL_DTP = 128" +
      "  and name_part(\\TABLE,0) like ?" +
      "  and name_part(\\TABLE,1) like ?" +
      "  and name_part(\\TABLE,2) like ? " +
      "order by \\TABLE, \\COL_ID";

    private static String sql_special_columnsw2_casemode_2 =
      "select" +
      " NULL as \\SCOPE smallint," +
      " charset_recode (\\COLUMN, 'UTF-8', '_WIDE_') as \\COLUMN_NAME nvarchar(128),"	/* NOT NULL */ +
      " dv_to_sql_type(COL_DTP) as \\DATA_TYPE smallint,"	/* NOT NULL */ +
      " case when (SYS_COLS.COL_DTP in (125, 132) and get_keyword ('xml_col', coalesce (SYS_COLS.COL_OPTIONS, vector ())) is not null) then 'XMLType' else dv_type_title(SYS_COLS.COL_DTP) end AS TYPE_NAME VARCHAR(128),\n" /* DV_BLOB=125, DV_BLOB_WIDE=132 */ +
      " case when (SYS_COLS.COL_PREC = 0 and SYS_COLS.COL_DTP in (125, 132)) then " + VARCHAR_UNSPEC_SIZE + "  when (SYS_COLS.COL_PREC = 0 and SYS_COLS.COL_DTP = 225) then " + VARCHAR_UNSPEC_SIZE + " else SYS_COLS.COL_PREC end AS \\PRECISION INTEGER,\n" +
      " COL_PREC as \\LENGTH integer," +
      " COL_SCALE as \\SCALE smallint," +
      " 1 as \\PSEUDO_COLUMN smallint "	/* = SQL_PC_NOT_PSEUDO */ +
      "from DB.DBA.SYS_COLS " +
      "where \\COL_DTP = 128" +
      "  and charset_recode (upper(charset_recode (name_part(\\TABLE,0), 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8') like charset_recode (upper(charset_recode (?, 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8')" +
      "  and charset_recode (upper(charset_recode (name_part(\\TABLE,1), 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8') like charset_recode (upper(charset_recode (?, 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8')" +
      "  and charset_recode (upper(charset_recode (name_part(\\TABLE,2), 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8') like charset_recode (upper(charset_recode (?, 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8') " +
      "order by \\TABLE, \\COL_ID";

        private DataTable GetSchemaSpecialColumns(
            string identifierType,
            string catalog,
            string schema,
            string table,
            string scope,
            string nullable
            )
        {
            if(catalog == null)
               catalog = "";
            if(schema == null)
               schema = "";
            if(table == null)
               table = "";
            CLI.IdentifierType _identifierType;
            CLI.Scope _scope;
            CLI.Nullable _nullable;

            // Convert non-string restrictions from supplied string

            if (String.Compare(identifierType,
                SpecialColumnsRestrictions.IDENTIFIER_TYPE_BEST_ROWID) == 0)
                _identifierType = CLI.IdentifierType.SQL_BEST_ROWID;
            else if (String.Compare(identifierType,
                SpecialColumnsRestrictions.IDENTIFIER_TYPE_ROWVER) == 0)
                _identifierType = CLI.IdentifierType.SQL_ROWVER;
            else
                throw new ArgumentOutOfRangeException(
#if MONO
                    "SpecialColumnsRestrictions",
                    "IDENTIFIER_TYPE restriction out of range"); 
#else
                    "IDENTIFIER_TYPE restriction out of range", 
                    (Exception) null);
#endif

            if (String.Compare(scope, 
                SpecialColumnsRestrictions.SCOPE_CURROW) == 0)
                _scope = CLI.Scope.SQL_SCOPE_CURROW;
            else if (String.Compare(scope, 
                SpecialColumnsRestrictions.SCOPE_SESSION) == 0)
                _scope = CLI.Scope.SQL_SCOPE_SESSION;
            else if (String.Compare(scope, 
                SpecialColumnsRestrictions.SCOPE_TRANSACTION) == 0)
                _scope = CLI.Scope.SQL_SCOPE_TRANSACTION;
            else
                throw new ArgumentOutOfRangeException(
#if MONO
                    "SpecialColumnsRestrictions",
                    "SCOPE restriction out of range"); 
#else
                    "SCOPE restriction out of range", 
                    (Exception) null);
#endif

            if (String.Compare(nullable,
                SpecialColumnsRestrictions.NO_NULLS) == 0)
                _nullable = CLI.Nullable.SQL_NO_NULLS;
            else if (String.Compare(nullable,
                SpecialColumnsRestrictions.NULLABLE) == 0)
                _nullable = CLI.Nullable.SQL_NULLABLE;
            else
                throw new ArgumentOutOfRangeException(
#if MONO
                    "SpecialColumnsRestrictions",
                    "NULLABLE restriction out of range"); 
#else
                    "NULLABLE restriction out of range", 
                    (Exception) null);
#endif

            if (table == null || table.Trim().Length == 0)
                throw new ArgumentOutOfRangeException(
#if MONO
                    "table",
                    "TABLE_NAME restriction cannot be null or empty");
#else
                    "TABLE_NAME restriction cannot be null or empty", 
                    (Exception) null);
#endif

            DataTable dt = new DataTable("SpecialColumns");

/* 
 * Comment from virtodbc implementation for SQLSpecialColumns
 */

/* fColType must be one of the following values:
   SQL_BEST_ROWID: Returns the optimal column or set of columns that,
   by retrieving values from the column or columns, allows any row in
   the specified table to be uniquely identified. A column can be either
   a pseudocolumn specifically designed for this purpose
   (as in Oracle ROWID or Ingres TID) or the column or columns of any
   unique index for the table.

   Well, we implement this later better. Now just choose all the columns
   of the primary key.
   (0 = SQL_SCOPE_CURROW) Let's use the most narrow scope as I am not
   really sure about this. fScope argument is
   ignored anyway.
   (1 = SQL_SCOPE_TRANSACTION)
   (2 = SQL_SCOPE_SESSION)
 */
            String cmdText;
            if (_identifierType != CLI.IdentifierType.SQL_ROWVER)
              {
                cmdText = (innerConnection.IdentCase ==
              		CLI.IdentCase.SQL_IC_MIXED) ? 
						sql_special_columnsw1_casemode_2:
              	        sql_special_columnsw1_casemode_0;
              }
            else
              {
/*
   fColType is SQL_ROWVER: Returns the column or columns in the
   specified table, if any, that are automatically updated by the
   data source when any value in the row is updated by any transaction
   as in SQLBase ROWID or Sybase (and KUBL!) TIMESTAMP (= COL_DTP 128).
 */
                cmdText = (innerConnection.IdentCase ==
                    CLI.IdentCase.SQL_IC_MIXED) ? 
                        sql_special_columnsw2_casemode_2:
                        sql_special_columnsw2_casemode_0;
      /* With COL_ID returns columns in the same order as they were defined
         with create table. Without it they would be in alphabetical order. */
              }

            VirtuosoCommand cmd = new VirtuosoCommand(cmdText ,this);
  
            VirtuosoParameter p1 = (VirtuosoParameter) cmd.CreateParameter();
            p1.Value = catalog;
            p1.ParameterName = ("@catalog");
            cmd.Parameters.Add (p1);
            VirtuosoParameter p2 = (VirtuosoParameter) cmd.CreateParameter();
            p2.Value = schema;
            p2.ParameterName = ("@schema");
            cmd.Parameters.Add (p2);
            VirtuosoParameter p3 = (VirtuosoParameter) cmd.CreateParameter();
            p3.Value = table;
            p3.ParameterName = ("@table");
            cmd.Parameters.Add (p3);
                    
  
            VirtuosoDataReader reader = (VirtuosoDataReader)cmd.ExecuteReader();
            dt.Load(reader);

            return dt;
        }

    private static int SQL_INDEX_OBJECT_ID_STR = 8;

    public static String sql_statistics_textw_casemode_0 =
    "select" +
    " charset_recode (name_part(SYS_KEYS.KEY_TABLE,0), 'UTF-8', '_WIDE_') AS \\TABLE_CAT NVARCHAR(128)," +
    " charset_recode (name_part(SYS_KEYS.KEY_TABLE,1), 'UTF-8', '_WIDE_') AS \\TABLE_SCHEM NVARCHAR(128)," +
    " charset_recode (name_part(SYS_KEYS.KEY_TABLE,2), 'UTF-8', '_WIDE_') AS \\TABLE_NAME NVARCHAR(128)," +/* NOT NULL */
    " iszero(SYS_KEYS.KEY_IS_UNIQUE) AS \\NON_UNIQUE SMALLINT," +
    " charset_recode (name_part (SYS_KEYS.KEY_TABLE, 0), 'UTF-8', '_WIDE_') AS \\INDEX_QUALIFIER NVARCHAR(128)," +
    " charset_recode (name_part (SYS_KEYS.KEY_NAME, 2), 'UTF-8', '_WIDE_') AS \\INDEX_NAME NVARCHAR(128)," +
    " ((SYS_KEYS.KEY_IS_OBJECT_ID*" + SQL_INDEX_OBJECT_ID_STR + ") + " +
    "(3-(2*iszero(SYS_KEYS.KEY_CLUSTER_ON_ID)))) AS \\TYPE SMALLINT," + /* NOT NULL */
    " (SYS_KEY_PARTS.KP_NTH+1) AS \\ORDINAL_POSITION SMALLINT," +
    " charset_recode (SYS_COLS.\\COLUMN, 'UTF-8', '_WIDE_') AS \\COLUMN_NAME NVARCHAR(128)," +
    " NULL AS \\ASC_OR_DESC CHAR(1)," +	/* Value is either NULL, 'A' or 'D' */
    " NULL AS \\CARDINALITY INTEGER," +
    " NULL AS \\PAGES INTEGER," +
    " NULL AS \\FILTER_CONDITION VARCHAR(128) " +
    "from DB.DBA.SYS_KEYS SYS_KEYS, DB.DBA.SYS_KEY_PARTS SYS_KEY_PARTS," +
    " DB.DBA.SYS_COLS SYS_COLS " +
    "where name_part(SYS_KEYS.KEY_TABLE,0) like ?" +
    "  and __any_grants (SYS_KEYS.KEY_TABLE) " +
    "  and name_part(SYS_KEYS.KEY_TABLE,1) like ?" +
    "  and name_part(SYS_KEYS.KEY_TABLE,2) like ?" +
    "  and SYS_KEYS.KEY_IS_UNIQUE >= ?" +
    "  and SYS_KEYS.KEY_MIGRATE_TO is NULL" +
    "  and SYS_KEY_PARTS.KP_KEY_ID = SYS_KEYS.KEY_ID" +
    "  and SYS_KEY_PARTS.KP_NTH < SYS_KEYS.KEY_DECL_PARTS" +
    "  and SYS_COLS.COL_ID = SYS_KEY_PARTS.KP_COL" +
    "  and SYS_COLS.\\COLUMN <> '_IDN' " +
    "order by SYS_KEYS.KEY_TABLE, SYS_KEYS.KEY_NAME, SYS_KEY_PARTS.KP_NTH";

    public static String sql_statistics_textw_casemode_2 =
    "select" +
    " charset_recode (name_part(SYS_KEYS.KEY_TABLE,0), 'UTF-8', '_WIDE_') AS TABLE_CAT NVARCHAR(128)," +
    " charset_recode (name_part(SYS_KEYS.KEY_TABLE,1), 'UTF-8', '_WIDE_') AS \\TABLE_SCHEM NVARCHAR(128)," +
    " charset_recode (name_part(SYS_KEYS.KEY_TABLE,2), 'UTF-8', '_WIDE_') AS \\TABLE_NAME NVARCHAR(128)," + /* NOT NULL */
    " iszero(SYS_KEYS.KEY_IS_UNIQUE) AS \\NON_UNIQUE SMALLINT," +
    " charset_recode (name_part (SYS_KEYS.KEY_TABLE, 0), 'UTF-8', '_WIDE_') AS \\INDEX_QUALIFIER NVARCHAR(128)," +
    " charset_recode (name_part (SYS_KEYS.KEY_NAME, 2), 'UTF-8', '_WIDE_') AS \\INDEX_NAME NVARCHAR(128)," +
    " ((SYS_KEYS.KEY_IS_OBJECT_ID*" + SQL_INDEX_OBJECT_ID_STR + ") + " +
    "(3-(2*iszero(SYS_KEYS.KEY_CLUSTER_ON_ID)))) AS \\TYPE SMALLINT," + /* NOT NULL */
    " (SYS_KEY_PARTS.KP_NTH+1) AS \\ORDINAL_POSITION SMALLINT," +
    " charset_recode (SYS_COLS.\\COLUMN, 'UTF-8', '_WIDE_') AS \\COLUMN_NAME NVARCHAR(128)," +
    " NULL AS \\ASC_OR_DESC CHAR(1)," +	/* Value is either NULL, 'A' or 'D' */
    " NULL AS \\CARDINALITY INTEGER," +
    " NULL AS \\PAGES INTEGER," +
    " NULL AS \\FILTER_CONDITION VARCHAR(128) " +
    "from DB.DBA.SYS_KEYS SYS_KEYS, DB.DBA.SYS_KEY_PARTS SYS_KEY_PARTS," +
    " DB.DBA.SYS_COLS SYS_COLS " +
    "where charset_recode (upper(charset_recode (name_part(SYS_KEYS.KEY_TABLE,0), 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8') like charset_recode (upper(charset_recode (?, 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8')" +
    "  and __any_grants (SYS_KEYS.KEY_TABLE) " +
    "  and charset_recode (upper(charset_recode (name_part(SYS_KEYS.KEY_TABLE,1), 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8') like charset_recode (upper(charset_recode (?, 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8')" +
    "  and charset_recode (upper(charset_recode (name_part(SYS_KEYS.KEY_TABLE,2), 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8') like charset_recode (upper(charset_recode (?, 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8')" +
    "  and SYS_KEYS.KEY_IS_UNIQUE >= ?" +
    "  and SYS_KEYS.KEY_MIGRATE_TO is NULL" +
    "  and SYS_KEY_PARTS.KP_KEY_ID = SYS_KEYS.KEY_ID" +
    "  and SYS_KEY_PARTS.KP_NTH < SYS_KEYS.KEY_DECL_PARTS" +
    "  and SYS_COLS.COL_ID = SYS_KEY_PARTS.KP_COL" +
    "  and SYS_COLS.\\COLUMN <> '_IDN' " +
    "order by SYS_KEYS.KEY_TABLE, SYS_KEYS.KEY_NAME, SYS_KEY_PARTS.KP_NTH";
   /**
    * Gets a description of a table's indices and statistics. They are
    * ordered by NON_UNIQUE, TYPE, INDEX_NAME, and ORDINAL_POSITION.
    *
    * <P>Each index column description has the following columns:
    *  <OL>
    *	<LI><B>TABLE_CAT</B> String => table catalog (may be null)
    *	<LI><B>TABLE_SCHEM</B> String => table schema (may be null)
    *	<LI><B>TABLE_NAME</B> String => table name
    *	<LI><B>NON_UNIQUE</B> boolean => Can index values be non-unique?
    *      false when TYPE is tableIndexStatistic
    *	<LI><B>INDEX_QUALIFIER</B> String => index catalog (may be null);
    *      null when TYPE is tableIndexStatistic
    *	<LI><B>INDEX_NAME</B> String => index name; null when TYPE is
    *      tableIndexStatistic
    *	<LI><B>TYPE</B> short => index type:
    *      <UL>
    *      <LI> tableIndexStatistic - this identifies table statistics that
    *      are
    *           returned in conjunction with a table's index descriptions
    *      <LI> tableIndexClustered - this is a clustered index
    *      <LI> tableIndexHashed - this is a hashed index
    *      <LI> tableIndexOther - this is some other style of index
    *      </UL>
    *	<LI><B>ORDINAL_POSITION</B> short => column sequence number
    *      within index; zero when TYPE is tableIndexStatistic
    *	<LI><B>COLUMN_NAME</B> String => column name; null when TYPE is
    *      tableIndexStatistic
    *	<LI><B>ASC_OR_DESC</B> String => column sort sequence, "A" =>
    *	ascending,
    *      "D" => descending, may be null if sort sequence is not supported;
    *      null when TYPE is tableIndexStatistic
    *	<LI><B>CARDINALITY</B> int => When TYPE is tableIndexStatistic, then
    *      this is the number of rows in the table; otherwise, it is the
    *      number of unique values in the index.
    *	<LI><B>PAGES</B> int => When TYPE is  tableIndexStatistic then
    *      this is the number of pages used for the table, otherwise it
    *      is the number of pages used for the current index.
    *	<LI><B>FILTER_CONDITION</B> String => Filter condition, if any.
    *      (may be null)
    *  </OL>
    *
    * @param catalog a catalog name; "" retrieves those without a
    * catalog; null means drop catalog name from the selection criteria
    * @param schema a schema name; "" retrieves those without a schema
    * @param table a table name
    * @param unique when true, return only indices for unique values;
    *     when false, return indices regardless of whether unique or not
    * @param approximate when true, result is allowed to reflect approximate
    *     or out of data values; when false, results are requested to be
    *     accurate
    * @return ResultSet - each row is an index column description
    * @exception virtuoso.jdbc2.VirtuosoException if a database access error
    * occurs
    */

        private DataTable GetSchemaIndexes(string catalog, string schema, string table, string index)
        {
            DataTable dt = new DataTable("Indexes");

            if(catalog == null)
               catalog = "";
            if(schema == null)
               schema = "";
            if(table == null)
               table = "";
            catalog = catalog == "" ? "%" : catalog;
            schema =  schema == "" ? "%" : schema;
            table = table == "" ? "%" : table;

            String cmdText;
            cmdText = (innerConnection.IdentCase ==
         		CLI.IdentCase.SQL_IC_MIXED) ? 
					sql_statistics_textw_casemode_2:
           	        sql_statistics_textw_casemode_0;

            VirtuosoCommand cmd = new VirtuosoCommand(cmdText ,this);
  
            VirtuosoParameter p1 = (VirtuosoParameter) cmd.CreateParameter();
            p1.Value = catalog;
            p1.ParameterName = ("@catalog");
            cmd.Parameters.Add (p1);
            VirtuosoParameter p2 = (VirtuosoParameter) cmd.CreateParameter();
            p2.Value = schema;
            p2.ParameterName = ("@schema");
            cmd.Parameters.Add (p2);
            VirtuosoParameter p3 = (VirtuosoParameter) cmd.CreateParameter();
            p3.Value = table;
            p3.ParameterName = ("@table");
            cmd.Parameters.Add (p3);
            VirtuosoParameter p4 = (VirtuosoParameter) cmd.CreateParameter();
            p4.Value = CLI.IndexType.SQL_INDEX_ALL;
            p4.ParameterName = ("@unique");
            cmd.Parameters.Add (p4);
                    
            VirtuosoDataReader reader = (VirtuosoDataReader)cmd.ExecuteReader();
            DataTable dtSqlStats = new DataTable("SQLStatistics");
            dtSqlStats.Load(reader);

            // Filter on any index restriction and exclude SQL_TABLE_STAT rows
            string indexFilter = "";
            if (index != null && index.Trim().Length > 0)
                indexFilter = " AND INDEX_NAME LIKE '" + index + "'";
            DataView dv = dtSqlStats.DefaultView;
            dv.RowFilter = "TYPE <> 0" + indexFilter;

            dt = dv.ToTable();

            return dt;
        }


   private static String getWideProceduresCaseMode0 =
       "SELECT " +
         "charset_recode (name_part (\\P_NAME, 0), 'UTF-8', '_WIDE_') AS PROCEDURE_CAT NVARCHAR(128)," +
	 "charset_recode (name_part (\\P_NAME, 1), 'UTF-8', '_WIDE_') AS PROCEDURE_SCHEM NVARCHAR(128)," +
	 "charset_recode (name_part (\\P_NAME, 2), 'UTF-8', '_WIDE_') AS PROCEDURE_NAME NVARCHAR(128)," +
	 "\\P_N_IN AS RES1," +
	 "\\P_N_OUT AS RES2," +
	 "\\P_N_R_SETS AS RES3," +
	 "\\P_COMMENT AS REMARKS VARCHAR(254)," +
	 "either(isnull(P_TYPE),0,P_TYPE) AS PROCEDURE_TYPE SMALLINT " +
       "FROM DB.DBA.SYS_PROCEDURES " +
       "WHERE " +
         "name_part (\\P_NAME, 0) like ? AND " +
	 "name_part (\\P_NAME, 1) like ? AND " +
	 "name_part (\\P_NAME, 2) like ? AND " +
	 "__proc_exists (\\P_NAME) is not null " +
       "ORDER BY P_QUAL, P_NAME";

   private static String getWideProceduresCaseMode2 =
       "SELECT " +
         "charset_recode (name_part (\\P_NAME, 0), 'UTF-8', '_WIDE_') AS PROCEDURE_CAT NVARCHAR(128)," +
	 "charset_recode (name_part (\\P_NAME, 1), 'UTF-8', '_WIDE_') AS PROCEDURE_SCHEM NVARCHAR(128)," +
	 "charset_recode (name_part (\\P_NAME, 2), 'UTF-8', '_WIDE_') AS PROCEDURE_NAME NVARCHAR(128)," +
	 "\\P_N_IN AS RES1," +
	 "\\P_N_OUT AS RES2," +
	 "\\P_N_R_SETS AS RES3," +
	 "\\P_COMMENT AS REMARKS VARCHAR(254)," +
	 "either(isnull(P_TYPE),0,P_TYPE) AS PROCEDURE_TYPE SMALLINT " +
       "FROM DB.DBA.SYS_PROCEDURES " +
       "WHERE " +
         "charset_recode (upper (charset_recode (name_part (\\P_NAME, 0), 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8')" +
	 " like charset_recode (upper(charset_recode (?, 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8') AND " +
	 "charset_recode (upper (charset_recode (name_part (\\P_NAME, 1), 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8')" +
	 " like charset_recode (upper(charset_recode (?, 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8') AND " +
	 "charset_recode (upper (charset_recode (name_part (\\P_NAME, 2), 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8')" +
	 " like charset_recode (upper(charset_recode (?, 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8') AND " +
	 "__proc_exists (\\P_NAME) is not null " +
       "ORDER BY P_QUAL, P_NAME";


   /**
    * Gets a description of the stored procedures available in a
    * catalog.
    *
    * <P>Only procedure descriptions matching the schema and
    * procedure name criteria are returned.  They are ordered by
    * PROCEDURE_SCHEM, and PROCEDURE_NAME.
    *
    * <P>Each procedure description has the following columns:
    *  <OL>
    *	<LI><B>PROCEDURE_CAT</B> String => procedure catalog (may be null)
    *	<LI><B>PROCEDURE_SCHEM</B> String => procedure schema (may be null)
    *	<LI><B>PROCEDURE_NAME</B> String => procedure name
    *  <LI> reserved for future use
    *  <LI> reserved for future use
    *  <LI> reserved for future use
    *	<LI><B>REMARKS</B> String => explanatory comment on the procedure
    *	<LI><B>PROCEDURE_TYPE</B> short => kind of procedure:
    *      <UL>
    *      <LI> procedureResultUnknown - May return a result
    *      <LI> procedureNoResult - Does not return a result
    *      <LI> procedureReturnsResult - Returns a result
    *      </UL>
    *  </OL>
    *
    * @param catalog a catalog name; "" retrieves those without a
    * catalog; null means drop catalog name from the selection criteria
    * @param schemaPattern a schema name pattern; "" retrieves those
    * without a schema
    * @param procedureNamePattern a procedure name pattern
    * @return ResultSet - each row is a procedure description
    * @exception virtuoso.jdbc2.VirtuosoException if a database access error
    * occurs
    * @see #getSearchStringEscape
    */
         private DataTable GetSchemaProcedures(string catalog, string schema, string procedure, string type)
         {
            CLI.ProcedureType procType = CLI.ProcedureType.SQL_PT_UNKNOWN;

            if (type != null && type.Trim().Length > 0)
            {
                try
                {
                    procType = (CLI.ProcedureType)Int32.Parse(type);
                }
                catch
                {
                    throw new ArgumentOutOfRangeException("The string received for a PROCEDURE_TYPE restriction must " +
                       "parse to one of the following integer values: SQL_PT_UNKNOWN(0), SQL_PT_PROCEDURE(1) or " +
                       "SQL_PT_FUNCTION(2)");
                }
            }


            if(catalog == null)
               catalog = "%";
            if(schema == null)
               schema = "%";
            if(procedure == null)
               procedure = "%";
   
            DataTable dt = new DataTable("Procedures");
   
            String cmdText;
            cmdText = innerConnection.IdentCase == CLI.IdentCase.SQL_IC_MIXED ?
          	getWideProceduresCaseMode2 :
          	getWideProceduresCaseMode0;
            VirtuosoCommand cmd = new VirtuosoCommand(cmdText ,this);
   
            VirtuosoParameter p1 = (VirtuosoParameter) cmd.CreateParameter();
            p1.Value = catalog;
            p1.ParameterName = ("@catalog");
            cmd.Parameters.Add (p1);
            VirtuosoParameter p2 = (VirtuosoParameter) cmd.CreateParameter();
            p2.Value = schema;
            p2.ParameterName = ("@schema");
            cmd.Parameters.Add (p2);
            VirtuosoParameter p3 = (VirtuosoParameter) cmd.CreateParameter();
            p3.Value = procedure;
            p3.ParameterName = ("@procedure");
            cmd.Parameters.Add (p3);
   
            VirtuosoDataReader reader = (VirtuosoDataReader)cmd.ExecuteReader();
            dt.Load(reader);
            // Filter on the 'type' restriction here. 
            // The underlying SQLProcedures call doesn't support this.
            if (procType != CLI.ProcedureType.SQL_PT_UNKNOWN)
            {
                foreach (DataRow dr in dt.Rows)
                {
                    if (dr[7] != null)
                    {
                      int iProcType = Int32.Parse(dr[7].ToString());
                      if (iProcType != (int)CLI.ProcedureType.SQL_PT_UNKNOWN &&
          				iProcType != (int)procType)
                          dt.Rows.Remove (dr);
                    }
                }
            }
            dt.AcceptChanges();
   
            return dt;
         }

   private static String get_wide_pk_case0 =
       "SELECT " +
         "charset_recode (name_part(v1.KEY_TABLE,0), 'UTF-8', '_WIDE_') AS \\TABLE_CAT NVARCHAR(128), " +
	 "charset_recode (name_part(v1.KEY_TABLE,1), 'UTF-8', '_WIDE_') AS \\TABLE_SCHEM NVARCHAR(128), " +
	 "charset_recode (name_part(v1.KEY_TABLE,2), 'UTF-8', '_WIDE_') AS \\TABLE_NAME NVARCHAR(128), " +
	 "charset_recode (DB.DBA.SYS_COLS.\"COLUMN\", 'UTF-8', '_WIDE_') AS \\COLUMN_NAME NVARCHAR(128), " +
	 "(kp.KP_NTH+1) AS \\KEY_SEQ SMALLINT, " +
	 "charset_recode (name_part (v1.KEY_NAME, 2), 'UTF-8', '_WIDE_') AS \\PK_NAME VARCHAR(128) " +
       "FROM " +
         "DB.DBA.SYS_KEYS v1, " +
	 "DB.DBA.SYS_KEYS v2, " +
	 "DB.DBA.SYS_KEY_PARTS kp, " +
	 "DB.DBA.SYS_COLS " +
       "WHERE " +
         "name_part(v1.KEY_TABLE,0) LIKE ? " +
	 "AND name_part(v1.KEY_TABLE,1) LIKE ? " +
	 "AND name_part(v1.KEY_TABLE,2) LIKE ? " +
	 "AND __any_grants (v1.KEY_TABLE) " +
	 "AND v1.KEY_IS_MAIN = 1 " +
	 "AND v1.KEY_MIGRATE_TO is NULL " +
	 "AND v1.KEY_SUPER_ID = v2.KEY_ID " +
	 "AND kp.KP_KEY_ID = v1.KEY_ID " +
	 "AND kp.KP_NTH < v1.KEY_DECL_PARTS " +
	 "AND DB.DBA.SYS_COLS.COL_ID = kp.KP_COL " +
	 "AND DB.DBA.SYS_COLS.\"COLUMN\" <> '_IDN' " +
       "ORDER BY v1.KEY_TABLE, kp.KP_NTH";

   private static String get_wide_pk_case2 =
       "SELECT " +
         "charset_recode (name_part(v1.KEY_TABLE,0), 'UTF-8', '_WIDE_') AS \\TABLE_CAT NVARCHAR(128), " +
	 "charset_recode (name_part(v1.KEY_TABLE,1), 'UTF-8', '_WIDE_') AS \\TABLE_SCHEM NVARCHAR(128), " +
	 "charset_recode (name_part(v1.KEY_TABLE,2), 'UTF-8', '_WIDE_') AS \\TABLE_NAME NVARCHAR(128), " +
	 "charset_recode (DB.DBA.SYS_COLS.\"COLUMN\", 'UTF-8', '_WIDE_') AS \\COLUMN_NAME NVARCHAR(128), " +
	 "(kp.KP_NTH+1) AS \\KEY_SEQ SMALLINT, " +
	 "charset_recode (name_part (v1.KEY_NAME, 2), 'UTF-8', '_WIDE_') AS \\PK_NAME VARCHAR(128) " +
       "FROM " +
         "DB.DBA.SYS_KEYS v1, " +
	 "DB.DBA.SYS_KEYS v2, " +
	 "DB.DBA.SYS_KEY_PARTS kp, " +
	 "DB.DBA.SYS_COLS " +
       "WHERE " +
         "charset_recode (upper (charset_recode (name_part(v1.KEY_TABLE,0), 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8')"+
	 " LIKE charset_recode (upper (charset_recode (?, 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8') " +
	 "AND charset_recode (upper (charset_recode (name_part(v1.KEY_TABLE,1), 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8')" +
	 " LIKE charset_recode (upper (charset_recode (?, 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8') " +
	 "AND charset_recode (upper (charset_recode (name_part(v1.KEY_TABLE,2), 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8')" +
	 " LIKE charset_recode (upper (charset_recode (?, 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8') " +
	 "AND __any_grants (v1.KEY_TABLE) " +
	 "AND v1.KEY_IS_MAIN = 1 " +
	 "AND v1.KEY_MIGRATE_TO is NULL " +
	 "AND v1.KEY_SUPER_ID = v2.KEY_ID " +
	 "AND kp.KP_KEY_ID = v1.KEY_ID " +
	 "AND kp.KP_NTH < v1.KEY_DECL_PARTS " +
	 "AND DB.DBA.SYS_COLS.COL_ID = kp.KP_COL " +
	 "AND DB.DBA.SYS_COLS.\"COLUMN\" <> '_IDN' " +
       "ORDER BY v1.KEY_TABLE, kp.KP_NTH";

   /**
    * Gets a description of a table's primary key columns.  They
    * are ordered by COLUMN_NAME.
    *
    * <P>Each primary key column description has the following columns:
    *  <OL>
    *	<LI><B>TABLE_CAT</B> String => table catalog (may be null)
    *	<LI><B>TABLE_SCHEM</B> String => table schema (may be null)
    *	<LI><B>TABLE_NAME</B> String => table name
    *	<LI><B>COLUMN_NAME</B> String => column name
    *	<LI><B>KEY_SEQ</B> short => sequence number within primary key
    *	<LI><B>PK_NAME</B> String => primary key name (may be null)
    *  </OL>
    *
    * @param catalog a catalog name; "" retrieves those without a
    * catalog; null means drop catalog name from the selection criteria
    * @param schema a schema name; "" retrieves those
    * without a schema
    * @param table a table name
    * @return ResultSet - each row is a primary key column description
    * @exception virtuoso.jdbc2.VirtuosoException if a database access error
    * occurs
    */
        private DataTable GetSchemaPrimaryKeys(string catalog, string schema, string table)
        {
            DataTable dt = new DataTable("PrimaryKeys");

            if(catalog == null)
               catalog = "";
            if(schema == null)
               schema = "";
            if(table == null)
               table = "";
            catalog = catalog == "" ? "%" : catalog;
            schema = schema == "" ? "%" : schema;
            table = table == "" ? "%" : table;

            String cmdText;
  	        cmdText = innerConnection.IdentCase == CLI.IdentCase.SQL_IC_MIXED ?
  	     		get_wide_pk_case2 :
  	     		get_wide_pk_case0;
            VirtuosoCommand cmd = new VirtuosoCommand(cmdText ,this);
  
            VirtuosoParameter p1 = (VirtuosoParameter) cmd.CreateParameter();
            p1.Value = catalog;
            p1.ParameterName = ("@catalog");
            cmd.Parameters.Add (p1);
            VirtuosoParameter p2 = (VirtuosoParameter) cmd.CreateParameter();
            p2.Value = schema;
            p2.ParameterName = ("@schema");
            cmd.Parameters.Add (p2);
            VirtuosoParameter p3 = (VirtuosoParameter) cmd.CreateParameter();
            p3.Value = table;
            p3.ParameterName = ("@table");
            cmd.Parameters.Add (p3);

            VirtuosoDataReader reader = (VirtuosoDataReader)cmd.ExecuteReader();
            dt.Load(reader);

            return dt;
        }

        private DataTable GetSchemaProcedureColumns(string catalog, string schema, string procedure, string column)
        {
            DataTable dt = new DataTable("ProcedureColumns");

            // Following schema mirrors System.Data.Odbc provider.
            dt.Columns.Add("PROCEDURE_CAT", typeof(string));
            dt.Columns.Add("PROCEDURE_SCHEM", typeof(string));
            dt.Columns.Add("PROCEDURE_NAME", typeof(string));
            dt.Columns.Add("COLUMN_NAME", typeof(string));
            dt.Columns.Add("COLUMN_TYPE", typeof(short));
            dt.Columns.Add("DATA_TYPE", typeof(short));
            dt.Columns.Add("TYPE_NAME", typeof(string));
            dt.Columns.Add("COLUMN_SIZE", typeof(int));
            dt.Columns.Add("BUFFER_LENGTH", typeof(int));
            dt.Columns.Add("DECIMAL_DIGITS", typeof(short));
            dt.Columns.Add("NUM_PREC_RADIX", typeof(short));
            dt.Columns.Add("NULLABLE", typeof(short));
            dt.Columns.Add("REMARKS", typeof(string));
            dt.Columns.Add("COLUMN_DEF", typeof(string));
            dt.Columns.Add("SQL_DATA_TYPE", typeof(short));
            dt.Columns.Add("SQL_DATETIME_SUB", typeof(short));
            dt.Columns.Add("CHAR_OCTET_LENGTH", typeof(int));
            dt.Columns.Add("ORDINAL_POSITION", typeof(int));
            dt.Columns.Add("IS_NULLABLE", typeof(string));

            if(catalog == null)
               catalog = "%";
            if(schema == null)
               schema = "%";
            if(procedure == null)
               procedure = "%";
            if(column == null)
               column = "%";
   
            string cmdText = "DB.DBA.SQL_PROCEDURE_COLUMNSW (?, ?, ?, ?, ?, ?)";
   
            VirtuosoCommand cmd = new VirtuosoCommand(cmdText ,this);
   
            VirtuosoParameter p1 = (VirtuosoParameter) cmd.CreateParameter();
            p1.Value = catalog;
            p1.ParameterName = ("@catalog");
            p1.DbType = DbType.AnsiString;
            cmd.Parameters.Add (p1);
            VirtuosoParameter p2 = (VirtuosoParameter) cmd.CreateParameter();
            p2.Value = schema;
            p2.ParameterName = ("@schema");
            p2.DbType = DbType.AnsiString;
            cmd.Parameters.Add (p2);
            VirtuosoParameter p3 = (VirtuosoParameter) cmd.CreateParameter();
            p3.Value = procedure;
            p3.ParameterName = ("@procedure");
            p3.DbType = DbType.AnsiString;
            cmd.Parameters.Add (p3);
            VirtuosoParameter p4 = (VirtuosoParameter) cmd.CreateParameter();
            p4.Value = (column);
            p4.ParameterName = ("@column");
            p4.DbType = DbType.AnsiString;
            cmd.Parameters.Add (p4);
            VirtuosoParameter p5 = (VirtuosoParameter) cmd.CreateParameter();
            if (innerConnection.IdentCase == CLI.IdentCase.SQL_IC_MIXED)
              p5.Value = 2;
            else if (innerConnection.IdentCase == CLI.IdentCase.SQL_IC_UPPER)
              p5.Value = 1;
            else
              p5.Value = 0;
            p5.ParameterName = ("@case");
            cmd.Parameters.Add (p5);
            VirtuosoParameter p6 = (VirtuosoParameter) cmd.CreateParameter();
            p6.Value = 1;
            p6.ParameterName = ("@isODBC3");
            cmd.Parameters.Add (p6);

            VirtuosoDataReader reader = (VirtuosoDataReader)cmd.ExecuteReader();
            dt.Load(reader);
   
             // The MS Odbc provider supports both ProcedureColumns and
             // ProcedureParameters metadata collections. This provider
             // does likewise. Filter the output on COLUMN_TYPE to 
             // differentiate these two metadata collections.
            foreach (DataRow dr in dt.Rows)
            {
                if (dr[4] != null)
                {
                    short colType = Int16.Parse(dr[4].ToString());
                    if (colType != (short)CLI.InOutType.SQL_RESULT_COL)
                        dr.Delete(); 
                }
            }
   
            dt.AcceptChanges();
            return dt;
         }

        private DataTable GetSchemaProcedureParameters(string catalog, string schema, string procedure, string column)
        {
            DataTable dt = new DataTable("ProcedureParameters");

            // Following schema mirrors System.Data.Odbc provider.
            dt.Columns.Add("PROCEDURE_CAT", typeof(string));
            dt.Columns.Add("PROCEDURE_SCHEM", typeof(string));
            dt.Columns.Add("PROCEDURE_NAME", typeof(string));
            dt.Columns.Add("COLUMN_NAME", typeof(string));
            dt.Columns.Add("COLUMN_TYPE", typeof(short));
            dt.Columns.Add("DATA_TYPE", typeof(short));
            dt.Columns.Add("TYPE_NAME", typeof(string));
            dt.Columns.Add("COLUMN_SIZE", typeof(int));
            dt.Columns.Add("BUFFER_LENGTH", typeof(int));
            dt.Columns.Add("DECIMAL_DIGITS", typeof(short));
            dt.Columns.Add("NUM_PREC_RADIX", typeof(short));
            dt.Columns.Add("NULLABLE", typeof(short));
            dt.Columns.Add("REMARKS", typeof(string));
            dt.Columns.Add("COLUMN_DEF", typeof(string));
            dt.Columns.Add("SQL_DATA_TYPE", typeof(short));
            dt.Columns.Add("SQL_DATETIME_SUB", typeof(short));
            dt.Columns.Add("CHAR_OCTET_LENGTH", typeof(int));
            dt.Columns.Add("ORDINAL_POSITION", typeof(int));
            dt.Columns.Add("IS_NULLABLE", typeof(string));

            if(catalog == null)
               catalog = "%";
            if(schema == null)
               schema = "%";
            if(procedure == null)
               procedure = "%";
            if(column == null)
               column = "%";
   
            string cmdText = "DB.DBA.SQL_PROCEDURE_COLUMNSW (?, ?, ?, ?, ?, ?)";
   
            VirtuosoCommand cmd = new VirtuosoCommand(cmdText ,this);

            // Arguments to SQL_PROCEDURE_COLUMNSW must be narrow so change 
            // the parameter type to AnsiString
              
            VirtuosoParameter p1 = (VirtuosoParameter) cmd.CreateParameter();
            p1.Value = catalog;
            p1.ParameterName = ("@catalog");
            p1.DbType = DbType.AnsiString;
            cmd.Parameters.Add (p1);
            VirtuosoParameter p2 = (VirtuosoParameter) cmd.CreateParameter();
            p2.Value = schema;
            p2.ParameterName = ("@schema");
            p2.DbType = DbType.AnsiString;
            cmd.Parameters.Add (p2);
            VirtuosoParameter p3 = (VirtuosoParameter) cmd.CreateParameter();
            p3.Value = procedure;
            p3.ParameterName = ("@procedure");
            p3.DbType = DbType.AnsiString;
            cmd.Parameters.Add (p3);
            VirtuosoParameter p4 = (VirtuosoParameter) cmd.CreateParameter();
            p4.Value = column;
            p4.ParameterName = ("@column");
            p4.DbType = DbType.AnsiString;
            cmd.Parameters.Add (p4);
            VirtuosoParameter p5 = (VirtuosoParameter) cmd.CreateParameter();
            if (innerConnection.IdentCase == CLI.IdentCase.SQL_IC_MIXED)
              p5.Value = 2;
            else if (innerConnection.IdentCase == CLI.IdentCase.SQL_IC_UPPER)
              p5.Value = 1;
            else
              p5.Value = 0;
            p5.ParameterName = ("@case");
            cmd.Parameters.Add (p5);
            VirtuosoParameter p6 = (VirtuosoParameter) cmd.CreateParameter();
            p6.Value = 1;
            p6.ParameterName = ("@isODBC3");
            cmd.Parameters.Add (p6);

            VirtuosoDataReader reader = (VirtuosoDataReader)cmd.ExecuteReader();
            dt.Load(reader);
   
   
             // The MS Odbc provider supports both ProcedureColumns and
             // ProcedureParameters metadata collections. This provider
             // does likewise. Filter the output on COLUMN_TYPE to 
             // differentiate these two metadata collections.
            foreach (DataRow dr in dt.Rows)
            {
                if (dr[4] != null)
                {
                    short colType = Int16.Parse(dr[4].ToString());
                    if (colType == (short)CLI.InOutType.SQL_RESULT_COL)
                        dr.Delete(); 
                }
            }
   
            dt.AcceptChanges();
            return dt;
        }

        private DataTable GetSchemaTables(string catalog, string schema, string table, string types)
        {
            DataTable dt = new DataTable("Tables");
            StringBuilder cmdText = new StringBuilder ("select TABLE_CATALOG as TABLE_CAT, TABLE_SCHEMA as TABLE_SCHEM, TABLE_NAME, TABLE_TYPE from INFORMATION_SCHEMA.TABLES where ");

            if (catalog != null && catalog.Length != 0)
              cmdText.Append ("TABLE_CATALOG like '" + catalog + "' AND ");
            if (schema != null && schema.Length != 0)
              cmdText.Append ("TABLE_SCHEMA like '" + schema + "' AND ");
            if (table != null && table.Length != 0)
              cmdText.Append ("TABLE_NAME like '" + table + "' AND ");
            if (types != null && types.Length != 0)
              cmdText.Append ("TABLE_TYPE like '**" + types + "' AND ");
            cmdText.Append ("0 = 0");
            VirtuosoCommand cmd = new VirtuosoCommand (cmdText.ToString() ,this);
            VirtuosoDataReader reader = (VirtuosoDataReader)cmd.ExecuteReader();
            dt.Load(reader);

            return dt;
        }

        private DataTable GetSchemaViews(string catalog, string schema, string view)
        {
            DataTable dt = new DataTable("Views");

            StringBuilder cmdText = new StringBuilder ("select TABLE_CATALOG as TABLE_CAT, TABLE_SCHEMA as TABLE_SCHEM, TABLE_NAME, 'VIEW' as TABLE_TYPE from INFORMATION_SCHEMA.VIEWS where ");

            if (catalog != null && catalog.Length != 0)
              cmdText.Append ("TABLE_CATALOG like '" + catalog + "' AND ");
            if (schema != null && schema.Length != 0)
              cmdText.Append ("TABLE_SCHEMA like '" + schema + "' AND ");
            if (view != null && view.Length != 0)
              cmdText.Append ("TABLE_NAME like '" + view + "' AND ");
            cmdText.Append ("0 = 0");
            VirtuosoCommand cmd = new VirtuosoCommand (cmdText.ToString() ,this);
            VirtuosoDataReader reader = (VirtuosoDataReader)cmd.ExecuteReader();
            dt.Load(reader);

            return dt;
        }

    public static String fk_textw_casemode_0 =
    "select" +
    " charset_recode (name_part (PK_TABLE, 0), 'UTF-8', '_WIDE_') as PKTABLE_CAT nvarchar (128)," +
    " charset_recode (name_part (PK_TABLE, 1), 'UTF-8', '_WIDE_') as PKTABLE_SCHEM nvarchar (128)," +
    " charset_recode (name_part (PK_TABLE, 2), 'UTF-8', '_WIDE_') as PKTABLE_NAME nvarchar (128)," +
    " charset_recode (PKCOLUMN_NAME, 'UTF-8', '_WIDE_') as PKCOLUMN_NAME nvarchar (128)," +
    " charset_recode (name_part (FK_TABLE, 0), 'UTF-8', '_WIDE_') as FKTABLE_CAT nvarchar (128)," +
    " charset_recode (name_part (FK_TABLE, 1), 'UTF-8', '_WIDE_') as FKTABLE_SCHEM nvarchar (128)," +
    " charset_recode (name_part (FK_TABLE, 2), 'UTF-8', '_WIDE_') as FKTABLE_NAME nvarchar (128)," +
    " charset_recode (FKCOLUMN_NAME, 'UTF-8', '_WIDE_') as FKCOLUMN_NAME nvarchar (128)," +
    " (KEY_SEQ + 1) as KEY_SEQ SMALLINT," +
    " (case UPDATE_RULE when 0 then 3 when 1 then 0 when 3 then 4 end) as UPDATE_RULE smallint," +
    " (case DELETE_RULE when 0 then 3 when 1 then 0 when 3 then 4 end) as DELETE_RULE smallint," +
    " charset_recode (FK_NAME, 'UTF-8', '_WIDE_') as FK_NAME nvarchar (128)," +
    " charset_recode (PK_NAME, 'UTF-8', '_WIDE_') as PK_NAME nvarchar (128), "+
    " NULL as DEFERRABILITY " +
    "from DB.DBA.SYS_FOREIGN_KEYS SYS_FOREIGN_KEYS " +
    "where name_part (PK_TABLE, 0) like ?" +
    "  and name_part (PK_TABLE, 1) like ?" +
    "  and name_part (PK_TABLE, 2) like ?" +
    "  and name_part (FK_TABLE, 0) like ?" +
    "  and name_part (FK_TABLE, 1) like ?" +
    "  and name_part (FK_TABLE, 2) like ? " +
    "order by 1, 2, 3, 5, 6, 7, 9";

    public static String fk_textw_casemode_2 =
    "select" +
    " charset_recode (name_part (PK_TABLE, 0), 'UTF-8', '_WIDE_') as PKTABLE_CAT nvarchar (128)," +
    " charset_recode (name_part (PK_TABLE, 1), 'UTF-8', '_WIDE_') as PKTABLE_SCHEM nvarchar (128)," +
    " charset_recode (name_part (PK_TABLE, 2), 'UTF-8', '_WIDE_') as PKTABLE_NAME nvarchar (128)," +
    " charset_recode (PKCOLUMN_NAME, 'UTF-8', '_WIDE_') as PKCOLUMN_NAME nvarchar (128)," +
    " charset_recode (name_part (FK_TABLE, 0), 'UTF-8', '_WIDE_') as FKTABLE_CAT nvarchar (128)," +
    " charset_recode (name_part (FK_TABLE, 1), 'UTF-8', '_WIDE_') as FKTABLE_SCHEM nvarchar (128)," +
    " charset_recode (name_part (FK_TABLE, 2), 'UTF-8', '_WIDE_') as FKTABLE_NAME nvarchar (128)," +
    " charset_recode (FKCOLUMN_NAME, 'UTF-8', '_WIDE_') as FKCOLUMN_NAME nvarchar (128)," +
    " (KEY_SEQ + 1) as KEY_SEQ SMALLINT," +
    " (case UPDATE_RULE when 0 then 3 when 1 then 0 when 3 then 4 end) as UPDATE_RULE smallint," +
    " (case DELETE_RULE when 0 then 3 when 1 then 0 when 3 then 4 end) as DELETE_RULE smallint," +
    " charset_recode (FK_NAME, 'UTF-8', '_WIDE_') as FK_NAME nvarchar (128)," +
    " charset_recode (PK_NAME, 'UTF-8', '_WIDE_') as PK_NAME nvarchar (128),"+
    " NULL as DEFERRABILITY " +
    "from DB.DBA.SYS_FOREIGN_KEYS SYS_FOREIGN_KEYS " +
    "where charset_recode (upper (charset_recode (name_part (PK_TABLE, 0), 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8') like charset_recode (upper (charset_recode (?, 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8')" +
    "  and charset_recode (upper (charset_recode (name_part (PK_TABLE, 1), 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8') like charset_recode (upper (charset_recode (?, 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8')" +
    "  and charset_recode (upper (charset_recode (name_part (PK_TABLE, 2), 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8') like charset_recode (upper (charset_recode (?, 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8')" +
    "  and charset_recode (upper (charset_recode (name_part (FK_TABLE, 0), 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8') like charset_recode (upper (charset_recode (?, 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8')" +
    "  and charset_recode (upper (charset_recode (name_part (FK_TABLE, 1), 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8') like charset_recode (upper (charset_recode (?, 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8')" +
    "  and charset_recode (upper (charset_recode (name_part (FK_TABLE, 2), 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8') like charset_recode (upper (charset_recode (?, 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8') " +
    "order by 1, 2, 3, 5, 6, 7, 9";
   /**
    * Gets a description of the foreign key columns in the foreign key
    * table that reference the primary key columns of the primary key
    * table (describe how one table imports another's key.) This
    * should normally return a single foreign key/primary key pair
    * (most tables only import a foreign key from a table once.)  They
    * are ordered by FKTABLE_CAT, FKTABLE_SCHEM, FKTABLE_NAME, and
    * KEY_SEQ.
    *
    * <P>Each foreign key column description has the following columns:
    *  <OL>
    *	<LI><B>PKTABLE_CAT</B> String => primary key table catalog (may be
    *	null)
    *	<LI><B>PKTABLE_SCHEM</B> String => primary key table schema (may be
    *	null)
    *	<LI><B>PKTABLE_NAME</B> String => primary key table name
    *	<LI><B>PKCOLUMN_NAME</B> String => primary key column name
    *	<LI><B>FKTABLE_CAT</B> String => foreign key table catalog (may be
    *	null)
    *      being exported (may be null)
    *	<LI><B>FKTABLE_SCHEM</B> String => foreign key table schema (may be
    *	null)
    *      being exported (may be null)
    *	<LI><B>FKTABLE_NAME</B> String => foreign key table name
    *      being exported
    *	<LI><B>FKCOLUMN_NAME</B> String => foreign key column name
    *      being exported
    *	<LI><B>KEY_SEQ</B> short => sequence number within foreign key
    *	<LI><B>UPDATE_RULE</B> short => What happens to
    *       foreign key when primary is updated:
    *      <UL>
    *      <LI> importedNoAction - do not allow update of primary
    *               key if it has been imported
    *      <LI> importedKeyCascade - change imported key to agree
    *               with primary key update
    *      <LI> importedKeySetNull - change imported key to NULL if
    *               its primary key has been updated
    *      <LI> importedKeySetDefault - change imported key to default values
    *               if its primary key has been updated
    *      <LI> importedKeyRestrict - same as importedKeyNoAction
    *                                 (for ODBC 2.x compatibility)
    *      </UL>
    *	<LI><B>DELETE_RULE</B> short => What happens to
    *      the foreign key when primary is deleted.
    *      <UL>
    *      <LI> importedKeyNoAction - do not allow delete of primary
    *               key if it has been imported
    *      <LI> importedKeyCascade - delete rows that import a deleted key
    *      <LI> importedKeySetNull - change imported key to NULL if
    *               its primary key has been deleted
    *      <LI> importedKeyRestrict - same as importedKeyNoAction
    *                                 (for ODBC 2.x compatibility)
    *      <LI> importedKeySetDefault - change imported key to default if
    *               its primary key has been deleted
    *      </UL>
    *	<LI><B>FK_NAME</B> String => foreign key name (may be null)
    *	<LI><B>PK_NAME</B> String => primary key name (may be null)
    *	<LI><B>DEFERRABILITY</B> short => can the evaluation of foreign key
    *      constraints be deferred until commit
    *      <UL>
    *      <LI> importedKeyInitiallyDeferred - see SQL92 for definition
    *      <LI> importedKeyInitiallyImmediate - see SQL92 for definition
    *      <LI> importedKeyNotDeferrable - see SQL92 for definition
    *      </UL>
    *  </OL>
    *
    * @param primaryCatalog a catalog name; "" retrieves those without a
    * catalog; null means drop catalog name from the selection criteria
    * @param primarySchema a schema name; "" retrieves those
    * without a schema
    * @param primaryTable the table name that exports the key
    * @param foreignCatalog a catalog name; "" retrieves those without a
    * catalog; null means drop catalog name from the selection criteria
    * @param foreignSchema a schema name; "" retrieves those
    * without a schema
    * @param foreignTable the table name that imports the key
    * @return ResultSet - each row is a foreign key column description
    * @exception virtuoso.jdbc2.VirtuosoException if a database access error
    * occurs
    * @see #getImportedKeys
    */

        private DataTable GetSchemaForeignKeys(
            string pkCatalog, string pkSchema, string pkTable,
            string fkCatalog, string fkSchema, string fkTable)
        {
            DataTable dt = new DataTable("ForeignKeys");

            if(pkCatalog == null)
               pkCatalog = "";
            if(pkSchema == null)
               pkSchema = "";
            if(pkTable == null)
               pkTable = "";
            if(fkCatalog == null)
               fkCatalog = "";
            if(fkSchema == null)
               fkSchema = "";
            if(fkTable == null)
               fkTable = "";
                
            pkCatalog = pkCatalog == "" ? "%" : pkCatalog;
            pkSchema =  pkSchema == "" ? "%" : pkSchema;
            pkTable = pkTable == "" ? "%" : pkTable;
            fkCatalog = fkCatalog == "" ? "%" : fkCatalog;
            fkSchema =  fkSchema == "" ? "%" : fkSchema;
            fkTable = fkTable == "" ? "%" : fkTable;

            String cmdText;
  	        cmdText = innerConnection.IdentCase == CLI.IdentCase.SQL_IC_MIXED ?
  	     		fk_textw_casemode_2 :
  	     		fk_textw_casemode_0;
            VirtuosoCommand cmd = new VirtuosoCommand(cmdText ,this);
  
            VirtuosoParameter p1 = (VirtuosoParameter) cmd.CreateParameter();
            p1.Value = pkCatalog;
            p1.ParameterName = ("@pkCatalog");
            cmd.Parameters.Add (p1);
            VirtuosoParameter p2 = (VirtuosoParameter) cmd.CreateParameter();
            p2.Value = pkSchema;
            p2.ParameterName = ("@pkSchema");
            cmd.Parameters.Add (p2);
            VirtuosoParameter p3 = (VirtuosoParameter) cmd.CreateParameter();
            p3.Value = pkTable;
            p3.ParameterName = ("@pkTable");
            cmd.Parameters.Add (p3);
            VirtuosoParameter p4 = (VirtuosoParameter) cmd.CreateParameter();
            p4.Value = fkCatalog;
            p4.ParameterName = ("@fkCatalog");
            cmd.Parameters.Add (p4);
            VirtuosoParameter p5 = (VirtuosoParameter) cmd.CreateParameter();
            p5.Value = fkSchema;
            p5.ParameterName = ("@fkSchema");
            cmd.Parameters.Add (p5);
            VirtuosoParameter p6 = (VirtuosoParameter) cmd.CreateParameter();
            p6.Value = fkTable;
            p6.ParameterName = ("@fkTable");
            cmd.Parameters.Add (p6);

            VirtuosoDataReader reader = (VirtuosoDataReader)cmd.ExecuteReader();
            dt.Load(reader);

            return dt;
        }

#endif

#endregion
        }
}

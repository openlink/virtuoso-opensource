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
using System.Data;
using System.Data.Common;

using System.Diagnostics;
using System.Text;
#if (!MONO || ADONET2) // for now Mono doesn't have an IDE
using System.ComponentModel;
using System.Drawing;
#endif

#if ODBC_CLIENT
namespace OpenLink.Data.VirtuosoOdbcClient
#elif CLIENT
namespace OpenLink.Data.VirtuosoClient
#else
namespace OpenLink.Data.Virtuoso
#endif
{
#if (!MONO || ADONET2) // for now Mono doesn't have an IDE
    [ToolboxBitmap(typeof(VirtuosoCommand), "OpenLink.Data.VirtuosoClient.VirtuosoCommand.bmp") ]
    [ToolboxItem(true)]
    [DesignTimeVisible(true)]
#endif
    public sealed class VirtuosoCommand : 
#if ADONET2
    DbCommand, ICloneable, IDbCommand
#else
    System.ComponentModel.Component, ICloneable, IDbCommand
#endif
	{
		private VirtuosoConnection connection;
		private VirtuosoTransaction transaction;
		private string commandText;
		private CommandType commandType = CommandType.Text;
		private UpdateRowSource updatedRowSource = UpdateRowSource.None;
		private VirtuosoParameterCollection parameters;
		private int timeout = 30;
		private bool isPrepared = false;
		private bool isExecuted = false;
		private bool isFetching = false;
		private bool isExecuting = false;
/*		private bool isCanceling = false;*/
		private WeakReference dataReaderWeakRef = null;
		private IInnerCommand innerCommand;

		public VirtuosoCommand ()
			: this ("")
		{
		}

		public VirtuosoCommand (string cmdText)
			: this (cmdText, null)
		{
		}

		public VirtuosoCommand (string cmdText, VirtuosoConnection connection)
			: this (cmdText, connection, null)
		{
		}

		public VirtuosoCommand (string cmdText, VirtuosoConnection connection, VirtuosoTransaction transaction)
		{
			Debug.WriteLineIf (CLI.FnTrace.Enabled, "VirtuosoCommand.ctor()");
			this.commandText = cmdText;
			this.connection = connection;
			this.transaction = transaction;
			this.parameters = new VirtuosoParameterCollection (this);
		}

		/*
		 * Now inherited from the System.ComponentModel.Component 
		 * 
		~VirtuosoCommand ()
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

#if ADONET2
		public override string CommandText
#else
		public string CommandText
#endif
		{
			get
			{
				Debug.WriteLineIf (CLI.FnTrace.Enabled, "VirtuosoCommand.get_CommandText()");
				return commandText;
			}
			set
			{
				Debug.WriteLineIf (CLI.FnTrace.Enabled, "VirtuosoCommand.set_CommandText()");
				if (commandText != value)
				{
					CheckState ();
					//DisposeStatement ();
					isPrepared = false;
					commandText = value;
				}
			}
		}

#if ADONET2
		public override int CommandTimeout
#else
		public int CommandTimeout
#endif
		{
			get
			{
				return timeout;
			}
			set
			{
				Debug.WriteLineIf (CLI.FnTrace.Enabled, "VirtuosoCommand.set_CommandTimeout()");
				if (timeout < 0)
					throw new ArgumentException ("Negative timeout value is specified.");

				if (timeout != value)
				{
					CheckState ();
					timeout = value;
				}
			}
		}

#if ADONET2
		public override CommandType CommandType
#else
		public CommandType CommandType
#endif
		{
			get
			{
				return commandType;
			}
			set
			{
				Debug.WriteLineIf (CLI.FnTrace.Enabled, "VirtuosoCommand.set_CommandType()");
				switch (value)
				{
					case CommandType.StoredProcedure:
					case CommandType.TableDirect:
					case CommandType.Text:
						break;
					default:
						throw new ArgumentException ("Invalid CommandType value.");
				}

				if (commandType != value)
				{
					CheckState ();
					//DisposeStatement ();
					isPrepared = false;
					commandType = value;
				}
			}
		}

#if ADONET2
		protected override DbConnection DbConnection
#else
		public VirtuosoConnection Connection
#endif
		{
			/*
			 * The user should be able to set or change the connection at 
			 * any time.
			 */
			get
			{
				return connection;
			}
			set
			{
				/*
				 * The connection is associated with the transaction
				 * so set the transaction object to return a null reference if the connection 
				 * is reset.
				 */
				Debug.WriteLineIf (CLI.FnTrace.Enabled, "VirtuosoCommand.set_Connection()");
				if (connection != value)
				{
					CheckState ();
					DisposeStatement ();
					transaction = null;
					connection = (VirtuosoConnection) value;
				}
			}
		}
		IDbConnection IDbCommand.Connection
		{
			get { return Connection; }
			set { Connection = (VirtuosoConnection) value; }
		}

#if ADONET2
		protected override DbParameterCollection DbParameterCollection
#else
		public VirtuosoParameterCollection Parameters
#endif
		{
			get { return parameters; }
		}

		IDataParameterCollection IDbCommand.Parameters
		{
			get { return parameters; }
		}

#if ADONET2
		protected override DbTransaction DbTransaction
#else
		public VirtuosoTransaction Transaction
#endif
		{
			/*
			 * Set the transaction. Consider additional steps to ensure that the transaction
			 * is compatible with the connection, because the two are usually linked.
			 */
			get
			{
				return transaction;
			}
			set
			{
				Debug.WriteLineIf (CLI.FnTrace.Enabled, "VirtuosoCommand.set_Transaction()");
				if (transaction != value)
				{
					CheckState ();
					transaction = (VirtuosoTransaction) value;
				}
			}
		}

		IDbTransaction IDbCommand.Transaction
		{
			get { return Transaction; }
			set { Transaction = (VirtuosoTransaction) value; }
		}

#if ADONET2
		public override UpdateRowSource UpdatedRowSource
#else
		public UpdateRowSource UpdatedRowSource
#endif
		{
			get { return updatedRowSource;  }
			set { updatedRowSource = value; }
		}

#if ADONET2
		public override void Cancel ()
#else
		public void Cancel ()
#endif
		{
			Debug.WriteLineIf (CLI.FnTrace.Enabled, "VirtuosoCommand.Cancel()");

			// There must be a valid and open connection.
			if (connection == null || connection.State != ConnectionState.Open)
				throw new InvalidOperationException ("Connection must be valid and open");

			if (innerCommand != null && (isExecuting || isExecuted))
			{
				/*isCanceling = true;*/
				innerCommand.Cancel ();
				isExecuted = false;
				isFetching = false;
				// TODO: do something about datareader if the cancel closes a resultset.
			}
		}

		object ICloneable.Clone ()
		{
			VirtuosoCommand command = new VirtuosoCommand ();
			command.connection = connection;
			command.transaction = transaction;
			command.commandText = commandText;
			command.CommandType = commandType;
			command.timeout = timeout;
			return command;
		}

		IDbDataParameter IDbCommand.CreateParameter ()
		{
			return CreateParameter ();
		}

#if ADONET2
		protected override DbParameter CreateDbParameter ()
#else
        public VirtuosoParameter CreateParameter()
#endif
        {
			Debug.WriteLineIf (CLI.FnTrace.Enabled, "VirtuosoCommand.CreateParameter()");
			return new VirtuosoParameter ();
		}

#if ADONET2
		public override int ExecuteNonQuery ()
#else
		public int ExecuteNonQuery ()
#endif
		{
			/*
			 * ExecuteNonQuery is intended for commands that do
			 * not return results, instead returning only the number
			 * of records affected.
			 */
			Debug.WriteLineIf (CLI.FnTrace.Enabled, "VirtuosoCommand.ExecuteNonQuery()");

			int records = 0;
			IDataReader reader = null;
			try
			{
				reader = ExecuteReader (CommandBehavior.Default);
				reader.Close ();
				records = reader.RecordsAffected;
			}
			finally
			{
				if (reader != null)
					reader.Close ();
			}

			return records;
		}

		IDataReader IDbCommand.ExecuteReader ()
		{
			return ExecuteReader ();
		}

#if !ADONET2
		public VirtuosoDataReader ExecuteReader ()
		{
			return ExecuteReader (CommandBehavior.Default);
		}
#endif

		IDataReader IDbCommand.ExecuteReader (CommandBehavior behavior)
		{
			return ExecuteReader (behavior);
		}

#if ADONET2
        protected override DbDataReader ExecuteDbDataReader (CommandBehavior behavior)
#else
        public VirtuosoDataReader ExecuteReader (CommandBehavior behavior)
#endif
		{
			/*
			 * ExecuteReader should retrieve results from the data source
			 * and return a DataReader that allows the user to process 
			 * the results.
			 */
			Debug.WriteLineIf (CLI.FnTrace.Enabled, "VirtuosoCommand.ExecuteReader()");

			// There must be a valid and open connection.
			if (connection == null || connection.State != ConnectionState.Open)
				throw new InvalidOperationException ("Connection must be valid and open");

			VirtuosoConnection.permission.Demand ();

			CheckState ();

			if (innerCommand == null)
				innerCommand = connection.innerConnection.CreateInnerCommand (this);
			innerCommand.SetTimeout (timeout);
			innerCommand.SetCommandBehavior (behavior);

			bool schemaOnly = SchemaOnlyDataReader (behavior);
			if (schemaOnly)
			{
				if (!isPrepared)
					innerCommand.Prepare (GetCommandText ());
			}
			else
			{
				innerCommand.SetParameters (parameters);
				if (!isPrepared)
				{
					string text = GetCommandText ();
					try
					{
						isExecuting = true;
						innerCommand.Execute (text);
					}
					finally
					{
						isExecuting = false;
					}
				}
				else
				{
					try
					{
						isExecuting = true;
						innerCommand.Execute ();
					}
					finally
					{
						isExecuting = false;
					}
				}
				isExecuted = true;
			}

			VirtuosoDataReader reader = new VirtuosoDataReader (connection, innerCommand, this, behavior, schemaOnly);
			dataReaderWeakRef = new WeakReference (reader);
			isFetching = true;
			return reader;
		}

#if ADONET2
        public override object ExecuteScalar ()
#else
		public object ExecuteScalar ()
#endif
		{
			/*
			 * ExecuteScalar assumes that the command will return a single
			 * row with a single column, or if more rows/columns are returned
			 * it will return the first column of the first row.
			 */
			Debug.WriteLineIf (CLI.FnTrace.Enabled, "VirtuosoCommand.ExecuteScalar()");

			object value = null;
			IDataReader reader = null;
			try
			{
				reader = ExecuteReader (CommandBehavior.Default);
				if (reader.Read () && reader.FieldCount > 0)
					value = reader.GetValue (0);
			}
			finally
			{
				if (reader != null)
					reader.Dispose ();
			}

			return value;
		}

#if ADONET2
		public override void Prepare ()
#else
		public void Prepare ()
#endif
		{
			Debug.WriteLineIf (CLI.FnTrace.Enabled, "VirtuosoCommand.Prepare()");
		}

		protected override void Dispose (bool disposing)
		{
			if (disposing)
			{
				DisposeStatement ();
			}
			base.Dispose (disposing);
			connection = null;
			transaction = null;
		}

		internal void OnConnectionClose ()
		{
			if (isFetching)
				CloseDataReader ();
			DisposeStatement ();
			transaction = null;
		}

		internal void CheckState ()
		{
			if (isFetching)
				CloseFinalizedDataReader ();
			if (isFetching || isExecuting)
				throw new InvalidOperationException ("The command object is busy.");
		}

		internal void CloseDataReader ()
		{
			Debug.Assert (isFetching);
			Debug.Assert (dataReaderWeakRef != null);
			VirtuosoDataReader reader = (VirtuosoDataReader) dataReaderWeakRef.Target;
			CloseCursor (true, reader);
			dataReaderWeakRef = null;
			isFetching = false;
		}

		/// <summary>
		/// Cleans up after garbage collected data reader.
		/// Does nothing if the data reader is still alive.
		/// </summary>
		internal void CloseFinalizedDataReader ()
		{
			Debug.Assert (isFetching);
			Debug.Assert (dataReaderWeakRef != null);
			VirtuosoDataReader reader = (VirtuosoDataReader) dataReaderWeakRef.Target;
			if (reader == null)
			{
				CloseCursor (true, null);
				dataReaderWeakRef = null;
				isFetching = false;
			}
		}

		private void CloseCursor (bool keepResults, VirtuosoDataReader reader)
		{
			if (isExecuted)
            {
			  if (keepResults && commandType == CommandType.StoredProcedure)
				  innerCommand.GetParameters ();
            }
			innerCommand.CloseCursor (isExecuted);

			isExecuted = false;
		}

		internal bool GetNextResult ()
		{
			return innerCommand.GetNextResult ();
		}

		private bool SchemaOnlyDataReader (CommandBehavior behavior)
		{
			return ((behavior & CommandBehavior.SchemaOnly) != 0 && commandType != CommandType.StoredProcedure);
		}

		private void DisposeStatement ()
		{
			if (innerCommand != null)
			{
				innerCommand.Dispose ();
				innerCommand = null;
			}
		}

		private string GetCommandText ()
		{
			if (commandType == CommandType.TableDirect)
			{
				return "select * from " + commandText;
			}

			if (commandType == CommandType.StoredProcedure)
			{
				string retval = "";
				StringBuilder arglist = new StringBuilder ("(");
				bool firstArg = true;
				foreach (VirtuosoParameter param in parameters)
				{
					if (param.Direction == ParameterDirection.ReturnValue)
					{
						retval = "? = ";
					}
					else if (firstArg)
					{
						firstArg = false;
						arglist.Append ("?");
					}
					else
					{
						arglist.Append (", ?");
					}
				}
				arglist.Append (")");
				return "{" + retval + "call " + commandText + arglist + "}";
			}

			return commandText;
		}
                private bool m_design_time_visible = false;

#if (!MONO || ADONET2)
                [Browsable(false)]
                [DefaultValue(true)]
                [DesignOnly(true)]

#if ADONET2
                public override bool DesignTimeVisible
#else
                public bool DesignTimeVisible
#endif
                {
                    get
                    {
                        return m_design_time_visible;
                    }
                    set
                    {
                        m_design_time_visible = value;
                        TypeDescriptor.Refresh(this);
                    }
                }
#endif
	}
}

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
using System.Data;
using System.Data.Common;

using System.Diagnostics;
using System.Text;
#if (!MONO || ADONET2) // for now Mono doesn't have an IDE
using System.ComponentModel;
using System.Drawing;
#endif
using System.Text.RegularExpressions;

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
    DbCommand, ICloneable
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
		private bool isCanceling = false;
		private WeakReference dataReaderWeakRef = null;
		private IInnerCommand innerCommand;
		internal bool executeSecondaryStmt = false;
                internal string secondaryStmt = null;

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
		public new VirtuosoConnection Connection
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
#if ADONET2
		protected override DbConnection DbConnection
		{
			get { return Connection; }
			set { Connection = (VirtuosoConnection) value; }
		}
#else
		IDbConnection IDbCommand.Connection
		{
			get { return Connection; }
			set { Connection = (VirtuosoConnection) value; }
		}
#endif


#if ADONET2
		public new VirtuosoParameterCollection Parameters
#else
		public VirtuosoParameterCollection Parameters
#endif
		{
			get { return parameters; }
		}

#if ADONET2
		protected override DbParameterCollection DbParameterCollection
		{
			get { return parameters; }
		}
#else
		IDataParameterCollection IDbCommand.Parameters
		{
			get { return parameters; }
		}
#endif

#if ADONET2
		public new VirtuosoTransaction Transaction
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

#if ADONET2
		protected override DbTransaction DbTransaction
		{
			get { return Transaction; }
			set { Transaction = (VirtuosoTransaction) value; }
		}
#else
		IDbTransaction IDbCommand.Transaction
		{
			get { return Transaction; }
			set { Transaction = (VirtuosoTransaction) value; }
		}
#endif

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
				isCanceling = true;
				innerCommand.Cancel ();
				isExecuted = false;
				isFetching = false;
				// TODO: do something about datareader if the cancel closes a resultset.
			}
		}

		object ICloneable.Clone ()
		{
			VirtuosoCommand command = new VirtuosoCommand ();
			command.Connection = this.Connection;
			command.CommandText = this.CommandText;
			command.CommandType = this.CommandType;
			command.CommandTimeout = this.CommandTimeout;
#if (!MONO || ADONET2)
			command.DesignTimeVisible = this.DesignTimeVisible;
#endif
			command.Transaction = this.Transaction;
			command.UpdatedRowSource = this.UpdatedRowSource;
                        
		        command.executeSecondaryStmt = this.executeSecondaryStmt;
                        command.secondaryStmt = this.secondaryStmt;

			foreach (VirtuosoParameter p in this.Parameters)
				command.Parameters.Add (((ICloneable) p).Clone());
			return command;
		}

#if ADONET2
		protected override DbParameter CreateDbParameter ()
		{
			return CreateParameter ();
		}
#else
		IDbDataParameter IDbCommand.CreateParameter ()
		{
			return CreateParameter ();
		}
#endif

#if ADONET2
        public new VirtuosoParameter CreateParameter()
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

#if !ADONET2
		IDataReader IDbCommand.ExecuteReader ()
		{
			return ExecuteReader ();
		}
#endif

#if ADONET2
		public new VirtuosoDataReader ExecuteReader ()
#else
		public VirtuosoDataReader ExecuteReader ()
#endif
		{
			return ExecuteReader (CommandBehavior.Default);
		}

#if ADONET2
		protected override DbDataReader ExecuteDbDataReader (CommandBehavior behavior)
#else
		IDataReader IDbCommand.ExecuteReader (CommandBehavior behavior)
#endif
		{
			return ExecuteReader (behavior);
		}

#if ADONET2
        public new VirtuosoDataReader ExecuteReader (CommandBehavior behavior)
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
			string text = GetCommandText ();
		        bool isSparql = text.TrimStart(null).StartsWith("sparql", StringComparison.OrdinalIgnoreCase);
			if (schemaOnly)
			{
				if (!isPrepared)
				{
                    			if (!isSparql)
						text = replaceNamedParams (text);
					innerCommand.Prepare (text);
				}
			}
			else
			{
				if (!isSparql && parameters != null && parameters.Count > 0)
				{
					VirtuosoParameterCollection _parameters = handleNamedParams (text, parameters);
					Debug.Assert (_parameters.Count == parameters.Count, "Count mismatch in reordered parameter array");
					text = replaceNamedParams(text);
				}
				innerCommand.SetParameters (parameters);
				if (!isPrepared)
				{
					try
					{
						isExecuting = true;
						innerCommand.Execute (text);
                                                if (executeSecondaryStmt)
                                                  {
                                                    innerCommand.CloseCursor(false);
						    innerCommand.Execute (secondaryStmt);
                                                  }
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
                                                if (executeSecondaryStmt)
                                                  {
                                                    innerCommand.CloseCursor(false);
						    innerCommand.Execute (secondaryStmt);
                                                  }
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
			try
			{
			if (disposing)
			{
				DisposeStatement ();
			}
			base.Dispose (disposing);
			if (connection != null && 
			    connection.innerConnection != null)
				connection.innerConnection.RemoveCommand (this);
			connection = null;
			transaction = null;
		}
			catch (Exception e)
			{
				Debug.WriteLineIf(CLI.FnTrace.Enabled,
					"VirtuosoCommand.Dispose caught exception: " + e.Message);
			}
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
			Debug.Assert (dataReaderWeakRef != null);
			VirtuosoDataReader reader = (VirtuosoDataReader) dataReaderWeakRef.Target;
                        if (!isCanceling)
                        {
				Debug.Assert (isFetching);
				CloseCursor (true, reader);
                        }

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
			  if (keepResults && commandType == CommandType.StoredProcedure &&
innerCommand != null)
				  innerCommand.GetParameters ();
            }
            if (innerCommand != null)
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

		// Replaces any '@<name>' named parameters in the SQL command 
		// with '?' placeholders.
		internal string replaceNamedParams (string sql) 
		{
			string paramPattern = @"@\w+";
			Regex paramRegEx = new Regex(paramPattern);
			return paramRegEx.Replace(sql, "?");
		}

		// Reorders the parameter collection so that the order of named
		// parameters in the collection matches their order in the SQL 
		// command.
		internal VirtuosoParameterCollection handleNamedParams (string sql, VirtuosoParameterCollection _parameters)
		{
			string paramPattern = @"@\w+";
			Regex paramRegEx =  new Regex(paramPattern);
			Match match = paramRegEx.Match(sql);

			// If statement doesn't contain any named parameters
			if (!match.Success)
				return _parameters;

			VirtuosoParameterCollection newParameters = new VirtuosoParameterCollection (this);

			while(match.Success)
			{ 
				string paramName = String.Copy(match.Value);

				if (_parameters.IndexOf (paramName) >= 0)
					newParameters.Add (_parameters[_parameters.IndexOf (paramName)]);
				else
				{
					// Seems param name saved in parameter 
					// collection may or may not have a 
					// leading @
					string paramNameWithoutPrefix = String.Copy(paramName.Substring(1));
					if (_parameters.IndexOf (paramNameWithoutPrefix) >= 0)
					newParameters.Add (_parameters[_parameters.IndexOf (paramNameWithoutPrefix)]);
				}

		 		match = match.NextMatch();
			}
   
			return newParameters;
		}

	}
}

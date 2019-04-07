//  
//  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
//  project.
//  
//  Copyright (C) 1998-2019 OpenLink Software
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

#if ODBC_CLIENT
namespace OpenLink.Data.VirtuosoOdbcClient
#elif CLIENT
namespace OpenLink.Data.VirtuosoClient
#else
namespace OpenLink.Data.Virtuoso
#endif
{
	public sealed class VirtuosoCommandBuilder : 
#if ADONET2
        DbCommandBuilder
#else
        System.ComponentModel.Component
#endif
	{
		internal readonly static BooleanSwitch Switch = 
		    new BooleanSwitch ("VirtuosoClient.ComponentBuilder", "Marshaling");
#if !ADONET2
		private string quotePrefix;
		private string quoteSuffix;
		private VirtuosoDataAdapter adapter;
		private string tableName;
 		private ColumnData[] columns;
		private VirtuosoCommand deleteCommand;
		private VirtuosoCommand insertCommand;
		private VirtuosoCommand updateCommand;
#endif
#if !ADONET2
		private VirtuosoRowUpdatingEventHandler handler;
#else
		private EventHandler<RowUpdatingEventArgs> handler;
#endif

		public VirtuosoCommandBuilder ()
		{
#if ADONET2 
            // DbCommandBuilder defaults QuotePrefix and QuoteSuffix to
            // empty strings
            base.QuotePrefix = "\"";
            base.QuoteSuffix = "\"";
#endif
		}

		public VirtuosoCommandBuilder (VirtuosoDataAdapter adapter)
		{
			DataAdapter = adapter;
#if ADONET2
            base.QuotePrefix = "\"";
            base.QuoteSuffix = "\"";
#endif
		}

#if ADONET2
		public new VirtuosoDataAdapter DataAdapter
        {
            get { return (VirtuosoDataAdapter)base.DataAdapter;}
            set { base.DataAdapter = value; }
        }
#else
		public VirtuosoDataAdapter DataAdapter
		{
			get
			{
				return adapter;
			}
			set
			{
				if (adapter != value)
				{
					Reset ();
					adapter = value;
					if (adapter != null)
					{
						handler = new VirtuosoRowUpdatingEventHandler (this.RowUpdating);
						adapter.RowUpdating += handler;
					}
				}
			}
		}
#endif

#if ADONET2
        /// Given an unquoted identifier in the correct catalog case, returns
        /// the correct quoted form of that identifier, including properly
        /// escaping any embedded quotes in the identifier.
        public override string QuoteIdentifier(string unquotedIdentifier)
        {
            // Base class simply throws NotSupportedException
            string ret = QuotePrefix + unquotedIdentifier + QuoteSuffix;
            return ret;
        }

        /// Given a quoted identifier, returns the correct unquoted form of
        /// that identifier, including properly un-escaping any embedded
        /// quotes in the identifier.
        public override string UnquoteIdentifier(string quotedIdentifier)
        {
            // Base class simply throws NotSupportedException
            string ret = quotedIdentifier;

            int length = quotedIdentifier.Length;
            int startIndex = 0;
            if (quotedIdentifier.StartsWith(QuotePrefix) &&
                quotedIdentifier.EndsWith(QuoteSuffix))
            {
                length -= QuotePrefix.Length + QuoteSuffix.Length;
                startIndex = QuotePrefix.Length;
                ret = quotedIdentifier.Substring(startIndex, length);
            }
            return ret;
        }
#endif

#if ADONET2
        public override string QuotePrefix
		{
			get { return base.QuotePrefix != null ? base.QuotePrefix : ""; }
			set { base.QuotePrefix = value; }
		}
#else
        public string QuotePrefix
		{
			get { return quotePrefix != null ? quotePrefix : ""; }
			set { quotePrefix = value; }
		}
#endif

#if ADONET2
        public override string QuoteSuffix
		{
			get { return base.QuoteSuffix != null ? base.QuotePrefix : ""; }
			set { base.QuoteSuffix = value; }
		}
#else
		public string QuoteSuffix
		{
			get { return quoteSuffix != null ? quotePrefix : ""; }
			set { quoteSuffix = value; }
		}
#endif

		public static void DeriveParameters (VirtuosoCommand command)
		{
			if (command == null)
				throw new ArgumentNullException ("command");

			if (command.CommandType != CommandType.StoredProcedure)
				throw new InvalidOperationException ("DeriveParameters supports only stored procedures.");

			VirtuosoConnection connection = (VirtuosoConnection) command.Connection;
			if (connection == null)
				throw new InvalidOperationException ("The Connection property is not set.");
			if (connection.State == ConnectionState.Closed)
				throw new InvalidOperationException ("The connection is closed.");

			IInnerCommand innerCommand = null;
			VirtuosoDataReader reader = null;
			try
			{
				innerCommand = connection.innerConnection.CreateInnerCommand (null);
				innerCommand.GetProcedureColumns (command.CommandText);
				reader = new VirtuosoDataReader (connection, innerCommand, null, CommandBehavior.Default, false);

				command.Parameters.Clear ();
				while (reader.Read ())
				{
					CLI.InOutType iotype = (CLI.InOutType) reader.GetInt16 (reader.GetOrdinal ("COLUMN_TYPE"));

					ParameterDirection direction;
					switch (iotype)
					{
						case CLI.InOutType.SQL_PARAM_INPUT:
							direction = ParameterDirection.Input;
							break;
						case CLI.InOutType.SQL_PARAM_OUTPUT:
							direction = ParameterDirection.Output;
							break;
						case CLI.InOutType.SQL_PARAM_INPUT_OUTPUT:
							direction = ParameterDirection.InputOutput;
							break;
						case CLI.InOutType.SQL_PARAM_RETURN_VALUE:
							direction = ParameterDirection.ReturnValue;
							break;
						default:
#if MONO
							direction = ParameterDirection.Input;
#endif
							continue;
					}

					string name = reader.GetString (reader.GetOrdinal ("COLUMN_NAME"));
					if (name == "" && iotype == CLI.InOutType.SQL_PARAM_RETURN_VALUE)
						name = "ReturnValue";

					CLI.SqlType sqlType = (CLI.SqlType) reader.GetInt16 (reader.GetOrdinal ("DATA_TYPE"));
					DataType type = DataTypeInfo.MapSqlType (sqlType);
					if (type == null)
						throw new SystemException ("Unknown data type");

					int sizeOrdinal = reader.GetOrdinal ("COLUMN_SIZE");
					if (sizeOrdinal < 0)
						sizeOrdinal = reader.GetOrdinal ("PRECISION");
					int size = reader.IsDBNull (sizeOrdinal) ? 0 : reader.GetInt32 (sizeOrdinal);

					int scaleOrdinal = reader.GetOrdinal ("DECIMAL_DIGITS");
					if (scaleOrdinal < 0)
						scaleOrdinal = reader.GetOrdinal ("SCALE");
					short scale = reader.IsDBNull (scaleOrdinal) ? (short) 0 : reader.GetInt16 (scaleOrdinal);

					int nullableOrdinal = reader.GetOrdinal ("NULLABLE");
					CLI.Nullable nullable = (CLI.Nullable) reader.GetInt16 (nullableOrdinal);
					bool isNullable = (nullable != CLI.Nullable.SQL_NO_NULLS);

					VirtuosoParameter parameter = (VirtuosoParameter) command.CreateParameter ();
					parameter.ParameterName = name;
					parameter.Direction = direction;
					parameter.VirtDbType = type.vdbType;
					parameter.Size = type.GetFieldSize (size);
					parameter.Precision = type.GetPrecision (size);
					parameter.Scale = (byte) scale;
					parameter.IsNullable = isNullable;
					command.Parameters.Add (parameter);
				}
			}
			finally
			{
				if (reader != null)
					reader.Close ();
				if (innerCommand != null)
					innerCommand.Dispose ();
			}
		}

#if ADONET2
		public new VirtuosoCommand GetDeleteCommand ()
#else
		public VirtuosoCommand GetDeleteCommand ()
#endif
		{
#if ADONET2
            return (VirtuosoCommand)base.GetDeleteCommand();
#else
			return GetDeleteCommand (null, null);
#endif
		}

#if ADONET2
		public new VirtuosoCommand GetInsertCommand ()
#else
		public VirtuosoCommand GetInsertCommand ()
#endif
		{
#if ADONET2
            return (VirtuosoCommand)base.GetInsertCommand();
#else
			return GetInsertCommand (null, null);
#endif
		}

#if ADONET2
		public new VirtuosoCommand GetUpdateCommand ()
#else
		public VirtuosoCommand GetUpdateCommand ()
#endif
		{
#if ADONET2
            return (VirtuosoCommand)base.GetUpdateCommand();
#else
			return GetUpdateCommand (null, null);
#endif
		}

#if ADONET2
        public override void RefreshSchema ()
        {
            //will this do?
            base.RefreshSchema();
        }
#else
		public void RefreshSchema ()
		{
			tableName = null;
			columns = null;

			if (deleteCommand != null)
			{
				if (adapter != null && adapter.DeleteCommand == deleteCommand)
					adapter.DeleteCommand = null;
				deleteCommand.Dispose ();
				deleteCommand = null;
			}
			if (insertCommand != null)
			{
				if (adapter != null && adapter.InsertCommand == insertCommand)
					adapter.InsertCommand = null;
				insertCommand.Dispose ();
				insertCommand = null;
			}
			if (updateCommand != null)
			{
				if (adapter != null && adapter.UpdateCommand == updateCommand)
					adapter.UpdateCommand = null;
				updateCommand.Dispose ();
				updateCommand = null;
			}
		}

#endif

#if !ADONET2
		protected override void Dispose (bool disposing)
		{
			if (disposing)
			{
				Reset ();
				adapter = null;
			}
			base.Dispose (disposing);
		}

		private void Reset ()
		{
			if (handler != null)
			{
				adapter.RowUpdating -= handler;
				handler = null;
			}
			RefreshSchema ();
		}
#endif

#if !ADONET2
		private void RowUpdating (object sender, VirtuosoRowUpdatingEventArgs args)
		{
			Debug.WriteLineIf (CLI.FnTrace.Enabled, "VirtuosoCommandBuilder.RowUpdating()");
			if (args.Status != UpdateStatus.Continue)
				return;

			try
			{
				VirtuosoCommand command = args.Command;
				switch (args.StatementType)
				{
					case StatementType.Delete:
						if (command != null && command != deleteCommand)
							return;
						args.Command = GetDeleteCommand (args.TableMapping, args.Row);
						break;

					case StatementType.Insert:
						if (command != null && command != insertCommand)
							return;
						args.Command = GetInsertCommand (args.TableMapping, args.Row);
						break;

					case StatementType.Update:
						if (command != null && command != updateCommand)
							return;
						args.Command = GetUpdateCommand (args.TableMapping, args.Row);
						break;
				}
			}
			catch (Exception e)
			{
				args.Errors = e;
				args.Status = UpdateStatus.ErrorsOccurred;
			}
		}
#endif 

#if !ADONET2
		private VirtuosoCommand GetDeleteCommand (DataTableMapping mapping, DataRow row)
		{
			Debug.WriteLineIf (CLI.FnTrace.Enabled, "VirtuosoCommandBuilder.GetDeleteCommand()");
			VirtuosoCommand selectCommand = CollectInfo ();
			VirtuosoCommand command = deleteCommand;
			if (command == null)
				command = CreateCommand (selectCommand);
			command.Parameters.Clear ();

			StringBuilder text = new StringBuilder ("delete from ");
			text.Append (tableName);
			text.Append (" where ");

			bool first = true;
			int n = columns.Length;
			for (int i = 0; i < n; i++)
			{
				ColumnData c = columns[i];
				if (c.IsLong || c.IsHidden || c.IsExpression)
					continue;

				if (first)
					first = false;
				else
					text.Append (" and ");

				text.Append ("((? is null and ");
				text.Append (c.baseColumnName);
				text.Append (" is null) or (");
				text.Append (c.baseColumnName);
				text.Append (" = ?))");

				AddParameter (command, c, DataRowVersion.Original, mapping, row);
				AddParameter (command, c, DataRowVersion.Original, mapping, row);
			}

			command.CommandText = text.ToString ();
			command.CommandType = CommandType.Text;
			command.UpdatedRowSource = UpdateRowSource.None;
			deleteCommand = command;
			return command;
		}

		private VirtuosoCommand GetInsertCommand (DataTableMapping mapping, DataRow row)
		{
			Debug.WriteLineIf (CLI.FnTrace.Enabled, "VirtuosoCommandBuilder.GetInsertCommand()");
			VirtuosoCommand selectCommand = CollectInfo ();
			VirtuosoCommand command = insertCommand;
			if (command == null)
				command = CreateCommand (selectCommand);
			command.Parameters.Clear ();

			StringBuilder text = new StringBuilder ("insert into ");
			text.Append (tableName);
			text.Append (" (");

			int n = columns.Length;
			for (int i = 0; i < n; i++)
			{
				ColumnData c = columns[i];
				if (c.IsAutoIncrement || c.IsRowVersion || c.IsHidden || c.IsExpression)
					continue;

				if (i != 0)
					text.Append (", ");

				text.Append (c.baseColumnName);
			}
			text.Append (") values (");
			for (int i = 0; i < n; i++)
			{
				ColumnData c = columns[i];
				if (c.IsAutoIncrement || c.IsRowVersion || c.IsHidden || c.IsExpression)
					continue;

				if (i != 0)
					text.Append (", ");
				text.Append ("?");

				AddParameter (command, c, DataRowVersion.Current, mapping, row);
			}
			text.Append (")");

			command.CommandText = text.ToString ();
			command.CommandType = CommandType.Text;
			command.UpdatedRowSource = UpdateRowSource.None;
			insertCommand = command;
			return command;
		}

		private VirtuosoCommand GetUpdateCommand (DataTableMapping mapping, DataRow row)
		{
			Debug.WriteLineIf (CLI.FnTrace.Enabled, "VirtuosoCommandBuilder.GetUpdateCommand()");
			VirtuosoCommand selectCommand = CollectInfo ();
			VirtuosoCommand command = updateCommand;
			if (command == null)
				command = CreateCommand (selectCommand);
			command.Parameters.Clear ();

			StringBuilder text = new StringBuilder ("update ");
			text.Append (tableName);
			text.Append (" set ");

			int n = columns.Length;
			for (int i = 0; i < n; i++)
			{
				ColumnData c = columns[i];
				if (c.IsAutoIncrement || c.IsRowVersion || c.IsHidden || c.IsExpression)
					continue;

				if (i != 0)
					text.Append (", ");
				text.Append (c.baseColumnName);
				text.Append (" = ?");

				AddParameter (command, c, DataRowVersion.Current, mapping, row);
			}

			text.Append (" where ");

			bool first = true;
			for (int i = 0; i < n; i++)
			{
				ColumnData c = columns[i];
				if (c.IsLong || c.IsHidden || c.IsExpression)
					continue;

				if (first)
					first = false;
				else
					text.Append (" and ");

				text.Append ("((? is null and ");
				text.Append (c.baseColumnName);
				text.Append (" is null) or (");
				text.Append (c.baseColumnName);
				text.Append (" = ?))");

				AddParameter (command, c, DataRowVersion.Original, mapping, row);
				AddParameter (command, c, DataRowVersion.Original, mapping, row);
			}
			
			command.CommandText = text.ToString ();
			command.CommandType = CommandType.Text;
			command.UpdatedRowSource = UpdateRowSource.None;
			updateCommand = command;
			return command;
		}
#endif

#if !ADONET2
		private VirtuosoCommand CollectInfo ()
		{
			if (adapter == null)
				throw new InvalidOperationException ("The DataAdapter property is not set.");

			VirtuosoCommand selectCommand = (VirtuosoCommand) adapter.SelectCommand;
			if (selectCommand == null)
				throw new InvalidOperationException ("The SelectCommand property is not set.");

			VirtuosoConnection connection = (VirtuosoConnection) selectCommand.Connection;
			if (connection == null)
				throw new InvalidOperationException ("The Connection property is not set.");

			if (columns != null)
				return selectCommand;

			bool close = false;
			if (connection.State == ConnectionState.Closed)
			{
				connection.Open ();
				close = true;
			}

			VirtuosoDataReader reader = null;
			try
			{
				reader = (VirtuosoDataReader) selectCommand.ExecuteReader (CommandBehavior.KeyInfo | CommandBehavior.SchemaOnly);
				tableName = GetTableName (reader.Columns);
				columns = reader.Columns;
			}
			finally
			{
				if (reader != null)
					reader.Close ();
				if (close)
					connection.Close ();
			}

			return selectCommand;
		}
#endif

#if !ADONET2
		private string GetTableName (ColumnData[] columns)
		{
			if (columns == null)
				throw new InvalidOperationException ("The SelectCommand has not generated a result set.");

			int n = columns.Length;
			if (n < 1)
				throw new InvalidOperationException ("The SelectCommand has not generated a result set.");

			string baseCatalogName = null;
			string baseSchemaName = null;
			string baseTableName = null;

			bool first = true;
			for (int i = 1; i < n; i++)
			{
				ColumnData c = columns[i];
				if (c.IsExpression)
					continue;

				if (first)
				{
					first = false;
					baseCatalogName = c.baseCatalogName;
					baseSchemaName = c.baseSchemaName;
					baseTableName = c.baseTableName;
				}
				else
				{
					if (baseCatalogName != c.baseCatalogName
						|| baseSchemaName != c.baseSchemaName
						|| baseTableName != c.baseTableName)
						throw new InvalidOperationException ("The SelectCommand generated a result set not suitable for the command builder.");
				}
			}

			if (baseTableName == null || baseTableName == "")
				throw new InvalidOperationException ("The SelectCommand generated a result set not suitable for the command builder.");

			StringBuilder tableName = new StringBuilder ();
			if (baseCatalogName != null && baseCatalogName != "")
			{
				tableName.Append (QuotePrefix);
				tableName.Append (baseCatalogName);
				tableName.Append (QuoteSuffix);
				tableName.Append (".");
			}
			if (baseSchemaName != null && baseSchemaName != "")
			{
				tableName.Append (QuotePrefix);
				tableName.Append (baseSchemaName);
				tableName.Append (QuoteSuffix);
				tableName.Append (".");
			}
			tableName.Append (QuotePrefix);
			tableName.Append (baseTableName);
			tableName.Append (QuoteSuffix);
			return tableName.ToString ();
		}
#endif

		private VirtuosoCommand CreateCommand (VirtuosoCommand selectCommand)
		{
			VirtuosoCommand command = new VirtuosoCommand ();
			command.CommandTimeout = selectCommand.CommandTimeout;
			command.Connection = selectCommand.Connection;
			command.Transaction = selectCommand.Transaction;
			return command;
		}

#if !ADONET2
		private void AddParameter (
			VirtuosoCommand command,
			ColumnData column,
			DataRowVersion version,
			DataTableMapping mapping,
			DataRow row)
		{
			Debug.WriteLineIf (CLI.FnTrace.Enabled, "VirtuosoCommandBuilder.AddParameter()");
			VirtuosoParameter parameter = new VirtuosoParameter ();
			string name = String.Format ("p{0}", command.Parameters.Count);

			object value = null;
			if (row != null)
			{
				Debug.WriteLineIf (Switch.Enabled, "  row != null");
				//string datasetColumn = column.columnName;
				if (mapping != null)
				{
					Debug.WriteLineIf (Switch.Enabled, "  mapping != null");
					DataColumnMapping columnMapping = mapping.GetColumnMappingBySchemaAction (
						column.columnName,
						adapter.MissingMappingAction);
					if (columnMapping != null)
					{
						Debug.WriteLineIf (Switch.Enabled, "  columnMapping != null");
						DataColumn dataColumn = columnMapping.GetDataColumnBySchemaAction (
							row.Table,
							column.columnType.bufferType.type,
							adapter.MissingSchemaAction);
						if (dataColumn != null)
						{
							Debug.WriteLineIf (Switch.Enabled, "  dataColumn != null");
							value = row[dataColumn, version];
						}
					}
				}
			}
			Debug.WriteLineIf (Switch.Enabled, "  value: " + value);

			parameter.ParameterName = name;
			parameter.VirtDbType = column.columnType.vdbType;
			parameter.Precision = (byte) column.precision;
			parameter.Scale = (byte) column.scale;
			parameter.Size = 0;
			parameter.IsNullable = column.IsNullable;
			parameter.Direction = ParameterDirection.Input;
			parameter.SourceColumn = column.columnName;
			parameter.SourceVersion = version;
			parameter.Value = value;

			command.Parameters.Add (parameter);
		}
#endif
    #region ADO.NET 2.0
#if ADONET2
// jch ?????
//        protected override DbProviderFactory ProviderFactory
//        {
//            get
//            {
//                return VirtuosoClientFactory.Instance;
//            }
//        }


        /// Allows the provider implementation of the DbCommandBuilder class
        /// to handle provider-specific parameter properties.
        protected override void ApplyParameterInfo(
            DbParameter p, DataRow row, 
            StatementType statementType, bool whereClause)
        {
           //No Action needed
        }

        /// Returns the name of the specified parameter in the format of
        /// @p#.
        protected override string GetParameterName(int parameterOrdinal)
        {
            StringBuilder sb = new StringBuilder();
            sb.AppendFormat("@p{0}", parameterOrdinal);
            string ret = sb.ToString();
            return ret;
        }

        /// Returns the full parameter name, given the partial parameter name.
        protected override string GetParameterName(string parameterName)
        {
            StringBuilder sb = new StringBuilder();
            sb.AppendFormat("p{0}", parameterName);
            string ret = sb.ToString();
            return ret;
        }

        /// Returns the placeholder for the parameter in the associated SQL
        /// statement.
        protected override string GetParameterPlaceholder(int parameterOrdinal)
        {
            string ret = "?";
            return ret;
        }


        protected override void SetRowUpdatingHandler(DbDataAdapter adapter)
        {
            VirtuosoDataAdapter da = adapter as VirtuosoDataAdapter;
            if (da == null)
				throw new InvalidOperationException ("adapter is not set.");

            handler = new
				EventHandler<RowUpdatingEventArgs>(RowUpdatingEventHandler);

            da.RowUpdating += handler;
        }

        private void RowUpdatingEventHandler(
			object sender, RowUpdatingEventArgs e)
        {
            base.RowUpdatingHandler(e);
        }
#endif
    #endregion
   }
}

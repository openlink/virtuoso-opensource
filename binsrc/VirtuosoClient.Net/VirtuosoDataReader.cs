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
using System.Text;

using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Collections;

#if ODBC_CLIENT
namespace OpenLink.Data.VirtuosoOdbcClient
#elif CLIENT
namespace OpenLink.Data.VirtuosoClient
#else
namespace OpenLink.Data.Virtuoso
#endif
{
	internal class ColumnData
	{
		internal enum ColumnFlags
		{
			IsLong = 1,
			IsNullable = 2,
			IsReadOnly = 4,
			IsKey = 8,
			IsUnique = 16,
			IsRowVersion = 32,
			IsAutoIncrement = 64,
			IsHidden = 128,
			IsExpression = 256,
		};

		internal string columnName;
		internal DataType columnType;
		internal BufferType bufferType;
		internal int columnSize;
		internal short precision;
		internal short scale;
		internal ColumnFlags flags;
		internal String baseSchemaName;
		internal String baseCatalogName;
		internal String baseTableName;
		internal String baseColumnName;
		internal int lobLength;
		internal int lobOffset;
		internal object data;

		internal bool IsLong
		{
			get	{ return GetFlag (ColumnFlags.IsLong); }
			set	{ SetFlag (ColumnFlags.IsLong, value); }
		}

		internal bool IsNullable
		{
			get	{ return GetFlag (ColumnFlags.IsNullable); }
			set	{ SetFlag (ColumnFlags.IsNullable, value); }
		}

		internal bool IsReadOnly
		{
			get	{ return GetFlag (ColumnFlags.IsReadOnly); }
			set	{ SetFlag (ColumnFlags.IsReadOnly, value); }
		}

		internal bool IsKey
		{
			get	{ return GetFlag (ColumnFlags.IsKey); }
			set	{ SetFlag (ColumnFlags.IsKey, value); }
		}

		internal bool IsUnique
		{
			get	{ return GetFlag (ColumnFlags.IsUnique); }
			set	{ SetFlag (ColumnFlags.IsUnique, value); }
		}

		internal bool IsRowVersion
		{
			get	{ return GetFlag (ColumnFlags.IsRowVersion); }
			set	{ SetFlag (ColumnFlags.IsRowVersion, value); }
		}

		internal bool IsAutoIncrement
		{
			get	{ return GetFlag (ColumnFlags.IsAutoIncrement); }
			set	{ SetFlag (ColumnFlags.IsAutoIncrement, value); }
		}

		internal bool IsHidden
		{
			get	{ return GetFlag (ColumnFlags.IsHidden); }
			set	{ SetFlag (ColumnFlags.IsHidden, value); }
		}

		internal bool IsExpression
		{
			get	{ return GetFlag (ColumnFlags.IsExpression); }
			set	{ SetFlag (ColumnFlags.IsExpression, value); }
		}

		private bool GetFlag (ColumnFlags f)
		{
			return (flags & f) != 0;
		}

		private void SetFlag (ColumnFlags f, bool value)
		{
			if (value)
				flags |= f;
			else
				flags &= ~f;
		}
	};

	/// <summary>
	/// Summary description for VirtuosoDataReader.
	/// </summary>
	public sealed class VirtuosoDataReader : 
#if ADONET2
        DbDataReader, IDataReader, IDataRecord, IDisposable, IEnumerable
#else
        MarshalByRefObject, IDataReader, IDataRecord, IDisposable, IEnumerable
#endif
	{
		// The DataReader should always be open when returned to the user.
		private bool open = true;

		// The current resultset is over.
		private bool over = false;

		// The last resultset was retrieved.
		private bool last = false;

		private int rows = 0;
		private ColumnData[] columns = null;

		private VirtuosoConnection connection;
		private VirtuosoCommand command;
		private IInnerCommand innerCommand;
		private System.Data.CommandBehavior commandBehavior;

		/*
		 * Because the user should not be able to directly create a 
		 * DataReader object, the constructors are
		 * marked as internal.
		 */
		internal VirtuosoDataReader (
			VirtuosoConnection connection,
			IInnerCommand innerCommand,
			VirtuosoCommand command,
			CommandBehavior commandBehavior,
			bool schemaOnly)
		{
			Debug.WriteLineIf (CLI.FnTrace.Enabled, "VirtuosoDataReader.ctor()");
			Debug.Assert (connection != null);
			Debug.Assert (innerCommand != null);

			this.connection = connection;
			this.command = command;
			this.innerCommand = innerCommand;
			this.commandBehavior = commandBehavior;

			InitializeResultInfo (schemaOnly);
			if (schemaOnly)
			{
				over = true;
				last = true;
			}
		}

		~VirtuosoDataReader ()
		{
			Dispose (false);
		}

		void IDisposable.Dispose ()
		{
			Dispose (true);
			GC.SuppressFinalize (this);
		}

		/****
		 * METHODS / PROPERTIES FROM IDataReader.
		 ****/

#if ADONET2
        public override int Depth 
#else
		public int Depth 
#endif
		{
			/*
			 * Always return a value of zero if nesting is not supported.
			 */
			get { return 0; }
		}

#if ADONET2
        public override bool IsClosed
#else
		public bool IsClosed
#endif
		{
			/*
			 * Keep track of the reader state - some methods should be
			 * disallowed if the reader is closed.
			 */
			get { return !open; }
		}

#if ADONET2
        public override int RecordsAffected
#else
		public int RecordsAffected
#endif
		{
			/*
			 * RecordsAffected is only applicable to batch statements
			 * that include inserts/updates/deletes.
			 */
			get
			{
				Debug.WriteLineIf (CLI.FnTrace.Enabled, "VirtuosoDataReader.RecordsAffected");
				return rows;
			}
		}

		IEnumerator IEnumerable.GetEnumerator ()
		{
			return new System.Data.Common.DbEnumerator (this, (commandBehavior & CommandBehavior.CloseConnection) != 0);
		}

#if ADONET2
        public override void Close ()
#else
		public void Close ()
#endif
		{
			Debug.WriteLineIf (CLI.FnTrace.Enabled, "VirtuosoDataReader.Close()");
			if (open)
			{
				if (command != null)
				{
					command.CloseDataReader ();
					command = null;
				}
				if (connection != null && (commandBehavior & CommandBehavior.CloseConnection) != 0)
				{
					connection.Close ();
					connection = null;
				}
				columns = null;
				open = false;
			}
		}

#if ADONET2
        public override bool NextResult ()
#else
		public bool NextResult ()
#endif
		{
			Debug.WriteLineIf (CLI.FnTrace.Enabled, "VirtuosoDataReader.NextResult()");

			if (!open)
				throw new InvalidOperationException ("The VirtuosoDataReader object is closed.");
			if (last)
				return false;

			bool next = command.GetNextResult ();
			if (next)
				InitializeResultInfo (false);
			else
				last = true;
			return next;
		}

#if ADONET2
        public override bool Read ()
#else
		public bool Read ()
#endif
		{
			Debug.WriteLineIf (CLI.FnTrace.Enabled, "VirtuosoDataReader.Read()");

			// Return true if it is possible to advance and if you are still positioned
			// on a valid row.
			if (over)
				return false;

			if (!innerCommand.Fetch ())
			{
				over = true;
				return false;
			}

			int n = FieldCount;
			for (int i = 0; i < n; i++)
				ResetColumn (i);

			GC.KeepAlive (this);
			return true;
		}

#if ADONET2
        public override DataTable GetSchemaTable ()
#else
		public DataTable GetSchemaTable ()
#endif
		{
			Debug.WriteLineIf (CLI.FnTrace.Enabled, "VirtuosoDataReader.GetSchemaTable()");

			if (columns == null)
				throw new InvalidOperationException ();

			int n = columns.Length;
			DataTable table = new DataTable ("SchemaTable");
			table.MinimumCapacity = n;

			DataColumnCollection metaColumns = table.Columns;
			DataColumn columnName = metaColumns.Add ("ColumnName", typeof (System.String));
			DataColumn columnOrdinal = metaColumns.Add ("ColumnOrdinal", typeof (System.Int32));
			DataColumn columnSize = metaColumns.Add ("ColumnSize", typeof (System.Int32));
			DataColumn numericPrecision = metaColumns.Add ("NumericPrecision", typeof (System.Int16));
			DataColumn numericScale = metaColumns.Add ("NumericScale", typeof (System.Int16));
			DataColumn dataType = metaColumns.Add ("DataType", typeof (System.Type));
			DataColumn providerType = metaColumns.Add ("ProviderType", typeof (System.Int32));
			DataColumn isLong = metaColumns.Add ("IsLong", typeof (System.Boolean));
			DataColumn allowDBNull = metaColumns.Add ("AllowDBNull", typeof (System.Boolean));
			DataColumn isReadOnly = metaColumns.Add ("IsReadOnly", typeof (System.Boolean));
			DataColumn isRowVersion = metaColumns.Add ("IsRowVersion", typeof (System.Boolean));
			DataColumn isUnique = metaColumns.Add ("IsUnique", typeof (System.Boolean));
			DataColumn isKey = metaColumns.Add ("IsKey", typeof (System.Boolean));
			DataColumn isAutoIncrement = metaColumns.Add ("IsAutoIncrement", typeof (System.Boolean));
			DataColumn baseSchemaName = metaColumns.Add ("BaseSchemaName", typeof (System.String));
			DataColumn baseCatalogName = metaColumns.Add ("BaseCatalogName", typeof (System.String));
			DataColumn baseTableName = metaColumns.Add ("BaseTableName", typeof (System.String));
			DataColumn baseColumnName = metaColumns.Add ("BaseColumnName", typeof (System.String));
			DataColumn isHidden = metaColumns.Add ("IsHidden", typeof (System.Boolean));

			DataRowCollection rows = table.Rows;
			for (int i = 0; i < n; i++)
			{
				DataRow row = table.NewRow ();
				row[columnName] = columns[i].columnName;
				row[columnOrdinal] = i + 1;
				row[columnSize] = columns[i].columnSize;
				row[dataType] = columns[i].columnType.bufferType.type;
				row[providerType] = columns[i].columnType.sqlType;
				switch (Type.GetTypeCode(columns[i].columnType.bufferType.type))
				{
					case TypeCode.Int16:
					case TypeCode.UInt16:
					case TypeCode.Int32:
					case TypeCode.UInt32:
					case TypeCode.Int64:
					case TypeCode.UInt64:
					case TypeCode.Single:
					case TypeCode.Double:
					case TypeCode.Byte:
					case TypeCode.SByte:
					case TypeCode.DateTime:
						row[numericPrecision] = columns[i].precision;
						break;
					case TypeCode.Decimal:
						row[numericPrecision] = columns[i].precision;
						row[numericScale] = columns[i].scale;
						break;
					default:
						break;
				}

				row[isLong] = columns[i].IsLong;
				row[allowDBNull] = columns[i].IsNullable;
				row[isReadOnly] = columns[i].IsReadOnly;
				row[isRowVersion] = columns[i].IsRowVersion;
				row[isUnique] = columns[i].IsUnique;
				row[isKey] = columns[i].IsKey;
                // Assume key columns are not nullable.
                // If IDataReader.GetSchema table reports a key column as
                // IsKeyColumn==true but with AllowDBNull==true, 
                // DataRowCollection.Find() reports that the table 
                // associated with the parent DataTable doesn't
                // have a primary key.
				row[isAutoIncrement] = columns[i].IsAutoIncrement;
				row[baseSchemaName] = columns[i].baseSchemaName;
				row[baseCatalogName] = columns[i].baseCatalogName;
				row[baseTableName] = columns[i].baseTableName;
				if (columns[i].baseColumnName == null || columns[i].baseColumnName == String.Empty)
					row[baseColumnName] = columns[i].columnName;
				else
					row[baseColumnName] = columns[i].baseColumnName;
				row[isHidden] = columns[i].IsHidden;
                // Virtuoso returns the key as an additional column with 
                // the IsHidden property set to true.  However, if there
                // are two columns with IsKey set to true I get errors saying
                // that there is not primary key for the table.  This hack 
                // fixes the problem...
                if ((bool)row[isHidden])
                   row[isKey] = false;
				rows.Add (row);
				row.AcceptChanges ();
			}
		return table;
		}

		/****
		 * METHODS / PROPERTIES FROM IDataRecord.
		 ****/

#if ADONET2
        public override int FieldCount
#else
		public int FieldCount
#endif
		{
			// Return the count of the number of columns, which in
			// this case is the size of the column metadata
			// array.
			get { 
                        int col;
                        col = (columns == null ? 0 : columns.Length);

			Debug.WriteLineIf (CLI.FnTrace.Enabled, "VirtuosoDataReader.FieldCount() = " + col);
			return columns == null ? 0 : columns.Length; }
		}

#if ADONET2
        public override String GetName (int i)
#else
		public String GetName (int i)
#endif
		{
			Debug.WriteLineIf (CLI.FnTrace.Enabled, "VirtuosoDataReader.GetName()");
			return columns[i].columnName;
		}

#if ADONET2
        public override String GetDataTypeName (int i)
#else
		public String GetDataTypeName (int i)
#endif
		{
			Debug.WriteLineIf (CLI.FnTrace.Enabled, "VirtuosoDataReader.GetDataTypeName()");
			return columns[i].columnType.typeName;
		}

#if ADONET2
        public override Type GetFieldType (int i)
#else
		public Type GetFieldType (int i)
#endif
		{
			Debug.WriteLineIf (CLI.FnTrace.Enabled, "VirtuosoDataReader.GetFieldType()");
			// Return the actual Type class for the data type.
			return columns[i].columnType.bufferType.type;
		}

#if ADONET2
        public override Object GetValue (int i)
#else
		public Object GetValue (int i)
#endif
		{
			Debug.WriteLineIf (CLI.FnTrace.Enabled, "VirtuosoDataReader.GetValue()");
			return GetColumnData (i);
		}

#if ADONET2
        public override int GetValues (object[] values)
#else
		public int GetValues (object[] values)
#endif
		{
			Debug.WriteLineIf (CLI.FnTrace.Enabled, "VirtuosoDataReader.GetValues()");
			int n = Math.Min (values.Length, FieldCount);
			for (int i = 0; i < n; i++)
			  {
			    Debug.WriteLineIf (CLI.FnTrace.Enabled, String.Format ("VirtuosoDataReader.GetValues() : getting col {0} ({1})", 
				i, columns[i].columnName));
				values[i] = GetColumnData (i);
			  }
			return n;
		}

#if ADONET2
        public override int GetOrdinal (string name)
#else
		public int GetOrdinal (string name)
#endif
		{
			Debug.WriteLineIf (CLI.FnTrace.Enabled, "VirtuosoDataReader.GetOrdinal()");

			// Look for the ordinal of the column with the same name and return it.
			int n = FieldCount;
			for (int i = 0; i < n; i++)
			{
				if (0 == Platform.CaseInsensitiveCompare (name, columns[i].columnName))
				{
					return i;
				}
			}

			// Throw an exception if the ordinal cannot be found.
			throw new IndexOutOfRangeException ("Could not find specified column in results");
		}

#if ADONET2
        public override object this [ int i ]
#else
		public object this [ int i ]
#endif
		{
			get { return GetColumnData (i); }
		}

#if ADONET2
        public override object this [ String name ]
#else
		public object this [ String name ]
#endif
		{
			// Look up the ordinal and return 
			// the value at that position.
			get { return GetColumnData (GetOrdinal (name)); }
		}

#if ADONET2
        public override bool GetBoolean (int i)
#else
		public bool GetBoolean (int i)
#endif
		{
			Debug.WriteLineIf (CLI.FnTrace.Enabled, "VirtuosoDataReader.GetBoolean()");
			/*
			 * Force the cast to return the type. InvalidCastException
			 * should be thrown if the data is not already of the correct type.
			 */
            return Convert.ToBoolean(GetColumnData(i));
		}

#if ADONET2
        public override byte GetByte (int i)
#else
		public byte GetByte (int i)
#endif
		{
			Debug.WriteLineIf (CLI.FnTrace.Enabled, "VirtuosoDataReader.GetByte()");
			/*
			 * Force the cast to return the type. InvalidCastException
			 * should be thrown if the data is not already of the correct type.
			 */
            return Convert.ToByte(GetColumnData(i));
		}

#if ADONET2
        public override long GetBytes (int i, long fieldOffset, byte[] buffer, int bufferOffset, int length)
#else
		public long GetBytes (int i, long fieldOffset, byte[] buffer, int bufferOffset, int length)
#endif
		{
			Debug.WriteLineIf (CLI.FnTrace.Enabled, "VirtuosoDataReader.GetBytes()");

			if (fieldOffset < 0)
				throw new ArgumentException ("Invalid fieldOffset value");

			ColumnData column = columns[i];
			if (column.data == null
				&& column.columnType.isLong
				&& (commandBehavior & CommandBehavior.SequentialAccess) != 0)
				return innerCommand.GetBytes (i, columns, fieldOffset, buffer, bufferOffset, length);

			byte[] data = (byte[]) GetColumnData (i);
			if (buffer == null)
				return data.Length < fieldOffset ? 0 : data.Length - fieldOffset;
			if (length > (data.Length - fieldOffset))
				length = (int) (data.Length - fieldOffset);
			Array.Copy (data, (int) fieldOffset, buffer, bufferOffset, length);
			return length;
		}

#if ADONET2
        public override char GetChar (int i)
#else
		public char GetChar (int i)
#endif
		{
			/*
			 * Force the cast to return the type. InvalidCastException
			 * should be thrown if the data is not already of the correct type.
			 */
			Debug.WriteLineIf (CLI.FnTrace.Enabled, "VirtuosoDataReader.GetChar()");
			return Convert.ToChar(GetColumnData (i));
		}

#if ADONET2
        public override long GetChars (int i, long fieldOffset, char[] buffer, int bufferOffset, int length)
#else
		public long GetChars (int i, long fieldOffset, char[] buffer, int bufferOffset, int length)
#endif
		{
			Debug.WriteLineIf (CLI.FnTrace.Enabled, "VirtuosoDataReader.GetChars()");

			if (fieldOffset < 0)
				throw new ArgumentException ("Invalid fieldOffset value");

			ColumnData column = columns[i];
			if (column.data == null
				&& column.columnType.isLong
				&& (commandBehavior & CommandBehavior.SequentialAccess) != 0)
				return innerCommand.GetChars (i, columns, fieldOffset, buffer, bufferOffset, length);

			char[] data = ((string) GetColumnData (i)).ToCharArray ();
			if (buffer == null)
				return data.Length < fieldOffset ? 0 : data.Length - fieldOffset;
			if (length > (data.Length - fieldOffset))
				length = (int) (data.Length - fieldOffset);
			Array.Copy (data, (int) fieldOffset, buffer, bufferOffset, length);
			return length;
		}

#if ADONET2
        public override Guid GetGuid (int i)
#else
		public Guid GetGuid (int i)
#endif
		{
			/*
			 * Force the cast to return the type. InvalidCastException
			 * should be thrown if the data is not already of the correct type.
			 */
			Debug.WriteLineIf (CLI.FnTrace.Enabled, "VirtuosoDataReader.GetGuid(})");
			return (Guid) GetColumnData (i);
		}

#if ADONET2
        public override Int16 GetInt16 (int i)
#else
		public Int16 GetInt16 (int i)
#endif
		{
			/*
			 * Force the cast to return the type. InvalidCastException
			 * should be thrown if the data is not already of the correct type.
			 */
			Debug.WriteLineIf (CLI.FnTrace.Enabled, "VirtuosoDataReader.GetInt16()");
			return Convert.ToInt16(GetColumnData (i));
		}

#if ADONET2
        public override Int32 GetInt32 (int i)
#else
		public Int32 GetInt32 (int i)
#endif
		{
			/*
			 * Force the cast to return the type. InvalidCastException
			 * should be thrown if the data is not already of the correct type.
			 */
			Debug.WriteLineIf (CLI.FnTrace.Enabled, "VirtuosoDataReader.GetInt32()");
			return Convert.ToInt32(GetColumnData (i));
		}

#if ADONET2
        public override Int64 GetInt64 (int i)
#else
		public Int64 GetInt64 (int i)
#endif
		{
			/*
			 * Force the cast to return the type. InvalidCastException
			 * should be thrown if the data is not already of the correct type.
			 */
			Debug.WriteLineIf (CLI.FnTrace.Enabled, "VirtuosoDataReader.GetInt64()");
			return Convert.ToInt64(GetColumnData (i));
		}

#if ADONET2
        public override float GetFloat (int i)
#else
		public float GetFloat (int i)
#endif
		{
			/*
			 * Force the cast to return the type. InvalidCastException
			 * should be thrown if the data is not already of the correct type.
			 */
			Debug.WriteLineIf (CLI.FnTrace.Enabled, "VirtuosoDataReader.GetFloat()");
			return Convert.ToSingle(GetColumnData (i));
		}

#if ADONET2
        public override double GetDouble (int i)
#else
		public double GetDouble (int i)
#endif
		{
			/*
			 * Force the cast to return the type. InvalidCastException
			 * should be thrown if the data is not already of the correct type.
			 */
			Debug.WriteLineIf (CLI.FnTrace.Enabled, "VirtuosoDataReader.GetDouble()");
            return Convert.ToDouble(GetColumnData(i));
		}

#if ADONET2
        public override String GetString (int i)
#else
		public String GetString (int i)
#endif
		{
			/*
			 * Force the cast to return the type. InvalidCastException
			 * should be thrown if the data is not already of the correct type.
			 */
			Debug.WriteLineIf (CLI.FnTrace.Enabled, "VirtuosoDataReader.GetString()");
			object cd = GetColumnData (i);
			if (cd is String)
			  return (String) cd;
            else if (cd is System.Byte[])
            {
                byte[] v = (byte[])cd;
                StringBuilder buf = new StringBuilder(v.Length*2);
                string hex = "0123456789ABCDEF";

                for (int j = 0; j < v.Length; j++)
                {
                  buf.Append(hex[(v[j] >> 4) & 0x0f]);
                  buf.Append(hex[v[j] & 0x0f]);
                }
                return buf.ToString();
            }
            else
                return cd.ToString();
		}

#if ADONET2
        public override Decimal GetDecimal (int i)
#else
		public Decimal GetDecimal (int i)
#endif
		{
			/*
			 * Force the cast to return the type. InvalidCastException
			 * should be thrown if the data is not already of the correct type.
			 */
			Debug.WriteLineIf (CLI.FnTrace.Enabled, "VirtuosoDataReader.GetDecimal()");
			return Convert.ToDecimal(GetColumnData (i));
		}

#if ADONET2
        public override DateTime GetDateTime (int i)
#else
		public DateTime GetDateTime (int i)
#endif
		{
			/*
			 * Force the cast to return the type. InvalidCastException
			 * should be thrown if the data is not already of the correct type.
			 */
			Debug.WriteLineIf (CLI.FnTrace.Enabled, "VirtuosoDataReader.GetDateTime()");
			return Convert.ToDateTime(GetColumnData (i));
		}

		public SqlXml GetSqlXml (int i)
		{
			/*
			 * Force the cast to return the type. InvalidCastException
			 * should be thrown if the data is not already of the correct type.
			 */
			Debug.WriteLineIf (CLI.FnTrace.Enabled, "VirtuosoDataReader.GetSqlXml()");
			return (SqlXml) GetColumnData (i);
		}

#if !ADONET2
		public IDataReader GetData (int i)
		{
			/*
			 * The sample code does not support this method. Normally,
			 * this would be used to expose nested tables and
			 * other hierarchical data.
			 */
			Debug.WriteLineIf (CLI.FnTrace.Enabled, "VirtuosoDataReader.GetData()");
			throw new NotSupportedException("GetData not supported.");
		}
#endif

#if ADONET2
        public override bool IsDBNull (int i)
#else
		public bool IsDBNull (int i)
#endif
		{
			Debug.WriteLineIf (CLI.FnTrace.Enabled, "VirtuosoDataReader.IsDBNull()");

			ColumnData column = columns[i];
			if (column.data == null	&& column.columnType.isLong)
				return innerCommand.IsDBNull (i, columns);

			return Convert.IsDBNull (GetColumnData (i));
		}

		/*
		 * Implementation specific methods.
		 */

		internal ColumnData[] Columns
		{
			get { return columns; }
		}

		private void InitializeResultInfo (bool schemaOnly)
		{
			if (schemaOnly)
				rows = 0;
			else
				rows = innerCommand.GetRowCount ();

			columns = innerCommand.GetColumnMetaData ();
			if (columns == null)
				over = true;
			else
				over = false;
		}

		private object GetColumnData (int i)
		{
			ColumnData column = columns[i];
            		Type type = column.columnType.bufferType.type;
			if (column.data == null)
				column.data = innerCommand.GetColumnData (i, columns);
            		if (column.data != null && !Convert.IsDBNull(column.data) && type != column.data.GetType())
            		{
                		if (column.data is IConvertData)
                    			return ((IConvertData)column.data).ConvertData(type);
                		else if (column.data is IConvertible)
                          {
                            switch (column.data.GetType().FullName)
                            {
                                case "System.Int64":
                                case "System.Int32":
                                case "System.Single":
                                case "System.Double":
                                case "System.Decimal":
                                case "System.DateTime":
                                case "OpenLink.Data.Virtuoso.VirtuosoDateTime":
                                case "System.DateTimeOffset":
                                case "OpenLink.Data.Virtuoso.VirtuosoDateTimeOffset":
                                case "System.TimeSpan":
                                case "OpenLink.Data.Virtuoso.VirtuosoTimeSpan":
                                    return column.data;
                                default:
                    			return Convert.ChangeType(column.data, type);
                            }
                          }
                        	else if (column.data is SqlExtendedString)
                                	return column.data;
                        	else if (column.data is SqlRdfBox)
                                	return column.data;
                		else
                          {
                            switch (column.data.GetType().FullName)
                            {
                                case "System.DateTime":
                                case "OpenLink.Data.Virtuoso.VirtuosoDateTime":
                                case "System.DateTimeOffset":
                                case "OpenLink.Data.Virtuoso.VirtuosoDateTimeOffset":
                                case "System.TimeSpan":
                                case "OpenLink.Data.Virtuoso.VirtuosoTimeSpan":
                                case "System.Byte[]":
                                    return column.data;
                                default:
                    			return column.data.ToString();
            		}
                          }
            		}
            		else
				return column.data;
		}

		private void ResetColumn (int i)
		{
			ColumnData column = columns[i];
			column.data = null;
			column.lobLength = 0;
			column.lobOffset = 0;
		}

#if ADONET2
		protected override void Dispose (bool disposing)
#else
		private void Dispose (bool disposing)
#endif
		{
			try
			{
			if (disposing)
				Close ();
			connection = null;
        }
			catch (Exception e)
			{
				Debug.WriteLineIf(CLI.FnTrace.Enabled,
				"VirtousoDataReader.Dispose caught exception: " + e.Message);
			}
        	}
        #region ADO.NET 2.0
#if ADONET2
        public override bool  HasRows
        {
	      get { 
              //TODO:
              throw new global::System.NotImplementedException(); 
          }
        }

        public new void Dispose ()
        {
        }

        public override IEnumerator GetEnumerator()
        {
            //TODO:
            throw new global::System.NotImplementedException();
        }
#endif
#endregion

    }
}

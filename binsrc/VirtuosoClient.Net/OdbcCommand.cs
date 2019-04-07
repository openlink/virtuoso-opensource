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
using System.Diagnostics;
using System.Runtime.InteropServices;

#if ODBC_CLIENT
namespace OpenLink.Data.VirtuosoOdbcClient
#elif CLIENT
namespace OpenLink.Data.VirtuosoClient
#else
namespace OpenLink.Data.Virtuoso
#endif
{
	internal sealed class OdbcCommand : IInnerCommand, ICreateErrors, IDisposable
	{
		internal IntPtr hstmt;
		private VirtuosoCommand outerCommand;
		private ParameterData parameterData = null;

		private MemoryHandle dataBuffer = null;

		internal OdbcCommand (IntPtr hstmt, VirtuosoCommand outerCommand)
		{
			this.hstmt = hstmt;
			this.outerCommand = outerCommand;
		}

		~OdbcCommand ()
		{
			Dispose (false);
		}

		public void Dispose ()
		{
			Dispose (true);
			GC.SuppressFinalize (this);
		}

		public VirtuosoErrorCollection CreateErrors ()
		{
			return OdbcErrors.CreateErrors (CLI.HandleType.SQL_HANDLE_STMT, hstmt);
		}

		public void Cancel ()
		{
			CLI.ReturnCode rc = (CLI.ReturnCode) CLI.SQLCancel (hstmt);
			if (rc != CLI.ReturnCode.SQL_SUCCESS)
				Diagnostics.HandleResult (rc, this, outerCommand.Connection);
			GC.KeepAlive (this);
		}

		public void SetTimeout (int timeout)
		{
			CLI.ReturnCode rc = (CLI.ReturnCode) CLI.SQLSetStmtAttr (
				hstmt,
				(int) CLI.StatementAttribute.SQL_ATTR_QUERY_TIMEOUT,
				(IntPtr) timeout,
				(int) CLI.LengthCode.SQL_IS_SMALLINT);
			if (rc != CLI.ReturnCode.SQL_SUCCESS)
				Diagnostics.HandleResult (rc, this, outerCommand.Connection);
			GC.KeepAlive (this);
		}

		public void SetConcurrencyMode(CommandConcurrency concurrency)
		{
			int mode = CLI.Concurrency.SQL_CONCUR_READ_ONLY;

			if (concurrency == CommandConcurrency.CONCUR_PESSIMISTIC)
			   mode = CLI.Concurrency.SQL_CONCUR_LOCK;
			else if (concurrency == CommandConcurrency.CONCUR_OPTIMISTIC)
			   mode = CLI.Concurrency.SQL_CONCUR_VALUES;

			CLI.ReturnCode rc = (CLI.ReturnCode) CLI.SQLSetStmtAttr (
				hstmt,
				(int) CLI.StatementAttribute.SQL_ATTR_CONCURRENCY,
				(IntPtr) mode,
				(int) CLI.LengthCode.SQL_IS_SMALLINT);
			if (rc != CLI.ReturnCode.SQL_SUCCESS)
				Diagnostics.HandleResult (rc, this, outerCommand.Connection);
			GC.KeepAlive (this);

		}

		public void SetCommandBehavior (CommandBehavior behavior)
		{
			int unique_rows = 0;
			if ((behavior & CommandBehavior.KeyInfo) != 0)
				unique_rows = 1;

			CLI.ReturnCode rc = (CLI.ReturnCode) CLI.SQLSetStmtAttr (
				hstmt,
				(int) CLI.StatementAttribute.SQL_UNIQUE_ROWS,
				(IntPtr) unique_rows,
				(int) CLI.LengthCode.SQL_IS_SMALLINT);
			if (rc != CLI.ReturnCode.SQL_SUCCESS)
				Diagnostics.HandleResult (rc, this, outerCommand.Connection);
			GC.KeepAlive (this);
		}

		public void SetParameters (VirtuosoParameterCollection parameters)
		{
			if (parameterData != null)
			{
				parameterData.Dispose ();
				parameterData = null;
			}
			if (parameters != null && parameters.Count > 0)
			{
				parameterData = new ParameterData (parameters);
				parameterData.SetParameters ((VirtuosoConnection) outerCommand.Connection, hstmt);
			}
		}

		public void GetParameters ()
		{
			if (parameterData != null)
			{
				while (GetNextResult ())
					;
				parameterData.GetParameters ();
				DisposeParameters ();
			}
		}

		public void Execute (string query)
		{
			Debug.WriteLineIf (CLI.FnTrace.Enabled, "OdbcCommand.Execute(\"" + query + "\")");
			CLI.ReturnCode rc;
#if WIN32_ONLY
			rc = (CLI.ReturnCode) CLI.SQLExecDirect (hstmt, query, query.Length);
#else
			int size = (query.Length + 1) * Platform.WideCharSize;
			MemoryHandle buffer = new MemoryHandle (size);
			try
			{
				Platform.StringToWideChars (query, buffer.Handle, size);
				rc = (CLI.ReturnCode) CLI.SQLExecDirect (hstmt, buffer.Handle, (int) CLI.LengthCode.SQL_NTS);
			}
			finally
			{
				if (buffer != null)
					buffer.Dispose ();
			}
#endif
			if (rc != CLI.ReturnCode.SQL_SUCCESS)
			{
				if (rc != CLI.ReturnCode.SQL_SUCCESS_WITH_INFO)
					DisposeParameters ();
				Diagnostics.HandleResult (rc, this, outerCommand.Connection);
			}
			GC.KeepAlive (this);
		}

		public void Prepare (string query)
		{
			CLI.ReturnCode rc;
#if WIN32_ONLY
			rc = (CLI.ReturnCode) CLI.SQLPrepare (hstmt, query, query.Length);
#else
			int size = (query.Length + 1) * Platform.WideCharSize;
			MemoryHandle buffer = new MemoryHandle (size);
			try
			{
				Platform.StringToWideChars (query, buffer.Handle, size);
				rc = (CLI.ReturnCode) CLI.SQLPrepare (hstmt, buffer.Handle, (int) CLI.LengthCode.SQL_NTS);
			}
			finally
			{
				if (buffer != null)
					buffer.Dispose ();
			}
#endif
			if (rc != CLI.ReturnCode.SQL_SUCCESS)
				Diagnostics.HandleResult (rc, this, outerCommand.Connection);
			GC.KeepAlive (this);
		}

		public void Execute ()
		{
			CLI.ReturnCode rc = (CLI.ReturnCode) CLI.SQLExecute (hstmt);
			if (rc != CLI.ReturnCode.SQL_SUCCESS)
			{
				if (rc != CLI.ReturnCode.SQL_SUCCESS_WITH_INFO)
					DisposeParameters ();
				Diagnostics.HandleResult (rc, this, outerCommand.Connection);
			}
			GC.KeepAlive (this);
		}

		public void GetProcedureColumns (string text)
		{
			CLI.ReturnCode rc;
#if WIN32_ONLY
			rc = (CLI.ReturnCode) CLI.SQLProcedureColumns (
				hstmt,
				null, 0,
				null, 0,
				text, (short) CLI.LengthCode.SQL_NTS,
				null, 0);
#else
			int size = (text.Length + 1) * Platform.WideCharSize;
			MemoryHandle buffer = new MemoryHandle (size);
			try
			{
				Platform.StringToWideChars (text, buffer.Handle, size);
				rc = (CLI.ReturnCode) CLI.SQLProcedureColumns (
					hstmt,
					IntPtr.Zero, 0,
					IntPtr.Zero, 0,
					buffer.Handle, (short) CLI.LengthCode.SQL_NTS,
					IntPtr.Zero, 0);
			}
			finally
			{
				if (buffer != null)
					buffer.Dispose ();
			}
#endif
			if (rc != CLI.ReturnCode.SQL_SUCCESS)
				Diagnostics.HandleResult (rc, this, outerCommand.Connection);
			GC.KeepAlive (this);
		}

		public int GetRowCount ()
		{
			IntPtr count;
			CLI.ReturnCode rc = (CLI.ReturnCode) CLI.SQLRowCount (hstmt, out count);
			if (rc != CLI.ReturnCode.SQL_SUCCESS)
				Diagnostics.HandleResult (rc, this, outerCommand.Connection);

			GC.KeepAlive (this);
			return (int) count;
		}

		public ColumnData[] GetColumnMetaData ()
		{
			int columnCount = GetResultColumns ();
			if (columnCount == 0)
				return null;

			ColumnData[] columns = new ColumnData[columnCount];

			MemoryHandle name = new MemoryHandle ((CLI.SQL_MAX_COLUMN_NAME_LEN + 1) * Platform.WideCharSize);
			try 
			{
				for (int i = 0; i < columnCount; i++)
				{
					CLI.ReturnCode rc;
					short length, dataType, decimalDigits, nullable;
					uint columnSize;
					IntPtr iVal;

					ColumnData column = new ColumnData ();
					columns[i] = column;

					rc = (CLI.ReturnCode) CLI.SQLDescribeCol (
						hstmt, (ushort) (i + 1),
						name.Handle, (short) name.Length, out length,
						out dataType, out columnSize, out decimalDigits, out nullable);
					if (rc != CLI.ReturnCode.SQL_SUCCESS)
						Diagnostics.HandleResult (rc, this, outerCommand.Connection);
					length = (short) (length * Platform.WideCharSize);

					column.columnName = Platform.WideCharsToString (name.Handle, length);
					//System.Console.WriteLine ("name.Length: {0}, length: {1}, columnName: {2}", name.Length, length, column.columnName);
					    Debug.WriteLineIf (SqlXml.Switch.TraceVerbose, 
						String.Format ("SQLColAttribute col={0} data_type={1}", 
						  column.columnName, dataType));
					column.columnType = DataTypeInfo.MapSqlType ((CLI.SqlType) dataType);
					if (((CLI.SqlType)dataType) == CLI.SqlType.SQL_WLONGVARCHAR)
					  {
					    MemoryHandle bcolt = new MemoryHandle (
						(CLI.SQL_MAX_COLUMN_NAME_LEN + 1) * Platform.WideCharSize);
					    short blength;
					    IntPtr biVal;

					    Debug.WriteLineIf (SqlXml.Switch.TraceVerbose, 
						String.Format ("Calling SQLColAttribute for col {0}", 
						  column.columnName));
					    rc = (CLI.ReturnCode) CLI.SQLColAttribute (
						hstmt, (ushort) (i + 1),
						(ushort) CLI.DescriptorField.SQL_DESC_LOCAL_TYPE_NAME,
						bcolt.Handle, (short) bcolt.Length, out blength, out biVal);
					    Debug.WriteLineIf (SqlXml.Switch.TraceInfo, 
						String.Format (
						  "Calling SQLColAttribute for col {0} returned rc={1}", 
						  column.columnName, rc));
					    if (rc == CLI.ReturnCode.SQL_SUCCESS)
					      {
						String baseColumnType = Platform.WideCharsToString (
						    bcolt.Handle, blength);
						Debug.WriteLineIf (SqlXml.Switch.TraceInfo, 
						    String.Format (
						      "Calling SQLColAttribute for col {0} returned type={1}", 
						      column.columnName, baseColumnType));
						if (baseColumnType == "XMLType")
						  column.columnType = DataTypeInfo.Xml;
					      }
					  }
					  
					if (column.columnType == null)
						throw new SystemException ("Unknown data type");
					column.bufferType = column.columnType.bufferType;
					column.columnSize = column.columnType.GetFieldSize ((int) columnSize);
					column.precision = (short) column.columnSize;
					column.scale = decimalDigits;

					column.IsLong = column.columnType.isLong;
					column.IsNullable = nullable == 0 ? false : true;

					rc = (CLI.ReturnCode) CLI.SQLColAttribute (
						hstmt, (ushort) (i + 1),
						(ushort) CLI.ColumnAttribute.SQL_COLUMN_UPDATABLE,
						IntPtr.Zero, (short) 0, out length, out iVal);
					if (rc != CLI.ReturnCode.SQL_SUCCESS)
						Diagnostics.HandleResult (rc, this, outerCommand.Connection);
					CLI.Updatable updatable = (CLI.Updatable) (int) iVal;
					column.IsReadOnly = (updatable == CLI.Updatable.SQL_ATTR_READONLY);

					rc = (CLI.ReturnCode) CLI.SQLColAttribute (
						hstmt, (ushort) (i + 1),
						(ushort) CLI.ColumnAttribute.SQL_COLUMN_KEY,
						IntPtr.Zero, (short) 0, out length, out iVal);
					if (rc != CLI.ReturnCode.SQL_SUCCESS)
						Diagnostics.HandleResult (rc, this, outerCommand.Connection);
					column.IsKey = (((int) iVal) != 0);

					rc = (CLI.ReturnCode) CLI.SQLColAttribute (
						hstmt, (ushort) (i + 1),
						(ushort) CLI.ColumnAttribute.SQL_COLUMN_HIDDEN,
						IntPtr.Zero, (short) 0, out length, out iVal);
					if (rc != CLI.ReturnCode.SQL_SUCCESS)
						Diagnostics.HandleResult (rc, this, outerCommand.Connection);
					column.IsHidden = (((int) iVal) != 0);

					rc = (CLI.ReturnCode) CLI.SQLColAttribute (
						hstmt, (ushort) (i + 1),
						(ushort) CLI.ColumnAttribute.SQL_COLUMN_AUTO_INCREMENT,
						IntPtr.Zero, (short) 0, out length, out iVal);
					if (rc != CLI.ReturnCode.SQL_SUCCESS)
						Diagnostics.HandleResult (rc, this, outerCommand.Connection);
					column.IsAutoIncrement = (((int) iVal) != 0);

					rc = (CLI.ReturnCode) CLI.SQLColAttribute (
						hstmt, (ushort) (i + 1),
						(ushort) CLI.DescriptorField.SQL_DESC_ROWVER,
						IntPtr.Zero, (short) 0, out length, out iVal);
					if (rc != CLI.ReturnCode.SQL_SUCCESS)
						Diagnostics.HandleResult (rc, this, outerCommand.Connection);
					column.IsRowVersion = (((int) iVal) != 0);

					// TODO: check for unique columns as well.
					column.IsUnique = false;

					rc = (CLI.ReturnCode) CLI.SQLColAttribute (
						hstmt, (ushort) (i + 1),
						(ushort) CLI.DescriptorField.SQL_DESC_BASE_COLUMN_NAME,
						name.Handle, (short) name.Length, out length, out iVal);
					if (rc != CLI.ReturnCode.SQL_SUCCESS)
						Diagnostics.HandleResult (rc, this, outerCommand.Connection);
					column.baseColumnName = Platform.WideCharsToString (name.Handle, length);
					//System.Console.WriteLine ("name.Length: {0}, length: {1}, baseColumnName: {2}", name.Length, length, column.baseColumnName);

					rc = (CLI.ReturnCode) CLI.SQLColAttribute (
						hstmt, (ushort) (i + 1),
						(ushort) CLI.DescriptorField.SQL_DESC_BASE_TABLE_NAME,
						name.Handle, (short) name.Length, out length, out iVal);
					if (rc != CLI.ReturnCode.SQL_SUCCESS)
						Diagnostics.HandleResult (rc, this, outerCommand.Connection);
					column.baseTableName = Platform.WideCharsToString (name.Handle, length);

					rc = (CLI.ReturnCode) CLI.SQLColAttribute (
						hstmt, (ushort) (i + 1),
						(ushort) CLI.DescriptorField.SQL_DESC_SCHEMA_NAME,
						name.Handle, (short) name.Length, out length, out iVal);
					if (rc != CLI.ReturnCode.SQL_SUCCESS)
						Diagnostics.HandleResult (rc, this, outerCommand.Connection);
					column.baseSchemaName = Platform.WideCharsToString (name.Handle, length);

					rc = (CLI.ReturnCode) CLI.SQLColAttribute (
						hstmt, (ushort) (i + 1),
						(ushort) CLI.DescriptorField.SQL_DESC_CATALOG_NAME,
						name.Handle, (short) name.Length, out length, out iVal);
					if (rc != CLI.ReturnCode.SQL_SUCCESS)
						Diagnostics.HandleResult (rc, this, outerCommand.Connection);
					column.baseCatalogName = Platform.WideCharsToString (name.Handle, length);

					if (column.baseTableName == null || column.baseTableName == "")
						column.IsExpression = true;
					else
						column.IsExpression = false;
				}

				GC.KeepAlive (this);
			}
			finally
			{
				name.Dispose ();
			}

			return columns;
		}

		public object GetColumnData (int i, ColumnData[] columns)
		{
			if (dataBuffer == null)
				dataBuffer = new MemoryHandle (2048);

			ColumnData column = columns[i];
			BufferType type = column.bufferType;
			object columnData;// = column.data;

			IntPtr length;
			CLI.ReturnCode rc = (CLI.ReturnCode) CLI.SQLGetData (
				hstmt,
				(ushort) (i + 1),
				(short) type.sqlCType,
				dataBuffer.Handle,
				(IntPtr) dataBuffer.Length,
				out length);
			if (rc != CLI.ReturnCode.SQL_SUCCESS && rc != CLI.ReturnCode.SQL_SUCCESS_WITH_INFO)
				Diagnostics.HandleResult (rc, this, outerCommand.Connection);

			if (length == (IntPtr) (int) CLI.LengthCode.SQL_NULL_DATA)
				columnData = DBNull.Value;
			else if ((int) length <= (dataBuffer.Length - type.NullTermSize) && (int) length >= 0)
				columnData = type.NativeToManaged (dataBuffer.Handle, (int) length);
			else
			{
				column.lobOffset = 0;
				column.lobLength = (int) length;
				columnData = type.NativeSizeToManaged (column.lobLength);
				type.NativePartToManaged (dataBuffer.Handle, dataBuffer.Length - type.NullTermSize, columnData, ref column.lobOffset);
				for (;;)
				{
					rc = (CLI.ReturnCode) CLI.SQLGetData (
						hstmt,
						(ushort) (i + 1),
						(short) column.bufferType.sqlCType,
						dataBuffer.Handle,
						(IntPtr) dataBuffer.Length,
						out length);
					if (rc == CLI.ReturnCode.SQL_NO_DATA)
						break;
					if (rc != CLI.ReturnCode.SQL_SUCCESS && rc != CLI.ReturnCode.SQL_SUCCESS_WITH_INFO)
						Diagnostics.HandleResult (rc, this, outerCommand.Connection);

					int copyLength = (int) length;
					if (copyLength > dataBuffer.Length - type.NullTermSize)
						copyLength = dataBuffer.Length - type.NullTermSize;
					type.NativePartToManaged (dataBuffer.Handle, copyLength, columnData, ref column.lobOffset);
				}
				if (column.columnType.GetType() == typeof(DataTypeChar) ||
					column.columnType.GetType() == typeof(DataTypeWide))
					columnData = new String ((char []) columnData);
			}

			GC.KeepAlive (this);
			return columnData;
		}

		public bool Fetch ()
		{
#if false
			CLI.ReturnCode rc = (CLI.ReturnCode) CLI.SQLFetch (hstmt);
#else
			CLI.ReturnCode rc = (CLI.ReturnCode) CLI.SQLFetchScroll (hstmt, (short) CLI.FetchOrientation.SQL_FETCH_NEXT, (IntPtr) 0);
#endif
			if (rc != CLI.ReturnCode.SQL_SUCCESS)
			{
				if (rc == CLI.ReturnCode.SQL_NO_DATA)
					return false;
				Diagnostics.HandleResult (rc, this, outerCommand.Connection);
			}
			return true;
		}

		public bool GetNextResult ()
		{
			CLI.ReturnCode rc = (CLI.ReturnCode) CLI.SQLMoreResults (hstmt);
			if (rc != CLI.ReturnCode.SQL_SUCCESS && rc != CLI.ReturnCode.SQL_NO_DATA)
				Diagnostics.HandleResult (rc, this, outerCommand.Connection);
			GC.KeepAlive (this);
			return (rc == CLI.ReturnCode.SQL_SUCCESS);
		}

		public void CloseCursor (bool isExecuted)
		{
            if (!isExecuted)
              return;
			CLI.ReturnCode rc = (CLI.ReturnCode) CLI.SQLFreeStmt (hstmt, (ushort) CLI.FreeStmtOption.SQL_CLOSE);
			if (rc != CLI.ReturnCode.SQL_SUCCESS && rc != CLI.ReturnCode.SQL_NO_DATA)
				Diagnostics.HandleResult (rc, this, outerCommand.Connection);
			GC.KeepAlive (this);
		}

		public bool IsDBNull (int i, ColumnData[] columns)
		{
			if (dataBuffer == null)
				dataBuffer = new MemoryHandle (2048);

			ColumnData column = columns[i];
			BufferType type = column.bufferType;

			IntPtr length;
			CLI.ReturnCode rc = (CLI.ReturnCode) CLI.SQLGetData (
				hstmt,
				(ushort) (i + 1),
				(short) type.sqlCType,
				dataBuffer.Handle,
				(IntPtr) 0,
				out length);
			if (rc != CLI.ReturnCode.SQL_SUCCESS && rc != CLI.ReturnCode.SQL_SUCCESS_WITH_INFO)
				Diagnostics.HandleResult (rc, this, outerCommand.Connection);

			// rewind so that another IsDBNull() won't get SQL_NO_DATA
			RewindData (columns);

			return (length == (IntPtr) (int) CLI.LengthCode.SQL_NULL_DATA);
		}

		public long GetChars (int i, ColumnData[] columns, long fieldOffset,
			char[] buffer, int bufferOffset, int length)
		{
			if (dataBuffer == null)
				dataBuffer = new MemoryHandle (2048);

			CLI.ReturnCode rc;
			IntPtr outlen;
			ColumnData column = columns[i];

			if (fieldOffset < column.lobOffset)
				RewindData (columns);

			while (fieldOffset > column.lobOffset)
			{
				int dataLength = (int) (fieldOffset - column.lobOffset) * Platform.WideCharSize + Platform.WideCharSize;
				if (dataLength > dataBuffer.Length)
					dataLength = dataBuffer.Length;

				rc = (CLI.ReturnCode) CLI.SQLGetData (
					hstmt,
					(ushort) (i + 1),
					(short) CLI.SqlCType.SQL_C_WCHAR,
					dataBuffer.Handle,
					(IntPtr) dataLength,
					out outlen);
				if (rc == CLI.ReturnCode.SQL_NO_DATA)
					return 0;
				if (rc != CLI.ReturnCode.SQL_SUCCESS || rc != CLI.ReturnCode.SQL_SUCCESS_WITH_INFO)
					Diagnostics.HandleResult (rc, this, outerCommand.Connection);

				if (dataLength > (int) outlen)
					dataLength = (int) outlen;
				else
					dataLength -= Platform.WideCharSize;
				column.lobOffset += dataLength / Platform.WideCharSize;
			}

			if (buffer == null)
			{
				rc = (CLI.ReturnCode) CLI.SQLGetData (
					hstmt,
					(ushort) (i + 1),
					(short) CLI.SqlCType.SQL_C_WCHAR,
					dataBuffer.Handle,
					(IntPtr) 0,
					out outlen);
				if (rc == CLI.ReturnCode.SQL_NO_DATA)
					return 0;
				if (rc != CLI.ReturnCode.SQL_SUCCESS && rc != CLI.ReturnCode.SQL_SUCCESS_WITH_INFO)
					Diagnostics.HandleResult (rc, this, outerCommand.Connection);
				return (long) outlen / Platform.WideCharSize;
			}

			int readLength = 0;
			while (length > readLength)
			{
				int dataLength = (length - readLength) * Platform.WideCharSize + Platform.WideCharSize;
				if (dataLength > dataBuffer.Length)
					dataLength = dataBuffer.Length;

				rc = (CLI.ReturnCode) CLI.SQLGetData (
					hstmt,
					(ushort) (i + 1),
					(short) CLI.SqlCType.SQL_C_WCHAR,
					dataBuffer.Handle,
					(IntPtr) dataLength,
					out outlen);
				if (rc == CLI.ReturnCode.SQL_NO_DATA)
					break;
				if (rc != CLI.ReturnCode.SQL_SUCCESS || rc != CLI.ReturnCode.SQL_SUCCESS_WITH_INFO)
					Diagnostics.HandleResult (rc, this, outerCommand.Connection);

				if (dataLength > (int) outlen)
					dataLength = (int) outlen;
				else
					dataLength -= Platform.WideCharSize;

				char[] data = Platform.WideCharsToArray (dataBuffer.Handle, dataLength);
				Array.Copy (data, 0, buffer, bufferOffset, data.Length);
				column.lobOffset += data.Length;
				bufferOffset += data.Length;
				readLength += data.Length;
			}

			GC.KeepAlive (this);
			return readLength;
		}

		public long GetBytes (int i, ColumnData[] columns, long fieldOffset,
			byte[] buffer, int bufferOffset, int length)
		{
			if (dataBuffer == null)
				dataBuffer = new MemoryHandle (2048);

			CLI.ReturnCode rc;
			IntPtr outlen;
			ColumnData column = columns[i];

			if (fieldOffset < column.lobOffset)
				RewindData (columns);

			while (fieldOffset > column.lobOffset)
			{
				int dataLength = (int) fieldOffset - column.lobOffset;
				if (dataLength > dataBuffer.Length)
					dataLength = dataBuffer.Length;

				rc = (CLI.ReturnCode) CLI.SQLGetData (
					hstmt,
					(ushort) (i + 1),
					(short) CLI.SqlCType.SQL_C_BINARY,
					dataBuffer.Handle,
					(IntPtr) dataLength,
					out outlen);
				if (rc == CLI.ReturnCode.SQL_NO_DATA)
					return 0;
				if (rc != CLI.ReturnCode.SQL_SUCCESS)
					Diagnostics.HandleResult (rc, this, outerCommand.Connection);

				if (dataLength > (int) outlen)
					dataLength = (int) outlen;
				column.lobOffset += dataLength;
			}

			if (buffer == null)
			{
				rc = (CLI.ReturnCode) CLI.SQLGetData (
					hstmt,
					(ushort) (i + 1),
					(short) CLI.SqlCType.SQL_C_BINARY,
					dataBuffer.Handle,
					(IntPtr) 0,
					out outlen);
				if (rc == CLI.ReturnCode.SQL_NO_DATA)
					return 0;
				if (rc != CLI.ReturnCode.SQL_SUCCESS && rc != CLI.ReturnCode.SQL_SUCCESS_WITH_INFO)
					Diagnostics.HandleResult (rc, this, outerCommand.Connection);
				return (long) outlen;
			}

			int readLength = 0;
			while (length > readLength)
			{
				int dataLength = length - readLength;
				if (dataLength > dataBuffer.Length)
					dataLength = dataBuffer.Length;

				rc = (CLI.ReturnCode) CLI.SQLGetData (
					hstmt,
					(ushort) (i + 1),
					(short) CLI.SqlCType.SQL_C_BINARY,
					dataBuffer.Handle,
					(IntPtr) dataLength,
					out outlen);
				if (rc == CLI.ReturnCode.SQL_NO_DATA)
					break;
				if (rc != CLI.ReturnCode.SQL_SUCCESS || rc != CLI.ReturnCode.SQL_SUCCESS_WITH_INFO)
					Diagnostics.HandleResult (rc, this, outerCommand.Connection);

				if (dataLength > (int) outlen)
					dataLength = (int) outlen;
				column.lobOffset += dataLength;
				readLength += dataLength;

				Marshal.Copy (dataBuffer.Handle, buffer, bufferOffset, dataLength);
				bufferOffset += dataLength;
			}

			GC.KeepAlive (this);
			return readLength;
		}

		private void RewindData (ColumnData[] columns)
		{
			CLI.ReturnCode rc = (CLI.ReturnCode) CLI.SQLSetPos (hstmt, 1, (ushort) CLI.SetPosOp.SQL_POSITION, (ushort) CLI.LockOption.SQL_LOCK_NO_CHANGE);
			if (rc != CLI.ReturnCode.SQL_SUCCESS)
				Diagnostics.HandleResult (rc, this, outerCommand.Connection);
			GC.KeepAlive (this);

			for (int i = 0; i < columns.Length; i++)
				columns[i].lobOffset = 0;
		}

		private int GetResultColumns ()
		{
			short count;
			CLI.ReturnCode rc = (CLI.ReturnCode) CLI.SQLNumResultCols (hstmt, out count);
			if (rc != CLI.ReturnCode.SQL_SUCCESS)
				Diagnostics.HandleResult (rc, this, outerCommand.Connection);

			GC.KeepAlive (this);
			return count;
		}

		private void Dispose (bool disposing)
		{
			if (dataBuffer != null)
			{
				dataBuffer.Dispose ();
				dataBuffer = null;
			}
			hstmt = IntPtr.Zero;
		}

		private void DisposeParameters ()
		{
			CLI.ReturnCode rc = (CLI.ReturnCode) CLI.SQLFreeStmt (hstmt, (ushort) CLI.FreeStmtOption.SQL_RESET_PARAMS);
			if (rc != CLI.ReturnCode.SQL_SUCCESS && rc != CLI.ReturnCode.SQL_NO_DATA)
				Diagnostics.HandleResult (rc, this, outerCommand.Connection);
			GC.KeepAlive (this);

			if (parameterData != null)
			{
				parameterData.Dispose ();
				parameterData = null;
			}
		}
	}
}

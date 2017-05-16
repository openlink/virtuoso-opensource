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
	internal class ManagedCommand : IInnerCommand, ICreateErrors, IDisposable
	{
		internal readonly static BooleanSwitch Switch = 
		    new BooleanSwitch ("VirtuosoClient.ManagedCommand", "Marshaling");

		private ManagedConnection connection;
		private VirtuosoParameterCollection parameters;
		object[] parameterValues;

		private string id = null;

		private int timeout = 0;
		private int prefetchSize = Values.SELECT_PREFETCH_QUOTA;
		private CommandConcurrency concurrency = CommandConcurrency.CONCUR_DEFAULT;
		private bool uniqueRows = false;
		private ArrayOfLongPacked options = null;

		private Future pendingFuture = null;

		private int needDataParameter = 0;

		QueryType queryType = QueryType.QT_UNKNOWN;
		private ColumnData[] columns = null;

		private int affectedRows = 0;
		private int prefetchedRows = 0;
		private bool isLastResult = false;
		private bool isLastRow = false;
		private bool isLastInBatch = false;
		private bool isWaitedResult = false;

		private object[] prefetchRow = null;
		private object[] currentRow = null;

		private ManagedErrors errors = null;

		internal ManagedCommand (ManagedConnection connection)
		{
			this.connection = connection;
			errors = new ManagedErrors ();
		}

		public void Dispose ()
		{
			Dispose (true);
			GC.SuppressFinalize (this);
		}

		public VirtuosoErrorCollection CreateErrors ()
		{
			VirtuosoErrorCollection e = errors.CreateErrors ();
			errors.Clear ();
			return e;
		}

		public void Cancel ()
		{
                        lock(this)
                        {
                          if (pendingFuture != null && isWaitedResult)
                            {
								Future cancel = new Future (Service.Cancel);
								cancel.SendRequest (connection.Session);
                            }
                        }  
		}


		public void SetTimeout (int timeout)
		{
			if (timeout > (int.MaxValue / Values.MillisPerSec))
				timeout = int.MaxValue / Values.MillisPerSec;
			this.timeout = timeout;
		}

		public void SetConcurrencyMode(CommandConcurrency mode)
		{
			this.concurrency = mode;
		}

		public void SetCommandBehavior (CommandBehavior behavior)
		{
			uniqueRows = (0 != (behavior & CommandBehavior.KeyInfo));
		}

		public void SetParameters (VirtuosoParameterCollection parameters)
		{
			this.parameters = parameters;
			if (parameters == null)
			{
				parameterValues = new object[0];
				return;
			}

			parameterValues = new object[parameters.Count];
			for (int i = 0; i < parameters.Count; i++)
			{
				VirtuosoParameter param = (VirtuosoParameter) parameters[i];
				Debug.WriteLineIf (Switch.Enabled, "  param: " + param.paramName);

				object value = null;
				if (param.Direction == ParameterDirection.Input
					|| param.Direction == ParameterDirection.InputOutput)
				{
					value = param.Value;
					if (param.bufferType == null)
					{
						if (param.paramType != null)
							param.bufferType = param.paramType.bufferType;
						else if (value == null || Convert.IsDBNull (value))
							param.bufferType = VirtuosoParameter.defaultType.bufferType;
						else
							param.bufferType = BufferTypes.InferBufferType (value);
						if (param.bufferType == null)
							throw new InvalidOperationException ("Cannot infer parameter type");
					}
					value = param.bufferType.ConvertValue (param.Value);
				}
				Debug.WriteLineIf (Switch.Enabled, "  value: " + param.Value);
				if (value is System.String)
				{
				    BoxTag tag = (param.DbType == DbType.AnsiString ? BoxTag.DV_STRING : BoxTag.DV_WIDE);
				    parameterValues[i] = ExplicitString.CreateExplicitString((String)value, tag, connection);
				}
				else
				    parameterValues[i] = value;
			}
		}

		public void GetParameters ()
		{
			if (parameters != null && parameters.Count > 0)
			{
				while (GetNextResult ())
					;
				for (int i = 0; i < parameters.Count; i++)
				{
					VirtuosoParameter param = (VirtuosoParameter) parameters[i];
					if (param.Direction == ParameterDirection.ReturnValue
						|| param.Direction == ParameterDirection.Output
						|| param.Direction == ParameterDirection.InputOutput)
					{
						object data = parameterValues[i];
						if (param.bufferType == null)
						{
							if (param.paramType != null)
								param.bufferType = param.paramType.bufferType;
							else if (data == null || Convert.IsDBNull (data))
								param.bufferType = VirtuosoParameter.defaultType.bufferType;
							else
								param.bufferType = BufferTypes.InferBufferType (data);
							if (param.bufferType == null)
								throw new InvalidOperationException ("Cannot infer parameter type");
						}

						data = param.bufferType.ConvertValue (data);
						param.paramData = data;
					}
				}
			}
		}

		public void Execute (string query)
		{
			if (pendingFuture != null)
				throw new InvalidOperationException ("The command is already active.");

			IMarshal marshaledQuery = ExplicitString.CreateExecString (connection, query);

			queryType = QueryType.QT_UNKNOWN;
			affectedRows = prefetchedRows = 0;
			isLastResult = isLastRow = isLastInBatch = false;
			prefetchRow = currentRow = null;

			object[] parameterRows = new object[1];
			parameterRows[0] = parameterValues;
			Future future = new Future (Service.Execute, GetId (), marshaledQuery, GetId (), parameterRows, null, GetOptions ());
			SendRequest (future);
			CLI.ReturnCode rc = ProcessResult (true);

			if (rc != CLI.ReturnCode.SQL_SUCCESS && rc != CLI.ReturnCode.SQL_NO_DATA)
			{
				if (rc != CLI.ReturnCode.SQL_SUCCESS_WITH_INFO)
				{
				    pendingFuture = null;
					connection.futures.Remove(future);
				}
				Diagnostics.HandleResult (rc, this, connection.OuterConnection);
			}
		}

		public void Prepare (string query)
		{
			if (pendingFuture != null)
				throw new InvalidOperationException ("The command is already active.");

			IMarshal marshaledQuery = ExplicitString.CreateExecString (connection, query);

			Future future = new Future (Service.Prepare, GetId (), marshaledQuery, 0, GetOptions ());
			SendRequest (future);
			CLI.ReturnCode rc = ProcessResult (false);
			if (rc != CLI.ReturnCode.SQL_SUCCESS && rc != CLI.ReturnCode.SQL_NO_DATA)
			{
                		if (rc != CLI.ReturnCode.SQL_SUCCESS_WITH_INFO)
                		{
				pendingFuture = null;
                    				connection.futures.Remove(future);
                		}
				Diagnostics.HandleResult (rc, this, connection.OuterConnection);
			}
		}

		public void Execute ()
		{
			Execute (null);
		}

		public void GetProcedureColumns (string text)
		{
			VirtuosoParameterCollection p = new VirtuosoParameterCollection (null);
			p.Add ("p1", connection.OuterConnection.Database);
			p.Add ("p2", "%");
			p.Add ("p3", text);
			p.Add ("p4", "%");
			p.Add ("p5", 1); // TODO: take casemode from the connection.
			p.Add ("p6", 1);
			SetParameters (p);
			Execute ("DB.DBA.SQL_PROCEDURE_COLUMNS (?, ?, ?, ?, ?, ?)");
		}

		public bool Fetch ()
		{
			Debug.WriteLineIf (CLI.FnTrace.Enabled, "ManagedCommand.Fetch ()");

			for (;;)
			{
				Debug.WriteLineIf (Switch.Enabled, "isLastRow: " + isLastRow);
				if (isLastRow)
				{
					currentRow = null;
					return false;
				}
				if (prefetchRow != null)
				{
					prefetchedRows++;
					currentRow = prefetchRow;
					prefetchRow = null;
					return true;
				}
				Debug.WriteLineIf (Switch.Enabled, "prefetchedRows: " + prefetchedRows + " / " + prefetchSize);
				Debug.WriteLineIf (Switch.Enabled, "isLastInBatch: " + isLastInBatch);
				if ((prefetchedRows == prefetchSize || isLastInBatch)
					&& queryType == QueryType.QT_SELECT)
				{
					Future future = new Future(Service.Fetch, id, pendingFuture.RequestNo);
					future.SendRequest(connection.Session, timeout);
					prefetchedRows = 0;
					isLastInBatch = false;
				}

				CLI.ReturnCode rc = ProcessResult (true);
				if (rc != CLI.ReturnCode.SQL_SUCCESS)
				{
					if (rc == CLI.ReturnCode.SQL_NO_DATA)
						return false;
					Diagnostics.HandleResult (rc, this, connection.OuterConnection);
				}
			}
		}

		public bool GetNextResult()
		{
			Debug.WriteLineIf (CLI.FnTrace.Enabled, "ManagedCommand.GetNextResult ()");

			while (!isLastRow)
				Fetch ();
			if (isLastResult)
				return false;

			CLI.ReturnCode rc = ProcessResult (true);
			if (rc != CLI.ReturnCode.SQL_SUCCESS && rc != CLI.ReturnCode.SQL_NO_DATA)
				Diagnostics.HandleResult (rc, this, connection.OuterConnection);
			return (rc == CLI.ReturnCode.SQL_SUCCESS || rc == CLI.ReturnCode.SQL_SUCCESS_WITH_INFO);
		}

		public void CloseCursor (bool isExecuted)
		{
			Debug.WriteLineIf (CLI.FnTrace.Enabled, "ManagedCommand.CloseCursor ()");

                        if (isExecuted)
                        {
			      currentRow = prefetchRow = null;
			      if (!isLastRow)
			      {
			          Future future = new Future (Service.FreeStmt, GetId (), (int) CLI.FreeStmtOption.SQL_CLOSE);
			          try
			          {
				      connection.futures.Add (future);
				      future.SendRequest (connection.Session);
				      future.GetResult (connection.Session, connection.futures);
			          }
			          finally
			          {
				      connection.futures.Remove (future);
			          }
			      }
                        }

			if (pendingFuture != null && connection.futures != null)
			{
				connection.futures.Remove (pendingFuture);
				pendingFuture = null;
			}
		}

		public int GetRowCount ()
		{
			return affectedRows;
		}

		public ColumnData[] GetColumnMetaData ()
		{
			return columns;
		}

		public object GetColumnData (int i, ColumnData[] columns)
		{
		    Debug.WriteLineIf (CLI.FnTrace.Enabled, "ManagedCommand.GetColumnData"); 
			Debug.Assert (currentRow != null);
			ColumnData column = columns[i];
			object data = currentRow[i + 1];
			if (data is BlobHandle)
			{
				BlobHandle blob = (BlobHandle) data;

				column.lobOffset = 0;
				column.lobLength = blob.length;

				if (column.columnType.GetType() == typeof(DataTypeChar) ||
					column.columnType.GetType() == typeof(DataTypeWide))
				{
					char[] chars = new char[blob.length];
					GetData (column, blob, blob.length, chars, 0);
					data = new String (chars);
				}
				else
				{
					byte[] bytes = new byte[blob.length];
					GetData (column, blob, blob.length, bytes, 0);
					data = bytes;
				}
			}
			else
			{
				Debug.Assert (column.bufferType != null);
				if (data is DateTimeMarshaler)
                                  data = ((IConvertData)data).ConvertData(typeof(DateTime));
				else
				data = column.bufferType.ConvertValue (data);
			}
			return data;
		}

		public bool IsDBNull (int i, ColumnData[] columns)
		{
			Debug.Assert (currentRow != null);
			return Convert.IsDBNull (currentRow[i + 1]);
		}

		public long GetChars (int i, ColumnData[] columns, long fieldOffset,
			char[] buffer, int bufferOffset, int length)
		{
			ColumnData column = columns[i];
			object data = currentRow[i + 1];
			if (data is BlobHandle)
			{
				BlobHandle blob = (BlobHandle) data;
				if (buffer == null)
					return blob.length < fieldOffset ? 0 : blob.length - fieldOffset;
				if (fieldOffset < column.lobOffset)
				{
					blob.Rewind ();
					column.lobOffset = 0;
				}
				if (fieldOffset > column.lobOffset)
				{
					GetData (column, blob, (int) (fieldOffset - column.lobOffset), null, 0);
					if (fieldOffset > column.lobOffset)
						return 0;
				}
				return GetData (column, blob, length, buffer, bufferOffset);
			}
			else
			{
				char[] chars = ((string) data).ToCharArray ();
				if (buffer == null)
					return chars.Length < fieldOffset ? 0 : chars.Length - fieldOffset;
				if (length > (chars.Length - fieldOffset))
					length = (int) (chars.Length - fieldOffset);
				Array.Copy (chars, (int) fieldOffset, buffer, bufferOffset, length);
				return length;
			}
		}

		public long GetBytes (int i, ColumnData[] columns, long fieldOffset,
			byte[] buffer, int bufferOffset, int length)
		{
			ColumnData column = columns[i];
			object data = currentRow[i + 1];
			if (data is BlobHandle)
			{
				BlobHandle blob = (BlobHandle) data;
				if (buffer == null)
					return blob.length < fieldOffset ? 0 : blob.length - fieldOffset;
				if (fieldOffset < column.lobOffset)
				{
					blob.Rewind ();
					column.lobOffset = 0;
				}
				if (fieldOffset > column.lobOffset)
				{
					GetData (column, blob, (int) (fieldOffset - column.lobOffset), null, 0);
					if (fieldOffset > column.lobOffset)
						return 0;
				}
				return GetData (column, blob, length, buffer, bufferOffset);
			}
			else if (data is byte[])
			{
				byte[] bytes = (byte[]) data;
				if (buffer == null)
					return bytes.Length < fieldOffset ? 0 : bytes.Length - fieldOffset;
				if (length > (bytes.Length - fieldOffset))
					length = (int) (bytes.Length - fieldOffset);
				Array.Copy (bytes, (int) fieldOffset, buffer, bufferOffset, length);
				return length;
			}
			else if (data is string)
			{
				string str = (string) data;
				if (buffer == null)
					return str.Length < fieldOffset ? 0 : str.Length - fieldOffset;
				if (length > (str.Length - fieldOffset))
					length = (int) (str.Length - fieldOffset);
				BufferTypeBinary.ConvertStringToBytes (str, buffer, 
				    bufferOffset, length,
				    (int) fieldOffset);
				return length;
			}
			else
			  throw new NotSupportedException ();
		}

		private long GetData (ColumnData column, BlobHandle blob, int length, object buffer, int bufferOffset)
		{
			Debug.WriteLineIf (CLI.FnTrace.Enabled, "ManagedCommand.GetData()");

			Future future = new Future (Service.GetData,
				blob.current_page,
				length,
				blob.current_position,
				blob.keyId,
				blob.fragNo,
				blob.dirPage,
				blob.pages,
				blob.tag == BoxTag.DV_BLOB_WIDE_HANDLE ? 1 : 0,
				blob.timeStamp);

			object result = null;
			try
			{
				connection.futures.Add (future);
				future.SendRequest (connection.Session, timeout);
				result = future.GetResult (connection.Session, connection.futures);
			}
			finally
			{
				connection.futures.Remove (future);
			}

			if (!(result is object[]))
				return 0;

			object[] results = (object[]) result;
			if (results[0] is int && (AnswerTag) results[0] == AnswerTag.QA_ERROR)
			{
				errors.AddServerError ((string) results[1], null, (string) results[2]);
				Diagnostics.HandleResult (CLI.ReturnCode.SQL_ERROR, this, connection.OuterConnection);
			}

			int startOffset = column.lobOffset;
			for (int i = 0; i < results.Length; i++)
			{
				if (results[i] is int[])
				{
					int[] array = (int[]) results[i];
					blob.current_page = array[1];
					blob.current_position = array[2];
					continue;
				}
				else if (results[i] is string)
				{
					string s = (string) results[i];
					if (buffer is char[])
					{
						char[] chars = s.ToCharArray ();
						char[] charBuffer = (char[]) buffer;

						Debug.WriteLineIf (Switch.Enabled, "do chars");
						Debug.WriteLineIf (Switch.Enabled, "buffer length: " + 
						    (charBuffer == null ? "no" : charBuffer.Length.ToString ()));
						Debug.WriteLineIf (Switch.Enabled, "buffer offset: " + bufferOffset);
						Debug.WriteLineIf (Switch.Enabled, "data length: " + chars.Length);
						Debug.WriteLineIf (Switch.Enabled, "length: " + length);

						if (charBuffer != null)
						{
							int copyLength = length < chars.Length ? length : chars.Length;
							Array.Copy (chars, 0, charBuffer, bufferOffset, copyLength);
						}
						column.lobOffset += chars.Length;
						bufferOffset += chars.Length;
						length -= chars.Length;
					}
					else
					{
						byte[] bytes = Encoding.GetEncoding ("iso-8859-1").GetBytes (s);
						byte[] byteBuffer = (byte[]) buffer;

						Debug.WriteLineIf (Switch.Enabled, "do bytes");
						Debug.WriteLineIf (Switch.Enabled, "buffer length: " + 
						    (byteBuffer == null ? "no" : byteBuffer.Length.ToString ()));
						Debug.WriteLineIf (Switch.Enabled, "buffer offset: " + bufferOffset);
						Debug.WriteLineIf (Switch.Enabled, "data length: " + bytes.Length);
						Debug.WriteLineIf (Switch.Enabled, "length: " + length);

						if (byteBuffer != null)
						{
							int copyLength = length < bytes.Length ? length : bytes.Length;
							Array.Copy (bytes, 0, byteBuffer, bufferOffset, copyLength);
						}
						column.lobOffset += bytes.Length;
						bufferOffset += bytes.Length;
						length -= bytes.Length;
					}
				}
			}
			return column.lobOffset - startOffset;
		}

		private string GetId ()
		{
			if (id == null)
				id = connection.GetNewId ();
			return id;
		}

		private ArrayOfLongPacked GetOptions ()
		{
			if (options == null)
			{
				options = new ArrayOfLongPacked (RpcMessageLayout.StatementOptionsLength);
				InitializeOptions ();
			}

			options[RpcMessageLayout.SO_Prefetch] = prefetchSize;
			if (connection.autocommit)
				options[RpcMessageLayout.SO_AutoCommit] = (int) CLI.AutoCommit.SQL_AUTOCOMMIT_ON;
			else
				options[RpcMessageLayout.SO_AutoCommit] = (int) CLI.AutoCommit.SQL_AUTOCOMMIT_OFF;
			options[RpcMessageLayout.SO_Isolation] = (int) connection.isolation;
			options[RpcMessageLayout.SO_RpcTimeout] = timeout * Values.MillisPerSec;
			if (uniqueRows)
				options[RpcMessageLayout.SO_UniqueRows] = 1;
			else
				options[RpcMessageLayout.SO_UniqueRows] = 0;

			return options;
		}

		private void InitializeOptions ()
		{
			Debug.Assert (options != null);

			if (concurrency == CommandConcurrency.CONCUR_PESSIMISTIC)
				options[RpcMessageLayout.SO_Concurrency] = (int)CLI.Concurrency.SQL_CONCUR_LOCK;
			else if (concurrency == CommandConcurrency.CONCUR_OPTIMISTIC)
				options[RpcMessageLayout.SO_Concurrency] = (int)CLI.Concurrency.SQL_CONCUR_VALUES;
			else
				options[RpcMessageLayout.SO_Concurrency] = (int)CLI.Concurrency.SQL_CONCUR_READ_ONLY;

			options[RpcMessageLayout.SO_IsAsync] = 0;
			options[RpcMessageLayout.SO_MaxRows] = 0;
			options[RpcMessageLayout.SO_Timeout] = 0;
			options[RpcMessageLayout.SO_Prefetch] = Values.SELECT_PREFETCH_QUOTA;
			//options[RpcMessageLayout.SO_AutoCommit] = (int) CLI.AutoCommit.SQL_AUTOCOMMIT_ON;
			//options[RpcMessageLayout.SO_RpcTimeout] = 0;
			options[RpcMessageLayout.SO_CursorType] = (int) CLI.CursorType.SQL_CURSOR_FORWARD_ONLY;
			options[RpcMessageLayout.SO_KeysetSize] = 0;
			options[RpcMessageLayout.SO_UseBookmarks] = 0;
			//options[RpcMessageLayout.SO_Isolation] = (int) CLI.IsolationLevel.SQL_TXN_READ_COMMITED;
			//options[RpcMessageLayout.SO_PrefetchBytes] = 0;
			//options[RpcMessageLayout.SO_UniqueRows] = 0;
		}

		private void SendRequest (Future future)
		{
			Debug.Assert (pendingFuture == null);

			pendingFuture = future;
			try
			{
				connection.futures.Add (future);
				future.SendRequest (connection.Session, timeout);
			}
			catch
			{
				connection.futures.Remove (future);
				pendingFuture = null;
				throw;
			}
		}

		private CLI.ReturnCode ProcessResult (bool needEvl)
		{
			Debug.WriteLineIf (CLI.FnTrace.Enabled, "ManagedCommand.ProcessResult (" + needEvl + ")");
			bool warningPending = false;
			for (;;)
			{
				lock (this) { isWaitedResult = true; }
				object result = pendingFuture.GetNextResult (connection.Session, connection.futures);
				lock(this) { isWaitedResult = false; }
				if (result is object[])
				{
					object[] results = (object[]) result;
					AnswerTag tag = (AnswerTag) results[0];
					Debug.WriteLineIf (Switch.Enabled, "QA: " + tag);
					switch (tag)
					{
					case AnswerTag.QA_LOGIN:
						connection.currentCatalog = (string) results[1];
						break;

					case AnswerTag.QA_COMPILED:
					{
						object[] compilation = (object[]) results[1];
						queryType = (QueryType) compilation[1];
						SetColumnMetaData (compilation[0], (int) compilation[4]);
						if (!needEvl)
							return (warningPending ? CLI.ReturnCode.SQL_SUCCESS_WITH_INFO : CLI.ReturnCode.SQL_SUCCESS);
						break;
					}

					case AnswerTag.QA_ROWS_AFFECTED:
						affectedRows += (int) results[1];
						isLastRow = true;
						if (queryType == QueryType.QT_PROC_CALL)
							return CLI.ReturnCode.SQL_NO_DATA;
						isLastResult = true;
						if (queryType == QueryType.QT_SELECT)
							return CLI.ReturnCode.SQL_NO_DATA;
						return (warningPending ? CLI.ReturnCode.SQL_SUCCESS_WITH_INFO : CLI.ReturnCode.SQL_SUCCESS);

					case AnswerTag.QA_ROW_LAST_IN_BATCH:
						isLastInBatch = true;
						goto case AnswerTag.QA_ROW;

					case AnswerTag.QA_ROW:
						prefetchRow = results;
						isLastRow = false;
						return (warningPending ? CLI.ReturnCode.SQL_SUCCESS_WITH_INFO : CLI.ReturnCode.SQL_SUCCESS);

					case AnswerTag.QA_PROC_RETURN:
						SetParameterValues (results);
						isLastResult = isLastRow = true;
						return (warningPending ? CLI.ReturnCode.SQL_SUCCESS_WITH_INFO : CLI.ReturnCode.SQL_SUCCESS);

					case AnswerTag.QA_NEED_DATA:
						needDataParameter = (int) results[1];
						return CLI.ReturnCode.SQL_NEED_DATA;

					case AnswerTag.QA_ERROR:
						isLastResult = isLastRow = true;
						errors.AddServerError ((string) results[1], null, (string) results[2]);
						return CLI.ReturnCode.SQL_ERROR;

					case AnswerTag.QA_WARNING:
                        			errors.AddServerWarning((string)results[1], null, (string)results[2]);
                        			warningPending = true;
                        			break;
					}
				}
				else
				{
					/*
					CLI.ReturnCode rc = (CLI.ReturnCode) result;
					if (rc == CLI.ReturnCode.SQL_NO_DATA)
						return rc;
					*/

					isLastRow = true;
					// proc call. Result set ends, proc not returned.
					if (queryType == QueryType.QT_PROC_CALL)
						return CLI.ReturnCode.SQL_NO_DATA;
					isLastResult = true;
					if (queryType == QueryType.QT_SELECT)
						return CLI.ReturnCode.SQL_NO_DATA;
					return CLI.ReturnCode.SQL_SUCCESS;
				}
			}
		}


		private void SetColumnMetaData (object compilationColumns, int hiddenColumns)
		{
		  Debug.WriteLineIf (CLI.FnTrace.Enabled, "ManagedCommand.SetColumnMetaData");
			object[] descriptions = null;
			if (compilationColumns is object[])
				descriptions = (object[]) compilationColumns;

			if (descriptions == null || descriptions.Length == 0)
			{
				columns = null;
				return;
			}

			bool hasKeyColumns = false;

			columns = new ColumnData[descriptions.Length];
			for (int i = 0; i < columns.Length; i++)
			{
				object[] description = (object[]) descriptions[i];

				ColumnData column = new ColumnData ();
				columns[i] = column;

				ColumnFlags flags = (ColumnFlags) description[11];

				column.columnName = (string) description[0];
				column.columnType = DataTypeInfo.MapDvType ((BoxTag) description[1]);
				if (0 != (flags & ColumnFlags.CDF_XMLTYPE))
				  {
				    Debug.WriteLineIf (SqlXml.Switch.TraceVerbose,
					String.Format ("Set XML type for {0}", column.columnName));
				    column.columnType = DataTypeInfo.Xml;
				  }
				if (column.columnType == null)
					throw new SystemException ("Unknown data type");
				column.bufferType = column.columnType.bufferType;

				column.columnSize = column.columnType.GetFieldSize ((int) description[3]);
				column.precision = (short) column.columnSize;
				column.scale = (short) ((int) description[2]);
				column.IsLong = column.columnType.isLong;
				column.IsNullable = (0 != (int) description[4]);

				CLI.Updatable updatable = (CLI.Updatable) (int) description[5];
				column.IsReadOnly = (updatable == CLI.Updatable.SQL_ATTR_READONLY);

				column.IsAutoIncrement = (0 != (flags & ColumnFlags.CDF_AUTOINCREMENT));
				column.IsKey = (0 != (flags & ColumnFlags.CDF_KEY));
				if (column.IsKey)
					hasKeyColumns = true;

				column.IsHidden = (i >= (columns.Length - hiddenColumns));
				column.IsRowVersion = (column.columnType == DataTypeInfo.Timestamp);
				// TODO: check for unique columns as well.
				column.IsUnique = false;

				column.baseCatalogName = (string) Values.NullIfZero (description[7]);
				column.baseColumnName = (string) Values.NullIfZero (description[8]);
				column.baseSchemaName = (string) Values.NullIfZero (description[9]);
				column.baseTableName = (string) Values.NullIfZero (description[10]);

				if (column.baseTableName == null || column.baseTableName == "")
					column.IsExpression = true;
				else
					column.IsExpression = false;
			}

			if (uniqueRows && !hasKeyColumns)
				uniqueRows = false;
		}

		private void SetParameterValues (object[] results)
		{
			if (parameters == null || parameters.Count == 0)
				return;

			for (int i = 0; i < parameters.Count && (i + 2) < results.Length; i++)
			{
				if (parameters[i].Direction == ParameterDirection.ReturnValue
					|| parameters[i].Direction == ParameterDirection.Output
					|| parameters[i].Direction == ParameterDirection.InputOutput)
					parameterValues[i] = results[i + 2];
			}
		}

		private void Dispose (bool disposing)
		{
			// TODO: Review command disposing
			/*
			if (disposing)
			{
				CloseCursor ();
			}
			*/
			if (connection.futures != null)
			{
				Future future = new Future(Service.FreeStmt, GetId(), (int)CLI.FreeStmtOption.SQL_DROP);
				try
				{
					connection.futures.Add(future);
					future.SendRequest(connection.Session);
					future.GetResult(connection.Session, connection.futures);
				}
				finally
				{
					connection.futures.Remove(future);
				}
			}
		}
	}
}

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
	internal sealed class CLI
	{
		private CLI() {}

#if UNMANAGED_ODBC
#if !USE_DRIVER_MANAGER
		private const string ODBC_DLL = "virtodbc45.dll";
#else
		private const string ODBC_DLL = "odbc32.dll";
#endif
#endif

		internal enum ReturnCode
		{
			SQL_SUCCESS = 0,
			SQL_SUCCESS_WITH_INFO = 1,
			SQL_STILL_EXECUTING = 2,
			SQL_NEED_DATA = 99,
			SQL_NO_DATA = 100,
			SQL_ERROR = -1,
			SQL_INVALID_HANDLE = -2
		};

        internal enum IdentCase 

        {
            SQL_IC_UPPER = 1,
            SQL_IC_LOWER = 2,
            SQL_IC_SENSITIVE = 3,
            SQL_IC_MIXED = 4,
        }

		internal enum IsolationLevel
		{
			SQL_TXN_READ_UNCOMMITTED = 1,
			SQL_TXN_READ_COMMITED = 2,
			SQL_TXN_REPEATABLE_READ = 4,
			SQL_TXN_SERIALIZABLE = 8,
			SQL_TXN_VERSIONING = 16
		};

		private const int SQL_SIGNED_OFFSET = -20;
		private const int SQL_UNSIGNED_OFFSET = -22;

		internal enum SqlCType
		{
			SQL_C_DEFAULT = 99,
			SQL_C_CHAR = SqlType.SQL_CHAR,
			SQL_C_BIGINT = SqlType.SQL_BIGINT,
			SQL_C_LONG = SqlType.SQL_INTEGER,
			SQL_C_SHORT = SqlType.SQL_SMALLINT,
			SQL_C_FLOAT = SqlType.SQL_REAL,
			SQL_C_DOUBLE = SqlType.SQL_DOUBLE,
			SQL_C_NUMERIC = SqlType.SQL_NUMERIC,
			SQL_C_DATE = SqlType.SQL_DATE,
			SQL_C_TIME = SqlType.SQL_TIME,
			SQL_C_TIMESTAMP = SqlType.SQL_TIMESTAMP,
			SQL_C_TYPE_DATE = SqlType.SQL_TYPE_DATE,
			SQL_C_TYPE_TIME = SqlType.SQL_TYPE_TIME,
			SQL_C_TYPE_TIMESTAMP = SqlType.SQL_TYPE_TIMESTAMP,
			SQL_C_BINARY = SqlType.SQL_BINARY,
			SQL_C_TINYINT = SqlType.SQL_TINYINT,
			SQL_C_BIT = SqlType.SQL_BIT,
			SQL_C_WCHAR = SqlType.SQL_WCHAR,
			SQL_C_GUID = SqlType.SQL_GUID,
			SQL_C_SBIGINT = SqlType.SQL_BIGINT + SQL_SIGNED_OFFSET,
			SQL_C_UBIGINT = SqlType.SQL_BIGINT + SQL_UNSIGNED_OFFSET,
			SQL_C_SLONG = SQL_C_LONG + SQL_SIGNED_OFFSET,
			SQL_C_ULONG = SQL_C_LONG + SQL_UNSIGNED_OFFSET,
			SQL_C_SSHORT = SQL_C_SHORT + SQL_SIGNED_OFFSET,
			SQL_C_USHORT = SQL_C_SHORT + SQL_UNSIGNED_OFFSET,
			SQL_C_STINYINT = SqlType.SQL_TINYINT + SQL_SIGNED_OFFSET,
			SQL_C_UTINYINT = SqlType.SQL_TINYINT + SQL_UNSIGNED_OFFSET,
			SQL_C_BOOKMARK = SQL_C_ULONG,
			SQL_C_VARBOOKMARK = SQL_C_BINARY,
		};

		internal enum SqlType
		{
			SQL_UNKNOWN_TYPE = -1,
			SQL_ALL_TYPES = 0,
			SQL_CHAR = 1,
			SQL_NUMERIC = 2,
			SQL_DECIMAL = 3,
			SQL_INTEGER = 4,
			SQL_SMALLINT = 5,
			SQL_FLOAT = 6,
			SQL_REAL = 7,
			SQL_DOUBLE = 8,
			//SQL_DATETIME = 9,
			SQL_DATE = 9,
			//SQL_INTERVAL = 10,
			SQL_TIME = 10,
			SQL_TIMESTAMP = 11,
			SQL_VARCHAR = 12,
			SQL_TYPE_DATE = 91,
			SQL_TYPE_TIME = 92,
			SQL_TYPE_TIMESTAMP = 93,
			SQL_LONGVARCHAR = -1,
			SQL_BINARY = -2,
			SQL_VARBINARY = -3,
			SQL_LONGVARBINARY = -4,
			SQL_BIGINT = -5,
			SQL_TINYINT = -6,
			SQL_BIT = -7,
			SQL_WCHAR = -8,
			SQL_WVARCHAR = -9,
			SQL_WLONGVARCHAR = -10,
			SQL_GUID = -11,
		};

        internal enum GroupBy
        {
            SQL_GB_NOT_SUPPORTED = 0,
            SQL_GB_GROUP_BY_EQUALS_SELECT = 1,
            SQL_GB_GROUP_BY_CONTAINS_SELECT = 2,
            SQL_GB_NO_RELATION = 3,
            SQL_GB_COLLATE = 4
        };

        [Flags]
        internal enum OuterJoin
        {
            SQL_OJ_LEFT =               0x00000001,
            SQL_OJ_RIGHT =              0x00000002,
            SQL_OJ_FULL =               0x00000004,
            SQL_OJ_NESTED =             0x00000008,
            SQL_OJ_NOT_ORDERED =        0x00000010,
            SQL_OJ_INNER =              0x00000020,
            SQL_OJ_ALL_COMPARISON_OPS = 0x00000040
        };

		internal enum Nullable
		{
			SQL_NO_NULLS = 0,
			SQL_NULLABLE = 1,
			SQL_NULLABLE_UNKNOWN = 2
		};

        internal enum ProcedureType
        {
            SQL_PT_UNKNOWN = 0,
            SQL_PT_PROCEDURE = 1,
            SQL_PT_FUNCTION = 2
        };

        internal enum IdentifierType
        {
            SQL_BEST_ROWID = 1,
            SQL_ROWVER = 2
        };

        internal enum Scope
        {
            SQL_SCOPE_CURROW = 0,
            SQL_SCOPE_TRANSACTION = 1,
            SQL_SCOPE_SESSION = 2
        };

		internal enum CompletionType
		{
			SQL_COMMIT = 0,
			SQL_ROLLBACK = 1
		};

		internal enum InOutType
		{
			SQL_PARAM_TYPE_UNKNOWN = 0,
			SQL_PARAM_INPUT = 1,
			SQL_PARAM_INPUT_OUTPUT = 2,
			SQL_RESULT_COL = 3,
			SQL_PARAM_OUTPUT = 4,
			SQL_PARAM_RETURN_VALUE = 5
		};

        internal enum IndexType
        {
            SQL_INDEX_UNIQUE = 0,
            SQL_INDEX_ALL = 1
        };

		internal enum Concurrency
		{
			SQL_CONCUR_READ_ONLY = 1,
			SQL_CONCUR_LOCK = 2,
			SQL_CONCUR_ROWVER = 3,
			SQL_CONCUR_VALUES = 4,
		};

		internal enum CursorType
		{
			SQL_CURSOR_FORWARD_ONLY = 0,
			SQL_CURSOR_KEYSET_DRIVEN = 1,
			SQL_CURSOR_DYNAMIC = 2,
			SQL_CURSOR_STATIC = 3,
		};

		internal enum AutoCommit
		{
			SQL_AUTOCOMMIT_OFF = 0,
			SQL_AUTOCOMMIT_ON = 1
		};

		internal enum Updatable
		{
			SQL_ATTR_READONLY = 0,
			SQL_ATTR_WRITE = 1,
			SQL_ATTR_WRITE_UNKNOWN = 2,
		}

		internal enum FreeStmtOption
		{
			SQL_CLOSE = 0,
			SQL_DROP = 1,
			SQL_UNBIND = 2,
			SQL_RESET_PARAMS = 3
		};




#if UNMANAGED_ODBC
		internal enum HandleType
		{
			SQL_HANDLE_ENV = 1,
			SQL_HANDLE_DBC = 2,
			SQL_HANDLE_STMT = 3,
			SQL_HANDLE_DESC = 4
		};

		internal enum DriverCompletion
		{
			SQL_DRIVER_NOPROMPT = 0,
			SQL_DRIVER_COMPLETE = 1,
			SQL_DRIVER_PROMPT = 2,
			SQL_DRIVER_COMPLETE_REQUIRED = 3
		};

		internal enum EnvironmentAttribute
		{
			SQL_ATTR_ODBC_VERSION = 200,
			SQL_ATTR_CONNECTION_POOLING = 201,
			SQL_ATTR_CP_MATCH = 202,
			SQL_ATTR_OUTPUT_NTS = 10001,
		};

		internal enum ConnectionAttribute
		{
			SQL_ATTR_ACCESS_MODE = 101,
			SQL_ATTR_AUTOCOMMIT = 102,
			SQL_ATTR_LOGIN_TIMEOUT = 103,
			SQL_ATTR_TRACE = 104,
			SQL_ATTR_TRACEFILE = 105,
			SQL_ATTR_TRANSLATE_LIB = 106,
			SQL_ATTR_TRANSLATE_OPTION = 107,
			SQL_ATTR_TXN_ISOLATION = 108,
			SQL_ATTR_CURRENT_CATALOG = 109,
			SQL_ATTR_ODBC_CURSORS = 110,
			SQL_ATTR_QUIET_MODE = 111,
			SQL_ATTR_PACKET_SIZE = 112,
			SQL_ATTR_CONNECTION_TIMEOUT = 113,
			SQL_ATTR_DISCONNECT_BEHAVIOR = 114,
			SQL_ATTR_ENLIST_IN_DTC = 1207,
			SQL_ATTR_ENLIST_IN_XA = 1208,
			SQL_ATTR_CONNECTION_DEAD = 1209,
			SQL_ATTR_AUTO_IPD = 10001,
			SQL_ATTR_METADATA_ID = 10014,
		};

		internal enum StatementAttribute
		{
			SQL_ATTR_APP_PARAM_DESC = 10011,
			SQL_ATTR_APP_ROW_DESC = 10010,
			SQL_ATTR_ASYNC_ENBALE = 4,
			SQL_ATTR_CONCURRENCY = 7,
			SQL_ATTR_CURSOR_SCROLLABLE = -1,
			SQL_ATTR_CURSOR_SENSITIVITY = -2,
			SQL_ATTR_CURSOR_TYPE = 6,
			SQL_ATTR_ENABLE_AUTO_IPD = 15,
			SQL_ATTR_FETCH_BOOKMARK_PTR = 16,
			SQL_ATTR_IMP_PARAM_DESC = 10013,
			SQL_ATTR_IMP_ROW_DESC = 10012,
			SQL_ATTR_KEYSET_SIZE = 8,
			SQL_ATTR_MAX_LENGTH = 3,
			SQL_ATTR_MAX_ROWS = 1,
			SQL_ATTR_METADATA_ID = 10014,
			SQL_ATTR_NOSCAN = 2,
			SQL_ATTR_PARAM_BIND_OFFSET_PTR = 17,
			SQL_ATTR_PARAM_BIND_TYPE = 18,
			SQL_ATTR_PARAM_OPERATION_PTR = 19,
			SQL_ATTR_PARAM_STATUS_PTR = 20,
			SQL_ATTR_PARAMS_PROCESSED_PTR = 21,
			SQL_ATTR_PARAMSET_SIZE = 22,
			SQL_ATTR_QUERY_TIMEOUT = 0,
			SQL_ATTR_RETRIEVE_DATA = 11,
			SQL_ATTR_ROW_ARRAY_SIZE = 27,
			SQL_ATTR_ROW_BIND_OFFSET_PTR = 23,
			SQL_ATTR_ROW_BIND_TYPE = 5,
			SQL_ATTR_ROW_NUMBER = 14,
			SQL_ATTR_ROW_OPERATION_PTR = 24,
			SQL_ATTR_ROW_STATUS_PTR = 25,
			SQL_ATTR_ROWS_FETCHED_PTR = 26,
			SQL_ATTR_SIMULATE_CURSOR = 10,
			SQL_ATTR_USE_BOOKMARKS = 12,
			SQL_UNIQUE_ROWS = 5009,
		};

		internal enum ColumnAttribute
		{
			SQL_COLUMN_COUNT = 0,
			SQL_COLUMN_NAME = 1,
			SQL_COLUMN_TYPE = 2,
			SQL_COLUMN_LENGTH = 3,
			SQL_COLUMN_PRECISION = 4,
			SQL_COLUMN_SCALE = 5,
			SQL_COLUMN_DISPLAY_SIZE = 6,
			SQL_COLUMN_NULLABLE = 7,
			SQL_COLUMN_UNSIGNED = 8,
			SQL_COLUMN_MONEY = 9,
			SQL_COLUMN_UPDATABLE = 10,
			SQL_COLUMN_AUTO_INCREMENT = 11,
			SQL_COLUMN_CASE_SENSITIVE = 12,
			SQL_COLUMN_SEARCHABLE = 13,
			SQL_COLUMN_TYPE_NAME = 14,
			SQL_COLUMN_TABLE_NAME = 15,
			SQL_COLUMN_OWNER_NAME = 16,
			SQL_COLUMN_QUALIFIER_NAME = 17,
			SQL_COLUMN_LABEL = 18,
			SQL_COLUMN_HIDDEN = 5007,
			SQL_COLUMN_KEY = 5008,
		};

		internal enum DescriptorField
		{
			SQL_DESC_ARRAY_SIZE = 20,
			SQL_DESC_ARRAY_STATUS_PTR = 21,
			SQL_DESC_AUTO_UNIQUE_VALUE = ColumnAttribute.SQL_COLUMN_AUTO_INCREMENT,
			SQL_DESC_BASE_COLUMN_NAME = 22,
			SQL_DESC_BASE_TABLE_NAME = 23,
			SQL_DESC_BIND_OFFSET_PTR = 24,
			SQL_DESC_BIND_TYPE = 25,
			SQL_DESC_CASE_SENSITIVE = ColumnAttribute.SQL_COLUMN_CASE_SENSITIVE,
			SQL_DESC_CATALOG_NAME = ColumnAttribute.SQL_COLUMN_QUALIFIER_NAME,
			SQL_DESC_CONCISE_TYPE = ColumnAttribute.SQL_COLUMN_TYPE,
			SQL_DESC_DATETIME_INTERVAL_PRECISION = 26,
			SQL_DESC_DISPLAY_SIZE = 26,
			SQL_DESC_FIXED_PREC_SCALE = ColumnAttribute.SQL_COLUMN_MONEY,
			SQL_DESC_LABEL = ColumnAttribute.SQL_COLUMN_LABEL,
			SQL_DESC_LITERAL_PREFIX = 27,
			SQL_DESC_LITERAL_SUFFIX = 28,
			SQL_DESC_LOCAL_TYPE_NAME = 29,
			SQL_DESC_MAXIMUM_SCALE = 30,
			SQL_DESC_MINIMIM_SCALE = 31,
			SQL_DESC_NUM_PREC_RADIX = 32,
			SQL_DESC_PARAMETER_TYPE = 33,
			SQL_DESC_ROWS_PROCESSED_PTR = 34,
			SQL_DESC_ROWVER = 35,
			SQL_DESC_SCHEMA_NAME = ColumnAttribute.SQL_COLUMN_OWNER_NAME,
			SQL_DESC_SEARCHABLE = ColumnAttribute.SQL_COLUMN_SEARCHABLE,
			SQL_DESC_TYPE_NAME = ColumnAttribute.SQL_COLUMN_TYPE_NAME,
			SQL_DESC_TABLE_NAME = ColumnAttribute.SQL_COLUMN_TABLE_NAME,
			SQL_DESC_UNSIGNED = ColumnAttribute.SQL_COLUMN_UNSIGNED,
			SQL_DESC_UPDATABLE = ColumnAttribute.SQL_COLUMN_UPDATABLE,
			SQL_DESC_COUNT = 1001,
			SQL_DESC_TYPE = 1002,
			SQL_DESC_LENGTH = 1003,
			SQL_DESC_OCTET_LENGTH_PTR = 1004,
			SQL_DESC_PRECISION = 1005,
			SQL_DESC_SCALE = 1006,
			SQL_DESC_DATETIME_INTERVAL_CODE = 1007,
			SQL_DESC_NULLABLE = 1008,
			SQL_DESC_INDICATOR_PTR = 1009,
			SQL_DESC_DATA_PTR = 1010,
			SQL_DESC_NAME = 1011,
			SQL_DESC_UNNAMED = 1012,
			SQL_DESC_OCTET_LENGTH = 1013,
			SQL_DESC_ALLOC_TYPE = 1099,
		};

		internal enum OdbcVersion
		{
			SQL_OV_ODBC2 = 2,
			SQL_OV_ODBC3 = 3,
		}

		internal enum ConnectionPooling
		{
			SQL_CP_OFF = 0,
			SQL_CP_ONE_PER_DRIVER = 1,
			SQL_CP_ONE_PER_HENV = 2
		};

		internal enum ConnectionPoolingMatch
		{
			SQL_CP_STRICT_MATCH = 0,
			SQL_CP_RELAXED_MATCH = 1
		};

		internal enum AccessMode
		{
			SQL_MODE_READ_WRITE = 0,
			SQL_MODE_READ_ONLY = 1,
		};

		internal enum LengthCode
		{
			SQL_NULL_DATA = -1,
			SQL_DATA_AT_EXEC = -2,
			SQL_NTS = -3,
			SQL_NO_TOTAL = -4,
			SQL_DEFAULT_PARAM = -5,
			SQL_IGNORE = -6,
			SQL_COLUMN_IGNORE = SQL_IGNORE,

			SQL_IS_POINTER = -4,
			SQL_IS_UINTEGER = -5,
			SQL_IS_INTEGER = -6,
			SQL_IS_USMALLINT = -7,
			SQL_IS_SMALLINT = -8,
		};

		internal enum SetPosOp
		{
			SQL_POSITION = 0,
			SQL_REFRESH = 1,
			SQL_UPDATE = 2,
			SQL_DELETE = 3,
		}

		internal enum LockOption
		{
			SQL_LOCK_NO_CHANGE = 0,
			SQL_LOCK_EXCLUSIVE = 1,
			SQL_LOCK_UNLOCK = 2,
		}

		internal enum FetchOrientation
		{
			SQL_FETCH_NEXT = 1,
			SQL_FETCH_FIRST = 2,
			SQL_FETCH_LAST = 3,
			SQL_FETCH_PRIOR = 4,
			SQL_FETCH_ABSOLUTE = 5,
			SQL_FETCH_RELATIVE = 6,
		}

        internal enum Searchable
        {
            SQL_PRED_NONE = 0,
            SQL_PRED_CHAR = 1,
            SQL_PRED_BASIC = 2,
            SQL_PRED_SEARCHABLE = 3
        };

		internal static readonly IntPtr SQL_NULL_HANDLE = new IntPtr(0);

		internal const int SQL_SQLSTATE_SIZE = 5;
		internal const int SQL_MAX_NUMERIC_LEN = 16;
		internal const int SQL_MAX_MESSAGE_LEN = 512;
		internal const int SQL_MAX_CONNECTION_STRING_LEN = 1024;
		internal const int SQL_MAX_COLUMN_NAME_LEN = 127;

		[DllImport (ODBC_DLL)]
		internal static extern short SQLAllocHandle(short handleType, IntPtr inputHandle, out IntPtr outputHandle);

		[DllImport (ODBC_DLL)]
		internal static extern short SQLBindCol(IntPtr statementHandle,
			ushort columnNumber, short targetType, IntPtr targetValuePtr, IntPtr bufferLength,
			IntPtr strLenOrIndPtr);

		[DllImport (ODBC_DLL)]
		internal static extern short SQLBindParameter(IntPtr statementHandle,
			ushort parameterNumber, short inputOutputType, short valueType, short parameterType,
			IntPtr columnSize, short decimalDigits, IntPtr parameterValuePtr,
			IntPtr bufferLength, IntPtr strLenOrIndPtr);

		[DllImport (ODBC_DLL)]
		internal static extern short SQLCancel(IntPtr statementHandle);

#if USE_DRIVER_MANAGER
		[DllImport (ODBC_DLL)]
		internal static extern short SQLCloseCursor(IntPtr statementHandle);
#endif

		[DllImport (ODBC_DLL, CharSet=CharSet.Unicode, EntryPoint="SQLColAttributeW")]
		internal static extern short SQLColAttribute(IntPtr statementHandle,
			ushort columnNumber, ushort fieldIdentifier, IntPtr characterAttributePtr,
			short bufferLength, out short stringLength, out IntPtr numericAttribute);

		[DllImport (ODBC_DLL, CharSet=CharSet.Unicode, EntryPoint="SQLDescribeColW")]
		internal static extern short SQLDescribeCol(IntPtr statementHandle,
			ushort columnNumber, IntPtr columnName, short bufferLength, out short nameLength,
			out short dataType, out uint columnSize, out short decimalDigits, out short nullable);

		[DllImport (ODBC_DLL)]
		internal static extern short SQLDisconnect(IntPtr connectionHandle);

#if !WIDE_CHAR_CONNECT
// As of Jan 27 2003 SQLDriverConnectW is missing in virtodbc.dll
#if WIN32_ONLY
		[DllImport (ODBC_DLL, CharSet=CharSet.Ansi, EntryPoint="SQLDriverConnect")]
		internal static extern short SQLDriverConnect(IntPtr connectionHandle, IntPtr windowHandle,
			[MarshalAs(UnmanagedType.LPStr)] string inConnectionString, short inStringLength,
			IntPtr outConnectionString, short bufferLength, out short outStringLength,
			short driverCompletion);
#else
		[DllImport (ODBC_DLL, CharSet=CharSet.Ansi, EntryPoint="SQLDriverConnect")]
		internal static extern short SQLDriverConnect(IntPtr connectionHandle, IntPtr windowHandle,
			string inConnectionString, short inStringLength,
			IntPtr outConnectionString, short bufferLength, out short outStringLength,
			short driverCompletion);
#endif
#else
#if WIN32_ONLY
		[DllImport (ODBC_DLL, CharSet=CharSet.Unicode)]
		internal static extern short SQLDriverConnect(IntPtr connectionHandle, IntPtr windowHandle,
			[MarshalAs(UnmanagedType.LPWStr)] string inConnectionString, short inStringLength,
			IntPtr outConnectionString, short bufferLength, out short outStringLength,
			short driverCompletion);
#else
		[DllImport (ODBC_DLL, CharSet=CharSet.Unicode, EntryPoint="SQLDriverConnectW")]
		internal static extern short SQLDriverConnect(IntPtr connectionHandle, IntPtr windowHandle,
			IntPtr inConnectionString, short inStringLength,
			IntPtr outConnectionString, short bufferLength, out short outStringLength,
			short driverCompletion);
#endif
#endif

		[DllImport (ODBC_DLL)]
		internal static extern short SQLEndTran(short handleType, IntPtr handle, short completionType);

#if WIN32_ONLY
		[DllImport (ODBC_DLL, CharSet=CharSet.Unicode)]
		internal static extern short SQLExecDirect(IntPtr statementHandle,
			[MarshalAs(UnmanagedType.LPWStr)] string statementText, int textLength);
#else
		[DllImport (ODBC_DLL, CharSet=CharSet.Unicode, EntryPoint="SQLExecDirectW")]
		internal static extern short SQLExecDirect(IntPtr statementHandle,
			IntPtr statementText, int textLength);
#endif

		[DllImport (ODBC_DLL)]
		internal static extern short SQLExecute(IntPtr statementHandle);

		[DllImport (ODBC_DLL)]
		internal static extern short SQLFetch(IntPtr statementHandle);

		[DllImport (ODBC_DLL)]
		internal static extern short SQLFetchScroll(IntPtr statementHandle, short fetchOrientation, IntPtr offset);

		[DllImport (ODBC_DLL)]
		internal static extern short SQLFreeHandle(short handleType, IntPtr handle);

		[DllImport (ODBC_DLL)]
		internal static extern short SQLFreeStmt(IntPtr statementHandle, ushort option);

		[DllImport (ODBC_DLL, CharSet=CharSet.Unicode, EntryPoint="SQLGetConnectAttrW")]
		internal static extern short SQLGetConnectAttr(IntPtr connectionHandle,
			int attribute, IntPtr ValuePtr, int bufferLength, out int stringLength);

		[DllImport (ODBC_DLL)]
		internal static extern short SQLGetData(IntPtr statementHandle,
			ushort columnNumber, short targetType, IntPtr targetValuePtr, IntPtr bufferLength,
			out IntPtr strLenOrInd);

		[DllImport (ODBC_DLL, CharSet=CharSet.Unicode, EntryPoint="SQLGetDescFieldW")]
		internal static extern short SQLGetDescField(IntPtr descriptorHandle,
			short recNumber, short fieldIdentifier, IntPtr valuePtr, int bufferLength, out int stringLength);

#if false
		[DllImport (ODBC_DLL, CharSet=CharSet.Unicode)]
		internal static extern short SQLGetDiagRec(short handleType,
			IntPtr handle, short recNumber,	IntPtr sqlState, out int nativeError,
			IntPtr messageText, short bufferLength, out short textLength);
#else
		[DllImport (ODBC_DLL, CharSet=CharSet.Ansi)]
		internal static extern short SQLGetDiagRec(short handleType,
			IntPtr handle, short recNumber,	IntPtr sqlState, out int nativeError,
			IntPtr messageText, short bufferLength, out short textLength);
#endif

		[DllImport (ODBC_DLL, CharSet=CharSet.Unicode, EntryPoint="SQLGetStmtAttrW")]
		internal static extern short SQLGetStmtAttr(IntPtr connectionHandle,
			int attribute, IntPtr ValuePtr, int bufferLength, out int stringLength);

		[DllImport (ODBC_DLL)]
		internal static extern short SQLMoreResults(IntPtr statementHandle);

		[DllImport (ODBC_DLL)]
		internal static extern short SQLNumParams(IntPtr statementHandle, out short parameterCount);

		[DllImport (ODBC_DLL)]
		internal static extern short SQLNumResultCols(IntPtr statementHandle, out short columnCount);

		[DllImport (ODBC_DLL)]
		internal static extern short SQLParamData(IntPtr statementHandle, out IntPtr value);

#if WIN32_ONLY
		[DllImport (ODBC_DLL, CharSet=CharSet.Unicode)]
		internal static extern short SQLPrepare(IntPtr statementHandle,
			[MarshalAs(UnmanagedType.LPWStr)] string statementText, int textLength);
#else
		[DllImport (ODBC_DLL, CharSet=CharSet.Unicode, EntryPoint="SQLPrepareW")]
		internal static extern short SQLPrepare(IntPtr statementHandle,
			IntPtr statementText, int textLength);
#endif

#if WIN32_ONLY
		[DllImport (ODBC_DLL, CharSet=CharSet.Unicode)]
		internal static extern short SQLProcedureColumns(IntPtr statementHandle,
			[MarshalAs(UnmanagedType.LPWStr)] string catalogName, short nameLength1,
			[MarshalAs(UnmanagedType.LPWStr)] string schemaName, short nameLength2,
			[MarshalAs(UnmanagedType.LPWStr)] string procName, short nameLength3,
			[MarshalAs(UnmanagedType.LPWStr)] string columnName, short nameLength4);
#else
		[DllImport (ODBC_DLL, CharSet=CharSet.Unicode, EntryPoint="SQLProcedureColumnsW")]
		internal static extern short SQLProcedureColumns(IntPtr statementHandle,
			IntPtr catalogName, short nameLength1,
			IntPtr schemaName, short nameLength2,
			IntPtr procName, short nameLength3,
			IntPtr columnName, short nameLength4);
#endif

		[DllImport (ODBC_DLL)]
		internal static extern short SQLPutData(IntPtr statementHandle, IntPtr dataPtr, IntPtr strLenOrInd);

		[DllImport (ODBC_DLL)]
		internal static extern short SQLRowCount(IntPtr statementHandle, out IntPtr rowCount);

		[DllImport (ODBC_DLL, CharSet=CharSet.Unicode, EntryPoint="SQLSetConnectAttrW")]
		internal static extern short SQLSetConnectAttr(IntPtr connectionHandle,
			int attribute, IntPtr ValuePtr, int stringLength);

		[DllImport (ODBC_DLL)]
		internal static extern short SQLSetEnvAttr(IntPtr environmentHandle,
			int attribute, IntPtr ValuePtr, int stringLength);

		[DllImport (ODBC_DLL)]
		internal static extern short SQLSetPos (IntPtr statementHandle,
			ushort rowNumber, ushort operation, ushort lockType);

		[DllImport (ODBC_DLL, CharSet=CharSet.Unicode, EntryPoint="SQLSetStmtAttrW")]
		internal static extern short SQLSetStmtAttr(IntPtr statementHandle,
			int attribute, IntPtr ValuePtr, int stringLength);

#endif
#region Trace switches
		internal static BooleanSwitch FnTrace = new BooleanSwitch("VirtuosoClient.FnTrace", "Function trace");
#endregion
	}
}

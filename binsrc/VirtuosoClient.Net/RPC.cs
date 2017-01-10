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

#if ODBC_CLIENT
namespace OpenLink.Data.VirtuosoOdbcClient
#elif CLIENT
namespace OpenLink.Data.VirtuosoClient
#else
namespace OpenLink.Data.Virtuoso
#endif
{
	internal enum BoxTag
	{
		DV_NULL = 180,
		DV_SHORT_STRING_SERIAL = 181,
		DV_BIN = 222,
		DV_STRICT_STRING = 238,
		DV_STRING = 182,
		DV_SHORT_STRING = DV_STRING,
		DV_LONG_STRING = DV_STRING,
		DV_LONG_BIN = 223,
		DV_WIDE = 225,
		DV_LONG_WIDE = 226,
		DV_C_STRING = 183,
		DV_C_SHORT = 184,
		DV_STRING_SESSION = 185,
		DV_SHORT_CONT_STRING = 186,
		DV_LONG_CONT_STRING = 187,
		DV_SHORT_INT = 188,
		DV_LONG_INT = 189,
		DV_SINGLE_FLOAT = 190,
		DV_DOUBLE_FLOAT = 191,
		DV_CHARACTER = 192,
		DV_NUMERIC = 219,
		DV_ARRAY_OF_POINTER = 193,
		DV_ARRAY_OF_LONG_PACKED = 194,
		DV_ARRAY_OF_FLOAT = 202,
		DV_ARRAY_OF_DOUBLE = 195,
		DV_ARRAY_OF_LONG = 209,
		DV_LIST_OF_POINTER = 196,
		DV_OBJECT_AND_CLASS = 197,
		DV_OBJECT_REFERENCE = 198,
		DV_DELETED = 199,
		DV_OBJECT = 254,
		DV_MEMBER_POINTER = 200,
		DV_C_INT = 201,
		DV_CUSTOM = 203,
		DV_DB_NULL = 204,
		DV_G_REF_CLASS = 205,
		DV_G_REF = 206,
		DV_BOX_FLAGS = 207,
		DV_BLOB = 125,
		DV_BLOB_HANDLE = 126,
		DV_BLOB_WIDE_HANDLE = 133,
		DV_BLOB_BIN = 131,
		DV_BLOB_WIDE = 132,
		DV_BLOB_XPER = 134,
		DV_SYMBOL = 127,
		DV_TIMESTAMP = 128,
		DV_DATE = 129,
		DV_TIMESTAMP_OBJ = 208,
		DV_TIME = 210,
		DV_DATETIME = 211,
		DV_IRI_ID   = 243,
		DV_IRI_ID_8 = 244,
		DV_INT64    = 247,
		DV_RDF	= 246,
		DV_ANY	= 242,
                
	}

	internal enum RpcTag
	{
		DA_FUTURE_REQUEST = 1,
		DA_FUTURE_ANSWER = 2,
		DA_FUTURE_PARTIAL_ANSWER = 3,
		DA_DIRECT_IO_FUTURE_REQUEST = 4,
		DA_CALLER_IDENTIFICATION = 5,
	}

	internal class RpcMessageLayout
	{
		private RpcMessageLayout () {}

		internal const int DA_MESSAGE_TYPE = 0;

		// future request
		internal const int DA_FRQ_LENGTH = 5;
		internal const int FRQ_COND_NUMBER = 1;
		internal const int FRQ_ANCESTRY = 2;
		internal const int FRQ_SERVICE_NAME = 3;
		internal const int FRQ_ARGUMENTS = 4;

		// future answer
		internal const int DA_ANSWER_LENGTH = 4;
		internal const int RRC_COND_NUMBER = 1;
		internal const int RRC_VALUE = 2;
		internal const int RRC_ERROR = 3;

		// statement options
		internal const int StatementOptionsLength = 13;
		internal const int SO_Concurrency = 0;
		internal const int SO_IsAsync = 1;
		internal const int SO_MaxRows = 2;
		internal const int SO_Timeout = 3;
		internal const int SO_Prefetch = 4;
		internal const int SO_AutoCommit = 5;
		internal const int SO_RpcTimeout = 6;
		internal const int SO_CursorType = 7;
		internal const int SO_KeysetSize = 8;
		internal const int SO_UseBookmarks = 9;
		internal const int SO_Isolation = 10;
		internal const int SO_PrefetchBytes = 11;
		internal const int SO_UniqueRows = 12;
	}

	internal enum AnswerTag
	{
		QA_ROW = 1,
		QA_ERROR = 3,
		QA_COMPILED = 4,
		QA_NEED_DATA = 5,
		QA_PROC_RETURN = 6,
		QA_ROWS_AFFECTED = 7,
		QA_BLOB_POS = 8,
		QA_LOGIN = 9,
		QA_ROW_ADDED = 10,
		QA_ROW_UPDATED = 11,
		QA_ROW_DELETED = 12,
		QA_ROW_LAST_IN_BATCH = 13,
		QA_WARNING = 14,
	}

	internal enum QueryType
	{
		QT_UNKNOWN = -1,
		QT_UPDATE = 0,
		QT_SELECT = 1,
		QT_PROC_CALL = 2,
	}

	internal enum ColumnFlags
	{
		CDF_KEY = 1,
		CDF_AUTOINCREMENT = 2,
		CDF_XMLTYPE = 4
	}

	internal enum NumericFlags
	{
		NDF_INF = 0x10,
		NDF_NAN = 0x08,
		NDF_LEAD0 = 0x04,
		NDF_TRAIL0 = 0x02,
		NDF_NEG = 0x01,
	}

	internal enum DateTimeType
	{
		DT_TYPE_DATETIME = 1,
		DT_TYPE_DATE = 2,
		DT_TYPE_TIME = 3,
	}

	internal enum DtpFlags
	{
		SQL_TP_UNENLIST = 0x00f0,
		SQL_TP_PREPARE = 0x00f1,
		SQL_TP_COMMIT = 0x00f2,
		SQL_TP_ABORT = 0x00f3,
		SQL_TP_ENLIST = 0x00f4,

		SQL_XA_UNENLIST = 0x0f00,
		SQL_XA_WAIT = 0x0f00,
		SQL_XA_PREPARE = 0x0f01,
		SQL_XA_COMMIT = 0x0f02,
		SQL_XA_ROLLBACK = 0x0f03,
		SQL_XA_ENLIST_END = 0x0f04,
		SQL_XA_JOIN = 0x0f05,
		SQL_XA_ENLIST = 0x0f06,
	}

	internal class Values
	{
		private Values () {}

		/// <summary>
		/// The version string.
		/// </summary>
		internal const string VERSION = "05.51.3032";

		internal const string DEFAULT_HOST = "localhost";
		internal const int DEFAULT_PORT = 1111;
		internal const int DEFAULT_ENCRYPTED_PORT = 2111;

		internal const int SELECT_PREFETCH_QUOTA = 20;

		// The Gregorian Reformation date
		internal const int GREG_YEAR = 1582;
		internal const int GREG_MONTH = 10;
		internal const int GREG_FIRST_DAY = 5;
		internal const int GREG_LAST_DAY = 14;
		internal const int GREG_JDAYS = 577737;	// date2num (GREG_YEAR, GREG_MONTH, GREG_FIRST_DAY - 1)

		// arbitrary day component of time-only DV_DATETIME
		internal const int DAY_ZERO = 1999 * 365;

		internal const int MillisPerSec = 1000;
		internal const int MicrosPerSec = 1000000;
		internal const int MicrosPerMilliSec = 1000;
		internal const int NanosPerMilliSec = 1000000;
		internal const int TicksPerSec = 10000000;

		internal static object NullIfZero (object value)
		{
			if (value == null)
				return null;
			if (value is int && (int) value == 0)
				return null;
			return value;
		}
	}
}

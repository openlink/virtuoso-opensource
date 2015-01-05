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
using System.Runtime.InteropServices;
using System.Text;

#if ODBC_CLIENT
namespace OpenLink.Data.VirtuosoOdbcClient
#elif CLIENT
namespace OpenLink.Data.VirtuosoClient
#else
namespace OpenLink.Data.Virtuoso
#endif
{
	/// <summary>
	/// Describes a backend type.
	/// </summary>
	internal class DataType
	{
		/// <summary>
		/// Virtuoso type name.
		/// </summary>
		internal readonly string typeName;

		/// <summary>
		/// Virtuoso type.
		/// </summary>
		internal readonly VirtDbType vdbType;

		/// <summary>
		/// DbType type (needed for parameters mostly).
		/// </summary>
		internal readonly System.Data.DbType dbType;

		/// <summary>
		/// ODBC type.
		/// </summary>
		internal readonly CLI.SqlType sqlType;

		/// <summary>
		/// The native type which corresponds to this backend type.
		/// </summary>
		internal BufferType bufferType;

		internal readonly bool isLong;

		internal DataType (
			string typeName,
			VirtDbType vdbType,
			System.Data.DbType dbType,
			CLI.SqlType sqlType,
			BufferType bufferType)
			: this (typeName, vdbType, dbType, sqlType, bufferType, false)
		{
		}

		internal DataType (
			string typeName,
			VirtDbType vdbType,
			System.Data.DbType dbType,
			CLI.SqlType sqlType,
			BufferType bufferType,
			bool isLong)
		{
			this.typeName = typeName;
			this.vdbType = vdbType;
			this.dbType = dbType;
			this.sqlType = sqlType;
			this.bufferType = bufferType;
			this.isLong = isLong;
		}

		internal virtual int GetFieldSize (int size)
		{
			return size;
		}

		internal virtual byte GetPrecision (int size)
		{
			return 0;
		}
	}

	internal class NumericDataType : DataType
	{
		internal NumericDataType (
			string typeName,
			VirtDbType vdbType,
			System.Data.DbType dbType,
			CLI.SqlType sqlType,
			BufferType bufferType)
			: base (typeName, vdbType, dbType, sqlType, bufferType)
		{
		}

		internal override int GetFieldSize (int size)
		{
			return bufferType.GetBufferSize (size);
		}

		internal override byte GetPrecision (int size)
		{
			return (byte) size;
		}
	}

	internal sealed class DataTypeChar : DataType
	{
		internal DataTypeChar (
			string typeName,
			VirtDbType vdbType,
			System.Data.DbType dbType,
			CLI.SqlType sqlType,
			bool isLong)
#if false
			: base (typeName, vdbType, dbType, sqlType, BufferTypes.Char, isLong)
#else
			: base (typeName, vdbType, dbType, sqlType, BufferTypes.WChar, isLong)
#endif
		{
		}

		internal override int GetFieldSize (int size)
		{
			return size;
		}
	}

	internal sealed class DataTypeWide : DataType
	{
		internal DataTypeWide (
			string typeName,
			VirtDbType vdbType,
			System.Data.DbType dbType,
			CLI.SqlType sqlType,
			bool isLong)
			: base (typeName, vdbType, dbType, sqlType, BufferTypes.WChar, isLong)
		{
		}

		internal override int GetFieldSize (int size)
		{
			int max = System.Int32.MaxValue / Platform.WideCharSize;
			return size < max ? size : max;
		}
	}

	internal sealed class DataTypeBinary : DataType
	{
		internal DataTypeBinary (
			string typeName,
			VirtDbType vdbType,
			System.Data.DbType dbType,
			CLI.SqlType sqlType,
			bool isLong)
			: base (typeName, vdbType, dbType, sqlType, BufferTypes.Binary, isLong)
		{
		}
	}

	internal sealed class DataTypeBigInt : NumericDataType
	{
		internal DataTypeBigInt (
			string typeName,
			VirtDbType vdbType,
			System.Data.DbType dbType,
			CLI.SqlType sqlType)
			: base (typeName, vdbType, dbType, sqlType, BufferTypes.BigInt)
		{
		}
	}

	internal sealed class DataTypeInt32 : NumericDataType
	{
		internal DataTypeInt32 (
			string typeName,
			VirtDbType vdbType,
			System.Data.DbType dbType,
			CLI.SqlType sqlType)
			: base (typeName, vdbType, dbType, sqlType, BufferTypes.Long)
		{
		}
	}

	internal sealed class DataTypeInt16 : NumericDataType
	{
		internal DataTypeInt16 (
			string typeName,
			VirtDbType vdbType,
			System.Data.DbType dbType,
			CLI.SqlType sqlType)
			: base (typeName, vdbType, dbType, sqlType, BufferTypes.Short)
		{
		}
	}

	internal sealed class DataTypeSingle : NumericDataType
	{
		internal DataTypeSingle (
			string typeName,
			VirtDbType vdbType,
			System.Data.DbType dbType,
			CLI.SqlType sqlType)
			: base (typeName, vdbType, dbType, sqlType, BufferTypes.Float)
		{
		}
	}

	internal sealed class DataTypeDouble : NumericDataType
	{
		internal DataTypeDouble (
			string typeName,
			VirtDbType vdbType,
			System.Data.DbType dbType,
			CLI.SqlType sqlType)
			: base (typeName, vdbType, dbType, sqlType, BufferTypes.Double)
		{
		}
	}

	internal sealed class DataTypeNumeric : NumericDataType
	{
		internal DataTypeNumeric (
			string typeName,
			VirtDbType vdbType,
			System.Data.DbType dbType,
			CLI.SqlType sqlType)
			: base (typeName, vdbType, dbType, sqlType, BufferTypes.Numeric)
		{
		}
	}

	internal sealed class DataTypeDate : DataType
	{
		internal DataTypeDate (
			string typeName,
			VirtDbType vdbType,
			System.Data.DbType dbType,
			CLI.SqlType sqlType)
			: base (typeName, vdbType, dbType, sqlType, BufferTypes.Date)
		{
		}

		internal override int GetFieldSize (int size)
		{
			return 10; // yyyy-mm-dd
		}
	}

	internal sealed class DataTypeTime : DataType
	{
		internal DataTypeTime (
			string typeName,
			VirtDbType vdbType,
			System.Data.DbType dbType,
			CLI.SqlType sqlType)
			: base (typeName, vdbType, dbType, sqlType, BufferTypes.Time)
		{
		}

		internal override int GetFieldSize (int size)
		{
			return 8; // hh-mm-ss
		}
	}

	internal sealed class DataTypeDateTime : DataType
	{
		internal DataTypeDateTime (
			string typeName,
			VirtDbType vdbType,
			System.Data.DbType dbType,
			CLI.SqlType sqlType)
			: base (typeName, vdbType, dbType, sqlType, BufferTypes.DateTime)
		{
		}

		internal override int GetFieldSize (int size)
		{
			return size < 19 ? 19 : size > 26 ? 26 : size;
		}
	}

	internal sealed class DataTypeTimestamp : DataType
	{
		internal DataTypeTimestamp (
			string typeName,
			VirtDbType vdbType,
			System.Data.DbType dbType,
			CLI.SqlType sqlType)
			: base (typeName, vdbType, dbType, sqlType, BufferTypes.Binary)
		{
		}
	}

	internal sealed class DataTypeXml : DataType
	{
		internal DataTypeXml (
			string typeName,
			VirtDbType vdbType,
			System.Data.DbType dbType,
			CLI.SqlType sqlType)
			: base (typeName, vdbType, dbType, sqlType, BufferTypes.Xml, true)
		{
		}

		internal override int GetFieldSize (int size)
		{
			int max = System.Int32.MaxValue / Platform.WideCharSize;
			return size < max ? size : max;
		}
	}

	internal sealed class DataTypeInfo
	{
		private DataTypeInfo () {} // Prevent instantiation

		internal static DataTypeChar Char;
		internal static DataTypeChar VarChar;
		internal static DataTypeChar LongVarChar;
		internal static DataTypeWide NChar;
		internal static DataTypeWide NVarChar;
		internal static DataTypeWide NLongVarChar;
		internal static DataTypeBinary Binary;
		internal static DataTypeBinary VarBinary;
		internal static DataTypeBinary LongVarBinary;
		internal static DataTypeBigInt BigInt;
		internal static DataTypeInt32 Integer;
		internal static DataTypeInt16 SmallInt;
		internal static DataTypeSingle Real;
		internal static DataTypeDouble Float;
		internal static DataTypeDouble Double;
		//internal static DataTypeNumeric Decimal;
		internal static DataTypeNumeric Numeric;
		internal static DataTypeDate Date;
		internal static DataTypeTime Time;
		internal static DataTypeDateTime DateTime;
		internal static DataTypeTimestamp Timestamp;
		internal static DataTypeXml Xml;

		static DataTypeInfo ()
		{
			//Char = new DataTypeChar ("CHAR", VirtDbType.Char, System.Data.DbType.AnsiStringFixedLength, CLI.SqlType.SQL_CHAR, false);
			Char = new DataTypeChar ("CHAR", VirtDbType.Char, System.Data.DbType.AnsiString, CLI.SqlType.SQL_CHAR, false);
			VarChar = new DataTypeChar ("VARCHAR", VirtDbType.VarChar, System.Data.DbType.AnsiString, CLI.SqlType.SQL_VARCHAR, false);
			LongVarChar = new DataTypeChar ("LONG VARCHAR", VirtDbType.LongVarChar, System.Data.DbType.AnsiString, CLI.SqlType.SQL_LONGVARCHAR, true);
			//NChar = new DataTypeWide ("NCHAR", VirtDbType.NChar, System.Data.DbType.StringFixedLength, CLI.SqlType.SQL_WCHAR, false);
			NChar = new DataTypeWide ("NCHAR", VirtDbType.NChar, System.Data.DbType.String, CLI.SqlType.SQL_WCHAR, false);
			NVarChar = new DataTypeWide ("NVARCHAR", VirtDbType.NVarChar, System.Data.DbType.String, CLI.SqlType.SQL_WVARCHAR, false);
			NLongVarChar = new DataTypeWide ("LONG NVARCHAR", VirtDbType.LongNVarChar, System.Data.DbType.String, CLI.SqlType.SQL_WVARCHAR, true);
			Binary = new DataTypeBinary ("BINARY", VirtDbType.Binary, System.Data.DbType.Binary, CLI.SqlType.SQL_BINARY, false);
			VarBinary = new DataTypeBinary ("VARBINARY", VirtDbType.VarBinary, System.Data.DbType.Binary, CLI.SqlType.SQL_VARBINARY, false);
			LongVarBinary = new DataTypeBinary ("LONG VARBINARY", VirtDbType.LongVarBinary, System.Data.DbType.Binary, CLI.SqlType.SQL_LONGVARBINARY, true);
			BigInt = new DataTypeBigInt ("BIGINT", VirtDbType.BigInt, System.Data.DbType.Int64, CLI.SqlType.SQL_BIGINT);
			Integer = new DataTypeInt32 ("INTEGER", VirtDbType.Integer, System.Data.DbType.Int32, CLI.SqlType.SQL_INTEGER);
			SmallInt = new DataTypeInt16 ("SMALLINT", VirtDbType.SmallInt, System.Data.DbType.Int16, CLI.SqlType.SQL_SMALLINT);
			Real = new DataTypeSingle ("REAL", VirtDbType.Real, System.Data.DbType.Single, CLI.SqlType.SQL_REAL);
			Float = new DataTypeDouble ("FLOAT", VirtDbType.Float, System.Data.DbType.Double, CLI.SqlType.SQL_FLOAT);
			Double = new DataTypeDouble ("DOUBLE", VirtDbType.Float, System.Data.DbType.Double, CLI.SqlType.SQL_DOUBLE);
			//Decimal = new DataTypeNumeric ("DECIMAL", VirtDbType.Decimal, System.Data.DbType.Decimal, CLI.SqlType.SQL_DECIMAL);
			Numeric = new DataTypeNumeric ("NUMERIC", VirtDbType.Numeric, System.Data.DbType.Decimal, CLI.SqlType.SQL_NUMERIC);
			Date = new DataTypeDate ("DATE", VirtDbType.Date, System.Data.DbType.Date, CLI.SqlType.SQL_TYPE_DATE);
			Time = new DataTypeTime ("TIME", VirtDbType.Time, System.Data.DbType.Time, CLI.SqlType.SQL_TYPE_TIME);
			DateTime = new DataTypeDateTime ("DATETIME", VirtDbType.DateTime, System.Data.DbType.DateTime, CLI.SqlType.SQL_TYPE_TIMESTAMP);
			Timestamp = new DataTypeTimestamp ("TIMESTAMP", VirtDbType.TimeStamp, System.Data.DbType.Binary, CLI.SqlType.SQL_BINARY);
			Xml = new DataTypeXml ("LONG XML", VirtDbType.Xml, System.Data.DbType.String, CLI.SqlType.SQL_WVARCHAR);
		}

		internal static DataType MapSqlType (CLI.SqlType type)
		{
			switch (type)
			{
			case CLI.SqlType.SQL_CHAR:		return Char;
			case CLI.SqlType.SQL_VARCHAR:		return VarChar;
			case CLI.SqlType.SQL_LONGVARCHAR:	return LongVarChar;
			case CLI.SqlType.SQL_WCHAR:		return NChar;
			case CLI.SqlType.SQL_WVARCHAR:		return NVarChar;
			case CLI.SqlType.SQL_WLONGVARCHAR:	return NLongVarChar;
			case CLI.SqlType.SQL_BINARY:		return Timestamp;
			case CLI.SqlType.SQL_VARBINARY:		return VarBinary;
			case CLI.SqlType.SQL_LONGVARBINARY:	return LongVarBinary;
			case CLI.SqlType.SQL_BIGINT:		return BigInt;
			case CLI.SqlType.SQL_INTEGER:		return Integer;
			case CLI.SqlType.SQL_SMALLINT:		return SmallInt;
			case CLI.SqlType.SQL_REAL:		return Real;
			case CLI.SqlType.SQL_FLOAT:		return Float;
			case CLI.SqlType.SQL_DOUBLE:		return Double;
			case CLI.SqlType.SQL_DECIMAL:		//return Decimal;
			case CLI.SqlType.SQL_NUMERIC:		return Numeric;
			case CLI.SqlType.SQL_DATE:
			case CLI.SqlType.SQL_TYPE_DATE:		return Date;
			case CLI.SqlType.SQL_TIME:
			case CLI.SqlType.SQL_TYPE_TIME:		return Time;
			case CLI.SqlType.SQL_TIMESTAMP:
			case CLI.SqlType.SQL_TYPE_TIMESTAMP:	return DateTime;
			}
			return null;
		}

		internal static DataType MapVirtDbType (VirtDbType vdbType)
		{
			switch (vdbType)
			{
			case VirtDbType.Binary:			return Binary;
			case VirtDbType.Char:			return Char;
			case VirtDbType.Date:			return Date;
			case VirtDbType.DateTime:		return DateTime;
				//case VirtDbType.Decimal:		return Decimal;
			case VirtDbType.Float:			return Float;
			case VirtDbType.BigInt:			return BigInt;
			case VirtDbType.Integer:		return Integer;
			case VirtDbType.LongNVarChar:		return NLongVarChar;
			case VirtDbType.LongVarBinary:		return LongVarBinary;
			case VirtDbType.LongVarChar:		return LongVarChar;
			case VirtDbType.NChar:			return NChar;
			case VirtDbType.Numeric:		return Numeric;
			case VirtDbType.NVarChar:		return NVarChar;
			case VirtDbType.Real:			return Real;
			case VirtDbType.SmallInt:		return SmallInt;
			case VirtDbType.Time:			return Time;
			case VirtDbType.TimeStamp:		return Timestamp;
			case VirtDbType.VarBinary:		return VarBinary;
			case VirtDbType.VarChar:		return VarChar;
			case VirtDbType.Xml:			return Xml;
			}
			return null;
		}

		internal static DataType MapDbType (System.Data.DbType dbType)
		{
			switch (dbType)
			{
			case DbType.AnsiString:				return VarChar;
			case DbType.AnsiStringFixedLength:		return Char;
			case DbType.Binary:				return VarBinary;
			case DbType.Date:				return Date;
			case DbType.DateTime:				return DateTime;
			case DbType.Decimal:				return Numeric;
			case DbType.Double:				return Double;
			case DbType.Int16:				return SmallInt;
			case DbType.Int32:				return Integer;
			case DbType.Int64:				return BigInt;
			case DbType.Single:				return Real;
			case DbType.String:				return NVarChar;
			case DbType.StringFixedLength:			return NChar;
			case DbType.Time:				return Time;
			}
			return null;
		}

		internal static DataType MapDvType (BoxTag tag)
		{
			switch (tag)
			{
			case BoxTag.DV_SHORT_INT:		return SmallInt;
			case BoxTag.DV_LONG_INT:		return Integer;
			case BoxTag.DV_DOUBLE_FLOAT:		return Double;
			case BoxTag.DV_SINGLE_FLOAT:		return Real;
			case BoxTag.DV_NUMERIC:			return Numeric;
			case BoxTag.DV_BLOB:
			case BoxTag.DV_BLOB_XPER:		return LongVarChar;
			case BoxTag.DV_BLOB_BIN:		return LongVarBinary;
			case BoxTag.DV_BLOB_WIDE:		return NLongVarChar;
			case BoxTag.DV_DATE:			return Date;
			case BoxTag.DV_TIME:			return Time;
			case BoxTag.DV_DATETIME:		return DateTime;
			case BoxTag.DV_TIMESTAMP:		return Timestamp;
			case BoxTag.DV_BIN:			return VarBinary;
			case BoxTag.DV_RDF:
			case BoxTag.DV_BOX_FLAGS:
			case BoxTag.DV_WIDE:
			case BoxTag.DV_LONG_WIDE:		return NVarChar;
			case BoxTag.DV_INT64:			return BigInt;
			}
			return VarChar;
		}
	}
}

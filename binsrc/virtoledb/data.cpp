/*  data.cpp
 *
 *  $Id$
 *  
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *  
 *  Copyright (C) 1998-2014 OpenLink Software
 *  
 *  This project is free software; you can redistribute it and/or modify it
 *  under the terms of the GNU General Public License as published by the
 *  Free Software Foundation; only version 2 of the License, dated June 1991.
 *  
 *  This program is distributed in the hope that it will be useful, but
 *  WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 *  General Public License for more details.
 *  
 *  You should have received a copy of the GNU General Public License along
 *  with this program; if not, write to the Free Software Foundation, Inc.,
 *  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
 *  
 *  
*/

#include "headers.h"
#include "asserts.h"
#include "syncobj.h"
#include "lobdata.h"
#include "data.h"
#include "util.h"
#include "error.h"

struct TypeNameCmp
{
  bool
  operator()(const LPOLESTR a, const LPOLESTR b) const
  {
    return _wcsicmp(a, b) < 0;
  }
};

////////////////////////////////////////////////////////////////////////
// DataType

DataType::DataType (
  native_type_t wNativeType, DBTYPE wOledbType,
  bool fFixed, bool fLong, bool fNumber, bool fUnsigned
)
{
  m_wNativeType = wNativeType;
  m_wOledbType = wOledbType;
  m_fFixed = fFixed;
  m_fLong = fLong;
  m_fNumber = fNumber;
  m_fUnsigned = fUnsigned;
}

native_size_t
DataType::RectifySize (native_size_t ulDataSize) const
{
  return ulDataSize;
}

native_scale_t
DataType::RectifyDecimalDigits (native_scale_t /*iDecimalDigits*/) const
{
  return 0;
}

DBLENGTH
DataType::GetOledbSize (native_size_t ulDataSize) const
{
  return ulDataSize;
}

BYTE
DataType::GetOledbPrecision (native_size_t /*ulDataSize*/) const
{
  return ~0;
}

BYTE
DataType::GetOledbScale (native_scale_t /*iDecimalDigits*/) const
{
  return ~0;
}

class CharType : public DataType
{
public:

  CharType (native_type_t wNativeType, bool fLong)
    : DataType (wNativeType, DBTYPE_STR, false, fLong, false, false)
  {
  }
};

class WideType : public DataType
{
public:

  WideType (native_type_t wNativeType, bool fLong)
    : DataType (wNativeType, DBTYPE_WSTR, false, fLong, false, false)
  {
  }

  virtual native_size_t
  RectifySize (native_size_t ulDataSize) const
  {
    return ulDataSize < 1073741823 ? ulDataSize : 1073741823;
  }
};

class BinaryType : public DataType
{
public:

  BinaryType (native_type_t wNativeType, bool fLong)
    : DataType (wNativeType, DBTYPE_BYTES, false, fLong, false, false)
  {
  }
};

class FixedType : public DataType
{
public:

  FixedType (native_type_t wNativeType, DBTYPE wOledbType, DBLENGTH ulSize, bool fNumber, bool fUnsigned)
    : DataType (wNativeType, wOledbType, true, false, fNumber, fUnsigned)
  {
    m_ulSize = ulSize;
  }

  virtual DBLENGTH
  GetOledbSize (native_size_t /*ulDataSize*/) const
  {
    return m_ulSize;
  }

private:

  DBLENGTH m_ulSize;
};

// All fixed and floating point types
class FNumType : public FixedType
{
public:

  FNumType (native_type_t wNativeType, DBTYPE wOledbType, BYTE ulSize, BYTE bPrecision, bool fUnsigned)
    : FixedType (wNativeType, wOledbType, ulSize, true, fUnsigned)
  {
    m_bPrecision = bPrecision;
  }

  virtual native_size_t
  RectifySize (native_size_t /*ulDataSize*/) const
  {
    return m_bPrecision;
  }

  virtual BYTE
  GetOledbPrecision (native_size_t /*ulDataSize*/) const
  {
    return m_bPrecision;
  }

private:

  BYTE m_bPrecision;
};

class NumericType : public FixedType
{
public:

  NumericType (native_type_t wNativeType)
    : FixedType (wNativeType, DBTYPE_NUMERIC, sizeof (DB_NUMERIC), true, false)
  {
  }

  virtual native_size_t
  RectifySize (native_size_t ulDataSize) const
  {
    // Virtuoso currently supports 40-digit numerics, but this could cause
    // problems in OLEDB clients (especially test suites:-). So pretend that
    // our precision conforms to the standard precision.
    return ulDataSize < 39 ? ulDataSize : 39;
  }

  virtual native_scale_t
  RectifyDecimalDigits (native_scale_t iDecimalDigits) const
  {
    return iDecimalDigits < 15 ? iDecimalDigits : 15;
  }

  virtual BYTE
  GetOledbPrecision (native_size_t ulDataSize) const
  {
    return (BYTE) ulDataSize;
  }

  virtual BYTE
  GetOledbScale (native_scale_t iDecimalDigits) const
  {
    return (BYTE) iDecimalDigits;
  }
};

class DateType : public FixedType
{
public:

  DateType (native_type_t wNativeType)
    : FixedType (wNativeType, DBTYPE_DBDATE, sizeof (DBDATE), false, false)
  {
  }

  virtual native_size_t
  RectifySize (native_size_t /*ulDataSize*/) const
  {
    return 10; // yyyy-mm-dd
  }
};

class TimeType : public FixedType
{
public:

  TimeType (native_type_t wNativeType)
    : FixedType (wNativeType, DBTYPE_DBTIME, sizeof (DBTIME), false, false)
  {
  }

  virtual native_size_t
  RectifySize (native_size_t /*ulDataSize*/) const
  {
    return 8; // hh:mm;ss
  }
};

class DateTimeType : public FixedType
{
public:

  DateTimeType (native_type_t wNativeType)
    : FixedType (wNativeType, DBTYPE_DBTIMESTAMP, sizeof (DBTIMESTAMP), false, false)
  {
  }

  virtual native_size_t
  RectifySize (native_size_t ulDataSize) const
  {
    return ulDataSize < 19 ? 19 : ulDataSize > 26 ? 26 : ulDataSize; // yyyy-mm-dd hh:mm:ss[.ffffff]
  }

  virtual native_scale_t
  RectifyDecimalDigits (native_scale_t iDecimalDigits) const
  {
    return iDecimalDigits > 6 ? 6 : iDecimalDigits;
  }

  virtual BYTE
  GetOledbPrecision (native_size_t ulDataSize) const
  {
    return (BYTE) ulDataSize;
  }

  virtual BYTE
  GetOledbScale (native_scale_t iDecimalDigits) const
  {
    return (BYTE) iDecimalDigits;
  }
};

// native types
CharType g_type_CHAR (SQL_CHAR, false);
CharType g_type_VARCHAR (SQL_VARCHAR, false);
CharType g_type_LONGVARCHAR (SQL_LONGVARCHAR, true);
WideType g_type_WCHAR (SQL_WCHAR, false);
WideType g_type_WVARCHAR (SQL_WVARCHAR, false);
WideType g_type_WLONGVARCHAR (SQL_WLONGVARCHAR, true);
BinaryType g_type_BINARY (SQL_BINARY, false);
FixedType g_type_TIMESTAMP (SQL_BINARY, DBTYPE_BYTES, 10, false, false);
BinaryType g_type_VARBINARY (SQL_VARBINARY, false);
BinaryType g_type_LONGVARBINARY (SQL_LONGVARBINARY, true);
FNumType g_type_SMALLINT (SQL_SMALLINT, DBTYPE_I2, sizeof (SHORT), 5, false);
FNumType g_type_INTEGER (SQL_INTEGER, DBTYPE_I4, sizeof (LONG), 10, false);
FNumType g_type_REAL (SQL_REAL, DBTYPE_R4, sizeof (FLOAT), 7, false);
FNumType g_type_FLOAT (SQL_FLOAT, DBTYPE_R8, sizeof (DOUBLE), 15, false);
FNumType g_type_DOUBLE (SQL_DOUBLE, DBTYPE_R8, sizeof (DOUBLE), 15, false);
NumericType g_type_DECIMAL (SQL_DECIMAL);
NumericType g_type_NUMERIC (SQL_NUMERIC);
DateType g_type_DATE (SQL_TYPE_DATE);
TimeType g_type_TIME (SQL_TYPE_TIME);
DateTimeType g_type_DATETIME (SQL_TYPE_TIMESTAMP);

// synthetic types
WideType g_type_WSTR (SQL_UNKNOWN_TYPE, false);
FNumType g_type_I2 (SQL_UNKNOWN_TYPE, DBTYPE_I2, sizeof (SHORT), 5, false);
FNumType g_type_UI2 (SQL_UNKNOWN_TYPE, DBTYPE_UI2, sizeof (USHORT), 5, true);
FNumType g_type_I4 (SQL_UNKNOWN_TYPE, DBTYPE_I4, sizeof (LONG), 10, false);
FNumType g_type_UI4 (SQL_UNKNOWN_TYPE, DBTYPE_UI4, sizeof (ULONG), 10, true);
FNumType g_type_I8 (SQL_UNKNOWN_TYPE, DBTYPE_I8, sizeof (LONGLONG), 19, false);
FNumType g_type_UI8 (SQL_UNKNOWN_TYPE, DBTYPE_UI8, sizeof (ULONGLONG), 20, true);
FNumType g_type_R4 (SQL_UNKNOWN_TYPE, DBTYPE_R4, sizeof (FLOAT), 7, false);
FNumType g_type_R8 (SQL_UNKNOWN_TYPE, DBTYPE_R8, sizeof (DOUBLE), 15, false);
FixedType g_type_BOOL (SQL_UNKNOWN_TYPE, DBTYPE_BOOL, sizeof (SHORT), false, false);
FixedType g_type_GUID (SQL_UNKNOWN_TYPE, DBTYPE_GUID, sizeof (GUID), false, false);
FixedType g_type_IUNKNOWN (SQL_UNKNOWN_TYPE, DBTYPE_IUNKNOWN, sizeof (IUnknown*), false, false);
FixedType g_type_VARIANT (SQL_UNKNOWN_TYPE, DBTYPE_VARIANT, sizeof (VARIANT), false, false);
// A date stored in the same way as in Automation: a double, the whole part of which is the number
// of days since December 30, 1899, and the fractional part of which is the fraction of a day.
FixedType g_type_OLEDATE (SQL_UNKNOWN_TYPE, DBTYPE_DATE, sizeof (double), false, false);

////////////////////////////////////////////////////////////////////////
// BufferType

BufferType::BufferType (DBTYPE wOledbType, SQLSMALLINT wSqlCType, ULONG ulAlignment)
{
  m_wOledbType = wOledbType;
  m_wSqlCType = wSqlCType;
  m_ulAlignment = ulAlignment;
}

class FixedBufferType : public BufferType
{
public:

  FixedBufferType (DBTYPE wOledbType, SQLSMALLINT wSqlCType, ULONG ulAlignment, ULONG ulSize)
    : BufferType (wOledbType, wSqlCType, ulAlignment)
  {
    m_ulSize = ulSize;
  }

  virtual ULONG
  GetBufferSize (ULONG /*ulDataSize*/) const
  {
    return m_ulSize;
  }

private:

  ULONG m_ulSize;
};


class CharBufferType : public BufferType
{
public:

  CharBufferType (DBTYPE wOledbType, SQLSMALLINT wSqlCType, ULONG ulAlignment)
    : BufferType (wOledbType, wSqlCType, ulAlignment)
  {
  }

  virtual ULONG
  GetBufferSize (ULONG ulDataSize) const
  {
    return ulDataSize + 1;
  }
};


class WideBufferType : public BufferType
{
public:

  WideBufferType (DBTYPE wOledbType, SQLSMALLINT wSqlCType, ULONG ulAlignment)
    : BufferType (wOledbType, wSqlCType, ulAlignment)
  {
  }

  virtual ULONG
  GetBufferSize (ULONG ulDataSize) const
  {
    return (ulDataSize + 1) * sizeof (SQLWCHAR);
  }
};


class BinaryBufferType : public BufferType
{
public:

  BinaryBufferType (DBTYPE wOledbType, SQLSMALLINT wSqlCType, ULONG ulAlignment)
    : BufferType (wOledbType, wSqlCType, ulAlignment)
  {
  }

  virtual ULONG
  GetBufferSize (ULONG ulDataSize) const
  {
    return ulDataSize;
  }
};


FixedBufferType g_bufferType_BOOL (DBTYPE_BOOL, SQL_C_SHORT, sizeof(SQLSMALLINT), sizeof(SQLSMALLINT));
FixedBufferType g_bufferType_I1 (DBTYPE_I1, SQL_C_STINYINT, sizeof(SQLSCHAR), sizeof(SQLSCHAR));
FixedBufferType g_bufferType_UI1 (DBTYPE_UI1, SQL_C_UTINYINT, sizeof(SQLCHAR), sizeof(SQLCHAR));
FixedBufferType g_bufferType_I2 (DBTYPE_I2, SQL_C_SSHORT, sizeof(SQLSMALLINT), sizeof(SQLSMALLINT));
FixedBufferType g_bufferType_UI2 (DBTYPE_UI2, SQL_C_USHORT, sizeof(SQLUSMALLINT), sizeof(SQLUSMALLINT));
FixedBufferType g_bufferType_I4 (DBTYPE_I4, SQL_C_SLONG, sizeof(SQLINTEGER), sizeof(SQLINTEGER));
FixedBufferType g_bufferType_UI4 (DBTYPE_UI4, SQL_C_ULONG, sizeof(SQLUINTEGER), sizeof(SQLUINTEGER));
FixedBufferType g_bufferType_I8 (DBTYPE_I8, SQL_C_SBIGINT, sizeof(SQLBIGINT), sizeof(SQLBIGINT));
FixedBufferType g_bufferType_UI8 (DBTYPE_UI8, SQL_C_UBIGINT, sizeof(SQLUBIGINT), sizeof(SQLUBIGINT));
FixedBufferType g_bufferType_R4 (DBTYPE_R4, SQL_C_FLOAT, sizeof(SQLREAL), sizeof(SQLREAL));
FixedBufferType g_bufferType_R8 (DBTYPE_R8, SQL_C_DOUBLE, sizeof(SQLDOUBLE), sizeof(SQLDOUBLE));
// SQL_NUMERIC_STRUCT contains only chars, therefore 1-byte alignment is enough.
FixedBufferType g_bufferType_NUMERIC (DBTYPE_NUMERIC, SQL_C_NUMERIC, sizeof(SQLCHAR), sizeof(SQL_NUMERIC_STRUCT));
// DATE_STRUCT and TIME_STRUCT contain only shorts, therefore 2-byte alignment is enough.
FixedBufferType g_bufferType_DBDATE (DBTYPE_DBDATE, SQL_C_TYPE_DATE, sizeof(SQLSMALLINT), sizeof(DATE_STRUCT));
FixedBufferType g_bufferType_DBTIME (DBTYPE_DBTIME, SQL_C_TYPE_TIME, sizeof(SQLSMALLINT), sizeof(TIME_STRUCT));
// TIMESTAMP_STRUCT contains a long, therfore it requires 4-byte alignment.
FixedBufferType g_bufferType_DBTIMESTAMP (DBTYPE_DBTIMESTAMP, SQL_C_TYPE_TIMESTAMP, sizeof(SQLINTEGER), sizeof(TIMESTAMP_STRUCT));
FixedBufferType g_bufferType_GUID (DBTYPE_GUID, SQL_C_BINARY, sizeof(SQLINTEGER), sizeof(GUID));
FixedBufferType g_bufferType_IUNKNOWN (DBTYPE_IUNKNOWN, SQL_C_BINARY, sizeof(IUnknown*), sizeof(IUnknown*));
CharBufferType g_bufferType_STR (DBTYPE_STR, SQL_C_CHAR, sizeof(SQLCHAR));
WideBufferType g_bufferType_WSTR (DBTYPE_WSTR, SQL_C_WCHAR, sizeof(SQLWCHAR));
BinaryBufferType g_bufferType_BYTES (DBTYPE_BYTES, SQL_C_BINARY, sizeof(SQLCHAR));

FixedBufferType g_bufferType_Long_STR (DBTYPE_STR, SQL_C_CHAR, sizeof (LONG_PTR), sizeof (LONG_PTR));
FixedBufferType g_bufferType_Long_WSTR (DBTYPE_WSTR, SQL_C_WCHAR, sizeof (LONG_PTR), sizeof (LONG_PTR));
FixedBufferType g_bufferType_Long_BYTES (DBTYPE_BYTES, SQL_C_BINARY, sizeof (LONG_PTR), sizeof (LONG_PTR));

////////////////////////////////////////////////////////////////////////
// DataFieldInfo

DataFieldInfo::DataFieldInfo ()
  : m_name(L"")
{
  m_pDataType = NULL;
  m_pBufferType = NULL;
  m_field_size = 0;
  m_decimal_digits = 0;
  m_internal_length = 0;
  m_internal_offset = 0;
  m_flags = 0;
}

const DataType*
DataFieldInfo::MapNativeType (native_type_t wNativeType)
{
  switch (wNativeType)
    {
    case SQL_CHAR:		return &g_type_CHAR;
    case SQL_VARCHAR:		return &g_type_VARCHAR;
    case SQL_LONGVARCHAR:	return &g_type_LONGVARCHAR;
    case SQL_WCHAR:		return &g_type_WCHAR;
    case SQL_WVARCHAR:		return &g_type_WVARCHAR;
    case SQL_WLONGVARCHAR:	return &g_type_WLONGVARCHAR;
    case SQL_SMALLINT:		return &g_type_SMALLINT;
    case SQL_INTEGER:		return &g_type_INTEGER;
    case SQL_REAL:		return &g_type_REAL;
    case SQL_FLOAT:		return &g_type_FLOAT;
    case SQL_DOUBLE:		return &g_type_DOUBLE;
    case SQL_NUMERIC:		return &g_type_NUMERIC;
    case SQL_DECIMAL:		return &g_type_DECIMAL;
    case SQL_BINARY:		return &g_type_TIMESTAMP;
    case SQL_VARBINARY:		return &g_type_VARBINARY;
    case SQL_LONGVARBINARY:	return &g_type_LONGVARBINARY;
    case SQL_DATE:
    case SQL_TYPE_DATE:		return &g_type_DATE;
    case SQL_TIME:
    case SQL_TYPE_TIME:		return &g_type_TIME;
    case SQL_TIMESTAMP:
    case SQL_TYPE_TIMESTAMP:	return &g_type_DATETIME;
    }
  return NULL;
}

const DataType*
DataFieldInfo::MapNativeType (const LPOLESTR pwszDataSourceType)
{
  if (pwszDataSourceType == NULL)
    return NULL;

  static bool initialized = false;
  static std::map<LPOLESTR, DataType*, TypeNameCmp> mpType;
  if (!initialized)
    {
      CriticalSection critical_section(&Module::m_GlobalSync);
      if (!initialized)
	{
	  initialized = true;

	  // Map OLEDB names.
	  mpType[L"DBTYPE_I2"] = &g_type_SMALLINT;
	  mpType[L"DBTYPE_I4"] = &g_type_INTEGER;
	  mpType[L"DBTYPE_R4"] = &g_type_REAL;
	  mpType[L"DBTYPE_R8"] = &g_type_DOUBLE;
	  mpType[L"DBTYPE_NUMERIC"] = &g_type_NUMERIC;
	  mpType[L"DBTYPE_STR"] = &g_type_CHAR;
	  mpType[L"DBTYPE_WSTR"] = &g_type_WCHAR;
	  mpType[L"DBTYPE_BYTES"] = &g_type_BINARY;
	  mpType[L"DBTYPE_DBDATE"] = &g_type_DATE;
	  mpType[L"DBTYPE_DBTIME"] = &g_type_TIME;
	  mpType[L"DBTYPE_DBTIMESTAMP"] = &g_type_DATETIME;
	  mpType[L"DBTYPE_CHAR"] = &g_type_CHAR;
	  mpType[L"DBTYPE_VARCHAR"] = &g_type_VARCHAR;
	  mpType[L"DBTYPE_LONGVARCHAR"] = &g_type_LONGVARCHAR;
	  mpType[L"DBTYPE_WCHAR"] = &g_type_WCHAR;
	  mpType[L"DBTYPE_WVARCHAR"] = &g_type_WVARCHAR;
	  mpType[L"DBTYPE_WLONGVARCHAR"] = &g_type_WLONGVARCHAR;
	  mpType[L"DBTYPE_BINARY"] = &g_type_BINARY;
	  mpType[L"DBTYPE_VARBINARY"] = &g_type_VARBINARY;
	  mpType[L"DBTYPE_LONGVARBINARY"] = &g_type_LONGVARBINARY;

	  // Map Virtuoso names.
	  mpType[L"SMALLINT"] = &g_type_SMALLINT;
	  mpType[L"INT"] = &g_type_INTEGER;
	  mpType[L"INTEGER"] = &g_type_INTEGER;
	  mpType[L"REAL"] = &g_type_REAL;
	  mpType[L"FLOAT"] = &g_type_FLOAT;
	  mpType[L"DOUBLE"] = &g_type_DOUBLE;
	  mpType[L"DOUBLE PRECISION"] = &g_type_DOUBLE;
	  mpType[L"DECIMAL"] = &g_type_DECIMAL;
	  mpType[L"NUMERIC"] = &g_type_NUMERIC;
	  mpType[L"CHAR"] = &g_type_CHAR;
	  mpType[L"CHARACTER"] = &g_type_CHAR;
	  mpType[L"VARCHAR"] = &g_type_VARCHAR;
	  mpType[L"LONG VARCHAR"] = &g_type_LONGVARCHAR;
	  mpType[L"NCHAR"] = &g_type_WCHAR;
	  mpType[L"NCHARACTER"] = &g_type_WCHAR;
	  mpType[L"NVARCHAR"] = &g_type_WVARCHAR;
	  mpType[L"LONG NVARCHAR"] = &g_type_WLONGVARCHAR;
	  mpType[L"BINARY"] = &g_type_BINARY;
	  mpType[L"VARBINARY"] = &g_type_VARBINARY;
	  mpType[L"LONG VARBINARY"] = &g_type_LONGVARBINARY;
	  mpType[L"DATE"] = &g_type_DATE;
	  mpType[L"TIME"] = &g_type_TIME;
	  mpType[L"DATETIME"] = &g_type_DATETIME;
	  mpType[L"TIMESTAMP"] = &g_type_TIMESTAMP;
	}
    }

  std::map<LPOLESTR, DataType*, TypeNameCmp>::iterator iter = mpType.find(pwszDataSourceType);
  if (iter == mpType.end())
    return NULL;

  return iter->second;
}

const DataType*
DataFieldInfo::MapSyntheticType (DBTYPE wOledbType)
{
  switch (wOledbType)
    {
    case DBTYPE_WSTR:		return &g_type_WSTR;
    case DBTYPE_I2:		return &g_type_I2;
    case DBTYPE_UI2:		return &g_type_UI2;
    case DBTYPE_I4:		return &g_type_I4;
    case DBTYPE_UI4:		return &g_type_UI4;
    case DBTYPE_I8:		return &g_type_I8;
    case DBTYPE_UI8:		return &g_type_UI8;
    case DBTYPE_R4:		return &g_type_R4;
    case DBTYPE_R8:		return &g_type_R8;
    case DBTYPE_BOOL:		return &g_type_BOOL;
    case DBTYPE_GUID:		return &g_type_GUID;
    case DBTYPE_IUNKNOWN:	return &g_type_IUNKNOWN;
    case DBTYPE_VARIANT:	return &g_type_VARIANT;
    case DBTYPE_DATE:		return &g_type_OLEDATE;
    }
  return NULL;
}

const BufferType*
DataFieldInfo::MapTypeToBuffer (const DataType* pDataType)
{
  if (pDataType == NULL)
    return NULL;

  if (pDataType->IsLong ())
    {
      switch (pDataType->GetOledbType ())
	{
	case DBTYPE_STR:	return &g_bufferType_Long_STR;
	case DBTYPE_WSTR:	return &g_bufferType_Long_WSTR;
	case DBTYPE_BYTES:	return &g_bufferType_Long_BYTES;
	}
      return NULL;
    }

  switch (pDataType->GetOledbType ())
    {
    case DBTYPE_BOOL:		return &g_bufferType_BOOL;
    case DBTYPE_I1:		return &g_bufferType_I1;
    case DBTYPE_UI1:		return &g_bufferType_UI1;
    case DBTYPE_I2:		return &g_bufferType_I2;
    case DBTYPE_UI2:		return &g_bufferType_UI2;
    case DBTYPE_I4:		return &g_bufferType_I4;
    case DBTYPE_UI4:		return &g_bufferType_UI4;
    case DBTYPE_I8:		return &g_bufferType_I8;
    case DBTYPE_UI8:		return &g_bufferType_UI8;
    case DBTYPE_R4:		return &g_bufferType_R4;
    case DBTYPE_DATE:
    case DBTYPE_R8:		return &g_bufferType_R8;
    case DBTYPE_DECIMAL:
    case DBTYPE_NUMERIC:
    case DBTYPE_VARNUMERIC:	return &g_bufferType_NUMERIC;
    case DBTYPE_DBDATE:		return &g_bufferType_DBDATE;
    case DBTYPE_DBTIME:		return &g_bufferType_DBTIME;
    case DBTYPE_DBTIMESTAMP:	return &g_bufferType_DBTIMESTAMP;
    case DBTYPE_GUID:		return &g_bufferType_GUID;
    case DBTYPE_IUNKNOWN:	return &g_bufferType_IUNKNOWN;
    case DBTYPE_STR:		return &g_bufferType_STR;
    case DBTYPE_BSTR:
    case DBTYPE_WSTR:		return &g_bufferType_WSTR;
    case DBTYPE_BYTES:		return &g_bufferType_BYTES;
    }
  return NULL;
}

const BufferType*
DataFieldInfo::OptimizeBufferType (const DataType *pDataType, DBTYPE wOledbType)
{
  if (pDataType == NULL)
    return NULL;

  switch (pDataType->GetNativeType ())
    {
    case SQL_CHAR:
    case SQL_VARCHAR:
    case SQL_LONGVARCHAR:
    case SQL_WCHAR:
    case SQL_WVARCHAR:
    case SQL_WLONGVARCHAR:
    case SQL_BINARY:
    case SQL_VARBINARY:
    case SQL_LONGVARBINARY:
      switch (wOledbType)
	{
	case DBTYPE_STR:	return &g_bufferType_STR;
	case DBTYPE_WSTR:	return &g_bufferType_WSTR;
	case DBTYPE_BYTES:	return &g_bufferType_BYTES;
	}
      break;

    case SQL_SMALLINT:
    case SQL_INTEGER:
    case SQL_REAL:
    case SQL_FLOAT:
    case SQL_DOUBLE:
    case SQL_NUMERIC:
    case SQL_DECIMAL:
      switch (wOledbType)
	{
	case DBTYPE_STR:	return &g_bufferType_STR;
	case DBTYPE_WSTR:	return &g_bufferType_WSTR;
	case DBTYPE_BYTES:	return &g_bufferType_BYTES;
	case DBTYPE_I1:		return &g_bufferType_I2;
	case DBTYPE_UI1:	return &g_bufferType_UI2;
	case DBTYPE_I2:		return &g_bufferType_I2;
	case DBTYPE_UI2:	return &g_bufferType_UI2;
	case DBTYPE_I4:		return &g_bufferType_I4;
	case DBTYPE_UI4:	return &g_bufferType_UI4;
	case DBTYPE_R4:		return &g_bufferType_R4;
	case DBTYPE_R8:		return &g_bufferType_R8;
	}
      break;

    case SQL_DATE:
    case SQL_TYPE_DATE:
    case SQL_TIME:
    case SQL_TYPE_TIME:
    case SQL_TIMESTAMP:
    case SQL_TYPE_TIMESTAMP:
      switch (wOledbType)
	{
	case DBTYPE_STR:	return &g_bufferType_STR;
	case DBTYPE_WSTR:	return &g_bufferType_WSTR;
	case DBTYPE_BYTES:	return &g_bufferType_BYTES;
	case DBTYPE_DBDATE:	return &g_bufferType_DBDATE;
	case DBTYPE_DBTIME:	return &g_bufferType_DBTIME;
	case DBTYPE_DBTIMESTAMP:return &g_bufferType_DBTIMESTAMP;
	}
      break;
    }

  return NULL;
}

HRESULT
DataFieldInfo::SetNativeFieldInfo (
  native_type_t wNativeType,
  native_size_t ulDataSize,
  native_scale_t iDecimalDigits
)
{
  m_pDataType = MapNativeType (wNativeType);
  if (m_pDataType == NULL)
    return ErrorInfo::Set (E_FAIL, "Unknown data type");

  m_field_size = m_pDataType->RectifySize (ulDataSize);
  LOGCALL (("DataFieldInfo::SetNativeFieldInfo () wNativeType=%d, ulDataSize=%lu m_field_size=%lu\n",
	(int) wNativeType,
	(unsigned long) ulDataSize,
	(unsigned long) m_field_size));
  m_decimal_digits = m_pDataType->RectifyDecimalDigits (iDecimalDigits);
  return S_OK;
}

HRESULT
DataFieldInfo::SetNativeFieldInfo (
  const LPOLESTR pwszDataSourceType,
  DBLENGTH ulDataSize,
  BYTE bPrecision,
  BYTE bScale
)
{
  m_pDataType = MapNativeType (pwszDataSourceType);
  if (m_pDataType == NULL)
    return ErrorInfo::Set (E_FAIL, "Unknown data type");

  if (m_pDataType->IsFixed ())
    m_field_size = m_pDataType->RectifySize (bPrecision);
   else
    m_field_size = m_pDataType->RectifySize ((native_size_t)ulDataSize);
  m_decimal_digits = m_pDataType->RectifyDecimalDigits (bScale);
  return S_OK;
}

HRESULT
DataFieldInfo::SetSyntheticFieldInfo (DBTYPE wOledbType, native_size_t ulDataSize, native_scale_t iDecimalDigits)
{
  m_pDataType = MapSyntheticType (wOledbType);
  if (m_pDataType == NULL)
    return ErrorInfo::Set (E_FAIL, "Unknown data type");

  m_field_size = m_pDataType->RectifySize (ulDataSize);
  m_decimal_digits = m_pDataType->RectifyDecimalDigits (iDecimalDigits);
  return S_OK;
}

HRESULT
DataFieldInfo::SetName(const OLECHAR* name)
{
  LOGCALL(("DataFieldInfo::SetName('%ls')\n", name ? name : L""));

  if (name == NULL)
    {
      m_name.erase();
    }
  else
    {
      try {
	m_name = name;
      } catch (...) {
	return ErrorInfo::Set(E_OUTOFMEMORY);
      }
    }
  return S_OK;
}

HRESULT
DataFieldInfo::Optimize(DBTYPE type)
{
  assert(IsSet());

  if (m_pBufferType != NULL)
    return ErrorInfo::Set(DB_E_BADBINDINFO);

  m_pBufferType = OptimizeBufferType (m_pDataType, type);
  return S_OK;
}

HRESULT
DataFieldInfo::Complete(ULONG offset)
{
  assert(IsSet());

  if (m_pBufferType == NULL)
    m_pBufferType = MapTypeToBuffer (m_pDataType);

  int align = m_pBufferType->GetAlignment ();
  offset += align - 1;
  offset -= offset % align;

  m_internal_offset = offset;
  m_internal_length = m_pBufferType->GetBufferSize (m_field_size);
  return S_OK;
}

/**********************************************************************/
/* DataRecordInfo                                                     */

DataRecordInfo::DataRecordInfo()
{
  m_status = STATUS_UNINITIALIZED;
  m_cbRecordSize = 0;
  m_fHasLongData = false;
}

HRESULT
DataRecordInfo::Init()
{
  assert(m_status == STATUS_UNINITIALIZED);
  m_status = STATUS_INITIALIZED;
  return S_OK;
}

void
DataRecordInfo::Release()
{
  m_status = STATUS_UNINITIALIZED;
}

HRESULT
DataRecordInfo::Optimize(ULONG iField, DBTYPE type)
{
  if (IsCompleted())
    return ErrorInfo::Set(DB_E_BADACCESSORFLAGS);

  assert(m_status == STATUS_INITIALIZED);
  return const_cast<DataFieldInfo&>(GetFieldInfo(iField)).Optimize(type);
}

// The overhead argument was intended for use with Doug Lea's independent_calloc()
// but this aproach has never been actually tetsed. Left here just in case...
HRESULT
DataRecordInfo::Complete (size_t /*overhead*/)
{
  assert(m_status == STATUS_INITIALIZED);

  ULONG cFieldInfos = (ULONG)GetFieldCount();
  ULONG cbRunningSize = GetExtraSize() + cFieldInfos * sizeof(SQLLEN);
  for (ULONG i = 0; i < cFieldInfos; i++)
    {
      DataFieldInfo& field_info = const_cast<DataFieldInfo&>(GetFieldInfo(i));
      if (!field_info.IsSet())
	continue;
      if (field_info.IsLong())
	m_fHasLongData = true;

      HRESULT hr = field_info.Complete(cbRunningSize);
      if (FAILED(hr))
	return hr;
      cbRunningSize = field_info.GetInternalOffset() + field_info.GetInternalLength();
    }

  // Finally, it is necessary to align for rows that might go in succession.
  // Presumably doubles always has the worst alignment requirements.
#if 0
  cbRunningSize += overhead;
  cbRunningSize += sizeof (double) - 1;
  cbRunningSize -= cbRunningSize % sizeof (double);
  m_cbRecordSize = cbRunningSize - overhead;
#else
  cbRunningSize += sizeof (double) - 1;
  cbRunningSize -= cbRunningSize % sizeof (double);
  m_cbRecordSize = cbRunningSize;
#endif

  m_status = STATUS_COMPLETED;
  return S_OK;
}

/**********************************************************************/
/* DataAccessor                                                       */

HRESULT
DataAccessor::Init (DBACCESSORFLAGS dwAccessorFlags, DBCOUNTITEM cBindings, const DBBINDING rgBindings[], DBLENGTH cbRowSize)
{
  m_iRefCount = 1;
  m_dwAccessorFlags = dwAccessorFlags;
  m_cbRowSize = cbRowSize;
  return CopyBindings (cBindings, rgBindings);
}

HRESULT
DataAccessor::Init (const DataAccessor& accessor, DBACCESSORFLAGS dwAccessorFlags)
{
  m_iRefCount = 1;
  m_dwAccessorFlags = dwAccessorFlags;
  m_cbRowSize = accessor.m_cbRowSize;
  return CopyBindings (accessor.m_cBindings, accessor.m_rgBindings);
}

HRESULT
DataAccessor::CopyBindings (DBCOUNTITEM cBindings, const DBBINDING rgBindings[])
{
  LOGCALL (("DataAccessor::CopyBindings(cBindings = %d)\n", cBindings));

  m_cBindings = cBindings;

  if (cBindings == 0)
    {
      m_rgBindings = NULL;
      return S_OK;
    }

  m_rgBindings = new DBBINDING[cBindings];
  if (m_rgBindings == NULL)
    return ErrorInfo::Set (E_OUTOFMEMORY);

  memcpy (m_rgBindings, rgBindings, cBindings * sizeof (DBBINDING));
  for (DBCOUNTITEM iBinding = 0; iBinding < m_cBindings; iBinding++)
    {
      DBBINDING& binding = m_rgBindings[iBinding];
      if ((binding.dwPart & DBPART_VALUE) != 0
	  && binding.wType == DBTYPE_IUNKNOWN
	  && binding.pObject != NULL)
	{
	  DBOBJECT* pObject = new DBOBJECT;
	  if (pObject == NULL)
	    {
	      // Prevent releasing non-copied bindings.
	      for (; iBinding < m_cBindings; iBinding++)
		{
		  DBBINDING& binding = m_rgBindings[iBinding];
		  binding.pObject = NULL;
		}
	      // Release copied bindings.
	      FreeBindings ();
	      return ErrorInfo::Set (E_OUTOFMEMORY);
	    }
	  pObject->dwFlags = binding.pObject->dwFlags;
	  pObject->iid = binding.pObject->iid;
	  binding.pObject = pObject;
	}
    }

  return S_OK;
}

void
DataAccessor::FreeBindings ()
{
  LOGCALL (("DataAccessor::FreeBindings()\n"));

  if (m_rgBindings == NULL)
    return;

  for (DBCOUNTITEM iBinding = 0; iBinding < m_cBindings; iBinding++)
    {
      DBBINDING& binding = m_rgBindings[iBinding];
      if ((binding.dwPart & DBPART_VALUE) != 0
	  && binding.wType == DBTYPE_IUNKNOWN
	  && binding.pObject != NULL)
	{
	  delete binding.pObject;
	  binding.pObject = NULL;
	}
    }

  delete [] m_rgBindings;
  m_rgBindings = NULL;
  m_cBindings = 0;
}

/**********************************************************************/
/* DataTransferHandler                                                */

DataTransferHandler::DataTransferHandler()
{
  m_pIDataConvert = NULL;
}

DataTransferHandler::~DataTransferHandler()
{
  Release();
}

void
DataTransferHandler::Release()
{
  if (m_pIDataConvert != NULL)
    {
      m_pIDataConvert->Release();
      m_pIDataConvert = NULL;
    }
}

HRESULT
DataTransferHandler::Init()
{
  HRESULT hr = CoCreateInstance(CLSID_OLEDB_CONVERSIONLIBRARY, NULL, CLSCTX_INPROC_SERVER,
				IID_IDataConvert, (void**) &m_pIDataConvert);
  if (FAILED(hr))
    return hr;

  IDCInfo* dcinfo;
  hr = m_pIDataConvert->QueryInterface(IID_IDCInfo, (void**) &dcinfo);
  if (SUCCEEDED(hr))
    {
      DCINFO rgInfo[1];
      rgInfo[0].eInfoType = DCINFOTYPE_VERSION;
      VariantInit(&rgInfo[0].vData);
      V_VT(&rgInfo[0].vData) = VT_UI4;
      V_UI4(&rgInfo[0].vData) = 0x200;
      dcinfo->SetInfo(1, rgInfo);
      dcinfo->Release();
    }

  return S_OK;
}

DBBINDSTATUS
DataTransferHandler::ValidateBinding(DBACCESSORFLAGS dwAccessorFlags, const DBBINDING& binding)
{
  LOGCALL(("DataTransferHandler::ValidateBinding()\n"));

  if ((binding.dwPart & (DBPART_VALUE | DBPART_LENGTH | DBPART_STATUS)) == 0)
    return DBBINDSTATUS_BADBINDINFO;
  if ((binding.dwPart & ~(DBPART_VALUE | DBPART_LENGTH | DBPART_STATUS)) != 0)
    return DBBINDSTATUS_BADBINDINFO;
  if (binding.wType == DBTYPE_EMPTY
      || binding.wType == DBTYPE_NULL
      || binding.wType == (DBTYPE_BYREF | DBTYPE_EMPTY)
      || binding.wType == (DBTYPE_BYREF | DBTYPE_NULL))
    return DBBINDSTATUS_BADBINDINFO;
  if ((binding.wType & (DBTYPE_BYREF | DBTYPE_ARRAY)) == (DBTYPE_BYREF | DBTYPE_ARRAY)
      || (binding.wType & (DBTYPE_BYREF | DBTYPE_VECTOR)) == (DBTYPE_BYREF | DBTYPE_VECTOR)
      || (binding.wType & (DBTYPE_ARRAY | DBTYPE_VECTOR)) == (DBTYPE_ARRAY | DBTYPE_VECTOR))
    return DBBINDSTATUS_BADBINDINFO;
  if ((binding.wType & DBTYPE_RESERVED) != 0)
    return DBBINDSTATUS_BADBINDINFO;
  if (binding.dwMemOwner != DBMEMOWNER_CLIENTOWNED
      && binding.dwMemOwner != DBMEMOWNER_PROVIDEROWNED)
    return DBBINDSTATUS_BADBINDINFO;
  if (binding.dwMemOwner == DBMEMOWNER_PROVIDEROWNED
      && (binding.wType & DBTYPE_BYREF) == 0
      && (binding.wType & DBTYPE_ARRAY) == 0
      && (binding.wType & DBTYPE_VECTOR) == 0
      && binding.wType != DBTYPE_BSTR)
    return DBBINDSTATUS_BADBINDINFO;
  if (binding.dwMemOwner == DBMEMOWNER_PROVIDEROWNED
      && (dwAccessorFlags & DBACCESSOR_PARAMETERDATA) != 0
      && (dwAccessorFlags & DBACCESSOR_PASSBYREF) == 0)
    return DBBINDSTATUS_BADBINDINFO;
  if (binding.dwFlags != 0 && binding.dwFlags != DBBINDFLAG_HTML)
    return DBBINDSTATUS_BADBINDINFO;
  if (binding.dwFlags == DBBINDFLAG_HTML
      && binding.wType != DBTYPE_STR
      && binding.wType != DBTYPE_WSTR
      && binding.wType != DBTYPE_BSTR)
    return DBBINDSTATUS_BADBINDINFO;
  if ((binding.dwPart & DBPART_VALUE) != 0
      && binding.wType == DBTYPE_IUNKNOWN
      && binding.pObject != NULL
      && binding.pObject->iid != IID_IUnknown
      && binding.pObject->iid != IID_ISequentialStream)
    return DBBINDSTATUS_NOINTERFACE;
  if ((dwAccessorFlags & DBACCESSOR_PARAMETERDATA) != 0)
    {
      if (binding.eParamIO != DBPARAMIO_INPUT
	  && binding.eParamIO != DBPARAMIO_OUTPUT
	  && binding.eParamIO != (DBPARAMIO_INPUT | DBPARAMIO_OUTPUT))
	return DBBINDSTATUS_BADBINDINFO;
      if ((binding.eParamIO & DBPARAMIO_OUTPUT) != 0
	  && (dwAccessorFlags & DBACCESSOR_PASSBYREF) != 0)
	return DBBINDSTATUS_BADBINDINFO;
      if (binding.iOrdinal == 0)
	return DBBINDSTATUS_BADORDINAL;
    }

  return DBBINDSTATUS_OK;
}

DBBINDSTATUS
DataTransferHandler::MetadataValidateBinding(const DataRecordInfo& info, const DBBINDING& binding)
{
  LOGCALL(("DataTransferHandler::MetadataValidateBinding()\n"));

  ULONG field_index = info.OrdinalToIndex(binding.iOrdinal);
  if (field_index > info.GetFieldCount() /*|| field_index < 0*/)
    return DBBINDSTATUS_BADORDINAL;

  const DataFieldInfo& field_info = info.GetFieldInfo(field_index);
  DBTYPE type = field_info.GetInternalDBType();
  bool is_long = field_info.IsLong();

  assert(type != DBTYPE_EMPTY);
  if (binding.dwMemOwner == DBMEMOWNER_PROVIDEROWNED)
    {
      if (binding.wType != (type | DBTYPE_BYREF))
	return DBBINDSTATUS_BADBINDINFO;
      if (is_long)
	return DBBINDSTATUS_BADBINDINFO;
    }
  else if (binding.wType == DBTYPE_IUNKNOWN)
    {
      if (!is_long && type != DBTYPE_IUNKNOWN)
	return DBBINDSTATUS_UNSUPPORTEDCONVERSION;
    }
#if 0
  else if (is_long)
    {
      if (binding.wType != DBTYPE_STR && binding.wType != DBTYPE_WSTR && binding.wType != DBTYPE_BYTES)
	return DBBINDSTATUS_BADBINDINFO;
    }
#endif
  else
    {
      HRESULT hr = m_pIDataConvert->CanConvert(type, binding.wType);
      if (FAILED(hr) || hr == S_FALSE)
	{
	  LOG(("Cannot convert: %d -> %d\n", type, binding.wType));
	  return DBBINDSTATUS_UNSUPPORTEDCONVERSION;
	}
    }

  return DBBINDSTATUS_OK;
}

HRESULT
DataTransferHandler::CanConvert(
  DBTYPE wFromType,
  DBTYPE wToType,
  DBCONVERTFLAGS dwConvertFlags,
  bool fIsCommand
)
{
  assert(m_pIDataConvert != NULL);

  DBCONVERTFLAGS what = dwConvertFlags & ~(DBCONVERTFLAGS_ISFIXEDLENGTH | DBCONVERTFLAGS_ISLONG | DBCONVERTFLAGS_FROMVARIANT);
  if (what != DBCONVERTFLAGS_COLUMN && what != DBCONVERTFLAGS_PARAMETER)
    return ErrorInfo::Set(DB_E_BADCONVERTFLAG);
  if (what == DBCONVERTFLAGS_PARAMETER && !fIsCommand)
    return ErrorInfo::Set(DB_E_BADCONVERTFLAG);

  DBTYPE type = wFromType & ~(DBTYPE_BYREF | DBTYPE_ARRAY | DBTYPE_VECTOR | DBTYPE_RESERVED);
  if (dwConvertFlags & DBCONVERTFLAGS_FROMVARIANT)
    {
      if ((type > VT_DECIMAL && type < VT_I1)
	  || (type > VT_LPWSTR && type < VT_FILETIME && type != VT_RECORD)
	  || (type > VT_CLSID))
	return ErrorInfo::Set(DB_E_BADTYPE);
    }
  if (dwConvertFlags & DBCONVERTFLAGS_ISLONG)
    {
      if (type != DBTYPE_STR && type != DBTYPE_WSTR && type != DBTYPE_BYTES && type != DBTYPE_VARNUMERIC)
	return ErrorInfo::Set(DB_E_BADCONVERTFLAG);
    }

  return m_pIDataConvert->CanConvert(wFromType, wToType);
}

HRESULT
DataTransferHandler::GetData(
  const DataRecordInfo& info,
  GetDataHandler* pgd,
  HROW iRecordID,
  char* pbProviderData,
  const DataAccessor& accessor,
  DBCOUNTITEM iBinding,
  char* pbConsumerData,
  bool fIsParameter
)
{
  LOGCALL (("DataTransferHandler::GetData ()\n"));
  assert(pbConsumerData != NULL);
  assert(m_pIDataConvert != NULL);

  const DBBINDING& binding = accessor.GetBinding (iBinding);

  char* pbConsumerValue = NULL;
  DBLENGTH* pcbConsumerLength = NULL;
  DBSTATUS* pdwConsumerStatus = NULL;

  if (binding.dwPart & DBPART_VALUE)
    pbConsumerValue = pbConsumerData + binding.obValue;
  if (binding.dwPart & DBPART_LENGTH)
    pcbConsumerLength = (DBLENGTH*) (pbConsumerData + binding.obLength);
  if (binding.dwPart & DBPART_STATUS)
    pdwConsumerStatus = (DBSTATUS*) (pbConsumerData + binding.obStatus);
  LOG(("DataTransferHandler::GetData () dwPart=%lX max_len=%lu pbConsumerValue=%p pcbConsumerLength=%p\n",
	(unsigned long) binding.dwPart,
	(unsigned long) binding.cbMaxLen,
	pbConsumerValue,
	pcbConsumerLength));

  if (pcbConsumerLength != NULL)
    *pcbConsumerLength = 0;

  DBBINDSTATUS dwBindStatus = MetadataValidateBinding(info, binding);
  if (dwBindStatus != DBBINDSTATUS_OK)
    {
      if (pdwConsumerStatus != NULL)
	*pdwConsumerStatus = DBSTATUS_E_BADACCESSOR;
      return S_FALSE;
    }

  // Can get NULL pbProviderData when called from GetOriginalData on newly inserted rows.
  // In this case it should either return the column default value or null if unable to
  // determine the default.
  if (pbProviderData == NULL)
    {
      if (pdwConsumerStatus != NULL)
	*pdwConsumerStatus = DBSTATUS_S_ISNULL;
      return S_OK;
    }

  ULONG iField = info.OrdinalToIndex(binding.iOrdinal);
  const DataFieldInfo& field_info = info.GetFieldInfo(iField);
  assert(field_info.IsSet());

  if (fIsParameter)
    {
      DBPARAMFLAGS flags = field_info.GetFlags();
      if (!(flags & DBPARAMFLAGS_ISOUTPUT))
	return S_OK;
    }

  SQLSMALLINT wSqlCType = field_info.GetSqlCType();

  int cbTerm = 0;
  if (wSqlCType == SQL_C_CHAR)
    cbTerm = sizeof(CHAR);
  else if (wSqlCType == SQL_C_WCHAR)
    cbTerm = sizeof(WCHAR);

  char* pbProviderValue = NULL;
  DBLENGTH cbProviderLength = 0;
  DBSTATUS dwProviderStatus = DBSTATUS_S_OK;
  AutoRelease<char, ComMemFree> data;
  //AutoRelease<OLECHAR, SysStrFree> bstr;
  HRESULT hr;

  LOG (("DataTransferHandler::GetData () binding.wType=%d name=%S field_type=%d isLong=%d\n",
	(int) binding.wType,
	(wchar_t *) field_info.GetName ().c_str(),
	(int) field_info.GetOledbType (),
	(int) field_info.IsLong ()));
  if (binding.wType == DBTYPE_IUNKNOWN && field_info.GetOledbType() != DBTYPE_IUNKNOWN)
    {
      assert(field_info.IsLong());
      assert(binding.dwMemOwner != DBMEMOWNER_PROVIDEROWNED);

      const IID* piid = &IID_IUnknown;
      if (binding.pObject != NULL)
	{
	  if (binding.pObject->dwFlags & STGM_WRITE)
	    {
	      if (pdwConsumerStatus != NULL)
		*pdwConsumerStatus = DBSTATUS_E_BADACCESSOR;
	      return S_FALSE;
	    }
	  piid = &binding.pObject->iid;
	}
      if (pgd == NULL)
	{
	  if (pdwConsumerStatus != NULL)
	    *pdwConsumerStatus = DBSTATUS_E_CANTCONVERTVALUE;
	  return S_FALSE;
	}

      IUnknown** ppUnk = pbConsumerValue != NULL ? ((IUnknown**) pbConsumerValue) : NULL;

      hr = pgd->CreateStreamObject(iRecordID, binding.iOrdinal, wSqlCType, *piid, ppUnk);
      if (FAILED(hr))
	{
	  if (hr == E_OUTOFMEMORY || hr == DB_E_OBJECTOPEN)
	    {
	      if (pdwConsumerStatus != NULL)
		*pdwConsumerStatus = DBSTATUS_E_CANTCREATE;
	      return S_FALSE;
	    }
	  if (hr == DB_E_COLUMNUNAVAILABLE)
	    {
	      if (pdwConsumerStatus != NULL)
		*pdwConsumerStatus = DBSTATUS_E_UNAVAILABLE;
	      return S_FALSE;
	    }
	  if (pdwConsumerStatus != NULL)
	    *pdwConsumerStatus = DBSTATUS_E_CANTCONVERTVALUE;
	  return hr;
	}
      if (hr == S_FALSE)
	{
	  if (pdwConsumerStatus != NULL)
	    *pdwConsumerStatus = DBSTATUS_S_ISNULL;
	  return S_OK;
	}

      if (pdwConsumerStatus != NULL)
	*pdwConsumerStatus = DBSTATUS_S_OK;
      if (pcbConsumerLength != NULL)
	*pcbConsumerLength = sizeof(IUnknown*);
      return S_OK;
    }
  else if (field_info.IsLong())
    {
      assert(binding.dwMemOwner != DBMEMOWNER_PROVIDEROWNED);

      if (pgd == NULL)
	{
	  if (pdwConsumerStatus != NULL)
	    *pdwConsumerStatus = DBSTATUS_E_CANTCONVERTVALUE;
	  return S_FALSE;
	}

      hr = pgd->ResetLongData(iRecordID, binding.iOrdinal);
      if (FAILED(hr))
	{
	  if (hr == DB_E_OBJECTOPEN || hr == DB_E_COLUMNUNAVAILABLE)
	    {
	      if (pdwConsumerStatus != NULL)
		*pdwConsumerStatus = DBSTATUS_E_UNAVAILABLE;
	      return S_FALSE;
	    }
	  if (pdwConsumerStatus != NULL)
	    *pdwConsumerStatus = DBSTATUS_E_CANTCONVERTVALUE;
	  return hr;
	}

      bool fBypassConversion = false;
      if (binding.wType == DBTYPE_BYTES || binding.wType == (DBTYPE_BYTES | DBTYPE_BYREF))
	{
	  fBypassConversion = true;
	  wSqlCType = SQL_C_BINARY;
	}
      else if (binding.wType == DBTYPE_STR || binding.wType == (DBTYPE_STR | DBTYPE_BYREF))
	{
	  fBypassConversion = true;
	  wSqlCType = SQL_C_CHAR;
	}
      else if (binding.wType == DBTYPE_WSTR || binding.wType == (DBTYPE_WSTR | DBTYPE_BYREF))
	{
	  fBypassConversion = true;
	  wSqlCType = SQL_C_WCHAR;
	}
      // TODO: DBTYPE_BSTR and (DBTYPE_BSTR | DBTYPE_BYREF)

      bool fIsReferenceType = (binding.wType & DBTYPE_BYREF) != 0 /*|| binding.wType == DBTYPE_BSTR*/;
      bool fUseConsumerMemory = fBypassConversion && !fIsReferenceType && (pbConsumerValue != NULL);

      bool fKeepAllData = true;
      if (fUseConsumerMemory || (fBypassConversion && (pbConsumerValue == NULL)))
	fKeepAllData = false;
      LOG (("DataTransferHandler::GetData () keepAllData=%d, fIsReferenceType=%d, fUseConsumerMemory=%d, fBypassConversion=%d, fIsReferenceType=%d\n",
	    (int) fKeepAllData,
	    (int) fIsReferenceType,
	    (int) fUseConsumerMemory,
	    (int) fBypassConversion,
	    (int) fIsReferenceType));

      // Check for a null.
      SQLLEN cb;
      char dummy[1];
      hr = pgd->GetLongData(iRecordID, binding.iOrdinal, wSqlCType, dummy, 0, cb);
      if (FAILED(hr))
	{
	  if (pdwConsumerStatus != NULL)
	    *pdwConsumerStatus = DBSTATUS_E_CANTCONVERTVALUE;
	  return hr;
	}
      if (cb == SQL_NULL_DATA)
	{
	  if (pdwConsumerStatus != NULL)
	    *pdwConsumerStatus = DBSTATUS_S_ISNULL;
	  return S_OK;
	}

      if (!pbConsumerValue && (pcbConsumerLength == NULL || cb != SQL_NO_TOTAL))
	{
	  LOG (("DataTransferHandler::GetData () !pbConsumerData cb=%lu\n",
		(unsigned long) cb));
	  if (pdwConsumerStatus != NULL)
	    *pdwConsumerStatus = DBSTATUS_S_OK;
	  if (pcbConsumerLength != NULL)
	    *pcbConsumerLength = cb;
	  return S_OK;
	}

      if (fUseConsumerMemory && binding.cbMaxLen > (DBLENGTH) cbTerm)
	{
	  LOG (("DataTransferHandler::GetData () useConsumerMemory cbMaxLen=%lu\n",
		(unsigned long) binding.cbMaxLen));
	  hr = pgd->GetLongData(iRecordID, binding.iOrdinal, wSqlCType, pbConsumerValue, binding.cbMaxLen, cb);
	  if (FAILED(hr))
	    {
	      if (pdwConsumerStatus != NULL)
		*pdwConsumerStatus = DBSTATUS_E_CANTCONVERTVALUE;
	      return hr;
	    }
	  if (cb > 9999)
	    LOG (("DataTransferHandler::GetData () wchar_t[9999]=%d wchar_t[10000]=%d\n",
		  (int) ((wchar_t *)pbConsumerValue)[9999],
		  (int) ((wchar_t *)pbConsumerValue)[10000]));
	  if (cb != SQL_NO_TOTAL)
	    {
	      if (pdwConsumerStatus != NULL)
		*pdwConsumerStatus = ((ULONG) cb + cbTerm) > binding.cbMaxLen ? DBSTATUS_S_TRUNCATED : DBSTATUS_S_OK;
	      if (pcbConsumerLength != NULL)
		{
		  *pcbConsumerLength = (((ULONG) cb + cbTerm) > binding.cbMaxLen) ?
		      (binding.cbMaxLen - cbTerm) :
			  cb;
		  LOG (("DataTransferHandler::GetData () consumer_len=%lu\n",
			(unsigned long *) *pcbConsumerLength));
		}
	      return S_OK;
	    }

	  cbProviderLength = binding.cbMaxLen - cbTerm;
	  /*if (wSqlCType == SQL_C_WCHAR)
	    cbProviderLength -= cbProviderLength % sizeof(WCHAR);*/
	}

      DBLENGTH cbMaxSize = 8172;
      char* pNewData = (char*) CoTaskMemAlloc(cbMaxSize);
      if (pNewData == NULL)
	{
	  if (pdwConsumerStatus != NULL)
	    *pdwConsumerStatus = DBSTATUS_E_CANTCREATE;
	  return S_FALSE;
	}
      data.Set(pNewData);

      for(;;)
	{
	  DBLENGTH cbOffset = fKeepAllData ? (cbProviderLength > (DBLENGTH) cbTerm ? (cbProviderLength - (DBLENGTH) cbTerm) : 0) : 0;
	  LOG (("DataTransferHandler::GetData GetLongData () wSqlCType=%d, cbOffset=%lu, cbMaxSize=%lu\n",
		(int) wSqlCType,
		(unsigned long) cbOffset,
		(unsigned long) cbMaxSize));
	  hr = pgd->GetLongData(iRecordID, binding.iOrdinal, wSqlCType, data + cbOffset, cbMaxSize - cbOffset, cb);
	  LOG (("DataTransferHandler::GetData GetLongData () after hr=%d cb=%lu\n",
		(int) hr,
		(unsigned long) cb));
	  if (FAILED(hr))
	    {
	      if (pdwConsumerStatus != NULL)
		*pdwConsumerStatus = DBSTATUS_E_CANTCONVERTVALUE;
	      return hr;
	    }
	  if (hr == S_FALSE)
	    {
	      cb = 0;
	      break;
	    }
	  if (cb != SQL_NO_TOTAL)
	    {
	      if (!fKeepAllData)
		{
		  cbProviderLength += cb;
		  cb = 0;
		  break;
		}
	      else
		{
		  if (((ULONG) cb) > cbMaxSize - cbOffset - cbTerm)
		    cbProviderLength += cbMaxSize - cbOffset - cbTerm;
		  else
		    cbProviderLength += cb;
		}
	    }
	  else
	    cbProviderLength += cbMaxSize - cbOffset - cbTerm;

	  if (fKeepAllData)
	    {
	      cbMaxSize *= 2;
	      pNewData = (char*) CoTaskMemRealloc(data.Get(), cbMaxSize);
	      if (pNewData == NULL)
		{
		  if (pdwConsumerStatus != NULL)
		    *pdwConsumerStatus = DBSTATUS_E_CANTCREATE;
		  return S_FALSE;
		}
	      data.Set(pNewData);
	    }
	}

      if (fUseConsumerMemory)
	{
	  cbProviderLength += cb;
	  if (pdwConsumerStatus != NULL)
	    *pdwConsumerStatus = DBSTATUS_S_TRUNCATED;
	  if (pcbConsumerLength != NULL)
	    *pcbConsumerLength = cbProviderLength;
	  return S_OK;
	}

      if (fKeepAllData)
	{
	  DBLENGTH cbNewSize = cbProviderLength + cb;
	  if (cbNewSize > cbMaxSize || (cbNewSize != cbMaxSize && fBypassConversion))
	    {
	      assert(fIsReferenceType);

	      pNewData = (char*) CoTaskMemRealloc(data.Get(), cbNewSize);
	      if (pNewData == NULL)
		{
		  if (pdwConsumerStatus != NULL)
		    *pdwConsumerStatus = DBSTATUS_E_CANTCREATE;
		  return S_FALSE;
		}
	      cbMaxSize = cbNewSize;
	      data.Set(pNewData);
	    }
	  if (cb > 0)
	    {
	      DBLENGTH cbOffset = fKeepAllData ? cbProviderLength : 0;
	      LOG (("DataTransferHandler::GetData () GetLongData2 wSqlCType=%d, cbProviderLength=%lu, cbMaxSize=%lu\n",
		    (int) wSqlCType,
		    (unsigned long) cbProviderLength,
		    (unsigned long) cbMaxSize));
	      hr = pgd->GetLongData(iRecordID, binding.iOrdinal, wSqlCType, data + cbProviderLength, cbMaxSize - cbProviderLength, cb);
	      LOG (("DataTransferHandler::GetData GetLongData2 () after hr=%d cb=%lu\n",
		    (int) hr,
		    (unsigned long) cb));
	      if (FAILED(hr))
		{
		  if (pdwConsumerStatus != NULL)
		    *pdwConsumerStatus = DBSTATUS_E_CANTCONVERTVALUE;
		  return hr;
		}
	      cbProviderLength += cb;
	    }
	}

      if (fBypassConversion)
	{
	  LOGCALL (("DataTransferHandler::GetData () fBypassConversion cbProviderLength=%lu\n",
		(unsigned long) cbProviderLength));
	  if (pdwConsumerStatus != NULL)
	    *pdwConsumerStatus = DBSTATUS_S_OK;
	  if (pcbConsumerLength != NULL)
	    *pcbConsumerLength = cbProviderLength;
	  if (pbConsumerValue != NULL)
	    {
	      assert(fIsReferenceType);
	      *((void **) pbConsumerValue) = data.GiveUp();
	    }
	  return S_OK;
	}

      pbProviderValue = data.Get();
    }
  else
    {
      pbProviderValue = pbProviderData + field_info.GetInternalOffset();
      cbProviderLength = info.GetFieldLength(pbProviderData, iField);

#if DEBUG
      LogFieldData((ULONG)binding.iOrdinal, field_info, pbProviderValue, (LONG)cbProviderLength);
#endif

      if (cbProviderLength == SQL_NULL_DATA)
	{
	  if (pdwConsumerStatus != NULL)
	    *pdwConsumerStatus = DBSTATUS_S_ISNULL;
	  return S_OK;
	}
      if (cbProviderLength == SQL_COLUMN_IGNORE)
	{
	  if (pdwConsumerStatus != NULL)
	    *pdwConsumerStatus = DBSTATUS_E_UNAVAILABLE;
	  return S_FALSE;
	}

      // fix up for Virtuoso sometimes not returning correct length.
      if (field_info.IsFixed())
	cbProviderLength = field_info.GetInternalLength();

      if ((cbProviderLength + cbTerm) > field_info.GetInternalLength())
	dwProviderStatus = DBSTATUS_S_TRUNCATED;

      if (binding.dwMemOwner == DBMEMOWNER_PROVIDEROWNED)
	{
	  assert(binding.wType == (field_info.GetInternalDBType() | DBTYPE_BYREF));
	  LOG(("Provider-owned memory.\n"));

	  if (pdwConsumerStatus != NULL)
	    *pdwConsumerStatus = dwProviderStatus;
	  if (pcbConsumerLength != NULL)
	    *pcbConsumerLength = cbProviderLength;
	  if (pbConsumerValue != NULL)
	    *((char**) pbConsumerValue) = pbProviderValue;
	  return S_OK;
	}

      if (binding.wType == field_info.GetInternalDBType())
	{
	  LOG(("Copy data.\n"));
	  size_t cbLength = cbProviderLength;
	  if (!field_info.IsFixed() && cbLength + cbTerm > binding.cbMaxLen)
	    {
	      dwProviderStatus = DBSTATUS_S_TRUNCATED;
	      cbLength = binding.cbMaxLen - cbTerm;
	      if (wSqlCType == SQL_C_WCHAR)
		cbLength -= cbLength % sizeof(WCHAR);
	    }

	  if (pdwConsumerStatus != NULL)
	    *pdwConsumerStatus = dwProviderStatus;
	  if (pcbConsumerLength != NULL)
	    *pcbConsumerLength = cbProviderLength;
	  if (pbConsumerValue != NULL)
	    {
	      memcpy(pbConsumerValue, pbProviderValue, cbLength);
	      for (int i = 0; i < cbTerm; i++)
		pbConsumerValue[cbLength + i] = 0;
	    }
	  return S_OK;
	}
    }

  LOG(("Convert data.\n"));

  DBSTATUS dwConsumerStatus;
  DBLENGTH cbConsumerLength;
  hr = m_pIDataConvert->DataConvert(field_info.GetInternalDBType(), binding.wType,
				    cbProviderLength, &cbConsumerLength,
				    pbProviderValue, pbConsumerValue, binding.cbMaxLen,
				    dwProviderStatus, &dwConsumerStatus,
				    binding.bPrecision, binding.bScale,
				    DBDATACONVERT_DEFAULT);
  if (FAILED(hr))
    {
      TRACE((__FILE__, __LINE__,
	     "DataConvert(wSrcType=%d, wDstType=%d, cbSrcLength=%d, cbDstLength=%d, cbDstMaxLength=%d, "
	     "dbsSrcStatus=%d, dbsStatus=%d, bPrecision=%d, bScale=%d) failed.\n",
	     field_info.GetInternalDBType(), binding.wType, cbProviderLength, cbConsumerLength,
	     binding.cbMaxLen, dwProviderStatus, dwConsumerStatus, binding.bPrecision, binding.bScale));
      if (hr == E_OUTOFMEMORY)
	dwConsumerStatus = DBSTATUS_E_CANTCREATE;
      else if (hr == DB_E_BADBINDINFO)
	dwConsumerStatus = DBSTATUS_E_BADACCESSOR;
      else if (hr == DB_E_DATAOVERFLOW)
	dwConsumerStatus = DBSTATUS_E_DATAOVERFLOW;
      else
	dwConsumerStatus = DBSTATUS_E_CANTCONVERTVALUE;
    }
  if (pdwConsumerStatus != NULL)
    *pdwConsumerStatus = dwConsumerStatus;
  if (pcbConsumerLength != NULL)
    *pcbConsumerLength = cbConsumerLength;

  if (dwConsumerStatus != DBSTATUS_S_OK && dwConsumerStatus != DBSTATUS_S_TRUNCATED)
    return S_FALSE;
  return S_OK;
}

HRESULT
DataTransferHandler::SetData(
  const DataRecordInfo& info,
  SetDataHandler* psd,
  HROW iRecordID,
  char* pbProviderData,
  const DataAccessor& accessor,
  DBCOUNTITEM iBinding,
  char* pbConsumerData,
  bool fIsParameter
)
{
  assert(pbProviderData != NULL);
  assert(pbConsumerData != NULL);
  assert(m_pIDataConvert != NULL);

  const DBBINDING& binding = accessor.GetBinding (iBinding);

  char* pbConsumerValue = NULL;
  DBSTATUS* pdwConsumerStatus = NULL;
  DBLENGTH* pcbConsumerLength = NULL;

  if (binding.dwPart & DBPART_VALUE)
    pbConsumerValue = pbConsumerData + binding.obValue;
  if (binding.dwPart & DBPART_LENGTH)
    pcbConsumerLength = (DBLENGTH*) (pbConsumerData + binding.obLength);
  if (binding.dwPart & DBPART_STATUS)
    pdwConsumerStatus = (DBSTATUS*) (pbConsumerData + binding.obStatus);

  DBBINDSTATUS dwBindStatus = MetadataValidateBinding(info, binding);
  if (dwBindStatus != DBBINDSTATUS_OK)
    {
      if (pdwConsumerStatus != NULL)
	*pdwConsumerStatus = DBSTATUS_E_BADACCESSOR;
      return S_FALSE;
    }

  ULONG iField = info.OrdinalToIndex(binding.iOrdinal);
  const DataFieldInfo& field_info = info.GetFieldInfo(iField);
  assert(field_info.IsSet());

  if (fIsParameter)
    {
      DBPARAMFLAGS flags = field_info.GetFlags();
      if (!(flags & DBPARAMFLAGS_ISINPUT))
	return S_OK;
    }

  int cbTerm = 0;
  if (field_info.GetSqlCType() == SQL_C_CHAR)
    cbTerm = sizeof(CHAR);
  else if (field_info.GetSqlCType() == SQL_C_WCHAR)
    cbTerm = sizeof(WCHAR);

  HRESULT hr;
  DBLENGTH cbConsumerLength = 0;
  DBDATACONVERT dwConvertFlags = DBDATACONVERT_SETDATABEHAVIOR;
  if (pcbConsumerLength != NULL)
    cbConsumerLength = *pcbConsumerLength;
  else
    dwConvertFlags |= DBDATACONVERT_LENGTHFROMNTS;

  DBSTATUS dwConsumerStatus = DBSTATUS_S_OK;
  if (pdwConsumerStatus != NULL)
    {
      dwConsumerStatus = *pdwConsumerStatus;
      if (dwConsumerStatus != DBSTATUS_S_OK
	  && dwConsumerStatus != DBSTATUS_S_ISNULL
	  && dwConsumerStatus != DBSTATUS_S_DEFAULT
	  && (dwConsumerStatus != DBSTATUS_S_IGNORE || fIsParameter))
	{
	  if (pdwConsumerStatus != NULL)
	    *pdwConsumerStatus = DBSTATUS_E_BADSTATUS;
	  return S_FALSE;
	}
    }

  char* pbProviderValue = pbProviderData + field_info.GetInternalOffset();

  if (dwConsumerStatus == DBSTATUS_S_ISNULL)
    info.SetFieldLength(pbProviderData, iField, SQL_NULL_DATA);
  else if (dwConsumerStatus == DBSTATUS_S_DEFAULT)
    info.SetFieldLength(pbProviderData, iField, SQL_DEFAULT_PARAM);
  else if (dwConsumerStatus == DBSTATUS_S_IGNORE)
    info.SetFieldLength(pbProviderData, iField, SQL_COLUMN_IGNORE);
  else if (pbConsumerValue == NULL)
    {
      if (pdwConsumerStatus != NULL)
	*pdwConsumerStatus = DBSTATUS_E_UNAVAILABLE;
      return S_FALSE;
    }
  else if (field_info.IsLong())
    {
      if (psd == NULL)
	{
	  if (pdwConsumerStatus != NULL)
	    *pdwConsumerStatus = DBSTATUS_E_CANTCONVERTVALUE;
	  return S_FALSE;
	}

      SQLSMALLINT wSqlCType = field_info.GetSqlCType();
      if (binding.wType == DBTYPE_IUNKNOWN)
	{
	  IUnknown* pIUnknown = *(IUnknown**) pbConsumerValue;
	  if (pIUnknown == NULL)
	    {
	      if (pdwConsumerStatus != NULL)
		*pdwConsumerStatus = DBSTATUS_E_UNAVAILABLE;
	      return S_FALSE;
	    }
	  AutoInterface<ISequentialStream> pISequentialStream;
	  hr = pISequentialStream.QueryInterface(pIUnknown, IID_ISequentialStream);
	  if (FAILED(hr))
	    {
	      if (pdwConsumerStatus != NULL)
		*pdwConsumerStatus = DBSTATUS_E_UNAVAILABLE;
	      return S_FALSE;
  	    }
	}
      else
	{
	  // TODO: DBTYPE_BSTR and (DBTYPE_BSTR | DBTYPE_BYREF)
	  if (binding.wType == DBTYPE_BYTES || binding.wType == (DBTYPE_BYTES | DBTYPE_BYREF))
	    wSqlCType = SQL_C_BINARY;
	  else if (binding.wType == DBTYPE_STR || binding.wType == (DBTYPE_STR | DBTYPE_BYREF))
	    wSqlCType = SQL_C_CHAR;
	  else if (binding.wType == DBTYPE_WSTR || binding.wType == (DBTYPE_WSTR | DBTYPE_BYREF))
	    wSqlCType = SQL_C_WCHAR;
	  else
	    {
	      if (pdwConsumerStatus != NULL)
		*pdwConsumerStatus = DBSTATUS_E_BADACCESSOR;
	      return S_FALSE;
	    }
	}

      hr = psd->SetDataAtExec(iRecordID, binding.iOrdinal, wSqlCType, iBinding);
      if (FAILED(hr))
	{
	  if (pdwConsumerStatus != NULL)
	    *pdwConsumerStatus = DBSTATUS_E_UNAVAILABLE;
	  return S_FALSE;
	}
    }
  else
    {
      DBLENGTH cbProviderLength;

      hr = m_pIDataConvert->DataConvert(binding.wType, field_info.GetInternalDBType(),
					cbConsumerLength, &cbProviderLength,
					pbConsumerValue,
					pbProviderValue, field_info.GetInternalLength(),
					dwConsumerStatus, &dwConsumerStatus,
					field_info.GetOledbPrecision(), field_info.GetOledbScale(),
					dwConvertFlags);
      if (FAILED(hr))
	{
	  TRACE((__FILE__, __LINE__,
		 "DataConvert(): Cannot convert parameter value.\n"));
	  if (hr == E_OUTOFMEMORY)
	    dwConsumerStatus = DBSTATUS_E_CANTCREATE;
	  else if (hr == DB_E_BADBINDINFO)
	    dwConsumerStatus = DBSTATUS_E_BADACCESSOR;
	  else if (hr == DB_E_DATAOVERFLOW)
	    dwConsumerStatus = DBSTATUS_E_DATAOVERFLOW;
	  else
	    dwConsumerStatus = DBSTATUS_E_CANTCONVERTVALUE;
	}

      info.SetFieldLength(pbProviderData, iField, (LONG)cbProviderLength);
    }

  if (pdwConsumerStatus != NULL)
    *pdwConsumerStatus = dwConsumerStatus;

  if (dwConsumerStatus != DBSTATUS_S_OK && dwConsumerStatus != DBSTATUS_S_TRUNCATED)
    return S_FALSE;
  return S_OK;
}

HRESULT
DataTransferHandler::SetDataAtExec(
  const DataRecordInfo& info,
  SetDataHandler* psd,
  const DataAccessor& accessor,
  char* pbConsumerData,
  bool fIsParameter
)
{
  assert(psd != NULL);

  for (;;)
    {
      HROW iRecordID;
      DBCOUNTITEM iBinding = -1;
      HRESULT hr = psd->GetDataAtExec(iRecordID, iBinding);
      if (FAILED(hr))
	return hr;
      if (hr == S_FALSE)
	break;

      const DBBINDING& binding = accessor.GetBinding (iBinding);

      char* pbConsumerValue = NULL;
      DBSTATUS* pdwConsumerStatus = NULL;
      DBLENGTH* pcbConsumerLength = NULL;

      if (binding.dwPart & DBPART_VALUE)
	pbConsumerValue = pbConsumerData + binding.obValue;
      if (binding.dwPart & DBPART_LENGTH)
	pcbConsumerLength = (DBLENGTH*) (pbConsumerData + binding.obLength);
      if (binding.dwPart & DBPART_STATUS)
	pdwConsumerStatus = (DBSTATUS*) (pbConsumerData + binding.obStatus);

      ULONG iField = info.OrdinalToIndex(binding.iOrdinal);
      const DataFieldInfo& field_info = info.GetFieldInfo(iField);

      DBLENGTH cbConsumerLength = 0;
      DBDATACONVERT dwConvertFlags = 0 /*DBDATACONVERT_SETDATABEHAVIOR*/;
      if (pcbConsumerLength != NULL)
	cbConsumerLength = *pcbConsumerLength;
      else
	dwConvertFlags |= DBDATACONVERT_LENGTHFROMNTS;

      DBSTATUS dwConsumerStatus = DBSTATUS_S_OK;
      if (pdwConsumerStatus != NULL)
	dwConsumerStatus = *pdwConsumerStatus;

      if (fIsParameter)
	pbConsumerValue += iRecordID * accessor.GetRowSize ();

      ULONG cb;
      char buffer[2000];
      if (binding.wType == DBTYPE_IUNKNOWN)
	{
	  AutoInterface<IUnknown> pIUnknown(*(IUnknown**) pbConsumerValue, false);
	  assert(pIUnknown != NULL);

	  AutoInterface<ISequentialStream> pISequentialStream;
	  HRESULT hr = pISequentialStream.QueryInterface(pIUnknown.Get(), IID_ISequentialStream);
	  if (FAILED(hr))
	    {
	      if (pdwConsumerStatus != NULL)
		*pdwConsumerStatus = DBSTATUS_E_CANTCONVERTVALUE;
	      continue;
	    }

	  for (;;)
	    {
	      HRESULT hr = pISequentialStream->Read(buffer, sizeof buffer, &cb);
	      if (FAILED(hr))
		{
		  if (pdwConsumerStatus != NULL)
		    *pdwConsumerStatus = DBSTATUS_E_CANTCONVERTVALUE;
		  break;
		}
	      if (hr == S_FALSE)
		break;

	      hr = psd->PutDataAtExec(buffer, cb);
	      if (FAILED(hr))
		{
		  if (pdwConsumerStatus != NULL)
		    *pdwConsumerStatus = DBSTATUS_E_CANTCONVERTVALUE;
		  break;
		}
	    }
	}
      else
	{
	  char* pData = NULL;
	  if (binding.wType & DBTYPE_BYREF)
	    pData = *((char**) pbConsumerValue);
	  else
	    pData = (char*) pbConsumerValue;

	  ULONG cbData = 0;
	  if (dwConvertFlags & DBDATACONVERT_LENGTHFROMNTS)
	    cbData = SQL_NTS;
	  else
	    cbData = (ULONG)cbConsumerLength;

	  HRESULT hr = psd->PutDataAtExec(pData, cbData);
	  if (FAILED(hr))
	    {
	      if (pdwConsumerStatus != NULL)
		*pdwConsumerStatus = DBSTATUS_E_CANTCONVERTVALUE;
	      continue;
	    }
	}
    }

  // TODO: in case some parameters failed return DB_[SE]_ERRORSOCURRED
  // or cancel execution at all.
  return S_OK;
}

#if DEBUG
void
DataTransferHandler::LogFieldData(
  ULONG iFieldOrdinal,
  const DataFieldInfo& info,
  const char* pbValue,
  LONG cbLength
)
{
  LOG(("field: %d, buffer: %x, ", iFieldOrdinal, pbValue));

  switch (cbLength)
    {
    case SQL_NULL_DATA:
      LOGFLAT(("value: NULL\n"));
      return;
    case SQL_DEFAULT_PARAM:
      LOGFLAT(("value: DEFAULT\n"));
      return;
    case SQL_COLUMN_IGNORE:
      LOGFLAT(("value: IGNORE\n"));
      return;
    case SQL_DATA_AT_EXEC:
      LOGFLAT(("value: DATA_AT_EXEC\n"));
      return;
    }

  LOGFLAT(("length: %d, ", cbLength));
  switch (info.GetInternalDBType())
    {
    case DBTYPE_I1:
      LOGFLAT(("value(I1): %d\n", *(CHAR*) pbValue));
      break;
    case DBTYPE_UI1:
      LOGFLAT(("value(UI1): %d\n", *(BYTE*) pbValue));
      break;
    case DBTYPE_I2:
      LOGFLAT(("value(I2): %d\n", *(SHORT*) pbValue));
      break;
    case DBTYPE_UI2:
      LOGFLAT(("value(UI2): %d\n", *(USHORT*) pbValue));
      break;
    case DBTYPE_I4:
      LOGFLAT(("value(I4): %d\n", *(LONG*) pbValue));
      break;
    case DBTYPE_UI4:
      LOGFLAT(("value(UI4): %d\n", *(ULONG*) pbValue));
      break;
    case DBTYPE_I8:
      LOGFLAT(("value(I8): I8\n"));
      break;
    case DBTYPE_CY:
      LOGFLAT(("value: %d\n", *(LONG*) pbValue));
      break;
    case DBTYPE_UI8:
      LOGFLAT(("value(UI8): UI8\n"));
      break;
    case DBTYPE_R4:
      LOGFLAT(("value(R4): %f\n", *(FLOAT*) pbValue));
      break;
    case DBTYPE_R8:
      LOGFLAT(("value(R8): %f\n", *(DOUBLE*) pbValue));
      break;
    case DBTYPE_BOOL:
      LOGFLAT(("value(BOOL): %d\n", *(VARIANT_BOOL*) pbValue));
      break;
    case DBTYPE_STR:
      LOGFLAT(("value(STR): %.*s\n", cbLength, pbValue));
      break;
    case DBTYPE_WSTR:
      LOGFLAT(("value(WSTR): %.*S\n", (int) (cbLength / sizeof(SQLWCHAR)), pbValue));
      break;
    case DBTYPE_BYTES:
      LOGFLAT(("value: BYTES\n"));
      break;
    case DBTYPE_DBDATE:
      LOGFLAT(("value: %04d-%02d-%02d\n",
	       ((DBDATE*) pbValue)->year, ((DBDATE*) pbValue)->month, ((DBDATE*) pbValue)->day));
      break;
    case DBTYPE_DBTIME:
      LOGFLAT(("value: %02d:%02d:%02d\n",
	       ((DBTIME*) pbValue)->hour, ((DBTIME*) pbValue)->minute, ((DBTIME*) pbValue)->second));
      break;
    case DBTYPE_DBTIMESTAMP:
      LOGFLAT(("value: %04d-%02d-%02d %02d:%02d:%02d.%06d\n",
	       ((DBTIMESTAMP*) pbValue)->year, ((DBTIMESTAMP*) pbValue)->month, ((DBTIMESTAMP*) pbValue)->day,
	       ((DBTIMESTAMP*) pbValue)->hour, ((DBTIMESTAMP*) pbValue)->minute, ((DBTIMESTAMP*) pbValue)->second,
	       ((DBTIMESTAMP*) pbValue)->fraction));
      break;
    case DBTYPE_NUMERIC:
      LOGFLAT(("value: sign = %d, scale = %d, precision = %d, value =",
	       ((DB_NUMERIC*) pbValue)->sign, ((DB_NUMERIC*) pbValue)->scale, ((DB_NUMERIC*) pbValue)->precision));
      for (int i = 0; i < 16; i++)
	{
	  LOGFLAT((" %02x", ((DB_NUMERIC*) pbValue)->val[i]));
	}
      LOGFLAT(("\n"));
      break;
    }
}
#endif

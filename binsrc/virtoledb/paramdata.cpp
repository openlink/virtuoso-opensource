/*  paramdata.cpp
 *
 *  $Id$
 *  
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *  
 *  Copyright (C) 1998-2016 OpenLink Software
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
#include "dataobj.h"
#include "session.h"
#include "paramdata.h"
#include "error.h"

#define MAX_PARAM_NAME_SIZE 127

/**********************************************************************/
/* ParameterInfo                                                      */

HRESULT
ParameterInfo::InitParameterInfo(
  const SQLWCHAR* name,
  SQLSMALLINT sql_type,
  SQLUINTEGER field_size,
  SQLSMALLINT decimal_digits,
  SQLSMALLINT nullable,
  SQLSMALLINT param_type
)
{
  HRESULT hr = SetNativeFieldInfo (sql_type, field_size, decimal_digits);
  if (FAILED(hr))
    return hr;

  // This method is useed if the command object is prepared and the parameter info is
  // obtained from ODBC. It could be called after InitParameterInfo(const DBPARAMBINDINFO&)
  // which is used if an app itself provides parameter info. So it must not blindly reset
  // the info provided by the app. [Currently Virtuoso ODBC doesn't provide parameter name
  // and io type info at all.]

  if (name != NULL)
    {
      hr = SetName(name);
      if (FAILED(hr))
	return hr;
    }

  DBPARAMFLAGS flags = GetFlags();
  if (IsLong())
    flags |= DBPARAMFLAGS_ISLONG;
  else
    flags &= ~DBPARAMFLAGS_ISLONG;
  if (IsUnsigned())
    flags &= ~DBPARAMFLAGS_ISSIGNED;
  else
    flags |= DBPARAMFLAGS_ISSIGNED;
  if (nullable)
    flags |= DBPARAMFLAGS_ISNULLABLE;
  else
    flags &= ~DBPARAMFLAGS_ISNULLABLE;
  if (param_type != SQL_PARAM_TYPE_UNKNOWN)
    {
      if (param_type == SQL_PARAM_INPUT)
	flags |= DBPARAMFLAGS_ISINPUT;
      else if (param_type == SQL_PARAM_INPUT_OUTPUT)
	flags |= DBPARAMFLAGS_ISINPUT | DBPARAMFLAGS_ISOUTPUT;
      else if (param_type == SQL_PARAM_OUTPUT || param_type == SQL_RETURN_VALUE)
	flags |= DBPARAMFLAGS_ISOUTPUT;
    }
  SetFlags(flags);
  return S_OK;
}

HRESULT
ParameterInfo::InitParameterInfo(const DBPARAMBINDINFO& param_bind_info)
{
  HRESULT hr = SetNativeFieldInfo (
    param_bind_info.pwszDataSourceType,
    param_bind_info.ulParamSize,
    param_bind_info.bPrecision,
    param_bind_info.bScale);
  if (FAILED(hr))
    return hr;

  hr = SetName(param_bind_info.pwszName);
  if (FAILED(hr))
    return hr;

  DBPARAMFLAGS flags = param_bind_info.dwFlags;
  if (IsLong())
    flags |= DBPARAMFLAGS_ISLONG;
  if (!IsUnsigned())
    flags |= DBPARAMFLAGS_ISSIGNED;
  SetFlags(flags);
  return S_OK;
}

HRESULT
ParameterInfo::InitSchemaParameterInfo(SQLSMALLINT sql_type, SQLINTEGER field_size, DBTYPE oledb_type)
{
  LOGCALL (("ParameterInfo::InitSchemaParameterInfo () IsSet() = %d\n",
	(int) IsSet ()));
  HRESULT hr = SetNativeFieldInfo (sql_type, field_size, 0);
  if (FAILED(hr))
    {
      LOG (("ParameterInfo::InitSchemaParameterInfo () SetNativeFieldInfo returned error\n"));
      return hr;
    }
  LOG (("ParameterInfo::InitSchemaParameterInfo () IsSet() = %d\n",
	(int) IsSet ()));
  hr = Optimize (oledb_type);
  if (FAILED(hr))
    return hr;

  SetFlags(DBPARAMFLAGS_ISINPUT | DBPARAMFLAGS_ISNULLABLE);
  return S_OK;
}

HRESULT
ParameterInfo::InitDefaultParameterInfo(const DBBINDING& binding)
{
  DBTYPE type = (binding.wType & ~DBTYPE_BYREF);

  SQLSMALLINT sql_type = SQL_UNKNOWN_TYPE;
  SQLUINTEGER field_size = 0;
  SQLSMALLINT decimal_digits = 0;
  switch (type)
    {
    case DBTYPE_I2:
      sql_type = SQL_SMALLINT;
      break;

    case DBTYPE_I4:
      sql_type = SQL_INTEGER;
      break;

    case DBTYPE_R4:
      sql_type = SQL_REAL;
      break;

    case DBTYPE_R8:
      sql_type = SQL_DOUBLE;
      break;

    case DBTYPE_NUMERIC:
    case DBTYPE_VARNUMERIC:
      sql_type = SQL_NUMERIC;
      if (binding.dwPart & DBPART_VALUE)
	{
	  field_size = binding.bPrecision;
	  decimal_digits = binding.bScale;
	}
      break;

    case DBTYPE_STR:
      sql_type = SQL_CHAR;
      if (binding.dwPart & DBPART_VALUE)
	{
	  if (binding.wType & DBTYPE_BYREF)
	    sql_type = SQL_LONGVARCHAR;
	  else
	    field_size = (SQLUINTEGER)binding.cbMaxLen;
	}
      break;

    case DBTYPE_WSTR:
      sql_type = SQL_WCHAR;
      if (binding.dwPart & DBPART_VALUE)
	{
	  if (binding.wType & DBTYPE_BYREF)
	    sql_type = SQL_WLONGVARCHAR;
	  else
	    field_size = (SQLUINTEGER)binding.cbMaxLen / 2;
	}
      break;

    case DBTYPE_BYTES:
      sql_type = SQL_BINARY;
      if (binding.dwPart & DBPART_VALUE)
	{
	  if (binding.wType & DBTYPE_BYREF)
	    sql_type = SQL_LONGVARBINARY;
	  else
	    field_size = (SQLUINTEGER)binding.cbMaxLen;
	}
      break;

    case DBTYPE_DBDATE:
      sql_type = SQL_TYPE_DATE;
      break;

    case DBTYPE_DBTIME:
      sql_type = SQL_TYPE_TIME;
      break;

    case DBTYPE_DBTIMESTAMP:
      sql_type = SQL_TYPE_TIMESTAMP;
      break;

    case DBTYPE_IUNKNOWN:
      sql_type = SQL_LONGVARCHAR;
      break;

    default:
      return ErrorInfo::Set(DB_E_PARAMUNAVAILABLE);
    }

  HRESULT hr = SetNativeFieldInfo (sql_type, field_size, decimal_digits);
  if (FAILED(hr))
    return hr;

  DBPARAMFLAGS flags = DBPARAMFLAGS_ISNULLABLE;
  if (IsLong())
    flags |= DBPARAMFLAGS_ISLONG;
  if (!IsUnsigned())
    flags |= DBPARAMFLAGS_ISSIGNED;
  SetFlags(flags);
  return S_OK;
}

void
ParameterInfo::InitDefaultParameterType(const DBBINDING& binding)
{
  DBPARAMFLAGS flags = GetFlags();
  if (binding.eParamIO & DBPARAMIO_INPUT)
    flags |= DBPARAMFLAGS_ISINPUT;
  if (binding.eParamIO & DBPARAMIO_OUTPUT)
    flags |= DBPARAMFLAGS_ISOUTPUT;
  SetFlags(flags);
}

/**********************************************************************/
/* ParameterPolicy                                                    */

ParameterPolicy::ParameterPolicy()
{
  m_cFieldInfos = 0;
  m_rgFieldInfos = NULL;
  m_cParamSets = 0;
  m_cParamSetsProcessed = 0;
  m_pbParamSets = NULL;
  m_rgParamSetStatus = NULL;
  m_fOutputParams = false;
}

ParameterPolicy::~ParameterPolicy()
{
  Release();
}

void
ParameterPolicy::Release()
{
  DataRecordInfo::Release();
  ReleaseStatusArray();

  delete [] m_rgFieldInfos;
  m_rgFieldInfos = NULL;
  m_cFieldInfos = 0;

  delete [] m_pbParamSets;
  m_pbParamSets = NULL;

  m_statement.Release();
}

void
ParameterPolicy::ReleaseStatusArray()
{
  delete [] m_rgParamSetStatus;
  m_rgParamSetStatus = NULL;
}

HRESULT
ParameterPolicy::InitInfo(DBORDINAL cParams)
{
  HRESULT hr = DataRecordInfo::Init();
  if (FAILED(hr))
    return hr;
  if (cParams == 0)
    return S_OK;

  m_rgFieldInfos = new ParameterInfo[cParams];
  if (m_rgFieldInfos == NULL)
    return ErrorInfo::Set(E_OUTOFMEMORY);
  m_cFieldInfos = cParams;

  return S_OK;
}

HRESULT
ParameterPolicy::Init(
  Statement& stmt,
  const std::vector<ParameterInfo>& param_info,
  DBCOUNTITEM cBindings,
  const DBBINDING rgBindings[],
  DB_UPARAMS cParamSets,
  DBLENGTH cbRowSize
)
{
  Release();

  m_statement = stmt;

  ULONG param;
  DBCOUNTITEM binding;
  DBORDINAL max_ordinal = param_info.size();
  for (binding = 0; binding < cBindings; binding++)
    {
      if (max_ordinal < rgBindings[binding].iOrdinal)
	max_ordinal = rgBindings[binding].iOrdinal;
    }
  if (max_ordinal == 0)
    return S_OK;

  HRESULT hr = InitInfo(max_ordinal);
  if (FAILED(hr))
    return hr;

  for (param = 0; param < param_info.size(); param++)
    m_rgFieldInfos[param] = param_info[param];

  for (binding = 0; binding < cBindings; binding++)
    {
      param = rgBindings[binding].iOrdinal - 1;
      ParameterInfo& info = m_rgFieldInfos[param];

      // If parameters info is not set guess it from the binding.
      if (!info.IsSet())
	{
	  hr = info.InitDefaultParameterInfo(rgBindings[binding]);
	  if (FAILED(hr))
	    return hr;
	}
      // If Virtuoso currenly doesn't provide parameter type info
      // use last chance to infer it from the binding.
      info.InitDefaultParameterType(rgBindings[binding]);
    }

  hr = Complete();
  if (FAILED(hr))
    return hr;

  m_cParamSets = (SQLUINTEGER)cParamSets;

  m_pbParamSets = new char[cParamSets * GetRecordSize()];
  if (m_pbParamSets == NULL)
    return ErrorInfo::Set(E_OUTOFMEMORY);

  m_rgParamSetStatus = new SQLUSMALLINT[cParamSets];
  if (m_rgParamSetStatus == NULL)
    return ErrorInfo::Set(E_OUTOFMEMORY);

  SQLRETURN rc;
  rc = SQLSetStmtAttr(stmt.GetHSTMT(), SQL_ATTR_PARAM_BIND_TYPE, (SQLPOINTER) GetRecordSize(), SQL_IS_UINTEGER);
  if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
    {
      TRACE((__FILE__, __LINE__, "ParameterPolicy::Init(): SQLSetStmtAttr() failed.\n"));
      return ErrorInfo::Set(E_FAIL, SQL_HANDLE_STMT, stmt.GetHSTMT());
    }
  rc = SQLSetStmtAttr(stmt.GetHSTMT(), SQL_ATTR_PARAMSET_SIZE, (SQLPOINTER) cParamSets, SQL_IS_UINTEGER);
  if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
    {
      TRACE((__FILE__, __LINE__, "ParameterPolicy::Init(): SQLSetStmtAttr() failed.\n"));
      return ErrorInfo::Set(E_FAIL, SQL_HANDLE_STMT, stmt.GetHSTMT());
    }
  rc = SQLSetStmtAttr(stmt.GetHSTMT(), SQL_ATTR_PARAM_STATUS_PTR, m_rgParamSetStatus, SQL_IS_POINTER);
  if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
    {
      TRACE((__FILE__, __LINE__, "ParameterPolicy::Init(): SQLSetStmtAttr() failed.\n"));
      return ErrorInfo::Set(E_FAIL, SQL_HANDLE_STMT, stmt.GetHSTMT());
    }
  rc = SQLSetStmtAttr(stmt.GetHSTMT(), SQL_ATTR_PARAMS_PROCESSED_PTR, &m_cParamSetsProcessed, SQL_IS_POINTER);
  if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
    {
      TRACE((__FILE__, __LINE__, "ParameterPolicy::Init(): SQLSetStmtAttr() failed.\n"));
      return ErrorInfo::Set(E_FAIL, SQL_HANDLE_STMT, stmt.GetHSTMT());
    }

  m_fOutputParams = false;

  for (param = 0; param < GetFieldCount(); param++)
    {
      const DataFieldInfo& info = GetFieldInfo(param);
      if (info.IsLong())
	continue;

      int iotype = SQL_PARAM_INPUT;
      DBPARAMFLAGS flags = info.GetFlags();
      if (flags & DBPARAMFLAGS_ISOUTPUT)
	{
	  m_fOutputParams = true;

	  if (flags & DBPARAMFLAGS_ISINPUT)
	    iotype = SQL_PARAM_INPUT_OUTPUT;
	  else
	    iotype = SQL_PARAM_OUTPUT;
	}

      LOG(("SQLBindParameter(..., param = %d, iotype = %d, sqlctype = %d, sqltype = %d, precision = %d, scale = %d, buffer = %x, length = %d, len_ind = %x)\n",
	   param + 1, iotype, info.GetSqlCType(), info.GetSqlType(),
	   info.GetOdbcColumnSize(), info.GetOdbcDecimalDigits(),
	   GetFieldBuffer(m_pbParamSets, param), info.GetInternalLength(),
	   GetFieldLengthPtr(m_pbParamSets, param)));

      rc = SQLBindParameter(stmt.GetHSTMT(), (SQLUSMALLINT) (param + 1), iotype,
			    info.GetSqlCType(), info.GetSqlType(),
			    info.GetOdbcColumnSize(), info.GetOdbcDecimalDigits(),
			    GetFieldBuffer(m_pbParamSets, param),
			    info.GetInternalLength(),
			    GetFieldLengthPtr(m_pbParamSets, param));
      if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
	{
	  TRACE((__FILE__, __LINE__, "ParameterPolicy::Init(): SQLBindParameter() failed.\n"));
	  return ErrorInfo::Set(E_FAIL, SQL_HANDLE_STMT, stmt.GetHSTMT());
	}
    }

  // TODO: Init status in param array

  return S_OK;
}

HRESULT
ParameterPolicy::Init(
  Statement& stmt,
  Schema* pSchema,
  ULONG cRestrictions,
  const VARIANT rgRestrictions[],
  IDataConvert* pIDataConvert
)
{
  LOGCALL(("ParamData::Init()\n"));

  assert(pSchema != NULL);

  if (pSchema->cParams == 0)
    return S_OK;

  m_statement = stmt;

  HRESULT hr = InitInfo(pSchema->cParams);
  if (FAILED(hr))
    return hr;

  for (ULONG param = 0; param < pSchema->cParams; param++)
    {
      ParameterInfo& info = m_rgFieldInfos[param];
      SchemaParam& schema_param = pSchema->rgParams[param];

      SQLUINTEGER precision = 0;
      DBTYPE oledb_type = DBTYPE_EMPTY;
      if (schema_param.iRestriction < cRestrictions)
	{
	  const VARIANT* value = &rgRestrictions[schema_param.iRestriction];
	  DBTYPE value_type = V_VT(value);
	  switch (value_type)
	    {
	    case VT_EMPTY:
	      break;
	    case VT_BSTR:
	      precision = SysStringLen(V_BSTR(value));
	      oledb_type = value_type;
	      break;
	    case VT_BOOL:
	    case VT_UI2:
	    case VT_UI4:
	    case VT_I2:
	    case VT_I4:
	      oledb_type = value_type;
	      break;
	    default:
	      return E_INVALIDARG;
	    }
	}

      hr = info.InitSchemaParameterInfo (schema_param.wSqlType, precision, oledb_type);
      if (FAILED(hr))
	return hr;
    }

  hr = Complete();
  if (FAILED(hr))
    return hr;

  m_cParamSets = 1;

  m_pbParamSets = new char[GetRecordSize()];
  if (m_pbParamSets == NULL)
    return ErrorInfo::Set(E_OUTOFMEMORY);

  m_rgParamSetStatus = new SQLUSMALLINT[1];
  if (m_rgParamSetStatus == NULL)
    return ErrorInfo::Set(E_OUTOFMEMORY);

  for (ULONG param = 0; param < GetFieldCount(); param++)
    {
      const DataFieldInfo& info = GetFieldInfo(param);
      SchemaParam& schema_param = pSchema->rgParams[param];

      LOG(("SQLBindParameter(..., param = %d, iotype = %d, sqlctype = %d, sqltype = %d, precision = %d, scale = %d, buffer = %x, length = %d, len_ind = %x)\n",
	   param + 1, SQL_PARAM_INPUT, info.GetSqlCType(), info.GetSqlType(),
	   info.GetOdbcColumnSize(), info.GetOdbcDecimalDigits(),
	   GetFieldBuffer(m_pbParamSets, param), info.GetInternalLength(),
	   GetFieldLengthPtr(m_pbParamSets, param)));

      SQLRETURN rc;
      rc = SQLBindParameter(stmt.GetHSTMT(), (SQLUSMALLINT) (param + 1), SQL_PARAM_INPUT,
			    info.GetSqlCType(), info.GetSqlType(),
			    info.GetOdbcColumnSize(), info.GetOdbcDecimalDigits(),
			    GetFieldBuffer(m_pbParamSets, param),
			    info.GetInternalLength(),
			    GetFieldLengthPtr(m_pbParamSets, param));
      if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
	{
	  TRACE((__FILE__, __LINE__, "ParameterPolicy::Init(): SQLBindParameter() failed.\n"));
	  return ErrorInfo::Set(E_FAIL, SQL_HANDLE_STMT, stmt.GetHSTMT());
	}

      SetFieldLength(m_pbParamSets, param, SQL_NULL_DATA);
      if (schema_param.iRestriction < cRestrictions)
	{
	  const VARIANT* value = &rgRestrictions[schema_param.iRestriction];
	  if (V_VT(value) != VT_EMPTY)
	    {
	      DBLENGTH cbProviderLength;

	      // Work around the problem with Oledb .NET data provider sometimes enclosing the
	      // table name into quotes.
	      if (V_VT(value) == VT_BSTR)
		{
		  BSTR value_string = V_BSTR(value);
		  UINT value_length = SysStringLen(value_string);
		  if (value_length > 0 && value_string[0] == '"' && value_string[value_length - 1] == '"')
		    {
		      hr = pIDataConvert->DataConvert(DBTYPE_WSTR, info.GetInternalDBType(),
						      (value_length - 2) * sizeof(OLECHAR), &cbProviderLength,
						      value_string + 1,
						      GetFieldBuffer(m_pbParamSets, param),
						      info.GetInternalLength(),
						      DBSTATUS_S_OK, NULL,
						      info.GetOledbPrecision(), info.GetOledbScale(),
						      DBDATACONVERT_SETDATABEHAVIOR);
		      if (FAILED(hr))
			{
			  TRACE((__FILE__, __LINE__, "ParameterPolicy::Init(): DataConvert(): Cannot convert parameter value.\n"));
			  return hr;
			}
		      SetFieldLength(m_pbParamSets, param, cbProviderLength);
		      continue;
		    }
		}

	      hr = pIDataConvert->DataConvert(DBTYPE_VARIANT, info.GetInternalDBType(),
					      0, &cbProviderLength,
					      (void*) value,
					      GetFieldBuffer(m_pbParamSets, param),
					      info.GetInternalLength(),
					      DBSTATUS_S_OK, NULL,
					      info.GetOledbPrecision(), info.GetOledbScale(),
					      DBDATACONVERT_SETDATABEHAVIOR);
	      if (FAILED(hr))
		{
		  TRACE((__FILE__, __LINE__, "ParameterPolicy::Init(): DataConvert(): Cannot convert parameter value.\n"));
		  return hr;
		}
	      SetFieldLength(m_pbParamSets, param, cbProviderLength);
	    }
	}
    }

  return S_OK;
}

HRESULT
ParameterPolicy::SetDataAtExec(
  HROW iRecordID,
  DBORDINAL iFieldOrdinal,
  SQLSMALLINT wSqlCType,
  DBCOUNTITEM iBinding
)
{
  LOGCALL(("ParameterPolicy::SetDataAtExec()\n"));

  if (iRecordID != 0)
    return S_OK;

  ULONG iField = OrdinalToIndex(iFieldOrdinal);
  const DataFieldInfo& info = GetFieldInfo(iField);

  int iotype = SQL_PARAM_INPUT;
  DBPARAMFLAGS flags = info.GetFlags();
  if (flags & DBPARAMFLAGS_ISOUTPUT)
    {
      if (flags & DBPARAMFLAGS_ISINPUT)
	iotype = SQL_PARAM_INPUT_OUTPUT;
      else
	iotype = SQL_PARAM_OUTPUT;
    }

  SQLRETURN rc = SQLBindParameter(m_statement.GetHSTMT(), (SQLUSMALLINT) iFieldOrdinal, iotype,
				  wSqlCType, info.GetSqlType(), 0, 0, (SQLPOINTER) iBinding, 0,
				  GetFieldLengthPtr(m_pbParamSets, iField));
  if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
    {
      TRACE((__FILE__, __LINE__, "ParameterPolicy::SetDataAtExec(): SQLBindParameter() failed.\n"));
      return ErrorInfo::Set(E_FAIL, SQL_HANDLE_STMT, m_statement.GetHSTMT());
    }

  return S_OK;
}

HRESULT
ParameterPolicy::GetDataAtExec(HROW& iRecordID, DBCOUNTITEM& iBinding)
{
  LOGCALL(("ParameterPolicy::GetDataAtExec()\n"));

  SQLINTEGER dwCookie = 0;
  HRESULT hr = m_statement.CheckDataAtExec((SQLPOINTER*) &dwCookie);
  if (FAILED(hr))
    return hr;

  if (hr == S_FALSE)
    {
      iRecordID = m_cParamSetsProcessed;
      iBinding = dwCookie;

      LOG(("paramset: %d, binding: %d\n", iRecordID, iBinding));
      return S_OK;
    }

  return S_FALSE;
}

HRESULT
ParameterPolicy::PutDataAtExec(char* pv,SQLINTEGER cb)
{
  LOGCALL(("ParameterPolicy::PutDataAtExec(pv = %x, cb = %d\n", pv, cb));

  SQLRETURN rc = SQLPutData(m_statement.GetHSTMT(), pv, cb);
  if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
    {
      TRACE((__FILE__, __LINE__, "ParameterPolicy::PutDataAtExec(): SQLPutData() failed.\n"));
      m_statement.DoDiagnostics();
      return ErrorInfo::Set(E_FAIL, SQL_HANDLE_STMT, m_statement.GetHSTMT());
    }
  return S_OK;
}

HRESULT
ParameterPolicy::GetStatus(ULONG param_set, const DataAccessor& accessor, char* consumer_data)
{
  if (GetFieldCount() == 0)
    return S_OK;

  assert(consumer_data != NULL);
  assert(m_rgParamSetStatus != NULL);

  bool failure = false;

  // It looks like Virtuoso's ODBC driver doesn't set SQL_ATTR_PARAMS_PROCESSED_PTR
  // in some cases (e.g. after a select with parametrs has been executed). Handle
  // this case by assuming that everything's ok.
  if (m_cParamSetsProcessed == 0)
    {
      m_cParamSetsProcessed = m_cParamSets;
      for (ULONG iParamSet = 0; iParamSet < m_cParamSetsProcessed; iParamSet++)
	{
	  m_rgParamSetStatus[iParamSet] = SQL_PARAM_SUCCESS;
	}
    }

  DBSTATUS dwStatus = DBSTATUS_S_OK;
  if (param_set >= m_cParamSetsProcessed)
    {
      dwStatus = DBSTATUS_E_UNAVAILABLE;
      failure = true;
    }
  else
    {
      switch (m_rgParamSetStatus[param_set])
	{
	case SQL_PARAM_SUCCESS:
	case SQL_PARAM_SUCCESS_WITH_INFO:
	  break;

	case SQL_PARAM_ERROR:
	  /* Currently ODBC does not provide row and column numbers in diagnostic
	     records therefore it is impossible to determine which kind of error
	     we got. Therefore it is impossible to set more precise error code. */
	case SQL_PARAM_UNUSED:
	  dwStatus = DBSTATUS_E_UNAVAILABLE;
	  failure = true;
	  break;
	}
    }

  for (DBCOUNTITEM iBinding = 0; iBinding < accessor.GetBindingCount (); iBinding++)
    {
      const DBBINDING& binding = accessor.GetBinding (iBinding);
      ULONG field = OrdinalToIndex(binding.iOrdinal);

      assert(field < GetFieldCount());
      const DataFieldInfo& field_info = GetFieldInfo(field);
      DBPARAMFLAGS flags = field_info.GetFlags();
      if (!(flags & DBPARAMFLAGS_ISINPUT))
	continue;

      if (dwStatus != DBSTATUS_S_OK && binding.dwPart & DBPART_STATUS)
	{
	  DBSTATUS* pConsumerStatus = (DBSTATUS*)(consumer_data + binding.obStatus);
	  if (*pConsumerStatus == DBSTATUS_S_OK
	      || *pConsumerStatus == DBSTATUS_S_ISNULL
	      || *pConsumerStatus == DBSTATUS_S_TRUNCATED)
	    *pConsumerStatus = dwStatus;
	}
    }

  return failure ? DB_E_ERRORSOCCURRED : S_OK;
}

void
ParameterPolicy::UnsetStatus()
{
  SQLSetStmtAttr(m_statement.GetHSTMT(), SQL_ATTR_PARAM_STATUS_PTR, NULL, SQL_IS_POINTER);
  ReleaseStatusArray();
}

HRESULT
ParameterPolicy::GetParamsInfo(Statement& stmt, std::vector<ParameterInfo>& param_infos)
{
  HSTMT hstmt = stmt.GetHSTMT();

  SQLSMALLINT num_params;
  SQLRETURN rc = SQLNumParams(hstmt, &num_params);
  if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
    {
      TRACE((__FILE__, __LINE__, "ParamData::GetParamsInfo(): SQLNumParams() failed.\n"));
      stmt.DoDiagnostics();
      return ErrorInfo::Set(E_FAIL, SQL_HANDLE_STMT, hstmt);
    }

  try {
    param_infos.reserve(num_params);
  } catch (...) {
    return ErrorInfo::Set(E_OUTOFMEMORY);
  }

  for (int i = 0; i < num_params; i++)
    {
      SQLSMALLINT type, scale, nullable;
      SQLULEN precision;
      SQLRETURN rc = SQLDescribeParam(hstmt, i + 1, &type, &precision, &scale, &nullable);
      if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
	{
	  TRACE((__FILE__, __LINE__, "ParamData::GetParamsInfo(): SQLDescribeParam() failed.\n"));
	  stmt.DoDiagnostics();
	  return ErrorInfo::Set(E_FAIL, SQL_HANDLE_STMT, hstmt);
	}

      if (i == param_infos.size())
	param_infos.push_back(ParameterInfo());

      SQLHDESC hipd;
      SQLINTEGER cbipd;
      rc = SQLGetStmtAttr(hstmt, SQL_ATTR_IMP_PARAM_DESC, (SQLPOINTER) &hipd, sizeof(SQLHDESC), &cbipd);
      if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
	{
	  TRACE((__FILE__, __LINE__, "ParamData::GetParamsInfo(): SQLGetStmtAttr() failed.\n"));
	  stmt.DoDiagnostics();
	  return ErrorInfo::Set(E_FAIL, SQL_HANDLE_STMT, hstmt);
	}

      SQLSMALLINT param_type = SQL_PARAM_TYPE_UNKNOWN;
      rc = SQLGetDescField(hipd, i + 1, SQL_DESC_PARAMETER_TYPE, &param_type, SQL_IS_SMALLINT, &cbipd);
      if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
	{
	  TRACE((__FILE__, __LINE__, "ParamData::GetParamsInfo(): SQLGetDescField() failed.\n"));
	  //DoDiagnostics(SQL_HANDLE_DESC, hipd);
	  return ErrorInfo::Set(E_FAIL);
	}

      SQLWCHAR param_name[MAX_PARAM_NAME_SIZE + 1] = { 0 };
      rc = SQLGetDescFieldW (hipd, i + 1, SQL_DESC_NAME, param_name, sizeof param_name, &cbipd);
      if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
	{
	  TRACE((__FILE__, __LINE__, "ParamData::GetParamsInfo(): SQLGetDescField() failed.\n"));
	  //DoDiagnostics(SQL_HANDLE_DESC, hipd);
	  return ErrorInfo::Set(E_FAIL);
	}

      ParameterInfo& param_info = param_infos[i];
      HRESULT hr = param_info.InitParameterInfo(param_name, type, (SQLUINTEGER)precision, scale, nullable, param_type);
      if (FAILED(hr))
	return hr;
    }
  return S_OK;
}

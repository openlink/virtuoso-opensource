/*  rowsetdata.cpp
 *
 *  $Id$
 *  
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *  
 *  Copyright (C) 1998-2019 OpenLink Software
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
#include "session.h"
#include "command.h"
#include "rowsetdata.h"
#include "util.h"
#include "error.h"
#include "virtext.h"

#if DEBUG
# include <crtdbg.h>
#endif

/* VC 7.0 hides this, so define it here. */
#define DBCOLUMNFLAGS_KEYCOLUMN 0x8000

#define MAX_COLUMN_NAME_SIZE 127

struct MetaColumn
{
  const wchar_t* pwszName;
  const DBID* pdbid;
  DBTYPE wOledbType;
  SQLINTEGER dwColumnSize;
  bool fMaybeNull;
};


const MetaColumn g_rgRequiredColumns[] = {
  { L"DBCOLUMN_IDNAME",		  &DBCOLUMN_IDNAME,	      DBTYPE_WSTR,	128,	true },
  { L"DBCOLUMN_GUID",		  &DBCOLUMN_GUID,	      DBTYPE_GUID,	16,	true },
  { L"DBCOLUMN_PROPID",		  &DBCOLUMN_PROPID,	      DBTYPE_UI4,	0,	true },
  { L"DBCOLUMN_NAME",		  &DBCOLUMN_NAME,	      DBTYPE_WSTR,	128,	true },
  { L"DBCOLUMN_NUMBER",		  &DBCOLUMN_NUMBER,	      DBTYPE_UI4,	0,	false },
  { L"DBCOLUMN_TYPE",		  &DBCOLUMN_TYPE,	      DBTYPE_UI2,	0,	false },
  { L"DBCOLUMN_TYPEINFO",	  &DBCOLUMN_TYPEINFO,	      DBTYPE_IUNKNOWN,	0,	true },
  { L"DBCOLUMN_COLUMNSIZE",	  &DBCOLUMN_COLUMNSIZE,	      DBTYPE_UI4,	0,	false },
  { L"DBCOLUMN_PRECISION",	  &DBCOLUMN_PRECISION,	      DBTYPE_UI2,	0,	true },
  { L"DBCOLUMN_SCALE",		  &DBCOLUMN_SCALE,	      DBTYPE_I2,	0,	true },
  { L"DBCOLUMN_FLAGS",		  &DBCOLUMN_FLAGS,	      DBTYPE_UI4,	0,	false },
};


#define REQUIRED_COLUMNS (sizeof g_rgRequiredColumns / sizeof g_rgRequiredColumns[0])

const MetaColumn g_rgOptionalColumns[] = {
  { L"DBCOLUMN_BASECATALOGNAME",  &DBCOLUMN_BASECATALOGNAME,  DBTYPE_WSTR,	128,	true },
  { L"DBCOLUMN_BASECOLUMNNAME",	  &DBCOLUMN_BASECOLUMNNAME,   DBTYPE_WSTR,	128,	true },
  { L"DBCOLUMN_BASESCHEMANAME",	  &DBCOLUMN_BASESCHEMANAME,   DBTYPE_WSTR,	128,	true },
  { L"DBCOLUMN_BASETABLENAME",	  &DBCOLUMN_BASETABLENAME,    DBTYPE_WSTR,	128,	true },
//{ L"DBCOLUMN_CLSID",		  &DBCOLUMN_CLSID,	      DBTYPE_GUID,	16,	true },
//{ L"DBCOLUMN_COLLATINGSEQUENCE",&DBCOLUMN_COLLATINGSEQUENCE,DBTYPE_I4,	0,	true },
  { L"DBCOLUMN_COMPUTEMODE",	  &DBCOLUMN_COMPUTEMODE,      DBTYPE_I4,	0,	true },
  { L"DBCOLUMN_DATETIMEPRECISION",&DBCOLUMN_DATETIMEPRECISION,DBTYPE_UI4,	0,	true },
//{ L"DBCOLUMN_DEFAULTVALUE",	  &DBCOLUMN_DEFAULTVALUE,     DBTYPE_VARIANT,	0,	true },
//{ L"DBCOLUMN_DOMAINCATALOG",	  &DBCOLUMN_DOMAINCATALOG,    DBTYPE_WSTR,	128,	true },
//{ L"DBCOLUMN_DOMAINSCHEMA",	  &DBCOLUMN_DOMAINSCHEMA,     DBTYPE_WSTR,	128,	true },
//{ L"DBCOLUMN_DOMAINNAME",	  &DBCOLUMN_DOMAINNAME,	      DBTYPE_WSTR,	128,	true },
//{ L"DBCOLUMN_HASDEFAULT",	  &DBCOLUMN_HASDEFAULT,	      DBTYPE_BOOL,	0,	true },
//{ L"DBCOLUMN_ISAUTOINCREMENT",  &DBCOLUMN_ISAUTOINCREMENT,  DBTYPE_BOOL,	0,	false },
  { L"DBCOLUMN_ISCASESENSITIVE",  &DBCOLUMN_ISCASESENSITIVE,  DBTYPE_BOOL,	0,	true },
  { L"DBCOLUMN_ISSEARCHABLE",	  &DBCOLUMN_ISSEARCHABLE,     DBTYPE_UI4,	0,	true },
//{ L"DBCOLUMN_ISUNIQUE",	  &DBCOLUMN_ISUNIQUE,	      DBTYPE_BOOL,	0,	true },
//{ L"DBCOLUMN_MAYSORT",	  &DBCOLUMN_MAYSORT,	      DBTYPE_BOOL,	0,	true },
  { L"DBCOLUMN_OCTETLENGTH",	  &DBCOLUMN_OCTETLENGTH,      DBTYPE_UI4,	0,	true },
  { L"DBCOLUMN_KEYCOLUMN",	  &DBCOLUMN_KEYCOLUMN,	      DBTYPE_BOOL,	0,	false },
//{ L"DBCOLUMN_BASETABLEVERSION", &DBCOLUMN_BASETABLEVERSION, DBTYPE_UI8,	0,	true },
//{ L"DBCOLUMN_DERIVEDCOLUMNNAME",&DBCOLUMN_DERIVEDCOLUMNNAME,DBTYPE_WSTR,	128,	true },
};

#define OPTIONAL_COLUMNS (sizeof g_rgOptionalColumns / sizeof g_rgOptionalColumns[0])

/**********************************************************************/
/* ColumnInfo                                                         */

ColumnInfo::ColumnInfo()
{
  m_pdbid = NULL;
}

HRESULT
ColumnInfo::InitColumnInfo(
  const SQLWCHAR* pwszName,
  const SQLWCHAR* pwszBaseName,
  const SQLWCHAR* pwszTable,
  const SQLWCHAR* pwszSchema,
  const SQLWCHAR* pwszCatalog,
  SQLSMALLINT sql_type,
  SQLUINTEGER field_size,
  SQLSMALLINT decimal_digits,
  SQLSMALLINT nullable,
  SQLLEN updatable,
  SQLLEN key
)
{
  LOGCALL (("ColumnInfo::InitColumnInfo pwszName=%S pwszBaseName=%S SqlCType=%d\n",
	pwszName,
	pwszBaseName,
	(int) sql_type));
  HRESULT hr = SetNativeFieldInfo(sql_type, field_size, decimal_digits);
  if (FAILED(hr))
    return hr;

  hr = SetName(pwszName);
  if (FAILED(hr))
    return hr;

  try
    {
      m_base_column_name = pwszBaseName;
      m_base_table_name = pwszTable;
      m_base_schema_name = pwszSchema;
      m_base_catalog_name = pwszCatalog;
    }
  catch (...)
    {
      return ErrorInfo::Set(E_OUTOFMEMORY);
    }

  DBCOLUMNFLAGS flags = 0;
  if (IsFixed())
    flags |= DBCOLUMNFLAGS_ISFIXEDLENGTH;
  else if (IsLong())
    flags |= DBCOLUMNFLAGS_ISLONG | DBCOLUMNFLAGS_MAYDEFER;
  // Virtuoso ODBC driver maps TIMESTAMP to BINARY. Also it does not report that it
  // isn't updatable nor nullable (it's always updated automatically, not by a user).
  if (sql_type == SQL_BINARY)
    flags |= DBCOLUMNFLAGS_ISROWVER;
  else
    {
      if (nullable != SQL_NO_NULLS)
	flags |= DBCOLUMNFLAGS_ISNULLABLE | DBCOLUMNFLAGS_MAYBENULL;
      // FIXME: What it should really be: DBCOLUMNFLAGS_WRITE or DBCOLUMNFLAGS_WRITEUNKNOWN ?
      if (updatable != SQL_ATTR_READONLY)
#if 0
	flags |= DBCOLUMNFLAGS_WRITE;
#else
	flags |= DBCOLUMNFLAGS_WRITEUNKNOWN;
#endif
    }

  if (key)
    flags |= DBCOLUMNFLAGS_KEYCOLUMN;
  SetFlags(flags);
  return S_OK;
}

HRESULT
ColumnInfo::InitBookmarkColumnInfo ()
{
  HRESULT hr = SetSyntheticFieldInfo (DBTYPE_UI4, 10, 0);
  if (FAILED (hr))
    return hr;

  SetFlags (DBCOLUMNFLAGS_ISBOOKMARK | DBCOLUMNFLAGS_ISFIXEDLENGTH);
  return S_OK;
}

HRESULT
ColumnInfo::InitMetaColumnInfo(
  const wchar_t* pwszName,
  const DBID* pdbid,
  DBTYPE wOledbType,
  SQLINTEGER dwColumnSize,
  bool fMaybeNull
)
{
  LOGCALL (("ColumnInfo::InitMetaColumnInfo1 pwszName=%S, wOledbType=%d, dwColumnSize=%ld\n",
	pwszName,
	(int) wOledbType,
	(long) dwColumnSize));
  HRESULT hr = SetSyntheticFieldInfo (wOledbType, dwColumnSize, 0);
  if (FAILED(hr))
    {
      LOG (("ColumnInfo::InitMetaColumnInfo1 SetSyntheticFieldInfo failed\n"));
      return hr;
    }
  hr = SetName(pwszName);
  if (FAILED(hr))
    return hr;

  if (pdbid != NULL)
    SetDBID(pdbid);

  DBCOLUMNFLAGS flags = 0;
  if (fMaybeNull)
    flags |= DBCOLUMNFLAGS_MAYBENULL;
  if (IsFixed())
    flags |= DBCOLUMNFLAGS_ISFIXEDLENGTH;
  SetFlags(flags);
  return S_OK;
}

/**********************************************************************/
/* RowsetInfo                                                         */

RowsetInfo::RowsetInfo()
{
  m_cColumns = 0;
  m_cHiddenColumns = 0;
  m_rgColumnInfos = NULL;
  m_fHasBookmark = false;
}

RowsetInfo::~RowsetInfo()
{
  Release();
}

void
RowsetInfo::Release()
{
  DataRecordInfo::Release();
  delete [] m_rgColumnInfos;
  m_rgColumnInfos = NULL;
  m_cColumns = 0;
}

HRESULT
RowsetInfo::InitInfo(DBORDINAL cColumns, bool fHasBookmark)
{
  m_fHasBookmark = fHasBookmark;

  HRESULT hr = DataRecordInfo::Init();
  if (FAILED(hr))
    return hr;
  if (cColumns == 0)
    return S_OK;

  if (m_fHasBookmark)
    cColumns++;

  m_rgColumnInfos = new ColumnInfo[cColumns];
  if (m_rgColumnInfos == NULL)
    return ErrorInfo::Set(E_OUTOFMEMORY);
  m_cColumns = cColumns;

  return S_OK;
}

HRESULT
RowsetInfo::InitColumn (int iColumn, Statement& stmt)
{
  SQLWCHAR wszName[MAX_COLUMN_NAME_SIZE + 1];
  SQLWCHAR wszBaseName[MAX_COLUMN_NAME_SIZE + 1];
  SQLWCHAR wszTable[MAX_COLUMN_NAME_SIZE + 1];
  SQLWCHAR wszSchema[MAX_COLUMN_NAME_SIZE + 1];
  SQLWCHAR wszCatalog[MAX_COLUMN_NAME_SIZE + 1];
  SQLSMALLINT cbName, cbBaseName, cbTable, cbSchema, cbCatalog;
  SQLSMALLINT wSqlType, wScale, wNullable;
  SQLULEN dwPrecision;
  SQLLEN dwUpdatable, dwHidden, dwKey;
  SQLRETURN rc;

  HSTMT hstmt = stmt.GetHSTMT();

  LOGCALL (("RowsetInfo::InitColumn()\n"));
  rc = SQLDescribeColW (hstmt, (SQLUSMALLINT) iColumn,	wszName, sizeof wszName, &cbName,
			&wSqlType,  &dwPrecision, &wScale, &wNullable);
  if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
    {
      TRACE((__FILE__, __LINE__, "RowsetInfo::Init(): SQLDescribeCol() failed.\n"));
      DataRecordInfo::Release();
      return ErrorInfo::Set(E_FAIL, SQL_HANDLE_STMT, hstmt);
    }
  LOG (("RowsetInfo::InitColumn() iCol=%d, wszName=%S, wSqlType=%d, dwPrecision=%ld, wScale=%d, wNullable=%d\n",
	(int)iColumn,
	wszName,
	(int)wSqlType,
	(long)dwPrecision,
	(int)wScale,
	(int)wNullable));
  rc = SQLColAttributes(hstmt, iColumn, SQL_COLUMN_UPDATABLE, NULL, 0, NULL, &dwUpdatable);
  if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
    {
      TRACE((__FILE__, __LINE__, "RowsetInfo::Init(): SQLColAttribute() failed.\n"));
      DataRecordInfo::Release();
      return ErrorInfo::Set(E_FAIL, SQL_HANDLE_STMT, hstmt);
    }
 rc = SQLColAttributesW (hstmt, iColumn, SQL_DESC_BASE_COLUMN_NAME, wszBaseName, sizeof wszBaseName, &cbBaseName, NULL);
 if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
    {
      TRACE((__FILE__, __LINE__, "RowsetInfo::Init(): SQLColAttribute() for SQL_DESC_BASE_COLUMN_NAME failed.\n"));
      DataRecordInfo::Release();
      return ErrorInfo::Set(E_FAIL, SQL_HANDLE_STMT, hstmt);
    }
 rc = SQLColAttributesW (hstmt, iColumn, SQL_DESC_BASE_TABLE_NAME, wszTable, sizeof wszTable, &cbTable, NULL);
 if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
    {
      TRACE((__FILE__, __LINE__, "RowsetInfo::Init(): SQLColAttribute() for SQL_DESC_BASE_TABLE_NAME failed.\n"));
      DataRecordInfo::Release();
      return ErrorInfo::Set(E_FAIL, SQL_HANDLE_STMT, hstmt);
    }
  rc = SQLColAttributesW (hstmt, iColumn, SQL_DESC_SCHEMA_NAME, wszSchema, sizeof wszSchema, &cbSchema, NULL);
  if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
    {
      TRACE((__FILE__, __LINE__, "RowsetInfo::Init(): SQLColAttribute() for SQL_DESC_SCHEMA_NAME failed.\n"));
      DataRecordInfo::Release();
      return ErrorInfo::Set(E_FAIL, SQL_HANDLE_STMT, hstmt);
    }
  rc = SQLColAttributesW (hstmt, iColumn, SQL_DESC_CATALOG_NAME, wszCatalog, sizeof wszCatalog, &cbCatalog, NULL);
  if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
    {
      TRACE((__FILE__, __LINE__, "RowsetInfo::Init(): SQLColAttribute() for SQL_DESC_CATALOG_NAME failed.\n"));
      DataRecordInfo::Release();
      return ErrorInfo::Set(E_FAIL, SQL_HANDLE_STMT, hstmt);
    }

  dwKey = 0;
  rc = SQLColAttributes(hstmt, iColumn, SQL_COLUMN_KEY,	NULL, 0, NULL, &dwKey);
  if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
    {
      TRACE((__FILE__, __LINE__, "RowsetInfo::Init(): SQLColAttribute(..., SQL_COLUMN_KEY, ...) failed.\n"));
    }

  dwHidden = 0;
  rc = SQLColAttributes(hstmt, iColumn, SQL_COLUMN_HIDDEN, NULL, 0, NULL, &dwHidden);
  if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
    {
      TRACE((__FILE__, __LINE__, "RowsetInfo::Init(..., SQL_COLUMN_HIDEEN, ...): SQLColAttribute() failed.\n"));
    }

  return m_rgColumnInfos[OrdinalToIndex(iColumn)].InitColumnInfo (wszName, wszBaseName,
								  wszTable, wszSchema, wszCatalog,
								  wSqlType, (SQLUINTEGER) dwPrecision, wScale,
								  wNullable, dwUpdatable, dwKey);
}

HRESULT
RowsetInfo::InitColumn (int iColumn, Schema* pSchema)
{
  SchemaColumn* pSchemaColumn = &pSchema->rgColumns[iColumn - 1];
  return m_rgColumnInfos[OrdinalToIndex(iColumn)].InitMetaColumnInfo (pSchemaColumn->pwszName,
								      NULL,
								      pSchemaColumn->wOledbType,
								      pSchemaColumn->dwColumnSize,
								      pSchemaColumn->fMaybeNull);
}

HRESULT
RowsetInfo::Init(Statement& stmt, Schema* pSchema)
{
  Release();

  m_cHiddenColumns = 0;

  DBORDINAL cColumns = stmt.GetColumnCount();
  HRESULT hr = InitInfo(cColumns, stmt.HasBookmark());
  if (FAILED(hr))
    return hr;
  if (cColumns == 0)
    return S_OK;

  if (m_fHasBookmark)
    m_rgColumnInfos[0].InitBookmarkColumnInfo();

  HSTMT hstmt = stmt.GetHSTMT();
  for (int iColumn = 1; iColumn <= cColumns; iColumn++)
    {
      if (pSchema == NULL
	  || iColumn > pSchema->cColumns
	  || pSchema->rgColumns[iColumn - 1].wOledbType == DBTYPE_EMPTY)
	hr = InitColumn (iColumn, stmt);
      else
	hr = InitColumn (iColumn, pSchema);
      if (FAILED(hr))
	{
	  DataRecordInfo::Release();
	  return hr;
	}

      if (m_rgColumnInfos[OrdinalToIndex(iColumn)].GetFlags() & DBCOLUMNFLAGS_KEYCOLUMN)
	m_cHiddenColumns++;
    }

  return S_OK;
}

HRESULT
RowsetInfo::Init(
  DBORDINAL cOptColumns,
  const DBID rgOptColumns[],
  bool fHasBookmark
)
{
  DBORDINAL cColumns = REQUIRED_COLUMNS;
  for (int i = 0; i < OPTIONAL_COLUMNS; i++)
    {
      for (DBORDINAL iOptColumn = 0; iOptColumn < cOptColumns; iOptColumn++)
	{
	  if (DBIDEqual(g_rgOptionalColumns[i].pdbid, &rgOptColumns[iOptColumn]))
	    {
	      cColumns++;
	      break;
	    }
	}
    }

  HRESULT hr = InitInfo(cColumns, fHasBookmark);
  if (FAILED(hr))
    return hr;

  DBORDINAL iColumn = 0;
  if (m_fHasBookmark)
    {
      m_rgColumnInfos[0].InitBookmarkColumnInfo();
      iColumn++;
    }
  for (int i = 0; i < REQUIRED_COLUMNS; i++)
    {
      m_rgColumnInfos[iColumn].InitMetaColumnInfo(g_rgRequiredColumns[i].pwszName,
						  g_rgRequiredColumns[i].pdbid,
						  g_rgRequiredColumns[i].wOledbType,
						  g_rgRequiredColumns[i].dwColumnSize,
						  g_rgRequiredColumns[i].fMaybeNull);
      iColumn++;
    }
  for (int i = 0; i < OPTIONAL_COLUMNS; i++)
    {
      for (DBORDINAL iOptColumn = 0; iOptColumn < cOptColumns; iOptColumn++)
	{
	  if (DBIDEqual(g_rgOptionalColumns[i].pdbid, &rgOptColumns[iOptColumn]))
	    {
	      m_rgColumnInfos[iColumn].InitMetaColumnInfo(g_rgOptionalColumns[i].pwszName,
							  g_rgOptionalColumns[i].pdbid,
							  g_rgOptionalColumns[i].wOledbType,
							  g_rgOptionalColumns[i].dwColumnSize,
							  g_rgOptionalColumns[i].fMaybeNull);
	      iColumn++;
	      break;
	    }
	}
    }
  assert(iColumn == m_cColumns);

  return S_OK;
}

int
RowsetInfo::GetOptionalMetaColumns()
{
  return OPTIONAL_COLUMNS;
}

void
RowsetInfo::GetOptionalMetaColumnIDs(DBID* rgOptColumns)
{
  assert(rgOptColumns != NULL);
  for (int i = 0; i < OPTIONAL_COLUMNS; i++)
    rgOptColumns[i] = *g_rgOptionalColumns[i].pdbid;
}

HRESULT
RowsetInfo::InitMetaRow(DBORDINAL iColumnOrdinal, const ColumnInfo& info, bool fIsHidden, char* pbMetaData)
{
  assert(IsCompleted());

  DBORDINAL cColumns = GetFieldCount();
  for (ULONG iColumn = 0; iColumn < cColumns; iColumn++)
    {
      SetColumnStatus(pbMetaData, iColumn, COLUMN_STATUS_UNCHANGED);

      const ColumnInfo& metainfo = GetColumnInfo(iColumn);
      char* pbColumnMetaData = GetFieldBuffer(pbMetaData, iColumn);
      if (IndexToOrdinal(iColumn) == 0) // this is a bookmark meta column
	{
	  *((DBORDINAL*) pbColumnMetaData) = iColumnOrdinal;
	  SetFieldLength(pbMetaData, iColumn, sizeof(SQLLEN));
	}
      else if (DBIDEqual(metainfo.GetDBID(), &DBCOLUMN_IDNAME))
	{
	  if (iColumnOrdinal == 0)
	    SetFieldLength(pbMetaData, iColumn, SQL_NULL_DATA);
	  else
	    {
	      const DBID* dbid = info.GetDBID();
	      if (dbid != NULL)
		SetFieldLength(pbMetaData, iColumn, SQL_NULL_DATA);
	      else
		{
		  if (info.GetName().empty())
  		    SetFieldLength(pbMetaData, iColumn, SQL_NULL_DATA);
		  else
		    {
  		      SetFieldLength(pbMetaData, iColumn, info.GetName().length() * sizeof(wchar_t));
		      wcsncpy((wchar_t*) pbColumnMetaData, info.GetName().c_str(), metainfo.GetOdbcColumnSize());
		    }
		}
	    }
	}
      else if (DBIDEqual(metainfo.GetDBID(), &DBCOLUMN_GUID))
	{
	  if (iColumnOrdinal == 0 || fIsHidden)
	    {
	      *((GUID*) pbColumnMetaData) = DBCOL_SPECIALCOL;
	      SetFieldLength(pbMetaData, iColumn, 16);
	    }
	  else
	    {
	      const DBID* dbid = info.GetDBID();
	      if (dbid != NULL)
		{
		  assert(dbid->eKind == DBKIND_GUID_PROPID);
		  *((GUID*) pbColumnMetaData) = dbid->uGuid.guid;
		  SetFieldLength(pbMetaData, iColumn, SQL_NULL_DATA);
		}
	      else
		{
  		  SetFieldLength(pbMetaData, iColumn, SQL_NULL_DATA);
		}
	    }
	}
      else if (DBIDEqual(metainfo.GetDBID(), &DBCOLUMN_PROPID))
	{
	  if (iColumnOrdinal == 0)
	    {
	      *((LONG*) pbColumnMetaData) = 2;
	      SetFieldLength(pbMetaData, iColumn, sizeof(LONG));
	    }
	  else
	    {
	      const DBID* dbid = info.GetDBID();
	      if (dbid != NULL)
		{
		  assert(dbid->eKind == DBKIND_GUID_PROPID);
		  *((LONG*) pbColumnMetaData) = dbid->uName.ulPropid;
		  SetFieldLength(pbMetaData, iColumn, SQL_NULL_DATA);
		}
	      else
		{
  		  SetFieldLength(pbMetaData, iColumn, SQL_NULL_DATA);
		}
	    }
	}
      else if (DBIDEqual(metainfo.GetDBID(), &DBCOLUMN_NAME))
	{
	  if (iColumnOrdinal == 0 || info.GetName().empty())
	    SetFieldLength(pbMetaData, iColumn, SQL_NULL_DATA);
	  else
	    {
	      SetFieldLength(pbMetaData, iColumn, info.GetName().length() * sizeof(wchar_t));
	      wcsncpy((wchar_t*) pbColumnMetaData, info.GetName().c_str(), metainfo.GetOdbcColumnSize());
	    }
	}
      else if (DBIDEqual(metainfo.GetDBID(), &DBCOLUMN_NUMBER))
	{
	  *((DBORDINAL*) pbColumnMetaData) = iColumnOrdinal;
	  SetFieldLength(pbMetaData, iColumn, sizeof(LONG));
	}
      else if (DBIDEqual(metainfo.GetDBID(), &DBCOLUMN_TYPE))
	{
	  *((SHORT*) pbColumnMetaData) = info.GetOledbType();
	  SetFieldLength(pbMetaData, iColumn, sizeof(SHORT));
	}
      else if (DBIDEqual(metainfo.GetDBID(), &DBCOLUMN_TYPEINFO))
	{
	  SetFieldLength(pbMetaData, iColumn, SQL_NULL_DATA);
	}
      else if (DBIDEqual(metainfo.GetDBID(), &DBCOLUMN_COLUMNSIZE))
	{
	  *((DBORDINAL*) pbColumnMetaData) = info.GetOledbSize();
	  SetFieldLength(pbMetaData, iColumn, sizeof(LONG));
	}
      else if (DBIDEqual(metainfo.GetDBID(), &DBCOLUMN_PRECISION))
	{
	  switch (info.GetOledbType())
	    {
	    case DBTYPE_I2:
	    case DBTYPE_UI2:
	    case DBTYPE_I4:
	    case DBTYPE_UI4:
	    case DBTYPE_I8:
	    case DBTYPE_UI8:
	    case DBTYPE_R4:
	    case DBTYPE_R8:
	    case DBTYPE_DECIMAL:
	    case DBTYPE_NUMERIC:
	    case DBTYPE_VARNUMERIC:
	    case DBTYPE_DBTIMESTAMP:
	      *((SHORT*) pbColumnMetaData) = info.GetOledbPrecision();
	      SetFieldLength(pbMetaData, iColumn, sizeof(SHORT));
	      break;
	    default:
	      SetFieldLength(pbMetaData, iColumn, SQL_NULL_DATA);
	      break;
	    }
	}
      else if (DBIDEqual(metainfo.GetDBID(), &DBCOLUMN_SCALE))
	{
	  switch (info.GetOledbType())
	    {
	    case DBTYPE_DECIMAL:
	    case DBTYPE_NUMERIC:
	    case DBTYPE_VARNUMERIC:
	    case DBTYPE_DBTIMESTAMP:
	      *((SHORT*) pbColumnMetaData) = info.GetOledbScale();
	      SetFieldLength(pbMetaData, iColumn, sizeof(SHORT));
	      break;
	    default:
	      SetFieldLength(pbMetaData, iColumn, SQL_NULL_DATA);
	    }
	}
      else if (DBIDEqual(metainfo.GetDBID(), &DBCOLUMN_FLAGS))
	{
	  *((LONG*) pbColumnMetaData) = info.GetFlags();
	  SetFieldLength(pbMetaData, iColumn, sizeof(LONG));
	}
      else if (DBIDEqual(metainfo.GetDBID(), &DBCOLUMN_BASECATALOGNAME))
	{
	  const std::basic_string<OLECHAR>& name = info.GetBaseCatalogName();
	  if (name.empty())
	    SetFieldLength(pbMetaData, iColumn, SQL_NULL_DATA);
	  else
	    {
	      SetFieldLength(pbMetaData, iColumn, name.length() * sizeof(wchar_t));
	      wcsncpy((wchar_t*) pbColumnMetaData, name.c_str(), metainfo.GetOdbcColumnSize());
	    }
	}
      else if (DBIDEqual(metainfo.GetDBID(), &DBCOLUMN_BASECOLUMNNAME))
	{
	  const std::basic_string<OLECHAR>& name = info.GetBaseColumnName();
	  if (name.empty())
	    SetFieldLength(pbMetaData, iColumn, SQL_NULL_DATA);
	  else
	    {
	      SetFieldLength(pbMetaData, iColumn, name.length() * sizeof(wchar_t));
	      wcsncpy((wchar_t*) pbColumnMetaData, name.c_str(), metainfo.GetOdbcColumnSize());
	    }
	}
      else if (DBIDEqual(metainfo.GetDBID(), &DBCOLUMN_BASESCHEMANAME))
	{
	  const std::basic_string<OLECHAR>& name = info.GetBaseSchemaName();
	  if (name.empty())
	    SetFieldLength(pbMetaData, iColumn, SQL_NULL_DATA);
	  else
	    {
	      SetFieldLength(pbMetaData, iColumn, name.length() * sizeof(wchar_t));
	      wcsncpy((wchar_t*) pbColumnMetaData, name.c_str(), metainfo.GetOdbcColumnSize());
	    }
	}
      else if (DBIDEqual(metainfo.GetDBID(), &DBCOLUMN_BASETABLENAME))
	{
	  const std::basic_string<OLECHAR>& name = info.GetBaseTableName();
	  if (name.empty())
	    SetFieldLength(pbMetaData, iColumn, SQL_NULL_DATA);
	  else
	    {
	      SetFieldLength(pbMetaData, iColumn, name.length() * sizeof(wchar_t));
	      wcsncpy((wchar_t*) pbColumnMetaData, name.c_str(), metainfo.GetOdbcColumnSize());
	    }
	}
      else if (DBIDEqual(metainfo.GetDBID(), &DBCOLUMN_COMPUTEMODE))
	{
	  *((LONG*) pbColumnMetaData) = DBCOMPUTEMODE_NOTCOMPUTED;
	  SetFieldLength(pbMetaData, iColumn, sizeof(LONG));
	}
      else if (DBIDEqual(metainfo.GetDBID(), &DBCOLUMN_DATETIMEPRECISION))
	{
	  if (info.GetOledbType() == DBTYPE_DBTIMESTAMP)
	    {
	      // Yes, it's GetOledbScale(), not GetOledbPrecision()!
	      *((LONG*) pbColumnMetaData) = info.GetOledbScale();
	      SetFieldLength(pbMetaData, iColumn, sizeof(LONG));
	    }
	  else
	    SetFieldLength(pbMetaData, iColumn, SQL_NULL_DATA);
	}
      else if (DBIDEqual(metainfo.GetDBID(), &DBCOLUMN_ISAUTOINCREMENT))
	{
	  *((SHORT*) pbColumnMetaData) = VARIANT_FALSE;
	  SetFieldLength(pbMetaData, iColumn, sizeof(SHORT));
	}
      else if (DBIDEqual(metainfo.GetDBID(), &DBCOLUMN_ISCASESENSITIVE))
	{
	  if (info.GetOledbType() == DBTYPE_STR || info.GetOledbType() == DBTYPE_WSTR)
	    *((SHORT*) pbColumnMetaData) = VARIANT_TRUE;
	  else
	    *((SHORT*) pbColumnMetaData) = VARIANT_FALSE;
	  SetFieldLength(pbMetaData, iColumn, sizeof(SHORT));
	}
      else if (DBIDEqual(metainfo.GetDBID(), &DBCOLUMN_ISSEARCHABLE))
	{
	  if (info.IsLong())
	    *((LONG*) pbColumnMetaData) = DB_UNSEARCHABLE;
	  else if (info.GetOledbType() == DBTYPE_STR || info.GetOledbType() == DBTYPE_WSTR
		   || (info.GetOledbType() == DBTYPE_BYTES && info.GetSqlType() != SQL_BINARY)) // excluding timestamp
	    *((LONG*) pbColumnMetaData) = DB_SEARCHABLE;
	  else
	    *((LONG*) pbColumnMetaData) = DB_ALL_EXCEPT_LIKE;
	  SetFieldLength(pbMetaData, iColumn, sizeof(LONG));
	}
      else if (DBIDEqual(metainfo.GetDBID(), &DBCOLUMN_OCTETLENGTH))
	{
	  if (info.GetOledbType() == DBTYPE_STR || info.GetOledbType() == DBTYPE_BYTES)
	    {
	      *((LONG*) pbColumnMetaData) = info.GetOdbcColumnSize();
	      SetFieldLength(pbMetaData, iColumn, sizeof(LONG));
	    }
	  else if (info.GetOledbType() == DBTYPE_WSTR)
	    {
	      *((LONG*) pbColumnMetaData) = info.GetOdbcColumnSize() * 2;
	      SetFieldLength(pbMetaData, iColumn, sizeof(LONG));
	    }
	  else
	    SetFieldLength(pbMetaData, iColumn, SQL_NULL_DATA);
	}
      else if (DBIDEqual(metainfo.GetDBID(), &DBCOLUMN_KEYCOLUMN))
	{
	  if ((info.GetFlags() & DBCOLUMNFLAGS_KEYCOLUMN))
	    *((SHORT*) pbColumnMetaData) = VARIANT_TRUE;
	  else
	    *((SHORT*) pbColumnMetaData) = VARIANT_FALSE;
	  SetFieldLength(pbMetaData, iColumn, sizeof(SHORT));
	}
      else
	{
	  SetFieldLength(pbMetaData, iColumn, SQL_NULL_DATA);
	  SetColumnStatus(pbMetaData, iColumn, COLUMN_STATUS_UNAVAILABLE);
	}
    }
  return S_OK;
}

/**********************************************************************/
/* ReleaseRowsPolicy                                                  */

void
ReleaseRowsPolicy::Release()
{
  m_hRowBase = 0;
  m_cHeldRows = 0;
  m_rows.clear();
  delete [] m_pbRows;
  m_pbRows = NULL;
  m_cMaxRows = 0;
}

bool
ReleaseRowsPolicy::HoldsRows()
{
  return (m_cHeldRows != 0);
}

void
ReleaseRowsPolicy::ReleaseAllRows()
{
  assert(!HoldsRows());

  delete [] m_pbRows;
  m_pbRows = NULL;
  m_cMaxRows = 0;
}

HRESULT
ReleaseRowsPolicy::AllocateRows(HROW hRowBase, DBCOUNTITEM cRows, const DataRecordInfo* info)
{
  assert(info != NULL);

  if (HoldsRows())
    return DB_E_ROWSNOTRELEASED;

  try {
    m_rows.resize(cRows, RowData());
  } catch (...) {
    return ErrorInfo::Set(E_OUTOFMEMORY);
  }

  if (cRows > m_cMaxRows)
    {
      delete [] m_pbRows;
      m_pbRows = new char[cRows * info->GetRecordSize()];
      if (m_pbRows == NULL)
	{
	  Release();
	  return ErrorInfo::Set(E_OUTOFMEMORY);
	}
      m_cMaxRows = cRows;
    }

  for (DBCOUNTITEM iRow = 0; iRow < cRows; iRow++)
    m_rows[iRow].Init(m_pbRows + iRow * info->GetRecordSize());

  m_hRowBase = hRowBase;
  // TODO: if a failure happens before AddRef the count of held rows can become wrong.
  m_cHeldRows = cRows;
  return S_OK;
}

RowData*
ReleaseRowsPolicy::GetRowData(HROW hRow)
{
  int i = (int)(hRow - m_hRowBase);
  return i < ((int) m_rows.size()) && i >= 0 ? &m_rows[i] : NULL;
}

void
ReleaseRowsPolicy::ReleaseRowData(HROW hRow)
{
  int i = (int)(hRow - m_hRowBase);
  assert(i < ((int) m_rows.size()) && i >= 0);
  m_rows[i].Reset();
  m_cHeldRows--;
}

void
ReleaseRowsPolicy::DeleteRow(RowData* pRowData)
{
  assert(pRowData != NULL);
  pRowData->m_pbData = NULL;
  pRowData->m_status = DBPENDINGSTATUS_INVALIDROW;
}

DBCOUNTITEM
ReleaseRowsPolicy::GetActiveRows()
{
  return m_cHeldRows;
}

void
ReleaseRowsPolicy::GetActiveRowHandles(HROW rghRows[])
{
  int iRow = 0;
  for (int i = 0; i < ((int) m_rows.size()); i++)
    {
      if (m_rows[i].GetRefRow() > 0)
	rghRows[iRow++] = m_hRowBase + i;
    }
}

/**********************************************************************/
/* CanHoldRowsPolicy                                                  */

void
CanHoldRowsPolicy::Release()
{
  for (Map::iterator i = m_rows.begin(); i != m_rows.end(); i++)
    delete [] i->second.m_pbData;
  m_rows.clear();
}

bool
CanHoldRowsPolicy::HoldsRows()
{
  return !m_rows.empty();
}

void
CanHoldRowsPolicy::ReleaseAllRows()
{
  assert(!HoldsRows());
}

HRESULT
CanHoldRowsPolicy::AllocateRows(HROW hRowBase, DBCOUNTITEM cRows, const DataRecordInfo* info)
{
  assert(info != NULL);

  // TODO: Reuse memory -- don't allocate and release it each time.

  // TODO: This can be optimized, e.g. using insert(iterator, value_type&)
  // instead of insert(value_type&) etc.
  for (DBCOUNTITEM i = 0; i < cRows; i++)
    {
      Map::iterator iter = m_rows.end();
      try {
	std::pair<Map::iterator, bool> ipair = m_rows.insert(Elt(hRowBase + i, RowData()));
	// Skip initialization if a row is encountered that was created sometime earlier.
	if (!ipair.second)
	  continue;
	iter = ipair.first;
      } catch (...) {
	for (DBCOUNTITEM j = 0; j <= i; j++)
	  {
	    iter = m_rows.find(hRowBase + j);
	    if (iter != m_rows.end() && iter->second.m_status == DBPENDINGSTATUS_INVALIDROW)
	      {
		delete [] iter->second.m_pbData;
		m_rows.erase(iter);
	      }
	  }
	return ErrorInfo::Set(E_OUTOFMEMORY);
      }

      char* pbData = new char[info->GetRecordSize()];
      if (pbData == NULL)
	{
	  for (DBCOUNTITEM j = 0; j <= i; j++)
	    {
	      iter = m_rows.find(hRowBase + j);
	      if (iter != m_rows.end() && iter->second.m_status == DBPENDINGSTATUS_INVALIDROW)
		{
		  delete [] iter->second.m_pbData;
		  m_rows.erase(iter);
		}
	    }
	  return ErrorInfo::Set(E_OUTOFMEMORY);
	}

      iter->second.Init(pbData);
    }

  return S_OK;
}

RowData*
CanHoldRowsPolicy::GetRowData(HROW hRow)
{
  std::map<HROW, RowData>::iterator i = m_rows.find(hRow);
  if (i != m_rows.end())
    return &i->second;
  return NULL;
}

void
CanHoldRowsPolicy::ReleaseRowData(HROW hRow)
{
  std::map<HROW, RowData>::iterator i = m_rows.find(hRow);
  if (i != m_rows.end())
    {
      delete [] i->second.m_pbData;
      m_rows.erase(i);
    }
}

void
CanHoldRowsPolicy::DeleteRow(RowData* pRowData)
{
  assert(pRowData != NULL);
  delete [] pRowData->m_pbData;
  pRowData->m_pbData = NULL;
  pRowData->m_status = DBPENDINGSTATUS_INVALIDROW;
}

DBCOUNTITEM
CanHoldRowsPolicy::GetActiveRows()
{
  return (DBCOUNTITEM) m_rows.size();
}

void
CanHoldRowsPolicy::GetActiveRowHandles(HROW rghRows[])
{
  int iRow = 0;
  for (Map::iterator i = m_rows.begin(); i != m_rows.end(); i++)
    rghRows[iRow++] = i->first;
}

/**********************************************************************/
/* ColumnsRowsPolicy                                                  */

HRESULT
ColumnsRowsPolicy::Init(DBCOUNTITEM cRows, const DataRecordInfo* info)
{
  assert(info != NULL);
  assert(info->IsCompleted());

  assert(m_cRows == 0);
  assert(m_rgRows == NULL);
  assert(m_pbRows == NULL);

  if (cRows == 0)
    return S_OK;

  AutoRelease<RowData, DeleteArray <RowData> > rgAutoRows(new RowData[cRows]);
  if (rgAutoRows == NULL)
    return ErrorInfo::Set(E_OUTOFMEMORY);

  AutoRelease<char, DeleteArray <char> > pbAutoRows(new char[cRows * info->GetRecordSize()]);
  if (pbAutoRows == NULL)
    return ErrorInfo::Set(E_OUTOFMEMORY);

  m_cRows = cRows;
  m_rgRows = rgAutoRows.GiveUp();
  m_pbRows = pbAutoRows.GiveUp();
  for (DBCOUNTITEM iRow = 0; iRow < cRows; iRow++)
    {
      RowData* pRowData = &m_rgRows[iRow];
      pRowData->Init(m_pbRows + iRow * info->GetRecordSize());
    }
  return S_OK;
}

void
ColumnsRowsPolicy::Release()
{
  m_cRows = 0;
  delete [] m_rgRows;
  m_rgRows = NULL;
  delete [] m_pbRows;
  m_pbRows = NULL;
}

bool
ColumnsRowsPolicy::HoldsRows()
{
  return (m_cHeldRows != 0);
}

void
ColumnsRowsPolicy::ReleaseAllRows()
{
  assert(!HoldsRows());
  Release();
}

HRESULT
ColumnsRowsPolicy::AllocateRows(HROW hRowBase, DBCOUNTITEM cRows, const DataRecordInfo* info)
{
  for (DBCOUNTITEM iRow = 0; iRow < cRows; iRow++)
    {
      HROW hRow = hRowBase + iRow;
      assert(hRow > 0 && hRow <= m_cRows);

      RowData* pRowData = &m_rgRows[hRow - 1];
      if (pRowData->GetStatus() == 0 && pRowData->GetRefRow() == 0)
	{
	  //pRowData->Init(m_pbRows + (hRow - 1) * info->GetRecordSize());
	  // TODO: if a failure happens before AddRef the count of held rows can become wrong.
	  m_cHeldRows++;
	}
    }

  return S_OK;
}

RowData*
ColumnsRowsPolicy::GetRowData(HROW hRow)
{
  assert(hRow > 0 && hRow <= m_cRows);
  return &m_rgRows[hRow - 1];
}

void
ColumnsRowsPolicy::ReleaseRowData(HROW hRow)
{
  assert(hRow > 0 && hRow <= m_cRows);
  m_rgRows[hRow - 1].m_iRef = 0;
  m_rgRows[hRow - 1].m_status = 0;
  m_cHeldRows--;
}

void
ColumnsRowsPolicy::DeleteRow(RowData* pRowData)
{
  // shouldn't be really used cause the columns rowsets are always read-only
  assert(pRowData != NULL);
  pRowData->m_pbData = NULL;
  pRowData->m_status = DBPENDINGSTATUS_INVALIDROW;
}

DBCOUNTITEM
ColumnsRowsPolicy::GetActiveRows()
{
  // shouldn't be really used cause the columns rowsets are always read-only
  return m_cHeldRows;
}

void
ColumnsRowsPolicy::GetActiveRowHandles(HROW rghRows[])
{
  // shouldn't be really used cause the columns rowsets are always read-only
  int iRow = 0;
  for (DBCOUNTITEM i = 0; i < m_cRows; i++)
    {
      if (m_rgRows[i].GetRefRow() > 0)
	rghRows[iRow++] = i + 1;
    }
}

/**********************************************************************/
/* RowsetPolicy                                                       */

RowsetPolicy::RowsetPolicy(RowsetInfo* pRowsetInfo, AbstractRowPolicy* pRowPolicy)
{
  assert(pRowsetInfo != NULL);
  assert(pRowPolicy != NULL);
  m_pRowsetInfo = pRowsetInfo;
  m_pRowPolicy = pRowPolicy;
  m_hRowBase = 0;
  m_cRows = 0;
  m_cRowsMax = 0;
  m_cRowsFetched = 0;
  m_rgRowStatus = NULL;
  m_cbBindOffset = 0;
  m_pbBindOrigin = NULL;
  m_pStreamSync = NULL;
  m_pStream = NULL;
}

RowsetPolicy::~RowsetPolicy()
{
  Release();
}

void
RowsetPolicy::Release()
{
  if (m_rgRowStatus != NULL)
    {
      delete [] m_rgRowStatus;
      m_rgRowStatus = NULL;
      m_cRows = 0;
      m_cRowsMax = 0;
      m_cRowsFetched = 0;
    }
  if (m_pStreamSync != NULL)
    {
      m_pStreamSync->SetRowsetStatus(false);
      m_pStreamSync = NULL;
    }
  m_statement.Release();
}

HRESULT
RowsetPolicy::Init(Statement& statement)
{
  m_statement = statement;

  SQLRETURN rc;
  HSTMT hstmt = statement.GetHSTMT();
  rc = SQLSetStmtAttr(hstmt, SQL_ATTR_ROW_BIND_TYPE, (SQLPOINTER) m_pRowsetInfo->GetRecordSize(), SQL_IS_INTEGER);
  if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
    {
      TRACE((__FILE__, __LINE__, "RowsetPolicy::Init(): SQLSetStmtAttr() failed.\n"));
      return ErrorInfo::Set(E_FAIL, SQL_HANDLE_STMT, hstmt);
    }
  rc = SQLSetStmtAttr(hstmt, SQL_ATTR_ROWS_FETCHED_PTR, &m_cRowsFetched, SQL_IS_POINTER);
  if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
    {
      TRACE((__FILE__, __LINE__, "RowsetPolicy::Init(): SQLSetStmtAttr() failed.\n"));
      return ErrorInfo::Set(E_FAIL, SQL_HANDLE_STMT, hstmt);
    }
  rc = SQLSetStmtAttr(hstmt, SQL_ATTR_ROW_BIND_OFFSET_PTR, &m_cbBindOffset, SQL_IS_POINTER);
  if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
    {
      TRACE((__FILE__, __LINE__, "RowsetPolicy::Init(): SQLSetStmtAttr() failed.\n"));
      return ErrorInfo::Set(E_FAIL, SQL_HANDLE_STMT, hstmt);
    }
  if (m_pRowsetInfo->HasBookmark())
    {
      rc = SQLSetStmtAttr(hstmt, SQL_ATTR_FETCH_BOOKMARK_PTR, &m_ulFetchBookmark, SQL_IS_POINTER);
      if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
	{
	  TRACE((__FILE__, __LINE__, "RowsetPolicy::Init(): SQLSetStmtAttr() failed.\n"));
	  return ErrorInfo::Set(E_FAIL, SQL_HANDLE_STMT, hstmt);
	}
    }

  m_pStreamSync = new LobStreamSyncObj();
  if (m_pStreamSync == NULL)
    return ErrorInfo::Set(E_OUTOFMEMORY);
  m_pStreamSync->SetRowsetStatus(true);

  return S_OK;
}

GetDataHandler*
RowsetPolicy::GetGetDataHandler()
{
  return this;
}

SetDataHandler*
RowsetPolicy::GetSetDataHandler()
{
  return this;
}

void
RowsetPolicy::KillStreamObject()
{
  LOGCALL (("RowsetPolicy::KillStreamObject()\n"));

  if (m_pStreamSync != NULL)
    {
      CriticalSection critical_section(m_pStreamSync);
      if (m_pStreamSync->IsStreamAlive())
	{
	  assert(m_pStream != NULL);
	  m_pStream->Kill();
	  m_pStream = NULL;
	}
    }
}

bool
RowsetPolicy::IsStreamObjectAlive()
{
  LOGCALL (("RowsetPolicy::IsStreamObjectAlive()\n"));

  CriticalSection critical_section(m_pStreamSync);
  return m_pStreamSync->IsStreamAlive();
}

HRESULT
RowsetPolicy::SetRowArraySize(DBCOUNTITEM cRows)
{
  LOGCALL (("RowsetPolicy::SetRowArraySize(%ld)\n", (unsigned long) cRows));
  if (m_cRows == cRows)
    return S_OK;

  SQLRETURN rc;
  HSTMT hstmt = m_statement.GetHSTMT();

  m_cRows = 0;
  if (cRows > m_cRowsMax)
    {
      m_cRowsMax = 0;

      delete [] m_rgRowStatus;
      m_rgRowStatus = new SQLUSMALLINT[cRows];
      if (m_rgRowStatus == NULL)
	return ErrorInfo::Set(E_OUTOFMEMORY);

      //delete [] m_rghRowsObtained;
      //m_rghRowsObtained = new HROW[cRows];
      //if (m_rghRowsObtained == NULL)
	//return ErrorInfo::Set(E_OUTOFMEMORY);

      rc = SQLSetStmtAttr(hstmt, SQL_ATTR_ROW_STATUS_PTR, m_rgRowStatus, SQL_IS_POINTER);
      if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
	{
	  TRACE((__FILE__, __LINE__, "RowsetPolicy::SetRowArraySize: SQLSetStmtAttr() failed.\n"));
	  return ErrorInfo::Set(E_FAIL, SQL_HANDLE_STMT, hstmt);
	}

      m_cRowsMax = cRows;
    }

  rc = SQLSetStmtAttr(hstmt, SQL_ATTR_ROW_ARRAY_SIZE, (SQLPOINTER) cRows, SQL_IS_INTEGER);
  if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
    {
      TRACE((__FILE__, __LINE__, "RowsetPolicy::SetRowArraySize(): SQLSetStmtAttr() failed.\n"));
      return ErrorInfo::Set(E_FAIL, SQL_HANDLE_STMT, hstmt);
    }

  m_cRows = cRows;
  return S_OK;
}

HRESULT
RowsetPolicy::BindRows(HROW hRowBase, DBCOUNTITEM cRows)
{
  LOGCALL (("RowsetPolicy::BindRows\n"));
  HRESULT hr = SetRowArraySize(cRows);
  if (FAILED(hr))
    return hr;

  hr = m_pRowPolicy->AllocateRows(hRowBase, cRows, m_pRowsetInfo);
  if (FAILED(hr))
    return hr;

  m_hRowBase = hRowBase;

#if CONTIGUOUS_ROWS
  char* pbRowData = m_pRowPolicy->GetRowData(hRowBase)->GetData();
  assert(pbRowData != NULL);

  /* In case columns were already bound to a buffer just set bind offset and return. */
  if (m_pbBindOrigin != NULL)
    {
      m_cbBindOffset = pbRowData - m_pbBindOrigin;
      return S_OK;
    }

  m_cbBindOffset = 0;
  m_pbBindOrigin = pbRowData;

  /* Bind columns to a newly created buffer. */
  HSTMT hstmt = m_statement.GetHSTMT();
  for (DBORDINAL i = 0; i < GetFieldCount(); i++)
    {
      const DataFieldInfo& info = GetFieldInfo(i);
      if (info.IsLong())
	continue;

      LOG (("RowsetPolicy::BindRows bind fld=%d, ctype=%d, len=%ld\n",
	    (int) i,
	    (int) info.GetSqlCType (),
	    (long) info.GetInternalLength ()));
      SQLRETURN rc = SQLBindCol(hstmt, (SQLUSMALLINT)IndexToOrdinal(i), 
				info.GetSqlCType(),
				GetFieldBuffer(pbRowData, i),
				info.GetInternalLength(),
				GetFieldLengthPtr(pbRowData, i));
      if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
	{
	  TRACE((__FILE__, __LINE__, "RowsetPolicy::BindRows(): SQLBindCol() failed.\n"));
	  return ErrorInfo::Set(E_FAIL, SQL_HANDLE_STMT, hstmt);
	}
    }
#endif

  return S_OK;
}

// pbRowData could differ from pRowData->GetData() if called from GetVisibleData.
HRESULT
RowsetPolicy::InitRow(ULONG iRow, RowData* pRowData, char* pbRowData)
{
  assert(pRowData != NULL);
  LOGCALL (("RowsetPolicy::InitRow\n"));

  if (pbRowData == NULL)
    {
      pbRowData = pRowData->GetData();
      assert(pbRowData != NULL);
    }

  if (m_rgRowStatus[iRow] == SQL_ROW_DELETED)
    {
      // FIXME: It might be better to call DeleteData() somewhere later (in the calling function)
      m_pRowPolicy->DeleteRow(pRowData);
      return ErrorInfo::Set(DB_E_DELETEDROW);
    }

  if (m_rgRowStatus[iRow] == SQL_ROW_ERROR)
    {
      for (ULONG iField = 0; iField < m_pRowsetInfo->GetFieldCount(); iField++)
	{
	  const DataFieldInfo& info = m_pRowsetInfo->GetFieldInfo(iField);
	  m_pRowsetInfo->SetFieldLength(pbRowData, iField, 0);
	  m_pRowsetInfo->SetColumnStatus(pbRowData, iField, COLUMN_STATUS_UNAVAILABLE);
	}
      return S_OK;
    }

  HRESULT hr = SetRowPos((SQLSETPOSIROW)(iRow + 1));
  if (FAILED(hr))
    return hr;

  LOG (("RowsetPolicy::InitRow fld_count=%d\n", m_pRowsetInfo->GetFieldCount ()));
  for (ULONG iField = 0; iField < m_pRowsetInfo->GetFieldCount(); iField++)
    {
      const DataFieldInfo& info = m_pRowsetInfo->GetFieldInfo(iField);
      if (info.IsLong())
	{
	  m_pRowsetInfo->SetFieldLength(pbRowData, iField, 0);
	  m_pRowsetInfo->SetColumnStatus(pbRowData, iField, COLUMN_STATUS_UNCHANGED);
	  LOG (("RowsetPolicy::InitRow is_long =%d fld=%d sql_type=%d, len=%ld\n",
	    (int) iField,
	    (int) info.GetSqlCType (),
	    (long) info.GetInternalLength ()));
	  continue;
	}

      SQLUSMALLINT iFieldOrdinal = (SQLUSMALLINT) m_pRowsetInfo->IndexToOrdinal(iField);

      SQLLEN cbLength;
      SQLHSTMT hstmt = m_statement.GetHSTMT ();
      SQLSMALLINT SqlCType = info.GetSqlCType ();
      ULONG InternalLength = info.GetInternalLength ();
      char * buf = m_pRowsetInfo->GetFieldBuffer(pbRowData, iField);
      LOG (("RowsetPolicy::InitRow req fld=%d sql_type=%d, len=%ld\n",
	    (int) iField,
	    (int) SqlCType,
	    (long) InternalLength));
      if (info.GetSqlCType () == SQL_C_USHORT)
	{
	  LOG (("RowsetPolicy::InitRow before ret=%u\n",
	  (unsigned) *((unsigned short *)buf)));
	}
      SQLRETURN rc = SQLGetData(hstmt, iFieldOrdinal, SqlCType,
				buf,
				InternalLength, &cbLength);
      LOG (("RowsetPolicy::InitRow rc=%d fld=%d sql_type=%d, len=%ld\n",
	    (int) rc,
	    (int) iField,
	    (int) SqlCType,
	    (long) cbLength));
      if (info.GetSqlCType () == SQL_C_USHORT)
	{
	  LOG (("RowsetPolicy::InitRow ret=%u\n",
	  (unsigned) *((unsigned short *)buf)));
	}

      if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
	{
	  m_pRowsetInfo->SetFieldLength(pbRowData, iField, 0);
	  m_pRowsetInfo->SetColumnStatus(pbRowData, iField, COLUMN_STATUS_UNAVAILABLE);
	  continue;
	}
      m_pRowsetInfo->SetFieldLength(pbRowData, iField, cbLength);
      m_pRowsetInfo->SetColumnStatus(pbRowData, iField, COLUMN_STATUS_UNCHANGED);
    }

  return S_OK;
}

HRESULT
RowsetPolicy::InitRows()
{
  ULONG iRow;

  for (iRow = 0; iRow < m_cRowsFetched; iRow++)
    {
      HROW hRow = m_hRowBase + iRow;
      RowData* pRowData = m_pRowPolicy->GetRowData(hRow);
      assert(pRowData != NULL);

      pRowData->AddRefRow();

      // FIXME: Is it necessary to AddRef rows with DBPENDINGSTATUS_DELETED too?
      DBPENDINGSTATUS dwPendingStatus = pRowData->GetStatus();
      if (dwPendingStatus != 0)
	continue;

      HRESULT hr = InitRow(iRow, pRowData);
      if (hr == DB_E_DELETEDROW)
	{
	  ErrorInfo::Clear();
	  continue;
	}

      pRowData->SetStatus(DBPENDINGSTATUS_UNCHANGED);

      if (m_pRowsetInfo->HasBookmark())
	{
	  ULONG ulBookmark = *(ULONG*) m_pRowsetInfo->GetFieldBuffer(pRowData->GetData(), 0);
	  hr = BookmarkRow(hRow, ulBookmark);
	  if (FAILED(hr))
	    return hr;
	}
    }

  for (iRow = m_cRowsFetched; iRow < m_cRows; iRow++)
    {
      HROW hRow = m_hRowBase + iRow;
      m_pRowPolicy->ReleaseRowData(hRow);
    }

  return S_OK;
}

DBCOUNTITEM
RowsetPolicy::GetRowsObtained()
{
  return m_cRowsFetched;
}

HRESULT
RowsetPolicy::ResetLongData(HROW iRecordID, DBORDINAL iFieldOrdinal)
{
  LOGCALL (("RowsetPolicy::ResetLongData(iRecordID=%d, iFieldOrdinal=%d)\n", iRecordID, iFieldOrdinal));

  CriticalSection critical_section(m_pStreamSync);
  if (m_pStreamSync->IsStreamAlive())
    return DB_E_OBJECTOPEN;

  HRESULT hr = SnatchRow(iRecordID);
  if (FAILED(hr))
    return hr;

  return SetRowPos((SQLSETPOSIROW)(iRecordID - m_hRowBase + 1));
}

HRESULT
RowsetPolicy::GetLongData(
  HROW iRecordID,
  DBORDINAL iFieldOrdinal,
  SQLSMALLINT wSqlCType,
  char* pv,
  DBLENGTH cb,
  SQLLEN& rcb
)
{
  LOGCALL(("RowsetPolicy::GetLongData(field=%d, wSqlCType = %d, pv=%p, cb=%ld)\n", iFieldOrdinal, wSqlCType, pv,
	(long) cb));

  SQLRETURN rc = SQLGetData(m_statement.GetHSTMT(), (SQLUSMALLINT) iFieldOrdinal, wSqlCType, pv, cb, &rcb);
  LOG (("RowsetPolicy::GetLongData() rc = %d, rcb=%ld\n",
	(int) rc,
	(long) rcb));
  if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
    {
      if (rc == SQL_NO_DATA)
	return S_FALSE;

      TRACE((__FILE__, __LINE__, "RowsetPolicy::GetLongData(): SQLGetData() failed.\n"));
      m_statement.DoDiagnostics();
      return ErrorInfo::Set(E_FAIL, SQL_HANDLE_STMT,  m_statement.GetHSTMT());
    }
  return S_OK;
}

HRESULT
RowsetPolicy::CreateStreamObject(
  HROW iRecordID,
  DBORDINAL iFieldOrdinal,
  SQLSMALLINT wSqlCType,
  REFIID riid,
  IUnknown** ppUnk
)
{
  LOGCALL (("RowsetPolicy::CreateStreamObject()\n"));

  assert(ppUnk != NULL);
  *ppUnk = NULL;

  assert(m_pStreamSync != NULL);
  CriticalSection critical_section(m_pStreamSync);
  if (m_pStreamSync->IsStreamAlive())
    return DB_E_OBJECTOPEN;

  HRESULT hr = SnatchRow(iRecordID);
  if (FAILED(hr))
    return hr;
  hr = SetRowPos((SQLSETPOSIROW)(iRecordID - m_hRowBase + 1));
  if (FAILED(hr))
    return hr;

  SQLLEN cb;
  char dummy[1];
  hr = GetLongData(iRecordID, iFieldOrdinal, wSqlCType, dummy, 0, cb);
  if (FAILED(hr))
    return hr;
  if (cb == SQL_NULL_DATA)
    return S_FALSE;

  CGetDataSequentialStreamInitializer initializer = {
    m_pStreamSync, this, iRecordID, iFieldOrdinal, wSqlCType
  };

  return ComImmediateObj<CGetDataSequentialStream>::CreateInstance (
    NULL, riid, (void**) ppUnk, &initializer, &m_pStream
  );
}

HRESULT
RowsetPolicy::SetDataAtExec(
  HROW iRecordID,
  DBORDINAL iFieldOrdinal,
  SQLSMALLINT wSqlCType,
  DBCOUNTITEM iBinding
)
{
  LOGCALL(("RowsetPolicy::SetDataAtExec()\n"));

  RowData* pRowData = m_pRowPolicy->GetRowData(iRecordID);
  char* pbRowData = pRowData->GetData();

  ULONG iField = m_pRowsetInfo->OrdinalToIndex(iFieldOrdinal);
  m_pRowsetInfo->SetColumnStatus(pbRowData, iField, COLUMN_STATUS_CHANGED);
  m_pRowsetInfo->SetFieldLength(pbRowData, iField, SQL_DATA_AT_EXEC);

  DBCOUNTITEM* plColumnData = (DBCOUNTITEM*) m_pRowsetInfo->GetFieldBuffer(pbRowData, iField);
  *plColumnData = iBinding;

  return S_OK;
}

HRESULT
RowsetPolicy::GetDataAtExec(HROW& iRecordID, DBCOUNTITEM& iBinding)
{
  LOGCALL(("RowsetPolicy::GetDataAtExec()\n"));

  LONG* plColumnData = 0;
  SQLRETURN rc = SQLParamData(m_statement.GetHSTMT(), (SQLPOINTER*) &plColumnData);
  if (rc == SQL_NEED_DATA)
    {
      iRecordID = 0;
      iBinding = *plColumnData;
      LOG(("column: %d, binding: %d\n", iRecordID, iBinding));
      return S_OK;
    }
  if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
    {
      TRACE((__FILE__, __LINE__, "RowsetPolicy::GetDataAtExec(): SQLParamData() failed.\n"));
      m_statement.DoDiagnostics();
      return ErrorInfo::Set(E_FAIL, SQL_HANDLE_STMT, m_statement.GetHSTMT());
    }

  return S_FALSE;
}

HRESULT
RowsetPolicy::PutDataAtExec(char* pv, SQLINTEGER cb)
{
  LOGCALL(("RowsetPolicy::PutDataAtExec(pv = %x, cb = %d\n", pv, cb));

  SQLRETURN rc = SQLPutData(m_statement.GetHSTMT(), pv, cb);
  if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
    {
      TRACE((__FILE__, __LINE__, "RowsetPolicy::PutDataAtExec(): SQLPutData() failed.\n"));
      m_statement.DoDiagnostics();
      return ErrorInfo::Set(E_FAIL, SQL_HANDLE_STMT, m_statement.GetHSTMT());
    }
  return S_OK;
}

HRESULT
RowsetPolicy::SnatchRow(HROW hRow)
{
  assert(hRow >= m_hRowBase && hRow < m_hRowBase + m_cRowsFetched);
  return S_OK;
}

HRESULT
RowsetPolicy::BookmarkRow(HROW hRow, ULONG ulBookmark)
{
  return S_OK;
}

HRESULT
RowsetPolicy::SetRowPos(SQLSETPOSIROW iPosition)
{
  LOGCALL(("RowsetPolicy::SetRowPos(iPosition = %d)\n", iPosition));

  assert((SQLINTEGER)iPosition > 0 && (SQLINTEGER)iPosition <= m_cRowsFetched);

  HSTMT hstmt = m_statement.GetHSTMT();
  SQLRETURN rc = SQLSetPos(hstmt, iPosition, SQL_POSITION, SQL_LOCK_NO_CHANGE);
  if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
    {
      TRACE((__FILE__, __LINE__, "RowsetPolicy::SetRowPos(): SQLSetPos() failed.\n"));
      m_statement.DoDiagnostics();
      return ErrorInfo::Set(E_FAIL, SQL_HANDLE_STMT, hstmt);
    }

  return S_OK;
}

/**********************************************************************/
/* ForwardOnlyPolicy                                                  */

HRESULT
ForwardOnlyPolicy::GetNextRows(DBROWOFFSET lRowsOffset, DBROWCOUNT cRows)
{
  LOGCALL(("ForwardOnlyPolicy::GetNextRows(lRowsOffset=%d, cRows=%d)\n", lRowsOffset, cRows));

  assert(cRows != 0);

  if (lRowsOffset < 0)
    return ErrorInfo::Set(DB_E_CANTSCROLLBACKWARDS);
  if (cRows < 0)
    return ErrorInfo::Set(DB_E_CANTFETCHBACKWARDS);

  HROW hRowBase = m_hRowBase + m_cRowsFetched + lRowsOffset + 1;

  m_cRowsFetched = 0;

  if (lRowsOffset > 0)
    {
      HRESULT hr = SkipNextRows(lRowsOffset);
      if (FAILED(hr))
	return hr;
    }

  HRESULT hr = BindRows(hRowBase, cRows);
  if (FAILED(hr))
    return hr;
  hr = FetchNextRows();
  if (FAILED(hr))
    return hr;
  hr = InitRows();
  if (FAILED(hr))
    return hr;

  if (m_cRowsFetched < m_cRows)
    return DB_S_ENDOFROWSET;
  return S_OK;
}

void
ForwardOnlyPolicy::GetRowHandlesObtained(HROW* rghRows)
{
  LOGCALL(("ForwardOnlyPolicy::GetRowHandlesObtained()\n"));

  for (ULONG iRow = 0; iRow < m_cRowsFetched; iRow++)
    rghRows[iRow] = m_hRowBase + iRow;
}

HRESULT
ForwardOnlyPolicy::RestartPosition()
{
  LOGCALL(("ForwardOnlyPolicy::RestartPosition()\n"));

  if (m_pRowPolicy->HoldsRows())
    return ErrorInfo::Set(DB_E_ROWSNOTRELEASED);

  m_pRowPolicy->ReleaseAllRows();

  DBORDINAL cFields = m_pRowsetInfo->GetFieldCount();
  AutoRelease<DataFieldInfo, DeleteArray <DataFieldInfo> > rgFields(new DataFieldInfo[cFields]);
  if (rgFields == NULL)
    return ErrorInfo::Set(E_OUTOFMEMORY);

  ULONG iField;
  for (iField = 0; iField < cFields; iField++)
    rgFields[iField] = m_pRowsetInfo->GetFieldInfo(iField);

  HRESULT hr;
  if (m_pCommandHandler != NULL)
    hr = m_pCommandHandler->Reexecute();
  else
    hr = m_statement.Reexecute();
  if (FAILED(hr))
    return hr;

  hr = const_cast<RowsetInfo*>(m_pRowsetInfo)->Init(m_statement);
  if (FAILED(hr))
    return hr;
  hr = const_cast<RowsetInfo*>(m_pRowsetInfo)->Complete();
  if (FAILED(hr))
    return hr;

  bool fColumnsChanged = false;
  if (cFields != m_pRowsetInfo->GetFieldCount())
    {
      fColumnsChanged = true;
    }
  else
    {
      for (iField = 0; iField < cFields; iField++)
	{
	  const DataFieldInfo& info1 = rgFields[iField];
	  const DataFieldInfo& info2 = m_pRowsetInfo->GetFieldInfo(iField);
	  if (info1.GetSqlCType() != info2.GetSqlCType()
	      || info1.GetOdbcColumnSize() != info2.GetOdbcColumnSize()
	      || info1.GetOdbcDecimalDigits() != info2.GetOdbcDecimalDigits()
	      || info1.GetFlags() != info2.GetFlags()
	      || info1.GetName() != info2.GetName())
	    {
	      fColumnsChanged = true;
	      break;
	    }
	}
    }

  if (fColumnsChanged)
    {
      HSTMT hstmt = m_statement.GetHSTMT();
      SQLRETURN rc = SQLSetStmtAttr(hstmt, SQL_ATTR_ROW_BIND_TYPE,
				    (SQLPOINTER) m_pRowsetInfo->GetRecordSize(), SQL_IS_INTEGER);
      if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
	{
	  TRACE((__FILE__, __LINE__, "ForwardOnlyPolicy::RestartPosition(): SQLSetStmtAttr() failed.\n"));
	  return ErrorInfo::Set(E_FAIL);
	}

      return DB_S_COLUMNSCHANGED;
    }

  return DB_S_COMMANDREEXECUTED;
}

HRESULT
ForwardOnlyPolicy::SkipNextRows(DBCOUNTITEM lRowsOffset)
{
  LOGCALL(("ForwardOnlyPolicy::SkipNextRows(lRowsOffset = %d)\n", lRowsOffset));

  HSTMT hstmt = m_statement.GetHSTMT();
  SQLSetStmtAttr(hstmt, SQL_ATTR_RETRIEVE_DATA, (SQLPOINTER) SQL_RD_OFF, SQL_IS_INTEGER);

  HRESULT hr = S_OK;
  while (lRowsOffset > 0)
    {
      DBCOUNTITEM cRowsToSkip = m_cRowsMax == 0 ? 1 : m_cRowsMax < lRowsOffset ? m_cRowsMax : lRowsOffset;

      HRESULT hr = SetRowArraySize(cRowsToSkip);
      if (FAILED(hr))
	break;

      SQLRETURN rc = SQLFetchScroll(hstmt, SQL_FETCH_NEXT, 0);
      if (rc == SQL_NO_DATA)
	break;

      if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
	{
	  TRACE((__FILE__, __LINE__, "ForwardOnlyPolicy::SkipNextRows(): SQLFetchScroll() failed.\n"));
	  m_statement.DoDiagnostics();
	  ErrorInfo::Set(E_FAIL);
	  break;
	}

      lRowsOffset -= m_cRowsFetched;
    }

  SQLSetStmtAttr(hstmt, SQL_ATTR_RETRIEVE_DATA, (SQLPOINTER) SQL_RD_ON, SQL_IS_INTEGER);
  return hr;
}

HRESULT
ForwardOnlyPolicy::FetchNextRows()
{
  LOGCALL(("ForwardOnlyPolicy::FetchNextRows()\n"));

  HSTMT hstmt = m_statement.GetHSTMT();
  SQLRETURN rc = SQLFetchScroll(hstmt, SQL_FETCH_NEXT, 0);
  if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO && rc != SQL_NO_DATA)
    {
      TRACE((__FILE__, __LINE__, "ForwardOnlyPolicy::FetchNextRows(): SQLFetchScroll() failed.\n"));
      m_statement.DoDiagnostics();
      return ErrorInfo::Set(E_FAIL, SQL_HANDLE_STMT, hstmt);
    }

  return S_OK;
}

/**********************************************************************/
/* ScrollbalePolicy                                                   */

HRESULT
ScrollablePolicy::GetNextRows(DBROWOFFSET lRowsOffset, DBROWCOUNT cRows)
{
  LOGCALL(("ScrollablePolicy::GetNextRows(lRowsOffset=%d, cRows=%d)\n", lRowsOffset, cRows));

  assert(cRows != 0);

  SQLSMALLINT wFetchOrientation;
  DBROWOFFSET lFetchOffset;
  if (m_fStartPos)
    {
      wFetchOrientation = SQL_FETCH_ABSOLUTE;
      if (lRowsOffset < 0 || lRowsOffset == 0 && cRows < 0)
	lFetchOffset = lRowsOffset;
      else
	lFetchOffset = lRowsOffset + 1;
    }
  else
    {
      wFetchOrientation = SQL_FETCH_RELATIVE;
      if (m_fBackward)
	lFetchOffset = lRowsOffset;
      else
	lFetchOffset = lRowsOffset + m_cRowsFetched;
    }

  if (cRows < 0)
    {
      m_fBackward = true;
      cRows = cRows == LONG_MIN ? LONG_MAX : -cRows;
      lFetchOffset -= cRows;
    }
  else
    {
      m_fBackward = false;
    }

  HROW hRowBase = m_hRowBase + m_cRowsFetched + 1;
  if (hRowBase < m_hRowBase) // got integer overflow
    hRowBase = 1;

  m_fStartPos = false;
  m_cRowsFetched = 0;
  HRESULT hr = BindRows(hRowBase, cRows);
  if (FAILED(hr))
    return hr;
  hr = Fetch(wFetchOrientation, lFetchOffset);
  if (FAILED(hr))
    return hr;
  hr = InitRows();
  if (FAILED(hr))
    return hr;

  if (m_cRowsFetched < m_cRows)
    return DB_S_ENDOFROWSET;
  return S_OK;
}

void
ScrollablePolicy::GetRowHandlesObtained(HROW* rghRows)
{
  LOGCALL(("ScrollablePolicy::GetRowHandlesObtained()\n"));

  for (ULONG iRow = 0; iRow < m_cRowsFetched; iRow++)
    {
      if (m_fBackward)
	rghRows[m_cRowsFetched - iRow - 1] = m_hRowBase + iRow;
      else
	rghRows[iRow] = m_hRowBase + iRow;
    }
}

HRESULT
ScrollablePolicy::RestartPosition()
{
  LOGCALL(("ScrollablePolicy::RestartPosition()\n"));

  m_fStartPos = true;
  return S_OK;
}

HRESULT
ScrollablePolicy::CreateRow(HROW& hRow)
{
  LOGCALL(("ScrollablePolicy::CreateRow()\n"));

  HROW hRowBase = m_hRowBase + m_cRowsFetched + 1;
  if (hRowBase < m_hRowBase) // got integer overflow
    hRowBase = 1;

  m_cRowsFetched = 0;
  HRESULT hr = BindRows(hRowBase, 1);
  if (FAILED(hr))
    return hr;

  hRow = hRowBase;
  return S_OK;
}

HRESULT
ScrollablePolicy::InsertRow(HROW hRow)
{
  LOGCALL(("ScrollablePolicy::InsertRow(hRow=%d)\n", hRow));

  RowData* pRowData = m_pRowPolicy->GetRowData(hRow);
  assert(pRowData != NULL);

  HRESULT hr = BindColumns(pRowData->GetData(), 1, false);
  if (FAILED(hr))
    return hr;
  hr = Insert();
  UnbindColumns(pRowData->GetData(), false);
  return hr;
}

HRESULT
ScrollablePolicy::UpdateRow(HROW hRow, bool fDeferred)
{
  LOGCALL(("ScrollablePolicy::UpdateRow(hRow=%d)\n", hRow));

  HRESULT hr = SnatchRow(hRow);
  if (FAILED(hr))
    return hr;

  RowData* pRowData = m_pRowPolicy->GetRowData(hRow);
  assert(pRowData != NULL);

  hr = BindColumns(pRowData->GetData(), (SQLSETPOSIROW)(hRow - m_hRowBase + 1), fDeferred);
  if (FAILED(hr))
    return hr;

  hr = Update((SQLSETPOSIROW)(hRow - m_hRowBase + 1));
  UnbindColumns(pRowData->GetData(), fDeferred);
  return hr;
}

HRESULT
ScrollablePolicy::DeleteRow(HROW hRow)
{
  LOGCALL(("ScrollablePolicy::DeleteRow(hRow=%d)\n", hRow));

  HRESULT hr = SnatchRow(hRow);
  if (FAILED(hr))
    return hr;

  return Delete((SQLSETPOSIROW)(hRow - m_hRowBase + 1));
}

HRESULT
ScrollablePolicy::ResyncRow(HROW hRow, char* pbData)
{
  LOGCALL(("ScrollablePolicy::ResyncRow(hRow=%d)\n", hRow));

  HRESULT hr = SnatchRow(hRow);
  if (FAILED(hr))
    return hr;

  hr = Refresh((SQLSETPOSIROW)(hRow - m_hRowBase + 1));
  if (FAILED(hr))
    return hr;

  RowData* pRowData = m_pRowPolicy->GetRowData(hRow);
  assert(pRowData != NULL);

  return InitRow((ULONG)(hRow - m_hRowBase), pRowData, pbData);
}

HRESULT
ScrollablePolicy::BindColumns(char* pbRowData, SQLSETPOSIROW iPosition, bool fDeferred)
{
  LOGCALL(("ScrollablePolicy::BindColumns(pbData=%x, iPosition=%d, fDeferred=%d)\n",
	   pbRowData, iPosition, fDeferred));

  assert(pbRowData != NULL);
  assert(iPosition > 0);

  ULONG cbOffset = m_pRowsetInfo->GetRecordSize() * (ULONG)(iPosition - 1);

  pbRowData -= cbOffset;

  HSTMT hstmt = m_statement.GetHSTMT();
  for (ULONG iField = 0; iField < m_pRowsetInfo->GetFieldCount(); iField++)
    {
      const DataFieldInfo& info = m_pRowsetInfo->GetFieldInfo(iField);
      COLUMN_STATUS status = m_pRowsetInfo->GetColumnStatus(pbRowData, iField);
      if (status != COLUMN_STATUS_CHANGED)
	continue;
      if (fDeferred && !info.IsLong())
	continue;

      SQLUSMALLINT iColumnOrdinal = (SQLUSMALLINT) m_pRowsetInfo->IndexToOrdinal(iField);

#if DEBUG
      DataTransferHandler::LogFieldData(iColumnOrdinal, info,
					pbRowData + info.GetInternalOffset(),
					m_pRowsetInfo->GetFieldLength(pbRowData, iField));
#endif

      LOG (("ScrollablePolicy::BindColumns bind fld=%d, ctype=%d, len=%ld\n",
	    (int) iField,
	    (int) info.GetSqlCType (),
	    (long) info.GetInternalLength ()));
      SQLRETURN rc = SQLBindCol(hstmt, iColumnOrdinal, info.GetSqlCType(),
				m_pRowsetInfo->GetFieldBuffer(pbRowData, iField),
				info.GetInternalLength(),
				m_pRowsetInfo->GetFieldLengthPtr(pbRowData, iField));
      if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
	{
	  TRACE((__FILE__, __LINE__, "ScollablePolicy::BindColumns(): SQLBindCol() failed.\n"));
	  return ErrorInfo::Set(E_FAIL, SQL_HANDLE_STMT, hstmt);
	}
    }

  return S_OK;
}

void
ScrollablePolicy::UnbindColumns(char* pbRowData, bool fDeferred)
{
  LOGCALL(("ScrollablePolicy::UnbindColumns(pbData=%x, fDeferred=%d)\n", pbRowData, fDeferred));

  HSTMT hstmt = m_statement.GetHSTMT();
  for (ULONG iField = 0; iField < m_pRowsetInfo->GetFieldCount(); iField++)
    {
      const DataFieldInfo& info = m_pRowsetInfo->GetFieldInfo(iField);
      COLUMN_STATUS status = m_pRowsetInfo->GetColumnStatus(pbRowData, iField);
      if (status != COLUMN_STATUS_CHANGED)
	continue;
      if (fDeferred && !info.IsLong())
	continue;

      m_pRowsetInfo->SetColumnStatus(pbRowData, iField, COLUMN_STATUS_UNCHANGED);

      SQLUSMALLINT iColumnOrdinal = (SQLUSMALLINT) m_pRowsetInfo->IndexToOrdinal(iField);
      SQLRETURN rc = SQLBindCol(hstmt, iColumnOrdinal, info.GetSqlCType(), NULL, 0, NULL);
      if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
	{
	  TRACE((__FILE__, __LINE__, "ScrollablePolicy::UnbindColumns(): SQLBindCol() failed.\n"));
	}
    }
}

HRESULT
ScrollablePolicy::Fetch(SQLSMALLINT dwOrientation, DBROWOFFSET lRowsOffset)
{
  LOGCALL(("ScrollablePolicy::Fetch(dwOrientation=%d, lRowsOffset=%d)\n", dwOrientation, lRowsOffset));

  HSTMT hstmt = m_statement.GetHSTMT();
  SQLRETURN rc = SQLFetchScroll(hstmt, dwOrientation, lRowsOffset);
  if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO && rc != SQL_NO_DATA)
    {
      TRACE((__FILE__, __LINE__, "ScrollablePolicy::Fetch(): SQLFetchScroll() failed.\n"));
      m_statement.DoDiagnostics();
      return ErrorInfo::Set(E_FAIL, SQL_HANDLE_STMT, hstmt);
    }

  return S_OK;
}

HRESULT
ScrollablePolicy::Refresh(SQLSETPOSIROW iPosition)
{
  LOGCALL(("ScrollablePolicy::Refresh(iPosition = %d)\n", iPosition));

  assert ((SQLINTEGER)iPosition > 0 && (SQLINTEGER)iPosition <= m_cRowsFetched);

  HSTMT hstmt = m_statement.GetHSTMT();
  SQLRETURN rc = SQLSetPos(hstmt, iPosition, SQL_REFRESH, SQL_LOCK_NO_CHANGE);
  if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
    {
      TRACE((__FILE__, __LINE__, "ScrollablePolicy::Refresh(): SQLSetPos() failed.\n"));
      m_statement.DoDiagnostics();
      return ErrorInfo::Set(E_FAIL, SQL_HANDLE_STMT, hstmt);
    }

  return S_OK;
}

HRESULT
ScrollablePolicy::Update(SQLSETPOSIROW iPosition)
{
  LOGCALL(("ScrollablePolicy::Update(iPosition = %d)\n", iPosition));

  assert ((SQLINTEGER)iPosition > 0 && (SQLINTEGER)iPosition <= m_cRowsFetched);

  HSTMT hstmt = m_statement.GetHSTMT();
  SQLRETURN rc = SQLSetPos(hstmt, iPosition, SQL_UPDATE, SQL_LOCK_NO_CHANGE);
  if (rc == SQL_SUCCESS_WITH_INFO)
    {
      char sqlstate[6];
      if (m_statement.GetSqlState(sqlstate))
	{
	  if (strcmp(sqlstate, "01001") == 0)
	    return DB_S_MULTIPLECHANGES;
	}
    }
  else if (rc != SQL_SUCCESS && rc != SQL_NEED_DATA)
    {
      TRACE((__FILE__, __LINE__, "ScrollablePolicy::Update(): SQLSetPos() failed.\n"));
      m_statement.DoDiagnostics();

      char sqlstate[6];
      if (m_statement.GetSqlState(sqlstate))
	{
	  if (strcmp(sqlstate, "23000") == 0)
	    return ErrorInfo::Set(DB_E_INTEGRITYVIOLATION, SQL_HANDLE_STMT, hstmt);
	  if (strcmp(sqlstate, "HY008") == 0)
	    return ErrorInfo::Set(DB_E_CANCELED, SQL_HANDLE_STMT, hstmt);
	}
      return ErrorInfo::Set(E_FAIL, SQL_HANDLE_STMT, hstmt);
    }

  return rc == SQL_NEED_DATA ? S_FALSE : S_OK;
}

HRESULT
ScrollablePolicy::Delete(SQLSETPOSIROW iPosition)
{
  LOGCALL(("ScrollablePolicy::Delete(iPosition = %d)\n", iPosition));

  assert ((SQLINTEGER)iPosition > 0 && (SQLINTEGER)iPosition <= m_cRowsFetched);

  HSTMT hstmt = m_statement.GetHSTMT();
  SQLRETURN rc = SQLSetPos(hstmt, iPosition, SQL_DELETE, SQL_LOCK_NO_CHANGE);
  if (rc == SQL_SUCCESS_WITH_INFO)
    {
      char sqlstate[6];
      if (m_statement.GetSqlState(sqlstate))
	{
	  if (strcmp(sqlstate, "01001") == 0)
	    return DB_S_MULTIPLECHANGES;
	}
    }
  else if (rc != SQL_SUCCESS)
    {
      TRACE((__FILE__, __LINE__, "ScrollablePolicy::Delete(): SQLSetPos() failed.\n"));
      m_statement.DoDiagnostics();

      char sqlstate[6];
      if (m_statement.GetSqlState(sqlstate))
	{
	  if (strcmp(sqlstate, "23000") == 0)
	    return ErrorInfo::Set(DB_E_INTEGRITYVIOLATION, SQL_HANDLE_STMT, hstmt);
	  if (strcmp(sqlstate, "HY008") == 0)
	    return ErrorInfo::Set(DB_E_CANCELED, SQL_HANDLE_STMT, hstmt);
	}
      return ErrorInfo::Set(E_FAIL, SQL_HANDLE_STMT, hstmt);
    }

  return S_OK;
}

HRESULT
ScrollablePolicy::Insert(SQLSETPOSIROW iPosition)
{
  LOGCALL(("ScrollablePolicy::Insert(iPosition = %d)\n", iPosition));

  assert (m_cRows > 0 && iPosition <= m_cRowsMax && iPosition > m_cRowsFetched);

  HSTMT hstmt = m_statement.GetHSTMT();
  SQLRETURN rc = SQLSetPos(hstmt, iPosition, SQL_ADD, SQL_LOCK_NO_CHANGE);
  if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO && rc != SQL_NEED_DATA)
    {
      TRACE((__FILE__, __LINE__, "ScrollablePolicy::Insert(): SQLSetPos() failed.\n"));
      m_statement.DoDiagnostics();

      char sqlstate[6];
      if (m_statement.GetSqlState(sqlstate))
	{
	  if (strcmp(sqlstate, "23000") == 0)
	    return ErrorInfo::Set(DB_E_INTEGRITYVIOLATION, SQL_HANDLE_STMT, hstmt);
	  if (strcmp(sqlstate, "HY008") == 0)
	    return ErrorInfo::Set(DB_E_CANCELED);
	}
      return ErrorInfo::Set(E_FAIL, SQL_HANDLE_STMT, hstmt);
    }

  return rc == SQL_NEED_DATA ? S_FALSE : S_OK;
}

HRESULT
ScrollablePolicy::Insert()
{
  LOGCALL(("ScrollablePolicy::Insert()\n"));

  assert (m_cRows > 0);

  HSTMT hstmt = m_statement.GetHSTMT();
  SQLRETURN rc = SQLBulkOperations(hstmt, SQL_ADD);
  if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO && rc != SQL_NEED_DATA)
    {
      TRACE((__FILE__, __LINE__, "ScrollablePolicy::Insert(): SQLBulkOperations() failed.\n"));
      m_statement.DoDiagnostics();

      char sqlstate[6];
      if (m_statement.GetSqlState(sqlstate))
	{
	  if (strcmp(sqlstate, "23000") == 0)
	    return ErrorInfo::Set(DB_E_INTEGRITYVIOLATION, SQL_HANDLE_STMT, hstmt);
	  if (strcmp(sqlstate, "HY008") == 0)
	    return ErrorInfo::Set(DB_E_CANCELED);
	}
      return ErrorInfo::Set(E_FAIL, SQL_HANDLE_STMT, hstmt);
    }

  return rc == SQL_NEED_DATA ? S_FALSE : S_OK;
}

/**********************************************************************/
/* PositionalPolicy                                                   */

HRESULT
PositionalPolicy::Init(Statement& statement)
{
  HRESULT hr = RowsetPolicy::Init(statement);
  if (FAILED(hr))
    return hr;

  hr = InitRowCount(m_cTotalRows);
  if (FAILED(hr))
    return hr;

  m_hNextNewRow = m_cTotalRows + 1;
  return S_OK;
}

HRESULT
PositionalPolicy::InitRowCount(DBCOUNTITEM& cRows)
{
  LOGCALL(("PositionalPolicy::InitRowCount()\n"));

  HSTMT hstmt = m_statement.GetHSTMT();

  SQLLEN cRowsT;
  SQLRETURN rc = SQLRowCount(hstmt, &cRowsT);
  if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
    {
      TRACE((__FILE__, __LINE__, "PositionalData::InitRowCount(): SQLRowCount() failed.\n"));
      return ErrorInfo::Set(E_FAIL, SQL_HANDLE_STMT, hstmt);
    }

  LOG(("row count: %d\n", cRowsT));

  cRows = cRowsT;
  return S_OK;
}

HRESULT
PositionalPolicy::GetNextRows(DBROWOFFSET lRowsOffset, DBROWCOUNT cRows)
{
  LOGCALL(("PositionalPolicy::GetNextRows(lRowsOffset=%d, cRows=%d)\n", lRowsOffset, cRows));

  assert(cRows != 0);

  // In initial position the next fetch position depends on the given offset or fetch
  // direction. Otherwise it depends on the previous fetches.
  DBCOUNTITEM iNextFetch;
  if (m_fStartPos)
    {
      if (lRowsOffset < 0 || lRowsOffset == 0 && cRows < 0)
	iNextFetch = m_cTotalRows + lRowsOffset;
      else
	iNextFetch = lRowsOffset;
    }
  else
    {
      iNextFetch =  m_nNextFetch + lRowsOffset;
    }

  HROW hRowBase;
  if (cRows < 0)
    {
      if (iNextFetch <= 0 || iNextFetch > m_cTotalRows)
	{
	  m_cRowsObtained = 0;
	  return DB_S_ENDOFROWSET;
	}

      m_fBackward = true;
      if (iNextFetch + cRows < 0)
	{
	  m_nNextFetch = 0;
	  cRows = iNextFetch - m_nNextFetch;
	}
      else
	{
	  m_nNextFetch = iNextFetch + cRows;
	  cRows = -cRows;
	}

      hRowBase = m_nNextFetch + 1;
    }
  else
    {
      if (iNextFetch < 0 || iNextFetch >= m_cTotalRows)
	{
	  m_cRowsObtained = 0;
	  return DB_S_ENDOFROWSET;
	}

      m_fBackward = false;
      if (iNextFetch + cRows > m_cTotalRows)
	{
	  m_nNextFetch = m_cTotalRows;
	  cRows = m_nNextFetch - iNextFetch;
	}
      else
	m_nNextFetch = iNextFetch + cRows;

      hRowBase = iNextFetch + 1;
    }

  SQLSMALLINT wFetchOrientation = SQL_FETCH_ABSOLUTE;
  DBROWOFFSET lFetchOffset = (DBROWOFFSET)hRowBase;

  DBROWOFFSET lReverseOffset = (DBROWOFFSET)(m_cTotalRows - hRowBase + 1);
  if (lReverseOffset < lFetchOffset)
    lFetchOffset = -lReverseOffset;

  if (!m_fStartPos)
    {
      DBROWOFFSET lRelativeOffset = (DBROWOFFSET)(hRowBase - m_hRowBase);
      if (abs(lRelativeOffset) < abs(lFetchOffset))
	{
	  if (lRelativeOffset == 1)
	    wFetchOrientation = SQL_FETCH_NEXT;
	  else if (lRelativeOffset == -1)
	    wFetchOrientation = SQL_FETCH_PREV;
	  else
	    {
	      wFetchOrientation = SQL_FETCH_RELATIVE;
	      lFetchOffset = lRelativeOffset;
	    }
	}
    }

  m_fStartPos = false;
  m_cRowsFetched = 0;
  HRESULT hr = BindRows(hRowBase, cRows);
  if (FAILED(hr))
    return hr;
  hr = Fetch(wFetchOrientation, lFetchOffset);
  if (FAILED(hr))
    return hr;
  hr = InitRows();
  if (FAILED(hr))
    return hr;

  m_cRowsObtained = m_cRowsFetched;
  if (m_cRowsFetched < m_cRows)
    return DB_S_ENDOFROWSET;
  return S_OK;
}

HRESULT
PositionalPolicy::GetRowsAtPosition(
  bool fStandardBookmark,
  ULONG ulBookmark,
  DBROWOFFSET lRowsOffset,
  DBROWCOUNT cRows
)
{
  LOGCALL(("PositionalPolicy::GetRowsAtPosition(fStandardBookmark = %d, ulBookmark = %d, lRowsOffset = %d, cRows = %d)\n",
	   fStandardBookmark, ulBookmark, lRowsOffset, cRows));

  assert(cRows != 0);

  HROW hRowBase;
  if (fStandardBookmark)
    {
      if (ulBookmark == DBBMK_FIRST)
	hRowBase = (HROW)(1 + lRowsOffset);
      else if (ulBookmark == DBBMK_LAST)
	hRowBase = (HROW)(m_cTotalRows + lRowsOffset);
    }
  else
    {
      bm_iter_t i = m_bookmarks.find(ulBookmark);
      if (i == m_bookmarks.end())
	return ErrorInfo::Set(DB_E_BADBOOKMARK);
      hRowBase = (HROW)(i->second + lRowsOffset);
    }

  if (hRowBase <= 0 || hRowBase > m_cTotalRows)
    {
      m_cRowsObtained = 0;
      return DB_S_ENDOFROWSET;
    }

  if (cRows < 0)
    {
      if (hRowBase + cRows - 1 < 0)
	{
	  cRows = (DBROWCOUNT)hRowBase;
	  hRowBase = 1;
	}
      else
	{
	  hRowBase += (HROW)(cRows + 1);
	  cRows = -cRows;
	}

      m_fBackward = true;
    }
  else
    {
      if (hRowBase + cRows - 1 > m_cTotalRows)
	cRows = (DBCOUNTITEM)(m_cTotalRows - hRowBase + 1);

      m_fBackward = false;
    }

  SQLSMALLINT wFetchOrientation = SQL_FETCH_ABSOLUTE;
  DBROWOFFSET lFetchOffset = (DBROWOFFSET)hRowBase;

  DBROWOFFSET lReverseOffset = (DBROWOFFSET)(m_cTotalRows - hRowBase + 1);
  if (lReverseOffset < lFetchOffset)
    lFetchOffset = -lReverseOffset;

  if (!m_fStartPos)
    {
      DBROWOFFSET lRelativeOffset = (DBROWOFFSET)(hRowBase - m_hRowBase);
      if (abs(lRelativeOffset) < abs(lFetchOffset))
	{
	  if (lRelativeOffset == 1)
	    wFetchOrientation = SQL_FETCH_NEXT;
	  else if (lRelativeOffset == -1)
	    wFetchOrientation = SQL_FETCH_PREV;
	  else
	    {
	      wFetchOrientation = SQL_FETCH_RELATIVE;
	      lFetchOffset = lRelativeOffset;
	    }
	}
    }

  m_fStartPos = false;
  m_cRowsFetched = 0;
  HRESULT hr = BindRows(hRowBase, cRows);
  if (FAILED(hr))
    return hr;
  hr = Fetch(wFetchOrientation, lFetchOffset);
  if (FAILED(hr))
    return hr;
  hr = InitRows();
  if (FAILED(hr))
    return hr;

  m_cRowsObtained = m_cRowsFetched;
  if (m_cRowsFetched < m_cRows)
    return DB_S_ENDOFROWSET;
  return S_OK;
}

HRESULT
PositionalPolicy::GetRowByBookmark(ULONG ulBookmark)
{
  LOGCALL(("PositionalPolicy::GetRowByBookmark(ulBookmark = %d)\n", ulBookmark));

  m_cRows = 0;

  bm_iter_t i = m_bookmarks.find(ulBookmark);
  if (i == m_bookmarks.end())
    return DBROWSTATUS_E_INVALID;

  HROW hRow = i->second;

  SQLSMALLINT wFetchOrientation = SQL_FETCH_ABSOLUTE;
  DBROWOFFSET lFetchOffset =  (DBROWOFFSET)hRow;

  DBROWOFFSET lReverseOffset = (DBROWOFFSET)(m_cTotalRows - hRow + 1);
  if (lReverseOffset < lFetchOffset)
    lFetchOffset = -lReverseOffset;

  if (!m_fStartPos)
    {
      DBROWOFFSET lRelativeOffset = (DBROWOFFSET)(hRow - m_hRowBase);
      if (abs(lRelativeOffset) < abs(lFetchOffset))
	{
	  if (lRelativeOffset == 1)
	    wFetchOrientation = SQL_FETCH_NEXT;
	  else if (lRelativeOffset == -1)
	    wFetchOrientation = SQL_FETCH_PREV;
	  else
	    {
	      wFetchOrientation = SQL_FETCH_RELATIVE;
	      lFetchOffset = lRelativeOffset;
	    }
	}
    }

  HRESULT hr = BindRows(hRow, 1);
  if (FAILED(hr))
    return hr;
  hr = Fetch(wFetchOrientation, lFetchOffset);
  if (FAILED(hr))
    return hr;
  hr = InitRows();
  if (FAILED(hr))
    return hr;

  if (m_cRowsFetched != 1)
    return DBROWSTATUS_E_INVALID;
  return S_OK;
}

DBCOUNTITEM
PositionalPolicy::GetRowsObtained()
{
  return m_cRowsObtained;
}

HRESULT
PositionalPolicy::SnatchRow(HROW hRow)
{
  if (hRow >= m_hRowBase && hRow < m_hRowBase + m_cRowsFetched)
    return S_OK;

  SQLSMALLINT wFetchOrientation = SQL_FETCH_ABSOLUTE;
  DBROWOFFSET lFetchOffset = (DBROWOFFSET)hRow;

  DBROWOFFSET lReverseOffset = (DBROWOFFSET)(m_cTotalRows - hRow + 1);
  if (lReverseOffset < lFetchOffset)
    lFetchOffset = -lReverseOffset;

  if (!m_fStartPos)
    {
      DBROWOFFSET lRelativeOffset = (DBROWOFFSET)(hRow - m_hRowBase);
      if (abs(lRelativeOffset) < abs(lFetchOffset))
	{
	  if (lRelativeOffset == 1)
	    wFetchOrientation = SQL_FETCH_NEXT;
	  else if (lRelativeOffset == -1)
	    wFetchOrientation = SQL_FETCH_PREV;
	  else
	    {
	      wFetchOrientation = SQL_FETCH_RELATIVE;
	      lFetchOffset = lRelativeOffset;
	    }
	}
    }

  HRESULT hr = BindRows(hRow, 1);
  if (FAILED(hr))
    return hr;
  hr = Fetch(wFetchOrientation, lFetchOffset);
  if (FAILED(hr))
    return hr;

  if (m_rgRowStatus[0] == SQL_ROW_DELETED || m_rgRowStatus[0] == SQL_ROW_ERROR)
    return DB_E_CANTCONVERTVALUE;
  return S_OK;
}

HRESULT
PositionalPolicy::BookmarkRow(HROW hRow, ULONG ulBookmark)
{
  try {
    m_bookmarks[ulBookmark] = hRow;
  } catch (...) {
    return ErrorInfo::Set(E_OUTOFMEMORY);
  }
  return S_OK;
}

DBCOUNTITEM
PositionalPolicy::GetRowCount()
{
  return m_cTotalRows;
}

DBCOUNTITEM
PositionalPolicy::GetPosition(bool fStandardBookmark, ULONG ulBookmark)
{
  if (fStandardBookmark)
    {
      if (ulBookmark == DBBMK_FIRST)
	return 1;
      if (ulBookmark == DBBMK_LAST)
	return m_cTotalRows;
    }
  else
    {
      bm_iter_t i = m_bookmarks.find(ulBookmark);
      if (i != m_bookmarks.end())
	return (DBCOUNTITEM)i->second;
    }
  return 0;
}

HRESULT
PositionalPolicy::CreateRow(HROW& hRow)
{
  LOGCALL(("PositionalPolicy::CreateRow()\n"));

  m_cRowsFetched = 0;
  HRESULT hr = BindRows(m_hNextNewRow, 1);
  if (FAILED(hr))
    return hr;

  hRow = m_hNextNewRow;
  return S_OK;
}

HRESULT
PositionalPolicy::InsertRow(HROW hRow)
{
  LOGCALL(("PositionalPolicy::InsertRow(hRow=%d)\n", hRow));

  RowData* pRowData = m_pRowPolicy->GetRowData(hRow);
  assert(pRowData != NULL);

  HRESULT hr = BindColumns(pRowData->GetData(), 1, false);
  if (FAILED(hr))
    return hr;

  hr = Insert();
  if (FAILED(hr))
    {
      UnbindColumns(pRowData->GetData(), false);
      return hr;
    }

  if (m_pRowsetInfo->HasBookmark())
    {
      ULONG ulBookmark = *(ULONG*) m_pRowsetInfo->GetFieldBuffer(pRowData->GetData(), 0);
      HRESULT hr = BookmarkRow(hRow, ulBookmark);
      if (FAILED(hr))
	{
	  UnbindColumns(pRowData->GetData(), false);
	  return hr;
	}
    }

  m_hNextNewRow++;
  UnbindColumns(pRowData->GetData(), false);
  return hr;
}

/*
void
ProcessDiagRecs()
{
  for (int i = 1;; i++)
    {
      SQLCHAR sqlstate[6], error_msg[SQL_MAX_MESSAGE_LENGTH];
      SQLSMALLINT error_msg_len;
      SQLINTEGER native_error;
      SQLRETURN rv;

      rv = SQLGetDiagRec(SQL_HANDLE_STMT, db_statement.GetHSTMT(), i,
			 sqlstate, &native_error,
			 error_msg, sizeof error_msg, &error_msg_len);
      if (rv == SQL_NO_DATA)
	break;

      LOG(("SQLSTATE:        %s\n", sqlstate));
      LOG(("NativeError:     %d\n", native_error));
      LOG(("Diagnostic Msg:  %s\n", error_msg));

      SQLINTEGER row = 0, column = 0;
      rv = SQLGetDiagField(SQL_HANDLE_STMT, db_statement.GetHSTMT(), i,
			   SQL_DIAG_ROW_NUMBER, &row, SQL_IS_POINTER, NULL);
      if (rv != SQL_SUCCESS)
	continue;
      rv = SQLGetDiagField(SQL_HANDLE_STMT, db_statement.GetHSTMT(), i,
			   SQL_DIAG_COLUMN_NUMBER, &column, SQL_IS_POINTER, NULL);
      if (rv != SQL_SUCCESS)
	continue;

      LOG(("row:	    %d\n", row));
      LOG(("column:	    %d\n", column));

      if (strcmp((char *)sqlstate, "01004") == 0
	  && row != SQL_ROW_NUMBER_UNKNOWN
	  && column != SQL_COLUMN_NUMBER_UNKNOWN)
	{
	  char* row_buffer = GetRecordBuffer(row - 1);
	  LONG* col_length = GetFieldLength(row_buffer, column - 1);
	  *col_length = DBSTATUS_S_TRUNCATED;
	}
    }
}
*/

/**********************************************************************/
/* SyntheticPolicy                                                    */

SyntheticPolicy::SyntheticPolicy(RowsetInfo* pRowsetInfo, AbstractRowPolicy* pRowPolicy)
{
  assert(pRowsetInfo != NULL);
  assert(pRowPolicy != NULL);
  m_pRowsetInfo = pRowsetInfo;
  m_pRowPolicy = pRowPolicy;
  m_cTotalRows = 0;
  m_fStartPos = true;
  m_fBackward = false;
  m_nNextFetch = 0;
  m_hRowBase = 0;
  m_cRowsObtained = 0;
}

HRESULT
SyntheticPolicy::Init(DBCOUNTITEM cRows)
{
  m_cTotalRows = cRows;
  return S_OK;
}

HRESULT
SyntheticPolicy::GetNextRows(DBROWOFFSET lRowsOffset, DBROWCOUNT cRows)
{
  LOGCALL(("SyntheticPolicy::GetNextRows(lRowsOffset=%d, cRows=%d)\n", lRowsOffset, cRows));

  assert(cRows != 0);

  // In initial position the next fetch position depends on the given offset or fetch
  // direction. Otherwise it depends on the previous fetches.
  HROW iNextFetch;
  if (m_fStartPos)
    {
      if (lRowsOffset < 0 || lRowsOffset == 0 && cRows < 0)
	iNextFetch = m_cTotalRows + lRowsOffset;
      else
	iNextFetch = lRowsOffset;
    }
  else
    {
      iNextFetch = m_nNextFetch + lRowsOffset;
    }

  HROW hRowBase;
  if (cRows < 0)
    {
      if (iNextFetch <= 0 || iNextFetch > m_cTotalRows)
	{
	  m_cRowsObtained = 0;
	  return DB_S_ENDOFROWSET;
	}

      m_fBackward = true;
      if (iNextFetch + cRows < 0)
	{
	  m_nNextFetch = 0;
	  cRows = iNextFetch - m_nNextFetch;
	}
      else
	{
	  m_nNextFetch = iNextFetch + cRows;
	  cRows = -cRows;
	}

      hRowBase = m_nNextFetch + 1;
    }
  else
    {
      if (iNextFetch < 0 || iNextFetch >= m_cTotalRows)
	{
	  m_cRowsObtained = 0;
	  return DB_S_ENDOFROWSET;
	}

      m_fBackward = false;
      if (iNextFetch + cRows > m_cTotalRows)
	{
	  m_nNextFetch = m_cTotalRows;
	  cRows = m_nNextFetch - iNextFetch;
	}
      else
	m_nNextFetch = iNextFetch + cRows;

      hRowBase = iNextFetch + 1;
    }

  m_fStartPos = false;
  HRESULT hr = m_pRowPolicy->AllocateRows(hRowBase, cRows, m_pRowsetInfo);
  if (FAILED(hr))
    return hr;
  hr = InitRows(hRowBase, cRows);
  if (FAILED(hr))
    return hr;

  m_hRowBase = hRowBase;
  m_cRowsObtained = cRows;
  if (m_cRowsObtained < cRows)
    return DB_S_ENDOFROWSET;
  return S_OK;
}

DBCOUNTITEM
SyntheticPolicy::GetRowsObtained()
{
  return m_cRowsObtained;
}

void
SyntheticPolicy::GetRowHandlesObtained(HROW* rghRows)
{
  LOGCALL(("SyntheticPolicy::GetRowHandlesObtained()\n"));

  for (LONG iRow = 0; iRow < m_cRowsObtained; iRow++)
    {
      if (m_fBackward)
	rghRows[m_cRowsObtained - iRow - 1] = m_hRowBase + iRow;
      else
	rghRows[iRow] = m_hRowBase + iRow;
    }
}

HRESULT
SyntheticPolicy::RestartPosition()
{
  LOGCALL(("SyntheticPolicy::RestartPosition()\n"));

  m_fStartPos = true;
  return S_OK;
}

GetDataHandler*
SyntheticPolicy::GetGetDataHandler()
{
  return NULL;
}

SetDataHandler*
SyntheticPolicy::GetSetDataHandler()
{
  return NULL;
}

bool
SyntheticPolicy::IsStreamObjectAlive()
{
  return false;
}

void
SyntheticPolicy::KillStreamObject()
{
}

HRESULT
SyntheticPolicy::InitRows(HROW hRowBase, DBCOUNTITEM cRows)
{
  ULONG iRow;

  for (iRow = 0; iRow < cRows; iRow++)
    {
      HROW hRow = hRowBase + iRow;
      RowData* pRowData = m_pRowPolicy->GetRowData(hRow);
      assert(pRowData != NULL);

      pRowData->AddRefRow();
      pRowData->SetStatus(DBPENDINGSTATUS_UNCHANGED);
    }

  return S_OK;
}

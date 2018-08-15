/*  session.cpp
 *
 *  $Id$
 *  
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *  
 *  Copyright (C) 1998-2018 OpenLink Software
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
#include "datasource.h"
#include "rowset.h"
#include "command.h"
#include "util.h"

////////////////////////////////////////////////////////////////////////
// SessionPropertySet

static PropertyInfo session_properties[] =
{
  {
    DBPROP_SESS_AUTOCOMMITISOLEVELS,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ | DBPROPFLAGS_WRITE,
    VT_I4,
    L"Autocommit Isolation Levels",
    DBPROPVAL_TI_READCOMMITTED
  }
};

PropertySetInfo g_SessionPropertySetInfo(DBPROPSET_SESSION,
					 DBPROPFLAGS_SESSION,
					 sizeof session_properties / sizeof session_properties[0],
					 session_properties);

class SessionPropertySet : public PropertySet
{
public:

  SessionPropertySet();
  ~SessionPropertySet();

  virtual Property* GetProperty(DBPROPID id);

  // TODO: Call Connection::SetConnectionAttrs() on change.
  PropertyI4 prop_sess_autocommitisolevels;
};

SessionPropertySet::SessionPropertySet()
  : PropertySet(g_SessionPropertySetInfo, DBPROPFLAGS_READ | DBPROPFLAGS_WRITE)
{
}

SessionPropertySet::~SessionPropertySet()
{
}

Property*
SessionPropertySet::GetProperty(DBPROPID id)
{
  switch(id)
    {
    case DBPROP_SESS_AUTOCOMMITISOLEVELS: return &prop_sess_autocommitisolevels;
    }
  return NULL;
}

////////////////////////////////////////////////////////////////////////
// CSession

CSession::CSession()
{
  LOGCALL(("CSession::CSession()\n"));

  m_pDataSource = NULL;
  m_pSessionPropertySet = NULL;
  m_xactState = XACT_NONE;
  m_pUnkFTM = NULL;
  m_nTrxLevel = 0;
}

CSession::~CSession()
{
  LOGCALL(("CSession::~CSession()\n"));
}

HRESULT
CSession::Initialize (CDataSource* pDataSource)
{
  LOGCALL(("CSession::Initialize()\n"));

  m_pSessionPropertySet = new SessionPropertySet();
  if (m_pSessionPropertySet == NULL)
    return ErrorInfo::Set(E_OUTOFMEMORY);
  if (m_pSessionPropertySet->Init() == false)
    return ErrorInfo::Set(E_OUTOFMEMORY);

  assert(pDataSource != NULL);
  m_pDataSource = pDataSource;
  m_pDataSource->GetControllingUnknown()->AddRef();
  m_pDataSource->IncrementSessionCount();

  HRESULT hr = m_pDataSource->InitConnection(m_connection);
  if (FAILED(hr))
    return hr;
  hr = m_connection.SetTransactionAttrs(true, m_pSessionPropertySet->prop_sess_autocommitisolevels.GetValue());
  if (FAILED(hr))
    return hr;

  return S_OK;
}

void
CSession::Delete()
{
  LOGCALL(("CSession::Delete()\n"));

  if (m_pDataSource != NULL)
    {
      m_pDataSource->DecrementSessionCount();
      m_pDataSource->GetControllingUnknown()->Release();
      m_pDataSource = NULL;
    }
  if (m_pSessionPropertySet != NULL)
    {
      delete m_pSessionPropertySet;
      m_pSessionPropertySet = NULL;
    }
  if (m_pUnkFTM != NULL)
    {
      m_pUnkFTM->Release();
      m_pUnkFTM = NULL;
    }
}

HRESULT
CSession::GetInterface(REFIID riid, IUnknown** ppUnknown)
{
  LOGCALL (("CSession::GetInterface(%s)\n", STRINGFROMGUID(riid)));

  IUnknown* pUnknown = NULL;
  if (riid == IID_IGetDataSource)
    pUnknown = static_cast<IGetDataSource*>(this);
  else if (riid == IID_IOpenRowset)
    pUnknown = static_cast<IOpenRowset*>(this);
  else if (riid == IID_ISessionProperties)
    pUnknown = static_cast<ISessionProperties*>(this);
  else if (riid == IID_IDBCreateCommand)
    pUnknown = static_cast<IDBCreateCommand*>(this);
  else if (riid == IID_IDBSchemaRowset)
    pUnknown = static_cast<IDBSchemaRowset*>(this);
  else if (riid == IID_ITransaction)
    pUnknown = static_cast<ITransaction*>(this);
  else if (riid == IID_ITransactionJoin)
    pUnknown = static_cast<ITransactionJoin*>(this);
  else if (riid == IID_ITransactionLocal)
    pUnknown = static_cast<ITransactionLocal*>(this);
  else if (riid == IID_ISupportErrorInfo)
    pUnknown = static_cast<ISupportErrorInfo*>(this);
  else if (riid == IID_IMarshal)
    {
      CriticalSection critical_section(this);
      if (m_pUnkFTM == NULL)
	CoCreateFreeThreadedMarshaler(GetControllingUnknown(), &m_pUnkFTM);
      if (m_pUnkFTM != NULL)
	return m_pUnkFTM->QueryInterface(riid, (void**) ppUnknown);
    }
  if (pUnknown == NULL)
    return E_NOINTERFACE;

  *ppUnknown = pUnknown;
  return S_OK;
}

const IID**
CSession::GetSupportErrorInfoIIDs()
{
  static const IID* rgpIIDs[] =
  {
    &IID_IOpenRowset,
    &IID_IDBCreateCommand,
    &IID_IDBSchemaRowset,
    &IID_ITransaction,
    &IID_ITransactionLocal,
    &IID_ITransactionJoin,
    NULL
  };

  return rgpIIDs;
}

ULONG
CSession::GetPropertySetCount()
{
  return 1;
}

PropertySet*
CSession::GetPropertySet(ULONG iPropertySet)
{
  assert(iPropertySet == 0);
  return m_pSessionPropertySet;
}

PropertySet*
CSession::GetPropertySet(REFGUID rguidPropertySet)
{
  if (rguidPropertySet == DBPROPSET_SESSION)
    return m_pSessionPropertySet;
  return NULL;
}

HRESULT
CSession::AddRowset(CRowset* rowset)
{
  LOGCALL (("CSession::AddRowset()\n"));

  HRESULT hr = S_OK;
  try {
    CriticalSection critical_section(this);
    m_rowsets.push_front(rowset);
  } catch (...) {
    hr = E_OUTOFMEMORY;
  }
  return hr;
}

void
CSession::RemoveRowset(CRowset* rowset)
{
  LOGCALL (("CSession::RemoveRowset()\n"));

  CriticalSection critical_section(this);
  m_rowsets.remove(rowset);
}

HRESULT
CSession::EndTransaction(bool commit, bool retain)
{
  LOGCALL (("CSession::EndTransaction(commit = %d, retain = %d)\n", commit, retain));

  CriticalSection critical_section(this);

  if (m_xactState == XACT_NONE)
    return XACT_E_NOTRANSACTION;
  else if (m_xactState == XACT_DISTRIBUTED)
    { /* this is a dummy to emulate support for subtransactions */
      m_nTrxLevel--;
      LOG(("CSession::EndTransaction() m_xactState = XACT_DISTRIBUTED nTrxLevel=%d\n",
	    m_nTrxLevel));
      if (m_nTrxLevel > 0)
	{
	  LOG(("CSession::EndTransaction() end deferred\n"));
	  return S_OK;
	}
    }

  for (RowsetIter iter = m_rowsets.begin(); iter != m_rowsets.end(); iter++)
    (*iter)->EndTransaction(commit);

  HRESULT hr = m_connection.EndTransaction(commit);
  if (FAILED(hr))
    return hr;

  if (retain)
    return S_OK;

  m_xactState = XACT_NONE;
  hr = m_connection.SetTransactionAttrs(true, m_pSessionPropertySet->prop_sess_autocommitisolevels.GetValue());
  if (FAILED(hr))
    return hr;

  return S_OK;
}

////////////////////////////////////////////////////////////////////////
// IGetDataSource

STDMETHODIMP
CSession::GetDataSource(
  REFIID riid,
  IUnknown **ppDataSource
)
{
  LOGCALL(("CSession::GetDataSource(riid=%s)\n", StringFromGuid(riid)));

  assert(m_pDataSource != NULL);
  return m_pDataSource->GetControllingUnknown()->QueryInterface(riid, (void **) ppDataSource);
}

////////////////////////////////////////////////////////////////////////
// IOpenRowset

STDMETHODIMP
CSession::OpenRowset(
  IUnknown *pUnkOuter,
  DBID *pTableID,
  DBID *pIndexID,
  REFIID riid,
  ULONG cPropertySets,
  DBPROPSET rgPropertySets[],
  IUnknown **ppRowset
)
{
  LOGCALL(("CSession::OpenRowset(riid=%s)\n", StringFromGuid(riid)));

  if (ppRowset != NULL)
    *ppRowset = NULL;

  ErrorCheck error(IID_IOpenRowset, DISPID_IOpenRowset_OpenRowset);

  if (pUnkOuter != NULL && riid != IID_IUnknown)
    return ErrorInfo::Set(DB_E_NOAGGREGATION);
  if (pTableID == NULL && pIndexID == NULL)
    return ErrorInfo::Set(E_INVALIDARG);
  if (pIndexID != NULL)
    return ErrorInfo::Set(DB_E_NOINDEX); // indexes are not supported at all.
  if (pTableID == NULL
      || pTableID->eKind != DBKIND_NAME
      || pTableID->uName.pwszName == NULL
      || pTableID->uName.pwszName[0] == 0)
    return ErrorInfo::Set(DB_E_NOTABLE);

  ostring query;
  try {
    query = ostring(L"select * from ") + pTableID->uName.pwszName;
  } catch (...) {
    return ErrorInfo::Set(E_OUTOFMEMORY);
  }

  IUnknown* pRowset;
  CRowsetSessionInitializer initializer (this, query, NULL, 0, NULL, riid, cPropertySets, rgPropertySets);
  HRESULT hr = ComAggregateObj<CRowset>::CreateInstance (pUnkOuter, riid, (void**) &pRowset, &initializer);
  if (FAILED (hr))
    return hr;

  if (riid == IID_NULL)
    {
      pRowset->Release ();
      return ErrorInfo::Set(E_NOINTERFACE);
    }

  if (ppRowset != NULL)
    *ppRowset = pRowset;
  else
    pRowset->Release ();

  return initializer.hr; // Can be S_OK or DB_S_ERRORSOCCURED
}

////////////////////////////////////////////////////////////////////////
// ISessionProperties

STDMETHODIMP
CSession::GetProperties(
  ULONG cPropertyIDSets,
  const DBPROPIDSET rgPropertyIDSets[],
  ULONG *pcPropertySets,
  DBPROPSET **prgPropertySets
)
{
  LOGCALL(("CSession::GetProperties()\n"));

  ErrorCheck error(IID_ISessionProperties, DISPID_ISessionProperties_GetProperties);
  CriticalSection critical_section(this);
  return PropertySuperset::GetProperties(cPropertyIDSets, rgPropertyIDSets, pcPropertySets, prgPropertySets);
}

STDMETHODIMP
CSession::SetProperties(
  ULONG cPropertySets,
  DBPROPSET rgPropertySets[]
)
{
  LOGCALL(("CSession::SetProperties()\n"));

  ErrorCheck error(IID_ISessionProperties, DISPID_ISessionProperties_SetProperties);
  CriticalSection critical_section(this);
  return PropertySuperset::SetProperties(cPropertySets, rgPropertySets);
}

////////////////////////////////////////////////////////////////////////
// IDBCreateCommand

STDMETHODIMP
CSession::CreateCommand(
  IUnknown *pUnkOuter,
  REFIID riid,
  IUnknown **ppCommand
)
{
  LOGCALL(("CSession::CreateCommand()\n"));

  ErrorCheck error(IID_IDBCreateCommand, DISPID_IDBCreateCommand_CreateCommand);

  if (ppCommand == NULL)
    return ErrorInfo::Set(E_INVALIDARG);
  *ppCommand = NULL;

  if (pUnkOuter != NULL && riid != IID_IUnknown)
    return ErrorInfo::Set(DB_E_NOAGGREGATION);

  return ComAggregateObj<CCommand>::CreateInstance (pUnkOuter, riid, (void**) ppCommand, this);
}

////////////////////////////////////////////////////////////////////////
// IDBSchemaRowset

static SchemaParam catalogs_params[] =
{
  { SQL_WCHAR, 0 },
  { SQL_WCHAR, 0 }
};

#define CATALOGS_PARAMS (sizeof catalogs_params / sizeof(SchemaParam))

static SchemaColumn catalogs_columns[] =
{
  { L"CATALOG_NAME",  DBTYPE_WSTR, 128,  false },
  { L"DESCRIPTION",   DBTYPE_WSTR, 128,  true },
};

#define CATALOGS_COLUMNS (sizeof catalogs_columns / sizeof(SchemaColumn))

static SchemaParam column_privileges_params[] =
{
  { SQL_WCHAR, 0 },
  { SQL_WCHAR, 1 },
  { SQL_WCHAR, 2 },
  { SQL_WCHAR, 3 },
  { SQL_WCHAR, 4 },
  { SQL_WCHAR, 4 },
  { SQL_WCHAR, 5 },
  { SQL_WCHAR, 5 }
};

#define COLUMN_PRIVILEGES_PARAMS (sizeof column_privileges_params / sizeof(SchemaParam))

static SchemaColumn column_privileges_columns[] =
{
  { L"GRANTOR",		DBTYPE_WSTR,  128,  true },
  { L"GRANTEE",		DBTYPE_WSTR,  128,  true },
  { L"TABLE_CATALOG",	DBTYPE_WSTR,  128,  false },
  { L"TABLE_SCHEMA",	DBTYPE_WSTR,  128,  false },
  { L"TABLE_NAME",	DBTYPE_WSTR,  128,  false },
  { L"COLUMN_NAME",	DBTYPE_WSTR,  128,  false },
  { L"COLUMN_GUID",	DBTYPE_GUID,  0,    true },
  { L"COLUMN_PROPID",	DBTYPE_UI4,   0,    true },
  { L"PRIVILEGE_TYPE",	DBTYPE_WSTR,  128,  true },
  { L"IS_GRANTABLE",	DBTYPE_BOOL,  0,    true },
};

#define COLUMN_PRIVILEGES_COLUMNS (sizeof column_privileges_columns / sizeof(SchemaColumn))

static SchemaParam columns_params[] =
{
  { SQL_WCHAR, 0 },
  { SQL_WCHAR, 1 },
  { SQL_WCHAR, 1 },
  { SQL_WCHAR, 2 },
  { SQL_WCHAR, 2 },
  { SQL_WCHAR, 3 },
  { SQL_WCHAR, 3 }
};

#define COLUMNS_PARAMS (sizeof columns_params / sizeof(SchemaParam))

static SchemaColumn columns_columns[] =
{
  { L"TABLE_CATALOG",		  DBTYPE_WSTR,  128,  false },
  { L"TABLE_SCHEMA",		  DBTYPE_WSTR,  128,  false },
  { L"TABLE_NAME",		  DBTYPE_WSTR,  128,  false },
  { L"COLUMN_NAME",		  DBTYPE_WSTR,  128,  false },
  { L"COLUMN_GUID",		  DBTYPE_GUID,  0,    true },
  { L"COLUMN_PROPID",		  DBTYPE_UI4,   0,    true },
  { L"ORDINAL_POSITION",	  DBTYPE_UI4,   0,    true },
  { L"COLUMN_HASDEFAULT",	  DBTYPE_BOOL,  0,    true },
  { L"COLUMN_DEFAULT",		  DBTYPE_WSTR,	256,  true },
  { L"COLUMN_FLAGS",		  DBTYPE_UI4,	0,    true },
  { L"IS_NULLABLE",		  DBTYPE_BOOL,	0,    true },
  { L"DATA_TYPE",		  DBTYPE_UI2,	0,    true },
  { L"TYPE_GUID",		  DBTYPE_GUID,	0,    true },
  { L"CHARACTER_MAXIMUM_LENGTH",  DBTYPE_UI4,	0,    true },
  { L"CHARACTER_OCTET_LENGTH",	  DBTYPE_UI4,	0,    true },
  { L"NUMERIC_PRECISION",	  DBTYPE_UI2,	0,    true },
  { L"NUMERIC_SCALE",		  DBTYPE_I2,	0,    true },
  { L"DATETIME_PRECISION",	  DBTYPE_UI4,	0,    true },
  { L"CHARACTER_SET_CATALOG",	  DBTYPE_WSTR,	1,    true },
  { L"CHARACTER_SET_SCHEMA",	  DBTYPE_WSTR,	1,    true },
  { L"CHARACTER_SET_NAME",	  DBTYPE_WSTR,	1,    true },
  { L"COLLATION_CATALOG",	  DBTYPE_WSTR,	1,    true },
  { L"COLLATION_SCHEMA",	  DBTYPE_WSTR,	1,    true },
  { L"COLLATION_NAME",		  DBTYPE_WSTR,	1,    true },
  { L"DOMAIN_CATALOG",		  DBTYPE_WSTR,	1,    true },
  { L"DOMAIN_SCHEMA",		  DBTYPE_WSTR,	1,    true },
  { L"DOMAIN_NAME",		  DBTYPE_WSTR,	1,    true },
  { L"DESCRIPTION",		  DBTYPE_WSTR,	1,    true },
};

#define COLUMNS_COLUMNS (sizeof columns_columns / sizeof(SchemaColumn))

#define BUG_5942 1

static SchemaParam foreign_keys_params[] =
{
  { SQL_WCHAR, 0 },
#if BUG_5942
  { SQL_WCHAR, 0 },
#endif
  { SQL_WCHAR, 1 },
  { SQL_WCHAR, 1 },
  { SQL_WCHAR, 2 },
  { SQL_WCHAR, 2 },
  { SQL_WCHAR, 3 },
#if BUG_5942
  { SQL_WCHAR, 3 },
#endif
  { SQL_WCHAR, 4 },
  { SQL_WCHAR, 4 },
  { SQL_WCHAR, 5 },
  { SQL_WCHAR, 5 }
};

#define FOREIGN_KEYS_PARAMS (sizeof foreign_keys_params / sizeof(SchemaParam))

static SchemaColumn foreign_keys_columns[] =
{
  { L"PK_TABLE_CATALOG",	  DBTYPE_WSTR,  128,  false },
  { L"PK_TABLE_SCHEMA",		  DBTYPE_WSTR,  128,  false },
  { L"PK_TABLE_NAME",		  DBTYPE_WSTR,  128,  false },
  { L"PK_COLUMN_NAME",		  DBTYPE_WSTR,  128,  false },
  { L"PK_COLUMN_GUID",		  DBTYPE_GUID,  0,    true },
  { L"PK_COLUMN_PROPID",	  DBTYPE_UI4,   0,    true },
  { L"FK_TABLE_CATALOG",	  DBTYPE_WSTR,  128,  false },
  { L"FK_TABLE_SCHEMA",		  DBTYPE_WSTR,  128,  false },
  { L"FK_TABLE_NAME",		  DBTYPE_WSTR,  128,  false },
  { L"FK_COLUMN_NAME",		  DBTYPE_WSTR,  128,  false },
  { L"FK_COLUMN_GUID",		  DBTYPE_GUID,  0,    true },
  { L"FK_COLUMN_PROPID",	  DBTYPE_UI4,   0,    true },
  { L"ORDINAL",			  DBTYPE_UI4,   0,    true },
  { L"UPDATE_RULE",		  DBTYPE_WSTR,	20,   true },
  { L"DELETE_RULE",		  DBTYPE_WSTR,	20,   true },
  { L"PK_NAME",			  DBTYPE_WSTR,	128,  true },
  { L"FK_NAME",			  DBTYPE_WSTR,	128,  true },
  { L"DEFERRABILITY",		  DBTYPE_I2,	0,    true },
};

#define FOREIGN_KEYS_COLUMNS (sizeof foreign_keys_columns / sizeof(SchemaColumn))

static SchemaParam indexes_params[] =
{
  { SQL_WCHAR, 0 },
  { SQL_WCHAR, 1 },
  { SQL_WCHAR, 1 },
  { SQL_WCHAR, 4 },
  { SQL_WCHAR, 4 },
  { SQL_WCHAR, 2 },
  { SQL_WCHAR, 2 }
};

#define INDEXES_PARAMS (sizeof indexes_params / sizeof(SchemaParam))

static SchemaColumn indexes_columns[] =
{
  { L"TABLE_CATALOG",		  DBTYPE_WSTR,  128,  false },
  { L"TABLE_SCHEMA",		  DBTYPE_WSTR,  128,  false },
  { L"TABLE_NAME",		  DBTYPE_WSTR,  128,  false },
  { L"INDEX_CATALOG",		  DBTYPE_WSTR,  128,  false },
  { L"INDEX_SCHEMA",		  DBTYPE_WSTR,  128,  false },
  { L"INDEX_NAME",		  DBTYPE_WSTR,  128,  false },
  { L"PRIMARY_KEY",		  DBTYPE_BOOL,  0,    true },
  { L"UNIQUE",			  DBTYPE_BOOL,  0,    true },
  { L"CLUSTERED",		  DBTYPE_BOOL,  0,    true },
  { L"TYPE",			  DBTYPE_UI2,	0,    true },
  { L"FILL_FACTOR",		  DBTYPE_I4,	0,    true },
  { L"INITIAL_SIZE",		  DBTYPE_I4,	0,    true },
  { L"NULLS",			  DBTYPE_I4,	0,    true },
  { L"SORT_BOOKMARKS",		  DBTYPE_BOOL,  0,    true },
  { L"AUTO_UPDATE",		  DBTYPE_BOOL,  0,    true },
  { L"NULL_COLLATION",		  DBTYPE_I4,	0,    true },
  { L"ORDINAL_POSITION",	  DBTYPE_UI4,   0,    true },
  { L"COLUMN_NAME",		  DBTYPE_WSTR,  128,  false },
  { L"COLUMN_GUID",		  DBTYPE_GUID,  0,    true },
  { L"COLUMN_PROPID",		  DBTYPE_UI4,   0,    true },
  { L"COLLATION",		  DBTYPE_I2,	0,    true },
  { L"CARDINALITY",		  DBTYPE_UI8,   0,    true },
  { L"PAGES",			  DBTYPE_I4,	0,    true },
  { L"FILTER_CONDITION",	  DBTYPE_WSTR,	1,    true },
  { L"INTEGRATED",		  DBTYPE_BOOL,  0,    true },
};

#define INDEXES_COLUMNS (sizeof indexes_columns / sizeof(SchemaColumn))

static SchemaParam primary_keys_params[] =
{
  { SQL_WCHAR, 0 },
  { SQL_WCHAR, 1 },
  { SQL_WCHAR, 1 },
  { SQL_WCHAR, 2 },
  { SQL_WCHAR, 2 }
};

#define PRIMARY_KEYS_PARAMS (sizeof primary_keys_params / sizeof(SchemaParam))

static SchemaColumn primary_keys_columns[] =
{
  { L"TABLE_CATALOG",		  DBTYPE_WSTR,  128,  false },
  { L"TABLE_SCHEMA",		  DBTYPE_WSTR,  128,  false },
  { L"TABLE_NAME",		  DBTYPE_WSTR,  128,  false },
  { L"COLUMN_NAME",		  DBTYPE_WSTR,  128,  false },
  { L"COLUMN_GUID",		  DBTYPE_GUID,  0,    true },
  { L"COLUMN_PROPID",		  DBTYPE_UI4,   0,    true },
  { L"ORDINAL",			  DBTYPE_UI4,   0,    true },
  { L"PK_NAME",			  DBTYPE_WSTR,	128,  true },
};

#define PRIMARY_KEYS_COLUMNS (sizeof primary_keys_columns / sizeof(SchemaColumn))

static SchemaParam procedure_parameters_params[] =
{
  { SQL_WCHAR, 0 },
  { SQL_WCHAR, 1 },
  { SQL_WCHAR, 2 },
  { SQL_WCHAR, 3 }
};

#define PROCEDURE_PARAMETERS_PARAMS (sizeof procedure_parameters_params / sizeof(SchemaParam))

static SchemaColumn procedure_parameters_columns[] =
{
  { L"PROCEDURE_CATALOG",	  DBTYPE_WSTR,  128,  false },
  { L"PROCEDURE_SCHEMA",	  DBTYPE_WSTR,  128,  false },
  { L"PROCEDURE_NAME",		  DBTYPE_WSTR,  128,  false },
  { L"PARAMETER_NAME",		  DBTYPE_WSTR,  128,  false },
  { L"ORDINAL_POSITION",	  DBTYPE_UI2,   0,    true },
  { L"PARAMETER_TYPE",		  DBTYPE_UI2,	0,    true },
  { L"PARAMETER_HASDEFAULT",	  DBTYPE_BOOL,  0,    true },
  { L"PARAMETER_DEFAULT",	  DBTYPE_WSTR,	256,  true },
  { L"IS_NULLABLE",		  DBTYPE_BOOL,	0,    true },
  { L"DATA_TYPE",		  DBTYPE_UI2,	0,    true },
  { L"CHARACTER_MAXIMUM_LENGTH",  DBTYPE_UI4,	0,    true },
  { L"CHARACTER_OCTET_LENGTH",	  DBTYPE_UI4,	0,    true },
  { L"NUMERIC_PRECISION",	  DBTYPE_UI2,	0,    true },
  { L"NUMERIC_SCALE",		  DBTYPE_I2,	0,    true },
  { L"DESCRIPTION",		  DBTYPE_WSTR,	1,    true },
  { L"TYPE_NAME",		  DBTYPE_WSTR,	32,   true },
  { L"LOCAL_TYPE_NAME",		  DBTYPE_WSTR,	32,   true },
};

#define PROCEDURE_PARAMETERS_COLUMNS (sizeof procedure_parameters_columns / sizeof(SchemaColumn))

static SchemaParam procedures_params[] =
{
  { SQL_WCHAR, 0 },
  { SQL_WCHAR, 1 },
  { SQL_WCHAR, 1 },
  { SQL_WCHAR, 2 },
  { SQL_WCHAR, 2 },
  { SQL_WCHAR, 3 },
  { SQL_WCHAR, 3 }
};

#define PROCEDURES_PARAMS (sizeof procedures_params / sizeof(SchemaParam))

static SchemaColumn procedures_columns[] =
{
  { L"PROCEDURE_CATALOG",	  DBTYPE_WSTR,  128,  false },
  { L"PROCEDURE_SCHEMA",	  DBTYPE_WSTR,  128,  false },
  { L"PROCEDURE_NAME",		  DBTYPE_WSTR,  128,  false },
  { L"PROCEDURE_TYPE",		  DBTYPE_I2,	0,    false },
  // PROCEDURE_DEFINITION might be a BLOB so let the real data govern the type
  { L"PROCEDURE_DEFINITION",	  DBTYPE_EMPTY, 128,  true },
  { L"DESCRIPTION",		  DBTYPE_WSTR,	128,  true },
  { L"DATE_CREATED",		  DBTYPE_DATE,	0,    true },
  { L"DATE_MODIFIED",		  DBTYPE_DATE,	0,    true },
};

#define PROCEDURES_COLUMNS (sizeof procedures_columns / sizeof(SchemaColumn))

static SchemaParam provider_types_params[] =
{
  { SQL_SMALLINT, 0 },
  { SQL_SMALLINT, 1 }
};

#define PROVIDER_TYPES_PARAMS (sizeof provider_types_params / sizeof(SchemaParam))

static SchemaColumn provider_types_columns[] =
{
  { L"TYPE_NAME",	    DBTYPE_WSTR,  32, false },
  { L"DATA_TYPE",	    DBTYPE_UI2,	  0,  false },
  { L"COLUMN_SIZE",	    DBTYPE_UI4,	  0,  false },
  { L"LITERAL_PREFIX",	    DBTYPE_WSTR,  5,  false },
  { L"LITERAL_SUFFIX",	    DBTYPE_WSTR,  5,  false },
  { L"CREATE_PARAMS",	    DBTYPE_WSTR,  64, false },
  { L"IS_NULLABLE",	    DBTYPE_BOOL,  0,  false },
  { L"CASE_SENSITIVE",	    DBTYPE_BOOL,  0,  false },
  { L"SEARCHABLE",	    DBTYPE_UI4,	  0,  false },
  { L"UNSIGNED_ATTRIBUTE",  DBTYPE_BOOL,  0,  false },
  { L"FIXED_PREC_SCALE",    DBTYPE_BOOL,  0,  false },
  { L"AUTO_UNIQUE_VALUE",   DBTYPE_BOOL,  0,  false },
  { L"LOCAL_TYPE_NAME",	    DBTYPE_WSTR,  32, false },
  { L"MINIMUM_SCALE",	    DBTYPE_I2,	  0,  false },
  { L"MAXIMUM_SCALE",	    DBTYPE_I2,	  0,  false },
  { L"GUID",		    DBTYPE_GUID,  0,  false },
  { L"TYPELIB",		    DBTYPE_WSTR,  32, false },
  { L"VERSION",		    DBTYPE_WSTR,  32, false },
  { L"IS_LONG",		    DBTYPE_BOOL,  0,  false },
  { L"BEST_MATCH",	    DBTYPE_BOOL,  0,  false },
  { L"IS_FIXEDLENGTH",	    DBTYPE_BOOL,  0,  false },
};

#define PROVIDER_TYPES_COLUMNS (sizeof provider_types_columns / sizeof(SchemaColumn))

static SchemaParam schemata_params[] =
{
  { SQL_WCHAR, 0 },
  { SQL_WCHAR, 1 },
  { SQL_WCHAR, 1 },
  { SQL_WCHAR, 2 },
  { SQL_WCHAR, 2 }
};

#define SCHEMATA_PARAMS (sizeof schemata_params / sizeof(SchemaParam))

static SchemaColumn schemata_columns[] =
{
  { L"CATALOG_NAME",		      DBTYPE_WSTR,  128,  false },
  { L"SCHEMA_NAME",		      DBTYPE_WSTR,  128,  false },
  { L"SCHEMA_OWNER",		      DBTYPE_WSTR,  128,  false },
  { L"DEFAULT_CHARACTER_SET_CATALOG", DBTYPE_WSTR,  1,    true },
  { L"DEFAULT_CHARACTER_SET_SCHEMA",  DBTYPE_WSTR,  1,    true },
  { L"DEFAULT_CHARACTER_SET_NAME",    DBTYPE_WSTR,  1,    true },
};

#define SCHEMATA_COLUMNS (sizeof schemata_columns / sizeof(SchemaColumn))

static SchemaParam table_privileges_params[] =
{
  { SQL_WCHAR, 0 },
  { SQL_WCHAR, 1 },
  { SQL_WCHAR, 2 },
  { SQL_WCHAR, 3 },
  { SQL_WCHAR, 3 },
  { SQL_WCHAR, 4 },
  { SQL_WCHAR, 4 }
};

#define TABLE_PRIVILEGES_PARAMS (sizeof table_privileges_params / sizeof(SchemaParam))

static SchemaColumn table_privileges_columns[] =
{
  { L"GRANTOR",		DBTYPE_WSTR,  128,  true },
  { L"GRANTEE",		DBTYPE_WSTR,  128,  true },
  { L"TABLE_CATALOG",	DBTYPE_WSTR,  128,  false },
  { L"TABLE_SCHEMA",	DBTYPE_WSTR,  128,  false },
  { L"TABLE_NAME",	DBTYPE_WSTR,  128,  false },
  { L"PRIVILEGE_TYPE",	DBTYPE_WSTR,  128,  true },
  { L"IS_GRANTABLE",	DBTYPE_BOOL,  0,    true },
};

#define TABLE_PRIVILEGES_COLUMNS (sizeof table_privileges_columns / sizeof(SchemaColumn))

static SchemaParam tables_params[] =
{
  { SQL_WCHAR, 0 },
  { SQL_WCHAR, 1 },
  { SQL_WCHAR, 1 },
  { SQL_WCHAR, 2 },
  { SQL_WCHAR, 2 },
  { SQL_WCHAR, 3 },
  { SQL_WCHAR, 3 }
};

#define TABLES_PARAMS (sizeof tables_params / sizeof(SchemaParam))

static SchemaColumn tables_columns[] =
{
  { L"TABLE_CATALOG",  DBTYPE_WSTR, 128,  false },
  { L"TABLE_SCHEMA",   DBTYPE_WSTR, 128,  false },
  { L"TABLE_NAME",     DBTYPE_WSTR, 128,  false },
  { L"TABLE_TYPE",     DBTYPE_WSTR, 128,  false },
  { L"TABLE_GUID",     DBTYPE_GUID, 0,	  false },
  { L"DESCRIPTION",    DBTYPE_WSTR, 128,  true },
  { L"TABLE_PROPID",   DBTYPE_UI4,  0,	  true },
  { L"DATE_CREATED",   DBTYPE_DATE, 0,	  true },
  { L"DATE_MODIFIED",  DBTYPE_DATE, 0,	  true },
};

#define TABLES_COLUMNS (sizeof tables_columns / sizeof(SchemaColumn))

static Schema schemas[] =
{
  {
    &DBSCHEMA_CATALOGS,
    CRESTRICTIONS_DBSCHEMA_CATALOGS, 0x01,
    "select distinct name_part(KEY_TABLE, 0), NULL "
    "from DB.DBA.SYS_KEYS "
    "where"
    " (upper(cast(name_part(KEY_TABLE, 0) as NVARCHAR)) = upper(?) or ? is null) "
    "order by 1",
    CATALOGS_PARAMS, catalogs_params,
    CATALOGS_COLUMNS, catalogs_columns,
  },
  {
    &DBSCHEMA_COLUMN_PRIVILEGES,
    CRESTRICTIONS_DBSCHEMA_COLUMN_PRIVILEGES, 0x3f,
    "select cp.GRANTOR, cp.GRANTEE, cp.TABLE_QUALIFIER, cp.TABLE_OWNER, cp.TABLE_NAME,"
    " cp.COLUMN_NAME, NULL, NULL, cp.PRIVILEGE, cp.IS_GRANTABLE "
    "from DB.DBA.column_privileges(tc, ts, tn, cn)"
    "("
    " TABLE_QUALIFIER varchar,"
    " TABLE_OWNER varchar,"
    " TABLE_NAME varchar,"
    " COLUMN_NAME varchar,"
    " GRANTOR varchar,"
    " GRANTEE varchar,"
    " PRIVILEGE varchar,"
    " IS_GRANTABLE varchar"
    ") cp "
    "where"
    " tc = coalesce(?, dbname()) and"
    " ts = coalesce(?, '%') and"
    " tn = coalesce(?, '%') and"
    " cn = coalesce(?, '%') and"
    " (upper(cast(cp.GRANTOR as NVARCHAR)) = upper(?) or ? is null) and"
    " (upper(cast(cp.GRANTEE as NVARCHAR)) = upper(?) or ? is null) "
    "order by 3, 4, 5, 6, 9",
    COLUMN_PRIVILEGES_PARAMS, column_privileges_params,
    COLUMN_PRIVILEGES_COLUMNS, column_privileges_columns,
  },
  {
    &DBSCHEMA_COLUMNS,
    CRESTRICTIONS_DBSCHEMA_COLUMNS, 0x0f,
    "select\n"
    " name_part(KEY_TABLE, 0), name_part(KEY_TABLE, 1), name_part(KEY_TABLE, 2),"
    " \\COLUMN, NULL, NULL,"
    " (select count(*) from DB.DBA.SYS_COLS where \\TABLE = KEY_TABLE and COL_ID <= c.COL_ID and \\COLUMN <> '_IDN'),"
    " case when deserialize(COL_DEFAULT) is null then 0 else -1 end,"
    " deserialize(COL_DEFAULT),"
    " DB.DBA.oledb_dbflags(COL_DTP, COL_NULLABLE),"
    " case COL_NULLABLE when 1 then -1 else 0 end,"
    " DB.DBA.oledb_dbtype(COL_DTP),"
    " NULL,"
    " DB.DBA.oledb_char_max_len(COL_DTP, COL_PREC),"
    " DB.DBA.oledb_char_oct_len(COL_DTP, COL_PREC),"
    " DB.DBA.oledb_num_prec(COL_DTP, COL_PREC),"
    " DB.DBA.oledb_num_scale(COL_DTP, COL_SCALE),"
    " DB.DBA.oledb_datetime_prec(COL_DTP, COL_PREC),"
    " NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL "
    "from DB.DBA.SYS_KEYS, DB.DBA.SYS_KEY_PARTS, DB.DBA.SYS_COLS c "
    "where"
    " __any_grants(KEY_TABLE) and"
    " upper(cast(name_part(KEY_TABLE, 0) as NVARCHAR)) = upper(cast(coalesce(?, dbname()) as NVARCHAR)) and"
    " (upper(cast(name_part(KEY_TABLE, 1) as NVARCHAR)) = upper(?) or ? is null) and"
    " (upper(cast(name_part(KEY_TABLE, 2) as NVARCHAR)) = upper(?) or ? is null) and"
    " (upper(cast(\\COLUMN as NVARCHAR)) = upper(?) or ? is null) and"
    " \\COLUMN <> '_IDN' and"
    " KEY_IS_MAIN = 1 and"
    " KEY_MIGRATE_TO is null and"
    " KP_KEY_ID = KEY_ID and"
    " COL_ID = KP_COL "
    "order by KEY_TABLE, 7",
    COLUMNS_PARAMS, columns_params,
    COLUMNS_COLUMNS, columns_columns,
  },
  {
    &DBSCHEMA_FOREIGN_KEYS,
    CRESTRICTIONS_DBSCHEMA_FOREIGN_KEYS, 0x3f,
    "select"
    " name_part(PK_TABLE, 0), name_part(PK_TABLE, 1), name_part(PK_TABLE, 2),"
    " PKCOLUMN_NAME, NULL, NULL,"
    " name_part(FK_TABLE, 0), name_part(FK_TABLE, 1), name_part(FK_TABLE, 2),"
    " FKCOLUMN_NAME, NULL, NULL,"
    " (KEY_SEQ + 1),"
    " case UPDATE_RULE"
    " when 0 then 'NO ACTION'"
    " when 1 then 'CASCADE'"
    " when 2 then 'SET NULL'"
    " when 3 then 'SET DEFAULT'"
    " else NULL end,"
    " case DELETE_RULE"
    " when 0 then 'NO ACTION'"
    " when 1 then 'CASCADE'"
    " when 2 then 'SET NULL'"
    " when 3 then 'SET DEFAULT'"
    " else NULL end,"
    " PK_NAME, FK_NAME, 3 "
    "from DB.DBA.SYS_FOREIGN_KEYS "
    "where"
#if BUG_5942
    " ("
    "  upper(cast(name_part(PK_TABLE, 0) as NVARCHAR)) = upper(?) or"
    "  upper(cast(name_part(PK_TABLE, 0) as NVARCHAR)) = upper(cast(dbname() as NVARCHAR)) and ? is null"
    " ) and"
#else
    " upper(cast(name_part(PK_TABLE, 0) as NVARCHAR)) = upper(cast(coalesce(?, dbname()) as NVARCHAR)) and"
#endif
    " (upper(cast(name_part(PK_TABLE, 1) as NVARCHAR)) = upper(?) or ? is null) and"
    " (upper(cast(name_part(PK_TABLE, 2) as NVARCHAR)) = upper(?) or ? is null) and"
#if BUG_5942
    " ("
    "  upper(cast(name_part(FK_TABLE, 0) as NVARCHAR)) = upper(?) or"
    "  upper(cast(name_part(FK_TABLE, 0) as NVARCHAR)) = upper(cast(dbname() as NVARCHAR)) and ? is null"
    " ) and"
#else
    " upper(cast(name_part(FK_TABLE, 0) as NVARCHAR)) = upper(cast(coalesce(?, dbname()) as NVARCHAR)) and"
#endif
    " (upper(cast(name_part(FK_TABLE, 1) as NVARCHAR)) = upper(?) or ? is null) and"
    " (upper(cast(name_part(FK_TABLE, 2) as NVARCHAR)) = upper(?) or ? is null) "
    "order by FK_TABLE",
    FOREIGN_KEYS_PARAMS, foreign_keys_params,
    FOREIGN_KEYS_COLUMNS, foreign_keys_columns,
  },
  {
    &DBSCHEMA_INDEXES,
    CRESTRICTIONS_DBSCHEMA_INDEXES, 0x17,
    "select"
    " name_part(KEY_TABLE, 0), " /* TABLE_CATALOG */
    " name_part(KEY_TABLE, 1), " /* TABLE_SCHEMA */
    " name_part(KEY_TABLE, 2)," /* TABLE_NAME */
    " name_part(KEY_NAME, 0), " /* INDEX_CATALOG */
    " name_part(KEY_NAME, 1), " /* INDEX_SCHEMA */
    " name_part(KEY_NAME, 2)," /* INDEX_NAME */
    " case KEY_IS_MAIN when 1 then -1 else 0 end," /* PRIMARY_KEY */
    " case KEY_IS_UNIQUE when 1 then -1 else 0 end," /* UNIQUE */
    " case KEY_IS_MAIN when 1 then -1 else 0 end," /* CLUSTERED */
    " 1, " /* TYPE */
    " NULL, " /* FILL_FACTOR */
    " NULL, " /* INITIAL_SIZE */
    " NULL, " /* NULLS */
    " 0, " /* SORT_BOOKMARKS */
    " -1, " /* AUTO_UPDATE */
    " 4," /* NULL_COLLATION */
    " (KP_NTH + 1), " /* ORDINAL_POSITION */
    " \\COLUMN, " /* COLUMN_NAME */
    " NULL, " /* COLUMN_GUID */
    " NULL," /* COLUMN_PROPID */
    " NULL, " /* COLLATION */
    " NULL, " /* CARDINALITY */
    " NULL, " /* PAGES */
    " NULL," /* FILTER_CONDITION */
    " case KEY_IS_MAIN when 1 then -1 else 0 end " /* INTEGRATED */
    "from DB.DBA.SYS_KEYS, DB.DBA.SYS_KEY_PARTS, DB.DBA.SYS_COLS "
    "where"
    " __any_grants(KEY_TABLE) and"
    " upper(cast(name_part(KEY_TABLE, 0) as NVARCHAR)) = upper(cast(coalesce(?, dbname()) as NVARCHAR)) and"
    " (upper(cast(name_part(KEY_TABLE, 1) as NVARCHAR)) = upper(?) or ? is null) and"
    " (upper(cast(name_part(KEY_TABLE, 2) as NVARCHAR)) = upper(?) or ? is null) and"
    " (upper(cast(name_part(KEY_NAME, 2) as NVARCHAR)) = upper(?) or ? is null) and"
    " KEY_MIGRATE_TO is null and"
    " KP_KEY_ID = KEY_ID and"
    " KP_NTH < KEY_DECL_PARTS and"
    " COL_ID = KP_COL and"
    " \\COLUMN <> '_IDN' "
    "order by KEY_IS_UNIQUE desc, KEY_NAME, KP_NTH",
    INDEXES_PARAMS, indexes_params,
    INDEXES_COLUMNS, indexes_columns,
  },
  {
    &DBSCHEMA_PRIMARY_KEYS,
    CRESTRICTIONS_DBSCHEMA_PRIMARY_KEYS, 0x07,
    "select"
    " name_part(KEY_TABLE, 0), name_part(KEY_TABLE, 1), name_part(KEY_TABLE, 2),"
    " \\COLUMN, NULL, NULL, (KP_NTH + 1), name_part(KEY_NAME, 2) "
    "from DB.DBA.SYS_KEYS, DB.DBA.SYS_KEY_PARTS, DB.DBA.SYS_COLS "
    "where"
    " __any_grants(KEY_TABLE) and"
    " upper(cast(name_part(KEY_TABLE, 0) as NVARCHAR)) = upper(cast(coalesce(?, dbname()) as NVARCHAR)) and"
    " (upper(cast(name_part(KEY_TABLE, 1) as NVARCHAR)) = upper(?) or ? is null) and"
    " (upper(cast(name_part(KEY_TABLE, 2) as NVARCHAR)) = upper(?) or ? is null) and"
    " KEY_IS_MAIN = 1 and"
    " KEY_MIGRATE_TO is null and"
    " KP_KEY_ID = KEY_ID and"
    " KP_NTH < KEY_DECL_PARTS and"
    " COL_ID = KP_COL and"
    " \\COLUMN <> '_IDN' "
    "order by KEY_TABLE",
    PRIMARY_KEYS_PARAMS, primary_keys_params,
    PRIMARY_KEYS_COLUMNS, primary_keys_columns,
  },
  {
    &DBSCHEMA_PROCEDURE_PARAMETERS,
    CRESTRICTIONS_DBSCHEMA_PROCEDURE_PARAMETERS, 0x0f,
    "select"
    " PROCEDURE_CATALOG, PROCEDURE_SCHEMA, PROCEDURE_NAME, PARAMETER_NAME, ORDINAL_POSITION,"
    " PARAMETER_TYPE, PARAMETER_HASDEFAULT, PARAMETER_DEFAULT, IS_NULLABLE, DATA_TYPE,"
    " CHARACTER_MAXIMUM_LENGTH, CHARACTER_OCTET_LENGTH, NUMERIC_PRECISION, NUMERIC_SCALE,"
    " DESCRIPTION, TYPE_NAME, LOCAL_TYPE_NAME "
    "from DB.DBA.oledb_procedure_parameters(pc, ps, pn, parn)"
    "("
    " PROCEDURE_CATALOG VARCHAR(128),"
    " PROCEDURE_SCHEMA VARCHAR(128),"
    " PROCEDURE_NAME VARCHAR(128),"
    " PARAMETER_NAME VARCHAR(128),"
    " ORDINAL_POSITION SMALLINT,"
    " PARAMETER_TYPE SMALLINT,"
    " PARAMETER_HASDEFAULT SMALLINT,"
    " PARAMETER_DEFAULT VARCHAR,"
    " IS_NULLABLE SMALLINT,"
    " DATA_TYPE SMALLINT,"
    " CHARACTER_MAXIMUM_LENGTH INTEGER,"
    " CHARACTER_OCTET_LENGTH INTEGER,"
    " NUMERIC_PRECISION SMALLINT,"
    " NUMERIC_SCALE SMALLINT,"
    " DESCRIPTION VARCHAR(1),"
    " TYPE_NAME VARCHAR(32),"
    " LOCAL_TYPE_NAME VARCHAR(32)"
    ") pp "
    "where"
    " pc = ? and ps = ? and pn = ? and parn = ?",
    PROCEDURE_PARAMETERS_PARAMS, procedure_parameters_params,
    PROCEDURE_PARAMETERS_COLUMNS, procedure_parameters_columns,
  },
  {
    &DBSCHEMA_PROCEDURES,
    CRESTRICTIONS_DBSCHEMA_PROCEDURES, 0x0f,
    "select"
    " C1, C2, C3, C4, "
    " DB.DBA.oledb_procedure_definition(P_NAME) as PROCEDURE_DEFINITION LONG NVARCHAR, "
    " C5, C6, C7 "
    " from ("
    " select "
    " name_part(P_NAME, 0) as C1, "
    " name_part(P_NAME, 1) as C2, "
    " name_part(P_NAME, 2) as C3, "
    " ifnull(P_TYPE, 1, P_TYPE + 1) as C4,"
    " P_NAME as P_NAME, "
    " P_COMMENT as C5, "
    " NULL as C6, "
    " NULL as C7 "
    "from DB.DBA.SYS_PROCEDURES "
    "where"
    " upper(cast(name_part(P_NAME, 0) as NVARCHAR)) = upper(cast(coalesce(?, dbname()) as NVARCHAR)) and"
    " (upper(cast(name_part(P_NAME, 1) as NVARCHAR)) = upper(?) or ? is null) and"
    " (upper(cast(name_part(P_NAME, 2) as NVARCHAR)) = upper(?) or ? is null) and"
    " (ifnull(P_TYPE, 1, P_TYPE + 1) = ? or ? is null) and"
    " __proc_exists(P_NAME) is not null "
    "order by P_NAME"
    ") x",
    PROCEDURES_PARAMS, procedures_params,
    PROCEDURES_COLUMNS, procedures_columns,
  },
  {
    &DBSCHEMA_PROVIDER_TYPES,
    CRESTRICTIONS_DBSCHEMA_PROVIDER_TYPES, 0x03,
    "select"
    " gt.TYPE_NAME, gt.DATA_TYPE, gt.COLUMN_SIZE, gt.LITERAL_PREFIX, gt.LITERAL_SUFFIX,"
    " gt.CREATE_PARAMS, gt.IS_NULLABLE, gt.CASE_SENSITIVE, gt.SEARCHABLE, gt.UNSIGNED_ATTRIBUTE,"
    " gt.FIXED_PREC_SCALE, gt.AUTO_UNIQUE_VALUE, gt.LOCAL_TYPE_NAME, gt.MINIMUM_SCALE, gt.MAXIMUM_SCALE,"
    " gt.GUID, gt.TYPELIB, gt.VERSION, gt.IS_LONG, gt.BEST_MATCH, gt.IS_FIXEDLENGTH "
    "from DB.DBA.oledb_get_types(t, m)"
    "("
    " TYPE_NAME NVARCHAR(32),"
    " DATA_TYPE SMALLINT,"
    " COLUMN_SIZE INTEGER,"
    " LITERAL_PREFIX NVARCHAR(5),"
    " LITERAL_SUFFIX NVARCHAR(5),"
    " CREATE_PARAMS NVARCHAR(64),"
    " IS_NULLABLE SMALLINT,"
    " CASE_SENSITIVE SMALLINT,"
    " SEARCHABLE INTEGER,"
    " UNSIGNED_ATTRIBUTE SMALLINT,"
    " FIXED_PREC_SCALE SMALLINT,"
    " AUTO_UNIQUE_VALUE SMALLINT,"
    " LOCAL_TYPE_NAME NVARCHAR(32),"
    " MINIMUM_SCALE SMALLINT,"
    " MAXIMUM_SCALE SMALLINT,"
    " GUID NVARCHAR,"
    " TYPELIB NVARCHAR,"
    " VERSION NVARCHAR(32),"
    " IS_LONG SMALLINT,"
    " BEST_MATCH SMALLINT,"
    " IS_FIXEDLENGTH SMALLINT"
    ") gt "
    "where"
    " t = ? and m = ?",
    PROVIDER_TYPES_PARAMS, provider_types_params,
    PROVIDER_TYPES_COLUMNS, provider_types_columns,
  },
  {
    &DBSCHEMA_SCHEMATA,
    CRESTRICTIONS_DBSCHEMA_SCHEMATA, 0x07,
    "select distinct"
    " name_part(KEY_TABLE, 0), name_part(KEY_TABLE, 1), name_part(KEY_TABLE, 1), NULL, NULL, NULL "
    "from DB.DBA.SYS_KEYS "
    "where"
    " upper(cast(name_part(KEY_TABLE, 0) as NVARCHAR)) = upper(cast(coalesce(?, dbname()) as NVARCHAR)) and"
    " (upper(cast(name_part(KEY_TABLE, 1) as NVARCHAR)) = upper(?) or ? is null) and"
    " (upper(cast(name_part(KEY_TABLE, 1) as NVARCHAR)) = upper(?) or ? is null) "
    "order by 1, 2",
    SCHEMATA_PARAMS, schemata_params,
    SCHEMATA_COLUMNS, schemata_columns,
  },
  {
    &DBSCHEMA_TABLE_PRIVILEGES,
    CRESTRICTIONS_DBSCHEMA_TABLE_PRIVILEGES, 0x1f,
    "select"
    " tp.GRANTOR, tp.GRANTEE, tp.TABLE_QUALIFIER, tp.TABLE_OWNER, tp.TABLE_NAME, tp.PRIVILEGE, tp.IS_GRANTABLE "
    "from DB.DBA.table_privileges(tc, ts, tn)"
    "("
    " TABLE_QUALIFIER varchar,"
    " TABLE_OWNER varchar,"
    " TABLE_NAME varchar,"
    " GRANTOR varchar,"
    " GRANTEE varchar,"
    " PRIVILEGE varchar,"
    " IS_GRANTABLE varchar"
    ") tp "
    "where"
    " tc = coalesce(?, dbname()) and"
    " ts = coalesce(?, '%') and"
    " tn = coalesce(?, '%') and"
    " (upper(cast(tp.GRANTOR as NVARCHAR)) = upper(?) or ? is null) and"
    " (upper(cast(tp.GRANTEE as NVARCHAR)) = upper(?) or ? is null) "
    "order by 3, 4, 5, 6",
    TABLE_PRIVILEGES_PARAMS, table_privileges_params,
    TABLE_PRIVILEGES_COLUMNS, table_privileges_columns,
  },
  {
    &DBSCHEMA_TABLES,
    CRESTRICTIONS_DBSCHEMA_TABLES, 0x0f,
    "select"
    " name_part(KEY_TABLE, 0), name_part(KEY_TABLE, 1), name_part(KEY_TABLE, 2),"
    " table_type(KEY_TABLE), NULL, NULL, NULL, NULL, NULL "
    "from DB.DBA.SYS_KEYS "
    "where"
    " __any_grants(KEY_TABLE) and"
    " upper(cast(name_part(KEY_TABLE, 0) as NVARCHAR)) = upper(cast(coalesce(?, dbname()) as NVARCHAR)) and"
    " (upper(cast(name_part(KEY_TABLE, 1) as NVARCHAR)) = upper(?) or ? is null) and"
    " (upper(cast(name_part(KEY_TABLE, 2) as NVARCHAR)) = upper(?) or ? is null) and"
    " (upper(table_type(KEY_TABLE)) = upper(?) or ? is null) and"
    " KEY_IS_MAIN = 1 and"
    " KEY_MIGRATE_TO is null "
    "order by 4, KEY_TABLE",
    TABLES_PARAMS, tables_params,
    TABLES_COLUMNS, tables_columns
  },
#if 0
  {
    &DBSCHEMA_TABLE_CONSTRAINTS,
    CRESTRICTIONS_DBSCHEMA_TABLE_CONSTRAINTS, 0x00,
    "",
    NULL,
    0
  },
  {
    &DBSCHEMA_TABLE_STATISTICS,
    CRESTRICTIONS_DBSCHEMA_TABLE_STATISTICS, 0x00,
    "",
    NULL,
    0
  },
  {
    &DBSCHEMA_TABLES_INFO,
    CRESTRICTIONS_DBSCHEMA_TABLES_INFO, 0x00,
    "",
    NULL,
    0
  },
  {
    &DBSCHEMA_STATISTICS,
    CRESTRICTIONS_DBSCHEMA_STATISTICS, 0x00,
    "",
    NULL,
    0
  },
  {
    &DBSCHEMA_CHECK_CONSTRAINTS,
    CRESTRICTIONS_DBSCHEMA_CHECK_CONSTRAINTS, 0x00,
    "",
    NULL,
    0
  },
  {
    &DBSCHEMA_CHECK_CONSTRAINTS_BY_TABLE,
    CRESTRICTIONS_DBSCHEMA_CHECK_CONSTRAINTS_BY_TABLE, 0x00,
    "",
    NULL,
    0
  },
#endif
};

static Schema schema_tables_no_sys_tbs =
  {
    &DBSCHEMA_TABLES,
    CRESTRICTIONS_DBSCHEMA_TABLES, 0x0f,
    "select"
    " name_part(KEY_TABLE, 0), name_part(KEY_TABLE, 1), name_part(KEY_TABLE, 2),"
    " ("
    "  case "
    "    when upper(table_type(KEY_TABLE)) = 'SYSTEM TABLE' then 'TABLE' "
    "    else upper(table_type(KEY_TABLE))"
    "  end"
    " ), "
    " NULL, NULL, NULL, NULL, NULL "
    "from DB.DBA.SYS_KEYS "
    "where"
    " __any_grants(KEY_TABLE) and"
    " upper(cast(name_part(KEY_TABLE, 0) as NVARCHAR)) = upper(cast(coalesce(?, dbname()) as NVARCHAR)) and"
    " (upper(cast(name_part(KEY_TABLE, 1) as NVARCHAR)) = upper(?) or ? is null) and"
    " (upper(cast(name_part(KEY_TABLE, 2) as NVARCHAR)) = upper(?) or ? is null) and"
    " ("
    "  ("
    "   case "
    "    when upper(table_type(KEY_TABLE)) = 'SYSTEM TABLE' then 'TABLE' "
    "    else upper(table_type(KEY_TABLE)) "
    "   end"
    "  ) = upper(?) or ? is null) and"
    " KEY_IS_MAIN = 1 and"
    " KEY_MIGRATE_TO is null "
    "order by 4, KEY_TABLE",
    TABLES_PARAMS, tables_params,
    TABLES_COLUMNS, tables_columns
  };


#define SCHEMAS (sizeof schemas / sizeof schemas[0])

STDMETHODIMP
CSession::GetRowset(
  IUnknown *pUnkOuter,
  REFGUID rguidSchema,
  ULONG cRestrictions,
  const VARIANT rgRestrictions[],
  REFIID riid,
  ULONG cPropertySets,
  DBPROPSET rgPropertySets[],
  IUnknown **ppRowset
)
{
  LOGCALL(("CSession::GetRowset(%s, %s)\n", STRINGFROMGUID(rguidSchema), STRINGFROMGUID(riid)));

  ErrorCheck error(IID_IDBSchemaRowset, DISPID_IDBSchemaRowset_GetRowset);

  if (ppRowset == NULL)
    return ErrorInfo::Set(E_INVALIDARG);
  *ppRowset = NULL;

  Schema* schema = NULL;
  for (ULONG iSchema = 0; iSchema < SCHEMAS; iSchema++)
    if (rguidSchema == *schemas[iSchema].pguidSchema)
      {
	schema = &schemas[iSchema];
	break;
      }
  if (schema == NULL)
    return ErrorInfo::Set(E_INVALIDARG);
  if (schema->pguidSchema == &DBSCHEMA_TABLES)
    {
      VARIANT_BOOL b;
      if (S_OK == m_pDataSource->GetNoSysTables (b))
	{
	  if (b != 0)
	    schema = &schema_tables_no_sys_tbs;
	}
    }

  if (cRestrictions > 0 && rgRestrictions == NULL)
    return ErrorInfo::Set(E_INVALIDARG);

  if (cRestrictions > 0)
    {
      ULONG iRestriction = 0;
      for (; iRestriction < schema->cRestrictions; iRestriction++)
	{
	  LOGCALL(("restriction %d: %s\n", iRestriction, STRINGFROMVARIANT(&rgRestrictions[iRestriction])));
	  if (V_VT(&rgRestrictions[iRestriction]) != VT_EMPTY)
	    {
	      ULONG bit = 1 << iRestriction;
	      if (!(bit & schema->ulRestrictionSupport))
		return ErrorInfo::Set(DB_E_NOTSUPPORTED, std::string ("Restrictions not supported in GetRowset"));
	    }
	}
      for (; iRestriction < cRestrictions; iRestriction++)
	if (V_VT(&rgRestrictions[iRestriction]) != VT_EMPTY)
	  return ErrorInfo::Set(DB_E_NOTSUPPORTED);
    }

  if (pUnkOuter != NULL && riid != IID_IUnknown)
    return ErrorInfo::Set(DB_E_NOAGGREGATION);

  ostring query;
  try {
    query.reserve (strlen (schema->szQuery));
    for (const char *cp = schema->szQuery; *cp; cp++)
      query += ((OLECHAR) *cp);
  } catch (...) {
    return ErrorInfo::Set(E_OUTOFMEMORY);
  }

  CRowsetSessionInitializer initializer (
    this, query, schema, cRestrictions, rgRestrictions,
    riid, cPropertySets, rgPropertySets
  );
  HRESULT hr = ComAggregateObj<CRowset>::CreateInstance (pUnkOuter, riid, (void**) ppRowset, &initializer);
  if (FAILED (hr))
    return hr;

  return initializer.hr; // Can be S_OK or DB_S_ERRORSOCCURED
}

STDMETHODIMP
CSession::GetSchemas(
  ULONG *pcSchemas,
  GUID **prgSchemas,
  ULONG **prgRestrictionSupport
)
{
  LOGCALL(("CSession::GetSchemas()\n"));

  if (pcSchemas != NULL)
    *pcSchemas = 0;
  if (prgSchemas != NULL)
    *prgSchemas = NULL;
  if (prgRestrictionSupport != NULL)
    *prgRestrictionSupport = NULL;

  ErrorCheck error(IID_IDBSchemaRowset, DISPID_IDBSchemaRowset_GetSchemas);

  if (pcSchemas == NULL || prgSchemas == NULL)
    return ErrorInfo::Set(E_INVALIDARG);

  GUID* rgSchemas = (GUID*) CoTaskMemAlloc(SCHEMAS * sizeof(GUID));
  if (rgSchemas == NULL)
    return ErrorInfo::Set(E_OUTOFMEMORY);
  for (ULONG iSchema = 0; iSchema < SCHEMAS; iSchema++)
    rgSchemas[iSchema] = *schemas[iSchema].pguidSchema;

  if (prgRestrictionSupport != NULL)
    {
      ULONG* rgRestrictionSupport = (ULONG*) CoTaskMemAlloc(SCHEMAS * sizeof(ULONG));
      if (rgRestrictionSupport == NULL)
	{
	  CoTaskMemFree(rgSchemas);
	  return ErrorInfo::Set(E_OUTOFMEMORY);
	}
      for (ULONG iSchema = 0; iSchema < SCHEMAS; iSchema++)
	rgRestrictionSupport[iSchema] = schemas[iSchema].ulRestrictionSupport;

      *prgRestrictionSupport = rgRestrictionSupport;
    }

  *pcSchemas = SCHEMAS;
  *prgSchemas = rgSchemas;
  return S_OK;
}

////////////////////////////////////////////////////////////////////////
// ITableDefinition members

STDMETHODIMP
CSession::AddColumn (
    DBID *pTableID,
    DBCOLUMNDESC *pColumnDesc,
    DBID **ppColumnID
)
{
  LOGCALL (("CSession::AddColumn()\n"));

  ErrorCheck error(IID_ITableDefinition, DISPID_ITableDefinition_AddColumn);

  return E_FAIL;
}

STDMETHODIMP
CSession::CreateTable (
    IUnknown *pUnkOuter,
    DBID *pTableID,
    DBORDINAL cColumnDescs,
    const DBCOLUMNDESC rgColumnDescs[],
    REFIID riid,
    ULONG cPropertySets,
    DBPROPSET rgPropertySet[],
    DBID **ppTableID,
    IUnknown **ppRowset
)
{
  LOGCALL (("CSession::CreateTable()\n"));

  ErrorCheck error(IID_ITableDefinition, DISPID_ITableDefinition_CreateTable);

  return E_FAIL;
}

STDMETHODIMP
CSession::DropColumn (
    DBID *pTableID,
    DBID *pColumnID
)
{
  LOGCALL (("CSession::DropColumn()\n"));

  ErrorCheck error(IID_ITableDefinition, DISPID_ITableDefinition_DropColumn);

  return E_FAIL;
}

STDMETHODIMP
CSession::DropTable (
    DBID *pTableID
)
{
  LOGCALL (("CSession::DropTable()\n"));

  ErrorCheck error(IID_ITableDefinition, DISPID_ITableDefinition_DropTable);

  if (pTableID == NULL)
    return ErrorInfo::Set(E_INVALIDARG);
  if (pTableID->eKind != DBKIND_NAME
      || pTableID->uName.pwszName == NULL
      || pTableID->uName.pwszName[0] == 0)
    return ErrorInfo::Set(DB_E_NOTABLE);

  ostring query (L"drop table ");
  query += pTableID->uName.pwszName;

  Statement statement;
  statement.Init (m_connection);
  HRESULT hr = statement.Execute (query);
  statement.Release ();

  return hr;
}

////////////////////////////////////////////////////////////////////////
// ITransaction

STDMETHODIMP
CSession::Abort(
  BOID *pboidReason,
  BOOL fRetaining,
  BOOL fAsync
)
{
  LOGCALL(("CSession::Abort()\n"));

  ErrorCheck error(IID_ITransaction, DISPID_ITransaction_Abort);

  if (fAsync)
    return ErrorInfo::Set(XACT_E_NOTSUPPORTED, std::string ("Async abort not supported"));
  return EndTransaction(false, fRetaining != 0);
}

STDMETHODIMP
CSession::Commit(
  BOOL fRetaining,
  DWORD grfTC,
  DWORD grfRM
)
{
  LOGCALL(("CSession::Commit()\n"));

  ErrorCheck error(IID_ITransaction, DISPID_ITransaction_Commit);

  //if (grfTC != XACTTC_SYNC || grfRM != 0)
  if (grfRM != 0)
    return ErrorInfo::Set(XACT_E_NOTSUPPORTED, std::string ("grfRM on Commit() must be zero"));
  if (grfTC != XACTTC_NONE && grfTC != XACTTC_SYNC)
    {
      LOG(("CSession::Commit grfTC=%u\n",
	    (unsigned) grfTC));
      return ErrorInfo::Set(XACT_E_NOTSUPPORTED, std::string ("Async Commit() not supported"));
    }
  return EndTransaction(true, fRetaining != 0);
}

STDMETHODIMP
CSession::GetTransactionInfo(
  XACTTRANSINFO *pinfo
)
{
  LOGCALL(("CSession::GetTransactionInfo()\n"));

  ErrorCheck error(IID_ITransaction, DISPID_ITransaction_GetTransactionInfo);

  if (pinfo == NULL)
    return ErrorInfo::Set(E_INVALIDARG);

  CriticalSection critical_section(this);
  if (m_xactState == XACT_NONE)
    return ErrorInfo::Set(XACT_E_NOTRANSACTION);

  pinfo->uow = m_uow;
  pinfo->isoLevel = m_isoLevel;
  pinfo->isoFlags = 0;
  pinfo->grfTCSupported = XACTTC_SYNC;
  pinfo->grfRMSupported = 0;
  pinfo->grfTCSupportedRetaining = 0;
  pinfo->grfRMSupportedRetaining = 0;

  return S_OK;
}

////////////////////////////////////////////////////////////////////////
// ITransactionJoin

STDMETHODIMP
CSession::GetOptionsObject(
  ITransactionOptions **ppOptions
)
{
  LOGCALL(("CSession::GetOptionsObject()\n"));

  ErrorCheck error(IID_ITransactionJoin, DISPID_ITransactionJoin_GetOptionsObject);

  return ErrorInfo::Set(DB_E_NOTSUPPORTED, std::string ("GetOptionsObject () not supported in ITransactionJoin"));
}

STDMETHODIMP
CSession::JoinTransaction(
  IUnknown* pUnkTransactionCoord,
  ISOLEVEL isoLevel,
  ULONG isoFlags,
  ITransactionOptions *pOtherOptions
)
{
  LOGCALL(("CSession::JoinTransaction()\n"));

  ErrorCheck error(IID_ITransactionJoin, DISPID_ITransactionJoin_JoinTransaction);

  if (isoFlags != 0)
    {
      LOG(("CSession::JoinTransaction() no isoFlags\n"));
      return ErrorInfo::Set(XACT_E_NOISORETAIN);
    }

  if (pOtherOptions != NULL)
    {
      XACTOPT options;
      HRESULT hr = pOtherOptions->GetOptions(&options);
      if (FAILED(hr))
	{
	  LOG(("CSession::JoinTransaction() GetOptions() failed\n"));
	  return hr;
	}

      if (options.ulTimeout != 0)
	{
	  LOG(("CSession::JoinTransaction() ulTimeout != 0\n"));
	  return ErrorInfo::Set(XACT_E_NOTIMEOUT);
	}
    }

  HRESULT hr;
  AutoInterface<ITransaction> pTransaction;
  if (pUnkTransactionCoord != NULL)
    {
      hr = pTransaction.QueryInterface(pUnkTransactionCoord, IID_ITransaction);
      if (FAILED(hr))
	{
	  LOG(("CSession::JoinTransaction() queryInterface IID_ITransaction != 0\n"));
	  return hr;
	}
    }

  CriticalSection critical_section(this);

  if (m_xactState == XACT_LOCAL)
    {
      LOG(("CSession::JoinTransaction() xactState != XACT_LOCAL\n"));
      return XACT_E_XTIONEXISTS;
    }

  LOG(("CSession::JoinTransaction() pUnkTransactionCoord=%p\n", pUnkTransactionCoord));
  if (pUnkTransactionCoord != NULL)
    {
      hr = m_connection.EnlistInDTC(pTransaction.Get());
      if (FAILED(hr))
	{
	  LOG(("CSession::JoinTransaction() enlistInDTC1 Failed\n"));
	  return hr;
	}
      hr = m_connection.SetTransactionAttrs(false, isoLevel);
      if (FAILED(hr))
	{
	  LOG(("CSession::JoinTransaction() SetTransactionAttrs1 Failed\n"));
	  return hr;
	}

      m_xactState = XACT_DISTRIBUTED;
      m_isoLevel = isoLevel;
      m_nTrxLevel ++;
      LOG(("CSession::JoinTransaction() m_xactState = XACT_DISTRIBUTED nTrxLevel=%d\n",
	    m_nTrxLevel));

      XACTTRANSINFO info;
      hr = pTransaction->GetTransactionInfo(&info);
      if (FAILED(hr))
	{
	  LOG(("CSession::JoinTransaction() GetTransactionInfo1 Failed\n"));
	  return hr;
	}

      m_uow = info.uow;
    }
  else
    {
      hr = m_connection.EnlistInDTC(NULL);
      if (FAILED(hr))
	{
	  LOG(("CSession::JoinTransaction() EnlistInDTC2 Failed\n"));
	  return hr;
	}

      hr = m_connection.SetTransactionAttrs(true, m_pSessionPropertySet->prop_sess_autocommitisolevels.GetValue());
      if (FAILED(hr))
	{
	  LOG(("CSession::JoinTransaction() SetTransactionAttrs2 Failed\n"));
	  return hr;
	}

      if (m_xactState == XACT_DISTRIBUTED)
	{ /* this is a dummy to emulate support for subtransactions */
	  LOG(("CSession::JoinTransaction() m_xactState = XACT_DISTRIBUTED pUnkTransactionCoord=NULL nTrxLevel=%d\n",
		m_nTrxLevel));
          hr = EndTransaction (true, false);
	  if (FAILED(hr))
	    {
	      LOG(("CSession::JoinTransaction() EndTransaction Failed\n"));
	      return hr;
	    }
	}
      m_xactState = XACT_NONE;
    }

  LOG(("CSession::JoinTransaction() done\n"));
  return S_OK;
}

////////////////////////////////////////////////////////////////////////
// ITransactionLocal

#if 0
STDMETHODIMP
CSession::GetOptionsObject(
  ITransactionOptions **ppOptions
)
{
  LOGCALL(("CSession::GetOptionsObject()\n"));

  ErrorCheck error(IID_ITransactionLocal, DISPID_ITransactionLocal_GetOptionsObject);

  return ErrorInfo::Set(DB_E_NOTSUPPORTED);
}
#endif

STDMETHODIMP
CSession::StartTransaction(
  ISOLEVEL isoLevel,
  ULONG isoFlags,
  ITransactionOptions *pOtherOptions,
  ULONG *pulTransactionLevel
)
{
  LOGCALL(("CSession::StartTransaction()\n"));

  ErrorCheck error(IID_ITransactionLocal, DISPID_ITransactionLocal_StartTransaction);

  if (isoFlags != 0)
    {
      LOG(("CSession::StartTransaction() no isoFlags\n"));
      return ErrorInfo::Set(XACT_E_NOISORETAIN);
    }

  if (pOtherOptions != NULL)
    {
      XACTOPT options;
      HRESULT hr = pOtherOptions->GetOptions(&options);
      if (FAILED(hr))
	{
	  LOG(("CSession::StartTransaction() setOptions failed\n"));
	  return hr;
	}

      if (options.ulTimeout != 0)
	{
	  LOG(("CSession::StartTransaction() ulTimeout != 0\n"));
	  return ErrorInfo::Set(XACT_E_NOTIMEOUT);
	}
    }

  CriticalSection critical_section(this);

  if (m_xactState == XACT_DISTRIBUTED)
    { /* this is a dummy to emulate support for subtransactions */
      m_nTrxLevel ++;
      LOG(("CSession::StartTransaction() m_xactState = XACT_DISTRIBUTED nTrxLevel=%d\n",
	    m_nTrxLevel));
      if (pulTransactionLevel != NULL)
	*pulTransactionLevel = m_nTrxLevel;
      return S_OK;
    }
  else if (m_xactState != XACT_NONE)
    {
      LOG(("CSession::StartTransaction() m_xactState != XACT_NONE\n"));
      return XACT_E_XTIONEXISTS;
    }

  HRESULT hr = m_connection.SetTransactionAttrs(false, isoLevel);
  if (FAILED(hr))
    {
      LOG(("CSession::StartTransaction() SetTransactionAttrs failed\n"));
      return hr;
    }

  m_xactState = XACT_LOCAL;
  m_isoLevel = isoLevel;
  UuidCreate((GUID*) &m_uow);

  if (pulTransactionLevel != NULL)
    *pulTransactionLevel = 1;

  LOG(("CSession::StartTransaction() done\n"));
  return S_OK;
}

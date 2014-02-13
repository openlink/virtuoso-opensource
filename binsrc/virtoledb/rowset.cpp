/*  rowset.cpp
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
#include "rowset.h"
#include "rowsetprops.h"
#include "command.h"
#include "session.h"
#include "datasource.h"
#include "lobdata.h"
#include "util.h"

#ifdef _MSC_VER
# include <malloc.h>
#else
# include <alloca.h>
#endif

#if DEBUG
# include <crtdbg.h>
#endif

/**********************************************************************/
/* CRowset                                                            */

CRowset::CRowset()
  : m_RowsetNotifyCP(IID_IRowsetNotify)
{
  LOGCALL(("CRowset::CRowset()\n"));

  m_pParameters = NULL;
  m_pCommandHandler = NULL;
  m_pRowPolicy = NULL;
  m_pRowsetPolicy = NULL;
  m_pUnkSpec = NULL;
  m_pUnkFTM = NULL;
}

CRowset::~CRowset()
{
  LOGCALL(("CRowset::~CRowset()\n"));
}

HRESULT
CRowset::Create()
{
  LOGCALL(("CRowset::Create()\n"));

  m_RowsetNotifyCP.Init(GetControllingUnknown());
  m_rgpCP[0] = &m_RowsetNotifyCP;
  m_rgpCP[1] = NULL;
  return S_OK;
}

HRESULT
CRowset::Initialize (CRowsetSessionInitializer *pInitializer)
{
  Create ();
  pInitializer->hr = Init (
    pInitializer->sess, pInitializer->query,
    pInitializer->pSchema, pInitializer->cRestrictions, pInitializer->rgRestrictions,
    pInitializer->riid, pInitializer->cPropertySets, pInitializer->rgPropertySets
  );
  return pInitializer->hr;
}

HRESULT
CRowset::Initialize (CRowsetCommandInitializer *pInitializer)
{
  Create ();
  pInitializer->hr = Init (
    pInitializer->comm, pInitializer->handler, pInitializer->stmt, pInitializer->rps, pInitializer->riid
  );
  return pInitializer->hr;
}

HRESULT
CRowset::Initialize (CRowsetColumnsInitializer *pInitializer)
{
  Create ();
  pInitializer->hr = Init (
    pInitializer->pDataObj, pInitializer->pRowsetInfo,
    pInitializer->cOptColumns, pInitializer->rgOptColumns,
    pInitializer->riid, pInitializer->cPropertySets, pInitializer->rgPropertySets
  );
  return pInitializer->hr;
}

void
CRowset::Delete()
{
  LOGCALL(("CRowset::Delete()\n"));

  if (rowset_property_set != NULL)
    OnRowsetChange(DBREASON_ROWSET_RELEASE, DBEVENTPHASE_DIDEVENT);

  FreeResources();

  CSession* pSession = GetSession();
  if (pSession != NULL)
    pSession->RemoveRowset(this);

  if (m_pUnkSpec != NULL)
    {
      m_pUnkSpec->Release();
      m_pUnkSpec = NULL;
    }
  if (m_pUnkFTM != NULL)
    {
      m_pUnkFTM->Release();
      m_pUnkFTM = NULL;
    }
}

void
CRowset::FreeResources()
{
  if (m_pCommandHandler != NULL)
    {
      m_pCommandHandler->RowsetCloseNotify();
      m_pCommandHandler = NULL;
      rowset_property_set = NULL;
    }
  else if (rowset_property_set != NULL)
    {
      delete rowset_property_set;
      rowset_property_set = NULL;
    }

  if (m_pParameters != NULL)
    {
      delete m_pParameters;
      m_pParameters = NULL;
    }

  // NB: RowPolicy destruction must go after RowsetPolicy destruction
  //     because the later might use the former.
  if (m_pRowsetPolicy != NULL)
    {
      m_pRowsetPolicy->KillStreamObject();
      delete m_pRowsetPolicy;
      m_pRowsetPolicy = NULL;
    }
  if (m_pRowPolicy != NULL)
    {
      delete m_pRowPolicy;
      m_pRowPolicy = NULL;
    }

  if (m_statement.IsInitialized())
    m_statement.Release();

  std::map<HROW, char*>::iterator iter;
  for (iter = m_mpOriginalData.begin(); iter != m_mpOriginalData.end(); iter++)
    {
      delete [] iter->second;
      iter->second = NULL;
    }
  for (iter = m_mpVisibleData.begin(); iter != m_mpVisibleData.end(); iter++)
    {
      delete [] iter->second;
      iter->second = NULL;
    }
  m_mpOriginalData.clear();
  m_mpVisibleData.clear();
}

HRESULT
CRowset::GetInterface(REFIID riid, IUnknown** ppUnknown)
{
  LOGCALL (("CRowset::GetInterface(%s)\n", STRINGFROMGUID (riid)));

  IUnknown* pUnknown = NULL;
  if (riid == IID_IAccessor)
    pUnknown = static_cast<IAccessor*>(this);
  else if (riid == IID_IColumnsInfo)
    pUnknown = static_cast<IColumnsInfo*>(this);
  else if (riid == IID_IColumnsRowset)
    pUnknown = static_cast<IColumnsRowset*>(this);
  else if (riid == IID_IConvertType)
    pUnknown = static_cast<IConvertType*>(this);
  else if (riid == IID_IConnectionPointContainer)
    {
      if (rowset_property_set->prop_IConnectionPointContainer.GetValue() == VARIANT_TRUE)
	pUnknown = static_cast<IConnectionPointContainer*>(this);
    }
  else if (riid == IID_IRowset)
    pUnknown = static_cast<IRowset*>(this);
  else if (riid == IID_IRowsetChange)
    {
      if (rowset_property_set->prop_IRowsetChange.GetValue() == VARIANT_TRUE)
	pUnknown = static_cast<IRowsetChange*>(this);
    }
#if 0
  else if (riid == IID_IRowsetFind)
    {
      if (rowset_property_set->prop_IRowsetFind.GetValue() == VARIANT_TRUE)
	pUnknown = static_cast<IRowsetFind*>(this);
    }
#endif
  else if (riid == IID_IRowsetIdentity)
    {
      if (rowset_property_set->prop_IRowsetIdentity.GetValue() == VARIANT_TRUE)
	pUnknown = static_cast<IRowsetIdentity*>(this);
    }
  else if (riid == IID_IRowsetInfo)
    pUnknown = static_cast<IRowsetInfo*>(this);
  else if (riid == IID_IRowsetLocate)
    {
      if (rowset_property_set->prop_IRowsetLocate.GetValue() == VARIANT_TRUE)
	pUnknown = static_cast<IRowsetLocate*>(this);
    }
  else if (riid == IID_IRowsetRefresh)
    {
      if (rowset_property_set->prop_IRowsetRefresh.GetValue() == VARIANT_TRUE)
	pUnknown = static_cast<IRowsetRefresh*>(this);
    }
  else if (riid == IID_IRowsetResynch)
    {
      if (rowset_property_set->prop_IRowsetResynch.GetValue() == VARIANT_TRUE)
	pUnknown = static_cast<IRowsetResynch*>(this);
    }
  else if (riid == IID_IRowsetScroll)
    {
      if (rowset_property_set->prop_IRowsetScroll.GetValue() == VARIANT_TRUE)
	pUnknown = static_cast<IRowsetScroll*>(this);
    }
  else if (riid == IID_IRowsetUpdate)
    {
      if (rowset_property_set->prop_IRowsetUpdate.GetValue() == VARIANT_TRUE)
	pUnknown = static_cast<IRowsetUpdate*>(this);
    }
  else if (riid == IID_ISupportErrorInfo)
    {
      if (rowset_property_set->prop_ISupportErrorInfo.GetValue() == VARIANT_TRUE)
	pUnknown = static_cast<ISupportErrorInfo*>(this);
    }
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
CRowset::GetSupportErrorInfoIIDs()
{
  static const IID* rgpIIDs[] =
  {
    &IID_IAccessor,
    &IID_IColumnsInfo,
    &IID_IColumnsRowset,
    &IID_IConvertType,
    &IID_IRowset,
    &IID_IRowsetChange,
    &IID_IRowsetIdentity,
    &IID_IRowsetInfo,
    &IID_IRowsetLocate,
    &IID_IRowsetRefresh,
    &IID_IRowsetResynch,
    &IID_IRowsetScroll,
    &IID_IRowsetUpdate,
    NULL
  };
  return rgpIIDs;
}

IConnectionPoint**
CRowset::GetConnectionPoints()
{
  return m_rgpCP;
}

HRESULT
CRowset::InitFirst(CSession* pSession, IUnknown* pUnkSpec, RowsetPropertySet* rps)
{
  assert(pUnkSpec != NULL);
  m_pUnkSpec = pUnkSpec;
  m_pUnkSpec->AddRef();

  HRESULT hr = CDataObj::Init(pSession, rps);
  if (FAILED(hr))
    return hr;
  hr = pSession->AddRowset(this);
  if (FAILED(hr))
    return hr;

  return S_OK;
}

HRESULT
CRowset::Init(
  CSession* sess,
  ostring& query,
  Schema* pSchema,
  ULONG cRestrictions,
  const VARIANT rgRestrictions[],
  REFIID riid,
  ULONG cPropertySets,
  DBPROPSET rgPropertySets[]
)
{
  LOGCALL(("CRowset::Init('%ls')\n", query.c_str()));

  RowsetPropertySet* rps = new RowsetPropertySet();
  if (rps == NULL)
    return ErrorInfo::Set(E_OUTOFMEMORY);
  if (rps->Init() == false)
    return ErrorInfo::Set(E_OUTOFMEMORY);

  HRESULT hr = InitFirst(sess, sess->GetControllingUnknown(), rps);
  if (FAILED(hr))
    return hr;

  // Note that it is possible to get two success return codes here:
  // S_OK and DB_S_ERRORSOCCURED. The code which is actualy got should
  // be kept to be returned if no error occurs after this point.
  HRESULT hr_props = SetProperties(cPropertySets, rgPropertySets, true);
  if (FAILED(hr_props))
    return hr_props;
  DBPROPID propid;
  if (rps->ConvertRowsetIIDToPropertyID(riid, propid) == S_OK)
    {
      hr = rps->SetRowsetProperty(propid);
      if (FAILED(hr))
	return hr;
      if (hr != S_OK)
	return ErrorInfo::Set(E_NOINTERFACE);
    }

  hr = m_statement.Init(GetSession()->GetConnection(), rowset_property_set);
  if (FAILED(hr))
    return hr;

  if (pSchema != NULL)
    {
      // Allocate parameters and keep them for the whole rowset life
      // because they are necessary if a statement is reexecuted by
      // the RestartPosition() method.
      m_pParameters = new ParameterPolicy();
      if (m_pParameters == NULL)
	return ErrorInfo::Set(E_OUTOFMEMORY);
      hr = m_pParameters->Init(m_statement, pSchema, cRestrictions, rgRestrictions, m_dth.GetDataConvert());
      if (FAILED(hr))
	return hr;
    }

  hr = m_statement.Execute(query);
  if (FAILED(hr))
    return hr;

  hr = InitFinal(pSchema);
  if (FAILED(hr))
    return hr;

  return hr_props;
}

HRESULT
CRowset::Init(
  CDataObj* pDataObj,
  const RowsetInfo* pRowsetInfo,
  DBORDINAL cOptColumns,
  const DBID rgOptColumns[],
  REFIID riid,
  ULONG cPropertySets,
  DBPROPSET rgPropertySets[]
)
{
  LOGCALL(("CRowset::Init()\n"));

  assert(pDataObj != NULL);
  assert(pRowsetInfo != NULL);

  RowsetPropertySet* rps = new RowsetPropertySet();
  if (rps == NULL)
    return ErrorInfo::Set(E_OUTOFMEMORY);
  if (rps->Init() == false)
    return ErrorInfo::Set(E_OUTOFMEMORY);

  HRESULT hr = InitFirst(pDataObj->GetSession(), pDataObj->GetControllingUnknown(), rps);
  if (FAILED(hr))
    return hr;

  // Note that it is possible to get two success return codes here:
  // S_OK and DB_S_ERRORSOCCURED. The code which is actualy got should
  // be kept to be returned if no error occurs after this point.
  HRESULT hr_props = SetProperties(cPropertySets, rgPropertySets, true);
  if (FAILED(hr_props))
    return hr_props;
  DBPROPID propid;
  if (rps->ConvertRowsetIIDToPropertyID(riid, propid) == S_OK)
    {
      hr = rps->SetRowsetProperty(propid);
      if (FAILED(hr))
	return hr;
      if (hr != S_OK)
	return ErrorInfo::Set(E_NOINTERFACE);
    }

  rowset_property_set->RefineProperties(SQL_CURSOR_STATIC, SQL_CONCUR_READ_ONLY, false);

  hr = m_info.Init(cOptColumns, rgOptColumns, rowset_property_set->HasBookmark());
  if (FAILED(hr))
    {
      LOG (("CRowset::Init() err after RowsetInfo init\n"));
      return hr;
    }
  hr = m_info.Complete();
  if (FAILED(hr))
    {
      LOG (("CRowset::Init() err after RowsetInfo complete\n"));
      return hr;
    }

  AutoRelease<ColumnsRowsPolicy> pColumnsRowsPolicy(new ColumnsRowsPolicy());
  if (pColumnsRowsPolicy == NULL)
    return ErrorInfo::Set(E_OUTOFMEMORY);
  hr = pColumnsRowsPolicy->Init(pRowsetInfo->GetFieldCount(), &m_info);
  if (FAILED(hr))
    {
      LOG (("CRowset::Init() err after RowsPolicy.Init\n"));
      return hr;
    }
  m_pRowPolicy = pColumnsRowsPolicy.GiveUp();

  DBORDINAL cColumns = pRowsetInfo->GetFieldCount();
  DBORDINAL cHiddenColumns = pRowsetInfo->GetHiddenColumns();
  for (ULONG iColumn = 0; iColumn < cColumns; iColumn++)
    {
      const ColumnInfo& column_info = pRowsetInfo->GetColumnInfo(iColumn);
      RowData* pRowData = m_pRowPolicy->GetRowData(iColumn + 1);
      m_info.InitMetaRow(pRowsetInfo->IndexToOrdinal(iColumn), column_info,
			 iColumn >= cColumns - cHiddenColumns, pRowData->GetData());
    }

  SyntheticPolicy* policy = new SyntheticPolicy(&m_info, m_pRowPolicy);
  if (policy == NULL)
    return ErrorInfo::Set(E_OUTOFMEMORY);
  hr = policy->Init(pRowsetInfo->GetFieldCount());
  if (FAILED(hr))
    return hr;
  m_pRowsetPolicy = policy;

  // TODO: INERROR properties.

  return hr_props;
}

HRESULT
CRowset::Init(
  CCommand* comm,
  CommandHandler* pHandler,
  Statement& stmt,
  RowsetPropertySet* rps,
  REFIID riid
)
{
  LOGCALL(("CRowset::Init()\n"));

  assert(pHandler != NULL);
  m_pCommandHandler = pHandler;

  HRESULT hr = InitFirst(comm->GetSession(), comm->GetControllingUnknown(), rps);
  if (FAILED(hr))
    return hr;
  hr = CopyRowAccessors(comm);
  if (FAILED(hr))
    return hr;
  m_statement = stmt;

  return InitFinal();
}

HRESULT
CRowset::InitFinal(Schema* pSchema)
{
  HRESULT hr = m_info.Init(m_statement, pSchema);
  if (FAILED(hr))
    return hr;
  hr = m_info.Complete();
  if (FAILED(hr))
    return hr;

  /* Get the real cursor type. It could be different from one deduced from the properties.*/
  ULONG ulCursorType = m_statement.GetCursorType();
  ULONG ulConcurrency = m_statement.GetConcurrency();
  bool fUniqueRows = m_statement.GetUniqueRows();
  if (ulCursorType == VDB_BAD_CURSOR_TYPE || ulConcurrency == VDB_BAD_CONCURRENCY)
    return ErrorInfo::Get()->GetErrorCode();

  /* Set all the properties according to the real cursor type. */
  rowset_property_set->RefineProperties(ulCursorType, ulConcurrency, fUniqueRows);
  rowset_property_set->prop_HIDDENCOLUMNS.SetValue((LONG)m_info.GetHiddenColumns());

  if (rowset_property_set->prop_CANHOLDROWS.GetValue() == VARIANT_TRUE)
    m_pRowPolicy = new CanHoldRowsPolicy();
  else
    m_pRowPolicy = new ReleaseRowsPolicy();

  if (m_pRowPolicy == NULL)
    return ErrorInfo::Set(E_OUTOFMEMORY);

  if (ulCursorType == SQL_CURSOR_FORWARD_ONLY)
    {
      ForwardOnlyPolicy* policy = new ForwardOnlyPolicy(&m_info, m_pRowPolicy, m_pCommandHandler);
      if (policy == NULL)
	return ErrorInfo::Set(E_OUTOFMEMORY);
      HRESULT hr = policy->Init(m_statement);
      if (FAILED(hr))
	return hr;
      m_pRowsetPolicy = policy;
    }
  else if (ulCursorType == SQL_CURSOR_DYNAMIC)
    {
      ScrollablePolicy* policy = new ScrollablePolicy(&m_info, m_pRowPolicy);
      if (policy == NULL)
	return ErrorInfo::Set(E_OUTOFMEMORY);
      HRESULT hr = policy->Init(m_statement);
      if (FAILED(hr))
	return hr;
      m_pRowsetPolicy = policy;
    }
  else if (ulCursorType == SQL_CURSOR_STATIC || ulCursorType == SQL_CURSOR_KEYSET_DRIVEN)
    {
      PositionalPolicy* policy = new PositionalPolicy(&m_info, m_pRowPolicy);
      if (policy == NULL)
	return ErrorInfo::Set(E_OUTOFMEMORY);
      HRESULT hr = policy->Init(m_statement);
      if (FAILED(hr))
	return hr;
      m_pRowsetPolicy = policy;
    }
  else
    return ErrorInfo::Set(E_FAIL);

  // TODO: INERROR properties.

  return S_OK;
}

bool
CRowset::IsCommand() const
{
  return false;
}

bool
CRowset::IsChangeableRowset() const
{
  return rowset_property_set->prop_IRowsetChange.GetValue() == VARIANT_TRUE;
}

HRESULT
CRowset::GetRowsetInfo(const RowsetInfo*& rowset_info_p) const
{
  rowset_info_p = NULL;

  if (zombie)
    return ErrorInfo::Set(E_UNEXPECTED);

  rowset_info_p = &m_info;
  return S_OK;
}

void
CRowset::EndTransaction(bool commit)
{
  LOGCALL (("CRowset::EndTransaction(%d)\n", commit));

  CriticalSection critical_section(this);

  if ((commit && rowset_property_set->prop_COMMITPRESERVE.GetValue() == VARIANT_FALSE)
      || (!commit && rowset_property_set->prop_ABORTPRESERVE.GetValue() == VARIANT_FALSE))
    {
      zombie = true;
      FreeResources();
    }
}

HRESULT
CRowset::OnFieldChange(
  HROW hRow,
  DBORDINAL cColumns,
  DBORDINAL rgColumns[],
  DBREASON eReason,
  DBEVENTPHASE ePhase
)
{
  if (rowset_property_set->prop_IConnectionPointContainer.GetValue() == VARIANT_FALSE)
    return S_OK;
  if (cColumns == 0)
    return S_OK;

  DWORD dwCookie;
  IUnknown* pUnkSink;

  bool fCanceled = false;
  bool fCantDeny = (ePhase == DBEVENTPHASE_DIDEVENT || ePhase == DBEVENTPHASE_FAILEDTODO);
  bool fNextSink = m_RowsetNotifyCP.GetFirstConnection(&dwCookie, &pUnkSink);
  while (fNextSink)
    {
      AutoInterface<IRowsetNotify> pRowsetNotify;
      HRESULT hr = pRowsetNotify.QueryInterface(pUnkSink, IID_IRowsetNotify);
      if (SUCCEEDED(hr))
	{
	  hr = pRowsetNotify->OnFieldChange(static_cast<IRowset*>(this), hRow, cColumns, rgColumns,
					    eReason, ePhase, fCantDeny ? TRUE : FALSE);
	  if (hr == S_FALSE && !fCantDeny)
	    {
	      fCanceled = true;
	      pUnkSink->Release();
	      break;
	    }
	}

      pUnkSink->Release();
      fNextSink = m_RowsetNotifyCP.GetNextConnection(dwCookie, &dwCookie, &pUnkSink);
    }

  if (fCanceled)
    {
      DWORD dwCookieBis;

      fNextSink = m_RowsetNotifyCP.GetFirstConnection(&dwCookieBis, &pUnkSink);
      while (fNextSink && (ePhase != DBEVENTPHASE_OKTODO || !m_RowsetNotifyCP.Before(dwCookieBis, dwCookie)))
	{
	  AutoInterface<IRowsetNotify> pRowsetNotify;
	  HRESULT hr = pRowsetNotify.QueryInterface(pUnkSink, IID_IRowsetNotify);
	  if (SUCCEEDED(hr))
	    pRowsetNotify->OnFieldChange(static_cast<IRowset*>(this), hRow, cColumns, rgColumns,
					 eReason, DBEVENTPHASE_FAILEDTODO, TRUE);
	  pUnkSink->Release();
	  fNextSink = m_RowsetNotifyCP.GetNextConnection(dwCookieBis, &dwCookieBis, &pUnkSink);
	}

      return S_FALSE;
    }

  return S_OK;
}

HRESULT
CRowset::OnRowActivate(DBCOUNTITEM cRows, const HROW rghRows[])
{
  if (rowset_property_set->prop_IConnectionPointContainer.GetValue() == VARIANT_FALSE)
    return S_OK;
  if (!m_RowsetNotifyCP.HasConnections())
    return S_OK;

  DBCOUNTITEM cFilteredRows = 0;
  HROW* rghFilteredRows = (HROW*) alloca(cRows * sizeof(HROW));
  if (rghFilteredRows == NULL)
    return S_OK;

  for (DBCOUNTITEM iRow = 0; iRow < cRows; iRow++)
    {
      HROW hRow = rghRows[iRow];
      if (hRow == DB_NULL_HROW)
	continue;

      RowData* pRowData = m_pRowPolicy->GetRowData(hRow);
      assert(pRowData != NULL);

      LONG iRefRow = pRowData->GetRefRow();
      if (iRefRow == 1)
	rghFilteredRows[cFilteredRows++] = hRow;
    }

  return OnRowChange(cFilteredRows, rghFilteredRows, DBREASON_ROW_ACTIVATE, DBEVENTPHASE_DIDEVENT);
}

HRESULT
CRowset::OnRowChange(
  DBCOUNTITEM cRows,
  const HROW rghRows[],
  DBREASON eReason,
  DBEVENTPHASE ePhase
)
{
  if (rowset_property_set->prop_IConnectionPointContainer.GetValue() == VARIANT_FALSE)
    return S_OK;
  if (cRows == 0)
    return S_OK;

  DWORD dwCookie;
  IUnknown* pUnkSink;

  bool fCanceled = false;
  bool fCantDeny = (ePhase == DBEVENTPHASE_DIDEVENT || ePhase == DBEVENTPHASE_FAILEDTODO);
  bool fNextSink = m_RowsetNotifyCP.GetFirstConnection(&dwCookie, &pUnkSink);
  while (fNextSink)
    {
      AutoInterface<IRowsetNotify> pRowsetNotify;
      HRESULT hr = pRowsetNotify.QueryInterface(pUnkSink, IID_IRowsetNotify);
      if (SUCCEEDED(hr))
	{
	  hr = pRowsetNotify->OnRowChange(static_cast<IRowset*>(this), cRows, rghRows,
					  eReason, ePhase, fCantDeny ? TRUE : FALSE);
	  if (hr == S_FALSE && !fCantDeny)
	    {
	      fCanceled = true;
	      pUnkSink->Release();
	      break;
	    }
	}

      pUnkSink->Release();
      fNextSink = m_RowsetNotifyCP.GetNextConnection(dwCookie, &dwCookie, &pUnkSink);
    }

  if (fCanceled)
    {
      DWORD dwCookieBis;

      fNextSink = m_RowsetNotifyCP.GetFirstConnection(&dwCookieBis, &pUnkSink);
      while (fNextSink && (ePhase != DBEVENTPHASE_OKTODO || !m_RowsetNotifyCP.Before(dwCookieBis, dwCookie)))
	{
	  AutoInterface<IRowsetNotify> pRowsetNotify;
	  HRESULT hr = pRowsetNotify.QueryInterface(pUnkSink, IID_IRowsetNotify);
	  if (SUCCEEDED(hr))
	    pRowsetNotify->OnRowChange(static_cast<IRowset*>(this), cRows, rghRows,
				       eReason, DBEVENTPHASE_FAILEDTODO, TRUE);
	  pUnkSink->Release();
	  fNextSink = m_RowsetNotifyCP.GetNextConnection(dwCookieBis, &dwCookieBis, &pUnkSink);
	}

      return S_FALSE;
    }

  return S_OK;
}

HRESULT
CRowset::OnRowsetChange(DBREASON eReason, DBEVENTPHASE ePhase)
{
  if (rowset_property_set->prop_IConnectionPointContainer.GetValue() == VARIANT_FALSE)
    return S_OK;

  DWORD dwCookie;
  IUnknown* pUnkSink;

  bool fCanceled = false;
  bool fCantDeny = (ePhase == DBEVENTPHASE_DIDEVENT || ePhase == DBEVENTPHASE_FAILEDTODO);
  bool fNextSink = m_RowsetNotifyCP.GetFirstConnection(&dwCookie, &pUnkSink);
  while (fNextSink && !fCanceled)
    {
      AutoInterface<IRowsetNotify> pRowsetNotify;
      HRESULT hr = pRowsetNotify.QueryInterface(pUnkSink, IID_IRowsetNotify);
      if (SUCCEEDED(hr))
	{
	  hr = pRowsetNotify->OnRowsetChange(static_cast<IRowset*>(this),
					     eReason, ePhase, fCantDeny ? TRUE : FALSE);
	  if (hr == S_FALSE && !fCantDeny)
	    {
	      fCanceled = true;
	      pUnkSink->Release();
	      break;
	    }
	}

      pUnkSink->Release();
      fNextSink = m_RowsetNotifyCP.GetNextConnection(dwCookie, &dwCookie, &pUnkSink);
    }

  if (fCanceled)
    {
      DWORD dwCookieBis;

      fNextSink = m_RowsetNotifyCP.GetFirstConnection(&dwCookieBis, &pUnkSink);
      while (fNextSink && (ePhase != DBEVENTPHASE_OKTODO || !m_RowsetNotifyCP.Before(dwCookieBis, dwCookie)))
	{
	  AutoInterface<IRowsetNotify> pRowsetNotify;
	  HRESULT hr = pRowsetNotify.QueryInterface(pUnkSink, IID_IRowsetNotify);
	  if (SUCCEEDED(hr))
	    pRowsetNotify->OnRowsetChange(static_cast<IRowset*>(this),
					  eReason, DBEVENTPHASE_FAILEDTODO, TRUE);
	  pUnkSink->Release();
	  fNextSink = m_RowsetNotifyCP.GetNextConnection(dwCookieBis, &dwCookieBis, &pUnkSink);
	}

      return S_FALSE;
    }

  return S_OK;
}

HRESULT
CRowset::GetData(HROW hRow, char* pbProviderData, const DataAccessor& accessor, char* pbConsumerData)
{
  bool failure = false;
  bool success = false;

  for (DBCOUNTITEM iBinding = 0; iBinding < accessor.GetBindingCount (); iBinding++)
    {
      HRESULT hr = m_dth.GetData(m_info, m_pRowsetPolicy->GetGetDataHandler(), 
	hRow, pbProviderData, accessor, iBinding, pbConsumerData, false);
      if (FAILED(hr))
	{
	  ErrorInfo::Clear();
	  failure = true;
	}
      else if (hr == S_FALSE)
	failure = true;
      else
	success = true;
    }

  return failure ? success ? DB_S_ERRORSOCCURRED : DB_E_ERRORSOCCURRED : S_OK;
}

HRESULT
CRowset::SaveOriginalData(HROW hRow, RowData* pRowData)
{
  AutoRelease<char, DeleteArray <char> > pbOriginalData;
  if (pRowData != NULL)
    {
      pbOriginalData.Set(new char[m_info.GetRecordSize()]);
      if (pbOriginalData == NULL)
	return ErrorInfo::Set(E_OUTOFMEMORY);
      memcpy(pbOriginalData.Get(), pRowData->GetData(), m_info.GetRecordSize());
    }

  try {
    m_mpOriginalData.insert(std::map<HROW, char*>::value_type(hRow, pbOriginalData.Get()));
  } catch (...) {
    return ErrorInfo::Set(E_OUTOFMEMORY);
  }

  pbOriginalData.GiveUp();
  return S_OK;
}

void
CRowset::FreeOriginalData(HROW hRow)
{
  std::map<HROW, char*>::iterator iter = m_mpOriginalData.find(hRow);
  if (iter == m_mpOriginalData.end())
    return;

  delete [] iter->second;
  m_mpOriginalData.erase(iter);
}

void
CRowset::FreeVisibleData(HROW hRow)
{
  std::map<HROW, char*>::iterator iter = m_mpVisibleData.find(hRow);
  if (iter == m_mpVisibleData.end())
    return;

  delete [] iter->second;
  m_mpVisibleData.erase(iter);
}

/**********************************************************************/
/* IRowset                                                            */

STDMETHODIMP
CRowset::AddRefRows(
  DBCOUNTITEM cRows,
  const HROW rghRows[],
  DBREFCOUNT rgRefCounts[],
  DBROWSTATUS rgRowStatus[]
)
{
  LOGCALL(("CRowset::AddRefRows()\n"));

  ErrorCheck error(IID_IRowset, DISPID_IRowset_AddRefRows);

  if (cRows == 0)
    return S_OK;
  if (rghRows == NULL)
    return ErrorInfo::Set(E_INVALIDARG);

  CriticalSection critical_section(this);
  if (zombie)
    return ErrorInfo::Set(E_UNEXPECTED);

  bool success = false;
  bool failure = false;
  for (ULONG i = 0; i < cRows; i++)
    {
      HROW hRow = rghRows[i];
      RowData* pRowData = m_pRowPolicy->GetRowData(hRow);

      ULONG dwRefCount = 0;
      DBROWSTATUS dwRowStatus = DBROWSTATUS_E_INVALID;
      if (pRowData != NULL)
	{
	  DBPENDINGSTATUS dwPendingStatus = pRowData->GetStatus();
	  if (dwPendingStatus != 0)
	    {
	      // the row was deleted
	      if (dwPendingStatus == DBPENDINGSTATUS_INVALIDROW)
		dwRowStatus = DBROWSTATUS_E_DELETED;
	      // there are no pending changes or there are pending changes
	      // but the row has non-zero reference count.
	      else if (dwPendingStatus == DBPENDINGSTATUS_UNCHANGED || pRowData->GetRefRow() != 0)
		{
		  dwRefCount = pRowData->AddRefRow();
		  dwRowStatus = DBROWSTATUS_S_OK;
		}
	    }
	}

      if (rgRefCounts != NULL)
	rgRefCounts[i] = dwRefCount;
      if (rgRowStatus != NULL)
	rgRowStatus[i] = dwRowStatus;

      if (dwRowStatus == DBROWSTATUS_S_OK)
	success = true;
      else
	failure = true;
    }

  return failure ? success ? DB_S_ERRORSOCCURRED : DB_E_ERRORSOCCURRED : S_OK;
}

STDMETHODIMP
CRowset::GetData(HROW hRow, HACCESSOR hAccessor, void *pData)
{
  LOGCALL(("CRowset::GetData()\n"));

  ErrorCheck error(IID_IRowset, DISPID_IRowset_GetData);

  CriticalSection critical_section(this);
  if (zombie)
    return ErrorInfo::Set(E_UNEXPECTED);
  if (m_pRowsetPolicy->IsStreamObjectAlive())
    return ErrorInfo::Set(E_UNEXPECTED);

  AutoReleaseAccessor accessor_iter(this, hAccessor);
  if (accessor_iter == EndAccessor())
    return ErrorInfo::Set(DB_E_BADACCESSORHANDLE);
  DataAccessor& accessor = GetAccessor(accessor_iter);
  if (accessor.GetBindingCount () == 0)
    return S_OK;
  if (pData == NULL)
    return ErrorInfo::Set(E_INVALIDARG);

  RowData* pRowData = m_pRowPolicy->GetRowData(hRow);
  if (pRowData == NULL || pRowData->GetRefRow() == 0)
    return ErrorInfo::Set(DB_E_BADROWHANDLE);

  DBPENDINGSTATUS dwPendingStatus = pRowData->GetStatus();
  if (dwPendingStatus == 0)
    return ErrorInfo::Set(DB_E_BADROWHANDLE);
  if (dwPendingStatus == DBPENDINGSTATUS_INVALIDROW)
    return ErrorInfo::Set(DB_E_DELETEDROW);

  return GetData(hRow, pRowData->GetData(), accessor, (char*) pData);
}

STDMETHODIMP
CRowset::GetNextRows(
  HCHAPTER hChapter,
  DBROWOFFSET lRowsOffset,
  DBROWCOUNT cRows,
  DBCOUNTITEM *pcRowsObtained,
  HROW **prghRows
)
{
  LOGCALL(("CRowset::GetNextRows(lRowsOffset = %d, cRows = %d)\n", lRowsOffset, cRows));

  if (pcRowsObtained != NULL)
    *pcRowsObtained = 0;

  ErrorCheck error(IID_IRowset, DISPID_IRowset_GetNextRows);

  CriticalSection critical_section(this);
  if (zombie)
    return ErrorInfo::Set(E_UNEXPECTED);
  if (m_pRowsetPolicy->IsStreamObjectAlive())
    return ErrorInfo::Set(E_UNEXPECTED);

  if (prghRows == NULL || pcRowsObtained == NULL)
    return ErrorInfo::Set(E_INVALIDARG);
  if (cRows == 0)
    return S_OK;
  if (lRowsOffset < 0 && rowset_property_set->prop_CANSCROLLBACKWARDS.GetValue() == VARIANT_FALSE)
    return ErrorInfo::Set(DB_E_CANTSCROLLBACKWARDS);
  if (cRows < 0 && rowset_property_set->prop_CANFETCHBACKWARDS.GetValue() == VARIANT_FALSE)
    return ErrorInfo::Set(DB_E_CANTFETCHBACKWARDS);
  if (m_pRowPolicy->HoldsRows() && rowset_property_set->prop_CANHOLDROWS.GetValue() == VARIANT_FALSE)
    return ErrorInfo::Set(DB_E_ROWSNOTRELEASED);

  if (S_FALSE == OnRowsetChange(DBREASON_ROWSET_FETCHPOSITIONCHANGE, DBEVENTPHASE_OKTODO))
    return ErrorInfo::Set(DB_E_CANCELED);
  if (S_FALSE == OnRowsetChange(DBREASON_ROWSET_FETCHPOSITIONCHANGE, DBEVENTPHASE_ABOUTTODO))
    return ErrorInfo::Set(DB_E_CANCELED);
  if (S_FALSE == OnRowsetChange(DBREASON_ROWSET_FETCHPOSITIONCHANGE, DBEVENTPHASE_SYNCHAFTER))
    return ErrorInfo::Set(DB_E_CANCELED);

  HRESULT hr = m_pRowsetPolicy->GetNextRows(lRowsOffset, cRows);
  if (FAILED(hr))
    {
      OnRowsetChange(DBREASON_ROWSET_FETCHPOSITIONCHANGE, DBEVENTPHASE_FAILEDTODO);
      return hr;
    }
  OnRowsetChange(DBREASON_ROWSET_FETCHPOSITIONCHANGE, DBEVENTPHASE_DIDEVENT);

  DBCOUNTITEM cRowsObtained = m_pRowsetPolicy->GetRowsObtained();
  LOG(("cRowsObtained: %d\n", cRowsObtained));
  if (cRowsObtained == 0)
    return hr;

  HROW* rghRows = *prghRows;
  if (rghRows == NULL)
    {
      rghRows = (HROW*) CoTaskMemAlloc(cRowsObtained * sizeof(HROW));
      if (rghRows == NULL)
	return ErrorInfo::Set(E_OUTOFMEMORY);
    }
  m_pRowsetPolicy->GetRowHandlesObtained(rghRows);

  *pcRowsObtained = cRowsObtained;
  if (*prghRows == NULL)
    *prghRows = rghRows;

  OnRowActivate(cRowsObtained, rghRows);
  return hr;
}

STDMETHODIMP
CRowset::ReleaseRows(
  DBCOUNTITEM cRows,
  const HROW rghRows[],
  DBROWOPTIONS rgRowOptions[],
  DBREFCOUNT rgRefCounts[],
  DBROWSTATUS rgRowStatus[]
)
{
  LOGCALL(("CRowset::ReleaseRows()\n"));

  ErrorCheck error(IID_IRowset, DISPID_IRowset_ReleaseRows);

  if (cRows == 0)
    return S_OK;
  if (rghRows == NULL)
    return ErrorInfo::Set(E_INVALIDARG);

  ULONG cRowsChanged = 0;
  HROW* rghRowsChanged = NULL;
  if (rowset_property_set->prop_IConnectionPointContainer.GetValue() == VARIANT_TRUE)
    {
      rghRowsChanged = (HROW*) alloca(cRows * sizeof(HROW));
      if (rghRowsChanged == NULL)
	return ErrorInfo::Set(E_OUTOFMEMORY);
    }

  CriticalSection critical_section(this);

  bool success = false;
  bool failure = false;
  for (ULONG i = 0; i < cRows; i++)
    {
      HROW hRow = rghRows[i];
      RowData* pRowData = m_pRowPolicy->GetRowData(hRow);

      ULONG dwRefCount = 0;
      DBROWSTATUS dwRowStatus = DBROWSTATUS_E_INVALID;
      if (pRowData != NULL)
	{
	  DBPENDINGSTATUS dwPendingStatus = pRowData->GetStatus();
	  // the row was deleted or there are no pending changes
	  if (dwPendingStatus == DBPENDINGSTATUS_INVALIDROW
	      || dwPendingStatus == DBPENDINGSTATUS_UNCHANGED)
	    {
	      dwRefCount = pRowData->ReleaseRow();
	      if (dwRefCount == 0)
		m_pRowPolicy->ReleaseRowData(hRow);
	      dwRowStatus = DBROWSTATUS_S_OK;
	    }
	  // there are pending changes
	  else if (dwPendingStatus != 0 && pRowData->GetRefRow() != 0)
	    {
	      dwRefCount = pRowData->ReleaseRow();
	      dwRowStatus = DBROWSTATUS_S_PENDINGCHANGES;
	    }
	}

      if (rgRefCounts != NULL)
	rgRefCounts[i] = dwRefCount;
      if (rgRowStatus != NULL)
	rgRowStatus[i] = dwRowStatus;

      if (dwRowStatus == DBROWSTATUS_S_OK || dwRowStatus == DBROWSTATUS_S_PENDINGCHANGES)
	{
	  success = true;
	  if (dwRefCount == 0 && rghRowsChanged != NULL)
	    rghRowsChanged[cRowsChanged++] = rghRows[i];
	}
      else
	failure = true;
    }

  if (cRowsChanged > 0)
    OnRowChange(cRowsChanged, rghRowsChanged, DBREASON_ROW_RELEASE, DBEVENTPHASE_DIDEVENT);
  return failure ? success ? DB_S_ERRORSOCCURRED : DB_E_ERRORSOCCURRED : S_OK;
}

STDMETHODIMP
CRowset::RestartPosition(HCHAPTER hChapter)
{
  LOGCALL(("CRowset::RestartPosition()\n"));

  ErrorCheck error(IID_IRowset, DISPID_IRowset_RestartPosition);

  CriticalSection critical_section(this);
  if (zombie)
    return ErrorInfo::Set(E_UNEXPECTED);
  if (m_pRowsetPolicy->IsStreamObjectAlive())
    return ErrorInfo::Set(E_UNEXPECTED);

  if (S_FALSE == OnRowsetChange(DBREASON_ROWSET_FETCHPOSITIONCHANGE, DBEVENTPHASE_OKTODO))
    return ErrorInfo::Set(DB_E_CANCELED);
  if (S_FALSE == OnRowsetChange(DBREASON_ROWSET_FETCHPOSITIONCHANGE, DBEVENTPHASE_ABOUTTODO))
    return ErrorInfo::Set(DB_E_CANCELED);
  if (S_FALSE == OnRowsetChange(DBREASON_ROWSET_FETCHPOSITIONCHANGE, DBEVENTPHASE_SYNCHAFTER))
    return ErrorInfo::Set(DB_E_CANCELED);

  HRESULT hr = m_pRowsetPolicy->RestartPosition();
  if (FAILED(hr))
    {
      OnRowsetChange(DBREASON_ROWSET_FETCHPOSITIONCHANGE, DBEVENTPHASE_FAILEDTODO);
      return hr;
    }
  if (hr == DB_S_COLUMNSCHANGED)
    OnRowsetChange(DBREASON_ROWSET_CHANGED, DBEVENTPHASE_DIDEVENT);
  OnRowsetChange(DBREASON_ROWSET_FETCHPOSITIONCHANGE, DBEVENTPHASE_DIDEVENT);

  return hr;
}

/**********************************************************************/
/* IRowsetChange                                                      */

STDMETHODIMP
CRowset::DeleteRows(
  HCHAPTER hChapter,
  DBCOUNTITEM cRows,
  const HROW rghRows[],
  DBROWSTATUS rgRowStatus[]
)
{
  LOGCALL(("CRowset::DeleteRows()\n"));

  ErrorCheck error(IID_IRowsetChange, DISPID_IRowsetChange_DeleteRows);

  CriticalSection critical_section(this);
  if (zombie)
    return ErrorInfo::Set(E_UNEXPECTED);
  if (m_pRowsetPolicy->IsStreamObjectAlive())
    return ErrorInfo::Set(E_UNEXPECTED);
  if (cRows == 0)
    return S_OK;
  if (rghRows == NULL)
    return ErrorInfo::Set(E_INVALIDARG);

  ScrollablePolicy* pScrollablePolicy = dynamic_cast<ScrollablePolicy*>(m_pRowsetPolicy);
  assert(pScrollablePolicy != 0);

  bool success = false;
  bool failure = false;
  for (ULONG iRow = 0; iRow < cRows; iRow++)
    {
      HROW hRow = rghRows[iRow];
      RowData* pRowData = m_pRowPolicy->GetRowData(hRow);
      DBPENDINGSTATUS dwPendingStatus = pRowData == NULL ? 0 : pRowData->GetStatus();

      DBROWSTATUS dwRowStatus = DBROWSTATUS_S_OK;
      if (dwPendingStatus == 0)
	dwRowStatus = DBROWSTATUS_E_INVALID;
      else if (dwPendingStatus == DBPENDINGSTATUS_INVALIDROW || dwPendingStatus == DBPENDINGSTATUS_DELETED)
	dwRowStatus = DBROWSTATUS_E_DELETED;
      else if (S_FALSE == OnRowChange(1, &hRow, DBREASON_ROW_DELETE, DBEVENTPHASE_OKTODO))
	dwRowStatus = DBROWSTATUS_E_CANCELED;
      else if (S_FALSE == OnRowChange(1, &hRow, DBREASON_ROW_DELETE, DBEVENTPHASE_ABOUTTODO))
	dwRowStatus = DBROWSTATUS_E_CANCELED;
      // FIXME: It might be that the proper SYNCAFTER's place is somewhere later.
      else if (S_FALSE == OnRowChange(1, &hRow, DBREASON_ROW_INSERT, DBEVENTPHASE_SYNCHAFTER))
	dwRowStatus = DBROWSTATUS_E_CANCELED;
      else if (dwPendingStatus == DBPENDINGSTATUS_NEW)
	{
	  m_pRowPolicy->DeleteRow(pRowData);
	  FreeOriginalData(hRow);
	  FreeVisibleData(hRow);
	  OnRowChange(1, &hRow, DBREASON_ROW_INSERT, DBEVENTPHASE_DIDEVENT);
	  dwRowStatus = DBROWSTATUS_S_OK;
	}
      else if (pRowData->IsInserted() && rowset_property_set->prop_CHANGEINSERTEDROWS.GetValue() == VARIANT_FALSE)
	{
	  OnRowChange(1, &hRow, DBREASON_ROW_INSERT, DBEVENTPHASE_FAILEDTODO);
	  dwRowStatus = DBROWSTATUS_E_NEWLYINSERTED;
	}
      else if (rowset_property_set->prop_IRowsetUpdate.GetValue() == VARIANT_TRUE)
	{
	  // If the row was changed before then there is no need to save data again.
	  HRESULT hr = S_OK;
	  if (dwPendingStatus == DBPENDINGSTATUS_UNCHANGED)
	    hr = SaveOriginalData(hRow, pRowData);

	  if (FAILED(hr))
	    {
	      ErrorInfo::Clear();
	      OnRowChange(1, &hRow, DBREASON_ROW_INSERT, DBEVENTPHASE_FAILEDTODO);
	      dwRowStatus = DBROWSTATUS_E_FAIL;
	    }
	  else
	    {
	      pRowData->SetStatus(DBPENDINGSTATUS_DELETED);
	      OnRowChange(1, &hRow, DBREASON_ROW_INSERT, DBEVENTPHASE_DIDEVENT);
	      dwRowStatus = DBROWSTATUS_S_OK;
	    }
	}
      else
	{
	  HRESULT hr = pScrollablePolicy->DeleteRow(rghRows[iRow]);
	  if (FAILED(hr))
	    {
	      ErrorInfo::Clear();
	      OnRowChange(1, &hRow, DBREASON_ROW_INSERT, DBEVENTPHASE_FAILEDTODO);
	      if (hr == DB_E_CANCELED)
		dwRowStatus = DBROWSTATUS_E_CANCELED;
	      else if (hr == DB_E_INTEGRITYVIOLATION)
		dwRowStatus = DBROWSTATUS_E_INTEGRITYVIOLATION;
	      else
		dwRowStatus = DBROWSTATUS_E_FAIL;
	    }
	  else
	    {
	      m_pRowPolicy->DeleteRow(pRowData);
	      OnRowChange(1, &hRow, DBREASON_ROW_INSERT, DBEVENTPHASE_DIDEVENT);
	      if (hr == DB_S_MULTIPLECHANGES)
		dwRowStatus = DBROWSTATUS_S_MULTIPLECHANGES;
	      else
		dwRowStatus = DBROWSTATUS_S_OK;
	    }
	}

      if (rgRowStatus != NULL)
	rgRowStatus[iRow] = dwRowStatus;

      if (dwRowStatus == DBROWSTATUS_S_OK || dwRowStatus == DBROWSTATUS_S_MULTIPLECHANGES)
	success = true;
      else
	failure = true;
    }

  return failure ? success ? DB_S_ERRORSOCCURRED : DB_E_ERRORSOCCURRED : S_OK;
}

STDMETHODIMP
CRowset::InsertRow(
  HCHAPTER hChapter,
  HACCESSOR hAccessor,
  void *pData,
  HROW *phRow
)
{
  LOGCALL(("CRowset::InsertRow()\n"));

  ErrorCheck error(IID_IRowsetChange, DISPID_IRowsetChange_InsertRow);

  CriticalSection critical_section(this);
  if (zombie)
    return ErrorInfo::Set(E_UNEXPECTED);
  if (m_pRowsetPolicy->IsStreamObjectAlive())
    return ErrorInfo::Set(E_UNEXPECTED);
  if (m_pRowPolicy->HoldsRows() && rowset_property_set->prop_CANHOLDROWS.GetValue() == VARIANT_FALSE)
    return ErrorInfo::Set(DB_E_ROWSNOTRELEASED);

  AutoReleaseAccessor accessor_iter(this, hAccessor);
  if (accessor_iter == EndAccessor())
    return ErrorInfo::Set(DB_E_BADACCESSORHANDLE);

  DataAccessor& accessor = GetAccessor(accessor_iter);
  if (accessor.GetBindingCount () != 0 && pData == NULL)
    return ErrorInfo::Set(E_INVALIDARG);

  ScrollablePolicy* pScrollablePolicy = dynamic_cast<ScrollablePolicy*>(m_pRowsetPolicy);
  assert(pScrollablePolicy != 0);

  HROW hRow;
  HRESULT hr = pScrollablePolicy->CreateRow(hRow);
  if (FAILED(hr))
    return hr;

  RowData* pRowData = m_pRowPolicy->GetRowData(hRow);
  assert(pRowData != NULL);

  pRowData->AddRefRow();
  if (rowset_property_set->prop_IRowsetUpdate.GetValue() == VARIANT_FALSE)
    pRowData->SetStatus(DBPENDINGSTATUS_UNCHANGED);
  else
    pRowData->SetStatus(DBPENDINGSTATUS_NEW);

  if (S_FALSE == OnRowChange(1, &hRow, DBREASON_ROW_INSERT, DBEVENTPHASE_OKTODO))
    {
      m_pRowPolicy->ReleaseRowData(hRow);
      return ErrorInfo::Set(DB_E_CANCELED);
    }
  if (S_FALSE == OnRowChange(1, &hRow, DBREASON_ROW_INSERT, DBEVENTPHASE_ABOUTTODO))
    {
      m_pRowPolicy->ReleaseRowData(hRow);
      return ErrorInfo::Set(DB_E_CANCELED);
    }

  bool failure = false;
  for (DBCOUNTITEM iBinding = 0; iBinding < accessor.GetBindingCount (); iBinding++)
    {
      hr = m_dth.SetData(m_info, m_pRowsetPolicy->GetSetDataHandler(), hRow, 
	pRowData->GetData(), accessor, iBinding, (char*) pData, false);
      if (FAILED(hr))
	{
	  m_pRowPolicy->ReleaseRowData(hRow);
	  OnRowChange(1, &hRow, DBREASON_ROW_INSERT, DBEVENTPHASE_FAILEDTODO);
	  return hr;
	}
      if (hr == S_FALSE)
	failure = true;
      else
	{
	  const DBBINDING& binding = accessor.GetBinding (iBinding);
	  ULONG iField = m_info.OrdinalToIndex(binding.iOrdinal);
	  m_info.SetColumnStatus(pRowData->GetData(), iField, COLUMN_STATUS_CHANGED);
	}
    }
  if (failure)
    {
      m_pRowPolicy->ReleaseRowData(hRow);
      OnRowChange(1, &hRow, DBREASON_ROW_INSERT, DBEVENTPHASE_FAILEDTODO);
      return DB_E_ERRORSOCCURRED;
    }

  if (rowset_property_set->prop_IRowsetUpdate.GetValue() == VARIANT_TRUE)
    {
      hr = SaveOriginalData(hRow, NULL);
      if (FAILED(hr))
	{
	  m_pRowPolicy->ReleaseRowData(hRow);
	  OnRowChange(1, &hRow, DBREASON_ROW_INSERT, DBEVENTPHASE_FAILEDTODO);
	  return hr;
	}
    }

  if (S_FALSE == OnRowChange(1, &hRow, DBREASON_ROW_INSERT, DBEVENTPHASE_SYNCHAFTER))
    {
      if (rowset_property_set->prop_IRowsetUpdate.GetValue() == VARIANT_TRUE)
	FreeOriginalData(hRow);
      m_pRowPolicy->ReleaseRowData(hRow);
      return ErrorInfo::Set(DB_E_CANCELED);
    }

  if (rowset_property_set->prop_IRowsetUpdate.GetValue() == VARIANT_FALSE)
    {
      hr = pScrollablePolicy->InsertRow(hRow);
      if (FAILED(hr))
	{
	  if (rowset_property_set->prop_IRowsetUpdate.GetValue() == VARIANT_TRUE)
	    FreeOriginalData(hRow);
	  m_pRowPolicy->ReleaseRowData(hRow);
	  OnRowChange(1, &hRow, DBREASON_ROW_INSERT, DBEVENTPHASE_FAILEDTODO);
	  return hr;
	}
      if (hr == S_FALSE)
	{
	  hr = m_dth.SetDataAtExec(m_info, m_pRowsetPolicy->GetSetDataHandler(),
				   accessor, (char*) pData, false);
	  if (FAILED(hr))
	    {
	      if (rowset_property_set->prop_IRowsetUpdate.GetValue() == VARIANT_TRUE)
		FreeOriginalData(hRow);
	      m_pRowPolicy->ReleaseRowData(hRow);
	      OnRowChange(1, &hRow, DBREASON_ROW_INSERT, DBEVENTPHASE_FAILEDTODO);
	      return hr;
	    }
	}
      pRowData->SetInserted();
    }
  OnRowChange(1, &hRow, DBREASON_ROW_INSERT, DBEVENTPHASE_DIDEVENT);

  if (phRow != NULL)
    {
      *phRow = hRow;
    }
  else
    {
      ULONG dwRefCount = pRowData->ReleaseRow();
      assert(dwRefCount == 0);

      if (rowset_property_set->prop_IRowsetUpdate.GetValue() == VARIANT_FALSE)
	m_pRowPolicy->ReleaseRowData(hRow);
    }

  return S_OK;
}

STDMETHODIMP
CRowset::SetData(HROW hRow, HACCESSOR hAccessor, void *pData)
{
  LOGCALL(("CRowset::SetData()\n"));

  ErrorCheck error(IID_IRowsetChange, DISPID_IRowsetChange_SetData);

  CriticalSection critical_section(this);
  if (zombie)
    return ErrorInfo::Set(E_UNEXPECTED);
  if (m_pRowsetPolicy->IsStreamObjectAlive())
    return ErrorInfo::Set(E_UNEXPECTED);

  AutoReleaseAccessor accessor_iter(this, hAccessor);
  if (accessor_iter == EndAccessor())
    return ErrorInfo::Set(DB_E_BADACCESSORHANDLE);

  DataAccessor& accessor = GetAccessor(accessor_iter);
  if (accessor.GetBindingCount () == 0)
    return S_OK;
  if (pData == NULL)
    return ErrorInfo::Set(E_INVALIDARG);

  RowData* pRowData = m_pRowPolicy->GetRowData(hRow);
  if (pRowData == NULL)
    return ErrorInfo::Set(DB_E_BADROWHANDLE);

  DBPENDINGSTATUS dwPendingStatus = pRowData->GetStatus();
  if (dwPendingStatus == 0)
    return ErrorInfo::Set(DB_E_BADROWHANDLE);
  if (dwPendingStatus == DBPENDINGSTATUS_INVALIDROW || dwPendingStatus == DBPENDINGSTATUS_DELETED)
    return ErrorInfo::Set(DB_E_DELETEDROW);
  if (pRowData->IsInserted() && rowset_property_set->prop_CHANGEINSERTEDROWS.GetValue() == VARIANT_FALSE)
    return ErrorInfo::Set(DB_E_NEWLYINSERTED);

  bool fFirstChange = false;
  bool fOriginalData = false;
  char* pbOriginalData = NULL;
  if (rowset_property_set->prop_IRowsetUpdate.GetValue() == VARIANT_TRUE)
    {
      if (dwPendingStatus == DBPENDINGSTATUS_UNCHANGED || dwPendingStatus == DBPENDINGSTATUS_NEW)
	{
	  fFirstChange = true;

	  if (S_FALSE == OnRowChange(1, &hRow, DBREASON_ROW_FIRSTCHANGE, DBEVENTPHASE_OKTODO))
	    return ErrorInfo::Set(DB_E_CANCELED);
	  if (S_FALSE == OnRowChange(1, &hRow, DBREASON_ROW_FIRSTCHANGE, DBEVENTPHASE_ABOUTTODO))
	    return ErrorInfo::Set(DB_E_CANCELED);

	  if (dwPendingStatus == DBPENDINGSTATUS_UNCHANGED)
	    {
	      fOriginalData = true;

	      HRESULT hr = SaveOriginalData(hRow, pRowData);
	      if (FAILED(hr))
		{
		  OnRowChange(1, &hRow, DBREASON_ROW_FIRSTCHANGE, DBEVENTPHASE_FAILEDTODO);
		  return hr;
		}

	      std::map<HROW, char*>::iterator iter = m_mpOriginalData.find(hRow);
	      pbOriginalData = iter->second;
	    }
	}
    }

  AutoRelease<char, DeleteArray <char> > pbAutoOriginalData;
  if (!fOriginalData)
    {
      pbAutoOriginalData.Set(new char[m_info.GetRecordSize()]);
      if (pbAutoOriginalData == NULL)
	{
	  if (fFirstChange)
	    OnRowChange(1, &hRow, DBREASON_ROW_FIRSTCHANGE, DBEVENTPHASE_FAILEDTODO);
	  return ErrorInfo::Set(E_OUTOFMEMORY);
	}

      pbOriginalData = pbAutoOriginalData.Get();
      memcpy(pbOriginalData, pRowData->GetData(), m_info.GetRecordSize());
    }

  HRESULT hr;
  DBORDINAL cColumns = 0;
  DBORDINAL* rgColumns = NULL;

  // TODO: Check for DBSTATUS_S_IGNORE.
  if (rowset_property_set->prop_IConnectionPointContainer.GetValue() == VARIANT_TRUE)
    {
      rgColumns = (DBORDINAL*) alloca(m_info.GetFieldCount() * sizeof(DBORDINAL));
      if (rgColumns == NULL)
	{
	  if (fOriginalData)
	    FreeOriginalData(hRow);
	  if (fFirstChange)
	    OnRowChange(1, &hRow, DBREASON_ROW_FIRSTCHANGE, DBEVENTPHASE_FAILEDTODO);
	  return ErrorInfo::Set(E_OUTOFMEMORY);
	}

      ULONG iField;
      for (iField = 0; iField < m_info.GetFieldCount(); iField++)
	rgColumns[iField] = 0;
      for (DBCOUNTITEM iBinding = 0; iBinding < accessor.GetBindingCount (); iBinding++)
	{
	  iField = m_info.OrdinalToIndex(accessor.GetBinding(iBinding).iOrdinal);
	  if (iField < m_info.GetFieldCount())
	    rgColumns[iField] = 1;
	}
      for (iField = 0; iField < m_info.GetFieldCount(); iField++)
	{
	  if (rgColumns[iField])
	    rgColumns[cColumns++] = m_info.IndexToOrdinal(iField);
	}

      if (S_FALSE == OnFieldChange(hRow, cColumns, rgColumns, DBREASON_COLUMN_SET, DBEVENTPHASE_OKTODO))
	{
	  if (fOriginalData)
	    FreeOriginalData(hRow);
	  if (fFirstChange)
	    OnRowChange(1, &hRow, DBREASON_ROW_FIRSTCHANGE, DBEVENTPHASE_FAILEDTODO);
	  return ErrorInfo::Set(DB_E_CANCELED);
	}
      if (S_FALSE == OnFieldChange(hRow, cColumns, rgColumns, DBREASON_COLUMN_SET, DBEVENTPHASE_ABOUTTODO))
	{
	  if (fOriginalData)
	    FreeOriginalData(hRow);
	  if (fFirstChange)
	    OnRowChange(1, &hRow, DBREASON_ROW_FIRSTCHANGE, DBEVENTPHASE_FAILEDTODO);
	  return ErrorInfo::Set(DB_E_CANCELED);
	}
    }

  ScrollablePolicy* pScrollablePolicy = dynamic_cast<ScrollablePolicy*>(m_pRowsetPolicy);
  assert(pScrollablePolicy != 0);

  bool failure = false;
  for (DBCOUNTITEM iBinding = 0; iBinding < accessor.GetBindingCount (); iBinding++)
    {
      hr = m_dth.SetData(m_info, m_pRowsetPolicy->GetSetDataHandler(), hRow, 
	pRowData->GetData(), accessor, iBinding, (char*) pData, false);
      if (FAILED(hr))
	{
	  memcpy(pRowData->GetData(), pbOriginalData, m_info.GetRecordSize());
	  if (fOriginalData)
	    FreeOriginalData(hRow);
	  OnFieldChange(hRow, cColumns, rgColumns, DBREASON_COLUMN_SET, DBEVENTPHASE_FAILEDTODO);
	  if (fFirstChange)
	    OnRowChange(1, &hRow, DBREASON_ROW_FIRSTCHANGE, DBEVENTPHASE_FAILEDTODO);
	  return hr;
	}
      if (hr == S_FALSE)
	failure = true;
      else
	{
	  const DBBINDING& binding = accessor.GetBinding (iBinding);
	  ULONG iField = m_info.OrdinalToIndex(binding.iOrdinal);
	  m_info.SetColumnStatus(pRowData->GetData(), iField, COLUMN_STATUS_CHANGED);
	}
    }
  if (failure)
    {
      memcpy(pRowData->GetData(), pbOriginalData, m_info.GetRecordSize());
      if (fOriginalData)
	FreeOriginalData(hRow);
      OnFieldChange(hRow, cColumns, rgColumns, DBREASON_COLUMN_SET, DBEVENTPHASE_FAILEDTODO);
      if (fFirstChange)
	OnRowChange(1, &hRow, DBREASON_ROW_FIRSTCHANGE, DBEVENTPHASE_FAILEDTODO);
      return DB_E_ERRORSOCCURRED;
    }

  if (S_FALSE == OnFieldChange(hRow, cColumns, rgColumns, DBREASON_COLUMN_SET, DBEVENTPHASE_SYNCHAFTER))
    {
      memcpy(pRowData->GetData(), pbOriginalData, m_info.GetRecordSize());
      if (fOriginalData)
	FreeOriginalData(hRow);
      if (fFirstChange)
	OnRowChange(1, &hRow, DBREASON_ROW_FIRSTCHANGE, DBEVENTPHASE_FAILEDTODO);
      return ErrorInfo::Set(DB_E_CANCELED);
    }
  if (fFirstChange)
    {
      if (S_FALSE == OnRowChange(1, &hRow, DBREASON_ROW_FIRSTCHANGE, DBEVENTPHASE_SYNCHAFTER))
	{
	  memcpy(pRowData->GetData(), pbOriginalData, m_info.GetRecordSize());
	  if (fOriginalData)
	    FreeOriginalData(hRow);
	  OnFieldChange(hRow, cColumns, rgColumns, DBREASON_COLUMN_SET, DBEVENTPHASE_FAILEDTODO);
	  return ErrorInfo::Set(DB_E_CANCELED);
	}
    }

  hr = S_OK;
  if (rowset_property_set->prop_IRowsetUpdate.GetValue() != VARIANT_TRUE)
    {
      hr = pScrollablePolicy->UpdateRow(hRow, false);
      if (hr == S_FALSE)
	hr = m_dth.SetDataAtExec(m_info, m_pRowsetPolicy->GetSetDataHandler(),
				 accessor, (char*) pData, false);
    }
#if 0
  // TODO: check for immediate long data
  else if (...)
    {
    }
#endif

  // TODO: check for each field status and call OnFieldChange accordingly.
  if (FAILED(hr))
    {
      memcpy(pRowData->GetData(), pbOriginalData, m_info.GetRecordSize());
      if (fOriginalData)
	FreeOriginalData(hRow);
      OnFieldChange(hRow, cColumns, rgColumns, DBREASON_COLUMN_SET, DBEVENTPHASE_FAILEDTODO);
      if (fFirstChange)
	OnRowChange(1, &hRow, DBREASON_ROW_FIRSTCHANGE, DBEVENTPHASE_FAILEDTODO);
    }
  else
    {
      OnFieldChange(hRow, cColumns, rgColumns, DBREASON_COLUMN_SET, DBEVENTPHASE_DIDEVENT);
      if (fFirstChange)
	OnRowChange(1, &hRow, DBREASON_ROW_FIRSTCHANGE, DBEVENTPHASE_DIDEVENT);
      if (dwPendingStatus == DBPENDINGSTATUS_UNCHANGED)
	pRowData->SetStatus(DBPENDINGSTATUS_CHANGED);
    }
  return hr;
}

/**********************************************************************/
/* IRowsetFind                                                        */

STDMETHODIMP
CRowset::FindNextRow(
  HCHAPTER hChapter,
  HACCESSOR hAccessor,
  void* pFindValue,
  DBCOMPAREOP CompareOp,
  DBBKMARK cbBookmark,
  const BYTE* pBookmark,
  DBROWOFFSET lRowsOffset,
  DBROWCOUNT cRows,
  DBCOUNTITEM* pcRowsObtained,
  HROW** prghRows
)
{
  return E_FAIL;
}

/**********************************************************************/
/* IRowsetIdentity                                                    */

STDMETHODIMP
CRowset::IsSameRow(
  HROW hThisRow,
  HROW hThatRow
)
{
  LOGCALL(("CRowset::IsSameRow()\n"));

  ErrorCheck error(IID_IRowsetIdentity, DISPID_IRowsetIdentity_IsSameRow);

  CriticalSection critical_section(this);
  if (zombie)
    return ErrorInfo::Set(E_UNEXPECTED);

  RowData* pThisData = m_pRowPolicy->GetRowData(hThisRow);
  if (pThisData == NULL || pThisData->GetRefRow() == 0)
    return ErrorInfo::Set(DB_E_BADROWHANDLE);
  DBPENDINGSTATUS dwThisStatus = pThisData->GetStatus();
  if (dwThisStatus == 0)
    return ErrorInfo::Set(DB_E_BADROWHANDLE);

  RowData* pThatData = m_pRowPolicy->GetRowData(hThatRow);
  if (pThatData == NULL || pThatData->GetRefRow() == 0)
    return ErrorInfo::Set(DB_E_BADROWHANDLE);
  DBPENDINGSTATUS dwThatStatus = pThatData->GetStatus();
  if (dwThatStatus == 0)
    return ErrorInfo::Set(DB_E_BADROWHANDLE);

  if (dwThisStatus == DBPENDINGSTATUS_INVALIDROW || dwThatStatus == DBPENDINGSTATUS_INVALIDROW)
    return ErrorInfo::Set(DB_E_DELETEDROW);
  if (pThisData->IsInserted() || pThatData->IsInserted())
    {
      if (rowset_property_set->prop_STRONGIDENTITY.GetValue() == VARIANT_FALSE)
	return ErrorInfo::Set(DB_E_NEWLYINSERTED);
    }

  return hThisRow == hThatRow ? S_OK : S_FALSE;
}

/**********************************************************************/
/* IRowsetInfo                                                        */

STDMETHODIMP
CRowset::GetProperties(
  const ULONG cPropertyIDSets,
  const DBPROPIDSET rgPropertyIDSets[],
  ULONG *pcPropertySets,
  DBPROPSET **prgPropertySets
)
{
  LOGCALL(("CRowset::GetProperties()\n"));

  ErrorCheck error(IID_IRowsetInfo, DISPID_IRowsetInfo_GetProperties);

  CriticalSection critical_section(this);
  if (zombie)
    return ErrorInfo::Set(E_UNEXPECTED);

  return PropertySuperset::GetProperties(cPropertyIDSets, rgPropertyIDSets, pcPropertySets, prgPropertySets);
}

STDMETHODIMP
CRowset::GetReferencedRowset(
  DBORDINAL iOrdinal,
  REFIID riid,
  IUnknown **ppReferencedRowset
)
{
  LOGCALL(("CRowset::GetReferencedRowset()\n"));

  ErrorCheck error(IID_IRowsetInfo, DISPID_IRowsetInfo_GetReferencedRowset);

  if (ppReferencedRowset == NULL)
    return ErrorInfo::Set(E_INVALIDARG);
  *ppReferencedRowset = NULL;

  CriticalSection critical_section(this);
  if (zombie)
    return ErrorInfo::Set(E_UNEXPECTED);

  if (m_info.OrdinalToIndex(iOrdinal) >= m_info.GetFieldCount())
    return DBBINDSTATUS_BADORDINAL;
  if (iOrdinal != 0)
    return ErrorInfo::Set(DB_E_NOTAREFERENCECOLUMN);

  return GetControllingUnknown()->QueryInterface(riid, (void **) ppReferencedRowset);
}

STDMETHODIMP
CRowset::GetSpecification(
  REFIID riid,
  IUnknown **ppSpecification
)
{
  LOGCALL(("CRowset::GetSpecification()\n"));

  ErrorCheck error(IID_IRowsetInfo, DISPID_IRowsetInfo_GetSpecification);

  if (ppSpecification == NULL)
    return ErrorInfo::Set(E_INVALIDARG);
  *ppSpecification = NULL;

  if (zombie)
    return ErrorInfo::Set(E_UNEXPECTED);
  if (m_pUnkSpec == NULL)
    return S_FALSE;

  return m_pUnkSpec->QueryInterface(riid, (void **) ppSpecification);
}

/**********************************************************************/
/* IRowsetLocate                                                      */

STDMETHODIMP
CRowset::Compare(
  HCHAPTER hChapter,
  DBBKMARK cbBookmark1,
  const BYTE *pBookmark1,
  DBBKMARK cbBookmark2,
  const BYTE *pBookmark2,
  DBCOMPARE *pComparison
)
{
  LOGCALL(("CRowset::Compare()\n"));

  ErrorCheck error(IID_IRowsetLocate, DISPID_IRowsetLocate_Compare);

  CriticalSection critical_section(this);
  if (zombie)
    return ErrorInfo::Set(E_UNEXPECTED);

  if (cbBookmark1 == 0 || cbBookmark2 == 0)
    return ErrorInfo::Set(E_INVALIDARG);
  if (pBookmark1 == NULL || pBookmark2 == NULL || pComparison == NULL)
    return ErrorInfo::Set(E_INVALIDARG);

  bool fStandardBookmark1;
  ULONG ulBookmark1;
  if (cbBookmark1 == 1)
    {
      if (*pBookmark1 != DBBMK_FIRST && *pBookmark1 != DBBMK_LAST)
	return ErrorInfo::Set(DB_E_BADBOOKMARK);
      fStandardBookmark1 = true;
      ulBookmark1 = *pBookmark1;
    }
  else
    {
      if (cbBookmark1 != sizeof(ULONG))
	return ErrorInfo::Set(DB_E_BADBOOKMARK);
      fStandardBookmark1 = false;
      ulBookmark1 = *(ULONG*) pBookmark1;
    }

  bool fStandardBookmark2;
  ULONG ulBookmark2;
  if (cbBookmark2 == 1)
    {
      if (*pBookmark2 != DBBMK_FIRST && *pBookmark2 != DBBMK_LAST)
	return ErrorInfo::Set(DB_E_BADBOOKMARK);
      fStandardBookmark2 = true;
      ulBookmark2 = *pBookmark2;
    }
  else
    {
      if (cbBookmark2 != sizeof(ULONG))
	return ErrorInfo::Set(DB_E_BADBOOKMARK);
      fStandardBookmark2 = false;
      ulBookmark2 = *(ULONG*) pBookmark2;
    }

  if (fStandardBookmark1 || fStandardBookmark2)
    {
      *pComparison = (fStandardBookmark1 && fStandardBookmark2
		      && ulBookmark1 == ulBookmark2 ? DBCOMPARE_EQ : DBCOMPARE_NE);
      return S_OK;
    }

  if (rowset_property_set->prop_ORDEREDBOOKMARKS.GetValue() == VARIANT_TRUE)
    {
      PositionalPolicy* pPositionalPolicy = dynamic_cast<PositionalPolicy*>(m_pRowsetPolicy);
      assert(pPositionalPolicy != NULL);

      DBCOUNTITEM ulPosition1 = pPositionalPolicy->GetPosition(false, ulBookmark1);
      DBCOUNTITEM ulPosition2 = pPositionalPolicy->GetPosition(false, ulBookmark2);
      if (ulPosition1 == 0 || ulPosition2 == 0)
	return DB_E_BADBOOKMARK;

      *pComparison = (ulPosition1 == ulPosition2 ? DBCOMPARE_EQ
		      : ulPosition1 < ulPosition2 ? DBCOMPARE_LT : DBCOMPARE_GT);
    }
  else
    {
      *pComparison = ulBookmark1 == ulBookmark2 ? DBCOMPARE_EQ : DBCOMPARE_NE;
    }

  return S_OK;
}

STDMETHODIMP
CRowset::GetRowsAt(
  HWATCHREGION hReserved,
  HCHAPTER hChapter,
  DBBKMARK cbBookmark,
  const BYTE *pBookmark,
  DBROWOFFSET lRowsOffset,
  DBROWCOUNT cRows,
  DBCOUNTITEM *pcRowsObtained,
  HROW **prghRows
)
{
  LOGCALL(("CRowset::GetRowsAt(lRowsOffset = %d, cRows = %d)\n", lRowsOffset, cRows));

  if (pcRowsObtained != NULL)
    *pcRowsObtained = 0;

  ErrorCheck error(IID_IRowsetLocate, DISPID_IRowsetLocate_GetRowsAt);

  CriticalSection critical_section(this);
  if (zombie)
    return ErrorInfo::Set(E_UNEXPECTED);
  if (m_pRowsetPolicy->IsStreamObjectAlive())
    return ErrorInfo::Set(E_UNEXPECTED);

  if (prghRows == NULL || pcRowsObtained == NULL)
    return ErrorInfo::Set(E_INVALIDARG);
  if (cbBookmark == 0)
    return ErrorInfo::Set(E_INVALIDARG);
  if (pBookmark == NULL)
    return ErrorInfo::Set(E_INVALIDARG);
  if (cRows == 0)
    return S_OK;
  if (lRowsOffset < 0 && rowset_property_set->prop_CANSCROLLBACKWARDS.GetValue() == VARIANT_FALSE)
    return ErrorInfo::Set(DB_E_CANTSCROLLBACKWARDS);
  if (cRows < 0 && rowset_property_set->prop_CANFETCHBACKWARDS.GetValue() == VARIANT_FALSE)
    return ErrorInfo::Set(DB_E_CANTFETCHBACKWARDS);
  if (m_pRowPolicy->HoldsRows() && rowset_property_set->prop_CANHOLDROWS.GetValue() == VARIANT_FALSE)
    return ErrorInfo::Set(DB_E_ROWSNOTRELEASED);

  bool fStandardBookmark;
  ULONG ulBookmark;
  if (cbBookmark == 1)
    {
      if (*pBookmark != DBBMK_FIRST && *pBookmark != DBBMK_LAST)
	return ErrorInfo::Set(DB_E_BADBOOKMARK);
      fStandardBookmark = true;
      ulBookmark = *pBookmark;
    }
  else
    {
      if (cbBookmark != sizeof(ULONG))
	return ErrorInfo::Set(DB_E_BADBOOKMARK);
      fStandardBookmark = false;
      ulBookmark = *(ULONG*) pBookmark;
    }

  PositionalPolicy* pPositionalPolicy = dynamic_cast<PositionalPolicy*>(m_pRowsetPolicy);
  assert(pPositionalPolicy != 0);

  HRESULT hr = pPositionalPolicy->GetRowsAtPosition(fStandardBookmark, ulBookmark, lRowsOffset, cRows);
  if (FAILED(hr))
    return hr;

  DBCOUNTITEM cRowsObtained = pPositionalPolicy->GetRowsObtained();
  if (cRowsObtained == 0)
    return hr;

  HROW* rghRows = *prghRows;
  if (rghRows == NULL)
    {
      rghRows = (HROW*) CoTaskMemAlloc(cRowsObtained * sizeof(HROW));
      if (rghRows == NULL)
	return ErrorInfo::Set(E_OUTOFMEMORY);
    }
  m_pRowsetPolicy->GetRowHandlesObtained(rghRows);

  *pcRowsObtained = cRowsObtained;
  if (*prghRows == NULL)
    *prghRows = rghRows;

  OnRowActivate(cRowsObtained, rghRows);
  return hr;
}

STDMETHODIMP
CRowset::GetRowsByBookmark(
  HCHAPTER hChapter,
  DBCOUNTITEM cRows,
  const DBBKMARK rgcbBookmarks[],
  const BYTE *rgpBookmarks[],
  HROW rghRows[],
  DBROWSTATUS rgRowStatus[]
)
{
  LOGCALL(("CRowset::GetRowsByBookmark(cRows = %d)\n", cRows));

  ErrorCheck error(IID_IRowsetLocate, DISPID_IRowsetLocate_GetRowsByBookmark);

  CriticalSection critical_section(this);
  if (zombie)
    return ErrorInfo::Set(E_UNEXPECTED);
  if (m_pRowsetPolicy->IsStreamObjectAlive())
    return ErrorInfo::Set(E_UNEXPECTED);

  if (cRows == 0)
    return S_OK;
  if (rghRows == NULL || rgcbBookmarks == NULL || rgpBookmarks == NULL)
    return ErrorInfo::Set(E_INVALIDARG);
  if (m_pRowPolicy->HoldsRows() && rowset_property_set->prop_CANHOLDROWS.GetValue() == VARIANT_FALSE)
    return ErrorInfo::Set(DB_E_ROWSNOTRELEASED);

  PositionalPolicy* pPositionalPolicy = dynamic_cast<PositionalPolicy*>(m_pRowsetPolicy);
  assert(pPositionalPolicy != 0);

  bool success = false;
  bool failure = false;

  // TODO: Change this to retrieve muiltiple rows at once whenever
  // SQLBulkOperations(..., SQL_FETCH_BY_BOOKMARK) is implemented.
  for (ULONG iRow = 0; iRow < cRows; iRow++)
    {
      DBBKMARK cbBookmark = rgcbBookmarks[iRow];
      const BYTE* pBookmark = rgpBookmarks[iRow];

      DBROWSTATUS dwStatus = DBROWSTATUS_S_OK;
      if (cbBookmark != sizeof(ULONG) || pBookmark == NULL)
	{
	  dwStatus = DBROWSTATUS_E_INVALID;
	}
      else
	{
	  ULONG ulBookmark = *(ULONG*) pBookmark;
	  HRESULT hr = pPositionalPolicy->GetRowByBookmark(ulBookmark);
	  if (FAILED(hr))
	    {
	      rghRows[iRow] = DB_NULL_HROW;
	      if (hr == DB_E_BADBOOKMARK)
		dwStatus = DBROWSTATUS_E_INVALID;
	      if (hr == E_OUTOFMEMORY)
		dwStatus = DBROWSTATUS_E_OUTOFMEMORY;
	      else
		dwStatus = DBROWSTATUS_E_FAIL;

	      // Clear the error because currently only single error object
	      // is allowed at the same time and this method could be called
	      // multiple times therefore multiple errors could occur.
	      ErrorInfo::Clear();
	    }
	  else
	    {
	      pPositionalPolicy->GetRowHandlesObtained(&rghRows[iRow]);
	      dwStatus = DBROWSTATUS_S_OK;
	    }
	}

      if (rgRowStatus != NULL)
	rgRowStatus[iRow] = dwStatus;

      if (dwStatus == DBROWSTATUS_S_OK)
	success = true;
      else
	failure = true;
    }

  OnRowActivate(cRows, rghRows);
  return failure ? success ? DB_S_ERRORSOCCURRED : DB_E_ERRORSOCCURRED : S_OK;
}

STDMETHODIMP
CRowset::Hash(
  HCHAPTER hChapter,
  DBBKMARK cBookmarks,
  const DBBKMARK rgcbBookmarks[],
  const BYTE *rgpBookmarks[],
  DBHASHVALUE rgHashedValues[],
  DBROWSTATUS rgBookmarkStatus[]
)
{
  LOGCALL(("CRowset::Hash()\n"));

  if (cBookmarks == 0)
    return S_OK;

  ErrorCheck error(IID_IRowsetLocate, DISPID_IRowsetLocate_Hash);

  CriticalSection critical_section(this);
  if (zombie)
    return ErrorInfo::Set(E_UNEXPECTED);
  if (m_pRowsetPolicy->IsStreamObjectAlive())
    return ErrorInfo::Set(E_UNEXPECTED);
  if (rgcbBookmarks == NULL || rgpBookmarks == NULL || rgHashedValues == NULL)
    return ErrorInfo::Set(E_INVALIDARG);

  bool success = false;
  bool failure = false;

  for (ULONG i = 0; i < cBookmarks; i++)
    {
      DBROWSTATUS status;
      if (rgcbBookmarks[i] != sizeof(ULONG) || rgpBookmarks[i] == NULL)
	{
	  rgHashedValues[i] = 0;
	  status = DBROWSTATUS_E_INVALID;
	}
      else
	{
	  rgHashedValues[i] = (*(ULONG *) rgpBookmarks[i]);
	  status = DBROWSTATUS_S_OK;
	}

      if (status == DBROWSTATUS_S_OK)
	success = true;
      else
	failure = true;

      if (rgBookmarkStatus != NULL)
	rgBookmarkStatus[i] = status;
    }

  return failure ? success ? DB_S_ERRORSOCCURRED : DB_E_ERRORSOCCURRED : S_OK;
}

/**********************************************************************/
/* IRowsetRefresh                                                     */

STDMETHODIMP
CRowset::GetLastVisibleData(
  HROW hRow,
  HACCESSOR hAccessor,
  void* pData
)
{
  LOGCALL(("CRowset::GetLastVisibleData()\n"));

  ErrorCheck error(IID_IRowset, DISPID_IRowsetRefresh_GetLastVisibleData);

  CriticalSection critical_section(this);
  if (zombie)
    return ErrorInfo::Set(E_UNEXPECTED);
  if (m_pRowsetPolicy->IsStreamObjectAlive())
    return ErrorInfo::Set(E_UNEXPECTED);

  AutoReleaseAccessor accessor_iter(this, hAccessor);
  if (accessor_iter == EndAccessor())
    return ErrorInfo::Set(DB_E_BADACCESSORHANDLE);
  DataAccessor& accessor = GetAccessor(accessor_iter);
  if (accessor.GetBindingCount () == 0)
    return S_OK;
  if (pData == NULL)
    return ErrorInfo::Set(E_INVALIDARG);

  RowData* pRowData = m_pRowPolicy->GetRowData(hRow);
  if (pRowData == NULL || pRowData->GetRefRow() == 0)
    return ErrorInfo::Set(DB_E_BADROWHANDLE);

  DBPENDINGSTATUS dwPendingStatus = pRowData->GetStatus();
  if (dwPendingStatus == 0)
    return ErrorInfo::Set(DB_E_BADROWHANDLE);
  if (dwPendingStatus == DBPENDINGSTATUS_INVALIDROW)
    return ErrorInfo::Set(DB_E_DELETEDROW);
  if (dwPendingStatus == DBPENDINGSTATUS_NEW)
    return ErrorInfo::Set(DB_E_PENDINGINSERT);
  if (pRowData->IsInserted() && rowset_property_set->prop_STRONGIDENTITY.GetValue() == VARIANT_FALSE)
    return ErrorInfo::Set(DB_E_NEWLYINSERTED);

  char* pbVisibleData = NULL;
  if (dwPendingStatus == DBPENDINGSTATUS_UNCHANGED)
    {
      assert(m_mpVisibleData.find(hRow) == m_mpVisibleData.end());
      pbVisibleData = pRowData->GetData();
    }
  else
    {
      std::map<HROW, char*>::iterator iter = m_mpVisibleData.find(hRow);
      if (iter == m_mpVisibleData.end())
	{
	  iter = m_mpOriginalData.find(hRow);
	  assert(iter != m_mpOriginalData.end());
	}
      pbVisibleData = iter->second;
    }
  assert(pbVisibleData != NULL);

  return GetData(hRow, pbVisibleData, accessor, (char*) pData);
}

STDMETHODIMP
CRowset::RefreshVisibleData(
  HCHAPTER hChapter,
  DBCOUNTITEM cRows,
  const HROW rghRows[],
  BOOL fOverwrite,
  DBCOUNTITEM* pcRowsRefreshed,
  HROW** prghRowsRefreshed,
  DBROWSTATUS** prgRowStatus
)
{
  LOGCALL(("CRowset::RefreshVisibleData()\n"));

  if (pcRowsRefreshed != NULL)
    {
      *pcRowsRefreshed = 0;
      if (prghRowsRefreshed != NULL)
	*prghRowsRefreshed = NULL;
      if (prgRowStatus != NULL)
	*prgRowStatus = NULL;
    }

  ErrorCheck error(IID_IRowset, DISPID_IRowsetRefresh_RefreshVisibleData);

  CriticalSection critical_section(this);
  if (zombie)
    return ErrorInfo::Set(E_UNEXPECTED);
  if (m_pRowsetPolicy->IsStreamObjectAlive())
    return ErrorInfo::Set(E_UNEXPECTED);
  if (cRows != 0 && rghRows == NULL)
    return ErrorInfo::Set(E_UNEXPECTED);
  if (pcRowsRefreshed != NULL && prghRowsRefreshed == NULL)
    return ErrorInfo::Set(E_UNEXPECTED);

  DBCOUNTITEM cRowsRefreshed = cRows;
  if (cRowsRefreshed == 0)
    {
      cRowsRefreshed = m_pRowPolicy->GetActiveRows();
      if (cRowsRefreshed == 0)
	return S_OK;
    }

  AutoRelease<HROW, ComMemFree> rghRowsRefreshed;
  if (cRows == 0 || pcRowsRefreshed != NULL)
    {
      rghRowsRefreshed.Set((HROW*) CoTaskMemAlloc(cRowsRefreshed * sizeof(HROW)));
      if (rghRowsRefreshed == NULL)
	return ErrorInfo::Set(E_OUTOFMEMORY);
      if (cRows == 0)
	m_pRowPolicy->GetActiveRowHandles(rghRowsRefreshed.Get());
    }

  AutoRelease<DBROWSTATUS, ComMemFree> rgRowStatus;
  if (pcRowsRefreshed != NULL && prgRowStatus != NULL)
    {
      rgRowStatus.Set((DBROWSTATUS*) CoTaskMemAlloc(cRowsRefreshed * sizeof(DBROWSTATUS)));
      if (rgRowStatus == NULL)
	return ErrorInfo::Set(E_OUTOFMEMORY);
    }

  ScrollablePolicy* pScrollablePolicy = dynamic_cast<ScrollablePolicy*>(m_pRowsetPolicy);
  assert(pScrollablePolicy != 0);

  bool failure = false;
  bool success = false;

  for (DBCOUNTITEM iRow = 0; iRow < cRowsRefreshed; iRow++)
    {
      HROW hRow;
      if (cRows == 0)
	{
	  hRow = rghRowsRefreshed[iRow];
	}
      else
	{
	  hRow = rghRows[iRow];
	  if (pcRowsRefreshed != NULL)
	    rghRowsRefreshed[iRow] = hRow;
	}

      RowData* pRowData = m_pRowPolicy->GetRowData(hRow);
      DBPENDINGSTATUS dwPendingStatus = pRowData == NULL ? 0 : pRowData->GetStatus();

      DBROWSTATUS dwRowStatus;
      if (dwPendingStatus == 0)
	dwRowStatus = DBROWSTATUS_E_INVALID;
      else if (dwPendingStatus == DBPENDINGSTATUS_INVALIDROW)
	dwRowStatus = DBROWSTATUS_E_DELETED;
      else if (dwPendingStatus == DBPENDINGSTATUS_NEW)
	dwRowStatus = DBROWSTATUS_E_PENDINGINSERT;
      else if (pRowData->IsInserted() && rowset_property_set->prop_STRONGIDENTITY.GetValue() == VARIANT_FALSE)
	dwRowStatus = DBROWSTATUS_E_NEWLYINSERTED;
      else if (S_FALSE == OnRowChange(1, &hRow, DBREASON_ROW_RESYNCH, DBEVENTPHASE_OKTODO))
	dwRowStatus = DBROWSTATUS_E_CANCELED;
      else if (S_FALSE == OnRowChange(1, &hRow, DBREASON_ROW_RESYNCH, DBEVENTPHASE_ABOUTTODO))
	dwRowStatus = DBROWSTATUS_E_CANCELED;
      else if (S_FALSE == OnRowChange(1, &hRow, DBREASON_ROW_RESYNCH, DBEVENTPHASE_SYNCHAFTER))
	dwRowStatus = DBROWSTATUS_E_CANCELED;
      else if (dwPendingStatus == DBPENDINGSTATUS_UNCHANGED)
	{
	  HRESULT hr = S_OK;
	  if (fOverwrite)
	    hr = pScrollablePolicy->ResyncRow(hRow, pRowData->GetData());
	  if (FAILED(hr))
	    {
	      ErrorInfo::Clear();
	      OnRowChange(1, &hRow, DBREASON_ROW_RESYNCH, DBEVENTPHASE_FAILEDTODO);
	      dwRowStatus = DBROWSTATUS_E_FAIL;
	    }
	  else
	    {
	      OnRowChange(1, &hRow, DBREASON_ROW_RESYNCH, DBEVENTPHASE_DIDEVENT);
	      dwRowStatus = DBROWSTATUS_S_OK;
	    }
	}
      else if (fOverwrite)
	{
	  HRESULT hr = pScrollablePolicy->ResyncRow(hRow, pRowData->GetData());
	  if (FAILED(hr))
	    {
	      ErrorInfo::Clear();
	      OnRowChange(1, &hRow, DBREASON_ROW_RESYNCH, DBEVENTPHASE_FAILEDTODO);
	      dwRowStatus = DBROWSTATUS_E_FAIL;
	    }
	  else
	    {
	      pRowData->SetStatus(DBPENDINGSTATUS_UNCHANGED);
	      FreeOriginalData(hRow);
	      FreeVisibleData(hRow);
	      OnRowChange(1, &hRow, DBREASON_ROW_RESYNCH, DBEVENTPHASE_DIDEVENT);
	      dwRowStatus = DBROWSTATUS_S_OK;
	    }
	}
      else
	{
	  HRESULT hr;
	  std::map<HROW, char*>::iterator iter = m_mpVisibleData.find(hRow);
	  if (iter != m_mpVisibleData.end())
	    {
	      char* pbVisibleData = iter->second;
	      hr = pScrollablePolicy->ResyncRow(hRow, pbVisibleData);
	    }
	  else
	    {
	      char* pbVisibleData = new char[m_info.GetRecordSize()];
	      if (pbVisibleData != NULL)
		{
		  try {
		    m_mpVisibleData.insert(std::map<HROW, char*>::value_type(hRow, pbVisibleData));
		  } catch (...) {
		    delete [] pbVisibleData;
		    pbVisibleData = NULL;
		  }
		}
	      if (pbVisibleData == NULL)
		hr = E_OUTOFMEMORY;
	      else
		{
		  hr = pScrollablePolicy->ResyncRow(hRow, pbVisibleData);
		  if (FAILED(hr))
		    FreeVisibleData(hr);
		}
	    }
	  if (FAILED(hr))
	    {
	      ErrorInfo::Clear();
	      OnRowChange(1, &hRow, DBREASON_ROW_RESYNCH, DBEVENTPHASE_FAILEDTODO);
	      dwRowStatus = DBROWSTATUS_E_FAIL;
	    }
	  else
	    {
	      OnRowChange(1, &hRow, DBREASON_ROW_RESYNCH, DBEVENTPHASE_DIDEVENT);
	      dwRowStatus = DBROWSTATUS_S_OK;
	    }
	}

      if (dwRowStatus != DBROWSTATUS_E_INVALID)
	{
	  if (cRows == 0 && pcRowsRefreshed != NULL)
	    pRowData->AddRefRow();
	}

      if (pcRowsRefreshed != NULL && prgRowStatus != NULL)
	rgRowStatus[iRow] = dwRowStatus;

      if (dwRowStatus == DBROWSTATUS_S_OK)
	success = true;
      else
	failure = true;
    }

  if (pcRowsRefreshed != NULL)
    {
      *pcRowsRefreshed = cRowsRefreshed;
      *prghRowsRefreshed = rghRowsRefreshed.GiveUp();
      if (prgRowStatus != NULL)
	*prgRowStatus = rgRowStatus.GiveUp();
    }

  return failure ? success ? DB_S_ERRORSOCCURRED : DB_E_ERRORSOCCURRED : S_OK;
}

/**********************************************************************/
/* IRowsetResynch                                                     */

STDMETHODIMP
CRowset::GetVisibleData(
  HROW hRow,
  HACCESSOR hAccessor,
  void* pData
)
{
  LOGCALL(("CRowset::GetVisibleData()\n"));

  ErrorCheck error(IID_IRowset, DISPID_IRowsetResynch_GetVisibleData);

  CriticalSection critical_section(this);
  if (zombie)
    return ErrorInfo::Set(E_UNEXPECTED);
  if (m_pRowsetPolicy->IsStreamObjectAlive())
    return ErrorInfo::Set(E_UNEXPECTED);

  AutoReleaseAccessor accessor_iter(this, hAccessor);
  if (accessor_iter == EndAccessor())
    return ErrorInfo::Set(DB_E_BADACCESSORHANDLE);
  DataAccessor& accessor = GetAccessor(accessor_iter);
  if (accessor.GetBindingCount () == 0)
    return S_OK;
  if (pData == NULL)
    return ErrorInfo::Set(E_INVALIDARG);

  RowData* pRowData = m_pRowPolicy->GetRowData(hRow);
  if (pRowData == NULL || pRowData->GetRefRow() == 0)
    return ErrorInfo::Set(DB_E_BADROWHANDLE);

  DBPENDINGSTATUS dwPendingStatus = pRowData->GetStatus();
  if (dwPendingStatus == 0)
    return ErrorInfo::Set(DB_E_BADROWHANDLE);
  if (dwPendingStatus == DBPENDINGSTATUS_INVALIDROW)
    return ErrorInfo::Set(DB_E_DELETEDROW);
  if (dwPendingStatus == DBPENDINGSTATUS_NEW)
    return ErrorInfo::Set(DB_E_PENDINGINSERT);
  if (pRowData->IsInserted() && rowset_property_set->prop_STRONGIDENTITY.GetValue() == VARIANT_FALSE)
    return ErrorInfo::Set(DB_E_NEWLYINSERTED);

  char* pbVisibleData = NULL;
  AutoRelease<char, DeleteArray <char> > pbAutoVisibleData;
  std::map<HROW, char*>::iterator iter = m_mpVisibleData.find(hRow);
  if (iter == m_mpVisibleData.end())
    {
      pbAutoVisibleData.Set(new char[m_info.GetRecordSize()]);
      if (pbAutoVisibleData == NULL)
	return ErrorInfo::Set(E_OUTOFMEMORY);
      pbVisibleData = pbAutoVisibleData.Get();
    }
  else
    {
      pbVisibleData = iter->second;
      assert(pbVisibleData != NULL);
    }

  ScrollablePolicy* pScrollablePolicy = dynamic_cast<ScrollablePolicy*>(m_pRowsetPolicy);
  assert(pScrollablePolicy != 0);

  HRESULT hr = pScrollablePolicy->ResyncRow(hRow, pbVisibleData);
  if (FAILED(hr))
    return hr;

  return GetData(hRow, pbVisibleData, accessor, (char*) pData);
}

STDMETHODIMP
CRowset::ResynchRows(
  DBCOUNTITEM cRows,
  const HROW rghRows[],
  DBCOUNTITEM* pcRowsResynched,
  HROW** prghRowsResynched,
  DBROWSTATUS** prgRowStatus
)
{
  LOGCALL(("CRowset::ResynchRows()\n"));

  if (pcRowsResynched != NULL)
    {
      *pcRowsResynched = 0;
      if (prghRowsResynched != NULL)
	*prghRowsResynched = NULL;
      if (prgRowStatus != NULL)
	*prgRowStatus = NULL;
    }

  ErrorCheck error(IID_IRowset, DISPID_IRowsetResynch_ResynchRows);

  CriticalSection critical_section(this);
  if (zombie)
    return ErrorInfo::Set(E_UNEXPECTED);
  if (m_pRowsetPolicy->IsStreamObjectAlive())
    return ErrorInfo::Set(E_UNEXPECTED);
  if (cRows != 0 && rghRows == NULL)
    return ErrorInfo::Set(E_UNEXPECTED);
  if (pcRowsResynched != NULL && prghRowsResynched == NULL)
    return ErrorInfo::Set(E_UNEXPECTED);

  DBCOUNTITEM cRowsResynched = cRows;
  if (cRowsResynched == 0)
    {
      cRowsResynched = m_pRowPolicy->GetActiveRows();
      if (cRowsResynched == 0)
	return S_OK;
    }

  AutoRelease<HROW, ComMemFree> rghRowsResynched;
  if (cRows == 0 || pcRowsResynched != NULL)
    {
      rghRowsResynched.Set((HROW*) CoTaskMemAlloc(cRowsResynched * sizeof(HROW)));
      if (rghRowsResynched == NULL)
	return ErrorInfo::Set(E_OUTOFMEMORY);
      if (cRows == 0)
	m_pRowPolicy->GetActiveRowHandles(rghRowsResynched.Get());
    }

  AutoRelease<DBROWSTATUS, ComMemFree> rgRowStatus;
  if (pcRowsResynched != NULL && prgRowStatus != NULL)
    {
      rgRowStatus.Set((DBROWSTATUS*) CoTaskMemAlloc(cRowsResynched * sizeof(DBROWSTATUS)));
      if (rgRowStatus == NULL)
	return ErrorInfo::Set(E_OUTOFMEMORY);
    }

  ScrollablePolicy* pScrollablePolicy = dynamic_cast<ScrollablePolicy*>(m_pRowsetPolicy);
  assert(pScrollablePolicy != 0);

  bool failure = false;
  bool success = false;

  for (DBCOUNTITEM iRow = 0; iRow < cRowsResynched; iRow++)
    {
      HROW hRow;
      if (cRows == 0)
	{
	  hRow = rghRowsResynched[iRow];
	}
      else
	{
	  hRow = rghRows[iRow];
	  if (pcRowsResynched != NULL)
	    rghRowsResynched[iRow] = hRow;
	}

      RowData* pRowData = m_pRowPolicy->GetRowData(hRow);
      DBPENDINGSTATUS dwPendingStatus = pRowData == NULL ? 0 : pRowData->GetStatus();

      DBROWSTATUS dwRowStatus;
      if (dwPendingStatus == 0)
	dwRowStatus = DBROWSTATUS_E_INVALID;
      else if (dwPendingStatus == DBPENDINGSTATUS_INVALIDROW)
	dwRowStatus = DBROWSTATUS_E_DELETED;
      else if (dwPendingStatus == DBPENDINGSTATUS_NEW)
	dwRowStatus = DBROWSTATUS_E_PENDINGINSERT;
      else if (pRowData->IsInserted() && rowset_property_set->prop_STRONGIDENTITY.GetValue() == VARIANT_FALSE)
	dwRowStatus = DBROWSTATUS_E_NEWLYINSERTED;
      else if (S_FALSE == OnRowChange(1, &hRow, DBREASON_ROW_RESYNCH, DBEVENTPHASE_OKTODO))
	dwRowStatus = DBROWSTATUS_E_CANCELED;
      else if (S_FALSE == OnRowChange(1, &hRow, DBREASON_ROW_RESYNCH, DBEVENTPHASE_ABOUTTODO))
	dwRowStatus = DBROWSTATUS_E_CANCELED;
      else if (S_FALSE == OnRowChange(1, &hRow, DBREASON_ROW_RESYNCH, DBEVENTPHASE_SYNCHAFTER))
	dwRowStatus = DBROWSTATUS_E_CANCELED;
      else
	{
	  HRESULT hr = pScrollablePolicy->ResyncRow(hRow, pRowData->GetData());
	  if (FAILED(hr))
	    {
	      ErrorInfo::Clear();
	      OnRowChange(1, &hRow, DBREASON_ROW_RESYNCH, DBEVENTPHASE_FAILEDTODO);
	      dwRowStatus = DBROWSTATUS_E_FAIL;
	    }
	  else
	    {
	      pRowData->SetStatus(DBPENDINGSTATUS_UNCHANGED);
	      FreeOriginalData(hRow);
	      FreeVisibleData(hRow);
	      OnRowChange(1, &hRow, DBREASON_ROW_RESYNCH, DBEVENTPHASE_DIDEVENT);
	      dwRowStatus = DBROWSTATUS_S_OK;
	    }
	}

      if (dwRowStatus != DBROWSTATUS_E_INVALID)
	{
	  if (cRows == 0 && pcRowsResynched != NULL)
	    pRowData->AddRefRow();
	}

      if (pcRowsResynched != NULL && prgRowStatus != NULL)
	rgRowStatus[iRow] = dwRowStatus;

      if (dwRowStatus == DBROWSTATUS_S_OK)
	success = true;
      else
	failure = true;
    }

  if (pcRowsResynched != NULL)
    {
      *pcRowsResynched = cRowsResynched;
      *prghRowsResynched = rghRowsResynched.GiveUp();
      if (prgRowStatus != NULL)
	*prgRowStatus = rgRowStatus.GiveUp();
    }

  return failure ? success ? DB_S_ERRORSOCCURRED : DB_E_ERRORSOCCURRED : S_OK;
}

/**********************************************************************/
/* IRowsetScroll                                                      */

STDMETHODIMP
CRowset::GetApproximatePosition(
  HCHAPTER hChapter,
  DBBKMARK cbBookmark,
  const BYTE* pBookmark,
  DBCOUNTITEM* pulPosition,
  DBCOUNTITEM* pcRows
)
{
  LOGCALL(("CRowset::GetApproximatePosition()\n"));

  ErrorCheck error(IID_IRowsetScroll, DISPID_IRowsetScroll_GetApproximatePosition);

  CriticalSection critical_section(this);
  if (zombie)
    return ErrorInfo::Set(E_UNEXPECTED);
  if (m_pRowsetPolicy->IsStreamObjectAlive())
    return ErrorInfo::Set(E_UNEXPECTED);

  PositionalPolicy* pPositionalPolicy = dynamic_cast<PositionalPolicy*>(m_pRowsetPolicy);
  assert(pPositionalPolicy != 0);

  if (cbBookmark == 0)
    {
      if (pcRows != NULL)
	*pcRows = pPositionalPolicy->GetRowCount();
      return S_OK;
    }
  if (pBookmark == NULL)
    return ErrorInfo::Set(E_INVALIDARG);

  bool fStandardBookmark;
  ULONG ulBookmark;
  if (cbBookmark == 1)
    {
      if (*pBookmark != DBBMK_FIRST && *pBookmark != DBBMK_LAST)
	return ErrorInfo::Set(DB_E_BADBOOKMARK);
      fStandardBookmark = true;
      ulBookmark = *pBookmark;
    }
  else
    {
      if (cbBookmark != sizeof(ULONG))
	return ErrorInfo::Set(DB_E_BADBOOKMARK);
      fStandardBookmark = false;
      ulBookmark = *(ULONG*) pBookmark;
    }

  DBCOUNTITEM cRows = pPositionalPolicy->GetRowCount();
  DBCOUNTITEM ulPosition = 0;
  if (cRows != 0)
    {
      ulPosition = pPositionalPolicy->GetPosition(fStandardBookmark, ulBookmark);
      if (ulPosition == 0)
	return ErrorInfo::Set(DB_E_BADBOOKMARK);
    }

  if (pulPosition != NULL)
    *pulPosition = ulPosition;
  if (pcRows != NULL)
    *pcRows = cRows;
  return S_OK;
}

STDMETHODIMP
CRowset::GetRowsAtRatio(
  HWATCHREGION hReserved,
  HCHAPTER hChapter,
  DBCOUNTITEM ulNumerator,
  DBCOUNTITEM ulDenominator,
  DBROWCOUNT cRows,
  DBCOUNTITEM* pcRowsObtained,
  HROW** prghRows
)
{
  LOGCALL(("CRowset::GetRowsAtRatio()\n"));

  if (pcRowsObtained != NULL)
    *pcRowsObtained = 0;

  ErrorCheck error(IID_IRowsetScroll, DISPID_IRowsetScroll_GetRowsAtRatio);

  CriticalSection critical_section(this);
  if (zombie)
    return ErrorInfo::Set(E_UNEXPECTED);
  if (m_pRowsetPolicy->IsStreamObjectAlive())
    return ErrorInfo::Set(E_UNEXPECTED);

  if (prghRows == NULL || pcRowsObtained == NULL)
    return ErrorInfo::Set(E_INVALIDARG);
  if (ulNumerator > ulDenominator || ulDenominator == 0)
    return ErrorInfo::Set(DB_E_BADRATIO);
  if (cRows == 0)
    return S_OK;
  if (cRows < 0 && rowset_property_set->prop_CANFETCHBACKWARDS.GetValue() == VARIANT_FALSE)
    return ErrorInfo::Set(DB_E_CANTFETCHBACKWARDS);
  if (m_pRowPolicy->HoldsRows() && rowset_property_set->prop_CANHOLDROWS.GetValue() == VARIANT_FALSE)
    return ErrorInfo::Set(DB_E_ROWSNOTRELEASED);

  PositionalPolicy* pPositionalPolicy = dynamic_cast<PositionalPolicy*>(m_pRowsetPolicy);
  assert(pPositionalPolicy != 0);

  DBCOUNTITEM iPosition;
  if (ulNumerator == 0)
    iPosition = cRows < 0 ? 0 : 1;
  else if (ulNumerator == ulDenominator)
    iPosition = pPositionalPolicy->GetRowCount() + (cRows < 0 ? 0 : 1);
  else
    iPosition = (ULONG) ((__int64) pPositionalPolicy->GetRowCount() * ulNumerator / ulDenominator);

  HRESULT hr = pPositionalPolicy->GetRowsAtPosition(true, DBBMK_FIRST, iPosition - 1, cRows);
  if (FAILED(hr))
    return hr;
  DBCOUNTITEM cRowsObtained = pPositionalPolicy->GetRowsObtained();
  if (cRowsObtained == 0)
    return hr;

  HROW* rghRows = *prghRows;
  if (rghRows == NULL)
    {
      rghRows = (HROW*) CoTaskMemAlloc(cRowsObtained * sizeof(HROW));
      if (rghRows == NULL)
	return ErrorInfo::Set(E_OUTOFMEMORY);
    }
  m_pRowsetPolicy->GetRowHandlesObtained(rghRows);

  *pcRowsObtained = cRowsObtained;
  if (*prghRows == NULL)
    *prghRows = rghRows;

  OnRowActivate(cRowsObtained, rghRows);
  return hr;
}

/**********************************************************************/
/* IRowsetUpdate                                                      */

STDMETHODIMP
CRowset::GetOriginalData(HROW hRow, HACCESSOR hAccessor, void* pData)
{
  LOGCALL(("CRowset::GetOriginalData()\n"));

  ErrorCheck error(IID_IRowsetUpdate, DISPID_IRowsetUpdate_GetOriginalData);

  CriticalSection critical_section(this);
  if (zombie)
    return ErrorInfo::Set(E_UNEXPECTED);
  if (m_pRowsetPolicy->IsStreamObjectAlive())
    return ErrorInfo::Set(E_UNEXPECTED);

  AutoReleaseAccessor accessor_iter(this, hAccessor);
  if (accessor_iter == EndAccessor())
    return ErrorInfo::Set(DB_E_BADACCESSORHANDLE);

  DataAccessor& accessor = GetAccessor(accessor_iter);
  if (accessor.GetBindingCount () == 0)
    return S_OK;
  if (pData == NULL)
    return ErrorInfo::Set(E_INVALIDARG);

  RowData* pRowData = m_pRowPolicy->GetRowData(hRow);
  if (pRowData == NULL || pRowData->GetRefRow() == 0)
    return ErrorInfo::Set(DB_E_BADROWHANDLE);

  DBPENDINGSTATUS dwPendingStatus = pRowData->GetStatus();
  if (dwPendingStatus == 0)
    return ErrorInfo::Set(DB_E_BADROWHANDLE);
  if (dwPendingStatus == DBPENDINGSTATUS_INVALIDROW)
    return ErrorInfo::Set(DB_E_DELETEDROW);

  char* pbOriginalData = NULL;
  if (dwPendingStatus == DBPENDINGSTATUS_UNCHANGED)
    pbOriginalData = pRowData->GetData();
  else
    {
      std::map<HROW, char*>::iterator iter = m_mpOriginalData.find(hRow);
      assert(iter != m_mpOriginalData.end());
      pbOriginalData = iter->second;
    }

  return GetData(hRow, pbOriginalData, accessor, (char*) pData);
}

STDMETHODIMP
CRowset::GetPendingRows(
  HCHAPTER hReserved,
  DBPENDINGSTATUS dwRowStatus,
  DBCOUNTITEM* pcPendingRows,
  HROW** prgPendingRows,
  DBPENDINGSTATUS** prgPendingStatus
)
{
  LOGCALL(("CRowset::GetPendingRows()\n"));

  if (pcPendingRows != NULL)
    {
      *pcPendingRows = 0;
      if (prgPendingRows != NULL)
	*prgPendingRows = NULL;
      if (prgPendingStatus != NULL)
	*prgPendingStatus = NULL;
    }

  ErrorCheck error(IID_IRowsetUpdate, DISPID_IRowsetUpdate_GetPendingRows);

  CriticalSection critical_section(this);
  if (zombie)
    return ErrorInfo::Set(E_UNEXPECTED);
  if ((dwRowStatus & ~(DBPENDINGSTATUS_NEW | DBPENDINGSTATUS_CHANGED | DBPENDINGSTATUS_DELETED)) != 0)
    return ErrorInfo::Set(E_INVALIDARG);

  DBCOUNTITEM cPendingRows = 0;
  std::map<HROW, char*>::iterator iter;
  for (iter = m_mpOriginalData.begin(); iter != m_mpOriginalData.end(); iter++)
    {
      HROW hRow = iter->first;
      RowData* pRowData = m_pRowPolicy->GetRowData(hRow);
      assert(pRowData != NULL);

      DBPENDINGSTATUS dwPendingStatus = pRowData->GetStatus();
      if ((dwPendingStatus & dwRowStatus) != 0)
	cPendingRows++;
    }

  if (cPendingRows == 0)
    return S_FALSE;
  if (pcPendingRows == NULL)
    return S_OK;
  if (prgPendingRows == NULL && prgPendingStatus == NULL)
    {
      *pcPendingRows = cPendingRows;
      return S_OK;
    }

  AutoRelease<HROW, ComMemFree> rgPendingRows;
  if (prgPendingRows != NULL)
    {
      rgPendingRows.Set((HROW*) CoTaskMemAlloc(cPendingRows * sizeof(HROW)));
      if (rgPendingRows == NULL)
	return ErrorInfo::Set(E_OUTOFMEMORY);
    }

  AutoRelease<DBPENDINGSTATUS, ComMemFree> rgPendingStatus;
  if (prgPendingStatus != NULL)
    {
      rgPendingStatus.Set((DBPENDINGSTATUS*) CoTaskMemAlloc(cPendingRows * sizeof(DBPENDINGSTATUS)));
      if (rgPendingStatus == NULL)
	return ErrorInfo::Set(E_OUTOFMEMORY);
    }

  DBCOUNTITEM iPendingRow = 0;
  for (iter = m_mpOriginalData.begin(); iter != m_mpOriginalData.end(); iter++)
    {
      HROW hRow = iter->first;
      RowData* pRowData = m_pRowPolicy->GetRowData(hRow);
      assert(pRowData != NULL);

      DBPENDINGSTATUS dwPendingStatus = pRowData->GetStatus();
      if ((dwPendingStatus & dwRowStatus) != 0)
	{
	  pRowData->AddRefRow();
	  if (prgPendingRows != NULL)
	    rgPendingRows[iPendingRow] = hRow;
	  if (prgPendingStatus != NULL)
	    rgPendingStatus[iPendingRow] = dwPendingStatus;
	  iPendingRow++;
	}
    }

  *pcPendingRows = cPendingRows;
  if (prgPendingRows != NULL)
    *prgPendingRows = rgPendingRows.GiveUp();
  if (prgPendingStatus != NULL)
    *prgPendingStatus = rgPendingStatus.GiveUp();
  return S_OK;
}

STDMETHODIMP
CRowset::GetRowStatus(
  HCHAPTER hReserved,
  DBCOUNTITEM cRows,
  const HROW rghRows[],
  DBPENDINGSTATUS rgPendingStatus[]
)
{
  LOGCALL(("CRowset::GetRowStatus()\n"));

  ErrorCheck error(IID_IRowsetUpdate, DISPID_IRowsetUpdate_GetRowStatus);

  CriticalSection critical_section(this);
  if (zombie)
    return ErrorInfo::Set(E_UNEXPECTED);
  if (cRows == 0)
    return S_OK;
  if (rghRows == NULL || rgPendingStatus == NULL)
    return ErrorInfo::Set(E_INVALIDARG);

  bool success = false;
  bool failure = false;

  for (DBCOUNTITEM iRow = 0; iRow < cRows; iRow++)
    {
      HROW hRow = rghRows[iRow];
      RowData* pRowData = m_pRowPolicy->GetRowData(hRow);

      DBPENDINGSTATUS dwPendingStatus = pRowData == NULL ? 0 : pRowData->GetStatus();
      if (dwPendingStatus == 0)
	dwPendingStatus = DBPENDINGSTATUS_INVALIDROW;

      rgPendingStatus[iRow] = dwPendingStatus;

      if (dwPendingStatus == DBPENDINGSTATUS_INVALIDROW)
	failure = true;
      else
	success = true;
    }

  return failure ? success ? DB_S_ERRORSOCCURRED : DB_E_ERRORSOCCURRED : S_OK;
}

STDMETHODIMP
CRowset::Undo(
  HCHAPTER hReserved,
  DBCOUNTITEM cRows,
  const HROW rghRows[],
  DBCOUNTITEM* pcRows,
  HROW** prgRows,
  DBROWSTATUS** prgRowStatus
)
{
  LOGCALL(("CRowset::Undo()\n"));

  if (pcRows != NULL)
    *pcRows = 0;
  if (pcRows != NULL && prgRows != NULL)
    *prgRows = NULL;
  if ((cRows != 0 || pcRows != NULL) && prgRowStatus != NULL)
    *prgRowStatus = NULL;

  ErrorCheck error(IID_IRowsetUpdate, DISPID_IRowsetUpdate_Undo);

  CriticalSection critical_section(this);
  if (zombie)
    return ErrorInfo::Set(E_UNEXPECTED);
  if (cRows != 0 && rghRows == NULL)
    return ErrorInfo::Set(E_INVALIDARG);
  if (pcRows != NULL && prgRows == NULL)
    return ErrorInfo::Set(E_INVALIDARG);

  std::map<HROW, char*>::iterator iter;

  AutoRelease<HROW, ComMemFree> rgRows;
  if (cRows == 0)
    {
      cRows = (DBCOUNTITEM) m_mpOriginalData.size();
      rgRows.Set((HROW*) CoTaskMemAlloc(cRows * sizeof(HROW)));
      if (rgRows == NULL)
	return ErrorInfo::Set(E_OUTOFMEMORY);
      iter = m_mpOriginalData.begin();
      for (DBCOUNTITEM iRow = 0; iter != m_mpOriginalData.end(); iRow++, iter++)
	rgRows[iRow] = iter->first;
      rghRows = rgRows.Get();
    }
  else if (pcRows != NULL)
    {
      rgRows.Set((HROW*) CoTaskMemAlloc(cRows * sizeof(HROW)));
      if (rgRows == NULL)
	return ErrorInfo::Set(E_OUTOFMEMORY);
      for (DBCOUNTITEM iRow = 0; iRow < cRows; iRow++)
	rgRows[iRow] = rghRows[iRow];
    }

  if (cRows == 0)
    return S_OK;

  AutoRelease<DBROWSTATUS, ComMemFree> rgRowStatus;
  if ((cRows != NULL || pcRows != NULL) && prgRowStatus != NULL)
    {
      rgRowStatus.Set((DBROWSTATUS*) CoTaskMemAlloc(cRows * sizeof(DBROWSTATUS)));
      if (rgRowStatus == NULL)
	return ErrorInfo::Set(E_OUTOFMEMORY);
    }

  bool success = false;
  bool failure = false;

  for (DBCOUNTITEM iRow = 0; iRow < cRows; iRow++)
    {
      HROW hRow = rghRows[iRow];
      RowData* pRowData = m_pRowPolicy->GetRowData(hRow);
      DBPENDINGSTATUS dwPendingStatus = pRowData == NULL ? 0 : pRowData->GetStatus();

      DBROWSTATUS dwRowStatus;
      if (dwPendingStatus == 0)
	dwRowStatus = DBROWSTATUS_E_INVALID;
      else if (dwPendingStatus == DBPENDINGSTATUS_INVALIDROW)
	dwRowStatus = DBROWSTATUS_E_DELETED;
      else if (dwPendingStatus == DBPENDINGSTATUS_UNCHANGED)
	dwRowStatus = DBROWSTATUS_S_OK;
      else
	{
	  DBREASON dwReason;
	  if (dwPendingStatus == DBPENDINGSTATUS_NEW)
	    dwReason = DBREASON_ROW_UNDOINSERT;
	  else if (dwPendingStatus == DBPENDINGSTATUS_DELETED)
	    dwReason = DBREASON_ROW_UNDODELETE;
	  else //if (dwPendingStatus == DBPENDINGSTATUS_CHANGED)
	    dwReason = DBREASON_ROW_UNDOCHANGE;

	  if (S_FALSE == OnRowChange(1, &hRow, dwReason, DBEVENTPHASE_OKTODO))
	    dwRowStatus = DBROWSTATUS_E_CANCELED;
	  else if (S_FALSE == OnRowChange(1, &hRow, dwReason, DBEVENTPHASE_ABOUTTODO))
	    dwRowStatus = DBROWSTATUS_E_CANCELED;
	  else if (S_FALSE == OnRowChange(1, &hRow, dwReason, DBEVENTPHASE_SYNCHAFTER))
	    dwRowStatus = DBROWSTATUS_E_CANCELED;
	  else if (dwPendingStatus == DBPENDINGSTATUS_NEW)
	    {
	      m_mpOriginalData.erase(iter);
	      m_pRowPolicy->DeleteRow(pRowData);
	      OnRowChange(1, &hRow, dwReason, DBEVENTPHASE_DIDEVENT);
	      dwRowStatus = DBROWSTATUS_S_OK;
	    }
	  else //if (dwPendingStatus == DBPENDINGSTATUS_DELETED || dwPendingStatus == DBPENDINGSTATUS_CHANGED)
	    {
	      iter = m_mpOriginalData.find(hRow);
	      assert(iter != m_mpOriginalData.end());

	      char* cbOriginalData = iter->second;
	      if (cbOriginalData != NULL) // changed or changed and then deleted
		{
		  memcpy(pRowData->GetData(), cbOriginalData, m_info.GetRecordSize());
		  delete [] cbOriginalData;
		}

	      m_mpOriginalData.erase(iter);
	      pRowData->SetStatus(DBPENDINGSTATUS_UNCHANGED);
	      OnRowChange(1, &hRow, dwReason, DBEVENTPHASE_DIDEVENT);
	      dwRowStatus = DBROWSTATUS_S_OK;
	    }
	}

      if ((cRows != 0 || pcRows != NULL) && prgRowStatus != NULL)
	rgRowStatus[iRow] = dwRowStatus;

      if (dwRowStatus != DBROWSTATUS_E_INVALID)
	{
	  if (cRows == 0 && pcRows != NULL)
	    pRowData->AddRefRow();
	}

      if (dwRowStatus == DBROWSTATUS_S_OK || dwRowStatus == DBROWSTATUS_S_MULTIPLECHANGES)
	success = true;
      else
	failure = true;
    }

  if (pcRows != NULL)
    {
      *pcRows = cRows;
      *prgRows = rgRows.GiveUp();
    }

  if ((cRows != 0 || pcRows != NULL) && prgRowStatus != NULL)
    *prgRowStatus = rgRowStatus.GiveUp();

  return failure ? success ? DB_S_ERRORSOCCURRED : DB_E_ERRORSOCCURRED : S_OK;
}

STDMETHODIMP
CRowset::Update(
  HCHAPTER hReserved,
  DBCOUNTITEM cRows,
  const HROW rghRows[],
  DBCOUNTITEM* pcRows,
  HROW** prgRows,
  DBROWSTATUS** prgRowStatus
)
{
  LOGCALL(("CRowset::Update()\n"));

  if (pcRows != NULL)
    *pcRows = 0;
  if (pcRows != NULL && prgRows != NULL)
    *prgRows = NULL;
  if ((cRows != 0 || pcRows != NULL) && prgRowStatus != NULL)
    *prgRowStatus = NULL;

  ErrorCheck error(IID_IRowsetUpdate, DISPID_IRowsetUpdate_Update);

  CriticalSection critical_section(this);
  if (zombie)
    return ErrorInfo::Set(E_UNEXPECTED);
  if (cRows != 0 && rghRows == NULL)
    return ErrorInfo::Set(E_INVALIDARG);
  if (pcRows != NULL && prgRows == NULL)
    return ErrorInfo::Set(E_INVALIDARG);

  std::map<HROW, char*>::iterator iter;

  AutoRelease<HROW, ComMemFree> rgRows;
  if (cRows == 0)
    {
      cRows = (DBCOUNTITEM)m_mpOriginalData.size();
      rgRows.Set((HROW*) CoTaskMemAlloc(cRows * sizeof(HROW)));
      if (rgRows == NULL)
	return ErrorInfo::Set(E_OUTOFMEMORY);
      iter = m_mpOriginalData.begin();
      for (DBCOUNTITEM iRow = 0; iter != m_mpOriginalData.end(); iRow++, iter++)
	rgRows[iRow] = iter->first;
      rghRows = rgRows.Get();
    }
  else if (pcRows != NULL)
    {
      rgRows.Set((HROW*) CoTaskMemAlloc(cRows * sizeof(HROW)));
      if (rgRows == NULL)
	return ErrorInfo::Set(E_OUTOFMEMORY);
      for (DBCOUNTITEM iRow = 0; iRow < cRows; iRow++)
	rgRows[iRow] = rghRows[iRow];
    }

  if (cRows == 0)
    return S_OK;

  AutoRelease<DBROWSTATUS, ComMemFree> rgRowStatus;
  if ((cRows != 0 || pcRows != NULL) && prgRowStatus != NULL)
    {
      rgRowStatus.Set((DBROWSTATUS*) CoTaskMemAlloc(cRows * sizeof(DBROWSTATUS)));
      if (rgRowStatus == NULL)
	return ErrorInfo::Set(E_OUTOFMEMORY);
    }

  ScrollablePolicy* pScrollablePolicy = dynamic_cast<ScrollablePolicy*>(m_pRowsetPolicy);
  assert(pScrollablePolicy != 0);

  bool success = false;
  bool failure = false;

  for (DBCOUNTITEM iRow = 0; iRow < cRows; iRow++)
    {
      HROW hRow = rghRows[iRow];
      RowData* pRowData = m_pRowPolicy->GetRowData(hRow);
      DBPENDINGSTATUS dwPendingStatus = pRowData == NULL ? 0 : pRowData->GetStatus();

      DBROWSTATUS dwRowStatus;
      if (dwPendingStatus == 0)
	dwRowStatus = DBROWSTATUS_E_INVALID;
      else if (dwPendingStatus == DBPENDINGSTATUS_INVALIDROW)
	dwRowStatus = DBROWSTATUS_E_DELETED;
      else if (dwPendingStatus == DBPENDINGSTATUS_UNCHANGED)
	dwRowStatus = DBROWSTATUS_S_OK;
      else if (S_FALSE == OnRowChange(1, &hRow, DBREASON_ROW_UPDATE, DBEVENTPHASE_OKTODO))
	dwRowStatus = DBROWSTATUS_E_CANCELED;
      else if (S_FALSE == OnRowChange(1, &hRow, DBREASON_ROW_UPDATE, DBEVENTPHASE_ABOUTTODO))
	dwRowStatus = DBROWSTATUS_E_CANCELED;
      else if (S_FALSE == OnRowChange(1, &hRow, DBREASON_ROW_UPDATE, DBEVENTPHASE_SYNCHAFTER))
	dwRowStatus = DBROWSTATUS_E_CANCELED;
      else
	{
	  HRESULT hr = S_OK;
	  if (dwPendingStatus == DBPENDINGSTATUS_NEW)
	    {
	      hr = pScrollablePolicy->InsertRow(hRow);
#if 1
	      assert(hr != S_FALSE);
#else
	      if (hr == S_FALSE)
		hr = m_dth.SetDataAtExec(m_info, m_pRowsetPolicy, accessor, (char*) pData, false);
#endif
	      if (SUCCEEDED(hr))
		{
		  pRowData->SetInserted();
		  pRowData->SetStatus(DBPENDINGSTATUS_UNCHANGED);
		}
	    }
	  else if (dwPendingStatus == DBPENDINGSTATUS_DELETED)
	    {
	      hr = pScrollablePolicy->DeleteRow(rghRows[iRow]);
	      if (SUCCEEDED(hr))
		m_pRowPolicy->DeleteRow(pRowData);
	    }
	  else if (dwPendingStatus == DBPENDINGSTATUS_CHANGED)
	    {
	      hr = pScrollablePolicy->UpdateRow(hRow, false);
#if 1
	      assert(hr != S_FALSE);
#else
	      if (hr == S_FALSE)
		hr = m_dth.SetDataAtExec(m_info, m_pRowsetPolicy, accessor, (char*) pData, false);
#endif
	      if (SUCCEEDED(hr))
		pRowData->SetStatus(DBPENDINGSTATUS_UNCHANGED);
	    }

	  if (FAILED(hr))
	    {
	      ErrorInfo::Clear();
	      OnRowChange(1, &hRow, DBREASON_ROW_UPDATE, DBEVENTPHASE_FAILEDTODO);
	      if (hr == DB_E_CANCELED)
		dwRowStatus = DBROWSTATUS_E_CANCELED;
	      else if (hr == DB_E_INTEGRITYVIOLATION)
		dwRowStatus = DBROWSTATUS_E_INTEGRITYVIOLATION;
	      else
		dwRowStatus = DBROWSTATUS_E_FAIL;
	    }
	  else
	    {
	      FreeOriginalData(hRow);
	      FreeVisibleData(hRow);
	      OnRowChange(1, &hRow, DBREASON_ROW_UPDATE, DBEVENTPHASE_DIDEVENT);
	      if (hr == DB_S_MULTIPLECHANGES)
		dwRowStatus = DBROWSTATUS_S_MULTIPLECHANGES;
	      else
		dwRowStatus = DBROWSTATUS_S_OK;
	    }
	}

      if ((cRows != 0 || pcRows != NULL) && prgRowStatus != NULL)
	rgRowStatus[iRow] = dwRowStatus;

      if (dwRowStatus != DBROWSTATUS_E_INVALID)
	{
	  if (cRows == 0 && pcRows != NULL)
	    pRowData->AddRefRow();
	  else if (pRowData->GetRefRow() == 0)
	    m_pRowPolicy->ReleaseRowData(hRow);
	}

      if (dwRowStatus == DBROWSTATUS_S_OK || dwRowStatus == DBROWSTATUS_S_MULTIPLECHANGES)
	success = true;
      else
	failure = true;
    }

  if (pcRows != NULL)
    {
      *pcRows = cRows;
      *prgRows = rgRows.GiveUp();
    }

  if ((cRows != 0 || pcRows != NULL) && prgRowStatus != NULL)
    *prgRowStatus = rgRowStatus.GiveUp();

  return failure ? success ? DB_S_ERRORSOCCURRED : DB_E_ERRORSOCCURRED : S_OK;
}

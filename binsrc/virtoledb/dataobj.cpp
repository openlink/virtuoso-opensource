/*  dataobj.cpp
 *
 *  $Id$
 *
 *  Base class for Command and Rowset objects.
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
#include "dataobj.h"
#include "session.h"
#include "rowset.h"
#include "rowsetprops.h"
#include "util.h"
#include "error.h"
#include <bitset>


/**********************************************************************/
/* CDataObj                                                            */

CDataObj::CDataObj()
{
  zombie = false;
  m_pSession = NULL;
  last_accessor_handle = 0;
  rowset_property_set = NULL;
}

CDataObj::~CDataObj()
{
  m_dth.Release();
  if (m_pSession != NULL)
    m_pSession->GetControllingUnknown()->Release();
  while (accessors.empty() == false)
    RemoveAccessor(accessors.begin());
}

HRESULT
CDataObj::Init(CSession* pSession, RowsetPropertySet* rps)
{
  assert(pSession != NULL);
  m_pSession = pSession;
  m_pSession->GetControllingUnknown()->AddRef();

  assert(rps != NULL);
  rowset_property_set = rps;

  return m_dth.Init();
}

ULONG
CDataObj::GetPropertySetCount()
{
  return 1;
}

PropertySet*
CDataObj::GetPropertySet(ULONG iPropertySet)
{
  assert(iPropertySet == 0);
  return rowset_property_set;
}

PropertySet*
CDataObj::GetPropertySet(REFGUID rguidPropertySet)
{
  if (rguidPropertySet == DBPROPSET_ROWSET)
    return rowset_property_set;
  return NULL;
}

bool
CDataObj::IsChangeableRowset() const
{
  return false;
}

HRESULT
CDataObj::CreateAccessor
(
  DBACCESSORFLAGS dwAccessorFlags,
  DBCOUNTITEM cBindings,
  const DBBINDING rgBindings[],
  DBLENGTH cbRowSize,
  HACCESSOR* phAccessor
)
{
  LOGCALL (("CDataObj::CreateAccessor()\n"));

  CriticalSection critical_section(this);

  last_accessor_handle++;
#if 0
  // in case of overflow
  if (last_accessor_handle < 0)
    {
      last_accessor_handle = 1;
      while (accessors.find(last_accessor_handle) != accessors.end())
	last_accessor_handle++;
    }
#endif

  AccessorIterator iter;
  try {
    iter = accessors.insert(AccessorMap::value_type (last_accessor_handle, DataAccessor())).first;
  } catch (...) {
    return ErrorInfo::Set(E_OUTOFMEMORY);
  }

  DataAccessor& accessor = iter->second;
  HRESULT hr = accessor.Init (dwAccessorFlags, cBindings, rgBindings, cbRowSize);
  if (FAILED (hr))
    {
      accessors.erase(iter);
      return hr;
    }

  *phAccessor = iter->first;
  return S_OK;
}

AccessorIterator
CDataObj::AcquireAccessor(HACCESSOR hAccessor)
{
  LOGCALL (("CDataObj::AcquireAccessor()\n"));

  // Comment this out. The caller must already be synchronized.
  //CriticalSection critical_section(this);

  AccessorIterator iterator = accessors.find(hAccessor);
  if (iterator != accessors.end())
    {
      DataAccessor& accessor = iterator->second;
      accessor.AddRef ();
    }

  return iterator;
}

void
CDataObj::ReleaseAccessor(AccessorIterator& iterator)
{
  LOGCALL (("CDataObj::ReleaseAccessor()\n"));

  // Comment this out. The caller must already be synchronized.
  //CriticalSection critical_section(this);

  if (iterator != accessors.end())
    {
      DataAccessor& accessor = iterator->second;
      if(accessor.Release () == 0)
	RemoveAccessor(iterator);
    }
}

DataAccessor&
CDataObj::GetAccessor(AccessorIterator& iterator)
{
  assert(iterator != accessors.end());
  return iterator->second;
}

AccessorIterator
CDataObj::EndAccessor()
{
  return accessors.end();
}

void
CDataObj::RemoveAccessor(AccessorIterator iterator)
{
  accessors.erase(iterator);
}

HRESULT
CDataObj::CopyRowAccessors(const CDataObj* dataobj)
{
  LOGCALL (("CDataObj::CopyRowAccessors()\n"));

  assert(last_accessor_handle == 0);

  CriticalSection critical_section(const_cast<CDataObj*>(dataobj));

  AccessorMap::const_iterator src_iter = dataobj->accessors.begin();
  while (src_iter != dataobj->accessors.end())
    {
      AccessorIterator dst_iter;
      try {
	dst_iter = accessors.insert(AccessorMap::value_type (src_iter->first, DataAccessor())).first;
      } catch (...) {
	return ErrorInfo::Set(E_OUTOFMEMORY);
      }

      const DataAccessor& src_accessor = src_iter->second;
      DataAccessor& dst_accessor = dst_iter->second;
      HRESULT hr = dst_accessor.Init (src_accessor, src_accessor.GetFlags () & ~DBACCESSOR_PARAMETERDATA);
      if (FAILED (hr))
	{
	  accessors.erase(dst_iter);
	  return hr;
	}

      src_iter++;
    }
  last_accessor_handle = dataobj->last_accessor_handle;

  return S_OK;
}

/**********************************************************************/
/* IAccessor                                                          */

STDMETHODIMP
CDataObj::AddRefAccessor
(
  HACCESSOR hAccessor,
  DBREFCOUNT *pcRefCount
)
{
  LOGCALL(("CDataObj::AddRefAccessor()\n"));

  ErrorCheck error(IID_IAccessor, DISPID_IAccessor_AddRefAccessor);

  CriticalSection critical_section(this);
  if (zombie)
    return ErrorInfo::Set(E_UNEXPECTED);

  AccessorIterator iterator = accessors.find(hAccessor);
  if (iterator == accessors.end())
    return ErrorInfo::Set(DB_E_BADACCESSORHANDLE);

  DataAccessor& accessor = iterator->second;
  LONG cRefCount = accessor.AddRef ();

  if (pcRefCount != NULL)
    *pcRefCount = cRefCount;
  return S_OK;
}

STDMETHODIMP
CDataObj::CreateAccessor
(
  DBACCESSORFLAGS dwAccessorFlags,
  DBCOUNTITEM cBindings,
  const DBBINDING rgBindings[],
  DBLENGTH cbRowSize,
  HACCESSOR *phAccessor,
  DBBINDSTATUS rgStatus[]
)
{
  LOGCALL(("CDataObj::CreateAccessor()\n"));

  ErrorCheck error(IID_IAccessor, DISPID_IAccessor_CreateAccessor);

  if (phAccessor == NULL)
    return ErrorInfo::Set(E_INVALIDARG);
  *phAccessor = NULL;

  CriticalSection critical_section(this);
  if (zombie)
    return ErrorInfo::Set(E_UNEXPECTED);

  if (cBindings != 0 && rgBindings == NULL)
    return ErrorInfo::Set(E_INVALIDARG);
  if (dwAccessorFlags & DBACCESSOR_PASSBYREF)
    return ErrorInfo::Set(DB_E_BYREFACCESSORNOTSUPPORTED);
  if (dwAccessorFlags == DBACCESSOR_INVALID)
    return ErrorInfo::Set(DB_E_BADACCESSORFLAGS);
  if ((dwAccessorFlags & (DBACCESSOR_PARAMETERDATA | DBACCESSOR_ROWDATA)) == 0)
    return ErrorInfo::Set(DB_E_BADACCESSORFLAGS);
  if ((dwAccessorFlags & ~(DBACCESSOR_PASSBYREF | DBACCESSOR_ROWDATA
                           | DBACCESSOR_PARAMETERDATA | DBACCESSOR_OPTIMIZED
			   | DBACCESSOR_INHERITED)) != 0)
    return ErrorInfo::Set(DB_E_BADACCESSORFLAGS);
  if ((dwAccessorFlags & DBACCESSOR_PARAMETERDATA) != 0 && !IsCommand())
    return ErrorInfo::Set(DB_E_BADACCESSORFLAGS);
  if (cBindings == 0 && (IsCommand() || !IsChangeableRowset()))
    return ErrorInfo::Set(DB_E_NULLACCESSORNOTSUPPORTED);

  const RowsetInfo* rowset_info = NULL;
  if (!IsCommand())
    {
      HRESULT hr = GetRowsetInfo(rowset_info);
      if (FAILED(hr))
	return hr;
    }

  bool errors = false;
  for (DBCOUNTITEM iBinding = 0; iBinding < cBindings; iBinding++)
    {
      DBBINDSTATUS status = m_dth.ValidateBinding(dwAccessorFlags, rgBindings[iBinding]);
      if (status == DBBINDSTATUS_OK && !IsCommand())
	{
	  assert(rowset_info != NULL);
	  status = m_dth.MetadataValidateBinding(*rowset_info, rgBindings[iBinding]);
	}
      if (rgStatus != NULL)
	rgStatus[iBinding] = status;
      if (status != DBBINDSTATUS_OK)
	{
	  LOG(("Validation failed for iBinding = %d\n", iBinding));
	  errors = true;
	}
    }
  if (errors)
    return DB_E_ERRORSOCCURRED;

  if ((dwAccessorFlags & DBACCESSOR_PARAMETERDATA) != 0)
    {
#define PARAMETER_INFINITY 1024

      std::bitset<PARAMETER_INFINITY> set;
      for (ULONG iBinding = 0; iBinding < cBindings; iBinding++)
	{
	  if (rgBindings[iBinding].eParamIO & DBPARAMIO_INPUT)
	    {
	      if (rgBindings[iBinding].iOrdinal > PARAMETER_INFINITY)
		return ErrorInfo::Set(E_FAIL);
	      if (set.test(rgBindings[iBinding].iOrdinal - 1))
		{
		  if (rgStatus != NULL)
		    rgStatus[iBinding] = DBBINDSTATUS_BADBINDINFO;
		  errors = true;
		}
	      set.set(rgBindings[iBinding].iOrdinal - 1);
	    }
	}
      if (errors)
	return DB_E_ERRORSOCCURRED;
    }

  return CreateAccessor(dwAccessorFlags, cBindings, rgBindings, cbRowSize, phAccessor);
}

STDMETHODIMP
CDataObj::GetBindings
(
  HACCESSOR hAccessor,
  DBACCESSORFLAGS *pwdAccessorFlags,
  DBCOUNTITEM *pcBindings,
  DBBINDING **prgBindings
)
{
  LOGCALL(("CDataObj::GetBindings()\n"));

  if (pwdAccessorFlags != NULL)
    *pwdAccessorFlags = 0;
  if (pcBindings != NULL)
    *pcBindings = 0;
  if (prgBindings != NULL)
    *prgBindings = NULL;

  ErrorCheck error(IID_IAccessor, DISPID_IAccessor_GetBindings);

  CriticalSection critical_section(this);
  if (zombie)
    return ErrorInfo::Set(E_UNEXPECTED);
  if (pwdAccessorFlags == NULL || pcBindings == NULL || prgBindings == NULL)
    return ErrorInfo::Set(E_INVALIDARG);

  AccessorIterator accessor_iter = AcquireAccessor(hAccessor);
  if (accessor_iter == EndAccessor())
    return ErrorInfo::Set(DB_E_BADACCESSORHANDLE);

  DataAccessor& accessor = GetAccessor(accessor_iter);

  *pwdAccessorFlags = accessor.GetFlags ();
  *pcBindings = accessor.GetBindingCount ();
  if (accessor.GetBindingCount () != 0)
    {
      *prgBindings = (DBBINDING *) CoTaskMemAlloc(accessor.GetBindingCount () * sizeof (DBBINDING));
      if (*prgBindings == NULL)
	{
	  ReleaseAccessor(accessor_iter);
	  return ErrorInfo::Set(E_OUTOFMEMORY);
	}
      memcpy (*prgBindings, accessor.GetBindings (), accessor.GetBindingCount () * sizeof (DBBINDING));
    }

  ReleaseAccessor(accessor_iter);
  return S_OK;
}

STDMETHODIMP
CDataObj::ReleaseAccessor
(
  HACCESSOR hAccessor,
  DBREFCOUNT *pcRefCount
)
{
  LOGCALL(("CDataObj::ReleaseAccessor()\n"));

  ErrorCheck error(IID_IAccessor, DISPID_IAccessor_ReleaseAccessor);

  CriticalSection critical_section(this);

  AccessorIterator iterator = accessors.find(hAccessor);
  if (iterator == accessors.end())
    return ErrorInfo::Set(DB_E_BADACCESSORHANDLE);

  DataAccessor& accessor = iterator->second;
  LONG cRefCount = accessor.Release ();
  if (cRefCount == 0)
    RemoveAccessor(iterator);

  if (pcRefCount != NULL)
    *pcRefCount = cRefCount;
  return S_OK;
}

/**********************************************************************/
/* IColumnsInfo                                                       */

STDMETHODIMP
CDataObj::GetColumnInfo
(
  DBORDINAL *pcColumns,
  DBCOLUMNINFO **prgInfo,
  OLECHAR **ppStringsBuffer
)
{
  LOGCALL(("CDataObj::GetColumnInfo()\n"));

  if (pcColumns != NULL)
    *pcColumns = 0;
  if (prgInfo != NULL)
    *prgInfo = NULL;
  if (ppStringsBuffer != NULL)
    *ppStringsBuffer = NULL;

  ErrorCheck error(IID_IColumnsInfo, DISPID_IColumnsInfo_GetColumnInfo);

  CriticalSection critical_section(this);
  if (zombie)
    return ErrorInfo::Set(E_UNEXPECTED);
  if (pcColumns == NULL || prgInfo == NULL || ppStringsBuffer == NULL)
    return ErrorInfo::Set(E_INVALIDARG);

  const RowsetInfo* pRowsetInfo = NULL;
  HRESULT hr = GetRowsetInfo(pRowsetInfo);
  if (FAILED(hr))
    return hr;
  assert(pRowsetInfo != NULL);

  int cColumns = pRowsetInfo->GetFieldCount();
  if (cColumns == 0)
    return S_OK;

  int cHiddenColumns = pRowsetInfo->GetHiddenColumns();

  AutoRelease<DBCOLUMNINFO, ComMemFree> rgInfo((DBCOLUMNINFO*) CoTaskMemAlloc(cColumns * sizeof(DBCOLUMNINFO)));
  if (rgInfo == NULL)
    return ErrorInfo::Set(E_OUTOFMEMORY);

  int iColumn;
  size_t cwTotalLength = 0;

  for(iColumn = 0; iColumn < cColumns; iColumn++)
    {
      const ColumnInfo& columnInfo = pRowsetInfo->GetColumnInfo(iColumn);
      DBCOLUMNINFO& dbColumnInfo = rgInfo[iColumn];
      DBORDINAL iColumnOrdinal = pRowsetInfo->IndexToOrdinal(iColumn);

      dbColumnInfo.pwszName = NULL;
      dbColumnInfo.pTypeInfo = NULL;
      dbColumnInfo.iOrdinal = iColumnOrdinal;
      dbColumnInfo.dwFlags = columnInfo.GetFlags();
      dbColumnInfo.ulColumnSize = columnInfo.GetOledbSize();
      dbColumnInfo.wType = columnInfo.GetOledbType();
      dbColumnInfo.bPrecision = columnInfo.GetOledbPrecision();
      dbColumnInfo.bScale = columnInfo.GetOledbScale();
      if (iColumnOrdinal == 0)
	{
	  dbColumnInfo.columnid.eKind = DBKIND_GUID_PROPID;
	  dbColumnInfo.columnid.uGuid.guid = DBCOL_SPECIALCOL;
	  dbColumnInfo.columnid.uName.ulPropid = 2;
	}
      else
	{
	  const DBID* pdbid = columnInfo.GetDBID();
	  if (pdbid != NULL)
	    {
	      assert(pdbid->eKind == DBKIND_GUID_PROPID);
	      dbColumnInfo.columnid.eKind = pdbid->eKind;
	      dbColumnInfo.columnid.uGuid.guid = pdbid->uGuid.guid;
	      dbColumnInfo.columnid.uName.ulPropid = pdbid->uName.ulPropid;
	    }
	  else if (iColumn >= cColumns - cHiddenColumns)
	    {
	      dbColumnInfo.columnid.eKind = DBKIND_GUID_NAME;
	      dbColumnInfo.columnid.uGuid.guid = DBCOL_SPECIALCOL;
	      dbColumnInfo.columnid.uName.pwszName = NULL;
	    }
	  else
	    {
	      dbColumnInfo.columnid.eKind = DBKIND_NAME;
	      dbColumnInfo.columnid.uName.pwszName = NULL;
	    }

	  if (!columnInfo.GetName().empty())
	    cwTotalLength += (DBLENGTH)columnInfo.GetName().length() + 1;
	}
    }

  if (cwTotalLength == 0)
    {
      *pcColumns = cColumns;
      *prgInfo = rgInfo.GiveUp();
      return S_OK;
    }

  OLECHAR* pStringsBuffer = (OLECHAR*)CoTaskMemAlloc(cwTotalLength * sizeof(OLECHAR));
  if (pStringsBuffer == NULL)
    return ErrorInfo::Set(E_OUTOFMEMORY);

  OLECHAR* pwszName = pStringsBuffer;
  for (iColumn = 0; iColumn < cColumns; iColumn++)
    {
      const ColumnInfo& columnInfo = pRowsetInfo->GetColumnInfo(iColumn);
      DBCOLUMNINFO& dbColumnInfo = rgInfo[iColumn];
      if (!columnInfo.GetName().empty())
	{
	  wcscpy(pwszName, columnInfo.GetName().c_str());
	  dbColumnInfo.pwszName = pwszName;
	  if (columnInfo.GetDBID() == NULL)
	    dbColumnInfo.columnid.uName.pwszName = pwszName;
	  pwszName += columnInfo.GetName().length() + 1;
	}
      LOG (("CDataObj::GetColumnInfo()fld %d, pwszName=%S, ulColumnSize=%lu, wType=%d, bPrecision=%d, bScale=%d\n",
	    (int) iColumn,
	    dbColumnInfo.pwszName,
	    (unsigned long) dbColumnInfo.ulColumnSize,
	    (int) dbColumnInfo.wType,
	    (int) dbColumnInfo.bPrecision,
	    (int) dbColumnInfo.bScale));
    }

  *pcColumns = cColumns - cHiddenColumns;
  *prgInfo = rgInfo.GiveUp();
  *ppStringsBuffer = pStringsBuffer;

  return S_OK;
}

STDMETHODIMP
CDataObj::MapColumnIDs
(
  DBORDINAL cColumnIDs,
  const DBID rgColumnIDs[],
  DBORDINAL rgColumns[]
)
{
  LOGCALL(("CDataObj::MapColumnIDs()\n"));

  ErrorCheck error(IID_IColumnsInfo, DISPID_IColumnsInfo_MapColumnIDs);

  CriticalSection critical_section(this);
  if (zombie)
    {
      LOGCALL(("CDataObj::MapColumnIDs() zombie\n"));
      return ErrorInfo::Set(E_UNEXPECTED);
    }

  if (cColumnIDs == 0)
    {
      LOGCALL(("CDataObj::MapColumnIDs() col_id = 0\n"));
      return S_OK;
    }
  if (rgColumnIDs == NULL || rgColumns == NULL)
    {
      LOGCALL(("CDataObj::MapColumnIDs() no rgColsIDS or rgCols\n"));
      return ErrorInfo::Set(E_INVALIDARG);
    }

  const RowsetInfo* pRowsetInfo;
  HRESULT hr = GetRowsetInfo(pRowsetInfo);
  if (FAILED(hr))
    {
      LOGCALL(("CDataObj::MapColumnIDs() no rowsetinfo\n"));
      return hr;
    }
  assert(pRowsetInfo != NULL);

  bool success = false;
  bool failure = false;

  for (DBORDINAL iColumnID = 0; iColumnID < cColumnIDs; iColumnID++)
    {
      bool fFound = false;

      const DBID& id = rgColumnIDs[iColumnID];
      LOGCALL(("CDataObj::MapColumnIDs() col_id = %lu kind=%d name=%S\n", (unsigned long) iColumnID, (int) id.eKind, id.uName.pwszName));
      if ((id.eKind == DBKIND_NAME
	   || (id.eKind == DBKIND_GUID_NAME && id.uGuid.guid == DBCOL_SPECIALCOL)
	   || (id.eKind == DBKIND_PGUID_NAME && *id.uGuid.pguid == DBCOL_SPECIALCOL))
	  && id.uName.pwszName != NULL)
	{
	  for (ULONG iColumn = 0; iColumn < pRowsetInfo->GetFieldCount(); iColumn++)
	    {
	      const ColumnInfo& info = pRowsetInfo->GetColumnInfo(iColumn);
	      const DBID* pdbid = info.GetDBID();
	      if (pdbid == NULL && !info.GetName().empty() && info.GetName().compare(id.uName.pwszName) == 0)
		{
		  rgColumns[iColumnID] = pRowsetInfo->IndexToOrdinal(iColumn);
		  fFound = true;
		  break;
		}
	    }
	}
      else if (id.eKind == DBKIND_GUID_PROPID || id.eKind == DBKIND_PGUID_PROPID)
	{
	  const GUID& guid = id.eKind == DBKIND_GUID_PROPID ? id.uGuid.guid : *id.uGuid.pguid;
	  if (guid == DBCOL_SPECIALCOL && id.uName.ulPropid == 2 && pRowsetInfo->HasBookmark())
	    {
	      rgColumns[iColumnID] = 0;
	      fFound = true;
	    }
	  else
	    {
	      for (DBORDINAL iColumn = 0; iColumn < pRowsetInfo->GetFieldCount(); iColumn++)
		{
		  const ColumnInfo& info = pRowsetInfo->GetColumnInfo(iColumn);
		  const DBID* pdbid = info.GetDBID();
		  if (pdbid != NULL)
		    {
		      assert(pdbid->eKind == DBKIND_GUID_PROPID);
		      if (pdbid->uGuid.guid == guid && pdbid->uName.ulPropid == id.uName.ulPropid)
			{
			  rgColumns[iColumnID] = pRowsetInfo->IndexToOrdinal(iColumn);
			  fFound = true;
			  break;
			}
		    }
		}
	    }
	}

      if (fFound)
	success = true;
      else
	{
	  rgColumns[iColumnID] = DB_INVALIDCOLUMN;
	  failure = true;
	}
      LOG(("CDataObj::MapColumnIDs() col_id = %lu Found=%d\n", (unsigned long) iColumnID, (int) fFound));
    }

  LOG(("CDataObj::MapColumnIDs() finished\n"));
  return failure ? success ? DB_S_ERRORSOCCURRED : DB_E_ERRORSOCCURRED : S_OK;
}

/**********************************************************************/
/* IColumnsRowset                                                     */

STDMETHODIMP
CDataObj::GetAvailableColumns
(
  DBORDINAL* pcOptColumns,
  DBID** prgOptColumns
)
{
  LOGCALL(("CDataObj::GetAvailableColumns()\n"));

  if (pcOptColumns != NULL)
    *pcOptColumns = 0;
  if (prgOptColumns != NULL)
    *prgOptColumns = NULL;

  ErrorCheck error(IID_IColumnsRowset, DISPID_IColumnsRowset_GetAvailableColumns);

  CriticalSection critical_section(this);
  if (zombie)
    return ErrorInfo::Set(E_UNEXPECTED);
  if (pcOptColumns == NULL || prgOptColumns == NULL)
    return ErrorInfo::Set(E_INVALIDARG);

  DBORDINAL cOptColumns = RowsetInfo::GetOptionalMetaColumns();
  if (cOptColumns == 0)
    return S_OK;

  DBID* rgOptColumns = (DBID*) CoTaskMemAlloc(cOptColumns * sizeof(DBID));
  if (rgOptColumns == NULL)
    return ErrorInfo::Set(E_OUTOFMEMORY);

  RowsetInfo::GetOptionalMetaColumnIDs(rgOptColumns);
  *pcOptColumns = cOptColumns;
  *prgOptColumns = rgOptColumns;
  return S_OK;
}

STDMETHODIMP
CDataObj::GetColumnsRowset
(
  IUnknown* pUnkOuter,
  DBORDINAL cOptColumns,
  const DBID rgOptColumns[],
  REFIID riid,
  ULONG cPropertySets,
  DBPROPSET rgPropertySets[],
  IUnknown** ppColRowset
)
{
  LOGCALL(("CDataObj::GetColumnsRowset()\n"));

  if (ppColRowset != NULL)
    *ppColRowset = NULL;

  ErrorCheck error(IID_IColumnsRowset, DISPID_IColumnsRowset_GetColumnsRowset);

  CriticalSection critical_section(this);
  if (zombie)
    return ErrorInfo::Set(E_UNEXPECTED);
  if (ppColRowset == NULL)
    return ErrorInfo::Set(E_INVALIDARG);
  if (cOptColumns != 0 && rgOptColumns == NULL)
    return ErrorInfo::Set(E_INVALIDARG);
  if (pUnkOuter != NULL && riid != IID_IUnknown)
    return ErrorInfo::Set(DB_E_NOAGGREGATION);

  const RowsetInfo* pRowsetInfo;
  HRESULT hr = GetRowsetInfo(pRowsetInfo);
  if (FAILED(hr))
    return hr;
  assert(pRowsetInfo != NULL);

  CRowsetColumnsInitializer initializer (
    this, pRowsetInfo, cOptColumns, rgOptColumns, riid, cPropertySets, rgPropertySets
  );
  hr = ComAggregateObj<CRowset>::CreateInstance (pUnkOuter, riid, (void**) ppColRowset, &initializer);
  if (FAILED(hr))
    return hr;

  return initializer.hr; // Could be S_OK or DB_S_ERRORSOCCURED
}

/**********************************************************************/
/* CImpIConvertType                                                   */

STDMETHODIMP
CDataObj::CanConvert
(
  DBTYPE wFromType,
  DBTYPE wToType,
  DBCONVERTFLAGS dwConvertFlags
)
{
  LOGCALL(("CDataObj::CanConvert()\n"));

  ErrorCheck error(IID_IConvertType, DISPID_IConvertType_CanConvert);

  if (zombie)
    return ErrorInfo::Set(E_UNEXPECTED);

  return m_dth.CanConvert(wFromType, wToType, dwConvertFlags, IsCommand());
}

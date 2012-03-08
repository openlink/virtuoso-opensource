/*  error.h
 *
 *  $Id$
 *  
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *  
 *  Copyright (C) 1998-2012 OpenLink Software
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

#ifndef ERROR_H
#define ERROR_H


#include "baseobj.h"
#include "syncobj.h"


enum
{
  DISPID_Unknown,
  DISPID_IDBInitialize_Initialize,
  DISPID_IDBInitialize_Uninitialize,
  DISPID_IDBProperties_GetProperties,
  DISPID_IDBProperties_GetPropertyInfo,
  DISPID_IDBProperties_SetProperties,
  DISPID_IDBCreateSession_CreateSession,
  DISPID_IOpenRowset_OpenRowset,
  DISPID_ISessionProperties_GetProperties,
  DISPID_ISessionProperties_SetProperties,
  DISPID_IDBCreateCommand_CreateCommand,
  DISPID_IDBSchemaRowset_GetRowset,
  DISPID_IDBSchemaRowset_GetSchemas,
  DISPID_ITableDefinition_AddColumn,
  DISPID_ITableDefinition_CreateTable,
  DISPID_ITableDefinition_DropColumn,
  DISPID_ITableDefinition_DropTable,
  DISPID_ITransaction_Abort,
  DISPID_ITransaction_Commit,
  DISPID_ITransaction_GetTransactionInfo,
  DISPID_ITransactionJoin_GetOptionsObject,
  DISPID_ITransactionJoin_JoinTransaction,
  DISPID_ITransactionLocal_GetOptionsObject,
  DISPID_ITransactionLocal_StartTransaction,
  DISPID_IAccessor_AddRefAccessor,
  DISPID_IAccessor_CreateAccessor,
  DISPID_IAccessor_GetBindings,
  DISPID_IAccessor_ReleaseAccessor,
  DISPID_IColumnsInfo_GetColumnInfo,
  DISPID_IColumnsInfo_MapColumnIDs,
  DISPID_IColumnsRowset_GetAvailableColumns,
  DISPID_IColumnsRowset_GetColumnsRowset,
  DISPID_IConvertType_CanConvert,
  DISPID_ICommandPrepare_Prepare,
  DISPID_ICommandPrepare_Unprepare,
  DISPID_ICommandProperties_GetProperties,
  DISPID_ICommandProperties_SetProperties,
  DISPID_ICommand_Cancel,
  DISPID_ICommand_Execute,
  DISPID_ICommand_GetDBSession,
  DISPID_ICommandText_GetCommandText,
  DISPID_ICommandText_SetCommandText,
  DISPID_ICommandWithParameters_GetParameterInfo,
  DISPID_ICommandWithParameters_MapParameterNames,
  DISPID_ICommandWithParameters_SetParameterInfo,
  DISPID_IMultipleResults_GetResult,
  DISPID_IRowset_AddRefRows,
  DISPID_IRowset_GetData,
  DISPID_IRowset_GetNextRows,
  DISPID_IRowset_ReleaseRows,
  DISPID_IRowset_RestartPosition,
  DISPID_IRowsetIdentity_IsSameRow,
  DISPID_IRowsetInfo_GetProperties,
  DISPID_IRowsetInfo_GetReferencedRowset,
  DISPID_IRowsetInfo_GetSpecification,
  DISPID_IRowsetChange_DeleteRows,
  DISPID_IRowsetChange_InsertRow,
  DISPID_IRowsetChange_SetData,
  DISPID_IRowsetLocate_Compare,
  DISPID_IRowsetLocate_GetRowsAt,
  DISPID_IRowsetLocate_GetRowsByBookmark,
  DISPID_IRowsetLocate_Hash,
  DISPID_IRowsetRefresh_GetLastVisibleData,
  DISPID_IRowsetRefresh_RefreshVisibleData,
  DISPID_IRowsetResynch_GetVisibleData,
  DISPID_IRowsetResynch_ResynchRows,
  DISPID_IRowsetScroll_GetApproximatePosition,
  DISPID_IRowsetScroll_GetRowsAtRatio,
  DISPID_IRowsetUpdate_GetOriginalData,
  DISPID_IRowsetUpdate_GetPendingRows,
  DISPID_IRowsetUpdate_GetRowStatus,
  DISPID_IRowsetUpdate_Undo,
  DISPID_IRowsetUpdate_Update,
};


// LookupIDs
enum
{
  LID_Unknown,
  LID_DynamicErrorBase,
};


class ErrorInfo
{
public:

  static HRESULT Init();
  static void Fini();

  static ErrorInfo* Get();
  static HRESULT Set(HRESULT hrError, DWORD dwLookupId = IDENTIFIER_SDK_ERROR);
  static HRESULT Set(HRESULT hrError, const std::string& description);
  static HRESULT Set(HRESULT hrError, SQLSMALLINT handleType, SQLHANDLE handle);

  static void Allow();
  static void Check(REFIID riid, DISPID dispid);
  static void Clear();

  static HRESULT GetDynamicError(DWORD dwLookupId, BSTR* pbstrDescription);
  static HRESULT ReleaseErrors(DWORD dwDynamicErrorId);

  ~ErrorInfo();

  void Post(REFIID riid, DISPID dispid);

  HRESULT
  GetErrorCode()
  {
    return m_hrError;
  }

  DWORD
  GetLookupId(DWORD dwLookupId)
  {
    return m_dwLookupId;
  }

  DWORD
  GetDynamicErrorId()
  {
    return m_dwDynamicErrorId;
  }

  ErrorInfo*
  GetNext()
  {
    return m_pNext;
  }

private:

  // ErrorInfo creation is only allowed with IErrorInfo::Create()
  ErrorInfo(HRESULT hrError, DWORD dwLookupId, DWORD dwDynamicErrorId, ErrorInfo* pNext);

  static ErrorInfo* InternalSet(HRESULT hrError, DWORD dwLookupId, DWORD dwDynamicErrorId, ErrorInfo* pNext);

  typedef std::map<LONG, std::string> DynamicLookupMap;
  typedef std::multimap<LONG, LONG> DynamicReleaseMap;

#if GLOBAL_ERROR_FACTORY
  // Global factory doesn't work. That is it causes GPF at times. Looks
  // like cross-appartment call issues or something. Perhaps it could
  // be put into GIT but it is not worth the trouble.
  static IClassFactory* m_pErrorObjectFactory;
#endif

  static DynamicLookupMap m_dynamicLookupMap;
  static DynamicReleaseMap m_dynamicReleaseMap;
  static LONG m_dwLastLookupID;
  static LONG m_dwLastDynamicID;
  static SyncObj m_sync;

  HRESULT m_hrError;
  DWORD m_dwLookupId;
  DWORD m_dwDynamicErrorId;
  ErrorInfo* m_pNext;
};


class ErrorCheck
{
public:

  ErrorCheck(REFIID riid, DISPID dispid)
    : m_riid(riid), m_dispid(dispid)
  {
    ErrorInfo::Allow();
  }

  ~ErrorCheck()
  {
    ErrorInfo::Check(m_riid, m_dispid);
  }

private:

  REFIID m_riid;
  DISPID m_dispid;
};


class NOVTABLE CErrorLookup : public IErrorLookup, public ComObjBase
{
public:

  CErrorLookup()
  {
    LOGCALL(("CErrorLookup::CErrorLookup()\n"));

    m_pUnkFTM = NULL;
  }

  ~CErrorLookup()
  {
    LOGCALL(("CErrorLookup::~CErrorLookup()\n"));
  }
  
  HRESULT
  Initialize (void*)
  {
    return S_OK;
  }

  void
  Delete()
  {
    if (m_pUnkFTM != NULL)
      {
	m_pUnkFTM->Release();
	m_pUnkFTM = NULL;
      }
  }

  virtual HRESULT GetInterface(REFIID riid, IUnknown** ppUnknown);

  // IErrorLookup members

  STDMETHODIMP GetErrorDescription
  (
    HRESULT hrError,
    DWORD dwLookupID,
    DISPPARAMS* pdipsparams,
    LCID lcid,
    BSTR* pbstrSource,
    BSTR* pbstrDescription
  );

  STDMETHODIMP GetHelpInfo
  (
    HRESULT hrError,
    DWORD dwLookupID,
    LCID lcid,
    BSTR* pbstrHelpFile,
    DWORD* pdwHelpContext
  );

  STDMETHODIMP ReleaseErrors
  (
    const DWORD dwDynamicErrorId
  );

private:

  IUnknown* m_pUnkFTM;
};


template<class T>
class ISupportErrorInfoImpl : public ISupportErrorInfo
{
public:

  STDMETHODIMP
  InterfaceSupportsErrorInfo(REFIID riid)
  {
    const IID** rgpIIDs = static_cast<T*>(this)->GetSupportErrorInfoIIDs();
    for (int i = 0; rgpIIDs[i]; i++)
      if (riid == *rgpIIDs[i])
	return S_OK;
    return S_FALSE;
  }
};

#endif

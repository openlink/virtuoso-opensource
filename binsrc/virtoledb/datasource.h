/*  datasource.h
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

#ifndef DATASOURCE_H
#define DATASOURCE_H

#include "baseobj.h"
#include "syncobj.h"
#include "properties.h"
#include "db.h"
#include "error.h"


class DBInitPropertySet;
class VirtDBInitPropertySet;
class DataSourcePropertySet;
class DataSourceInfoPropertySet;


class NOVTABLE CDataSource :
  public IDBInitialize,
  public IDBProperties,
  public IDBCreateSession,
  public IDBInfo,
  public IPersistFile,
  public IServiceProvider,
  public ISpecifyPropertyPages,
  public ISupportErrorInfoImpl<CDataSource>,
  public ComObjBase,
  public SyncObj,
  public PropertySuperset
{
public:

  CDataSource();
  ~CDataSource();

  HRESULT Initialize (void*);

  void Delete();

  virtual HRESULT GetInterface(REFIID riid, IUnknown** ppUnknown);

  const IID** GetSupportErrorInfoIIDs();

  void IncrementSessionCount();
  void DecrementSessionCount();

  HRESULT InitConnection(Connection &connection);

  HRESULT
  GetActiveSessions(LONG& value)
  {
    return m_connection_pool.GetActiveSessions(value);
  }

  HRESULT
  GetCurrentCatalog(std::string& catalog) const
  {
    return m_connection_pool.GetCurrentCatalog(catalog);
  }

  HRESULT
  SetCurrentCatalog(const std::string& catalog)
  {
    return m_connection_pool.SetCurrentCatalog(catalog);
  }

  HRESULT GetDataSourceName(BSTR& value) const;

  HRESULT
  GetDBMSName(std::string& value)
  {
    return m_connection_pool.GetDBMSName(value);
  }

  HRESULT
  GetDBMSVer(std::string& value)
  {
    return m_connection_pool.GetDBMSVer(value);
  }

  HRESULT
  GetIdentifierCase(LONG& value)
  {
    return m_connection_pool.GetIdentifierCase(value);
  }

  HRESULT
  GetServerName(std::string& value)
  {
    return m_connection_pool.GetServerName(value);
  }

  HRESULT GetUserName(BSTR& value) const;

  HRESULT GetNoSysTables (VARIANT_BOOL& value) const;

  // IDBInitialize members

  STDMETHODIMP Initialize();
  STDMETHODIMP Uninitialize();

  // IDBProperties members

  STDMETHODIMP GetProperties(
    ULONG cPropertyIDSets,
    const DBPROPIDSET rgPropertyIDSets[],
    ULONG *pcPropertySets,
    DBPROPSET **prgPropertySets
  );

  STDMETHODIMP GetPropertyInfo(
    ULONG cPropertyIDSets,
    const DBPROPIDSET rgPropertyIDSets[],
    ULONG *pcPropertyInfoSets,
    DBPROPINFOSET **prgPropertyInfoSets,
    OLECHAR **ppDescBuffer
  );

  STDMETHODIMP SetProperties(
    ULONG cPropertySets,
    DBPROPSET rgPropertySets[]
  );

  // IDBCreateSession members

  STDMETHODIMP CreateSession(
    IUnknown *pUnkOuter,
    REFIID riid,
    IUnknown **ppDBSession
  );

  // IDBInfo members

  STDMETHODIMP GetKeywords(
    LPOLESTR *ppwszKeywords
  );

  STDMETHODIMP GetLiteralInfo(
    ULONG cLiterals,
    const DBLITERAL rgLiterals[],
    ULONG *pcLiteralInfo,
    DBLITERALINFO **prgLiteralInfo,
    OLECHAR **ppCharBuffer
  );

  // IPersist members

  STDMETHODIMP GetClassID(
    CLSID* pClassID
  );

  // IPersistFile members

  STDMETHODIMP IsDirty();

  STDMETHODIMP Load(
    LPCOLESTR pszFileName,
    DWORD dwMode
  );

  STDMETHODIMP Save(
    LPCOLESTR pszFileName,
    BOOL fRemember
  );

  STDMETHODIMP SaveCompleted(
    LPCOLESTR pszFileName
  );

  STDMETHODIMP GetCurFile(
    LPOLESTR *ppszFileName
  );

  // IServiceProvider members

  STDMETHODIMP QueryService(
    REFGUID guidService,
    REFIID riid,
    void** ppvObject
  );

  // ISpecifyPropertyPages members

  STDMETHODIMP GetPages(
    CAUUID* pPages
  );

protected:

  virtual ULONG GetPropertySetCount();
  virtual PropertySet* GetPropertySet(ULONG iPropertySet);
  virtual PropertySet* GetPropertySet(REFGUID rguidPropertySet);

private:

  enum ds_state_t
  {
    S_Uninitialized,
    S_Initialized
  };

  ds_state_t m_state;

  bool m_fIsDirty;
  LPOLESTR m_pszFileName;

  PropertySetInfoRepository m_info;
  DBInitPropertySet* m_pDBInitPropertySet;
  VirtDBInitPropertySet* m_pVirtDBInitPropertySet;
  DataSourcePropertySet* m_pDataSourcePropertySet;
  DataSourceInfoPropertySet* m_pDataSourceInfoPropertySet;

  long m_sessions;
  Environment m_environment;
  ConnectionPool m_connection_pool;

  IUnknown* m_pUnkFTM;
};


#endif

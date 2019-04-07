/*  session.h
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

#ifndef SESSION_H
#define SESSION_H

#include "baseobj.h"
#include "syncobj.h"
#include "properties.h"
#include "db.h"
#include "error.h"


class CDataSource;
class CRowset;
class SessionPropertySet;
class Connection;


struct SchemaParam
{
  SQLSMALLINT wSqlType;
  ULONG iRestriction;
};


struct SchemaColumn
{
  wchar_t* pwszName;
  DBTYPE wOledbType;
  ULONG dwColumnSize;
  bool fMaybeNull;
};


struct Schema
{
  const GUID* pguidSchema;
  ULONG cRestrictions;
  ULONG ulRestrictionSupport;
  const char* szQuery;
  DBORDINAL cParams;
  SchemaParam* rgParams;
  ULONG cColumns;
  SchemaColumn* rgColumns;
};


class NOVTABLE CSession :
  public IGetDataSource,
  public IOpenRowset,
  public ISessionProperties,
  public IDBCreateCommand,
  public IDBSchemaRowset,
  public ITableDefinition,
  public ITransactionJoin,
  public ITransactionLocal,
  public ISupportErrorInfoImpl<CSession>,
  public ComObjBase,
  public SyncObj,
  public PropertySuperset
{
public:

  CSession();
  ~CSession();

  HRESULT Initialize (CDataSource* pDataSource);

  void Delete();

  virtual HRESULT GetInterface(REFIID riid, IUnknown** ppUnknown);

  const IID** GetSupportErrorInfoIIDs();

  HRESULT AddRowset(CRowset* rowset);
  void RemoveRowset(CRowset* rowset);

  const Connection&
  GetConnection()
  {
    return m_connection;
  }

  // IGetDataSource members

  STDMETHODIMP GetDataSource (
    REFIID riid,
    IUnknown **ppDataSource
  );

  // IOpenRowset members

  STDMETHODIMP OpenRowset (
    IUnknown *pUnkOuter,
    DBID *pTableID,
    DBID *pIndexID,
    REFIID riid,
    ULONG cPropertySets,
    DBPROPSET rgPropertySets[],
    IUnknown **ppRowset
  );

  // ISessionProperties members

  STDMETHODIMP GetProperties (
    ULONG cPropertyIDSets,
    const DBPROPIDSET rgPropertyIDSets[],
    ULONG *pcPropertySets,
    DBPROPSET **prgPropertySets
  );

  STDMETHODIMP SetProperties (
    ULONG cPropertySets,
    DBPROPSET rgPropertySets[]
  );

  // IDBCreateCommand members

  STDMETHODIMP CreateCommand (
    IUnknown *pUnkOuter,
    REFIID riid,
    IUnknown **ppCommand
  );

  // IDBSchemaRowset members

  STDMETHODIMP GetRowset (
    IUnknown *pUnkOuter,
    REFGUID rguidSchema,
    ULONG cRestrictions,
    const VARIANT rgRestrictions[],
    REFIID riid,
    ULONG cPropertySets,
    DBPROPSET rgPropertySets[],
    IUnknown **ppRowset
  );

  STDMETHODIMP GetSchemas (
    ULONG *pcSchemas,
    GUID **prgSchemas,
    ULONG **prgRestrictionSupport
  );

  // ITableDefinition members

  STDMETHODIMP AddColumn (
    DBID *pTableID,
    DBCOLUMNDESC *pColumnDesc,
    DBID **ppColumnID
  );

  STDMETHODIMP CreateTable (
    IUnknown *pUnkOuter,
    DBID *pTableID,
    DBORDINAL cColumnDescs,
    const DBCOLUMNDESC rgColumnDescs[],
    REFIID riid,
    ULONG cPropertySets,
    DBPROPSET rgPropertySet[],
    DBID **ppTableID,
    IUnknown **ppRowset
  );

  STDMETHODIMP DropColumn (
    DBID *pTableID,
    DBID *pColumnID
  );

  STDMETHODIMP DropTable (
    DBID *pTableID
  );

  // ITransaction members

  STDMETHODIMP Abort (
    BOID *pboidReason,
    BOOL fRetaining,
    BOOL fAsync
  );

  STDMETHODIMP Commit (
    BOOL fRetaining,
    DWORD grfTC,
    DWORD grfRM
  );

  STDMETHODIMP GetTransactionInfo (
    XACTTRANSINFO *pinfo
  );

  // ITransacrionJoin members

  STDMETHODIMP GetOptionsObject (
    ITransactionOptions **ppOptions
  );

  STDMETHODIMP JoinTransaction (
    IUnknown* pUnkTransactionCoord,
    ISOLEVEL isoLevel,
    ULONG isoFlags,
    ITransactionOptions *pOtherOptions
  );

  // ITransactionLocal members

  //STDMETHODIMP GetOptionsObject (
  //  ITransactionOptions **ppOptions
  //);

  STDMETHODIMP StartTransaction (
    ISOLEVEL isoLevel,
    ULONG isoFlags,
    ITransactionOptions *pOtherOptions,
    ULONG *pulTransactionLevel
  );

protected:

  virtual ULONG GetPropertySetCount();
  virtual PropertySet* GetPropertySet(ULONG iPropertySet);
  virtual PropertySet* GetPropertySet(REFGUID rguidPropertySet);

private:

  enum XACTSTATE
  {
    XACT_NONE,
    XACT_LOCAL,
    XACT_DISTRIBUTED
  };

  HRESULT EndTransaction(bool commit, bool retain);

  typedef std::list<CRowset*> RowsetList;
  typedef RowsetList::iterator RowsetIter;

  CDataSource* m_pDataSource;
  SessionPropertySet* m_pSessionPropertySet;
  Connection m_connection;
  XACTSTATE m_xactState;
  ISOLEVEL m_isoLevel;
  XACTUOW m_uow;
  RowsetList m_rowsets;
  IUnknown* m_pUnkFTM;
  int m_nTrxLevel;
};


#endif

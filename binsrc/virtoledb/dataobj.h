/*  dataobj.h
 *
 *  $Id$
 *
 *  Base class for Command and Rowset objects.
 *  
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *  
 *  Copyright (C) 1998-2015 OpenLink Software
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

#ifndef DATAOBJ_H
#define DATAOBJ_H

#include "baseobj.h"
#include "syncobj.h"
#include "properties.h"
#include "data.h"


class CSession;
class RowsetPropertySet;
class RowsetInfo;


typedef std::map<long, DataAccessor> AccessorMap;
typedef AccessorMap::iterator AccessorIterator;


class CDataObj :
  public IAccessor,
  public IColumnsInfo,
  public IColumnsRowset,
  public IConvertType,
  public ComObjBase,
  public SyncObj,
  public PropertySuperset
{
public:

  CDataObj();
  virtual ~CDataObj();

  HRESULT Init(CSession* pSession, RowsetPropertySet* rps);

  CSession*
  GetSession()
  {
    return m_pSession;
  }

  virtual bool IsCommand() const = 0;
  virtual bool IsChangeableRowset() const;

  virtual HRESULT GetRowsetInfo(const RowsetInfo*& rowset_info) const = 0;

  HRESULT CreateAccessor
  (
    DBACCESSORFLAGS dwAccessorFlags,
    DBCOUNTITEM cBindings,
    const DBBINDING rgBindings[],
    DBLENGTH cbRowSize,
    HACCESSOR* phAccessor
  );

  /* AcquireAccessor() looks for an accessor with the specified handle.
     If found returns iterator that could be used to obtain ``Accessor''
     structure. To prevent removal of the accessor by a concurrent thread
     this method increments accessor's reference count. Therefore each
     AcquireAccessor() should be complemented by ReleaseAccessor(). */
  AccessorIterator AcquireAccessor(HACCESSOR hAccessor);
  void ReleaseAccessor(AccessorIterator& iterator);
  DataAccessor& GetAccessor(AccessorIterator& iterator);
  AccessorIterator EndAccessor();

  HRESULT CopyRowAccessors(const CDataObj* data_obj);

  class AutoReleaseAccessor
  {
  public:

    AutoReleaseAccessor(CDataObj* pObject, HACCESSOR hAccessor)
    {
      assert(pObject != NULL);
      m_pObject = pObject;
      m_iterator = pObject->AcquireAccessor(hAccessor);
    }

    ~AutoReleaseAccessor()
    {
      Release();
    }

    void
    Release()
    {
      if (m_iterator != m_pObject->EndAccessor())
	{
	  m_pObject->ReleaseAccessor(m_iterator);
	  m_iterator = m_pObject->EndAccessor();
	}
    }

    operator AccessorIterator&()
    {
      return m_iterator;
    }

    bool
    operator ==(AccessorIterator iterator)
    {
      return m_iterator == iterator;
    }

  private:

    CDataObj* m_pObject;
    AccessorIterator m_iterator;
  };

protected:

  virtual ULONG GetPropertySetCount();
  virtual PropertySet* GetPropertySet(ULONG iPropertySet);
  virtual PropertySet* GetPropertySet(REFGUID rguidPropertySet);

  bool zombie;
  DataTransferHandler m_dth;
  RowsetPropertySet* rowset_property_set;

private:

  CSession* m_pSession;

  void RemoveAccessor(AccessorIterator iterator);

  AccessorMap accessors;
  long last_accessor_handle;

public:

  // IAccessor members

  STDMETHODIMP AddRefAccessor
  (
    HACCESSOR hAccessor,
    DBREFCOUNT *pcRefCount
  );

  STDMETHODIMP CreateAccessor
  (
    DBACCESSORFLAGS dwAccessorFlags,
    DBCOUNTITEM cBindings,
    const DBBINDING rgBindings[],
    DBLENGTH cbRowSize,
    HACCESSOR *phAccessor,
    DBBINDSTATUS rgStatus[]
  );

  STDMETHODIMP GetBindings
  (
    HACCESSOR hAccessor,
    DBACCESSORFLAGS *pwdAccessorFlags,
    DBCOUNTITEM *pcBindings,
    DBBINDING **prgBindings
  );

  STDMETHODIMP ReleaseAccessor
  (
    HACCESSOR hAccessor,
    DBREFCOUNT *pcRefCount
  );

  // IColumnsInfo members

  STDMETHODIMP GetColumnInfo
  (
    DBORDINAL *pcColumns,
    DBCOLUMNINFO **prgInfo,
    OLECHAR **ppStringsBuffer
  );

  STDMETHODIMP MapColumnIDs
  (
    DBORDINAL cColumnIDs,
    const DBID rgColumnIDs[],
    DBORDINAL rgColumns[]
  );

  // IColumnsRowset members

  STDMETHODIMP GetAvailableColumns
  (
    DBORDINAL* pcOptColumns,
    DBID** prgOptColumns
  );

  STDMETHODIMP GetColumnsRowset
  (
    IUnknown* pUnkOuter,
    DBORDINAL cOptColumns,
    const DBID rgOptColumns[],
    REFIID riid,
    ULONG cPropertySets,
    DBPROPSET rgPropertySets[],
    IUnknown** ppColRowset
  );

  // IConvertType members

  STDMETHODIMP CanConvert
  (
    DBTYPE wFromType,
    DBTYPE wToType,
    DBCONVERTFLAGS dwConvertFlags
  );
};


#endif

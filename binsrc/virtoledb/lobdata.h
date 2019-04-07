/*  lobdata.h
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

#ifndef LOBDATA_H
#define LOBDATA_H


#include "baseobj.h"
#include "data.h"
#include "error.h"


// This sync object is to be used for synchronization with SequentialStream object.
class LobStreamSyncObj : public SyncObj
{
public:

  LobStreamSyncObj()
  {
    m_fIsRowsetAlive = false;
    m_fIsStreamAlive = false;
  }

  bool
  IsRowsetAlive()
  {
    return m_fIsRowsetAlive;
  }

  bool
  IsStreamAlive()
  {
    return m_fIsStreamAlive;
  }

  void
  SetRowsetStatus(bool fIsRowsetAlive)
  {
    m_fIsRowsetAlive = fIsRowsetAlive;
    if (!m_fIsRowsetAlive && !m_fIsStreamAlive)
      delete this;
  }

  void
  SetStreamStatus(bool fIsStreamAlive)
  {
    m_fIsStreamAlive = fIsStreamAlive;
    if (!m_fIsRowsetAlive && !m_fIsStreamAlive)
      delete this;
  }

private:

  bool m_fIsRowsetAlive;
  bool m_fIsStreamAlive;
};


struct CGetDataSequentialStreamInitializer
{
  LobStreamSyncObj* pStreamSync;
  GetDataHandler* pgd;
  HROW iRecordID;
  DBORDINAL iFieldOrdinal;
  SQLSMALLINT wSqlCType;
};

class NOVTABLE CGetDataSequentialStream :
  public ISequentialStream,
  public ISupportErrorInfoImpl<CGetDataSequentialStream>,
  public ComObjBase
{
public:

  CGetDataSequentialStream();
  ~CGetDataSequentialStream();

  HRESULT Initialize (CGetDataSequentialStreamInitializer* pInitializer);

  void Delete();

  virtual HRESULT GetInterface(REFIID riid, IUnknown** ppUnknown);

  const IID** GetSupportErrorInfoIIDs();

  HRESULT Init(LobStreamSyncObj* pStreramSync, GetDataHandler* pgd,
	       HROW iRecordID, DBORDINAL iFieldOrdinal, SQLSMALLINT wSqlCType);

  void Kill();

  // ISequentialStream members

  STDMETHODIMP Read
  (
    void* pv,
    ULONG cb,
    ULONG* pcbRead
  );

  STDMETHODIMP Write
  (
    void const* pv,
    ULONG cb,
    ULONG* pcbWritten
  );

private:

  enum StreamStatus
  {
    STATUS_UNINITIALIZED,
    STATUS_INITIALIZED,
    STATUS_INPROGRESS,
    STATUS_FINISHED,
    STATUS_ZOMBIE
  };

  StreamStatus m_status;
  LobStreamSyncObj* m_pStreamSync;
  GetDataHandler* m_pgd;
  HROW m_iRecordID;
  DBORDINAL m_iFieldOrdinal;
  SQLSMALLINT m_wSqlCType;
  IUnknown* m_pUnkFTM;
};


#endif

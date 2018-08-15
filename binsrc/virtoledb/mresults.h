/*  mresults.h
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

#ifndef MRESULTS_H
#define MRESULTS_H

#include "baseobj.h"
#include "syncobj.h"
#include "error.h"


class CommandHandler;


class NOVTABLE CMultipleResults :
  public IMultipleResults,
  public ISupportErrorInfoImpl<CMultipleResults>,
  public ComObjBase,
  public SyncObj
{
public:

  CMultipleResults()
  {
    LOGCALL(("CMultipleResults::CMultipleResults()\n"));

    m_pCommandHandler = NULL;
    m_pUnkFTM = NULL;
  }

  ~CMultipleResults()
  {
    LOGCALL(("CMultipleResults::~CMultipleResults()\n"));
  }
  
  HRESULT
  Initialize (CommandHandler* pCommandHandler)
  {
    assert (pCommandHandler != NULL);
    m_pCommandHandler = pCommandHandler;
    return S_OK;
  }

  void Delete();

  virtual HRESULT GetInterface(REFIID riid, IUnknown** ppUnknown);

  const IID** GetSupportErrorInfoIIDs();

  // IMultipleResults members

  STDMETHODIMP GetResult
  (
    IUnknown* pUnkOuter,
    DBRESULTFLAG lResultFlag,
    REFIID riid,
    DBROWCOUNT* pcRowsAffected,
    IUnknown** ppRowset
  );

private:

  CommandHandler* m_pCommandHandler;
  IUnknown* m_pUnkFTM;
};


#endif

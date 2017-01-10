/*  mresults.cpp
 *
 *  $Id$
 *  
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *  
 *  Copyright (C) 1998-2017 OpenLink Software
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
#include "mresults.h"

/**********************************************************************/
/* CMultipleResults                                                   */

void
CMultipleResults::Delete()
{
  if (m_pCommandHandler != NULL)
    {
      m_pCommandHandler->MultipleResultsCloseNotify();
    }
  if (m_pUnkFTM != NULL)
    {
      m_pUnkFTM->Release();
      m_pUnkFTM = NULL;
    }
}

HRESULT
CMultipleResults::GetInterface(REFIID riid, IUnknown** ppUnknown)
{
  LOGCALL (("CMultipleResults::GetInterface(%s)\n", STRINGFROMGUID (riid)));

  IUnknown* pUnknown = NULL;
  if (riid == IID_IMultipleResults)
    pUnknown = static_cast<IMultipleResults*>(this);
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
CMultipleResults::GetSupportErrorInfoIIDs()
{
  static const IID* rgpIIDs[] =
  {
    &IID_IMultipleResults,
    NULL
  };

  return rgpIIDs;
}

/**********************************************************************/
/* IMultipleResults                                                   */

STDMETHODIMP
CMultipleResults::GetResult
(
  IUnknown* pUnkOuter,
  DBRESULTFLAG lResultFlag,
  REFIID riid,
  DBROWCOUNT* pcRowsAffected,
  IUnknown** ppRowset
)
{
  LOGCALL(("CMultipleResults::GetResult()\n"));

  ErrorCheck error(IID_IMultipleResults, DISPID_IMultipleResults_GetResult);

  if (pcRowsAffected != NULL)
    *pcRowsAffected = DB_COUNTUNAVAILABLE;
  if (ppRowset != NULL)
    *ppRowset = NULL;

  if (pUnkOuter != NULL && riid != IID_IUnknown)
    return ErrorInfo::Set(DB_E_NOAGGREGATION);
  if (lResultFlag != DBRESULTFLAG_DEFAULT && lResultFlag != DBRESULTFLAG_ROWSET)
    return ErrorInfo::Set(E_INVALIDARG);
#if 0
  if (riid != IID_NULL && ppRowset == NULL)
    return ErrorInfo::Set(E_INVALIDARG);
#endif

  return m_pCommandHandler->GetResult(pUnkOuter, riid, pcRowsAffected, ppRowset);
}

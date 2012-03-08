/*  command.cpp
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

#include "headers.h"
#include "asserts.h"
#include "command.h"
#include "session.h"
#include "mresults.h"
#include "rowset.h"
#include "rowsetprops.h"
#include "util.h"

/**********************************************************************/
/* CommandHandler                                                     */

CommandHandler::CommandHandler()
{
  LOGCALL(("CommandHandler::CommandHandler()\n"));

  m_state = S_Uninitialized;
  m_pCommand = NULL;
  m_fMultipleResults = false;
  m_pbConsumerData = NULL;
  m_pbReexecuteData = NULL;
  m_prps = NULL;
  m_pRowset = NULL;
}

CommandHandler::~CommandHandler()
{
  LOGCALL(("CommandHandler::~CommandHandler()\n"));

  if (m_pCommand != NULL)
    {
      CriticalSection critical_section (m_pCommand);

      m_pCommand->DecrementRowsetCount();
      if (m_accessor_iter != m_pCommand->EndAccessor())
	m_pCommand->ReleaseAccessor(m_accessor_iter);
      m_pCommand->GetControllingUnknown()->Release();

      critical_section.Leave ();

      m_statement.CloseCursor();

      delete [] m_pbReexecuteData;
      delete m_prps;
    }
}

HRESULT
CommandHandler::Init
(
  DataTransferHandler& dth,
  CCommand* command,
  Statement& stmt,
  std::vector<ParameterInfo>& param_info,
  DBPARAMS* pParams,
  RowsetPropertySet* rps
)
{
  LOGCALL(("CommandHandler::Init()\n"));

  assert(m_state == S_Uninitialized);

  assert(command != 0);
  m_pCommand = command;
  m_pCommand->GetControllingUnknown()->AddRef();
  m_pCommand->IncrementRowsetCount();
  m_accessor_iter = m_pCommand->EndAccessor();
  m_statement = stmt;
  m_pdth = &dth;
  m_prps = rps;

  if (pParams != NULL)
    {
      if (pParams->cParamSets == 0)
	return ErrorInfo::Set(E_INVALIDARG);
      if (pParams->pData == NULL)
	return ErrorInfo::Set(E_INVALIDARG);

      m_accessor_iter = command->AcquireAccessor(pParams->hAccessor);
      if (m_accessor_iter == command->EndAccessor())
	return ErrorInfo::Set(DB_E_BADACCESSORHANDLE);

      DataAccessor& accessor = command->GetAccessor(m_accessor_iter);
      if ((accessor.GetFlags () & DBACCESSOR_PARAMETERDATA) == 0)
	return ErrorInfo::Set(DB_E_BADACCESSORTYPE);

      m_pbConsumerData = (char*) pParams->pData;

      HRESULT hr = m_params.Init(m_statement, param_info,
				 accessor.GetBindingCount (), accessor.GetBindings (),
				 pParams->cParamSets, accessor.GetRowSize ());
      if (FAILED(hr))
	return hr;
    }

  m_state = S_Initialized;
  return S_OK;
}

HRESULT
CommandHandler::SetParams()
{
  LOGCALL(("CommandHandler::SetParams()\n"));

  if (!m_params.IsInitialized() || m_params.GetFieldCount() == 0)
    return S_OK;

  if (m_pbReexecuteData != NULL)
    {
      m_params.RestoreData(m_pbReexecuteData);
      return S_OK;
    }

  bool failure = false;
  char* pbConsumerData = m_pbConsumerData;
  DataAccessor& accessor = m_pCommand->GetAccessor(m_accessor_iter);
  for (ULONG iParamSet = 0; iParamSet < m_params.GetParamSets(); iParamSet++)
    {
      for (DBCOUNTITEM iBinding = 0; iBinding < accessor.GetBindingCount (); iBinding++)
	{
	  HRESULT hr = m_pdth->SetData(m_params, &m_params, iParamSet, m_params.GetParamSetData(iParamSet),
				       accessor, iBinding, pbConsumerData, true);
	  if (FAILED(hr))
	    return hr;
	  if (hr == S_FALSE)
	    failure = true;
	}
      pbConsumerData += accessor.GetRowSize ();
    }

  if (m_pbReexecuteData == NULL
      && m_statement.GetCursorType() == SQL_CURSOR_FORWARD_ONLY
      && m_params.HasLongData() == false)
    {
      HRESULT hr = m_params.BackupData(m_pbReexecuteData);
      if (FAILED(hr))
	return hr;
    }

  return failure ? DB_E_ERRORSOCCURRED : S_OK;
}

HRESULT
CommandHandler::SetLongParams()
{
  LOGCALL(("CommandHandler::SetLongParams()\n"));

  DataAccessor& accessor = m_pCommand->GetAccessor(m_accessor_iter);
  return m_pdth->SetDataAtExec(m_params, &m_params, accessor, m_pbConsumerData, true);
}

HRESULT
CommandHandler::GetStatus()
{
  LOGCALL(("CommandHandler::GetStatus()\n"));

  if (!m_params.IsInitialized() || m_params.GetFieldCount() == 0)
    return S_OK;

  bool success = false;
  bool failure = false;
  char* pbConsumerData = m_pbConsumerData;
  DataAccessor& accessor = m_pCommand->GetAccessor(m_accessor_iter);
  for (ULONG param_set = 0; param_set < m_params.GetParamSets(); param_set++)
    {
      HRESULT hr = m_params.GetStatus(param_set, accessor, pbConsumerData);
      if (FAILED(hr))
	failure = true;
      else
	success = true;
      pbConsumerData += param_set * accessor.GetRowSize ();
    }

  // Work around bug #1293. Note that after this GetStatus can no longer be called.
  m_params.UnsetStatus();

  return failure ? success ? DB_S_ERRORSOCCURRED : DB_E_ERRORSOCCURRED : S_OK;
}

HRESULT
CommandHandler::GetParams()
{
  LOGCALL(("CommandHandler::GetParams()\n"));

  if (!m_params.IsInitialized() || m_params.GetFieldCount() == 0)
    return S_OK;

  bool success = false;
  bool failure = false;

  char* pbConsumerData = m_pbConsumerData;
  DataAccessor& accessor = m_pCommand->GetAccessor(m_accessor_iter);
  for (ULONG iParamSet = 0; iParamSet < m_params.GetParamSets(); iParamSet++)
    {
      for (DBCOUNTITEM iBinding = 0; iBinding < accessor.GetBindingCount (); iBinding++)
	{
	  HRESULT hr = m_pdth->GetData(m_params, NULL, iParamSet, m_params.GetParamSetData(iParamSet),
				       accessor, iBinding, pbConsumerData, true);
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
      pbConsumerData += accessor.GetRowSize ();
    }

  return failure ? success ? DB_S_ERRORSOCCURRED : DB_E_ERRORSOCCURRED : S_OK;
}

HRESULT
CommandHandler::GetResult
(
  IUnknown* pUnkOuter,
  REFIID riid,
  DBROWCOUNT* pcRowsAffected,
  IUnknown** ppRowset
)
{
  LOGCALL(("CommandHandler::GetResult()\n"));

  HRESULT hr;

  CriticalSection critical_section(this);
  if (m_pRowset != NULL)
    return ErrorInfo::Set(DB_E_OBJECTOPEN);
  if (m_state == S_No_More_Results)
    return DB_S_NORESULT;

  assert(m_state != S_Uninitialized);
  if (m_state == S_Initialized)
    {
      m_state = S_First_Result;
    }
  else
    {
      if (m_state == S_First_Result)
	m_state = S_More_Results;
 
      hr = m_statement.MoreResults();
      if (FAILED(hr))
	return hr;
      if (hr == DB_S_NORESULT)
	{
	  m_state = S_No_More_Results;
	  GetParams();
	  return hr;
	}
    }

  if (pcRowsAffected != NULL)
    {
      hr = m_statement.GetRowsAffected(pcRowsAffected);
      if (FAILED(hr))
	return hr;
    }

  if (!m_statement.CreatesRowset())
    return S_OK;
  if (riid == IID_NULL || ppRowset == NULL)
    return S_OK;

  CRowsetCommandInitializer initializer (m_pCommand, this, m_statement, m_prps, riid);
  return ComAggregateObj<CRowset>::CreateInstance (pUnkOuter, riid, (void**) ppRowset, &initializer, &m_pRowset);
}

void
CommandHandler::RowsetCloseNotify()
{
  LOGCALL(("CommandHandler::RowsetCloseNotify()\n"));

  CriticalSection critical_section(this);

  assert(m_pRowset != NULL);
  if (m_fMultipleResults)
    {
      m_pRowset = NULL;
    }
  else
    {
      DeleteNotify();
      critical_section.Leave(); // for safety: critical_section is made on this obj
      delete this;
    }
}

void
CommandHandler::MultipleResultsCloseNotify()
{
  LOGCALL(("CommandHandler::MultipleResultsCloseNotify()\n"));

  CriticalSection critical_section(this);

  assert(m_fMultipleResults == true);
  if (m_pRowset != NULL)
    {
      m_fMultipleResults = false;
    }
  else
    {
      DeleteNotify();
      critical_section.Leave(); // for safety: critical_section is made on this obj
      delete this;
    }
}

void
CommandHandler::DeleteNotify()
{
  LOGCALL(("CommandHandler::DeleteNotify()\n"));

  // If there are any output parameters, consume all the results
  // to make sure that the output parametes are really returned.
  if (m_params.IsCompleted() && m_params.HasOutputParams())
    {
      while (m_state != S_No_More_Results)
	{
	  m_pRowset = NULL;
	  GetResult(NULL, IID_NULL, NULL, NULL);
	}
    }
}

HRESULT
CommandHandler::Reexecute()
{
  LOGCALL(("CommandHandler::Reexecute()\n"));

  if (m_state != S_First_Result || (m_params.IsInitialized() && m_params.HasLongData()))
    return ErrorInfo::Set(DB_E_CANNOTRESTART);

  HRESULT hr = SetParams();
  if (FAILED(hr))
    return hr;
  hr = m_statement.Reexecute();
#if 0
  if (hr == S_FALSE)
    hr = SetLongParams();
#endif
  if (FAILED(hr))
    return hr;

  return S_OK;
}

/**********************************************************************/
/* CCommand                                                           */

CCommand::CCommand()
{
  LOGCALL(("CCommand::CCommand()\n"));

  state = S_Initial;
  open_rowsets = 0;
  command_text = NULL;
  param_flags = PI_None;

  m_pUnkFTM = NULL;
}

CCommand::~CCommand()
{
  LOGCALL(("CCommand::~CCommand()\n"));
}

HRESULT
CCommand::Initialize (CSession* pSession)
{
  LOGCALL(("CCommand::Initialize ()\n"));

  RowsetPropertySet* rps = new RowsetPropertySet();
  if (rps == NULL)
    return ErrorInfo::Set(E_OUTOFMEMORY);
  if (rps->Init() == false)
    return ErrorInfo::Set(E_OUTOFMEMORY);

  return CDataObj::Init (pSession, rps);
}

void
CCommand::Delete()
{
  LOGCALL(("CCommand::Delete()\n"));

  if (rowset_property_set != NULL)
    {
      delete rowset_property_set;
      rowset_property_set = NULL;
    }
  if (command_text != NULL)
    {
      delete [] command_text;
      command_text = NULL;
    }
  if (m_pUnkFTM != NULL)
    {
      m_pUnkFTM->Release();
      m_pUnkFTM = NULL;
    }
}

HRESULT
CCommand::GetInterface(REFIID riid, IUnknown** ppUnknown)
{
  IUnknown* pUnknown = NULL;
  if (riid == IID_IAccessor)
    pUnknown = static_cast<IAccessor*>(this);
  else if (riid == IID_IColumnsInfo)
    pUnknown = static_cast<IColumnsInfo*>(this);
  else if (riid == IID_IColumnsRowset)
    pUnknown = static_cast<IColumnsRowset*>(this);
  else if (riid == IID_ICommand)
    pUnknown = static_cast<ICommand*>(this);
  else if (riid == IID_ICommandPrepare)
    pUnknown = static_cast<ICommandPrepare*>(this);
  else if (riid == IID_ICommandProperties)
    pUnknown = static_cast<ICommandProperties*>(this);
  else if (riid == IID_ICommandText)
    pUnknown = static_cast<ICommandText*>(this);
  else if (riid == IID_ICommandWithParameters)
    pUnknown = static_cast<ICommandWithParameters*>(this);
  else if (riid == IID_IConvertType)
    pUnknown = static_cast<IConvertType*>(this);
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
CCommand::GetSupportErrorInfoIIDs()
{
  static const IID* rgpIIDs[] =
  {
    &IID_IAccessor,
    &IID_IColumnsInfo,
    &IID_IColumnsRowset,
    &IID_ICommand,
    &IID_ICommandPrepare,
    &IID_ICommandProperties,
    &IID_ICommandText,
    &IID_ICommandWithParameters,
    &IID_IConvertType,
    NULL
  };

  return rgpIIDs;
}

bool
CCommand::IsCommand() const
{
  return true;
}

bool
CCommand::IsChangeableRowset() const
{
  return false;
}

HRESULT
CCommand::Prepare()
{
  ostring query = command_text;

  HRESULT hr = prepared_statement.Init(GetSession()->GetConnection(), rowset_property_set);
  if (FAILED(hr))
    {
      prepared_statement.Release();
      return hr;
    }

  hr = prepared_statement.Prepare(query);
  if (FAILED(hr))
    {
      prepared_statement.Release();
      return hr;
    }

  hr = InitRowsetInfo(prepared_statement);
  if (FAILED(hr))
    prepared_statement.Release();

  return hr;
}

HRESULT
CCommand::InitRowsetInfo(Statement& stmt)
{
  HRESULT hr = rowset_info.Init(stmt);
  if (FAILED(hr))
    return hr;

  rowset_property_set->prop_HIDDENCOLUMNS.SetValue((LONG)rowset_info.GetHiddenColumns());

  // TODO: check if DBPROP_UNIQUEROWS and other properties are satisfied
  // and return DB_[ES]_ERRORSOCCURRED as pertinent.
  return S_OK;
}

HRESULT
CCommand::GetRowsetInfo(const RowsetInfo*& rowset_info_p) const
{
  LOGCALL (("CCommand::GetRowsetInfo()\n"));

  rowset_info_p = NULL;

  CriticalSection critical_section(const_cast<CCommand*>(this));

  if (state == S_Initial)
    return ErrorInfo::Set(DB_E_NOCOMMAND);
  if (state == S_Unprepared)
    return ErrorInfo::Set(DB_E_NOTPREPARED);
  if (state == S_Dirty)
    {
      HRESULT hr = const_cast<CCommand*>(this)->Prepare();
      if (FAILED(hr))
	return hr;
      const_cast<CCommand*>(this)->state = S_Prepared;
    }

  rowset_info_p = &rowset_info;
  return S_OK;
}

void
CCommand::IncrementRowsetCount()
{
  LOGCALL(("CCommand::IncrementRowsetCount(), count = %d\n", open_rowsets + 1));

  InterlockedIncrement(&open_rowsets);
}

void
CCommand::DecrementRowsetCount()
{
  LOGCALL(("CCommand::DecrementRowsetCount(), count = %d\n", open_rowsets - 1));

  LONG rv = InterlockedDecrement(&open_rowsets);
  assert(rv >= 0);
}

/**********************************************************************/
/* ICommand                                                           */

STDMETHODIMP
CCommand::Cancel()
{
  LOGCALL(("CCommand::Cancel()\n"));

  ErrorCheck error(IID_ICommand, DISPID_ICommand_Cancel);

  if (InterlockedExchange(&phase, EP_Cancel) == EP_Executing)
    {
      HRESULT hr = executed_statement.Cancel();
      if (FAILED(hr))
	return ErrorInfo::Set(DB_E_CANTCANCEL);
      return S_OK;
    }
  return ErrorInfo::Set(DB_E_CANTCANCEL);
}

STDMETHODIMP
CCommand::Execute
(
  IUnknown *pUnkOuter,
  REFIID riid,
  DBPARAMS *pParams,
  DBROWCOUNT *pcRowsAffected,
  IUnknown **ppRowset
)
{
  LOGCALL(("CCommand::Execute()\n"));

  if (pcRowsAffected != NULL)
    *pcRowsAffected = DB_COUNTUNAVAILABLE;
  if (ppRowset != NULL)
    *ppRowset = NULL;

  ErrorCheck error(IID_ICommand, DISPID_ICommand_Execute);

  if (pUnkOuter != NULL && riid != IID_IUnknown)
    return ErrorInfo::Set(DB_E_NOAGGREGATION);
  if (riid != IID_NULL && ppRowset == NULL)
    return ErrorInfo::Set(E_INVALIDARG);
  if (pParams != NULL && (pParams->cParamSets == 0 || pParams->pData == NULL))
    return ErrorInfo::Set(E_INVALIDARG);

  CriticalSection critical_section(this);
  phase = EP_Not_Executing;

  if (state == S_Initial)
    return ErrorInfo::Set(DB_E_NOCOMMAND);

  HRESULT hr;
  if (state == S_Dirty)
    {
      hr = Prepare();
      if (FAILED(hr))
	return hr;
      state = S_Prepared;
    }

  bool create_rowset = ppRowset != NULL;
  bool use_prepared_statement = state == S_Prepared && open_rowsets == 0;

  AutoRelease<RowsetPropertySet> rps;
  if (create_rowset)
    {
      rps.Set(new RowsetPropertySet());
      if (rps == NULL)
	return ErrorInfo::Set(E_OUTOFMEMORY);
      if (rps->Init() == false)
	return ErrorInfo::Set(E_OUTOFMEMORY);
      hr = rps->Copy(rowset_property_set);
      if (FAILED(hr))
	return hr;
      DBPROPID propid;
      if (rps->ConvertRowsetIIDToPropertyID(riid, propid) == S_OK)
	{
	  hr = rps->SetRowsetProperty(propid);
	  if (FAILED(hr))
	    return hr;
	  if (hr != S_OK)
	    return ErrorInfo::Set(E_NOINTERFACE);
	}
    }

  if (use_prepared_statement)
    executed_statement = prepared_statement;
  else
    {
      if (create_rowset)
	hr = executed_statement.Init(GetSession()->GetConnection(), rowset_property_set);
      else
	hr = executed_statement.Init(GetSession()->GetConnection());
      if (FAILED(hr))
	{
	  executed_statement.Release();
	  return hr;
	}
    }

  int timeout = 0;
  if (rowset_property_set->prop_COMMANDTIMEOUT.HasValue())
    timeout = rowset_property_set->prop_COMMANDTIMEOUT.GetValue();
  executed_statement.SetQueryTimeout(timeout);

  AutoRelease<CommandHandler> handler(new CommandHandler());
  if (handler == NULL)
    return ErrorInfo::Set(E_OUTOFMEMORY);

  hr = handler->Init(m_dth, this, executed_statement, param_info, pParams, rps.GiveUp());
  if (FAILED(hr))
    return hr;
  hr = handler->SetParams();
  if (FAILED(hr))
    return hr;

  if (use_prepared_statement)
    {
      phase = EP_Executing;
      hr = executed_statement.Execute();
    }
  else
    {
      ostring query = command_text;
      phase = EP_Executing;
      hr = executed_statement.Execute(query);
    }
  if (hr == S_FALSE)
    hr = handler->SetLongParams();
  phase = EP_Not_Executing;
  executed_statement.Release();
  if (FAILED(hr))
    return hr;

  HRESULT hr_result = handler->GetStatus();
  if (FAILED(hr_result))
    return hr_result;

  // If the multiple results flag is false then the command handler may be
  // deleted by the RowsetCloseNotify(). Set it to true for now so that if
  // a failure occurrs during rowset initialization the command handler
  // won't be deleted by the incompletely initialized rowset.
  handler->SetMultipleResults(true);
  if (riid == IID_IMultipleResults)
    {
      hr = ComAdaptiveObjCreator<CMultipleResults>::CreateInstance (
	pUnkOuter, riid, (void**) ppRowset, handler.GiveUp ()
      );
      if (FAILED(hr))
	return hr;
    }
  else
    {
      hr = handler->GetResult(pUnkOuter, riid, pcRowsAffected, ppRowset);
      if (FAILED(hr))
	return hr;

      if (ppRowset == NULL || *ppRowset == NULL)
	{
	  handler->DeleteNotify();
	  return hr_result;
	}

      // Now it's safe to set the multiple results flag to false because
      // the rowset is completely initialized.
      handler->SetMultipleResults(false);

      handler.GiveUp();
    }

  return hr_result;
}

STDMETHODIMP
CCommand::GetDBSession
(
  REFIID riid,
  IUnknown **ppSession
)
{
  LOGCALL(("CCommand::GetDBSession()\n"));

  ErrorCheck error(IID_ICommand, DISPID_ICommand_GetDBSession);

  if (ppSession == NULL)
    return ErrorInfo::Set(E_INVALIDARG);
  *ppSession = NULL;

  CSession* pSession = GetSession();
  if (pSession == NULL)
    return S_FALSE;
  return pSession->GetControllingUnknown()->QueryInterface(riid, (void **) ppSession);
}

/**********************************************************************/
/* ICommandPrepare                                                    */

STDMETHODIMP
CCommand::Prepare
(
  ULONG cExpectedRuns
)
{
  LOGCALL(("CCommand::Prepare()\n"));

  ErrorCheck error(IID_ICommandPrepare, DISPID_ICommandPrepare_Prepare);

  CriticalSection critical_section(this);

  if (state == S_Prepared)
    return S_OK;
  if (state == S_Initial)
    return ErrorInfo::Set(DB_E_NOCOMMAND);
  if (open_rowsets > 0)
    return ErrorInfo::Set(DB_E_OBJECTOPEN);

  HRESULT hr = Prepare();
  if (FAILED(hr))
    return hr;
  state = S_Prepared;

  hr = ParameterPolicy::GetParamsInfo(prepared_statement, param_info);
  if (FAILED(hr))
    return hr;
  param_flags = (c_param_flags_t) (param_flags | PI_Derived);

  return S_OK;
}

STDMETHODIMP
CCommand::Unprepare()
{
  LOGCALL(("CCommand::Unprepare()\n"));

  ErrorCheck error(IID_ICommandPrepare, DISPID_ICommandPrepare_Unprepare);

  CriticalSection critical_section(this);

  if (state == S_Initial)
    return S_OK;
  if (state == S_Unprepared)
    return S_OK;
  if (open_rowsets > 0)
    return ErrorInfo::Set(DB_E_OBJECTOPEN);

  prepared_statement.Release();
  state = S_Unprepared;
  param_flags = (c_param_flags_t) (param_flags & ~PI_Derived);
  return S_OK;
}

/**********************************************************************/
/* ICommandProperties                                                 */

STDMETHODIMP
CCommand::GetProperties
(
  const ULONG cPropertyIDSets,
  const DBPROPIDSET rgPropertyIDSets[],
  ULONG *pcPropertySets,
  DBPROPSET **prgPropertySets
)
{
  LOGCALL(("CCommand::GetProperties()\n"));

  ErrorCheck error(IID_ICommandProperties, DISPID_ICommandProperties_GetProperties);

  CriticalSection critical_section(this);
  return PropertySuperset::GetProperties(cPropertyIDSets, rgPropertyIDSets, pcPropertySets, prgPropertySets);
}

STDMETHODIMP
CCommand::SetProperties
(
  ULONG cPropertySets,
  DBPROPSET rgPropertySets[]
)
{
  LOGCALL(("CCommand::SetProperties()\n"));

  ErrorCheck error(IID_ICommandProperties, DISPID_ICommandProperties_SetProperties);

  CriticalSection critical_section(this);
  if (open_rowsets > 0)
    return ErrorInfo::Set(DB_E_OBJECTOPEN);

  HRESULT hr = PropertySuperset::SetProperties(cPropertySets, rgPropertySets);
  if (FAILED(hr))
    return hr;

  if (state == S_Prepared)
    state = S_Dirty;
  return hr;
}

/**********************************************************************/
/* ICommandText                                                       */

STDMETHODIMP
CCommand::GetCommandText
(
  GUID *pguidDialect,
  LPOLESTR *ppwszCommand
)
{
  LOGCALL(("CCommand::GetCommandText()\n"));

  ErrorCheck error(IID_ICommandText, DISPID_ICommandText_GetCommandText);

  HRESULT hr = S_OK;
  if (pguidDialect != NULL)
    {
      if (*pguidDialect != DBGUID_DEFAULT && *pguidDialect != DBGUID_SQL)
	hr = DB_S_DIALECTIGNORED;

      static GUID db_nullguid = DB_NULLGUID; // DB_NULLGUID #defines a struct initializer (i.e. {...})
      *pguidDialect = db_nullguid;
    }

  if (ppwszCommand == NULL)
    return ErrorInfo::Set(E_INVALIDARG);

  CriticalSection critical_section(this);
  if (state == S_Initial)
    return ErrorInfo::Set(DB_E_NOCOMMAND);

  *ppwszCommand = (OLECHAR*) CoTaskMemAlloc(sizeof(OLECHAR) * (wcslen(command_text) + 1));
  if (*ppwszCommand == NULL)
    return ErrorInfo::Set(E_OUTOFMEMORY);
  wcscpy(*ppwszCommand, command_text);

  if (pguidDialect != NULL)
    *pguidDialect = DBGUID_SQL;
  return hr;
}

STDMETHODIMP
CCommand::SetCommandText
(
  REFGUID rguidDialect,
  LPCOLESTR pwszCommand
)
{
  LOGCALL(("CCommand::SetCommandText('%S')\n", pwszCommand));

  ErrorCheck error(IID_ICommandText, DISPID_ICommandText_SetCommandText);

  if (rguidDialect != DBGUID_DEFAULT && rguidDialect != DBGUID_SQL)
    return ErrorInfo::Set(DB_E_DIALECTNOTSUPPORTED);

  CriticalSection critical_section(this);

  if (open_rowsets > 0)
    return ErrorInfo::Set(DB_E_OBJECTOPEN);

  if (command_text != NULL)
    {
      delete [] command_text;
      command_text = NULL;
    }
  prepared_statement.Release();

  state = S_Initial;
  param_flags = (c_param_flags_t) (param_flags & ~PI_Derived);
  if (pwszCommand == NULL || *pwszCommand == 0)
    return S_OK;

  command_text = new OLECHAR[wcslen(pwszCommand) + 1];
  if (command_text == NULL)
    return ErrorInfo::Set(E_OUTOFMEMORY);
  wcscpy(command_text, pwszCommand);
 
  state = S_Unprepared;
  return S_OK;
}

/**********************************************************************/
/* ICommandWithParameters                                             */

STDMETHODIMP
CCommand::GetParameterInfo
(
  DB_UPARAMS *pcParams,
  DBPARAMINFO **prgParamInfo,
  OLECHAR **ppNamesBuffer
)
{
  LOGCALL(("CCommand::GetParameterInfo()\n"));

  if (pcParams != NULL)
    *pcParams = 0;
  if (prgParamInfo != NULL)
    *prgParamInfo = NULL;
  if (ppNamesBuffer != NULL)
    *ppNamesBuffer = NULL;

  ErrorCheck error(IID_ICommandWithParameters, DISPID_ICommandWithParameters_GetParameterInfo);

  if (pcParams == NULL || prgParamInfo == NULL)
    return ErrorInfo::Set(E_INVALIDARG);

  CriticalSection critical_section(this);

  if (!(param_flags & PI_Set))
    {
      // While the spec says to return DB_E_NOCOMMAND if no command text was currently set
      // it also has the following note:
      //   Some 2.1 or earlier providers that support command preparation may return
      //   DB_E_NOTPREPARED when the command text has not been set.
      // Also the test suite from the MDAC version as late as 2.6 still wants the return
      // code to be DB_E_NOTPREPARED, so return this ``wrong'' code as it wants.
      if (state == S_Initial)
#if 0
	return ErrorInfo::Set(DB_E_NOCOMMAND);
#else
	return ErrorInfo::Set(DB_E_NOTPREPARED);
#endif
      if (state == S_Unprepared)
	return ErrorInfo::Set(DB_E_NOTPREPARED);

      HRESULT hr = ParameterPolicy::GetParamsInfo(prepared_statement, param_info);
      if (FAILED(hr))
	return hr;
      param_flags = PI_Derived;
    }

  DB_UPARAMS cParams = 0;

  int i, n = param_info.size();
  for (i = 0; i < n; i++)
    {
      if (param_info[i].IsSet())
	cParams++;
    }

  if (cParams == 0)
    return S_OK;

  AutoRelease<DBPARAMINFO, ComMemFree> rgParamInfo((DBPARAMINFO*) CoTaskMemAlloc(cParams * sizeof(DBPARAMINFO)));
  if (rgParamInfo == NULL)
    return ErrorInfo::Set(E_OUTOFMEMORY);

  AutoRelease<OLECHAR, ComMemFree> pNamesBuffer;
  if (ppNamesBuffer != NULL)
    {
      size_t total = 0;
      for (i = 0; i < n; i++)
	{
	  if (param_info[i].IsSet() && !param_info[i].GetName().empty())
	    total += param_info[i].GetName().size() + 1;
	}

      if (total > 0)
	{
	  pNamesBuffer.Set((OLECHAR*) CoTaskMemAlloc(total * sizeof(OLECHAR)));
	  if (pNamesBuffer == NULL)
	    return ErrorInfo::Set(E_OUTOFMEMORY);
	}
    }

  OLECHAR *pNext = pNamesBuffer.Get();
  for (i = 0; i < n; i++)
    {
      if (!param_info[i].IsSet())
	continue;

      rgParamInfo[i].dwFlags = param_info[i].GetFlags();
      rgParamInfo[i].iOrdinal = i + 1;
      if (pNamesBuffer == NULL || param_info[i].GetName().empty())
	rgParamInfo[i].pwszName = NULL;
      else
	{
	  rgParamInfo[i].pwszName = pNext;
	  wcscpy(pNext, param_info[i].GetName().c_str());
	  pNext += param_info[i].GetName().size() + 1;
	}
      rgParamInfo[i].pTypeInfo = NULL;
      rgParamInfo[i].ulParamSize = param_info[i].GetOledbSize();
      rgParamInfo[i].wType = param_info[i].GetOledbType();
      rgParamInfo[i].bPrecision = param_info[i].GetOledbPrecision();
      rgParamInfo[i].bScale = param_info[i].GetOledbScaleForParameterInfo();
    }

  *pcParams = cParams;
  *prgParamInfo = rgParamInfo.GiveUp();
  if (ppNamesBuffer != NULL)
    *ppNamesBuffer = pNamesBuffer.GiveUp();
  return S_OK;
}

STDMETHODIMP
CCommand::MapParameterNames
(
  DB_UPARAMS cParamNames,
  const OLECHAR *rgParamNames[],
  DB_LPARAMS rgParamOrdinals[]
)
{
  LOGCALL(("CCommand::MapParameterNames()\n"));

  ErrorCheck error(IID_ICommandWithParameters, DISPID_ICommandWithParameters_MapParameterNames);

  if (cParamNames == 0)
    return S_OK;
  if (rgParamNames == NULL || rgParamOrdinals == NULL)
    return ErrorInfo::Set(E_INVALIDARG);

  CriticalSection critical_section(this);

  if (!(param_flags & PI_Set))
    {
      if (state == S_Initial)
	return ErrorInfo::Set(DB_E_NOCOMMAND);
      if (state == S_Unprepared)
	return ErrorInfo::Set(DB_E_NOTPREPARED);
    }

  bool success = false;
  bool failure = false;

  for (DB_UPARAMS iParam = 0; iParam < cParamNames; iParam++)
    {
      if (rgParamNames[iParam] == NULL)
	{
	  rgParamOrdinals[iParam] = 0;
	  failure = true;
	  continue;
	}

      ULONG j;
      for (j = 0; j < param_info.size(); j++)
	if (param_info[j].GetName().compare(rgParamNames[iParam]) == 0)
	  break;
      if (j < param_info.size())
	{
	  rgParamOrdinals[iParam] = j + 1;
	  success = true;
	}
      else
	{
	  rgParamOrdinals[iParam] = 0;
	  failure = true;
	}
    }

  return failure ? success ? DB_S_ERRORSOCCURRED : DB_E_ERRORSOCCURRED : S_OK;
}

STDMETHODIMP
CCommand::SetParameterInfo
(
  DB_UPARAMS cParams,
  const DB_UPARAMS rgParamOrdinals[],
  const DBPARAMBINDINFO rgParamBindInfo[]
)
{
  LOGCALL(("CCommand::SetParameterInfo()\n"));

  ErrorCheck error(IID_ICommandWithParameters, DISPID_ICommandWithParameters_SetParameterInfo);

  if (cParams != 0 && (rgParamOrdinals == NULL || rgParamBindInfo == NULL))
    return ErrorInfo::Set(E_INVALIDARG);

  DB_UPARAMS iParam, max_ordinal = 0;
  for (iParam = 0; iParam < cParams; iParam++)
    {
      DB_UPARAMS ordinal = rgParamOrdinals[iParam];
      if (ordinal == 0)
	return ErrorInfo::Set(E_INVALIDARG);
      if (max_ordinal < ordinal)
	max_ordinal = ordinal;

      const DBPARAMBINDINFO &bindinfo = rgParamBindInfo[iParam];
      LOG(("rgParamBindInfo[%d]: pwszDataSourceType='%ls', pwszName='%s', ulParamSize=%ld, dwFlags=0x%04x, bPrecision=%d, bScale=%d\n",
	   iParam, bindinfo.pwszDataSourceType ? bindinfo.pwszDataSourceType : L"", bindinfo.pwszName ? bindinfo.pwszName : L"",
	   bindinfo.ulParamSize, bindinfo.dwFlags, bindinfo.bPrecision, bindinfo.bScale));

      if (bindinfo.pwszDataSourceType == NULL)
	return ErrorInfo::Set(E_INVALIDARG);
      if ((bindinfo.dwFlags
           & ~(DBPARAMFLAGS_ISINPUT | DBPARAMFLAGS_ISOUTPUT | DBPARAMFLAGS_ISSIGNED
	       | DBPARAMFLAGS_ISNULLABLE | DBPARAMFLAGS_ISLONG)) != 0)
	return ErrorInfo::Set(E_INVALIDARG);
      if (!DataFieldInfo::IsValidTypeName (bindinfo.pwszDataSourceType))
      //if (DataFieldInfo::DataSourceTypeToSql(bindinfo.pwszDataSourceType) == SQL_UNKNOWN_TYPE)
	return ErrorInfo::Set(DB_E_BADTYPENAME);
      // TODO: check to see if the parameter name is correct.
    }

  CriticalSection critical_section(this);
  if (open_rowsets > 0)
    return ErrorInfo::Set(DB_E_OBJECTOPEN);

  if (cParams == 0)
    {
      param_info.clear();
      param_flags = PI_None;
      return S_OK;
    }

  try {
    param_info.reserve(max_ordinal);
    for (DB_UPARAMS i = param_info.size(); i < max_ordinal; i++)
      param_info.push_back(ParameterInfo());
  } catch (...) {
    return ErrorInfo::Set(E_OUTOFMEMORY);
  }
  param_flags = (c_param_flags_t) (param_flags | PI_Set);

  bool overridden = false;
  for (iParam = 0; iParam < cParams; iParam++)
    {
      ParameterInfo& info = param_info[rgParamOrdinals[iParam] - 1];
      if (info.IsSet())
	overridden = true;

      HRESULT hr = info.InitParameterInfo(rgParamBindInfo[iParam]);
      if (FAILED(hr))
	return hr;
    }

#if 0
  for (i = 0; i < param_info.size(); i++)
    {
      if (param_info[i].IsSet())
	{
	  bool named_parameters = param_info[i].GetName().empty();
	  for (; i < param_info.size(); i++)
	    {
	      if (param_info[i].IsSet() && named_parameters != param_info[i].GetName().empty())
		return ErrorInfo::Set(DB_E_BADPARAMETERNAME);
	    }
	  break;
	}
    }
#endif

  return overridden ? DB_S_TYPEINFOOVERRIDDEN : S_OK;
}

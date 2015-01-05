/*  command.h
 *
 *  $Id$
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

#ifndef COMMAND_H
#define COMMAND_H

#include "dataobj.h"
#include "paramdata.h"
#include "rowsetdata.h"
#include "db.h"
#include "error.h"


class CSession;
class CCommand;
class CRowset;


class CommandHandler : public SyncObj
{
public:

  CommandHandler();
  ~CommandHandler();

  HRESULT Init
  (
    DataTransferHandler& dth,
    CCommand* command,
    Statement& stmt,
    std::vector<ParameterInfo>& param_info,
    DBPARAMS* pParams,
    RowsetPropertySet* rps
  );

  HRESULT SetParams();
  HRESULT SetLongParams();
  HRESULT GetStatus();
  HRESULT GetParams();

  HRESULT GetResult
  (
    IUnknown* pUnkOuter,
    REFIID riid,
    DBROWCOUNT* pcRowsAffected,
    IUnknown** ppRowset
  );

  void RowsetCloseNotify();
  void MultipleResultsCloseNotify();
  void DeleteNotify();

  CCommand*
  GetCommand()
  {
    return m_pCommand;
  }

  void
  SetMultipleResults(bool mr)
  {
    m_fMultipleResults = mr;
  }

  HRESULT Reexecute();

private:

  enum cm_state_t
  {
    S_Uninitialized,
    S_Initialized,
    S_First_Result,
    S_More_Results,
    S_No_More_Results
  };

  cm_state_t m_state;
  Statement m_statement;
  CCommand* m_pCommand;
  ParameterPolicy m_params;
  char* m_pbConsumerData;
  char* m_pbReexecuteData;
  bool m_fMultipleResults;
  DataTransferHandler* m_pdth;
  RowsetPropertySet* m_prps;
  CRowset* m_pRowset;
  AccessorIterator m_accessor_iter;
};


class NOVTABLE CCommand :
  public ICommandPrepare,
  public ICommandProperties,
  public ICommandText,
  public ICommandWithParameters,
  public ISupportErrorInfoImpl<CCommand>,
  public CDataObj
{
public:

  CCommand();
  ~CCommand();
  
  HRESULT Initialize (CSession* pSession);

  void Delete();

  virtual HRESULT GetInterface(REFIID riid, IUnknown** ppUnknown);

  const IID** GetSupportErrorInfoIIDs();

  HRESULT Init(CSession* pSession);

  virtual bool IsCommand() const;
  virtual bool IsChangeableRowset() const;

  virtual HRESULT GetRowsetInfo(const RowsetInfo*& rowset_info_p) const;

  void IncrementRowsetCount();
  void DecrementRowsetCount();

  const RowsetPropertySet*
  GetRowsetProperties()
  {
    return rowset_property_set;
  }

private:

  HRESULT Prepare();
  HRESULT InitRowsetInfo(Statement& stmt);

  enum c_state_t
  {
    S_Initial,
    S_Unprepared,
    S_Prepared,
    S_Dirty
  };

  enum c_param_flags_t
  {
    PI_None = 0,
    PI_Set = 1,
    PI_Derived = 2
  };

  // command execution phase
  enum c_exec_phase_t
  {
    EP_Not_Executing,
    EP_Executing,
    EP_Cancel
  };

  c_state_t state;
  long phase;
  Statement prepared_statement;
  Statement executed_statement;
  LONG open_rowsets;
  OLECHAR* command_text;
  c_param_flags_t param_flags;
  std::vector<ParameterInfo> param_info;
  RowsetInfo rowset_info;

  IUnknown* m_pUnkFTM;

public:

  // ICommand members

  STDMETHODIMP Cancel();

  STDMETHODIMP Execute
  (
    IUnknown *pUnkOuter,
    REFIID riid,
    DBPARAMS *pParams,
    DBROWCOUNT *pcRowsAffected,
    IUnknown **ppRowset
  );

  STDMETHODIMP GetDBSession
  (
    REFIID riid,
    IUnknown **ppSession
  );

  // ICommandPrepare members

  STDMETHODIMP Prepare
  (
    ULONG cExpectedRuns
  );

  STDMETHODIMP Unprepare();

  // ICommandProperties members

  STDMETHODIMP GetProperties
  (
    const ULONG cPropertyIDSets,
    const DBPROPIDSET rgPropertyIDSets[],
    ULONG *pcPropertySets,
    DBPROPSET **prgPropertySets
  );

  STDMETHODIMP SetProperties
  (
    ULONG cPropertySets,
    DBPROPSET rgPropertySets[]
  );

  // ICommandText members

  STDMETHODIMP GetCommandText
  (
    GUID *pguidDialect,
    LPOLESTR *ppwszCommand
  );

  STDMETHODIMP SetCommandText
  (
    REFGUID rguidDialect,
    LPCOLESTR pwszCommand
  );

  // ICommandWithParameters members

  STDMETHODIMP GetParameterInfo
  (
    DB_UPARAMS *pcParams,
    DBPARAMINFO **prgParamInfo,
    OLECHAR **ppNamesBuffer
  );

  STDMETHODIMP MapParameterNames
  (
    DB_UPARAMS cParamNames,
    const OLECHAR *rgParamNames[],
    DB_LPARAMS rgParamOrdinals[]
  );

  STDMETHODIMP SetParameterInfo
  (
    DB_UPARAMS cParams,
    const DB_UPARAMS rgParamOrdinals[],
    const DBPARAMBINDINFO rgParamBindInfo[]
  );
};


#endif

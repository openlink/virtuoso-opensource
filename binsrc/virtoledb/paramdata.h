/*  paramdata.h
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

#ifndef PARAMDATA_H
#define PARAMDATA_H

#include "data.h"


// defined in session.h
struct Schema;


class ParameterInfo : public DataFieldInfo
{
public:

  HRESULT InitParameterInfo(const SQLWCHAR* name,
			    SQLSMALLINT sql_type, SQLUINTEGER field_size, SQLSMALLINT decimal_digits,
			    SQLSMALLINT nullable, SQLSMALLINT param_type);

  HRESULT InitParameterInfo(const DBPARAMBINDINFO& param_bind_info);

  HRESULT InitSchemaParameterInfo(SQLSMALLINT sql_type, SQLINTEGER field_size, DBTYPE oledb_type);

  // Used when parameter information neither provided by application nor obtained
  // from server (that is the statement executed was not prepared).
  HRESULT InitDefaultParameterInfo(const DBBINDING& binding);

  void InitDefaultParameterType(const DBBINDING& binding);
};


class ParameterPolicy : public DataRecordInfo, public SetDataHandler
{
public:

  ParameterPolicy();
  ~ParameterPolicy();

  void Release();
  void ReleaseStatusArray();

  HRESULT Init
  (
    Statement& stmt,
    const std::vector<ParameterInfo>& param_info,
    DBCOUNTITEM cBindings,
    const DBBINDING rgBindings[],
    DB_UPARAMS cParamSets,
    DBLENGTH cbRowSize
  );

  HRESULT Init
  (
    Statement& stmt,
    Schema* pSchema,
    ULONG cRestrictions,
    const VARIANT rgRestrictions[],
    IDataConvert* pIDataConvert
  );

  virtual ULONG
  GetFieldCount() const
  {
    assert(IsInitialized());
    return (ULONG)m_cFieldInfos;
  }

  virtual const DataFieldInfo&
  GetFieldInfo(ULONG iField) const
  {
    assert(IsInitialized());
    assert(m_rgFieldInfos != NULL);
    assert(iField < m_cFieldInfos);
    return m_rgFieldInfos[iField];
  }

  ULONG
  GetParamSets()
  {
    assert(IsInitialized());
    return m_cParamSets;
  }

  bool
  HasOutputParams()
  {
    assert(IsInitialized());
    return m_fOutputParams;
  }

  char*
  GetParamSetData(ULONG iParamSet)
  {
    assert(iParamSet < m_cParamSets && iParamSet >= 0);
    return m_pbParamSets + iParamSet * GetRecordSize();
  }

  virtual HRESULT SetDataAtExec(HROW iRecordID, DBORDINAL iFieldOrdinal, SQLSMALLINT wSqlCType, DBCOUNTITEM iBinding);
  virtual HRESULT GetDataAtExec(HROW& iRecordID, DBCOUNTITEM& iBinding);
  virtual HRESULT PutDataAtExec(char* pv, SQLINTEGER cb);

  HRESULT
  BackupData(char*& pbBackupData)
  {
    size_t size = m_cParamSets * GetRecordSize();
    pbBackupData = new char[size];
    if (pbBackupData == NULL)
      return ErrorInfo::Set(E_OUTOFMEMORY);
    memcpy(pbBackupData, m_pbParamSets, size);
    return S_OK;
  }

  void
  RestoreData(char* pbBackupData)
  {
    memcpy(m_pbParamSets, pbBackupData, m_cParamSets * GetRecordSize());
  }

  HRESULT GetStatus(ULONG param_set, const DataAccessor& accessor, char* consumer_data);

  void UnsetStatus();

  static HRESULT GetParamsInfo(Statement& stmt, std::vector<ParameterInfo>& params_info);

private:

  HRESULT InitInfo(DBORDINAL cParams);

  Statement m_statement;
  DBORDINAL m_cFieldInfos;
  ParameterInfo* m_rgFieldInfos;
  SQLUINTEGER m_cParamSets;
  SQLUINTEGER m_cParamSetsProcessed;
  char* m_pbParamSets;
  SQLUSMALLINT* m_rgParamSetStatus;
  bool m_fOutputParams;
};


#endif

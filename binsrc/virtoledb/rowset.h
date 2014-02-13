/*  rowset.h
 *
 *  $Id$
 *  
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *  
 *  Copyright (C) 1998-2014 OpenLink Software
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

#ifndef ROWSET_H
#define ROWSET_H

#include "dataobj.h"
#include "connobj.h"
#include "rowsetdata.h"
#include "error.h"


class CSession;
class CCommand;
class CommandHandler;
class ParameterPolicy;
struct Schema;


struct CRowsetSessionInitializer
{
  CRowsetSessionInitializer (
    CSession* _sess, ostring& _query,
    Schema* _pSchema, ULONG _cRestrictions, const VARIANT _rgRestrictions[],
    REFIID _riid, ULONG _cPropertySets, DBPROPSET _rgPropertySets[]
  )
  : sess (_sess), query (_query),
    pSchema (_pSchema), cRestrictions (_cRestrictions), rgRestrictions (_rgRestrictions),
    riid (_riid), cPropertySets (_cPropertySets), rgPropertySets (_rgPropertySets)
  {
  }

  CSession* sess;
  ostring& query;
  Schema* pSchema;
  ULONG cRestrictions;
  const VARIANT* rgRestrictions;
  REFIID riid;
  ULONG cPropertySets;
  DBPROPSET* rgPropertySets;
  HRESULT hr;
};

struct CRowsetCommandInitializer
{
  CRowsetCommandInitializer (
    CCommand* _comm, CommandHandler* _handler, Statement& _stmt, RowsetPropertySet* _rps, REFIID _riid
  )
  : comm (_comm), handler (_handler), stmt (_stmt), rps (_rps), riid (_riid)
  {
  }

  CCommand* comm;
  CommandHandler* handler;
  Statement& stmt;
  RowsetPropertySet* rps;
  REFIID riid;
  HRESULT hr;
};

struct CRowsetColumnsInitializer
{
  CRowsetColumnsInitializer (
    CDataObj* _pDataObj, const RowsetInfo* _pRowsetInfo, DBORDINAL _cOptColumns, const DBID _rgOptColumns[],
    REFIID _riid, ULONG _cPropertySets, DBPROPSET _rgPropertySets[]
  )
  : pDataObj (_pDataObj), pRowsetInfo (_pRowsetInfo), cOptColumns (_cOptColumns), rgOptColumns (_rgOptColumns),
    riid (_riid), cPropertySets (_cPropertySets), rgPropertySets (_rgPropertySets)
  {
  }

  CDataObj* pDataObj;
  const RowsetInfo* pRowsetInfo;
  DBORDINAL cOptColumns;
  const DBID* rgOptColumns;
  REFIID riid;
  ULONG cPropertySets;
  DBPROPSET* rgPropertySets;
  HRESULT hr;
};

class NOVTABLE CRowset :
  public IConnectionPointContainerImpl<CRowset>,
  public IRowsetFind,
  public IRowsetIdentity,
  public IRowsetInfo,
  public IRowsetRefresh,
  public IRowsetResynch,
  public IRowsetScroll,
  public IRowsetUpdate,
  public ISupportErrorInfoImpl<CRowset>,
  public CDataObj
{
public:

  CRowset();
  ~CRowset();

  HRESULT Initialize (CRowsetSessionInitializer *pInitializer);
  HRESULT Initialize (CRowsetCommandInitializer *pInitializer);
  HRESULT Initialize (CRowsetColumnsInitializer *pInitializer);

  HRESULT Create();

  void Delete();

  virtual HRESULT GetInterface(REFIID riid, IUnknown** ppUnknown);

  const IID** GetSupportErrorInfoIIDs();
  IConnectionPoint** GetConnectionPoints();

  HRESULT Init
  (
    CSession* sess,
    ostring& query,
    Schema* pSchema,
    ULONG cRestrictions,
    const VARIANT rgRestrictions[],
    REFIID riid,
    ULONG cPropertySets,
    DBPROPSET rgPropertySets[]
  );

  HRESULT Init
  (
    CDataObj* pDataObj,
    const RowsetInfo* pRowsetInfo,
    DBORDINAL cOptColumns,
    const DBID rgOptColumns[],
    REFIID riid,
    ULONG cPropertySets,
    DBPROPSET rgPropertySets[]
  );

  HRESULT Init
  (
    CCommand* comm,
    CommandHandler* handler,
    Statement& stmt,
    RowsetPropertySet* rps,
    REFIID riid
  );

  virtual bool IsCommand() const;
  virtual bool IsChangeableRowset() const;

  virtual HRESULT GetRowsetInfo(const RowsetInfo*& rowset_info_p) const;

  void EndTransaction(bool commit);

private:

  HRESULT InitFirst(CSession* sess, IUnknown* spec, RowsetPropertySet* rps);
  HRESULT InitFinal(Schema* pSchema = NULL);

  void FreeResources();

  HRESULT OnFieldChange(HROW hRow, DBORDINAL cColumns, DBORDINAL rgColumns[], DBREASON eReason, DBEVENTPHASE ePhase);
  HRESULT OnRowActivate(DBCOUNTITEM cRows, const HROW rghRows[]);
  HRESULT OnRowChange(DBCOUNTITEM cRows, const HROW rghRows[], DBREASON eReason, DBEVENTPHASE ePhase);
  HRESULT OnRowsetChange(DBREASON eReason, DBEVENTPHASE ePhase);

  HRESULT GetData(HROW hRow, char* pbProviderData, const DataAccessor& accessor, char* pbConsumerData);

  Statement m_statement;
  CommandHandler* m_pCommandHandler;
  ParameterPolicy* m_pParameters;
  RowsetInfo m_info;
  AbstractRowPolicy* m_pRowPolicy;
  AbstractRowsetPolicy* m_pRowsetPolicy;
  std::map<HROW, char*> m_mpOriginalData;
  std::map<HROW, char*> m_mpVisibleData;
  CConnectionPoint m_RowsetNotifyCP;
  IConnectionPoint* m_rgpCP[2];
  IUnknown* m_pUnkSpec;
  IUnknown* m_pUnkFTM;

  HRESULT SaveOriginalData(HROW hRow, RowData* pRowData);
  void FreeOriginalData(HROW hRow);
  void FreeVisibleData(HROW hRow);

public:

  // IRowset members

  STDMETHODIMP AddRefRows(
    DBCOUNTITEM cRows,
    const HROW rghRows[],
    DBREFCOUNT rgRefCounts[],
    DBROWSTATUS rgRowStatus[]
  );

  STDMETHODIMP GetData(
    HROW hRow,
    HACCESSOR hAccessor,
    void* pData
  );

  STDMETHODIMP GetNextRows(
    HCHAPTER hChapter,
    DBROWOFFSET lRowsOffset,
    DBROWCOUNT cRows,
    DBCOUNTITEM* pcRowsObtained,
    HROW** prghRows
  );

  STDMETHODIMP ReleaseRows(
    DBCOUNTITEM cRows,
    const HROW rghRows[],
    DBROWOPTIONS rgRowOptions[],
    DBREFCOUNT rgRefCounts[],
    DBROWSTATUS rgRowStatus[]
  );

  STDMETHODIMP RestartPosition(
    HCHAPTER hChapter
  );

  // IRowsetChange members

  STDMETHODIMP DeleteRows(
    HCHAPTER hChapter,
    DBCOUNTITEM cRows,
    const HROW rghRows[],
    DBROWSTATUS rgRowStatus[]
  );

  STDMETHODIMP InsertRow(
    HCHAPTER hChapter,
    HACCESSOR hAccessor,
    void *pData,
    HROW *phRow
  );

  STDMETHODIMP SetData(
    HROW hRow,
    HACCESSOR hAccessor,
    void *pData
  );

  // IRowsetIdentity members

  STDMETHODIMP IsSameRow(
    HROW hThisRow,
    HROW hThatRow
  );

  // IRowsetInfo members

  STDMETHODIMP GetProperties(
    const ULONG cPropertyIDSets,
    const DBPROPIDSET rgPropertyIDSets[],
    ULONG *pcPropertySets,
    DBPROPSET **prgPropertySets
  );

  STDMETHODIMP GetReferencedRowset(
    DBORDINAL iOrdinal,
    REFIID riid,
    IUnknown **ppReferencedRowset
  );

  STDMETHODIMP GetSpecification(
    REFIID riid,
    IUnknown **ppSpecification
  );

  // IRowsetFind members

  STDMETHODIMP FindNextRow(
    HCHAPTER hChapter,
    HACCESSOR hAccessor,
    void* pFindValue,
    DBCOMPAREOP CompareOp,
    DBBKMARK cbBookmark,
    const BYTE* pBookmark,
    DBROWOFFSET lRowsOffset,
    DBROWCOUNT cRows,
    DBCOUNTITEM* pcRowsObtained,
    HROW** prghRows
  );

  // IRowsetLocate members

  STDMETHODIMP Compare(
    HCHAPTER hChapter,
    DBBKMARK cbBookmark1,
    const BYTE *pBookmark1,
    DBBKMARK cbBookmark2,
    const BYTE *pBookmark2,
    DBCOMPARE *pComparison
  );

  STDMETHODIMP GetRowsAt(
    HWATCHREGION hReserved,
    HCHAPTER hChapter,
    DBBKMARK cbBookmark,
    const BYTE *pBookmark,
    DBROWOFFSET lRowsOffset,
    DBROWCOUNT cRows,
    DBCOUNTITEM *pcRowsObtained,
    HROW **prghRows
  );

  STDMETHODIMP GetRowsByBookmark(
    HCHAPTER hChapter,
    DBCOUNTITEM cRows,
    const DBBKMARK rgcbBookmarks[],
    const BYTE *rgpBookmarks[],
    HROW rghRows[],
    DBROWSTATUS rgRowStatus[]
  );

  STDMETHODIMP Hash(
    HCHAPTER hChapter,
    DBBKMARK cBookmarks,
    const DBBKMARK rgcbBookmarks[],
    const BYTE *rgpBookmarks[],
    DBHASHVALUE rgHashedValues[],
    DBROWSTATUS rgBookamrkStatus[]
  );

  // IRowsetRefresh members

  STDMETHODIMP GetLastVisibleData(
    HROW hRow,
    HACCESSOR hAccessor,
    void* pData
  );

  STDMETHODIMP RefreshVisibleData(
    HCHAPTER hChapter,
    DBCOUNTITEM cRows,
    const HROW rghRows[],
    BOOL fOverwrite,
    DBCOUNTITEM* pcRowsRefreshed,
    HROW** prghRowsRefreshed,
    DBROWSTATUS** prgRowStatus
  );

  // IRowsetResynch members

  STDMETHODIMP GetVisibleData(
    HROW hRow,
    HACCESSOR hAccessor,
    void* pData
  );

  STDMETHODIMP ResynchRows(
    DBCOUNTITEM cRows,
    const HROW rghRows[],
    DBCOUNTITEM* pcRowsResynched,
    HROW** prghRowsResynched,
    DBROWSTATUS** prgRowStatus
  );

  // IRowsetScroll members

  STDMETHODIMP GetApproximatePosition(
    HCHAPTER hChapter,
    DBBKMARK cbBookmark,
    const BYTE* pBookmark,
    DBCOUNTITEM* pulPosition,
    DBCOUNTITEM* pcRows
  );

  STDMETHODIMP GetRowsAtRatio(
    HWATCHREGION hReserved,
    HCHAPTER hChapter,
    DBCOUNTITEM ulNumerator,
    DBCOUNTITEM ulDenominator,
    DBROWCOUNT cRows,
    DBCOUNTITEM* pcRowsObtained,
    HROW** prghRows
  );

  // IRowsetUpdate members

  STDMETHODIMP GetOriginalData(
    HROW hRow,
    HACCESSOR hAccessor,
    void* pData
  );

  STDMETHODIMP GetPendingRows(
    HCHAPTER hReserved,
    DBPENDINGSTATUS dwRowStatus,
    DBCOUNTITEM* pcPendingRows,
    HROW**  prgPendingRows,
    DBPENDINGSTATUS** prgPendingStatus
  );

  STDMETHODIMP GetRowStatus(
    HCHAPTER hReserved,
    DBCOUNTITEM cRows,
    const HROW rghRows[],
    DBPENDINGSTATUS rgPendingStatus[]
  );

  STDMETHODIMP Undo(
    HCHAPTER hReserved,
    DBCOUNTITEM cRows,
    const HROW rghRows[],
    DBCOUNTITEM* pcRows,
    HROW** prgRows,
    DBROWSTATUS** prgRowStatus
  );

  STDMETHODIMP Update(
    HCHAPTER hReserved,
    DBCOUNTITEM cRows,
    const HROW rghRows[],
    DBCOUNTITEM* pcRows,
    HROW** prgRows,
    DBROWSTATUS** prgRowStatus
  );

};


#endif

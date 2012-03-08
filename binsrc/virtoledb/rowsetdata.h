/*  rowsetdata.h
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

#ifndef ROWSETDATA_H
#define ROWSETDATA_H

#include "data.h"
#include "lobdata.h"


// defined in session.h
struct Schema;


enum COLUMN_STATUS
{
  COLUMN_STATUS_UNAVAILABLE,
  COLUMN_STATUS_UNCHANGED,
  COLUMN_STATUS_CHANGED,
};


typedef long bookmark_t;
typedef std::map<bookmark_t, HROW> bm_map_t;
typedef std::map<bookmark_t, HROW>::iterator bm_iter_t;


class ColumnInfo : public DataFieldInfo
{
public:

  ColumnInfo();

  HRESULT InitColumnInfo(const SQLWCHAR* pwszName, const SQLWCHAR* pwszBaseName,
			 const SQLWCHAR* pwszTable, const SQLWCHAR* pwszSchema, const SQLWCHAR* pwszCatalog,
			 SQLSMALLINT sql_type, SQLUINTEGER field_size, SQLSMALLINT decimal_digits,
			 SQLSMALLINT nullable, SQLLEN updatable, SQLLEN key);

  HRESULT InitBookmarkColumnInfo();

  HRESULT InitMetaColumnInfo(const wchar_t* pwszName, const DBID* pdbid,
			     DBTYPE wOledbType, SQLINTEGER dwColumnSize, bool fMaybeNull);

  // Get field DBID (for metadata columns only)
  const DBID*
  GetDBID() const
  {
    return m_pdbid;
  }

  const std::basic_string<OLECHAR>&
  GetBaseColumnName() const
  {
    return m_base_column_name;
  }

  const std::basic_string<OLECHAR>&
  GetBaseTableName() const
  {
    return m_base_table_name;
  }

  const std::basic_string<OLECHAR>&
  GetBaseSchemaName() const
  {
    return m_base_schema_name;
  }

  const std::basic_string<OLECHAR>&
  GetBaseCatalogName() const
  {
    return m_base_catalog_name;
  }

private:

  void
  SetDBID(const DBID* pdbid)
  {
    m_pdbid = pdbid;
  }

  const DBID* m_pdbid;
  std::basic_string<OLECHAR> m_base_column_name;
  std::basic_string<OLECHAR> m_base_table_name;
  std::basic_string<OLECHAR> m_base_schema_name;
  std::basic_string<OLECHAR> m_base_catalog_name;
};


class RowsetInfo : public DataRecordInfo
{
public:

  RowsetInfo();
  ~RowsetInfo();

  HRESULT Init(Statement& stmt, Schema* pSchema = NULL);
  HRESULT Init(DBORDINAL cOptColumns,
	       const DBID rgOptColumns[],
	       bool fHasBookmark);

  void Release();

  virtual ULONG
  GetFieldCount() const
  {
    assert(IsInitialized());
    return (ULONG)m_cColumns;
  }

  virtual const DataFieldInfo&
  GetFieldInfo(ULONG iColumn) const
  {
    return GetColumnInfo(iColumn);
  }

  const ColumnInfo&
  GetColumnInfo(DBORDINAL iColumn) const
  {
    assert(IsInitialized());
    assert(m_rgColumnInfos != NULL);
    assert(iColumn < m_cColumns);
    return m_rgColumnInfos[iColumn];
  }

  bool
  HasBookmark() const
  {
    assert(IsInitialized());
    return m_fHasBookmark;
  }

  virtual ULONG
  OrdinalToIndex(DBORDINAL ordinal) const
  {
    return HasBookmark() ? (ULONG)ordinal : (ULONG)ordinal - 1;
  }

  virtual DBORDINAL
  IndexToOrdinal(ULONG index) const
  {
    return HasBookmark() ? index : index + 1;
  }

  virtual DBORDINAL
  GetHiddenColumns() const
  {
    assert(IsInitialized());
    return m_cHiddenColumns;
  }

  COLUMN_STATUS
  GetColumnStatus(char* pbRecordData, DBORDINAL iField) const
  {
    return (COLUMN_STATUS) ((LONG*) pbRecordData)[iField];
  }

  void
  SetColumnStatus(char* pbRecordData, DBORDINAL iField, COLUMN_STATUS dwStatus) const
  {
    ((LONG*) pbRecordData)[iField] = dwStatus;
  }

  static int GetOptionalMetaColumns();
  static void GetOptionalMetaColumnIDs(DBID* rgOptColumns);

  HRESULT InitMetaRow(DBORDINAL iColumnOrdinal, const ColumnInfo& info, bool fIsHidden, char* pbData);

protected:

  virtual ULONG
  GetExtraSize() const
  {
    return (ULONG) (sizeof(DBORDINAL) * GetFieldCount());
  }

private:

  HRESULT InitInfo(DBORDINAL cColumns, bool fHasBookmark);
  HRESULT InitColumn (int iColumn, Statement& stmt);
  HRESULT InitColumn (int iColumn, Schema* pSchema);

  DBORDINAL m_cColumns;
  DBORDINAL m_cHiddenColumns;
  ColumnInfo* m_rgColumnInfos;
  bool m_fHasBookmark;

  // forbid copying
  RowsetInfo(const RowsetInfo&);
  RowsetInfo& operator=(const RowsetInfo&);
};


class RowData
{
public:

  LONG
  GetRefRow() const
  {
    return m_iRef;
  }

  LONG
  AddRefRow()
  {
    return ++m_iRef;
  }

  LONG
  ReleaseRow()
  {
    assert(m_iRef > 0);
    return --m_iRef;
  }

  DBPENDINGSTATUS
  GetStatus()
  {
    return m_status;
  }

  void
  SetStatus(DBPENDINGSTATUS status)
  {
    m_status = status;
  }

  bool
  IsInserted()
  {
    return m_fInserted;
  }

  void
  SetInserted(bool fInserted = true)
  {
    m_fInserted = fInserted;
  }

  char*
  GetData()
  {
    return m_pbData;
  }

private:

  //                            | m_iRef |  m_status   | m_pbData 
  // ---------------------------+--------+-------------+----------
  // upon construction          |   0    |	0      |   NULL   
  // upon initialization        |   0    |	0      | not NULL 
  // the row was deleted        |  >= 1  | _INVALIDROW |   NULL   
  // while holding data         |  >= 1  | _UNCHANGED  | not NULL 
  // while holding pending data |  >= 0  |   _NEW or   | not NULL 
  //                            |        | _CHANGED or |          
  //                            |        |  _DELETED   |          

  LONG m_iRef;
  DBPENDINGSTATUS m_status;
  bool m_fInserted;
  char* m_pbData;

  RowData()
  {
    Reset();
  }

  // no destructor -- destruction is managed by one of the *RowPolicy classes.

  void
  Reset()
  {
    m_iRef = 0;
    m_status = 0;
    m_fInserted = false;
    m_pbData = NULL;
  }

  void
  Init(char* pbData)
  {
    assert(m_iRef == 0 && m_status == 0 && m_pbData == NULL);
    m_pbData = pbData;
  }

  friend class ReleaseRowsPolicy;
  friend class CanHoldRowsPolicy;
  friend class ColumnsRowsPolicy;
};


class AbstractRowPolicy
{
public:

  virtual bool HoldsRows() = 0;

  // Might be used by IRowset::RestartPosition() to ensure that
  // all record size dependent memory is released to allow for
  // handling of the DB_S_COLUMNSCHANGED condition.
  virtual void ReleaseAllRows() = 0;

  virtual HRESULT AllocateRows(HROW hRowBase, DBCOUNTITEM cRows, const DataRecordInfo* info) = 0;
  virtual RowData* GetRowData(HROW hRow) = 0;
  virtual void ReleaseRowData(HROW hRow) = 0;
  virtual void DeleteRow(RowData* pRowData) = 0;

  virtual DBCOUNTITEM GetActiveRows() = 0;
  virtual void GetActiveRowHandles(HROW rghRows[]) = 0;
};


class ReleaseRowsPolicy : public AbstractRowPolicy
{
public:

  ReleaseRowsPolicy()
  {
    m_hRowBase = 0;
    m_cHeldRows = 0;
    m_pbRows = NULL;
    m_cMaxRows = 0;
  }

  ~ReleaseRowsPolicy()
  {
    Release();
  }

  void Release();

  virtual bool HoldsRows();
  virtual void ReleaseAllRows();
  virtual HRESULT AllocateRows(HROW hRowBase, DBCOUNTITEM cRows, const DataRecordInfo* info);
  virtual RowData* GetRowData(HROW hRow);
  virtual void ReleaseRowData(HROW hRow);
  virtual void DeleteRow(RowData* pRowData);
  virtual DBCOUNTITEM GetActiveRows();
  virtual void GetActiveRowHandles(HROW rghRows[]);

private:

  HROW m_hRowBase;
  DBCOUNTITEM m_cHeldRows;
  std::vector<RowData> m_rows;
  char* m_pbRows;
  DBCOUNTITEM m_cMaxRows;
};


class CanHoldRowsPolicy : public AbstractRowPolicy
{
public:

  CanHoldRowsPolicy()
  {
  }

  ~CanHoldRowsPolicy()
  {
    Release();
  }

  void Release();

  virtual bool HoldsRows();
  virtual void ReleaseAllRows();
  virtual HRESULT AllocateRows(HROW hRowBase, DBCOUNTITEM cRows, const DataRecordInfo* info);
  virtual RowData* GetRowData(HROW hRow);
  virtual void ReleaseRowData(HROW hRow);
  virtual void DeleteRow(RowData* pRowData);
  virtual DBCOUNTITEM GetActiveRows();
  virtual void GetActiveRowHandles(HROW rghRows[]);

protected:

  typedef std::map<HROW, RowData> Map;
  typedef Map::value_type Elt;

  Map m_rows;
};


class ColumnsRowsPolicy : public AbstractRowPolicy
{
public:

  ColumnsRowsPolicy()
  {
    m_cRows = 0;
    m_cHeldRows = 0;
    m_rgRows = NULL;
    m_pbRows = NULL;
  }

  ~ColumnsRowsPolicy()
  {
    Release();
  }

  HRESULT Init(DBCOUNTITEM cRows, const DataRecordInfo* info);

  void Release();

  virtual bool HoldsRows();
  virtual void ReleaseAllRows();
  virtual HRESULT AllocateRows(HROW hRowBase, DBCOUNTITEM cRows, const DataRecordInfo* info);
  virtual RowData* GetRowData(HROW hRow);
  virtual void ReleaseRowData(HROW hRow);
  virtual void DeleteRow(RowData* pRowData);
  virtual DBCOUNTITEM GetActiveRows();
  virtual void GetActiveRowHandles(HROW rghRows[]);

private:

  DBCOUNTITEM m_cRows;
  DBCOUNTITEM m_cHeldRows;
  RowData* m_rgRows;
  char* m_pbRows;
};


class AbstractRowsetPolicy
{
public:

  virtual HRESULT GetNextRows(DBROWOFFSET lRowsOffset, DBROWCOUNT cRows) = 0;
  virtual DBCOUNTITEM GetRowsObtained() = 0;
  virtual void GetRowHandlesObtained(HROW* rghRows) = 0;
  virtual HRESULT RestartPosition() = 0;
  virtual GetDataHandler* GetGetDataHandler() = 0;
  virtual SetDataHandler* GetSetDataHandler() = 0;
  virtual bool IsStreamObjectAlive() = 0;
  virtual void KillStreamObject() = 0;
};


class AbstractPositionalRowsetPolicy
{
public:

  virtual DBCOUNTITEM GetRowCount() = 0;
  virtual DBCOUNTITEM GetPosition(bool fStandardBookmark, ULONG ulBookmark) = 0;
  virtual HRESULT GetRowsAtPosition(bool fStandardBookmark, ULONG ulBookmark,
				    DBROWOFFSET lRowsOffset, DBROWCOUNT cRows) = 0;
  virtual HRESULT GetRowByBookmark(ULONG ulBookmark) = 0;
};


class AbstractChangeableRowsetPolicy
{
public:

  virtual HRESULT CreateRow(HROW& hRow) = 0;
  virtual HRESULT InsertRow(HROW hRow) = 0;
  virtual HRESULT UpdateRow(HROW hRow, bool fDeferred) = 0;
  virtual HRESULT DeleteRow(HROW hRow) = 0;
  virtual HRESULT ResyncRow(HROW hRow, char* pbData) = 0;
};


class RowsetPolicy : public AbstractRowsetPolicy, public GetDataHandler, public SetDataHandler
{
public:

  RowsetPolicy(RowsetInfo* pRowsetInfo, AbstractRowPolicy* pRowPolicy);

  virtual ~RowsetPolicy();

  void Release();

  HRESULT Init(Statement& stmt);

  virtual HRESULT ResetLongData(HROW iRecordID, DBORDINAL iFieldOrdinal);
  virtual HRESULT GetLongData(HROW iRecordID, DBORDINAL iFieldOrdinal, SQLSMALLINT wSqlCType,
			      char* pv, DBLENGTH cb, SQLLEN& rcb);
  virtual HRESULT CreateStreamObject(HROW iRecordID, DBORDINAL iFieldOrdinal, SQLSMALLINT wSqlCType,
				     REFIID riid, IUnknown** ppUnk);
  virtual HRESULT SetDataAtExec(HROW iRecordID, DBORDINAL iFieldOrdinal, SQLSMALLINT wSqlCType,
				DBCOUNTITEM iBinding);
  virtual HRESULT GetDataAtExec(HROW& iRecordID, DBCOUNTITEM& iBinding);
  virtual HRESULT PutDataAtExec(char* pv, SQLINTEGER cb);

  virtual DBCOUNTITEM GetRowsObtained();

  virtual GetDataHandler* GetGetDataHandler();
  virtual SetDataHandler* GetSetDataHandler();
  virtual bool IsStreamObjectAlive();
  virtual void KillStreamObject();

protected:

  HRESULT SetRowArraySize(DBCOUNTITEM cRows);
  HRESULT BindRows(HROW hRowBase, DBCOUNTITEM cRows);
  HRESULT InitRow(ULONG iRow, RowData* pRowData, char* pbRowData = NULL);
  HRESULT InitRows();
  HRESULT SetRowPos(SQLSETPOSIROW iPosition);

  virtual HRESULT SnatchRow(HROW hRow);
  virtual HRESULT BookmarkRow(HROW hRow, ULONG ulBookmark);

  Statement m_statement;
  const RowsetInfo* m_pRowsetInfo;
  AbstractRowPolicy* m_pRowPolicy;
  HROW m_hRowBase;
  DBCOUNTITEM m_cRows;
  DBCOUNTITEM m_cRowsMax;
  SQLUINTEGER m_cRowsFetched;
  SQLUSMALLINT* m_rgRowStatus;
  SQLUINTEGER m_ulFetchBookmark;
  SQLUINTEGER m_cbBindOffset; // Offset between initially allocated row buffer and the current one.
  char* m_pbBindOrigin;// This is used to calculate bind offset.

private:

  LobStreamSyncObj* m_pStreamSync;
  CGetDataSequentialStream* m_pStream;
};


class CommandHandler;

class ForwardOnlyPolicy : public RowsetPolicy
{
public:

  ForwardOnlyPolicy(RowsetInfo* pRowsetInfo, AbstractRowPolicy* pRowPolicy, CommandHandler* pCommandHandler)
    : RowsetPolicy(pRowsetInfo, pRowPolicy)
  {
    m_pCommandHandler = pCommandHandler;
  }

  virtual HRESULT GetNextRows(DBROWOFFSET lRowsOffset, DBROWCOUNT cRows);
  virtual void GetRowHandlesObtained(HROW* rghRows);
  virtual HRESULT RestartPosition();

private:

  HRESULT SkipNextRows(DBCOUNTITEM lRowsOffset);
  HRESULT FetchNextRows();

  CommandHandler* m_pCommandHandler;
};


class ScrollablePolicy : public RowsetPolicy
{
public:

  ScrollablePolicy(RowsetInfo* pRowsetInfo, AbstractRowPolicy* pRowPolicy)
    : RowsetPolicy(pRowsetInfo, pRowPolicy)
  {
    m_fStartPos = true;
  }

  virtual HRESULT GetNextRows(DBROWOFFSET lRowsOffset, DBROWCOUNT cRows);
  virtual void GetRowHandlesObtained(HROW* rghRows);
  virtual HRESULT RestartPosition();

  virtual HRESULT CreateRow(HROW& hRow);
  virtual HRESULT InsertRow(HROW hRow);
  virtual HRESULT UpdateRow(HROW hRow, bool fDeferred);
  virtual HRESULT DeleteRow(HROW hRow);
  virtual HRESULT ResyncRow(HROW hRow, char* pbData);

protected:

  HRESULT BindColumns(char* pbRowData, SQLSETPOSIROW iPosition, bool fDeferred);
  void UnbindColumns(char* pbRowData, bool fDeferred);

  HRESULT Fetch(SQLSMALLINT dwOrientation, DBROWOFFSET lRowsOffset);
  HRESULT Refresh(SQLSETPOSIROW iPosition);
  HRESULT Update(SQLSETPOSIROW iPosition);
  HRESULT Delete(SQLSETPOSIROW iPosition);
  HRESULT Insert(SQLSETPOSIROW iPosition);
  HRESULT Insert();

  bool m_fStartPos;
  bool m_fBackward;
};


class PositionalPolicy : public ScrollablePolicy
{
public:

  PositionalPolicy(RowsetInfo* pRowsetInfo, AbstractRowPolicy* pRowPolicy)
    : ScrollablePolicy(pRowsetInfo, pRowPolicy)
  {
  }

  HRESULT Init(Statement& stmt);

  virtual HRESULT GetNextRows(DBROWOFFSET lRowsOffset, DBROWCOUNT cRows);
  virtual DBCOUNTITEM GetRowsObtained();

  virtual HRESULT CreateRow(HROW& hRow);
  virtual HRESULT InsertRow(HROW hRow);

  virtual HRESULT GetRowsAtPosition(bool fStandardBookmark, ULONG ulBookmark, DBROWOFFSET lRowsOffset, DBROWCOUNT cRows);
  virtual HRESULT GetRowByBookmark(ULONG ulBookmark);
  virtual DBCOUNTITEM GetRowCount();
  virtual DBCOUNTITEM GetPosition(bool fStandardBookmark, ULONG ulBookmark);

protected:

  virtual HRESULT SnatchRow(HROW hRow);
  virtual HRESULT BookmarkRow(HROW hRow, ULONG ulBookmark);

private:

  HRESULT InitRowCount(DBCOUNTITEM& cRows);

  // The interpretation of the iNextFetch position is as follows. There are rows numbered
  // from 1 to m_cTotalRows. If iNextFetch is equal to 0 then the fetch position is before
  // the first row. In this position a forward fetch will get the first row and a backward
  // fetch will get the end-of-rowset. If iNextFetch is equal to 1 then the fetch position
  // is after the first row and before the second row. In this position a forward fetch will
  // get the second row and a backward fetch will get the first row. If iNextFetch is equal
  // to m_cTotalRows then the next fetch position is after the last row. In this position a
  // forward fetch will get the end-of-rowset and a backward fetch will get the last row.
  HROW m_nNextFetch;
  DBCOUNTITEM m_cTotalRows;
  DBROWCOUNT m_cRowsObtained;
  HROW m_hNextNewRow;
  bm_map_t m_bookmarks;
};


class SyntheticPolicy : public AbstractRowsetPolicy
{
public:

  SyntheticPolicy(RowsetInfo* pRowsetInfo, AbstractRowPolicy* pRowPolicy);

  HRESULT Init(DBCOUNTITEM cRows);

  virtual HRESULT GetNextRows(DBROWOFFSET lRowsOffset, DBROWCOUNT cRows);
  virtual DBCOUNTITEM GetRowsObtained();
  virtual void GetRowHandlesObtained(HROW* rghRows);
  virtual HRESULT RestartPosition();

  virtual GetDataHandler* GetGetDataHandler();
  virtual SetDataHandler* GetSetDataHandler();
  virtual bool IsStreamObjectAlive();
  virtual void KillStreamObject();

private:

  HRESULT InitRows(HROW hRowBase, DBCOUNTITEM cRows);

  const RowsetInfo* m_pRowsetInfo;
  AbstractRowPolicy* m_pRowPolicy;
  DBCOUNTITEM m_cTotalRows;
  bool m_fStartPos;
  bool m_fBackward;
  HROW m_nNextFetch;
  DBROWCOUNT m_cRowsObtained;
  HROW m_hRowBase;
};


#endif

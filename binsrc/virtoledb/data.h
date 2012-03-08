/*  data.h
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

#ifndef DATA_H
#define DATA_H

#include "db.h"
#include "syncobj.h"
#include "error.h"


// Currently native_type_t represents SQL_* types
// (like SQL_CHAR, SQL_INTEGER, SQL_BINARY, etc).
// Eventually this might be changed to DV_* types.

typedef SQLSMALLINT native_type_t;
typedef SQLUINTEGER native_size_t;
typedef SQLSMALLINT native_scale_t;


class DataType
{
public:

  DataType (native_type_t wNativeType, DBTYPE wOledbType, bool fFixed, bool fLong, bool fNumber, bool fUnsigned);

  native_type_t
  GetNativeType () const
  {
    return m_wNativeType;
  }

  DBTYPE
  GetOledbType () const
  {
    return m_wOledbType;
  }

  bool
  IsFixed () const
  {
    return m_fFixed;
  }

  bool
  IsLong () const
  {
    return m_fLong;
  }

  bool
  IsNumber () const
  {
    return m_fNumber;
  }

  bool
  IsUnsigned () const
  {
    return m_fUnsigned;
  }

  virtual native_size_t RectifySize (native_size_t ulDataSize) const;
  virtual native_scale_t RectifyDecimalDigits (native_scale_t iDecimalDigits) const;

  virtual DBLENGTH GetOledbSize (native_size_t ulDataSize) const;
  virtual BYTE GetOledbPrecision (native_size_t ulDataSize) const;
  virtual BYTE GetOledbScale (native_scale_t iDecimalDigits) const;

  BYTE
  GetOledbScaleForParameterInfo (native_scale_t iDecimalDigits) const
  {
    return IsNumber () ? (BYTE) iDecimalDigits : GetOledbScale (iDecimalDigits);
  }

private:

  native_type_t m_wNativeType;
  DBTYPE m_wOledbType;
  bool m_fFixed;
  bool m_fLong;
  bool m_fNumber;
  bool m_fUnsigned;
};


// BufferType describes ``internal'' representation of a data field.
// That is the information about memory layout of the field. In certain
// cases the ``internal'' type differs from the actual type. For instance,
// BSTR fields are kept internally as WSTR. This can be also the case for
// optimized accessors -- once they are implemented.
class BufferType
{
public:

  BufferType (DBTYPE wOledbType, SQLSMALLINT wSqlCType, ULONG ulAlignment);

  DBTYPE
  GetOledbType () const
  {
    return m_wOledbType;
  }

  SQLSMALLINT
  GetSqlCType () const
  {
    return m_wSqlCType;
  }

  ULONG
  GetAlignment () const
  {
    return m_ulAlignment;
  }

  virtual ULONG GetBufferSize (ULONG ulDataSize) const = 0;

private:

  DBTYPE m_wOledbType;
  SQLSMALLINT m_wSqlCType;
  ULONG m_ulAlignment;
};


class DataFieldInfo
{
public:

  DataFieldInfo();

  bool
  IsSet () const
  {
    return m_pDataType != NULL;
  }

  bool
  IsComplete () const
  {
    return m_pBufferType != NULL;
  }

  // Get field name.
  const ostring&
  GetName () const
  {
    return m_name;
  }

  ULONG
  GetFlags () const
  {
    return m_flags;
  }

  bool
  IsLong () const
  {
    assert (IsSet ());
    return m_pDataType->IsLong ();
  }

  bool
  IsFixed () const
  {
    assert (IsSet ());
    return m_pDataType->IsFixed ();
  }

  bool
  IsUnsigned () const
  {
    assert (IsSet ());
    return m_pDataType->IsUnsigned ();
  }

  SQLUINTEGER
  GetOdbcColumnSize () const
  {
    assert (IsSet ());
    return m_field_size;
  }

  SQLSMALLINT
  GetOdbcDecimalDigits () const
  {
    assert (IsSet ());
    return m_decimal_digits;
  }

  DBTYPE
  GetOledbType () const
  {
    assert (IsSet ());
    return m_pDataType->GetOledbType ();
  }

  DBLENGTH
  GetOledbSize () const
  {
    assert (IsSet ());
    return m_pDataType->GetOledbSize (m_field_size);
  }

  BYTE
  GetOledbPrecision () const
  {
    assert (IsSet ());
    return m_pDataType->GetOledbPrecision (m_field_size);
  }

  BYTE
  GetOledbScale () const
  {
    assert (IsSet ());
    return m_pDataType->GetOledbScale (m_decimal_digits);
  }

  BYTE
  GetOledbScaleForParameterInfo () const
  {
    assert (IsSet ());
    return m_pDataType->GetOledbScaleForParameterInfo (m_decimal_digits);
  }

  SQLSMALLINT
  GetSqlType () const
  {
    assert (IsSet ());
    return m_pDataType->GetNativeType ();
  }

  SQLSMALLINT
  GetSqlCType () const
  {
    assert (IsComplete ());
    return m_pBufferType->GetSqlCType();
  }

  DBTYPE
  GetInternalDBType () const
  {
    assert (IsComplete ());
    return m_pBufferType->GetOledbType();
  }

  ULONG
  GetInternalLength () const
  {
    assert (IsComplete ());
    return m_internal_length;
  }

  ULONG
  GetInternalOffset () const
  {
    assert (IsComplete ());
    return m_internal_offset;
  }

  HRESULT Optimize (DBTYPE type);
  HRESULT Complete (ULONG offset);

  static bool
  IsValidTypeName (const LPOLESTR pwszDataSourceType)
  {
    const DataType* type = MapNativeType (pwszDataSourceType);
    return type == NULL ? false : true;
  }

  //static SQLSMALLINT DataSourceTypeToSql(const LPOLESTR pwszDataSourceType);

protected:

  // Set all field info (except name and flags).
  HRESULT SetNativeFieldInfo (native_type_t wNativeType, native_size_t ulDataSize, native_scale_t iDecimalDigits);
  HRESULT SetNativeFieldInfo (const LPOLESTR pwszDataSourceType, DBLENGTH ulDataSize, BYTE bPrecision, BYTE bScale);
  HRESULT SetSyntheticFieldInfo (DBTYPE wOledbType, native_size_t ulDataSize, native_scale_t iDecimalDigits);

  // Set field name.
  HRESULT SetName(const OLECHAR* name);

  void
  SetFlags(ULONG flags)
  {
    m_flags = flags;
  }

private:

  static const DataType* MapNativeType (native_type_t wNativeType);
  static const DataType* MapNativeType (const LPOLESTR pwszDataSourceType);
  static const DataType* MapSyntheticType (DBTYPE wOledbType);

  static const BufferType* MapTypeToBuffer (const DataType *pDataType);
  static const BufferType* OptimizeBufferType (const DataType *pDataType, DBTYPE wOledbType);

  ostring m_name;
  const DataType* m_pDataType;
  const BufferType* m_pBufferType;
  native_size_t m_field_size;
  native_scale_t m_decimal_digits;
  ULONG m_internal_length;
  ULONG m_internal_offset;
  ULONG m_flags;
};


class DataRecordInfo
{
public:

  DataRecordInfo();

  HRESULT Init();
  void Release();

  virtual ULONG GetFieldCount() const = 0;
  virtual const DataFieldInfo& GetFieldInfo(ULONG index) const = 0;

  HRESULT Optimize(ULONG iField, DBTYPE type);
  HRESULT Complete(size_t overhead = 0);

  bool
  IsInitialized() const
  {
    return m_status == STATUS_INITIALIZED || m_status == STATUS_COMPLETED;
  }

  bool
  IsCompleted() const
  {
    return m_status == STATUS_COMPLETED;
  }

  ULONG
  GetRecordSize() const
  {
    assert(IsCompleted());
    return m_cbRecordSize;
  }

  bool
  HasLongData() const
  {
    assert(IsCompleted());
    return m_fHasLongData;
  }

  virtual ULONG
  OrdinalToIndex(DBORDINAL ordinal) const
  {
    return (ULONG) ordinal - 1;
  }

  virtual DBORDINAL
  IndexToOrdinal(ULONG index) const
  {
    return index + 1;
  }

  char*
  GetFieldBuffer(char* pbRecordData, ULONG iField) const
  {
    return pbRecordData + GetFieldInfo(iField).GetInternalOffset();
  }

  SQLLEN
  GetFieldLength(char* pbRecordData, ULONG iField) const
  {
    return ((SQLLEN*) (pbRecordData + GetExtraSize()))[iField];
  }

  void
  SetFieldLength(char* pbRecordData, ULONG iField, SQLLEN cbLength) const
  {
    ((SQLLEN*) (pbRecordData + GetExtraSize()))[iField] = cbLength;
  }

  SQLLEN*
  GetFieldLengthPtr(char* pbRecordData, ULONG iField) const
  {
    return ((SQLLEN*) (pbRecordData + GetExtraSize())) + iField;
  }

protected:

  virtual ULONG	
  GetExtraSize() const
  {
    return 0;
  }

private:

  enum RecordInfoStatus
  {
    STATUS_UNINITIALIZED,
    STATUS_INITIALIZED,
    STATUS_COMPLETED
  };

  RecordInfoStatus m_status;
  ULONG m_cbRecordSize;
  bool m_fHasLongData;

  // forbid copying
  DataRecordInfo(const DataRecordInfo&);
  DataRecordInfo& operator=(const DataRecordInfo&);
};


class DataAccessor
{
public:

  DataAccessor ()
  {
    m_rgBindings = NULL;
    m_cBindings = 0;
    m_dwAccessorFlags = 0;
    m_cbRowSize = 0;
    m_iRefCount = 0;
  }

  ~DataAccessor ()
  {
    FreeBindings ();
  }

  HRESULT Init (DBACCESSORFLAGS dwAccessorFlags, DBCOUNTITEM cBindings, const DBBINDING rgBindings[], DBLENGTH cbRowSize);
  HRESULT Init (const DataAccessor& accessor, DBACCESSORFLAGS dwAccessorFlags);
  
  LONG
  AddRef ()
  {
    LOGCALL (("DataAccessor::AddRef (), %d\n", m_iRefCount + 1));
    return ++m_iRefCount;
  }
  
  LONG
  Release ()
  {
    LOGCALL (("DataAccessor::Release (), %d\n", m_iRefCount - 1));
    return --m_iRefCount;
  }

  DBCOUNTITEM
  GetBindingCount () const
  {
    return m_cBindings;
  }

  const DBBINDING&
  GetBinding (DBCOUNTITEM iBinding) const
  {
    assert (iBinding < m_cBindings);
    return m_rgBindings[iBinding];
  }
  
  const DBBINDING*
  GetBindings ()
  {
    return m_rgBindings;
  }

  DBACCESSORFLAGS
  GetFlags () const
  {
    return m_dwAccessorFlags;
  }

  DBLENGTH
  GetRowSize () const
  {
    return m_cbRowSize;
  }

private:

  HRESULT CopyBindings (DBCOUNTITEM cBindings, const DBBINDING rgBindings[]);
  void FreeBindings ();

  DBBINDING* m_rgBindings;
  DBCOUNTITEM m_cBindings;
  DBACCESSORFLAGS m_dwAccessorFlags;
  DBLENGTH m_cbRowSize;
  LONG m_iRefCount;
};


class GetDataHandler
{
public:

  // The return codes are:
  // S_OK if everything's ok,
  // DB_E_OBJECTOPEN if a stream object was already created,
  // DB_E_COLUMNUNAVAILABLE if cannot retreive the specified BLOB.
  // and others (E_FAIL) as appropriate,
  virtual HRESULT ResetLongData(HROW iRecordID, DBORDINAL iFieldOrdinal) = 0;

  // The return codes are:
  // S_OK if everything's ok,
  // S_FALSE if no more data available,
  // and others (E_OUTOFMEMORY, E_FAIL) as appropriate,
  virtual HRESULT GetLongData(HROW iRecordID, DBORDINAL iFieldOrdinal, SQLSMALLINT wSqlCType,
			      char* pv, DBLENGTH cb, SQLLEN& rcb) = 0;

  // The return codes are:
  // S_OK if everything's ok,
  // S_FALSE on attempt to create stream object on the null value,
  // DB_E_OBJECTOPEN if another stream object was already created,
  // DB_E_COLUMNUNAVAILABLE if cannot retreive the specified BLOB.
  // and others (E_OUTOFMEMORY, E_FAIL) as appropriate,
  virtual HRESULT CreateStreamObject(HROW iRecordID, DBORDINAL iFieldOrdinal, SQLSMALLINT wSqlCType,
				     REFIID riid, IUnknown** ppUnk) = 0;

};


class SetDataHandler
{
public:

  virtual HRESULT SetDataAtExec(HROW iRecordID, DBORDINAL iFieldOrdinal, SQLSMALLINT wSqlCType,
				DBCOUNTITEM iBinding) = 0;
  virtual HRESULT GetDataAtExec(HROW& iRecordID, DBCOUNTITEM& iBinding) = 0;
  virtual HRESULT PutDataAtExec(char* pv, SQLINTEGER cb) = 0;
};


class DataTransferHandler
{
public:

  DataTransferHandler();
  ~DataTransferHandler();

  void Release();

  HRESULT Init();

  IDataConvert*
  GetDataConvert()
  {
    return m_pIDataConvert;
  }

  DBBINDSTATUS ValidateBinding(DBACCESSORFLAGS dwAccessorFlags, const DBBINDING& binding);
  DBBINDSTATUS MetadataValidateBinding(const DataRecordInfo& info, const DBBINDING& binding);
  HRESULT CanConvert(DBTYPE wFromType, DBTYPE wToType, DBCONVERTFLAGS dwConvertFlags, bool fIsCommand);

  HRESULT GetData(const DataRecordInfo& info, GetDataHandler* pgd, HROW iRecordID,
		  char* pbProviderData, const DataAccessor& accessor, DBCOUNTITEM iBinding,
		  char* pbConsumerData, bool fIsParameter);

  HRESULT SetData(const DataRecordInfo& info, SetDataHandler* psd, HROW iRecordID,
		  char* pbProviderData, const DataAccessor& accessor, DBCOUNTITEM iBinding,
		  char* pbConsumerData, bool fIsParameter);

  HRESULT SetDataAtExec(const DataRecordInfo& info, SetDataHandler* pSetData,
			const DataAccessor& accessor,
			char* pbConsumerData, bool fIsParameter);

#if DEBUG
  static void LogFieldData(ULONG iFieldOrdinal, const DataFieldInfo& info,
			   const char* pbValue, LONG cbLength);
#endif

private:

  IDataConvert* m_pIDataConvert;

  // forbid copying
  DataTransferHandler(const DataTransferHandler&);
  DataTransferHandler& operator=(const DataTransferHandler&);
};


#endif

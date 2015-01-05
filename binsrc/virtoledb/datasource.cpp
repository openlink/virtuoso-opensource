/*  datasource.cpp
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

#include "headers.h"
#include "asserts.h"
#include "datasource.h"
#include "session.h"
#include "db.h"
#include "util.h"
#include "filedsn.h"
#include <fstream>

#include "sqlver.h"
#define LT(t) L ## t
#define LM(m) LT(m)
#define PROVIDER_VER LM(DBMS_SRV_VER_ONLY) L"." LM(DBMS_SRV_GEN_MAJOR) LM(DBMS_SRV_GEN_MINOR)

// PropertySetInfos defined elsewhere.
extern PropertySetInfo g_SessionPropertySetInfo;
extern PropertySetInfo g_RowsetPropertySetInfo;

////////////////////////////////////////////////////////////////////////
// DBInitPropertySet

static PropertyInfo dbinit_properties[] =
{
  {
    DBPROP_AUTH_USERID,
    DBPROPFLAGS_READ | DBPROPFLAGS_WRITE | DBPROPFLAGS_REQUIRED,
    VT_BSTR,
    L"User ID"
  },
  {
    DBPROP_AUTH_PASSWORD,
    DBPROPFLAGS_READ | DBPROPFLAGS_WRITE | DBPROPFLAGS_REQUIRED,
    VT_BSTR,
    L"Password"
  },
  {
    DBPROP_AUTH_PERSIST_SENSITIVE_AUTHINFO,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ | DBPROPFLAGS_WRITE,
    VT_BOOL,
    L"Persist Security Info",
    VARIANT_FALSE
  },
  {
    DBPROP_INIT_DATASOURCE,
    DBPROPFLAGS_READ | DBPROPFLAGS_WRITE | DBPROPFLAGS_REQUIRED,
    VT_BSTR,
    L"Data Source"
  },
  {
    DBPROP_INIT_CATALOG,
    DBPROPFLAGS_READ | DBPROPFLAGS_WRITE,
    VT_BSTR,
    L"Initial Catalog"
  },
  {
    DBPROP_INIT_PROVIDERSTRING,
    DBPROPFLAGS_READ | DBPROPFLAGS_WRITE,
    VT_BSTR,
    L"Extended Properties"
  },
  {
    DBPROP_INIT_HWND,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ | DBPROPFLAGS_WRITE,
    VT_I4,
    L"Window Handle",
    0
  },
  {
    DBPROP_INIT_PROMPT,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ | DBPROPFLAGS_WRITE,
    VT_I2,
    L"Prompt",
    DBPROMPT_COMPLETE
  },
  {
    DBPROP_INIT_TIMEOUT,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ | DBPROPFLAGS_WRITE,
    VT_I4,
    L"Connect Timeout",
    0
  },
  {
    DBPROP_INIT_OLEDBSERVICES,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ | DBPROPFLAGS_WRITE,
    VT_I4,
    L"OLE DB Services",
    DBPROPVAL_OS_ENABLEALL
  },
};

PropertySetInfo g_DBInitPropertySetInfo(DBPROPSET_DBINIT,
					DBPROPFLAGS_DBINIT,
					sizeof dbinit_properties / sizeof dbinit_properties[0],
					dbinit_properties);

class DBInitPropertySet : public PropertySet
{

  class PropertyPrompt : public PropertyI2
  {
  public:

    virtual bool
    IsValidValue(const VARIANT *value) const
    {
      if (V_VT(value) == VT_EMPTY)
	return true;
      if (PropertyI2::IsValidValue(value))
	switch(V_I2(value))
	  {
	  case DBPROMPT_PROMPT:
	  case DBPROMPT_COMPLETE:
	  case DBPROMPT_COMPLETEREQUIRED:
	  case DBPROMPT_NOPROMPT:
	    return true;
	  }
      return false;
    }

  };

  class PropertyTimeout : public PropertyI4
  {
  public:

    virtual bool
    IsValidValue(const VARIANT *value) const
    {
      if (V_VT(value) == VT_EMPTY)
	return true;
      if (PropertyI4::IsValidValue(value))
	return V_I4(value) >= 0;
      return false;
    }

  };

public:

  DBInitPropertySet::DBInitPropertySet()
    : PropertySet(g_DBInitPropertySetInfo, DBPROPFLAGS_READ | DBPROPFLAGS_WRITE)
  {
  }

  DBInitPropertySet::~DBInitPropertySet()
  {
  }

  virtual Property* GetProperty(DBPROPID id);

  PropertyBSTR prop_AUTH_USERID;
  PropertyBSTR prop_AUTH_PASSWORD;
  PropertyBool prop_AUTH_PERSIST_SENSITIVE_AUTHINFO;
  PropertyBSTR prop_INIT_DATASOURCE;
  PropertyBSTR prop_INIT_CATALOG;
  PropertyBSTR prop_INIT_PROVIDERSTRING;
  PropertyI4 prop_INIT_HWND;
  PropertyPrompt prop_INIT_PROMPT;
  PropertyTimeout prop_INIT_TIMEOUT;
  PropertyI4 prop_INIT_OLEDBSERVICES;
};

Property*
DBInitPropertySet::GetProperty(DBPROPID id)
{
  switch (id)
    {
    case DBPROP_AUTH_USERID:		return &prop_AUTH_USERID;
    case DBPROP_AUTH_PASSWORD:		return &prop_AUTH_PASSWORD;
    case DBPROP_AUTH_PERSIST_SENSITIVE_AUTHINFO: return &prop_AUTH_PERSIST_SENSITIVE_AUTHINFO;
    case DBPROP_INIT_DATASOURCE:	return &prop_INIT_DATASOURCE;
    case DBPROP_INIT_CATALOG:		return &prop_INIT_CATALOG;
    case DBPROP_INIT_PROVIDERSTRING:    return &prop_INIT_PROVIDERSTRING;
    case DBPROP_INIT_HWND:		return &prop_INIT_HWND;
    case DBPROP_INIT_PROMPT:		return &prop_INIT_PROMPT;
    case DBPROP_INIT_TIMEOUT:		return &prop_INIT_TIMEOUT;
    case DBPROP_INIT_OLEDBSERVICES:	return &prop_INIT_OLEDBSERVICES;
    }
  return NULL;
}

////////////////////////////////////////////////////////////////////////
// VirtDBInitPropertySet

static PropertyInfo virtdbinit_properties[] =
{
  {
    VIRTPROP_INIT_ENCRYPT,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ | DBPROPFLAGS_WRITE,
    VT_BOOL,
    L"Encrypt Connection",
    VARIANT_FALSE
  },
  {
    VIRTPROP_AUTH_PKCS12FILE,
    DBPROPFLAGS_READ | DBPROPFLAGS_WRITE,
    VT_BSTR,
    L"PKCS #12 File",
  },
  {
    VIRTPROP_INIT_SHOWSYSTABLES,
    DBPROPFLAGS_READ | DBPROPFLAGS_WRITE,
    VT_BOOL,
    L"NoSysTables",
    VARIANT_FALSE
  }
};

PropertySetInfo g_VirtDBInitPropertySetInfo(DBPROPSET_VIRTUOSODBINIT,
					    DBPROPFLAGS_DBINIT,
					    sizeof virtdbinit_properties / sizeof virtdbinit_properties[0],
					    virtdbinit_properties);

class VirtDBInitPropertySet : public PropertySet
{
public:

  VirtDBInitPropertySet::VirtDBInitPropertySet()
    : PropertySet(g_VirtDBInitPropertySetInfo, DBPROPFLAGS_READ | DBPROPFLAGS_WRITE)
  {
  }

  VirtDBInitPropertySet::~VirtDBInitPropertySet()
  {
  }

  virtual Property* GetProperty(DBPROPID id);

  PropertyBool prop_INIT_ENCRYPT;
  PropertyBSTR prop_AUTH_PKCS12FILE;
  PropertyBool prop_INIT_SHOW_SYSTEMTABLES;
};

Property*
VirtDBInitPropertySet::GetProperty(DBPROPID id)
{
  switch (id)
    {
    case VIRTPROP_INIT_ENCRYPT:		return &prop_INIT_ENCRYPT;
    case VIRTPROP_AUTH_PKCS12FILE:	return &prop_AUTH_PKCS12FILE;
    case VIRTPROP_INIT_SHOWSYSTABLES:	return &prop_INIT_SHOW_SYSTEMTABLES;
    }
  return NULL;
}

////////////////////////////////////////////////////////////////////////
// DataSourcePropertySet

static PropertyInfo datasource_properties[] =
{
  {
    DBPROP_CURRENTCATALOG,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ | DBPROPFLAGS_WRITE,
    VT_BSTR,
    L"Current Catalog"
  },
  {
    DBPROP_MULTIPLECONNECTIONS,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ | DBPROPFLAGS_WRITE,
    VT_BOOL,
    L"Multiple Connections",
    VARIANT_TRUE
  },
  /*{
    DBPROP_RESETDATASOURCE,
    DBPROPFLAGS_READ | DBPROPFLAGS_WRITE,
    VT_I4,
    L"Reset Datasource"
  }*/
};

PropertySetInfo g_DataSourcePropertySetInfo(DBPROPSET_DATASOURCE,
					    DBPROPFLAGS_DATASOURCE,
					    sizeof datasource_properties / sizeof datasource_properties[0],
					    datasource_properties);

class DataSourcePropertySet : public PropertySet
{

  class PropertyCurrentCatalog : public PropertyBSTRBase
  {
  public:

    virtual HRESULT
    GetValue(const PropertySet* propset, const DBID& colid, BSTR& value) const
    {
      const DataSourcePropertySet* dspropset = dynamic_cast<const DataSourcePropertySet*>(propset);
      assert(dspropset != NULL);
      std::string catalog;
      HRESULT hr = dspropset->data_source->GetCurrentCatalog(catalog);
      if (FAILED(hr))
	return hr;
      return string2bstr(catalog, &value);
    }

    virtual HRESULT
    SetValue(PropertySet* propset, const DBID& colid, BSTR value)
    {
      DataSourcePropertySet* dspropset = dynamic_cast<DataSourcePropertySet*>(propset);
      assert(dspropset != NULL);
      std::string catalog;
      HRESULT hr = olestr2string(value, catalog);
      if (FAILED(hr))
	return hr;
      return dspropset->data_source->SetCurrentCatalog(catalog);
    }
  };

  class PropertyMultipleConnections : public PropertyBool
  {
  public:
  };

  class PropertyResetDatasource : public PropertyI4Base
  {
  public:

    virtual HRESULT
    GetValue(const PropertySet* propset, const DBID& colid, LONG& value) const
    {
      value = 0;
      return S_OK;
    }

    virtual HRESULT
    SetValue(PropertySet* propset, const DBID& colid, LONG value)
    {
      // TODO: What the hell should it do?
      return S_OK;
    }
  };

public:

  DataSourcePropertySet::DataSourcePropertySet(CDataSource* ds)
    : PropertySet(g_DataSourcePropertySetInfo, DBPROPFLAGS_READ | DBPROPFLAGS_WRITE)
  {
    data_source = ds;
  }

  DataSourcePropertySet::~DataSourcePropertySet()
  {
  }

  virtual Property*
  GetProperty(DBPROPID id)
  {
    switch (id)
      {
      case DBPROP_CURRENTCATALOG:	return &prop_current_catalog;
      case DBPROP_MULTIPLECONNECTIONS:	return &prop_multiple_connections;
      //case DBPROP_RESETDATASOURCE:	return &prop_reset_datasource;
      }
    return NULL;
  }

  CDataSource* data_source;
  PropertyCurrentCatalog prop_current_catalog;
  PropertyMultipleConnections prop_multiple_connections;
  PropertyResetDatasource prop_reset_datasource;
};

////////////////////////////////////////////////////////////////////////
// DataSourceInfoPropertySet

static PropertyInfo datasourceinfo_properties[] =
{
  {
    DBPROP_ACTIVESESSIONS,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ,
    VT_I4,
    L"Active Sessions",
    0
  },
  /*{
    DBPROP_ALTERCOLUMN,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ,
    VT_I4,
    L"Alter Column Support",
    0
  },*/
  {
    DBPROP_ASYNCTXNABORT,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ,
    VT_BOOL,
    L"Asynchable Abort",
    VARIANT_FALSE
  },
  {
    DBPROP_ASYNCTXNCOMMIT,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ,
    VT_BOOL,
    L"Asynchable Commit",
    VARIANT_FALSE
  },
  {
    DBPROP_BYREFACCESSORS,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ,
    VT_BOOL,
    L"Pass By Ref Accessors",
    VARIANT_FALSE
  },
  {
    DBPROP_CATALOGLOCATION,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ,
    VT_I4,
    L"Catalog Location",
    DBPROPVAL_CL_START
  },
  {
    DBPROP_CATALOGTERM,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ,
    VT_BSTR,
    L"Catalog Term",
    (LONG_PTR) L"qualifier"
  },
  {
    DBPROP_CATALOGUSAGE,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ,
    VT_I4,
    L"Catalog Usage",
    DBPROPVAL_CU_DML_STATEMENTS | DBPROPVAL_CU_TABLE_DEFINITION
    | DBPROPVAL_CU_INDEX_DEFINITION | DBPROPVAL_CU_PRIVILEGE_DEFINITION
  },
  {
    DBPROP_COLUMNDEFINITION,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ,
    VT_I4,
    L"Column Definition",
    DBPROPVAL_CD_NOTNULL
  },
  {
    DBPROP_COMSERVICES,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ,
    VT_I4,
    L"COM Service Support",
    0
  },
  {
    DBPROP_CONCATNULLBEHAVIOR,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ,
    VT_I4,
    L"NULL Concatenation Behavior",
    DBPROPVAL_CB_NULL
  },
  // TODO: Get the real data.
  {
    DBPROP_CONNECTIONSTATUS,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ,
    VT_I4,
    L"Connection Status",
    DBPROPVAL_CS_INITIALIZED
  },
  {
    DBPROP_DATASOURCENAME,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ,
    VT_BSTR,
    L"Data Source Name",
    (LONG_PTR) L""
  },
  // TODO: Get the real data.
  {
    DBPROP_DATASOURCEREADONLY,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ,
    VT_BOOL,
    L"Read-Only Data Source",
    VARIANT_FALSE
  },
  /*{
    DBPROP_DATASOURCE_TYPE,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ,
    VT_I4,
    L"Data Source Type",
    DBPROPVAL_DST_TDP
  },*/
  {
    DBPROP_DBMSNAME,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ,
    VT_BSTR,
    L"DBMS Name",
    (LONG_PTR) L"Virtuoso"
  },
  {
    DBPROP_DBMSVER,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ,
    VT_BSTR,
    L"DBMS Version",
    (LONG_PTR) L"00.00.0000"
  },
  {
    DBPROP_DSOTHREADMODEL,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ,
    VT_I4,
    L"Data Source Object Threading Model",
    DBPROPVAL_RT_FREETHREAD /*| DBPROPVAL_RT_APTMTTHREAD | DBPROPVAL_RT_SINGLETHREAD*/
  },
  /*{
    DBPROP_GENERATEURL,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ,
    VT_I4,
    L"URL Generation",
    DBPROPVAL_GU_NOTSUPPORTED
  },*/
  {
    DBPROP_GROUPBY,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ,
    VT_I4,
    L"GROUP BY Support",
    DBPROPVAL_GB_NO_RELATION
  },
  {
    DBPROP_HETEROGENEOUSTABLES,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ,
    VT_I4,
    L"Heterogeneous Table Support",
    DBPROPVAL_HT_DIFFERENT_CATALOGS
  },
  {
    DBPROP_IDENTIFIERCASE,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ,
    VT_I4,
    L"Identifier Case Sensitivity",
    DBPROPVAL_IC_SENSITIVE
  },
  {
    DBPROP_MAXINDEXSIZE,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ,
    VT_I4,
    L"Maximum Index Size",
    2000
  },
  {
    DBPROP_MAXOPENCHAPTERS,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ,
    VT_I4,
    L"Maximum Open Chapters",
    0
  },
  {
    DBPROP_MAXROWSIZE,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ,
    VT_I4,
    L"Maximum Row Size",
    2000
  },
  {
    DBPROP_MAXROWSIZEINCLUDESBLOB,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ,
    VT_BOOL,
    L"Maximum Row Size Includes BLOB",
    VARIANT_FALSE
  },
  {
    DBPROP_MAXTABLESINSELECT,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ,
    VT_I4,
    L"Maximum Tables in SELECT",
    0
  },
  {
    DBPROP_MULTIPLEPARAMSETS,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ,
    VT_BOOL,
    L"Multiple Parameter Sets",
    VARIANT_TRUE
  },
  {
    DBPROP_MULTIPLERESULTS,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ,
    VT_I4,
    L"Multiple Results",
    DBPROPVAL_MR_SUPPORTED
  },
  {
    DBPROP_MULTIPLESTORAGEOBJECTS,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ,
    VT_BOOL,
    L"Multiple Storage Objects",
    VARIANT_FALSE
  },
  {
    DBPROP_MULTITABLEUPDATE,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ,
    VT_BOOL,
    L"Multi-Table Update",
    VARIANT_TRUE
  },
  {
    DBPROP_NULLCOLLATION,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ,
    VT_I4,
    L"NULL Collation Order",
    DBPROPVAL_NC_HIGH
  },
  {
    DBPROP_OLEOBJECTS,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ,
    VT_I4,
    L"OLE Object Support",
    DBPROPVAL_OO_BLOB
  },
  {
    DBPROP_OPENROWSETSUPPORT,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ,
    VT_I4,
    L"Open Rowset Support",
    DBPROPVAL_ORS_TABLE
  },
  {
    DBPROP_ORDERBYCOLUMNSINSELECT,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ,
    VT_BOOL,
    L"ORDER BY Columns in Select List",
    VARIANT_FALSE
  },
  {
    DBPROP_OUTPUTPARAMETERAVAILABILITY,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ,
    VT_I4,
    L"Output Parameter Availability",
    DBPROPVAL_OA_ATROWRELEASE
  },
  {
    DBPROP_PERSISTENTIDTYPE,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ,
    VT_I4,
    L"Persistent ID Type",
    DBPROPVAL_PT_NAME,
  },
  {
    DBPROP_PREPAREABORTBEHAVIOR,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ,
    VT_I4,
    L"Prepare Abort Behavior",
    DBPROPVAL_CB_PRESERVE
  },
  {
    DBPROP_PREPARECOMMITBEHAVIOR,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ,
    VT_I4,
    L"Prepare Commit Behavior",
    DBPROPVAL_CB_PRESERVE
  },
  {
    DBPROP_PROCEDURETERM,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ,
    VT_BSTR,
    L"Procedure Term",
    (LONG_PTR) L"procedure"
  },
  {
    DBPROP_PROVIDERFRIENDLYNAME,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ,
    VT_BSTR,
    L"Provider Friendly Name",
    (LONG_PTR) L"OpenLink OLE DB Provider for Virtuoso"
  },
  {
    DBPROP_PROVIDERMEMORY,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ,
    VT_BOOL,
    L"Provider Owned Memory",
    VARIANT_TRUE
  },
  {
    DBPROP_PROVIDERFILENAME,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ,
    VT_BSTR,
    L"Provider Name",
    (LONG_PTR) L"virtoledb.dll"
  },
  {
    DBPROP_PROVIDEROLEDBVER,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ,
    VT_BSTR,
    L"OLE DB Version",
    (LONG_PTR) L"02.60"
  },
  {
    DBPROP_PROVIDERVER,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ,
    VT_BSTR,
    L"Provider Version",
    (LONG_PTR) PROVIDER_VER
  },
  {
    DBPROP_QUOTEDIDENTIFIERCASE,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ,
    VT_I4,
    L"Quoted Identifier Sensitivity",
    DBPROPVAL_IC_SENSITIVE
  },
  {
    DBPROP_ROWSETCONVERSIONSONCOMMAND,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ,
    VT_BOOL,
    L"Rowset Conversions on Command",
    VARIANT_TRUE
  },
  {
    DBPROP_SCHEMATERM,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ,
    VT_BSTR,
    L"Schema Term",
    (LONG_PTR) L"owner"
  },
  {
    DBPROP_SCHEMAUSAGE,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ,
    VT_I4,
    L"Schema Usage",
    DBPROPVAL_SU_DML_STATEMENTS | DBPROPVAL_SU_TABLE_DEFINITION
    | DBPROPVAL_SU_INDEX_DEFINITION | DBPROPVAL_SU_PRIVILEGE_DEFINITION
  },
  {
    DBPROP_SERVERNAME,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ,
    VT_BSTR,
    L"Server Name",
    (LONG_PTR) L""
  },
  {
    DBPROP_SQLSUPPORT,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ,
    VT_I4,
    L"SQL Support",
    DBPROPVAL_SQL_ODBC_MINIMUM | DBPROPVAL_SQL_ODBC_CORE /*| DBPROPVAL_SQL_ODBC_EXTENDED*/
    | DBPROPVAL_SQL_ANSI89_IEF | DBPROPVAL_SQL_ESCAPECLAUSES | DBPROPVAL_SQL_ANSI92_ENTRY
    /*| DBPROPVAL_SQL_FIPS_TRANSITIONAL | DBPROPVAL_SQL_ANSI92_INTERMEDIATE | DBPROPVAL_SQL_ANSI92_FULL*/
  },
  {
    DBPROP_STRUCTUREDSTORAGE,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ,
    VT_I4,
    L"Structured Storage",
    DBPROPVAL_SS_ISEQUENTIALSTREAM
  },
  {
    DBPROP_SUBQUERIES,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ,
    VT_I4,
    L"Subquery Support",
    DBPROPVAL_SQ_CORRELATEDSUBQUERIES | DBPROPVAL_SQ_COMPARISON | DBPROPVAL_SQ_EXISTS
    | DBPROPVAL_SQ_IN | DBPROPVAL_SQ_QUANTIFIED | DBPROPVAL_SQ_TABLE
  },
  // FIXME: What is actual txn and ddl relationship in Virtuoso?
  {
    DBPROP_SUPPORTEDTXNDDL,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ,
    VT_I4,
    L"Transaction DDL",
    DBPROPVAL_TC_DML
  },
  {
    DBPROP_SUPPORTEDTXNISOLEVELS,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ,
    VT_I4,
    L"Isolation Levels",
    DBPROPVAL_TI_READUNCOMMITTED | DBPROPVAL_TI_READCOMMITTED
    | DBPROPVAL_TI_REPEATABLEREAD | DBPROPVAL_TI_SERIALIZABLE
  },
  // FIXME: What's about actual txn retention.
  {
    DBPROP_SUPPORTEDTXNISORETAIN,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ,
    VT_I4,
    L"Isolation Retention",
    DBPROPVAL_TR_DONTCARE
  },
  {
    DBPROP_TABLESTATISTICS,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ,
    VT_I4,
    L"Table Statistics Support",
    0
  },
  {
    DBPROP_TABLETERM,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ,
    VT_BSTR,
    L"Table Term",
    (LONG_PTR) L"table"
  },
  {
    DBPROP_USERNAME,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ,
    VT_BSTR,
    L"User Name",
    (LONG_PTR) L""
  }
};

PropertySetInfo g_DataSourceInfoPropertySetInfo(DBPROPSET_DATASOURCEINFO,
						DBPROPFLAGS_DATASOURCEINFO,
						sizeof datasourceinfo_properties / sizeof datasourceinfo_properties[0],
						datasourceinfo_properties);

class DataSourceInfoPropertySet : public PropertySet
{
public:

  class PropertyActiveSessions : public PropertyI4RO
  {
  public:

    virtual HRESULT
    GetValue(const PropertySet* propset, const DBID& colid, LONG& value) const
    {
      const DataSourceInfoPropertySet* dspropset = dynamic_cast<const DataSourceInfoPropertySet*>(propset);
      assert(dspropset != NULL);
      return dspropset->data_source->GetActiveSessions(value);
    }
  };

  class PropertyDataSourceName : public PropertyBSTRRO
  {
  public:

    virtual HRESULT
    GetValue(const PropertySet* propset, const DBID& colid, BSTR& value) const
    {
      const DataSourceInfoPropertySet* dspropset = dynamic_cast<const DataSourceInfoPropertySet*>(propset);
      assert(dspropset != NULL);
      return dspropset->data_source->GetDataSourceName(value);
    }
  };

  class PropertyDBMSName : public PropertyBSTRRO
  {
  public:

    virtual HRESULT
    GetValue(const PropertySet* propset, const DBID& colid, BSTR& value) const
    {
      const DataSourceInfoPropertySet* dspropset = dynamic_cast<const DataSourceInfoPropertySet*>(propset);
      assert(dspropset != NULL);
      std::string s_value;
      HRESULT hr = dspropset->data_source->GetDBMSName(s_value);
      if (FAILED(hr))
	return hr;
      return string2bstr(s_value, &value);
    }
  };

  class PropertyDBMSVer : public PropertyBSTRRO
  {
  public:

    virtual HRESULT
    GetValue(const PropertySet* propset, const DBID& colid, BSTR& value) const
    {
      const DataSourceInfoPropertySet* dspropset = dynamic_cast<const DataSourceInfoPropertySet*>(propset);
      assert(dspropset != NULL);
      std::string s_value;
      HRESULT hr = dspropset->data_source->GetDBMSVer(s_value);
      if (FAILED(hr))
	return hr;
      return string2bstr(s_value, &value);
    }
  };

  class PropertyIdentifierCase : public PropertyI4RO
  {
  public:

    virtual HRESULT
    GetValue(const PropertySet* propset, const DBID& colid, LONG& value) const
    {
      const DataSourceInfoPropertySet* dspropset = dynamic_cast<const DataSourceInfoPropertySet*>(propset);
      assert(dspropset != NULL);
      return dspropset->data_source->GetIdentifierCase(value);
    }
  };

  class PropertyServerName : public PropertyBSTRRO
  {
  public:

    virtual HRESULT
    GetValue(const PropertySet* propset, const DBID& colid, BSTR& value) const
    {
      const DataSourceInfoPropertySet* dspropset = dynamic_cast<const DataSourceInfoPropertySet*>(propset);
      assert(dspropset != NULL);
      std::string s_value;
      HRESULT hr = dspropset->data_source->GetServerName(s_value);
      if (FAILED(hr))
	return hr;
      return string2bstr(s_value, &value);
    }
  };

  class PropertyUserName : public PropertyBSTRRO
  {
  public:

    virtual HRESULT
    GetValue(const PropertySet* propset, const DBID& colid, BSTR& value) const
    {
      const DataSourceInfoPropertySet* dspropset = dynamic_cast<const DataSourceInfoPropertySet*>(propset);
      assert(dspropset != NULL);
      return dspropset->data_source->GetUserName(value);
    }
  };

  DataSourceInfoPropertySet(CDataSource* ds)
    : PropertySet(g_DataSourceInfoPropertySetInfo, DBPROPFLAGS_READ)
  {
    data_source = ds;
  }

  ~DataSourceInfoPropertySet()
  {
  }

  CDataSource* data_source;

#define DATA_SOURCE_INFO_PROPERTY_SET\
  ELT(PropertyActiveSessions, ACTIVESESSIONS)\
  /*ELT(PropertyI4RO, ALTERCOLUMN)*/\
  ELT(PropertyBoolRO, ASYNCTXNABORT)\
  ELT(PropertyBoolRO, ASYNCTXNCOMMIT)\
  ELT(PropertyBoolRO, BYREFACCESSORS)\
  ELT(PropertyI4RO, CATALOGLOCATION)\
  ELT(PropertyBSTRRO, CATALOGTERM)\
  ELT(PropertyI4RO, CATALOGUSAGE)\
  ELT(PropertyI4RO, COLUMNDEFINITION)\
  ELT(PropertyI4RO, COMSERVICES)\
  ELT(PropertyI4RO, CONCATNULLBEHAVIOR)\
  ELT(PropertyI4RO, CONNECTIONSTATUS)\
  ELT(PropertyDataSourceName, DATASOURCENAME)\
  ELT(PropertyBoolRO, DATASOURCEREADONLY)\
  /*ELT(PropertyI4RO, DATASOURCE_TYPE)*/\
  ELT(PropertyDBMSName, DBMSNAME)\
  ELT(PropertyDBMSVer, DBMSVER)\
  ELT(PropertyI4RO, DSOTHREADMODEL)\
  ELT(PropertyI4RO, GENERATEURL)\
  ELT(PropertyI4RO, GROUPBY)\
  ELT(PropertyI4RO, HETEROGENEOUSTABLES)\
  ELT(PropertyIdentifierCase, IDENTIFIERCASE)\
  ELT(PropertyI4RO, MAXINDEXSIZE)\
  ELT(PropertyI4RO, MAXOPENCHAPTERS)\
  ELT(PropertyI4RO, MAXROWSIZE)\
  ELT(PropertyBoolRO, MAXROWSIZEINCLUDESBLOB)\
  ELT(PropertyI4RO, MAXTABLESINSELECT)\
  ELT(PropertyBoolRO, MULTIPLEPARAMSETS)\
  ELT(PropertyI4RO, MULTIPLERESULTS)\
  ELT(PropertyBoolRO, MULTIPLESTORAGEOBJECTS)\
  ELT(PropertyBoolRO, MULTITABLEUPDATE)\
  ELT(PropertyI4RO, NULLCOLLATION)\
  ELT(PropertyI4RO, OLEOBJECTS)\
  ELT(PropertyI4RO, OPENROWSETSUPPORT)\
  ELT(PropertyBoolRO, ORDERBYCOLUMNSINSELECT)\
  ELT(PropertyI4RO, OUTPUTPARAMETERAVAILABILITY)\
  ELT(PropertyI4RO, PERSISTENTIDTYPE)\
  ELT(PropertyI4RO, PREPAREABORTBEHAVIOR)\
  ELT(PropertyI4RO, PREPARECOMMITBEHAVIOR)\
  ELT(PropertyBSTRRO, PROCEDURETERM)\
  ELT(PropertyBSTRRO, PROVIDERFRIENDLYNAME)\
  ELT(PropertyBoolRO, PROVIDERMEMORY)\
  ELT(PropertyBSTRRO, PROVIDERFILENAME)\
  ELT(PropertyBSTRRO, PROVIDEROLEDBVER)\
  ELT(PropertyBSTRRO, PROVIDERVER)\
  ELT(PropertyI4RO, QUOTEDIDENTIFIERCASE)\
  ELT(PropertyBoolRO, ROWSETCONVERSIONSONCOMMAND)\
  ELT(PropertyBSTRRO, SCHEMATERM)\
  ELT(PropertyI4RO, SCHEMAUSAGE)\
  ELT(PropertyServerName, SERVERNAME)\
  ELT(PropertyI4RO, SQLSUPPORT)\
  ELT(PropertyI4RO, STRUCTUREDSTORAGE)\
  ELT(PropertyI4RO, SUBQUERIES)\
  ELT(PropertyI4RO, SUPPORTEDTXNDDL)\
  ELT(PropertyI4RO, SUPPORTEDTXNISOLEVELS)\
  ELT(PropertyI4RO, SUPPORTEDTXNISORETAIN)\
  ELT(PropertyI4RO, TABLESTATISTICS)\
  ELT(PropertyBSTRRO, TABLETERM)\
  ELT(PropertyUserName, USERNAME)

#undef ELT
#define ELT(type, name) type prop_##name;

  DATA_SOURCE_INFO_PROPERTY_SET

#undef ELT
#define ELT(type, name) case DBPROP_##name: return &prop_##name;

  virtual Property*
  GetProperty(DBPROPID id)
  {
    switch (id)
      {
	DATA_SOURCE_INFO_PROPERTY_SET
      }
    return NULL;
  }
};

////////////////////////////////////////////////////////////////////////
// CDataSource

CDataSource::CDataSource()
{
  LOGCALL(("CDataSource::CDataSource()\n"));

  m_state = S_Uninitialized;
  m_fIsDirty = true;
  m_pszFileName = NULL;
  m_sessions = 0;

  m_pDBInitPropertySet = NULL;
  m_pVirtDBInitPropertySet = NULL;
  m_pDataSourcePropertySet = NULL;
  m_pDataSourceInfoPropertySet = NULL;

  m_pUnkFTM = NULL;
}

CDataSource::~CDataSource()
{
  LOGCALL(("CDataSource::~CDataSource()\n"));

  delete [] m_pszFileName;
}

HRESULT
CDataSource::Initialize (void*)
{
  LOGCALL(("CDataSource::Initialize()\n"));

  if (m_info.Register(&g_DBInitPropertySetInfo) == false)
    {
      TRACE((__FILE__, __LINE__, "CDataSource::Init(): DBInitPropertySetInfo.Register() failed.\n"));
      return E_OUTOFMEMORY;
    }
  if (m_info.Register(&g_VirtDBInitPropertySetInfo) == false)
    {
      TRACE((__FILE__, __LINE__, "CDataSource::Init(): DBInitPropertySetInfo.Register() failed.\n"));
      return E_OUTOFMEMORY;
    }

  m_pDBInitPropertySet = new DBInitPropertySet();
  m_pVirtDBInitPropertySet = new VirtDBInitPropertySet();
  m_pDataSourcePropertySet = new DataSourcePropertySet(this);
  m_pDataSourceInfoPropertySet = new DataSourceInfoPropertySet(this);
  if (!m_pDBInitPropertySet
      || !m_pVirtDBInitPropertySet
      || !m_pDataSourcePropertySet
      || !m_pDataSourceInfoPropertySet)
    return E_OUTOFMEMORY;
  if (m_pDBInitPropertySet->Init() == false)
    return E_OUTOFMEMORY;
  if (m_pVirtDBInitPropertySet->Init() == false)
    return E_OUTOFMEMORY;
  if (m_pDataSourcePropertySet->Init() == false)
    return E_OUTOFMEMORY;
  if (m_pDataSourceInfoPropertySet->Init() == false)
    return E_OUTOFMEMORY;

  return m_environment.Init();
}

void
CDataSource::Delete()
{
  if (m_pUnkFTM != NULL)
    {
      m_pUnkFTM->Release();
      m_pUnkFTM = NULL;
    }

  delete m_pDBInitPropertySet;
  delete m_pVirtDBInitPropertySet;
  delete m_pDataSourcePropertySet;
  delete m_pDataSourceInfoPropertySet;

  m_info.Unregister(&g_VirtDBInitPropertySetInfo);
  m_info.Unregister(&g_DBInitPropertySetInfo);
}

HRESULT
CDataSource::GetInterface(REFIID riid, IUnknown** ppUnknown)
{
  LOGCALL (("CDataSource::GetInterface(%s)\n", STRINGFROMGUID (riid)));

  IUnknown* pUnknown = NULL;
  if (riid == IID_IDBInitialize)
    pUnknown = static_cast<IDBInitialize*>(this);
  else if (riid == IID_IDBProperties)
    pUnknown = static_cast<IDBProperties*>(this);
  else if (riid == IID_IDBCreateSession)
    {
      CriticalSection critical_section(this);
      if (m_state == S_Uninitialized)
	return E_UNEXPECTED;
      pUnknown = static_cast<IDBCreateSession*>(this);
    }
  else if (riid == IID_IDBInfo)
    {
      CriticalSection critical_section(this);
      if (m_state == S_Uninitialized)
	return E_UNEXPECTED;
      pUnknown = static_cast<IDBInfo*>(this);
    }
  else if (riid == IID_IPersist)
    pUnknown = static_cast<IPersist*>(this);
  else if (riid == IID_IPersistFile)
    pUnknown = static_cast<IPersistFile*>(this);
  else if (riid == IID_IServiceProvider)
    pUnknown = static_cast<IServiceProvider*>(this);
  else if (riid == IID_ISpecifyPropertyPages)
    pUnknown = static_cast<ISpecifyPropertyPages*>(this);
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
CDataSource::GetSupportErrorInfoIIDs()
{
  static const IID* rgpIIDs[] =
  {
    &IID_IDBInitialize,
    &IID_IDBProperties,
    &IID_IDBCreateSession,
    //&IID_IDBInfo,
    //&IID_IPersist,
    //&IID_IPersistFile,
    NULL
  };

  return rgpIIDs;
}

void
CDataSource::IncrementSessionCount()
{
  LOGCALL(("CDataSource::IncrementSessionCount(), sessions=%d\n", m_sessions + 1));
  InterlockedIncrement(&m_sessions);
}

void
CDataSource::DecrementSessionCount()
{
  LOGCALL(("CDataSource::DecrementSessionCount(), sessions=%d\n", m_sessions - 1));
  InterlockedDecrement(&m_sessions);
}

HRESULT
CDataSource::InitConnection(Connection &connection)
{
  LOGCALL (("CDataSource::InitConnection()\n"));

  CriticalSection critical_section(this);
  VARIANT_BOOL multiple_connections = m_pDataSourcePropertySet->prop_multiple_connections.GetValue();
  critical_section.Leave();

  return connection.Init(m_connection_pool, multiple_connections == VARIANT_TRUE);
}

ULONG
CDataSource::GetPropertySetCount()
{
  return m_state == S_Initialized ? 4 : 2;
}

PropertySet*
CDataSource::GetPropertySet(ULONG iPropertySet)
{
  switch (iPropertySet)
    {
    case 0:
      return m_pDBInitPropertySet;
    case 1:
      return m_pVirtDBInitPropertySet;
    case 2:
      assert(m_state == S_Initialized);
      return m_pDataSourcePropertySet;
    case 3:
      assert(m_state == S_Initialized);
      return m_pDataSourceInfoPropertySet;
    default:
      assert(0);
    }
  return NULL;
}

PropertySet*
CDataSource::GetPropertySet(REFGUID rguidPropertySet)
{
  if (rguidPropertySet == DBPROPSET_DBINIT)
    return m_pDBInitPropertySet;
  if (rguidPropertySet == DBPROPSET_VIRTUOSODBINIT)
    return m_pVirtDBInitPropertySet;
  if (m_state == S_Initialized)
    {
      if (rguidPropertySet == DBPROPSET_DATASOURCE)
	return m_pDataSourcePropertySet;
      if (rguidPropertySet == DBPROPSET_DATASOURCEINFO)
	return m_pDataSourceInfoPropertySet;
    }
  return NULL;
}

HRESULT
CDataSource::GetDataSourceName(BSTR& value) const
{
  value = SysAllocString(m_pDBInitPropertySet->prop_INIT_DATASOURCE.GetValue());
  if (value == NULL)
    return ErrorInfo::Set(E_OUTOFMEMORY);
  return S_OK;
}

HRESULT
CDataSource::GetUserName(BSTR& value) const
{
  value = SysAllocString(m_pDBInitPropertySet->prop_AUTH_USERID.GetValue());
  if (value == NULL)
    return ErrorInfo::Set(E_OUTOFMEMORY);
  return S_OK;
}

HRESULT
CDataSource::GetNoSysTables (VARIANT_BOOL& value) const
{
  DBID col_id;
  value = FALSE;
  if (m_pVirtDBInitPropertySet->prop_INIT_SHOW_SYSTEMTABLES.HasValue())
    return m_pVirtDBInitPropertySet->prop_INIT_SHOW_SYSTEMTABLES.GetValue (
	m_pVirtDBInitPropertySet,
	col_id,
	value);
  else
    return S_OK;
}
////////////////////////////////////////////////////////////////////////
// IDBInitialize

STDMETHODIMP
CDataSource::Initialize()
{
  LOGCALL(("CDataSource::Initialize()\n"));

  ErrorCheck error(IID_IDBInitialize, DISPID_IDBInitialize_Initialize);
  CriticalSection critical_section(this);

  if (m_state == CDataSource::S_Initialized)
    return ErrorInfo::Set(DB_E_ALREADYINITIALIZED);

  ConnectionPoolInfo pool_info;
  pool_info.cpi_conn_min = 1;
  pool_info.cpi_conn_max_soft = 1;
  pool_info.cpi_conn_max_hard = 0;

  HRESULT hr;
  ConnectionInfo conn_info;
  if (m_pDBInitPropertySet->prop_AUTH_USERID.HasValue())
    {
      hr = olestr2string(m_pDBInitPropertySet->prop_AUTH_USERID.GetValue(), conn_info.ci_userid);
      if (FAILED(hr))
	return hr;
    }
  if (m_pDBInitPropertySet->prop_AUTH_PASSWORD.HasValue())
    {
      hr = olestr2string(m_pDBInitPropertySet->prop_AUTH_PASSWORD.GetValue(), conn_info.ci_password);
      if (FAILED(hr))
	return hr;
    }
  if (m_pDBInitPropertySet->prop_INIT_DATASOURCE.HasValue())
    {
      hr = olestr2string(m_pDBInitPropertySet->prop_INIT_DATASOURCE.GetValue(), conn_info.ci_datasource);
      if (FAILED(hr))
	return hr;
    }
  if (m_pDBInitPropertySet->prop_INIT_CATALOG.HasValue())
    {
      hr = olestr2string(m_pDBInitPropertySet->prop_INIT_CATALOG.GetValue(), conn_info.ci_catalog);
      if (FAILED(hr))
	return hr;
    }
  if (m_pDBInitPropertySet->prop_INIT_PROVIDERSTRING.HasValue())
    {
      hr = olestr2string(m_pDBInitPropertySet->prop_INIT_PROVIDERSTRING.GetValue(), conn_info.ci_providerstring);
      if (FAILED(hr))
	return hr;
    }
  if (m_pDBInitPropertySet->prop_INIT_HWND.HasValue())
    conn_info.ci_hwnd = (HWND) m_pDBInitPropertySet->prop_INIT_HWND.GetValue();
  else
    conn_info.ci_hwnd = NULL;
  if (m_pDBInitPropertySet->prop_INIT_PROMPT.HasValue())
    conn_info.ci_prompt = m_pDBInitPropertySet->prop_INIT_PROMPT.GetValue();
  else
    conn_info.ci_prompt = DBPROMPT_NOPROMPT;
  if (m_pDBInitPropertySet->prop_INIT_TIMEOUT.HasValue())
    conn_info.ci_timeout = m_pDBInitPropertySet->prop_INIT_TIMEOUT.GetValue();
  else
    conn_info.ci_timeout = 0;
  if (m_pVirtDBInitPropertySet->prop_AUTH_PKCS12FILE.HasValue())
    {
      conn_info.ci_encrypt = true;
      m_pVirtDBInitPropertySet->prop_INIT_ENCRYPT.SetValue(VARIANT_TRUE);
    }
  else if (m_pVirtDBInitPropertySet->prop_INIT_ENCRYPT.HasValue()
	   && m_pVirtDBInitPropertySet->prop_INIT_ENCRYPT.GetValue() == VARIANT_TRUE)
    {
      conn_info.ci_encrypt = true;
    }
  else
      conn_info.ci_encrypt = false;
  if (m_pVirtDBInitPropertySet->prop_INIT_SHOW_SYSTEMTABLES.HasValue()
	   && m_pVirtDBInitPropertySet->prop_INIT_SHOW_SYSTEMTABLES.GetValue() == VARIANT_TRUE)
    {
      conn_info.ci_show_systemtables = true;
    }
  else
      conn_info.ci_show_systemtables = false;

  ConnectionPool tmp_connection_pool;
  hr = tmp_connection_pool.Init(m_environment, pool_info, conn_info);
  if (FAILED(hr))
    return hr;

  BSTR bstr;
  const ConnectionInfo& actual_conn_info = tmp_connection_pool.GetConnectionInfo();

  hr = string2bstr(actual_conn_info.ci_userid, &bstr);
  if (FAILED(hr))
    return hr;
  m_pDBInitPropertySet->prop_AUTH_USERID.SetValue(bstr);

  if (m_pDBInitPropertySet->prop_AUTH_PERSIST_SENSITIVE_AUTHINFO.GetValue() == VARIANT_TRUE)
    {
      hr = string2bstr(actual_conn_info.ci_password, &bstr);
      if (FAILED(hr))
	return hr;
    }
  else
    {
      hr = string2bstr("*****", &bstr);
      if (FAILED(hr))
	return hr;
    }
  m_pDBInitPropertySet->prop_AUTH_PASSWORD.SetValue(bstr);

  hr = string2bstr(actual_conn_info.ci_datasource, &bstr);
  if (FAILED(hr))
    return hr;
  m_pDBInitPropertySet->prop_INIT_DATASOURCE.SetValue(bstr);

  if (actual_conn_info.ci_catalog.length() == 0)
    {
      m_pDBInitPropertySet->prop_INIT_CATALOG.SetValue(NULL);
      m_pDBInitPropertySet->prop_INIT_CATALOG.SetValueFlag(false);
    }
  else
    {
      hr = string2bstr(actual_conn_info.ci_catalog, &bstr);
      if (FAILED(hr))
	return hr;
      m_pDBInitPropertySet->prop_INIT_CATALOG.SetValue(bstr);
    }

  if (actual_conn_info.ci_providerstring.length() == 0)
    {
      m_pDBInitPropertySet->prop_INIT_PROVIDERSTRING.SetValue(NULL);
      m_pDBInitPropertySet->prop_INIT_PROVIDERSTRING.SetValueFlag(false);
    }
  else
    {
      hr = string2bstr(actual_conn_info.ci_providerstring, &bstr);
      if (FAILED(hr))
	return hr;
      m_pDBInitPropertySet->prop_INIT_PROVIDERSTRING.SetValue(bstr);
    }

  if (m_info.Register(&g_DataSourcePropertySetInfo) == false)
    return ErrorInfo::Set(E_OUTOFMEMORY);
  if (m_info.Register(&g_DataSourceInfoPropertySetInfo) == false)
    return ErrorInfo::Set(E_OUTOFMEMORY);
  if (m_info.Register(&g_SessionPropertySetInfo) == false)
    return ErrorInfo::Set(E_OUTOFMEMORY);
  if (m_info.Register(&g_RowsetPropertySetInfo) == false)
    return ErrorInfo::Set(E_OUTOFMEMORY);
  // TODO: Add more PropertySetInfos (Table, Column, Stream).

  m_pDBInitPropertySet->SetPropertyFlags(DBPROPFLAGS_READ);

  m_connection_pool = tmp_connection_pool;
  m_state = CDataSource::S_Initialized;

  return S_OK;
}

STDMETHODIMP
CDataSource::Uninitialize()
{
  LOGCALL(("CDataSource::Uninitialize()\n"));

  ErrorCheck error(IID_IDBInitialize, DISPID_IDBInitialize_Uninitialize);
  CriticalSection critical_section(this);

  if (m_state == CDataSource::S_Uninitialized)
    return S_OK;
  if (m_sessions > 0)
    return ErrorInfo::Set(DB_E_OBJECTOPEN);

  m_state = CDataSource::S_Uninitialized;
  m_connection_pool = ConnectionPool(); // uninit connection pool

  m_pDBInitPropertySet->SetPropertyFlags(DBPROPFLAGS_READ | DBPROPFLAGS_WRITE);

  m_info.Unregister(&g_DataSourcePropertySetInfo);
  m_info.Unregister(&g_DataSourceInfoPropertySetInfo);
  m_info.Unregister(&g_SessionPropertySetInfo);
  m_info.Unregister(&g_RowsetPropertySetInfo);
  // TODO: Add more PropertySetInfos (Table, Column, Stream).

  return S_OK;
}

////////////////////////////////////////////////////////////////////////
// IDBProperties

STDMETHODIMP
CDataSource::GetProperties(
  ULONG cPropertyIDSets,
  const DBPROPIDSET rgPropertyIDSets[],
  ULONG *pcPropertySets,
  DBPROPSET **prgPropertySets
)
{
  LOGCALL(("CDataSource::GetProperties()\n"));

  ErrorCheck error(IID_IDBProperties, DISPID_IDBProperties_GetProperties);
  CriticalSection critical_section(this);

  return PropertySuperset::GetProperties(cPropertyIDSets, rgPropertyIDSets, pcPropertySets, prgPropertySets);
}

STDMETHODIMP
CDataSource::GetPropertyInfo(
  ULONG cPropertyIDSets,
  const DBPROPIDSET rgPropertyIDSets[],
  ULONG *pcPropertyInfoSets,
  DBPROPINFOSET **prgPropertyInfoSets,
  OLECHAR **ppDescBuffer
)
{
  LOGCALL(("CDataSource::GetPropertyInfo()\n"));

  ErrorCheck error(IID_IDBProperties, DISPID_IDBProperties_GetPropertyInfo);
  CriticalSection critical_section(this);

  return m_info.GetPropertyInfo(cPropertyIDSets,
				rgPropertyIDSets,
				pcPropertyInfoSets,
				prgPropertyInfoSets,
				ppDescBuffer);
}

STDMETHODIMP
CDataSource::SetProperties(
  ULONG cPropertySets,
  DBPROPSET rgPropertySets[]
)
{
  LOGCALL(("CDataSource::SetProperties()\n"));

  ErrorCheck error(IID_IDBProperties, DISPID_IDBProperties_SetProperties);
  CriticalSection critical_section(this);

  m_fIsDirty = true;
  return PropertySuperset::SetProperties(cPropertySets, rgPropertySets);
}

////////////////////////////////////////////////////////////////////////
// IDBCreateSession

STDMETHODIMP
CDataSource::CreateSession(
  IUnknown *pUnkOuter,
  REFIID riid,
  IUnknown **ppDBSession
)
{
  LOGCALL(("CDataSource::CreateSession(riid=%s)\n", StringFromGuid(riid)));

  ErrorCheck error(IID_IDBCreateSession, DISPID_IDBCreateSession_CreateSession);

  if (ppDBSession == NULL)
    return ErrorInfo::Set(E_INVALIDARG);
  *ppDBSession = NULL;

  if (pUnkOuter != NULL && riid != IID_IUnknown)
    return ErrorInfo::Set(DB_E_NOAGGREGATION);

  CriticalSection critical_section(this);

  if (m_state == CDataSource::S_Uninitialized)
    return ErrorInfo::Set(E_UNEXPECTED);

  return ComAggregateObj<CSession>::CreateInstance (pUnkOuter, riid, (void**) ppDBSession, this);
}

////////////////////////////////////////////////////////////////////////
// IDBInfo

enum LiteralType
{
  LT_SpecialChar,
  LT_Ident,
  LT_CharLiteral,
  LT_BinaryLiteral
};

struct LiteralInfo
{
  DBLITERAL lt;
  LiteralType type;
  LPOLESTR data;
};

static LiteralInfo literal_info[] =
{
  { DBLITERAL_BINARY_LITERAL,		LT_BinaryLiteral,	NULL },
  { DBLITERAL_CATALOG_NAME,		LT_Ident,		NULL },
  { DBLITERAL_CATALOG_SEPARATOR,	LT_SpecialChar,		L"." },
  { DBLITERAL_CHAR_LITERAL,		LT_CharLiteral,		NULL },
  { DBLITERAL_COLUMN_ALIAS,		LT_Ident,		NULL },
  { DBLITERAL_COLUMN_NAME,		LT_Ident,		NULL },
  // The next one is mentioned in oledb docs but absent in headers.
  //{ DBLITERAL_CONSTRAINT_NAME,		LT_Ident,		NULL },
  { DBLITERAL_CORRELATION_NAME,		LT_Ident,		NULL },
  { DBLITERAL_CURSOR_NAME,		LT_Ident,		NULL },
  { DBLITERAL_ESCAPE_PERCENT_PREFIX,	LT_SpecialChar,		L"\\" },
  //{ DBLITERAL_ESCAPE_PERCENT_SUFFIX,	LT_SpecialChar,		L"]" },
  { DBLITERAL_ESCAPE_UNDERSCORE_PREFIX,	LT_SpecialChar,		L"\\" },
  //{ DBLITERAL_ESCAPE_UNDERSCORE_SUFFIX, LT_SpecialChar,		L"]" },
  { DBLITERAL_INDEX_NAME,		LT_Ident,		NULL },
  { DBLITERAL_LIKE_PERCENT,		LT_SpecialChar,		L"%" },
  { DBLITERAL_LIKE_UNDERSCORE,		LT_SpecialChar,		L"_" },
  { DBLITERAL_PROCEDURE_NAME,		LT_Ident,		NULL },
  { DBLITERAL_SCHEMA_NAME,		LT_Ident,		NULL },
  { DBLITERAL_SCHEMA_SEPARATOR,		LT_SpecialChar,		L"." },
  { DBLITERAL_TABLE_NAME,		LT_Ident,		NULL },
  { DBLITERAL_TEXT_COMMAND,		LT_CharLiteral,		NULL },
  { DBLITERAL_USER_NAME,		LT_Ident,		NULL },
  { DBLITERAL_VIEW_NAME,		LT_Ident,		NULL },
  { DBLITERAL_QUOTE_PREFIX,		LT_SpecialChar,		L"\"" },
  { DBLITERAL_QUOTE_SUFFIX,		LT_SpecialChar,		L"\"" }
};

#define LITERAL_INFO_SIZE (sizeof literal_info / sizeof literal_info[0])

#define IDENT_INVALID_CHARS	      L"!\"#$%&\'()*+,-./:;<=>?@[\\]^`{|}~ "
				      //L"\x7f\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0a\x0b\x0c\x0d\x0e\x0f"\
				      //L"\x10\x11\x12\x13\x14\x15\x16\x17\x18\x19\x1a\x1b\x1c\x1d\x1e\x1f"

#define IDENT_INVALID_STARTING_CHARS  L"0123456789!\"#$%&\'()*+,-./:;<=>?@[\\]^`{|}~ "
				      //L"\x7f\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0a\x0b\x0c\x0d\x0e\x0f"\
				      //L"\x10\x11\x12\x13\x14\x15\x16\x17\x18\x19\x1a\x1b\x1c\x1d\x1e\x1f"

#ifndef MAX_NAME_LEN
#define MAX_NAME_LEN 100
#endif

#define MAX_LITERAL_LEN 100000

STDMETHODIMP
CDataSource::GetKeywords(
  LPOLESTR *ppwszKeywords
)
{
  LOGCALL(("CDataSource::GetKeywords()\n"));

  if (ppwszKeywords == NULL)
    return E_INVALIDARG;
  *ppwszKeywords = NULL;

  if (m_state == CDataSource::S_Uninitialized)
    return E_UNEXPECTED;

  static OLECHAR keywords[] = L"LONG,OBJECT_ID,REPLACING,SOFT";

  *ppwszKeywords = (LPOLESTR) CoTaskMemAlloc(sizeof keywords);
  if (*ppwszKeywords == NULL)
    return E_OUTOFMEMORY;

  memcpy (*ppwszKeywords, keywords, sizeof keywords);
  return S_OK;
}

STDMETHODIMP
CDataSource::GetLiteralInfo(
  ULONG cLiterals,
  const DBLITERAL rgLiterals[],
  ULONG *pcLiteralInfo,
  DBLITERALINFO **prgLiteralInfo,
  OLECHAR **ppCharBuffer
)
{
  LOGCALL(("CDataSource::GetLiteralInfo()\n"));

  if (pcLiteralInfo != NULL)
    *pcLiteralInfo = 0;
  if (prgLiteralInfo != NULL)
    *prgLiteralInfo = NULL;
  if (ppCharBuffer != NULL)
    *ppCharBuffer = NULL;

  if (cLiterals != 0 && rgLiterals == NULL)
    return E_INVALIDARG;
  if (pcLiteralInfo == NULL || prgLiteralInfo == NULL || ppCharBuffer == NULL)
    return E_INVALIDARG;

  if (m_state == CDataSource::S_Uninitialized)
    return E_UNEXPECTED;

  ULONG cLiteralInfo = cLiterals ? cLiterals : LITERAL_INFO_SIZE;

  DBLITERALINFO *rgLiteralInfo = (DBLITERALINFO*) CoTaskMemAlloc(cLiteralInfo * sizeof(DBLITERALINFO));
  if (rgLiteralInfo == NULL)
    return E_OUTOFMEMORY;

  ULONG i;
  size_t cbCharBuffer = 0;
  std::vector<LiteralInfo*> li_vec;
  bool success = false;
  bool failure = false;
  for (i = 0; i < cLiteralInfo; i++)
    {
      LiteralInfo* li = NULL;
      if (cLiterals)
	{
	  rgLiteralInfo[i].lt = rgLiterals[i];
	  for (ULONG j = 0; j < LITERAL_INFO_SIZE; j++)
	    if (rgLiterals[i] == literal_info[j].lt)
	      {
		li = &literal_info[j];
		break;
	      }
	  li_vec.push_back(li);
	  if (li == NULL)
	    {
	      failure = true;
	      continue;
	    }
	}
      else
	{
	  rgLiteralInfo[i].lt = literal_info[i].lt;
	  li = &literal_info[i];
	  li_vec.push_back(li);
	}

      success = true;
      switch (li->type)
	{
	case LT_SpecialChar:
	  cbCharBuffer += wcslen (li->data) + 1;
	  break;

	case LT_Ident:
	  cbCharBuffer += sizeof IDENT_INVALID_CHARS;
	  cbCharBuffer += sizeof IDENT_INVALID_STARTING_CHARS;
	  break;

	case LT_CharLiteral:
	  break;

	case LT_BinaryLiteral:
	  break;
	}
    }

  OLECHAR* pCharBuffer = NULL;
  if (success)
    {
      pCharBuffer = (OLECHAR*) CoTaskMemAlloc(cbCharBuffer * sizeof (OLECHAR));
      if (pCharBuffer == NULL)
	{
	  CoTaskMemFree(rgLiteralInfo);
	  return E_OUTOFMEMORY;
	}
    }

  OLECHAR *pNextChar = pCharBuffer;
  for (i = 0; i < cLiteralInfo; i++)
    {
      LiteralInfo* li = li_vec[i];
      if (li == NULL)
	{
	  rgLiteralInfo[i].fSupported = FALSE;
	  rgLiteralInfo[i].pwszLiteralValue = NULL;
	  rgLiteralInfo[i].pwszInvalidChars = NULL;
	  rgLiteralInfo[i].pwszInvalidStartingChars = NULL;
	  rgLiteralInfo[i].cchMaxLen = 0;
	  continue;
	}

      rgLiteralInfo[i].fSupported = TRUE;
      switch (li->type)
	{
	case LT_SpecialChar:
	  rgLiteralInfo[i].pwszLiteralValue = pNextChar;
	  rgLiteralInfo[i].pwszInvalidChars = NULL;
	  rgLiteralInfo[i].pwszInvalidStartingChars = NULL;
	  rgLiteralInfo[i].cchMaxLen = 1;
	  wcscpy (pNextChar, li->data);
	  pNextChar += wcslen (li->data) + 1;
	  break;

	case LT_Ident:
	  rgLiteralInfo[i].pwszLiteralValue = NULL;
	  rgLiteralInfo[i].pwszInvalidChars = pNextChar;
	  wcscpy(pNextChar, IDENT_INVALID_CHARS);
	  pNextChar += sizeof IDENT_INVALID_CHARS;
	  rgLiteralInfo[i].pwszInvalidStartingChars = pNextChar;
	  wcscpy(pNextChar, IDENT_INVALID_STARTING_CHARS);
	  pNextChar += sizeof IDENT_INVALID_STARTING_CHARS;
	  rgLiteralInfo[i].cchMaxLen = MAX_NAME_LEN;
	  break;

	case LT_CharLiteral:
	  rgLiteralInfo[i].pwszLiteralValue = NULL;
	  rgLiteralInfo[i].pwszInvalidChars = NULL;
	  rgLiteralInfo[i].pwszInvalidStartingChars = NULL;
	  rgLiteralInfo[i].cchMaxLen = MAX_LITERAL_LEN;
	  break;

	case LT_BinaryLiteral:
	  rgLiteralInfo[i].pwszLiteralValue = NULL;
	  rgLiteralInfo[i].pwszInvalidChars = NULL;
	  rgLiteralInfo[i].pwszInvalidStartingChars = NULL;
	  rgLiteralInfo[i].cchMaxLen = MAX_LITERAL_LEN;
	  break;
	}
    }

  *pcLiteralInfo = cLiteralInfo;
  *prgLiteralInfo = rgLiteralInfo;
  *ppCharBuffer = pCharBuffer;

  return failure ? success ? DB_S_ERRORSOCCURRED : DB_E_ERRORSOCCURRED : S_OK;
}

////////////////////////////////////////////////////////////////////////
// IPersist

STDMETHODIMP
CDataSource::GetClassID(
  CLSID *pClassID
)
{
  LOGCALL(("CDataSource::GetClassID()\n"));

  if (pClassID == NULL)
    return E_FAIL;

  memcpy(pClassID, &CLSID_VIRTOLEDB, sizeof(CLSID));
  return S_OK;
}

////////////////////////////////////////////////////////////////////////
// IPersistFile

STDMETHODIMP
CDataSource::IsDirty()
{
  LOGCALL(("CDataSource::IsDirty()\n"));

  CriticalSection critical_section(this);
  return m_fIsDirty ? S_OK : S_FALSE;
}

STDMETHODIMP
CDataSource::Load(
  LPCOLESTR pszFileName,
  DWORD dwMode
)
{
  LOGCALL(("CDataSource::Load(%ls)\n", pszFileName));

  if (pszFileName == NULL)
    return  STG_E_INVALIDNAME;
  if (pszFileName[0] == 0)
    return  STG_E_INVALIDNAME;

  CriticalSection critical_section(this);

  if (m_state == CDataSource::S_Initialized)
    return ErrorInfo::Set(DB_E_ALREADYINITIALIZED);

  std::string filename;
  HRESULT hr = olestr2string(pszFileName, filename);
  if (FAILED(hr))
    return hr;

  std::ifstream is(filename.c_str());
  if (is.fail())
    return STG_E_FILENOTFOUND;

  FileDSN filedsn;
  if (!filedsn.Read(is))
    return E_FAIL;

  m_pszFileName = new OLECHAR[wcslen(pszFileName) + 1];
  if (m_pszFileName == NULL)
    return E_OUTOFMEMORY;
  wcscpy(m_pszFileName, pszFileName);

  m_fIsDirty = false;

  BSTR bstr;
  std::string value;
  if (filedsn.Get("ODBC", "UID", value))
    {
      hr = string2bstr(value, &bstr);
      if (FAILED(hr))
	return hr;
      m_pDBInitPropertySet->prop_AUTH_USERID.SetValue(bstr);
    }
  if (filedsn.Get("ODBC", "PWD", value))
    {
      hr = string2bstr(value, &bstr);
      if (FAILED(hr))
	return hr;
      m_pDBInitPropertySet->prop_AUTH_PASSWORD.SetValue(bstr);
    }
  if (filedsn.Get("ODBC", "HOST", value))
    {
      hr = string2bstr(value, &bstr);
      if (FAILED(hr))
	return hr;
      m_pDBInitPropertySet->prop_INIT_DATASOURCE.SetValue(bstr);
    }
  if (filedsn.Get("ODBC", "DATABASE", value))
    {
      hr = string2bstr(value, &bstr);
      if (FAILED(hr))
	return hr;
      m_pDBInitPropertySet->prop_INIT_CATALOG.SetValue(bstr);
    }
  if (filedsn.Get("OLEDB", "PROVIDERSTRING", value))
    {
      hr = string2bstr(value, &bstr);
      if (FAILED(hr))
	return hr;
      m_pDBInitPropertySet->prop_INIT_PROVIDERSTRING.SetValue(bstr);
    }
  if (filedsn.Get("OLEDB", "HVND", value))
    {
      int i = atoi(value.c_str());
      m_pDBInitPropertySet->prop_INIT_HWND.SetValue(i);
    }
  if (filedsn.Get("OLEDB", "HVND", value))
    {
      int i = atoi(value.c_str());
      m_pDBInitPropertySet->prop_INIT_HWND.SetValue(i);
    }
  if (filedsn.Get("OLEDB", "PROMPT", value))
    {
      int i = atoi(value.c_str());
      m_pDBInitPropertySet->prop_INIT_PROMPT.SetValue(i);
    }
  if (filedsn.Get("OLEDB", "TIMEOUT", value))
    {
      int i = atoi(value.c_str());
      m_pDBInitPropertySet->prop_INIT_TIMEOUT.SetValue(i);
    }

  return S_OK;
}

STDMETHODIMP
CDataSource::Save(
  LPCOLESTR pszFileName,
  BOOL fRemember
)
{
  LOGCALL(("CDataSource::Save(%ls, %d)\n", pszFileName, fRemember));

  CriticalSection critical_section(this);

  LPCOLESTR w_pszFileName = pszFileName;
  if (w_pszFileName == NULL)
    {
      w_pszFileName = m_pszFileName;
      if (w_pszFileName == NULL)
	return STG_E_INVALIDNAME;
    }
  else if (w_pszFileName[0] == 0)
    return STG_E_INVALIDNAME;

  std::string filename;
  HRESULT hr = olestr2string(w_pszFileName, filename);
  if (FAILED(hr))
    return hr;

  FileDSN filedsn;

  std::string value;
  if (m_pDBInitPropertySet->prop_AUTH_USERID.HasValue())
    {
      hr = olestr2string(m_pDBInitPropertySet->prop_AUTH_USERID.GetValue(), value);
      if (hr != S_OK)
	return hr;
      if (!filedsn.Set("ODBC", "UID", value))
	return E_FAIL;
    }
  if (m_pDBInitPropertySet->prop_AUTH_PASSWORD.HasValue()
      && m_pDBInitPropertySet->prop_AUTH_PERSIST_SENSITIVE_AUTHINFO.GetValue() == VARIANT_TRUE)
    {
      hr = olestr2string(m_pDBInitPropertySet->prop_AUTH_PASSWORD.GetValue(), value);
      if (hr != S_OK)
	return hr;
      if (!filedsn.Set("ODBC", "PWD", value))
	return E_FAIL;
    }
  if (m_pDBInitPropertySet->prop_INIT_DATASOURCE.HasValue())
    {
      hr = olestr2string(m_pDBInitPropertySet->prop_INIT_DATASOURCE.GetValue(), value);
      if (hr != S_OK)
	return hr;
      if (!filedsn.Set("ODBC", "HOST", value))
	return E_FAIL;
    }
  if (m_pDBInitPropertySet->prop_INIT_CATALOG.HasValue())
    {
      hr = olestr2string(m_pDBInitPropertySet->prop_INIT_CATALOG.GetValue(), value);
      if (hr != S_OK)
	return hr;
      if (!filedsn.Set("ODBC", "DATABASE", value))
	return E_FAIL;
    }
  if (m_pDBInitPropertySet->prop_INIT_PROVIDERSTRING.HasValue())
    {
      hr = olestr2string(m_pDBInitPropertySet->prop_INIT_PROVIDERSTRING.GetValue(), value);
      if (hr != S_OK)
	return hr;
      if (!filedsn.Set("OLEDB", "PROVIDERSTRING", value))
	return E_FAIL;
    }
  char s[16];
  if (m_pDBInitPropertySet->prop_INIT_HWND.HasValue())
    {
      int i = m_pDBInitPropertySet->prop_INIT_HWND.GetValue();
      sprintf(s, "%d", i);
      if (!filedsn.Set("OLEDB", "HWND", s))
	return E_FAIL;
    }
  if (m_pDBInitPropertySet->prop_INIT_PROMPT.HasValue())
    {
      int i = m_pDBInitPropertySet->prop_INIT_PROMPT.GetValue();
      sprintf(s, "%d", i);
      if (!filedsn.Set("OLEDB", "PROMPT", s))
	return E_FAIL;
    }
  if (m_pDBInitPropertySet->prop_INIT_TIMEOUT.HasValue())
    {
      int i = m_pDBInitPropertySet->prop_INIT_TIMEOUT.GetValue();
      sprintf(s, "%d", i);
      if (!filedsn.Set("OLEDB", "TIMEOUT", s))
	return E_FAIL;
    }

  std::ofstream os(filename.c_str());
  if (os.fail())
    return STG_E_FILENOTFOUND;

  if (!filedsn.Write(os))
    return E_FAIL;

  if (pszFileName)
    {
      if (fRemember)
	{
	  m_pszFileName = new OLECHAR[wcslen(pszFileName) + 1];
	  if (m_pszFileName == NULL)
	    return E_OUTOFMEMORY;
	  wcscpy(m_pszFileName, pszFileName);

	  m_fIsDirty = false;
	}
    }
  else
    {
      m_fIsDirty = false;
    }

  return S_OK;
}

STDMETHODIMP
CDataSource::SaveCompleted(
  LPCOLESTR pszFileName
)
{
  LOGCALL(("CDataSource::SaveCompleted(%ls)\n", pszFileName));

  return S_OK;
}

STDMETHODIMP
CDataSource::GetCurFile(
  LPOLESTR *ppszFileName
)
{
  LOGCALL(("CDataSource::GetCurFile()\n"));

  if (ppszFileName == NULL)
    return E_FAIL;

  CriticalSection critical_section(this);

  HRESULT hr;
  LPOLESTR pszFileName;
  if (m_pszFileName != NULL)
    {
      hr = S_OK;
      pszFileName = m_pszFileName;
    }
  else
    {
      hr = S_FALSE;
      pszFileName = L"*.dsn";
    }

  *ppszFileName = (LPOLESTR) CoTaskMemAlloc((wcslen(pszFileName) + 1) * sizeof(OLECHAR));
  if (*ppszFileName == NULL)
    return E_OUTOFMEMORY;
  wcscpy(*ppszFileName, pszFileName);

  return hr;
}

////////////////////////////////////////////////////////////////////////
// IServiceProvider members

STDMETHODIMP
CDataSource::QueryService(
    REFGUID guidService,
    REFIID riid,
    void **ppvObject
)
{
  LOGCALL(("CDataSource::QueryService(guidService = %s, riid = %s)\n",
	   StringFromGuid(guidService),
	   StringFromGuid(riid)));

  if (ppvObject != NULL)
    *ppvObject = NULL;

  if (guidService != OLEDB_SVC_DSLPropertyPages)
    return E_NOINTERFACE /*SVC_E_UNKNOWNSERVICE*/;

  return GetControllingUnknown()->QueryInterface(riid, ppvObject);
}

////////////////////////////////////////////////////////////////////////
// ISpecifyPropertyPages members

STDMETHODIMP
CDataSource::GetPages(
  CAUUID* pPages
)
{
  LOGCALL(("CDataSource::GetPages()\n"));

  if (pPages == NULL)
    return E_POINTER;

  pPages->cElems = 2;
  pPages->pElems = (GUID*) CoTaskMemAlloc(pPages->cElems * sizeof(GUID));
  if (pPages->pElems == NULL)
    return E_OUTOFMEMORY;

  pPages->pElems[0] = CLSID_VIRTOLEDB_CONNECTION_PAGE;
#if ADVANCED_PAGE
  pPages->pElems[1] = CLSID_VIRTOLEDB_ADVANCED_PAGE;
#else
  pPages->pElems[1] = GUID_NULL;
#endif
  return S_OK;
}

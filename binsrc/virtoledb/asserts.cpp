/*
 *  OpenLink Generic OLE DB Provider
 *
 *  asserts.cpp
 *
 *  $Id$
 *
 *  Debugging and Assertion Routines
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

#include "headers.h"
#include "asserts.h"

#if DEBUG			// only compile for debug!

#include "util.h"
#include <stdarg.h>
#include <time.h>
#include <sqloledb.h>

static char *g_szLogFileName = "c:\\tmp\\virtoledb.log";

static int iLogLevel = 991;  // defines levels of call nesting logging

int LogIndent::iNesting = 0;

static LPSTR
StringFromPropID_VirtOledbDbInit(DBPROPID propID)
{
  switch (propID)
    {
    case VIRTPROP_INIT_ENCRYPT:		return "VIRTPROP_INIT_ENCRYPT";
    case VIRTPROP_AUTH_PKCS12FILE:	return "VIRTPROP_AUTH_PKCS12FILE";
    case VIRTPROP_INIT_CHARSET:		return "VIRTPROP_INIT_CHARSET";
    case VIRTPROP_INIT_DAYLIGHT:	return "VIRTPROP_INIT_DAYLIGHT";
    case VIRTPROP_INIT_SHOWSYSTABLES:	return "VIRTPROP_INIT_SHOWSYSTABLES";
    }
  return NULL;
}

static LPSTR
StringFromPropID_VirtOledbRowset(DBPROPID propID)
{
  switch (propID)
    {
    case VIRTPROP_PREFETCHSIZE:	      return "VIRTPROP_PREFETCHSIZE";
    case VIRTPROP_TXNTIMEOUT:	      return "VIRTPROP_TXNTIMEOUT";
    }
  return NULL;
}

static LPSTR
StringFromPropID_Oledb(DBPROPID propID)
{
  switch (propID)
    {
    case DBPROP_ABORTPRESERVE : return "DBPROP_ABORTPRESERVE";
    case DBPROP_ACTIVESESSIONS : return "DBPROP_ACTIVESESSIONS";
    case DBPROP_APPENDONLY : return "DBPROP_APPENDONLY";
    case DBPROP_ASYNCTXNABORT : return "DBPROP_ASYNCTXNABORT";
    case DBPROP_ASYNCTXNCOMMIT : return "DBPROP_ASYNCTXNCOMMIT";
    case DBPROP_AUTH_CACHE_AUTHINFO : return "DBPROP_AUTH_CACHE_AUTHINFO";
    case DBPROP_AUTH_ENCRYPT_PASSWORD : return "DBPROP_AUTH_ENCRYPT_PASSWORD";
    case DBPROP_AUTH_INTEGRATED : return "DBPROP_AUTH_INTEGRATED";
    case DBPROP_AUTH_MASK_PASSWORD : return "DBPROP_AUTH_MASK_PASSWORD";
    case DBPROP_AUTH_PASSWORD : return "DBPROP_AUTH_PASSWORD";
    case DBPROP_AUTH_PERSIST_ENCRYPTED : return "DBPROP_AUTH_PERSIST_ENCRYPTED";
    case DBPROP_AUTH_PERSIST_SENSITIVE_AUTHINFO : return "DBPROP_AUTH_PERSIST_SENSITIVE_AUTHINFO";
    case DBPROP_AUTH_USERID : return "DBPROP_AUTH_USERID";
    case DBPROP_BLOCKINGSTORAGEOBJECTS : return "DBPROP_BLOCKINGSTORAGEOBJECTS";
    case DBPROP_BOOKMARKS : return "DBPROP_BOOKMARKS";
    case DBPROP_BOOKMARKSKIPPED : return "DBPROP_BOOKMARKSKIPPED";
    case DBPROP_BOOKMARKTYPE : return "DBPROP_BOOKMARKTYPE";
    case DBPROP_BYREFACCESSORS : return "DBPROP_BYREFACCESSORS";
    case DBPROP_CACHEDEFERRED : return "DBPROP_CACHEDEFERRED";
    case DBPROP_CANFETCHBACKWARDS : return "DBPROP_CANFETCHBACKWARDS";
    case DBPROP_CANHOLDROWS : return "DBPROP_CANHOLDROWS";
    case DBPROP_CANSCROLLBACKWARDS : return "DBPROP_CANSCROLLBACKWARDS";
    case DBPROP_CATALOGLOCATION : return "DBPROP_CATALOGLOCATION";
    case DBPROP_CATALOGTERM : return "DBPROP_CATALOGTERM";
    case DBPROP_CATALOGUSAGE : return "DBPROP_CATALOGUSAGE";
    case DBPROP_CHANGEINSERTEDROWS : return "DBPROP_CHANGEINSERTEDROWS";
    case DBPROP_COL_AUTOINCREMENT : return "DBPROP_COL_AUTOINCREMENT";
    case DBPROP_COL_DEFAULT : return "DBPROP_COL_DEFAULT";
    case DBPROP_COL_DESCRIPTION : return "DBPROP_COL_DESCRIPTION";
    case DBPROP_COL_FIXEDLENGTH : return "DBPROP_COL_FIXEDLENGTH";
    case DBPROP_COL_NULLABLE : return "DBPROP_COL_NULLABLE";
    case DBPROP_COL_PRIMARYKEY : return "DBPROP_COL_PRIMARYKEY";
    case DBPROP_COL_UNIQUE : return "DBPROP_COL_UNIQUE";
    case DBPROP_COLUMNDEFINITION : return "DBPROP_COLUMNDEFINITION";
    case DBPROP_COLUMNRESTRICT : return "DBPROP_COLUMNRESTRICT";
    case DBPROP_COMMANDTIMEOUT : return "DBPROP_COMMANDTIMEOUT";
    case DBPROP_COMMITPRESERVE : return "DBPROP_COMMITPRESERVE";
    case DBPROP_CONCATNULLBEHAVIOR : return "DBPROP_CONCATNULLBEHAVIOR";
    case DBPROP_CURRENTCATALOG : return "DBPROP_CURRENTCATALOG";
    case DBPROP_DATASOURCENAME : return "DBPROP_DATASOURCENAME";
    case DBPROP_DATASOURCEREADONLY : return "DBPROP_DATASOURCEREADONLY";
    case DBPROP_DBMSNAME : return "DBPROP_DBMSNAME";
    case DBPROP_DBMSVER : return "DBPROP_DBMSVER";
    case DBPROP_DEFERRED : return "DBPROP_DEFERRED";
    case DBPROP_DELAYSTORAGEOBJECTS : return "DBPROP_DELAYSTORAGEOBJECTS";
    case DBPROP_DSOTHREADMODEL : return "DBPROP_DSOTHREADMODEL";
    case DBPROP_GROUPBY : return "DBPROP_GROUPBY";
    case DBPROP_HETEROGENEOUSTABLES : return "DBPROP_HETEROGENEOUSTABLES";
    case DBPROP_IAccessor : return "DBPROP_IAccessor";
    case DBPROP_IColumnsInfo : return "DBPROP_IColumnsInfo";
    case DBPROP_IColumnsRowset : return "DBPROP_IColumnsRowset";
    case DBPROP_IConnectionPointContainer : return "DBPROP_IConnectionPointContainer";
    case DBPROP_IConvertType : return "DBPROP_IConvertType";
    case DBPROP_IRowset : return "DBPROP_IRowset";
    case DBPROP_IRowsetChange : return "DBPROP_IRowsetChange";
    case DBPROP_IRowsetIdentity : return "DBPROP_IRowsetIdentity";
    case DBPROP_IRowsetIndex : return "DBPROP_IRowsetIndex";
    case DBPROP_IRowsetInfo : return "DBPROP_IRowsetInfo";
    case DBPROP_IRowsetLocate : return "DBPROP_IRowsetLocate";
    case DBPROP_IRowsetResynch : return "DBPROP_IRowsetResynch";
    case DBPROP_IRowsetScroll : return "DBPROP_IRowsetScroll";
    case DBPROP_IRowsetUpdate : return "DBPROP_IRowsetUpdate";
    case DBPROP_ISupportErrorInfo : return "DBPROP_ISupportErrorInfo";
    case DBPROP_ILockBytes : return "DBPROP_ILockBytes";
    case DBPROP_ISequentialStream : return "DBPROP_ISequentialStream";
    case DBPROP_IStorage : return "DBPROP_IStorage";
    case DBPROP_IStream : return "DBPROP_IStream";
    case DBPROP_IDENTIFIERCASE : return "DBPROP_IDENTIFIERCASE";
    case DBPROP_IMMOBILEROWS : return "DBPROP_IMMOBILEROWS";
    case DBPROP_INDEX_AUTOUPDATE : return "DBPROP_INDEX_AUTOUPDATE";
    case DBPROP_INDEX_CLUSTERED : return "DBPROP_INDEX_CLUSTERED";
    case DBPROP_INDEX_FILLFACTOR : return "DBPROP_INDEX_FILLFACTOR";
    case DBPROP_INDEX_INITIALSIZE : return "DBPROP_INDEX_INITIALSIZE";
    case DBPROP_INDEX_NULLCOLLATION : return "DBPROP_INDEX_NULLCOLLATION";
    case DBPROP_INDEX_NULLS : return "DBPROP_INDEX_NULLS";
    case DBPROP_INDEX_PRIMARYKEY : return "DBPROP_INDEX_PRIMARYKEY";
    case DBPROP_INDEX_SORTBOOKMARKS : return "DBPROP_INDEX_SORTBOOKMARKS";
    case DBPROP_INDEX_TEMPINDEX : return "DBPROP_INDEX_TEMPINDEX";
    case DBPROP_INDEX_TYPE : return "DBPROP_INDEX_TYPE";
    case DBPROP_INDEX_UNIQUE : return "DBPROP_INDEX_UNIQUE";
    case DBPROP_INIT_DATASOURCE : return "DBPROP_INIT_DATASOURCE";
    case DBPROP_INIT_HWND : return "DBPROP_INIT_HWND";
    case DBPROP_INIT_IMPERSONATION_LEVEL : return "DBPROP_INIT_IMPERSONATION_LEVEL";
    case DBPROP_INIT_LCID : return "DBPROP_INIT_LCID";
    case DBPROP_INIT_LOCATION : return "DBPROP_INIT_LOCATION";
    case DBPROP_INIT_MODE : return "DBPROP_INIT_MODE";
    case DBPROP_INIT_PROMPT : return "DBPROP_INIT_PROMPT";
    case DBPROP_INIT_PROTECTION_LEVEL : return "DBPROP_INIT_PROTECTION_LEVEL";
    case DBPROP_INIT_PROVIDERSTRING : return "DBPROP_INIT_PROVIDERSTRING";
    case DBPROP_INIT_TIMEOUT : return "DBPROP_INIT_TIMEOUT";
    case DBPROP_LITERALBOOKMARKS : return "DBPROP_LITERALBOOKMARKS";
    case DBPROP_LITERALIDENTITY : return "DBPROP_LITERALIDENTITY";
// deprecated in OLEDB 2.6    case DBPROP_MARSHALLABLE : return "DBPROP_MARSHALLABLE";
    case DBPROP_MAXINDEXSIZE : return "DBPROP_MAXINDEXSIZE";
    case DBPROP_MAXOPENROWS : return "DBPROP_MAXOPENROWS";
    case DBPROP_MAXPENDINGROWS : return "DBPROP_MAXPENDINGROWS";
    case DBPROP_MAXROWS : return "DBPROP_MAXROWS";
    case DBPROP_MAXROWSIZE : return "DBPROP_MAXROWSIZE";
    case DBPROP_MAXROWSIZEINCLUDESBLOB : return "DBPROP_MAXROWSIZEINCLUDESBLOB";
    case DBPROP_MAXTABLESINSELECT : return "DBPROP_MAXTABLESINSELECT";
    case DBPROP_MAYWRITECOLUMN : return "DBPROP_MAYWRITECOLUMN";
    case DBPROP_MEMORYUSAGE : return "DBPROP_MEMORYUSAGE";
    case DBPROP_MULTIPLEPARAMSETS : return "DBPROP_MULTIPLEPARAMSETS";
    case DBPROP_MULTIPLERESULTS : return "DBPROP_MULTIPLERESULTS";
    case DBPROP_MULTIPLESTORAGEOBJECTS : return "DBPROP_MULTIPLESTORAGEOBJECTS";
    case DBPROP_MULTITABLEUPDATE : return "DBPROP_MULTITABLEUPDATE";
    case DBPROP_NOTIFICATIONGRANULARITY : return "DBPROP_NOTIFICATIONGRANULARITY";
    case DBPROP_NOTIFICATIONPHASES : return "DBPROP_NOTIFICATIONPHASES";
    case DBPROP_NOTIFYCOLUMNSET : return "DBPROP_NOTIFYCOLUMNSET";
    case DBPROP_NOTIFYROWDELETE : return "DBPROP_NOTIFYROWDELETE";
    case DBPROP_NOTIFYROWFIRSTCHANGE : return "DBPROP_NOTIFYROWFIRSTCHANGE";
    case DBPROP_NOTIFYROWINSERT : return "DBPROP_NOTIFYROWINSERT";
    case DBPROP_NOTIFYROWRESYNCH : return "DBPROP_NOTIFYROWRESYNCH";
    case DBPROP_NOTIFYROWSETCHANGED : return "DBPROP_NOTIFYROWSETCHANGED";
    case DBPROP_NOTIFYROWSETRELEASE : return "DBPROP_NOTIFYROWSETRELEASE";
    case DBPROP_NOTIFYROWSETFETCHPOSITIONCHANGE : return "DBPROP_NOTIFYROWSETFETCHPOSITIONCHANGE";
    case DBPROP_NOTIFYROWUNDOCHANGE : return "DBPROP_NOTIFYROWUNDOCHANGE";
    case DBPROP_NOTIFYROWUNDODELETE : return "DBPROP_NOTIFYROWUNDODELETE";
    case DBPROP_NOTIFYROWUNDOINSERT : return "DBPROP_NOTIFYROWUNDOINSERT";
    case DBPROP_NOTIFYROWUPDATE : return "DBPROP_NOTIFYROWUPDATE";
    case DBPROP_NULLCOLLATION : return "DBPROP_NULLCOLLATION";
    case DBPROP_OLEOBJECTS : return "DBPROP_OLEOBJECTS";
    case DBPROP_ORDERBYCOLUMNSINSELECT : return "DBPROP_ORDERBYCOLUMNSINSELECT";
    case DBPROP_ORDEREDBOOKMARKS : return "DBPROP_ORDEREDBOOKMARKS";
    case DBPROP_OTHERINSERT : return "DBPROP_OTHERINSERT";
    case DBPROP_OTHERUPDATEDELETE : return "DBPROP_OTHERUPDATEDELETE";
    case DBPROP_OUTPUTPARAMETERAVAILABILITY : return "DBPROP_OUTPUTPARAMETERAVAILABILITY";
    case DBPROP_OWNINSERT : return "DBPROP_OWNINSERT";
    case DBPROP_OWNUPDATEDELETE : return "DBPROP_OWNUPDATEDELETE";
    case DBPROP_PERSISTENTIDTYPE : return "DBPROP_PERSISTENTIDTYPE";
    case DBPROP_PREPAREABORTBEHAVIOR : return "DBPROP_PREPAREABORTBEHAVIOR";
    case DBPROP_PREPARECOMMITBEHAVIOR : return "DBPROP_PREPARECOMMITBEHAVIOR";
    case DBPROP_PROCEDURETERM : return "DBPROP_PROCEDURETERM";
    case DBPROP_PROVIDERNAME : return "DBPROP_PROVIDERNAME";
    case DBPROP_PROVIDEROLEDBVER : return "DBPROP_PROVIDEROLEDBVER";
    case DBPROP_PROVIDERVER : return "DBPROP_PROVIDERVER";
    case DBPROP_QUICKRESTART : return "DBPROP_QUICKRESTART";
    case DBPROP_QUOTEDIDENTIFIERCASE : return "DBPROP_QUOTEDIDENTIFIERCASE";
    case DBPROP_REENTRANTEVENTS : return "DBPROP_REENTRANTEVENTS";
    case DBPROP_REMOVEDELETED : return "DBPROP_REMOVEDELETED";
    case DBPROP_REPORTMULTIPLECHANGES : return "DBPROP_REPORTMULTIPLECHANGES";
    case DBPROP_RETURNPENDINGINSERTS : return "DBPROP_RETURNPENDINGINSERTS";
    case DBPROP_ROWRESTRICT : return "DBPROP_ROWRESTRICT";
    case DBPROP_ROWSETCONVERSIONSONCOMMAND : return "DBPROP_ROWSETCONVERSIONSONCOMMAND";
    case DBPROP_ROWTHREADMODEL : return "DBPROP_ROWTHREADMODEL";
    case DBPROP_SCHEMATERM : return "DBPROP_SCHEMATERM";
    case DBPROP_SCHEMAUSAGE : return "DBPROP_SCHEMAUSAGE";
    case DBPROP_SERVERCURSOR : return "DBPROP_SERVERCURSOR";
    case DBPROP_SESS_AUTOCOMMITISOLEVELS : return "DBPROP_SESS_AUTOCOMMITISOLEVELS";
    case DBPROP_SQLSUPPORT : return "DBPROP_SQLSUPPORT";
    case DBPROP_STRONGIDENTITY : return "DBPROP_STRONGIDENTITY";
    case DBPROP_STRUCTUREDSTORAGE : return "DBPROP_STRUCTUREDSTORAGE";
    case DBPROP_SUBQUERIES : return "DBPROP_SUBQUERIES";
    case DBPROP_SUPPORTEDTXNDDL : return "DBPROP_SUPPORTEDTXNDDL";
    case DBPROP_SUPPORTEDTXNISOLEVELS : return "DBPROP_SUPPORTEDTXNISOLEVELS";
    case DBPROP_SUPPORTEDTXNISORETAIN : return "DBPROP_SUPPORTEDTXNISORETAIN";
    case DBPROP_TABLETERM : return "DBPROP_TABLETERM";
    case DBPROP_TBL_TEMPTABLE : return "DBPROP_TBL_TEMPTABLE";
    case DBPROP_TRANSACTEDOBJECT : return "DBPROP_TRANSACTEDOBJECT";
    case DBPROP_UPDATABILITY : return "DBPROP_UPDATABILITY";
    case DBPROP_USERNAME : return "DBPROP_USERNAME";
//    case DBPROP_FILTEROPS : return "DBPROP_FILTEROPS";
    case DBPROP_FILTERCOMPAREOPS : return "DBPROP_FILTERCOMPAREOPS";
    case DBPROP_FINDCOMPAREOPS : return "DBPROP_FINDCOMPAREOPS";
    case DBPROP_IChapteredRowset : return "DBPROP_IChapteredRowset";
    case DBPROP_IDBAsynchStatus : return "DBPROP_IDBAsynchStatus";
    case DBPROP_IRowsetFind : return "DBPROP_IRowsetFind";
    case DBPROP_IRowsetView : return "DBPROP_IRowsetView";
    case DBPROP_IViewChapter : return "DBPROP_IViewChapter";
    case DBPROP_IViewFilter : return "DBPROP_IViewFilter";
    case DBPROP_IViewRowset : return "DBPROP_IViewRowset";
    case DBPROP_IViewSort : return "DBPROP_IViewSort";
    case DBPROP_INIT_ASYNCH : return "DBPROP_INIT_ASYNCH";
    case DBPROP_MAXOPENCHAPTERS : return "DBPROP_MAXOPENCHAPTERS";
    case DBPROP_MAXORSINFILTER : return "DBPROP_MAXORSINFILTER";
    case DBPROP_MAXSORTCOLUMNS : return "DBPROP_MAXSORTCOLUMNS";
    case DBPROP_ROWSET_ASYNCH : return "DBPROP_ROWSET_ASYNCH";
    case DBPROP_SORTONINDEX : return "DBPROP_SORTONINDEX";
    case DBPROP_IMultipleResults : return "DBPROP_IMultipleResults";
    case DBPROP_DATASOURCE_TYPE : return "DBPROP_DATASOURCE_TYPE";
    case MDPROP_AXES : return "MDPROP_AXES";
    case MDPROP_FLATTENING_SUPPORT : return "MDPROP_FLATTENING_SUPPORT";
    case MDPROP_MDX_JOINCUBES : return "MDPROP_MDX_JOINCUBES";
    case MDPROP_NAMED_LEVELS : return "MDPROP_NAMED_LEVELS";
    case MDPROP_RANGEROWSET : return "MDPROP_RANGEROWSET";
    case MDPROP_MDX_SLICER : return "MDPROP_MDX_SLICER";
    case MDPROP_MDX_CUBEQUALIFICATION : return "MDPROP_MDX_CUBEQUALIFICATION";
    case MDPROP_MDX_OUTERREFERENCE : return "MDPROP_MDX_OUTERREFERENCE";
    case MDPROP_MDX_QUERYBYPROPERTY : return "MDPROP_MDX_QUERYBYPROPERTY";
    case MDPROP_MDX_CASESUPPORT : return "MDPROP_MDX_CASESUPPORT";
    case MDPROP_MDX_STRING_COMPOP : return "MDPROP_MDX_STRING_COMPOP";
    case MDPROP_MDX_DESCFLAGS : return "MDPROP_MDX_DESCFLAGS";
    case MDPROP_MDX_SET_FUNCTIONS : return "MDPROP_MDX_SET_FUNCTIONS";
    case MDPROP_MDX_MEMBER_FUNCTIONS : return "MDPROP_MDX_MEMBER_FUNCTIONS";
    case MDPROP_MDX_NUMERIC_FUNCTIONS : return "MDPROP_MDX_NUMERIC_FUNCTIONS";
    case MDPROP_MDX_FORMULAS : return "MDPROP_MDX_FORMULAS";
    case MDPROP_MDX_AGGREGATECELL_UPDATE : return "MDPROP_MDX_AGGREGATECELL_UPDATE";
    case DBPROP_ACCESSORDER : return "DBPROP_ACCESSORDER";
    case DBPROP_BOOKMARKINFO : return "DBPROP_BOOKMARKINFO";
    case DBPROP_INIT_CATALOG : return "DBPROP_INIT_CATALOG";
    case DBPROP_ROW_BULKOPS : return "DBPROP_ROW_BULKOPS";
    case DBPROP_PROVIDERFRIENDLYNAME : return "DBPROP_PROVIDERFRIENDLYNAME";
    case DBPROP_LOCKMODE : return "DBPROP_LOCKMODE";
    case DBPROP_MULTIPLECONNECTIONS : return "DBPROP_MULTIPLECONNECTIONS";
    case DBPROP_UNIQUEROWS : return "DBPROP_UNIQUEROWS";
    case DBPROP_SERVERDATAONINSERT : return "DBPROP_SERVERDATAONINSERT";
    case DBPROP_STORAGEFLAGS : return "DBPROP_STORAGEFLAGS";
    case DBPROP_CONNECTIONSTATUS : return "DBPROP_CONNECTIONSTATUS";
    case DBPROP_ALTERCOLUMN : return "DBPROP_ALTERCOLUMN";
    case DBPROP_COLUMNLCID : return "DBPROP_COLUMNLCID";
    case DBPROP_RESETDATASOURCE : return "DBPROP_RESETDATASOURCE";
    case DBPROP_INIT_OLEDBSERVICES : return "DBPROP_INIT_OLEDBSERVICES";
    case DBPROP_IRowsetRefresh : return "DBPROP_IRowsetRefresh";
    case DBPROP_SERVERNAME : return "DBPROP_SERVERNAME";
    case DBPROP_IParentRowset : return "DBPROP_IParentRowset";
    case DBPROP_HIDDENCOLUMNS : return "DBPROP_HIDDENCOLUMNS";
    case DBPROP_PROVIDERMEMORY : return "DBPROP_PROVIDERMEMORY";
    case DBPROP_CLIENTCURSOR : return "DBPROP_CLIENTCURSOR";
    case DBPROP_TRUSTEE_USERNAME: return "DBPROP_TRUSTEE_USERNAME";
    case DBPROP_TRUSTEE_AUTHENTICATION: return "DBPROP_TRUSTEE_AUTHENTICATION";
    case DBPROP_TRUSTEE_NEWAUTHENTICATION: return "DBPROP_TRUSTEE_NEWAUTHENTICATION";
    case DBPROP_IRow: return "DBPROP_IRow";
    case DBPROP_IRowChange: return "DBPROP_IRowChange";
    case DBPROP_IRowSchemaChange: return "DBPROP_IRowSchemaChange";
    case DBPROP_IGetRow: return "DBPROP_IGetRow";
    case DBPROP_IScopedOperations: return "DBPROP_IScopedOperations";
    case DBPROP_IBindResource: return "DBPROP_IBindResource";
    case DBPROP_ICreateRow: return "DBPROP_ICreateRow";
    case DBPROP_INIT_BINDFLAGS: return "DBPROP_INIT_BINDFLAGS";
    case DBPROP_INIT_LOCKOWNER: return "DBPROP_INIT_LOCKOWNER";
    case DBPROP_GENERATEURL: return "DBPROP_GENERATEURL";
    case DBPROP_IDBBinderProperties: return "DBPROP_IDBBinderProperties";
    case DBPROP_IColumnsInfo2: return "DBPROP_IColumnsInfo2";
    case DBPROP_IRegisterProvider: return "DBPROP_IRegisterProvider";
    case DBPROP_IGetSession: return "DBPROP_IGetSession";
    case DBPROP_IGetSourceRow: return "DBPROP_IGetSourceRow";
    case DBPROP_IRowsetCurrentIndex: return "DBPROP_IRowsetCurrentIndex";
    case DBPROP_OPENROWSETSUPPORT: return "DBPROP_OPENROWSETSUPPORT";
    case DBPROP_COL_ISLONG: return "DBPROP_COL_ISLONG";
    case DBPROP_COL_SEED: return "DBPROP_COL_SEED";
    case DBPROP_COL_INCREMENT: return "DBPROP_COL_INCREMENT";
    case DBPROP_INIT_GENERALTIMEOUT: return "DBPROP_INIT_GENERALTIMEOUT";
    case DBPROP_COMSERVICES: return "DBPROP_COMSERVICES";
    case DBPROP_OUTPUTSTREAM: return "DBPROP_OUTPUTSTREAM";
    case DBPROP_OUTPUTENCODING: return "DBPROP_OUTPUTENCODING";
    case DBPROP_TABLESTATISTICS: return "DBPROP_TABLESTATISTICS";
    case DBPROP_SKIPROWCOUNTRESULTS: return "DBPROP_SKIPROWCOUNTRESULTS";
    case DBPROP_IRowsetBookmark: return "DBPROP_IRowsetBookmark";
    case MDPROP_VISUALMODE: return "MDPROP_VISUALMODE";
    }
  return NULL;
}

LPSTR
StringFromPropID(REFIID riid, DBPROPID propID)
{
  char* pszProp = NULL;
  if (riid == DBPROPSET_VIRTUOSODBINIT)
    pszProp = StringFromPropID_VirtOledbDbInit(propID);
  else if (riid == DBPROPSET_VIRTUOSODBINIT)
    pszProp = StringFromPropID_VirtOledbRowset(propID);
  else
    pszProp = StringFromPropID_Oledb(propID);

  if (pszProp != NULL)
    return pszProp;

  static char pszBuf[256];
  sprintf(pszBuf, "%lu", propID);
  return pszBuf;
}

LPSTR
StringFromGuid(REFIID riid)
{
  static char pszBuf[256];
  if (riid == IID_IUnknown)
    return "IID_IUnknown";
  if (riid == IID_IAccessor)
    return "IID_IAccessor";
  if (riid == IID_IRowset)
    return "IID_IRowset";
  if (riid == IID_IRowsetInfo)
    return "IID_IRowsetInfo";
  if (riid == IID_IRowsetLocate)
    return "IID_IRowsetLocate";
  if (riid == IID_IRowsetResynch)
    return "IID_IRowsetResynch";
  if (riid == IID_IRowsetScroll)
    return "IID_IRowsetScroll";
  if (riid == IID_IRowsetChange)
    return "IID_IRowsetChange";
  if (riid == IID_IRowsetUpdate)
    return "IID_IRowsetUpdate";
  if (riid == IID_IRowsetIdentity)
    return "IID_IRowsetIdentity";
  if (riid == IID_IRowsetNotify)
    return "IID_IRowsetNotify";
  if (riid == IID_IRowsetIndex)
    return "IID_IRowsetIndex";
  if (riid == IID_ICommand)
    return "IID_ICommand";
  if (riid == IID_IMultipleResults)
    return "IID_IMultipleResults";
  if (riid == IID_IConvertType)
    return "IID_IConvertType";
  if (riid == IID_ICommandPrepare)
    return "IID_ICommandPrepare";
  if (riid == IID_ICommandProperties)
    return "IID_ICommandProperties";
  if (riid == IID_ICommandText)
    return "IID_ICommandText";
  if (riid == IID_ICommandWithParameters)
    return "IID_ICommandWithParameters";
  if (riid == IID_IColumnsRowset)
    return "IID_IColumnsRowset";
  if (riid == IID_IColumnsInfo)
    return "IID_IColumnsInfo";
  if (riid == IID_IDBCreateCommand)
    return "IID_IDBCreateCommand";
  if (riid == IID_IDBCreateSession)
    return "IID_IDBCreateSession";
  if (riid == IID_ISourcesRowset)
    return "IID_ISourcesRowset";
  if (riid == IID_IDBProperties)
    return "IID_IDBProperties";
  if (riid == IID_IDBInitialize)
    return "IID_IDBInitialize";
  if (riid == IID_IDBInfo)
    return "IID_IDBInfo";
  if (riid == IID_IDBDataSourceAdmin)
    return "IID_IDBDataSourceAdmin";
  if (riid == IID_ISessionProperties)
    return "IID_ISessionProperties";
  if (riid == IID_IIndexDefinition)
    return "IID_IIndexDefinition";
  if (riid == IID_ITableDefinition)
    return "IID_ITableDefinition";
  if (riid == IID_IOpenRowset)
    return "IID_IOpenRowset";
  if (riid == IID_IDBSchemaRowset)
    return "IID_IDBSchemaRowset";
  if (riid == IID_IErrorRecords)
    return "IID_IErrorRecords";
  if (riid == IID_IErrorLookup)
    return "IID_IErrorLookup";
  if (riid == IID_ISQLErrorInfo)
    return "IID_ISQLErrorInfo";
  if (riid == IID_IGetDataSource)
    return "IID_IGetDataSource";
  if (riid == IID_ITransactionLocal)
    return "IID_ITransactionLocal";
  if (riid == IID_ITransactionJoin)
    return "IID_ITransactionJoin";
  if (riid == IID_ITransactionObject)
    return "IID_ITransactionObject";
  if (riid == IID_IChapteredRowset)
    return "IID_IChapteredRowset";
  if (riid == IID_IDBAsynchNotify)
    return "IID_IDBAsynchNotify";
  if (riid == IID_IDBAsynchStatus)
    return "IID_IDBAsynchStatus";
  if (riid == IID_IRowsetFind)
    return "IID_IRowsetFind";
  if (riid == IID_IRowPosition)
    return "IID_IRowPosition";
  if (riid == IID_IRowPositionChange)
    return "IID_IRowPositionChange";
  if (riid == IID_IViewRowset)
    return "IID_IViewRowset";
  if (riid == IID_IViewChapter)
    return "IID_IViewChapter";
  if (riid == IID_IViewSort)
    return "IID_IViewSort";
  if (riid == IID_IViewFilter)
    return "IID_IViewFilter";
  if (riid == IID_IRowsetView)
    return "IID_IRowsetView";
  if (riid == IID_IMDDataset)
    return "IID_IMDDataset";
  if (riid == IID_IMDFind)
    return "IID_IMDFind";
  if (riid == IID_IMDRangeRowset)
    return "IID_IMDRangeRowset";
  if (riid == IID_IAlterTable)
    return "IID_IAlterTable";
  if (riid == IID_IAlterIndex)
    return "IID_IAlterIndex";
  if (riid == IID_ICommandPersist)
    return "IID_ICommandPersist";
  if (riid == IID_IRowsetChapterMember)
    return "IID_IRowsetChapterMember";
  if (riid == IID_IRowsetRefresh)
    return "IID_IRowsetRefresh";
  if (riid == IID_IParentRowset)
    return "IID_IParentRowset";
  if (riid == IID_IServiceProvider)
    return "IID_IServiceProvider";
  if (riid == IID_ISpecifyPropertyPages)
    return "IID_ISpecifyPropertyPages";
  if (riid == OLEDB_SVC_DSLPropertyPages)
    return "OLEDB_SVC_DSLPropertyPages";
  if (riid == (REFGUID)DB_NULLID)
    return "DB_NULLID";
  if (riid == (REFGUID)DBCOL_SELFCOLUMNS)
    return "DBCOL_SELFCOLUMNS";
  if (riid == (REFGUID)DBCOL_SPECIALCOL)
    return "DBCOL_SPECIALCOL";
  if (riid == (REFGUID)DBCOLUMN_BASECATALOGNAME)
    return "DBCOLUMN_BASECATALOGNAME";
  if (riid == (REFGUID)DBCOLUMN_BASECOLUMNNAME)
    return "DBCOLUMN_BASECOLUMNNAME";
  if (riid == (REFGUID)DBCOLUMN_BASESCHEMANAME)
    return "DBCOLUMN_BASESCHEMANAME";
  if (riid == (REFGUID)DBCOLUMN_BASETABLENAME)
    return "DBCOLUMN_BASETABLENAME";
  if (riid == (REFGUID)DBCOLUMN_BASETABLEVERSION)
    return "DBCOLUMN_BASETABLEVERSION";
  if (riid == (REFGUID)DBCOLUMN_CLSID)
    return "DBCOLUMN_CLSID";
  if (riid == (REFGUID)DBCOLUMN_COLLATINGSEQUENCE)
    return "DBCOLUMN_COLLATINGSEQUENCE";
  if (riid == (REFGUID)DBCOLUMN_COLUMNSIZE)
    return "DBCOLUMN_COLUMNSIZE";
  if (riid == (REFGUID)DBCOLUMN_COMPUTEMODE)
    return "DBCOLUMN_COMPUTEMODE";
  if (riid == (REFGUID)DBCOLUMN_DATETIMEPRECISION)
    return "DBCOLUMN_DATETIMEPRECISION";
  if (riid == (REFGUID)DBCOLUMN_DEFAULTVALUE)
    return "DBCOLUMN_DEFAULTVALUE";
  if (riid == (REFGUID)DBCOLUMN_DOMAINCATALOG)
    return "DBCOLUMN_DOMAINCATALOG";
  if (riid == (REFGUID)DBCOLUMN_DOMAINNAME)
    return "DBCOLUMN_DOMAINNAME";
  if (riid == (REFGUID)DBCOLUMN_DOMAINSCHEMA)
    return "DBCOLUMN_DOMAINSCHEMA";
  if (riid == (REFGUID)DBCOLUMN_FLAGS)
    return "DBCOLUMN_FLAGS";
  if (riid == (REFGUID)DBCOLUMN_GUID)
    return "DBCOLUMN_GUID";
  if (riid == (REFGUID)DBCOLUMN_HASDEFAULT)
    return "DBCOLUMN_HASDEFAULT";
  if (riid == (REFGUID)DBCOLUMN_IDNAME)
    return "DBCOLUMN_IDNAME";
  if (riid == (REFGUID)DBCOLUMN_ISAUTOINCREMENT)
    return "DBCOLUMN_ISAUTOINCREMENT";
  if (riid == (REFGUID)DBCOLUMN_ISCASESENSITIVE)
    return "DBCOLUMN_ISCASESENSITIVE";
  if (riid == (REFGUID)DBCOLUMN_ISSEARCHABLE)
    return "DBCOLUMN_ISSEARCHABLE";
  if (riid == (REFGUID)DBCOLUMN_ISUNIQUE)
    return "DBCOLUMN_ISUNIQUE";
  if (riid == (REFGUID)DBCOLUMN_KEYCOLUMN)
    return "DBCOLUMN_KEYCOLUMN";
  if (riid == (REFGUID)DBCOLUMN_MAYSORT)
    return "DBCOLUMN_MAYSORT";
  if (riid == (REFGUID)DBCOLUMN_NAME)
    return "DBCOLUMN_NAME";
  if (riid == (REFGUID)DBCOLUMN_NUMBER)
    return "DBCOLUMN_NUMBER";
  if (riid == (REFGUID)DBCOLUMN_NUMERICPRECISIONRADIX)
    return "DBCOLUMN_NUMERICPRECISIONRADIX";
  if (riid == (REFGUID)DBCOLUMN_OCTETLENGTH)
    return "DBCOLUMN_OCTETLENGTH";
  if (riid == (REFGUID)DBCOLUMN_PRECISION)
    return "DBCOLUMN_PRECISION";
  if (riid == (REFGUID)DBCOLUMN_PROPID)
    return "DBCOLUMN_PROPID";
  if (riid == (REFGUID)DBCOLUMN_SCALE)
    return "DBCOLUMN_SCALE";
  if (riid == (REFGUID)DBCOLUMN_TYPE)
    return "DBCOLUMN_TYPE";
  if (riid == (REFGUID)DBCOLUMN_TYPEINFO)
    return "DBCOLUMN_TYPEINFO";
  if (riid == (REFGUID)DBGUID_DBSQL)
    return "DBGUID_DBSQL";
  if (riid == (REFGUID)DBGUID_DEFAULT)
    return "DBGUID_DEFAULT";
  if (riid == (REFGUID)DBGUID_MDX)
    return "DBGUID_MDX";
  if (riid == (REFGUID)DBGUID_SQL)
    return "DBGUID_SQL";
  if (riid == (REFGUID)DBPROPSET_COLUMN)
    return "DBPROPSET_COLUMN";
  if (riid == (REFGUID)DBPROPSET_COLUMNALL)
    return "DBPROPSET_COLUMNALL";
  if (riid == (REFGUID)DBPROPSET_CONSTRAINTALL)
    return "DBPROPSET_CONSTRAINTALL";
  if (riid == (REFGUID)DBPROPSET_DATASOURCE)
    return "DBPROPSET_DATASOURCE";
  if (riid == (REFGUID)DBPROPSET_DATASOURCEALL)
    return "DBPROPSET_DATASOURCEALL";
  if (riid == (REFGUID)DBPROPSET_DATASOURCEINFO)
    return "DBPROPSET_DATASOURCEINFO";
  if (riid == (REFGUID)DBPROPSET_DATASOURCEINFOALL)
    return "DBPROPSET_DATASOURCEINFOALL";
  if (riid == (REFGUID)DBPROPSET_DBINIT)
    return "DBPROPSET_DBINIT";
  if (riid == (REFGUID)DBPROPSET_DBINITALL)
    return "DBPROPSET_DBINITALL";
  if (riid == (REFGUID)DBPROPSET_INDEX)
    return "DBPROPSET_INDEX";
  if (riid == (REFGUID)DBPROPSET_INDEXALL)
    return "DBPROPSET_INDEXALL";
  if (riid == (REFGUID)DBPROPSET_PROPERTIESINERROR)
    return "DBPROPSET_PROPERTIESINERROR";
  if (riid == (REFGUID)DBPROPSET_ROWSET)
    return "DBPROPSET_ROWSET";
  if (riid == (REFGUID)DBPROPSET_ROWSETALL)
    return "DBPROPSET_ROWSETALL";
  if (riid == (REFGUID)DBPROPSET_SESSION)
    return "DBPROPSET_SESSION";
  if (riid == (REFGUID)DBPROPSET_SESSIONALL)
    return "DBPROPSET_SESSIONALL";
  if (riid == (REFGUID)DBPROPSET_STREAM)
    return "DBPROPSET_STREAM";
  if (riid == (REFGUID)DBPROPSET_STREAMALL)
    return "DBPROPSET_STREAMALL";
  if (riid == (REFGUID)DBPROPSET_TABLE)
    return "DBPROPSET_TABLE";
  if (riid == (REFGUID)DBPROPSET_TABLEALL)
    return "DBPROPSET_TABLEALL";
  if (riid == (REFGUID)DBPROPSET_TRUSTEE)
    return "DBPROPSET_TRUSTEE";
  if (riid == (REFGUID)DBPROPSET_TRUSTEEALL)
    return "DBPROPSET_TRUSTEEALL";
  if (riid == (REFGUID)DBPROPSET_VIEW)
    return "DBPROPSET_VIEW";
  if (riid == (REFGUID)DBPROPSET_VIEWALL)
    return "DBPROPSET_VIEWALL";
  if (riid == (REFGUID)DBPROPSET_VIRTUOSODBINIT)
    return "DBPROPSET_VIRTUOSODBINIT";
  if (riid == (REFGUID)DBPROPSET_VIRTUOSOROWSET)
    return "DBPROPSET_VIRTUOSOROWSET";
  if (riid == (REFGUID)DBSCHEMA_ASSERTIONS)
    return "DBSCHEMA_ASSERTIONS";
  if (riid == (REFGUID)DBSCHEMA_CATALOGS)
    return "DBSCHEMA_CATALOGS";
  if (riid == (REFGUID)DBSCHEMA_CHARACTER_SETS)
    return "DBSCHEMA_CHARACTER_SETS";
  if (riid == (REFGUID)DBSCHEMA_CHECK_CONSTRAINTS)
    return "DBSCHEMA_CHECK_CONSTRAINTS";
  if (riid == (REFGUID)DBSCHEMA_COLLATIONS)
    return "DBSCHEMA_COLLATIONS";
  if (riid == (REFGUID)DBSCHEMA_COLUMN_DOMAIN_USAGE)
    return "DBSCHEMA_COLUMN_DOMAIN_USAGE";
  if (riid == (REFGUID)DBSCHEMA_COLUMN_PRIVILEGES)
    return "DBSCHEMA_COLUMN_PRIVILEGES";
  if (riid == (REFGUID)DBSCHEMA_COLUMNS)
    return "DBSCHEMA_COLUMNS";
  if (riid == (REFGUID)DBSCHEMA_CONSTRAINT_COLUMN_USAGE)
    return "DBSCHEMA_CONSTRAINT_COLUMN_USAGE";
  if (riid == (REFGUID)DBSCHEMA_CONSTRAINT_TABLE_USAGE)
    return "DBSCHEMA_CONSTRAINT_TABLE_USAGE";
  if (riid == (REFGUID)DBSCHEMA_FOREIGN_KEYS)
    return "DBSCHEMA_FOREIGN_KEYS";
  if (riid == (REFGUID)DBSCHEMA_INDEXES)
    return "DBSCHEMA_INDEXES";
  if (riid == (REFGUID)DBSCHEMA_KEY_COLUMN_USAGE)
    return "DBSCHEMA_KEY_COLUMN_USAGE";
  if (riid == (REFGUID)DBSCHEMA_PRIMARY_KEYS)
    return "DBSCHEMA_PRIMARY_KEYS";
  if (riid == (REFGUID)DBSCHEMA_PROCEDURE_COLUMNS)
    return "DBSCHEMA_PROCEDURE_COLUMNS";
  if (riid == (REFGUID)DBSCHEMA_PROCEDURE_PARAMETERS)
    return "DBSCHEMA_PROCEDURE_PARAMETERS";
  if (riid == (REFGUID)DBSCHEMA_PROCEDURES)
    return "DBSCHEMA_PROCEDURES";
  if (riid == (REFGUID)DBSCHEMA_PROVIDER_TYPES)
    return "DBSCHEMA_PROVIDER_TYPES";
  if (riid == (REFGUID)DBSCHEMA_REFERENTIAL_CONSTRAINTS)
    return "DBSCHEMA_REFERENTIAL_CONSTRAINTS";
  if (riid == (REFGUID)DBSCHEMA_SCHEMATA)
    return "DBSCHEMA_SCHEMATA";
  if (riid == (REFGUID)DBSCHEMA_SQL_LANGUAGES)
    return "DBSCHEMA_SQL_LANGUAGES";
  if (riid == (REFGUID)DBSCHEMA_STATISTICS)
    return "DBSCHEMA_STATISTICS";
  if (riid == (REFGUID)DBSCHEMA_TABLE_CONSTRAINTS)
    return "DBSCHEMA_TABLE_CONSTRAINTS";
  if (riid == (REFGUID)DBSCHEMA_TABLE_PRIVILEGES)
    return "DBSCHEMA_TABLE_PRIVILEGES";
  if (riid == (REFGUID)DBSCHEMA_TABLES)
    return "DBSCHEMA_TABLES";
  if (riid == (REFGUID)DBSCHEMA_TABLES_INFO)
    return "DBSCHEMA_TABLES_INFO";
  if (riid == (REFGUID)DBSCHEMA_TRANSLATIONS)
    return "DBSCHEMA_TRANSLATIONS";
  if (riid == (REFGUID)DBSCHEMA_USAGE_PRIVILEGES)
    return "DBSCHEMA_USAGE_PRIVILEGES";
  if (riid == (REFGUID)DBSCHEMA_VIEW_COLUMN_USAGE)
    return "DBSCHEMA_VIEW_COLUMN_USAGE";
  if (riid == (REFGUID)DBSCHEMA_VIEW_TABLE_USAGE)
    return "DBSCHEMA_VIEW_TABLE_USAGE";
  if (riid == (REFGUID)DBSCHEMA_VIEWS)
    return "DBSCHEMA_VIEWS";
  if (riid == (REFGUID)MDGUID_MDX)
    return "MDGUID_MDX";
  if (riid == (REFGUID)MDSCHEMA_CUBES)
    return "MDSCHEMA_CUBES";
  if (riid == (REFGUID)MDSCHEMA_DIMENSIONS)
    return "MDSCHEMA_DIMENSIONS";
  if (riid == (REFGUID)MDSCHEMA_HIERARCHIES)
    return "MDSCHEMA_HIERARCHIES";
  if (riid == (REFGUID)MDSCHEMA_LEVELS)
    return "MDSCHEMA_LEVELS";
  if (riid == (REFGUID)MDSCHEMA_MEASURES)
    return "MDSCHEMA_MEASURES";
  if (riid == (REFGUID)MDSCHEMA_MEMBERS)
    return "MDSCHEMA_MEMBERS";
  if (riid == (REFGUID)MDSCHEMA_PROPERTIES)
    return "MDSCHEMA_PROPERTIES";
  if (riid == (REFGUID)PSGUID_QUERY)
    return "PSGUID_QUERY";
  sprintf(pszBuf,
    "{%08lX-%04X-%04X-%02X%02X-%02X%02X%02X%02X%02X%02X}",
    riid.Data1, riid.Data2, riid.Data3, riid.Data4[0], riid.Data4[1],
    riid.Data4[2], riid.Data4[3], riid.Data4[4], riid.Data4[5],
    riid.Data4[6], riid.Data4[7]);
  HKEY hKey;
  LONG lSize, retval;
  char tempBuf[512];
  if (ERROR_SUCCESS == RegOpenKeyEx(HKEY_CLASSES_ROOT,"Interface",0,KEY_READ,&hKey))
  {
    lSize = sizeof tempBuf;
    if (ERROR_SUCCESS == (retval = RegQueryValue(hKey,pszBuf,tempBuf,&lSize)))
      strcpy(pszBuf,tempBuf);
    RegCloseKey(hKey);
    if (ERROR_SUCCESS != retval)
    {
      if (ERROR_SUCCESS == RegOpenKeyEx(HKEY_CLASSES_ROOT,"CLSID",0,KEY_READ,&hKey))
      {
        lSize = sizeof tempBuf;
	if (ERROR_SUCCESS == RegQueryValue(hKey,pszBuf,tempBuf,&lSize))
	  strcpy(pszBuf,tempBuf);
	RegCloseKey(hKey);
      }
    }
  }
  return pszBuf;
}

LPSTR
StringFromVariant(const VARIANT& v)
{
  static char buffer[4096];

  switch (V_VT(&v))
    {
    case VT_EMPTY:
      _snprintf(buffer, sizeof buffer, "VT_EMPTY");
      break;

    case VT_BOOL:
      _snprintf(buffer, sizeof buffer, "VT_BOOL[%s]", V_BOOL(&v) == VARIANT_FALSE ? "VARIANT_FALSE" : "VARIANT_TRUE");
      break;

    case VT_I2:
      _snprintf(buffer, sizeof buffer, "VT_I2[%d]", V_I2(&v));
      break;

    case VT_I4:
      _snprintf(buffer, sizeof buffer, "VT_I4[%d]", V_I4(&v));
      break;

    case VT_BSTR:
      _snprintf(buffer, sizeof buffer, "VT_BSTR[%S]", V_BSTR(&v));
      break;

    default:
      _snprintf(buffer, sizeof buffer, "VARIANT_TYPE[unsupported]");
      break;
    }

  return buffer;
}


/**
 * Variable argument formatter and Dump routine for messages.
 * @param format  IN - Format String
 * @param ...	  IN - Variable Arg List
 */
void
OLEDB_Trace(const char * szPath, int iLine, const char *format, ...)
{
  va_list argptr;

  char buffer[4096];
  _snprintf(buffer, sizeof buffer, "%s(%d): ", szPath, iLine);
  OutputDebugString(buffer);
  va_start(argptr, format);
  _vsnprintf(buffer, sizeof buffer, format, argptr);
  va_end(argptr);
  OutputDebugString(buffer);

  FILE* fp = fopen(g_szLogFileName, "a");
  if (fp != NULL)
    {
      fprintf(fp, "%s(%d): ", szPath, iLine);
      va_start(argptr, format);
      vfprintf(fp, format, argptr);
      va_end(argptr);
      fclose(fp);
    }
}


/**
 * Call logging with variable argument formatter and Dump routine for messages.
 * @param format  IN - Format String
 * @param ...	  IN - Variable Arg List
 */
void
OLEDB_Log(const char *format, ...)
{
  va_list argptr;

  char buffer[4096];
  _snprintf(buffer, sizeof buffer, "%*s", (LogIndent::iNesting - 1) * 2, "");
  OutputDebugString(buffer);
  va_start(argptr, format);
  _vsnprintf(buffer, sizeof buffer, format, argptr);
  va_end(argptr);
  OutputDebugString(buffer);

  FILE* fp = fopen(g_szLogFileName, "a");
  if (fp != NULL)
    {
      fprintf(fp, "%*s", (LogIndent::iNesting - 1) * 2, "");
      va_start(argptr, format);
      vfprintf(fp, format, argptr);
      va_end(argptr);
      fclose(fp);
    }
}


void
OLEDB_LogFlat(const char *format, ...)
{
  va_list argptr;

  char buffer[4096];
  va_start(argptr, format);
  _vsnprintf(buffer, sizeof buffer, format, argptr);
  va_end(argptr);
  OutputDebugString(buffer);

  FILE* fp = fopen(g_szLogFileName, "a");
  if (fp != NULL)
    {
      va_start(argptr, format);
      vfprintf(fp, format, argptr);
      va_end(argptr);
      fclose(fp);
    }
}


/**
 * This an internal assertion routine that dumps more information
 * than the normal assertion routines.
 *
 * @return NONE
 * @param expression  IN - Expression to assert on
 * @param filename  IN - Filename where assertion occurred
 * @param linenum  IN - Line number where assertion occurred
 *
 */
void
OLEDB_Assert(LPSTR expression, LPSTR filename, long linenum)
{
  char szbuff[350];
  volatile int fAbort = 1;

  _snprintf(szbuff, sizeof (szbuff),
            "Assertion error!\n  File '%.50s', line '%ld'\n  Expression '%.200s'\n",
            filename, linenum, expression);
  LOG((szbuff));

  strcat(szbuff, "Abort execution?");

  // We're a DLL (therefore Windows), so may not have an output stream we can write to.
  // GK: but on other hand : we may not be a foreground process at all :-)
  // fAbort = IDYES==::MessageBox(NULL, szbuff, "Assertion Error", MB_SYSTEMMODAL | MB_ICONHAND | MB_YESNO);

  // Break and let the user get a crack at it.
  // You can set fAbort=0 to continue merrily along.
  if (fAbort)
    abort ();			// Raises SIGABRT
}


LPSTR
LogIndent::StringFromVariant(const VARIANT* variant)
{
  char buffer[2048];
  switch(V_VT(variant))
    {
    case VT_EMPTY:
      _snprintf(buffer, sizeof buffer, "%s", "{EMPTY}");
      break;
    case VT_NULL:
      _snprintf(buffer, sizeof buffer, "%s", "{NULL}");
      break;
    case VT_I1:
      _snprintf(buffer, sizeof buffer, "%d", V_I1(variant));
      break;
    case VT_I2:
      _snprintf(buffer, sizeof buffer, "%d", V_I2(variant));
      break;
    case VT_I4:
      _snprintf(buffer, sizeof buffer, "%d", V_I4(variant));
      break;
    case VT_UI1:
      _snprintf(buffer, sizeof buffer, "%u", V_UI1(variant));
      break;
    case VT_UI2:
      _snprintf(buffer, sizeof buffer, "%u", V_UI2(variant));
      break;
    case VT_UI4:
      _snprintf(buffer, sizeof buffer, "%u", V_UI4(variant));
      break;
    case VT_BSTR:
      {
	std::string string;
	olestr2string(V_BSTR(variant), string);
	_snprintf(buffer, sizeof buffer, "%s", string.c_str());
      }
      break;
    default:
      _snprintf(buffer, sizeof buffer, "%s", "???");
    }
  return insert(buffer);
}

#endif

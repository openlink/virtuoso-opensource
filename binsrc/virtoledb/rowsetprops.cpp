/*  rowsetprops.h
 *
 *  $Id$
 *  
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *  
 *  Copyright (C) 1998-2013 OpenLink Software
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
#include "rowsetprops.h"

static PropertyInfo rowset_properties[] =
{
  {
    DBPROP_ABORTPRESERVE,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ | DBPROPFLAGS_WRITE,
    VT_BOOL,
    L"Preserve on Abort",
    VARIANT_FALSE
  },
  {
    DBPROP_ACCESSORDER,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ /*| DBPROPFLAGS_WRITE*/,
    VT_I4,
    L"Access Order",
    DBPROPVAL_AO_RANDOM
  },
  /*{
    DBPROP_APPENDONLY,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ | DBPROPFLAGS_WRITE,
    VT_BOOL,
    L"Append-Only Rowset",
    VARIANT_FALSE
  },*/
  {
    DBPROP_BLOCKINGSTORAGEOBJECTS,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ /*| DBPROPFLAGS_WRITE*/,
    VT_BOOL,
    L"Blocking Storage Objects",
    VARIANT_TRUE
  },
  {
    DBPROP_BOOKMARKINFO,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ,
    VT_I4,
    L"Bookmark Information",
    DBPROPVAL_BI_CROSSROWSET
  },
  {
    DBPROP_BOOKMARKS,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ | DBPROPFLAGS_WRITE,
    VT_BOOL,
    L"Use Bookmarks",
    VARIANT_FALSE
  },
  {
    DBPROP_BOOKMARKSKIPPED,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ /*| DBPROPFLAGS_WRITE*/,
    VT_BOOL,
    L"Skip Deleted Bookmarks",
    VARIANT_FALSE
  },
  {
    DBPROP_BOOKMARKTYPE,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ /*| DBPROPFLAGS_WRITE*/,
    VT_I4,
    L"Bookmark Type",
    DBPROPVAL_BMK_NUMERIC
  },
  {
    DBPROP_CACHEDEFERRED,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ /*| DBPROPFLAGS_WRITE*/ | DBPROPFLAGS_COLUMNOK,
    VT_BOOL,
    L"Cache Deferred Columns",
    VARIANT_FALSE
  },
  {
    DBPROP_CANFETCHBACKWARDS,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ | DBPROPFLAGS_WRITE,
    VT_BOOL,
    L"Fetch Backwards",
    VARIANT_FALSE
  },
  {
    DBPROP_CANHOLDROWS,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ | DBPROPFLAGS_WRITE,
    VT_BOOL,
    L"Hold Rows",
    VARIANT_FALSE
  },
  {
    DBPROP_CANSCROLLBACKWARDS,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ | DBPROPFLAGS_WRITE,
    VT_BOOL,
    L"Scroll Backwards",
    VARIANT_FALSE
  },
  // TODO: add support of VARINT_TRUE
  {
    DBPROP_CHANGEINSERTEDROWS,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ /*| DBPROPFLAGS_WRITE*/,
    VT_BOOL,
    L"Change Inserted Rows",
    VARIANT_FALSE
  },
  {
    DBPROP_COLUMNRESTRICT,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ,
    VT_BOOL,
    L"Column Privileges",
    VARIANT_FALSE
  },
  // TODO: really support this
  {
    DBPROP_COMMANDTIMEOUT,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ | DBPROPFLAGS_WRITE,
    VT_I4,
    L"Command Time Out",
    0
  },
  {
    DBPROP_COMMITPRESERVE,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ | DBPROPFLAGS_WRITE,
    VT_BOOL,
    L"Preserve on Commit",
    VARIANT_FALSE
  },
  {
    DBPROP_DEFERRED,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ /*| DBPROPFLAGS_WRITE*/ | DBPROPFLAGS_COLUMNOK,
    VT_BOOL,
    L"Defer Column",
    VARIANT_FALSE
  },
  {
    DBPROP_DELAYSTORAGEOBJECTS,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ /*| DBPROPFLAGS_WRITE*/,
    VT_BOOL,
    L"Delay Storage Object Updates",
    VARIANT_FALSE
  },
  {
    DBPROP_FINDCOMPAREOPS,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ | DBPROPFLAGS_COLUMNOK,
    VT_I4,
    L"Find Operations",
    0
  },
  {
    DBPROP_HIDDENCOLUMNS,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ,
    VT_I4,
#if 0
    L"Hidden Column Count",  // as per OLE DB 2,6 reference
#else
    L"Hidden Columns",       // as per coformance tests
#endif
    0
  },
  {
    DBPROP_IAccessor,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ,
    VT_BOOL,
    L"IAccessor",
    VARIANT_TRUE
  },
  {
    DBPROP_IColumnsInfo,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ,
    VT_BOOL,
    L"IColumnsInfo",
    VARIANT_TRUE
  },
  /*{
    DBPROP_IColumnsInfo2,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ | DBPROPFLAGS_WRITE,
    VT_BOOL,
    L"IColumnsInfo2",
    VARIANT_FALSE
  },*/
  {
    DBPROP_IColumnsRowset,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ | DBPROPFLAGS_WRITE,
    VT_BOOL,
    L"IColumnsRowset",
    VARIANT_FALSE
  },
  {
    DBPROP_IConnectionPointContainer,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ | DBPROPFLAGS_WRITE,
    VT_BOOL,
    L"IConnectionPointContainer",
    VARIANT_FALSE
  },
  {
    DBPROP_IConvertType,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ,
    VT_BOOL,
    L"IConvertType",
    VARIANT_TRUE
  },
  /*{
    DBPROP_IDBAsynchStatus,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ | DBPROPFLAGS_WRITE,
    VT_BOOL,
    L"IDBAsynchStatus",
    VARIANT_FALSE
  },*/
  /*{
    DBPROP_ILockBytes,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ | DBPROPFLAGS_WRITE | DBPROPFLAGS_COLUMNOK,
    VT_BOOL,
    L"ILockBytes",
    VARIANT_FALSE
  },*/
  {
    DBPROP_IMMOBILEROWS,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ | DBPROPFLAGS_WRITE,
    VT_BOOL,
    L"Immobile Rows",
    VARIANT_FALSE
  },
  {
    DBPROP_IMultipleResults,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ | DBPROPFLAGS_WRITE,
    VT_BOOL,
    L"IMultipleResults",
    VARIANT_FALSE
  },
  {
    DBPROP_IRowset,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ,
    VT_BOOL,
    L"IRowset",
    VARIANT_TRUE
  },
  /*{
    DBPROP_IRowsetBookmark,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ | DBPROPFLAGS_WRITE,
    VT_BOOL,
    L"IRowsetBookmark",
    VARIANT_FALSE
  },*/
  {
    DBPROP_IRowsetChange,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ | DBPROPFLAGS_WRITE,
    VT_BOOL,
    L"IRowsetChange",
    VARIANT_FALSE
  },
  /*{
    DBPROP_IRowsetFind,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ | DBPROPFLAGS_WRITE,
    VT_BOOL,
    L"IRowsetFind",
    VARIANT_FALSE
  },*/
  {
    DBPROP_IRowsetIdentity,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ | DBPROPFLAGS_WRITE,
    VT_BOOL,
    L"IRowsetIdentity",
    VARIANT_FALSE
  },
  {
    DBPROP_IRowsetInfo,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ,
    VT_BOOL,
    L"IRowsetInfo",
    VARIANT_TRUE
  },
  {
    DBPROP_IRowsetLocate,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ | DBPROPFLAGS_WRITE,
    VT_BOOL,
    L"IRowsetLocate",
    VARIANT_FALSE
  },
  {
    DBPROP_IRowsetRefresh,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ | DBPROPFLAGS_WRITE,
    VT_BOOL,
    L"IRowsetRefresh",
    VARIANT_FALSE
  },
  {
    DBPROP_IRowsetResynch,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ | DBPROPFLAGS_WRITE,
    VT_BOOL,
    L"IRowsetResynch",
    VARIANT_FALSE
  },
  {
    DBPROP_IRowsetScroll,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ | DBPROPFLAGS_WRITE,
    VT_BOOL,
    L"IRowsetScroll",
    VARIANT_FALSE
  },
  {
    DBPROP_IRowsetUpdate,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ | DBPROPFLAGS_WRITE,
    VT_BOOL,
    L"IRowsetUpdate",
    VARIANT_FALSE
  },
  {
    DBPROP_ISequentialStream,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ /*| DBPROPFLAGS_WRITE | DBPROPFLAGS_COLUMNOK*/,
    VT_BOOL,
    L"ISequentialStream",
    VARIANT_TRUE
  },
  /*{
    DBPROP_IStorage,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ | DBPROPFLAGS_WRITE | DBPROPFLAGS_COLUMNOK,
    VT_BOOL,
    L"IStorage",
    VARIANT_FALSE
  },*/
  /*{
    DBPROP_IStream,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ | DBPROPFLAGS_WRITE | DBPROPFLAGS_COLUMNOK,
    VT_BOOL,
    L"IStream",
    VARIANT_FALSE
  },*/
  {
    DBPROP_ISupportErrorInfo,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ | DBPROPFLAGS_WRITE,
    VT_BOOL,
    L"ISupportErrorInfo",
    VARIANT_FALSE
  },
  {
    DBPROP_LITERALBOOKMARKS,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ /*| DBPROPFLAGS_WRITE*/,
    VT_BOOL,
    L"Literal Bookmarks",
    VARIANT_FALSE
  },
  {
    DBPROP_LITERALIDENTITY,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ,
    VT_BOOL,
    L"Literal Row Identity",
    VARIANT_TRUE
  },
  {
    DBPROP_LOCKMODE,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ | DBPROPFLAGS_WRITE,
    VT_I4,
    L"Lock Mode",
    DBPROPVAL_LM_NONE
  },
  {
    DBPROP_MAXOPENROWS,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ /*| DBPROPFLAGS_WRITE*/,
    VT_I4,
    L"Maximum Open Rows",
    0
  },
  {
    DBPROP_MAXPENDINGROWS,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ /*| DBPROPFLAGS_WRITE*/,
    VT_I4,
    L"Maximum Pending Rows",
    0
  },
  // TODO: Really support this
  {
    DBPROP_MAXROWS,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ | DBPROPFLAGS_WRITE,
    VT_I4,
    L"Maximum Rows",
    0
  },
  /*{
    DBPROP_MAYWRITECOLUMN,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ | DBPROPFLAGS_WRITE | DBPROPFLAGS_COLUMNOK,
    VT_BOOL,
    L"Column Writable",
    VARIANT_FALSE
  },*/
  /*{
    DBPROP_MEMORYUSAGE,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ | DBPROPFLAGS_WRITE,
    VT_I4,
    L"Memory Usage",
    0
  },*/
  {
    DBPROP_NOTIFICATIONGRANULARITY,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ,
    VT_I4,
    L"Notification Granularity",
    DBPROPVAL_NT_SINGLEROW
  },
  {
    DBPROP_NOTIFICATIONPHASES,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ,
    VT_I4,
    L"Notification Phases",
    DBPROPVAL_NP_OKTODO | DBPROPVAL_NP_ABOUTTODO
    | DBPROPVAL_NP_SYNCHAFTER | DBPROPVAL_NP_FAILEDTODO | DBPROPVAL_NP_DIDEVENT
  },
  {
    DBPROP_NOTIFYCOLUMNSET,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ,
    VT_I4,
    L"Column Set Notification",
    DBPROPVAL_NP_OKTODO | DBPROPVAL_NP_ABOUTTODO | DBPROPVAL_NP_SYNCHAFTER
  },
  {
    DBPROP_NOTIFYROWDELETE,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ,
    VT_I4,
    L"Row Delete Notification",
    DBPROPVAL_NP_OKTODO | DBPROPVAL_NP_ABOUTTODO | DBPROPVAL_NP_SYNCHAFTER
  },
  {
    DBPROP_NOTIFYROWFIRSTCHANGE,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ,
    VT_I4,
    L"Row First Change Notification",
    DBPROPVAL_NP_OKTODO | DBPROPVAL_NP_ABOUTTODO | DBPROPVAL_NP_SYNCHAFTER
  },
  {
    DBPROP_NOTIFYROWINSERT,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ,
    VT_I4,
    L"Row Insert Notification",
    DBPROPVAL_NP_OKTODO | DBPROPVAL_NP_ABOUTTODO | DBPROPVAL_NP_SYNCHAFTER
  },
  {
    DBPROP_NOTIFYROWRESYNCH,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ,
    VT_I4,
    L"Row Resynchronization Notification",
    DBPROPVAL_NP_OKTODO | DBPROPVAL_NP_ABOUTTODO | DBPROPVAL_NP_SYNCHAFTER
  },
  {
    DBPROP_NOTIFYROWSETCHANGED,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ,
    VT_I4,
    L"Rowset Change Notification",
    DBPROPVAL_NP_OKTODO | DBPROPVAL_NP_ABOUTTODO | DBPROPVAL_NP_SYNCHAFTER
  },
  {
    DBPROP_NOTIFYROWSETFETCHPOSITIONCHANGE,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ,
    VT_I4,
    L"Rowset Fetch Position Change Notification",
    DBPROPVAL_NP_OKTODO | DBPROPVAL_NP_ABOUTTODO | DBPROPVAL_NP_SYNCHAFTER
  },
  {
    DBPROP_NOTIFYROWSETRELEASE,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ,
    VT_I4,
    L"Rowset Release Notification",
    DBPROPVAL_NP_OKTODO | DBPROPVAL_NP_ABOUTTODO | DBPROPVAL_NP_SYNCHAFTER
  },
  {
    DBPROP_NOTIFYROWUNDOCHANGE,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ,
    VT_I4,
    L"Row Undo Change Notification",
    DBPROPVAL_NP_OKTODO | DBPROPVAL_NP_ABOUTTODO | DBPROPVAL_NP_SYNCHAFTER
  },
  {
    DBPROP_NOTIFYROWUNDODELETE,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ,
    VT_I4,
    L"Row Undo Delete Notification",
    DBPROPVAL_NP_OKTODO | DBPROPVAL_NP_ABOUTTODO | DBPROPVAL_NP_SYNCHAFTER
  },
  {
    DBPROP_NOTIFYROWUNDOINSERT,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ,
    VT_I4,
    L"Row Undo Insert Notification",
    DBPROPVAL_NP_OKTODO | DBPROPVAL_NP_ABOUTTODO | DBPROPVAL_NP_SYNCHAFTER
  },
  {
    DBPROP_NOTIFYROWUPDATE,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ,
    VT_I4,
    L"Row Update Notification",
    DBPROPVAL_NP_OKTODO | DBPROPVAL_NP_ABOUTTODO | DBPROPVAL_NP_SYNCHAFTER
  },
  {
    DBPROP_ORDEREDBOOKMARKS,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ | DBPROPFLAGS_WRITE,
    VT_BOOL,
    L"Bookmarks Ordered",
    VARIANT_FALSE
  },
  {
    DBPROP_OTHERINSERT,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ | DBPROPFLAGS_WRITE,
    VT_BOOL,
    L"Others' Inserts Visible",
    VARIANT_FALSE
  },
  {
    DBPROP_OTHERUPDATEDELETE,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ | DBPROPFLAGS_WRITE,
    VT_BOOL,
    L"Others' Changes Visible",
    VARIANT_FALSE
  },
  {
    DBPROP_OWNINSERT,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ | DBPROPFLAGS_WRITE,
    VT_BOOL,
    L"Own Inserts Visible",
    VARIANT_TRUE
  },
  {
    DBPROP_OWNUPDATEDELETE,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ | DBPROPFLAGS_WRITE,
    VT_BOOL,
    L"Own Changes Visible",
    VARIANT_TRUE
  },
  {
    DBPROP_QUICKRESTART,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ | DBPROPFLAGS_WRITE,
    VT_BOOL,
    L"Quick Restart",
    VARIANT_FALSE
  },
  {
    DBPROP_REENTRANTEVENTS,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ,
    VT_BOOL,
    L"Reentrant Events",
    VARIANT_FALSE
  },
  // TODO: Really support this
  {
    DBPROP_REMOVEDELETED,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ | DBPROPFLAGS_WRITE,
    VT_BOOL,
    L"Remove Deleted Rows",
    VARIANT_FALSE
  },
  {
    DBPROP_REPORTMULTIPLECHANGES,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ,
    VT_BOOL,
    L"Report Multiple Changes",
    VARIANT_FALSE
  },
  {
    DBPROP_RETURNPENDINGINSERTS,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ,
    VT_BOOL,
    L"Return Pending Inserts",
    VARIANT_FALSE
  },
  /*{
    DBPROP_ROW_BULKOPS,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ | DBPROPFLAGS_WRITE,
    VT_I4,
    L"Bulk Operations",
    0
  },*/
  {
    DBPROP_ROWRESTRICT,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ,
    VT_BOOL,
    L"Row Privileges",
    VARIANT_FALSE
  },
  {
    DBPROP_ROWSET_ASYNCH,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ | DBPROPFLAGS_WRITE,
    VT_I4,
    L"Asynchronous Rowset Processing",
    0
  },
  {
    DBPROP_ROWTHREADMODEL,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ /*| DBPROPFLAGS_WRITE*/,
    VT_I4,
    L"Row Threading Model",
    DBPROPVAL_RT_FREETHREAD /*| DBPROPVAL_RT_APTMTTHREAD | DBPROPVAL_RT_SINGLETHREAD*/
  },
  {
    DBPROP_SERVERCURSOR,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ /*| DBPROPFLAGS_WRITE*/,
    VT_BOOL,
    L"Server Cursor",
    VARIANT_TRUE // FIXME: make it VARINT_FALSE for forward-only ?
  },
  // TODO: add support of VARIANT_TRUE
  {
    DBPROP_SERVERDATAONINSERT,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ /*| DBPROPFLAGS_WRITE*/,
    VT_BOOL,
    L"Server Data on Insert",
    VARIANT_FALSE
  },
  {
    DBPROP_SKIPROWCOUNTRESULTS,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ /*| DBPROPFLAGS_WRITE*/,
    VT_BOOL,
    L"Skip Row Count Results",
    VARIANT_TRUE
  },
  {
    DBPROP_STRONGIDENTITY,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ,
    VT_BOOL,
    L"Strong Row Identity",
    VARIANT_FALSE
  },
  {
    DBPROP_TRANSACTEDOBJECT,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ /*| DBPROPFLAGS_WRITE*/ | DBPROPFLAGS_COLUMNOK,
    VT_BOOL,
    L"Objects Transacted",
    VARIANT_FALSE
  },
  {
    DBPROP_UNIQUEROWS,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ | DBPROPFLAGS_WRITE,
    VT_BOOL,
    L"Unique Rows",
    VARIANT_FALSE // FIXME: that's what SQL Server does, although logically it must be VARIANT_TRUE
  },
  {
    DBPROP_UPDATABILITY,
    VDBPROPFLAGS_HAS_VALUE | DBPROPFLAGS_READ | DBPROPFLAGS_WRITE,
    VT_I4,
    L"Updatability",
    DBPROPVAL_UP_CHANGE | DBPROPVAL_UP_DELETE | DBPROPVAL_UP_INSERT // TODO: default to 0
  },
};


  /*
   * The value constraint enumerated type is used to limit values of boolean
   * properties.
   * VC_FALSE means that the corresponding property can hold VARIANT_FALSE 
   * only.
   * VC_TRUE means that the corresponding property can hold VARIANT_TRUE only.
   * VC_ANY means that the corresponding property can hold either VARIANT_FALSE
   * or VARIANT_TRUE.
   * The last constraint is used in two situations. First, if a rowset is able
   * to support both values (e.g. a rowset based on a static cursor can have
   * the DBPROP_IRowsetScroll property equal to either of values). Second, if
   * a given property is not applicable to a rowset (e.g. a rowset based on
   * a static cursor in current implementation doesn't support updates and
   * therefore DBPROP_IMMOBILEROWS property is meaningless in that context. So
   * whatever value it has, it doesn't affect anything). One case that is 
   * particularly important is DBPROP_OWNINSERT and DBPROP_OWNUPDATEDELETE
   * properties for the static cursor. ADO wants these properties to be true
   * both for keyset and static cursors (the difference between them is that it
   * wants also DBPROP_OTHERUPDATEDELETE and few other properties to be true
   * only for keyset cursor, but ADO asks for these differing properties after
   * DBPROP_OWNINSERT and DBPROP_OWNUPDATE). Even though Virtuoso's static
   * cursor cannot do this, since we do not have IRowsetChange over static
   * cursor we can safely put VC_ANY in the corresponding rows of the static
   * column. Putting VC_FALSE there confuses current conflict resolution
   * algorithm, and it will always choose keyset cursor instead of static if
   * asked for it in the way ADO asks.
   */

property_constraint_t RowsetPropertySet::rgConstraints[] =
{ /*                          ForwardOnly Dynamic   Keyset    Static  */
  { DBPROP_ABORTPRESERVE,	VC_FALSE, VC_ANY,   VC_ANY,   VC_ANY,	NULL },
  { DBPROP_BOOKMARKS,		VC_ANY,	  VC_ANY,   VC_ANY,   VC_ANY,	&RowsetPropertySet::CheckBookmarks },
  { DBPROP_CANFETCHBACKWARDS,	VC_FALSE, VC_ANY,   VC_ANY,   VC_ANY,	NULL },
  { DBPROP_CANHOLDROWS,		VC_FALSE, VC_FALSE, VC_ANY,   VC_ANY,	NULL },
  { DBPROP_CANSCROLLBACKWARDS,	VC_FALSE, VC_ANY,   VC_ANY,   VC_ANY,	NULL },
  //{ DBPROP_CHANGEINSERTEDROWS,	VC_FALSE, VC_FALSE, VC_FALSE, VC_FALSE,	NULL },
  { DBPROP_COMMITPRESERVE,	VC_FALSE, VC_ANY,   VC_ANY,   VC_ANY,	NULL },
  { DBPROP_IMMOBILEROWS,	VC_ANY,	  VC_FALSE, VC_TRUE,  VC_ANY,	NULL },
  { DBPROP_IRowsetChange,	VC_FALSE, VC_ANY,   VC_ANY,   VC_FALSE, &RowsetPropertySet::CheckIRowsetChange },
  //{ DBPROP_IRowsetFind,		VC_FALSE, VC_FALSE, VC_FALSE, VC_FALSE,	NULL },
  { DBPROP_IRowsetLocate,	VC_FALSE, VC_FALSE, VC_ANY,   VC_ANY,	&RowsetPropertySet::CheckIRowsetLocate },
  { DBPROP_IRowsetRefresh,	VC_FALSE, VC_ANY,   VC_ANY,   VC_FALSE,	NULL },
  { DBPROP_IRowsetResynch,	VC_FALSE, VC_ANY,   VC_ANY,   VC_FALSE,	NULL },
  { DBPROP_IRowsetScroll,	VC_FALSE, VC_FALSE, VC_ANY,   VC_ANY,	&RowsetPropertySet::CheckIRowsetScroll },
  { DBPROP_IRowsetUpdate,	VC_FALSE, VC_ANY,   VC_ANY,   VC_FALSE,	&RowsetPropertySet::CheckIRowsetUpdate },
  { DBPROP_ORDEREDBOOKMARKS,	VC_FALSE, VC_FALSE, VC_ANY,   VC_ANY,	&RowsetPropertySet::CheckOrderedBookmarks },
  { DBPROP_OTHERINSERT,		VC_TRUE,  VC_TRUE,  VC_FALSE, VC_FALSE,	NULL },
  { DBPROP_OTHERUPDATEDELETE,	VC_TRUE,  VC_TRUE,  VC_TRUE,  VC_FALSE,	NULL },
  { DBPROP_OWNINSERT,		VC_ANY,	  VC_TRUE,  VC_TRUE,  VC_ANY,	NULL },
  { DBPROP_OWNUPDATEDELETE,	VC_ANY,	  VC_TRUE,  VC_TRUE,  VC_ANY,	NULL },
  { DBPROP_QUICKRESTART,	VC_FALSE, VC_ANY,   VC_ANY,   VC_ANY,	NULL },
  { DBPROP_REMOVEDELETED,	VC_ANY,	  VC_TRUE,  VC_ANY,   VC_ANY,	NULL },
  //{ DBPROP_SERVERDATAONINSERT,	VC_FALSE, VC_FALSE, VC_FALSE, VC_FALSE,	NULL },
  //{ DBPROP_STRONGIDENTITY,	VC_FALSE, VC_FALSE, VC_FALSE, VC_FALSE,	NULL },
  { DBPROP_UNIQUEROWS,		VC_TRUE,  VC_FALSE, VC_FALSE, VC_FALSE,	NULL },
};

/*
 * NB: The table above somewhere contains values that differ from the default
 *     values of the properties. During and after conflict resolution when some
 *     properties from this table has already been set and some hasn't, the values
 *     of the properties that hasn't might be implied by those that has. At this
 *     time the use of the method HasValue() must be avoided, because it might
 *     get a default value which has already been made obsoleted by some
 *     has-been-set property. GetValue() can be used only after GetValueFlag().
 *     Everything gets back to the normal state after RefineProperties() is
 *     invoked. It explicitly sets values of all the implied properties.
 */

int RowsetPropertySet::cConstraints = sizeof RowsetPropertySet::rgConstraints / sizeof RowsetPropertySet::rgConstraints[0];

PropertySetInfo g_RowsetPropertySetInfo(DBPROPSET_ROWSET,
					DBPROPFLAGS_ROWSET,
					sizeof rowset_properties / sizeof rowset_properties[0],
					rowset_properties);

RowsetPropertySet::RowsetPropertySet()
  : PropertySet(g_RowsetPropertySetInfo, DBPROPFLAGS_READ | DBPROPFLAGS_WRITE)
{
}

RowsetPropertySet::~RowsetPropertySet()
{
}

bool
RowsetPropertySet::Set(PropertyBool& property, VARIANT_BOOL value, bool fRequired)
{
  if (!property.GetValueFlag())
    {
      property.SetValue(value);
      if (fRequired)
	property.SetRequiredFlag(true);
      return true;
    }
  else
    {
      if (property.GetValue() == value)
	{
	  if (fRequired)
	    property.SetRequiredFlag(true);
	  return true;
	}
      if (fRequired && !property.IsRequired())
	{
	  property.SetValue(value);
	  property.SetRequiredFlag(true);
	  return true;
	}
    }
  return false;
}

bool
RowsetPropertySet::CheckBookmarks(VARIANT_BOOL value, bool fRequired)
{
  return (value == VARIANT_TRUE
	  || (Set(prop_ORDEREDBOOKMARKS, VARIANT_FALSE, fRequired)
	      && Set(prop_IRowsetLocate, VARIANT_FALSE, fRequired)
	      && Set(prop_IRowsetScroll, VARIANT_FALSE, fRequired)));
}

bool
RowsetPropertySet::CheckOrderedBookmarks(VARIANT_BOOL value, bool fRequired)
{
  return value == VARIANT_FALSE || Set(prop_BOOKMARKS, VARIANT_TRUE, fRequired);
}

bool
RowsetPropertySet::CheckIRowsetLocate(VARIANT_BOOL value, bool fRequired)
{
  return (value == VARIANT_TRUE
	  ? Set(prop_BOOKMARKS, VARIANT_TRUE, fRequired)
	  : Set(prop_IRowsetScroll, VARIANT_FALSE, fRequired));
}

bool
RowsetPropertySet::CheckIRowsetScroll(VARIANT_BOOL value, bool fRequired)
{
  return (value == VARIANT_FALSE
	  || (Set(prop_IRowsetLocate, VARIANT_TRUE, fRequired)
	      && Set(prop_BOOKMARKS, VARIANT_TRUE, fRequired)));
}

bool
RowsetPropertySet::CheckIRowsetChange(VARIANT_BOOL value, bool fRequired)
{
  return value == VARIANT_TRUE || Set(prop_IRowsetUpdate, VARIANT_FALSE, fRequired);
}

bool
RowsetPropertySet::CheckIRowsetUpdate(VARIANT_BOOL value, bool fRequired)
{
  return value == VARIANT_FALSE || Set(prop_IRowsetChange, VARIANT_TRUE, fRequired);
}

bool
RowsetPropertySet::CheckConstraints(const PropertyBool& prop, VARIANT_BOOL value, bool fRequired)
{
  DBPROPID propid = prop.GetInfo()->id;
  property_constraint_t* pConstraint = NULL;
  for (int iConstraint = 0; iConstraint < cConstraints; iConstraint++)
    if (rgConstraints[iConstraint].dwPropertyID == propid)
      {
	pConstraint = &rgConstraints[iConstraint];
	break;
      }
  if (pConstraint == NULL)
    return true;

  for (int iCursorType = CURSOR_FORWARD_ONLY; iCursorType < CURSOR_TYPES; iCursorType++)
    {
      int iConstraint;
      for (iConstraint = 0; iConstraint < cConstraints; iConstraint++)
	{
	  property_constraint_t* pConstraintOther = &rgConstraints[iConstraint];
	  value_constraint_t vc = pConstraintOther->vc[iCursorType];

	  VARIANT_BOOL valueOther;
	  if (pConstraint == pConstraintOther)
	    {
	      valueOther = value;
	    }
	  else
	    {
	      PropertyBool* propertyOther = static_cast<PropertyBool*>(GetProperty(pConstraintOther->dwPropertyID));
	      assert(propertyOther != 0);
	      if (!propertyOther->GetValueFlag())
		continue;
	      valueOther = propertyOther->GetValue();
	    }

	  if (vc == VC_TRUE)
	    {
	      if (valueOther == VARIANT_FALSE)
		break;
	    }
	  else if (vc == VC_FALSE)
	    {
	      if (valueOther == VARIANT_TRUE)
		break;
	    }
	}

      if (iConstraint == cConstraints)
	{
	  if (pConstraint->pfnCheck != NULL && !(this->*(pConstraint->pfnCheck))(value, fRequired))
	    return false;
	  return true;
	}
    }

  return false;
}

ULONG
RowsetPropertySet::GetCursorType() const
{
  bool fForwardOnly = true;
  bool fDynamic = true;
  bool fKeyset = true;
  bool fStatic = true;

  for (int iConstraint = 0; iConstraint < cConstraints; iConstraint++)
    {
      property_constraint_t* pConstraint = &rgConstraints[iConstraint];

      const PropertyBool* property = static_cast<PropertyBool*>(const_cast<RowsetPropertySet*>(this)->GetProperty(pConstraint->dwPropertyID));
      assert(property != 0);
      if (!property->GetValueFlag())
	continue;

      VARIANT_BOOL value = property->GetValue();

      LOG(("property %s: %d\n", StringFromPropID(DBPROPSET_ROWSET, pConstraint->dwPropertyID), value));
      if (value == VARIANT_TRUE)
	{
	  if (pConstraint->vc[CURSOR_FORWARD_ONLY] == VC_FALSE)
	    fForwardOnly = false;
	  if (pConstraint->vc[CURSOR_DYNAMIC] == VC_FALSE)
	    fDynamic = false;
	  if (pConstraint->vc[CURSOR_KEYSET] == VC_FALSE)
	    fKeyset = false;
	  if (pConstraint->vc[CURSOR_STATIC] == VC_FALSE)
	    fStatic = false;
	}
      else // if (value == VARIANT_FALSE)
	{
	  if (pConstraint->vc[CURSOR_FORWARD_ONLY] == VC_TRUE)
	    fForwardOnly = false;
	  if (pConstraint->vc[CURSOR_DYNAMIC] == VC_TRUE)
	    fDynamic = false;
	  if (pConstraint->vc[CURSOR_KEYSET] == VC_TRUE)
	    fKeyset = false;
	  if (pConstraint->vc[CURSOR_STATIC] == VC_TRUE)
	    fStatic = false;
	}

      LOG(("%d %d %d %d\n", fForwardOnly, fDynamic, fKeyset, fStatic));
    }

  /* The order is important in case more than one cursor type complies with
     the requested properties. The conditions below are put in the ordrer
     to choose more efficient cursors types over less efficient ones.
     The static cursor type is before keyset because when ADO wants static
     cursor it sets the properties in such a way that both static and keyset
     cursors are possible, when it wants keyset cursor it sets properties in
     such a way that only keyset cursor is possible. */
  if (fForwardOnly)
    return SQL_CURSOR_FORWARD_ONLY;
  if (fDynamic)
    return SQL_CURSOR_DYNAMIC;
  if (fStatic)
    return SQL_CURSOR_STATIC;
  if (fKeyset)
    return SQL_CURSOR_KEYSET_DRIVEN;

  assert(0);
  return SQL_CURSOR_TYPE_DEFAULT;
}

ULONG
RowsetPropertySet::GetConcurrency() const
{
  if (prop_IRowsetChange.GetValue() == VARIANT_FALSE)
    return SQL_CONCUR_READ_ONLY;
  if (prop_LOCKMODE.GetValue() == DBPROPVAL_LM_NONE)
    return SQL_CONCUR_VALUES;
  return SQL_CONCUR_LOCK;
}

void
RowsetPropertySet::RefineProperties(ULONG ulCursorType, ULONG ulConcurrency, bool fUniqueRows)
{
  int iCursorType;
  switch (ulCursorType)
    {
    case SQL_CURSOR_FORWARD_ONLY:   iCursorType = CURSOR_FORWARD_ONLY;  break;
    case SQL_CURSOR_DYNAMIC:	    iCursorType = CURSOR_DYNAMIC;	break;
    case SQL_CURSOR_KEYSET_DRIVEN:  iCursorType = CURSOR_KEYSET;	break;
    case SQL_CURSOR_STATIC:	    iCursorType = CURSOR_STATIC;	break;
    default:
      assert(0);
    }

  for (int iConstraint = 0; iConstraint < cConstraints; iConstraint++)
    {
      property_constraint_t* pConstraint = &rgConstraints[iConstraint];
      value_constraint_t vc = pConstraint->vc[iCursorType];
      PropertyBool* property = static_cast<PropertyBool*>(GetProperty(pConstraint->dwPropertyID));
      assert(property != 0);

      if (vc == VC_TRUE)
	property->SetValue(VARIANT_TRUE);
      else if (vc == VC_FALSE)
	property->SetValue(VARIANT_FALSE);
      // else if (vc == VC_ANY) do nothing 
    }

  if (ulConcurrency == SQL_CONCUR_READ_ONLY)
    {
      prop_IRowsetUpdate.SetValue(VARIANT_FALSE);
      prop_IRowsetChange.SetValue(VARIANT_FALSE);
      prop_LOCKMODE.SetValue(DBPROPVAL_LM_NONE);
    }
  else if (ulConcurrency == SQL_CONCUR_LOCK)
    {
      prop_LOCKMODE.SetValue(DBPROPVAL_LM_SINGLEROW);
    }
  else
    {
      prop_LOCKMODE.SetValue(DBPROPVAL_LM_NONE);
    }

  prop_UNIQUEROWS.SetValue(fUniqueRows ? VARIANT_TRUE : VARIANT_FALSE);
}

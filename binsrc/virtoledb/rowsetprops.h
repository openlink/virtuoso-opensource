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

#ifndef ROWSETPROPS_H
#define ROWSETPROPS_H

#include "properties.h"


class RowsetPropertySet;


enum value_constraint_t
{
  VC_FALSE,
  VC_TRUE,
  VC_ANY,
};

enum cursor_type_t
{
  CURSOR_FORWARD_ONLY	= 0,
  CURSOR_DYNAMIC	= 1,
  CURSOR_KEYSET		= 2,
  CURSOR_STATIC		= 3,
  CURSOR_TYPES		= 4
};

struct property_constraint_t
{
  DBPROPID dwPropertyID;
  value_constraint_t vc[CURSOR_TYPES];
  bool (RowsetPropertySet::*pfnCheck)(VARIANT_BOOL value, bool fRequired);
};


class RowsetPropertySet : public PropertySet
{
private:

  static int cConstraints;
  static property_constraint_t rgConstraints[];

  bool Set(PropertyBool& property, VARIANT_BOOL value, bool fRequired);

  bool CheckBookmarks(VARIANT_BOOL value, bool fRequired);
  bool CheckOrderedBookmarks(VARIANT_BOOL value, bool fRequired);
  bool CheckIRowsetLocate(VARIANT_BOOL value, bool fRequired);
  bool CheckIRowsetScroll(VARIANT_BOOL value, bool fRequired);
  bool CheckIRowsetChange(VARIANT_BOOL value, bool fRequired);
  bool CheckIRowsetUpdate(VARIANT_BOOL value, bool fRequired);

  class PropertyConstrained  : public PropertyBool
  {
  public:

    virtual bool
    ResolveConflicts(PropertySet* propset, const DBID& colid, const VARIANT& value, bool fRequired) const
    {
      return static_cast<RowsetPropertySet*>(propset)->CheckConstraints(*this, V_BOOL(&value), fRequired);
    }
  };

  class PropertyAccessOrder : public PropertyI4
  {
  public:

    virtual bool
    IsValidValue(const VARIANT *value) const
    {
      if (V_VT(value) == VT_EMPTY)
	return true;
      if (PropertyI4::IsValidValue(value))
	switch(V_I4(value))
	  {
	  case DBPROPVAL_AO_RANDOM:
	  case DBPROPVAL_AO_SEQUENTIALSTORAGEOBJECTS:
	  case DBPROPVAL_AO_SEQUENTIAL:
	    return true;
	  }
      return false;
    }
  };

  class PropertyBookmarkType : public PropertyI4
  {
  public:

    virtual bool
    IsValidValue(const VARIANT *value) const
    {
      if (V_VT(value) == VT_EMPTY)
	return true;
      if (PropertyI4::IsValidValue(value))
	switch(V_I4(value))
	  {
	  case DBPROPVAL_BMK_NUMERIC:
	  case DBPROPVAL_BMK_KEY:
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

  class PropertyLockMode : public PropertyI4
  {
  public:

    virtual bool
    IsValidValue(const VARIANT *value) const
    {
      if (V_VT(value) == VT_EMPTY)
	return true;
      if (PropertyI4::IsValidValue(value))
	switch(V_I4(value))
	  {
	  case DBPROPVAL_LM_NONE:
	  case DBPROPVAL_LM_SINGLEROW:
	    return true;
	  }
      return false;
    }
  };

  class PropertyRowCount : public PropertyI4
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

  class PropertyNotificationGranularity : public PropertyI4
  {
  public:

    virtual bool
    IsValidValue(const VARIANT *value) const
    {
      if (V_VT(value) == VT_EMPTY)
	return true;
      if (PropertyI4::IsValidValue(value))
	switch(V_I4(value))
	  {
	  case DBPROPVAL_NT_SINGLEROW:
	  case DBPROPVAL_NT_MULTIPLEROWS:
	    return true;
	  }
      return false;
    }
  };

  class PropertyRowBulkOps : public PropertyI4
  {
  };

  class PropertyRowsetAsynch : public PropertyI4
  {
  };

  class PropertyThreadModel : public PropertyI4
  {
  };

  class PropertyUpdatability : public PropertyI4
  {
  };

public:

  RowsetPropertySet();
  ~RowsetPropertySet();

  ULONG GetCursorType() const;
  ULONG GetConcurrency() const;

  bool
  HasBookmark() const 
  {
    return prop_BOOKMARKS.GetValue() == VARIANT_TRUE;
  }

  bool
  HasUniqueRows() const
  {
    return prop_UNIQUEROWS.GetValue() == VARIANT_TRUE;
  }

  bool CheckConstraints(const PropertyBool& prop, VARIANT_BOOL value, bool fRequired);

  void RefineProperties(ULONG ulCursorType, ULONG ulConcurrency, bool fUniqueRows);

#define ROWSET_PROPERTY_SET\
  ELT(PropertyConstrained, ABORTPRESERVE)\
  ELT(PropertyAccessOrder, ACCESSORDER)\
  /*ELT(PropertyBool, APPENDONLY)*/\
  ELT(PropertyBool, BLOCKINGSTORAGEOBJECTS)\
  ELT(PropertyI4, BOOKMARKINFO)\
  ELT(PropertyConstrained, BOOKMARKS)\
  ELT(PropertyBool, BOOKMARKSKIPPED)\
  ELT(PropertyBookmarkType, BOOKMARKTYPE)\
  ELT(PropertyBool, CACHEDEFERRED)\
  ELT(PropertyConstrained, CANFETCHBACKWARDS)\
  ELT(PropertyConstrained, CANHOLDROWS)\
  ELT(PropertyConstrained, CANSCROLLBACKWARDS)\
  ELT(PropertyConstrained, CHANGEINSERTEDROWS)\
  ELT(PropertyBool, COLUMNRESTRICT)\
  ELT(PropertyTimeout, COMMANDTIMEOUT)\
  ELT(PropertyConstrained, COMMITPRESERVE)\
  ELT(PropertyBool, DEFERRED)\
  ELT(PropertyBool, DELAYSTORAGEOBJECTS)\
  ELT(PropertyI4, FINDCOMPAREOPS)\
  ELT(PropertyI4, HIDDENCOLUMNS)\
  ELT(PropertyBool, IAccessor)\
  ELT(PropertyBool, IColumnsInfo)\
  /*ELT(PropertyBool, IColumnsInfo2)*/\
  ELT(PropertyBool, IColumnsRowset)\
  ELT(PropertyBool, IConnectionPointContainer)\
  ELT(PropertyBool, IConvertType)\
  /*ELT(PropertyBool, IDBAsynchStatus)*/\
  /*ELT(PropertyBool, ILockBytes)*/\
  ELT(PropertyConstrained, IMMOBILEROWS)\
  ELT(PropertyBool, IMultipleResults)\
  ELT(PropertyBool, IRowset)\
  /*ELT(PropertyBool, IRowsetBookmark)*/\
  ELT(PropertyConstrained, IRowsetChange)\
  /*ELT(PropertyConstrained, IRowsetFind)*/\
  ELT(PropertyBool, IRowsetIdentity)\
  ELT(PropertyBool, IRowsetInfo)\
  ELT(PropertyConstrained, IRowsetLocate)\
  ELT(PropertyConstrained, IRowsetRefresh)\
  ELT(PropertyConstrained, IRowsetResynch)\
  ELT(PropertyConstrained, IRowsetScroll)\
  ELT(PropertyConstrained, IRowsetUpdate)\
  ELT(PropertyBool, ISequentialStream)\
  /*ELT(PropertyBool, IStorage)*/\
  /*ELT(PropertyBool, IStream)*/\
  ELT(PropertyBool, ISupportErrorInfo)\
  ELT(PropertyBool, LITERALBOOKMARKS)\
  ELT(PropertyBool, LITERALIDENTITY)\
  ELT(PropertyLockMode, LOCKMODE)\
  ELT(PropertyRowCount, MAXOPENROWS)\
  ELT(PropertyRowCount, MAXPENDINGROWS)\
  ELT(PropertyRowCount, MAXROWS)\
  /*ELT(PropertyBool, MAYWRITECOLUMN)*/\
  /*ELT(PropertyI4, MEMORYUSAGE)*/\
  ELT(PropertyNotificationGranularity, NOTIFICATIONGRANULARITY)\
  ELT(PropertyI4, NOTIFICATIONPHASES)\
  ELT(PropertyI4, NOTIFYCOLUMNSET)\
  ELT(PropertyI4, NOTIFYROWDELETE)\
  ELT(PropertyI4, NOTIFYROWFIRSTCHANGE)\
  ELT(PropertyI4, NOTIFYROWINSERT)\
  ELT(PropertyI4, NOTIFYROWRESYNCH)\
  ELT(PropertyI4, NOTIFYROWSETCHANGED)\
  ELT(PropertyI4, NOTIFYROWSETFETCHPOSITIONCHANGE)\
  ELT(PropertyI4, NOTIFYROWSETRELEASE)\
  ELT(PropertyI4, NOTIFYROWUNDOCHANGE)\
  ELT(PropertyI4, NOTIFYROWUNDODELETE)\
  ELT(PropertyI4, NOTIFYROWUNDOINSERT)\
  ELT(PropertyI4, NOTIFYROWUPDATE)\
  ELT(PropertyConstrained, ORDEREDBOOKMARKS)\
  ELT(PropertyConstrained, OTHERINSERT)\
  ELT(PropertyConstrained, OTHERUPDATEDELETE)\
  ELT(PropertyConstrained, OWNINSERT)\
  ELT(PropertyConstrained, OWNUPDATEDELETE)\
  ELT(PropertyConstrained, QUICKRESTART)\
  ELT(PropertyBool, REENTRANTEVENTS)\
  ELT(PropertyConstrained, REMOVEDELETED)\
  ELT(PropertyBool, REPORTMULTIPLECHANGES)\
  ELT(PropertyBool, RETURNPENDINGINSERTS)\
  /*ELT(PropertyRowBulkOps, ROW_BULKOPS)*/\
  ELT(PropertyBool, ROWRESTRICT)\
  ELT(PropertyRowsetAsynch, ROWSET_ASYNCH)\
  ELT(PropertyThreadModel, ROWTHREADMODEL)\
  ELT(PropertyBool, SERVERCURSOR)\
  ELT(PropertyConstrained, SERVERDATAONINSERT)\
  ELT(PropertyBool, SKIPROWCOUNTRESULTS)\
  ELT(PropertyConstrained, STRONGIDENTITY)\
  ELT(PropertyBool, TRANSACTEDOBJECT)\
  ELT(PropertyBool, UNIQUEROWS)\
  ELT(PropertyUpdatability, UPDATABILITY)

#undef ELT
#define ELT(type, name) type prop_##name;

  ROWSET_PROPERTY_SET

#undef ELT
#define ELT(type, name) case DBPROP_##name: return &prop_##name;

  virtual Property*
  GetProperty(DBPROPID id)
  {
    switch (id)
      {
	ROWSET_PROPERTY_SET
      }
    return NULL;
  }
};


#endif

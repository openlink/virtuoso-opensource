/*  properties.h
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

#ifndef PROPERTIES_H
#define PROPERTIES_H

#include "error.h"


class PropertySet;
class Property;

/*
 * Used in a PropertyInfo structure this flag indicates that the property
 * has a default value. This value should be taken with care to avoid any
 * clashes with standard DBPROPFLAGS.
 */
enum VDBPROPFLAGS
{
  VDBPROPFLAGS_HAS_VALUE = 0x80000000,
};

#define PROPFLAGS(flags) (flags & ~(VDBPROPFLAGS_HAS_VALUE))

struct PropertyInfo
{
  DBPROPID id;
  DBPROPFLAGS flags;
  VARTYPE type;
  WCHAR *description;
  LONG_PTR value;
};


class PropertySetInfo
{
public:

  PropertySetInfo
  (
    REFGUID rguid,
    DBPROPFLAGS group,
    int property_size,
    PropertyInfo *property_info
  );

  ~PropertySetInfo();

  REFGUID
  GetGUID() const
  {
    return ps_rguid;
  }

  DBPROPFLAGS const
  GetPropertyGroup()
  {
    return ps_group;
  }

  ULONG
  GetPropertyCount() const
  {
    return ps_property_size;
  }

  const PropertyInfo*
  GetPropertyInfoByIndex(ULONG index) const
  {
    if (index < 0 || index >= ps_property_size)
      return NULL;
    return &ps_property_info[index];
  }

  const PropertyInfo *GetPropertyInfoById(DBPROPID id) const;

private:

  REFGUID ps_rguid;
  DBPROPFLAGS ps_group;
  ULONG ps_property_size;
  PropertyInfo *ps_property_info;
};


class PropertySetInfoRepository
{
public:

  bool Register(PropertySetInfo*);
  void Unregister(PropertySetInfo*);

  PropertySetInfo *GetPropertySetInfo(REFGUID rguid);

  HRESULT GetPropertyInfo
  (
    ULONG cPropertyIDSets,
    const DBPROPIDSET rgPropertyIDSets[],
    ULONG *pcPropertyInfoSets,
    DBPROPINFOSET **prgPropertyInfoSets,
    OLECHAR **ppDescBuffer
  );

private:

  typedef std::list<PropertySetInfo *> PropertySetInfoList;
  typedef PropertySetInfoList::iterator PropertySetInfoIter;

  PropertySetInfoList ps_info_list;
};


class PropertySuperset
{
public:

  PropertySuperset();
  ~PropertySuperset();

  HRESULT GetProperties
  (
    ULONG cPropertyIDSets,
    const DBPROPIDSET rgPropertyIDSets[],
    ULONG *pcPropertySets,
    DBPROPSET **prgPropertySets
  );

  HRESULT SetProperties
  (
    ULONG cPropertySets,
    DBPROPSET rgPropertySets[],
    bool bIsCreating = false
  );

protected:

  virtual ULONG GetPropertySetCount() = 0;
  virtual PropertySet* GetPropertySet(ULONG iPropertySet) = 0;
  virtual PropertySet* GetPropertySet(REFGUID rguidPropertySet) = 0;

private:

  typedef std::vector<PropertySet *> PropertySetList;
  typedef PropertySetList::iterator PropertySetIter;

  PropertySetList pss_in_error_sets;
};


class PropertySet
{
public:

  PropertySet(const PropertySetInfo &, DBPROPFLAGS flags);
  virtual ~PropertySet();

  virtual bool Init();

  static HRESULT GetProperty(PropertySet *propset, Property *property, DBPROP *dbprop);
  static HRESULT SetProperty(PropertySet *propset, Property *property, DBPROP *dbprop);

  HRESULT Copy(const PropertySet* property_set);

  REFGUID
  GetGUID()
  {
    return ps_info.GetGUID();
  }

  DBPROPFLAGS
  GetPropertyFlags()
  {
    return ps_flags;
  }

  const PropertySetInfo*
  GetPropertySetInfo()
  {
    return &ps_info;
  }

  int
  GetPropertyCount() const
  {
    return ps_info.GetPropertyCount();
  }

  const PropertyInfo*
  GetPropertyInfo(int index) const
  {
    return ps_info.GetPropertyInfoByIndex(index);
  }

  void
  SetPropertyFlags(DBPROPFLAGS flags)
  {
    ps_flags = flags;
  }

  typedef std::vector<DBPROPID> PropertyList;
  typedef PropertyList::iterator PropertyIter;

  const PropertyList&
  GetInErrorProperties() const
  {
    return ps_in_error_props;
  }

  HRESULT ConvertRowsetIIDToPropertyID(REFIID riid, DBPROPID& propid);
  HRESULT SetRowsetProperty(DBPROPID propid);

  virtual Property* GetProperty(DBPROPID id) = 0;

private:

  const PropertySetInfo &ps_info;
  DBPROPFLAGS ps_flags; // used for read & write flags
  PropertyList ps_in_error_props;
};


class Property
{
public:

  Property();
  virtual ~Property();

  virtual void Init(const PropertyInfo* info);
  HRESULT Copy(PropertySet* dstpropset, const PropertySet* srcpropset, const Property* property);

  virtual bool IsValidValue(const VARIANT* value) const = 0;
  virtual bool IsEqual(const PropertySet* propset, const DBID& colid, const VARIANT& value) const = 0;
  virtual HRESULT GetValue(const PropertySet* propset, const DBID& colid, VARIANT& value) const = 0;
  virtual HRESULT SetValue(PropertySet* propset, const DBID& colid, const VARIANT& value) = 0;

  virtual bool
  ResolveConflicts(PropertySet* propset, const DBID& colid, const VARIANT& value, bool fRequired) const
  {
    return true;
  }

  virtual DBPROPFLAGS
  GetPropertyFlags(const DBID& colid) const
  {
    return GetPropertyFlags();
  }

  virtual bool
  IsRequired(const DBID& colid) const
  {
    return IsRequired();
  }

  virtual void
  SetRequiredFlag(const DBID& colid, bool flag)
  {
    SetRequiredFlag(flag);
  }

  virtual bool
  HasValue(const DBID& colid) const
  {
    return HasValue();
  }

  virtual void
  SetValueFlag(const DBID& colid, bool flag)
  {
    SetValueFlag(flag);
  }

  virtual bool
  GetValueFlag(const DBID& colid) const
  {
    return GetValueFlag();
  }

  const PropertyInfo*
  GetInfo() const
  {
    return p_info;
  }

  DBPROPFLAGS
  GetPropertyFlags() const
  {
    assert(p_info != NULL);
    return PROPFLAGS(p_flags | p_info->flags);
  }

  bool
  IsRequired() const
  {
    return (p_flags & DBPROPFLAGS_REQUIRED) != 0;
  }

  void
  SetRequiredFlag(bool flag)
  {
    if (flag)
      p_flags |= DBPROPFLAGS_REQUIRED;
    else
      p_flags &= ~DBPROPFLAGS_REQUIRED;
  }

  bool
  HasValue() const
  {
    assert(p_info != NULL);
    return ((p_flags | p_info->flags) & VDBPROPFLAGS_HAS_VALUE) != 0;
  }

  void
  SetValueFlag(bool flag)
  {
    if (flag)
      p_flags |= VDBPROPFLAGS_HAS_VALUE;
    else
      p_flags &= ~VDBPROPFLAGS_HAS_VALUE;
  }

  bool
  GetValueFlag() const
  {
    return (p_flags & VDBPROPFLAGS_HAS_VALUE) != 0;
  }

private:

  const PropertyInfo* p_info;
  DBPROPFLAGS p_flags;
};


class PropertyBoolBase : public Property
{
public:

  virtual bool IsValidValue(const VARIANT* value) const;
  virtual bool IsEqual(const PropertySet* propset, const DBID& colid, const VARIANT& value) const;
  virtual HRESULT GetValue(const PropertySet* propset, const DBID& colid, VARIANT& value) const;
  virtual HRESULT SetValue(PropertySet* propset, const DBID& colid, const VARIANT& value);

  virtual HRESULT GetValue(const PropertySet* propset, const DBID& colid, VARIANT_BOOL& value) const = 0;
  virtual HRESULT SetValue(PropertySet* propset, const DBID& colid, VARIANT_BOOL value) = 0;
};


class PropertyI2Base : public Property
{
public:

  virtual bool IsValidValue(const VARIANT* value) const;
  virtual bool IsEqual(const PropertySet* propset, const DBID& colid, const VARIANT& value) const;
  virtual HRESULT GetValue(const PropertySet* propset, const DBID& colid, VARIANT& value) const;
  virtual HRESULT SetValue(PropertySet* propset, const DBID& colid, const VARIANT& value);

  virtual HRESULT GetValue(const PropertySet* propset, const DBID& colid, SHORT& value) const = 0;
  virtual HRESULT SetValue(PropertySet* propset, const DBID& colid, SHORT value) = 0;
};


class PropertyI4Base : public Property
{
public:

  virtual bool IsValidValue(const VARIANT* value) const;
  virtual bool IsEqual(const PropertySet* propset, const DBID& colid, const VARIANT& value) const;
  virtual HRESULT GetValue(const PropertySet* propset, const DBID& colid, VARIANT& value) const;
  virtual HRESULT SetValue(PropertySet* propset, const DBID& colid, const VARIANT& value);

  virtual HRESULT GetValue(const PropertySet* propset, const DBID& colid, LONG& value) const = 0;
  virtual HRESULT SetValue(PropertySet* propset, const DBID& colid, LONG value) = 0;
};


class PropertyBSTRBase : public Property
{
public:

  virtual bool IsValidValue(const VARIANT* value) const;
  virtual bool IsEqual(const PropertySet* propset, const DBID& colid, const VARIANT& value) const;
  virtual HRESULT GetValue(const PropertySet* propset, const DBID& colid, VARIANT& value) const;
  virtual HRESULT SetValue(PropertySet* propset, const DBID& colid, const VARIANT& value);

  virtual HRESULT GetValue(const PropertySet* propset, const DBID& colid, BSTR& value) const = 0;
  virtual HRESULT SetValue(PropertySet* propset, const DBID& colid, BSTR value) = 0;
};


template<class BaseClass, class ValueType>
class ReadOnlyProperty : public BaseClass
{
  virtual HRESULT
  GetValue(const PropertySet* propset, const DBID& colid, ValueType& value) const
  {
    value = (ValueType) GetInfo()->value;
    return S_OK;
  }

  virtual HRESULT
  SetValue(PropertySet* propset, const DBID& colid, ValueType value)
  {
    assert(0);
    return ErrorInfo::Set(E_FAIL);
  }
};


template<>
class ReadOnlyProperty<PropertyBSTRBase, LPOLESTR> : public PropertyBSTRBase
{
public:

  virtual HRESULT
  GetValue(const PropertySet* propset, const DBID& colid, BSTR& value) const
  {
    LPCOLESTR property_value = (LPCOLESTR) GetInfo()->value;
    if (property_value == NULL)
      {
	value = NULL;
      }
    else
      {
	value = SysAllocString(property_value);
	if (value == NULL)
	  return ErrorInfo::Set(E_OUTOFMEMORY);
      }
    return S_OK;
  }

  virtual HRESULT
  SetValue(PropertySet* propset, const DBID& colid, BSTR value)
  {
    assert(0);
    return ErrorInfo::Set(E_FAIL);
  }
};


template<class BaseClass, class ValueType>
class SimpleProperty : public BaseClass
{
public:

  SimpleProperty() {}
  ~SimpleProperty() {}

  virtual HRESULT
  GetValue(const PropertySet* propset, const DBID& colid, ValueType& value) const
  {
    value = GetValue();
    return S_OK;
  }

  virtual HRESULT
  SetValue(PropertySet* propset, const DBID& colid, ValueType value)
  {
    SetValue(value);
    return S_OK;
  }

  ValueType
  GetValue() const
  {
    assert(HasValue());
    return GetValueFlag() ? p_value : (ValueType) (GetInfo()->value);
  }

  void
  SetValue(ValueType value)
  {
    p_value = value;
    SetValueFlag(true);
  }

private:

  ValueType p_value;
};


template<>
class SimpleProperty<PropertyBSTRBase, LPOLESTR> : public PropertyBSTRBase
{
public:

  SimpleProperty()
  {
    p_value = NULL;
  }

  ~SimpleProperty()
  {
    if (p_value != NULL)
      SysFreeString(p_value);
  }

  virtual HRESULT
  GetValue(const PropertySet* propset, const DBID& colid, BSTR& value) const
  {
    LPCOLESTR property_value = GetValue();
    if (property_value == NULL)
      {
	value = NULL;
      }
    else
      {
	value = SysAllocString(property_value);
	if (value == NULL)
	  return ErrorInfo::Set(E_OUTOFMEMORY);
      }
    return S_OK;
  }

  virtual HRESULT
  SetValue(PropertySet* propset, const DBID& colid, BSTR value)
  {
    if (value == NULL)
      {
	SetValue(NULL);
      }
    else
      {
	LPOLESTR new_value = SysAllocString(value);
	if (new_value == NULL)
	  return ErrorInfo::Set(E_OUTOFMEMORY);
	SetValue(new_value);
      }
    return S_OK;
  }

  LPCOLESTR
  GetValue() const
  {
    assert(HasValue());
    return GetValueFlag() ? p_value : (LPCOLESTR) GetInfo()->value;
  }

  void
  SetValue(LPOLESTR value)
  {
    if (p_value != NULL)
      SysFreeString(p_value);
    p_value = value;
    SetValueFlag(true);
  }

private:

  LPOLESTR p_value;
};

typedef ReadOnlyProperty<PropertyBoolBase, VARIANT_BOOL>	PropertyBoolRO;
typedef ReadOnlyProperty<PropertyI2Base,   SHORT>		PropertyI2RO;
typedef ReadOnlyProperty<PropertyI4Base,   LONG>		PropertyI4RO;
typedef ReadOnlyProperty<PropertyBSTRBase, LPOLESTR>		PropertyBSTRRO;

typedef SimpleProperty<PropertyBoolBase, VARIANT_BOOL>		PropertyBool;
typedef SimpleProperty<PropertyI2Base,   SHORT>			PropertyI2;
typedef SimpleProperty<PropertyI4Base,   LONG>			PropertyI4;
typedef SimpleProperty<PropertyBSTRBase, LPOLESTR>		PropertyBSTR;


#endif

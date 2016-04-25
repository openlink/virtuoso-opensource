/*  properties.cpp
 *
 *  $Id$
 *  
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *  
 *  Copyright (C) 1998-2016 OpenLink Software
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
#include "properties.h"
#include "error.h"

/**********************************************************************/
/* PropertySetInfo	                                              */

PropertySetInfo::PropertySetInfo(
  REFGUID rguid,
  DBPROPFLAGS group,
  int property_size,
  PropertyInfo *property_info
)
  : ps_rguid(rguid),
    ps_group(group),
    ps_property_size(property_size),
    ps_property_info(property_info)
{
}

PropertySetInfo::~PropertySetInfo()
{
}

const PropertyInfo *
PropertySetInfo::GetPropertyInfoById(DBPROPID id) const
{
  for (ULONG i = 0; i < GetPropertyCount(); i++)
    {
      const PropertyInfo *info = GetPropertyInfoByIndex(i);
      if (info->id == id)
	return info;
    }
  return NULL;
}

/**********************************************************************/
/* PropertySetInfoRepository                                          */

bool
PropertySetInfoRepository::Register(PropertySetInfo *info)
{
  bool rc = true;
  try {
    ps_info_list.push_back(info);
  } catch (std::bad_alloc &) {
    rc = false;
  }
  return rc;
}

void
PropertySetInfoRepository::Unregister(PropertySetInfo *info)
{
  ps_info_list.remove(info);
}

static int
operator==(const PropertySetInfo *property_set_info, REFGUID rguid)
{
  return property_set_info->GetGUID() == rguid;
}

PropertySetInfo *
PropertySetInfoRepository::GetPropertySetInfo(REFGUID rguid)
{
  PropertySetInfoIter iter = std::find(ps_info_list.begin(), ps_info_list.end(), rguid);
  if (iter == ps_info_list.end())
    return NULL;
  return *iter;
}

HRESULT
PropertySetInfoRepository::GetPropertyInfo(
  ULONG cPropertyIDSets,
  const DBPROPIDSET rgPropertyIDSets[],
  ULONG *pcPropertyInfoSets,
  DBPROPINFOSET **prgPropertyInfoSets,
  OLECHAR **ppDescBuffer
)
{
  if (pcPropertyInfoSets != NULL)
    *pcPropertyInfoSets = 0;
  if (prgPropertyInfoSets != NULL)
    *prgPropertyInfoSets = NULL;
  if (ppDescBuffer != NULL)
    *ppDescBuffer = NULL;

  if (pcPropertyInfoSets == NULL || prgPropertyInfoSets == NULL)
    return ErrorInfo::Set(E_INVALIDARG);
  if (cPropertyIDSets != 0 && rgPropertyIDSets == NULL)
    return ErrorInfo::Set(E_INVALIDARG);

  ULONG propset_count, prop_count;

  DBPROPFLAGS property_groups = 0;
  if (cPropertyIDSets == 0)
    {
      property_groups = (DBPROPFLAGS_COLUMN
	                 | DBPROPFLAGS_DATASOURCE
			 | DBPROPFLAGS_DATASOURCECREATE
			 | DBPROPFLAGS_DATASOURCEINFO
			 | DBPROPFLAGS_DBINIT
			 | DBPROPFLAGS_INDEX
			 | DBPROPFLAGS_ROWSET
			 | DBPROPFLAGS_SESSION
#if OLEDBVER >= 0x0260
			 | DBPROPFLAGS_STREAM
#endif
			 | DBPROPFLAGS_TABLE
			 | DBPROPFLAGS_TRUSTEE
			 | DBPROPFLAGS_VIEW);
    }
  else
    {
      bool normal_guids = false;
      bool special_guids = false;

      // Check to see if rgPropertySets is valid.
      for (propset_count = 0; propset_count < cPropertyIDSets; propset_count++)
	{
	  const DBPROPIDSET *dbpropidset = &rgPropertyIDSets[propset_count];

	  bool is_special = true;
	  if (dbpropidset->guidPropertySet == DBPROPSET_COLUMNALL)
            property_groups |= DBPROPFLAGS_COLUMN;
	  else if (dbpropidset->guidPropertySet == DBPROPSET_CONSTRAINTALL)
	    ;
	  else if (dbpropidset->guidPropertySet == DBPROPSET_DATASOURCEALL)
            property_groups |= DBPROPFLAGS_DATASOURCE;
	  else if (dbpropidset->guidPropertySet == DBPROPSET_DATASOURCEINFOALL)
	    property_groups |= DBPROPFLAGS_DATASOURCEINFO;
	  else if (dbpropidset->guidPropertySet == DBPROPSET_DBINITALL)
	    property_groups |= DBPROPFLAGS_DBINIT;
	  else if (dbpropidset->guidPropertySet == DBPROPSET_INDEXALL)
	    property_groups |= DBPROPFLAGS_INDEX;
	  else if (dbpropidset->guidPropertySet == DBPROPSET_ROWSETALL)
	    property_groups |= DBPROPFLAGS_ROWSET;
	  else if (dbpropidset->guidPropertySet == DBPROPSET_SESSIONALL)
	    property_groups |= DBPROPFLAGS_SESSION;
#if 0 && OLEDBVER >= 0x0260
	  else if (dbpropidset->guidPropertySet == DBPROPSET_STREAMALL)
	    property_groups |= DBPROPFLAGS_STREAM;
#endif
	  else if (dbpropidset->guidPropertySet == DBPROPSET_TABLEALL)
	    property_groups |= DBPROPFLAGS_TABLE;
	  else if (dbpropidset->guidPropertySet == DBPROPSET_TRUSTEEALL)
	    property_groups |= DBPROPFLAGS_TRUSTEE;
	  else if (dbpropidset->guidPropertySet == DBPROPSET_VIEWALL)
	    property_groups |= DBPROPFLAGS_VIEW;
	  else
	    is_special = false;

	  if (is_special)
	    {
	      if (normal_guids)
		return ErrorInfo::Set(E_INVALIDARG);
	      special_guids = true;
	    }
	  else
	    {
	      if (special_guids)
		return ErrorInfo::Set(E_INVALIDARG);
	      normal_guids = true;
	    }
	  if (dbpropidset->cPropertyIDs != 0 && dbpropidset->rgPropertyIDs == NULL)
	    return ErrorInfo::Set(E_INVALIDARG);
	}

      if (special_guids)
	{
	  cPropertyIDSets = 0;
	  rgPropertyIDSets = NULL;
	}
    }

  ULONG cPropertyInfoSets = cPropertyIDSets;
  if (cPropertyInfoSets == 0)
    {
      PropertySetInfoIter iter = ps_info_list.begin();
      while (iter != ps_info_list.end())
	{
	  PropertySetInfo *propset_info = *iter;
	  if ((propset_info->GetPropertyGroup() & property_groups) != 0)
	    cPropertyInfoSets++;
	  iter++;
	}
      if (cPropertyInfoSets == 0)
	return S_OK;
    }

  DBPROPINFOSET *rgPropertyInfoSets = (DBPROPINFOSET *) CoTaskMemAlloc(cPropertyInfoSets * sizeof(DBPROPINFOSET));
  if (rgPropertyInfoSets == NULL)
    return ErrorInfo::Set(E_OUTOFMEMORY);

  if (cPropertyIDSets == 0)
    {
      propset_count = 0;
      PropertySetInfoIter iter = ps_info_list.begin();
      while (iter != ps_info_list.end())
	{
	  PropertySetInfo *propset_info = *iter;
	  if ((propset_info->GetPropertyGroup() & property_groups) != 0)
	    {
	      assert(propset_count < cPropertyInfoSets);
	      rgPropertyInfoSets[propset_count].guidPropertySet = propset_info->GetGUID();
	      rgPropertyInfoSets[propset_count].cPropertyInfos = 0;
	      rgPropertyInfoSets[propset_count].rgPropertyInfos = NULL;
	      propset_count++;
	    }
	  iter++;
	}
      assert(propset_count == cPropertyInfoSets);
    }
  else
    {
      for (propset_count = 0; propset_count < cPropertyIDSets; propset_count++)
	{
          const DBPROPIDSET *dbpropidset = &rgPropertyIDSets[propset_count];
	  rgPropertyInfoSets[propset_count].guidPropertySet = dbpropidset->guidPropertySet;
	  rgPropertyInfoSets[propset_count].cPropertyInfos = 0;
	  rgPropertyInfoSets[propset_count].rgPropertyInfos = NULL;
        }
    }

  HRESULT hr = S_OK;

  bool s_ok = false;
  bool e_errors_occurred = false;

  ULONG cOffset = 0;
  ULONG cDescBuffer = 0;
  WCHAR *pDescBuffer = NULL;

  for (propset_count = 0; propset_count < cPropertyInfoSets; propset_count++)
    {
      DBPROPINFOSET *dbpropinfoset = &rgPropertyInfoSets[propset_count];
      PropertySetInfo *propset_info = GetPropertySetInfo(dbpropinfoset->guidPropertySet);

      int cPropertyIDs = 0;
      if (cPropertyIDSets != 0)
        cPropertyIDs = rgPropertyIDSets[propset_count].cPropertyIDs;

      ULONG cPropertyInfos = cPropertyIDs;
      if (cPropertyInfos == 0)
	{
	  if (propset_info == NULL)
	    {
	      e_errors_occurred = true;
	      continue;
	    }
	  cPropertyInfos = propset_info->GetPropertyCount();
	  if (cPropertyInfos == 0)
	    continue;
	}

      DBPROPINFO *rgPropertyInfos = (DBPROPINFO *) CoTaskMemAlloc(cPropertyInfos * sizeof(DBPROPINFO));
      if (rgPropertyInfos == NULL)
	{
	  hr = E_OUTOFMEMORY;
	  break;
	}

      dbpropinfoset->cPropertyInfos = cPropertyInfos;
      dbpropinfoset->rgPropertyInfos = rgPropertyInfos;

      if (cPropertyIDs == 0)
	{
	  for (prop_count = 0; prop_count < cPropertyInfos; prop_count++)
	    {
	      const PropertyInfo *property_info = propset_info->GetPropertyInfoByIndex(prop_count);
	      rgPropertyInfos[prop_count].dwPropertyID = property_info->id;
	      VariantInit(&rgPropertyInfos[prop_count].vValues);
	    }
	}
      else
	{
	  const DBPROPIDSET *dbpropidset = &rgPropertyIDSets[propset_count];
	  for (prop_count = 0; prop_count < cPropertyInfos; prop_count++)
	    {
	      rgPropertyInfos[prop_count].dwPropertyID = dbpropidset->rgPropertyIDs[prop_count];
	      VariantInit(&rgPropertyInfos[prop_count].vValues);
	    }
	}

      for (prop_count = 0; prop_count < cPropertyInfos; prop_count++)
	{
	  DBPROPINFO *dbpropinfo = &dbpropinfoset->rgPropertyInfos[prop_count];

	  const PropertyInfo *property_info = NULL;
	  if (propset_info != NULL)
	    property_info = propset_info->GetPropertyInfoById(dbpropinfo->dwPropertyID);

	  if (property_info == NULL)
	    {
	      dbpropinfo->dwFlags = DBPROPFLAGS_NOTSUPPORTED;
	      dbpropinfo->vtType = VT_EMPTY;
	      dbpropinfo->pwszDescription = NULL;
	      e_errors_occurred = true;
	    }
	  else
	    {
	      dbpropinfo->dwFlags = (propset_info->GetPropertyGroup() | PROPFLAGS(property_info->flags));
	      dbpropinfo->vtType = property_info->type;
	      if (ppDescBuffer == NULL)
		dbpropinfo->pwszDescription = NULL;
	      else
		{
		  ULONG cLength = wcslen(property_info->description) + 1;
		  if (cOffset + cLength > cDescBuffer)
		    {
		      cDescBuffer = cDescBuffer ? cDescBuffer * 2 : 4064;
		      WCHAR *pNewBuffer = (WCHAR *) CoTaskMemRealloc(pDescBuffer, cDescBuffer * sizeof(WCHAR));
		      if (pNewBuffer == NULL)
			{
			  hr = E_OUTOFMEMORY;
			  break;
			}
		      pDescBuffer = pNewBuffer;
		    }
		  dbpropinfo->pwszDescription = pDescBuffer + cOffset;
		  wcscpy(dbpropinfo->pwszDescription, property_info->description);
		  cOffset += cLength;
		}
	      s_ok = true;
	    }
	}

      if (FAILED(hr))
	break;
    }

  if (FAILED(hr))
    {
      for (propset_count = 0; propset_count < cPropertyInfoSets; propset_count++)
	{
	  DBPROPINFOSET *dbpropinfoset = &rgPropertyInfoSets[propset_count];
	  if (dbpropinfoset->rgPropertyInfos != NULL)
	    {
	      for (prop_count = 0; prop_count < dbpropinfoset->cPropertyInfos; prop_count++)
		VariantClear(&dbpropinfoset->rgPropertyInfos[prop_count].vValues);
	      CoTaskMemFree(dbpropinfoset->rgPropertyInfos);
	    }
	}
      CoTaskMemFree(rgPropertyInfoSets);
      if (pDescBuffer)
	CoTaskMemFree(pDescBuffer);
      return hr;
    }

  *pcPropertyInfoSets = cPropertyInfoSets;
  *prgPropertyInfoSets = rgPropertyInfoSets;
  if (ppDescBuffer != NULL)
    *ppDescBuffer = pDescBuffer;

  if (e_errors_occurred)
    {
      if (s_ok)
	return DB_S_ERRORSOCCURRED;

      // DB_E_ERRORSOCCURRED is an error (as opposed to DB_S_ERRORSOCCURRED)
      // and on any error ppDescBuffer should be null.
      if (pDescBuffer != NULL)
	{
	  CoTaskMemFree(pDescBuffer);
	  *ppDescBuffer = NULL;
	}
      return DB_E_ERRORSOCCURRED;
    }
  return S_OK;
}

/**********************************************************************/
/* PropertySuperset                                                   */

PropertySuperset::PropertySuperset()
{
}

PropertySuperset::~PropertySuperset()
{
}

HRESULT
PropertySuperset::GetProperties(
  ULONG cPropertyIDSets,
  const DBPROPIDSET rgPropertyIDSets[],
  ULONG *pcPropertySets,
  DBPROPSET **prgPropertySets
)
{
  if (pcPropertySets != NULL)
    *pcPropertySets = 0;
  if (prgPropertySets != NULL)
    *prgPropertySets = NULL;

  if (pcPropertySets == NULL || prgPropertySets == NULL)
    return ErrorInfo::Set(E_INVALIDARG);
  if (cPropertyIDSets != 0 && rgPropertyIDSets == NULL)
    return ErrorInfo::Set(E_INVALIDARG);

  bool properties_in_error = false;

  // Check to see if rgPropertySets is valid.
  for (ULONG iPropertyIDSet = 0; iPropertyIDSet < cPropertyIDSets; iPropertyIDSet++)
    {
      const DBPROPIDSET* dbpropidset = &rgPropertyIDSets[iPropertyIDSet];
      if (dbpropidset->guidPropertySet == DBPROPSET_PROPERTIESINERROR)
	{
	  LOG (("Getting INERROR properties."));
	  if (cPropertyIDSets > 1)
	    return ErrorInfo::Set(E_INVALIDARG);
	  if (dbpropidset->cPropertyIDs != 0 || dbpropidset->rgPropertyIDs != NULL)
	    return ErrorInfo::Set(E_INVALIDARG);
	  properties_in_error = true;
	}
      else if (dbpropidset->cPropertyIDs != 0 && dbpropidset->rgPropertyIDs == NULL)
	return ErrorInfo::Set(E_INVALIDARG);
    }
  if (properties_in_error)
    cPropertyIDSets = 0;

  ULONG cPropertySets = cPropertyIDSets;
  if (cPropertySets == 0)
    {
      if (properties_in_error)
	cPropertySets = pss_in_error_sets.size();
      else
	cPropertySets = GetPropertySetCount();
      if (cPropertySets == 0)
	return S_OK;
    }

  DBPROPSET* rgPropertySets = (DBPROPSET*) CoTaskMemAlloc(cPropertySets * sizeof(DBPROPSET));
  if (rgPropertySets == NULL)
    return ErrorInfo::Set(E_OUTOFMEMORY);

  ULONG iPropertySet, iProperty;
  for (iPropertySet = 0; iPropertySet < cPropertySets; iPropertySet++)
    {
      if (cPropertyIDSets == 0)
	{
	  PropertySet* propset = (properties_in_error
				  ? pss_in_error_sets[iPropertySet]
				  : GetPropertySet(iPropertySet));
	  assert(propset != NULL);
	  rgPropertySets[iPropertySet].guidPropertySet = propset->GetGUID();
	}
      else
	{
	  const DBPROPIDSET* dbpropidset = &rgPropertyIDSets[iPropertySet];
	  rgPropertySets[iPropertySet].guidPropertySet = dbpropidset->guidPropertySet;
	}
      rgPropertySets[iPropertySet].cProperties = 0;
      rgPropertySets[iPropertySet].rgProperties = NULL;
    }

  HRESULT hr = S_OK;
  bool s_ok = false;
  bool e_errors_occurred = false;

  for (iPropertySet = 0; iPropertySet < cPropertySets; iPropertySet++)
    {
      DBPROPSET* dbpropset = &rgPropertySets[iPropertySet];
      PropertySet* property_set = GetPropertySet(dbpropset->guidPropertySet);

      LOG(("Property Set: %s -- %ssupported\n",
	   StringFromGuid (dbpropset->guidPropertySet),
	   property_set == NULL ? "not " : ""));

      ULONG cPropertyIDs = 0;
      if (cPropertyIDSets != 0)
        cPropertyIDs = rgPropertyIDSets[iPropertySet].cPropertyIDs;

      ULONG cProperties = cPropertyIDs;
      if (cProperties == 0)
	{
	  if (properties_in_error)
	    {
	      cProperties = property_set->GetInErrorProperties().size();
	      assert(cProperties > 0);
	    }
	  else
	    {
	      if (property_set == NULL)
		{
		  e_errors_occurred = true;
		  continue;
		}
	      const PropertySetInfo* propset_info = property_set->GetPropertySetInfo();
	      for (iProperty = 0; iProperty < propset_info->GetPropertyCount(); iProperty++)
		{
		  const PropertyInfo* property_info = propset_info->GetPropertyInfoByIndex(iProperty);
		  Property* property = property_set->GetProperty(property_info->id);
		  assert(property != NULL);
		  if (property->HasValue(DB_NULLID))
		    cProperties++;
		}
	      if (cProperties == 0)
		continue;
	    }
	}

      DBPROP *rgProperties = (DBPROP *) CoTaskMemAlloc(cProperties * sizeof(DBPROP));
      if (rgProperties == NULL)
	{
	  hr = E_OUTOFMEMORY;
	  break;
	}

      dbpropset->cProperties = cProperties;
      dbpropset->rgProperties = rgProperties;

      if (cPropertyIDs == 0)
	{
	  if (properties_in_error)
	    {
	      for (iProperty = 0; iProperty < cProperties; iProperty++)
		{
		  rgProperties[iProperty].dwPropertyID = property_set->GetInErrorProperties()[iProperty];
		  VariantInit(&rgProperties[iProperty].vValue);
		}
	    }
	  else
	    {
	      ULONG count = 0;
	      const PropertySetInfo* propset_info = property_set->GetPropertySetInfo();
	      for (iProperty = 0; iProperty < propset_info->GetPropertyCount(); iProperty++)
		{
		  const PropertyInfo* property_info = propset_info->GetPropertyInfoByIndex(iProperty);
		  Property* property = property_set->GetProperty(property_info->id);
		  assert(property != NULL);
		  if (property->HasValue(DB_NULLID))
		    {
		      assert(count < cProperties);
		      rgProperties[count].dwPropertyID = property_info->id;
		      VariantInit(&rgProperties[count].vValue);
		      count++;
		    }
		}
	      assert(count == cProperties);
	    }
	}
      else
	{
	  const DBPROPIDSET* dbpropidset = &rgPropertyIDSets[iPropertySet];
	  for (iProperty = 0; iProperty < cProperties; iProperty++)
	    {
	      rgProperties[iProperty].dwPropertyID = dbpropidset->rgPropertyIDs[iProperty];
	      VariantInit(&rgProperties[iProperty].vValue);
	    }
	}

      for (iProperty = 0; iProperty < cProperties; iProperty++)
	{
	  DBPROP* dbprop = &rgProperties[iProperty];

          Property* property = NULL;
	  if (property_set != NULL)
	    property = property_set->GetProperty(dbprop->dwPropertyID);

	  hr = PropertySet::GetProperty(property_set, property, dbprop);
	  if (FAILED(hr))
	    break;
	  if (hr == S_OK)
	    s_ok = true;
	  else
	    e_errors_occurred = true;

#if DEBUG
	  LOG(("Get property %s, %s: %s\n",
	       StringFromGuid(dbpropset->guidPropertySet),
	       StringFromPropID(dbpropset->guidPropertySet, dbprop->dwPropertyID),
	       hr != S_OK ? "[failed]" : StringFromVariant(dbprop->vValue)));
#endif
	}

      if (FAILED(hr))
	break;
    }

  if (FAILED(hr))
    {
      for (iPropertySet = 0; iPropertySet < cPropertySets; iPropertySet++)
	{
	  DBPROPSET* dbpropset = &rgPropertySets[iPropertySet];
	  if (dbpropset->rgProperties != NULL)
	    {
	      for (iProperty = 0; iProperty < dbpropset->cProperties; iProperty++)
		VariantClear(&dbpropset->rgProperties[iProperty].vValue);
	      CoTaskMemFree(dbpropset->rgProperties);
	    }
	}
      CoTaskMemFree(rgPropertySets);
      return hr;
    }

  *pcPropertySets = cPropertySets;
  *prgPropertySets = rgPropertySets;

  if (e_errors_occurred)
    {
      if (s_ok)
	return DB_S_ERRORSOCCURRED;
      else
	return DB_E_ERRORSOCCURRED;
    }
  return S_OK;
}

HRESULT
PropertySuperset::SetProperties(
  ULONG cPropertySets,
  DBPROPSET rgPropertySets[],
  bool bIsCreating
)
{
  LOGCALL(("PropertySuperset::SetProperties(cPropertySets = %d)\n", cPropertySets));

  if (cPropertySets == 0)
    return S_OK;
  if (rgPropertySets == NULL)
    return ErrorInfo::Set(E_INVALIDARG);

  ULONG propset_count, prop_count;

  // Check to see if rgPropertySets is valid.
  for (propset_count = 0; propset_count < cPropertySets; propset_count++)
    {
      DBPROPSET *dbpropset = &rgPropertySets[propset_count];
      if (dbpropset->cProperties == 0)
	continue;
      if (dbpropset->rgProperties == NULL)
	return ErrorInfo::Set(E_INVALIDARG);
    }

  bool s_ok = false;
  bool e_errors_occurred = false;
  bool s_errors_occurred = false;

  for (propset_count = 0; propset_count < cPropertySets; propset_count++)
    {
      DBPROPSET* dbpropset = &rgPropertySets[propset_count];
      if (dbpropset->cProperties == 0)
	continue;
      PropertySet* property_set = GetPropertySet(dbpropset->guidPropertySet);
      // Set properties in 2 passes. First pass sets only required properties.
      // Second pass sets only optional properties. This prvents the problem when
      // an optional property and a required property conflict with each other
      // and the optional one is met before the required. For a single pass
      // algorithm when a second property is met it is necessary to backtrack
      // to the earlier optional property, set its value and its status field
      // accordingly, and finally increment the s_errors_occured counter.
      // With the two pass algorithm we still could face this problem but only
      // if such properties are used in separate SetProperties() calls. This
      // situation is much more simple because we don't have to care about
      // the status field and the error counter.
      for (prop_count = 0; prop_count < dbpropset->cProperties; prop_count++)
	{
	  DBPROP* dbprop = &dbpropset->rgProperties[prop_count];
	  if (dbprop->dwOptions == DBPROPOPTIONS_REQUIRED)
	    {
	      Property* property = NULL;

	      /* GK: we skip the location property */
	      if (dbprop->dwPropertyID == DBPROP_INIT_LOCATION)
		  continue;

	      if (property_set != NULL)
		  property = property_set->GetProperty(dbprop->dwPropertyID);

	      HRESULT hr = PropertySet::SetProperty(property_set, property, dbprop);
	      if (FAILED(hr))
		return hr;

	      LOG(("Set property %s, %s: %s: %s\n",
		   StringFromGuid(dbpropset->guidPropertySet),
		   StringFromPropID(dbpropset->guidPropertySet, dbprop->dwPropertyID),
		   StringFromVariant(dbprop->vValue),
		   hr == S_OK ? "ok" : "failed (required)"));

	      if (hr == S_OK)
		s_ok = true;
	      else
		e_errors_occurred = true;
	    }
	  else if (dbprop->dwOptions == DBPROPOPTIONS_OPTIONAL)
	    ;
	  else
	    {
	      dbprop->dwStatus = DBPROPSTATUS_BADOPTION;
	      e_errors_occurred = true;
	      return S_FALSE;
	    }
	}
      for (prop_count = 0; prop_count < dbpropset->cProperties; prop_count++)
	{
	  DBPROP* dbprop = &dbpropset->rgProperties[prop_count];
	  if (dbprop->dwOptions == DBPROPOPTIONS_REQUIRED)
	    ;
	  else if (dbprop->dwOptions == DBPROPOPTIONS_OPTIONAL)
	    {
	      Property* property = NULL;
	      if (property_set != NULL)
		  property = property_set->GetProperty(dbprop->dwPropertyID);

	      HRESULT hr = PropertySet::SetProperty(property_set, property, dbprop);
	      if (FAILED(hr))
		return hr;

#if DEBUG
	      LOG(("Set property %s, %s: %s: %s\n",
		   StringFromGuid(dbpropset->guidPropertySet),
		   StringFromPropID(dbpropset->guidPropertySet, dbprop->dwPropertyID),
		   StringFromVariant(dbprop->vValue),
		   hr == S_OK ? "ok" : "failed (optional)"));
#endif

	      if (hr == S_OK)
		s_ok = true;
	      else
		s_errors_occurred = true;
	    }
	  else
	    {
	      dbprop->dwStatus = DBPROPSTATUS_BADOPTION;
	      e_errors_occurred = true;
	      return S_FALSE;
	    }
	}
    }

  if (bIsCreating)
    {
      if (e_errors_occurred)
	return DB_E_ERRORSOCCURRED;
      if (s_errors_occurred)
	return DB_S_ERRORSOCCURRED;
    }
  else if (e_errors_occurred || s_errors_occurred)
    {
      if (s_ok)
	return DB_S_ERRORSOCCURRED;
      else
	return DB_E_ERRORSOCCURRED;
    }
  return S_OK;
}

/**********************************************************************/
/* PropertySet                                                        */

PropertySet::PropertySet(
  const PropertySetInfo &info,
  DBPROPFLAGS flags
)
  : ps_info(info),
    ps_flags(flags)
{
}

PropertySet::~PropertySet()
{
}

bool
PropertySet::Init()
{
  for (int i = 0; i < GetPropertyCount(); i++)
    {
      const PropertyInfo* property_info = GetPropertyInfo(i);
      assert(property_info != NULL);
      Property* property = GetProperty(property_info->id);
      assert(property != NULL);
      property->Init(property_info);
    }
  return true;
}

HRESULT
PropertySet::GetProperty(PropertySet* propset, Property* property, DBPROP* dbprop)
{
  dbprop->colid = DB_NULLID;

  if (propset == NULL || property == NULL)
    {
      dbprop->dwStatus = DBPROPSTATUS_NOTSUPPORTED;
      return S_FALSE;
    }

  if (property->GetPropertyFlags(DB_NULLID) & DBPROPFLAGS_REQUIRED)
    dbprop->dwOptions = DBPROPOPTIONS_REQUIRED;
  else
    dbprop->dwOptions = DBPROPOPTIONS_OPTIONAL;

  dbprop->dwStatus = DBPROPSTATUS_OK;
  if (property->HasValue(DB_NULLID))
    return property->GetValue(propset, DB_NULLID, dbprop->vValue);

  V_VT(&dbprop->vValue) = VT_EMPTY;
  return S_OK;
}

HRESULT
PropertySet::SetProperty(PropertySet* propset, Property* property, DBPROP* dbprop)
{
  if (dbprop->dwOptions != DBPROPOPTIONS_OPTIONAL
      && dbprop->dwOptions != DBPROPOPTIONS_REQUIRED)
    {
      dbprop->dwStatus = DBPROPSTATUS_BADOPTION;
      return S_FALSE;
    }
  if (propset == NULL || property == NULL)
    {
      dbprop->dwStatus = DBPROPSTATUS_NOTSUPPORTED;
      return S_FALSE;
    }
  if (!property->IsValidValue(&dbprop->vValue))
    {
      dbprop->dwStatus = DBPROPSTATUS_BADVALUE;
      return S_FALSE;
    }
  if (!property->ResolveConflicts(propset, DB_NULLID, dbprop->vValue, (dbprop->dwOptions == DBPROPOPTIONS_REQUIRED)))
    {
      dbprop->dwStatus = DBPROPSTATUS_CONFLICTING;
      return S_FALSE;
    }

  if ((propset->GetPropertyFlags() & property->GetPropertyFlags(DB_NULLID) & DBPROPFLAGS_WRITE) == 0)
    {
      if (property->HasValue(DB_NULLID) && property->IsEqual(propset, DB_NULLID, dbprop->vValue))
	{
	  dbprop->dwStatus = DBPROPSTATUS_OK;
	  return S_OK;
	}
      if (V_VT(&dbprop->vValue) == VT_EMPTY)
	{
	  dbprop->dwStatus = DBPROPSTATUS_OK;
	  return S_OK;
	}

      if (dbprop->dwOptions == DBPROPOPTIONS_REQUIRED)
        dbprop->dwStatus = DBPROPSTATUS_NOTSETTABLE;
      else
	dbprop->dwStatus = DBPROPSTATUS_NOTSET;
      return S_FALSE;
    }

  dbprop->dwStatus = DBPROPSTATUS_OK;
  property->SetRequiredFlag(DB_NULLID, dbprop->dwOptions == DBPROPOPTIONS_REQUIRED);
  return property->SetValue(propset, DB_NULLID, dbprop->vValue);
}

HRESULT
PropertySet::Copy(const PropertySet* property_set)
{
  for (int i = 0; i < GetPropertyCount(); i++)
    {
      const PropertyInfo* info = GetPropertyInfo(i);
      const Property* src_prop = const_cast<PropertySet*>(property_set)->GetProperty(info->id);
      Property* dst_prop = GetProperty(info->id);
      HRESULT hr = dst_prop->Copy(this, property_set, src_prop);
      if (FAILED(hr))
	return hr;
    }
  return S_OK;
}

/*
bool
PropertySet::HasSetProperties()
{
  for (int i = 0; i < GetPropertyCount(); i++)
    {
      const PropertyInfo* property_info = GetPropertyInfo(i);
      PropertyBase* property = GetProperty(property_info->id);
      if (property->IsSet(DB_NULLID))
	return true;
    }
  return false;
}
*/

HRESULT
PropertySet::ConvertRowsetIIDToPropertyID(REFIID riid, DBPROPID& propid)
{
  if (riid == IID_IAccessor)
    propid = DBPROP_IAccessor;
  else if (riid == IID_IColumnsInfo)
    propid = DBPROP_IColumnsInfo;
  else if (riid == IID_IColumnsInfo2)
    propid = DBPROP_IColumnsInfo2;
  else if (riid == IID_IColumnsRowset)
    propid = DBPROP_IColumnsRowset;
  else if (riid == IID_IConnectionPointContainer)
    propid = DBPROP_IConnectionPointContainer;
  else if (riid == IID_IConvertType)
    propid = DBPROP_IConvertType;
  else if (riid == IID_IDBAsynchStatus)
    propid = DBPROP_IDBAsynchStatus;
#if 0
  else if (riid == IID_IRowsetBookmark)
    propid = DBPROP_IRowsetBookmark;
#endif
  else if (riid == IID_IRowsetChange)
    propid = DBPROP_IRowsetChange;
  else if (riid == IID_IRowsetFind)
    propid = DBPROP_IRowsetFind;
  else if (riid == IID_IRowsetIdentity)
    propid = DBPROP_IRowsetIdentity;
  else if (riid == IID_IRowsetInfo)
    propid = DBPROP_IRowsetInfo;
  else if (riid == IID_IRowsetLocate)
    propid = DBPROP_IRowsetLocate;
  else if (riid == IID_IRowsetRefresh)
    propid = DBPROP_IRowsetRefresh;
  else if (riid == IID_IRowsetScroll)
    propid = DBPROP_IRowsetScroll;
  else if (riid == IID_IRowsetUpdate)
    propid = DBPROP_IRowsetUpdate;
  else if (riid == IID_ISupportErrorInfo)
    propid = DBPROP_ISupportErrorInfo;
  else
    return S_FALSE;
  return S_OK;
}

HRESULT
PropertySet::SetRowsetProperty(DBPROPID propid)
{
  DBPROP dbprop;
  dbprop.dwPropertyID = propid;
  dbprop.dwOptions = DBPROPOPTIONS_REQUIRED;
  dbprop.colid = DB_NULLID;
  VariantInit (&dbprop.vValue);
  V_VT(&dbprop.vValue) = VT_BOOL;
  V_BOOL(&dbprop.vValue) = VARIANT_TRUE;

  HRESULT hr = SetProperty(this, GetProperty(propid), &dbprop);
  if (FAILED(hr))
    return hr;

  LOG(("Set property %s, %s: %s\n",
       StringFromGuid(GetGUID()), StringFromPropID(GetGUID(), propid), hr == S_OK ? "ok" : "failed"));

  return hr;
}

/**********************************************************************/
/* Property                                                           */

Property::Property()
  : p_info(NULL), p_flags(0)
{
}

Property::~Property()
{
}

void
Property::Init(const PropertyInfo* info)
{
  assert(info != NULL);
  p_info = info;
}

HRESULT
Property::Copy(PropertySet* dstpropset, const PropertySet* srcpropset, const Property* property)
{
  HRESULT hr = S_OK;
  if (property->HasValue(DB_NULLID))
    {
      VARIANT value;
      VariantInit(&value);
      HRESULT hr = property->GetValue(srcpropset, DB_NULLID, value);
      if (FAILED(hr))
	return hr;
      hr = SetValue(dstpropset, DB_NULLID, value);
      VariantClear(&value);
    }
  return hr;
}

/**********************************************************************/
/* PropertyBoolBase                                                   */

bool
PropertyBoolBase::IsValidValue(const VARIANT* value) const
{
  return (V_VT(value) == VT_EMPTY
	  || (V_VT(value) == VT_BOOL
	      && (V_BOOL(value) == VARIANT_TRUE || V_BOOL(value) == VARIANT_FALSE)));
}

bool
PropertyBoolBase::IsEqual(const PropertySet* propset, const DBID& colid, const VARIANT& value) const
{
  assert(HasValue(colid));
  if (V_VT(&value) != VT_BOOL)
    return false;
  VARIANT_BOOL property_value;
  if (FAILED(GetValue(propset, colid, property_value)))
    return false;
  return V_BOOL(&value) == property_value;
}

HRESULT
PropertyBoolBase::GetValue(const PropertySet* propset, const DBID& colid, VARIANT& value) const
{
  assert(HasValue(colid));
  VARIANT_BOOL property_value;
  HRESULT hr = GetValue(propset, colid, property_value);
  if (FAILED(hr))
    return hr;
  V_VT(&value) = VT_BOOL;
  V_BOOL(&value) = property_value;
  return S_OK;
}

HRESULT
PropertyBoolBase::SetValue(PropertySet* propset, const DBID& colid, const VARIANT& value)
{
  if (V_VT(&value) == VT_EMPTY)
    {
      SetValueFlag(colid, false);
      return S_OK;
    }
  else
    {
      assert(V_VT(&value) == VT_BOOL);
      return SetValue(propset, colid, V_BOOL(&value));
    }
}

/**********************************************************************/
/* PropertyI2Base                                                     */

bool
PropertyI2Base::IsValidValue(const VARIANT* value) const
{
  return V_VT(value) == VT_EMPTY || V_VT(value) == VT_I2;
}

bool
PropertyI2Base::IsEqual(const PropertySet* propset, const DBID& colid, const VARIANT& value) const
{
  assert(HasValue(colid));
  if (V_VT(&value) != VT_I2)
    return false;
  SHORT property_value;
  if (FAILED(GetValue(propset, colid, property_value)))
    return false;
  return V_I2(&value) == property_value;
}

HRESULT
PropertyI2Base::GetValue(const PropertySet* propset, const DBID& colid, VARIANT& value) const
{
  assert(HasValue(colid));
  SHORT property_value;
  HRESULT hr = GetValue(propset, colid, property_value);
  if (FAILED(hr))
    return hr;
  V_VT(&value) = VT_I2;
  V_I2(&value) = property_value;
  return S_OK;
}

HRESULT
PropertyI2Base::SetValue(PropertySet* propset, const DBID& colid, const VARIANT& value)
{
  if (V_VT(&value) == VT_EMPTY)
    {
      SetValueFlag(colid, false);
      return S_OK;
    }
  else
    {
      assert(V_VT(&value) == VT_I2);
      return SetValue(propset, colid, V_I2(&value));
    }
}

/**********************************************************************/
/* PropertyI4Base                                                     */

bool
PropertyI4Base::IsValidValue(const VARIANT* value) const
{
  return V_VT(value) == VT_EMPTY || V_VT(value) == VT_I4;
}

bool
PropertyI4Base::IsEqual(const PropertySet* propset, const DBID& colid, const VARIANT& value) const
{
  assert(HasValue(colid));
  if (V_VT(&value) != VT_I4)
    return false;
  LONG property_value;
  if (FAILED(GetValue(propset, colid, property_value)))
    return false;
  return V_I4(&value) == property_value;
}

HRESULT
PropertyI4Base::GetValue(const PropertySet* propset, const DBID& colid, VARIANT& value) const
{
  assert(HasValue(colid));
  LONG property_value;
  HRESULT hr = GetValue(propset, colid, property_value);
  if (FAILED(hr))
    return hr;
  V_VT(&value) = VT_I4;
  V_I4(&value) = property_value;
  return S_OK;
}

HRESULT
PropertyI4Base::SetValue(PropertySet* propset, const DBID& colid, const VARIANT& value)
{
  if (V_VT(&value) == VT_EMPTY)
    {
      SetValueFlag(colid, false);
      return S_OK;
    }
  else
    {
      assert(V_VT(&value) == VT_I4);
      return SetValue(propset, colid, V_I4(&value));
    }
}

/**********************************************************************/
/* PropertyBSTRBase                                                   */

bool
PropertyBSTRBase::IsValidValue(const VARIANT* value) const
{
  return V_VT(value) == VT_EMPTY || V_VT(value) == VT_BSTR;
}

bool
PropertyBSTRBase::IsEqual(const PropertySet* propset, const DBID& colid, const VARIANT& value) const
{
  assert(HasValue(colid));
  if (V_VT(&value) != VT_BSTR)
    return false;
  LPOLESTR property_value;
  if (FAILED(GetValue(propset, colid, property_value)))
    return false;
  return ((V_BSTR(&value) == NULL && property_value == NULL)
	  || (V_BSTR(&value) != NULL && property_value != NULL
	      && wcscmp(V_BSTR(&value), property_value) == 0));
}

HRESULT
PropertyBSTRBase::GetValue(const PropertySet* propset, const DBID& colid, VARIANT& value) const
{
  assert(HasValue(colid));
  BSTR property_value;
  HRESULT hr = GetValue(propset, colid, property_value);
  if (FAILED(hr))
    return hr;
  V_VT(&value) = VT_BSTR;
  V_BSTR(&value) = property_value;
  return S_OK;
}

HRESULT
PropertyBSTRBase::SetValue(PropertySet* propset, const DBID& colid, const VARIANT& value)
{
  if (V_VT(&value) == VT_EMPTY)
    {
      HRESULT hr = SetValue(propset, colid, NULL);
      if (FAILED(hr))
	return hr;
      SetValueFlag(colid, false);
      return S_OK;
    }
  else
    {
      assert(V_VT(&value) == VT_BSTR);
      return SetValue(propset, colid, V_BSTR(&value));
    }
}

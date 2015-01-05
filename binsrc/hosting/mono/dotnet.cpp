/*
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
 */

#define C_BEGIN() extern "C" {
#define C_END()   }

#define uint16  unsigned short
#define uint8   unsigned char

#include <stdio.h>
#include <string.h>
#include <ctype.h>
#include <stdlib.h>
#include <string.h>
#include <tchar.h>
#include <AtlBase.h>
#include <mscoree.h>
#include <direct.h>
C_BEGIN ()
#include <ksrvext.h>
#include "clr_ll_api.h"
caddr_t box_wide_string (wchar_t *wstr);
/*for MALLOC_DEBUG only
dbg_dk_set_push (char *file, int line, s_node_t ** set, void *item);
#define dk_set_push(S,I)        dbg_dk_set_push (__FILE__, __LINE__, (S), (I))*/
char pid_dir [MAX_PATH + 1];
char server_executable_dir[MAX_PATH + 1];
extern void (*db_exit_hook) (void);
C_END()

#undef PASCAL
#undef DECIMAL
#undef DATE
#undef inline
#undef com_issue_error
#undef com_error
#undef hr

#ifdef WIN32
#ifndef HRESULT
#define HRESULT long
#define S_OK                                   ((HRESULT)0x00000000L)
#define S_FALSE                                ((HRESULT)0x00000001L)
#endif

#import "mscorlib.tlb" raw_interfaces_only
#import "system.tlb" raw_interfaces_only

CComPtr<IDispatch>		virtclr_inst;
CComPtr<ICorRuntimeHost>	spRuntimeHost;

DISPID			dispid_call_method_asm;
DISPID			dispid_call_ins;
DISPID			dispid_get_isinstance_of;
DISPID			dispid_free_ins;
DISPID			dispid_get_prop;
DISPID			dispid_get_copy;
DISPID			dispid_obj_serialize;
DISPID			dispid_obj_deserialize;
DISPID			dispid_create_ins_asm;
DISPID			dispid_set_prop;
DISPID			dispid_get_stat_prop;
DISPID			dispid_compile_source;
DISPID			dispid_add_comp_ref;
//DISPID			dispid_remove_instance_from_hash;
//DISPID			dispid_add_assem_to_sec_hash;

typedef struct extension_obj_s
{
  ptrlong exo_type;
  long exo_object;
}
extension_obj_t;

#define DVEXT_JAVA_OBJECT 1
#define CLR_DISK_CACHE "tmp"
#define FS_DIR_MODE     0

dk_set_t list_obj_id = NULL;

#define COM_VARS \
    VARIANT varVals; \
    VariantInit(&varVals)

#define COM_ARRAY \
  VARIANT varVals; \
  VariantInit(&varVals); \
  VariantInit(&varVals); \
  varVals.vt = VT_ARRAY | VT_VARIANT; \
  SAFEARRAYBOUND range = {n_args}; \
  SAFEARRAY* pArray = SafeArrayCreate(VT_VARIANT, 1, &range); \
  SafeArrayAccessData(pArray, (void**)&varVals); \
  SAFEARRAY* oArray = SafeArrayCreate(VT_INT, 1, &range); \
  SafeArrayAccessData(oArray, (void**)&varVals); \
  SAFEARRAY *ret = NULL; \
  dk_set_t ret_vec = NULL

#define COM_END \
  SafeArrayUnaccessData(oArray); \
  SafeArrayUnaccessData(pArray); \
  SafeArrayDestroy(oArray); \
  SafeArrayDestroy(pArray); \
  SafeArrayDestroy(ret);

#define DP_CREATE(n) \
  HRESULT hr; \
  DISPPARAMS dispparams; \
  dispparams.rgvarg = new VARIANTARG[n]

#define DP_ARRAY(n, name) \
  dispparams.rgvarg[n].vt = VT_ARRAY; \
  dispparams.rgvarg[n].parray = name

#define DP_BSTR(n, name) \
  dispparams.rgvarg[n].vt = VT_BSTR; \
  dispparams.rgvarg[n].bstrVal = ::SysAllocString((CComBSTR)name)

#define DP_INT(n, name) \
  dispparams.rgvarg[n].vt = VT_I4; \
  dispparams.rgvarg[n].intVal = name

#define DP_INTPTR(n, name) \
  dispparams.rgvarg[n].vt = VT_INT; \
  dispparams.rgvarg[n].intVal = name

#define DP_LEN(n) \
  dispparams.cArgs = n; \
  dispparams.cNamedArgs = 0; \
  VARIANT vRet; \
  VariantInit(&vRet); \
  EXCEPINFO Excepinfo; \
  unsigned int uArgErr

#define DP_ERR(err_no, proc_name)		\
   delete [] dispparams.rgvarg; \
   if (!SUCCEEDED (hr)) \
      if (!err_no) \
        return 0; \
      else \
        virt_com_error (hr, err_no, proc_name, &Excepinfo)   /* FIXME FIXME FIXME FIXME FIXME FIXME FIXME */ \

#define CHECK_ERR(n) if (FAILED(hr)) return startup_com_error (n)

#define DP_ARRAYS(n) \
  dispparams.rgvarg[n].vt = VT_ARRAY; \
  dispparams.rgvarg[n].parray = oArray; \
  dispparams.rgvarg[n+1].vt = VT_ARRAY; \
  dispparams.rgvarg[n+1].parray = pArray

#define CALL(name) \
  hr = virtclr_inst->Invoke (name, IID_NULL, LOCALE_SYSTEM_DEFAULT, DISPATCH_METHOD, \
			     &dispparams, &vRet, &Excepinfo,&uArgErr)

#define box_length(box) ((uint32)(0x00ffffff & ((uint32 *)(box))[-1]))

using namespace mscorlib;

CComPtr<_AppDomain>		spDefAppDomain;

static void add_id (int id)
{
  DO_SET (int, val, &list_obj_id)
    {
      if (val == NULL)
	{
	  iter->data = box_num (id);
	  return;
	}
      if (unbox ((box_t)val) == id)
	return;
    }
  END_DO_SET();

  dk_set_push (&list_obj_id, box_num (id));
}

static int check_id (int id)
{
  if (!id)
    return 1;

    DO_SET (int, val, &list_obj_id)
    {
      if (unbox ((box_t)val) == id)
	return 1;
    }
    END_DO_SET();

  return 0;
}

static int del_id (int id)
{
  DO_SET (int, val, &list_obj_id)
    {
      if (unbox ((box_t)val) == id)
	{
	  dk_free_box ((box_t) iter->data);
	  iter->data = NULL;
	  return 1;
	}
    }
  END_DO_SET();
  return 0;
}

C_BEGIN ()

caddr_t cpp_udt_clr_instance_allocate (int val, void *udt);
void * udt_find_class_for_clr_instance (int clr_ret, void *target_udt);
void * scan_session_boxing (dk_session_t *session);
int session_flush (dk_session_t * session);
void print_object2 (void *object, dk_session_t *session);
caddr_t bif_dotnet_get_info (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args);
extern void bif_init_func_clr (void);
extern char * clr_version_string ();
static void (*old_hook) (void) = NULL;
void acl_add_allowed_dir (char *dir);

static void virt_com_error (HRESULT hr, char * err_no, char * proc_name,  EXCEPINFO *einfo_ptr)
{
      IErrorInfo *err_info = NULL;
      if (SUCCEEDED (::GetErrorInfo (0, &err_info)) && err_info)
	{
	  _bstr_t desc;
	  err_info->GetDescription (desc.GetAddress());
	  sqlr_new_error ("42000", err_no, "Com error in %s : %s", proc_name, (LPCTSTR)desc);
	}
      else if ((hr == DISP_E_EXCEPTION) && einfo_ptr && einfo_ptr->bstrDescription)
	{
	  sqlr_new_error ("42000", err_no, "Com exception in %s : %sr", proc_name,
			  CW2A(einfo_ptr->bstrDescription));
	}
      else
	sqlr_new_error ("42000", err_no, "Com error in %s %x : Unknown error", proc_name, hr);
}


static int startup_com_error (int pos)
{
      IErrorInfo *err_info = NULL;
      if (SUCCEEDED (::GetErrorInfo (0, &err_info)) && err_info)
	{
	  _bstr_t desc;
	  err_info->GetDescription (desc.GetAddress());
	  log_info ("Com error on startup %i : %s", pos, (LPCTSTR)desc);
	}
      else
	log_info ("(%i) Unknown Com error.", pos);

      return 0;
}


static caddr_t
conv_ret (caddr_t in)
{
  if (DV_TYPE_OF (in) == DV_ARRAY_OF_POINTER)
    {
      int l = BOX_ELEMENTS (in);

      if (l > 1 || l == 0)
	return in;
      else
	{
	  caddr_t ret = ((caddr_t *)in)[0];
	  dk_free_box (in);
	  return ret;
	}
    }

  return in;
}


static caddr_t
dotnet_box_variant_to_ansi (VARIANT varVals)
{
  caddr_t ret;
  try
    {
      _bstr_t bstr = (_bstr_t) (varVals);
      ret = (caddr_t) box_dv_short_string ((char *) bstr);
      VariantClear (&varVals);
      return ret;
    }
  catch (...)
    {
      return NULL;
    }
}


static caddr_t
dotnet_box_variant_to_wide (VARIANT varVals)
{
  caddr_t ret;
  try
    {
      _variant_t * var = new _variant_t (varVals);
      _bstr_t bstr = (_bstr_t) (*var);
      wchar_t *wstr = (wchar_t *) bstr;
      ret = (caddr_t) box_wide_string (wstr);
      delete var;
      return ret;
    }
  catch (...)
    {
      return NULL;
    }
}


int sa_to_dk (SAFEARRAY *in, dk_set_t *ret, int mode, void *udt)
{
  USES_CONVERSION;
  HRESULT hr;
  LONG lstart, lend;
  LONG idx = -1;
  LONG ret_type;
  BSTR* pbstr;
  COM_VARS;
  int clr_object = 0;

  hr = SafeArrayGetLBound( in, 1, &lstart );
  if(FAILED(hr))
    sqlr_new_error ("42000", "CLR03", "Com error. Can't access SafeArray");

  hr = SafeArrayGetUBound( in, 1, &lend );
  if(FAILED(hr))
    sqlr_new_error ("42000", "CLR04", "Com error. Can't access SafeArray");

  hr = SafeArrayAccessData(in,(void HUGEP**)&pbstr);
  if(SUCCEEDED(hr))
    {
      SafeArrayGetElement (in, &lstart, &varVals);

      ret_type = varVals.lVal;

      if (!ret_type)
         {
	   char *error_text;
	   lstart = ++lstart;
	   SafeArrayGetElement (in, &lstart, &varVals);
	   error_text = dotnet_box_variant_to_ansi (varVals);
	   if (error_text)
	     {
	       caddr_t err = srv_make_new_error ("42000", "CLR05", error_text);
	       dk_free_box (error_text);
	       sqlr_resignal (err);
	     }
	   else
	     sqlr_new_error ("42000", "CLR06", "Unknown error");
	 }

      /* get type of object */

      clr_object = 0;
      if (ret_type == 5 || ret_type == 6)
	clr_object = 1;

      for(idx=lstart + 1; idx <= lend; idx++)
	{
	  SafeArrayGetElement (in, &idx, &varVals);

	  if ( varVals.vt == VT_I4)
	    {
	      if (clr_object)
		{
		  void * what_udt;

		  if (mode)
		    {
		      if ( varVals.vt == VT_BSTR)
			{
			  dk_set_push (ret, dotnet_box_variant_to_wide (varVals));
			  return 1;
			}
		      else
			{
			  int ret = varVals.lVal;
			  add_id (ret);
			  SafeArrayUnaccessData(in);
			  return ret;
			}
		    }

		  what_udt = udt_find_class_for_clr_instance (varVals.lVal, udt);
		  if (what_udt)
		    {
		      add_id (varVals.lVal);
		      dk_set_push (ret, cpp_udt_clr_instance_allocate (varVals.lVal, what_udt));
		    }
		  else
		    {
		      sqlr_new_error ("22023", "CLR07", "Can't map CLR result to PL type");
		    }
		}
            else
		dk_set_push (ret, box_num (varVals.lVal));
	    }
	  else if ( varVals.vt == VT_R4)
	    {
	      dk_set_push (ret, box_double (varVals.fltVal));
	    }
	  else if ( varVals.vt == VT_R8)
	    {
	      dk_set_push (ret, box_double (varVals.dblVal));
	    }
	  else if ( varVals.vt == VT_BOOL)
	    {
	      if (varVals.boolVal)
		dk_set_push (ret, box_num (1));
	      else
		dk_set_push (ret, box_num (0));
	    }
	  else if ( varVals.vt == VT_BSTR)
	    {
	      dk_set_push (ret, dotnet_box_variant_to_wide (varVals));
	    }
	  VariantClear (&varVals);
	}
    }

  SafeArrayUnaccessData(in);
  SafeArrayUnlock (in);

  return 0;
}
;

int
dotnet_is_instance_of (int clr_ret, caddr_t class_name)
{
  COM_VARS;
  LONG element;
  BSTR* pbstr;
  char *p1=NULL, *p2=NULL, *p3 = NULL;
  char t_class_name[200];
  int fl = 1, inx = 0;

  if (!class_name)
    return 0;

  strcpy (t_class_name, class_name);
  p1 = p3 = t_class_name;

  for (;;)
    {
      p2 = strstr (p3, "/");
      if (!p2)
	break;
      else
	p3 = p2 + 1;
      fl = fl - 1;
    }
  p1 [p3 - p1 - 1] = 0;

  DP_CREATE(4);
  DP_BSTR(0, p3);
  DP_BSTR(1, p1);
  DP_INT(2, fl);
  DP_INTPTR(3, clr_ret);
  DP_LEN(4);

  CALL(dispid_get_isinstance_of);

  DP_ERR("CLR08", "dotnet_is_instance_of");

  SAFEARRAY *ret = vRet.parray;

  hr = SafeArrayGetLBound(ret, 1, &element);
  hr = SafeArrayAccessData(ret,(void HUGEP**)&pbstr);

  if(SUCCEEDED(hr))
    {
      SafeArrayGetElement (ret, &element, &varVals);

      if (varVals.boolVal)
	return 1;
      else
	return 0;
    }

  return 0;
}


int
param_to_safearray (caddr_t *list_args, int n_args, SAFEARRAY **pArray, SAFEARRAY **oArray)
{
  int is_object = 0;
  long inx = 0;
  caddr_t * volatile line = NULL;
  caddr_t err = NULL;
  VARIANT params;

  for (inx = 0; inx < n_args; inx++)
    {
      line = (caddr_t *) list_args[inx];

      is_object = 0;
      if (DV_TYPE_OF (line[1]) == DV_DB_NULL)
	{
	  params.vt = VT_EMPTY;
	  goto put_it;
	}

      if (!strncmp (line[0], "System.String", sizeof ("System.String")) ||
          !strncmp (line[0], "String", sizeof ("String")))
	{
	  if (!DV_STRINGP (line[1]))
	    goto convert_error;
	  params.vt = VT_BSTR;
	  params.bstrVal = ::SysAllocString ((CComBSTR)line[1]);
	}
      else if (!strncmp (line[0], "Int32", sizeof ("Int32"))
	  || !strncmp (line[0], "System.Int32", sizeof ("System.Int32"))
	  || !strncmp (line[0], "int", sizeof ("int")))
	{
	  params.vt = VT_I4;
	  if (DV_TYPE_OF (line[1]) != DV_LONG_INT)
	    goto convert_error;

	  params.lVal = (long) unbox (line[1]);
	}
      else if (!strncmp (line[0], "System.Single", sizeof ("System.Single"))
	  || !strncmp (line[0], "Single", sizeof ("Single")))
	{
	  params.vt = VT_R4;

	  if (DV_TYPE_OF (line[1]) != DV_SINGLE_FLOAT)
	    goto convert_error;

	  params.fltVal = (float) unbox_float (line[1]);
	}
      else if (!strncmp (line[0], "System.Data.SqlTypes.SqlDouble", sizeof ("System.Data.SqlTypes.SqlDouble"))
            || !strncmp (line[0], "System.Double", sizeof ("System.Double"))
            || !strncmp (line[0], "Double", sizeof ("Double")))
	{
	  params.vt = VT_R8;
	  if (DV_TYPE_OF (line[1]) != DV_DOUBLE_FLOAT)
	    goto convert_error;
	  params.dblVal = (float) unbox_double (line[1]);
	}
      else /*if (!strncmp (line[0], "CLRObject", sizeof ("CLRObject")))	  */
	{
	  params.vt = VT_I4;
	  if (DV_TYPE_OF (line[1]) != DV_LONG_INT)
	    goto convert_error;
	  params.lVal = (long) unbox (line[1]);

	  if (check_id (params.lVal))
	    is_object = (long) params.lVal;
	  else
	    sqlr_new_error ("22023", "CLR13", "Data supplied is not an CLR object instance where one is needed");
	}
put_it:
      SafeArrayPutElement (*pArray, &inx, (void *) &params);
      SafeArrayPutElement (*oArray, &inx, &is_object);
    }

  return 1;
convert_error:
  sqlr_new_error ("22023", "XXXXX", "invalid or unknown type");
  return 0; /* dummy - msvc needs it */
}


int clr_serialize (int gc_in, dk_session_t * ses)
{
  LONG lstart, lend;
  LONG idx = -1;
  LONG ret_type;
  BSTR* pbstr;
  VARIANT varVals;

  DP_CREATE(1);
  DP_INTPTR(0, gc_in);
  DP_LEN(1);

  CALL(dispid_obj_serialize);

  DP_ERR(NULL, NULL);

  SAFEARRAY *ret = ret = vRet.parray;

  hr = SafeArrayGetLBound(ret, 1, &lstart);
  if(FAILED(hr))
    return 0;

  hr = SafeArrayGetUBound(ret, 1, &lend);
  if(FAILED(hr))
    return 0;

  hr = SafeArrayAccessData(ret ,(void HUGEP**)&pbstr);
  if(SUCCEEDED(hr))
    {
      SafeArrayGetElement (ret, &lstart, &varVals);

      ret_type = varVals.lVal;

      if (!ret_type)
         {
	   return 0;
	 }

      /* get type of object */
      if ((lend -0) < 256)
	{
	  session_buffered_write_char (DV_BIN, ses);
	  session_buffered_write_char ((char) (lend - 0), ses);
	}
      else
	{
	  session_buffered_write_char (DV_LONG_BIN, ses);
	  print_long ((long) (lend - 0), ses);
	}


      for(idx=lstart + 1; idx <= lend; idx++)
	{
	  SafeArrayGetElement (ret, &idx, &varVals);
	  session_buffered_write_char (varVals.bVal, ses);
	}
    }

  return 0;
}


caddr_t
clr_deserialize (dk_session_t * ses, long mode, caddr_t asm_name, caddr_t type, void *udt)
{
  long len, inx;
  caddr_t in_values;
  dk_set_t ret_vec = NULL;
  byte varVals;
  BSTR HUGEP *pbstr;

  in_values = (caddr_t) scan_session_boxing (ses);

  if (DV_TYPE_OF (in_values) != DV_BIN)
    return (caddr_t) box_num (0);

  len = box_length (in_values);

  SAFEARRAYBOUND range = {len};
  SAFEARRAY* pArray = SafeArrayCreate(VT_UI1, 1, &range);
  SafeArrayAccessData(pArray, (void HUGEP**)&pbstr);

  if (in_values)
    dk_free_tree (in_values);

  for (inx = 0; inx < len; inx++)
    {
      varVals = in_values [inx];
      SafeArrayPutElement (pArray, &inx, (void *) &varVals);
    }

  DP_CREATE(4);
  DP_BSTR(0, type);
  DP_BSTR(1, asm_name);
  DP_INT(2, mode);
  DP_ARRAY(3, pArray);
  DP_LEN(4);

  CALL(dispid_obj_deserialize);

  DP_ERR(NULL, NULL);

  SAFEARRAY * ret = vRet.parray;

  sa_to_dk (ret, &ret_vec, 0, udt);

  return conv_ret (list_to_array (dk_set_nreverse (ret_vec)));
}

int copy_ref (int gc_in, void* udt)
{
  dk_set_t ret_vec = NULL;

  DP_CREATE(1);
  DP_INTPTR(0, gc_in);
  DP_LEN(1);

  CALL(dispid_get_copy);

  DP_ERR(NULL, NULL);

  SAFEARRAY *ret = ret = vRet.parray;

  return sa_to_dk (ret, &ret_vec, 1, udt);
}

void del_ref (int gc_in)
{
  if (!del_id (gc_in))
    return;

  DP_CREATE(1);
  DP_INTPTR(0, gc_in);
  DP_LEN(1);

  CALL(dispid_free_ins);

  delete [] dispparams.rgvarg;
}

/*
void dotnet_remove_instance_from_hash (caddr_t int_name)
{

  DP_CREATE(1);
  DP_BSTR(0, int_name);
  DP_LEN(1);

  CALL(dispid_remove_instance_from_hash);

  delete [] dispparams.rgvarg;
}


void dotnet_add_assem_to_sec_hash (caddr_t assem_name)
{

  DP_CREATE(1);
  DP_BSTR(0, assem_name);
  DP_LEN(1);

  CALL(dispid_add_assem_to_sec_hash);

  delete [] dispparams.rgvarg;
}
*/

caddr_t
dotnet_method_call (caddr_t *type_vec, int n_args, int instance, caddr_t method, void *udt, int sec_unrestricted)
{
  COM_ARRAY;

  if (type_vec)
    param_to_safearray (type_vec, n_args, &pArray, &oArray);

  DP_CREATE(5);
  DP_ARRAYS(0);
  DP_BSTR(2, method);
  DP_INT(3, sec_unrestricted);
  DP_INTPTR(4, instance);
  DP_LEN(5);

  CALL(dispid_call_ins);

  DP_ERR("CLR37", "dotnet_method_call");

  ret = vRet.parray;

  if (sa_to_dk (ret, &ret_vec, 0, udt))
    sqlr_new_error ("22023", "CLR14",
	"Can't convert output parameters in dotnet_method_call");

  COM_END;

  return conv_ret (list_to_array (dk_set_nreverse (ret_vec)));
}

caddr_t
dotnet_get_property (long inst, caddr_t prop_name)
{
  dk_set_t ret_vec = NULL;

  if (!check_id (inst))
    sqlr_new_error ("42000", "CLR20", "Not is valid instance in dotnet_get_property");

  DP_CREATE(2);
  DP_BSTR(0, prop_name);
  DP_INTPTR(1, inst);
  DP_LEN(2);

  CALL(dispid_get_prop);

  DP_ERR("CLR21", "dotnet_get_property");

  SAFEARRAY *ret = vRet.parray;

  sa_to_dk (ret, &ret_vec, 0, NULL);

  return conv_ret (list_to_array (dk_set_nreverse (ret_vec)));
}

caddr_t
dotnet_get_stat_prop (int asm_type, caddr_t asm_name, caddr_t type, caddr_t prop_name)
{
  dk_set_t ret_vec = NULL;

  DP_CREATE(4);
  DP_BSTR(0, prop_name);
  DP_BSTR(1, type);
  DP_BSTR(2, asm_name);
  DP_INT(3, asm_type);
  DP_LEN(4);

  CALL(dispid_set_prop);

  DP_ERR("CLR23", "dotnet_get_stat_prop");

  SAFEARRAY *ret = vRet.parray;

  sa_to_dk (ret, &ret_vec, 0, NULL);

  return conv_ret (list_to_array (dk_set_nreverse (ret_vec)));
}

caddr_t dotnet_set_property (caddr_t * type_vec, long instance, caddr_t prop_name)
{
  int n_args = 1;
  COM_ARRAY;

  if (type_vec)
    param_to_safearray (type_vec, 1, &pArray, &oArray);

  DP_CREATE(4);
  DP_ARRAYS(0);
  DP_BSTR(2, prop_name);
  DP_INTPTR(3, instance);
  DP_LEN(4);

  CALL(dispid_set_prop);

  DP_ERR("CLR24", "dotnet_set_property");

  ret = vRet.parray;

  COM_END;

  return conv_ret (list_to_array (dk_set_nreverse (ret_vec)));
}

caddr_t
dotnet_call (caddr_t *type_vec, int n_args, int asm_type, caddr_t asm_name,
    caddr_t type, caddr_t method, void *udt, int sec_unrestricted)
{
  COM_ARRAY;

  if (type_vec)
    param_to_safearray (type_vec, n_args, &pArray, &oArray);

  DP_CREATE(7);
  DP_ARRAYS(0);
  DP_BSTR(2, method);
  DP_BSTR(3, type);
  DP_BSTR(4, asm_name);
  DP_INT(5, sec_unrestricted);
  DP_INT(6, asm_type);
  DP_LEN(7);

  CALL(dispid_call_method_asm);

  DP_ERR("CLR25", "dotnet_call");

  ret = vRet.parray;

  if (sa_to_dk (ret, &ret_vec, 0, udt))
    sqlr_new_error ("42000", "CLR26",
	"Can't convert output parameters in dotnet_call");

  COM_END;
/*XXX VariantClear (&vRet);  XXX*/

  return conv_ret (list_to_array (dk_set_nreverse (ret_vec)));
}


int
create_instance (caddr_t * type_vec, int n_args, long mode, caddr_t asm_name,
    		 caddr_t type, void * udt)
{
  int proc_ret;

  COM_ARRAY;

  if (type_vec)
    param_to_safearray (type_vec, n_args, &pArray, &oArray);

  DP_CREATE(5);
  DP_ARRAYS(0);
  DP_BSTR(2, type);
  DP_BSTR(3, asm_name);
  DP_INT(4, mode);
  DP_LEN(5);

  CALL(dispid_create_ins_asm);

  DP_ERR("CLR27", "dotnet_create_instance");

  ret = vRet.parray;

  proc_ret = sa_to_dk (ret, &ret_vec, 1, udt);

  COM_END;

  return proc_ret;
}

caddr_t clr_compile (caddr_t source, caddr_t outfile)
{
  dk_set_t ret_vec = NULL;

  DP_CREATE(2);
  DP_BSTR(0, source);
  DP_BSTR(1, outfile);
  DP_LEN(2);

  CALL(dispid_compile_source);

  DP_ERR("CLR29", "clr_compile");
  SAFEARRAY * ret = vRet.parray;

  if (sa_to_dk (ret, &ret_vec, 0, NULL))
    sqlr_new_error ("22023", "CLR14",
	"Can't convert output parameters in dotnet_method_call");

  sa_to_dk (ret, &ret_vec, 0, NULL);

  return conv_ret (list_to_array (dk_set_nreverse (ret_vec)));
}

caddr_t clr_add_comp_reference (caddr_t assembly)
{
  dk_set_t ret_vec = NULL;

  DP_CREATE(1);
  DP_BSTR(0, assembly);
  DP_LEN(1);

  CALL(dispid_add_comp_ref);

  DP_ERR("CLR30", "clr_add_comp_reference");
  SAFEARRAY * ret = vRet.parray;

  if (sa_to_dk (ret, &ret_vec, 0, NULL))
    sqlr_new_error ("22023", "CLR31",
	"Can't convert output parameters in clr_add_comp_reference");

  sa_to_dk (ret, &ret_vec, 0, NULL);

  return conv_ret (list_to_array (dk_set_nreverse (ret_vec)));
}


static void set_cache_dirs_to_tmp ()
{
  acl_add_allowed_dir (pid_dir);
}

static int remove_cache_dirs ()
{
  char *p1;
  SHFILEOPSTRUCT sfo;
  HINSTANCE hInstance;

  hInstance = GetModuleHandle(NULL);
  GetModuleFileName(hInstance, server_executable_dir, MAX_PATH);
  p1 = strstr (server_executable_dir, "virtuoso");
  *p1 = 0;

  sprintf (pid_dir, "%s%s\\*.*\0", server_executable_dir, CLR_DISK_CACHE);

  ZeroMemory (&sfo, sizeof (SHFILEOPSTRUCT));

  sfo.wFunc = FO_DELETE;
  sfo.pFrom = (LPCSTR) pid_dir;
  sfo.fFlags = FOF_SILENT | FOF_NOCONFIRMATION | FOF_NOERRORUI;

  SHFileOperation (&sfo);

  sprintf (pid_dir, "%s%s\\%i\\", server_executable_dir, CLR_DISK_CACHE, getpid());
  _rmdir (pid_dir);

  sprintf (pid_dir, "%s%s", server_executable_dir, CLR_DISK_CACHE); /* Removed only for check creation */
  _rmdir (pid_dir);

  return 1;
}

void virt_com_exit ()
{
  spRuntimeHost->UnloadDomain((IUnknown *)spDefAppDomain);
  spRuntimeHost->Stop();

  remove_cache_dirs ();

  if (old_hook)
     (*old_hook) ();
}

extern "C" {
  extern char *virtuoso_odbc_port();
}

int virt_com_init ()
{
  HRESULT hr;
  wchar_t framework_ver[16];

  CComVariant				VntUnwrapped;
  CComPtr<IUnknown>			pUnk;
  CComPtr<_ObjectHandle>		spObjectHandle;

  OLECHAR FAR* sz_call_method_asm = L"call_method_asm";
  OLECHAR FAR* sz_call_ins = L"call_ins";
  OLECHAR FAR* sz_dispid_get_isinstance_of = L"get_IsInstanceOf";
  OLECHAR FAR* sz_free_ins = L"free_ins";
  OLECHAR FAR* sz_get_prop = L"get_prop";
  OLECHAR FAR* sz_get_copy = L"get_copy";
  OLECHAR FAR* sz_obj_serialize = L"obj_serialize";
  OLECHAR FAR* sz_obj_deserialize= L"obj_deserialize";
  OLECHAR FAR* sz_create_ins_asm = L"create_ins_asm";
  OLECHAR FAR* sz_set_prop = L"set_prop";
  OLECHAR FAR* sz_get_stat_prop = L"get_stat_prop";
  OLECHAR FAR* sz_compile_source = L"compile_source";
  OLECHAR FAR* sz_add_comp_reference = L"add_comp_reference";
/*OLECHAR FAR* sz_remove_instance_from_hash = L"remove_instance_from_hash";
  OLECHAR FAR* sz_add_assem_to_sec_hash = L"add_assem_to_sec_hash";*/

  if (!remove_cache_dirs ()) /* Always return true */
    log_info ("Removing cache dirs fails.");

  set_cache_dirs_to_tmp ();

  sprintf (pid_dir, "%s%s\\", server_executable_dir, CLR_DISK_CACHE);
  _mkdir (pid_dir);

  sprintf (pid_dir, "%s%s\\%i\\", server_executable_dir, CLR_DISK_CACHE, getpid());
  _mkdir (pid_dir);


  swprintf (framework_ver, sizeof (framework_ver), L"v%d.%d.%d", CLR_MAJOR_VERSION, CLR_MINOR_VERSION, CLR_BUILD_VERSION);

  /* Retrieve a pointer to the ICorRuntimeHost interface */
  hr = CorBindToRuntimeEx((LPCWSTR)framework_ver,   /* Retrieve latest version by default */
  			  L"wks", /* Request a WorkStation build of the CLR */
			  STARTUP_LOADER_OPTIMIZATION_SINGLE_DOMAIN | STARTUP_CONCURRENT_GC,
			  CLSID_CorRuntimeHost,
			  IID_ICorRuntimeHost,
  			  (void**)&spRuntimeHost);

  CHECK_ERR(1);

  hr = spRuntimeHost->Start();
  CHECK_ERR(2);

  hr = spRuntimeHost->GetDefaultDomain(&pUnk);
  CHECK_ERR(3);

  hr = pUnk->QueryInterface(&spDefAppDomain.p);
  CHECK_ERR(4);

  hr = spDefAppDomain->AppendPrivatePath (_bstr_t(pid_dir));
  CHECK_ERR(99);

  hr = spDefAppDomain->SetData (_bstr_t ("OpenLink.Virtuoso.InProcessPort"), _variant_t (_bstr_t (virtuoso_odbc_port())));
  CHECK_ERR(99);

  /* Creates an instance of the type specified in the Assembly */
  hr = spDefAppDomain->CreateInstance(_bstr_t("virtclr"),
                                      _bstr_t("VInvoke"),
                                      &spObjectHandle);

  CHECK_ERR(5);

  hr = spObjectHandle->Unwrap(&VntUnwrapped);
  CHECK_ERR(6);

  /* We know our .NET component exposes IDispatch */
  virtclr_inst = VntUnwrapped.pdispVal;

  /* Retrieve the DISPID's */
  hr = virtclr_inst->GetIDsOfNames (IID_NULL, &sz_call_method_asm, 1,
      				    LOCALE_SYSTEM_DEFAULT, &dispid_call_method_asm);
  CHECK_ERR(7);

  hr = virtclr_inst->GetIDsOfNames (IID_NULL, &sz_call_ins, 1,
      				    LOCALE_SYSTEM_DEFAULT, &dispid_call_ins);
  CHECK_ERR(8);

  hr = virtclr_inst->GetIDsOfNames (IID_NULL, &sz_dispid_get_isinstance_of, 1,
      				    LOCALE_SYSTEM_DEFAULT, &dispid_get_isinstance_of);
  CHECK_ERR(9);

  hr = virtclr_inst->GetIDsOfNames (IID_NULL, &sz_free_ins, 1,
      				    LOCALE_SYSTEM_DEFAULT, &dispid_free_ins);
  CHECK_ERR(10);

  hr = virtclr_inst->GetIDsOfNames (IID_NULL, &sz_get_prop, 1,
      				    LOCALE_SYSTEM_DEFAULT, &dispid_get_prop);
  CHECK_ERR(11);

  hr = virtclr_inst->GetIDsOfNames (IID_NULL, &sz_get_copy, 1,
      				    LOCALE_SYSTEM_DEFAULT, &dispid_get_copy);
  CHECK_ERR(12);

  hr = virtclr_inst->GetIDsOfNames (IID_NULL, &sz_obj_serialize, 1,
      				    LOCALE_SYSTEM_DEFAULT, &dispid_obj_serialize);
  CHECK_ERR(13);

  hr = virtclr_inst->GetIDsOfNames (IID_NULL, &sz_create_ins_asm, 1,
      				    LOCALE_SYSTEM_DEFAULT, &dispid_create_ins_asm);
  CHECK_ERR(14);

  hr = virtclr_inst->GetIDsOfNames (IID_NULL, &sz_obj_deserialize, 1,
      				    LOCALE_SYSTEM_DEFAULT, &dispid_obj_deserialize);
  CHECK_ERR(15);

  hr = virtclr_inst->GetIDsOfNames (IID_NULL, &sz_set_prop, 1,
      				    LOCALE_SYSTEM_DEFAULT, &dispid_set_prop);
  CHECK_ERR(16);

  hr = virtclr_inst->GetIDsOfNames (IID_NULL, &sz_get_stat_prop, 1,
      				    LOCALE_SYSTEM_DEFAULT, &dispid_get_stat_prop);
  CHECK_ERR(17);

  hr = virtclr_inst->GetIDsOfNames (IID_NULL, &sz_compile_source, 1,
      				    LOCALE_SYSTEM_DEFAULT, &dispid_compile_source);
  CHECK_ERR(18);
  hr = virtclr_inst->GetIDsOfNames (IID_NULL, &sz_add_comp_reference, 1,
      				    LOCALE_SYSTEM_DEFAULT, &dispid_add_comp_ref);
  CHECK_ERR(19);

/*
  hr = virtclr_inst->GetIDsOfNames (IID_NULL, &sz_remove_instance_from_hash, 1,
      				    LOCALE_SYSTEM_DEFAULT, &dispid_remove_instance_from_hash);
  CHECK_ERR(18);

  hr = virtclr_inst->GetIDsOfNames (IID_NULL, &sz_add_assem_to_sec_hash, 1,
      				    LOCALE_SYSTEM_DEFAULT, &dispid_add_assem_to_sec_hash);
  CHECK_ERR(19);
*/
  old_hook = VirtuosoServerSetExitHook (virt_com_exit);

 return 1;
}


typedef struct byte_size_ptr_s
{
  char * name;
  LONG size;
  LPBYTE data;
} byte_size_ptr_t;


static void *
loc_virt_malloc (size_t size)
{
  return CoTaskMemAlloc (size);
}


DWORD WINAPI dotnet_unmanaged_call (LPVOID param)
{
  if (param)
  {
    byte_size_ptr_t *ptr = (byte_size_ptr_t *) param;
    void *ret = NULL;
    long retsize = 0;

    dotnet_get_assembly_by_name (ptr->name, &ret, &retsize, loc_virt_malloc);
    ptr->data = (LPBYTE) ret;
    ptr->size = (LONG) retsize;
  }
  return 0;
}

C_END()

void dbg_malloc_enable (void) { /* nop */; };

#ifndef ONLY_CLR
int
main (int argc, char *argv[])
{
  static char brand_buffer[200];
#ifdef MALLOC_DEBUG
  dbg_malloc_enable ();
#endif
  sprintf (brand_buffer, ".NET CLR %s", clr_version_string ());
  build_set_special_server_model (brand_buffer);
  VirtuosoServerSetInitHook (bif_init_func_clr);

  return VirtuosoServerMain (argc, argv);
}
#endif

#endif

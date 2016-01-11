/*
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
 */

#include "mono.h"
#ifndef WIN32
#include <locale.h>
#endif


#if defined (WIN32) || defined (SOLARIS)
static int
virt_setenv (const char *name, const char *value, int overwrite)
{
  char *buffer;
  int name_len, value_len, ret;
  if (!name)
    return -1;
  if (!overwrite && getenv (name))
    return 0;
  if (!value)
    return putenv (name);

  name_len = strlen (name);
  value_len = strlen (value);
  buffer = malloc (name_len + value_len + 2);
  sprintf (buffer, "%s=%s", name, value);
  ret = putenv (buffer);
  free (buffer);
  return ret;
}
#define setenv virt_setenv
#endif
#include "clr_ll_api.h"

static char *VIRTCLR_NAME = "virtclr.dll";

void
virt_mono_throw_unhandled_exception (MonoObject *exc)
{
  caddr_t err;
  char *message = (char *) "";
  const char *name = (const char *) "";
  MonoString *str;
  MonoMethod *method;
  MonoClass *klass;
  gboolean free_message = FALSE;
  gint i;

  if (mono_object_isinst (exc, mono_get_exception_class ()))
    {
      klass = mono_object_get_class (exc);
      method = NULL;
      while (klass && method == NULL)
	{
	  gpointer m_iter = NULL;
	  for (method = mono_class_get_methods (klass, &m_iter); method != NULL;
	      method = mono_class_get_methods (klass, &m_iter))
	    {
	      MonoMethodSignature *sig = mono_method_signature (method);
	      guint32 flags = 0;
	      const char *name = mono_method_get_name (method);

	      mono_method_get_flags (method, &flags);
	      if (!strcmp ("ToString", name) &&
		  sig->param_count == 0
#ifdef OLD_KIT_1_1_5
		  && (flags & METHOD_ATTRIBUTE_VIRTUAL)
		  && (flags & METHOD_ATTRIBUTE_PUBLIC)
#endif
		  )
		{
		  break;
		}
	      method = NULL;
	    }

	  if (method == NULL)
	    klass = mono_class_get_parent (klass);
	}

      g_assert (method);

      str = (MonoString *) mono_runtime_invoke (method, exc, NULL, NULL);
      if (str) {
	message = mono_string_to_utf8 (str);
	free_message = TRUE;
	name = mono_class_get_name (klass);
      }
    }

  /*
   * g_printerr ("\nUnhandled Exception: %s.%s: %s\n", exc->vtable->klass->name_space,
   *	   exc->vtable->klass->name, message);
   */
  g_printerr ("\nUnhandled Exception: %s\n", message);


  err = srv_make_new_error ("42000", "MN001", "Unhandled Mono Exception [%.200s]: %.200s",
      name, message);
  if (free_message)
    g_free (message);
  sqlr_resignal (err);
}

static MonoDomain *virtuoso_domain;
static MonoThread *
get_mono_thread ()
{
#ifndef MONO_AGENT
  thread_t *thr = THREAD_CURRENT_THREAD;
  MonoThread *ret_thr = NULL;
  if (NULL == (ret_thr = (MonoThread *) THR_ATTR (thr, TA_MONO_THREAD)))
    {
      ret_thr = mono_thread_attach (virtuoso_domain);
      SET_THR_ATTR (thr, TA_MONO_THREAD, ret_thr);
    }
  return ret_thr;
#else
  return NULL;
#endif
}


static MonoObject *
virt_mono_runtime_exec_main (MonoMethod *method, MonoArray *args, MonoObject **exc)
{
  MonoDomain *domain;
  MonoObject *obj, *ret;

  g_assert (args);

  domain = mono_object_get_domain ((MonoObject *) args);
  mono_runtime_ensure_entry_assembly (domain,
      mono_image_get_assembly (
	mono_class_get_image (
	  mono_method_get_class (method))));


#if 0
#ifndef MONO_AGENT
  mono_new_thread_init (get_mono_thread(), &ret);
#endif
#endif
  obj = mono_object_new (domain, mono_method_get_class (method));

  ret = mono_runtime_invoke_array (method, obj, args, exc);

  return ret;

  /* FIXME: check signature of method
     if (method->signature->ret->type == MONO_TYPE_I4) {
     res = mono_runtime_invoke (method, NULL, pa, exc);
     if (!exc || !*exc)
     rval = *(guint32 *)((char *)res + sizeof (MonoObject));
     else
     rval = -1;
     fprintf (stderr, "[INT:%i]\n", rval);
     }
     else if (method->signature->ret->type == MONO_TYPE_SZARRAY)
     {
     MonoObject *res;
     int len;

     res = mono_runtime_invoke (method, NULL, pa, exc);
     rval = mono_array_length ((MonoArrayType *)res);
     len = mono_array_length ((MonoArray*)res);

     for (i = 0; i < len; ++i)
     {
     MonoObject *s; // = (MonoString *)mono_array_get ((MonoArray*)res, gpointer, i);
     fprintf (stderr, "[STRING:%s]\n", mono_string_to_utf8 ((MonoString *)s));
     }

     if (!exc || !*exc)
     rval = *(guint32 *)((char *)res + sizeof (MonoObject));
     else
     rval = -1;
     fprintf (stderr, "[INT:%i]\n", rval);
     } else {
     MonoObject *ress;
     ress = mono_runtime_invoke (method, NULL, pa, exc);
     fprintf (stderr, "[STRING:%s]\n", mono_string_to_utf8 ((MonoString *)ress));
     }

  //	return rval;*/
}


static MonoObject *
mono_jit_exec_virt (MonoAssembly *assembly, char *mtd_name, MonoArray *v_args)
{
  MonoImage *image = mono_assembly_get_image (assembly);
  MonoMethod *method;
  MonoClass *class;
  MonoMethodDesc *desc;
  MonoObject *exc = NULL, *ret;

  class = mono_class_from_name (image, "", "VInvoke");
  desc = mono_method_desc_new (mtd_name, 1);
  method = mono_method_desc_search_in_image (desc, image);

  mono_assembly_set_main (
      mono_image_get_assembly (
	mono_class_get_image (
	  mono_method_get_class (method))));
  /*mono_start_method = mono_marshal_get_runtime_invoke (method);*/

  ret = virt_mono_runtime_exec_main (method, v_args, &exc);
  if (exc)
    virt_mono_throw_unhandled_exception (exc);

  return ret;
}

static MonoObject *
call_mono (caddr_t file_name, caddr_t mtd_name, MonoArray *v_args, MonoDomain *domain)
{
  MonoAssembly *assembly = mono_domain_assembly_open (domain, file_name);
  return mono_jit_exec_virt (assembly, mtd_name, v_args);
}


static MonoDomain *virtuoso_domain = NULL;

static int
param_to_mono_array (caddr_t *list_args, int n_args, MonoArray ** p_i_array, MonoArray **p_o_array)
{
  caddr_t * line;
  MonoObject *arg = NULL;
  MonoDomain *domain = virtuoso_domain;
  MonoArray *i_array, *o_array;
  guint32 is_object;
  int inx;

  i_array = (MonoArray*)mono_array_new (domain, mono_get_object_class (), n_args);
  o_array = (MonoArray*)mono_array_new (domain, mono_get_intptr_class (), n_args);
  for (inx = 0; inx < n_args; ++inx)
    {
      line = (caddr_t *) list_args[inx];

      is_object = 0;
      if (DV_TYPE_OF (line[1]) == DV_DB_NULL)
	{
	  arg = NULL;
	  goto put_it;
	}

      if (!strncmp (line[0], "System.String", sizeof ("System.String")) ||
	  !strncmp (line[0], "String", sizeof ("String")))
	{
	  if (!DV_STRINGP (line[1]))
	    goto convert_error;

	  arg = (MonoObject *) mono_string_new (domain, line[1]);
	}
      else if (!strncmp (line[0], "Int32", sizeof ("Int32"))
	  || !strncmp (line[0], "System.Int32", sizeof ("System.Int32"))
	  || !strncmp (line[0], "int", sizeof ("int")))
	{
	  gint32 ivalue;
	  if (DV_TYPE_OF (line[1]) != DV_LONG_INT)
	    goto convert_error;

	  ivalue = unbox (line[1]);
	  arg = mono_value_box (domain, mono_get_int32_class (), &ivalue);
	}
      else if (!strncmp (line[0], "System.Single", sizeof ("System.Single"))
	  || !strncmp (line[0], "Single", sizeof ("Single")))
	{
	  float flt_value;
	  if (DV_TYPE_OF (line[1]) != DV_SINGLE_FLOAT)
	    goto convert_error;

	  flt_value = unbox_float (line[1]);
	  arg = mono_value_box (domain, mono_get_single_class (), &flt_value);
	}
      else if (!strncmp (line[0], "System.Data.SqlTypes.SqlDouble", sizeof ("System.Data.SqlTypes.SqlDouble"))
            || !strncmp (line[0], "System.Double", sizeof ("System.Double"))
            || !strncmp (line[0], "Double", sizeof ("Double")))
	{
	  double dbl_value;
	  if (DV_TYPE_OF (line[1]) != DV_DOUBLE_FLOAT)
	    goto convert_error;
	  dbl_value = unbox_double (line[1]);
	  arg = mono_value_box (domain, mono_get_double_class (), &dbl_value);
	}
      else /*if (!strncmp (line[0], "CLRObject", sizeof ("CLRObject")))	  */
	{
	  gint32 ivalue;
	  if (DV_TYPE_OF (line[1]) != DV_LONG_INT)
	    goto convert_error;
	  is_object = unbox (line[1]);
	  arg = mono_value_box (domain, mono_get_int32_class (), &ivalue);
	}
put_it:
      mono_array_set (i_array, gpointer, inx, arg);
      mono_array_set (o_array, gpointer, inx, (gpointer) is_object);
    }

  *p_i_array = i_array;
  *p_o_array = o_array;
  return 0;
convert_error:
  sqlr_new_error ("22023", "XXXXX", "wrong or unknown type");
  return 0;
}

static caddr_t
sa_to_dk (MonoArray *mono_list, int ofs, int mode, void *udt)
{
  guint32 ret_type;
  int clr_object = 0;
  MonoObject *type, *value;
  caddr_t ret = NULL;
  MonoClass *cls;
  int len = mono_array_length (mono_list), inx;
  dk_set_t ret_set = NULL;

  type = (MonoObject *)mono_array_get (mono_list, gpointer, ofs + 0);

  ret_type = *(guint32 *)((char *)type + sizeof (MonoObject));

  if (!ret_type)
    {
      char *error_text;
      caddr_t err = NULL;

      value = (MonoObject *)mono_array_get (mono_list, gpointer, ofs + 1);
      error_text = mono_string_to_utf8 ((MonoString *)value);
      if (error_text)
	err = srv_make_new_error ("42000", "MN002", "Mono error : %.200s",
	    mono_class_get_name (mono_object_get_class (value)), error_text);
      else
	err = srv_make_new_error ("42000", "MN003", "Unknown mono error");
      g_free (error_text);
      sqlr_resignal (err);
    }

  /* get type of object */
  clr_object = 0;
  if (ret_type == 5 || ret_type == 6)
    clr_object = 1;

  for (inx = 1; inx < len; inx++)
    {
      value = (MonoObject *)mono_array_get (mono_list, gpointer, ofs + inx);
      if (value)
	{
	  cls = mono_object_get_class (value);
	  if (cls == mono_get_int32_class ())
	    {
	      gint32 v = *(gint32 *)((char *)value + sizeof (MonoObject));
	      if (clr_object)
		{
		  void * what_udt;

		  if (mode)
		    {
		      /*add_id (v);*/
		      ret = box_num (v);
		    }
		  else
		    {
		      what_udt = udt_find_class_for_clr_instance (v, udt);
		      if (what_udt)
			{
			  /*add_id (v);*/
			  ret = cpp_udt_clr_instance_allocate (v, what_udt);
			}
		      else
			{
			  sqlr_new_error ("22023", "MN005", "Can't map Mono result to PL type");
			}
		    }
		}
	      else
		ret = box_num (v);
	    }
	  else if (cls == mono_get_uint32_class())
	    ret = box_num (*(guint32 *)((char *)value + sizeof (MonoObject)));
	  else if (cls == mono_get_single_class ())
	    ret = box_float (*(float *)((char *)value + sizeof (MonoObject)));
	  else if (cls == mono_get_double_class ())
	    ret = box_double (*(double *)((char *)value + sizeof (MonoObject)));
	  else if (cls == mono_get_boolean_class ())
	    ret = box_num (*(guint8 *)((guint8 *)value + sizeof (MonoObject)));
	  else if (cls == mono_get_string_class ())
	    {
	      char *utf8 = mono_string_to_utf8 ((MonoString *)value);
	      ret = box_utf8_as_wide_char (utf8, NULL, strlen (utf8), 0, DV_WIDE);
	      g_free (utf8);
	    }
	  else
	    {
	      const char *name = mono_class_get_name (cls);
	      sqlr_new_error ("22023", "MN006", "Can't map CLR result of type (%s) to PL type",
		  name ? name : "<unknown>");
	    }
	}
      else
	ret = NULL;
    if (ret_type != 3 && ret_type != 4 && ret_type != 5)
  	return ret;
      else
	dk_set_push (&ret_set, ret);
    }
  return list_to_array (dk_set_nreverse (ret_set));
}

#define SET_STRING_ARG(domain,arr,inx,val) \
{ \
  MonoObject *arg = (MonoObject *) mono_string_new (domain,val); \
  mono_array_set (arr, gpointer, inx, arg); \
}

#define SET_INT_ARG(domain,arr,inx,val) \
{ \
  gpointer _v = (gpointer) (ptrlong) (val); \
  MonoObject *arg = mono_value_box (domain, mono_get_intptr_class(), &_v); \
  mono_array_set (arr, gpointer, inx, arg); \
}

#define MAKE_PARAM_ARRAY(domain,len)  (MonoArray*)mono_array_new (domain, mono_get_object_class (), len)

/****************************** TOP LEVEL FUNCTIONS **********************************/

int
dotnet_is_instance_of (int _clr_ret, caddr_t class_name)
{
  MonoDomain *domain = virtuoso_domain;
  MonoArray *v_args = NULL, *mono_list;
  MonoObject *arg = NULL;
  char *p1=NULL, *p2=NULL, *p3 = NULL;
  char t_class_name[200];
  int fl = 1, ret = 0;

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

      get_mono_thread ();
      v_args = MAKE_PARAM_ARRAY (domain, 4);

      SET_INT_ARG (domain, v_args, 0, _clr_ret);
      SET_INT_ARG (domain, v_args, 1, fl);
      SET_STRING_ARG (domain, v_args, 2, p1);
      SET_STRING_ARG (domain, v_args, 3, p3);

  QR_RESET_CTX
    {
      mono_list = (MonoArray *) call_mono (VIRTCLR_NAME, "VInvoke:get_IsInstanceOf", v_args, domain);
    }
  QR_RESET_CODE
    {
      caddr_t err;
      err = thr_get_error_code (THREAD_CURRENT_THREAD);
      dk_free_tree (err);
      POP_QR_RESET;
      return 0;
    }
  END_QR_RESET;

  arg = (MonoObject *) mono_array_get (mono_list, gpointer, 0);
#ifdef MONO_DEBUG
  fprintf (stderr, "VInvoke:get_IsInstanceOf CLR ret=%s data_sz=%d gboolean_sz=%d guint8_sz=%d\n",
      arg->vtable->klass->name,
      (int) (arg->vtable->klass->instance_size - sizeof (MonoObject)),
      sizeof (gboolean),
      sizeof (guint8));
#endif
  ret = *(((guint8 *)arg) + sizeof (MonoObject));
#ifdef MONO_DEBUG
  fprintf (stderr, "VInvoke:get_IsInstanceOf C ret=%d\n", ret);
#endif
  return ret;
}


/* INFO: toplevel udt_clr_instance_copy */
int
copy_ref (int gc_in, void* udt)
{
  MonoDomain *domain = virtuoso_domain;
  MonoArray *v_args, *mono_list;
  caddr_t aret;
  int ret;
  get_mono_thread ();

  v_args = MAKE_PARAM_ARRAY (domain, 1);

  SET_INT_ARG (domain, v_args, 0, gc_in);

  mono_list = (MonoArray *) call_mono (VIRTCLR_NAME, "VInvoke:get_copy", v_args, domain);

  aret = sa_to_dk (mono_list, 0, 1, udt);
  ret = unbox(aret);
  dk_free_box (aret);
  return ret;
}


/* INFO: toplevel udt_clr_serialize */
int clr_serialize (int _gc_in, dk_session_t * ses)
{
  MonoArray *v_args = NULL;
  MonoArray *mono_list;
  int len, inx;
  MonoDomain *domain = virtuoso_domain;
  get_mono_thread ();

  v_args = MAKE_PARAM_ARRAY (domain, 1);

  SET_INT_ARG (domain, v_args, 0, _gc_in);

  QR_RESET_CTX
    {
      mono_list = (MonoArray *) call_mono (VIRTCLR_NAME, "VInvoke:obj_serialize_soap", v_args, domain);
    }
  QR_RESET_CODE
    {
      caddr_t err;
      POP_QR_RESET;
      err = thr_get_error_code (THREAD_CURRENT_THREAD);
      if (ARRAYP (err))
	log_error ("Mono Serialization error : [%s] [%s]", ERR_STATE(err), ERR_MESSAGE (err));
      else
	log_error ("Mono Serialization error : unknown");
      dk_free_tree (err);
      goto no_obj;
    }
  END_QR_RESET;

  len = mono_array_length (mono_list);
  if (len - 1 < 256)
    {
      session_buffered_write_char (DV_BIN, ses);
      session_buffered_write_char (len - 1, ses);
    }
  else
    {
      session_buffered_write_char (DV_LONG_BIN, ses);
      print_long (len - 1, ses);
    }
  for (inx = 1; inx < len; inx++)
    {
      MonoObject *obj = (MonoObject *)mono_array_get (mono_list, gpointer, inx);
      guint8 b = *(guint8 *)((char *)obj + sizeof (MonoObject));
      session_buffered_write_char (b, ses);
    }
  return len;
no_obj:
  session_buffered_write_char (DV_DB_NULL, ses);
  return 1;
}


caddr_t
clr_deserialize (dk_session_t * ses, long mode, caddr_t asm_name, caddr_t type, void *udt)
{
  MonoArray *v_args = NULL, *bin_data;
  MonoArray *mono_list;
  int len;
  caddr_t in_values, bin_data_ptr;
  MonoDomain *domain = virtuoso_domain;
  get_mono_thread ();

  in_values = (caddr_t) scan_session_boxing (ses);
  if (DV_TYPE_OF (in_values) != DV_BIN)
    return (caddr_t) box_num (0);

  len = box_length (in_values);

  bin_data = mono_array_new (domain, mono_get_byte_class(), len);
  bin_data_ptr = mono_array_addr (bin_data, char, 0);
  memcpy (bin_data_ptr, in_values, len);

  if (in_values)
    dk_free_tree (in_values);

  v_args = MAKE_PARAM_ARRAY (domain, 4);


  mono_array_set (v_args, gpointer, 0, bin_data);
  SET_INT_ARG (domain, v_args, 1, mode);
  SET_STRING_ARG (domain, v_args, 2, asm_name);
  SET_STRING_ARG (domain, v_args, 3, type);

  QR_RESET_CTX
    {
      mono_list = (MonoArray *) call_mono (VIRTCLR_NAME, "VInvoke:obj_deserialize", v_args, domain);
    }
  QR_RESET_CODE
    {
      caddr_t err;
      POP_QR_RESET;
      err = thr_get_error_code (THREAD_CURRENT_THREAD);
      if (ARRAYP (err))
	log_error ("Mono Deserialization error : [%s] [%s]", ERR_STATE(err), ERR_MESSAGE (err));
      else
	log_error ("Mono Deserialization error : unknown");
      dk_free_tree (err);
      return 0;
    }
  END_QR_RESET;

  return sa_to_dk ((MonoArray *) mono_list, 0, 0, udt);
}

/* INFO: topelevel udt_clr_instance_free */
void del_ref (int gc_in)
{
  MonoDomain *domain = virtuoso_domain;
  MonoArray *v_args;
  get_mono_thread ();

  v_args = MAKE_PARAM_ARRAY (domain, 1);

  SET_INT_ARG (domain, v_args, 0, gc_in);

  call_mono (VIRTCLR_NAME, "VInvoke:free_ins", v_args, domain);
}

/* INFO: topelevel udt_clr_method_call */
caddr_t
dotnet_method_call (caddr_t *type_vec, int n_args, int _instance, caddr_t method, void *udt, int sec_unrestricted)
{
  MonoArray *v_args = NULL, *i_array = NULL, *o_array = NULL;
  MonoObject *mono_list;
  caddr_t ret = NULL;
  MonoDomain *domain = virtuoso_domain;
  get_mono_thread ();

  v_args = MAKE_PARAM_ARRAY (domain, 5);
  if (param_to_mono_array (type_vec, n_args, &i_array, &o_array))
    sqlr_new_error ("22023", "MN007", "Can't convert parameters");

  SET_INT_ARG (domain, v_args, 0, _instance);
  SET_INT_ARG (domain, v_args, 1, sec_unrestricted);
  SET_STRING_ARG (domain, v_args, 2, method);

  mono_array_set (v_args, gpointer, 3, i_array);
  mono_array_set (v_args, gpointer, 4, o_array);

  mono_list = call_mono (VIRTCLR_NAME, "VInvoke:call_ins", v_args, domain);

  ret = sa_to_dk ((MonoArray *) mono_list, 0, 0, udt);
  return ret;
}

caddr_t
dotnet_get_property (long inst, caddr_t prop_name)
{
  MonoDomain *domain = virtuoso_domain;
  MonoArray *v_args, *mono_list;
  get_mono_thread ();

  v_args = MAKE_PARAM_ARRAY (domain, 2);

  SET_INT_ARG (domain, v_args, 0, inst);
  SET_STRING_ARG (domain, v_args, 1, prop_name);

  mono_list = (MonoArray *) call_mono (VIRTCLR_NAME, "VInvoke:get_prop", v_args, domain);

  return sa_to_dk (mono_list, 0, 0, NULL);
}

/* INFO: toplevel udt_clr_member_observer */
caddr_t
dotnet_get_stat_prop (int _asm_type, caddr_t asm_name, caddr_t type, caddr_t prop_name)
{
  MonoDomain *domain = virtuoso_domain;
  MonoArray *v_args, *mono_list;
  get_mono_thread ();

  v_args = MAKE_PARAM_ARRAY (domain, 4);

  SET_INT_ARG (domain, v_args, 0, _asm_type);
  SET_STRING_ARG (domain, v_args, 1, asm_name);
  SET_STRING_ARG (domain, v_args, 2, type);
  SET_STRING_ARG (domain, v_args, 3, prop_name);

  mono_list = (MonoArray *) call_mono (VIRTCLR_NAME, "VInvoke:get_stat_prop", v_args, domain);

  return sa_to_dk (mono_list, 0, 0, NULL);
}

/* INFO: toplevel udt_clr_member_mutator */
caddr_t
dotnet_set_property (caddr_t *type_vec, long inst, caddr_t prop_name)
{
  MonoArray *v_args, *i_array = NULL, *o_array = NULL;
  MonoObject *mono_list;
  caddr_t ret = NULL;
  MonoDomain *domain = virtuoso_domain;

  get_mono_thread ();
  v_args = MAKE_PARAM_ARRAY (domain, 4);
  if (param_to_mono_array (type_vec, 1, &i_array, &o_array))
    sqlr_new_error ("22023", "MN008", "Can't convert parameters");

  SET_INT_ARG (domain, v_args, 0, inst);
  SET_STRING_ARG (domain, v_args, 1, prop_name);

  mono_array_set (v_args, gpointer, 2, i_array);
  mono_array_set (v_args, gpointer, 3, o_array);
  mono_list = call_mono (VIRTCLR_NAME, "VInvoke:set_prop", v_args, domain);

  ret = sa_to_dk ((MonoArray *) mono_list, 0, 0, NULL);
  return ret;
}

/* INFO: toplevel udt_clr_method_call */
caddr_t
dotnet_call (caddr_t * type_vec, int n_args, int _asm_type, caddr_t asm_name,
    caddr_t type, caddr_t method, void *udt, int sec_unrestricted)
{
  MonoArray *v_args, *i_array = NULL, *o_array = NULL;
  MonoObject *mono_list;
  caddr_t ret = NULL;
  MonoDomain *domain = virtuoso_domain;

  get_mono_thread ();
  v_args = MAKE_PARAM_ARRAY (domain, 7);
  if (param_to_mono_array (type_vec, n_args, &i_array, &o_array))
    sqlr_new_error ("22023", "MN009", "Can't convert parameters");

  SET_INT_ARG (domain, v_args, 0, _asm_type);
  SET_INT_ARG (domain, v_args, 1, sec_unrestricted);
  SET_STRING_ARG (domain, v_args, 2, asm_name);
  SET_STRING_ARG (domain, v_args, 3, type);
  SET_STRING_ARG (domain, v_args, 4, method);

  mono_array_set (v_args, gpointer, 5, i_array);
  mono_array_set (v_args, gpointer, 6, o_array);
  mono_list = call_mono (VIRTCLR_NAME, "VInvoke:call_method_asm", v_args, domain);

  ret = sa_to_dk ((MonoArray *) mono_list, 0, 0, NULL);
  return ret;
}

/* INFO: toplevel udt_clr_instantiate_class */
int
create_instance (caddr_t *type_vec, int n_args, long _mode, caddr_t asm_name, caddr_t type,
    void * udt)
{
  MonoArray *v_args, *i_array = NULL, *o_array = NULL;
  MonoObject *mono_list;
  int len, ret = 0;
  MonoDomain *domain = virtuoso_domain;

  get_mono_thread ();

  v_args = MAKE_PARAM_ARRAY (domain, 5);

  if (param_to_mono_array (type_vec, n_args, &i_array, &o_array))
    sqlr_new_error ("22023", "MN010", "Can't convert parameters");

  SET_INT_ARG (domain, v_args, 0, _mode);
  SET_STRING_ARG (domain, v_args, 1, asm_name);
  SET_STRING_ARG (domain, v_args, 2, type);

  mono_array_set (v_args, gpointer, 3, i_array);
  mono_array_set (v_args, gpointer, 4, o_array);

  mono_list = call_mono (VIRTCLR_NAME, "VInvoke:create_ins_asm", v_args, domain);
  len = mono_array_length ((MonoArray*)mono_list);
  if (len == 2)
    {
      caddr_t aret = sa_to_dk ((MonoArray *) mono_list, 0, 1, udt);
      ret = unbox (aret);
      dk_free_box (aret);
    }
  else
    GPF_T1 ("create_instance");

  return ret;
}

#ifndef MONO_AGENT
caddr_t clr_compile (caddr_t source, caddr_t outfile)
{
  MonoArray *v_args, *i_array = NULL, *o_array = NULL;
  MonoObject *mono_list;
  caddr_t ret = NULL;
  MonoDomain *domain = virtuoso_domain;

  get_mono_thread ();
  v_args = MAKE_PARAM_ARRAY (domain, 2);

  SET_STRING_ARG (domain, v_args, 0, outfile);
  SET_STRING_ARG (domain, v_args, 1, source);
  mono_list = call_mono (VIRTCLR_NAME, "VInvoke:compile_source", v_args, domain);

  return sa_to_dk ((MonoArray *) mono_list, 0, 0, NULL);
}

caddr_t clr_add_comp_reference (caddr_t assembly)
{
  MonoArray *v_args, *i_array = NULL, *o_array = NULL;
  MonoObject *mono_list;
  caddr_t ret = NULL;
  MonoDomain *domain = virtuoso_domain;

  get_mono_thread ();
  log_error (assembly);
  v_args = MAKE_PARAM_ARRAY (domain, 1);

  SET_STRING_ARG (domain, v_args, 0, assembly);
  mono_list = call_mono (VIRTCLR_NAME, "VInvoke:add_comp_reference", v_args, domain);
  return sa_to_dk ((MonoArray *) mono_list, 0, 0, NULL);
}
#endif


caddr_t
dotnet_get_instance_name (int instance)
{
  MonoArray *v_args;
  MonoObject *mono_ret;
  caddr_t ret = NULL;
  MonoDomain *domain = virtuoso_domain;
  char *utf8;

  get_mono_thread ();
  v_args = MAKE_PARAM_ARRAY (domain, 1);

  SET_INT_ARG (domain, v_args, 0, instance);

  mono_ret = call_mono (VIRTCLR_NAME, "VInvoke:get_instance_name", v_args, domain);

  if (!mono_ret || !mono_object_isinst (mono_ret, mono_get_string_class ()))
    GPF_T1 ("not a string in dotnet_get_instance_name");
  utf8 = mono_string_to_utf8 ((MonoString *)mono_ret);
  ret = box_dv_short_string (utf8);
  g_free (utf8);

  return ret;
}


static void
dummy_print (const gchar *str)
{
}

caddr_t mono_get_assembly_by_name (caddr_t *sql_name);


static MonoReflectionAssembly *
ves_icall_VInvoke_LoadAssemblyFromVirtuoso (MonoAppDomain *ad, MonoString *message)
{
  char *asm_name;
  caddr_t name = NULL;
  caddr_t code = NULL;
  long len;

  MonoAssembly *ass;
  MonoDomain *domain = virtuoso_domain;
  MonoImage *image = NULL;
#ifdef OLD_KIT_1_1_5
  MonoImageOpenStatus *status;
#else
  MonoImageOpenStatus status;
#endif

  asm_name = mono_string_to_utf8 (message);
  name = box_copy (asm_name);

  code = mono_get_assembly_by_name (&name);

  if (!code)
    return NULL;

  len = box_length (code);

  image = mono_image_open_from_data (code, len, 0, NULL);

  if (!image)
    return NULL;

#ifdef OLD_KIT_1_1_5
  ass = mono_assembly_open ("", NULL, image);
#else
  ass = mono_assembly_load_from (image, "", &status);
#endif

  if (!ass && !status)
    return NULL;

  return mono_assembly_get_object (domain, ass);
}


#ifndef MONO_AGENT
extern char *virtuoso_odbc_port();

static void
mono_set_port (void)
{
  MonoObject *exc;
  MonoMethod *method;
  MonoClass *class;
  MonoMethodDesc *desc;
  MonoArray *v_args = NULL;
  MonoAppDomain *domain_cls = mono_domain_get_appdomain (virtuoso_domain);
  char *port;

  port = virtuoso_odbc_port ();


  class = mono_object_get_class ((MonoObject *) domain_cls);

  desc = mono_method_desc_new ("System.AppDomain:SetData", 1);
  method = mono_method_desc_search_in_class (desc, class);

  v_args = MAKE_PARAM_ARRAY (virtuoso_domain, 2);
  SET_STRING_ARG (virtuoso_domain, v_args, 0, "OpenLink.Virtuoso.InProcessPort");
  SET_STRING_ARG (virtuoso_domain, v_args, 1, port);

  mono_runtime_invoke_array (method, domain_cls, v_args, &exc);
}

#endif

void
mono_init_virt ()
{
  const char *error;
#ifndef MONO_AGENT
  char * cfg_mono_root_path;
  char * cfg_mono_cfg_dir;
  char * cfg_mono_path;
  char * cfg_mono_trace;

/*g_log_set_always_fatal (G_LOG_LEVEL_ERROR);
  g_log_set_fatal_mask (G_LOG_DOMAIN, G_LOG_LEVEL_ERROR);*/

#ifndef VIRT_MINT
  if (virtuoso_cfg_getstring ("Mono", "MONO_TRACE", &cfg_mono_trace) != -1)
    mono_jit_trace_calls = strcmp (cfg_mono_trace, "On") ? FALSE : TRUE;
#endif
  if (virtuoso_cfg_getstring ("Mono", "MONO_PATH", &cfg_mono_path) != -1)
    setenv ("MONO_PATH", cfg_mono_path, 1);
  if (virtuoso_cfg_getstring ("Mono", "MONO_ROOT", &cfg_mono_root_path) != -1)
    setenv ("MONO_ROOT", cfg_mono_root_path, 1);
  if (virtuoso_cfg_getstring ("Mono", "MONO_CFG_DIR", &cfg_mono_cfg_dir) != -1)
    setenv ("MONO_CFG_DIR", cfg_mono_cfg_dir, 1);
  if (virtuoso_cfg_getstring ("Mono", "virtclr.dll", &VIRTCLR_NAME) == -1)
    VIRTCLR_NAME = "virtclr.dll";

#endif
#ifdef WIN32
  /* mono initialization on win32 has to be done sooner than later */
#ifdef VIRT_MINT
  virtuoso_domain = mono_interp_init ("virtuoso");
#else
  virtuoso_domain = mono_jit_init ("virtuoso");
#endif
  if (cfg_mono_root_path)
    mono_assembly_setrootdir (cfg_mono_root_path);
#endif
#ifndef VIRT_MINT
  mono_jit_trace_calls = FALSE;
#endif
    {
      char *path = getenv ("MONO_ROOT");
      if (path)
	mono_assembly_setrootdir (path);
    }
  /* mono_debug_init (1); */
#ifndef WIN32
  setlocale(LC_ALL, "");
#endif
  g_log_set_always_fatal (G_LOG_LEVEL_ERROR);
  g_log_set_fatal_mask (G_LOG_DOMAIN, G_LOG_LEVEL_ERROR);

  g_set_printerr_handler (dummy_print);
#ifndef WIN32
#ifdef VIRT_MINT
  virtuoso_domain = mono_interp_init ("virtuoso");
#else
  virtuoso_domain = mono_jit_init ("virtuoso");
#endif

  mono_config_parse (NULL);

#ifdef OLD_KIT
  if (NULL != (error = mono_verify_corlib ()))
#elif !defined (OLD_KIT_1_1_5)
  if (NULL != (error = mono_check_corlib_version ()))
#endif
    {
      log_error ("Mono Corlib not in sync with this runtime: %s", error);
      exit (-1);
    }
#ifndef VIRT_MINT
#ifdef OLD_KIT_1_1_5
  mono_thread_attach_aborted_cb = virt_mono_throw_unhandled_exception;
#else
  mono_thread_set_attach_aborted_cb (virt_mono_throw_unhandled_exception);
#endif
#endif
#endif
  mono_add_internal_call ("VInvoke::LoadAssemblyFromVirtuoso(string)", ves_icall_VInvoke_LoadAssemblyFromVirtuoso);

#ifndef MONO_AGENT
  mono_set_port ();
#endif

#ifndef MONO_AGENT
#ifdef OLD_KIT_1_1_4
  log_debug ("Mono config path [%s]", mono_cfg_dir);
#else
  log_debug ("Mono config path [%s]", mono_get_config_dir ());
#endif
#endif
#ifndef WIN32
  setlocale (LC_ALL, "C");
#endif
#ifndef OLD_KIT_1_1_5
  mono_thread_manage ();
  mono_thread_set_main (mono_thread_current());
#endif
}

#ifndef ONLY_MONO
int
main (int argc, char *argv[])
{
  static char brand_buffer[200];
#ifdef MALLOC_DEBUG
  dbg_malloc_enable ();
#endif
  sprintf (brand_buffer, "%s %s", _MONO_NAME_, _MONO_VERSION_);
  build_set_special_server_model (brand_buffer);

  VirtuosoServerSetInitHook (bif_init_func_clr);
#ifdef WIN32
  virtuoso_set_create_thread (GC_CreateThread);
#endif
  return VirtuosoServerMain (argc, argv);
}
#else
char *
mono_outp_virt_init ()
{
  return " " _MONO_VERSION_;
}
#endif

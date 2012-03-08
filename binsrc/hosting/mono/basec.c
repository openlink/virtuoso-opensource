/*
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
 */

#define C_BEGIN() extern "C" {
#define C_END()   }

#include <stdio.h>
#include <string.h>
#include <ctype.h>
#include <stdlib.h>
#include <string.h>

#include <Dk.h>
#include "libutil.h"
#include "sqlnode.h"
#include "sqlfn.h"
#include "sqlpar.h"
#include <util/fnmatch.h>
#include "statuslog.h"
#include "sqlcmps.h"
#include "sqlintrp.h"
#include "sqltype.h"
#include "sqltype_c.h"
#include "sqlbif.h"
#include "sqlo.h"
#include "sqlpfn.h"
#undef PASCAL
#include "sql3.h"
#include "arith.h"
#include "srvmultibyte.h"
#include "clr_ll_api.h"

#define CLR_VERSION "1.0"
#define DV_EXTENSION_OBJ 255
/*#define CLR_DEBUG*/
#undef isp_shema
#define isp_schema(x) isp_schema_1(x)

caddr_t bif_http_handler_aspx (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args);

static sql_class_t *clr_unk_object = NULL;
void sec_check_dba (query_instance_t * qi, char * func);
void dotnet_remove_instance_from_hash (caddr_t int_name);
void dotnet_add_assem_to_sec_hash (caddr_t assem_name);
typedef void (*ddl_init_hook_t) (void *cli);
extern ddl_init_hook_t set_ddl_init_hook (ddl_init_hook_t new_ddl_init_hook);
extern char *temp_aspx_dir_get ();
extern char pid_dir;
void mono_init_virt ();

#define UDT_CLR_I_OBJECT_SET(box,obj) ((caddr_t *)box)[1] = (caddr_t) (obj)
#define UDT_CLR_I_OBJECT(box) ((int)((caddr_t *)box)[1])

#define GET_ASM_NAME(t_class_name) \
  strcpy (t_class_name, class_name); \
  p1 = p3 = t_class_name; \
  for (;;) \
    {  \
      p2 = strstr (p3, "/"); \
      if (!p2) \
	break; \
      else \
	p3 = p2 + 1; \
      fl = fl - 1; \
    } \
  p1 [p3 - p1 - 1] = 0 \

char *clr_version_string ()
{
  return CLR_VERSION;
}


static caddr_t
udt_clr_instance_allocate (int val, sql_class_t *udt)
{
  caddr_t ret = dk_alloc_box_zero (sizeof (caddr_t) * 2, DV_OBJECT);

  UDT_I_CLASS (ret) = udt;
  UDT_CLR_I_OBJECT_SET (ret, val);
  return ret;
}


caddr_t
cpp_udt_clr_instance_allocate (int val, void *udt)
{
  caddr_t ret = dk_alloc_box_zero (sizeof (caddr_t) * 2, DV_OBJECT);

  UDT_I_CLASS (ret) = (sql_class_t *) udt;
  UDT_CLR_I_OBJECT_SET (ret, val);
  return ret;
}


/*
static void
clr_object_dv_free (caddr_t box)
{
  int oldv = UDT_CLR_I_OBJECT (box);
  del_ref (oldv);
}
*/

void * udt_find_class_for_clr_instance (int clr_ret, sql_class_t *target_udt)
{
  sql_class_t **pudt = NULL;
  caddr_t class_name = NULL;
  id_casemode_hash_iterator_t hit;
  sql_class_t *curr_best_udt = NULL;

  if (target_udt)
    {
       class_name = target_udt->scl_ext_name;
    }
  else
   class_name = "";

  id_casemode_hash_iterator (&hit, isp_schema(NULL)->sc_name_to_object [sc_to_type]);
  while (id_casemode_hit_next (&hit, (char **) &pudt))
    {
      sql_class_t *udt = *pudt;
      if (udt && udt->scl_ext_lang == UDT_LANG_CLR &&
	  (!target_udt || udt_instance_of (udt, target_udt)))
	{
	  class_name = udt->scl_ext_name;
	  if (dotnet_is_instance_of (clr_ret, class_name))
	    {
	      if (!curr_best_udt || udt_instance_of (udt, curr_best_udt))
		curr_best_udt = udt;
	    }
	}
    }

#ifdef CLR_DEBUG
  fprintf (stderr, "udt_find_class_for_clr_instance found [%s] [%s]\n",
      target_udt ? target_udt->scl_ext_name : "<none>",
      curr_best_udt ? curr_best_udt->scl_ext_name : "<unknown>");
#endif
  return (void *) (curr_best_udt ? curr_best_udt : clr_unk_object);
}


static void
udt_clr_convert_params (caddr_t *list_args, int n_args, caddr_t *qst)
{
  caddr_t * line, err = NULL, val;
  int inx;

  for (inx = 0; inx < n_args; ++inx)
    {
      caddr_t new_val = NULL;
      line = (caddr_t *) list_args[inx];
      if (DV_TYPE_OF (line[1]) == DV_DB_NULL)
	continue;

      if (!strncmp (line[0], "System.String", sizeof ("System.String")) ||
	  !strncmp (line[0], "String", sizeof ("String")))
	{
	  caddr_t wide = box_cast_to (qst, line[1], DV_TYPE_OF (line[1]), DV_WIDE,
	      NUMERIC_MAX_PRECISION, NUMERIC_MAX_SCALE, &err);
	  caddr_t utf8;
	  if (err)
	    goto error;

	  utf8 = box_wide_as_utf8_char (wide, box_length (wide) / sizeof (wchar_t) - 1, DV_LONG_STRING);
	  dk_free_box (wide);
	  new_val = utf8;
	}
      else if (!strncmp (line[0], "Int32", sizeof ("Int32"))
	  || !strncmp (line[0], "System.Int32", sizeof ("System.Int32"))
	  || !strncmp (line[0], "int", sizeof ("int")))
	{
	  val = box_cast_to (qst, line[1], DV_TYPE_OF (line[1]), DV_LONG_INT,
	      NUMERIC_MAX_PRECISION, NUMERIC_MAX_SCALE, &err);
	  if (err)
	    goto error;

	  new_val = val;
	}
      else if (!strncmp (line[0], "System.Single", sizeof ("System.Single"))
	  || !strncmp (line[0], "Single", sizeof ("Single")))
	{
	  val = box_cast_to (qst, line[1], DV_TYPE_OF (line[1]), DV_SINGLE_FLOAT,
	      NUMERIC_MAX_PRECISION, NUMERIC_MAX_SCALE, &err);

	  if (err)
	    goto error;

	  new_val = val;
	}
      else if (!strncmp (line[0], "System.Data.SqlTypes.SqlDouble", sizeof ("System.Data.SqlTypes.SqlDouble"))
            || !strncmp (line[0], "System.Double", sizeof ("System.Double"))
            || !strncmp (line[0], "Double", sizeof ("Double")))
	{
	  val = box_cast_to (qst, line[1], DV_TYPE_OF (line[1]), DV_DOUBLE_FLOAT,
	      NUMERIC_MAX_PRECISION, NUMERIC_MAX_SCALE, &err);

	  if (err)
	    goto error;

	  new_val = val;
	}
      else /*if (!strncmp (line[0], "CLRObject", sizeof ("CLRObject")))	  */
	{
	  ptrlong ivalue;
	  if (DV_TYPE_OF (line[1]) == DV_LONG_INT)
	    {
	      ivalue = (long) unbox (line[1]);
	    }
	  else if (DV_TYPE_OF (line[1]) == DV_OBJECT)
	    {
	      ivalue = (int) ((caddr_t *)(line[1]))[1];
	    }
	  else
	    {
	      err = srv_make_new_error ("22023", "MN004", "Invalid data type %d", DV_TYPE_OF (line[1]));
	      goto error;
	    }

	  new_val = box_num (ivalue);
	}
      if (new_val)
	{
	  dk_free_tree (line[1]);
	  line[1] = new_val;
	}
    }
  return;
error:
  dk_free_tree (list_args);
  return;
}


static caddr_t *
udt_clr_convert_sets_to_arrays (dk_set_t set, int n_args, caddr_t *qst)
{
  caddr_t *ret = (caddr_t *) list_to_array (dk_set_nreverse (set));
  int inx;
  _DO_BOX_FAST(inx, ret)
    {
      ret[inx] = list_to_array (dk_set_nreverse ((dk_set_t) ret[inx]));
    }
  END_DO_BOX_FAST;
  udt_clr_convert_params (ret, n_args, qst);
  return ret;
}




static caddr_t
udt_clr_instantiate_class (caddr_t * qst, sql_class_t * udt, sql_method_t *mtd,
     state_slot_t ** args, int n_args)
{
  char *p1=NULL, *p2=NULL, *p3 = NULL;
  char t_class_name[200];
  int ret, fl = 1, inx = 0;
  caddr_t class_name = (udt->scl_ext_name);
  dk_set_t type_vec = NULL;
  caddr_t *ret_con;
  caddr_t err = NULL, *perr = &err;

  GET_ASM_NAME (t_class_name);

#ifdef CLR_DEBUG
fprintf (stdout, "udt_clr_instantiate_class %s\n", t_class_name);
#endif

  for (inx = 0; inx < n_args; inx++)
    {
      caddr_t value = qst_get (qst, args[inx]);
      caddr_t sig = NULL;
      dk_set_t temp = NULL;
      if (mtd->scm_param_ext_types[inx])
	{
	  sig = mtd->scm_param_ext_types[inx];
	}
      if (!sig && mtd->scm_signature[inx + 1].sqt_class &&
               mtd->scm_signature[inx + 1].sqt_class->scl_ext_lang == UDT_LANG_CLR &&
               mtd->scm_signature[inx + 1].sqt_class->scl_ext_name)
           {
	     sig = dk_alloc_box (box_length (
		   mtd->scm_signature[inx + 1].sqt_class->scl_ext_name) + 2, DV_SHORT_STRING);
	   }

      dk_set_push (&temp, box_dv_short_string (sig));
      dk_set_push (&temp, box_copy (value));

      dk_set_push (&type_vec, (void *) temp);
    }

  ret_con = udt_clr_convert_sets_to_arrays (type_vec, n_args, qst);

  if (qst)
    {
      IO_SECT(qst);
      ret = create_instance (ret_con, n_args, fl, p1, p3, udt);
      END_IO_SECT (perr);
    }
  else
    {
      ret = create_instance (ret_con, n_args, fl, p1, p3, udt);
    }

  dk_free_tree (ret_con);

  if (err)
    sqlr_resignal (err);

  return udt_clr_instance_allocate (ret, udt);
}

static caddr_t
udt_clr_instance_copy (caddr_t box)
{
  int oldv = UDT_CLR_I_OBJECT (box);
  sql_class_t *udt = UDT_I_CLASS (box);
  int newv = copy_ref (oldv, udt);

#ifdef CLR_DEBUG
fprintf (stdout, "udt_clr_instance_copy Old (%i) New (%i)\n", oldv, newv);
#endif

  return  udt_clr_instance_allocate (newv, udt);
}

static void
udt_clr_instance_free (caddr_t * box)
{
  int oldv = UDT_CLR_I_OBJECT (box);
  del_ref (oldv);

#ifdef CLR_DEBUG
fprintf (stdout, "udt_clr_instance_free %i\n", oldv);
#endif

}

static caddr_t
udt_clr_member_observer (caddr_t *qst, caddr_t udi, sql_field_t *fld, int member_inx)
{
  caddr_t field_name = fld->sfl_ext_name ? fld->sfl_ext_name : fld->sfl_name;
  int inst = UDT_CLR_I_OBJECT (udi);
  caddr_t ret = NULL, err = NULL, *perr = &err;

#ifdef CLR_DEBUG
  fprintf (stdout, "udt_clr_member_observer %s\n", field_name);
#endif

  if (qst)
    {
      IO_SECT(qst);
      ret = dotnet_get_property (inst, field_name);
      END_IO_SECT (perr);
    }
  else
    {
      ret = dotnet_get_property (inst, field_name);
    }

  if (err)
    {
      dk_free_tree (ret);
      sqlr_resignal (err);
    }
  return ret;
}

char *
udt_clr_sqt_to_sig (dtp_t dtp)
{
  switch (dtp)
    {
    case DV_SHORT_INT:
      return "int";
    case DV_LONG_INT:
      return "int";
    case DV_SINGLE_FLOAT:
      return "Single";
    case DV_DOUBLE_FLOAT:
      return "Double";
    case DV_SHORT_STRING:
    case DV_WIDE:
    case DV_LONG_WIDE:
      return "String";
    }
  return "String";
}


static caddr_t
udt_clr_member_mutator
(caddr_t *qst, caddr_t udi, sql_field_t *fld, int member_inx, caddr_t new_val)
{
  caddr_t field_name = fld->sfl_ext_name ? fld->sfl_ext_name : fld->sfl_name;
  sql_class_t *udt = UDT_I_CLASS (udi);
  int m_ins = UDT_CLR_I_OBJECT (udi);
  dk_set_t type_vec = NULL;
  dk_set_t temp = NULL;
  caddr_t type, *ret_con, ret = NULL, err = NULL, *perr = &err;

#ifdef CLR_DEBUG
fprintf (stdout, "udt_clr_member_mutator %s\n", field_name);
#endif

  if (fld->sfl_ext_type)
    type = fld->sfl_ext_type;
  else if (fld->sfl_sqt.sqt_class)
    {
      sql_class_t *fld_udt = fld->sfl_sqt.sqt_class;
      if (fld_udt->scl_ext_lang == UDT_LANG_CLR)
	{
	  char *last_slash;

	  last_slash = strrchr (fld_udt->scl_ext_name, '/');
	  if (last_slash)
	    type = last_slash + 1;
	  else
	    type = fld_udt->scl_ext_name;
	}
      else
	sqlr_new_error ("22023", "CLRXX", "Non-CLR object passed as an CLR parameter for mutating %.200s of %.200s",
	    fld->sfl_name, udt->scl_name);
    }
  if (!type)
    type = udt_clr_sqt_to_sig (fld->sfl_sqt.sqt_dtp);

  dk_set_push (&temp, box_dv_short_string (type));

  dk_set_push (&temp, box_copy (new_val));
  dk_set_push (&type_vec, (void *) temp);

  ret_con =  udt_clr_convert_sets_to_arrays (type_vec, dk_set_length (type_vec), qst);

  if (qst)
    {
      IO_SECT (qst);
      ret = dotnet_set_property (ret_con, m_ins, field_name);
      END_IO_SECT (perr);
    }
  else
    {
      ret = dotnet_set_property (ret_con, m_ins, field_name);
    }

  dk_free_tree (ret_con);

  if (err)
    {
      dk_free_tree (udi);
      sqlr_resignal (err);
    }

  return udi;
}

static caddr_t
udt_clr_method_call (caddr_t *qst, sql_class_t *udt, caddr_t udi,
        sql_method_t *mtd, state_slot_t **args, int n_args)
{
  int inx;
  caddr_t *ret_con = NULL, ret;
  caddr_t method_name = mtd->scm_ext_name;
  caddr_t err = NULL, *perr = &err;
  int m_ins = udi ? UDT_CLR_I_OBJECT (udi) : 0;
  dk_set_t type_vec = NULL;
/*int method_rest = udt->scl_sec_unrestricted;*/
  IO_SECT(qst);

#ifdef CLR_DEBUG
fprintf (stdout, "udt_clr_method_call %s\n", method_name);
#endif

  if (mtd->scm_type == UDT_METHOD_STATIC && method_name[0] == 0 && strlen (method_name + 1) > 0)
    {
      char *p1=NULL, *p2=NULL, *p3 = NULL;
      char t_class_name[200];
      int fl = 1;
      caddr_t class_name = udt->scl_ext_name;

      GET_ASM_NAME (t_class_name);

      ret = dotnet_get_stat_prop (fl, p1, p3, method_name + 1);
      goto endcall;
    }

  if (mtd->scm_type != UDT_METHOD_STATIC)
    {
      args = &(args[1]);
      n_args -= 1;
    }

  for (inx = 0; inx < n_args; inx++)
    {
      caddr_t value = qst_get (qst, args[inx]);
      caddr_t sig = NULL;
      dk_set_t temp = NULL;
      int m_ins = 0;
      if (mtd->scm_param_ext_types[inx])
	{
	  sig = mtd->scm_param_ext_types[inx];
	}
      if (!sig && mtd->scm_signature[inx + 1].sqt_class &&
	  mtd->scm_signature[inx + 1].sqt_class->scl_ext_lang == UDT_LANG_CLR &&
	  mtd->scm_signature[inx + 1].sqt_class->scl_ext_name)
	{
	  sig = dk_alloc_box (box_length (
		mtd->scm_signature[inx + 1].sqt_class->scl_ext_name) + 2, DV_SHORT_STRING);
	}

      if (!sig)
	  sig = udt_clr_sqt_to_sig (mtd->scm_signature[inx + 1].sqt_dtp);
      if (!sig)
	  sig = udt_clr_sqt_to_sig (DV_TYPE_OF (value));
      if (!sig)
	sqlr_new_error ("22023", "CLR01",
	    "Unsupported type in parameter %d of clr_method_call", inx);

      dk_set_push (&temp, box_dv_short_string (sig));

      if (DV_TYPE_OF (value) == DV_OBJECT)
	{
           m_ins = UDT_CLR_I_OBJECT (value);
	   dk_set_push (&temp, box_num (m_ins));
	}
      else
	dk_set_push (&temp, box_copy (value));

      dk_set_push (&type_vec, (void *) temp);
    }

  ret_con = udt_clr_convert_sets_to_arrays (type_vec, n_args, qst);

  if (m_ins)
    ret = dotnet_method_call (ret_con, n_args, m_ins, mtd->scm_name,
			      mtd->scm_signature[0].sqt_class, udt->scl_sec_unrestricted);
  else
    {
      char *p1=NULL, *p2=NULL, *p3 = NULL;
      char t_class_name[200];
      int fl = 1;
      caddr_t class_name = udt->scl_ext_name;

      GET_ASM_NAME (t_class_name);

      ret = dotnet_call (ret_con, n_args, fl, p1, p3, method_name, udt, udt->scl_sec_unrestricted);
    }

endcall:
  END_IO_SECT (perr);

  dk_free_tree (ret_con);
  if (err)
    {
      dk_free_tree (ret);
      sqlr_resignal (err);
    }
  return ret;
}

int clr_serialize (int gc_in, dk_session_t * ses);
caddr_t clr_deserialize (dk_session_t * ses, long mode, caddr_t asm_name, caddr_t type, void *udt);

static int
udt_clr_serialize (caddr_t udi, dk_session_t * session)
{
  int m_ins = udi ? UDT_CLR_I_OBJECT (udi) : 0;

#ifdef CLR_DEBUG
fprintf (stdout, "udt_clr_serialize (%i)\n", m_ins);
#endif

  clr_serialize (m_ins, session);

  return 0;
}

static void *
udt_clr_deserialize (dk_session_t * ses, dtp_t dtp, sql_class_t *udt)
{
  char *p1=NULL, *p2=NULL, *p3 = NULL;
  char t_class_name[200];
  caddr_t class_name = (udt->scl_ext_name);
  int fl = 1;

  GET_ASM_NAME (t_class_name);

#ifdef CLR_DEBUG
fprintf (stdout, "udt_clr_deserialize %s\n", t_class_name);
#endif
  return clr_deserialize (ses, fl, p1, p3, udt);
}

caddr_t bif_aspx_get_temp_directory (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{

  if (temp_aspx_dir_get())
    return box_dv_short_string (temp_aspx_dir_get());
  else
    return box_dv_short_string ("temp");
}

extern void sqls_define_clr (client_connection_t *cli);
extern void sqls_define_xslt (client_connection_t *cli);
static void (*old_ddl_hook) (client_connection_t *cli) = NULL;

caddr_t dotnet_get_assembly_real (caddr_t *sql_name);

caddr_t bif_get_dll_name (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t ret = NULL;
  caddr_t sql_name = bif_string_arg (qst, args, 0, "__get_dll_name");

  ret = dotnet_get_assembly_real (&sql_name);

  return ret ? box_dv_short_string (ret) : box_dv_short_string (sql_name);
}

/*
caddr_t bif_remove_dll_from_hash (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t int_name = bif_string_arg (qst, args, 0, "__remove_dll_from_hash");

#ifndef MONO
  dotnet_remove_instance_from_hash (int_name);
#endif

  return box_dv_short_string(int_name);
}

caddr_t bif_add_assem_to_sec_hash (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t assem_name = bif_string_arg (qst, args, 0, "__add_assem_to_sec_hash");

#ifndef MONO
  dotnet_add_assem_to_sec_hash (assem_name);
#endif

  return box_dv_short_string(assem_name);
}
*/

caddr_t bif_dotnet_get_pid_dir (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return box_dv_short_string(&pid_dir);
}

caddr_t bif_clr_compile (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t text = bif_string_arg (qst, args, 0, "__dotnet_compile");
  caddr_t ofile = bif_string_arg (qst, args, 1, "__dotnet_compile");
  caddr_t ret = NULL;

  IO_SECT(qst);
  ret = clr_compile (text, ofile);
  END_IO_SECT (err_ret);
  if (*err_ret)
    {
      dk_free_tree (ret);
      ret = NULL;
    }
  return ret;
}

caddr_t bif_clr_add_refence (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t ref = bif_string_arg (qst, args, 0, "__dotnet_add_reference");
  caddr_t ret = NULL;

  IO_SECT(qst);
  ret = clr_add_comp_reference (ref);
  END_IO_SECT (err_ret);
  if (*err_ret)
    {
      dk_free_tree (ret);
      ret = NULL;
    }
  return ret;
}


static void
clr_ddl_hook (client_connection_t *cli)
{
   if (old_ddl_hook)
      old_ddl_hook (cli);

   clr_unk_object = udt_alloc_class_def ("DB.DBA.UNKNOWN_CLR_HOSTED_OBJECT");
   clr_unk_object->scl_ext_lang = UDT_LANG_CLR;

   sqls_define_clr (cli);
   if (!old_ddl_hook)
     sqls_define_xslt (cli);
}

static caddr_t
bif_clr_runtime_name (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
#ifdef MONO
  return box_dv_short_string ("Mono");
#else
  return box_dv_short_string ("MS.NET");
#endif
}

void
bif_init_func_clr (void)
{
  sql_class_imp_t *map = get_imp_map_ptr (UDT_LANG_CLR);
/*  dk_mem_hooks (DV_EXTENSION_OBJ, dv_extension_obj_copy, clr_object_dv_free);*/

#ifdef MONO
  mono_init_virt();
#endif

  bif_define ("aspx_get_temp_directory", bif_aspx_get_temp_directory);
  bif_define ("__get_dll_name", bif_get_dll_name);
  bif_define ("clr_runtime_name", bif_clr_runtime_name);
/*bif_define ("__remove_dll_from_hash", bif_remove_dll_from_hash);
  bif_define ("__add_assem_to_sec_hash", bif_add_assem_to_sec_hash);*/
  bif_define ("__dotnet_get_pid_dir", bif_dotnet_get_pid_dir);
  bif_define ("__dotnet_compile", bif_clr_compile);
  bif_define ("__dotnet_add_reference", bif_clr_add_refence);

  map->scli_deserialize = udt_clr_deserialize;
  map->scli_instance_copy = udt_clr_instance_copy;
  map->scli_instantiate_class = udt_clr_instantiate_class;
  map->scli_instance_free = udt_clr_instance_free;
  map->scli_member_observer = udt_clr_member_observer;
  map->scli_member_mutator = udt_clr_member_mutator;
  map->scli_method_call = udt_clr_method_call;
  map->scli_serialize = udt_clr_serialize;

  old_ddl_hook = (void *) set_ddl_init_hook ((void *)clr_ddl_hook);

#ifdef MONO
  log_info ("Hosting %s %s", _MONO_NAME_, _MONO_VERSION_);
#else
  log_info ("Hosting Microsoft .NET CLR %s", clr_version_string ());
  if (!virt_com_init ())
    exit (-1);
#endif
}

void
dotnet_get_assembly_by_name (char *pbs_name, void **pbs_data, long *pbs_size, void * (*str_malloc) (size_t))
{
  dk_thread_t *thr;

  *pbs_size = 0;
  *pbs_data = 0;
  thr = PrpcThreadAttach ();
  if (thr)
    {
      caddr_t err = NULL;
      local_cursor_t *lc = NULL;
      static client_connection_t *cli = NULL;
      static query_t *qr_p = NULL;
      static query_t *qr_s = NULL;

      if (!cli)
        {
          cli = client_connection_create ();
	}
      local_start_trx (cli);

      if (!qr_p)
	qr_p = sql_compile ("call (?) (?, ?)", cli, &err, SQLC_DEFAULT);

      if (err)
        {
          log_debug ("Error in compiling [%s] : %s", ERR_STATE (err), ERR_MESSAGE (err));
          dk_free_tree (err);
          err = NULL;
          goto done;
        }

      if (!qr_s)
	qr_s = sql_compile ("SELECT blob_to_string (VAC_DATA) from DB.DBA.CLR_VAC where VAC_REAL_NAME=?",
	    cli, &err, 0);

      if (err)
        {
          log_debug ("Error in compiling [%s] : %s", ERR_STATE (err), ERR_MESSAGE (err));
          dk_free_tree (err);
          err = NULL;
          goto done;
        }

      err = qr_quick_exec (qr_p, cli, NULL, NULL, 3,
	  ":0", "DB.DBA.CACHE_ASSEMBLY_TO_DISK", QRP_STR,
	  ":1", pbs_name, QRP_STR,
	  ":2", &pid_dir, QRP_STR);

      err = qr_quick_exec (qr_s, cli, NULL, &lc, 1,
          ":0", pbs_name, QRP_STR);

      if (!err && lc && lc_next (lc) && !lc->lc_error)
        {
          caddr_t val = lc_nth_col (lc, 0);
          if (val && DV_STRINGP (val))
            {
              *pbs_size = box_length (val) - 1;
    	      if (*pbs_size)
    	        {
    	          *pbs_data = str_malloc (*pbs_size);
    	          memcpy (*pbs_data, val, *pbs_size);
    	        }
    	    }
        }
done:
      local_commit_end_trx (cli);
      if (!err && lc)
        lc_free (lc);

      if (err)
	{
	  log_debug ("Error in executing [%s] : %s", ERR_STATE (err), ERR_MESSAGE (err));
	  dk_free_tree (err);
	}

      PrpcThreadDetach ();
    }
}


caddr_t
mono_get_assembly_by_name (caddr_t *sql_name)
{
  caddr_t err = NULL;
  local_cursor_t *lc = NULL;
  client_connection_t *cli = GET_IMMEDIATE_CLIENT_OR_NULL;
  caddr_t ret = NULL;
  static query_t *qr_sm = NULL;

  if (!qr_sm)
    qr_sm = sql_compile ("SELECT blob_to_string (VAC_DATA) from DB.DBA.CLR_VAC where VAC_REAL_NAME=?",
	cli, &err, 0);

  if (!qr_sm || !cli)
    goto done;
  err = qr_quick_exec (qr_sm, cli, NULL, &lc, 1,
      ":0", *sql_name, QRP_STR);


  if (!err && lc && lc_next (lc) && !lc->lc_error)
    {
      caddr_t val = lc_nth_col (lc, 0);
      if (val && DV_STRINGP (val))
	{
	  ret = box_copy (val);
	}
    }

  if (!err && lc)
    lc_free (lc);
  if (err)
    {
      log_debug ("Error in executing [%s] : %s", ERR_STATE (err), ERR_MESSAGE (err));
      dk_free_tree (err);
    }

done:
  return ret;
}


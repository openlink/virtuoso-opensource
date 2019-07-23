/*
 *  sqltype.c
 *
 *  $Id$
 *
 *  User defined types routines
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
 */

#include "Dk.h"
#include "libutil.h"
#include "sqlnode.h"
#include "arith.h"
#include "sqlfn.h"
#include "sqlpar.h"
#include "security.h"
#include "util/fnmatch.h"
#include "statuslog.h"
#include "sqlcmps.h"
#include "sqlintrp.h"
#include "sqltype.h"
#include "sqltype_c.h"
#include "sqlbif.h"
#include "sqlo.h"
#include "sqlpfn.h"
#include "sqlcstate.h"
#include "xmltree.h"
#ifndef __SQL3_H
#define __SQL3_H
#include "sql3.h"
#endif

sql_class_imp_t imp_map[UDT_N_LANGS];

void ddl_type_changed (query_instance_t * qi, char *full_type_name, sql_class_t *udt, caddr_t tree);
int sec_udt_check (sql_class_t * udt, oid_t group, oid_t user, int op);

sql_class_imp_t *
get_imp_map_ptr(int type)
{
  return &(imp_map[type]);
}

sql_class_t *udt_alloc_class_def (caddr_t name);
static sql_class_t *
udt_store_forward_reference (caddr_t name, dbe_schema_t *sc, client_connection_t *cli, sql_class_t *udt_def);
static int udt_try_instantiable (dbe_schema_t * sc, sql_class_t * udt,
    caddr_t * err_ret);
void udt_free_class_def (sql_class_t * udt);
int udt_instance_of (sql_class_t * udt, sql_class_t * sudt);
static int udt_sqt_distance (sql_type_t * sqtv, sql_type_t * sqtp);
static int sqlc_udt_has_constructor_method (sql_comp_t * sc,
    sql_class_t * udt, state_slot_t * ret, state_slot_t ** params);
static dk_set_t udt_get_derived_classes (dbe_schema_t *sc, sql_class_t *udt);

static caddr_t
udo_new_object_ref (/*object_space_t *udo,*/ caddr_t udi /*, int copy_udi*/);

static query_t *udt_add_qr;
static query_t *udt_read_qr;
static query_t *udt_drop_qr;
static query_t *udt_drop_methods_qr;
static query_t *udt_drop_grants_qr;
static query_t *udt_get_tree_by_id_qr;
static query_t *udt_replace_qr;
static query_t *udt_tree_update_qr;
static query_t *udt_mark_tb_affected_qr;

sql_class_t *
ddl_type_to_class (caddr_t * type, sql_class_t *udt)
{
  if (BOX_ELEMENTS (type) > 3 && type[3])
    {
      if (udt && !CASEMODESTRCMP (udt->scl_name, type[3]))
	return udt;
      else
	return sch_name_to_type (isp_schema (NULL), type[3]);
    }
  else
    return NULL;
}


static void
udt_data_type_ref_to_sqt (dbe_schema_t * sc, caddr_t dt, sql_type_t * sqt,
    caddr_t * err_ret, int store_in_hash, sql_class_t *udt, client_connection_t *cli)
{
  ddl_type_to_sqt (sqt, (caddr_t *) dt);
  sqt->sqt_non_null = 0;

  if (sqt->sqt_dtp == DV_OBJECT)
    {
      caddr_t name = BOX_ELEMENTS (dt) > 3 ? ((caddr_t *)dt)[3] : NULL;
      sqt->sqt_class = NULL;
      if (name)
	{
	  if (udt && !CASEMODESTRCMP (udt->scl_name, name))
	    sqt->sqt_class = udt;
	  else
	    sqt->sqt_class = sch_name_to_type (sc, name);

	  if (sqt->sqt_class == NULL && store_in_hash)
	    {
	      sqt->sqt_class = udt_store_forward_reference (((caddr_t *)dt)[3],
		  sc, cli, udt);
	    }
	}
    }
}


static void
udt_compile_class_representation (dbe_schema_t * sc, sql_class_t * udt,
    UST * tree, caddr_t * err_ret, int store_in_hash, client_connection_t *cli)
{
  int inx = 0;

  if (err_ret)
    *err_ret = NULL;
  if (!tree->_.type.representation)
    return;

  if (IS_DISTINCT_TYPE (tree))
    {
      caddr_t dt = ((caddr_t *) (tree)->_.type.representation)[0];
      udt->scl_fields =
	  (sql_field_t *) dk_alloc_box_zero (sizeof (sql_field_t), DV_BIN);
      udt->scl_fields[inx].sfl_name = NULL;
      udt_data_type_ref_to_sqt (sc, dt, &(udt->scl_fields[inx].sfl_sqt),
	  err_ret, store_in_hash, udt, cli);
      udt->scl_fields[inx].sfl_ext_lang = udt->scl_ext_lang;
    }
  else
    {
      udt->scl_fields =
	  (sql_field_t *) dk_alloc_box_zero (BOX_ELEMENTS (tree->_.type.
	      representation) * sizeof (sql_field_t), DV_BIN);
      _DO_BOX_FAST (inx, tree->_.type.representation)
      {
	UST *ufld = ((UST **) tree->_.type.representation)[inx];
	caddr_t dt = (caddr_t) ufld->_.member.data_type;

	udt->scl_fields[inx].sfl_name =
	    box_dv_short_string (ufld->_.member.name);
	udt->scl_fields[inx].sfl_ext_lang = udt->scl_ext_lang;
	if (ufld->_.member.ext_def)
	  {
	    udt->scl_fields[inx].sfl_ext_name = box_dv_short_string (ufld->_.member.ext_def->_.ext_def.name);
	    udt->scl_fields[inx].sfl_ext_type = box_dv_short_string (ufld->_.member.ext_def->_.ext_def.type);
	  }
	else
	  udt->scl_fields[inx].sfl_ext_name = box_dv_short_string (udt->scl_fields[inx].sfl_name);

	if (BOX_ELEMENTS (ufld) > 7 && ufld->_.member.soap_def)
	  {
	    udt->scl_fields[inx].sfl_soap_name = box_dv_short_string (ufld->_.member.soap_def->_.soap_def.name);
	    udt->scl_fields[inx].sfl_soap_type = box_dv_short_string (ufld->_.member.soap_def->_.soap_def.type);
	  }

	udt->scl_fields[inx].sfl_default = box_copy (ufld->_.member.deflt);
	udt_data_type_ref_to_sqt (sc, dt, &(udt->scl_fields[inx].sfl_sqt),
	    err_ret, store_in_hash, udt, cli);
	if (err_ret && *err_ret)
	  return;
	if (udt->scl_fields[inx].sfl_ext_lang != udt->scl_ext_lang)
	  {
	    caddr_t err = srv_make_new_error ("37000", "UD009",
		"Field %.200s declared of different language than the class %.200s",
		udt->scl_fields[inx].sfl_name, udt->scl_name);
	    if (err_ret)
	      {
		*err_ret = err;
		return;
	      }
	    else
	      sqlr_resignal (err);
	  }
	if (udt->scl_fields[inx].sfl_sqt.sqt_class)
	  {
	    sql_class_t *fld_udt = udt->scl_fields[inx].sfl_sqt.sqt_class;
	    if (udt->scl_ext_lang != fld_udt->scl_ext_lang)
	      {
		caddr_t err = srv_make_new_error ("37000", "UD010",
		    "Field %.200s declared of different language than the class %.200s",
		    udt->scl_fields[inx].sfl_name, udt->scl_name);
		if (err_ret)
		  {
		    *err_ret = err;
		    return;
		  }
		else
		  sqlr_resignal (err);
	      }
	  }
      }
      END_DO_BOX_FAST;
    }
}


static void
udt_parm_list_to_sig (dbe_schema_t * sc, caddr_t parms, caddr_t * names, caddr_t *types,
    sql_type_t * sig, caddr_t * err_ret, sql_class_t *udt, client_connection_t *cli,
    int store_in_hash)
{
  int pinx;
  caddr_t err = NULL;
  DO_BOX (ST *, parm, pinx, ((ST **) parms))
  {
    if (names)
      names[pinx] = box_dv_short_string (parm->_.var.name->_.col_ref.name);
    if (types && parm->_.var.alt_type)
      types[pinx] = box_dv_short_string (parm->_.var.alt_type);

    if (sig)
      udt_data_type_ref_to_sqt (sc, (caddr_t) parm->_.var.type,
	  &(sig[pinx]), &err, store_in_hash, udt, cli);

    if (err_ret && *err_ret)
      return;
  }
  END_DO_BOX;
}


static void
udt_compile_class_methods (dbe_schema_t * sc, sql_class_t * udt,
    UST * tree, caddr_t * err_ret, int store_in_hash, client_connection_t *cli)
{
  int inx;

  if (!tree->_.type.methods || !BOX_ELEMENTS (tree->_.type.methods))
    return;
  udt->scl_methods =
      (sql_method_t *) dk_alloc_box_zero (BOX_ELEMENTS (tree->_.type.
	  methods) * sizeof (sql_method_t), DV_BIN);
  DO_BOX (UST *, mtd, inx, tree->_.type.methods)
  {
    sql_method_t *udtm = &(udt->scl_methods[inx]);
    UST *mt = mtd->_.method_def.method;
    int n_plus_args = 1;
    int n_args;

    n_args = n_plus_args + BOX_ELEMENTS (mt->_.method.parms);

    udtm->scm_class = udt;
    udtm->scm_name = box_dv_short_string (mt->_.method.name);
    udtm->scm_type = (int) mt->_.method.type;
    udtm->scm_override = (int) mtd->_.method_def.override;
    udtm->scm_param_names = (caddr_t *) box_copy ((box_t) mt->_.method.parms);
    memset (udtm->scm_param_names, 0, box_length (udtm->scm_param_names));
    udtm->scm_param_ext_types = (caddr_t *) box_copy ((box_t) mt->_.method.parms);
    memset (udtm->scm_param_ext_types, 0, box_length (udtm->scm_param_ext_types));
    udtm->scm_signature =
	(sql_type_t *) dk_alloc_box (n_args * sizeof (sql_type_t),
	DV_ARRAY_OF_POINTER);
    memset (udtm->scm_signature, 0, box_length (udtm->scm_signature));

    if (mt->_.method.specific_name)
      udtm->scm_specific_name =
	  box_dv_short_string (mt->_.method.specific_name);
    else
      {
	char temp[MAX_QUAL_NAME_LEN];
	snprintf (temp, sizeof (temp), "%s.%s.%s",
	    udt->scl_qualifier, udt->scl_owner, mt->_.method.name);
	udtm->scm_specific_name = box_dv_short_string (mt->_.method.name);
      }

    if (udtm->scm_type == UDT_METHOD_CONSTRUCTOR)
      {
	udtm->scm_signature[0].sqt_dtp = DV_OBJECT;
	udtm->scm_signature[0].sqt_class = udt;
      }
    else
      udt_data_type_ref_to_sqt (sc, (caddr_t) mt->_.method.ret_type,
	  &(udtm->scm_signature[0]), err_ret, store_in_hash, udt, cli);
    if (err_ret && *err_ret)
      return;

    udt_parm_list_to_sig (sc, (caddr_t) mt->_.method.parms,
	udtm->scm_param_names, udtm->scm_param_ext_types,
	&(udtm->scm_signature[n_plus_args]), err_ret, udt, cli,
	store_in_hash);
    if (err_ret && *err_ret)
      return;
    if (mtd->_.method_def.props)
      {
	int inx2;
	DO_BOX (UST *, prop, inx2, mtd->_.method_def.props)
	  {
	    if (ST_P (prop, UDT_EXT))
	      {
		if (prop->_.ext_def.name)
		  {
		    if (udtm->scm_ext_name && err_ret)
		      {
			*err_ret = srv_make_new_error ("37000", "UD011", "Duplicate external name option");
			return;
		      }
		    udtm->scm_ext_name = box_dv_short_string (prop->_.ext_def.name);
		  }
		else if (prop->_.ext_def.language != UDT_LANG_NONE)
		  {
		    if (udtm->scm_ext_lang != UDT_LANG_NONE && err_ret)
		      {
			*err_ret = srv_make_new_error ("37000", "UD012", "Duplicate external language option");
			return;
		      }
		    udtm->scm_ext_lang = (int) prop->_.ext_def.language;
		  }
		else if (prop->_.ext_def.type)
		  {
		    if (udtm->scm_ext_type && err_ret)
		      {
			*err_ret = srv_make_new_error ("37000", "UD013", "Duplicate external language option");
			return;
		      }
		    udtm->scm_ext_type = box_dv_short_string (prop->_.ext_def.type);
		  }
	      }
	    else if (ST_P (prop, UDT_VAR_EXT))
	      {
		if (udtm->scm_type != UDT_METHOD_STATIC)
		  {
		    *err_ret = srv_make_new_error ("37000", "UD014", "EXTERNAL VARIABLE NAME can be used only with STATIC methods");
		    return;
		  }
		udtm->scm_ext_name = dk_alloc_box (strlen (prop->_.ext_def.name) + 2, DV_SHORT_STRING);
		memset (udtm->scm_ext_name, 0, box_length (udtm->scm_ext_name));
		strncpy (udtm->scm_ext_name + 1, prop->_.ext_def.name, box_length (udtm->scm_ext_name) - 2);
		udtm->scm_ext_name[box_length (udtm->scm_ext_name) - 1] = 0;
	      }
	  }
	END_DO_BOX;
      }
    if (udtm->scm_ext_lang == UDT_LANG_NONE)
      udtm->scm_ext_lang = udt->scl_ext_lang;
    if (!udtm->scm_ext_name)
      udtm->scm_ext_name = box_dv_short_string (udtm->scm_name);

    if (udtm->scm_ext_lang != udt->scl_ext_lang)
      {
	caddr_t err = srv_make_new_error ("37000", "UD015",
	    "Method %.200s declared of different language than the class %.200s",
	    udtm->scm_name, udt->scl_name);
	if (err_ret)
	  {
	    *err_ret = err;
	    return;
	  }
	else
	  sqlr_resignal (err);
      }
  }
  END_DO_BOX;
}


static sql_class_t *
udt_store_forward_reference (caddr_t name, dbe_schema_t *sc, client_connection_t *cli, sql_class_t *udt_def)
{
  sql_class_t *udt;
  char q[MAX_NAME_LEN];
  char o[MAX_NAME_LEN];
  char n[MAX_NAME_LEN];
  char complete[MAX_QUAL_NAME_LEN];

  q[0] = 0;
  o[0] = 0;
  n[0] = 0;
  sch_split_name (cli->cli_qualifier, name, q, o, n);
  sch_normalize_new_table_case (sc, q, sizeof (q), o, sizeof (o));
  if (!q[0])
    strcpy_ck (q, cli->cli_qualifier);
  if (!o[0])
    strcpy_ck (o, CLI_OWNER (cli));
  snprintf (complete, sizeof (complete), "%s.%s.%s", q, o, n);
  udt = udt_alloc_class_def (complete);
  if (udt_def)
    udt->scl_ext_lang = udt_def->scl_ext_lang;
  else
    udt->scl_ext_lang = UDT_LANG_SQL;
  id_casemode_hash_set (sc->sc_name_to_object[sc_to_type],
      udt->scl_qualifier_name, udt->scl_owner,
      (caddr_t) & udt);
  return udt;
}

char *
udt_language_name (int lang)
{
  switch (lang)
    {
      case UDT_LANG_SQL: return "Virtuoso/PL SQL";
      case UDT_LANG_JAVA: return "Java";
      case UDT_LANG_C: return "C";
      case UDT_LANG_CLR: return "CLR";
      default: GPF_T1("Unknown language"); return NULL;
    }
}

query_t * qr_dotnet_get_assembly_real = NULL;

caddr_t
dotnet_get_assembly_real (caddr_t *sql_name)
{

      caddr_t err = NULL;
      local_cursor_t *lc = NULL;
      client_connection_t *cli = GET_IMMEDIATE_CLIENT_OR_NULL;
      caddr_t ret = NULL;

      if (!qr_dotnet_get_assembly_real || !cli)
	goto done;
      err = qr_quick_exec (qr_dotnet_get_assembly_real, cli, NULL, &lc, 1,
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

sql_class_t *
udt_compile_class_def (dbe_schema_t * sc, caddr_t _tree, sql_class_t * udt,
    caddr_t * err_ret, int store_in_hash, client_connection_t *cli,
    long udt_id, long udt_migrate_to)
{
  UST *tree = (UST *) _tree;
  int inx;
  sql_class_t *old_udt;

  if (cli->cli_user && !sec_user_has_group (0, cli->cli_user->usr_g_id))
    {
      char q[MAX_NAME_LEN], o[MAX_NAME_LEN], n[MAX_NAME_LEN];
      sch_split_name (NULL, tree->_.type.name, q, o, n);
      if (cli->cli_user->usr_name && o[0] != 0 && CASEMODESTRCMP (cli->cli_user->usr_name, o))
	{
	  caddr_t err = srv_make_new_error ("42000", "UD095",
	      "user defined type %.200s owner specified is different than the creator.",
	      tree->_.type.name);
	  if (err_ret)
	    {
	      *err_ret = err;
	      return udt;
	    }
	  else
	    sqlr_resignal (err);
	}
    }

  old_udt = sch_name_to_type (sc, tree->_.type.name);
  if (old_udt && old_udt->scl_defined && udt_migrate_to == 0)
    {
      caddr_t err = srv_make_new_error ("37000", "UD016",
	  "Class %.200s already declared",
	  old_udt->scl_name);
      if (err_ret)
	{
	  *err_ret = err;
	  return udt;
	}
      else
	sqlr_resignal (err);
    }

  if (!udt)
    udt = udt_alloc_class_def (tree->_.type.name);

  if (tree->_.type.ext_def)
    {
      caddr_t ext_name = tree->_.type.ext_def->_.ext_def.name ?
	  tree->_.type.ext_def->_.ext_def.name : udt->scl_name_only;
      caddr_t int_name = dotnet_get_assembly_real (&ext_name);

      udt->scl_ext_lang = (int) tree->_.type.ext_def->_.ext_def.language;
      udt->scl_ext_name = box_dv_short_string (int_name ? int_name : ext_name);
      if (imp_map[udt->scl_ext_lang].scli_instantiate_class == NULL)
	{
	  caddr_t err = srv_make_new_error ("37000", "UD017",
	      "Class %.200s declared of external language %s, which is not supported by the current binary",
	      udt->scl_name, udt_language_name (udt->scl_ext_lang));
	  if (err_ret)
	    {
	      *err_ret = err;
	      return udt;
	    }
	  else
	    sqlr_resignal (err);
	}
    }
  else
    udt->scl_ext_lang = UDT_LANG_SQL;
  if (old_udt && old_udt->scl_ext_lang != udt->scl_ext_lang)
    {
      caddr_t err = srv_make_new_error ("37000", "UD017",
	  "Class %.200s declared of different language from it's forward declaration",
	  udt->scl_name);
      if (err_ret)
	{
	  *err_ret = err;
	  return udt;
	}
      else
	sqlr_resignal (err);
    }

  if (tree->_.type.parent)
    {
      udt->scl_super = sch_name_to_type (sc, tree->_.type.parent);
      if (NULL == udt->scl_super)
	{
	  if (store_in_hash)
	    {
	      udt->scl_super = udt_store_forward_reference (tree->_.type.parent,
		  sc, cli, udt);
	    }
	}
      else
	{
	  if (udt->scl_ext_lang != udt->scl_super->scl_ext_lang)
	    {
	      caddr_t err = srv_make_new_error ("37000", "UD018",
		  "Class %.200s declared of different language from it's superclass %.200s",
		  udt->scl_name, udt->scl_super->scl_name);
	      if (err_ret)
		{
		  *err_ret = err;
		  return udt;
		}
	      else
		sqlr_resignal (err);
	    }
	  if (cli->cli_user &&
	      !sec_udt_check (udt->scl_super, cli->cli_user->usr_g_id,
		cli->cli_user->usr_id, GR_UDT_UNDER))
	    {
	      caddr_t err = srv_make_new_error ("42000", "UD096:SECURITY",
		  "No permission to use type %.200s as a superclass for %.200s",
		  udt->scl_super->scl_name, udt->scl_name);
	      if (err_ret)
		{
		  *err_ret = err;
		  return udt;
		}
	      else
		sqlr_resignal (err);
	    }
	}
    }
  udt_compile_class_representation (sc, udt, tree, err_ret, store_in_hash, cli);
  if (err_ret && *err_ret)
    return udt;
  udt_compile_class_methods (sc, udt, tree, err_ret, store_in_hash, cli);

  DO_BOX (ST *, opt, inx, ((ST **)tree->_.type.options))
    {
      if (ST_P (opt, UDT_REFCAST) && BOX_ELEMENTS (opt) == 2)
	switch ((ptrlong) ((caddr_t *)opt)[1])
	  {
	    case 0: udt->scl_self_as_ref = 1; break;
	    case 1: udt->scl_mem_only = 1; break;
	  }
      else if (ST_P (opt, UDT_SOAP))
	{
	  udt->scl_soap_type = box_dv_short_string (((caddr_t *)opt)[1]);
	}
      else if (ST_P (opt, UDT_UNRESTRICTED))
	udt->scl_sec_unrestricted = 1;

    }
  END_DO_BOX;
  if (udt->scl_super)
    {
      if (udt->scl_super->scl_defined && udt->scl_super->scl_mem_only != udt->scl_mem_only)
	{
	  *err_ret = srv_make_new_error ("37000", "UD019",
	      "Can't make a %s subclass %.200s of a %s class %.200s",
	      udt->scl_mem_only ? "TEMPORARY" : "PERSISTENT", udt->scl_name,
	      udt->scl_super->scl_mem_only ? "TEMPORARY" : "PERSISTENT", udt->scl_super->scl_name);
	  return udt;
	}
    }
  udt->scl_defined = 1;
  return udt;
}


sql_class_t *
udt_alloc_class_def (caddr_t name)
{
  char q[MAX_NAME_LEN];
  char o[MAX_NAME_LEN];
  char n[MAX_NAME_LEN];
  char qn[2 * MAX_NAME_LEN + 1];
  sql_class_t * udt = (sql_class_t *)dk_alloc_box_zero (sizeof(sql_class_t), DV_ARRAY_OF_LONG); /* Leak on VSPX recompilation */

  udt->scl_name = box_dv_short_string (name); /* Leak on VSPX recompilation */
  sch_split_name (cli_qual (sqlc_client ()), name, q, o, n);
  udt->scl_qualifier = box_dv_short_string (q); /* Leak on VSPX recompilation */
  udt->scl_owner = box_dv_short_string (o); /* Leak on VSPX recompilation */
  udt->scl_name_only = &udt->scl_name[strlen (udt->scl_name) - strlen (n)];
  snprintf (qn, sizeof (qn), "%s.%s", udt->scl_qualifier, udt->scl_name_only);
  udt->scl_qualifier_name = box_dv_short_string (qn); /* Leak on VSPX recompilation */
  return udt;
}


void
udt_free_internals_of_class_def (sql_class_t * udt)
{
  int mtd_inx = UDT_N_METHODS (udt);
  int fld_inx = UDT_N_FIELDS (udt);
  if (mtd_inx > 0)
    {
      sql_method_t *methods = udt->scl_methods;
      dk_free_box ((box_t) udt->scl_method_map);
      udt->scl_method_map = (sql_method_t **) list(0);
      udt->scl_methods = (sql_method_t *) list(0);
      while (mtd_inx--)
	{
#ifdef QUERY_DEBUG
      log_query_event (methods[mtd_inx].scm_qr, 1, "DEPRECATION by udt_free_internals_of_class_def()");
#endif
	  dk_free_box (methods[mtd_inx].scm_name);
	  dk_free_box (methods[mtd_inx].scm_specific_name);
	  dk_free_tree ((box_t) methods[mtd_inx].scm_param_names);
	  dk_free_box ((box_t) methods[mtd_inx].scm_signature);
	  dk_free_box (methods[mtd_inx].scm_ext_name);
	  dk_free_box (methods[mtd_inx].scm_ext_type);
	  dk_free_tree ((box_t) methods[mtd_inx].scm_param_ext_types);
	  dk_set_pushnew (&global_old_procs, methods[mtd_inx].scm_qr);
	}
      dk_free_box ((box_t) methods);
      udt->scl_methods = NULL;
    }
  if (fld_inx > 0)
    {
      sql_field_t *fields = udt->scl_fields;
      dk_free_box ((box_t) udt->scl_member_map);
      udt->scl_member_map = (sql_field_t **) list(0);
      udt->scl_fields = (sql_field_t *) list(0);
      while (fld_inx--)
	{
	  dk_free_box (fields[fld_inx].sfl_name);
	  dk_free_box (fields[fld_inx].sfl_default);
	  dk_free_box (fields[fld_inx].sfl_ext_name);
	  dk_free_box (fields[fld_inx].sfl_ext_type);
	  dk_free_box (fields[fld_inx].sfl_soap_type);
	  dk_free_box (fields[fld_inx].sfl_soap_name);
	}
      dk_free_box ((box_t) fields);
      udt->scl_fields = NULL;
    }
}

void
udt_free_class_def (sql_class_t * udt)
{
  udt_free_internals_of_class_def (udt);

#if 0
/* !!! Stub for GPF in udttest.sql */
  dk_free_box (udt->scl_name);
  dk_free_box (udt->scl_qualifier);
  dk_free_box (udt->scl_qualifier_name);
  dk_free_box (udt->scl_owner);
  dk_free_box (udt->scl_ext_name);
  dk_free_box (udt->scl_soap_type);
  /*dk_free_box (udt->scl_sec_unrestricted);*/
  dk_free_box ((box_t) udt->scl_fields);
  dk_free_box ((box_t) udt->scl_methods);
  dk_free_box ((box_t) udt->scl_method_map);
  dk_free_box ((box_t) udt->scl_member_map);
  if (udt->scl_name_to_method)
    id_hash_free (udt->scl_name_to_method);
  dk_free_box (udt);
#endif

  return;
}

#ifdef UDT_HASH_DEBUG
static void
dbg_udt_print_id_hash_entry (const void *key, void *data)
{
  long id_pk = (long) (ptrlong) key;
  sql_class_t * cls = (sql_class_t *) data;

  fprintf (stderr, "class [id:%ld] [%p] [%s] [%ld] lang:%d inst:%d def:%d mem:%d\n",
      (long) id_pk, cls, cls->scl_name, cls->scl_id,
      cls->scl_ext_lang, cls->scl_method_map ? 1 : 0, cls->scl_defined, cls->scl_mem_only);
}


void
dbg_udt_print_class_hash (dbe_schema_t *sc, char *msg, char *udt_name)
{
  char **pk;

  sql_class_t **pcls;
  id_hash_iterator_t it;

  fprintf (stderr, "\n------ [%s]: %s -----\n", udt_name ? udt_name : "", msg);
  id_hash_iterator (&it, sc->sc_name_to_type);
  while (hit_next (&it, (caddr_t *) & pk, (caddr_t *) & pcls))
    {
      sql_class_t *cls = *pcls;
      fprintf (stderr, "class [%s] [%p] [%s] [%ld] lang:%d inst:%d def:%d mem:%d\n", *pk, cls, cls->scl_name,
	  cls->scl_id,
	  cls->scl_ext_lang, cls->scl_method_map ? 1 : 0, cls->scl_defined, cls->scl_mem_only);
    }
  fprintf (stderr, "****** [%s]: %s *****\n", udt_name ? udt_name : "", msg);
  fprintf (stderr, "++++++ [%s]: %s +++++\n", udt_name ? udt_name : "", msg);
  maphash (dbg_udt_print_id_hash_entry, sc->sc_id_to_type);
  fprintf (stderr, "###### [%s]: %s #####\n", udt_name ? udt_name : "", msg);
}
#endif


void
udt_exec_class_def (query_instance_t * qi, ST * _tree)
{
  UST *tree = (UST *) _tree;
  dbe_schema_t *sc = isp_schema (NULL);
  client_connection_t *cli = qi->qi_client;
  local_cursor_t *lc;
  sql_class_t *udt;
  caddr_t err = NULL;

  dbg_udt_print_class_hash (isp_schema (NULL), "before exec udt", tree->_.type.name);

  qr_rec_exec (udt_read_qr, cli, &lc, qi, NULL, 1,
      ":0", tree->_.type.name, QRP_STR);
  if (lc_next (lc))
    {
      lc_free (lc);
      sqlr_new_error ("42S01", "UD020", "Type %s already exists",
	  tree->_.type.name);
      return;
    }
  lc_free (lc);
  udt = udt_compile_class_def (sc, (caddr_t) tree, NULL, &err, 0, cli, 0, 0);
  if (err)
    {
      if (udt)
	udt_free_class_def (udt);
      sqlr_resignal (err);
    }
/*  udt_try_instantiable (sc, udt, &err);
  if (err)
    {
      if (udt)
	udt_free_class_def (udt);
      sqlr_resignal (err);
    }*/
  if (udt->scl_mem_only)
    {
      ddl_type_changed (qi, tree->_.type.name, NULL, (caddr_t) tree);
      udt_free_class_def (udt);
    }
  else
    {
      AS_DBA (qi, qr_rec_exec (udt_add_qr, cli, NULL, qi, NULL, 2, ":0", tree->_.type.name,
	  QRP_STR, ":1", box_copy_tree ((box_t) tree), QRP_RAW));
      ddl_type_changed (qi, tree->_.type.name, NULL, NULL);
      udt_free_class_def (udt);
    }
  dbg_udt_print_class_hash (isp_schema (NULL), "end exec udt", tree->_.type.name);
}


static void
udt_drop_obsoleted_types (query_instance_t * qi, sql_class_t *udt)
{
  static query_t *select_qr = NULL, *drop_qr = NULL;
  client_connection_t *cli = qi->qi_client;
  char subtype_name [MAX_QUAL_NAME_LEN];
  local_cursor_t *lc = NULL;
  caddr_t err = NULL;

  if (!select_qr)
    {
      select_qr = sql_compile (
	  "select UT_ID, UT_NAME from DB.DBA.SYS_USER_TYPES where UT_NAME like ? and UT_MIGRATE_TO is not null",
	  bootstrap_cli, &err, SQLC_DEFAULT);
      if (err)
	sqlr_resignal (err);
    }
  if (!drop_qr)
    {
      drop_qr = sql_compile (
	  "delete from DB.DBA.SYS_USER_TYPES where UT_ID = ?",
	  bootstrap_cli, &err, SQLC_DEFAULT);
      if (err)
	sqlr_resignal (err);
    }
  snprintf (subtype_name, sizeof (subtype_name), "%.300s__%%", udt->scl_name);
  err = qr_rec_exec (select_qr, cli, &lc, qi, NULL, 1,
      ":0", subtype_name, QRP_STR);
  if (err)
    {
      LC_FREE (lc);
      sqlr_resignal (err);
    }
  while (lc_next (lc))
    {
      long id = (long) unbox (lc_nth_col (lc, 0));
      caddr_t name = lc_nth_col (lc, 1);
      err = qr_quick_exec (drop_qr, cli, NULL, NULL, 1,
	  ":0", (ptrlong) id, QRP_INT);
      ddl_type_changed (qi, name, NULL, NULL);
    }
  lc_free (lc);
}


static sql_class_t *
udt_is_supertype_of_any (sql_class_t *udt)
{
  dbe_schema_t *sc = isp_schema (NULL);
  sql_class_t **pcls;
  id_casemode_hash_iterator_t it;
  id_casemode_hash_iterator (&it, sc->sc_name_to_object[sc_to_type]);
  while (id_casemode_hit_next (&it, (caddr_t *) & pcls))
    {
      if (pcls && *pcls && (*pcls)->scl_super == udt)
	return (*pcls);
    }
  return NULL;
}

void
udt_drop_class_def (query_instance_t * qi, ST * _tree)
{
  UST *tree = (UST *) _tree;
  client_connection_t *cli = qi->qi_client;
  caddr_t err = NULL;
  sql_class_t *udt =
      sch_name_to_type (isp_schema (NULL), tree->_.drop_udt.name);
  sql_class_t *sub_udt;

  dbg_udt_print_class_hash (isp_schema (NULL), "before drop udt", tree->_.drop_udt.name);
  if (!udt)
    sqlr_new_error ("42000", "UD021", "No user defined class %.200s", tree->_.drop_udt.name);
  if (NULL != (sub_udt = udt_is_supertype_of_any (udt)))
    sqlr_new_error ("42000", "UD080",
	"User defined type %s is a super type at least of %s. "
	"Drop it and any other such types first.", tree->_.drop_udt.name, sub_udt->scl_name);

  if (tree->_.drop_udt.drop_behaviour == 2
      && udt_is_qr_used (udt->scl_name))
    sqlr_new_error ("42000", "UD022",
	"Type %s is used in one or more compiled queries. Drop them first",
	udt->scl_name);
  if (!udt_drop_methods_qr)
    {
      udt_drop_methods_qr = sql_compile (
	  "delete from DB.DBA.SYS_METHODS where M_ID in "
	  "(SELECT UT_ID from DB.DBA.SYS_USER_TYPES where UT_NAME = ?)",
	  bootstrap_cli, &err, SQLC_DEFAULT);
      if (err)
	sqlr_resignal (err);
    }
  if (!udt_drop_grants_qr)
    {
      udt_drop_grants_qr = sql_compile (
	  "delete from DB.DBA.SYS_GRANTS where G_OBJECT = ?",
	  bootstrap_cli, &err, SQLC_DEFAULT);
      if (err)
	sqlr_resignal (err);
    }
  if (!udt->scl_mem_only)
    {
      err =
	  qr_rec_exec (udt_drop_methods_qr, cli, NULL, qi, NULL, 1, ":0",
	      udt->scl_name, QRP_STR);
      if (err)
	sqlr_resignal (err);
      err =
	  qr_rec_exec (udt_drop_grants_qr, cli, NULL, qi, NULL, 1, ":0",
	     udt->scl_name, QRP_STR);
      if (err)
	sqlr_resignal (err);
      err =
	  qr_rec_exec (udt_drop_qr, cli, NULL, qi, NULL, 1, ":0",
	     udt->scl_name, QRP_STR);
      if (err)
	sqlr_resignal (err);
    }

  if (udt->scl_defined)
    ddl_type_changed (qi, tree->_.drop_udt.name, NULL, NULL);

  if (!udt->scl_migrate_to)
    udt_drop_obsoleted_types (qi, udt);

/* IvAn/UdtRedefLeak/040211 Minimization of the leak */
  if (udt->scl_defined)
    {
      udt->scl_obsolete = 1;
      dbg_printf (("UDT %s is made obsolete by udt_drop_class_def()\n", udt->scl_name));
      udt_free_internals_of_class_def (udt);
      srv_add_background_task ((srv_background_task_t) udt_free_class_def, udt);
    }
/* IvAn/UdtRedefLeak/040211 **/

  dbg_udt_print_class_hash (isp_schema (NULL), "after drop udt", tree->_.drop_udt.name);
}


sql_class_t *
sch_name_to_type (dbe_schema_t * sc, const char *name)
{
  sql_class_t *cls;
  client_connection_t *cli = sqlc_client ();
  char *o_default;
  char *q_default;
  if (!cli)
    cli = bootstrap_cli;
  if (cli)
    o_default = CLI_OWNER (cli);
  else
    o_default = "DBA";
  q_default = cli_qual (cli);
  cls = (sql_class_t *) sch_name_to_object (sc, sc_to_type, name, q_default, o_default, 1);
  if ((sql_class_t *) - 1L == cls)
    return NULL;
  return cls;
}


/* When inside udt_exec_class_def, \c fresh_udt is a type description that is made by current definition.
If \c udt_name maps to \c udt that is equal to \c fresh udt then there's no need to make \c udt obsolete
and to remove from sc->sc_name_to_object[sc_to_type] because id_casemode_hash_set will reverse the
operation soon */
static void
sch_drop_type (dbe_schema_t * sc, char *udt_name, sql_class_t *fresh_udt)
{
  sql_class_t *udt = sch_name_to_type (sc, udt_name);
  if (NULL == udt)
    return; /* It's been deleted or never exists. Hence nothing to do */
  if (udt->scl_defined)
    {
      if (fresh_udt != udt)
	{
	  dk_set_t childs = NULL;
	  id_casemode_hash_iterator_t it;
	  sql_class_t **pcls;
	  id_casemode_hash_iterator (&it, sc->sc_name_to_object[sc_to_type]);
	  while (id_casemode_hit_next (&it, (caddr_t *) & pcls))
	    {
	      sql_class_t *cls = *pcls;
	      if (udt != cls->scl_super)
	        continue;
	      dk_set_push (&childs, cls);
	    }
	  while (NULL != childs)
	    {
	      sql_class_t *child = (sql_class_t *) dk_set_pop (&childs);
	      sch_drop_type (sc, child->scl_name, NULL);
	    }
	}
      if (fresh_udt != udt)
        {
          udt->scl_obsolete = 1;
	  dbg_printf (("UDT %s is made obsolete by udt_drop_type()\n", udt->scl_name));
#if defined (PURIFY) || defined (VALGRIND)
	  dk_set_push (&sc->sc_old_types, udt);
#else
	  srv_add_background_task ((srv_background_task_t) udt_free_class_def, udt);
#endif
	}
      id_casemode_hash_remove (sc->sc_name_to_object[sc_to_type],
	  udt->scl_qualifier_name, udt->scl_owner);
    }
  if (udt->scl_id)
    remhash ((void *) (ptrlong) udt->scl_id, sc->sc_id_to_type);
  udt_mark_affected (udt_name);
}


static void
udt_read_methods_qrs (sql_class_t *udt, caddr_t *err_ret, query_instance_t *qi, dbe_schema_t *sc)
{
  static query_t *rdproc = NULL;
  local_cursor_t *lc = NULL;
  user_t *org_user;
  caddr_t org_qual;
  dbe_schema_t *org_schema;

  if (!udt || !udt->scl_id)
    return;

  if (!rdproc)
    {
      rdproc = sql_compile (
	  "select blob_to_string (M_TEXT), M_QUAL, M_OWNER from DB.DBA.SYS_METHODS where M_ID = ?",
	  bootstrap_cli, err_ret, SQLC_DEFAULT);
      if (!rdproc)
	return;
    }
  *err_ret = qr_rec_exec (rdproc, bootstrap_cli, &lc, qi, NULL, 1,
      ":0", (ptrlong) (udt->scl_id - 1), QRP_INT);
  if (*err_ret)
    {
      LC_FREE (lc);
      return;
    }
  org_user = bootstrap_cli->cli_user;
  org_qual = bootstrap_cli->cli_qualifier;
  org_schema = bootstrap_cli->cli_new_schema;
  CLI_QUAL_ZERO (bootstrap_cli);
  while (lc_next (lc))
    {
      caddr_t m_text = lc_nth_col (lc, 0);
      caddr_t qual = lc_nth_col (lc, 1);
      caddr_t owner = lc_nth_col (lc, 2);
      user_t *owner_user = sec_name_to_user (owner);
      if (owner_user)
	bootstrap_cli->cli_user = owner_user;
      else
	{
	  *err_ret = srv_make_new_error ("42000", "UD062",
	      "Method with bad owner, owner =  %s", owner);
	  bootstrap_cli->cli_user = org_user;
	  CLI_RESTORE_QUAL (bootstrap_cli, org_qual);
	  bootstrap_cli->cli_new_schema = org_schema;
	  lc_free (lc);
	  return;
	}
      CLI_SET_QUAL (bootstrap_cli, qual);
      bootstrap_cli->cli_new_schema = sc;
      sql_compile (m_text, bootstrap_cli, err_ret, SQLC_DO_NOT_STORE_PROC);
      if (*err_ret)
	{
	  lc_free (lc);
	  bootstrap_cli->cli_user = org_user;
	  CLI_RESTORE_QUAL (bootstrap_cli, org_qual);
	  bootstrap_cli->cli_new_schema = org_schema;
	  return;
	}
    }
  bootstrap_cli->cli_user = org_user;
  CLI_RESTORE_QUAL (bootstrap_cli, org_qual);
  bootstrap_cli->cli_new_schema = org_schema;
  lc_free (lc);
}


static caddr_t
qi_read_type_schema_1 (query_instance_t * qi, char *read_udt,
    dbe_schema_t * sc, sql_class_t *udt)
{
  caddr_t err = NULL;
  lock_trx_t * lt = qi->qi_trx;

  sch_drop_type (sc, read_udt, udt);
  if (!udt)
    {
      local_cursor_t *lc = NULL;
      err = qr_rec_exec (udt_read_qr, qi->qi_client, &lc, qi, NULL, 1,
	  ":0", read_udt, QRP_STR);

      if (err)
        {
          LC_FREE (lc);
          return err;
        }
      /* make */
      while (lc_next (lc))
	{
	  caddr_t udt_name =
	      sch_complete_table_name (box_copy (lc_nth_col (lc, 0)));
	  caddr_t udt_parse_tree = lc_nth_col (lc, 1);
	  long udt_id = unbox_or_null (lc_nth_col (lc, 2)) + 1;
	  long udt_migrate_to =
	      DV_TYPE_OF (lc_nth_col (lc, 3)) == DV_DB_NULL ? 0 :
	      (unbox_or_null (lc_nth_col (lc, 3)) + 1);
	  sql_class_t *new_udt;
	  udt = sch_name_to_type (sc, udt_name);

	  dk_free_box (udt_name);
	  new_udt = udt_compile_class_def (sc, udt_parse_tree, udt, &err, 1, qi->qi_client, udt_id, udt_migrate_to);
	  if (err)
	    {
	      lc_free (lc);
	      return err;
	    }
	  new_udt->scl_id = udt_id;
	  new_udt->scl_migrate_to = udt_migrate_to;
	  if (new_udt != udt)
	    {
	      id_casemode_hash_set (sc->sc_name_to_object[sc_to_type],
		  new_udt->scl_qualifier_name, new_udt->scl_owner,
		  (caddr_t) & new_udt);
	    }
	  udt_try_instantiable (sc, new_udt, &err);
	  if (err)
	    {
	      lc_free (lc);
	      return err;
	    }
	  /* was udt_read_methods_qrs, moved outside, after commit */
	  udt = new_udt;
	}
      err = lc->lc_error;
      lc_free (lc);
      if (err)
	return err;
    }
  else
    {
      id_casemode_hash_set (sc->sc_name_to_object[sc_to_type],
	  udt->scl_qualifier_name, udt->scl_owner,
	  (caddr_t) & udt);
      udt_try_instantiable (sc, udt, &err);
      if (err)
	return err;
    }
  if (udt)
    {
      dk_set_t derived_set = udt_get_derived_classes (sc, udt);
      DO_SET (sql_class_t *, sudt, &derived_set)
	{
	  udt_try_instantiable (sc, sudt, &err);
	}
      END_DO_SET();
      dk_set_free (derived_set);
    }
  if (!err)
    err = it_read_object_dd (lt, sc);
  if (err)
    return err;
  if (!udt)
    return NULL;
  err = sec_read_grants (qi->qi_client, qi, read_udt, 0);
  return err;
}


static void
qi_read_type_schema (query_instance_t * qi, char *read_udt, sql_class_t *udt, caddr_t tree)
{
  caddr_t err;
  lock_trx_t *lt = qi->qi_trx;
  dbe_schema_t *sc = wi_inst.wi_schema;

  lt->lt_pending_schema = dbe_schema_copy (sc);
  if (tree)
    {
      udt = udt_compile_class_def (lt->lt_pending_schema, tree,
	  sch_name_to_type (lt->lt_pending_schema, ((UST *)tree)->_.type.name),
	  &err, 1, qi->qi_client, 0, 0);
    }
  err = qi_read_type_schema_1 (qi, read_udt, lt->lt_pending_schema, udt);
  if (!qi->qi_trx->lt_branch_of && !qi->qi_client->cli_in_daq)
    {
      if (!qi->qi_client->cli_is_log)
	cl_ddl (qi, qi->qi_trx, read_udt, CLO_DDL_TYPE, NULL);
    }

  if (!udt && !err)
    {
      sql_class_t *new_udt;
      /* before we read methods do a commit to have udt in the commit schema */
      ddl_commit_trx (qi);
      sc = wi_inst.wi_schema;
      new_udt = sch_name_to_type (sc, read_udt);
      udt_read_methods_qrs (new_udt, &err, qi, sc);
    }

  if (err)
    sqlr_resignal (err);
  ddl_commit_trx (qi);
}


void
ddl_type_changed (query_instance_t * qi, char *full_type_name, sql_class_t *udt, caddr_t tree)
{
  qi_read_type_schema (qi, full_type_name, udt, tree);
  log_dd_type_change (qi->qi_trx, full_type_name, tree);
}

static sql_class_t *udt_serialization_error_udt;


caddr_t
udt_serialization_error_dv (char *name)
{
  caddr_t ret = dk_alloc_box (2 * sizeof (caddr_t), DV_OBJECT);
  UDT_I_CLASS (ret) = udt_serialization_error_udt;
  UDT_I_VAL (ret, 0) = box_dv_short_string (name);
  return ret;
}


void
udt_ensure_init (client_connection_t * cli)
{
  caddr_t err = NULL;
  static char udt_add_text[] =
      "insert into DB.DBA.SYS_USER_TYPES (UT_NAME, UT_PARSE_TREE) "
      "values (?, serialize (?))";

  static char udt_sel_text[] =
      "select UT_NAME, deserialize (blob_to_string (UT_PARSE_TREE)), UT_ID, UT_MIGRATE_TO "
      "from DB.DBA.SYS_USER_TYPES where UT_NAME = ?";

  static char udt_del_text[] =
      "delete from DB.DBA.SYS_USER_TYPES where UT_NAME = ?";

  static char udt_get_tree_by_id_text[] =
      "select deserialize (blob_to_string (UT_PARSE_TREE)) from DB.DBA.SYS_USER_TYPES "
      " where UT_NAME = ? and UT_ID = ?";

  static char udt_tree_update_text[] =
      "update DB.DBA.SYS_USER_TYPES set UT_PARSE_TREE = serialize (?) where UT_NAME = ?";

  static char udt_modified_proc_text[] =
      "create procedure DB.DBA.__type_modified (in type_id integer, "
                                              "in type_name varchar, in tree any, "
					      "in old_type_name varchar, in old_tree any) "
      " { "
      "   declare _new_id integer; "
      "   update DB.DBA.SYS_USER_TYPES set UT_NAME = old_type_name, UT_PARSE_TREE = serialize (old_tree) "
      "        where UT_ID = type_id; "
      "   insert into DB.DBA.SYS_USER_TYPES (UT_NAME, UT_PARSE_TREE) "
      "        values (type_name, serialize (tree)); "
      "   _new_id := identity_value(); "
      "   update DB.DBA.SYS_USER_TYPES set UT_MIGRATE_TO = _new_id "
      "        where UT_ID = type_id; "
      "   return _new_id; "
      " }";

  static char udt_mark_tb_affected_proc_text[] =
      "create procedure DB.DBA.__type_mark_tb_affected (in type_name varchar) "
      "  { "
      "    for select distinct \"TABLE\" _tb from DB.DBA.SYS_COLS "
      "           where get_keyword ('sql_class', coalesce (COL_OPTIONS, vector())) = type_name do "
      "      { "
/*      "        dbg_obj_print ('marking', _tb); "*/
      "         __ddl_changed (_tb); "
      "      } "
      "  }";

  static char udt_replace_text[] =
      "select DB.DBA.__type_modified (?, ?, ?, ?, ?)";

  static char udt_mark_tb_affected_text[] =
      "select DB.DBA.__type_mark_tb_affected (?)";

  udt_add_qr = sql_compile (udt_add_text, cli, &err, SQLC_DEFAULT);
  if (err)
    GPF_T;
  udt_read_qr = sql_compile (udt_sel_text, cli, &err, SQLC_DEFAULT);
  if (err)
    GPF_T;
  udt_drop_qr = sql_compile (udt_del_text, cli, &err, SQLC_DEFAULT);
  if (err)
    GPF_T;
  ddl_ensure_table ("the object serialization error",
      "create type SYS_SERIALIZATION_ERROR as (SE_NAME varchar default NULL) temporary");
  udt_serialization_error_udt = sch_name_to_type (isp_schema(NULL), "DB.DBA.SYS_SERIALIZATION_ERROR");
  udt_serialization_error_udt->scl_id = -10;
  sethash ((void *) (ptrlong) udt_serialization_error_udt->scl_id,
      isp_schema(NULL)->sc_id_to_type, (void *) udt_serialization_error_udt);
  udt_get_tree_by_id_qr = sql_compile (udt_get_tree_by_id_text, cli, &err, SQLC_DEFAULT);
  if (err)
    GPF_T;
  ddl_std_proc (udt_modified_proc_text, 1);
  ddl_std_proc (udt_mark_tb_affected_proc_text, 1);
  udt_replace_qr = sql_compile (udt_replace_text, cli, &err, SQLC_DEFAULT);
  if (err)
    GPF_T;
  udt_tree_update_qr = sql_compile (udt_tree_update_text, cli, &err, SQLC_DEFAULT);
  if (err)
    GPF_T;
  udt_mark_tb_affected_qr = sql_compile (udt_mark_tb_affected_text, cli, &err, SQLC_DEFAULT);
  if (err)
    GPF_T;
}


static int
udt_class_castable_to (sql_class_t * udt, sql_type_t * sqt)
{
  if (UDT_IS_DISTINCT (udt)
      && -1 != udt_sqt_distance (&(udt->scl_fields[0].sfl_sqt), sqt))
    return 1;
  else
    return 0;
}


static int
udt_class_castable_from (sql_class_t * udt, sql_type_t * sqt)
{
  if (UDT_IS_DISTINCT (udt)
      && -1 != udt_sqt_distance (sqt, &(udt->scl_fields[0].sfl_sqt)))
    return 1;
  else
    return 0;
}


static int
udt_sqt_distance (sql_type_t * sqtv, sql_type_t * sqtp)
{				/* sqtv => sqt of the value sqtp =>sqt of the place */
  if (sqtv->sqt_dtp == sqtp->sqt_dtp)
    {
      switch (sqtv->sqt_dtp)
	{
	case DV_OBJECT:
	  if (!sqtv->sqt_class)
	    {
	      if (!sqtp->sqt_class)
		return 0;
	      else
		return -1;
	    }
	  if (UDT_IS_SAME_CLASS (sqtv->sqt_class, sqtp->sqt_class))
	    return 0;
	  else if (udt_instance_of (sqtv->sqt_class, sqtp->sqt_class))
	    return 1;
	  else if (udt_instance_of (sqtp->sqt_class, sqtv->sqt_class))
	    return 2; /* GK : TODO: this is a bit of a hack :
			 allow base class values to be supplied to parameters of derived classes.
			 But until we have a real typecast (no actual conversion, just check :
			 something like ((derived)base_val)) we are better off with the hack */
	  else if (udt_class_castable_to (sqtv->sqt_class, sqtp))
	    return 3;
	  else
	    return -1;
	case DV_ARRAY_OF_POINTER:
	  if (sqtv->sqt_precision == sqtp->sqt_precision &&
	      DVC_MATCH == cmp_boxes ((caddr_t)sqtv->sqt_tree, (caddr_t)sqtp->sqt_tree, NULL, NULL))
	    return 0;
	default:
	  if (!memcmp (sqtv, sqtp, sizeof (sql_type_t)))
	    return 0;
	  else if (!sqtp->sqt_precision || !sqtv->sqt_precision ||
	      sqtv->sqt_precision <= sqtp->sqt_precision)
	    return 1;
	  else if (!sqtv->sqt_scale || !sqtv->sqt_scale ||
	      sqtv->sqt_scale <= sqtp->sqt_scale)
	    return 1;
	  else
	    return -1;
	}
    }
  else
    {
      if (sqtv->sqt_dtp == DV_OBJECT)
	{
	  if (sqtp->sqt_dtp == DV_ANY)
	    return 2;
	  else if (!sqtv->sqt_class)
	    return -1;
	  else if (udt_class_castable_to (sqtv->sqt_class, sqtp))
	    return 3;
	  else
	    return -1;
	}
      else if (sqtp->sqt_dtp == DV_OBJECT)
	{
	  if (sqtp->sqt_dtp == DV_ANY)
	    return 2;
	  if (!sqtv->sqt_class)
	    return -1;
	  else if (udt_class_castable_from (sqtp->sqt_class, sqtv))
	    return 3;
	  else
	    return -1;
	}
      else if (sqtv->sqt_dtp == DV_DB_NULL)
	return 2;
      else if (sqtv->sqt_dtp == DV_ANY)
	{
	  return 2;
	}
      else if (sqtv->sqt_dtp == DV_UNKNOWN)
	{
	  return 2;
	}
      else
	{
	  switch (sqtp->sqt_dtp)
	    {
	    case DV_LONG_CONT_STRING:
	    case DV_SHORT_CONT_STRING:
	    case DV_SYMBOL:
	    case DV_STRING:
	    case DV_C_STRING:
	    case DV_WIDE:
	    case DV_LONG_WIDE:
	      if (sqtv->sqt_dtp == DV_SHORT_INT ||
		  sqtv->sqt_dtp == DV_LONG_INT ||
		  sqtv->sqt_dtp == DV_SINGLE_FLOAT ||
		  sqtv->sqt_dtp == DV_DOUBLE_FLOAT ||
		  sqtv->sqt_dtp == DV_STRING_SESSION ||
		  sqtv->sqt_dtp == DV_NUMERIC ||
		  sqtv->sqt_dtp == DV_STRING ||
		  sqtv->sqt_dtp == DV_C_STRING ||
		  sqtv->sqt_dtp == DV_LONG_CONT_STRING ||
		  sqtv->sqt_dtp == DV_SHORT_CONT_STRING ||
		  sqtv->sqt_dtp == DV_SYMBOL ||
		  sqtv->sqt_dtp == DV_DATETIME ||
		  sqtv->sqt_dtp == DV_BIN ||
		  sqtv->sqt_dtp == DV_WIDE ||
		  sqtv->sqt_dtp == DV_LONG_WIDE ||
		  sqtv->sqt_dtp == DV_BLOB_HANDLE ||
		  sqtv->sqt_dtp == DV_BLOB_WIDE_HANDLE ||
		  sqtv->sqt_dtp == DV_XML_ENTITY ||
		  sqtv->sqt_dtp == DV_ARRAY_OF_XQVAL)
		return 3;
	      else
		return -1;

	    case DV_SHORT_INT:
	    case DV_LONG_INT:
	      if (sqtv->sqt_dtp == DV_SHORT_INT ||
		  sqtv->sqt_dtp == DV_LONG_INT ||
		  sqtv->sqt_dtp == DV_SINGLE_FLOAT ||
		  sqtv->sqt_dtp == DV_DOUBLE_FLOAT ||
		  sqtv->sqt_dtp == DV_NUMERIC ||
		  sqtv->sqt_dtp == DV_STRING ||
		  sqtv->sqt_dtp == DV_WIDE || sqtv->sqt_dtp == DV_LONG_WIDE)
		return 3;
	      else
		return -1;

	    case DV_SINGLE_FLOAT:
	      if (sqtv->sqt_dtp == DV_LONG_INT ||
		  sqtv->sqt_dtp == DV_DOUBLE_FLOAT ||
		  sqtv->sqt_dtp == DV_STRING ||
		  sqtv->sqt_dtp == DV_NUMERIC ||
		  sqtv->sqt_dtp == DV_WIDE || sqtv->sqt_dtp == DV_LONG_WIDE)
		return 3;
	      else
		return -1;

	    case DV_DOUBLE_FLOAT:
	      if (sqtv->sqt_dtp == DV_LONG_INT ||
		  sqtv->sqt_dtp == DV_SINGLE_FLOAT ||
		  sqtv->sqt_dtp == DV_DOUBLE_FLOAT ||
		  sqtv->sqt_dtp == DV_STRING ||
		  sqtv->sqt_dtp == DV_NUMERIC ||
		  sqtv->sqt_dtp == DV_WIDE || sqtv->sqt_dtp == DV_LONG_WIDE)
		return 3;
	      else
		return -1;

	    case DV_NUMERIC:
	      if (sqtv->sqt_dtp == DV_LONG_INT ||
		  sqtv->sqt_dtp == DV_SINGLE_FLOAT ||
		  sqtv->sqt_dtp == DV_DOUBLE_FLOAT ||
		  sqtv->sqt_dtp == DV_STRING ||
		  sqtv->sqt_dtp == DV_WIDE || sqtv->sqt_dtp == DV_LONG_WIDE)
		return 3;
	      else
		return -1;

	    case DV_DATETIME:
	    case DV_DATE:
	    case DV_TIMESTAMP:
	      if (sqtv->sqt_dtp == DV_STRING ||
		  sqtv->sqt_dtp == DV_DATE ||
		  sqtv->sqt_dtp == DV_DATETIME ||
		  sqtv->sqt_dtp == DV_TIME ||
		  sqtv->sqt_dtp == DV_TIMESTAMP ||
		  sqtv->sqt_dtp == DV_WIDE || sqtv->sqt_dtp == DV_LONG_WIDE)
		return 3;
	      else
		return -1;

	    case DV_TIME:
	      if (sqtv->sqt_dtp == DV_STRING ||
		  sqtv->sqt_dtp == DV_DATETIME ||
		  sqtv->sqt_dtp == DV_TIMESTAMP ||
		  sqtv->sqt_dtp == DV_WIDE || sqtv->sqt_dtp == DV_LONG_WIDE)
		return 3;
	      else
		return -1;

	    case DV_BIN:
	      if (sqtv->sqt_dtp == DV_STRING ||
		  sqtv->sqt_dtp == DV_BLOB_HANDLE ||
		  sqtv->sqt_dtp == DV_BLOB_WIDE_HANDLE ||
		  sqtv->sqt_dtp == DV_WIDE || sqtv->sqt_dtp == DV_LONG_WIDE)
		return 3;
	      else
		return -1;

	    case DV_ANY:
	      return 2;
#if 0
	    case DV_UNKNOWN:
	      return 2;
#endif
	    }
	  return -1;
	}
    }
}


static int
udt_method_sig_distance (sql_type_t * sig1, sql_type_t * sig2, int skip1,
    int skip2)
{
  int inx;
  int distance = 0;
  if (UDT_N_SIG_ELTS (sig1) - skip1 != UDT_N_SIG_ELTS (sig2) - skip2)
    return -1;

  for (inx = skip1; inx < UDT_N_SIG_ELTS (sig1); inx++)
    {
      sql_type_t *sqt1 = &(sig1[inx]);
      sql_type_t *sqt2 = &(sig2[inx - skip1 + skip2]);
      int dist = udt_sqt_distance (sqt1, sqt2);
      if (dist == -1)
	return dist;
      else
	distance += dist;
    }
  return distance;
}


static int
udt_method_sig_ssl_distance (state_slot_t ** sig1, sql_type_t * sig2,
    int skip1, int skip2)
{
  int inx;
  int distance = 0;
  if (BOX_ELEMENTS (sig1) - skip1 != UDT_N_SIG_ELTS (sig2) - skip2)
    return -1;

  for (inx = skip1; inx < BOX_ELEMENTS_INT (sig1); inx++)
    {
      sql_type_t *sqt1 = &(sig1[inx]->ssl_sqt);
      sql_type_t *sqt2 = &(sig2[inx - skip1 + skip2]);
      int dist = udt_sqt_distance (sqt1, sqt2);
      if (dist == -1)
	return dist;
      else
	distance += dist;
    }
  return distance;
}


static int
udt_try_instantiable (dbe_schema_t * sc, sql_class_t * udt, caddr_t * err_ret)
{
  int inx;
  ptrlong ptrlonginx;
  dk_set_t set = NULL;
  sql_class_t *sudt = udt->scl_super;

  if (!udt->scl_defined)
    return 0;
  if (udt->scl_member_map)
    return 1;

  /* fields */
  if (sudt)
    {
      if (!udt_try_instantiable (sc, sudt, err_ret))
	return 0;
      DO_BOX (sql_field_t *, sfld, inx, sudt->scl_member_map)
      {
	dk_set_push (&set, sfld);
      }
      END_DO_BOX;
    }
  for (inx = 0; inx < UDT_N_FIELDS (udt); inx++)
    {
      DO_SET (sql_field_t *, fld, &set)
      {
	if (!strcmp (fld->sfl_name, udt->scl_fields[inx].sfl_name))
	  {
	    *err_ret = srv_make_new_error ("42000", "UD023",
		"Duplicate member name %s in type %s", fld->sfl_name,
		udt->scl_name);
	    goto done;
	  }

      }
      END_DO_SET ();
      dk_set_push (&set, &(udt->scl_fields[inx]));
    }

  udt->scl_member_map =
      (sql_field_t **) list_to_array (dk_set_nreverse (set));
  set = NULL;

  /* methods */
  if (sudt)
    {
      DO_BOX (sql_method_t *, mtd, inx, sudt->scl_method_map)
      {
	dk_set_push (&set, mtd);
      }
      END_DO_BOX;
    }
  for (inx = 0; inx < UDT_N_METHODS (udt); inx++)
    {
      s_node_t *iter;
      int check_depth = 0;
      DO_SET_WRITABLE (sql_method_t *, mtd, iter, &set)
      {
	if (!strcmp (mtd->scm_name, udt->scl_methods[inx].scm_name) &&
	    0 == udt_method_sig_distance (mtd->scm_signature,
		udt->scl_methods[inx].scm_signature, 0, 0))
	  {
	    if (udt->scl_methods[inx].scm_override)
	      {
		iter->data = &(udt->scl_methods[inx]);
		goto next_method;
	      }
	    else
	      {
		*err_ret = srv_make_new_error ("42000", "UD024",
		    "Duplicate method %s in type %s", mtd->scm_name,
		    udt->scl_name);
		goto done;
	      }
	  }
	check_depth++;
      }
      END_DO_SET ();
      dk_set_push (&set, &(udt->scl_methods[inx]));
    next_method:;
    }

  udt->scl_method_map =
      (sql_method_t **) list_to_array (dk_set_nreverse (set));
  set = NULL;
  udt->scl_name_to_method = id_casemode_hash_create (1 + BOX_ELEMENTS (udt->scl_method_map));
  DO_BOX (sql_method_t *, scm, ptrlonginx, udt->scl_method_map)
    {
      if (UDT_METHOD_INSTANCE == scm->scm_type)
	id_hash_set (udt->scl_name_to_method, (caddr_t) &scm->scm_name, (caddr_t) &ptrlonginx);
    }
  END_DO_BOX;
  if (udt->scl_id != 0)
    sethash ((void *) (ptrlong) udt->scl_id, sc->sc_id_to_type, (void *) udt);

done:
  if (set)
    dk_set_free (set);
  if (*err_ret)
    return 0;
  else
    return 1;
}


void
udt_resolve_instantiable (dbe_schema_t * sc, caddr_t * err_ret)
{
  sql_class_t **pcls;
  id_casemode_hash_iterator_t it;

  id_casemode_hash_iterator (&it, sc->sc_name_to_object[sc_to_type]);
  while (id_casemode_hit_next (&it, (caddr_t *) & pcls))
    {
      sql_class_t *cls = *pcls;
      udt_try_instantiable (sc, cls, err_ret);
    }
}


static caddr_t
bif_ddl_type_change (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  char *udt_name = bif_string_arg (qst, args, 0, "__ddl_type_change");
  query_instance_t *qi = (query_instance_t *) qst;
  caddr_t repl = box_copy_tree ((box_t) qi->qi_trx->lt_replicate);
  caddr_t tree = NULL;
  /* save the logging mode across the autocommit inside the schema read */
  dbg_udt_print_class_hash (isp_schema (NULL), "changed before compile", udt_name);
  if (BOX_ELEMENTS (args) > 1)
    {
      tree = bif_arg (qst, args, 1, "__ddl_type_change");
      if (DV_TYPE_OF (tree) == DV_ARRAY_OF_POINTER)
	{ /* replay the mem_only creation */
	  qi_read_type_schema (qi, udt_name, NULL, tree);
	}
      else
	qi_read_type_schema (qi, udt_name, NULL, NULL); /* drop the mem_only */
    }
  else
    qi_read_type_schema (qi, udt_name, NULL, NULL); /* replay the normal one */
  qi->qi_trx->lt_replicate = (caddr_t *) repl;
  log_dd_type_change (qi->qi_trx, udt_name, tree);
  dbg_udt_print_class_hash (isp_schema (NULL), "changed after compile", udt_name);
  return 0;
}


static caddr_t
bif_udt_i_arg (caddr_t * qst, state_slot_t ** args, int nth, const char *func, caddr_t *ref)
{
  caddr_t arg = bif_arg (qst, args, nth, func);
  dtp_t dtp = DV_TYPE_OF (arg);
  switch (dtp)
    {
    case DV_OBJECT:
      *ref = NULL;
      return arg;
    case DV_REFERENCE:
      *ref = arg;
      return udo_find_object_by_ref (arg);
    case DV_XML_ENTITY:
      {
      	sql_class_t *stub_udt = XMLTYPE_CLASS;
      	caddr_t val = NULL;
      	caddr_t res;
      	if (NULL == stub_udt)
	  sqlr_new_error ("22023", "SR362",
	    "The user defined type 'XMLType' is undefined; function %s needs it to cast argument %d of type %s (%d) to a type instance",
	    func, nth + 1, dv_type_title (dtp), dtp);
	qst_swap (qst, args[nth], &val);
	res = list (4, stub_udt, arg, 0, 0);
        box_tag_modify (res, DV_OBJECT);
        *ref = NULL;
        qst_set (qst, args[nth], res);
        return res;
      }
    }
  sqlr_new_error ("22023", "SR014",
    "Function %s needs an user defined type instance as argument %d, not an arg of type %s (%d)",
    func, nth + 1, dv_type_title (dtp), dtp);
  return NULL; /* dummy */
}


sql_class_t *
bif_udt_arg (caddr_t * qst, state_slot_t ** args, int nth, const char *func)
{
  caddr_t arg = bif_arg (qst, args, nth, func);
  sql_class_t *udt = NULL;
  if (arg &&
      (DV_TYPE_OF (arg) == DV_OBJECT ||
       DV_TYPE_OF (arg) == DV_REFERENCE))
    {
      caddr_t ref;
      caddr_t udi = bif_udt_i_arg (qst, args, nth, func, &ref);
      udt = UDT_I_CLASS (udi);
      if (!udt)
	sqlr_new_error ("22023", "UD025",
	  "Function %s needs an user defined type name as argument %d",
	  func, nth + 1);
    }
  else
    {
      arg = bif_string_arg (qst, args, nth, func);
      udt = sch_name_to_type (isp_schema (NULL), arg);
      if (!udt)
	sqlr_new_error ("22023", "UD066",
	  "Function %s needs an valid name of user defined type as argument %d; '%s' is not a defined type",
	  func, nth + 1, arg);
    }
  return udt;
}



sql_class_t *
bif_internal_udt_arg (caddr_t * qst, state_slot_t ** args, int nth, const char *func)
{
  caddr_t arg = bif_arg (qst, args, nth, func);
  sql_class_t *udt = NULL;
  if (DV_LONG_INT == DV_TYPE_OF (arg))
    {
      udt = (sql_class_t *) unbox_ptrlong (arg);
    }
  else
    udt = bif_udt_arg (qst, args, nth, func);
  if (udt->scl_obsolete)
    sqlr_new_error ("22023", "UD066",
      "Function %s needs up to date UDT as argument.  UDT supplied has been changed since this function was called.  Please repeat operation to automatically recompile the function with the new definition of type '%s'", func, udt->scl_name);
      return udt;
}


static caddr_t
bif_udt_is_available (caddr_t * qst, caddr_t * err_ret,
    state_slot_t ** args)
{
  caddr_t name = bif_string_arg (qst, args, 0, "udt_is_available");
  sql_class_t *udt = sch_name_to_type (isp_schema (NULL), name);
  if (udt)
    return box_num(1);
  return box_num(0);
}


static caddr_t
bif_udt_instantiate_class (caddr_t * qst, caddr_t * err_ret,
    state_slot_t ** args)
{
  sql_class_t *udt = bif_internal_udt_arg (qst, args, 0, UDT_INSTANTIATE_CLASS_BIF);
  long best_method_inx = (long) bif_long_arg (qst, args, 1, UDT_INSTANTIATE_CLASS_BIF);

  if (udt->scl_migrate_to)
    {
      dbg_printf (("Type %s is obsolete, scl_migrate_to = %ld.", udt->scl_name, udt->scl_migrate_to));
      sqlr_new_error ("22023", "UD063", "Type %s is obsolete.", udt->scl_name);
    }
  return udt_instantiate_class (qst, udt, best_method_inx, &(args[2]), BOX_ELEMENTS (args) - 2);
}


bif_type_t bt_udt_instance = { NULL, DV_OBJECT, 0, 0 };

int
udt_instance_of (sql_class_t * udt, sql_class_t * sudt)
{
  do
    {
      if (udt == sudt)
	return 1;
      else if (!udt || !sudt)
	return 0;
      else if (UDT_IS_SAME_CLASS (udt, sudt))
	return 1;
      udt = udt->scl_super;
    }
  while (udt);

  return 0;
}


int
udt_find_field (sql_field_t ** map, caddr_t name)
{
  int inx;
  if (!map)
    return -1;
  DO_BOX (sql_field_t *, fld, inx, map)
  {
    if (fld->sfl_name == name || !CASEMODESTRCMP (fld->sfl_name, name))
      return inx;
  }
  END_DO_BOX;
  return -1;
}


int
sec_udt_check (sql_class_t * udt, oid_t group, oid_t user, int op)
{
  ptrlong flags;
  dk_hash_t *ht;
  if (sec_user_has_group (U_ID_DBA, user))
    return 1;
  if (sec_user_has_group (G_ID_DBA, group))
    return 1;
  if (sec_user_has_group_name (udt->scl_owner, user))
    return 1;
  if (sec_user_has_group_name (udt->scl_owner, group))
    return 1;
  ht = udt->scl_grants;
  if (ht)
    {
      flags = (ptrlong) gethash ((void *) U_ID_PUBLIC, ht);
      if (flags & op)
	return 1;
      if (sec_user_is_in_hash (ht, group, op))
	return 1;
      if (sec_user_is_in_hash (ht, user, op))
	return 1;
      if (sec_user_is_in_hash (ht, (oid_t) U_ID_PUBLIC, -1))
	return 1;
    }
  return 0;
}


static int
sec_udt_check_qst (sql_class_t *udt, caddr_t *qst, int op)
{
  query_instance_t *qi = (query_instance_t *) qst;
  oid_t eff_g_id = U_ID_DBA, eff_u_id = U_ID_DBA;
  if (!udt)
    return 1;

  if (qst && qst != (caddr_t *) CALLER_LOCAL && qst != (caddr_t *) CALLER_CLIENT)
    {
      if (!qi->qi_query->qr_proc_name)
	{
	  eff_g_id = qi->qi_g_id;
	  eff_u_id = qi->qi_u_id;
	}
      else
	{
	  user_t * usr = sec_id_to_user (qi->qi_query->qr_proc_owner);
	  eff_u_id = qi->qi_query->qr_proc_owner;
	  if (usr)
	    eff_g_id = usr->usr_g_id;
	  else
	    eff_g_id = eff_u_id;
	}
    }
  else
    {
      client_connection_t *cli;
      cli = GET_IMMEDIATE_CLIENT_OR_NULL;
      if (cli && cli->cli_user)
	{
	  eff_g_id = cli->cli_user->usr_g_id;
	  eff_u_id = cli->cli_user->usr_id;
	}
    }
   return sec_udt_check (udt, eff_g_id, eff_u_id, op);
}


caddr_t
udt_instantiate_class (caddr_t * qst, sql_class_t * udt, long mtd_inx,
    state_slot_t ** args, int n_args)
{
  sql_method_t *cons_mtd = NULL;
  if (!UDT_IS_INSTANTIABLE (udt))
    return dk_alloc_box (0, DV_DB_NULL);
  if (!udt->scl_methods || mtd_inx < 0 || mtd_inx >= UDT_N_METHODS (udt))
    {
      if (n_args)
	return dk_alloc_box (0, DV_DB_NULL);
    }
  else
    {
      cons_mtd = &(udt->scl_methods[mtd_inx]);
    }
  if (cons_mtd && cons_mtd->scm_type != UDT_METHOD_CONSTRUCTOR)
    return dk_alloc_box (0, DV_DB_NULL);

  if (!sec_udt_check_qst (udt, qst, GR_EXECUTE))
    sqlr_new_error ("42000", "UD097:SECURITY", "No permission to instantiate user defined type %.200s", udt->scl_name);

  if (imp_map[udt->scl_ext_lang].scli_instantiate_class)
    return imp_map[udt->scl_ext_lang].scli_instantiate_class (qst, udt, cons_mtd, args, n_args);
  else
    return dk_alloc_box (0, DV_DB_NULL);
}


caddr_t
udt_instance_copy (caddr_t box)
{
  sql_class_t *udt = UDT_I_CLASS (box);
  if (!udt)
    return dk_alloc_box (0, DV_DB_NULL);
  if (imp_map[udt->scl_ext_lang].scli_instance_copy)
    return imp_map[udt->scl_ext_lang].scli_instance_copy (box);
  else
    return dk_alloc_box (0, DV_DB_NULL);
}


int
udt_instance_destroy (caddr_t * box)
{
  sql_class_t *udt = UDT_I_CLASS (box);
  if (udt && imp_map[udt->scl_ext_lang].scli_instance_free)
    imp_map[udt->scl_ext_lang].scli_instance_free (box);
  return 0;
}


caddr_t
udt_member_observer (caddr_t *qst, caddr_t udi, sql_field_t *fld, int member_inx)
{
  if (DV_TYPE_OF (udi) != DV_OBJECT)
    sqlr_new_error ("22023", "UD026", "Invalid instance in user defined type observer");
  if (!sec_udt_check_qst (UDT_I_CLASS (udi), qst, GR_EXECUTE))
    sqlr_new_error ("42000", "UD098:SECURITY", "No permission to access members of user defined type %.200s",
	UDT_I_CLASS (udi)->scl_name);
  if (imp_map[fld->sfl_ext_lang].scli_member_observer)
    return imp_map[fld->sfl_ext_lang].scli_member_observer (qst, udi, fld, member_inx);
  else
    return dk_alloc_box (0, DV_DB_NULL);
}


caddr_t
udt_member_mutator (caddr_t *qst, caddr_t udi, sql_field_t *fld, int member_inx, caddr_t new_val)
{
  if (DV_TYPE_OF (udi) != DV_OBJECT)
    sqlr_new_error ("22023", "UD027", "Invalid instance in user defined type mutator");
  if (!sec_udt_check_qst (UDT_I_CLASS (udi), qst, GR_EXECUTE))
    sqlr_new_error ("42000", "UD099:SECURITY", "No permission to change members of user defined type %.200s",
	UDT_I_CLASS (udi)->scl_name);
  if (DV_TYPE_OF (udi) == DV_OBJECT && imp_map[fld->sfl_ext_lang].scli_member_mutator)
    return imp_map[fld->sfl_ext_lang].scli_member_mutator (qst, udi, fld, member_inx, new_val);
  else
    return dk_alloc_box (0, DV_DB_NULL);
}

caddr_t
udt_method_call (caddr_t *qst, sql_class_t *udt, caddr_t udi,
    sql_method_t *mtd, state_slot_t **args, int n_args)
{
  if (udi)
    {
      if (DV_TYPE_OF (udi) != DV_OBJECT || !UDT_I_CLASS (udi))
	sqlr_new_error ("22023", "UD028", "Invalid instance in user defined type method call");
      if (!udt_instance_of (UDT_I_CLASS (udi), udt))
	sqlr_new_error ("22023", "UD029", "%s is not an instance of %s in user defined type method call",
	    UDT_I_CLASS (udi)->scl_name, udt->scl_name);
      if (mtd->scm_type == UDT_METHOD_STATIC)
	sqlr_new_error ("22023", "UD030", "%s instance supplied to a static method call %s of %s",
	    UDT_I_CLASS (udi)->scl_name, mtd->scm_name, udt->scl_name);
    }
  else if (mtd->scm_type != UDT_METHOD_STATIC)
    sqlr_new_error ("22023", "UD031", "No instance supplied to a non-static method call %s of %s",
	mtd->scm_name, udt->scl_name);

  if (!sec_udt_check_qst (udi ? UDT_I_CLASS (udi) : udt, qst, GR_EXECUTE))
    sqlr_new_error ("42000", "UD100:SECURITY", "No permission to call methods of user defined type %.200s",
	(udi ? UDT_I_CLASS (udi)->scl_name : udt->scl_name));

  if (imp_map[mtd->scm_ext_lang].scli_method_call)
    return imp_map[mtd->scm_ext_lang].scli_method_call (qst, udt, udi, mtd, args, n_args);
  else
    return dk_alloc_box (0, DV_DB_NULL);
}


int
udt_serialize (caddr_t udi, dk_session_t * session)
{
  sql_class_t *udt, *orig_udt;
  caddr_t alloc_udi = NULL;
  int ret;

  orig_udt = udt = UDT_I_CLASS (udi);
  if (udt == XMLTYPE_CLASS)
    { /* serialize the XMLType as long varchar even for the UDT instances */
      caddr_t xe = (caddr_t) XMLTYPE_TO_ENTITY (udi);
      print_object2 (xe, session);
      return 0;
    }
  if (!udt || udt->scl_mem_only || !imp_map[udt->scl_ext_lang].scli_serialize)
    {
      alloc_udi = udi = udt_serialization_error_dv (udt ? udt->scl_name : (caddr_t) "unknown class");
      udt = UDT_I_CLASS (udi);
    }
  session_buffered_write_char (DV_OBJECT, session);
  print_long (udt->scl_id, session);

  ret = imp_map[udt->scl_ext_lang].scli_serialize (udi, session);
  if (alloc_udi)
    dk_free_box (alloc_udi);
  return ret;
}


void *
udt_deserialize (dk_session_t * session, dtp_t dtp)
{
  caddr_t ret = NULL;
  long udt_id;
  sql_class_t *udt;

  udt_id = read_long (session);
  if (udt_id == UDT_JAVA_CLIENT_OBJECT_ID && imp_map[UDT_LANG_JAVA].scli_deserialize)
    ret = (caddr_t) imp_map[UDT_LANG_JAVA].scli_deserialize (session, dtp, NULL);
  else
    {
      udt = sch_id_to_type (isp_schema (NULL), udt_id);
      if (!udt || udt->scl_id != udt_id || !udt->scl_member_map ||
	  !imp_map[udt->scl_ext_lang].scli_deserialize)
	ret = (caddr_t) scan_session_boxing (session);
      else
	ret = (caddr_t) imp_map[udt->scl_ext_lang].scli_deserialize (session, dtp, udt);
    }
  if (!ret)
    ret = udt_serialization_error_dv ("unknown class");
  return ret;
}


/* interface functions implementation for SQL */

static caddr_t
udt_sql_instantiate_class (caddr_t * qst, sql_class_t * udt, sql_method_t *mtd,
    state_slot_t ** args, int n_args)
{
  int inx;
  caddr_t ret = NULL;

  ret =
      dk_alloc_box_zero (box_length (udt->scl_member_map) + sizeof (caddr_t),
      DV_OBJECT);

  UDT_I_CLASS (ret) = udt;
  for (inx = 0; inx < BOX_ELEMENTS_INT (udt->scl_member_map); inx++)
    {
      caddr_t new_val;
      if (udt->scl_member_map[inx]->sfl_default)
	new_val = box_copy (udt->scl_member_map[inx]->sfl_default);
      else
	new_val = dk_alloc_box (0, DV_DB_NULL);
      UDT_I_VAL (ret, inx) = new_val;
    }
  if (udt->scl_self_as_ref)
    {
      ret = udo_new_object_ref (ret/*, 0*/);
    }

  return ret;
}


static caddr_t
udt_sql_instance_copy (caddr_t box)
{
  caddr_t newb = dk_alloc_box (box_length (box), DV_OBJECT);
  int inx;

  UDT_I_CLASS (newb) = UDT_I_CLASS (box);
  for (inx = 0; inx < UDT_I_LENGTH (box); inx++)
    UDT_I_VAL (newb, inx) = box_copy_tree (UDT_I_VAL (box, inx));
  return newb;
}


static void
udt_sql_instance_free (caddr_t * box)
{
  int inx;
  for (inx = 0; inx < UDT_I_LENGTH (box); inx++)
    dk_free_tree (UDT_I_VAL (box, inx));
}


static caddr_t
udt_sql_member_observer (caddr_t *qst, caddr_t udi, sql_field_t *fld, int member_inx)
{
  return box_copy_tree (UDT_I_VAL (udi, member_inx));
}


static caddr_t
udt_sql_member_mutator (caddr_t *qst, caddr_t udi, sql_field_t *fld, int member_inx, caddr_t new_val)
{
  dk_free_tree (UDT_I_VAL (udi, member_inx));
  UDT_I_VAL (udi, member_inx) = box_copy_tree (new_val);
  return udi;
}


static caddr_t
udt_sql_method_call (caddr_t *qst, sql_class_t *udt, caddr_t udi,
    sql_method_t *mtd, state_slot_t **args, int n_args)
{
#if 0
  instruction_t ins, *inst = &ins;
  caddr_t ret;

  memset (inst, 0, sizeof (instruction_t));
  inst->ins_type = INS_CALL;
  inst->_.call.proc = box_dv_uname_string (mtd->scm_specific_name);
  inst->_.call.bif = bif_find (mtd->scm_specific_name);
  inst->_.call.ret = NULL;
  inst->_.call.params =
      dk_alloc_box (n_args * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
  if (n_args)
    memcpy (inst->_.call.params, args,
	box_length (inst->_.call.params));
  ins_call (inst, qst, &ret);
  return ret;
#else
  if (!mtd->scm_qr)
    sqlr_new_error ("42000", "UD032", "Method '%s' of type '%s' not defined",
	mtd->scm_name, mtd->scm_class->scl_name);
  else
    {
      oid_t eff_g_id, eff_u_id;
      caddr_t value;
      query_instance_t *qi = (query_instance_t *) QST_INSTANCE (qst);
      caddr_t err = NULL;
      caddr_t pars_auto[30];
      int param_len = n_args * sizeof (caddr_t);
      query_t *proc = mtd->scm_qr;
      caddr_t *pars;
      caddr_t ptmp;
      int inx;
      int any_out = 0;
      int n_ret_param = qi->qi_query->qr_is_call == 2 ? 1 : 0;

      char auto_qi[AUTO_QI_DEFAULT_SZ];

      param_len -= n_ret_param * sizeof (caddr_t);
      if (proc->qr_to_recompile)
	mtd->scm_qr = proc = qr_recompile (proc, NULL);
      if (!qi->qi_query->qr_proc_name)
	{
	  eff_g_id = qi->qi_g_id;
	  eff_u_id = qi->qi_u_id;
	}
      else
	{
	  user_t * usr = sec_id_to_user (qi->qi_query->qr_proc_owner);
	  eff_u_id = qi->qi_query->qr_proc_owner;
	  if (usr)
	    eff_g_id = usr->usr_g_id;
	  else
	    eff_g_id = eff_u_id;
	}
      if (!sec_udt_check_qst (udt, qst, GR_EXECUTE) &&
	  !sec_proc_check (proc, eff_g_id, eff_u_id))
	sqlr_new_error ("42000", "SR186:SECURITY", "No permission to execute method %s of type %s with user ID %d, group ID %d",
	    mtd->scm_name, mtd->scm_class->scl_name, (int)eff_g_id, (int)eff_u_id );

      BOX_AUTO (ptmp, pars_auto, param_len, DV_ARRAY_OF_POINTER);
      pars = (caddr_t *) ptmp;

      inx = 0;
      DO_SET (state_slot_t *, sl, &proc->qr_parms)
	{
	  state_slot_t *actual;
	  if (inx >= (int) (param_len / sizeof (caddr_t)))
	    {
	      sqlr_new_error ("07001", "SR187", "Too few actual parameters for method %s.", proc->qr_proc_name);
	    }
	  actual = args[inx - n_ret_param];
	  if (IS_SSL_REF_PARAMETER (sl->ssl_type))
	    {
	      if (actual->ssl_type == SSL_CONSTANT)
		{
		  sqlr_new_error ("HY105", "SR188", "Cannot pass literal as reference parameter.");
		}
	      pars[inx] = (caddr_t) qst_address (qst, actual);
	      any_out = 1;
	    }
	  else
	    pars[inx] = box_copy_tree (QST_GET (qst, actual));
	  inx++;
	}
      END_DO_SET ();
#ifndef ROLLBACK_XQ
      dk_free_tree ((caddr_t) qi->qi_thread->thr_func_value); /* IvAn/010801/LeakOnReturn: this line added */
#endif
      qi->qi_thread->thr_func_value = NULL;
      err = qr_subq_exec (qi->qi_client, proc, qi,
	  (caddr_t *) & auto_qi, sizeof (auto_qi), NULL, pars, NULL);
      BOX_DONE (pars, pars_auto);
      value = qi->qi_thread->thr_func_value;
      qi->qi_thread->thr_func_value = NULL;
      if ((caddr_t) SQL_NO_DATA_FOUND == err
	  && CALLER_CLIENT == qi->qi_caller)
	{
	  /* unhandled 'not found' will appear as end of possible results and
	   * procedure return tp client.
	   * It will be resignaled if caller is a procedure
	   */
	  err = SQL_SUCCESS;
	}
      if (err)
	{
	  dk_free_tree (value);
	  sqlr_resignal (err);
	}
#if 1
      if (qi->qi_lc && CALLER_LOCAL == qi->qi_caller)
	{
	  /* if invoked from server internal api and result needed, put it in lc */
	  int inx;
	  caddr_t *cli_ret = (caddr_t *) dk_alloc_box_zero
	      (param_len + (2 + n_ret_param) * sizeof (caddr_t), DV_ARRAY_OF_POINTER);

	  cli_ret[0] = (caddr_t) QA_PROC_RETURN;
	  if (n_ret_param)
	    cli_ret[2] = box_copy_tree (value);
	  else
	    cli_ret[1] = box_copy_tree (value);

	  inx = n_ret_param;
	  DO_SET (state_slot_t *, sl, &proc->qr_parms)
	    {
	      if (IS_SSL_REF_PARAMETER (sl->ssl_type))
		{
		  state_slot_t *actual;
		  actual = args[inx - n_ret_param];
		  if (BOX_ELEMENTS_INT (cli_ret) > inx + 2)
		    cli_ret[inx + 2] = box_copy_tree (qst_get (qst, actual));
		}
	      inx++;
	    }
	  END_DO_SET ();
	  qi->qi_lc->lc_proc_ret = (caddr_t) cli_ret;
	}
#endif
      return value;
    }
  return NULL;
#endif
}


static int
udt_sql_serialize (caddr_t udi, dk_session_t * session)
{
  int length = UDT_I_LENGTH (udi), inx;

  session_buffered_write_char (DV_ARRAY_OF_POINTER, session);
  print_int (length, session);
  for (inx = 0; inx < length; inx++)
    {
      print_object2 (UDT_I_VAL (udi,inx), session);
    }
  return 0;
}


static caddr_t
udt_sql_instance_migrate (caddr_t udi)
{
  sql_class_t *udt, *n_udt;
  dbe_schema_t *sc = isp_schema (NULL);
  caddr_t n_udi = NULL;
  int inx;


  n_udt = udt = UDT_I_CLASS (udi);
  while (n_udt->scl_migrate_to)
    {
      n_udt = sch_id_to_type (sc, n_udt->scl_migrate_to);
      if (!n_udt)
	return udi;
    }
  if (!UDT_IS_INSTANTIABLE  (n_udt))
    return udi;

  n_udi = dk_alloc_box_zero ((BOX_ELEMENTS (n_udt->scl_member_map) + 1) * sizeof (caddr_t), DV_OBJECT);
  UDT_I_CLASS (n_udi) = n_udt;
  DO_BOX (sql_field_t *, n_fld, inx, n_udt->scl_member_map)
    {
      int fld_inx = udt_find_field (udt->scl_member_map, n_fld->sfl_name);
      if (fld_inx == -1)
	UDT_I_VAL (n_udi, inx) = n_fld->sfl_default ?
	    box_copy_tree (n_fld->sfl_default) : dk_alloc_box (0, DV_DB_NULL);
      else
	{
	  UDT_I_VAL (n_udi, inx) = UDT_I_VAL (udi, fld_inx);
	  UDT_I_VAL (udi, fld_inx) = NULL;
	}
    }
  END_DO_BOX;
  return n_udi;
}


static void *
udt_sql_deserialize (dk_session_t * session, dtp_t dtp, sql_class_t *udt)
{
  caddr_t ret = NULL;
  int length, inx;
  dtp_t ddtp;

  ddtp = session_buffered_read_char (session);
  if (ddtp != DV_ARRAY_OF_POINTER)
    GPF_T1 ("Not an array");
  length = read_int (session);

  if (BOX_ELEMENTS (udt->scl_member_map) == length)
    {
      ret = dk_alloc_box_zero ((length + 1) * sizeof (caddr_t), DV_OBJECT);
      UDT_I_CLASS (ret) = udt;
      for (inx = 0; inx < length; inx++)
	{
	  UDT_I_VAL (ret, inx) = (caddr_t) scan_session_boxing (session);
	}

      if (udt->scl_migrate_to)
	{
	  caddr_t ret1 = udt_sql_instance_migrate (ret);
	  if (ret1 != ret)
	    {
	      dk_free_box (ret);
	      ret = ret1;
	    }
	}
    }
  else
    {
      ret = dk_alloc_box_zero (length * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
      for (inx = 0; inx < length; inx++)
	{
	  ((caddr_t *)ret)[inx] = (caddr_t) scan_session_boxing (session);
	}
    }
  return ret;
}


/* end of interface functions implementation for SQL */


static caddr_t
bif_udt_member_handler (caddr_t * qst, caddr_t * err_ret,
    state_slot_t ** args)
{
  sql_class_t *udt = bif_internal_udt_arg (qst, args, 0, UDT_MEMBER_HANDLER_BIF);
  long member_inx = (long) bif_long_arg (qst, args, 1, UDT_MEMBER_HANDLER_BIF);
  caddr_t ref = NULL;
  caddr_t udi;
  sql_field_t *fld;
  const char *observer = BOX_ELEMENTS (args) <= 3 ? "observer" : "mutator";

  caddr_t ret = NULL;

  if (member_inx < 0 || member_inx >= BOX_ELEMENTS_INT (udt->scl_member_map))
    sqlr_new_error ("42000", "UD035", "invalid instance offset %ld",
	member_inx);

  fld = udt->scl_member_map [member_inx];

  udi = bif_arg (qst, args, 2, UDT_MEMBER_HANDLER_BIF);
  if (DV_DB_NULL == DV_TYPE_OF (udi))
    sqlr_new_error ("42000", "UD067",
	"The argument 3 is of type DB_NULL, not an user defined type in member (%s) %s (... AS \"%.200s\").\"%.200s\" call.",
	fld->sfl_name, observer, udt->scl_name, fld->sfl_name);
  udi = bif_udt_i_arg (qst, args, 2, UDT_MEMBER_HANDLER_BIF, &ref);
  if (!udi)
    {
      if (BOX_ELEMENTS (args) <= 3)
	return dk_alloc_box (0, DV_DB_NULL);
      else
	return (ref ? box_copy_tree (ref) : dk_alloc_box (0, DV_DB_NULL));
    }
  if (!UDT_I_CLASS (udi))
    sqlr_new_error ("22023", "UD033",
	"Non-valid object instance supplied to member (%s) %s for class %.200s",
	fld->sfl_name, observer, udt->scl_name);

  if (!udt_instance_of (UDT_I_CLASS (udi), udt))
    sqlr_new_error ("42000", "UD034",
	"The object (type %s) is not an instance of %s",
	UDT_I_CLASS (udi)->scl_name, udt->scl_name);

  if (BOX_ELEMENTS (args) > 3)
    {
      udi = udt_member_mutator (qst, udi, fld, member_inx,
	  bif_arg (qst, args, 3, UDT_MEMBER_HANDLER_BIF));
      if (!ref)
	ret = (caddr_t) box_copy_tree (udi);
      else
	ret = box_copy_tree (ref);
    }
  else
    {
      ret = udt_member_observer (qst, udi, fld, member_inx);
    }
  return ret;
}


static caddr_t
bif_udt_method_call (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *) qst;
  sql_class_t *udt, *udt_to_free = NULL;
  long method_inx = (long) bif_long_arg (qst, args, 1, UDT_METHOD_CALL_BIF);
  caddr_t udi = NULL;
  sql_method_t *mtd;
  int use_udi_udt = 1;
  caddr_t _udt;

  _udt = bif_arg (qst, args, 0, UDT_METHOD_CALL_BIF);
  *err_ret = NULL;
  if (DV_ARRAY_OF_POINTER == DV_TYPE_OF (_udt))
    {
      udt = udt_to_free = udt_compile_class_def (isp_schema (NULL),
	  _udt, NULL, err_ret, 0, qi->qi_client, 0, 0);
      if (*err_ret != 0)
	return NULL;
      if (!udt_try_instantiable (isp_schema (NULL), udt, err_ret))
	{
	  if (!*err_ret)
	    *err_ret = srv_make_new_error ("42000", "UD102",
		"Cannot compile the temp method for external procedure");
	  udt_free_class_def (udt_to_free);
	  return NULL;
	}
    }
  else
    udt = bif_internal_udt_arg (qst, args, 0, UDT_METHOD_CALL_BIF);
  if (method_inx < -1)
    {
      method_inx *= -1;
      use_udi_udt = 0;
      method_inx -= 2;
    }
  if (method_inx < 0 || method_inx >= BOX_ELEMENTS_INT (udt->scl_method_map))
    {
      if (udt_to_free)
	udt_free_class_def (udt_to_free);
      sqlr_new_error ("42000", "UD036", "invalid vtable offset %ld", method_inx);
    }

  mtd = udt->scl_method_map[method_inx];
  if (mtd->scm_type != UDT_METHOD_STATIC)
    {
      sql_class_t *udi_udt;
      caddr_t ref = NULL;
      udi = bif_udt_i_arg (qst, args, 2, UDT_METHOD_CALL_BIF, &ref);
      if (!udi && ref)
	return dk_alloc_box (0, DV_DB_NULL);
      udi_udt = UDT_I_CLASS (udi);
      if (!udi_udt)
	{
	  if (udt_to_free)
	    udt_free_class_def (udt_to_free);
	  sqlr_new_error ("22023", "UD037",
	      "The object supplied is not an instance of %s",
	      udt->scl_name);
	}
      if (!udt_instance_of (udi_udt, udt))
	{
	  if (udt_to_free)
	    udt_free_class_def (udt_to_free);
	  sqlr_new_error ("22023", "UD038",
	      "The object (type %s) is not an instance of %s",
	      UDT_I_CLASS (udi)->scl_name, udt->scl_name);
	}
      if (method_inx < 0
	  || method_inx >= BOX_ELEMENTS_INT (udi_udt->scl_method_map))
	{
	  if (udt_to_free)
	    udt_free_class_def (udt_to_free);
	  sqlr_new_error ("42000", "UD039", "invalid vtable offset %ld",
	      method_inx);
	}
      if (use_udi_udt)
	mtd = udi_udt->scl_method_map[method_inx];
    }
  if (udt_to_free)
    {
      caddr_t ret = NULL;
      QR_RESET_CTX
	{
	  ret = udt_method_call (qst, udt, udi, mtd, &(args[2]), BOX_ELEMENTS (args) - 2);
	}
      QR_RESET_CODE
	{
	  POP_QR_RESET;
	  *err_ret = thr_get_error_code (THREAD_CURRENT_THREAD);
	  ret = NULL;
	}
      END_QR_RESET;
      udt_free_class_def (udt_to_free);
      return ret;
    }
  else
    return udt_method_call (qst, udt, udi, mtd, &(args[2]), BOX_ELEMENTS (args) - 2);
}


int
sqlc_udt_is_udt_call (sql_comp_t * sc, char *name, dk_set_t * code,
    state_slot_t * ret, state_slot_t ** params, caddr_t ret_param, caddr_t fun_udt_name)
{
  int fld_inx;
  sql_class_t *udt = NULL;
  int retc = 0;

  if (fun_udt_name)
    {
      udt = sch_name_to_type (wi_inst.wi_schema, fun_udt_name);
      if (!udt)
	sqlc_new_error (sc->sc_cc, "37000", "UD040",
	    "User defined type %.200s not found in member observer (... AS ...) call",
	    fun_udt_name);
    }
  else if (BOX_ELEMENTS (params) >= 1 &&
	NULL != params[0]->ssl_sqt.sqt_class)
    udt = params[0]->ssl_sqt.sqt_class;

  if (udt && !udt->scl_migrate_to && -1 != (fld_inx = udt_find_field (udt->scl_member_map, name)))
    {				/* this is a field */
      caddr_t fld_inx_box = box_num (fld_inx);
      if (BOX_ELEMENTS (params) == 1)
	{			/* observer */
	  state_slot_t **bif_parms = (state_slot_t **) sc_list (3,
	      scalar_exp_generate (sc, (ST *) t_box_num ((ptrlong) udt), code),
	      scalar_exp_generate (sc, (ST *) fld_inx_box, code),
	      params[0]);
	  cv_call (code, NULL, t_sqlp_box_id_upcase (UDT_MEMBER_HANDLER_BIF), ret, bif_parms);
	  qr_uses_type (sc->sc_cc->cc_query, udt->scl_name);
	  if (ret && IS_REAL_SSL (ret) && ret->ssl_dtp == DV_UNKNOWN)
	    ret->ssl_sqt = udt->scl_member_map[fld_inx]->sfl_sqt;
	  if (ret && udt->scl_ext_lang == UDT_LANG_SQL)
	    ret->ssl_is_observer = 1;
	  retc = 1;
	}
      else if (BOX_ELEMENTS (params) == 2)
	{			/* mutator */
	  state_slot_t **bif_parms = (state_slot_t **) sc_list (4,
	      scalar_exp_generate (sc, (ST *) t_box_num ((ptrlong)udt), code),
	      scalar_exp_generate (sc, (ST *) fld_inx_box, code),
	      params[0],
	      params[1]);
	  cv_call (code, NULL, t_sqlp_box_id_upcase (UDT_MEMBER_HANDLER_BIF), ret, bif_parms);
	  qr_uses_type (sc->sc_cc->cc_query, udt->scl_name);
	  if (ret)
	    {
	      ret->ssl_dtp = DV_OBJECT;
	      ret->ssl_sqt.sqt_class = udt;
	    }
	  if (params[1]->ssl_dtp == DV_UNKNOWN)
	    params[1]->ssl_sqt = udt->scl_member_map[fld_inx]->sfl_sqt;
	  retc = 1;
	}
      dk_free_box (fld_inx_box);
    }
  else if (NULL != (udt = sch_name_to_type (wi_inst.wi_schema, name)) && !udt->scl_migrate_to)
    {				/* constructor */
      state_slot_t **bif_parms = (state_slot_t **) dk_alloc_box (box_length (params) + 2 * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
      sql_method_t *best_method = NULL;
      int best_method_inx;

      if (box_length (params) > 0)
	memcpy (&(bif_parms[2]), params, box_length (params));

      bif_parms[0] = scalar_exp_generate (sc, (ST *) udt->scl_name, code);
      qr_uses_type (sc->sc_cc->cc_query, udt->scl_name);
      best_method_inx = sqlc_udt_has_constructor_method (sc, udt, ret, params);
      if (best_method_inx != -1)
	best_method = &(udt->scl_methods[best_method_inx]);
      bif_parms[1] = scalar_exp_generate (sc, (ST *) t_box_num (best_method_inx), code);
      if (NULL != best_method && best_method->scm_ext_lang == UDT_LANG_SQL)
	{
	  state_slot_t **cons_params;
	  state_slot_t *cons_ret = ret ? ret : sqlc_new_temp (sc, "udt_inst", DV_OBJECT);
	  int inx;

	  cons_params =
	      (state_slot_t **) dk_alloc_box (box_length (params) +
	      3 * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
	  if (box_length (params) > 0)
	    memcpy (&(cons_params[3]), params, box_length (params));
	  best_method_inx = -1;
	  DO_BOX (sql_method_t *, mtd, inx, udt->scl_method_map)
	    {
	      if (best_method == mtd)
		best_method_inx = inx;
	    }
	  END_DO_BOX;
	  cons_params[0] = ssl_new_constant (sc->sc_cc, t_box_num ((ptrlong)udt));
	  cons_params[1] = ssl_new_constant (sc->sc_cc, t_box_num (best_method_inx));
	  cons_params[2] = cons_ret;
	  cons_params[2]->ssl_sqt.sqt_class = udt;

	  cv_call (code, NULL, t_sqlp_box_id_upcase (UDT_INSTANTIATE_CLASS_BIF), cons_params[2],
	      bif_parms);

	  cv_call (code, NULL, t_sqlp_box_id_upcase (UDT_METHOD_CALL_BIF), CV_CALL_VOID,
	      cons_params);
	}
      else
	cv_call (code, NULL, t_sqlp_box_id_upcase (UDT_INSTANTIATE_CLASS_BIF), ret, bif_parms);
      if (ret && IS_REAL_SSL (ret) && ret->ssl_dtp == DV_UNKNOWN)
	{
	  ret->ssl_dtp = DV_OBJECT;
	  ret->ssl_sqt.sqt_class = udt;
	}
      retc = 1;
    }
  return retc;
}


static int sqlc_udt_find_best_method_to_call (
  char *method_name, sql_class_t *udt, int method_type,
  state_slot_t * ret, state_slot_t ** params,
 caddr_t *err_ret)
{
  const char *method_type_name = ((UDT_METHOD_INSTANCE == method_type) ? "instance" : "static");
  const char *wrong_type_name = ((UDT_METHOD_INSTANCE == method_type) ? "static" : "instance");
  int best_score = -1;
  int best_inx = -1;
  int best_count = 0;
  int method_count = 0;
  int wrong_count = 0;
  int inx;
  if (NULL == udt->scl_method_map)
    {
      err_ret[0] =
        srv_make_new_error ("37000", "UD044",
	  "Call of %s method '%s' of type '%s' is invalid: no methods are declared for this type", method_type_name, method_name, udt->scl_name);
      return best_inx;
    }
  DO_BOX (sql_method_t *, method, inx, udt->scl_method_map)
    {
      int score;
      if (CASEMODESTRCMP (method_name, method->scm_name))	 /* Name does not match. */
	continue;
      if (method->scm_type != method_type)	/* instance instead of static or vice versa */
	{
          wrong_count ++;
	  continue;
	}
      method_count ++;
      score = udt_method_sig_ssl_distance (params, method->scm_signature,
        ((UDT_METHOD_INSTANCE == method_type) ? 1 : 0),
        1 );
      if (score != -1 && ret && IS_REAL_SSL (ret) && ret->ssl_dtp != DV_UNKNOWN)
	{
	  int dist = udt_sqt_distance (&(ret->ssl_sqt), &(method->scm_signature[0]));
	  if (dist == -1)
	    score = dist;
	  else
	    score += dist;
	}
      if (-1 == score)
        continue;	/* Method does not match at all */
      if (score < best_score || -1 == best_score)
	{	/* This is the best hit we've ever seen */
	  best_score = score;
	  best_inx = inx;
	  best_count = 1;
	}
      else if (score == best_score)
        best_count += 1;	/* This method matches as good as one of previous */
    }
  END_DO_BOX;
  if ((0 == method_count) && (0 != wrong_count))
    {
      err_ret[0] = srv_make_new_error ("37000", "UD045",
	  "No %s method '%s' in the user defined type '%s'; there are only %s method(s) with this name", method_type_name, method_name, udt->scl_name, wrong_type_name);
      return best_inx;
    }
  if (0 == method_count)
    {
      err_ret[0] = srv_make_new_error ("37000", "UD045",
	  "No %s method '%s' in the user defined type '%s'", method_type_name, method_name, udt->scl_name);
      return best_inx;
    }
  if (-1 == best_inx)
    {
      err_ret[0] = srv_make_new_error ("37000", "UD042",
	  "No %s method '%s' in the user defined type %s matches the call: wrong number and/or type of parameters passed", method_type_name, method_name, udt->scl_name);
      return best_inx;
    }
  if (1 < best_count)
    {
      err_ret[0] = srv_make_new_error ("37000", "UD046",
	"Ambiguous %s method '%s' in the user defined type '%s'", method_type_name, method_name,
	udt->scl_name);
      return best_inx;
    }
  return best_inx;
}



static int
sqlc_udt_static_method_call (sql_comp_t * sc, char *name, dk_set_t * code,
    state_slot_t * ret, state_slot_t ** params, caddr_t ret_param,
    caddr_t type_name)
{
  sql_class_t *udt = sch_name_to_type (wi_inst.wi_schema, type_name);
  int best_mtd_inx = -1;
  caddr_t err = NULL;
  state_slot_t **bif_params;
  if (!udt)
    {
      err = srv_make_new_error ("37000", "UD041", "No user defined type %s",
	  type_name);
      goto error;
    }
  best_mtd_inx = sqlc_udt_find_best_method_to_call (name, udt, UDT_METHOD_STATIC,
      ret, params, &err);
  if (NULL != err)
    goto error;

  bif_params =
      (state_slot_t **) dk_alloc_box (box_length (params) +
      2 * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
  memcpy (&(bif_params[2]), params, box_length (params));
  bif_params[0] = scalar_exp_generate (sc, (ST *) t_box_num ((ptrlong)udt), code);
  bif_params[1] = scalar_exp_generate (sc, (ST *) (ptrlong) best_mtd_inx, code);
  cv_call (code, NULL, t_sqlp_box_id_upcase (UDT_METHOD_CALL_BIF), ret, bif_params);
  if (ret && IS_REAL_SSL (ret) && ret->ssl_dtp == DV_UNKNOWN)
    ret->ssl_sqt = udt->scl_method_map[best_mtd_inx]->scm_signature[0];
  qr_uses_type (sc->sc_cc->cc_query, udt->scl_name);
  return 1;

error:
  sqlc_resignal_1 (sc->sc_cc, err);
  return 0;			/* dummy */
}

static int
sqlc_udt_dynamic_method_call (sql_comp_t * sc, char *name, dk_set_t * code,
    state_slot_t * ret, state_slot_t ** params, caddr_t ret_param, caddr_t type_name)
{
  sql_class_t *udt;
  int best_mtd_inx = -1;
  caddr_t err = NULL;
  state_slot_t **bif_params;
  if (!type_name)
    {
      if (BOX_ELEMENTS (params) < 1)
	{
	  err =
	      srv_make_new_error ("37000", "UD103",
		  "Dynamic call of method '%s' is invalid: 'self' parameter is not passed", name);
	  goto error;
	}
      udt = params[0]->ssl_sqt.sqt_class;
/*      if (NULL == udt)
        udt = udt_class_of_wellknown_method (name);*/
      if (NULL == udt)
	{
	  sql_class_t *stub_udt = XMLTYPE_CLASS;
	  if (NULL != stub_udt)
	    {
	      best_mtd_inx = sqlc_udt_find_best_method_to_call (name, stub_udt, UDT_METHOD_INSTANCE,
		ret, params, &err);
	      if (-1 != best_mtd_inx)
		udt = stub_udt;
	    }
	}
      if (NULL == udt)
	{

	  err =
	      srv_make_new_error ("37000", "UD104",
		  "Dynamic call of method '%s' is invalid: 'self' parameter has no type information", name);
	  goto error;
	}
    }
  else
    {
      sql_class_t *udt_spec = sch_name_to_type (wi_inst.wi_schema, type_name);
      if (NULL == udt_spec)
	{
	  err =
	      srv_make_new_error ("37000", "UD105",
		  "Dynamic call of method '%s' is invalid: type '%.200s' is not declared", name, type_name);
	  goto error;
	}
      udt = udt_spec;
    }
  if (NULL == udt->scl_method_map)
    {
      err =
        srv_make_new_error ("37000", "UD044",
	  "Dynamic call of method '%s' is invalid: 'self' parameter of type '%s' has no methods", name, udt->scl_name);
      goto error;
    }
  best_mtd_inx = sqlc_udt_find_best_method_to_call (name, udt, UDT_METHOD_INSTANCE,
      ret, params, &err);
  if (NULL != err)
    goto error;
  bif_params =
      (state_slot_t **) dk_alloc_box (box_length (params) +
      2 * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
  memcpy (&(bif_params[2]), params, box_length (params));
  bif_params[0] = scalar_exp_generate (sc, (ST *)t_box_num((ptrlong)udt), code);
  if (type_name)
    bif_params[1] = scalar_exp_generate (sc, (ST *) t_box_num ((best_mtd_inx + 2) * -1), code);
  else
    bif_params[1] = scalar_exp_generate (sc, (ST *) t_box_num (best_mtd_inx), code);
  cv_call (code, NULL, t_sqlp_box_id_upcase (UDT_METHOD_CALL_BIF), ret, bif_params);
  if (ret && IS_REAL_SSL (ret) && ret->ssl_dtp == DV_UNKNOWN)
    ret->ssl_sqt = udt->scl_method_map[best_mtd_inx]->scm_signature[0];
  qr_uses_type (sc->sc_cc->cc_query, udt->scl_name);
  return 1;

error:
  sqlc_resignal_1 (sc->sc_cc, err);
  return 0;			/* dummy */
}


static int
sqlc_udt_has_constructor_method (sql_comp_t * sc, sql_class_t * udt,
    state_slot_t * ret, state_slot_t ** params)
{
  int inx;
  int best_score = -1;
  int best_mtd_inx = -1;
  caddr_t err = NULL;

  if (!udt->scl_member_map)
    {
      err =
	  srv_make_new_error ("37000", "UD047",
	  "Not an proper constructor call");
      goto error;
    }

  for (inx = 0; inx < UDT_N_METHODS (udt); inx++)
    {
      sql_method_t *mtd = &(udt->scl_methods[inx]);
      if (mtd->scm_type == UDT_METHOD_CONSTRUCTOR)
	{
	  int score =
	      udt_method_sig_ssl_distance (params, mtd->scm_signature, 0, 1);
	  if (score != -1 && ret && IS_REAL_SSL (ret) && ret->ssl_dtp != DV_UNKNOWN)
	    {
	      int dist = udt_sqt_distance (&(mtd->scm_signature[0]), &(ret->ssl_sqt));
	      if (dist == -1)
		score = dist;
	      else
		score += dist;
	    }
	  if (score != -1 && (score < best_score || best_score == -1))
	    {
	      best_score = score;
	      best_mtd_inx = inx;
	    }
	}
    }

  if (best_mtd_inx == -1 && BOX_ELEMENTS (params) > 1)
    {
      err = srv_make_new_error ("37000", "UD048",
	  "No constructor in the user defined type %s", udt->scl_name);
      goto error;
    }

  if (best_mtd_inx != -1)
    {
      for (inx = 0; inx < UDT_N_METHODS (udt); inx++)
	{
	  sql_method_t *mtd = &(udt->scl_methods[inx]);
	  if (mtd->scm_type == UDT_METHOD_CONSTRUCTOR && inx != best_mtd_inx)
	    {
	      int score =
		  udt_method_sig_ssl_distance (params, mtd->scm_signature, 0,
		  1);
	      if (score != -1 && ret && IS_REAL_SSL (ret)
		  && ret->ssl_dtp != DV_UNKNOWN)
		score +=
		    udt_sqt_distance (&(ret->ssl_sqt),
		    &(mtd->scm_signature[0]));
	      if (score == best_score)
		{
		  err = srv_make_new_error ("37000", "UD049",
		      "Ambiguous constructor call for the user defined type %s",
		      udt->scl_name);
		  goto error;
		}
	    }
	}
    }
error:
  if (err)
    sqlc_resignal_1 (sc->sc_cc, err);
  return best_mtd_inx;
}


static int
udt_get_default_constructor_method_inx (sql_class_t * udt)
{
  int inx;

  if (!udt->scl_member_map)
    return -1;

  for (inx = 0; inx < UDT_N_METHODS (udt); inx++)
    {
      sql_method_t *mtd = &(udt->scl_methods[inx]);
      if (mtd->scm_type == UDT_METHOD_CONSTRUCTOR &&
	  UDT_N_SIG_ELTS (mtd->scm_signature) == 1)
	return inx;
    }

  return -1;
}


int
sqlc_udt_method_call (sql_comp_t * sc, char *name, dk_set_t * code,
    state_slot_t * ret, state_slot_t ** params, caddr_t ret_param,
    caddr_t type_name)
{
  if (type_name)
    {
      if (DV_ARRAY_OF_POINTER == DV_TYPE_OF (type_name))
	return sqlc_udt_dynamic_method_call (sc, name, code, ret, params,
	    ret_param, ((caddr_t *)type_name)[0]);
      if (type_name == ((caddr_t) ((ptrlong) 1)))
	return sqlc_udt_dynamic_method_call (sc, name, code, ret, params,
	    ret_param, NULL);
      else
	return sqlc_udt_static_method_call (sc, name, code, ret, params, ret_param,
	    type_name);
    }
  else
    return 0;
}


static ST *
sqlo_check_scope_variable (sqlo_t *so, sql_comp_t *sc, caddr_t name)
{
  caddr_t var_to_be = NULL;
  char *dots[MAX_NAME_LEN];
  int inx, name_len = (int) strlen (name), dots_inx;
  ST *res = NULL;
  caddr_t var_to_be_auto[6];
  BOX_AUTO (var_to_be, var_to_be_auto, 3 * sizeof (caddr_t), DV_ARRAY_OF_POINTER);

  dots_inx = 0;
  dots[dots_inx++] = NULL;
  for (inx = 0; inx < name_len && dots_inx < MAX_NAME_LEN; inx++)
    {
      if (name[inx] == '.')
	{
	  dots[dots_inx++] = &(name[inx]);
	}
    }
  for (inx = dots_inx - 1; inx >= 0; inx--)
    {
      ((caddr_t *)var_to_be)[0] = (caddr_t) (ptrlong) COL_DOTTED;
      if (inx < dots_inx - 1)
	*(dots[inx + 1]) = 0;
      if (dots[inx])
	{
	  *(dots[inx]) = 0;
	  ((caddr_t *)var_to_be)[1] = t_box_string (name);
	  *(dots[inx]) = '.';
	  ((caddr_t *)var_to_be)[2] = t_box_string (dots[inx] + 1);
	}
      else
	{
	  ((caddr_t *)var_to_be)[1] = NULL;
	  ((caddr_t *)var_to_be)[2] = t_box_string (name);
	}
      if (inx < dots_inx - 1)
	*(dots[inx + 1]) = '.';

      if (so)
	{
	  ST *var_to_be_copy = (ST *) t_box_copy_tree ((caddr_t) var_to_be);
	  if (sqlo_col_scope_1 (so, var_to_be_copy, 0))
	    break;
	}
      else if (sqlo_col_or_param_1 (sc, (ST *) var_to_be, 0))
	break;
    }
  if (inx >= 0)
    { /* some var found */
      res = (ST *) t_box_copy_tree ((caddr_t) var_to_be);
      for (inx += 1; inx < dots_inx; inx++)
	{
	  if (inx < dots_inx - 1)
	    *(dots[inx + 1]) = 0;
	  res = t_listst (3, CALL_STMT, t_box_string (dots[inx] ? dots[inx] + 1 : name), t_list (1, res));
	  if (inx < dots_inx - 1)
	    *(dots[inx + 1]) = '.';
	}
    }
  BOX_DONE (var_to_be, var_to_be_auto);
  return res;
}


ST *
sqlo_udt_check_method_call (sqlo_t * so, sql_comp_t * sc, ST * tree)
{
  char *ptr;
  if (BOX_ELEMENTS (tree) < 5 && DV_TYPE_OF (tree->_.call.name) != DV_ARRAY_OF_POINTER &&
      NULL != (ptr = strrchr (tree->_.call.name, '.')))
    {				/* not a method already */
      ST *var_to_be;
      char buffer[MAX_QUAL_NAME_LEN];

      *ptr = 0;
      strncpy (buffer, tree->_.call.name, sizeof (buffer) - 1);
      *ptr = '.';
      var_to_be = sqlo_check_scope_variable (so, sc, buffer);

      if (var_to_be)
	{
	  caddr_t identifier = t_box_string (ptr + 1);
	  caddr_t new_params =
	      t_alloc_box (box_length (tree->_.call.params) +
		  sizeof (caddr_t),
		  DV_ARRAY_OF_POINTER);
	  memcpy (&(((caddr_t *) new_params)[1]), tree->_.call.params,
	      box_length (tree->_.call.params));
	  ((ST **) new_params)[0] = var_to_be;
	  tree =
	      t_listst (5, CALL_STMT, identifier, new_params, NULL,
		  (ptrlong) 1);
	}
    }
  return tree;
}


ST *
sqlo_udt_check_observer (sqlo_t * so, sql_comp_t * sc, ST * tree)
{ /* from COL_DOTTED */
  if (tree->_.col_ref.prefix)
    {
      ST *var_to_be;

      var_to_be = sqlo_check_scope_variable (so, sc, tree->_.col_ref.prefix);

      if (var_to_be)
	{
	  int n1 = box_length (tree);
	  ST *new_tree =
	      t_listst (3, CALL_STMT, tree->_.col_ref.name, t_list (1, var_to_be));
	  memcpy (tree, new_tree, n1);
	  tree = new_tree;
	}
    }
  return tree;
}


ST *
sqlo_udt_is_mutator (sqlo_t * so, sql_comp_t * sc, ST * lvalue)
{ /* from ASG_STMT */
  if (ST_COLUMN (lvalue, COL_DOTTED))
    {
      if (lvalue->_.col_ref.prefix)
	{
	  ST *var_to_be;

	  var_to_be = sqlo_check_scope_variable (so, sc, lvalue->_.col_ref.prefix);

	  if (var_to_be)
	    return var_to_be;
	}
    }
  else if (ST_P (lvalue, CALL_STMT))
    {
      if (BOX_ELEMENTS (lvalue->_.call.params) == 1)
	{ /* member observer becomes member mutator here */
	  return (ST *) t_box_num (1);
	}
      else
	SQL_GPF_T1 (sc ? sc->sc_cc : so->so_sc->sc_cc, "non-valid lvalue in mutator");
    }
  else
    SQL_GPF_T1 (sc ? sc->sc_cc : so->so_sc->sc_cc, "non-valid lvalue");
  return NULL;
}


ST *
sqlo_udt_make_mutator (sqlo_t * so, sql_comp_t * sc, ST * lvalue, ST *rvalue, ST *var_to_be)
{
  if (ST_COLUMN (lvalue, COL_DOTTED) && var_to_be)
    {
      ST *new_tree =
	  t_listst (3, CALL_STMT, lvalue->_.col_ref.name, t_list (2, var_to_be, rvalue));
      return new_tree;
    }
  else if (ST_P (lvalue, CALL_STMT) && BOX_ELEMENTS (lvalue->_.call.params) == 1)
    {
      ST *new_tree = (ST *) t_box_copy_tree ((caddr_t) lvalue);
      new_tree->_.call.params = (ST **) t_list (2, lvalue->_.call.params[0], rvalue);
      return new_tree;
    }
  SQL_GPF_T1 (sc ? sc->sc_cc : so->so_sc->sc_cc, "invalid make_mutator");
  return NULL;
}


ST *
sqlo_udt_check_mutator (sqlo_t * so, sql_comp_t * sc, ST * tree)
{ /* from ASG_STMT */
  ST *lvalue = (ST *) tree->_.op.arg_1;
  ST *rvalue = (ST *) tree->_.op.arg_2;
  ST *var_to_be = NULL;

  if (NULL != (var_to_be = sqlo_udt_is_mutator (so, sc, lvalue)))
    {
      ST *new_tree = sqlo_udt_make_mutator (so, sc, lvalue, rvalue, var_to_be);
      memcpy (tree, new_tree, box_length (tree));
      tree = new_tree;
    }
  return tree;
}


caddr_t
sqlp_udt_method_decl (int specific, int mtd_type,
    caddr_t mtd_name, caddr_t params_list, caddr_t opt_ret,
    caddr_t udt_name, caddr_t body, caddr_t alt_ret_type)
{
  dbe_schema_t *sc = wi_inst.wi_schema;
  sql_class_t *udt = sch_name_to_type (sc, udt_name);
  sql_method_t *mtd_found = NULL;
  int mtd_inx_found = 0;
  ST *ret = NULL;
  int inx;
  caddr_t *parms = NULL;
  client_connection_t *cli = sqlc_client ();

  if (!udt || !udt->scl_method_map || (!udt->scl_mem_only && !udt->scl_id))
    yy_new_error ("No class", "37000", "UD050");

  if (udt->scl_ext_lang != UDT_LANG_SQL)
    yy_new_error ("Method definition allowed only for SQL user defined types", "37000", "UD051");

  if (cli->cli_user && !sec_udt_check (udt, cli->cli_user->usr_g_id, cli->cli_user->usr_id, GR_EXECUTE))
    {
      char msg[300];
      snprintf (msg, sizeof (msg), "No permission to define methods of class %.200s", udt->scl_name);
      yy_new_error (msg, "42000", "UD101:SECURITY");
    }
  if (specific)
    {
      for (inx = 0; inx < UDT_N_METHODS (udt); inx++)
	{
	  sql_method_t *mtd = &(udt->scl_methods[inx]);
	  if (!strcmp (mtd->scm_specific_name, mtd_name))
	    {
	      mtd_found = mtd;
	      mtd_inx_found = inx;
	      goto done;
	    }
	}
    }
  else
    {
      caddr_t err = NULL;
      int n_sigs = BOX_ELEMENTS (params_list);
      sql_type_t ret_type;
      sql_type_t *sig =
	  (sql_type_t *) t_alloc_box (n_sigs * sizeof (sql_type_t), DV_BIN);
      memset (sig, 0, box_length (sig));
      memset (&ret_type, 0, sizeof (sql_type_t));
      udt_parm_list_to_sig (sc, params_list, NULL, NULL, sig, &err, udt, sqlc_client(), 0);
    report_error:
      if (err)
	{
	  char buffer[255], state[6];
	  strncpy (buffer, ERR_MESSAGE (err), sizeof (buffer));
	  strncpy (state, ERR_STATE (err), sizeof (state));
	  buffer[sizeof (buffer)-1] = 0;
	  state[sizeof (state)-1] = 0;
	  dk_free_tree (err);
	  yy_new_error (buffer, state, "UD052");
	}
      if (opt_ret)
	{
	  udt_data_type_ref_to_sqt (sc, opt_ret,
	      &ret_type, &err, 0, udt, sqlc_client());
	  if (err)
	    goto report_error;
	}

      for (inx = 0; inx < UDT_N_METHODS (udt); inx++)
	{
	  sql_method_t *mtd = &(udt->scl_methods[inx]);
	  if (mtd->scm_type == mtd_type && !strcmp (mtd_name, mtd->scm_name) &&
	      0 == udt_method_sig_distance (mtd->scm_signature, sig,
		1, 0) &&
	      (!opt_ret
	       || 0 == udt_sqt_distance (&(mtd->scm_signature[0]),
		 &ret_type)))
	    {
	      mtd_inx_found = inx;
	      mtd_found = mtd;
	      goto done;
	    }
	}
    }
done:

  if (!mtd_found)
    yy_new_error (t_box_sprintf (1000, "No method of name '%.200s' declared in UDT '%.200s' (or signature mismatch)", mtd_name, udt_name), "37000", "UD053");

  if (mtd_found->scm_type != UDT_METHOD_STATIC)
    {
      parms =
	  (caddr_t *) t_alloc_box (box_length (params_list) +
	  sizeof (caddr_t), DV_ARRAY_OF_POINTER);
      memcpy (&(parms[1]), params_list, box_length (params_list));
      parms[0] = (caddr_t) t_list (6, LOCAL_VAR, INOUT_MODE,
	  t_list (3, COL_DOTTED, NULL, t_box_string ("SELF")),
	  t_list (4, (ptrlong) DV_OBJECT, (ptrlong)0, (ptrlong)0, udt->scl_name), NULL, NULL);
    }
  else
    parms = (caddr_t *) params_list;
  ret =
      t_listst (8, ROUTINE_DECL, FUNCTION, mtd_found->scm_specific_name,
	  parms, opt_ret, body, alt_ret_type,
	  t_list (2,
	    udt->scl_mem_only ? t_box_string (udt->scl_name) : t_box_num (udt->scl_id),
	    t_box_num (mtd_inx_found)
	    )
      );
  return (caddr_t) ret;
}


caddr_t
sqlp_udt_identifier_chain_to_member_handler (dk_set_t idents, caddr_t args, int is_observer)
{
  int set_len = dk_set_length (idents);
  int pref_len = 0, inx;
  caddr_t pref = NULL;
  s_node_t *iter;
  caddr_t member_name = NULL, obj_name = NULL;

  if (set_len < 3)
    SQL_GPF_T1 (top_sc->sc_cc, "Invalid member observer identifier chain");
  for (iter = idents, inx = 0; iter != NULL && inx < set_len - 2; iter = iter->next, inx++)
    {
      pref_len += (int) strlen ((char *) iter->data);
    }
  obj_name = (caddr_t) iter->data;
  member_name = (caddr_t) iter->next->data;

  pref = t_alloc_box (pref_len + set_len - 2, DV_SHORT_STRING);
  pref[0] = 0;
  for (iter = idents, inx = 0; iter != NULL && inx < set_len - 2; iter = iter->next, inx++)
    {
      strcat_box_ck (pref, (char *) iter->data);
      if (inx < set_len - 3)
	strcat_box_ck (pref, ".");
    }
  if (is_observer)
    return (caddr_t) t_list (3, CALL_STMT, member_name,
	t_list (1,
	  t_list  (3, COL_DOTTED, pref, obj_name)));
  else
    return (caddr_t) t_list (5, CALL_STMT, member_name,
	t_list_to_array (t_CONS (
	    t_list  (3, COL_DOTTED, pref, obj_name), args)), NULL, (ptrlong) 1);
}

query_t *
sqlc_udt_store_method_def (sql_comp_t *sc, client_connection_t *cli, int cr_type, query_t *qr, const char * string2, caddr_t *err)
{
  long mtd_id  = DV_TYPE_OF (qr->qr_udt_mtd_info[0]) == DV_LONG_INT ? (long) unbox (qr->qr_udt_mtd_info[0]) : 0;
  caddr_t mtd_name = DV_TYPE_OF (qr->qr_udt_mtd_info[0]) == DV_LONG_INT ? NULL : qr->qr_udt_mtd_info[0];
  long mtd_index = (long) unbox (qr->qr_udt_mtd_info[1]);
  sql_class_t *udt;
  sql_method_t *mtd;
  user_t * p_user = cli->cli_user;

  if (mtd_id)
    {
      udt = sch_id_to_type (wi_inst.wi_schema, mtd_id);
    }
  else
      udt = sch_name_to_type (wi_inst.wi_schema, mtd_name);
  if (!udt || !udt->scl_method_map || mtd_index < 0 || mtd_index > UDT_N_METHODS (udt))
    {
      if (err)
	*err = srv_make_new_error ("37000", "UD054", "Invalid class for the method definition");
      query_free (qr);
      qr = NULL;
      goto finish;
    }

  mtd = &(udt->scl_methods[mtd_index]);

  if (p_user && !sec_user_has_group (0, p_user->usr_g_id))
    {
      char q[MAX_NAME_LEN], o[MAX_NAME_LEN], n[MAX_NAME_LEN];
      sch_split_name (NULL, qr->qr_proc_name, q, o, n);
      if (p_user->usr_name && o[0] != 0 && CASEMODESTRCMP (p_user->usr_name, o))
	{
	  if (err)
	    *err = srv_make_new_error ("42000", "SQ076",
		"The method owner specified is different than the creator.");
	  query_free (qr);
	  qr = NULL;
	  goto finish;
	}
    }
  mtd->scm_qr = qr;

  if (p_user) /*always must set the owner of qr not inside of sqlc_make_proc_store_qr */
    qr->qr_proc_owner = p_user->usr_id;


  if (cr_type != SQLC_DO_NOT_STORE_PROC)
    {
      qr = sqlc_make_proc_store_qr (cli, qr, string2);
    }
finish:
  return qr;
}

static query_t *mtd_st_query;

void
ddl_store_method (caddr_t * state, op_node_t * op)
{
  query_instance_t *qi = (query_instance_t *) QST_INSTANCE (state);
  client_connection_t *cli = qi->qi_client;
  caddr_t err;
  char *text = qst_get (state, op->op_arg_2);
  char *name = qst_get (state, op->op_arg_1);
  caddr_t *mtd_info = (caddr_t *) qst_get (state, op->op_arg_3);
  long udt_id = DV_TYPE_OF (mtd_info[0]) == DV_LONG_INT ? (long) unbox (mtd_info[0]) : 0;
  long mtd_id = (long) unbox (mtd_info[1]);
  char *sch = cli->cli_qualifier;
  caddr_t udt_name = DV_TYPE_OF (mtd_info[0]) == DV_LONG_INT ? NULL : mtd_info[0];
  caddr_t escapes_text = NULL;

  if (udt_name)
    {
      caddr_t *log_array = (caddr_t *) dk_alloc_box (1 * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
      log_array[0] = box_string (text);
      log_text_array (qi->qi_trx, (caddr_t) log_array);
      dk_free_tree ((box_t) log_array);
      return;
    }
  if (!mtd_st_query)
    {
      mtd_st_query = sql_compile (
	  "insert replacing DB.DBA.SYS_METHODS "
	    "(M_ID, M_OFS, M_NAME, M_TEXT, M_OWNER, M_QUAL) "
	    "values (?, ?, ?, ?, ?, ?)",
	  bootstrap_cli, NULL, SQLC_DEFAULT);
    }

  if (cli->cli_not_char_c_escape || cli->cli_utf8_execs)
    {
      escapes_text = dk_alloc_box (strlen (text) +
	  (cli->cli_not_char_c_escape ? 18 : 0) +
	  (cli->cli_utf8_execs ? 19 : 0), DV_SHORT_STRING);
      escapes_text[0] = 0;
      if (cli->cli_not_char_c_escape)
	strcat_box_ck (escapes_text, "\n--no_c_escapes+\n");
      if (cli->cli_utf8_execs)
	strcat_box_ck (escapes_text, "\n--utf8_execs=yes\n");
      strcat_box_ck (escapes_text, text);
      text = escapes_text;
    }

  err = qr_rec_exec (mtd_st_query, cli, NULL, qi, NULL, 6,
      ":0", (ptrlong) (udt_id - 1), QRP_INT,
      ":1", (ptrlong) mtd_id, QRP_INT,
      ":2", name, QRP_STR,
      ":3", text, QRP_STR,
      ":4", CLI_OWNER (cli), QRP_STR,
      ":5", sch, QRP_STR);

  if (escapes_text)
    dk_free_box (escapes_text);
  if (err != SQL_SUCCESS)
    sqlr_resignal (err);
  else
    {
      caddr_t *log_array = (caddr_t *) dk_alloc_box (3 * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
      log_array[0] = box_string ("__method_changed (?, ?)");
      log_array[1] = box_num (udt_id);
      log_array[2] = box_num (mtd_id);
      log_text_array (qi->qi_trx, (caddr_t) log_array);
      dk_free_tree ((box_t) log_array);
    }
}


static caddr_t
bif_udt_method_changed (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  long udt_id = (long) bif_long_arg (qst, args, 0, "__method_changed");
  long mtd_id = (long) bif_long_arg (qst, args, 1, "__method_changed");

  query_instance_t *qi = (query_instance_t *) qst;
  client_connection_t *cli = qi->qi_trx->lt_client;
  user_t *org_user = cli->cli_user;
  caddr_t org_qual = cli->cli_qualifier;
  query_t *proc_qr, *rdproc;
  caddr_t err;
  local_cursor_t *lc = NULL;

  rdproc = sql_compile (
      "select blob_to_string (M_TEXT), M_OWNER, M_QUAL "
      "from DB.DBA.SYS_METHODS where M_ID = ? and M_OFS = ?",
      cli, &err, SQLC_DEFAULT);
  if (!err)
    {
      err = qr_rec_exec (rdproc, cli, &lc, qi, NULL, 2,
	  ":0", (ptrlong) (udt_id - 1), QRP_INT,
	  ":1", (ptrlong) mtd_id, QRP_INT
	  );
    }
  CLI_QUAL_ZERO (cli);
  if (!err && lc_next (lc))
    {
      char *text = lc_nth_col (lc, 0);
      char *owner = lc_nth_col (lc, 1);
      char *qual = lc_nth_col (lc, 2);
      user_t *owner_user = sec_name_to_user (owner);

      if (0 == strcmp (qual, "S"))
	qual = "DB";

      CLI_SET_QUAL (cli, qual);
      if (owner_user)
	cli->cli_user = owner_user;
      else
	{
	  log_error ("Method with bad owner, owner = %s", owner);
	  goto end;
	}
      proc_qr = sql_compile (text, cli, &err, SQLC_DO_NOT_STORE_PROC);
      if (err)
	{
	  if (text && strlen (text) > 60)
	    text[59] = 0;
	  log_error ("Error compiling method %s : %s",
	      ((caddr_t *) err)[QC_ERRNO], ((caddr_t *) err)[QC_ERROR_STRING],
	      text);
	  goto end;
	}
      /*cli->cli_user = org_user;
      cli->cli_qualifier = org_qual;*/
    }
end:
  cli->cli_user = org_user;
  CLI_RESTORE_QUAL (cli, org_qual);

  if (lc)
    lc_free (lc);
  if (err)
    dk_free_tree (err);
  qr_free (rdproc);
  return NULL;
}


void
udt_can_write_to (sql_type_t *sqt, caddr_t data, caddr_t *err_ret)
{
  dtp_t dtp = DV_TYPE_OF (data);
  if (sqt->sqt_dtp == DV_BLOB && sqt->sqt_class && !strcmp (sqt->sqt_class->scl_name, "DB.DBA.__ANY"))
    {
      if (dtp != DV_BLOB_WIDE_HANDLE)
	return;
      *err_ret = srv_make_new_error ("22023", "UD055", "Can't write a wide blob handle into a long any column,.  Cast to string or string output first.");
      return;
    }
  if ((sqt->sqt_col_dtp == DV_OBJECT || sqt->sqt_col_dtp == DV_BLOB) && sqt->sqt_class &&
      DV_TYPE_OF (data) == DV_OBJECT &&
      UDT_I_CLASS (data) &&
      udt_instance_of (UDT_I_CLASS (data), sqt->sqt_class))
    {
      return;
    }
  *err_ret = srv_make_new_error ("22023", "UD055", "Can't write to an user defined type column");
}

static int
ref_serialize (caddr_t box, dk_session_t * session)
{
  size_t length = box_length (box);
  if (length < 256)
    {
      session_buffered_write_char (DV_SHORT_REF, session);
      session_buffered_write_char ((char) length, session);
    }
  else
    {
      session_buffered_write_char (DV_REFERENCE, session);
      print_long ((long) length, session);
    }
  session_buffered_write (session, box, length);
  return (int) length;
}

static void *
box_read_short_ref (dk_session_t *session, dtp_t dtp)
{
  size_t length = session_buffered_read_char (session);
  char *ref = (char *) dk_alloc_box (length, DV_REFERENCE);
  session_buffered_read (session, ref, (int) length);
  return (void *) ref;
}


static void *
box_read_long_ref (dk_session_t *session, dtp_t dtp)
{
  size_t length = (size_t) read_long (session);
  char *ref;
  if (length >= MAX_BOX_LENGTH)
    box_read_error (session, dtp);
  ref = (char *) dk_alloc_box (length, DV_REFERENCE);
  session_buffered_read (session, ref, (int) length);
  return (void *) ref;
}

caddr_t
udt_mp_copy (mem_pool_t * mp, caddr_t box)
{
  caddr_t cp = NULL;
  if (UDT_I_CLASS (box) == XMLTYPE_CLASS)
    cp = xe_make_copy (box);
  else
    cp = box_copy (box);
  dk_set_push (&mp->mp_trash, (void*)cp);
  return cp;
}



void
udt_ses_init (void)
{
  macro_char_func *rt = get_readtable ();
  dk_mem_hooks (DV_OBJECT, (box_copy_f) udt_instance_copy,
      (box_destr_f) udt_instance_destroy, 0);
  PrpcSetWriter (DV_OBJECT, (ses_write_func) udt_serialize);
  box_tmp_copier[DV_OBJECT] = udt_mp_copy;
  rt[DV_OBJECT] = udt_deserialize;
  PrpcSetWriter (DV_REFERENCE, (ses_write_func) ref_serialize);
  rt[DV_SHORT_REF] = box_read_short_ref;
  rt[DV_REFERENCE] = box_read_long_ref;
}


caddr_t
udt_i_find_member_address (caddr_t *qst, state_slot_t *actual_ssl,
    code_vec_t code_vec, instruction_t *ins)
{
  caddr_t res = (caddr_t) qst_address (qst, actual_ssl);
  DO_INSTR (c_ins, 0, code_vec)
    {
      if (c_ins >= ins)
	break;
      if (c_ins->ins_type == INS_CALL_BIF && c_ins->_.call.ret == actual_ssl &&
	  c_ins->_.bif.bif == bif_udt_member_handler &&
	  BOX_ELEMENTS (c_ins->_.call.params) == 3)
	{
	  caddr_t udi = qst_get (qst, c_ins->_.call.params[2]);
	  long fld_inx;
	  sql_class_t *udt;

	  if (DV_TYPE_OF (udi) == DV_REFERENCE)
	    udi = udo_find_object_by_ref (udi);

	  fld_inx = (long) unbox (qst_get (qst, c_ins->_.call.params[1]));
	  udt = UDT_I_CLASS (udi);

	  if (udt && udt->scl_ext_lang == UDT_LANG_SQL && fld_inx >= 0 &&
	      fld_inx <= BOX_ELEMENTS_INT (udt->scl_member_map))
	    {
	      res = (caddr_t) &(UDT_I_VAL(udi, fld_inx));
	    }
	}
    }
  END_DO_INSTR;
  return res;
}

static caddr_t
bif_udt_instance_of (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  sql_class_t *udt = bif_udt_arg (qst, args, 0, "udt_instance_of");

  if (BOX_ELEMENTS (args) > 1)
    {
      sql_class_t *sudt = bif_udt_arg (qst, args, 1, "udt_instance_of");
      return box_num (udt_instance_of (udt, sudt));
    }
  else
    return box_dv_short_string (udt->scl_name);
}


static caddr_t
bif_udt_implements_method (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  sql_class_t *udt = bif_udt_arg (qst, args, 0, "udt_implements_method");
  caddr_t method_name = bif_string_arg (qst, args, 1, "udt_implements_method");
  int type = BOX_ELEMENTS (args) > 2 ? UDT_METHOD_CONSTRUCTOR : UDT_METHOD_INSTANCE;
  int inx;

  if (udt->scl_method_map)
    {
      if (UDT_METHOD_INSTANCE == type)
	{
	  ptrlong *place  = (ptrlong *) id_hash_get (udt->scl_name_to_method, (caddr_t) &method_name);
	  if (!place)
	    return NULL;
	  return list (2,
		       box_dv_short_string (udt->scl_name),
		       box_num (*place));
	}
      DO_BOX (sql_method_t *, mtd, inx, udt->scl_method_map)
	{
	  if (mtd->scm_type == type
	      && !CASEMODESTRCMP (method_name, mtd->scm_name))
	    {
	      caddr_t ret = list (2,
		  box_dv_short_string (udt->scl_name),
		  box_num (inx));
	      return ret;
	    }
	}
      END_DO_BOX;
    }
  return NULL;
}


static caddr_t
bif_udt_defines_field (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  sql_class_t *udt = bif_udt_arg (qst, args, 0, "udt_defines_field");
  caddr_t fld_name = bif_string_arg (qst, args, 1, "udt_defines_field");

  if (-1 != udt_find_field (udt->scl_member_map, fld_name))
    return box_num (1);
  return NULL;
}


static caddr_t
bif_udt_get (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t ref = NULL;
  caddr_t udi = bif_udt_i_arg (qst, args, 0, "udt_get", &ref);
  caddr_t fld_name = bif_string_arg (qst, args, 1, "udt_get");
  int fld_inx = -1;
  sql_class_t *udt = UDT_I_CLASS (udi);

  if (!udt || -1 == (fld_inx = udt_find_field (udt->scl_member_map, fld_name)))
    sqlr_new_error ("22023", "UD056",
	"No field %.200s in the user defined type %.200s",
	fld_name,
	udt ? udt->scl_name : "<unknown>");
  return udt_member_observer (qst, udi, udt->scl_member_map[fld_inx], fld_inx);
}


static caddr_t
bif_udt_set (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t ref = NULL;
  caddr_t udi = bif_udt_i_arg (qst, args, 0, "udt_set", &ref);
  caddr_t fld_name = bif_string_arg (qst, args, 1, "udt_set");
  caddr_t val = bif_arg (qst, args, 2, "udt_set");
  int fld_inx = -1;
  sql_class_t *udt = UDT_I_CLASS (udi);

  if (!udt || -1 == (fld_inx = udt_find_field (udt->scl_member_map, fld_name)))
    sqlr_new_error ("22023", "UD057",
	"No field %.200s in the user defined type %.200s",
	fld_name,
	udt ? udt->scl_name : "<unknown>");
  if (ref)
    {
      udi = udt_member_mutator (qst, udi, udt->scl_member_map[fld_inx], fld_inx, val);
      return box_copy_tree (ref);
    }
  else
    {
      udi = box_copy_tree (udi);
      udi = udt_member_mutator (qst, udi, udt->scl_member_map[fld_inx], fld_inx, val);
      return udi;
    }
}


static int
udt_ext_lang_by_name (char *ext_lang_name)
{
  if (!stricmp (ext_lang_name, "java"))
    return UDT_LANG_JAVA;
  else if (!stricmp (ext_lang_name, "clr"))
    return UDT_LANG_CLR;
  else if (!stricmp (ext_lang_name, "sql"))
    return UDT_LANG_SQL;
  else
    return UDT_LANG_NONE;
}


static caddr_t
bif_udt_find_by_ext_type (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t ext_lang_name = bif_string_arg (qst, args, 0, "udt_find_by_ext_type");
  dbe_schema_t *sc = isp_schema (qi->qi_space);
  long ext_lang = udt_ext_lang_by_name (ext_lang_name);
  dk_set_t list = NULL;

  sql_class_t **pcls;
  id_casemode_hash_iterator_t it;

  id_casemode_hash_iterator (&it, sc->sc_name_to_object[sc_to_type]);

  while (id_casemode_hit_next (&it, (caddr_t *) & pcls))
    {
      sql_class_t *udt = *pcls;
      if (udt->scl_method_map && udt->scl_ext_lang == ext_lang)
	{
	  char buffer[MAX_QUAL_NAME_LEN + 7];
	  snprintf (buffer, sizeof (buffer), "\"%.100s\".\"%.100s\".\"%.100s\"",
	      udt->scl_qualifier, udt->scl_owner, udt->scl_name_only);
	  dk_set_push (&list, box_dv_short_string (buffer));
	}
    }
  return list_to_array (dk_set_nreverse (list));
}


static caddr_t
bif_udt_find_by_ext_name (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t ext_lang_name = bif_string_arg (qst, args, 0, "udt_find_by_ext_name");
  caddr_t ext_name = bif_string_arg (qst, args, 1, "udt_find_by_ext_name");
  query_instance_t *qi = (query_instance_t *) qst;
  caddr_t qual = qi->qi_client->cli_qualifier;
  dbe_schema_t *sc = isp_schema (qi->qi_space);
  long ext_lang = udt_ext_lang_by_name (ext_lang_name);

  sql_class_t **pcls;
  id_casemode_hash_iterator_t it;

  if (BOX_ELEMENTS (args) > 2)
    qual = bif_string_or_null_arg (qst, args, 2, "udt_find_by_ext_name");
  id_casemode_hash_iterator (&it, sc->sc_name_to_object[sc_to_type]);

  while (id_casemode_hit_next (&it, (caddr_t *) & pcls))
    {
      sql_class_t *udt = *pcls;
      if (udt->scl_method_map && udt->scl_ext_lang == ext_lang &&
	  udt->scl_ext_name &&
	  (!qual || !CASEMODESTRCMP (qual, udt->scl_qualifier)) &&
	  !strcmp (udt->scl_ext_name, ext_name))
	{
	  char buffer[MAX_QUAL_NAME_LEN + 7];
	  snprintf (buffer, sizeof (buffer), "\"%.100s\".\"%.100s\".\"%.100s\"",
	      udt->scl_qualifier, udt->scl_owner, udt->scl_name_only);
	  return box_dv_short_string (buffer);
	}
    }
  return NULL;
}


static void
ddl_udt_find_deps (dbe_schema_t *sc, caddr_t *err_ret, char *uid, sql_class_t *mudt, dk_set_t *pset)
{
  id_casemode_hash_iterator_t it;
  sql_class_t **pudt;

  if (dk_set_member (*pset, mudt->scl_name))
    return;

  id_casemode_hash_iterator (&it, sc->sc_name_to_object[sc_to_type]);

  while (id_casemode_hit_next (&it, (caddr_t *) & pudt))
    {
      sql_class_t *udt = *pudt;
      if (udt && udt->scl_owner && !UDT_IS_SAME_CLASS (udt, mudt) &&
	  udt->scl_super && UDT_IS_SAME_CLASS (udt->scl_super, mudt))
	{
	  if (CASEMODESTRCMP (udt->scl_owner, uid))
	    {
	      *err_ret = srv_make_new_error ("42000", "UD063",
		  "Type %.255s depends on type %.255s. Drop it first", udt->scl_name, mudt->scl_name);
	      return;
	    }

	  ddl_udt_find_deps (sc, err_ret, uid, udt, pset);
	  if (*err_ret)
	    return;
	}
    }
  dk_set_pushnew (pset, mudt->scl_name);
}


static caddr_t
bif_ddl_udt_get_udt_list_by_user (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *)qst;
  dk_set_t set = NULL, out_set = NULL;
  caddr_t uid = bif_string_arg (qst, args, 0, "__ddl_udt_get_udt_list_by_user");
  dbe_schema_t *sc = isp_schema (NULL);
  id_casemode_hash_iterator_t it;
  sql_class_t **pudt;

  sec_check_dba (qi, "__ddl_udt_get_udt_list_by_user");

  if (!sec_name_to_user (uid))
    {
      *err_ret = srv_make_new_error ("22023", "UD104", "Non-existent user %.128s", uid);
      goto finish;
    }

  id_casemode_hash_iterator (&it, sc->sc_name_to_object[sc_to_type]);
  while (id_casemode_hit_next (&it, (caddr_t *) & pudt))
    {
      if (pudt && *pudt && !CASEMODESTRCMP ((*pudt)->scl_owner, uid)
	  && !(*pudt)->scl_migrate_to && !(*pudt)->scl_obsolete)
	ddl_udt_find_deps (sc, err_ret, uid, *pudt, &set);
      if (*err_ret)
	goto finish;
    }

finish:
  if (*err_ret)
    {
      dk_free_tree (list_to_array (set));
      set = NULL;
    }
  set = dk_set_nreverse (set);
  DO_SET (caddr_t, udt_name, &set)
    {
      dk_set_push (&out_set, box_dv_short_string (udt_name));
      dk_set_push (&out_set, box_num (1));
    }
  END_DO_SET ();
  dk_set_free (set);
  return list_to_array (dk_set_nreverse (out_set));
}

#define DEFAULT_EXISTING 1

static caddr_t
bif_complete_udt_name (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t result = NULL;
  caddr_t udt_name = bif_string_arg (qst, args, 0, "complete_udt_name");
  long mode = (long) bif_long_arg (qst, args, 1, "complete_udt_name");
  query_instance_t *qi = (query_instance_t *) qst;
  sql_class_t *udt = NULL;

  sqlc_set_client (qi->qi_client);
  if (mode == DEFAULT_EXISTING)
    {
      if (parse_mtx)
	parse_enter ();
      udt = sch_name_to_type (isp_schema (NULL), udt_name);
      if (parse_mtx)
	parse_leave ();
    }
  if (udt)
    {
      result = box_dv_short_string (udt->scl_name);
    }
  else
    {
      char q[MAX_NAME_LEN];
      char o[MAX_NAME_LEN];
      char n[MAX_NAME_LEN];
      char complete[MAX_QUAL_NAME_LEN];
      q[0] = 0;
      o[0] = 0;
      n[0] = 0;
      sch_split_name (qi->qi_client->cli_qualifier, udt_name, q, o, n);
      if (0 == o[0])
	strcpy_ck (o, cli_owner (qi->qi_client));
      snprintf (complete, sizeof (complete), "%s.%s.%s", q, o, n);
      result = box_dv_short_string (complete);
    }
  return result;
}


static caddr_t
bif_udt_get_info (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  sql_class_t *udt = bif_udt_arg (qst, args, 0, "udt_get_info");
  caddr_t info_name = bif_string_arg (qst, args, 1, "udt_get_info");
  caddr_t result = NULL;

  if (!stricmp (info_name, "children"))
    {
      id_casemode_hash_iterator_t it;
      dk_set_t children = NULL;
      dbe_schema_t *sc = isp_schema (NULL);
      sql_class_t **pudt;

      id_casemode_hash_iterator (&it, sc->sc_name_to_object[sc_to_type]);
      while (id_casemode_hit_next (&it, (caddr_t *) & pudt))
	{
	  if (pudt && *pudt && (*pudt)->scl_super == udt)
	    dk_set_push (&children, box_dv_short_string ((*pudt)->scl_name));
	}
      result = list_to_array (children);
    }
  else if (!stricmp (info_name, "parent"))
    {
      if (udt->scl_super)
	result = box_dv_short_string (udt->scl_super->scl_name);
    }
  else
    sqlr_new_error ("22023", "UD105", "Invalid info name. Valid infos are : children, parent");

  return result ? result : NEW_DB_NULL;
}


int
udt_is_udt_bif (bif_t bif)
{
  return
      (bif_udt_instantiate_class == bif
      || bif_udt_member_handler == bif
      || bif_udt_method_call == bif) ? 1 : 0;
}


void
bif_udt_init (void)
{
  bif_define ("__ddl_type_changed", bif_ddl_type_change);
  bif_define ("udt_is_available", bif_udt_is_available);
  bif_define_typed (UDT_INSTANTIATE_CLASS_BIF, bif_udt_instantiate_class,
      &bt_udt_instance);
  bif_set_uses_index (bif_udt_instantiate_class);
  bif_define (UDT_MEMBER_HANDLER_BIF, bif_udt_member_handler);
  bif_define (UDT_METHOD_CALL_BIF, bif_udt_method_call);
  bif_set_uses_index (bif_udt_method_call);
  bif_define ("__method_changed", bif_udt_method_changed);
  bif_define ("udt_instance_of", bif_udt_instance_of);
  bif_define ("udt_defines_field", bif_udt_defines_field);
  bif_define ("udt_implements_method", bif_udt_implements_method);
  bif_define ("udt_get", bif_udt_get);
  bif_define ("udt_set", bif_udt_set);
  bif_define ("udt_find_by_ext_name", bif_udt_find_by_ext_name);
  bif_define ("udt_find_by_ext_type", bif_udt_find_by_ext_type);
  bif_define ("__ddl_udt_get_udt_list_by_user", bif_ddl_udt_get_udt_list_by_user);
  bif_define_ex ("complete_udt_name", bif_complete_udt_name, BMD_RET_TYPE, &bt_varchar, BMD_DONE);
  bif_define_ex ("udt_get_info", bif_udt_get_info, BMD_RET_TYPE, &bt_any, BMD_DONE);


  imp_map[UDT_LANG_SQL].scli_instantiate_class = udt_sql_instantiate_class;
  imp_map[UDT_LANG_SQL].scli_instance_copy = udt_sql_instance_copy;
  imp_map[UDT_LANG_SQL].scli_instance_free = udt_sql_instance_free;
  imp_map[UDT_LANG_SQL].scli_member_observer = udt_sql_member_observer;
  imp_map[UDT_LANG_SQL].scli_member_mutator = udt_sql_member_mutator;
  imp_map[UDT_LANG_SQL].scli_method_call = udt_sql_method_call;
  imp_map[UDT_LANG_SQL].scli_serialize = udt_sql_serialize;
  imp_map[UDT_LANG_SQL].scli_deserialize = udt_sql_deserialize;
  udt_ses_init();
}

resource_t *udo_rc = NULL;

static object_space_t *
udo_alloc_object_space (void *cdata)
{
  NEW_VARZ (object_space_t, udo);
  udo->os_map = id_tree_hash_create (101);
  id_hash_set_rehash_pct (udo->os_map, 200);
  return udo;
}

static void
udo_clear_object_space (object_space_t *udo)
{
  id_hash_iterator_t hit;
  caddr_t *ref, *udi;

  if (!udo)
    return;
  id_hash_iterator (&hit, udo->os_map);
  while (hit_next (&hit, (char **) &ref, (char **) &udi))
    {
      dk_free_tree (*udi);
    }
  id_hash_iterator (&hit, udo->os_map);
  while (hit_next (&hit, (char **) &ref, (char **) &udi))
    {
      if (DV_REFERENCE == DV_TYPE_OF (*ref))
        {
#if 1
          box_tag_modify_impl (*ref, DV_NULL); /* This works correctly but prevents from debugging of double free */
          dk_free_box (*ref);
#else
          box_tag_modify_impl (*ref, TAG_BAD); /* This is of course a memory leak but nice to debug */
#endif
        }
      else
        dk_free_tree (*ref);
    }
  id_hash_clear (udo->os_map);
}


static void
udo_free_object_space (object_space_t *udo)
{
  if (udo)
    {
      udo_clear_object_space (udo);
      id_hash_free (udo->os_map);
      dk_free (udo, sizeof (object_space_t));
    }
}

object_space_t *
udo_new_object_space (object_space_t *parent)
{
  object_space_t *udo;
  if (!udo_rc)
    udo_rc = resource_allocate (100,
	(rc_constr_t) udo_alloc_object_space,
	(rc_destr_t) udo_free_object_space,
	(rc_destr_t) udo_clear_object_space, NULL);
  udo = (object_space_t *) resource_get (udo_rc);
  udo->os_parent = parent;
  return udo;
}

void
udo_object_space_clear (object_space_t *udo)
{
  if (NULL == udo)
    return;
  if (OBJECT_SPACE_NOT_SET == udo)
    return;
    resource_store (udo_rc, udo);
}


#if 0
caddr_t
udt_instantiate_from_key_ref (caddr_t ref)
{
  return NULL;
}


caddr_t
udo_find_object_by_ref (caddr_t ref)
{
  object_space_t *udo;
  caddr_t udi = NULL;
  object_space_t *curr_udo;

  if (DV_TYPE_OF (ref) != DV_REFERENCE)
    goto done;
  OBJECT_SPACE_GET (udo);
  curr_udo = udo;
  while (curr_udo && !udi)
    {
      caddr_t *udi_to_be = (caddr_t *) id_hash_get (curr_udo->os_map, (caddr_t) &ref);
      if (udi_to_be)
	udi = *udi_to_be;
      if (!udi)
	curr_udo = curr_udo->os_parent;
    }
  if (!udi)
    {
      key_id_t key_id = SHORT_REF (ref + IE_KEY_ID);
      if (key_id)
	{
	  udi = udt_instantiate_from_key_ref (ref);
	  if (udi) /* Never happens for a while: "database as a virtual memory for objects" feature is not implemented */
	    {
	      caddr_t udi_copy = box_copy_tree (udi);
	      ref = box_copy_tree (ref);
	      id_hash_set (udo->os_map, (caddr_t) &ref, (caddr_t) &udi_copy);
	      goto done;
	    }
	}
    }
done:
  return udi;
}


static caddr_t
udo_new_object_ref (object_space_t *udo, caddr_t udi, int copy_udi)
{
   caddr_t ref = dk_alloc_box (sizeof (int32) * 2, DV_REFERENCE);
   caddr_t udi_copy;
   LONG_SET (ref, 0);
   LONG_SET (ref + IE_FIRST_KEY, (long) udo->os_next_serial);
   udo->os_next_serial++;
   udi_copy = copy_udi ? box_copy_tree (udi) : udi;
   id_hash_set (udo->os_map, (caddr_t) &ref, (caddr_t) &udi_copy);
   return ref;
}

#else

caddr_t
udo_find_object_by_ref (caddr_t ref)
{
  if (DV_TYPE_OF (ref) != DV_REFERENCE)
    return NULL;
  else
    {
      object_space_t *udo;
      caddr_t *udi_to_be;
      OBJECT_SPACE_GET (udo);
      udi_to_be = (caddr_t *) id_hash_get (udo->os_map, (caddr_t) &ref);
      if (NULL == udi_to_be)
	return NULL;
      return *udi_to_be;
    }
}


caddr_t
udo_dbg_find_object_by_ref (query_instance_t *qi, caddr_t ref)
{
  if (DV_TYPE_OF (ref) != DV_REFERENCE)
    return NULL;
  else
    {
      object_space_t *udo;
      caddr_t *udi_to_be;
      OBJECT_SPACE_GET_FROM (udo,qi->qi_thread);
      udi_to_be = (caddr_t *) id_hash_get (udo->os_map, (caddr_t) &ref);
      if (NULL == udi_to_be)
	return NULL;
      return *udi_to_be;
    }
}

static caddr_t
udo_new_object_ref (caddr_t udi)
{
   object_space_t *udo;
   caddr_t ref = dk_alloc_box_zero (sizeof (int32) * 2, DV_REFERENCE);
   OBJECT_SPACE_GET (udo);
   LONG_SET (ref, 0);
   LONG_SET (ref + IE_FIRST_KEY, (long) udo->os_next_serial);
   udo->os_next_serial++;
   id_hash_set (udo->os_map, (caddr_t) &ref, (caddr_t) &udi);
   return ref;
}

#endif


void
dbg_udt_print_object (caddr_t udi, FILE *out)
{
  sql_class_t *udt = UDT_I_CLASS (udi);
  if (udt && udt->scl_member_map)
    {
      if (udt->scl_ext_lang == UDT_LANG_SQL)
	{
	  int i;
	  DO_BOX (sql_field_t *, fld, i, udt->scl_member_map)
	    {
	      caddr_t val = UDT_I_VAL(udi, i);
	      fprintf (out, "\t%s=", fld->sfl_name);
	      if (DV_TYPE_OF (val) != DV_REFERENCE)
		{
		  dbg_print_box (val, out);
		  fprintf (out, "\n");
		}
	      else
		fprintf (out, "\t<object ref>\n");
	    }
	  END_DO_BOX;
	}
      else
	{
	  switch (udt->scl_ext_lang)
	    {
	      case UDT_LANG_JAVA:
		  fprintf (out, "\tjvm obj %p %s\n", UDT_I_VAL (udi, 0), udt->scl_ext_name);
		  break;
	      case UDT_LANG_CLR:
		  fprintf (out, "\tclr obj %p %s\n", UDT_I_VAL (udi, 0), udt->scl_ext_name);
		  break;
	    }
	}
    }
  else if (udt)
    {
      fprintf (out, "\tnon-inst %s\n", udt->scl_name);
    }
}


int
udt_soap_struct_to_udi (caddr_t *place, dk_set_t *ret_set, caddr_t *ret_ptr, caddr_t *err_ret)
{
  sql_class_t *udt = NULL;
  caddr_t udi = NULL, udi_to_set = NULL;
  s_node_t *iter;
  int mtd_inx = -1;

  if (NULL == place)
    return 1;

  if (NULL == (udt = sch_name_to_type (isp_schema (NULL), *place)))
    {
      *err_ret = srv_make_new_error ("22023", "UD058", "No user defined type %.500s", *place);
      return 0;
    }

  mtd_inx = udt_get_default_constructor_method_inx (udt);

  QR_RESET_CTX
    {
      if (NULL == (udi = udt_instantiate_class (NULL, udt, mtd_inx, NULL, 0)))
	{
	  *err_ret = srv_make_new_error ("22023", "UD059", "Failed to make instance of the user defined type %.500s", udt->scl_name);
	  POP_QR_RESET;
	  return 0;
	}

      if (DV_TYPE_OF (udi) == DV_REFERENCE)
	udi_to_set = udo_find_object_by_ref (udi);
      else
	udi_to_set = udi;

      iter = *ret_set;
      while (NULL != iter)
	{
	  caddr_t value = (caddr_t) iter->data;
	  caddr_t name = iter->next ? (caddr_t) iter->next->data : NULL;

	  if (DV_TYPE_OF (name) == DV_COMPOSITE)
	    {
	      if (DV_TYPE_OF (value) == DV_ARRAY_OF_POINTER)
		{ /* we have attributes */
		  POP_QR_RESET;
		  *err_ret = srv_make_new_error ("22023", "UD060", "XML attributes not supported with user defined types");
		  goto error;
		}
	    }
	  else if (DV_STRINGP (name))
	    {
	      int inx;
	      int is_set = 0;
	      DO_BOX (sql_field_t *, fld, inx, udt->scl_member_map)
		{
		  caddr_t fld_soap_name = fld->sfl_soap_name ? fld->sfl_soap_name : fld->sfl_name;

		  if (!CASEMODESTRCMP (fld_soap_name, name))
		    {
		      udt_member_mutator (NULL, udi_to_set, fld, inx, value);
		      is_set = 1;
		      break;
		    }
		}
	      END_DO_BOX;
	      if (!is_set)
		{
		  *err_ret = srv_make_new_error ("22023", "UD061", "No member %.200s in the user defined type %.200s", name, udt->scl_name);
		  POP_QR_RESET;
		  goto error;
		}
	    }

	  iter = iter->next;
	  if (iter)
	    iter = iter->next;
	}

      dk_free_tree (list_to_array (*ret_set));
      *ret_set = NULL;
      *ret_ptr = udi;
    }
  QR_RESET_CODE
    {
      POP_QR_RESET;
      *err_ret = thr_get_error_code (THREAD_CURRENT_THREAD);
      thr_set_error_code (THREAD_CURRENT_THREAD, NULL);
      goto error;
    }
  END_QR_RESET;
  return 1;

error:
  dk_free_box (udi);
  return 0;
}


static UST *
udt_add_attribute (sql_class_t *udt, UST *udt_tree, UST *ufld, caddr_t *err_ret, dk_set_t derived_udts)
{
  int n_elements;
  caddr_t *new_representation;
  if (IS_DISTINCT_TYPE (udt_tree))
    {
      *err_ret = srv_make_new_error ("37000", "UD064",
	  "Type %.300s is DISTINCT. ALTER TYPE ADD ATTRIBUTE for distinct types is not supported",
	  udt->scl_name);
      goto error;
    }

  if (-1 != udt_find_field (udt->scl_member_map, ufld->_.member.name))
    {
      *err_ret = srv_make_new_error ("37000", "UD065",
	  "Field with name %.300s is already defined(inherited) for type %.300s",
	  ufld->_.member.name, udt->scl_name);
      goto error;
    }
  DO_SET (sql_class_t *, sudt, &derived_udts)
    {
      int inx;
      for (inx = 0; inx < UDT_N_FIELDS (sudt); inx ++)
	{
	  if (!strcmp (sudt->scl_fields[inx].sfl_name, ufld->_.member.name))
	    {
	      *err_ret = srv_make_new_error ("42S22", "UD081",
		  "Field with name %s defined for type %s, which is an derived type of %s.",
		  ufld->_.member.name, sudt->scl_name, udt->scl_name);
	      goto error;
	    }
	}
    }
  END_DO_SET ();

  n_elements = ARRAYP (udt_tree->_.type.representation) ?
      BOX_ELEMENTS (udt_tree->_.type.representation) : 0;
  new_representation = (caddr_t *) dk_alloc_box (
      (n_elements + 1) * sizeof (caddr_t),
      DV_ARRAY_OF_POINTER);
  if (n_elements)
    memcpy (new_representation, udt_tree->_.type.representation,
	n_elements * sizeof (caddr_t));
  new_representation [n_elements] = box_copy_tree ((box_t) ufld);

  dk_free_box ((box_t) udt_tree->_.type.representation);
  udt_tree->_.type.representation = (UST *) new_representation;

  return udt_tree;

error:
  dk_free_tree ((box_t) udt_tree);
  return NULL;
}


static dk_set_t
udt_get_derived_classes (dbe_schema_t *sc, sql_class_t *udt)
{
  dk_set_t derived = NULL;
  id_casemode_hash_iterator_t it;
  sql_class_t **pcls;

  id_casemode_hash_iterator (&it, sc->sc_name_to_object[sc_to_type]);

  while (id_casemode_hit_next (&it, (caddr_t *) & pcls))
    {
      sql_class_t *cls = *pcls;
      if (udt_instance_of (cls, udt))
	dk_set_push (&derived, cls);
    }
  return derived;
}


static void
udt_change_refs_to_type_name (caddr_t *tree, dk_set_t derived_udts)
{
  if (!tree || !*tree)
    return;
  switch (DV_TYPE_OF (*tree))
    {
      case DV_SYMBOL:
      case DV_STRING:
	  DO_SET (sql_class_t *, udt, &derived_udts)
	    {
	      if (!strcmp (*tree, udt->scl_name))
		{
		  char udt_old_name [MAX_QUAL_NAME_LEN];
		  dk_free_box (*tree);
		  snprintf (udt_old_name, sizeof (udt_old_name), "%.300s__%ld", udt->scl_name, udt->scl_id - 1);
		  *tree = sqlp_box_id_upcase (udt_old_name);
		  break;
		}
	    }
	  END_DO_SET();
	  break;
      case DV_ARRAY_OF_POINTER:
	    {
	      int i;
	      for (i = 0; i < BOX_ELEMENTS_INT (*tree); i++)
		udt_change_refs_to_type_name (&(((caddr_t *)(*tree))[i]), derived_udts);
	    }
	  break;
    }
}

static UST *
udt_get_parse_tree (query_instance_t *qi, char *name, long id)
{
  caddr_t err = NULL;
  local_cursor_t *lc = NULL;
  UST *ret;

  err = qr_rec_exec (udt_get_tree_by_id_qr, qi->qi_client, &lc, qi, NULL, 2,
      ":0", name, QRP_STR,
      ":1", (ptrlong) (id - 1), QRP_INT);
  if (err)
    {
      LC_FREE (lc);
      sqlr_resignal (err);
    }

  if (!lc_next (lc))
    {
      lc_free (lc);
      sqlr_new_error ("42S22", "UD082",
	  "The definition of type %s not found in SYS_USER_TYPES",
	  name);
    }
  ret = (UST *) box_copy_tree (lc_nth_col (lc, 0));
  lc_free (lc);
  return ret;
}


static UST *
udt_drop_attribute (sql_class_t *udt, UST *udt_tree, caddr_t ufld, caddr_t *err_ret, dk_set_t derived_udts)
{
  int n_elements, inx, found_inx = -1;
  caddr_t *new_representation;
  if (IS_DISTINCT_TYPE (udt_tree))
    {
      *err_ret = srv_make_new_error ("37000", "UD083",
	  "Type %.300s is DISTINCT. ALTER TYPE DROP ATTRIBUTE for distinct types is not supported",
	  udt->scl_name);
      goto error;
    }

  DO_BOX (UST *, field, inx, ((UST **)udt_tree->_.type.representation))
    {
      if (!strcmp (field->_.member.name, ufld))
	found_inx = inx;
    }
  END_DO_BOX;

  if (-1 == found_inx)
    {
      *err_ret = srv_make_new_error ("37000", "UD084",
	  "No field with name %.300s for type %.300s",
	  ufld, udt->scl_name);
      goto error;
    }
  n_elements = ARRAYP (udt_tree->_.type.representation) ?
      BOX_ELEMENTS (udt_tree->_.type.representation) : 0;
  new_representation = (caddr_t *) dk_alloc_box (
      (n_elements - 1) * sizeof (caddr_t),
      DV_ARRAY_OF_POINTER);

  if (found_inx)
    memcpy (new_representation, udt_tree->_.type.representation,
	found_inx * sizeof (caddr_t));
  if (found_inx + 1 < n_elements)
    memcpy (&new_representation[found_inx], &((UST **)udt_tree->_.type.representation)[found_inx + 1],
	(n_elements - found_inx - 1) * sizeof (caddr_t));

  dk_free_box ((box_t) udt_tree->_.type.representation);
  udt_tree->_.type.representation = (UST *) new_representation;

  return udt_tree;

error:
  dk_free_tree ((box_t) udt_tree);
  return NULL;
}


static UST *
udt_add_method (sql_class_t *udt, UST *udt_tree, UST *mtd, caddr_t *err_ret, dk_set_t derived_udts,
    dbe_schema_t *sc, client_connection_t *cli)
{
  sql_type_t *signature = NULL;
  int n_args, n_methods, inx;
  caddr_t *new_methods;
  UST *mt = mtd->_.method_def.method;

  n_args = (ARRAYP (mt->_.method.parms) ? BOX_ELEMENTS (mt->_.method.parms) : 0) + 1;

  if (!udt || !udt->scl_method_map)
    {
      *err_ret =
	  srv_make_new_error ("37000", "UD085", "User defined type %s is not instantiable",
	  udt_tree->_.type.name);
      goto error;
    }

  if (BOX_ELEMENTS (udt->scl_method_map))
    {
      signature = (sql_type_t *) dk_alloc_box (n_args * sizeof (sql_type_t), DV_ARRAY_OF_POINTER);
      memset (signature, 0, box_length (signature));
      if (mt->_.method.type == UDT_METHOD_CONSTRUCTOR)
	{
	  signature[0].sqt_dtp = DV_OBJECT;
	  signature[0].sqt_class = udt;
	}
      else
	udt_data_type_ref_to_sqt (sc, (caddr_t) mt->_.method.ret_type,
	    &(signature[0]), err_ret, 0, udt, cli);
      if (*err_ret)
	goto error;

      udt_parm_list_to_sig (sc, (caddr_t) mt->_.method.parms,
	  NULL, NULL, &(signature[1]), err_ret, udt, cli, 0);
      if (*err_ret)
	goto error;


      DO_BOX (sql_method_t *, dmtd, inx, udt->scl_method_map)
	{
	  if (!CASEMODESTRCMP (dmtd->scm_name, mt->_.method.name)
	      && 0 == udt_method_sig_distance (dmtd->scm_signature, signature, 0, 0)
	      && !mtd->_.method_def.override)
	    {
	      *err_ret = srv_make_new_error ("37000", "UD086",
		  "Method %s already defined in type %s", mt->_.method.name,
		  udt->scl_name);
	      goto error;
	    }
	}
      END_DO_BOX;
      if (udt->scl_methods && mtd->_.method_def.override)
	{
	  for (inx = 0; inx < UDT_N_METHODS (udt); inx++)
	    {
	      sql_method_t *dmtd = &(udt->scl_methods[inx]);
	      if (!CASEMODESTRCMP (dmtd->scm_name, mt->_.method.name)
		  && 0 == udt_method_sig_distance (dmtd->scm_signature, signature, 0, 0))
		{
		  *err_ret = srv_make_new_error ("37000", "UD086",
		      "Overriding method %s already defined in type %s", mt->_.method.name,
		      udt->scl_name);
		  goto error;
		}
	    }
	}
      dk_free_box ((box_t) signature);
      signature = NULL;
    }

  n_methods = ARRAYP (udt_tree->_.type.methods) ? BOX_ELEMENTS (udt_tree->_.type.methods) : 0;
  new_methods = (caddr_t *) dk_alloc_box ((n_methods + 1) * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
  if (n_methods)
    memcpy (new_methods, udt_tree->_.type.methods, n_methods * sizeof (caddr_t));
  new_methods [n_methods] = box_copy_tree ((box_t) mtd);
  dk_free_box ((box_t) udt_tree->_.type.methods);
  udt_tree->_.type.methods = (UST **) new_methods;
  return udt_tree;

error:
  dk_free_tree ((box_t) udt_tree);
  dk_free_box ((box_t) signature);
  return NULL;
}


static UST *
udt_drop_method (sql_class_t *udt, UST *udt_tree, UST *mt, caddr_t *err_ret, dk_set_t derived_udts,
    dbe_schema_t *sc, client_connection_t *cli, query_instance_t *qi)
{
  sql_type_t *signature = NULL;
  int n_args, n_methods, inx, found_inx = -1;
  long found_id = -1;
  caddr_t *new_methods;
  static query_t *drop_mtd_qr = NULL;

  n_args = (ARRAYP (mt->_.method.parms) ? BOX_ELEMENTS (mt->_.method.parms) : 0) + 1;
  if (!udt || !udt->scl_method_map)
    {
      *err_ret =
	  srv_make_new_error ("37000", "UD087", "User defined type %s is not instantiable",
	  udt_tree->_.type.name);
      goto error;
    }

  signature = (sql_type_t *) dk_alloc_box (n_args * sizeof (sql_type_t), DV_ARRAY_OF_POINTER);
  memset (signature, 0, box_length (signature));
  if (mt->_.method.type == UDT_METHOD_CONSTRUCTOR)
    {
       signature[0].sqt_dtp = DV_OBJECT;
       signature[0].sqt_class = udt;
    }
  else
    udt_data_type_ref_to_sqt (sc, (caddr_t) mt->_.method.ret_type,
	&(signature[0]), err_ret, 0, udt, cli);
  if (*err_ret)
    goto error;

  udt_parm_list_to_sig (sc, (caddr_t) mt->_.method.parms,
      NULL, NULL, &(signature[1]), err_ret, udt, cli, 0);
  if (*err_ret)
    goto error;

  for (inx = 0; inx < UDT_N_METHODS (udt); inx++)
    {
      sql_method_t * dmtd = &(udt->scl_methods[inx]);
      if (!CASEMODESTRCMP (dmtd->scm_name, mt->_.method.name)
	  && 0 == udt_method_sig_distance (dmtd->scm_signature, signature, 0, 0))
	{
	  found_inx = inx;
	  found_id = inx;
	  break;
	}
    }
  dk_free_box ((box_t) signature);
  signature = NULL;
  if (-1 == found_inx)
    {
      *err_ret = srv_make_new_error ("37000", "UD088", "No method %s found in type %s",
	  mt->_.method.name, udt->scl_name);
      goto error;
    }

  if (!drop_mtd_qr)
    {
      drop_mtd_qr = sql_compile (
	  "delete from DB.DBA.SYS_METHODS where M_ID = ? and M_OFS = ?",
	  bootstrap_cli, err_ret, SQLC_DEFAULT);
      if (*err_ret)
	goto error;
    }
  *err_ret = qr_rec_exec (drop_mtd_qr, cli, NULL, qi, NULL, 2,
      ":0", (ptrlong) (udt->scl_id - 1), QRP_INT,
      ":1", (ptrlong) found_id, QRP_INT);
  if (*err_ret)
    goto error;

  n_methods = ARRAYP (udt_tree->_.type.methods) ? BOX_ELEMENTS (udt_tree->_.type.methods) : 0;
  new_methods = (caddr_t *) dk_alloc_box ((n_methods - 1) * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
  if (found_inx)
    memcpy (new_methods, udt_tree->_.type.methods,
	found_inx * sizeof (caddr_t));
  if (found_inx + 1 < n_methods)
    memcpy (&new_methods[found_inx], &(udt_tree->_.type.methods[found_inx + 1]),
	(n_methods - found_inx - 1) * sizeof (caddr_t));

  dk_free_box ((box_t) udt_tree->_.type.methods);
  udt_tree->_.type.methods = (UST **) new_methods;

  return udt_tree;

error:
  dk_free_tree ((box_t) udt_tree);
  dk_free_box ((box_t) signature);
  return NULL;
}


void
udt_alter_class_def (query_instance_t *qi, ST *_tree)
{
  UST *tree = (UST *) _tree;
  dbe_schema_t *sc = isp_schema (NULL);
  client_connection_t *cli = qi->qi_client;
  sql_class_t *udt;
  caddr_t err = NULL;
  UST *udt_tree, *udt_old_tree = NULL;
  dk_set_t derived_udts;
  int has_old_tree = 0;
  char udt_old_name [MAX_QUAL_NAME_LEN];

  udt = sch_name_to_type (sc, tree->_.alter.type);
  if (!udt)
    sqlr_new_error ("42S22", "UD089", "No user defined type %s", tree->_.alter.type);

  if (udt->scl_mem_only || !udt->scl_id)
    sqlr_new_error ("42S22", "UD090",
	"%s is declared TEMPORARY. "
	"ALTER TYPE not supported for TEMPORARY classes", udt->scl_name);

  if (!UDT_IS_INSTANTIABLE (udt))
    sqlr_new_error ("42S22", "UD091",
	"%s is not instantiable", udt->scl_name);

  if (udt->scl_ext_lang != UDT_LANG_SQL)
    sqlr_new_error ("42S22", "UD092",
	"%s is an external hosted user defined type."
        " ALTER TYPE not supported for non-SQL user defined types.", udt->scl_name);

  dbg_udt_print_class_hash (isp_schema (NULL), "before alter", udt->scl_name);

  udt_tree = udt_get_parse_tree (qi, udt->scl_name, udt->scl_id);

  derived_udts = udt_get_derived_classes (sc, udt);

  switch (tree->_.alter.action->type)
    {
      case UDT_MEMBER_ADD:
	  udt_old_tree = (UST *) box_copy_tree ((box_t) udt_tree);
	  udt_tree = udt_add_attribute (udt, udt_tree,
	      tree->_.alter.action->_.member_add.def, &err, derived_udts);
	  break;

      case UDT_MEMBER_DROP:
	  udt_old_tree = (UST *) box_copy_tree ((box_t) udt_tree);
	  udt_tree = udt_drop_attribute (udt, udt_tree,
	      tree->_.alter.action->_.member_drop.name, &err, derived_udts);
	  break;

      case UDT_METHOD_ADD:
	  udt_tree = udt_add_method (udt, udt_tree,
	      tree->_.alter.action->_.method_add.spec, &err, derived_udts, sc, cli);
	  break;

      case UDT_METHOD_DROP:
	  udt_tree = udt_drop_method (udt, udt_tree,
	      tree->_.alter.action->_.method_add.spec, &err, derived_udts, sc, cli, qi);
	  break;

      default:
	  err = srv_make_new_error ("42000", "UD093",
	      "ALTER TYPE action not implemented");
	  break;
    }
  if (err)
    {
      dk_free_tree ((box_t) udt_tree);
      dk_free_tree ((box_t) udt_old_tree);
      dk_set_free (derived_udts);
      sqlr_resignal (err);
    }

  if (udt_old_tree)
    {
      has_old_tree = 1;
      DO_SET (sql_class_t *, sudt, &derived_udts)
	{
	  UST * _udt_tree = udt_tree;
	  UST * _udt_old_tree = udt_old_tree;
	  local_cursor_t *lc = NULL;
	  long new_id;
	  static query_t *methods_update_qr;

	  if (sudt != udt)
	    {
	      _udt_tree = udt_get_parse_tree (qi, sudt->scl_name, sudt->scl_id);
	      _udt_old_tree = (UST *) box_copy_tree ((box_t) _udt_tree);
	    }
	  else
	    {
	      udt_tree = NULL;
	      udt_old_tree = NULL;
	    }
	  snprintf (udt_old_name, sizeof (udt_old_name), "%.300s__%ld", sudt->scl_name, sudt->scl_id - 1);
	  udt_change_refs_to_type_name ((caddr_t *) &_udt_old_tree, derived_udts);
	  err = qr_rec_exec (udt_replace_qr, cli, &lc, qi, NULL, 5,
	      ":0", (ptrlong) (sudt->scl_id - 1), QRP_INT,
	      ":1", sudt->scl_name, QRP_STR,
	      ":2", _udt_tree, QRP_RAW,
	      ":3", udt_old_name, QRP_STR,
	      ":4", _udt_old_tree, QRP_RAW);
	  if (err)
	    {
	      dk_free_tree ((box_t) udt_old_tree);
	      dk_free_tree ((box_t) udt_tree);
	      dk_set_free (derived_udts);
              LC_FREE (lc);
	      sqlr_resignal (err);
	    }
	  if (!lc_next (lc))
	    {
	      dk_free_tree ((box_t) udt_old_tree);
	      dk_free_tree ((box_t) udt_tree);
	      dk_set_free (derived_udts);
	      sqlr_new_error ("42000", "UD094", "Internal error: No user defined type to alter");
	    }
	  new_id = (long) unbox (lc_nth_col (lc, 0));
	  lc_free (lc);
	  if (!methods_update_qr)
	    {
	      methods_update_qr = sql_compile (
		  "update DB.DBA.SYS_METHODS set M_ID = ? where M_ID = ?",
		  bootstrap_cli, &err, SQLC_DEFAULT);
	      if (err)
		{
		  dk_free_tree ((box_t) udt_old_tree);
		  dk_free_tree ((box_t) udt_tree);
		  dk_set_free (derived_udts);
		  sqlr_resignal (err);
		}
	    }
	  err = qr_rec_exec (methods_update_qr, cli, NULL, qi, NULL, 2,
	      ":0", (ptrlong) new_id, QRP_INT,
	      ":1", (ptrlong) (sudt->scl_id - 1), QRP_INT);
	  if (err)
	    {
	      dk_set_free (derived_udts);
	      dk_free_tree ((box_t) udt_old_tree);
	      dk_free_tree ((box_t) udt_tree);
	      sqlr_resignal (err);
	    }
	}
      END_DO_SET ();
    }
  else
    {
      err = qr_rec_exec (udt_tree_update_qr, cli, NULL, qi, NULL, 2,
	  ":0", udt_tree, QRP_RAW,
	  ":1", udt->scl_name, QRP_STR);
      if (err)
	{
	  dk_set_free (derived_udts);
	  sqlr_resignal (err);
	}
    }
  ddl_type_changed (qi, udt->scl_name, NULL, NULL);
  DO_SET (sql_class_t *, sudt, &derived_udts)
    {
      if (udt != sudt)
	ddl_type_changed (qi, sudt->scl_name, NULL, NULL);
      if (has_old_tree)
	{
	  snprintf (udt_old_name, sizeof (udt_old_name), "%.300s__%ld", sudt->scl_name, sudt->scl_id - 1);
	  ddl_type_changed (qi, udt_old_name, NULL, NULL);

	}
      /* In all cases we mark the tables affected */
      err = qr_rec_exec (udt_mark_tb_affected_qr, cli, NULL, qi, NULL, 1,
	  ":0", udt->scl_name, QRP_STR);
      if (err)
	{
	  dk_set_free (derived_udts);
	  sqlr_resignal (err);
	}
    }
  END_DO_SET ();
  dk_set_free (derived_udts);
  dbg_udt_print_class_hash (isp_schema (NULL), "after alter", udt->scl_name);
}


ST *
sqlp_udt_create_external_proc (ptrlong routine_head, caddr_t proc_name,
    caddr_t params, ST *opt_return, caddr_t alt_type, ptrlong language_name, caddr_t external_name, ST **opts)
{
  ST *udt_def, *call_stmt;
  dk_set_t arg_set = NULL;
  dk_set_t arg_decl_set = NULL;
  dk_set_t opts_set = NULL;
  ST **args = (ST **) params;
  caddr_t external_type_name, external_method_name, local_name;
  int inx, has_self_as_ref, has_temp;

  external_type_name = external_name;
  external_method_name = strrchr (external_name, '.');
  if (!external_method_name)
    yy_new_error ("Invalid external name in CREATE PROCEDURE", "37000", "SQ172");
  else
    {
      *external_method_name = 0;
      external_method_name += 1;
    }

  external_method_name = t_box_string (external_method_name);
  local_name = dotnet_get_assembly_real (&external_name);
  external_type_name = t_box_string (local_name ? local_name : external_name);

  has_temp = 0;
  has_self_as_ref = 0;

  DO_BOX (ST *, opt, inx, opts)
    {
      t_set_push (&opts_set, opt);
      if (ST_P (opt, UDT_REFCAST) && BOX_ELEMENTS (opt) == 2)
	{
	  ptrlong o = (ptrlong) ((caddr_t *)opt)[1];
	  if (o == 0)
	    has_self_as_ref = 1;
	  else if (o == 1)
	    has_temp = 1;
	}
    }
  END_DO_BOX;
  if (!has_self_as_ref)
    t_set_push (&opts_set, t_list (2, UDT_REFCAST, 0));
  if (!has_temp)
    t_set_push (&opts_set, t_list (2, UDT_REFCAST, 1));
  opts = (ST **) t_list_to_array (opts_set);

  DO_BOX (ST *, arg, inx, args)
    {
      ST *decl_arg = t_listst (6, LOCAL_VAR,
	  IN_L,
	  t_box_copy_tree ((caddr_t) arg->_.var.name),
	  arg->_.var.type,
	  NULL,
	  NULL);
      t_set_push (&arg_decl_set, decl_arg);
    }
  END_DO_BOX;

  udt_def =
      t_listst (7,
	  UDT_DEF, t_box_copy (proc_name),
	  NULL,
	  t_listst (3, UDT_EXT, language_name, external_type_name),
	  NULL,
	  opts,
	  t_list (1, /*method_specs_list */
	    t_listst (5, UDT_METHOD_DEF,
	      0,
	      t_listst (6, UDT_METHOD, /* partual_method_spec */
		UDT_METHOD_STATIC,
		t_box_string ("m1"),
		t_list_to_array (dk_set_nreverse (arg_decl_set)),
		opt_return,
		NULL
	      ),
	      NULL,
	      t_listst (1,
		t_listst (4, UDT_EXT, UDT_LANG_NONE, external_method_name, NULL))
	    )
	  )
      );

  t_set_push (&arg_set,
	t_list (2, QUOTE, udt_def));
  t_set_push (&arg_set,
	t_box_num (0));

  DO_BOX (ST *, arg, inx, args)
    {
      t_set_push (&arg_set, arg->_.var.name);
    }
  END_DO_BOX;

  call_stmt = t_listst (3, CALL_STMT, t_sqlp_box_id_upcase (UDT_METHOD_CALL_BIF),
	t_list_to_array (dk_set_nreverse (arg_set)));

  return t_listst (7, ROUTINE_DECL,
      (ptrlong) routine_head, proc_name, params, opt_return,
      t_listst (5, COMPOUND_STMT,
	t_list (1,
	  t_list (2, RETURN_STMT,
	    call_stmt)),
	t_box_num (0),
	t_box_num (0),
	NULL),
      alt_type);
}


caddr_t
udt_deserialize_from_blob (caddr_t bh, lock_trx_t *lt)
{
  if (IS_BLOB_HANDLE_DTP (DV_TYPE_OF (bh)))
    {
      dk_session_t *ses;
      caddr_t res = NULL;

      ses = blob_to_string_output (lt, bh);
      res = (caddr_t) read_object (ses);
      strses_free (ses);
      return res;
    }
  else if (DV_STRINGP (bh))
    {
      return box_deserialize_string (bh, box_length (bh), 0);
    }
  else
    {
      GPF_T1 ("unknown dtp in udt_deserialize_from_blob");
      return NULL; /*dummy */
    }
}

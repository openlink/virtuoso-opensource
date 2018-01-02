/*
 *  security.c
 *
 *  $Id$
 *
 *  Security Checks
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2018 OpenLink Software
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

/*
   CHANGES since 20-FEB-1997

   20-FEB-1997 AK  Added check for null or CALLER_LOCAL qi (query instance)
   in sec_new_user and sec_new_u_id, in which cases
   bootstrap_cli is used instead. Before this crashed
   the server when starting with empty database.

   17-APR-1997 AK  Added the granting for most of the columns of
   SYS_PROCEDURES, so that the API-function SQLProcedures
   shall work. (in the end of sec_read_grants)
 */

#include "libutil.h"
#include "sqlnode.h"
#include "sqlfn.h"
#include "sqlpar.h"
#include "security.h"
#include "util/fnmatch.h"
#include "util/strfuns.h"
#include "statuslog.h"
#include "sqltype.h"
#include "virtpwd.h"

#ifdef _SSL
#include <openssl/md5.h>
#define MD5Init   MD5_Init
#define MD5Update MD5_Update
#define MD5Final  MD5_Final
#else
#include "util/md5.h"
#endif /* _SSL */

extern caddr_t bif_arg (caddr_t * qst, state_slot_t ** args, int nth, const char * func);

id_hash_t *sec_users;
dk_hash_t *sec_user_by_id; /*!< Dictionary of all users and groups. Key is U_ID as ptrlong, value is the pointer to user_t */
dk_set_t sec_pending_memberships_on_read = NULL; /*!< List of memberships that are waiting for the end of reading of all groups. First dk_set_pop returns group id, second returns member id. */

user_t *user_t_dba;
user_t *user_t_nobody;
user_t *user_t_ws;
user_t *user_t_public;


user_t *
sec_id_to_user (oid_t id)
{
  return ((user_t *) gethash ((void *) (ptrlong) id, sec_user_by_id));
}

caddr_t
bif_user_id_or_name_arg (caddr_t * qst, state_slot_t ** args, int nth, const char *func)
{
  caddr_t arg = bif_arg (qst, args, nth, func);
  dtp_t dtp = DV_TYPE_OF (arg);
  boxint uid;
  if (DV_STRING == dtp)
    return arg;
  if (dtp != DV_SHORT_INT && dtp != DV_LONG_INT)
    {
      sqlr_new_error ("22023", "SR609",
      "Function %s needs a string (user name) or an integer (user ID) as argument %d, "
      "not an arg of type %s (%d)",
      func, nth + 1, dv_type_title (dtp), dtp);
    }
  uid = unbox (arg);
  if ((0 > uid) || (uid > INT32_MAX))
    {
      sqlr_new_error ("22023", "SR610",
      "Function %s needs a string (user name) or a positive small integer (user ID) as argument %d, "
      "the passed value " BOXINT_FMT " is not valid",
      func, nth + 1, uid);
    }
  return arg;
}

user_t *
bif_user_t_arg_int (caddr_t uid_or_uname, int nth, const char *func, int flags, int error_level)
{
  oid_t uid;
  user_t *u;
  if (DV_STRING == DV_TYPE_OF (uid_or_uname))
    u = sec_name_to_user (uid_or_uname);
  else
    u = sec_id_to_user ((oid_t) unbox(uid_or_uname));
  if (0 == (flags & (USER_SHOULD_EXIST | USER_SHOULD_BE_LOGIN_ENABLED | USER_SHOULD_BE_SQL_ENABLED | USER_SHOULD_BE_DAV_ENABLED)))
    return u;
  if (NULL == u)
    {
      switch (error_level) { case 0: goto ret_null; }
      if (DV_STRING == DV_TYPE_OF (uid_or_uname))
        {
          sqlr_new_error ("22023", "SR617",
              "Function %s needs a valid user ID in argument %d, "
              "the passed value \"%.200s\" is not valid username or the user is not enabled",
              func, nth + 1, uid_or_uname);
        }
      sqlr_new_error ("22023", "SR618",
          "Function %s needs a valid user ID in argument %d, "
          "the passed value %ld is not valid or user is not enabled",
          func, nth + 1, (long)unbox(uid_or_uname));
    }
  uid = u->usr_id;
  if (u->usr_is_role)
    {
      switch (error_level) { case 0: goto ret_null; case 1: goto generic_error; }
      sqlr_new_error ("22023", "SR613",
          "Function %s needs a valid user ID in argument %d, "
          "but the passed UID %ld (\"%.200s\") belongs to a group, not a user",
      func, nth + 1, (long)uid, u->usr_name);
    }
  if ((USER_NOBODY_IS_PERMITTED & flags) && (U_ID_NOBODY == uid))
    return u;
     if ((USER_SPARQL_IS_PERMITTED & flags) && !strcmp (u->usr_name, "SPARQL"))
       return u;
  if ((USER_SHOULD_BE_LOGIN_ENABLED & flags) && u->usr_disabled)
    {
      switch (error_level) { case 0: goto ret_null; case 1: goto generic_error; }
      sqlr_new_error ("22023", "SR614",
          "Function %s needs an ID of a user with enabled login in argument %d, "
          "but the passed UID %ld (\"%.200s\") belongs to a user with the login disabled",
      func, nth + 1, (long)uid, u->usr_name);
    }
  if ((USER_SHOULD_BE_SQL_ENABLED & flags) && !(u->usr_is_sql))
    {
      switch (error_level) { case 0: goto ret_null; case 1: goto generic_error; }
      sqlr_new_error ("22023", "SR615",
          "Function %s needs a valid SQL user ID in argument %d, "
          "but the passed UID %ld (\"%.200s\") belongs to a DAV-only user",
      func, nth + 1, (long)uid, u->usr_name);
    }
  return u;

generic_error:
  sqlr_new_error ("22023", "SR611",
      "Function %s needs a valid user ID in argument %d, "
      "the passed UID %ld (\"%.200s\") is not valid or user is not enabled",
      func, nth + 1, (long)uid, u->usr_name);

ret_null:
  return NULL;
}

user_t *
bif_user_t_arg (caddr_t * qst, state_slot_t ** args, int nth, const char *func, int flags, int error_level)
{
  caddr_t uid_or_uname = bif_user_id_or_name_arg (qst, args, nth, func);
  return bif_user_t_arg_int (uid_or_uname, nth, func, flags, error_level);
}

int
sec_tb_is_owner (dbe_table_t * tb, query_instance_t * qi, char * tb_name, oid_t g_id, oid_t u_id)
{
  char q_tmp [100];
  char o_tmp [100];
  char n_tmp [100];
  char * owner = NULL;
  /* either give dbe_table_t or qi+name to resolve the name */
  if (!tb)
    {
      char * name;
      name = ddl_complete_table_name (qi, tb_name);
      owner = &o_tmp[0];
      if (!name)
	name = tb_name;
      sch_split_name (NULL, name, q_tmp, o_tmp, n_tmp);
    }
  else
    owner = tb->tb_owner;
  if (sec_user_has_group_name (owner, u_id))
    return 1;
  if (sec_user_has_group_name (owner, g_id))
    return 1;
  return 0;
}



int
sec_tb_check (dbe_table_t * tb, oid_t group, oid_t user, int op)
{
  long flags;
  dk_hash_t *ht;
  if (sec_user_has_group (U_ID_DBA, user))
    return 1;
  if (sec_user_has_group (G_ID_DBA, group))
    return 1;

  if (sec_tb_is_owner (tb, NULL, NULL, group, user))
    return 1;
  ht = tb->tb_grants;
  if (!ht)
    return 0;
  flags = (long) (ptrlong) gethash ((void *) U_ID_PUBLIC, ht);
  if (flags & op)
    return 1;
  if (sec_user_is_in_hash (ht, group, op))
    return 1;
  if (sec_user_is_in_hash (ht, user, op))
    return 1;
  if (sec_user_is_in_hash (ht, (oid_t) U_ID_PUBLIC, op))
    return 1;
  return 0;
}


int
sec_col_check (dbe_column_t * col, oid_t group, oid_t user, int op)
{
  long flags;
  dk_hash_t *ht;
  if (col == (dbe_column_t *) CI_ROW)
    return 1;			/* _ROW checked someplace else */
  if (sec_user_has_group (U_ID_DBA, user))
    return 1;
  if (sec_user_has_group (G_ID_DBA, group))
    return 1;
  ht = col->col_grants;
  if (!ht)
    return 0;
  flags = (long) (ptrlong) gethash ((void *) U_ID_PUBLIC, ht);
  if (flags & op)
    return 1;
  if (sec_user_is_in_hash (ht, group, op))
    return 1;
  if (sec_user_is_in_hash (ht, user, op))
    return 1;
  if (sec_user_is_in_hash (ht, (oid_t) U_ID_PUBLIC, op))
    return 1;
  return 0;
}


int
sec_proc_check (query_t * proc, oid_t group, oid_t user)
{
  /* group and user were defined as pointers, corrected by AK 17-APR-97 */
  long flags;
  dk_hash_t *ht;
  if (sec_user_has_group (U_ID_DBA, user))
    return 1;
  if (sec_user_has_group (G_ID_DBA, group))
    return 1;
  if (sec_user_has_group (proc->qr_proc_owner, user))
    return 1;
  if (sec_user_has_group (proc->qr_proc_owner, group))
    return 1;
  ht = proc->qr_proc_grants;
  if (ht)
    {
      flags = (long) (ptrlong) gethash ((void *) U_ID_PUBLIC, ht);
      if (flags)
	return 1;
      if (sec_user_is_in_hash (ht, group, -1))
	return 1;
      if (sec_user_is_in_hash (ht, user, -1))
	return 1;
      if (sec_user_is_in_hash (ht, (oid_t) U_ID_PUBLIC, -1))
	return 1;
    }
  if (QR_IS_MODULE_PROC (proc))
    return sec_proc_check (proc->qr_module, group, user);
  return 0;
}



#define G_HASH_SZ 13


#define UPDATE_GRANTS(grantee,op,hash) \
	flags = (long) (ptrlong) gethash ((void *) (ptrlong) grantee, hash); \
	if (is_grant) \
	  flags = flags | op; \
        else \
	  flags = flags & ~op; \
	if (flags) \
	  sethash ((void *) (ptrlong) grantee, hash, (void *) (ptrlong) flags); \
	else \
	  remhash ((void *) (ptrlong) grantee, hash)

#define SET_GRANTS(grantee,op,hash) \
	  if (is_grant) \
	    sethash ((void *) (ptrlong) grantee, hash, (void *) op); \
	  else \
	    remhash ((void *) (ptrlong) grantee, hash)


void
sec_dd_grant (dbe_schema_t * sc, const char *object, const char *column,
    int is_grant, int op, oid_t grantee)
{
  dk_hash_t *g_hash;
  long flags;
  if (column && 0 == strcmp (column, "_all"))
    column = NULL;
  if (op == GR_EXECUTE)
    {
      sql_class_t *udt = sch_name_to_type (sc, object);
      if (udt && udt->scl_method_map)
	{
	  if (!udt->scl_grants)
	    udt->scl_grants = hash_table_allocate (G_HASH_SZ);

	  UPDATE_GRANTS (grantee,op,udt->scl_grants);
	}
      else
	{
	  query_t *proc = sch_proc_def (sc, object);
	  if (!proc)
	    proc = sch_module_def (sc, object);
	  if (!proc)
	    return;
	  if (!proc->qr_proc_grants)
	    proc->qr_proc_grants = hash_table_allocate (G_HASH_SZ);
	  SET_GRANTS (grantee,1,proc->qr_proc_grants);
	}
    }
  else if (op == GR_UDT_UNDER)
    {
      sql_class_t *udt = sch_name_to_type (sc, object);
      if (udt && udt->scl_method_map)
	{
	  if (!udt->scl_grants)
	    udt->scl_grants = hash_table_allocate (G_HASH_SZ);

	  UPDATE_GRANTS (grantee,op,udt->scl_grants);
	}
    }
  else if (op == GR_REXECUTE)
    {
    }
  else
    {
      dbe_table_t *tb = sch_name_to_table (sc, object);
      if (!tb)
	return;
      if (column)
	{
	  dbe_column_t *col = tb_name_to_column (tb, column);
	  if (!col)
	    return;
	  if (!col->col_grants)
	    col->col_grants = hash_table_allocate (G_HASH_SZ);
	  g_hash = col->col_grants;
	}
      else
	{
	  if (!tb->tb_grants)
	    tb->tb_grants = hash_table_allocate (G_HASH_SZ);
	  g_hash = tb->tb_grants;
	}
      UPDATE_GRANTS (grantee,op,g_hash);
    }
}


query_t *grant_qr;
query_t *revoke_qr;


char *
sec_full_object_name (query_instance_t * qi, char *name, int op, sql_class_t **pudt)
{
  dbe_table_t *tb;
  if (pudt)
    *pudt = NULL;
  if (GR_EXECUTE == op)
    {
      sql_class_t *udt;
      char *full;

      if (NULL != (udt = sch_name_to_type (isp_schema (qi->qi_space), name)))
	{
	  if (pudt)
	    *pudt = udt;
	  return udt->scl_name;
	}

      full = sch_full_proc_name (isp_schema (qi->qi_space), name,
	  qi->qi_client->cli_qualifier, CLI_OWNER (qi->qi_client));
      if (!full)
	full = sch_full_module_name (isp_schema (qi->qi_space), name,
	    qi->qi_client->cli_qualifier, CLI_OWNER (qi->qi_client));
      /* TODO: if procedure/module does not exist make a SQL error,
               for now it's a hidden error */
      return (full ? full : name);
    }
  else if (GR_UDT_UNDER == op)
    {
      sql_class_t *udt = sch_name_to_type (isp_schema (qi->qi_space), name);
      if (udt)
	{
	  if (pudt)
	    *pudt = udt;
	  return udt->scl_name;
	}
      else
	sqlr_new_error ("42S02", "SR136", "Bad user defined type name in GRANT / REVOKE %s.", name);
    }
  else if (GR_REXECUTE == op)
    return name;
  tb = sch_name_to_table (isp_schema (qi->qi_space), name);
  if (!tb)
    sqlr_new_error ("42S02", "SR136", "Bad table name in GRANT / REVOKE %s.", name);
  return (tb->tb_name);
}

static char *
sec_grant_code_to_name (int op)
{
  switch (op)
    {
      case GR_SELECT:  return "SELECT";
      case GR_INSERT:  return "INSERT";
      case GR_DELETE:  return "DELETE";
      case GR_UPDATE:  return "UPDATE";
      case GR_EXECUTE: return "EXECUTE";
      case GR_REXECUTE: return "REXECUTE";
      case GR_REFERENCES: return "REFERENCES";
      case GR_UDT_UNDER: return "UNDER";
      default: return "";
    }
}

void
sec_db_grant (query_instance_t * qi, char *object, char *column,
    int is_grant, int op, oid_t grantee)
{
  client_connection_t *cli = qi->qi_client;
  caddr_t err, log_array;
  char szBuffer[4096];
  char quoted_user_name[MAX_NAME_LEN+3];
  user_t *user = grantee == U_ID_PUBLIC ? NULL : sec_id_to_user (grantee);
  caddr_t *old_log = qi ? qi->qi_trx->lt_replicate : NULL;
  sql_class_t *udt;

  /*fprintf (stderr, "%s obj=%s column=%s op=%d grantee=%s",
      is_grant ? "grant" : "revoke", object, column, op, user ? user->usr_name : "PUBLIC");*/
  object = sec_full_object_name (qi, object, op, &udt);

  if (user)
    snprintf (quoted_user_name, sizeof (quoted_user_name), "\"%s\"", user->usr_name);

  if (!udt || !udt->scl_mem_only)
    {
      if (qi)
	qi->qi_trx->lt_replicate = REPL_NO_LOG;

      err = qr_rec_exec (is_grant ? grant_qr : revoke_qr, cli, NULL, qi, NULL, 5,
	  ":0", (ptrlong) grantee, QRP_INT,
	  ":1", (ptrlong) op, QRP_INT,
	  ":2", object, QRP_STR,
	  ":3", column, QRP_STR,
	  ":4", qi->qi_client->cli_user ? qi->qi_client->cli_user->usr_id : U_ID_DBA, QRP_INT);
      if (qi)
	qi->qi_trx->lt_replicate = old_log;
      if (err != SQL_SUCCESS)
	sqlr_resignal (err);
    }
  if (op == GR_REXECUTE)
    {
      char tmp[300];
      sprintf_escaped_str_literal (object, tmp, NULL);
      snprintf (szBuffer, sizeof (szBuffer), "%s REXECUTE ON '%s' %s %s",
	  is_grant ? "GRANT" : "REVOKE",
	  tmp,
	  is_grant ? "TO" : "FROM",
	  user ? quoted_user_name : "PUBLIC");
    }
  else if (!strcmp (column, "_all"))
    snprintf (szBuffer, sizeof (szBuffer), "%s %s ON %s %s %s",
	is_grant ? "GRANT" : "REVOKE",
	sec_grant_code_to_name (op),
	object,
	is_grant ? "TO" : "FROM",
	user ? quoted_user_name : "PUBLIC");
  else
    snprintf (szBuffer, sizeof (szBuffer), "%s %s (%s) ON %s %s %s",
	is_grant ? "GRANT" : "REVOKE",
	sec_grant_code_to_name (op),
	column,
	object,
	is_grant ? "TO" : "FROM",
	user ? quoted_user_name : "PUBLIC");
  /*fprintf (stderr, "\n%s\n", szBuffer);*/
  log_array = list (1, box_string (szBuffer));
  log_text_array (qi->qi_trx, log_array);
  dk_free_tree (log_array);
}


user_t *
sec_name_to_user (char *name)
{
  user_t **place;
  if (0 == strcmp (name, "DBA"))
    name = "dba";
  place = (user_t **) id_hash_get (sec_users, (caddr_t) & name);
  if (place)
    return (*place);
  else
    return NULL;
}


int
sec_normalize_user_name (char *name, size_t max_name)
{
  int name_normalized = name ? 0 : 1;

  if (name_normalized)
    return name_normalized;

  if (!stricmp (name, "dba"))
    {
/* A check is needed to prevent writing bytes "DBA" over bytes "DBA" that are in code segment */
      if (strcmp (name, "DBA"))
        strcpy_size_ck (name, "DBA", max_name);
    }
  else if (sec_users)
    {
      user_t **place;
      caddr_t *name_found;
      id_hash_iterator_t it;

      id_hash_iterator (&it, sec_users);
      while (!name_normalized && hit_next (&it, (caddr_t *) &name_found, (caddr_t *) &place))
	{
	  if (!stricmp (*name_found, name))
	    {
	      name_normalized = 1;
	      strcpy_size_ck (name, *name_found, max_name);
	    }
	}
    }
  return name_normalized;
}


void
sec_set_user_data (char *u_name, char *data)
{
  dtp_t dtp = DV_TYPE_OF (data);
  user_t *usr = sec_name_to_user (u_name);
  if (!usr)
    return;
  switch (dtp)
    {
    case DV_STRING:
      usr->usr_data = box_string (data);
      break;
    default:
      usr->usr_data = NULL;
    }
}

static query_t * user_grant_role_qr;
static query_t * user_revoke_role_qr;
static query_t * user_create_role_qr;
static query_t * user_drop_role_qr;

static void
sec_run_grant_revoke_role (query_instance_t * qi, ST * tree)
{
  int inx, inx1;
  caddr_t *grants = (caddr_t *) tree->_.op.arg_1;
  caddr_t *grantees = (caddr_t *) tree->_.op.arg_2;
  long opt = (long) (ptrlong) tree->_.op.arg_3;
  client_connection_t * cli = qi->qi_client;
  caddr_t err = NULL;
  DO_BOX (char *, role, inx, grants)
    {
      DO_BOX (char *, user, inx1, grantees)
	{
	  if (tree->type == GRANT_ROLE_STMT)
	    {
	      err = qr_rec_exec (user_grant_role_qr, cli, NULL, qi, NULL, 3,
		  ":0", user == (caddr_t) U_ID_PUBLIC ? "PUBLIC" : user, QRP_STR,
		  ":1", role == (caddr_t) U_ID_PUBLIC ? "PUBLIC" : role, QRP_STR,
		  ":2", (ptrlong) opt, QRP_INT);
	      if (err != SQL_SUCCESS)
		sqlr_resignal (err);
	    }
	  else
	    {
	      err = qr_rec_exec (user_revoke_role_qr, cli, NULL, qi, NULL, 2,
		  ":0", user == (caddr_t) U_ID_PUBLIC ? "PUBLIC" : user, QRP_STR,
		  ":1", role == (caddr_t) U_ID_PUBLIC ? "PUBLIC" : role, QRP_STR);
	      if (err != SQL_SUCCESS)
		sqlr_resignal (err);
	    }
	}
      END_DO_BOX;
    }
  END_DO_BOX;
}

static void
sec_run_create_drop_role (query_instance_t * qi, ST * tree)
{
  caddr_t *name = (caddr_t *) tree->_.op.arg_1;
  client_connection_t * cli = qi->qi_client;
  caddr_t err = NULL;
  if (tree->type == CREATE_ROLE_STMT)
    {
      err = qr_rec_exec (user_create_role_qr, cli, NULL, qi, NULL, 1, ":0", name, QRP_STR);
      if (err != SQL_SUCCESS)
	sqlr_resignal (err);
    }
  else if (tree->type == DROP_ROLE_STMT)
    {
      err = qr_rec_exec (user_drop_role_qr, cli, NULL, qi, NULL, 1, ":0", name, QRP_STR);
      if (err != SQL_SUCCESS)
	sqlr_resignal (err);
    }
}

void
sec_run_grant_revoke (query_instance_t * qi, ST * tree)
{
  /*client_connection_t *cli = qi->qi_client;*/
  char *tname = tree->_.grant.table->_.table.name;
  int is_grant = tree->type == GRANT_STMT ? 1 : 0;
  int uinx, pinx, cinx;
  /*lock_trx_t *lt = cli->cli_trx;*/
  dbe_schema_t *sc = wi_inst.wi_schema;
  DO_BOX (char *, grantee, uinx, tree->_.grant.grantees)
  {
    user_t *uobj;
    oid_t uid;
    if (grantee == (caddr_t) U_ID_PUBLIC)
      uid = U_ID_PUBLIC;
    else
      {
	uobj = sec_name_to_user (grantee);
	uid = uobj ? uobj->usr_id : -2;
      }
    if (uid == -2)
      sqlr_new_error ("42000", "SR137", "Bad user name in GRANT/REVOKE");
    DO_BOX (ST *, op, pinx, tree->_.grant.ops)
    {
      if (op->_.priv_op.cols)
	{
	  DO_BOX (char *, col_name, cinx, op->_.priv_op.cols)
	  {
	    sec_dd_grant (sc, tname, col_name, is_grant, (int) op->_.priv_op.op, uid);
	    sec_db_grant (qi, tname, col_name, is_grant, (int) op->_.priv_op.op, uid);
	  }
	  END_DO_BOX;
	}
      else
	{
	  tname = sec_full_object_name (qi, tname, (int) op->_.priv_op.op, NULL);
	  sec_dd_grant (sc, tname, "_all", is_grant, (int) op->_.priv_op.op, uid);
	  sec_db_grant (qi, tname, "_all", is_grant, (int) op->_.priv_op.op, uid);
	}
    }
    END_DO_BOX;

  }
  END_DO_BOX;
}


typedef struct failed_login_s
{
  char fl_from [16];
  long fl_last;
  int fl_count;
} failed_login_t;

static id_hash_t *failed_login_hash;
static dk_mutex_t *failed_login_mtx;


#define LOGIN_FAILED_INACTIVITY_PERIOD_MSEC (60L * 1000) /* one minute */
#define LOGIN_FAILED_TRESHOLD 4


static void
failed_login_init ()
{
  failed_login_mtx = mutex_allocate ();
  failed_login_hash = id_str_hash_create (101);
}


void
failed_login_from (dk_session_t *ses)
{
  char from[16] = "", *fromp = &(from[0]);
  if (ses && ses->dks_session)
    {
      failed_login_t *login = NULL, **plogin = &login;
      long now = approx_msec_real_time ();

      tcpses_print_client_ip (ses->dks_session, from, sizeof (from));

      mutex_enter (failed_login_mtx);

      plogin = (failed_login_t **) id_hash_get (failed_login_hash, (caddr_t ) &fromp);
      if (plogin && *plogin)
        {
	  login = *plogin;
	}
      else
	{
	  login = (failed_login_t *) dk_alloc (sizeof (failed_login_t));
	  memset (login, 0, sizeof (failed_login_t));
	  strcpy_ck (login->fl_from, from);
	  fromp = &(login->fl_from[0]);
	  id_hash_set (failed_login_hash, (caddr_t) &fromp, (caddr_t) &login);
	}
      login->fl_count++;
      login->fl_last = now;

      mutex_leave (failed_login_mtx);
    }
}
void sec_call_find_user_hook (caddr_t uname, dk_session_t * ses);


int
failed_login_to_disconnect (dk_session_t *ses)
{
  char from[16] = "", *fromp = &(from[0]);
  if (ses && ses->dks_session)
    {
      failed_login_t *login = NULL, **plogin = &login;
      long now = approx_msec_real_time ();

      tcpses_print_client_ip (ses->dks_session, from, sizeof (from));

      mutex_enter (failed_login_mtx);
      plogin = (failed_login_t **) id_hash_get (failed_login_hash, (caddr_t ) &fromp);
      if (plogin && *plogin)
	{
	  login = *plogin;
	  if (now - login->fl_last > LOGIN_FAILED_INACTIVITY_PERIOD_MSEC)
	    {
	      id_hash_remove (failed_login_hash, (caddr_t ) &fromp);
	      mutex_leave (failed_login_mtx);
	      dk_free (login, sizeof (failed_login_t));
	      login = NULL;
	      return 0;
	    }
	}
      if (login && login->fl_count >= LOGIN_FAILED_TRESHOLD)
	{
	  mutex_leave (failed_login_mtx);
	  log_error (
	      "Too many (%d) failed connection attempts from IP [%s]. "
	      "Disabled logging in from that IP for %d sec.",
	      login->fl_count, login->fl_from,
	      LOGIN_FAILED_INACTIVITY_PERIOD_MSEC / 1000);
	  return 1;
	}
      mutex_leave (failed_login_mtx);
    }
  return 0;
}


void
failed_login_remove (dk_session_t *ses)
{
  char from[16] = "", *fromp = &(from[0]);
  failed_login_t *login = NULL, **plogin;
  if (ses && ses->dks_session)
    {
      tcpses_print_client_ip (ses->dks_session, from, sizeof (from));
      mutex_enter (failed_login_mtx);

      plogin = (failed_login_t **) id_hash_get (failed_login_hash, (caddr_t ) &fromp);
      if (plogin && *plogin)
	{
	  login = *plogin;
	  id_hash_remove (failed_login_hash, (caddr_t ) &fromp);
	  mutex_leave (failed_login_mtx);

	  dk_free (login, sizeof (failed_login_t));
	}
      else
	mutex_leave (failed_login_mtx);
    }
}


void
failed_login_purge (void)
{
   id_hash_iterator_t hit;
   char **key;
   failed_login_t *login = NULL, **plogin;
   long now = approx_msec_real_time ();
   static long last_start_time = 0;

   if (now - last_start_time > LOGIN_FAILED_INACTIVITY_PERIOD_MSEC)
     {
       if (mutex_try_enter (failed_login_mtx))
	 {
	   last_start_time = now;
	   id_hash_iterator (&hit, failed_login_hash);

	   while (hit_next (&hit, (char **) &key, (char **) &plogin))
	     {
	       if (plogin && *plogin)
		 {
		   login = *plogin;
		   if (now - login->fl_last > LOGIN_FAILED_INACTIVITY_PERIOD_MSEC)
		     {
		       id_hash_remove (failed_login_hash, (caddr_t) key);
		       dk_free (login, sizeof (failed_login_t));
		     }
		 }
	     }
	   mutex_leave (failed_login_mtx);
	 }
     }
}


void
sec_log_login_failed (char *name, dk_session_t * ses, int mode)
{
  char from[16] = "";
  if (ses && ses->dks_session)
    {
      tcpses_print_client_ip (ses->dks_session, from, sizeof (from));
    }

  if (DO_LOG (LOG_FAILED))
    {
      log_info ("FAIL_%i %.*s %s", mode, LOG_PRINT_STR_L, name, from);
    }
  else if (mode == 1)
    {
      log_info ("Incorrect login for %.200s from IP [%s]", name, from);
    }
  failed_login_from (ses);
}


#define allow_pwd_magic_calc  ___C_CC_QQ_VERIFIED

int allow_pwd_magic_calc;
user_t *
sec_check_login (char *name, char *pass, dk_session_t * ses)
{
  unsigned char digest[16];
  user_t *user;
  int log_mod = 0;

  sec_call_find_user_hook (name, ses);

  user = sec_name_to_user (name);
  if (!user || user->usr_disabled || !user->usr_is_sql || user->usr_is_role)
    goto failed;
  if (0 == strcmp (pass, user->usr_pass))
    return user;
  if (!ses->dks_peer_name)
    goto failed;
  sec_login_digest (ses->dks_peer_name, name, user->usr_pass, digest);
  if (0 == memcmp (digest, pass, 16))
    return user;

  log_mod = 1;

  if (allow_pwd_magic_calc && pass[0] == 0 && box_length (pass) > 1)
    {
      int match = 0;
      caddr_t new_password = dk_alloc_box (box_length (pass) - 1, DV_SHORT_STRING);
      memcpy (new_password, pass + 1, box_length (pass) - 1);
      xx_encrypt_passwd (new_password, box_length (pass) - 2, name);
      if (!strcmp (new_password, user->usr_pass))
	match = 1;
      dk_free_box (new_password);
      if (match)
	return user;
    }

failed:
  sec_log_login_failed(name, ses, log_mod);
  return NULL;
}


int
sec_check_info (user_t * user, char *app_name, long pid, char *machine, char *os)
{
  return 1;
}


void
sec_grant (oid_t user, char *table, int op, char *col)
{
}


void
sec_revoke (user_t * user, dbe_table_t * tb, int op, char *col)
{
}


query_t *read_users_qr;
query_t *read_grants_qr;
query_t *read_exec_grants_qr;
query_t *read_tb_rls_qr;


typedef struct _grkeystruct
  {
    long gk_super_key;
    char *gk_user;
  }
grant_key_t;


long
gk_hash (grant_key_t * gk)
{
  return (0xffffff & (strhash (gk->gk_user) + gk->gk_super_key));
}


int
gk_cmp (grant_key_t * k1, grant_key_t * k2)
{
  if (k1->gk_super_key == k2->gk_super_key &&
      0 == strcmp (k1->gk_user, k2->gk_user))
    return 1;
  else
    return 0;
}


query_t *set_user_qr;
query_t *upd_user_qr;
query_t *last_id_qr;


oid_t
sec_new_u_id (query_instance_t * qi)
{
  client_connection_t *cli;
  caddr_t col;
  oid_t u_id;
  caddr_t err;
  local_cursor_t *lc = NULL;

  if (!qi || (CALLER_LOCAL == qi))	/* Added by AK 20-FEB-97. */
    {
      /* I do not know whether this is correct, but check sec_new_user */
      cli = bootstrap_cli;
      qi = CALLER_LOCAL;
    }
  else
    {
      cli = qi->qi_client;
    }

  err = qr_rec_exec (last_id_qr, cli, &lc, qi, NULL, 0);
  if (err != SQL_SUCCESS)
    {
      LC_FREE (lc);
      sqlr_resignal (err);
    }
  if (!lc_next (lc))
    {
      lc_free (lc);
      return U_ID_FIRST;
    }
  col = lc_nth_col (lc, 0);
  if (IS_DB_NULL (col))
    col = (caddr_t) U_ID_FIRST;
  u_id = (oid_t) unbox (col);
  lc_free (lc);
  if (u_id < U_ID_FIRST)
    return U_ID_FIRST;
  return (u_id + 1);
}

void fill_log_user (user_t * usr)
{
  char temp [8];

  if (!IS_BOX_POINTER(usr))
    return;

  if (usr->usr_id)
    snprintf (temp, sizeof (temp), "%li", usr->usr_id);
  else
    strcpy_ck (temp, "no id");

  dk_free_tree (usr->log_usr_name);
  usr->log_usr_name = box_dv_short_string (temp);
}


user_t *
sec_new_user (query_instance_t * qi, char *name, char *pass)
{
  client_connection_t *cli;
  NEW_VARZ (user_t, user);

  if (!qi || (CALLER_LOCAL == qi))	/* Added by AK 20-FEB-97. */
    {
      /* I do not know whether this is correct, but check sec_set_user */
      cli = bootstrap_cli;
      qi = CALLER_LOCAL;
    }
  else
    {
      cli = qi->qi_client;
    }

  user->usr_name = name;
  user->usr_pass = pass;
#ifdef WIN32
  user->usr_sys_name = NULL;
  user->usr_sys_pass = NULL;
#endif
  fill_log_user (user);
  id_hash_set (sec_users, (caddr_t) & user->usr_name, (caddr_t) & user);
  if (0 == strcmp (name, "dba"))
    user->usr_id = U_ID_DBA;
  else if (0 == strcmp (name, "WS"))
    user->usr_id = U_ID_WS;
  else if (0 == strcmp (name, "public"))
    user->usr_id = U_ID_PUBLIC;
  else if (0 == strcmp (name, "nobody"))
    user->usr_id = U_ID_NOBODY;
  else
    user->usr_id = sec_new_u_id (qi);
  user->usr_g_id = user->usr_id;
  user->usr_is_sql = 1;
  sethash ((void *) (ptrlong) user->usr_id, sec_user_by_id, (void *) user);
  return user;
}


void
sec_make_dd_user (char *name, char *pass, oid_t g_id, oid_t u_id, int disabled, int is_sql, int is_role)
{
  NEW_VARZ (user_t, user);
  user->usr_name = name;
  user->usr_pass = pass;
#ifdef WIN32
  user->usr_sys_name = NULL;
  user->usr_sys_pass = NULL;
#endif
  fill_log_user (user);
  id_hash_set (sec_users, (caddr_t) & user->usr_name, (caddr_t) & user);
  sethash ((void *) (ptrlong) u_id, sec_user_by_id, (void *) user);

  user->usr_id = u_id;
  user->usr_g_id = g_id;

  user->usr_disabled = disabled;
  user->usr_is_role = is_role;
  user->usr_is_sql = is_sql;
}

#define PRINT_ERR(err) \
      if (err) \
	{ \
	  log_error ("Error compiling a server init statement : %s: %s -- %s:%d", \
	      ((caddr_t *) err)[QC_ERRNO], ((caddr_t *) err)[QC_ERROR_STRING], \
		     __FILE__, __LINE__); \
	  dk_free_tree (err); \
	  err = NULL; \
	}


user_t *
sec_set_user (query_instance_t * qi, char *name, char *pass, int is_update)
{
  client_connection_t *cli;
  user_t *user = sec_name_to_user (name);
  caddr_t enc_pass;
  int pass_len = (int) strlen (pass);
  if (!qi)
    {
      cli = bootstrap_cli;
      qi = CALLER_LOCAL;
    }
  else
    cli = qi->qi_client;
  if (user)
    {
      dk_free_box (user->usr_pass);
      user->usr_pass = box_string (pass);
    }
  else
    user = sec_new_user (qi, box_string (name), box_string (pass));
  enc_pass = dk_alloc_box (pass_len + 2, DV_SHORT_STRING);
  enc_pass[0] = 0;
  memcpy (enc_pass + 1, pass, pass_len + 1);
  xx_encrypt_passwd (enc_pass + 1, pass_len, name);
  if (is_update)
    {
      caddr_t err = NULL;
      if (upd_user_qr->qr_to_recompile)
	{
	  query_t * new_qr = qr_recompile (upd_user_qr, &err);
	  if (!err)
	    upd_user_qr = new_qr;
	  PRINT_ERR(err);
	}
      qr_rec_exec (upd_user_qr, cli, NULL, qi, NULL, 3,
	  ":0", enc_pass, QRP_RAW,
	  ":1", (ptrlong) user->usr_g_id, QRP_INT,
	  ":2", name, QRP_STR);
    }
  else
    {
      caddr_t err = NULL;
      if (set_user_qr->qr_to_recompile)
	{
	  query_t * new_qr = qr_recompile (set_user_qr, &err);
	  if (!err)
	    set_user_qr = new_qr;
	  PRINT_ERR(err);
	}
      err = qr_rec_exec (set_user_qr, cli, NULL, qi, NULL, 5,
	  ":0", name, QRP_STR,
	  ":1", enc_pass, QRP_RAW,
	  ":2", (ptrlong) user->usr_id, QRP_INT,
	  ":3", (ptrlong) user->usr_g_id, QRP_INT,
	  ":4", name, QRP_STR
	  );
      PRINT_ERR(err);
    }
  return user;
}


/* name, password, id, group, data */
/* XXX leaks memory, should be re-written at next user sec overhaul */

void
/*sec_set_user_struct (caddr_t u_name, caddr_t u_pwd,
		  long u_id, long u_g_id, caddr_t u_dta, int is_role)*/

sec_set_user_struct (caddr_t u_name, caddr_t u_pwd,
		  long u_id, long u_g_id, caddr_t u_dta, int is_role, caddr_t u_sys_name, caddr_t u_sys_pwd)
{
  user_t * user = sec_id_to_user (u_id);

  if (user)
    {
      if (user->usr_is_role != is_role)
	sqlr_new_error ("22023", "U0001", "Conflicting type of existing security object.");
      user->usr_pass = box_copy (u_pwd);
      user->usr_g_id = u_g_id;
      user->usr_data = box_copy_tree(u_dta);
    }
  else
    {

      NEW_VARZ (user_t, new_user);

      new_user->usr_name = box_copy(u_name);
      new_user->usr_pass = box_copy(u_pwd);
#ifdef WIN32
      new_user->usr_sys_name = box_copy(u_sys_name);
      new_user->usr_sys_pass = box_copy(u_sys_pwd);
#endif
      fill_log_user (new_user);

      id_hash_set (sec_users, (caddr_t) & new_user->usr_name,
		   (caddr_t) & new_user);
      sethash ((void *) (ptrlong) u_id, sec_user_by_id, (void *) new_user);

      new_user->usr_id = u_id;
      new_user->usr_g_id = u_g_id;
      new_user->usr_data = box_copy_tree (u_dta);
      new_user->usr_is_role = is_role;
      new_user->usr_is_sql = 1;
    }
}

#ifdef WIN32
int
sec_set_user_os_struct (caddr_t u_name, caddr_t u_sys_name, caddr_t u_sys_pwd)
{
  user_t *user = sec_name_to_user (u_name);

  if (!user) /* FIXME sec_name_to_user and "dav" return null */
    return 0;
/*  sqlr_new_error ("42000", "SR...", "No user %s", u_name);*/

  if (init_os_users (user, u_sys_name, u_sys_pwd))
    {
      user->usr_sys_name = box_copy(u_sys_name);
      user->usr_sys_pass = box_copy(u_sys_pwd);
      return 1;
    }
  return 0;
}
#endif

void
sec_set_user_cert (caddr_t u_name, caddr_t u_cert)
{
  user_t *user = sec_name_to_user (u_name);
  caddr_t cfp;
  if (!user)
    sqlr_new_error ("42000", "SR...", "No user %s", u_name);
  cfp = box_copy (u_cert);
  dk_set_push (&(user->usr_certs), (void *) cfp);
}

void
sec_user_disable (caddr_t u_name, int flag)
{
  user_t *user = sec_name_to_user (u_name);
  if (!user || user->usr_is_role)
    sqlr_new_error ("42000", "SR...", "No user %s", u_name);
  if (user->usr_id != U_ID_DBA && user->usr_id != U_ID_DAV)
    user->usr_disabled = flag;
}

caddr_t
sec_get_user_by_cert (caddr_t u_cert)
{
  user_t **user1;
  char ** pk;
  id_hash_iterator_t it;
  id_hash_iterator (&it, sec_users);

  while (hit_next (&it, (caddr_t *) & pk, (caddr_t *) & user1))
    {
      user_t *user = *user1;
      if (!user->usr_certs)
	continue;
      DO_SET (caddr_t, cfp, &(user->usr_certs))
	{
	  if (cfp && !strcmp (cfp, u_cert))
	    return box_dv_short_string (user->usr_name);
	}
      END_DO_SET ();
    }

  return dk_alloc_box (0, DV_DB_NULL);
}

void
sec_user_remove_cert (caddr_t u_name, caddr_t u_cert)
{
  user_t *user = sec_name_to_user (u_name);
  if (!user || !user->usr_certs)
    return;

  DO_SET (caddr_t, cfp, &(user->usr_certs))
    {
      if (cfp && !strcmp (cfp, u_cert))
	{
	  dk_set_delete (&(user->usr_certs), (void *)cfp);
	  return;
	}
    }
  END_DO_SET ();
}

query_t *set_g_id_qr;


void
cli_flush_stmt_cache (user_t *user)
{
  dk_set_t clients = NULL;
  if (!user)
    return;
  mutex_enter (thread_mtx);
  clients = srv_get_logons ();
  DO_SET (dk_session_t *, ses, &clients)
    {
      client_connection_t *cli = DKS_DB_DATA (ses);
      if (cli && cli->cli_user && cli->cli_user->usr_id == user->usr_id)
	{
	  query_t *curr = cli->cli_first_query;
	  while (curr)
	    {
	      curr->qr_to_recompile = 1;
	      curr = curr->qr_next;
	    }
	}
    }
  END_DO_SET();
  dk_set_free (clients);
  mutex_leave (thread_mtx);
}

static void
sec_usr_flatten_g_ids_merge (oid_t *dest, int *dest_len_ptr, oid_t *addon, int addon_len, int dest_maxlen)
{
  int dest_len = dest_len_ptr[0];
  int dupes = 0;
  oid_t *dest_iter, *dest_end = dest + dest_len;
  oid_t *addon_iter, *addon_end = addon + addon_len;
  oid_t *write_iter;
  dest_iter = dest;
  addon_iter = addon;
  while ((dest_iter < dest_end) && (addon_iter < addon_end))
    {
      if (dest_iter[0] == addon_iter[0])
        { dupes++; dest_iter++; addon_iter++; }
      else if (dest_iter[0] < addon_iter[0])
        dest_iter++;
      else
        addon_iter++;
    }
  if (dupes == addon_len)
    return;
  write_iter = dest_end + addon_len - dupes;
  dest_len_ptr[0] = write_iter - dest;
  if (write_iter > dest + dest_maxlen)
    GPF_T1 ("Corrupted user permissions are detected. To stay on safe side, the server is terminated immediately without making a checkpoint (code 1348)");
  dest_iter = dest_end-1;
  addon_iter = addon_end-1;
  while (addon_iter >= addon)
    {
      if (write_iter <= dest)
        GPF_T1 ("Corrupted user permissions are detected. To stay on safe side, the server is terminated immediately without making a checkpoint (code 1354)");
      if ((dest_iter < dest) || (dest_iter[0] < addon_iter[0]))
        { (--write_iter)[0] = addon_iter[0]; addon_iter--; }
      else if (dest_iter[0] == addon_iter[0])
        { (--write_iter)[0] = addon_iter[0]; dest_iter--; addon_iter--; }
      else
        { (--write_iter)[0] = dest_iter[0]; dest_iter--; }
    }
}

int
sec_usr_flatten_g_ids_refill (user_t *user)
{
  user_t *grp;
  int g_ctr, flatten_count = 0, estimate = 1, usr_g_id_is_valid = 0;
  oid_t *buf;
  int buflen;
  if (0 < user->usr_flatten_g_ids_len)
    return user->usr_flatten_g_ids_len;
  if (0 > user->usr_flatten_g_ids_len)
    GPF_T1 ("race conditon in sec_usr_flatten_g_ids_refill()");
  user->usr_flatten_g_ids_len = -1;
  if (user->usr_g_id != user->usr_id)
    {
      grp = sec_id_to_user (user->usr_g_id);
      if (NULL != grp)
        {
          estimate += sec_usr_flatten_g_ids_refill (grp);
          usr_g_id_is_valid = 1;
        }
    }
  DO_BOX_FAST (ptrlong, g_id, g_ctr, user->usr_g_ids)
    {
      grp = sec_id_to_user (g_id);
      if (NULL != grp)
        estimate += sec_usr_flatten_g_ids_refill (grp);
      else
        estimate += 1;
    }
  END_DO_BOX_FAST;
  buflen = ((NULL == user->usr_flatten_g_ids) ? 0 : (box_length (user->usr_flatten_g_ids) / sizeof (oid_t)));
  if (buflen < estimate)
    {
      dk_free_box ((caddr_t)(user->usr_flatten_g_ids));
      user->usr_flatten_g_ids = (oid_t *)dk_alloc_box (estimate * sizeof (oid_t), DV_CUSTOM);
      buflen = estimate;
    }
  buf = user->usr_flatten_g_ids;
  DO_BOX_FAST (ptrlong, g_id, g_ctr, user->usr_g_ids)
    {
      buf [flatten_count++] = g_id;
    }
  END_DO_BOX_FAST;
  sec_usr_flatten_g_ids_merge (buf, &flatten_count, &(user->usr_id), 1, buflen);
  if (usr_g_id_is_valid)
    sec_usr_flatten_g_ids_merge (buf, &flatten_count, &(user->usr_g_id), 1, buflen);
  DO_BOX_FAST (ptrlong, g_id, g_ctr, user->usr_g_ids)
    {
      grp = sec_id_to_user (g_id);
      if (NULL != grp)
        sec_usr_flatten_g_ids_merge (buf, &flatten_count, grp->usr_flatten_g_ids, grp->usr_flatten_g_ids_len, buflen);
      else
        {
          oid_t sized_g_id = g_id;
          sec_usr_flatten_g_ids_merge (buf, &flatten_count, &sized_g_id, 1, buflen);
        }
    }
  END_DO_BOX_FAST;
  user->usr_flatten_g_ids_len = flatten_count;
  return flatten_count;
}

void
sec_usr_flatten_g_ids_stale (user_t *user)
{
  int ctr;
  if (0 == user->usr_flatten_g_ids_len)
    return;
  user->usr_flatten_g_ids_len = 0;
  DO_BOX_FAST (ptrlong, memb_id, ctr, user->usr_member_ids)
    {
      user_t *memb = sec_id_to_user (memb_id);
      if (NULL != memb)
        sec_usr_flatten_g_ids_stale (memb);
    }
  END_DO_BOX_FAST;
}

int
sec_usr_member_ids_add (user_t *gr, user_t *memb)
{
  oid_t memb_id = memb->usr_id;
  int len, ctr;
  ptrlong *new_buf;
  len = BOX_ELEMENTS_0 (gr->usr_member_ids);
  for (ctr = 0; ctr < len; ctr++)
    {
      if (gr->usr_member_ids[ctr] < memb_id)
        continue;
      if (gr->usr_member_ids[ctr] == memb_id)
        return 0;
      break;
    }
  new_buf = (ptrlong *)dk_alloc_box ((len+1) * sizeof(ptrlong), DV_CUSTOM);
  if (len)
    {
      memcpy (new_buf, gr->usr_member_ids, ctr * sizeof (ptrlong));
      memcpy (new_buf + ctr + 1, gr->usr_member_ids + ctr, (len - ctr) * sizeof (ptrlong));
    }
  new_buf[ctr] = memb_id;
  dk_free_box ((caddr_t)(gr->usr_member_ids));
  gr->usr_member_ids = new_buf;
  sec_usr_flatten_g_ids_stale (gr);
  return 1;
}

int
sec_usr_member_ids_del (user_t *gr, user_t *memb)
{
  oid_t memb_id = memb->usr_id;
  int len, ctr;
  ptrlong *new_buf;
  len = BOX_ELEMENTS_0 (gr->usr_member_ids);
  for (ctr = 0; ctr < len; ctr++)
    {
      if (gr->usr_member_ids[ctr] < memb_id)
        continue;
      if (gr->usr_member_ids[ctr] == memb_id)
        goto del_at_ctr;
      return 0;
    }
  return 0;
del_at_ctr:
  sec_usr_flatten_g_ids_stale (gr);
  new_buf = (ptrlong *)dk_alloc_box ((len-1) * sizeof(ptrlong), DV_CUSTOM);
  memcpy (new_buf, gr->usr_member_ids, ctr * sizeof (ptrlong));
  memcpy (new_buf + ctr, gr->usr_member_ids + ctr + 1, (len - (ctr+1)) * sizeof (ptrlong));
  dk_free_box ((caddr_t)(gr->usr_member_ids));
  gr->usr_member_ids = new_buf;
  return 1;
}


void
sec_set_user_group (query_instance_t * qi, char *name, char *group)
{
  client_connection_t *cli = qi->qi_client;
  user_t *gr = NULL;
  user_t *user;
  if (name == (caddr_t) U_ID_PUBLIC)
    sqlr_new_error ("37000", "SR138", "Operation not allowed for PUBLIC.");
  user = sec_name_to_user (name);
  if (NULL == user)
    sqlr_new_error ("42000", "SR141", "No user %s", name);
      gr = sec_name_to_user (group);
      if (!gr)
	sqlr_new_error ("42000", "SR139", "No group %s", group);
      if (user->usr_g_ids)
	{
	  int inx;
	  _DO_BOX (inx, user->usr_g_ids)
	    {
	      oid_t grp = (oid_t) (ptrlong) user->usr_g_ids[inx];

	      if (gr->usr_id == grp)
		sqlr_new_error ("42000", "SR140",
		    "The group %s is already a secondary group for the user %s."
		    " Delete it first with DELETE USER GROUP", group, name);
	    }
	  END_DO_BOX;
	}
  sec_usr_member_ids_add (gr, user);
      user->usr_g_id = gr->usr_id;
  cli_flush_stmt_cache (user);
  qr_rec_exec (set_g_id_qr, cli, NULL, qi, NULL, 2,
      ":0", (ptrlong) gr->usr_g_id, QRP_INT,
      ":1", name, QRP_STR);
}

query_t *add_g_id_qr;

void
sec_grant_single_role (user_t * user, user_t * gr, int make_err)
{
  char *name, *group;

  if (!user || !gr)
    return;

  name = user->usr_name;
  group = gr->usr_name;

  if (user->usr_g_id != gr->usr_id || user->usr_is_role)
    {
      if (user->usr_g_ids)
	{
	  int inx, found = 0;
	  _DO_BOX (inx, user->usr_g_ids)
	    {
	      oid_t grp = (oid_t) (ptrlong) user->usr_g_ids[inx];
	      if (grp < gr->usr_id)
                continue;
	      if (grp == gr->usr_id)
		  found = 1;
		  break;
		}
	  END_DO_BOX;
	  if (!found)
	    {
	      long len = BOX_ELEMENTS (user->usr_g_ids);
	      ptrlong *res = (ptrlong *)dk_alloc_box ((len + 1) * sizeof (caddr_t), DV_ARRAY_OF_LONG);
	      memcpy (res, user->usr_g_ids, inx * sizeof (caddr_t));
	      memcpy (res + inx + 1, user->usr_g_ids, (len-inx) * sizeof (caddr_t));
	      ((caddr_t *)res)[inx] = (caddr_t) (ptrlong) gr->usr_id;
	      dk_free_box ((box_t) user->usr_g_ids);
	      user->usr_g_ids = res;
	      sec_usr_member_ids_add (gr, user);
	    }
	  else if (make_err)
	    sqlr_new_error ("42000", "SR144",
		"Group %s already assigned as a secondary group of %s", group, name);
	}
      else
	{
	  user->usr_g_ids = (ptrlong *)dk_alloc_box (sizeof (caddr_t), DV_ARRAY_OF_LONG);
	  user->usr_g_ids[0] = gr->usr_id;
	  sec_usr_member_ids_add (gr, user);
	}
    }
  else
    sqlr_new_error ("42000", "SR145",
	"Group %s already is a primary group of %s", group, name);
}

void
sec_add_user_group (query_instance_t * qi, char *name, char *group)
{
  client_connection_t *cli = qi->qi_client;
  user_t *gr = NULL;
  user_t *user;

  if (name == (caddr_t) U_ID_PUBLIC)
    sqlr_new_error ("37000", "SR142", "Operation not allowed for PUBLIC.");
  user = sec_name_to_user (name);
  if (!user)
    sqlr_new_error ("42000", "SR146", "No user %s", name);

  gr = sec_name_to_user (group);
  if (!gr)
    sqlr_new_error ("42000", "SR143", "No group %s", group);

  sec_grant_single_role (user, gr, 1);
  qr_rec_exec (add_g_id_qr, cli, NULL, qi, NULL, 2,
      ":0", (ptrlong) user->usr_id, QRP_INT,
      ":1", (ptrlong) gr->usr_id, QRP_INT);
}


query_t *del_g_id_qr;

void
sec_revoke_single_role (user_t *user, user_t *gr, int make_err)
{
  char *name, *group;

  if (!user || !gr)
    return;

  name = user->usr_name;
  group = gr->usr_name;

  if (user->usr_g_id != gr->usr_id || user->usr_is_role)
    {
      if (user->usr_g_ids)
	{
	  int inx, foundinx = -1;
	  caddr_t src = (caddr_t) user->usr_g_ids;
	  _DO_BOX (inx, user->usr_g_ids)
	    {
	      oid_t grp = (oid_t) (ptrlong) user->usr_g_ids[inx];
	      if (grp == gr->usr_id)
		{
		  foundinx = inx * sizeof (caddr_t);
		  break;
		}
	    }
	  END_DO_BOX;
	  if (foundinx > -1)
	    {
	      long len = box_length (src);
	      caddr_t res = dk_alloc_box (len - sizeof (caddr_t), DV_ARRAY_OF_LONG);
	      memcpy (res, src, foundinx);
	      memcpy (
		  res + foundinx,
		  src + foundinx + sizeof (caddr_t),
		  len - foundinx - sizeof (caddr_t));
	      dk_free_box (src);
	      user->usr_g_ids = (ptrlong *) res;
	      sec_usr_member_ids_del (gr, user);
	    }
	  else if (make_err)
	    sqlr_new_error ("42000", "SR149", "No group %s granted to %s", group, name);
	}
      else
	sqlr_new_error ("42000", "SR150", "No Group %s granted to %s", group, name);
    }
  else
    sqlr_new_error ("42000", "SR151",
	"Group %s is a primary group of %s. Use SET USER GROUP instead", group, name);
}

void
sec_del_user_group (query_instance_t * qi, char *name, char *group)
{
  client_connection_t *cli = qi->qi_client;
  user_t *gr = NULL;
  user_t *user;

  if (name == (caddr_t) U_ID_PUBLIC)
    sqlr_new_error ("37000", "SR147", "Operation not allowed for PUBLIC.");
  user = sec_name_to_user (name);
  if (!user)
    sqlr_new_error ("42000", "SR152", "No user %s", name);
  gr = sec_name_to_user (group);
  if (!gr)
    sqlr_new_error ("42000", "SR148", "No group %s", group);

  sec_revoke_single_role (user, gr, 1);

  cli_flush_stmt_cache (user);
  qr_rec_exec (del_g_id_qr, cli, NULL, qi, NULL, 2,
      ":0", (ptrlong) user->usr_id, QRP_INT,
      ":1", (ptrlong) gr->usr_id, QRP_INT);
}


int sec_initialized = 0;

/* if only_execute_gr flag passed then do only executable grants */
caddr_t
sec_read_grants (client_connection_t * cli, query_instance_t * caller_qi,
    char *table, int only_execute_gr)
{
  dbe_schema_t * sc;
  caddr_t err = NULL;
  local_cursor_t *lc = NULL;
  sqlc_set_client (cli);
  if (!sec_initialized)
    return NULL;
  if (!table)
    table = "%";
  if (!cli)
    cli = bootstrap_cli;

  if (caller_qi)
    {
      if (caller_qi->qi_trx->lt_pending_schema)
	sc = caller_qi->qi_trx->lt_pending_schema;
      else
	sc = wi_inst.wi_schema;
      err = qr_rec_exec (only_execute_gr ? read_exec_grants_qr : read_grants_qr, cli, &lc, caller_qi, NULL, 1,
			 ":0", table, QRP_STR);
    }
  else
    {
      sc = wi_inst.wi_schema;
      err = qr_quick_exec (only_execute_gr ? read_exec_grants_qr : read_grants_qr, cli, "", &lc, 1,
			   ":0", table, QRP_STR);
    }
  if (err)
    {
      LC_FREE (lc);
      return err;
    }
  while (lc_next (lc))
    {
      oid_t grantee = (oid_t) unbox (lc_nth_col (lc, 0));
      int op = (int) unbox (lc_nth_col (lc, 1));
      char *object = lc_nth_col (lc, 2);
      char *column = lc_nth_col (lc, 3);
      QR_RESET_CTX_T (((query_instance_t *)(lc->lc_inst))->qi_thread)
        {
          sec_dd_grant (sc, object, column, 1, op, grantee);
          dk_free_tree (err); /* Can't remember more than 1 error anyway */
          err = lc->lc_error;
        }
      QR_RESET_CODE
        {
          dk_free_tree (err); /* Can't remember more than 1 error anyway */
          err = thr_get_error_code (THREAD_CURRENT_THREAD);
          POP_QR_RESET;
        }
      END_QR_RESET;
    }
  lc_free (lc);
  if (!caller_qi)
    local_commit (bootstrap_cli);
  else
    return NULL; /* do not do default grants when picking a single table from qi_read_table_schema or such */

  if (only_execute_gr) /* If called after read procs do not do default grants */
    return err;

  sec_dd_grant (isp_schema (NULL), "SYS_COLS", "_all", 1, GR_SELECT,
      U_ID_PUBLIC);
  sec_dd_grant (isp_schema (NULL), "SYS_KEYS", "_all", 1, GR_SELECT,
      U_ID_PUBLIC);
  sec_dd_grant (isp_schema (NULL), "SYS_KEY_PARTS", "_all", 1, GR_SELECT,
      U_ID_PUBLIC);
  sec_dd_grant (isp_schema (NULL), "SYS_CHARSETS", "CS_NAME", 1, GR_SELECT,
      U_ID_PUBLIC);
  sec_dd_grant (isp_schema (NULL), "SYS_CHARSETS", "CS_ALIASES", 1, GR_SELECT,
      U_ID_PUBLIC);

/* Grant privileges to all columns of SYS_PROCEDURES except P_TEXT
   and P_MORE, so that the API-function SQLProcedures shall work,
   but the ordinary mortals still do not see the source code itself.
   Added by AK 17-APR-1997.
 */
  sec_dd_grant (isp_schema (NULL), "SYS_PROCEDURES", "P_QUAL", 1, GR_SELECT,
      U_ID_PUBLIC);
  sec_dd_grant (isp_schema (NULL), "SYS_PROCEDURES", "P_OWNER", 1, GR_SELECT,
      U_ID_PUBLIC);
  sec_dd_grant (isp_schema (NULL), "SYS_PROCEDURES", "P_NAME", 1, GR_SELECT,
      U_ID_PUBLIC);
  sec_dd_grant (isp_schema (NULL), "SYS_PROCEDURES", "P_N_IN", 1, GR_SELECT,
      U_ID_PUBLIC);
  sec_dd_grant (isp_schema (NULL), "SYS_PROCEDURES", "P_N_OUT", 1, GR_SELECT,
      U_ID_PUBLIC);
  sec_dd_grant (isp_schema (NULL), "SYS_PROCEDURES", "P_N_R_SETS", 1, GR_SELECT,
      U_ID_PUBLIC);
  sec_dd_grant (isp_schema (NULL), "SYS_PROCEDURES", "P_COMMENT", 1, GR_SELECT,
      U_ID_PUBLIC);
  sec_dd_grant (isp_schema (NULL), "SYS_PROCEDURES", "P_TYPE", 1, GR_SELECT,
      U_ID_PUBLIC);
  sec_dd_grant (isp_schema (NULL), "SYS_FOREIGN_KEYS", "_all", 1, GR_SELECT,
      U_ID_PUBLIC);
  sec_dd_grant (isp_schema (NULL), "SYS_USER_TYPES", "_all", 1, GR_SELECT,
      U_ID_PUBLIC);
  return err;
}

query_t *delete_user_qr;

#ifdef UPDATE_SYS_USERS_TO_ENCRYPTED
static void
update_users (dk_set_t *users_to_set)
{
  caddr_t err = NULL;
  client_connection_t *cli = bootstrap_cli;
  query_t *set_pass_qr = sql_compile ("update SYS_USERS set U_PASSWORD = ? where U_NAME = ?",
      cli, &err, SQLC_DEFAULT);
  DO_SET (caddr_t *, user, users_to_set)
    {
      int passwd_len = box_length (user[1]);
      caddr_t enc_passwd = dk_alloc_box (passwd_len + 1, DV_SHORT_STRING);
      enc_passwd[0] = 0;
      memcpy (enc_passwd + 1, user[1], passwd_len);
      xx_encrypt_passwd (enc_passwd + 1, passwd_len, user[0]);
      dk_free_box (user[1]);
      user[1] = NULL;
      err = qr_quick_exec (set_pass_qr, cli, "", NULL, 2,
	  ":0", enc_passwd, QRP_RAW,
	  ":1", user[0], QRP_RAW);
      dk_free_box (user);
    }
  END_DO_SET();
  local_commit (bootstrap_cli);
  qr_free (set_pass_qr);
}
#endif

static query_t *read_groups_qr = NULL;

int
sec_user_has_group (oid_t CheckGroup, oid_t user)
{
  int inx;
  if (CheckGroup == user)
    return 1;
  else
    {
      user_t *u = sec_id_to_user (user);
      if (u)
	{
	  if (u->usr_g_id == CheckGroup)
	    return 1;
	  if (u->usr_g_ids)
	    {
	      _DO_BOX (inx, u->usr_g_ids)
		{
		  oid_t grp = (oid_t) (ptrlong) u->usr_g_ids[inx];
		  if (CheckGroup == grp)
		    return 1;
		}
	      END_DO_BOX;
	    }
	}
    }
  return 0;
}


int
sec_user_has_group_name (char * name, oid_t user)
{
  int inx;
  user_t *u = sec_id_to_user (user), *g;
  if (u)
    {
      if (!strcmp (u->usr_name, name))
	return 1;
      g = sec_id_to_user (u->usr_g_id);
      if (g && !strcmp (g->usr_name, name))
	return 1;
      if (u->usr_g_ids)
	{
	  _DO_BOX (inx, u->usr_g_ids)
	    {
	      oid_t grp = (oid_t) (ptrlong) u->usr_g_ids[inx];
	      g = sec_id_to_user (grp);
	      if (g && !strcmp (g->usr_name, name))
		return 1;
	    }
	  END_DO_BOX;
	}
    }
  return 0;
}


int
sec_user_is_in_hash (dk_hash_t *ht, oid_t user, int op)
{
  int inx, flags;
  flags = (long) (ptrlong) gethash ((void *) (ptrlong) user, ht);
  if (flags & op)
    return 1;
  else
    {
      user_t *u = sec_id_to_user (user);
      if (u)
	{
	  flags = (long) (ptrlong) gethash ((void *) (ptrlong) u->usr_g_id, ht);
	  if (flags & op)
	    return 1;
	  if (u->usr_g_ids)
	    {
	      _DO_BOX (inx, u->usr_g_ids)
		{
		  oid_t grp = (oid_t) (ptrlong) u->usr_g_ids[inx];
		  flags = (long) (ptrlong) gethash ((void *) (ptrlong) grp, ht);
		  if (flags & op)
		    return 1;
		}
	      END_DO_BOX;
	    }
	}
    }
  return 0;
}

static void
sec_user_read_groups (char *name)
{
  user_t *user = sec_name_to_user (name);
  local_cursor_t *lc = NULL;
  caddr_t err;
  dk_set_t groups_set = NULL;
  long elts = 0;

  if (!user)
    return;
  err = qr_quick_exec (read_groups_qr, bootstrap_cli, "", &lc, 1,
      ":0", (ptrlong) user->usr_id, QRP_INT);
  while (lc_next (lc))
    {
      oid_t gid = (oid_t) unbox (lc_nth_col (lc, 0));
      if (!dk_set_member (groups_set, (caddr_t) (ptrlong) gid))
	{
	  dk_set_push (&groups_set, (caddr_t) (ptrlong) gid);
	  elts++;
	}
    }
  lc_free (lc);
  if (user->usr_g_ids)
    {
      int inx;
      for (inx = 0; ((uint32) inx) < BOX_ELEMENTS (user->usr_g_ids); inx++)
	{
	  oid_t gid = (oid_t) (ptrlong) user->usr_g_ids[inx];
	  if (!dk_set_member (groups_set, (caddr_t) (ptrlong) gid))
	    {
	      dk_set_push (&groups_set, (caddr_t) (ptrlong) gid);
	      elts++;
	    }
	}
      dk_free_box ((box_t) user->usr_g_ids);
    }

  if (elts)
    {
      user->usr_g_ids = (ptrlong *) dk_alloc_box (elts * sizeof (caddr_t), DV_ARRAY_OF_LONG);
      DO_SET (oid_t, gid, &groups_set)
	{
          user_t *group = sec_id_to_user (gid);
	  user->usr_g_ids[--elts] = gid;
          if (NULL != group)
            sec_usr_member_ids_add (group, user);
          else
            {
              dk_set_push (&sec_pending_memberships_on_read, (void *)((ptrlong)(user->usr_id)));
              dk_set_push (&sec_pending_memberships_on_read, (void *)((ptrlong)(gid)));
            }
	}
      END_DO_SET();
    }
  else
    user->usr_g_ids = NULL;
}

void
sec_read_users (void)
{
  int save;
  caddr_t err;
  static query_t *null_users_qr = NULL;
  client_connection_t *cli = bootstrap_cli;
  static query_t *read_users_qr;
#ifdef UPDATE_SYS_USERS_TO_ENCRYPTED
  dk_set_t users_to_set = NULL;
#endif
  local_cursor_t *lc;

  if (!sec_users)
    {
      sec_users = id_str_hash_create (101);
      sec_user_by_id = hash_table_allocate (101);

      read_users_qr = sql_compile_static (
	  "select U_NAME, U_PASSWORD, U_GROUP, U_ID, U_DATA, U_ACCOUNT_DISABLED, U_SQL_ENABLE, U_IS_ROLE, U_DAV_ENABLE "
	  "from SYS_USERS", cli, &err, 0);
      PRINT_ERR(err);

      read_grants_qr = sql_compile_static (
	"select G_USER, G_OP, G_OBJECT, G_COL "
	"from SYS_GRANTS "
	"where G_OBJECT like ?", cli, &err, 0);

      read_tb_rls_qr = sql_compile_static (
	"select RLSP_TABLE, RLSP_FUNC, RLSP_OP "
	"from DB.DBA.SYS_RLS_POLICY "
	"where RLSP_TABLE like ?", cli, &err, 0);

      PRINT_ERR(err);

      read_exec_grants_qr = sql_compile_static (
	"select G_USER, G_OP, G_OBJECT, G_COL "
	"from SYS_GRANTS "
	"where G_OBJECT like ? AND G_OP = 32", cli, &err, 0);
      PRINT_ERR(err);

      set_user_qr = sql_compile_static (
	  "insert replacing SYS_USERS (U_NAME, U_PASSWORD, U_ID, U_GROUP, U_ACCOUNT_DISABLED, U_IS_ROLE, U_SQL_ENABLE, U_DAV_ENABLE) "
	  "values (?, ?, ?, ?, 0, 0, 1, case when ? = 'dba' then 1 else 0 end)", cli, &err, 0);
      PRINT_ERR(err);

      upd_user_qr = sql_compile_static ("update SYS_USERS set U_PASSWORD = ?, U_GROUP = ? where U_NAME = ?",
	  cli, &err, 0);
      PRINT_ERR(err);

      set_g_id_qr = sql_compile_static (
	  "update SYS_USERS set U_GROUP = ? where U_NAME = ?", cli, &err, 0);
      PRINT_ERR(err);

      add_g_id_qr = sql_compile_static (
	  "insert replacing SYS_ROLE_GRANTS (GI_SUPER, GI_SUB) values (?, ?)", cli, &err, 0);
      PRINT_ERR(err);

      del_g_id_qr = sql_compile_static (
	  "delete from SYS_ROLE_GRANTS where GI_SUPER = ? and GI_SUB = ?", cli, &err, 0);
      PRINT_ERR(err);

      last_id_qr = sql_compile_static (
	  "select U_ID from SYS_USERS order by U_ID desc", cli, &err, 0);
      PRINT_ERR(err);

      grant_qr = sql_compile_static (
	  "insert soft SYS_GRANTS (G_USER, G_OP, G_OBJECT, G_COL, G_GRANTOR) "
	  "values (?,?,?,?,?)", cli, &err, 0);
      PRINT_ERR(err);

      revoke_qr = sql_compile_static ("revoke_proc (?,?,?,?,?)", cli, &err, 0);
      PRINT_ERR(err);

      /* XXX: this is a some sort of a hack !!! */
      null_users_qr = sql_compile_static (
	  "update SYS_USERS set U_ID = 0, U_GROUP = 0 "
	  "where (U_ID is null or U_GROUP is null) and U_IS_ROLE = 0 and U_SQL_ENABLE = 1", cli, &err, 0);
      PRINT_ERR(err);

      delete_user_qr = sql_compile_static ("USER_DROP (?, ?)", cli, &err, 0); /* was del_user */
      PRINT_ERR(err);

      read_groups_qr = sql_compile_static (
	  "select distinct GI_SUB as GI_SUB from SYS_ROLE_GRANTS where GI_SUPER = ?", cli, &err, 0);
      PRINT_ERR(err);

      user_grant_role_qr = sql_compile_static ("USER_GRANT_ROLE (?, ?, ?)", cli, &err, 0);
      PRINT_ERR(err);

      user_revoke_role_qr = sql_compile_static ("USER_REVOKE_ROLE (?, ?)", cli, &err, 0);
      PRINT_ERR(err);

      user_create_role_qr = sql_compile_static ("USER_ROLE_CREATE (?, 0)", cli, &err, 0);
      PRINT_ERR(err);

      user_drop_role_qr = sql_compile_static ("USER_ROLE_DROP (?)", cli, &err, 0);
      PRINT_ERR(err);
    }

  /* separate txn for this.
     May fuck up on non-unique key in recovery of old databases */
  /* no users, so no mt queries, error in aq if no user exists */
  save = enable_qp;
  enable_qp = 1;
  err = qr_quick_exec (null_users_qr, cli, "", NULL, 0);
  enable_qp = save;
  PRINT_ERR(err);
  local_commit (bootstrap_cli);

  err = qr_quick_exec (read_users_qr, cli, "", &lc, 0);
  PRINT_ERR(err);
  while (lc_next (lc))
    {
      caddr_t name = lc_nth_col (lc, 0);
      caddr_t pass = lc_nth_col (lc, 1);
      int disabled = (int) unbox (lc_nth_col (lc, 5));
      int is_sql = (int) unbox (lc_nth_col (lc, 6));
      int is_role = (int) unbox (lc_nth_col (lc, 7));
      int is_dav = (int) unbox (lc_nth_col (lc, 8));
      if (is_dav && !is_sql) /* disable web accounts for SQL/ODBC login */
	disabled = 1;
      if (!DV_STRINGP (pass))
	{
	  pass = box_string ("");
	  disabled = 1;
	}
      else if (!pass[0] && box_length (pass) > 1)
	{
	  caddr_t pass_copy = dk_alloc_box_zero (box_length (pass) - 1, DV_STRING);
	  memcpy (pass_copy, pass + 1, (size_t) (box_length (pass) - 1));
	  xx_encrypt_passwd (pass_copy, box_length (pass_copy) - 1, name);
	  pass = pass_copy;
	}
      else
	{
#ifdef UPDATE_SYS_USERS_TO_ENCRYPTED
	  caddr_t *set = (caddr_t *)dk_alloc_box (2 * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
	  set[0] = box_string (name);
	  set[1] = box_string (pass);
	  dk_set_push (&users_to_set, (caddr_t) set);
#endif
	  pass = box_string (pass);
	}
      sec_make_dd_user (box_string (name), pass,
	  (oid_t) unbox (lc_nth_col (lc, 2)),
	  (oid_t) unbox (lc_nth_col (lc, 3)),
	  disabled,
	  is_sql,
	  is_role);
      sec_set_user_data (name, lc_nth_col (lc, 4));
      sec_user_read_groups (name);
    }
  lc_free (lc);

  user_t_dba = sec_name_to_user ("dba");
  user_t_nobody = sec_name_to_user ("nobody");
  user_t_ws = sec_name_to_user ("WS");
  user_t_public = sec_name_to_user ("public");
  if (!user_t_dba)
    user_t_dba = sec_set_user (NULL, "dba", "dba", 0);
  /* make sure that dba always has id and group 0, even
     if accidentally set to something else */
  user_t_dba->usr_id = 0;
  user_t_dba->usr_g_id = 0;
  user_t_dba->usr_disabled = 0;
  user_t_dba->usr_is_role = 0;
  user_t_dba->usr_is_sql = 1;
  bootstrap_cli->cli_user = user_t_dba;
  if (user_t_dba->usr_g_ids)
    {
      dk_free_box ((box_t) user_t_dba->usr_g_ids);
      user_t_dba->usr_g_ids = NULL;
    }
  if (!user_t_nobody)
    user_t_nobody = sec_set_user (NULL, "nobody", "\001\r\001\n\001", 0);
  user_t_nobody->usr_id = U_ID_NOBODY;
  user_t_nobody->usr_g_id = U_ID_NOGROUP;
  user_t_nobody->usr_disabled = 1;
  user_t_nobody->usr_is_role = 0;
  user_t_nobody->usr_is_sql = 1;
  if (!user_t_ws) /* this is a trick to have WS.WS. views compiled */
    user_t_ws = sec_new_user (NULL, box_string ("WS"), box_string ("WS"));
  user_t_ws->usr_disabled = 1; /* make it disabled */
  user_t_ws->usr_g_id = 0;         /* from DBA group*/
  if (!user_t_public) /* this is a trick to have public as a role */
    user_t_public = sec_new_user (NULL, box_string ("public"), box_string ("public"));
  user_t_public->usr_disabled = 1;
  user_t_public->usr_is_role = 1;
  user_t_public->usr_g_id = U_ID_PUBLIC;
  while (NULL != sec_pending_memberships_on_read)
    {
      ptrlong gid = (ptrlong)dk_set_pop (&sec_pending_memberships_on_read);
      ptrlong member_id = (ptrlong)dk_set_pop (&sec_pending_memberships_on_read);
      user_t *grp = sec_id_to_user (gid);
      user_t *memb = sec_id_to_user (member_id);
      if ((NULL != grp) && (NULL != memb))
        sec_usr_member_ids_add (grp, memb);
    }
  sec_initialized = 1;
  local_commit (bootstrap_cli);
#ifdef UPDATE_SYS_USERS_TO_ENCRYPTED
  if (users_to_set)
    {
      update_users (&users_to_set);
      dk_set_free (users_to_set);
    }
#endif
}

void
sec_remove_user_struct (query_instance_t * qi, user_t * user, caddr_t uname)
{
  id_hash_iterator_t it;
  char **nuser;
  user_t **puser;

  id_hash_iterator (&it, sec_users);
  while (hit_next (&it, (caddr_t *) &nuser, (caddr_t *) &puser))
    {
      if (puser && *puser && (*puser)->usr_id != user->usr_id)
	{
	  if ((*puser)->usr_g_id == user->usr_id)
	    { /* if it's a other user's primary group set it to the user name */
	      sec_set_user_group (qi, (*puser)->usr_name, (*puser)->usr_name);
	      id_hash_iterator (&it, sec_users);
	      continue;
	    }
	  else if (sec_user_has_group (user->usr_id, (*puser)->usr_id))
	    { /* if it's a other user's secondary group delete it */
	      sec_del_user_group (qi, (*puser)->usr_name, user->usr_name);
	      id_hash_iterator (&it, sec_users);
	      continue;
	    }
	}
    }
  remhash ((void *) (ptrlong) user->usr_id, sec_user_by_id);
  id_hash_remove (sec_users, (char *) &uname);
}

#define IS_DROP_CASCADE(x) \
	(IS_BOX_POINTER (x) && BOX_ELEMENTS (x) > 2 && unbox (((caddr_t *)x)[2]))
void
sec_delete_user (query_instance_t * qi, ST * tree)
{
  client_connection_t *cli = qi->qi_client;
  caddr_t err = qr_rec_exec (delete_user_qr, cli, NULL, qi, NULL, 2,
      ":0", tree->_.op.arg_1, QRP_STR,
      ":1", (ptrlong) (IS_DROP_CASCADE (tree) ? 1 : 0), QRP_INT);
#if 0
  user_t *user;
#endif

  if (err != SQL_SUCCESS)
    sqlr_resignal (err);

#if 0 /* these are in the USER_DROP PL function */
  user = sec_name_to_user ((char *)tree->_.op.arg_1);

  if (!user)
    sqlr_new_error ("28000", "SR153", "No user in delete user");
  sec_remove_user_struct (qi, user, tree->_.op.arg_1);
#endif
}


int
sec_is_owner_ddl (query_instance_t * qi, ST * tree, oid_t g_id, oid_t u_id)
{
  char * obj = NULL;
  switch (tree->type)
    {
    case TABLE_DEF:
      obj =tree->_.table_def.name;
      break;

    case INDEX_DEF:
      obj = tree->_.index.table;
      break;
    case TABLE_DROP:
      obj = tree->_.op.arg_1;
      break;
    case INDEX_DROP:
      return 1; /* check later */
    case DROP_COL:
    case TABLE_RENAME:
    case ADD_COLUMN:
    case MODIFY_COLUMN:
      obj = tree->_.op.arg_1;
      break;
    case VIEW_DEF:
      obj = tree->_.view_def.name;
      break;
    case GRANT_STMT:
    case REVOKE_STMT:
      if (tree->_.grant.ops && BOX_ELEMENTS (tree->_.grant.ops) == 1 &&
	  ((ST **)tree->_.grant.ops)[0]->_.priv_op.op == GR_REXECUTE)
	{ /* rexecute checked right here */
	  if (sec_user_has_group (0, u_id))
	    return 1;
	  return 0;
	}
      obj = tree->_.grant.table->_.table.name;
      break;
    default:
      return 0;
    }
  if (sec_tb_is_owner (NULL, qi, obj, g_id, u_id))
    return 1;
  return 0;
}


void
sec_check_ddl (query_instance_t * qi, ST * tree)
{
  client_connection_t *cli = qi->qi_client;
  user_t * usr;

  if (tree->type == SET_PASS_STMT)
    return;
  else if (tree->type == CREATE_TABLE_AS)
    return;
  else if (ST_P (tree, UDT_DEF) || ST_P (tree, UDT_DROP))
    return;

  if (!cli->cli_user ||
      sec_user_has_group (0, cli->cli_user->usr_g_id))
    return;
  usr = cli->cli_user;
  if (sec_is_owner_ddl (qi, tree, usr->usr_g_id, usr->usr_id))
    return;
  else if (ST_P (tree, ADD_COLUMN) || ST_P (tree, MODIFY_COLUMN) ||
      ST_P (tree, DROP_COL) || ST_P (tree, TABLE_RENAME) ||
      ST_P (tree, TABLE_DROP))
    {
      dbe_table_t *tb = qi_name_to_table (qi, tree->_.op.arg_1);
      if (!tb)
	switch (tree->type)
	  {
	    case TABLE_DROP: sqlr_new_error ("42S02", "SR154", "No table or view in drop table");
	    case DROP_COL: sqlr_new_error ("42S02", "SR155", "No table in alter table drop column");
	    case TABLE_RENAME: sqlr_new_error ("42S02", "SR156", "No table in table rename");
	    case ADD_COLUMN: sqlr_new_error ("42S02", "SR157", "No table in alter table add column");
	    case MODIFY_COLUMN: sqlr_new_error ("42S02", "SR157", "No in table alter table modify column");
	  }
    }
  sqlr_new_error ("42000", "SR158:SECURITY",
      "Permission denied. Must be owner of object or member of dba group.");
}

oid_t
sec_bif_caller_uid (query_instance_t * qi)
{
  oid_t user_id = 0xffffffff;
  if (!qi->qi_query->qr_proc_name)
    {
      client_connection_t *cli = qi->qi_client;
      if (NULL == cli->cli_user)
	return U_ID_DBA;
      user_id = cli->cli_user->usr_g_id;
    }
  else
    user_id = qi->qi_query->qr_proc_owner;
  return user_id;
}


int
sec_bif_caller_is_dba (query_instance_t * qi)
{
  oid_t user_id = sec_bif_caller_uid (qi);
  return sec_user_has_group (G_ID_DBA, user_id);
}


void
sec_check_dba (query_instance_t * qi, const char * func)
{
  if (!sec_bif_caller_is_dba (qi))
    sqlr_new_error ("42000", "SR159:SECURITY", "Function %.300s restricted to DBA group.", func);
}


void
sec_stmt_exec (query_instance_t * qi, ST * tree)
{
  client_connection_t *cli = qi->qi_client;
  char szBuffer[4096];
  caddr_t *old_log = qi->qi_trx->lt_replicate;

  if (tree->type == SET_PASS_STMT)
    {
      caddr_t *log_array;
      if (0 != strcmp (cli->cli_user->usr_pass, tree->_.op.arg_1))
	sqlr_new_error ("42000", "SR160", "Incorrect old password in set password");
      qi->qi_trx->lt_replicate = REPL_NO_LOG;
      QR_RESET_CTX_T (qi->qi_thread)
	{
	  sec_set_user (qi, cli->cli_user->usr_name, tree->_.op.arg_2, 1);
	}
      QR_RESET_CODE
	{
	  POP_QR_RESET;
	  qi->qi_trx->lt_replicate = old_log;
	  longjmp_splice (THREAD_CURRENT_THREAD->thr_reset_ctx, reset_code);
	}
      END_QR_RESET
      qi->qi_trx->lt_replicate = old_log;

      log_array = (caddr_t *) dk_alloc_box (6 * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
      log_array[0] = box_string ("sec_set_user_struct (?, ?, ?, ?, ?)");
      log_array[1] = box_string (cli->cli_user->usr_name);
      log_array[2] = box_string (cli->cli_user->usr_pass);
      log_array[3] = box_num (cli->cli_user->usr_id);
      log_array[4] = box_num (cli->cli_user->usr_g_id);
      log_array[5] = box_string (cli->cli_user->usr_data);
      log_text_array (qi->qi_trx, (caddr_t) log_array);
      dk_free_tree ((box_t) log_array);
      return;
    }

  QR_RESET_CTX_T (qi->qi_thread)
    {
      szBuffer[0] = 0;
      switch (tree->type)
	{
	  case CREATE_USER_STMT:
	      qi->qi_trx->lt_replicate = REPL_NO_LOG;
	      sec_set_user (qi, tree->_.op.arg_1, tree->_.op.arg_1, 0);
	      snprintf (szBuffer, sizeof (szBuffer), "CREATE USER %s", tree->_.op.arg_1);
	      break;
	  case SET_GROUP_STMT:
	      qi->qi_trx->lt_replicate = REPL_NO_LOG;
	      sec_set_user_group (qi, tree->_.op.arg_1, tree->_.op.arg_2);
	      snprintf (szBuffer, sizeof (szBuffer), "SET USER GROUP %s %s", tree->_.op.arg_1, tree->_.op.arg_2);
	      break;
	  case REVOKE_STMT:
	  case GRANT_STMT:
	      sec_run_grant_revoke (qi, tree);
	      break;
	  case DELETE_USER_STMT:
	      qi->qi_trx->lt_replicate = REPL_NO_LOG;
	      sec_delete_user (qi, tree);
	      snprintf (szBuffer, sizeof (szBuffer), "DELETE USER %s", tree->_.op.arg_1);
	      break;
	  case ADD_GROUP_STMT:
	      qi->qi_trx->lt_replicate = REPL_NO_LOG;
	      sec_add_user_group (qi, tree->_.op.arg_1, tree->_.op.arg_2);
	      snprintf (szBuffer, sizeof (szBuffer), "ADD USER GROUP %s %s", tree->_.op.arg_1, tree->_.op.arg_2);
	      break;
	  case DELETE_GROUP_STMT:
	      qi->qi_trx->lt_replicate = REPL_NO_LOG;
	      sec_del_user_group (qi, tree->_.op.arg_1, tree->_.op.arg_2);
	      snprintf (szBuffer, sizeof (szBuffer), "DELETE USER GROUP %s %s", tree->_.op.arg_1, tree->_.op.arg_2);
	      break;
	  case REVOKE_ROLE_STMT:  /* for these and below make log entry */
	  case GRANT_ROLE_STMT:
	      sec_run_grant_revoke_role (qi, tree);
	      break;
	  case CREATE_ROLE_STMT:
	  case DROP_ROLE_STMT:
	      sec_run_create_drop_role (qi, tree);
	      break;
	  default:
	      sqlr_new_error ("42000", "SR161", "Unsupported security statement.");
	}
    }
  QR_RESET_CODE
    {
      POP_QR_RESET;
      qi->qi_trx->lt_replicate = old_log;
      longjmp_splice (qi->qi_thread->thr_reset_ctx, reset_code);
    }
  END_QR_RESET;
  qi->qi_trx->lt_replicate = old_log;

  if (szBuffer[0])
    {
      caddr_t log = list (1, box_dv_short_string (szBuffer));
      log_text_array (qi->qi_trx, log);
      dk_free_tree (log);
    }
}

long cli_encryption_on_password = 0; /* digest */
static caddr_t caller_id_defaults = NULL;

static void
sec_caller_id_defaults_init (void)
{
  if (cli_encryption_on_password != -1)
    {
      cdef_add_param ((caddr_t **) &caller_id_defaults,
	  "SQL_ENCRYPTION_ON_PASSWORD", cli_encryption_on_password);
    }
  else
    caller_id_defaults = dk_alloc_box (0, DV_ARRAY_OF_POINTER);
}

static caddr_t
sec_caller_id_server_hook (void)
{
  return box_copy_tree (caller_id_defaults);
}

static query_t *sec_call_login_hook_qr;
static query_t *sec_call_find_user_qr;

void
sec_init (void)
{
  caddr_t err = NULL;
  sec_call_login_hook_qr = sql_compile_static (
      "DB.DBA.USER_CERT_LOGIN (?, ?, ?)", /* in UID, in digest, in secret */
      bootstrap_cli,
      &err,
      SQLC_DEFAULT);
  if (err)
    {
      if (err != (caddr_t) SQL_NO_DATA_FOUND)
	log_error ("Error compiling the DBEV_LOGIN call [%.5s] : %.200s",
	    ERR_STATE (err),
	    ERR_MESSAGE (err));
      else
	log_error ("Error compiling the DBEV_LOGIN call : <NOT FOUND>");
      dk_free_tree (err);
    }

  err = NULL;
  sec_call_find_user_qr = sql_compile_static (
      "DB.DBA.USER_FIND (?)", /* in u_name */
      bootstrap_cli,
      &err,
      SQLC_DEFAULT);
  if (err)
    {
      if (err != (caddr_t) SQL_NO_DATA_FOUND)
	log_error ("Error compiling the USER_FIND call [%.5s] : %.200s",
	    ERR_STATE (err),
	    ERR_MESSAGE (err));
      else
	log_error ("Error compiling the USER_FIND call : <NOT FOUND>");
      dk_free_tree (err);
    }
  sec_caller_id_defaults_init ();
  PrpcSetCallerIDServerHook (sec_caller_id_server_hook);
  failed_login_init ();
}


int
sec_call_login_hook (caddr_t *puid, caddr_t digest, dk_session_t *ses, client_connection_t *cli)
{
  caddr_t err = NULL;
  local_cursor_t *lc;
  caddr_t *cli_ret;
  caddr_t uid = *puid;
  int ret = PLLH_NO_AUTH;

/*  return PLLH_VALID; */

  if (!dbev_enable)
    return ret;
  if (!sch_proc_def (isp_schema (NULL),
	"DB.DBA.USER_CERT_LOGIN"))
    return ret;

  sqlc_set_client (cli);
  local_start_trx (cli);
  cli_set_start_times (cli);
  err = qr_quick_exec (sec_call_login_hook_qr, cli, NULL,
      &lc, 3,
      ":0", box_copy (uid), QRP_RAW,
      ":1", box_copy (digest), QRP_RAW,
      ":2", box_copy (ses->dks_peer_name), QRP_RAW);

  if (err)
    {
      if (err != (caddr_t) SQL_NO_DATA_FOUND)
	log_error ("Error calling DB.DBA.DBEV_LOGIN [%.5s] : %.200s",
	    ERR_STATE (err),
	    ERR_MESSAGE (err));
      else
	log_error ("Error calling DB.DBA.DBEV_LOGIN : <NOT FOUND>");
      dk_free_tree (err);
      goto done;
    }
  if (!lc || !lc->lc_proc_ret)
    {
      log_info ("DB.DBA.DBEV_LOGIN called, but no result returned");
      goto done;
    }
  cli_ret = (caddr_t *)lc->lc_proc_ret;
  ret = (int) unbox (cli_ret[1]);
  if (ret != PLLH_NO_AUTH && ret != PLLH_VALID && ret != PLLH_INVALID)
    {
      log_error ("DB.DBA.DBEV_LOGIN returned %ld. Valid values are -1, 0 and 1", ret);
      ret = PLLH_NO_AUTH;
      goto done;
    }
  if (ret == PLLH_INVALID)
    {
      goto done;
    }
  if (!DV_STRINGP (cli_ret[2]))
    {
      log_error ("DB.DBA.DBEV_LOGIN returned UID of type %s.", dv_type_title (DV_TYPE_OF (cli_ret[3])));
      goto done;
    }
  dk_free_tree (*puid);
  *puid = box_copy (cli_ret[2]);
done:
  if (lc)
    lc_free (lc);
  local_commit_end_trx (cli);
  return ret;
}


void
sec_call_find_user_hook (caddr_t uname, dk_session_t * ses)
{
  caddr_t err = NULL;
  client_connection_t *cli = ses ? DKS_DB_DATA (ses) : NULL;

  if (!sch_proc_def (isp_schema (NULL), "DB.DBA.USER_FIND") || !cli)
    return;

  local_start_trx (cli);
  err = qr_quick_exec (sec_call_find_user_qr, cli, NULL,
      NULL /*&lc*/, 1, ":0", box_dv_short_string (uname), QRP_RAW);

  if (err)
    {
      if (err != (caddr_t) SQL_NO_DATA_FOUND)
	log_error ("Error calling DB.DBA.USER_FIND [%.5s] : %.200s",
	    ERR_STATE (err),
	    ERR_MESSAGE (err));
      else
	log_error ("Error calling DB.DBA.USER_FIND : <NOT FOUND>");
      dk_free_tree (err);
    }

  local_commit_end_trx (cli);
  return;
}


void
sec_rls_set (dbe_schema_t * sc, char *table, char *procedure, char *op, int is_grant)
{
  dbe_table_t *tb = sch_name_to_table (sc, table);
  if (!tb)
    return;
  if (!op || strlen (op) < 1)
    return;
  dk_free_box (tb->tb_rls_procs[TB_RLS_OP_TO_INX(*op)]);
  tb->tb_rls_procs[TB_RLS_OP_TO_INX (*op)] = is_grant ? box_string (procedure) : NULL;
}


caddr_t
sec_read_tb_rls (client_connection_t * cli, query_instance_t * caller_qi, char *table)
{
  dbe_schema_t * sc;
  caddr_t err = NULL;
  local_cursor_t *lc = NULL;
  sqlc_set_client (cli);

  if (!table)
    table = "%";

  if (!cli)
    cli = bootstrap_cli;

  if (!read_tb_rls_qr)
    return NULL;

  if (caller_qi)
    {
      if (caller_qi->qi_trx->lt_pending_schema)
	sc = caller_qi->qi_trx->lt_pending_schema;
      else
	sc = wi_inst.wi_schema;
      err = qr_rec_exec (read_tb_rls_qr, cli, &lc, caller_qi, NULL, 1,
			 ":0", table, QRP_STR);
    }
  else
    {
      sc = wi_inst.wi_schema;
      err = qr_quick_exec (read_tb_rls_qr, cli, "", &lc, 1,
			   ":0", table, QRP_STR);
    }
  if (err)
    {
      LC_FREE (lc);
      return err;
    }
  while (lc_next (lc))
    {
      char *table = lc_nth_col (lc, 0);
      char *procedure = lc_nth_col (lc, 1);
      char *op = lc_nth_col (lc, 2);

      sec_rls_set (sc, table, procedure, op, 1);
    }
  err = lc->lc_error;
  lc_free (lc);
  if (!caller_qi)
    local_commit (bootstrap_cli);

  return err;
}

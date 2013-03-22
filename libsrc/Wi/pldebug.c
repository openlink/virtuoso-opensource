/*
 *  pldebug.c
 *
 *  $Id$
 *
 *  PL Debugger
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
 */

#include "sqlnode.h"
#include "sqlfn.h"
#include "log.h"
#include "wirpce.h"
#include "security.h"
#include "xmltree.h"
#include "pldebug.h"
#include "sqlcmps.h"
#include "sqlintrp.h"
#include "sqlbif.h"
#include "sqltype.h"

#ifdef WIN32
#include "wiservic.h"
#endif

#define SES_WRITE(ses, s) session_buffered_write (ses, s, strlen (s))
#define PLD_GET_FRAME(cli) (cli->cli_pldbg->pd_frame ? \
			    cli->cli_pldbg->pd_frame : cli->cli_pldbg->pd_inst)
#define QI_LINE_NO(qi)	(qi->qi_last_break ? ((instruction_t *)(qi->qi_last_break))->_.breakpoint.line_no  : -1)
#define QI_STATE(qi)	(qi->qi_last_break ? ((instruction_t *)(qi->qi_last_break))->_.breakpoint.scope  : NULL)
#define QR_TEXT(qr) 	((qr) ? ((qr)->qr_module ? (qr)->qr_module->qr_text : (qr)->qr_text) : NULL)

dk_mutex_t * pldbg_mtx;
semaphore_t * pldbg_sem;
basket_t pldbg_queue;
dk_set_t pldbg_brk = NULL;
dk_mutex_t * pldbg_brk_mtx;
resource_t * pldbg_rc;


pldbg_message_t *
pd_allocate (void)
{
  NEW_VARZ (pldbg_message_t, pd);
  return pd;
}

void
pd_free (pldbg_message_t * pd)
{
  dk_free ((caddr_t) pd, -1);
}

void
pd_clear (pldbg_message_t * pd)
{
  pd->msg = NULL;
  pd->ses = NULL;
  pd->mode = 0;
}

static void
pldbg_printf (char * buf, size_t buf_len, char *str, ...)
{
  va_list ap;
  va_start (ap, str);
  vsnprintf (buf, buf_len, str, ap);
  va_end (ap);
}

static void pldbg_print_value (dk_session_t * ses, box_t box, query_instance_t * qi);

void
pldbg_break_delete (void * ins)
{
  mutex_enter (pldbg_brk_mtx);
  DO_SET (caddr_t *, elm, &pldbg_brk)
    {
      void * inst = elm[2];
      if (inst == ins)
	{
	  dk_set_delete (&pldbg_brk, (void *)elm);
	  dk_free_box ((box_t) elm);
	  break;
	}
    }
  END_DO_SET ()
  mutex_leave (pldbg_brk_mtx);
}

void
pldbg_udt_print_object (caddr_t udi, dk_session_t *ses, query_instance_t * qi)
{
  char tmp[1024];
  sql_class_t *udt = UDT_I_CLASS (udi);
  if (udt && udt->scl_member_map)
    {
      if (udt->scl_ext_lang == UDT_LANG_SQL)
	{
	  int i;
	  DO_BOX (sql_field_t *, fld, i, udt->scl_member_map)
	    {
	      caddr_t val = UDT_I_VAL(udi, i);
	      snprintf (tmp, sizeof (tmp), "\t%s=", fld->sfl_name);
	      SES_PRINT (ses, tmp);
	      if (DV_TYPE_OF (val) != DV_REFERENCE)
		{
		  pldbg_print_value (ses, val, qi);
		  SES_PRINT (ses, "\n");
		}
	      else
		SES_PRINT (ses, "\t<object ref>\n");
	    }
	  END_DO_BOX;
	}
      else
	{
	  switch (udt->scl_ext_lang)
	    {
	      case UDT_LANG_JAVA:
		    {
		      snprintf (tmp, sizeof (tmp), "\tjvm obj %s\n", udt->scl_ext_name);
		      SES_PRINT (ses, tmp);
		    }
		  break;
	      case UDT_LANG_CLR:
		    {
		      snprintf (tmp, sizeof (tmp), "\tclr obj %s\n", udt->scl_ext_name);
		      SES_PRINT (ses, tmp);
		    }
		  break;
	    }
	}
    }
  else if (udt)
    {
      snprintf (tmp, sizeof (tmp), "\tnon-inst %s\n", udt->scl_name);
      SES_PRINT (ses, tmp);
    }
}

static void
pldbg_print_value (dk_session_t * ses, box_t box, query_instance_t *qi)
{
  char tmp[1024];
  dtp_t dtp = DV_TYPE_OF (box);
  switch (dtp)
    {
      case DV_DB_NULL:
	    {
	      SES_PRINT (ses, "<DB_NULL>");
	      break;
	    }
      case DV_ARRAY_OF_POINTER:
      case DV_LIST_OF_POINTER:
	    {
	      int i, l = BOX_ELEMENTS (box);
	      SES_PRINT (ses, "(");
	      for (i = 0; i < l; i++)
		{
		  pldbg_print_value (ses, ((caddr_t *)box)[i], qi);
		  SES_PRINT (ses, " ");
		}
	      SES_PRINT (ses, ")");
	      break;
	    }
      case DV_ARRAY_OF_FLOAT:
	    {
	      int i, l = box_length (box) / sizeof (float);
	      SES_PRINT (ses, "#F(");
	      for (i = 0; i < l; i++)
		{
		  char buffer[50];
		  snprintf (buffer, sizeof (buffer), "%f ", ((float *) box)[i]);
		  SES_PRINT (ses, buffer);
		}
	      SES_PRINT (ses, ")");
	      break;
	    }
      case DV_ARRAY_OF_DOUBLE:
	    {
	      int i, l = box_length (box) / sizeof (double);
	      SES_PRINT (ses, "#D(");
	      for (i = 0; i < l; i++)
		{
		  char buffer[50];
		  snprintf (buffer, sizeof (buffer), "%f ", ((double *) box)[i]);
		  SES_PRINT (ses, buffer);
		}
	      SES_PRINT (ses, ")");
	      break;
	    }
      case DV_ARRAY_OF_LONG:
	    {
	      int i, l = box_length (box) / sizeof (ptrlong);
	      SES_PRINT (ses, "L(");
	      for (i = 0; i < l; i++)
		{
		  char buffer[50];
		  snprintf (buffer, sizeof (buffer), "%ld ", (long) ((ptrlong *) box)[i]);
		  SES_PRINT (ses, buffer);
		}
	      SES_PRINT (ses, ")");
	      break;
	    }
#ifdef BIF_XML
	case DV_XML_ENTITY:
	  {
	     SES_PRINT (ses, "XML{\n");
	     ((xml_entity_t *)box)->_->xe_serialize ((xml_entity_t *)box, ses);
	     SES_PRINT (ses, "\n}");
	     break;
	  }
#endif
	case DV_COMPOSITE:
	  {
	    snprintf (tmp, sizeof (tmp), "<COMPOSITE tag = %d>\n", (int) dtp);
	    SES_PRINT (ses, tmp);
	    break;
	  }
        case DV_BLOB:
	case DV_BLOB_HANDLE:
	case DV_BLOB_BIN:
	case DV_BLOB_WIDE:
	case DV_BLOB_WIDE_HANDLE:
	case DV_BLOB_XPER:
	case DV_BLOB_XPER_HANDLE:
	  {
	    SES_PRINT (ses, "<BLOB>");
	    break;
	  }
	case DV_OBJECT:
	  {
	    sql_class_t * udt = UDT_I_CLASS (box);
	    snprintf (tmp, sizeof (tmp), "{\n\t[obj:%p %s]\n", box, udt->scl_name);
	    SES_PRINT (ses, tmp);
	    pldbg_udt_print_object (box, ses, qi);
	    SES_PRINT (ses, "}\n");
	  }
	break;
	case DV_REFERENCE:
	  {
	    caddr_t udi = udo_dbg_find_object_by_ref (qi, box);
	    sql_class_t * udt = udi ? UDT_I_CLASS (udi) : NULL;
	    SES_PRINT (ses, "{\n\tREF:");
	    if (!udt)
	      SES_PRINT (ses, "(null)");
	    else
	      {
		snprintf (tmp, sizeof (tmp), "[ref:%p obj:%p %s]\n", box, udi, udt->scl_name);
		SES_PRINT (ses, tmp);
		pldbg_udt_print_object (udi, ses, qi);
	      }
	    SES_PRINT (ses, "}\n");
	  }
	break;
	case DV_BIN:
	  {
	    snprintf (tmp, sizeof (tmp), " LEN %d", box_length (box));
	    SES_PRINT (ses, tmp);
	  }
	break;
      default:
	    {
	      caddr_t err_ret = NULL;
	      caddr_t strval;
	      strval = box_cast_to (NULL, (caddr_t)box, dtp, DV_SHORT_STRING,
		  NUMERIC_MAX_PRECISION, NUMERIC_MAX_SCALE, &err_ret);
	      if (!err_ret && strval)
		{
		  if (IS_STRING_DTP (dtp))
		    SES_PRINT (ses, "'");
		  SES_PRINT (ses, strval);
		  if (IS_STRING_DTP (dtp))
		    SES_PRINT (ses, "'");
		}
	      else
		SES_PRINT (ses, "<box>");
	    }
    }
}

static int
pldbg_ssl_set (state_slot_t * ssl, caddr_t * qst, caddr_t value)
{
  if (!ssl || !qst || !ssl_is_settable (ssl))
    return 0;
  else
    {
      caddr_t err_ret = NULL;
      caddr_t oldval = qst_get (qst, ssl);
      dtp_t dtp = DV_TYPE_OF (oldval);
      caddr_t newval = box_cast_to (NULL, value,
	  DV_TYPE_OF (value), dtp,
	  NUMERIC_MAX_PRECISION, NUMERIC_MAX_SCALE,
	  &err_ret);
      if (!err_ret && newval)
	{
	  qst_set (qst, ssl, newval);
	  return 1;
	}
      dk_free_tree (err_ret);
      dk_free_tree (newval);
      return 0;
    }
}

static void
pldbg_ssl_print (char * buf, size_t buf_len, state_slot_t * ssl, caddr_t * qst)
{
  query_instance_t * qi = (query_instance_t *) qst;
  if (!ssl)
    {
      pldbg_printf (buf, buf_len, " <none> ");
      return;
    }
  if (((state_slot_t *) -1L) == ssl)
    {
      pldbg_printf (buf, buf_len, " <proc table> ");
      return;
    }
  switch (ssl->ssl_type)
    {
    case SSL_PARAMETER:
    case SSL_COLUMN:
    case SSL_VARIABLE:
    case SSL_REF_PARAMETER:
    case SSL_REF_PARAMETER_OUT:
    case SSL_VEC:
    case SSL_REF:
	  {
	    caddr_t value = qst_get (qst, ssl);
	    dtp_t dtp = DV_TYPE_OF (value);
	    caddr_t strval;
	    dk_session_t * out_ses = strses_allocate ();
            pldbg_print_value (out_ses, value, qi);
	    strval = strses_string (out_ses);
	    strses_free (out_ses);
	    pldbg_printf (buf, buf_len, "$%d \"%s\" %s (%d) %s", ssl->ssl_index, ssl->ssl_name,
		  dv_type_title(dtp), dtp, strval);
	  }
      break;

    case SSL_CONSTANT:
	{
	  caddr_t err_ret = NULL;
	  if (DV_TYPE_OF (ssl->ssl_constant) == DV_DB_NULL)
	    pldbg_printf (buf, buf_len, "<constant DB_NULL>");
	  else
	    {
	      caddr_t strval = box_cast_to (NULL, ssl->ssl_constant,
		  DV_TYPE_OF (ssl->ssl_constant), DV_SHORT_STRING,
		  NUMERIC_MAX_PRECISION, NUMERIC_MAX_SCALE,
		  &err_ret);
	      if (!err_ret && strval)
		pldbg_printf (buf, buf_len, "<constant (" EXPLAIN_LINE_MAX_STR_FORMAT ")>", strval);
	      else
		pldbg_printf (buf, buf_len, "<constant>");
	      if (err_ret)
		dk_free_tree (err_ret);
	      if (strval)
		dk_free_box (strval);
	    }
	}
      break;

    default:
      pldbg_printf (buf, buf_len, "<$%d \"%s\" spec %d>", ssl->ssl_index,
	  ssl->ssl_name ? ssl->ssl_name : "-", ssl->ssl_type);
      break;
    }
}

static long
pldbg_count_lines (char * body)
{
  long br = 0;
  char *ptr = body;
  if (!body)
    return 0;
  while (*ptr)
    {
      if ((*ptr == 0x0A && *(ptr+1) == 0x0D) ||
	  (*ptr == 0x0D && *(ptr+1) == 0x0A))
	{
	  br++;
	  ptr++;
	}
      else if (*ptr == 0x0A || *ptr == 0x0D)
	{
	  br++;
	}
      ptr++;
    }
  return br;
}

static int
pldbg_get_line (char * body, long line, char * buf, int buf_len)
{
  char *start = body, *ptr = body;
  char *end, *end1, *end2;
  long br = 1;
  char l_no [10];
  if (!body || line < 1)
    return 0;
  while (*ptr && br < line)
    {
      if ((*ptr == 0x0A && *(ptr+1) == 0x0D) ||
	  (*ptr == 0x0D && *(ptr+1) == 0x0A))
	{
	   start = ptr+2;
	   br++;
	   ptr++;
	}
      else if (*ptr == 0x0A || *ptr == 0x0D)
	{
	  start = ptr+1;
	  br++;
	}
      ptr++;
    }
  if (br < line)
    return 0;
  if (start)
    {
      end1 = strchr (start, 0x0a);
      end2 = strchr (start, 0x0d);
      if (end1 && end2 && end1 < end2)
	end = end1;
      else if (end1 && end2 && end2 < end1)
	end = end2;
      else if (!end1 && end2)
	end = end2;
      else if (!end2 && end1)
	end = end1;
      else
	end = NULL;
      snprintf (l_no, sizeof (l_no), "%ld ", line);
      strncat_size_ck (buf, l_no, buf_len - strlen (buf), buf_len);
      buf[buf_len - 1] = 0;
      if (end)
	{
	  if ((end - start) < PLD_LINE_LIMIT)
	    strncat_size_ck (buf, start, (size_t)(end - start), buf_len);
	  else
	    strncat_size_ck (buf, start, PLD_LINE_LIMIT, buf_len);
	}
      else
	{
	  strncat_size_ck (buf, start, PLD_LINE_LIMIT, buf_len);
	}
      return 1;
    }
  return 0;
}

static void
pldbg_session_cleanup (dk_session_t * ses)
{
  int is_in_step;
  client_connection_t *cli = DKS_DB_DATA (ses);
  query_instance_t * qi = cli && cli->cli_pldbg ? cli->cli_pldbg->pd_inst : NULL;
  pldbg_t * dbginf;
  if (!cli)
    return;
  dbginf = cli->cli_pldbg;
  cli->cli_pldbg->pd_session = NULL;
  cli->cli_pldbg->pd_send = NULL;
  cli->cli_pldbg->pd_step = PLDS_NONE;
  is_in_step = cli->cli_pldbg->pd_is_step;
  cli->cli_pldbg->pd_is_step = 0;
  if (is_in_step && qi && qi->qi_query)
    {
      query_instance_t * cur_qi = qi;
      while (IS_POINTER(cur_qi))
	{
	  cur_qi->qi_step = PLDS_NONE;
	  sqlc_set_brk (cur_qi->qi_query, -1, 2, NULL); /* must be more precise, remove all active brks for now */
	  cur_qi = cur_qi->qi_caller;
	}
      semaphore_leave (dbginf->pd_sem);
    }
  DKS_DB_DATA (ses) = NULL;
}

void
pldbg_out_ready (dk_session_t * ses, caddr_t msg)
{
  pldbg_message_t *pd = (pldbg_message_t *) resource_get (pldbg_rc);
  pd->ses = ses;
  pd->msg = msg;
  pd->mode = PD_OUT;

  mutex_enter (pldbg_mtx);
  basket_add (&pldbg_queue, (void *) pd);
  mutex_leave (pldbg_mtx);

  semaphore_leave (pldbg_sem);
}

void
pldbg_make_answer (void * cli1)
{
  client_connection_t * cli = (client_connection_t *) cli1;
  caddr_t msg;
  char tmp [4096];
  query_instance_t * qi = cli->cli_pldbg->pd_inst;
  char * body = (qi && qi->qi_query ? QR_TEXT(qi->qi_query) : NULL);
  tmp[0] = 0;
  if (qi && pldbg_get_line (body, QI_LINE_NO(qi), tmp, sizeof (tmp)))
    {
      if (srv_have_global_lock (qi->qi_thread))
	strcat_ck (tmp, "\nWarning: You're stepping thru the code in atomic mode.");
      msg = box_dv_short_string (tmp);
    }
  else
    msg = box_dv_short_string ("Step over last statement");
  pldbg_out_ready (cli->cli_pldbg->pd_session, msg);
}

static query_t *
pldbg_get_qr (char * name)
{
  int inx;
  query_t * qr = NULL;
  const char * pname;

  if (!name)
    return NULL;

  pname = sch_full_proc_name (wi_inst.wi_schema, name, "DB", "DBA");
  if (pname)
    qr = sch_proc_def (wi_inst.wi_schema, pname);
  if (!qr) /* triggers */
    {
      dbe_table_t *tb;
      char * tb_name = strchr (name, '@'), *trig_name = name;

      if (!tb_name)
	goto try_udt;

      *tb_name = 0;
      tb_name ++;
      tb = sch_name_to_table (isp_schema (NULL), tb_name);

      if (!tb)
	goto try_udt;

      DO_SET (query_t *, trig_qr, &tb->tb_triggers->trig_list)
	{
	  if (!CASEMODESTRCMP (trig_name, trig_qr->qr_proc_name))
	    {
	      qr = trig_qr;
	      break;
	    }
	}
      END_DO_SET ();
    }
try_udt:
  if (!qr)
    {
      sql_class_t *udt;
      char * method_name = strrchr (name, '.'), *class_name = name;
      char * constructor_name = strrchr (name, ':');
      int what = UDT_METHOD_INSTANCE; /* or UDT_METHOD_CONSTRUCTOR */

      if (!method_name && !constructor_name)
	return NULL;

      if (constructor_name)
	{
	  method_name = constructor_name;
	  what = UDT_METHOD_CONSTRUCTOR;
	}

      *method_name = 0;
      method_name ++;
      udt = sch_name_to_type (isp_schema (NULL), class_name);
      if (udt && udt->scl_method_map)
	{
	  DO_BOX (sql_method_t *, mtd, inx, udt->scl_method_map)
	    {
	      if (mtd->scm_type == what && !CASEMODESTRCMP (method_name, mtd->scm_name))
		{
		  qr = mtd->scm_qr;
		  break;
		}
	    }
	  END_DO_BOX;
	}
    }
  return qr;
}

int
pldbg_cmd_execute (dk_session_t * ses, caddr_t * args)
{
  int cmd = BOX_ELEMENTS (args) ? (int) unbox(args[0]) : -1;
  char tmp [4096];
  dk_session_t * out_ses = strses_allocate ();
  caddr_t msg = NULL, err = NULL;
  int send_answer = 1;
  size_t tmp_len = sizeof (tmp);

  tmp[0] = 0;
  switch (cmd)
    {
      case PD_BREAK: /* set a breakpoint  */
      case PD_DELETE: /* delete a breakpoint  */
	    {
	      caddr_t inst = NULL;
	      char * pname = BOX_ELEMENTS (args) > 1 ? args[1] : NULL; /*make it full*/
	      int break_to_delete = 0;
	      if (pname && alldigits (pname))
		{
		  break_to_delete = atoi (pname);
		  pname = NULL;
		}
	      if (pname || cmd == PD_BREAK)
		{
		  int bre = BOX_ELEMENTS (args) > 2 ? (int) unbox (args[2]) : 0;
		  int to_delete = (cmd == PD_DELETE ? 1 : 0);
		  query_t * qr = pldbg_get_qr (pname);
		  if (qr)
		    {
		      if (qr->qr_to_recompile)
			qr = qr_recompile (qr, &err);
		      if (!qr) /* can't be recompiled */
			{
			  msg = ERR_MESSAGE (err);
			  ERR_MESSAGE (err) = NULL;
			  dk_free_tree (err);
			  break;
			}
		      mutex_enter (pldbg_brk_mtx);
		      bre = sqlc_set_brk (qr, bre, to_delete ? 0 : 2, &inst);
		      if (bre > 0)
			{
			  if (!to_delete)
			    {
			      int found = 0, nth = 0;
			      DO_SET (caddr_t *, elm, &pldbg_brk)
				{
				  if (!strcmp (elm[0], qr->qr_proc_name) && bre == (long) (ptrlong) elm[1])
				    {
				      found++;
				      break;
				    }
				  nth ++;
				}
			      END_DO_SET ();
			      if (!found)
				pldbg_brk = dk_set_conc (pldbg_brk,
				    dk_set_cons ((void *) list (4, qr->qr_proc_name, bre, inst, ++nth), NULL));
			    }
			  else
			    {
			      DO_SET (caddr_t *, elm, &pldbg_brk)
				{
				  if (!strcmp (elm[0], qr->qr_proc_name) && bre == (long) (ptrlong) elm[1])
				    {
				      dk_set_delete (&pldbg_brk, (void *)elm);
				      dk_free_box ((box_t) elm);
				      break;
				    }
				}
			      END_DO_SET ()
			    }
			}
		      mutex_leave (pldbg_brk_mtx);
		      if (0 < bre)
			snprintf (tmp, sizeof (tmp), "%sBreakpoint at: procedure %s, line %d", to_delete ? "Deleted " : "",
			    qr->qr_proc_name, bre);
		      else
			snprintf (tmp, sizeof (tmp), "Can't find a breakpoint at: procedure %s, line %d", qr->qr_proc_name, bre);
		      msg = box_dv_short_string (tmp);
		    }
		  else
		    msg = box_dv_short_string ("There is no such procedure");
		}
	      else
		{
		  int n = 0, found = 0;
		  mutex_enter (pldbg_brk_mtx);
		  DO_SET (caddr_t *, elm, &pldbg_brk)
		    {
		      n++;
		      if (!break_to_delete || break_to_delete == (int) (ptrlong) elm[3])
			{
			  found++;
			  inst = elm[2];
			  sqlc_set_brk (NULL, 0, 0, &inst);
			  dk_set_delete (&pldbg_brk, (void *)elm);
			  dk_free_box ((box_t) elm);
			}
		    }
		  END_DO_SET ()
		  mutex_leave (pldbg_brk_mtx);
		  if (found && break_to_delete)
		    snprintf (tmp, sizeof (tmp), "Deleted: breakpoint number %d.", break_to_delete);
		  else if (!found && break_to_delete)
		    snprintf (tmp, sizeof (tmp), "No breakpoint number %d.", break_to_delete);
		  else
		    snprintf (tmp, sizeof (tmp), "All breakpoints are deleted");
		  msg = box_dv_short_string (tmp);
		}
	    }
	  break;
      case PD_NEXT: /* do next */
      case PD_STEP: /* step into */
      case PD_FINISH: /* finish current */
      case PD_UNTIL: /* finish current or stop at line */
	    {
	      caddr_t inst = NULL;
	      int step = (cmd == PD_STEP ? PLDS_STEP : PLDS_NEXT);
	      /* never set step to the PLDS_NONE as it's a test to leave the semaphore*/
	      client_connection_t *cli = DKS_DB_DATA (ses);
	      if (cli && cli->cli_pldbg && cli->cli_pldbg->pd_is_step)
		{
		  query_instance_t * qi = cli->cli_pldbg->pd_inst;
		  query_instance_t * cur_qi = qi->qi_caller;

		  if (cmd == PD_UNTIL)
		    {
		      char * pname = BOX_ELEMENTS (args) > 1 ? args[1] : NULL; /*make it full*/
		      int bre;
		      query_t * qr;
		      if (alldigits (pname) && BOX_ELEMENTS (args) == 2)
			{
			  bre = atoi (pname);
			  qr = qi->qi_query;
			}
		      else
			{
			  bre = BOX_ELEMENTS (args) > 2 ? (int) unbox (args[2]) : 0;
			  qr = pldbg_get_qr (pname);
			}

		      if (qr)
			{
			  if (qr->qr_to_recompile)
			    qr = qr_recompile (qr, &err);
			  if (!qr) /* can't be recompiled */
			    {
			      msg = ERR_MESSAGE (err);
			      ERR_MESSAGE (err) = NULL;
			      dk_free_tree (err);
			      break;
			    }
			  mutex_enter (pldbg_brk_mtx);
			  bre = sqlc_set_brk (qr, bre, 1, &inst);
			  mutex_leave (pldbg_brk_mtx);
			}
		    }

		  if (!(cli->cli_pldbg->pd_step & (PLDS_STEP|PLDS_NEXT))) /* entering stepping mode */
		    {
		      while (IS_POINTER(cur_qi))
			{
			  cur_qi->qi_step = PLDS_STEP;
			  cur_qi = cur_qi->qi_caller;
			}
		    }
		  if (cmd == PD_FINISH || cmd == PD_UNTIL)
		    qi->qi_step = PLDS_NONE;
		  cli->cli_pldbg->pd_step = step;
		  cli->cli_pldbg->pd_send = pldbg_make_answer;
	          semaphore_leave (cli->cli_pldbg->pd_sem);
		  send_answer = 0;
		}
	      else
		msg = box_dv_short_string ("There is no active statements to step");
	    }
	  break;
      case PD_INFO: /* miscellaneous info */
	    {
	      int infoi = BOX_ELEMENTS (args) > 1 ? (int) unbox(args[1]) : -1; /* what info requested */
	      switch (infoi)
		{
		  case PDI_BREAK:
			{
			  int found = 0;
			  mutex_enter (pldbg_brk_mtx);
			  DO_SET (caddr_t *, elm, &pldbg_brk)
			    {
			      found++;
			      snprintf (tmp, sizeof (tmp), "%d %s:%ld\n", (int) (ptrlong) elm[3], elm[0], (long) (ptrlong) elm[1]);
			      SES_WRITE (out_ses, tmp);
			    }
			  END_DO_SET ();
			  mutex_leave (pldbg_brk_mtx);
			  if (!found)
			    msg = box_dv_short_string ("No breakpoints.");
			  else
			    msg = strses_string (out_ses);
			  break;
			}
		  case PDI_CLI: /* XXX: clients */
			{
			  dk_set_t clis;
			  mutex_enter (thread_mtx);
			  clis = srv_get_logons ();
			  mutex_leave (thread_mtx);
			  DO_SET (dk_session_t *, ses, &clis)
			    {
			      if (ses->dks_peer_name && DKS_DB_DATA(ses))
				{
				  SES_WRITE (out_ses, ses->dks_peer_name);
				  SES_WRITE (out_ses, "\n");
				}
			    }
			  END_DO_SET ();
			  msg = strses_string (out_ses);
			  break;
			}
		  case PDI_THRE: /* stopped threads */
			{
			  char conn_id[30];
			  client_connection_t * cli;
			  IN_TXN;
			  DO_SET (lock_trx_t *, lt, &all_trxs)
			    {
			      cli = lt->lt_client;
			      ASSERT_IN_TXN;
			      if (cli && lt->lt_threads > 0)
				{
				  query_instance_t * qi = cli->cli_pldbg->pd_inst;
				  dk_session_t * c_ses = cli->cli_http_ses ? cli->cli_http_ses : cli->cli_session;

				  if (!cli->cli_pldbg->pd_id)
				    {
				      if (c_ses && c_ses->dks_peer_name)
					cli->cli_pldbg->pd_id = box_copy (c_ses->dks_peer_name);
				      else
					{
					  char * ct = cli && cli->cli_ws ? "HTTP" : "INTERNAL";
					  snprintf (conn_id, sizeof (conn_id), "%s:%lX", ct, (unsigned long) (uptrlong) cli);
					  cli->cli_pldbg->pd_id = box_dv_short_string (conn_id);
					}
				    }


				  snprintf (tmp, sizeof (tmp), "@%s in %s () at %ld\n",
				     cli->cli_pldbg->pd_id,
				     (qi && qi->qi_query->qr_proc_name ? qi->qi_query->qr_proc_name : "??"),
				     (long) (qi ? QI_LINE_NO(qi) : -1));
				  SES_PRINT (out_ses, tmp);
				}
			    }
			  END_DO_SET ();
			  LEAVE_TXN;
			  msg = strses_string (out_ses);
			  break;
			}
		  default:
		      msg = box_dv_short_string ("There is no such info");
		      break;
		}
	    }
	  break;
      case PD_LIST: /* do a list */
	    {
	      char * pname = BOX_ELEMENTS (args) > 1 ? args[1] : NULL; /*make it full*/
	      int line_no = BOX_ELEMENTS (args) > 2 ? (int) unbox (args[2]) : 1;
	      query_t * qr = pldbg_get_qr (pname);
	      if (!pname)
		{
		  client_connection_t *cli = DKS_DB_DATA (ses);
		  if (cli && cli->cli_pldbg && cli->cli_pldbg->pd_is_step)
		    {
		      query_instance_t * qi = PLD_GET_FRAME(cli);
		      long line_no = QI_LINE_NO(qi);
		      char * body = qi->qi_query ? QR_TEXT(qi->qi_query) : NULL;
		      snprintf (tmp, sizeof (tmp), "Current breakpoint: procedure %s, line %ld\n",
			  qi->qi_query->qr_proc_name, line_no);

		      strcat_ck (tmp, " ");
		      if (pldbg_get_line (body, line_no - 1, tmp, sizeof (tmp)))
			strcat_ck (tmp, "\n*");
		      if (pldbg_get_line (body, line_no, tmp, sizeof (tmp)))
			strcat_ck (tmp, "\n ");
		      pldbg_get_line (body, line_no + 1, tmp, sizeof (tmp));

		      if (strlen (tmp) > 1)
			msg = box_dv_short_string (tmp);
		      else
			msg = box_dv_short_string ("There is no such line");
		    }
		  else
		    msg = box_dv_short_string ("There is no active statements");
		}
	      else if (qr)
		{
		  int i, have_one = 0;
		  for (i = line_no; i < line_no + 10; i++)
		    {
		      tmp[0] = 0;
		      if (!pldbg_get_line (QR_TEXT(qr), i, tmp, sizeof (tmp)))
			{
			  if (!have_one)
			    {
			      snprintf (tmp, sizeof (tmp), "Line number %d out of range\n", line_no);
			      SES_PRINT (out_ses, tmp);
			    }
			  break;
			}
		      have_one ++;
		      SES_PRINT (out_ses, tmp);
		      SES_PRINT (out_ses, "\n");
		    }
		  msg = strses_string (out_ses);
		}
	      else
		msg = box_dv_short_string ("There is no such procedure");
	    }
	  break;
      case PD_WHERE: /* where, call stack */
	    {
	      client_connection_t *cli = DKS_DB_DATA (ses);
	      if (cli && cli->cli_pldbg && cli->cli_pldbg->pd_is_step)
		{
		  int n = 0;
		  query_instance_t * qi = cli->cli_pldbg->pd_inst, *cur_qi;
		  const char * proc_name;

		  cur_qi = qi;
		  while (IS_POINTER(cur_qi))
		    {
		      long line_no = QI_LINE_NO(cur_qi);
		      proc_name = cur_qi->qi_query && cur_qi->qi_query->qr_proc_name ?
			  cur_qi->qi_query->qr_proc_name : "??";
		      pldbg_printf (tmp, tmp_len, "#%d %s () at %ld\n", n++, proc_name, line_no);
		      SES_PRINT (out_ses, tmp);
		      cur_qi = cur_qi->qi_caller;
		    }
		  msg = strses_string (out_ses);
		}
	      else
		msg = box_dv_short_string ("There is no active statements");
	      break;
	    }
      case PD_FRAME: /* set the current frame */
	    {
	      client_connection_t *cli = DKS_DB_DATA (ses);
	      int fram = BOX_ELEMENTS (args) > 1 ? (int) unbox(args[1]) : -1;
	      if (cli && cli->cli_pldbg && cli->cli_pldbg->pd_is_step)
		{
		  int n = 0, found = 0;
		  query_instance_t * qi = cli->cli_pldbg->pd_inst, *cur_qi;
		  char * proc_name;
		  cur_qi = qi;
		  cli->cli_pldbg->pd_frame = NULL;
		  while (IS_POINTER(cur_qi))
		    {
		      long line_no = QI_LINE_NO(cur_qi);
		      proc_name = cur_qi->qi_query && cur_qi->qi_query->qr_proc_name ?
			  cur_qi->qi_query->qr_proc_name : NULL;
		      if (n == fram && proc_name)
			{
			  pldbg_printf (tmp, tmp_len, "#%d %s () at %ld\n", n, proc_name, line_no);
			  SES_PRINT (out_ses, tmp);
			  cli->cli_pldbg->pd_frame = cur_qi;
			  found ++;
			  break;
			}
		      cur_qi = cur_qi->qi_caller;
		      n++;
		    }
		  if (found)
		    msg = strses_string (out_ses);
		  else
		    msg = box_dv_short_string ("Can't go to the specified frame number.");
		}
	      else
		msg = box_dv_short_string ("There is no active statements");
	      break;
	    }
      case PD_CONT: /* continue */
	    {
	      client_connection_t *cli = DKS_DB_DATA (ses);
	      query_instance_t * qi = cli && cli->cli_pldbg->pd_is_step ? cli->cli_pldbg->pd_inst : NULL;
	      if (cli)
		{
		  cli->cli_pldbg->pd_step = PLDS_NONE;
		  cli->cli_pldbg->pd_send = NULL;
		}
	      if (qi && qi->qi_query)
		{
		  query_instance_t * cur_qi = qi;
		  while (IS_POINTER(cur_qi))
		    {
		      cur_qi->qi_step = PLDS_NONE;
		      cur_qi = cur_qi->qi_caller;
		    }
		  semaphore_leave (cli->cli_pldbg->pd_sem);
		  msg = box_dv_short_string ("Execution resumed");
		}
	      else
		msg = box_dv_short_string ("There is no active statements to resume");
	    }
	 break;
      case PD_ATTACH: /* attach */
	    {
	      char * name = BOX_ELEMENTS (args) > 1 ? args[1] : NULL; /* connection ID */
	      client_connection_t *cli = NULL;
	      if (name && name[0] == '@')
		{
		  name++;
		  IN_TXN;
		  DO_SET (lock_trx_t *, lt, &all_trxs)
		    {
		      cli = lt->lt_client;
		      if (cli && lt->lt_threads > 0)
			{
			  if (cli &&
			      cli->cli_pldbg->pd_id && !strcmp (cli->cli_pldbg->pd_id, name))
			    break;
			}
		      cli = NULL;
		    }
		  END_DO_SET ();
		  LEAVE_TXN;
		}
	      else if (NULL == name) /* connect to first available */
		{
		  IN_TXN;
		  DO_SET (lock_trx_t *, lt, &all_trxs)
		    {
		      cli = lt->lt_client;
		      if (cli && lt->lt_threads > 0)
			{
			  if (cli && cli->cli_pldbg->pd_id)
			    {
			      name = cli->cli_pldbg->pd_id;
			      break;
			    }
			}
		      cli = NULL;
		    }
		  END_DO_SET ();
		  LEAVE_TXN;
		}
	      else
		{
		  dk_session_t *r_ses;
                  r_ses = name ? PrpcFindPeer (name) : NULL;
                  cli = r_ses ? DKS_DB_DATA (r_ses) : NULL;
		}
	      if (cli && (!cli->cli_pldbg || !cli->cli_pldbg->pd_session))
		{
		  int is_in_step;
	          cli->cli_pldbg->pd_session = (dk_session_t *) ses;
		  is_in_step = cli->cli_pldbg->pd_is_step;
		  pldbg_session_cleanup (ses); /* detach if already attached */
	          DKS_DB_DATA (ses) = cli;
		  if (!is_in_step)
		    cli->cli_pldbg->pd_step = PLDS_INT;
		  msg = box_dv_short_string (name);
		}
	      else if (cli && cli->cli_pldbg && cli->cli_pldbg->pd_session)
		{
		  msg = box_dv_short_string ("The connection is in use");
		}
	      else
		msg = box_dv_short_string ("Can't find connection to attach");
	    }
	 break;
      case PD_PRINT: /* print state */
	    {
	      char * name = BOX_ELEMENTS (args) > 1 ? args[1] : NULL; /* variable name */
	      client_connection_t *cli = DKS_DB_DATA (ses);
	      query_instance_t * qi = cli && cli->cli_pldbg ? PLD_GET_FRAME(cli) : NULL;
	      tmp[0] = 0;
	      if (qi && qi->qi_query && name) /*XXX: for now only if specified*/
		{
		  dk_set_t state_scope = QI_STATE(qi);
		  state_slot_t * found = NULL;
		  DO_SET (state_slot_t *, ssl, &state_scope)
		    {
		      char * name1 = ssl->ssl_name;
		      if (name1 && !CASEMODESTRCMP (name1, name))
			found = ssl; /*get the last one*/
		    }
		  END_DO_SET ();
		  if (!found)
		    pldbg_printf (tmp, tmp_len, "No symbol '%s' in current context.", (name ? name : "(nil)"));
		  else
		    pldbg_ssl_print (tmp, tmp_len, found, (caddr_t *) qi);
		  msg = box_dv_short_string (tmp);
		}
	      else
		msg = box_dv_short_string ("There is no active statement");
	    }
	 break;
      case PD_SET: /* set state */
	    {
	      char * name = BOX_ELEMENTS (args) > 1 ? args[1] : NULL; /* variable name */
	      caddr_t value = BOX_ELEMENTS (args) > 2 ? args[2] : NULL; /* new value */
	      client_connection_t *cli = DKS_DB_DATA (ses);
	      query_instance_t * qi = cli && cli->cli_pldbg ? PLD_GET_FRAME(cli) : NULL;
	      tmp[0] = 0;
	      if (qi && qi->qi_query && name)
		{
		  state_slot_t * found = NULL;
		  dk_set_t state_scope = QI_STATE(qi);
		  DO_SET (state_slot_t *, ssl, &state_scope)
		    {
		      char * name1 = ssl->ssl_name;
		      if (name1 && !CASEMODESTRCMP (name1, name))
			found = ssl;
		    }
		  END_DO_SET ();
		  if (!found)
		    pldbg_printf (tmp, tmp_len, "No symbol '%s' in current context.", (name ? name : "(nil)"));
		  else
		    {
		      if (!pldbg_ssl_set (found, (caddr_t *) qi, value))
			pldbg_printf (tmp, tmp_len, "Can't set '%s' to '%s'.", (name ? name : "(nil)"),
			    (value ? value : "(nil)"));
		      else
			pldbg_ssl_print (tmp, tmp_len, found, (caddr_t *) qi);
		    }
		  msg = box_dv_short_string (tmp);
		}
	      else if (!name)
		pldbg_printf (tmp, tmp_len, "No symbol specified");
	      else
		msg = box_dv_short_string ("There is no active statement");
	    }
	 break;
      default:
	   {
	     char * opt_name = BOX_ELEMENTS (args) > 1 ? args[1] : NULL; /*name of command*/
	     if (opt_name)
	       snprintf (tmp, sizeof (tmp), "Undefined command: %s", opt_name);
	     else
	       snprintf (tmp, sizeof (tmp), "Undefined command: %d", cmd);
	     msg = box_dv_short_string (tmp);
	   }
         break;
    }

  if (send_answer)
    pldbg_out_ready (ses, msg);
  strses_free (out_ses);
  return 1;
}

void
pldbg_loop (void)
{
  int mode;
  dk_session_t *ses;
  caddr_t cmd;
  pldbg_message_t * pd;
  for(;;)
    {
      semaphore_enter (pldbg_sem);
      mutex_enter (pldbg_mtx);
      pd = (pldbg_message_t *) basket_get (&pldbg_queue);
      ses = pd->ses;
      cmd = pd->msg;
      mode = pd->mode;
      resource_store (pldbg_rc, (void *) pd);
      mutex_leave (pldbg_mtx);
      if (!cmd || !DKSESSTAT_ISSET (ses, SST_OK))
	{
	  pldbg_session_cleanup (ses);
	  PrpcDisconnect (ses);
	  PrpcSessionFree (ses);
	  continue;
	}
      /* do operation */
      switch (mode)
	{
	  case PD_IN:
	      pldbg_cmd_execute (ses, (caddr_t *)cmd);
	      PrpcCheckInAsync (ses);
	      break;
	  case PD_OUT:
		{
	          PrpcWriteObject (ses, cmd);
		  if (!DKSESSTAT_ISSET (ses, SST_OK))
		    {
		      pldbg_session_cleanup (ses);
		      PrpcDisconnect (ses);
		      PrpcSessionFree (ses);
		    }
		}
	      break;
	  default:
	      break;
	}
      dk_free_tree (cmd);
    }
}

void
pldbg_session_dropped (dk_session_t * ses)
{
  if (DKSESSTAT_ISSET (ses, SST_NOT_OK))
    remove_from_served_sessions (ses);
}

void
pldbg_input_ready (dk_session_t * ses)
{
  pldbg_message_t *pd;
  caddr_t cmd;

  remove_from_served_sessions (ses);
  cmd = (caddr_t) PrpcReadObject (ses);

  pd = (pldbg_message_t *) resource_get (pldbg_rc);
  pd->ses = ses;
  pd->msg = cmd;
  pd->mode = PD_IN;

  mutex_enter (pldbg_mtx);
  basket_add (&pldbg_queue, (void *) pd);
  mutex_leave (pldbg_mtx);

  semaphore_leave (pldbg_sem);
}

caddr_t
sf_pl_debug (caddr_t name, caddr_t digest)
{
  dk_session_t *client = IMMEDIATE_CLIENT;
  user_t * user;
  user = sec_check_login (name, digest, client);
  if (!user || !sec_user_has_group (G_ID_DBA, user->usr_id))
    {
      log_info ("Bad debug console login %s.", name);
      DKST_RPC_DONE (client);
      PrpcDisconnect (client);
      return box_num(0);
    }
  client->dks_is_server = 0; /* XXX: no auto dealloc when dead hook called */
  PrpcSetPartnerDeadHook (client, (io_action_func) pldbg_session_dropped);
  SESSION_SCH_DATA (client)->sio_default_read_ready_action =
	  (io_action_func) pldbg_input_ready;
  return box_num(1);
}

/* source and line are from module's qr */
#define QR_SOURCE(qr) (qr->qr_module ? qr->qr_module->qr_source : qr->qr_source)
#define QR_LINE(qr)   (qr->qr_module ? qr->qr_module->qr_line : qr->qr_line)

static void
pldbg_stats (query_t *qr, caddr_t * result1, int add_line, caddr_t udt_name)
{
  dk_set_t setl = NULL, setc = NULL;
  caddr_t * result;
  long lines_cnt = 0;
  if (qr && !qr->qr_to_recompile)
    {
      if (add_line)
	lines_cnt = pldbg_count_lines (QR_TEXT(qr));
      result = (caddr_t *) list (3, list (7,
	    box_copy_tree (qr->qr_proc_name),
	    QR_SOURCE(qr) ? box_copy (QR_SOURCE(qr)) : box_dv_short_string ("unnamed"),
	    box_num (qr->qr_calls),
	    box_num (lines_cnt),
	    box_num (qr->qr_time_cumulative),
	    (udt_name ? box_copy (udt_name) : NEW_DB_NULL),
	    box_num (qr->qr_self_time)),
	  	NULL, NULL);
    }
  else
    result = (caddr_t *) NEW_DB_NULL;
  if (qr && qr->qr_line_counts)
    {
      char tmp [1024];
      int32 line, cnt;
      ptrlong linel, cntl;
      ptrlong *pcnt;
      caddr_t *calle;
      dk_hash_iterator_t hit;
      id_hash_iterator_t it;

      if (add_line) /* ensure all lines in hash */
	{
	  DO_INSTR (instr, 0, qr->qr_head_node->src_pre_code)
	    {
	      if (instr->ins_type == INS_BREAKPOINT)
		{
		  line = (int32) instr->_.breakpoint.line_no;
		  cnt = (int32) (ptrlong) gethash ((void *) (ptrlong) line, qr->qr_line_counts);
		  if (!cnt)
		    sethash ((void *) (ptrlong) line,  qr->qr_line_counts, (void *) (ptrlong) cnt);
		}
	    }
	  END_DO_INSTR;
	}

      dk_hash_iterator (&hit, qr->qr_line_counts);
      while (dk_hit_next (&hit, (void**) &linel, (void**) &cntl))
	{
          line = (int32) linel;
          cnt = (int32) cntl;
	  if (!cnt && !add_line)
	    continue;
	  tmp[0] = 0;
	  if (add_line)
	    {
	      pldbg_get_line (QR_TEXT(qr), line, tmp, sizeof (tmp));
	      tmp [50] = 0;
	    }
	  dk_set_push (&setl, list (3, box_num(line + QR_LINE(qr)), box_num(cnt), box_dv_short_string (tmp)));
	}
      result[1] = list_to_array (dk_set_nreverse (setl));
      if (qr->qr_call_counts)
	{
	  id_hash_iterator (&it, qr->qr_call_counts);
	  while (hit_next (&it, (char**) &calle, (char**) &pcnt))
	    {
	      dk_set_push (&setc, list (2, box_copy_tree (*calle), box_num(*pcnt)));
	    }
	}
      result[2] = list_to_array (dk_set_nreverse (setc));
    }
  else
    {
      if (ARRAYP (result))
	{
	  result [1] = NEW_DB_NULL;
	  result [2] = NEW_DB_NULL;
	}
    }
  if (result1)
    *result1 = (caddr_t)result;
}

static caddr_t
bif_pldbg_stats (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t pname = BOX_ELEMENTS (args) > 0 ? bif_string_or_null_arg (qst, args, 0, "pldbg_stats") : NULL;
  long add_line = (long)(BOX_ELEMENTS (args) > 1 ? bif_long_arg (qst, args, 1, "pldbg_stats") : 0);
  caddr_t udt_name = (caddr_t)(BOX_ELEMENTS (args) > 2 ?
      bif_string_or_null_arg (qst, args, 2, "pldbg_stats") : NULL);
  long all_udt = (long)(BOX_ELEMENTS (args) > 3 ? bif_long_arg (qst, args, 3, "pldbg_stats") : 0);
  dbe_schema_t * sc = isp_schema (qi->qi_space);
  query_t *qr = NULL;
  caddr_t result = NULL;

  if (pname)
    {
      if (udt_name)
	{
	  sql_class_t *udt = bif_udt_arg (qst, args, 2, "pldbg_stats");
	  int inx;

	  if (udt->scl_method_map)
	    {
	      for (inx = 0; inx < UDT_N_METHODS (udt); inx++)
		{
		  sql_method_t *mtd = &(udt->scl_methods[inx]);
		  if (!CASEMODESTRCMP (pname, mtd->scm_name))
		    {
		      qr = mtd->scm_qr;
		      break;
		    }
		}
	    }
	}
      else
	qr = sch_proc_def (sc, pname);
      pldbg_stats (qr, &result, add_line, udt_name);
    }
  else
    {
      dk_set_t all_proc = NULL;
      caddr_t result1;
      query_t **ptp;
      id_casemode_hash_iterator_t it;
      id_casemode_hash_iterator (&it, sc->sc_name_to_object[sc_to_proc]);

      while (id_casemode_hit_next (&it, (caddr_t *) & ptp))
	{
	  qr = *ptp;
	  if (!qr || !qr->qr_calls || qr->qr_to_recompile)
	    continue;
	  pldbg_stats (qr, &result1, add_line, NULL);
	  dk_set_push (&all_proc, result1);
	}
      if (all_udt)
	{
	  sql_class_t **pcls;

	  id_casemode_hash_iterator (&it, sc->sc_name_to_object[sc_to_type]);
	  while (id_casemode_hit_next (&it, (caddr_t *) & pcls))
	    {
	      int inx;
	      sql_class_t *udt = *pcls;

	      if (udt->scl_method_map)
		{
		  for (inx = 0; inx < UDT_N_METHODS (udt); inx++)
		    {
		      sql_method_t *mtd = &(udt->scl_methods[inx]);
		      qr = mtd->scm_qr;
		      if (!qr || !qr->qr_calls || qr->qr_to_recompile)
			continue;
		      pldbg_stats (qr, &result1, add_line, udt->scl_name);
		      dk_set_push (&all_proc, result1);
		    }
		}
	    }
	}
      result = list_to_array (dk_set_nreverse (all_proc));
    }

  return (caddr_t)result;
}

/*TODO: make sure that array offsets are tested*/
static caddr_t
bif_pldbg_stats_load (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t * data = (caddr_t *)bif_strict_array_or_null_arg (qst, args, 0, "pldbg_stats_load");
  query_t *qr = NULL;
  long calls, time, self_time;
  caddr_t * pdata, pname, err = NULL, udt_name;

  if (!(pl_debug_all & 2))
    return box_num(0);

  if (!data || BOX_ELEMENTS(data) < 3
      || !ARRAYP(data[0]) || !ARRAYP(data[1]) || !ARRAYP(data[2]))
    return box_num(0);

  pdata = (caddr_t *)(data[0]);
  pname = pdata[0];
  calls = (long) unbox (pdata[2]);
  time = (long) unbox (pdata[3]);
  udt_name = (BOX_ELEMENTS (pdata) > 4 && DV_STRINGP(pdata[4]) ? pdata[4] : NULL);
  self_time = (long)(BOX_ELEMENTS (pdata) > 5 ? unbox (pdata[5]) : 0);

  if (!IS_STRING_DTP(DV_TYPE_OF(pname)) && DV_C_STRING != DV_TYPE_OF(pname))
    return box_num(0);
  if (udt_name)
    {
      sql_class_t *udt = sch_name_to_type (isp_schema (NULL), udt_name);
      int inx;

      if (udt && udt->scl_method_map)
	{
	  for (inx = 0; inx < UDT_N_METHODS (udt); inx++)
	    {
	      sql_method_t *mtd = &(udt->scl_methods[inx]);
	      if (!CASEMODESTRCMP (pname, mtd->scm_name))
		{
		  qr = mtd->scm_qr;
		  break;
		}
	    }
	}
    }
  else
    qr = sch_proc_def (isp_schema (qi->qi_space), pname);

  if (qr)
    {
      int inx;
      if (qr->qr_to_recompile)
	qr = qr_recompile (qr, &err);
      if (!qr) /* can't be recompiled, skip */
	return box_num(0);
      DO_BOX (caddr_t *, elm, inx, (caddr_t *)(data[1]))
	{
	  int32 lineno, cnt, curct;
	  lineno = (int32) (unbox(elm[0]) - QR_LINE(qr));
	  cnt = (int32) unbox(elm[1]);
	  curct = (int32) (ptrlong) gethash ((void *) (ptrlong) lineno, qr->qr_line_counts);
	  cnt += curct;
	  sethash ((void *) (ptrlong) lineno,  qr->qr_line_counts, (void *) (ptrlong) cnt);
	}
      END_DO_BOX;

      DO_BOX (caddr_t *, elm, inx, (caddr_t *)(data[2]))
	{
	  caddr_t caller_name;
	  int32 cnt;
	  ptrlong *callct;
          caller_name = elm[0];
	  cnt = (int32) unbox(elm[1]);

	  callct = (ptrlong *) id_hash_get (qr->qr_call_counts, (caddr_t)&caller_name);
	  if (callct)
	    (*callct) += cnt;
	  else
	    {
	      caddr_t caller_name1 = box_copy (caller_name);
	      ptrlong callct = cnt;
	      id_hash_set (qr->qr_call_counts, (caddr_t)&caller_name1, (caddr_t)&callct);
	    }

	}
      END_DO_BOX;
      qr->qr_calls += calls;
      qr->qr_time_cumulative += time;
      qr->qr_self_time += self_time;
    }
  return box_num(1);
}

static void
pldbg_stats_clear (query_t *qr)
{
  qr->qr_calls = 0;
  qr->qr_self_time = 0;
  qr->qr_time_cumulative = 0;
  if (qr->qr_line_counts)
    {
      hash_table_free (qr->qr_line_counts);
      qr->qr_line_counts = hash_table_allocate (100);
    }
  if (qr->qr_call_counts)
    {
      id_hash_iterator_t it;
      caddr_t *calle;
      ptrlong *pcnt;

      id_hash_iterator (&it, qr->qr_call_counts);
      while (hit_next (&it, (char**) &calle, (char**) &pcnt))
	{
	  dk_free_tree (calle[0]);
	}
      id_hash_free (qr->qr_call_counts);
      qr->qr_call_counts = id_str_hash_create (101);
    }
}

static caddr_t
bif_pldbg_stats_clear (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  dbe_schema_t * sc = isp_schema (qi->qi_space);
  query_t *qr = NULL;
  query_t **ptp;
  sql_class_t **pcls;
  id_casemode_hash_iterator_t it;
  id_casemode_hash_iterator (&it, sc->sc_name_to_object[sc_to_proc]);

  while (id_casemode_hit_next (&it, (caddr_t *) & ptp))
    {
      qr = *ptp;
      if (!qr || !qr->qr_calls || qr->qr_to_recompile)
	continue;
      pldbg_stats_clear (qr);
    }
  id_casemode_hash_iterator (&it, sc->sc_name_to_object[sc_to_type]);
  while (id_casemode_hit_next (&it, (caddr_t *) & pcls))
    {
      int inx;
      sql_class_t *udt = *pcls;

      if (udt->scl_method_map)
	{
	  for (inx = 0; inx < UDT_N_METHODS (udt); inx++)
	    {
	      sql_method_t *mtd = &(udt->scl_methods[inx]);
	      qr = mtd->scm_qr;
	      if (!qr || !qr->qr_calls || qr->qr_to_recompile)
		continue;
	      pldbg_stats_clear (qr);
	    }
	}
    }
  return (caddr_t) NEW_DB_NULL;
}


void
pldbg_init (void)
{
  dk_thread_t *pldbg_thr;
  bif_define ("pldbg_stats", bif_pldbg_stats);
  bif_define ("pldbg_stats_load", bif_pldbg_stats_load);
  bif_define ("pldbg_stats_clear", bif_pldbg_stats_clear);

  pldbg_mtx = mutex_allocate ();
  pldbg_brk_mtx = mutex_allocate ();
  pldbg_sem = semaphore_allocate (0);
  pldbg_rc = resource_allocate (100, (rc_constr_t) pd_allocate, (rc_destr_t) pd_free, (rc_destr_t) pd_clear, 0);

  PrpcRegisterServiceDesc (&s_pl_debug, (server_func) sf_pl_debug);
  pldbg_thr = PrpcThreadAllocate ((thread_init_func) pldbg_loop, 50000, NULL);

  if (!pldbg_thr)
    {
      log_error ("Can't start the server because it can't create a system thread. Exiting");
      GPF_T;
    }
}

/*
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

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ksrvext.h>
#ifdef WIN32
#include <windows.h>
#include <process.h>
WINBASEAPI DWORD WINAPI
SignalObjectAndWait (HANDLE hObjectToSignal,
HANDLE hObjectToWaitOn, DWORD dwMilliseconds, BOOL bAlertable);
#endif

static caddr_t
bif_my_aref (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t arr = bif_array_arg (qst, args, 0, "my_aref");
  long inx = bif_long_arg (qst, args, 1, "my_aref");
  dtp_t vectype = DV_TYPE_OF (arr);
  int n_elems = (box_length (arr) / get_itemsize_of_vector (vectype));

  if ((inx >= n_elems) || (inx < 0))	/* Catch negative indexes also! */
    {
      sqlr_error ("42000",
	  "aref: Bad array subscript (zero-based) %d for an arg of type %s "
	  "(%d) and length %d.",
	  inx, dv_type_title (vectype), vectype, n_elems);
    }
  else
    {
      return (gen_aref (arr, inx, vectype, "my_aref"));
    }

  return NULL;
}


static caddr_t
bif_my_vector (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  int len = BOX_ELEMENTS (args);
  caddr_t *res = (caddr_t *) dk_alloc_box (len * sizeof (caddr_t),
      DV_ARRAY_OF_POINTER);
  int inx;
  for (inx = 0; inx < len; inx++)
    {
      res[inx] = box_copy_tree (bif_arg (qst, args, inx, "my_vector"));
    }
  return ((caddr_t) res);
}


#define N_COLS 11
static caddr_t
bif_my_select (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  static char *count_stmt_text = "select count (*) from DB.DBA.SYS_KEYS";
  static char *select_stmt_text =
      "select "
      " KEY_TABLE, "
      " KEY_NAME, "
      " KEY_ID, "
      " KEY_N_SIGNIFICANT, "
      " KEY_CLUSTER_ON_ID, "
      " KEY_IS_MAIN, "
      " KEY_IS_OBJECT_ID, "
      " KEY_IS_UNIQUE, "
      " KEY_MIGRATE_TO, "
      " KEY_SUPER_ID, " " KEY_DECL_PARTS " " from DB.DBA.SYS_KEYS";

  long len, inx, col;
  client_connection_t *cli = qi_client (qst);

  caddr_t **result = NULL;
  query_t *count_stmt = NULL, *select_stmt = NULL;
  local_cursor_t *lc = NULL;

  if (NULL == (count_stmt = sql_compile (count_stmt_text, cli, err_ret, 0)))
    goto end;

  if (NULL != (*err_ret =
	  qr_rec_exec (count_stmt, cli, &lc, (query_instance_t *) qst, NULL,
	      0)))
    goto end;

  if (lc)
    {
      if (lc->lc_error)
	{
	  *err_ret = box_copy_tree (lc->lc_error);
	  goto end;
	}
      while (lc_next (lc))
	len = unbox (lc_nth_col (lc, 0));
      lc_free (lc);
      lc = NULL;
    }
  qr_free (count_stmt);
  count_stmt = NULL;

  result =
      (caddr_t **) dk_alloc_box (len * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
  memset (result, 0, len * sizeof (caddr_t));

  if (NULL == (select_stmt = sql_compile (select_stmt_text, cli, err_ret, 0)))
    goto end;

  if (NULL != (*err_ret =
	  qr_rec_exec (select_stmt, cli, &lc, (query_instance_t *) qst, NULL,
	      0)))
    goto end;

  inx = 0;
  if (lc)
    {
      while (lc_next (lc) && inx < len)
	{
	  if (lc->lc_error)
	    {
	      *err_ret = box_copy_tree (lc->lc_error);
	      goto end;
	    }
	  result[inx] =
	      (caddr_t *) dk_alloc_box (N_COLS * sizeof (caddr_t),
	      DV_ARRAY_OF_POINTER);
	  memset (result[inx], 0, N_COLS * sizeof (caddr_t));
	  for (col = 0; col < N_COLS; col++)
	    result[inx][col] = box_copy_tree (lc_nth_col (lc, col));
	  inx++;
	}
      lc_free (lc);
      lc = NULL;
    }

  qr_free (select_stmt);
  select_stmt = NULL;

end:
  if (lc)
    lc_free (lc);
  if (count_stmt)
    qr_free (count_stmt);
  if (select_stmt)
    qr_free (select_stmt);
  if (*err_ret)
    {
      dk_free_tree (result);
      result = NULL;
    }
  return (caddr_t) result;
}




ST *
nk_tree_and (ST * left, ST * right)
{
  if (left && right)
    return ((ST *) list (4, BOP_AND, left, right, NULL));
  if (left)
    return left;
  return right;
}

void
nk_test_add (ST * outer_texp, char *corr_name, int uid)
{
  /* add a exists (select 1 from need_to_know where nk_class = <corr_name>.r_class) */
  ST *sel, *exists, *texp, **from;
  ST *where =
      (ST *) list (4, BOP_EQ, list (3, COL_DOTTED, NULL,
  box_string ("NK_CLASS")),
      list (3, COL_DOTTED, box_string (corr_name), box_string ("R_CLASS")),
      NULL);
  where =
      nk_tree_and (where, listst (4, BOP_EQ, list (3, COL_DOTTED, NULL,
	  box_string ("NK_USER")), box_num (uid), NULL));
  from =
      (ST **) list (1, list (3, TABLE_REF, list (5, TABLE_DOTTED,
	   box_string ("DB.DBA.NEED_TO_KNOW"), NULL, box_num (0),
	      box_num (0)), NULL));
  texp = listst (9, TABLE_EXP, from, where, NULL, NULL, NULL, -1, NULL, NULL);
  sel = listst (5, SELECT_STMT, NULL, list (1, box_num (1)), NULL, texp);
  exists = (ST *) list (5, EXISTS_PRED, NULL, sel, NULL, NULL);
  outer_texp->_.table_exp.where =
      nk_tree_and (outer_texp->_.table_exp.where, exists);
}


static caddr_t
bif_need_to_know (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  unsigned inx;
  caddr_t uid = (caddr_t) bif_long_arg (qst, args, 0, "need_to_know");
  ST *tree = (ST *) bif_array_arg (qst, args, 1, "need_to_know");
  if (ST_P (tree, SELECT_STMT))
    {
      ST *texp = tree->_.select_stmt.table_exp;
      if (!texp)
	return 0;		/* select w/o a from */
      for (inx = 0; inx < BOX_ELEMENTS (texp->_.table_exp.from); inx++)
	{
	  ST *tref = texp->_.table_exp.from[inx];
	  if (ST_P (tref, TABLE_REF))
	    tref = tref->_.table_ref.table;
	  if (ST_P (tref, TABLE_DOTTED))
	    {
	      char *corr_name;
	      if (tref->_.table.prefix)
		corr_name = tref->_.table.prefix;
	      else
		corr_name = tref->_.table.name;
	      if (strstr (tref->_.table.name, "REPORT"))
		nk_test_add (texp, corr_name, (int) uid);
	    }
	}
    }
  return 0;
}


static caddr_t
bif_n_range (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t n1 = bif_arg (qst, args, 0, "n_range_bif");
  caddr_t n2 = bif_arg (qst, args, 1, "n_range_bif");
  long inx, i1, i2;
  dtp_t dtp1 = DV_TYPE_OF (n1);
  dtp_t dtp2 = DV_TYPE_OF (n2);
  if (DV_DB_NULL == dtp1)
    i1 = 0;
  else if (dtp1 != DV_LONG_INT)
    sqlr_error ("42000", "Bad arg 1 for n_rage_bif");
  else
    i1 = unbox (n1);
  if (DV_DB_NULL == dtp2)
    i2 = 10;
  else if (dtp2 != DV_LONG_INT)
    sqlr_error ("42000", "Bad arg 2 for n_range_bif");
  else
    i2 = unbox (n2);

  for (inx = i1; inx < i2; inx++)
    {
      caddr_t num1 = box_num (inx);
      caddr_t num2 = box_num (inx * 2);
      bif_result_inside_bif (2, num1, num2);
      dk_free_box (num1);
      dk_free_box (num2);
    }
  return NULL;
}

#ifdef WIN32
/* the initialization critical section */
static CRITICAL_SECTION s_init_java;

/* the request queue element structure */
typedef struct queue_elt_s
{
  HANDLE qe_sem;
  struct queue_elt_s *qe_next;

  /* data part - app specific */
  int n1, n2, result;
}
queue_elt_t;

/* the request queue structure */
typedef struct queue_s
{
  CRITICAL_SECTION q_sect;
  queue_elt_t *q_head;
}
queue_t;

/* the worker thread(s) structure */
typedef struct thr_s
{
  HANDLE thr_semaphore;
  queue_t *thr_queue;
}
thr_t;

static unsigned WINAPI
java_worker (thr_t * thr)
{
  queue_t *queue = thr->thr_queue;
  queue_elt_t *elt;

  do
    {
      /* wait for continue notification */
      WaitForSingleObject (thr->thr_semaphore, INFINITE);

      /* get a element from the queue */
      EnterCriticalSection (&queue->q_sect);
      elt = queue->q_head;
      queue->q_head = elt->qe_next;
      LeaveCriticalSection (&queue->q_sect);

      /* actual processing */
      elt->result = elt->n1 + elt->n2;

      /* mark the processing done */
      ReleaseSemaphore (elt->qe_sem, 1, NULL);
    }
  while (1);
}

#define WORKER_THREAD_STACK_SIZE 100000
static caddr_t
bif_call_java (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  /* thread & queue */
  static thr_t *thr = NULL;
  static queue_t *queue = NULL;

  /* the request */
  queue_elt_t req;

  /* initialize on first enter */
  EnterCriticalSection (&s_init_java);
  if (!thr)
    {
      unsigned int thr_id;

      /* allocate & init the queue structure */
      queue = dk_alloc_box (sizeof (queue_t), DV_BIN);
      memset (queue, 0, sizeof (queue_t));
      InitializeCriticalSection (&queue->q_sect);
      queue->q_head = NULL;

      /* allocate & init the thread struct */
      thr = dk_alloc_box (sizeof (thr_t), DV_BIN);
      thr->thr_semaphore = CreateSemaphore (NULL, 0, 100, NULL);
      thr->thr_queue = queue;
      if (!thr->thr_semaphore)
	{
	  dk_free_box (thr);
	  DeleteCriticalSection (&queue->q_sect);
	  dk_free_box (queue);
	  thr = NULL;
	  queue = NULL;
	  sqlr_error (".....",
	      "Can\'t initialize the worker thread semaphore");
	}
      if (!_beginthreadex (NULL, WORKER_THREAD_STACK_SIZE, java_worker, thr,
	      0, &thr_id))
	{
	  CloseHandle (thr->thr_semaphore);
	  dk_free_box (thr);
	  DeleteCriticalSection (&queue->q_sect);
	  dk_free_box (queue);
	  thr = NULL;
	  queue = NULL;
	  sqlr_error (".....", "Can\'t start the worker thread");
	}
    }
  LeaveCriticalSection (&s_init_java);

  /* prepare the request */
  if (!(req.qe_sem = CreateSemaphore (NULL, 0, 100, NULL)))
    sqlr_error (".....", "Error creating a request");

  req.n1 = bif_long_arg (qst, args, 0, "call_java");
  req.n2 = bif_long_arg (qst, args, 1, "call_java");
  req.result = 0;

  /* add it to the queue */
  EnterCriticalSection (&queue->q_sect);
  req.qe_next = queue->q_head;
  queue->q_head = &req;
  LeaveCriticalSection (&queue->q_sect);

  /* wait for processing to complete */
  SignalObjectAndWait (thr->thr_semaphore, req.qe_sem, INFINITE, FALSE);

  /* free the request */
  CloseHandle (req.qe_sem);

  /* return the results */
  return box_num (req.result);
}
#endif

static void
init_func (void)
{
  bif_define_typed ("my_aref", bif_my_aref, &bt_any);
  bif_define_typed ("my_vector", bif_my_vector, &bt_any);
  bif_define_typed ("my_select", bif_my_select, &bt_any);
  bif_define ("need_to_know", bif_need_to_know);
  bif_define ("n_range_bif", bif_n_range);
#ifdef WIN32
  InitializeCriticalSection (&s_init_java);
  bif_define ("call_java", bif_call_java);
#endif
}


int
main (int argc, char *argv[])
{
#ifdef MALLOC_DEBUG
  dbg_malloc_enable();
#endif
  build_set_special_server_model ("Sample Interface");
  VirtuosoServerSetInitHook (init_func);
  return VirtuosoServerMain (argc, argv);
}

/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2017 OpenLink Software
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

#define NO_DBG_PRINTF

#include "shcompo.h"
#include "http.h"
#include "sqlbif.h"
#include "xmltree.h"
#include "security.h"

static void shcompo_release_int (shcompo_t *shc);
long shc_waits = 0;
long shc_recompiled = 0;

/* PART 1. Generic functionality */

shcompo_t *
shcompo_get_or_compile (shcompo_vtable_t *vt, caddr_t key, int key_is_const, struct query_instance_s *qi, void *env, caddr_t *err_ret)
{
  shcompo_t *res, **val_ptr;
  mutex_enter (vt->shcompo_cache_mutex);
  val_ptr = (shcompo_t **)id_hash_get (vt->shcompo_cache, (caddr_t)(&key));
  if (NULL != val_ptr)
    {
      res = val_ptr[0];
      res->shcompo_ref_count++;
      if (!key_is_const)
	dk_free_tree (key);
      mutex_leave (vt->shcompo_cache_mutex);
      if (NULL != res->shcompo_comp_mutex)
        {
	  IO_SECT (qi);
          SHC_ENTER (res);
	  END_IO_SECT (err_ret);
	  shc_waits ++;
          if (NULL != res->shcompo_error)
            {
              if (NULL != err_ret)
                err_ret[0] = box_copy_tree (res->shcompo_error);
              SHC_LEAVE (res);
              shcompo_release (res);
              return NULL;
            }
          SHC_LEAVE (res);
        }
      return res;
    }
  res = vt->shcompo_alloc (env);
  if (key_is_const)
    key = box_copy_tree (key);
  res->_ = vt;
  res->shcompo_key = key;
  res->shcompo_error = NULL;
  res->shcompo_ref_count = 2; /* +1 for adding into cache, +1 for returned pointer */
  res->shcompo_is_stale = 0;
#ifdef DEBUG
  res->shcompo_watchdog = 0;
#endif
  if (NULL != vt->shcompo_spare_mutexes)
    res->shcompo_comp_mutex = (dk_mutex_t *)(dk_set_pop (&(vt->shcompo_spare_mutexes)));
  else
    res->shcompo_comp_mutex = mutex_allocate ();
  if (vt->shcompo_cache->ht_count > vt->shcompo_cache_size_limit)
    {
static int32 shc_rnd_seed;
      int32 rnd = sqlbif_rnd (&shc_rnd_seed);
      while (vt->shcompo_cache->ht_count > vt->shcompo_cache_size_limit)
	{
	  caddr_t old_key;
          shcompo_t *old_data;
	  if (id_hash_remove_rnd (vt->shcompo_cache, rnd, (caddr_t)&old_key, (caddr_t)&old_data))
            {
              old_data->shcompo_ref_count -= 1;
              if (0 == old_data->shcompo_ref_count)
	        shcompo_release_int (old_data);
	      else /* we must increase again as it may happen to be released prematurely by other thread waiting on same condition */
		old_data->shcompo_ref_count += 1;
            }
          rnd++;
	}
    }
  id_hash_add_new (vt->shcompo_cache, (caddr_t)(&key), (caddr_t)(&res));
  SHC_ENTER (res); /* Safe to enter there inside vt->shcompo_cache_mutex because nobody else knows about the res at all */
  mutex_leave (vt->shcompo_cache_mutex);
  vt->shcompo_compile (res, qi, env);
  if (NULL != res->shcompo_error)
    {
      if (NULL != err_ret)
        err_ret[0] = box_copy_tree (res->shcompo_error);
      mutex_enter (vt->shcompo_cache_mutex);
      if (id_hash_remove (vt->shcompo_cache, (caddr_t)(&key)))
        res->shcompo_ref_count -= 1;
      mutex_leave (vt->shcompo_cache_mutex);
      SHC_LEAVE (res);
      shcompo_release (res);
      return NULL;
    }
  SHC_LEAVE (res);
  return res;
}

shcompo_t *
shcompo_get (shcompo_vtable_t *vt, caddr_t key)
{
  shcompo_t *res, **val_ptr;
  mutex_enter (vt->shcompo_cache_mutex);
  val_ptr = (shcompo_t **)id_hash_get (vt->shcompo_cache, (caddr_t)(&key));
  if (NULL != val_ptr)
    {
      res = val_ptr[0];
      res->shcompo_ref_count++;
      mutex_leave (vt->shcompo_cache_mutex);
      if (NULL != res->shcompo_comp_mutex)
        {
          SHC_ENTER (res);
          if (NULL != res->shcompo_error)
            {
              SHC_LEAVE (res);
              shcompo_release (res);
              return NULL;
            }
          SHC_LEAVE (res);
        }
      return res;
    }
  mutex_leave (vt->shcompo_cache_mutex);
  return NULL;
}

void
shcompo_lock (shcompo_t *shc)
{
  mutex_enter (shc->_->shcompo_cache_mutex);
  shc->shcompo_ref_count++;
  mutex_leave (shc->_->shcompo_cache_mutex);
}

void
shcompo_release_int (shcompo_t *shc)
{
  shcompo_vtable_t *vt = shc->_;
  if (NULL != shc->shcompo_comp_mutex)
    {
      SHC_COMP_MTX_CHECK (shc);
      dk_set_push (&(vt->shcompo_spare_mutexes), shc->shcompo_comp_mutex);
      shc->shcompo_comp_mutex = NULL;
    }
  dk_free_tree (shc->shcompo_error);
  shc->shcompo_error = NULL;
  dk_free_tree (shc->shcompo_key);
  shc->shcompo_key = NULL;
  vt->shcompo_destroy_data (shc);
}

void
shcompo_release (shcompo_t *shc)
{
  shcompo_vtable_t *vt;
  if (NULL == shc)
    return;
  vt = shc->_;
  mutex_enter (vt->shcompo_cache_mutex);
  shc->shcompo_ref_count--;
  if (0 == shc->shcompo_ref_count)
    shcompo_release_int (shc);
  mutex_leave (vt->shcompo_cache_mutex);
}

void
shcompo_stale (shcompo_t *shc)
{
  shcompo_vtable_t *vt;
  if (NULL == shc)
    return;
  vt = shc->_;
  if (shc->shcompo_is_stale)
    return;
  mutex_enter (vt->shcompo_cache_mutex);
  if (shc->shcompo_is_stale)
    {
      mutex_leave (vt->shcompo_cache_mutex);
      return;
    }
  if (id_hash_remove (vt->shcompo_cache, (caddr_t)(&(shc->shcompo_key))))
    shc->shcompo_ref_count--;
  shc->shcompo_is_stale = 1;
  mutex_leave (vt->shcompo_cache_mutex);
}

void
shcompo_stale_if_needed (shcompo_t *shc)
{
  shcompo_vtable_t *vt;
  if (NULL == shc)
    return;
  vt = shc->_;
  if (NULL == vt->shcompo_check_if_stale)
    return;
  /* Removed by Mitko in v6:
  if (shc->shcompo_is_stale || (NULL == shc->shcompo_data))
    return; */
  mutex_enter (vt->shcompo_cache_mutex);
  if (shc->shcompo_is_stale || (NULL == shc->shcompo_data))
    {
      mutex_leave (vt->shcompo_cache_mutex);
      return;
    }
  if (vt->shcompo_check_if_stale (shc))
    {
      if (id_hash_remove (vt->shcompo_cache, (caddr_t)(&(shc->shcompo_key))))
        shc->shcompo_ref_count--;
      shc->shcompo_is_stale = 1;
    }
  mutex_leave (vt->shcompo_cache_mutex);
}

void
shcompo_recompile (shcompo_t **shc_ptr)
{
  shcompo_t *old_shc, *new_shc;
  shcompo_vtable_t *vt;
  old_shc = shc_ptr[0];
  if (NULL == old_shc)
    return;
  vt = old_shc->_;
  if (NULL == vt->shcompo_recompile)
    {
      shcompo_stale (old_shc);
      return;
    }
  new_shc = vt->shcompo_alloc_copy (old_shc);
  new_shc->_ = vt;
  new_shc->shcompo_key = old_shc->shcompo_key;
  new_shc->shcompo_error = NULL;
  new_shc->shcompo_ref_count = 1;
  new_shc->shcompo_is_stale = 0;
#ifdef DEBUG
  new_shc->shcompo_watchdog = 0;
#endif
  mutex_enter (vt->shcompo_cache_mutex);
  if (NULL != vt->shcompo_spare_mutexes)
    new_shc->shcompo_comp_mutex = (dk_mutex_t *)(dk_set_pop (&(vt->shcompo_spare_mutexes)));
  else
    new_shc->shcompo_comp_mutex = mutex_allocate ();
  SHC_ENTER (new_shc);
  shc_recompiled ++;
  mutex_leave (vt->shcompo_cache_mutex);
  vt->shcompo_recompile (old_shc, new_shc);
  if (NULL != new_shc->shcompo_error)
    {
      mutex_enter (vt->shcompo_cache_mutex);
      if (id_hash_remove (vt->shcompo_cache, (caddr_t)(&(old_shc->shcompo_key))))
        old_shc->shcompo_ref_count -= 1;
      old_shc->shcompo_is_stale = 1;
      if (1 == old_shc->shcompo_ref_count)
        {
	  SHC_COMP_MTX_CHECK (old_shc);
          dk_set_push (&(old_shc->_->shcompo_spare_mutexes), old_shc->shcompo_comp_mutex);
          old_shc->shcompo_comp_mutex = NULL;
        }
      new_shc->shcompo_key = NULL;
      mutex_leave (vt->shcompo_cache_mutex);
      SHC_LEAVE (new_shc);
      shcompo_release (new_shc);
      return;
    }
  mutex_enter (vt->shcompo_cache_mutex);
  id_hash_set (vt->shcompo_cache, (caddr_t)(&(old_shc->shcompo_key)), (caddr_t)(&new_shc));
  new_shc->shcompo_ref_count += 1;
  old_shc->shcompo_key = NULL;
  mutex_leave (vt->shcompo_cache_mutex);
  SHC_LEAVE (new_shc);
  shcompo_stale (old_shc);
  shc_ptr[0] = new_shc;
}

void
shcompo_recompile_if_needed (shcompo_t **shc_ptr)
{
  shcompo_t *shc = shc_ptr[0];
  shcompo_vtable_t *vt;
  if (NULL == shc)
    return;
  vt = shc->_;
  if (NULL == vt->shcompo_check_if_stale)
    return;
  if ((NULL == shc->shcompo_data) || (NULL != shc->shcompo_error))
    return;
  mutex_enter (vt->shcompo_cache_mutex);
  if ((NULL == shc->shcompo_data) || (NULL != shc->shcompo_error))
    {
      mutex_leave (vt->shcompo_cache_mutex);
      return;
    }
  if (shc->shcompo_is_stale || vt->shcompo_check_if_stale (shc))
    {
      mutex_leave (vt->shcompo_cache_mutex);
      shcompo_recompile (shc_ptr);
      return;
    }
  mutex_leave (vt->shcompo_cache_mutex);
}

shcompo_t *
shcompo_alloc__default (void *env)
{
  shcompo_t *res = (shcompo_t *)dk_alloc (sizeof (shcompo_t));
  res->shcompo_data = NULL;
#ifndef NDEBUG
  res->shcompo_owner = NULL;
#endif
  return res;
}

/* Part 2.1. shcompo_vtable__qr and its members */

shcompo_vtable_t shcompo_vtable__qr;

void
shcompo_compile__qr(shcompo_t *shc, query_instance_t *qi, void *env)
{
  caddr_t txt = ((caddr_t *)(shc->shcompo_key))[0];
  long saved_mrows = qi->qi_client->cli_resultset_max_rows;
  qi->qi_client->cli_resultset_max_rows = -1;
  QR_RESET_CTX_T (qi->qi_thread)
    {
      shc->shcompo_data = sql_compile (txt, qi->qi_client, &(shc->shcompo_error), 0);
    }
  QR_RESET_CODE
    {
      POP_QR_RESET;
      /* if it compiles possibly will have an non-empty mem pool */
      if (THR_TMP_POOL)
	MP_DONE ();
      switch (reset_code)
	{
	  case RST_ERROR:
	      shc->shcompo_error = thr_get_error_code (THREAD_CURRENT_THREAD);
	      break;
	  default:
	      shc->shcompo_error = srv_make_new_error ("S1T00", "SR490", "Transaction timed out");
	}
    }
  END_QR_RESET;
  qi->qi_client->cli_resultset_max_rows = saved_mrows;
}

int
shcompo_check_if_stale__qr (shcompo_t *shc)
{
  query_t *qr = (query_t *)(shc->shcompo_data);
  return qr->qr_to_recompile;
}

void
shcompo_recompile__qr (shcompo_t *old_shc, shcompo_t *new_shc)
{
  query_t *qr = (query_t *)(old_shc->shcompo_data);
  query_t *new_qr;
/*  long saved_mrows = bootstrap_cli->cli_resultset_max_rows;*/
  bootstrap_cli->cli_resultset_max_rows = -1;
  new_qr = qr_recompile (qr, &(new_shc->shcompo_error));
/*  bootstrap_cli->cli_resultset_max_rows = saved_mrows; */
  new_shc->shcompo_data = new_qr;
}

void
shcompo_destroy_data__qr (shcompo_t *shc)
{
  if (NULL != shc->shcompo_data)
    {
      query_t *qr = (query_t *)(shc->shcompo_data);
      qr_free (qr);
    }
  dk_free (shc, sizeof (shcompo_t));
}

/* Part 2.2. shcompo_vtable__test and its members */

shcompo_vtable_t shcompo_vtable__test;

void
shcompo_compile__test (shcompo_t *shc, query_instance_t *qi, void *env)
{
  caddr_t txt = ((caddr_t *)(shc->shcompo_key))[0];
  caddr_t my;
  if ((NULL != shc->shcompo_data) || (NULL != shc->shcompo_error))
    GPF_T1 ("shcompo_compile__test: bad state before");
  shc->shcompo_data = my = box_sprintf (80, "%.50s is BEING compiled", txt);
  virtuoso_sleep (2, 0);
  if ((my != shc->shcompo_data) || (NULL != shc->shcompo_error))
    GPF_T1 ("shcompo_compile__test: collision");
  dk_free_tree (shc->shcompo_data);
  shc->shcompo_data = NULL;
  if (0 == (txt[0] % 2))
    shc->shcompo_data = box_sprintf (80, "%.50s is compiled", txt);
  else
    shc->shcompo_error = srv_make_new_error ("TEST0", "SHCO1", "Error compiling %.100s", txt);
}

int
shcompo_check_if_stale__test (shcompo_t *shc)
{
  return ((0 == (((char *)(shc->shcompo_data))[0] % 5)) ? 1 : 0);
}

void
shcompo_recompile__test (shcompo_t *old_shc, shcompo_t *new_shc)
{
  caddr_t txt = ((caddr_t *)(old_shc->shcompo_key))[0];
  caddr_t my;
  if ((NULL == old_shc->shcompo_data) || (NULL != old_shc->shcompo_error))
    GPF_T1 ("shcompo_recompile__test: bad old_shc state before");
  if ((NULL != new_shc->shcompo_data) || (NULL != new_shc->shcompo_error))
    GPF_T1 ("shcompo_recompile__test: bad new_shc state before");
  new_shc->shcompo_data = my = box_sprintf (80, "%.50s -- BEING recompiled", txt);
  virtuoso_sleep (2, 0);
  if ((my != new_shc->shcompo_data) || (NULL != new_shc->shcompo_error))
    GPF_T1 ("shcompo_recompile__test: collision");
  new_shc->shcompo_data = NULL;
  if (0 == (txt[0] % 3))
    new_shc->shcompo_data = box_sprintf (80, "%.50s is recompiled", txt);
  else
    new_shc->shcompo_error = srv_make_new_error ("TEST0", "SHCO1", "Error recompiling %.100s", txt);
}

void
shcompo_destroy_data__test (shcompo_t *shc)
{
  if (NULL != shc->shcompo_data)
    dk_free_tree (shc->shcompo_data);
  dk_free (shc, sizeof (shcompo_t));
}

caddr_t
bif_exec_shcompo_test (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *)qst;
  caddr_t txt = bif_string_arg (qst, args, 0, "bif_exec_shcompo_test");
  caddr_t err = NULL;
  shcompo_t *shc = shcompo_get_or_compile (&shcompo_vtable__test, list (4, box_copy_tree (txt), (ptrlong)11, (ptrlong)22, (ptrlong)0), 0, qi, NULL, &err);
  if (NULL != err)
    sqlr_resignal (err);
  shcompo_recompile_if_needed (&shc);
  if (NULL != shc->shcompo_error)
    sqlr_resignal (box_copy_tree (shc->shcompo_error));
  return box_copy_tree (shc->shcompo_data);
}

caddr_t
bif_shcompo_clear (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  shcompo_t **val_ptr;
  caddr_t **key;
  shcompo_vtable_t *vt = &shcompo_vtable__qr;
  id_hash_iterator_t it;

  sec_check_dba ((query_instance_t *) qst, "shcompo_clear");
  mutex_enter (vt->shcompo_cache_mutex);
  id_hash_iterator (&it, shcompo_vtable__qr.shcompo_cache);
  while (hit_next (&it, (char **)&key, (char **)&val_ptr))
    {
      val_ptr[0]->shcompo_ref_count--;
      if (0 == val_ptr[0]->shcompo_ref_count)
	shcompo_release_int (val_ptr[0]);
    }
  id_hash_clear (shcompo_vtable__qr.shcompo_cache);
  mutex_leave (vt->shcompo_cache_mutex);
  return NULL;
}
;

/* Part 3. Init/final */

int c_shcompo_size = 100;
void shcompo_init (void)
{
    shcompo_vtable__qr.shcompo_type_title = "precompiled SQL query";
    shcompo_vtable__qr.shcompo_cache = id_hash_allocate (4096, sizeof (caddr_t), sizeof (caddr_t), treehash, treehashcmp);
    shcompo_vtable__qr.shcompo_cache_mutex = mutex_allocate ();
    shcompo_vtable__qr.shcompo_spare_mutexes = NULL;
    shcompo_vtable__qr.shcompo_alloc = shcompo_alloc__default;
    shcompo_vtable__qr.shcompo_alloc_copy = (shcompo_alloc_copy_t) shcompo_alloc__default;
    shcompo_vtable__qr.shcompo_compile = shcompo_compile__qr;
    shcompo_vtable__qr.shcompo_check_if_stale = shcompo_check_if_stale__qr;
    shcompo_vtable__qr.shcompo_recompile = shcompo_recompile__qr;
    shcompo_vtable__qr.shcompo_destroy_data = shcompo_destroy_data__qr;
    shcompo_vtable__qr.shcompo_cache_size_limit = c_shcompo_size;
    shcompo_vtable__test.shcompo_type_title = "test emulator of compilation";
    shcompo_vtable__test.shcompo_cache = id_hash_allocate (4096, sizeof (caddr_t), sizeof (caddr_t), treehash, treehashcmp);
    shcompo_vtable__test.shcompo_cache_mutex = mutex_allocate ();
    shcompo_vtable__test.shcompo_spare_mutexes = NULL;
    shcompo_vtable__test.shcompo_alloc = shcompo_alloc__default;
    shcompo_vtable__test.shcompo_alloc_copy = (shcompo_alloc_copy_t) shcompo_alloc__default;
    shcompo_vtable__test.shcompo_compile = shcompo_compile__test;
    shcompo_vtable__test.shcompo_check_if_stale = shcompo_check_if_stale__test;
    shcompo_vtable__test.shcompo_recompile = shcompo_recompile__test;
    shcompo_vtable__test.shcompo_destroy_data = shcompo_destroy_data__test;
    shcompo_vtable__test.shcompo_cache_size_limit = 10;
    bif_define ("exec_shcompo_test", bif_exec_shcompo_test);
    bif_define ("shcompo_clear", bif_shcompo_clear);
}

void
shcompo_terminate_module (void)
{
}


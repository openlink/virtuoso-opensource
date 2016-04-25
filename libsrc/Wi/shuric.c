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

#define NO_DBG_PRINTF

#include "shuric.h"
#include "http.h"
#include "sqlbif.h"
#include "xmltree.h"

id_hash_t * shuric_global_hashtable;
dk_mutex_t * shuric_mtx;

#ifdef DEBUG
volatile dk_set_t shuric_named_noncached = NULL;
#endif
static void shuric_stale_prepare (shuric_t *shu, dk_set_t *obsoletes);

shuric_t *shuric_load (shuric_vtable_t *vt, caddr_t uri, caddr_t ts, caddr_t uri_text_content, shuric_t *loaded_by, struct query_instance_s *qi, void *env, caddr_t *err_ret )
{
  caddr_t str = NULL;
  shuric_t ** cached_shuric_ptr;
  shuric_t *new_cached_shuric = NULL, *old_cached_shuric = NULL;
  shuric_t * new_shuric = NULL;
  shuric_t * res = NULL; /* = NULL to keep compiler happy */
  dk_set_t obsoletes = NULL;
  dbg_printf (("shuric_load started (\"%s\", \"%s\", \"%s\" @ %p)\n",
    vt->shuric_type_title, uri,
    loaded_by ? loaded_by->shuric_uri : "", loaded_by ));
  if (NULL != err_ret[0])
    return NULL;
  if (NULL != uri)
    {
      if (DV_STRING != DV_TYPE_OF (uri))
	{
          err_ret[0] = srv_make_new_error ("39000", "FA041", "A URI of a shareable XSLT/XQuery resource has invalid data type.");
          goto cleanup;
	}
      if (box_length (uri) > MAX_SHURIC_URI_LENGTH)
	{
          err_ret[0] = srv_make_new_error ("39000", "FA042", "An abnormally long string is passed as URI of a shareable XSLT/XQuery resource.");
          goto cleanup;
	}
    }
  if (NULL != uri)
    {
      if (NULL != loaded_by)
        {
          shuric_t *old_inc = shuric_scan_relations (loaded_by, uri, SHURIC_SCAN_INCLUDED_BY | SHURIC_SCAN_IMPORTED_BY);
	  if (old_inc != NULL)
	    {
	      char impuri[300];
	      if (NULL != loaded_by->shuric_uri)
	        strcpy (impuri, "(temporary resource with no URI)");
	      else
	        {
	          strcpy_ck (impuri, loaded_by->shuric_uri);
	        }
	      shuric_release (old_inc);
	      err_ret[0] = srv_make_new_error ("39000", "FA048", "Cyclic references: '%.300s' refers to his ancestor '%.300s' as to child resource", impuri, uri);
	    }
	}
      mutex_enter (shuric_mtx);
      cached_shuric_ptr = (shuric_t **) id_hash_get (shuric_global_hashtable, (caddr_t) &uri);
      old_cached_shuric = ((NULL == cached_shuric_ptr) ? NULL : cached_shuric_ptr[0]);
      if (NULL != old_cached_shuric)
	old_cached_shuric->shuric_ref_count++; /* Temporary lock to keep the pointer valid. */
      mutex_leave (shuric_mtx);
      if ((NULL != old_cached_shuric) && (old_cached_shuric->_ != vt))
	{
          err_ret[0] = srv_make_new_error ("39000", "FA046", "Server uses the content of URI '%.200s' as '%.30s' and can not load it as '%.30s'",
	    uri, old_cached_shuric->_->shuric_type_title, vt->shuric_type_title );
          goto cleanup;
	}
    }
  if (NULL == uri_text_content)
    {
      QR_RESET_CTX
      {
        str = vt->shuric_uri_to_text (uri, qi, env, err_ret);
      }
      QR_RESET_CODE
      {
        du_thread_t *self = THREAD_CURRENT_THREAD;
        err_ret[0] = thr_get_error_code (self);
        thr_set_error_code (self, NULL);
      }
      END_QR_RESET;
    }
  else
    str = uri_text_content;
  if (NULL != err_ret[0])
    goto cleanup;
  new_shuric = vt->shuric_alloc (env);
#ifdef DEBUG
  if (NULL != uri)
    dk_set_push (&shuric_named_noncached, new_shuric);
#endif
  new_shuric->_ = vt;
  new_shuric->shuric_uri = box_copy (uri);
  new_shuric->shuric_imports = NULL;
  new_shuric->shuric_includes = NULL;
  new_shuric->shuric_imported_by = NULL;
  new_shuric->shuric_included_by = NULL;
  new_shuric->shuric_ref_count = 1;
  new_shuric->shuric_loading_time = NULL;
  new_shuric->shuric_is_stale = 0;
  if (NULL != loaded_by)
    shuric_make_include (loaded_by, new_shuric);
  dbg_printf (("shuric_load before parse (\"%s\", \"%s\", \"%s\" @ %p)\n",
    vt->shuric_type_title, uri,
    loaded_by ? loaded_by->shuric_uri : "", loaded_by  ));
  dbg_printf (("  new_shuric = %p\n", new_shuric));
  QR_RESET_CTX
  {
    vt->shuric_parse_text (new_shuric, str, qi, env, err_ret);
  }
  QR_RESET_CODE
  {
    du_thread_t *self = THREAD_CURRENT_THREAD;
    err_ret[0] = thr_get_error_code (self);
    thr_set_error_code (self, NULL);
  }
  END_QR_RESET;
  dbg_printf (("shuric_load after parse (\"%s\", \"%s\", \"%s\" @ %p)\n",
    vt->shuric_type_title, uri,
    loaded_by ? loaded_by->shuric_uri : "", loaded_by ));
  dbg_printf (("  new_shuric = %p state=\"%s\" err=\"%s\"\n", res,
    err_ret[0] ? ERR_STATE(err_ret[0]) : "00000",
    err_ret[0] ? ERR_MESSAGE(err_ret[0]) : "OK" )
    );
  if (NULL != err_ret[0])
    {
      goto cleanup;
    }
  new_shuric->shuric_loading_time = box_copy (ts);
  if (NULL != uri)
    {
      mutex_enter (shuric_mtx);
      cached_shuric_ptr = (shuric_t **) id_hash_get (shuric_global_hashtable, (caddr_t) &uri);
      new_cached_shuric = ((NULL == cached_shuric_ptr) ? NULL : cached_shuric_ptr[0]);
      if (NULL != new_cached_shuric)
	new_cached_shuric->shuric_ref_count++; /* Temporary lock to keep the pointer valid. */
      if ((NULL != new_cached_shuric) && (new_cached_shuric->_ != vt))
	{
          err_ret[0] = srv_make_new_error ("39000", "FA046", "Server uses the content of URI '%.200s' as '%.30s' and can not load it as '%.30s'",
	    uri, new_cached_shuric->_->shuric_type_title, vt->shuric_type_title );
	  mutex_leave (shuric_mtx);
          goto cleanup;
	}
/* If new_cached_shuric != cached_shuric, then style sheet is just compiled and cached by third party */
      if (new_cached_shuric == old_cached_shuric)
	{
	  if (NULL != new_cached_shuric)
	    shuric_stale_prepare (new_cached_shuric, &obsoletes);
#ifdef DEBUG
	  if (NULL != id_hash_get (shuric_global_hashtable, (caddr_t)(&(new_shuric->shuric_uri))))
	    GPF_T;
#endif
	  new_shuric->shuric_ref_count++;
	  id_hash_set (shuric_global_hashtable, (caddr_t)(&(new_shuric->shuric_uri)), (caddr_t)&new_shuric);
#ifdef DEBUG
	  dk_set_delete (&shuric_named_noncached, new_shuric);
#endif
	  res = new_shuric;
	  new_shuric = NULL;		 /* to prevent lock release */
	}
      else
	{
	  res = new_cached_shuric;
	  new_cached_shuric = NULL;	/* to prevent lock release */
	}
      mutex_leave (shuric_mtx);
    }
  else
    {
      res = new_shuric;
      new_shuric = NULL;		 /* to prevent lock release */
    }
cleanup:
  if (NULL != loaded_by)
    {
      if ((res != new_shuric) && (NULL != new_shuric))
        {
	  shuric_rollback_include (loaded_by, new_shuric);
	  if (NULL != res)
	    shuric_make_include (loaded_by, res);
	}
    }
  shuric_release (old_cached_shuric); /* It was locked here to protect from destroying by a third party */
  shuric_release (new_cached_shuric); /* It's no longer in the table and is not a result */
  shuric_release (new_shuric); /* It's not a NULL iff it's neither added into the table nor become a result */
  while (NULL != obsoletes)
    {
      shuric_t *oldtimer = (shuric_t *)dk_set_pop (&obsoletes);
      oldtimer->_->shuric_on_stale (oldtimer);
      shuric_release (oldtimer);
    }
  if (str != uri_text_content)
    dk_free_box (str);
  dbg_printf (("shuric_load completed (\"%s\", \"%s\", \"%s\" @ %p)\n",
    vt->shuric_type_title, uri,
    loaded_by ? loaded_by->shuric_uri : "", loaded_by ));
  dbg_printf (("  res = %p err_state=\"%s\" err_message=\"%s\"\n", res,
    err_ret[0] ? ERR_STATE(err_ret[0]) : "00000",
    err_ret[0] ? ERR_MESSAGE(err_ret[0]) : "OK"
    ));
  return res;
}


shuric_t *shuric_get (caddr_t uri)
{
  shuric_t ** cached_shuric_ptr;
  shuric_t * cached_shuric;
  if (NULL == uri)
    return NULL;
  mutex_enter (shuric_mtx);
  cached_shuric_ptr = (shuric_t **) id_hash_get (shuric_global_hashtable, (caddr_t) &uri);
#ifdef DEBUG
  if ((NULL != cached_shuric_ptr) && (NULL == cached_shuric_ptr[0]))
    GPF_T1 ("Failure cached in shuric_global_hashtable");
#endif
  cached_shuric = ((NULL == cached_shuric_ptr) ? NULL : cached_shuric_ptr[0]);
  if (cached_shuric && !cached_shuric->shuric_is_stale)
    cached_shuric->shuric_ref_count++;
  else
    cached_shuric = NULL;
  mutex_leave (shuric_mtx);
  dbg_printf (("shuric_get (\"%s\")", uri));
  if (cached_shuric)
    {
      dbg_printf ((" returns %p \"%s\" refs=%d\n",
        cached_shuric, cached_shuric->_->shuric_type_title,
        cached_shuric->shuric_ref_count ));
    }
  else
    {
      dbg_printf ((" returns NULL\n"));
    }
  return (cached_shuric);
}


shuric_t *shuric_get_typed (caddr_t uri, shuric_vtable_t *vt, caddr_t *err_ret)
{
  shuric_t *hit = shuric_get (uri);
  if (NULL == hit)
    return NULL;
  if (hit->_ == vt)
    return hit;
  if (NULL != err_ret)
    {
      err_ret[0] = srv_make_new_error ("39000", "FA047", "Server uses the content of URI '%.200s' as '%.30s', not as '%.30s'",
	uri, hit->_->shuric_type_title, vt->shuric_type_title );
    }
  shuric_release (hit);
  return NULL;
}


void shuric_lock (shuric_t *shu)
{
  if (NULL == shu)
    return;
  if (shu->shuric_ref_count <= 0)
    GPF_T1 ("Nonpositive ref count of shuric before lock");
  mutex_enter (shuric_mtx);
  shu->shuric_ref_count++;
  dbg_printf (("shuric_lock completed (\"%s\", \"%s\" @ %p, refs=%d)\n",
    shu->_->shuric_type_title, shu->shuric_uri, shu, shu->shuric_ref_count));
  mutex_leave (shuric_mtx);
}


static void shuric_sentence_tree_to_shot (shuric_t *shu, dk_set_t *shot_list)
{
  if (dk_set_member (shot_list[0], shu))
    GPF_T1 ("A shuric is sentenced to shot twice");
  if (shu->shuric_ref_count != 0)
    GPF_T1 ("Nonzero ref count of shuric before destroy");
  dk_set_push (shot_list, shu);
  if (NULL != shu->shuric_included_by)
    GPF_T1 ("Shuric is included but refcount is zero");
  if (NULL != shu->shuric_imported_by)
    GPF_T1 ("Shuric is imported but refcount is zero");
  if (NULL != shu->shuric_uri)
    {
      shuric_t **cached_shu_ptr = (shuric_t **)id_hash_get (
        shuric_global_hashtable, (caddr_t)(&(shu->shuric_uri)) );
      if ((NULL != cached_shu_ptr) && (shu == cached_shu_ptr[0]))
        GPF_T1 ("A cached shuric is sentenced to shot");
    }
  DO_SET(shuric_t *, subshu, &(shu->shuric_includes))
    {
      dk_set_delete (&(subshu->shuric_included_by), shu);
      subshu->shuric_ref_count--;
      dbg_printf (("shuric_sentence... \"%s\" \"%s\" @ %p, refs=%d\n  no longer included in \"%s\" \"%s\" @ %p\n",
        subshu->_->shuric_type_title, subshu->shuric_uri, subshu, subshu->shuric_ref_count,
	shu->_->shuric_type_title, shu->shuric_uri, shu ));
      if (0 >= subshu->shuric_ref_count)
	shuric_sentence_tree_to_shot (subshu, shot_list);
    }
  END_DO_SET()
  DO_SET(shuric_t *, subshu, &(shu->shuric_imports))
    {
      dk_set_delete (&(subshu->shuric_imported_by), shu);
      subshu->shuric_ref_count--;
      dbg_printf (("shuric_sentence... \"%s\" \"%s\" @ %p, refs=%d\n  no longer imported by \"%s\" \"%s\" @ %p\n",
        subshu->_->shuric_type_title, subshu->shuric_uri, subshu, subshu->shuric_ref_count,
	shu->_->shuric_type_title, shu->shuric_uri, shu ));
      if (0 >= subshu->shuric_ref_count)
	shuric_sentence_tree_to_shot (subshu, shot_list);
    }
  END_DO_SET()
}


void shuric_release (shuric_t *shu)
{
  if (NULL == shu)
    return;
  mutex_enter (shuric_mtx);
  if (shu->shuric_ref_count <= 0)
    GPF_T1 ("Nonpositive ref count of shuric before release");
  dbg_printf (("shuric_release started (\"%s\", \"%s\" @ %p, refs=%d)\n",
    shu->_->shuric_type_title, shu->shuric_uri, shu, shu->shuric_ref_count));
  shu->shuric_ref_count--;
  if (0 >= shu->shuric_ref_count)
    {
      dk_set_t shot_list = NULL;
      shuric_sentence_tree_to_shot (shu, &shot_list);
      mutex_leave (shuric_mtx);
      while (NULL != shot_list)
        {
          shuric_t *condemned = (shuric_t *) dk_set_pop (&shot_list);
	  caddr_t condemned_uri = condemned->shuric_uri;
	  dbg_printf (("shuric_destroy_data started (\"%s\")\n", condemned_uri));
#ifdef DEBUG
	  if (NULL != condemned_uri)
	    dk_set_delete (&shuric_named_noncached, condemned);
#endif
	  dk_set_free (condemned->shuric_includes);
	  condemned->shuric_includes = NULL;
	  dk_set_free (condemned->shuric_imports);
	  condemned->shuric_imports = NULL;
          condemned->_->shuric_destroy_data (condemned);
	  dbg_printf (("shuric_destroy_data completed (\"%s\")\n", condemned_uri));
	  dk_free_box (condemned_uri);
        }
    }
  else
    mutex_leave (shuric_mtx);
}


static void shuric_stale_prepare (shuric_t *shu, dk_set_t *obsoletes)
{
  shuric_t ** cached_shuric_ptr;
  shuric_t * cached_shuric = NULL;
  if (NULL == shu)
    return;
  if (shu->shuric_is_stale)
    return;
  shu->shuric_is_stale = 1;
  shu->shuric_ref_count++;
  dk_set_push (obsoletes, shu);
  DO_SET(shuric_t *, supershu, &(shu->shuric_included_by))
    {
      shuric_stale_prepare (supershu, obsoletes);
    }
  END_DO_SET()
  if (NULL == shu->shuric_uri)
    return;
  cached_shuric_ptr = (shuric_t **) id_hash_get (shuric_global_hashtable, (caddr_t)(&(shu->shuric_uri)));
  if (NULL != cached_shuric_ptr)
    cached_shuric = cached_shuric_ptr[0];
  if (shu != cached_shuric)
    return;
  id_hash_remove (shuric_global_hashtable, (caddr_t)((&(cached_shuric->shuric_uri))));
  cached_shuric->shuric_ref_count--;
  if (0 >= cached_shuric->shuric_ref_count)
    GPF_T;
#ifdef DEBUG
  dk_set_push (&shuric_named_noncached, cached_shuric);
#endif
}


int shuric_stale_tree (shuric_t *shu)
{
  dk_set_t obsoletes = NULL;
  mutex_enter (shuric_mtx);
  shuric_stale_prepare (shu, &obsoletes);
  mutex_leave (shuric_mtx);
  if (NULL == obsoletes)
    return 0;
  while (NULL != obsoletes)
    {
      shuric_t *oldtimer = (shuric_t *)dk_set_pop (&obsoletes);
      oldtimer->_->shuric_on_stale (oldtimer);
      shuric_release (oldtimer);
    }
  return 1;
}


caddr_t shuric_uri_ts (caddr_t uri)
{
  if (!strnicmp ("file:", uri, 5) && www_root)
    {
      caddr_t ts;
      caddr_t complete_name = dk_alloc_box (strlen (uri + 5) + strlen (www_root) + 2, DV_SHORT_STRING);
      char *p1 = uri + 5;

      while (*p1 == '/')
	p1++;
      strcpy_box_ck (complete_name, www_root);
#ifdef WIN32
      strcat_box_ck (complete_name, "\\");
#else
      strcat_box_ck (complete_name, "/");
#endif
      strcat_box_ck (complete_name, p1);
      ts = file_stat (complete_name, 0);
      dk_free_box (complete_name);
      return ts;
    }
  return NULL;
}


int shuric_is_obsolete_1 (shuric_t *shu, caddr_t *new_ts_ret)
{
  caddr_t uri = shu->shuric_uri;
  caddr_t ts;
  int res;
  if (shu->shuric_is_stale)
    {
      if (NULL != new_ts_ret)
	new_ts_ret[0] = shuric_uri_ts (uri);
      return 1;
    }
  ts = shuric_uri_ts (uri);
  if (NULL != new_ts_ret)
    new_ts_ret[0] = ts;
  if (!ts)
    return 0;
  res = ((NULL == shu->shuric_loading_time) || (strcmp (shu->shuric_loading_time, ts)));
  if (NULL == new_ts_ret)
    dk_free_box (ts);
  return res;
}


static int shuric_subtrees_are_obsolete (shuric_t *shu, dk_set_t *story)
{
  dk_set_push (story, shu);
  DO_SET(shuric_t *, subshu, &(shu->shuric_includes))
    {
      if (dk_set_member (story[0], subshu))
	continue;
      if (shuric_is_obsolete_1(shu, NULL))
	return 1;
      if (shuric_subtrees_are_obsolete (subshu, story))
	return 1;
    }
  END_DO_SET()
  return 0;
}

int shuric_includes_are_obsolete (shuric_t *shu)
{
  dk_set_t story = NULL;
  int res = shuric_subtrees_are_obsolete (shu, &story);
  dk_set_free (story);
  return res;
}

#if 0
/*! Reloads the shuric, returning a new locked shuric.
It signals an error via err_ret if the given shuric is not staled. */
extern shuric_t *shuric_reload (shuric_t *staled_shuric, void *env, caddr_t *err_ret);
#endif

int shuric_make_import (shuric_t *main, shuric_t *sub)
{
  dbg_printf (("shuric_make_import \"%s\" \"%s\" @ %p, refs=%d\n will be imported by \"%s\" \"%s\" @ %p\n",
    sub->_->shuric_type_title, sub->shuric_uri, sub, sub->shuric_ref_count,
    main->_->shuric_type_title, main->shuric_uri, main ));
  if (dk_set_member (main->shuric_imports, sub))
    {
#ifdef DEBUG
      if (!dk_set_member (sub->shuric_imported_by, main))
	GPF_T1 ("Unidirectional link");
#endif
      return 0;
    }
#ifdef DEBUG
  if (dk_set_member (sub->shuric_imported_by, main))
    GPF_T1 ("Unidirectional link");
#endif
  mutex_enter (shuric_mtx);
  sub->shuric_ref_count++;
  dk_set_push (&(main->shuric_imports), sub);
  dk_set_push (&(sub->shuric_imported_by), main);
  mutex_leave (shuric_mtx);
  return 1;
}


int shuric_make_include (shuric_t *main, shuric_t *sub)
{
  dbg_printf (("shuric_make_include \"%s\" \"%s\" @ %p, refs=%d\n will be imported by \"%s\" \"%s\" @ %p\n",
    sub->_->shuric_type_title, sub->shuric_uri, sub, sub->shuric_ref_count,
    main->_->shuric_type_title, main->shuric_uri, main ));
  if (dk_set_member (main->shuric_includes, sub))
    {
#ifdef DEBUG
      if (!dk_set_member (sub->shuric_included_by, main))
	GPF_T1 ("Unidirectional link");
#endif
      return 0;
    }
#ifdef DEBUG
  if (dk_set_member (sub->shuric_included_by, main))
    GPF_T1 ("Unidirectional link");
#endif
  mutex_enter (shuric_mtx);
  sub->shuric_ref_count++;
  dk_set_push (&(main->shuric_includes), sub);
  dk_set_push (&(sub->shuric_included_by), main);
  mutex_leave (shuric_mtx);
  return 1;
}


int shuric_rollback_import (shuric_t *main, shuric_t *sub)
{
  dbg_printf (("shuric_rollback_import \"%s\" \"%s\" @ %p, refs=%d\n no longer imported by \"%s\" \"%s\" @ %p\n",
    sub->_->shuric_type_title, sub->shuric_uri, sub, sub->shuric_ref_count,
    main->_->shuric_type_title, main->shuric_uri, main ));
  if (!dk_set_member (main->shuric_imports, sub))
    {
#ifdef DEBUG
      if (dk_set_member (sub->shuric_imported_by, main))
	GPF_T1 ("Unidirectional link");
#endif
      return 0;
    }
#ifdef DEBUG
  if (!dk_set_member (sub->shuric_imported_by, main))
    GPF_T1 ("Unidirectional link");
#endif
  mutex_enter (shuric_mtx);
  dk_set_delete (&(main->shuric_imports), sub);
  dk_set_delete (&(sub->shuric_imported_by), main);
  mutex_leave (shuric_mtx);
  shuric_release (sub);
  return 1;
}


int shuric_rollback_include (shuric_t *main, shuric_t *sub)
{
  dbg_printf (("shuric_rollback_include \"%s\" \"%s\" @ %p, refs=%d\n no longer included by \"%s\" \"%s\" @ %p\n",
    sub->_->shuric_type_title, sub->shuric_uri, sub, sub->shuric_ref_count,
    main->_->shuric_type_title, main->shuric_uri, main ));
  if (!dk_set_member (main->shuric_includes, sub))
    {
#ifdef DEBUG
      if (dk_set_member (sub->shuric_included_by, main))
	GPF_T1 ("Unidirectional link");
#endif
      return 0;
    }
#ifdef DEBUG
  if (!dk_set_member (sub->shuric_included_by, main))
    GPF_T1 ("Unidirectional link");
#endif
  mutex_enter (shuric_mtx);
  dk_set_delete (&(main->shuric_includes), sub);
  dk_set_delete (&(sub->shuric_included_by), main);
  mutex_leave (shuric_mtx);
  shuric_release (sub);
  return 1;
}


caddr_t shuric_uri_to_text_default (caddr_t uri, query_instance_t *qi, void *env, caddr_t *err_ret)
{
  caddr_t res = xml_uri_get (qi, err_ret, NULL, NULL /* = no base uri */, uri, XML_URI_STRING);
  return res;
}


shuric_t *shuric_scan_relations (shuric_t *haystack_base, caddr_t needle_uri, int scan_mask)
{
  dk_set_t scanned = NULL;
  dk_set_t not_scanned = NULL;
  shuric_t *res = NULL;
  if (NULL == haystack_base)
    return NULL;
  dk_set_push (&not_scanned, haystack_base);
  mutex_enter (shuric_mtx);
  while (NULL != not_scanned)
    {
      dk_set_t directions[SHURIC_SCAN_DIRECTIONS_COUNT];
      int directions_count = 0;
      shuric_t *curr = (shuric_t *) dk_set_pop (&not_scanned);
      dk_set_push (&scanned, curr);
/* First of all we select all lists to scan */
      if (scan_mask & SHURIC_SCAN_IMPORTS)
        directions[directions_count++] = curr->shuric_imports;
      if (scan_mask & SHURIC_SCAN_INCLUDES)
        directions[directions_count++] = curr->shuric_includes;
      if (scan_mask & SHURIC_SCAN_IMPORTED_BY)
        directions[directions_count++] = curr->shuric_imported_by;
      if (scan_mask & SHURIC_SCAN_INCLUDED_BY)
        directions[directions_count++] = curr->shuric_included_by;
/* Now we do an actual scan */
      while (directions_count)
        {
	  dk_set_t related = directions[--directions_count];
	  DO_SET (shuric_t *, sch, &related)
	    {
	      if ((NULL != sch->shuric_uri) && (NULL != needle_uri) && !strcmp (sch->shuric_uri, needle_uri))
		{
		  res = sch;
		  res->shuric_ref_count++; /* not shuric_lock (res); because we're in mutex already */
		  goto scan_complete; /* see below */
		}
	      if (!dk_set_member (scanned, sch) && !dk_set_member (not_scanned, sch))
		dk_set_push (&not_scanned, sch);
	    }
	  END_DO_SET()
	}
    }

scan_complete:
  mutex_leave (shuric_mtx);
  dk_set_free (scanned);
  dk_set_free (not_scanned);
  return res;
}


#ifdef DEBUG

int shuric_check_serial = 0;

void shuric_check_reason_of_forgiveness (shuric_t *shu, int strict)
{
  DO_SET (shuric_t *, imp, &(shu->shuric_imported_by))
    {
      shuric_check_reason_of_forgiveness (imp, strict);
    }
  END_DO_SET();
  DO_SET (shuric_t *, imp, &(shu->shuric_included_by))
    {
      shuric_check_reason_of_forgiveness (imp, strict);
    }
  END_DO_SET();
  if (shu->shuric_watchdog == shuric_check_serial)
    return;
  if (NULL == shu->_->shuric_destroy_data)
    return;
  if ((NULL != shu->shuric_imported_by) || (NULL != shu->shuric_included_by))
    return;
  if (!strict)
    {
      int musthave = dk_set_length (shu->shuric_imported_by) + dk_set_length (shu->shuric_included_by);
      if (shu->shuric_ref_count > musthave)
        return;
    }
  dbg_printf (("shuric_check_reason_of_forgiveness: failed on \"%s\" \"%s\" @ %p, refs=%d",
    shu->_->shuric_type_title, shu->shuric_uri, shu, shu->shuric_ref_count ));
  GPF_T;
}

void shuric_validate_refcounters (int strict)
{
  id_hash_iterator_t it;
  caddr_t **uri_ptr;
  shuric_t **shu_ptr;
  mutex_enter (shuric_mtx);
  shuric_check_serial++;
  dbg_printf (("shuric_validate_refcounters: shuric_check_serial=%d\n", shuric_check_serial));
  id_hash_iterator (&it, shuric_global_hashtable);
  while (hit_next (&it, (caddr_t *) &uri_ptr, (caddr_t *) &shu_ptr))
    {
      int musthave = 1 + dk_set_length (shu_ptr[0]->shuric_imported_by) + dk_set_length (shu_ptr[0]->shuric_included_by);
      if (shu_ptr[0]->shuric_is_stale)
        GPF_T1 ("Staled shuric in shuric_global_hashtable");
      if (shu_ptr[0]->shuric_ref_count < musthave)
        GPF_T1 ("Too small refcount value");
      if (strict && (shu_ptr[0]->shuric_ref_count > musthave))
        GPF_T1 ("Too big refcount value");
      shu_ptr[0]->shuric_watchdog = shuric_check_serial;
    }
  DO_SET (shuric_t *, noncached, &shuric_named_noncached)
    {
      shuric_check_reason_of_forgiveness (noncached, strict);
    }
  END_DO_SET();
  mutex_leave (shuric_mtx);
}
#endif


caddr_t
bif_shuric_list (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t type_mask = bif_string_or_null_arg (qst, args, 0, "__shuric_list");
  caddr_t name_mask = bif_string_or_null_arg (qst, args, 1, "__shuric_list");
  dk_set_t hits = NULL;
  id_hash_iterator_t it;
  caddr_t *uri_ptr;
  shuric_t **shu_ptr;
  mutex_enter (shuric_mtx);
  id_hash_iterator (&it, shuric_global_hashtable);
  while (hit_next (&it, (caddr_t *) &uri_ptr, (caddr_t *) &shu_ptr))
    {
      const char *type_title;
      if (shu_ptr[0]->shuric_is_stale)
	continue;
      if (NULL == uri_ptr[0])
	continue;
      if ((NULL != name_mask) && (DVC_MATCH !=
	   cmp_like (uri_ptr[0], name_mask, NULL, '\0', LIKE_ARG_CHAR, LIKE_ARG_CHAR) ) )
	continue;
      type_title = shu_ptr[0]->_->shuric_type_title;
      if ((NULL != type_mask) && (DVC_MATCH !=
	   cmp_like (type_title, type_mask, NULL, '\0', LIKE_ARG_CHAR, LIKE_ARG_CHAR) ) )
	continue;
      dk_set_push (&hits,
	list (4,
	  box_copy (uri_ptr[0]),
	  box_dv_short_string (type_title),
	  box_num (shu_ptr[0]->shuric_is_stale),
	  box_copy (shu_ptr[0]->shuric_loading_time) ) );
    }
  mutex_leave (shuric_mtx);
  return list_to_array (hits);
}


shuric_t shuric_anchor;
shuric_vtable_t shuric_anchor_vtable = {"List of system resources", NULL, NULL, NULL, NULL, NULL, NULL};


void shuric_on_stale__no_op (struct shuric_s *shuric)
{
#ifdef DEBUG
  shuric_validate_refcounters (0);
  if (shuric->shuric_cache)
    GPF_T1("Cached shuric of type that does not support caching");
#endif
}


void shuric_on_stale__cache_remove (struct shuric_s *shuric)
{
#ifdef DEBUG
  shuric_validate_refcounters (0);
#endif
  if (shuric->shuric_cache)
    shuric->shuric_cache->_->shuric_cache_remove (shuric->shuric_cache, shuric);
}


caddr_t shuric_get_cache_key__stub (struct shuric_s *shuric)
{
  GPF_T1("shuric_get_cache_key__stub() called");
  return NULL;
}


/* shuric_cache__LRU */

extern shuric_cache_t * shuric_cache_alloc__LRU (int size_hint, void *env);
extern void shuric_cache_free__LRU (shuric_cache_t *cache);
extern void shuric_cache_put__LRU (shuric_cache_t *cache, shuric_t *value);
extern shuric_t * shuric_cache_get__LRU (shuric_cache_t *cache, caddr_t key);
extern void shuric_cache_remove__LRU (shuric_cache_t *cache, shuric_t *value);
extern void shuric_cache_empty__LRU (shuric_cache_t *cache);
extern void shuric_cache_on_idle__LRU (shuric_cache_t *cache);


shuric_cache_t *shuric_cache_alloc__LRU (int size_hint, void *env)
{
  NEW_VARZ (shuric_cache_t, sc);
  sc->_ = &shuric_cache__LRU;
  sc->sc_table = id_hash_allocate (size_hint, sizeof (caddr_t), sizeof (caddr_t), treehash, treehashcmp);
  sc->sc_size_hint = size_hint;
  return sc;
}


void shuric_cache_free__LRU (shuric_cache_t *sc)
{
  shuric_cache_empty__LRU (sc);
  id_hash_free (sc->sc_table);
  dk_free (sc, sizeof (shuric_cache_t));
}


#define DLLIST_REMOVE(sc, x) \
do { \
  shuric_t *prev = x->shuric_prev_in_cache; \
  shuric_t *next = x->shuric_next_in_cache; \
  if (next) \
    next->shuric_prev_in_cache = prev; \
  else \
    sc->sc_useless = prev; \
  if (prev) \
    prev->shuric_next_in_cache = next; \
  else \
    sc->sc_worth = next; \
  } while (0)


#define DLLIST_INS_FRONT(sc, x) \
do { \
  x->shuric_prev_in_cache = NULL; \
  x->shuric_next_in_cache = sc->sc_worth; \
  if (sc->sc_worth) \
    { \
      sc->sc_worth->shuric_prev_in_cache = x; \
      sc->sc_worth = x; \
    } \
  else \
    sc->sc_worth = sc->sc_useless = x; \
  } while (0)


#define SHURIC_OUT_OF_CACHE(x) \
  do { x->shuric_prev_in_cache = x->shuric_next_in_cache = NULL; x->shuric_cache = NULL; } while (0)

void shuric_cache_put__LRU (shuric_cache_t *sc, shuric_t *value)
{
  caddr_t key;
  shuric_t **old_ptr;
  shuric_t *old = NULL;
  mutex_enter (shuric_mtx);
  while (sc->sc_table->ht_count >= sc->sc_size_hint)
    {
      old = sc->sc_useless;
      if (old->shuric_cache != sc)
        GPF_T;
      key = value->_->shuric_get_cache_key (old);
#ifdef DEBUG
      old_ptr = (shuric_t **) id_hash_get (sc->sc_table, (caddr_t)(&key));
      if ((NULL == old_ptr) || (old_ptr[0] != old))
        GPF_T;
#endif
      id_hash_remove (sc->sc_table, (caddr_t)(&key));
      DLLIST_REMOVE(sc, old);
      SHURIC_OUT_OF_CACHE(old);
      mutex_leave (shuric_mtx);
      shuric_release (old);
      mutex_enter (shuric_mtx);
    }
  if (NULL != value->shuric_cache)
    {
      if (value->shuric_cache != sc)
        GPF_T;
      if (sc->sc_worth != value)
        {
	  DLLIST_REMOVE(sc, value);
	  DLLIST_INS_FRONT(sc, value);
	}
      mutex_leave (shuric_mtx);
      return;
    }
  value->shuric_ref_count++; /* not shuric_lock (value); because we're in mutex already */
  key = value->_->shuric_get_cache_key (value);
  old_ptr = (shuric_t **) id_hash_get (sc->sc_table, (caddr_t)(&key));
  if (old_ptr)
    {
      old = old_ptr[0];
      id_hash_remove (sc->sc_table, (caddr_t)(&key));
      DLLIST_REMOVE(sc, old);
      SHURIC_OUT_OF_CACHE(old);
    }
  id_hash_set (sc->sc_table, (caddr_t)(&key), (caddr_t)(&value));
  DLLIST_INS_FRONT(sc, value);
  value->shuric_cache = sc;
  mutex_leave (shuric_mtx);
  if (old_ptr)
    shuric_release (old);
}


shuric_t *
shuric_cache_get__LRU (shuric_cache_t *sc, caddr_t key)
{
  shuric_t **value_ptr;
  shuric_t *value;
  mutex_enter (shuric_mtx);
  value_ptr = (shuric_t **) id_hash_get (sc->sc_table, (caddr_t)(&key));
  if (NULL == value_ptr)
    {
      mutex_leave (shuric_mtx);
      return NULL;
    }
  value = value_ptr[0];
  value->shuric_ref_count++; /* not shuric_lock (value); because we're in mutex already */
  if (sc->sc_worth != value)
    {
      DLLIST_REMOVE(sc, value);
      DLLIST_INS_FRONT(sc, value);
    }
  mutex_leave (shuric_mtx);
  return value;
}


void
shuric_cache_remove__LRU (shuric_cache_t *sc, shuric_t *value)
{
  caddr_t key;
  shuric_t **old_ptr;
  shuric_t *old = NULL;
  if (NULL == value)
    return;
  mutex_enter (shuric_mtx);
  if (value->shuric_cache != sc)
    {
      if (value->shuric_cache)
        GPF_T;
      mutex_leave (shuric_mtx);
      return;
    }
  key = value->_->shuric_get_cache_key (value);
  old_ptr = (shuric_t **) id_hash_get (sc->sc_table, (caddr_t)(&key));
  if (old_ptr)
    {
      old = old_ptr[0];
      if (old != value)
        GPF_T;
      id_hash_remove (sc->sc_table, (caddr_t)(&key));
      DLLIST_REMOVE(sc, old);
      SHURIC_OUT_OF_CACHE(old);
    }
  else
    GPF_T;
  mutex_leave (shuric_mtx);
  shuric_release (old);
}


void shuric_cache_empty__LRU (shuric_cache_t *sc)
{
  int ctr;
  for (ctr = sc->sc_table->ht_count; ctr > 0; ctr--)
    {
      if (NULL == sc->sc_useless)
        GPF_T;
      shuric_cache_remove__LRU (sc, sc->sc_useless);
    }
  if (NULL != sc->sc_useless)
    GPF_T;
}


void shuric_cache_on_idle__LRU (shuric_cache_t *sc)
{
}


shuric_cache_vtable_t shuric_cache__LRU =
  {
    "Cache with removal of Least Recently Used records",
    shuric_cache_alloc__LRU,
    shuric_cache_free__LRU,
    shuric_cache_put__LRU,
    shuric_cache_get__LRU,
    shuric_cache_remove__LRU,
    shuric_cache_empty__LRU,
    shuric_cache_on_idle__LRU
  };


/* Global init */


void shuric_init (void)
{
  shuric_global_hashtable = id_str_hash_create (101);
  shuric_mtx = mutex_allocate ();
  shuric_anchor._ = &shuric_anchor_vtable;
  shuric_anchor.shuric_ref_count = 1;
  bif_define ("__shuric_list", bif_shuric_list);
}

void
shuric_terminate_module (void)
{
  int bucket_ctr;
  for (bucket_ctr = shuric_global_hashtable->ht_buckets; bucket_ctr--; /* no step */)
    {
      caddr_t key;
      shuric_t *sptr;
      while (id_hash_remove_rnd (shuric_global_hashtable, bucket_ctr, (caddr_t)&key, (caddr_t)&sptr))
	{
          shuric_lock (sptr);
          shuric_stale_tree (sptr);
          shuric_release (sptr);
	}
    }
}

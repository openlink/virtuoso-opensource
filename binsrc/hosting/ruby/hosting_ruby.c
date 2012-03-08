/*
 *  hosting_ruby.c
 *
 *  $Id$
 *
 *  Virtuoso Ruby hosting plugin
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
 *  
*/

#include "hosting_ruby.h"

/* the initialization critical section */
void *vrb_init_srv = NULL;
vrb_thr_t *vrb_thr = NULL;
vrb_queue_t *vrb_queue = NULL;

void *
vrb_mutex_allocate ()
{
#ifdef WIN32
  CRITICAL_SECTION *crit;
  crit = malloc (sizeof (CRITICAL_SECTION));
  InitializeCriticalSection (crit);
  return (void *) crit;
#else
  pthread_mutex_t *mtx;
  pthread_mutexattr_t mutex_attr;
  mtx = malloc (sizeof (pthread_mutex_t));
  pthread_mutex_init (mtx, &mutex_attr);
  return (void *) mtx;
#endif
}

int
vrb_mutex_enter (void *mtx)
{
#ifdef WIN32
  EnterCriticalSection ((CRITICAL_SECTION *) mtx);
#else
  pthread_mutex_lock ((pthread_mutex_t *) mtx);
#endif
  return 0;
}

void
vrb_mutex_leave (void *mtx)
{
#ifdef WIN32
  LeaveCriticalSection ((CRITICAL_SECTION *) mtx);
#else
  pthread_mutex_unlock ((pthread_mutex_t *) mtx);
#endif
}

void
vrb_mutex_free (void *mtx)
{
#ifdef WIN32
  DeleteCriticalSection ((CRITICAL_SECTION *) mtx);
#else
  pthread_mutex_destroy ((pthread_mutex_t *) mtx);
#endif
  free (mtx);
}

int
vrb_thread_create (void *thr2, RUBY_LPTHREAD_START_ROUTINE funcp, void *arg)
{
#ifdef WIN32
  DWORD dwThreadId;
  thr2 = CreateThread (NULL, 0, funcp, arg, 0, &dwThreadId);
  return dwThreadId;
#else
  thr2 = malloc (sizeof (pthread_t));
  return pthread_create (thr2, NULL, funcp, arg) ? 0 : 1;
#endif
}

pvrb_semaphore_t
vrb_semaphore_allocate ()
{
#ifdef WIN32
  pvrb_semaphore_t sem = CreateSemaphore (NULL, 0, LONG_MAX, NULL);
#else
  pvrb_semaphore_t sem = (pvrb_semaphore_t) malloc (sizeof (vrb_semaphore_t));
  int rc;
  if (0 != (rc = pthread_mutex_init (&(sem->mutex), NULL)))
    {
      free (sem);
      return NULL;
    }
  if (0 != (rc = pthread_cond_init (&(sem->condition), NULL)))
    {
      pthread_mutex_destroy (&(sem->mutex));
      free (sem);
      return NULL;
    }
  sem->count = 0;
#endif
  return sem;
}

int
vrb_semaphore_enter (pvrb_semaphore_t sem)
{
#ifdef WIN32
  return WaitForSingleObject (sem, INFINITE);
#else
  int rc;
  if (0 != (rc = pthread_mutex_lock (&(sem->mutex))))
    return 1;

  while (sem->count <= 0)
    {
      rc = pthread_cond_wait (&(sem->condition), &(sem->mutex));
      if (rc && errno != EINTR)
	break;
    }
  sem->count--;

  if (0 != (rc = pthread_mutex_unlock (&(sem->mutex))))
    return 1;
  return 0;
#endif
}


int
vrb_semaphore_leave (pvrb_semaphore_t sem)
{
#ifdef WIN32
  return ReleaseSemaphore (sem, 1, NULL);
#else
  int rc;
  if (0 != (rc = pthread_mutex_lock (&(sem->mutex))))
    return 0;

  sem->count++;

  if (0 != (rc = pthread_mutex_unlock (&(sem->mutex))))
    return 0;

  if (0 != (rc = pthread_cond_signal (&(sem->condition))))
    return 0;

  return 1;
#endif
}

void
vrb_semaphore_free (pvrb_semaphore_t sem)
{
#ifdef WIN32
  CloseHandle (sem);
#else
  pthread_mutex_destroy (&(sem->mutex));
  pthread_cond_destroy (&(sem->condition));
  free (sem);
#endif
}

#define TAG_RETURN      0x1
#define TAG_BREAK       0x2
#define TAG_NEXT        0x3
#define TAG_RETRY       0x4
#define TAG_REDO        0x5
#define TAG_RAISE       0x6
#define TAG_THROW       0x7
#define TAG_FATAL       0x8
#define TAG_MASK        0xf


void
vrb_tailprintf(char *text, size_t tlen, int *fill, const char *string,...)
{
  int len;
  va_list list;
  va_start (list, string);
  len = vsnprintf (text+fill[0], tlen - *fill, string, list);
  va_end (list);
  if (len<0)
    return;
  fill[0] += len;
}



static void
get_error_pos(char *buf, int max, int *fill)
{
  ID last_func = rb_frame_last_func();

  if (ruby_sourcefile) {
    if (last_func) {
      vrb_tailprintf(buf, max, fill, "%s:%d:in `%s'", ruby_sourcefile, ruby_sourceline,
	  rb_id2name(last_func));
    }
    else {
      vrb_tailprintf (buf, max, fill, "%s:%d", ruby_sourcefile, ruby_sourceline);
    }
  }
}


static void
vrb_get_exception_info (char *buf, int max, int *fill)
{
  VALUE errat;
  VALUE eclass;
  VALUE estr;
  char *einfo;
  int elen;
  int state;

  if (NIL_P(ruby_errinfo)) return;

  errat = rb_funcall(ruby_errinfo, rb_intern("backtrace"), 0);
  if (!NIL_P(errat))
    {
      VALUE mesg = RARRAY(errat)->ptr[0];

      if (NIL_P(mesg))
	{
	  get_error_pos(buf, max, fill);
	}
      else
	{
	  vrb_tailprintf (buf, max, fill, "%.*s", RSTRING(mesg)->len,  RSTRING(mesg)->ptr);
	}
    }

  eclass = CLASS_OF(ruby_errinfo);
  estr = rb_protect(rb_obj_as_string, ruby_errinfo, &state);
  if (state)
    {
      einfo = "";
      elen = 0;
    }
  else
    {
      einfo = RSTRING(estr)->ptr;
      elen = RSTRING(estr)->len;
    }
  if (eclass == rb_eRuntimeError && elen == 0)
    {
      vrb_tailprintf (buf, max, fill, ": unhandled exception\n");
    }
  else
    {
      VALUE epath;

      epath = rb_class_path(eclass);
      if (elen == 0)
	{
	  vrb_tailprintf (buf, max, fill, ": ");
	  vrb_tailprintf (buf, max, fill, "%.*s", RSTRING(epath)->len, RSTRING(epath)->ptr);
	  vrb_tailprintf (buf, max, fill, "\n");
	}
      else
	{
	  char *tail  = 0;
	  int len = elen;

	  if (RSTRING(epath)->ptr[0] == '#') epath = 0;
	  if ((tail = strchr(einfo, '\n')) != NULL)
	    {
	      len = tail - einfo;
	      tail++;         /* skip newline */
	    }
	  vrb_tailprintf (buf, max, fill, ": ");
	  vrb_tailprintf (buf, max, fill, "%.*s", len, einfo);
	  if (epath)
	    {
	      vrb_tailprintf (buf, max, fill, " (");
	      vrb_tailprintf (buf, max, fill, "%.*s", RSTRING(epath)->len, RSTRING(epath)->ptr);
	      vrb_tailprintf (buf, max, fill, ")\n");
	    }
	  if (tail)
	    {
	      vrb_tailprintf (buf, max, fill, "%.*s", elen - len - 1, tail);
	      vrb_tailprintf (buf, max, fill, "\n");
	    }
	}
    }

  if (!NIL_P(errat))
    {
      long i, len;
      struct RArray *ep;

#define TRACE_MAX (TRACE_HEAD+TRACE_TAIL+5)
#define TRACE_HEAD 8
#define TRACE_TAIL 5

      ep = RARRAY(errat);
      len = ep->len;
      for (i=1; i<len; i++)
	{
	  if (TYPE(ep->ptr[i]) == T_STRING)
	    {
	      vrb_tailprintf (buf, max, fill, "  from ");
	      vrb_tailprintf (buf, max, fill, "%.*s", RSTRING(ep->ptr[i])->len, RSTRING(ep->ptr[i])->ptr);
	      vrb_tailprintf (buf, max, fill, "\n");
	    }
	  if (i == TRACE_HEAD && len > TRACE_MAX)
	    {
	      vrb_tailprintf (buf, max, fill, "   ... %ld levels...\n",
		  len - TRACE_HEAD - TRACE_TAIL);
	      i = len - TRACE_TAIL;
	    }
	}
    }
}

static void
vrb_get_error_info(int state, char *buf, int max, int *fill)
{
  if (max - *fill)
    buf[0] = 0;

  switch (state) {
    case TAG_RETURN:
	get_error_pos(buf, max, fill);
	vrb_tailprintf (buf, max, fill, ": unexpected return\n");
	break;
    case TAG_NEXT:
	get_error_pos(buf, max, fill);
	vrb_tailprintf (buf, max, fill, ": unexpected next\n");
	break;
    case TAG_BREAK:
	get_error_pos(buf, max, fill);
	vrb_tailprintf (buf, max, fill, ": unexpected break\n");
	break;
    case TAG_REDO:
	get_error_pos(buf, max, fill);
	vrb_tailprintf (buf, max, fill, ": unexpected redo\n");
	break;
    case TAG_RETRY:
	get_error_pos(buf, max, fill);
	vrb_tailprintf (buf, max, fill, ": retry outside of rescue clause\n");
	break;
    case TAG_RAISE:
    case TAG_FATAL:
	vrb_get_exception_info(buf, max, fill);
	break;
    default:
	get_error_pos(buf, max, fill);
	vrb_tailprintf (buf, max, fill, ": unknown longjmp status %d", state);
	break;
  }
}

static void
vrb_ruby_setenv (const char *key, const char *val)
{
  if (!key)
    return;

  ruby_unsetenv (key);

  if (val && *val)
    ruby_setenv(key, val);
}


RUBY_THREAD_FUNC_TYPE
vrb_srv_worker (RUBY_THREAD_FUNC_ARG_TYPE arg)
{
  VALUE stack_start;
  vrb_thr_t *thr2 = (vrb_thr_t *) arg;
  vrb_request_t *elt;
  vrb_queue_t *queue2 = thr2->thr_queue;
  int state, i = 0, reinit = 0;
  void Init_stack _((VALUE *));

again:
  ruby_init ();
  Init_stack (&stack_start);
  ruby_init_loadpath ();
  vrb_init_virt_code ();
  /*fprintf (stderr, "safe level=%d\n", (int) rb_safe_level());*/
  if (!reinit)
    vrb_semaphore_leave (thr2->vrt_sem_init);
  else
    reinit = 0;
  do
    {
      /* wait for continue notification */
      vrb_semaphore_enter (thr2->vrt_sem);
      /* get a element from the queue */
      vrb_mutex_enter (queue2->q_sect);
      elt = queue2->q_head;
      queue2->q_head = elt->qe_next;
      vrb_mutex_leave (queue2->q_sect);

      ruby_script (elt->base_uri);

      /* environment */
      for (i = 0; i < elt->n_options; i += 2)
	{
	  vrb_ruby_setenv (elt->options[i], elt->options[i + 1]);
	  if (elt->options[i] && elt->options[i + 1] &&
	      !strcmp (elt->options[i], "__VIRT_CGI") &&
	      !strcmp (elt->options[i + 1], "1"))
	    elt->html_mode = 1;
	}

      /* actual processing */
      vrb_virt_start_request (elt);
      if (elt->content)
	rb_eval_string_protect (elt->content, &state);
      else
	vrb_load_file_protect (elt->base_uri, &state);
      if (state)
	{
	  if (state == TAG_RAISE
	      && rb_obj_is_kind_of (ruby_errinfo, rb_eSystemExit))
	    {
	      *(elt->head_ret) = NULL;
	      elt->retval = NULL;
	      *(elt->diag_ret) = NULL;
	      if (elt->err && elt->max_len > 0)
		{
		  strncpy (elt->err, "Raise condition returned by the Ruby runtime", elt->max_len);
		  elt->err[elt->max_len] = 0;
		}
	      reinit = 1;
	      goto next_loop;
	    }
	  else
	    {
	      int fill = 0;

	      if (elt->err && elt->max_len > 0)
		vrb_get_error_info (state, elt->err, elt->max_len, &fill);
	    }
	}

      vrb_virt_flush_request ();
next_loop:
      rb_gc ();
      /* mark the processing done */
      vrb_semaphore_leave (elt->qe_sem);
    }
  while (!reinit);
  ruby_finalize ();
  goto again;
}

static void
hosting_ruby_connect (void *x)
{
}

static hosting_version_t hosting_ruby_version = {
  {
	HOSTING_TITLE,		/* !< Title of unit, filled by unit */
	DBMS_SRV_GEN_MAJOR DBMS_SRV_GEN_MINOR,	/* !< Version number,
						 * filled by unit */
	"OpenLink Software",	/* !< Plugin's developer, filled by
				 * unit */
	"Ruby hosting plugin",	/* !< Any additional info, filled by
				 * unit */
	NULL,			/* !< Error message, filled by unit loader */
	NULL,			/* !< Name of file with unit's code, filled
				 * by unit loader */
	hosting_ruby_connect,	/* !< Pointer to connection function,
				 * cannot be NULL */
	NULL,			/* !< Pointer to disconnection function, or
				 * NULL */
	NULL,			/* !< Pointer to activation function, or NULL */
	NULL,			/* !< Pointer to deactivation function, or
				 * NULL */
      NULL},
  NULL, NULL, NULL, NULL, NULL,
  NULL
};

void *
virtm_client_attach (char *err, int max_len)
{
  /* initialize on first enter */
  int result;
  if (!vrb_init_srv)
    vrb_init_srv = vrb_mutex_allocate ();
  vrb_mutex_enter (vrb_init_srv);
  if (!vrb_thr)
    {
      void *handle = NULL;
      /* allocate & init the queue structure */
      vrb_queue = malloc (sizeof (vrb_queue_t));
      memset (vrb_queue, 0, sizeof (vrb_queue_t));
      vrb_queue->q_sect = vrb_mutex_allocate ();
      /* allocate & init the thread struct */
      vrb_thr = malloc (sizeof (vrb_thr_t));
      vrb_thr->vrt_sem_init = vrb_semaphore_allocate ();
      vrb_thr->vrt_sem = vrb_semaphore_allocate ();
      vrb_thr->thr_queue = vrb_queue;
      result = vrb_thread_create (handle, vrb_srv_worker, vrb_thr);
      if (!result)
	{
	  vrb_semaphore_free (vrb_thr->vrt_sem_init);
	  vrb_semaphore_free (vrb_thr->vrt_sem);
	  free (vrb_thr);
	  vrb_mutex_free (vrb_queue->q_sect);
	  free (vrb_queue);
	  vrb_thr = NULL;
	  vrb_queue = NULL;
	  SET_ERR ("Can\'t start the Ruby worker thread");
	}
      else
	{
	  vrb_semaphore_enter (vrb_thr->vrt_sem_init);
	  vrb_semaphore_free (vrb_thr->vrt_sem_init);
	}
    }
  vrb_mutex_leave (vrb_init_srv);
  return vrb_queue;
}

unit_version_t *
hosting_ruby_check (unit_version_t * in, void *appdata)
{
  static char *args[2];
  args[0] = "rb";
  args[1] = NULL;
  hosting_ruby_version.hv_extensions = args;
  return &hosting_ruby_version.hv_pversion;
}

void
virtm_client_detach (void *cli)
{
}

void *
virtm_client_clone (void *cli, char *err, int max_err_len)
{
  return NULL;
}

void
virtm_client_free (void *cli)
{
}

char *
virtm_http_handler (void *cli, char *err, int max_len,
    const char *base_uri, const char *content,
    const char *params, const char **lines, int n_lines,
    char **head_ret, const char **options, int n_options, char **diag_ret,
    int compile_only)
{
  vrb_request_t req;
  vrb_queue_t *queue2 = (vrb_queue_t *) cli;
  if (diag_ret)
    *diag_ret = NULL;
  if (compile_only)
    return NULL;
  if (!queue2)
    {
      SET_ERR ("client not attached to the interface");
      return NULL;
    }
  /* prepare the request */
  memset (&req, 0, sizeof (vrb_request_t));
  req.qe_sem = vrb_semaphore_allocate ();
  if (!req.qe_sem)
    return NULL;
  req.base_uri = base_uri;
  req.n_options = n_options;
  req.options = options;
  req.params = params;
  req.content = content;
  req.diag_ret = diag_ret;
  req.head_ret = head_ret;
  req.err = err;
  req.max_len = max_len;
  /* add it to the queue */
  vrb_mutex_enter (queue2->q_sect);
  req.qe_next = queue2->q_head;
  queue2->q_head = &req;
  vrb_mutex_leave (queue2->q_sect);
  /*
   * signal the worker thread's semaphore and wait for processing to
   * complete
   */
  vrb_semaphore_leave (vrb_thr->vrt_sem);
  vrb_semaphore_enter (req.qe_sem);
  /* free the request */
  vrb_semaphore_free (req.qe_sem);
  return req.retval;
}

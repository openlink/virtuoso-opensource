/*
 *  hosting_ruby.h
 *
 *  $Id$
 *
 *  Virtuoso Ruby hosting plugin header
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
 *  
*/

#ifndef HOSTING_RUBY_H
#define HOSTING_RUBY_H
#include <stdio.h>
#include <stdarg.h>

#ifdef _POSIX_C_SOURCE
#undef _POSIX_C_SOURCE
#endif
#ifdef _XOPEN_SOURCE
#undef _XOPEN_SOURCE
#endif
#if defined (_DEBUG) && defined (WIN32)
#undef _DEBUG
#endif
#include "ruby.h"
#include "util.h"

#ifdef WIN32
#include <windows.h>
#define RUBY_LPTHREAD_START_ROUTINE LPTHREAD_START_ROUTINE
#define RUBY_THREAD_FUNC_TYPE DWORD WINAPI
#define RUBY_THREAD_FUNC_ARG_TYPE PVOID
#define pvrb_semaphore_t HANDLE
#else
#include <pthread.h>
#include <errno.h>
typedef void *(*RUBY_LPTHREAD_START_ROUTINE) (void *);
#define RUBY_THREAD_FUNC_TYPE static void *
#define RUBY_THREAD_FUNC_ARG_TYPE void *
typedef struct r_semaphore_s
{
  pthread_mutex_t mutex;
  pthread_cond_t condition;
  int count;
} vrb_semaphore_t;
#define pvrb_semaphore_t vrb_semaphore_t *
#endif
#include "hosting.h"
#include "sqlver.h"

/* Ruby routines */
#define WORKER_THREAD_STACK_SIZE 100000

#define SET_ERR(str) \
{ \
    if (err && max_len > 0) \
    { \
        strncpy (err, str, max_len); \
        err[max_len] = 0; \
    } \
}

/* the request queue element structure */
typedef struct vrb_request
{
  pvrb_semaphore_t qe_sem;
  struct vrb_request *qe_next;
  const char *base_uri;
  int n_options;
  const char **options;
  const char *params;
  const char *content;
  char **diag_ret;
  char **head_ret;
  char *retval;
  char *err;
  int max_len;
  int html_mode;
} vrb_request_t;

/* the request queue structure */
typedef struct vrb_queue_s
{
  void *q_sect;
  vrb_request_t *q_head;
} vrb_queue_t;

/* the worker thread(s) structure */
typedef struct vrb_thr_s
{
  pvrb_semaphore_t vrt_sem_init;
  pvrb_semaphore_t vrt_sem;
  void *thr;
  vrb_queue_t *thr_queue;
} vrb_thr_t;

extern void *vrb_init_srv;
extern vrb_thr_t *vrb_thr;
extern vrb_queue_t *vrb_queue;

RUBY_EXTERN VALUE vrb_request;
RUBY_EXTERN VALUE ruby_err_info;

/* ruby_io.c */
void vrb_virt_start_request (vrb_request_t *elt);
void vrb_virt_flush_request ();
void vrb_init_virt_code ();
void vrb_load_file_protect (const char *file, int *state);

/*#define VRB_DEBUG*/
#ifdef VRB_DEBUG
#define vrb_fprintf(x) fprintf x
#else
#define vrb_fprintf(x)
#endif

#endif

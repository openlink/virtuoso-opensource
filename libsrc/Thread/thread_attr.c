/*
 *  thread_attr.c
 *
 *  $Id$
 *
 *  Manages thread local storage attributes
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

#include "Dk.h"


void
_thread_init_attributes (thread_t *self)
{
  if (!self->thr_attributes)
    self->thr_attributes = hash_table_allocate (THREAD_ATTRIBUTE_HASH);
  else
    clrhash ((dk_hash_t *) self->thr_attributes);
}


void
_thread_free_attributes (thread_t *self)
{
  if (self->thr_attributes)
    {
      hash_table_free ((dk_hash_t *) self->thr_attributes);
      self->thr_attributes = NULL;
    }
}


void *
thread_setattr (thread_t *self, void *key, void *value)
{
  return sethash (key, (dk_hash_t *) self->thr_attributes, value);
}


void *
thread_getattr (thread_t *self, void *key)
{
  return gethash (key, (dk_hash_t *) self->thr_attributes);
}

/*#define ERR_DEBUG*/

caddr_t
DBG_NAME(thr_get_error_code) (DBG_PARAMS  thread_t *thr)
{
  caddr_t ret = thr->thr_reset_code;
  thr->thr_reset_code = NULL;
#ifdef ERR_DEBUG
  fprintf (stderr, "thr_get_error_code (%p)=%p [%s]\n",
      thr, ret, ret ? (ERROR_REPORT_P (ret) ? ((caddr_t *)ret)[2] : "<not found>") : "<none>");
#endif
#ifdef SIGNAL_DEBUG
  if (ERROR_REPORT_P(ret))
    log_error_report_event (ret, 0, "THR_GET at %s:%d", file, line);
#endif
  return ret;
}

void
DBG_NAME(thr_set_error_code) (DBG_PARAMS  thread_t *thr, caddr_t err)
{
#ifdef ERR_DEBUG
  fprintf (stderr, "thr_set_error_code (%p, %p [%s]) -> free %p [%s]\n",
      thr, err, err ? (ERROR_REPORT_P (err) ? ((caddr_t *)err)[2] : "<not found>") : "<none>",
      thr->thr_reset_code, thr->thr_reset_code ? (ARRAYP (thr->thr_reset_code) ?  ((caddr_t *)thr->thr_reset_code)[2] : "<not found>") : "<none>");
#endif
#ifdef SIGNAL_DEBUG
  if (ERROR_REPORT_P(err))
    log_error_report_event (err, 0, "THR_SET at %s:%d", file, line);
#endif
  dk_free_tree (thr->thr_reset_code);
  thr->thr_reset_code = err;
}


#ifdef JMP_CKSUM
uint32
j_cksum (jmp_buf j)
{
  uint32 h = 0;
  char * ptr = (char*)j;
  BYTE_BUFFER_HASH (h, ptr, sizeof (jmp_buf));
  return h;
}

int 
j_set_cksum (jmp_buf_splice * j, int rc)
{
  if (!rc)
    j->j_cksum = j_cksum (j->buf);
  return rc;
}
#endif

void
longjmp_brk (jmp_buf_splice * b, int rc)
{
#ifdef JMP_CKSUM
  if (b->j_cksum != j_cksum (b->buf))
    GPF_T1 ("uninited jmp buffer");
#endif
  longjmp (b->buf, rc);
}

#ifdef MALLOC_DEBUG
#undef thr_get_error_code
caddr_t thr_get_error_code (thread_t *thr) { return dbg_thr_get_error_code (__FILE__, __LINE__, thr); }
#undef thr_set_error_code
void thr_set_error_code (thread_t *thr, caddr_t err) { dbg_thr_set_error_code (__FILE__, __LINE__, thr, err); }
#endif

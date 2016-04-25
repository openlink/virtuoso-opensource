/*
 *  dbgmal.c
 *
 *  $Id$
 *
 *  Debugging malloc package
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

#undef MALLOC_DEBUG

#include "libutil.h"
#include "util/dyntab.h"
#include "util/dbgmal.h"

#ifdef USE_KILL_RINGBUF
#define KILL_RINGBUF_SIZE 0x1FF0
void **kill_ringbuf[KILL_RINGBUF_SIZE];
void **kill_ringbuf_curr = kill_ringbuf;
#define FREE_WITH_DELAY(ptr) \
  do \
    { \
      if (NULL != kill_ringbuf_curr[0]) \
        free (kill_ringbuf_curr[0]); \
      kill_ringbuf_curr[0] = ptr; \
      if (kill_ringbuf_curr == kill_ringbuf) \
        kill_ringbuf_curr = kill_ringbuf + KILL_RINGBUF_SIZE - 1; \
      else \
        kill_ringbuf_curr--; \
    } while (0)
#else
#define FREE_WITH_DELAY(ptr) free(ptr)
#endif

#define MALREC_FNAME_BUFLEN 32
struct malrec_s
  {
    char fname[MALREC_FNAME_BUFLEN];
    u_int linenum;
    long numalloc;
    long prevalloc;
    long numfree;
    long prevfree;
    size_t totalsize;
    size_t prevsize;
  };
typedef struct malrec_s malrec_t;

struct malhdr_s
  {
    uint32 magic;
    malrec_t *origin;
    size_t size;
    void *pool;
  };
typedef struct malhdr_s malhdr_t;

dk_mutex_t *		_dbgmal_mtx;
static dyntable_t	_dbgtab;
static size_t		_totalmem;
static uint32		_free_nulls;
static uint32		_free_invalid;
static int		_dbgmal_enabled;

void memdbg_abort (void);

#ifdef MALLOC_STRESS
static size_t dbg_malloc_hard_memlimit = ~((size_t)0);
static const char *hit_name = "";
static malrec_t *hit_rec = NULL;
static size_t hit_totalsize = 0;

void dbg_malloc_set_hard_memlimit (size_t consumption)
{
  dbg_malloc_hard_memlimit = consumption;
}

extern void dbg_malloc_hit_impl (const char *file, u_int line, const char *name)
{
  if (NULL != hit_rec)
    return;
  if (strcmp (name, hit_name))
    return;
  hit_rec = mal_register (file, line);
}

extern void dbg_malloc_set_hit_memlimit (const char *name, size_t consumption)
{
  if (strcmp (name, hit_name))
    {
      hit_name = name;
      hit_rec = NULL;
    }
  hit_totalsize = consumption;
}
#endif

/* #define USE_KILL_RINGBUF */

#ifdef USE_KILL_RINGBUF
#define KILL_RINGBUF_SIZE 0x1FF0
void **kill_ringbuf[KILL_RINGBUF_SIZE];
void **kill_ringbuf_curr = kill_ringbuf;
#define FREE_WITH_DELAY(ptr) \
  do \
    { \
      if (NULL != kill_ringbuf_curr[0]) \
        free (kill_ringbuf_curr[0]); \
      kill_ringbuf_curr[0] = ptr; \
      if (kill_ringbuf_curr == kill_ringbuf) \
        kill_ringbuf_curr = kill_ringbuf + KILL_RINGBUF_SIZE - 1; \
      else \
        kill_ringbuf_curr--; \
    } while (0)
#else
#define FREE_WITH_DELAY(ptr) free(ptr)
#endif

size_t dbg_malloc_get_current_total (void) { return _totalmem; }


static void
mal_printall (htrecord_t record, void *arg)
{
  malrec_t *rec = (malrec_t *) record;
  char buf[200];
  size_t buflen;
  char *localname;
  /* The path to file should not be printed */
  if (NULL != (localname = strrchr (rec->fname, '/')))
    localname++;
  else if (NULL != (localname = strrchr (rec->fname, '\\')))
    localname++;
  else localname = rec->fname;
  /* Printing aligned filename and line number */
  if (rec->linenum == -1)
    snprintf(buf, sizeof (buf), "%s (mark)", localname);
  else
    snprintf(buf, sizeof (buf), "%s (%04d)", localname, rec->linenum);
  buflen = strlen(buf);
  if (buflen < 20)
    {
      memset (buf+buflen, ' ', 20-buflen);
      buf[20] = '\0';
    }
  /* Printing statistics */
  fprintf ((FILE *) arg,
    "%s %7ld uses = %7ld - %7ld | %7ld + %7ld = %7ld b\n",
    buf,
    rec->numalloc - rec->numfree,
    rec->numalloc,
    rec->numfree,
    (long)(rec->prevsize),
    (long)(rec->totalsize - rec->prevsize),
    (long)(rec->totalsize) );
  rec->prevalloc = rec->numalloc;
  rec->prevfree = rec->numfree;
  rec->prevsize = rec->totalsize;
}


static void
mal_printnew (htrecord_t record, void *arg)
{
  malrec_t *rec = (malrec_t *) record;
  if (rec->totalsize != rec->prevsize)
    mal_printall (record, arg);
  else
    {
      rec->prevalloc = rec->numalloc;
      rec->prevfree = rec->numfree;
      rec->prevsize = rec->totalsize;
    }
}


static void
mal_printoneleak (htrecord_t record, void *arg)
{
  malrec_t *rec = (malrec_t *) record;
  char buf[200];
  size_t buflen;
  char *localname;
  if ((rec->totalsize <= rec->prevsize) &&
    ((rec->numalloc - rec->prevalloc) <= (rec->numfree - rec->prevfree)) )
    {
      rec->prevalloc = rec->numalloc;
      rec->prevfree = rec->numfree;
      rec->prevsize = rec->totalsize;
      return;
    }
  /* The path to file should not be printed */
  if (NULL != (localname = strrchr (rec->fname, '/')))
    localname++;
  else if (NULL != (localname = strrchr (rec->fname, '\\')))
    localname++;
  else localname = rec->fname;
  /* Printing aligned filename and line number */
  if (rec->linenum == -1)
    snprintf(buf, sizeof (buf), "%s (mark)", localname);
  else
    snprintf(buf, sizeof (buf), "%s (%4d)", localname, rec->linenum);
  buflen = strlen(buf);
  if (buflen < 20)
    {
      memset (buf+buflen, ' ', 20-buflen);
      buf[20] = '\0';
    }
  /* Printing statistics */
  fprintf ((FILE *) arg,
    "%s%7ld leaks =%7ld -%7ld |%7ld +%7ld =%7ld b\n",
    buf,
    (rec->numalloc - rec->prevalloc) - (rec->numfree - rec->prevfree),
    (rec->numalloc - rec->prevalloc),
    (rec->numfree - rec->prevfree),
    (long)(rec->prevsize),
    (long)(rec->totalsize - rec->prevsize),
    (long)(rec->totalsize) );
  rec->prevalloc = rec->numalloc;
  rec->prevfree = rec->numfree;
  rec->prevsize = rec->totalsize;
}


static u_int
mal_hashfun (htrecord_t record)
{
  malrec_t *rec = (malrec_t *) record;
  char *cp;
  u_int h;

  for (h = 0, cp = rec->fname; *cp; cp++)
    {
      h *= 3;
      h += *cp;
    }
  h ^= rec->linenum;
  h ^= ((rec->linenum) << 16);

  return h;
}


static int
mal_comparefun (htrecord_t recA, htrecord_t recB)
{
  malrec_t *r1 = (malrec_t *) recA;
  malrec_t *r2 = (malrec_t *) recB;
  int i;

  i = r1->linenum - r2->linenum;
  if (i)
    return i;
  return strcmp (r2->fname, r1->fname);
}


static malrec_t *
mal_register (const char *name, u_int line)
{
  malrec_t xrec, *r;

  strncpy (xrec.fname, name, MALREC_FNAME_BUFLEN);
  xrec.fname[MALREC_FNAME_BUFLEN-1] = '\0';
  xrec.linenum = line;

  r = (malrec_t *) dtab_find_record (_dbgtab, 1, (htrecord_t) &xrec);

  if (r == NULL)
    {
      dtab_create_record (_dbgtab, (htrecord_t *) &r);
      strcpy (r->fname, xrec.fname);
      r->linenum = line;
      r->numalloc = r->prevalloc = 0;
      r->numfree = r->prevfree = 0;
      r->totalsize = r->prevsize = 0;
      dtab_add_record ((htrecord_t) r);
    }

  return r;
}

size_t
dbg_mal_count (const char *name, u_int line)
{
  malrec_t xrec, *r;

  strncpy (xrec.fname, name, MALREC_FNAME_BUFLEN);
  xrec.fname[MALREC_FNAME_BUFLEN-1] = '\0';
  xrec.linenum = line;

  r = (malrec_t *) dtab_find_record (_dbgtab, 1, (htrecord_t) &xrec);
  return r ? r->numalloc - r->numfree : 0;
}

#ifdef DBGMAL_SIGNAL
static RETSIGTYPE
mal_sighandler (int sig)
{
  signal (DBGMAL_SIGNAL, mal_sighandler);
  dbg_malstats (stderr, DBG_MALSTATS_ALL);
}
#endif


static void
mal_init (void)
{
  _dbgmal_mtx = mutex_allocate ();	/* Note - calls dbg_malloc!! */

  dtab_create_table (
	&_dbgtab,
	sizeof(malrec_t),	/* record size */
	1021,			/* init record count */
	1021,			/* record incr */
	NULL, 0,
	NULL);

  dtab_define_key (_dbgtab, mal_hashfun, 1021, mal_comparefun, 1);

#ifdef DBGMAL_SIGNAL
  signal (DBGMAL_SIGNAL, mal_sighandler);
#endif
}


void dbg_malloc_enable(void)
{
  if (_dbgmal_enabled)
    return;
  mal_init();
  _dbgmal_enabled = 1;
}

#ifdef MALLOC_STRESS
#define DBG_MALLOC_HARD_LIMIT_CHECK \
  if (_totalmem > dbg_malloc_hard_memlimit) \
    { \
      fprintf (stderr, "WARNING: running out of memory limit (%ld) on allocation of %ld at %s (%u)\n", \
	  (long) dbg_malloc_hard_memlimit, (long) size, file, line); \
      _totalmem -= size; \
      goto err; \
    }
#define DBG_MALLOC_HIT_LIMIT_CHECK \
  if ((rec == hit_rec) && ((rec->totalsize + size) > hit_totalsize)) \
    { \
      fprintf (stderr, "WARNING: running out of local memory limit (%ld) on allocation of %ld at %s (%u)\n", \
	  (long) (rec->totalsize), (long) size, file, line); \
      _totalmem -= size; \
      goto err; \
    }
#else
#define DBG_MALLOC_HARD_LIMIT_CHECK ;
#define DBG_MALLOC_HIT_LIMIT_CHECK ;
#endif


#define DBG_MALLOC_IMPL(RAW_MALLOC,MAGIC,POOL,MEMSET)  \
do { \
  malhdr_t *data; \
  malrec_t *rec; \
  void *user; \
  if (!_dbgmal_enabled) \
    return RAW_MALLOC; \
  mutex_enter (_dbgmal_mtx); \
  if (size == 0) \
    { \
      fprintf (stderr, "WARNING: allocating 0 bytes in %s (%u)\n", \
	  file, line); \
    } \
  _totalmem += size; \
  DBG_MALLOC_HARD_LIMIT_CHECK; \
  rec = mal_register (file, line); \
  DBG_MALLOC_HIT_LIMIT_CHECK; \
  if ((data = (malhdr_t *) malloc (sizeof (malhdr_t) + size + 4)) == NULL) \
    { \
      fprintf (stderr, "WARNING: malloc(%ld) returned NULL for %s (%u)\n", \
	  (long) size, file, line); \
      goto err; \
    } \
  data->magic = MAGIC; \
  data->origin = rec; \
  data->size = size; \
  data->pool = POOL; \
  data->origin->totalsize += size; \
  data->origin->numalloc++; \
  mutex_leave (_dbgmal_mtx); \
  user = (u_char *) data + sizeof (malhdr_t); \
  MEMSET; \
  ((unsigned char *) user)[size + 0] = 0xDE; \
  ((unsigned char *) user)[size + 1] = 0xAD; \
  ((unsigned char *) user)[size + 2] = 0xC0; \
  ((unsigned char *) user)[size + 3] = 0xDE; \
  return user; \
err: \
  mutex_leave (_dbgmal_mtx); \
  return NULL; \
  } while (0);

#ifndef USE_TLSF
void *
dbg_malloc (const char *file, u_int line, size_t size)
{
  DBG_MALLOC_IMPL (malloc(size), MALMAGIC_OK, NULL, 0)
}
#endif

void *
dbg_realloc (const char *file, u_int line, void *old, size_t size)
{
  void *res;
  if (0 == size)
    {
      if (NULL != old)
        dbg_free (file, line, old);
      return NULL;
    }
  res = dbg_malloc (file, line, size);
  if (NULL != old)
    {
      malhdr_t *mhdr = (malhdr_t *) ((u_char *) old - sizeof (malhdr_t));
      size_t oldsize;
      if (mhdr->magic != MALMAGIC_OK)
        {
          const char *msg = dbg_find_allocation_error (old, NULL);
          fprintf (stderr, "WARNING: free of invalid pointer in %s (%u): %s\n",
	    file, line,
	    msg ? msg : "");
	  _free_invalid++;
          memdbg_abort ();
          return NULL;
        }
      oldsize = mhdr->size;
      memcpy (res, old, ((oldsize > size) ? size : oldsize));
      dbg_free (file, line, old);
    }
  return res;    
}

void *
dbg_mallocp (const char *file, u_int line, size_t size, void *pool)
{
  DBG_MALLOC_IMPL (malloc(size), MALPMAGIC_OK, pool, 0)
}


void *
dbg_calloc (const char *file, u_int line, size_t num, size_t size)
{
  size *= num;
  DBG_MALLOC_IMPL (calloc (1, size), MALMAGIC_OK, NULL, memset (user, '\0', size))
}


void *
dbg_callocp (const char *file, u_int line, size_t num, size_t size, void *pool)
{
  size *= num;
  DBG_MALLOC_IMPL (calloc (1, size), MALPMAGIC_OK, pool, memset (user, '\0', size))
}


char *
dbg_strdup (const char *file, u_int line, const char *str)
{
  size_t length = strlen (str) + 1;
  char *tmp = (char *) dbg_malloc (file, line, length);
  memcpy (tmp, str, length);
  return tmp;
}


void
memdbg_abort (void)
{
  if (1 || getenv ("MEMDBG_ABORT"))
#if 0
    abort ();
#else
  *(long*)-1 = -1;
#endif
}

#if 0
#define ERROR_FOUND(err) return NULL;
#else
#define ERROR_FOUND(err) { sprintf err; return buf; }
#endif

const char *dbg_find_allocation_error (void *data, void *expected_pool)
{
  static char buf[0x100];
  malhdr_t *mhdr;
  u_char *cp;
  if (data == NULL)
    ERROR_FOUND((buf, "NULL pointer"));
  if (!_dbgmal_enabled)
    {
      return NULL;
    }
  mhdr = (malhdr_t *) ((u_char *) data - sizeof (malhdr_t));
  if (NULL != expected_pool)
    {
      if (mhdr->magic != MALPMAGIC_OK)
	{
	  if (mhdr->magic == MALMAGIC_OK)
	    return NULL; /*"Pointer to allocated non-pooled buffer, pooled expected";*/
	  if (mhdr->magic == MALMAGIC_FREED)
	    ERROR_FOUND((buf, "Pointer to freed non-pooled buffer"))
	  if (mhdr->magic == MALMAGIC_FREED)
	    ERROR_FOUND((buf, "Pointer to freed pooled buffer"))
	  ERROR_FOUND((buf, "Invalid pointer, magic number not found"))
	}
      if (mhdr->pool != expected_pool)
	ERROR_FOUND((buf, "Pointer to buffer wrom wrong pool"));
    }
  else
    {
      if (mhdr->magic != MALMAGIC_OK)
	{
	  if (mhdr->magic == MALMAGIC_FREED)
	    ERROR_FOUND((buf, "Pointer to freed buffer"))
	  if (mhdr->magic == MALPMAGIC_OK)
	    ERROR_FOUND((buf, "Pointer to pooled buffer"))
	  if (mhdr->magic == MALPMAGIC_FREED)
	    ERROR_FOUND((buf, "Pointer to freed pooled buffer"))
	  ERROR_FOUND((buf, "Invalid pointer, magic number not found"))
	}
    }
  cp = (unsigned char *) data + mhdr->size;
  if (cp[0] != 0xDE || cp[1] != 0xAD || cp[2] != 0xC0 || cp[3] != 0xDE)
    ERROR_FOUND((buf, "Area thrash detected past the end of buffer"))
  return NULL;
}

int dbg_allows_free_nulls = 0;

#ifndef USE_TLSF
void
dbg_free (const char *file, u_int line, void *data)
{
  malhdr_t *mhdr;
  malrec_t *r;
  unsigned char *cp;

  if (data == NULL)
    {
      fprintf (stderr, "WARNING: free of NULL pointer in %s (%u)\n",
	  file, line);
      _free_nulls++;
      if (0 >= dbg_allows_free_nulls)
      memdbg_abort ();
      return;
    }
  if (!_dbgmal_enabled)
    {
      FREE_WITH_DELAY (data);
      return;
    }
  mutex_enter (_dbgmal_mtx);
  mhdr = (malhdr_t *) ((u_char *) data - sizeof (malhdr_t));
  if (mhdr->magic != MALMAGIC_OK)
    {
      const char *msg = dbg_find_allocation_error (data, NULL);
      fprintf (stderr, "WARNING: free of invalid pointer in %s (%u): %s\n",
	file, line,
	 msg ? msg : "");
      _free_invalid++;
      memdbg_abort ();
      mutex_leave (_dbgmal_mtx);
      return;
    }
  mhdr->magic = MALMAGIC_FREED;
  cp = (u_char *) data + mhdr->size;
  if (cp[0] != 0xDE || cp[1] != 0xAD || cp[2] != 0xC0 || cp[3] != 0xDE)
    {
      fprintf (stderr, "WARNING: area thrash detected in %s (%u)\n",
	  file, line);
      memdbg_abort ();
      mutex_leave (_dbgmal_mtx);
      return;
    }
  _totalmem -= mhdr->size;
  r = mhdr->origin;
  r->totalsize -= mhdr->size;
  r->numfree++;

/*  if (r->numfree == r->numalloc)
    dtab_delete_record ((htrecord_t *) &r); */

  memset (mhdr + 1, 0xDD, mhdr->size); /* The header remains 'as is' to found the place where the block was allocated */
  FREE_WITH_DELAY (mhdr);
  mutex_leave (_dbgmal_mtx);
}
#endif

void
dbg_free_sized (const char *file, u_int line, void *data, size_t sz)
{
  malhdr_t *mhdr;
  malrec_t *r;
  u_char *cp;

  if (data == NULL)
    {
      fprintf (stderr, "WARNING: free of NULL pointer in %s (%u)\n",
	  file, line);
      _free_nulls++;
      memdbg_abort ();
      return;
    }
  if (!_dbgmal_enabled)
    {
      FREE_WITH_DELAY (data);
      return;
    }
  mutex_enter (_dbgmal_mtx);
  mhdr = (malhdr_t *) ((u_char *) data - sizeof (malhdr_t));
  if (mhdr->magic != MALMAGIC_OK)
    {
      const char *msg = dbg_find_allocation_error (data, NULL);
      fprintf (stderr, "WARNING: free of invalid pointer in %s (%u): %s\n",
	file, line,
	 msg ? msg : "");
      _free_invalid++;
      memdbg_abort ();
      mutex_leave (_dbgmal_mtx);
      return;
    }
  mhdr->magic = MALMAGIC_FREED;
  cp = (unsigned char *) data + mhdr->size;
  if (cp[0] != 0xDE || cp[1] != 0xAD || cp[2] != 0xC0 || cp[3] != 0xDE)
    {
      fprintf (stderr, "WARNING: area thrash detected in %s (%u)\n",
	  file, line);
      memdbg_abort ();
      mutex_leave (_dbgmal_mtx);
      return;
    }
  if ((sz != ((size_t)-1)) && ((size_t)(mhdr->size) != sz))
    {
      fprintf (stderr, "WARNING: free of area of actual size %ld with declared size %ld in %s (%u)\n",
        (long)(mhdr->size), (long)sz,
	file, line );
      _free_invalid++;
      memdbg_abort ();
      mutex_leave (_dbgmal_mtx);
      return;
    }
  _totalmem -= mhdr->size;
  r = mhdr->origin;
  r->totalsize -= mhdr->size;
  r->numfree++;

/*  if (r->numfree == r->numalloc)
    dtab_delete_record ((htrecord_t *) &r); */

  memset (mhdr + 1, 0xDD, mhdr->size); /* The header remains 'as is' to found the place where the block was allocated */
  FREE_WITH_DELAY (mhdr);
  mutex_leave (_dbgmal_mtx);
}


void
dbg_freep (const char *file, u_int line, void *data, void *pool)
{
  malhdr_t *mhdr;
  malrec_t *r;
  unsigned char *cp;

  if (data == NULL)
    {
      fprintf (stderr, "WARNING: free of NULL pointer in %s (%u)\n",
	  file, line);
      _free_nulls++;
      memdbg_abort ();
      return;
    }
  if (!_dbgmal_enabled)
    {
      FREE_WITH_DELAY (data);
      return;
    }
  mutex_enter (_dbgmal_mtx);
  mhdr = (malhdr_t *) ((u_char *) data - sizeof (malhdr_t));
  if (mhdr->magic != MALPMAGIC_OK)
    {
      const char *err = dbg_find_allocation_error (data, pool);
      if ((NULL == err) && (mhdr->magic == MALMAGIC_OK))
	err = "Pointer to valid non-pool buffer";
      if (!err)
	err = "";
      fprintf (stderr, "WARNING: free of invalid pointer in %s (%u): %s\n",
	file, line, err );
      _free_invalid++;
      memdbg_abort ();
      FREE_WITH_DELAY (data);
      mutex_leave (_dbgmal_mtx);
      return;
    }
  mhdr->magic = MALPMAGIC_FREED;
  cp = (unsigned char *) data + mhdr->size;
  if (cp[0] != 0xDE || cp[1] != 0xAD || cp[2] != 0xC0 || cp[3] != 0xDE)
    {
      fprintf (stderr, "WARNING: area thrash detected in %s (%u)\n",
	  file, line);
      memdbg_abort ();
      mutex_leave (_dbgmal_mtx);
      return;
    }
  _totalmem -= mhdr->size;
  r = mhdr->origin;
  r->totalsize -= mhdr->size;
  r->numfree++;

/*    if (r->numfree == r->numalloc)
    dtab_delete_record ((htrecord_t *) &r); */

  memset (mhdr + 1, 0xDD, mhdr->size); /* The header remains 'as is' to found the place where the block was allocated */
  FREE_WITH_DELAY (mhdr);
  mutex_leave (_dbgmal_mtx);
}


void
dbg_malstats (FILE *fd, int mode)
{
  fprintf (fd, "##########################################\n");
  fprintf (fd, "# TOTAL MEMORY IN USE      : %lu\n", (long) _totalmem);
  fprintf (fd, "# Frees of NULL pointer    : %lu\n", (long) _free_nulls);
  fprintf (fd, "# Frees of invalid pointer : %lu\n", (long) _free_invalid);
  fprintf (fd, "##########################################\n");
  switch (mode)
    {
    case DBG_MALSTATS_ALL:
      dtab_foreach (_dbgtab, 0, mal_printall, fd);
      break;
    case DBG_MALSTATS_NEW:
      dtab_foreach (_dbgtab, 0, mal_printnew, fd);
      break;
    case DBG_MALSTATS_LEAKS:
      dtab_foreach (_dbgtab, 0, mal_printoneleak, fd);
      break;
    }
  fprintf (fd, "\n\n");
}


int
dbg_mark (char *name)
{
  malrec_t xrec, *r;

  strncpy (xrec.fname, name, MALREC_FNAME_BUFLEN);
  xrec.fname[MALREC_FNAME_BUFLEN-1] = 0;
  xrec.linenum = -1;

  r = (malrec_t *) dtab_find_record (_dbgtab, 1, (htrecord_t) &xrec);

  if (r == NULL)
    {
      dtab_create_record (_dbgtab, (htrecord_t *) &r);
      strcpy (r->fname, xrec.fname);
      r->linenum = -1;
      r->numalloc = r->numfree = 0;
      r->totalsize = 0;
      dtab_add_record ((htrecord_t) r);
    }

  return ++r->numalloc;
}


int
dbg_unmark (char *name)
{
  malrec_t xrec, *r;

  strncpy (xrec.fname, name, MALREC_FNAME_BUFLEN);
  xrec.fname[MALREC_FNAME_BUFLEN-1] = 0;
  xrec.linenum = -1;

  r = (malrec_t *) dtab_find_record (_dbgtab, 1, (htrecord_t) &xrec);

  if (r != NULL)
    {
      r->numfree++;
      if (r->numfree == r->numalloc)
	{
	  dtab_delete_record ((htrecord_t *) &r);
	  return 1;
	}
      return 0;
    }

  return -1;
}

void dbg_add_dumpentry (htrecord_t rec_, void* file_)
{
  malrec_t* rec = (malrec_t*)rec_;
  if (0 != rec->totalsize)
    fprintf ((FILE*)file_, "file: %s line: %u sz: %ld\n",
	   rec->fname, rec->linenum, (long)(rec->totalsize));
}

void dbg_dump_mem()
{
  FILE* file = fopen ("xmemdump.txt","w+");
  if (file)
    {
      fprintf (file, "Starting memory dumping....\n");
      dtab_foreach (_dbgtab,0,dbg_add_dumpentry, (void*)file);
    };
  fprintf (file, "End of memory dump.\n");
  fclose (file);
}


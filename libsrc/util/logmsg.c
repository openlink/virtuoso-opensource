/*
 *  logmsg.c
 *
 *  $Id$
 *
 *  Logfile routines
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
 *  
*/

#include "libutil.h"
#include <util/listmac.h>
#include <stdarg.h>

#if defined (BUFSIZ) && (BUFSIZ < 1024)
# undef BUFSIZ
# define BUFSIZ 2048
#endif

static LOG _head;

static char *loglevels[] =
{
  "EMERG",
  "ALERT",
  "CRIT",
  "ERROR",
  "WARNING",
  "NOTICE",
  "INFO",
  "DEBUG"
};


#ifdef LOG_LIMIT_CHECK

struct logrecord
{
  int32 last;
  int32 ok;
  int count;
  int shutdown;
};

#define HTSIZE		   1024
#define LIMIT_RESTART_WAIT (60*10)

static HTTABLE *limit_ht;
static int limit_rate;

#define LIMIT_OK	0
#define LIMIT_SHUTDOWN	1
#define LIMIT_OFF	2

static int
limit_check (char *file, int line)
{
  char key[BUFSIZ];
  struct logrecord *r;
  time_t curtime = time (0);

  if (limit_ht == NULL)
    {
      if ((limit_ht = htinit (HTSIZE, 0)) == NULL)
	{
	  fprintf (stderr, "can't init logmsg hashtable\n");
	  return LIMIT_OK;
	}
    }

  if (file == NULL)
    return LIMIT_OK;

  sprintf (key, "%s%d", file, line);

  if ((r = (struct logrecord *) htgetdata (limit_ht, key)) == NULL)
    {
      if ((r = salloc (1, struct logrecord)) == NULL)
	{
	  fprintf (stderr, "can't allocate logrecord struct\n");
	  return LIMIT_OK;
	}
      htadd (limit_ht, key, (char *) r);
    }

  r->count++;

  if (r->shutdown)
    {
      if (r->last == curtime)
	return LIMIT_OFF;
      else
	{
	  r->last = curtime;
	  if (r->count / (curtime - r->ok) > limit_rate)
	    {
	      r->ok = curtime;
	      r->count = 1;
	      return LIMIT_OFF;
	    }
	  else
	    {
	      if ((curtime - r->ok) >= (int32) LIMIT_RESTART_WAIT)
		{
		  r->shutdown = 0;
		  r->count = 1;
		  return LIMIT_OK;
		}
	      else
		{
		  r->count = 1;
		  return LIMIT_OFF;
		}
	    }
	}
    }

  if (r->last == curtime)
    {
      if (r->count > limit_rate)
	{
	  r->shutdown = 1;
	  r->ok = curtime;
	  return LIMIT_SHUTDOWN;
	}
    }
  else
    {
      r->last = curtime;
      r->count = 1;
    }

  return LIMIT_OK;
}
#endif


/*
  We break this routine out from below to avoid performing
  this scan if we're not using the format string.  That is,
  the loglevel is to low to force the printout.
*/
static void
fix_format (char *format_in, char *format_out, int len, int errno_save, char *file, int line)
{
  char *f;
  char *b;
  char *b_end;
  char c;

  f = gettext (format_in);
  b = format_out;
  b_end = &format_out[len];

  while ((c = *f++) != '\0' && c != '\n' && b < b_end)
    {
      if (c != '%')
	{
	  *b++ = c;
	  continue;
	}
      c = *f++;
      switch (c)
	{
	case 'm':
	  strcpy (b, opl_strerror (errno_save));
	  b += strlen (b);
	  break;
	case 'F':
	  sprintf (b, "%s", file);
	  b += strlen (b);
	  break;
	case 'L':
	  sprintf (b, "%d", line);
	  b += strlen (b);
	  break;
	default:
	  *b++ = '%';
	  *b++ = c;
	  break;
	}
    }

  *b++ = '\n';
  *b = '\0';
}


int
logmsg_ap (int level, char *file, int line, int mask, char *format, va_list ap)
{
  LOG *log;
  char buf[BUFSIZ];
  char *bufptr;
  char formatbuf[BUFSIZ];
#ifdef LOG_LIMIT_CHECK
  int limit_stat;
#endif
  int do_fix = 1;
  int errno_save;
  struct tm *tm;
  time_t now;
  int month, day, year;
  size_t remain;
#if defined (HAVE_VA_COPY) || defined (HAVE___VA_COPY)
  va_list save_ap;
#endif
#ifdef HAVE_LOCALTIME_R
  struct tm keeptime;
#endif

  errno_save = errno;

#ifdef LOG_LIMIT_CHECK
  if ((file != NULL) && (limit_rate > 0))
    limit_stat = limit_check (file, line);
  else
    limit_stat = LIMIT_OK;

  if (limit_stat == LIMIT_OFF)
    return 0;
#endif

  if (_head.next == NULL)
    {
#if !defined(SINGLETIER)
      if (do_fix)
	{
	  fix_format (format, formatbuf, sizeof (formatbuf),
	      errno_save, file, line);
	  do_fix = 0;
	}
      vfprintf (stderr, formatbuf, ap);
#endif
      return 0;
    }

  if (level < 0)
    level = 0;
  if (level > MAX_LOG_LEVEL)
    level = MAX_LOG_LEVEL;

  time (&now);

#ifdef HAVE_LOCALTIME_R
  tm = localtime_r(&now, &keeptime);
#else
  tm = localtime (&now);
#endif

  month = tm->tm_mon + 1;
  day = tm->tm_mday;
  year = tm->tm_year + 1900;

  for (log = _head.next; log != &_head; log = log->next)
    {
      if ((mask == 0) || mask & log->mask[level])
	{
	  if (log->style & L_STYLE_GROUP)
	    {
	      if (log->day != day || log->month != month || log->year != year)
		{
		  strftime (buf, sizeof (buf), "\n\t\t%a %b %d %Y\n", tm);
		  if (log->emitter)
		    (*log->emitter) (log, level, buf);
		  log->day = day;
		  log->month = month;
		  log->year = year;
		}
	    }

	  buf[0] = 0;
	  bufptr = buf;

	  if (log->style & L_STYLE_TIME)
	    {
	      if (log->style & L_STYLE_GROUP)
		sprintf (bufptr, "%02u:%02u:%02u ",
		    tm->tm_hour, tm->tm_min, tm->tm_sec);
	      else
		sprintf (bufptr, "%02u/%02u/%04u %02u:%02u:%02u ",
		    month, day, year, tm->tm_hour, tm->tm_min, tm->tm_sec);
	      bufptr = bufptr + strlen (buf);
	    }

	  if (log->style & L_STYLE_LEVEL)
	    {
	      bufptr = stpcpy (bufptr, loglevels[level]);
	      *bufptr++ = ' ';
	    }

#ifndef _DK_H			/* not in virtuoso */
	  if (log->style & L_STYLE_PROG)
	    {
	      bufptr = stpcpy (bufptr, MYNAME);
	      *bufptr++ = ' ';
	    }
#endif

	  if ((log->style & L_STYLE_LINE) && (file != NULL))
	    {
#if 0
	      char *ptr = strrchr (file, '.');
	      if (ptr != NULL)
		*ptr = '\0';
#endif
	      sprintf (bufptr, "(%s:%d) ", file, line);
	      bufptr += strlen (bufptr);
	    }

#ifdef LOG_LIMIT_CHECK
	  if (limit_stat == LIMIT_SHUTDOWN)
	    bufptr = stpcpy (bufptr, "EXCESSIVE MESSAGES ");
#endif

	  if (bufptr != buf &&
	      (log->style & (L_STYLE_LINE | L_STYLE_PROG | L_STYLE_LEVEL)))
	    {
	      bufptr[-1] = ':';
	      *bufptr++ = ' ';
	    }

	  if (do_fix)
	    {
	      fix_format (format, formatbuf, sizeof (formatbuf),
		  errno_save, file, line);
	      do_fix = 0;
	    }

	  /*
	   *  Calculate remaining length in buf
	   */
	  remain = sizeof (buf) - (bufptr - &buf[0]);

	  /* 
 	   *  Corrects bug on various systems 
	   *  va_list is modified after use :-(
	   */
#if defined (HAVE_VA_COPY)
#define AP save_ap
	  va_copy (save_ap, ap);
#elif defined (HAVE___VA_COPY)
#define AP save_ap
	  __va_copy (save_ap, ap);
#else
#define AP ap
#endif

#if defined (WIN32)
	  _vsnprintf (bufptr, remain, formatbuf, AP);
#elif defined (HAVE_VSNPRINTF)
	  vsnprintf (bufptr, remain, formatbuf, AP);
#else
	  vsprintf (bufptr, formatbuf, AP);
#endif

#if defined (HAVE_VA_COPY) || defined (HAVE___VA_COPY)
#undef AP
	  va_end (save_ap);
#endif

	  if (log->emitter)
	    (*log->emitter) (log, level, buf);
	}
    }

  return 0;
}


int
logmsg (int level, char *file, int line, int mask, char *format, ...)
{
  va_list ap;
  int rc;

  va_start (ap, format);
  rc = logmsg_ap (level, file, line, mask, format, ap);
  va_end (ap);

  return rc;
}


int
log_error (char *format, ...)
{
  va_list ap;
  int rc;

  va_start (ap, format);
  rc = logmsg_ap (LOG_ERR, NULL, 0, 1, format, ap);
  va_end (ap);

  return rc;
}


int
log_warning (char *format, ...)
{
  va_list ap;
  int rc;

  va_start (ap, format);
  rc = logmsg_ap (LOG_WARNING, NULL, 0, 1, format, ap);
  va_end (ap);

  return rc;
}


int
log_info (char *format, ...)
{
  va_list ap;
  int rc;

  va_start (ap, format);
  rc = logmsg_ap (LOG_INFO, NULL, 0, 1, format, ap);
  va_end (ap);

  return rc;
}


int
log_debug (char *format, ...)
{
  va_list ap;
  int rc;

  va_start (ap, format);
  rc = logmsg_ap (LOG_DEBUG, NULL, 0, 1, format, ap);
  va_end (ap);

  return rc;
}


int
log (int level, char *file, int line, char *format, ...)
{
  va_list ap;
  int rc;

  va_start (ap, format);
  rc = logmsg_ap (level, file, line, 1, format, ap);
  va_end (ap);

  return rc;
}


#ifdef LOG_LIMIT_CHECK
int
log_set_limit (int rate)
{
  limit_rate = rate;

  return 0;
}


static int
reset_limits (ITEM data, ITEM key, ITEM usr)
{
  ((struct logrecord *)data)->shutdown = 0;

  return 0;
}


int
log_reset_limits (void)
{
  if (limit_ht != NULL)
    htmap (limit_ht, reset_limits, 0);

  return 0;
}
#endif


int
log_set_mask (LOG * log, int level, int mask)
{
  int i;

  if (level < 0)
    level = 0;

  if (level > MAX_LOG_LEVEL)
    level = MAX_LOG_LEVEL;

  for (i = 0; i <= level; i++)
    log->mask[i] |= mask;

  for (i = level + 1; i <= MAX_LOG_LEVEL; i++)
    log->mask[i] &= ~mask;

  return 0;
}


int
log_set_level (LOG * log, int level)
{
  return log_set_mask (log, level, -1);
}


static LOG *
add_log (int level, int mask, int style)
{
  LOG *log;

  if (_head.next == NULL)
    {
      LISTINIT (&_head, next, prev);
    }

  if ((log = (LOG *) calloc (1, sizeof (LOG))) == NULL)
    return NULL;

  log->style = style;
  log->month = 0;
  log->day = 0;
  log->year = 0;
  log->emitter = NULL;
  log->closer = NULL;

  log_set_mask (log, level, mask);

  LISTPUTAFTER (&_head, log, next, prev);

  return log;
}


LOG *
log_open_callback (log_emit_func emitter, log_close_func closer,
    int level, int mask, int style)
{
  LOG *log;

  if ((log = add_log (level, mask, style)) == NULL)
    return NULL;

  log->emitter = emitter;
  log->closer = closer;

  return log;
}


static void
file_emit (LOG *log, int level, char *msg)
{
  FILE *fp = (FILE *) log->user_data;

  if (fp)
    {
      fputs (msg, fp);
      fflush (fp);
    }
}


static void
file_close (LOG *log)
{
  FILE *fp = (FILE *) log->user_data;

  if (fp)
    fclose (fp);
}


static void
syslog_emit (LOG *log, int level, char *msg)
{
#ifdef HAVE_SYSLOG
  syslog (level, "%s", msg);
#endif
}


static void
syslog_close (LOG *log)
{
#ifdef HAVE_SYSLOG
  closelog ();
#endif
}


LOG *
log_open_syslog (char *ident, int logopt, int facility, int level, int mask, int style)
{
  LOG *log;

  log = log_open_callback (syslog_emit, syslog_close, level, mask, style);
  if (log == NULL)
    return NULL;

#ifdef HAVE_SYSLOG
  openlog (ident, logopt, facility);
#endif

  return log;
}


LOG *
log_open_fp (FILE * fp, int level, int mask, int style)
{
  LOG *log;

  log = log_open_callback (file_emit, file_close, level, mask, style);
  if (log == NULL)
    return NULL;

  log->user_data = fp;

  return log;
}


LOG *
log_open_fp2 (FILE * fp, int level, int mask, int style)
{
  LOG *log;

  log = log_open_callback (file_emit, NULL, level, mask, style);
  if (log == NULL)
    return NULL;

  log->user_data = fp;

  return log;
}


LOG *
log_open_file (char *filename, int level, int mask, int style)
{
  FILE *fp;
  LOG *log;

  if ((fp = fopen (filename, "a")) == NULL)
    return NULL;

  log = log_open_callback (file_emit, file_close, level, mask, style);
  if (log == NULL)
    {
      fclose (fp);
      return NULL;
    }

  log->user_data = fp;

  return log;
}


int
log_close (LOG * log)
{
  if (log->closer)
    (*log->closer) (log);

  LISTDELETE (log, next, prev);

  return 0;
}


void
log_close_all (void)
{
  LOG *log;
  LOG *next;

  if (_head.next == NULL)
    return;

  for (log = _head.next; log != &_head; log = next)
    {
      next = log->next;
      log_close (log);
    }
}


int
log_parse_mask (char *mask_str, LOGMASK_ALIST * alist, int size, int *maskp)
{
  char name[BUFSIZ];
  char *namep = name;
  char *ptr = mask_str;
  int i;

  *maskp = 0;

  for (;;)
    {
      /*
        Mask lists have symbolic mask names separated by commas.
      */
      if ((*ptr == ',') || (*ptr == '\0'))
	{
	  /*
           *  Process the last entry we found by searching the mask
           *  alist for a match, and oring in the bit pattern.
           */
	  *namep = '\0';
	  for (i = 0; i < size; i++)
	    {
	      if (strcmp (name, alist[i].name) == 0)
		{
		  *maskp |= alist[i].bit;
		  goto ok;
		}
	    }
	  return -1;
	ok:
	  namep = name;
	}
      else
	*(namep++) = *ptr;

      if (*ptr == '\0')
	return 0;

      ptr++;
    }
}


void
log_flush_all (void)
{
}

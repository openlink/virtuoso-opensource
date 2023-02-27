/*
 *  Dkutil.c
 *
 *  $Id$
 *
 *  Helper functions
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2023 OpenLink Software
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

#include "Dk.h"

#if defined(HAVE_EXECINFO_H)

#include <execinfo.h>

#define N_FRAMES 100

void
print_trace (void)
{
  void *array[N_FRAMES];
  size_t size, i;
  char **strings;

  size = backtrace (array, N_FRAMES);
  strings = backtrace_symbols (array, size);
  for (i = 0; i < size; i++)
    log_info ("%s\n", strings[i]);
#ifndef MALLOC_DEBUG
  free (strings);
#endif
}
#else
void print_trace (void) { }
#endif

int
gpf_notice (const char *file, int line, const char *text)
{
#ifdef DEBUG
  FILE *core_reason;
#endif
  print_trace ();
#if defined (PMN_LOG) && defined (NOT_DEFINED)
  /* XXX - first resolve libutil conflicts */
  if (text)
    log_out (LOG_EMERG, file, line, "internal error: %s", text);
  else
    log_out (LOG_EMERG, file, line, "internal error");
#else
  if (text)
    dk_report_error ("GPF: %s:%d %s\n", file, line, text);
  else
    dk_report_error ("GPF: %s:%d internal error\n", file, line);
  fflush (stdout);
  if (text)
    fprintf (stderr, "GPF: %s:%d %s\n", file, line, text);
  else
    fprintf (stderr, "GPF: %s:%d internal error\n", file, line);
  fflush (stderr);
#ifdef DEBUG
  core_reason = fopen ("core_reason", "wt");
  if (text)
    fprintf (core_reason, "GPF: %s:%d %s\n", file, line, text);
  else
    fprintf (core_reason, "GPF: %s:%d internal error\n", file, line);
  fclose (core_reason);
#endif
#endif
  *(long *) -1 = -1;

  call_exit (1);

  exit(1);
}


void
get_real_time (timeout_t * to)
{
#if defined (WIN32)
  FILETIME ft;
  uint64 res = 0;

  GetSystemTimeAsFileTime (&ft);

  res |= ft.dwHighDateTime;
  res <<= 32;
  res |= ft.dwLowDateTime;

  /* converting file time to Unix epoch 1970/1/1 */
  res -= 116444736000000000ULL;	/* ticks between 1601 and 1970 year */
  res /= 10;			/* convert into microseconds */

  to->to_sec = (uint32) (res / 1000000ULL);
  to->to_usec = (int32) (res % 1000000ULL);
#else
  struct timeval tv;

  gettimeofday (&tv, NULL);

  to->to_sec = tv.tv_sec;
  to->to_usec = tv.tv_usec;
#endif
}


time_msec_t time_now_msec;

time_msec_t
approx_msec_real_time (void)
{
  return time_now_msec;
}



time_msec_t
get_msec_real_time (void)
{
  int done = 0;
  time_msec_t now_msec = 0;

#if defined (WIN32)
  /*
   *  Use QueryPerformanceCounter for current versions of Windows
   */
  if (!done)
    {
      timeout_t time_now;
      LARGE_INTEGER count;
      static LARGE_INTEGER freq;
      static int initialized = 0;

      if (!initialized)
	{
	  QueryPerformanceFrequency (&freq);
	  initialized = 1;
	}

      if (freq.QuadPart > 0 && QueryPerformanceCounter (&count))
	{
	  time_now.to_sec = (time_t) (count.QuadPart / freq.QuadPart);
	  time_now.to_usec = (int) ((count.QuadPart % freq.QuadPart) * 1000000 / freq.QuadPart);

	  now_msec = (time_msec_t) time_now.to_sec * 1000 + (time_now.to_usec + 500) / 1000;
	  done = 1;
	}
    }
#endif

#if defined (HAVE_CLOCK_GETTIME)
  /*
   *  Use clock_gettime which works on Linux/macOS/FreeBSD
   */
  if (!done)
    {
      struct timespec ts;
      int have_clock_gettime = 1;

#if defined (CLOCK_MONOTONIC_FAST)
      clockid_t cop = CLOCK_MONOTONIC_FAST;	/* FreeBSD */
#else
      clockid_t cop = CLOCK_MONOTONIC;	/* Linux and macOS */
#endif

#if defined (__APPLE__)
      have_clock_gettime = 0;
      if (__builtin_available (macOS 10.12, iOS 10, tvOS 10, watchOS 3, *))
	have_clock_gettime = 1;
#endif

      if (have_clock_gettime && clock_gettime (cop, &ts) == 0)
	{
	  now_msec = (time_msec_t) ts.tv_sec * 1000ULL + (ts.tv_nsec + 500000ULL) / 1000000ULL;
	  done = 1;
	}
    }
#endif

  /*
   *  Fallback if any of the above fail
   */
  if (!done)
    {
      timeout_t time_now;

      get_real_time (&time_now);

      now_msec = (time_msec_t) time_now.to_sec * 1000 + (time_now.to_usec + 500) / 1000;
    }

  /* 
   *  Finally return the value
   */
  return time_now_msec = now_msec;
}


void
time_add (timeout_t * time1, timeout_t * time2)
{
  time1->to_sec = time1->to_sec + time2->to_sec;
  time1->to_usec = time1->to_usec + time2->to_usec;
/*  if (time1->to_usec >= 1000000) { mty MAALIS */
  if (time1->to_usec >= 1000)
    {
      time1->to_sec++;
/*    time1->to_usec =- 1000000; */
      time1->to_usec -= 1000;			 /* mty MAALIS */
    }
}


int
time_gt (timeout_t * time1, timeout_t * time2)
{
  if (time1->to_sec > time2->to_sec)
    return 1;
  else if (time1->to_sec == time2->to_sec)
    return time1->to_usec > time2->to_usec;
  else
    return 0;
}


char * dk_strdup (char * s)
{
  return s ? box_dv_short_string (s) : NULL;
}

#include "util/strfuns.h"


char *
dk_cslentry (const char *list, int idx)
{
  char *start;
  size_t length;

  if (!list || !list[0] || !idx)
    return NULL;

  for (--idx; idx && *list; idx--)
    {
      if ((list = strchr (list, ',')) == NULL)
	return NULL;
      list++;
    }
  start = (char *) ltrim (list);
  if ((list = strchr (start, ',')) == NULL)
    length = strlen (start);
  else
    length = (u_int) (list - start);

  if ((start = dk_strdup (start)) != NULL)
    {
      start[length] = 0;
      rtrim (start);
    }

  return start;
}

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
 *  Copyright (C) 1998-2015 OpenLink Software
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

#if defined(linux) || defined (__APPLE__)
#include <execinfo.h>

void
print_trace (void)
{
#define N_FRAMES 100 
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
  return 0;
}


void
get_real_time (timeout_t * to)
{
#if defined (WIN32)
#if 0
  static DWORD prec_nsec = 0, dummy;
  static BOOL b1;

  if (prec_nsec == 0)
    GetSystemTimeAdjustment (&dummy, &prec_nsec, &dummy);

  to->to_sec = time (NULL);

  if (prec_nsec)
    to->to_usec = (((long) (GetTickCount () / (prec_nsec * 10))) * (prec_nsec * 10)) % 1000;
  else
    to->to_usec = GetTickCount () % 1000;
#else
  ULARGE_INTEGER tim;
  GetSystemTimeAsFileTime ((FILETIME *) & tim);	 /* 100ns ticks since Jan 1, 1601 */
  tim.QuadPart -= 0x19DB1DED53E8000L;		 /* ticks between 1601 and 1970 year */
  tim.QuadPart /= 10;				 /* convert to microseconds */
  to->to_usec = (int32) (tim.QuadPart % 1000000);	/* microseconds */
  to->to_sec = (int32) (tim.QuadPart / 1000000); /* seconds */
#endif
#else
  struct timeval tv;
  gettimeofday (&tv, NULL);
  to->to_sec = tv.tv_sec;
  to->to_usec = tv.tv_usec;
#endif
}


static timeout_t boot_time;
uint32 last_approx_msec_real_time;

long
approx_msec_real_time (void)
{
/*  return (time_now.to_sec * 1000 + time_now.to_usec / 1000); */
  static timeout_t ret;

  if (boot_time.to_sec == 0)
    {
      get_real_time (&boot_time);
      return 0;
    }
  if (time_now.to_usec >= boot_time.to_usec)
    {
      ret.to_sec = time_now.to_sec - boot_time.to_sec;
      ret.to_usec = time_now.to_usec - boot_time.to_usec;
    }
  else
    {
      ret.to_sec = time_now.to_sec - boot_time.to_sec - 1;
      ret.to_usec = time_now.to_usec + 1000000 - boot_time.to_usec;
    }
  return last_approx_msec_real_time = ret.to_sec * 1000 + (ret.to_usec + 500) / 1000;
}


long
get_msec_real_time (void)
{
#if 0
  struct timezone tz;
  struct timeval time;
  gettimeofday (&time, &tz);
  return ((time.tv_sec * 1000) + (time.tv_usec / 1000));
#endif

  get_real_time (&time_now);
  time_now_msec = time_now.to_sec * 1000 + time_now.to_usec / 1000;
  return approx_msec_real_time ();
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

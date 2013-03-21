/*
 *  timeacct.h
 *
 *  $Id$
 *
 *  Timing macros and functions
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2013 OpenLink Software
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

#ifdef __cplusplus
extern "C" {
#endif

#ifdef WIN32
#define get_msec_count GetTickCount
#define get_msec_real_time GetTickCount
#else
long get_msec_count(void);
#endif

#define TA_ON 1
#define TA_OFF 2
#define TA_DISABLED 3

typedef struct timeacctstr {
  int      ta_is_on;
  char *   ta_name;
  long     ta_n_samples;
  long     ta_total;
  long     ta_max;
  long     ta_min;
  long     ta_entry_time;
  long     ta_init_time;
} timer_account_t;


void ta_print_out (FILE * out, timer_account_t * ta);


void ta_init (timer_account_t * ta, char * n);
void ta_enter (timer_account_t * ta);
void ta_leave (timer_account_t * ta);
void ta_add_sample (timer_account_t * ta, long this_time);
void ta_disable (timer_account_t * ta);
void set_rnd_seed (long seedval);
long rnd (void);
long random_1 (long scale);

extern long rnd_seed;


#ifdef LOW_ORDER_FIRST

#define REV_LONG(l) \
  ((((unsigned long)l) >> 24) |              \
   (((unsigned long)l & 0x00ff0000 ) >> 8) |  \
   (((unsigned long)l & 0x0000ff00 ) << 8) |  \
   (((unsigned long)l) << 24) )


#define TV_TO_STRING(tv) \
  (tv) -> tv_sec = REV_LONG ((tv) -> tv_sec), (tv) -> tv_usec = REV_LONG ((tv) -> tv_usec)

#define STRING_TO_TV(tv) TV_TO_STRING(tv)

#else

#define TV_TO_STRING(tv)
#define STRING_TO_TV(tv)

#endif


#define gettimestamp(ts) \
{ \
  gettimeofday ((struct timeval *) ts, NULL); \
  TV_TO_STRING ( (struct timeval *)  ts)  ; \
}


#ifdef __cplusplus
}
#endif

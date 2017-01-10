/*
 *  time.c
 *
 *  $Id$
 *
 *  Timing functions
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

#include <stdio.h>
#include <memory.h>

#ifdef UNIX
#include <time.h>
#include <sys/time.h>
#endif

#ifdef WIN32
#include <windows.h>
#include <time.h>
#endif

#include "timeacct.h"



void
ta_disable (timer_account_t * ta)
{
  ta->ta_is_on = TA_DISABLED;
}


void
ta_init (timer_account_t * ta, char *name)
{
  if (ta->ta_is_on == TA_DISABLED)
    return;
  memset (ta, 0, sizeof (timer_account_t));
  ta->ta_name = name;
  ta->ta_min = 0xfffffff;
  ta->ta_init_time = get_msec_count ();
  ta->ta_is_on = TA_ON;
}


void
ta_enter (timer_account_t * ta)
{
  if (ta->ta_is_on == TA_ON) {
    ta->ta_entry_time = get_msec_count ();
  }
}


void
ta_leave (timer_account_t * ta)
{
  if (ta->ta_is_on == TA_ON)
    {
      long this_time = get_msec_count () - ta->ta_entry_time;
      ta->ta_total += this_time;
      if (this_time > ta->ta_max)
	ta->ta_max = this_time;
      if (this_time < ta->ta_min)
	ta->ta_min = this_time;
      ta->ta_n_samples++;
    }
}


void
ta_add_sample (timer_account_t * ta, long this_time)
{
  if (ta->ta_is_on == TA_ON)
    {
      ta->ta_total += this_time;
      if (this_time > ta->ta_max)
	ta->ta_max = this_time;
      if (this_time < ta->ta_min)
	ta->ta_min = this_time;
      ta->ta_n_samples++;
    }
}


void
ta_print_out (FILE * out, timer_account_t * ta)
{
  if (!ta->ta_is_on == TA_ON)
    return;
  if (ta->ta_n_samples > 0)
    {
      long time_now = get_msec_count ();
      if (time_now != ta->ta_init_time)
	fprintf (out, "-- %-26s  %5ld / %3ld / %5ld     %7ld  %ld%%  %ld times\n",
		 ta->ta_name, ta->ta_min, ta->ta_total / ta->ta_n_samples, ta->ta_max,
		 ta->ta_total, (100 * ta->ta_total) / (time_now - ta->ta_init_time),
		 ta->ta_n_samples);
      else
	fprintf (out, "%s No time elapsed\n", ta->ta_name);
    }
  else
    {
      fprintf (out, "%s  no samples\n", ta->ta_name);
    }
}

#if defined (GUI)
void
ta_print_buffer(char *szOut, timer_account_t *ta)
{
  if (!ta->ta_is_on == TA_ON)
    return;
  if (ta->ta_n_samples > 0)
    {
      long time_now = get_msec_count ();
      sprintf (szOut, "-- %-26s  %5ld / %3ld / %5ld     %7ld  %ld%%  %ld times\n",
	  ta->ta_name, ta->ta_min, ta->ta_total / ta->ta_n_samples, ta->ta_max,
	  ta->ta_total, (100 * ta->ta_total) / (time_now - ta->ta_init_time),
	  ta->ta_n_samples);
    }
  else
    {
      sprintf (szOut, "%s  no samples\n", ta->ta_name);
    }
}
#endif

#if defined (WIN32)

void
gettimeofday (struct timeval *tv, struct timezone *tz)
{
  long tics = GetTickCount ();
  static struct timeval last_tv;
  tv->tv_sec = tics / 1000;
  tv->tv_usec = (tics % 1000) * 1000;
  if (last_tv.tv_sec == tv->tv_sec && last_tv.tv_usec == tv->tv_usec)
    tv->tv_usec++;
  /* if this is within the same msec as last call, add an usec to
     keep returning a rising series */
  last_tv = *tv;
}

#endif


#ifndef WIN32

long
get_msec_count ()
{
  struct timeval time;
  gettimeofday (&time, NULL);
  return ((time.tv_sec * 1000) + (time.tv_usec / 1000));
}

#endif


/* Random function
   TODO Probably make this a bif (PmN) */

/* This alg uses a prime modulus multiplicative congruential generator
   (PMMLCG), also known as a Lehmer Grammar, which satisfies the following
   properties

   (i)	 modulus: m - a large prime integer
   (ii)  multiplier: a - an integer in the range 2, 3, ..., m - 1
   (iii) z[n+1] = f(z[n]), for n = 1, 2, ...
   (iv)  f(z) = az mod m
   (v)	 u[n] = z[n] / m, for n = 1, 2, ...

   The sequence of z's must be initialized by choosing an initial seed
   z[1] from the range 1, 2, ..., m - 1.  The sequence of z's is a pseudo-
   random sequence drawn without replacement from the set 1, 2, ..., m - 1.
   The u's form a pseudo-random sequence of real numbers between (but not
   including) 0 and 1.

   Schrage's method is used to compute the sequence of z's.
   Let m = aq + r, where q = m div a, and r = m mod a.
   Then f(z) = az mod m = az - m * (az div m) = = gamma(z) + m * delta(z)
   Where gamma(z) = a(z mod q) - r(z div q)
   and	 delta(z) = (z div q) - (az div m)

   If r < q, then for all z in 1, 2, ..., m - 1:
   (1) delta(z) is either 0 or 1
   (2) both a(z mod q) and r(z div q) are in 0, 1, ..., m - 1
   (3) absolute value of gamma(z) <= m - 1
   (4) delta(z) = 1 iff gamma(z) < 0

   Hence each value of z can be computed exactly without overflow as long
   as m can be represented as an integer.

   a good random number generator, correct on any machine with 32 bit
   integers, this algorithm is from:

   Stephen K. Park and Keith W. Miller,
   "Random Number Generators: Good ones are hard to find",
   Communications of the ACM, October 1988, vol 31, number 10, pp. 1192-1201.

   If this algorithm is implemented correctly, then if z[1] = 1, then
   z[10001] will equal 1043618065
*/
#ifdef UNIX
# include <unistd.h>		/* for getpid */
#endif

#define RNG_M 2147483647L  /* m = 2^31 - 1 */
#define RNG_A 16807L
#define RNG_Q 127773L	   /* m div a */
#define RNG_R 2836L	   /* m mod a */

/* 32 bit seed */
long rnd_seed;


/* set seed to value between 1 and m-1 */
void
set_rnd_seed (long seedval)
{
  rnd_seed = (seedval % (RNG_M - 1)) + 1;
}


/* returns a pseudo-random number from set 1, 2, ..., RNG_M - 1 */
long
rnd (void)
{
  long hi, lo;

  if (!rnd_seed || rnd_seed == RNG_M)
#ifdef WIN32
    rnd_seed = ((long) GetTickCount () << 16) ^ (long) time (NULL);
#else
    rnd_seed = ((long) getpid () << 16) ^ (long) time (NULL);
#endif

  hi = rnd_seed / RNG_Q;
  lo = rnd_seed % RNG_Q;
  if ((rnd_seed = RNG_A * lo - RNG_R * hi) <= 0)
    rnd_seed += RNG_M;

  return rnd_seed;
}


long
random_1 (long n)
{
  return (rnd () %n);
}

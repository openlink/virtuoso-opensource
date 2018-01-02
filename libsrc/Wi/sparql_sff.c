/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2018 OpenLink Software
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

#include "sparql2sql.h"
#include "sqlparext.h"
#include "arith.h"
#include "sqlcmps.h"
#include "http.h" /* for DKS_ESC_CHARCLASS_ACTION and DKS_ESC_URI */
#ifdef __cplusplus
extern "C" {
#endif
#include "sparql_p.h"
#ifdef __cplusplus
}
#endif


int
sprintff_is_proven_bijection (const char *f)
{
  const char *tail = f;
  while ('\0' != tail[0])
    {
      char next;
      char fmt_type;
      if ('%' != tail[0])
        {
          tail += 1;
          continue;
        }
      if ('%' == tail[1])
        {
          tail += 2;
          continue;
        }
      if ('{' == tail[1])
        {
          tail += 2;
          while (isalnum ((unsigned char) (tail[0])) || ('_' == tail[0])) tail++;
          if ('}' != tail[0])
            return 0; /* Syntax error in placeholder for connection variable so the bijection is not proven */
          if (NULL == strchr ("Us", tail[1]))
            return 0; /* Unknown format so the bijection is not proven */
          tail += 2;
          continue;
        }
      tail++;
      if (NULL == strchr ("DUdgusc", tail[0]))
        return 0; /* Unknown format so the bijection is not proven */
      fmt_type = tail[0];
      tail++;
      if ('c' == fmt_type)
        continue;
      if ('%' != tail[0])
        next = tail[0];
      else if ('%' == tail[1])
        next = '%';
      else
        return 0; /* Can't read two concatenated formats if the first one is not '%c' */
      switch (fmt_type)
        {
          case 'D':
            if (isdatechar (next))
              return 0;
            continue;
          case 'd': case 'u':
            if (isdigit (next))
              return 0;
            continue;
          case 'U':
            if (isplainURIchar (next) || (next & ~ 0x7F))
              return 0;
            continue;
          case 'g':
            if (isfloatchar (next))
              return 0;
            continue;
        }
    }
  return 1;
}

int
sprintff_is_proven_unparseable (const char *f)
{
  const char *tail = f;
  const char *tail_after_prev_format = NULL;

  while ('\0' != tail[0])
    {
      char fmt_type;
      char left_fmt_type;
      if ('%' != tail[0])
        {
          tail += 1;
          continue;
        }
      if ('%' == tail[1])
        {
          tail += 2;
          continue;
        }
      if (tail == tail_after_prev_format)
        left_fmt_type = tail_after_prev_format[-1];
      else
        left_fmt_type = '\0';
      if ('{' == tail[1])
        {
          tail += 2;
          while (isalnum ((unsigned char) (tail[0])) || ('_' == tail[0])) tail++;
          if ('}' != tail[0])
            return 1; /* Syntax error in placeholder for connection variable so it's proven to be unparseable */
          if (NULL == strchr ("Us", tail[1]))
            return 1; /* Unknown format so that is unparseable */
          tail += 2;
          continue;
        }
      tail++;
      if (NULL == strchr ("DUduscg", tail[0]))
        return 1; /* Unknown format so the format is unparseable OR the filed has modifiers for length and the like */
      fmt_type = tail[0];
      tail++;
      tail_after_prev_format = tail;
      if ('\0' == left_fmt_type)
        continue; /* If formats are not adjacent then there's a possibility that ht is bijection for some data */
      if ('c' == left_fmt_type)
        continue; /* Single char is always OK because the size is fixed, can't "eat" more than needed */
      if ('s' == left_fmt_type)
        return 1; /* %s at left can not be a bijection */
      if (('U' == left_fmt_type) && ('s' != fmt_type))
        return 1; /* %U can eat anything except unescaped chars like '/' that might be printed by '%s' */
      if ('u' == fmt_type)
        return 1; /* Any character %u can eat is good for any format at left */
      if ('D' == fmt_type)
        return 1; /* Any character %D can eat as first character is good for any format at left */
      if ('g' == fmt_type)
        return 1; /* Any character %D can eat as first character is good for any format at left */
   }
  return 0;
}

#define SFF_ISECT_OK 0		/*!< A nonempty intersection may exists */
#define SFF_ISECT_DISJOIN -1	/*!< An intersection is empty */
#define SFF_ISECT_DIFF_END -2	/*!< An intersection is empty and any backtracking on tails of these formats by skipping variables is useless due to difference in fixed chars after last vars */

#define SFF_MAX_DEPTH 20	/*!< Maximum allowed recursion depth in sff_isect. Twenty is OK for all applications I could imagine */

static const char *full_f1 = NULL;
static const char *full_f2 = NULL;
static char *full_res_buf = NULL;

#ifdef SSF_WEIGHTED_ISECT
!!! Should not be used because it does not support %{connvarname}U in format strings and is poorly tested so it is probably buggy

static const char *full_f1_end = NULL;
static const char *full_f2_end = NULL;
static char *full_res_buf_end = NULL;

static int
sff_weight (const char *f1, const char *f1_end)
{
  int weight = 0;
  const char *f1_var_end;

again:
  if (f1 == f1_end)
    return weight;
  if ('%' != f1[0]) { f1++; weight += 8; goto again; }
  for (f1 += 2; f1 < f1_end; f1++)
    {
      int f1_v = f1 [-1];
      weight += 2;
      if (isalpha (f1_v) || ('%' == f1_v))
        break;
    }
  goto again;
}

/*! This function gets two sprintf_format strings \c f1 and \c f2.
It writes to \c res_buf a format string such that it can be used for printing
any text that can be printed both using \c f1 and using \c f2
(with appropriate trailing sprintf data).
The function returns positive weight (i.e. quality) of the intersection format, negative value nonzero if \c f1 and \c f2 are proven to be 'disjoint'
so no one string can be printed using both of them. */
static int
sff_weighted_isect (const char *f1, const char *f1_end, const char *f2, const char *f2_end, char *res_buf, int depth)
{
  char fmt;
  const char *f1_var, *f1_var_end, *f1_rest, *f1_aux;
  const char *f2_var, *f2_var_end, *f2_rest, *f2_aux;
  char f1_v, f2_v, f1_fix, f2_fix;
  int weight = 0;
#ifndef NDEBUG
  char *res_buf_at_begin = res_buf;
  memset (res_buf, 0, full_res_buf_end - res_buf);
#endif
  depth++;
again:
#ifndef NDEBUG
  if ((f1_end < f1) || (f2_end < f2) || ((f2_end >= f1) && (f2 <= f1_end)))
    GPF_T1 ("Mess in f1..f1_end and f2..f2_end");
  if ((res_buf < full_res_buf) || ((res_buf + (f1_end - f1) + (f2_end - f2)) > full_res_buf_end))
    GPF_T1 ("Mess in full_res_buf..full_res_buf_end");
  if (((f1 < full_f1) || (f1_end > full_f1_end) || (f2 < full_f2) || (f2_end > full_f2_end)) &&
    ((f1 < full_f2) || (f1_end > full_f2_end) || (f2 < full_f1) || (f2_end > full_f1_end)) )
    GPF_T1 ("Mess in full_fA..fB..fB_end..full_fA_end and full_fC..fD..fD_end..full_fC_end");
#endif
  if ((f1 < f1_end) && (f2 < f2_end) && (f1[0] == f2[0]) && ('%' != f1[0]))
    {
      (res_buf++)[0] = f1[0]; f1++; f2++;
      weight += 32; /* Starting chars weight a lot: 8 bit in f1 + 8 bit in f2 ; bonus 2 */
      goto again; /* see above */
    }
  if ((f1 == f1_end) && (f2 == f2_end))
    {
      res_buf[0]  = '\0';
      return weight; /* Reached end of both formats */
    }
  for (f1_var = f1; ((f1_var < f1_end) && ('%' != f1_var[0])); f1_var++) { /* no-op */; }
  for (f2_var = f2; ((f2_var < f2_end) && ('%' != f2_var[0])); f2_var++) { /* no-op */; }

  if ((f1_var > f1) && (f2_var > f2))
    {
      if ((f1_var == f1_end) && (f2_var == f2_end))
        {
          int mindist = MIN (f1_var - f1, f2_var - f2);
          if ((mindist > 0) && memcmp (f1_end - mindist, f2_end - mindist, mindist))
            return SFF_ISECT_DIFF_END;
        }
      return SFF_ISECT_DISJOIN; /* Two different nonempty strings of fixed */
    }
  if ((f1_var == f1_end) && (f2_var == f2_end))
    return SFF_ISECT_DISJOIN;  /* Two different possibly empty strings of fixed, both at right ends */

  if ((f1_var == f1) && (f1_var < f1_end-1))
    {
      for (f1_var_end = f1_var+2; (f1_var_end < f1_end); f1_var_end++)
        {
          f1_v = f1_var_end [-1];
          if (isalpha (f1_v) || ('%' == f1_v))
            break;
        }
      for (f1_rest = f1_var_end; ((f1_rest < f1_end) && ('%' != f1_rest[0])); f1_rest++) { /* no-op */; }
    }
  else
    {
      f1_rest = f1_var_end = f1_var;
      f1_v = '\0';
    }

  if ((f2_var == f2) && (f2_var < f2_end-1))
    {
      for (f2_var_end = f2_var+2; (f2_var_end < f2_end); f2_var_end++)
        {
          f2_v = f2_var_end [-1];
          if (isalpha (f2_v) || ('%' == f2_v))
            break;
        }
      for (f2_rest = f2_var_end; ((f2_rest < f2_end) && ('%' != f2_rest[0])); f2_rest++) { /* no-op */; }
    }
  else
    {
      f2_rest = f2_var_end = f2_var;
      f2_v = '\0';
    }

/* Now it's time to do optimized left-hand searches */

if (('%' == f1_v) && ('%' == f2_v))
  {
    (res_buf++)[0] = '%'; (res_buf++)[0] = '%';
    f1 = f1_var_end; f2 = f2_var_end;
    weight += 32;
    goto again;
  }

if (('d' == f1_v) && (f1_var_end < f1_rest) && !isdigit (f1_var_end[0]) && ('-' != f1_var_end[0]))
  {
    f2_aux = f2;
    if ((f2_aux < f2_var-1) && ('-' == f2_aux[0]) && isdigit (f2_aux[1]))
      f2_aux += 2;
    while ((f2_aux < f2_var) && isdigit (f2_aux[0])) f2_aux++;
    if ((f2_aux < f2_var) && !(('-' == f2_aux[0]) && (f2_aux == f2) && (f2_aux == f2_var-1)))
      {
        if (f2_aux[0] != f1_var_end[0])
          return SFF_ISECT_DISJOIN; /* First char of the f1 rest does not match first char after f2 digits (if any) */
        if (f2_aux == f2)
          return SFF_ISECT_DISJOIN; /* %d can not match to the empty space between f1 and a non-digit */
      }
    if (f2_aux > f2)
      {
        weight += 8 * (f2_aux - f2);
        while (f2 < f2_aux) (res_buf++)[0] = (f2++)[0];
        if (f2_var == f2_end)
          {
            weight += 4 * (f1_var_end - f1_var);
            f1 = f1_var_end;
          }
        goto again;
      }
  }

default_action:
  do {
      int w1 = sff_weight (f1, f1_end);
      int w2 = sff_weight (f2, f2_end);
      if (w1 > w2)
        {
          memcpy (res_buf, f1, f1_end - f1);
          res_buf [f1_end - f1] = '\0';
          return w1;
        }
      else
        {
          memcpy (res_buf, f2, f2_end - f2);
          res_buf [f2_end - f2] = '\0';
          return w1;
        }
    } while (0);
}

#else


/*! This function gets two sprintf_format strings \c f1 and \c f2.
It writes to \c res_buf a format string such that it can be used for printing
any text that can be printed both using \c f1 and using \c f2
(with appropriate trailing sprintf data).
The function returns nonzero if \c f1 and \c f2 are proven to be 'disjoint'
so no one string can be printed using both of them. */
static int
sff_isect (const char *f1, const char *f2, char *res_buf)
{
#ifdef SFF_DEBUG
  const char *f1_initial = f1; /* f1 is shifted to the right so that each time label "again" is passed f1 points to the text that is not yet intersected into res_buf */
  const char *f2_initial = f2; /* and that is true for f2 as well */
  int dbg_ctr;
#endif
  const char *f1_tail = NULL, *f2_tail = NULL;
  char *res_tail = res_buf; /* pointer to the end of filled part of res_buf */
  char f1_v = 0, f2_v = 0; /* Formatting chars of current variable parts in \c f1 and \c f2 */
  char f2_fix = 0; /* Current fixed char in \c f2 . There's no f1_fix because the beginning of f2 is always kept "more fixed" that the beginning of f1 */
  const char *f1_last_replaced = NULL; /* The beginning of last fragment in f1 that is replaced with fixed chars or vars from f2. */
  const char *f2_last_replaced = NULL; /* The beginning of last fragment in f2 that is replaced with fixed chars or vars from f1. */
  int strcmp_res;
again:
#ifdef SFF_DEBUG
  printf ("sff_isect: f1 = %s\n''''''''''''''''", f1_initial);
  for (dbg_ctr = f1 - f1_initial; dbg_ctr--; /* no step */) putchar ('~');
  printf ("\n");
  printf ("sff_isect: f2 = %s\n''''''''''''''''", f2_initial);
  for (dbg_ctr = f2 - f2_initial; dbg_ctr--; /* no step */) putchar ('~');
  printf ("\n");
  printf ("sff_isect: res= ");
  for (dbg_ctr = 0; (dbg_ctr < (res_tail - res_buf)); dbg_ctr++) putchar (res_buf[dbg_ctr]);
  printf ("\n");
#endif
  while ((f1[0] == f2[0]) && ('\0' != f1[0]) && ('%' != f1[0]))
    {
      (res_tail++)[0] = f1[0]; f1++; f2++;
    }
  strcmp_res = strcmp (f1, f2);
  if (!strcmp_res)
    {
      strcpy (res_tail, f1); return SFF_ISECT_OK;
    }
  if ((('%' != f1[0]) && ('%' != f2[0]) && (0 < strcmp_res)) || /* If both v1 and f2 starts from fixed chars and 2nd is greater than 1st */
    (('%' == f2[0]) && /* OR if f2 starts from '%' and f1 does not OR f2 starts from single '%' and f1 starts from double '%' OR f2 starts from plain '%' and f1 starts from %{connvarname}U */
    (('%' != f1[0]) ? 1 :
      ((('%' != f2[1]) && ('%' == f1[1])) ||
        (('{' != f2[1]) && ('{' == f1[1])) ) ) ) )
    {
      const char *swap;
      swap = f2; f2 = f1; f1 = swap;
      swap = f2_tail; f2_tail = f1_tail; f1_tail = swap;
      swap = f2_last_replaced; f2_last_replaced = f1_last_replaced; f1_last_replaced = swap;
#ifdef SFF_DEBUG
      swap = f2_initial; f2_initial = f1_initial; f1_initial = swap;
#endif
    }
/* Now f2 is 'more fixed' than f1 */
  if ('%' != f1[0])
    {
#ifndef NDEBUG
      if ('%' == f2[0])
        GPF_T;
#endif
      if ('\0' == f1[0])
        {
          if ('\0' == f2[0])
            {
              res_tail[0]  = '\0';
              return SFF_ISECT_OK; /* Reached end of both formats */
            }
          return SFF_ISECT_DISJOIN; /* Disjoint: f2 is longer than f1 */
        }
      return SFF_ISECT_DISJOIN; /* Disjoint: f1 and f2 both start with non-'%' chars and they're different */
    }
/* Now we know that '%' == f1[0] */
  if (('%' == f1[0]) && ('%' == f1[1]))
    {
      if (('%' == f2[0]) && ('%' == f2[1]))
        {
          (res_tail++)[0] = '%'; (res_tail++)[0] = '%';
          f1 += 2; f2 += 2;
          goto again; /* see above */
        }
      if ('%' == f2[0])
        GPF_T;
      return SFF_ISECT_DISJOIN; /* Disjoint: f1 starts with '%%' and f2 starts with other fixed char */
    }
/* Now we know that f1 starts with variable part, f2 is either fixed or variable part */
  if(f1_tail <= f1)
    {
      f1_tail = f1 + 1;
      if ('{' == f1_tail[0])
        {
          f1_tail++;
          while (isalnum ((unsigned char) (f1_tail[0])) || ('_' == f1_tail[0])) f1_tail++;
          if ('}' != f1_tail[0])
            goto generic_tails; /* Syntax error -- no '}' after "%{connvar" */
          f1_tail++;
          while (!isalpha (f1_tail[0]) && ('\0' != f1_tail[0])) f1_tail++;
          f1_v = (f1_tail++)[0];
          if ('U' != f1_v)
            goto generic_tails; /* Syntax error -- no 'U' after "%{connvar}" */
        }
      else
        {
          while (!isalpha (f1_tail[0]) && ('\0' != f1_tail[0])) f1_tail++;
          f1_v = (f1_tail++)[0];
        }
    }
  if (f2_tail <= f2)
    {
      if ('%' == f2[0])
        {
          if ('%' == f2[1])
            {
              f2_tail = f2 + 2;
              f2_v = '\0';
              f2_fix = '%';
            }
          else if ('{' == f2[1])
            {
              f2_tail = f2 + 2;
              while (isalnum ((unsigned char) (f2_tail[0])) || ('_' == f2_tail[0])) f2_tail++;
              if ('}' != f2_tail[0])
                goto generic_tails; /* Syntax error -- no '}' after "%{connvar" */
              f2_tail++;
              while (!isalpha (f2_tail[0]) && ('\0' != f2_tail[0])) f2_tail++;
              f2_v = (f2_tail++)[0];
              f2_fix = '\0';
              if ('U' != f2_v)
                goto generic_tails; /* Syntax error -- no 'U' after "%{connvar}" */
              /* There exists one special case that does not depend on format type and context: identical connection variables with identical formatting will always match */
              if (((f1_tail - f1) == (f2_tail - f2)) &&
                  (f1_last_replaced != f1) && (f2_last_replaced != f2) &&
                  !memcmp (f1, f2, (f1_tail - f1)) )
                goto res_tail_shifts_f1_v_gets_f2_v; /* see below */
            }
          else
            {
              f2_tail = f2 + 1;
              while (!isalpha (f2_tail[0]) && ('\0' != f2_tail[0])) f2_tail++;
              f2_v = (f2_tail++)[0];
              f2_fix = '\0';
              switch (f2_v)
                {
                case 'D': case 'U': case 'd': case 's': case 'u': break;
                default: goto generic_tails; /* see below */
                }
            }
        }
      else
        {
          f2_tail = f2 + 1;
          f2_v = '\0';
          f2_fix = f2[0];
        }
    }
  switch (f1_v)
    {
    case 'D': case 'U': case 'd': case 'g': case 's': case 'u': break;
    default: goto generic_tails; /* see below */
    }
/* Now we slightly normalize the rest of processing to write code only for a half of f1_v and f2_v combinations */
  if (('\0' != f2_v) && (f1_v > f2_v))
    { /* This never swaps when f2_fix is not zero, because f2_v is 0 in than case and not greater than f1_v */
      const char *swap;
      char cswap;
      swap = f2; f2 = f1; f1 = swap;
      swap = f2_tail; f2_tail = f1_tail; f1_tail = swap;
      swap = f2_last_replaced; f2_last_replaced = f1_last_replaced; f1_last_replaced = swap;
      cswap = f2_v; f2_v = f1_v; f1_v = cswap;
#ifdef SFF_DEBUG
      swap = f2_initial; f2_initial = f1_initial; f1_initial = swap;
#endif
    }

  switch (f1_v)
    {
    case 'D': goto f1_v_is_D; /* see below */
    case 'U': goto f1_v_is_U; /* see below */
    case 'd': goto f1_v_is_d; /* see below */
    case 'g': goto f1_v_is_g; /* see below */
    case 's': goto f1_v_is_s; /* see below */
    case 'u': goto f1_v_is_u; /* see below */
    default: GPF_T;
    }

f1_v_is_D:
  if (isdatechar (f1_tail[0]))
    goto generic_tails; /* see below */
  /* The unambiguous '%D' in f1 may match any %D-like chars, f2 vars (%U to %D, %s to %D) */
  if ('\0' == f2_v)
    {
      if (isdatechar (f2_fix))
        goto res_tail_gets_f2_fix; /* see below */
      if ((f1_tail[0] == f2_fix) && /* unambiguous synchronisation between f1 and f2... */
        (f1_last_replaced == f1) ) /*... but date output can not be empty so should make if result contains something for the field */
        {
          f2_tail = f2;
          goto tails_are_in_sync; /* see below */
        }
      if ('\0' == f1_tail[0])
        return SFF_ISECT_DIFF_END; /* One string ends with %D, other with non-%D fixed char */
      return SFF_ISECT_DISJOIN;
    }
  switch (f2_v)
    {
    case 'D': goto res_tail_gets_f2_v; /* see below */
    case 'U':
      if (isplainURIchar (f1_tail[0]) || isplainURIchar (f2_tail[0]))
        goto res_tail_gets_f1_v; /* see below */
      if (('%' != f1_tail[0]) && ('%' != f2_tail[0]))
        {
          f2 = f2_tail;
          goto res_tail_gets_f1_v; /* see below */
        }
      goto res_tail_gets_f1_v; /* see below */
    case 'd': case 'g': case 'u':
      goto res_tail_gets_f2_v; /* see below */
    case 's': goto generic_tails; /* see below */
    goto res_tail_gets_f2_v; /* see below */
    default: goto generic_tails; /* see below */
    }

f1_v_is_U:
  if (isplainURIchar (f1_tail[0]))
    goto generic_tails; /* see below */
  /* The unambiguous '%U' in f1 may match any %U-like chars, f2 vars (%U to %U, %d to %d, %s to %U) */
  if ('\0' == f2_v)
    {
      if (isplainURIchar (f2_fix))
        goto res_tail_gets_f2_fix; /* see below */
      if (f1_tail[0] == f2_fix) /* unambiguous synchronisation between f1 and f2... */
        {
          f2_tail = f2;
          goto tails_are_in_sync; /* see below */
        }
      if ('\0' == f1_tail[0])
        return SFF_ISECT_DIFF_END; /* One string ends with %U, other with non-%U fixed char */
      return SFF_ISECT_DISJOIN;
    }
  switch (f2_v)
    {
    case 'U': goto res_tail_gets_f2_v; /* see below */
    case 'd': goto res_tail_gets_f2_v; /* see below */
    case 'g': goto res_tail_gets_f2_v; /* see below */
    case 's': goto generic_tails; /* see below */
    case 'u': goto res_tail_gets_f2_v; /* see below */
    default: goto generic_tails; /* see below */
    }

f1_v_is_d:
f1_v_is_u:
  if (isdigit (f1_tail[0]))
    goto generic_tails; /* see below */
  /* The unambiguous '%d' in f1 may match any %d-like chars, f2 vars (%u to %u) */
  if ('\0' == f2_v)
    {
      if (isdigit (f2_fix))
        goto res_tail_gets_f2_fix; /* see below */
      if (('d' == f1_v) && (f1_last_replaced != f1) && (('-' == f2_fix) || ('+' == f2_fix)))
        goto res_tail_gets_f2_fix; /* see below */
      if ((f1_tail[0] == f2_fix) && /* unambiguous synchronisation between f1 and f2... */
        (f1_last_replaced == f1) ) /*... but integer output can not be empty so should make if result contains something for the field */
        {
          f2_tail = f2;
          goto tails_are_in_sync; /* see below */
        }
      if ('\0' == f1_tail[0])
        return SFF_ISECT_DIFF_END; /* One string ends with %d, other with non-%d fixed char */
      return SFF_ISECT_DISJOIN;
    }
  switch (f2_v)
    {
    case 'd': goto res_tail_gets_f2_v; /* see below */
    case 'g': goto res_tail_gets_f1_v; /* see below */
    case 's': goto generic_tails; /* see below */
    case 'u': goto res_tail_gets_f2_v; /* see below */
    default: goto generic_tails; /* see below */
    }

f1_v_is_g:
  if (isfloatchar (f1_tail[0]))
    goto generic_tails; /* see below */
  /* The unambiguous '%g' in f1 may match any %g-like chars, f2 vars (%u to %u) */
  if ('\0' == f2_v)
    {
      if (isdigit (f2_fix) || ('+' == f2_fix) || ('-' == f2_fix))
        goto res_tail_gets_f2_fix; /* see below */
      if ((f1_last_replaced != f1) && (('-' == f2_fix) || ('+' == f2_fix) || ('.' == f2_fix)))
        goto res_tail_gets_f2_fix; /* see below */
      if ((f1_tail[0] == f2_fix) && /* unambiguous synchronisation between f1 and f2... */
        (f1_last_replaced == f1) ) /*... but integer output can not be empty so should make if result contains something for the field */
        {
          f2_tail = f2;
          goto tails_are_in_sync; /* see below */
        }
      if ('\0' == f1_tail[0])
        return SFF_ISECT_DIFF_END; /* One string ends with %g, other with non-%g fixed char */
      return SFF_ISECT_DISJOIN;
    }
  switch (f2_v)
    {
    case 'd': goto res_tail_gets_f2_v; /* see below */
    case 'g': goto res_tail_gets_f2_v; /* see below */
    case 's': goto generic_tails; /* see below */
    case 'u': goto res_tail_gets_f2_v; /* see below */
    default: goto generic_tails; /* see below */
    }

f1_v_is_s:
  if ('\0' == f2_v)
    {
      if (('\0' != f2_fix) && ('%' != f2_fix) && (f1_tail[0] != f2_fix))
        goto res_tail_gets_f2_fix; /* see below */
    }
  if ('\0' == f1_tail[0])
    { /* %s at the end of f1 intersects with any f2 and the intersection is f2 */
      strcpy (res_tail, f2);
      return SFF_ISECT_OK;
    }
  goto generic_tails; /* see below */

res_tail_gets_f1_v:
  while (f1 < f1_tail) (res_tail++)[0] = (f1++)[0];
  f2_last_replaced = f2;
  goto again; /* see above */

res_tail_shifts_f1_v_gets_f2_v:
#ifndef NDEBUG
  if ('\0' != f2_fix)
    GPF_T1("res_tail_shifts_f1_v_gets_f2_v with f2_fix");
#endif
  while (f2 < f2_tail) (res_tail++)[0] = (f2++)[0];
  f1 = f1_tail;
  goto again; /* see above */

res_tail_gets_f2_v:
#ifndef NDEBUG
  if ('\0' != f2_fix)
    GPF_T1("res_tail_gets_f2 with f2_fix");
#endif
  while (f2 < f2_tail) (res_tail++)[0] = (f2++)[0];
  f1_last_replaced = f1;
  goto again; /* see above */

res_tail_gets_f2_fix:
#ifndef NDEBUG
  if ('\0' == f2_fix)
    GPF_T1("res_tail_gets_f2_fix without f2_fix");
#endif
  if ('%' == f2_fix)
    (res_tail++)[0] = '%';
  (res_tail++)[0] = (f2++)[0];
  f1_last_replaced = f1;
  goto again; /* see above */

tails_are_in_sync:
  f1 = f1_tail;
  f2 = f2_tail;
  goto again;

generic_tails:
  if (('\0' != f2_fix) || ('U' == f2_v) || ('d' == f2_v) || ('u' == f2_v))
    strcpy (res_tail, f2);
  else
    strcpy (res_tail, "%s");
  return SFF_ISECT_OK;
}
#endif

static id_hashed_key_t sprintff_pair_hash (char *strp)
{
  caddr_t *pair = (caddr_t *) strp;
  size_t len1 = box_length (pair[0]);
  size_t len2 = box_length (pair[1]);
  id_hashed_key_t h1, h2;
  BYTE_BUFFER_HASH (h1, pair[0], len1);
  BYTE_BUFFER_HASH (h2, pair[1], len2);
  return ((h1 + 3 * h2) & ID_HASHED_KEY_MASK);
}

static int sprintff_pair_cmp (char *x, char *y)
{
  caddr_t *pair1 = (caddr_t *) x;
  caddr_t *pair2 = (caddr_t *) y;
  if (strcmp (pair1[0], pair2[0]))
    return 0;
  if (strcmp (pair1[1], pair2[1]))
    return 0;
  return 1;
}

id_hash_t *sprintff_known_intersects = NULL;
dk_mutex_t *sprintff_intersect_mtx = NULL;

ccaddr_t
sprintff_intersect (ccaddr_t f1, ccaddr_t f2, int ignore_cache)
{
  ccaddr_t key_pair[2];
  ccaddr_t *cached_res_ptr;
  int fmt_strcmp, best_weight;
  int chk_pos, f1_strlen, f2_strlen, res_maxsize;
  char res_local_buf [100];
  caddr_t res;
/* First-time init */
  if (NULL == sprintff_intersect_mtx)
    {
      sprintff_intersect_mtx = mutex_allocate ();
      sprintff_known_intersects = id_hash_allocate (1021, 2 * sizeof (caddr_t), sizeof (caddr_t), sprintff_pair_hash, sprintff_pair_cmp);
    }
/* Very basic check for disjoint beginnings. */
  chk_pos = 0;
  for (;;)
    {
      char c1 = f1 [chk_pos];
      char c2 = f2 [chk_pos];
      if (c1 != c2)
        {
          if (('%' != c1) && ('%' != c2))
            return NULL; /* Difference in fixed chars */
          break; /* Variable part vs fixed char */
        }
      if ('%' == c1)
        {
          if (('%' == f1 [chk_pos + 1]) && ('%' == f2 [chk_pos + 1]))
            {
              chk_pos += 2; /* Escaped percent char in both formats */
              continue;
            }
          break;
        }
      if ('\0' == c1)
        {
          if (ignore_cache)
            return box_copy (f1);
          return f1; /* Reached ends of strings, two equal string w/o vars */
        }
      chk_pos++;
    }
  fmt_strcmp = strcmp (f1 + chk_pos, f2 + chk_pos);
  if (0 < fmt_strcmp)
    { ccaddr_t swap = f2; f2 = f1; f1 = swap; }
  if (!ignore_cache)
    {
      mutex_enter (sprintff_intersect_mtx);
      key_pair [0] = f1;
      key_pair [1] = f2;
      cached_res_ptr = (ccaddr_t *) id_hash_get (sprintff_known_intersects, (caddr_t)key_pair);
      if (NULL != cached_res_ptr)
        {
          ccaddr_t res = cached_res_ptr [0];
          mutex_leave (sprintff_intersect_mtx);
          return res;
        }
    }
/* Here we start actual calculation of a new result, starting from chk_pos offset. Then we cache it and return */
  f1_strlen = chk_pos + strlen (f1 + chk_pos);
  f2_strlen = chk_pos + strlen (f2 + chk_pos);
  res_maxsize = 3 + f1_strlen + f2_strlen - chk_pos;
  full_res_buf = ((res_maxsize > sizeof (res_local_buf)) ? dk_alloc (res_maxsize) : res_local_buf);
  full_f1 = f1 + chk_pos;
  full_f2 = f2 + chk_pos;
#ifdef SSF_WEIGHTED_ISECT
  full_res_buf_end = full_res_buf + res_maxsize;
  full_f1_end = f1 + f1_strlen;
  full_f2_end = f2 + f2_strlen;
  memcpy (full_res_buf, f1, chk_pos);
  best_weight = sff_isect (full_f1, full_f1_end, full_f2, full_f2_end, full_res_buf + chk_pos, 0);
#else
  best_weight = sff_isect (full_f1, full_f2, full_res_buf + chk_pos);
#endif
  if (0 > best_weight)
    res = NULL;
  else
    {
#ifndef SSF_WEIGHTED_ISECT
      memcpy (full_res_buf, f1, chk_pos);
#endif
      res = box_dv_short_string (full_res_buf);
    }
  if (full_res_buf != res_local_buf)
    dk_free (full_res_buf, res_maxsize);
  if (ignore_cache)
    return res; /* mutex is not entered and it's OK to bypass mutex_leave() at the end. */
  key_pair [0] = box_dv_short_string (f1);
  key_pair [1] = box_dv_short_string (f2);
#if 0
  printf ("sprintff_intersect ('%s', '%s') = '%s'\n", key_pair[0], key_pair[1], (NULL == res) ? "NULL" : res);
#endif
  id_hash_set (sprintff_known_intersects, (caddr_t)key_pair, (caddr_t)(&res));
  mutex_leave (sprintff_intersect_mtx);
  return res;
}

/*! This function gets a string \c s1 and a sprintf_format string \c f2.
The function returns nonzero if it is proven that \c s1 can not be printed by \c f2.
If it can be printed or if the function is in doubt then it returns zero. */
static int sff_dislike (const char *s1, const char *f2)
{
  const char *f2_tail, *s1_tail;
  char f2_v;
  int s1_shifted;
again:
  while ((f2[0] == s1[0]) && ('\0' != f2[0]) && ('%' != f2[0]))
    {
      f2++; s1++;
    }
  if ('\0' == f2[0])
    {
      if ('\0' == s1[0])
        {
          return SFF_ISECT_OK; /* Reached end of both formats */
        }
      return SFF_ISECT_DISJOIN; /* Disjoint: s1 is longer than f2 */
    }
  if ('%' != f2[0])
    return SFF_ISECT_DISJOIN; /* Disjoint fixed chars */
/* Now we know that '%' == f2[0] */
  if ('%' == f2[1])
    {
      f2 += 2; s1 += 1;
      goto again; /* see above */
    }
/* Now we know that f2 starts with variable part */
  f2_tail = f2 + 1;
  if ('{' == f2_tail[0])
    {
      f2_tail++;
      while (isalnum ((unsigned char) (f2_tail[0])) || ('_' == f2_tail[0])) f2_tail++;
      if ('}' != f2_tail[0])
        goto generic_tails; /* Syntax error -- no '}' after "%{connvar" */
      f2_tail++;
    }
  while (!isalpha (f2_tail[0]) && ('\0' != f2_tail[0])) f2_tail++;
  f2_v = (f2_tail++)[0];
  switch (f2_v)
    {
    case 'D': goto f2_v_is_D; /* see below */
    case 'U': goto f2_v_is_U; /* see below */
    case 'd': goto f2_v_is_d; /* see below */
    case 'g': goto f2_v_is_g; /* see below */
    case 's': goto f2_v_is_s; /* see below */
    case 'u': goto f2_v_is_u; /* see below */
    default: goto generic_tails; /* see below */
    }

f2_v_is_D:
  if (isdatechar (f2_tail[0]) || ('%' == f2_tail[0]))
    goto generic_tails; /* see below */
  /* The unambiguous '%D' in f2 may match any %D-like chars */
  s1_tail = s1;
  for (;;)
    {
      if (!isdatechar (s1_tail[0]))
        {
          if (f2_tail[0] == s1_tail[0]) /* unambiguous synchronisation between f2 and s1 */
            goto tails_are_in_sync; /* see below */
          if ('\0' == f2_tail[0])
            return SFF_ISECT_DIFF_END; /* One string ends with %D, other with non-%D fixed char */
          return SFF_ISECT_DISJOIN;
        }
      else
        s1_tail++;
    }
  GPF_T; /* never reached */

f2_v_is_U:
  if (isplainURIchar (f2_tail[0]) || (f2_tail[0] & ~0x7F) || ('%' == f2_tail[0]))
    goto generic_tails; /* see below */
  /* The unambiguous '%U' in f2 may match any %U-like chars */
  s1_tail = s1;
  for (;;)
    {
      if (isplainURIchar (s1_tail[0]))
        {
          s1_tail++;
          continue;
        }
      if (s1_tail[0] & ~0x7F)
        {
          const char *ctail = s1_tail;
          unichar uc = eh_decode_char__UTF8 (&ctail, ctail + strlen (ctail));
          if (uc > 0)
            {
              s1_tail = ctail;
              continue;
            }
        }
      else if (('%' == s1_tail[0]) && isxdigit (s1_tail[1]) && isxdigit (s1_tail[2]))
        {
          s1_tail += 3;
          continue;
        }
      if (f2_tail[0] == s1_tail[0]) /* unambiguous synchronisation between f2 and s1 */
        goto tails_are_in_sync; /* see below */
      if ('\0' == f2_tail[0])
        return SFF_ISECT_DIFF_END; /* One string ends with %U, other with non-%U fixed char */
      return SFF_ISECT_DISJOIN;
    }
  GPF_T; /* never reached */

f2_v_is_d:
f2_v_is_u:
  if (isdigit (f2_tail[0]) || ('%' == f2_tail[0]))
    goto generic_tails; /* see below */
  /* The unambiguous '%d' in f2 may match any %d-like chars */
  s1_tail = s1;
  s1_shifted = 0;
  for (;;)
    {
      if (isdigit (s1_tail[0]))
        {
          s1_tail++;
          s1_shifted = 1; continue;
        }
      else if (!s1_shifted && ('-' == s1_tail[0]) && isdigit (s1_tail[0]) && ('-' != f2_tail[0]) && ('d' == f2_v))
        {
          s1_tail += 2;
          s1_shifted = 1; continue;
        }
      else if (s1_shifted && (f2_tail[0] == s1_tail[0])) /* unambiguous synchronisation between f2 and s1 */
        goto tails_are_in_sync; /* see below */
      else if ('\0' == f2_tail[0])
        return SFF_ISECT_DIFF_END; /* One string ends with %d, other with non-%d fixed char */
      else
        return SFF_ISECT_DISJOIN;
    }
  GPF_T; /* never reached */

f2_v_is_g:
  if (isfloatchar (f2_tail[0]) || ('%' == f2_tail[0]))
    goto generic_tails; /* see below */
  /* The unambiguous '%d' in f2 may match any %d-like chars */
  s1_tail = s1;
  s1_shifted = 0;
  if (('-' == s1_tail[0]) && isdigit (s1_tail[0]))
    {
      s1_tail += 2;
      s1_shifted = 1;
    }
  while (isdigit (s1_tail[0]))
    {
      s1_tail++;
      s1_shifted = 1;
    }
  if (s1_shifted && ('.' == s1_tail[0]) && isdigit (s1_tail[0]))
    {
      s1_tail += 2;
      while (isdigit (s1_tail[0])) s1_tail++;
    }
  if (s1_shifted && (('e' == s1_tail[0]) || ('E' == s1_tail[0])))
    {
      if (('-' == s1_tail[1]) && isdigit (s1_tail[2]))
        s1_tail += 3;
      else if (isdigit (s1_tail[1]))
        s1_tail += 2;
      else
        return SFF_ISECT_DIFF_END; /* 'E' in string does not match to f2_tail[0] char */
      while (isdigit (s1_tail[0])) s1_tail++;
    }
  if (s1_shifted && (f2_tail[0] == s1_tail[0])) /* unambiguous synchronisation between f2 and s1 */
    goto tails_are_in_sync; /* see below */
  else if ('\0' == f2_tail[0])
    return SFF_ISECT_DIFF_END; /* One string ends with %g, other with non-%g fixed char */
  else
    return SFF_ISECT_DISJOIN;

f2_v_is_s:
  if ('\0' == f2_tail[0])
    { /* %s at the end of f2 intersects with any s1 */
      return SFF_ISECT_OK;
    }
  goto generic_tails; /* see below */

tails_are_in_sync:
  f2 = f2_tail;
  s1 = s1_tail;
  goto again;

generic_tails:
  return SFF_ISECT_OK;
}

int
sprintff_like (ccaddr_t s1, ccaddr_t f2)
{
  int s1_chk_pos, f2_chk_pos /* s1_strlen */;
/* Very basic check for disjoint beginnings. */
  s1_chk_pos = f2_chk_pos = 0;
  for (;;)
    {
      char c1 = s1 [s1_chk_pos];
      char c2 = f2 [f2_chk_pos];
      if ('%' == c2)
        {
          if (('%' == c1) && ('%' == f2 [f2_chk_pos + 1]))
            {
              s1_chk_pos++; f2_chk_pos += 2; /* Escaped percent char in f2 */
              continue;
            }
          break; /* Variable part vs fixed char */
        }
      if (c1 != c2)
        return 0; /* Difference in fixed chars */
      if ('\0' == c1)
        return 1;
      s1_chk_pos++; f2_chk_pos++;
    }
/* Here we start actual calculation of a new result, starting from s1_chk_pos and f2_chk_pos offset. Then we cache it and return */
  /* s1_strlen = s1_chk_pos + strlen (s1 + s1_chk_pos); */
  if (SFF_ISECT_OK == sff_dislike (s1 + s1_chk_pos, f2 + f2_chk_pos))
    return 1;
  return 0;
}

caddr_t
sprintff_from_strg (ccaddr_t strg, int use_mem_pool)
{
  int ctr, strg_strlen = 0;
  int strg_pct_ctr = 0;
  caddr_t res;
  char * res_tail;
  while ('\0' != strg [strg_strlen])
    {
      if ('%' == strg [strg_strlen])
        strg_pct_ctr++;
      strg_strlen++;
    }
  if (use_mem_pool)
    res = t_alloc_box (strg_strlen + strg_pct_ctr + 1, DV_STRING);
  else
    res = dk_alloc_box (strg_strlen + strg_pct_ctr + 1, DV_STRING);
  res_tail = res;
  for (ctr = 0; ctr <= /* not '<' */ strg_strlen; ctr++)
    {
      char c1 = strg[ctr];
      if ('%' == c1)
        (res_tail++)[0] = '%';
      (res_tail++)[0] = c1;
    }
  return res;
}

void
sparp_rvr_add_sprintffs (sparp_t *sparp, rdf_val_range_t *rvr, ccaddr_t *add_sffs, ptrlong add_count)
{
  int old_len, len;
  int ctr, addctr;
  int oldsize, newmax;
  old_len = len = rvr->rvrSprintffCount;
  newmax = len + add_count;
  oldsize = BOX_ELEMENTS_0 (rvr->rvrSprintffs);
  if (oldsize < newmax)
    {
      int newsize = oldsize ? oldsize : 1;
      ccaddr_t *new_buf;
      do newsize *= 2; while (newsize < newmax);
      new_buf = (ccaddr_t *)t_alloc_box (newsize * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
      if (NULL != rvr->rvrSprintffs)
        memcpy (new_buf, rvr->rvrSprintffs, len * sizeof (caddr_t));
      rvr->rvrSprintffs = new_buf;
    }
  for (ctr = old_len; ctr--; /* no step */)
    {
      ccaddr_t old = rvr->rvrSprintffs [ctr];
      if (!IS_BOX_POINTER (old))
        spar_internal_error (sparp, "RDF medatata are corrupted (sparp_rvr_add_sprintffs() #1)");
    }
  for (addctr = add_count; addctr--; /* no step */)
    {
      ccaddr_t addon = add_sffs [addctr];
      if (!IS_BOX_POINTER (addon))
        spar_internal_error (sparp, "RDF medatata are corrupted (sparp_rvr_add_sprintffs() #2)");
      for (ctr = old_len; ctr--; /* no step */)
        {
          ccaddr_t old = rvr->rvrSprintffs [ctr];
          if (!strcmp (old, addon)) /* Already here */
            goto skip_addon; /* see below */
        }
      rvr->rvrSprintffs [len++] = addon;
skip_addon: ;
    }
  rvr->rvrSprintffCount = len;
}

void
sparp_rvr_intersect_sprintffs (sparp_t *sparp, rdf_val_range_t *rvr, ccaddr_t *isect_sffs, ptrlong isect_count)
{
  int old_len = rvr->rvrSprintffCount;
  int max_reslen, old_ctr, isect_ctr, res_ctr, res_count, res_buf_len, oldsize;
  ccaddr_t *res = sparp->sparp_sprintff_isect_buf;
  max_reslen = old_len * isect_count;
  if (0 == max_reslen)
    {
      rvr->rvrSprintffCount = 0;
      return;
    }
  res_buf_len = BOX_ELEMENTS_0 (res);
  if (res_buf_len < max_reslen)
    {
      int newsize = res_buf_len ? res_buf_len : 1;
      do newsize *= 2; while (newsize < max_reslen);
      if (newsize >= MAX_BOX_ELEMENTS)
	spar_internal_error (sparp, "The maximum number of elements in array too long");
      res = sparp->sparp_sprintff_isect_buf = (ccaddr_t *)t_alloc_box (newsize * sizeof (caddr_t), DV_ARRAY_OF_LONG);
      res_buf_len = newsize;
    }
#ifdef SFF_DEBUG
  memset (res, '~', res_buf_len * sizeof (caddr_t));
#endif
  res_count = 0;
  for (old_ctr = old_len; old_ctr--; /* no step */)
    {
      for (isect_ctr = isect_count; isect_ctr--; /* no step */)
        {
          ccaddr_t f1 = rvr->rvrSprintffs [old_ctr];
          ccaddr_t f2 = isect_sffs [isect_ctr];
          ccaddr_t f12;
          if (!IS_BOX_POINTER (f1))
            spar_internal_error (sparp, "RDF medatata are corrupted (sparp_rvr_intersect_sprintffs() #1)");
          if (!IS_BOX_POINTER (f2))
            spar_internal_error (sparp, "RDF medatata are corrupted (sparp_rvr_intersect_sprintffs() #2)");
          f12 = sprintff_intersect (f1, f2, 0);
          if (NULL == f12)
            continue;
          for (res_ctr = res_count; res_ctr--; /* no_step */)
            {
              if (!strcmp (res [res_ctr], f12))
                goto skip_save_f12;
            }
          res [res_count++] = (caddr_t) f12;
skip_save_f12: ;
        }
    }
  oldsize = BOX_ELEMENTS_0 (rvr->rvrSprintffs);
  if (oldsize < res_count)
    {
      int newsize = oldsize ? oldsize : 1;
      do newsize *= 2; while (newsize < max_reslen);
      rvr->rvrSprintffs = (ccaddr_t *)t_alloc_box (newsize * sizeof (caddr_t), DV_ARRAY_OF_LONG);
    }
#ifdef MALLOC_DEBUG
  memset (rvr->rvrSprintffs, 0, box_length (rvr->rvrSprintffs));
#else
#ifdef DEBUG
  memset (rvr->rvrSprintffs, -1, box_length (rvr->rvrSprintffs));
#endif
#endif
  memcpy (rvr->rvrSprintffs, res, res_count * sizeof (caddr_t));
  rvr->rvrSprintffCount = res_count;
}

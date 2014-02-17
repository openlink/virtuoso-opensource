/*
 *  xslt_fmt.c
 *
 *  $Id$
 *
 *  XSLT formatting routines
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2014 OpenLink Software
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

/* #define UNIT_TEST */

#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#ifndef UNIT_TEST
#include "Dk.h"
#include "xslt_impl.h"
#endif

typedef char *roman_digits_t[10];

roman_digits_t roman_digits[4] = {
  { "", "i", "ii", "iii", "iv", "v", "vi", "vii", "viii", "ix" },
  { "", "x", "xx", "xxx", "xl", "l", "lx", "lxx", "lxxx", "xc" },
  { "", "c", "cc", "ccc", "cd", "d", "dc", "dcc", "dccc", "cm" },
  { "", "m", "mm", "mmm", "mq", "q", "qm", "qmm", "qmmm", "mq" } };

char *xslt_fmt_print_roman (char *tail, unsigned num, int uppercase)
{
  int digit_ctr = 3;
  unsigned digit_factor = 1000;
  if (!num)
    {
      (tail++)[0] = '0';
      return tail;
    }
  if (num >=10000)
    {
      (tail++)[0] = '?';
      num %= 10000;
    }
  while (digit_ctr >= 0)
    {
      roman_digits_t *dgts = roman_digits + digit_ctr;
      char *dgt = dgts[0][num / digit_factor];
      if (uppercase)
	{
	  while ('\0' != dgt[0])
	    (tail++)[0] = (dgt++)[0] - ('a' - 'A');
	}
      else
	{
	  while ('\0' != dgt[0])
	    (tail++)[0] = (dgt++)[0];
	}
      num = num % digit_factor;
      digit_ctr--;
      digit_factor /= 10;
    }
  return tail;
}

char *xslt_fmt_print_latin_alpha (char *tail, unsigned num, int uppercase)
{
  int digit_ctr = 1;
  unsigned digit_factor = 1;
  if (!num)
    {
      (tail++)[0] = '0';
      return tail;
    }
  num--;
  while ((26 * digit_factor) <= num)
    {
      num -= (26 * digit_factor);
      if (digit_ctr >= 5)
	{
	  num %= (26 * digit_factor);
	  break;
	}
      digit_ctr++;
      digit_factor *= 26;
    }
  while (digit_ctr > 0)
    {
      unsigned dgt = num / digit_factor;
      (tail++)[0] = (uppercase ? 'A' : 'a') + dgt;
      num %= digit_factor;
      digit_ctr--;
      digit_factor /= 26;
    }
  return tail;
}

char *xslt_fmt_print_decimal (char *tail, unsigned num, int min_len)
{
  char buf[20];
  int len = sprintf (buf, "%u", num);
  while (len < min_len)
    {
      (tail++)[0] = '0';
      min_len--;
    }
  memcpy (tail, buf, len);
  return tail + len;
}

char *xslt_fmt_print_numbers (char *tail, int tail_max_fill, unsigned *nums, int nums_count, char *format)
{
  char *last_nonalpha_begin;
  char *delim_begin, *delim_end, *delim_tail;
  char *fmt_end = NULL; /* To keep gcc 4.0 happy */
  char *buf_end = tail + tail_max_fill;
  int fmt_type = '1', fmt_len = 1;
  int num_idx;
  int format_len = (int) strlen(format);
/* Printing starting nonalpha-s */
  while (('\0' != format[0]) && !isalnum ((unsigned char) (format[0])))
    (tail++)[0] = (format++)[0];
  delim_begin = delim_end = format;
/* Remembering format end */
  last_nonalpha_begin = format + format_len;
  while ((last_nonalpha_begin > format) && !isalnum((unsigned char) (last_nonalpha_begin[-1])))
    last_nonalpha_begin--;
/* Now the printing loop is running. */
  for (num_idx = 0; num_idx < nums_count; num_idx++)
    {
      unsigned curr_num = nums [num_idx];
/* Finding the format */
      if (delim_end < last_nonalpha_begin)
	{
	  fmt_end = delim_end;
	  fmt_type = fmt_end[0];
	  switch (fmt_end[0])
	    {
	    case '1':
	      fmt_len = 1;
	      fmt_end++;
	      break;
	    case '0':
	      fmt_type = '1';
	      fmt_len = 1;
	      while ('0' == fmt_end[0])
		{ fmt_end++; fmt_len++; }
	      if ('1' == fmt_end[0])
		fmt_end++;
	      else
		fmt_len = 1;
	      break;
	    case 'A': case 'a': case 'I': case 'i':
	      fmt_end++;
	      break;
	    }
/* Error recovery should be made if the format is unsupported or invalid */
	  if (isalnum ((unsigned char) (fmt_end[0])))
	    {
	      fmt_type = '1';
	      fmt_len = 1;
	      while (isalnum ((unsigned char) (fmt_end[0])))
		fmt_end++;
	    }
	}
/* Printing the current number */
#ifdef GPF_T
      if (tail > (buf_end-16))
	GPF_T;
#endif
      switch (fmt_type)
	{
	case 'A':
	  tail = xslt_fmt_print_latin_alpha (tail, curr_num, 1);
	  break;
	case 'a':
	  tail = xslt_fmt_print_latin_alpha (tail, curr_num, 0);
	  break;
	case 'I':
	  tail = xslt_fmt_print_roman (tail, curr_num, 1);
	  break;
	case 'i':
	  tail = xslt_fmt_print_roman (tail, curr_num, 0);
	  break;
	default:
	  tail = xslt_fmt_print_decimal (tail, curr_num, fmt_len);
	  break;
	}
/* If needed, printing the delimiter */
      if (num_idx < (nums_count-1))
	{
	  if (delim_end < last_nonalpha_begin)
	    {
	      delim_begin = delim_end = fmt_end;
	      while ((delim_end < last_nonalpha_begin) && !isalnum ((unsigned char) (delim_end[0])))
		delim_end++;
	    }
	  if (delim_begin < delim_end)
	    {
	      for (delim_tail = delim_begin; delim_tail < delim_end; delim_tail++)
		(tail++)[0] = delim_tail[0];
	    }
	  else
	    (tail++)[0] = '.';
	}
    }
/* Printing ending nonalpha-s */
  while ('\0' != last_nonalpha_begin[0])
    (tail++)[0] = (last_nonalpha_begin++)[0];
  return tail;
}

#ifdef UNIT_TEST
/* It takes 49 test cases to get 100% coverage on 4 functions with 68 C/D-s */

char tst_buf[100000];

void main(void)
{
  static unsigned n1[] = { 1,2,3,4,5,6,7,8,9,10 };
  static unsigned n2[] = { 10,20,30,40,50,60,70,80,90,100 };
  static unsigned n3[] = { 100,200,300,400,500,600,700,800,900,1000 };
  static unsigned n4[] = { 1234,2345,3456,4576,5678,6789,7890,8901,9012,27 };
  static unsigned n5[] = { 1000000000 };
  char *tail;

  tail = tst_buf; memset (tst_buf, 0, sizeof (tst_buf));
  tail += sprintf (tail, "\nSpecial numberings:");
  tail += sprintf (tail, "\n"); tail = xslt_fmt_print_numbers (tail, n1, 1, "A.i");
  tail += sprintf (tail, "\n"); tail = xslt_fmt_print_numbers (tail, n1, 2, "A.i");
  tail += sprintf (tail, "\n"); tail = xslt_fmt_print_numbers (tail, n1, 3, "A.i");
  tail += sprintf (tail, "\n"); tail = xslt_fmt_print_numbers (tail, n1, 1, "((A.i))");
  tail += sprintf (tail, "\n"); tail = xslt_fmt_print_numbers (tail, n1, 2, "((A.i))");
  tail += sprintf (tail, "\n"); tail = xslt_fmt_print_numbers (tail, n1, 3, "((A.i))");
  tail += sprintf (tail, "\n"); tail = xslt_fmt_print_numbers (tail, n1, 1, "((001))");
  tail += sprintf (tail, "\n"); tail = xslt_fmt_print_numbers (tail, n1, 2, "((001))");
  tail += sprintf (tail, "\n"); tail = xslt_fmt_print_numbers (tail, n1, 3, "((001))");
  tail += sprintf (tail, "\n"); tail = xslt_fmt_print_numbers (tail, n1, 1, "#");
  tail += sprintf (tail, "\n"); tail = xslt_fmt_print_numbers (tail, n1, 2, "#");
  tail += sprintf (tail, "\n"); tail = xslt_fmt_print_numbers (tail, n1, 3, "#");
  printf ("%s", tst_buf);

  tail = tst_buf; memset (tst_buf, 0, sizeof (tst_buf));
  tail += sprintf (tail, "\nAlpha lowercase:");
  tail += sprintf (tail, "\n"); tail = xslt_fmt_print_numbers (tail, n1, 10, "a");
  tail += sprintf (tail, "\n"); tail = xslt_fmt_print_numbers (tail, n2, 10, "a");
  tail += sprintf (tail, "\n"); tail = xslt_fmt_print_numbers (tail, n3, 10, "a");
  tail += sprintf (tail, "\n"); tail = xslt_fmt_print_numbers (tail, n4, 10, "a");
  tail += sprintf (tail, "\n"); tail = xslt_fmt_print_numbers (tail, n5, 10, "a");
  printf ("%s", tst_buf);

  tail = tst_buf; memset (tst_buf, 0, sizeof (tst_buf));
  tail += sprintf (tail, "\nAlpha uppercase:");
  tail += sprintf (tail, "\n"); tail = xslt_fmt_print_numbers (tail, n1, 10, "A");
  tail += sprintf (tail, "\n"); tail = xslt_fmt_print_numbers (tail, n2, 10, "A");
  tail += sprintf (tail, "\n"); tail = xslt_fmt_print_numbers (tail, n3, 10, "A");
  tail += sprintf (tail, "\n"); tail = xslt_fmt_print_numbers (tail, n4, 10, "A");
  tail += sprintf (tail, "\n"); tail = xslt_fmt_print_numbers (tail, n5, 10, "A");
  printf ("%s", tst_buf);

  tail = tst_buf; memset (tst_buf, 0, sizeof (tst_buf));
  tail += sprintf (tail, "\nRoman lowercase:");
  tail += sprintf (tail, "\n"); tail = xslt_fmt_print_numbers (tail, n1, 10, "i");
  tail += sprintf (tail, "\n"); tail = xslt_fmt_print_numbers (tail, n2, 10, "i");
  tail += sprintf (tail, "\n"); tail = xslt_fmt_print_numbers (tail, n3, 10, "i");
  tail += sprintf (tail, "\n"); tail = xslt_fmt_print_numbers (tail, n4, 10, "i");
  tail += sprintf (tail, "\n"); tail = xslt_fmt_print_numbers (tail, n5, 10, "i");
  printf ("%s", tst_buf);

  tail = tst_buf; memset (tst_buf, 0, sizeof (tst_buf));
  tail += sprintf (tail, "\nRoman uppercase:");
  tail += sprintf (tail, "\n"); tail = xslt_fmt_print_numbers (tail, n1, 10, "I");
  tail += sprintf (tail, "\n"); tail = xslt_fmt_print_numbers (tail, n2, 10, "I");
  tail += sprintf (tail, "\n"); tail = xslt_fmt_print_numbers (tail, n3, 10, "I");
  tail += sprintf (tail, "\n"); tail = xslt_fmt_print_numbers (tail, n4, 10, "I");
  tail += sprintf (tail, "\n"); tail = xslt_fmt_print_numbers (tail, n5, 10, "I");
  printf ("%s", tst_buf);

  tail = tst_buf; memset (tst_buf, 0, sizeof (tst_buf));
  tail += sprintf (tail, "\nDefault:");
  tail += sprintf (tail, "\n"); tail = xslt_fmt_print_numbers (tail, n1, 10, "");
  tail += sprintf (tail, "\n"); tail = xslt_fmt_print_numbers (tail, n2, 10, "");
  tail += sprintf (tail, "\n"); tail = xslt_fmt_print_numbers (tail, n3, 10, "");
  tail += sprintf (tail, "\n"); tail = xslt_fmt_print_numbers (tail, n4, 10, "");
  tail += sprintf (tail, "\n"); tail = xslt_fmt_print_numbers (tail, n5, 10, "");
  printf ("%s", tst_buf);

  tail = tst_buf; memset (tst_buf, 0, sizeof (tst_buf));
  tail += sprintf (tail, "\nFormats that are equal to default:");
  tail += sprintf (tail, "\n"); tail = xslt_fmt_print_numbers (tail, n4, 10, "1");
  tail += sprintf (tail, "\n"); tail = xslt_fmt_print_numbers (tail, n4, 10, "1.1");
  tail += sprintf (tail, "\n"); tail = xslt_fmt_print_numbers (tail, n4, 10, "1.1.1.1.1.1.1.1.1.1.1");
  printf ("%s", tst_buf);

  tail = tst_buf; memset (tst_buf, 0, sizeof (tst_buf));
  tail += sprintf (tail, "\nInvalid formats:");
  tail += sprintf (tail, "\n"); tail = xslt_fmt_print_numbers (tail, n1, 3, "A.z");
  tail += sprintf (tail, "\n"); tail = xslt_fmt_print_numbers (tail, n1, 3, "z.i");
  tail += sprintf (tail, "\n"); tail = xslt_fmt_print_numbers (tail, n1, 3, "z.z");
  tail += sprintf (tail, "\n"); tail = xslt_fmt_print_numbers (tail, n1, 3, "((A.z))");
  tail += sprintf (tail, "\n"); tail = xslt_fmt_print_numbers (tail, n1, 3, "((z.z))");
  tail += sprintf (tail, "\n"); tail = xslt_fmt_print_numbers (tail, n1, 3, "((z.z))");
  tail += sprintf (tail, "\n"); tail = xslt_fmt_print_numbers (tail, n1, 3, "((000))");
  tail += sprintf (tail, "\n"); tail = xslt_fmt_print_numbers (tail, n1, 3, "((00A))");
  tail += sprintf (tail, "\n"); tail = xslt_fmt_print_numbers (tail, n1, 3, "((011))");
  printf ("%s", tst_buf);

  exit(0);
}

#endif

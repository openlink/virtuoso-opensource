/*
 *  wi_xid.c
 *
 *  $Id$
 *
 *  Functions to deal with XID structures
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2012 OpenLink Software
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

#include "Dk.h"
#include "Wi/widv.h"
#include "Wi/wi_xid.h"


#define XID_DEBUG


char* uuid_bin_encode (void* uuid)
{
  char* encoded_str = dk_alloc_box (37, DV_STRING);

#ifdef XID_DEBUG
  if (box_length (uuid) != sizeof(uuid_t))
    GPF_T1 ("wrong uuid object received");
#endif
  uuid_unparse ((unsigned char *) uuid, encoded_str);
  return encoded_str;
}


void* uuid_bin_decode (const char* uuid_str)
{
  uuid_t * xid = (uuid_t *) dk_alloc_box (sizeof (uuid_t), DV_BIN);
#ifdef XID_DEBUG
  if (strlen (uuid_str) != 37)
    GPF_T1 ("wrong uuid string received");
#endif

  if (0 == uuid_parse ((const char*)uuid_str, (unsigned char *) xid))
    return xid;
  dk_free_box ((box_t) xid);
  return 0;
}

static char char_16_table[] = "0123456789abcdef";
static int char_r_16_table[256] =
/*	0	1	2	3	4	5	6	7	8	9	a	b	c       d        e       f */
/* 0 */{-1,	-1,	-1,	-1,	-1,	-1,	-1,	-1,	-1,	-1,	-1,	-1,	-1,	     -1,       -1,      -1,
/* 1 */	-1,	-1,	-1,	-1,	-1,	-1,	-1,	-1,	-1,	-1,	-1,	-1,      -1,      -1,       -1,      -1,
/* 2 */	-1,	-1,	-1,	-1,	-1,	-1,	-1,	-1,	-1,	-1,	-1,	-1,      -1,      -1,       -1,      -1,
/* 3 */	0,	1,	2,	3,	4,	5,	6,	7,	8,	9,	-1,	-1,      -1,      -1,       -1,      -1,
/* 4 */	-1,	-1,	-1,	-1,	-1,	-1,	-1,	-1,	-1,	-1,	-1,	-1,      -1,      -1,       -1,      -1,
/* 5 */	-1,	-1,	-1,	-1,	-1,	-1,	-1,	-1,	-1,	-1,	-1,	-1,      -1,      -1,       -1,      -1,
/* 6 */	-1,	10,	11,	12,	13,	14,	15,	-1,	-1,	-1,	-1,	-1,      -1,      -1,       -1,      -1,
/* 7 */	-1,	-1,	-1,	-1,	-1,	-1,	-1,	-1,	-1,	-1,	-1,	-1,      -1,      -1,       -1,      -1,
/* 8 */	-1,	-1,	-1,	-1,	-1,	-1,	-1,	-1,	-1,	-1,	-1,	-1,      -1,      -1,       -1,      -1,
/* 9 */	-1,	-1,	-1,	-1,	-1,	-1,	-1,	-1,	-1,	-1,	-1,	-1,      -1,      -1,       -1,      -1,
/* a */	-1,	-1,	-1,	-1,	-1,	-1,	-1,	-1,	-1,	-1,	-1,	-1,      -1,      -1,       -1,      -1,
/* b */	-1,	-1,	-1,	-1,	-1,	-1,	-1,	-1,	-1,	-1,	-1,	-1,      -1,      -1,       -1,      -1,
/* c */	-1,	-1,	-1,	-1,	-1,	-1,	-1,	-1,	-1,	-1,	-1,	-1,      -1,      -1,       -1,      -1,
/* d */	-1,	-1,	-1,	-1,	-1,	-1,	-1,	-1,	-1,	-1,	-1,	-1,      -1,      -1,       -1,      -1,
/* e */	-1,	-1,	-1,	-1,	-1,	-1,	-1,	-1,	-1,	-1,	-1,	-1,      -1,      -1,       -1,      -1,
/* f */	-1,	-1,	-1,	-1,	-1,	-1,	-1,	-1,	-1,	-1,	-1,	-1,      -1,      -1,       -1,      -1
};




/* encoded xid string is sequence of 3 encoded longs in
   network byte order + remains encoded data... */
#if 1 /* Aleksey, enable it when the java code will be updated */

static
int encode_ptr (unsigned char * ptr, int length, unsigned char * target)
{
  unsigned char * xid_ptr = ptr;
  unsigned char * xid_end = ptr+length;
  unsigned char * where = target;

  while (xid_ptr != xid_end)
    {
      where[0] = char_16_table [xid_ptr[0] / 16];
      where[1] = char_16_table [xid_ptr[0] % 16];
      where+=2;
      xid_ptr++;
    }
  return (int) (where - target);
}

static
int decode_ptr (const unsigned char * from, int length, unsigned char * where)
{
  const unsigned char * str_ptr = from;
  const unsigned char * str_e = from + 2 * ( length / 2 ); /* only even numbers are allowed */
  unsigned char * xid_ptr = where;

  while (str_ptr != str_e)
    {
#ifdef XID_DEBUG
      if (char_r_16_table[(int)str_ptr[0]] == -1 ||
	  char_r_16_table[(int)str_ptr[1]] == -1)
	GPF_T1 ("wrong xid string");
#endif
      xid_ptr[0] = (char) char_r_16_table[(int)str_ptr[0]] * 16 + (char) char_r_16_table[(int)str_ptr[1]];

      str_ptr+=2;
      xid_ptr++;
    }
  return length;
}


char*
xid_bin_encode (void* _xid)
{
  unsigned char* str_ptr;
  unsigned char* encoded_str = str_ptr = (unsigned char *) dk_alloc_box (sizeof(virtXID)*2 + 1 ,DV_STRING);
  virtXID * xid = (virtXID *) _xid;
  int length;
  int32 tmp_l;

  /*log_debug (">> %d %d %d", xid->formatID, xid->gtrid_length, xid->bqual_length); */

  LONG_SET_NA (&tmp_l, xid->formatID);
  length = encode_ptr ((unsigned char *) &tmp_l, sizeof (tmp_l), encoded_str);

  LONG_SET_NA (&tmp_l, xid->gtrid_length);
  length += encode_ptr ((unsigned char *) &tmp_l, sizeof (tmp_l), encoded_str + length);

  LONG_SET_NA (&tmp_l, xid->bqual_length);
  length += encode_ptr ((unsigned char *) &tmp_l, sizeof (tmp_l), encoded_str + length);

  length += encode_ptr ((unsigned char *) xid->data, XIDDATASIZE, encoded_str + length);

  encoded_str[length] = 0;

  /*log_debug (">> %s", encoded_str);*/
  return (char *) encoded_str;
}

void*
xid_bin_decode (const char* xid_str)
{
  int length = 0;
  virtXID * xid;
  caddr_t xid_ptr;
  int32 tmp;
  if (strlen(xid_str) != (sizeof(virtXID)*2))
    return 0;

  xid = (virtXID *) (xid_ptr = dk_alloc_box (sizeof (virtXID), DV_BIN));

  length = decode_ptr ((unsigned char*)xid_str, sizeof (int32) * 2, (unsigned char*) &tmp);
  xid->formatID = LONG_REF_NA (&tmp);

  length += decode_ptr ((unsigned char*) (xid_str + length), sizeof (int32) * 2, (unsigned char*) &tmp);
  xid->gtrid_length = LONG_REF_NA (&tmp);

  length += decode_ptr ((unsigned char*) (xid_str + length), sizeof (int32) * 2, (unsigned char*) &tmp);
  xid->bqual_length = LONG_REF_NA (&tmp);

  decode_ptr ((unsigned char*) (xid_str + length), (int) (strlen (xid_str) - length), (unsigned char*) xid->data);

  /*log_debug ("%s << %d %d %d", xid_str, xid->formatID, xid->gtrid_length, xid->bqual_length);*/

  return xid;

}


#else
char*
xid_bin_encode (void* xid)
{
  char* str_ptr;
  char* encoded_str = str_ptr = dk_alloc_box (sizeof(XID)*2 + 1 ,DV_STRING);
  unsigned char * xid_ptr = (unsigned char*)xid;
  unsigned char * xid_end = (unsigned char*)(xid) + sizeof(XID);
  while (xid_ptr != xid_end)
    {
      str_ptr[0] = char_16_table [xid_ptr[0] / 16];
      str_ptr[1] = char_16_table [xid_ptr[0] % 16];
      str_ptr+=2;
      xid_ptr++;
    }
  str_ptr[0]=0;
  return encoded_str;
}

void*
xid_bin_decode (const char* xid_str)
{
  XID * xid;
  caddr_t xid_ptr;
  const char * str_ptr = xid_str;
  if (strlen(xid_str) != (sizeof(XID)*2))
    return 0;

  xid = (XID *) (xid_ptr = dk_alloc_box (sizeof (XID), DV_BIN));
  while (str_ptr[0])
    {
#ifdef XID_DEBUG
      if (char_r_16_table[(int)str_ptr[0]] == -1 ||
	  char_r_16_table[(int)str_ptr[1]] == -1)
	GPF_T1 ("wrong xid string");
#endif
      xid_ptr[0] = (char) char_r_16_table[(int)str_ptr[0]] * 16 + (char) char_r_16_table[(int)str_ptr[1]];

      str_ptr+=2;
      xid_ptr++;
    }
  return xid;
}
#endif

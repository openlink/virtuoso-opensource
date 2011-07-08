/*
 *  mem.c
 *
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2011 OpenLink Software
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

#include "sqlnode.h"
#include "arith.h"
#include "simd.h"


void
memzero (void *ptr, int len)
{
#if defined(__GNUC__)
  unsigned int i;
  union
  {
    v4sf_t v4;
    int64 i[2];
  } zero;
  zero.i[0] = zero.i[1] = 0;
  for (i = 0; i + 16 <= len; i += 16)
    __builtin_ia32_storeups ((float *) (((char *) ptr) + i), zero.v4);
  for (i = i; i + 4 <= len; i += 4)
    *(int32 *) (((char *) ptr) + i) = 0;
  for (i = i; i < len; i++)
    ((char *) ptr)[i] = 0;
#else
  memset (ptr, 0, len);
#endif
}


void
memset_16 (void *ptr, unsigned char fill, int len)
{
#if defined(__GNUC__)
  unsigned int i;
  union
  {
    v4sf_t v4;
    int64 i[2];
    int32 i32[4];
  } zero;
  zero.i32[0] = fill | ((uint32) fill << 8) | ((uint32) fill << 16) | ((uint32) fill << 24);
  zero.i32[1] = zero.i32[0];
  zero.i[1] = zero.i[0];
  for (i = 0; i + 16 <= len; i += 16)
    __builtin_ia32_storeups ((float *) (((char *) ptr) + i), zero.v4);
  for (i = i; i + 4 <= len; i += 4)
    *(int32 *) (((char *) ptr) + i) = zero.i32[0];
  for (i = i; i < len; i++)
    ((char *) ptr)[i] = zero.i32[0];
#else
  memset (ptr, fill, len);
#endif
}


void
int_fill (int *ptr, int n, int len)
{
  unsigned int inx = 0;
#if defined(__GNUC__)
  if (len > 8)
    {
      union
      {
	v4sf_t v;
	int32 i[4];
      } data;
      data.i[0] = data.i[1] = data.i[2] = data.i[3] = n;
      for (inx = 0; inx + 4 < len; inx += 4)
	__builtin_ia32_storeups ((float *) (ptr + inx), data.v);
    }
#endif
  for (inx = inx; inx < len; inx++)
    ptr[inx] = n;
}


void
int64_fill (int64 * ptr, int64 n, int len)
{
  unsigned int inx = 0;
#if defined(__GNUC__)
  if (len > 4)
    {
      union
      {
	v4sf_t v;
	int64 i[2];
      } data;
      data.i[0] = data.i[1] = n;
      for (inx = 0; inx + 2 <= len; inx += 2)
	__builtin_ia32_storeups ((float *) (ptr + inx), data.v);
    }
#endif
  for (inx = inx; inx < len; inx++)
    ptr[inx] = n;
}


void
int64_fill_nt (int64 * ptr, int64 n, int len)
{
  unsigned int inx = 0;
#if defined(__GNUC__)
  if (len > 4)
    {
      union
      {
	v4sf_t v;
	int64 i[2];
      } data;
      data.i[0] = data.i[1] = n;
      if ((ptrlong) ptr & 0xf && len)
	{
	  *ptr = n;
	  ptr++;
	  len--;
	}
      for (inx = 0; inx + 2 <= len; inx += 2)
	__builtin_ia32_movntps ((float *) (ptr + inx), data.v);
    }
  __builtin_ia32_sfence ();
#endif
  for (inx = inx; inx < len; inx++)
    ptr[inx] = n;
}

void
int_asc_fill (int *ptr, int len, int start)
{
  unsigned int inx;
  for (inx = 0; inx < len; inx++)
    ptr[inx] = inx + start;
}


#define cpy(dtp) \
  {*(dtp*)target = *(dtp*)source; target += sizeof (dtp); source += sizeof (dtp);}

#define D_cpy(dtp) \
  { target -= sizeof (dtp); source -= sizeof (dtp); *(dtp*)target = *(dtp*)source;}

void
memcpy_16 (void *t, const void *s, size_t len)
{
#if defined(__GNUC__)
  char *target = (char *) t, *source = (char *) s;
  caddr_t end = target + (len & ~0xf);
  while (target < end)
    {
      __builtin_ia32_storeups ((float *) target, __builtin_ia32_loadups ((float *) source));
      target += 16;
      source += 16;
    }
  len &= 0xf;
  if (len >= 8)
    cpy (int64);
  switch (len & 0x7)
    {
    case 7: cpy (int32);
    case 3: cpy (short);
    case 1: cpy (char);
      break;
    case 6: cpy (int32);
    case 2: cpy (short);
      break;
    case 5: cpy (char);
    case 4: cpy (int32);
    default:
      break;
    }
#else
  memcpy (t, s, len);
#endif
}


void
memcpy_16_nt (void *t, const void *s, size_t len)
{
#if defined(__GNUC__)
  char *target = (char *) t, *source = (char *) s;
  caddr_t end = target + (len & ~0xf);
  while (target < end)
    {
      __builtin_ia32_storeups ((float *) target, __builtin_ia32_loadups ((float *) source));
      target += 16;
      source += 16;
    }
  len &= 0xf;
  if (len >= 8)
    cpy (int64);
  switch (len & 0x7)
    {
    case 7: cpy (int32);
    case 3: cpy (short);
    case 1: cpy (char);
      break;
    case 6: cpy (int32);
    case 2: cpy (short);
      break;
    case 5: cpy (char);
    case 4: cpy (int32);
    default:
      break;
    }
#else
  memcpy (t, s, len);
#endif
}

void
memmove_16 (void *t, const void *s, size_t len)
{
#if defined(__GNUC__)
  char *target = (char *) t, *source = (char *) s;
  caddr_t end;
  if (target > source && target < source + len)
    {
      end = target + (len & 0xf);
      target += len;
      source += len;
      while (target > end)
	{
	  target -= 16;
	  source -= 16;
	  __builtin_ia32_storeups ((float *) target, __builtin_ia32_loadups ((float *) source));
	}
      len &= 0xf;
      if (len >= 8)
	D_cpy (int64);
      switch (len & 0x7)
	{
	case 7: D_cpy (int32);
	case 3: D_cpy (short);
	case 1: D_cpy (char);
	  break;
	case 6: D_cpy (int32);
	case 2: D_cpy (short);
	  break;
	case 5: D_cpy (char);
	case 4: D_cpy (int32);
	default:
	  break;
	}
      return;
    }
  end = target + (len & ~0xf);
  while (target < end)
    {
      __builtin_ia32_storeups ((float *) target, __builtin_ia32_loadups ((float *) source));
      target += 16;
      source += 16;
    }
  len &= 0xf;
  if (len >= 8)
    cpy (int64);
  switch (len & 0x7)
    {
    case 7: cpy (int32);
    case 3: cpy (short);
    case 1: cpy (char);
      break;
    case 6: cpy (int32);
    case 2: cpy (short);
      break;
    case 5: cpy (char);
    case 4: cpy (int32);
    default:
      break;
    }
#else
  memmove (t, s, len);
#endif
}


unsigned
int64 rdtsc()
{
#ifndef WIN32
  uint32 lo, hi;
  __asm__ __volatile__ (      // serialize
			"xorl %%eax,%%eax \n        cpuid"
    ::: "%rax", "%rbx", "%rcx", "%rdx");
    /* We cannot use "=A", since this would use %rax on x86_64 and return only the lower 32bits of the TSC */
    __asm__ __volatile__ ("rdtsc" : "=a" (lo), "=d" (hi));
    return (uint64_t)hi << 32 | lo;
#else
    return 0;
#endif
}

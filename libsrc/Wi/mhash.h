/*
 *  mhash.h
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

#define MHASH_M  ((uint64) 0xc6a4a7935bd1e995)
#define MHASH_R 47


#define MHASH_STEP(h, data) \
{ \
  uint64 __k = data; \
      __k *= MHASH_M;  \
      __k ^= __k >> MHASH_R;  \
      __k *= MHASH_M;  \
      h ^= __k; \
      h *= MHASH_M; \
    }


#define MHASH_ID_STEP(h, data) \
{ \
  uint64 __k = data; \
  uint32 __k1 = __k; \
      __k *= MHASH_M;  \
      __k ^= __k >> MHASH_R;  \
      __k *= MHASH_M;  \
      h ^= __k; \
      h *= MHASH_M; \
      h = (h & 0xffffffff00000000) | __k1;	\
    }




#ifdef VALGRIND
#define MHASH_VAR(init, ptr, len) BYTE_BUFFER_HASH (init, ptr, len)
#else
#define MHASH_VAR(init, ptr, len)		\
{ \
    uint64 __h = init; \
  uint64 * data = (uint64*)ptr; \
  uint64 * end = (uint64*)(((ptrlong)data) + (len & ~7));	\
  while (data < end) \
    { \
      uint64 k  = *(data++); \
      k *= MHASH_M;  \
      k ^= k >> MHASH_R;  \
      k *= MHASH_M;  \
      __h ^= k; \
      __h *= MHASH_M; \
    } \
  if (len & 7) \
    { \
      uint64 k = *data; \
      k &= ((int64)1 << ((len & 7) << 3)) - 1;	\
      k *= MHASH_M;  \
      k ^= k >> MHASH_R;  \
      k *= MHASH_M;  \
      __h ^= k; \
      __h *= MHASH_M; \
    }\
  init = __h; \
}
#endif

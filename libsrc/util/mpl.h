/*
 *  mpl.h
 *
 *  $Id$
 *
 *  Mempory Pool Primitives
 *  Derived from obstack
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
 *  
*/

#ifndef _MPL_H
#define _MPL_H

/*
 *  Since DOS has segmented memory, we use normalized
 *  character pointers in some critical parts. (mpl_..)
 *  These pointers are memptr_t type.
 */
#if !defined(__COMPACT__) && !defined(__LARGE__) && !defined(__HUGE__)
typedef char *memptr_t;
#else
typedef char huge *memptr_t;
#endif

typedef ptr_long memdf_t;		/* Type for pointer difference */
typedef ptr_ulong memsz_t;		/* Type for memory size */

#define MPL_CHUNK_SIZE	4096

typedef struct mpc		/* Lives at front of each chunk. */
{
  struct mpc *mc_prev;		/* address of prior chunk or NULL */
  memptr_t mc_limit;		/* size of chunk */
} MPC;

typedef struct			/* control current object in current chunk */
{
  MPC *mp_chunk;		/* address of current MPL_chunk */
  memptr_t mp_base;		/* address of object we are building */
  memptr_t mp_next;		/* where to add next char to current object */
  memptr_t mp_limit;		/* address of char after current chunk */
} MPL;


#define mpl_1grow(mp, c)	\
	((((mp)->mp_next >= (mp)->mp_limit) ? (mpl_newchunk(mp, 1), 0) : 0),\
	*((mp)->mp_next)++ = (c))


BEGIN_CPLUSPLUS

memptr_t getcore (memsz_t size);
void	 freecore (memptr_t mem);
void     mpl_newchunk (MPL * mp, memsz_t length);
void     mpl_init (MPL * mp);
void     mpl_destroy (MPL * mp);
void     mpl_free (MPL * mp, memptr_t ptr);
memsz_t  mpl_object_size (MPL * mp);
memptr_t mpl_alloc (MPL * mp, memsz_t size);
memptr_t mpl_finish (MPL * mp);
memptr_t mpl_finish2 (MPL * mp, memsz_t *size);
memptr_t mpl_getmem (MPL * mp, memsz_t size);
memptr_t mpl_grow (MPL * mp, memptr_t addr, memsz_t len);

END_CPLUSPLUS

#endif

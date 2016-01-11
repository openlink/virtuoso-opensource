/*
 *  mpl.c
 *
 *  $Id$
 *
 *  Mempory Pool Primitives
 *  Derived from obstack
 *  
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *  
 *  Copyright (C) 1998-2016 OpenLink Software
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

#include "libutil.h"
#include "mpl.h"

#define MPL_CHUNK_SIZE	4096
#define MPL_ALIGNMENT	16

#define MPL_RNDUP(SZ,AL)	((((SZ) + AL - 1) / AL) * AL)
#define MPL_ALIGN(X)		MPL_RNDUP (X, MPL_ALIGNMENT)
#define MPL_ALIGNPTR(PTR)	((memptr_t) MPL_ALIGN ((memsz_t) (PTR)))
#define MPL_MCBASE(MC)		MPL_ALIGNPTR (((memptr_t) MC) + sizeof (MPC))

#ifdef MEMORY_DEBUG
# define MPL_DEBUG
#endif


memptr_t
getcore (memsz_t size)
{
  memptr_t mem;

  mem = (memptr_t) calloc (1, size);

#ifndef NO_LOG
  if (mem == (memptr_t) 0)
    {
# ifdef MPL_DEBUG
      fprintf (stderr, "get_core: out of memory\n");
      abort ();
# endif
      log (L_ERR, "out of memory");
      terminate (1);
    }
#endif

#ifdef MPL_DEBUG
  /* init to garbage, to trap uninit use */
  memset (mem, 0xFA, size);
#endif

  return mem;
}


void
freecore (memptr_t mem)
{
  free (mem);
}


void
mpl_newchunk (MPL * mp, memsz_t length)
{
  register memsz_t obj_size;
  MPC *mc;
  memsz_t new_size;
  memptr_t new_base;

  /* Old data */
  obj_size = mp->mp_next - mp->mp_base;

  /* Compute size for new chunk.  */
  new_size = (obj_size + length) + (obj_size >> 3) + 100;
  new_size = MPL_RNDUP (new_size, MPL_CHUNK_SIZE);

  /* Allocate new block and copy old data */
  mc = (MPC *) getcore (new_size);
  new_base = MPL_MCBASE (mc);
  memcpy (new_base, mp->mp_base, obj_size);

  /* If old chunk has no other data, free that */
  if (mp->mp_base == MPL_MCBASE (mp->mp_chunk))
    {
      mc->mc_prev = mp->mp_chunk->mc_prev;
      freecore ((memptr_t) mp->mp_chunk);
    }
  else
    mc->mc_prev = mp->mp_chunk;

  mp->mp_limit = mc->mc_limit = (memptr_t) mc + new_size;
  mp->mp_chunk = mc;
  mp->mp_base = new_base;
  mp->mp_next = new_base + obj_size;
}


void
mpl_init (MPL * mp)
{
  memset (mp, 0, sizeof (MPL));
}


void
mpl_destroy (MPL * mp)
{
  MPC *prev;
  MPC *p;

  for (p = mp->mp_chunk; p; p = prev)
    {
      prev = p->mc_prev;
      freecore ((memptr_t) p);
    }
  memset (mp, 0, sizeof (MPL));
  mpl_init (mp);
}


void
mpl_free (MPL * mp, memptr_t ptr)
{
  MPC *p;
  MPC *prev;

  if (ptr)
    {
      for (p = mp->mp_chunk; p; p = prev)
	{
	  if (MPL_MCBASE (p) <= ptr && ptr < p->mc_limit)
	    {
	      mp->mp_base = mp->mp_next = ptr;
	      mp->mp_chunk = p;
	      mp->mp_limit = mp->mp_chunk->mc_limit;
	      return;
	    }
	  prev = p->mc_prev;
	  freecore ((memptr_t) p);
	}

#ifdef MPL_DEBUG
      fprintf (stderr, "mpl_free: bad address\n");
#endif
      mpl_init (mp);
    }
  else
    mp->mp_next = mp->mp_base;
}


memsz_t
mpl_object_size (MPL * mp)
{
  return mp->mp_next - mp->mp_base;
}


/*
 *  Reserve memory in the pool.
 *  Can be used for structures, since data is aligned.
 *  Assumes mpl is aligned on input.
 */
memptr_t
mpl_alloc (MPL * mp, memsz_t size)
{
  memptr_t base = mp->mp_next;
  if (base + size >= mp->mp_limit)
    {
      mpl_newchunk (mp, size);
      base = mp->mp_next;
    }
  mp->mp_next = MPL_ALIGNPTR (base + size);
  return base;
}


void
mpl_align (MPL * mp)
{
  mp->mp_next = MPL_ALIGNPTR (mp->mp_next);
}


/*
 *  Finished memory growth on current chunk and returns a pointer
 *  to the first byte.
 *  mpl is aligned on output.
 */
memptr_t
mpl_finish (MPL * mp)
{
  memptr_t base = mp->mp_base;
  mp->mp_base = mp->mp_next = MPL_ALIGNPTR (mp->mp_next);
  return base;
}


memptr_t
mpl_finish2 (MPL * mp, memsz_t *size)
{
  memptr_t base = mp->mp_base;
  *size = mp->mp_next - base;
  mp->mp_base = mp->mp_next = MPL_ALIGNPTR (mp->mp_next);
  return base;
}


memptr_t
mpl_getmem (MPL * mp, memsz_t size)
{
  mpl_alloc (mp, size);
  return mpl_finish (mp);
}


/*
 *  Copy data to the pool.
 *  Do not use with structures, because the memory is not necessarily aligned
 *
 *  If mpl_alloc or mpl_getmem is required after an mpl_grow (mpl_1grow),
 *  call mpl_align or mpl_finish first.
 *
 *  Note: the returned pointer is only valid until the pool is reallocated.
 *        It's only intended use is an immediate memcpy.
 */
memptr_t
mpl_grow (MPL * mp, memptr_t addr, memsz_t len)
{
  memptr_t base;

  if (mp->mp_next + len >= mp->mp_limit)
    mpl_newchunk (mp, len);
  base = mp->mp_next;
  memcpy (base, addr, len);
  mp->mp_next += len;

  return base;
}


#ifdef MPL_DEBUG
#include <assert.h>

void
mpl_dump (MPL * mp, char *where)
{
  memsz_t total;
  MPC *p;
  int i = 0;

  puts (where);
  total = 0;
  for (p = mp->mp_chunk; p; p = p->mc_prev)
    {
      memsz_t size = p->mc_limit - MPL_MCBASE (p);
      total += size;
      assert (size < MPL_CHUNK_SIZE);
      i++;
    }

  printf ("Stored %lu bytes in %d chunks\n", (unsigned long) total, i);
  printf ("Current mp: base=%p, next=%p limit=%p chunk=%p\n",
      mp->mp_base, mp->mp_next, mp->mp_limit, mp->mp_chunk);
  printf ("            stored=%ld remaining=%ld size=%ld\n",
      (long) (mp->mp_next - mp->mp_base),
      (long) (mp->mp_limit - mp->mp_next),
      (long) (mp->mp_limit - mp->mp_base));
}
#endif


#ifdef MPL_TESTCODE
char *pp[2000];

int
main ()
{
  MPL xx;
  int i, j, k;
  char *cp;

  mpl_init (&xx);

  for (k = 0; k < 100; k++)
    {
      for (j = 0; j < 200; j++)
	{
	  for (i = 0; i < 100; i++)
	    mpl_grow (&xx, "ABCDEFGHIJ", 10);
	  mpl_1grow (&xx, 0);
	  pp[j] = cp = mpl_finish (&xx);
	}
      fflush (stdout);
      mpl_free (&xx, pp[k % 10]);
    }
  mpl_dump (&xx, "test1");
  mpl_free (&xx, pp[0]);
  for (j = 0; j < 2000; j++)
    {
      pp[j] = cp = mpl_getmem (&xx, 200);
      for (k = 0; k < 200; k++)
	cp[k] = j & 0x7f;
    }
  for (j = 0; j < 2000; j++)
    {
      cp = pp[j];
      for (k = 0; k < 200; k++)
	assert (cp[k] == (j & 0x7f));
    }
  mpl_dump (&xx, "test2");

  mpl_destroy (&xx);

  mpl_1grow (&xx, 0);
  mpl_align (&xx);
  mpl_dump (&xx, "test3");

  return 0;
}
#endif

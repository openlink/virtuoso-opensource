/*
 * Two Levels Segregate Fit memory allocator (TLSF)
 * Version 2.4.6
 *
 * Written by Miguel Masmano Tello <mimastel@doctor.upv.es>
 *
 * Thanks to Ismael Ripoll for his suggestions and reviews
 *
 * Copyright (C) 2008, 2007, 2006, 2005, 2004
 *
 * This code is released using a dual license strategy: GPL/LGPL
 * You can choose the licence that better fits your requirements.
 *
 * Released under the terms of the GNU General Public License Version 2.0
 * Released under the terms of the GNU Lesser General Public License Version 2.1
 *
 */

#ifndef _TLSF_H_
#define _TLSF_H_

#include <sys/types.h>

extern size_t init_memory_pool(size_t, void *);
extern size_t get_used_size(void *);
extern size_t get_max_size(void *);
extern void destroy_memory_pool(void *);
extern size_t add_new_area(void *, size_t, void *);
extern void *malloc_ex(size_t, void *);
extern void free_ex(void *, void *);
extern void *realloc_ex(void *, size_t, void *);
extern void *calloc_ex(size_t, size_t, void *);

extern void *tlsf_malloc(DBG_PARAMS size_t size, du_thread_t * thr);
extern void tlsf_free(void *ptr);
extern void * tlsf_id_alloc (size_t sz, short tlsf_id);
extern void * tlsf_base_alloc (size_t c);
extern void tlsf_base_free (void * c, size_t sz);


/*#define USE_SBRK        (0) */
#define USE_MMAP        (1) 
#define _DEBUG_TLSF_ 1
#define TLSF_STATISTIC 1
#define USE_PRINTF 1
#define TLSF_USE_LOCKS 1

#ifndef USE_PRINTF
#define USE_PRINTF      (1)
#endif

#include <string.h>

#ifndef TLSF_USE_LOCKS
#define	TLSF_USE_LOCKS 	(0)
#endif

#ifndef TLSF_STATISTIC
#define	TLSF_STATISTIC 	(0)
#endif

#ifndef USE_MMAP
#define	USE_MMAP 	(0)
#endif

#ifndef USE_SBRK
#define	USE_SBRK 	(0)
#endif


#if TLSF_USE_LOCKS
#include "target.h"
#else
#define TLSF_CREATE_LOCK(_unused_)   do{}while(0)
#define TLSF_DESTROY_LOCK(_unused_)  do{}while(0) 
#define TLSF_ACQUIRE_LOCK(_unused_)  do{}while(0)
#define TLSF_RELEASE_LOCK(_unused_)  do{}while(0)
#endif

#if TLSF_STATISTIC
#define	TLSF_ADD_SIZE(tlsf, b) do {									\
    tlsf->used_size += ((int)b->size & BLOCK_SIZE) + BHDR_OVERHEAD;	\
		if (tlsf->used_size > tlsf->max_size) 						\
			tlsf->max_size = tlsf->used_size;						\
		} while(0)

#define	TLSF_REMOVE_SIZE(tlsf, b) do {								\
    tlsf->used_size -= ((int)b->size & BLOCK_SIZE) + BHDR_OVERHEAD;	\
	} while(0)
#else
#define	TLSF_ADD_SIZE(tlsf, b)	     do{}while(0)
#define	TLSF_REMOVE_SIZE(tlsf, b)    do{}while(0)
#endif

#if USE_MMAP || USE_SBRK
#include <unistd.h>
#endif

#if USE_MMAP
#include <sys/mman.h>
#endif

#include "tlsf.h"

#if !defined(__GNUC__)
#ifndef __inline__
#define __inline__
#endif
#endif

/* The  debug functions  only can  be used  when _DEBUG_TLSF_  is set. */
#ifndef _DEBUG_TLSF_
#define _DEBUG_TLSF_  (0)
#endif

/*************************************************************************/
/* Definition of the structures used by TLSF */


/* Some IMPORTANT TLSF parameters */
/* Unlike the preview TLSF versions, now they are statics */
#define BLOCK_ALIGN (sizeof(void *) * 2)

#define MAX_FLI		(30)
#define MAX_LOG2_SLI	(5)
#define MAX_SLI		(1 << MAX_LOG2_SLI)     /* MAX_SLI = 2^MAX_LOG2_SLI */

#define FLI_OFFSET	(6)     /* tlsf structure just will manage blocks bigger */
/* than 128 bytes */
#define SMALL_BLOCK	(128)
#define REAL_FLI	(MAX_FLI - FLI_OFFSET)
#define MIN_BLOCK_SIZE	(sizeof (free_ptr_t))
#define BHDR_OVERHEAD	(sizeof (bhdr_t) - MIN_BLOCK_SIZE)
#define TLSF_SIGNATURE	(0x2A59FA59)

#define	PTR_MASK	(sizeof(void *) - 1)
#define BLOCK_SIZE	(0xFFFFFFFF - PTR_MASK)

#define GET_NEXT_BLOCK(_addr, _r) ((bhdr_t *) ((char *) (_addr) + (_r)))
#define	MEM_ALIGN		  ((BLOCK_ALIGN) - 1)
#define ROUNDUP_SIZE(_r)          (((_r) + MEM_ALIGN) & ~MEM_ALIGN)
#define ROUNDDOWN_SIZE(_r)        ((_r) & ~MEM_ALIGN)
#define ROUNDUP(_x, _v)           ((((~(_x)) + 1) & ((_v)-1)) + (_x))

#define BLOCK_STATE	(0x1)
#define PREV_STATE	(0x2)

/* bit 0 of the block size */
#define FREE_BLOCK	(0x1)
#define USED_BLOCK	(0x0)

/* bit 1 of the block size */
#define PREV_FREE	(0x2)
#define PREV_USED	(0x0)


#define DEFAULT_AREA_SIZE (1024*10)

#ifdef USE_MMAP
#define PAGE_SIZE (getpagesize())
#endif

#ifdef USE_PRINTF
#include <stdio.h>
# define PRINT_MSG(fmt, args...) fprintf(tlsf_fp, fmt, ## args)
# define ERROR_MSG(fmt, args...) printf(fmt, ## args)
#else
# if !defined(PRINT_MSG)
#  define PRINT_MSG(fmt, args...)
# endif
# if !defined(ERROR_MSG)
#  define ERROR_MSG(fmt, args...)
# endif
#endif

typedef unsigned int u32_t;     /* NOTE: Make sure that this type is 4 bytes long on your computer */
typedef unsigned char u8_t;     /* NOTE: Make sure that this type is 1 byte on your computer */

typedef struct free_ptr_struct {
    struct bhdr_struct *prev;
    struct bhdr_struct *next;
} free_ptr_t;

typedef struct bhdr_struct {
    /* This pointer is just valid if the first bit of size is set */
    struct bhdr_struct *prev_hdr;
    /* The size is stored in bytes */
    uint32 size;                /* bit 0 indicates whether the block is used and */
    /* bit 1 allows to know whether the previous block is free */
  uint32	bhdr_info; /* source tlsf and optional code  of alloc file/line */
    union {
        struct free_ptr_struct free_ptr;
        u8_t buffer[1];         /*sizeof(struct free_ptr_struct)]; */
    } ptr;
} bhdr_t;

/* This structure is embedded at the beginning of each area, giving us
 * enough information to cope with a set of areas */

typedef struct area_info_struct {
    bhdr_t *end;
    struct area_info_struct *next;
} area_info_t;

typedef struct TLSF_struct {
    /* the TLSF's structure signature */
    u32_t tlsf_signature;
#if TLSF_USE_LOCKS
  dk_mutex_t tlsf_mtx;
#endif

#if TLSF_STATISTIC
    /* These can not be calculated outside tlsf because we
     * do not know the sizes when freeing/reallocing memory. */
    size_t used_size;
    size_t max_size;
#endif
    size_t	tlsf_total_mapped;
    /* A linked list holding all the existing areas */
    area_info_t *area_head;

  char	tlsf_on_thread;
  short	tlsf_id; /* index in table of all tlsfs */
    /* the first-level bitmap */
    /* This array should have a size of REAL_FLI bits */
    u32_t fl_bitmap;

    /* the second-level bitmap */
    u32_t sl_bitmap[REAL_FLI];

    bhdr_t *matrix[REAL_FLI][MAX_SLI];
  size_t	tlsf_grow_quantum;
  dk_hash_t	tlsf_large_alloc;
  caddr_t	tlsf_comment;
  struct mem_pool_s *	tlsf_mp;
#ifdef MALLOC_DEBUG
  id_hash_t *	tlsf_allocs;
#endif
} tlsf_t;


#define TLSF_IN_MP 4095 /* temp tlsf not in dk_all_tlsfs */
#define MAX_TLSFS 4095
#define TLSF_ID_MASK 4095
extern tlsf_t * dk_base_tlsf;
extern size_t tlsf_mmap_threshold;
extern tlsf_t * dk_all_tlsfs[MAX_TLSFS];

/* tlsf_on_thread */
#define TLSF_STATIC 0
#define TLSF_BOUND 1
#define TLSF_FREE 2

void thr_set_tlsf (du_thread_t * thr, tlsf_t * tlsf);
tlsf_t * tlsf_new (size_t size);
void tlsf_destroy (tlsf_t * tlsf);
tlsf_t * tlsf_get ();
void tlsf_set_comment (tlsf_t * tlsf, char * name);

#define BHDR(b)  ((bhdr_t*)(((char*)b) - BHDR_OVERHEAD))


#ifdef MALLOC_DEBUG

typedef struct mdbg_place_s
{
  char *	mpl_file;
  int		mpl_line;
} mdbg_place_t;


typedef struct mdbg_stat_s
{
  uint32	mds_allocs;
  uint32	mds_frees;
  size_t	mds_bytes;
  size_t	mds_prev_bytes;
} mdbg_stat_t;

extern tlsf_t * mdbg_tlsf;
void tlsf_mdbg_init ();
void tlsf_mdbg_alloc (tlsf_t * tlsf, const char * f, int l, bhdr_t * b);
void tlsf_mdbg_free (tlsf_t * tlsf, bhdr_t * b);
void tlsf_all_in_use (FILE * out, int mode, int nth);
#endif
void tlsf_summary (FILE * out);
size_t tlsf_get_total (size_t * mapped_ret);
size_t  tlsf_block_size (caddr_t ptr);
char * tlsf_check_alloc (void * ptr);
int tlsf_check (tlsf_t * tlsf, int mode);
void tlsf_print_all_blocks(tlsf_t * tlsf, void * ht1, int mode);
#define AB_ALL 0 /* print all blocks, free and allocd */
#define AB_FILL 1 /* put allocd in ht */
#define AB_EXCEPT 2 /* print allocd except ones in ht */
#define AB_ALLOCD 3 /* print all allocd */
#endif


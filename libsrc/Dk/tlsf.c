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

/*
 * Code contributions:
 *
 * (Jul 28 2007)  Herman ten Brugge <hermantenbrugge@home.nl>:
 *
 * - Add 64 bit support. It now runs on x86_64 and solaris64.
 * - I also tested this on vxworks/32and solaris/32 and i386/32 processors.
 * - Remove assembly code. I could not measure any performance difference 
 *   on my core2 processor. This also makes the code more portable.
 * - Moved defines/typedefs from tlsf.h to tlsf.c
 * - Changed MIN_BLOCK_SIZE to sizeof (free_ptr_t) and BHDR_OVERHEAD to 
 *   (sizeof (bhdr_t) - MIN_BLOCK_SIZE). This does not change the fact 
 *    that the minumum size is still sizeof 
 *   (bhdr_t).
 * - Changed all C++ comment style to C style. (// -> /.* ... *./)
 * - Used ls_bit instead of ffs and ms_bit instead of fls. I did this to 
 *   avoid confusion with the standard ffs function which returns 
 *   different values.
 * - Created set_bit/clear_bit fuctions because they are not present 
 *   on x86_64.
 * - Added locking support + extra file target.h to show how to use it.
 * - Added get_used_size function (REMOVED in 2.4)
 * - Added rtl_realloc and rtl_calloc function
 * - Implemented realloc clever support.
 * - Added some test code in the example directory.
 * - Bug fixed (discovered by the rockbox project: www.rockbox.org).       
 *
 * (Oct 23 2006) Adam Scislowicz: 
 *
 * - Support for ARMv5 implemented
 *
 */

#include "Dk.h"
#include "mhash.h"

FILE * tlsf_fp;

/******************************************************************/
/**************     Helping functions    **************************/
/******************************************************************/
static __inline__ void set_bit(int nr, u32_t * addr);
static __inline__ void clear_bit(int nr, u32_t * addr);
static __inline__ int ls_bit(int x);
static __inline__ int ms_bit(int x);
static __inline__ void MAPPING_SEARCH(size_t * _r, int *_fl, int *_sl);
static __inline__ void MAPPING_INSERT(size_t _r, int *_fl, int *_sl);
static __inline__ bhdr_t *FIND_SUITABLE_BLOCK(tlsf_t * _tlsf, int *_fl, int *_sl);
static __inline__ bhdr_t *process_area(void *area, size_t size);
static __inline__ void *get_new_area(tlsf_t * tlsf, size_t * size);

#ifdef WIN32
int getpagesize()
{
  SYSTEM_INFO si;
  GetSystemInfo(&si);
  return si.dwPageSize;
}
#endif

static const int table[] = {
    -1, 0, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 3, 3, 3, 3, 4, 4, 4, 4, 4, 4, 4,
    4, 4,
    4, 4, 4, 4, 4, 4, 4,
    5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5,
    5,
    5, 5, 5, 5, 5, 5, 5,
    6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6,
    6,
    6, 6, 6, 6, 6, 6, 6,
    6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6,
    6,
    6, 6, 6, 6, 6, 6, 6,
    7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7,
    7,
    7, 7, 7, 7, 7, 7, 7,
    7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7,
    7,
    7, 7, 7, 7, 7, 7, 7,
    7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7,
    7,
    7, 7, 7, 7, 7, 7, 7,
    7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7,
    7,
    7, 7, 7, 7, 7, 7, 7
};

static __inline__ int ls_bit(int i)
{
    unsigned int a;
    unsigned int x = i & -i;

    a = x <= 0xffff ? (x <= 0xff ? 0 : 8) : (x <= 0xffffff ? 16 : 24);
    return table[x >> a] + a;
}

static __inline__ int ms_bit(int i)
{
    unsigned int a;
    unsigned int x = (unsigned int) i;

    a = x <= 0xffff ? (x <= 0xff ? 0 : 8) : (x <= 0xffffff ? 16 : 24);
    return table[x >> a] + a;
}

static __inline__ void set_bit(int nr, u32_t * addr)
{
    addr[nr >> 5] |= 1 << (nr & 0x1f);
}

static __inline__ void clear_bit(int nr, u32_t * addr)
{
    addr[nr >> 5] &= ~(1 << (nr & 0x1f));
}

static __inline__ void MAPPING_SEARCH(size_t * _r, int *_fl, int *_sl)
{
    int _t;

    if (*_r < SMALL_BLOCK) {
        *_fl = 0;
        *_sl = *_r / (SMALL_BLOCK / MAX_SLI);
    } else {
        _t = (1 << (ms_bit(*_r) - MAX_LOG2_SLI)) - 1;
        *_r = *_r + _t;
        *_fl = ms_bit(*_r);
        *_sl = (*_r >> (*_fl - MAX_LOG2_SLI)) - MAX_SLI;
        *_fl -= FLI_OFFSET;
        /*if ((*_fl -= FLI_OFFSET) < 0) // FL wil be always >0!
         *_fl = *_sl = 0;
         */
        *_r &= ~_t;
    }
}

static __inline__ void MAPPING_INSERT(size_t _r, int *_fl, int *_sl)
{
    if (_r < SMALL_BLOCK) {
        *_fl = 0;
        *_sl = _r / (SMALL_BLOCK / MAX_SLI);
    } else {
        *_fl = ms_bit(_r);
        *_sl = (_r >> (*_fl - MAX_LOG2_SLI)) - MAX_SLI;
        *_fl -= FLI_OFFSET;
    }
}


static __inline__ bhdr_t *FIND_SUITABLE_BLOCK(tlsf_t * _tlsf, int *_fl, int *_sl)
{
    u32_t _tmp = _tlsf->sl_bitmap[*_fl] & (~0 << *_sl);
    bhdr_t *_b = NULL;

    if (_tmp) {
        *_sl = ls_bit(_tmp);
        _b = _tlsf->matrix[*_fl][*_sl];
    } else {
        *_fl = ls_bit(_tlsf->fl_bitmap & (~0 << (*_fl + 1)));
        if (*_fl > 0) {         /* likely */
            *_sl = ls_bit(_tlsf->sl_bitmap[*_fl]);
            _b = _tlsf->matrix[*_fl][*_sl];
        }
    }
    return _b;
}


#define EXTRACT_BLOCK_HDR(_b, _tlsf, _fl, _sl) do {					\
		_tlsf -> matrix [_fl] [_sl] = _b -> ptr.free_ptr.next;		\
		if (_tlsf -> matrix[_fl][_sl])								\
			_tlsf -> matrix[_fl][_sl] -> ptr.free_ptr.prev = NULL;	\
		else {														\
			clear_bit (_sl, &_tlsf -> sl_bitmap [_fl]);				\
			if (!_tlsf -> sl_bitmap [_fl])							\
				clear_bit (_fl, &_tlsf -> fl_bitmap);				\
		}															\
		_b -> ptr.free_ptr.prev =  NULL;				\
		_b -> ptr.free_ptr.next =  NULL;				\
	}while(0)


#define EXTRACT_BLOCK(_b, _tlsf, _fl, _sl) do {							\
		if (_b -> ptr.free_ptr.next)									\
			_b -> ptr.free_ptr.next -> ptr.free_ptr.prev = _b -> ptr.free_ptr.prev; \
		if (_b -> ptr.free_ptr.prev)									\
			_b -> ptr.free_ptr.prev -> ptr.free_ptr.next = _b -> ptr.free_ptr.next; \
		if (_tlsf -> matrix [_fl][_sl] == _b) {							\
			_tlsf -> matrix [_fl][_sl] = _b -> ptr.free_ptr.next;		\
			if (!_tlsf -> matrix [_fl][_sl]) {							\
				clear_bit (_sl, &_tlsf -> sl_bitmap[_fl]);				\
				if (!_tlsf -> sl_bitmap [_fl])							\
					clear_bit (_fl, &_tlsf -> fl_bitmap);				\
			}															\
		}																\
		_b -> ptr.free_ptr.prev = NULL;					\
		_b -> ptr.free_ptr.next = NULL;					\
	} while(0)

#define INSERT_BLOCK(_b, _tlsf, _fl, _sl) do {							\
		_b -> ptr.free_ptr.prev = NULL; \
		_b -> ptr.free_ptr.next = _tlsf -> matrix [_fl][_sl]; \
		if (_tlsf -> matrix [_fl][_sl])									\
			_tlsf -> matrix [_fl][_sl] -> ptr.free_ptr.prev = _b;		\
		_tlsf -> matrix [_fl][_sl] = _b;								\
		set_bit (_sl, &_tlsf -> sl_bitmap [_fl]);						\
		set_bit (_fl, &_tlsf -> fl_bitmap);								\
	} while(0)

static __inline__ void *get_new_area(tlsf_t * tlsf, size_t * size) 
{
    void *area;

#if USE_SBRK
    area = (void *)sbrk(0);
    if (((void *)sbrk(*size)) != ((void *) -1))
        return area;
#endif

#ifndef MAP_ANONYMOUS
/* https://dev.openwrt.org/ticket/322 */
# define MAP_ANONYMOUS MAP_ANON
#endif


#if USE_MMAP
    if (tlsf->tlsf_mp)
      {
	int nth;
	*size = mm_next_size (*size, &nth);
	area = mp_large_alloc (tlsf->tlsf_mp, *size);
	return area ? area : ((void *) ~0);

      }
    *size = ROUNDUP(*size, PAGE_SIZE);
    if ((area = mmap(0, *size, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0)) != MAP_FAILED)
        return area;
#else
  *size = ROUNDUP(*size, PAGE_SIZE);
  if ((area = malloc(*size)) != NULL)
    return area;
#endif
    return ((void *) ~0);
}

static __inline__ bhdr_t *process_area(void *area, size_t size)
{
    bhdr_t *b, *lb, *ib;
    area_info_t *ai;

    ib = (bhdr_t *) area;
    ib->size =
        (sizeof(area_info_t) <
         MIN_BLOCK_SIZE) ? MIN_BLOCK_SIZE : ROUNDUP_SIZE(sizeof(area_info_t)) | USED_BLOCK | PREV_USED;
    b = (bhdr_t *) GET_NEXT_BLOCK(ib->ptr.buffer, ib->size & BLOCK_SIZE);
    b->size = ROUNDDOWN_SIZE(size - 3 * BHDR_OVERHEAD - (ib->size & BLOCK_SIZE)) | USED_BLOCK | PREV_USED;
    b->ptr.free_ptr.prev = b->ptr.free_ptr.next = 0;
    lb = GET_NEXT_BLOCK(b->ptr.buffer, b->size & BLOCK_SIZE);
    lb->prev_hdr = b;
    lb->size = 0 | USED_BLOCK | PREV_FREE;
    ai = (area_info_t *) ib->ptr.buffer;
    ai->next = 0;
    ai->end = lb;
    return ib;
}

void 
tlsf_printf (char * fmt, ...)
{
  va_list ap;
  va_start (ap, fmt);
  vfprintf (tlsf_fp, fmt, ap);
  va_end (ap);
}

/******************************************************************/
/******************** Begin of the allocator code *****************/
/******************************************************************/

/******************************************************************/
size_t init_memory_pool(size_t mem_pool_size, void *mem_pool)
{
/******************************************************************/
    tlsf_t *tlsf;
    bhdr_t *b, *ib;

    if (!mem_pool || !mem_pool_size || mem_pool_size < sizeof(tlsf_t) + BHDR_OVERHEAD * 8) {
        ERROR_MSG("init_memory_pool (): memory_pool invalid\n");
        return -1;
    }

    if (((unsigned long) mem_pool & PTR_MASK)) {
        ERROR_MSG("init_memory_pool (): mem_pool must be aligned to a word\n");
        return -1;
    }
    tlsf = (tlsf_t *) mem_pool;

    /* Zeroing the memory pool */
    memset(mem_pool, 0, sizeof(tlsf_t));

    tlsf->tlsf_signature = TLSF_SIGNATURE;

    dk_mutex_init(&tlsf->tlsf_mtx, MUTEX_TYPE_SHORT);
    tlsf->tlsf_total_mapped = _RNDUP_PWR2 (mem_pool_size, 4096);
    ib = process_area(GET_NEXT_BLOCK
                      (mem_pool, ROUNDUP_SIZE(sizeof(tlsf_t))), ROUNDDOWN_SIZE(mem_pool_size - sizeof(tlsf_t)));
    b = GET_NEXT_BLOCK(ib->ptr.buffer, ib->size & BLOCK_SIZE);
    free_ex(b->ptr.buffer, tlsf);
    tlsf->area_head = (area_info_t *) ib->ptr.buffer;

#if TLSF_STATISTIC
    tlsf->used_size = mem_pool_size - (b->size & BLOCK_SIZE);
    tlsf->max_size = tlsf->used_size;
#endif

    return (b->size & BLOCK_SIZE);
}

/******************************************************************/
size_t add_new_area(void *area, size_t area_size, void *mem_pool)
{
/******************************************************************/
    tlsf_t *tlsf = (tlsf_t *) mem_pool;
    area_info_t *ai;
    bhdr_t *ib0, *b0, *lb0;
#ifdef TLSF_32BIT_ONLY
    area_info_t *ptr, *ptr_prev;
    ptr = tlsf->area_head;
    ptr_prev = 0;
#endif

    memset(area, 0, area_size);

    ib0 = process_area(area, area_size);
    b0 = GET_NEXT_BLOCK(ib0->ptr.buffer, ib0->size & BLOCK_SIZE);
    lb0 = GET_NEXT_BLOCK(b0->ptr.buffer, b0->size & BLOCK_SIZE);

    /* Before inserting the new area, we have to merge this area with the already existing ones */
#ifdef TLSF_32BIT_ONLY /* sizes are 32 bit and addresses are 64.  Cannot merge areas if result were over 4G in size.  Do not merge at all */
    while (ptr) {
        bhdr_t *ib1 = (bhdr_t *) ((char *) ptr - BHDR_OVERHEAD);
        bhdr_t *b1 = GET_NEXT_BLOCK(ib1->ptr.buffer, ib1->size & BLOCK_SIZE);
        bhdr_t *lb1 = ptr->end;

        /* Merging the new area with the next physically contigous one */
        if ((unsigned long) ib1 == (unsigned long) lb0 + BHDR_OVERHEAD) {
            if (tlsf->area_head == ptr) {
                tlsf->area_head = ptr->next;
                ptr = ptr->next;
            } else {
                ptr_prev->next = ptr->next;
                ptr = ptr->next;
            }

            b0->size =
                ROUNDDOWN_SIZE((b0->size & BLOCK_SIZE) +
                               (ib1->size & BLOCK_SIZE) + 2 * BHDR_OVERHEAD) | USED_BLOCK | PREV_USED;

            b1->prev_hdr = b0;
            lb0 = lb1;

            continue;
        }

        /* Merging the new area with the previous physically contigous
           one */
        if ((unsigned long) lb1->ptr.buffer == (unsigned long) ib0) {
            bhdr_t *next_b;
            if (tlsf->area_head == ptr) {
                tlsf->area_head = ptr->next;
                ptr = ptr->next;
            } else {
                ptr_prev->next = ptr->next;
                ptr = ptr->next;
            }

            lb1->size =
                ROUNDDOWN_SIZE((b0->size & BLOCK_SIZE) +
                               (ib0->size & BLOCK_SIZE) + 2 * BHDR_OVERHEAD) | USED_BLOCK | (lb1->size & PREV_STATE);
            next_b = GET_NEXT_BLOCK(lb1->ptr.buffer, lb1->size & BLOCK_SIZE);
            next_b->prev_hdr = lb1;
            b0 = lb1;
            ib0 = ib1;

            continue;
        }
        ptr_prev = ptr;
        ptr = ptr->next;
    }
#endif
    /* Inserting the area in the list of linked areas */
    ai = (area_info_t *) ib0->ptr.buffer;
    ai->next = tlsf->area_head;
    ai->end = lb0;
    tlsf->area_head = ai;
    free_ex(b0->ptr.buffer, mem_pool);
    TLSF_ADD_SIZE (tlsf, b0);
    return (b0->size & BLOCK_SIZE);
}


/******************************************************************/
size_t get_used_size(void *mem_pool)
{
/******************************************************************/
#if TLSF_STATISTIC
    return ((tlsf_t *) mem_pool)->used_size;
#else
    return 0;
#endif
}

/******************************************************************/
size_t get_max_size(void *mem_pool)
{
/******************************************************************/
#if TLSF_STATISTIC
    return ((tlsf_t *) mem_pool)->max_size;
#else
    return 0;
#endif
}

/******************************************************************/
void destroy_memory_pool(void *mem_pool)
{
/******************************************************************/
    tlsf_t *tlsf = (tlsf_t *) mem_pool;

    tlsf->tlsf_signature = 0;
    dk_mutex_destroy (&tlsf->tlsf_mtx);
}

#define TLSF_SIZE_MMAP 0xffffffff  /* if block mmap'd outside of tlsf area, this is size in bhdr, actual size if int64 below bhdr */
#define BHDR_MMAP_SIZE(bhdr) *(&((int64*)bhdr)[-1])


size_t 
tlsf_block_size (caddr_t ptr)
{
  bhdr_t * b = BHDR (ptr);
  if (TLSF_SIZE_MMAP == b->size)
    {
      return BHDR_MMAP_SIZE (b) - (BHDR_OVERHEAD + sizeof (int64));
    }
  if ((FREE_BLOCK & b->size))
    GPF_T1 ("tlsf length of free b,block by bhdr free bit");
  return b->size;
}




void*
tlsf_large_alloc (tlsf_t * tlsf, size_t size)
{
  void * ret;
  size_t min_alloc = size + BHDR_OVERHEAD + sizeof (int64), alloc_size;
  int nth;
  bhdr_t * bhdr;
  alloc_size = mm_next_size (min_alloc, &nth);
  ret = mm_large_alloc (alloc_size);
  memzero (ret, BHDR_OVERHEAD + sizeof (int64));
  bhdr = (bhdr_t*)(((char*)ret) + sizeof (int64));
  *(int64*)ret = alloc_size;
  bhdr->bhdr_info = tlsf->tlsf_id;
  bhdr->size = TLSF_SIZE_MMAP;
  return (void*)bhdr->ptr.buffer;
}


int no_place_limit = 0;


void *
tlsf_malloc(DBG_PARAMS size_t size, du_thread_t * thr)
{
  tlsf_t * tlsf = !thr ? dk_base_tlsf : thr->thr_tlsf;
  void *ret;
  if (!tlsf)
    {
      tlsf = dk_base_tlsf;
      if (!tlsf)
	tlsf = dk_base_tlsf = tlsf_new (1000000);
    }

  if (size >= tlsf_mmap_threshold)
    ret =  tlsf_large_alloc (tlsf, size);
  else
    {
      mutex_enter(&tlsf->tlsf_mtx);
      ret = malloc_ex(size, tlsf);
      mutex_leave(&tlsf->tlsf_mtx);
    }
#ifdef MALLOC_DEBUG
  tlsf_mdbg_alloc (tlsf, file, line,  BHDR (ret));
#endif
  if (no_place_limit && tlsf == dk_base_tlsf && tlsf_check (tlsf, 2) > no_place_limit) 
    printf ("over %d\n", no_place_limit);
  return ret;
}

#if defined (WIN32) || defined (SOLARIS)
#define __builtin_prefetch(m) 
#endif

void 
tlsf_free(void *ptr)
{
  bhdr_t * bhdr = (bhdr_t*) (((char*)ptr) - BHDR_OVERHEAD);
  short tlsf_id = bhdr->bhdr_info & TLSF_ID_MASK;
  uint32 size = bhdr->size  & BLOCK_SIZE;
  tlsf_t * tlsf = dk_all_tlsfs[tlsf_id];
  if (tlsf->tlsf_id != tlsf_id && size < tlsf_mmap_threshold) GPF_T1 ("bad tlsf in block header in free");
#ifdef MALLOC_DEBUG
  tlsf_mdbg_free (tlsf, BHDR (ptr));
#endif
  if (TLSF_SIZE_MMAP == bhdr->size)
    {
      mm_free_sized (((char*)bhdr) - sizeof (int64), BHDR_MMAP_SIZE (bhdr));
      return;
    }
  __builtin_prefetch (((char*)ptr) + size);
  ASSERT_NOT_IN_POOL (ptr);
  mutex_enter (&tlsf->tlsf_mtx);
  free_ex(ptr, tlsf);
  mutex_leave(&tlsf->tlsf_mtx);

}


/******************************************************************/
void *malloc_ex(size_t size, void *mem_pool)
{
/******************************************************************/
    tlsf_t *tlsf = (tlsf_t *) mem_pool;
    bhdr_t *b, *b2, *next_b;
    int fl, sl;
    size_t tmp_size;

    size = (size < MIN_BLOCK_SIZE) ? MIN_BLOCK_SIZE : ROUNDUP_SIZE(size);

    /* Rounding up the requested size and calculating fl and sl */
    MAPPING_SEARCH(&size, &fl, &sl);

    /* Searching a free block, recall that this function changes the values of fl and sl,
       so they are not longer valid when the function fails */
    b = FIND_SUITABLE_BLOCK(tlsf, &fl, &sl);
    if (!b) {
        size_t area_size;
        void *area;
        /* Growing the pool size when needed */
        area_size = MAX (tlsf->tlsf_grow_quantum, size + BHDR_OVERHEAD * 8);   /* size plus enough room for the requered headers. */
        area_size = (area_size > DEFAULT_AREA_SIZE) ? area_size : DEFAULT_AREA_SIZE;
	if (tlsf->tlsf_grow_quantum < tlsf->tlsf_total_mapped / 4)
	  {
	    int ign;
	    tlsf->tlsf_grow_quantum = MIN ((1L << 30) - 4096, tlsf->tlsf_total_mapped / 4);
	    area_size = mm_next_size (area_size, &ign);
	  }
        area = get_new_area(tlsf, &area_size);        /* Call sbrk or mmap */
        if (area == ((void *) ~0))
            return NULL;        /* Not enough system memory */
	//at_register_area (area, area_size, (uptrlong)tlsf | AT_TLSF_AREA);
	tlsf->tlsf_total_mapped += area_size;
	add_new_area(area, area_size, mem_pool);
        /* Rounding up the requested size and calculating fl and sl */
        MAPPING_SEARCH(&size, &fl, &sl);
        /* Searching a free block */
        b = FIND_SUITABLE_BLOCK(tlsf, &fl, &sl);
    }
    if (!b)
        return NULL;            /* Not found */

    EXTRACT_BLOCK_HDR(b, tlsf, fl, sl);

    /*-- found: */
    next_b = GET_NEXT_BLOCK(b->ptr.buffer, b->size & BLOCK_SIZE);
    /* Should the block be split? */
    tmp_size = (b->size & BLOCK_SIZE) - size;
    if (tmp_size >= sizeof(bhdr_t)) {
        tmp_size -= BHDR_OVERHEAD;
        b2 = GET_NEXT_BLOCK(b->ptr.buffer, size);
        b2->size = tmp_size | FREE_BLOCK | PREV_USED;
        next_b->prev_hdr = b2;
        MAPPING_INSERT(tmp_size, &fl, &sl);
        INSERT_BLOCK(b2, tlsf, fl, sl);

        b->size = size | (b->size & PREV_STATE);
    } else {
        next_b->size &= (~PREV_FREE);
        b->size &= (~FREE_BLOCK);       /* Now it's used */
    }

    TLSF_ADD_SIZE(tlsf, b);
    b->bhdr_info = tlsf->tlsf_id 
#ifndef MALLOC_DEBUG
      | ((((uint32)(ptrlong)b) >> 3) << 12)
#endif
      ;
    return (void *) b->ptr.buffer;
}

/******************************************************************/
void free_ex(void *ptr, void *mem_pool)
{
/******************************************************************/
    tlsf_t *tlsf = (tlsf_t *) mem_pool;
    bhdr_t *b, *tmp_b;
    int fl = 0, sl = 0;

    if (!ptr) {
        return;
    }
    b = (bhdr_t *) ((char *) ptr - BHDR_OVERHEAD);
    if (FREE_BLOCK & b->size)
      GPF_T1 ("tlsf double free, seen by bhdr free bit");
    b->size |= FREE_BLOCK;

    TLSF_REMOVE_SIZE(tlsf, b);

    b->ptr.free_ptr.prev = NULL;
    b->ptr.free_ptr.next = NULL;
    tmp_b = GET_NEXT_BLOCK(b->ptr.buffer, b->size & BLOCK_SIZE);
    if (tmp_b->size & FREE_BLOCK) {
        MAPPING_INSERT(tmp_b->size & BLOCK_SIZE, &fl, &sl);
        EXTRACT_BLOCK(tmp_b, tlsf, fl, sl);
        b->size += (tmp_b->size & BLOCK_SIZE) + BHDR_OVERHEAD;
    }
    if (b->size & PREV_FREE) {
        tmp_b = b->prev_hdr;
        MAPPING_INSERT(tmp_b->size & BLOCK_SIZE, &fl, &sl);
        EXTRACT_BLOCK(tmp_b, tlsf, fl, sl);
        tmp_b->size += (b->size & BLOCK_SIZE) + BHDR_OVERHEAD;
        b = tmp_b;
    }
    MAPPING_INSERT(b->size & BLOCK_SIZE, &fl, &sl);
    INSERT_BLOCK(b, tlsf, fl, sl);

    tmp_b = GET_NEXT_BLOCK(b->ptr.buffer, b->size & BLOCK_SIZE);
    tmp_b->size |= PREV_FREE;
    tmp_b->prev_hdr = b;
}

/******************************************************************/
void *realloc_ex(void *ptr, size_t new_size, void *mem_pool)
{
/******************************************************************/
    tlsf_t *tlsf = (tlsf_t *) mem_pool;
    void *ptr_aux;
    unsigned int cpsize;
    bhdr_t *b, *tmp_b, *next_b;
    int fl, sl;
    size_t tmp_size;

    if (!ptr) {
        if (new_size)
            return (void *) malloc_ex(new_size, mem_pool);
        if (!new_size)
            return NULL;
    } else if (!new_size) {
        free_ex(ptr, mem_pool);
        return NULL;
    }

    b = (bhdr_t *) ((char *) ptr - BHDR_OVERHEAD);
    next_b = GET_NEXT_BLOCK(b->ptr.buffer, b->size & BLOCK_SIZE);
    new_size = (new_size < MIN_BLOCK_SIZE) ? MIN_BLOCK_SIZE : ROUNDUP_SIZE(new_size);
    tmp_size = (b->size & BLOCK_SIZE);
    if (new_size <= tmp_size) {
	TLSF_REMOVE_SIZE(tlsf, b);
        if (next_b->size & FREE_BLOCK) {
            MAPPING_INSERT(next_b->size & BLOCK_SIZE, &fl, &sl);
            EXTRACT_BLOCK(next_b, tlsf, fl, sl);
            tmp_size += (next_b->size & BLOCK_SIZE) + BHDR_OVERHEAD;
            next_b = GET_NEXT_BLOCK(next_b->ptr.buffer, next_b->size & BLOCK_SIZE);
            /* We allways reenter this free block because tmp_size will
               be greater then sizeof (bhdr_t) */
        }
        tmp_size -= new_size;
        if (tmp_size >= sizeof(bhdr_t)) {
            tmp_size -= BHDR_OVERHEAD;
            tmp_b = GET_NEXT_BLOCK(b->ptr.buffer, new_size);
            tmp_b->size = tmp_size | FREE_BLOCK | PREV_USED;
            next_b->prev_hdr = tmp_b;
            next_b->size |= PREV_FREE;
            MAPPING_INSERT(tmp_size, &fl, &sl);
            INSERT_BLOCK(tmp_b, tlsf, fl, sl);
            b->size = new_size | (b->size & PREV_STATE);
        }
	TLSF_ADD_SIZE(tlsf, b);
        return (void *) b->ptr.buffer;
    }
    if ((next_b->size & FREE_BLOCK)) {
        if (new_size <= (tmp_size + (next_b->size & BLOCK_SIZE))) {
			TLSF_REMOVE_SIZE(tlsf, b);
            MAPPING_INSERT(next_b->size & BLOCK_SIZE, &fl, &sl);
            EXTRACT_BLOCK(next_b, tlsf, fl, sl);
            b->size += (next_b->size & BLOCK_SIZE) + BHDR_OVERHEAD;
            next_b = GET_NEXT_BLOCK(b->ptr.buffer, b->size & BLOCK_SIZE);
            next_b->prev_hdr = b;
            next_b->size &= ~PREV_FREE;
            tmp_size = (b->size & BLOCK_SIZE) - new_size;
            if (tmp_size >= sizeof(bhdr_t)) {
                tmp_size -= BHDR_OVERHEAD;
                tmp_b = GET_NEXT_BLOCK(b->ptr.buffer, new_size);
                tmp_b->size = tmp_size | FREE_BLOCK | PREV_USED;
                next_b->prev_hdr = tmp_b;
                next_b->size |= PREV_FREE;
                MAPPING_INSERT(tmp_size, &fl, &sl);
                INSERT_BLOCK(tmp_b, tlsf, fl, sl);
                b->size = new_size | (b->size & PREV_STATE);
            }
			TLSF_ADD_SIZE(tlsf, b);
            return (void *) b->ptr.buffer;
        }
    }

    if (!(ptr_aux = malloc_ex(new_size, mem_pool))){
        return NULL;
    }      
    
    cpsize = ((b->size & BLOCK_SIZE) > new_size) ? new_size : (b->size & BLOCK_SIZE);

    memcpy(ptr_aux, ptr, cpsize);

    free_ex(ptr, mem_pool);
    return ptr_aux;
}


/******************************************************************/
void *calloc_ex(size_t nelem, size_t elem_size, void *mem_pool)
{
/******************************************************************/
    void *ptr;

    if (nelem <= 0 || elem_size <= 0)
        return NULL;

    if (!(ptr = malloc_ex(nelem * elem_size, mem_pool)))
        return NULL;
    memset(ptr, 0, nelem * elem_size);

    return ptr;
}



#if _DEBUG_TLSF_

/***************  DEBUG FUNCTIONS   **************/

/* The following functions have been designed to ease the debugging of */
/* the TLSF  structure.  For non-developing  purposes, it may  be they */
/* haven't too much worth.  To enable them, _DEBUG_TLSF_ must be set.  */

extern void dump_memory_region(unsigned char *mem_ptr, unsigned int size);
extern void print_block(bhdr_t * b);
extern void print_tlsf(tlsf_t * tlsf);

void dump_memory_region(unsigned char *mem_ptr, unsigned int size)
{

    unsigned long begin = (unsigned long) mem_ptr;
    unsigned long end = (unsigned long) mem_ptr + size;
    int column = 0;

    begin >>= 2;
    begin <<= 2;

    end >>= 2;
    end++;
    end <<= 2;

    PRINT_MSG("\nMemory region dumped: 0x%lx - 0x%lx\n\n", begin, end);

    column = 0;
    PRINT_MSG("0x%lx ", begin);

    while (begin < end) {
        if (((unsigned char *) begin)[0] == 0)
            PRINT_MSG("00");
        else
            PRINT_MSG("%02x", ((unsigned char *) begin)[0]);
        if (((unsigned char *) begin)[1] == 0)
            PRINT_MSG("00 ");
        else
            PRINT_MSG("%02x ", ((unsigned char *) begin)[1]);
        begin += 2;
        column++;
        if (column == 8) {
            PRINT_MSG("\n0x%lx ", begin);
            column = 0;
        }

    }
    PRINT_MSG("\n\n");
}

id_hash_t * mdbg_place_to_id;
id_hash_t * mdbg_id_to_place;
id_hash_t * mdbg_total;
dk_mutex_t mdbg_place_mtx;
uptrlong mdbg_place_ctr;
#define MDBG_HASH_SIZE 4011


void print_block(bhdr_t * b)
{
  mdbg_place_t * pl = NULL;
    if (!b)
        return;
#ifdef MALLOC_DEBUG 
    if (mdbg_id_to_place)
      {
	ptrlong i = b->bhdr_info >> 12;
	pl = (mdbg_place_t*)id_hash_get (mdbg_id_to_place, (caddr_t) &i);
      }
#endif
    PRINT_MSG("   [%p] (", b);
    if ((b->size & BLOCK_SIZE))
        PRINT_MSG("%lu bytes, ", (unsigned long) (b->size & BLOCK_SIZE));
    else
        PRINT_MSG("sentinel, ");
    if ((b->size & BLOCK_STATE) == FREE_BLOCK)
        PRINT_MSG("free [%p, %p], ", b->ptr.free_ptr.prev, b->ptr.free_ptr.next);
    else
      {
	if (pl)
	  PRINT_MSG(" %s:%d used, ", pl->mpl_file, pl->mpl_line);
	else
	  PRINT_MSG("used, ");
      }
    if ((b->size & PREV_STATE) == PREV_FREE)
      PRINT_MSG("prev. free [%p])\n", b->prev_hdr);
    else
        PRINT_MSG("prev used)\n");
}

void print_tlsf(tlsf_t * tlsf)
{
    bhdr_t *next;
    int i, j;

    PRINT_MSG("\nTLSF at %p\n", tlsf);

    PRINT_MSG("FL bitmap: 0x%x\n\n", (unsigned) tlsf->fl_bitmap);

    for (i = 0; i < REAL_FLI; i++) {
        if (tlsf->sl_bitmap[i])
            PRINT_MSG("SL bitmap 0x%x\n", (unsigned) tlsf->sl_bitmap[i]);
        for (j = 0; j < MAX_SLI; j++) {
            next = tlsf->matrix[i][j];
            if (next)
                PRINT_MSG("-> [%d][%d]\n", i, j);
            while (next) {
                print_block(next);
                next = next->ptr.free_ptr.next;
            }
        }
    }
}


void
ht_free_nop (id_hash_t * ht)
{
  /* empty */
}


void
tlsf_print_all_blocks(tlsf_t * tlsf, void * ht1, int mode)
{
  caddr_t one = (caddr_t)1;
  id_hash_t * ht = (id_hash_t *)ht1;
  area_info_t *ai;
  bhdr_t *next;
  if (!tlsf)
    return;
  if (ht)
    {
      ht->ht_free_hook = ht_free_nop;
      ht->ht_hash_func = boxint_hash;
      ht->ht_cmp = boxint_hashcmp;
    }
  PRINT_MSG("\nTLSF at %p\nALL BLOCKS\n\n", tlsf);
  ai = tlsf->area_head;
  while (ai) {
    next = (bhdr_t *) ((char *) ai - BHDR_OVERHEAD);
    while (next) {
      if ((next->size & BLOCK_STATE) == FREE_BLOCK)
	{
	  if (AB_ALL == mode)
	    print_block(next);
	}
      else
	{
	  if (AB_FILL == mode && ht)
	    id_hash_set (ht, (caddr_t)&next, (caddr_t)&one);
	  else if (AB_EXCEPT == mode && ht)
	    {
	      if (!id_hash_get (ht, (caddr_t)&next))
		print_block (next);
	    }
	  else
	    print_block (next);
	}
      if ((next->size & BLOCK_SIZE))
	next = GET_NEXT_BLOCK(next->ptr.buffer, next->size & BLOCK_SIZE);
      else
	next = NULL;
    }
    ai = ai->next;
  }
}

#endif


tlsf_t * dk_base_tlsf;
size_t tlsf_mmap_threshold = ((128 * 1024) - BHDR_OVERHEAD);
tlsf_t * dk_all_tlsfs[MAX_TLSFS];
int tlsf_ctr;
dk_mutex_t all_tlsf_mtx;

tlsf_t *
tlsf_new (size_t size)
{
  tlsf_t * tlsf;
  void * area;
#ifdef HAVE_SYS_MMAN_H  
  if ((area = mmap(0, size, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0)) != MAP_FAILED)
#else
  size = ROUNDUP(size, PAGE_SIZE);
  if ((area = malloc(size)) != NULL)
#endif
    {
      init_memory_pool (size, area);
      tlsf = (tlsf_t*)area;
      if (!tlsf_ctr)
	dk_mutex_init (&all_tlsf_mtx, MUTEX_TYPE_SHORT);
      if (tlsf_ctr > 2)
	tlsf->tlsf_on_thread = TLSF_BOUND;
      mutex_enter (&all_tlsf_mtx);
      tlsf->tlsf_id = ++tlsf_ctr;
      dk_all_tlsfs[tlsf->tlsf_id] = tlsf;
      mutex_leave (&all_tlsf_mtx);
      tlsf->tlsf_grow_quantum = size;
#ifdef MALLOC_DEBUG
      if (mdbg_tlsf)
	{
	  WITH_TLSF (mdbg_tlsf)
	  {
	    tlsf->tlsf_allocs = id_hash_allocate (3011, sizeof (boxint), sizeof (mdbg_stat_t), boxint_hash, boxint_hashcmp);
	  }
	  END_WITH_TLSF;
	}
#endif
      return tlsf;
    }
  return NULL;
}


void 
tlsf_destroy (tlsf_t * tlsf)
{
  tlsf->tlsf_signature = 0;
  dk_mutex_destroy (&tlsf->tlsf_mtx);
#ifdef MALLOC_DEBUG
  if (tlsf->tlsf_allocs)
    id_hash_free (tlsf->tlsf_allocs);
#endif
}

tlsf_t *
tlsf_get ()
{
  int inx;
  return NULL;
  mutex_enter (&all_tlsf_mtx);
  for (inx = 3; inx <= tlsf_ctr; inx++)
    {
      tlsf_t * tlsf = dk_all_tlsfs[inx];
      if (TLSF_FREE == tlsf->tlsf_on_thread)
	{
	  tlsf->tlsf_on_thread = TLSF_BOUND;
	  mutex_leave (&all_tlsf_mtx);
	  return tlsf;
	}
    }
  mutex_leave (&all_tlsf_mtx);
  return tlsf_new (1000000);
}


void *
tlsf_id_alloc (size_t sz, short tlsf_id)
{
  void * ret;
  tlsf_t * tlsf;
  if (!tlsf_id)
    tlsf = dk_base_tlsf;
  else 
    tlsf = dk_all_tlsfs[tlsf_id];
  
  if (sz >= tlsf_mmap_threshold)
    return tlsf_large_alloc (tlsf, sz);
  mutex_enter(&tlsf->tlsf_mtx);
  ret =  malloc_ex (sz, tlsf);
  mutex_leave(&tlsf->tlsf_mtx);
  return ret;
}

#undef tlsf_base_alloc

void *
tlsf_base_alloc (size_t sz)
{
  void * ret;
  if (sz >= tlsf_mmap_threshold)
    return tlsf_large_alloc (dk_base_tlsf, sz);
  mutex_enter(&dk_base_tlsf->tlsf_mtx);
  ret =  malloc_ex (sz, dk_base_tlsf);
  mutex_leave(&dk_base_tlsf->tlsf_mtx);
  return ret;
}


int
mbs_cmp (const void * p1, const void * p2)
{
  int64 n1 = *(int64*)p1;
  int64 n2 = *(int64*)p2;
  return n1 < n2 ? -1 : n1 == n2 ? 0 : 1;
}


int
tlsf_check (tlsf_t * tlsf, int mode)
{
  int64 * arr;
  int64 ts;
  id_hash_iterator_t hit;
  int fill = 0, inx;
  int no_print = 0;
  mem_pool_t * mp = NULL;
  int64 total = 0, n_blocks = 0;
  int64 allocd_bytes = 0, free_bytes = 0;
  int n_free = 0, n_allocd = 0, n_err = 0, n_areas = 0;
  if (!THREAD_CURRENT_THREAD || !tlsf)
    return 0;
  if (2 == mode)
    {
      mode = 0;
      no_print = 1;
    }
  WITHOUT_TMP_POOL 
  {
    int64 *sz;
    int64 *cts;
    id_hash_t * ht = NULL;
    area_info_t *ai;
    bhdr_t *next;
    if (1 == mode)
      {
	mp = mem_pool_alloc ();
	SET_THR_TMP_POOL (mp);
	ht = t_id_hash_allocate (101, sizeof (int64), 2 *sizeof (int64), boxint_hash, boxint_hashcmp);
      }
    if (mode != 0)
      printf ("\nTLSF %s at %p %luK mapped\n", tlsf->tlsf_comment ? tlsf->tlsf_comment : "", tlsf, tlsf->tlsf_total_mapped >> 10);
    mutex_enter (&tlsf->tlsf_mtx);
    ai = tlsf->area_head;
    while (ai) 
      {
	next = (bhdr_t *) ((char *) ai - BHDR_OVERHEAD);
	while (next) 
	  {
	    int64 sz = next->size & BLOCK_SIZE;
	    int64 * place;
	    total += sz;
	    n_blocks++;
	    if (FREE_BLOCK & next->size)
	      {
		free_bytes += sz;
		n_free ++;
	      }
	    else
	      {
		char * err = NULL;
		if (next != ai->end && 16 != ((long)ai - (long)next))
		  err = tlsf_check_alloc (next->ptr.buffer);
		if (err)
		  {
		    if (n_err < 10 && !no_print)
		      printf ("%p %s\n", next, err);
		    n_err++;
		  }
		allocd_bytes += sz;
		n_allocd++;
	      }
	    if (ht)
	      {
		place = (int64 *)id_hash_get (ht, (caddr_t)&sz);
		if (!place)
		  {
		    int64 p[2];
		    p[0] = p[1] = 0;
		    if (next->size & FREE_BLOCK)
		      p[1]++;
		    else
		      p[0]++;
		    t_id_hash_set (ht, (caddr_t)&sz, (caddr_t)&p);
		  }
		else
		  {
		    if (next->size & FREE_BLOCK)
		      place[1]++;
		    else
		      place[0]++;
		  }
	      }
	    if ((next->size & BLOCK_SIZE))
	      next = GET_NEXT_BLOCK(next->ptr.buffer, next->size & BLOCK_SIZE);
	    else
	      next = NULL;
	  }
	ai = ai->next;
	n_areas++;
      }
    mutex_leave (&tlsf->tlsf_mtx);
    ts = allocd_bytes + free_bytes + BHDR_OVERHEAD * (n_free + n_allocd);
    if (ht)
      {
	id_hash_iterator (&hit, ht);
	arr = (int64*)mp_alloc_box (mp, sizeof (int64) * 3 * ht->ht_count, DV_STRING);
	while (hit_next (&hit, (caddr_t*)&sz, (caddr_t*)&cts))
	  {
	    arr[fill] = *sz;
	    arr[fill + 1] = cts[0];
	    arr[fill + 2] = cts[1];
	    fill += 3;
	  }
	qsort (arr, fill / 3, 3 * sizeof (int64), mbs_cmp);
	printf ("%Ld/%Ld bytes/blocks total, %Ld/%d allocd, %Ld/%d free; %Ld bytes of allocd+free+overhead\n", total, n_blocks, allocd_bytes, n_allocd, free_bytes, n_free, ts);
	for (inx = 0; inx < fill; inx += 3)
	  {
	    printf ("sz %Ld %Ld allocd %Ld free\n", arr[inx], arr[inx + 1], arr[inx + 2]);
	  }
      }
  }
  END_WITHOUT_TMP_POOL;
  if (mp)
  mp_free (mp);
  return n_err;
}


int
tlsf_by_addr (caddr_t * ptr)
{
  int t_inx;
  for (t_inx = 1; t_inx < tlsf_ctr; t_inx++)
    {
      tlsf_t * tlsf = dk_all_tlsfs[t_inx];
      area_info_t *ai;
      bhdr_t *next, * end;
      mutex_enter (&tlsf->tlsf_mtx);
      ai = tlsf->area_head;
      while (ai) 
	{
	  next = (bhdr_t *) ((char *) ai - BHDR_OVERHEAD);
	  end = ai->end;
	  if ((ptrlong)ptr > (ptrlong)ai && (ptrlong)ptr < (ptrlong)ai->end)
	    {
	      while (next) 
		{
		  int64 sz = next->size & BLOCK_SIZE;
		  if ((ptrlong)ptr >= (ptrlong)next && (ptrlong)ptr < (ptrlong)next + sz)
		    {

		      if (FREE_BLOCK & next->size)
			{
			  printf ("%p is in free bock of size %Ld starting at %p in area %p--%p of tlsf %p\n", ptr, (long long)sz, next, ai, end, tlsf);
			  mutex_leave (&tlsf->tlsf_mtx);
			  return t_inx;
			}
		      else 
			{
			  printf ("%p is in allocd bock of size %Ld starting at %p in area %p--%p of tlsf %p\n", ptr, (long long)sz, next, ai, end, tlsf);
			  mutex_leave (&tlsf->tlsf_mtx);
			  return t_inx;
			}
		    }

		  if ((next->size & BLOCK_SIZE))
		    next = GET_NEXT_BLOCK(next->ptr.buffer, next->size & BLOCK_SIZE);
		  else
		    next = NULL;
		}
	    }
	  ai = ai->next;
	}
      mutex_leave (&tlsf->tlsf_mtx);
    }
  return 0;
}


int
tlsf_cmp (const void * p1, const void * p2)
{
  int64 n1, n2;
  if (!p1)
    return -1;
  if (!p2)
    return 1;
  n1 = (*((tlsf_t**)p1))->tlsf_total_mapped;
	n2 = (*((tlsf_t**)p2))->tlsf_total_mapped;
  return n1 < n2 ? -1 : n1 == n2 ? 0 : 1;
}

void
tlsf_summary (FILE * out)
{
  int64 mapped = 0, used = 0, max = 0;
  int fill = tlsf_ctr, inx;
  tlsf_t * tlsfs[MAX_TLSFS];
  memcpy (tlsfs, &dk_all_tlsfs[1], fill * sizeof (caddr_t));
  qsort (tlsfs, tlsf_ctr, sizeof (caddr_t), tlsf_cmp);
  if (!out)
    out = stderr;
  fprintf (out, "\nAllocation summary\n");
  for (inx = 0; inx < fill; inx++)
    {
      tlsf_t * tlsf = tlsfs[inx];
      if (!tlsf)
	continue;
      mapped += tlsf->tlsf_total_mapped;
      used += tlsf->used_size;
      max += tlsf->max_size;
      fprintf (out, "%luKb mapped, %luKb used, %luKb max --- in tlsf %p with id %d '%s'\n", tlsf->tlsf_total_mapped >> 10, tlsf->used_size >> 10, tlsf->max_size >> 10, tlsf, tlsf->tlsf_id, tlsf->tlsf_comment ? tlsf->tlsf_comment : "-");
    }
  fprintf (out, "%luKb mapped, %luKb used, %luKb max\n", (unsigned long)(mapped >> 10), (unsigned long)(used >> 10), (unsigned long)(max >> 10));

}

void
thr_set_tlsf (du_thread_t * thr, tlsf_t * tlsf)
{
  if (tlsf && TLSF_SIGNATURE != tlsf->tlsf_signature) GPF_T1 ("bad tlsf bound to thread");
  thr->thr_tlsf = tlsf;
}


void
tlsf_set_comment (tlsf_t * tlsf, char * name)
{
}



#ifdef MALLOC_DEBUG
tlsf_t * mdbg_tlsf;



uint32
mdbg_place_hash (caddr_t * p)
{
  mdbg_place_t * pl = (mdbg_place_t*)p;
  uint64 h = 1;
  MHASH_STEP (h, (ptrlong)pl->mpl_file);
  MHASH_STEP (h, pl->mpl_line);
  return h & 0x7fffffff;
}


int
mdbg_place_hash_cmp (caddr_t * p1, caddr_t *p2)
{
  mdbg_place_t * pl1 = (mdbg_place_t*)p1;
  mdbg_place_t * pl2 = (mdbg_place_t*)p2;
  return pl1->mpl_file == pl2->mpl_file && pl1->mpl_line == pl2->mpl_line;
}


void
tlsf_mdbg_init ()
{
  dk_mutex_init (&mdbg_place_mtx, MUTEX_TYPE_SHORT);
  mdbg_tlsf = tlsf_new (1000000);
  tlsf_fp = stderr;
  WITH_TLSF (mdbg_tlsf)
  {
    mdbg_place_to_id = id_hash_allocate (MDBG_HASH_SIZE, sizeof (mdbg_place_t), sizeof (uint32), mdbg_place_hash, mdbg_place_hash_cmp);
    mdbg_id_to_place = id_hash_allocate (MDBG_HASH_SIZE, sizeof (boxint), sizeof (mdbg_place_t), boxint_hash, boxint_hashcmp);
    dk_base_tlsf->tlsf_allocs = id_hash_allocate (MDBG_HASH_SIZE, sizeof (boxint), sizeof (mdbg_stat_t), boxint_hash, boxint_hashcmp);
  }
  END_WITH_TLSF;
}



uint32
tlsf_place_id (const char * file, int line)
{
  uint32 ret;
  mdbg_place_t pl;
  pl.mpl_line = line;
  pl.mpl_file = file;
  boxint * place = (boxint*)id_hash_get (mdbg_place_to_id, (caddr_t)&pl); 
  if (place)
    return *place;
  WITH_TLSF (mdbg_tlsf)
  {
    mutex_enter (&mdbg_place_mtx);
    mdbg_place_ctr++;
    id_hash_set (mdbg_place_to_id, (caddr_t)&pl, (caddr_t)&mdbg_place_ctr);
    id_hash_set (mdbg_id_to_place, (caddr_t)&mdbg_place_ctr, (caddr_t)&pl);
    ret = mdbg_place_ctr;
    mutex_leave (&mdbg_place_mtx);
  }
  END_WITH_TLSF;
  return ret;
}




void 
tlsf_mdbg_alloc (tlsf_t * tlsf, const char * file, int line, bhdr_t * b)
{
  boxint id = 0;
  mdbg_stat_t * place;
  size_t sz = tlsf_block_size (b->ptr.buffer);
  if (!mdbg_tlsf || tlsf == mdbg_tlsf || !mdbg_place_to_id || !mdbg_id_to_place)
    return;
#if 1
  id = tlsf_place_id (file, line);
  place = (mdbg_stat_t*)id_hash_get (tlsf->tlsf_allocs, (caddr_t)&id);
  if (place)
    {
      place->mds_allocs++;
      place->mds_bytes += sz;
    }
  else
    {
      mdbg_stat_t mds;
      mds.mds_allocs = 1;
      mds.mds_frees = 0;
      mds.mds_bytes = sz;
      mds.mds_prev_bytes = 0;
      mutex_enter (&tlsf->tlsf_mtx);
      WITH_TLSF (mdbg_tlsf)
	id_hash_set (tlsf->tlsf_allocs, (caddr_t)&id, (caddr_t)&mds);
      END_WITH_TLSF;
      mutex_leave (&tlsf->tlsf_mtx);
    }
#endif
  b->bhdr_info = (id << 12) | (b->bhdr_info & TLSF_ID_MASK);
}


void 
tlsf_mdbg_free (tlsf_t * tlsf, bhdr_t * b)
{
  boxint id;
  mdbg_stat_t * mds;
  if (!mdbg_tlsf || tlsf == mdbg_tlsf)
    return;
  id = b->bhdr_info >> 12;
  if (id > mdbg_place_ctr) GPF_T1 ("alloc place for block being freed is not in range, free of non-allocd");
  mds = (mdbg_stat_t*)id_hash_get (tlsf->tlsf_allocs, (caddr_t)&id); 
  if (mds)
    {
      mds->mds_frees++;
      mds->mds_bytes -= tlsf_block_size (b->ptr.buffer);
    }
}


int mdbg_sort_mode;


int
mds_sort_cmp (const void * p1, const void * p2)
{
  mdbg_stat_t * mds1 = *(mdbg_stat_t**)p1;
  mdbg_stat_t * mds2 = *(mdbg_stat_t**)p2;
  switch (mdbg_sort_mode)
    {
    case 1: return (int64)(mds1->mds_bytes - mds1->mds_prev_bytes) < (int64)(mds2->mds_bytes - mds2->mds_prev_bytes) ? -1 : 1;
    case 0: return mds1->mds_bytes < mds2->mds_bytes ? -1 : 1;
    default: GPF_T1 ("bad mem report sort mode");
    }
  return 0;
}

FILE * mdbg_rep_f;

void
tlsf_print_sizes (id_hash_t * allocs, int mode)
{
  int inx;
  FILE * out = mdbg_rep_f ? mdbg_rep_f : stderr;
  int n = allocs->ht_count, fill = 0;
  id_hash_iterator_t hit;
  ptrlong id;
  mdbg_stat_t * mds;
  mdbg_stat_t ** mds_arr = (mdbg_stat_t **)tlsf_malloc ("", 0, sizeof (caddr_t) * n, THREAD_CURRENT_THREAD);
  mdbg_sort_mode = mode;
  id_hash_iterator (&hit, allocs);
  while (hit_next (&hit, (caddr_t*)&id, (caddr_t*)&mds))
    {
      if (1 == mode && mds->mds_prev_bytes == mds->mds_bytes)
	continue;
      if (!mds->mds_bytes)
	continue;
      mds_arr[fill++] = mds;
    }
  qsort (mds_arr, fill, sizeof (caddr_t), mds_sort_cmp);
  for (inx = 0; inx < fill; inx++)
    {
      mdbg_stat_t * mds = mds_arr[inx];
      mdbg_place_t * pl = (mdbg_place_t*)id_hash_get (mdbg_id_to_place, (caddr_t) (((boxint*)mds) - 1));
      fprintf (out, "%s:%d %d uses %d alloc %d free " BOXINT_FMT "  + %Ld bytes " BOXINT_FMT " total\n", pl->mpl_file, pl->mpl_line, mds->mds_allocs - mds->mds_frees, mds->mds_allocs, mds->mds_frees, mds->mds_prev_bytes, (int64)(mds->mds_bytes - mds->mds_prev_bytes), mds->mds_bytes); 
    }
  tlsf_free (mds_arr);
}

mdbg_place_t *
mdbg_id_place (ptrlong id)
{
  mdbg_place_t * pl = (mdbg_place_t*)id_hash_get (mdbg_id_to_place, (caddr_t)&id);
  return pl;
}


void 
tlsf_all_in_use (FILE * out, int mode, int nth)
{
  int inx;
  boxint *id;
  size_t allocd, mapped;
  mdbg_stat_t * mds;
  if (!out)
    out = stderr;
  mutex_enter (&mdbg_place_mtx);
  allocd = tlsf_get_total (&mapped);
  fprintf (out, "\n######\nMemory %lu total allocated %lu mapped\n\n", allocd, mapped);
  mdbg_rep_f = out;
  WITH_TLSF (mdbg_tlsf)
  {
    if (nth)
      {
	id_hash_iterator_t hit;
	tlsf_t * tlsf = dk_all_tlsfs[nth];
	if (!tlsf)
	  fprintf (out, "no tlsf at index %d\n", nth);
	else
	  {
	    tlsf_print_sizes (tlsf->tlsf_allocs, mode);
	    id_hash_iterator (&hit, tlsf->tlsf_allocs);
	    while (hit_next (&hit, (caddr_t*)&id, (caddr_t*)&mds))
	      {
		mds->mds_prev_bytes = mds->mds_bytes;
	      }
	  }
      }
    else
      {
	id_hash_iterator_t hit;
	if (!mdbg_total)
	  mdbg_total = id_hash_allocate (MDBG_HASH_SIZE, sizeof (boxint), sizeof (mdbg_stat_t), boxint_hash, boxint_hashcmp);
	else
	  {
	    mdbg_stat_t * mds;
	    id_hash_iterator (&hit, mdbg_total);
	    while (hit_next (&hit, (caddr_t*)&id, (caddr_t*)&mds))
	      {
		mds->mds_prev_bytes = mds->mds_bytes;
		mds->mds_bytes = 0;
	      }
	  }
	for (inx = 1; inx <= tlsf_ctr; inx++)
	  {
	    tlsf_t * tlsf = dk_all_tlsfs[inx];
	    if (!tlsf || !tlsf->tlsf_allocs)
	      continue;
	    mutex_enter (&tlsf->tlsf_mtx);
	    id_hash_iterator (&hit, tlsf->tlsf_allocs);
	    while (hit_next (&hit, (caddr_t*)&id, (caddr_t*)&mds))
	      {
		mdbg_stat_t * t = (mdbg_stat_t*)id_hash_get (mdbg_total, (caddr_t)id);
		if (t)
		  {
		    t->mds_allocs += mds->mds_allocs;
		    t->mds_frees += mds->mds_frees;
		    t->mds_bytes += mds->mds_bytes;
		  }
		else
		  id_hash_set (mdbg_total, (caddr_t)id, (caddr_t)mds);
	      }
	    mutex_leave (&tlsf->tlsf_mtx);
	  }
	tlsf_print_sizes (mdbg_total, mode);
      }
  }
  END_WITH_TLSF;
  mdbg_rep_f = NULL;
  mutex_leave (&mdbg_place_mtx);
}


#endif

size_t
tlsf_get_total (size_t * map_ret)
{
  int inx;
  size_t s = 0, m = 0;
  for (inx = 1; inx <= tlsf_ctr; inx++)
    {
      if (dk_all_tlsfs[inx])
	{
	  m += dk_all_tlsfs[inx]->tlsf_total_mapped;
	  s += dk_all_tlsfs[inx]->used_size;
	}
    }
  if (map_ret)
      *map_ret = m;
  return s;
}



char * 
tlsf_check_alloc (void * ptr)
{
  tlsf_t * tlsf;
  bhdr_t * b = BHDR (ptr);
  uint32 i = b->bhdr_info;
  int tid = i & TLSF_ID_MASK;
  if (TLSF_SIZE_MMAP == b->size)
    return NULL;
  if (b->size & FREE_BLOCK)
    return "pointer to freed";
  if (TLSF_IN_MP == tid)
    return NULL;
  if (tid < 1 || tid > tlsf_ctr)
    return "bad tlsf id in block";
  tlsf = dk_all_tlsfs[tid];
  if (tlsf->tlsf_id != tid)
    return "tlsf_check_alloc: tlsf of block does not have right id";
  if (b->size > tlsf->tlsf_total_mapped)
    return "block larger than its tlsf";
  #ifdef MALLOC_DEBUG
  if (i >> 12 > mdbg_place_ctr && (i >> 12))
    return "alloc place in malloc debug out of range, not an allocd block";
#else
  if (i >> 12 != ((((ptrlong)b) >> 3)& 0x000fffff))
    return "block info checksum bad";
#endif
  return NULL;
}


int
tlsf_check_all (int mode)
{
  int inx, s = 0;
  for (inx = 1; inx <= tlsf_ctr; inx++)
    {
      s += tlsf_check (dk_all_tlsfs[inx], mode);
    }
  return s;
}

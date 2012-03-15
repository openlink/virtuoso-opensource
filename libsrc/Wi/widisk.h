/*
 *  widisk.h
 *
 *  $Id$
 *
 *  Disk Based Data Structures
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

#ifndef _WIDISK_H
#define _WIDISK_H

#ifndef PMN_THREADS
typedef int int32;
typedef unsigned int uint32;
#endif

#if defined (WIN32) && !defined (__CYGWIN__)
int ftruncate (int fh, long sz);
int ftruncate64 (int fd, OFF_T length);
#endif

/* Disk address */
typedef uint32 dp_addr_t;	/* must be exactly 32 bits wide */

/*
 *  Macro to cast from dp_addr_t to void * for 64 bit port
 */
#define DP_ADDR2VOID(x)	((void *) (unsigned ptrlong) (x))

typedef unsigned char * db_buf_t;

#define PAGE_SZ			8192
#define KILOS_PER_PAGE (PAGE_SZ/1024)
#define PAGE_DATA_SZ		(PAGE_SZ - DP_DATA)

#define ROW_ALIGN(s) ALIGN_2(s)

#define BITS_IN_LONG		(sizeof (dp_addr_t) * 8)
#define BITS_ON_PAGE		(PAGE_DATA_SZ * 8)
#define LONGS_ON_PAGE		(PAGE_DATA_SZ / sizeof (dp_addr_t))
#define REMAPS_ON_PAGE		(LONGS_ON_PAGE / 2)

#define MAX_RULING_PART_BYTES	1900 /* the length of the leaf pointer not including the leaf pointer headers */
#define MAX_ROW_BYTES		(((PAGE_DATA_SZ / 2) / 4) * 4) /* Must be < half of PAGE_DATA_SZ */
#define ROW_MAX_DATA  (MAX_ROW_BYTES - IE_FIRST_KEY)
#define ROW_MAX_COL_BYTES 	(ROW_MAX_DATA - 10) /*GK: 10 is arbitrary, should be reconsidered */
#define MAX_HASH_TEMP_ROW_BYTES (PAGE_DATA_SZ - 20)

/*
 *  Disk Page layout
 */

#define DP_NULL			0
#define DP_DELETED		((dp_addr_t) -1)

#define DP_FLAGS		0
#define DP_COMP_LEN 2
#define DP_COMPRESS_OVERFLOW (1 * sizeof (dp_addr_t))
#define DP_PARENT		(2 * sizeof (dp_addr_t))
#define DP_RIGHT_INSERTS	(3 * sizeof (dp_addr_t))
#define DP_LAST_INSERT		(3 * sizeof (dp_addr_t) + 2)
#define DP_KEY_ID		(4 * sizeof (dp_addr_t))  /* overlaps with the blob len since only occurs in DPF_INDEX pages.  4 bytes */

#define DP_BLOB_DIR (1 * sizeof (dp_addr_t)) /* overlap with index page comp overflow since blobs compressed stream wise if at all */
#define DP_BLOB_TS		(2 * sizeof (dp_addr_t))
#define DP_BLOB_LEN		(3 * sizeof (dp_addr_t))
#define DP_OVERFLOW		(4 * sizeof (dp_addr_t))
#define DP_DATA			(5 * sizeof (dp_addr_t))
#define N_CFG_PAGE_WORDS	5	/* Highest value of the above */

/* min free pages before insert */
#define DP_INSERT_RESERVE 350



/*
 *  Values for DP_FLAGS
 */

#define DPF_INDEX		 0
#define DPF_FREE_SET		1
/* parent is previous, extension is next */
#define DPF_EXTENSION		2
/* parent is predecessor */
#define DPF_BLOB		3
/* parent is previous, extension is next */
#define DPF_FREE		4
#define DPF_DB_HEAD		5
/* The database control block */
#define DPF_CP_REMAP		6
/* a wide blob page */
#define DPF_BLOB_DIR		7
/* a blob directory page (zzeng) */
#define DPF_INCBACKUP_SET	8
#define DPF_EXTENT_SET 9
#define DPF_EXTENT_MAP 10
#define DPF_HASH 11
/* Like a page with rows but temporary hash index */
#define DPF_COMPRESS_OVERFLOW 12
/* this page has what did not fit on some  compressed page */
/* fake DPF which indicates max possible value of the DPF */
#define DPF_LAST_DPF		13




#define DPF_GZIP 32 /* if gzipped, this is ored to DP_FLAGS */
#define DPF_COMP_OVERFLOWED 64 /* if set, no compression was made and the rest of the page is on the comp overflow.  The 2 bytes lost are in the comp len on this page. */

#define DP_COMP_HEAD_LEN 4 /* 2 bytes for DP_FLAGS and 2 for DP_COMP_LEN */

/*
 * Reference to disk page data
 */

#define HASH_HEAD_LEN 6 /* 4 for next in bucket dp and 2 for next in bucket pos */
#define HH_NEXT_DP 0
#define HH_NEXT_POS 4

#ifndef LOW_ORDER_FIRST
# define LONG_TO_EXT(l) (l)

# define EXT_TO_FLOAT(fl, ext) \
  (((char *) (fl))[0] = ((char *) (ext))[0], \
   ((char *) (fl))[1] = ((char *) (ext))[1], \
   ((char *) (fl))[2] = ((char *) (ext))[2], \
   ((char *) (fl))[3] = ((char *) (ext))[3] )

# define EXT_TO_DOUBLE(fl, ext) \
  (((char *) (fl))[0] = ((char *) (ext))[0], \
   ((char *) (fl))[1] = ((char *) (ext))[1], \
   ((char *) (fl))[2] = ((char *) (ext))[2], \
   ((char *) (fl))[3] = ((char *) (ext))[3], \
   ((char *) (fl))[4] = ((char *) (ext))[4], \
   ((char *) (fl))[5] = ((char *) (ext))[5], \
   ((char *) (fl))[6] = ((char *) (ext))[6], \
   ((char *) (fl))[7] = ((char *) (ext))[7] )

# define FLOAT_TO_EXT(ext, fl) \
  (((char *) (ext))[0] = ((char *) (fl))[0], \
   ((char *) (ext))[1] = ((char *) (fl))[1], \
   ((char *) (ext))[2] = ((char *) (fl))[2], \
   ((char *) (ext))[3] = ((char *) (fl))[3] )

# define DOUBLE_TO_EXT(ext, fl) \
  (((char *) (ext))[0] = ((char *) (fl))[0], \
   ((char *) (ext))[1] = ((char *) (fl))[1], \
   ((char *) (ext))[2] = ((char *) (fl))[2], \
   ((char *) (ext))[3] = ((char *) (fl))[3], \
   ((char *) (ext))[4] = ((char *) (fl))[4], \
   ((char *) (ext))[5] = ((char *) (fl))[5], \
   ((char *) (ext))[6] = ((char *) (fl))[6], \
   ((char *) (ext))[7] = ((char *) (fl))[7] )

#else /* LOW_ORDER_FIRST */
# define LONG_TO_EXT(l) \
  ((((uint32) (l)) >> 24) | \
   (((uint32) (l) & 0x00ff0000) >> 8) | \
   (((uint32) (l) & 0x0000ff00) << 8) | \
   (((uint32) (l)) << 24) )

# define EXT_TO_FLOAT(fl, ext) \
  (((char *) (fl))[3] = ((char *) (ext))[0], \
   ((char *) (fl))[2] = ((char *) (ext))[1], \
   ((char *) (fl))[1] = ((char *) (ext))[2], \
   ((char *) (fl))[0] = ((char *) (ext))[3] )

# define EXT_TO_DOUBLE(fl, ext) \
  (((char *) (fl))[7] = ((char *) (ext))[0], \
   ((char *) (fl))[6] = ((char *) (ext))[1], \
   ((char *) (fl))[5] = ((char *) (ext))[2], \
   ((char *) (fl))[4] = ((char *) (ext))[3], \
   ((char *) (fl))[3] = ((char *) (ext))[4], \
   ((char *) (fl))[2] = ((char *) (ext))[5], \
   ((char *) (fl))[1] = ((char *) (ext))[6], \
   ((char *) (fl))[0] = ((char *) (ext))[7] )

# define FLOAT_TO_EXT(ext, fl) \
  (((char *) (ext))[3] = ((char *) (fl))[0], \
   ((char *) (ext))[2] = ((char *) (fl))[1], \
   ((char *) (ext))[1] = ((char *) (fl))[2], \
   ((char *) (ext))[0] = ((char *) (fl))[3] )

# define DOUBLE_TO_EXT(ext, fl) \
  (((char *) (ext))[7] = ((char *) (fl))[0], \
   ((char *) (ext))[6] = ((char *) (fl))[1], \
   ((char *) (ext))[5] = ((char *) (fl))[2], \
   ((char *) (ext))[4] = ((char *) (fl))[3], \
   ((char *) (ext))[3] = ((char *) (fl))[4], \
   ((char *) (ext))[2] = ((char *) (fl))[5], \
   ((char *) (ext))[1] = ((char *) (fl))[6], \
   ((char *) (ext))[0] = ((char *) (fl))[7] )

#endif /* LOW_ORDER_FIRST */



#ifdef WORDS_BIGENDIAN

#define LONG_REF(ip) \
  ((((int)(*(short*)(ip))) << 16) \
+ (((unsigned short*)(ip)) [1]))


#define LONG_SET(ip, v) \
{ \
  ((unsigned short *) (ip))[0] = (v) >> 16;		\
 ((unsigned short *) (ip))[1] = (unsigned short)(v);	\
}

#else

#define LONG_SET(p, l) \
  *((int32*) (p)) = (l)


#define LONG_REF(p) \
  (* ((int32*) (p)))

#endif

#define SHORT_SET(p, l) \
  *((short*) (p)) = (l)

#define SHORT_REF(p) \
  (* ((short*) (p)))



#ifdef WORDS_BIGENDIAN

#define INT64_REF(p) \
    ( \
      (  ((int64)((short*)(p))[0]) << 48) \
      | (((unsigned int64)((unsigned short*)(p))[1]) << 32) \
      | (((uint32)((unsigned short*)(p))[2]) << 16) \
      | (((unsigned short*)(p))[3]) \
    )

#define INT64_SET(p, v) \
	{ \
	  ((unsigned short *) (p))[0] = (unsigned short)((v) >> 48); \
	  ((unsigned short *) (p))[1] = (unsigned short)((v) >> 32); \
	  ((unsigned short *) (p))[2] = (unsigned short)((v) >> 16); \
	  ((unsigned short *) (p))[3] = (unsigned short)(v); \
       	}

#else

/* row layout as 2 32 bit words, aligned on 4, machine byte order, most significant first */

#define UINT32PL(p)  ((unsigned int32*)(p))

#define INT64_REF(place) \
  (((int64) (UINT32PL(place)[0])) << 32 | UINT32PL(place)[1])

#define INT64_SET(place, v) \
  {((unsigned int32*)(place))[0] = (v) >> 32; \
  ((unsigned int32*)(place))[1] = (int32)(v); }

#endif

/* Index entry flags. Used only for uncommitted rows */

#define IEF_DELETE		0x80

#define IE_KEY_VERSION_OFF		0
#define IE_ROW_VERSION_OFF		1
#define LD_LEAF 2 /* position of leaf pointer in KV_LEFT_DUMMY */
#define IE_FIRST_KEY		2

#define IE_FLAGS(ie)		(((dtp_t *) (ie))[IE_KEY_VERSION_OFF])
#define IE_SET_FLAGS(ie, f)	IE_FLAGS(ie) = f | (IE_FLAGS(ie) & 0x7f)
#define IE_ADD_FLAGS(ie, f)	IE_FLAGS(ie) = f | IE_FLAGS(ie)
#define IE_ISSET(ie, f) ((ie)[IE_KEY_VERSION_OFF] & (f))

#define IE_KEY_VERSION(ie)  (((db_buf_t)(ie))[IE_KEY_VERSION_OFF] & 0x7f)
#define IE_SET_KEY_VERSION(ie, kv) (ie[IE_KEY_VERSION_OFF] = kv)
#define IE_ROW_VERSION(ie) (((db_buf_t)(ie))[IE_ROW_VERSION_OFF])

#define CFG_FILE "wi.cfg"



#define ROW_OUT_SES(ses, area) \
  (memset (&(ses), 0, sizeof (ses)), \
   (ses).dks_out_buffer = (char*) &area, \
   (ses).dks_out_length = sizeof (area), \
   (ses).dks_out_fill = sizeof (short) )

#define ROW_OUT_SES_2(ses, area, len) \
  (memset (&(ses), 0, sizeof (ses)), \
   (ses).dks_out_buffer = (char *) area, \
   (ses).dks_out_length = (len), \
   (ses).dks_out_fill = sizeof (short) )

#define ROW_IN_SES_2(ses, sio, area, len) \
  (memset (&(ses), 0, sizeof (ses)), \
   memset (&sio, 0, sizeof (scheduler_io_data_t)), \
   SESSION_SCH_DATA (&ses) = &sio, \
   (ses).dks_in_buffer = (char*) area, \
   (ses).dks_in_length = len, \
   (ses).dks_in_fill = len )


typedef struct wi_database_s	wi_database_t;
typedef struct disk_stripe_s	disk_stripe_t;
typedef struct disk_segment_s	disk_segment_t;
typedef struct log_segment_s	log_segment_t;
typedef struct io_queue_s io_queue_t;

#define BACKUP_PREFIX_SZ	32

struct wi_database_s
  {
    dp_addr_t		db_extent_set;
    dp_addr_t		db_checkpoint_root;
    dp_addr_t		db_free_set;
    dp_addr_t		db_incbackup_set;
    dp_addr_t		db_registry;
    dp_addr_t		db_checkpoint_map;
    dp_addr_t		db_last_id;
    char		db_ver[12];
    char		db_generic[12];
    /* backup info */
    char		db_bp_prfx[BACKUP_PREFIX_SZ];
    dp_addr_t		db_bp_ts;
    dp_addr_t		db_bp_num;
    dp_addr_t		db_bp_pages;
    dp_addr_t		db_bp_date;
    /* byte order */
    char		db_byte_order;
    /* backup info again */
    dp_addr_t		db_bp_index;
    dp_addr_t		db_bp_wr_bytes;
    /* cluster */
    int32	db_host_id;	/* this db file set belongs to host nn */
    int32	db_stripe_unit;
    int32	db_extent_size;
    int32	db_initial_gen;
    char 	db_id[16];
  };

struct disk_stripe_s
  {
    disk_stripe_t *	dst_next; /* list of all stripes */
    dk_mutex_t *	dst_mtx;
    semaphore_t *	dst_sem;
    char *		dst_file;
    int *		dst_fds;
    int			dst_fd_fill;
    io_queue_t *	dst_iq;
    caddr_t		dst_iq_id;
  };

struct disk_segment_s
  {
    disk_stripe_t **	ds_stripes;
    int			ds_n_stripes;
    long		ds_size;
  };

struct log_segment_s
  {
    caddr_t		ls_file;
    unsigned long	ls_bytes;
    log_segment_t *	ls_next;
  };


extern int c_use_o_direct;
#if defined (WINDOWS) || defined (WINNT)
# define OPEN_FLAGS	O_RDWR | O_CREAT | O_BINARY
# define OPEN_FLAGS_RO	O_RDONLY | O_BINARY
# define fd_open(N,M)  _open (N, M, 0600)

# define fd_close(fd,n) \
{ \
  _close (fd); \
  if (n) \
    SetFileAttributes (n, FILE_ATTRIBUTE_ARCHIVE); \
}

# define file_set_rw(name) \
    SetFileAttributes (name, FILE_ATTRIBUTE_ARCHIVE); \

# define DB_OPEN_FLAGS	OPEN_FLAGS
# define LOG_OPEN_FLAGS OPEN_FLAGS
# define fd_fsync(N)   _commit (N)

#else

# ifndef O_BINARY
#  define O_BINARY	0
# endif

#ifndef O_LARGEFILE
#define O_LARGEFILE	0
#endif

#ifndef O_DIRECT
#define O_MAYBE_DIRECT 0
#else
#define O_MAYBE_DIRECT (c_use_o_direct ? O_DIRECT : 0)
#endif

#if defined (FILE64)
# define DB_OPEN_FLAGS	O_RDWR | O_CREAT | O_BINARY | O_LARGEFILE | O_MAYBE_DIRECT
# define OPEN_FLAGS	O_RDWR | O_CREAT | O_BINARY | O_LARGEFILE
# define OPEN_FLAGS_RO	O_RDONLY | O_BINARY | O_LARGEFILE
#else
# define DB_OPEN_FLAGS	O_RDWR | O_CREAT | O_BINARY | O_MAYBE_DIRECT
# define OPEN_FLAGS	O_RDWR | O_CREAT | O_BINARY
# define OPEN_FLAGS_RO	O_RDONLY | O_BINARY
#endif /* FILE64 */
#define LOG_OPEN_FLAGS OPEN_FLAGS

# define fd_open(N,M)  open (N, M, 0666)
# define fd_close(f,n)	close (f)
# define file_set_rw(N)
# define fd_fsync(N)   fsync (N)

#endif


/* aligned temp buffers in case )_DIRECT wants aligned buffers */

#define ALIGN_8K(p) ((void*) _RNDUP_PWR2 (((ptrlong)(p)), 8192))

#define ALIGNED_PAGE_ZERO(n) \
  dtp_t n##a[2 * PAGE_SZ]; \
  db_buf_t n= (db_buf_t) ALIGN_8K(&n##a[0]); \
  memset (n, 0, PAGE_SZ)

#define ALIGNED_PAGE_BUFFER(n) \
  dtp_t n##a[2 * 8192]; \
  db_buf_t n= (db_buf_t) ALIGN_8K(&n##a[0])

#define IS_IO_ALIGN(x) \
  (0 == (((unsigned ptrlong) (x)) & (PAGE_SZ - 1)))


#define DB_ORDER_UNKNOWN		0
#define DB_ORDER_BIG_ENDIAN		1
#define DB_ORDER_LITTLE_ENDIAN		2


#if __BYTE_ORDER == __BIG_ENDIAN
#  define DB_SYS_BYTE_ORDER		DB_ORDER_BIG_ENDIAN
#elif __BYTE_ORDER == __LITTLE_ENDIAN
#  define DB_SYS_BYTE_ORDER		DB_ORDER_LITTLE_ENDIAN
#else
#  error Byte order must be known
#endif



/* compare given byte order with current sys byte order, 0=equals, -1=non equals */
int dbs_byte_order_cmp (char byte_order);
extern int dst_fd (disk_stripe_t * dst);
extern void dst_fd_done (disk_stripe_t * dst, int fd);

#ifdef DBG_BLOB_PAGES_ACCOUNT
void db_dbg_account_add_page (dp_addr_t start);
void db_dbg_account_check_page_in_hash (dp_addr_t start);
void db_dbg_account_init_hash ();
#endif
extern int32 malloc_bufs;

#endif /* _WIDISK_H */

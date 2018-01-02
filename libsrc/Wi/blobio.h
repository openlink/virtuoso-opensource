/*
 *  blobio.h
 *
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

#ifndef _BLOBIO_H
#define _BLOBIO_H

#include "widisk.h"
#include "widv.h"
#include "multibyte.h"

struct blob_state_s
  {
    unsigned char utf8_chr;	/* this is for reading utf8 data from client */
    unsigned char count;	/* this is for prefetch in utf8 page read from client */
    dtp_t ask_tag;		/* previously read data chunk tag (for bh_get_data_from_user) */
    dtp_t need_tag;		/* column type (for bh_get_data_from_user) */
    caddr_t buffer;		/* this is necessary for blob2blob conversion with recoding */
    int bufpos;			/* current position in buffer */
    int buflen;			/* data bytes read in buflen*/
  };

typedef struct blob_state_s blob_state_t;

typedef unsigned char wblob_state_t;

struct blob_handle_s
  {
    dp_addr_t bh_page;		/* if blob is on disk as chained pages */
    dp_addr_t 	bh_current_page;	/* Keep track of position over SQLGetData calls */
    dp_addr_t 	bh_dir_page;	/* points at first directory page */
    int32	bh_position;		/* -- */ /* point on page or string */
    short	bh_frag_no;
    unsigned short	bh_slice;
    caddr_t bh_string;		/* if BLOB is in RAM as DV string */
    int64 bh_length;		/* Number of symbols in BLOB (either char-s or wchar_t-s */
    int64 bh_diskbytes;	/* Number of bytes required to store BLOB on disk
				    equal to bh_length for narrow-char BLOBs,
				    length of UTF8-ed string for DV_BLOB_WIDE_HANDLE */

    char bh_ask_from_client;	/* true when coming from log or from client by PutData */
    int 	bh_page_dir_complete;	/* true if bh_pages is complete, e.g. not only those dps ref'd on the row */
    char	bh_all_received;	/* true when client has sent end mark */
    char	bh_send_as_bh; /*do not inline as string over serialization, use for blob req in cluster */
    uint32	bh_bytes_coming;	/* byte count being sent by client */
    long	bh_param_index;	/* Use this index when asking from client */
    dp_addr_t *bh_pages;	/* a contiguous array of pages IDs, allocated as a DV_CUSTOM. */
    struct index_tree_s *	bh_it;
    uint32		bh_key_id;
    uint32		bh_timestamp;
    blob_state_t	bh_state;
    caddr_t 		bh_source_session; /* used when bh_get_data_from_client is 3 */
  };


#define BH_CLUSTER_DAE 5 /* in bh_ask_from_client to indicate that this is a data at exec blob made as temp before use on anothr partition */
typedef struct blob_handle_s blob_handle_t;

#define BH_ANY		((uint32)(-1))
#define BH_DIRTYREAD	((dk_set_t)(-1))

#define BH_FROM_CLUSTER(bh) \
  ((bh)->bh_frag_no && (bh)->bh_frag_no != local_cll.cll_this_host)


/* Bit fields used for blob_layout_s::bl_delete_later */
#define BL_DELETE_AT_COMMIT	0x01
#define BL_DELETE_AT_ROLLBACK	0x02

/*! This structure is used in lt_blobs_delete_at_commit &
   lt_blobs_delete_at_rollback queues of transaction. It should be allocated by
   'blob_layout_ctor' function and will be freed by 'blob_chain_delete' */

/*#define BL_DEBUG*/
struct blob_layout_s
  {
    dtp_t bl_blob_handle_dtp;	/*!< Type of BLOB handle, to pay special attention to the length of wide BLOBs */
    dp_addr_t bl_start;		/*!< First page of blob sequence */
    dp_addr_t bl_dir_start;	/*!< First page of blob directory sequence, if unknown = 0 and it will be tried to fetch it from DP_PARENT offset of the first blob page */
    int64 bl_length;		/*!< Number of symbols in BLOB, 0 if unknown */
    int64 bl_diskbytes;	/*!< Number of bytes required to store BLOB on disk, 0 if unknown */
    dp_addr_t * bl_pages;	/*!< Page directory or NULL if not yet known. */
    int	bl_page_dir_complete;	/*!< Flags if we have to read bl_page_dir in order to get all pages */
    int bl_delete_later;	/*!< Flags if this blob should be deleted later in case of commit and/or rollback */
    struct index_tree_s * bl_it;	/*!< Index tree of the row that contains the field with this blob. */
#ifdef BL_DEBUG
    const char *file_alloc;
    int line_alloc;
    const char *file_free;
    int line_free;
#endif
  };

typedef struct blob_layout_s blob_layout_t;

/* parameters correspond to the fields of 'blob_del_t'*/

/* IvAn/DvBlobXper/001212 This function is no longer usable.
   blob_handle_t *bh_allocate (int isWide);

   Now bh_alloc should be used to create blob handle of given type DV_BLOB_xxx_HANDLE */
#define bh_alloc(handle_dtp) \
 ((blob_handle_t *)(dk_alloc_box_zero (sizeof (blob_handle_t), (handle_dtp))))

void bh_free (blob_handle_t * bh);

void iri_id_write (iri_id_t *iid, dk_session_t * ses);

void blobio_init (void);
caddr_t datetime_serialize (caddr_t dt, dk_session_t * out);
void dt_to_string (const char *dt, char *str, int len);
void dt_to_iso8601_string (const char *dt, char *str, int len);
void dt_to_iso8601_string_ext (const char *dt, char *buf, int len, int mode);
void dt_to_rfc1123_string (const char *dt, char *str, int len);
void dt_to_ms_string (const char *dt, char *str, int len);
void sec_login_digest (char *ses_name, char *user, char *pwd, unsigned char *digest);
int http_date_to_dt (const char *http_date, char *dt);

void bh_serialize (blob_handle_t * bh, dk_session_t * ses);
void bh_serialize_wide (blob_handle_t * bh, dk_session_t * ses);
void bh_serialize_xper (blob_handle_t * bh, dk_session_t * ses);

struct index_space_s;
struct lock_trx_s;
struct it_cursor_s;

int bh_read_ahead (struct lock_trx_s *lt, blob_handle_t * bh, unsigned from, unsigned to);


int rbs_length (db_buf_t rbs);
void rbs_hash_range (dtp_t ** buf, int * len, int * is_string);
int64 rbs_ro_id (db_buf_t rbs);

extern caddr_t rb_copy (rdf_box_t * rb);
extern void rb_complete (rdf_box_t * rb, struct lock_trx_s * lt, void * /*actually query_instance_t * */ caller_qi);
extern void rb_complete_1 (rdf_box_t * rb, struct lock_trx_s * lt, void * /*actually query_instance_t * */ caller_qi, int is_local);

#define RDF_POP(dtp, data, lt)			\
{ \
  if (DV_RDF == dtp) \
    {\
      if (! ((rdf_box_t*)data)->rb_is_complete) \
	rb_complete (data, lt, CALLER_LOCAL); \
      data = ((rdf_box_t *)data)->rb_box; \
    } \
}


#define RDF_POP_NC(dtp, data)			\
{ \
  if (DV_RDF == dtp) \
    {\
      if (((rdf_box_t*)data)->rb_is_complete) \
	data = ((rdf_box_t *)data)->rb_box; \
      else\
	sqlr_new_error ("22032", "RDFBX", "An incomplete outlined rdf box is not a valid operand for function."); \
    } \
}


#define RDF_POP_NO_ERROR(dtp, data, not_complete)		\
{ \
  if (DV_RDF == dtp) \
    {\
      if (((rdf_box_t*)data)->rb_is_complete) \
	data = ((rdf_box_t *)data)->rb_box; \
      else\
	goto not_complete; \
    } \
}


/* The following has nothing to do with blobs, but is here because this
   header file is included both by wi.h and cliint.h, of which the former
   in turn is included by the server's module sqlbif.c and the latter by
   client's module cliuti.c
   These both modules use strtok_r function which probably does not exist
   in MS Visual C environment.
   For a while, we use the following macro which just uses the ordinary
   strtok and ignores the third argument altogether.
   AK 11-MAR-1997.
 */

#if defined (NO_THREAD) || defined  (WIN32) || defined (LINUX)
#define NO_STRTOK_R
#endif

#ifdef NO_STRTOK_R
#ifndef strtok_r
#define strtok_r(X,Y,Z) strtok((X),(Y))
#endif
#endif

/* Similarly with these two: */
#ifdef WIN32
#ifndef strncasecmp
#define strncasecmp strnicmp
#endif
#ifndef strcasecmp
#define strcasecmp  stricmp
#endif
#endif

#endif /* _BLOBIO_H */

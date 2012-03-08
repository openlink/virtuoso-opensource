/*
 *  blobio.c
 *
 *  $Id$
 *
 *  Marshallers for DV_BLOB_HANDLE and DV_TIMESTAMP_OBJ
 *  Should really be part of Dk
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

#include "virtpwd.h"
#include "CLI.h"
#include "multibyte.h"
#include "sqlfn.h"
#include "numeric.h"

#ifdef _SSL
#include <openssl/md5.h>
#define MD5Init   MD5_Init
#define MD5Update MD5_Update
#define MD5Final  MD5_Final
#else
#include "util/md5.h"
#endif /* _SSL */


void
bh_free (blob_handle_t * bh)
{
  dk_free_box ((caddr_t) bh);
}

/*
   BH printed representation.
   bh_ask_from_client
   if ask_from_client
   bh_param_index
   else
   bh_page

   A blob to be fetched from client (SQLPutData) is marked by param
   index. A blob to send to client is marked by page no.
 */

void
bh_serialize_compat (blob_handle_t * bh, dk_session_t * ses)
{
  if (BLOB_NULL_RECEIVED == bh->bh_all_received)
    {
      session_buffered_write_char (DV_DB_NULL, ses);
      return;
    }
  session_buffered_write_char (DV_BLOB_HANDLE, ses);
  print_long (bh->bh_ask_from_client, ses);
  if (bh->bh_ask_from_client)
    print_long (bh->bh_param_index, ses);
  else
    print_long (bh->bh_page, ses);
  print_long ((long) MIN (bh->bh_length, LONG_MAX), ses);
  print_long (bh->bh_key_id, ses);
  print_long (bh->bh_frag_no, ses);
  print_long (bh->bh_dir_page, ses);
  print_long (bh->bh_timestamp, ses);
  print_object  (bh->bh_pages, ses, NULL, NULL);
}

blob_handle_t *
bh_deserialize_compat (dk_session_t * session)
{
  blob_handle_t *bh;
  MARSH_CHECK_BOX (bh = (blob_handle_t *) dk_try_alloc_box (
      sizeof (blob_handle_t), DV_BLOB_HANDLE));
  memset (bh, 0, sizeof (blob_handle_t));

  bh->bh_ask_from_client = read_long (session);
  if (bh->bh_ask_from_client)
    {
      bh->bh_param_index = read_long (session);
    }
  else
    {
      bh->bh_page = read_long (session);
    }
  bh->bh_length = read_long (session);
  bh->bh_key_id = (unsigned short) read_long (session);
  bh->bh_frag_no = (short) read_long (session);
  bh->bh_dir_page = read_long (session);
  bh->bh_timestamp = read_long (session);
  bh->bh_pages = (dp_addr_t *) scan_session (session);
  return bh;
}

void
bh_serialize_wide_compat (blob_handle_t * bh, dk_session_t * ses)
{
  if (BLOB_NULL_RECEIVED == bh->bh_all_received)
    {
      session_buffered_write_char (DV_DB_NULL, ses);
      return;
    }
  session_buffered_write_char (DV_BLOB_WIDE_HANDLE, ses);
  print_long (bh->bh_ask_from_client, ses);
  if (bh->bh_ask_from_client)
    print_long (bh->bh_param_index, ses);
  else
    print_long (bh->bh_page, ses);
  print_long ((long) MIN (LONG_MAX, bh->bh_length), ses);
  print_long (bh->bh_key_id, ses);
  print_long (bh->bh_frag_no, ses);
  print_long (bh->bh_dir_page, ses);
  print_long (bh->bh_timestamp, ses);
  print_object  (bh->bh_pages, ses, NULL, NULL);
}


blob_handle_t *
bh_deserialize_wide_compat (dk_session_t * session)
{
  blob_handle_t *bh;

  MARSH_CHECK_BOX (bh = (blob_handle_t *) dk_try_alloc_box (
      sizeof (blob_handle_t), DV_BLOB_WIDE_HANDLE));
  memset (bh, 0, sizeof (blob_handle_t));

  bh->bh_ask_from_client = read_long (session);
  if (bh->bh_ask_from_client)
    {
      bh->bh_param_index = read_long (session);
    }
  else
    {
      bh->bh_page = read_long (session);
    }
  bh->bh_length = read_long (session);
  bh->bh_key_id = (unsigned short) read_long (session);
  bh->bh_frag_no = (short) read_long (session);
  bh->bh_dir_page = read_long (session);
  bh->bh_timestamp = read_long (session);
  bh->bh_pages = (dp_addr_t *) scan_session (session);
  return bh;
}

void
bh_serialize (blob_handle_t * bh, dk_session_t * ses)
{
  client_connection_t *cli = DKS_DB_DATA (ses);
  if (BLOB_NULL_RECEIVED == bh->bh_all_received)
    {
      session_buffered_write_char (DV_DB_NULL, ses);
      return;
    }
  if (cli && cli->cli_version < 3104)
    {
      bh_serialize_compat (bh, ses);
      return;
    }
  session_buffered_write_char (DV_BLOB_HANDLE, ses);
  print_int (bh->bh_ask_from_client, ses);
  if (bh->bh_ask_from_client)
    print_int (bh->bh_param_index, ses);
  else
    print_int (bh->bh_page, ses);
  print_int (bh->bh_length, ses);
  print_int (bh->bh_diskbytes, ses);
  print_int (bh->bh_key_id, ses);
  print_int (bh->bh_frag_no, ses);
  print_int (bh->bh_dir_page, ses);
  print_int (bh->bh_timestamp, ses);
  print_object  (bh->bh_pages, ses, NULL, NULL);
}


caddr_t
bh_deserialize (dk_session_t * session)
{
  blob_handle_t *bh;
  client_connection_t *cli = DKS_DB_DATA (session);
  if (cli && cli->cli_version < 3104)
    {
      bh = bh_deserialize_compat (session);
      return (caddr_t) bh;
    }
  MARSH_CHECK_BOX (bh = (blob_handle_t *) dk_try_alloc_box (
      sizeof (blob_handle_t), DV_BLOB_HANDLE));
  memset (bh, 0, sizeof (blob_handle_t));

  bh->bh_ask_from_client = read_int (session);
  if (bh->bh_ask_from_client)
    {
      bh->bh_param_index = read_int (session);
    }
  else
    {
      bh->bh_page = read_int (session);
    }
  bh->bh_length = read_int (session);
  bh->bh_diskbytes = read_int (session);
  bh->bh_key_id = (unsigned short) read_int (session);
  bh->bh_frag_no = (short) read_int (session);
  bh->bh_dir_page = read_int (session);
  bh->bh_timestamp = read_int (session);
  bh->bh_pages = (dp_addr_t *) scan_session (session);
  return ((caddr_t) bh);
}


void
bh_serialize_xper (blob_handle_t * bh, dk_session_t * ses)
{
  if (BLOB_NULL_RECEIVED == bh->bh_all_received)
    {
      session_buffered_write_char (DV_DB_NULL, ses);
      return;
    }
  session_buffered_write_char (DV_BLOB_XPER_HANDLE, ses);
  print_long (bh->bh_ask_from_client, ses);
  if (bh->bh_ask_from_client)
    print_long (bh->bh_param_index, ses);
  else
    print_long (bh->bh_page, ses);
  print_long ((long) bh->bh_length, ses);
  print_long (bh->bh_key_id, ses);
  print_long (bh->bh_frag_no, ses);
  print_long (bh->bh_dir_page, ses);
  print_long (bh->bh_timestamp, ses);
  print_object  (bh->bh_pages, ses, NULL, NULL);
}


caddr_t
bh_deserialize_xper (dk_session_t * session)
{
  blob_handle_t *bh;
  MARSH_CHECK_BOX (bh = (blob_handle_t *) dk_try_alloc_box (
      sizeof (blob_handle_t), DV_BLOB_XPER_HANDLE));
  memset (bh, 0, sizeof (blob_handle_t));
  bh->bh_ask_from_client = read_long (session);
  if (bh->bh_ask_from_client)
    {
      bh->bh_param_index = read_long (session);
    }
  else
    {
      bh->bh_page = read_long (session);
    }
  bh->bh_length = read_long (session);
  bh->bh_key_id = (unsigned short) read_long (session);
  bh->bh_frag_no = (short) read_long (session);
  bh->bh_dir_page = read_long (session);
  bh->bh_timestamp = read_long (session);
  bh->bh_pages = (dp_addr_t *) scan_session (session);
  return ((caddr_t) bh);
}


void
bh_serialize_wide (blob_handle_t * bh, dk_session_t * ses)
{
  client_connection_t *cli = DKS_DB_DATA (ses);
  if (BLOB_NULL_RECEIVED == bh->bh_all_received)
    {
      session_buffered_write_char (DV_DB_NULL, ses);
      return;
    }
  if (cli && cli->cli_version < 3104)
    {
      bh_serialize_wide_compat (bh, ses);
      return;
    }
  session_buffered_write_char (DV_BLOB_WIDE_HANDLE, ses);
  print_int (bh->bh_ask_from_client, ses);
  if (bh->bh_ask_from_client)
    print_int (bh->bh_param_index, ses);
  else
    print_int (bh->bh_page, ses);
  print_int (bh->bh_length, ses);
  print_int (bh->bh_diskbytes, ses);
  print_int (bh->bh_key_id, ses);
  print_int (bh->bh_frag_no, ses);
  print_int (bh->bh_dir_page, ses);
  print_int (bh->bh_timestamp, ses);
  print_object  (bh->bh_pages, ses, NULL, NULL);
}


caddr_t
bh_deserialize_wide (dk_session_t * session)
{
  blob_handle_t *bh;
  client_connection_t *cli = DKS_DB_DATA (session);
  if (cli && cli->cli_version < 3104)
    {
      bh = bh_deserialize_compat (session);
      return (caddr_t) bh;
    }

  MARSH_CHECK_BOX (bh = (blob_handle_t *) dk_try_alloc_box (
      sizeof (blob_handle_t), DV_BLOB_WIDE_HANDLE));
  memset (bh, 0, sizeof (blob_handle_t));

  bh->bh_ask_from_client = read_int (session);
  if (bh->bh_ask_from_client)
    {
      bh->bh_param_index = read_int (session);
    }
  else
    {
      bh->bh_page = read_int (session);
    }
  bh->bh_length = read_int (session);
  bh->bh_diskbytes = read_int (session);
  bh->bh_key_id = (unsigned short) read_int (session);
  bh->bh_frag_no = (short) read_int (session);
  bh->bh_dir_page = read_int (session);
  bh->bh_timestamp = read_int (session);
  bh->bh_pages = (dp_addr_t *) scan_session (session);
  return ((caddr_t) bh);
}


/* The timestamp object serialization, deserialization */





caddr_t
datetime_serialize (caddr_t dt_in, dk_session_t * out)
{
  caddr_t dt = dt_in;
#if 0
  unsigned char dt_loc [DT_LENGTH];
  int dt_type = DT_DT_TYPE (dt);

  if (dt_type == DT_TYPE_DATETIME || dt_type == DT_TYPE_DATE || dt_type == DT_TYPE_TIME)
    { /* do not pass typed dates across the wire until compatibility issues resolved */
      int tz = DT_TZ (dt);
      memcpy (dt_loc, dt_in, DT_LENGTH);
      dt = &(dt_loc[0]);
      DT_SET_COMPAT_TZ (dt, tz);
    }
#endif

  session_buffered_write_char (DV_DATETIME, out);
  session_buffered_write (out, dt, DT_LENGTH);
  return NULL;
}


caddr_t
datetime_deserialize (dk_session_t * session)
{
  caddr_t dt;
  MARSH_CHECK_BOX (dt = dk_try_alloc_box (DT_LENGTH, DV_DATETIME));
  session_buffered_read (session, dt, DT_LENGTH);
#if 0
  /* for now all the dates from the wire come as DATETIME. see datetime_serialize */
  DT_SET_DT_TYPE (dt, DT_TYPE_DATETIME);
#endif
  return dt;
}


caddr_t
numeric_box_copy (caddr_t b)
{
  numeric_t n = numeric_allocate ();
  numeric_copy (n, (numeric_t) b);
  return ((caddr_t) n);
}


caddr_t
ign_deserialize (dk_session_t * ses)
{
  return (dk_alloc_box (0, DV_IGNORE));
}


void
ign_serialize (caddr_t ign, dk_session_t * ses)
{
  session_buffered_write_char (DV_IGNORE, ses);
}


void
print_bin_string (char *string, dk_session_t * session)
{
  /* There will be a zero at the end. Do not send the zero. */
  size_t length = box_length (string);
  if (length < 256)
    {
      session_buffered_write_char (DV_BIN, session);
      session_buffered_write_char ((char) length, session);
    }
  else
    {
      session_buffered_write_char (DV_LONG_BIN, session);
      print_long ((long) length, session);
    }
  session_buffered_write (session, string, length);
}


void *
box_read_bin_string (dk_session_t * session, dtp_t dtp)
{
  size_t length = session_buffered_read_char (session);
  char *string;
  MARSH_CHECK_BOX (string = (char *) dk_try_alloc_box (length, DV_BIN));
  session_buffered_read (session, string, (int) length);
  return (void *) string;
}


void *
box_read_long_bin_string (dk_session_t * session, dtp_t dtp)
{
  size_t length = (size_t) read_long (session);
  char *string;
  MARSH_CHECK_LENGTH (length);
  MARSH_CHECK_BOX (string = (char *) dk_try_alloc_box (length, DV_BIN));
  session_buffered_read (session, string, (int) length);
  return (void *) string;
}


void *
box_read_composite (dk_session_t * session, dtp_t dtp)
{
  size_t length = session_buffered_read_char (session);
  unsigned char *string;
  MARSH_CHECK_LENGTH (length + 2);
  MARSH_CHECK_BOX (string = (unsigned char *) dk_try_alloc_box (length + 2, DV_COMPOSITE));
  session_buffered_read (session, (char *) (string + 2), (int) length);
  string[0] = DV_COMPOSITE;
  string[1] = (dtp_t) length;
  return (void *) string;
}


void
print_composite (char *string, dk_session_t * session)
{
  size_t length = box_length (string);
  if (length < 2)
    {
      session_buffered_write_char (DV_DB_NULL, session);
      return;
    }
  if (length < 256)
    {
      session_buffered_write_char (DV_COMPOSITE, session);
      session_buffered_write_char ((char) length - 2, session);
    }
  else
    GPF_T1 ("limit of 255 on length of DV_COMPOSITE");
  session_buffered_write (session, string + 2, length - 2);
}

static caddr_t
comp_copy (caddr_t comp)
{
  int comp_len = box_length (comp);
  caddr_t ret = dk_alloc_box (comp_len, DV_COMPOSITE);
  if (comp_len > 0)
    memcpy (ret, comp, comp_len);
  return ret;
}

static int
comp_destroy (caddr_t comp)
{
  return 0;
}


/* Destruction and copy semantics for BLOB handlers */

int
bh_destroy (caddr_t box)
{
  blob_handle_t *bh = (blob_handle_t *) box;
  if (NULL != bh->bh_pages)
    {
      dk_free_box ((box_t) bh->bh_pages);
      bh->bh_pages = NULL;
    }
  if (NULL != bh->bh_state.buffer)
    {
      dk_free_box (bh->bh_state.buffer);
      bh->bh_state.buffer = NULL;
    }
  if (bh->bh_source_session)
    {
      dk_free_box (bh->bh_source_session);
      bh->bh_source_session = NULL;
    }
  return 0;
}


caddr_t
bh_copy (caddr_t box)
{
  blob_handle_t *bh = (blob_handle_t *) box;
  blob_handle_t *bhcopy = bh_alloc (box_tag (box));
  memcpy (bhcopy, bh, sizeof (*bhcopy));
  bhcopy->bh_pages = (dp_addr_t *) box_copy ((caddr_t) bhcopy->bh_pages);
  bh->bh_source_session = NULL;
  bhcopy->bh_state.buffer = box_copy_tree (bhcopy->bh_state.buffer);
  if (bh->bh_ask_from_client == 2 || bh->bh_ask_from_client == 2)
    bhcopy->bh_ask_from_client = 0;
  return (caddr_t) bhcopy;
}


caddr_t
bh_mp_copy (mem_pool_t * mp, caddr_t box)
{
  blob_handle_t *bh = (blob_handle_t *) box;
  blob_handle_t *bhcopy = (blob_handle_t *)mp_alloc_box (mp, sizeof (blob_handle_t), box_tag (box));
  memcpy (bhcopy, bh, sizeof (*bhcopy));
  bhcopy->bh_pages = (dp_addr_t *) mp_box_copy (mp, (caddr_t) bhcopy->bh_pages);
  bh->bh_source_session = NULL;
  bhcopy->bh_state.buffer = mp_full_box_copy_tree (mp, bhcopy->bh_state.buffer);
  if (bh->bh_ask_from_client == 2 || bh->bh_ask_from_client == 2)
    bhcopy->bh_ask_from_client = 0;
  return (caddr_t) bhcopy;
}


static int
symbol_write (char * string, dk_session_t * session)
{
  size_t length = box_length (string) - 1;
  session_buffered_write_char (DV_SYMBOL, session);
  print_long ((long) length, session);
  session_buffered_write (session, string, length);
  return (int) length;
}

static void *
box_read_symbol (dk_session_t *session, dtp_t dtp)
{
  size_t length = (size_t) read_long (session);
  char *string = (char *) dk_alloc_box (length + 1, DV_SYMBOL);
  session_buffered_read (session, string, (int) length);
  string[length] = 0;
  return (void *) string;
}

static void *
udt_client_deserialize (dk_session_t * session, dtp_t dtp)
{
  caddr_t ret;
  long udt_id;

  udt_id = read_long (session);
  ret = (caddr_t) scan_session_boxing (session);
  return ret;
}


static void *
udt_client_ref_deserialize (dk_session_t * session, dtp_t dtp)
{
  caddr_t ret;
  long len;

  if (dtp == DV_REFERENCE)
    len = read_long (session);
  else
    len = session_buffered_read_char (session);
  ret = dk_alloc_box (len, DV_BIN);
  session_buffered_read (session, ret, len);
  return ret;
}

static char
pass1[] = "7rLrT7iG3kWWLuSDYdS/KIXO8JF86h12KyCTG1Mh0qxWdSZ6ezHRST0UuGl6xkbMgsXj4+eZbXNyYijRmoaaJm+hQCWSOW+0OHGCnYWB4upxi0Fogdu0gb+q4VFzyUFknEpZPg==";
static char
pass2[] = "PCuJhpWX5eApg2mRs0bvSIdfwSDUa0kjiSdd76ORgXYyhtLbHm4Uq6afLbfROLi5pDpjKVS9Vr9aZo+F3IpyZ6Zn6m/Xf1PRtq3jdseJht4VSduxHrpocKVdRh3LixXKr6Ue6A==";
static char the_pass[] = EMPTY_PASS;
#define MD5_SIZE 16

static void
calculate_pass ()
{
  if (the_pass[0] == 'x')
    {
      int inx;
      for (inx = 0; inx < sizeof (pass2); inx++)
	{
	  the_pass[inx] = pass1[inx] ^ pass2[inx];
	  if (!the_pass[inx])
	    the_pass[inx] = pass1[inx];
	}
    }
}


void
xx_encrypt_passwd (char *thing, int thing_len, char *user_name)
{
  int md5_inx;
  unsigned char md5[MD5_SIZE], *thing_ptr;
  MD5_CTX ctx;
  calculate_pass ();
  memset (&ctx, 0, sizeof (MD5_CTX));
  MD5Init (&ctx);
  if (user_name && *user_name)
    MD5Update (&ctx, (unsigned char *) user_name, (unsigned) strlen (user_name));
  MD5Update (&ctx, (unsigned char *) the_pass, sizeof (the_pass));
  MD5Final (md5, &ctx);
  for (md5_inx = 0, thing_ptr = (unsigned char *) thing; thing_ptr - ((unsigned char *)thing) < thing_len;
      thing_ptr++, md5_inx = (md5_inx+1) % MD5_SIZE)
    *thing_ptr = *thing_ptr ^ md5[md5_inx];
}


void
iri_id_write (iri_id_t * iid, dk_session_t * ses)
{
  iri_id_t n = *iid;
  int fill = ses->dks_out_fill;
  if (n <= 0xffffffff)
    {
      if (fill + 5 <= ses->dks_out_length)
	{
	  ses->dks_out_buffer[fill] = DV_IRI_ID;
	  LONG_SET_NA (ses->dks_out_buffer + fill + 1, n);
	  ses->dks_out_fill += 5;
	}
      else
	{
	  session_buffered_write_char (DV_IRI_ID, ses);
	  print_long (n, ses);
	}
    }
  else
    {
      if (fill + 9 <= ses->dks_out_length)
	{
	  ses->dks_out_buffer[fill] = DV_IRI_ID_8;
	  INT64_SET_NA (ses->dks_out_buffer + fill + 1, n);
	  ses->dks_out_fill += 9;
	}
      else
	{
	  session_buffered_write_char (DV_IRI_ID_8, ses);
	  print_long (n >> 32, ses);
	  print_long (n & 0xffffffff, ses);
	}
    }
}


void *
box_read_iri_id (dk_session_t * ses, dtp_t dtp)
{
  iri_id_t l, h = 0;
  if (DV_IRI_ID == dtp)
    {
      l = (unsigned int32)read_long (ses);
    }
  else
    {
      h = (unsigned int32)read_long (ses);
      l = (unsigned int32)read_long (ses);
    }
  return (void*) box_iri_id (h << 32 | l);
}


int blobio_inited = 0;

void
blobio_init (void)
{
  macro_char_func *rt;
  if (blobio_inited)
    return;
  blobio_inited = 1;

  rt = get_readtable ();
  PrpcSetWriter (DV_BLOB_HANDLE, (ses_write_func) bh_serialize);
  rt[DV_BLOB_HANDLE] = (macro_char_func) bh_deserialize;
  PrpcSetWriter (DV_BLOB_XPER_HANDLE, (ses_write_func) bh_serialize_xper);
  rt[DV_BLOB_XPER_HANDLE] = (macro_char_func) bh_deserialize_xper;
  PrpcSetWriter (DV_BLOB_WIDE_HANDLE, (ses_write_func) bh_serialize_wide);
  rt[DV_BLOB_WIDE_HANDLE] = (macro_char_func) bh_deserialize_wide;
  PrpcSetWriter (DV_DATETIME, (ses_write_func) datetime_serialize);
  rt[DV_DATETIME] = (macro_char_func) datetime_deserialize;
  dt_init ();

  PrpcSetWriter (DV_NUMERIC, (ses_write_func) numeric_serialize);
  rt[DV_NUMERIC] = (macro_char_func) numeric_deserialize;
  PrpcSetWriter (DV_IGNORE, (ses_write_func) ign_serialize);
  rt[DV_IGNORE] = (macro_char_func) ign_deserialize;
  numeric_init ();

  PrpcSetWriter (DV_BIN, (ses_write_func) print_bin_string);
  rt[DV_BIN] = (macro_char_func) box_read_bin_string;
  rt[DV_LONG_BIN] = (macro_char_func) box_read_long_bin_string;

  PrpcSetWriter (DV_WIDE, (ses_write_func) wide_serialize);
  PrpcSetWriter (DV_LONG_WIDE, (ses_write_func) wide_serialize);
  rt[DV_WIDE] = (macro_char_func) box_read_wide_string;
  rt[DV_LONG_WIDE] = (macro_char_func) box_read_long_wide_string;
  rt[DV_COMPOSITE] = (macro_char_func) box_read_composite;
  PrpcSetWriter (DV_COMPOSITE, (ses_write_func) print_composite);
  dk_mem_hooks (DV_COMPOSITE, comp_copy, comp_destroy, 0);
  /* Hooks added for BLOB handlers to process page directories */
  dk_mem_hooks_2 (DV_BLOB_HANDLE, bh_copy, bh_destroy, 0, bh_mp_copy);
  dk_mem_hooks_2 (DV_BLOB_XPER_HANDLE, bh_copy, bh_destroy, 0, bh_mp_copy);
  dk_mem_hooks_2 (DV_BLOB_WIDE_HANDLE, bh_copy, bh_destroy, 0, bh_mp_copy);

  PrpcSetWriter (DV_SYMBOL, (ses_write_func) symbol_write);
  rt[DV_SYMBOL] = box_read_symbol;

  PrpcSetWriter (DV_IRI_ID, (ses_write_func) iri_id_write);
  rt[DV_IRI_ID] = box_read_iri_id;
  rt[DV_IRI_ID_8] = box_read_iri_id;


  rt[DV_OBJECT] = udt_client_deserialize;
  rt[DV_REFERENCE] = udt_client_ref_deserialize;
  rt[DV_SHORT_REF] = udt_client_ref_deserialize;
  calculate_pass();
}

#undef MD5_CTX

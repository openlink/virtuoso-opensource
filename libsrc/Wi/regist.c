/*
 *  regist.c
 *
 *  $Id$
 *
 *  Database Registry
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
 */

#include "sqlnode.h"
#include "sqlfn.h"
#include "log.h"


void
cli_bootstrap_cli ()
{
  if (!bootstrap_cli)
    {
      bootstrap_cli = client_connection_create ();
      local_start_trx (bootstrap_cli);
    }
}


buffer_desc_t *reg_buf;


int
cpt_write_registry (dbe_storage_t * dbs, dk_session_t *ses)
{
  int err = 0;
  long copy_bytes;
  long prev_size = 0, bytes_left = strses_length (ses);
  int n_pages = _RNDUP (bytes_left, PAGE_DATA_SZ) / PAGE_DATA_SZ, n_prev_pages;
  long byte_from = 0;
  dp_addr_t first = dbs->dbs_registry;
  dp_addr_t any_page = first;
  dk_set_t new_dps = NULL;
  if (first)
    {
      dk_session_t * strses = bloblike_pages_to_string_output (dbs, bootstrap_cli->cli_trx, dbs->dbs_registry, &err);
      if (err)
	{
	  log_error ("A bad registry has been detected in cpt.  Making new registry.");
	  prev_size = first = any_page = 0;
	}
      else
	prev_size = strses_length (strses);
      dk_free_box (strses);
    }

  n_prev_pages = _RNDUP (prev_size, PAGE_DATA_SZ) / PAGE_DATA_SZ;
  if (n_pages > n_prev_pages)
    {
      int ctr;
      for (ctr = n_prev_pages; ctr < n_pages; ctr++)
	{
	  dp_addr_t dp = em_new_dp (dbs->dbs_extent_map, EXT_INDEX, 0, NULL);
	  if (!dp)
	    {
	      log_error ("out of disk for writing registry.  Checkpoint not started.");
	      while ((dp = (dp_addr_t)(uptrlong)dk_set_pop (&new_dps)))
		em_free_dp (dbs->dbs_extent_map, dp, EXT_INDEX);
	      return LTE_NO_DISK;
	    }
	  dk_set_push (&new_dps, (void*)(uptrlong)dp);
	}
      new_dps = dk_set_nreverse (new_dps);
    }
  if (!reg_buf)
    {
      reg_buf = buffer_allocate (DPF_BLOB);
      reg_buf->bd_storage = dbs;
    }
  CATCH_READ_FAIL (ses)
    {
      while (bytes_left)
	{
	  if (!first)
	    {
	      dp_addr_t new_dp = (dp_addr_t)(uptrlong)dk_set_pop (&new_dps);
	      if (!any_page)
		{
		  dbs->dbs_registry = new_dp;
		  any_page = new_dp;
		  reg_buf->bd_page = reg_buf->bd_physical_page = new_dp;
		}
	      else
		{
		  LONG_SET (reg_buf->bd_buffer + DP_OVERFLOW, new_dp);
		  buf_disk_write (reg_buf, 0);
		  reg_buf->bd_page = new_dp;
		  reg_buf->bd_physical_page = new_dp;
		}
	      LONG_SET (reg_buf->bd_buffer + DP_OVERFLOW, 0);
	    }
	  else
	    {
	      reg_buf->bd_page = first;
	      reg_buf->bd_physical_page = first;
	      buf_disk_read (reg_buf);
	    }
	  copy_bytes = MIN (PAGE_DATA_SZ, bytes_left);
	  session_buffered_read (ses, (char *) (reg_buf->bd_buffer + DP_DATA), copy_bytes);
	  LONG_SET (reg_buf->bd_buffer + DP_BLOB_LEN, copy_bytes);
	  bytes_left -= copy_bytes;
	  byte_from += copy_bytes;
	  first = LONG_REF (reg_buf->bd_buffer + DP_OVERFLOW);
	  if (!bytes_left && first)
	    {
	      LONG_SET (reg_buf->bd_buffer + DP_OVERFLOW, 0);
	      buf_disk_write (reg_buf, 0);
	      while (first)
		{
		  reg_buf->bd_page = first;
		  reg_buf->bd_physical_page = first;
		  buf_disk_read (reg_buf);
		  freeing_unfreeable = 1;
		  em_free_dp (dbs->dbs_extent_map, first, EXT_INDEX);
		  freeing_unfreeable = 0;
		  first = LONG_REF (reg_buf->bd_buffer + DP_OVERFLOW);
		}
	    }
	  else
	    buf_disk_write (reg_buf, 0);
	}
    }
  FAILED
    {
      GPF_T1 ("Inconsistent number of bytes read in cpt_write_registry");
    }
  END_READ_FAIL (ses);
  return LTE_OK;
}

#ifdef DBG_BLOB_PAGES_ACCOUNT
extern int f_backup_dump;
#endif


dk_session_t *
dbs_read_registry (dbe_storage_t * dbs, client_connection_t * cli)
{
#ifdef DBG_BLOB_PAGES_ACCOUNT
  if (f_backup_dump)
    db_dbg_account_init_hash ();
#endif
  if (!cli)
    {
      cli_bootstrap_cli ();
      cli = bootstrap_cli;
    }

  if (dbs->dbs_registry)
    {
      int err;
      dk_session_t *str = bloblike_pages_to_string_output (dbs, cli->cli_trx, dbs->dbs_registry, &err);
      if (cli == bootstrap_cli)
	local_commit (bootstrap_cli);
      return str;
    }
  else
    return NULL;
}


id_hash_t *registry;
id_hash_t *sequences;

#define ENSURE_REGISTRY \
  if (!registry) registry = id_str_hash_create (101);

#define ENSURE_SEQUENCES \
  if (!sequences)  \
sequences = id_hash_allocate  (101, sizeof (void *), sizeof (boxint), \
				 strhash, strhashcmp);


caddr_t
box_deserialize_string (caddr_t text, int opt_len, short offset)
{
  dtp_t dvrdf_temp[50];
  scheduler_io_data_t iod;
  caddr_t reg, buf = (caddr_t) dvrdf_temp;

  dk_session_t ses;
  /* read_object will not box top level numbers */
  switch ((dtp_t)text[0])
    {
    case DV_LONG_INT:
      return (box_num (LONG_REF_NA (text + 1) + offset));
    case DV_INT64:
      return (box_num (INT64_REF_NA (text + 1) + offset));

    case DV_SHORT_INT:
      return box_num (((signed char *)text)[1] + offset);
    case DV_IRI_ID:
      return box_iri_id ((unsigned int32)LONG_REF_NA (text + 1) + offset);
    case DV_IRI_ID_8:
      return box_iri_id (INT64_REF_NA (text + 1) + offset);
    case DV_SHORT_STRING_SERIAL:
      {
	unsigned char len = (unsigned char) text[1];
	caddr_t box = dk_alloc_box (len + 1, DV_STRING);
	memcpy (box, text + 2, len);
	box[len - 1] += offset;
	box[len ] = 0;
	return box;
      }
    case DV_RDF_ID:
      return rbb_from_id (LONG_REF_NA (text + 1) + offset);
    case DV_RDF_ID_8:
      return rbb_from_id (INT64_REF_NA (text + 1) + offset);
    case DV_RDF:
      if (!opt_len)
	opt_len = box_length (text);
      if (opt_len > sizeof (dvrdf_temp))
	buf = dk_alloc (opt_len);
      if (offset)
	{
	  memcpy (buf, text, opt_len);
	  buf[opt_len - 1] += offset;
	  text = (char*)buf;
	}
      break;
    }
  memset (&ses, 0, sizeof (ses));
  memset (&iod, 0, sizeof (iod));
  ses.dks_in_buffer = text;
  if (opt_len)
    ses.dks_in_fill = opt_len;
  else
    ses.dks_in_fill = box_length (text);
  SESSION_SCH_DATA ((&ses)) = &iod;

  reg = (caddr_t) read_object (&ses);
  if (buf != (caddr_t) dvrdf_temp)
    dk_free (buf, opt_len);
  return reg;
}


caddr_t
mp_rbb_from_id (mem_pool_t * mp, int64 n)
{
  caddr_t rb = rbb_from_id (n);
  mp_trash (mp, rb);
  return rb;
}


caddr_t
mp_box_deserialize_string (mem_pool_t * mp, caddr_t text, int opt_len, short offset)
{
  dtp_t dvrdf_temp[50];
  scheduler_io_data_t iod;
  caddr_t reg;

  dk_session_t ses;
  /* read_object will not box top level numbers */
  switch ((dtp_t)text[0])
    {
    case DV_LONG_INT:
      return (mp_box_num (mp, LONG_REF_NA (text + 1) + offset));
    case DV_INT64:
      return (mp_box_num (mp, INT64_REF_NA (text + 1) + offset));

    case DV_SHORT_INT:
      return mp_box_num (mp, ((signed char *)text)[1] + offset);
    case DV_IRI_ID:
      return mp_box_iri_id (mp, (unsigned int32)LONG_REF_NA (text + 1) + offset);
    case DV_IRI_ID_8:
      return mp_box_iri_id (mp, INT64_REF_NA (text + 1) + offset);
    case DV_SHORT_STRING_SERIAL:
      {
	unsigned char len = (unsigned char) text[1];
	caddr_t box = mp_alloc_box (mp, len + 1, DV_STRING);
	memcpy (box, text + 2, len);
	box[len - 1] += offset;
	box[len ] = 0;
	return box;
      }
    case DV_RDF_ID:
      return mp_rbb_from_id (mp, LONG_REF_NA (text + 1) + offset);
    case DV_RDF_ID_8:
      return mp_rbb_from_id (mp, INT64_REF_NA (text + 1) + offset);
    case DV_RDF:
      if (!opt_len)
	opt_len = box_length (text);
      if (opt_len > sizeof (dvrdf_temp))
	GPF_T1 ("rdf box serialization too long");
      if (offset)
	{
	  memcpy (dvrdf_temp, text, opt_len);
	  dvrdf_temp[opt_len - 1] += offset;
	  text = (char*)dvrdf_temp;
	}
      break;
    }
  memset (&ses, 0, sizeof (ses));
  memset (&iod, 0, sizeof (iod));
  ses.dks_in_buffer = text;
  if (opt_len)
    ses.dks_in_fill = opt_len;
  else
    ses.dks_in_fill = box_length (text);
  SESSION_SCH_DATA ((&ses)) = &iod;

  reg = (caddr_t) read_object (&ses);
  mp_trash (mp, reg);
  return reg;
}

int in_crash_dump = 0;

void
db_replay_registry_setting (caddr_t ent, caddr_t *err_ret)
{
  if (ent[0] == 'X' && !in_crash_dump)
    {
      caddr_t err = NULL;
      query_t *qr = sql_compile (ent + 1, bootstrap_cli, &err, 0);
      if (qr)
	{
	  err = qr_quick_exec (qr, bootstrap_cli, "", NULL, 0);
	  qr_free (qr);
	}
      if (IS_BOX_POINTER (err))
	{
	  *err_ret = err;
	}
    }
}

void
db_replay_registry_sequences (void)
{
  id_hash_iterator_t hi;
  caddr_t *pkey, *pdata;

  id_hash_iterator (&hi, registry);

  while (hit_next (&hi, (caddr_t *) &pkey, (caddr_t *) &pdata))
    {
      if (pdata && *pdata)
	{
	  caddr_t err = NULL;
	  db_replay_registry_setting (*pdata, &err);
	  if (IS_BOX_POINTER (err))
	    {
	      log_error ("Error reading registry: %s: %s\n%s",
		  ((caddr_t *) err)[QC_ERRNO], ((caddr_t *) err)[QC_ERROR_STRING],
		  *pdata);
	      dk_free_tree (err);
	      err = NULL;
	    }
	}
    }
}


void
dbs_registry_from_array (dbe_storage_t * dbs, caddr_t * reg)
{
  /* the array is either kept or freed here */
  int inx;
  DO_BOX (caddr_t *, ent, inx, reg)
    {
      id_hash_set (dbs->dbs_registry_hash, (caddr_t) & ent[0], (caddr_t) & ent[1]);
      dk_free_box ((caddr_t) ent);
    }
  END_DO_BOX;
  dk_free_box ((caddr_t)reg);
}

void
dbs_init_registry (dbe_storage_t * dbs)
{
  caddr_t *reg;
  dk_session_t *ses = dbs_read_registry (dbs, NULL);
  ENSURE_SEQUENCES;
  ENSURE_REGISTRY;
  if (DBS_PRIMARY == dbs->dbs_type && !dbs->dbs_registry_hash)
    dbs->dbs_registry_hash = registry;
  if (!ses)
    return;

  reg = (caddr_t *) read_object (ses);
  dbs_registry_from_array (dbs, reg);
  if (ses)
    dk_free_box ((box_t) ses);
}

int sql_escaped_string_literal (char *target, char *text, int max);


void
registry_exec ()
{
  id_hash_iterator_t it;
  caddr_t *name;
  caddr_t *value;
  id_hash_iterator (&it, registry);
  while (hit_next (&it, (caddr_t *) & name, (caddr_t *) & value))
    {
      caddr_t str = *value;
      if (str && str[0] == 'X' && str[1] == ' ')
	{
	  caddr_t err;
	  query_t *qr = sql_compile (str + 1, bootstrap_cli, &err, 0);
	  if (qr)
	    {
	      err = qr_quick_exec (qr, bootstrap_cli, "", NULL, 0);
	      qr_free (qr);
	    }
	  if (IS_BOX_POINTER (err))
	    {
	      log_error ("Error reading registry: %s: %s\n%s",
			 ((caddr_t *) err)[QC_ERRNO], ((caddr_t *) err)[QC_ERROR_STRING],
			 str);
	    }
	}
    }
}

void
registry_set_sequence (caddr_t name, boxint value, caddr_t * err_ret)
{
  char temp[2000];
  caddr_t the_id = box_sprintf_escaped (name, 0);
  snprintf (temp, sizeof (temp), "X __sequence_set ('%s', " BOXINT_FMT ", 1)", the_id, value);
  dk_free_box (the_id);
  registry_set_1 (name, temp, 0, err_ret);
}

void
registry_update_sequences (void)
{
  id_hash_iterator_t it;
  caddr_t *name;
  boxint *value;
  if (!sequences)
    return;
  id_hash_iterator (&it, sequences);
  ASSERT_IN_TXN;
  while (hit_next (&it, (caddr_t *) & name, (caddr_t *) & value))
    {
      registry_set_sequence (*name, *value, NULL);
    }
}


caddr_t list (long n,...);


caddr_t *
dbs_registry_to_array (dbe_storage_t * dbs)
{
  dk_set_t ents = NULL;
  id_hash_iterator_t it;
  caddr_t *k, *d;
  id_hash_iterator (&it, dbs->dbs_registry_hash);
  while (hit_next (&it, (caddr_t *) & k, (caddr_t *) & d))
    {
      caddr_t *ent = (caddr_t *) list (2, *k, *d);
      dk_set_push (&ents, (void*)ent);
    }

  return (caddr_t *) list_to_array (dk_set_nreverse (ents));
}


int
dbs_write_registry (dbe_storage_t * dbs)
{
  int rc;
  scheduler_io_data_t iod;
  int inx;
  caddr_t *arr;
  dk_session_t *ses = strses_allocate ();

  registry_update_sequences ();
  arr = dbs_registry_to_array (dbs);
  if (!SESSION_SCH_DATA (ses))
    SESSION_SCH_DATA (ses) = &iod;
  memset (&iod, 0, sizeof (iod));
  CATCH_WRITE_FAIL (ses)
      print_object ((caddr_t) arr, ses, NULL, NULL);
  rc = cpt_write_registry (dbs, ses);
  strses_free (ses);
  DO_BOX (caddr_t, elt, inx, arr)
    {
      dk_free_box (elt);
    }
  END_DO_BOX;
  dk_free_box ((box_t) arr);
  return rc;
}


int
sql_escaped_string_literal (char *target, char *text, int max)
{
  int inx = 0;
  while (*text)
    {
      unsigned char ch = *text;
      if ((ch >= 'A' && ch <= 'Z') ||
	  (ch >= 'a' && ch <= 'z') ||
	  (ch >= '0' && ch <= '9'))
	target[inx++] = ch;
      else
	{
	  target[inx++] = '\\';
	  target[inx++] = '0' + (ch / 64);
	  target[inx++] = '0' + ((ch / 8) & 7);
	  target[inx++] = '0' + (ch & 7);
	}
      text++;
      if (inx > max - 5)
	break;
    }
  target[inx++] = 0;
  return inx - 1;
}

void
log_registry_set (lock_trx_t * lt, char * k, const char * d)
{
  int llen = 0;
  char temp[2000];

  if (!lt || lt->lt_replicate == REPL_NO_LOG || !d || !k || in_log_replay || cl_non_logged_write_mode)
    return;

  ASSERT_IN_TXN;
  if (0 == strncmp (k, "__key__", 7)
    || 0 == strncmp (k, "__EM:__key__", 12) )
    return;
  tailprintf (temp, sizeof (temp), &llen, "registry_set ('%s', '", k);
  llen += sql_escaped_string_literal (&temp[llen], (char *) d, sizeof (temp) - llen);
  if (llen + 3 > sizeof (temp))
    return;
  tailprintf (temp, sizeof (temp), &llen, "')");
  session_buffered_write_char (LOG_TEXT, lt->lt_log);
  session_buffered_write_char (DV_LONG_STRING, lt->lt_log);
  print_long ((long)llen, lt->lt_log);
  session_buffered_write (lt->lt_log, temp, llen);
}

void
db_log_registry (dk_session_t * log)
{
  id_hash_iterator_t it;
  caddr_t *k, *d;

  IN_TXN;
  registry_update_sequences ();
  id_hash_iterator (&it, registry);
  while (hit_next (&it, (caddr_t *) & k, (caddr_t *) & d))
    {
      int llen = 0;
      char temp[2000];
      caddr_t the_id = box_sprintf_escaped (*k, 0);

      if (!*d)
	{
	  dk_free_box (the_id);
	  continue;
	}
      if (0 == strncmp (*k, "__key__", 7)
	  || 0 == strncmp (*k, "__EM:__key__", 12))
	{
	  dk_free_box (the_id);
	  continue;
	}
      tailprintf (temp, sizeof (temp), &llen, "registry_set ('%s', '", the_id);
      dk_free_box (the_id);

      llen += sql_escaped_string_literal (&temp[llen], *d, sizeof (temp) - llen);
      if (llen + 3 > sizeof (temp))
	continue;

      tailprintf (temp, sizeof (temp), &llen, "')");

      session_buffered_write_char (LOG_TEXT, log);
      session_buffered_write_char (DV_LONG_STRING, log);
      print_long ((long)llen, log);
      session_buffered_write (log, temp, llen);
    }
  LEAVE_TXN;
}

#define REGISTRY_SIZE_LIMIT 500000

void
registry_set_1 (const char *name, const char *value, int is_boxed, caddr_t * err_ret)
{
  caddr_t *place;
  ASSERT_IN_TXN;
  ENSURE_REGISTRY;

  if (is_boxed && !DV_STRINGP (value))
    GPF_T1 ("setting non-string in registry");
  place = (caddr_t *) id_hash_get (registry, (caddr_t) & name);
  if (place)
    {
      dk_free_box (*place);
      *place = is_boxed ? box_copy (value) : box_dv_short_string (value);
    }
  else
    {
      caddr_t copy_name, copy_value;

      if (registry->ht_count > REGISTRY_SIZE_LIMIT)
	{
	  if (err_ret)
	    {
	      *err_ret = srv_make_new_error ("42000", "SQ487", "Registry overflow");
	      return;
	    }
	  /* else return; */
	}

      copy_name = box_string (name);
      copy_value = is_boxed ? box_copy (value) : box_dv_short_string (value);
      id_hash_set (registry, (caddr_t) & copy_name, (caddr_t) & copy_value);
    }
}


void
dbs_registry_set (dbe_storage_t * dbs, const char *name, const char *value, int is_boxed)
{
  caddr_t *place;
  ASSERT_IN_TXN;
  if (is_boxed && value && !DV_STRINGP (value))
    GPF_T1 ("setting non-string in registry");
  place = (caddr_t *) id_hash_get (dbs->dbs_registry_hash, (caddr_t) & name);
  if (place)
    {
      dk_free_box (*place);
      if (!value)
	{
	  id_hash_remove (dbs->dbs_registry_hash, (caddr_t)&name);
	  return;
	}
      *place = is_boxed ? box_copy (value) : box_dv_short_string (value);
    }
  else
    {
      caddr_t copy_name;
      caddr_t copy_value;
      if (!value)
	return;
      copy_name = box_string (name);
      copy_value = is_boxed ? box_copy (value) : box_dv_short_string (value);
      id_hash_set (dbs->dbs_registry_hash, (caddr_t) & copy_name, (caddr_t) & copy_value);
    }
}


caddr_t
registry_get (const char *name)
{
  caddr_t *place;
  ASSERT_IN_TXN;
  place = (caddr_t *) id_hash_get (registry, (caddr_t) & name);
  if (place)
    return (box_copy (*place));
  else
    return NULL;
}


boxint
sequence_next_inc_1 (char *name, int in_map, boxint inc_by, caddr_t * err_ret)
{
  boxint  res;
  if (INSIDE_MAP != in_map)
    IN_TXN;
  ENSURE_SEQUENCES;
  {
    boxint *place = (boxint *) id_hash_get (sequences, (caddr_t) & name);
    if (!place)
      {
	caddr_t name_copy = box_string (name);
	boxint init = 1;
	registry_set_sequence (name, init, err_ret);
	id_hash_set (sequences, (caddr_t) & name_copy, (caddr_t) & init);
	res = 0;
      }
    else
      {
	res = (*place);
	(*place) += inc_by;
      }
  }
  if (INSIDE_MAP != in_map)
    LEAVE_TXN;
  return res;
}


caddr_t
registry_remove (char *name)
{
  caddr_t *place;
  ASSERT_IN_TXN;
  place = (caddr_t *) id_hash_get (registry, (caddr_t) & name);
  if (place)
    {
      caddr_t res = *place;
      id_hash_remove (registry, (caddr_t) &name);
      return res;
    }
  else
    return NULL;
}


boxint
sequence_next (char *name, int in_map)
{
  return sequence_next_inc (name, in_map, 1);
}


boxint
sequence_set_1 (char *name, boxint value, int mode, int in_map, caddr_t * err_ret)
{
  boxint res;
  if (INSIDE_MAP != in_map)
  IN_TXN;
  ENSURE_SEQUENCES;
  {
    boxint *place = (boxint *) id_hash_get (sequences, (caddr_t) & name);
    if (!place)
      {
	if (mode == SEQUENCE_GET)
	  res = 0;
	else
	  {
	    caddr_t name_copy = box_string (name);
	    registry_set_sequence (name, value, err_ret);
	    id_hash_set (sequences, (caddr_t) & name_copy, (caddr_t) & value);
	    res = value;
	  }
      }
    else
      {
	if (mode == SEQUENCE_GET)
	  res = *place;
	else if (mode == SET_IF_GREATER)
	  {
	    if (value > *place)
	      *place = value;
	  }
	else
	  *place = value;
	res = *place;
      }
  }
  if (INSIDE_MAP != in_map)
    LEAVE_TXN;
  return res;
}



box_t
registry_get_all ( void )
{
  box_t ret = NULL;
  dk_set_t parts = NULL;
  id_hash_iterator_t it;
  caddr_t *name_copy;
  caddr_t *value_copy;

  id_hash_iterator (&it, (id_hash_t *) registry);
  while (hit_next (&it, (caddr_t *) & name_copy, (caddr_t *) & value_copy))
    {
      dk_set_push (&parts, box_copy (*name_copy));
      dk_set_push (&parts, box_copy (*value_copy));
    }
  ret = list_to_array (dk_set_nreverse (parts));
  return ret;
}


int
sequence_remove (char *name, int in_map)
{
  int res;
  if (INSIDE_MAP != in_map)
  IN_TXN;
  ENSURE_SEQUENCES;

  res = id_hash_remove (sequences, (caddr_t) & name);
  if (res)
    {
      caddr_t data = registry_remove (name);
      if (data)
	dk_free_box (data);
    }
  if (INSIDE_MAP != in_map)
    LEAVE_TXN;
  return res;
}


box_t
sequence_get_all ( void )
{
  box_t ret = NULL;
  dk_set_t parts = NULL;
  id_hash_iterator_t it;
  long **place;
  caddr_t *name_copy;

  id_hash_iterator (&it, (id_hash_t *) sequences);
  while (hit_next (&it, (caddr_t *) & name_copy, (caddr_t *) & place))
    {
      dk_set_push (&parts, box_copy (*name_copy));
      dk_set_push (&parts, box_num ((ptrlong) *place));
    }
  ret = list_to_array (dk_set_nreverse (parts));
  return ret;
}

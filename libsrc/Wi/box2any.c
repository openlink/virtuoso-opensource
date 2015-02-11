/*
 *  box2any.c
 *
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2015 OpenLink Software
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

caddr_t
name (caddr_t data, caddr_t * err_ret, MP_T * ap, int ser_flags)
{
  caddr_t box;
  int init, len;
  dtp_t key_image[PAGE_DATA_SZ];
  dk_session_t sesn, *ses = &sesn;
  scheduler_io_data_t io;
  dtp_t dtp = DV_TYPE_OF (data);

  switch (dtp)
    {
    case DV_IRI_ID:
      {
	iri_id_t id = unbox_iri_id (data);
	if (id < 0xffffffff)
	  {
	    box = ALLOC (6, DV_STRING);
	    box[0] = DV_IRI_ID;
	    LONG_SET_NA (box + 1, id);
	    box[5] = 0;
	    return box;
	  }
	else
	  {
	    box = ALLOC (10, DV_STRING);
	    box[0] = DV_IRI_ID_8;
	    INT64_SET_NA (box + 1, id);
	    box[9] = 0;
	    return box;
	  }
      }
    case DV_LONG_INT:
      {
	boxint n = unbox (data);
	if ((n > -128) && (n < 128))
	  {
	    box = ALLOC (3, DV_STRING);
	    box[0] = DV_SHORT_INT;
	    box[1] = n;
	    box[2] = 0;
	  }
	else if (n >= (int64) INT32_MIN && n <= (int64) INT32_MAX)
	  {
	    int32 ni = n;
	    box = ALLOC (6, DV_STRING);
	    box[0] = DV_LONG_INT;
	    LONG_SET_NA (box + 1, ni);
	    box[5] = 0;
	  }
	else
	  {
	    box = ALLOC (10, DV_STRING);
	    box[0] = DV_INT64;
	    INT64_SET_NA (box + 1, n);
	    box[9] = 0;
	  }

	return box;}
    case DV_SINGLE_FLOAT:
      {
	float f = unbox_float (data);
	box = ALLOC (6, DV_STRING);
	box[0] = DV_SINGLE_FLOAT;
	FLOAT_TO_EXT (box + 1, &f);
	box[5] = 0;
	return box;
      }
    case DV_DOUBLE_FLOAT:
      {
	double f = unbox_double (data);
	box = ALLOC (10, DV_STRING);
	box[0] = DV_DOUBLE_FLOAT;
	DOUBLE_TO_EXT (box + 1, &f);
	box[9] = 0;
	return box;
      }
    case DV_STRING:
      {
	int len = box_length (data);
	if (box_flags (data))
	  goto general;
	if (len > 256)
	  break;
	box = ALLOC (len + 2, DV_STRING);
	box[0] = DV_SHORT_STRING_SERIAL;
	box[1] = len - 1;
	memcpy (box + 2, data, len);
	return box;
      }
    general:
    default:;
    }
  ROW_OUT_SES (sesn, key_image);
  SESSION_SCH_DATA (ses) = &io;
  memset (SESSION_SCH_DATA (ses), 0, sizeof (scheduler_io_data_t));
  sesn.dks_cluster_flags = ser_flags;
  init = sesn.dks_out_fill;

  CATCH_WRITE_FAIL (ses)
  {
    print_object (data, &sesn, NULL, NULL);
  }
  FAILED
  {
      if (DKS_TO_DC & ser_flags)
	return box_to_any_long (data, err_ret, ser_flags);
    *err_ret = srv_make_new_error ("22026", "SR477", "Error serializing the value into an ANY column");
    return NULL;
  }
  END_WRITE_FAIL (ses);

  if (sesn.dks_out_fill > PAGE_DATA_SZ - 10)
    {
      if (DKS_TO_DC & ser_flags)
	return box_to_any_long (data, err_ret, ser_flags);
      box2anyerr ();
      *err_ret = srv_make_new_error ("22026", "SR478", "Value of ANY type column too long");
      return NULL;
    }
  len = sesn.dks_out_fill - init;
  box = ALLOC (len + 1, DV_STRING);
  memcpy (box, &sesn.dks_out_buffer[init], len);
  box[len] = 0;
  return box;
}

#undef name
#undef MP_T
#undef ALLOC

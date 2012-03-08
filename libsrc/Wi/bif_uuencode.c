/*
 *  bif_uuencode.c
 *
 *  $Id$
 *
 *  Build in Functions for UU, XX, Base64, MIME-PlainText and
 *  MIME-QuotedPrintable encodings
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

#include "uuencode_impl.h"
#include "libutil.h"
#include "sqlnode.h"
#include "sqlbif.h"
#include "wi.h"

caddr_t
bif_uuencode (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t input = bif_arg (qst, args, 0, "uuencode");
  long uuenctype = (long) bif_long_arg (qst, args, 1, "uuencode");
  long maxlinespersection = (long) bif_long_arg (qst, args, 2, "uuencode");
  dtp_t input_dtp = DV_TYPE_OF (input);
  caddr_t res = NULL;
  switch (input_dtp)
    {
    case DV_BLOB_HANDLE:
      {
	input = blob_to_string (((query_instance_t *) qst)->qi_trx, input);
	qst_set (qst, args[0], input);
	input_dtp = DV_TYPE_OF (input);
	break;
      }
    case DV_STRING:
    case DV_STRING_SESSION:
      break;
    default:
      sqlr_new_error ("22023", "UUE01",
	"Function uuencode needs a string output or a string as argument 1, not an arg of type %s (%d)",
	dv_type_title (input_dtp), input_dtp);
    }
  switch (uuenctype)
    {
      case UUENCTYPE_NATIVE:
      case UUENCTYPE_XX:
      case UUENCTYPE_BASE64_UNIX:
      case UUENCTYPE_BASE64_WIDE:
      case UUENCTYPE_BINHEX:
      case UUENCTYPE_PLAINTEXT:
      case UUENCTYPE_MIME_QP_TXT:
      case UUENCTYPE_MIME_QP_BIN:
	break;
      default:
	sqlr_new_error ("22003", "UUE02", "Unsupported type of UU-encoding (%ld)", uuenctype);
    }
  if (DV_STRING_SESSION == input_dtp)
    {
      int failed = 0;
      IO_SECT (qst);
      CATCH_READ_FAIL ((dk_session_t *)input)
        {
          uu_encode_string_session (&res, (dk_session_t *)input, uuenctype, maxlinespersection);
        }
      FAILED
	{
	  failed = 1;
	}
      END_READ_FAIL ((dk_session_t *)input)
      END_IO_SECT (err_ret);
      if (failed)
        {
          dk_free_tree (res);
          sqlr_new_error ("22003", "UUE10", "Error reading source data of UU-encoding (%ld)", uuenctype);
        }
    }
  else
    uu_encode_string (&res, input, uuenctype, maxlinespersection);
  return res;
}


caddr_t
bif_uuvalidate (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t string = bif_string_arg (qst, args, 0, "uuvalidate");
  long uuenctype = ((BOX_ELEMENTS(args) > 1) ? (long) bif_long_arg (qst, args, 1, "uuvalidate") : 0);
  int bhflag = ((BOX_ELEMENTS(args) > 2) ? (int) bif_long_arg (qst, args, 2, "uuvalidate") : 0);
  int bug_count = 0;
  int res;
  switch (uuenctype)
    {
      case UUENCTYPE_UNKNOWN:
      case UUENCTYPE_NATIVE:
      case UUENCTYPE_XX:
      case UUENCTYPE_BASE64_UNIX:
      case UUENCTYPE_BASE64_WIDE:
      case UUENCTYPE_BINHEX:
	break;
      default:
	sqlr_new_error ("22003", "UUV01", "Unsupported type of UU-encoding (%ld)", uuenctype);
    }
  res = uu_validate_encoding ((unsigned char *)string, uuenctype, &bhflag, &bug_count);
  return box_num (res);
}

caddr_t
bif_uudecode (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t string = bif_string_arg (qst, args, 0, "uudecode");
  long uuenctype = (long) bif_long_arg (qst, args, 1, "uudecode");
  caddr_t boundary = ((BOX_ELEMENTS(args) > 2) ? bif_string_arg (qst, args, 2, "uudecode") : NULL);
  caddr_t input, out = NULL;
  uu_ctx_t ctx;
  switch (uuenctype)
    {
      case UUENCTYPE_UNKNOWN:
      case UUENCTYPE_NATIVE:
      case UUENCTYPE_XX:
      case UUENCTYPE_BASE64_UNIX:
      case UUENCTYPE_BASE64_WIDE:
      case UUENCTYPE_BINHEX:
      case UUENCTYPE_PLAINTEXT:
      case UUENCTYPE_MIME_QP_TXT:
      case UUENCTYPE_MIME_QP_BIN:
	break;
      default:
	sqlr_new_error ("22003", "UUD01", "Unsupported type of UU-encoding (%ld)", uuenctype);
    }
  memset (&ctx, 0, sizeof (uu_ctx_t));
  ctx.uuc_boundary = boundary;
  ctx.uuc_boundary_status = -1;
  ctx.uuc_enctype = uuenctype;
  ctx.uuc_state = UUSTATE_BEGIN;
  input = box_copy (string);
  uu_decode_part (&ctx, &out, input);
  dk_free_box (input);
  if ((NULL == out) || (NULL != ctx.uuc_errmsg))
    {
      dk_free_box (out);
      if (NULL == ctx.uuc_errmsg)
	ctx.uuc_errmsg = "generic syntax error";
      sqlr_new_error ("22003", "UUD02", "Data string contains errors [%s]", ctx.uuc_errmsg);
    }
  if (0 != ctx.uuc_trail_len)
    {
      dk_free_box (out);
      sqlr_new_error ("22003", "UUD03", "Encoded data ended prematurely");
    }
  if (UUSTATE_BEGIN == ctx.uuc_state)
    {
      dk_free_box (out);
      sqlr_new_error ("22003", "UUD04", "No data found to be decoded");
    }
  return out;
}

int bif_uuencode_init(void)
{
  uu_initialize_tables();
  bif_define ("uuencode", bif_uuencode);
  bif_define ("uuvalidate", bif_uuvalidate);
  bif_define ("uudecode", bif_uudecode);
  return 0;
}


/*
 *  $Id$
 *
 *  Cluster server side operations
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

#include "sqlnode.h"
#include "log.h"
#include "security.h"


#define LT_ID_ARG(x) QFID_HOST (x), (uint32)x

int32
strses_out_bytes (dk_session_t * ses)
{
  return ses->dks_out_fill + ses->dks_bytes_sent;
}


query_t *
cl_ins_del_qr (dbe_key_t * key, int op, int ins_mode, caddr_t * err_ret)
{
  query_t **qrp, *qr;
  if (INS_SOFT_QUIET == ins_mode)
    ins_mode = INS_SOFT;
  qrp = CLO_INSERT == op ? (INS_SOFT == ins_mode ? &key->key_ins_soft_qr : &key->key_ins_qr) : &key->key_del_qr;
  qr = *qrp;
  if (qr && !qr->qr_to_recompile)
    return qr;
  return *qrp = log_key_ins_del_qr (key, err_ret, CLO_INSERT == op ? LOG_KEY_INSERT : LOG_KEY_DELETE, ins_mode, 0);
}


void
cls_vec_del_rd_layout (row_delta_t * rd)
{
  caddr_t tmp[16];
  dbe_key_t *key = rd->rd_key;
  int inx;
  for (inx = 0; inx < key->key_n_significant; inx++)
    tmp[key->key_part_in_layout_order[inx]] = rd->rd_values[inx];
  memcpy (rd->rd_values, tmp, sizeof (caddr_t) * key->key_n_significant);
}

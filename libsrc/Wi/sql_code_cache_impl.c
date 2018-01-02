/*
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

#include "sqlnode.h"
#include "sqlfn.h"

#define CACHE_RESOURCE virt_bootstrap_cache_resource

void virt_bootstrap_cache_resource (const char **src_text, const char *uri, const char *pubid, const char *dat, const char *comment)
{
  static char * cres_load_qr_text = "DB.DBA.SYS_CACHED_RESOURCE_ADD (?, ?, ?, cast (? as datetime), ?)";
  static query_t *cres_load_qr;
  caddr_t text;
  char *tgt_text_tail;
  const char **src_text_tail;
  int tgt_text_len = 0;
  for (src_text_tail = src_text; NULL != src_text_tail[0]; src_text_tail++)
    tgt_text_len += (int) strlen (src_text_tail[0]);
  tgt_text_tail = text = dk_alloc_box (tgt_text_len + 1, DV_STRING);
  for (src_text_tail = src_text; NULL != src_text_tail[0]; src_text_tail++)
    {
      const char *line_tail = src_text_tail[0];
      while ('\0' != line_tail[0])
        (tgt_text_tail++)[0] = (line_tail++)[0];
    }
  tgt_text_tail[0] = '\0';
#ifdef DEBUG
  if (tgt_text_tail != text + tgt_text_len)
    GPF_T;
#endif
    if (NULL == cres_load_qr)
      cres_load_qr = sql_compile (cres_load_qr_text, bootstrap_cli, NULL, SQLC_DEFAULT);
    if (NULL == cres_load_qr)
      log_error ("Error in a server init statement %s", cres_load_qr_text);
    else
      {
        caddr_t err = NULL;
        err = qr_quick_exec (cres_load_qr, bootstrap_cli, NULL, NULL, 5,
          ":0", uri, QRP_STR,
	  ":1", pubid, QRP_STR,
	  ":2", text, QRP_STR,
	  ":3", dat, QRP_STR,
	  ":4", comment, QRP_STR );
        if (err) {
          log_error ("Error loading cached resource '%s': %s: %s in %s",
	  uri,
          ((caddr_t *) err)[QC_ERRNO], ((caddr_t *) err)[QC_ERROR_STRING],
                      cres_load_qr_text);
          dk_free_tree (err);
	    }
	  local_commit (bootstrap_cli);
      }
    dk_free_box (text);
  }

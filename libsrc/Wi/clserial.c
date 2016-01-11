/*
 *  clserial.c
 *
 *  $Id$
 *
 *  Cluster serialization/deserialization subquery
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2016 OpenLink Software
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
#include "sqlpar.h"
#include "sqlcmps.h"
#include "sqlintrp.h"
#include "sqlbif.h"
#include "sqlo.h"
#include "rdfinf.h"
#include "xmlnode.h"
#include "remote.h"



int
rd_is_blob (row_delta_t * rd, int nth)
{
  dbe_key_t * key = rd->rd_key;
  if (key->key_table && !key->key_table->tb_any_blobs)
    return 0;
  else
    {
      DO_CL (cl, key->key_row_var)
	{
	  if (nth < cl->cl_nth)
	    return 0;
	  if (cl->cl_nth == nth && IS_BLOB_DTP (cl->cl_sqt.sqt_dtp))
	    return 1;
	}
      END_DO_CL;
    }
  return 0;
}


dbe_col_loc_t *
key_nth_cl (dbe_key_t * key, int nth)
{
  DO_CL (cl, key->key_row_var)
    {
      if (cl->cl_nth == nth)
	return cl;
    }
  END_DO_CL;
  return NULL;
}

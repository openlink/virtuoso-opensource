/*
 *  cldfg.c
 *
 *  $Id$
 *
 *  Cluster non-colocated query frag
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2017 OpenLink Software
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
#include "sqlbif.h"
#include "arith.h"

#include "eqlcomp.h"
#include "sqlfn.h"
#include "sqlpar.h"
#include "sqlpfn.h"
#include "sqlcmps.h"
#include "sqlintrp.h"
#include "sqlo.h"
#include "rdfinf.h"
#include "aqueue.h"

#define in_printf(q)
#if 1
int enable_dfg_print = 0;
int enable_rec_dfg_print = 0;
#define dfg_printf(q) {if (enable_dfg_print) printf q; }
#else
#define dfg_printf(q)
#endif



extern long tc_dfg_coord_pause;
extern long tc_dfg_more;



void
stage_node_input (stage_node_t * stn, caddr_t * inst, caddr_t * state)
{
  NO_CL;
}

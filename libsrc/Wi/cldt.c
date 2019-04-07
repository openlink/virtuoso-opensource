/*
 *  cldt.c
 *
 *  $Id$
 *
 *  Cluster parallel multiple set derived tables, subquery, existence,
 *  aggregates
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2019 OpenLink Software
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


void
cl_set_aggregate_set (caddr_t * inst, state_slot_t * set_ctr, state_slot_t * current_set, state_slot_t * arr, state_slot_t ** save,
    int n_save)
{
}






int
qr_is_continuable (query_t * qr, caddr_t * inst)
{
  DO_SET (data_source_t *, qn, &qr->qr_nodes)
  {
    if (SRC_IN_STATE (qn, inst))
      return 1;
  }
  END_DO_SET ();
  return 0;
}


void
code_node_input (code_node_t * cn, caddr_t * inst, caddr_t * state)
{
  QNCAST (query_instance_t, qi, inst);
  int n_sets;
  QN_N_SETS (cn, inst);
  QN_CHECK_SETS (cn, inst, qi->qi_n_sets);
  n_sets = qi->qi_n_sets;
  qi->qi_set_mask = NULL;
  if (cn->cn_is_test)
    {
      QST_INT (inst, cn->src_gen.src_out_fill) = 0;
      code_vec_run_v (cn->cn_code, inst, 0, -1, qi->qi_n_sets, NULL, QST_BOX (int *, inst, cn->src_gen.src_sets),
	  cn->src_gen.src_out_fill);
      qi->qi_set_mask = NULL;
      if (!QST_INT (inst, cn->src_gen.src_out_fill))
      return;
    }
		else
		  {
      int inx;
      int *sets = QST_BOX (int *, inst, cn->src_gen.src_sets);
      for (inx = 0; inx < n_sets; inx++)
	sets[inx] = inx;
      QST_INT (inst, cn->src_gen.src_out_fill) = n_sets;
      code_vec_run_v (cn->cn_code, inst, 0, -1, QST_INT (inst, cn->src_gen.src_out_fill), NULL, NULL, 0);
}
  qi->qi_set_mask = NULL;
	qn_send_output ((data_source_t *) cn, inst);
      return;
    }


void
cn_free (code_node_t * cn)
{
  clb_free (&cn->clb);
  if (cn->cn_assigned)
    dk_free_box ((caddr_t) cn->cn_assigned);
  dk_set_free (cn->cn_continuable);
  cv_free (cn->cn_code);
}



void
cl_fref_resume (fun_ref_node_t * fref, caddr_t * inst)
{
  /* continue the fnr_select branch so it is all finished */
again:
  DO_SET (data_source_t *, qn, &fref->fnr_select_nodes)
  {
    if (SRC_IN_STATE (qn, inst))
      {
	qn->src_input (qn, inst, NULL);
	goto again;
      }
  }
  END_DO_SET ();
  /* this does not mark the containing qr's run as over since there can be results in nodes that read the aggregation */
}






void
cl_fref_read_input (cl_fref_read_node_t * clf, caddr_t * inst, caddr_t * state)
{
  NO_CL;
    }

void
ssa_iter_input (ssa_iter_node_t * ssi, caddr_t * inst, caddr_t * state)
  {
  NO_CL;
}

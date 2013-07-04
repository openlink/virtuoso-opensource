/*
 *  sqloprt.c
 *
 *  $Id$
 *
 *  sql opt intermediate diag
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
#include "sqlpar.h"
#include "sqlpfn.h"
#include "sqlcmps.h"
#include "sqlintrp.h"
#include "sqlbif.h"
#include "arith.h"
#include "security.h"
#include "sqlo.h"
#include "list2.h"





void
sqlo_dfe_list_print (dk_set_t list, int offset)
{
  DO_SET (df_elt_t *, elt, &list)
    {
      sqlo_dfe_print (elt, offset);
    }
  END_DO_SET();
}

void
sqlo_index_path_print (df_elt_t * dfe)
{
  DO_SET (index_choice_t *, ic, &dfe->_.table.index_path)
    {
      if (ic->ic_key)
	{
	  if (ic->ic_text_order)
	    printf ("by_text ");
	  printf ("key %s %9.2g %9.2g ", ic->ic_key->key_name, ic->ic_unit, ic->ic_arity);
	}
      if (ic->ic_inx_op)
	{
	DO_SET (df_inx_op_t *, dio, &ic->ic_inx_op->dio_terms) printf ("%s ", dio->dio_key->key_name);
	  END_DO_SET();
	}
    }
  END_DO_SET();
  printf ("\n");
}


caddr_t dv_iri_short_name (caddr_t x);

void
dbg_print_st (caddr_t * box, FILE * f)
{
  ST * st = (ST*)box;
  dtp_t dtp = DV_TYPE_OF (box);
  if (DV_IRI_ID == dtp)
    {
      caddr_t n = dv_iri_short_name (box);
      sqlo_print (("#%s ", n ? n :  "unnamed"));
      dk_free_box (n);
      return;
    }
  if (ST_P (st, COL_DOTTED))
    sqlo_print (("%s.%s ", st->_.col_ref.prefix, st->_.col_ref.name));
  else if (ST_P (st, CALL_STMT))
    {
      dbg_print_box (st->_.call.name, f);
      dbg_print_box ((caddr_t) st->_.call.params, f);
    }
  else
    dbg_print_box ((caddr_t) box, f);
}


void
sqlo_dfe_print (df_elt_t * dfe, int offset)
{
  int is_rec = offset == -1;
  if (offset < 0)
    offset = 8;
  sqlo_print (("%*.*s", offset, offset, " "));
  if (!IS_BOX_POINTER (dfe))
    {
      sqlo_print (("#%ld", (long) (ptrlong) dfe));
      switch ((ptrlong)dfe)
	{
	case BOP_NOT:
	    sqlo_print ((" (not)"));
	  break;
	case BOP_OR:
	    sqlo_print ((" (or)"));
	  break;
	case BOP_AND:
	    sqlo_print ((" (and)"));
	  break;
	case DFE_PRED_BODY:
	    sqlo_print ((" (pred body)"));
	  break;
	}
      return;
    }
  if (DV_ARRAY_OF_POINTER == DV_TYPE_OF (dfe))
    {
      int inx;
      df_elt_t ** dfe_arr = (df_elt_t **) dfe;
      sqlo_print (("{\n"));
      DO_BOX (df_elt_t *, elt, inx, dfe_arr)
	{
	  sqlo_dfe_print (elt, offset + OFS_INCR);
	}
      END_DO_BOX;
      sqlo_print (("%*.*s", offset, offset, " "));
      sqlo_print (("}\n"));
      return;
    }
  if (dfe->dfe_locus && LOC_LOCAL != dfe->dfe_locus)
    {
      sqlo_print (("  %s: ", dfe->dfe_locus->loc_name));
      offset += (int) (4 + strlen (dfe->dfe_locus->loc_name));
    }
  switch (dfe->dfe_type)
    {
    case DFE_COLUMN:
      sqlo_print (("   out col"));
      dbg_print_box ((caddr_t) dfe->dfe_tree, stdout);
      sqlo_print (("\n"));
      break;
    case DFE_CONST:
      sqlo_print (("   const ("));
      dbg_print_box ((caddr_t) dfe->dfe_tree, stdout);
      sqlo_print ((")\n"));
      break;

    case DFE_HEAD:
      sqlo_print (("   HEAD\n"));
      break;

    case DFE_FUN_REF:
      if (AMMSC_USER == dfe->dfe_tree->_.fn_ref.fn_code)
	{
	  int argctr;
	  user_aggregate_t * ua = (user_aggregate_t *)unbox_ptrlong(dfe->dfe_tree->_.fn_ref.user_aggr_addr);
	  sqlo_print (("   AGGREGATE %s (", ua->ua_name));
	  DO_BOX_FAST (ST *, arg, argctr, dfe->dfe_tree->_.fn_ref.fn_arglist)
	    {
	      if (argctr)
		sqlo_print ((", "));
	      dbg_print_box ((caddr_t) arg, stdout);
	    }
	  END_DO_BOX_FAST;
	}
      else
	{
	  sqlo_print (("   %s (", ammsc_name ((int) dfe->dfe_tree->_.fn_ref.fn_code)));
	  dbg_print_box ((caddr_t) dfe->dfe_tree->_.fn_ref.fn_arg, stdout);
	}
      sqlo_print ((")\n"));
      break;

    case DFE_BOP_PRED:
      sqlo_print (("pred "));

    case DFE_BOP:
      {
	if (ST_P (dfe->dfe_tree, KWD_PARAM))
	  {
	    dbg_print_st ((caddr_t *) dfe->dfe_tree->_.bin_exp.left, stdout);
	    sqlo_print (("=> "));
	    dbg_print_st ((caddr_t *) dfe->dfe_tree->_.bin_exp.right, stdout);
	  }
	else if (ST_P (dfe->dfe_tree, ASG_STMT))
	  {
	    dbg_print_st ((caddr_t *) dfe->_.bin.left->dfe_tree, stdout);
	    sqlo_print ((":= "));
	    dbg_print_st ((caddr_t *) dfe->_.bin.right->dfe_tree, stdout);
	  }
	else
	  {
	    sqlo_print ((" "));
	    if (!dfe->_.bin.right)
	      sqlo_print ((" %s ", bop_text (dfe->_.bin.op)));
	    dbg_print_st ((caddr_t *) dfe->_.bin.left->dfe_tree, stdout);
	    if (dfe->_.bin.right)
	      {
		sqlo_print ((" %s ", bop_text (dfe->_.bin.op)));
		dbg_print_st ((caddr_t *) dfe->_.bin.right->dfe_tree, stdout);
	      }
	  }
	sqlo_print (("\n"));
	break;
      }
    case DFE_TEXT_PRED:
      sqlo_print (("text pred ("));
      dbg_print_box ((caddr_t) dfe->_.text.args, stdout);
      sqlo_print ((")\n%*.*safter_test\n", offset + OFS_INCR, offset + OFS_INCR, " "));
      sqlo_dfe_print ((df_elt_t *) dfe->_.text.after_test, offset + OFS_INCR);
      break;

    case DFE_TABLE:
      {
	char spacing[40];
	spacing[0] = 0;
	if (dfe->_.table.hit_spacing)
	  snprintf (spacing, sizeof (spacing), "%s spacing %9.2g", dfe->_.table.in_order ? "in order" : "", dfe->_.table.hit_spacing);
	sqlo_print ((" key %s (%s %s) %s %s",
		     dfe->_.table.key ? dfe->_.table.key->key_name : "no key",
		     dfe->_.table.ot->ot_prefix ? dfe->_.table.ot->ot_prefix : "",
		     dfe->_.table.ot->ot_new_prefix,
		     dfe->_.table.hash_role == HR_FILL ? " hash filler " : dfe->_.table.hash_role == HR_REF ? "hash join" : "",
		     dfe->_.table.is_cl_part_first ? "cl new partition" : ""));
	if (compiler_unit_msecs)
	  sqlo_print (("  Reached %9.2g unit %9.2g (%g msecs) arity %9.2g %s\n",
		(double) dfe->_.table.in_arity, (double) dfe->dfe_unit,
		(double) dfe->dfe_unit * dfe->_.table.in_arity * compiler_unit_msecs,
		       (double) dfe->dfe_arity, spacing));
	else
	  sqlo_print (("  Reached %9.2g unit %9.2g arity %9.2g %s\n",
		(double) dfe->_.table.in_arity, (double) dfe->dfe_unit,
		       (double) dfe->dfe_arity, spacing));
	sqlo_print (("  col preds: "));
	if (dfe->_.table.index_path)
	  sqlo_index_path_print (dfe);
	if (dfe->_.table.col_preds)
	  sqlo_print (("\n"));
	sqlo_dfe_list_print (dfe->_.table.col_preds, offset + OFS_INCR);
	if (dfe->_.table.col_pred_merges)
	  {
	    sqlo_print (("%*.*s", offset, offset, " "));
	    sqlo_print (("  col pred merge pre-code:\n"));
	    DO_SET (df_elt_t *, mrg, &dfe->_.table.col_pred_merges)
	      {
		sqlo_dfe_print (mrg, offset + OFS_INCR);
	      }
	    END_DO_SET();
	    sqlo_print (("\n"));
	    sqlo_print (("%*.*s", offset, offset, " "));
	  }
	if (dfe->_.table.col_preds)
	  sqlo_print (("%*.*s", offset, offset, " "));
	if (dfe->_.table.inx_op && !is_rec)
	  {
	    sqlo_print (("Index AND:\n{\n"));
	    DO_SET (df_inx_op_t *, term, &dfe->_.table.inx_op->dio_terms)
	      {
		sqlo_dfe_print (term->dio_table, -1);
		sqlo_print (("\n"));
	      }
	    END_DO_SET();
	    sqlo_print (("\n}"));
	  }
	if (dfe->_.table.out_cols)
	  {
	    sqlo_print (("  out cols: "));
	    DO_SET (df_elt_t *, col_dfe, &dfe->_.table.out_cols)
	      {
		if (col_dfe->_.col.col == (dbe_column_t *) CI_ROW)
		  sqlo_print ((" _ROW "));
		else if (col_dfe->_.col.col)
		  sqlo_print ((" %s ", col_dfe->_.col.col->col_name));
		else
		  {
		    sqlo_print ((" "));
		    dbg_print_box ((caddr_t) col_dfe->dfe_tree, stdout);
		    sqlo_print ((" "));
		  }
	      }
	    END_DO_SET();
	    sqlo_print (("\n"));
	    sqlo_print (("%*.*s", offset, offset, " "));
	  }
	if (dfe->_.table.join_test)
	  {
	    sqlo_print (("  join test:\n"));
	    sqlo_dfe_print ((df_elt_t *) dfe->_.table.join_test, offset + OFS_INCR);
	  }
	if (dfe->_.table.vdb_join_test)
	  {
	    sqlo_print (("  vdb join test:\n"));
	    sqlo_dfe_print ((df_elt_t *) dfe->_.table.vdb_join_test, offset + OFS_INCR);
	  }
	if (dfe->_.table.after_join_test)
	  {
	    sqlo_print (("  after join test:\n"));
	    sqlo_dfe_print ((df_elt_t *) dfe->_.table.after_join_test, offset + OFS_INCR);
	  }

	if (dfe->_.table.hash_filler)
	  {
	    df_elt_t * filler = dfe->_.table.hash_filler;
	    sqlo_print (("  hash filler dfe build time %g ms:\n", sqlo_hash_ins_cost (dfe, filler->dfe_arity, dfe->_.table.out_cols) * compiler_unit_msecs));
	    sqlo_dfe_print (filler, offset + OFS_INCR);
	  }

	if (dfe->_.table.hash_filler_after_code)
	  {
	    sqlo_print (("  hash filler after code :\n"));
	    sqlo_dfe_print ((df_elt_t *) dfe->_.table.hash_filler_after_code, offset + OFS_INCR);
	  }

	if (dfe->_.table.text_pred)
	  {
	    sqlo_print (("  text pred :\n"));
	    sqlo_dfe_print ((df_elt_t *) dfe->_.table.text_pred, offset + OFS_INCR);
	  }

	if (dfe->_.table.xpath_pred)
	  {
	    sqlo_print (("  xpath pred :\n"));
	    sqlo_dfe_print ((df_elt_t *) dfe->_.table.xpath_pred, offset + OFS_INCR);
	  }

	break;
      }
    case DFE_EXISTS:
    case DFE_DT:
    case DFE_VALUE_SUBQ:
    case DFE_PRED_BODY:
      {
	df_elt_t * elt;
	sqlo_print (("{"));
	sqlo_print (("%*.*s", offset, offset, " "));
	if (dfe->dfe_type == DFE_VALUE_SUBQ)
	  sqlo_print ((" scalar subq  "));
	else if (dfe->dfe_type == DFE_EXISTS)
	  sqlo_print ((" exists subq  "));
	if (dfe->_.sub.ot)
	  {
	    int inx;
	    sqlo_print (("  %s dt %s\n", dfe->_.sub.is_contradiction ? "CONTR" : "", dfe->_.sub.ot->ot_new_prefix));
	    if (compiler_unit_msecs)
	      sqlo_print (("  unit %9.2g (%g msecs) arity %9.2g reached %7.2g \n",
		    (double) dfe->dfe_unit, (double) dfe->dfe_unit * compiler_unit_msecs,
		    (double) dfe->dfe_arity, dfe->_.sub.in_arity));
	    else
	      sqlo_print (("  unit %9.2g arity %9.2g reached %7.2g \n",
		    (double) dfe->dfe_unit, (double) dfe->dfe_arity, dfe->_.sub.in_arity));
	    sqlo_print (("%*.*sOut cols :\n", offset, offset, " "));
	    DO_BOX (df_elt_t *, out, inx, dfe->_.sub.dt_out)
	      {
		sqlo_dfe_print (out, offset + OFS_INCR);
	      }
	    END_DO_BOX;
	  }
	if (dfe->_.sub.generated_dfe)
	  {
	    sqlo_print (("%*.*s", offset, offset, " "));
	    sqlo_print (("   dt generated as:\n"));
	    sqlo_dfe_print (dfe->_.sub.generated_dfe, offset + OFS_INCR);
	  }
	if (DFE_DT == dfe->dfe_type && dfe->_.sub.trans)
	  sqlo_print (("  dt transitive\n"));
	if (!dfe->_.sub.first)
	  sqlo_print (("empty dt"));
	else
	  {
	  for (elt = dfe->_.sub.first->dfe_next; elt; elt = elt->dfe_next)
	    {
	      sqlo_dfe_print (elt, offset + OFS_INCR);
	      sqlo_print (("\n"));
	    }
	  }
	sqlo_print (("%*.*s", offset, offset, " "));
	sqlo_print (("}\n"));
	if (dfe->_.sub.after_join_test)
	  {
	    sqlo_print (("%*.*s", offset, offset, " "));
	    sqlo_print (("  dt after join test:\n"));
	    sqlo_dfe_print ((df_elt_t *) dfe->_.sub.after_join_test, offset + OFS_INCR);
	  }
	if (DFE_DT == dfe->dfe_type && dfe->_.sub.trans && dfe->_.sub.trans->tl_complement)
	  {
	    sqlo_print ((" \nTransitive e from both ends, complement dt:\n"));
	    sqlo_dfe_print (dfe->_.sub.trans->tl_complement, offset);
	  }
	break;
      }
    case DFE_CALL:
      if (dfe->dfe_tree && DV_STRINGP (dfe->dfe_tree->_.call.name))
	sqlo_print (("call %s: ", dfe->dfe_tree->_.call.name));
      else
	sqlo_print (("call %s ...", dfe->_.call.func_name ? dfe->_.call.func_name : ""));
      dbg_print_box ((caddr_t) dfe->dfe_tree, stdout);
      sqlo_print (("\n"));
      break;

    case DFE_CONTROL_EXP:
      sqlo_print (("control_exp "));
      dbg_print_box ((caddr_t) dfe->dfe_tree, stdout);
      sqlo_print (("\n"));
      sqlo_dfe_print ((df_elt_t *) dfe->_.control.terms, offset + OFS_INCR);
      sqlo_print (("\n"));
      break;
    case DFE_QEXP:
      {
	int inx;
	sqlo_print (("{ set op %d\n", dfe->_.qexp.op));
	DO_BOX (df_elt_t *, elt, inx, dfe->_.qexp.terms)
	  {
	    sqlo_dfe_print (elt, offset + OFS_INCR);
	  }
	END_DO_BOX;
	sqlo_print (("%*.*s", offset, offset, " "));
	sqlo_print (("}\n"));
	break;
      }
    case DFE_ORDER:
    case DFE_GROUP:
      sqlo_print (("  %s unit %g card %g", dfe->dfe_type == DFE_ORDER ? "order by" : "group by", dfe->dfe_unit, dfe->dfe_arity));
      if (dfe->_.setp.is_linear)
	sqlo_print ((" linear "));
      dbg_print_box ((caddr_t) dfe->_.setp.specs, stdout);
      if (dfe->_.setp.oby_dep_cols)
	{
	  int inx;
	  printf ("oby dep:\n");
	  DO_BOX (dk_set_t, deps, inx, dfe->_.setp.oby_dep_cols)
	    {
	      DO_SET (df_elt_t *, dfe, &deps)
		{
		  sqlo_dfe_print (dfe, 0);
		}
	      END_DO_SET();
	    }
	  END_DO_BOX;
	}
      if (dfe->_.setp.after_test)
	{
	  sqlo_print (("after test: "));
	  sqlo_dfe_print ((df_elt_t *) dfe->_.setp.after_test, offset + OFS_INCR);
	}
      sqlo_print (("\n"));
      break;
    default:
      sqlo_print (("node\n"));
      break;
    }
}


#define OT_NAME(ot) ot->ot_new_prefix



char *
rq_inx_abbrev (df_elt_t * elt)
{
  dbe_key_t * key = elt->_.table.key;
  if (key->key_is_primary)
    return "so";
  if (key->key_n_significant == 4)
    return "os";
  return key->key_name;
}


void
rq_print_ps (dk_set_t * preds)
{
  DO_SET (df_elt_t *, pred, preds)
    {
    if (PRED_IS_EQ (pred) && DFE_COLUMN == pred->_.bin.left->dfe_type && pred->_.bin.left->_.col.col
	&& 'P' == toupper (pred->_.bin.left->_.col.col->col_name[0]))
	sqlo_dfe_print (pred, 0);
    }
  END_DO_SET();
}


void
sqlo_next_print (dk_set_t * arr)
{
  /* print the array of next steps in sqlo_layout_sort_tables */
  int inx;
  DO_BOX (dk_set_t, dfes, inx, arr)
    {
      df_elt_t * dfe = (df_elt_t*)dfes->data;
      sqlo_print ((" score %9.2g %s ", dfe->dfe_unit, DFE_TABLE == dfe->dfe_type && dfe->_.table.is_leaf ? "leaf" : ""));
    DO_SET (df_elt_t *, elt, &dfes) sqlo_print ((" %s ", elt->_.table.ot->ot_new_prefix));
      END_DO_SET();
    }
  END_DO_BOX;
  sqlo_print (("\n"));
}


void
sqlo_scenario_summary (df_elt_t * dfe, float cost)
{
  df_elt_t * elt;
  int is_rq;
  if (compiler_unit_msecs)
    sqlo_print (("sequence for %s cost %9.2g (%g msec):", dfe->_.sub.ot->ot_new_prefix, cost, cost * compiler_unit_msecs));
  else
    sqlo_print (("sequence for %s cost %9.2g:", dfe->_.sub.ot->ot_new_prefix, cost));
  for (elt = dfe->_.sub.first->dfe_next; elt; elt = elt->dfe_next)
    {
      int elt_printed = 1;
      switch (elt->dfe_type)
	{
	case DFE_TABLE:
	  is_rq = dfe_is_quad (elt);
	    if (elt->_.table.hash_role == HR_FILL)
	      {
		sqlo_print (("(%s filler) ", elt->_.table.ot->ot_new_prefix));
	      }
	    else
	      {
		sqlo_print (("%s as %s ", is_rq ? "rq" : elt->_.table.ot->ot_table->tb_name_only, elt->_.table.ot->ot_new_prefix));
		if (elt->_.table.inx_op)
		  {
		    sqlo_print ((" inx and ( "));
		    DO_SET (df_inx_op_t *, dio, &elt->_.table. inx_op->dio_terms)
		      {
			sqlo_print ((" %s on %s, ", OT_NAME (dio->dio_table->_.table.ot), dio->dio_key->key_name));
		      }
		    END_DO_SET();
		    sqlo_print ((" ) "));
		  }
		else if (HR_REF == elt->_.table.hash_role)
		  {
		    df_elt_t * filler = elt->_.table.hash_filler;
		    sqlo_print ((" hash ref "));
		    if (DFE_DT == filler->dfe_type)
		      {
			sqlo_print (("build ("));
			sqlo_scenario_summary (filler, filler->dfe_unit);
			sqlo_print ((")"));
		      }
		  }
		else
		  {
		    if (is_rq)
		      sqlo_print ((" %s ", rq_inx_abbrev (elt)));
		    else
		    sqlo_print ((" on %s ", elt->_.table.key->key_name ? elt->_.table.key->key_name : "no inx"));
		  }
		if (is_rq)
		  printf ("%s", dfe_p_const_abbrev (elt));
		if (elt->_.table.is_oby_order && elt->_.table.ot->ot_order_cols)
		  sqlo_print (("(index_oby %s %s) ",
			elt->_.table.key->key_name, elt->_.table.ot->ot_order_dir == ORDER_DESC ? "DESC" : "ASC"));
	      }
	  break;
	case DFE_DT:
	  sqlo_print (("%s ", elt->_.sub.ot->ot_new_prefix));
	  if (elt->_.sub.trans)
	    sqlo_print ((" transdir=%d ", (int)elt->_.sub.trans->tl_direction));
	  break;
	case DFE_ORDER:
	  sqlo_print ((" order_by "));
	  break;
	case DFE_GROUP:
	  if (elt->_.setp.is_linear)
	    sqlo_print ((" linear_group_by "));
	  else
	    sqlo_print ((" group_by "));
	  break;
	default:
	  elt_printed = 0;
	}
      if (elt->dfe_next && elt_printed)
	sqlo_print ((", "));
    }
  if (!dfe->_.sub.hash_filler_of)
  sqlo_print (("\n"));
}

void
sqlo_box_print (caddr_t tree)
{
  dbg_print_box (tree, stdout);
  printf ("\n");
  fflush (stdout);
}

#ifdef DEBUG

void
dbg_qi_print_row (query_instance_t * qi, dk_set_t slots, int nthset)
{
  int save_nthset = qi->qi_set;
  qi->qi_set = nthset;
  DO_SET (state_slot_t *, sl, &slots)
  {
    dbg_print_box (qst_get (qi, sl), stdout);
    printf ("\t");
  }
  END_DO_SET ()qi->qi_set = save_nthset;
  printf ("\n");
  fflush (stdout);
}

void
dbg_qi_print_slots (query_instance_t * qi, state_slot_t ** slots, int nthset)
{
  int save_nthset = qi->qi_set;
  qi->qi_set = nthset;
  int i;
  DO_BOX (state_slot_t *, sl, i, slots)
  {
    dbg_print_box (qst_get (qi, sl), stdout);
    printf ("\t");
  }
  END_DO_BOX;
  qi->qi_set = save_nthset;
  printf ("\n");
  fflush (stdout);
}

#endif // DEBUG


void
jp_arr_print (dk_set_t * arr)
{
  int inx;
  DO_BOX (dk_set_t, list, inx, arr)
    {
      df_elt_t * head = (df_elt_t*)list->data;
      printf (" card %s %g score %g %s ", head->dfe_is_joined ? "": "NJ", head->dfe_arity, head->dfe_unit, head->_.table.ot->ot_new_prefix);
      DO_SET (df_elt_t *, dfe, &list->next)
	{
	  printf ("%s ", dfe->_.table.ot->ot_new_prefix);
	}
      END_DO_SET();
      printf ("\n");
    }
  END_DO_BOX;
}


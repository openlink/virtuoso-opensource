/*
 *  $Id$
 *
 *  Code genration for triggers that update native RDF data on changes in relational sources
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

#include "libutil.h"
#include "sqlnode.h"
#include "sqlbif.h"
#include "sqlparext.h"
#include "bif_text.h"
#include "xmlparser.h"
#include "xmltree.h"
#include "numeric.h"
#include "rdf_core.h"
#include "security.h"
#include "sqlcmps.h"
#include "sparql.h"
#include "sparql2sql.h"
#include "xml_ecm.h" /* for sorted dict, ECM_MEM_NOT_FOUND etc. */
#include "arith.h" /* for cmp_boxes() */
#ifdef __cplusplus
extern "C" {
#endif
#include "sparql_p.h"
#ifdef __cplusplus
}
#endif

extern int adler32_of_buffer (unsigned char *data, size_t len);

/*! Description of blocker that become conditional wrapper of form "if (field <> inverse_qmf (const)) { rdb2rdf actions }".
 Some quad map pattern may correspond to a given table and given field values when used standalone but be shadowed by EXCLUSIVE patterns before.
This structure is to keep one such blocking pattern, as one value per item of blocking pattern.
Field value is NULL if quad map value is not specified in the corresponding position, or qm_value if the value is a constant.
If quad map value is specified but not a constant then there's no need to remember it: it's enough to interrupt scan of branch of quad map tree after such an "match-all" exclusive (no more processing -- no need for data for that processing).
*/

typedef struct rdb2rdf_blocker_s {
    struct rdb2rdf_blocker_s *rrb_next;			/*!< Next item in list */
    SPART *rrb_const_vals[SPART_TRIPLE_FIELDS_COUNT];	/*!< Field values as boxes, SPAR_QNAME or SPAR_LITERAL. No graph translation here, otherwise xlat can merge an exclusive graph merged with non-exclusive */
    int rrb_total_eclipse;				/*!< Nonzero if total eclipse so no further scan required. For debugging, bits 0x1-0x8 indicate positions of non-constant quad map values */
  } rdb2rdf_blocker_t;

#define RDB2RDF_MAX_ALIASES_OF_MAIN_TABLE	7 /*!< Maximim allowed number of aliases of the main table in the quad map pattern. More than enough, I guess. 8*4=32, so uint32 type is sufficient for control bitmasks */

typedef struct rdb2rdf_optree_s {
    quad_map_t *rro_qm;			/*!< Pointer to map that is root of qm subtree in question */
    struct rdb2rdf_optree_s *rro_parent;	/*!< Pointer to a parent node, it may contain exclusive blockers that */
    struct rdb2rdf_optree_s *rro_breakup_begin;	/*!< Pointer to a node that will be first in the breakup containing the given leaf, NULL for non-leafs */
    struct rdb2rdf_optree_s **rro_subtrees;	/*!< optrees corresponding to sub quad maps */
    rdb2rdf_blocker_t	*rro_blockers_before;	/*!< All "strictly previous" blockers of this and above levels (for codegen of this qm). From previous siblings, previous siblings of parent and so on */
    rdb2rdf_blocker_t	*rro_blockers_before_next;	/*!< rro_blockers_before, extended. If a local blocker exists, it is added to the list of brokers. If optrees are not created for few next sibling quad maps but these quad maps are exclusive then their brokers are added too. This is to fill in next sibling optrees. */
    int			rro_is_leaf;		/*!< This optree has no descendants and create an SQL DML statement in the trigger */
    dk_set_t rro_aliases_of_main_table;		/*!< Aliases used for main table, alias_no is a zero-based position in this set */
    uint32 rro_bits_of_fields_here;		/*!< Bitmask that indicates which fields are calculated by alias only or fixed at this level, not at parent, (0x1 << alias_no*4) for graph, (0x2 << alias_no*4) for S, (0x4 << alias_no*4) for P and (0x8 << alias_no*4) for O */
    uint32 rro_bits_of_fields_here_and_above;	/*!< Bitwize OR of \c rro_bits_of_fields_here of this optree and all its ancestors */
    int			rro_own_serial;		/*!< Serial number of optree in the whole tree */
    int			rro_qm_index;		/*!< Position of rro_qm in \c rrc_all_qms of codegen context */
    boxint		rro_rule_id;		/*!< Value for RULE_ID field of RDF_QUAD_DELETE_QUEUE */
    int			rro_self_multi;		/*!< Flags if multiple database rows may create one quad via \c rro_qm alone. */
    int			rro_sample_of_rule;	/*!< Value for RULE_ID field of RDF_QUAD_DELETE_QUEUE */
  } rdb2rdf_optree_t;

#define RDB2RDF_RSVS_CONST	1
#define RDB2RDF_RSVS_QMV	2
typedef struct rdb2rdf_single_val_state_s {
  char rsvs_type;
  union {
    ccaddr_t	tsvs_const;
    qm_value_t	*tsvs_qm;
    void *	tsvs_ptr;
    } _;
} rdb2rdf_single_val_state_t;

/*! State of variables g_val, s_val, p_val and o_val */
typedef struct rdb2rdf_vals_state_s {
    struct rdb2rdf_vals_state_s *rrvs_next;		/*!< Pointer to next state in enclosing branch */
    rdb2rdf_single_val_state_t rrvs_vals[SPART_TRIPLE_FIELDS_COUNT];	/*!< Pointers to source qmvs or consts that are now values of variables. NULL means that the variable is uninitialized or unknown after branching on if(){} . */
  } rdb2rdf_vals_state_t;

typedef struct rdb2rdf_ctx_s {
    rdb2rdf_optree_t		rrc_root_rro;	/*!< Root optree, an fake one that corresponds to the whole storage (user's quad maps are its subtrees) */
    rdb2rdf_vals_state_t *	rrc_rrvs_stack;	/*!< Stack of states of variables */
    int			rrc_all_qm_count;	/*!< Count of all quad maps in the storage */
    dk_set_t			rrc_qm_revlist;	/*!< Accumulator to build \c rrc_all_qms */
    quad_map_t **		rrc_all_qms;	/*!< List of all quad maps of the storage (first */
    char **		rrc_conflicts_of_qms;	/*!< Matrix of RDB2RDF_QMQM_xxx values, one row per quad map (same order as in \c rrc_all_qms), one item per qm-to-qm relation */
    caddr_t *			rrc_graph_xlat;	/*!< An get_keyword style array of strings; constant graph of RDF View as a key, replacement graph of the dump as a value. Can be NULL. */
    int			rrc_graph_xlat_count;	/*!< Count of strings (not count of pairs) in rrc_graph_xlat */
    int			rrc_rule_id_seed;	/*!< Value for RULE_ID field of RDF_QUAD_DELETE_QUEUE */
    int				rrc_rule_count;	/*!< Count of rules, if zero then "after delete" code is not needed. */
    sparp_t			rrc_sparp_stub;	/*!< Stub for use its auto-initializable fields in sparp_rvr_intersect_sprintffs() and the like */
  } rdb2rdf_ctx_t;


#define RDB2RDF_CODEGEN_EXPLAIN			0
#define RDB2RDF_CODEGEN_INITIAL			1
#define RDB2RDF_CODEGEN_AFTER_INSERT		2
#define RDB2RDF_CODEGEN_AFTER_UPDATE		3
#define RDB2RDF_CODEGEN_BEFORE_DELETE		4
#define COUNTOF__RDB2RDF_CODEGEN		5
#define RDB2RDF_CODEGEN_BEFORE_UPDATE		13
#define RDB2RDF_CODEGEN_AFTER_DELETE		14

#define RDB2RDF_CODEGEN_INITIAL_SUB_SINGLE	1
#define RDB2RDF_CODEGEN_INITIAL_SUB_MULTI	2
#define RDB2RDF_CODEGEN_SUB_INS			3
#define RDB2RDF_CODEGEN_SUB_BEFORE_DEL		4
#define RDB2RDF_CODEGEN_SUB_AFTER_DEL		5

#define RDB2RDF_QMQM_NOT_PROVEN		'?'	/*!< The cell is not yet filled with RDB2RDF_QMQM_DISJOIN or RDB2RDF_QMQM_INTERSECT */
#define RDB2RDF_QMQM_DISJOIN		'.'	/*!< Qm is proven to be disjoint with the main qm */
#define RDB2RDF_QMQM_INTERSECT		'I'	/*!< Qm is proven to be intersecting with the main qm */
#define RDB2RDF_QMQM_SELF		's'	/*!< Qm is equal to the main qm (on "main diagonal" of rrc_conflicts_of_qms) */
#define RDB2RDF_QMQM_WEIRD_SELF		'w'	/*!< Qm is equal to the main qm but not on "main diagonal", so onw qm is found in the storage _twice_ */
#define RDB2RDF_QMQM_GROUPING		'g'	/*!< Grouping qms are excluded from processing */
#define RDB2RDF_QMQM_SHADOWED_BY_MAIN	'>'	/*!< Qm is shadowed by the main qm that is declared as an "exclusive" or "soft exclusive" */
#define RDB2RDF_QMQM_SHADOWED_BY_THIRD	'}'	/*!< Qm is shadowed not by by the main qm but by some third party */
#define RDB2RDF_QMQM_SHADOWS_MAIN	'<'	/*!< Qm shadows the main one, internal error if the cell is probed. */

#define RDB2RDF_INTERNAL_ERROR sqlr_new_error ("22023", "SR635", "rdb2rdf internal codegen error, line %d", __LINE__);


void
rdb2rdf_reset_rrvs_stack (rdb2rdf_ctx_t *rrc)
{
  rrc->rrc_rrvs_stack = (rdb2rdf_vals_state_t *)t_alloc_box (sizeof (rdb2rdf_vals_state_t), DV_ARRAY_OF_LONG);
}

void
rdb2rdf_push_rrvs_stack (rdb2rdf_ctx_t *rrc)
{
  rdb2rdf_vals_state_t *new_top = (rdb2rdf_vals_state_t *)t_box_copy ((caddr_t)(rrc->rrc_rrvs_stack));
  new_top->rrvs_next = rrc->rrc_rrvs_stack;
  rrc->rrc_rrvs_stack = new_top;
}

void
rdb2rdf_pop_rrvs_stack (rdb2rdf_ctx_t *rrc, int expects_empty_after)
{
  rdb2rdf_vals_state_t *curr = rrc->rrc_rrvs_stack;
  rdb2rdf_vals_state_t *next;
  if (NULL == curr)
    RDB2RDF_INTERNAL_ERROR;
  next = curr->rrvs_next;
  if (expects_empty_after)
    {
      if (NULL != next)
        RDB2RDF_INTERNAL_ERROR;
    }
  else
    {
      int fld_ctr;
      if (NULL == next)
        RDB2RDF_INTERNAL_ERROR;
      for (fld_ctr = SPART_TRIPLE_FIELDS_COUNT; fld_ctr--; /* no step */)
        {
          rdb2rdf_single_val_state_t *curr_val = curr->rrvs_vals + fld_ctr;
          rdb2rdf_single_val_state_t *next_val = next->rrvs_vals + fld_ctr;
          if ((curr_val->_.tsvs_ptr == next_val->_.tsvs_ptr) || (0 == next_val->rsvs_type))
            continue;
          if (0 == curr_val->rsvs_type)
            {
              next->rrvs_vals[fld_ctr].rsvs_type = 0;
              next->rrvs_vals[fld_ctr]._.tsvs_ptr = NULL;
              continue;
            }
          if ((RDB2RDF_RSVS_CONST != curr_val->rsvs_type) || (RDB2RDF_RSVS_CONST != next_val->rsvs_type) ||
            (DV_TYPE_OF (next_val->_.tsvs_ptr) != DV_TYPE_OF (curr_val->_.tsvs_ptr)) ||
            !sparp_values_equal (&(rrc->rrc_sparp_stub), curr_val->_.tsvs_const, NULL, NULL, next_val->_.tsvs_const, NULL, NULL) )
            {
              next->rrvs_vals[fld_ctr].rsvs_type = 0;
              next->rrvs_vals[fld_ctr]._.tsvs_ptr = NULL;
            }
        }
      rrc->rrc_rrvs_stack = next;
   }
}

void
rrc_tweak_const_with_graph_xlat (rdb2rdf_ctx_t *rrc, ccaddr_t *fld_const_ptr)
{
  int idx;
  if (NULL == fld_const_ptr[0])
    return;
  if (DV_UNAME != DV_TYPE_OF (fld_const_ptr[0]))
    sqlr_new_error ("22023", "SR637", "A quad map has constant graph that is not an IRI");
  idx = ecm_find_name (fld_const_ptr[0], rrc->rrc_graph_xlat, rrc->rrc_graph_xlat_count/2, 2 * sizeof (caddr_t));
  if (0 <= idx)
    fld_const_ptr[0] = rrc->rrc_graph_xlat [2*idx + 1];
}

/*! Returns 1 if quad map \c qm does not use table \c table_name in any alias that is keyrefd by resulting quad.
If 1 is returned then removal of a row in table does not automatically mean removal of some quad made from that row before */
int
rdb2rdf_qm_is_self_multi (quad_map_t *qm, ccaddr_t table_name)
{
  int atbl_ctr, keyrefd_ctr, found = 0;
  for (atbl_ctr = qm->qmAllATableUseCount; atbl_ctr--; /* no step */)
    {
      qm_atable_use_t *qmatu = ((qm_atable_use_t *)(qm->qmAllATableUses))+atbl_ctr;
      if (strcmp (table_name, qmatu->qmatu_tablename))
        continue;
      DO_BOX_FAST_REV (caddr_t, a, keyrefd_ctr, qm->qmAliasesKeyrefdByQuad)
        {
          if (strcmp (a, qmatu->qmatu_alias)) continue;
          found = 1;
          break;
        }
      END_DO_BOX_FAST_REV;
      if (!found)
        return 1;
    }
  return 0;
}

rdb2rdf_optree_t *
rdb2rdf_create_optree (rdb2rdf_ctx_t *rrc, rdb2rdf_optree_t *parent, rdb2rdf_optree_t *prev_sibling, quad_map_t *qm, ccaddr_t table_name)
{
  rdb2rdf_optree_t tmpres;
  int table_aliases_count = 0;
  if (NULL == qm->qmAliasesKeyrefdByQuad)
    sqlr_new_error ("22023", "SR636", "Some quad maps for table %.500s needs upgrade before generating RDB2RDF code, please call DB.DBA.RDF_UPGRADE_METADATA()", table_name ? table_name : "UNKNOWN" );
  memset (&tmpres, 0, sizeof (rdb2rdf_optree_t));
  tmpres.rro_is_leaf = (NULL == qm->qmUserSubMaps);
  tmpres.rro_qm = qm;
  tmpres.rro_parent = parent;
  tmpres.rro_blockers_before = ((NULL != prev_sibling) ? prev_sibling->rro_blockers_before_next : parent->rro_blockers_before);
  tmpres.rro_qm_index = (rrc->rrc_all_qm_count)++;
  t_set_push (&(rrc->rrc_qm_revlist), qm);
  if ((!tmpres.rro_is_leaf) && (SPART_QM_EXCLUSIVE & qm->qmMatchingFlags)) /* i.e. there's a blocker and there's a need in its calculation */
    {
      int fld_ctr;
      rdb2rdf_blocker_t *local_rrb = (rdb2rdf_blocker_t *)t_alloc (sizeof (rdb2rdf_blocker_t));
      for (fld_ctr = SPART_TRIPLE_FIELDS_COUNT; fld_ctr--; /*no step*/)
        {
          qm_value_t *fld_qmv = SPARP_FIELD_QMV_OF_QM(qm,fld_ctr);
          rdf_val_range_t *fld_const_rvr = SPARP_FIELD_CONST_RVR_OF_QM(qm,fld_ctr);
          if (fld_const_rvr->rvrRestrictions & SPART_VARR_FIXED)
            local_rrb->rrb_const_vals[fld_ctr] = spar_make_qname_or_literal_from_rvr (&(rrc->rrc_sparp_stub), fld_const_rvr, 1);
          else if (NULL != fld_qmv)
            local_rrb->rrb_total_eclipse |= 1 << fld_ctr;
        }
      local_rrb->rrb_next = tmpres.rro_blockers_before;
      tmpres.rro_blockers_before_next = local_rrb;
    }
  else
    tmpres.rro_blockers_before_next = tmpres.rro_blockers_before;
  if (tmpres.rro_is_leaf && (NULL == qm->qmAllConds))
    sparp_collect_all_conds (NULL, qm);
  if (tmpres.rro_is_leaf && (NULL != table_name))
    {
      int qm_atbl_ctr;
      if (NULL == qm->qmAllATableUses)
        sparp_collect_all_atable_uses (NULL, qm);
      for (qm_atbl_ctr = qm->qmAllATableUseCount; qm_atbl_ctr--; /* no step */)
        {
          qm_atable_use_t *qmatu = ((qm_atable_use_t *)(qm->qmAllATableUses))+qm_atbl_ctr;
          if (strcmp (qmatu->qmatu_tablename, table_name))
            continue;
          t_set_push (&(tmpres.rro_aliases_of_main_table), (caddr_t)(qmatu->qmatu_alias));
          table_aliases_count++;
        }
      if ((0 == qm->qmAllATableUseCount) && (NULL != qm->qmTableName) && !strcmp (qm->qmTableName, table_name)) /* Prehistoric declaration of the quad map */
        {
          t_set_push (&(tmpres.rro_aliases_of_main_table), uname___empty);
          table_aliases_count = 1;
        }
    }
  if (table_aliases_count)
    {
      int fld_ctr;
      if (8 < table_aliases_count)
        sqlr_new_error ("22023", "SR637", "Overcomplicated quad map contains more than 8 aliases for table \"%.200s\"", table_name ? table_name : "UNKNOWN" );
      for (fld_ctr = SPART_TRIPLE_FIELDS_COUNT; fld_ctr--; /*no step*/)
        {
          qm_value_t *fld_qmv = SPARP_FIELD_QMV_OF_QM(qm,fld_ctr);
          rdf_val_range_t *fld_const_rvr = SPARP_FIELD_CONST_RVR_OF_QM(qm,fld_ctr);
          if (fld_const_rvr->rvrRestrictions & SPART_VARR_FIXED)
            tmpres.rro_bits_of_fields_here |= (0x11111111 << fld_ctr);
          else if (NULL != fld_qmv->qmvATables)
            {
              if ((1 == BOX_ELEMENTS (fld_qmv->qmvATables)) && !strcmp (fld_qmv->qmvATables[0]->qmvaTableName, table_name))
                {
                  int pass = dk_set_position_of_string (tmpres.rro_aliases_of_main_table, fld_qmv->qmvATables[0]->qmvaAlias);
                  if (0 > pass)
#ifndef NDEBUG
                    GPF_T1 ("rdb2rdf_" "create_optree(): weird collection of aliases");
#else
                    continue;
#endif
                  tmpres.rro_bits_of_fields_here |= (0x1 << (fld_ctr + 4*pass));
                }
            }
          else if (NULL != fld_qmv->qmvTableName)
            {
              if (!strcmp (fld_qmv->qmvTableName, table_name))
                tmpres.rro_bits_of_fields_here |= (0x1 << fld_ctr);
            }
          else if (NULL != qm->qmTableName)
            {
              if (!strcmp (qm->qmTableName, table_name))
                tmpres.rro_bits_of_fields_here |= (0x1 << fld_ctr);
            }
        }
      tmpres.rro_self_multi = rdb2rdf_qm_is_self_multi (qm, table_name);
    }
  tmpres.rro_bits_of_fields_here_and_above = tmpres.rro_bits_of_fields_here;
  if (NULL != parent)
    tmpres.rro_bits_of_fields_here_and_above |= parent->rro_bits_of_fields_here_and_above;
  if (NULL != qm->qmUserSubMaps)
    {
      dk_set_t subtrees = NULL;
      int sub_qm_ctr;
      rdb2rdf_optree_t *prev_sub_qm_rro = NULL;
      DO_BOX_FAST (quad_map_t *, sub_qm, sub_qm_ctr, qm->qmUserSubMaps)
        {
          rdb2rdf_optree_t *sub_qm_rro = rdb2rdf_create_optree (rrc, &tmpres, prev_sub_qm_rro, sub_qm, table_name);
          if (NULL == sub_qm_rro)
            continue;
          t_set_push (&subtrees, sub_qm_rro);
          prev_sub_qm_rro = sub_qm_rro;
          if ((NULL != sub_qm_rro->rro_blockers_before_next) && sub_qm_rro->rro_blockers_before_next->rrb_total_eclipse)
            break;
        }
      END_DO_BOX_FAST;
      if (NULL != subtrees)
        tmpres.rro_subtrees = (rdb2rdf_optree_t **)t_revlist_to_array (subtrees);
    }
  if (tmpres.rro_is_leaf ? ((0 != table_aliases_count) || (NULL == table_name)) : (NULL != tmpres.rro_subtrees))
    {
      int sub_qm_rro_ctr;
      rdb2rdf_optree_t *res = (rdb2rdf_optree_t *)t_alloc (sizeof (rdb2rdf_optree_t));
      tmpres.rro_own_serial = 1 + ((NULL != prev_sibling) ? prev_sibling->rro_own_serial : parent->rro_own_serial);
      memcpy (res, &tmpres, sizeof (rdb2rdf_optree_t));
      DO_BOX_FAST (rdb2rdf_optree_t *, sub_qm_rro, sub_qm_rro_ctr, tmpres.rro_subtrees)
        {
          sub_qm_rro->rro_parent = res;
        }
      END_DO_BOX_FAST;
      return res;
    }
  if (NULL != prev_sibling)
    prev_sibling->rro_blockers_before_next = tmpres.rro_blockers_before_next;
  return NULL; /* The qm is totally useless for triggers on \c table_name */
}

void
rdb2rdf_list_tables (rdb2rdf_optree_t *rro, dk_set_t *tables_ret)
{
  int sub_qm_rro_ctr;
  quad_map_t *qm = rro->rro_qm;
  if (NULL != qm)
    {
      int ctr;
      if (NULL == qm->qmAllATableUses)
        sparp_collect_all_atable_uses (NULL, qm);
      for (ctr = qm->qmAllATableUseCount; ctr--; /* no step */)
        {
          qm_atable_use_t *qmatu = ((qm_atable_use_t *)(qm->qmAllATableUses)) + ctr;
          ccaddr_t tblname = qmatu->qmatu_tablename;
          if (0 > dk_set_position_of_string (tables_ret[0], tblname))
            dk_set_push (tables_ret, box_copy_tree (tblname));
        }
    }
  DO_BOX_FAST (rdb2rdf_optree_t *, sub_qm_rro, sub_qm_rro_ctr, rro->rro_subtrees)
    rdb2rdf_list_tables (sub_qm_rro, tables_ret);
  END_DO_BOX_FAST;
}

void
rdb2rdf_set_rvr_by_const_or_qmv (rdb2rdf_ctx_t *rrc, rdf_val_range_t *rvr, ccaddr_t fld_const, qm_value_t *fld_qmv)
{
  if (NULL != fld_const)
    sparp_rvr_set_by_constant (NULL, rvr, NULL, (SPART *)fld_const);
  else
    {
      rdf_val_range_t *qmv_or_fmt_rvr = NULL;
      if ((SPART_VARR_SPRINTFF | SPART_VARR_FIXED) & fld_qmv->qmvRange.rvrRestrictions)
        qmv_or_fmt_rvr = &(fld_qmv->qmvRange);
      else if ((NULL != fld_qmv->qmvFormat) && ((SPART_VARR_SPRINTFF | SPART_VARR_FIXED) & fld_qmv->qmvFormat->qmfValRange.rvrRestrictions))
        qmv_or_fmt_rvr = &(fld_qmv->qmvFormat->qmfValRange);
      else
        qmv_or_fmt_rvr = &(fld_qmv->qmvRange);
      sparp_rvr_copy (&(rrc->rrc_sparp_stub), rvr, qmv_or_fmt_rvr);
    }
}

void
rdb2rdf_calculate_qmqm (rdb2rdf_ctx_t *rrc, rdb2rdf_optree_t *main_optree, int other_qm_idx)
{
  int main_qm_idx = main_optree->rro_qm_index;
  quad_map_t *main_qm, *other_qm;
  int fld_ctr;
  if (RDB2RDF_QMQM_NOT_PROVEN != rrc->rrc_conflicts_of_qms[main_qm_idx][other_qm_idx])
    return;
  main_qm = rrc->rrc_all_qms [main_qm_idx];
  other_qm = rrc->rrc_all_qms [other_qm_idx];
/* Optimistic loop */
  for (fld_ctr = 0; fld_ctr < SPART_TRIPLE_FIELDS_COUNT; fld_ctr++)
    {
      rdf_val_range_t *main_fld_const_rvr, *other_fld_const_rvr;
      main_fld_const_rvr = SPARP_FIELD_CONST_RVR_OF_QM(main_qm,fld_ctr);
      if (!(main_fld_const_rvr->rvrRestrictions & SPART_VARR_FIXED))
        continue;
      other_fld_const_rvr = SPARP_FIELD_CONST_RVR_OF_QM(other_qm,fld_ctr);
      if (!(other_fld_const_rvr->rvrRestrictions & SPART_VARR_FIXED))
        continue;
      if ((main_fld_const_rvr->rvrRestrictions & SPART_VARR_IS_REF) != (other_fld_const_rvr->rvrRestrictions & SPART_VARR_IS_REF))
        goto disjoin; /* see below */
      if (main_fld_const_rvr->rvrDatatype != other_fld_const_rvr->rvrDatatype)
        goto disjoin; /* see below */
      if ((SPART_TRIPLE_GRAPH_IDX == fld_ctr) && rrc->rrc_graph_xlat_count)
        {
          ccaddr_t main_fld_const = main_fld_const_rvr->rvrFixedValue;
          ccaddr_t other_fld_const = other_fld_const_rvr->rvrFixedValue;
          rrc_tweak_const_with_graph_xlat (rrc, &main_fld_const);
          rrc_tweak_const_with_graph_xlat (rrc, &other_fld_const);
          if (main_fld_const != other_fld_const) /* These consts are either UNAMEs or smth weirdly wrong, so we can compare pointers */
            goto disjoin; /* see below */
        }
      else if (!sparp_rvrs_have_same_fixedvalue (&(rrc->rrc_sparp_stub), main_fld_const_rvr, other_fld_const_rvr))
        goto disjoin; /* see below */
        }
/* Pessimistic loop */
  for (fld_ctr = 0; fld_ctr < SPART_TRIPLE_FIELDS_COUNT; fld_ctr++)
    {
      rdf_val_range_t *main_fld_const_rvr = SPARP_FIELD_CONST_RVR_OF_QM(main_qm,fld_ctr);
      rdf_val_range_t *other_fld_const_rvr = SPARP_FIELD_CONST_RVR_OF_QM(other_qm,fld_ctr);
      qm_value_t *main_fld_qmv;
      qm_value_t *other_fld_qmv;
      rdf_val_range_t main_rvr, other_rvr;
      if ((main_fld_const_rvr->rvrRestrictions & SPART_VARR_FIXED) && (other_fld_const_rvr->rvrRestrictions & SPART_VARR_FIXED))
        continue; /* consts are compared in the optimistic loop, so either disjoin is found or there's no need to compare equal values again */
      main_fld_qmv = SPARP_FIELD_QMV_OF_QM(main_qm,fld_ctr);
      other_fld_qmv = SPARP_FIELD_QMV_OF_QM(other_qm,fld_ctr);
      if ((SPART_TRIPLE_GRAPH_IDX == fld_ctr) && rrc->rrc_graph_xlat_count)
        {
          ccaddr_t main_fld_const = main_fld_const_rvr->rvrFixedValue;
          ccaddr_t other_fld_const = other_fld_const_rvr->rvrFixedValue;
          rrc_tweak_const_with_graph_xlat (rrc, &main_fld_const);
          rrc_tweak_const_with_graph_xlat (rrc, &other_fld_const);
          rdb2rdf_set_rvr_by_const_or_qmv (rrc, &main_rvr, main_fld_const, main_fld_qmv);
          rdb2rdf_set_rvr_by_const_or_qmv (rrc, &other_rvr, other_fld_const, other_fld_qmv);
        }
      else
        {
          sparp_rvr_copy (&(rrc->rrc_sparp_stub), &main_rvr,
            ((main_fld_const_rvr->rvrRestrictions & SPART_VARR_FIXED) ? main_fld_const_rvr : &(main_fld_qmv->qmvRange)) );
          sparp_rvr_copy (&(rrc->rrc_sparp_stub), &other_rvr,
            ((other_fld_const_rvr->rvrRestrictions & SPART_VARR_FIXED) ? other_fld_const_rvr : &(other_fld_qmv->qmvRange)) );
        }
      sparp_rvr_audit(&(rrc->rrc_sparp_stub), &main_rvr);
      sparp_rvr_audit(&(rrc->rrc_sparp_stub), &other_rvr);
      sparp_rvr_tighten (&(rrc->rrc_sparp_stub), &main_rvr, &other_rvr, ~0);
      if (SPART_VARR_CONFLICT & main_rvr.rvrRestrictions)
        goto disjoin; /* see below */
    }
/* Intersect is by default */
  rrc->rrc_conflicts_of_qms[main_qm_idx][other_qm_idx] = RDB2RDF_QMQM_INTERSECT;
  rrc->rrc_conflicts_of_qms[other_qm_idx][main_qm_idx] = RDB2RDF_QMQM_INTERSECT;
  return;

disjoin:
  rrc->rrc_conflicts_of_qms[main_qm_idx][other_qm_idx] = RDB2RDF_QMQM_DISJOIN;
  rrc->rrc_conflicts_of_qms[other_qm_idx][main_qm_idx] = RDB2RDF_QMQM_DISJOIN;
  return;
}

void
ses_print_ruler_10 (dk_session_t *ses, int len, const char *head1, const char *tail1, const char *head2, const char *tail2)
{
  char buf[32+1];
  int ctr;
  SES_PRINT (ses, head1);
  for (ctr = 0; ctr < len; ctr += 10)
    {
      int rest = (len - ctr);
      if (rest > 10)
        {
          sprintf (buf, "%d          ", ctr / 10);
          buf [10] = '\0';
        }
      else sprintf (buf, "%d", ctr / 10);
      SES_PRINT (ses, buf);
    }
  SES_PRINT (ses, tail1);
  SES_PRINT (ses, "\n");
  SES_PRINT (ses, head2);
  for (ctr = 0; ctr < len; ctr += 10)
    {
      int n = (len - ctr);
      if (n > 10)
        n = 10;
      session_buffered_write (ses, "0123456789", n);
    }
  SES_PRINT (ses, tail2);
  SES_PRINT (ses, "\n");
}

void
rdb2rdf_ctx_dump (rdb2rdf_ctx_t *rrc, dk_session_t *ses)
{
  char buf[20];
  int main_qm_ctr;
  ses_print_ruler_10 (ses, rrc->rrc_all_qm_count, "      ", "", "      ", "");
  for (main_qm_ctr = 0; main_qm_ctr < rrc->rrc_all_qm_count; main_qm_ctr++)
    {
#if 0
      int other_qm_ctr;
      for (other_qm_ctr = rrc->rrc_all_qm_count; other_qm_ctr--; /* no step */)
        {
          if (RDB2RDF_QMQM_NOT_PROVEN == rrc->rrc_conflicts_of_qms [main_qm_index][other_qm_ctr])
            rdb2rdf_calculate_qmqm (rrc, rro, other_qm_ctr);
        }
#endif
      sprintf (buf, "%.05d ", main_qm_ctr);
      SES_PRINT (ses, buf); SES_PRINT (ses, rrc->rrc_conflicts_of_qms [main_qm_ctr]); SES_PRINT (ses, "\n");
    }
  ses_print_ruler_10 (ses, rrc->rrc_all_qm_count, "      ", "", "      ", "");
  SES_PRINT (ses, "\n");
}

void
rdb2rdf_optree_dump (rdb2rdf_ctx_t *rrc, rdb2rdf_optree_t *rro, dk_session_t *ses)
{
  char buf[5000];
  char buf2[32+1];
  int sub_qm_rro_ctr;
  int ctr;
  rdb2rdf_blocker_t *blockers_tail;
  sprintf (buf, "-----\n%s optree %d from qm %d, subtree of %d, breakup starts at %d\n",
    (rro->rro_is_leaf ? "LEAF" : "grouping"),
    rro->rro_own_serial, rro->rro_qm_index,
    ((NULL != rro->rro_parent) ? rro->rro_parent->rro_own_serial : -1),
    ((NULL != rro->rro_breakup_begin) ? rro->rro_breakup_begin->rro_own_serial : -1) );
  SES_PRINT (ses, buf);
  if (NULL != rro->rro_qm)
    {
      SES_PRINT (ses, "Quad: ");
      for (ctr = 0; ctr < SPART_TRIPLE_FIELDS_COUNT; ctr++)
        {
          rdf_val_range_t *fld_const_rvr = SPARP_FIELD_CONST_RVR_OF_QM(rro->rro_qm, ctr);
          if (fld_const_rvr->rvrRestrictions & SPART_VARR_FIXED)
            {
              switch (DV_TYPE_OF (fld_const_rvr->rvrFixedValue))
                {
                case DV_UNAME: sprintf (buf, " <%s>", fld_const_rvr->rvrFixedValue); SES_PRINT (ses, buf); break;
                case DV_STRING: sprintf (buf, " '''%s'''", fld_const_rvr->rvrFixedValue); SES_PRINT (ses, buf); break;
                case DV_LONG_INT: sprintf (buf, " " BOXINT_FMT, (boxint)(fld_const_rvr->rvrFixedValue)); SES_PRINT (ses, buf); break;
                default: SES_PRINT (ses, " const"); break;
                }
            }
          else
            {
              sprintf (buf, " ?%c", "GSPO"[ctr]); SES_PRINT (ses, buf);
            }
        }
      SES_PRINT (ses, "\n");
    }
  if (rro->rro_is_leaf)
    {
      int other_qm_ctr;
      for (other_qm_ctr = rrc->rrc_all_qm_count; other_qm_ctr--; /* no step */)
        {
          if (RDB2RDF_QMQM_NOT_PROVEN == rrc->rrc_conflicts_of_qms [rro->rro_qm_index][other_qm_ctr])
            rdb2rdf_calculate_qmqm (rrc, rro, other_qm_ctr);
        }
      ses_print_ruler_10 (ses, rrc->rrc_all_qm_count, "      ", "", "      ", "");
      SES_PRINT (ses, "QMQM: "); SES_PRINT (ses, rrc->rrc_conflicts_of_qms [rro->rro_qm_index]); SES_PRINT (ses, "\n");
    }
  /*  quad_map_t *rro_qm; */
  for (blockers_tail = rro->rro_blockers_before_next; (blockers_tail != NULL) && (blockers_tail != rro->rro_blockers_before); blockers_tail = blockers_tail->rrb_next)
    {
      int ctr;
      SES_PRINT (ses, "Adds a breakup");
      for (ctr = 0; ctr < SPART_TRIPLE_FIELDS_COUNT; ctr++)
        {
          ccaddr_t cv = blockers_tail->rrb_const_vals[ctr];
          if (NULL == cv)
            continue;
          sprintf (buf, "  %c = ", "GSPO"[ctr]); SES_PRINT (ses, buf);
          switch (DV_TYPE_OF (cv))
            {
              case DV_STRING: sprintf (buf, "'''%.200s'''", cv); break;
              case DV_UNAME: sprintf (buf, "<%.200s>", cv); break;
              case DV_LONG_INT: sprintf (buf, "%ld", (long)(unbox(cv))); break;
              default: sprintf (buf, "const with tag %d", DV_TYPE_OF (cv)); break;
            }
          SES_PRINT (ses, buf);
        }
      SES_PRINT (ses, "\n");
    }
  SES_PRINT (ses, "Aliases:");
  DO_SET (caddr_t, a, &rro->rro_aliases_of_main_table)
    {
      sprintf (buf, " <%.200s>", a); SES_PRINT (ses, buf);
    }
  END_DO_SET()
  SES_PRINT (ses, "\n");
  if (NULL != rro->rro_qm)
    {
      SES_PRINT (ses, "Keyrefd:");
      DO_BOX_FAST (ccaddr_t, a, ctr, rro->rro_qm->qmAliasesKeyrefdByQuad)
        {
          sprintf (buf, " <%.200s>", a); SES_PRINT (ses, buf);
        }
      END_DO_BOX_FAST;
      SES_PRINT (ses, "\n");
    }
  for (ctr = 0; ctr < 32; ctr++)
    {
      buf2[ctr] = ((rro->rro_bits_of_fields_here & (1 << ctr)) ?
        "GSPOGSPOGSPOGSPOGSPOGSPOGSPOGSPO"[ctr] :
        ((rro->rro_bits_of_fields_here_and_above & (1 << ctr)) ?
          "gspogspogspogspogspogspogspogspo"[ctr] :
          "{--}{--}{--}{--}{--}{--}{--}{--}"[ctr] ) );
    }
  buf2[4 * (dk_set_length (rro->rro_aliases_of_main_table)+1)] = '\0';
  sprintf (buf, "Fields here: %s\n", buf2); SES_PRINT (ses, buf);
  /*  uint32 rro_bits_of_fields_here_and_above; */
  DO_BOX_FAST (rdb2rdf_optree_t *, sub_qm_rro, sub_qm_rro_ctr, rro->rro_subtrees)
    rdb2rdf_optree_dump (rrc, sub_qm_rro, ses);
  END_DO_BOX_FAST;
}

void
rdb2rdf_print_fld_expn (rdb2rdf_optree_t *rro, int cast_to_obj, int alias_no, quad_map_t *qm, qm_value_t *fld_qmv, const char *prefix, spar_sqlgen_t *ssg)
{
  qm_format_t *fmt = fld_qmv->qmvFormat;
/*  if (fmt->qmfValRange.rvrRestrictions & SPART_VARR_IS_REF)
    ssg_puts ("__i2id (");
  else */ if (cast_to_obj && !(fmt->qmfValRange.rvrRestrictions & SPART_VARR_LONG_EQ_SQL))
    ssg_puts ("DB.DBA.RDF_OBJ_OF_LONG (");
  ssg_print_tmpl (ssg, fmt, fmt->qmfLongOfShortTmpl, prefix, fld_qmv, NULL, NULL_ASNAME);
/*  if (fmt->qmfValRange.rvrRestrictions & SPART_VARR_IS_REF)
    ssg_putchar (')');
  else */ if (cast_to_obj && !(fmt->qmfValRange.rvrRestrictions & SPART_VARR_LONG_EQ_SQL))
    ssg_putchar (')');
}

void
rdb2rdf_print_const (rdb2rdf_ctx_t *rrc, ccaddr_t fld_const, spar_sqlgen_t *ssg)
{
  if (DV_UNAME == DV_TYPE_OF (fld_const))
    {
      ssg_puts ("__i2id (");
      ssg_print_box_as_sql_atom (ssg, fld_const, SQL_ATOM_UTF8_ONLY);
      ssg_putchar (')');
    }
  else
    ssg_print_scalar_expn (ssg, (SPART *)fld_const, qm_format_default, NULL);
}

int
rdb2rdf_is_delete_conflicting (rdb2rdf_ctx_t *rrc, rdb2rdf_optree_t *rro, ccaddr_t alias)
{
  int ctr, found = 0;
  char *qm_conflicts;
  int other_qm_ctr;
  if (NULL != alias)
    {
      quad_map_t *qm = rro->rro_qm;
      DO_BOX_FAST_REV (caddr_t, a, ctr, qm->qmAliasesKeyrefdByQuad)
        {
          if (strcmp (a, alias)) continue;
          found = 1;
          break;
        }
      END_DO_BOX_FAST_REV;
      if (!found)
        return 1;
    }
  qm_conflicts = rrc->rrc_conflicts_of_qms[rro->rro_qm_index];
  for (other_qm_ctr = rrc->rrc_all_qm_count; other_qm_ctr--; /* no step */)
    {
      if (RDB2RDF_QMQM_INTERSECT == qm_conflicts[other_qm_ctr])
        return 1;
    }
  for (other_qm_ctr = rrc->rrc_all_qm_count; other_qm_ctr--; /* no step */)
    {
      if (RDB2RDF_QMQM_NOT_PROVEN == rrc->rrc_conflicts_of_qms [rro->rro_qm_index][other_qm_ctr])
        rdb2rdf_calculate_qmqm (rrc, rro, other_qm_ctr);
      if (RDB2RDF_QMQM_INTERSECT == qm_conflicts[other_qm_ctr])
        return 1;
    }
  return 0;
}

void
rdb2rdf_calculate_rule_id (rdb2rdf_ctx_t *rrc, rdb2rdf_optree_t *rro)
{
  int needs_rule_id = rro->rro_self_multi;
  int other_qm_ctr;
  char *qm_conflicts = rrc->rrc_conflicts_of_qms[rro->rro_qm_index];
  for (other_qm_ctr = rrc->rrc_all_qm_count; other_qm_ctr--; /* no step */)
    {
      if (RDB2RDF_QMQM_NOT_PROVEN == rrc->rrc_conflicts_of_qms [rro->rro_qm_index][other_qm_ctr])
        rdb2rdf_calculate_qmqm (rrc, rro, other_qm_ctr);
    }
  if (!needs_rule_id)
    {
      for (other_qm_ctr = rrc->rrc_all_qm_count; other_qm_ctr--; /* no step */)
        {
          if (RDB2RDF_QMQM_INTERSECT != qm_conflicts[other_qm_ctr])
            continue;
          needs_rule_id = 1;
          break;
        }
    }
  if (!needs_rule_id)
    {
      rro->rro_rule_id = -1;
      return;
    }
  rrc->rrc_rule_count++;
  rro->rro_rule_id = (boxint)((unsigned)(rrc->rrc_rule_id_seed)) * 100000 + rro->rro_qm_index;
  rro->rro_sample_of_rule = 1;
  return;
}

void
rdb2rdf_qm_after_del_codegen (rdb2rdf_ctx_t *rrc, rdb2rdf_optree_t *rro, ccaddr_t table_name, int opcode, spar_sqlgen_t *ssg)
{
  char buf[300];
  char *qm_conflicts;
  int need_union = 0;
  int other_qm_ctr;
  if (0 == rro->rro_rule_id)
    rdb2rdf_calculate_rule_id (rrc, rro);
  if (!rro->rro_sample_of_rule)
    return;
  ssg_newline (0);
  sprintf (buf,
    "for (select * from DB.DBA.RDF_QUAD_DELETE_QUEUE q where q.EVENT_ID=query_instance_id(1) and RULE_ID=" BOXINT_FMT " and not exists (",
    rro->rro_rule_id );
  ssg_puts (buf);
  ssg->ssg_indent += 2;
  qm_conflicts = rrc->rrc_conflicts_of_qms[rro->rro_qm_index];
  ssg_puts ("sparql define input:storage virtrdf:SyncToQuads ask where {");
  ssg->ssg_indent += 2;
  for (other_qm_ctr = rrc->rrc_all_qm_count; other_qm_ctr--; /* no step */)
    {
      quad_map_t *other_qm = rrc->rrc_all_qms[other_qm_ctr];
      jso_rtti_t *other_qm_rtti;
      if ((RDB2RDF_QMQM_INTERSECT != qm_conflicts[other_qm_ctr]) &&
        !(rro->rro_self_multi && other_qm_ctr == rro->rro_qm_index) )
        continue;
      other_qm_rtti = gethash (other_qm, jso_rttis_of_structs);
      if ((NULL == other_qm_rtti) || (other_qm != other_qm_rtti->jrtti_self))
        sqlr_new_error ("22023", "SR638", "Some quad maps of quad store virtrdf:SyncToQuads are not loaded or corrupted or being edited during SQL code generation");
      ssg_newline (0);
      if (need_union++)
        ssg_puts ("UNION ");
      ssg_puts (" { QUAD MAP <");
      ssg_puts (other_qm_rtti->jrtti_inst_iri);
      ssg_puts ("> { graph ?:LONG::QG { ?:LONG::QS ?:LONG::QP ?:LONG::QO }}} ");
    }
  ssg_puts ("}");
  ssg->ssg_indent -= 2;
  ssg_newline (0);
  ssg_puts (") ) do {\n");
  ssg_puts ("    if (not __rdf_graph_is_in_enabled_repl (QG))\n");
  ssg_puts ("      delete from DB.DBA.RDF_QUAD where G=QG and S=QS and P=QP and O=QO option (QUIETCAST);\n"),
  ssg_puts ("    else if (exists (select top 1 1 from DB.DBA.RDF_QUAD where G=QG and S=QS and P=QP and O=QO option (QUIETCAST)))\n");
  ssg_puts ("      {\n");
  ssg_puts ("        declare triples any;\n");
  ssg_puts ("        triples := vector (vector (QS, QP, QO));\n");
  ssg_puts ("        DB.DBA.RDF_REPL_DELETE_TRIPLES (id_to_iri (QG), triples);\n");
  ssg_puts ("        delete from DB.DBA.RDF_QUAD where G=QG and S=QS and P=QP and O=QO option (QUIETCAST);\n"),
  ssg_puts ("      }\n");
  ssg_puts ("  }\n");
  ssg->ssg_indent -= 2;
  ssg_newline (0);
  sprintf (buf,
    "delete from DB.DBA.RDF_QUAD_DELETE_QUEUE q where q.EVENT_ID=query_instance_id(1) and RULE_ID=" BOXINT_FMT ";",
    rro->rro_rule_id );
  ssg_puts (buf);
}


void
rdb2rdf_qm_codegen (rdb2rdf_ctx_t *rrc, rdb2rdf_optree_t *rro, caddr_t table_name, int opcode, int subopcode, const char *prefix, ccaddr_t alias, int alias_no, spar_sqlgen_t *ssg)
{
  int fld_ctr, cond_ctr;
  int need_comma, alias_ctr;
  int out_of_loop_ifs_for_blockers = 0;
  unsigned int bits_of_fields_here;
  unsigned int bits_of_fields_above;
  boxint two_phase_delete = 0;
  quad_map_t *qm = rro->rro_qm;
  char buf[300];
  static const char *x_vals[4] = {"g_val", "s_val", "p_val", "o_val"};
  static const char *x_locals[4] = {"g_local", "s_local", "p_local", "o_local"};
#ifndef NDEBUG
  if (RDB2RDF_CODEGEN_SUB_AFTER_DEL == subopcode)
    GPF_T;
#endif
  bits_of_fields_here = ((rro->rro_bits_of_fields_here >> (alias_no * 4)) & 0xF);
  bits_of_fields_above = (NULL == rro->rro_parent) ? 0 : ((rro->rro_parent->rro_bits_of_fields_here_and_above >> (alias_no * 4)) & 0xF);
  ssg->ssg_alias_to_search = alias;
  ssg->ssg_alias_to_replace = prefix;
  if (RDB2RDF_CODEGEN_SUB_BEFORE_DEL == subopcode)
    {
      two_phase_delete = rdb2rdf_is_delete_conflicting (rrc, rro, alias);
      if (two_phase_delete)
        {
          if (0 == rro->rro_rule_id)
            rdb2rdf_calculate_rule_id (rrc, rro);
          if (0 > rro->rro_rule_id)
            RDB2RDF_INTERNAL_ERROR;
        }
    }
/* First of all we set "variable" fields because they can add IFs for blockers */
  for (fld_ctr = SPART_TRIPLE_FIELDS_COUNT; fld_ctr--; /* no step*/)
    {
      qm_value_t *fld_qmv = SPARP_FIELD_QMV_OF_QM(qm,fld_ctr);
      rdf_val_range_t *fld_const_rvr = SPARP_FIELD_CONST_RVR_OF_QM(qm,fld_ctr);
      rdb2rdf_single_val_state_t *rvvs_val_ptr = rrc->rrc_rrvs_stack->rrvs_vals + fld_ctr;
      rdb2rdf_blocker_t *rrb_iter;
      if (!(bits_of_fields_here & (1 << fld_ctr)))
        continue;
      if (bits_of_fields_above & (1 << fld_ctr))
        continue;
      if (fld_const_rvr->rvrRestrictions & SPART_VARR_FIXED)
        continue;
      if (rvvs_val_ptr->_.tsvs_qm == fld_qmv)
        continue;
      ssg_newline (0);
      ssg_putchar ("gspo"[fld_ctr]); ssg_puts ("_val := ");
      rdb2rdf_print_fld_expn (rro, (RDB2RDF_CODEGEN_SUB_BEFORE_DEL == subopcode), alias_no, qm, fld_qmv, prefix, ssg);
      ssg_putchar (';');
      rvvs_val_ptr->rsvs_type = RDB2RDF_RSVS_QMV;
      rvvs_val_ptr->_.tsvs_qm = fld_qmv;
      for (rrb_iter = rro->rro_blockers_before_next; rrb_iter != rro->rro_blockers_before ; rrb_iter = rrb_iter->rrb_next)
        {
          SPART *rrb_c = rrb_iter->rrb_const_vals [fld_ctr];
          if (NULL == rrb_c)
            continue;
          ssg_newline (0);
          ssg_puts ("if ("); ssg_putchar ("gspo"[fld_ctr]); ssg_puts ("_val != ");
          rdb2rdf_print_const (rrc, rrb_c, ssg);
          ssg_puts (") {");
          ssg->ssg_indent++;
          rdb2rdf_push_rrvs_stack (rrc);
          out_of_loop_ifs_for_blockers++;
        }
    }
/* Now a similar loop deals with consts. Blockers are not checked here hecause they've inspected when optree is composed. */
  for (fld_ctr = SPART_TRIPLE_FIELDS_COUNT; fld_ctr--; /* no step*/)
    {
      rdf_val_range_t *fld_const_rvr = SPARP_FIELD_CONST_RVR_OF_QM(qm,fld_ctr);
      caddr_t *fld_const = NULL;
      rdb2rdf_single_val_state_t *rvvs_val_ptr = rrc->rrc_rrvs_stack->rrvs_vals + fld_ctr;
      if (!(bits_of_fields_here & (1 << fld_ctr)))
        continue;
      if (bits_of_fields_above & (1 << fld_ctr))
        continue;
      if (!(fld_const_rvr->rvrRestrictions & SPART_VARR_FIXED))
        continue;
      if ((0 != alias_no) && (RDB2RDF_MAX_ALIASES_OF_MAIN_TABLE != alias_no))
        continue;
      fld_const = spar_make_qname_or_literal_from_rvr (&(rrc->rrc_sparp_stub), fld_const_rvr, 1);
      if ((SPART_TRIPLE_GRAPH_IDX == fld_ctr) && rrc->rrc_graph_xlat_count)
        rrc_tweak_const_with_graph_xlat (rrc, &fld_const);
      if ((RDB2RDF_RSVS_CONST == rvvs_val_ptr->rsvs_type) &&
        sparp_values_equal (&(rrc->rrc_sparp_stub), rvvs_val_ptr->_.tsvs_const, NULL, NULL, fld_const, NULL, NULL))
      continue;
      ssg_newline (0);
      ssg_putchar ("gspo"[fld_ctr]); ssg_puts ("_val := ");
      rdb2rdf_print_const (rrc, fld_const, ssg);
      ssg_putchar (';');
      rvvs_val_ptr->rsvs_type = RDB2RDF_RSVS_CONST;
      rvvs_val_ptr->_.tsvs_const = fld_const;
    }
  if ((1 == dk_set_length (rro->rro_aliases_of_main_table)) &&
    (1 == rro->rro_qm->qmAllATableUseCount) &&
    (0xF == bits_of_fields_here) ) /* i.e. all fields are set, no inner loop */
    {
      int cond_ctr = 0;
      ssg_newline (0);
      ssg->ssg_where_l_printed = 0;
      ssg->ssg_where_l_text = "if (";
      for (fld_ctr = SPART_TRIPLE_FIELDS_COUNT; fld_ctr--; /* no step*/)
        {
          qm_value_t *fld_qmv = SPARP_FIELD_QMV_OF_QM(qm,fld_ctr);
          if (NULL == fld_qmv)
            continue;
          if (SPART_VARR_NOT_NULL & fld_qmv->qmvRange.rvrRestrictions)
            continue;
          ssg_print_where_or_and (ssg, "nullable col check");
          ssg_putchar ("gspo"[fld_ctr]); ssg_puts ("_val is not null");
        }
      for (cond_ctr = 0; cond_ctr < qm->qmAllCondCount; cond_ctr++)
        {
          ccaddr_t cond = qm->qmAllConds[cond_ctr];
          ssg_print_where_or_and (ssg, "filter of quad map");
          ssg_print_tmpl (ssg, NULL, cond, prefix, NULL, NULL, NULL_ASNAME);
        }
      if (ssg->ssg_where_l_printed)
        {
          ssg_puts (") ");
          ssg->ssg_indent++;
          ssg_newline (0);
        }
      if (two_phase_delete)
        {
          char buf[300];
          if (RDB2RDF_CODEGEN_SUB_BEFORE_DEL != subopcode)
            GPF_T;
          sprintf (buf,
            "insert soft DB.DBA.RDF_QUAD_DELETE_QUEUE (EVENT_ID,RULE_ID,QG,QS,QP,QO) values (query_instance_id(1), " BOXINT_FMT ", g_val, s_val, p_val, o_val);",
            rro->rro_rule_id );
          ssg_puts (buf);
        }
      else if (RDB2RDF_CODEGEN_SUB_BEFORE_DEL == subopcode)
        {
#if 0
          ssg_puts ("delete from DB.DBA.RDF_QUAD where G=g_val and S=s_val and P=p_val and O=o_val;");
#else
          ssg_puts ("    if (not __rdf_graph_is_in_enabled_repl (g_val))\n");
          ssg_puts ("      delete from DB.DBA.RDF_QUAD where G=g_val and S=s_val and P=p_val and O=o_val option (QUIETCAST);\n"),
          ssg_puts ("    else if (exists (select top 1 1 from DB.DBA.RDF_QUAD where G=g_val and S=s_val and P=p_val and O=o_val option (QUIETCAST)))\n");
          ssg_puts ("      {\n");
          ssg_puts ("        declare triples any;\n");
          ssg_puts ("        triples := vector (vector (s_val, p_val, o_val));\n");
          ssg_puts ("        DB.DBA.RDF_REPL_DELETE_TRIPLES (id_to_iri (g_val), triples);\n");
          ssg_puts ("        delete from DB.DBA.RDF_QUAD where G=g_val and S=s_val and P=p_val and O=o_val option (QUIETCAST);\n"),
          ssg_puts ("      }\n");
#endif
        }
      else
#if 0
        ssg_puts ("insert soft DB.DBA.RDF_QUAD (G,S,P,O) values (g_val, s_val, p_val, o_val);");
#else
        ssg_puts ("DB.DBA.RDF_QUAD_L_RDB2RDF (g_val, s_val, p_val, o_val, old_g_iid, ro_id_dict);");
#endif
      if (ssg->ssg_where_l_printed)
        ssg->ssg_indent--;
      goto close_out_of_loop_ifs_for_blockers; /* see below */
    }
  ssg_newline (0);
  ssg_puts ("for (select ");
  ssg->ssg_indent++;
  need_comma = 0;
  for (fld_ctr = SPART_TRIPLE_FIELDS_COUNT; fld_ctr--; /* no step*/)
    {
      qm_value_t *fld_qmv = SPARP_FIELD_QMV_OF_QM(qm,fld_ctr);
      if (NULL == fld_qmv)
        continue;
      if (bits_of_fields_here & (1 << fld_ctr))
        continue;
      if (need_comma++)
        ssg_putchar (',');
      ssg_newline (0);
      rdb2rdf_print_fld_expn (rro, (RDB2RDF_CODEGEN_SUB_BEFORE_DEL == subopcode), alias_no, qm, fld_qmv, prefix, ssg);
      ssg_puts (" as "); ssg_putchar ("gspo"[fld_ctr]); ssg_puts ("_local");
    }
  if (need_comma)
    ssg_newline (0);
  else
    ssg_puts (" TOP 1 1 as RDB2RDF_STUB ");
  ssg_puts ("FROM ");
  need_comma = 0;
  for (alias_ctr = 0; alias_ctr < qm->qmAllATableUseCount; alias_ctr++)
    {
      qm_atable_use_t *qmatu = ((qm_atable_use_t *)qm->qmAllATableUses) + alias_ctr;
      ccaddr_t tblalias = qmatu->qmatu_alias;
      if (!strcmp (((NULL == tblalias) ? "" : tblalias), ((NULL == alias) ? "" : alias)))
        continue;
      if (need_comma++)
        ssg_putchar (',');
      ssg_puts (qmatu->qmatu_tablename);
      ssg_puts (" AS ");
      ssg_prin_subalias (ssg, prefix, tblalias, 0);
    }
  if (!need_comma)
    ssg_puts (" DB.DBA.SYS_IDONLY_ONE AS emergency_stub");
  ssg_newline (0);
  ssg->ssg_where_l_printed = 0;
  ssg->ssg_where_l_text = " WHERE ";
  for (cond_ctr = 0; cond_ctr < qm->qmAllCondCount; cond_ctr++)
    {
      ccaddr_t cond = qm->qmAllConds[cond_ctr];
      ssg_print_where_or_and (ssg, "inter-alias join cond or filter");
      ssg_print_tmpl (ssg, NULL, cond, prefix, NULL, NULL, NULL_ASNAME);
    }
  for (fld_ctr = SPART_TRIPLE_FIELDS_COUNT; fld_ctr--; /* no step*/)
    {
      qm_value_t *fld_qmv = SPARP_FIELD_QMV_OF_QM(qm,fld_ctr);
      if (NULL == fld_qmv)
        continue;
      if (SPART_VARR_NOT_NULL & fld_qmv->qmvRange.rvrRestrictions)
        continue;
      if (bits_of_fields_here & (1 << fld_ctr))
        {
          ssg_print_where_or_and (ssg, "non-null cond (value from outer loop)");
          ssg_putchar ("gspo"[fld_ctr]); ssg_puts ("_val is not null");
        }
      else if (fld_qmv->qmvFormat->qmfMapsOnlyNullToNull)
        {
          qm_format_t *fmt = fld_qmv->qmvFormat;
          if (1 == fmt->qmfColumnCount)
            {
              ssg_print_where_or_and (ssg, "non-null cond (optimized, single col)");
              ssg_print_tmpl (ssg, fmt, " (^{tree}^ is not null)", prefix, fld_qmv, NULL, NULL_ASNAME);
            }
          else
            {
              int col_ctr;
              for (col_ctr = 0; col_ctr < fmt->qmfColumnCount; col_ctr++)
                {
                  ssg_print_where_or_and (ssg, "non-null cond (optimized, multipart)");
                  ssg_print_tmpl (ssg, fmt, "^{comma-list-begin}^ (^{alias-N-dot}^^{column-N}^ is not null)^{end}^", prefix, fld_qmv, NULL, COL_IDX_ASNAME + col_ctr); /*!!!TBD: skip check for not null of columns declared as NOT NULL */
                }
            }
        }
      else
        {
          ssg_print_where_or_and (ssg, "non-null cond (non-optimized)");
          ssg_putchar ('(');
          ssg->ssg_indent++;
          rdb2rdf_print_fld_expn (rro, (RDB2RDF_CODEGEN_SUB_BEFORE_DEL == subopcode), alias_no, qm, fld_qmv, prefix, ssg);
          ssg_putchar (')');
          ssg->ssg_indent--;
          ssg_puts (" is not null");
        }
    }
  ssg_puts (") do");
  ssg_newline (0);
  ssg_putchar ('{');
  ssg->ssg_indent++;
  ssg_newline (0);
#define NTH_FLD(n) ((bits_of_fields_here & (1 << (n))) ? x_vals[n] : x_locals[n])
  if (two_phase_delete)
    {
      if (RDB2RDF_CODEGEN_SUB_BEFORE_DEL != subopcode)
        GPF_T;
      sprintf (buf,
        "insert soft DB.DBA.RDF_QUAD_DELETE_QUEUE (EVENT_ID,RULE_ID,QG,QS,QP,QO) values (query_instance_id(1), " BOXINT_FMT ", %s, %s, %s, %s);",
        rro->rro_rule_id, NTH_FLD(0), NTH_FLD(1), NTH_FLD(2), NTH_FLD(3) );
      ssg_puts (buf);
    }
  else if (RDB2RDF_CODEGEN_SUB_BEFORE_DEL == subopcode)
    {
#if 0
      ssg_puts ("delete from DB.DBA.RDF_QUAD where ");
      for (fld_ctr = 0; fld_ctr < SPART_TRIPLE_FIELDS_COUNT; fld_ctr++)
        {
          if (fld_ctr) ssg_puts (" and ");
          ssg_putchar ("GSPO"[fld_ctr]);
          ssg_puts (" = ");
          ssg_putchar ("gspo"[fld_ctr]);
          if (bits_of_fields_here & (1 << fld_ctr))
            ssg_puts ("_val");
          else
            ssg_puts ("_local");
        }
      ssg_puts (";");
#else
      sprintf (buf, "    if (not __rdf_graph_is_in_enabled_repl (%s))\n", NTH_FLD(0));
      ssg_puts (buf);
      sprintf (buf, "      delete from DB.DBA.RDF_QUAD where G=%s and S=%s and P=%s and O=%s option (QUIETCAST);\n",
        NTH_FLD(0), NTH_FLD(1), NTH_FLD(2), NTH_FLD(3) );
      ssg_puts (buf);
      sprintf (buf, "    else if (exists (select top 1 1 from DB.DBA.RDF_QUAD where G=%s and S=%s and P=%s and O=%s option (QUIETCAST)))\n",
        NTH_FLD(0), NTH_FLD(1), NTH_FLD(2), NTH_FLD(3) );
      ssg_puts (buf);
      ssg_puts ("      {\n");
      ssg_puts ("        declare triples any;\n");
      sprintf (buf, "        triples := vector (vector (%s, %s, %s));\n", NTH_FLD(1), NTH_FLD(2), NTH_FLD(3)); ssg_puts (buf);
      sprintf (buf, "        DB.DBA.RDF_REPL_DELETE_TRIPLES (id_to_iri (%s), triples);\n", NTH_FLD(0));
      ssg_puts (buf);
      sprintf (buf, "        delete from DB.DBA.RDF_QUAD where G=%s and S=%s and P=%s and O=%s option (QUIETCAST);\n",
        NTH_FLD(0), NTH_FLD(1), NTH_FLD(2), NTH_FLD(3) ); ssg_puts (buf);
      ssg_puts ("      }\n");
#endif
    }
  else
    {
#if 0
      ssg_puts ("insert soft DB.DBA.RDF_QUAD (G,S,P,O) values (");
#else
      ssg_puts ("DB.DBA.RDF_QUAD_L_RDB2RDF (");
#endif
      for (fld_ctr = 0; fld_ctr < SPART_TRIPLE_FIELDS_COUNT; fld_ctr++)
        {
          if (fld_ctr) ssg_putchar (',');
          ssg_putchar ("gspo"[fld_ctr]);
          if (bits_of_fields_here & (1 << fld_ctr))
            ssg_puts ("_val");
          else
            ssg_puts ("_local");
        }
#if 0
      ssg_puts (");");
#else
      ssg_puts (", old_g_iid, ro_id_dict);");
#endif
    }
  ssg->ssg_indent--;
  ssg_newline (0);
  ssg_putchar ('}');
  ssg->ssg_indent--;

close_out_of_loop_ifs_for_blockers:
  while (out_of_loop_ifs_for_blockers--)
    {
      ssg->ssg_indent--;
      ssg_newline(0);
      ssg_putchar ('}');
      rdb2rdf_pop_rrvs_stack (rrc, 0);
    }
}

void
rdb2rdf_optree_codegen (rdb2rdf_ctx_t *rrc, rdb2rdf_optree_t *rro, caddr_t table_name, int opcode, int subopcode, const char *prefix, spar_sqlgen_t *ssg)
{
  int alias_no, sub_qm_rro_ctr;
  int single_use_of_single_main;
  if (!rro->rro_is_leaf)
    goto do_subtrees; /* see below */
  single_use_of_single_main = ((1 == dk_set_length (rro->rro_aliases_of_main_table)) && (1 == rro->rro_qm->qmAllATableUseCount));
  switch (subopcode)
    {
    case RDB2RDF_CODEGEN_INITIAL_SUB_SINGLE:
      if (single_use_of_single_main)
        rdb2rdf_qm_codegen (rrc, rro, table_name, opcode, subopcode, prefix, (ccaddr_t)(rro->rro_aliases_of_main_table->data), 0, ssg);
      break;
    case RDB2RDF_CODEGEN_INITIAL_SUB_MULTI:
      if (!single_use_of_single_main)
        rdb2rdf_qm_codegen (rrc, rro, table_name, opcode, subopcode, prefix, "-no-such-", RDB2RDF_MAX_ALIASES_OF_MAIN_TABLE, ssg);
      break;
    case RDB2RDF_CODEGEN_SUB_AFTER_DEL:
      rdb2rdf_qm_after_del_codegen (rrc, rro, table_name, opcode, ssg);
      break;
    default:
      alias_no = 0;
      DO_SET (ccaddr_t, alias, &(rro->rro_aliases_of_main_table))
        {
          rdb2rdf_qm_codegen (rrc, rro, table_name, opcode, subopcode, prefix, alias, alias_no, ssg);
          alias_no++;
        }
      END_DO_SET()
      break;
    }
do_subtrees:
  DO_BOX_FAST (rdb2rdf_optree_t *, sub_qm_rro, sub_qm_rro_ctr, rro->rro_subtrees)
    rdb2rdf_optree_codegen (rrc, sub_qm_rro, table_name, opcode, subopcode, prefix, ssg);
  END_DO_BOX_FAST;
}

void
rdb2rdf_print_body_begin (spar_sqlgen_t *ssg, int inserts_are_possible)
{
  ssg_puts ("{\n");
  ssg->ssg_indent = 1;
  ssg_puts ("  declare g_val, s_val, p_val, o_val any;\n");
  if (inserts_are_possible)
    ssg_puts ("  declare old_g_iid, ro_id_dict any;\n");
  ssg_puts ("  declare exit handler for sqlstate '*' {\n");
  ssg_puts ("      dbg_obj_princ ('RDB2RDF trigger fail: ', __SQL_STATE, ': ', __SQL_MESSAGE);\n");
  if (inserts_are_possible)
    ssg_puts ("      if (dict_size (ro_id_dict)) DB.DBA.RDF_OBJ_ADD_KEYWORD_FOR_GRAPH (old_g_iid, ro_id_dict);\n");
  ssg_puts ("      resignal;\n };\n");
  ssg_puts ("  declare exit handler for sqlstate '*' { dbg_obj_princ ('RDB2RDF trigger fail: ', __SQL_STATE, ': ', __SQL_MESSAGE); resignal; };\n");
  if (inserts_are_possible)
    {
      ssg_puts ("  old_g_iid := #i0;\n");
      ssg_puts ("  ro_id_dict := null;\n");
    }
}

void
rdb2rdf_print_body_end (spar_sqlgen_t *ssg, int inserts_are_possible)
{
  ssg_puts ("\n");
  if (inserts_are_possible)
    ssg_puts ("  if (dict_size (ro_id_dict)) DB.DBA.RDF_OBJ_ADD_KEYWORD_FOR_GRAPH (old_g_iid, ro_id_dict);\n");
  ssg_puts ("}\n");
}

int
rdb2rdf_codegen (rdb2rdf_ctx_t *rrc, caddr_t table_name, int opcode, dk_session_t *ses)
{
  spar_sqlgen_t ssg_place;
  spar_sqlgen_t *ssg = &ssg_place;
  caddr_t table_name_for_proc;
  caddr_t table_name_in_quotes;
  char *tail;
  int second_opcode = 0;
  int table_name_contains_quotes = 0;
  memset (ssg, 0, sizeof (spar_sqlgen_t));
  ssg->ssg_out = ses;
  rdb2rdf_reset_rrvs_stack (rrc);
  table_name_for_proc = t_box_copy (table_name);
  for (tail = table_name_for_proc; '\0' != tail[0]; tail++)
    {
      switch (tail[0])
        {
        case '.': tail[0] = '~'; continue;
        case '"': tail[0] = '`'; table_name_contains_quotes++; continue;
        }
    }
  if (table_name_contains_quotes)
    table_name_in_quotes = table_name;
  else
    table_name_in_quotes = t_box_sprintf (3 + strlen (table_name), "\"%s\"", table_name);
  switch (opcode)
    {
    case RDB2RDF_CODEGEN_INITIAL:
      ssg_puts ("create procedure DB.DBA.\"RDB2RDF_FILL__"); ssg_puts (table_name_for_proc); ssg_puts ("\" ()\n");
      rdb2rdf_print_body_begin (ssg, 1);
      ssg_puts ("  for (select * from "); ssg_puts (table_name); ssg_puts (") do\n");
      ssg_puts ("    {\n");
      ssg->ssg_indent = 3;
      rdb2rdf_push_rrvs_stack (rrc);
      rdb2rdf_optree_codegen (rrc, &(rrc->rrc_root_rro), table_name, opcode, RDB2RDF_CODEGEN_INITIAL_SUB_SINGLE, NULL, ssg);
      ssg_puts ("\n      ;\n");
      ssg_puts ("\n    }\n");
      ssg->ssg_indent = 1;
      rdb2rdf_pop_rrvs_stack (rrc, 0);
      rdb2rdf_optree_codegen (rrc, &(rrc->rrc_root_rro), table_name, opcode, RDB2RDF_CODEGEN_INITIAL_SUB_MULTI, NULL, ssg);
      rdb2rdf_print_body_end (ssg, 1);
      break;
    case RDB2RDF_CODEGEN_AFTER_INSERT:
      ssg_puts ("create trigger \"RDB2RDF_AI__"); ssg_puts (table_name_for_proc); ssg_puts ("\" after insert on "); ssg_puts (table_name_in_quotes); ssg_puts (" referencing new as \"RDF2RDB_N\"\n");
      rdb2rdf_print_body_begin (ssg, 1);
      rdb2rdf_optree_codegen (rrc, &(rrc->rrc_root_rro), table_name, opcode, RDB2RDF_CODEGEN_SUB_INS, "RDF2RDB_N", ssg);
      rdb2rdf_print_body_end (ssg, 1);
      break;
    case RDB2RDF_CODEGEN_BEFORE_UPDATE:
      ssg_puts ("create trigger \"RDB2RDF_BU__"); ssg_puts (table_name_for_proc); ssg_puts ("\" before update on "); ssg_puts (table_name_in_quotes); ssg_puts (" referencing new as \"RDF2RDB_N\", old as \"RDF2RDB_O\"\n");
      rdb2rdf_print_body_begin (ssg, 0);
      rdb2rdf_optree_codegen (rrc, &(rrc->rrc_root_rro), table_name, opcode, RDB2RDF_CODEGEN_SUB_BEFORE_DEL, "RDF2RDB_O", ssg);
      rdb2rdf_print_body_end (ssg, 0);
      break;
    case RDB2RDF_CODEGEN_AFTER_UPDATE:
      ssg_puts ("create trigger \"RDB2RDF_AU__"); ssg_puts (table_name_for_proc); ssg_puts ("\" after update on "); ssg_puts (table_name_in_quotes); ssg_puts (" referencing new as \"RDF2RDB_N\", old as \"RDF2RDB_O\"\n");
      rdb2rdf_print_body_begin (ssg, 1);
      rdb2rdf_optree_codegen (rrc, &(rrc->rrc_root_rro), table_name, opcode, RDB2RDF_CODEGEN_SUB_AFTER_DEL, "RDF2RDB_O", ssg);
      rdb2rdf_optree_codegen (rrc, &(rrc->rrc_root_rro), table_name, opcode, RDB2RDF_CODEGEN_SUB_INS, "RDF2RDB_N", ssg);
      rdb2rdf_print_body_end (ssg, 1);
      second_opcode = RDB2RDF_CODEGEN_BEFORE_UPDATE;
      break;
    case RDB2RDF_CODEGEN_BEFORE_DELETE:
      ssg_puts ("create trigger \"RDB2RDF_BD__"); ssg_puts (table_name_for_proc); ssg_puts ("\" before delete on "); ssg_puts (table_name_in_quotes); ssg_puts (" referencing old as \"RDF2RDB_O\"\n");
      rdb2rdf_print_body_begin (ssg, 0);
      rdb2rdf_optree_codegen (rrc, &(rrc->rrc_root_rro), table_name, opcode, RDB2RDF_CODEGEN_SUB_BEFORE_DEL, "RDF2RDB_O", ssg);
      rdb2rdf_print_body_end (ssg, 0);
      if (rrc->rrc_rule_count)
        second_opcode = RDB2RDF_CODEGEN_AFTER_DELETE;
      break;
    case RDB2RDF_CODEGEN_AFTER_DELETE:
      ssg_puts ("create trigger \"RDB2RDF_AD__"); ssg_puts (table_name_for_proc); ssg_puts ("\" after delete on "); ssg_puts (table_name_in_quotes); ssg_puts (" referencing old as \"RDF2RDB_O\"\n");
      rdb2rdf_print_body_begin (ssg, 0);
      rdb2rdf_optree_codegen (rrc, &(rrc->rrc_root_rro), table_name, opcode, RDB2RDF_CODEGEN_SUB_AFTER_DEL, "RDF2RDB_O", ssg);
      rdb2rdf_print_body_end (ssg, 0);
      break;
    }
  rdb2rdf_pop_rrvs_stack (rrc, 1);
  return second_opcode;
}

void
rdb2rdf_init_conflicts (rdb2rdf_ctx_t *rrc)
{
  int main_qm_ctr, other_qm_ctr, fld_ctr;
  rrc->rrc_all_qms = (quad_map_t **)t_revlist_to_array (rrc->rrc_qm_revlist);
  rrc->rrc_conflicts_of_qms = (char **)t_alloc_box (rrc->rrc_all_qm_count * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
  for (main_qm_ctr = rrc->rrc_all_qm_count; main_qm_ctr--; /* no step */)
    {
      rrc->rrc_conflicts_of_qms[main_qm_ctr] = t_alloc_box (rrc->rrc_all_qm_count + 1, DV_ARRAY_OF_POINTER);
      memset (rrc->rrc_conflicts_of_qms[main_qm_ctr], RDB2RDF_QMQM_NOT_PROVEN, rrc->rrc_all_qm_count);
      rrc->rrc_conflicts_of_qms[main_qm_ctr][rrc->rrc_all_qm_count] = '\0';
      rrc->rrc_conflicts_of_qms[main_qm_ctr][main_qm_ctr] = RDB2RDF_QMQM_SELF;
    }
  for (main_qm_ctr = rrc->rrc_all_qm_count; main_qm_ctr--; /* no step */)
    {
      quad_map_t *qm = rrc->rrc_all_qms[main_qm_ctr];
      char *main_qm_conflicts = rrc->rrc_conflicts_of_qms[main_qm_ctr];
      for (fld_ctr = 0; fld_ctr < SPART_TRIPLE_FIELDS_COUNT; fld_ctr++)
        {
          qm_value_t *fld_qmv = SPARP_FIELD_QMV_OF_QM(qm,fld_ctr);
          rdf_val_range_t *fld_const_rvr = SPARP_FIELD_CONST_RVR_OF_QM(qm,fld_ctr);
          if ((NULL == fld_qmv) && !(fld_const_rvr->rvrRestrictions & SPART_VARR_FIXED))
            {
              memset (main_qm_conflicts, RDB2RDF_QMQM_GROUPING, rrc->rrc_all_qm_count);
              for (other_qm_ctr = rrc->rrc_all_qm_count; other_qm_ctr--; /* no step */)
                rrc->rrc_conflicts_of_qms[other_qm_ctr][main_qm_ctr] = RDB2RDF_QMQM_GROUPING;
              goto next_qm; /* see below */
            }
        }
      for (other_qm_ctr = main_qm_ctr; other_qm_ctr--; /* no step */)
        {
          if (qm != rrc->rrc_all_qms[other_qm_ctr])
          continue;
          main_qm_conflicts[other_qm_ctr] = RDB2RDF_QMQM_WEIRD_SELF;
          rrc->rrc_conflicts_of_qms[other_qm_ctr][main_qm_ctr] = RDB2RDF_QMQM_WEIRD_SELF;
        }
next_qm: ;
    }
}

caddr_t
bif_sparql_rdb2rdf_impl (caddr_t * qst, caddr_t table_name, int opcode, caddr_t *graph_xlat, int rule_id_seed, int only_list_tables)
{
  caddr_t storage_name = uname_virtrdf_ns_uri_SyncToQuads;
  quad_storage_t *storage = sparp_find_storage_by_name (storage_name);
  caddr_t result = NULL;
  dk_session_t *ses1 = NULL;
  dk_session_t *ses2 = NULL;

  if (NULL == storage)
    sqlr_new_error ("22023", "SR639", "Quad storage <%.500s> does not exist or unusable", storage_name);
  MP_START ();
  QR_RESET_CTX
    {
      dk_set_t subtrees = NULL;
      int qm_ctr;
      rdb2rdf_ctx_t rrc;
      rdb2rdf_optree_t *prev_top_rro = NULL;
      memset (&rrc, 0, sizeof (rdb2rdf_ctx_t));
      rrc.rrc_rule_id_seed = rule_id_seed;
      if (NULL != graph_xlat)
        {
          rrc.rrc_graph_xlat_count = BOX_ELEMENTS (graph_xlat);
          if (rrc.rrc_graph_xlat_count % 2)
            sqlr_new_error ("22023", "SR639", "Vector of graph IRIs to translate should be of even length, not of length %d", rrc.rrc_graph_xlat_count);
          if (rrc.rrc_graph_xlat_count)
            {
              int ctr, ctrL;
              rrc.rrc_graph_xlat = (caddr_t *)t_alloc_box (rrc.rrc_graph_xlat_count * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
              for (ctr = rrc.rrc_graph_xlat_count; ctr--; /* no step */)
                {
                  caddr_t g = graph_xlat[ctr];
                  dtp_t g_dtp = DV_TYPE_OF (g);
                  if ((DV_STRING != g_dtp) && (DV_UNAME != g_dtp))
                    sqlr_new_error ("22023", "SR639", "Graph IRI should be an UTF-8 string or an UNAME");
                  rrc.rrc_graph_xlat[ctr] = t_box_dv_uname_string (g);
                }
              /* check + sort by keys */
              for (ctr = 0; ctr < rrc.rrc_graph_xlat_count; ctr += 2)
                {
                  for (ctrL = ctr - 2; 0 <= ctrL; ctrL -= 2)
                    {
                      int cmp = strcmp (rrc.rrc_graph_xlat[ctrL], rrc.rrc_graph_xlat[ctrL+2]);
                      if (!cmp)
                        sqlr_new_error ("22023", "SR639", "Graph IRI '%.100s' is used twice as a key in array of graph translations", rrc.rrc_graph_xlat[ctr]);
                      if (0 < cmp)
                        {
                          caddr_t swap;
                          swap = rrc.rrc_graph_xlat[ctrL]; rrc.rrc_graph_xlat[ctrL] = rrc.rrc_graph_xlat[ctrL+2]; rrc.rrc_graph_xlat[ctrL+2] = swap;
                          swap = rrc.rrc_graph_xlat[ctrL+1]; rrc.rrc_graph_xlat[ctrL+1] = rrc.rrc_graph_xlat[ctrL+3]; rrc.rrc_graph_xlat[ctrL+3] = swap;
                        }
                    }
                }
            }
        }
      DO_BOX_FAST (quad_map_t *, qm, qm_ctr, storage->qsUserMaps)
        {
          rdb2rdf_optree_t *qm_rro = rdb2rdf_create_optree (&rrc, &(rrc.rrc_root_rro), prev_top_rro, qm, table_name);
          if (NULL == qm_rro)
            continue;
          t_set_push (&subtrees, qm_rro);
          prev_top_rro = qm_rro;
          if ((NULL != qm_rro->rro_blockers_before_next) && qm_rro->rro_blockers_before_next->rrb_total_eclipse)
            break;
        }
      END_DO_BOX_FAST;
      rrc.rrc_root_rro.rro_subtrees = (rdb2rdf_optree_t **)t_revlist_to_array (subtrees);
      if (only_list_tables)
        {
          dk_set_t tables = NULL;
          rdb2rdf_list_tables (&(rrc.rrc_root_rro), &tables);
          result = revlist_to_array (tables);
        }
      else
        {
          if (RDB2RDF_CODEGEN_AFTER_INSERT != opcode)
            rdb2rdf_init_conflicts (&rrc);
          ses1 = strses_allocate ();
          switch (opcode)
            {
            case RDB2RDF_CODEGEN_EXPLAIN:
              rdb2rdf_optree_dump (&rrc, &(rrc.rrc_root_rro), ses1);
              rdb2rdf_ctx_dump (&rrc, ses1); /* After optree dump to fill in qmqm_conflicts */
              result = (caddr_t)ses1;
              ses1 = NULL;
              break;
            default:
              {
                int second_opcode = rdb2rdf_codegen (&rrc, table_name, opcode, ses1);
                if (second_opcode)
                  {
                    ses2 = strses_allocate ();
                    rdb2rdf_codegen (&rrc, table_name, second_opcode, ses2);
                    result = list (2, ses1, ses2);
                    ses2 = NULL;
                  }
                else
                  {
                    result = (caddr_t)ses1;
                  }
                ses1 = NULL;
                break;
              }
            }
        }
    }
  QR_RESET_CODE
    {
      du_thread_t *self = THREAD_CURRENT_THREAD;
      caddr_t err = thr_get_error_code (self);
      thr_set_error_code (self, NULL);
      POP_QR_RESET;
      MP_DONE ();
      dk_free_box ((caddr_t)ses1);
      dk_free_box ((caddr_t)ses2);
      dk_free_box (result);
      sqlr_resignal (err);
    }
  END_QR_RESET
  MP_DONE ();
  return result;
}

caddr_t
bif_sparql_rdb2rdf_codegen (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args, const char *fname)
{
  int argcount = BOX_ELEMENTS (args);
  caddr_t table_name = bif_string_arg (qst, args, 0, "sparql_rdb2rdf_codegen");
  int opcode = bif_long_range_arg (qst, args, 1, "sparql_rdb2rdf_codegen", RDB2RDF_CODEGEN_EXPLAIN, COUNTOF__RDB2RDF_CODEGEN);
  caddr_t *graph_xlat = ((3 <= argcount) ?
    bif_array_of_pointer_arg (qst, args, 2, "sparql_rdb2rdf_codegen") : NULL );
  int rule_id_seed = (4 <= argcount) ?
    bif_long_arg (qst, args, 3, "sparql_rdb2rdf_codegen") :
    (adler32_of_buffer ((unsigned char *)table_name, box_length (table_name)-1) ^ opcode);
  return bif_sparql_rdb2rdf_impl (qst, table_name, opcode, graph_xlat, rule_id_seed, 0);
}

caddr_t
bif_sparql_rdb2rdf_list_tables (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args, const char *fname)
{
  int opcode = bif_long_range_arg (qst, args, 0, "sparql_rdb2rdf_list_tables", RDB2RDF_CODEGEN_EXPLAIN, COUNTOF__RDB2RDF_CODEGEN);
  return bif_sparql_rdb2rdf_impl (qst, NULL, opcode, NULL, 0 /*fake*/, 1);
}

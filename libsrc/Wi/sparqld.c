/*
 *  $Id$
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

#include "sparql2sql.h"
#include "sqlparext.h"
/*#include "arith.h"
#include "sqlcmps.h"*/
#ifdef __cplusplus
extern "C" {
#endif
#include "sparql_p.h"
#ifdef __cplusplus
}
#endif
#ifdef __cplusplus
extern "C" {
#endif
#include "xmlparser.h"
#include "xmlparser_impl.h"
#ifdef __cplusplus
}
#endif
#include "http.h"
#include "date.h"
/*#include "xml_ecm.h"*/

void ssg_sdprin_literal (spar_sqlgen_t *ssg, SPART *tree)
{
  switch (DV_TYPE_OF (tree))
    {
    case DV_ARRAY_OF_POINTER:
      if (SPAR_LIT != tree->type)
        spar_sqlprint_error ("ssg_" "sdprin_literal: non-literal vector as argument");
      ssg_sdprin_literal (ssg, (SPART *)(tree->_.lit.val));
      if (DV_STRING != DV_TYPE_OF (tree->_.lit.val))
        return;
      if (NULL != tree->_.lit.datatype)
        {
          ssg_puts ("^^");
          ssg_sdprin_qname (ssg, (SPART *)(tree->_.lit.datatype));
        }
      if (NULL != tree->_.lit.language)
        {
          ssg_putchar ('@');
          ssg_puts (tree->_.lit.language);
        }
      return;
    case DV_STRING:
      ssg_putchar ('"');
      dks_esc_write (ssg->ssg_out, (caddr_t)tree, box_length (tree)-1, CHARSET_UTF8, CHARSET_UTF8, DKS_ESC_TTL_DQ);
      ssg_putchar ('"');
      return;
    case DV_UNAME:
      ssg_sdprin_qname (ssg, tree);
      return;
    case DV_DATE: case DV_TIME: case DV_DATETIME:
      {
        char temp[40];
        caddr_t type_uri;
        dt_to_iso8601_string ((ccaddr_t)tree, temp, sizeof (temp));
        switch (DT_DT_TYPE(tree))
          {
          case DT_TYPE_DATE: type_uri = uname_xmlschema_ns_uri_hash_date; break;
          case DT_TYPE_TIME: type_uri = uname_xmlschema_ns_uri_hash_time; break;
          default : type_uri = uname_xmlschema_ns_uri_hash_dateTime;
          }
        ssg_putchar ('"');
        ssg_puts (temp);
        ssg_puts ("\"^^<");
        ssg_puts (type_uri);
        ssg_putchar ('>');
        return;
      }
    default:
      ssg_print_box_as_sql_atom (ssg, (caddr_t)tree, SQL_ATOM_UTF8_ONLY);
      return;
    }
}

void ssg_sdprin_qname (spar_sqlgen_t *ssg, SPART *tree)
{
  caddr_t str;
  unsigned char *tail, *end;
  if (DV_ARRAY_OF_POINTER == DV_TYPE_OF (tree))
    {
      if (SPAR_QNAME != tree->type)
        spar_sqlprint_error ("ssg_" "sdprin_qname: non-QName vector as argument");
      str = tree->_.qname.val;
    }
  else
    str = (caddr_t)tree;
  end = (unsigned char *)str + (box_length (str) - 1);
  for (tail = (unsigned char *)str; tail < end; tail++)
    if ((tail[0] < 0x20) || strchr ("<>\"{}|^`\\", tail[0]))
      spar_sqlprint_error ("Unable to print a QName that contain illegal characters as an IRI_REF");
/*!!!TBD: pretty-print with namespaces */
  ssg_putchar ('<');
#if 0
  dks_esc_write (ssg->ssg_out, str, box_length (str)-1, CHARSET_UTF8, CHARSET_UTF8, DKS_ESC_TTL_IRI);
#else
  ssg_puts (str);
#endif
  ssg_putchar ('>');
}

void ssg_sdprint_tree_list (spar_sqlgen_t *ssg, SPART **trees, char delim)
{
  int ctr;
  DO_BOX_FAST (SPART *, tree, ctr, trees)
    {
      if (('\0' != delim) && (0 != ctr))
        {
          if ('\n' == delim)
            ssg_newline (0);
          else
            ssg_putchar (delim);
        }
      ssg_sdprint_tree (ssg, tree);
    }
  END_DO_BOX_FAST;
}

const char *
ssg_sd_opname (sparp_t *sparp, ptrlong opname, int is_op)
{

  if (is_op)
    switch (opname)
    {
    case BOP_AND: return "&&";
    case BOP_OR: return "||";
    case BOP_NOT: return "!";
    case SPAR_BOP_EQ: spar_internal_error (sparp, "special assignment can not be rendered in SPARQL text");
    case BOP_EQ: return "=";
    case BOP_NEQ: return "!=";
    case BOP_LT: return "<";
    case BOP_LTE: return "<=";
    case BOP_GT: return ">";
    case BOP_GTE: return ">=";
    /*case BOP_LIKE: Like is built-in in SPARQL, not a BOP! */
    case BOP_SAME: return "==";
    case BOP_NSAME: return "!==";
    case BOP_PLUS: return "+";
    case BOP_MINUS: return "-";
    case BOP_TIMES: return "*";
    case BOP_DIV: return "DIV";
    case BOP_MOD: return "MOD";
    }

  switch (opname)
    {
    /*case _LBRA: return "quad mapping parent group name";*/
    case ASC_L: return "ASC";
    case ASK_L: return "ASK";
    case BOUND_L: return "BOUND";
    case CONSTRUCT_L: return "CONSTRUCT";
    /*case CREATE_L: return "quad mapping name";*/
    case DATATYPE_L: return "DATATYPE";
    case DESC_L: return "DESC";
    case DESCRIBE_L: return "DESCRIBE";
    case DISTINCT_L: return "SELECT DISTINCT";
    case false_L: return "false";
    case FILTER_L: return "FILTER";
    /* case FROM_L: return "FROM"; */
    /* case GRAPH_L: return "GRAPH"; */
    case IN_L: return "IN";
    case IRI_L: return "IRI";
    case LANG_L: return "LANG";
    case LIKE_L: return "LIKE";
    case LIMIT_L: return "LIMIT";
    /* case NAMED_L: return "FROM NAMED"; */
    case NIL_L: return "NIL";
    /* case OBJECT_L: return "OBJECT"; */
    case OFFBAND_L: return "OFFBAND";
    case OFFSET_L: return "OFFSET";
    case OPTIONAL_L: return "OPTIONAL";
    case ORDER_L: return "ORDER";
    /* case PREDICATE_L: return "PREDICATE"; */
    /* case PREFIX_L: return "PREFIX"; */
    case SCORE_L: return "SCORE";
    case SCORE_LIMIT_L: return "SCORE_LIMIT";
    case SELECT_L: return "SELECT";
    /* case SUBJECT_L: return "SUBJECT"; */
    case true_L: return "true";
    case UNION_L: return "UNION";
    /* case WHERE_L: return "WHERE"; */

#if 0
    case SPAR_BLANK_NODE_LABEL: return "blank node label";
    case SPAR_BUILT_IN_CALL: return "built-in call";
    case SPAR_FUNCALL: return "function call";
    case SPAR_GP: return "group pattern";
    case SPAR_LIT: return "lit";
    case SPAR_QNAME: return "QName";
    /*case SPAR_QNAME_NS: return "QName NS";*/
    case SPAR_REQ_TOP: return "SPARQL query";
    case SPAR_VARIABLE: return "Variable";
    case SPAR_TRIPLE: return "Triple";
#endif
  }
  /*spar_sqlprint_error (t_box_sprintf (200, "ssg_" "sd_opname: unknown/unsupported opcode (%d, %s)", opname, spart_dump_opname (opname, is_op)));*/
  return NULL;
}

int
ssg_fields_are_equal (SPART *tree1, SPART *tree2)
{
  int type1, type2;
  if (tree1 == tree2)
    return 1;
  type1 = SPART_TYPE (tree1);
  type2 = SPART_TYPE (tree2);
  if (type1 != type2)
    return 0;
  switch (type1)
    {
    case SPAR_VARIABLE: case SPAR_BLANK_NODE_LABEL:
      return !strcmp (tree1->_.var.vname, tree2->_.var.vname);
    case SPAR_QNAME:
      return !strcmp (tree1->_.qname.val, tree2->_.qname.val);
    case SPAR_LIT:
      return box_hash ((caddr_t)tree1) == box_hash ((caddr_t)tree2);
    }
  GPF_T1 ("ssg_" "fields_are_equal: unsupported tree type");
  return 0;
}

void
ssg_sdprin_varname (spar_sqlgen_t *ssg, ccaddr_t vname)
{
  if (NULL != ssg->ssg_wrapping_sinv)
    {
      int paramctr;
      DO_BOX_FAST (caddr_t, param_vname, paramctr, ssg->ssg_wrapping_sinv->_.sinv.param_varnames)
        {
          char buf[20];
          if (strcmp (vname, param_vname))
            continue;
          if (SSG_SD_GLOBALS & ssg->ssg_sd_flags)
            {
              sprintf (buf, "?:%d", paramctr+1);
              ssg_puts (buf);
            }
          else
            {
              t_set_push (&(ssg->ssg_param_pos_set), (void *)((ptrlong)(strses_length (ssg->ssg_out))));
              t_set_push (&(ssg->ssg_param_pos_set), (void *)((ptrlong)(paramctr+1)));
              sprintf (buf, "?!%06d", paramctr+1);
              ssg_puts (buf);
            }
          return;
        }
      END_DO_BOX_FAST;
    }
  if (('_' == vname[0]) && ':' == vname[1])
    {
      ssg_puts (vname);
      return;
    }
  if (':' == vname[0])
    {
      if (!(SSG_SD_GLOBALS & ssg->ssg_sd_flags))
        spar_error (ssg->ssg_sparp, "%.100s does not support SPARQL-BI extensions (like external parameters) so SPARQL query can not be composed", ssg->ssg_sd_service_name);
    }
  else if ((/* strchr (vname, '_') || --- Bug 14613 */ strchr (vname, '"') || strchr (vname, ':')) && !(SSG_SD_BI & ssg->ssg_sd_flags))
    spar_error (ssg->ssg_sparp, "%.100s does not support SPARQL-BI extensions (say, SQL-like names of variables) so SPARQL query can not be composed", ssg->ssg_sd_service_name);
  ssg_putchar ('?');
  ssg_puts (vname);
  return;
}

int ssg_filter_is_default_graph_condition (SPART *filt)
{
  switch (SPART_TYPE (filt))
    {
    case SPAR_BUILT_IN_CALL:
      return ((IN_L == filt->_.builtin.btype) && SPART_IS_DEFAULT_GRAPH_BLANK (filt->_.builtin.args[0]));
    case BOP_EQ:
      return SPART_IS_DEFAULT_GRAPH_BLANK (filt->_.bin_exp.left);
    }
  return 0;
}

void
ssg_sdprint_equiv_restrs (spar_sqlgen_t *ssg, sparp_equiv_t *eq)
{
  ptrlong mixed_field_restr = 0;
  int ctr;
  const char *builtin_name = NULL;
  if ((SPART_VARR_CONFLICT & eq->e_rvr.rvrRestrictions) && (0 != eq->e_gspo_uses))
    {
      ssg_newline (0);
      ssg_puts (" FILTER (0 != 0)");
      return;
    }
  if (!(SPART_VARR_NOT_NULL & eq->e_rvr.rvrRestrictions))
    return;
  for (ctr = eq->e_var_count; ctr--; /*no step*/ )
    {
      SPART *v = eq->e_vars[ctr];
      SPART *tr;
      if (NULL == v->_.var.tabid)
        continue;
      tr = sparp_find_triple_of_var_or_retval (ssg->ssg_sparp, eq->e_gp, v, 1);
      if (OPTIONAL_L == tr->_.triple.subtype)
        continue;
      if (SPART_TRIPLE_FIELDS_COUNT <= v->_.var.tr_idx)
        continue;
      if (1 == BOX_ELEMENTS (tr->_.triple.tc_list))
        {
          quad_map_t *qm;
          qm_value_t *qmv;
          qm = tr->_.triple.tc_list[0]->tc_qm;
          qmv = SPARP_FIELD_QMV_OF_QM (qm, v->_.var.tr_idx);
          if (NULL != qmv)
            mixed_field_restr |= qmv->qmvRange.rvrRestrictions | qmv->qmvFormat->qmfValRange.rvrRestrictions;
          else
            {
              caddr_t c = SPARP_FIELD_CONST_OF_QM (qm, v->_.var.tr_idx);
              if (DV_UNAME == DV_TYPE_OF (c))
                mixed_field_restr |= (SPART_VARR_NOT_NULL | SPART_VARR_IS_REF | SPART_VARR_IS_IRI);
              else
                mixed_field_restr |= SPART_VARR_NOT_NULL | SPART_VARR_IS_LIT;
            }
        }
      else
        {
          switch (v->_.var.tr_idx)
            {
            case SPART_TRIPLE_PREDICATE_IDX:
              mixed_field_restr |= (SPART_VARR_NOT_NULL | SPART_VARR_IS_REF | SPART_VARR_IS_IRI);
              break;
            case SPART_TRIPLE_SUBJECT_IDX: case SPART_TRIPLE_GRAPH_IDX:
              mixed_field_restr |= (SPART_VARR_NOT_NULL | SPART_VARR_IS_REF);
              break;
            case SPART_TRIPLE_OBJECT_IDX:
              mixed_field_restr |= SPART_VARR_NOT_NULL;
              break;
            }
        }
    }
  if (NULL != eq->e_subvalue_idxs)
    {
      ptrlong gp_subtype = eq->e_gp->_.gp.subtype;
      ptrlong sub_restr = ((UNION_L == gp_subtype) ? ~0L : 0L);
      DO_BOX_FAST (ptrlong, sub_idx, ctr, eq->e_subvalue_idxs)
        {
          sparp_equiv_t *sub = SPARP_EQUIV (ssg->ssg_sparp, sub_idx);
          if (SPART_VARR_CONFLICT & sub->e_rvr.rvrRestrictions)
            {
              if (UNION_L == gp_subtype)
                continue;
              break;
            }
          if (!(SPART_VARR_NOT_NULL & sub->e_rvr.rvrRestrictions))
            continue;
          if (UNION_L == gp_subtype)
            sub_restr &= sub->e_rvr.rvrRestrictions;
          else
            sub_restr |= sub->e_rvr.rvrRestrictions;
        }
      END_DO_BOX_FAST;
      mixed_field_restr |= sub_restr;
    }
  if ((SPART_VARR_FIXED & eq->e_rvr.rvrRestrictions) && !(SPART_VARR_FIXED & mixed_field_restr))
    {
      ssg_newline (0);
      ssg_puts (" FILTER (");
      ssg_sdprin_varname (ssg, eq->e_varnames[0]);
      ssg_puts (" = ");
      ssg_sdprint_tree (ssg, (SPART *)(eq->e_rvr.rvrFixedValue));
      ssg_puts (")");
      goto end_builtin_checks;
    }
  if ((SPART_VARR_IS_LIT & eq->e_rvr.rvrRestrictions) && !(SPART_VARR_IS_LIT & mixed_field_restr))
    builtin_name = "isLITERAL";
  else if ((SPART_VARR_IS_IRI & eq->e_rvr.rvrRestrictions) && !(SPART_VARR_IS_IRI & mixed_field_restr))
    builtin_name = "isIRI";
  else if ((SPART_VARR_IS_BLANK & eq->e_rvr.rvrRestrictions) && !(SPART_VARR_IS_BLANK & mixed_field_restr))
    builtin_name = "isBLANK";
  else if ((SPART_VARR_IS_REF & eq->e_rvr.rvrRestrictions) && !(SPART_VARR_IS_REF & mixed_field_restr))
    builtin_name = "!isLITERAL";
  else if ((SPART_VARR_NOT_NULL & eq->e_rvr.rvrRestrictions) && !(SPART_VARR_NOT_NULL & mixed_field_restr))
    builtin_name = "BOUND";
  if (NULL != builtin_name)
    {
      ssg_newline (0);
      ssg_puts (" FILTER (");
      ssg_puts (builtin_name);
      ssg_puts (" (");
      ssg_sdprin_varname (ssg, eq->e_varnames[0]);
      ssg_puts (" ))");
    }
end_builtin_checks:
  for (ctr = BOX_ELEMENTS (eq->e_varnames); 0 < --ctr; /*no step*/)
    {
      ssg_newline (0);
      ssg_puts (" FILTER (");
      ssg_sdprin_varname (ssg, eq->e_varnames[0]);
      ssg_puts (" = ");
      ssg_sdprin_varname (ssg, eq->e_varnames[ctr]);
      ssg_puts (")");
    }
}

void ssg_sdprint_tree (spar_sqlgen_t *ssg, SPART *tree)
{
  int ctr = 0, count;
  int tree_type;
  if (NULL == tree)
    spar_sqlprint_error ("ssg_" "sdprint_tree(): NULL tree");
  if (DV_ARRAY_OF_POINTER != DV_TYPE_OF (tree))
    {
      ssg_putchar (' ');
      ssg_sdprin_literal (ssg, tree);
      return;
    }
  tree_type = SPART_TYPE (tree);
  switch (tree_type)
    {
    case SPAR_ALIAS:
      {
        int old_parens = ((SSG_SD_VIRTSPECIFIC & ssg->ssg_sd_flags) && !(SSG_SD_SPARQL11_DRAFT & ssg->ssg_sd_flags));
        if (!(SSG_SD_BI_OR_SPARQL11_DRAFT & ssg->ssg_sd_flags))
          {
            ssg_sdprint_tree (ssg, tree->_.alias.arg);
            return;
          }
        ssg_putchar (' ');
        ssg_puts (" (");
        ssg->ssg_indent++;
        ssg_sdprint_tree (ssg, tree->_.alias.arg);
        if (old_parens)
          {
            ssg_puts (")");
            ssg->ssg_indent--;
          }
        ssg_puts (" AS ?");
        ssg_puts (tree->_.alias.aname);
        if (!old_parens)
          {
            ssg_puts (")");
            ssg->ssg_indent--;
          }
        return;
      }
    case SPAR_BLANK_NODE_LABEL: case SPAR_VARIABLE:
      {
        ssg_putchar (' ');
        ssg_sdprin_varname (ssg, tree->_.var.vname);
        return;
      }
    case SPAR_BUILT_IN_CALL:
      {
        ssg_putchar (' ');
        switch (tree->_.builtin.btype)
          {
          case LIKE_L:
            if (!(SSG_SD_LIKE & ssg->ssg_sd_flags))
              spar_error (ssg->ssg_sparp, "%.100s does not support LIKE operator so SPARQL query can not be composed", ssg->ssg_sd_service_name);
            ssg_puts (" (");
            ssg->ssg_indent++;
            ssg_sdprint_tree (ssg, tree->_.builtin.args[0]);
            ssg_puts (" LIKE");
            ssg_sdprint_tree (ssg, tree->_.builtin.args[1]);
            ssg_puts (")");
            ssg->ssg_indent--;
            return;
          case IN_L:
            if (SSG_SD_IN & ssg->ssg_sd_flags)
              {
                int argctr, argcount;
                ssg_sdprint_tree (ssg, tree->_.builtin.args[0]);
                ssg_puts (" IN (");
                ssg->ssg_indent++;
                argcount = BOX_ELEMENTS (tree->_.builtin.args);
                for (argctr = 1; argctr < argcount; argctr++)
                  {
                    if (argctr > 1)
                      ssg_putchar (',');
                    ssg_sdprint_tree (ssg, tree->_.builtin.args[argctr]);
                  }
                ssg_putchar (')');
                ssg->ssg_indent--;
              }
            else
              {
                int argctr, argcount;
                ssg_puts (" ((");
                ssg->ssg_indent += 2;
                argcount = BOX_ELEMENTS (tree->_.builtin.args);
                for (argctr = 1; argctr < argcount; argctr++)
                  {
                    if (argctr > 1)
                      ssg_puts (") || (");
                    ssg_sdprint_tree (ssg, tree->_.builtin.args[0]);
                    ssg_puts (" =");
                    ssg_sdprint_tree (ssg, tree->_.builtin.args[argctr]);
                  }
                ssg_puts ("))");
                ssg->ssg_indent -= 2;
              }
            return;
          default:
            {
              const sparp_bif_desc_t *sbd = sparp_bif_descs + tree->_.builtin.desc_ofs;
              ssg_puts (sbd->sbd_name);
              ssg_putchar ('(');
              ssg->ssg_indent++;
              ssg_sdprint_tree_list (ssg, tree->_.builtin.args, ',');
              ssg_putchar (')');
              ssg->ssg_indent--;
              return;
            }
          }
      }
    case SPAR_FUNCALL:
      {
        caddr_t fname = tree->_.funcall.qname;
        ssg_putchar (' '); /* 01234567890123 */
        if (!strncmp (fname, "SPECIAL::bif:", 13))
          {
static const char *sparql11aggregates[] = { "AVG", "COUNT", "GROUP_CONCAT", "MAX", "MIN", "SAMPLE", "SUM" };
            if (ECM_MEM_NOT_FOUND != ecm_find_name (fname+13, sparql11aggregates, sizeof (sparql11aggregates)/sizeof (char *), sizeof (char *)))
              {
                if (!(SSG_SD_BI_OR_SPARQL11_DRAFT & ssg->ssg_sd_flags))
                  spar_error (ssg->ssg_sparp, "%.100s does not support %s aggregate function so SPARQL query can not be composed", ssg->ssg_sd_service_name, fname+13);
                ssg_puts (fname+13);
                goto fname_printed; /* see below */
              }
          }
        if (!strncmp (fname, "xpath:", 6))
          {
            char *colon = strrchr (fname + 6, ':');
            if (NULL == colon)
              fname = t_box_dv_short_string (fname + 6);
            else
              {
                colon[0] = '\0';
                fname = t_box_sprintf (400, "%.200s%.100s", fname+6, colon+1);
                colon[0] = ':';
              }
          }
        ssg_sdprin_qname (ssg, (SPART *)(fname));
fname_printed:
        ssg_putchar ('(');
        ssg->ssg_indent++;
        ssg_sdprint_tree_list (ssg, tree->_.funcall.argtrees, ',');
        ssg_putchar (')');
        ssg->ssg_indent--;
        return;
      }
    case SPAR_GP:
      {
        if (ssg->ssg_sd_forgotten_dot)
          {
            ssg_puts (" .");
            ssg->ssg_indent -= 4;
            ssg->ssg_sd_forgotten_dot = 0;
          }
        if (ssg->ssg_sd_forgotten_graph)
          {
            ssg_puts (" }");
            ssg->ssg_indent -= 2;
            ssg->ssg_sd_forgotten_graph = 0;
            ssg->ssg_sd_graph_gp_nesting--;
          }
        ssg_newline (0);
        t_set_push (&(ssg->ssg_sd_outer_gps), tree);
#if 0 /* I can't understand it */
        ssg->ssg_sd_outer_gps = NULL; /* The first triple pattern in the group can not use ';' or ',' shorthand */
#endif
        switch (tree->_.gp.subtype)
          {
          case SELECT_L:
            if (!(SSG_SD_BI & ssg->ssg_sd_flags))
              spar_error (ssg->ssg_sparp, "%.100s does not support SPARQL-BI extensions (like nested SELECT) so SPARQL query can not be composed", ssg->ssg_sd_service_name);
            if (NULL == ssg->ssg_sd_outer_gps->data)
              {
                ssg_puts (" (");
                ssg->ssg_indent++;
              }
            else
              {
                ssg_puts ("  { ");
                ssg->ssg_indent += 2;
              }
            ssg_sdprint_tree (ssg, tree->_.gp.subquery);
            if (NULL == ssg->ssg_sd_outer_gps->data)
              {
                ssg_puts (" )");
                ssg->ssg_indent--;
              }
            else
              {
                ssg_puts (" }");
                ssg->ssg_indent -= 2;
              }
            return;
          case UNION_L:
            DO_BOX_FAST (SPART *, sub, ctr, tree->_.gp.members)
              {
                if (0 != ctr)
                  {
                    ssg_newline (0);
                    ssg_puts ("UNION ");
                  }
                ssg->ssg_indent++;
                ssg_sdprint_tree (ssg, sub);
                ssg->ssg_indent--;
              }
            END_DO_BOX_FAST;
            return;
          case OPTIONAL_L: ssg_puts (" OPTIONAL"); break;
          case WHERE_L: ssg_puts (" WHERE"); break;
          case SERVICE_L:
            {
              SPART *sinv = sparp_get_option (ssg->ssg_sparp, tree->_.gp.options, SPAR_SERVICE_INV);
              int ctr, count;
              ssg_puts (" SERVICE ");
              ssg_sdprin_qname (ssg, (SPART *)(sinv->_.sinv.endpoint));
              ssg_puts (" (");
              DO_BOX_FAST (SPART *, var, ctr, sinv->_.sinv.param_varnames)
                {
                  ssg_puts (" IN ");
                  ssg_sdprint_tree (ssg, var);
                }
              END_DO_BOX_FAST;
              count = BOX_ELEMENTS_0 (sinv->_.sinv.defines);
              for (ctr = 0; ctr < count; ctr += 2)
                {
                  caddr_t name = (caddr_t)(sinv->_.sinv.defines[ctr]);
                  SPART ***vals = (SPART ***)(sinv->_.sinv.defines[ctr+1]);
                  int valctr;
                  if (!strcmp (name, "lang:dialect"))
                    continue;
                  ssg_puts (" DEFINE ");
                  ssg_puts (name);
                  DO_BOX_FAST (SPART **, val, valctr, vals)
                    {
                      if (valctr) ssg_putchar (',');
                      ssg_sdprint_tree (ssg, val[1]);
                    }
                  END_DO_BOX_FAST;
                }
              ssg_puts (") ");
              break;
            }
          case 0: ssg_putchar (' '); break;
          }
        ssg_puts (" { ");
        ssg->ssg_indent += 2;
#if 0
        if ((0 == BOX_ELEMENTS_0 (tree->_.gp.members)) && (NULL == tree->_.gp.subquery))
          {
            ssg_puts ("<nosuch://S> <nosuch://P> <nosuch://O> . FILTER (0 != 0) .");
          }
        else
#endif
          {
            DO_BOX_FAST (SPART *, sub, ctr, tree->_.gp.members)
              {
                ssg_sdprint_tree (ssg, sub);
              }
            END_DO_BOX_FAST;
          }
        if (ssg->ssg_sd_forgotten_dot)
          {
            ssg_puts (" .");
            ssg->ssg_indent -= 4;
            ssg->ssg_sd_forgotten_dot = 0;
          }
        if (ssg->ssg_sd_forgotten_graph)
          {
            ssg_puts (" }");
            ssg->ssg_indent -= 2;
            ssg->ssg_sd_forgotten_graph = 0;
            ssg->ssg_sd_graph_gp_nesting--;
          }
        t_set_push (&(ssg->ssg_sd_outer_gps), NULL);
        SPARP_FOREACH_GP_EQUIV (ssg->ssg_sparp, tree, ctr, eq)
          {
            ssg_sdprint_equiv_restrs (ssg, eq);
          }
        END_SPARP_FOREACH_GP_EQUIV;
        count = BOX_ELEMENTS (tree->_.gp.filters) - tree->_.gp.glued_filters_count;
        for (ctr = 0; ctr < count; ctr++)
          {
            SPART * filt = tree->_.gp.filters [ctr];
            if (ssg_filter_is_default_graph_condition (filt))
              continue;
            ssg_newline (0);
            ssg_puts ("FILTER (");
            ssg->ssg_indent++;
            ssg_sdprint_tree (ssg, filt);
            ssg_puts (" )");
            ssg->ssg_indent--;
          }
        if (OPTIONAL_L == tree->_.gp.subtype)
          {
            SPART *outer_gp = ssg->ssg_sd_outer_gps->data;
            if (NULL != outer_gp)
              {
                count = BOX_ELEMENTS (outer_gp->_.gp.filters);
                for (ctr = count - outer_gp->_.gp.glued_filters_count; ctr < count; ctr++)
                  {
                    SPART * filt = outer_gp->_.gp.filters [ctr];
                    ssg_newline (0);
                    ssg_puts ("FILTER (");
                    ssg->ssg_indent++;
                    ssg_sdprint_tree (ssg, filt);
                    ssg->ssg_indent--;
                    ssg_puts (" )");
                  }
              }
          }
        t_set_pop (&(ssg->ssg_sd_outer_gps));
        t_set_pop (&(ssg->ssg_sd_outer_gps));
        ssg_puts (" }");
        ssg->ssg_indent -= 2;
/*!!!TBD print tree->_.gp.options */
        return;
      }
    case SPAR_LIT:
      {
        ssg_putchar (' ');
        ssg_sdprin_literal (ssg, tree);
        return;
      }
    case SPAR_QNAME:
      {
        ssg_putchar (' ');
        ssg_sdprin_qname (ssg, tree);
        return;
      }
    case SPAR_REQ_TOP:
      {
        int retctr;
        int srcctr, srccount = BOX_ELEMENTS (tree->_.req_top.sources);
        caddr_t saved_ssg_sd_single_from = ssg->ssg_sd_single_from;
        int saved_ssg_sd_graph_gp_nesting = ssg->ssg_sd_graph_gp_nesting;
        int from_count = 0;
        ssg->ssg_sd_single_from = NULL;
        ssg->ssg_sd_graph_gp_nesting = 0;
        if ((NULL != tree->_.req_top.storage_name) && (tree->_.req_top.storage_name != uname_virtrdf_ns_uri_DefaultServiceStorage))
          {
            if (!(SSG_SD_VIRTSPECIFIC & ssg->ssg_sd_flags))
              spar_error (ssg->ssg_sparp, "%.100s does not support Virtuoso-specific extensions (like define input:storage) so SPARQL query can not be composed", ssg->ssg_sd_service_name);
            ssg_puts ("define input:storage <");
            ssg_puts (tree->_.req_top.storage_name);
            ssg_puts ("> ");
          }
        switch (tree->_.req_top.subtype)
          {
          case ASK_L: ssg_puts ("ASK "); break;
          case DISTINCT_L: ssg_puts ("SELECT DISTINCT "); break;
          default: ssg_puts ("SELECT "); break;
          }
        DO_BOX_FAST (SPART *, arg, retctr, tree->_.req_top.retvals)
          {
            ptrlong arg_type = SPART_TYPE (arg);
            if (0 != ctr)
              ssg_newline (0);
            while ((SPAR_ALIAS == arg_type) && !((SSG_SD_BI & ssg->ssg_sd_flags)))
              {
                arg = arg->_.alias.arg;
                arg_type = SPART_TYPE (arg);
              }
            switch (arg_type)
              {
              case SPAR_VARIABLE: case SPAR_BLANK_NODE_LABEL: case SPAR_ALIAS:
                ssg_sdprint_tree (ssg, arg);
                break;
              default:
                if (!(SSG_SD_BI & ssg->ssg_sd_flags))
                  spar_error (ssg->ssg_sparp, "%.100s does not support SPARQL-BI extensions (like expressions in result list) so SPARQL query can not be composed", ssg->ssg_sd_service_name);
                ssg_putchar ('(');
                ssg->ssg_indent++;
                ssg_sdprint_tree (ssg, arg);
                ssg_putchar (')');
                ssg->ssg_indent--;
                break;
              }
          }
        END_DO_BOX_FAST;
        for (srcctr = 0; srcctr < srccount; srcctr++)
          {
            SPART *src = tree->_.req_top.sources[srcctr];
            ssg_newline (0);
            ssg_sdprint_tree (ssg, src);
            if (SPART_GRAPH_MIN_NEGATION < src->_.graph.subtype)
              continue;
            from_count++;
            if ((1 == from_count) && (SPART_GRAPH_FROM == src->_.graph.subtype))
              ssg->ssg_sd_single_from = src->_.graph.iri;
            else
              ssg->ssg_sd_single_from = NULL;
          }
        ssg_sdprint_tree (ssg, tree->_.req_top.pattern);
        if (ASK_L != tree->_.req_top.subtype)
          {
            SPART *lim = tree->_.req_top.limit;
            SPART *ofs = tree->_.req_top.offset;
            if (0 != BOX_ELEMENTS_0 (tree->_.req_top.groupings))
              {
                ssg_newline (0);
                ssg_puts ("GROUP BY ");
                ssg_sdprint_tree_list (ssg, tree->_.req_top.groupings, ' ');
              }
            if (NULL != tree->_.req_top.having)
              {
                ssg_newline (0);
                ssg_puts ("HAVING ");
                ssg_sdprint_tree (ssg, tree->_.req_top.having);
              }
            if (0 != BOX_ELEMENTS_0 (tree->_.req_top.order)
              && ((SELECT_L == tree->_.req_top.subtype) || (DISTINCT_L == tree->_.req_top.subtype) || (NULL != lim) || (NULL != ofs)) )
              {
                ssg_newline (0);
                ssg_puts ("ORDER BY ");
                ssg_sdprint_tree_list (ssg, tree->_.req_top.order, ' ');
              }
            if (NULL != lim)
              {
                if ((DV_LONG_INT != DV_TYPE_OF (lim)) && !(SSG_SD_BI & ssg->ssg_sd_flags))
                  spar_error (ssg->ssg_sparp, "%.100s does not support SPARQL-BI extensions (like expression in LIMIT clause) so SPARQL query can not be composed", ssg->ssg_sd_service_name);
                ssg_newline (0);
                ssg_puts ("LIMIT");
                ssg_sdprint_tree (ssg, lim);
              }
            if (NULL != ofs)
              {
                if ((DV_LONG_INT != DV_TYPE_OF (ofs)) && !(SSG_SD_BI & ssg->ssg_sd_flags))
                  spar_error (ssg->ssg_sparp, "%.100s does not support SPARQL-BI extensions (like expression in OFFSET clause) so SPARQL query can not be composed", ssg->ssg_sd_service_name);
                ssg_newline (0);
                ssg_puts ("OFFSET");
                ssg_sdprint_tree (ssg, ofs);
              }
          }
        ssg->ssg_sd_single_from = saved_ssg_sd_single_from;
        ssg->ssg_sd_graph_gp_nesting = saved_ssg_sd_graph_gp_nesting;
        return;
      }
    case SPAR_TRIPLE:
      {
        SPART *curr_graph = tree->_.triple.tr_graph;
        int new_g_is_dflt = 0;
        int should_close_graph, need_new_graph, place_qm;
        int option_count;
        if (ssg->ssg_sd_graph_gp_nesting <= ssg->ssg_sd_forgotten_graph)
          {
            switch (SPART_TYPE (curr_graph))
              {
              case SPAR_BLANK_NODE_LABEL:
                if (curr_graph->_.bnode.bracketed & 0x2)
                  new_g_is_dflt = 1;
                break;
              case SPAR_QNAME:
                if ((NULL != ssg->ssg_sd_single_from) && !strcmp (ssg->ssg_sd_single_from, curr_graph->_.qname.val))
                  new_g_is_dflt = 1;
                break;
              }
          }
        if (ssg->ssg_sd_forgotten_graph)
          {
            int old_g_is_dflt = SPART_IS_DEFAULT_GRAPH_BLANK (ssg->ssg_sd_prev_graph);
            if (old_g_is_dflt)
              spar_internal_error (ssg->ssg_sparp, "ssg_sd_forgotten_graph is set but old g is default");
            if (new_g_is_dflt)
              {
                should_close_graph = 1;
                need_new_graph = 0;
              }
            else
              should_close_graph = need_new_graph = !ssg_fields_are_equal (ssg->ssg_sd_prev_graph, curr_graph);
          }
        else
          {
            should_close_graph = 0;
            need_new_graph = !new_g_is_dflt;
          }
        place_qm = ((SSG_SD_QUAD_MAP & ssg->ssg_sd_flags) &&
          (1 == BOX_ELEMENTS_0 (tree->_.triple.tc_list)) &&
          (NULL != ssg->ssg_sparp->sparp_storage) &&
          (0 != (BOX_ELEMENTS_0 (ssg->ssg_sparp->sparp_storage->qsUserMaps) +
              BOX_ELEMENTS_0 (ssg->ssg_sparp->sparp_storage->qsMjvMaps) ) ) );
        if (ssg->ssg_sd_forgotten_dot)
          {
            if ((OPTIONAL_L == tree->_.triple.subtype) ||
             place_qm || should_close_graph || need_new_graph ||
             !ssg_fields_are_equal (ssg->ssg_sd_prev_subj, tree->_.triple.tr_subject) )
              {
                ssg_puts (" .");
                ssg->ssg_indent -= 4;
                ssg->ssg_sd_forgotten_dot = 0;
                ssg->ssg_sd_prev_subj = ssg->ssg_sd_prev_pred = NULL;
              }
          }
        if (should_close_graph)
          {
            ssg_puts (" }");
            ssg->ssg_indent -= 2;
            ssg->ssg_sd_forgotten_graph = 0;
            ssg->ssg_sd_graph_gp_nesting--;
            ssg->ssg_sd_prev_graph = NULL;
          }
        if ((need_new_graph || (OPTIONAL_L == tree->_.triple.subtype) || place_qm) && !ssg->ssg_sd_forgotten_dot)
          ssg_newline (0);
        if (need_new_graph)
          {
            ssg_puts (" GRAPH");
            ssg_sdprint_tree (ssg, curr_graph);
            ssg_puts (" {");
            ssg->ssg_indent += 2;
            ssg->ssg_sd_forgotten_graph = 1;
            ssg->ssg_sd_graph_gp_nesting++;
            ssg->ssg_sd_prev_graph = curr_graph;
          }
        if (OPTIONAL_L == tree->_.triple.subtype)
          {
            ssg_puts (" OPTIONAL {");
            ssg->ssg_indent += 2;
          }
        if (place_qm)
          {
            quad_map_t *qm = tree->_.triple.tc_list[0]->tc_qm;
            jso_rtti_t *qm_rtti = gethash (qm, jso_rttis_of_structs);
            if (NULL == qm_rtti)
              spar_internal_error (ssg->ssg_sparp, "bad quad map JSO instance");
            ssg_puts (" QUAD MAP ");
            ssg_sdprin_qname (ssg, (SPART *)(qm_rtti->jrtti_inst_iri));
            ssg_puts (" {");
            ssg->ssg_indent += 2;
          }
        if (!ssg->ssg_sd_forgotten_dot)
          {
            ssg_sdprint_tree (ssg, tree->_.triple.tr_subject);
            ssg->ssg_sd_prev_subj = tree->_.triple.tr_subject;
            ssg->ssg_indent += 2;
            ssg_sdprint_tree (ssg, tree->_.triple.tr_predicate);
            ssg->ssg_sd_prev_pred = tree->_.triple.tr_predicate;
            ssg->ssg_indent += 2;
          }
        else if (!ssg_fields_are_equal (ssg->ssg_sd_prev_pred, tree->_.triple.tr_predicate))
          {
            ssg_puts (" ;");
            ssg->ssg_indent -= 2;
            ssg_newline (0);
            ssg_sdprint_tree (ssg, tree->_.triple.tr_predicate);
            ssg->ssg_sd_prev_pred = tree->_.triple.tr_predicate;
            ssg->ssg_indent += 2;
          }
        else
          {
            ssg_puts (" ,");
            ssg_newline (0);
          }
        ssg_sdprint_tree (ssg, tree->_.triple.tr_object);
        option_count = BOX_ELEMENTS_0 (tree->_.triple.options);
        if (0 != option_count)
          {
            if (!(SSG_SD_OPTION & ssg->ssg_sd_flags))
              spar_error (ssg->ssg_sparp, "%.100s does not support OPTION (...) clause for triples so SPARQL query can not be composed", ssg->ssg_sd_service_name);
/*@@@*/
          }
        if (place_qm || (OPTIONAL_L == tree->_.triple.subtype))
          {
            if (ssg->ssg_sd_forgotten_dot)
              {
                ssg_puts (" .");
                ssg->ssg_indent -= 4;
                ssg->ssg_sd_forgotten_dot = 0;
              }
            if (place_qm)
              {
                ssg_puts (" }");
                ssg->ssg_indent -= 2;
              }
            if (OPTIONAL_L == tree->_.triple.subtype)
              {
                ssg_puts (" }");
                ssg->ssg_indent -= 2;
              }
          }
        else
          ssg->ssg_sd_forgotten_dot = 1;
        return;
      }
    case BOP_EQ: case BOP_NEQ:
    case BOP_LT: case BOP_LTE: case BOP_GT: case BOP_GTE:
    /*case BOP_LIKE: Like is built-in in SPARQL, not a BOP! */
    case BOP_SAME: case BOP_NSAME:
    case BOP_PLUS: case BOP_MINUS: case BOP_TIMES: case BOP_DIV: case BOP_MOD:
    case BOP_AND: case BOP_OR:
      {
        if (SPART_TYPE (tree->_.bin_exp.left) < 1000)
          {
            ssg_putchar ('(');
            ssg->ssg_indent++;
          }
        ssg_sdprint_tree (ssg, tree->_.bin_exp.left);
        if (SPART_TYPE (tree->_.bin_exp.left) < 1000)
          {
            ssg_putchar (')');
            ssg->ssg_indent--;
          }
        ssg_putchar (' ');
        ssg_puts (ssg_sd_opname (ssg->ssg_sparp, tree_type, 1));
        ssg_putchar (' ');
        if (SPART_TYPE (tree->_.bin_exp.right) < 1000)
          {
            ssg_putchar ('(');
            ssg->ssg_indent++;
          }
        ssg_sdprint_tree (ssg, tree->_.bin_exp.right);
        if (SPART_TYPE (tree->_.bin_exp.right) < 1000)
          {
            ssg_putchar (')');
            ssg->ssg_indent--;
          }
        return;
      }
    case BOP_NOT:
      {
        ssg_puts (" !(");
        ssg->ssg_indent++;
        ssg_sdprint_tree (ssg, tree->_.bin_exp.left);
        ssg_putchar (')');
        ssg->ssg_indent--;
        return;
      }
    case ORDER_L:
      {
        switch (tree->_.oby.direction)
          {
          case ASC_L: ssg_puts (" ASC ("); break;
          case DESC_L: ssg_puts (" DESC ("); break;
          }
        ssg->ssg_indent++;
        ssg_sdprint_tree (ssg, tree->_.oby.expn);
        ssg_putchar (')');
        ssg->ssg_indent--;
        return;
      }
    case SPAR_GRAPH:
      {
        if (NULL == tree->_.graph.iri)
          spar_error (ssg->ssg_sparp, "%.100s can be invoked only with constant graphs in FROM... clauses so SPARQL query can not be composed", ssg->ssg_sd_service_name);
        switch (tree->_.graph.subtype)
          {
          case SPART_GRAPH_FROM:
          case SPART_GRAPH_GROUP:
            ssg_puts (" FROM "); break;
          case SPART_GRAPH_NAMED:
            ssg_puts (" FROM NAMED "); break;
          case SPART_GRAPH_NOT_FROM:
          case SPART_GRAPH_NOT_GROUP:
            ssg_puts (" NOT FROM "); break;
          case SPART_GRAPH_NOT_NAMED:
            ssg_puts (" NOT FROM NAMED "); break;
          default: spar_internal_error (ssg->ssg_sparp, "Bad tree->_.graph.subtype"); break;
          }
        ssg_sdprin_qname (ssg, (SPART *)(tree->_.graph.iri));
        return;
      }
#if 0
    case SPAR_LIST:
      {
        ssg_puts ("LIST:");
        SES_PRINT (ses, buf);
        spart_dump (tree->_.list.items, ses, indent+2, "ITEMS", -2);
        break;
      }
    default:
      {
        sprintf (buf, "NODE OF TYPE %ld (", (ptrlong)(tree->type));
        SES_PRINT (ses, buf);
        spart_dump_long ((void *)(tree->type), ses, 0);
        sprintf (buf, ") with %d children:\n", childrens-SPART_HEAD);
        SES_PRINT (ses, buf);
        for (ctr = SPART_HEAD; ctr < childrens; ctr++)
	spart_dump (((void **)(tree))[ctr], ses, indent+2, NULL, 0);
        return;
      }
#endif
  }
}



void
sparp_make_sparqld_text (spar_sqlgen_t *ssg)
{
  ssg_sdprint_tree (ssg, ssg->ssg_tree);
}

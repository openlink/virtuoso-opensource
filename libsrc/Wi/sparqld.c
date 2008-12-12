/*
 *  
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *  
 *  Copyright (C) 1998-2006 OpenLink Software
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
/*#include "xml_ecm.h"*/

void ssg_sdprin_literal (spar_sqlgen_t *ssg, SPART *tree)
{
  switch (DV_TYPE_OF (tree))
    {
    case DV_ARRAY_OF_POINTER:
      if (SPAR_LIT != tree->type)
        spar_sqlprint_error ("ssg_" "sdprin_literal: non-literal vector as argument");
      ssg_sdprin_literal (ssg, (SPART *)(tree->_.lit.val));
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
    default:
      ssg_print_box_as_sql_atom (ssg, (caddr_t)tree, 0);
      return;
    }
}

void ssg_sdprin_qname (spar_sqlgen_t *ssg, SPART *tree)
{
  caddr_t str;
  if (DV_ARRAY_OF_POINTER == DV_TYPE_OF (tree))
    {
      if (SPAR_QNAME != tree->type)
        spar_sqlprint_error ("ssg_" "sdprin_qname: non-QName vector as argument");
      str = tree->_.qname.val;
    }
  else
    str = (caddr_t)tree;
/*!!!TBD: pretty-print with namespaces */
  ssg_putchar ('<');
  dks_esc_write (ssg->ssg_out, str, box_length (str)-1, CHARSET_UTF8, CHARSET_UTF8, DKS_ESC_TTL_IRI);
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
ssg_sd_opname (ptrlong opname, int is_op)
{

  if (is_op)
    switch (opname)
    {
    case BOP_AND: return "AND";
    case BOP_OR: return "OR";
    case BOP_NOT: return "!";
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
    case FROM_L: return "FROM";
    /* case GRAPH_L: return "GRAPH"; */
    case IRI_L: return "IRI";
    case IN_L: return "IN";
    case isBLANK_L: return "isBLANK";
    case isIRI_L: return "isIRI";
    case isLITERAL_L: return "isLITERAL";
    case isURI_L: return "isIRI"; /* no isURI in SPARQL */
    case LANG_L: return "LANG";
    case LANGMATCHES_L: return "LANGMATCHES";
    case LIKE_L: return "LIKE";
    case LIMIT_L: return "LIMIT";
    case NAMED_L: return "FROM NAMED";
    case NIL_L: return "NIL";
    /* case OBJECT_L: return "OBJECT"; */
    case OFFBAND_L: return "OFFBAND";
    case OFFSET_L: return "OFFSET";
    case OPTIONAL_L: return "OPTIONAL";
    case ORDER_L: return "ORDER";
    /* case PREDICATE_L: return "PREDICATE"; */
    /* case PREFIX_L: return "PREFIX"; */
    case REGEX_L: return "REGEX";
    case SAMETERM_L: return "sameTerm";
    case SCORE_L: return "SCORE";
    case SELECT_L: return "SELECT";
    case STR_L: return "STR";
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


#define SSG_SD_QUAD_MAP		0x0001	/*!< Allows the use of QUAD MAP groups in the output */
#define SSG_SD_OPTION		0x0002	/*!< Allows the use of OPTION keyword in the output */
#define SSG_SD_BREAKUP		0x0004	/*!< Flags if BREAKUP hint options should be printed, this has no effect w/o SSG_SD_OPTION */
#define SSG_SD_PKSELFJOIN	0x0008	/*!< Flags if PKSELFJOIN hint options should be printed, this has no effect w/o SSG_SD_OPTION */
#define SSG_SD_RVR		0x0010	/*!< Flags if RVR hint options should be printed, this has no effect w/o SSG_SD_OPTION */
#define SSG_SD_BI		0x0020	/*!< Allows the use of SPARQL-BI extensions, blocking in most of cases */
#define SSG_SD_VOS_509		0x00FF	/*!< Allows everything that is supported by Virtuoso Open Source 5.0.9 */
#define SSG_SD_SERVICE		0x0100	/*!< Allows the use of SERVICE extension, blocking */
#define SSG_SD_TRANSIT		0x0200	/*!< Allows the use of SERVICE extension, blocking */
#define SSG_SD_VOS6		0x0FFF	/*!< Allows everything that is supported by Virtuoso Open Source 6.0.0 */
#define SSG_SD_VOS_CURRENT	SSG_SD_VOS_509	/*!< Allows everything that is supported by current version of Virtuoso */

int
ssg_fields_are_equal (SPART *tree1, SPART *tree2)
{
  int type1 = SPART_TYPE (tree1);
  int type2 = SPART_TYPE (tree2);
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

void ssg_sdprint_tree (spar_sqlgen_t *ssg, SPART *tree)
{
  int ctr, count;
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
        ssg_putchar (' ');
        ssg_sdprint_tree (ssg, tree->_.alias.arg);
        if (SSG_SD_BI & ssg->ssg_sd_flags)
          {
            ssg_puts (" AS ?");
            ssg_puts (tree->_.alias.aname);
          }
        return;
      }
    case SPAR_BLANK_NODE_LABEL:
      {
        ssg_puts (" _:");
        ssg_puts (tree->_.var.vname);
        return;
      }
    case SPAR_BUILT_IN_CALL:
      {
        ssg_putchar (' ');
        if (IN_L == tree->_.builtin.btype)
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
            return;
          }
        ssg_puts (ssg_sd_opname (tree->_.builtin.btype, 0));
        ssg_putchar ('(');
        ssg_sdprint_tree_list (ssg, tree->_.builtin.args, ',');
        ssg_putchar (')');
        ssg->ssg_indent--;
        return;
      }
    case SPAR_FUNCALL:
      {
        int argcount = BOX_ELEMENTS (tree->_.funcall.argtrees);
        ssg_putchar (' ');
        ssg_sdprin_qname (ssg, (SPART *)(tree->_.funcall.qname));
        if (0 != argcount)
          {
            ssg_putchar ('(');
            ssg->ssg_indent++;
            ssg_sdprint_tree_list (ssg, tree->_.funcall.argtrees, ',');
            ssg_putchar (')');
            ssg->ssg_indent--;
          }
        else
          ssg_puts (" NIL");
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
            ssg_newline (0);
            ssg->ssg_sd_forgotten_graph = 0;
          }
        ssg_newline (0);
        t_set_push (&(ssg->ssg_sd_outer_gps), tree);
        ssg->ssg_sd_outer_gps = NULL; /* The first triple pattern in the group can not use ';' or ',' shorthand */
        switch (tree->_.gp.subtype)
          {
          case SELECT_L:
            if (!(SSG_SD_BI & ssg->ssg_sd_flags))
              spar_error (ssg->ssg_sparp, "%.100s does not support SPARQL-BI extensions (like nested SELECT) so SPARQL query can not be composed", ssg->ssg_sd_service_name);
            if (NULL == ssg->ssg_sd_outer_gps->data)
              ssg_puts (" (");
            else
              ssg_puts (" {");
            ssg->ssg_indent++;
            ssg_sdprint_tree (ssg, tree->_.gp.subquery);
            if (NULL == ssg->ssg_sd_outer_gps->data)
              ssg_puts (" )");
            else
              ssg_puts (" }");
            ssg->ssg_indent--;
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
          case OPTIONAL_L: ssg_puts (" OPTIONAL "); break;
          case WHERE_L: ssg_puts (" WHERE "); break;
          case 0: break;
          }
        ssg_putchar ('{');
        ssg->ssg_indent += 2;
        DO_BOX_FAST (SPART *, sub, ctr, tree->_.gp.members)
          {
            ssg_sdprint_tree (ssg, sub);
          }
        END_DO_BOX_FAST;
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
            ssg_newline (0);
            ssg->ssg_sd_forgotten_graph = 0;
          }
        t_set_push (&(ssg->ssg_sd_outer_gps), NULL);
        count = BOX_ELEMENTS (tree->_.gp.filters) - tree->_.gp.glued_filters_count;
        for (ctr = 0; ctr < count; ctr++)
          {
            SPART * filt = tree->_.gp.filters [ctr];
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
        int srcctr, srccount = BOX_ELEMENTS (tree->_.req_top.sources);
        ssg_puts ("SELECT ");
        ssg_sdprint_tree_list (ssg, tree->_.req_top.retvals, '\n');
        for (srcctr = 0; srcctr < srccount; srcctr++)
          {
            if (NAMED_L == tree->_.req_top.sources[srcctr]->type)
              continue;
            ssg_newline (0);
            ssg_sdprint_tree (ssg, tree->_.req_top.sources[srcctr]);
          }
        ssg_newline (0);
        ssg_sdprint_tree (ssg, tree->_.req_top.pattern);
        if (NULL != tree->_.req_top.limit)
          {
            ssg_newline (0);
            ssg_puts ("LIMIT ");
            ssg_sdprin_literal (ssg, (SPART *)(tree->_.req_top.limit));
          }
        if (NULL != tree->_.req_top.offset)
          {
            ssg_newline (0);
            ssg_puts ("OFFSET ");
            ssg_sdprin_literal (ssg, (SPART *)(tree->_.req_top.offset));
          }
        if (0 != BOX_ELEMENTS_0 (tree->_.req_top.groupings))
          {
            ssg_newline (0);
            ssg_puts ("GROUP BY ");
            ssg_sdprint_tree_list (ssg, tree->_.req_top.groupings, ',');
          }
        if (0 != BOX_ELEMENTS_0 (tree->_.req_top.order))
          {
            ssg_newline (0);
            ssg_puts ("ORDER BY ");
            ssg_sdprint_tree_list (ssg, tree->_.req_top.order, ',');
          }
        return;
      }
    case SPAR_VARIABLE:
      {
        ssg_puts (" ?");
        ssg_puts (tree->_.var.vname);
        return;
      }
    case SPAR_TRIPLE:
      {
        int new_g_is_dflt = SPART_IS_DEFAULT_GRAPH_BLANK (tree->_.triple.tr_graph);
        int should_close_graph, need_new_graph, place_qm;
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
              should_close_graph = need_new_graph = !ssg_fields_are_equal (ssg->ssg_sd_prev_graph, tree->_.triple.tr_graph);
          }
        else
          {
            should_close_graph = 0;
            need_new_graph = !new_g_is_dflt;
          }
        place_qm = ((SSG_SD_QUAD_MAP & ssg->ssg_sd_flags) &&
          (1 == BOX_ELEMENTS_0 (tree->_.triple.tc_list)) &&
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
                ssg_newline (0);
                ssg->ssg_sd_forgotten_dot = 0;
                ssg->ssg_sd_prev_subj = ssg->ssg_sd_prev_pred = NULL;
              }
          }
        if (should_close_graph)
          {
            ssg_puts (" }");
            ssg->ssg_indent -= 2;
            ssg_newline (0);
            ssg->ssg_sd_forgotten_graph = 0;
            ssg->ssg_sd_prev_graph = NULL;
          }
        if (need_new_graph)
          {
            ssg_puts (" GRAPH");
            ssg_sdprint_tree (ssg, tree->_.triple.tr_graph);
            ssg_puts (" {");
            ssg->ssg_indent += 2;
            ssg_newline (0);
            ssg->ssg_sd_forgotten_graph = 1;
            ssg->ssg_sd_prev_graph = tree->_.triple.tr_graph;
          }
        if (OPTIONAL_L == tree->_.triple.subtype)
          {
            ssg_puts (" OPTIONAL {");
            ssg->ssg_indent += 2;
          }
        if (place_qm)
          {
            quad_map_t *qm = tree->_.triple.tc_list[0]->tc_qm;
            jso_rtti_t *qm_rtti = gethash (qm, jso_rttis_of_names);
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
            ssg_sdprint_tree (ssg, tree->_.triple.tr_object);
          }
        else if (!ssg_fields_are_equal (ssg->ssg_sd_prev_pred, tree->_.triple.tr_predicate))
          {
            ssg_puts (" ;");
            ssg->ssg_indent -= 2;
            ssg_newline (0);
            ssg_sdprint_tree (ssg, tree->_.triple.tr_predicate);
            ssg->ssg_sd_prev_pred = tree->_.triple.tr_predicate;
            ssg->ssg_indent += 2;
            ssg_sdprint_tree (ssg, tree->_.triple.tr_object);
          }
        else
          {
            ssg_puts (" ,");
            ssg_newline (0);
            ssg_sdprint_tree (ssg, tree->_.triple.tr_object);
          }
        ssg->ssg_sd_forgotten_dot = 1;
        if (place_qm || (OPTIONAL_L == tree->_.triple.subtype))
          {
            ssg_puts (" .");
            ssg->ssg_indent -= 4;
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
        ssg_puts (ssg_sd_opname (tree_type, 1));
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
        ssg_puts (" NOT (");
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
    case FROM_L:
      {
        ssg_puts (" FROM");
        ssg_sdprint_tree (ssg, tree->_.lit.val);
        return;
      }
    case NAMED_L:
      {
        ssg_puts (" FROM NAMED");
        ssg_sdprint_tree (ssg, tree->_.lit.val);
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

#if 0
void spart_dump_varr_bits (dk_session_t *ses, int varr_bits)
{
  char buf[200];
  char *tail = buf;
#define VARR_BIT(b,txt) \
  do { \
    if (varr_bits & (b)) \
      { const char *t = (txt); while ('\0' != (tail[0] = (t++)[0])) tail++; } \
    } while (0);
  VARR_BIT (SPART_VARR_CONFLICT, " CONFLICT");
  VARR_BIT (SPART_VARR_GLOBAL, " GLOBAL");
  VARR_BIT (SPART_VARR_EXTERNAL, " EXTERNAL");
  VARR_BIT (SPART_VARR_ALWAYS_NULL, " always-NULL");
  VARR_BIT (SPART_VARR_NOT_NULL, " notNULL");
  VARR_BIT (SPART_VARR_FIXED, " fixed");
  VARR_BIT (SPART_VARR_TYPED, " typed");
  VARR_BIT (SPART_VARR_IS_LIT, " lit");
  VARR_BIT (SPART_VARR_IRI_CALC, " IRI-namecalc");
  VARR_BIT (SPART_VARR_SPRINTFF, " SprintfF");
  VARR_BIT (SPART_VARR_IS_BLANK, " bnode");
  VARR_BIT (SPART_VARR_IS_IRI, " IRI");
  VARR_BIT (SPART_VARR_IS_REF, " reference");
  VARR_BIT (SPART_VARR_EXPORTED, " exported");
  session_buffered_write (ses, buf, tail-buf);
}

void spart_dump_rvr (dk_session_t *ses, rdf_val_range_t *rvr)
{
  char buf[300];
  char *tail = buf;
  int len;
  int varr_bits = rvr->rvrRestrictions;
  ccaddr_t fixed_dt = rvr->rvrDatatype;
  ccaddr_t fixed_val = rvr->rvrFixedValue;
  spart_dump_varr_bits (ses, varr_bits);
  if (varr_bits & SPART_VARR_TYPED)
    {
      len = sprintf (tail, "; dt=%.100s", fixed_dt);
      tail += len;
    }
  if (varr_bits & SPART_VARR_FIXED)
    {
      dtp_t dtp = DV_TYPE_OF (fixed_val);
      const char *dtp_name = dv_type_title (dtp);
      const char *meta = "";
      const char *lit_dt = NULL;
      const char *lit_lang = NULL;
      if (DV_ARRAY_OF_POINTER == dtp)
        {
          SPART *fixed_tree = ((SPART *)fixed_val);
          if (SPAR_QNAME == SPART_TYPE (fixed_tree))
            {
              meta = " QName";
              fixed_val = fixed_tree->_.lit.val;
            }
          else if (SPAR_LIT == SPART_TYPE (fixed_tree))
            {
              meta = " lit";
              fixed_val = fixed_tree->_.lit.val;
              lit_dt = fixed_tree->_.lit.datatype;
              lit_lang = fixed_tree->_.lit.language;
            }
          dtp = DV_TYPE_OF (fixed_val);
          dtp_name = dv_type_title (dtp);
        }
      if (IS_STRING_DTP (dtp))
        len = sprintf (tail, "; fixed%s %s '%.100s'", meta, dtp_name, fixed_val);
      else if (DV_LONG_INT == dtp)
        len = sprintf (tail, "; fixed%s %s %ld", meta, dtp_name, (long)(unbox (fixed_val)));
      else
        len = sprintf (tail, "; fixed%s %s", meta, dtp_name);
      tail += len;
      if (NULL != lit_dt)
        tail += sprintf (tail, "^^'%.50s'", lit_dt);
      if (NULL != lit_lang)
        tail += sprintf (tail, "@'%.50s'", lit_lang);
      SES_PRINT (ses, buf);
    }
  if (rvr->rvrIriClassCount)
    {
      int iricctr;
      SES_PRINT (ses, "; IRI classes");
      for (iricctr = 0; iricctr < rvr->rvrIriClassCount; iricctr++)
        {
          SES_PRINT (ses, " ");
          SES_PRINT (ses, rvr->rvrIriClasses[iricctr]);
        }
    }
  if (rvr->rvrRedCutCount)
    {
      int rcctr;
      SES_PRINT (ses, "; Not one of");
      for (rcctr = 0; rcctr < rvr->rvrRedCutCount; rcctr++)
        {
          SES_PRINT (ses, " ");
          SES_PRINT (ses, rvr->rvrRedCuts[rcctr]);
        }
    }
  if (rvr->rvrSprintffs)
    {
      int sffctr;
      SES_PRINT (ses, "; Formats ");
      for (sffctr = 0; sffctr < rvr->rvrSprintffCount; sffctr++)
        {
          SES_PRINT (ses, " |");
          SES_PRINT (ses, rvr->rvrSprintffs[sffctr]);
          SES_PRINT (ses, "|");
        }
    }
}

void
spart_dump_eq (int eq_ctr, sparp_equiv_t *eq, dk_session_t *ses)
{
  int varname_count, varname_ctr, var_ctr;
  char buf[100];
  session_buffered_write_char ('\n', ses);
  if (NULL == eq)
    {
      sprintf (buf, "#%d: merged and destroyed", eq_ctr);
      SES_PRINT (ses, buf);
      return;
    }
  sprintf (buf, "#%d: %s( %d subv (%d bindings), %d recv, %d gspo, %d const, %d opt, %d subq:", eq_ctr,
  (eq->e_deprecated ? "deprecated " : ""),
    BOX_ELEMENTS_INT_0(eq->e_subvalue_idxs), (int)(eq->e_nested_bindings), BOX_ELEMENTS_INT_0(eq->e_receiver_idxs),
    (int)(eq->e_gspo_uses), (int)(eq->e_const_reads), (int)(eq->e_optional_reads), (int)(eq->e_subquery_uses) );
  SES_PRINT (ses, buf);
  varname_count = BOX_ELEMENTS (eq->e_varnames);
  for (varname_ctr = 0; varname_ctr < varname_count; varname_ctr++)
    {
      SES_PRINT (ses, " ");
      SES_PRINT (ses, eq->e_varnames[varname_ctr]);
    }
  SES_PRINT (ses, " in");
  for (var_ctr = 0; var_ctr < eq->e_var_count; var_ctr++)
    {
      SPART *var = eq->e_vars[var_ctr];
      SES_PRINT (ses, " ");
      SES_PRINT (ses, ((NULL != var->_.var.tabid) ? var->_.var.tabid : var->_.var.selid));
    }
  SES_PRINT (ses, ";"); spart_dump_rvr (ses, &(eq->e_rvr));
  SES_PRINT (ses, ")");
}

void
spart_dump (void *tree_arg, dk_session_t *ses, int indent, const char *title, int hint)
{
  SPART *tree = (SPART *) tree_arg;
  int ctr;
  if ((NULL == tree) && (hint < 0))
    return;
  if (indent > 0)
    {
      session_buffered_write_char ('\n', ses);
      for (ctr = indent; ctr--; /*no step*/ )
        session_buffered_write_char (' ', ses);
    }
  if (title)
    {
      SES_PRINT (ses, title);
      SES_PRINT (ses, ": ");
    }
  if ((-1 == hint) && IS_BOX_POINTER(tree))
    {
      if (DV_ARRAY_OF_POINTER != DV_TYPE_OF (tree))
        {
          SES_PRINT (ses, "special: ");
          hint = 0;
        }
      else if ((SPART_HEAD >= BOX_ELEMENTS(tree)) || IS_BOX_POINTER (tree->type))
        {
          SES_PRINT (ses, "special: ");
          hint = -2;
        }
    }
  if (!hint)
    hint = DV_TYPE_OF (tree);
  switch (hint)
    {
    case -1:
      {
	int childrens;
	char buf[50];
	if (!IS_BOX_POINTER(tree))
	  {
	    SES_PRINT (ses, "[");
	    spart_dump_long (tree, ses, 0);
	    SES_PRINT (ses, "]");
	    goto printed;
	  }
        sprintf (buf, "(line %d) ", (int) (ptrlong) tree->srcline);
        SES_PRINT (ses, buf);
	childrens = BOX_ELEMENTS (tree);
	switch (tree->type)
	  {
	  case SPAR_ALIAS:
	    {
	      sprintf (buf, "ALIAS:");
	      SES_PRINT (ses, buf);
	      spart_dump (tree->_.alias.aname, ses, indent+2, "ALIAS NAME", 0);
	      spart_dump (tree->_.alias.arg, ses, indent+2, "VALUE", -1);
		/* _.alias.native is temp so it is not printed */
	      break;
	    }
	  case SPAR_BLANK_NODE_LABEL:
	    {
	      sprintf (buf, "BLANK NODE:");
	      SES_PRINT (ses, buf);
	      spart_dump (tree->_.var.vname, ses, indent+2, "NAME", 0);
	      spart_dump (tree->_.var.selid, ses, indent+2, "SELECT ID", 0);
	      spart_dump (tree->_.var.tabid, ses, indent+2, "TABLE ID", 0);
	      break;
	    }
	  case SPAR_BUILT_IN_CALL:
	    {
	      sprintf (buf, "BUILT-IN CALL:");
	      SES_PRINT (ses, buf);
	      spart_dump_long ((void *)(tree->_.builtin.btype), ses, -1);
	      spart_dump (tree->_.builtin.args, ses, indent+2, "ARGUMENT", -2);
	      break;
	    }
	  case SPAR_FUNCALL:
	    {
	      int argctr, argcount = BOX_ELEMENTS (tree->_.funcall.argtrees);
	      spart_dump (tree->_.funcall.qname, ses, indent+2, "FUNCTION NAME", 0);
              if (tree->_.funcall.agg_mode)
		spart_dump ((void *)(tree->_.funcall.agg_mode), ses, indent+2, "AGGREGATE MODE", 0);
	      for (argctr = 0; argctr < argcount; argctr++)
		spart_dump (tree->_.funcall.argtrees[argctr], ses, indent+2, "ARGUMENT", -1);
	      break;
	    }
	  case SPAR_GP:
            {
              int eq_count, eq_ctr;
	      sprintf (buf, "GRAPH PATTERN:");
	      SES_PRINT (ses, buf);
	      spart_dump_long ((void *)(tree->_.gp.subtype), ses, -1);
	      spart_dump (tree->_.gp.members, ses, indent+2, "MEMBERS", -2);
	      spart_dump (tree->_.gp.subquery, ses, indent+2, "SUBQUERY", -1);
	      spart_dump (tree->_.gp.filters, ses, indent+2, "FILTERS", -2);
	      spart_dump (tree->_.gp.selid, ses, indent+2, "SELECT ID", 0);
	      spart_dump (tree->_.gp.options, ses, indent+2, "OPTIONS", -2);
	      /* spart_dump (tree->_.gp.results, ses, indent+2, "RESULTS", -2); */
              session_buffered_write_char ('\n', ses);
	      for (ctr = indent+2; ctr--; /*no step*/ )
	        session_buffered_write_char (' ', ses);
	      sprintf (buf, "EQUIVS:");
	      SES_PRINT (ses, buf);
              eq_count = tree->_.gp.equiv_count;
	      for (eq_ctr = 0; eq_ctr < eq_count; eq_ctr++)
                {
	          sprintf (buf, " %d", (int)(tree->_.gp.equiv_indexes[eq_ctr]));
		  SES_PRINT (ses, buf);
                }
	      break;
	    }
	  case SPAR_LIT:
	    {
	      sprintf (buf, "LITERAL:");
	      SES_PRINT (ses, buf);
	      spart_dump (tree->_.lit.val, ses, indent+2, "VALUE", 0);
              if (tree->_.lit.datatype)
	        spart_dump (tree->_.lit.datatype, ses, indent+2, "DATATYPE", 0);
              if (tree->_.lit.language)
	        spart_dump (tree->_.lit.language, ses, indent+2, "LANGUAGE", 0);
	      break;
	    }
	  case SPAR_QNAME:
	    {
	      sprintf (buf, "QNAME:");
	      SES_PRINT (ses, buf);
	      spart_dump (tree->_.lit.val, ses, indent+2, "IRI", 0);
	      break;
	    }
	  /*case SPAR_QNAME_NS:
	    {
	      sprintf (buf, "QNAME_NS:");
	      SES_PRINT (ses, buf);
	      spart_dump (tree->_.lit.val, ses, indent+2, "NAMESPACE", 0);
	      break;
	    }*/
	  case SPAR_REQ_TOP:
	    {
	      sprintf (buf, "REQUEST TOP NODE (");
	      SES_PRINT (ses, buf);
	      spart_dump_long ((void *)(tree->_.req_top.subtype), ses, 1);
	      SES_PRINT (ses, "):");
              if (NULL != tree->_.req_top.retvalmode_name)
	        spart_dump (tree->_.req_top.retvalmode_name, ses, indent+2, "VALMODE FOR RETVALS", 0);
              if (NULL != tree->_.req_top.formatmode_name)
	        spart_dump (tree->_.req_top.formatmode_name, ses, indent+2, "SERIALIZATION FORMAT", 0);
              if (NULL != tree->_.req_top.storage_name)
	        spart_dump (tree->_.req_top.storage_name, ses, indent+2, "RDF DATA STORAGE", 0);
	      if (IS_BOX_POINTER(tree->_.req_top.retvals))
	        spart_dump (tree->_.req_top.retvals, ses, indent+2, "RETVALS", -2);
	      else
	        spart_dump (tree->_.req_top.retvals, ses, indent+2, "RETVALS", 0);
	      spart_dump (tree->_.req_top.retselid, ses, indent+2, "RETVALS SELECT ID", 0);
	      spart_dump (tree->_.req_top.sources, ses, indent+2, "SOURCES", -2);
	      spart_dump (tree->_.req_top.pattern, ses, indent+2, "PATTERN", -1);
	      spart_dump (tree->_.req_top.order, ses, indent+2, "ORDER", -1);
	      spart_dump ((void *)(tree->_.req_top.limit), ses, indent+2, "LIMIT", 0);
	      spart_dump ((void *)(tree->_.req_top.offset), ses, indent+2, "OFFSET", 0);
	      break;
	    }
	  case SPAR_VARIABLE:
	    {
	      sprintf (buf, "VARIABLE:");
	      SES_PRINT (ses, buf);
              spart_dump_rvr (ses, &(tree->_.var.rvr));
              if (NULL != tree->_.var.tabid)
                {
                  ptrlong tr_idx = tree->_.var.tr_idx;
                  static const char *field_full_names[] = {"graph", "subject", "predicate", "object"};
                  if (tr_idx < SPART_TRIPLE_FIELDS_COUNT)
                    {
                      sprintf (buf, " (%s)", field_full_names[tr_idx]);
                      SES_PRINT (ses, buf);
                    }
                  else
                    spart_dump_opname (tr_idx, 0);
                }
	      spart_dump (tree->_.var.vname, ses, indent+2, "NAME", 0);
	      spart_dump (tree->_.var.selid, ses, indent+2, "SELECT ID", 0);
	      spart_dump (tree->_.var.tabid, ses, indent+2, "TABLE ID", 0);
	      spart_dump ((void*)(tree->_.var.equiv_idx), ses, indent+2, "EQUIV", 0);
	      break;
	    }
	  case SPAR_TRIPLE:
	    {
	      sprintf (buf, "TRIPLE:");
	      SES_PRINT (ses, buf);
	      if (tree->_.triple.ft_type)
                {
	          sprintf (buf, " ft predicate %d", (int)(tree->_.triple.ft_type));
	          SES_PRINT (ses, buf);
                }
              if (NULL != tree->_.triple.options)
                spart_dump (tree->_.triple.options, ses, indent+2, "OPTIONS", -2);
	      spart_dump (tree->_.triple.tr_graph, ses, indent+2, "GRAPH", -1);
	      spart_dump (tree->_.triple.tr_subject, ses, indent+2, "SUBJECT", -1);
	      spart_dump (tree->_.triple.tr_predicate, ses, indent+2, "PREDICATE", -1);
	      spart_dump (tree->_.triple.tr_object, ses, indent+2, "OBJECT", -1);
	      spart_dump (tree->_.triple.selid, ses, indent+2, "SELECT ID", 0);
	      spart_dump (tree->_.triple.tabid, ses, indent+2, "TABLE ID", 0);
	      spart_dump (tree->_.triple.options, ses, indent+2, "OPTIONS", -2);
	      break;
	    }
	  case BOP_EQ: case BOP_NEQ:
	  case BOP_LT: case BOP_LTE: case BOP_GT: case BOP_GTE:
	  /*case BOP_LIKE: Like is built-in in SPARQL, not a BOP! */
	  case BOP_SAME: case BOP_NSAME:
	  case BOP_PLUS: case BOP_MINUS: case BOP_TIMES: case BOP_DIV: case BOP_MOD:
	  case BOP_AND: case BOP_OR: case BOP_NOT:
	    {
	      sprintf (buf, "OPERATOR EXPRESSION ("/*, tree->type*/);
	      SES_PRINT (ses, buf);
	      spart_dump_long ((void *)(tree->type), ses, 1);
	      SES_PRINT (ses, "):");
	      spart_dump (tree->_.bin_exp.left, ses, indent+2, "LEFT", -1);
	      spart_dump (tree->_.bin_exp.right, ses, indent+2, "RIGHT", -1);
	      break;
	    }
          case ORDER_L:
            {
	      sprintf (buf, "ORDERING ("/*, tree->_.oby.direction*/);
	      SES_PRINT (ses, buf);
	      spart_dump_long ((void *)(tree->_.oby.direction), ses, 1);
	      SES_PRINT (ses, "):");
	      spart_dump (tree->_.oby.expn, ses, indent+2, "CRITERION", -1);
	      break;
            }
	  case FROM_L:
	    {
	      sprintf (buf, "FROM (default):");
	      SES_PRINT (ses, buf);
	      spart_dump (tree->_.lit.val, ses, indent+2, "IRI", 0);
	      break;
	    }
	  case NAMED_L:
	    {
	      sprintf (buf, "FROM NAMED:");
	      SES_PRINT (ses, buf);
	      spart_dump (tree->_.lit.val, ses, indent+2, "IRI", 0);
	      break;
	    }
	  case SPAR_LIST:
	    {
	      sprintf (buf, "LIST:");
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
	      break;
	    }
	  }
	break;
      }
    case DV_ARRAY_OF_POINTER:
      {
	int childrens = BOX_ELEMENTS (tree);
	char buf[50];
	sprintf (buf, "ARRAY with %d children: {", childrens);
	SES_PRINT (ses,	buf);
	for (ctr = 0; ctr < childrens; ctr++)
	  spart_dump (((void **)(tree))[ctr], ses, indent+2, NULL, 0);
	if (indent > 0)
	  {
	    session_buffered_write_char ('\n', ses);
	    for (ctr = indent; ctr--; /*no step*/ )
	      session_buffered_write_char (' ', ses);
	  }
	SES_PRINT (ses,	" }");
	break;
      }
    case -2:
      {
	int childrens = BOX_ELEMENTS (tree);
	char buf[50];
	if (0 == childrens)
	  {
	    SES_PRINT (ses, "EMPTY ARRAY");
	    break;
	  }
	sprintf (buf, "ARRAY OF NODES with %d children: {", childrens);
	SES_PRINT (ses,	buf);
	for (ctr = 0; ctr < childrens; ctr++)
	  spart_dump (((void **)(tree))[ctr], ses, indent+2, NULL, -1);
	if (indent > 0)
	  {
	    session_buffered_write_char ('\n', ses);
	    for (ctr = indent; ctr--; /*no step*/ )
	    session_buffered_write_char (' ', ses);
	  }
	SES_PRINT (ses,	" }");
	break;
      }
#if 0
    case -3:
      {
	char **execname = (char **)id_hash_get (xpf_reveng, (caddr_t)(&tree));
	SES_PRINT (ses, "native code started at ");
	if (NULL == execname)
	  {
	    char buf[30];
	    sprintf (buf, "0x%p", (void *)tree);
	    SES_PRINT (ses, buf);
	  }
	else
	  {
	    SES_PRINT (ses, "label '");
	    SES_PRINT (ses, execname[0]);
	    SES_PRINT (ses, "'");
	  }
	break;
      }
#endif
    case DV_LONG_INT:
      {
	char buf[30];
	sprintf (buf, "LONG %ld", (long)(unbox ((ccaddr_t)tree)));
	SES_PRINT (ses,	buf);
	break;
      }
    case DV_STRING:
      {
	SES_PRINT (ses,	"STRING `");
	SES_PRINT (ses,	(char *)(tree));
	SES_PRINT (ses,	"'");
	break;
      }
    case DV_UNAME:
      {
	SES_PRINT (ses,	"UNAME `");
	SES_PRINT (ses,	(char *)(tree));
	SES_PRINT (ses,	"'");
	break;
      }
    case DV_SYMBOL:
      {
	SES_PRINT (ses,	"SYMBOL `");
	SES_PRINT (ses,	(char *)(tree));
	SES_PRINT (ses,	"'");
	break;
      }
    case DV_NUMERIC:
      {
        numeric_t n = (numeric_t)(tree);
        char buf[0x100];
	SES_PRINT (ses,	"NUMERIC ");
        numeric_to_string (n, buf, 0x100);
	SES_PRINT (ses,	buf);
      }
    default:
      {
	char buf[30];
	sprintf (buf, "UNEXPECTED TYPE (%u)", (unsigned)(DV_TYPE_OF (tree)));
	SES_PRINT (ses,	buf);
	break;
      }
    }
printed:
  if (0 == indent)
    session_buffered_write_char ('\n', ses);
}
#endif


void sparp_make_sparqld_text (spar_sqlgen_t *ssg)
{
  ssg_sdprint_tree (ssg, ssg->ssg_tree);
}

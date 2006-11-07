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
#include "arith.h"
#include "sqlparext.h"
#include "sqlbif.h"
#include "sqlcmps.h"
#include "remote.h" /* for sqlrcomp.h */
#include "sqlrcomp.h"
#include "xmltree.h"
#include "xml_ecm.h" /* for ecm_find_name etc. */
#include "xpf.h"
#include "xqf.h"
#ifdef __cplusplus
extern "C" {
#endif
#include "sparql_p.h"
#ifdef __cplusplus
}
#endif

#ifdef DEBUG
#define spar_sqlprint_error(x) do { ssg_putchar ('!'); ssg_puts ((x)); ssg_putchar ('!'); return; } while (0)
#define spar_sqlprint_error2(x,v) do { ssg_putchar ('!'); ssg_puts ((x)); ssg_putchar ('!'); return (v); } while (0)
#else
#define spar_sqlprint_error(x) spar_internal_error (NULL, (x))
#define spar_sqlprint_error2(x,v) spar_internal_error (NULL, (x))
#endif

/* Description of RDF datasources */

qm_format_t *qm_format_default_iri_ref;
qm_format_t *qm_format_default_ref;
qm_format_t *qm_format_default;
qm_value_t *qm_default_values[SPART_TRIPLE_FIELDS_COUNT];
quad_map_t *qm_default;
quad_storage_t *rdf_sys_storage;

void rdf_ds_load_all (void)
{
  int colctr;
  qm_format_t *qmf;
  qm_column_t *qmcol;
  qm_value_t *qmval;

  for (colctr = 0; colctr < 4; colctr++)
    {
      const char *colnames[] = {"G", "S", "P", "O"};
      qmcol = dk_alloc_box_zero (sizeof (qm_column_t), DV_ARRAY_OF_POINTER);
      qmcol->qmvcColumnName = box_dv_short_string (colnames[colctr]);
      qmval = qm_default_values[colctr] = (qm_value_t *)dk_alloc_box_zero (sizeof (qm_value_t), DV_ARRAY_OF_POINTER);
      qmval->qmvTableName = box_dv_short_string ("DB.DBA.RDF_QUAD");
      qmval->qmvColumns = (qm_column_array_t)list (1, qmcol);
    }

/* field for graph, subject and predicate */
  qmf = qm_format_default_iri_ref = dk_alloc_box_zero (sizeof (qm_format_t), DV_ARRAY_OF_POINTER);
  qmf->qmfName = box_dv_short_string ("default-iid-nonblank");
  qmf->qmfShortTmpl = box_dv_short_string (" ^{alias-dot}^^{column}^");
  qmf->qmfLongTmpl = box_dv_short_string (" /* LONG: */ ^{alias-dot}^^{column}^");
  qmf->qmfSqlvalTmpl = box_dv_short_string (" DB.DBA.RDF_QNAME_OF_IID (^{alias-dot}^^{column}^)");
  qmf->qmfBoolTmpl = box_dv_short_string (" NULL");
  qmf->qmfIsrefOfShortTmpl = box_dv_short_string (" 1");
  qmf->qmfIsuriOfShortTmpl = box_dv_short_string (" (^{tree}^ < #i1000000000)");
  qmf->qmfIsblankOfShortTmpl = box_dv_short_string (" (^{tree}^ >= #i1000000000)");
  qmf->qmfIslitOfShortTmpl = box_dv_short_string (" 0");
  qmf->qmfLongOfShortTmpl = box_dv_short_string (" ^{tree}^ ");
  qmf->qmfDatatypeOfShortTmpl = box_dv_short_string (" 'http://www.w3.org/2001/XMLSchema#anyURI'");
  qmf->qmfLanguageOfShortTmpl = box_dv_short_string (" NULL");
  qmf->qmfSqlvalOfShortTmpl = box_dv_short_string (" DB.DBA.RDF_QNAME_OF_IID (^{tree}^)");
  qmf->qmfBoolOfShortTmpl = box_dv_short_string (" NULL");
  qmf->qmfIidOfShortTmpl = box_dv_short_string (" ^{tree}^");
  qmf->qmfUriOfShortTmpl = box_dv_short_string (" DB.DBA.RDF_QNAME_OF_IID (^{tree}^)");
  qmf->qmfStrsqlvalOfShortTmpl = box_dv_short_string (" DB.DBA.RDF_QNAME_OF_IID (^{tree}^)");
  qmf->qmfShortOfTypedsqlvalTmpl = box_dv_short_string (" NULL");
  qmf->qmfShortOfSqlvalTmpl = box_dv_short_string (" DB.DBA.RDF_MAKE_IID_OF_QNAME_SAFE (^{tree}^)");
  qmf->qmfShortOfLongTmpl = box_dv_short_string (" /* SHORT of LONG: */ ^{tree}^");
  qmf->qmfShortOfUriTmpl = box_dv_short_string (" DB.DBA.RDF_MAKE_IID_OF_QNAME_SAFE (^{tree}^)");
  qmf->qmfCmpFuncName = box_dv_short_string ("DB.DBA.RDF_IID_CMP");
  qmf->qmfTypeminTmpl = box_dv_short_string (" NULL"); /* No order on IRIs */
  qmf->qmfTypemaxTmpl = box_dv_short_string (" NULL"); /* No order on IRIs */
  qmf->qmfOkForAnySqlvalue = 0; /* It can not store anything except IRI ids */
  qmf->qmfValRange.rvrRestrictions = SPART_VARR_IS_REF | SPART_VARR_IS_IRI | SPART_VARR_NOT_NULL;
  qmf->qmfValRange.rvrDatatype = NULL;
  qmf->qmfValRange.rvrLanguage = NULL;
  qmf->qmfValRange.rvrFixedValue = NULL;
  qmf->qmfValRange.rvrIriClasses = NULL;
  qmf->qmfValRange.rvrIriClassCount = 0;
  qmf->qmfUriIdOffset = 0;

  qmf = qm_format_default = dk_alloc_box_zero (sizeof (qm_format_t), DV_ARRAY_OF_POINTER);
  qmf->qmfName = box_dv_short_string ("default");
  qmf->qmfShortTmpl = box_dv_short_string (" ^{alias-dot}^^{column}^");
  qmf->qmfLongTmpl = box_dv_short_string (" DB.DBA.RQ_LONG_OF_O (^{alias-dot}^^{column}^)");
  qmf->qmfSqlvalTmpl = box_dv_short_string (" DB.DBA.RQ_SQLVAL_OF_O (^{alias-dot}^^{column}^)");
  qmf->qmfBoolTmpl = box_dv_short_string (" DB.DBA.RQ_BOOL_OF_O (^{alias-dot}^^{column}^)");
  qmf->qmfIsrefOfShortTmpl = box_dv_short_string (" isiri_id (^{tree}^)");
  qmf->qmfIsuriOfShortTmpl = box_dv_short_string (" (case (isiri_id (^{tree}^)) when 0 then 0 else lt (^{tree}^, #i1000000000) end)");
  qmf->qmfIsblankOfShortTmpl = box_dv_short_string (" (case (isiri_id (^{tree}^)) when 0 then 0 else gte (^{tree}^, #i1000000000) end)");
  qmf->qmfIslitOfShortTmpl = box_dv_short_string (" DB.DBA.RQ_O_IS_LIT (^{tree}^)");
  qmf->qmfLongOfShortTmpl = box_dv_short_string (" DB.DBA.RDF_LONG_OF_OBJ (^{tree}^)");
  qmf->qmfDatatypeOfShortTmpl = box_dv_short_string (" DB.DBA.RDF_DATATYPE_OF_OBJ (^{tree}^)");
  qmf->qmfLanguageOfShortTmpl = box_dv_short_string (" DB.DBA.RDF_LANGUAGE_OF_OBJ (^{tree}^)");
  qmf->qmfSqlvalOfShortTmpl = box_dv_short_string (" DB.DBA.RDF_SQLVAL_OF_OBJ (^{tree}^)");
  qmf->qmfBoolOfShortTmpl = box_dv_short_string (" DB.DBA.RDF_BOOL_OF_OBJ (^{tree}^)");
  qmf->qmfIidOfShortTmpl = box_dv_short_string (" DB.DBA.RDF_MAKE_IID_OF_LONG (DB.DBA.RDF_LONG_OF_OBJ (^{tree}^))");
  qmf->qmfUriOfShortTmpl = box_dv_short_string (" DB.DBA.RDF_QNAME_OF_OBJ (^{tree}^)");
  qmf->qmfStrsqlvalOfShortTmpl = box_dv_short_string (" DB.DBA.RDF_STRSQLVAL_OF_OBJ (^{tree}^)");
  qmf->qmfShortOfTypedsqlvalTmpl = box_dv_short_string (" DB.DBA.RDF_MAKE_OBJ_OF_TYPEDSQLVAL (^{sqlval-of-tree}^, DB.DBA.RDF_MAKE_IID_OF_QNAME(^{datatype-of-tree}^), ^{language-of-tree}^)");
  qmf->qmfShortOfSqlvalTmpl = box_dv_short_string (" DB.DBA.RDF_OBJ_OF_SQLVAL (^{tree}^)");
  qmf->qmfShortOfLongTmpl = box_dv_short_string (" DB.DBA.RDF_OBJ_OF_LONG (^{tree}^)");
  qmf->qmfShortOfUriTmpl = box_dv_short_string (" DB.DBA.RDF_MAKE_IID_OF_QNAME_SAFE (^{tree}^)");
  qmf->qmfCmpFuncName = box_dv_short_string ("DB.DBA.RDF_OBJ_CMP");
  qmf->qmfTypeminTmpl = box_dv_short_string (" DB.DBA.RDF_TYPEMIN_OF_OBJ (^{tree}^)");
  qmf->qmfTypemaxTmpl = box_dv_short_string (" DB.DBA.RDF_TYPEMAX_OF_OBJ (^{tree}^)");
  qmf->qmfOkForAnySqlvalue = 1; /* It can store anything */
  qmf->qmfValRange.rvrRestrictions = SPART_VARR_NOT_NULL;
  qmf->qmfValRange.rvrDatatype = NULL;
  qmf->qmfValRange.rvrLanguage = NULL;
  qmf->qmfValRange.rvrFixedValue = NULL;
  qmf->qmfValRange.rvrIriClasses = NULL;
  qmf->qmfValRange.rvrIriClassCount = 0;
  qmf->qmfUriIdOffset = 0;

  qmf = qm_format_default_ref = box_copy (qm_format_default_iri_ref);
  qmf->qmfName = box_dv_short_string ("default-iid");
  qmf->qmfValRange.rvrRestrictions = SPART_VARR_IS_REF | SPART_VARR_NOT_NULL;

  qm_format_default_ref->qmfSuperFormats = (qm_format_t**) list (1, qm_format_default);
  qm_format_default_iri_ref->qmfSuperFormats = (qm_format_t**) list (2, qm_format_default_ref, qm_format_default);

  qm_default_values[SPART_TRIPLE_GRAPH_IDX]->qmvFormat = qm_format_default_iri_ref;
  qm_default_values[SPART_TRIPLE_SUBJECT_IDX]->qmvFormat = qm_format_default_ref;
  qm_default_values[SPART_TRIPLE_PREDICATE_IDX]->qmvFormat = qm_format_default_iri_ref;
  qm_default_values[SPART_TRIPLE_OBJECT_IDX]->qmvFormat = qm_format_default;

  qm_default = dk_alloc_box_zero (sizeof (quad_map_t), DV_ARRAY_OF_POINTER);
  qm_default->qmGraphMap = qm_default_values[SPART_TRIPLE_GRAPH_IDX];
  qm_default->qmSubjectMap = qm_default_values[SPART_TRIPLE_SUBJECT_IDX];
  qm_default->qmPredicateMap = qm_default_values[SPART_TRIPLE_PREDICATE_IDX];
  qm_default->qmObjectMap = qm_default_values[SPART_TRIPLE_OBJECT_IDX];
  qm_default->qmTableName = box_dv_short_string ("DB.DBA.RDF_QUAD");

  rdf_sys_storage = dk_alloc_box_zero (sizeof (quad_storage_t), DV_ARRAY_OF_POINTER);
  rdf_sys_storage->qsDefaultMap = qm_default;

#if 0
/* system data source itself */
  qm->rdfd_pred_mappings = (rdf_ds_pred_mapping_t *)list (0);
  qm->rdfd_base_table="DB.DBA.RDF_QUAD";
  qm->rdfd_uri_local_table="DB.DBA.RDF_IRI";
  qm->rdfd_uri_ns_table="DB.DBA.RDF_NS";
  qm->rdfd_uri_lob_table="DB.DBA.RDF_LOB";
  qm->rdfd_allmappings_view = NULL;
#endif
}

ssg_valmode_t
ssg_find_valmode_by_name (ccaddr_t name)
{
  if (NULL == name)
    return NULL;
  if (!strcmp (name, "SQLVAL"))
    return SSG_VALMODE_SQLVAL;
  else if (!strcmp (name, "LONG"))
    return SSG_VALMODE_LONG;
  spar_error (NULL, "Unsupported valmode name '%.30s', only 'SQLVAL' and 'LONG' are supported", name);
  return NULL; /* to keep compiler happy */
}

const char *ssg_find_formatter_by_name_and_subtype (ccaddr_t name, ptrlong subtype)
{
  if (NULL == name)
    return NULL;
  if (!strcmp (name, "RDF/XML"))
    switch (subtype)
      {
      case SELECT_L: case DISTINCT_L: return "DB.DBA.RDF_FORMAT_RESULT_SET_AS_RDF_XML";
      case CONSTRUCT_L: case DESCRIBE_L: return "DB.DBA.RDF_FORMAT_TRIPLE_DICT_AS_RDF_XML";
      case ASK_L: return "DB.DBA.RDF_FORMAT_BOOL_RESULT_AS_RDF_XML";
      default: return NULL;
      }
  if (!strcmp (name, "TURTLE") || !strcmp (name, "TTL"))
    switch (subtype)
      {
      case SELECT_L: case DISTINCT_L: return "DB.DBA.RDF_FORMAT_RESULT_SET_AS_TTL";
      case CONSTRUCT_L: case DESCRIBE_L: return "DB.DBA.RDF_FORMAT_TRIPLE_DICT_AS_TTL";
      case ASK_L: return "DB.DBA.RDF_FORMAT_BOOL_RESULT_AS_TTL";
      default: return NULL;
      }
  spar_error (NULL, "Unsupported format name '%.30s', only 'RDF/XML' and 'TURTLE' are supported", name);
  return NULL; /* to keep compiler happy */
}

/* Dependency tracking */

void
sparp_jso_push_affected (sparp_t *sparp, ccaddr_t inst_iri)
{
  dk_set_t *set_ptr = &(sparp->sparp_env->spare_qm_affected_jso_iris);
  if (0 > dk_set_position_of_string (set_ptr[0], inst_iri))
    t_set_push (set_ptr, inst_iri);
}

void
sparp_jso_push_deleted (sparp_t *sparp, ccaddr_t class_iri, ccaddr_t inst_iri)
{
  dk_set_t *set_ptr = &(sparp->sparp_env->spare_qm_deleted);
  t_set_push (set_ptr, class_iri);
  t_set_push (set_ptr, inst_iri);
}

void 
ssg_qr_uses_jso (spar_sqlgen_t *ssg, ccaddr_t jso_inst, ccaddr_t jso_name)
{
  comp_context_t *cc;
  if (NULL == jso_name)
     {
      jso_rtti_t *jso_rtti = gethash (jso_inst, jso_rttis_of_names);
      if (NULL == jso_rtti)
        spar_internal_error (ssg->ssg_sparp, "sg_qr_uses_jso (): reference to lost object");
      jso_name = jso_rtti->jrtti_inst_iri;
     }
  cc = ssg->ssg_sc->sc_cc;
  if (NULL != cc)
    {
      box_dv_uname_make_immortal (jso_name);
      qr_uses_jso (cc->cc_super_cc->cc_query, jso_name);
    }
}

void
ssg_qr_uses_table (spar_sqlgen_t *ssg, const char *tbl)
{
  comp_context_t *cc;
  cc = ssg->ssg_sc->sc_cc;
  if (NULL != cc)
    {
      qr_uses_table (cc->cc_super_cc->cc_query, tbl);
    }
}

/* Printer */

ccaddr_t ssg_id_of_gp_or_triple (SPART *tree)
{
  switch (tree->type)
    {
    case SPAR_GP: return tree->_.gp.selid;
    case SPAR_TRIPLE: return tree->_.triple.tabid;
    default: spar_internal_error (NULL, "ssg_id_of_gp_or_triple(): bad arg");
    }
  return NULL;
}

ccaddr_t ssg_find_jl_by_jr (spar_sqlgen_t *ssg, SPART *gp, ccaddr_t jr_alias)
{
  int ctr;
  for (ctr = BOX_ELEMENTS_INT_0 (gp->_.gp.members) - 1; ctr--; /*no step*/)
    {
      SPART *sub = gp->_.gp.members[ctr+1];
      if (!strcmp (ssg_id_of_gp_or_triple (sub), jr_alias))
        return ssg_id_of_gp_or_triple (gp->_.gp.members[ctr]);
    }
  return "";
}


int
ssg_print_tmpl_phrase (struct spar_sqlgen_s *ssg, qm_format_t *qm_fmt, const char *tmpl, const char *tmpl_end, caddr_t alias, qm_value_t *qm_val, SPART *tree, int col_idx, const char *asname)
{
  const char *tail;
  const char *cmd;
  const char *delim_hit;
  int cmdlen;
  int asname_printed = 0;
  tail = tmpl;
  while (tail < tmpl_end)
    {
      delim_hit = strstr (tail, "^{");
      if ((NULL == delim_hit) || (delim_hit >= tmpl_end))
        {
          session_buffered_write (ssg->ssg_out, tail, tmpl_end - tail);
          return asname_printed;
        }
      session_buffered_write (ssg->ssg_out, tail, delim_hit - tail);
      cmd = delim_hit + 2;
      delim_hit = strstr (cmd, "}^");
      if ((NULL == delim_hit) || (delim_hit > tmpl_end))
        spar_sqlprint_error2 ("ssg_print_tmpl_phrase(): syntax error in template string", asname_printed);
      cmdlen = delim_hit - cmd;
      tail = delim_hit + 2;
#define CMD_EQUAL(w,l) ((l == cmdlen) && (!memcmp (w, cmd, l)))
/*                   0         1         2 */
/*                   012345678901234567890 */
      if (CMD_EQUAL("N", 1))
        {
          char buf[10];
          if (col_idx < 0)
            spar_sqlprint_error2 ("ssg_print_tmpl(): can't use column number outside the loop", asname_printed);
          sprintf (buf, "%d", col_idx);
          ssg_puts (buf);
        }
/*                        0         1         2 */
/*                        012345678901234567890 */
      else if (CMD_EQUAL("alias", 5))
        {
          if (NULL == alias)
            spar_sqlprint_error2 ("ssg_print_tmpl(): can't print NULL alias", asname_printed);
          ssg_prin_id (ssg, alias);
        }
/*                        0         1         2 */
/*                        012345678901234567890 */
      else if (CMD_EQUAL("as-name", 7))
        {
          if (col_idx >= 0)
            spar_sqlprint_error2 ("ssg_print_tmpl(): can't use ^{as-name}^ inside a loop, should be ^{as-name-N}^", asname_printed);
          if (IS_BOX_POINTER (asname))
            {
              ssg_puts (" AS /*as-name*/ ");
              ssg_prin_id (ssg, asname);
            }
          asname_printed = 1;
        }
/*                        0         1         2 */
/*                        012345678901234567890 */
      else if (CMD_EQUAL("as-name-N", 9))
        {
          if (col_idx < 0)
            spar_sqlprint_error2 ("ssg_print_tmpl(): can't use ^{as-name-N}^ outside a loop, should be ^{as-name}^", asname_printed);
          if (IS_BOX_POINTER (asname))
            {
              char buf[60];
              sprintf (buf, "%s~%d", asname, col_idx);
              ssg_puts (" AS /*as-name-N*/ ");
              ssg_prin_id (ssg, buf);
              asname_printed = 1;
        }
        }
/*                        0         1         2 */
/*                        012345678901234567890 */
      else if (CMD_EQUAL("alias-dot", 9))
        {
          if (NULL != alias)
            {
              ssg_prin_id (ssg, alias);
              ssg_putchar ('.');
            }
        }
/*                        0         1         2 */
/*                        012345678901234567890 */
      else if (CMD_EQUAL("column", 6))
        {
          if (NULL == qm_val)
            spar_sqlprint_error2 ("ssg_print_tmpl(): can't use ^{column}^ if qm_val is NULL", asname_printed);
          if (1 != BOX_ELEMENTS (qm_val->qmvColumns))
            spar_sqlprint_error2 ("ssg_print_tmpl(): can't use ^{column}^ if qm_val has more than one column", asname_printed);
          if (col_idx >= 0)
            spar_sqlprint_error2 ("ssg_print_tmpl(): can't use ^{column}^ inside a loop, should be ^{column-N}^", asname_printed);
          ssg_prin_id (ssg, qm_val->qmvColumns[0]->qmvcColumnName);
        }
/*                        0         1         2 */
/*                        012345678901234567890 */
      else if (CMD_EQUAL("column-0", 8))
        {
          if (NULL == qm_val)
            spar_sqlprint_error2 ("ssg_print_tmpl(): can't use ^{column-0}^ if qm_val is NULL", asname_printed);
          ssg_prin_id (ssg, qm_val->qmvColumns[0]->qmvcColumnName);
        }
/*                        0         1         2 */
/*                        012345678901234567890 */
      else if (CMD_EQUAL("column-N", 8))
        {
          if (NULL == qm_val)
            spar_sqlprint_error2 ("ssg_print_tmpl(): can't use ^{column-N}^ if qm_val is NULL", asname_printed);
          if (col_idx < 0)
            spar_sqlprint_error2 ("ssg_print_tmpl(): can't use ^{column-N}^ outside a loop", asname_printed);
          ssg_prin_id (ssg, qm_val->qmvColumns[col_idx]->qmvcColumnName);
        }
/*                        0         1         2 */
/*                        012345678901234567890 */
      else if (CMD_EQUAL("comma-list-begin", 16))
        {
          int colctr, colcount;
          const char *loop_end;
/*                                       0         1         2 */
/*                                       012345678901234567890 */
          loop_end = strstr (delim_hit, "^{end}^");
          if (NULL == qm_val)
            spar_sqlprint_error2 ("ssg_print_tmpl(): can't use ^{comma-list-begin}^ if qm_val is NULL", asname_printed);
          if (col_idx > 0)
            spar_sqlprint_error2 ("ssg_print_tmpl(): can't use ^{comma-list-begin}^ inside the loop", asname_printed);
          if (NULL == loop_end)
            spar_sqlprint_error2 ("ssg_print_tmpl(): ^{comma-list-begin}^ without matching ^{end}^", asname_printed);
          colcount = BOX_ELEMENTS (qm_val->qmvColumns);
          for (colctr = 0; colctr < colcount; colctr++)
            {
              if (0 != colctr)
                ssg_puts (", ");
              asname_printed |= ssg_print_tmpl_phrase (ssg, qm_fmt, tail, loop_end, alias, qm_val, tree, colctr, asname);
            }
          tail = loop_end + 7;
        }
/*                        0         1         2 */
/*                        012345678901234567890 */
      else if (CMD_EQUAL("tree", 4))
        {
          if (NULL == tree)
            {
              if (NULL == qm_fmt)
                spar_sqlprint_error2 ("ssg_print_tmpl(): can't use ^{tree}^ if qm_fmt is NULL", asname_printed);
              if (tmpl == qm_fmt->qmfShortTmpl)
                spar_sqlprint_error2 ("ssg_print_tmpl(): can't use ^{tree}^ in qmfShortTmpl: infinite recursion", asname_printed);
              ssg_print_tmpl (ssg, qm_fmt, qm_fmt->qmfShortTmpl, alias, qm_val, NULL, NULL_ASNAME);
            }
          else
            ssg_print_scalar_expn (ssg, tree, SSG_VALMODE_AUTO, NULL_ASNAME);
        }
/*                        0         1         2 */
/*                        012345678901234567890 */
      else if (CMD_EQUAL("tree-N", 6))
        {
          if (NULL == tree)
            {
              if (NULL == qm_fmt)
                spar_sqlprint_error2 ("ssg_print_tmpl(): can't use ^{tree-N}^ if qm_fmt is NULL", asname_printed);
              if (tmpl == qm_fmt->qmfShortTmpl)
                spar_sqlprint_error2 ("ssg_print_tmpl(): can't use ^{tree-N}^ in qmfShortTmpl: infinite recursion", asname_printed);
              ssg_print_tmpl (ssg, qm_fmt, qm_fmt->qmfShortTmpl, alias, qm_val, NULL, COL_IDX_ASNAME + col_idx);
        }
      else
            ssg_print_scalar_expn (ssg, tree, SSG_VALMODE_AUTO, COL_IDX_ASNAME + col_idx);
        }
/*                        0         1         2 */
/*                        012345678901234567890 */
      else if (CMD_EQUAL("tree-as-name", 12))
        {
          if (NULL == tree)
            {
              if (NULL == qm_fmt)
                spar_sqlprint_error2 ("ssg_print_tmpl(): can't use ^{tree-as-name}^ if qm_fmt is NULL", asname_printed);
              if (tmpl == qm_fmt->qmfShortTmpl)
                spar_sqlprint_error2 ("ssg_print_tmpl(): can't use ^{tree-as-name}^ in qmfShortTmpl: infinite recursion", asname_printed);
              ssg_print_tmpl (ssg, qm_fmt, qm_fmt->qmfShortTmpl, alias, qm_val, NULL, asname);
            }
          else
            ssg_print_scalar_expn (ssg, tree, SSG_VALMODE_AUTO, asname);
          asname_printed = 1;
        }
/*                         0         1         2 */
/*                         012345678901234567890 */
      else if (CMD_EQUAL ("sqlval-of-tree", 14))
        ssg_print_scalar_expn (ssg, tree, SSG_VALMODE_SQLVAL, NULL_ASNAME);
/*                         0         1         2 */
/*                         012345678901234567890 */
      else if (CMD_EQUAL ("datatype-of-tree", 16))
        ssg_print_scalar_expn (ssg, tree, SSG_VALMODE_DATATYPE, NULL_ASNAME);
/*                         0         1         2 */
/*                         012345678901234567890 */
      else if (CMD_EQUAL ("language-of-tree", 16))
        ssg_print_scalar_expn (ssg, tree, SSG_VALMODE_LANGUAGE, NULL_ASNAME);
/*                         0         1         2 */
/*                         012345678901234567890 */
      else if (CMD_EQUAL ("custom-string-1", 15))
        {
          if (NULL == qm_fmt)
            spar_sqlprint_error2 ("ssg_print_tmpl(): can't use ^{custom-string-1}^ if qm_fmt is NULL", asname_printed);
          ssg_print_literal (ssg, uname_xmlschema_ns_uri_hash_string, (SPART *)qm_fmt->qmfCustomString1);
        }
/*                         0         1         2 */
/*                         012345678901234567890 */
      else if (CMD_EQUAL ("custom-verbatim-1", 17))
        {
          if (NULL == qm_fmt)
            spar_sqlprint_error2 ("ssg_print_tmpl(): can't use ^{custom-verbatim-1}^ if qm_fmt is NULL", asname_printed);
          ssg_puts (qm_fmt->qmfCustomString1);
        }
/*                         0         1         2 */
/*                         012345678901234567890 */
      else if (CMD_EQUAL ("URIQADefaultHost", 16))
        {
          caddr_t subst;
          IN_TXN;
          subst = registry_get ("URIQADefaultHost");
          LEAVE_TXN;
          if (NULL == subst)
            spar_sqlprint_error2 ( "Unable to use ^{URIQADefaultHost}^ in IRI template if DefaultHost is not specified in [URIQA] section of Virtuoso config", asname_printed);
          ssg_puts (subst);
        }
      else
        spar_sqlprint_error2 ("ssg_print_tmpl(): unsupported keyword in ^{...}^", asname_printed);
    }
  return asname_printed;
}


void ssg_print_tmpl (struct spar_sqlgen_s *ssg, qm_format_t *qm_fmt, ccaddr_t tmpl, caddr_t alias, qm_value_t *qm_val, SPART *tree, const char *asname)
{
  const char *tmpl_end;
  int asname_printed;
  if (NULL == tmpl)
    spar_internal_error (ssg->ssg_sparp, "Uninitialized template detected; it's probably due to incomplete declaration of some quad mapping data format");
  tmpl_end = tmpl; while ('\0' != tmpl_end[0]) tmpl_end++;
  if (NULL == qm_val)
    {
      ptrlong tree_type = SPART_TYPE (tree);
      switch (tree_type)
        {
        case SPAR_RETVAL:
          if (NULL != tree->_.retval.triple)
            {
              quad_map_t *qm = tree->_.retval.triple->_.triple.qm_list[0];
              qm_val = SPARP_FIELD_QMV_OF_QM (qm,tree->_.retval.tr_idx);
            }
    }
    }
  if ((NULL != asname) && !IS_BOX_POINTER (asname))
    {
      const char *loop_begin, *loop_end;
/*                                0         1         2 */
/*                                012345678901234567890 */
      loop_begin = strstr (tmpl, "-list-begin}^");
      if (NULL == loop_begin)
        spar_sqlprint_error ("ssg_print_tmpl(): no list in template for printing one part of list");
      loop_begin += 13;
      loop_end = strstr (loop_begin, "^{end}^");
      if (NULL == loop_begin)
        spar_sqlprint_error ("ssg_print_tmpl(): list-begin}^ without ^{end}^");
      ssg_print_tmpl_phrase (ssg, qm_fmt, loop_begin, loop_end, alias, qm_val, tree, asname - COL_IDX_ASNAME, NULL_ASNAME);
  return;
    }
  asname_printed = ssg_print_tmpl_phrase (ssg, qm_fmt, tmpl, tmpl_end, alias, qm_val, tree, -1, asname);
  if (IS_BOX_POINTER (asname) && !asname_printed)
    {
      ssg_puts (" AS /*tmpl*/ ");
      ssg_prin_id (ssg, asname);
    }
}


void
ssg_prin_id (spar_sqlgen_t *ssg, const char *name)
{
#if 0
  char tmp[1000 + 1];

  sprintf_escaped_id (name, tmp, NULL);
  ssg_puts (tmp);
#else
#ifdef DEBUG
  if (NULL != strstr (name, "CRASH"))  
    ssg_puts ("!!!CRASH!!!");
#endif
  ssg_putchar ('"');
  ssg_puts (name);
  ssg_putchar ('"');
#endif
}

ssg_valmode_t
ssg_equiv_native_valmode (spar_sqlgen_t *ssg, SPART *gp, sparp_equiv_t *eq)
{
  caddr_t name_as_expn = NULL;
  int var_count = eq->e_var_count;
  int var_ctr;
  ssg_valmode_t largest_intersect, largest_optional_intersect;
  int gp_member_idx;
  if (NULL == eq)
    return NULL;
  if (SPART_VARR_FIXED & eq->e_rvr.rvrRestrictions)
    {
      return SSG_VALMODE_SQLVAL;
    }
  if (UNION_L == gp->_.gp.subtype)
    {
      ssg_valmode_t smallest_union = SSG_VALMODE_AUTO;
  DO_BOX_FAST (SPART *, gp_member, gp_member_idx, gp->_.gp.members)
    {
      sparp_equiv_t *member_eq;
      ssg_valmode_t member_valmode;
      if (SPAR_GP != SPART_TYPE (gp_member))
        continue;
      member_eq = sparp_equiv_get_subvalue_ro (ssg->ssg_equivs, ssg->ssg_equiv_count, gp_member, eq);
      if (NULL == member_eq)
        continue;
      member_valmode = ssg_equiv_native_valmode (ssg, gp_member, member_eq);
      if (NULL == member_valmode)
        continue;
          smallest_union = ssg_smallest_union_valmode (smallest_union, member_valmode);
        }
      END_DO_BOX_FAST;
#ifdef DEBUG
      if (0 != var_count)
        spar_internal_error (ssg->ssg_sparp, "ssg_equiv_native_valmode(): union should not contain local variables");
#endif
      return smallest_union;
        }
  largest_intersect = SSG_VALMODE_AUTO;
  largest_optional_intersect = SSG_VALMODE_AUTO;
  for (var_ctr = 0; var_ctr < var_count; var_ctr++)
        {
      SPART *var = eq->e_vars[var_ctr];
      SPART *triple;
      caddr_t tabid = var->_.var.tabid;
      int tr_idx;
      ssg_valmode_t tr_valmode;
      if (NULL == tabid)
        continue; /* because next loop will do complex cases with care, and OPTIONs are not good candidates if there are SPART_VARR_NOT_NULL items */
      triple = sparp_find_triple_of_var (ssg->ssg_sparp, gp, var);
#ifdef DEBUG
      if (SPAR_TRIPLE != SPART_TYPE (triple))
        spar_internal_error (ssg->ssg_sparp, "ssg_equiv_native_valmode(): bad tabid of a variable");
#endif
      tr_idx = var->_.var.tr_idx;
#ifdef DEBUG
      if (NULL == triple->_.triple.qm_list)
        spar_internal_error (ssg->ssg_sparp, "ssg_equiv_native_valmode(): NULL == qm_list");
#endif
      tr_valmode = triple->_.triple.native_formats[tr_idx];
      largest_intersect = ssg_largest_intersect_valmode (largest_intersect, tr_valmode);
        }
  DO_BOX_FAST (SPART *, gp_member, gp_member_idx, gp->_.gp.members)
    {
      sparp_equiv_t *member_eq;
      ssg_valmode_t member_valmode;
      if (SPAR_GP != SPART_TYPE (gp_member))
        continue;
      member_eq = sparp_equiv_get_subvalue_ro (ssg->ssg_equivs, ssg->ssg_equiv_count, gp_member, eq);
      if (NULL == member_eq)
        continue;
      member_valmode = ssg_equiv_native_valmode (ssg, gp_member, member_eq);
      if (member_eq->e_rvr.rvrRestrictions & SPART_VARR_NOT_NULL)
        largest_intersect = ssg_largest_intersect_valmode (largest_intersect, member_valmode);
      else if (SSG_VALMODE_AUTO == largest_intersect)
        largest_optional_intersect = ssg_largest_intersect_valmode (largest_optional_intersect, member_valmode);
    }
  END_DO_BOX_FAST;
  if (SSG_VALMODE_AUTO != largest_intersect)
    return largest_intersect;
  return largest_optional_intersect;
}


ssg_valmode_t
ssg_expn_native_valmode (spar_sqlgen_t *ssg, SPART *tree)
{
  switch (SPART_TYPE (tree))
    {
    case BOP_EQ: case BOP_NEQ: case BOP_LT: case BOP_LTE: case BOP_GT: case BOP_GTE:
    /*case BOP_LIKE: Like is built-in in SPARQL, not a BOP! */
    case BOP_SAME: case BOP_NSAME:
    case BOP_AND: case BOP_OR: case BOP_NOT:
      return SSG_VALMODE_BOOL;
    case BOP_PLUS: case BOP_MINUS: case BOP_TIMES: case BOP_DIV: case BOP_MOD:
    case SPAR_LIT:
    case SPAR_QNAME:
    /*case SPAR_QNAME_NS:*/
      return SSG_VALMODE_SQLVAL;
    case SPAR_BUILT_IN_CALL:
      switch (tree->_.builtin.btype)
        {
        case IN_L: case LIKE_L: case LANGMATCHES_L: case REGEX_L: case BOUND_L:
	case isIRI_L: case isURI_L: case isBLANK_L: case isLITERAL_L: return SSG_VALMODE_BOOL;
        case IRI_L: return SSG_VALMODE_LONG;
        default: return SSG_VALMODE_SQLVAL;
        }
    case SPAR_FUNCALL:
      return ssg_rettype_of_function (ssg, tree->_.funcall.qname);
    case SPAR_CONV:
      {
        ssg_valmode_t needed = tree->_.conv.needed;
        if ((SSG_VALMODE_DATATYPE == needed) || (SSG_VALMODE_LANGUAGE == needed))
          return SSG_VALMODE_SQLVAL;
        return needed;
      }
    case SPAR_VARIABLE: case SPAR_BLANK_NODE_LABEL:
      if (SPART_VARR_FIXED & tree->_.var.rvr.rvrRestrictions)
        return SSG_VALMODE_SQLVAL;
      else if (SPART_VARR_GLOBAL & tree->_.var.rvr.rvrRestrictions)
        return ssg_rettype_of_global_param (ssg, tree->_.var.vname);
      else if (NULL != tree->_.var.tabid)
        {
          SPART *triple;
          caddr_t tabid = tree->_.var.tabid;
          int tr_idx;
          ssg_valmode_t tr_valmode;
          triple = sparp_find_triple_of_var (ssg->ssg_sparp, NULL, tree);
#ifdef DEBUG
          if (SPAR_TRIPLE != SPART_TYPE (triple))
            spar_internal_error (ssg->ssg_sparp, "ssg_expn_native_valmode(): bad tabid of a variable");
#endif
          tr_idx = tree->_.var.tr_idx;
#ifdef DEBUG
          if (NULL == triple->_.triple.qm_list)
            spar_internal_error (ssg->ssg_sparp, "ssg_expn_native_valmode(): NULL == qm_list");
#endif
          tr_valmode = triple->_.triple.native_formats[tr_idx];
          return tr_valmode;
        }
      else
        {
          ptrlong eq_idx = tree->_.var.equiv_idx;
          sparp_equiv_t *eq = ssg->ssg_equivs[eq_idx];
          SPART *gp = sparp_find_gp_by_eq_idx (ssg->ssg_sparp, eq_idx);
          return ssg_equiv_native_valmode (ssg, gp, eq);
        }
    case SPAR_RETVAL:
      if (SPART_VARNAME_IS_GLOB (tree->_.retval.vname))
        return ssg_rettype_of_global_param (ssg, tree->_.retval.vname);
      else if (NULL != tree->_.retval.tabid)
        {
          int tr_idx = tree->_.retval.tr_idx;
          SPART *triple = tree->_.retval.triple;
#ifdef DEBUG
          if (SPAR_TRIPLE != SPART_TYPE (triple))
            spar_internal_error (ssg->ssg_sparp, "ssg_expn_native_valmode(): bad triple of a retval");
          if (1 != BOX_ELEMENTS_0 (triple->_.triple.qm_list))
            spar_internal_error (ssg->ssg_sparp, "ssg_expn_native_valmode(): lengths of triple->_.triple.qm_list differs from 1");
#endif
          return triple->_.triple.native_formats[tr_idx];
        }
      else
        {
          SPART *gp = tree->_.retval.gp;
          sparp_equiv_t *eq;
          if (NULL == gp)
            gp = sparp_find_gp_by_alias (ssg->ssg_sparp, tree->_.retval.selid);
          eq = sparp_equiv_get_ro (
            ssg->ssg_equivs, ssg->ssg_equiv_count, gp, tree,
            SPARP_EQUIV_GET_NAMESAKES | SPARP_EQUIV_GET_ASSERT );
          return ssg_equiv_native_valmode (ssg, gp, eq);
        }
    default: spar_internal_error (NULL, "Unsupported case in ssg_expn_native_valmode()");
    }
  return NULL; /* Never reached, to keep compiler happy */
}


void
ssg_print_box_as_sqlval (spar_sqlgen_t *ssg, caddr_t box)
{
  char smallbuf[MAX_QUAL_NAME_LEN + 100 + BOX_AUTO_OVERHEAD];
  size_t buflen;
  caddr_t tmpbuf;
  int buffill = 0;
  dtp_t dtp = DV_TYPE_OF (box);
  buflen = 20 + (IS_BOX_POINTER(box) ? box_length (box) * 3 : 20);
  BOX_AUTO (tmpbuf, smallbuf, buflen, DV_STRING);
  ssg_putchar (' ');
  switch (dtp)
    {
    case DV_LONG_INT:
      buffill = sprintf (tmpbuf, "%ld", unbox (box));
      break;
    case DV_DB_NULL:
      strcpy (tmpbuf, "NULL"); buffill = 4;
      break;
    case DV_STRING:
      sqlc_string_literal (tmpbuf, buflen, &buffill, box);
      break;
    case DV_UNAME:
      ssg_puts ("UNAME");
      sqlc_string_literal (tmpbuf, buflen, &buffill, box);
      break;
    case DV_WIDE:
      ssg_puts ("N");
      sqlc_wide_string_literal (tmpbuf, buflen, &buffill, (wchar_t *) box);
      break;
    case DV_DOUBLE_FLOAT:
      buffill = sprintf (tmpbuf, "%lg", unbox_double (box));
      break;
    case DV_NUMERIC:
      numeric_to_string ((numeric_t)box, tmpbuf, buflen);
      buffill = strlen (tmpbuf);
      break;
#if 0
#ifndef MAP_DIRECT_BIN_CHAR
    case DV_BIN:
	{
	  caddr_t bin_literal_prefix = rds_get_info (target_rds, -4);
	  caddr_t bin_literal_suffix = rds_get_info (target_rds, -5);
	  if (bin_literal_prefix)
	    sprintf_more (text, tlen, fill, "%s", bin_literal_prefix);
	  sqlc_bin_dv_print (exp, text, tlen, fill);
	  if (bin_literal_suffix)
	    sprintf_more (text, tlen, fill, "%s", bin_literal_suffix);
	  sc->sc_exp_sqt.sqt_dtp = dtp;
	}
      break;
#endif
#endif
    case DV_DATETIME:
      ssg_puts ("CAST ('");
      dt_to_string (box, tmpbuf, buflen);
      ssg_puts (tmpbuf);
      ssg_puts ("' AS DATETIME)");
      break;
    case DV_DATE:
      ssg_puts ("CAST ('");
      dt_to_string (box, tmpbuf, buflen);
      ssg_puts (tmpbuf);
      ssg_puts ("' AS DATE)");
      break;
    case DV_TIME:
      ssg_puts ("CAST ('");
      dt_to_string (box, tmpbuf, buflen);
      ssg_puts (tmpbuf);
      ssg_puts ("' AS DATETIME)");
      break;
    default:
      spar_error (ssg->ssg_sparp, "Current implementation of SPARQL does not supports literals of type %s", dv_type_title (dtp));
      }
  session_buffered_write (ssg->ssg_out, tmpbuf, buffill);
  BOX_DONE (tmpbuf, smallbuf);
}

void
ssg_print_literal (spar_sqlgen_t *ssg, ccaddr_t type, SPART *lit)
{
  caddr_t value;
  int fill = 0;
  if (DV_ARRAY_OF_POINTER == DV_TYPE_OF (lit))
    {
      if (SPAR_LIT == lit->type)
        value = lit->_.lit.val;
      else if ((SPAR_QNAME == lit->type)/* || (SPAR_QNAME_NS == lit->type)*/)
        value = lit->_.lit.val;
      else
        {
          spar_sqlprint_error ("ssg_print_literal(): non-lit tree as argument");
          value = BADBEEF_BOX; /* To keep gcc 4.0 happy */
        }
    }
  else
    value = (caddr_t)lit;
  if (uname_xmlschema_ns_uri_hash_boolean == type)
    {
      if (unbox (value))
        ssg_puts ("(1=1)");
      else
        ssg_puts ("(1=2)");
      return;
    }
  ssg_print_box_as_sqlval (ssg, value);
}

void
ssg_print_literal_as_long (spar_sqlgen_t *ssg, SPART *lit)
{
  caddr_t value;
  int fill = 0;
  dtp_t value_dtp;
  caddr_t datatype = NULL;
  caddr_t language = NULL;
  if (DV_ARRAY_OF_POINTER == DV_TYPE_OF (lit))
    {
      if (SPAR_LIT == lit->type)
        {
          value = lit->_.lit.val;
          datatype = lit->_.lit.datatype;
          language = lit->_.lit.language;
        }
      else if ((SPAR_QNAME == lit->type)/* || (SPAR_QNAME_NS == lit->type)*/)
        {
          ssg_puts (" DB.DBA.RDF_MAKE_IID_OF_QNAME (");
          ssg_print_literal (ssg, NULL, lit);
          ssg_putchar (')');
          return;
        }
      else
        spar_sqlprint_error ("ssg_print_literal_as_long(): non-lit tree as argument");   
    }
  else
    value = (caddr_t)lit;
  value_dtp = DV_TYPE_OF (value);
  if ((DV_STRING == value_dtp) && ((NULL != datatype) || (NULL != language)))
    {
      ssg_puts (" DB.DBA.RDF_MAKE_LONG_OF_TYPEDSQLVAL (");
      ssg_print_literal (ssg, NULL, lit);
      ssg_putchar (',');
      if (NULL != datatype)
        ssg_print_literal (ssg, NULL, (SPART *)datatype);
      else
        ssg_puts (" NULL");
      ssg_putchar (',');
      if (NULL != language)
        ssg_print_literal (ssg, NULL, (SPART *)language);
      else
        ssg_puts (" NULL");
      ssg_putchar (')');
      return;
    }
  ssg_print_box_as_sqlval (ssg, value);
}

void
ssg_print_equiv (spar_sqlgen_t *ssg, caddr_t selectid, sparp_equiv_t *eq, ccaddr_t asname)
{
  caddr_t name_as_expn = NULL;
  if (SPART_VARR_FIXED & eq->e_rvr.rvrRestrictions)
    ssg_print_literal (ssg, NULL, eq->e_rvr.rvrFixedValue);
  else
    {
      if (NULL != selectid)
        {
          ssg_prin_id (ssg, selectid);
          ssg_putchar ('.');
        }
      name_as_expn = eq->e_varnames[0];
      ssg_prin_id (ssg, name_as_expn);
    }
  if (IS_BOX_POINTER (asname) &&
    ((NULL == name_as_expn) || strcmp (asname, name_as_expn)) )
    {
      ssg_puts (" AS /*equiv*/ ");
      ssg_prin_id (ssg, asname);
    }
}

/*static const char *field_names[] = {"G", "S", "P", "O"}; -- unusable when mapping is implemented, cols may have any names */

void
ssg_print_tr_field_expn (spar_sqlgen_t *ssg, qm_value_t *field, caddr_t tabid, ssg_valmode_t needed, const char *asname)
{
  ccaddr_t tmpl = NULL;
  if (NULL == tabid)
    spar_sqlprint_error ("ssg_print_tr_field_expn(): no tabid");
  if (IS_BOX_POINTER (needed))
    {
      if (ssg_valmode_is_subformat_of (field->qmvFormat, needed))
        tmpl = field->qmvFormat->qmfShortTmpl;
  else
        spar_sqlprint_error ("ssg_print_tr_field_expn(): unsupported custom needed");
    }
  else
    {
      if (SSG_VALMODE_LONG == needed)
        tmpl = field->qmvFormat->qmfLongTmpl;
      else if (SSG_VALMODE_SQLVAL == needed)
        tmpl = field->qmvFormat->qmfSqlvalTmpl;
      else if (SSG_VALMODE_BOOL == needed)
        tmpl = field->qmvFormat->qmfBoolTmpl;
      else if (SSG_VALMODE_AUTO == needed)
        tmpl = field->qmvFormat->qmfShortTmpl;
      else
        spar_sqlprint_error ("ssg_print_tr_field_expn(): unsupported special needed");
    }
  ssg_print_tmpl (ssg, field->qmvFormat, tmpl, tabid, field, NULL, asname);
}

void
ssg_print_tr_var_expn (spar_sqlgen_t *ssg, SPART *var, ssg_valmode_t needed, const char *asname)
{
  SPART_buf rv_buf;
  SPART *rv, *triple;
  caddr_t tabid = var->_.var.tabid;
  ssg_valmode_t native;
  quad_map_t *qm;
  qm_value_t *qmv;
  if (NULL == tabid)
    spar_sqlprint_error ("ssg_print_tr_var_expn(): no tabid");
  if (SPAR_RETVAL == var->type)
    {
      rv = var;
      triple = rv->_.retval.triple;
    }
  else
    {
  SPART_AUTO (rv, rv_buf, SPAR_RETVAL);
      memcpy (&(rv->_.retval), &(var->_.var), sizeof (rv->_.var));
      triple = rv->_.retval.triple = sparp_find_triple_of_var (ssg->ssg_sparp, NULL, var);
    }
  native = ssg_expn_native_valmode (ssg, rv);
  if (IS_BOX_POINTER (needed) &&
    IS_BOX_POINTER (native) &&
    ssg_valmode_is_subformat_of (needed, native) )
    needed = native; /* !!!TBD: proper check for safety of this replacement (the value returned may be of an unexpected type) */
  qm = triple->_.triple.qm_list[0];
  qmv = JSO_FIELD_ACCESS(qm_value_t *, qm, qm_field_map_offsets[var->_.var.tr_idx])[0];
  if (NULL != qmv)
    {
      int col_count = (IS_BOX_POINTER (native) ? BOX_ELEMENTS (qmv->qmvColumns) : 1);
      int col_ctr;
      if ((1 == col_count) || (needed != native) || !IS_BOX_POINTER (asname))
        {
          rv->_.retval.vname = qmv->qmvColumns[0]->qmvcColumnName;
          ssg_print_valmoded_scalar_expn (ssg, rv, needed, native, asname);
          return;
        }
      for (col_ctr = 0; col_ctr < col_count; col_ctr++)
        {
          const char *eq_idx_asname = ((1 == col_count) ? NULL_ASNAME : (COL_IDX_ASNAME + col_ctr));
          if (col_ctr)
            ssg_puts (", ");
          rv->_.retval.vname = qmv->qmvColumns[col_ctr]->qmvcColumnName;
          ssg_print_valmoded_scalar_expn (ssg, rv, needed, native, eq_idx_asname);
        }
    }
  else
    ssg_print_valmoded_scalar_expn (ssg, rv, needed, native, asname);
}

ssg_valmode_t
ssg_smallest_union_valmode (ssg_valmode_t m1, ssg_valmode_t m2)
{
  ssg_valmode_t best;
  int ctr1, ctr2, smallest_weight;
  if (m2 == m1)
    return m1;
  if (m2 < m1)
    return ssg_smallest_union_valmode (m2, m1);
  /* Now m1 is less than m2 */
  if (SSG_VALMODE_BOOL == m2)
    return SSG_VALMODE_BOOL;
  if (!IS_BOX_POINTER (m2))
    {
      if (SSG_VALMODE_AUTO == m2)
        return m1;
      return SSG_VALMODE_LONG;
    }
  if (!IS_BOX_POINTER (m1))
    {
      if (SSG_VALMODE_SQLVAL == m1)
        {
          if (m2->qmfOkForAnySqlvalue)
            return m2;
          else
            return SSG_VALMODE_LONG;
        }
      else if (SSG_VALMODE_AUTO == m1)
        return m2;
      else
        return SSG_VALMODE_LONG;
    }
  DO_BOX_FAST (qm_format_t *, sup1, ctr1, m1->qmfSuperFormats)
    {
      if (sup1 == m2)
        return sup1;
    }
  END_DO_BOX_FAST;
  DO_BOX_FAST (qm_format_t *, sup2, ctr2, m2->qmfSuperFormats)
    {
      if (sup2 == m1)
        return sup2;
    }
  END_DO_BOX_FAST;
  best = NULL;
  smallest_weight = 0xFFFF;
  DO_BOX_FAST (qm_format_t *, sup1, ctr1, m1->qmfSuperFormats)
    {
      int sup1_weight;
      if (NULL == sup1)
        continue;
      sup1_weight = BOX_ELEMENTS_0 (sup1->qmfSuperFormats);
      if (sup1_weight >= smallest_weight)
        continue;
      DO_BOX_FAST (qm_format_t *, sup2, ctr2, m2->qmfSuperFormats)
        {
          if (sup1 == sup2)
            {
              best = sup1;
              smallest_weight = sup1_weight;
              break;
            }
        }
      END_DO_BOX_FAST;
    }
  END_DO_BOX_FAST;
  if (NULL != best)
    return best;
  return SSG_VALMODE_LONG;
}

ssg_valmode_t
ssg_largest_intersect_valmode (ssg_valmode_t m1, ssg_valmode_t m2)
{
/*  ssg_valmode_t best;*/
  int ctr1, ctr2/*, largest_weight*/;
  if (m2 == m1)
    return m1;
  if (m2 < m1)
    return ssg_largest_intersect_valmode (m2, m1);
  /* Now m1 is less than m2 */
  if (SSG_VALMODE_BOOL == m2)
    return SSG_VALMODE_BOOL;
  if (!IS_BOX_POINTER (m2))
    {
      if (SSG_VALMODE_AUTO == m2)
        return m1;
      return SSG_VALMODE_LONG;
    }
  if (!IS_BOX_POINTER (m1))
    {
      if (SSG_VALMODE_SQLVAL == m1)
        {
          if (m2->qmfOkForAnySqlvalue)
            return m2;
          else
            return SSG_VALMODE_LONG;
        }
      else if (SSG_VALMODE_AUTO == m1)
        return m2;
      else
        return SSG_VALMODE_LONG;
    }
  DO_BOX_FAST (qm_format_t *, sup1, ctr1, m1->qmfSuperFormats)
    {
      if (sup1 == m2)
            return m1;
        }
  END_DO_BOX_FAST;
  DO_BOX_FAST (qm_format_t *, sup2, ctr2, m2->qmfSuperFormats)
    {
      if (sup2 == m1)
        return m2;
    }
  END_DO_BOX_FAST;
/* Ups...
  best = NULL;
  largest_weight = -1;
  DO_BOX_FAST (qm_format_t *, sup1, ctr1, m1->qmfSuperFormats)
    {
      int sup1_weight;
      if (NULL == sup1)
        continue;
      sup1_weight = BOX_ELEMENTS_0 (sup1->qmfSuperFormats);
      if (sup1_weight >= smallest_weight)
        continue;
      DO_BOX_FAST (qm_format_t *, sup2, ctr2, m2->qmfSuperFormats)
        {
          if (sup1 == sup2)
            {
              best = sup1;
              smallest_weight = sup1_weight;
              break;
            }
        }
      END_DO_BOX_FAST;
    }
  END_DO_BOX_FAST;
  if (NULL != best)
    return best;
*/
  return SSG_VALMODE_LONG;
}

ssg_valmode_t
ssg_largest_eq_valmode (ssg_valmode_t m1, ssg_valmode_t m2)
{
/*  ssg_valmode_t best;*/
  int ctr1, ctr2/*, largest_weight*/;
  if (m2 == m1)
    {
      if (!IS_BOX_POINTER (m1))
        return m1; /* !!!TBD: SSG_VALMODE_AUTO may be bad for LONG and LONG due to an error when native valmode is LONG but the printed expn is short */;
      return SSG_VALMODE_AUTO;
    }
  if (m2 < m1)
    return ssg_largest_eq_valmode (m2, m1);
  /* Now m1 is less than m2 */
#ifdef DEBUG
  if ((SSG_VALMODE_AUTO == m1) || (SSG_VALMODE_AUTO == m2))
    GPF_T1 ("ssg_largest_eq_valmode (): SSG_VALMODE_AUTO argument");
#endif
  if (SSG_VALMODE_BOOL == m2)
    return SSG_VALMODE_BOOL;
  if (!IS_BOX_POINTER (m2))
    {
      return SSG_VALMODE_LONG;
    }
  if (!IS_BOX_POINTER (m1))
    {
      if ((SSG_VALMODE_SQLVAL == m1) && (m2->qmfOkForAnySqlvalue))
        return m2;
      return SSG_VALMODE_LONG;
    }
  DO_BOX_FAST (qm_format_t *, sup1, ctr1, m1->qmfSuperFormats)
        {
      if (sup1 == m2)
            return m2;
        }
  END_DO_BOX_FAST;
  DO_BOX_FAST (qm_format_t *, sup2, ctr2, m2->qmfSuperFormats)
    {
      if (sup2 == m1)
        return m1;
    }
  END_DO_BOX_FAST;
/* Ups...
  best = NULL;
  largest_weight = -1;
  DO_BOX_FAST (qm_format_t *, sup1, ctr1, m1->qmfSuperFormats)
    {
      int sup1_weight;
      if (NULL == sup1)
        continue;
      sup1_weight = BOX_ELEMENTS_0 (sup1->qmfSuperFormats);
      if (sup1_weight >= smallest_weight)
        continue;
      DO_BOX_FAST (qm_format_t *, sup2, ctr2, m2->qmfSuperFormats)
        {
          if (sup1 == sup2)
            {
              best = sup1;
              smallest_weight = sup1_weight;
              break;
            }
        }
      END_DO_BOX_FAST;
    }
  END_DO_BOX_FAST;
  if (NULL != best)
    return best;
*/
  return SSG_VALMODE_LONG;
}

int
ssg_valmode_is_subformat_of (ssg_valmode_t m1, ssg_valmode_t m2)
{
  int ctr1;
  if (!IS_BOX_POINTER (m1))
    GPF_T1("ssg_valmode_is_subformat_of (): special m1");
  if (!IS_BOX_POINTER (m2))
    GPF_T1("ssg_valmode_is_subformat_of (): special m2");
  if (m2 == m1)
    return 1;
  DO_BOX_FAST (qm_format_t *, sup1, ctr1, m1->qmfSuperFormats)
    {
      if (sup1 == m2)
        return 2;
    }
  END_DO_BOX_FAST;
  return 0;
}

void
ssg_print_bop_bool_expn (spar_sqlgen_t *ssg, SPART *tree, const char *bool_op, const char *sqlval_fn, int top_filter_op, ssg_valmode_t needed)
{
  SPART *left = tree->_.bin_exp.left;
  SPART *right = tree->_.bin_exp.right;
  int bop_has_bool_args = ((BOP_AND == tree->type) || (BOP_OR == tree->type));
  ssg_valmode_t left_vmode, right_vmode, min_mode;
  if (bop_has_bool_args)
    {
      left_vmode = right_vmode = min_mode = SSG_VALMODE_BOOL;
    }
  else
    {
      left_vmode = ssg_expn_native_valmode (ssg, left);
      right_vmode = ssg_expn_native_valmode (ssg, left);
      min_mode = ssg_largest_intersect_valmode (left_vmode, right_vmode);
      if (SSG_VALMODE_LONG == min_mode)
        min_mode = SSG_VALMODE_SQLVAL;
    }
  if (top_filter_op && (SSG_VALMODE_BOOL == needed))
    {
      ssg_putchar ('(');
      if (bop_has_bool_args)
        {
          ssg->ssg_indent ++;
          ssg_print_filter_expn (ssg, left);
          ssg_puts (bool_op);
          ssg_newline (1);
          ssg_print_filter_expn (ssg, right);
          ssg->ssg_indent --;
        }
      else
        {
          ssg_print_scalar_expn (ssg, left, min_mode, NULL_ASNAME);
          ssg_puts (bool_op);
          ssg_print_scalar_expn (ssg, right, min_mode, NULL_ASNAME);
        }
      ssg_putchar (')');
    }
  else if ((SSG_VALMODE_SQLVAL == needed) || (SSG_VALMODE_BOOL == needed))
    {
      ssg_puts (sqlval_fn);
      ssg_print_scalar_expn (ssg, left, min_mode, NULL_ASNAME);
      ssg_puts (", ");
      ssg_print_scalar_expn (ssg, right, min_mode, NULL_ASNAME);
      ssg_putchar (')');
    }
  else if (SSG_VALMODE_DATATYPE == needed)
    {
      ssg_print_literal (ssg, NULL, (SPART *)uname_xmlschema_ns_uri_hash_boolean);
    }
  else if (SSG_VALMODE_LANGUAGE == needed)
    {
      ssg_puts (" NULL");
    }
  else
    spar_sqlprint_error ("ssg_print_bop_bool_expn (): unsupported mode");
}

void
ssg_print_bop_calc_expn (spar_sqlgen_t *ssg, SPART *tree, const char *s1, const char *s2, const char *s3)
{
  SPART *left = tree->_.bin_exp.left;
  SPART *right = tree->_.bin_exp.right;
  ssg_puts (s1);
  ssg_print_scalar_expn (ssg, left, SSG_VALMODE_SQLVAL, NULL_ASNAME);
  ssg_puts (s2);
  if (NULL == s3)
    return;
  ssg_print_scalar_expn (ssg, right, SSG_VALMODE_SQLVAL, NULL_ASNAME);
  ssg_puts (s3);
}

void
ssg_print_bop_cmp_expn (spar_sqlgen_t *ssg, SPART *tree, const char *bool_op, const char *sqlval_fn, int top_filter_op, ssg_valmode_t needed)
{
  SPART *left = tree->_.bin_exp.left;
  SPART *right = tree->_.bin_exp.right;
  ssg_valmode_t left_native;
  ssg_valmode_t right_native;
  ssg_valmode_t smallest_union;
  const char *cmp_func_name = NULL;
  if (
    (needed != SSG_VALMODE_SQLVAL) && /* Trick! All representations are equal. */
    (needed != SSG_VALMODE_LONG) &&
    (needed != SSG_VALMODE_BOOL) )
    spar_sqlprint_error ("ssg_print_bop_cmp_expn(): unsupported valmode");
  left_native = ssg_expn_native_valmode (ssg, left);
  right_native = ssg_expn_native_valmode (ssg, right);
  smallest_union = ssg_smallest_union_valmode (left_native, right_native);
  if (SSG_VALMODE_LONG == smallest_union)
    cmp_func_name = "DB.DBA.RDF_LONG_CMP";
  else if (IS_BOX_POINTER (smallest_union))
    cmp_func_name = smallest_union->qmfCmpFuncName;
  else
    { /* Fallback to usual SQL comparison, with possible lack of type checking. */
      ssg_print_bop_bool_expn (ssg, tree, bool_op, sqlval_fn, top_filter_op, needed);
      return;
    }
  if (top_filter_op &&
    IS_BOX_POINTER (smallest_union) &&
    ((SPAR_VARIABLE == SPART_TYPE (left)) || (SPAR_BLANK_NODE_LABEL == SPART_TYPE (left)) ||
      (SPAR_VARIABLE == SPART_TYPE (right)) || (SPAR_BLANK_NODE_LABEL == SPART_TYPE (right)) ) )
    { /* Comparison that is partially optimizable for indexing */
      const char *typemin, *typemax;
      ssg_puts ("((");
      ssg->ssg_indent += 2;
      ssg_print_scalar_expn (ssg, left, smallest_union, NULL_ASNAME);
      ssg_puts (bool_op);
      ssg_print_scalar_expn (ssg, right, smallest_union, NULL_ASNAME);
      ssg_puts (") AND");
      ssg_newline(SSG_INDENT_FACTOR);
      ssg_puts ("(");
#if 1
      typemin = smallest_union->qmfTypeminTmpl;
      typemax = smallest_union->qmfTypemaxTmpl;
#endif
      if ((BOP_LT == SPART_TYPE (tree)) || (BOP_LTE == SPART_TYPE (tree)))
        {
#if 0
          if (SSG_VALMODE_SQLVAL == right_native)
            typemin = " DB.DBA.RDF_TYPEMIN_OF_SQLVAL (^{tree}^)";
          else
            typemin = right_native->qmfTypeminTmpl;
          if (SSG_VALMODE_SQLVAL == left_native)
            typemax = " DB.DBA.RDF_TYPEMAX_OF_SQLVAL (^{tree}^)";
          else
            typemax = left_native->qmfTypemaxTmpl;
#endif
          ssg_print_tmpl (ssg, smallest_union, typemin, NULL, NULL, right, NULL_ASNAME);
          ssg_puts (" <=");
          ssg_print_scalar_expn (ssg, left, smallest_union, NULL_ASNAME);
          ssg_puts (") AND");
          ssg_newline(SSG_INDENT_FACTOR);
          ssg_puts ("(");
          ssg_print_scalar_expn (ssg, right, smallest_union, NULL_ASNAME);
          ssg_puts (" <=");
          ssg_print_tmpl (ssg, smallest_union, typemax, NULL, NULL, left, NULL_ASNAME);
        }
      else
        {
#if 0
          if (SSG_VALMODE_SQLVAL == right_native)
            typemax = " DB.DBA.RDF_TYPEMAX_OF_SQLVAL (^{tree}^)";
          else
            typemax = right_native->qmfTypemaxTmpl;
          if (SSG_VALMODE_SQLVAL == left_native)
            typemin = " DB.DBA.RDF_TYPEMIN_OF_SQLVAL (^{tree}^)";
          else
            typemin = left_native->qmfTypeminTmpl;
#endif
          ssg_print_tmpl (ssg, smallest_union, typemax, NULL, NULL, right, NULL_ASNAME);
          ssg_puts (" >=");
          ssg_print_scalar_expn (ssg, left, smallest_union, NULL_ASNAME);
          ssg_puts (") AND");
          ssg_newline(SSG_INDENT_FACTOR);
          ssg_puts ("(");
          ssg_print_scalar_expn (ssg, right, smallest_union, NULL_ASNAME);
          ssg_puts (" >=");
          ssg_print_tmpl (ssg, smallest_union, typemin, NULL, NULL, left, NULL_ASNAME);
        }
      ssg->ssg_indent -= 2;
      ssg_puts ("))");
      return;
    }
/* Plain use of cmp function */  
  if (top_filter_op)
    {
      ssg_puts ("(");
      ssg_puts (cmp_func_name);
      ssg_puts ("(");
      ssg->ssg_indent += 2;
      ssg_print_scalar_expn (ssg, left, smallest_union, NULL_ASNAME);
      ssg_puts (" ,");
      ssg_print_scalar_expn (ssg, right, smallest_union, NULL_ASNAME);
      ssg->ssg_indent -= 2;
      ssg_puts (")");
      ssg_puts (bool_op);
      ssg_puts ("0)");
    }
  else
    {
      ssg_puts (sqlval_fn);
      ssg_puts (cmp_func_name);
      ssg_puts ("(");
      ssg->ssg_indent += 2;
      ssg_print_scalar_expn (ssg, left, smallest_union, NULL_ASNAME);
      ssg_puts (" ,");
      ssg_print_scalar_expn (ssg, right, smallest_union, NULL_ASNAME);
      ssg->ssg_indent -= 2;
      ssg_puts ("), 0)");
    }
  return;
}

void
ssg_print_builtin_expn (spar_sqlgen_t *ssg, SPART *tree, int top_filter_op, ssg_valmode_t needed)
{
  SPART *arg1 = tree->_.builtin.args[0];
  ssg_valmode_t arg1_native = ssg_expn_native_valmode (ssg, arg1);
  switch (tree->_.builtin.btype)
    {
    case BOUND_L:
      if (top_filter_op)
        {
          ssg_puts (" ("); ssg_print_scalar_expn (ssg, arg1, arg1_native, NULL_ASNAME); ssg_puts (" is not null)");
        }
      else
        {
          ssg_puts ("(0 = isnull ("); ssg_print_scalar_expn (ssg, arg1, arg1_native, NULL_ASNAME); ssg_puts ("))");
        }
      return;
    case DATATYPE_L:
      if (SSG_VALMODE_SQLVAL != needed)
        ssg_print_valmoded_scalar_expn (ssg, tree, needed, SSG_VALMODE_SQLVAL, NULL_ASNAME);
      else
        ssg_print_scalar_expn (ssg, arg1, SSG_VALMODE_DATATYPE, NULL_ASNAME);
      return;
    case LIKE_L:
      if (SSG_VALMODE_BOOL != needed)
        ssg_print_valmoded_scalar_expn (ssg, tree, needed, SSG_VALMODE_BOOL, NULL_ASNAME);
      else
        {
          ssg_puts (" (cast ("); ssg_print_scalar_expn (ssg, arg1, SSG_VALMODE_SQLVAL, NULL_ASNAME);
          ssg_puts (" as varchar) like cast ("); ssg_print_scalar_expn (ssg, tree->_.builtin.args[1], SSG_VALMODE_SQLVAL, NULL_ASNAME);
          ssg_puts (" as varchar))"); 
        }
      return;
    case IN_L:
      if (SSG_VALMODE_BOOL != needed)
        ssg_print_valmoded_scalar_expn (ssg, tree, needed, SSG_VALMODE_BOOL, NULL_ASNAME);
      else
        {
          int argctr;
          int format_is_common = 1;
          ssg_valmode_t op_fmt;
          DO_BOX_FAST (SPART *, argN, argctr, tree->_.builtin.args)
            {
              ssg_valmode_t argN_native;
              if (0 == argctr)
                continue;
              argN_native = ssg_expn_native_valmode (ssg, argN);
              if (argN_native != arg1_native)
                {
                  format_is_common = 0;
                  break;
                }
            }
          END_DO_BOX_FAST;
          op_fmt = (format_is_common ? arg1_native : SSG_VALMODE_SQLVAL);
          if ((SSG_VALMODE_LONG == op_fmt) ||
            (IS_BOX_POINTER (op_fmt) && (
              op_fmt->qmfOkForAnySqlvalue || !(op_fmt->qmfIsBijection) ) ) )
            op_fmt = SSG_VALMODE_SQLVAL;
          DO_BOX_FAST (SPART *, argN, argctr, tree->_.builtin.args)
            {
              switch (argctr)
                {
                case 0: ssg_puts (top_filter_op ? " (" : " position ("); break;
                case 1: ssg_puts (top_filter_op ? " in (" : ", vector ("); break;
                default: ssg_puts (" ,");
                }
              ssg_print_scalar_expn (ssg, argN, op_fmt, NULL_ASNAME);
            }
          END_DO_BOX_FAST;
          ssg_puts ("))");
        }
      return;
    case isBLANK_L:
      if (SSG_VALMODE_BOOL != needed)
        ssg_print_valmoded_scalar_expn (ssg, tree, needed, SSG_VALMODE_BOOL, NULL_ASNAME);
      else
      {
        if (IS_BOX_POINTER (arg1_native))
            ssg_print_tmpl (ssg, arg1_native, arg1_native->qmfIsblankOfShortTmpl, NULL, NULL, arg1, NULL_ASNAME);
        else if (SSG_VALMODE_LONG == arg1_native)
          ssg_print_tmpl (ssg, arg1_native,
            (top_filter_op ?
                " ((isiri_id (^{tree}^) and (^{tree}^ >= #i1000000000))" :
                " either (isiri_id (^{tree}^), gte (^{tree}^, #i1000000000), 0)" ),
              NULL, NULL, arg1, NULL );
        else if (SSG_VALMODE_SQLVAL == arg1_native)
            ssg_print_tmpl (ssg, arg1_native, " DB.DBA.RDF_IS_BLANK_REF (^{tree}^)", NULL, NULL, arg1, NULL_ASNAME);
        else
          spar_sqlprint_error ("ssg_print_scalar_expn(): bad native type for isBLANK()");
      }
      return;
    case LANG_L:
      if (SSG_VALMODE_SQLVAL != needed)
        ssg_print_valmoded_scalar_expn (ssg, tree, needed, SSG_VALMODE_SQLVAL, NULL_ASNAME);
      else
        ssg_print_scalar_expn (ssg, arg1, SSG_VALMODE_LANGUAGE, NULL_ASNAME);
      return;
    case isURI_L:
    case isIRI_L:
      if (SSG_VALMODE_BOOL != needed)
        ssg_print_valmoded_scalar_expn (ssg, tree, needed, SSG_VALMODE_BOOL, NULL_ASNAME);
      else
      {
        if (IS_BOX_POINTER (arg1_native))
            ssg_print_tmpl (ssg, arg1_native, arg1_native->qmfIsuriOfShortTmpl, NULL, NULL, arg1, NULL_ASNAME);
        else if (SSG_VALMODE_LONG == arg1_native)
          ssg_print_tmpl (ssg, arg1_native,
            (top_filter_op ?
                " ((isiri_id (^{tree}^) and (^{tree}^ < 1000000000))" :
                " either (isiri_id (^{tree}^), lt (^{tree}^, 1000000000), 0)" ),
              NULL, NULL, arg1, NULL );
        else if (SSG_VALMODE_SQLVAL == arg1_native)
            ssg_print_tmpl (ssg, arg1_native, " DB.DBA.RDF_IS_URI_REF (^{tree}^)", NULL, NULL, arg1, NULL_ASNAME);
        else
          spar_sqlprint_error ("ssg_print_scalar_expn(): bad native type for isURI()");
      }
      return;
    case isLITERAL_L:
      if (SSG_VALMODE_BOOL != needed)
        ssg_print_valmoded_scalar_expn (ssg, tree, needed, SSG_VALMODE_BOOL, NULL_ASNAME);
      else
      {
        if (IS_BOX_POINTER (arg1_native))
            ssg_print_tmpl (ssg, arg1_native, arg1_native->qmfIslitOfShortTmpl, NULL, NULL, arg1, NULL_ASNAME);
        else if (SSG_VALMODE_LONG == arg1_native)
          ssg_print_tmpl (ssg, arg1_native,
            (top_filter_op ?
                " (not (isiri_id (^{tree}^))" : "(0 = isiri_id (^{tree}^))" ),
              NULL, NULL, arg1, NULL );
        else if (SSG_VALMODE_SQLVAL == arg1_native)
            ssg_print_tmpl (ssg, arg1_native, " DB.DBA.RDF_IS_LITERAL (^{tree}^)", NULL, NULL, arg1, NULL_ASNAME);
        else
          spar_sqlprint_error ("ssg_print_scalar_expn(): bad native type for isLITERAL()");
      }
      return;
    case IRI_L:
      {
        if (SSG_VALMODE_BOOL == arg1_native)
          spar_error (ssg->ssg_sparp, "IRI() built-in function can not use boolean expression as an argument");
        if (IS_BOX_POINTER (needed))
          {
            const char *tmpl;
            if (SSG_VALMODE_SQLVAL == arg1_native)
              tmpl = needed->qmfShortOfUriTmpl;
            else
              {
                ssg_print_valmoded_scalar_expn (ssg, tree, needed, SSG_VALMODE_LONG, NULL_ASNAME);
                return;
              }
            ssg_print_tmpl (ssg, arg1_native, tmpl, NULL, NULL, arg1, NULL_ASNAME);
          }
        else if (SSG_VALMODE_SQLVAL == needed)
          {
            const char *tmpl;
            if (IS_BOX_POINTER (arg1_native))
              tmpl = arg1_native->qmfStrsqlvalOfShortTmpl;
            else if (SSG_VALMODE_LONG == arg1_native)
              tmpl = " DB.DBA.RDF_STRSQLVAL_OF_LONG (^{tree}^)";
            else if (SSG_VALMODE_SQLVAL == arg1_native)
              tmpl = " DB.DBA.RDF_STRSQLVAL_OF_SQLVAL (^{tree}^)";
            else
              spar_sqlprint_error ("ssg_print_scalar_expn(): bad native type for IRI()");
            ssg_print_tmpl (ssg, arg1_native, tmpl, NULL, NULL, arg1, NULL_ASNAME);
          }
        else if (SSG_VALMODE_LONG == needed)
          {
            const char *tmpl;
            if (IS_BOX_POINTER (arg1_native))
              tmpl = arg1_native->qmfIidOfShortTmpl;
            else if (SSG_VALMODE_LONG == arg1_native)
              tmpl = " DB.DBA.RDF_MAKE_IID_OF_LONG (^{tree}^)";
            else if (SSG_VALMODE_SQLVAL == arg1_native)
              tmpl = " DB.DBA.RDF_MAKE_IID_OF_QNAME_SAFE (^{tree}^)";
            else
              spar_sqlprint_error ("ssg_print_scalar_expn(): bad native type for IRI()");
            ssg_print_tmpl (ssg, arg1_native, tmpl, NULL, NULL, arg1, NULL_ASNAME);
          }
        else if (SSG_VALMODE_DATATYPE == needed)
          ssg_puts (" " XMLSCHEMA_NS_URI "#anyURI");
        else if (SSG_VALMODE_LANGUAGE == needed)
          ssg_puts (" NULL");
        else
          ssg_print_valmoded_scalar_expn (ssg, tree, needed, SSG_VALMODE_LONG, NULL_ASNAME);
        return;
      }
    case STR_L:
      {
        if (SSG_VALMODE_SQLVAL == needed)
          {
            const char *tmpl;
            if (IS_BOX_POINTER (arg1_native))
              tmpl = arg1_native->qmfStrsqlvalOfShortTmpl;
            else if (SSG_VALMODE_LONG == arg1_native)
              tmpl = " DB.DBA.RDF_STRSQLVAL_OF_LONG (^{tree}^)";
            else if (SSG_VALMODE_SQLVAL == arg1_native)
              tmpl = " DB.DBA.RDF_STRSQLVAL_OF_SQLVAL (^{tree}^)";
            else if (SSG_VALMODE_BOOL == arg1_native)
              tmpl = " case (^{tree}^) when 0 then 'false' else 'true' end";
            else
              spar_sqlprint_error ("ssg_print_scalar_expn(): bad native type for STR()");
            ssg_print_tmpl (ssg, arg1_native, tmpl, NULL, NULL, arg1, NULL_ASNAME);
          }
        else if (SSG_VALMODE_DATATYPE == needed)
          ssg_puts (" NULL");
        else if (SSG_VALMODE_LANGUAGE == needed)
          ssg_puts (" NULL");
        else
          ssg_print_valmoded_scalar_expn (ssg, tree, needed, SSG_VALMODE_SQLVAL, NULL_ASNAME);
        return;
      }
    case REGEX_L:
      if (SSG_VALMODE_BOOL != needed)
        ssg_print_valmoded_scalar_expn (ssg, tree, needed, SSG_VALMODE_BOOL, NULL_ASNAME);
      else
        { /*!!!TBD extra 'between'*/
          ssg_puts (" DB.DBA.RDF_REGEX (");
          ssg_print_scalar_expn (ssg, arg1, SSG_VALMODE_SQLVAL, NULL_ASNAME);
          ssg_putchar (',');
          ssg_print_scalar_expn (ssg, tree->_.builtin.args[1], SSG_VALMODE_SQLVAL, NULL_ASNAME);
          if (3 == BOX_ELEMENTS (tree->_.builtin.args))
            {
              ssg_putchar (',');
              ssg_print_scalar_expn (ssg, tree->_.builtin.args[2], SSG_VALMODE_SQLVAL, NULL_ASNAME);
            }
          ssg_putchar (')');
        }
      return;
    case LANGMATCHES_L:
      if (SSG_VALMODE_BOOL != needed)
        ssg_print_valmoded_scalar_expn (ssg, tree, needed, SSG_VALMODE_BOOL, NULL_ASNAME);
      else
        {
          ssg_puts (" DB.DBA.RDF_LANGMATCHES (");
          ssg_print_scalar_expn (ssg, arg1, SSG_VALMODE_SQLVAL, NULL_ASNAME);
          ssg_putchar (',');
          ssg_print_scalar_expn (ssg, tree->_.builtin.args[1], SSG_VALMODE_SQLVAL, NULL_ASNAME);
          ssg_putchar (')');
        }
      return;
    default:
      spar_sqlprint_error ("ssg_print_scalar_expn(): unsupported builtin");  
      return;
    }
}

xqf_str_parser_desc_t *function_is_xqf_str_parser (caddr_t name)
{
  long desc_idx;
  if (!strncmp (name, XFN_NS_URI, strlen (XFN_NS_URI)))
    name += strlen (XFN_NS_URI);
  else if (!strncmp (name, XS_NS_URI, strlen (XS_NS_URI)))
    name += strlen (XS_NS_URI);
  else
    return NULL;
  if ('#' != name[0])
    return NULL;
  name++;
  desc_idx = ecm_find_name (name, xqf_str_parser_descs_ptr,
    xqf_str_parser_desc_count, sizeof (xqf_str_parser_desc_t) );
  if (ECM_MEM_NOT_FOUND == desc_idx)
    return NULL;
  return xqf_str_parser_descs_ptr + desc_idx;
}

static ssg_valmode_t
ssg_find_valmode_by_name_prefix (spar_sqlgen_t *ssg, caddr_t name, ssg_valmode_t dflt)
{
  if (!strncmp (name, "SQLVAL::", 8))
    return SSG_VALMODE_SQLVAL;
  if (!strncmp (name, "LONG::", 6))
    return SSG_VALMODE_LONG;
  if (!strncmp (name, "BOOL::", 6))
    return SSG_VALMODE_BOOL;
  if (!strncmp (name, "SHORT::", 7))
    return qm_format_default;
  if (!strncmp (name, "SPECIAL::", 9))
    return SSG_VALMODE_SPECIAL;
  if (NULL != strstr (name, "::"))
    spar_sqlprint_error2 ("unsupported valmode", SSG_VALMODE_SQLVAL);
  return dflt;
}

ssg_valmode_t
ssg_rettype_of_global_param (spar_sqlgen_t *ssg, caddr_t name)
{
  ssg_valmode_t res = ssg_find_valmode_by_name_prefix (ssg, name+1, SSG_VALMODE_SQLVAL);
  return res;
}


ssg_valmode_t
ssg_rettype_of_function (spar_sqlgen_t *ssg, caddr_t name)
{
  ssg_valmode_t res = ssg_find_valmode_by_name_prefix (ssg, name, SSG_VALMODE_SQLVAL);
  if (SSG_VALMODE_SPECIAL == res)
    {
      if (!strcmp (name, "SPECIAL::sql:RDF_MAKE_GRAPH_IIDS_OF_QNAMES"))
        return SSG_VALMODE_LONG; /* Fake but this works for use as 2-nd arg of 'LONG::bif:position' */
      spar_sqlprint_error2 ("ssg_rettype_of_function(): unsupported SPECIAL", SSG_VALMODE_SQLVAL);
    }
  return SSG_VALMODE_SQLVAL /* not "return res" */;
}


ssg_valmode_t
ssg_argtype_of_function (spar_sqlgen_t *ssg, caddr_t name, int arg_idx)
{
  ssg_valmode_t res = ssg_find_valmode_by_name_prefix (ssg, name, SSG_VALMODE_SQLVAL);
  if (SSG_VALMODE_SPECIAL == res)
    {
      if (!strcmp (name, "SPECIAL::sql:RDF_MAKE_GRAPH_IIDS_OF_QNAMES"))
        return SSG_VALMODE_SQLVAL;
      spar_sqlprint_error2 ("ssg_argtype_of_function(): unsupported SPECIAL", SSG_VALMODE_SQLVAL);
    }
  return res;
}


void
ssg_prin_function_name (spar_sqlgen_t *ssg, ccaddr_t name)
{
  const char *delim;
  delim = strstr (name, "::");
  if (NULL != delim)
    name = delim + 2;
  if (name == strstr (name, "bif:"))
    {
      name = name + 4;
      if (!strcasecmp(name, "left"))
        ssg_puts ("\"LEFT\"");
      else if (!strcasecmp(name, "right"))
        ssg_puts ("\"RIGHT\"");
      else
        ssg_puts(name); /*not ssg_prin_id (ssg, name);*/
    }
  else if (name == strstr (name, "sql:"))
    {
      name = name + 4;
      ssg_puts ("DB.DBA.");
      ssg_puts(name); /*not ssg_prin_id (ssg, name);*/
    }
  else
    {
      ssg_puts ("DB.DBA.");
      ssg_prin_id (ssg, name);
    }
}

void ssg_print_uri_list (spar_sqlgen_t *ssg, dk_set_t uri_precodes, ssg_valmode_t needed)
{
  int uri_ctr = 0;
  DO_SET (SPART *, expn, &uri_precodes)
    {
      if (uri_ctr++)
        ssg_puts (", ");
      ssg_print_scalar_expn (ssg, expn, needed, NULL_ASNAME);
    }
  END_DO_SET ()  
}

void ssg_print_global_param (spar_sqlgen_t *ssg, caddr_t vname, ssg_valmode_t needed)
{ /* needed is always equal to native in this function */
  sparp_env_t *env = ssg->ssg_sparp->sparp_env;
  char *coloncolon = strstr (vname, "::");
  if (NULL != coloncolon)
    vname = coloncolon + 1;
  if (!strcmp (vname, SPAR_VARNAME_DEFAULT_GRAPH))
    {
      SPART *defined_precode = env->spare_default_graph_precode;
      if (NULL != defined_precode)
        {
          if (env->spare_default_graph_locked)
            {
              ssg_print_scalar_expn (ssg, defined_precode, needed, NULL_ASNAME);
              return;
            }
          ssg_puts (" coalesce (connection_get ('");
          ssg_puts (vname);
          ssg_puts ("'),");
          ssg->ssg_indent += 1;
          ssg_print_scalar_expn (ssg, defined_precode, needed, NULL_ASNAME);
          ssg->ssg_indent -= 1;
          ssg_puts (")");
          return;
        }
      ssg_puts (" connection_get ('");
      ssg_puts (vname);
      ssg_puts ("')");
      return;
    }
  else if (!strcmp (vname, SPAR_VARNAME_NAMED_GRAPHS))
    {
      dk_set_t defined_precodes = env->spare_named_graph_precodes;
      if (0 != dk_set_length (defined_precodes))
        {
          if (env->spare_named_graphs_locked)
            {
              ssg_puts (" vector (");
              ssg->ssg_indent += 1;
              ssg_print_uri_list (ssg, defined_precodes, needed);
              ssg->ssg_indent -= 1;
              ssg_puts (")");
              return;
            }
          ssg_puts (" coalesce (connection_get ('");
          ssg_puts (vname);
          ssg_puts ("'), vector (");
          ssg->ssg_indent += 2;
          ssg_print_uri_list (ssg, defined_precodes, needed);
          ssg->ssg_indent -= 2;
          ssg_puts ("))");
          return;
        }
      ssg_puts (" connection_get ('");
      ssg_puts (vname);
      ssg_puts ("')");
      return;
    }
  else if (isdigit (vname[1])) /* Numbered parameter */
    {
      ssg_puts (vname);
      return;
    }
/*
  else if (':' = vname[1])
    {
  ssg_puts (" connection_get ('");
      ssg_puts (vname+1);
  ssg_puts ("')");
    }
*/
  else
    {
      ssg_putchar (' ');
      ssg_puts (vname+1);
/* Quoted name is not a good idea due to case mode. Local vars are usually not escaped.
      ssg_prin_id (ssg, vname+1);
*/
    }
}


const char *
ssg_tmpl_X_of_short (ssg_valmode_t needed, qm_format_t *qm_fmt)
{
  if (SSG_VALMODE_LONG == needed)
    return qm_fmt->qmfLongOfShortTmpl;
  if (SSG_VALMODE_SQLVAL == needed)
    return qm_fmt->qmfSqlvalOfShortTmpl;
  if (SSG_VALMODE_DATATYPE == needed)
    return qm_fmt->qmfDatatypeOfShortTmpl;
  if (SSG_VALMODE_LANGUAGE == needed)
    return qm_fmt->qmfLanguageOfShortTmpl;
  if (SSG_VALMODE_BOOL == needed)
    return qm_fmt->qmfBoolOfShortTmpl;
  spar_internal_error (NULL, "ssg_tmpl_X_of_short(): bad mode needed");
  return NULL; /* Never reached, to keep compiler happy */
}

const char *ssg_tmpl_short_of_X (qm_format_t *qm_fmt, ssg_valmode_t native)
{
  if (SSG_VALMODE_LONG == native)	return qm_fmt->qmfShortOfLongTmpl;
  if (SSG_VALMODE_SQLVAL == native)	return qm_fmt->qmfShortOfSqlvalTmpl;
  spar_internal_error (NULL, "ssg_tmpl_short_of_X(): bad mode needed");
  return NULL; /* Never reached, to keep compiler happy */
}

const char *ssg_tmpl_X_of_Y (ssg_valmode_t needed, ssg_valmode_t native)
{
  if (SSG_VALMODE_LONG == needed)
    {
      if (SSG_VALMODE_LONG	== native)	return " ^{tree}^";
      if (SSG_VALMODE_SQLVAL	== native)	return " DB.DBA.RDF_LONG_OF_SQLVAL (^{tree}^)";
    }
  else if (SSG_VALMODE_SQLVAL == needed)
    {
      if (SSG_VALMODE_LONG	== native)	return " DB.DBA.RDF_SQLVAL_OF_LONG (^{tree}^)";
      if (SSG_VALMODE_SQLVAL	== native)	return " ^{tree}^";
    }
  else if (SSG_VALMODE_DATATYPE == needed)
    {
      if (SSG_VALMODE_LONG	== native)	return " DB.DBA.RDF_DATATYPE_OF_LONG (^{tree}^)";
      if (SSG_VALMODE_SQLVAL	== native)	return " DB.DBA.RDF_DATATYPE_OF_SQLVAL (^{tree}^)";
    }
  else if (SSG_VALMODE_LANGUAGE == needed)
    {
      if (SSG_VALMODE_LONG	== native)	return " DB.DBA.RDF_LANGUAGE_OF_LONG (^{tree}^)";
      if (SSG_VALMODE_SQLVAL	== native)	return " DB.DBA.RDF_LANGUAGE_OF_SQLVAL (^{tree}^)";
    }
  else if (SSG_VALMODE_BOOL == needed)
    {
      if (SSG_VALMODE_LONG	== native)	return " DB.DBA.RDF_BOOL_OF_LONG (^{tree}^)";
      if (SSG_VALMODE_SQLVAL	== native)	return " (^{tree}^)";
    }
  spar_internal_error (NULL, "ssg_tmpl_X_of_Y(): bad mode needed");
  return NULL; /* Never reached, to keep compiler happy */
}


void
ssg_print_valmoded_scalar_expn (spar_sqlgen_t *ssg, SPART *tree, ssg_valmode_t needed, ssg_valmode_t native, const char *asname)
{
  if ((native == needed) || (SSG_VALMODE_AUTO == needed))
    {
      ssg_print_scalar_expn (ssg, tree, native, asname);
      return;
    }
  if (SSG_VALMODE_AUTO == native)
    native = ssg_expn_native_valmode (ssg, tree);
  if (SSG_VALMODE_BOOL == native)
    {
      ssg_print_scalar_expn (ssg, tree, needed, asname);
      return;
    }
  if (IS_BOX_POINTER (native))
    {
      if (IS_BOX_POINTER (needed))
        {
          SPART_buf fromshort_buf;
          SPART *fromshort;
          if (ssg_valmode_is_subformat_of (native, needed))
            {
              ssg_print_scalar_expn (ssg, tree, native, asname);
              return;
            }
          SPART_AUTO(fromshort,fromshort_buf,SPAR_CONV);
          fromshort->_.conv.arg = tree;
          fromshort->_.conv.native = native;
          fromshort->_.conv.needed = SSG_VALMODE_LONG;
          ssg_print_scalar_expn (ssg, fromshort, needed, asname);
          return;
        }
      ssg_print_tmpl (ssg, native, ssg_tmpl_X_of_short (needed, native), NULL, NULL, tree, asname);
      return;
    }
  if (IS_BOX_POINTER (needed))
    {
      ssg_print_tmpl (ssg, needed, ssg_tmpl_short_of_X (needed, native), NULL, NULL, tree, asname);
      return;
    }
  ssg_print_tmpl (ssg, native, ssg_tmpl_X_of_Y (needed, native), NULL, NULL, tree, asname);
  return;
}


void
ssg_print_scalar_expn (spar_sqlgen_t *ssg, SPART *tree, ssg_valmode_t needed, const char *asname)
{
#ifdef DEBUG
  if (THR_IS_STACK_OVERFLOW (THREAD_CURRENT_THREAD, &ssg, 1000))
    spar_internal_error (NULL, "ssg_print_scalar_expn (): stack overflow");
#endif
  if (SSG_VALMODE_AUTO == needed)
    needed = ssg_expn_native_valmode (ssg, tree);
  switch (SPART_TYPE (tree))
    {
    case BOP_AND:	ssg_print_bop_bool_expn (ssg, tree, " AND "	, " __and ("	, 0, SSG_VALMODE_BOOL); goto print_asname;
    case BOP_OR:	ssg_print_bop_bool_expn (ssg, tree, " OR "	, " __or ("	, 0, SSG_VALMODE_BOOL); goto print_asname;
    case BOP_EQ:	ssg_print_bop_bool_expn (ssg, tree, " = "	, " equ ("	, 0, SSG_VALMODE_BOOL); goto print_asname;
    case BOP_NEQ:	ssg_print_bop_bool_expn (ssg, tree, " <> "	, " neq ("	, 0, SSG_VALMODE_BOOL); goto print_asname;
    case BOP_LT:	ssg_print_bop_bool_expn (ssg, tree, " < "	, " lt ("	, 0, SSG_VALMODE_BOOL); goto print_asname;
    case BOP_LTE:	ssg_print_bop_bool_expn (ssg, tree, " <= "	, " lte ("	, 0, SSG_VALMODE_BOOL); goto print_asname;
    case BOP_GT:	ssg_print_bop_bool_expn (ssg, tree, " > "	, " gt ("	, 0, SSG_VALMODE_BOOL); goto print_asname;
    case BOP_GTE:	ssg_print_bop_bool_expn (ssg, tree, " >= "	, " gte ("	, 0, SSG_VALMODE_BOOL); goto print_asname;
   /*case BOP_LIKE: Like is built-in in SPARQL, not a BOP!
			ssg_print_bop_bool_expn (ssg, tree, " like "	, " strlike ("	, 0, SSG_VALMODE_BOOL); goto print_asname; */
/*
    case BOP_SAME:	ssg_print_bop_bool_expn (ssg, tree, "(", "= ", ")"); goto print_asname;
    case BOP_NSAME:	ssg_print_bop_bool_expn (ssg, tree, "(", "= ", ")"); goto print_asname;
*/
    case BOP_NOT:
      {
        if ((SSG_VALMODE_BOOL == needed) || (SSG_VALMODE_SQLVAL == needed))
          {
            ssg_puts (" __not ("); ssg_print_scalar_expn (ssg, tree->_.bin_exp.left, SSG_VALMODE_SQLVAL, NULL_ASNAME); ssg_putchar (')');
          }
        else if (SSG_VALMODE_DATATYPE == needed)
          {
            ssg_print_literal (ssg, NULL, (SPART *)uname_xmlschema_ns_uri_hash_boolean);
          }
        else if (SSG_VALMODE_LANGUAGE == needed)
          {
            ssg_puts (" NULL");
          }
        else
          spar_sqlprint_error ("ssg_print_scalar_expn (): unsupported mode for 'not(X)'");
        goto print_asname;
      }
    case BOP_PLUS:	ssg_print_bop_calc_expn (ssg, tree, " (", " + ", ")"); goto print_asname;
    case BOP_MINUS:	ssg_print_bop_calc_expn (ssg, tree, " (", " - ", ")"); goto print_asname;
    case BOP_TIMES:	ssg_print_bop_calc_expn (ssg, tree, " (", " * ", ")"); goto print_asname;
    case BOP_DIV:	ssg_print_bop_calc_expn (ssg, tree, " div (", ", ", ")"); goto print_asname;
    case BOP_MOD:	ssg_print_bop_calc_expn (ssg, tree, " mod (", ", ", ")"); goto print_asname;
    case SPAR_BLANK_NODE_LABEL:
    case SPAR_VARIABLE:
      {
#if 0
        ssg_valmode_t vmode = ssg_expn_native_valmode (ssg, tree);
        if (vmode == needed)
          {
            sparp_equiv_t *eq = ssg->ssg_equivs[tree->_.var.equiv_idx];
            ssg_print_equiv_retval_expn (ssg, sparp_find_gp_by_alias (ssg->ssg_sparp, tree->_.var.selid), eq, 0, 1, needed, NULL_ASNAME);
          }
        else
          ssg_print_valmoded_scalar_expn (ssg, tree, needed, vmode);
#else
        sparp_equiv_t *eq = ssg->ssg_equivs[tree->_.var.equiv_idx];
        SPART *gp = sparp_find_gp_by_alias (ssg->ssg_sparp, tree->_.var.selid);
        if ((NULL == gp) && (SPART_VARR_EXPORTED & tree->_.var.rvr.rvrRestrictions))
          gp = ssg->ssg_tree->_.req_top.pattern;
        ssg_print_equiv_retval_expn (ssg, gp, eq, SSG_RETVAL_FROM_JOIN_MEMBER | SSG_RETVAL_MUST_PRINT_SOMETHING | SSG_RETVAL_USES_ALIAS, needed, asname);
#endif
        return;
      }
    case SPAR_BUILT_IN_CALL:
      {
        ssg_print_builtin_expn (ssg, tree, 0, needed);
        goto print_asname;
      }
    case SPAR_CONV:
      {
        if ((tree->_.conv.needed == needed) ||
          ( IS_BOX_POINTER (tree->_.conv.needed) &&
            IS_BOX_POINTER (needed) &&
            ssg_valmode_is_subformat_of (tree->_.conv.needed, needed)) )
          ssg_print_valmoded_scalar_expn (ssg, tree->_.conv.arg, tree->_.conv.needed, tree->_.conv.native, asname);
        else
          ssg_print_valmoded_scalar_expn (ssg, tree, needed, tree->_.conv.needed, asname);
        return;
      }
    case SPAR_FUNCALL:
      {
        int bigtext, arg_ctr, arg_count = tree->_.funcall.argcount;
        xqf_str_parser_desc_t *parser_desc;
	ssg_valmode_t native = ssg_rettype_of_function (ssg, tree->_.funcall.qname);
        if (native != needed)
          {
            ssg_print_valmoded_scalar_expn (ssg, tree, needed, native, asname);
            return;
          }
        ssg_putchar (' ');
        parser_desc = function_is_xqf_str_parser (tree->_.funcall.qname);
        if (NULL != parser_desc)
          {
            ssg_puts ("__xqf_str_parse ('");
            ssg_puts (parser_desc->p_name);
            ssg_puts ("'");
            ssg->ssg_indent++;
            for (arg_ctr = 0; arg_ctr < arg_count; arg_ctr++)
              {
                ssg_puts (", ");
                ssg_print_scalar_expn (ssg, tree->_.funcall.argtrees[arg_ctr], SSG_VALMODE_SQLVAL, NULL_ASNAME);
              }
            ssg->ssg_indent--;
            ssg_putchar (')');
            goto print_asname;
          }
        bigtext =
          ((NULL != strstr (tree->_.funcall.qname, "bif:")) ||
           (NULL != strstr (tree->_.funcall.qname, "sql:")) ||
           (arg_count > 3) );
        ssg_prin_function_name (ssg, tree->_.funcall.qname);
        ssg_puts (" (");
        ssg->ssg_indent++;
        for (arg_ctr = 0; arg_ctr < arg_count; arg_ctr++)
          {
            ssg_valmode_t argtype = ssg_argtype_of_function (ssg, tree->_.funcall.qname, arg_ctr);
            if (arg_ctr > 0)
              ssg_putchar (',');
            if (bigtext) ssg_newline (0); else ssg_putchar (' ');
            ssg_print_scalar_expn (ssg, tree->_.funcall.argtrees[arg_ctr], argtype, NULL_ASNAME);
          }
        ssg->ssg_indent--;
        ssg_putchar (')');
        goto print_asname;
      }
    case SPAR_LIT:
      {
        dtp_t tree_dtp = DV_TYPE_OF (tree);
        if (DV_UNAME == tree_dtp)
          {
            if (SSG_VALMODE_DATATYPE == needed)
              {
                ssg_puts (" UNAME'" XMLSCHEMA_NS_URI "#anyURI'");
              }
            else if (SSG_VALMODE_LANGUAGE == needed)
              {
                ssg_puts (" NULL");
              }
            else if (SSG_VALMODE_LONG == needed)
              {
                ssg_puts (" DB.DBA.RDF_MAKE_IID_OF_QNAME (");
                ssg_print_literal (ssg, NULL, tree);
                ssg_puts (")");
              }
            else if (SSG_VALMODE_SQLVAL == needed)
              ssg_print_literal (ssg, NULL, tree);
            else if (IS_BOX_POINTER (needed))
              {
                if (NULL != needed->qmfShortOfUriTmpl)
                  {
                    ssg_print_tmpl (ssg, needed, needed->qmfShortOfUriTmpl, NULL, NULL, tree, asname);
                    return;
                  }
                else
                  {
                    ssg_puts (" DB.DBA.RDF_MAKE_IID_OF_QNAME (");
                    ssg_print_literal (ssg, NULL, tree);
                    ssg_puts (")");
                  }
              }
            else
              {
                spar_sqlprint_error ("ssg_print_scalar_expn(): unsupported valmode for UNAME literal");
              }
            goto print_asname;
          }
        if (SSG_VALMODE_DATATYPE == needed)
          {
            if (DV_ARRAY_OF_POINTER != tree_dtp)
              {
                ssg_puts (" DB.DBA.RDF_DATATYPE_OF_TAG (__tag ("); /* !!!TBD Replace with something less ugly when twobyte of every predefined type is fixed */
                ssg_print_literal (ssg, NULL, tree);
                ssg_puts ("))");
              }
            else if (NULL != tree->_.lit.datatype)
              ssg_print_literal (ssg, NULL, (SPART *)(tree->_.lit.datatype));
            else
              ssg_puts (" NULL");
            goto print_asname;
          }
        if (SSG_VALMODE_LANGUAGE == needed)
          {
            if (DV_ARRAY_OF_POINTER != tree_dtp)
              ssg_puts (" NULL");
            else if (NULL != tree->_.lit.language)
              ssg_print_literal (ssg, NULL, (SPART *)(tree->_.lit.language));
            else
              ssg_puts (" NULL");
            goto print_asname;
          }
        if (SSG_VALMODE_LONG == needed)
          {
            ssg_print_literal_as_long (ssg, tree);
            goto print_asname;
          }
        if (SSG_VALMODE_SQLVAL == needed)
          {
          ssg_print_literal (ssg, NULL, tree);
            goto print_asname;
          }
        ssg_print_valmoded_scalar_expn (ssg, tree, needed, SSG_VALMODE_SQLVAL, asname);
        return;
      }
    case SPAR_QNAME:
    /*case SPAR_QNAME_NS:*/
      if (SSG_VALMODE_DATATYPE == needed)
        {
          ssg_puts (" UNAME'" XMLSCHEMA_NS_URI "#anyURI'");
        }
      else if (SSG_VALMODE_LANGUAGE == needed)
        {
          ssg_puts (" NULL");
        }
      else if (SSG_VALMODE_LONG == needed)
        ssg_print_literal_as_long (ssg, tree);
      else if (SSG_VALMODE_SQLVAL != needed)
        {
          ssg_print_valmoded_scalar_expn (ssg, tree, needed, SSG_VALMODE_SQLVAL, asname);
          return;
        }
      else
        ssg_print_literal (ssg, NULL, tree);
      goto print_asname;
    case SPAR_RETVAL:
      {
        ssg_valmode_t vmode = ssg_expn_native_valmode (ssg, tree);
        if (vmode == needed)
          {
            if (SPART_VARNAME_IS_GLOB(tree->_.retval.vname))
              ssg_print_global_param (ssg, tree->_.retval.vname, needed);
            else
              {
                caddr_t e_varname = ssg->ssg_equivs[tree->_.var.equiv_idx]->e_varnames[0];
                ssg_puts (" /*retval[*/ ");
                ssg_putchar (' ');
                if (NULL != tree->_.retval.tabid)
                  {
                    ssg_prin_id (ssg, tree->_.retval.tabid);
                    ssg_putchar ('.');
                  }
                else if (NULL != tree->_.retval.selid)
                  {
                    ssg_prin_id (ssg, tree->_.retval.selid);
                    ssg_putchar ('.');
                  }
                if ((NULL == asname) || IS_BOX_POINTER (asname))
                  {
                    ssg_prin_id (ssg, tree->_.retval.vname);
                    ssg_puts (" /* "); ssg_puts (e_varname); ssg_puts (" */");
                  }
                else
                  {
                    int col_idx = asname - COL_IDX_ASNAME;
                    char buf[210];
#if 0 /* old variant, seemes to be redundant */
                    ccaddr_t col_name;
                    quad_map_t *qm = tree->_.retval.triple->_.triple.qm_list[0];
                    qm_value_t *qm_val = SPARP_FIELD_QMV_OF_QM (qm,tree->_.retval.tr_idx);
                    col_name = qm_val->qmvColumns[col_idx]->qmvcColumnName;
                    sprintf (buf, "%.100s~%d~%.100s", e_varname, col_idx, col_name);
#else
                    sprintf (buf, "%.100s~%d", e_varname, col_idx);
#endif
                    ssg_prin_id (ssg, buf);
                  }
                ssg_puts (" /*]retval*/ ");
              }
          }
        else
          {
            ssg_print_valmoded_scalar_expn (ssg, tree, needed, vmode, asname);
        return;
      }
        goto print_asname;
      }
    default:
      spar_sqlprint_error ("ssg_print_scalar_expn(): unsupported scalar expression type");
      goto print_asname;
    }

print_asname:
  if (IS_BOX_POINTER (asname))
    {
      ssg_puts (" AS /*scalar*/ ");
      ssg_prin_id (ssg, asname);
    }
}

void
ssg_print_filter_expn (spar_sqlgen_t *ssg, SPART *tree)
{
  switch (SPART_TYPE (tree))
    {
    case BOP_AND:	ssg_print_bop_bool_expn (ssg, tree, " AND "	, " __and ("	, 1, SSG_VALMODE_BOOL); return;
    case BOP_OR:	ssg_print_bop_bool_expn (ssg, tree, " OR "	, " __or ("	, 1, SSG_VALMODE_BOOL); return;
    case BOP_EQ:	ssg_print_bop_bool_expn (ssg, tree, " = "	, " equ ("	, 1, SSG_VALMODE_BOOL); return;
    case BOP_NEQ:	ssg_print_bop_bool_expn (ssg, tree, " <> "	, " neq ("	, 1, SSG_VALMODE_BOOL); return;
    case BOP_LT:	ssg_print_bop_cmp_expn (ssg, tree, " < "	, " lt ("	, 1, SSG_VALMODE_BOOL); return;
    case BOP_LTE:	ssg_print_bop_cmp_expn (ssg, tree, " <= "	, " lte ("	, 1, SSG_VALMODE_BOOL); return;
    case BOP_GT:	ssg_print_bop_cmp_expn (ssg, tree, " > "	, " gt ("	, 1, SSG_VALMODE_BOOL); return;
    case BOP_GTE:	ssg_print_bop_cmp_expn (ssg, tree, " >= "	, " gte ("	, 1, SSG_VALMODE_BOOL); return;
/*case BOP_LIKE: Like is built-in in SPARQL, not a BOP!
			ssg_print_bop_bool_expn (ssg, tree, " LIKE "	, " strlike ("	, 1, SSG_VALMODE_BOOL); return; */
/*
    case BOP_SAME:	ssg_print_bop_bool_expn (ssg, tree, "(", "= ", ")"); return;
    case BOP_NSAME:	ssg_print_bop_bool_expn (ssg, tree, "(", "= ", ")"); return;
*/
    case BOP_NOT:
      ssg_puts (" not ("); ssg_print_filter_expn (ssg, tree->_.bin_exp.left); ssg_putchar (')');
      return;
    case SPAR_BUILT_IN_CALL:
      {
        ssg_print_builtin_expn (ssg, tree, 1, SSG_VALMODE_BOOL);
        return;
      }
    default: break;
    }
  ssg_print_scalar_expn (ssg, tree, SSG_VALMODE_BOOL, NULL_ASNAME);
}


void
ssg_print_where_or_and (spar_sqlgen_t *ssg, const char *location)
{
  if (ssg->ssg_where_l_printed)
    {
      ssg_newline (0);
      ssg_puts ("AND");
    }
  else if (NULL != ssg->ssg_where_l_text)
    {
      if ('\b' == ssg->ssg_where_l_text[0])
        {
          ssg_newline (SSG_INDENT_FACTOR);
          ssg_puts (ssg->ssg_where_l_text + 1);
        }
      else
        {
      ssg_newline (0);
      ssg_puts (ssg->ssg_where_l_text);
    }
    }
  ssg->ssg_where_l_printed = 1;
  if (NULL != location)
    {
      ssg_puts (" /* ");
      ssg_puts (location);
      ssg_puts (" */ ");
      ssg_newline (1);
    }
}

void
ssg_find_global_in_equiv (sparp_equiv_t *eq, SPART **var_ret, caddr_t *name_ret)
{
  int ctr;
  if (NULL != var_ret)
    {
      var_ret[0] = NULL;
  for (ctr = eq->e_var_count; ctr--; /* no step */)
    {
      SPART *var = eq->e_vars[ctr];
      if (SPART_VARNAME_IS_GLOB(var->_.var.vname))
            {
              var_ret[0] = var;
              if (NULL != name_ret)
                name_ret[0] = var->_.var.vname;
              return;
            }
        }
    }
  if (NULL != name_ret)
    {
      name_ret[0] = NULL;
      for (ctr = BOX_ELEMENTS (eq->e_varnames); ctr--; /* no step */)
        {
          caddr_t name = eq->e_varnames[ctr];
          if (SPART_VARNAME_IS_GLOB(name))
            {
              name_ret[0] = name;
              return;
            }
        }
    }
}

void
ssg_print_fld_lit_restrictions (spar_sqlgen_t *ssg, quad_map_t *qmap, qm_value_t *field, caddr_t tabid, SPART *fld_tree)
{
  ptrlong field_restr = field->qmvFormat->qmfValRange.rvrRestrictions;
/*  caddr_t litvalue = ((DV_ARRAY_OF_POINTER == DV_TYPE_OF (fld_tree)) ? fld_tree->_.lit.val : (caddr_t)fld_tree);*/
  caddr_t litvalue, littype, litlang;
  int col_ctr, col_count;
  if (DV_ARRAY_OF_POINTER == DV_TYPE_OF (fld_tree))
    {
      litvalue = fld_tree->_.lit.val;
      littype = fld_tree->_.lit.datatype;
      litlang = fld_tree->_.lit.language;
    }
  else
    {
      litvalue = (caddr_t)fld_tree;
      littype = litlang = NULL;
    }
  if ((SPART_VARR_FIXED & field_restr) && (SPART_VARR_IS_LIT & field_restr))
    {
      if ((DVC_MATCH == cmp_boxes ((caddr_t)(field->qmvFormat->qmfValRange.rvrDatatype), littype, NULL, NULL)) &&
        (DVC_MATCH == cmp_boxes ((caddr_t)(field->qmvFormat->qmfValRange.rvrFixedValue), litvalue, NULL, NULL)) )
        return;
    }
  if (!(SPART_VARR_IS_LIT & field_restr))
    {
      ssg_print_where_or_and (ssg, "obj field is a literal");
      ssg_print_tmpl (ssg, field->qmvFormat, field->qmvFormat->qmfIslitOfShortTmpl, tabid, field, NULL, NULL_ASNAME);
    }
  col_count = BOX_ELEMENTS (field->qmvColumns);
  for (col_ctr = 0; col_ctr < col_count; col_ctr++)
    {
      const char *eq_asname = ((1 == col_count) ? NULL_ASNAME : (COL_IDX_ASNAME + col_ctr));
      ssg_print_where_or_and (ssg, ((0 != col_ctr) ? NULL : "field equal to literal, quick test"));
      ssg_print_tr_field_expn (ssg, field, tabid, field->qmvFormat, eq_asname);
      ssg_puts (" =");
  if ((DV_STRING == DV_TYPE_OF (litvalue)) &&
    ((NULL != littype) || (NULL != litlang)) )
        ssg_print_tmpl (ssg, field->qmvFormat, field->qmvFormat->qmfShortOfTypedsqlvalTmpl, tabid, field, fld_tree, eq_asname);
  else
        ssg_print_tmpl (ssg, field->qmvFormat, field->qmvFormat->qmfShortOfSqlvalTmpl, tabid, field, (SPART *)litvalue, eq_asname);
    }
/*  ssg_print_where_or_and (ssg, "field equal to literal, full test");
  ssg_print_tr_field_expn (ssg, field, tabid, SSG_VALMODE_SQLVAL, NULL_ASNAME);
  ssg_puts (" =");
  ssg_print_literal (ssg, NULL, (SPART *)litvalue);*/
}

void
ssg_print_fld_uri_restrictions (spar_sqlgen_t *ssg, quad_map_t *qmap, qm_value_t *field, caddr_t tabid, caddr_t uri)
{
  ptrlong field_restr = field->qmvFormat->qmfValRange.rvrRestrictions;
  int col_ctr, col_count;
  if ((SPART_VARR_FIXED & field_restr) && (SPART_VARR_IS_REF & field_restr))
    {
      if (DVC_MATCH == cmp_boxes ((caddr_t)(field->qmvFormat->qmfValRange.rvrFixedValue), uri, NULL, NULL))
        return;
    }
  if (!(SPART_VARR_IS_REF & field_restr))
    {
      ssg_print_where_or_and (ssg, "node field is a URI ref");
      ssg_print_tmpl (ssg, field->qmvFormat, field->qmvFormat->qmfIsrefOfShortTmpl, tabid, field, NULL, NULL_ASNAME);
    }
  col_count = BOX_ELEMENTS (field->qmvColumns);
  for (col_ctr = 0; col_ctr < col_count; col_ctr++)
    {
      const char *eq_asname = ((1 == col_count) ? NULL_ASNAME : (COL_IDX_ASNAME + col_ctr));
      ssg_print_where_or_and (ssg, ((0 != col_ctr) ? NULL : "field equal to URI ref"));
      ssg_print_tr_field_expn (ssg, field, tabid, field->qmvFormat, eq_asname);
      ssg_puts (" =");
      ssg_print_tmpl (ssg, field->qmvFormat, field->qmvFormat->qmfShortOfUriTmpl, tabid, field, (SPART *)uri, eq_asname);
    }
}

void
ssg_print_fld_restrictions (spar_sqlgen_t *ssg, quad_map_t *qmap, qm_value_t *field, caddr_t tabid, SPART *fld_tree)
{
  switch (SPART_TYPE (fld_tree))
    {
    case SPAR_LIT:
      {
        ssg_print_fld_lit_restrictions (ssg, qmap, field, tabid, fld_tree);
        return;
      }
    case SPAR_QNAME:
    /*case SPAR_QNAME_NS:*/
      {
        caddr_t uri = fld_tree->_.lit.val;
        ssg_print_fld_uri_restrictions (ssg, qmap, field, tabid, uri);
        return;
      }
    case SPAR_VARIABLE: case SPAR_BLANK_NODE_LABEL:
      {
        ptrlong field_restr = field->qmvFormat->qmfValRange.rvrRestrictions;
        ptrlong tree_restr = fld_tree->_.var.rvr.rvrRestrictions;
        if ((SPART_VARR_FIXED | SPART_VARR_GLOBAL) & tree_restr)
          return; /* Because this means that equiv has equality on the field that is to be printed later; so there's nothing to do right here */
        if (SPART_VARR_CONFLICT & tree_restr) 
          {
            ssg_print_where_or_and (ssg, "conflict! The query remained not entirely optimized");
            ssg_puts ("(1=2)");
            return;
          }
        if ((SPART_VARR_NOT_NULL & tree_restr) && (!(SPART_VARR_NOT_NULL & field_restr)))
          {
            ssg_print_where_or_and (ssg, "nullable variable is not null");
            ssg_print_tmpl (ssg, field->qmvFormat, "(^{alias-dot}^^{column-0}^ is not null)", tabid, field, NULL, NULL_ASNAME);
          }
        if ((SPART_VARR_IS_BLANK & tree_restr) && (!(SPART_VARR_IS_BLANK & field_restr)))
          {
            ssg_print_where_or_and (ssg, "variable is blank node");
            ssg_print_tmpl (ssg, field->qmvFormat, field->qmvFormat->qmfIsblankOfShortTmpl, tabid, field, NULL, NULL_ASNAME);
          }
        else if ((SPART_VARR_IS_IRI & tree_restr) && (!(SPART_VARR_IS_IRI & field_restr)))
          {
            ssg_print_where_or_and (ssg, "variable is IRI");
            ssg_print_tmpl (ssg, field->qmvFormat, field->qmvFormat->qmfIsuriOfShortTmpl, tabid, field, NULL, NULL_ASNAME);
          }
        else if ((SPART_VARR_IS_REF & tree_restr) && (!(SPART_VARR_IS_REF & field_restr)))
          {
            ssg_print_where_or_and (ssg, "'any' variable is a reference");
            ssg_print_tmpl (ssg, field->qmvFormat, field->qmvFormat->qmfIsrefOfShortTmpl, tabid, field, NULL, NULL_ASNAME);
          }
        else if ((SPART_VARR_IS_LIT & tree_restr) && (!(SPART_VARR_IS_LIT & field_restr)))
          {
            ssg_print_where_or_and (ssg, "'any' variable is a literal");
            ssg_print_tmpl (ssg, field->qmvFormat, field->qmvFormat->qmfIslitOfShortTmpl, tabid, field, NULL, NULL_ASNAME);
          }
        /*!!! TBD: checks for type, lang */
        return;
      }
    default:
      spar_sqlprint_error ("ssg_print_fld_restrictions(): unsupported type of fld_tree()");
    }
}

int
ssg_print_equiv_retval_expn (spar_sqlgen_t *ssg, SPART *gp, sparp_equiv_t *eq, int flags, ssg_valmode_t needed, const char *asname)
{
  caddr_t name_as_expn = NULL;
  int var_count, var_ctr;
  ssg_valmode_t native = NULL;
  if (!(flags & (SSG_RETVAL_USES_ALIAS | SSG_RETVAL_SUPPRESSED_ALIAS)) && IS_BOX_POINTER (asname))
    asname = NULL;
  if (NULL == eq)
    goto try_write_null; /* see below */
  if (SPART_VARR_CONFLICT & eq->e_rvr.rvrRestrictions)
    {
      ssg_puts (" NULL /* due to conflict on ");
      ssg_puts (eq->e_varnames[0]);
      ssg_puts (" */");
      goto write_assuffix;
    }
#ifdef DEBUG
  if (SSG_VALMODE_LONG == needed)
    {
      ssg_puts (" /* LONG retval */");
    }
#endif
  if (SPART_VARR_FIXED & eq->e_rvr.rvrRestrictions)
    {
      ssg_print_scalar_expn (ssg, (SPART *)(eq->e_rvr.rvrFixedValue), needed, asname);
      return 1;
    }
  var_count = eq->e_var_count;
  if (SSG_VALMODE_AUTO == needed)
    needed = native = ssg_equiv_native_valmode (ssg, gp, eq);
  if (SPART_VARR_GLOBAL & eq->e_rvr.rvrRestrictions)
    {
      for (var_ctr = 0; var_ctr < var_count; var_ctr++)
        {
          SPART *vartree = eq->e_vars[var_ctr];
          if (SPART_VARNAME_IS_GLOB (vartree->_.var.vname))
            {
              if (NULL == native)
                native = ssg_expn_native_valmode (ssg, vartree);
	      if (needed == native)
                {
              ssg_print_global_param (ssg, vartree->_.var.vname, needed);
	      goto write_assuffix;
            }
              else
		{
		  ssg_print_valmoded_scalar_expn (ssg, vartree, needed, native, asname);
		  return 1;
		}
            }
        }
    }
  if (flags & SSG_RETVAL_FROM_JOIN_MEMBER)
    {
      for (var_ctr = 0; var_ctr < var_count; var_ctr++)
        {
          SPART *var = eq->e_vars[var_ctr];
          caddr_t tabid = var->_.var.tabid;
          if (NULL == tabid)
            continue;
          ssg_print_tr_var_expn (ssg, var, needed, asname);
          return 1;
        }
    }
  if (flags & SSG_RETVAL_FROM_GOOD_SELECTED)
    {
      for (var_ctr = 0; var_ctr < var_count; var_ctr++)
        {
          SPART_buf rv_buf;
          SPART *rv;
          ssg_valmode_t native;
          SPART *var = eq->e_vars[var_ctr];
          caddr_t selid = var->_.var.selid;
          if (NULL == selid)
            continue;
          SPART_AUTO (rv, rv_buf, SPAR_RETVAL);
          memcpy (&(rv->_.retval), &(var->_.var), sizeof (rv->_.var));
          rv->_.var.selid = selid;
          rv->_.var.tabid = NULL;
          rv->_.retval.triple = sparp_find_triple_of_var (ssg->ssg_sparp, NULL, var);
          native = ssg_expn_native_valmode (ssg, rv);
          if ((native == needed) || (SSG_VALMODE_AUTO == needed))
            name_as_expn = var->_.var.vname;
#ifdef DEBUG
          if (SSG_VALMODE_AUTO == native)
            {
              ssg_expn_native_valmode (ssg, rv);
              spar_internal_error (ssg->ssg_sparp, "ssg_print_equiv_retval_expn(): SSG_VALMODE_AUTO == native");
            }
#endif
          ssg_print_valmoded_scalar_expn (ssg, rv, needed, native, asname);
          return 1;
        }
      if ((0 == eq->e_var_count) &&
        ((flags & SSG_RETVAL_FROM_ANY_SELECTED) ||
          (UNION_L == gp->_.gp.subtype) || (0 == gp->_.gp.subtype)) )
        { /* Special case of an equiv used only to pass column of UNION to the next level, can print it always */
          SPART_buf rv_buf;
          SPART *rv;
          ssg_valmode_t native;
          SPART_AUTO (rv, rv_buf, SPAR_RETVAL);
          rv->_.retval.equiv_idx = eq->e_own_idx;
          memcpy (&(rv->_.retval.rvr.rvrRestrictions), &(eq->e_rvr.rvrRestrictions), sizeof (rdf_val_range_t));
          rv->_.retval.selid = gp->_.gp.selid;
          rv->_.retval.tabid = NULL;
          rv->_.retval.vname = eq->e_varnames[0];
          native = ssg_expn_native_valmode (ssg, rv);
          if ((native == needed) || (SSG_VALMODE_AUTO == needed))
            name_as_expn = rv->_.retval.vname;
          ssg_print_valmoded_scalar_expn (ssg, rv, needed, native, asname);
          return 1;
        }
    }
  switch (gp->_.gp.subtype)
    {
    case UNION_L:
      {
        SPART *gp_member = NULL;
        sparp_equiv_t *subval;
        int sub_flags, printed;
        if (!(flags & SSG_RETVAL_FROM_FIRST_UNION_MEMBER))
          goto try_write_null; /* see below */
        gp_member = gp->_.gp.members[0];
        subval = sparp_equiv_get_subvalue_ro (ssg->ssg_equivs, ssg->ssg_equiv_count, gp_member, eq);
        sub_flags = SSG_RETVAL_FROM_GOOD_SELECTED |
          (flags & (SSG_RETVAL_MUST_PRINT_SOMETHING | SSG_RETVAL_FROM_ANY_SELECTED | SSG_RETVAL_CAN_PRINT_NULL | SSG_RETVAL_USES_ALIAS) );
        printed = ssg_print_equiv_retval_expn (ssg, gp_member, subval, sub_flags, needed, asname);
        return printed;
      }
    default:
      {
        SPART *gp_member = NULL;
        sparp_equiv_t *subval = NULL;
        int memb_ctr, memb_len;
        int sub_flags, printed;
        if (!(flags & SSG_RETVAL_FROM_JOIN_MEMBER))
          goto try_write_null; /* see below */
        memb_len = BOX_ELEMENTS_INT (gp->_.gp.members);
        for (memb_ctr = 0; memb_ctr < memb_len; memb_ctr++)
          {
            gp_member = gp->_.gp.members[memb_ctr];
            if (SPAR_GP != gp_member->type)
              continue;
            subval = sparp_equiv_get_subvalue_ro (ssg->ssg_equivs, ssg->ssg_equiv_count, gp_member, eq);
            if (NULL != subval)
              break;
          }
        sub_flags = SSG_RETVAL_FROM_GOOD_SELECTED |
          (flags & (SSG_RETVAL_MUST_PRINT_SOMETHING | SSG_RETVAL_FROM_ANY_SELECTED | SSG_RETVAL_CAN_PRINT_NULL | SSG_RETVAL_USES_ALIAS) );
        printed = ssg_print_equiv_retval_expn (ssg, gp_member, subval, sub_flags, needed, asname);
        return printed;
        break;
      }
    }

try_write_null:
  if ((flags & SSG_RETVAL_MUST_PRINT_SOMETHING) &&
    (flags & SSG_RETVAL_FROM_GOOD_SELECTED) && !(flags & SSG_RETVAL_FROM_ANY_SELECTED) )
    return 
      ssg_print_equiv_retval_expn (ssg, gp, eq, flags | SSG_RETVAL_FROM_ANY_SELECTED, needed, asname);
  if (!(flags & SSG_RETVAL_CAN_PRINT_NULL))
    {
      if (flags & SSG_RETVAL_MUST_PRINT_SOMETHING)
        spar_internal_error (NULL, "ssg_print_equiv_retval_expn(): must print something but can not");
      return 0;
    }
  ssg_puts (" NULL");

write_assuffix:
  if (IS_BOX_POINTER (asname) &&
    ((NULL == name_as_expn) || strcmp (asname, name_as_expn)) )
    {
      ssg_puts (" AS /*eqretval*/ ");
      ssg_prin_id (ssg, asname);
    }
  return 1;
}


void
ssg_print_equivalences (spar_sqlgen_t *ssg, SPART *gp, sparp_equiv_t *eq,
  ccaddr_t jleft_alias, ccaddr_t jright_alias )
{
  int var_ctr, var2_ctr;
  int sub_ctr, sub2_ctr;

if (NULL != jright_alias)
  {
#ifdef DEBUG
    ccaddr_t jl = ssg_find_jl_by_jr (ssg, gp, jright_alias);
    if (strcmp (jl, jleft_alias))
      spar_internal_error (NULL, "ssg_print_equivalences (): invalid pair of jleft_alias and jright_alias");
#endif
    goto print_cross_equalities;
  }

  /* Printing equalities with constants */
  for (var_ctr = 0; var_ctr < eq->e_var_count; var_ctr++)
    {
      SPART *var = eq->e_vars[var_ctr];
      caddr_t tabid = var->_.var.tabid;
      if (NULL == tabid)
        continue;
      if (SPART_VARR_FIXED & eq->e_rvr.rvrRestrictions)
        {
          ssg_valmode_t vmode;
          SPART *var_triple = sparp_find_triple_of_var (ssg->ssg_sparp, NULL, var);
          SPART_buf var_rv_buf/*, glob_rv_buf*/;
          SPART *var_rv/*, *glob_rv*/;
          quad_map_t *qm;
          qm_value_t *qmv;
          int col_ctr, col_count;
          qm = var_triple->_.triple.qm_list[0];
          qmv = JSO_FIELD_ACCESS(qm_value_t *, qm, qm_field_map_offsets[var->_.var.tr_idx])[0];
          if (NULL == qmv) /* It's fixed and it's constant in qm hence it matches compile-time, no run-time check needed */
            continue;
          SPART_AUTO (var_rv, var_rv_buf, SPAR_RETVAL);
          memcpy (&(var_rv->_.retval), &(var->_.var), sizeof (var->_.var));
          var_rv->_.retval.triple = var_triple;
          vmode = ssg_expn_native_valmode (ssg, var_rv);
          col_count = (IS_BOX_POINTER (vmode) ? BOX_ELEMENTS (qmv->qmvColumns) : 1);
          for (col_ctr = 0; col_ctr < col_count; col_ctr++)
            {
              const char *eq_idx_asname = ((1 == col_count) ? NULL_ASNAME : (COL_IDX_ASNAME + col_ctr));
              ssg_print_where_or_and (ssg, ((0 != col_ctr) ? NULL : "fixed value of equiv class (short)"));
              ssg_print_tr_var_expn (ssg, var, vmode, eq_idx_asname);
          ssg_puts (" =");
              ssg_print_scalar_expn (ssg, eq->e_rvr.rvrFixedValue, vmode, eq_idx_asname);
            }
          if (! (SPART_VARR_IS_REF & eq->e_rvr.rvrRestrictions))
            {
              ssg_print_where_or_and (ssg, "fixed value of equiv class (sqlval)");
              ssg_print_tr_var_expn (ssg, var, SSG_VALMODE_SQLVAL, NULL_ASNAME);
              ssg_puts (" =");
              ssg_print_literal (ssg, NULL, eq->e_rvr.rvrFixedValue);
            }
          continue;
        }
      if (SPART_VARR_GLOBAL & eq->e_rvr.rvrRestrictions)
        {
          SPART *glob_var;
          caddr_t glob_name;
          ssg_valmode_t vmode;
          SPART_buf var_rv_buf, glob_rv_buf;
          SPART *var_rv, *glob_rv;
          int col_ctr, col_count;
          SPART_AUTO (var_rv, var_rv_buf, SPAR_RETVAL);
          memcpy (&(var_rv->_.retval), &(var->_.var), sizeof (var->_.var));
          var_rv->_.retval.triple = sparp_find_triple_of_var (ssg->ssg_sparp, eq->e_gp, var);
          var_rv->_.retval.vname = "";
          vmode = ssg_expn_native_valmode (ssg, var_rv);
          SPART_AUTO (glob_rv, glob_rv_buf, SPAR_RETVAL);
          ssg_find_global_in_equiv (eq, &glob_var, &glob_name);
          if (NULL != glob_var)
            memcpy (&(glob_rv->_.retval), &(glob_var->_.var), sizeof (glob_var->_.var));
          else
            { /* This is possible in sparql select * where { ?local ?p ?o . filter (?local = ?:global) }*/
              memcpy (&(glob_rv->_.retval), &(var->_.var), sizeof (var->_.var));
              if (NULL != glob_name)
                glob_rv->_.retval.vname = glob_name;
            }
          if (IS_BOX_POINTER (vmode))
            {
              qm_value_t *qmv = sparp_find_qmv_of_var_or_retval (ssg->ssg_sparp, var_rv->_.retval.triple, eq->e_gp, var_rv);
              col_count = BOX_ELEMENTS (qmv->qmvColumns);
            }
          else
            col_count = 1;
          for (col_ctr = 0; col_ctr < col_count; col_ctr++)
            {
              const char *eq_idx_asname = ((1 == col_count) ? NULL_ASNAME : (COL_IDX_ASNAME + col_ctr));
              ssg_print_where_or_and (ssg, ((0 != col_ctr) ? NULL : "global param value of equiv class"));
              ssg_print_tr_var_expn (ssg, var_rv, vmode, eq_idx_asname);
          ssg_puts (" =");
              ssg_print_scalar_expn (ssg, glob_rv, vmode, eq_idx_asname);
            }
        }
      if (SPART_VARR_TYPED & eq->e_rvr.rvrRestrictions)
        {
          ssg_print_where_or_and (ssg, "fixed type of equiv class");
          ssg_print_tr_var_expn (ssg, var, SSG_VALMODE_DATATYPE, NULL_ASNAME);
          ssg_puts (" =");
          ssg_print_literal (ssg, NULL, (SPART *)(eq->e_rvr.rvrDatatype));
        }
    }

print_cross_equalities:
  /* Printing cross-equalities */
  if ((SPART_VARR_FIXED | SPART_VARR_GLOBAL) & eq->e_rvr.rvrRestrictions)
    return; /* As soon as all are equal to globals, no need in cross-equalities */
  for (var_ctr = 0; var_ctr < eq->e_var_count; var_ctr++)
    {
      SPART *var = eq->e_vars[var_ctr];
      ssg_valmode_t var_native;
      caddr_t tabid = var->_.var.tabid;
      if (NULL == tabid)
        continue;
      if (NULL != jright_alias)
        goto print_field_and_retval_equalities;
      for (var2_ctr = var_ctr + 1; var2_ctr < eq->e_var_count; var2_ctr++)
        {
          SPART *var2 = eq->e_vars[var2_ctr];
          ssg_valmode_t var2_native;
          ssg_valmode_t common_native;
          qm_value_t *qmv = NULL, *qmv2 = NULL;
          caddr_t tabid2 = var2->_.var.tabid;
          int col_ctr, col_count;
          if (NULL == tabid2)
            continue;
          var_native = ssg_expn_native_valmode (ssg, var);
          var2_native = ssg_expn_native_valmode (ssg, var2);
          common_native = ssg_largest_eq_valmode (var_native, var2_native);
#ifdef DEBUG
	  if (SSG_VALMODE_LONG == common_native)
            ssg_puts (" /* note SSG_VALMODE_LONG: */");
#endif
          if (IS_BOX_POINTER (common_native) || (SSG_VALMODE_AUTO == common_native))
            {
              qmv = sparp_find_qmv_of_var_or_retval (ssg->ssg_sparp, NULL, eq->e_gp, var);
              col_count = BOX_ELEMENTS (qmv->qmvColumns);
            }
          else
            col_count = 1;
          for (col_ctr = 0; col_ctr < col_count; col_ctr++)
            {
              const char *eq_idx_asname;
              if (!strcmp (var->_.var.tabid, var2->_.var.tabid) && 
                (IS_BOX_POINTER (common_native) || (SSG_VALMODE_AUTO == common_native)) )
                {
                  if (NULL == qmv2)
                    qmv2 = sparp_find_qmv_of_var_or_retval (ssg->ssg_sparp, NULL, eq->e_gp, var2);
                  if (!strcmp (qmv->qmvColumns[col_ctr]->qmvcColumnName, qmv2->qmvColumns[col_ctr]->qmvcColumnName))
                    continue;
                }
              eq_idx_asname = ((1 == col_count) ? NULL_ASNAME : (COL_IDX_ASNAME + col_ctr));
              ssg_print_where_or_and (ssg, ((0 != col_ctr) ? NULL : "two fields belong to same equiv"));
              ssg_print_tr_var_expn (ssg, var, common_native, eq_idx_asname);
          ssg_puts (" =");
              ssg_print_tr_var_expn (ssg, var2, common_native, eq_idx_asname);
            }
        }

print_field_and_retval_equalities:
      for (sub2_ctr = 0; sub2_ctr < BOX_ELEMENTS_INT_0 (eq->e_subvalue_idxs); sub2_ctr++)
        {
          ptrlong sub2_eq_idx = eq->e_subvalue_idxs[sub2_ctr];
          sparp_equiv_t *sub2_eq = ssg->ssg_equivs[sub2_eq_idx];
          SPART *sub2_gp = sparp_find_gp_by_eq_idx (ssg->ssg_sparp, sub2_eq_idx);
          ssg_valmode_t sub2_native;
          ssg_valmode_t common_native;
          int col_ctr, col_count;
          if (NULL != jright_alias)
            {
              if (strcmp (sub2_gp->_.gp.selid, jright_alias))
                continue;
              if (strcmp (tabid, jleft_alias))
                continue;
            }
          else if (OPTIONAL_L == sub2_gp->_.gp.subtype)
            {
              ccaddr_t jl = ssg_find_jl_by_jr (ssg, gp, sub2_gp->_.gp.selid);
              if (!strcmp (tabid, jl))
                continue;
            }
          var_native = ssg_expn_native_valmode (ssg, var);
          sub2_native = ssg_equiv_native_valmode (ssg, sub2_gp, sub2_eq);
          common_native = ssg_largest_eq_valmode (var_native, sub2_native);
#ifdef DEBUG
	  if (SSG_VALMODE_LONG == common_native)
            ssg_puts (" /* note SSG_VALMODE_LONG: */");
#endif
          if (IS_BOX_POINTER (common_native) || (SSG_VALMODE_AUTO == common_native))
            {
              qm_value_t *qmv = sparp_find_qmv_of_var_or_retval (ssg->ssg_sparp, NULL, eq->e_gp, var);
              col_count = BOX_ELEMENTS (qmv->qmvColumns);
            }
          else
            col_count = 1;
          for (col_ctr = 0; col_ctr < col_count; col_ctr++)
            {
              const char *eq_idx_asname = ((1 == col_count) ? NULL_ASNAME : (COL_IDX_ASNAME + col_ctr));
              ssg_print_where_or_and (ssg, ((0 != col_ctr) ? NULL : "field and retval belong to same equiv"));
              ssg_print_tr_var_expn (ssg, var, common_native, eq_idx_asname);
          ssg_puts (" =");
              ssg_print_equiv_retval_expn (ssg, sub2_gp, sub2_eq, SSG_RETVAL_FROM_GOOD_SELECTED | SSG_RETVAL_MUST_PRINT_SOMETHING, common_native, eq_idx_asname);
            }
        }
    }
  for (sub_ctr = 0; sub_ctr < BOX_ELEMENTS_INT_0 (eq->e_subvalue_idxs); sub_ctr++)
    {
      ptrlong sub_eq_idx = eq->e_subvalue_idxs[sub_ctr];
      sparp_equiv_t *sub_eq = ssg->ssg_equivs[sub_eq_idx];
      SPART *sub_gp = sparp_find_gp_by_eq_idx (ssg->ssg_sparp, sub_eq_idx);
      for (sub2_ctr = sub_ctr + 1; sub2_ctr < BOX_ELEMENTS_INT_0 (eq->e_subvalue_idxs); sub2_ctr++)
        {
          ptrlong sub2_eq_idx = eq->e_subvalue_idxs[sub2_ctr];
          sparp_equiv_t *sub2_eq = ssg->ssg_equivs[sub2_eq_idx];
          SPART *sub2_gp = sparp_find_gp_by_eq_idx (ssg->ssg_sparp, sub2_eq_idx);
          ssg_valmode_t sub_native, sub2_native, common_native;
          int col_ctr, col_count;
          if ((OPTIONAL_L == sub_gp->_.gp.subtype) &&
            (OPTIONAL_L == sub2_gp->_.gp.subtype) )
            continue;
          if (NULL != jright_alias)
            {
              if (
                (strcmp (sub2_gp->_.gp.selid, jright_alias) ||
                 strcmp (sub_gp->_.gp.selid, jleft_alias ) ) &&
                (strcmp (sub_gp->_.gp.selid, jright_alias) ||
                 strcmp (sub2_gp->_.gp.selid, jleft_alias ) ) )
                continue;
            }
          else if (OPTIONAL_L == sub2_gp->_.gp.subtype)
            {
              ccaddr_t jl = ssg_find_jl_by_jr (ssg, gp, sub2_gp->_.gp.selid);
              if (!strcmp (sub_gp->_.gp.selid, jl))
                continue;
            }
          else if (OPTIONAL_L == sub_gp->_.gp.subtype)
            {
              ccaddr_t jl = ssg_find_jl_by_jr (ssg, gp, sub_gp->_.gp.selid);
              if (!strcmp (sub2_gp->_.gp.selid, jl))
                continue;
            }
          sub_native = ssg_equiv_native_valmode (ssg, sub_gp, sub_eq);
          sub2_native = ssg_equiv_native_valmode (ssg, sub2_gp, sub2_eq);
          common_native = ssg_largest_eq_valmode (sub_native, sub2_native);
#ifdef DEBUG
	  if (SSG_VALMODE_LONG == common_native)
            ssg_puts (" /* note SSG_VALMODE_LONG: */");
#endif
          if (IS_BOX_POINTER (common_native) || (SSG_VALMODE_AUTO == common_native))
            {
#if 0 /*! TBD: fix this! */
              qm_value_t *qmv = sparp_find_qmv_of_var_or_retval (ssg->ssg_sparp, gp, var_rv);
              col_count = BOX_ELEMENTS (qmv->qmvColumns);
#else
              col_count = 1;
#endif
            }
          else
            col_count = 1;
          for (col_ctr = 0; col_ctr < col_count; col_ctr++)
            {
              const char *eq_asname = ((1 == col_count) ? NULL_ASNAME : (COL_IDX_ASNAME + col_ctr));
              ssg_print_where_or_and (ssg, ((0 != col_ctr) ? NULL : "two retvals belong to same equiv"));
              ssg_print_equiv_retval_expn (ssg, sub_gp, sub_eq, SSG_RETVAL_FROM_GOOD_SELECTED | SSG_RETVAL_MUST_PRINT_SOMETHING, common_native, eq_asname);
          ssg_puts (" =");
              ssg_print_equiv_retval_expn (ssg, sub2_gp, sub2_eq, SSG_RETVAL_FROM_GOOD_SELECTED | SSG_RETVAL_MUST_PRINT_SOMETHING, common_native, eq_asname);
            }
        }
    }
}

void ssg_print_retval_bop_calc_expn (spar_sqlgen_t *ssg, SPART *gp, SPART *tree,
  const char *s1, const char *s2, const char *s3,
  int cmp_op, ssg_valmode_t needed )
{
  SPART *left = tree->_.bin_exp.left;
  SPART *right = tree->_.bin_exp.right;
  if (needed == SSG_VALMODE_LONG)
#if 1
    needed = SSG_VALMODE_SQLVAL; /* Trick! This uses the fact that integers 0 and 1 are stored identically in SQLVAL and LONG valmodes */
#else
    {
      ssg_puts (" DB.DBA.RDF_LONG_OF_SQLVAL (");
      ssg_print_retval_bop_calc_expn (ssg, gp, tree, s1, s2, s3, cmp_op, SSG_VALMODE_SQLVAL);
      ssg_puts (")");
      return;
    }
#endif
  else if (needed != SSG_VALMODE_SQLVAL)
    spar_sqlprint_error ("ssg_print_retval_bop_calc_expn(): unsupported valmode");
  if (cmp_op)
    {
      ssg_valmode_t left_native = ssg_expn_native_valmode (ssg, left);
      ssg_valmode_t right_native = ssg_expn_native_valmode (ssg, right);
      ssg_valmode_t smallest_union;
      const char *cmp_func_name = NULL;
      smallest_union = ssg_smallest_union_valmode (left_native, right_native);
      if (SSG_VALMODE_LONG == smallest_union)
        cmp_func_name = "DB.DBA.RDF_LONG_CMP";
      else if (IS_BOX_POINTER (smallest_union))
        cmp_func_name = smallest_union->qmfCmpFuncName;
      else
        goto sqlval_operation;
      ssg_puts (s1);
      ssg_puts (cmp_func_name);
      ssg_puts ("(");
      ssg_print_retval_simple_expn (ssg, gp, left, smallest_union, NULL_ASNAME);
      ssg_puts (" ,");
      ssg_print_retval_simple_expn (ssg, gp, right, smallest_union, NULL_ASNAME);
      ssg_puts ("), 0)");
      return;
    }
sqlval_operation:
  ssg_puts (s1);
  ssg_print_retval_simple_expn (ssg, gp, left, SSG_VALMODE_SQLVAL, NULL_ASNAME);
  ssg_puts (s2);
  if (NULL == s3)
    return;
  ssg_print_retval_simple_expn (ssg, gp, right, SSG_VALMODE_SQLVAL, NULL_ASNAME);
  ssg_puts (s3);
}


void ssg_print_retval_simple_expn (spar_sqlgen_t *ssg, SPART *gp, SPART *tree, ssg_valmode_t needed, const char *asname)
{
  switch (SPART_TYPE (tree))
    {
    case BOP_AND:	ssg_print_retval_bop_calc_expn (ssg, gp, tree, " __and ("	, ", ", ")"	, 0, needed); goto print_asname;
    case BOP_OR:	ssg_print_retval_bop_calc_expn (ssg, gp, tree, " __or ("	, ", ", ")"	, 0, needed); goto print_asname;
    case BOP_EQ:	ssg_print_retval_bop_calc_expn (ssg, gp, tree, " equ ("		, ", ", ")"	, 0, needed); goto print_asname;
    case BOP_NEQ:	ssg_print_retval_bop_calc_expn (ssg, gp, tree, " neq ("		, ", ", ")"	, 0, needed); goto print_asname;
    case BOP_LT:	ssg_print_retval_bop_calc_expn (ssg, gp, tree, " lt ("		, ", ", ")"	, 1, needed); goto print_asname;
    case BOP_LTE:	ssg_print_retval_bop_calc_expn (ssg, gp, tree, " lte ("		, ", ", ")"	, 1, needed); goto print_asname;
    case BOP_GT:	ssg_print_retval_bop_calc_expn (ssg, gp, tree, " gt ("		, ", ", ")"	, 1, needed); goto print_asname;
    case BOP_GTE:	ssg_print_retval_bop_calc_expn (ssg, gp, tree, " gte ("		, ", ", ")"	, 1, needed); goto print_asname;
/*case BOP_LIKE: Like is built-in in SPARQL, not a BOP!
			ssg_print_retval_bop_calc_expn (ssg, gp, tree, " like "	, " strlike ("	, 0, SSG_VALMODE_BOOL); goto print_asname;
*/
/*
    case BOP_SAME:	ssg_print_bop_bool_expn (ssg, tree, "(", "= ", ")"); goto print_asname;
    case BOP_NSAME:	ssg_print_bop_bool_expn (ssg, tree, "(", "= ", ")"); goto print_asname;
*/

    case BOP_PLUS:	ssg_print_retval_bop_calc_expn (ssg, gp, tree, " ("		, " + ", ")"	, 0, needed); goto print_asname;
    case BOP_MINUS:	ssg_print_retval_bop_calc_expn (ssg, gp, tree, " ("		, " - ", ")"	, 0, needed); goto print_asname;
    case BOP_TIMES:	ssg_print_retval_bop_calc_expn (ssg, gp, tree, " ("		, " * ", ")"	, 0, needed); goto print_asname;
    case BOP_DIV:	ssg_print_retval_bop_calc_expn (ssg, gp, tree, " div ("		, ", ", ")"	, 0, needed); goto print_asname;
    case BOP_MOD:	ssg_print_retval_bop_calc_expn (ssg, gp, tree, " mod ("		, ", ", ")"	, 0, needed); goto print_asname;
    case SPAR_ALIAS:
      ssg_print_retval_simple_expn (ssg, gp, tree->_.alias.arg, needed, asname);
      return;
    case SPAR_BLANK_NODE_LABEL:
    case SPAR_VARIABLE:
      {
        caddr_t name = tree->_.var.vname;
        sparp_equiv_t *eq = sparp_equiv_get_ro (
          ssg->ssg_equivs, ssg->ssg_equiv_count,
          gp, (SPART *)name, SPARP_EQUIV_GET_NAMESAKES | SPARP_EQUIV_GET_ASSERT );
        int printed = ssg_print_equiv_retval_expn (ssg, gp, eq, SSG_RETVAL_FROM_JOIN_MEMBER | SSG_RETVAL_MUST_PRINT_SOMETHING, needed, asname);
        if (! printed)
          {
#ifdef DEBUG
            ssg_print_equiv_retval_expn (ssg, gp, eq, SSG_RETVAL_FROM_JOIN_MEMBER | SSG_RETVAL_MUST_PRINT_SOMETHING, needed, asname);
#endif
            spar_sqlprint_error ("ssg_print_retval_simple_expn(): can't print variable in retval expn");
          }
        return;
      }
    case SPAR_BUILT_IN_CALL:
      ssg_print_scalar_expn (ssg, tree, needed, asname);
      return;
    case SPAR_FUNCALL:
      {
        int bigtext, arg_ctr, arg_count = tree->_.funcall.argcount;
        xqf_str_parser_desc_t *parser_desc;
        int ctr;
	ssg_valmode_t native = ssg_rettype_of_function (ssg, tree->_.funcall.qname);
        if (needed != native)
          {
            if ((SSG_VALMODE_LONG == needed) && (SSG_VALMODE_SQLVAL == native))
          {
            ssg_puts (" DB.DBA.RDF_LONG_OF_SQLVAL (");
                ssg_print_retval_simple_expn (ssg, gp, tree, SSG_VALMODE_SQLVAL, NULL_ASNAME);
            ssg_puts (")");
                goto print_asname;
          }
            if ((SSG_VALMODE_SQLVAL == needed) && (SSG_VALMODE_LONG == native))
          {
                ssg_puts (" DB.DBA.RDF_SQLVAL_OF_LONG (");
                ssg_print_retval_simple_expn (ssg, gp, tree, SSG_VALMODE_LONG, NULL_ASNAME);
                ssg_puts (")");
                goto print_asname;
              }
            spar_sqlprint_error ("ssg_print_retval_simple_expn (): can't print funcall due to valmode mismatch");
          }
        ssg_putchar (' ');
        parser_desc = function_is_xqf_str_parser (tree->_.funcall.qname);
        if (NULL != parser_desc)
          {
            ssg_puts ("__xqf_str_parse ('");
            ssg_puts (parser_desc->p_name);
            ssg_puts ("'");
            ssg->ssg_indent++;
            for (ctr = 0; ctr < tree->_.funcall.argcount; ctr++)
              {
                ssg_puts (", ");
                ssg_print_scalar_expn (ssg, tree->_.funcall.argtrees[ctr], SSG_VALMODE_SQLVAL, NULL_ASNAME);
              }
            ssg->ssg_indent--;
            ssg_putchar (')');
            goto print_asname;
          }
        bigtext =
          ((NULL != strstr (tree->_.funcall.qname, "bif:")) ||
           (NULL != strstr (tree->_.funcall.qname, "sql:")) ||
           (arg_count > 3) );
        ssg_prin_function_name (ssg, tree->_.funcall.qname);
        ssg_puts (" (");
        ssg->ssg_indent++;
        for (arg_ctr = 0; arg_ctr < arg_count; arg_ctr++)
          {
            ssg_valmode_t argtype = ssg_argtype_of_function (ssg, tree->_.funcall.qname, arg_ctr);
            if (arg_ctr > 0)
              ssg_putchar (',');
            if (bigtext) ssg_newline (0); else ssg_putchar (' ');
            ssg_print_retval_simple_expn (ssg, gp, tree->_.funcall.argtrees[arg_ctr], argtype, NULL_ASNAME);
          }
        ssg->ssg_indent--;
        ssg_putchar (')');
        goto print_asname;
      }
    case SPAR_LIT: case SPAR_QNAME:/* case SPAR_QNAME_NS:*/
      ssg_print_scalar_expn (ssg, tree, needed, asname);
      return;
    default:
      break;
  }
  spar_sqlprint_error ("ssg_print_retval_simple_expn(): unsupported type of retval expression");
print_asname:
  if (IS_BOX_POINTER (asname))
    {
      ssg_puts (" AS /*retsimple*/ ");
      ssg_prin_id (ssg, asname);
    }
}


void
ssg_print_retval_expn (spar_sqlgen_t *ssg, SPART *gp, SPART *ret_column, int col_idx, int flags, SPART *auto_valmode_gp, ssg_valmode_t needed)
{
  int printed;
  int eq_flags;
  caddr_t var_name = NULL;
  const char *asname = NULL_ASNAME;
  sparp_equiv_t *eq;
  if (flags & SSG_RETVAL_NAME_INSTEAD_OF_TREE)
    asname = var_name = (caddr_t) ret_column;
  else if (flags & (SSG_RETVAL_USES_ALIAS | SSG_RETVAL_SUPPRESSED_ALIAS))
    {
      asname = spar_alias_name_of_ret_column (ret_column);
      var_name = spar_var_name_of_ret_column (ret_column);
    }
      if (NULL == var_name)
    {
      if (SSG_VALMODE_AUTO == needed)
        spar_sqlprint_error ("ssg_print_retval_expn(): SSG_VALMODE_AUTO for not a variable");
      if ((NULL_ASNAME == asname) && (flags & SSG_RETVAL_USES_ALIAS))
                {
          char buf[30];
          sprintf (buf, "callret-%d", col_idx);
          asname = buf;
        }
      ssg_print_retval_simple_expn (ssg, gp, ret_column, needed, asname);
      return;
    }
  eq_flags = SPARP_EQUIV_GET_NAMESAKES;
  if (!(flags & SSG_RETVAL_CAN_PRINT_NULL))
    eq_flags |= SPARP_EQUIV_GET_ASSERT;
  if (SSG_VALMODE_AUTO == needed)
    {
      sparp_equiv_t *auto_eq = sparp_equiv_get_ro (ssg->ssg_equivs, ssg->ssg_equiv_count, auto_valmode_gp, (SPART *)var_name, eq_flags);
      if (NULL != auto_eq)
        needed = ssg_equiv_native_valmode (ssg, auto_valmode_gp, auto_eq);
    }
  eq = sparp_equiv_get_ro (ssg->ssg_equivs, ssg->ssg_equiv_count, gp, (SPART *)var_name, eq_flags);
  printed = ssg_print_equiv_retval_expn (ssg, gp, eq, flags, needed, asname);
  if (! printed)
    {
#ifdef DEBUG
      ssg_print_equiv_retval_expn (ssg, gp, eq, flags, needed, asname);
#endif
      spar_sqlprint_error ("ssg_print_retval_expn(): can't print retval expn");
    }
}

void ssg_print_retval_cols (spar_sqlgen_t *ssg, SPART **retvals, ccaddr_t selid)
{
  int col_idx;
  DO_BOX_FAST (SPART *, ret_column, col_idx, retvals)
    {
      const char *asname = spar_alias_name_of_ret_column (ret_column);
      if (NULL_ASNAME == asname)
        {
          char buf[30];
          sprintf (buf, "callret-%d", col_idx);
          asname = t_box_dv_short_string (buf);
        }
      if (0 < col_idx)
        ssg_puts (", ");
      if (NULL != selid)
        {
          ssg_prin_id (ssg, selid);
          ssg_putchar ('.');
          ssg_prin_id (ssg, asname);
        }
      else
        ssg_print_literal (ssg, NULL, (SPART *)asname);
    }
  END_DO_BOX_FAST;
}

void
ssg_print_retval_list (spar_sqlgen_t *ssg, SPART *gp, SPART **retlist, int flags, SPART *auto_valmode_gp, ssg_valmode_t needed)
{
  int res_ctr, res_len;
  res_len = BOX_ELEMENTS_INT(retlist);
  if (0 == res_len)
    {
      if (SSG_VALMODE_SQLVAL == needed)
        ssg_puts (" 1");
      else
        ssg_puts (" NULL");
      if (flags & SSG_RETVAL_USES_ALIAS)
        {
          if ((flags & SSG_RETVAL_TOPMOST) && (ASK_L == ssg->ssg_tree->_.req_top.subtype))
            ssg_puts (" AS __ask_retval");
          else
            ssg_puts (" AS __dummy_retval");
        }
    }
  ssg->ssg_indent++;
  for (res_ctr = 0; res_ctr < res_len; res_ctr++)
    {
      SPART *ret_column = retlist[res_ctr];
      if (res_ctr > 0)
        {
          ssg_putchar (',');
          ssg_newline (1);
        }
      ssg_print_retval_expn (ssg, gp, ret_column, res_ctr, flags, auto_valmode_gp, needed);
    }
  ssg->ssg_indent--;
}

void
ssg_print_filter (spar_sqlgen_t *ssg, SPART *tree)
{
  ssg_print_where_or_and (ssg, "filter");
  ssg_print_filter_expn (ssg, tree);
}


void
ssg_print_all_table_fld_restrictions (spar_sqlgen_t *ssg, quad_map_t *qm, caddr_t alias, SPART **fields)
{
  if (NULL != qm->qmGraphMap)
    ssg_print_fld_restrictions (ssg, qm, qm->qmGraphMap, alias, fields[SPART_TRIPLE_GRAPH_IDX]);
  if (NULL != qm->qmSubjectMap)
    ssg_print_fld_restrictions (ssg, qm, qm->qmSubjectMap, alias, fields[SPART_TRIPLE_SUBJECT_IDX]);
  if (NULL != qm->qmPredicateMap)
    ssg_print_fld_restrictions (ssg, qm, qm->qmPredicateMap, alias, fields[SPART_TRIPLE_PREDICATE_IDX]);
  if (NULL != qm->qmObjectMap)
    ssg_print_fld_restrictions (ssg, qm, qm->qmObjectMap, alias, fields[SPART_TRIPLE_OBJECT_IDX]);
}


void
ssg_print_table_exp (spar_sqlgen_t *ssg, SPART **trees, int tree_count, int pass)
{
  SPART *tree;
#ifdef DEBUG
  if (1 > tree_count)
    spar_internal_error (ssg->ssg_sparp, "ssg_print_table_exp(): weird tree_count");
#endif
  tree = trees[0];
  switch (SPART_TYPE(tree))
    {
    case SPAR_TRIPLE:
      {
        caddr_t tabid = tree->_.triple.tabid;
        quad_map_t **qm_list = tree->_.triple.qm_list;
        quad_map_t *qm;
#ifdef DEBUG
        if (1 != BOX_ELEMENTS_0 (qm_list))
          spar_internal_error (ssg->ssg_sparp, "ssg_print_table_exp(): qm_list does not contain exactly one qm");
#endif
        qm = qm_list[0];
        if (( 1 == tree_count) && (NULL != strstr (qm->qmTableName, "DB.DBA.RDF_QUAD")))
          { /* Single table of plain triples */
            quad_map_t *qm = qm_list[0];
            ssg_qr_uses_jso (ssg, NULL, qm->qmTableName);
            if (1 == pass)
              {
                ssg_putchar (' ');
                ssg_puts (qm->qmTableName);
                ssg_qr_uses_table (ssg, qm->qmTableName);
                ssg_puts (" AS ");
                ssg_prin_id (ssg, tabid);
              }
            if (2 == pass)
              ssg_print_all_table_fld_restrictions (ssg, qm, tree->_.triple.tabid, tree->_.triple.tr_fields);
          }
        else
          { /* fake self-join on pk or single table of non-plain triples */
            if (1 == pass)
              {
                int save_where_l_printed;
                const char *save_where_l_text;
                caddr_t sub_tabid = t_box_sprintf (100, "%s-int", tabid);
                int tree_ctr, fld_ctr;
                dk_set_t colcodes = NULL;
                dk_set_t row_filters = NULL;
                ssg->ssg_indent++;
                ssg_puts (" (SELECT");
                for (tree_ctr = 0; tree_ctr < tree_count; tree_ctr++)
                  {
                    tree = trees[tree_ctr];
                    qm_list = tree->_.triple.qm_list;
                    qm = qm_list[0];
                    for (fld_ctr = 0; fld_ctr < SPART_TRIPLE_FIELDS_COUNT; fld_ctr++)
                      {
                        qm_format_t *fmt;
                        qm_value_t *qmv;
                        SPART *var;
                        caddr_t asname = NULL_ASNAME;
			caddr_t colcode;
                        fmt = tree->_.triple.native_formats[fld_ctr];
                        qmv = JSO_FIELD_ACCESS(qm_value_t *, qm, qm_field_map_offsets[fld_ctr])[0];
                        if (NULL == qmv)
                          continue;
                        var = tree->_.triple.tr_fields [fld_ctr];
                        if (SPAR_IS_BLANK_OR_VAR (var) && (1 < BOX_ELEMENTS (qmv->qmvColumns)))
                          {
                            asname = SPARP_EQUIV (ssg->ssg_sparp, var->_.var.equiv_idx)->e_varnames[0];
                            colcode = t_box_sprintf (210, "%.100s~%.100s", qmv->qmvColumns[0]->qmvcColumnName, asname);
                          }
                        else
                          colcode = qmv->qmvColumns[0]->qmvcColumnName;
                        if (0 <= dk_set_position_of_string (colcodes, colcode))
                          continue;
                        if (NULL != colcodes)
                          ssg_puts (", ");                        
                        ssg_print_tr_field_expn (ssg, qmv, sub_tabid, fmt, asname);
                        t_set_push (&colcodes, colcode);
                      }
                  }
                ssg_puts (" FROM ");
                ssg_puts (qm->qmTableName);
                if (NULL != ssg->ssg_sc->sc_cc)
                  qr_uses_table (ssg->ssg_sc->sc_cc->cc_super_cc->cc_query, qm->qmTableName);
                ssg_puts (" AS ");
                ssg_prin_id (ssg, sub_tabid);
                save_where_l_printed = ssg->ssg_where_l_printed;
                save_where_l_text = ssg->ssg_where_l_text;
                ssg->ssg_where_l_printed = 0;
                ssg->ssg_where_l_text = " WHERE";
                for (tree_ctr = 0; tree_ctr < tree_count; tree_ctr++)
                  {
                    caddr_t rowfilter = qm->qmTableRowFilter;
                    tree = trees[tree_ctr];
                    qm_list = tree->_.triple.qm_list;
                    qm = qm_list[0];
                    ssg_print_all_table_fld_restrictions (ssg, qm, sub_tabid, tree->_.triple.tr_fields);
                    if (NULL != rowfilter)
                      {
                        if (0 > dk_set_position_of_string (row_filters, rowfilter))
                          {
                            ssg_print_where_or_and (ssg, "row filter of quad map");
                            ssg_print_tmpl (ssg, NULL, rowfilter, sub_tabid, NULL, NULL, NULL_ASNAME);
                            t_set_push (&row_filters, rowfilter);
                          }
                      }
		  }
                ssg->ssg_where_l_printed = save_where_l_printed;
                ssg->ssg_where_l_text = save_where_l_text;
                ssg_puts (") AS ");
                ssg_prin_id (ssg, tree->_.triple.tabid);
                ssg->ssg_indent--;
              }
          }
        break;
      }
    case SPAR_GP:
      {
        if (1 == pass)
          {
            int eq_ctr;
            dk_set_t retvals_set = NULL;
            caddr_t *retlist;
            for (eq_ctr = tree->_.gp.equiv_count; eq_ctr--; /*no step*/)
              {
                sparp_equiv_t *eq = ssg->ssg_equivs[tree->_.gp.equiv_indexes[eq_ctr]];
                if (BOX_ELEMENTS_INT_0 (eq->e_receiver_idxs))
                  dk_set_push (&retvals_set, eq->e_varnames[0]);
              }
            retlist = (caddr_t *)list_to_array (retvals_set);
            ssg_puts (" (");
            ssg->ssg_indent++;
            ssg_print_union (ssg, tree, (SPART **)retlist, 0,
              ( SSG_RETVAL_FROM_FIRST_UNION_MEMBER | SSG_RETVAL_FROM_JOIN_MEMBER |
                SSG_RETVAL_USES_ALIAS | SSG_RETVAL_NAME_INSTEAD_OF_TREE | SSG_RETVAL_MUST_PRINT_SOMETHING ),
              SSG_VALMODE_AUTO );
            dk_free_box (retlist);
            ssg->ssg_indent--;
            ssg_puts (") AS ");
            ssg_prin_id (ssg, tree->_.gp.selid);
          } 
        break;
      }
    default: spar_sqlprint_error ("ssg_print_table_exp(): unsupported type of tree");
    }
}

void
ssg_print_union (spar_sqlgen_t *ssg, SPART *gp, SPART **retlist, int head_flags, int retval_flags, ssg_valmode_t needed)
{
  SPART **members;
  int memb_ctr, memb_count;
  int equiv_ctr;
  int save_where_l_printed;
  const char *save_where_l_text;
  if (UNION_L == gp->_.gp.subtype)
    {
      members = gp->_.gp.members;
      memb_count = BOX_ELEMENTS_INT (members);
      retval_flags |= SSG_RETVAL_CAN_PRINT_NULL;
    }
  else
    {
      members = &gp;
      memb_count = 1;
    }
  for (memb_ctr = 0; memb_ctr < memb_count; memb_ctr++)
    {
      SPART *member = members[memb_ctr];
      ccaddr_t prev_itm_alias = uname___empty;
      int first_tabexpn_itm_idx, itm_idx, itm_count;
      if ((memb_ctr > 0) || !(SSG_PRINT_UNION_NOFIRSTHEAD & head_flags))
        {
          ssg_newline (0);
          if (memb_ctr > 0)
            ssg_puts ("UNION ALL ");
          ssg_puts ("SELECT");
          ssg_print_retval_list (ssg, members[memb_ctr], retlist, retval_flags, gp, needed);
        }
      if (retval_flags & SSG_RETVAL_USES_ALIAS)
        {
          retval_flags &= ~SSG_RETVAL_USES_ALIAS; /* Aliases are not printed in resultsets of union, except the very first one... */
          retval_flags |= SSG_RETVAL_SUPPRESSED_ALIAS; /* ...but they're still known, right? */
        }
      ssg_newline (0);
      ssg_puts ("FROM");
      ssg->ssg_indent++;
#ifdef DEBUG
      if (SPAR_GP != SPART_TYPE (member))
        spar_internal_error (ssg->ssg_sparp, "ssg_print_union(): the member is not a SPAR_GP");
#endif
      itm_count = BOX_ELEMENTS (member->_.gp.members);
      if (0 == itm_count)
        {
          char buf[20];
          ssg_newline (0);
          sprintf (buf, "stub-%s", member->_.gp.selid);
          if (SSG_PRINT_UNION_NONEMPTY_STUB & head_flags)
            ssg_puts ("(SELECT TOP 1 1 AS __stub FROM DB.DBA.RDF_QUAD) AS ");
          else
            ssg_puts ("(SELECT TOP 1 1 AS __stub FROM DB.DBA.RDF_QUAD WHERE 1=2) AS ");
          ssg_prin_id (ssg, buf);
          goto end_of_table_list; /* see below */
        }
      for (itm_idx = 0; itm_idx < itm_count; itm_idx++)
        {
          SPART *itm = member->_.gp.members [itm_idx];
          ccaddr_t itm_alias;
          int itm_is_opt = 0;
          itm_alias = ssg_id_of_gp_or_triple (itm);
          first_tabexpn_itm_idx = itm_idx;
#if 0
          ssg_puts (t_box_sprintf (100, " /* alias %s #%d */", itm_alias, first_tabexpn_itm_idx));
#endif
          if (0 < itm_idx)
            {
              itm_is_opt = ((SPAR_GP == itm->type) && (OPTIONAL_L == itm->_.gp.subtype));
              if (itm_is_opt)
                {
                  ssg_newline (0);
                  ssg_puts ("LEFT OUTER JOIN");
                }
              else
                {
                  ssg_putchar (',');
                  ssg_newline (1);
                }
            }
          if (SPAR_TRIPLE == itm->type)
            {
              while (itm_idx + 1 < itm_count)
                {
                  SPART *next_itm = member->_.gp.members [itm_idx+1];
                  ccaddr_t next_itm_alias = ((SPAR_TRIPLE == next_itm->type) ? next_itm->_.triple.tabid : "");
                  if (strcmp (next_itm_alias, itm_alias))
                    break;
                  itm_idx++;
                }
            }
          ssg_print_table_exp (ssg, member->_.gp.members + first_tabexpn_itm_idx, itm_idx + 1 - first_tabexpn_itm_idx, 1); /* PASS 1, printing what's in FROM */
          if (itm_is_opt)
            {
              save_where_l_printed = ssg->ssg_where_l_printed;
              save_where_l_text = ssg->ssg_where_l_text;
              ssg->ssg_where_l_printed = 0;
              ssg->ssg_where_l_text = NULL;
              ssg_newline (0);
              ssg_puts ("ON (");
              ssg->ssg_indent++;
              for (equiv_ctr = 0; equiv_ctr < member->_.gp.equiv_count; equiv_ctr++)
                {
                  sparp_equiv_t *eq = ssg->ssg_equivs[member->_.gp.equiv_indexes[equiv_ctr]];
                  ssg_print_equivalences (ssg, member, eq, prev_itm_alias, itm_alias);
                }
              if (0 == ssg->ssg_where_l_printed)
                ssg_puts ("1=1");
              ssg->ssg_indent--;
              ssg_puts (")");
              ssg->ssg_where_l_printed = save_where_l_printed;
              ssg->ssg_where_l_text = save_where_l_text;
            }
          prev_itm_alias = itm_alias;
        }

end_of_table_list: ;
      ssg->ssg_indent--;
      save_where_l_printed = ssg->ssg_where_l_printed;
      save_where_l_text = ssg->ssg_where_l_text;
      ssg->ssg_where_l_printed = 0;
      ssg->ssg_where_l_text = "\bWHERE";
      ssg->ssg_indent++;
      for (itm_idx = 0; itm_idx < itm_count; itm_idx++)
        {
          SPART *itm = member->_.gp.members [itm_idx];
          ccaddr_t itm_alias;
          itm_alias = ssg_id_of_gp_or_triple (itm);
          first_tabexpn_itm_idx = itm_idx;
#if 0
          ssg_puts (t_box_sprintf (100, " /* alias %s #%d */", itm_alias, first_tabexpn_itm_idx));
#endif
          if (SPAR_TRIPLE == itm->type)
            {
              while (itm_idx + 1 < itm_count)
        {
                  SPART *next_itm = member->_.gp.members [itm_idx+1];
                  ccaddr_t next_itm_alias = ((SPAR_TRIPLE == next_itm->type) ? next_itm->_.triple.tabid : "");
                  if (strcmp (next_itm_alias, itm_alias))
                    break;
                  itm_idx++;
                }
            }
          ssg_print_table_exp (ssg, member->_.gp.members + first_tabexpn_itm_idx, itm_idx + 1 - first_tabexpn_itm_idx, 2); /* PASS 2, printing what's in WHERE */
        }
      for (equiv_ctr = 0; equiv_ctr < member->_.gp.equiv_count; equiv_ctr++)
        {
          sparp_equiv_t *eq = ssg->ssg_equivs[member->_.gp.equiv_indexes[equiv_ctr]];
          ssg_print_equivalences (ssg, member, eq, NULL, NULL);
        }
      DO_BOX_FAST (SPART *, itm, itm_idx, member->_.gp.filters)
        {
          ssg_print_filter (ssg, itm);
        }
      END_DO_BOX_FAST;
      ssg->ssg_where_l_printed = save_where_l_printed;
      ssg->ssg_where_l_text = save_where_l_text;
      ssg->ssg_indent--;
    }
}

void
ssg_print_orderby_item (spar_sqlgen_t *ssg, SPART *gp, SPART *oby_itm)
{
  ssg_print_retval_simple_expn (ssg, gp, oby_itm->_.oby.expn, SSG_VALMODE_SQLVAL, NULL_ASNAME);
  switch (oby_itm->_.oby.direction)
    {
    case ASC_L: ssg_puts (" ASC"); break;
    case DESC_L: ssg_puts (" DESC"); break;
    }
}

void ssg_make_sql_query_text (spar_sqlgen_t *ssg)
{
  int oby_ctr;
  long lim, ofs;
  SPART	*tree = ssg->ssg_tree;
  ptrlong subtype = tree->_.req_top.subtype;
  const char *formatter;
  ssg_valmode_t retvalmode;
  int top_retval_flags =
    SSG_RETVAL_TOPMOST |
    SSG_RETVAL_FROM_JOIN_MEMBER |
    SSG_RETVAL_FROM_FIRST_UNION_MEMBER |
    SSG_RETVAL_MUST_PRINT_SOMETHING |
    SSG_RETVAL_CAN_PRINT_NULL |
    SSG_RETVAL_USES_ALIAS ;
  ccaddr_t top_selid = tree->_.req_top.pattern->_.gp.selid;
  if (NULL != ssg->ssg_sparp->sparp_env->spare_storage_name)
    ssg_qr_uses_jso (ssg, NULL, ssg->ssg_sparp->sparp_env->spare_storage_name);
  ssg_qr_uses_jso (ssg, NULL, uname_virtrdf_ns_uri_QuadStorage);
  ssg->ssg_equiv_count = tree->_.req_top.equiv_count;
  ssg->ssg_equivs = tree->_.req_top.equivs;
  formatter = ssg_find_formatter_by_name_and_subtype (tree->_.req_top.formatmode_name, tree->_.req_top.subtype);
  retvalmode = ssg_find_valmode_by_name (tree->_.req_top.retvalmode_name);
  if ((NULL != formatter) && (NULL != retvalmode) && (SSG_VALMODE_LONG != retvalmode))
    spar_sqlprint_error ("'output:valmode' declaration conflicts with 'output:format'");
  switch (subtype)
    {
    case SELECT_L:
    case DISTINCT_L:
      if (NULL != formatter)
        {
          ssg_puts ("SELECT "); ssg_puts (formatter); ssg_puts (" (");
          ssg_puts ("vector (");
          ssg_print_retval_cols (ssg, tree->_.req_top.retvals, top_selid);
          ssg_puts ("), vector (");
          ssg_print_retval_cols (ssg, tree->_.req_top.retvals, NULL_ASNAME);
          ssg_puts (")) AS \"callret-0\" LONG VARCHAR\nFROM (");
          ssg->ssg_indent += 1;
          ssg_newline (0);
        }
      ssg_puts ("SELECT");
      lim = unbox (tree->_.req_top.limit);
      ofs = unbox (tree->_.req_top.offset);
      if ((2147483647 != lim) || (0 != ofs))
        {
          char buf[40];
          if (0 != ofs)
            sprintf (buf, " TOP %ld, %ld", ofs, lim);
          else
            sprintf (buf, " TOP %ld", lim);
          ssg_puts (buf);
        }
      if (DISTINCT_L == tree->_.req_top.subtype)
        ssg_puts (" DISTINCT");
      if (NULL == retvalmode)
        retvalmode = ((NULL != formatter) ? SSG_VALMODE_LONG : SSG_VALMODE_SQLVAL);
      ssg_print_retval_list (ssg, tree->_.req_top.pattern,
        tree->_.req_top.retvals, top_retval_flags, NULL, retvalmode );
      break;
    case CONSTRUCT_L:
    case DESCRIBE_L:
      if ((NULL == formatter) && ssg->ssg_sparp->sparp_sparqre->sparqre_direct_client_call)
        {
          formatter = ssg_find_formatter_by_name_and_subtype ("TTL", subtype);
          if ((NULL != retvalmode) && (SSG_VALMODE_LONG != retvalmode))
            spar_sqlprint_error ("'output:valmode' declaration conflicts with TTL output format needed by database client connection'");
        }
      /* No break here. INSERT_L and DELETE_L returns simple integers so no need to protect the client connection by formatting */
    case INSERT_L:
    case DELETE_L:
      ssg_puts ("SELECT TOP 1");
      if (NULL != formatter)
        {
          ssg_puts (" ");
          ssg_puts (formatter); ssg_puts (" (");
          ssg->ssg_indent += 1;
          ssg_newline (0);
          top_retval_flags &= ~SSG_RETVAL_USES_ALIAS;
        }
      retvalmode = SSG_VALMODE_SQLVAL;
      ssg_print_retval_list (ssg, tree->_.req_top.pattern,
        tree->_.req_top.retvals, top_retval_flags, NULL, retvalmode );
      if (NULL != formatter)
        {
          ssg_puts (" ) AS \"callret");
          if (NULL != tree->_.req_top.formatmode_name)
            ssg_puts (tree->_.req_top.formatmode_name);
          ssg_puts ("-0\" LONG VARCHAR");
          ssg->ssg_indent -= 1;
          ssg_newline (0);
        }
      break;
    case ASK_L:
      if (NULL != formatter)
        {
          ssg_puts ("SELECT "); ssg_puts (formatter); ssg_puts (" (");
          ssg_prin_id (ssg, top_selid);
          ssg_puts (".__ask_retval)\nFROM (");
          ssg->ssg_indent += 1;
        }
      ssg_puts ("SELECT TOP 1 1 AS __ask_retval");
      break;
    default: spar_sqlprint_error ("ssg_make_sql_query_text(): unsupported type of tree");
    }
  ssg_print_union (ssg, tree->_.req_top.pattern, tree->_.req_top.retvals,
    SSG_PRINT_UNION_NOFIRSTHEAD | SSG_PRINT_UNION_NONEMPTY_STUB | SSG_RETVAL_MUST_PRINT_SOMETHING,
    top_retval_flags, retvalmode );
  if ((0 < BOX_ELEMENTS_INT_0 (tree->_.req_top.order)) && (NULL == formatter))
    {
      ssg_newline (0);
      ssg_puts ("ORDER BY");
      ssg->ssg_indent++;
      DO_BOX_FAST(SPART *, oby_itm, oby_ctr, tree->_.req_top.order)
        {
	  if (oby_ctr > 0)
            ssg_putchar (',');
          ssg_print_orderby_item (ssg, tree->_.req_top.pattern, oby_itm);
        }
      END_DO_BOX_FAST;
      ssg->ssg_indent--;
    }
   ssg_puts ("\nOPTION (QUIETCAST)");
  if (NULL != formatter)
    {
      switch (tree->_.req_top.subtype)
        {
        case SELECT_L:
        case DISTINCT_L:
        case ASK_L:
          ssg_puts (" ) AS ");
          ssg_prin_id (ssg, top_selid);
          ssg->ssg_indent--;
          break;
        }
    }
}

void
ssg_print_qm_sql (spar_sqlgen_t *ssg, SPART *tree)
{
  switch (SPART_TYPE (tree))
  {
    case SPAR_QM_SQL:
      {
#define QM_SQL_ARG_IS_LONG(arg) ( \
  (SPAR_QM_SQL == SPART_TYPE (arg)) || \
  (((DV_STRING == DV_TYPE_OF (arg)) || (DV_STRING == DV_TYPE_OF (arg))) && \
    (40 < box_length (arg)) ) )
        int ctr, prev_was_long, fixedlen, namedlen;
        prev_was_long = 0;
        ssg_puts (tree->_.qm_sql.fname);
        ssg_puts (" (");
        ssg->ssg_indent++;
        fixedlen = BOX_ELEMENTS_0 (tree->_.qm_sql.fixed);
        for (ctr = 0; ctr < fixedlen; ctr++)
          {
            SPART *arg = tree->_.qm_sql.fixed[ctr];
            int curr_is_long = QM_SQL_ARG_IS_LONG(arg);
            if (0 != ctr)
              ssg_puts (", ");
            if (curr_is_long || prev_was_long)
              ssg_newline (0);
            ssg_print_qm_sql (ssg, arg);
            prev_was_long = curr_is_long;
          }
        if (NULL != tree->_.qm_sql.named)
          {
            if (0 != fixedlen)
              ssg_puts (", ");
            if (prev_was_long)
              ssg_newline (0);
            prev_was_long = 0;
            ssg_puts ("vector (");
            ssg->ssg_indent++;
            namedlen = BOX_ELEMENTS_0 (tree->_.qm_sql.named);
            for (ctr = 0; ctr < namedlen; ctr++)
              {
                SPART *arg = tree->_.qm_sql.named[ctr];
                int curr_is_long = QM_SQL_ARG_IS_LONG(arg);
                if (0 != ctr)
                  ssg_puts (", ");
                if (curr_is_long || prev_was_long)
                  ssg_newline (0);
                ssg_print_qm_sql (ssg, arg);
                prev_was_long = curr_is_long;
              }
            ssg->ssg_indent--;
            ssg_puts (" )");
          }
        ssg->ssg_indent--;
        ssg_puts (" )");
        break;
#undef QM_SQL_ARG_IS_LONG
      }
    default:
      if (NULL == tree)
        {
          ssg_puts (" NULL");
          return;
        }
     ssg_print_scalar_expn (ssg, tree, SSG_VALMODE_SQLVAL, NULL_ASNAME);
/*
    default: spar_internal_error (ssg->ssg_sparp, "ssg_print_qm_sql(): unsupported tree type");
*/
  }
}

void
ssg_make_qm_sql_text (spar_sqlgen_t *ssg)
{
  ssg_print_qm_sql (ssg, ssg->ssg_tree);
}

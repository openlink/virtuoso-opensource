/*
 *  $Id$
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
#include "srvmultibyte.h"
#include "remote.h" /* for sqlrcomp.h */
#include "sqlrcomp.h"
#include "xmltree.h"
#include "xml_ecm.h" /* for ecm_find_name etc. */
#include "xpf.h"
#include "xqf.h"
#include "date.h" /* for DT_DT_TYPE */
#include "numeric.h"
#ifdef __cplusplus
extern "C" {
#endif
#include "sparql_p.h"
#ifdef __cplusplus
}
#endif
extern id_hash_t *name_to_bif_type; /* from sqlbif.c */

/* Description of RDF datasources */

qm_format_t *qm_format_default_iri_ref;
qm_format_t *qm_format_default_ref;
qm_format_t *qm_format_default;
qm_format_t *qm_format_default_iri_ref_nullable;
qm_format_t *qm_format_default_ref_nullable;
qm_format_t *qm_format_default_nullable;
qm_value_t *qm_default_values[SPART_TRIPLE_FIELDS_COUNT];
quad_map_t *qm_default;
triple_case_t *tc_default;
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
  qmf->qmfSqlvalTmpl = box_dv_short_string (" id_to_iri (^{alias-dot}^^{column}^)");
  qmf->qmfBoolTmpl = box_dv_short_string (" NULL");
  qmf->qmfIsrefOfShortTmpl = box_dv_short_string (" 1");
  qmf->qmfIsuriOfShortTmpl = box_dv_short_string (" (^{tree}^ < min_bnode_iri_id ())");
  qmf->qmfIsblankOfShortTmpl = box_dv_short_string (" (^{tree}^ >= min_bnode_iri_id ())");
  qmf->qmfIslitOfShortTmpl = box_dv_short_string (" 0");
  qmf->qmf01uriOfShortTmpl = box_dv_short_string (" (lt (^{tree}^, min_bnode_iri_id ()))");
  qmf->qmf01blankOfShortTmpl = box_dv_short_string (" (gte (^{tree}^, min_bnode_iri_id ()))");
  qmf->qmfLongOfShortTmpl = box_dv_short_string (" ^{tree}^ ");
  qmf->qmfDatatypeOfShortTmpl = box_dv_short_string (" 'http://www.w3.org/2001/XMLSchema#anyURI'");
  qmf->qmfLanguageOfShortTmpl = box_dv_short_string (" NULL");
  qmf->qmfSqlvalOfShortTmpl = box_dv_short_string (" id_to_iri (^{tree}^)");
  qmf->qmfBoolOfShortTmpl = box_dv_short_string (" NULL");
  qmf->qmfIidOfShortTmpl = box_dv_short_string (" ^{tree}^");
  qmf->qmfUriOfShortTmpl = box_dv_short_string (" id_to_iri (^{tree}^)");
  qmf->qmfStrsqlvalOfShortTmpl = box_dv_short_string (" id_to_iri (^{tree}^)");
  qmf->qmfShortOfTypedsqlvalTmpl = box_dv_short_string (" NULL");
  qmf->qmfShortOfSqlvalTmpl = box_dv_short_string (" DB.DBA.RDF_MAKE_IID_OF_QNAME_SAFE (^{tree}^)");
  qmf->qmfShortOfLongTmpl = box_dv_short_string (" /* SHORT of LONG: */ ^{tree}^");
  qmf->qmfShortOfUriTmpl = box_dv_short_string (" DB.DBA.RDF_MAKE_IID_OF_QNAME_SAFE (^{tree}^)");
  qmf->qmfCmpFuncName = box_dv_short_string ("DB.DBA.RDF_IID_CMP");
  qmf->qmfTypeminTmpl = box_dv_short_string (" NULL"); /* No order on IRIs */
  qmf->qmfTypemaxTmpl = box_dv_short_string (" NULL"); /* No order on IRIs */
  qmf->qmfColumnCount = 1;
  qmf->qmfOkForAnySqlvalue = 0; /* It can not store anything except IRI ids */
  qmf->qmfIsBijection = 1;
  qmf->qmfIsSubformatOfLong = 1;
  qmf->qmfValRange.rvrRestrictions = SPART_VARR_IS_REF | SPART_VARR_IS_IRI | SPART_VARR_NOT_NULL;
  qmf->qmfValRange.rvrDatatype = NULL;
  qmf->qmfValRange.rvrLanguage = NULL;
  qmf->qmfValRange.rvrFixedValue = NULL;
  qmf->qmfValRange.rvrSprintffs = NULL;
  qmf->qmfValRange.rvrSprintffCount = 0;
  qmf->qmfValRange.rvrIriClasses = NULL;
  qmf->qmfValRange.rvrIriClassCount = 0;
  qmf->qmfValRange.rvrRedCuts = NULL;
  qmf->qmfValRange.rvrRedCutCount = 0;
  qmf->qmfUriIdOffset = 0;

  qmf = qm_format_default = dk_alloc_box_zero (sizeof (qm_format_t), DV_ARRAY_OF_POINTER);
  qmf->qmfName = box_dv_short_string ("default");
  qmf->qmfShortTmpl = box_dv_short_string (" ^{alias-dot}^^{column}^");
  qmf->qmfLongTmpl = box_dv_short_string (" __rdf_long_of_obj /*o*/ (^{alias-dot}^^{column}^)");
  qmf->qmfSqlvalTmpl = box_dv_short_string (" __rdf_sqlval_of_obj /*o*/ (^{alias-dot}^^{column}^)");
  qmf->qmfBoolTmpl = box_dv_short_string (" DB.DBA.RQ_BOOL_OF_O (^{alias-dot}^^{column}^)");
  qmf->qmfIsrefOfShortTmpl = box_dv_short_string (" isiri_id (^{tree}^)");
  qmf->qmfIsuriOfShortTmpl = box_dv_short_string (" is_named_iri_id (^{tree}^)");
  qmf->qmfIsblankOfShortTmpl = box_dv_short_string (" is_bnode_iri_id (^{tree}^)");
  qmf->qmfIslitOfShortTmpl = box_dv_short_string (" (1 - isiri_id (^{tree}^))");
  qmf->qmfLongOfShortTmpl = box_dv_short_string (" __rdf_long_of_obj (^{tree}^)");
  qmf->qmfDatatypeOfShortTmpl = box_dv_short_string (" DB.DBA.RDF_DATATYPE_OF_OBJ (^{tree}^)");
  qmf->qmfLanguageOfShortTmpl = box_dv_short_string (" DB.DBA.RDF_LANGUAGE_OF_OBJ (^{tree}^)");
  qmf->qmfSqlvalOfShortTmpl = box_dv_short_string (" __rdf_sqlval_of_obj (^{tree}^)");
  qmf->qmfBoolOfShortTmpl = box_dv_short_string (" DB.DBA.RDF_BOOL_OF_OBJ (^{tree}^)");
  qmf->qmfIidOfShortTmpl = box_dv_short_string (" DB.DBA.RDF_MAKE_IID_OF_LONG (__rdf_long_of_obj (^{tree}^))");
  qmf->qmfUriOfShortTmpl = box_dv_short_string (" id_to_iri_nosignal (^{tree}^)");
  qmf->qmfStrsqlvalOfShortTmpl = box_dv_short_string (" __rdf_strsqlval (^{tree}^)");
  qmf->qmfShortOfTypedsqlvalTmpl = box_dv_short_string (" DB.DBA.RDF_MAKE_OBJ_OF_TYPEDSQLVAL (^{sqlval-of-tree}^, DB.DBA.RDF_MAKE_IID_OF_QNAME(^{datatype-of-tree}^), ^{language-of-tree}^)");
  qmf->qmfShortOfSqlvalTmpl = box_dv_short_string (" DB.DBA.RDF_OBJ_OF_SQLVAL (^{tree}^)");
  qmf->qmfShortOfLongTmpl = box_dv_short_string (" DB.DBA.RDF_OBJ_OF_LONG (^{tree}^)");
  qmf->qmfShortOfUriTmpl = box_dv_short_string (" DB.DBA.RDF_MAKE_IID_OF_QNAME_SAFE (^{tree}^)");
  qmf->qmfCmpFuncName = box_dv_short_string ("DB.DBA.RDF_OBJ_CMP");
  qmf->qmfTypeminTmpl = box_dv_short_string (" DB.DBA.RDF_TYPEMIN_OF_OBJ (^{tree}^)");
  qmf->qmfTypemaxTmpl = box_dv_short_string (" DB.DBA.RDF_TYPEMAX_OF_OBJ (^{tree}^)");
  qmf->qmfColumnCount = 1;
  qmf->qmfIsBijection = 1;
  qmf->qmfIsSubformatOfLongWhenEqToSql = 1;
  qmf->qmfIsSubformatOfLongWhenRef = 1;
  qmf->qmfOkForAnySqlvalue = 1; /* It can store anything */
  qmf->qmfValRange.rvrRestrictions = SPART_VARR_NOT_NULL;
  qmf->qmfValRange.rvrDatatype = NULL;
  qmf->qmfValRange.rvrLanguage = NULL;
  qmf->qmfValRange.rvrFixedValue = NULL;
  qmf->qmfValRange.rvrSprintffs = NULL;
  qmf->qmfValRange.rvrSprintffCount = 0;
  qmf->qmfValRange.rvrIriClasses = NULL;
  qmf->qmfValRange.rvrIriClassCount = 0;
  qmf->qmfValRange.rvrRedCuts = NULL;
  qmf->qmfValRange.rvrRedCutCount = 0;
  qmf->qmfUriIdOffset = 0;

  qmf = qm_format_default_ref = box_copy (qm_format_default_iri_ref);
  qmf->qmfName = box_dv_short_string ("default-iid");
  qmf->qmfValRange.rvrRestrictions = SPART_VARR_IS_REF | SPART_VARR_NOT_NULL;

  qmf = qm_format_default_iri_ref_nullable = box_copy (qm_format_default_iri_ref);
  qmf->qmfName = box_dv_short_string ("default-iid-nonblank-nullable");
  qmf->qmfValRange.rvrRestrictions &= ~SPART_VARR_NOT_NULL;

  qmf = qm_format_default_ref_nullable = box_copy (qm_format_default_ref);
  qmf->qmfName = box_dv_short_string ("default-iid-nullable");
  qmf->qmfValRange.rvrRestrictions &= ~SPART_VARR_NOT_NULL;

  qmf = qm_format_default_nullable = box_copy (qm_format_default);
  qmf->qmfName = box_dv_short_string ("default-nullable");
  qmf->qmfValRange.rvrRestrictions &= ~SPART_VARR_NOT_NULL;

  qm_format_default->qmfSuperFormats = (qm_format_t**) list (1, qm_format_default_nullable);
  qm_format_default_ref->qmfSuperFormats = (qm_format_t**) list (3, qm_format_default_ref_nullable, qm_format_default, qm_format_default_nullable);
  qm_format_default_iri_ref->qmfSuperFormats = (qm_format_t**) list (5, qm_format_default_iri_ref_nullable, qm_format_default_ref, qm_format_default_ref_nullable, qm_format_default, qm_format_default_nullable);
  qm_format_default_ref_nullable->qmfSuperFormats = (qm_format_t**) list (1, qm_format_default_nullable);
  qm_format_default_iri_ref_nullable->qmfSuperFormats = (qm_format_t**) list (2, qm_format_default_ref_nullable, qm_format_default_nullable);

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

  tc_default = dk_alloc_box_zero (sizeof (triple_case_t), DV_ARRAY_OF_POINTER);
  tc_default->tc_qm = qm_default;

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
  if (!strcmp (name, "AUTO"))
    return SSG_VALMODE_AUTO;
  spar_error (NULL, "Unsupported valmode name '%.30s', only 'SQLVAL' and 'LONG' are supported", name);
  return NULL; /* to keep compiler happy */
}

void
ssg_find_formatter_by_name_and_subtype (ccaddr_t name, ptrlong subtype,
  const char **ret_formatter, const char **ret_agg_formatter, const char **ret_agg_mdata )
{
  ret_formatter[0] = ret_agg_formatter[0] = ret_agg_mdata[0] = NULL;
  if (NULL == name)
    return;
  if (!strncmp (name, "HTTP+", 5))
    {
/*                     0123456789 */
  if (!strncmp (name, "HTTP+XML ", 9))
    switch (subtype)
      {
      case SELECT_L: case COUNT_DISTINCT_L: case DISTINCT_L: ret_agg_formatter[0] = "DB.DBA.SPARQL_RSET_XML_HTTP"; ret_agg_mdata[0] = "DB.DBA.SPARQL_RSET_XML_HTTP_PRE"; return;
      case CONSTRUCT_L: case DESCRIBE_L: goto bad_descr; /* see below */
      case ASK_L: goto bad_ask; /* see below */
      default: return;
      }
#if 0
/*                     0         1   */
/*                     0123456789012 */
  if (!strncmp (name, "HTTP+RDF/XML ", 12))
    switch (subtype)
      {
      case SELECT_L: case COUNT_DISTINCT_L: case DISTINCT_L: ret_agg_formatter[0] = "DB.DBA.SPARQL_RSET_RDFXML_HTTP"; ret_agg_mdata[0] = "DB.DBA.SPARQL_RSET_RDFXML_HTTP_PRE"; return;
#if 0
      case CONSTRUCT_L: case DESCRIBE_L: ret_agg_formatter[0] = "DB.DBA.SPARQL_DICT_RDFXML_HTTP"; ret_agg_mdata[0] = "DB.DBA.SPARQL_DICT_RDFXML_HTTP_PRE"; return;
      case ASK_L: goto bad_ask; /* see below */
#else
      case CONSTRUCT_L: case DESCRIBE_L: ret_formatter[0] = "DB.DBA.RDF_FORMAT_TRIPLE_DICT_AS_RDF_XML"; return;
      case ASK_L: ret_formatter[0] = "DB.DBA.RDF_FORMAT_BOOL_RESULT_AS_RDF_XML"; return;
#endif
      default: return;
      }
#endif
/*                     0123456789 */
  if (!strncmp (name, "HTTP+TTL ", 9))
    switch (subtype)
      {
      case SELECT_L: case COUNT_DISTINCT_L: case DISTINCT_L: ret_agg_formatter[0] = "DB.DBA.SPARQL_RSET_TTL_HTTP"; ret_agg_mdata[0] = "DB.DBA.SPARQL_RSET_TTL_HTTP_PRE"; return;
#if 0
      case CONSTRUCT_L: case DESCRIBE_L: ret_agg_formatter[0] = "DB.DBA.SPARQL_DICT_TTL_HTTP"; ret_agg_mdata[0] = "DB.DBA.SPARQL_DICT_TTL_HTTP_PRE"; return;
      case ASK_L: goto bad_ask; /* see below */
#else
      case CONSTRUCT_L: case DESCRIBE_L: ret_formatter[0] = "DB.DBA.RDF_FORMAT_TRIPLE_DICT_AS_TTL"; return;
      case ASK_L: ret_formatter[0] = "DB.DBA.RDF_FORMAT_BOOL_RESULT_AS_TTL"; return;
#endif
      default: return;
      }
    }
  if (!strcmp (name, "RDF/XML"))
    switch (subtype)
      {
      case SELECT_L: case COUNT_DISTINCT_L: case DISTINCT_L: ret_formatter[0] = "DB.DBA.RDF_FORMAT_RESULT_SET_AS_RDF_XML"; return;
      case CONSTRUCT_L: case DESCRIBE_L: ret_formatter[0] = "DB.DBA.RDF_FORMAT_TRIPLE_DICT_AS_RDF_XML"; return;
      case ASK_L: ret_formatter[0] = "DB.DBA.RDF_FORMAT_BOOL_RESULT_AS_RDF_XML"; return;
      default: return;
      }
  if (!strcmp (name, "TURTLE") || !strcmp (name, "TTL"))
    switch (subtype)
      {
      case SELECT_L: case COUNT_DISTINCT_L: case DISTINCT_L: ret_formatter[0] = "DB.DBA.RDF_FORMAT_RESULT_SET_AS_TTL"; return;
      case CONSTRUCT_L: case DESCRIBE_L: ret_formatter[0] = "DB.DBA.RDF_FORMAT_TRIPLE_DICT_AS_TTL"; return;
      case ASK_L: ret_formatter[0] = "DB.DBA.RDF_FORMAT_BOOL_RESULT_AS_TTL"; return;
      default: return;
      }
  if (!strcmp (name, "_JAVA_"))
    switch (subtype)
      {
      case ASK_L: ret_formatter[0] = "COUNT"; return;
      default: return;
      }
  spar_error (NULL, "Unsupported format name '%.40s', only 'RDF/XML', 'TURTLE' and '_JAVA_' are supported", name);
bad_ask:
  spar_error (NULL, "Format name '%.30s' is not supported for booleand results made by SPARQL %s", name, spart_dump_opname (subtype, 0));
bad_descr:
  spar_error (NULL, "Format name '%.30s' is not supported for triple dictionaries made by SPARQL %s", name, spart_dump_opname (subtype, 0));
}

/* Dependency tracking */

void
sparp_jso_push_affected (sparp_t *sparp, ccaddr_t inst_iri)
{
  dk_set_t *set_ptr = &(sparp->sparp_env->spare_qm_affected_jso_iris);
  if (0 > dk_set_position_of_string (set_ptr[0], inst_iri))
    t_set_push (set_ptr, (caddr_t)inst_iri);
}

void
sparp_jso_push_deleted (sparp_t *sparp, ccaddr_t class_iri, ccaddr_t inst_iri)
{
  dk_set_t *set_ptr = &(sparp->sparp_env->spare_qm_deleted);
  t_set_push (set_ptr, (caddr_t)class_iri);
  t_set_push (set_ptr, (caddr_t)inst_iri);
}

void 
ssg_qr_uses_jso (spar_sqlgen_t *ssg, ccaddr_t jso_inst, ccaddr_t jso_name)
{
  comp_context_t *cc = ssg->ssg_sc->sc_cc;
  if (NULL == cc)
    return;
  if (NULL == jso_name)
    {
      jso_rtti_t *jso_rtti = gethash (jso_inst, jso_rttis_of_names);
      if (NULL == jso_rtti)
        return; /* Built-in anonymous JSO, like one used when define input:storage "" */
      jso_name = jso_rtti->jrtti_inst_iri;
    }
  box_dv_uname_make_immortal ((caddr_t)jso_name);
  qr_uses_jso (cc->cc_super_cc->cc_query, jso_name);
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


#define CMD_EQUAL(w,l) ((l == cmdlen) && (!memcmp (w, cmd, l)))
int
ssg_print_tmpl_phrase (struct spar_sqlgen_s *ssg, qm_format_t *qm_fmt, const char *tmpl, const char *tmpl_end, caddr_t alias, qm_value_t *qm_val, SPART *tree, int col_idx, const char *asname)
{
/* IMPORTANT: keep this function in sync with sparp_check_tmpl(), otherwise syntax changes may be blicked by the compiler. */
  const char *tail;
  const char *cmd;
  const char *mopen_hit;
  const char *mclose_hit;
  int cmdlen;
  int asname_printed = 0;
  tail = tmpl;
  while (tail < tmpl_end)
    {
      mopen_hit = strstr (tail, "^{");
      if (mopen_hit >= tmpl_end)
        mopen_hit = NULL;
      mclose_hit = strstr (tail, "}^");
      if (mclose_hit >= tmpl_end)
        mclose_hit = NULL;
      if ((NULL == mopen_hit) && (NULL == mclose_hit))
        {
          session_buffered_write (ssg->ssg_out, tail, tmpl_end - tail);
          break;
        }
      if (NULL == mclose_hit)
        spar_sqlprint_error2 ("ssg_" "print_tmpl(): template string contains '^{' without matching '}^'", asname_printed);
      if ((NULL == mopen_hit) || (mclose_hit < mopen_hit))
        spar_sqlprint_error2 ("ssg_" "print_tmpl(): template string contains '}^' without matching '^{'", asname_printed);
      cmd = mopen_hit + 2;
      cmdlen = mclose_hit - cmd;
      session_buffered_write (ssg->ssg_out, tail, mopen_hit - tail);
      tail = mclose_hit + 2;
      if ('.' == cmd [cmdlen-1])
        {
          caddr_t a = t_box_dv_short_nchars (cmd, cmdlen - 1);
          caddr_t subalias;
          if (NULL == alias)
            spar_sqlprint_error2 ("ssg_" "print_tmpl(): can't print NULL alias", asname_printed);
          if ('!' == a[0])
            subalias = alias;
          else
            subalias = t_box_sprintf (210, "%.100s~%.100s", alias, a);
          ssg_prin_id (ssg, subalias);
        }
/*                   0         1         2 */
/*                   012345678901234567890 */
      else if (CMD_EQUAL("N", 1))
        {
          char buf[10];
          if (col_idx < 0)
            spar_sqlprint_error2 ("ssg_" "print_tmpl(): can't use column number outside the loop", asname_printed);
          snprintf (buf, sizeof (buf), "%d", col_idx);
          ssg_puts (buf);
        }
/*                   0         1         2 */
/*                   012345678901234567890 */
      else if (CMD_EQUAL("N1", 2))
        {
          char buf[10];
          if (col_idx < 0)
            spar_sqlprint_error2 ("ssg_" "print_tmpl(): can't use column number outside the loop", asname_printed);
          snprintf (buf, sizeof (buf), "%d", col_idx+1);
          ssg_puts (buf);
        }
/*                        0         1         2 */
/*                        012345678901234567890 */
      else if (CMD_EQUAL("alias", 5))
        {
          if (NULL == alias)
            spar_sqlprint_error2 ("ssg_" "print_tmpl(): can't print NULL alias", asname_printed);
          ssg_prin_id (ssg, alias);
        }
/*                        0         1         2 */
/*                        012345678901234567890 */
      else if (CMD_EQUAL("alias-0", 7))
        {
          ccaddr_t colalias;
          if (NULL == alias)
            spar_sqlprint_error2 ("ssg_" "print_tmpl(): can't print NULL alias", asname_printed);
          if (NULL == qm_val)
            spar_sqlprint_error2 ("ssg_" "print_tmpl(): can't use ^{alias-0}^ if qm_val is NULL", asname_printed);
          colalias = qm_val->qmvColumns[0]->qmvcAlias;
          if ((NULL == colalias) || ('!' == colalias[0]))
            ssg_prin_id (ssg, alias);
          else
            {
              caddr_t subalias = t_box_sprintf (210, "%.100s~%.100s", alias, colalias);
              ssg_prin_id (ssg, subalias);
            }
        }
/*                        0         1         2 */
/*                        012345678901234567890 */
      else if (CMD_EQUAL("alias-1", 7))
        {
          ccaddr_t colalias;
          if (NULL == alias)
            spar_sqlprint_error2 ("ssg_" "print_tmpl(): can't print NULL alias", asname_printed);
          if (NULL == qm_val)
            spar_sqlprint_error2 ("ssg_" "print_tmpl(): can't use ^{alias-1}^ if qm_val is NULL", asname_printed);
          colalias = qm_val->qmvColumns[1]->qmvcAlias;
          if ((NULL == colalias) || ('!' == colalias[0]))
            ssg_prin_id (ssg, alias);
          else
            {
              caddr_t subalias = t_box_sprintf (210, "%.100s~%.100s", alias, colalias);
              ssg_prin_id (ssg, subalias);
            }
        }
/*                        0         1         2 */
/*                        012345678901234567890 */
      else if (CMD_EQUAL("alias-dot", 9))
        {
          ccaddr_t colalias;
          if (NULL == qm_val)
            spar_sqlprint_error2 ("ssg_" "print_tmpl(): can't use ^{alias-dot}^ if qm_val is NULL", asname_printed);
          if (1 != BOX_ELEMENTS (qm_val->qmvColumns))
            {
              if ((2 < BOX_ELEMENTS (qm_val->qmvColumns)) || strcmp (qm_val->qmvColumns[0]->qmvcAlias, qm_val->qmvColumns[1]->qmvcAlias))
                spar_sqlprint_error2 ("ssg_" "print_tmpl(): can't use ^{alias-dot}^ if qm_val has many columns", asname_printed);
            }
          if (col_idx >= 0)
            spar_sqlprint_error2 ("ssg_" "print_tmpl(): can't use ^{alias-dot}^ inside a loop, should be ^{column-N}^", asname_printed);
          colalias = qm_val->qmvColumns[0]->qmvcAlias;
          if (NULL != alias)
            {
              if ((NULL == colalias) || ('!' == colalias[0]))
                ssg_prin_id (ssg, alias);
              else
                {
                  caddr_t subalias = t_box_sprintf (210, "%.100s~%.100s", alias, colalias);
                  ssg_prin_id (ssg, subalias);
                }
              ssg_putchar ('.');
            }
        }
/*                        0         1         2 */
/*                        012345678901234567890 */
      else if (CMD_EQUAL("alias-N-dot", 11))
        {
          ccaddr_t colalias;
          if (NULL == qm_val)
            spar_sqlprint_error2 ("ssg_" "print_tmpl(): can't use ^{alias-N-dot}^ if qm_val is NULL", asname_printed);
          if (col_idx < 0)
            spar_sqlprint_error2 ("ssg_" "print_tmpl(): can't use ^{alias-N-dot}^ outside a loop, should be ^{alias-dot}^", asname_printed);
          if (col_idx >= BOX_ELEMENTS (qm_val->qmvColumns))
            spar_sqlprint_error2 ("ssg_" "print_tmpl(): col index for ^{alias-N-dot}^ exceedes number of columns", asname_printed);
          colalias = qm_val->qmvColumns[col_idx]->qmvcAlias;
          if (NULL != alias)
            {
              if ((NULL == colalias) || ('!' == colalias[0]))
                ssg_prin_id (ssg, alias);
              else
                {
                  caddr_t subalias = t_box_sprintf (210, "%.100s~%.100s", alias, colalias);
                  ssg_prin_id (ssg, subalias);
                }
              ssg_putchar ('.');
            }
        }
/*                        0         1         2 */
/*                        012345678901234567890 */
      else if (CMD_EQUAL("as-name", 7))
        {
          if (col_idx >= 0)
            spar_sqlprint_error2 ("ssg_" "print_tmpl(): can't use ^{as-name}^ inside a loop, should be ^{as-name-N}^", asname_printed);
          if (IS_BOX_POINTER (asname))
            {
#ifdef NDEBUG
              ssg_puts (" AS ");
#else
              ssg_puts (" AS /*as-name*/ ");
#endif
              ssg_prin_id (ssg, asname);
            }
          asname_printed = 1;
        }
/*                        0         1         2 */
/*                        012345678901234567890 */
      else if (CMD_EQUAL("as-name-0", 9))
        {
          if (IS_BOX_POINTER (asname))
            {
              char buf[60];
              snprintf (buf, sizeof (buf), "%s~%d", asname, 0);
#ifdef NDEBUG
              ssg_puts (" AS ");
#else
              ssg_puts (" AS /*as-name-0*/ ");
#endif
              ssg_prin_id (ssg, buf);
              asname_printed = 1;
            }
        }
/*                        0         1         2 */
/*                        012345678901234567890 */
      else if (CMD_EQUAL("as-name-1", 9))
        {
          if (IS_BOX_POINTER (asname))
            {
              char buf[60];
              snprintf (buf, sizeof (buf), "%s~%d", asname, 1);
#ifdef NDEBUG
              ssg_puts (" AS ");
#else
              ssg_puts (" AS /*as-name-0*/ ");
#endif
              ssg_prin_id (ssg, buf);
              asname_printed = 1;
            }
        }
/*                        0         1         2 */
/*                        012345678901234567890 */
      else if (CMD_EQUAL("as-name-dt", 10))
        {
          if (col_idx >= 0)
            spar_sqlprint_error2 ("ssg_" "print_tmpl(): can't use ^{as-name-dt}^ inside a loop", asname_printed);
          if (IS_BOX_POINTER (asname))
            {
#ifdef NDEBUG
              ssg_puts (" AS ");
#else
              ssg_puts (" AS /*as-name-dt*/ ");
#endif
              ssg_prin_id_with_suffix (ssg, asname, "_dt");
            }
          asname_printed = 1;
        }
/*                        0         1         2 */
/*                        012345678901234567890 */
      else if (CMD_EQUAL("as-name-lang", 12))
        {
          if (col_idx >= 0)
            spar_sqlprint_error2 ("ssg_" "print_tmpl(): can't use ^{as-name-lang}^ inside a loop", asname_printed);
          if (IS_BOX_POINTER (asname))
            {
#ifdef NDEBUG
              ssg_puts (" AS ");
#else
              ssg_puts (" AS /*as-name-lang*/ ");
#endif
              ssg_prin_id_with_suffix (ssg, asname, "_lang");
            }
          asname_printed = 1;
        }
/*                        0         1         2 */
/*                        012345678901234567890 */
      else if (CMD_EQUAL("as-name-N", 9))
        {
          if (col_idx < 0)
            spar_sqlprint_error2 ("ssg_" "print_tmpl(): can't use ^{as-name-N}^ outside a loop, should be ^{as-name}^", asname_printed);
          if (IS_BOX_POINTER (asname))
            {
              char buf[60];
              snprintf (buf, sizeof (buf), "%s~%d", asname, col_idx);
#ifdef NDEBUG
              ssg_puts (" AS ");
#else
              ssg_puts (" AS /*as-name-N*/ ");
#endif
              ssg_prin_id (ssg, buf);
              asname_printed = 1;
            }
        }
/*                        0         1         2 */
/*                        012345678901234567890 */
      else if (CMD_EQUAL("column", 6))
        {
          if (NULL == qm_val)
            spar_sqlprint_error2 ("ssg_" "print_tmpl(): can't use ^{column}^ if qm_val is NULL", asname_printed);
          if (1 != BOX_ELEMENTS (qm_val->qmvColumns))
            spar_sqlprint_error2 ("ssg_" "print_tmpl(): can't use ^{column}^ if qm_val has more than one column", asname_printed);
          if (col_idx >= 0)
            spar_sqlprint_error2 ("ssg_" "print_tmpl(): can't use ^{column}^ inside a loop, should be ^{column-N}^", asname_printed);
          ssg_prin_id (ssg, qm_val->qmvColumns[0]->qmvcColumnName);
        }
/*                        0         1         2 */
/*                        012345678901234567890 */
      else if (CMD_EQUAL("column-0", 8))
        {
          if (NULL == qm_val)
            spar_sqlprint_error2 ("ssg_" "print_tmpl(): can't use ^{column-0}^ if qm_val is NULL", asname_printed);
          ssg_prin_id (ssg, qm_val->qmvColumns[0]->qmvcColumnName);
        }
/*                        0         1         2 */
/*                        012345678901234567890 */
      else if (CMD_EQUAL("column-1", 8))
        {
          if (NULL == qm_val)
            spar_sqlprint_error2 ("ssg_" "print_tmpl(): can't use ^{column-0}^ if qm_val is NULL", asname_printed);
          ssg_prin_id (ssg, qm_val->qmvColumns[1]->qmvcColumnName);
        }
/*                        0         1         2 */
/*                        012345678901234567890 */
      else if (CMD_EQUAL("column-N", 8))
        {
          if (NULL == qm_val)
            spar_sqlprint_error2 ("ssg_" "print_tmpl(): can't use ^{column-N}^ if qm_val is NULL", asname_printed);
          if (col_idx < 0)
            spar_sqlprint_error2 ("ssg_" "print_tmpl(): can't use ^{column-N}^ outside a loop", asname_printed);
          if (col_idx >= BOX_ELEMENTS (qm_val->qmvColumns))
            spar_sqlprint_error2 ("ssg_" "print_tmpl(): col index for ^{column-N}^ exceedes number of columns", asname_printed);
          ssg_prin_id (ssg, qm_val->qmvColumns[col_idx]->qmvcColumnName);
        }
/*                        0         1         2 */
/*                        012345678901234567890 */
      else if (CMD_EQUAL("comma-cut", 9))
        ssg_puts (", ");
/*                        0         1         2 */
/*                        012345678901234567890 */
      else if (CMD_EQUAL("comma-list-begin", 16))
        {
          int colctr, colcount;
          const char *loop_end;
/*                                       0         1         2 */
/*                                       012345678901234567890 */
          loop_end = strstr (mopen_hit, "^{end}^");
          if (col_idx > 0)
            spar_sqlprint_error2 ("ssg_" "print_tmpl(): can't use ^{comma-list-begin}^ inside the loop", asname_printed);
          if (NULL == loop_end)
            spar_sqlprint_error2 ("ssg_" "print_tmpl(): ^{comma-list-begin}^ without matching ^{end}^", asname_printed);
          if (!IS_BOX_POINTER (qm_fmt))
            spar_sqlprint_error2 ("ssg_" "print_tmpl(): ^{comma-list-begin}^ with non-short format", asname_printed);
          colcount = qm_fmt->qmfColumnCount;
          if (0 == colcount)
            {
              /* spar_sqlprint_error2 ("ssg_" "print_tmpl(): ^{comma-list-begin}^ with a format that have zero columns", asname_printed); */
              asname_printed |= 1; /* No one value is printed without alias, hence all printed with alias */
            }
          else
            {
              for (colctr = 0; colctr < colcount; colctr++)
                {
                  if (0 != colctr)
                    ssg_puts (", ");
                  asname_printed |= ssg_print_tmpl_phrase (ssg, qm_fmt, tail, loop_end, alias, qm_val, tree, colctr, asname);
                }
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
                spar_sqlprint_error2 ("ssg_" "print_tmpl(): can't use ^{tree}^ if qm_fmt is NULL", asname_printed);
              if (tmpl == qm_fmt->qmfShortTmpl)
                spar_sqlprint_error2 ("ssg_" "print_tmpl(): can't use ^{tree}^ in qmfShortTmpl: infinite recursion", asname_printed);
              ssg_print_tmpl (ssg, qm_fmt, qm_fmt->qmfShortTmpl, alias, qm_val, NULL, NULL_ASNAME);
            }
          else
            ssg_print_scalar_expn (ssg, tree, SSG_VALMODE_AUTO, NULL_ASNAME);
        }
/*                        0         1         2 */
/*                        012345678901234567890 */
      else if (CMD_EQUAL("tree-0", 6))
        {
          if (NULL == tree)
            {
              if (NULL == qm_fmt)
                spar_sqlprint_error2 ("ssg_" "print_tmpl(): can't use ^{tree-0}^ if qm_fmt is NULL", asname_printed);
              if (tmpl == qm_fmt->qmfShortTmpl)
                spar_sqlprint_error2 ("ssg_" "print_tmpl(): can't use ^{tree-0}^ in qmfShortTmpl: infinite recursion", asname_printed);
              ssg_print_tmpl (ssg, qm_fmt, qm_fmt->qmfShortTmpl, alias, qm_val, NULL, COL_IDX_ASNAME + 0);
            }
          else if (IS_BOX_POINTER (qm_fmt) && (1 != qm_fmt->qmfColumnCount))
            ssg_print_scalar_expn (ssg, tree, SSG_VALMODE_AUTO, COL_IDX_ASNAME + 0);
          else
            ssg_print_scalar_expn (ssg, tree, SSG_VALMODE_AUTO, NULL_ASNAME);
        }
/*                        0         1         2 */
/*                        012345678901234567890 */
      else if (CMD_EQUAL("tree-1", 6))
        {
          if (!(IS_BOX_POINTER (qm_fmt) && (2 <= qm_fmt->qmfColumnCount)))
            spar_sqlprint_error2 ("ssg_" "print_tmpl(): can't use ^{tree-1}^ if qm_fmt is not short or have less than 2 cols", asname_printed);
          if (NULL == tree)
            {
              if (NULL == qm_fmt)
                spar_sqlprint_error2 ("ssg_" "print_tmpl(): can't use ^{tree-1}^ if qm_fmt is NULL", asname_printed);
              if (tmpl == qm_fmt->qmfShortTmpl)
                spar_sqlprint_error2 ("ssg_" "print_tmpl(): can't use ^{tree-1}^ in qmfShortTmpl: infinite recursion", asname_printed);
              ssg_print_tmpl (ssg, qm_fmt, qm_fmt->qmfShortTmpl, alias, qm_val, NULL, COL_IDX_ASNAME + 1);
            }
          else
            ssg_print_scalar_expn (ssg, tree, SSG_VALMODE_AUTO, COL_IDX_ASNAME + 1);
        }
/*                        0         1         2 */
/*                        012345678901234567890 */
      else if (CMD_EQUAL("tree-N", 6))
        {
          if (NULL == tree)
            {
              if (NULL == qm_fmt)
                spar_sqlprint_error2 ("ssg_" "print_tmpl(): can't use ^{tree-N}^ if qm_fmt is NULL", asname_printed);
              if (tmpl == qm_fmt->qmfShortTmpl)
                spar_sqlprint_error2 ("ssg_" "print_tmpl(): can't use ^{tree-N}^ in qmfShortTmpl: infinite recursion", asname_printed);
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
                spar_sqlprint_error2 ("ssg_" "print_tmpl(): can't use ^{tree-as-name}^ if qm_fmt is NULL", asname_printed);
              if (tmpl == qm_fmt->qmfShortTmpl)
                spar_sqlprint_error2 ("ssg_" "print_tmpl(): can't use ^{tree-as-name}^ in qmfShortTmpl: infinite recursion", asname_printed);
              ssg_print_tmpl (ssg, qm_fmt, qm_fmt->qmfShortTmpl, alias, qm_val, NULL, asname);
            }
          else
            ssg_print_scalar_expn (ssg, tree, SSG_VALMODE_AUTO, asname);
          asname_printed = 1;
        }
/*                        0         1         2 */
/*                        012345678901234567890 */
      else if (CMD_EQUAL("tree-dt", 7))
        {
          if (NULL == tree)
            {
              if (NULL == qm_fmt)
                spar_sqlprint_error2 ("ssg_" "print_tmpl(): can't use ^{tree-dt}^ if qm_fmt is NULL", asname_printed);
              if (tmpl == qm_fmt->qmfDatatypeOfShortTmpl)
                spar_sqlprint_error2 ("ssg_" "print_tmpl(): can't use ^{tree-dt}^ in qmfDatatypeOfShortTmpl: infinite recursion", asname_printed);
              ssg_print_tmpl (ssg, qm_fmt, qm_fmt->qmfDatatypeOfShortTmpl, alias, qm_val, NULL, asname);
            }
          else
            ssg_print_scalar_expn (ssg, tree, SSG_VALMODE_DATATYPE, asname);
        }
/*                        0         1         2 */
/*                        012345678901234567890 */
      else if (CMD_EQUAL("tree-lang", 9))
        {
          if (NULL == tree)
            {
              if (NULL == qm_fmt)
                spar_sqlprint_error2 ("ssg_" "print_tmpl(): can't use ^{tree-lang}^ if qm_fmt is NULL", asname_printed);
              if (tmpl == qm_fmt->qmfLanguageOfShortTmpl)
                spar_sqlprint_error2 ("ssg_" "print_tmpl(): can't use ^{tree-lang}^ in qmfLanguageOfShortTmpl: infinite recursion", asname_printed);
              ssg_print_tmpl (ssg, qm_fmt, qm_fmt->qmfLanguageOfShortTmpl, alias, qm_val, NULL, asname);
            }
          else
            ssg_print_scalar_expn (ssg, tree, SSG_VALMODE_LANGUAGE, asname);
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
            spar_sqlprint_error2 ("ssg_" "print_tmpl(): can't use ^{custom-string-1}^ if qm_fmt is NULL", asname_printed);
          ssg_print_box_as_sql_atom (ssg, qm_fmt->qmfCustomString1, 0);
        }
/*                         0         1         2 */
/*                         012345678901234567890 */
      else if (CMD_EQUAL ("custom-verbatim-1", 17))
        {
          if (NULL == qm_fmt)
            spar_sqlprint_error2 ("ssg_" "print_tmpl(): can't use ^{custom-verbatim-1}^ if qm_fmt is NULL", asname_printed);
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
        spar_sqlprint_error2 ("ssg_" "print_tmpl(): unsupported keyword in ^{...}^", asname_printed);
    }
  return asname_printed;
}


void ssg_print_tmpl (struct spar_sqlgen_s *ssg, qm_format_t *qm_fmt, ccaddr_t tmpl, caddr_t alias, qm_value_t *qm_val, SPART *tree, const char *asname)
{
  const char *tmpl_end;
  int asname_printed;
  if (NULL == tmpl)
    spar_internal_error (ssg->ssg_sparp, "Uninitialized template detected; it's probably due to incomplete declaration of some quad mapping data format");
#ifdef DEBUG
  if ((NULL != strstr (tmpl, "1=2")) || (NULL != strstr (tmpl, "2=1")))
    spar_internal_error (ssg->ssg_sparp, "1=2 in template to be printed");
#endif
  sparp_jso_validate_format (ssg->ssg_sparp, qm_fmt);
  tmpl_end = tmpl; while ('\0' != tmpl_end[0]) tmpl_end++;
  if (NULL == qm_val)
    {
      ptrlong tree_type = SPART_TYPE (tree);
      switch (tree_type)
        {
        case SPAR_RETVAL:
          if (NULL != tree->_.retval.triple)
            {
              quad_map_t *qm = tree->_.retval.triple->_.triple.tc_list[0]->tc_qm;
              qm_val = SPARP_FIELD_QMV_OF_QM (qm,tree->_.retval.tr_idx);
            }
        }
    }
  if ((NULL != asname) && !IS_BOX_POINTER (asname))
    {
      int col_idx = asname - COL_IDX_ASNAME, col_ctr;
      const char *tail, *cut_begin, *cut_end;
/*                               0         1         2 */
/*                               012345678901234567890 */
      cut_begin = strstr (tmpl, "-list-begin}^");
      if (NULL != cut_begin)
        {
          cut_begin += 13;
          cut_end = strstr (cut_begin, "^{end}^");
          if (NULL == cut_begin)
            spar_sqlprint_error ("ssg_print_tmpl(): list-begin}^ without ^{end}^");
          goto print_cut; /* see below */
        }
      cut_begin = tmpl;
      for (col_ctr = 0; col_ctr < col_idx; col_ctr++)
        {
/*                                        0         1         2 */
/*                                        012345678901234567890 */
          tail = strstr (cut_begin, "^{comma-cut}^");
          if (NULL == tail)
            {
              if (cut_begin == tmpl)
                spar_sqlprint_error ("ssg_print_tmpl(): no list in template for printing one part of list");
              else
                spar_sqlprint_error ("ssg_print_tmpl(): not enough comma-cuts in template");
            }
          cut_begin = tail + 13;
        }
      cut_end = strstr (cut_begin, "^{comma-cut}^");
      if (NULL == cut_end)
        cut_end = cut_begin + strlen (cut_begin);

print_cut:
      ssg_print_tmpl_phrase (ssg, qm_fmt, cut_begin, cut_end, alias, qm_val, tree, col_idx, NULL_ASNAME);
      return;
    }
  asname_printed = ssg_print_tmpl_phrase (ssg, qm_fmt, tmpl, tmpl_end, alias, qm_val, tree, -1, asname);
  if (IS_BOX_POINTER (asname) && !asname_printed)
    {
#ifdef NDEBUG
      ssg_puts (" AS ");
#else
      ssg_puts (" AS /*tmpl*/ ");
#endif
      ssg_prin_id (ssg, asname);
    }
}


void
sparp_check_tmpl (sparp_t *sparp, ccaddr_t tmpl, int qmv_known, dk_set_t *used_aliases)
{
  const char *tmpl_end = tmpl + box_length (tmpl) - 1;
  const char *tail;
  const char *cmd;
  const char *mopen_hit;
  const char *mclose_hit;
  int in_list = 0;
  int after_list = 0;
  int cmdlen;
  tail = tmpl;
  while (tail < tmpl_end)
    {
      mopen_hit = strstr (tail, "^{");
      if (mopen_hit >= tmpl_end)
        mopen_hit = NULL;
      mclose_hit = strstr (tail, "}^");
      if (mclose_hit >= tmpl_end)
        mclose_hit = NULL;
      if ((NULL == mopen_hit) && (NULL == mclose_hit))
        break;
      if (NULL == mclose_hit)
        spar_error (sparp, "Template string contains '^{' without matching '}^'");
      if ((NULL == mopen_hit) || (mclose_hit < mopen_hit))
        spar_error (sparp, "Template string contains '}^' without matching '^{'");
      cmd = mopen_hit + 2;
      cmdlen = mclose_hit - cmd;
      tail = mclose_hit + 2;
      if (0 == cmdlen)
        spar_error (sparp, "Template string contains empty macro '^{}^'");
      if ('.' == cmd [cmdlen-1])
        {
          caddr_t alias = t_box_dv_short_nchars (cmd, cmdlen - 1);
          caddr_t qtable = spar_qm_find_base_table (sparp, alias);
          if (NULL == qtable)
            spar_error (sparp, "Template string refers to unspecified alias in macro ^{%.100s.}^", alias);
          if (0 > dk_set_position_of_string (used_aliases[0], alias))
            t_set_push (used_aliases, alias);
          continue;
        }
/*                   0         1         2 */
/*                   012345678901234567890 */
      else if (CMD_EQUAL("N", 1))
        goto inloop_cmd;
/*                   0         1         2 */
/*                   012345678901234567890 */
      else if (CMD_EQUAL("N1", 2))
        goto inloop_cmd;
/*                        0         1         2 */
/*                        012345678901234567890 */
      else if (CMD_EQUAL("alias", 5))
        goto noloop_tbl_cmd;
/*                        0         1         2 */
/*                        012345678901234567890 */
      else if (CMD_EQUAL("alias-0", 7))
        goto noloop_tbl_cmd;
/*                        0         1         2 */
/*                        012345678901234567890 */
      else if (CMD_EQUAL("alias-1", 7))
        goto noloop_tbl_cmd;
/*                        0         1         2 */
/*                        012345678901234567890 */
      else if (CMD_EQUAL("alias-dot", 9))
        goto noloop_tbl_cmd;
/*                        0         1         2 */
/*                        012345678901234567890 */
      else if (CMD_EQUAL("alias-N-dot", 11))
        goto inloop_cmd;
/*                        0         1         2 */
/*                        012345678901234567890 */
      else if (CMD_EQUAL("as-name", 7))
        goto noloop_cmd;
/*                        0         1         2 */
/*                        012345678901234567890 */
      else if (CMD_EQUAL("as-name-0", 9))
        goto noloop_cmd;
/*                        0         1         2 */
/*                        012345678901234567890 */
      else if (CMD_EQUAL("as-name-1", 9))
        goto noloop_cmd;
/*                        0         1         2 */
/*                        012345678901234567890 */
      else if (CMD_EQUAL("as-name-dt", 10))
        goto noloop_cmd;
/*                        0         1         2 */
/*                        012345678901234567890 */
      else if (CMD_EQUAL("as-name-lang", 12))
        goto noloop_cmd;
/*                        0         1         2 */
/*                        012345678901234567890 */
      else if (CMD_EQUAL("as-name-N", 9))
        goto inloop_cmd;
/*                        0         1         2 */
/*                        012345678901234567890 */
      else if (CMD_EQUAL("column", 6))
        goto noloop_cmd;
/*                        0         1         2 */
/*                        012345678901234567890 */
      else if (CMD_EQUAL("column-0", 8))
        goto inloop_cmd;
/*                        0         1         2 */
/*                        012345678901234567890 */
      else if (CMD_EQUAL("column-1", 8))
        goto inloop_cmd;
/*                        0         1         2 */
/*                        012345678901234567890 */
      else if (CMD_EQUAL("column-N", 8))
        goto inloop_cmd;
/*                        0         1         2 */
/*                        012345678901234567890 */
      else if (CMD_EQUAL("comma-cut", 9))
        goto inloop_cmd;
/*                        0         1         2 */
/*                        012345678901234567890 */
      else if (CMD_EQUAL("comma-list-begin", 16))
        {
/*                                       0         1         2 */
/*                                       012345678901234567890 */
          const char *loop_end = strstr (mopen_hit, "^{end}^");
          if (NULL == loop_end)
            spar_error (sparp, "Template string contains ^{%.100s}^ without matching ^{end}^", t_box_dv_short_nchars (cmd, cmdlen));
          if (in_list)
            spar_error (sparp, "Template string contains macro ^{%.100s}^ inside a list (say, between ^{comma-list-begin}^ and ^{end}^", t_box_dv_short_nchars (cmd, cmdlen));
          if (after_list)
            spar_error (sparp, "Template string contains more than one list (like ^{%.100s}^ ... ^{end}^)", t_box_dv_short_nchars (cmd, cmdlen));
          in_list = 1;
          goto inloop_cmd;
        }
/*                        0         1         2 */
/*                        012345678901234567890 */
      else if (CMD_EQUAL("end", 3))
        {
          if (!in_list)
            spar_error (sparp, "Template string contains ^{end}^ without pair begin of a list");
          in_list = 0;
          after_list = 1;
          goto noloop_cmd;
        }
/*                        0         1         2 */
/*                        012345678901234567890 */
      else if (CMD_EQUAL("tree", 4))
        goto noloop_cmd;
/*                        0         1         2 */
/*                        012345678901234567890 */
      else if (CMD_EQUAL("tree-0", 6))
        goto inloop_cmd;
/*                        0         1         2 */
/*                        012345678901234567890 */
      else if (CMD_EQUAL("tree-1", 6))
        goto inloop_cmd;
/*                        0         1         2 */
/*                        012345678901234567890 */
      else if (CMD_EQUAL("tree-N", 6))
        goto inloop_cmd;
/*                        0         1         2 */
/*                        012345678901234567890 */
      else if (CMD_EQUAL("tree-as-name", 12))
        goto noloop_cmd;
/*                         0         1         2 */
/*                         012345678901234567890 */
      else if (CMD_EQUAL ("sqlval-of-tree", 14))
        goto noloop_cmd;
/*                         0         1         2 */
/*                         012345678901234567890 */
      else if (CMD_EQUAL ("datatype-of-tree", 16))
        goto noloop_cmd;
/*                         0         1         2 */
/*                         012345678901234567890 */
      else if (CMD_EQUAL ("language-of-tree", 16))
        goto noloop_cmd;
/*                         0         1         2 */
/*                         012345678901234567890 */
      else if (CMD_EQUAL ("custom-string-1", 15))
        goto col_cmd;
/*                         0         1         2 */
/*                         012345678901234567890 */
      else if (CMD_EQUAL ("custom-verbatim-1", 17))
        goto col_cmd;
/*                         0         1         2 */
/*                         012345678901234567890 */
      else if (CMD_EQUAL ("URIQADefaultHost", 16))
        {
          caddr_t subst;
          IN_TXN;
          subst = registry_get ("URIQADefaultHost");
          LEAVE_TXN;
          if (NULL == subst)
            spar_error (sparp, "Unable to use ^{URIQADefaultHost}^ in IRI template if DefaultHost is not specified in [URIQA] section of Virtuoso config");
        }
      else
        spar_error (sparp, "Template string contains unsupported keyword ^{%.100s}^", t_box_dv_short_nchars (cmd, cmdlen));

inloop_cmd:
      if (!in_list)
        spar_error (sparp, "Macro ^{%.100s}^ can be used only inside a list (say, between ^{comma-list-begin}^ and ^{end}^", t_box_dv_short_nchars (cmd, cmdlen));
col_cmd:
      if (!qmv_known)
        spar_error (sparp, "Macro ^{%.100s}^ can be used only in format strings, not in table conditions", t_box_dv_short_nchars (cmd, cmdlen));
      continue;

noloop_cmd:
      if (!qmv_known)
        spar_error (sparp, "Macro ^{%.100s}^ can be used only in format strings, not in table conditions", t_box_dv_short_nchars (cmd, cmdlen));
noloop_tbl_cmd:
      if (in_list)
        spar_error (sparp, "Macro ^{%.100s}^ can not be used inside a list (say, between ^{comma-list-begin}^ and ^{end}^", t_box_dv_short_nchars (cmd, cmdlen));
      continue;

    }
}
#undef CMD_EQUAL


caddr_t
sparp_patch_tmpl (sparp_t *sparp, ccaddr_t tmpl, dk_set_t alias_replacements)
{
  const char *tmpl_end = tmpl + box_length (tmpl) - 1;
  const char *tail;
  const char *cmd;
  const char *mopen_hit;
  const char *mclose_hit;
  dk_session_t *ses = strses_allocate ();
  caddr_t res, tres;
  int cmdlen;
  tail = tmpl;
  while (tail < tmpl_end)
    {
      mopen_hit = strstr (tail, "^{");
      if (mopen_hit >= tmpl_end)
        mopen_hit = NULL;
      if (NULL == mopen_hit)
        {
          SES_PRINT (ses, tail);
          break;
        }
      mclose_hit = strstr (tail, "}^");
      if (mclose_hit >= tmpl_end)
        mclose_hit = NULL;
      cmd = mopen_hit + 2;
      cmdlen = mclose_hit - cmd;
      tail = mclose_hit + 2;
      if (0 == cmdlen)
        spar_error (sparp, "Template string contains empty macro '^{}^'");
      if ('.' == cmd [cmdlen-1])
        {
          caddr_t alias = t_box_dv_short_nchars (cmd, cmdlen - 1);
          caddr_t new_alias = dk_set_get_keyword (alias_replacements, alias, NULL);
          if (NULL != new_alias)
            {
              SES_PRINT (ses, "^{");
              SES_PRINT (ses, new_alias);
              SES_PRINT (ses, ".}^");
              continue;
            }
        }
      session_buffered_write (ses, mopen_hit, tail - mopen_hit);
    }
  res = strses_string (ses);
  dk_free_box (ses);
  tres = t_box_dv_short_string (res);
  dk_free_box (res);
  return tres;
}

#ifndef spar_sqlprint_error_impl
void
spar_sqlprint_error_impl (spar_sqlgen_t *ssg, const char *msg)
  {
    ssg_putchar ('!'); ssg_puts (msg); ssg_putchar ('!');
  }
#endif

void
ssg_prin_id (spar_sqlgen_t *ssg, const char *name)
{
#ifdef DEBUG
  if (NULL != strstr (name, "CRASH"))  
    ssg_puts ("!!!CRASH!!!");
#endif
  if ('\"' == name[0])
    ssg_puts (name);
  else
    {   
      ssg_putchar ('"');
      ssg_puts (name);
      ssg_putchar ('"');
    }
}


void
ssg_prin_id_with_suffix (spar_sqlgen_t *ssg, const char *name, const char *suffix)
{
#if 0
  char tmp[1000 + 1];
  sprintf_escaped_id (t_box_sprintf ("%s%s", name, suffix), tmp, NULL);
  ssg_puts (tmp);
#else
#ifdef DEBUG
  if (NULL != strstr (name, "CRASH"))  
    ssg_puts ("!!!CRASH!!!");
#endif
  ssg_putchar ('"');
  ssg_puts (name);
  ssg_puts (suffix);
  ssg_putchar ('"');
#endif
}

ssg_valmode_t
sparp_equiv_native_valmode (sparp_t *sparp, SPART *gp, sparp_equiv_t *eq)
{
  int var_count = eq->e_var_count;
  int var_ctr;
  ssg_valmode_t largest_intersect, largest_optional_intersect, res;
  int gp_member_idx;
  if (NULL == eq)
    return NULL;
  if (SPART_VARR_FIXED & eq->e_rvr.rvrRestrictions)
    {
      return SSG_VALMODE_SQLVAL;
    }
  if (SELECT_L == gp->_.gp.subtype)
    {
      caddr_t varname = eq->e_varnames[0];
      SPART *retval = sparp_find_subexpn_in_retlist (sparp, varname, gp->_.gp.subquery->_.req_top.orig_retvals, 1);
      if (NULL != retval)
        return sparp_expn_native_valmode (sparp, retval);
      if (NULL != gp->_.gp.options)
        {
          int ctr;
          for (ctr = BOX_ELEMENTS (gp->_.gp.options); 1 < ctr; ctr -= 2)
            {
              SPART *val = gp->_.gp.options[ctr-1];
              if (T_STEP_L == ((ptrlong)(gp->_.gp.options[ctr-2])) && !strcmp (val->_.alias.aname, varname))
                {
                  SPART *expn = val->_.alias.arg;
                  if (SSG_VALMODE_AUTO != val->_.alias.native)
                    return val->_.alias.native;
                  if (SPAR_VARIABLE == SPART_TYPE (expn))
                    {
                      retval = sparp_find_subexpn_in_retlist (sparp, expn->_.var.vname, gp->_.gp.subquery->_.req_top.orig_retvals, 1);
                      if (NULL == retval)
                        spar_internal_error (sparp, "sparp_" "equiv_native_valmode(): no retval for T_STEP variable");
                      val->_.alias.native = sparp_expn_native_valmode (sparp, retval);
                      return val->_.alias.native;
                    }
                  else
                    return SSG_VALMODE_SQLVAL;
                }
            }
        }
      return SSG_VALMODE_LONG;
    }
  if (UNION_L == gp->_.gp.subtype)
    {
      ssg_valmode_t smallest_union = SSG_VALMODE_AUTO;
      int var_miss_in_some_members = 0;
      int all_cases_make_only_refs = 1;
      DO_BOX_FAST (SPART *, gp_member, gp_member_idx, gp->_.gp.members)
        {
          sparp_equiv_t *member_eq;
          ssg_valmode_t member_valmode;
          if (SPAR_GP != SPART_TYPE (gp_member))
            continue;
          member_eq = sparp_equiv_get_subvalue_ro (sparp->sparp_equivs, sparp->sparp_equiv_count, gp_member, eq);
          if (NULL == member_eq)
            {
              var_miss_in_some_members = 1;
              continue;
            }
          if ((SPART_VARR_FIXED & member_eq->e_rvr.rvrRestrictions) &&
            (SPART_VARR_NOT_NULL & member_eq->e_rvr.rvrRestrictions) &&
            (SPART_VARR_IS_REF & member_eq->e_rvr.rvrRestrictions) )
            {
              quad_map_t *dflt_qm = sparp->sparp_storage ? sparp->sparp_storage->qsDefaultMap : NULL;
              member_valmode = qm_format_default_iri_ref;
              if ((NULL != dflt_qm) && (NULL != dflt_qm->qmSubjectMap))
                member_valmode = dflt_qm->qmSubjectMap->qmvFormat;
            }
          else
            {
              member_valmode = sparp_equiv_native_valmode (sparp, gp_member, member_eq);
              if (all_cases_make_only_refs && !(SPART_VARR_IS_REF & member_eq->e_rvr.rvrRestrictions))
                all_cases_make_only_refs = 0;
            }
          if (NULL == member_valmode)
            continue;
          smallest_union = ssg_smallest_union_valmode (smallest_union, member_valmode);
        }
      END_DO_BOX_FAST;
#ifdef DEBUG
      if (0 != var_count)
        spar_internal_error (sparp, "sparp_" "equiv_native_valmode(): union should not contain local variables");
#endif
      if (var_miss_in_some_members &&
        IS_BOX_POINTER (smallest_union) )
        { /* Missing variable in union will be printed as single NULL so... */
          if (1 != smallest_union->qmfColumnCount)
            smallest_union = SSG_VALMODE_LONG; /* ... non-missing multi-column format is not appropriate */
          else if (SPART_VARR_NOT_NULL & smallest_union->qmfValRange.rvrRestrictions)
            smallest_union = ssg_find_nullable_superformat (smallest_union); /* ... format that does not support NULLs is not appropriate, too */
        }
      if (all_cases_make_only_refs && (SSG_VALMODE_LONG == smallest_union))
        smallest_union = SSG_VALMODE_SQLVAL;
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
      triple = sparp_find_triple_of_var_or_retval (sparp, gp, var, 1);
#ifdef DEBUG
      if (SPAR_TRIPLE != SPART_TYPE (triple))
        spar_internal_error (sparp, "sparp_" "equiv_native_valmode(): bad tabid of a variable");
#endif
      tr_idx = var->_.var.tr_idx;
      if (SPART_TRIPLE_FIELDS_COUNT <= tr_idx)
        tr_valmode = SSG_VALMODE_SQLVAL;
      else
        {
#ifdef DEBUG
          if (NULL == triple->_.triple.tc_list)
            spar_internal_error (sparp, "sparp_" "equiv_native_valmode(): NULL == qm_list");
#endif
          tr_valmode = triple->_.triple.native_formats[tr_idx];
          sparp_jso_validate_format (sparp, tr_valmode);
        }
      largest_intersect = ssg_largest_intersect_valmode (largest_intersect, tr_valmode);
    }
  DO_BOX_FAST (SPART *, gp_member, gp_member_idx, gp->_.gp.members)
    {
      sparp_equiv_t *member_eq;
      ssg_valmode_t member_valmode;
      if (SPAR_GP != SPART_TYPE (gp_member))
        continue;
      member_eq = sparp_equiv_get_subvalue_ro (sparp->sparp_equivs, sparp->sparp_equiv_count, gp_member, eq);
      if (NULL == member_eq)
        continue;
      member_valmode = sparp_equiv_native_valmode (sparp, gp_member, member_eq);
      if (member_eq->e_rvr.rvrRestrictions & SPART_VARR_NOT_NULL)
        largest_intersect = ssg_largest_intersect_valmode (largest_intersect, member_valmode);
      else if (SSG_VALMODE_AUTO == largest_intersect)
        largest_optional_intersect = ssg_largest_intersect_valmode (largest_optional_intersect, member_valmode);
    }
  END_DO_BOX_FAST;
  if (SSG_VALMODE_AUTO != largest_intersect)
    res = largest_intersect;
  else
    res = largest_optional_intersect;
  if (!(eq->e_rvr.rvrRestrictions & SPART_VARR_NOT_NULL) && IS_BOX_POINTER (res) && (res->qmfValRange.rvrRestrictions & SPART_VARR_NOT_NULL))
    res = ssg_find_nullable_superformat (res);
  return res;
}

ssg_valmode_t
sparp_expn_native_valmode (sparp_t *sparp, SPART *tree)
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
    case SPAR_ALIAS:
      if (SSG_VALMODE_AUTO == tree->_.alias.native)
        tree->_.alias.native = sparp_expn_native_valmode (sparp, tree->_.alias.arg);
      return tree->_.alias.native;
    case SPAR_BUILT_IN_CALL:
      switch (tree->_.builtin.btype)
        {
        case IN_L: case LIKE_L: case LANGMATCHES_L: case REGEX_L: case BOUND_L:
	case isIRI_L: case isURI_L: case isBLANK_L: case isLITERAL_L: return SSG_VALMODE_BOOL;
        case IRI_L: case DATATYPE_L: return SSG_VALMODE_LONG;
        default: return SSG_VALMODE_SQLVAL;
        }
    case SPAR_FUNCALL:
      return sparp_rettype_of_function (sparp, tree->_.funcall.qname);
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
        return sparp_rettype_of_global_param (sparp, tree->_.var.vname);
      else if (SPART_VARR_EXTERNAL & tree->_.var.rvr.rvrRestrictions)
        {
          SPART *orig = sparp_find_origin_of_external_var (sparp, tree);
          return sparp_expn_native_valmode (sparp, orig);
        }
      else if (NULL != tree->_.var.tabid)
        {
          SPART *triple;
          int tr_idx;
          ssg_valmode_t tr_valmode;
          triple = sparp_find_triple_of_var_or_retval (sparp, NULL, tree, 1);
#ifdef DEBUG
          if (SPAR_TRIPLE != SPART_TYPE (triple))
            spar_internal_error (sparp, "sparp_" "expn_native_valmode(): bad tabid of a variable");
#endif
          tr_idx = tree->_.var.tr_idx;
          if (SPART_TRIPLE_FIELDS_COUNT <= tr_idx)
            return SSG_VALMODE_SQLVAL;
#ifdef DEBUG
          if (NULL == triple->_.triple.tc_list)
            spar_internal_error (sparp, "sparp_" "expn_native_valmode(): NULL == qm_list");
#endif
          tr_valmode = triple->_.triple.native_formats[tr_idx];
          sparp_jso_validate_format (sparp, tr_valmode);
          return tr_valmode;
        }
      else
        {
          ptrlong eq_idx = tree->_.var.equiv_idx;
          sparp_equiv_t *eq = sparp->sparp_equivs[eq_idx];
          SPART *gp = sparp_find_gp_by_eq_idx (sparp, eq_idx);
          return sparp_equiv_native_valmode (sparp, gp, eq);
        }
    case SPAR_RETVAL:
      if (NULL == tree->_.retval.vname)
        {
          if (NULL == tree->_.retval.tabid)
            spar_internal_error (sparp, "sparp_" "expn_native_valmode(): null vname and null tabid");
        }
      else
        {
          if (SPART_VARNAME_IS_GLOB (tree->_.retval.vname))
            return sparp_rettype_of_global_param (sparp, tree->_.retval.vname);
        }
      if (NULL != tree->_.retval.tabid)
        {
          int tr_idx = tree->_.retval.tr_idx;
          SPART *triple = tree->_.retval.triple;
          ssg_valmode_t tr_valmode;
          if (SPAR_TRIPLE != SPART_TYPE (triple))
            spar_internal_error (sparp, "sparp_" "expn_native_valmode(): bad triple of a retval");
          if (SPART_TRIPLE_FIELDS_COUNT <= tr_idx)
            return SSG_VALMODE_SQLVAL;
          if (1 != BOX_ELEMENTS_0 (triple->_.triple.tc_list))
            spar_internal_error (sparp, "sparp_" "expn_native_valmode(): lengths of triple->_.triple.qm_list differs from 1");
          tr_valmode = triple->_.triple.native_formats[tr_idx];
          sparp_jso_validate_format (sparp, tr_valmode);
          if (SSG_VALMODE_AUTO == tr_valmode)
            {
              ptrlong rvr = sparp_restr_bits_of_expn (sparp, triple->_.triple.tr_fields[tr_idx]);
              if ((rvr & SPART_VARR_IS_REF) || ((rvr & (SPART_VARR_IS_LIT | SPART_VARR_LONG_EQ_SQL)) == (SPART_VARR_IS_LIT | SPART_VARR_LONG_EQ_SQL)))
                return SSG_VALMODE_SQLVAL;
              return SSG_VALMODE_LONG;
            }
          return tr_valmode;
        }
      else
        {
          SPART *gp = tree->_.retval.gp;
          sparp_equiv_t *eq;
          ssg_valmode_t eq_valmode;
          if (NULL == gp)
            gp = sparp_find_gp_by_alias (sparp, tree->_.retval.selid);
          eq = sparp_equiv_get_ro (
            sparp->sparp_equivs, sparp->sparp_equiv_count, gp, tree,
            SPARP_EQUIV_GET_NAMESAKES | SPARP_EQUIV_GET_ASSERT );
          eq_valmode = sparp_equiv_native_valmode (sparp, gp, eq);
          return eq_valmode;
        }
    case SPAR_GP:
      {
        sparp_t *sub_sparp;
        SPART *subq = tree->_.gp.subquery;
        ssg_valmode_t res;
        if (SELECT_L != tree->_.gp.subtype)
          break;
        if (1 != BOX_ELEMENTS (subq->_.req_top.retvals))
          break;
        sub_sparp = (sparp_t *)t_box_copy ((caddr_t)sparp);
        sub_sparp->sparp_expr = subq;
        sub_sparp->sparp_env = subq->_.req_top.shared_spare;
        sub_sparp->sparp_parent_sparp = sparp;
        res = sparp_expn_native_valmode (sub_sparp, subq->_.req_top.retvals[0]);
        return res;
      }
    default: break;
    }
  spar_internal_error (sparp, "sparp_" "expn_native_valmode(): unsupported case");
  return NULL; /* Never reached, to keep compiler happy */
}

static void
sparp_set_valmodes_of_t_inouts (sparp_t *sparp, sparp_t *sub_sparp, SPART *wrapping_gp)
{
  SPART **t_in_vars, **t_out_vars, **retvals;
  int v_ctr;
  if (NULL == sparp_get_option (sparp, wrapping_gp->_.gp.options, TRANSITIVE_L))
    return;
  t_in_vars = sparp_get_option (sparp, wrapping_gp->_.gp.options, T_IN_L)->_.list.items;
  t_out_vars = sparp_get_option (sparp, wrapping_gp->_.gp.options, T_OUT_L)->_.list.items;
  retvals = wrapping_gp->_.gp.subquery->_.req_top.orig_retvals;
  for (v_ctr = BOX_ELEMENTS_0 (t_in_vars); v_ctr--; /*no step*/)
    {
      caddr_t in_vname, out_vname;
      SPART *in_alias, *out_alias;
      ssg_valmode_t in_vmode, out_vmode, mixed_vmode;
      in_vname = t_in_vars [v_ctr]->_.var.vname;
      out_vname = t_out_vars [v_ctr]->_.var.vname;
      in_alias = sparp_find_subexpn_in_retlist (sparp, in_vname, retvals, 1);
      out_alias = sparp_find_subexpn_in_retlist (sparp, out_vname, retvals, 1);
      in_vmode = sparp_expn_native_valmode (sub_sparp, in_alias);
      out_vmode = sparp_expn_native_valmode (sub_sparp, out_alias);
      if (!IS_BOX_POINTER (in_vmode))
        spar_error (sparp, "Variable ?%.100s in T_IN list is not a value from some triple", in_vname);
      if (!in_vmode->qmfIsBijection)
        spar_error (sparp, "Variable ?%.100s in T_IN list is not made by bijection", in_vname);
      if (1 != in_vmode->qmfColumnCount)
        spar_error (sparp, "Variable ?%.100s in T_IN list is made from %d database columns, should be made from exactly one", in_vname);
      if (!IS_BOX_POINTER (out_vmode))
        spar_error (sparp, "Variable ?%.100s in T_IN list is not a value from some triple", out_vname);
      if (!out_vmode->qmfIsBijection)
        spar_error (sparp, "Variable ?%.100s in T_IN list is not made by bijection", out_vname);
      if (1 != out_vmode->qmfColumnCount)
        spar_error (sparp, "Variable ?%.100s in T_IN list is made from %d database columns, should be made from exactly one", out_vname);
      mixed_vmode = ssg_smallest_union_valmode (in_vmode, out_vmode);
      if (!IS_BOX_POINTER (mixed_vmode))
        spar_error (sparp, "Variable ?%.100s in T_IN list and corresponding variable ?%.100s in T_OUT get values from columns that are too different", in_vmode, out_vname);
      in_alias->_.alias.native = out_alias->_.alias.native = mixed_vmode;
    }
}

ptrlong sparp_restr_bits_of_dtp (dtp_t dtp)
{
  switch (dtp)
    {
      case DV_ANY:
        return 0;
      case DV_DB_NULL:
        return SPART_VARR_ALWAYS_NULL;
      case DV_IRI_ID:
        return SPART_VARR_IS_REF | SPART_VARR_NOT_NULL;
      case DV_LONG_INT: case DV_DATETIME: case DV_DATE: case DV_TIME:
      case DV_SINGLE_FLOAT: case DV_DOUBLE_FLOAT: case DV_NUMERIC:
       return SPART_VARR_IS_LIT | SPART_VARR_LONG_EQ_SQL | SPART_VARR_NOT_NULL;
      default: return SPART_VARR_IS_LIT | SPART_VARR_NOT_NULL;
    }
}

ptrlong
sparp_restr_bits_of_expn (sparp_t *sparp, SPART *tree)
{
  switch (SPART_TYPE (tree))
    {
    case BOP_NOT:
      return 
        (SPART_VARR_IS_LIT | SPART_VARR_LONG_EQ_SQL |
          (sparp_restr_bits_of_expn (sparp, tree->_.bin_exp.left) &
           SPART_VARR_NOT_NULL ) );
    case BOP_EQ: case BOP_NEQ: case BOP_LT: case BOP_LTE: case BOP_GT: case BOP_GTE:
    /*case BOP_LIKE: Like is built-in in SPARQL, not a BOP! */
    case BOP_SAME: case BOP_NSAME:
    case BOP_AND: case BOP_OR:
    case BOP_PLUS: case BOP_MINUS: case BOP_TIMES: case BOP_DIV: case BOP_MOD:
      return 
        (SPART_VARR_IS_LIT | SPART_VARR_LONG_EQ_SQL |
          (sparp_restr_bits_of_expn (sparp, tree->_.bin_exp.left) &
           sparp_restr_bits_of_expn (sparp, tree->_.bin_exp.right) &
           SPART_VARR_NOT_NULL ) );
    case SPAR_LIT:
      return sparp_restr_bits_of_dtp ((DV_ARRAY_OF_POINTER == DV_TYPE_OF (tree)) ? DV_TYPE_OF (tree->_.lit.val) : DV_TYPE_OF (tree));
    case SPAR_QNAME:
    /*case SPAR_QNAME_NS:*/
      return SPART_VARR_IS_REF | SPART_VARR_IS_IRI | SPART_VARR_NOT_NULL ;
    case SPAR_ALIAS:
      return sparp_restr_bits_of_expn (sparp, tree->_.alias.arg);
    case SPAR_BUILT_IN_CALL:
      switch (tree->_.builtin.btype)
        {
        case IN_L: case LIKE_L: case LANGMATCHES_L: case REGEX_L:
        case isIRI_L: case isURI_L: case isBLANK_L: case isLITERAL_L: case BOUND_L:
          return SPART_VARR_IS_LIT | SPART_VARR_NOT_NULL | SPART_VARR_LONG_EQ_SQL;
        case IRI_L: return SPART_VARR_IS_REF ;
        case DATATYPE_L: return SPART_VARR_IS_REF | SPART_VARR_IS_IRI ;
        default: return 0;
        }
    case SPAR_FUNCALL:
      {
        caddr_t qname = tree->_.funcall.qname;
        if ((!strcmp (qname, "bif:MAX") || !strcmp (qname, "bif:MIN") || !strcmp (qname, "SPECIAL::bif:MAX")) &&
          (1 == BOX_ELEMENTS (tree->_.funcall.argtrees)) )
          return sparp_restr_bits_of_expn (sparp, tree->_.funcall.argtrees[0]) & ~SPART_VARR_NOT_NULL;
        if (!strcmp (qname, "bif:AVG") && (1 == BOX_ELEMENTS (tree->_.funcall.argtrees)))
          return (SPART_VARR_IS_LIT | SPART_VARR_LONG_EQ_SQL |
            (sparp_restr_bits_of_expn (sparp, tree->_.funcall.argtrees[0]) & ~SPART_VARR_NOT_NULL) );
        if (!strcmp (qname, "bif:COUNT"))
          return (SPART_VARR_IS_LIT | SPART_VARR_LONG_EQ_SQL | SPART_VARR_NOT_NULL);
        if (!strncmp (qname, "bif:", 4))
          {
            caddr_t iduqname = sqlp_box_id_upcase (qname+4);
            bif_type_t ** bt = (bif_type_t **) id_hash_get (name_to_bif_type, (char *) &iduqname);
            if (NULL == bt)
              return 0;
            return sparp_restr_bits_of_dtp (bt[0]->bt_dtp) & ~SPART_VARR_NOT_NULL;
          }
        return 0; /* !!! TBD better output */
      }
    case SPAR_CONV:
      return sparp_restr_bits_of_expn (sparp, tree->_.conv.arg);
    case SPAR_VARIABLE: case SPAR_BLANK_NODE_LABEL:
      return tree->_.var.rvr.rvrRestrictions;
    case SPAR_RETVAL:
      if (NULL == tree->_.retval.vname)
        return 0;
      else
        {
          if (SPART_VARNAME_IS_GLOB (tree->_.retval.vname))
            return 0;
        }
      if (NULL != tree->_.retval.tabid)
        {
          int tr_idx = tree->_.retval.tr_idx;
          SPART *triple = tree->_.retval.triple;
          ssg_valmode_t tr_valmode;
          if (SPAR_TRIPLE != SPART_TYPE (triple))
            spar_internal_error (sparp, "sparp_" "restr_bits_of_expn(): bad triple of a retval");
          if (SPART_TRIPLE_FIELDS_COUNT <= tr_idx)
            return SPART_VARR_IS_LIT;
          if (1 != BOX_ELEMENTS_0 (triple->_.triple.tc_list))
            spar_internal_error (sparp, "sparp_" "restr_bits_of_expn(): lengths of triple->_.triple.qm_list differs from 1");
          tr_valmode = triple->_.triple.native_formats[tr_idx];
          sparp_jso_validate_format (sparp, tr_valmode);
          if (IS_BOX_POINTER (tr_idx))
            return tr_valmode->qmfValRange.rvrRestrictions;
          return 0;
        }
      else
        {
          SPART *gp = tree->_.retval.gp;
          sparp_equiv_t *eq;
          if (NULL == gp)
            gp = sparp_find_gp_by_alias (sparp, tree->_.retval.selid);
          eq = sparp_equiv_get_ro (
            sparp->sparp_equivs, sparp->sparp_equiv_count, gp, tree,
            SPARP_EQUIV_GET_NAMESAKES | SPARP_EQUIV_GET_ASSERT );
          return eq->e_rvr.rvrRestrictions;
        }
    case SPAR_GP:
      if (tree->_.gp.subtype != SELECT_L)
        spar_internal_error (sparp, "sparp_" "restr_bits_of_expn(): unsupported subtype of GP tree");
      return sparp_restr_bits_of_expn (sparp, tree->_.gp.subquery->_.req_top.retvals[0]);
    default: spar_internal_error (sparp, "sparp_" "restr_bits_of_expn(): unsupported case");
    }
  return 0; /* Never reached, to keep compiler happy */
}

#define SPAR_FUNCALL_ARG_IS_LONG(arg) ( \
  (SPAR_QM_SQL_FUNCALL == SPART_TYPE (arg)) || \
  (SPAR_FUNCALL == SPART_TYPE (arg)) || \
  (((DV_STRING == DV_TYPE_OF (arg)) || (DV_UNAME == DV_TYPE_OF (arg))) && \
    (40 < box_length (arg)) ) )

void
ssg_print_box_as_sql_atom (spar_sqlgen_t *ssg, ccaddr_t box, int allow_uname)
{
  char smallbuf[MAX_QUAL_NAME_LEN + 100 + BOX_AUTO_OVERHEAD];
  size_t buflen;
  caddr_t tmpbuf;
  int buffill = 0;
  dtp_t dtp = DV_TYPE_OF (box);
  buflen = 20 + (IS_BOX_POINTER(box) ? box_length (box) * 5 : 25);
  BOX_AUTO (tmpbuf, smallbuf, buflen, DV_STRING);
  ssg_putchar (' ');
  switch (dtp)
    {
    case DV_LONG_INT:
      buffill = sprintf (tmpbuf, BOXINT_FMT, unbox (box));
      break;
    case DV_DB_NULL:
      strcpy (tmpbuf, "NULL"); buffill = 4;
      break;
    case DV_STRING:
      sqlc_string_virtuoso_literal (tmpbuf, buflen, &buffill, box);
      break;
    case DV_UNAME:
      if (allow_uname)
        {
          ssg_puts ("UNAME");
          sqlc_string_virtuoso_literal (tmpbuf, buflen, &buffill, box);
        }
      else
        {
          caddr_t strg = box_utf8_string_as_narrow (box, NULL, 0, default_charset);
	  if (strg)
	    sqlc_string_virtuoso_literal (tmpbuf, buflen, &buffill, strg);
	  else
	    spar_error (ssg->ssg_sparp, "A literal contains bad UTF-8 sequence.");
          dk_free_box (strg);
        }
      break;
    case DV_WIDE:
      ssg_puts ("N");
      sqlc_wide_string_literal (tmpbuf, buflen, &buffill, (wchar_t *) box);
      break;
    case DV_SINGLE_FLOAT:
      if (1.0 > ((2 - 1.41484755040568800000e+16) + 1.41484755040568800000e+16))
        spar_error (ssg->ssg_sparp, "Platform-specific error: this build of Virtuoso does not supports literals of type %s due to rounding errors in math functions", dv_type_title (dtp));
      buffill = sprintf (tmpbuf, "cast (%lg", (double)(unbox_float (box)));
      if ((NULL == strchr (tmpbuf, '.')) && (NULL == strchr (tmpbuf, 'E')) && (NULL == strchr (tmpbuf, 'e')))
        {
          strcpy (tmpbuf+buffill, ".0");
          buffill += 2;
        }
      strcpy (tmpbuf+buffill, " as float)");
      buffill += 10;
      break;
    case DV_DOUBLE_FLOAT:
      buffill = sprintf (tmpbuf, "%lg", unbox_double (box));
      if ((NULL == strchr (tmpbuf, '.')) && (NULL == strchr (tmpbuf, 'E')) && (NULL == strchr (tmpbuf, 'e')))
        {
          strcpy (tmpbuf+buffill, ".0");
          buffill += 2;
        }
      break;
    case DV_NUMERIC:
      {
        numeric_t nbox = (numeric_t)box;
        numeric_to_string (nbox, tmpbuf, buflen);
        buffill = strlen (tmpbuf);
        if (/*(10 > numeric_raw_precision (nbox)) && (0 == numeric_scale (nbox)) &&*/ (NULL == strchr (tmpbuf, '.')))
          {
            strcpy (tmpbuf+buffill, ".0");
            buffill += 2;
          }
        break;
      }
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
      {
        const char *as_strg;
        switch (DT_DT_TYPE (box))
          {
          case DT_TYPE_DATE: as_strg = "' AS DATE)"; break;
          case DT_TYPE_TIME: as_strg = "' AS TIME)"; break;
          default: as_strg = "' AS DATETIME)"; break;
          }
        ssg_puts ("CAST ('");
        dt_to_string (box, tmpbuf, buflen);
        ssg_puts (tmpbuf);
        ssg_puts (as_strg);
        break;
      }
    default:
      spar_error (ssg->ssg_sparp, "Current implementation of SPARQL does not supports literals of type %s", dv_type_title (dtp));
      }
  session_buffered_write (ssg->ssg_out, tmpbuf, buffill);
  BOX_DONE (tmpbuf, smallbuf);
}

void
ssg_print_literal_as_sql_atom (spar_sqlgen_t *ssg, ccaddr_t type, SPART *lit)
{
  caddr_t value;
  caddr_t dt = NULL;
  caddr_t lang = NULL;
  if (DV_ARRAY_OF_POINTER == DV_TYPE_OF (lit))
    {
      if (SPAR_LIT == lit->type)
        {
          value = lit->_.lit.val;
          dt = lit->_.lit.datatype;
          lang = lit->_.lit.language;
        }
      else if ((SPAR_QNAME == lit->type)/* || (SPAR_QNAME_NS == lit->type)*/)
        {
          value = lit->_.lit.val;
#ifdef NDEBUG
          ssg_puts (" __bft(");
#else
          ssg_puts (" /* QNAME as sql atom */ __box_flags_tweak (");
#endif
          ssg_print_box_as_sql_atom (ssg, value, 0);
          ssg_puts (", 1)");
          return;
        }
      else
        {
          spar_sqlprint_error ("ssg_" "print_literal_as_sql_atom (): non-lit tree as argument");
          value = BADBEEF_BOX; /* To keep gcc 4.0 happy */
        }
    }
  else
    value = (caddr_t)lit;
  if (NULL == type)
    type = dt;
  if (uname_xmlschema_ns_uri_hash_boolean == type)
    {
      if (unbox (value))
        ssg_puts (" 1");
      else
        ssg_puts (" 0");
      return;
    }
  ssg_print_box_as_sql_atom (ssg, value, 0);
}

void
ssg_print_literal_as_sqlval (spar_sqlgen_t *ssg, ccaddr_t type, SPART *lit)
{
  caddr_t value;
  caddr_t dt = NULL;
  caddr_t lang = NULL;
  dtp_t lit_dtp = DV_TYPE_OF (lit);
  if (DV_ARRAY_OF_POINTER == lit_dtp)
    {
      if (SPAR_LIT == lit->type)
        {
          value = lit->_.lit.val;
          dt = lit->_.lit.datatype;
          lang = lit->_.lit.language;
        }
      else if ((SPAR_QNAME == lit->type)/* || (SPAR_QNAME_NS == lit->type)*/)
        {
          value = lit->_.lit.val;
#ifdef NDEBUG
          ssg_puts (" __bft(");
#else
          ssg_puts (" /* QName as sqlval */ __box_flags_tweak (");
#endif
          ssg_print_box_as_sql_atom (ssg, value, 0);
          ssg_puts (", 1)");
          return;
        }
      else
        {
          spar_sqlprint_error ("ssg_" "print_literal_as_sqlval (): non-lit tree as argument");
          value = BADBEEF_BOX; /* To keep gcc 4.0 happy */
        }
    }
  else if (DV_UNAME == lit_dtp)
    {
#ifdef NDEBUG
      ssg_puts (" __bft(");
#else
      ssg_puts (" /* UNAME as sqlval */ __box_flags_tweak (");
#endif
      ssg_print_box_as_sql_atom (ssg, (ccaddr_t)(lit), 0);
      ssg_puts (", 1)");
      return;
    }
  else
    value = (caddr_t)lit;
  if (NULL == type)
    type = dt;
#if 0
  if (uname_xmlschema_ns_uri_hash_boolean == type)
    {
      if (unbox (value))
        ssg_puts ("1");
      else
        ssg_puts ("0");
      return;
    }
#else
  if ((NULL != type) || (NULL != lang))
    {
      if (((NULL == lang) && (
          ((uname_xmlschema_ns_uri_hash_string == type) && (DV_STRING == DV_TYPE_OF (value))) ||
          ((uname_xmlschema_ns_uri_hash_integer == type) && (DV_LONG_INT == DV_TYPE_OF (value))) ||
          ((uname_xmlschema_ns_uri_hash_double == type) && (DV_DOUBLE_FLOAT == DV_TYPE_OF (value))) ) ) ||
        ((NULL != lang) && (NULL == type) && (DV_STRING == DV_TYPE_OF (value))) )
        {
          ssg_print_box_as_sql_atom (ssg, value, 0);
          return;
        }
#ifdef NDEBUG
      ssg_puts (" __ro2sq(DB.DBA.RDF_MAKE_LONG_OF_TYPEDSQLVAL_STRINGS(");
#else
      ssg_puts (" /* sqlval of typed literal */ __rdf_sqlval_of_obj (DB.DBA.RDF_MAKE_LONG_OF_TYPEDSQLVAL_STRINGS (");
#endif
      ssg_print_box_as_sql_atom (ssg, value, 0);
      ssg_putchar (',');
      if (NULL != type)
        ssg_print_box_as_sql_atom (ssg, type, 1);
      else
        ssg_puts (" NULL");
      ssg_putchar (',');
      if (NULL != lang)
        ssg_print_box_as_sql_atom (ssg, lang, 0);
      else
        ssg_puts (" NULL");
      ssg_puts ("))");
      return;
    }
#endif
  ssg_print_box_as_sql_atom (ssg, value, 0);
}

void
ssg_print_literal_as_long (spar_sqlgen_t *ssg, SPART *lit)
{
  caddr_t value = NULL;
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
          ssg_print_box_as_sql_atom (ssg, lit->_.lit.val, 1);
          ssg_putchar (')');
          return;
        }
      else
        spar_sqlprint_error ("ssg_print_literal_as_long(): non-lit tree as argument");   
    }
  else
    value = (caddr_t)lit;
  value_dtp = DV_TYPE_OF (value);
  if ((NULL != datatype) || (NULL != language))
    {
      ssg_puts (" DB.DBA.RDF_MAKE_LONG_OF_TYPEDSQLVAL_STRINGS (");
      ssg_print_box_as_sql_atom (ssg, value, 0);
      ssg_putchar (',');
      if (NULL != datatype)
        ssg_print_box_as_sql_atom (ssg, datatype, 1);
      else
        ssg_puts (" NULL");
      ssg_putchar (',');
      if (NULL != language)
        ssg_print_box_as_sql_atom (ssg, language, 0);
      else
        ssg_puts (" NULL");
      ssg_putchar (')');
      return;
    }
  if ((DV_STRING == value_dtp) || (DV_WIDE == value_dtp) ||
    (DV_BLOB_HANDLE == value_dtp) || (DV_UNAME == value_dtp) ||
    (DV_XML_ENTITY == value_dtp) )
    {
      ssg_puts (" DB.DBA.RDF_MAKE_LONG_OF_SQLVAL (");
      ssg_print_literal_as_sqlval (ssg, NULL, (SPART *)value);
      ssg_putchar (')');
      return;
    }
  ssg_print_box_as_sql_atom (ssg, value, 0);
}

void
ssg_print_equiv (spar_sqlgen_t *ssg, caddr_t selectid, sparp_equiv_t *eq, ccaddr_t asname)
{
  caddr_t name_as_expn = NULL;
  if (SPARP_EQ_IS_FIXED_AND_NOT_NULL (eq))
    ssg_print_literal_as_sqlval (ssg, NULL, (SPART *)(eq->e_rvr.rvrFixedValue));
  else
    {
      if (NULL != selectid)
        {
          ssg_putchar (' ');
          ssg_prin_id (ssg, selectid);
          ssg_putchar ('.');
        }
      name_as_expn = eq->e_varnames[0];
      ssg_putchar (' ');
      ssg_prin_id (ssg, name_as_expn);
    }
  if (IS_BOX_POINTER (asname) &&
    ((NULL == name_as_expn) || strcmp (asname, name_as_expn)) )
    {
#ifdef NDEBUG
      ssg_puts (" AS ");
#else
      ssg_puts (" AS /*equiv*/ ");
#endif
      ssg_prin_id (ssg, asname);
    }
}

/*static const char *field_names[] = {"G", "S", "P", "O"}; -- unusable when mapping is implemented, cols may have any names */

void
ssg_print_tr_field_expn (spar_sqlgen_t *ssg, qm_value_t *field, caddr_t tabid, ssg_valmode_t needed, const char *asname)
{
  ccaddr_t tmpl = NULL;
  ssg_valmode_t field_format = field->qmvFormat;
  if (NULL == tabid)
    spar_sqlprint_error ("ssg_" "print_tr_field_expn(): no tabid");
  if (IS_BOX_POINTER (needed))
    {
      if (ssg_valmode_is_subformat_of (field_format, needed))
        tmpl = field_format->qmfShortTmpl;
      else
        {
          spar_sqlprint_error ("ssg_" "print_tr_field_expn(): unsupported custom needed");
        }
    }
  else
    {
      if (SSG_VALMODE_LONG == needed)
        tmpl = field_format->qmfLongTmpl;
      else if (SSG_VALMODE_SQLVAL == needed)
        tmpl = field_format->qmfSqlvalTmpl;
      else if (SSG_VALMODE_DATATYPE == needed)
        tmpl = (field_format->qmfDatatypeTmpl ? field_format->qmfDatatypeTmpl : field_format->qmfDatatypeOfShortTmpl) ;
      else if (SSG_VALMODE_LANGUAGE == needed)
        tmpl = (field_format->qmfLanguageTmpl ? field_format->qmfLanguageTmpl : field_format->qmfLanguageOfShortTmpl) ;
      else if (SSG_VALMODE_BOOL == needed)
        tmpl = field_format->qmfBoolTmpl;
      else if (SSG_VALMODE_AUTO == needed)
        tmpl = field_format->qmfShortTmpl;
      else
        spar_sqlprint_error ("ssg_" "print_tr_field_expn(): unsupported special needed");
    }
  ssg_print_tmpl (ssg, field_format, tmpl, tabid, field, NULL, asname);
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
      triple = rv->_.retval.triple = sparp_find_triple_of_var_or_retval (ssg->ssg_sparp, NULL, var, 1);
    }
  native = sparp_expn_native_valmode (ssg->ssg_sparp, rv);
  if (IS_BOX_POINTER (native) && native->qmfValRange.rvrRestrictions & SPART_VARR_NOT_NULL &&
    !(var->_.var.rvr.rvrRestrictions & SPART_VARR_NOT_NULL) )
    {
      ssg_valmode_t nullable_native = ssg_find_nullable_superformat (native);
      if (!IS_BOX_POINTER(nullable_native))
        spar_error (ssg->ssg_sparp, "Unable to compose SQL text because quad map format %.200s has no version that could handle NULL values", native->qmfName );
      native = nullable_native;
    }
  if (IS_BOX_POINTER (needed) &&
    IS_BOX_POINTER (native) &&
    ssg_valmode_is_subformat_of (needed, native) )
    needed = native; /* !!!TBD: proper check for safety of this replacement (the value returned may be of an unexpected type) */
  qm = triple->_.triple.tc_list[0]->tc_qm;
  if (SPART_TRIPLE_FIELDS_COUNT <= var->_.var.tr_idx)
    qmv = (qm_value_t *)1;
  else
    qmv = JSO_FIELD_ACCESS(qm_value_t *, qm, qm_field_map_offsets[var->_.var.tr_idx])[0];
  if (NULL != qmv)
    {
      int col_count = (IS_BOX_POINTER (needed) ? needed->qmfColumnCount : 1);
      int col_ctr;
      if ((1 == col_count) || (needed != native) || ((NULL != asname) && !IS_BOX_POINTER (asname)))
        {
          if (0 == col_count)
            rv->_.retval.vname = NULL;
          else if (IS_BOX_POINTER (qmv) && (0 != BOX_ELEMENTS (qmv->qmvColumns)))
            rv->_.retval.vname = (caddr_t)(qmv->qmvColumns[0]->qmvcColumnName);
          else
            rv->_.retval.vname = var->_.var.vname;
          ssg_print_valmoded_scalar_expn (ssg, rv, needed, native, asname);
          return;
        }
      for (col_ctr = 0; col_ctr < col_count; col_ctr++)
        {
          const char *eq_idx_asname = ((1 == col_count) ? NULL_ASNAME : (COL_IDX_ASNAME + col_ctr));
          if (col_ctr)
            ssg_puts (", ");
          if (!IS_BOX_POINTER (qmv))
            spar_sqlprint_error ("ssg_" "print_tr_var_expn(): multicolumn printing of special binding");
          rv->_.retval.vname = (caddr_t)(qmv->qmvColumns[col_ctr]->qmvcColumnName);
          ssg_print_valmoded_scalar_expn (ssg, rv, needed, native, eq_idx_asname);
          if (IS_BOX_POINTER (asname))
            {
              char buf[210];
              snprintf (buf, sizeof (buf), "%.100s~%d", asname, col_ctr);
#ifdef NDEBUG
              ssg_puts (" AS ");
#else
              ssg_puts (" AS /*tr_var_expn*/ ");
#endif
              ssg_prin_id (ssg, buf);
            }
        }
    }
  else
    ssg_print_valmoded_scalar_expn (ssg, rv, needed, native, asname);
}

ssg_valmode_t
ssg_smallest_union_valmode (ssg_valmode_t m1, ssg_valmode_t m2)
{
  ssg_valmode_t best;
  int ctr1, ctr2, largest_weight;
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
  largest_weight = -1;
  DO_BOX_FAST (qm_format_t *, sup1, ctr1, m1->qmfSuperFormats)
    {
      int sup1_weight;
      if (NULL == sup1)
        continue;
      sup1_weight = BOX_ELEMENTS_0 (sup1->qmfSuperFormats);
      if (sup1_weight <= largest_weight)
        continue;
      DO_BOX_FAST (qm_format_t *, sup2, ctr2, m2->qmfSuperFormats)
        {
          if (sup1 == sup2)
            {
              best = sup1;
              largest_weight = sup1_weight;
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
      else if ((SSG_VALMODE_LONG == m1) && (m2->qmfIsSubformatOfLong))
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
      if (!m1->qmfIsBijection)
        {
          if (SPART_VARR_IS_REF & m1->qmfValRange.rvrRestrictions)
            return SSG_VALMODE_SQLVAL;
          if (SPART_VARR_IS_LIT & m1->qmfValRange.rvrRestrictions)
            return SSG_VALMODE_SQLVAL;
          return SSG_VALMODE_LONG;
        }
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
  if (!(m1->qmfIsBijection) || !(m2->qmfIsBijection))
    {
      if ((SPART_VARR_IS_REF & m1->qmfValRange.rvrRestrictions) &&
        (SPART_VARR_IS_REF & m2->qmfValRange.rvrRestrictions) )
        return SSG_VALMODE_SQLVAL;
      if ((SPART_VARR_IS_LIT & m1->qmfValRange.rvrRestrictions) &&
        (SPART_VARR_IS_LIT & m2->qmfValRange.rvrRestrictions) )
        return SSG_VALMODE_SQLVAL;
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

ssg_valmode_t
ssg_find_nullable_superformat (ssg_valmode_t fmt)
{
  int ctr;
  if (!IS_BOX_POINTER (fmt))
    return fmt;
  if (!(fmt->qmfValRange.rvrRestrictions & SPART_VARR_NOT_NULL))
    return fmt;
  DO_BOX_FAST (qm_format_t *, sup, ctr, fmt->qmfSuperFormats)
    {
      ssg_valmode_t sup_nullable = ssg_find_nullable_superformat (sup);
      if (IS_BOX_POINTER (sup_nullable))
        return sup_nullable;
    }
  END_DO_BOX_FAST;
  return SSG_VALMODE_LONG;
}

#define SSG_MAGIC_SPLIT_MULTIPART \
	"^{comma-list-begin}^ __spfinv (^{tree}^, ^{custom-string-1}^, 2)[^{N}^]^{as-name-N}^^{end}^"

#define SSG_MAGIC_SPLIT_SINGLEPART \
	" __spfinv (^{tree}^, ^{custom-string-1}^, 2)[0]"

caddr_t *
ssg_const_is_good_for_split_into_short (spar_sqlgen_t *ssg, SPART *tree, int tree_is_qname, ssg_valmode_t fmt)
{
  ccaddr_t tmpl, sff, strg;
  caddr_t err = NULL;
  caddr_t split, split_copy;
  int tree_type = tree_is_qname ? SPAR_QNAME : SPART_TYPE (tree);
  if (!IS_BOX_POINTER (fmt) || !fmt->qmfIsBijection || (NULL == fmt->qmfCustomString1))
    return NULL;
  switch (tree_type)
    {
    case SPAR_QNAME:
      if (NULL == fmt->qmfShortOfUriTmpl)
        spar_internal_error (ssg->ssg_sparp, "ssg_" "const_is_good_for_split_into_short(): NULL == qmfShortOfUriTmpl, so there are corrupted medatada");
      tmpl = fmt->qmfShortOfUriTmpl;
      break;
    case SPAR_LIT:
      if ((DV_ARRAY_OF_POINTER == DV_TYPE_OF (tree)) && ((NULL != tree->_.lit.language) || (NULL != tree->_.lit.datatype)))
        return NULL;
      if (NULL == fmt->qmfShortOfSqlvalTmpl)
        spar_internal_error (ssg->ssg_sparp, "ssg_" "const_is_good_for_split_into_short(): NULL == qmfShortOfSqlvalTmpl, so there are corrupted medatada");
      tmpl = fmt->qmfShortOfSqlvalTmpl;
      break;
    default:
      return NULL;
    }
  if (strcmp (tmpl, SSG_MAGIC_SPLIT_MULTIPART) && strcmp (tmpl, SSG_MAGIC_SPLIT_SINGLEPART))
    return NULL;
  sff = fmt->qmfCustomString1;
  if (NULL != strstr (sff, "%{")) /* Macro expansion may vary between compilation time and execution time(s), no ho magic can be made once. */
    return NULL;
  strg = SPAR_LIT_OR_QNAME_VAL (tree);
  split = sprintf_inverse (NULL, &err, strg, sff, 1);
  if (NULL != err)
    {
      dk_free_tree (err);
      return NULL;
    }
  if ((DV_ARRAY_OF_POINTER != DV_TYPE_OF (split)) || (fmt->qmfColumnCount != BOX_ELEMENTS (split)))
    {
      dk_free_tree (split);
      return NULL;
    }
  split_copy = t_full_box_copy_tree (split);
  dk_free_tree (split);
  return (caddr_t *)split_copy;
}

void
ssg_print_bop_bool_expn (spar_sqlgen_t *ssg, SPART *tree, const char *bool_op, const char *sqlval_fn, int top_filter_op, ssg_valmode_t needed)
{
  SPART *left = tree->_.bin_exp.left;
  SPART *right = tree->_.bin_exp.right;
  caddr_t *split = NULL;
  ptrlong ttype = tree->type;
  int bop_has_bool_args = ((BOP_AND == ttype) || (BOP_OR == ttype));
  int bop_is_comparison = ((BOP_LT == ttype) || (BOP_LTE == ttype) || (BOP_GT == ttype) || (BOP_GTE == ttype));
  ssg_valmode_t left_vmode, right_vmode, min_mode;
  ptrlong left_restr_bits = -1, right_restr_bits = -1;
  if (bop_has_bool_args)
    {
      left_vmode = right_vmode = min_mode = SSG_VALMODE_BOOL;
      goto vmodes_found; /* see below */
    }
  left_vmode = sparp_expn_native_valmode (ssg->ssg_sparp, left);
  right_vmode = sparp_expn_native_valmode (ssg->ssg_sparp, right);
/* There exists a special popular case for a filter for GRAPH `iri(my_expression)` { ... } where graph is made by mapping with a fixed graph.
Without the special optization it becomes iri_to_id ('graph iri string from view declaration') = DB.DBA.RDF_MAKE_IID_OF_QNAME_SAFE (my_expression) */
  if ((BOP_EQ == ttype) &&
    ((SSG_VALMODE_SQLVAL == left_vmode) || (SSG_VALMODE_SQLVAL == right_vmode)) &&
    ((SSG_VALMODE_LONG == left_vmode) || (SSG_VALMODE_LONG == right_vmode)) )
    {
      left_restr_bits = sparp_restr_bits_of_expn (ssg->ssg_sparp, left);
      right_restr_bits = sparp_restr_bits_of_expn (ssg->ssg_sparp, right);
      if ((SPART_VARR_IS_REF & left_restr_bits) && (SPART_VARR_IS_REF & right_restr_bits))
        {
          min_mode = SSG_VALMODE_SQLVAL;
          goto vmodes_found; /* see below */
        }
    }
/* Special case for "=" or "!=" between bijection short made by good sff and a constant that can be parsed by sprintf_inverse */
  if (!bop_is_comparison && (IS_BOX_POINTER (left_vmode) && left_vmode->qmfIsBijection))
    {
      split = ssg_const_is_good_for_split_into_short (ssg, right, 0, left_vmode);
      if (NULL != split)
        {
          min_mode = left_vmode;
#ifndef NDEBUG
          right = BADBEEF_BOX;
#endif
          goto vmodes_found; /* see below */
        }
    }
/* There is no "symmetric" check like "if (!bop_is_comparison && (IS_BOX_POINTER (right_vmode) && right_vmode->qmfIsBijection))" because tree is rotated so the constant is supposed to be at right */
/* Valmode of global expressions does not really matter because they're calculated only once, hence the comparison prefers valmode of the non-global expression argument */
  if (!bop_is_comparison && (SSG_VALMODE_SQLVAL == right_vmode) &&
    ((SSG_VALMODE_LONG == left_vmode) ||
      (IS_BOX_POINTER (left_vmode) && left_vmode->qmfIsBijection) ) &&
    sparp_tree_is_global_expn (ssg->ssg_sparp, right) )
    {
      if ((BOP_NEQ != ttype) || !(IS_BOX_POINTER (left_vmode)) || left_vmode->qmfOkForAnySqlvalue)
        {
          min_mode = left_vmode;
          goto vmodes_found; /* see below */
        }
      if (-1 == left_restr_bits)
        left_restr_bits = sparp_restr_bits_of_expn (ssg->ssg_sparp, left);
      if (-1 == right_restr_bits)
        right_restr_bits = sparp_restr_bits_of_expn (ssg->ssg_sparp, right);
      if ((left_vmode->qmfIsSubformatOfLongWhenRef) &&
        (SPART_VARR_IS_REF & left_restr_bits) &&
        (SPART_VARR_IS_REF & right_restr_bits) &&
        !sparp_tree_is_global_expn (ssg->ssg_sparp, left) )
        {
          min_mode = left_vmode;
          goto vmodes_found; /* see below */
        }
      min_mode = SSG_VALMODE_SQLVAL;
      goto vmodes_found; /* see below */
    }
  if (!bop_is_comparison && (SSG_VALMODE_SQLVAL == left_vmode) &&
    ((SSG_VALMODE_LONG == right_vmode) ||
      (IS_BOX_POINTER (right_vmode) && right_vmode->qmfIsBijection) ) &&
    sparp_tree_is_global_expn (ssg->ssg_sparp, left) )
    {
      if ((BOP_NEQ == ttype) && (IS_BOX_POINTER (right_vmode)) && !right_vmode->qmfOkForAnySqlvalue)
        min_mode = SSG_VALMODE_SQLVAL;
      else
        min_mode = right_vmode;
      goto vmodes_found; /* see below */
    }
  min_mode = ssg_largest_intersect_valmode (left_vmode, right_vmode);
  if (SSG_VALMODE_LONG == min_mode)
    min_mode = SSG_VALMODE_SQLVAL;
  if (IS_BOX_POINTER (min_mode))
    {
      if (!min_mode->qmfIsBijection)
        min_mode = SSG_VALMODE_SQLVAL;
      else if (bop_is_comparison && ((!min_mode->qmfIsStable) || (1 != min_mode->qmfColumnCount)))
        min_mode = SSG_VALMODE_SQLVAL;
    }

vmodes_found:
  if (top_filter_op && (SSG_VALMODE_BOOL == needed))
    {
      ssg_putchar ('('); ssg->ssg_indent ++;
      if (bop_has_bool_args)
        {
          ssg_print_filter_expn (ssg, left);
          ssg_puts (bool_op);
          ssg_newline (1);
          ssg_print_filter_expn (ssg, right);
        }
      else if (!IS_BOX_POINTER (min_mode) || (1 == min_mode->qmfColumnCount))
        {
          ssg_print_scalar_expn (ssg, left, min_mode, NULL_ASNAME);
          ssg_puts (bool_op);
          if (NULL == split)
            ssg_print_scalar_expn (ssg, right, min_mode, NULL_ASNAME);
          else
            ssg_print_box_as_sql_atom (ssg, split[0], 0);
        }
      else
        {
          int colctr;
          for (colctr = 0; colctr < min_mode->qmfColumnCount; colctr++)
            {
              const char *asname;
              if (colctr)
                {
                  if (BOP_EQ == ttype)
                    ssg_puts (" and ");
                  else
                    ssg_puts (" or ");
                }
              ssg_putchar ('('); ssg->ssg_indent ++;
              if (bop_is_comparison)
                {
                  int prevcolctr;
                  for (prevcolctr = 0; prevcolctr < colctr; prevcolctr++)
                    {
                      asname = COL_IDX_ASNAME + prevcolctr;
                      ssg_putchar ('('); ssg->ssg_indent ++;
                      ssg_print_scalar_expn (ssg, left, min_mode, asname);
                      ssg_puts (" = ");
                      if (NULL == split)
                        ssg_print_scalar_expn (ssg, right, min_mode, asname);
                      else
                        ssg_print_box_as_sql_atom (ssg, split[prevcolctr], 0);
                      ssg->ssg_indent --; ssg_putchar (')');
                      ssg_puts (" and ");
                    }
                }
              asname = COL_IDX_ASNAME + colctr;
              ssg_print_scalar_expn (ssg, left, min_mode, asname);
              ssg_puts (bool_op);
              if (NULL == split)
                ssg_print_scalar_expn (ssg, right, min_mode, asname);
              else
                ssg_print_box_as_sql_atom (ssg, split[colctr], 0);
              ssg->ssg_indent --; ssg_putchar (')');
            }
        }
      ssg->ssg_indent --; ssg_putchar (')');
    }
  else if ((SSG_VALMODE_SQLVAL == needed) || (SSG_VALMODE_BOOL == needed))
    {
      if (!IS_BOX_POINTER (min_mode) || (1 == min_mode->qmfColumnCount))
        {
          ssg_puts (sqlval_fn); ssg->ssg_indent ++;
          ssg_print_scalar_expn (ssg, left, min_mode, NULL_ASNAME);
          ssg_puts (", ");
          if (NULL == split)
            ssg_print_scalar_expn (ssg, right, min_mode, NULL_ASNAME);
          else
            ssg_print_box_as_sql_atom (ssg, split[0], 0);
          ssg->ssg_indent --; ssg_putchar (')');
        }
      else
        {
          int colctr;
          if (BOP_EQ == ttype)
            ssg_puts (" __and (");
          else
            ssg_puts (" __or (");
          ssg->ssg_indent ++;
          for (colctr = 0; colctr < min_mode->qmfColumnCount; colctr++)
            {
              const char *asname;
              if (colctr)
                ssg_puts (", ");
              if (bop_is_comparison)
                {
                  int prevcolctr;
                  ssg_puts (" __and ("); ssg->ssg_indent ++;
                  for (prevcolctr = 0; prevcolctr < colctr; prevcolctr++)
                    {
                      asname = COL_IDX_ASNAME + prevcolctr;
                      ssg_puts (" equ ("); ssg->ssg_indent ++;
                      ssg_print_scalar_expn (ssg, left, min_mode, asname);
                      ssg_puts (", ");
                      if (NULL == split)
                        ssg_print_scalar_expn (ssg, right, min_mode, asname);
                      else
                        ssg_print_box_as_sql_atom (ssg, split[prevcolctr], 0);
                      ssg->ssg_indent --; ssg_putchar (')');
                      ssg_puts (", ");
                    }
                }
              asname = COL_IDX_ASNAME + colctr;
              ssg_puts (sqlval_fn); ssg->ssg_indent ++;
              ssg_print_scalar_expn (ssg, left, min_mode, asname);
              ssg_puts (", ");
              if (NULL == split)
                ssg_print_scalar_expn (ssg, right, min_mode, asname);
              else
                ssg_print_box_as_sql_atom (ssg, split[colctr], 0);
              ssg->ssg_indent --; ssg_putchar (')');
            }
          ssg->ssg_indent --; ssg_putchar (')');
        }
    }
  else if (SSG_VALMODE_DATATYPE == needed)
    {
      ssg_print_box_as_sql_atom (ssg, uname_xmlschema_ns_uri_hash_boolean, 1);
    }
  else if (SSG_VALMODE_LANGUAGE == needed)
    {
      ssg_puts (" NULL");
    }
  else
    spar_sqlprint_error ("ssg_" "print_bop_bool_expn (): unsupported mode");
}

void
ssg_print_bop_calc_expn (spar_sqlgen_t *ssg, SPART *tree, const char *s1, const char *s2, const char *s3, ssg_valmode_t needed)
{
  SPART *left = tree->_.bin_exp.left;
  SPART *right = tree->_.bin_exp.right;
  if (SSG_VALMODE_LANGUAGE == needed)
    {
      ssg_puts (" NULL");
      return;
    }
  if ((SSG_VALMODE_LONG != needed) && (SSG_VALMODE_SQLVAL != needed))
    {
      ssg_print_valmoded_scalar_expn (ssg, tree, needed, SSG_VALMODE_SQLVAL, NULL);
      return;
    }
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
  left_native = sparp_expn_native_valmode (ssg->ssg_sparp, left);
  right_native = sparp_expn_native_valmode (ssg->ssg_sparp, right);
  smallest_union = ssg_smallest_union_valmode (left_native, right_native);
  if ((SSG_VALMODE_LONG == smallest_union) ||
    (IS_BOX_POINTER (smallest_union) && smallest_union->qmfIsSubformatOfLong) )
    {
      ptrlong left_restr_bits = sparp_restr_bits_of_expn (ssg->ssg_sparp, left);
      ptrlong right_restr_bits = sparp_restr_bits_of_expn (ssg->ssg_sparp, right);
      if ((SPART_VARR_LONG_EQ_SQL & left_restr_bits) && (SPART_VARR_LONG_EQ_SQL & right_restr_bits))
        smallest_union = SSG_VALMODE_SQLVAL;
      else if ((SSG_VALMODE_LONG == smallest_union) &&
        (SPART_VARR_IS_REF & left_restr_bits) && (SPART_VARR_IS_REF & right_restr_bits) )
        smallest_union = SSG_VALMODE_SQLVAL;
    }
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
#ifdef RIGOROUS_CMP
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
#else
      ssg_puts ("(");
      ssg->ssg_indent += 1;
      ssg_print_scalar_expn (ssg, left, smallest_union, NULL_ASNAME);
      ssg_puts (bool_op);
      ssg_print_scalar_expn (ssg, right, smallest_union, NULL_ASNAME);
      ssg_puts (")");
      ssg->ssg_indent -= 1;
#endif
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
      ssg_puts (",");
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
      ssg_puts (",");
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
  ssg_valmode_t arg1_native = sparp_expn_native_valmode (ssg->ssg_sparp, arg1);
  int argctr;
  ssg_valmode_t op_fmt = NULL;
  int arg1_restr_bits;
  switch (tree->_.builtin.btype)
    {
    case BOUND_L:
      {
        const char *ltext, *rtext;
        arg1_restr_bits = sparp_restr_bits_of_expn (ssg->ssg_sparp, arg1);
        if (arg1_restr_bits & SPART_VARR_NOT_NULL)
          {
#ifdef NDEBUG
            ssg_puts (" 1");
#else
            ssg_puts (" 1 /* optimized BOUND */");
#endif
            return;
          }
        if (arg1_restr_bits & (SPART_VARR_ALWAYS_NULL | SPART_VARR_CONFLICT))
          {
#ifdef NDEBUG
            ssg_puts (" 0");
#else
            ssg_puts (" 0 /* optimized BOUND */");
#endif
            return;
          }
        if (top_filter_op)
          { ltext = " ("; rtext = " is not null)"; }
        else
          { ltext = "(isnotnull ("; rtext = "))"; }
        ssg_puts (ltext);
        if (IS_BOX_POINTER (arg1_native) && (1 < arg1_native->qmfColumnCount))
          {
            int colctr, colcount = arg1_native->qmfColumnCount;
            ssg_puts (" coalesce (");
            for (colctr = 0; colctr < colcount; colctr++)
              {
                if (colctr)
                  ssg_putchar (',');
                ssg_print_scalar_expn (ssg, arg1, arg1_native, COL_IDX_ASNAME + colctr);
              }
            ssg_puts (")");
          }
        else
          {
            ssg_print_scalar_expn (ssg, arg1, arg1_native, NULL_ASNAME);
          }
        ssg_puts (rtext);
        return;
      }
    case SAMETERM_L:
      {
        SPART *arg2 = tree->_.builtin.args[1];
        SPART *expanded;
        ptrlong arg1_restrs = sparp_restr_bits_of_expn (ssg->ssg_sparp, arg1);
        ptrlong arg2_restrs = sparp_restr_bits_of_expn (ssg->ssg_sparp, arg2);
        if ((arg1_restrs & SPART_VARR_IS_REF) && (arg2_restrs & SPART_VARR_IS_REF))
          {
            expanded = spartlist (ssg->ssg_sparp, 3, BOP_EQ, arg1, arg2);
            ssg_print_bop_bool_expn (ssg, expanded, " = ", " equ (", top_filter_op, needed);
            return;
          }
        if ((arg1_restrs & SPART_VARR_IS_REF) || (arg2_restrs & SPART_VARR_IS_REF))
          {
            SPART *potential_literal = ((arg1_restrs & SPART_VARR_IS_REF) ? arg2 : arg1);
            expanded = spartlist (ssg->ssg_sparp, 3, BOP_AND,
              spartlist (ssg->ssg_sparp, 3, SPAR_BUILT_IN_CALL, (ptrlong)isIRI_L, t_list (1, potential_literal)),
              spartlist (ssg->ssg_sparp, 3, BOP_EQ, arg1, arg2) );
            goto expanded_sameterm_ready; /* see below */
          }
        expanded = spartlist (ssg->ssg_sparp, 3, BOP_AND,
          spartlist (ssg->ssg_sparp, 3, BOP_EQ, arg1, arg2),
          spartlist (ssg->ssg_sparp, 3, BOP_AND,
            spartlist (ssg->ssg_sparp, 3, BOP_OR,
              spartlist (ssg->ssg_sparp, 3, BOP_EQ,
                spartlist (ssg->ssg_sparp, 3, SPAR_BUILT_IN_CALL, (ptrlong)DATATYPE_L, t_list (1, arg1)),
                spartlist (ssg->ssg_sparp, 3, SPAR_BUILT_IN_CALL, (ptrlong)DATATYPE_L, t_list (1, arg2)) ),
              spartlist (ssg->ssg_sparp, 3, BOP_AND,
                spartlist (ssg->ssg_sparp, 3, BOP_NOT,
                  spartlist (ssg->ssg_sparp, 3, SPAR_BUILT_IN_CALL, (ptrlong)BOUND_L, t_list (1, 
                      spartlist (ssg->ssg_sparp, 3, SPAR_BUILT_IN_CALL, (ptrlong)DATATYPE_L, t_list (1, arg1)) ) ),
                  NULL ),
                spartlist (ssg->ssg_sparp, 3, BOP_NOT,
                  spartlist (ssg->ssg_sparp, 3, SPAR_BUILT_IN_CALL, (ptrlong)BOUND_L, t_list (1, 
                      spartlist (ssg->ssg_sparp, 3, SPAR_BUILT_IN_CALL, (ptrlong)DATATYPE_L, t_list (1, arg2)) ) ),
                  NULL ) ) ),
            spartlist (ssg->ssg_sparp, 3, BOP_OR,
              spartlist (ssg->ssg_sparp, 3, BOP_EQ,
                spartlist (ssg->ssg_sparp, 3, SPAR_BUILT_IN_CALL, (ptrlong)LANG_L, t_list (1, arg1)),
                spartlist (ssg->ssg_sparp, 3, SPAR_BUILT_IN_CALL, (ptrlong)LANG_L, t_list (1, arg2)) ),
              spartlist (ssg->ssg_sparp, 3, BOP_AND,
                spartlist (ssg->ssg_sparp, 3, BOP_NOT,
                  spartlist (ssg->ssg_sparp, 3, SPAR_BUILT_IN_CALL, (ptrlong)BOUND_L, t_list (1, 
                      spartlist (ssg->ssg_sparp, 3, SPAR_BUILT_IN_CALL, (ptrlong)LANG_L, t_list (1, arg1)) ) ),
                  NULL ),
                spartlist (ssg->ssg_sparp, 3, BOP_NOT,
                  spartlist (ssg->ssg_sparp, 3, SPAR_BUILT_IN_CALL, (ptrlong)BOUND_L, t_list (1, 
                      spartlist (ssg->ssg_sparp, 3, SPAR_BUILT_IN_CALL, (ptrlong)LANG_L, t_list (1, arg2)) ) ),
                  NULL ) ) ) ) );

expanded_sameterm_ready:
        ssg_print_bop_bool_expn (ssg, expanded, " AND ", " __and (", top_filter_op, needed);
        return;
      }
    case DATATYPE_L:
      if (SSG_VALMODE_LONG != needed)
        ssg_print_valmoded_scalar_expn (ssg, tree, needed, SSG_VALMODE_LONG, NULL_ASNAME);
      else
        ssg_print_scalar_expn (ssg, arg1, SSG_VALMODE_DATATYPE, NULL_ASNAME);
      return;
    case LIKE_L:
      if ((SSG_VALMODE_BOOL != needed) && (SSG_VALMODE_SQLVAL != needed) && (SSG_VALMODE_LONG != needed))
        ssg_print_valmoded_scalar_expn (ssg, tree, needed, SSG_VALMODE_BOOL, NULL_ASNAME);
      else
        {
          ssg_puts (" (cast ("); ssg_print_scalar_expn (ssg, arg1, SSG_VALMODE_SQLVAL, NULL_ASNAME);
          ssg_puts (" as varchar) like cast ("); ssg_print_scalar_expn (ssg, tree->_.builtin.args[1], SSG_VALMODE_SQLVAL, NULL_ASNAME);
          ssg_puts (" as varchar))"); 
        }
      return;
    case IN_L:
      if ((SSG_VALMODE_BOOL != needed) && (SSG_VALMODE_SQLVAL != needed) && (SSG_VALMODE_LONG != needed))
        ssg_print_valmoded_scalar_expn (ssg, tree, needed, SSG_VALMODE_BOOL, NULL_ASNAME);
      else
        {
          if (IS_BOX_POINTER (arg1_native) && (1 == arg1_native->qmfColumnCount))
            {
              op_fmt = arg1_native;
              DO_BOX_FAST (SPART *, argN, argctr, tree->_.builtin.args)
                {
                  ssg_valmode_t argN_native;
                  if (0 == argctr)
                    continue;
                  argN_native = sparp_expn_native_valmode (ssg->ssg_sparp, argN);
                  if (argN_native != op_fmt)
                    {
                      op_fmt = ssg_smallest_union_valmode (op_fmt, argN_native);
                      if (!IS_BOX_POINTER (op_fmt))
                        break;
                    }
                }
              END_DO_BOX_FAST;
              if (SSG_VALMODE_LONG == op_fmt)
                {
                  DO_BOX_FAST (SPART *, argN, argctr, tree->_.builtin.args)
                    {
                      ssg_valmode_t argN_native;
                      argN_native = sparp_expn_native_valmode (ssg->ssg_sparp, argN);
                      if ((SSG_VALMODE_SQLVAL == argN_native) || (SSG_VALMODE_BOOL == argN_native))
                        continue;
                      if (IS_BOX_POINTER (argN_native) &&
                        ((argN_native->qmfIsSubformatOfLong &&
                            (SPART_VARR_LONG_EQ_SQL & argN_native->qmfValRange.rvrRestrictions ) ) ||
                           !strcmp (argN_native->qmfSqlvalOfShortTmpl, " ^{tree}^") ) )
                        continue;
                      if ((IS_BOX_POINTER (argN_native) &&
                        argN_native->qmfIsSubformatOfLong) ||
                        (SSG_VALMODE_LONG == argN_native) )
                        {
                          ptrlong rbits = sparp_restr_bits_of_expn (ssg->ssg_sparp, argN);
                          if (SPART_VARR_LONG_EQ_SQL & rbits)
                            continue;
                        }
                      goto IN_cant_use_SQLVAL; /* see below */
                    }
                  END_DO_BOX_FAST;
                  op_fmt = SSG_VALMODE_SQLVAL;
                  goto IN_op_fnt_found; /* see below */
IN_cant_use_SQLVAL: ;
                }
            }
          else 
            op_fmt = SSG_VALMODE_LONG;
        }
IN_op_fnt_found:
      switch (BOX_ELEMENTS (tree->_.builtin.args))
        {
        case 0: ssg_puts (/*top_filter_op ? " (1=2)" :*/ " 0"); return;
        case 1:
          ssg_puts (top_filter_op ? " (" : " equ (");
          ssg_print_scalar_expn (ssg, arg1, op_fmt, NULL_ASNAME);
          ssg_puts (top_filter_op ? " = /* in one */ " : " ,");
          ssg_print_scalar_expn (ssg, tree->_.builtin.args[1], op_fmt, NULL_ASNAME);
          ssg_puts (")");
          return;
        default: break;
        }
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
      return;
    case isBLANK_L:
      if ((SSG_VALMODE_BOOL != needed) && (SSG_VALMODE_SQLVAL != needed) && (SSG_VALMODE_LONG != needed))
        ssg_print_valmoded_scalar_expn (ssg, tree, needed, SSG_VALMODE_BOOL, NULL_ASNAME);
      else
        {
          arg1_restr_bits = sparp_restr_bits_of_expn (ssg->ssg_sparp, arg1);
          if (arg1_restr_bits & (SPART_VARR_IS_LIT | SPART_VARR_ALWAYS_NULL | SPART_VARR_CONFLICT))
            {
#ifdef NDEBUG
              ssg_puts (" 0");
#else
              ssg_puts (" 0 /* optimized isBLANK */");
#endif
              return;
            }
          if (IS_BOX_POINTER (arg1_native))
            {
              const char *tmpl = ((top_filter_op || (NULL == arg1_native->qmf01blankOfShortTmpl)) ?
                arg1_native->qmfIsblankOfShortTmpl : arg1_native->qmf01blankOfShortTmpl );
              ssg_print_tmpl (ssg, arg1_native, tmpl, NULL, NULL, arg1, NULL_ASNAME);
            }
          else if (SSG_VALMODE_LONG == arg1_native)
            ssg_print_tmpl (ssg, arg1_native,
              (top_filter_op ?
                " ((isiri_id (^{tree}^) and (^{tree}^ >= min_bnode_iri_id ()))" :
                " either (isiri_id (^{tree}^), gte (^{tree}^, min_bnode_iri_id ()), 0)" ),
              NULL, NULL, arg1, NULL );
          else if (SSG_VALMODE_SQLVAL == arg1_native)
            ssg_print_tmpl (ssg, arg1_native, " DB.DBA.RDF_IS_BLANK_REF (^{tree}^)", NULL, NULL, arg1, NULL_ASNAME);
          else
            spar_sqlprint_error ("ssg_" "print_builtin_expn(): bad native type for isBLANK()");
        }
      return;
    case LANG_L:
      if (SSG_VALMODE_SQLVAL != needed)
        ssg_print_valmoded_scalar_expn (ssg, tree, needed, SSG_VALMODE_SQLVAL, NULL_ASNAME);
      else
        {
          arg1_restr_bits = sparp_restr_bits_of_expn (ssg->ssg_sparp, arg1);
          if (arg1_restr_bits & (SPART_VARR_IS_REF | SPART_VARR_LONG_EQ_SQL | SPART_VARR_ALWAYS_NULL))
            {
#ifdef NDEBUG
              ssg_puts (" NULL");
#else
              ssg_puts (" NULL /* optimized LANG */");
#endif
              return;
            }
          ssg_print_scalar_expn (ssg, arg1, SSG_VALMODE_LANGUAGE, NULL_ASNAME);
        }
      return;
    case isURI_L:
    case isIRI_L:
      if ((SSG_VALMODE_BOOL != needed) && (SSG_VALMODE_SQLVAL != needed) && (SSG_VALMODE_LONG != needed))
        ssg_print_valmoded_scalar_expn (ssg, tree, needed, SSG_VALMODE_BOOL, NULL_ASNAME);
      else
        {
          arg1_restr_bits = sparp_restr_bits_of_expn (ssg->ssg_sparp, arg1);
          if (arg1_restr_bits & (SPART_VARR_IS_LIT | SPART_VARR_ALWAYS_NULL | SPART_VARR_CONFLICT))
            {
#ifdef NDEBUG
              ssg_puts (" 0");
#else
              ssg_puts (" 0 /* optimized isIRI */");
#endif
              return;
            }
          if (arg1_restr_bits & SPART_VARR_IS_REF & SPART_VARR_NOT_NULL)
            {
#ifdef NDEBUG
              ssg_puts (" 1");
#else
              ssg_puts (" 1 /* optimized isIRI */");
#endif
              return;
            }
          if (IS_BOX_POINTER (arg1_native))
            {
              const char *tmpl = ((top_filter_op || (NULL == arg1_native->qmf01uriOfShortTmpl)) ?
                arg1_native->qmfIsuriOfShortTmpl : arg1_native->qmf01uriOfShortTmpl );
              ssg_print_tmpl (ssg, arg1_native, tmpl, NULL, NULL, arg1, NULL_ASNAME);
            }
          else if (SSG_VALMODE_LONG == arg1_native)
            ssg_print_tmpl (ssg, arg1_native,
              (top_filter_op ?
                " ((isiri_id (^{tree}^) and (^{tree}^ < min_bnode_iri_id ()))" :
                " either (isiri_id (^{tree}^), lt (^{tree}^, min_bnode_iri_id ()), 0)" ),
              NULL, NULL, arg1, NULL );
          else if (SSG_VALMODE_SQLVAL == arg1_native)
            ssg_print_tmpl (ssg, arg1_native, " DB.DBA.RDF_IS_URI_REF (^{tree}^)", NULL, NULL, arg1, NULL_ASNAME);
          else
            spar_sqlprint_error ("ssg_" "print_builtin_expn(): bad native type for isURI()");
        }
      return;
    case isLITERAL_L:
      if ((SSG_VALMODE_BOOL != needed) && (SSG_VALMODE_SQLVAL != needed) && (SSG_VALMODE_LONG != needed))
        ssg_print_valmoded_scalar_expn (ssg, tree, needed, SSG_VALMODE_BOOL, NULL_ASNAME);
      else
        {
          arg1_restr_bits = sparp_restr_bits_of_expn (ssg->ssg_sparp, arg1);
          if (arg1_restr_bits & (SPART_VARR_IS_REF | SPART_VARR_ALWAYS_NULL | SPART_VARR_CONFLICT))
            {
#ifdef NDEBUG
              ssg_puts (" 0");
#else
              ssg_puts (" 0 /* optimized isLITERAL */");
#endif
              return;
            }
          if (arg1_restr_bits & SPART_VARR_IS_LIT & SPART_VARR_NOT_NULL)
            {
#ifdef NDEBUG
              ssg_puts (" 1");
#else
              ssg_puts (" 1 /* optimized isLITERAL */");
#endif
              return;
            }
          if (IS_BOX_POINTER (arg1_native))
            ssg_print_tmpl (ssg, arg1_native, arg1_native->qmfIslitOfShortTmpl, NULL, NULL, arg1, NULL_ASNAME);
          else if (SSG_VALMODE_LONG == arg1_native)
            ssg_print_tmpl (ssg, arg1_native,
              (top_filter_op ?
                " (not (isiri_id (^{tree}^))" : "iszero (isiri_id (^{tree}^))" ),
              NULL, NULL, arg1, NULL );
          else if (SSG_VALMODE_SQLVAL == arg1_native)
            ssg_print_tmpl (ssg, arg1_native, " DB.DBA.RDF_IS_LITERAL (^{tree}^)", NULL, NULL, arg1, NULL_ASNAME);
          else
            spar_sqlprint_error ("ssg_" "print_builtin_expn(): bad native type for isLITERAL()");
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
            ssg_print_tmpl (ssg, needed /* not arg1_native! */, tmpl, NULL, NULL, arg1, NULL_ASNAME);
          }
        else if (SSG_VALMODE_SQLVAL == needed)
          {
            const char *tmpl = NULL;
            if (IS_BOX_POINTER (arg1_native))
              tmpl = arg1_native->qmfStrsqlvalOfShortTmpl;
            else if (SSG_VALMODE_LONG == arg1_native)
              tmpl = " __rdf_strsqlval (^{tree}^)";
            else if (SSG_VALMODE_SQLVAL == arg1_native)
              tmpl = " DB.DBA.RDF_STRSQLVAL_OF_SQLVAL (^{tree}^)";
            else
              spar_sqlprint_error ("ssg_" "print_builtin_expn(): bad native type for IRI()");
            ssg_print_tmpl (ssg, arg1_native, tmpl, NULL, NULL, arg1, NULL_ASNAME);
          }
        else if (SSG_VALMODE_LONG == needed)
          {
            const char *tmpl = NULL;
            if (IS_BOX_POINTER (arg1_native))
              tmpl = arg1_native->qmfIidOfShortTmpl;
            else if (SSG_VALMODE_LONG == arg1_native)
              tmpl = " DB.DBA.RDF_MAKE_IID_OF_LONG (^{tree}^)";
            else if (SSG_VALMODE_SQLVAL == arg1_native)
              tmpl = " DB.DBA.RDF_MAKE_IID_OF_QNAME_SAFE (^{tree}^)";
            else
              spar_sqlprint_error ("ssg_" "print_builtin_expn(): bad native type for IRI()");
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
            const char *tmpl = NULL;
            if (IS_BOX_POINTER (arg1_native))
              tmpl = arg1_native->qmfStrsqlvalOfShortTmpl;
            else if (SSG_VALMODE_LONG == arg1_native)
              tmpl = " __rdf_strsqlval (^{tree}^)";
            else if (SSG_VALMODE_SQLVAL == arg1_native)
              tmpl = " DB.DBA.RDF_STRSQLVAL_OF_SQLVAL (^{tree}^)";
            else if (SSG_VALMODE_BOOL == arg1_native)
              tmpl = " case (^{tree}^) when 0 then 'false' else 'true' end";
            else
              spar_sqlprint_error ("ssg_" "print_builtin_expn(): bad native type for STR()");
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
      if ((SSG_VALMODE_BOOL != needed) && (SSG_VALMODE_SQLVAL != needed))
        ssg_print_valmoded_scalar_expn (ssg, tree, needed, SSG_VALMODE_BOOL, NULL_ASNAME);
      else
        { /*!!!TBD extra 'between'*/
          ssg_puts (" rdf_regex_impl (");
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
      if ((SSG_VALMODE_BOOL != needed) && (SSG_VALMODE_SQLVAL != needed) && (SSG_VALMODE_LONG != needed))
        ssg_print_valmoded_scalar_expn (ssg, tree, needed, SSG_VALMODE_BOOL, NULL_ASNAME);
      else
        {
          arg1_restr_bits = sparp_restr_bits_of_expn (ssg->ssg_sparp, arg1);
          if (arg1_restr_bits & (SPART_VARR_IS_REF | SPART_VARR_ALWAYS_NULL))
            {
#ifdef NDEBUG
              ssg_puts (" 0");
#else
              ssg_puts (" 0 /* optimized LANGMATCHES */");
#endif
              return;
            }
          ssg_puts (" DB.DBA.RDF_LANGMATCHES (");
          ssg_print_scalar_expn (ssg, arg1, SSG_VALMODE_LONG, NULL_ASNAME);
          ssg_putchar (',');
          ssg_print_scalar_expn (ssg, tree->_.builtin.args[1], SSG_VALMODE_SQLVAL, NULL_ASNAME);
          ssg_putchar (')');
        }
      return;
    default:
      spar_sqlprint_error ("ssg_" "print_builtin_expn(): unsupported builtin");  
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
sparp_find_valmode_by_name_prefix (sparp_t *sparp, caddr_t name, ssg_valmode_t dflt)
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
    spar_error (sparp, "Unsupported prefix before '::' in name '%.200s'", name);
  return dflt;
}

ssg_valmode_t
sparp_rettype_of_global_param (sparp_t *sparp, caddr_t name)
{
  ssg_valmode_t res;
  if ((':' == name[0]) && (':' == name[1]))
    {
      caddr_t vmname = sparp->sparp_env->spare_input_param_valmode_name;
      if (NULL == vmname)
        res = SSG_VALMODE_SQLVAL;
      else
        res = ssg_find_valmode_by_name (vmname);
    }
  else
    res = sparp_find_valmode_by_name_prefix (sparp, name+1, SSG_VALMODE_SQLVAL);
  return res;
}


ssg_valmode_t
sparp_rettype_of_function (sparp_t *sparp, caddr_t name)
{
  ssg_valmode_t res = sparp_find_valmode_by_name_prefix (sparp, name, SSG_VALMODE_SQLVAL);
  if (SSG_VALMODE_SPECIAL == res)
    {
      if (!strcmp (name, "SPECIAL::sql:RDF_MAKE_GRAPH_IIDS_OF_QNAMES"))
        return SSG_VALMODE_LONG; /* Fake but this works for use as 2-nd arg of 'LONG::bif:position' */
      if (!strcmp (name, "SPECIAL::sql:RDF_DIST_SER_LONG"))
        return SSG_VALMODE_LONG; /* Fake but this works for use as arg of RDF_DIST_DESER_LONG */
      if (!strcmp (name, "SPECIAL::sql:RDF_DIST_DESER_LONG"))
        return SSG_VALMODE_LONG;
      if (!strcmp (name, "SPECIAL::bif:MAX"))
        return SSG_VALMODE_LONG;
      if (!strcmp (name, "SPECIAL::bif:iri_to_id"))
        return SSG_VALMODE_LONG;
      spar_internal_error (sparp, "sparp_" "rettype_of_function(): unsupported SPECIAL");
    }
  if (!strcmp (name, uname_xmlschema_ns_uri_hash_string))
    return SSG_VALMODE_LONG;
  return SSG_VALMODE_SQLVAL /* not "return res" */;
}


ssg_valmode_t
sparp_argtype_of_function (sparp_t *sparp, caddr_t name, int arg_idx)
{
  ssg_valmode_t res = sparp_find_valmode_by_name_prefix (sparp, name, SSG_VALMODE_SQLVAL);
  if (SSG_VALMODE_SPECIAL == res)
    {
      if (!strcmp (name, "SPECIAL::sql:RDF_MAKE_GRAPH_IIDS_OF_QNAMES"))
        return SSG_VALMODE_SQLVAL;
      if (!strcmp (name, "SPECIAL::sql:RDF_DIST_SER_LONG"))
        return SSG_VALMODE_LONG;
      if (!strcmp (name, "SPECIAL::sql:RDF_DIST_DESER_LONG"))
        return SSG_VALMODE_LONG; /* Fake but this works for retvals of RDF_DIST_SER_LONG */
      if (!strcmp (name, "SPECIAL::bif:MAX"))
        return SSG_VALMODE_LONG;
      if (!strcmp (name, "SPECIAL::bif:iri_to_id"))
        return SSG_VALMODE_SQLVAL;
      spar_internal_error (sparp, "sparp_" "argtype_of_function(): unsupported SPECIAL");
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
      else if (!strcasecmp(name, "log"))
        ssg_puts ("\"LOG\"");
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

void
ssg_print_uri_list (spar_sqlgen_t *ssg, dk_set_t uri_precodes, ssg_valmode_t needed)
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

void
ssg_print_global_param (spar_sqlgen_t *ssg, caddr_t vname, ssg_valmode_t needed)
{ /* needed is always equal to native in this function */
  sparp_env_t *env = ssg->ssg_sparp->sparp_env;
  char *coloncolon = strstr (vname, "::");
  if ((NULL != coloncolon) && (vname != coloncolon))
    vname = coloncolon + 1;
  if (env->spare_globals_are_numbered)
    {
      char buf[30];
      int pos = dk_set_position_of_string (env->spare_global_var_names, vname);
      if (0 > pos)
        spar_sqlprint_error ("ssg_" "print_global_param(): unexpected global variable name");
      snprintf (buf, sizeof (buf), " :%d", pos + env->spare_global_num_offset);
      ssg_puts (buf);
      return;
    }
  if (isdigit (vname[1])) /* Numbered parameter */
    {
      ssg_putchar (' ');
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
  spar_internal_error (NULL, "ssg_" "tmpl_X_of_short(): bad mode needed");
  return NULL; /* Never reached, to keep compiler happy */
}

const char *ssg_tmpl_literal_short_of_X (qm_format_t *qm_fmt, ssg_valmode_t native)
{
  if (SSG_VALMODE_LONG == native)	return qm_fmt->qmfShortOfLongTmpl;
  if (SSG_VALMODE_SQLVAL == native)	return qm_fmt->qmfShortOfSqlvalTmpl;
  spar_internal_error (NULL, "ssg_" "tmpl_literal_short_of_X(): bad mode needed");
  return NULL; /* Never reached, to keep compiler happy */
}

const char *ssg_tmpl_ref_short_of_X (qm_format_t *qm_fmt, ssg_valmode_t native)
{
  if (SSG_VALMODE_LONG == native)	return qm_fmt->qmfShortOfLongTmpl;
  if (SSG_VALMODE_SQLVAL == native)	return qm_fmt->qmfShortOfUriTmpl;
  spar_internal_error (NULL, "ssg_" "tmpl_ref_short_of_X(): bad mode needed");
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
      if (SSG_VALMODE_LONG	== native)	return " __rdf_sqlval_of_obj /*l*/ (^{tree}^)";
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
    native = sparp_expn_native_valmode (ssg->ssg_sparp, tree);
  if (SSG_VALMODE_BOOL == native)
    {
      if ((SSG_VALMODE_SQLVAL == needed) || (SSG_VALMODE_LONG == needed))
        {
          ssg_print_scalar_expn (ssg, tree, SSG_VALMODE_BOOL, asname);
          return;
        }
      native = SSG_VALMODE_LONG; 
    }
  if (
    ((SSG_VALMODE_LONG == native) && (SSG_VALMODE_SQLVAL == needed)) ||
    ((SSG_VALMODE_SQLVAL == native) && (SSG_VALMODE_LONG == needed)) ||
    (IS_BOX_POINTER (native) && (
        ((SSG_VALMODE_SQLVAL == needed) && native->qmfIsSubformatOfLong) ||
        ((SSG_VALMODE_SQLVAL == needed) && native->qmfIsSubformatOfLongWhenEqToSql) ||
        ((SSG_VALMODE_LONG == needed) && native->qmfIsSubformatOfLongWhenEqToSql) ) ) ||
    (IS_BOX_POINTER (needed) && needed->qmfOkForAnySqlvalue && needed->qmfIsSubformatOfLongWhenEqToSql &&
      ((SSG_VALMODE_SQLVAL == native) || (SSG_VALMODE_LONG == native)) ) )
    {
      ptrlong tree_restr_bits = sparp_restr_bits_of_expn (ssg->ssg_sparp, tree);
      if (tree_restr_bits & SPART_VARR_LONG_EQ_SQL)
        {
          ssg_print_scalar_expn (ssg, tree, native, asname);
          return;
        }
    }
  if (IS_BOX_POINTER (needed) && needed->qmfIsSubformatOfLongWhenRef &&
      ((SSG_VALMODE_SQLVAL == native) || (SSG_VALMODE_LONG == native)) )
    {
      ptrlong tree_restr_bits = sparp_restr_bits_of_expn (ssg->ssg_sparp, tree);
      if (tree_restr_bits & SPART_VARR_IS_REF)
        {
          ssg_print_scalar_expn (ssg, tree, native, asname);
          return;
        }
    }
  if (IS_BOX_POINTER (native))
    {
      if ((SSG_VALMODE_LONG == needed) && native->qmfIsSubformatOfLong)
        {
          ssg_print_scalar_expn (ssg, tree, native, asname);
          return;
        }
      if ((SSG_VALMODE_LONG == needed) && native->qmfIsSubformatOfLongWhenRef)
        {
          ptrlong tree_restr_bits = sparp_restr_bits_of_expn (ssg->ssg_sparp, tree);
          if (tree_restr_bits & SPART_VARR_IS_REF)
            {
              ssg_print_scalar_expn (ssg, tree, native, asname);
              return;
            }
        }

      if ((SPAR_RETVAL == SPART_TYPE (tree)) && tree->_.retval.optional_makes_nullable &&
    /* checked above: IS_BOX_POINTER (native) && */ (native->qmfValRange.rvrRestrictions & SPART_VARR_NOT_NULL) )
        {
          ssg_valmode_t nullable_native = ssg_find_nullable_superformat (native);
          if (!IS_BOX_POINTER(nullable_native))
            spar_error (ssg->ssg_sparp, "Unable to compose SQL text for ?%.200s because quad map format %.200s has no version that could handle NULL values", tree->_.retval.vname, native->qmfName );
          native = nullable_native;
        }
      if (IS_BOX_POINTER (needed))
        {
          SPART_buf fromshort_buf;
          SPART *fromshort;
          if (ssg_valmode_is_subformat_of (native, needed))
            {
              ssg_print_retval (ssg, tree, native, asname);
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
      const char *tmpl;
      if (sparp_tree_returns_ref (ssg->ssg_sparp, tree))
        tmpl = ssg_tmpl_ref_short_of_X (needed, native);
      else
        tmpl = ssg_tmpl_literal_short_of_X (needed, native);
      ssg_print_tmpl (ssg, needed, tmpl, NULL, NULL, tree, asname);
      return;
    }
  ssg_print_tmpl (ssg, native, ssg_tmpl_X_of_Y (needed, native), NULL, NULL, tree, asname);
  return;
}


caddr_t
ssg_triple_retval_alias (spar_sqlgen_t *ssg, SPART *triple, int field_idx, int col_idx, const char *simple_vname)
{
  quad_map_t *qm;
  if (SPART_TRIPLE_FIELDS_COUNT <= field_idx)
    return t_box_dv_short_string (simple_vname);
  qm = triple->_.triple.tc_list[0]->tc_qm;
  if ((0 != triple->_.triple.ft_type) || (NULL == qm->qmTableName) || (NULL == strstr (qm->qmTableName, "DB.DBA.RDF_QUAD")))
    {
      qm_value_t *qmv = SPARP_FIELD_QMV_OF_QM (qm, field_idx);
      caddr_t full_vname;
      if (NULL == qmv)
        {
          caddr_t v = SPARP_FIELD_CONST_OF_QM (qm, field_idx);
          const char *tail = "";
          if ((DV_UNAME == DV_TYPE_OF (v)) || (DV_STRING == DV_TYPE_OF (v)))
            {
              const char *t = v + box_length (v) - 1;
              int ctr = 20;
              while ((0 < ctr--) && (v < t) && (isalnum (t[-1]))) t--;
              tail = t;
            }
          full_vname = t_box_sprintf (210, "%lx~%.100s", box_hash (v), tail);
        }
      else if (col_idx >= BOX_ELEMENTS_0 (qmv->qmvColumns))
        {
          if (col_idx > 0)
            spar_internal_error (ssg->ssg_sparp, "ssg_triple_retval_alias (): col_idx is too big");
          full_vname = t_box_sprintf (210, "%lx~fake", box_hash ((caddr_t)qmv));
        }
      else
        {
          ccaddr_t colname = qmv->qmvColumns[col_idx]->qmvcColumnName;
          if ('\"' != colname[0])
            full_vname = t_box_sprintf (210, "%lx~%.100s", box_hash ((caddr_t)qmv), colname);
          else
            full_vname = t_box_sprintf (210, "%lx%lx", box_hash ((caddr_t)qmv), box_hash ((caddr_t)colname));
        }
      return full_vname;
    }
  return t_box_dv_short_string (simple_vname);
}

void
ssg_print_scalar_expn (spar_sqlgen_t *ssg, SPART *tree, ssg_valmode_t needed, const char *asname)
{
#ifdef DEBUG
  if (THR_IS_STACK_OVERFLOW (THREAD_CURRENT_THREAD, &ssg, 1000))
    spar_internal_error (NULL, "ssg_print_scalar_expn (): stack overflow");
#endif
  if (SSG_VALMODE_AUTO == needed)
    needed = sparp_expn_native_valmode (ssg->ssg_sparp, tree);
  switch (SPART_TYPE (tree))
    {
    case BOP_AND:	ssg_print_bop_bool_expn (ssg, tree, " AND "	, " __and ("	, 0, needed); goto print_asname;
    case BOP_OR:	ssg_print_bop_bool_expn (ssg, tree, " OR "	, " __or ("	, 0, needed); goto print_asname;
    case BOP_EQ:	ssg_print_bop_bool_expn (ssg, tree, " = "	, " equ ("	, 0, needed); goto print_asname;
    case BOP_NEQ:	ssg_print_bop_bool_expn (ssg, tree, " <> "	, " neq ("	, 0, needed); goto print_asname;
    case BOP_LT:	ssg_print_bop_bool_expn (ssg, tree, " < "	, " lt ("	, 0, needed); goto print_asname;
    case BOP_LTE:	ssg_print_bop_bool_expn (ssg, tree, " <= "	, " lte ("	, 0, needed); goto print_asname;
    case BOP_GT:	ssg_print_bop_bool_expn (ssg, tree, " > "	, " gt ("	, 0, needed); goto print_asname;
    case BOP_GTE:	ssg_print_bop_bool_expn (ssg, tree, " >= "	, " gte ("	, 0, needed); goto print_asname;
   /*case BOP_LIKE: Like is built-in in SPARQL, not a BOP!
			ssg_print_bop_bool_expn (ssg, tree, " like "	, " strlike ("	, 0, needed); goto print_asname; */
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
            ssg_print_box_as_sql_atom (ssg, uname_xmlschema_ns_uri_hash_boolean, 1);
          }
        else if (SSG_VALMODE_LANGUAGE == needed)
          {
            ssg_puts (" NULL");
          }
        else
          spar_sqlprint_error ("ssg_print_scalar_expn (): unsupported mode for 'not(X)'");
        goto print_asname;
      }
    case BOP_PLUS:	ssg_print_bop_calc_expn (ssg, tree, " (", " + ", ")", needed); goto print_asname;
    case BOP_MINUS:	ssg_print_bop_calc_expn (ssg, tree, " (", " - ", ")", needed); goto print_asname;
    case BOP_TIMES:	ssg_print_bop_calc_expn (ssg, tree, " (", " * ", ")", needed); goto print_asname;
    case BOP_DIV:	ssg_print_bop_calc_expn (ssg, tree, " (", " / ", ")", needed); goto print_asname;
    case BOP_MOD:	ssg_print_bop_calc_expn (ssg, tree, " mod (", ", ", ")", needed); goto print_asname;
    case SPAR_BLANK_NODE_LABEL:
    case SPAR_VARIABLE:
      {
#if 0
        ssg_valmode_t vmode = sparp_expn_native_valmode (ssg->ssg_sparp, tree);
        if (vmode == needed)
          {
            sparp_equiv_t *eq = ssg->ssg_equivs[tree->_.var.equiv_idx];
            ssg_print_equiv_retval_expn (ssg, sparp_find_gp_by_alias (ssg->ssg_sparp, tree->_.var.selid), eq, 0, 1, needed, NULL_ASNAME);
          }
        else
          ssg_print_valmoded_scalar_expn (ssg, tree, needed, vmode);
#else
        if (NULL == ssg->ssg_equivs) /* This is for case when parts of the SPARQL front-end are used to produce small SQL fragments */
          {
            ssg_valmode_t vmode;
            if (SPART_VARNAME_IS_GLOB (tree->_.var.vname))
              {
                ssg_print_global_param (ssg, tree->_.retval.vname, needed);
                goto print_asname; /* see below */
              }
            vmode = sparp_expn_native_valmode (ssg->ssg_sparp, tree);
            if (vmode == needed)
              {
                ssg_putchar (' ');
                ssg_prin_id (ssg, tree->_.var.vname);
                goto print_asname; /* see below */
              }
            ssg_print_valmoded_scalar_expn (ssg, tree, needed, vmode, asname);
          }
        else
          {
            ptrlong eq_idx = tree->_.var.equiv_idx;
            sparp_equiv_t *eq;
            SPART *gp;
            if (SPART_BAD_EQUIV_IDX == eq_idx)
              spar_error (ssg->ssg_sparp, "Unable to use variable ?%.100s in OPTION () clause, try to rephrase the query", tree->_.var.vname);
            eq = ssg->ssg_equivs[eq_idx];
            gp = sparp_find_gp_by_alias (ssg->ssg_sparp, tree->_.var.selid);
            if ((NULL == gp) && (SPART_VARR_EXPORTED & tree->_.var.rvr.rvrRestrictions))
              gp = ssg->ssg_tree->_.req_top.pattern;
            ssg_print_equiv_retval_expn (ssg, gp, eq, SSG_RETVAL_FROM_JOIN_MEMBER | SSG_RETVAL_MUST_PRINT_SOMETHING | SSG_RETVAL_USES_ALIAS, needed, asname);
          }
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
        int curr_arg_is_long, prev_arg_is_long = 0, arg_ctr, arg_count = BOX_ELEMENTS (tree->_.funcall.argtrees);
        xqf_str_parser_desc_t *parser_desc;
	ssg_valmode_t native = sparp_rettype_of_function (ssg->ssg_sparp, tree->_.funcall.qname);
        if (native != needed)
          {
            ssg_print_valmoded_scalar_expn (ssg, tree, needed, native, asname);
            return;
          }
        ssg_putchar (' ');
        parser_desc = function_is_xqf_str_parser (tree->_.funcall.qname);
        if (NULL != parser_desc)
          {
            const char *cvtname = parser_desc->p_typed_bif_name;
            if (NULL == cvtname)
              cvtname = "__xqf_str_parse";
            ssg_puts (cvtname);
            ssg_puts (" ('");
            ssg_puts (parser_desc->p_name);
            ssg_puts ("'");
            ssg->ssg_indent++;
            for (arg_ctr = 0; arg_ctr < arg_count; arg_ctr++)
              {
                ssg_puts (", ");
                ssg_print_scalar_expn (ssg, tree->_.funcall.argtrees[arg_ctr], SSG_VALMODE_SQLVAL, NULL_ASNAME);
              }
            if (1 == arg_count)
              ssg_puts (", 1");
            ssg->ssg_indent--;
            ssg_putchar (')');
            goto print_asname;
          }
        ssg_putchar (' ');
        ssg_prin_function_name (ssg, tree->_.funcall.qname);
        ssg_puts (" (");
        if (tree->_.funcall.agg_mode)
          {
            if (!strcmp (tree->_.funcall.qname, "bif:COUNT") && ((SPART *)((ptrlong)1) == tree->_.funcall.argtrees[0]))
              arg_count = 1; /* Trick to handle SELECT COUNT FROM ... that is translated to SELECT COUNT (1, all vars) */
            if (DISTINCT_L == tree->_.funcall.agg_mode)
              ssg_puts (" DISTINCT");
          }
        ssg->ssg_indent++;
        for (arg_ctr = 0; arg_ctr < arg_count; arg_ctr++)
          {
            SPART *arg = tree->_.funcall.argtrees[arg_ctr];
            ssg_valmode_t argtype = sparp_argtype_of_function (ssg->ssg_sparp, tree->_.funcall.qname, arg_ctr);
            if (arg_ctr > 0)
              ssg_putchar (',');
            curr_arg_is_long = SPAR_FUNCALL_ARG_IS_LONG (arg);
            if (curr_arg_is_long || prev_arg_is_long) ssg_newline (0); else ssg_putchar (' ');
            ssg_print_scalar_expn (ssg, arg, argtype, NULL_ASNAME);
            prev_arg_is_long = curr_arg_is_long;
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
                ssg_puts (" iri_to_id (");
                ssg_print_box_as_sql_atom (ssg, (caddr_t)tree, 1);
                ssg_puts (")");
              }
            else if (SSG_VALMODE_SQLVAL == needed)
              ssg_print_literal_as_sqlval (ssg, NULL, tree);
            else if (IS_BOX_POINTER (needed))
              {
                if (NULL != needed->qmfShortOfUriTmpl)
                  {
                    ssg_print_tmpl (ssg, needed, needed->qmfShortOfUriTmpl, NULL, NULL, tree, asname);
                    return;
                  }
                else
                  {
                    ssg_puts (" iri_to_id (");
                    ssg_print_literal_as_sqlval (ssg, NULL, tree);
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
                ssg_puts (" __xsd_type ("); /* !!!TBD Replace with something less ugly when twobyte of every predefined type is fixed */
                ssg_print_literal_as_sqlval (ssg, NULL, tree);
                ssg_puts (")");
              }
            else if (NULL != tree->_.lit.datatype)
              ssg_print_box_as_sql_atom (ssg, tree->_.lit.datatype, 1);
            else
              ssg_puts (" NULL");
            goto print_asname;
          }
        if (SSG_VALMODE_LANGUAGE == needed)
          {
            if (DV_ARRAY_OF_POINTER != tree_dtp)
              ssg_puts (" NULL");
            else if (NULL != tree->_.lit.language)
              ssg_print_box_as_sql_atom (ssg, tree->_.lit.language, 0);
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
            ssg_print_literal_as_sqlval (ssg, NULL, tree);
            goto print_asname;
          }
        if (IS_BOX_POINTER (needed))
          ssg_print_tmpl (ssg, needed, needed->qmfShortOfTypedsqlvalTmpl, NULL, NULL, tree, asname);
        else
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
      else if (SSG_VALMODE_SQLVAL == needed)
        {
#ifdef NDEBUG
          ssg_puts (" __bft (");
#else
          ssg_puts (" __box_flags_tweak (");
#endif
          ssg_print_literal_as_sqlval (ssg, NULL, tree);
          ssg_puts (", 1)");
        }
    else
        ssg_print_tmpl (ssg, needed, needed->qmfShortOfUriTmpl, NULL, NULL, tree, asname);
      goto print_asname;
    case SPAR_RETVAL:
      {
        ssg_valmode_t vmode = sparp_expn_native_valmode (ssg->ssg_sparp, tree);
        if (vmode != needed)
          {
            ssg_print_valmoded_scalar_expn (ssg, tree, needed, vmode, asname);
            return;
          }
        ssg_print_retval (ssg, tree, vmode, asname);
        return;
      }
    case SPAR_QM_SQL_FUNCALL:
      {
        if (SSG_VALMODE_SQLVAL != needed)
          spar_sqlprint_error ("ssg_" "print_scalar_expn(): qm_sql_funcall when needed valmode is not sqlval");
        ssg_print_qm_sql (ssg, tree);
        goto print_asname;
      }
    case SPAR_GP:
      if ((SSG_VALMODE_SQLVAL != needed) && (SSG_VALMODE_LONG != needed))
        {
          ssg_print_valmoded_scalar_expn (ssg, tree, needed, SSG_VALMODE_LONG, asname);
          return;
        }
      ssg_print_scalar_subquery_exp (ssg, tree->_.gp.subquery, tree, needed);
      goto print_asname;
    case SPAR_LIST:
      {
        int ctr;
        if (NULL_ASNAME != asname)
          spar_sqlprint_error ("ssg_" "print_scalar_expn(): SPAR_LIST with asname");
        DO_BOX_FAST (SPART *, e, ctr, tree->_.list.items)
          {
            if (ctr)
              ssg_putchar(',');
            ssg_print_scalar_expn (ssg, e, needed, NULL_ASNAME);
          }
        END_DO_BOX_FAST;
        return;
      }
    default:
      spar_sqlprint_error ("ssg_" "print_scalar_expn(): unsupported scalar expression type");
      goto print_asname;
    }

print_asname:
  if (IS_BOX_POINTER (asname))
    {
#ifdef NDEBUG
      ssg_puts (" AS ");
#else
      ssg_puts (" AS /*scalar*/ ");
#endif
      ssg_prin_id (ssg, asname);
    }
}

void
ssg_print_retval (spar_sqlgen_t *ssg, SPART *tree, ssg_valmode_t vmode, const char *asname)
{
  caddr_t e_varname = NULL, full_vname = NULL;
  if (NULL == tree->_.retval.vname)
    {
      e_varname = "tmp";
      goto retval_without_var; /* see below */
    }
  if (SPART_VARNAME_IS_GLOB(tree->_.retval.vname))
    {
      ssg_print_global_param (ssg, tree->_.retval.vname, vmode);
      goto print_asname;
    }
  e_varname = ssg->ssg_equivs[tree->_.var.equiv_idx]->e_varnames[0];
  if (IS_BOX_POINTER (vmode) && (1 < vmode->qmfColumnCount) && (IS_BOX_POINTER (asname) || (NULL == asname)))
    {
      int colctr;
#ifdef NDEBUG
      ssg_putchar (' ');
#else
      ssg_puts (" /*retval-list[*/ ");
#endif
      for (colctr = 0; colctr < vmode->qmfColumnCount; colctr++)
        {
          char buf[210];
          if (colctr)
            ssg_putchar (',');
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
          snprintf (buf, sizeof (buf), "%.100s~%d", /*tree->_.retval.vname*/ e_varname, colctr);
          ssg_prin_id (ssg, buf);
          if (NULL != asname)
            {
              ssg_puts (" AS ");
              snprintf (buf, sizeof (buf), "%.100s~%d", asname, colctr);
              ssg_prin_id (ssg, buf);
            }
        }
#ifdef NDEBUG
      ssg_putchar (' ');
#else
      ssg_puts (" /*]retval-list*/ ");
#endif
      return;
    }
retval_without_var:
#ifdef NDEBUG
      ssg_putchar (' ');
#else
  ssg_puts (" /*retval[*/ ");
#endif
  if (NULL != tree->_.retval.tabid)
    {
      ssg_prin_id (ssg, tree->_.retval.tabid);
      ssg_putchar ('.');
      full_vname = ssg_triple_retval_alias (ssg, tree->_.retval.triple, tree->_.retval.tr_idx, 0, tree->_.retval.vname);
    }
  else if (NULL != tree->_.retval.selid)
    {
      ssg_prin_id (ssg, tree->_.retval.selid);
      ssg_putchar ('.');
      full_vname = tree->_.retval.vname;
    }
  if ((NULL == asname) || IS_BOX_POINTER (asname))
    {
      ssg_prin_id (ssg, full_vname);
#ifndef NDEBUG
      ssg_puts (" /* "); ssg_puts (e_varname); ssg_puts (" */");
#endif
    }
  else
    {
      int col_idx = asname - COL_IDX_ASNAME;
      char buf[210];
      snprintf (buf, sizeof (buf), "%.100s~%d", full_vname, col_idx);
      ssg_prin_id (ssg, buf);
#ifndef NDEBUG
      if (0 == col_idx)
        {
          ssg_puts (" /* "); ssg_puts (e_varname); ssg_puts (" */");
        }
#endif
    }
#ifdef NDEBUG
      ssg_putchar (' ');
#else
  ssg_puts (" /*]retval*/ ");
#endif
print_asname:
  if (IS_BOX_POINTER (asname))
    {
#ifdef NDEBUG
      ssg_puts (" AS ");
#else
      ssg_puts (" AS /*scalar*/ ");
#endif
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
    case BOP_SAME:	ssg_print_bop_bool_expn (ssg, tree, "(", "= ", ")", 1, SSG_VALMODE_BOOL); return;
    case BOP_NSAME:	ssg_print_bop_bool_expn (ssg, tree, "(", "= ", ")", 1, SSG_VALMODE_BOOL); return;
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
      ssg_puts ("AND ");
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
#ifndef NDEBUG
  if (NULL != location)
    {
      ssg_puts (" /* ");
      ssg_puts (location);
      ssg_puts (" */ ");
      ssg_newline (1);
    }
#endif
}

void
ssg_prin_option_commalist (spar_sqlgen_t *ssg, dk_set_t opts, int print_leading_comma)
{
  int ctr = 0;
  DO_SET (caddr_t, o, &opts)
    {
      if (ctr || print_leading_comma)
        ssg_puts (", ");
      ssg_puts (o);
      ctr++;
    }
  END_DO_SET()
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
ssg_find_external_in_equiv (sparp_equiv_t *eq, SPART **var_ret, caddr_t *name_ret)
{
  int ctr;
  for (ctr = eq->e_var_count; ctr--; /* no step */)
    {
      SPART *var = eq->e_vars[ctr];
      if (!(SPART_VARR_EXTERNAL & var->_.var.rvr.rvrRestrictions))
        continue;
      if (NULL != var_ret)
        var_ret[0] = var;
      if (NULL != name_ret)
        name_ret[0] = var->_.var.vname;
      return;
    }
  if (NULL != var_ret)
    var_ret[0] = NULL;
  if (NULL != name_ret)
    name_ret[0] = NULL;
}

void
ssg_print_fld_lit_restrictions (spar_sqlgen_t *ssg, quad_map_t *qmap, qm_value_t *field, caddr_t tabid, SPART *triple, int fld_idx, int print_outer_filter)
{
  SPART *fld_tree = triple->_.triple.tr_fields [fld_idx];
  SPART_buf rv_buf;
  SPART *rv = NULL;
  ptrlong field_restr = field->qmvFormat->qmfValRange.rvrRestrictions;
/*  caddr_t litvalue = ((DV_ARRAY_OF_POINTER == DV_TYPE_OF (fld_tree)) ? fld_tree->_.lit.val : (caddr_t)fld_tree);*/
  caddr_t litvalue, littype, litlang;
  if (print_outer_filter)
    {
      SPART_AUTO (rv, rv_buf, SPAR_RETVAL);
      rv->_.retval.triple = triple;
      rv->_.retval.tr_idx = fld_idx;
      rv->_.retval.tabid = tabid;
    }
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
  if (SPARP_FIXED_AND_NOT_NULL (field_restr) && (SPART_VARR_IS_LIT & field_restr))
    {
      if ((DVC_MATCH == cmp_boxes ((caddr_t)(field->qmvFormat->qmfValRange.rvrDatatype), littype, NULL, NULL)) &&
        (DVC_MATCH == cmp_boxes ((caddr_t)(field->qmvFormat->qmfValRange.rvrFixedValue), litvalue, NULL, NULL)) )
        return;
    }
  if (!(SPART_VARR_IS_LIT & field_restr))
    {
      ssg_print_where_or_and (ssg, "obj field is a literal");
      ssg_print_tmpl (ssg, field->qmvFormat, field->qmvFormat->qmfIslitOfShortTmpl, tabid, field, rv, NULL_ASNAME);
    }
  if (field->qmvFormat->qmfIsBijection)
    {
      int col_ctr, col_count;
      col_count = BOX_ELEMENTS (field->qmvColumns);
      for (col_ctr = 0; col_ctr < col_count; col_ctr++)
        {
	  qm_format_t *qmf = field->qmvFormat;
          const char *eq_asname = ((1 == col_count) ? NULL_ASNAME : (COL_IDX_ASNAME + col_ctr));
          ssg_print_where_or_and (ssg, ((0 != col_ctr) ? NULL : "field equal to literal, quick test"));
          if (print_outer_filter)
            ssg_print_scalar_expn (ssg, rv, qmf, eq_asname);
          else
            ssg_print_tr_field_expn (ssg, field, tabid, qmf, eq_asname);
          ssg_puts (" =");
          if ((DV_STRING == DV_TYPE_OF (litvalue)) &&
            ((NULL != littype) || (NULL != litlang)) )
            ssg_print_tmpl (ssg, field->qmvFormat, qmf->qmfShortOfTypedsqlvalTmpl, tabid, field, fld_tree, eq_asname);
          else if ((0 != qmf->qmfDtpOfNiceSqlval) &&
	    (qmf->qmfDtpOfNiceSqlval == DV_TYPE_OF (litvalue)) &&
	    (NULL != qmf->qmfShortOfNiceSqlvalTmpl) )
            ssg_print_tmpl (ssg, field->qmvFormat, qmf->qmfShortOfNiceSqlvalTmpl, tabid, field, (SPART *)litvalue, eq_asname);
	  else
            ssg_print_tmpl (ssg, field->qmvFormat, qmf->qmfShortOfSqlvalTmpl, tabid, field, (SPART *)litvalue, eq_asname);
        }
      if (0 != col_count)
        return;
    }
  ssg_print_where_or_and (ssg, "field equal to literal, full test");
  if (print_outer_filter)
    ssg_print_scalar_expn (ssg, rv, SSG_VALMODE_SQLVAL, NULL_ASNAME);
  else
    ssg_print_tr_field_expn (ssg, field, tabid, SSG_VALMODE_SQLVAL, NULL_ASNAME);
  ssg_puts (" =");
  ssg_print_literal_as_sqlval (ssg, NULL, (SPART *)litvalue);
}

void
ssg_print_fld_uri_restrictions (spar_sqlgen_t *ssg, quad_map_t *qmap, qm_value_t *field, caddr_t tabid, caddr_t uri, SPART *triple, int fld_idx, int print_outer_filter)
{
#ifndef NDEBUG
  SPART *fld_tree = triple->_.triple.tr_fields [fld_idx];
#endif
  SPART_buf rv_buf;
  SPART *rv = NULL;
  ptrlong field_restr = field->qmvFormat->qmfValRange.rvrRestrictions;
  if (SPARP_FIXED_AND_NOT_NULL(field_restr) && (SPART_VARR_IS_REF & field_restr))
    {
      if (DVC_MATCH == cmp_boxes ((caddr_t)(field->qmvFormat->qmfValRange.rvrFixedValue), uri, NULL, NULL))
        return;
    }
  if (print_outer_filter)
    {
      SPART_AUTO (rv, rv_buf, SPAR_RETVAL);
      rv->_.retval.triple = triple;
      rv->_.retval.tr_idx = fld_idx;
      rv->_.retval.tabid = tabid;
    }
  if (!(SPART_VARR_IS_REF & field_restr))
    {
      ssg_print_where_or_and (ssg, "node field is a URI ref");
      ssg_print_tmpl (ssg, field->qmvFormat, field->qmvFormat->qmfIsrefOfShortTmpl, tabid, field, rv, NULL_ASNAME);
    }
  if (field->qmvFormat->qmfIsBijection)
    {
      int col_ctr, col_count;
      caddr_t *split;
      col_count = BOX_ELEMENTS (field->qmvColumns);
      split = ssg_const_is_good_for_split_into_short (ssg, (SPART *)uri, 1, field->qmvFormat);
      for (col_ctr = 0; col_ctr < col_count; col_ctr++)
        {
          const char *eq_asname = ((1 == col_count) ? NULL_ASNAME : (COL_IDX_ASNAME + col_ctr));
          ssg_print_where_or_and (ssg, ((0 != col_ctr) ? NULL : "field equal to URI ref"));
          if (print_outer_filter)
            ssg_print_scalar_expn (ssg, rv, field->qmvFormat, eq_asname);
          else
            ssg_print_tr_field_expn (ssg, field, tabid, field->qmvFormat, eq_asname);
          ssg_puts (" =");
          if (NULL == split)
            ssg_print_tmpl (ssg, field->qmvFormat, field->qmvFormat->qmfShortOfUriTmpl, tabid, field, (SPART *)uri, eq_asname);
          else
            ssg_print_box_as_sql_atom (ssg, split[col_ctr], 0);
        }
      if (0 != col_count)
        return;
    }
  if (!(SPART_VARR_IS_REF & field_restr) ||
      (strlen (field->qmvFormat->qmfStrsqlvalOfShortTmpl) >
      strlen (field->qmvFormat->qmfLongOfShortTmpl) ) )
    {
      ssg_print_where_or_and (ssg, "IRI_ID of a field equal to IRI_ID of URI ref");
      if (print_outer_filter)
        ssg_print_scalar_expn (ssg, rv, SSG_VALMODE_LONG, NULL_ASNAME);
      else
        ssg_print_tr_field_expn (ssg, field, tabid, SSG_VALMODE_LONG, NULL_ASNAME);
      ssg_puts (" = iri_to_id (");
      ssg_print_box_as_sql_atom (ssg, uri, 1);
      ssg_puts (")");
    }
  else
    {
      ssg_print_where_or_and (ssg, "field equal to URI ref");
      if (print_outer_filter)
        ssg_print_scalar_expn (ssg, rv, SSG_VALMODE_SQLVAL, NULL_ASNAME);
      else
        ssg_print_tr_field_expn (ssg, field, tabid, SSG_VALMODE_SQLVAL, NULL_ASNAME);
      ssg_puts (" = ");
      ssg_print_box_as_sql_atom (ssg, uri, 1);
    }
}

void
ssg_print_fld_restrictions (spar_sqlgen_t *ssg, quad_map_t *qmap, qm_value_t *field, caddr_t tabid, SPART *triple, int fld_idx, int print_outer_filter)
{
  sparp_env_t *env = ssg->ssg_sparp->sparp_env;
  SPART *fld_tree = triple->_.triple.tr_fields [fld_idx];
  ptrlong fld_tree_type = SPART_TYPE (fld_tree);
  SPART *fld_if_outer = print_outer_filter ? fld_tree : NULL;
  switch (fld_tree_type)
    {
    case SPAR_LIT:
      {
        ssg_print_fld_lit_restrictions (ssg, qmap, field, tabid, triple, fld_idx, print_outer_filter);
        return;
      }
    case SPAR_QNAME:
    /*case SPAR_QNAME_NS:*/
      {
        caddr_t uri = fld_tree->_.lit.val;
        ssg_print_fld_uri_restrictions (ssg, qmap, field, tabid, uri, triple, fld_idx, print_outer_filter);
        return;
      }
    case SPAR_VARIABLE: case SPAR_BLANK_NODE_LABEL:
      {
        ptrlong field_restr = field->qmvFormat->qmfValRange.rvrRestrictions;
        ptrlong tree_restr = fld_tree->_.var.rvr.rvrRestrictions;
        if (SPARP_ASSIGNED_EXTERNALLY (tree_restr))
          return; /* Because this means that equiv has equality on the field that is to be printed later; so there's nothing to do right here */
        if (SPART_VARR_CONFLICT & tree_restr) 
          {
            ssg_print_where_or_and (ssg, "conflict! The query remained not entirely optimized");
            ssg_puts (" 0");
            return;
          }
        if ((SPART_VARR_NOT_NULL & tree_restr) && (!(SPART_VARR_NOT_NULL & field_restr)))
          {
            ssg_print_where_or_and (ssg, "nullable variable is not null");
            if (0 == field->qmvFormat->qmfColumnCount)
              ssg_print_tmpl (ssg, field->qmvFormat, "(^{tree}^ is not null)", tabid, field, NULL, NULL_ASNAME);
            else if (print_outer_filter)
              ssg_print_tmpl (ssg, field->qmvFormat, "(^{tree-0}^ is not null)", tabid, field, fld_tree, NULL_ASNAME);
            else
              ssg_print_tmpl (ssg, field->qmvFormat, "(^{alias-0}^.^{column-0}^ is not null)", tabid, field, NULL, NULL_ASNAME);
          }
/* SPONGE_SEEALSO () as a fake filter for a variable */
        if ((SPAR_VARIABLE == fld_tree_type) &&
          !(SPART_VARR_IS_LIT & tree_restr) &&
          !(SPART_VARR_EXTERNAL & tree_restr) &&
          (NULL != env->spare_grab.rgc_sa_preds) &&
          ((0 <= dk_set_position_of_string (env->spare_grab.rgc_sa_vars, fld_tree->_.var.vname)) ||
            (0 <= dk_set_position_of_string (env->spare_grab.rgc_vars, fld_tree->_.var.vname)) ) )
          {
/* External variable should be checked by this fake predicate at place of origin, hence no check here.
It's an open issue what to do if seealso is enabled only in scalar subquery.
Maybe the best thing is to prohibit seealso declarations in subqueries at all.
!!!TBD. */
            SPART *graph_tree = triple->_.triple.tr_graph;
            ptrlong graph_tree_type = SPART_TYPE (graph_tree);
            qm_value_t *graph_qmv = qmap->qmGraphMap;
            ssg_print_where_or_and (ssg, "fake filter for a sponged variable");
            ssg_puts (" DB.DBA.RDF_GRAB_SEEALSO (");
            ssg_print_tmpl (ssg, field->qmvFormat, field->qmvFormat->qmfUriOfShortTmpl, tabid, field, fld_if_outer, NULL_ASNAME);
            ssg_puts (", ");
            for (;;)
              {
                if (NULL == graph_qmv)
                  {
                    ssg_print_literal_as_long (ssg, (SPART *)(qmap->qmGraphRange.rvrFixedValue));
                    break;
                  }
                if ((SPAR_VARIABLE == graph_tree_type) || (SPAR_BLANK_NODE_LABEL == graph_tree_type))
                  {
                    ptrlong graph_tree_restr = graph_tree->_.var.rvr.rvrRestrictions;
                    if (SPART_VARR_FIXED & graph_tree_restr)
                      {
                        ssg_print_literal_as_long (ssg, (SPART *)(graph_tree->_.var.rvr.rvrFixedValue));
                        break;
                      }
                    if (SPART_VARR_GLOBAL & graph_tree_restr)
                      {
                        ssg_print_global_param (ssg, graph_tree->_.var.vname, SSG_VALMODE_LONG);
                        break;
                      }
                    ssg_print_tmpl (ssg, graph_qmv->qmvFormat, graph_qmv->qmvFormat->qmfIidOfShortTmpl, tabid, graph_qmv, NULL, NULL_ASNAME);
                    break;
                  }
                ssg_puts ("NULL");
                break;
              }
            ssg_puts (", :0)");
          }
        if ((SPART_VARR_IS_BLANK & tree_restr) && (!(SPART_VARR_IS_BLANK & field_restr)))
          {
            ssg_print_where_or_and (ssg, "variable is blank node");
            ssg_print_tmpl (ssg, field->qmvFormat, field->qmvFormat->qmfIsblankOfShortTmpl, tabid, field, fld_if_outer, NULL_ASNAME);
          }
        else if ((SPART_VARR_IS_IRI & tree_restr) && (!(SPART_VARR_IS_IRI & field_restr)))
          {
            ssg_print_where_or_and (ssg, "variable is IRI");
            ssg_print_tmpl (ssg, field->qmvFormat, field->qmvFormat->qmfIsuriOfShortTmpl, tabid, field, fld_if_outer, NULL_ASNAME);
          }
        else if ((SPART_VARR_IS_REF & tree_restr) && (!(SPART_VARR_IS_REF & field_restr)))
          {
            ssg_print_where_or_and (ssg, "'any' variable is a reference");
            ssg_print_tmpl (ssg, field->qmvFormat, field->qmvFormat->qmfIsrefOfShortTmpl, tabid, field, fld_if_outer, NULL_ASNAME);
          }
        else if ((SPART_VARR_IS_LIT & tree_restr) && (!(SPART_VARR_IS_LIT & field_restr)))
          {
            ssg_print_where_or_and (ssg, "'any' variable is a literal");
            ssg_print_tmpl (ssg, field->qmvFormat, field->qmvFormat->qmfIslitOfShortTmpl, tabid, field, fld_if_outer, NULL_ASNAME);
          }
        /*!!! TBD: checks for type, lang */
        return;
      }
    default:
      spar_sqlprint_error ("ssg_" "print_fld_restrictions(): unsupported type of fld_tree");
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
#ifdef NDEBUG
      ssg_puts (" NULL");
#else
      ssg_puts (" NULL /* due to conflict on ");
      ssg_puts (eq->e_varnames[0]);
      ssg_puts (" */");
#endif
      goto write_assuffix;
    }
#if 0 /* no longer needed */
  if (SSG_VALMODE_LONG == needed)
    {
      ssg_puts (" /* LONG retval */");
    }
#endif
  if (SPARP_EQ_IS_FIXED_AND_NOT_NULL (eq) && (!(flags & SSG_RETVAL_OPTIONAL_MAKES_NULLABLE)))
    {
      ssg_print_scalar_expn (ssg, (SPART *)(eq->e_rvr.rvrFixedValue), needed, asname);
      return 1;
    }
  var_count = eq->e_var_count;
  if (SSG_VALMODE_AUTO == needed)
    needed = native = sparp_equiv_native_valmode (ssg->ssg_sparp, gp, eq);
  if ((flags & SSG_RETVAL_OPTIONAL_MAKES_NULLABLE) &&
    IS_BOX_POINTER (needed) && (needed->qmfValRange.rvrRestrictions & SPART_VARR_NOT_NULL) )
    {
      ssg_valmode_t nullable_needed = ssg_find_nullable_superformat (needed);
      if (!IS_BOX_POINTER(nullable_needed))
        spar_error (ssg->ssg_sparp, "Unable to compose SQL text for ?%.200s because quad map format %.200s has no version that could handle NULL values", eq->e_varnames[0], needed->qmfName );
      needed = nullable_needed;
    }
  if ((SPART_VARR_GLOBAL | SPART_VARR_EXTERNAL) & eq->e_rvr.rvrRestrictions)
    {
      SPART *vartree;
      caddr_t varname;
      if (SPART_VARR_GLOBAL & eq->e_rvr.rvrRestrictions)
        ssg_find_global_in_equiv (eq, &vartree, &varname);
      else
        ssg_find_external_in_equiv (eq, &vartree, &varname);
      if (NULL != vartree)
        {
          if (NULL == native)
            native = sparp_expn_native_valmode (ssg->ssg_sparp, vartree);
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
          rv->_.retval.triple = sparp_find_triple_of_var_or_retval (ssg->ssg_sparp, NULL, var, 1);
          native = sparp_expn_native_valmode (ssg->ssg_sparp, rv);
          if ((native == needed) || (SSG_VALMODE_AUTO == needed))
            name_as_expn = var->_.var.vname;
#ifdef DEBUG
          if (SSG_VALMODE_AUTO == native)
            {
              sparp_expn_native_valmode (ssg->ssg_sparp, rv);
              spar_internal_error (ssg->ssg_sparp, "ssg_" "print_equiv_retval_expn(): SSG_VALMODE_AUTO == native");
            }
#endif
          if (flags & SSG_RETVAL_OPTIONAL_MAKES_NULLABLE)
            rv->_.retval.optional_makes_nullable = 1;
          ssg_print_valmoded_scalar_expn (ssg, rv, needed, native, asname);/*#1*/
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
          sparp_rvr_copy (ssg->ssg_sparp, &(rv->_.retval.rvr), &(eq->e_rvr));
          rv->_.retval.selid = gp->_.gp.selid;
          rv->_.retval.tabid = NULL;
          rv->_.retval.vname = eq->e_varnames[0];
          native = sparp_expn_native_valmode (ssg->ssg_sparp, rv);
          if ((native == needed) || (SSG_VALMODE_AUTO == needed))
            name_as_expn = rv->_.retval.vname;
          else if (SSG_VALMODE_AUTO == native)
            {
              if (ssg->ssg_sparp->sparp_env->spare_signal_void_variables)
                spar_error (ssg->ssg_sparp, "No way to calculate value of variable '%.200s'; the query might contain triple patterns that can not be bound",
                  rv->_.retval.vname );
              ssg_print_valmoded_scalar_expn (ssg, (SPART *)t_NEW_DB_NULL, needed, SSG_VALMODE_SQLVAL, asname);
              return 1;
            }
          if (flags & SSG_RETVAL_OPTIONAL_MAKES_NULLABLE)
            rv->_.retval.optional_makes_nullable = 1;
          ssg_print_valmoded_scalar_expn (ssg, rv, needed, native, asname);
          return 1;
        }
    }
  switch (gp->_.gp.subtype)
    {
    case SELECT_L:
      {
        SPART_buf rv_buf;
        SPART *rv;
        SPART_AUTO (rv, rv_buf, SPAR_RETVAL);
        rv->_.retval.equiv_idx = eq->e_own_idx;
        sparp_rvr_copy (ssg->ssg_sparp, &(rv->_.retval.rvr), &(eq->e_rvr));
        rv->_.retval.selid = gp->_.gp.selid;
        rv->_.retval.tabid = NULL;
        rv->_.retval.vname = eq->e_varnames[0];
        if (NULL == native)
          native = sparp_equiv_native_valmode (ssg->ssg_sparp, gp, eq);
        if ((native == needed) || (SSG_VALMODE_AUTO == needed))
          name_as_expn = rv->_.retval.vname;
        if (flags & SSG_RETVAL_OPTIONAL_MAKES_NULLABLE)
          rv->_.retval.optional_makes_nullable = 1;
        ssg_print_valmoded_scalar_expn (ssg, rv, needed, native, asname);
        return 1;
      }
    case UNION_L:
      {
        SPART *gp_member = NULL;
        sparp_equiv_t *subval;
        int sub_flags = (flags & SSG_RETVAL_OPTIONAL_MAKES_NULLABLE);
        int printed;
        if (!(flags & SSG_RETVAL_FROM_FIRST_UNION_MEMBER))
          goto try_write_null; /* see below */
        gp_member = gp->_.gp.members[0];
        subval = sparp_equiv_get_subvalue_ro (ssg->ssg_equivs, ssg->ssg_equiv_count, gp_member, eq);
        if (!(SPART_VARR_NOT_NULL & eq->e_rvr.rvrRestrictions))
          sub_flags |= SSG_RETVAL_OPTIONAL_MAKES_NULLABLE;
        sub_flags |= SSG_RETVAL_FROM_GOOD_SELECTED |
          (flags & (SSG_RETVAL_MUST_PRINT_SOMETHING | SSG_RETVAL_FROM_ANY_SELECTED | SSG_RETVAL_CAN_PRINT_NULL | SSG_RETVAL_USES_ALIAS) );
        printed = ssg_print_equiv_retval_expn (ssg, gp_member, subval, sub_flags, needed, asname);
        return printed;
      }
    default:
      {
        SPART *gp_member = NULL;
        sparp_equiv_t *subval = NULL;
        int memb_ctr, memb_len;
        int sub_flags = (flags & SSG_RETVAL_OPTIONAL_MAKES_NULLABLE);
        int printed;
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
              {
                if (OPTIONAL_L == gp_member->_.gp.subtype)
                  sub_flags |= SSG_RETVAL_OPTIONAL_MAKES_NULLABLE;
                break;
              }
          }
        sub_flags |= SSG_RETVAL_FROM_GOOD_SELECTED |
          (flags & (SSG_RETVAL_MUST_PRINT_SOMETHING | SSG_RETVAL_FROM_ANY_SELECTED | SSG_RETVAL_CAN_PRINT_NULL | SSG_RETVAL_USES_ALIAS) );
        printed = ssg_print_equiv_retval_expn (ssg, gp_member, subval, sub_flags, needed, asname);/*#2*/
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
#ifdef NDEBUG
      ssg_puts (" AS ");
#else
      ssg_puts (" AS /*eqretval*/ ");
#endif
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
          SPART *var_triple = sparp_find_triple_of_var_or_retval (ssg->ssg_sparp, NULL, var, 1);
          SPART_buf var_rv_buf/*, glob_rv_buf*/;
          SPART *var_rv/*, *glob_rv*/;
          quad_map_t *qm;
          int col_ctr, col_count;
          qm = var_triple->_.triple.tc_list[0]->tc_qm;
          if (SPART_TRIPLE_FIELDS_COUNT > var->_.var.tr_idx)
            {
              qm_value_t *qmv = JSO_FIELD_ACCESS(qm_value_t *, qm, qm_field_map_offsets[var->_.var.tr_idx])[0];
              if ((NULL == qmv) && (!SPART_VARNAME_IS_GLOB (var->_.var.vname))) /* It's fixed and it's constant in qm hence it matches compile-time, no run-time check needed */
                continue;
            }
          SPART_AUTO (var_rv, var_rv_buf, SPAR_RETVAL);
          memcpy (&(var_rv->_.retval), &(var->_.var), sizeof (var->_.var));
          var_rv->_.retval.triple = var_triple;
          vmode = sparp_expn_native_valmode (ssg->ssg_sparp, var_rv);
          col_count = (IS_BOX_POINTER (vmode) ? vmode->qmfColumnCount : 1);
          for (col_ctr = 0; col_ctr < col_count; col_ctr++)
            {
              const char *eq_idx_asname = ((1 == col_count) ? NULL_ASNAME : (COL_IDX_ASNAME + col_ctr));
              ssg_print_where_or_and (ssg, ((0 != col_ctr) ? NULL : "fixed value of equiv class (short)"));
              ssg_print_tr_var_expn (ssg, var, vmode, eq_idx_asname);
              ssg_puts (" =");
              ssg_print_scalar_expn (ssg, (SPART *)(eq->e_rvr.rvrFixedValue), vmode, eq_idx_asname);
            }
          if ((0 == col_count) || !(SPART_VARR_IS_REF & eq->e_rvr.rvrRestrictions))
            {
              ssg_print_where_or_and (ssg, "fixed value of equiv class (sqlval)");
              ssg_print_tr_var_expn (ssg, var, SSG_VALMODE_SQLVAL, NULL_ASNAME);
              ssg_puts (" =");
              ssg_print_literal_as_sqlval (ssg, NULL, (SPART *)(eq->e_rvr.rvrFixedValue));
            }
          continue;
        }
      if ((SPART_VARR_GLOBAL | SPART_VARR_EXTERNAL) & eq->e_rvr.rvrRestrictions)
        {
          SPART *glob_var;
          caddr_t glob_name;
          ssg_valmode_t vmode;
          SPART_buf var_rv_buf, glob_rv_buf;
          SPART *var_rv, *glob_rv;
          int col_ctr, col_count;
          SPART_AUTO (var_rv, var_rv_buf, SPAR_RETVAL);
          memcpy (&(var_rv->_.retval), &(var->_.var), sizeof (var->_.var));
          var_rv->_.retval.triple = sparp_find_triple_of_var_or_retval (ssg->ssg_sparp, eq->e_gp, var, 1);
          var_rv->_.retval.vname = "";
          vmode = sparp_expn_native_valmode (ssg->ssg_sparp, var_rv);
          SPART_AUTO (glob_rv, glob_rv_buf, SPAR_RETVAL);
          if (SPART_VARR_GLOBAL & eq->e_rvr.rvrRestrictions)
            ssg_find_global_in_equiv (eq, &glob_var, &glob_name);
          else
            {
              SPART *local_glob_var;
              ssg_find_external_in_equiv (eq, &local_glob_var, &glob_name);
              glob_var = sparp_find_origin_of_external_var (ssg->ssg_sparp, local_glob_var);
            }
          if (NULL != glob_var)
            {
              memcpy (&(glob_rv->_.retval), &(glob_var->_.var), sizeof (glob_var->_.var));
              if (!(SPART_VARR_GLOBAL & eq->e_rvr.rvrRestrictions))
                {
                  glob_rv->_.retval.gp = SPARP_EQUIV (ssg->ssg_sparp, glob_var->_.var.equiv_idx)->e_gp; /*sparp_find_gp_by_alias (ssg->ssg_sparp, glob_rv->_.retval.selid);*/
                  glob_rv->_.retval.triple = sparp_find_triple_of_var_or_retval (ssg->ssg_sparp, glob_rv->_.retval.gp, glob_rv, 0);
                }
              else
                {
                  glob_rv->_.retval.gp = NULL;
                  glob_rv->_.retval.triple = NULL;
                }
            }
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
              ssg_print_where_or_and (ssg, ((0 != col_ctr) ? NULL :
                  ((SPART_VARR_GLOBAL & eq->e_rvr.rvrRestrictions) ?
                    "global param value of equiv class" : "outer query value of equiv class" ) ) );
              ssg_print_tr_var_expn (ssg, var_rv, vmode, eq_idx_asname);
              ssg_puts (" =");
              if (NULL != glob_rv->_.retval.triple)
                ssg_print_tr_var_expn (ssg, glob_rv, vmode, eq_idx_asname);
              else
                ssg_print_scalar_expn (ssg, glob_rv, vmode, eq_idx_asname);
            }
          if (0 == col_count)
            {
              ssg_print_where_or_and (ssg, "global param value of equiv class (sqlval for 0 cols)");
              ssg_print_tr_var_expn (ssg, var, SSG_VALMODE_SQLVAL, NULL_ASNAME);
              ssg_puts (" =");
              ssg_print_scalar_expn (ssg, glob_rv, SSG_VALMODE_SQLVAL, NULL_ASNAME);
            }
        }
      if (SPART_VARR_TYPED & eq->e_rvr.rvrRestrictions)
        {
          if (SPART_VARR_TYPED & var->_.var.rvr.rvrRestrictions)
            {
              if (eq->e_rvr.rvrDatatype != var->_.var.rvr.rvrDatatype)
                spar_internal_error (ssg->ssg_sparp, "Fixed type of equiv class is not equal to fixed type of one of its variables");
            }
          else
            {
              ssg_print_where_or_and (ssg, "fixed type of equiv class");
              ssg_print_tr_var_expn (ssg, var, SSG_VALMODE_DATATYPE, NULL_ASNAME);
              ssg_puts (" =");
              ssg_print_literal_as_sqlval (ssg, NULL, (SPART *)(eq->e_rvr.rvrDatatype));
            }
        }
    }

print_cross_equalities:
  /* Printing cross-equalities */
  if (SPARP_EQ_IS_ASSIGNED_EXTERNALLY (eq))
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
          var_native = sparp_expn_native_valmode (ssg->ssg_sparp, var);
          var2_native = sparp_expn_native_valmode (ssg->ssg_sparp, var2);
          common_native = ssg_largest_eq_valmode (var_native, var2_native);
#ifdef DEBUG
	  if (SSG_VALMODE_LONG == common_native)
            ssg_puts (" /* note SSG_VALMODE_LONG: */");
#endif
          if (IS_BOX_POINTER (common_native) || (SSG_VALMODE_AUTO == common_native))
            { /* Note special zeropart case below */
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
          if ((0 == col_count) && (SSG_VALMODE_AUTO == common_native))
            { /* Two zeropart values of same class are always equal, the check is needed only if (SSG_VALMODE_AUTO == common_native) */
              ssg_print_where_or_and (ssg, "two fields belong to same equiv (sqlval for for zeropart)");
              ssg_print_tr_var_expn (ssg, var, SSG_VALMODE_SQLVAL, NULL_ASNAME);
              ssg_puts (" =");
              ssg_print_tr_var_expn (ssg, var2, SSG_VALMODE_SQLVAL, NULL_ASNAME);
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
          var_native = sparp_expn_native_valmode (ssg->ssg_sparp, var);
          sub2_native = sparp_equiv_native_valmode (ssg->ssg_sparp, sub2_gp, sub2_eq);
          common_native = ssg_largest_eq_valmode (var_native, sub2_native);
#ifdef DEBUG
	  if (SSG_VALMODE_LONG == common_native)
            ssg_puts (" /* note SSG_VALMODE_LONG: */");
#endif
          if (IS_BOX_POINTER (common_native) || (SSG_VALMODE_AUTO == common_native))
            { /* Note special zeropart case below */
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
          if ((0 == col_count) && (SSG_VALMODE_AUTO == common_native))
            { /* Two zeropart values of same class are always equal, the check is needed only if (SSG_VALMODE_AUTO == common_native) */
              ssg_print_where_or_and (ssg, "field and retval belong to same equiv (sqlval for zeropart)");
              ssg_print_tr_var_expn (ssg, var, SSG_VALMODE_SQLVAL, NULL_ASNAME);
              ssg_puts (" =");
              ssg_print_equiv_retval_expn (ssg, sub2_gp, sub2_eq, SSG_RETVAL_FROM_GOOD_SELECTED | SSG_RETVAL_MUST_PRINT_SOMETHING, SSG_VALMODE_SQLVAL, NULL_ASNAME);
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
          sub_native = sparp_equiv_native_valmode (ssg->ssg_sparp, sub_gp, sub_eq);
          sub2_native = sparp_equiv_native_valmode (ssg->ssg_sparp, sub2_gp, sub2_eq);
          common_native = ssg_largest_eq_valmode (sub_native, sub2_native);
          if (SSG_VALMODE_LONG == common_native)
            common_native = SSG_VALMODE_SQLVAL;
          else if (SSG_VALMODE_AUTO == common_native)
            common_native = sub_native; /* Note that sub_native == sub2_native in this case */
          else if (IS_BOX_POINTER (common_native) && !(common_native->qmfIsBijection))
            common_native = SSG_VALMODE_SQLVAL;

#ifdef DEBUG
	  if (SSG_VALMODE_LONG == common_native)
            ssg_puts (" /* note SSG_VALMODE_LONG: */");
#endif
          col_count = ((IS_BOX_POINTER (common_native)) ? common_native->qmfColumnCount : 1);
          for (col_ctr = 0; col_ctr < col_count; col_ctr++)
            {
              const char *eq_asname = ((1 == col_count) ? NULL_ASNAME : (COL_IDX_ASNAME + col_ctr));
              ssg_print_where_or_and (ssg, ((0 != col_ctr) ? NULL : "two retvals belong to same equiv"));
              ssg_print_equiv_retval_expn (ssg, sub_gp, sub_eq, SSG_RETVAL_FROM_GOOD_SELECTED | SSG_RETVAL_MUST_PRINT_SOMETHING, common_native, eq_asname);
              ssg_puts (" =");
              ssg_print_equiv_retval_expn (ssg, sub2_gp, sub2_eq, SSG_RETVAL_FROM_GOOD_SELECTED | SSG_RETVAL_MUST_PRINT_SOMETHING, common_native, eq_asname);
            }
          /* There's no special zeropart case here because each returned subvalue is tested in sub gp, if needed */
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
      ssg_valmode_t left_native = sparp_expn_native_valmode (ssg->ssg_sparp, left);
      ssg_valmode_t right_native = sparp_expn_native_valmode (ssg->ssg_sparp, right);
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

void
ssg_print_sparul_run_call (spar_sqlgen_t *ssg, SPART *gp, SPART *tree, int compose_report)
{ /* Very special case. Arguments are texts of queries. */
  int arg_ctr, arg_count = BOX_ELEMENTS (tree->_.funcall.argtrees);
  ssg_puts (" DB.DBA.SPARUL_RUN ( vector (");
  ssg->ssg_indent += 2;
  for (arg_ctr = 0; arg_ctr < arg_count; arg_ctr++)
    {
      SPART *arg = tree->_.funcall.argtrees[arg_ctr];
      if (arg_ctr > 0)
        ssg_putchar (',');
      ssg_newline (0);
      /*ssg_puts (" coalesce ((");*/
      ssg_puts (" (");
      ssg->ssg_indent += 2;
      if (DV_ARRAY_OF_POINTER == DV_TYPE_OF (arg) && SPAR_LIT == arg->type &&
        DV_STRING == DV_TYPE_OF (arg->_.lit.val) )
        ssg_puts (arg->_.lit.val);
      else
        ssg_print_retval_simple_expn (ssg, gp, arg, SSG_VALMODE_SQLVAL, NULL_ASNAME);
      ssg_puts (")");
      /*ssg_puts ("))");*/
      ssg->ssg_indent -= 2;
    }
  ssg_puts (")");
  if (compose_report)
    {
#ifdef NDEBUG
      ssg_puts (", 1");
#else
      ssg_puts (", 1 /* to compose report */");
#endif
    }
  ssg_puts (")");
  ssg->ssg_indent -= 2;

}

void
ssg_print_retval_simple_expn (spar_sqlgen_t *ssg, SPART *gp, SPART *tree, ssg_valmode_t needed, const char *asname)
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

    case BOP_PLUS:	ssg_print_retval_bop_calc_expn (ssg, gp, tree, " ("	, " + ", ")"	, 0, needed); goto print_asname;
    case BOP_MINUS:	ssg_print_retval_bop_calc_expn (ssg, gp, tree, " ("	, " - ", ")"	, 0, needed); goto print_asname;
    case BOP_TIMES:	ssg_print_retval_bop_calc_expn (ssg, gp, tree, " ("	, " * ", ")"	, 0, needed); goto print_asname;
    case BOP_DIV:	ssg_print_retval_bop_calc_expn (ssg, gp, tree, " ("	, " / ", ")"	, 0, needed); goto print_asname;
    case BOP_MOD:	ssg_print_retval_bop_calc_expn (ssg, gp, tree, " mod ("	, ", ", ")"	, 0, needed); goto print_asname;
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
        int bigtext, arg_ctr, arg_count = BOX_ELEMENTS (tree->_.funcall.argtrees);
        xqf_str_parser_desc_t *parser_desc;
	ssg_valmode_t native = sparp_rettype_of_function (ssg->ssg_sparp, tree->_.funcall.qname);
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
#ifdef NDEBUG
                ssg_puts (" __ro2sq (");
#else
                ssg_puts (" __rdf_sqlval_of_obj /*l*/ (");
#endif
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
            const char *cvtname = parser_desc->p_typed_bif_name;
            if (NULL == cvtname)
              cvtname = "__xqf_str_parse";
            ssg_puts (cvtname);
            ssg_puts (" ('");
            ssg_puts (parser_desc->p_name);
            ssg_puts ("'");
            ssg->ssg_indent++;
            for (arg_ctr = 0; arg_ctr < arg_count; arg_ctr++)
              {
                ssg_puts (", ");
                ssg_print_retval_simple_expn (ssg, gp, tree->_.funcall.argtrees[arg_ctr], SSG_VALMODE_SQLVAL, NULL_ASNAME);
              }
            if (1 == arg_count)
              ssg_puts (", 1");
            ssg->ssg_indent--;
            ssg_putchar (')');
            goto print_asname;
          }
        if (!strcmp (tree->_.funcall.qname, "sql:SPARUL_RUN"))
          {
            ssg_print_sparul_run_call (ssg, gp, tree, 1);
            goto print_asname;
          }
        bigtext =
          ((NULL != strstr (tree->_.funcall.qname, "bif:")) ||
           (NULL != strstr (tree->_.funcall.qname, "sql:")) ||
           (arg_count > 3) );
        ssg_prin_function_name (ssg, tree->_.funcall.qname);
        ssg_puts (" (");
        if (tree->_.funcall.agg_mode)
          {
            if (!strcmp (tree->_.funcall.qname, "bif:COUNT") && ((SPART *)((ptrlong)1) == tree->_.funcall.argtrees[0]))
              arg_count = 1; /* Trick to handle SELECT COUNT FROM ... that is translated to SELECT COUNT (1, all vars) */
            if (DISTINCT_L == tree->_.funcall.agg_mode)
              ssg_puts (" DISTINCT");
          }
        ssg->ssg_indent++;
        for (arg_ctr = 0; arg_ctr < arg_count; arg_ctr++)
          {
            ssg_valmode_t argtype = sparp_argtype_of_function (ssg->ssg_sparp, tree->_.funcall.qname, arg_ctr);
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
    case SPAR_GP:
      ssg_print_scalar_expn (ssg, tree, needed, asname);
      return;
    default:
      break;
  }
  spar_sqlprint_error ("ssg_print_retval_simple_expn(): unsupported type of retval expression");
print_asname:
  if (IS_BOX_POINTER (asname))
    {
#ifdef NDEBUG
      ssg_puts (" AS ");
#else
      ssg_puts (" AS /*retsimple*/ ");
#endif
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
#ifndef NDEBUG
  if ((SSG_RETVAL_DIST_SER_LONG & flags) && (gp != ssg->ssg_tree->_.req_top.pattern))
    spar_sqlprint_error ("ssg_" "print_retval_expn(): weird usage of SSG_RETVAL_DIST_SER_LONG");
#endif
  if ((SSG_RETVAL_DIST_SER_LONG & flags) && sparp_retval_should_wrap_distinct (ssg->ssg_sparp, ssg->ssg_tree, ret_column))
    {
      ret_column = spar_make_funcall (ssg->ssg_sparp, 0, "SPECIAL::sql:RDF_DIST_SER_LONG",
        (SPART **) t_list (1, ret_column) );
      var_name = NULL;
    }
  if (NULL == var_name)
    {
      if (SSG_VALMODE_AUTO == needed)
        needed = sparp_expn_native_valmode (ssg->ssg_sparp, ret_column); /* This is a special case of value returned from SPARQL subquery where AUTO valmode is set. */
      if (SSG_VALMODE_AUTO == needed)
        spar_sqlprint_error ("ssg_" "print_retval_expn(): SSG_VALMODE_AUTO for not a variable and no way to find a type");
      if ((NULL_ASNAME == asname) && (flags & SSG_RETVAL_USES_ALIAS))
        {
          char buf[30];
          snprintf (buf, sizeof (buf), "callret-%d", col_idx);
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
        needed = sparp_equiv_native_valmode (ssg->ssg_sparp, auto_valmode_gp, auto_eq);
    }
  if (IS_BOX_POINTER (needed) && (0 == needed->qmfColumnCount))
    {
#ifdef NDEBUG
      ssg_puts (" 1");
#else
      ssg_puts (" 1 /*fake*/");
#endif
      if (NULL != asname)
        {
#ifdef NDEBUG
          ssg_puts (" AS ");
#else
          ssg_puts (" AS /*retexpn*/ ");
#endif
          ssg_prin_id (ssg, asname);
        }
      return;
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

void ssg_print_retval_cols (spar_sqlgen_t *ssg, SPART *tree, SPART **retvals, ccaddr_t selid, const char *deser_name_or_code, int print_asname)
{
  int col_idx;
  DO_BOX_FAST (SPART *, ret_column, col_idx, retvals)
    {
      const char *asname = spar_alias_name_of_ret_column (ret_column);
      if (NULL_ASNAME == asname)
        {
          char buf[30];
          snprintf (buf, sizeof (buf), "callret-%d", col_idx);
          asname = t_box_dv_short_string (buf);
        }
      if (0 < col_idx)
        ssg_puts (", ");
      else
        ssg_putchar (' ');
      if (NULL != selid)
        {
          const char *deser_name = deser_name_or_code;
          if ((NULL != deser_name) && (!IS_BOX_POINTER (deser_name)))
            {
              if ((ptrlong)DISTINCT_L == (ptrlong)deser_name)
                {
                  if (sparp_retval_should_wrap_distinct (ssg->ssg_sparp, tree, ret_column))
                    deser_name = "SPECIAL::sql:RDF_DIST_DESER_LONG";
                  else
                    deser_name = NULL;
                }
              else
                spar_sqlprint_error("ssg" "_print_retval_cols(): bad deser_name_or_code");
            }
          if (NULL != deser_name)
            {
              ssg_prin_function_name (ssg, deser_name);
              ssg_puts (" (");
            }
          ssg_prin_id (ssg, selid);
          ssg_putchar ('.');
          ssg_prin_id (ssg, asname);
          if (NULL != deser_name)
            ssg_putchar (')');
          if (print_asname)
            {
              ssg_puts (" AS ");
              ssg_prin_id (ssg, asname);
            }
        }
      else
        ssg_print_box_as_sql_atom (ssg, asname, 0);
    }
  END_DO_BOX_FAST;
}

void
ssg_print_retval_list (spar_sqlgen_t *ssg, SPART *gp, SPART **retlist, int res_len, int flags, SPART *auto_valmode_gp, ssg_valmode_t needed)
{
  int res_ctr;
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
  if (tree == (box_t)(1)) /* The filter has been disabled because it's printed already */
    return;
  if (spar_filter_is_freetext (tree))
    {
      return;
      /* spar_error (ssg->ssg_sparp, "Unable to generate SQL code for %.100s() special predicate for variable '%.100s', try to rephrase the query",
        tree->_.funcall.qname, tree->_.funcall.argtrees[0]->_.var.vname );*/
    }
  ssg_print_where_or_and (ssg, "filter");
  ssg_print_filter_expn (ssg, tree);
}


void
ssg_print_all_table_fld_restrictions (spar_sqlgen_t *ssg, quad_map_t *qm, caddr_t alias, SPART *triple, int enabled_field_bitmask, int print_outer_filter)
{
  if ((NULL != qm->qmGraphMap) && (enabled_field_bitmask & (1 << SPART_TRIPLE_GRAPH_IDX)))
    ssg_print_fld_restrictions (ssg, qm, qm->qmGraphMap, alias, triple, SPART_TRIPLE_GRAPH_IDX, print_outer_filter);
  if ((NULL != qm->qmSubjectMap) && (enabled_field_bitmask & (1 << SPART_TRIPLE_SUBJECT_IDX)))
    ssg_print_fld_restrictions (ssg, qm, qm->qmSubjectMap, alias, triple, SPART_TRIPLE_SUBJECT_IDX, print_outer_filter);
  if ((NULL != qm->qmPredicateMap) && (enabled_field_bitmask & (1 << SPART_TRIPLE_PREDICATE_IDX)))
    ssg_print_fld_restrictions (ssg, qm, qm->qmPredicateMap, alias, triple, SPART_TRIPLE_PREDICATE_IDX, print_outer_filter);
  if ((NULL != qm->qmObjectMap) && (enabled_field_bitmask & (1 << SPART_TRIPLE_OBJECT_IDX)))
    ssg_print_fld_restrictions (ssg, qm, qm->qmObjectMap, alias, triple, SPART_TRIPLE_OBJECT_IDX, print_outer_filter);
}


static void
ssg_collect_aliases_tables_and_conds (
  qm_atable_array_t qmatables, ccaddr_t *qmconds,
  dk_set_t *aliases_ptr, dk_set_t *tables_ptr, dk_set_t *conds_ptr )
{
  int ata_ctr, cond_ctr;
  DO_BOX_FAST (qm_atable_t *, ata, ata_ctr, qmatables)
    {
      if (0 <= dk_set_position_of_string (aliases_ptr[0], ata->qmvaAlias))
        continue;
      t_set_push (aliases_ptr, (caddr_t)(ata->qmvaAlias));
      t_set_push (tables_ptr, (caddr_t)(ata->qmvaTableName));
    }
  END_DO_BOX_FAST;
  DO_BOX_FAST (caddr_t, cond, cond_ctr, qmconds)
    {
      if (0 <= dk_set_position_of_string (conds_ptr[0], cond))
        continue;
      t_set_push (conds_ptr, cond);
    }
  END_DO_BOX_FAST;
}

static void
ssg_print_fake_self_join_subexp (spar_sqlgen_t *ssg, SPART *gp, SPART ***tree_sets, int tree_set_count, int tree_count, int inside_breakup, int fld_restrictions_bitmask)
{
  caddr_t tabid = tree_sets[0][0]->_.triple.tabid;
  caddr_t sub_tabid = t_box_sprintf (100, "%s-int", tabid);
  int save_where_l_printed;
  const char *save_where_l_text;
  int tree_set_ctr, tree_ctr, fld_ctr;
  dk_set_t colcodes = NULL;
  dk_set_t ata_aliases = NULL;
  dk_set_t ata_tables = NULL;
  dk_set_t queued_row_filters = NULL;
  dk_set_t printed_row_filters = NULL;
  s_node_t *ata_tables_tail;
  ssg->ssg_indent++;
  for (tree_set_ctr = 0; tree_set_ctr < tree_set_count; tree_set_ctr++)
  for (tree_ctr = 0; tree_ctr < tree_count; tree_ctr++)
    {
      SPART *tree = tree_sets[tree_set_ctr][tree_ctr];
      triple_case_t **tc_list = tree->_.triple.tc_list;
      quad_map_t *qm = tc_list[0]->tc_qm;
      for (fld_ctr = 0; fld_ctr < SPART_TRIPLE_FIELDS_COUNT; fld_ctr++)
        {
          qm_format_t *fmt;
          qm_value_t *qmv;
          SPART *var;
          ccaddr_t asname = NULL_ASNAME;
          ccaddr_t colcode;
          fmt = tree->_.triple.native_formats[fld_ctr];
          sparp_jso_validate_format (ssg->ssg_sparp, fmt);
          qmv = JSO_FIELD_ACCESS(qm_value_t *, qm, qm_field_map_offsets[fld_ctr])[0];
          if (NULL == qmv)
            continue;
          var = tree->_.triple.tr_fields [fld_ctr];
          ssg_collect_aliases_tables_and_conds (qmv->qmvATables, qmv->qmvConds,
            &ata_aliases, &ata_tables, &queued_row_filters );
          if (0 == BOX_ELEMENTS_0 (qmv->qmvColumns))
            continue;
          asname = ssg_triple_retval_alias (ssg, tree, fld_ctr, 0, qmv->qmvColumns[0]->qmvcColumnName);
          colcode = asname;
          if (0 <= dk_set_position_of_string (colcodes, colcode))
            continue;
          if (NULL != colcodes)
            ssg_puts (", ");
          else
            ssg_puts (" (SELECT ");
          ssg_print_tr_field_expn (ssg, qmv, sub_tabid, fmt, asname);
          t_set_push (&colcodes, (caddr_t)colcode);
        }
      if (NULL != tree->_.triple.options)
        {
          int optctr;
          for (optctr = BOX_ELEMENTS (tree->_.triple.options); optctr >= 0; optctr -= 2)
            {
              SPART *val = tree->_.triple.options[optctr+1];
              switch ((ptrlong)(tree->_.triple.options[optctr]))
                {
                case OFFBAND_L: case SCORE_L:
                  if (NULL != colcodes)
                    ssg_puts (", ");
                  else
                    ssg_puts (" (SELECT ");
                  ssg_prin_id (ssg, val->_.var.vname);
                }
            }
        }
      ssg_collect_aliases_tables_and_conds (qm->qmATables, qm->qmConds,
        &ata_aliases, &ata_tables, &queued_row_filters );
      if (tree->_.triple.ft_type)
        {
          qm_ftext_t *qmft;
          qm_atable_t *ft_atable = (qm_atable_t *)t_alloc_box (sizeof (qm_atable_t), DV_ARRAY_OF_POINTER);
          qm_atable_t **ft_atables;
          if (NULL == qm->qmObjectMap)
            {
              tree->_.triple.ft_type = -1;
              goto ft_is_scrap; /*spar_sqlprint_error ("ssg_" "print_fake_self_join_subexp(): NULL == qm->qmObjectMap");*/
            }
          qmft = qm->qmObjectMap->qmvFText;
          if (NULL == qmft)
            {
              tree->_.triple.ft_type = -1;
              goto ft_is_scrap; /*spar_sqlprint_error ("ssg_" "print_fake_self_join_subexp(): NULL == qmft");*/
            }
          ft_atable->qmvaAlias = qmft->qmvftAlias;
	  ft_atable->qmvaTableName = qmft->qmvftTableName;
          if (NULL != qmft->qmvftAuxTableName)
            {
              qm_atable_t *aux_atable = (qm_atable_t *)t_alloc_box (sizeof (qm_atable_t), DV_ARRAY_OF_POINTER);
              aux_atable->qmvaAlias = qmft->qmvftAuxAlias;
              aux_atable->qmvaTableName = qmft->qmvftAuxTableName;
              ft_atables = (qm_atable_t **)t_list (2, aux_atable, ft_atable);
            }
          else
            ft_atables = (qm_atable_t **)t_list (1, ft_atable);
          ssg_collect_aliases_tables_and_conds (
            ft_atables,
            qmft->qmvftConds,
            &ata_aliases, &ata_tables, &queued_row_filters );
        }
ft_is_scrap: ;
    }
  if (NULL == colcodes)
    { /* This is a special case of quad map with four constants and no one quad map value. */
      ssg_puts (" DB.DBA.SYS_FAKE_1 AS ");
      ssg_prin_id (ssg, tabid);
      ssg->ssg_indent--;
      return;
    }
  ssg_puts (" FROM ");
  ata_tables_tail = ata_tables;
  if (NULL == ata_aliases)
    {
      caddr_t atable = t_box_dv_uname_string ("DB.DBA.RDF_QUAD");
      ssg_puts (atable);
      if (NULL != ssg->ssg_sc->sc_cc)
        qr_uses_table (ssg->ssg_sc->sc_cc->cc_super_cc->cc_query, atable);
      ssg_puts (" AS ");
      ssg_prin_id (ssg, sub_tabid);
      goto from_printed;
    }
  DO_SET (caddr_t, alias, &(ata_aliases))
    {
      caddr_t atable = ata_tables_tail->data;
      caddr_t full_alias;
      if (('\0' != alias[0]) && ('!' != alias[0]))
        full_alias = t_box_sprintf (210, "%.100s~%.100s", sub_tabid, alias);
      else
        full_alias = sub_tabid;
      if (ata_tables_tail != ata_tables)
        ssg_puts (", ");
      ata_tables_tail = ata_tables_tail->next;
      ssg_puts (atable);
      if (NULL != ssg->ssg_sc->sc_cc)
        qr_uses_table (ssg->ssg_sc->sc_cc->cc_super_cc->cc_query, atable);
      ssg_puts (" AS ");
      ssg_prin_id (ssg, full_alias);
      if (NULL == ata_tables_tail)
        { /* Last item of ata_tables corresponds to the first table of the first tree */
          SPART **opts = sparp_get_options_of_tree (ssg->ssg_sparp, tree_sets[0][0]);
          if (NULL != opts)
            {
              caddr_t val = (caddr_t)sparp_get_option (ssg->ssg_sparp, opts, TABLE_OPTION_L);
              if (NULL != val)
                {
                  ssg_puts (" TABLE OPTION (");
                  ssg_puts (val);
                  ssg_puts (")");
                }
            }
        }
    }
  END_DO_SET()

from_printed:
  save_where_l_printed = ssg->ssg_where_l_printed;
  save_where_l_text = ssg->ssg_where_l_text;
  ssg->ssg_where_l_printed = 0;
  ssg->ssg_where_l_text = " WHERE ";
  DO_SET (caddr_t, cond, &queued_row_filters)
    {
      ssg_print_where_or_and (ssg, "inter-alias join cond");
      ssg_print_tmpl (ssg, NULL, cond, sub_tabid, NULL, NULL, NULL_ASNAME);
    }
  END_DO_SET()
  printed_row_filters = queued_row_filters;
  for (tree_set_ctr = 0; tree_set_ctr < tree_set_count; tree_set_ctr++)
  for (tree_ctr = 0; tree_ctr < tree_count; tree_ctr++)
    {
      int condctr;
      SPART *tree = tree_sets[tree_set_ctr][tree_ctr];
      triple_case_t **tc_list = tree->_.triple.tc_list;
      quad_map_t *qm = tc_list[0]->tc_qm;
      ccaddr_t *conds = qm->qmConds;
      ccaddr_t rowfilter = qm->qmTableRowFilter;
      if (0 < tree->_.triple.ft_type)
        {
          caddr_t var_name = tree->_.triple.tr_object->_.var.vname;
          SPART *ft_pred = NULL, **args, *ft_arg1;
          qm_ftext_t *qmft = qm->qmObjectMap->qmvFText;
          caddr_t ft_alias = t_box_sprintf (210, "%.100s~%.100s", sub_tabid, qmft->qmvftAlias);
          int ctr, argctr, argcount;
          DO_BOX_FAST (SPART *, filt, ctr, gp->_.gp.filters)
            {
              if (!spar_filter_is_freetext (filt))
                continue;
              if (strcmp (var_name, filt->_.funcall.argtrees[0]->_.var.vname))
                continue;
              if (NULL == ft_pred)
                {
                  ft_pred = filt;
                  gp->_.gp.filters[ctr] = (box_t)(1);
                }
              else
                spar_error (ssg->ssg_sparp, "Too many %.100s() special predicates for variable %.100s, can not build an SQL query",
                  filt->_.funcall.qname, var_name );
            }
          END_DO_BOX_FAST;
          if (NULL == ft_pred)
            spar_sqlprint_error ("ssg_" "print_fake_self_join_subexp(): NULL == ft_predicate");
          args = ft_pred->_.funcall.argtrees;
          ft_arg1 = args[1];
          argcount = BOX_ELEMENTS (args);
          if ((SPAR_FT_CONTAINS == tree->_.triple.ft_type) &&
            !strcmp ("DB.DBA.RDF_QUAD", tree->_.triple.tc_list[0]->tc_qm->qmTableName))
            {
              SPART *g = tree->_.triple.tr_graph;
              if (SPAR_IS_LIT_OR_QNAME (g) ||
                (SPAR_IS_BLANK_OR_VAR (g) &&
                  ((SPART_VARR_FIXED | SPART_VARR_GLOBAL /* Should I add SPART_VARR_EXTERNAL here ? */) &
                    g->_.var.rvr.rvrRestrictions) ) )
                {
                  ft_arg1 = spar_make_funcall (ssg->ssg_sparp, 0, "sql:RDF_OBJ_PATCH_CONTAINS_BY_GRAPH",
                    (SPART **)t_list (2, ft_arg1, g) );
                  goto ft_arg1_is_patched; /* see below */
                }
              else if (SPAR_IS_BLANK_OR_VAR (g))
                {
                  dk_set_t chk_graphs = NULL;
                  dk_set_t good_expns = NULL;
                  /* dk_set_t bad_expns = NULL; */
                  int good_len /*, bad_len*/;
                  if (SPART_IS_DEFAULT_GRAPH_BLANK(g))
                    {
                      if (ssg->ssg_sparp->sparp_env->spare_named_graphs_listed)
                        chk_graphs = ssg->ssg_sparp->sparp_env->spare_default_graphs;
                      else chk_graphs = NULL;
                    }
                  else
                    chk_graphs = ssg->ssg_sparp->sparp_env->spare_named_graphs;
                  DO_SET (SPART *,src, &(chk_graphs))
                    {
                      if (!((SPART_GRAPH_NOT_FROM == src->_.graph.subtype) || (SPART_GRAPH_NOT_NAMED == src->_.graph.subtype)))
                        t_set_push (&good_expns, src->_.graph.expn);
                      /* else
                        t_set_push (&bad_expns, src->_.graph.expn); */
                    }
                  END_DO_SET()
                  good_len = dk_set_length (good_expns);
                  /*bad_len = dk_set_length (bad_expns);*/
                  if ((0 < good_len) && (16 > good_len) /*&& (4 < bad_len)*/)
                    {
                      ft_arg1 = spar_make_funcall (ssg->ssg_sparp, 0, "sql:RDF_OBJ_PATCH_CONTAINS_BY_MANY_GRAPHS",
                        (SPART **)t_list (2, ft_arg1,
                        spar_make_funcall (ssg->ssg_sparp, 0, "bif:vector",
                          (SPART **)t_list_to_array (good_expns) ) ) );
                      goto ft_arg1_is_patched; /* see below */
                    }
                }
            }
ft_arg1_is_patched:
          ssg_print_where_or_and (ssg, "freetext predicate");
          ssg_putchar (' ');
          ssg_puts (ft_pred->_.funcall.qname + 4);
          ssg_puts ("(");
          ssg_prin_id (ssg, ft_alias);
          ssg_puts (".");
          ssg_prin_id (ssg, qmft->qmvftColumnName);
          ssg_puts (", ");
          ssg_print_scalar_expn (ssg, ft_arg1, SSG_VALMODE_SQLVAL, NULL);
          for (argctr = 2; argctr < argcount; argctr += 2)
            {
              switch ((ptrlong)(args[argctr]))
                {
                case OFFBAND_L: ssg_puts (", OFFBAND, "); ssg_prin_id (ssg, args[argctr+1]->_.var.vname); break;
                case SCORE_L: ssg_puts (", SCORE, "); ssg_prin_id (ssg, args[argctr+1]->_.var.vname); break;
                default: spar_internal_error (ssg->ssg_sparp, "Unsupported option in printing freetext predicate"); break;
                }
            }
          ssg_puts (")");
        }
      else if (0 > tree->_.triple.ft_type)
        {
          ssg_print_where_or_and (ssg, "invalidated freetext predicate");
          ssg_puts ("(1 = 2)");
        }
      if ((0 == tree_ctr) || !inside_breakup)
        ssg_print_all_table_fld_restrictions (ssg, qm, sub_tabid, tree, (inside_breakup ? fld_restrictions_bitmask : ~0), 0);
      DO_BOX_FAST (caddr_t, c, condctr, conds)
        {
          if (0 > dk_set_position_of_string (printed_row_filters, c))
            {
              ssg_print_where_or_and (ssg, "condition of quad map");
              ssg_print_tmpl (ssg, NULL, c, sub_tabid, NULL, NULL, NULL_ASNAME);
              t_set_push (&printed_row_filters, c);
            }
        }
      END_DO_BOX_FAST;
      if (NULL != rowfilter)
        {
          if (0 > dk_set_position_of_string (printed_row_filters, rowfilter))
            {
              ssg_print_where_or_and (ssg, "(obsolete) row filter of quad map");
              ssg_print_tmpl (ssg, NULL, rowfilter, sub_tabid, NULL, NULL, NULL_ASNAME);
              t_set_push (&printed_row_filters, (caddr_t)rowfilter);
            }
        }
     }
  ssg->ssg_where_l_printed = save_where_l_printed;
  ssg->ssg_where_l_text = save_where_l_text;
  ssg_puts (") AS ");
  ssg_prin_id (ssg, tabid);
  ssg->ssg_indent--;
}

static void
ssg_print_triple_table_exp (spar_sqlgen_t *ssg, SPART *gp, SPART **trees, int tree_count, int pass)
{
  SPART *tree = trees[0];
  caddr_t tabid = tree->_.triple.tabid;
  triple_case_t **tc_list = tree->_.triple.tc_list;
  quad_map_t *qm;
  dk_set_t common_tblopts = ssg->ssg_sparp->sparp_env->spare_common_sql_table_options;
  dk_set_t tblopts = common_tblopts;
  caddr_t active_inference;
#ifdef DEBUG
  if (1 != BOX_ELEMENTS_0 (tc_list))
    spar_internal_error (ssg->ssg_sparp, "ssg_" "print_table_exp(): qm_list does not contain exactly one qm");
#endif
  qm = tc_list[0]->tc_qm;
  if (( 1 != tree_count) ||		/* IF fake self-join on pk or */
    (NULL == qm->qmTableName) ||	/* single table of non-plain triples or */
    (0 != tree->_.triple.ft_type) ||	/* triple with free-text predicate or */
    (NULL == strstr (qm->qmTableName, "DB.DBA.RDF_QUAD")) )	/* something otherwise unusual */
    {
      if (1 == pass)
        ssg_print_fake_self_join_subexp (ssg, gp, &trees, 1, tree_count, 0 /* = not iside breakup */, ~0);
      /* if (2 == pass) then there's nothing to do, all filters reside in the subquery and printed by pass 1 */
      return;
    }
/* The rest of function is for single table of plain triples */
  ssg_qr_uses_jso (ssg, (ccaddr_t)qm, NULL);
  if (1 == pass)
    {
      int has_table_options = 0;
#define SAME_AS__VARIANT_COUNT 6
      SPART **opts = NULL, *same_as__lists [SAME_AS__VARIANT_COUNT];
static ptrlong same_as__keys [SAME_AS__VARIANT_COUNT] = {IFP_L, SAME_AS_L, SAME_AS_O_L, SAME_AS_P_L, SAME_AS_S_L, SAME_AS_S_O_L};
static const char *same_as__names [SAME_AS__VARIANT_COUNT] = {"IFP", "SAME_AS", "SAME_AS_O", "SAME_AS_P", "SAME_AS_S", "SAME_AS_S_O"};
      ssg_putchar (' ');
      ssg_puts (qm->qmTableName);
      ssg_qr_uses_table (ssg, qm->qmTableName);
      ssg_puts (" AS ");
      ssg_prin_id (ssg, tabid);
      active_inference = ssg->ssg_sparp->sparp_env->spare_inference_name;
      opts = sparp_get_options_of_tree (ssg->ssg_sparp, tree);
      if (NULL != opts)
        {
          SPART *val;
          int sav_ctr;
          caddr_t local_inference = (caddr_t)sparp_get_option (ssg->ssg_sparp, opts, INFERENCE_L);
          if (NULL != local_inference)
            active_inference = local_inference;
          for (sav_ctr = SAME_AS__VARIANT_COUNT; sav_ctr--; /* no step */)
            {
              val = same_as__lists [sav_ctr] = sparp_get_option (ssg->ssg_sparp, opts, same_as__keys[sav_ctr]);
              if (NULL != val)
                has_table_options = 1;
            }
          val = sparp_get_option (ssg->ssg_sparp, opts, TABLE_OPTION_L);
          if (NULL != val)
            t_set_push (&tblopts, val);
        }
      if (NULL != active_inference)
        t_set_push (&tblopts, t_box_sprintf (200, "WITH '%.100s'", active_inference));
      if (NULL != tblopts)
        has_table_options = 1;
      if (has_table_options)
        {
          int needs_comma = 0;
          ssg_puts (" TABLE OPTION (");
          if (NULL != tblopts)
            {
              ssg_prin_option_commalist (ssg, tblopts, 0);
              needs_comma = 1;
            }
          if (NULL != opts)
            {
              int sav_ctr;
              for (sav_ctr = SAME_AS__VARIANT_COUNT; sav_ctr--; /* no step */)
                {
                  SPART *val = same_as__lists [sav_ctr];
                  if (NULL == val)
                    continue;
                  if (needs_comma)
                    ssg_putchar (',');
                  ssg_puts (same_as__names [sav_ctr]);
                  if (IS_BOX_POINTER (val))
                    {
                      ssg_puts (" vector (");
                      ssg_print_scalar_expn (ssg, val, SSG_VALMODE_LONG, NULL_ASNAME);
                      ssg_puts (")");
                    }
                  needs_comma = 1;
                }
            }
          ssg_puts (") ");
        }
    }
  if (2 == pass)
    ssg_print_all_table_fld_restrictions (ssg, qm, tree->_.triple.tabid, tree, ~0, 0);
}

void
ssg_print_subquery_table_exp (spar_sqlgen_t *ssg, SPART *wrapping_gp)
{
  sparp_t *sub_sparp = (sparp_t *)t_box_copy ((caddr_t)(ssg->ssg_sparp));
  spar_sqlgen_t subq_ssg;
  sql_comp_t subq_sc;
#ifdef NDEBUG
  ssg_puts (" (");
#else
  ssg_puts (" ( /* subq begin */ ");
#endif
  ssg->ssg_indent++;
  ssg_newline (1);
  memset (&subq_ssg, 0, sizeof (spar_sqlgen_t));
  subq_ssg.ssg_parent_ssg = ssg;
  subq_ssg.ssg_sparp = sub_sparp;
  subq_ssg.ssg_tree = sub_sparp->sparp_expr = wrapping_gp->_.gp.subquery;
  subq_ssg.ssg_wrapping_gp = wrapping_gp;
  sub_sparp->sparp_parent_sparp = NULL; /* not a scalar subquery -- no searches in surrounding query */
  sub_sparp->sparp_env = wrapping_gp->_.gp.subquery->_.req_top.shared_spare;
  if (NULL != ssg->ssg_sc)
    subq_ssg.ssg_sc = ssg->ssg_sc;
  else
    {
      memset (&subq_sc, 0, sizeof (sql_comp_t));
      subq_sc.sc_client = sub_sparp->sparp_sparqre->sparqre_cli;
      subq_ssg.ssg_sc = &subq_sc;
    }
  subq_ssg.ssg_sources = subq_ssg.ssg_tree->_.req_top.sources;
  subq_ssg.ssg_out = ssg->ssg_out;
  subq_ssg.ssg_indent = ssg->ssg_indent;
  if ((NULL != wrapping_gp) && (NULL != wrapping_gp->_.gp.options))
    sparp_set_valmodes_of_t_inouts (ssg->ssg_sparp, sub_sparp, wrapping_gp);
  ssg_make_sql_query_text (&subq_ssg);
  ssg_newline (1);
#ifdef NDEBUG
  ssg_puts (" ) AS ");
#else
  ssg_puts (" /* subq end */ ) AS ");
#endif
  ssg->ssg_indent--;
  ssg_prin_id (ssg, wrapping_gp->_.gp.selid);
}

void
ssg_print_scalar_subquery_exp (spar_sqlgen_t *ssg, SPART *sub_req_top, SPART *wrapping_gp, ssg_valmode_t needed)
{
  sparp_t *sub_sparp = (sparp_t *)t_box_copy ((caddr_t)(ssg->ssg_sparp));
  spar_sqlgen_t subq_ssg;
  sql_comp_t subq_sc;
#ifdef NDEBUG
  ssg_puts (" ( ");
#else
  ssg_puts (" ( /* scalar subq begin */ ");
#endif
  ssg->ssg_indent++;
  ssg_newline (1);
  memset (&subq_ssg, 0, sizeof (spar_sqlgen_t));
  subq_ssg.ssg_sparp = sub_sparp;
  subq_ssg.ssg_tree = sub_sparp->sparp_expr = wrapping_gp->_.gp.subquery;
  sub_sparp->sparp_parent_sparp = ssg->ssg_sparp;
  sub_sparp->sparp_env = wrapping_gp->_.gp.subquery->_.req_top.shared_spare;
  if ((SSG_VALMODE_LONG == needed) || (SSG_VALMODE_AUTO == needed))
    sub_sparp->sparp_env->spare_output_valmode_name = t_box_dv_short_string ("LONG");
  else if (SSG_VALMODE_SQLVAL == needed)
    sub_sparp->sparp_env->spare_output_valmode_name = NULL;
  else
    spar_internal_error (ssg->ssg_sparp, "ssg_" "print_scalar_subquery_exp: unsupported valmode");
  if (NULL != ssg->ssg_sc)
    subq_ssg.ssg_sc = ssg->ssg_sc;
  else
    {
      memset (&subq_sc, 0, sizeof (sql_comp_t));
      subq_sc.sc_client = sub_sparp->sparp_sparqre->sparqre_cli;
      subq_ssg.ssg_sc = &subq_sc;
    }
  subq_ssg.ssg_sources = subq_ssg.ssg_tree->_.req_top.sources;
  subq_ssg.ssg_out = ssg->ssg_out;
  subq_ssg.ssg_indent = ssg->ssg_indent;
  ssg_make_sql_query_text (&subq_ssg);
  ssg_newline (1);
#ifdef NDEBUG
  ssg_putchar (')');
#else
  ssg_puts (" /* scalar subq end */ )");
#endif
  ssg->ssg_indent--;
}

void
ssg_print_table_exp (spar_sqlgen_t *ssg, SPART *gp, SPART **trees, int tree_count, int pass)
{
  SPART *tree;
  if (0 == tree_count)
    {
      if (1 == pass)
        {
          char buf[200];
          snprintf (buf, sizeof (buf), " (select top 1 1 as __fake_table_col_%d from DB.DBA.RDF_QUAD) as __fake_table_%d",
            ssg->ssg_sparp->sparp_unictr, ssg->ssg_sparp->sparp_unictr );
          ssg->ssg_sparp->sparp_unictr++;
          ssg_puts (buf);
        }
      return;
    }
  tree = trees[0];
  switch (SPART_TYPE(tree))
    {
    case SPAR_TRIPLE:
      ssg_print_triple_table_exp (ssg, gp, trees, tree_count, pass);
      break;
    case SPAR_GP:
      {
        if (1 == pass)
          {
            int eq_ctr;
            dk_set_t retvals_set = NULL;
            caddr_t *retlist;
            if (SELECT_L == tree->_.gp.subtype)
              {
                ssg_print_subquery_table_exp (ssg, tree);
                break;
              }
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
    default: spar_sqlprint_error ("ssg_" "print_table_exp(): unsupported type of tree");
    }
}

void
ssg_print_breakup_in_union (spar_sqlgen_t *ssg, SPART *gp, SPART **retlist, int head_flags, int retval_flags, ssg_valmode_t needed, int first_mcase_idx, int breakup_shift)
{
  SPART *first_mcase = gp->_.gp.members [first_mcase_idx];
  SPART **first_mcase_triples = first_mcase->_.gp.members;
  int left_tc, tc, triples_count = BOX_ELEMENTS (first_mcase_triples), selected_triples_count;
  SPART ***all_triples_of_mcases = (SPART ***)t_alloc (triples_count * sizeof (SPART **));
  SPART ***selected_triples_of_mcases = (SPART ***)t_alloc (triples_count * sizeof (SPART **));
  int breakup_ctr, equiv_ctr, filter_ctr;
  int *common_fld_restrictions_bitmasks = (int *)t_alloc (triples_count * sizeof(int));
  int *leftmost_tc_of_tabid_reuses = (int *)t_alloc (triples_count * sizeof(int));
  int save_where_l_printed;
  const char *save_where_l_text;
#ifdef DEBUG
  if (SPAR_GP != SPART_TYPE (first_mcase))
    spar_internal_error (ssg->ssg_sparp, "ssg_" "print_breakup(): the member is not a SPAR_GP");
#endif

  for (tc = triples_count; tc--; /* no step */)
    {
      common_fld_restrictions_bitmasks[tc] = ~0;
      all_triples_of_mcases[tc] = (SPART **)t_alloc ((1 + breakup_shift) * sizeof (SPART *));
      leftmost_tc_of_tabid_reuses[tc] = -1;
    }
  for (breakup_ctr = 0; breakup_ctr <= /* not '<' */ breakup_shift; breakup_ctr++)
    {
      SPART *mcase = gp->_.gp.members [first_mcase_idx + breakup_ctr];
      for (tc = 0; tc < triples_count; tc++)
        {
          SPART *mcase_triple = mcase->_.gp.members [tc];
          all_triples_of_mcases[tc][breakup_ctr] = mcase_triple;
        }
    }
  for (left_tc = 0; left_tc < triples_count; left_tc++)
    {
      caddr_t left_tc_tabid;
      if (0 <= leftmost_tc_of_tabid_reuses[left_tc])
        continue; /* nothing to do because it is set already */
      leftmost_tc_of_tabid_reuses[left_tc] = left_tc; /* This one is the leftmost of many dupe tabids */
      left_tc_tabid = all_triples_of_mcases[left_tc][0]->_.triple.tabid;
      for (tc = left_tc+1; tc < triples_count; tc++)
        {
          caddr_t tc_tabid = all_triples_of_mcases[tc][0]->_.triple.tabid;
          if (!strcmp (left_tc_tabid, tc_tabid))
            leftmost_tc_of_tabid_reuses[tc] = left_tc;
        }
    }
  for (tc = triples_count; tc--; /* no step */)
    {
      quad_map_t *first_mcase_qm = first_mcase_triples[tc]->_.triple.tc_list[0]->tc_qm;
      int leftmost_tc = leftmost_tc_of_tabid_reuses[tc];
      for (breakup_ctr = 1; breakup_ctr <= /* not '<' */ breakup_shift; breakup_ctr++)
        {
          int fld_ctr;
          SPART *mcase = gp->_.gp.members [first_mcase_idx + breakup_ctr];
          SPART *mcase_triple = mcase->_.gp.members [tc];
          quad_map_t *mcase_qm = mcase_triple->_.triple.tc_list[0]->tc_qm;
          for (fld_ctr = 0; fld_ctr < SPART_TRIPLE_FIELDS_COUNT; fld_ctr++)
            {
              qm_value_t *first_mcase_qmv, *mcase_qmv;
              SPART *first_mcase_fld, *mcase_fld;
              if (! (common_fld_restrictions_bitmasks[leftmost_tc] & (1 << fld_ctr)))
                continue; /* It's not common already, no need to check */
              if (SPARP_FIELD_CONST_OF_QM (mcase_qm, fld_ctr) !=
                  SPARP_FIELD_CONST_OF_QM (first_mcase_qm, fld_ctr) )
                goto fld_restrictions_may_vary; /* see below */
              first_mcase_qmv = SPARP_FIELD_QMV_OF_QM (first_mcase_qm, fld_ctr);
              mcase_qmv = SPARP_FIELD_QMV_OF_QM (mcase_qm, fld_ctr);
              if (first_mcase_qmv != mcase_qmv)
                {
                  if (!((NULL != first_mcase_qmv) && (NULL != mcase_qmv))) /* One is mapping and one is const */
                    goto fld_restrictions_may_vary; /* see below */
                  if (first_mcase_qmv->qmvFormat != mcase_qmv->qmvFormat)
                    goto fld_restrictions_may_vary; /* see below */
                  if (first_mcase_qmv->qmvRange.rvrRestrictions != mcase_qmv->qmvRange.rvrRestrictions)
                    goto fld_restrictions_may_vary; /* see below */
                  if (!sparp_expns_are_equal (ssg->ssg_sparp, (SPART *)(first_mcase_qmv->qmvRange.rvrFixedValue), (SPART *)(mcase_qmv->qmvRange.rvrFixedValue)))
                    goto fld_restrictions_may_vary; /* see below */
                  if (!sparp_expns_are_equal (ssg->ssg_sparp, (SPART *)(first_mcase_qmv->qmvRange.rvrDatatype), (SPART *)(mcase_qmv->qmvRange.rvrDatatype)))
                    goto fld_restrictions_may_vary; /* see below */
                  if (!sparp_expns_are_equal (ssg->ssg_sparp, (SPART *)(first_mcase_qmv->qmvRange.rvrLanguage), (SPART *)(mcase_qmv->qmvRange.rvrLanguage)))
                    goto fld_restrictions_may_vary; /* see below */
                }
              first_mcase_fld = first_mcase_triples[tc]->_.triple.tr_fields[fld_ctr];
              mcase_fld = mcase_triple->_.triple.tr_fields[fld_ctr];
              if (!sparp_expns_are_equal (ssg->ssg_sparp, first_mcase_fld, mcase_fld))
                goto fld_restrictions_may_vary; /* see below */
              /* Both QMVs and triple field expressions match,
thus field restrictions stay 'common' for the given \c fld_ctr in all triples from \c first_mcase_triple to the current \c mcase_triple
No changes, just continue. */
              continue;

fld_restrictions_may_vary:
              common_fld_restrictions_bitmasks[leftmost_tc] &= ~(1 << fld_ctr);
            }
        }
    }
  ssg_puts (" * FROM (SELECT BREAKUP");
  for (breakup_ctr = 0; breakup_ctr <= /* not '<' */ breakup_shift; breakup_ctr++)
    {
      SPART *mcase = gp->_.gp.members [first_mcase_idx + breakup_ctr];
      int rflags = retval_flags;
      if (0 == breakup_ctr)
        rflags |= SSG_RETVAL_USES_ALIAS;
      ssg_newline (0);
      ssg_puts ("(");
      ssg->ssg_indent++;
      for (tc = 0; tc < triples_count; tc++)
        {
          SPART *mcase_triple = mcase->_.gp.members [tc];
          all_triples_of_mcases[tc][breakup_ctr] = mcase_triple;
        }
      ssg_print_retval_list (ssg, mcase, retlist, BOX_ELEMENTS_INT (retlist), rflags, gp, needed);
      save_where_l_printed = ssg->ssg_where_l_printed;
      save_where_l_text = ssg->ssg_where_l_text;
      ssg->ssg_where_l_printed = 0;
      ssg->ssg_where_l_text = "\bWHERE";
      ssg->ssg_indent++;
      DO_BOX_FAST (SPART *, filter, filter_ctr, mcase->_.gp.filters)
        {
          ssg_print_filter (ssg, filter);
        }
      END_DO_BOX_FAST;
      ssg_print_table_exp (ssg, mcase, mcase->_.gp.members, triples_count, 2); /* PASS 2, printing what's in WHERE */
      for (tc = triples_count; tc--; /* no step */)
        {
          SPART *mcase_triple = mcase->_.gp.members [tc];
          int leftmost_tc = leftmost_tc_of_tabid_reuses[tc];
          ssg_print_all_table_fld_restrictions (ssg, mcase_triple->_.triple.tc_list[0]->tc_qm, mcase_triple->_.triple.tabid, mcase_triple, ~(common_fld_restrictions_bitmasks[leftmost_tc]), 1);
        }
      ssg->ssg_where_l_printed = save_where_l_printed;
      ssg->ssg_where_l_text = save_where_l_text;
      ssg->ssg_indent--;
      ssg->ssg_indent--;
      ssg_puts (")");
    }
  ssg_newline (0);
  ssg_puts ("FROM");
  ssg->ssg_indent++;
  for (left_tc = 0; left_tc < triples_count; left_tc++)
    {
      if (left_tc != leftmost_tc_of_tabid_reuses[left_tc])
        continue;
      if (0 != left_tc)
        {
#ifdef NDEBUG
          ssg_putchar (',');
#else
          ssg_puts (", /* table list of next triple starts here */ ");
#endif
          ssg_newline (0);
        }
      selected_triples_count = 0;
      for (tc = left_tc; tc < triples_count; tc++)
        {
          if (left_tc != leftmost_tc_of_tabid_reuses[tc])
            continue;
          selected_triples_of_mcases [selected_triples_count++] = all_triples_of_mcases[tc];
        }
      ssg_print_fake_self_join_subexp (ssg, first_mcase, selected_triples_of_mcases, selected_triples_count, 1 + breakup_shift, 1 /* = inside breakup */, common_fld_restrictions_bitmasks[left_tc]);
    }
  ssg->ssg_indent--;
  save_where_l_printed = ssg->ssg_where_l_printed;
  save_where_l_text = ssg->ssg_where_l_text;
  ssg->ssg_where_l_printed = 0;
  ssg->ssg_where_l_text = "\bWHERE";
  ssg->ssg_indent++;
  for (equiv_ctr = 0; equiv_ctr < first_mcase->_.gp.equiv_count; equiv_ctr++)
    {
      int eq_idx = first_mcase->_.gp.equiv_indexes[equiv_ctr];
      sparp_equiv_t *eq = ssg->ssg_equivs[eq_idx];
      /* ssg_puts (t_box_sprintf (100, "/" "* eq = %d *" "/", eq_idx)); */
      ssg_print_equivalences (ssg, first_mcase, eq, NULL, NULL);
    }
  ssg->ssg_where_l_printed = save_where_l_printed;
  ssg->ssg_where_l_text = save_where_l_text;
  ssg->ssg_indent--;
  ssg_puts (") AS ");
  ssg_prin_id (ssg, first_mcase->_.gp.selid);
}

void
ssg_print_union (spar_sqlgen_t *ssg, SPART *gp, SPART **retlist, int head_flags, int retval_flags, ssg_valmode_t needed)
{
  SPART **members;
  int memb_ctr, memb_count;
  int equiv_ctr;
  int breakup_shift;
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
  for (memb_ctr = 0; memb_ctr < memb_count; memb_ctr += (1 + breakup_shift))
    {
      SPART *member = members[memb_ctr];
      ccaddr_t prev_itm_alias = uname___empty;
      int first_tabexpn_itm_idx, itm_idx, itm_count, filter_idx, filter_count;
      int curr_retval_flags = retval_flags;
      caddr_t *first_breakup_tabids;
      breakup_shift = 0;
      if (retval_flags & SSG_RETVAL_USES_ALIAS)
        {
          retval_flags &= ~SSG_RETVAL_USES_ALIAS; /* Aliases are not printed in resultsets of union, except the very first one... */
          retval_flags |= SSG_RETVAL_SUPPRESSED_ALIAS; /* ...but they're still known, right? */
        }
      if ((0 == memb_ctr) && (SSG_PRINT_UNION_NOFIRSTHEAD & head_flags))
        goto retval_list_complete; /* see below */
      first_breakup_tabids =
        sparp_gp_may_reuse_tabids_in_union (ssg->ssg_sparp, member, -1);
      if (NULL != first_breakup_tabids)
        {
          int bt_ctr, tabids_count = BOX_ELEMENTS (first_breakup_tabids);
          while (memb_ctr + breakup_shift + 1 < memb_count)
            {
              SPART *next_memb = members [memb_ctr + breakup_shift + 1];
              caddr_t *next_breakup_tabids =
                sparp_gp_may_reuse_tabids_in_union (ssg->ssg_sparp, next_memb, tabids_count);
              if (NULL == next_breakup_tabids)
                goto breakup_group_complete; /* see below */
              for (bt_ctr = tabids_count; bt_ctr--; /* no step */)
                {
#ifdef DEBUG
                  printf ("ssg_print_union() checks breakup in %s from %d to %d incl, bt_ctr %d: first %s next %s.\n",
                    gp->_.gp.selid, memb_ctr, memb_ctr + breakup_shift + 1,
                    bt_ctr, first_breakup_tabids [bt_ctr], next_breakup_tabids [bt_ctr] );
#endif
                  if (strcmp (first_breakup_tabids [bt_ctr], next_breakup_tabids [bt_ctr]))
                    goto breakup_group_complete; /* see below */
                }
              breakup_shift++;
            }
        }
breakup_group_complete:
#ifdef DEBUG
      if (0 != breakup_shift)
        {
          printf ("ssg_print_union() has found breakup in %s from %d to %d incl.\n",
            gp->_.gp.selid, memb_ctr, memb_ctr + breakup_shift);
        }
#endif
      ssg_newline (0);
      if (memb_ctr > 0)
        ssg_puts ("UNION ALL ");
      ssg_puts ("SELECT");
      if (0 != breakup_shift)
        {
          ssg_print_breakup_in_union (ssg, gp, retlist, head_flags, curr_retval_flags, needed, memb_ctr, breakup_shift);
          continue;
        }
      ssg_print_retval_list (ssg, members[memb_ctr], retlist, BOX_ELEMENTS_INT (retlist), curr_retval_flags, gp, needed);

retval_list_complete:
      ssg_newline (0);
      ssg_puts ("FROM");
      ssg->ssg_indent++;
#ifdef DEBUG
      if (SPAR_GP != SPART_TYPE (member))
        spar_internal_error (ssg->ssg_sparp, "ssg_" "print_union(): the member is not a SPAR_GP");
#endif
      itm_count = BOX_ELEMENTS (member->_.gp.members);
      if (0 == itm_count)
        {
          char buf[105]; /* potentialy 100 chars long see sparp_clone_id etc. */
          ssg_newline (0);
          snprintf (buf, sizeof (buf), "stub-%s", member->_.gp.selid);
          if (SSG_PRINT_UNION_NONEMPTY_STUB & head_flags)
            ssg_puts ("(SELECT TOP 1 1 AS __stub FROM DB.DBA.RDF_QUAD) AS ");
          else
            ssg_puts ("(SELECT TOP 1 1 AS __stub FROM DB.DBA.RDF_QUAD WHERE 0) AS ");
          ssg_prin_id (ssg, buf);
          goto end_of_table_list; /* see below */
        }
      if (OPTIONAL_L == member->_.gp.members[0]->_.gp.subtype)
        {
          char buf[105]; /* potentialy 100 chars long see sparp_clone_id etc. */
          ssg_newline (0);
          snprintf (buf, sizeof (buf), "lojstub-%s", member->_.gp.selid);
          ssg_puts ("(SELECT TOP 1 1 AS __stub FROM DB.DBA.RDF_QUAD) AS ");
          ssg_prin_id (ssg, buf);
          ssg_puts (" LEFT OUTER JOIN");
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
          ssg_print_table_exp (ssg, member, member->_.gp.members + first_tabexpn_itm_idx, itm_idx + 1 - first_tabexpn_itm_idx, 1); /* PASS 1, printing what's in FROM */
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
              filter_count = BOX_ELEMENTS_0 (member->_.gp.filters);
              for (filter_idx = filter_count - member->_.gp.glued_filters_count; filter_idx < filter_count; filter_idx++)
                {
                  SPART *filt = member->_.gp.filters[filter_idx];
                  ssg_print_filter (ssg, filt);
                }
              if (0 == ssg->ssg_where_l_printed)
                ssg_puts ("1");
              ssg->ssg_indent--;
              ssg_puts (")");
              ssg->ssg_where_l_printed = save_where_l_printed;
              ssg->ssg_where_l_text = save_where_l_text;
            }
          prev_itm_alias = itm_alias;
        }
      if (OPTIONAL_L == member->_.gp.members[0]->_.gp.subtype)
        {
          ssg_puts (" ON (1)");
        }

end_of_table_list: ;
      ssg->ssg_indent--;
      save_where_l_printed = ssg->ssg_where_l_printed;
      save_where_l_text = ssg->ssg_where_l_text;
      ssg->ssg_where_l_printed = 0;
      ssg->ssg_where_l_text = "\bWHERE";
      ssg->ssg_indent++;
      if ((0 == gp->_.gp.subtype) || (WHERE_L == gp->_.gp.subtype) || (1 >= itm_count))
        {
          for (equiv_ctr = 0; equiv_ctr < gp->_.gp.equiv_count; equiv_ctr++)
            {
              sparp_equiv_t *eq = ssg->ssg_equivs[gp->_.gp.equiv_indexes[equiv_ctr]];
              if ((SPART_VARR_CONFLICT & eq->e_rvr.rvrRestrictions) && (SPART_VARR_NOT_NULL & eq->e_rvr.rvrRestrictions))
                {
                  ssg_print_where_or_and (ssg, "conflict on NOT NULL variable");
                  ssg_puts (" 0");
                  goto end_of_where_list;
                }
            }
        }
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
          ssg_print_table_exp (ssg, member, member->_.gp.members + first_tabexpn_itm_idx, itm_idx + 1 - first_tabexpn_itm_idx, 2); /* PASS 2, printing what's in WHERE */
        }
      for (equiv_ctr = 0; equiv_ctr < member->_.gp.equiv_count; equiv_ctr++)
        {
          sparp_equiv_t *eq = ssg->ssg_equivs[member->_.gp.equiv_indexes[equiv_ctr]];
          ssg_print_equivalences (ssg, member, eq, NULL, NULL);
        }
      filter_count = BOX_ELEMENTS_0 (member->_.gp.filters) - member->_.gp.glued_filters_count;
      for (filter_idx = 0; filter_idx < filter_count; filter_idx++)
        {
          SPART *filt = member->_.gp.filters[filter_idx];
          ssg_print_filter (ssg, filt);
        }
end_of_where_list:
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

void
ssg_print_t_options_of_select (spar_sqlgen_t *ssg)
{
  SPART	*tree = ssg->ssg_tree;
  SPART	**opts = ssg->ssg_wrapping_gp->_.gp.options;
  int ctr, vctr;
  if (NULL == sparp_get_option (ssg->ssg_sparp, opts, TRANSITIVE_L))
    return;
  ssg_puts (" TRANSITIVE");
  for (ctr = BOX_ELEMENTS (opts); 1 < ctr; ctr -= 2)
    {
      ptrlong key = (ptrlong)(opts [ctr-2]);
      SPART *val = opts [ctr-1];
      char buf[40];
      switch (key)
        {
        case T_IN_L: case T_OUT_L:
          ssg_puts (((T_IN_L == key) ? " T_IN" : " T_OUT"));
          DO_BOX_FAST (SPART *, v, vctr, val->_.list.items)
            {
              int pos = sparp_subexpn_position1_in_retlist (ssg->ssg_sparp, v->_.var.vname, tree->_.req_top.orig_retvals);
              sprintf (buf, "%c%d", vctr ? ',': '(', pos);
              ssg_puts (buf);
            }
          END_DO_BOX_FAST;
          ssg_putchar (')');
          break;
        case T_MIN_L: case T_MAX_L:
          ssg_puts (((T_MIN_L == key) ? " T_MIN(" : " T_MAX("));
          ssg_print_scalar_expn (ssg->ssg_parent_ssg, val, SSG_VALMODE_SQLVAL, NULL_ASNAME);
          ssg_putchar (')');
          break;
        case T_DIRECTION_L:
          sprintf (buf, " T_DIRECTION %ld", (long)((ptrlong)val));
          ssg_puts (buf);
          break;
        case T_END_FLAG_L:
          sprintf (buf, " T_END_FLAG %ld", (long)((ptrlong)val));
          ssg_puts (buf);
          break;
        case T_CYCLES_ONLY_L: ssg_puts (" T_CYCLES_ONLY"); break;
        case T_DISTINCT_L: ssg_puts (" T_DISTINCT"); break;
        case T_EXISTS_L: ssg_puts (" T_EXISTS"); break;
        case T_NO_CYCLES_L: ssg_puts (" T_NO_CYCLES"); break;
        case T_NO_ORDER_L: ssg_puts (" T_NO_ORDER"); break;
        case T_SHORTEST_ONLY_L: ssg_puts (" T_SHORTEST_ONLY"); break;
        case T_FINAL_AS_L: spar_error (ssg->ssg_sparp, "Option T_FINAL_AS is not supported is SPARQL in this version of Virtuoso"); break;
        default: break;
        }
    }
}


void
ssg_print_t_steps_of_select (spar_sqlgen_t *ssg)
{
  SPART	*tree = ssg->ssg_tree;
  SPART	**opts = ssg->ssg_wrapping_gp->_.gp.options;
  int ctr;
  if (NULL == sparp_get_option (ssg->ssg_sparp, opts, TRANSITIVE_L))
    return;
  for (ctr = BOX_ELEMENTS (opts); 1 < ctr; ctr -= 2)
    {
      ptrlong key = (ptrlong)(opts [ctr-2]);
      SPART *val = opts [ctr-1];
      char buf[40];
      switch (key)
        {
        case T_STEP_L:
          ssg_puts ("");
          if (SPAR_VARIABLE == SPART_TYPE (val->_.alias.arg))
            {
              int pos = sparp_subexpn_position1_in_retlist (ssg->ssg_sparp, val->_.alias.arg->_.var.vname, tree->_.req_top.orig_retvals);
              sprintf (buf, ", T_STEP(%d) AS ", pos);
              ssg_puts (buf);
            }
          else
            {
              ssg_puts (", T_STEP(");
              ssg_print_scalar_expn (ssg, val->_.alias.arg, SSG_VALMODE_SQLVAL, NULL_ASNAME);
              ssg_puts (") AS ");
            }
          ssg_prin_id (ssg, val->_.alias.aname);
          break;
        default: break;
        }
    }
}

int
ssg_req_top_needs_rb_complete (spar_sqlgen_t *ssg)
{
  SPART	*tree = ssg->ssg_tree;
  ptrlong subtype = tree->_.req_top.subtype;
  ssg_valmode_t retvalmode;
  if ((SELECT_L != subtype) && (DISTINCT_L != subtype))
    return 0;
  if (NULL != tree->_.req_top.formatmode_name)
    return 0;
  retvalmode = ssg_find_valmode_by_name (tree->_.req_top.retvalmode_name);
  if ((SSG_VALMODE_SQLVAL != retvalmode) && (NULL != retvalmode))
    return 0;
  if (DISTINCT_L == subtype)
    return 1;
  if ((0 != BOX_ELEMENTS_0 (tree->_.req_top.order)) || (0 != BOX_ELEMENTS_0 (tree->_.req_top.groupings)))
    return 1;
  return 0;
}

void
ssg_make_rb_complete_wrapped (spar_sqlgen_t *ssg)
{
  SPART	*tree = ssg->ssg_tree;
  SPART **retvals = tree->_.req_top.retvals;
  caddr_t rbc_selid = t_box_sprintf (50, "%.40s_rbc", tree->_.req_top.retselid);
  ssg_puts (" SELECT ");
  ssg_print_retval_cols (ssg, tree, retvals, rbc_selid, "bif:__ro2sq", 1);
  ssg_puts (" FROM (");
  ssg->ssg_indent++;
  ssg_make_sql_query_text (ssg);
  ssg->ssg_indent--;
  ssg_puts (") AS ");
  ssg_prin_id (ssg, rbc_selid);  
}

void
ssg_make_sql_query_text (spar_sqlgen_t *ssg)
{
  int gby_ctr, oby_ctr;
  long lim, ofs;
  int has_limofs = 0;
  char limofs_strg[40] = "";
  caddr_t limofs_alias = NULL;
  SPART	*tree = ssg->ssg_tree;
  ptrlong subtype = tree->_.req_top.subtype;
  SPART **retvals;
  const char *formatter, *agg_formatter, *agg_meta;
  ssg_valmode_t retvalmode;
  int top_retval_flags =
    SSG_RETVAL_TOPMOST |
    SSG_RETVAL_FROM_JOIN_MEMBER |
    SSG_RETVAL_FROM_FIRST_UNION_MEMBER |
    SSG_RETVAL_MUST_PRINT_SOMETHING |
    SSG_RETVAL_CAN_PRINT_NULL |
    SSG_RETVAL_USES_ALIAS ;
  ccaddr_t top_selid = tree->_.req_top.pattern->_.gp.selid;
  retvals = tree->_.req_top.retvals;
  if (NULL != ssg->ssg_sparp->sparp_env->spare_storage_name)
    {
      if ('\0' != ssg->ssg_sparp->sparp_env->spare_storage_name[0])
        ssg_qr_uses_jso (ssg, NULL, ssg->ssg_sparp->sparp_env->spare_storage_name);
    }
  else
    ssg_qr_uses_jso (ssg, NULL, uname_virtrdf_ns_uri_DefaultQuadStorage);
  ssg->ssg_equiv_count = ssg->ssg_sparp->sparp_equiv_count;
  ssg->ssg_equivs = ssg->ssg_sparp->sparp_equivs;
  ssg_find_formatter_by_name_and_subtype (tree->_.req_top.formatmode_name, tree->_.req_top.subtype, &formatter, &agg_formatter, &agg_meta);
  if (COUNT_DISTINCT_L == subtype)
    retvalmode = SSG_VALMODE_SQLVAL;
  else
    retvalmode = ssg_find_valmode_by_name (tree->_.req_top.retvalmode_name);
  if (((NULL != formatter) || (NULL != agg_formatter)) && (NULL != retvalmode) && (SSG_VALMODE_LONG != retvalmode))
    spar_sqlprint_error ("'output:valmode' declaration conflicts with 'output:format'");
  lim = unbox (tree->_.req_top.limit);
  ofs = unbox (tree->_.req_top.offset);
  if ((SPARP_MAXLIMIT != lim) || (0 != ofs))
    {
      has_limofs = 1;
      if (0 != ofs)
        snprintf (limofs_strg, sizeof (limofs_strg), " TOP %ld, %ld", ofs, lim);
      else
        snprintf (limofs_strg, sizeof (limofs_strg), " TOP %ld", lim);
    }
  switch (subtype)
    {
    case SELECT_L:
    case COUNT_DISTINCT_L:
    case DISTINCT_L:
      if (NULL == retvalmode)
        retvalmode = ((NULL != formatter) ? SSG_VALMODE_LONG : SSG_VALMODE_SQLVAL);
      if ((DISTINCT_L == subtype) && sparp_some_retvals_should_wrap_distinct (ssg->ssg_sparp, tree))
        top_retval_flags |= SSG_RETVAL_DIST_SER_LONG;
      if (COUNT_DISTINCT_L == subtype)
        {
          ssg_puts ("SELECT COUNT (*) AS \"callret-0\" FROM (");
          ssg->ssg_indent += 1;
          ssg_newline (0);
        }
      else if (NULL != formatter)
        {
          const char *deser_name = NULL;
          if (SSG_RETVAL_DIST_SER_LONG & top_retval_flags)
            deser_name = (const char *)((ptrlong)DISTINCT_L);
          ssg_puts ("SELECT "); ssg_puts (formatter); ssg_puts (" (");
          ssg_puts ("vector (");
          ssg_print_retval_cols (ssg, tree, retvals, top_selid, deser_name, 0);
          ssg_puts ("), vector (");
          ssg_print_retval_cols (ssg, tree, retvals, NULL_ASNAME, NULL, 0);
          ssg_puts (")) AS \"callret-0\" LONG VARCHAR\nFROM (");
          ssg->ssg_indent += 1;
          ssg_newline (0);
        }
      else if (NULL != agg_formatter)
        {
          const char *deser_name = NULL;
          if (SSG_RETVAL_DIST_SER_LONG & top_retval_flags)
            deser_name = (const char *)((ptrlong)DISTINCT_L);
          ssg_puts ("SELECT "); ssg_puts (agg_formatter); ssg_puts (" (");
          if (NULL != agg_meta)
            {
              ssg_puts (agg_meta); ssg_puts (" (");
            }
          ssg_puts ("vector (");
          ssg_print_retval_cols (ssg, tree, retvals, NULL_ASNAME, NULL, 0);
          if (NULL != agg_meta)
            {
              ssg_puts ("), '");
              ssg_puts (strchr (tree->_.req_top.formatmode_name, ' ')+1);
              ssg_putchar ('\'');
            }
          ssg_puts ("), vector (");
          ssg_print_retval_cols (ssg, tree, retvals, top_selid, deser_name, 0);
          ssg_puts (")) AS \"aggret-0\" INTEGER FROM (");
          ssg->ssg_indent += 1;
          ssg_newline (0);
        }
      else if (SSG_RETVAL_DIST_SER_LONG & top_retval_flags)
        {
          ssg_puts ("SELECT "); 
          ssg_print_retval_cols (ssg, tree, retvals, top_selid, (const char *)((ptrlong)DISTINCT_L), 1);
          ssg_puts (" FROM (");
          ssg->ssg_indent += 1;
          ssg_newline (0);
        }
      ssg_puts ("SELECT");
      if ((COUNT_DISTINCT_L == tree->_.req_top.subtype) || (DISTINCT_L == tree->_.req_top.subtype))
        ssg_puts (" DISTINCT");
      if (has_limofs)
        ssg_puts (limofs_strg);
      if ((NULL != ssg->ssg_wrapping_gp) && (NULL != ssg->ssg_wrapping_gp->_.gp.options))
        ssg_print_t_options_of_select (ssg);
      ssg_print_retval_list (ssg, tree->_.req_top.pattern,
        retvals, BOX_ELEMENTS_INT (retvals),
        top_retval_flags, tree->_.req_top.pattern, retvalmode );
      if ((NULL != ssg->ssg_wrapping_gp) && (NULL != ssg->ssg_wrapping_gp->_.gp.options))
        ssg_print_t_steps_of_select (ssg);
      break;
    case CONSTRUCT_L:
    case DESCRIBE_L:
      if ((NULL != tree->_.req_top.formatmode_name) &&
        !strcmp ("_JAVA_", tree->_.req_top.formatmode_name) )
        ssg_puts (" DB.DBA.RDF_DICT_OF_TRIPLES_TO_THREE_COLS ((");
      else if ((NULL == formatter) && (NULL == agg_formatter) && ssg->ssg_sparp->sparp_sparqre->sparqre_direct_client_call)
        {
          ssg_find_formatter_by_name_and_subtype ("TTL", subtype, &formatter, &agg_formatter, &agg_meta);
          if ((NULL != retvalmode) && (SSG_VALMODE_LONG != retvalmode))
            spar_sqlprint_error ("'output:valmode' declaration conflicts with TTL output format needed by database client connection'");
        }
      /* No break here. INSERT_L and DELETE_L returns simple integers so no need to protect the client connection by formatting */
    case INSERT_L:
    case DELETE_L:
    case MODIFY_L:
    case CLEAR_L:
    case LOAD_L:
    case CREATE_L:
    case DROP_L:
    case SPARUL_RUN_SUBTYPE:
      if ((SPARUL_RUN_SUBTYPE == subtype) && !unbox (spar_compose_report_flag (ssg->ssg_sparp)))
        {
          ssg_puts ("set_row_count (");
          ssg->ssg_indent += 1;
          ssg_print_sparul_run_call (ssg, tree->_.req_top.pattern, retvals[0], 0);
          ssg_newline (0);
          ssg_puts (" )");
          ssg->ssg_indent -= 1;
          return;
        }
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
      if (has_limofs)
        {
          /*top_retval_flags |= SSG_RETVAL_FROM_LIMOFS;
          limofs_alias = t_box_sprintf (100, "%s_limofs", tree->_.req_top.pattern->_.gp.selid);*/
          limofs_alias = t_box_dv_short_string ("limofs");
        }
      ssg_print_retval_list (ssg, tree->_.req_top.pattern,
        retvals, 1,
        top_retval_flags, tree->_.req_top.pattern, retvalmode );
      if (NULL != formatter)
        {
          const char *fmname = tree->_.req_top.formatmode_name;
          ssg_puts (" ) AS \"callret");
          if (NULL != fmname)
            {
              if (strncmp (fmname, "HTTP+", 5))
                ssg_puts (fmname);
              else
                {
                  const char *fmname_head = fmname + 5;
                  const char *fmname_tail = strchr (fmname_head, ' ');
                  if (NULL == fmname_tail)
                    ssg_puts (fmname_head);
                  else
                    ssg_putbuf (fmname_head, fmname_tail - fmname_head);
                }
            }
          ssg_puts ("-0\" LONG VARCHAR");
          ssg->ssg_indent -= 1;
          ssg_newline (0);
        }
      if (has_limofs)
        {
          ssg_newline (0);
          ssg_puts ("FROM (SELECT");
          ssg_puts (limofs_strg);
          ssg_print_retval_list (ssg, tree->_.req_top.pattern,
            retvals + 1, BOX_ELEMENTS (retvals) - 1,
            top_retval_flags | SSG_RETVAL_USES_ALIAS, NULL, retvalmode );
          ssg->ssg_indent += 1;
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
  ssg_print_union (ssg, tree->_.req_top.pattern, retvals,
    SSG_PRINT_UNION_NOFIRSTHEAD | SSG_PRINT_UNION_NONEMPTY_STUB | SSG_RETVAL_MUST_PRINT_SOMETHING,
    top_retval_flags, retvalmode );
  if (0 < BOX_ELEMENTS_INT_0 (tree->_.req_top.groupings))
    {
      ssg_newline (0);
      ssg_puts ("GROUP BY");
      ssg->ssg_indent++;
      DO_BOX_FAST(SPART *, grouping, gby_ctr, tree->_.req_top.groupings)
        {
          ssg_valmode_t native, needed;
	  if (gby_ctr > 0)
            ssg_putchar (',');
          native = sparp_expn_native_valmode (ssg->ssg_sparp, grouping);
          if (IS_BOX_POINTER (native) && native->qmfIsBijection)
            needed = native;
          else
            needed = SSG_VALMODE_SQLVAL;
          ssg_print_retval_simple_expn (ssg, tree->_.req_top.pattern, grouping, needed, NULL_ASNAME);
        }
      END_DO_BOX_FAST;
      ssg->ssg_indent--;
    }
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
  if (NULL != limofs_alias)
    {
      ssg_newline (0);
      ssg_puts (") as \""); ssg_puts (limofs_alias); ssg_puts ("\"");
      ssg->ssg_indent -= 1;
    }
  ssg_puts ("\nOPTION (QUIETCAST");
  if (NULL != ssg->ssg_sparp->sparp_env->spare_use_ifp)
    ssg_puts (", IFP");
  if (NULL != ssg->ssg_sparp->sparp_env->spare_use_same_as)
    ssg_puts (", SAME_AS");
  ssg_prin_option_commalist (ssg, ssg->ssg_sparp->sparp_env->spare_sql_select_options, 1);
  ssg_puts (")");
  if ((COUNT_DISTINCT_L == subtype) || (NULL != formatter) || (NULL != agg_formatter) || (SSG_RETVAL_DIST_SER_LONG & top_retval_flags))
    {
      switch (tree->_.req_top.subtype)
        {
        case SELECT_L:
        case COUNT_DISTINCT_L:
        case DISTINCT_L:
        case ASK_L:
          ssg_puts (" ) AS ");
          ssg_prin_id (ssg, top_selid);
          ssg->ssg_indent--;
          break;
        }
    }
  else if (((CONSTRUCT_L == subtype) || (DESCRIBE_L == subtype)) &&
    (NULL != tree->_.req_top.formatmode_name) &&
    !strcmp ("_JAVA_", tree->_.req_top.formatmode_name) )
    ssg_puts ("))");
}

void
ssg_print_qm_sql (spar_sqlgen_t *ssg, SPART *tree)
{
  switch (SPART_TYPE (tree))
  {
    case SPAR_QM_SQL_FUNCALL:
      {
        int ctr, prev_was_long, fixedlen, namedlen;
        prev_was_long = 0;
        ssg_puts (tree->_.qm_sql_funcall.fname);
        ssg_puts (" (");
        ssg->ssg_indent++;
        fixedlen = BOX_ELEMENTS_0 (tree->_.qm_sql_funcall.fixed);
        for (ctr = 0; ctr < fixedlen; ctr++)
          {
            SPART *arg = tree->_.qm_sql_funcall.fixed[ctr];
            int curr_is_long = SPAR_FUNCALL_ARG_IS_LONG (arg);
            if (0 != ctr)
              ssg_puts (", ");
            if (curr_is_long || prev_was_long)
              ssg_newline (0);
            ssg_print_qm_sql (ssg, arg);
            prev_was_long = curr_is_long;
          }
        if (NULL != tree->_.qm_sql_funcall.named)
          {
            if (0 != fixedlen)
              ssg_puts (", ");
            if (prev_was_long)
              ssg_newline (0);
            prev_was_long = 0;
            ssg_puts ("vector (");
            ssg->ssg_indent++;
            namedlen = BOX_ELEMENTS_0 (tree->_.qm_sql_funcall.named);
            for (ctr = 0; ctr < namedlen; ctr++)
              {
                SPART *arg = tree->_.qm_sql_funcall.named[ctr];
                int curr_is_long = SPAR_FUNCALL_ARG_IS_LONG(arg);
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
      }
    case SPAR_LIT: case SPAR_QNAME:
      if (NULL == tree)
        {
          ssg_puts (" NULL");
          return;
        }
      if (DV_ARRAY_OF_POINTER == DV_TYPE_OF (tree))
        ssg_print_box_as_sql_atom (ssg, tree->_.lit.val, 1);
      else
        ssg_print_box_as_sql_atom (ssg, (caddr_t)tree, 1);
      break;
    default:
      ssg_print_scalar_expn (ssg, tree, SSG_VALMODE_SQLVAL, NULL_ASNAME);
/*
    default: spar_internal_error (ssg->ssg_sparp, "ssg_" "print_qm_sql(): unsupported tree type");
*/
  }
}

void
ssg_make_qm_sql_text (spar_sqlgen_t *ssg)
{
  ssg_print_qm_sql (ssg, ssg->ssg_tree);
}

void ssg_make_whole_sql_text (spar_sqlgen_t *ssg)
{
  QR_RESET_CTX
    {
      switch (SPART_TYPE (ssg->ssg_tree))
        {
        case SPAR_REQ_TOP:
          {
            int need_rb_complete;
            ssg->ssg_sources = ssg->ssg_tree->_.req_top.sources; /*!!!TBD merge with environment */
            need_rb_complete = ssg_req_top_needs_rb_complete (ssg);
            if (need_rb_complete)
              ssg_make_rb_complete_wrapped (ssg);
            else
              ssg_make_sql_query_text (ssg);
            break;
          }
        case SPAR_CODEGEN:
          {
            ssg_codegen_callback_t *cbk = ssg->ssg_tree->_.codegen.cgen_cbk[0];
            cbk (ssg, ssg->ssg_tree);
            break;
          }
        default:
          ssg_make_qm_sql_text (ssg);
        }
    }
  QR_RESET_CODE
    {
      du_thread_t *self = THREAD_CURRENT_THREAD;
      ssg->ssg_sparp->sparp_sparqre->sparqre_catched_error = thr_get_error_code (self);
      thr_set_error_code (self, NULL);
#ifdef SPARQL_DEBUG
      printf ("\nssg_make_whole_sql_text() caught composing error: %s", ERR_MESSAGE(ssg->ssg_sparp->sparp_sparqre->sparqre_catched_error));
#endif
    }
  END_QR_RESET
}

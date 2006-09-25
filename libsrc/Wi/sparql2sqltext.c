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

rdf_ds_field_t rdf_ds_field_tr_fields[SPART_TRIPLE_FIELDS_COUNT];
rdf_ds_t rdf_ds_sys_storage_inst;
rdf_ds_t *rdf_ds_sys_storage = &rdf_ds_sys_storage_inst;

void rdf_ds_load_all (void)
{
  rdf_ds_field_t *fld;
  rdf_ds_t *ds = rdf_ds_sys_storage;
/* fields: graph */
  fld = ds->tr_graph = rdf_ds_field_tr_fields + SPART_TRIPLE_GRAPH_IDX;
  fld->rdfdf_ds = ds;
  fld->rdfdf_format = "default-iid";
  fld->rdfdf_short_tmpl = " ^{alias-dot}^G";
  fld->rdfdf_long_tmpl = " ^{alias-dot}^G";
  fld->rdfdf_sqlval_tmpl = " DB.DBA.RDF_QNAME_OF_IID (^{alias-dot}^G)";
  fld->rdfdf_bool_tmpl = " NULL";
  fld->rdfdf_isref_of_short_tmpl = " 1";
  fld->rdfdf_isuri_of_short_tmpl = " (^{tree}^ < #i1000000000)";
  fld->rdfdf_isblank_of_short_tmpl = " (^{tree}^ >= #i1000000000)";
  fld->rdfdf_islit_of_short_tmpl = " 0";
  fld->rdfdf_long_of_short_tmpl = " ^{tree}^ ";
  fld->rdfdf_datatype_of_short_tmpl = " 'http://www.w3.org/2001/XMLSchema#anyURI'";
  fld->rdfdf_language_of_short_tmpl = " NULL";
  fld->rdfdf_sqlval_of_short_tmpl = " DB.DBA.RDF_QNAME_OF_IID (^{tree}^)";
  fld->rdfdf_bool_of_short_tmpl = " NULL";
  fld->rdfdf_uri_of_short_tmpl = " DB.DBA.RDF_QNAME_OF_IID (^{tree}^)";
  fld->rdfdf_strsqlval_of_short_tmpl = " DB.DBA.RDF_QNAME_OF_IID (^{tree}^)";
  fld->rdfdf_short_of_typedsqlval_tmpl = " NULL";
  fld->rdfdf_short_of_sqlval_tmpl = " DB.DBA.RDF_IID_OF_QNAME_SAFE (^{tree}^)";
  fld->rdfdf_short_of_long_tmpl = " ^{tree}^";
  fld->rdfdf_short_of_uri_tmpl = " DB.DBA.RDF_IID_OF_QNAME (^{tree}^)";
  fld->rdfdf_cmp_func_name = "DB.DBA.RDF_IID_CMP";
  fld->rdfdf_typemin_tmpl = " NULL"; /* No order on IRIs */
  fld->rdfdf_typemax_tmpl = " NULL"; /* No order on IRIs */
  fld->rdfdf_ok_for_any_sqlvalue = 0; /* It can not store anything except IRI ids */
  fld->rdfdf_restrictions = SPART_VARR_IS_REF | SPART_VARR_IS_IRI | SPART_VARR_NOT_NULL;
  fld->rdfdf_datatype = NULL;
  fld->rdfdf_language = NULL;
  fld->rdfdf_fixedvalue = NULL;
  fld->rdfdf_uri_id_offset = 0;
/* fields: subject */
  fld = ds->tr_subject = rdf_ds_field_tr_fields + SPART_TRIPLE_SUBJECT_IDX;
  fld->rdfdf_ds = ds;
  fld->rdfdf_format = "default-iid";
  fld->rdfdf_short_tmpl = " ^{alias-dot}^S";
  fld->rdfdf_long_tmpl = " ^{alias-dot}^S";
  fld->rdfdf_sqlval_tmpl = " DB.DBA.RDF_QNAME_OF_IID (^{alias-dot}^S)";
  fld->rdfdf_bool_tmpl = " NULL";
  fld->rdfdf_isref_of_short_tmpl = " 1";
  fld->rdfdf_isuri_of_short_tmpl = " (^{tree}^ < #i1000000000)";
  fld->rdfdf_isblank_of_short_tmpl = " (^{tree}^ >= #i1000000000)";
  fld->rdfdf_islit_of_short_tmpl = " 0";
  fld->rdfdf_long_of_short_tmpl = " ^{tree}^ ";
  fld->rdfdf_datatype_of_short_tmpl = " 'http://www.w3.org/2001/XMLSchema#anyURI'";
  fld->rdfdf_language_of_short_tmpl = " NULL";
  fld->rdfdf_sqlval_of_short_tmpl = " DB.DBA.RDF_QNAME_OF_IID (^{tree}^)";
  fld->rdfdf_bool_of_short_tmpl = " NULL";
  fld->rdfdf_uri_of_short_tmpl = " DB.DBA.RDF_QNAME_OF_IID (^{tree}^)";
  fld->rdfdf_strsqlval_of_short_tmpl = " DB.DBA.RDF_QNAME_OF_IID (^{tree}^)";
  fld->rdfdf_short_of_typedsqlval_tmpl = " NULL";
  fld->rdfdf_short_of_sqlval_tmpl = " DB.DBA.RDF_IID_OF_QNAME_SAFE (^{tree}^)";
  fld->rdfdf_short_of_long_tmpl = " ^{tree}^";
  fld->rdfdf_short_of_uri_tmpl = " DB.DBA.RDF_IID_OF_QNAME (^{tree}^)";
  fld->rdfdf_cmp_func_name = "DB.DBA.RDF_IID_CMP";
  fld->rdfdf_typemin_tmpl = " NULL"; /* No order on IRIs */
  fld->rdfdf_typemax_tmpl = " NULL"; /* No order on IRIs */
  fld->rdfdf_ok_for_any_sqlvalue = 0; /* It can not store anything except IRI ids */
  fld->rdfdf_restrictions = SPART_VARR_IS_REF | SPART_VARR_NOT_NULL;
  fld->rdfdf_datatype = NULL;
  fld->rdfdf_language = NULL;
  fld->rdfdf_fixedvalue = NULL;
  fld->rdfdf_uri_id_offset = 0;
/* fields: predicate */
  fld = ds->tr_predicate = rdf_ds_field_tr_fields + SPART_TRIPLE_PREDICATE_IDX;
  fld->rdfdf_ds = ds;
  fld->rdfdf_format = "default-iid";
  fld->rdfdf_short_tmpl = " ^{alias-dot}^P";
  fld->rdfdf_long_tmpl = " ^{alias-dot}^P";
  fld->rdfdf_sqlval_tmpl = " DB.DBA.RDF_QNAME_OF_IID (^{alias-dot}^P)";
  fld->rdfdf_bool_tmpl = " NULL";
  fld->rdfdf_isref_of_short_tmpl = " 1";
  fld->rdfdf_isuri_of_short_tmpl = " (^{tree}^ < #i1000000000)";
  fld->rdfdf_isblank_of_short_tmpl = " (^{tree}^ >= #i1000000000)";
  fld->rdfdf_islit_of_short_tmpl = " 0";
  fld->rdfdf_long_of_short_tmpl = " ^{tree}^ ";
  fld->rdfdf_datatype_of_short_tmpl = " 'http://www.w3.org/2001/XMLSchema#anyURI'";
  fld->rdfdf_language_of_short_tmpl = " NULL";
  fld->rdfdf_sqlval_of_short_tmpl = " DB.DBA.RDF_QNAME_OF_IID (^{tree}^)";
  fld->rdfdf_bool_of_short_tmpl = " NULL";
  fld->rdfdf_uri_of_short_tmpl = " DB.DBA.RDF_QNAME_OF_IID (^{tree}^)";
  fld->rdfdf_strsqlval_of_short_tmpl = " DB.DBA.RDF_QNAME_OF_IID (^{tree}^)";
  fld->rdfdf_short_of_typedsqlval_tmpl = " NULL";
  fld->rdfdf_short_of_sqlval_tmpl = " DB.DBA.RDF_IID_OF_QNAME_SAFE (^{tree}^)";
  fld->rdfdf_short_of_long_tmpl = " ^{tree}^";
  fld->rdfdf_short_of_uri_tmpl = " DB.DBA.RDF_IID_OF_QNAME (^{tree}^)";
  fld->rdfdf_cmp_func_name = "DB.DBA.RDF_IID_CMP";
  fld->rdfdf_typemin_tmpl = " NULL"; /* No order on IRIs */
  fld->rdfdf_typemax_tmpl = " NULL"; /* No order on IRIs */
  fld->rdfdf_ok_for_any_sqlvalue = 0; /* It can not store anything except IRI ids */
  fld->rdfdf_restrictions = SPART_VARR_IS_REF | SPART_VARR_NOT_NULL;
  fld->rdfdf_datatype = NULL;
  fld->rdfdf_language = NULL;
  fld->rdfdf_fixedvalue = NULL;
  fld->rdfdf_uri_id_offset = 0;
/* fields: object */
  fld = ds->tr_object = rdf_ds_field_tr_fields + SPART_TRIPLE_OBJECT_IDX;
  fld->rdfdf_ds = ds;
  fld->rdfdf_format = "default";
  fld->rdfdf_short_tmpl = " ^{alias-dot}^O";
  fld->rdfdf_long_tmpl = " DB.DBA.RQ_LONG_OF_O (^{alias-dot}^O)";
  fld->rdfdf_sqlval_tmpl = " DB.DBA.RQ_SQLVAL_OF_O (^{alias-dot}^O)";
  fld->rdfdf_bool_tmpl = " DB.DBA.RQ_BOOL_OF_O (^{alias-dot}^O)";
  fld->rdfdf_isref_of_short_tmpl = " DB.DBA.RQ_IID_OF_O (^{tree}^) is not null";
  fld->rdfdf_isuri_of_short_tmpl = " (DB.DBA.RQ_IID_OF_O (^{tree}^) < #i1000000000)";
  fld->rdfdf_isblank_of_short_tmpl = " (DB.DBA.RQ_IID_OF_O (^{tree}^) >= #i1000000000)";
  fld->rdfdf_islit_of_short_tmpl = " DB.DBA.RQ_O_IS_LIT (^{tree}^)";
  fld->rdfdf_long_of_short_tmpl = " DB.DBA.RDF_LONG_OF_OBJ (^{tree}^)";
  fld->rdfdf_datatype_of_short_tmpl = " DB.DBA.RDF_DATATYPE_OF_OBJ (^{tree}^)";
  fld->rdfdf_language_of_short_tmpl = " DB.DBA.RDF_LANGUAGE_OF_OBJ (^{tree}^)";
  fld->rdfdf_sqlval_of_short_tmpl = " DB.DBA.RDF_SQLVAL_OF_OBJ (^{tree}^)";
  fld->rdfdf_bool_of_short_tmpl = " DB.DBA.RDF_BOOL_OF_OBJ (^{tree}^)";
  fld->rdfdf_uri_of_short_tmpl = " DB.DBA.RDF_QNAME_OF_OBJ (^{tree}^)";
  fld->rdfdf_strsqlval_of_short_tmpl = " DB.DBA.RDF_STRSQLVAL_OF_OBJ (^{tree}^)";
  fld->rdfdf_short_of_typedsqlval_tmpl = " DB.DBA.RDF_MAKE_OBJ_OF_TYPEDSQLVAL (^{sqlval-of-tree}^, DB.DBA.RDF_MAKE_IID_OF_QNAME(^{datatype-of-tree}^), ^{language-of-tree}^)";
  fld->rdfdf_short_of_sqlval_tmpl = " DB.DBA.RDF_OBJ_OF_SQLVAL (^{tree}^)";
  fld->rdfdf_short_of_long_tmpl = " DB.DBA.RDF_OBJ_OF_LONG (^{tree}^)";
  fld->rdfdf_short_of_uri_tmpl = " DB.DBA.RDF_IID_OF_QNAME_SAFE (^{tree}^)";
  fld->rdfdf_cmp_func_name = "DB.DBA.RDF_OBJ_CMP";
  fld->rdfdf_typemin_tmpl = " DB.DBA.RDF_TYPEMIN_OF_OBJ (^{tree}^)";
  fld->rdfdf_typemax_tmpl = " DB.DBA.RDF_TYPEMAX_OF_OBJ (^{tree}^)";
  fld->rdfdf_ok_for_any_sqlvalue = 1; /* It can store anything */
  fld->rdfdf_restrictions = SPART_VARR_NOT_NULL;
  fld->rdfdf_datatype = NULL;
  fld->rdfdf_language = NULL;
  fld->rdfdf_fixedvalue = NULL;
  fld->rdfdf_uri_id_offset = 0;
/* system data source itself */
  ds->rdfd_pred_mappings = (rdf_ds_pred_mapping_t *)list (0);
  ds->rdfd_base_table="DB.DBA.RDF_QUAD";
  ds->rdfd_uri_local_table="DB.DBA.RDF_IRI";
  ds->rdfd_uri_ns_table="DB.DBA.RDF_NS";
  ds->rdfd_uri_lob_table="DB.DBA.RDF_LOB";
  ds->rdfd_allmappings_view = NULL;
}

dk_set_t
rdf_ds_find_appropriate (SPART *triple, SPART **sources, int ignore_named_sources)
{
  dk_set_t res = NULL;
  rdf_ds_usage_t *du;
  rdf_ds_t *ds;
/*!!!TBD real search for special cases here */
/* The default is, naturally, rdf_ds_sys_storage */
  du = (rdf_ds_usage_t *)dk_alloc (sizeof (rdf_ds_usage_t));
  ds = rdf_ds_sys_storage;
  du->rdfdu_ds = ds;
  du->tr_graph = ds->tr_graph;
  du->tr_subject = ds->tr_subject;
  du->tr_predicate = ds->tr_predicate;
  du->tr_object = ds->tr_object;
  dk_set_push (&res, du);
  return res;
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

/* Printer */

SPART *ssg_find_gp_by_alias_int (spar_sqlgen_t *ssg, SPART *gp, caddr_t alias)
{
  int ctr;
  if (SPAR_GP != SPART_TYPE (gp))
    return NULL;
  if (!strcmp (gp->_.gp.selid, alias))
    return gp;
  for (ctr = BOX_ELEMENTS_INT_0 (gp->_.gp.members); ctr--; /*no step*/)
    {
      SPART *res = ssg_find_gp_by_alias_int (ssg, gp->_.gp.members[ctr], alias);
      if (NULL != res)
        return res;
    }
  return NULL;
}

SPART *ssg_find_gp_by_alias (spar_sqlgen_t *ssg, caddr_t alias)
{
  return ssg_find_gp_by_alias_int (ssg, ssg->ssg_tree->_.req_top.pattern, alias);
}


SPART *ssg_find_gp_by_eq_idx_int (spar_sqlgen_t *ssg, SPART *gp, ptrlong eq_idx)
{
  int ctr;
  if (SPAR_GP != SPART_TYPE (gp))
    return NULL;
  for (ctr = gp->_.gp.equiv_count; ctr--; /*no step*/)
     {
       if (gp->_.gp.equiv_indexes[ctr] == eq_idx)
         return gp;
     }
  for (ctr = BOX_ELEMENTS_INT_0 (gp->_.gp.members); ctr--; /*no step*/)
    {
      SPART *res = ssg_find_gp_by_eq_idx_int (ssg, gp->_.gp.members[ctr], eq_idx);
      if (NULL != res)
        return res;
    }
  return 0;
}

SPART *ssg_find_gp_by_eq_idx (spar_sqlgen_t *ssg, ptrlong eq_idx)
{
  return ssg_find_gp_by_eq_idx_int (ssg, ssg->ssg_tree->_.req_top.pattern, eq_idx);
}


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


void ssg_print_tmpl (struct spar_sqlgen_s *ssg, rdf_ds_field_t *field, ccaddr_t tmpl, caddr_t alias, SPART *tree)
{
  const char *tail, *tmpl_end;
  const char *delim_hit;
  int cmdlen;
  tail = tmpl;
  tmpl_end = tail; while ('\0' != tmpl_end[0]) tmpl_end++;

  while (tail < tmpl_end)
    {
      delim_hit = strstr (tail, "^{");
      if (NULL == delim_hit)
        {
          session_buffered_write (ssg->ssg_out, tail, tmpl_end - tail);
          return;
        }
      session_buffered_write (ssg->ssg_out, tail, delim_hit - tail);
      tail = delim_hit + 2;
      delim_hit = strstr (tail, "}^");
      if (NULL == delim_hit)
        spar_sqlprint_error ("rdfd_tmpl_print_virtsql(): syntax error in template string");
      cmdlen = delim_hit - tail;
#define CMD_EQUAL(l,w) ((l == cmdlen) && (!memcmp (w, tail, l)))
      if (CMD_EQUAL(5, "alias"))
        {
          if (NULL == alias)
            spar_sqlprint_error ("rdfd_tmpl_print_virtsql(): can't print NULL alias");
          ssg_puts (alias);
        }
      else if (CMD_EQUAL(9, "alias-dot"))
        {
          if (NULL != alias)
            {
              ssg_prin_id (ssg, alias);
              ssg_putchar ('.');
            }
        }
      else if (CMD_EQUAL(4, "tree"))
        {
          if (NULL == tree)
            ssg_print_tmpl (ssg, field, field->rdfdf_short_tmpl, alias, NULL);
          else
            ssg_print_scalar_expn (ssg, tree, SSG_VALMODE_AUTO);
        }
      else if (CMD_EQUAL (14, "sqlval-of-tree"))
        ssg_print_scalar_expn (ssg, tree, SSG_VALMODE_SQLVAL);
      else if (CMD_EQUAL (16, "datatype-of-tree"))
        ssg_print_scalar_expn (ssg, tree, SSG_VALMODE_DATATYPE);
      else if (CMD_EQUAL (16, "language-of-tree"))
        ssg_print_scalar_expn (ssg, tree, SSG_VALMODE_LANGUAGE);
      else
        spar_sqlprint_error ("rdfd_tmpl_print_virtsql(): unsupported keyword in ^{...}^");
      tail = delim_hit + 2;
    }
  return;
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
  int var_count, var_ctr;
  ssg_valmode_t shortest_common;
  int gp_member_idx;
  int notnull_found = 0;
  int first_notnull = 0;
  if (NULL == eq)
    return NULL;
  if (SPART_VARR_FIXED & eq->e_restrictions)
    {
      return SSG_VALMODE_SQLVAL;
    }
  var_count = eq->e_var_count;
  for (var_ctr = 0; var_ctr < var_count; var_ctr++)
    {
      SPART *var = eq->e_vars[var_ctr];
      caddr_t tabid = var->_.var.tabid;
      if (NULL == tabid)
        continue; /* because next loop will do complex cases with care, and OPTIONs are not good candiates if there are SPART_VARR_NOT_NULL items */
      return rdf_ds_field_tr_fields + var->_.var.tr_idx; /* !!!TBD: smallest common (e.g. SSG_VALMODE_LONG) for triples that are unions, correct selection for non-default from hashtable */
    }
  shortest_common = NULL;
  DO_BOX_FAST (SPART *, gp_member, gp_member_idx, gp->_.gp.members)
    {
      sparp_equiv_t *member_eq;
      ssg_valmode_t member_valmode;
      if (SPAR_GP != SPART_TYPE (gp_member))
        continue;
      member_eq = sparp_equiv_get_subvalue_ro (ssg->ssg_equivs, ssg->ssg_equiv_count, gp_member, eq);
      if (NULL == member_eq)
        continue;
      if (member_eq->e_restrictions & SPART_VARR_NOT_NULL)
        {
          if (!notnull_found)
            {
              notnull_found = 1;
              first_notnull = 1;
            }
        }
      else if (notnull_found)
        continue;
      member_valmode = ssg_equiv_native_valmode (ssg, gp_member, member_eq);
      if (NULL == member_valmode)
        continue;
      if ((NULL == shortest_common) || first_notnull)
        {
          shortest_common = member_valmode;
          first_notnull = 0;
          continue;
        }
      if (UNION_L == gp->_.gp.subtype)
        {
          shortest_common = ssg_shortest_valmode (shortest_common, member_valmode);
          continue;
        }
      if (IS_BOX_POINTER (member_valmode))
        {
          if ((!IS_BOX_POINTER (shortest_common)) || RDF_DS_FIELD_SUBFORMAT_OF (member_valmode, shortest_common))
            shortest_common = member_valmode;
        }
      else if (SSG_VALMODE_SQLVAL == shortest_common)
        shortest_common = member_valmode;
    }
  END_DO_BOX_FAST;
  return shortest_common;
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
    case SPAR_QNAME_NS:
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
      if (SPART_VARR_FIXED & tree->_.var.restrictions)
        return SSG_VALMODE_SQLVAL;
      else if (SPART_VARR_GLOBAL & tree->_.var.restrictions)
        return ssg_rettype_of_global_param (ssg, tree->_.var.vname);
      else
        {
          ptrlong eq_idx = tree->_.var.equiv_idx;
          sparp_equiv_t *eq = ssg->ssg_equivs[eq_idx];
          SPART *gp = ssg_find_gp_by_eq_idx (ssg, eq_idx);
          return ssg_equiv_native_valmode (ssg, gp, eq);
        }
    case SPAR_RETVAL:
      if (SPART_VARNAME_IS_GLOB (tree->_.var.vname))
        return ssg_rettype_of_global_param (ssg, tree->_.var.vname);
      else if (NULL != tree->_.var.tabid)
        return rdf_ds_field_tr_fields + tree->_.var.tr_idx; /* !!!TBD: smallest common (e.g. SSG_VALMODE_LONG) for triples that are unions, correct selection for non-default from hashtable */
      else
        {
          SPART *gp = ssg_find_gp_by_alias (ssg, tree->_.var.selid);
          sparp_equiv_t *eq = sparp_equiv_get_ro (
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
      buffill = sprintf (tmpbuf, "NULL");
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
      spar_error (ssg->ssg_sparp, "Current implementation of SPARQL does not supprts literals of type %s", dv_type_title (dtp));
      }
  session_buffered_write (ssg->ssg_out, tmpbuf, buffill);
  BOX_DONE (tmpbuf, smallbuf);
}

void
ssg_print_literal (spar_sqlgen_t *ssg, ccaddr_t type, SPART *lit)
{
  caddr_t value;
  if (DV_ARRAY_OF_POINTER == DV_TYPE_OF (lit))
    {
      if (SPAR_LIT == lit->type)
        value = lit->_.lit.val;
      else if ((SPAR_QNAME == lit->type) || (SPAR_QNAME_NS == lit->type))
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
      else if ((SPAR_QNAME == lit->type) || (SPAR_QNAME_NS == lit->type))
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
ssg_print_equiv (spar_sqlgen_t *ssg, caddr_t selectid, sparp_equiv_t *eq, caddr_t as_name)
{
  caddr_t name_as_expn = NULL;
  if (SPART_VARR_FIXED & eq->e_restrictions)
    ssg_print_literal (ssg, NULL, eq->e_fixedvalue);
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
  if ((NULL != as_name) &&
    ((NULL == name_as_expn) || strcmp (as_name, name_as_expn)) )
    {
      ssg_puts (" AS ");
      ssg_prin_id (ssg, as_name);
    }
}

static const char *field_names[] = {"G", "S", "P", "O"};

void
ssg_print_tr_field_expn (spar_sqlgen_t *ssg, rdf_ds_field_t *field, caddr_t tabid, ssg_valmode_t valmode)
{
  ccaddr_t tmpl = NULL;
  if (NULL == tabid)
    spar_sqlprint_error ("ssg_print_tr_field_expn(): no tabid");
  if ((SSG_VALMODE_SHORT == valmode) ||
    (IS_BOX_POINTER (valmode) && RDF_DS_FIELD_SUBFORMAT_OF (valmode, field)) )
    tmpl = field->rdfdf_short_tmpl;
  else if (SSG_VALMODE_LONG == valmode)
    tmpl = field->rdfdf_long_tmpl;
  else if (SSG_VALMODE_SQLVAL == valmode)
    tmpl = field->rdfdf_sqlval_tmpl;
  else if (SSG_VALMODE_BOOL == valmode)
    tmpl = field->rdfdf_bool_tmpl;
  else
    spar_sqlprint_error ("ssg_print_tr_field_expn(): unsupported valmode");
  ssg_print_tmpl (ssg, field, tmpl, tabid, NULL);
}

void
ssg_print_tr_var_expn (spar_sqlgen_t *ssg, SPART *var, ssg_valmode_t needed)
{
  SPART_buf rv_buf;
  SPART *rv;
  caddr_t tabid = var->_.var.tabid;
  if (NULL == tabid)
    spar_sqlprint_error ("ssg_print_tr_var_expn(): no tabid");
/*!!!TBD*/
  SPART_AUTO (rv, rv_buf, SPAR_RETVAL);
  memcpy (&(rv->_.var), &(var->_.var), sizeof (rv->_.var));
  rv->_.var.vname = (caddr_t)(field_names[var->_.var.tr_idx]); /* Stub here. */
  ssg_print_valmoded_scalar_expn (ssg, rv, needed, ssg_expn_native_valmode (ssg, rv));
}

ssg_valmode_t
ssg_shortest_valmode (ssg_valmode_t m1, ssg_valmode_t m2)
{
  if (m2 == m1)
    return m1;
  if (m2 < m1)
    return ssg_shortest_valmode (m2, m1);
  /* Now m1 is less than m2 */
  if (SSG_VALMODE_BOOL == m2)
    return SSG_VALMODE_BOOL;
  if (IS_BOX_POINTER (m2))
    {
      if (IS_BOX_POINTER (m1))
        {
          if (RDF_DS_FIELD_SUBFORMAT_OF(m1,m2))
            return m2;
          if (RDF_DS_FIELD_SUBFORMAT_OF(m2,m1))
            return m1;
        }
      else if (SSG_VALMODE_SQLVAL == m1)
        {
          if (m2->rdfdf_ok_for_any_sqlvalue)
            return m2;
        }
    }
  return SSG_VALMODE_LONG;
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
      min_mode = ssg_shortest_valmode (left_vmode, right_vmode);
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
          ssg_print_scalar_expn (ssg, left, min_mode);
          ssg_puts (bool_op);
          ssg_print_scalar_expn (ssg, right, min_mode);
        }
      ssg_putchar (')');
    }
  else if ((SSG_VALMODE_SQLVAL == needed) || (SSG_VALMODE_BOOL == needed))
    {
      ssg_puts (sqlval_fn);
      ssg_print_scalar_expn (ssg, left, min_mode);
      ssg_puts (", ");
      ssg_print_scalar_expn (ssg, right, min_mode);
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
  ssg_print_scalar_expn (ssg, left, SSG_VALMODE_SQLVAL);
  ssg_puts (s2);
  if (NULL == s3)
    return;
  ssg_print_scalar_expn (ssg, right, SSG_VALMODE_SQLVAL);
  ssg_puts (s3);
}

void
ssg_print_bop_cmp_expn (spar_sqlgen_t *ssg, SPART *tree, const char *bool_op, const char *sqlval_fn, int top_filter_op, ssg_valmode_t needed)
{
  SPART *left = tree->_.bin_exp.left;
  SPART *right = tree->_.bin_exp.right;
  ssg_valmode_t left_native;
  ssg_valmode_t right_native;
  ssg_valmode_t shortest_common;
  const char *cmp_func_name = NULL;
  if (
    (needed != SSG_VALMODE_SQLVAL) && /* Trick! All representations are equal. */
    (needed != SSG_VALMODE_LONG) &&
    (needed != SSG_VALMODE_BOOL) )
    spar_sqlprint_error ("ssg_print_bop_cmp_expn(): unsupported valmode");
  left_native = ssg_expn_native_valmode (ssg, left);
  right_native = ssg_expn_native_valmode (ssg, right);
  shortest_common = ssg_shortest_valmode (left_native, right_native);
  if (SSG_VALMODE_LONG == shortest_common)
    cmp_func_name = "DB.DBA.RDF_LONG_CMP";
  else if (IS_BOX_POINTER (shortest_common))
    cmp_func_name = shortest_common->rdfdf_cmp_func_name;
  else
    { /* Fallback to usual SQL comparison, with possible lack of type checking. */
      ssg_print_bop_bool_expn (ssg, tree, bool_op, sqlval_fn, top_filter_op, needed);
      return;
    }
  if (top_filter_op &&
    IS_BOX_POINTER (shortest_common) &&
    ((SPAR_VARIABLE == SPART_TYPE (left)) || (SPAR_BLANK_NODE_LABEL == SPART_TYPE (left)) ||
      (SPAR_VARIABLE == SPART_TYPE (right)) || (SPAR_BLANK_NODE_LABEL == SPART_TYPE (right)) ) )
    { /* Comparison taht is partially optimizeable for indexing */
      const char *typemin, *typemax;
      ssg_puts ("((");
      ssg->ssg_indent += 2;
      ssg_print_scalar_expn (ssg, left, shortest_common);
      ssg_puts (bool_op);
      ssg_print_scalar_expn (ssg, right, shortest_common);
      ssg_puts (") AND");
      ssg_newline(SSG_INDENT_FACTOR);
      ssg_puts ("(");
#if 1
      typemin = shortest_common->rdfdf_typemin_tmpl;
      typemax = shortest_common->rdfdf_typemax_tmpl;
#endif
      if ((BOP_LT == SPART_TYPE (tree)) || (BOP_LTE == SPART_TYPE (tree)))
        {
#if 0
          if (SSG_VALMODE_SQLVAL == right_native)
            typemin = " DB.DBA.RDF_TYPEMIN_OF_SQLVAL (^{tree}^)";
          else
            typemin = right_native->rdfdf_typemin_tmpl;
          if (SSG_VALMODE_SQLVAL == left_native)
            typemax = " DB.DBA.RDF_TYPEMAX_OF_SQLVAL (^{tree}^)";
          else
            typemax = left_native->rdfdf_typemax_tmpl;
#endif
          ssg_print_tmpl (ssg, shortest_common, typemin, NULL, right);
          ssg_puts (" <=");
          ssg_print_scalar_expn (ssg, left, shortest_common);
          ssg_puts (") AND");
          ssg_newline(SSG_INDENT_FACTOR);
          ssg_puts ("(");
          ssg_print_scalar_expn (ssg, right, shortest_common);
          ssg_puts (" <=");
          ssg_print_tmpl (ssg, shortest_common, typemax, NULL, left);
        }
      else
        {
#if 0
          if (SSG_VALMODE_SQLVAL == right_native)
            typemax = " DB.DBA.RDF_TYPEMAX_OF_SQLVAL (^{tree}^)";
          else
            typemax = right_native->rdfdf_typemax_tmpl;
          if (SSG_VALMODE_SQLVAL == left_native)
            typemin = " DB.DBA.RDF_TYPEMIN_OF_SQLVAL (^{tree}^)";
          else
            typemin = left_native->rdfdf_typemin_tmpl;
#endif
          ssg_print_tmpl (ssg, shortest_common, typemax, NULL, right);
          ssg_puts (" >=");
          ssg_print_scalar_expn (ssg, left, shortest_common);
          ssg_puts (") AND");
          ssg_newline(SSG_INDENT_FACTOR);
          ssg_puts ("(");
          ssg_print_scalar_expn (ssg, right, shortest_common);
          ssg_puts (" >=");
          ssg_print_tmpl (ssg, shortest_common, typemin, NULL, left);
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
      ssg_print_scalar_expn (ssg, left, shortest_common);
      ssg_puts (" ,");
      ssg_print_scalar_expn (ssg, right, shortest_common);
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
      ssg_print_scalar_expn (ssg, left, shortest_common);
      ssg_puts (" ,");
      ssg_print_scalar_expn (ssg, right, shortest_common);
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
          ssg_puts (" ("); ssg_print_scalar_expn (ssg, arg1, arg1_native); ssg_puts (" is not null)");
        }
      else
        {
          ssg_puts ("(0 = isnull ("); ssg_print_scalar_expn (ssg, arg1, arg1_native); ssg_puts ("))");
        }
      return;
    case DATATYPE_L:
      if (SSG_VALMODE_SQLVAL != needed)
        ssg_print_valmoded_scalar_expn (ssg, tree, needed, SSG_VALMODE_SQLVAL);
      else
        ssg_print_scalar_expn (ssg, arg1, SSG_VALMODE_DATATYPE);
      return;
    case LIKE_L:
      if (SSG_VALMODE_BOOL != needed)
        ssg_print_valmoded_scalar_expn (ssg, tree, needed, SSG_VALMODE_BOOL);
      else
        {
          ssg_puts (" (cast ("); ssg_print_scalar_expn (ssg, arg1, SSG_VALMODE_SQLVAL);
          ssg_puts (" as varchar) like cast ("); ssg_print_scalar_expn (ssg, tree->_.builtin.args[1], SSG_VALMODE_SQLVAL);
          ssg_puts (" as varchar))"); 
        }
      return;
    case IN_L:
      if (SSG_VALMODE_BOOL != needed)
        ssg_print_valmoded_scalar_expn (ssg, tree, needed, SSG_VALMODE_BOOL);
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
          if ((SSG_VALMODE_LONG == op_fmt) || (IS_BOX_POINTER (op_fmt) && op_fmt->rdfdf_ok_for_any_sqlvalue))
            op_fmt = SSG_VALMODE_SQLVAL;
          DO_BOX_FAST (SPART *, argN, argctr, tree->_.builtin.args)
            {
              switch (argctr)
                {
                case 0: ssg_puts (top_filter_op ? " (" : " position ("); break;
                case 1: ssg_puts (top_filter_op ? " in (" : ", vector ("); break;
                default: ssg_puts (" ,");
                }
              ssg_print_scalar_expn (ssg, argN, op_fmt);
            }
          END_DO_BOX_FAST;
          ssg_puts ("))");
        }
      return;
    case isBLANK_L:
      if (SSG_VALMODE_BOOL != needed)
        ssg_print_valmoded_scalar_expn (ssg, tree, needed, SSG_VALMODE_BOOL);
      else
      {
        if (IS_BOX_POINTER (arg1_native))
          ssg_print_tmpl (ssg, arg1_native, arg1_native->rdfdf_isblank_of_short_tmpl, NULL, arg1);
        else if (SSG_VALMODE_LONG == arg1_native)
          ssg_print_tmpl (ssg, arg1_native,
            (top_filter_op ?
                " ((isiri_id (^{tree}^) and (^{tree}^ >= #i1000000000))" :
                " either (isiri_id (^{tree}^), gte (^{tree}^, #i1000000000), 0)" ),
            NULL, arg1 );
        else if (SSG_VALMODE_SQLVAL == arg1_native)
          ssg_print_tmpl (ssg, arg1_native, " DB.DBA.RDF_IS_BLANK_REF (^{tree}^)", NULL, arg1);
        else
          spar_sqlprint_error ("ssg_print_scalar_expn(): bad native type for isBLANK()");
      }
      return;
    case LANG_L:
      if (SSG_VALMODE_SQLVAL != needed)
        ssg_print_valmoded_scalar_expn (ssg, tree, needed, SSG_VALMODE_SQLVAL);
      else
        ssg_print_scalar_expn (ssg, arg1, SSG_VALMODE_LANGUAGE);
      return;
    case isURI_L:
    case isIRI_L:
      if (SSG_VALMODE_BOOL != needed)
        ssg_print_valmoded_scalar_expn (ssg, tree, needed, SSG_VALMODE_BOOL);
      else
      {
        if (IS_BOX_POINTER (arg1_native))
          ssg_print_tmpl (ssg, arg1_native, arg1_native->rdfdf_isuri_of_short_tmpl, NULL, arg1);
        else if (SSG_VALMODE_LONG == arg1_native)
          ssg_print_tmpl (ssg, arg1_native,
            (top_filter_op ?
                " ((isiri_id (^{tree}^) and (^{tree}^ < 1000000000))" :
                " either (isiri_id (^{tree}^), lt (^{tree}^, 1000000000), 0)" ),
            NULL, arg1 );
        else if (SSG_VALMODE_SQLVAL == arg1_native)
          ssg_print_tmpl (ssg, arg1_native, " DB.DBA.RDF_IS_URI_REF (^{tree}^)", NULL, arg1);
        else
          spar_sqlprint_error ("ssg_print_scalar_expn(): bad native type for isURI()");
      }
      return;
    case isLITERAL_L:
      if (SSG_VALMODE_BOOL != needed)
        ssg_print_valmoded_scalar_expn (ssg, tree, needed, SSG_VALMODE_BOOL);
      else
      {
        if (IS_BOX_POINTER (arg1_native))
          ssg_print_tmpl (ssg, arg1_native, arg1_native->rdfdf_islit_of_short_tmpl, NULL, arg1);
        else if (SSG_VALMODE_LONG == arg1_native)
          ssg_print_tmpl (ssg, arg1_native,
            (top_filter_op ?
                " (not (isiri_id (^{tree}^))" : "(0 = isiri_id (^{tree}^))" ),
            NULL, arg1);
        else if (SSG_VALMODE_SQLVAL == arg1_native)
          ssg_print_tmpl (ssg, arg1_native, " DB.DBA.RDF_IS_LITERAL (^{tree}^)", NULL, arg1);
        else
          spar_sqlprint_error ("ssg_print_scalar_expn(): bad native type for isLITERAL()");
      }
      return;
    case IRI_L:
      spar_sqlprint_error ("ssg_print_scalar_expn(): sorry, IRI built-in is not implemented");
    case STR_L:
      {
        if (SSG_VALMODE_SQLVAL != needed)
          {
            ssg_print_valmoded_scalar_expn (ssg, tree, needed,
              (SSG_VALMODE_SQLVAL == arg1_native) ? SSG_VALMODE_SQLVAL : SSG_VALMODE_LONG );
          }
        else
          {
            const char *tmpl;
            if (IS_BOX_POINTER (arg1_native))
              tmpl = arg1_native->rdfdf_strsqlval_of_short_tmpl;
            else if (SSG_VALMODE_LONG == arg1_native)
              tmpl = " DB.DBA.RDF_STRSQLVAL_OF_LONG (^{tree}^)";
            else if (SSG_VALMODE_SQLVAL == arg1_native)
              tmpl = " DB.DBA.RDF_STRSQLVAL_OF_SQLVAL (^{tree}^)";
            else if (SSG_VALMODE_BOOL == arg1_native)
              tmpl = " case (^{tree}^) when 0 then 'false' else 'true' end";
            else
              spar_sqlprint_error ("ssg_print_scalar_expn(): bad native type for STR()");
            ssg_print_tmpl (ssg, arg1_native, tmpl, NULL, arg1);
          }
        return;
      }
    case REGEX_L:
      if (SSG_VALMODE_BOOL != needed)
        ssg_print_valmoded_scalar_expn (ssg, tree, needed, SSG_VALMODE_BOOL);
      else
        { /*!!!TBD extra 'between'*/
          ssg_puts (" DB.DBA.RDF_REGEX (");
          ssg_print_scalar_expn (ssg, arg1, SSG_VALMODE_SQLVAL);
          ssg_putchar (',');
          ssg_print_scalar_expn (ssg, tree->_.builtin.args[1], SSG_VALMODE_SQLVAL);
          if (3 == BOX_ELEMENTS (tree->_.builtin.args))
            {
              ssg_putchar (',');
              ssg_print_scalar_expn (ssg, tree->_.builtin.args[2], SSG_VALMODE_SQLVAL);
            }
          ssg_putchar (')');
        }
      return;
    case LANGMATCHES_L:
      if (SSG_VALMODE_BOOL != needed)
        ssg_print_valmoded_scalar_expn (ssg, tree, needed, SSG_VALMODE_BOOL);
      else
        {
          ssg_puts (" DB.DBA.RDF_LANGMATCHES (");
          ssg_print_scalar_expn (ssg, arg1, SSG_VALMODE_SQLVAL);
          ssg_putchar (',');
          ssg_print_scalar_expn (ssg, tree->_.builtin.args[1], SSG_VALMODE_SQLVAL);
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
    return SSG_VALMODE_SHORT;
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

void ssg_print_uri_list (spar_sqlgen_t *ssg, dk_set_t uris, ssg_valmode_t needed)
{
  int uri_ctr = 0;
  DO_SET (SPART *, expn, &uris)
    {
      if (uri_ctr++)
        ssg_puts (", ");
      ssg_print_scalar_expn (ssg, expn, needed);
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
      caddr_t defined_uri = env->spare_default_graph_uri;
      if (NULL != defined_uri)
        {
          if (env->spare_default_graph_locked)
            {
              ssg_print_scalar_expn (ssg, (SPART *)defined_uri, needed);
              return;
            }
          ssg_puts (" coalesce (connection_get ('");
          ssg_puts (vname);
          ssg_puts ("'),");
          ssg->ssg_indent += 1;
          ssg_print_scalar_expn (ssg, (SPART *)defined_uri, needed);
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
      dk_set_t defined_uris = env->spare_named_graph_uris;
      if (0 != dk_set_length (defined_uris))
        {
          if (env->spare_named_graphs_locked)
            {
              ssg_puts (" vector (");
              ssg->ssg_indent += 1;
              ssg_print_uri_list (ssg, defined_uris, needed);
              ssg->ssg_indent -= 1;
              ssg_puts (")");
              return;
            }
          ssg_puts (" coalesce (connection_get ('");
          ssg_puts (vname);
          ssg_puts ("'), vector (");
          ssg->ssg_indent += 2;
          ssg_print_uri_list (ssg, defined_uris, needed);
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
ssg_tmpl_X_of_short (ssg_valmode_t needed, rdf_ds_field_t *fld)
{
  if (SSG_VALMODE_LONG == needed)
    return fld->rdfdf_long_of_short_tmpl;
  if (SSG_VALMODE_SQLVAL == needed)
    return fld->rdfdf_sqlval_of_short_tmpl;
  if (SSG_VALMODE_DATATYPE == needed)
    return fld->rdfdf_datatype_of_short_tmpl;
  if (SSG_VALMODE_LANGUAGE == needed)
    return fld->rdfdf_language_of_short_tmpl;
  if (SSG_VALMODE_BOOL == needed)
    return fld->rdfdf_bool_of_short_tmpl;
  spar_internal_error (NULL, "ssg_tmpl_X_of_short(): bad mode needed");
  return NULL; /* Never reached, to keep compiler happy */
}

const char *ssg_tmpl_short_of_X (rdf_ds_field_t *fld, ssg_valmode_t native)
{
  if (SSG_VALMODE_LONG == native)	return fld->rdfdf_short_of_long_tmpl;
  if (SSG_VALMODE_SQLVAL == native)	return fld->rdfdf_short_of_sqlval_tmpl;
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
ssg_print_valmoded_scalar_expn (spar_sqlgen_t *ssg, SPART *tree, ssg_valmode_t needed, ssg_valmode_t native)
{
  if (native == needed)
    {
      ssg_print_scalar_expn (ssg, tree, native);
      return;
    }
  if (SSG_VALMODE_BOOL == native)
    {
      ssg_print_scalar_expn (ssg, tree, needed);
      return;
    }
  if (IS_BOX_POINTER (native))
    {
      if (IS_BOX_POINTER (needed))
        {
          SPART_buf fromshort_buf;
          SPART *fromshort;
          if (RDF_DS_FIELD_SUBFORMAT_OF(native,needed)) /* short native and short needed are actually the same in byte layout */
            {
              ssg_print_scalar_expn (ssg, tree, native);
              return;
            }
          SPART_AUTO(fromshort,fromshort_buf,SPAR_CONV);
          fromshort->_.conv.arg = tree;
          fromshort->_.conv.native = native;
          fromshort->_.conv.needed = SSG_VALMODE_LONG;
          ssg_print_scalar_expn (ssg, fromshort, needed);
          return;
        }
      ssg_print_tmpl (ssg, native, ssg_tmpl_X_of_short (needed, native), NULL, tree);
      return;
    }
  if (IS_BOX_POINTER (needed))
    {
      ssg_print_tmpl (ssg, needed, ssg_tmpl_short_of_X (needed, native), NULL, tree);
      return;
    }
  ssg_print_tmpl (ssg, NULL, ssg_tmpl_X_of_Y (needed, native), NULL, tree);
  return;
}


void
ssg_print_scalar_expn (spar_sqlgen_t *ssg, SPART *tree, ssg_valmode_t needed)
{
  if (SSG_VALMODE_AUTO == needed)
    needed = ssg_expn_native_valmode (ssg, tree);
  switch (SPART_TYPE (tree))
    {
    case BOP_AND:	ssg_print_bop_bool_expn (ssg, tree, " AND "	, " __and ("	, 0, SSG_VALMODE_BOOL); return;
    case BOP_OR:	ssg_print_bop_bool_expn (ssg, tree, " OR "	, " __or ("	, 0, SSG_VALMODE_BOOL); return;
    case BOP_EQ:	ssg_print_bop_bool_expn (ssg, tree, " = "	, " equ ("	, 0, SSG_VALMODE_BOOL); return;
    case BOP_NEQ:	ssg_print_bop_bool_expn (ssg, tree, " <> "	, " neq ("	, 0, SSG_VALMODE_BOOL); return;
    case BOP_LT:	ssg_print_bop_bool_expn (ssg, tree, " < "	, " lt ("	, 0, SSG_VALMODE_BOOL); return;
    case BOP_LTE:	ssg_print_bop_bool_expn (ssg, tree, " <= "	, " lte ("	, 0, SSG_VALMODE_BOOL); return;
    case BOP_GT:	ssg_print_bop_bool_expn (ssg, tree, " > "	, " gt ("	, 0, SSG_VALMODE_BOOL); return;
    case BOP_GTE:	ssg_print_bop_bool_expn (ssg, tree, " >= "	, " gte ("	, 0, SSG_VALMODE_BOOL); return;
   /*case BOP_LIKE: Like is built-in in SPARQL, not a BOP!
			ssg_print_bop_bool_expn (ssg, tree, " like "	, " strlike ("	, 0, SSG_VALMODE_BOOL); return; */
/*
    case BOP_SAME:	ssg_print_bop_bool_expn (ssg, tree, "(", "= ", ")"); return;
    case BOP_NSAME:	ssg_print_bop_bool_expn (ssg, tree, "(", "= ", ")"); return;
*/
    case BOP_NOT:
      {
        if ((SSG_VALMODE_BOOL == needed) || (SSG_VALMODE_SQLVAL == needed))
          {
            ssg_puts (" __not ("); ssg_print_scalar_expn (ssg, tree->_.bin_exp.left, SSG_VALMODE_SQLVAL); ssg_putchar (')');
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
        return;
      }
    case BOP_PLUS:	ssg_print_bop_calc_expn (ssg, tree, " (", " + ", ")"); return;
    case BOP_MINUS:	ssg_print_bop_calc_expn (ssg, tree, " (", " - ", ")"); return;
    case BOP_TIMES:	ssg_print_bop_calc_expn (ssg, tree, " (", " * ", ")"); return;
    case BOP_DIV:	ssg_print_bop_calc_expn (ssg, tree, " div (", ", ", ")"); return;
    case BOP_MOD:	ssg_print_bop_calc_expn (ssg, tree, " mod (", ", ", ")"); return;
    case SPAR_BLANK_NODE_LABEL:
    case SPAR_VARIABLE:
      {
#if 0
        ssg_valmode_t vmode = ssg_expn_native_valmode (ssg, tree);
        if (vmode == needed)
          {
            sparp_equiv_t *eq = ssg->ssg_equivs[tree->_.var.equiv_idx];
            ssg_print_equiv_retval_expn (ssg, ssg_find_gp_by_alias (ssg, tree->_.var.selid), eq, 0, 1, NULL, needed);
          }
        else
          ssg_print_valmoded_scalar_expn (ssg, tree, needed, vmode);
#else
        sparp_equiv_t *eq = ssg->ssg_equivs[tree->_.var.equiv_idx];
        SPART *gp = ssg_find_gp_by_alias (ssg, tree->_.var.selid);
        ssg_print_equiv_retval_expn (ssg, gp, eq, SSG_RETVAL_FROM_JOIN_MEMBER | SSG_RETVAL_MUST_PRINT_SOMETHING , NULL, needed);
#endif
        return;
      }
    case SPAR_BUILT_IN_CALL:
      {
        ssg_print_builtin_expn (ssg, tree, 0, needed);
        return;
      }
    case SPAR_CONV:
      {
        if ((tree->_.conv.needed == needed) ||
          ( IS_BOX_POINTER (tree->_.conv.needed) &&
            IS_BOX_POINTER (needed) &&
            RDF_DS_FIELD_SUBFORMAT_OF(tree->_.conv.needed, needed) ) )
          ssg_print_valmoded_scalar_expn (ssg, tree->_.conv.arg, tree->_.conv.needed, tree->_.conv.native);
        else
          ssg_print_valmoded_scalar_expn (ssg, tree, needed, tree->_.conv.needed);
        return;
      }
    case SPAR_FUNCALL:
      {
        int bigtext, arg_ctr, arg_count = tree->_.funcall.argcount;
        xqf_str_parser_desc_t *parser_desc;
	ssg_valmode_t native = ssg_rettype_of_function (ssg, tree->_.funcall.qname);
        if (native != needed)
          {
            ssg_print_valmoded_scalar_expn (ssg, tree, needed, native);
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
                ssg_print_scalar_expn (ssg, tree->_.funcall.argtrees[arg_ctr], SSG_VALMODE_SQLVAL);
              }
            ssg->ssg_indent--;
            ssg_putchar (')');
            return;
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
            ssg_print_scalar_expn (ssg, tree->_.funcall.argtrees[arg_ctr], argtype);
          }
        ssg->ssg_indent--;
        ssg_putchar (')');
        return;
      }
    case SPAR_LIT:
      {
        if (SSG_VALMODE_DATATYPE == needed)
          {
            if (DV_ARRAY_OF_POINTER != DV_TYPE_OF (tree))
              {
                ssg_puts (" DB.DBA.RDF_DATATYPE_OF_TAG (__tag ("); /* !!!TBD Replace with something less ugly when twobyte of every predefined type is fixed */
                ssg_print_literal (ssg, NULL, (SPART *)(tree->_.lit.datatype));
                ssg_puts ("))");
              }
            else if (NULL != tree->_.lit.datatype)
              ssg_print_literal (ssg, NULL, (SPART *)(tree->_.lit.datatype));
            else
              ssg_puts (" NULL");
          }
        else if (SSG_VALMODE_LANGUAGE == needed)
          {
            if (DV_ARRAY_OF_POINTER != DV_TYPE_OF (tree))
              ssg_puts (" NULL");
            else if (NULL != tree->_.lit.language)
              ssg_print_literal (ssg, NULL, (SPART *)(tree->_.lit.language));
            else
              ssg_puts (" NULL");
          }
        else if (SSG_VALMODE_LONG == needed)
          {
            ssg_print_literal_as_long (ssg, tree);
          }
        else if (SSG_VALMODE_SQLVAL != needed)
          ssg_print_valmoded_scalar_expn (ssg, tree, needed, SSG_VALMODE_SQLVAL);
        else
          ssg_print_literal (ssg, NULL, tree);
        return;
      }
    case SPAR_QNAME:
    case SPAR_QNAME_NS:
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
        ssg_print_valmoded_scalar_expn (ssg, tree, needed, SSG_VALMODE_SQLVAL);
      else
        ssg_print_literal (ssg, NULL, tree);
      return;
    case SPAR_RETVAL:
      {
        ssg_valmode_t vmode = ssg_expn_native_valmode (ssg, tree);
        if (vmode == needed)
          {
            if (SPART_VARNAME_IS_GLOB(tree->_.var.vname))
              ssg_print_global_param (ssg, tree->_.var.vname, needed);
            else
              {
                ssg_putchar (' ');
                if (NULL != tree->_.var.tabid)
                  {
                    ssg_prin_id (ssg, tree->_.var.tabid);
                    ssg_putchar ('.');
                  }
                else if (NULL != tree->_.var.selid)
                  {
                    ssg_prin_id (ssg, tree->_.var.selid);
                    ssg_putchar ('.');
                  }
                ssg_prin_id (ssg, tree->_.var.vname);
                ssg_puts (" /* ");
                ssg_puts (ssg->ssg_equivs[tree->_.var.equiv_idx]->e_varnames[0]);
                ssg_puts (" */");
              }
          }
        else
          ssg_print_valmoded_scalar_expn (ssg, tree, needed, vmode);
        return;
      }
    default:
      spar_sqlprint_error ("ssg_print_scalar_expn(): unsupported scalar expression type");
      return;
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
  ssg_print_scalar_expn (ssg, tree, SSG_VALMODE_BOOL);
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


SPART *
ssg_find_global_in_equiv (sparp_equiv_t *eq)
{
  int ctr;
  for (ctr = eq->e_var_count; ctr--; /* no step */)
    {
      SPART *var = eq->e_vars[ctr];
      if (SPART_VARNAME_IS_GLOB(var->_.var.vname))
        return var;
    }
  return NULL;
}

void
ssg_print_fld_lit_restrictions (spar_sqlgen_t *ssg, rdf_ds_t *ds, rdf_ds_field_t *field, caddr_t tabid, SPART *fld_tree)
{
  ptrlong field_restr = field->rdfdf_restrictions;
/*  caddr_t litvalue = ((DV_ARRAY_OF_POINTER == DV_TYPE_OF (fld_tree)) ? fld_tree->_.lit.val : (caddr_t)fld_tree);*/
  caddr_t litvalue, littype, litlang;
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
      if ((DVC_MATCH == cmp_boxes ((caddr_t)(field->rdfdf_datatype), littype, NULL, NULL)) &&
        (DVC_MATCH == cmp_boxes ((caddr_t)(field->rdfdf_fixedvalue), litvalue, NULL, NULL)) )
        return;
    }
  if (!(SPART_VARR_IS_LIT & field_restr))
    {
      ssg_print_where_or_and (ssg, "obj field is a literal");
      ssg_print_tmpl (ssg, field, field->rdfdf_islit_of_short_tmpl, tabid, NULL);
    }
  ssg_print_where_or_and (ssg, "field equal to literal, quick test");
  ssg_print_tr_field_expn (ssg, field, tabid, SSG_VALMODE_SHORT);
  ssg_puts (" = ");
  if ((DV_STRING == DV_TYPE_OF (litvalue)) &&
    ((NULL != littype) || (NULL != litlang)) )
    ssg_print_tmpl (ssg, field, field->rdfdf_short_of_typedsqlval_tmpl, tabid, fld_tree);
  else
    ssg_print_tmpl (ssg, field, field->rdfdf_short_of_sqlval_tmpl, tabid, (SPART *)litvalue);
/*  ssg_print_where_or_and (ssg, "field equal to literal, full test");
  ssg_print_tr_field_expn (ssg, field, tabid, SSG_VALMODE_SQLVAL);
  ssg_puts (" = ");
  ssg_print_literal (ssg, NULL, (SPART *)litvalue);*/
}

void
ssg_print_fld_uri_restrictions (spar_sqlgen_t *ssg, rdf_ds_t *ds, rdf_ds_field_t *field, caddr_t tabid, caddr_t uri)
{
  ptrlong field_restr = field->rdfdf_restrictions;
  if ((SPART_VARR_FIXED & field_restr) && (SPART_VARR_IS_REF & field_restr))
    {
      if (DVC_MATCH == cmp_boxes ((caddr_t)(field->rdfdf_fixedvalue), uri, NULL, NULL))
        return;
    }
  if (!(SPART_VARR_IS_REF & field_restr))
    {
      ssg_print_where_or_and (ssg, "node field is a URI ref");
      ssg_print_tmpl (ssg, field, field->rdfdf_isref_of_short_tmpl, tabid, NULL);
    }
  ssg_print_where_or_and (ssg, "field equal to URI ref");
  ssg_print_tr_field_expn (ssg, field, tabid, SSG_VALMODE_SHORT);
  ssg_puts (" = ");
  ssg_print_tmpl (ssg, field, field->rdfdf_short_of_uri_tmpl, tabid, (SPART *)uri);
}

void
ssg_print_fld_restrictions (spar_sqlgen_t *ssg, rdf_ds_t *ds, rdf_ds_field_t *field, caddr_t tabid, SPART *fld_tree)
{
  switch (SPART_TYPE (fld_tree))
    {
    case SPAR_LIT:
      {
        ssg_print_fld_lit_restrictions (ssg, ds, field, tabid, fld_tree);
        return;
      }
    case SPAR_QNAME:
    case SPAR_QNAME_NS:
      {
        caddr_t uri = fld_tree->_.lit.val;
        ssg_print_fld_uri_restrictions (ssg, ds, field, tabid, uri);
        return;
      }
    case SPAR_VARIABLE: case SPAR_BLANK_NODE_LABEL:
      {
        ptrlong field_restr = field->rdfdf_restrictions;
        ptrlong tree_restr = fld_tree->_.var.restrictions;
        if ((SPART_VARR_FIXED | SPART_VARR_GLOBAL) & tree_restr)
          return; /* Because this means that equiv has equality on the field that is to be printed later; so there's nothing to do right here */
        if ((SPART_VARR_NOT_NULL & tree_restr) && (!(SPART_VARR_NOT_NULL & field_restr)))
          {
            ssg_print_where_or_and (ssg, "nullable variable is not null");
            ssg_print_tmpl (ssg, field, "(^{alias}^.^{short}^ is not null)", tabid, NULL);
          }
        if ((SPART_VARR_IS_BLANK & tree_restr) && (!(SPART_VARR_IS_BLANK & field_restr)))
          {
            ssg_print_where_or_and (ssg, "variable is blank node");
            ssg_print_tmpl (ssg, field, field->rdfdf_isblank_of_short_tmpl, tabid, NULL);
          }
        else if ((SPART_VARR_IS_IRI & tree_restr) && (!(SPART_VARR_IS_IRI & field_restr)))
          {
            ssg_print_where_or_and (ssg, "variable is IRI");
            ssg_print_tmpl (ssg, field, field->rdfdf_isuri_of_short_tmpl, tabid, NULL);
          }
        else if ((SPART_VARR_IS_REF & tree_restr) && (!(SPART_VARR_IS_REF & field_restr)))
          {
            ssg_print_where_or_and (ssg, "'any' variable is a reference");
            ssg_print_tmpl (ssg, field, field->rdfdf_isref_of_short_tmpl, tabid, NULL);
          }
        else if ((SPART_VARR_IS_LIT & tree_restr) && (!(SPART_VARR_IS_LIT & field_restr)))
          {
            ssg_print_where_or_and (ssg, "'any' variable is a literal");
            ssg_print_tmpl (ssg, field, field->rdfdf_islit_of_short_tmpl, tabid, NULL);
          }
        /*!!! TBD: checks for type, lang */
        return;
      }
    default:
      spar_sqlprint_error ("ssg_print_fld_restrictions(): unsupported type of fld_tree()");
    }
}

int
ssg_print_equiv_retval_expn (spar_sqlgen_t *ssg, SPART *gp, sparp_equiv_t *eq, int flags, caddr_t as_name, ssg_valmode_t needed)
{
  caddr_t name_as_expn = NULL;
  int var_count, var_ctr;
  if (NULL == eq)
    goto try_write_null; /* see below */
  if (SPART_VARR_FIXED & eq->e_restrictions)
    {
      ssg_print_literal (ssg, NULL, eq->e_fixedvalue);
      goto write_assuffix;
    }
  var_count = eq->e_var_count;
  if (SPART_VARR_GLOBAL & eq->e_restrictions)
    {
      for (var_ctr = 0; var_ctr < var_count; var_ctr++)
        {
          SPART *vartree = eq->e_vars[var_ctr];
          if (SPART_VARNAME_IS_GLOB (vartree->_.var.vname))
            {
              ssg_print_global_param (ssg, vartree->_.var.vname, needed);
	      goto write_assuffix;
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
          ssg_print_tr_var_expn (ssg, var, needed);
          goto write_assuffix;
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
          memcpy (&(rv->_.var), &(var->_.var), sizeof (rv->_.var));
          rv->_.var.selid = selid;
          rv->_.var.tabid = NULL;
          native = ssg_expn_native_valmode (ssg, rv);
          if (native == needed)
            name_as_expn = var->_.var.vname;
          ssg_print_valmoded_scalar_expn (ssg, rv, needed, native);
          goto write_assuffix;
        }
      if ((0 == eq->e_var_count) &&
        ((flags & SSG_RETVAL_FROM_ANY_SELECTED) ||
          (UNION_L == gp->_.gp.subtype) || (0 == gp->_.gp.subtype)) )
        { /* Special case of an equiv used only to pass column of UNION to the next level, can print it always */
          SPART_buf rv_buf;
          SPART *rv;
          ssg_valmode_t native;
          SPART_AUTO (rv, rv_buf, SPAR_RETVAL);
          rv->_.var.equiv_idx = eq->e_own_idx;
          rv->_.var.restrictions = eq->e_restrictions;
          rv->_.var.tr_idx = 0;
          rv->_.var.selid = gp->_.gp.selid;
          rv->_.var.tabid = NULL;
          rv->_.var.vname = eq->e_varnames[0];
          native = ssg_expn_native_valmode (ssg, rv);
          if (native == needed)
            name_as_expn = rv->_.var.vname;
          ssg_print_valmoded_scalar_expn (ssg, rv, needed, native);
          goto write_assuffix;
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
        printed = ssg_print_equiv_retval_expn (ssg, gp_member, subval, sub_flags, as_name, needed);
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
        printed = ssg_print_equiv_retval_expn (ssg, gp_member, subval, sub_flags, as_name, needed);
        return printed;
        break;
      }
    }

try_write_null:
  if ((flags & SSG_RETVAL_MUST_PRINT_SOMETHING) &&
    (flags & SSG_RETVAL_FROM_GOOD_SELECTED) && !(flags & SSG_RETVAL_FROM_ANY_SELECTED) )
    return 
      ssg_print_equiv_retval_expn (ssg, gp, eq, flags | SSG_RETVAL_FROM_ANY_SELECTED, as_name, needed);
  if (!(flags & SSG_RETVAL_CAN_PRINT_NULL))
    {
      if (flags & SSG_RETVAL_MUST_PRINT_SOMETHING)
        spar_internal_error (NULL, "ssg_print_equiv_retval_expn(): must print something but can not");
      return 0;
    }
  ssg_puts (" NULL");

write_assuffix:
  if ((NULL != as_name) &&
    (flags & SSG_RETVAL_USES_ALIAS) &&
    ((NULL == name_as_expn) || strcmp (as_name, name_as_expn)) )
    {
      ssg_puts (" AS ");
      ssg_prin_id (ssg, as_name);
    }
  return 1;
}


void
ssg_print_equivalences (spar_sqlgen_t *ssg, SPART *gp, sparp_equiv_t *eq,
  ccaddr_t jleft_alias, ccaddr_t jright_alias )
{
  int var_ctr, var2_ctr;
  int sub_ctr, sub2_ctr;
  SPART *glob;

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
  glob = ((SPART_VARR_GLOBAL & eq->e_restrictions) ?
    ssg_find_global_in_equiv (eq) : NULL );
  for (var_ctr = 0; var_ctr < eq->e_var_count; var_ctr++)
    {
      SPART *var = eq->e_vars[var_ctr];
      caddr_t tabid = var->_.var.tabid;
      if (NULL == tabid)
        continue;
      if (SPART_VARR_FIXED & eq->e_restrictions)
        {
          ssg_valmode_t vmode;
          SPART_buf var_rv_buf/*, glob_rv_buf*/;
          SPART *var_rv/*, *glob_rv*/;
          SPART_AUTO (var_rv, var_rv_buf, SPAR_RETVAL);
          memcpy (&(var_rv->_.var), &(var->_.var), sizeof (var->_.var));
          vmode = ssg_expn_native_valmode (ssg, var_rv);
          ssg_print_where_or_and (ssg, "fixed value of equiv class (short)");
          ssg_print_tr_var_expn (ssg, var, vmode);
          ssg_puts (" =");
          ssg_print_scalar_expn (ssg, eq->e_fixedvalue, vmode);
          if (! (SPART_VARR_IS_REF & eq->e_restrictions))
            {
              ssg_print_where_or_and (ssg, "fixed value of equiv class (sqlval)");
              ssg_print_tr_var_expn (ssg, var, SSG_VALMODE_SQLVAL);
              ssg_puts (" =");
              ssg_print_literal (ssg, NULL, eq->e_fixedvalue);
            }
          continue;
        }
      if (SPART_VARR_GLOBAL & eq->e_restrictions)
        {
          ssg_valmode_t vmode;
          SPART_buf var_rv_buf, glob_rv_buf;
          SPART *var_rv, *glob_rv;
          SPART_AUTO (var_rv, var_rv_buf, SPAR_RETVAL);
          memcpy (&(var_rv->_.var), &(var->_.var), sizeof (var->_.var));
          var_rv->_.var.vname = "%";
          vmode = ssg_expn_native_valmode (ssg, var_rv);
          SPART_AUTO (glob_rv, glob_rv_buf, SPAR_RETVAL);
          memcpy (&(glob_rv->_.var), &(glob->_.var), sizeof (glob->_.var));
          ssg_print_where_or_and (ssg, "global param value of equiv class");
          ssg_print_tr_var_expn (ssg, var, vmode);
          ssg_puts (" =");
          ssg_print_scalar_expn (ssg, glob_rv, vmode);
        }
      if (SPART_VARR_TYPED & eq->e_restrictions)
        {
          ssg_print_where_or_and (ssg, "fixed type of equiv class");
          ssg_print_tr_var_expn (ssg, var, SSG_VALMODE_DATATYPE);
          ssg_puts (" =");
          ssg_print_literal (ssg, NULL, (SPART *)(eq->e_datatype));
        }
    }

print_cross_equalities:
  /* Printing cross-equalities */
  if ((SPART_VARR_FIXED | SPART_VARR_GLOBAL) & eq->e_restrictions)
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
          caddr_t tabid2 = var2->_.var.tabid;
          if (NULL == tabid2)
            continue;
          if (NULL != jright_alias)
            continue;
          var_native = ssg_expn_native_valmode (ssg, var);
          var2_native = ssg_expn_native_valmode (ssg, var2);
          common_native = ssg_shortest_valmode (var_native, var2_native);
          ssg_print_where_or_and (ssg, "two fields belong to same equiv");
          ssg_print_tr_var_expn (ssg, var, common_native);
          ssg_puts (" =");
          ssg_print_tr_var_expn (ssg, var2, common_native);
        }

print_field_and_retval_equalities:
      for (sub2_ctr = 0; sub2_ctr < BOX_ELEMENTS_INT_0 (eq->e_subvalue_idxs); sub2_ctr++)
        {
          ptrlong sub2_eq_idx = eq->e_subvalue_idxs[sub2_ctr];
          sparp_equiv_t *sub2_eq = ssg->ssg_equivs[sub2_eq_idx];
          SPART *sub2_gp = ssg_find_gp_by_eq_idx (ssg, sub2_eq_idx);
          ssg_valmode_t sub2_native;
          ssg_valmode_t common_native;
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
          common_native = ssg_shortest_valmode (var_native, sub2_native);
#ifdef DEBUG
	  if (SSG_VALMODE_LONG == common_native)
            ssg_puts (" /* note SSG_VALMODE_LONG: */");

#endif
          ssg_print_where_or_and (ssg, "field and retval belong to same equiv");
          ssg_print_tr_var_expn (ssg, var, common_native);
          ssg_puts (" =");
          ssg_print_equiv_retval_expn (ssg, sub2_gp, sub2_eq, SSG_RETVAL_FROM_GOOD_SELECTED | SSG_RETVAL_MUST_PRINT_SOMETHING, NULL, common_native);
        }
    }
  for (sub_ctr = 0; sub_ctr < BOX_ELEMENTS_INT_0 (eq->e_subvalue_idxs); sub_ctr++)
    {
      ptrlong sub_eq_idx = eq->e_subvalue_idxs[sub_ctr];
      sparp_equiv_t *sub_eq = ssg->ssg_equivs[sub_eq_idx];
      SPART *sub_gp = ssg_find_gp_by_eq_idx (ssg, sub_eq_idx);
      for (sub2_ctr = sub_ctr + 1; sub2_ctr < BOX_ELEMENTS_INT_0 (eq->e_subvalue_idxs); sub2_ctr++)
        {
          ptrlong sub2_eq_idx = eq->e_subvalue_idxs[sub2_ctr];
          sparp_equiv_t *sub2_eq = ssg->ssg_equivs[sub2_eq_idx];
          SPART *sub2_gp = ssg_find_gp_by_eq_idx (ssg, sub2_eq_idx);
          ssg_valmode_t sub_native, sub2_native, common_native;
          if ((OPTIONAL_L == sub_gp->_.gp.subtype) &&
            (OPTIONAL_L == sub2_gp->_.gp.subtype) )
            continue;
          if (NULL != jright_alias)
            {
              if (strcmp (sub2_gp->_.gp.selid, jright_alias))
                continue;
              if (strcmp (sub_gp->_.gp.selid, jleft_alias))
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
          common_native = ssg_shortest_valmode (sub_native, sub2_native);
          ssg_print_where_or_and (ssg, "two retvals belong to same equiv");
          ssg_print_equiv_retval_expn (ssg, sub_gp, sub_eq, SSG_RETVAL_FROM_GOOD_SELECTED | SSG_RETVAL_MUST_PRINT_SOMETHING, NULL, common_native);
          ssg_puts (" =");
          ssg_print_equiv_retval_expn (ssg, sub2_gp, sub2_eq, SSG_RETVAL_FROM_GOOD_SELECTED | SSG_RETVAL_MUST_PRINT_SOMETHING, NULL, common_native);
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
      ssg_valmode_t shortest_common;
      const char *cmp_func_name = NULL;
      shortest_common = ssg_shortest_valmode (left_native, right_native);
      if (SSG_VALMODE_LONG == shortest_common)
        cmp_func_name = "DB.DBA.RDF_LONG_CMP";
      else if (IS_BOX_POINTER (shortest_common))
        cmp_func_name = shortest_common->rdfdf_cmp_func_name;
      else
        goto sqlval_operation;
      ssg_puts (s1);
      ssg_puts (cmp_func_name);
      ssg_puts ("(");
      ssg_print_retval_simple_expn (ssg, gp, left, shortest_common);
      ssg_puts (" ,");
      ssg_print_retval_simple_expn (ssg, gp, right, shortest_common);
      ssg_puts ("), 0)");
      return;
    }
sqlval_operation:
  ssg_puts (s1);
  ssg_print_retval_simple_expn (ssg, gp, left, SSG_VALMODE_SQLVAL);
  ssg_puts (s2);
  if (NULL == s3)
    return;
  ssg_print_retval_simple_expn (ssg, gp, right, SSG_VALMODE_SQLVAL);
  ssg_puts (s3);
}


void ssg_print_retval_simple_expn (spar_sqlgen_t *ssg, SPART *gp, SPART *tree, ssg_valmode_t needed)
{
  switch (SPART_TYPE (tree))
    {
    case BOP_AND:	ssg_print_retval_bop_calc_expn (ssg, gp, tree, " __and ("	, ", ", ")"	, 0, needed); return;
    case BOP_OR:	ssg_print_retval_bop_calc_expn (ssg, gp, tree, " __or ("	, ", ", ")"	, 0, needed); return;
    case BOP_EQ:	ssg_print_retval_bop_calc_expn (ssg, gp, tree, " equ ("		, ", ", ")"	, 0, needed); return;
    case BOP_NEQ:	ssg_print_retval_bop_calc_expn (ssg, gp, tree, " neq ("		, ", ", ")"	, 0, needed); return;
    case BOP_LT:	ssg_print_retval_bop_calc_expn (ssg, gp, tree, " lt ("		, ", ", ")"	, 1, needed); return;
    case BOP_LTE:	ssg_print_retval_bop_calc_expn (ssg, gp, tree, " lte ("		, ", ", ")"	, 1, needed); return;
    case BOP_GT:	ssg_print_retval_bop_calc_expn (ssg, gp, tree, " gt ("		, ", ", ")"	, 1, needed); return;
    case BOP_GTE:	ssg_print_retval_bop_calc_expn (ssg, gp, tree, " gte ("		, ", ", ")"	, 1, needed); return;
/*case BOP_LIKE: Like is built-in in SPARQL, not a BOP!
			ssg_print_retval_bop_calc_expn (ssg, gp, tree, " like "	, " strlike ("	, 0, SSG_VALMODE_BOOL); return;
*/
/*
    case BOP_SAME:	ssg_print_bop_bool_expn (ssg, tree, "(", "= ", ")"); return;
    case BOP_NSAME:	ssg_print_bop_bool_expn (ssg, tree, "(", "= ", ")"); return;
*/

    case BOP_PLUS:	ssg_print_retval_bop_calc_expn (ssg, gp, tree, " ("		, " + ", ")"	, 0, needed); return;
    case BOP_MINUS:	ssg_print_retval_bop_calc_expn (ssg, gp, tree, " ("		, " - ", ")"	, 0, needed); return;
    case BOP_TIMES:	ssg_print_retval_bop_calc_expn (ssg, gp, tree, " ("		, " * ", ")"	, 0, needed); return;
    case BOP_DIV:	ssg_print_retval_bop_calc_expn (ssg, gp, tree, " div ("		, ", ", ")"	, 0, needed); return;
    case BOP_MOD:	ssg_print_retval_bop_calc_expn (ssg, gp, tree, " mod ("		, ", ", ")"	, 0, needed); return;
    case SPAR_BLANK_NODE_LABEL:
    case SPAR_VARIABLE:
      {
        caddr_t name = tree->_.var.vname;
        sparp_equiv_t *eq = sparp_equiv_get_ro (
          ssg->ssg_equivs, ssg->ssg_equiv_count,
          gp, (SPART *)name, SPARP_EQUIV_GET_NAMESAKES | SPARP_EQUIV_GET_ASSERT );
        int printed = ssg_print_equiv_retval_expn (ssg, gp, eq, SSG_RETVAL_FROM_JOIN_MEMBER | SSG_RETVAL_MUST_PRINT_SOMETHING, NULL /* no AS name in subexpressions */, needed);
        if (! printed)
          {
#ifdef DEBUG
            ssg_print_equiv_retval_expn (ssg, gp, eq, SSG_RETVAL_FROM_JOIN_MEMBER | SSG_RETVAL_MUST_PRINT_SOMETHING, name, needed);
#endif
            spar_sqlprint_error ("ssg_print_retval_simple_expn(): can't print variable in retval expn");
          }
        return;
      }
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
            ssg_print_retval_simple_expn (ssg, gp, tree, SSG_VALMODE_SQLVAL);
            ssg_puts (")");
            return;
          }
            if ((SSG_VALMODE_SQLVAL == needed) && (SSG_VALMODE_LONG == native))
          {
                ssg_puts (" DB.DBA.RDF_SQLVAL_OF_LONG (");
                ssg_print_retval_simple_expn (ssg, gp, tree, SSG_VALMODE_LONG);
                ssg_puts (")");
                return;
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
                ssg_print_scalar_expn (ssg, tree->_.funcall.argtrees[ctr], SSG_VALMODE_SQLVAL);
              }
            ssg->ssg_indent--;
            ssg_putchar (')');
            return;
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
            ssg_print_retval_simple_expn (ssg, gp, tree->_.funcall.argtrees[arg_ctr], argtype);
          }
        ssg->ssg_indent--;
        ssg_putchar (')');
        return;
      }
    case SPAR_LIT: case SPAR_QNAME: case SPAR_QNAME_NS:
      ssg_print_scalar_expn (ssg, tree, needed);
      return;
    default:
      break;
  }
  spar_sqlprint_error ("ssg_print_retval_simple_expn(): unsupported type of retval expression");
}


void
ssg_print_retval_expn (spar_sqlgen_t *ssg, SPART *gp, SPART *ret_column, int col_idx, int flags, ssg_valmode_t needed)
{
  int printed;
  int eq_flags;
  caddr_t var_name, as_name;
  sparp_equiv_t *eq;
  if (flags & SSG_RETVAL_NAME_INSTEAD_OF_TREE)
    as_name = var_name = (caddr_t) ret_column;
  else
    {
      as_name = spar_alias_name_of_ret_column (ret_column);
      var_name = spar_var_name_of_ret_column (ret_column);
      if (NULL == var_name)
    {
      if (SSG_VALMODE_AUTO == needed)
        spar_sqlprint_error ("ssg_print_retval_expn(): SSG_VALMODE_AUTO for not a variable");
      ssg_print_retval_simple_expn (ssg, gp, ret_column, needed);
      if (flags & SSG_RETVAL_USES_ALIAS)
        {
              ssg_puts (" AS ");
              if (NULL == as_name)
                {
          char buf[30];
          sprintf (buf, "callret-%d", col_idx);
                  ssg_prin_id (ssg, buf);
                }
              else
                ssg_prin_id (ssg, as_name);
        }
      return;
    }
    }
  eq_flags = SPARP_EQUIV_GET_NAMESAKES;
  if (!(flags & SSG_RETVAL_CAN_PRINT_NULL))
    eq_flags |= SPARP_EQUIV_GET_ASSERT;
  eq = sparp_equiv_get_ro (ssg->ssg_equivs, ssg->ssg_equiv_count, gp, (SPART *)var_name, eq_flags);
  if (SSG_VALMODE_AUTO == needed)
    needed = ssg_equiv_native_valmode (ssg, gp, eq);
  printed = ssg_print_equiv_retval_expn (ssg, gp, eq, flags, as_name, needed);
  if (! printed)
    {
#ifdef DEBUG
      ssg_print_equiv_retval_expn (ssg, gp, eq, flags, as_name, needed);
#endif
      spar_sqlprint_error ("ssg_print_retval_expn(): can't print retval expn");
    }
}

void ssg_print_retval_cols (spar_sqlgen_t *ssg, SPART **retvals, ccaddr_t selid)
{
  int col_idx;
  DO_BOX_FAST (SPART *, ret_column, col_idx, retvals)
    {
      caddr_t as_name = spar_alias_name_of_ret_column (ret_column);
      if (NULL == as_name)
        {
          char buf[30];
          sprintf (buf, "callret-%d", col_idx);
          as_name = t_box_dv_short_string (buf);
        }
      if (0 < col_idx)
        ssg_puts (", ");
      if (NULL != selid)
        {
          ssg_prin_id (ssg, selid);
          ssg_putchar ('.');
          ssg_prin_id (ssg, as_name);
        }
      else
        ssg_print_literal (ssg, NULL, (SPART *)as_name);
    }
  END_DO_BOX_FAST;
}

void
ssg_print_retval_list (spar_sqlgen_t *ssg, SPART *gp, SPART **retlist, int print_union_flags, int flags, ssg_valmode_t needed)
{
  int res_ctr, res_len;
  if (SSG_PRINT_UNION_LIM_OR_OFS & print_union_flags)
    {
      char buf[40];
      long lim = unbox (ssg->ssg_tree->_.req_top.limit);
      long ofs = unbox (ssg->ssg_tree->_.req_top.offset);
      if (0 != ofs)
        sprintf (buf, " TOP %ld, %ld", ofs, lim);
      else
        sprintf (buf, " TOP %ld", lim);
      ssg_puts (buf);
    }
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
      ssg_print_retval_expn (ssg, gp, ret_column, res_ctr, flags, needed);
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
ssg_print_table_exp (spar_sqlgen_t *ssg, SPART *tree, int pass, int print_union_flags)
{
  switch (SPART_TYPE(tree))
    {
    case SPAR_TRIPLE:
      {
        SPART *graph = tree->_.triple.tr_graph;
        int ignore_named_sources = (
          (SPAR_VARIABLE == SPART_TYPE(graph)) &&
          !strcmp (SPAR_VARNAME_DEFAULT_GRAPH, graph->_.var.vname) );
        dk_set_t usages = rdf_ds_find_appropriate (tree, ssg->ssg_sources, ignore_named_sources);
        if (1 == dk_set_length (usages))
          { /* Single table of triples */
            rdf_ds_usage_t *dsu = (rdf_ds_usage_t *)dk_set_pop (&usages);
            if (1 == pass)
              {
                ssg_putchar (' ');
                ssg_puts (dsu->rdfdu_ds->rdfd_base_table);
                ssg_puts (" AS ");
                ssg_prin_id (ssg, tree->_.triple.tabid);
              }
            if (2 == pass)
              {
                int fctr;
                for (fctr = 0; fctr < SPART_TRIPLE_FIELDS_COUNT; fctr++)
                  ssg_print_fld_restrictions (ssg, dsu->rdfdu_ds, dsu->tr_fields[fctr], tree->_.triple.tabid, tree->_.triple.tr_fields[fctr]);
              }
            dk_free (dsu, sizeof (rdf_ds_usage_t));
          }
        else
          { /* Union of many tables of triples or many combinations of columns of a single table, or a mix */
            if (1 == pass)
              {
                ssg->ssg_indent++;
                ssg_puts (" (SELECT ");
		/*!!! TBD */
                ssg_puts (") AS ");
                ssg_prin_id (ssg, tree->_.triple.tabid);
                ssg->ssg_indent--;
              }
          }
        break;
      }
    case SPAR_GP:
      {
        int print_sub_flags;
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
            print_sub_flags = ((SSG_PRINT_UNION_TOPLEVEL & print_union_flags) ? (SSG_PRINT_UNION_LIM_OR_OFS & print_union_flags) : 0);
            ssg_print_union (ssg, tree, (SPART **)retlist, print_sub_flags,
              ( SSG_RETVAL_FROM_FIRST_UNION_MEMBER | SSG_RETVAL_FROM_JOIN_MEMBER |
                SSG_RETVAL_USES_ALIAS | SSG_RETVAL_NAME_INSTEAD_OF_TREE | SSG_RETVAL_MUST_PRINT_SOMETHING ),
              SSG_VALMODE_AUTO );
            if (SSG_PRINT_UNION_ORDER_BY & print_union_flags)
              {
                int oby_ctr;
                ssg_newline (0);
                ssg_puts ("ORDER BY");
                ssg->ssg_indent++;
                sparp_set_special_order_selid (ssg->ssg_sparp, tree);
                DO_BOX_FAST(SPART *, oby_itm, oby_ctr, ssg->ssg_tree->_.req_top.order)
                  {
                    if (oby_ctr > 0)
                      ssg_putchar (',');
                    ssg_print_orderby_item (ssg, tree, oby_itm, 1);
                  }
                END_DO_BOX_FAST;
                ssg->ssg_indent--;
              }
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
ssg_print_union (spar_sqlgen_t *ssg, SPART *gp, SPART **retlist, int print_union_flags, int retval_flags, ssg_valmode_t needed)
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
      int itm_idx;
      if ((memb_ctr > 0) || !(SSG_PRINT_UNION_NOFIRSTHEAD & print_union_flags))
        {
          ssg_newline (0);
          if (memb_ctr > 0)
            ssg_puts ("UNION ALL ");
          ssg_puts ("SELECT");
          ssg_print_retval_list (ssg, members[memb_ctr], retlist, print_union_flags, retval_flags, needed);
        }
      retval_flags &= ~SSG_RETVAL_USES_ALIAS; /* Aliases are not printed in resultsets of union, except the very first one */
      ssg_newline (0);
      ssg_puts ("FROM");
      ssg->ssg_indent++;
      if (0 == BOX_ELEMENTS (member->_.gp.members))
        {
          char buf[20];
          ssg_newline (0);
          sprintf (buf, "stub-%s", member->_.gp.selid);
          if (SSG_PRINT_UNION_NONEMPTY_STUB & print_union_flags)
            ssg_puts ("(SELECT TOP 1 1 AS __stub FROM DB.DBA.RDF_QUAD) AS ");
          else
            ssg_puts ("(SELECT TOP 1 1 AS __stub FROM DB.DBA.RDF_QUAD where 1=2) AS ");
          ssg_prin_id (ssg, buf);
          goto end_of_table_list; /* see below */
        }
      DO_BOX_FAST (SPART *, itm, itm_idx, member->_.gp.members)
        {
          ccaddr_t itm_alias = ssg_id_of_gp_or_triple (itm);
          int itm_is_opt = 0;
          if (itm_idx > 0)
            {
              itm_is_opt = (SPAR_GP == SPART_TYPE(itm)) && (OPTIONAL_L == itm->_.gp.subtype);
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
          ssg_print_table_exp (ssg, itm, 1, print_union_flags); /* PASS 1, printing what's in FROM */
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
      END_DO_BOX_FAST;

end_of_table_list: ;
      ssg->ssg_indent--;
      save_where_l_printed = ssg->ssg_where_l_printed;
      save_where_l_text = ssg->ssg_where_l_text;
      ssg->ssg_where_l_printed = 0;
      ssg->ssg_where_l_text = "WHERE";
      ssg->ssg_indent++;
      DO_BOX_FAST (SPART *, itm, itm_idx, member->_.gp.members)
        {
          ssg_print_table_exp (ssg, itm, 2, print_union_flags); /* PASS 2, printing what's in WHERE */
        }
      END_DO_BOX_FAST;
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
      ssg->ssg_indent--;
      ssg->ssg_where_l_printed = save_where_l_printed;
      ssg->ssg_where_l_text = save_where_l_text;
    }
}

void
ssg_print_orderby_item (spar_sqlgen_t *ssg, SPART *gp, SPART *oby_itm, int in_subselect)
{
  SPART *expn = oby_itm->_.oby.expn;
  if (in_subselect)
    ssg_print_scalar_expn (ssg, expn, SSG_VALMODE_SQLVAL);
  else
    ssg_print_retval_simple_expn (ssg, gp, expn, SSG_VALMODE_SQLVAL);
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
  int print_union_flags = SSG_PRINT_UNION_NOFIRSTHEAD | SSG_PRINT_UNION_NONEMPTY_STUB | SSG_PRINT_UNION_TOPLEVEL;
  int top_retval_flags =
    SSG_RETVAL_TOPMOST |
    SSG_RETVAL_FROM_JOIN_MEMBER |
    SSG_RETVAL_FROM_FIRST_UNION_MEMBER |
    SSG_RETVAL_MUST_PRINT_SOMETHING |
    SSG_RETVAL_CAN_PRINT_NULL |
    SSG_RETVAL_USES_ALIAS ;
  int need_order_by = 0;
  int need_lim_or_ofs = 0;
  ccaddr_t top_selid = tree->_.req_top.pattern->_.gp.selid;
  ssg->ssg_equiv_count = tree->_.req_top.equiv_count;
  ssg->ssg_equivs = tree->_.req_top.equivs;
  formatter = ssg_find_formatter_by_name_and_subtype (tree->_.req_top.formatmode_name, tree->_.req_top.subtype);
  retvalmode = ssg_find_valmode_by_name (tree->_.req_top.retvalmode_name);
  if ((NULL != formatter) && (NULL != retvalmode) && (SSG_VALMODE_LONG != retvalmode))
    spar_sqlprint_error ("'output:valmode' declaration conflicts with 'output:format'");
  if ((0 < BOX_ELEMENTS_INT_0 (tree->_.req_top.order)) && (NULL == formatter))
    need_order_by = 1;
  lim = unbox (tree->_.req_top.limit);
  ofs = unbox (tree->_.req_top.offset);
  if ((2147483647 != lim) || (0 != ofs))
    need_lim_or_ofs = 1;
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
          ssg_print_retval_cols (ssg, tree->_.req_top.retvals, NULL);
          ssg_puts (")) AS \"callret-0\" LONG VARCHAR\nFROM (");
          ssg->ssg_indent += 1;
          ssg_newline (0);
        }
      ssg_puts ("SELECT");
      if (need_lim_or_ofs)
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
      retvalmode = ssg_find_valmode_by_name (tree->_.req_top.retvalmode_name);
      if (NULL == retvalmode)
        retvalmode = ((NULL != formatter) ? SSG_VALMODE_LONG : SSG_VALMODE_SQLVAL);
      ssg_print_retval_list (ssg, tree->_.req_top.pattern,
        tree->_.req_top.retvals, 0, top_retval_flags, retvalmode );
      break;
    case CONSTRUCT_L:
    case DESCRIBE_L:
      if ((NULL == formatter) && ssg->ssg_sparp->sparp_sparqre->sparqre_direct_client_call)
        {
          formatter = ssg_find_formatter_by_name_and_subtype ("TTL", subtype);
          if ((NULL != retvalmode) && (SSG_VALMODE_LONG != retvalmode))
            spar_sqlprint_error ("'output:valmode' declaration conflicts with TTL output format needed by database client connection'");
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
      ssg_print_retval_list (ssg, tree->_.req_top.pattern,
        tree->_.req_top.retvals, print_union_flags, top_retval_flags, retvalmode );
      if (NULL != formatter)
        {
          ssg_puts (" ) AS \"callret");
          if (NULL != tree->_.req_top.formatmode_name)
            ssg_puts (tree->_.req_top.formatmode_name);
          ssg_puts ("-0\" LONG VARCHAR");
          ssg->ssg_indent -= 1;
          ssg_newline (0);
        }
      if (need_lim_or_ofs)
        print_union_flags |= SSG_PRINT_UNION_LIM_OR_OFS;
      if (need_order_by)
        print_union_flags |= SSG_PRINT_UNION_ORDER_BY;
      need_order_by = 0;
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
    print_union_flags, top_retval_flags, retvalmode );
  if (need_order_by)
    {
      ssg_newline (0);
      ssg_puts ("ORDER BY");
      ssg->ssg_indent++;
      DO_BOX_FAST(SPART *, oby_itm, oby_ctr, tree->_.req_top.order)
        {
	  if (oby_ctr > 0)
            ssg_putchar (',');
          ssg_print_orderby_item (ssg, tree->_.req_top.pattern, oby_itm, 0);
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

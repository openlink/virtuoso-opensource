/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2009 OpenLink Software
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
#ifdef __cplusplus
extern "C" {
#endif
#include "sparql_p.h"
#ifdef __cplusplus
}
#endif

#include "rdf_mapping_jso.h"

#ifdef MALLOC_DEBUG
const char *spartlist_impl_file="???";
int spartlist_impl_line;
#endif

extern void jsonyyerror_impl(const char *s);

size_t
spart_count_specific_elems_by_type (ptrlong type)
{
  static SPART sample;
  switch (type)
    {
    case SPAR_ALIAS:		return sizeof (sample._.alias);
    case SPAR_BLANK_NODE_LABEL:	return sizeof (sample._.var);
    case SPAR_BUILT_IN_CALL:	return sizeof (sample._.builtin);
    case SPAR_CONV:		return sizeof (sample._.conv);
    case SPAR_FUNCALL:		return sizeof (sample._.funcall);
    case SPAR_GP:		return sizeof (sample._.gp);
    case SPAR_REQ_TOP:		return sizeof (sample._.req_top);
    case SPAR_RETVAL:		return sizeof (sample._.retval);
    case SPAR_LIT:		return sizeof (sample._.lit);
    case SPAR_QNAME:		return sizeof (sample._.qname);
    case SPAR_SQLCOL:		return sizeof (sample._.qm_sqlcol);
    case SPAR_VARIABLE:		return sizeof (sample._.var);
    case SPAR_TRIPLE:		return sizeof (sample._.triple);
    case SPAR_QM_SQL_FUNCALL:	return sizeof (sample._.qm_sql_funcall);
    case SPAR_CODEGEN:		return sizeof (sample._.codegen);
    case SPAR_LIST:		return sizeof (sample._.list);
    case SPAR_GRAPH:		return sizeof (sample._.graph);
    case ORDER_L:		return sizeof (sample._.oby);
    case BOP_NOT:
    case BOP_OR: case BOP_AND:
    case BOP_PLUS: case BOP_MINUS: case BOP_TIMES: case BOP_DIV: case BOP_MOD:
    case BOP_EQ: case BOP_NEQ: case BOP_LT: case BOP_LTE: case BOP_GT: case BOP_GTE:
    case BOP_LIKE:		return sizeof (sample._.bin_exp);
    }
  GPF_T;
  return 0;
}

SPART*
spartlist_impl (sparp_t *sparp, ptrlong length, ptrlong type, ...)
{
  SPART *tree;
  va_list ap;
  int inx;
  va_start (ap, type);
#ifdef DEBUG
  if (SPAR_CODEGEN == type)
    {
      if (spart_count_specific_elems_by_type (type) > sizeof (caddr_t) * (length-1))
        spar_internal_error (sparp, "length mismatch in spartlist()");
    }
  else
    {
      if (spart_count_specific_elems_by_type (type) != sizeof (caddr_t) * (length-1))
        spar_internal_error (sparp, "length mismatch in spartlist()");
    }
#endif
  length += 1;
#ifdef MALLOC_DEBUG
  tree = (SPART *) dbg_mp_alloc_box (spartlist_impl_file, spartlist_impl_line, THR_TMP_POOL, sizeof (caddr_t) * length, DV_ARRAY_OF_POINTER);
#else
  tree = (SPART *) t_alloc_box (sizeof (caddr_t) * length, DV_ARRAY_OF_POINTER);
#endif
  for (inx = 2; inx < length; inx++)
    {
      caddr_t child = va_arg (ap, caddr_t);
#if 0
#ifdef MALLOC_DEBUG
      if (IS_BOX_POINTER (child))
	t_alloc_box_assert (child);
#endif
#endif
      ((caddr_t *)(tree))[inx] = child;
    }
  va_end (ap);
  tree->type = type;
  tree->srcline = t_box_num ((NULL != sparp) ? ((NULL != sparp->sparp_curr_lexem) ? sparp->sparp_curr_lexem->sparl_lineno : 0) : 0);
  /*spart_check (sparp, tree);*/
  return tree;
}


SPART*
spartlist_with_tail_impl (sparp_t *sparp, ptrlong length, caddr_t tail, ptrlong type, ...)
{
  SPART *tree;
  va_list ap;
  int inx;
  ptrlong tail_len = BOX_ELEMENTS(tail);
  va_start (ap, type);
#ifdef DEBUG
  if (spart_count_specific_elems_by_type (type) != sizeof (caddr_t) * (length+tail_len-1))
    spar_internal_error (sparp, "length mismatch in spartlist()");
#endif
#ifdef MALLOC_DEBUG
  tree = (SPART *) dbg_dk_alloc_box (spartlist_impl_file, spartlist_impl_line, sizeof (caddr_t) * (1+length+tail_len), DV_ARRAY_OF_POINTER);
#else
  tree = (SPART *) dk_alloc_box (sizeof (caddr_t) * (1+length+tail_len), DV_ARRAY_OF_POINTER);
#endif
  for (inx = 2; inx < length; inx++)
    {
      caddr_t child = va_arg (ap, caddr_t);
#ifdef MALLOC_DEBUG
      if (IS_BOX_POINTER (child))
	dk_alloc_box_assert (child);
#endif
      ((caddr_t *)(tree))[inx] = child;
    }
  va_end (ap);
  tree->type = type;
  tree->srcline = t_box_num ((NULL != sparp) ? ((NULL != sparp->sparp_curr_lexem) ? sparp->sparp_curr_lexem->sparl_lineno : 0) : 0);
  ((ptrlong *)(tree))[length] = tail_len;
  memcpy (((caddr_t *)(tree))+length+1, tail, sizeof(caddr_t) * tail_len);
  dk_free_box (tail);
  /*spart_check (sparp, tree);*/
  return tree;
}

caddr_t
spar_source_place (sparp_t *sparp, char *raw_text)
{
  char buf [3000];
  int lineno = ((NULL != sparp->sparp_curr_lexem) ? (int) sparp->sparp_curr_lexem->sparl_lineno : 0);
  char *next_text = NULL;
  if ((NULL == raw_text) && (NULL != sparp->sparp_curr_lexem))
    raw_text = sparp->sparp_curr_lexem->sparl_raw_text;
  if ((NULL != raw_text) && (NULL != sparp->sparp_curr_lexem))
    {
      if ((sparp->sparp_curr_lexem_bmk.sparlb_offset + 1) < sparp->sparp_lexem_buf_len)
        next_text = sparp->sparp_curr_lexem[1].sparl_raw_text;
    }
  sprintf (buf, "%.400s, line %d%.6s%.1000s%.5s%.15s%.1000s%.5s",
      sparp->sparp_err_hdr,
      lineno,
      ((NULL == raw_text) ? "" : ", at '"),
      ((NULL == raw_text) ? "" : raw_text),
      ((NULL == raw_text) ? "" : "'"),
      ((NULL == next_text) ? "" : ", before '"),
      ((NULL == next_text) ? "" : next_text),
      ((NULL == next_text) ? "" : "'")
      );
  return t_box_dv_short_string (buf);
}

caddr_t
spar_dbg_string_of_triple_field (sparp_t *sparp, SPART *fld)
{
  switch (SPART_TYPE (fld))
    {
    case SPAR_BLANK_NODE_LABEL: return t_box_sprintf (210, "_:%.200s", fld->_.var.vname);
    case SPAR_VARIABLE: return t_box_sprintf (210, "?%.200s", fld->_.var.vname);
    case SPAR_QNAME: return t_box_sprintf (210, "<%.200s>", fld->_.lit.val);
    case SPAR_LIT:
      if (NULL != fld->_.lit.language)
        return t_box_sprintf (410, "\"%.200s\"@%.200s", fld->_.lit.val, fld->_.lit.language);
      if (NULL == fld->_.lit.datatype)
        return t_box_sprintf (210, "\"%.200s\"", fld->_.lit.val);
      if (
        (uname_xmlschema_ns_uri_hash_integer == fld->_.lit.datatype) ||
        (uname_xmlschema_ns_uri_hash_decimal == fld->_.lit.datatype) ||
        (uname_xmlschema_ns_uri_hash_double == fld->_.lit.datatype) )
        return t_box_sprintf (210, "%.200s", fld->_.lit.val);
      return t_box_sprintf (410, "\"%.200s\"^^<%.200s>", fld->_.lit.val, fld->_.lit.datatype);
    default: return t_box_dv_short_string ("...");
    }
}

void
sparyyerror_impl (sparp_t *sparp, char *raw_text, const char *strg)
{
  int lineno = ((NULL != sparp->sparp_curr_lexem) ? (int) sparp->sparp_curr_lexem->sparl_lineno : 0);
  char *next_text = NULL;
  if ((NULL == raw_text) && (NULL != sparp->sparp_curr_lexem))
    raw_text = sparp->sparp_curr_lexem->sparl_raw_text;
  if ((NULL != raw_text) && (NULL != sparp->sparp_curr_lexem))
    {
      if ((sparp->sparp_curr_lexem_bmk.sparlb_offset + 1) < sparp->sparp_lexem_buf_len)
        next_text = sparp->sparp_curr_lexem[1].sparl_raw_text;
    }
  sqlr_new_error ("37000", "SP030",
      "%.400s, line %d: %.500s%.5s%.1000s%.5s%.15s%.1000s%.5s",
      sparp->sparp_err_hdr,
      lineno,
      strg,
      ((NULL == raw_text) ? "" : " at '"),
      ((NULL == raw_text) ? "" : raw_text),
      ((NULL == raw_text) ? "" : "'"),
      ((NULL == next_text) ? "" : " before '"),
      ((NULL == next_text) ? "" : next_text),
      ((NULL == next_text) ? "" : "'")
      );
}

void
sparyyerror_impl_1 (sparp_t *sparp, char *raw_text, int yystate, short *yyssa, short *yyssp, const char *strg)
{
  int sm2, sm1, sp1;
  int lineno = (int) ((NULL != sparp->sparp_curr_lexem) ? sparp->sparp_curr_lexem->sparl_lineno : 0);
  char *next_text = NULL;
  if ((NULL == raw_text) && (NULL != sparp->sparp_curr_lexem))
    raw_text = sparp->sparp_curr_lexem->sparl_raw_text;
  if ((NULL != raw_text) && (NULL != sparp->sparp_curr_lexem))
    {
      if ((sparp->sparp_curr_lexem_bmk.sparlb_offset + 1) < sparp->sparp_lexem_buf_len)
        next_text = sparp->sparp_curr_lexem[1].sparl_raw_text;
    }

  sp1 = yyssp[1];
  sm1 = yyssp[-1];
  sm2 = ((sm1 > 0) ? yyssp[-2] : 0);

  sqlr_new_error ("37000", "SP030",
     /*errlen,*/ "%.400s, line %d: %.500s [%d-%d-(%d)-%d]%.5s%.1000s%.5s%.15s%.1000s%.5s",
      sparp->sparp_err_hdr,
      lineno,
      strg,
      sm2,
      sm1,
      yystate,
      ((sp1 & ~0x7FF) ? -1 : sp1) /* stub to avoid printing random garbage in logs */,
      ((NULL == raw_text) ? "" : " at '"),
      ((NULL == raw_text) ? "" : raw_text),
      ((NULL == raw_text) ? "" : "'"),
      ((NULL == next_text) ? "" : " before '"),
      ((NULL == next_text) ? "" : next_text),
      ((NULL == next_text) ? "" : "'")
      );
}

void
spar_error (sparp_t *sparp, const char *format, ...)
{
  va_list ap;
  va_start (ap, format);
  if (NULL == sparp)
    sqlr_new_error ("37000", "SP031",
      "SPARQL generic error: %.1500s",
      box_vsprintf (1500, format, ap) );
  else
    sqlr_new_error ("37000", "SP031",
      "%.400s: %.1500s",
      sparp->sparp_err_hdr,
      t_box_vsprintf (1500, format, ap) );
  va_end (ap);
}

int
spar_audit_error (sparp_t *sparp, const char *format, ...)
{
  va_list ap;
  caddr_t msg;
  va_start (ap, format);
  msg = t_box_vsprintf (1500, format, ap);
  fprintf (stderr, "%s\n", msg);
#ifdef DEBUG
  if (sparp->sparp_internal_error_runs_audit)
    return 1;
#endif
  sqlr_new_error ("37000", "SP039",
    "%.400s: Internal error (reported by audit): %.1500s",
    ((NULL != sparp && sparp->sparp_err_hdr) ? sparp->sparp_err_hdr : "SPARQL"), msg);
  return 1; /* Never reached */
}


void
spar_internal_error (sparp_t *sparp, const char *msg)
{
#if 0
  const char *txt = ((NULL != sparp) ? sparp->sparp_text : "(no text, sparp is NULL)");
  FILE *core_reason1;
  fprintf (stderr, "Internal error %s while processing\n-----8<-----\n%s\n-----8<-----\n", msg, txt);
  core_reason1 = fopen ("core_reason1","wt");
  fprintf (core_reason1, "Internal error %s while processing\n-----8<-----\n%s\n-----8<-----\n", msg, txt);
  fclose (core_reason1);
  GPF_T1(msg);
#else
#ifdef DEBUG
  const char *txt = ((NULL != sparp) ? sparp->sparp_text : "(no text, sparp is NULL)");
  printf ("Internal error %s while processing\n-----8<-----\n%s\n-----8<-----\n", msg, txt);
  if ((NULL != sparp) && !sparp->sparp_internal_error_runs_audit)
    {
      sparp->sparp_internal_error_runs_audit = 1;
      sparp_audit_mem (sparp);
      sparp_equiv_audit_all (sparp, SPARP_EQUIV_AUDIT_NOBAD);
      sparp->sparp_internal_error_runs_audit = 0;
    }
#endif
  sqlr_new_error ("37000", "SP031",
    "%.400s: Internal error: %.1500s",
    ((NULL != sparp && sparp->sparp_err_hdr) ? sparp->sparp_err_hdr : "SPARQL"), msg);
#endif
}

#ifdef MALLOC_DEBUG
spartlist_track_t *
spartlist_track (const char *file, int line)
{
  static spartlist_track_t ret = { spartlist_impl, spartlist_with_tail_impl };
  spartlist_impl_file = file;
  spartlist_impl_line = line;
  return &ret;
}
#endif

#if 0
void sparqr_free (spar_query_t *sparqr)
{
  dk_free_tree (sparqr->sparqr_tree);
  ;;;
}
#endif

/*
caddr_t spar_charref_to_strliteral (sparp_t *sparp, const char *strg)
{
  const char *src_end = strchr(strg, '\0');
  const char *err_msg = NULL;
  int charref_val = spar_charref_to_unichar (&strg, src_end, &err_msg);
  if (0 > charref_val)
    xpyyerror_impl (sparp, NULL, err_msg);
  else
    {
      char tmp[MAX_UTF8_CHAR];
      char *tgt_tail = eh_encode_char__UTF8 (charref_val, tmp, tmp + MAX_UTF8_CHAR);
      return box_dv_short_nchars (tmp, tgt_tail - tmp);
    }
  return box_dv_short_nchars ("\0", 1);
}
*/

caddr_t
sparp_expand_qname_prefix (sparp_t * sparp, caddr_t qname)
{
  char *lname = strchr (qname, ':');
  dk_set_t ns_dict;
  caddr_t ns_pref, ns_uri, res;
  int ns_uri_len, local_len, res_len;
  if (NULL == lname)
    return qname;
  ns_dict = sparp->sparp_env->spare_namespace_prefixes;
  ns_pref = t_box_dv_short_nchars (qname, lname - qname);
  lname++;
  do
    {
      ns_uri = dk_set_get_keyword (ns_dict, ns_pref, NULL);
      if (NULL != ns_uri)
	break;
      if (!strcmp (ns_pref, "rdf"))
	{
	  ns_uri = uname_rdf_ns_uri;
	  break;
	}
      if (!strcmp (ns_pref, "xsd"))
	{
	  ns_uri = uname_xmlschema_ns_uri_hash;
	  break;
	}
      if (!strcmp (ns_pref, "virtrdf"))
	{
	  ns_uri = uname_virtrdf_ns_uri;
	  break;
	}
      if (!strcmp ("sql", ns_pref))
	{
	  ns_uri = box_dv_uname_string ("sql:");
	  break;
	}
      if (!strcmp ("bif", ns_pref))
	{
	  ns_uri = box_dv_uname_string ("bif:");
	  break;
	}
      ns_uri = xml_get_ns_uri (sparp->sparp_sparqre->sparqre_cli, ns_pref, 0x3, 1 /* ret_in_mp_box */ );
      if (NULL != ns_uri)
	break;
      sparyyerror_impl (sparp, ns_pref, "Undefined namespace prefix");
    }
  while (0);
  ns_uri_len = box_length (ns_uri) - 1;
  local_len = strlen (lname);
  res_len = ns_uri_len + local_len;
  res = box_dv_ubuf (res_len);
  memcpy (res, ns_uri, ns_uri_len);
  memcpy (res + ns_uri_len, lname, local_len);
  res[res_len] = '\0';
  return box_dv_uname_from_ubuf (res);
}

caddr_t
sparp_expand_q_iri_ref (sparp_t *sparp, caddr_t ref)
{
  if (NULL != sparp->sparp_env->spare_base_uri)
    {
      query_instance_t *qi = sparp->sparp_sparqre->sparqre_qi;
      caddr_t err = NULL, path_utf8_tmp, res;
      path_utf8_tmp = xml_uri_resolve (qi,
        &err, sparp->sparp_env->spare_base_uri, ref, "UTF-8" );
      res = t_box_dv_uname_string (path_utf8_tmp);
      dk_free_tree (path_utf8_tmp);
      return res;
    }
  else
    return ref;
}

caddr_t
sparp_exec_Narg (sparp_t *sparp, const char *pl_call_text, query_t **cached_qr_ptr, caddr_t *err_ret, int argctr, ccaddr_t arg1)
{
  query_instance_t *qi = sparp->sparp_sparqre->sparqre_qi;
  client_connection_t *cli = sparp->sparp_sparqre->sparqre_cli;
  local_cursor_t *lc = NULL;
  caddr_t err = NULL;
  if (NULL == cached_qr_ptr[0])
    {
      if (CALLER_CLIENT == (query_instance_t *) cli) /* This means that the call is made inside the SQL compiler, can't re-enter. */
        spar_internal_error (sparp, "sparp_exec_Narg () tries to compile static inside the SQL compiler");
      cached_qr_ptr[0] = sql_compile_static (pl_call_text, cli, &err, SQLC_DEFAULT);
      if (SQL_SUCCESS != err)
	{
	  cached_qr_ptr[0] = NULL;
	  if (err_ret)
	    *err_ret = err;
	  return NULL;
	}
    }
  err = qr_rec_exec (cached_qr_ptr[0], cli, &lc, qi, NULL, 1,
      ":0", box_copy_tree (arg1), QRP_RAW );
  if (SQL_SUCCESS != err)
    {
      LC_FREE(lc);
      if (err_ret)
	*err_ret = err;
      return NULL;
    }
  if (lc)
    {
      caddr_t ret = NULL;
#if 1
      while (lc_next (lc));
      if (SQL_SUCCESS != lc->lc_error)
	{
	  if (err_ret)
	    *err_ret = lc->lc_error;
	  lc_free (lc);
	  return NULL;
	}
      ret = t_full_box_copy_tree (((caddr_t *) lc->lc_proc_ret) [1]);
#else
      ret = t_full_box_copy_tree(lc_nth_col (lc, 0));
#endif
      lc_free (lc);
      return ret;
    }
  return NULL;
}


static query_t *iri_to_id_nosignal_cached_qr = NULL;
static const char *iri_to_id_nosignal_text = "DB.DBA.RDF_MAKE_IID_OF_QNAME_SAFE (?)";

caddr_t
sparp_iri_to_id_nosignal (sparp_t *sparp, caddr_t qname)
{
  caddr_t t_err, err = NULL;
  if (CALLER_LOCAL != sparp->sparp_sparqre->sparqre_qi)
    {
      caddr_t res = iri_to_id ((caddr_t *)(sparp->sparp_sparqre->sparqre_qi), qname, IRI_TO_ID_WITH_CREATE, &err);
      if (NULL == err)
        {
          caddr_t t_res = t_box_copy (res);
          dk_free_box (res);
          return t_res;
        }
    }
  else
    {
      caddr_t t_res = sparp_exec_Narg (sparp, iri_to_id_nosignal_text, &iri_to_id_nosignal_cached_qr, &err, 1, qname);
      if (DV_DB_NULL == DV_TYPE_OF (t_res))
        t_res = NULL;
      if (NULL == err)
        return t_res;
    }
  t_err = t_full_box_copy_tree (err);
  dk_free_tree (err);
  spar_error (sparp, "Unable to get IRI_ID for IRI <%.200s>: %.10s %.600s",
    qname, ERR_STATE(t_err), ERR_MESSAGE (t_err) );
  return NULL; /* to keep compiler happy */
}

extern caddr_t key_id_to_iri (query_instance_t * qi, iri_id_t iri_id_no);

static query_t *id_to_iri_cached_qr = NULL;
static const char *id_to_iri_text = "select DB.DBA.RDF_QNAME_OF_IID (?)";

ccaddr_t
sparp_id_to_iri (sparp_t *sparp, iri_id_t iid)
{
  caddr_t t_err, err = NULL;
  if (CALLER_LOCAL != sparp->sparp_sparqre->sparqre_qi)
    {
      caddr_t res = key_id_to_iri (sparp->sparp_sparqre->sparqre_qi, iid);
      caddr_t t_res = t_box_copy (res);
      dk_free_box (res);
      return t_res;
    }
  else
    {
      caddr_t t_res = sparp_exec_Narg (sparp, id_to_iri_text, &id_to_iri_cached_qr, &err, 1, box_iri_id (iid));
      if (DV_DB_NULL == DV_TYPE_OF (t_res))
        t_res = NULL;
      if (NULL == err)
        return t_res;
    }
  t_err = t_full_box_copy_tree (err);
  dk_free_tree (err);
  spar_error (sparp, "unknown IRI_ID %Lu: %.10s %.600s",
    iid, ERR_STATE(t_err), ERR_MESSAGE (t_err) );
  return NULL; /* to keep compiler happy */
}

caddr_t spar_strliteral (sparp_t *sparp, const char *strg, int strg_is_long, int is_json)
{
  caddr_t tmp_buf;
  caddr_t res;
  const char *err_msg;
  const char *src_tail, *src_end;
  char *tgt_tail;
  src_tail = strg + (strg_is_long ? 3 : 1);
  src_end = strg + strlen (strg) - (strg_is_long ? 3 : 1);
  tgt_tail = tmp_buf = dk_alloc_box ((src_end - src_tail) + 1, DV_SHORT_STRING);
  while (src_tail < src_end)
    {
      switch (src_tail[0])
	{
	case '\\':
          {
	    const char *bs_src		= "abfnrtv/\\\'\"uU";
	    const char *bs_trans	= "\a\b\f\n\r\t\v/\\\'\"\0\0";
            const char *bs_lengths	= "\2\2\2\2\2\2\2\2\2\2\2\6\012";
	    const char *hit = strchr (bs_src, src_tail[1]);
	    char bs_len, bs_tran;
	    const char *nextchr;
	    if (NULL == hit)
	      {
		err_msg = "Unsupported escape sequence after '\'";
		goto err;
	      }
            bs_len = bs_lengths [hit - bs_src];
            bs_tran = bs_trans [hit - bs_src];
	    nextchr = src_tail + bs_len;
	    if ((src_tail + bs_len) > src_end)
	      {
	        err_msg = "There is no place for escape sequence between '\' and the end of string";
	        goto err;
	      }
            if ('\0' != bs_tran)
              (tgt_tail++)[0] = bs_tran;
	    else
	      {
		unichar acc = 0;
		for (src_tail += 2; src_tail < nextchr; src_tail++)
		  {
		    int dgt = src_tail[0];
		    if ((dgt >= '0') && (dgt <= '9'))
		      dgt = dgt - '0';
		    else if ((dgt >= 'A') && (dgt <= 'F'))
		      dgt = 10 + dgt - 'A';
		    else if ((dgt >= 'a') && (dgt <= 'f'))
		      dgt = 10 + dgt - 'a';
		    else
		      {
		        err_msg = "Invalid hexadecimal digit in escape sequence";
			goto err;
		      }
		    acc = acc * 16 + dgt;
		  }
		if (acc < 0)
		  {
		    err_msg = "The \\U escape sequence represents invalid Unicode char";
		    goto err;
		  }
		tgt_tail = eh_encode_char__UTF8 (acc, tgt_tail, tgt_tail + MAX_UTF8_CHAR);
	      }
	    src_tail = nextchr;
            continue;
	  }
	default: (tgt_tail++)[0] = (src_tail++)[0];
	}
    }
  res = t_box_dv_short_nchars (tmp_buf, tgt_tail - tmp_buf);
  dk_free_box (tmp_buf);
  return res;

err:
  dk_free_box (tmp_buf);
  if (is_json)
    jsonyyerror_impl (err_msg);
  else
    sparyyerror_impl (sparp, NULL, err_msg);
  return NULL;
}

void
sparp_free (sparp_t * sparp)
{
}

caddr_t
spar_mkid (sparp_t * sparp, const char *prefix)
{
  return t_box_sprintf (0x100, "%s-%ld-%ld",
    prefix,
    (long)((NULL != sparp->sparp_curr_lexem) ?
      sparp->sparp_curr_lexem->sparl_lineno : 0),
    (long)(sparp->sparp_unictr++) );
}

void spar_change_sign (caddr_t *lit_ptr)
{
  switch (DV_TYPE_OF (lit_ptr[0]))
    {
    case DV_NUMERIC:
      {
        numeric_t tmp = t_numeric_allocate();
        numeric_negate (tmp, (numeric_t)(lit_ptr[0]));
        lit_ptr[0] = (caddr_t)tmp;
        break;
      }
    case DV_LONG_INT:
      lit_ptr[0] = t_box_num (- unbox (lit_ptr[0]));
      break;
    case DV_DOUBLE_FLOAT:
      lit_ptr[0] = t_box_double (- ((double *)(lit_ptr[0]))[0]);
      break;
    default: GPF_T1("spar_change_sign(): bad box type");
    }
}

static const char *sparp_known_get_params[] = {
    "get:login", "get:method", "get:proxy", "get:query", "get:refresh", "get:soft", "get:uri", NULL };

static const char *sparp_integer_defines[] = {
    "input:grab-depth", "input:grab-limit", "sql:log-enable", "sql:signal-void-variables", NULL };

static const char *sparp_var_defines[] = { NULL };

void
sparp_define (sparp_t *sparp, caddr_t param, ptrlong value_lexem_type, caddr_t value)
{
  switch (value_lexem_type)
    {
    case Q_IRI_REF:
      value = sparp_expand_q_iri_ref (sparp, value);
      break;
    case QNAME:
      value = sparp_expand_qname_prefix (sparp, value);
      break;
    case SPARQL_INTEGER:
      {
        const char **chk;
        for (chk = sparp_integer_defines; (NULL != chk[0]) && strcmp (chk[0], param); chk++) ;
        if (NULL == chk[0])
          spar_error (sparp, "Integer value %ld is specified for define %s", (long)unbox(value), param);
        break;
      }
    case SPAR_VARIABLE:
      {
        const char **chk;
        for (chk = sparp_var_defines; (NULL != chk[0]) && strcmp (chk[0], param); chk++) ;
        if (NULL == chk[0])
          spar_error (sparp, "The value specified for define %s should be constant, not an variable", param);
        break;
      }
    }
  if ((7 < strlen (param)) && !memcmp (param, "output:", 7))
    {
      if (!strcmp (param, "output:valmode")) {
          sparp->sparp_env->spare_output_valmode_name = t_box_dv_uname_string (value); return; }
      if (!strcmp (param, "output:format")) {
          sparp->sparp_env->spare_output_format_name = t_box_dv_uname_string (value); return; }
      if (!strcmp (param, "output:scalar-format")) {
          sparp->sparp_env->spare_output_scalar_format_name = t_box_dv_uname_string (value); return; }
      if (!strcmp (param, "output:dict-format")) {
          sparp->sparp_env->spare_output_dict_format_name = t_box_dv_uname_string (value); return; }
      if (!strcmp (param, "output:route")) {
          sparp->sparp_env->spare_output_route_name = t_box_dv_uname_string (value); return; }
    }
  if ((6 < strlen (param)) && !memcmp (param, "input:", 6))
    {
      if (!strcmp (param, "input:default-graph-uri"))
        {
          SPART *new_precode = sparp_make_graph_precode ( sparp, SPART_GRAPH_FROM,
            spartlist (sparp, 2, SPAR_QNAME, t_box_dv_uname_string (value)),
            NULL );
          sparp_push_new_graph_source (sparp,
            &(sparp->sparp_env->spare_default_graphs),
            new_precode );
          sparp->sparp_env->spare_default_graphs_listed++;
          sparp->sparp_env->spare_default_graphs_locked = 1;
          return;
        }
      if (!strcmp (param, "input:default-graph-exclude"))
        {
          SPART *new_precode = sparp_make_graph_precode ( sparp, SPART_GRAPH_NOT_FROM,
            spartlist (sparp, 2, SPAR_QNAME, t_box_dv_uname_string (value)),
            NULL );
          sparp_push_new_graph_source (sparp,
            &(sparp->sparp_env->spare_default_graphs),
            new_precode );
          /* No sparp->sparp_env->spare_default_graphs_locked = 1; here because NOT FROM can not be overridden */
          return;
        }
      if (!strcmp (param, "input:named-graph-uri"))
        {
          SPART *new_precode = sparp_make_graph_precode ( sparp, SPART_GRAPH_NAMED,
            spartlist (sparp, 2, SPAR_QNAME, t_box_dv_uname_string (value)),
            NULL );
          sparp_push_new_graph_source (sparp,
            &(sparp->sparp_env->spare_named_graphs),
            new_precode );
          sparp->sparp_env->spare_named_graphs_listed++;
          sparp->sparp_env->spare_named_graphs_locked = 1;
          return;
        }
      if (!strcmp (param, "input:named-graph-exclude"))
        {
          SPART *new_precode = sparp_make_graph_precode ( sparp, SPART_GRAPH_NOT_NAMED, 
            spartlist (sparp, 2, SPAR_QNAME, t_box_dv_uname_string (value)),
            NULL );
          sparp_push_new_graph_source (sparp,
            &(sparp->sparp_env->spare_named_graphs),
            new_precode );
          /* No sparp->sparp_env->spare_default_graphs_locked = 1; here because NOT FROM can not be overridden */
          return;
        }
      if (!strcmp (param, "input:ifp"))
        {
          sparp->sparp_env->spare_use_ifp = t_box_copy_tree (value);
          return;
        }
      if (!strcmp (param, "input:same-as"))
        {
          sparp->sparp_env->spare_use_same_as = t_box_copy_tree (value);
          return;
        }
      if (!strcmp (param, "input:storage"))
        {
          if (NULL != sparp->sparp_env->spare_storage_name)
            spar_error (sparp, "'define %.30s' is used more than once", param);
          sparp->sparp_env->spare_storage_name = t_box_dv_uname_string (value);
          return;
        }
      if (!strcmp (param, "input:inference"))
        {
          if (NULL != sparp->sparp_env->spare_inference_name)
            spar_error (sparp, "'define %.30s' is used more than once", param);
          sparp->sparp_env->spare_inference_name = t_box_dv_uname_string (value);
          return;
        }
      if ((11 < strlen (param)) && !memcmp (param, "input:grab-", 11))
        {
          rdf_grab_config_t *rgc = &(sparp->sparp_env->spare_grab);
          const char *lock_pragma = NULL;
          rgc->rgc_pview_mode = 1;
          if (sparp->sparp_env->spare_default_graphs_locked)
            lock_pragma = "input:default-graph-uri";
          else if (sparp->sparp_env->spare_named_graphs_locked)
            lock_pragma = "input:named-graph-uri";
          if (NULL != lock_pragma)
            spar_error (sparp, "define %s should not appear after define %s", param, lock_pragma);
          if (!strcmp (param, "input:grab-all"))
            {
              rgc->rgc_all = 1;
              return;
            }
          if (!strcmp (param, "input:grab-intermediate"))
            {
              rgc->rgc_intermediate = 1;
              return;
            }
          if (!strcmp (param, "input:grab-seealso") || !strcmp (param, "input:grab-follow-predicate"))
            {
              switch (value_lexem_type)
                {
                case QNAME:
                case Q_IRI_REF:
                  t_set_push (&(rgc->rgc_sa_preds), value);
                  break;
                default:
                  if (('?' == value[0]) || ('$' == value[0]))
                    spar_error (sparp, "The value of define input:grab-seealso should be predicate name");
                  else
                    t_set_push_new_string (&(rgc->rgc_sa_preds), value);
                }
              return;
            }
          if (!strcmp (param, "input:grab-iri"))
            {
              switch (value_lexem_type)
                {
                case QNAME:
                case Q_IRI_REF:
                  t_set_push (&(rgc->rgc_consts), value);
                  break;
                default:
                  if (('?' == value[0]) || ('$' == value[0]))
                    t_set_push_new_string (&(rgc->rgc_vars), t_box_dv_uname_string (value+1));
                  else
                    t_set_push_new_string (&(rgc->rgc_consts), value);
                }
              return;
            }
          if (!strcmp (param, "input:grab-var"))
            {
              caddr_t varname;
              if (('?' == value[0]) || ('$' == value[0]))
                varname = t_box_dv_uname_string (value+1);
              else
                varname = t_box_dv_uname_string (value);
              t_set_push_new_string (&(rgc->rgc_vars), varname);
              return;
            }
          if (!strcmp (param, "input:grab-depth"))
            {
              ptrlong val = ((DV_LONG_INT == DV_TYPE_OF (value)) ? unbox_ptrlong (value) : -1);
              if (0 >= val)
                spar_error (sparp, "define input:grab-depth should have positive integer value");
              rgc->rgc_depth = t_box_num_nonull (val);
              return;
            }
          if (!strcmp (param, "input:grab-limit"))
            {
              ptrlong val = ((DV_LONG_INT == DV_TYPE_OF (value)) ? unbox_ptrlong (value) : -1);
              if (0 >= val)
                spar_error (sparp, "define input:grab-limit should have positive integer value");
              rgc->rgc_limit = t_box_num_nonull (val);
              return;
            }
          if (!strcmp (param, "input:grab-base")) {
              rgc->rgc_base = t_box_dv_uname_string (value); return; }
          if (!strcmp (param, "input:grab-destination")) {
              rgc->rgc_destination = t_box_dv_uname_string (value); return; }
          if (!strcmp (param, "input:grab-group-destination")) {
              rgc->rgc_group_destination = t_box_dv_uname_string (value); return; }
          if (!strcmp (param, "input:grab-resolver")) {
              rgc->rgc_resolver_name = t_box_dv_uname_string (value); return; }
          if (!strcmp (param, "input:grab-loader")) {
              rgc->rgc_loader_name = t_box_dv_uname_string (value); return; }
        }
      else if (!strcmp (param, "input:param") || !strcmp (param, "input:params")) {
          t_set_push (&(sparp->sparp_env->spare_protocol_params), t_box_dv_uname_string (value));
          return; }
      else if (!strcmp (param, "input:param-valmode")) {
          sparp->sparp_env->spare_input_param_valmode_name = t_box_dv_uname_string (value); return; }
    }
  if ((4 < strlen (param)) && !memcmp (param, "get:", 4))
    {
      const char **chk;
      for (chk = sparp_known_get_params; (NULL != chk[0]) && strcmp (chk[0], param); chk++) ;
      if (NULL != chk[0])
        {
          dk_set_t *opts_ptr = &(sparp->sparp_env->spare_common_sponge_options);
          if (0 < dk_set_position_of_string (opts_ptr[0], param))
            spar_error (sparp, "'define %.30s' is used more than once", param);
          t_set_push (opts_ptr, t_box_dv_short_string (value));
          t_set_push (opts_ptr, t_box_dv_uname_string (param));
          return;
        }
    }
  if ((4 < strlen (param)) && !memcmp (param, "sql:", 4))
    {
      if (!strcmp (param, "sql:assert-user")) {
          user_t *u = sparp->sparp_sparqre->sparqre_exec_user;
          if (NULL == u)
            spar_error (sparp, "Assertion \"define sql:assert-user '%.200s'\" failed: user is not set", value);
          if (strcmp (value, u->usr_name))
            spar_error (sparp, "Assertion \"define sql:assert-user '%.200s'\" failed: the user is set to '%.200s'", value, u->usr_name);
          return; }
      if (!strcmp (param, "sql:param") || !strcmp (param, "sql:params")) {
          t_set_push (&(sparp->sparp_env->spare_protocol_params), t_box_dv_uname_string (value));
          return; }
      if (!strcmp (param, "sql:log-enable")) {
          ptrlong val = ((DV_LONG_INT == DV_TYPE_OF (value)) ? unbox_ptrlong (value) : -1);
          if (0 > val)
            spar_error (sparp, "define sql:log-enable should have nonnegative integer value");
            sparp->sparp_env->spare_sparul_log_mode = t_box_num_and_zero (val);
          return; }
      if (!strcmp (param, "sql:table-option")) {
          t_set_push (&(sparp->sparp_env->spare_common_sql_table_options), t_box_dv_uname_string (value));
          return; }
      if (!strcmp (param, "sql:select-option")) {
          t_set_push (&(sparp->sparp_env->spare_sql_select_options), t_box_dv_uname_string (value));
          return; }
      if (!strcmp (param, "sql:describe-mode")) {
          sparp->sparp_env->spare_describe_mode = t_box_dv_uname_string (value);
          return; }
      if (!strcmp (param, "sql:signal-void-variables")) {
          ptrlong val = ((DV_LONG_INT == DV_TYPE_OF (value)) ? unbox_ptrlong (value) : -1);
          if ((0 > val) || (1 < val))
            spar_error (sparp, "define sql:signal-void-variables should have value 0 or 1");
            sparp->sparp_env->spare_signal_void_variables = val;
          return; }
    }
  spar_error (sparp, "Unsupported parameter '%.30s' in 'define'", param);
}

caddr_t
spar_selid_push (sparp_t *sparp)
{
  caddr_t selid = spar_mkid (sparp, "s");
  t_set_push (&(sparp->sparp_env->spare_selids), selid );
  spar_dbg_printf (("spar_selid_push () pushes %s\n", selid));
  return selid;
}

caddr_t
spar_selid_push_reused (sparp_t *sparp, caddr_t selid)
{
  t_set_push (&(sparp->sparp_env->spare_selids), selid );
  spar_dbg_printf (("spar_selid_push_reused () pushes %s\n", selid));
  return selid;
}


caddr_t spar_selid_pop (sparp_t *sparp)
{
  caddr_t selid = t_set_pop (&(sparp->sparp_env->spare_selids));
  spar_dbg_printf (("spar_selid_pop () pops %s\n", selid));
  return selid;
}

void spar_gp_init (sparp_t *sparp, ptrlong subtype)
{
  sparp_env_t *env = sparp->sparp_env;
  spar_dbg_printf (("spar_gp_init (..., %ld)\n", (long)subtype));
  spar_selid_push (sparp);
  t_set_push (&(env->spare_acc_req_triples), NULL);
  t_set_push (&(env->spare_acc_opt_triples), NULL);
  t_set_push (&(env->spare_acc_filters), NULL);
  t_set_push (&(env->spare_context_gp_subtypes), (caddr_t)subtype);
  t_set_push (&(env->spare_good_graph_varname_sets), env->spare_good_graph_varnames);
  if (WHERE_L != subtype)
    t_set_push (&(sparp->sparp_env->spare_propvar_sets), NULL); /* For WHERE_L it's done at beginning of the result-set. */
}

void spar_gp_replace_selid (sparp_t *sparp, dk_set_t membs, caddr_t old_selid, caddr_t new_selid)
{
  DO_SET (SPART *, memb, &membs)
    {
      int fld_ctr;
      if (SPAR_TRIPLE != SPART_TYPE (memb))
        continue;
      if (strcmp (old_selid, memb->_.triple.selid))
        spar_internal_error (sparp, "spar_gp_replace_selid(): bad selid of triple");
      memb->_.triple.selid = new_selid;
      for (fld_ctr = SPART_TRIPLE_FIELDS_COUNT; fld_ctr--; /*no step*/)
        {
          SPART *fld = memb->_.triple.tr_fields[fld_ctr];
          if ((SPAR_VARIABLE != SPART_TYPE (fld)) &&
            (SPAR_BLANK_NODE_LABEL != SPART_TYPE (fld)) )
            continue;
          if (strcmp (old_selid, fld->_.var.selid))
            spar_internal_error (sparp, "spar_gp_replace_selid(): bad selid of var or bnode label");
          fld->_.var.selid = new_selid;
        }
    }
  END_DO_SET ()
}

SPART *
spar_gp_finalize (sparp_t *sparp, SPART **options)
{
  sparp_env_t *env = sparp->sparp_env;
  caddr_t orig_selid = env->spare_selids->data;
  dk_set_t propvars = (dk_set_t) t_set_pop (&(env->spare_propvar_sets));
  dk_set_t req_membs;
  dk_set_t opt_membs;
  dk_set_t filts;
  ptrlong subtype;
  SPART *res;
  spar_dbg_printf (("spar_gp_finalize (..., %ld)\n", (long)subtype));
/* Create triple patterns for distinct '+>' propvars and OPTIONAL triple patterns for distinct '*>' propvars */
  DO_SET (spar_propvariable_t *, pv, &propvars)
    {
      if (_STAR_GT == pv->sparpv_op)
        spar_gp_init (sparp, OPTIONAL_L);
      spar_gp_add_triple_or_special_filter (sparp, NULL,
          spar_make_variable (sparp, pv->sparpv_subj_var->_.var.vname),
          pv->sparpv_verb_qname,
          spar_make_variable (sparp, pv->sparpv_obj_var_name),
          NULL, NULL );
      if (_STAR_GT == pv->sparpv_op)
        {
          SPART *pv_gp;
          pv_gp = spar_gp_finalize (sparp, NULL);
          t_set_push (((dk_set_t *)(&(env->spare_acc_req_triples->data))) /* not &req_membs */, pv_gp);
        }
    }
  END_DO_SET();
/* Pop the rest of the environment and adjust graph varnames */
  req_membs = (dk_set_t) t_set_pop (&(env->spare_acc_req_triples));
  opt_membs = (dk_set_t) t_set_pop (&(env->spare_acc_opt_triples));
  filts = (dk_set_t) t_set_pop (&(env->spare_acc_filters));
  subtype = (ptrlong)((void *)t_set_pop (&(env->spare_context_gp_subtypes)));
  env->spare_good_graph_bmk = t_set_pop (&(env->spare_good_graph_varname_sets));
/* The following 'if' does not mention UNIONs because UNIONs are handled right in .y file
   For OPTIONAL GP we roll back spare_good_graph_vars at bookmarked level
   For other sorts the content of stack is naturally inherited by the parent:
   the bookmark is t_set_pop-ed, but the content remains at its place */
  if (OPTIONAL_L == subtype) /* Variables nested in optionals can not be good graph variables... */
    env->spare_good_graph_varnames = env->spare_good_graph_bmk;
/* Add extra GP to guarantee proper left side of the left outer join */
  if ((1 < dk_set_length (req_membs)) && (0 < dk_set_length (opt_membs)))
    {
      SPART *left_group;
      spar_gp_init (sparp, 0);
      spar_gp_replace_selid (sparp, req_membs, orig_selid, env->spare_selids->data);
      env->spare_acc_req_triples->data = req_membs;
      left_group = spar_gp_finalize (sparp, NULL);
      req_membs = NULL;
      t_set_push (&req_membs, left_group);
    }
/* Add extra GP to guarantee proper support of {... OPTIONAL { ... ?x ... } ... OPTIONAL { ... ?x ... } } */
  if (1 < dk_set_length (opt_membs))
    {
      SPART *last_opt;
      SPART *left_group;
      last_opt = (SPART *)t_set_pop (&opt_membs);
      spar_gp_init (sparp, 0);
      spar_gp_replace_selid (sparp, req_membs, orig_selid, env->spare_selids->data);
      env->spare_acc_req_triples->data = req_membs;
      spar_gp_replace_selid (sparp, opt_membs, orig_selid, env->spare_selids->data);
      env->spare_acc_opt_triples->data = opt_membs;
      left_group = spar_gp_finalize (sparp, NULL);
      req_membs = NULL;
      t_set_push (&req_membs, left_group);
      opt_membs = NULL;
      t_set_push (&opt_membs, last_opt);
    }
/* Plain composing of SPAR_GP tree node */
  res = spartlist (sparp, 10,
    SPAR_GP, subtype,
    /* opt members are at the first place in NCONC because there's a reverse in t_revlist_to_array */
    t_revlist_to_array (t_NCONC (opt_membs, req_membs)),
    t_revlist_to_array (filts),
    NULL,
    orig_selid,
    NULL, (ptrlong)(0), (ptrlong)(0), options );
  spar_selid_pop (sparp);
  return res;
}

SPART *
spar_gp_finalize_with_subquery (sparp_t *sparp, SPART **options, SPART *subquery)
{
  SPART *gp;
  gp = spar_gp_finalize (sparp, options);
  gp->_.gp.subquery = subquery;
  gp->_.gp.subtype = SELECT_L;
  if (NULL != options)
    sparp_validate_options_of_tree (sparp, gp, options);
  return gp;
}

void spar_gp_add_member (sparp_t *sparp, SPART *memb)
{
  dk_set_t *set_ptr;
  spar_dbg_printf (("spar_gp_add_member ()\n"));
  if ((SPAR_GP == SPART_TYPE (memb)) && (OPTIONAL_L == memb->_.gp.subtype))
    set_ptr = (dk_set_t *)(&(sparp->sparp_env->spare_acc_opt_triples->data));
  else
    set_ptr = (dk_set_t *)(&(sparp->sparp_env->spare_acc_req_triples->data));
  t_set_push (set_ptr, memb);
}

int
spar_filter_is_freetext (SPART *filt)
{
  caddr_t fname;
  if (SPAR_FUNCALL != SPART_TYPE (filt))
    return 0;
  fname = filt->_.funcall.qname;
  if (!strcmp (fname, "bif:contains"))
    return SPAR_FT_CONTAINS;
  if (!strcmp (fname, "bif:xcontains"))
    return SPAR_FT_XCONTAINS;
  if (!strcmp (fname, "bif:xpath_contains"))
    return SPAR_FT_XPATH_CONTAINS;
  if (!strcmp (fname, "bif:xquery_contains"))
    return SPAR_FT_XQUERY_CONTAINS;
  return 0;
}

int
spar_tree_is_var_with_forbidden_ft_name (sparp_t *sparp, SPART *tree, int report_error)
{
  caddr_t vname;
  if (!SPAR_IS_BLANK_OR_VAR (tree))
    return 0;
  vname = tree->_.var.vname;
  if (strcasecmp (vname, "SCORE") &&
    strcasecmp (vname, "XCONTAINS_MAIN_RANGES") &&
    strcasecmp (vname, "XCONTAINS_ATTR_RANGES") )
    return 0;
  if (report_error)
    spar_error (sparp, "Free-text triple pattern uses variable name '%s'; this name has special meaning in free-text SQL; please rename it to avoid unexpected effects", vname);
  return 1;
}

void
spar_gp_add_filter (sparp_t *sparp, SPART *filt)
{
  int filt_type = SPART_TYPE (filt);
  int ft_type;
  if (BOP_AND == filt_type)
    {
      spar_gp_add_filter (sparp, filt->_.bin_exp.left);
      spar_gp_add_filter (sparp, filt->_.bin_exp.right);
      return;
    }
  ft_type = spar_filter_is_freetext (filt);
  if (ft_type)
    {
      caddr_t ft_pred_name = filt->_.funcall.qname;
      SPART *ft_literal_var;
      caddr_t var_name;
      dk_set_t *req_triples_ptr;
      SPART **args, *triple_with_var_obj = NULL;
      int argctr, argcount, fld_ctr;
      args = filt->_.funcall.argtrees;
      argcount = BOX_ELEMENTS (args);
      if (2 > argcount)
        spar_error (sparp, "Not enough parameters for special predicate %s()", ft_pred_name);
      ft_literal_var = filt->_.funcall.argtrees[0];
      if (SPAR_VARIABLE != SPART_TYPE (ft_literal_var))
        spar_error (sparp, "The first argument of special predicate %s() should be a variable", ft_pred_name);
      var_name = ft_literal_var->_.var.vname;
      req_triples_ptr = (dk_set_t *)(&(sparp->sparp_env->spare_acc_req_triples->data));
      DO_SET (SPART *, memb, req_triples_ptr)
        {
          SPART *obj;
          if (SPAR_TRIPLE != SPART_TYPE (memb))
            continue;
          obj = memb->_.triple.tr_object;
          if (SPAR_VARIABLE != SPART_TYPE (obj))
            continue;
          if (strcmp (obj->_.var.vname, var_name))
            continue;
          if (memb->_.triple.ft_type)
            spar_error (sparp, "More than one %s() or similar predicate for '$%s' variable in a single group", ft_pred_name, var_name);
          if (NULL == triple_with_var_obj)
            triple_with_var_obj = memb;
        }
      END_DO_SET ()
      if (NULL == triple_with_var_obj)
        spar_error (sparp, "The group does not contain triple pattern with '$%s' object before %s() predicate", var_name, ft_pred_name);
      triple_with_var_obj->_.triple.ft_type = ft_type;
      if (2 < argcount)
        for (argctr = 2; argctr < argcount; argctr += 2)
          {
            SPART *arg_value = args[argctr+1];
            SPART *opt_value;
            if (SPAR_VARIABLE != SPART_TYPE (arg_value))
              continue;
            spar_tree_is_var_with_forbidden_ft_name (sparp, arg_value, 1);
            opt_value = (SPART *)t_box_copy_tree ((caddr_t)arg_value);
            opt_value->_.var.tabid = triple_with_var_obj->_.triple.tabid;
            opt_value->_.var.tr_idx = (ptrlong)args[argctr];
            triple_with_var_obj->_.triple.options = (SPART **) t_list_concat (
              (caddr_t)(triple_with_var_obj->_.triple.options),
              (caddr_t)t_list (2, args[argctr], opt_value) );
          }
      for (fld_ctr = 0; fld_ctr < SPART_TRIPLE_FIELDS_COUNT; fld_ctr++)
        spar_tree_is_var_with_forbidden_ft_name (sparp, triple_with_var_obj->_.triple.tr_fields[fld_ctr], 1);
      if (IS_BOX_POINTER (sparp->sparp_env->spare_sql_refresh_free_text))
        ((boxint *)(sparp->sparp_env->spare_sql_refresh_free_text))[0] = 1;
      else
        sparp->sparp_env->spare_sql_refresh_free_text = t_box_num (1);
    }
  if (NULL == sparp->sparp_env->spare_acc_filters)
    spar_internal_error (sparp, "spar_" "gp_add_filter(): NULL sparp->sparp_env->spare_acc_filters");
  t_set_push ((dk_set_t *)(&(sparp->sparp_env->spare_acc_filters->data)), filt);
}

void
spar_gp_add_filters_for_graph (sparp_t *sparp, SPART *graph_expn, dk_set_t sources, int suppress_filters_for_good_names)
{
  sparp_env_t *env = sparp->sparp_env;
  caddr_t varname;
  int src_count;
  SPART *graph_expn_copy, *filter;
  if (NULL == sources)
    return;
  if (!SPAR_IS_BLANK_OR_VAR (graph_expn))
    return;
  varname = graph_expn->_.var.vname;
  if (suppress_filters_for_good_names)
    {
      dk_set_t good_varnames = env->spare_good_graph_varnames;
      if (0 <= dk_set_position_of_string (good_varnames, varname))
        return;
    }
  graph_expn_copy = (
    (SPAR_VARIABLE == SPART_TYPE (graph_expn)) ?
    spar_make_variable (sparp, varname) :
    spar_make_blank_node (sparp, varname, 0) );
  src_count = dk_set_length (sources);
  if (1 == src_count)
    {
      SPART *src = (SPART *)(sources->data);
      filter = spartlist (sparp, 3,
        (((SPART_GRAPH_NOT_FROM == src->_.graph.subtype) ||
            (SPART_GRAPH_NOT_NAMED == src->_.graph.subtype) ) ?
          BOP_NEQ : BOP_EQ),
        graph_expn_copy, src->_.graph.expn );
        spar_gp_add_filter (sparp, filter);
    }
  else
    {
      dk_set_t good_expns = NULL;
      dk_set_t bad_expns = NULL;
      DO_SET (SPART *,src, &(sources))
        {
          if (!((SPART_GRAPH_NOT_FROM == src->_.graph.subtype) || (SPART_GRAPH_NOT_NAMED == src->_.graph.subtype)))
            t_set_push (&good_expns, src->_.graph.expn);
          else
            t_set_push (&bad_expns, src->_.graph.expn);
        }
      END_DO_SET()
      if (NULL != good_expns)
        {
          t_set_push (&good_expns, graph_expn_copy);
          filter = spartlist (sparp, 3, SPAR_BUILT_IN_CALL, (ptrlong)IN_L,
            (SPART **)t_list_to_array (good_expns) );
          spar_gp_add_filter (sparp, filter);
        }
      if (NULL != bad_expns)
        {
          graph_expn_copy = (
            (SPAR_VARIABLE == SPART_TYPE (graph_expn)) ?
            spar_make_variable (sparp, varname) :
            spar_make_blank_node (sparp, varname, 0) );
          t_set_push (&bad_expns, graph_expn_copy);
          filter = spartlist (sparp, 3, SPAR_BUILT_IN_CALL, (ptrlong)IN_L, 
            (SPART **)t_list_to_array (bad_expns) );
          filter = spartlist (sparp, 2, BOP_NOT, filter);
          spar_gp_add_filter (sparp, filter);
        }
    }
}

void
spar_gp_add_filters_for_named_graph (sparp_t *sparp)
{
  sparp_env_t *env = sparp->sparp_env;
  SPART *graph_expn = (SPART *)(env->spare_context_graphs->data);
  spar_gp_add_filters_for_graph (sparp, graph_expn, env->spare_named_graphs, 0);
}

SPART *
spar_add_propvariable (sparp_t *sparp, SPART *lvar, int opcode, SPART *verb_qname, int verb_lexem_type, caddr_t verb_lexem_text)
{
  int lvar_blen, verb_qname_blen;
  caddr_t new_key;
  spar_propvariable_t *curr_pv = NULL;
  const char *optext = ((_PLUS_GT == opcode) ? "+>" : "*>");
  caddr_t *spec_pred_names = jso_triple_get_objs (
    (caddr_t *)(sparp->sparp_sparqre->sparqre_qi),
    verb_qname->_.lit.val,
    uname_virtrdf_ns_uri_isSpecialPredicate );
  if (0 != BOX_ELEMENTS (spec_pred_names))
    {
      dk_free_tree (spec_pred_names);
      spar_error (sparp, "?%.200s %s ?%.200s is not allowed because it uses special predicate name", lvar->_.var.vname, optext, verb_lexem_text);
    }
  if (NULL == sparp->sparp_env->spare_propvar_sets)
    {
      dk_free_tree (spec_pred_names);
      spar_error (sparp, "?%.200s %s ?%.200s is used in illegal context", lvar->_.var.vname, optext, verb_lexem_text);
    }
  dk_free_tree (spec_pred_names);

  lvar_blen = box_length (lvar->_.var.vname);
  verb_qname_blen = box_length (verb_qname->_.lit.val);
  new_key = t_alloc_box (lvar_blen + verb_qname_blen + 1, DV_STRING);
  memcpy (new_key, lvar->_.var.vname, lvar_blen);
  memcpy (new_key + lvar_blen - 1, optext, 2);
  memcpy (new_key + lvar_blen + 1, verb_qname->_.lit.val, verb_qname_blen);
  DO_SET (spar_propvariable_t *, prev, &(sparp->sparp_propvars))
    {
      if (strcmp (prev->sparpv_key, new_key))
        continue;
      if ((prev->sparpv_verb_lexem_type != verb_lexem_type) ||
        strcmp (prev->sparpv_verb_lexem_text, verb_lexem_text) )
        spar_error (sparp, "Variables ?%.200s %s %s?%.200s%s and ?%.200s %s %s?%.200s%s are written different ways but may mean the same; remove this ambiguity",
        lvar->_.var.vname, optext,
        ((Q_IRI_REF == verb_lexem_type) ? "<" : ""), verb_lexem_text,
        ((Q_IRI_REF == verb_lexem_type) ? ">" : ""),
        prev->sparpv_subj_var->_.var.vname, optext,
        ((Q_IRI_REF == prev->sparpv_verb_lexem_type) ? "<" : ""), prev->sparpv_verb_lexem_text,
        ((Q_IRI_REF == prev->sparpv_verb_lexem_type) ? ">" : "") );
      curr_pv = prev;
      break;
    }
  END_DO_SET();
  if (NULL == curr_pv)
    {
      curr_pv = (spar_propvariable_t *) t_alloc (sizeof (spar_propvariable_t));
      curr_pv->sparpv_subj_var = lvar;
      curr_pv->sparpv_op = opcode;
      curr_pv->sparpv_verb_qname = verb_qname;
      curr_pv->sparpv_verb_lexem_type = verb_lexem_type;
      curr_pv->sparpv_verb_lexem_text = verb_lexem_text;
      curr_pv->sparpv_key = new_key;
      /* Composing readable and short name for the generated variable */
      if (lvar_blen + strlen (verb_lexem_text) + ((Q_IRI_REF == verb_lexem_type) ? 2 : 0) < 30)
        {
          curr_pv->sparpv_obj_var_name = t_box_sprintf (40, "%s%s%s%s%s",
            lvar->_.var.vname, optext,
            ((Q_IRI_REF == verb_lexem_type) ? "<" : ""), verb_lexem_text,
            ((Q_IRI_REF == verb_lexem_type) ? ">" : "") );
          curr_pv->sparpv_obj_altered = 0;
        }
      else
        {
          char buf[20];
          sprintf (buf, "!pv!%d", (sparp->sparp_unictr)++);
          if (strlen(buf) + strlen (verb_lexem_text) + ((Q_IRI_REF == verb_lexem_type) ? 2 : 0) < 30)
            curr_pv->sparpv_obj_var_name = t_box_sprintf (40, "%s%s%s%s%s",
              buf, optext,
              ((Q_IRI_REF == verb_lexem_type) ? "<" : ""), verb_lexem_text,
              ((Q_IRI_REF == verb_lexem_type) ? ">" : "") );
          else
            curr_pv->sparpv_obj_var_name = t_box_sprintf (40, "%s%s!%d",
              buf, optext, (sparp->sparp_unictr)++ );
            curr_pv->sparpv_obj_altered = 0x1;
        }
      if (':' == curr_pv->sparpv_obj_var_name[0])
        {
          curr_pv->sparpv_obj_var_name[0] = '!';
          curr_pv->sparpv_obj_altered |= 0x2;
        }
      t_set_push (&(sparp->sparp_propvars), curr_pv);
      goto not_found_in_local_set; /* see below */ /* No need to search because this is the first occurrence at all */
    }
  DO_SET (spar_propvariable_t *, prev, &(sparp->sparp_env->spare_propvar_sets->data))
    {
      if (strcmp (prev->sparpv_key, new_key))
        continue;
      goto in_local_set; /* see below */
    }
  END_DO_SET();

not_found_in_local_set:
  t_set_push ((dk_set_t *)(&(sparp->sparp_env->spare_propvar_sets->data)), (void *)curr_pv);

in_local_set:
  return spar_make_variable (sparp, curr_pv->sparpv_obj_var_name);
}


int
spar_describe_restricted_by_physical (sparp_t *sparp, SPART **retvals)
{
  SPART **sources = sparp->sparp_expr->_.req_top.sources;
  SPART *dflt_s = NULL;
  SPART *triple;
  int s_ctr;
  spar_selid_push_reused (sparp, uname__ref);
  triple = spar_make_plain_triple (sparp,
    spar_make_fake_blank_node (sparp),
    NULL,
    spar_make_fake_blank_node (sparp),
    spar_make_fake_blank_node (sparp),
    (caddr_t)(_STAR), NULL );
  spar_selid_pop (sparp);
  DO_BOX_FAST (SPART *, s, s_ctr, retvals)
    {
      triple_case_t **cases;
      int case_ctr;
      int s_type = SPART_TYPE (s);      
      if (SPAR_ALIAS == s_type)
        {
          s = s->_.alias.arg;
          s_type = SPART_TYPE (s);
        }
      if ((SPAR_VARIABLE == s_type) || (SPAR_BLANK_NODE_LABEL == s_type) || (SPAR_QNAME == s_type) || (SPAR_LIT == s_type))
        triple->_.triple.tr_subject = s;
      else
        {
          if (NULL == dflt_s)
            dflt_s = spar_make_fake_blank_node (sparp);
          triple->_.triple.tr_subject = dflt_s;
        }
      cases = sparp_find_triple_cases (sparp, triple, sources, SPART_GRAPH_FROM);
      DO_BOX_FAST_REV (triple_case_t *, tc, case_ctr, cases)
        {
          ccaddr_t table_name = tc->tc_qm->qmTableName;
          if ((NULL == table_name) || strcmp ("DB.DBA.RDF_QUAD", table_name))
            return 0;
        }
      END_DO_BOX_FAST_REV;
      cases = sparp_find_triple_cases (sparp, triple, sources, SPART_GRAPH_NAMED);
      DO_BOX_FAST_REV (triple_case_t *, tc, case_ctr, cases)
        {
          ccaddr_t table_name = tc->tc_qm->qmTableName;
          if ((NULL == table_name) || strcmp ("DB.DBA.RDF_QUAD", table_name))
            return 0;
        }
      END_DO_BOX_FAST_REV;
    }
  END_DO_BOX_FAST;
  return 1;
}

SPART **
spar_retvals_of_describe (sparp_t *sparp, SPART **retvals, caddr_t limit, caddr_t offset)
{
  int retval_ctr;
  dk_set_t vars = NULL;
  dk_set_t consts = NULL;
  dk_set_t good_graphs = NULL;
  dk_set_t bad_graphs = NULL;
  SPART *descr_call;
  SPART *agg_call;
  SPART *var_vector_expn;
  SPART *var_vector_arg;
  caddr_t limofs_name;
  const char *descr_name;
  int need_limofs_trick = ((SPARP_MAXLIMIT != unbox (limit)) || (0 != unbox (offset)));
/* Making lists of variables, blank nodes, fixed triples, triples with variables and blank nodes. */
  for (retval_ctr = BOX_ELEMENTS_INT (retvals); retval_ctr--; /* no step */)
    {
      SPART *retval = retvals[retval_ctr];
      switch (SPART_TYPE(retval))
        {
          case SPAR_LIT: case SPAR_QNAME: /*case SPAR_QNAME_NS:*/
            t_set_push (&consts, retval);
            break;
          default:
            t_set_push (&vars, retval);
            break;
        }
    }
  DO_SET (SPART *, g, &(sparp->sparp_env->spare_default_graphs))
    {
      t_set_push (((SPART_GRAPH_FROM == g->_.graph.subtype) ? &good_graphs : &bad_graphs), g->_.graph.expn);
    }
  END_DO_SET()
  DO_SET (SPART *, g, &(sparp->sparp_env->spare_named_graphs))
    {
      t_set_push (((SPART_GRAPH_NAMED == g->_.graph.subtype) ? &good_graphs : &bad_graphs), g->_.graph.expn);
    }
  END_DO_SET()
  var_vector_expn = spar_make_funcall (sparp, 0, "LONG::bif:vector",
    (SPART **)t_list_to_array (vars) );
  if (need_limofs_trick)
    {
      limofs_name = t_box_dv_short_string (":\"limofs\".\"describe-1\"");
      var_vector_arg = spar_make_variable (sparp, limofs_name);
    }
  else
    var_vector_arg = var_vector_expn;
  agg_call = spar_make_funcall (sparp, 1, "sql:SPARQL_DESC_AGG",
      (SPART **)t_list (1, var_vector_arg ) );
  if (NULL != sparp->sparp_env->spare_describe_mode)
    {
      int phys_only = spar_describe_restricted_by_physical (sparp, retvals);
      if (phys_only)
        descr_name = t_box_sprintf (100, "sql:SPARQL_DESC_DICT_%.50s_PHYSICAL", sparp->sparp_env->spare_describe_mode);
      else
        descr_name = t_box_sprintf (100, "sql:SPARQL_DESC_DICT_%.50s", sparp->sparp_env->spare_describe_mode);
    }
  else
    descr_name = "sql:SPARQL_DESC_DICT";
  descr_call = spar_make_funcall (sparp, 0, descr_name,
      (SPART **)t_list (6,
        agg_call,
        spar_make_funcall (sparp, 0, "LONG::bif:vector",
          (SPART **)t_list_to_array (consts) ),
        ((sparp->sparp_env->spare_default_graphs_listed || sparp->sparp_env->spare_named_graphs_listed) ?
          ((NULL != good_graphs) ?
            spar_make_funcall (sparp, 0, "LONG::bif:vector",
              (SPART **)t_list_to_array (good_graphs) ) : (SPART *)t_NEW_DB_NULL ) :
          (SPART *)t_box_num_nonull (0) ),
        ((NULL != bad_graphs) ?
          spar_make_funcall (sparp, 0, "LONG::bif:vector",
            (SPART **)t_list_to_array (bad_graphs) ) : (SPART *)t_NEW_DB_NULL ),
        sparp->sparp_env->spare_storage_name,
        spar_make_funcall (sparp, 0, "bif:vector", NULL) ) ); /*!!!TBD describe options will come here */
  if (need_limofs_trick)
    return (SPART **)t_list (2, descr_call,
      spartlist (sparp, 4, SPAR_ALIAS, var_vector_expn, t_box_dv_short_string ("describe-1"), SSG_VALMODE_AUTO) );
  else
    return (SPART **)t_list (1, descr_call);
}

int
sparp_gp_trav_add_rgc_vars_and_consts_from_retvals (sparp_t *sparp, SPART *curr, sparp_trav_state_t *sts_this, void *common_env)
{
  switch (SPART_TYPE (curr))
    {
    case SPAR_VARIABLE:
      if (!(SPART_VARR_GLOBAL & curr->_.var.rvr.rvrRestrictions))
        t_set_push_new_string (&(sparp->sparp_env->spare_grab.rgc_vars), t_box_dv_uname_string (curr->_.var.vname));
      break;
    case SPAR_QNAME:
      t_set_push_new_string (&(sparp->sparp_env->spare_grab.rgc_consts), curr->_.lit.val);
      break;
    }
  return 0;
}

void
spar_add_rgc_vars_and_consts_from_retvals (sparp_t *sparp, SPART **retvals)
{
  int retctr;
  DO_BOX_FAST (SPART *, retval, retctr, retvals)
    {
      sparp_gp_trav (sparp, retval, NULL,
        NULL, NULL,
        sparp_gp_trav_add_rgc_vars_and_consts_from_retvals, NULL, NULL,
        sparp_gp_trav_add_rgc_vars_and_consts_from_retvals );
    }
  END_DO_BOX_FAST;
}

SPART *spar_make_top (sparp_t *sparp, ptrlong subtype, SPART **retvals,
  caddr_t retselid, SPART *pattern, SPART **groupings, SPART **order, caddr_t limit, caddr_t offset)
{
  dk_set_t src = NULL;
  sparp_env_t *env = sparp->sparp_env;
  SPART **sources;
  caddr_t final_output_format_name;
  DO_SET(SPART *, g, &(env->spare_default_graphs))
    {
      t_set_push (&src, sparp_tree_full_copy (sparp, g, NULL));
    }
  END_DO_SET()
  DO_SET(SPART *, g, &(env->spare_named_graphs))
    {
      t_set_push (&src, sparp_tree_full_copy (sparp, g, NULL));
    }
  END_DO_SET()
  sources = (SPART **)t_revlist_to_array (src);
  if ((0 == BOX_ELEMENTS (sources)) &&
    (NULL != (env->spare_common_sponge_options)) )
    spar_error (sparp, "Retrieval options for source graphs (e.g., '%s') may be useless if the query does not contain 'FROM' or 'FROM NAMED'", env->spare_common_sponge_options->data);
  switch (subtype)
    {
    case CONSTRUCT_L: case DESCRIBE_L:
      final_output_format_name = ((NULL != env->spare_output_dict_format_name) ? env->spare_output_dict_format_name : env->spare_output_format_name);
      break;
    case ASK_L:
      final_output_format_name = ((NULL != env->spare_output_scalar_format_name) ? env->spare_output_scalar_format_name : env->spare_output_format_name);
      break;
    default:
      final_output_format_name = env->spare_output_format_name;
      break;
    }
  return spartlist (sparp, 16, SPAR_REQ_TOP, subtype,
    env->spare_output_valmode_name,
    final_output_format_name,
    t_box_copy (env->spare_storage_name),
    retvals, NULL /* orig_retvals */, NULL /* expanded_orig_retvals */, retselid,
    sources, pattern, groupings, order,
    limit, offset, env );
}

void
spar_gp_add_transitive_triple (sparp_t *sparp, SPART *graph, SPART *subject, SPART *predicate, SPART *object, caddr_t qm_iri, SPART **options)
{
#ifdef DEBUG
  sparp_env_t *saved_env = sparp->sparp_env;
  dk_set_t selid_stack = sparp->sparp_env->spare_selids;
  dk_set_t filters_stack = sparp->sparp_env->spare_acc_filters;
  dk_set_t members_stack = sparp->sparp_env->spare_acc_req_triples;
#endif
  SPART *subselect_top, *where_gp, *wrapper_gp, *fields[4];
  SPART *subj_var, *obj_var, **retvals;
  caddr_t subj_vname, obj_vname, retval_selid, gp_selid;
  int subj_is_plain_var, obj_is_plain_var, retvalctr, fld_ctr;
  int subj_stype = SPART_TYPE (subject);
  int obj_stype = SPART_TYPE (object);
  if ((SPAR_VARIABLE != subj_stype) && (SPAR_QNAME != subj_stype))
    spar_error (sparp, "Subject of transitive triple pattern should be variable or QName, not literal or blank node");
  if ((SPAR_VARIABLE != obj_stype) && (SPAR_QNAME != obj_stype) && (SPAR_LIT != obj_stype))
    spar_error (sparp, "Object of transitive triple pattern should be variable or QName or literal, not blank node");
  subj_is_plain_var = ((SPAR_VARIABLE == subj_stype) && (NULL == strchr (subject->_.var.vname, '>')));
  obj_is_plain_var = ((SPAR_VARIABLE == obj_stype) && (NULL == strchr (object->_.var.vname, '>')));
  subj_vname = (subj_is_plain_var ? subject->_.var.vname :
    t_box_sprintf (40, "trans-subj-%.20s", (caddr_t)(sparp->sparp_env->spare_selids->data)) );
  obj_vname = (obj_is_plain_var ? object->_.var.vname :
    t_box_sprintf (40, "trans-obj-%.20s", (caddr_t)(sparp->sparp_env->spare_selids->data)) );
  spar_gp_init (sparp, 0);
  spar_env_push (sparp);
  spar_selid_push (sparp);
  fields[0] = graph;
  fields[1] = spar_make_variable (sparp, subj_vname);
  fields[2] = predicate;
  fields[3] = spar_make_variable (sparp, obj_vname);
  retvalctr = 0;
  for (fld_ctr = 0; fld_ctr < 4; fld_ctr++)
    {
      if (SPAR_IS_BLANK_OR_VAR (fields[fld_ctr]))
        retvalctr++;
    }
  if (0 == retvalctr)
    retvalctr = 1;
  retvals = (SPART **)t_alloc_box (retvalctr * sizeof (SPART *), DV_ARRAY_OF_POINTER);
  retval_selid = (caddr_t)(sparp->sparp_env->spare_selids->data);
  retvalctr = 0;
  for (fld_ctr = 0; fld_ctr < 4; fld_ctr++)
    {
      switch (SPART_TYPE (fields[fld_ctr]))
        {
        case SPAR_BLANK_NODE_LABEL: retvals[retvalctr++] = spar_make_blank_node (sparp, fields[fld_ctr]->_.var.vname, 0); break;
        case SPAR_VARIABLE: retvals[retvalctr++] = spar_make_variable (sparp, fields[fld_ctr]->_.var.vname); break;
        }
    }
  if (0 == retvalctr)
    retvals[0] = (SPART *)t_box_num_nonull (1);
  t_set_push (&(sparp->sparp_env->spare_propvar_sets), NULL);
  spar_gp_init (sparp, WHERE_L);
  gp_selid = (caddr_t)(sparp->sparp_env->spare_selids->data);
  subj_var = spar_make_variable (sparp, subj_vname);
  obj_var = spar_make_variable (sparp, obj_vname);
  for (fld_ctr = 0; fld_ctr < 4; fld_ctr++)
    {
      if (SPAR_IS_BLANK_OR_VAR (fields[fld_ctr]))
        fields[fld_ctr]->_.var.selid = gp_selid;
    }
  spar_gp_add_triple_or_special_filter (sparp, graph, subj_var, predicate, obj_var, qm_iri, NULL);
  sparp_set_option (sparp, &options, T_IN_L,
    spartlist (sparp, 2, SPAR_LIST, t_list (1, spar_make_variable (sparp, subj_vname))),
    SPARP_SET_OPTION_REPLACING );
  sparp_set_option (sparp, &options, T_OUT_L,
    spartlist (sparp, 2, SPAR_LIST, t_list (1, spar_make_variable (sparp, obj_vname))),
    SPARP_SET_OPTION_REPLACING );
  where_gp = spar_gp_finalize (sparp, NULL); 
  subselect_top = spar_make_top (sparp, SELECT_L, retvals, 
    spar_selid_pop (sparp), where_gp, 
    (SPART **)NULL, (SPART **)NULL, t_box_num (SPARP_MAXLIMIT), t_box_num_nonull (0));
  sparp_expand_top_retvals (sparp, subselect_top, 1 /* safely_copy_all_vars */);
  spar_env_pop (sparp);
  t_check_tree (options);
  wrapper_gp = spar_gp_finalize_with_subquery (sparp, options, subselect_top);
  spar_gp_add_member (sparp, wrapper_gp);
  if (!subj_is_plain_var)
    {
      SPART *eq = spartlist (sparp, 3, BOP_EQ, spar_make_variable (sparp, subj_vname), subject);
      spar_gp_add_filter (sparp, eq);
    }
  if (!obj_is_plain_var)
    {
      SPART *eq = spartlist (sparp, 3, BOP_EQ, spar_make_variable (sparp, obj_vname), object);
      spar_gp_add_filter (sparp, eq);
    }
#ifdef DEBUG
  if (saved_env != sparp->sparp_env)
    spar_internal_error (sparp, "spar_" "gp_add_transitive_triple(): mismatch in env");
  if (selid_stack != sparp->sparp_env->spare_selids)
    spar_internal_error (sparp, "spar_" "gp_add_transitive_triple(): mismatch in selid");
  if (filters_stack != sparp->sparp_env->spare_acc_filters)
    spar_internal_error (sparp, "spar_" "gp_add_transitive_triple(): mismatch in filters");
  if (members_stack != sparp->sparp_env->spare_acc_req_triples)
    spar_internal_error (sparp, "spar_" "gp_add_transitive_triple(): mismatch in req_triples");
#endif
}

static ptrlong usage_natural_restrictions[SPART_TRIPLE_FIELDS_COUNT] = {
  SPART_VARR_IS_REF | SPART_VARR_IS_IRI | SPART_VARR_NOT_NULL,	/* graph	*/
  SPART_VARR_IS_REF | SPART_VARR_NOT_NULL,			/* subject	*/
  SPART_VARR_IS_REF | SPART_VARR_NOT_NULL,			/* predicate	*/
  SPART_VARR_NOT_NULL };					/* object	*/

void
spar_gp_add_triple_or_special_filter (sparp_t *sparp, SPART *graph, SPART *subject, SPART *predicate, SPART *object, caddr_t qm_iri, SPART **options)
{
  sparp_env_t *env = sparp->sparp_env;
  SPART *triple;
  if (NULL == subject)
    subject = (SPART *)t_box_copy_tree (env->spare_context_subjects->data);
  if (NULL == predicate)
    predicate = (SPART *)t_box_copy_tree (env->spare_context_predicates->data);
  if (NULL == object)
    object = (SPART *)t_box_copy_tree (env->spare_context_objects->data);
  for (;;)
    {
      SPART *ctx_qm;
      if (NULL != qm_iri)
        break;
      if (NULL == env->spare_context_qms)
        {
          qm_iri = (caddr_t)(_STAR);
          break;
        }
      ctx_qm = env->spare_context_qms->data;
      if (DV_ARRAY_OF_POINTER == DV_TYPE_OF (ctx_qm))
        {
          qm_iri = ctx_qm->_.lit.val;
          break;
        }
      ctx_qm = (SPART *)qm_iri;
      break;
    }
  if (NULL != options)
    {
      SPART *trans = sparp_get_option (sparp, options, TRANSITIVE_L);
      if (NULL != trans)
        {
          spar_gp_add_transitive_triple (sparp, graph, subject, predicate, object, qm_iri, options);
          return;
        }
    }
  if (SPAR_QNAME == SPART_TYPE (predicate))
    {
      caddr_t *spec_pred_names = jso_triple_get_objs (
        (caddr_t *)(sparp->sparp_sparqre->sparqre_qi),
        predicate->_.lit.val,
        uname_virtrdf_ns_uri_isSpecialPredicate );
      if (0 != BOX_ELEMENTS (spec_pred_names))
        {
          if (NULL != options)
            {
              int ctr;
              sparp_validate_options_of_tree (sparp, NULL /*no tree*/, options);
              for (ctr = BOX_ELEMENTS (options) - 2; ctr >= 0; ctr -= 2)
                {
                  SPART *option_value = options[ctr+1];
                  if (SPAR_VARIABLE != SPART_TYPE (option_value))
                    continue;
                  option_value->_.var.rvr.rvrRestrictions |= SPART_VARR_IS_LIT;
                }
            }
          spar_gp_add_filter (sparp,
            spar_make_funcall (sparp, 0, spec_pred_names[0],
              (SPART **)t_list_concat ((caddr_t)t_list (2, subject, object), (caddr_t)options) ) );
	  dk_free_tree (spec_pred_names);
          return;
        }
      dk_free_tree (spec_pred_names);
    }
  for (;;)
    {
      dk_set_t dflts;
      if (NULL != graph)
        break;
      if (env->spare_context_graphs)
        {
          graph = (SPART *)t_box_copy_tree (env->spare_context_graphs->data);
          break;
        }
      dflts = env->spare_default_graphs;
      if ((NULL == dflts) && (NULL != env->spare_named_graphs))
        { /* Special case: if no FROM clauses specified but there are some FROM NAMED then default graph is totally empty */
          graph = spar_make_blank_node (sparp, spar_mkid (sparp, "_::default"), 1);
          graph->_.var.rvr.rvrRestrictions |= SPART_VARR_CONFLICT;
          break;
        }
      if ((NULL != dflts) && (SPART_GRAPH_FROM == ((SPART *)(dflts->data))->_.graph.subtype) && 
         ((NULL == dflts->next) || (SPART_GRAPH_FROM != ((SPART *)(dflts->next->data))->_.graph.subtype)) )
        { /* If there's only one default graph then we can cheat and optimize the query a little bit by adding a restriction to the variable */
          SPART *single_dflt = (SPART *)(dflts->data);
          if (!SPAR_IS_LIT_OR_QNAME (single_dflt->_.graph.expn))	 /* FROM iriref OPTION (...) case */
            {
              caddr_t iri_arg = single_dflt->_.graph.iri;
              SPART *eq;
              graph = spar_make_blank_node (sparp, spar_mkid (sparp, "_::default"), 1);
              eq = spartlist (sparp, 3, BOP_EQ, sparp_tree_full_copy (sparp, graph, NULL), sparp_tree_full_copy (sparp, single_dflt->_.graph.expn, NULL));
              spar_gp_add_filter (sparp, eq);
              graph->_.var.rvr.rvrRestrictions |= SPART_VARR_FIXED | SPART_VARR_IS_REF | SPART_VARR_NOT_NULL;
              graph->_.var.rvr.rvrFixedValue = t_box_copy (iri_arg);
              break;
            }
	/* Single FROM iriref without sponge options */
          graph = sparp_tree_full_copy (sparp, single_dflt->_.graph.expn, NULL);
          break;
	}
      graph = spar_make_blank_node (sparp, spar_mkid (sparp, "_::default"), 1);
      spar_gp_add_filters_for_graph (sparp, graph, dflts, 0);
      break;
    }
  if (SPAR_IS_BLANK_OR_VAR (graph))
    graph->_.var.selid = env->spare_selids->data;
  triple = spar_make_plain_triple (sparp, graph, subject, predicate, object, qm_iri, options);
  if (NULL != options)
    sparp_validate_options_of_tree (sparp, triple, options);
  spar_gp_add_member (sparp, triple);
}

SPART *
spar_make_plain_triple (sparp_t *sparp, SPART *graph, SPART *subject, SPART *predicate, SPART *object, caddr_t qm_iri, SPART **options)
{
  sparp_env_t *env = sparp->sparp_env;
  caddr_t key;
  int fctr;
  SPART *triple;
  key = t_box_sprintf (0x100, "%s-t%d", env->spare_selids->data, sparp->sparp_key_gen);
  sparp->sparp_key_gen += 1;
  triple = spartlist (sparp, 17, SPAR_TRIPLE,
    (ptrlong)0,
    graph, subject, predicate, object, qm_iri,
    env->spare_selids->data, key, NULL,
    NULL, NULL, NULL, NULL,
    options, (ptrlong)0, (ptrlong)((sparp->sparp_unictr)++) );
  for (fctr = 0; fctr < SPART_TRIPLE_FIELDS_COUNT; fctr++)
    {
      SPART *fld = triple->_.triple.tr_fields[fctr];
      ptrlong ft = SPART_TYPE(fld);
      if ((SPAR_VARIABLE == ft) || (SPAR_BLANK_NODE_LABEL == ft))
        {
          fld->_.var.rvr.rvrRestrictions |= usage_natural_restrictions[fctr];
          fld->_.var.tabid = key;
          fld->_.var.tr_idx = fctr;
          if (!(SPART_VARR_GLOBAL & fld->_.var.rvr.rvrRestrictions))
            t_set_push_new_string (&(env->spare_good_graph_varnames), fld->_.var.vname);
        }
      if ((env->spare_grab.rgc_all) && (SPART_TRIPLE_PREDICATE_IDX != fctr))
        {
          if ((SPAR_VARIABLE == ft) && !(SPART_VARR_GLOBAL & fld->_.var.rvr.rvrRestrictions))
            t_set_push_new_string (&(env->spare_grab.rgc_vars), t_box_dv_uname_string (fld->_.var.vname));
          else if (SPAR_QNAME == ft)
            t_set_push_new_string (&(env->spare_grab.rgc_consts), fld->_.lit.val);
        }
      if ((NULL != env->spare_grab.rgc_sa_preds) &&
        (SPART_TRIPLE_SUBJECT_IDX == fctr) &&
        (SPAR_VARIABLE == ft) &&
        !(env->spare_grab.rgc_all) )
        {
          SPART *obj = triple->_.triple.tr_object;
          ptrlong objt = SPART_TYPE(obj);
          if (
            ((SPAR_VARIABLE == objt) &&
              (0 <= dk_set_position_of_string (env->spare_grab.rgc_vars, obj->_.var.vname)) ) ||
            ((SPAR_QNAME == objt) &&
              (0 <= dk_set_position_of_string (env->spare_grab.rgc_consts, obj->_.lit.val)) ) )
            {
              t_set_push_new_string (&(env->spare_grab.rgc_sa_vars), t_box_dv_uname_string (fld->_.var.vname));
            }
        }
    }
  return triple;
}

SPART *
spar_make_param_or_variable (sparp_t *sparp, caddr_t name)
{
  if (0 <= dk_set_position_of_string (sparp->sparp_env->spare_protocol_params, name))
    {
      caddr_t intname = t_box_sprintf (110, "::%.100s", name);
      return spar_make_variable (sparp, intname);
    }
  return spar_make_variable (sparp, name);
}

SPART *
spar_make_variable (sparp_t *sparp, caddr_t name)
{
  sparp_env_t *env = sparp->sparp_env;
  SPART *res;
  int is_global = SPART_VARNAME_IS_GLOB(name);
  caddr_t selid = NULL;
#ifdef DEBUG
  caddr_t rvr_list_test[] = {SPART_RVR_LIST_OF_NULLS};
  if (sizeof (rvr_list_test) != sizeof (rdf_val_range_t))
    GPF_T; /* Don't forget to add NULLS to SPART_RVR_LIST_OF_NULLS when adding fields to rdf_val_range_t */
#endif
  if (is_global)
    {
      t_set_push_new_string (&(sparp->sparp_env->spare_global_var_names), name);
    }
  if (sparp->sparp_in_precode_expn && !is_global)
    spar_error (sparp, "non-global variable '%.100s' can not be used outside any group pattern or result-set list");
  if (NULL != env->spare_selids)
    selid = env->spare_selids->data;
  else if (is_global) /* say, 'insert in graph ?:someglobalvariable {...} where {...} */
    selid = t_box_dv_uname_string ("(global)");
  else
    spar_internal_error (sparp, "non-global variable outside any group pattern or result-set list");
  res = spartlist (sparp, 6 + (sizeof (rdf_val_range_t) / sizeof (caddr_t)),
      SPAR_VARIABLE, name,
      selid, NULL,
      (ptrlong)(0), SPART_BAD_EQUIV_IDX, SPART_RVR_LIST_OF_NULLS );
  res->_.var.rvr.rvrRestrictions = (is_global ? SPART_VARR_GLOBAL : 0);
  return res;
}

SPART *spar_make_blank_node (sparp_t *sparp, caddr_t name, int bracketed)
{
  sparp_env_t *env = sparp->sparp_env;
  SPART *res;
  res = spartlist (sparp, 6 + (sizeof (rdf_val_range_t) / sizeof (caddr_t)),
      SPAR_BLANK_NODE_LABEL, name,
      env->spare_selids->data, NULL,
      (ptrlong)(bracketed), SPART_BAD_EQUIV_IDX, SPART_RVR_LIST_OF_NULLS );
  res->_.var.rvr.rvrRestrictions = /*SPART_VARR_IS_REF | SPART_VARR_IS_BLANK |*/ SPART_VARR_NOT_NULL;
  return res;
}

SPART *spar_make_fake_blank_node (sparp_t *sparp)
{
  SPART *res;
  res = spartlist (sparp, 6 + (sizeof (rdf_val_range_t) / sizeof (caddr_t)),
      SPAR_BLANK_NODE_LABEL, uname__ref,
      uname__ref, NULL,
      (ptrlong)(0), SPART_BAD_EQUIV_IDX, SPART_RVR_LIST_OF_NULLS );
  res->_.var.rvr.rvrRestrictions = /*SPART_VARR_IS_REF | SPART_VARR_IS_BLANK |*/ SPART_VARR_NOT_NULL;
  return res;
}

SPART *spar_make_typed_literal (sparp_t *sparp, caddr_t strg, caddr_t type, caddr_t lang)
{
  dtp_t tgt_dtp;
  caddr_t parsed_value = NULL;
  sql_tree_tmp *tgt_dtp_tree;  
  SPART *res;
  if (NULL != lang)
    return spartlist (sparp, 4, SPAR_LIT, strg, type, lang);
  if (uname_xmlschema_ns_uri_hash_boolean == type)
    {
      if (!strcmp ("true", strg))
        return spartlist (sparp, 4, SPAR_LIT, (ptrlong)1, type, NULL);
      if (!strcmp ("false", strg))
        return spartlist (sparp, 4, SPAR_LIT, (ptrlong)0, type, NULL);
      goto cannot_cast;
    }
  if (uname_xmlschema_ns_uri_hash_date == type)
    {
      tgt_dtp = DV_DATE;
      goto do_sql_cast;
    }
  if (uname_xmlschema_ns_uri_hash_dateTime == type)
    {
      tgt_dtp = DV_DATETIME;
      goto do_sql_cast;
    }
  if (uname_xmlschema_ns_uri_hash_decimal == type)
    {
      tgt_dtp = DV_NUMERIC;
      goto do_sql_cast;
    }
  if (uname_xmlschema_ns_uri_hash_double == type)
    {
      tgt_dtp = DV_DOUBLE_FLOAT;
      goto do_sql_cast;
    }
  if (uname_xmlschema_ns_uri_hash_float == type)
    {
      tgt_dtp = DV_SINGLE_FLOAT;
      goto do_sql_cast;
    }
  if (uname_xmlschema_ns_uri_hash_integer == type)
    {
      tgt_dtp = DV_LONG_INT;
      goto do_sql_cast;
    }
  if (uname_xmlschema_ns_uri_hash_time == type)
    {
      tgt_dtp = DV_TIME;
      goto do_sql_cast;
    }
  if (uname_xmlschema_ns_uri_hash_string == type)
    {
      return spartlist (sparp, 4, SPAR_LIT, strg, type, NULL);
    }
  return spartlist (sparp, 4, SPAR_LIT, strg, type, NULL);

do_sql_cast:
  tgt_dtp_tree = (sql_tree_tmp *)t_list (3, (ptrlong)tgt_dtp, (ptrlong)NUMERIC_MAX_PRECISION, (ptrlong)NUMERIC_MAX_SCALE);
  parsed_value = box_cast ((caddr_t *)(sparp->sparp_sparqre->sparqre_qi), strg, tgt_dtp_tree, DV_STRING);
  res = spartlist (sparp, 4, SPAR_LIT, t_full_box_copy_tree (parsed_value), type, NULL);
  dk_free_tree (parsed_value);
  return res;

cannot_cast:
  sparyyerror_impl (sparp, strg, "The string representation can not be converted to a valid typed value");
  return NULL;
}

void
sparp_push_new_graph_source (sparp_t *sparp, dk_set_t *set_ptr, SPART *src)
{
  DO_SET (SPART *, c, set_ptr)
    {
      if (strcmp (c->_.graph.iri, src->_.graph.iri))
        continue;
      if (c->_.graph.subtype > src->_.graph.subtype)
        return; /* A (failed) attempt to overwrite NOT FROM with FROM */
      if ((c->_.graph.subtype == src->_.graph.subtype) && (SPAR_QNAME != SPART_TYPE (c->_.graph.expn)))
        t_set_delete (set_ptr, c);
      break;
    }
  END_DO_SET()
  if ((SPART_GRAPH_NOT_FROM == src->_.graph.subtype) ||
    (SPART_GRAPH_NOT_NAMED == src->_.graph.subtype) )
    {
      dk_set_t tmp = NULL;
      t_set_push (&tmp, src);
      set_ptr[0] = t_NCONC (set_ptr[0], tmp);
    }
  else
    t_set_push (set_ptr, src);
}

SPART *
sparp_make_graph_precode (sparp_t *sparp, ptrlong subtype, SPART *iriref, SPART **options)
{
  rdf_grab_config_t *rgc_ptr = &(sparp->sparp_env->spare_grab);
  dk_set_t *opts_ptr = &(sparp->sparp_env->spare_common_sponge_options);
  SPART **mixed_options, **mixed_tail;
  int common_count, ctr;
  user_t *exec_user;
  if (NULL != rgc_ptr->rgc_sa_preds)
    {
      t_set_push_new_string (&(rgc_ptr->rgc_sa_graphs),
        ((DV_ARRAY_OF_POINTER == DV_TYPE_OF (iriref)) ? iriref->_.lit.val : (caddr_t)iriref) );
    }
  if ((NULL == options) && (0 > dk_set_position_of_string (opts_ptr[0], "get:soft")))
    return spartlist (sparp, 4, SPAR_GRAPH, subtype, iriref->_.qname.val, iriref);
  common_count = dk_set_length (opts_ptr[0]);
  mixed_tail = mixed_options = (SPART **)t_alloc_box ((common_count + 2 + BOX_ELEMENTS_0 (options)) * sizeof (SPART *), DV_ARRAY_OF_POINTER);
  DO_SET (SPART *, val, opts_ptr)
    {
      (mixed_tail++)[0] = (SPART *)t_full_box_copy_tree ((caddr_t)(val));
    }
  END_DO_SET()
  for (ctr = BOX_ELEMENTS_0 (options) - 1; 0 <= ctr; ctr -= 2)
    {
      caddr_t param = (caddr_t)(options[ctr]);
      const char **chk;
      for (chk = sparp_known_get_params; (NULL != chk[0]) && strcmp (chk[0], param); chk++) ;
      if (NULL == chk[0])
        spar_error (sparp, "Unsupported parameter '%.30s' in FROM ... (OPTION ...)", param);
      if (0 < dk_set_position_of_string (opts_ptr[0], param))
        spar_error (sparp, "FROM ... (OPTION ... %s ...) conflicts with 'DEFINE %s ...", param, param);
      (mixed_tail++)[0] = (SPART *)t_full_box_copy_tree (param);
      (mixed_tail++)[0] = (SPART *)t_full_box_copy_tree ((caddr_t)(options[ctr + 1]));
    }
  if (!IS_BOX_POINTER (sparp->sparp_env->spare_sql_refresh_free_text))
    sparp->sparp_env->spare_sql_refresh_free_text = t_box_num_and_zero (0);
  (mixed_tail++)[0] = (SPART *) t_box_dv_short_string ("refresh_free_text");
  (mixed_tail++)[0] = (SPART *) sparp->sparp_env->spare_sql_refresh_free_text;
  exec_user = sparp->sparp_sparqre->sparqre_exec_user;
  return spartlist (sparp, 4, SPAR_GRAPH, subtype, iriref->_.qname.val, 
    spar_make_funcall (sparp, 0, "SPECIAL::bif:iri_to_id",
      (SPART **)t_list (1,
        spar_make_funcall (sparp, 0, "sql:RDF_SPONGE_UP",
          (SPART **)t_list (3,
             iriref,
             spar_make_funcall (sparp, 0, "bif:vector", mixed_options),
             ((NULL != exec_user) ? exec_user->usr_id : U_ID_NOBODY) ) ) ) ) );
}

SPART *
spar_make_regex_or_like_or_eq (sparp_t *sparp, SPART *strg, SPART *regexpn)
{
  caddr_t val, like_tmpl;
  char *tail;
  int ctr, val_len, final_len, start_is_fixed, end_is_fixed;
  if (SPAR_LIT != SPART_TYPE (regexpn))
    goto bad_regex; /* see below */
  val = SPAR_LIT_VAL (regexpn);
  if (DV_STRING != DV_TYPE_OF (val))
    goto bad_regex; /* see below */
  val_len = box_length (val)-1;
  final_len = val_len + 2;
  start_is_fixed = 0;
  end_is_fixed = 0;
  if ('^' == val[0])
    {
      final_len -= 2;
      start_is_fixed = 1;
    }
  for (ctr = start_is_fixed; ctr < val_len; ctr++)
    {
      if (NULL == strchr ("%_.+*?\\[($", val[ctr]))
        continue;
      if (('$' == val[ctr]) && (ctr == val_len-1) && ((0 == ctr) || ('\\' != val[ctr-1])))
        {
          final_len -= 2;
          end_is_fixed = 1;
          break;
        }
      goto bad_regex; /* see below */
    }
  if (start_is_fixed && end_is_fixed)
    return spartlist (sparp, 3, BOP_EQ, strg, 
      spartlist (sparp, 4, SPAR_LIT, t_box_dv_short_nchars (val+1, final_len), NULL, NULL) );
  like_tmpl = t_alloc_box (final_len + 1, DV_STRING);
  tail = like_tmpl;
  if (!start_is_fixed)
    (tail++)[0] = '%';
  memcpy (tail, val + start_is_fixed, val_len - (start_is_fixed + end_is_fixed));
  tail += val_len - (start_is_fixed + end_is_fixed);
  if (!end_is_fixed)
    (tail++)[0] = '%';
  tail[0] = '\0';
/*#ifndef NDEBUG*/
  if (tail != like_tmpl + final_len)
    GPF_T1 ("spar_" "make_regex_or_like_or_eq (): pointer arithmetic error on like_tmpl");
/*#endif*/
  return spartlist (sparp, 3, SPAR_BUILT_IN_CALL, (ptrlong)LIKE_L,
    t_list (2, strg, 
      spartlist (sparp, 4, SPAR_LIT, like_tmpl, NULL, NULL) ) );

bad_regex:
 return spartlist (sparp, 3, SPAR_BUILT_IN_CALL, (ptrlong)REGEX_L, t_list (2, strg, regexpn));
}

SPART *
spar_make_funcall (sparp_t *sparp, int aggregate_mode, const char *funname, SPART **args)
{
  const char *sql_colon;
  caddr_t proc_full_name;
  query_t *proc;
  if (NULL == args)
    args = (SPART **)t_list (0);
  if (0 != aggregate_mode)
    goto aggr_checked; /* see below */
  sql_colon = strstr (funname, "sql:");
  if (NULL == sql_colon)
    goto aggr_checked; /* see below */
  if ((funname != sql_colon) && ((funname >= (sql_colon-2)) || (':' != sql_colon[-1]) || (':' != sql_colon[-2])))
    goto aggr_checked; /* see below */
  proc_full_name = t_box_sprintf (MAX_NAME_LEN + 10, "DB.DBA.%s", sql_colon+4);
  if (CM_UPPER == case_mode)
    sqlp_upcase (proc_full_name);
  proc = sch_proc_def (isp_schema (sparp->sparp_sparqre->sparqre_qi->qi_space), proc_full_name);
  if ((NULL == proc) || (NULL == proc->qr_aggregate))
    goto aggr_checked; /* see below */
  aggregate_mode = 1;
  if (sparp->sparp_in_precode_expn)
    spar_error (sparp, "Aggregate function %.100s() is not allowed in 'precode' expressions that should be calculated before the result-set of the query", funname);
  if (!sparp->sparp_allow_aggregates_in_expn)
    spar_error (sparp, "Aggregate function %.100s() is not allowed outside result-set expressions", funname);
aggr_checked:
  if (aggregate_mode)
    sparp->sparp_query_uses_aggregates++;
  return spartlist (sparp, 4, SPAR_FUNCALL, t_box_dv_short_string (funname), args, (ptrlong)aggregate_mode);
}

SPART *
spar_make_sparul_mdw (sparp_t *sparp, ptrlong subtype, const char *opname, SPART *graph_precode, SPART *aux_op)
{
  SPART **fake_sol;
  SPART *call, *top;
  caddr_t log_mode = sparp->sparp_env->spare_sparul_log_mode;
  spar_selid_push (sparp);
  fake_sol = spar_make_fake_action_solution (sparp);
  if (NULL != sparp->sparp_env->spare_output_route_name)
    call = spar_make_funcall (sparp, 0,
      t_box_sprintf (200, "sql:SPARQL_ROUTE_MDW_%.100s", sparp->sparp_env->spare_output_route_name),
      (SPART **)t_list (11, graph_precode,
          t_box_dv_short_string (opname),
          ((NULL == sparp->sparp_env->spare_storage_name) ? t_NEW_DB_NULL : sparp->sparp_env->spare_storage_name),
          ((NULL == sparp->sparp_env->spare_output_storage_name) ? t_NEW_DB_NULL : sparp->sparp_env->spare_output_storage_name),
          ((NULL == sparp->sparp_env->spare_output_format_name) ? t_NEW_DB_NULL : sparp->sparp_env->spare_output_format_name),
          aux_op,
          t_NEW_DB_NULL,
          t_NEW_DB_NULL,
          spar_boxed_exec_uid (sparp), log_mode, spar_compose_report_flag (sparp)) );
  else
    call = spar_make_funcall (sparp, 0, t_box_sprintf (30, "sql:SPARUL_%.15s", opname),
      (SPART **)t_list (4, graph_precode, spar_boxed_exec_uid (sparp), aux_op, spar_compose_report_flag (sparp)) );
  top = spar_make_top (sparp, subtype,
    (SPART **)t_list (1, call),
    spar_selid_pop (sparp),
    fake_sol[0], (SPART **)(fake_sol[1]), (SPART **)(fake_sol[2]), (caddr_t)(fake_sol[3]), (caddr_t)(fake_sol[4]) );
  return top;
}

SPART *
spar_make_sparul_clear (sparp_t *sparp, SPART *graph_precode)
{
  return spar_make_sparul_mdw (sparp, CLEAR_L, "CLEAR", graph_precode, (SPART *)t_box_num_nonull (0) /* i.e. not inside sponge */);
}

SPART *
spar_make_sparul_load (sparp_t *sparp, SPART *graph_precode, SPART *src_precode)
{
  return spar_make_sparul_mdw (sparp, LOAD_L, "LOAD", graph_precode, src_precode);
}

SPART *
spar_make_sparul_create (sparp_t *sparp, SPART *graph_precode, int silent)
{
  return spar_make_sparul_mdw (sparp, CREATE_L, "CREATE", graph_precode, (SPART *)t_box_num_nonull (silent));
}

SPART *
spar_make_sparul_drop (sparp_t *sparp, SPART *graph_precode, int silent)
{
  return spar_make_sparul_mdw (sparp, DROP_L, "DROP", graph_precode, (SPART *)t_box_num_nonull (silent));
}

SPART *
spar_make_topmost_sparul_sql (sparp_t *sparp, SPART **actions)
{
  caddr_t saved_format_name = sparp->sparp_env->spare_output_format_name;
  caddr_t saved_valmode_name = sparp->sparp_env->spare_output_valmode_name;
  SPART **fake_sol;
  SPART *top;
  SPART **action_sqls;
  int action_ctr, action_count = BOX_ELEMENTS (actions);
  if ((1 == action_count) && (spar_compose_report_flag (sparp)))
    return actions[0]; /* No need to make grouping around single action. */
/* First of all, every tree for every action is compiled into string literal containing SQL text. */
  action_sqls = (SPART **)t_alloc_box (action_count * sizeof (SPART *), DV_ARRAY_OF_POINTER);
  sparp->sparp_env->spare_output_format_name = NULL;
  sparp->sparp_env->spare_output_valmode_name = NULL;
  if (NULL != sparp->sparp_expr)
    spar_internal_error (sparp, "spar_" "make_topmost_sparul_sql() is called after start of some tree rewrite");
  DO_BOX_FAST (SPART *, action, action_ctr, actions)
    {
      spar_sqlgen_t ssg;
      sql_comp_t sc;
      caddr_t action_sql;
      sparp->sparp_expr = action;
      sparp_rewrite_all (sparp, 0 /* no cloning -- no need in safely_copy_retvals */);
  /*xt_check (sparp, sparp->sparp_expr);*/
#ifndef NDEBUG
      t_check_tree (sparp->sparp_expr);
#endif
      memset (&ssg, 0, sizeof (spar_sqlgen_t));
      memset (&sc, 0, sizeof (sql_comp_t));
      if (CALLER_LOCAL != sparp->sparp_sparqre->sparqre_qi)
        sc.sc_client = sparp->sparp_sparqre->sparqre_qi->qi_client;
      ssg.ssg_out = strses_allocate ();
      ssg.ssg_sc = &sc;
      ssg.ssg_sparp = sparp;
      ssg.ssg_tree = sparp->sparp_expr;
      ssg.ssg_sources = ssg.ssg_tree->_.req_top.sources; /*!!!TBD merge with environment */
      ssg_make_sql_query_text (&ssg);
      action_sql = strses_string (ssg.ssg_out);
      strses_free (ssg.ssg_out);
      action_sqls [action_ctr] = spartlist (sparp, 4, SPAR_LIT, action_sql, NULL, NULL);
      sparp->sparp_expr = NULL;
    }
  END_DO_BOX_FAST;
  sparp->sparp_env->spare_output_format_name = saved_format_name;
  sparp->sparp_env->spare_output_valmode_name = saved_valmode_name;
  spar_selid_push (sparp);
  fake_sol = spar_make_fake_action_solution (sparp);
  top = spar_make_top (sparp, SPARUL_RUN_SUBTYPE,
    (SPART **)t_list (1, spar_make_funcall (sparp, 0, "sql:SPARUL_RUN", action_sqls)),
    spar_selid_pop (sparp),
    fake_sol[0], (SPART **)(fake_sol[1]), (SPART **)(fake_sol[2]), (caddr_t)(fake_sol[3]), (caddr_t)(fake_sol[4]) );
  return top;
}


SPART **
spar_make_fake_action_solution (sparp_t *sparp)
{
  SPART * fake_gp;
  spar_gp_init (sparp, WHERE_L);
  fake_gp = spar_gp_finalize (sparp, NULL);
  return (SPART **)t_list (5,
    fake_gp, NULL, NULL, t_box_num(1), t_box_num(0));
}

id_hashed_key_t
spar_var_hash (caddr_t p_data)
{
  SPART *v = ((SPART **)p_data)[0];
  char *str;
  id_hashed_key_t h1, h2;
  str = v->_.var.tabid;
  if (NULL != str)
    BYTE_BUFFER_HASH (h1, str, strlen (str));
  else
    h1 = 0;
  str = v->_.var.vname;
  BYTE_BUFFER_HASH (h2, str, strlen (str));
  return ((h1 ^ h2 ^ v->_.var.tr_idx) & ID_HASHED_KEY_MASK);
}


int 
spar_var_cmp (caddr_t p_data1, caddr_t p_data2)
{
  SPART *v1 = ((SPART **)p_data1)[0];
  SPART *v2 = ((SPART **)p_data2)[0];
  int res;
  res = ((v2->_.var.tr_idx > v1->_.var.tr_idx) ? 1 :
    ((v2->_.var.tr_idx < v1->_.var.tr_idx) ? -1 : 0) );
  if (0 != res) return res;
  res = strcmp (v1->_.var.vname, v2->_.var.vname);
  if (0 != res) return res;
  return strcmp (v1->_.var.tabid, v2->_.var.tabid);
}

caddr_t
spar_boxed_exec_uid (sparp_t *sparp)
{
  if (NULL == sparp->sparp_boxed_exec_uid)
    {
      user_t *exec_user = sparp->sparp_sparqre->sparqre_exec_user;
      if (NULL != exec_user)
        sparp->sparp_boxed_exec_uid = t_box_num_nonull (exec_user->usr_id);
      else
        sparp->sparp_boxed_exec_uid = t_box_num_nonull (U_ID_NOBODY);
    }
  return sparp->sparp_boxed_exec_uid;
}  

caddr_t
spar_immortal_exec_uname (sparp_t *sparp)
{
  if (NULL == sparp->sparp_immortal_exec_uname)
    {
      user_t *exec_user = sparp->sparp_sparqre->sparqre_exec_user;
      if (NULL != exec_user)
        sparp->sparp_immortal_exec_uname = box_dv_uname_string (exec_user->usr_name);
      else
        sparp->sparp_immortal_exec_uname = box_dv_uname_string ("nobody");
      box_dv_uname_make_immortal (sparp->sparp_immortal_exec_uname);
    }
  return sparp->sparp_immortal_exec_uname;
}  

int
spar_graph_static_perms (sparp_t *sparp, caddr_t graph_iri)
{
  caddr_t boxed_uid = spar_boxed_exec_uid (sparp);
  caddr_t *hit;
static caddr_t boxed_zero_iid = NULL;
  if (NULL != graph_iri)
    {
      caddr_t boxed_graph_iid = sparp_iri_to_id_nosignal (sparp, graph_iri);
/*!!! TBD: add retrieval of permissions of specific user on specific graph */
      hit = (caddr_t *)id_hash_get (rdf_graph_public_perms_dict_htable, (caddr_t)(&(boxed_graph_iid)));
      if (NULL != hit)
        {
          if (NULL != sparp->sparp_sparqre->sparqre_super_sc)
            {
              caddr_t graph_uname = box_dv_uname_nchars (graph_iri, box_length (graph_iri) - 1);
              qr_uses_jso (sparp->sparp_sparqre->sparqre_super_sc->sc_cc->cc_super_cc->cc_query, graph_uname);
            }
        return unbox (hit[0]);
    }
    }
  hit = (caddr_t *)id_hash_get (rdf_graph_default_perms_of_user_dict_htable, (caddr_t)(&(boxed_uid)));
  if (NULL != hit)
    {
      if (NULL != sparp->sparp_sparqre->sparqre_super_sc)
        {
          caddr_t uname = spar_immortal_exec_uname (sparp);
          qr_uses_jso (sparp->sparp_sparqre->sparqre_super_sc->sc_cc->cc_super_cc->cc_query, uname);
        }
    return unbox (hit[0]);
    }
  if (NULL == boxed_zero_iid)
    boxed_zero_iid = box_iri_id (0);
  hit = (caddr_t *)id_hash_get (rdf_graph_public_perms_dict_htable, (caddr_t)(&(boxed_zero_iid)));
  if (NULL != hit)
    return unbox (hit[0]);
  return (RDF_GRAPH_PERM_READ | RDF_GRAPH_PERM_WRITE | RDF_GRAPH_PERM_SPONGE | RDF_GRAPH_PERM_LIST);
}

int
spar_graph_needs_security_testing (sparp_t *sparp, SPART *g_expn, int req_perms)
{
  caddr_t fixed_g;
  int default_perms;
  switch (SPART_TYPE (g_expn))
    {
    case SPAR_QNAME: fixed_g = g_expn->_.qname.val; break;
    case SPAR_BLANK_NODE_LABEL: case SPAR_VARIABLE:
      if (SPART_VARR_CONFLICT & g_expn->_.var.rvr.rvrRestrictions)
        return 0;
      fixed_g = rvr_string_fixedvalue (&(g_expn->_.var.rvr));
      break;
    default: fixed_g = NULL; break;
    }
  if (NULL != fixed_g)
    {
      default_perms = spar_graph_static_perms (sparp, fixed_g);
      return (req_perms & ~default_perms);
    }
  default_perms = spar_graph_static_perms (sparp, NULL);
  return (req_perms & ~default_perms);        
}

caddr_t
spar_query_lex_analyze (caddr_t str, wcharset_t *query_charset)
{
  if (!DV_STRINGP(str))
    {
      return list (1, list (3, (ptrlong)0, (ptrlong)0, box_dv_short_string ("SPARQL analyzer: input text is not a string")));
    }
  else
    {
      dk_set_t lexems = NULL;
      caddr_t result_array;
      int param_ctr = 0;
      spar_query_env_t sparqre;
      sparp_t *sparp;
      sparp_env_t *se;
      MP_START ();
      memset (&sparqre, 0, sizeof (spar_query_env_t));
      sparp = (sparp_t *)t_alloc (sizeof (sparp_t));
      memset (sparp, 0, sizeof (sparp_t));
      se = (sparp_env_t *)t_alloc (sizeof (sparp_env_t));
      memset (se, 0, sizeof (sparp_env_t));
      sparqre.sparqre_param_ctr = &param_ctr;
      sparqre.sparqre_qi = CALLER_LOCAL;
      sparp->sparp_sparqre = &sparqre;
      sparp->sparp_text = t_box_copy (str);
      sparp->sparp_env = se;
      sparp->sparp_synthighlight = 1;
      sparp->sparp_err_hdr = t_box_dv_short_string ("SPARQL analyzer");
      if (NULL == query_charset)
	query_charset = default_charset;
      if (NULL == query_charset)
	sparp->sparp_enc = &eh__ISO8859_1;
      else
	{
	  sparp->sparp_enc = eh_get_handler (CHARSET_NAME (query_charset, NULL));
	  if (NULL == sparp->sparp_enc)
	    sparp->sparp_enc = &eh__ISO8859_1;
	}
      sparp->sparp_lang = server_default_lh;

      spar_fill_lexem_bufs (sparp);
      DO_SET (spar_lexem_t *, buf, &(sparp->sparp_output_lexem_bufs))
	{
	  int buflen = box_length (buf) / sizeof( spar_lexem_t);
	  int ctr;
	  for (ctr = 0; ctr < buflen; ctr++)
	    {
	      spar_lexem_t *curr = buf+ctr;
	      if (0 == curr->sparl_lex_value)
		break;
#ifdef SPARQL_DEBUG
	      dk_set_push (&lexems, list (5,
		box_num (curr->sparl_lineno),
		curr->sparl_depth,
		box_copy (curr->sparl_raw_text),
		curr->sparl_lex_value,
		curr->sparl_state ) );
#else
	      dk_set_push (&lexems, list (4,
		box_num (curr->sparl_lineno),
		curr->sparl_depth,
		box_copy (curr->sparl_raw_text),
		curr->sparl_lex_value ) );
#endif
	    }
	}
      END_DO_SET();
      if (NULL != sparp->sparp_sparqre->sparqre_catched_error)
	{
	  dk_set_push (&lexems, list (3,
		((NULL != sparp->sparp_curr_lexem) ? sparp->sparp_curr_lexem->sparl_lineno : (ptrlong)0),
		sparp->sparp_lexdepth,
		box_copy (ERR_MESSAGE (sparp->sparp_sparqre->sparqre_catched_error)) ) );
	}
      sparp_free (sparp);
      MP_DONE ();
      result_array = revlist_to_array (lexems);
      return result_array;
    }
}

#ifdef DEBUG
sparp_t * dbg_curr_sparp;
#endif

sparp_t *
sparp_query_parse (char * str, spar_query_env_t *sparqre, int rewrite_all)
{
  wcharset_t *query_charset = sparqre->sparqre_query_charset;
  t_NEW_VAR (sparp_t, sparp);
  t_NEW_VARZ (sparp_env_t, spare);
#ifdef DEBUG
  dbg_curr_sparp = sparp;
#endif
  memset (sparp, 0, sizeof (sparp_t));
  sparp->sparp_sparqre = sparqre;
  if ((NULL == sparqre->sparqre_cli) && (CALLER_LOCAL != sparqre->sparqre_qi))
    sparqre->sparqre_cli = sparqre->sparqre_qi->qi_client;
  if ((sparqre->sparqre_exec_user) && (NULL != sparqre->sparqre_cli))
    sparqre->sparqre_exec_user = sparqre->sparqre_cli->cli_user;
  sparp->sparp_env = spare;
  sparp->sparp_err_hdr = t_box_dv_short_string ("SPARQL compiler");
  if ((NULL == query_charset) /*&& (!sparqre->xqre_query_charset_is_set)*/)
    {
      if (CALLER_LOCAL != sparqre->sparqre_qi)
        query_charset = QST_CHARSET (sparqre->sparqre_qi);
      if (NULL == query_charset)
        query_charset = default_charset;
    }
  if (NULL == query_charset)
    sparp->sparp_enc = &eh__ISO8859_1;
  else
    {
      sparp->sparp_enc = eh_get_handler (CHARSET_NAME (query_charset, NULL));
      if (NULL == sparp->sparp_enc)
      sparp->sparp_enc = &eh__ISO8859_1;
    }
  sparp->sparp_lang = server_default_lh;
  spare->spare_namespace_prefixes_outer = 
    spare->spare_namespace_prefixes =
      sparqre->sparqre_external_namespaces;

  sparp->sparp_text = str;
  spar_fill_lexem_bufs (sparp);
  if (NULL != sparp->sparp_sparqre->sparqre_catched_error)
    return sparp;
  QR_RESET_CTX
    {
      /* Bug 4566: sparpyyrestart (NULL); */
      sparyyparse (sparp);
      if (rewrite_all)
        sparp_rewrite_all (sparp, 0 /* top is never cloned, hence zero safely_copy_retvals */);
    }
  QR_RESET_CODE
    {
      du_thread_t *self = THREAD_CURRENT_THREAD;
      sparp->sparp_sparqre->sparqre_catched_error = thr_get_error_code (self);
      thr_set_error_code (self, NULL);
      POP_QR_RESET;
      return sparp; /* see below */
    }
  END_QR_RESET
  /*xt_check (sparp, sparp->sparp_expr);*/
#ifndef NDEBUG
  t_check_tree (sparp->sparp_expr);
#endif
  return sparp;
}

#define ENV_COPY(field) env_copy->field = env->field
#define ENV_BOX_COPY(field) env_copy->field = t_box_copy (env->field)
#define ENV_SPART_COPY(field) env_copy->field = (SPART *)t_box_copy_tree ((caddr_t)(env->field))
#define ENV_SET_COPY(field) \
  env_copy->field = t_set_copy (env->field); \
  DO_SET_WRITABLE (SPART *, opt, iter, &(env_copy->field)) \
    { \
      iter->data = t_box_copy_tree ((caddr_t)opt); \
    } \
  END_DO_SET()

sparp_t *
sparp_clone_for_variant (sparp_t *sparp, int allow_output_formatting)
{
  s_node_t *iter;
  sparp_env_t *env = sparp->sparp_env;
  t_NEW_VAR (sparp_t, sparp_copy);
  t_NEW_VARZ (sparp_env_t, env_copy);
  memcpy (sparp_copy, sparp, sizeof (sparp_t));
  sparp_copy->sparp_env = env_copy;
  ENV_BOX_COPY (spare_input_param_valmode_name);
  ENV_BOX_COPY (spare_output_valmode_name);
  if (allow_output_formatting)
    {
  ENV_BOX_COPY (spare_output_format_name);
      ENV_BOX_COPY (spare_output_scalar_format_name);
      ENV_BOX_COPY (spare_output_dict_format_name);
    }
  ENV_BOX_COPY (spare_storage_name);
  ENV_COPY(spare_parent_env);
#if 0 /* These will be used when libraries of inference rules are introduced. */
    id_hash_t *		spare_fundefs;			/*!< In-scope function definitions */
    id_hash_t *		spare_vars;			/*!< Known variables as keys, equivs as values */
    id_hash_t *		spare_global_bindings;		/*!< Dictionary of global bindings, varnames as keys, default value expns as values. DV_DB_NULL box for no expn! */
#endif
  /* No copy for spare_grab_vars */
  ENV_SET_COPY (spare_common_sponge_options);
  ENV_SET_COPY (spare_default_graphs);
  ENV_SET_COPY (spare_named_graphs);
  ENV_COPY (spare_default_graphs_locked);
  ENV_COPY (spare_named_graphs_locked);
  ENV_SET_COPY (spare_common_sql_table_options);
  ENV_SET_COPY (spare_sql_select_options);
  ENV_SET_COPY (spare_global_var_names);
  return sparp_copy;
}

void
spar_env_push (sparp_t *sparp)
{
  sparp_env_t *env = sparp->sparp_env;
  t_NEW_VARZ (sparp_env_t, env_copy);
  ENV_COPY (spare_start_lineno);
  ENV_COPY (spare_param_counter_ptr);
  ENV_COPY (spare_namespace_prefixes);
  ENV_COPY (spare_namespace_prefixes_outer);
  ENV_COPY (spare_base_uri);
  ENV_COPY (spare_input_param_valmode_name);
  env_copy->spare_output_valmode_name = t_box_dv_short_string ("AUTO");
  ENV_COPY (spare_storage_name);
  ENV_COPY (spare_inference_name);
  ENV_COPY (spare_use_same_as);
#if 0 /* These will be used when libraries of inference rules are introduced. Don't forget to patch sparp_clone_for_variant()! */
    id_hash_t *		spare_fundefs;			/*!< In-scope function definitions */
    id_hash_t *		spare_vars;			/*!< Known variables as keys, equivs as values */
    id_hash_t *		spare_global_bindings;		/*!< Dictionary of global bindings, varnames as keys, default value expns as values. DV_DB_NULL box for no expn! */
#endif
  ENV_COPY (spare_grab);
  ENV_COPY (spare_common_sponge_options);
  ENV_COPY (spare_default_graphs);
  ENV_COPY (spare_default_graphs_locked);
  ENV_COPY (spare_named_graphs);
  ENV_COPY (spare_named_graphs_locked);
  ENV_COPY (spare_common_sql_table_options);
  /* no copy for spare_groupings */
  ENV_COPY (spare_sql_select_options);
  /* no copy for spare_context_qms */
  ENV_COPY (spare_context_qms);
  if ((NULL != env_copy->spare_context_qms) && ((SPART *)((ptrlong)_STAR) != env_copy->spare_context_qms->data))
    spar_error (sparp, "Subqueries are not allowed inside QUAD MAP group patterns other than 'QUAD MAP * {...}'");
  ENV_COPY (spare_context_graphs); /* Do we need this??? */
  /* no copy for spare_context_subjects */
  /* no copy for spare_context_predicates */
  /* no copy for spare_context_objects */
  /* no copy for spare_context_gp_subtypes */
  /* no copy for spare_acc_req_triples */
  /* no copy for spare_acc_opt_triples */
  /* no copy for spare_acc_filters */
  ENV_COPY (spare_good_graph_varnames);
  ENV_COPY (spare_good_graph_varname_sets);
  ENV_COPY (spare_good_graph_bmk);
  /* no copy for spare_selids */
  ENV_COPY (spare_global_var_names);
  ENV_COPY (spare_globals_are_numbered);
  ENV_COPY (spare_global_num_offset);
  /* no copy for spare_acc_qm_sqls */
  /* no copy for spare_qm_default_table */
  /* no copy for spare_qm_current_table_alias */
  /* no copy for spare_qm_parent_tables_of_aliases */
  /* no copy for spare_qm_parent_aliases_of_aliases */
  /* no copy for spare_qm_descendants_of_aliases */
  /* no copy for spare_qm_ft_indexes_of_columns */
  /* no copy for spare_qm_where_conditions */
  /* no copy for spare_qm_locals */
  /* no copy for spare_qm_affected_jso_iris */
  /* no copy for spare_qm_deleted */
  /* no copy for spare_sparul_log_mode */
  ENV_COPY (spare_signal_void_variables);

  env_copy->spare_parent_env = env;
  sparp->sparp_env = env_copy;
}

#undef ENV_COPY
#undef ENV_BOX_COPY
#undef ENV_SPART_COPY
#undef ENV_SET_COPY

void
spar_env_pop (sparp_t *sparp)
{
  sparp_env_t *env = sparp->sparp_env;
  sparp_env_t *parent = env->spare_parent_env;
#ifndef NDEBUG
  if (NULL == parent)
    GPF_T1("Misplaced call of spar_env_pop()");
#endif
  parent->spare_global_var_names = env->spare_global_var_names;
  sparp->sparp_env = parent;
}

extern void sparp_delete_clone (sparp_t *sparp);


void
sparp_compile_subselect (spar_query_env_t *sparqre)
{
  sparp_t * sparp;
  query_t * qr = NULL; /*dummy for CC_INIT */
  spar_sqlgen_t ssg;
  comp_context_t cc;
  sql_comp_t sc;
  caddr_t str = strses_string (sparqre->sparqre_src->sif_skipped_part);
  caddr_t res;
#ifdef SPARQL_DEBUG
  printf ("\nsparp_compile_subselect() input:\n%s", str);
#endif
  strses_free (sparqre->sparqre_src->sif_skipped_part);
  sparqre->sparqre_src->sif_skipped_part = NULL;
  sparqre->sparqre_cli = sqlc_client();
  sparqre->sparqre_exec_user = sparqre->sparqre_cli->cli_user;
  sparp = sparp_query_parse (str, sparqre, 1);
  dk_free_box (str);
  if (NULL != sparp->sparp_sparqre->sparqre_catched_error)
    {
#ifdef SPARQL_DEBUG
      printf ("\nsparp_compile_subselect() caught parse error: %s", ERR_MESSAGE(sparp->sparp_sparqre->sparqre_catched_error));
#endif
      return;
    }
  memset (&ssg, 0, sizeof (spar_sqlgen_t));
  memset (&sc, 0, sizeof (sql_comp_t));
  CC_INIT (cc, ((NULL != sparqre->sparqre_super_sc) ? sparqre->sparqre_super_sc->sc_client : sqlc_client()));
  sc.sc_cc = &cc;
  if (NULL != sparqre->sparqre_super_sc)
    {
      cc.cc_super_cc = sparqre->sparqre_super_sc->sc_cc->cc_super_cc;
      sc.sc_super = sparqre->sparqre_super_sc;
    }
  ssg.ssg_out = strses_allocate ();
  ssg.ssg_sc = &sc;
  ssg.ssg_sparp = sparp;
  ssg.ssg_tree = sparp->sparp_expr;
  ssg_make_whole_sql_text (&ssg);
  if (NULL != sparqre->sparqre_catched_error)
    {
      strses_free (ssg.ssg_out);
      ssg.ssg_out = NULL;
      return;
    }
  session_buffered_write (ssg.ssg_out, sparqre->sparqre_tail_sql_text, strlen (sparqre->sparqre_tail_sql_text));
  session_buffered_write_char (0 /*YY_END_OF_BUFFER_CHAR*/, ssg.ssg_out); /* First terminator */
  session_buffered_write_char (0 /*YY_END_OF_BUFFER_CHAR*/, ssg.ssg_out); /* Second terminator. Most of Lex-es need two! */
  res = strses_string (ssg.ssg_out);
#ifdef SPARQL_DEBUG
  printf ("\nsparp_compile_subselect() done: %s", res);
#endif
  strses_free (ssg.ssg_out);
  ssg.ssg_out = NULL;
  sparqre->sparqre_compiled_text = t_box_copy (res);
  dk_free_box (res);
}


caddr_t
bif_sparql_explain (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  int param_ctr = 0;
  spar_query_env_t sparqre;
  sparp_t * sparp;
  caddr_t str = bif_string_arg (qst, args, 0, "sparql_explain");
  int rewrite_all = (0 != ((2 > BOX_ELEMENTS (args)) ? 1 : bif_long_arg (qst, args, 1, "sparql_explain")));
  dk_session_t *res;
  MP_START ();
  memset (&sparqre, 0, sizeof (spar_query_env_t));
  sparqre.sparqre_param_ctr = &param_ctr;
  sparqre.sparqre_qi = (query_instance_t *) qst;
  sparp = sparp_query_parse (str, &sparqre, rewrite_all);
  if (NULL != sparqre.sparqre_catched_error)
    {
      MP_DONE ();
      sqlr_resignal (sparqre.sparqre_catched_error);
    }
  res = strses_allocate ();
  spart_dump (sparp->sparp_expr, res, 0, "QUERY", -1);
#if 1
  {
    int eq_ctr, eq_count;
    SES_PRINT (res, "\nEQUIVS:");
    eq_count = sparp->sparp_equiv_count;
    for (eq_ctr = 0; eq_ctr < eq_count; eq_ctr++)
      {
        sparp_equiv_t *eq = sparp->sparp_equivs[eq_ctr];
        spart_dump_eq (eq_ctr, eq, res);
      }
  }
#endif
  MP_DONE ();
  return (caddr_t)res;
}

void sparp_make_sparqld_text (spar_sqlgen_t *ssg);

caddr_t
bif_sparql_detalize (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  int param_ctr = 0, flags;
  spar_query_env_t sparqre;
  sparp_t * sparp;
  caddr_t str;
  spar_sqlgen_t ssg;
  sql_comp_t sc;
  str = bif_string_arg (qst, args, 0, "sparql_detalize");
  flags = ((2 <= BOX_ELEMENTS (args)) ? bif_long_arg (qst, args, 1, "sparql_detalize") : SSG_SD_VOS_CURRENT);
  MP_START ();
  memset (&sparqre, 0, sizeof (spar_query_env_t));
  sparqre.sparqre_param_ctr = &param_ctr;
  sparqre.sparqre_qi = (query_instance_t *) qst;
  sparp = sparp_query_parse (str, &sparqre, 1);
  if (NULL != sparqre.sparqre_catched_error)
    {
      MP_DONE ();
      sqlr_resignal (sparqre.sparqre_catched_error);
    }
  memset (&ssg, 0, sizeof (spar_sqlgen_t));
  memset (&sc, 0, sizeof (sql_comp_t));
  sc.sc_client = sparqre.sparqre_qi->qi_client;
  ssg.ssg_out = strses_allocate ();
  ssg.ssg_sc = &sc;
  ssg.ssg_sparp = sparp;
  ssg.ssg_tree = sparp->sparp_expr;
  ssg.ssg_sd_flags = flags;
  ssg.ssg_sd_used_namespaces = id_str_hash_create (16);
  QR_RESET_CTX
    {
      sparp_make_sparqld_text (&ssg);
    }
  QR_RESET_CODE
    {
      du_thread_t *self = THREAD_CURRENT_THREAD;
      sparp->sparp_sparqre->sparqre_catched_error = thr_get_error_code (self);
      thr_set_error_code (self, NULL);
    }
  END_QR_RESET
  if (NULL != sparqre.sparqre_catched_error)
    {
      id_hash_iterator_t dict_hit;
      char **dict_key;		/* Current key to zap */
      char **dict_val;		/* Current value to zap, unused */
      for (id_hash_iterator (&dict_hit, ssg.ssg_sd_used_namespaces);
          hit_next (&dict_hit, (char **) (&dict_key), (char **) (&dict_val));
      /*no step */ )
        {
          dk_free_box (dict_key[0]);
          dk_free_box (dict_val[0]);
        }
      id_hash_free (ssg.ssg_sd_used_namespaces);
      strses_free (ssg.ssg_out);
      ssg.ssg_out = NULL;
      MP_DONE ();
      sqlr_resignal (sparqre.sparqre_catched_error);
    }
  id_hash_free (ssg.ssg_sd_used_namespaces);
  MP_DONE ();
  return (caddr_t)(ssg.ssg_out);
}

caddr_t
bif_sparql_to_sql_text (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  int param_ctr = 0;
  spar_query_env_t sparqre;
  sparp_t * sparp;
  caddr_t str;
  spar_sqlgen_t ssg;
  sql_comp_t sc;
  str = bif_string_arg (qst, args, 0, "sparql_to_sql_text");
  MP_START ();
  memset (&sparqre, 0, sizeof (spar_query_env_t));
  sparqre.sparqre_param_ctr = &param_ctr;
  sparqre.sparqre_qi = (query_instance_t *) qst;
  if (1 < BOX_ELEMENTS (args))
    {
      caddr_t uname = bif_string_arg (qst, args, 1, "sparql_to_sql_text");
      sparqre.sparqre_exec_user = sec_name_to_user (uname);
    }
  sparp = sparp_query_parse (str, &sparqre, 1);
  if (NULL != sparqre.sparqre_catched_error)
    {
      MP_DONE ();
      sqlr_resignal (sparqre.sparqre_catched_error);
    }
  memset (&ssg, 0, sizeof (spar_sqlgen_t));
  memset (&sc, 0, sizeof (sql_comp_t));
  sc.sc_client = sparqre.sparqre_qi->qi_client;
  ssg.ssg_out = strses_allocate ();
  ssg.ssg_sc = &sc;
  ssg.ssg_sparp = sparp;
  ssg.ssg_tree = sparp->sparp_expr;
  ssg_make_whole_sql_text (&ssg);
  if (NULL != sparqre.sparqre_catched_error)
    {
      strses_free (ssg.ssg_out);
      ssg.ssg_out = NULL;
      MP_DONE ();
      sqlr_resignal (sparqre.sparqre_catched_error);
    }
  MP_DONE ();
  return (caddr_t)(ssg.ssg_out);
}


caddr_t
bif_sparql_lex_analyze (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t str = bif_string_arg (qst, args, 0, "sparql_lex_analyze");
  return spar_query_lex_analyze (str, QST_CHARSET(qst));
}

SPART *
spar_make_literal_from_sql_box (sparp_t * sparp, caddr_t box, int make_bnode_if_null)
{
  switch (DV_TYPE_OF (box))
    {
    case DV_LONG_INT: return spartlist (sparp, 4, SPAR_LIT, t_box_copy (box), uname_xmlschema_ns_uri_hash_integer, NULL);
    case DV_NUMERIC: return spartlist (sparp, 4, SPAR_LIT, t_box_copy (box), uname_xmlschema_ns_uri_hash_decimal, NULL);
    case DV_DOUBLE_FLOAT: return spartlist (sparp, 4, SPAR_LIT, t_box_copy (box), uname_xmlschema_ns_uri_hash_double, NULL);
    case DV_UNAME: return spartlist (sparp, 2, SPAR_QNAME, t_box_copy (box));
    case DV_IRI_ID:
      {
        iri_id_t iid = unbox_iri_id (box);
        caddr_t iri;
        SPART *res;
        if (0L == iid)
          return NULL;
        if (iid >= min_bnode_iri_id ())
          {
            caddr_t t_iri;
            if (iid >= MIN_64BIT_BNODE_IRI_ID)
              t_iri = t_box_sprintf (30, "nodeID://b" BOXINT_FMT, (boxint)(iid-MIN_64BIT_BNODE_IRI_ID));
            else
              t_iri = t_box_sprintf (30, "nodeID://" BOXINT_FMT, (boxint)(iid));
            return spartlist (sparp, 2, SPAR_QNAME, t_box_dv_uname_string (t_iri));
          }
        iri = (caddr_t)sparp_id_to_iri (sparp, iid);
        if (!iri)
          return NULL;
        res = spartlist (sparp, 2, SPAR_QNAME, t_box_dv_uname_string (iri));
        return res;
      }
    case DV_RDF:
      {
        rdf_box_t *rb = (rdf_box_t *)box;
        if (!rb->rb_is_complete ||
          (RDF_BOX_DEFAULT_TYPE != rb->rb_type) ||
          (RDF_BOX_DEFAULT_LANG != rb->rb_lang) ||
          DV_STRING != DV_TYPE_OF (rb->rb_box) )
          spar_internal_error (sparp, "spar_" "make_literal_from_sql_box() does not support rdf boxes other than complete untyped strings, sorry");
        return spartlist (sparp, 4, SPAR_LIT, t_box_copy (box), NULL, NULL);
      }
    case DV_STRING: spartlist (sparp, 4, SPAR_LIT, t_box_copy (box), NULL, NULL);
    case DV_DB_NULL:
      if (make_bnode_if_null)
        return spar_make_blank_node (sparp, spar_mkid (sparp, "_:sqlbox"), 1);
      else
        return spar_make_variable (sparp, t_box_dv_uname_string ("_:sqlbox"));
      break;
    default: spar_internal_error (sparp, "spar_" "make_literal_from_sql_box(): unsupported box type");
  }
  return NULL; /* to keep compiler happy */
}

#define QUAD_MAPS_FOR_QUAD 1
#define SQL_COLS_FOR_QUAD 2
caddr_t
bif_sparql_quad_maps_for_quad_impl (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args, int resulting_format, const char *fname)
{
  int param_ctr_for_sparqre = 0;
  spar_query_env_t sparqre;
  sparp_env_t spare;
  sparp_t sparp;
  spar_sqlgen_t ssg;
  sql_comp_t sc;
  caddr_t sqlvals[SPART_TRIPLE_FIELDS_COUNT];
  caddr_t *bad_sources_val = NULL;
  caddr_t *good_sources_val = NULL;
  caddr_t storage_name = NULL;
  caddr_t *res = NULL;
  boxint flags = 0;
  switch (BOX_ELEMENTS (args))
    {
    case 8: flags = bif_long_arg (qst, args, 7, fname);
    case 7: bad_sources_val = bif_strict_2type_array_arg (DV_UNAME, DV_IRI_ID, qst, args, 6, fname);
    case 6: good_sources_val = bif_strict_2type_array_arg (DV_UNAME, DV_IRI_ID, qst, args, 5, fname);
    case 5: storage_name = bif_string_or_uname_or_wide_or_null_arg (qst, args, 4, fname);
    case 4: sqlvals[SPART_TRIPLE_OBJECT_IDX]	= bif_arg (qst, args, 3, fname);
    case 3: sqlvals[SPART_TRIPLE_PREDICATE_IDX]	= bif_arg (qst, args, 2, fname);
    case 2: sqlvals[SPART_TRIPLE_SUBJECT_IDX]	= bif_arg (qst, args, 1, fname);
    case 1: sqlvals[SPART_TRIPLE_GRAPH_IDX]	= bif_arg (qst, args, 0, fname);
    case 0: ; /* no break */
    }
  MP_START ();
  memset (&sparqre, 0, sizeof (spar_query_env_t));
  memset (&spare, 0, sizeof (sparp_env_t));
  memset (&sparp, 0, sizeof (sparp_t));
  sparqre.sparqre_param_ctr = &param_ctr_for_sparqre;
  sparqre.sparqre_qi = (query_instance_t *) qst;
  sparp.sparp_sparqre = &sparqre;
  sparp.sparp_env = &spare;
  memset (&ssg, 0, sizeof (spar_sqlgen_t));
  memset (&sc, 0, sizeof (sql_comp_t));
  sc.sc_client = sparqre.sparqre_qi->qi_client;
  ssg.ssg_sc = &sc;
  ssg.ssg_sparp = &sparp;
  QR_RESET_CTX
    {
      int src_max_count = BOX_ELEMENTS_0 (good_sources_val) + BOX_ELEMENTS_0 (bad_sources_val);
      SPART **sources = (SPART **)t_alloc_box (src_max_count * sizeof (SPART *), DV_ARRAY_OF_POINTER);
      SPART *triple;
      SPART *fake_global_sql_param = NULL;
      SPART *fake_global_long_param = NULL;
      triple_case_t **cases;
      int src_idx, case_count, case_ctr;
      int src_total_count = 0;
      if (DV_STRING == DV_TYPE_OF (storage_name))
        storage_name = t_box_dv_uname_string (storage_name);
      sparp.sparp_storage = sparp_find_storage_by_name (storage_name);
      t_set_push (&(spare.spare_selids), t_box_dv_short_string (fname));
      triple = spar_make_plain_triple (&sparp,
        spar_make_literal_from_sql_box (&sparp, sqlvals[SPART_TRIPLE_GRAPH_IDX]		, (int)(flags & 1)),
        spar_make_literal_from_sql_box (&sparp, sqlvals[SPART_TRIPLE_SUBJECT_IDX]	, (int)(flags & 1)),
        spar_make_literal_from_sql_box (&sparp, sqlvals[SPART_TRIPLE_PREDICATE_IDX]	, (int)(flags & 1)),
        spar_make_literal_from_sql_box (&sparp, sqlvals[SPART_TRIPLE_OBJECT_IDX]	, (int)(flags & 1)),
        (caddr_t)(_STAR), NULL );
      DO_BOX_FAST (caddr_t, itm, src_idx, good_sources_val)
        {
          SPART *expn = spar_make_literal_from_sql_box (&sparp, itm, 0);
          if (SPAR_QNAME == SPART_TYPE (expn))
            sources [src_total_count++] = spartlist (&sparp, 4, SPAR_GRAPH,
             SPART_GRAPH_FROM, expn->_.qname.val, expn );
        }
      END_DO_BOX_FAST;
      DO_BOX_FAST (caddr_t, itm, src_idx, bad_sources_val)
        {
          SPART *expn = spar_make_literal_from_sql_box (&sparp, itm, 0);
          if (SPAR_QNAME == SPART_TYPE (expn))
            sources [src_total_count++] = spartlist (&sparp, 4, SPAR_GRAPH,
             SPART_GRAPH_NOT_FROM, expn->_.qname.val, expn );
        }
      END_DO_BOX_FAST;
      if (src_total_count < src_max_count)
        {
          SPART **tmp = (SPART **)t_alloc_box (src_total_count * sizeof (SPART *), DV_ARRAY_OF_POINTER);
          memcpy (tmp, sources, src_total_count * sizeof (SPART *));
          sources = tmp;
        }
      cases = sparp_find_triple_cases (&sparp, triple, sources, SPART_GRAPH_FROM);
      case_count = BOX_ELEMENTS (cases);
      switch (resulting_format)
        {
        case QUAD_MAPS_FOR_QUAD:
          res = dk_alloc_list (case_count);
          for (case_ctr = case_count; case_ctr--; /* no step */)
            {
              triple_case_t *tc = cases [case_ctr];
              jso_rtti_t *sub = gethash (tc->tc_qm, jso_rttis_of_structs);
              caddr_t qm_name;
              if (NULL == sub)
                spar_internal_error (&sparp, "corrupted metadata: PointerToCorrupted");
              else if (sub->jrtti_self != tc->tc_qm)
                spar_internal_error (&sparp, "corrupted metadata: PointerToStaleDeleted");
              qm_name = box_copy (((jso_rtti_t *)(sub))->jrtti_inst_iri);
              res [case_ctr] = list (2, qm_name, tc->tc_qm->qmMatchingFlags);
            }
          break;
        case SQL_COLS_FOR_QUAD:
          {
            dk_set_t acc_maps = NULL;
            for (case_ctr = case_count; case_ctr--; /* no step */)
              {
                triple_case_t *tc = cases [case_ctr];
                int fld_ctr;
                int unique_bij_fld = -1;
                for (fld_ctr = SPART_TRIPLE_FIELDS_COUNT; fld_ctr--; /* no step */)
                  {
                    int col_ctr, col_count;
                    int alias_ctr, alias_count;
                    caddr_t sqlval = sqlvals [fld_ctr];
                    dtp_t sqlval_dtp = DV_TYPE_OF (sqlval);
                    caddr_t **col_descs;
                    caddr_t map_desc;
                    SPART *param;
                    ccaddr_t tmpl;
                    caddr_t expn_text;
                    qm_value_t *qmv;
                    if (DV_DB_NULL == sqlval_dtp)
                      continue;
                    qmv = SPARP_FIELD_QMV_OF_QM (tc->tc_qm, fld_ctr);
                    if ((NULL == qmv) || (!qmv->qmvFormat->qmfIsBijection && !qmv->qmvFormat->qmfDerefFlags))
                      continue;
                    if (qmv->qmvColumnsFormKey)
                      unique_bij_fld = fld_ctr;
                    col_count = BOX_ELEMENTS (qmv->qmvColumns);
                    col_descs = (caddr_t **)dk_alloc_list (col_count);
                    alias_count = BOX_ELEMENTS_0 (qmv->qmvATables);
                    for (col_ctr = col_count; col_ctr--; /* no step */)
                      {
                        qm_column_t *qmc = qmv->qmvColumns[col_ctr];
                        caddr_t *col_desc;
                        ccaddr_t table_alias = qmc->qmvcAlias;
                        ccaddr_t table_name = qmv->qmvTableName;
                        for (alias_ctr = alias_count; alias_ctr--; /* no step */)
                          {
                            if (strcmp (qmv->qmvATables[alias_ctr]->qmvaAlias, table_alias))
                              continue;
                            table_name = qmv->qmvATables[alias_ctr]->qmvaTableName;
                            break;
                          }
                        col_desc = (caddr_t *)list (4, box_copy (table_alias), box_copy (table_name), box_copy (qmc->qmvcColumnName), NULL);
                        col_descs[col_ctr] = col_desc;
                      }
                    switch (sqlval_dtp)
                      {
                      case DV_UNAME:
                        if (NULL == fake_global_sql_param)
                          fake_global_sql_param = spar_make_variable (&sparp, t_box_dv_uname_string (":0"));
                        param = fake_global_sql_param;
                        tmpl = qmv->qmvFormat->qmfShortOfUriTmpl;
                        break;
                      case DV_IRI_ID: case DV_RDF:
                        if (NULL == fake_global_sql_param)
                          fake_global_long_param = spar_make_variable (&sparp, t_box_dv_uname_string (":LONG::0"));
                        param = fake_global_long_param;
                        tmpl = qmv->qmvFormat->qmfShortOfLongTmpl; break;
                      default:
                        if (NULL == fake_global_sql_param)
                          fake_global_sql_param = spar_make_variable (&sparp, t_box_dv_uname_string (":0"));
                        param = fake_global_sql_param;
                        tmpl = qmv->qmvFormat->qmfShortOfSqlvalTmpl;
                        break;
                      }
                    if (NULL == ssg.ssg_out)
                      ssg.ssg_out = strses_allocate ();
                    session_buffered_write (ssg.ssg_out, "vector (", strlen ("vector ("));
                    ssg_print_tmpl (&ssg, qmv->qmvFormat, tmpl, NULL, NULL, param, NULL_ASNAME);
                    session_buffered_write (ssg.ssg_out, ")", strlen (")"));
                    expn_text = strses_string (ssg.ssg_out);
                    strses_flush (ssg.ssg_out);
                    map_desc = list (4,
                      box_num (fld_ctr),
                      box_num (qmv->qmvColumnsFormKey),
                      col_descs,
                      expn_text );
                    dk_set_push (&acc_maps, map_desc);
                  }
              }
            res = (caddr_t *)revlist_to_array (acc_maps);
          }
      }
    }
  QR_RESET_CODE
    {
      du_thread_t *self = THREAD_CURRENT_THREAD;
      sparqre.sparqre_catched_error = thr_get_error_code (self);
      thr_set_error_code (self, NULL);
      POP_QR_RESET;
      MP_DONE ();
      sqlr_resignal (sparqre.sparqre_catched_error);
    }
  END_QR_RESET
  MP_DONE ();
  return (caddr_t)res;
}

caddr_t
bif_sparql_quad_maps_for_quad (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return bif_sparql_quad_maps_for_quad_impl (qst, err_ret, args, QUAD_MAPS_FOR_QUAD, "sparql_quad_maps_for_quad");
}

caddr_t
bif_sparql_sql_cols_for_quad (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return bif_sparql_quad_maps_for_quad_impl (qst, err_ret, args, SQL_COLS_FOR_QUAD, "sparql_sql_cols_for_quad");
}

caddr_t
bif_sprintff_is_proven_bijection (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t f = bif_string_or_uname_arg (qst, args, 0, "__sprintff_is_proven_bijection");
  return box_num (sprintff_is_proven_bijection (f));
}

caddr_t
bif_sprintff_is_proven_unparseable (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t f = bif_string_or_uname_arg (qst, args, 0, "__sprintff_is_proven_unparseable");
  return box_num (sprintff_is_proven_unparseable (f));
}

caddr_t
bif_sprintff_intersect (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t f1 = bif_string_or_uname_arg (qst, args, 0, "__sprintff_intersect");
  caddr_t f2 = bif_string_or_uname_arg (qst, args, 1, "__sprintff_intersect");
  boxint ignore_cache = bif_long_arg (qst, args, 2, "__sprintff_intersect");
  caddr_t res;
  sec_check_dba ((query_instance_t *)qst, "__sprintff_intersect"); /* To prevent attack by intersecting garbage in order to run out of memory. */
  res = (caddr_t)sprintff_intersect (f1, f2, ignore_cache);
  if (NULL == res)
    return NEW_DB_NULL;
  return (ignore_cache ? res : box_copy (res));
}

caddr_t
bif_sprintff_like (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t f1 = bif_string_or_uname_arg (qst, args, 0, "__sprintff_like");
  caddr_t f2 = bif_string_or_uname_arg (qst, args, 1, "__sprintff_like");
  sec_check_dba ((query_instance_t *)qst, "__sprintff_like"); /* To prevent attack by likening garbage in order to run out of memory. */
  return box_num (sprintff_like (f1, f2));
}

#ifdef DEBUG

typedef struct spar_lexem_descr_s
{
  int ld_val;
  const char *ld_yname;
  char ld_fmttype;
  const char * ld_fmt;
  caddr_t *ld_tests;
} spar_lexem_descr_t;

spar_lexem_descr_t spar_lexem_descrs[__SPAR_NONPUNCT_END+1];

#define LEX_PROPS spar_lex_props
#define PUNCT(x) 'P', (x)
#define LITERAL(x) 'L', (x)
#define FAKE(x) 'F', (x)
#define SPAR "s"

#define LAST(x) "L", (x)
#define LAST1(x) "K", (x)
#define MISS(x) "M", (x)
#define ERR(x)  "E", (x)

#define PUNCT_SPAR_LAST(x) PUNCT(x), SPAR, LAST(x)


static void spar_lex_props (int val, const char *yname, char fmttype, const char *fmt, ...)
{
  va_list tail;
  const char *cmd;
  dk_set_t tests = NULL;
  spar_lexem_descr_t *ld = spar_lexem_descrs + val;
  if (0 != ld->ld_val)
    GPF_T;
  ld->ld_val = val;
  ld->ld_yname = yname;
  ld->ld_fmttype = fmttype;
  ld->ld_fmt = fmt;
  va_start (tail, fmt);
  for (;;)
    {
      cmd = va_arg (tail, const char *);
      if (NULL == cmd)
	break;
      dk_set_push (&tests, box_dv_short_string (cmd));
    }
  va_end (tail);
  ld->ld_tests = (caddr_t *)revlist_to_array (tests);
}

static void spar_lexem_descrs_fill (void)
{
  static int first_run = 1;
  if (!first_run)
    return;
  first_run = 0;
  #include "sparql_lex_props.c"
}

caddr_t
bif_sparql_lex_test (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  dk_set_t report = NULL;
  int tested_lex_val = 0;
  spar_lexem_descrs_fill ();
  for (tested_lex_val = 0; tested_lex_val < __SPAR_NONPUNCT_END; tested_lex_val++)
    {
      char cmd;
      caddr_t **lexems;
      unsigned lex_count;
      unsigned cmd_idx = 0;
      int last_lval, last1_lval;
      spar_lexem_descr_t *ld = spar_lexem_descrs + tested_lex_val;
      if (0 == ld->ld_val)
	continue;
      dk_set_push (&report, box_dv_short_string (""));
      dk_set_push (&report,
        box_sprintf (0x100, "#define % 25s %d /* '%s' (%c) */",
	  ld->ld_yname, ld->ld_val, ld->ld_fmt, ld->ld_fmttype ) );
      for (cmd_idx = 0; cmd_idx < BOX_ELEMENTS(ld->ld_tests); cmd_idx++)
	{
	  cmd = ld->ld_tests[cmd_idx][0];
	  switch (cmd)
	    {
	    case 's': break;	/* Fake, SPARQL has only one mode */
	    case 'K': case 'L': case 'M': case 'E':
	      cmd_idx++;
	      lexems = (caddr_t **) spar_query_lex_analyze (ld->ld_tests[cmd_idx], QST_CHARSET(qst));
	      dk_set_push (&report, box_dv_short_string (ld->ld_tests[cmd_idx]));
	      lex_count = BOX_ELEMENTS (lexems);
	      if (0 == lex_count)
		{
		  dk_set_push (&report, box_dv_short_string ("FAILED: no lexems parsed and no error reported!"));
		  goto end_of_test;
		}
	      { char buf[0x1000]; char *buf_tail = buf;
	        unsigned lctr = 0;
		for (lctr = 0; lctr < lex_count && (5 == BOX_ELEMENTS(lexems[lctr])); lctr++)
		  {
		    ptrlong *ldata = ((ptrlong *)(lexems[lctr]));
		    int lval = ldata[3];
		    spar_lexem_descr_t *ld = spar_lexem_descrs + lval;
		    if (ld->ld_val)
		      buf_tail += sprintf (buf_tail, " %s", ld->ld_yname);
		    else if (lval < 0x100)
		      buf_tail += sprintf (buf_tail, " '%c'", lval);
		    else GPF_T;
		    buf_tail += sprintf (buf_tail, " %ld ", (long)(ldata[4]));
		  }
	        buf_tail[0] = '\0';
		dk_set_push (&report, box_dv_short_string (buf));
	      }
	      if (3 == BOX_ELEMENTS(lexems[lex_count-1])) /* lexical error */
		{
		  dk_set_push (&report,
		    box_sprintf (0x1000, "%s: ERROR %s",
		      ('E' == cmd) ? "PASSED": "FAILED", lexems[lex_count-1][2] ) );
		  goto end_of_test;
		}
	      if (END_OF_SPARQL_TEXT != ((ptrlong *)(lexems[lex_count-1]))[3])
		{
		  dk_set_push (&report, box_dv_short_string ("FAILED: end of source is not reached and no error reported!"));
		  goto end_of_test;
		}
	      if (1 == lex_count)
		{
		  dk_set_push (&report, box_dv_short_string ("FAILED: no lexems parsed and only end of source has found!"));
		  goto end_of_test;
		}
	      last_lval = ((ptrlong *)(lexems[lex_count-2]))[3];
	      if ('E' == cmd)
		{
		  dk_set_push (&report,
		    box_sprintf (0x1000, "FAILED: %d lexems found, last lexem is %d, must be error",
		      lex_count, last_lval) );
		  goto end_of_test;
		}
	      if ('K' == cmd)
		{
		  if (4 > lex_count)
		    {
		      dk_set_push (&report,
			box_sprintf (0x1000, "FAILED: %d lexems found, the number of actual lexems is less than two",
			  lex_count ) );
		      goto end_of_test;
		    }
		  last1_lval = ((ptrlong *)(lexems[lex_count-3]))[3];
		  dk_set_push (&report,
		    box_sprintf (0x1000, "%s: %d lexems found, one-before-last lexem is %d, must be %d",
		      (last1_lval == tested_lex_val) ? "PASSED": "FAILED", lex_count, last1_lval, tested_lex_val) );
		  goto end_of_test;
		}
	      if ('L' == cmd)
		{
		  dk_set_push (&report,
		    box_sprintf (0x1000, "%s: %d lexems found, last lexem is %d, must be %d",
		      (last_lval == tested_lex_val) ? "PASSED": "FAILED", lex_count, last_lval, tested_lex_val) );
		  goto end_of_test;
		}
	      if ('M' == cmd)
		{
		  unsigned lctr;
		  for (lctr = 0; lctr < lex_count; lctr++)
		    {
		      int lval = ((ptrlong *)(lexems[lctr]))[3];
		      if (lval == tested_lex_val)
			{
			  dk_set_push (&report,
			    box_sprintf (0x1000, "FAILED: %d lexems found, lexem %d is found but it should not occur",
			      lex_count, tested_lex_val) );
			  goto end_of_test;
			}
		    }
		  dk_set_push (&report,
		    box_sprintf (0x1000, "PASSED: %d lexems found, lexem %d is not found and it should not occur",
		      lex_count, tested_lex_val) );
		  goto end_of_test;
		}
	      GPF_T;
end_of_test:
	      dk_free_tree (lexems);
	      break;		
	    default: GPF_T;
	    }
	  }
    }
  return revlist_to_array (report);
}
#endif


void
sparql_init (void)
{
  caddr_t err;
  rdf_ds_load_all();
  iri_to_id_nosignal_cached_qr = sql_compile_static (iri_to_id_nosignal_text, bootstrap_cli, &err, SQLC_DEFAULT);
  id_to_iri_cached_qr = sql_compile_static (id_to_iri_text, bootstrap_cli, &err, SQLC_DEFAULT);
  bif_define ("sparql_to_sql_text", bif_sparql_to_sql_text);
  bif_define ("sparql_detalize", bif_sparql_detalize);
  bif_define ("sparql_explain", bif_sparql_explain);
  bif_define ("sparql_lex_analyze", bif_sparql_lex_analyze);
  bif_define ("sparql_quad_maps_for_quad", bif_sparql_quad_maps_for_quad);
  bif_define ("sparql_sql_cols_for_quad", bif_sparql_sql_cols_for_quad);
  bif_define ("__sprintff_is_proven_bijection", bif_sprintff_is_proven_bijection);
  bif_define ("__sprintff_is_proven_unparseable", bif_sprintff_is_proven_unparseable);
  bif_define ("__sprintff_intersect", bif_sprintff_intersect);
  bif_define ("__sprintff_like", bif_sprintff_like);
#ifdef DEBUG
  bif_define ("sparql_lex_test", bif_sparql_lex_test);
#endif
}

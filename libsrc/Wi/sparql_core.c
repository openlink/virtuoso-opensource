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
 */

#include "libutil.h"
#include "sqlnode.h"
#include "sqlbif.h"
#include "sqlparext.h"
#include "bif_text.h"
#include "xmlparser.h"
#include "xmltree.h"
#include "numeric.h"
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

SPART*
spartlist_impl (sparp_t *sparp, ptrlong length, ptrlong type, ...)
{
  SPART *tree;
  va_list ap;
  int inx;
  va_start (ap, type);
#ifdef DEBUG
  if (IS_POINTER(type))
    GPF_T;
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
  if (IS_POINTER(type))
    GPF_T;
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

void spar_error (sparp_t *sparp, const char *format, ...)
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

void spar_internal_error (sparp_t *sparp, const char *msg)
{
#if 0
  FILE *core_reason1;
  fprintf (stderr, "Internal error %s while processing\n-----8<-----\n%s\n-----8<-----\n", msg, sparp->sparp_text);
  core_reason1 = fopen ("core_reason1","wt");
  fprintf (core_reason1, "Internal error %s while processing\n-----8<-----\n%s\n-----8<-----\n", msg, sparp->sparp_text);
  fclose (core_reason1);
  GPF_T1(msg);
#else
  sqlr_new_error ("37000", "SP031",
    "%.400s: Internal error: %.1500s",
    ((NULL != sparp) ? sparp->sparp_err_hdr : "SPARQL"), msg);
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

caddr_t sparp_expand_qname_prefix (sparp_t *sparp, caddr_t qname)
{
  char *lname = strchr (qname, ':');
  dk_set_t ns_dict;
  caddr_t ns_pref, ns_uri, res;
  int ns_uri_len, local_len, res_len;
  if (NULL == lname)
    return qname;
  lname++;
  ns_dict = sparp->sparp_env->spare_namespace_prefixes;
  ns_pref = t_box_dv_short_nchars (qname, lname - qname);
  ns_uri = dk_set_get_keyword (ns_dict, ns_pref, NULL);
  if (NULL == ns_uri)
    {
      if (!strcmp (ns_pref, "rdf:"))
        ns_uri = uname_rdf_ns_uri;
      else if (!strcmp (ns_pref, "xsd:"))
        ns_uri = uname_xmlschema_ns_uri_hash;
      else if (!strcmp (ns_pref, "virtrdf:"))
        ns_uri = uname_virtrdf_ns_uri;
      else if (!strcmp ("sql:", ns_pref) || !strcmp ("bif:", ns_pref))
        ns_uri = ns_pref;
      else
        sparyyerror_impl (sparp, ns_pref, "Undefined namespace prefix");
    }
  ns_uri_len = box_length (ns_uri) - 1;
  local_len = strlen (lname);
  res_len = ns_uri_len + local_len;
  res = box_dv_ubuf (res_len);
  memcpy (res, ns_uri, ns_uri_len);
  memcpy (res + ns_uri_len, lname, local_len);
  res[res_len] = '\0';
  return box_dv_uname_from_ubuf (res);
}


caddr_t spar_strliteral (sparp_t *sparp, const char *strg, int strg_is_long, char delimiter)
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
	    const char *bs_src		= "abfnrtv\\\'\"uU";
	    const char *bs_trans	= "\a\b\f\n\r\t\v\\\'\"\0\0";
            const char *bs_lengths	= "\2\2\2\2\2\2\2\2\2\2\6\012";
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
    "input:grab-depth", "input:grab-limit", NULL };

void
sparp_define (sparp_t *sparp, caddr_t param, ptrlong value_lexem_type, caddr_t value)
{
  switch (value_lexem_type)
    {
    case QNAME:
    value = sparp_expand_qname_prefix (sparp, value);
      break;
    case SPARQL_INTEGER:
      {
        const char **chk;
        for (chk = sparp_integer_defines; (NULL != chk[0]) && strcmp (chk[0], param); chk++) ;
        if (NULL == chk[0])
          spar_error (sparp, "Integer value %ld is specified for define %s");
        break;
      }
    }
  if ((7 < strlen (param)) && !memcmp (param, "output:", 7))
    {
      if (!strcmp (param, "output:valmode")) {
          sparp->sparp_env->spare_output_valmode_name = t_box_dv_uname_string (value); return; }
      if (!strcmp (param, "output:format")) {
          sparp->sparp_env->spare_output_format_name = t_box_dv_uname_string (value); return; }
    }
  if ((6 < strlen (param)) && !memcmp (param, "input:", 6))
    {
  if (!strcmp (param, "input:default-graph-uri") || !strcmp (param, "input:named-graph-uri"))
    {
  if (!strcmp (param, "input:default-graph-uri"))
    {
          SPART *new_precode = sparp_make_graph_precode ( sparp,
        spartlist (sparp, 2, SPAR_QNAME, t_box_dv_uname_string (value)),
        NULL );
          t_set_push (&(sparp->sparp_env->spare_default_graph_precodes), new_precode);
          sparp->sparp_env->spare_default_graphs_locked = 1;
      return;
    }
  if (!strcmp (param, "input:named-graph-uri"))
    {
      t_set_push (&(sparp->sparp_env->spare_named_graph_precodes),
        sparp_make_graph_precode (sparp,
          spartlist (sparp, 2, SPAR_QNAME, t_box_dv_uname_string (value)),
          NULL ) );
      sparp->sparp_env->spare_named_graphs_locked = 1;
      return;
    }
    }
  if (!strcmp (param, "input:storage"))
    {
      if (NULL != sparp->sparp_env->spare_storage_name)
        spar_error (sparp, "'define %.30s' is used more than once", param);
      sparp->sparp_env->spare_storage_name = t_box_dv_uname_string (value);
      return;
    }
  if (!strcmp (param, "input:grab-all") || !strcmp (param, "input:grab-iri") || !strcmp (param, "input:grab-var") ||
    !strcmp (param, "input:grab-depth") || !strcmp (param, "input:grab-limit") ||
    !strcmp (param, "input:grab-base") || !strcmp (param, "input:grab-destination") ||
    !strcmp (param, "input:grab-resolver") || !strcmp (param, "input:grab-loader") )
    {
      rdf_grab_config_t *rgc = &(sparp->sparp_env->spare_grab);
      const char *lock_pragma = NULL;
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
                t_set_push (&(rgc->rgc_vars), t_box_dv_uname_string (value+1));
              else
                t_set_push (&(rgc->rgc_consts), value);
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
          t_set_push (&(rgc->rgc_vars), varname);
      return;
    }
  if (!strcmp (param, "input:grab-depth"))
    {
      ptrlong val = unbox (value);
      if (0 >= val)
        spar_error (sparp, "define input:grab-depth should have positive integer value");
          rgc->rgc_depth = t_box_num_nonull (val);
      return;
    }
  if (!strcmp (param, "input:grab-limit"))
    {
      ptrlong val = unbox (value);
      if (0 >= val)
        spar_error (sparp, "define input:grab-limit should have positive integer value");
          rgc->rgc_limit = t_box_num_nonull (val);
          return;
        }
          if (!strcmp (param, "input:grab-base")) {
              rgc->rgc_base = t_box_dv_uname_string (value); return; }
          if (!strcmp (param, "input:grab-destination")) {
              rgc->rgc_destination = t_box_dv_uname_string (value); return; }
          if (!strcmp (param, "input:grab-resolver")) {
              rgc->rgc_resolver_name = t_box_dv_uname_string (value); return; }
          if (!strcmp (param, "input:grab-loader")) {
              rgc->rgc_loader_name = t_box_dv_uname_string (value); return; }
        }
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
          dk_set_push (opts_ptr, t_box_dv_short_string (value));
          dk_set_push (opts_ptr, t_box_dv_uname_string (param));
          return;
        }
    }
  if ((4 < strlen (param)) && !memcmp (param, "sql:", 4))
    {
      if (!strcmp (param, "sql:table-option")) {
          t_set_push (&(sparp->sparp_env->spare_common_sql_table_options), t_box_dv_uname_string (value));
          return; }
      if (!strcmp (param, "sql:select-option")) {
          t_set_push (&(sparp->sparp_env->spare_sql_select_options), t_box_dv_uname_string (value));
          return; }
    }
  spar_error (sparp, "Unsupported parameter '%.30s' in 'define'", param);
}

void
spar_selid_push (sparp_t *sparp)
{
  caddr_t selid = spar_mkid (sparp, "s");
  t_set_push (&(sparp->sparp_env->spare_selids), selid );
  spar_dbg_printf (("spar_selid_push () pushes %s\n", selid));
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

SPART * spar_gp_finalize (sparp_t *sparp)
{
  sparp_env_t *env = sparp->sparp_env;
  caddr_t orig_selid = env->spare_selids->data;
  dk_set_t req_membs = (dk_set_t) t_set_pop (&(env->spare_acc_req_triples));
  dk_set_t opt_membs = (dk_set_t) t_set_pop (&(env->spare_acc_opt_triples));
  dk_set_t filts = (dk_set_t) t_set_pop (&(env->spare_acc_filters));
  ptrlong subtype = (ptrlong) t_set_pop (&(env->spare_context_gp_subtypes));
  SPART *res;
  spar_dbg_printf (("spar_gp_finalize (..., %ld)\n", (long)subtype));
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
      left_group = spar_gp_finalize (sparp);
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
      left_group = spar_gp_finalize (sparp);
      req_membs = NULL;
      t_set_push (&req_membs, left_group);
      opt_membs = NULL;
      t_set_push (&opt_membs, last_opt);
    }
/* Plain composing of SPAR_GP tree node */
  res = spartlist (sparp, 7,
    SPAR_GP, subtype,
    /* opt members are at the first place in NCONC because there's a reverse in t_revlist_to_array */
    t_revlist_to_array (t_NCONC (opt_membs, req_membs)),
    t_revlist_to_array (filts),
    orig_selid,
    NULL, (ptrlong)(0) );
  spar_selid_pop (sparp);
  return res;
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

void spar_gp_add_filter (sparp_t *sparp, SPART *filt)
{
  t_set_push ((dk_set_t *)(&(sparp->sparp_env->spare_acc_filters->data)), filt);
}

void spar_gp_add_filter_for_graph (sparp_t *sparp, SPART *graph_expn, dk_set_t precodes, int suppress_filters_for_good_names)
{
  sparp_env_t *env = sparp->sparp_env;
  caddr_t varname;
  int precode_count = dk_set_length (precodes);
  SPART *graph_expn_copy, *filter;
  if (0 == precode_count)
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
  filter = spartlist (sparp, 4, SPAR_FUNCALL,
            box_dv_uname_string ("LONG::bif:position"), 2,
            t_list (2,
              graph_expn_copy,
              spartlist (sparp, 4, SPAR_FUNCALL,
                box_dv_uname_string ("SPECIAL::sql:RDF_MAKE_GRAPH_IIDS_OF_QNAMES"), 1,
                t_list (1,
          spartlist (sparp, 4, SPAR_FUNCALL,
            box_dv_uname_string ("SQLVAL::bif:vector"), precode_count,
            t_list_to_array (precodes) ) ) ) ) );
          spar_gp_add_filter (sparp, filter);
}

void
spar_gp_add_filter_for_named_graph (sparp_t *sparp)
{
  sparp_env_t *env = sparp->sparp_env;
  SPART *graph_expn = (SPART *)(env->spare_context_graphs->data);
  spar_gp_add_filter_for_graph (sparp, graph_expn, env->spare_named_graph_precodes, 0);
}

SPART **
spar_retvals_of_construct (sparp_t *sparp, SPART *ctor_gp)
{
  int triple_ctr, fld_ctr, var_count = 0, blank_count = 0;
  dk_set_t vars = NULL;
  dk_set_t var_iter, blank_iter;
  dk_set_t blanks = NULL;
  dk_set_t const_tvectors = NULL;
  dk_set_t var_tvectors = NULL;
  SPART *ctor_call;
/* Making lists of variables, blank nodes, fixed triples, triples with variables and blank nodes. */
  for (triple_ctr = BOX_ELEMENTS_INT (ctor_gp->_.gp.members); triple_ctr--; /* no step */)
    {
      SPART *triple = ctor_gp->_.gp.members[triple_ctr];
      SPART **tvector_args = (SPART **)t_list (6, NULL, NULL, NULL, NULL, NULL, NULL);
      SPART *tvector_call = spartlist (sparp, 4, SPAR_FUNCALL,
        box_dv_uname_string ("LONG::bif:vector"), (ptrlong)(6), tvector_args );
      int triple_is_const = 1;
      for (fld_ctr = 1; fld_ctr < SPART_TRIPLE_FIELDS_COUNT; fld_ctr++)
        {
          int paramctr;
          SPART *fld = triple->_.triple.tr_fields[fld_ctr];
          ptrlong fld_type = SPART_TYPE(fld);
          switch (fld_type)
            {
            case SPAR_VARIABLE:
              tvector_args [(fld_ctr-1)*2] = (SPART *)t_box_num_nonull (1);
              triple_is_const = 0;
              paramctr = var_count;
              for (var_iter = vars; NULL != var_iter; var_iter = var_iter->next)
                {
                  SPART *old_var = (SPART *)(var_iter->data);
                  paramctr--;
                  if (!strcmp (fld->_.var.vname, old_var->_.var.vname))
                    goto var_added;
                }
              t_set_push (&vars, fld);
              paramctr = var_count;
              var_count++;
var_added:              
              tvector_args [(fld_ctr-1)*2 + 1] = (SPART *)t_box_num_nonull (paramctr);
              break;
            case SPAR_BLANK_NODE_LABEL:
              tvector_args [(fld_ctr-1)*2] = (SPART *)t_box_num_nonull (2);
              triple_is_const = 0;
              paramctr = blank_count;
              for (blank_iter = blanks; NULL != blank_iter; blank_iter = blank_iter->next)
                {
                  SPART *old_blank = (SPART *)(blank_iter->data);
                  paramctr--;
                  if (!strcmp (fld->_.var.vname, old_blank->_.var.vname))
                    goto blank_added;
                }
              t_set_push (&blanks, fld);
              paramctr = blank_count;
              blank_count++;
blank_added:
              tvector_args [(fld_ctr-1)*2 + 1] = (SPART *)t_box_num_nonull (paramctr);
              break;
            case SPAR_QNAME:
            /*case SPAR_QNAME_NS:*/
              tvector_args [(fld_ctr-1)*2] = (SPART *)t_box_num_nonull (3);
              tvector_args [(fld_ctr-1)*2 + 1] = fld;
              break;
            default:
              if (SPAR_LIT != fld_type)
                triple_is_const = 0;
              tvector_args [(fld_ctr-1)*2] = (SPART *)t_box_num_nonull (3);
              tvector_args [(fld_ctr-1)*2 + 1] = fld;
              break;
            }
        }
      if (triple_is_const)
        t_set_push (&const_tvectors, tvector_call);
      else
        t_set_push (&var_tvectors, tvector_call);
    }
  ctor_call = spartlist (sparp, 4, SPAR_FUNCALL,
    box_dv_uname_string ("sql:SPARQL_CONSTRUCT"), (ptrlong)(3),
      t_list (3,
        spartlist (sparp, 4, SPAR_FUNCALL,
          box_dv_uname_string ("bif:vector"),
          dk_set_length (var_tvectors), t_list_to_array (var_tvectors) ),
        spartlist (sparp, 4, SPAR_FUNCALL,
          box_dv_uname_string ("LONG::bif:vector"),
          dk_set_length (vars), t_revlist_to_array (vars) ),
        spartlist (sparp, 4, SPAR_FUNCALL,
          box_dv_uname_string ("bif:vector"),
          dk_set_length (const_tvectors), t_list_to_array (const_tvectors) ) ) );
#if 1
  return (SPART **)t_list (1, ctor_call);
#else /* This was when list of retvals was also in use as a list of variables */
  t_set_push (&vars, ctor_call);
  return (SPART **)t_list_to_array (vars);
#endif
}

SPART **
spar_retvals_of_insert (sparp_t *sparp, SPART *graph_to_patch, SPART *ctor_gp)
{
  SPART **ctor_retval = spar_retvals_of_construct (sparp, ctor_gp);
  ctor_retval[0] = spartlist (sparp, 4, SPAR_FUNCALL,
    box_dv_uname_string ("sql:SPARQL_INSERT_DICT_CONTENT"), (ptrlong)(2),
      t_list (2, graph_to_patch, ctor_retval[0]) );
  return ctor_retval;
}

SPART **
spar_retvals_of_delete (sparp_t *sparp, SPART *graph_to_patch, SPART *ctor_gp)
{
  SPART **ctor_retval = spar_retvals_of_construct (sparp, ctor_gp);
  ctor_retval[0] = spartlist (sparp, 4, SPAR_FUNCALL,
    box_dv_uname_string ("sql:SPARQL_DELETE_DICT_CONTENT"), (ptrlong)(2),
      t_list (2, graph_to_patch, ctor_retval[0]) );
  return ctor_retval;
}

SPART **
spar_retvals_of_describe (sparp_t *sparp, SPART **retvals)
{
  int retval_ctr;
  dk_set_t vars = NULL;
  dk_set_t consts = NULL;
  SPART *descr_call;
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
  descr_call = spartlist (sparp, 4, SPAR_FUNCALL,
    box_dv_uname_string ("sql:SPARQL_DESCRIBE"), (ptrlong)(3),
      t_list (3,
        spartlist (sparp, 4, SPAR_FUNCALL,
          box_dv_uname_string ("LONG::bif:vector"),
          dk_set_length (vars), t_list_to_array (vars) ),
        spartlist (sparp, 4, SPAR_FUNCALL,
          box_dv_uname_string ("LONG::bif:vector"),
          dk_set_length (consts), t_list_to_array (consts) ),
        spartlist (sparp, 4, SPAR_FUNCALL, /*!!!TBD describe options will come here */
          box_dv_uname_string ("bif:vector"), 0, t_list(0) ) ) );
#if 1
  return (SPART **)t_list (1, descr_call);
#else /* This was when list of retvals was also in use as a list of variables */
  t_set_push (&vars, descr_call);
  return (SPART **)t_list_to_array (vars);
#endif
}

SPART *spar_make_top (sparp_t *sparp, ptrlong subtype, SPART **retvals,
  caddr_t retselid, SPART *pattern, SPART **order, caddr_t limit, caddr_t offset)
{
  dk_set_t src = NULL;
  SPART **sources;
#if 0 /* Old version with single default graph IRI */
  if (NULL != sparp->sparp_env->spare_default_graph_precode)
    t_set_push (&src, spartlist (sparp, 2, FROM_L,
        sparp_tree_full_copy (sparp, sparp->sparp_env->spare_default_graph_precode, NULL) ) );
#else
  DO_SET(SPART *, precode, &(sparp->sparp_env->spare_default_graph_precodes))
    {
      t_set_push (&src, spartlist (sparp, 2, FROM_L, sparp_tree_full_copy (sparp, precode, NULL)));
    }
  END_DO_SET()
#endif
  DO_SET(SPART *, precode, &(sparp->sparp_env->spare_named_graph_precodes))
    {
      t_set_push (&src, spartlist (sparp, 2, NAMED_L, sparp_tree_full_copy (sparp, precode, NULL)));
    }
  END_DO_SET()
  sources = (SPART **)t_revlist_to_array (src);
  return spartlist (sparp, 14, SPAR_REQ_TOP, subtype,
    sparp->sparp_env->spare_output_valmode_name,
    sparp->sparp_env->spare_output_format_name,
    t_box_copy (sparp->sparp_env->spare_storage_name),
    retvals, retselid,
    sources, pattern, order,
    limit, offset, NULL, (ptrlong)(0) );
}


static ptrlong usage_natural_restrictions[SPART_TRIPLE_FIELDS_COUNT] = {
  SPART_VARR_IS_REF | SPART_VARR_IS_IRI | SPART_VARR_NOT_NULL,	/* graph	*/
  SPART_VARR_IS_REF | SPART_VARR_NOT_NULL,			/* subject	*/
  SPART_VARR_IS_REF | SPART_VARR_NOT_NULL,			/* predicate	*/
  SPART_VARR_NOT_NULL };					/* object	*/

SPART *spar_make_triple (sparp_t *sparp, SPART *graph, SPART *subject, SPART *predicate, SPART *object)
{
  caddr_t key;
  sparp_env_t *env = sparp->sparp_env;
  SPART *triple;
  int fctr;
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
      dflts = env->spare_default_graph_precodes;
      if ((NULL != dflts) && (NULL == dflts->next))
        { /* If there's only one default graph then we can cheat and optimize the query a little bit by adding a restriction to the variable */
          SPART *single_dflt = (SPART *)(dflts->data);
          if (SPAR_FUNCALL == SPART_TYPE (single_dflt))	 /* FROM iriref OPTION (...) case */
        {
              SPART *eq;
              graph = spar_make_blank_node (sparp, spar_mkid (sparp, "_:graph"), 1);
              eq = spartlist (sparp, 3, BOP_EQ, sparp_tree_full_copy (sparp, graph, NULL), sparp_tree_full_copy (sparp, single_dflt, NULL));
              spar_gp_add_filter (sparp, eq);
	      graph->_.var.rvr.rvrRestrictions |= SPART_VARR_FIXED | SPART_VARR_IS_REF | SPART_VARR_NOT_NULL;
              graph->_.var.rvr.rvrFixedValue = (caddr_t)sparp_tree_full_copy (sparp, single_dflt->_.funcall.argtrees[0], NULL);
              break;
            }
	/* Single FROM iriref without sponge options */
          graph = sparp_tree_full_copy (sparp, single_dflt, NULL);
          break;
	}
      graph = spar_make_blank_node (sparp, spar_mkid (sparp, "_:graph"), 1);
      spar_gp_add_filter_for_graph (sparp, graph, dflts, 0);
      break;
    }
  if (SPAR_IS_BLANK_OR_VAR (graph))
    graph->_.var.selid = env->spare_selids->data;
  if (NULL == subject)
    subject = (SPART *)t_box_copy_tree (env->spare_context_subjects->data);
  if (NULL == predicate)
    predicate = (SPART *)t_box_copy_tree (env->spare_context_predicates->data);
  if (NULL == object)
    object = (SPART *)t_box_copy_tree (env->spare_context_objects->data);
  key = t_box_sprintf (0x100, "%s-t%d", env->spare_selids->data, sparp->sparp_key_gen);
  sparp->sparp_key_gen += 1;
  triple = spartlist (sparp, 12, SPAR_TRIPLE,
    graph, subject, predicate, object,
    env->spare_selids->data, key, NULL,
    NULL, NULL, NULL, NULL );
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
            {
              if (0 <= dk_set_position_of_string (env->spare_good_graph_varnames, fld->_.var.vname))
                t_set_push (&(env->spare_good_graph_varnames), fld->_.var.vname);
            }
        }
      if ((env->spare_grab.rgc_all) && (SPART_TRIPLE_PREDICATE_IDX != fctr))
        {
          if ((SPAR_VARIABLE == ft) && !(SPART_VARR_GLOBAL & fld->_.var.rvr.rvrRestrictions))
            t_set_push (&(env->spare_grab.rgc_vars), t_box_dv_uname_string (fld->_.var.vname));
          else if (SPAR_QNAME == ft)
            t_set_push (&(env->spare_grab.rgc_consts), fld->_.lit.val);
        }
    }
  return triple;
}

SPART *spar_make_variable (sparp_t *sparp, caddr_t name)
{
  sparp_env_t *env = sparp->sparp_env;
  SPART *res;
  int is_global = SPART_VARNAME_IS_GLOB(name);
  caddr_t selid;
#ifdef DEBUG
  caddr_t rvr_list_test[] = {SPART_RVR_LIST_OF_NULLS};
  if (sizeof (rvr_list_test) != sizeof (rdf_val_range_t))
    GPF_T; /* Don't forget to add NULLS to SPART_RVR_LIST_OF_NULLS when adding fields to rdf_val_range_t */
#endif
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
        return spartlist (sparp, 4, SPAR_LIT, 1, type, NULL);
      if (!strcmp ("false", strg))
        return spartlist (sparp, 4, SPAR_LIT, 0, type, NULL);
      goto cannot_cast;
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
  if (uname_xmlschema_ns_uri_hash_string == type)
    {
      return spartlist (sparp, 4, SPAR_LIT, strg, type, NULL);
    }
  return spartlist (sparp, 4, SPAR_LIT, strg, type, NULL);

do_sql_cast:
  tgt_dtp_tree = (sql_tree_tmp *)t_list (3, (ptrlong)tgt_dtp, 0, 0);
  parsed_value = box_cast ((caddr_t *)(sparp->sparp_sparqre->sparqre_qi), strg, tgt_dtp_tree, DV_STRING);
  res = spartlist (sparp, 4, SPAR_LIT, t_full_box_copy_tree (parsed_value), type, NULL);
  dk_free_tree (parsed_value);
  return res;

cannot_cast:
  sparyyerror_impl (sparp, strg, "The string representation can not be converted to a valid typed value");
  return NULL;
}

SPART *sparp_make_graph_precode (sparp_t *sparp, SPART *iriref, SPART **options)
{
  dk_set_t *opts_ptr = &(sparp->sparp_env->spare_common_sponge_options);
  SPART **mixed_options;
  int common_count;
  if ((NULL == options) && (0 > dk_set_position_of_string (opts_ptr[0], "get:soft")))
    return iriref;
  common_count = dk_set_length (opts_ptr[0]);
  if (0 < common_count)
    {
      int ctr;
      SPART **mixed_tail = mixed_options = (SPART **)t_alloc_box (common_count * sizeof (SPART *), DV_ARRAY_OF_POINTER);
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
    }
  else
    mixed_options = options;
  return spartlist (sparp, 4, SPAR_FUNCALL, t_box_dv_short_string ("sql:RDF_SPONGE_UP"),
    (ptrlong)2,
    (SPART **)t_list (2,
       iriref,
       spartlist (sparp, 4, SPAR_FUNCALL, t_box_dv_short_string ("bif:vector"),
         (ptrlong)(BOX_ELEMENTS (mixed_options)), mixed_options ) ) );
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
      ptrlong param_ctr = 0;
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


const char *spart_dump_opname (ptrlong opname, int is_op)
{

  if (is_op)
    switch (opname)
    {
    case BOP_AND: return "boolean operation 'AND'";
    case BOP_OR: return "boolean operation 'OR'";
    case BOP_NOT: return "boolean operation 'NOT'";
    case BOP_EQ: return "boolean operation '='";
    case BOP_NEQ: return "boolean operation '!='";
    case BOP_LT: return "boolean operation '<'";
    case BOP_LTE: return "boolean operation '<='";
    case BOP_GT: return "boolean operation '>'";
    case BOP_GTE: return "boolean operation '>='";
    /*case BOP_LIKE: Like is built-in in SPARQL, not a BOP! return "boolean operation 'like'"; */
    case BOP_SAME: return "boolean operation '=='";
    case BOP_NSAME: return "boolean operation '!=='";
    case BOP_PLUS: return "arithmetic operation '+'";
    case BOP_MINUS: return "arithmetic operation '-'";
    case BOP_TIMES: return "arithmetic operation '*'";
    case BOP_DIV: return "arithmetic operation 'div'";
    case BOP_MOD: return "arithmetic operation 'mod'";
    }

  switch (opname)
    {
    case _LBRA: return "quad mapping parent group name";
    case ASC_L: return "ascending order";
    case ASK_L: return "ASK result-mode";
    case BOUND_L: return "BOUND builtin";
    case CONSTRUCT_L: return "CONSTRUCT result-mode";
    case CREATE_L: return "quad mapping name";
    case DATATYPE_L: return "DATATYPE builtin";
    case DESC_L: return "descending";
    case DESCRIBE_L: return "DESCRIBE result-mode";
    case DISTINCT_L: return "SELECT DISTINCT result-mode";
    case false_L: return "false boolean";
    case FILTER_L: return "FILTER";
    case FROM_L: return "FROM";
    case GRAPH_L: return "GRAPH gp";
    case IRI_L: return "IRI builtin";
    case IN_L: return "IN";
    case isBLANK_L: return "isBLANK builtin";
    case isIRI_L: return "isIRI builtin";
    case isLITERAL_L: return "isLITERAL builtin";
    case isURI_L: return "isURI builtin";
    case LANG_L: return "LANG builtin";
    case LANGMATCHES_L: return "LANGMATCHES builtin";
    case LIKE_L: return "LIKE";
    case LIMIT_L: return "LIMIT";
    case NAMED_L: return "NAMED";
    case NIL_L: return "NIL";
    case OBJECT_L: return "OBJECT";
    case OFFSET_L: return "OFFSET";
    case OPTIONAL_L: return "OPTIONAL gp";
    case ORDER_L: return "ORDER";
    case PREDICATE_L: return "PREDICATE";
    case PREFIX_L: return "PREFIX";
    case REGEX_L: return "REGEX builtin";
    case SELECT_L: return "SELECT result-mode";
    case STR_L: return "STR builtin";
    case SUBJECT_L: return "SUBJECT";
    case true_L: return "true boolean";
    case UNION_L: return "UNION gp";
    case WHERE_L: return "WHERE gp";

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
  }
  return NULL;
}


char *spart_dump_addr (void *addr)
{
  return NULL;
}


void spart_dump_long (void *addr, dk_session_t *ses, int is_op)
{
  if (!IS_BOX_POINTER(addr))
    {
      const char *op_descr = spart_dump_opname((ptrlong)(addr), is_op);
      if (NULL != op_descr)
	{
	  SES_PRINT (ses, op_descr);
	  return;
	}
    }
  else
    {
      char *addr_descr = spart_dump_addr(addr);
      if (NULL != addr_descr)
	{
	  SES_PRINT (ses, addr_descr);
	  return;
	}
    }
  {
    char buf[30];
    sprintf (buf, "LONG %ld", unbox (addr));
    SES_PRINT (ses, buf);
    return;
  }
}

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
	      spart_dump (tree->_.alias.arg, ses, indent+2, "VALUE", 0);
	      spart_dump (tree->_.alias.aname, ses, indent+2, "ALIAS NAME", 0);
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
	      int ctr;
	      spart_dump (tree->_.funcall.qname, ses, indent+2, "FUNCTION NAME", 0);
	      for (ctr = 0; ctr < tree->_.funcall.argcount; ctr++)
		{
		  spart_dump (tree->_.funcall.argtrees[ctr], ses, indent+2, "ARGUMENT", -1);
		}
	      break;
	    }
	  case SPAR_GP:
            {
              int eq_count, eq_ctr;
	      sprintf (buf, "GRAPH PATTERN:");
	      SES_PRINT (ses, buf);
	      spart_dump_long ((void *)(tree->_.gp.subtype), ses, -1);
	      spart_dump (tree->_.gp.members, ses, indent+2, "MEMBERS", -2);
	      spart_dump (tree->_.gp.filters, ses, indent+2, "FILTERS", -2);
	      spart_dump (tree->_.gp.selid, ses, indent+2, "SELECT ID", 0);
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
              int eq_count, eq_ctr;
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
	      sprintf (buf, "\nEQUIVS:");
	      SES_PRINT (ses, buf);
              eq_count = tree->_.req_top.equiv_count;
	      for (eq_ctr = 0; eq_ctr < eq_count; eq_ctr++)
                {
		  sparp_equiv_t *eq = tree->_.req_top.equivs[eq_ctr];
                  int varname_count, varname_ctr;
                  int var_ctr;
		  session_buffered_write_char ('\n', ses);
		  for (ctr = indent+2; ctr--; /*no step*/ )
		    session_buffered_write_char (' ', ses);
                  if (NULL == eq)
                    {
	              sprintf (buf, "#%d: merged and destroyed", eq_ctr);
	              SES_PRINT (ses, buf);
                      continue;
                    }
	          sprintf (buf, "#%d: %s( %d subv, %d recv, %d gspo, %d const:", eq_ctr,
                    (eq->e_deprecated ? "deprecated " : ""),
		    BOX_ELEMENTS_INT_0(eq->e_subvalue_idxs), BOX_ELEMENTS_INT_0(eq->e_receiver_idxs),
	            (int)(eq->e_gspo_uses), (int)(eq->e_const_reads) );
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
	      break;
	    }
	  case SPAR_VARIABLE:
	    {
	      sprintf (buf, "VARIABLE:");
	      SES_PRINT (ses, buf);
              spart_dump_rvr (ses, &(tree->_.var.rvr));
              if (NULL != tree->_.var.tabid)
                {
                  static const char *field_full_names[] = {"graph", "subject", "predicate", "object"};
                  sprintf (buf, " (%s)", field_full_names[tree->_.var.tr_idx]); SES_PRINT (ses, buf);
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
	      spart_dump (tree->_.triple.tr_graph, ses, indent+2, "GRAPH", -1);
	      spart_dump (tree->_.triple.tr_subject, ses, indent+2, "SUBJECT", -1);
	      spart_dump (tree->_.triple.tr_predicate, ses, indent+2, "PREDICATE", -1);
	      spart_dump (tree->_.triple.tr_object, ses, indent+2, "OBJECT", -1);
	      spart_dump (tree->_.triple.selid, ses, indent+2, "SELECT ID", 0);
	      spart_dump (tree->_.triple.tabid, ses, indent+2, "TABLE ID", 0);
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

#ifdef DEBUG
sparp_t * dbg_curr_sparp;
#endif

sparp_t * sparp_query_parse (char * str, spar_query_env_t *sparqre)
{
  wcharset_t *query_charset = sparqre->sparqre_query_charset;
  t_NEW_VAR (sparp_t, sparp);
  t_NEW_VARZ (sparp_env_t, spare);
#ifdef DEBUG
  dbg_curr_sparp = sparp;
#endif
  memset (sparp, 0, sizeof (sparp_t));
  sparp->sparp_sparqre = sparqre;
  if ((NULL == sparqre->sparqre_cli) && (NULL != sparqre->sparqre_qi))
    sparqre->sparqre_cli = sparqre->sparqre_qi->qi_client;
  sparp->sparp_env = spare;
  sparp->sparp_err_hdr = t_box_dv_short_string ("SPARQL compiler");
  if ((NULL == query_charset) /*&& (!sparqre->xqre_query_charset_is_set)*/)
    {
      if (NULL != sparqre->sparqre_qi)
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
      sparp_rewrite_all (sparp);
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

extern sparp_t *
sparp_clone_for_variant (sparp_t *sparp)
{
#define ENV_COPY(field) env_copy->field = env->field
#define ENV_BOX_COPY(field) env_copy->field = t_box_copy (env->field)
#define ENV_SPART_COPY(field) env_copy->field = (SPART *)t_box_copy_tree ((caddr_t)(env->field))
  s_node_t *iter;
  sparp_env_t *env = sparp->sparp_env;
  t_NEW_VAR (sparp_t, sparp_copy);
  t_NEW_VARZ (sparp_env_t, env_copy);
  memcpy (sparp_copy, sparp, sizeof (sparp_t));
  sparp_copy->sparp_env = env_copy;
  ENV_BOX_COPY (spare_output_valmode_name);
  ENV_BOX_COPY (spare_output_format_name);
  ENV_BOX_COPY (spare_storage_name);
#if 0 /* These will be used when libraries of inference rules are introduced. */
    struct sparp_env_s *spare_parent_env;		/*!< Pointer to parent env */
    id_hash_t *		spare_fundefs;			/*!< In-scope function definitions */
    id_hash_t *		spare_vars;			/*!< Known variables as keys, equivs as values */
    id_hash_t *		spare_global_bindings;		/*!< Dictionary of global bindings, varnames as keys, default value expns as values. DV_DB_NULL box for no expn! */
#endif
  if (0 != env->spare_equiv_count)
    spar_internal_error (sparp, "sparp_" "clone_for_variant(): can't clone when equivs are built");
  /*... thus no copy for spare_equivs and spare_equiv_count */
  /* No copy for spare_grab_vars */
  env_copy->spare_common_sponge_options = t_set_copy (env->spare_common_sponge_options);
  DO_SET_WRITABLE (SPART *, opt, iter, &(env_copy->spare_common_sponge_options))
    {
      iter->data = t_box_copy_tree ((caddr_t)opt);
    }
  END_DO_SET()
#if 0 /* Old variant with single graph */
  ENV_SPART_COPY (spare_default_graph_precode);
#else
  env_copy->spare_default_graph_precodes = t_set_copy (env->spare_default_graph_precodes);
  DO_SET_WRITABLE (SPART *, precode, iter, &(env_copy->spare_default_graph_precodes))
    {
      iter->data = t_box_copy_tree ((caddr_t)precode);
    }
  END_DO_SET()
#endif
  env_copy->spare_named_graph_precodes = t_set_copy (env->spare_named_graph_precodes);
  DO_SET_WRITABLE (SPART *, precode, iter, &(env_copy->spare_named_graph_precodes))
    {
      iter->data = t_box_copy_tree ((caddr_t)precode);
    }
  END_DO_SET()
  ENV_COPY (spare_default_graphs_locked);
  ENV_COPY (spare_named_graphs_locked);
  return sparp_copy;
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
  sparp = sparp_query_parse (str, sparqre);
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
      /* ssg_free (ssg); */
      return;
    }
  /* ssg_free (ssg); */
  session_buffered_write (ssg.ssg_out, sparqre->sparqre_tail_sql_text, strlen (sparqre->sparqre_tail_sql_text));
  session_buffered_write_char (0 /*YY_END_OF_BUFFER_CHAR*/, ssg.ssg_out); /* First terminator */
  session_buffered_write_char (0 /*YY_END_OF_BUFFER_CHAR*/, ssg.ssg_out); /* Second terminator. Most of Lex-es need two! */
  res = strses_string (ssg.ssg_out);
#ifdef SPARQL_DEBUG
  printf ("\nsparp_compile_subselect() done: %s", res);
#endif
  strses_free (ssg.ssg_out);
  ssg.ssg_out = NULL;
  /* ssg_free (ssg); */
  sparqre->sparqre_compiled_text = t_box_copy (res);
  dk_free_box (res);
}


caddr_t
bif_sparql_explain (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  ptrlong param_ctr = 0;
  spar_query_env_t sparqre;
  sparp_t * sparp;
  caddr_t str = bif_string_arg (qst, args, 0, "sparql_explain");
  dk_session_t *res;
  caddr_t err = NULL;
  MP_START ();
  memset (&sparqre, 0, sizeof (spar_query_env_t));
  sparqre.sparqre_param_ctr = &param_ctr;
  sparqre.sparqre_qi = (query_instance_t *) qst;
  sparp = sparp_query_parse (str, &sparqre);
  if (NULL != sparqre.sparqre_catched_error)
    {
      MP_DONE ();
      sqlr_resignal (sparqre.sparqre_catched_error);
    }
  res = strses_allocate ();
  spart_dump (sparp->sparp_expr, res, 0, "QUERY", -1);
  MP_DONE ();
  return (caddr_t)res;
}


caddr_t
bif_sparql_to_sql_text (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  ptrlong param_ctr = 0;
  spar_query_env_t sparqre;
  sparp_t * sparp;
  caddr_t str = bif_string_arg (qst, args, 0, "sparql_to_sql_text");
  caddr_t err = NULL;
  spar_sqlgen_t ssg;
  sql_comp_t sc;
  MP_START ();
  memset (&sparqre, 0, sizeof (spar_query_env_t));
  sparqre.sparqre_param_ctr = &param_ctr;
  sparqre.sparqre_qi = (query_instance_t *) qst;
  sparp = sparp_query_parse (str, &sparqre);
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
      /* ssg_free (ssg); */
      MP_DONE ();
      sqlr_resignal (sparqre.sparqre_catched_error);
    }
  /* ssg_free (ssg); */
  MP_DONE ();
  return (caddr_t)(ssg.ssg_out);
}


caddr_t
bif_sparql_lex_analyze (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t str = bif_string_arg (qst, args, 0, "sparql_lex_analyze");
  return spar_query_lex_analyze (str, QST_CHARSET(qst));
}

caddr_t
bif_sprintff_intersect (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t f1 = bif_string_or_uname_arg (qst, args, 0, "__sprintff_intersect");
  caddr_t f2 = bif_string_or_uname_arg (qst, args, 1, "__sprintff_intersect");
  long ignore_cache = bif_long_arg (qst, args, 2, "__sprintff_intersect");
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
  caddr_t res;
  sec_check_dba ((query_instance_t *)qst, "__sprintff_like"); /* To prevent attack by likeing garbage in order to run out of memory. */
  return sprintff_like (f1, f2);
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
  rdf_ds_load_all();
  bif_define ("sparql_to_sql_text", bif_sparql_to_sql_text);
  bif_define ("sparql_explain", bif_sparql_explain);
  bif_define ("sparql_lex_analyze", bif_sparql_lex_analyze);
  bif_define ("__sprintff_intersect", bif_sprintff_intersect);
  bif_define ("__sprintff_like", bif_sprintff_like);
#ifdef DEBUG
  bif_define ("sparql_lex_test", bif_sparql_lex_test);
#endif
}

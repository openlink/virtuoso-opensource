/*
 *  $Id$
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

#include "http.h" /* for isplainURIchar() and the like */
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
#include "sqlbif.h" /* for bif_metadata_t */
#include "sqlcmps.h"
#include "sparql.h"
#include "sparql2sql.h"
#include "xml_ecm.h" /* for sorted dict, ECM_MEM_NOT_FOUND etc. */
#ifdef __cplusplus
extern "C" {
#endif
#include "sparql_p.h"
#ifdef __cplusplus
}
#endif

#include "sqlo.h" /* to load rdfinf.h :) */
#include "rdfinf.h"
#include "rdf_mapping_jso.h"
#include "xpf.h"
#include "xqf.h"

#ifdef _SSL
#include <openssl/md5.h>
#define MD5Init   MD5_Init
#define MD5Update MD5_Update
#define MD5Final  MD5_Final
#else
#include "util/md5.h"
#endif /* _SSL */

#ifdef MALLOC_DEBUG
const char *spartlist_impl_file="???";
int spartlist_impl_line;
#endif

#ifdef DEBUG
#define SPAR_ERROR_DEBUG
#endif

long mp_sparql_cap = ~0L;

#define SPARP_SAVED_MP_SIZE_CAP mem_pool_size_cap_t saved_mp_size_cap
#define SPARP_TWEAK_MP_SIZE_CAP(mp,sparqre) do {\
  saved_mp_size_cap = mp->mp_size_cap; \
  if (mp_sparql_cap != ~0L) \
    mp->mp_size_cap.cbk = sparp_mp_sparql_cap_cbk; \
  mp->mp_size_cap.limit = mp_sparql_cap; \
  mp->mp_size_cap.cbk_env = sparqre; \
} while (0)

#define SPARP_RESTORE_MP_SIZE_CAP(mp) mp->mp_size_cap = saved_mp_size_cap;

const char *sparp_dump_weird_query_path = "virtuoso_sparql_weird_queries.log";

void
sparp_dump_weird_query (spar_query_env_t *sparqre, const char *reason, char *md5_ret_buf)
{
  char digest_hex[16*2+1];
  FILE *dump_file;
  const char *txt, *sqltxt;
  static dk_mutex_t *sparp_dump_weird_query_mtx;
  if (NULL == sparp_dump_weird_query_mtx)
    sparp_dump_weird_query_mtx = mutex_allocate();
  txt = sparqre->sparqre_dbg_query_text;
  if (NULL == txt)
    txt = "(SPARQL query text is not available at the moment of writing the dump)";
  if (NULL != sparqre->sparqre_super_sc)
    {
      sqltxt = sparqre->sparqre_super_sc->sc_text;
      if (NULL == sqltxt)
        sqltxt = "(SQL text is not available at the moment of writing the dump)";
    }
  else
    sqltxt = "(SPARQL compiler is called directly, not via SQL compiler, so SQL text is not available)";
    {
      MD5_CTX ctx;
      unsigned char digest[16];
      int inx;
      long msec = get_msec_real_time ();
      memset (&ctx, 0, sizeof (MD5_CTX));
      MD5Init (&ctx);
      MD5Update (&ctx, (unsigned char *) txt, strlen(txt));
      MD5Update (&ctx, (unsigned char *) txt, strlen(sqltxt));
      MD5Update (&ctx, (unsigned char *) (&msec), sizeof (msec));
      MD5Final (digest, &ctx);
      for (inx = 0; inx < sizeof (digest); inx++)
        {
          unsigned c = (unsigned) digest[inx];
          digest_hex[inx * 2] = "0123456789abcdef"[0xf & (c >> 4)];
          digest_hex[inx * 2 + 1] = "0123456789abcdef"[c & 0xf];
        }
      digest_hex[sizeof (digest) * 2] = '\0';
      if (NULL != md5_ret_buf)
        strcpy (md5_ret_buf, digest_hex);
    }
  mutex_enter (sparp_dump_weird_query_mtx);
  dump_file = fopen (sparp_dump_weird_query_path, "a");
  if (NULL != dump_file)
    {
      fprintf (dump_file, "\n\n-----8<-----\n\nProblem report ID: %s\nThe SPARQL query is dumped: %s\n\nSPARQL query text:\n%s\n\nSurrounding SQL query text:%s\n", digest_hex, reason, txt, sqltxt);
      fclose (dump_file);
    }
  mutex_leave (sparp_dump_weird_query_mtx);
}

void
sparp_mp_sparql_cap_cbk (mem_pool_t *mp, void *cbk_env)
{
  char digest_hex[16*2+1];
  spar_query_env_t *sparqre = (spar_query_env_t *)(mp->mp_size_cap.cbk_env);
  sparp_dump_weird_query (sparqre, "SPARQL compiler ran out of temporary memory", digest_hex);
  if (NULL != sparqre->sparqre_dbg_sparp)
    spar_error (sparqre->sparqre_dbg_sparp, "SPARQL compiler ran out of temporary memory, report saved in %s, report ID %s", sparp_dump_weird_query_path, digest_hex);
}

/*#define SPAR_ERROR_DEBUG*/

extern void jsonyyerror_impl(const char *s);

size_t
spart_count_specific_elems_by_type (ptrlong type)
{
  static SPART sample;
  switch (type)
    {
    case SPAR_ALIAS:		return sizeof (sample._.alias);
    case SPAR_BLANK_NODE_LABEL:	return sizeof (sample._.bnode);
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
    case SPAR_WHERE_MODIFS:	return sizeof (sample._.wm);
    case SPAR_SERVICE_INV:	return sizeof (sample._.sinv);
    case SPAR_BINDINGS_INV:	return sizeof (sample._.binv);
    case SPAR_DEFMACRO:		return sizeof (sample._.defmacro);
    case SPAR_MACROCALL:	return sizeof (sample._.macrocall);
    case SPAR_MACROPU:		return sizeof (sample._.macropu);
    case ORDER_L:		return sizeof (sample._.oby);
    case SPAR_PPATH:		return sizeof (sample._.ppath);
    case BOP_NOT:
    case BOP_OR: case BOP_AND:
    case BOP_PLUS: case BOP_MINUS: case BOP_TIMES: case BOP_DIV: case BOP_MOD:
    case BOP_EQ: case SPAR_BOP_EQNAMES: case SPAR_BOP_EQ_NONOPT: case BOP_NEQ: case BOP_LT: case BOP_LTE: case BOP_GT: case BOP_GTE:
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
        {
          va_end (ap);
          spar_internal_error (sparp, "length mismatch in spartlist()");
        }
    }
  else
    {
      if (spart_count_specific_elems_by_type (type) != sizeof (caddr_t) * (length-1))
        {
          va_end (ap);
          spar_internal_error (sparp, "length mismatch in spartlist()");
        }
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
    {
      va_end (ap);
      spar_internal_error (sparp, "length mismatch in spartlist()");
    }
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
	{
	  if (DV_STRINGP (fld->_.lit.val))
	    return t_box_sprintf (210, "%.200s", fld->_.lit.val);
	  else
	    {
	      caddr_t err = NULL, ret, str;
	      str = box_cast_to (NULL, fld->_.lit.val, DV_TYPE_OF (fld->_.lit.val), DV_SHORT_STRING, NUMERIC_MAX_PRECISION, NUMERIC_MAX_SCALE, &err);
	      if (!err && str)
		ret = t_box_sprintf (210, "%.200s", str);
              else
                {
		  dk_free_tree (err);
		  ret = t_box_sprintf (210, "Value cannot be printed");
  	        }
	      dk_free_box (str);
	      return ret;
	    }
	}
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

int32 enable_spar_logfile = 0;

void
spar_log_error_to_file (sparp_t *sparp, const char *msg, const char *type)
{
  char filename[100];
  FILE *f;
  static int log_ctr = 0;
  if (!enable_spar_logfile || 1000 <= log_ctr++)
    return;
  sprintf (filename, "error_report_%03d_%s.txt", log_ctr, type);
  f = fopen (filename, "w");
  if (NULL == f)
    return;
  fprintf (f, "Internal error report\n\n"
"Before sending the file to support, please check it for any sensitive information.\n"
"An application may compose a query by imprinting some values into a template; these values may come from confidential data.\n"
"If so, please replace these values with some similar fake values, with some caution:\n"
"1. When one sensitive value appears in few places, please replace it with the same fake value in all those places;\n"
"2. Replace different sensitive values with different fake values.\n"
"3. Erase the following line before sending:\n"
"*** This report is not edited by hands ***\n\n");
  fprintf (f, "Message: %s\n", msg);
  if (NULL == sparp)
    {
      fprintf (f, "sparp is NULL\n");
    }
  else
    {
      fprintf (f, "sparp_err_hdr:\n%s\n\n", ((NULL != sparp->sparp_err_hdr) ? sparp->sparp_err_hdr : "(NULL)"));
      if (NULL != sparp->sparp_sparqre->sparqre_exec_user)
        fprintf (f, "sparqre_exec_user:%s\n", sparp->sparp_sparqre->sparqre_exec_user->usr_name);
      fprintf (f, "sparp_text:\n%s\n\n", sparp->sparp_text);
      fprintf (f, "sparqre_compiled_text:\n%s\n\n", sparp->sparp_sparqre->sparqre_compiled_text);
      if (NULL != sparp->sparp_sparqre->sparqre_super_sc)
        fprintf (f, "sc_text:\n%s\n\n", sparp->sparp_sparqre->sparqre_super_sc->sc_text);
    }
  fclose (f);
}

void
spar_error (sparp_t *sparp, const char *format, ...)
{
  va_list ap;
  caddr_t msg, err;
  va_start (ap, format);
  msg = box_vsprintf (1500, format, ap);
  va_end (ap);
  if (NULL == sparp)
    err = srv_make_new_error ("37000", "SP031", "SPARQL generic error: %.1500s", msg);
  else
    err = srv_make_new_error ("37000", "SP031", "%.400s: %.1500s",
      sparp->sparp_err_hdr, msg );
  dk_free_tree (msg);
  sqlr_resignal (err);
}

void
spar_audit_error (sparp_t *sparp, const char *format, ...)
{
#ifdef SPAR_ERROR_DEBUG
  const char *txt;
#endif
  va_list ap;
  caddr_t msg;
  va_start (ap, format);
  msg = t_box_vsprintf (1500, format, ap);
  va_end (ap);
  spar_log_error_to_file(sparp, msg, "spar_audit");
#ifdef SPAR_ERROR_DEBUG
  txt = ((NULL != sparp) ? sparp->sparp_text : "(no text, sparp is NULL)");
  printf ("Internal SPARQL audit error %s while processing\n-----8<-----\n%s\n-----8<-----\n", msg, txt);

  if (sparp->sparp_internal_error_runs_audit)
    return;
#endif
  sqlr_new_error ("37000", "SP039",
    "%.400s: Internal error (reported by audit): %.1500s",
    ((NULL != sparp && sparp->sparp_err_hdr) ? sparp->sparp_err_hdr : "SPARQL"), msg);
}


void
spar_internal_error (sparp_t *sparp, const char *msg)
{
#ifdef SPAR_ERROR_DEBUG
  const char *txt;
  txt = ((NULL != sparp) ? sparp->sparp_text : "(no text, sparp is NULL)");
  printf ("Internal SPARQL error %s while processing\n-----8<-----\n%s\n-----8<-----\n", msg, txt);
  if ((NULL != sparp) && !sparp->sparp_internal_error_runs_audit)
    {
      sparp->sparp_internal_error_runs_audit = 1;
      sparp_audit_mem (sparp);
      sparp_equiv_audit_all (sparp, SPARP_EQUIV_AUDIT_NOBAD);
      sparp->sparp_internal_error_runs_audit = 0;
    }
#endif

  spar_log_error_to_file (sparp, msg, "spar_internal");

  sqlr_new_error ("37000", "SP031",
      "%.400s: Internal error: %.1500s", ((NULL != sparp && sparp->sparp_err_hdr) ? sparp->sparp_err_hdr : "SPARQL"), msg);
}

#ifdef SPARQL_DEBUG
void
sparp_debug_weird (sparp_t *sparp, const char *file, int line, const char *msg)
{
  dbg_printf (("\n%s:%d weird: %s", file, line, msg));
}
#endif

void
spar_error_if_unsupported_syntax_imp (sparp_t *sparp, int feature_in_use, const char *feature_name)
{
  if (NULL != sparp->sparp_env->spare_context_sinvs)
    {
      SPART *sinv = (SPART *)(sparp->sparp_env->spare_context_sinvs->data);
      const char *msg_tail = "";
      if ((SSG_SD_NEED_LOAD_SERVICE_DATA & sparp->sparp_permitted_syntax) && (SPAR_QNAME == SPART_TYPE (sinv->_.sinv.endpoint)))
        {
          client_connection_t *cli = sparp->sparp_sparqre->sparqre_cli;
          if (NULL != cli)
            connection_set (cli, box_dv_uname_string ("SPARQL_endpoint_to_load_service_metadata"), box_dv_short_string (sinv->_.sinv.endpoint->_.qname.val));
          msg_tail = "; execute SPARQL LOAD SERVICE ... DATA and re-try";
        }
      spar_error (sparp, "The support of %.200s syntax is not enabled for the %.300s (bit 0x%x is not set)%.300s",
        feature_name, spar_sinv_naming (sparp, sinv), feature_in_use, msg_tail );
    }
  spar_error (sparp, "The support of %.200s syntax is disabled for debugging or security purpose by disabling bit 0x%x of define lang:dialect",
    feature_name, feature_in_use );
}

void
spar_error_if_syntax_exception_imp (sparp_t *sparp, int feature_in_use, const char *feature_name)
{
  if (NULL != sparp->sparp_env->spare_context_sinvs)
    {
      SPART *sinv = (SPART *)(sparp->sparp_env->spare_context_sinvs->data);
      spar_error (sparp, "The %.200s syntax is disabled for the %.300s (bit 0x%x is set)",
        feature_name, spar_sinv_naming (sparp, sinv), feature_in_use );
    }
  spar_error (sparp, "The %.200s syntax is disabled for debugging or security purpose by setting bit 0x%x of define lang:exceptions",
    feature_name, feature_in_use );
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
  caddr_t ns_pref, ns_uri, res, res_uname, res_t_uname;
  int ns_uri_len, local_len, res_len;
  if (NULL == lname)
    return qname;
  ns_dict = sparp->sparp_env->spare_namespace_prefixes;
  ns_pref = t_box_dv_short_nchars (qname, lname - qname);
  lname++;
  do
    {
      ns_uri = (caddr_t)dk_set_get_keyword (ns_dict, ns_pref, NULL);
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
  res_uname = box_dv_uname_from_ubuf (res);
#ifdef SPARQL_DEBUG
  dk_check_tree (res_uname);
#endif
  res_t_uname = t_box_copy (res_uname);
  dk_free_box (res_uname);
  return res_t_uname;
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
  client_connection_t *cli = sqlc_client ();
  lock_trx_t *lt = cli->cli_trx;
  int entered = 0;
  caddr_t res;
  local_cursor_t *lc = NULL;
  caddr_t err = NULL;
  user_t *saved_user = cli->cli_user;
  int saved_anytime_started = cli->cli_anytime_started;
  if (cli->cli_clt) /* Branch of cluster transaction, can't initiate partitioned operations */
    return NULL;
  if (!lt->lt_threads)
    {
      int rc = lt_enter (lt);
      if (LTE_OK != rc)
        return NULL;
      entered = 1;
    }
  cli->cli_anytime_started = 0;
  cli->cli_user = sec_name_to_user ("dba");
  if (NULL == cached_qr_ptr[0])
    {
      if (0 /*parse_sem && parse_sem->sem_entry_count */) /* This means that the call is made inside the SQL compiler, can't re-enter. */
        spar_internal_error (sparp, "sparp_exec_Narg () tries to compile static inside the SQL compiler");
      cached_qr_ptr[0] = sql_compile_static (pl_call_text, cli, &err, SQLC_STATIC_PRESERVES_TREE);
      if (SQL_SUCCESS != err)
	{
	  cached_qr_ptr[0] = NULL;
	  if (err_ret)
	    *err_ret = err;
	  res = NULL;
          goto leave_and_ret; /* see below */
	}
    }
  err = qr_rec_exec (cached_qr_ptr[0], cli, &lc, CALLER_LOCAL, NULL, 1,
      ":0", box_copy_tree (arg1), QRP_RAW );
  if (SQL_SUCCESS != err)
    {
      LC_FREE(lc);
      if (err_ret)
	*err_ret = err;
      res = NULL;
      goto leave_and_ret; /* see below */
    }
  if (lc)
    {
      if (lc_next (lc))
        res = t_full_box_copy_tree (lc_nth_col (lc, 0));
      else
        res = NEW_DB_NULL;
      lc_free (lc);
      goto leave_and_ret; /* see below */
    }
  res = NULL;

leave_and_ret:
  cli->cli_user = saved_user;
  cli->cli_anytime_started = saved_anytime_started;
  if (entered)
    {
      IN_TXN;
      lt_leave (lt);
      LEAVE_TXN;
    }
  return res;
}

caddr_t
sparp_graph_sec_iri_to_id_nosignal (sparp_t *sparp, ccaddr_t qname)
{
  caddr_t *place, res;
  rwlock_rdlock (rdf_graph_iri2id_dict_htable->ht_rwlock);
  place = (caddr_t *)id_hash_get (rdf_graph_iri2id_dict_htable, (caddr_t)(&qname));
  res = (NULL == place) ? NULL : box_copy_tree (place[0]);
  rwlock_unlock (rdf_graph_iri2id_dict_htable->ht_rwlock);
  return res;
}

caddr_t
sparp_graph_sec_id_to_iri_nosignal (sparp_t *sparp, iri_id_t iid)
{
  char iid_box_buf[ALIGN_16 (sizeof (iri_id_t)) + BOX_AUTO_OVERHEAD];
  caddr_t boxed_iid, *place, res;
  BOX_AUTO (boxed_iid, iid_box_buf, sizeof (iri_id_t), DV_IRI_ID);
  ((iri_id_t *)boxed_iid)[0] = iid;
  rwlock_rdlock (rdf_graph_id2iri_dict_htable->ht_rwlock);
  place = (caddr_t *)id_hash_get (rdf_graph_id2iri_dict_htable, (caddr_t)(&iid));
  res = (NULL == place) ? NULL : box_copy_tree (place[0]);
  rwlock_unlock (rdf_graph_id2iri_dict_htable->ht_rwlock);
  return res;
}

static query_t *iri_to_id_nosignal_cached_qr = NULL;
static const char *iri_to_id_nosignal_text = "DB.DBA.RDF_MAKE_IID_OF_QNAME_COMP (?)";

caddr_t
sparp_iri_to_id_nosignal (sparp_t *sparp, ccaddr_t qname)
{
  caddr_t t_err, err = NULL;
  if (CALLER_LOCAL != sparp->sparp_sparqre->sparqre_qi)
    {
      caddr_t res = iri_to_id ((caddr_t *)(sparp->sparp_sparqre->sparqre_qi), (caddr_t)qname, IRI_TO_ID_WITH_CREATE, &err);
      if (NULL == err)
        {
          caddr_t t_res = t_box_copy (res);
          dk_free_box (res);
          return t_res;
        }
    }
  else
    {
      caddr_t t_res = sparp_exec_Narg (sparp, iri_to_id_nosignal_text, &iri_to_id_nosignal_cached_qr, &err, 1, (caddr_t)qname);
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
                unichar first_surro_u = 0;
                unichar acc = 0;
next_u:
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
                if (0 != first_surro_u)
                  {
                    if ((acc >= 0xDC00) && (acc <= 0xDFFF))
                      {
                        unichar utf16pair = (first_surro_u << 10) + acc - 0x35FDC00;
                        tgt_tail = eh_encode_char__UTF8 (utf16pair, tgt_tail, tgt_tail + MAX_UTF8_CHAR);
                        first_surro_u = 0;
                      }
                    else
                      {
                        err_msg = "The \\u....\\u.... UTF-16 escape sequence has low surrogate part out of \\uDC00--\\uDFFF range";
                        goto err;
                      }
                  }
                else if (is_json && (6 == bs_len) && (acc >= 0xD800) && (acc <= 0xDFFF))
                  {
                    if (acc >= 0xDC00)
                      {
                        err_msg = "The \\u.... low surrogate UTF-16 part from \\uDC00--\\uDFFF range is not prepended by a high surrogate part";
                        goto err;
                      }
                    first_surro_u = acc;
                    acc = 0;
                    if (('\\' != src_tail[0]) || ('u' != src_tail[1]))
                      {
                        err_msg = "Missing second \\u part in the \\u....\\u.... UTF-16 escape sequence after high surrogate part from \\uD800--\\uDBFF range";
                        goto err;
                      }
                    nextchr += 6;
                    /* src_tail is not incremented by 2 here because it is the init operator of for() after goto */
                    goto next_u; /* see above */
                  }
                else
                  tgt_tail = eh_encode_char__UTF8 (acc, tgt_tail, tgt_tail + MAX_UTF8_CHAR);
              }
            src_tail = nextchr;
            continue;
          }
        default: (tgt_tail++)[0] = (src_tail++)[0];
        }
    }
  res = t_box_dv_short_nchars (tmp_buf, tgt_tail - tmp_buf);
  box_flags (res) = BF_UTF8;
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
  return t_box_sprintf (0x100, "%s_%ld_%ld",
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
    "get:accept", "get:cartridge", "get:destination", "get:error-recovery", "get:group-destination", "get:login", "get:method", "get:note", "get:private", "get:proxy", "get:query", "get:refresh", "get:soft", "get:strategy", "get:uri", NULL };

static const char *sparp_integer_defines[] = {
    "input:grab-depth", "input:grab-limit", "lang:dialect", "lang:exceptions", "output:maxrows", "sql:big-data-const", "sql:log-enable", "sql:signal-void-variables", "sql:comment", "sql:comments", "sql:sparql-ebv", NULL };

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
          sparp->sparp_sg->sg_output_valmode_name = t_box_dv_uname_string (value); return; }
      if (!strcmp (param, "output:format")) {
          sparp->sparp_sg->sg_output_format_name = t_box_dv_uname_string (value); return; }
      if (!strcmp (param, "output:scalar-format")) {
          sparp->sparp_sg->sg_output_scalar_format_name = t_box_dv_uname_string (value); return; }
      if (!strcmp (param, "output:dict-format")) {
          sparp->sparp_sg->sg_output_dict_format_name = t_box_dv_uname_string (value); return; }
      if (!strcmp (param, "output:route")) {
          sparp->sparp_sg->sg_output_route_name = t_box_dv_uname_string (value); return; }
      if (!strcmp (param, "output:maxrows")) {
          sparp->sparp_sg->sg_output_maxrows = t_box_num_nonull (unbox (value)); return; }
    }
  if ((6 < strlen (param)) && !memcmp (param, "input:", 6))
    {
      if (!strcmp (param, "input:default-graph-uri"))
        {
          sparp_make_and_push_new_graph_source ( sparp, SPART_GRAPH_FROM,
            spartlist (sparp, 2, SPAR_QNAME, t_box_dv_uname_string (value)),
            NULL, SPARP_SSRC_FROZEN_BY_PROTOCOL );
          if (SPARP_SSRC_FROZEN_BY_PROTOCOL > sparp->sparp_env->spare_src.ssrc_freeze_status)
            sparp->sparp_env->spare_src.ssrc_frozen_pragma_example = param;
          sparp->sparp_env->spare_src.ssrc_freeze_status |= SPARP_SSRC_FROZEN_BY_PROTOCOL;
          return;
        }
      if (!strcmp (param, "input:using-graph-uri"))
        {
          sparp_make_and_push_new_graph_source ( sparp, SPART_GRAPH_FROM,
            spartlist (sparp, 2, SPAR_QNAME, t_box_dv_uname_string (value)),
            NULL, SPARP_SSRC_FROZEN_BY_PROTOCOL | SPARP_SSRC_FROZEN_BY_USING );
          if (SPARP_SSRC_FROZEN_BY_USING > sparp->sparp_env->spare_src.ssrc_freeze_status)
            sparp->sparp_env->spare_src.ssrc_frozen_pragma_example = param;
          sparp->sparp_env->spare_src.ssrc_freeze_status |= SPARP_SSRC_FROZEN_BY_PROTOCOL | SPARP_SSRC_FROZEN_BY_USING;
          return;
        }
      if (!strcmp (param, "input:default-graph-exclude"))
        {
          sparp_make_and_push_new_graph_source ( sparp, SPART_GRAPH_NOT_FROM,
            spartlist (sparp, 2, SPAR_QNAME, t_box_dv_uname_string (value)),
            NULL, 0 );
          /* No sparp->sparp_env->spare_src.ssrc_freeze_status |= something, because NOT FROM can not be overridden */
          return;
        }
      if (!strcmp (param, "input:named-graph-uri"))
        {
          sparp_make_and_push_new_graph_source ( sparp, SPART_GRAPH_NAMED,
            spartlist (sparp, 2, SPAR_QNAME, t_box_dv_uname_string (value)),
            NULL, SPARP_SSRC_FROZEN_BY_PROTOCOL );
          if (SPARP_SSRC_FROZEN_BY_PROTOCOL > sparp->sparp_env->spare_src.ssrc_freeze_status)
            sparp->sparp_env->spare_src.ssrc_frozen_pragma_example = param;
          sparp->sparp_env->spare_src.ssrc_freeze_status |= SPARP_SSRC_FROZEN_BY_PROTOCOL;
          return;
        }
      if (!strcmp (param, "input:using-named-graph-uri"))
        {
          sparp_make_and_push_new_graph_source ( sparp, SPART_GRAPH_NAMED,
            spartlist (sparp, 2, SPAR_QNAME, t_box_dv_uname_string (value)),
            NULL, SPARP_SSRC_FROZEN_BY_PROTOCOL | SPARP_SSRC_FROZEN_BY_USING );
          if (SPARP_SSRC_FROZEN_BY_USING > sparp->sparp_env->spare_src.ssrc_freeze_status)
            sparp->sparp_env->spare_src.ssrc_frozen_pragma_example = param;
          sparp->sparp_env->spare_src.ssrc_freeze_status |= SPARP_SSRC_FROZEN_BY_PROTOCOL | SPARP_SSRC_FROZEN_BY_USING;
          return;
        }
      if (!strcmp (param, "input:named-graph-exclude"))
        {
          sparp_make_and_push_new_graph_source (sparp, SPART_GRAPH_NOT_NAMED,
            spartlist (sparp, 2, SPAR_QNAME, t_box_dv_uname_string (value)),
            NULL, 0 );
          /* No sparp->sparp_env->spare_src.ssrc_freeze_status |= something, because NOT FROM can not be overridden */
          return;
        }
      if (!strcmp (param, "input:with-graph-uri"))
        {
          caddr_t iri = ('\0' == value[0]) ? uname_virtrdf_ns_uri_DefaultSparul11Target : t_box_dv_uname_string (value);
          SPART *val = spartlist (sparp, 2, SPAR_QNAME, iri);
          sparp_make_and_push_new_graph_source (sparp, SPART_GRAPH_FROM, val, NULL, SPARP_SSRC_FROZEN_BY_PROTOCOL);
          sparp->sparp_env->spare_src.ssrc_graph_set_by_with = val;
          if (SPARP_SSRC_FROZEN_BY_WITH > sparp->sparp_env->spare_src.ssrc_freeze_status)
            sparp->sparp_env->spare_src.ssrc_frozen_pragma_example = param;
          sparp->sparp_env->spare_src.ssrc_freeze_status |= SPARP_SSRC_FROZEN_BY_PROTOCOL | SPARP_SSRC_FROZEN_BY_WITH;
          return;
        }
      if (!strcmp (param, "input:target-fallback-graph-uri"))
        {
          caddr_t iri = ('\0' == value[0]) ? uname_virtrdf_ns_uri_DefaultSparul11Target : t_box_dv_uname_string (value);
          SPART *val = spartlist (sparp, 2, SPAR_QNAME, iri);
          sparp->sparp_env->spare_src.ssrc_fallback_target = val;
          return;
        }
      if (!strcmp (param, "input:with-fallback-graph-uri"))
        {
          caddr_t iri = ('\0' == value[0]) ? uname_virtrdf_ns_uri_DefaultSparul11Target : t_box_dv_uname_string (value);
          SPART *val = spartlist (sparp, 2, SPAR_QNAME, iri);
          sparp->sparp_env->spare_src.ssrc_fallback_target = sparp->sparp_env->spare_src.ssrc_fallback_default_graph = val;
          return;
        }
      if (!strcmp (param, "input:freeze"))
        {
          if (SPARP_SSRC_FROZEN_EXPLICITLY > sparp->sparp_env->spare_src.ssrc_freeze_status)
            sparp->sparp_env->spare_src.ssrc_frozen_pragma_example = param;
          sparp->sparp_env->spare_src.ssrc_freeze_status |= SPARP_SSRC_FROZEN_EXPLICITLY;
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
          quad_storage_t *old_storage = sparp->sparp_storage;
          if (NULL != sparp->sparp_env->spare_storage_name)
            spar_error (sparp, "'define %.30s' is used more than once", param);
          sparp->sparp_env->spare_storage_name = t_box_dv_uname_string (value);
          sparp->sparp_storage = sparp_find_storage_by_name (sparp, sparp->sparp_env->spare_storage_name);
          if ((NULL == sparp->sparp_storage) && ('\0' != value[0]))
            spar_error (sparp, "Quad storage <%.100s> does not exist or is in unusable state", value);
          if ((sparp->sparp_storage != old_storage)
            && (NULL != sparp->sparp_env->spare_context_qms)
            && ((SPART **)((ptrlong)_STAR) != sparp->sparp_env->spare_context_qms->data) )
            spar_error (sparp, "Can't change quad storage via 'define %.30s' in subqueries inside QUAD MAP group patterns other than 'QUAD MAP * {...}'", param);
          return;
        }
      if (!strcmp (param, "input:macro-lib"))
        {
          caddr_t lib_iri_uname = t_box_dv_uname_string (value);
          if (0 <= dk_set_position (sparp->sparp_macro_libs, lib_iri_uname))
            spar_error (sparp, "The macro library <%.100s> is loaded more than once", value);
          t_set_push (&(sparp->sparp_macro_libs), lib_iri_uname);
          return;
        }
      if (!strcmp (param, "input:macro-lib-ignore-create"))
        {
          sparp->sparp_macrolib_ignore_create = 1;
          return;
        }
      if (!strcmp (param, "input:disable-storage-macro-lib"))
        {
          sparp->sparp_disable_storage_macro_lib = 1;
          return;
        }
      if (!strcmp (param, "input:inference"))
        {
          rdf_inf_ctx_t ** place;
          if (NULL != sparp->sparp_env->spare_inference_name)
            spar_error (sparp, "'define %.30s' is used more than once", param);
          sparp->sparp_env->spare_inference_name = t_box_dv_uname_string (value);
          place = (rdf_inf_ctx_t **) id_hash_get (rdf_name_to_ric, (caddr_t)&value);
          if (NULL == place)
            spar_error (sparp, "'define %.30s refers to undefined inference rule set \"%.200s\"", param, value);
          sparp->sparp_env->spare_inference_ctx = place[0];
          return;
        }
      if ((11 < strlen (param)) && !memcmp (param, "input:grab-", 11))
        {
          rdf_grab_config_t *rgc = &(sparp->sparp_env->spare_src.ssrc_grab);
          rgc->rgc_pview_mode = 1;
          if (sparp->sparp_env->spare_src.ssrc_freeze_status & (SPARP_SSRC_FROZEN_BY_PROTOCOL | SPARP_SSRC_FROZEN_BY_USING | SPARP_SSRC_FROZEN_EXPLICITLY))
            {
              const char *frozen_pragma = sparp->sparp_env->spare_src.ssrc_frozen_pragma_example;
              if (NULL == frozen_pragma)
                frozen_pragma = "input:using-graph-iri or in combination with similar SPARQL 1.1 protocol parameter";
              spar_error (sparp, "define %s should not appear after define %s", param, frozen_pragma);
            }
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
          sparp->sparp_sg->sg_input_param_valmode_name = t_box_dv_uname_string (value); return; }
    }
  if ((4 < strlen (param)) && !memcmp (param, "get:", 4))
    {
      const char **chk;
      for (chk = sparp_known_get_params; (NULL != chk[0]) && strcmp (chk[0], param); chk++) ;
      if (NULL != chk[0])
        {
          dk_set_t *opts_ptr = &(sparp->sparp_env->spare_src.ssrc_common_sponge_options);
          if (0 < dk_set_position_of_string (opts_ptr[0], param))
            spar_error (sparp, "'define %.30s' is used more than once", param);
          t_set_push (opts_ptr, t_box_dv_short_string (value));
          t_set_push (opts_ptr, t_box_dv_uname_string (param));
          return;
        }
    }
  if ((5 < strlen (param)) && !memcmp (param, "lang:", 4))
    {
      if (!strcmp (param, "lang:dialect"))
        {
          ptrlong val = ((DV_LONG_INT == DV_TYPE_OF (value)) ? unbox_ptrlong (value) : -1);
          if ((0 > val) || IS_BOX_POINTER (val))
            spar_error (sparp, "define lang:dialect should have non-negative integer value, a bitmask of valid bits");
          sparp->sparp_permitted_syntax = val;
          return;
        }
      if (!strcmp (param, "lang:exceptions"))
        {
          ptrlong val = ((DV_LONG_INT == DV_TYPE_OF (value)) ? unbox_ptrlong (value) : -1);
          if ((0 > val) || IS_BOX_POINTER (val))
            spar_error (sparp, "define lang:exceptions should have non-negative integer value, a bitmask of valid bits");
          sparp->sparp_syntax_exceptions = val;
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
      if (!strcmp (param, "sql:gs-app-callback")) {
          sparp->sparp_gs_app_callback = t_box_sprintf (MAX_NAME_LEN, "DB.DBA.SPARQL_GS_APP_CALLBACK_%.50s", value);
          return; }
      if (!strcmp (param, "sql:gs-app-uid")) {
          sparp->sparp_gs_app_uid = t_full_box_copy_tree (value);
          return; }
      if (!strcmp (param, "sql:param") || !strcmp (param, "sql:params")) {
          t_set_push (&(sparp->sparp_env->spare_protocol_params), t_box_dv_uname_string (value));
          return; }
      if (!strcmp (param, "sql:globals-mode")) {
          if (DV_STRING != DV_TYPE_OF (value))
            spar_error (sparp, "define sql:globals-mode should have string value");
          if (!strcmp (value, "XSLT"))
            sparp->sparp_globals_mode = SPARE_GLOBALS_ARE_COLONAMED;
          else if (!strcmp (value, "SQL"))
            sparp->sparp_globals_mode = SPARE_GLOBALS_ARE_PLAIN;
          else
            spar_error (sparp, "define sql:globals-mode should have value \"XSLT\" or \"SQL\"");
          return; }
      if (!strcmp (param, "sql:log-enable")) {
          ptrlong val = ((DV_LONG_INT == DV_TYPE_OF (value)) ? unbox_ptrlong (value) : -1);
          if (0 > val)
            spar_error (sparp, "define sql:log-enable should have non-negative integer value");
            sparp->sparp_sg->sg_sparul_log_mode = t_box_num_and_zero (val);
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
      if (!strcmp (param, "sql:big-data-const")) {
          ptrlong val = ((DV_LONG_INT == DV_TYPE_OF (value)) ? unbox_ptrlong (value) : -1);
          if ((0 > val) || (1 < val))
            spar_error (sparp, "define sql:big-data-const should have value 0 or 1");
            sparp->sparp_disable_big_const = 1-val;
          return; }
      if (!strcmp (param, "sql:signal-void-variables")) {
          ptrlong val = ((DV_LONG_INT == DV_TYPE_OF (value)) ? unbox_ptrlong (value) : -1);
          if ((0 > val) || (1 < val))
            spar_error (sparp, "define sql:signal-void-variables should have value 0 or 1");
            sparp->sparp_sg->sg_signal_void_variables = val;
          return; }
      if (!strcmp (param, "sql:comment") || !strcmp (param, "sql:comments")) {
          ptrlong val = ((DV_LONG_INT == DV_TYPE_OF (value)) ? unbox_ptrlong (value) : 0);
          sparp->sparp_sg->sg_comment_sql = val;
          return; }
      if (!strcmp (param, "sql:sparql-ebv")) {
          ptrlong val = ((DV_LONG_INT == DV_TYPE_OF (value)) ? unbox_ptrlong (value) : 0);
          sparp->sparp_ebv_mode = val;
          return; }
    }
  spar_error (sparp, "Unsupported parameter '%.30s' in 'define'", param);
}

void
sparp_configure_storage_and_macro_libs (sparp_t *sparp)
{
  if (sparp->sparp_storage_is_set)
    return;
  sparp->sparp_storage_is_set = 1;
  sparp->sparp_storage = sparp_find_storage_by_name (sparp, sparp->sparp_env->spare_storage_name);
  if ((NULL != sparp->sparp_storage) && !sparp->sparp_disable_storage_macro_lib)
    {
      sparql_macro_library_t *smlib = sparp->sparp_storage->qsMacroLibrary;
      if (NULL != smlib)
        {
          SPART **smllist;
          int new_defm_ctr;
          if (0 == smlib->smlCompilationState)
            {
              jso_rtti_t *sml_rtti = (jso_rtti_t *)gethash (smlib, jso_rttis_of_structs);
              if (NULL == sml_rtti)
                spar_error (sparp, "Quad storage <%.100s> refers to nonexistent or corrupted SPARQL macro library", sparp->sparp_env->spare_storage_name);
              sparp_compile_smllist (sparp, sml_rtti->jrtti_inst_iri, smlib);
              smllist = (SPART **)(smlib->smlList);
              if (!IS_BOX_POINTER (smllist))
                spar_error (sparp, "Compilation error in SPARQL macro library <%.100s> referenced by quad storage <%.100s>", sml_rtti->jrtti_inst_iri, sparp->sparp_env->spare_storage_name);
            }
          smllist = (SPART **)(smlib->smlList);
          DO_BOX_FAST (SPART *, new_defm, new_defm_ctr, smllist)
            {
              sparp_defmacro_store (sparp, new_defm);
            }
          END_DO_BOX_FAST;
          sparp_qr_uses_jso (sparp, (caddr_t)smlib, NULL);
        }
    }
  if ((NULL != sparp->sparp_macro_libs) && (NULL == sparp->sparp_macrolib_to_create))
    {
      caddr_t *explicit_includes = t_revlist_to_array (sparp->sparp_macro_libs);
      jso_class_descr_t *sml_cd;
      int lib_ctr;
      DO_BOX_FAST (caddr_t, lib_name, lib_ctr, explicit_includes)
        {
          jso_rtti_t *sml_rtti;
          sparql_macro_library_t *sml;
          SPART **smllist;
          caddr_t *smlincludes;
          int jso_get_status, new_defm_ctr, old_defm_count, incl_ctr;
          jso_get_status = jso_get_pinned_cd_and_rtti (uname_virtrdf_ns_uri_QuadStorage, lib_name, &sml_cd, &sml_rtti);
          if (JSO_GET_OK != jso_get_status)
            spar_error (sparp, "Unknown SPARQL macro library <%.100s>", lib_name);
          sml = (sparql_macro_library_t *)(sml_rtti->jrtti_self);
          sparp_qr_uses_jso (sparp, (caddr_t)sml, NULL);
          if (0 == sml->smlCompilationState)
            {
              sparp_compile_smllist (sparp, sml_rtti->jrtti_inst_iri, sml);
              smllist = (SPART **)(sml->smlList);
              if (!IS_BOX_POINTER (smllist))
                spar_error (sparp, "Compilation error in SPARQL macro library <%.100s>", lib_name);
            }
          smllist = (SPART **)(sml->smlList);
          old_defm_count = sparp->sparp_macro_def_count;
          DO_BOX_FAST (SPART *, new_defm, new_defm_ctr, smllist)
            {
              int old_defm_ctr;
              for (old_defm_ctr = old_defm_count; old_defm_ctr--; /* no step */)
                {
                  SPART *old_defm = sparp->sparp_macro_defs [old_defm_ctr];
                  if (strcmp (old_defm->_.defmacro.mname, new_defm->_.defmacro.mname))
                    continue;
                  if (old_defm->_.defmacro.sml_iri != new_defm->_.defmacro.sml_iri)
                    spar_error (sparp, "Macro <%.100s> is defined in both <%100s> and <%100s>", old_defm->_.defmacro.mname, old_defm->_.defmacro.sml_iri, new_defm->_.defmacro.sml_iri);
                  goto new_defm_done; /* see below */
                }
              sparp_defmacro_store (sparp, new_defm);
new_defm_done: ;
            }
          END_DO_BOX_FAST;
          smlincludes = (caddr_t *)(sml->smlIncludes);
          DO_BOX_FAST (caddr_t, new_incl, incl_ctr, smlincludes)
            {
              t_set_pushnew (&(sparp->sparp_macro_libs), new_incl);
            }
          END_DO_BOX_FAST;
        }
      END_DO_BOX_FAST;
    }
}

void
sparp_compile_smllist (sparp_t *outer_sparp, caddr_t sml_iri_uname, void /* actually struct sparql_macro_library_t */ *smlib_as_voidptr)
{
  sparql_macro_library_t *smlib = (sparql_macro_library_t *)smlib_as_voidptr;
  spar_query_env_t sparqre;
  sparp_t *sparp;
  SPART **mdefs;
  int ctr;
  if (DV_STRING != DV_TYPE_OF (smlib->smlSourceText))
    spar_error (outer_sparp, "Ill metadata of SPARQL macro library that is associated with the quad storage");
  memset (&sparqre, 0, sizeof (spar_query_env_t));
  sparqre.sparqre_cli = bootstrap_cli;
  sparqre.sparqre_qi = outer_sparp->sparp_sparqre->sparqre_qi;
  sparp = sparp_query_parse (
    t_box_sprintf (50 + box_length (smlib->smlSourceText), "define input:disable-storage-macro-lib \"yes\" %s", smlib->smlSourceText),
    &sparqre, 0 );
  ctr = sparp->sparp_macro_def_count;
  mdefs = (SPART **)dk_alloc_box (ctr * sizeof (SPART *), DV_ARRAY_OF_POINTER);
  while (ctr--)
    {
      SPART *mdef = sparp->sparp_macro_defs[ctr];
      if (NULL == mdef->_.defmacro.sml_iri)
        mdef->_.defmacro.sml_iri = box_copy (sml_iri_uname);
      mdefs[ctr] = (SPART *)box_copy_tree ((caddr_t)(mdef));
    }
  dk_check_tree ((caddr_t)(mdefs));
  smlib->smlList = (ccaddr_t)mdefs;
  smlib->smlIncludes = box_copy_tree ((caddr_t)t_revlist_to_array (sparp->sparp_macro_libs));
}

int
spar_triple_matches_macro_quad_pattern (sparp_t *sparp, SPART *defm, SPART *graph, SPART *subject, SPART *predicate, SPART *object)
{
  SPART *tg, *ts, *tp, *to;
  if (NULL == defm->_.defmacro.quad_pattern)
    return 0;
#define FLD_CHECK(templ_fld, templ_fld_idx, triple_fld) do { \
      templ_fld = defm->_.defmacro.quad_pattern[(templ_fld_idx)]; \
      if (SPAR_IS_LIT_OR_QNAME (templ_fld) && \
         !((SPART_TYPE (triple_fld) == SPART_TYPE (templ_fld)) && \
         sparp_values_equal (sparp, (ccaddr_t)triple_fld, NULL, NULL, (ccaddr_t)templ_fld, NULL, NULL) ) ) \
        return 0; } while (0)
  FLD_CHECK(tp, SPART_TRIPLE_PREDICATE_IDX, predicate);
  FLD_CHECK(to, SPART_TRIPLE_OBJECT_IDX, object);
  FLD_CHECK(ts, SPART_TRIPLE_SUBJECT_IDX, subject);

  switch (defm->_.defmacro.subtype)
    {
    case DEFAULT_L:
      if (!SPART_IS_DEFAULT_GRAPH_BLANK(graph)) return 0;
      break;
    case GRAPH_L:
      if (SPART_IS_DEFAULT_GRAPH_BLANK(graph)) return 0;
        FLD_CHECK(tg, SPART_TRIPLE_GRAPH_IDX, graph);
      break;
    default:
      break;
    }
  return 1;
}

SPART *
spar_find_defmacro_by_iri_or_fields (sparp_t *sparp, const char *mname, SPART **fields)
{
  int ctr;
#define spar_return_if_macro_matches(sparp,mname,fields,defm) do { \
  if (NULL == fields) { \
      if (!strcmp (defm->_.defmacro.mname, mname)) \
        return defm; } \
  else if (spar_triple_matches_macro_quad_pattern (sparp, defm, fields[0], fields[1], fields[2], fields[3])) \
    return defm; } while (0)
  if (!sparp->sparp_storage_is_set)
    spar_internal_error (sparp, "spar_" "find_defmacro_by_iri_or_fields(): storage is not set");
  for (ctr = 0; ctr < sparp->sparp_macro_def_count; ctr++)
    {
      SPART *defm = sparp->sparp_macro_defs[ctr];
      spar_return_if_macro_matches (sparp,mname,fields,defm);
    }
  if ((NULL != sparp->sparp_storage) && !sparp->sparp_disable_storage_macro_lib)
    {
      sparql_macro_library_t *smlib = sparp->sparp_storage->qsMacroLibrary;
      if (NULL != smlib)
        {
          SPART **smllist = (SPART **)smlib->smlList;
          if (IS_BOX_POINTER (smllist))
            {
              DO_BOX_FAST (SPART *, defm, ctr, smllist)
                {
                  spar_return_if_macro_matches (sparp,mname,fields,defm);
                }
              END_DO_BOX_FAST;
            }
        }
    }
  return NULL;
}

void
sparp_defmacro_store (sparp_t *sparp, SPART *defm)
{
  int old_macro_def_count = sparp->sparp_macro_def_count;
  if (old_macro_def_count >= BOX_ELEMENTS_0(sparp->sparp_macro_defs))
    {
      SPART **new_defs = (SPART **)t_alloc_box ((old_macro_def_count + 2) * 2 * sizeof (SPART *), DV_ARRAY_OF_POINTER);
      if (old_macro_def_count)
        memcpy (new_defs, sparp->sparp_macro_defs, old_macro_def_count * sizeof (SPART *));
      sparp->sparp_macro_defs = new_defs;
    }
  sparp->sparp_macro_defs [sparp->sparp_macro_def_count++] = defm;
}

SPART *
sparp_defmacro_init (sparp_t *sparp, caddr_t mname)
{
  SPART *old, *res;
  caddr_t selid = spar_mkid (sparp, "@s");
  old = spar_find_defmacro_by_iri_or_fields (sparp, mname, NULL);
  if (NULL != old)
    spar_error (sparp, "Macro name <%.200s> is already defined", mname);
  if (0 <= dk_set_position_of_string (sparp->sparp_funnames_in_defmacros, mname))
    spar_error (sparp, "The name of macro <%.200s> is used above as a name of function in the body of other macro", mname);
  res = spartlist (sparp, 10, SPAR_DEFMACRO, (ptrlong)(1), mname, NULL, NULL, NULL, NULL, NULL, selid, (ptrlong)0);
  return res;
}

void
sparp_make_defmacro_paramnames_from_template (sparp_t *sparp, SPART *defm)
{
  dk_set_t paramnames = NULL;
  int ctr;
  DO_BOX_FAST (SPART *, fld, ctr, defm->_.defmacro.quad_pattern)
    {
      if (SPAR_VARIABLE == SPART_TYPE (fld))
        {
          caddr_t vname = fld->_.var.vname;
          if (0 <= dk_set_position_of_string (sparp->sparp_env->spare_protocol_params, vname))
            spar_error (sparp, "The name of protocol parameter ?%.200s is (mis)used in the template of the declaration of macro <%.200s>", vname, defm->_.defmacro.mname);
          if (0 <= dk_set_position_of_string (paramnames, vname))
            spar_error (sparp, "The name of valiable ?%.200s is used twice in the template of the declaration of macro <%.200s>", vname, defm->_.defmacro.mname);
          t_set_push (&paramnames, vname);
        }
    }
  END_DO_BOX_FAST;
  defm->_.defmacro.paramnames = t_revlist_to_array (paramnames);
}

void
sparp_defmacro_finalize (sparp_t *sparp, SPART *body)
{
  sparp->sparp_current_macro->_.defmacro.body = body;
  sparp->sparp_current_macro = NULL;
}

void
sparp_check_dm_arg_for_redecl (sparp_t *sparp, dk_set_t recent, caddr_t dm_arg_vname)
{
  SPART *mdef;
  int ctr;
  mdef = sparp->sparp_current_macro;
  if (0 <= dk_set_position_of_string (sparp->sparp_env->spare_protocol_params, dm_arg_vname))
    spar_error (sparp, "The name of protocol parameter ?%.200s is (mis)used in the declaration of macro <%.200s>", dm_arg_vname, mdef->_.defmacro.mname);
  if (0 <= dk_set_position_of_string (recent, dm_arg_vname))
    goto dupe;
  DO_BOX_FAST (caddr_t, old_vname, ctr, mdef->_.defmacro.paramnames)
    {
      if (!strcmp (old_vname, dm_arg_vname))
        goto dupe;
    }
  END_DO_BOX_FAST;
  return;
dupe:
  spar_error (sparp, "Duplicate variable name ?%.200s in arguments of macro <%.200s>", dm_arg_vname, mdef->_.defmacro.mname);
}

void
spar_gp_init (sparp_t *sparp, ptrlong subtype)
{
  sparp_env_t *env = sparp->sparp_env;
  int gp_is_top = ((WHERE_L == subtype) || (CONSTRUCT_L == subtype));
  spar_dbg_printf (("spar_gp_init (..., %ld)\n", (long)subtype));
  t_set_push (&(env->spare_acc_triples), NULL);
  t_set_push (&(env->spare_acc_movable_filters), NULL);
  t_set_push (&(env->spare_acc_local_filters), NULL);
  t_set_push (&(env->spare_context_gp_subtypes), (caddr_t)subtype);
  t_set_push (&(env->spare_good_graph_varname_sets), env->spare_good_graph_varnames);
  if (!gp_is_top)
    t_set_push (&(env->spare_propvar_sets), NULL); /* For WHERE_L and CONSTRUCT_L it's done at beginning of the result-set. */
  t_set_push (&(sparp->sparp_sg->sg_bnode_label_sets), NULL);
}

void
spar_gp_replace_selid (sparp_t *sparp, dk_set_t membs, caddr_t old_selid, caddr_t new_selid)
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
      if (NULL != memb->_.triple.options)
        sparp_set_options_selid_and_tabid (sparp, memb->_.triple.options, new_selid, memb->_.triple.tabid);
    }
  END_DO_SET ()
}

SPART *
spar_gp_finalize (sparp_t *sparp, SPART **options)
{
  sparp_env_t *env = sparp->sparp_env;
  caddr_t orig_selid = NULL;
  dk_set_t membs;
  int all_ctr, opt_ctr;
  dk_set_t movable_filts, local_filts;
  ptrlong subtype = (ptrlong)(env->spare_context_gp_subtypes->data);
  SPART *res;
  if (sparp->sparp_macro_mode)
    {
      if (DEFMACRO_L == subtype)
        orig_selid = sparp->sparp_current_macro->_.defmacro.selid;
      else
        orig_selid = spar_mkid (sparp, "@s");
    }
  else
    {
      if (NULL != options)
        {
          caddr_t tabid_l = (caddr_t)sparp_get_option (sparp, options, TABID_L);
          if (NULL != tabid_l)
            orig_selid = t_box_sprintf (100, "%s_%d", tabid_l, sparp->sparp_key_gen++);
        }
      if (NULL == orig_selid)
        orig_selid = spar_mkid (sparp, "s");
    }
  spar_dbg_printf (("spar_gp_finalize (..., %ld), orig_selid %s\n", (long)subtype, orig_selid));
  sparp->sparp_sg->sg_invalidated_bnode_labels = dk_set_conc (
    (dk_set_t)t_set_pop (&(sparp->sparp_sg->sg_bnode_label_sets)),
    sparp->sparp_sg->sg_invalidated_bnode_labels );
  if (CONSTRUCT_L != subtype) /* CONSTRUCT_L did not push to spare_propvar_sets, using one that will be used in WHERE_L */
    {
/* Create triple patterns for distinct '+>' propvars and OPTIONAL triple patterns for distinct '*>' propvars */
      dk_set_t propvars = (dk_set_t) t_set_pop (&(env->spare_propvar_sets));
      DO_SET (spar_propvariable_t *, pv, &propvars)
        {
          if (_STAR_GT == pv->sparpv_op)
            spar_gp_init (sparp, OPTIONAL_L);
          spar_gp_add_triplelike (sparp, NULL,
              spar_make_variable (sparp, pv->sparpv_subj_var->_.var.vname),
              pv->sparpv_verb_qname,
              spar_make_variable (sparp, pv->sparpv_obj_var_name),
              NULL, NULL, 0x0 );
          if (_STAR_GT == pv->sparpv_op)
            {
              SPART *pv_gp;
              pv_gp = spar_gp_finalize (sparp, NULL);
              t_set_push (((dk_set_t *)(&(env->spare_acc_triples->data))) /* not &membs */, pv_gp);
            }
        }
      END_DO_SET();
    }
/* Pop the rest of the environment and adjust graph varnames */
  membs = (dk_set_t) t_set_pop (&(env->spare_acc_triples));
  membs = dk_set_nreverse (membs);
  movable_filts = (dk_set_t) t_set_pop (&(env->spare_acc_movable_filters));
  local_filts = (dk_set_t) t_set_pop (&(env->spare_acc_local_filters));
  t_set_pop (&(env->spare_context_gp_subtypes));
  env->spare_good_graph_bmk = (dk_set_t)t_set_pop (&(env->spare_good_graph_varname_sets));
/* The following 'if' does not mention UNIONs because UNIONs are handled right in .y file
   For OPTIONAL GP we roll back spare_good_graph_vars at bookmarked level
   For other sorts the content of stack is naturally inherited by the parent:
   the bookmark is t_set_pop-ed, but the content remains at its place */
  if (OPTIONAL_L == subtype) /* Variables nested in optionals can not be good graph variables... */
    env->spare_good_graph_varnames = env->spare_good_graph_bmk;
check_optionals:
  all_ctr = 0;
  opt_ctr = 0;
  DO_SET (SPART *, memb, &membs)
    {
      if ((SPAR_GP == SPART_TYPE (memb)) && (OPTIONAL_L == memb->_.gp.subtype))
        {
          if (((0 == opt_ctr) && (1 < all_ctr)) || /* Add extra GP to guarantee proper left side of the left outer join */
            (0 < opt_ctr) )/* Add extra GP to guarantee proper support of {... OPTIONAL { ... ?x ... } ... OPTIONAL { ... ?x ... } } */
            {
              dk_set_t left_membs = NULL;
              dk_set_t left_ft_filts = NULL;
              int left_ctr;
              SPART *left_group;
              spar_gp_init (sparp, 0);
              for (left_ctr = 0; left_ctr < all_ctr; left_ctr++)
                {
                  SPART *memb = (SPART *)(t_set_pop (&membs));
                  if ((SPAR_TRIPLE == SPART_TYPE(memb)) && (memb->_.triple.ft_type))
                    {
                      DO_SET (SPART *, filt, &local_filts)
                        {
                          if (NULL == spar_filter_is_freetext_or_rtree (sparp, filt, memb))
                            continue;
                          t_set_delete (&local_filts, filt);
                          t_set_push (&left_ft_filts, filt);
                          break;
                        }
                      END_DO_SET()
                    }
                  t_set_push (&left_membs, memb);
                }
              env->spare_acc_triples->data = left_membs; /* a revlist is set to a revlist, no reverse needed */
              env->spare_acc_local_filters->data = left_ft_filts; /* same is true for filters, even if not so important */
              left_group = spar_gp_finalize (sparp, NULL);
              t_set_push (&membs, left_group);
              goto check_optionals; /* see above */
            }
          opt_ctr++;
        }
      else if (SPAR_TRIPLE == SPART_TYPE (memb))
        {
          caddr_t new_tabid = NULL;
          memb->_.triple.selid = orig_selid;
          if (NULL != memb->_.triple.options)
            {
              caddr_t tabid_l = (caddr_t)sparp_get_option (sparp, memb->_.triple.options, TABID_L);
              if (NULL != tabid_l)
                new_tabid = t_box_sprintf (100, "%s_%d", tabid_l, sparp->sparp_key_gen++);
            }
          if (NULL == new_tabid)
            new_tabid = t_box_sprintf (100, "%s_t%d", orig_selid, sparp->sparp_key_gen++);
          memb->_.triple.tabid = new_tabid;
        }
      all_ctr++;
    }
  END_DO_SET()
/* Plain composing of SPAR_GP tree node */
  res = spartlist (sparp, 10, SPAR_GP, subtype,
    t_list_to_array (membs),
    t_revlist_to_array (dk_set_conc (local_filts, movable_filts)),
    NULL,
    orig_selid,
    NULL, (ptrlong)(0), (ptrlong)(0), options );
  return res;
}

SPART *
spar_gp_finalize_with_subquery (sparp_t *sparp, SPART **options, SPART *subquery)
{
  SPART *gp;
  gp = spar_gp_finalize (sparp, options);
  gp->_.gp.subquery = subquery;
  if ((SELECT_L != gp->_.gp.subtype) && (0 != gp->_.gp.subtype))
    spar_internal_error (sparp, "spar_" "gp_finalize_with_subquery(): subquery is composed in a wrong way");
  gp->_.gp.subtype = SELECT_L;
  if (NULL != options)
    sparp_validate_options_of_tree (sparp, gp, options);
  return gp;
}

SPART *
spar_gp_finalize_with_inline_data (sparp_t *sparp, SPART **vars, SPART ***rows)
{
  SPART *gp = spar_gp_finalize (sparp, NULL);
  SPART *binv = spar_make_bindings_inv_with_fake_equivs (sparp, vars, rows, gp);
  gp->_.gp.subquery = binv;
  return gp;
}

void spar_gp_add_member (sparp_t *sparp, SPART *memb)
{
  dk_set_t *set_ptr;
  spar_dbg_printf (("spar_gp_add_member ()\n"));
  set_ptr = (dk_set_t *)(&(sparp->sparp_env->spare_acc_triples->data));
  t_set_push (set_ptr, memb);
}

caddr_t
spar_filter_is_freetext_or_rtree (sparp_t *sparp, SPART *filt, SPART *base_triple)
{
  caddr_t fname;
  SPART **args;
  int argcount;
  if (SPAR_FUNCALL != SPART_TYPE (filt))
    return NULL;
  fname = filt->_.funcall.qname;
  args = filt->_.funcall.argtrees;
  argcount = BOX_ELEMENTS (args);
  if (SPAR_FT_TYPE_IS_GEO(fname))
    {
      if (3 < argcount)
        return NULL;
      if (2 > argcount)
        spar_error (sparp, "Not enough arguments for spatial function %s", fname);
      if ((SPAR_VARIABLE != SPART_TYPE (args[0]))
        && (SPAR_VARIABLE == SPART_TYPE (args[1]))
        && ( (uname_bif_c_spatial_intersects	== (fname))
          || (uname_bif_c_st_intersects		== (fname))
          || (uname_bif_c_st_may_intersect	== (fname)) ) )
        {
          SPART *swap = args[0]; args[0] = args[1]; args[1] = swap;
        }
      if ((SPAR_VARIABLE != SPART_TYPE (args[0]))
        || !SPART_VARNAME_IS_PLAIN (args[0]->_.var.vname)
        || !sparp_tree_is_global_expn (sparp, args[1])
        || ((2 < argcount) && !sparp_tree_is_global_expn (sparp, args[1])) )
        return NULL;
    }
  else if ((fname == uname_bif_c_contains)
    || (fname == uname_bif_c_xcontains)
    || (fname == uname_bif_c_xpath_contains)
    || (fname == uname_bif_c_xquery_contains) )
    { 
      if (2 > argcount)
        spar_error (sparp, "Not enough arguments for free-text function %s", fname);
      if ((SPAR_VARIABLE != SPART_TYPE (args[0]))
        || !SPART_VARNAME_IS_PLAIN (args[0]->_.var.vname)
        || !sparp_tree_is_global_expn (sparp, args[1])
        || ((2 < argcount) && !sparp_tree_is_global_expn (sparp, args[1])) )
        return NULL;
    }
  else
    return NULL;
  if (NULL != base_triple)
    {
      caddr_t ft_var_name;
      if (SPAR_VARIABLE != SPART_TYPE (base_triple->_.triple.tr_object))
        return NULL;
      ft_var_name = base_triple->_.triple.tr_object->_.var.vname;
      if ((SPAR_VARIABLE != SPART_TYPE (args[0])) ||
        strcmp (args[0]->_.var.vname, ft_var_name) )
      return NULL;
    }
  return fname;
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
spar_gp_finalize_binds (sparp_t *sparp, dk_set_t bind_revlist)
{
  SPART *inner_gp, *wrapper_gp;
  int type_of_gp_to_resume;
  SPART *subselect_top;
  dk_set_t filters_of_gp_to_resume = (dk_set_t)(sparp->sparp_env->spare_acc_movable_filters->data);
  sparp->sparp_env->spare_acc_movable_filters->data = NULL;
  inner_gp = spar_gp_finalize (sparp, NULL);
  type_of_gp_to_resume = inner_gp->_.gp.subtype;
  inner_gp->_.gp.subtype = WHERE_L;
  spar_env_push (sparp);
  subselect_top = spar_make_top (sparp, SELECT_L, (SPART **)_STAR,
    inner_gp,
    (SPART **)NULL, (SPART *)NULL, (SPART **)NULL, (SPART *)NULL /* i.e., no limit */, (SPART *)t_box_num_nonull (0), NULL);
  sparp_expand_top_retvals (sparp, subselect_top, 1 /* safely_copy_all_vars */, bind_revlist);
  spar_env_pop (sparp);
  spar_gp_init (sparp, type_of_gp_to_resume);
  sparp->sparp_env->spare_acc_movable_filters->data = filters_of_gp_to_resume;
  spar_gp_init (sparp, SELECT_L);
  wrapper_gp = spar_gp_finalize_with_subquery (sparp, NULL, subselect_top);
  spar_gp_add_member (sparp, wrapper_gp);
}

void
spar_gp_add_filter (sparp_t *sparp, SPART *filt, int filt_is_movable)
{
  int filt_type = SPART_TYPE (filt);
  caddr_t ft_type;
  dk_set_t filters_set_stack;
  if (BOP_AND == filt_type)
    {
      spar_gp_add_filter (sparp, filt->_.bin_exp.left, filt_is_movable);
      spar_gp_add_filter (sparp, filt->_.bin_exp.right, filt_is_movable);
      return;
    }
  ft_type = spar_filter_is_freetext_or_rtree (sparp, filt, NULL);
  if (ft_type)
    {
      caddr_t ft_pred_name = filt->_.funcall.qname;
      SPART *ft_literal_var;
      caddr_t var_name;
      dk_set_t *triples_ptr;
      SPART **args, *triple_with_var_obj = NULL;
      int argctr, argcount, fld_ctr;
      int ft_is_geo = SPAR_FT_TYPE_IS_GEO (ft_pred_name);
      args = filt->_.funcall.argtrees;
      argcount = BOX_ELEMENTS (args);
      if (2 > argcount)
        spar_error (sparp, "Not enough parameters for special predicate %s()", ft_pred_name);
      ft_literal_var = filt->_.funcall.argtrees[0];
      if (SPAR_VARIABLE != SPART_TYPE (ft_literal_var))
        spar_error (sparp, "The first argument of special predicate %s() should be a variable", ft_pred_name);
      var_name = ft_literal_var->_.var.vname;
      triples_ptr = (dk_set_t *)(&(sparp->sparp_env->spare_acc_triples->data));
      DO_SET (SPART *, memb, triples_ptr)
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
            spar_error (sparp, "%s() predicate for '$%s' variable found with another %s() predicate found before for same variable in same basic group pattern", ft_pred_name, var_name, memb->_.triple.ft_type);
          if (NULL == triple_with_var_obj)
            triple_with_var_obj = memb;
        }
      END_DO_SET ()
      if (NULL == triple_with_var_obj)
        spar_error (sparp, "The group does not contain triple pattern with '$%s' object before %s() predicate", var_name, ft_pred_name);
      triple_with_var_obj->_.triple.ft_type = ft_type;
      if (!ft_is_geo)
        {
          if (argcount % 2)
            spar_error (sparp, "%s() special predicate is used with wrong number of arguments", ft_pred_name);
          if (2 < argcount)
            for (argctr = 2; argctr < argcount; argctr += 2)
              {
                SPART *arg_value = args[argctr+1];
                SPART *opt_value;
                if (SPAR_VARIABLE != SPART_TYPE (arg_value))
                  continue;
                if (DV_LONG_INT != DV_TYPE_OF (args[argctr]))
                  spar_error (sparp, "Invalid argument #%d for %s() special predicate", argctr+1, ft_pred_name);
                spar_tree_is_var_with_forbidden_ft_name (sparp, arg_value, 1);
                opt_value = (SPART *)t_box_copy_tree ((caddr_t)arg_value);
                opt_value->_.var.tabid = triple_with_var_obj->_.triple.tabid;
                opt_value->_.var.tr_idx = (ptrlong)args[argctr];
                triple_with_var_obj->_.triple.options = t_spartlist_concat (
                  triple_with_var_obj->_.triple.options,
                  (SPART **)t_list (2, args[argctr], opt_value) );
              }
        }
      for (fld_ctr = 0; fld_ctr < SPART_TRIPLE_FIELDS_COUNT; fld_ctr++)
        spar_tree_is_var_with_forbidden_ft_name (sparp, triple_with_var_obj->_.triple.tr_fields[fld_ctr], 1);
      if (IS_BOX_POINTER (sparp->sparp_env->spare_sql_refresh_free_text))
        ((boxint *)(sparp->sparp_env->spare_sql_refresh_free_text))[0] = 1;
      else
        sparp->sparp_env->spare_sql_refresh_free_text = t_box_num (1);
      filt_is_movable = 0;
    }
  filters_set_stack = filt_is_movable ? sparp->sparp_env->spare_acc_movable_filters : sparp->sparp_env->spare_acc_local_filters;
  if (NULL == filters_set_stack)
    spar_internal_error (sparp, "spar_" "gp_add_filter(): NULL sparp->sparp_env->spare_acc_xxx_filters");
  t_set_push ((dk_set_t *)(&(filters_set_stack->data)), filt);
}

void
spar_gp_add_filters_for_graph (sparp_t *sparp, SPART *graph_expn, int graph_is_named, int suppress_filters_for_good_names)
{
  sparp_env_t *env = sparp->sparp_env;
  dk_set_t sources = (graph_is_named ? env->spare_src.ssrc_named_graphs : env->spare_src.ssrc_default_graphs);
  caddr_t varname = NULL;
  SPART *good_list_expn, *bad_list_expn, *filter;
  if (NULL == sources)
    return;
  if (SPAR_IS_BLANK_OR_VAR (graph_expn))
    {
      varname = graph_expn->_.var.vname;
      if (suppress_filters_for_good_names)
        {
          dk_set_t good_varnames = env->spare_good_graph_varnames;
          if (0 <= dk_set_position_of_string (good_varnames, varname))
            return;
        }
    }
  if ((NULL != sources) && (NULL == sources->next))
    {
      SPART *src = (SPART *)(sources->data);
      if (!(src->_.graph.subtype & SPART_GRAPH_GROUP_BIT))
        {
          SPART *graph_expn_copy = (
            (NULL != varname) ?
            ((SPAR_VARIABLE == SPART_TYPE (graph_expn)) ?
              spar_make_variable (sparp, varname) :
              spar_make_blank_node (sparp, varname, 0)) :
            (SPART *) t_box_copy ((caddr_t) graph_expn) );
          filter = spartlist (sparp, 3,
            ((SPART_GRAPH_MIN_NEGATION < src->_.graph.subtype) ? BOP_NEQ : BOP_EQ),
            graph_expn_copy, src->_.graph.expn );
          spar_gp_add_filter (sparp, filter, 0);
          return;
        }
    }
  if (graph_is_named)
    {
      good_list_expn = spar_make_list_of_sources_expn (sparp, SPART_GRAPH_NAMED, 0, 0, RDF_GRAPH_PERM_READ, graph_expn);
      bad_list_expn = spar_make_list_of_sources_expn (sparp, SPART_GRAPH_NOT_NAMED, 0, 0, 0x0, graph_expn);
    }
  else
    {
      good_list_expn = spar_make_list_of_sources_expn (sparp, SPART_GRAPH_FROM, SPART_GRAPH_GROUP, 0, RDF_GRAPH_PERM_READ, graph_expn);
      bad_list_expn = spar_make_list_of_sources_expn (sparp, SPART_GRAPH_NOT_FROM, SPART_GRAPH_NOT_GROUP, 0, 0x0, graph_expn);
    }
  if (NULL != good_list_expn)
    spar_gp_add_filter (sparp, good_list_expn, 0);
  if (NULL != bad_list_expn)
    spar_gp_add_filter (sparp, spartlist (sparp, 3, BOP_NOT, bad_list_expn, NULL), 0);
}

void
spar_gp_add_filters_for_named_graph (sparp_t *sparp)
{
  sparp_env_t *env = sparp->sparp_env;
  SPART *graph_expn = (SPART *)(env->spare_context_graphs->data);
  spar_gp_add_filters_for_graph (sparp, graph_expn, 1, 0);
}

SPART *
spar_make_list_of_sources_expn (sparp_t *sparp, ptrlong from_subtype, ptrlong from_group_subtype, ptrlong from2_subtype, ptrlong req_perms, SPART *needle_expn)
{
  dk_set_t single_graphs = NULL;
  dk_set_t graph_groups = NULL;
  DO_SET (SPART *, g, &(sparp->sparp_env->spare_src.ssrc_default_graphs))
    {
      ptrlong st = g->_.graph.subtype;
      if ((st == from_subtype) || (st == from2_subtype))
        t_set_push (&single_graphs, g->_.graph.expn);
      else if (st == from_group_subtype)
        t_set_push (&graph_groups, g->_.graph.expn);
    }
  END_DO_SET()
  DO_SET (SPART *, g, &(sparp->sparp_env->spare_src.ssrc_named_graphs))
    {
      ptrlong st = g->_.graph.subtype;
      if ((st == from_subtype) || (st == from2_subtype))
        t_set_push (&single_graphs, g->_.graph.expn);
      else if (st == from_group_subtype)
        t_set_push (&graph_groups, g->_.graph.expn);
    }
  END_DO_SET()
  if ((NULL == graph_groups) && (NULL == single_graphs))
    {
      if (NULL == needle_expn)
        return (SPART *)t_NEW_DB_NULL;
      return NULL;
    }
  if (NULL != needle_expn)
    {
      switch (SPART_TYPE (needle_expn))
        {
        case SPAR_BLANK_NODE_LABEL:
          needle_expn = spar_make_blank_node (sparp, needle_expn->_.var.vname, 0);
          break;
        case SPAR_VARIABLE:
          needle_expn = spar_make_variable (sparp, needle_expn->_.var.vname);
          break;
        }
    }
  if (NULL != graph_groups)
    {
      SPART *groups_expn = ((NULL == graph_groups->next) ?
            (SPART *)(graph_groups->data) :
            spar_make_funcall (sparp, 0, "LONG::bif:vector",
              (SPART **)t_list_to_array (graph_groups) ) );
      SPART *singles_expn = ((NULL == single_graphs) ?
            (SPART *)t_NEW_DB_NULL :
            spar_make_funcall (sparp, 0, "LONG::bif:vector",
              (SPART **)t_list_to_array (single_graphs) ) );
      SPART *lst_expn = spar_make_funcall (sparp, 0, "SPECIAL::sql:RDF_GRAPH_GROUP_LIST_GET",
        (SPART **)t_list (6,
          groups_expn, singles_expn, spar_boxed_exec_uid (sparp),
          ((NULL == sparp->sparp_gs_app_callback) ? t_NEW_DB_NULL : sparp->sparp_gs_app_callback),
          ((NULL == sparp->sparp_gs_app_uid) ? t_NEW_DB_NULL : sparp->sparp_gs_app_uid),
          t_box_num_nonull (req_perms) ) );
      if (NULL == needle_expn)
        return lst_expn;
#if 0 /* For version 5 */
      return spar_make_funcall (sparp, 0, "LONG::bif:position",
        (SPART **)t_list (2, needle_expn, lst_expn) );
#else
      return sparp_make_builtin_call (sparp, SPAR_BIF__ITEM_IN_VECTOR,
        (SPART **)t_list (2, needle_expn, lst_expn) );
#endif
    }
  if (NULL == needle_expn)
    return spar_make_funcall (sparp, 0, "LONG::bif:vector",
      (SPART **)t_list_to_array (single_graphs) );
  t_set_push (&single_graphs, needle_expn);
  return sparp_make_builtin_call (sparp, IN_L,
    (SPART **)t_list_to_array (single_graphs) );
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

void
spar_list_triple_varnames_and_macropunames_in_tree (sparp_t *sparp, SPART *tree, dk_set_t *all_varnames_ret, dk_set_t *undiscovered_ret)
{
  int ctr;
  switch (SPART_TYPE (tree))
    {
    case SPAR_ALIAS: t_set_push_new_string (all_varnames_ret, tree->_.alias.aname); break;
    case SPAR_VARIABLE: t_set_push_new_string (all_varnames_ret, tree->_.var.vname); break;
    case SPAR_TRIPLE:
      for (ctr = SPART_TRIPLE_FIELDS_COUNT; ctr--; /* no step */)
        {
          SPART *fld = tree->_.triple.tr_fields[ctr];
          switch (SPART_TYPE (fld))
            {
            case SPAR_VARIABLE: t_set_push_new_string (all_varnames_ret, fld->_.var.vname); break;
            case SPAR_MACROPU: t_set_push_new_string (all_varnames_ret, fld->_.macropu.pname); break;
            }
        }
      break;
    case SPAR_GP:
      DO_BOX_FAST_REV (SPART *, memb, ctr, tree->_.gp.members)
        {
          spar_list_triple_varnames_and_macropunames_in_tree (sparp, memb, all_varnames_ret, undiscovered_ret);
        }
      END_DO_BOX_FAST_REV;
      if (NULL != tree->_.gp.subquery)
        {
          SPART **retvals = tree->_.gp.subquery->_.req_top.retvals;
          if (DV_ARRAY_OF_POINTER == DV_TYPE_OF (retvals))
            {
              DO_BOX_FAST_REV (SPART *, memb, ctr, retvals)
                {
                  spar_list_triple_varnames_and_macropunames_in_tree (sparp, memb, all_varnames_ret, undiscovered_ret);
                }
              END_DO_BOX_FAST_REV;
            }
          else
            spar_internal_error (sparp, "Usupported combination of subqueries and service invocations");
        }
      break;
    case SPAR_MACROCALL: case SPAR_MACROPU:
      t_set_push (undiscovered_ret, tree);
      break;
    }
}

void
spar_add_service_inv_to_sg (sparp_t *sparp, SPART *sinv)
{
  SPART **sinvs = sparp->sparp_sg->sg_sinvs;
  ptrlong sinvcount = sparp->sparp_sg->sg_sinv_count;
  if (IS_BOX_POINTER (sparp->sparp_sg->sg_sinv_count))
    spar_error (sparp, "Too many service invocations, probably due to abnormal macro expansion");
  sinv->_.sinv.own_idx = sinvcount;
  if (BOX_ELEMENTS_INT_0 (sinvs) == sinvcount)
    {
      size_t new_size = ((NULL == sinvs) ? 4 * sizeof (SPART *) : 2 * box_length (sinvs));
      SPART **new_sinvs = (SPART **)t_alloc_box (new_size, DV_ARRAY_OF_POINTER);
      if (NULL != sinvs)
        memcpy (new_sinvs, sinvs, box_length (sinvs));
#ifdef DEBUG
      if (NULL != sinvs)
        memset (sinvs, -1, box_length (sinvs));
#endif
      sparp->sparp_sg->sg_sinvs = sinvs = new_sinvs;
    }
  sinvs[sinvcount] = sinv;
  sparp->sparp_sg->sg_sinv_count++;
}

SPART *
spar_make_service_inv (sparp_t *sparp, SPART *endpoint, dk_set_t all_options, ptrlong permitted_syntax, ptrlong syntax_exceptions, SPART **sources, caddr_t sinv_storage, int silent)
{
  dk_set_t iri_params = NULL;
  dk_set_t param_varnames = NULL;
  dk_set_t rset_varnames = NULL;
  dk_set_t defines = NULL;
  int in_list_implicit = 0;
  int in_list_explicit = 0;
  SPART *sinv;
  while (NULL != all_options)
    {
      caddr_t optvalue = (caddr_t)t_set_pop (&all_options);
      caddr_t optname = (caddr_t)t_set_pop (&all_options);
      if (DEFINE_L == (ptrlong)optname)
        {
          t_set_push (&defines, ((SPART **)optvalue)[0]);
          t_set_push (&defines, ((SPART **)optvalue)[1]);
        }
      else if (IN_L == (ptrlong)optname)
        {
          if (_STAR == (ptrlong)optvalue)
            {
              dk_set_t gp_subtypes_iter;
              dk_set_t acc_triples_iter = sparp->sparp_env->spare_acc_triples;
              in_list_implicit = 1;
              for (gp_subtypes_iter = sparp->sparp_env->spare_context_gp_subtypes;
                NULL != gp_subtypes_iter;
                gp_subtypes_iter = gp_subtypes_iter->next, acc_triples_iter = acc_triples_iter->next )
                {
                  dk_set_t members_before;
                  int gp_subtype = (ptrlong)(gp_subtypes_iter->data);
                  if (SELECT_L == gp_subtype)
                    break;
                  if ((UNION_L == gp_subtype) || (SPAR_UNION_WO_ALL == gp_subtype))
                    continue;
                  members_before = (dk_set_t)(acc_triples_iter->data);
                  DO_SET (SPART *, member, &members_before)
                    {
                      dk_set_t undiscovered = NULL;
                      spar_list_triple_varnames_and_macropunames_in_tree (sparp, member, &param_varnames, &undiscovered);
                      if (NULL != undiscovered)
                        spar_error (sparp, "SERVICE invocation is used in combination with macro so it should have explicit list of IN variables in options");
                    }
                  END_DO_SET()
                }
            }
          else
            {
              int varctr;
              DO_BOX_FAST (SPART *, var, varctr, (SPART **)optvalue)
                {
                  caddr_t vname = var->_.var.vname;
                  if (0 <= dk_set_position_of_string (param_varnames, vname))
                    spar_error (sparp, "Duplicate IN variable name \"%.100s\" in OPTIONs of SERVICE invocation", vname);
                  t_set_push (&param_varnames, vname);
                }
              END_DO_BOX_FAST;
            }
          if (in_list_implicit && in_list_explicit)
            spar_error (sparp, "options of SERVICE invocation contain both 'IN *' and 'IN ?variable'");
        }
/*! TBD: add other cases */
    }
  sinv = spartlist (sparp, 13, SPAR_SERVICE_INV,
    (ptrlong)(0),
    endpoint,
    t_revlist_to_array (iri_params),
    t_box_num (permitted_syntax),
    t_box_num (syntax_exceptions),
    t_revlist_to_array (param_varnames),
    (ptrlong)in_list_implicit,
    t_revlist_to_array (rset_varnames),
    t_revlist_to_array (defines),
    sources,
    sinv_storage,
    (ptrlong)silent );
  return sinv;
}

caddr_t
spar_sinv_naming (sparp_t *sparp, SPART *sinv)
{
  switch (SPART_TYPE (sinv->_.sinv.endpoint))
    {
    case SPAR_VARIABLE: return t_box_sprintf (300, "SERVICE ?%.200s at line %ld", sinv->_.sinv.endpoint->_.var.vname, (long)(unbox(sinv->_.sinv.endpoint->srcline)));
    case SPAR_QNAME: return t_box_sprintf (300, "SERVICE <%.200s> at line %ld", sinv->_.sinv.endpoint->_.qname.val, (long)(unbox(sinv->_.sinv.endpoint->srcline)));
    default: return t_box_sprintf (300, "SERVICE at line %ld", (long)(unbox(sinv/*->_.sinv.endpoint*/->srcline)));
    }
}

int
spar_describe_restricted_by_physical (sparp_t *sparp, SPART *req_top, SPART **retvals)
{
  SPART **sources = req_top->_.req_top.sources;
  SPART *dflt_s = NULL;
  SPART *triple;
  int s_ctr;
  /*spar_selid_push_reused (sparp, uname__ref);*/
  t_set_push (&(sparp->sparp_env->spare_context_gp_subtypes), (caddr_t)((ptrlong)WHERE_L));
  triple = spar_make_plain_triple (sparp,
    spar_make_fake_blank_node (sparp),
    NULL,
    spar_make_fake_blank_node (sparp),
    spar_make_fake_blank_node (sparp),
    (SPART **)t_list (2, NULL, (ptrlong)(_STAR)), NULL );
  /*spar_selid_pop (sparp);*/
  t_set_pop (&(sparp->sparp_env->spare_context_gp_subtypes));
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
spar_retvals_of_describe (sparp_t *sparp, SPART *req_top, SPART **retvals, SPART *limit_expn, SPART *offset_expn)
{
  int retval_ctr;
  dk_set_t vars = NULL;
  dk_set_t consts = NULL;
  SPART *good_graphs, *bad_graphs;
  SPART *descr_call;
  SPART *agg_call;
  SPART *var_vector_expn;
  SPART *var_vector_arg;
  SPART *opts_arg;
  dk_set_t opts_revlist = NULL;
  caddr_t limofs_name;
  caddr_t storage_name_or_null;
  const char *descr_name, *postproc_name = NULL;
  int need_limofs_trick = (
    (NULL != limit_expn) ||
    (DV_LONG_INT != DV_TYPE_OF (offset_expn)) ||
    (0 != unbox ((caddr_t)(offset_expn))) );
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

  var_vector_expn = spar_make_funcall (sparp, 0, "LONG::bif:vector",
    (SPART **)t_list_to_array (vars) );
  if (need_limofs_trick)
    {
      limofs_name = t_box_dv_short_string ("@\"limofs\".\"describe-1\"");
      var_vector_arg = spar_make_variable (sparp, limofs_name);
    }
  else
    var_vector_arg = var_vector_expn;
  agg_call = spar_make_funcall (sparp, 1, "sql:SPARQL_DESC_AGG",
      (SPART **)t_list (1, var_vector_arg ) );
  if (NULL != sparp->sparp_env->spare_describe_mode)
    {
      const char *mode = sparp->sparp_env->spare_describe_mode;
      const char *mode1 = mode, *plus = strchr (mode, '+');
      int phys_only;
      if (NULL != plus)
        {
          mode1 = t_box_dv_short_nchars (mode, plus-mode);
          postproc_name = t_box_sprintf (100, "sql:SPARQL_DESC_POSTPROC_%.50s", plus+1);
        }
      if ('\0' == mode1[0])
        descr_name = "sql:SPARQL_DESC_DICT";
      else
        {
          phys_only = ((NULL == sparp->sparp_env->spare_inference_name)
            && (NULL == sparp->sparp_env->spare_use_same_as)
            && spar_describe_restricted_by_physical (sparp, req_top, retvals) );
          if (phys_only)
            descr_name = t_box_sprintf (100, "sql:SPARQL_DESC_DICT_%.50s_PHYSICAL", mode1);
          else
            descr_name = t_box_sprintf (100, "sql:SPARQL_DESC_DICT_%.50s", mode1);
        }
    }
  else
    descr_name = "sql:SPARQL_DESC_DICT";
  if (sparp->sparp_env->spare_src.ssrc_default_graphs_listed || sparp->sparp_env->spare_src.ssrc_named_graphs_listed)
    good_graphs = spar_make_list_of_sources_expn (sparp, SPART_GRAPH_FROM, SPART_GRAPH_GROUP, SPART_GRAPH_NAMED, RDF_GRAPH_PERM_READ, NULL);
  else
    good_graphs = (SPART *)t_box_num_nonull (0);
  bad_graphs = spar_make_list_of_sources_expn (sparp, SPART_GRAPH_NOT_FROM, SPART_GRAPH_NOT_GROUP, SPART_GRAPH_NOT_NAMED, 0x0, NULL);
  t_set_push (&opts_revlist, t_box_dv_short_string ("uid"));
  t_set_push (&opts_revlist, spar_boxed_exec_uid (sparp));
  if (NULL != sparp->sparp_gs_app_callback)
    {
      t_set_push (&opts_revlist, t_box_dv_short_string ("gs-app-callback"));
      t_set_push (&opts_revlist, sparp->sparp_gs_app_callback );
    }
  if (NULL != sparp->sparp_gs_app_uid)
    {
      t_set_push (&opts_revlist, t_box_dv_short_string ("gs-app-uid"));
      t_set_push (&opts_revlist, sparp->sparp_gs_app_uid);
    }
  if (NULL != sparp->sparp_env->spare_inference_name)
    {
      t_set_push (&opts_revlist, t_box_dv_short_string ("inference"));
      t_set_push (&opts_revlist, sparp->sparp_env->spare_inference_name);
    }
  if (NULL != sparp->sparp_env->spare_use_same_as)
    {
      t_set_push (&opts_revlist, t_box_dv_short_string ("same-as"));
      t_set_push (&opts_revlist, sparp->sparp_env->spare_use_same_as);
    }
  storage_name_or_null = sparp->sparp_env->spare_storage_name;
  if (NULL == storage_name_or_null)
    storage_name_or_null = t_NEW_DB_NULL;
  opts_arg = spar_make_funcall (sparp, 0, "bif:vector", (SPART **)t_revlist_to_array (opts_revlist)); /*!!!TBD describe options will be added here */
  descr_call = spar_make_funcall (sparp, 0, descr_name,
      (SPART **)t_list (6,
        agg_call,
        spar_make_funcall (sparp, 0, "LONG::bif:vector",
          (SPART **)t_list_to_array (consts) ),
        good_graphs,
        bad_graphs,
        storage_name_or_null,
        opts_arg ) );
  if (NULL != postproc_name)
    descr_call = spar_make_funcall (sparp, 0, postproc_name,
      (SPART **)t_list (5,
        descr_call,
        good_graphs,
        bad_graphs,
        storage_name_or_null,
        opts_arg ) );
  if (need_limofs_trick)
    return (SPART **)t_list (2, descr_call,
      spartlist (sparp, 6, SPAR_ALIAS, var_vector_expn, t_box_dv_short_string ("describe-1"), SSG_VALMODE_AUTO, (ptrlong)0, (ptrlong)0) );
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
        t_set_push_new_string (&(sparp->sparp_env->spare_src.ssrc_grab.rgc_vars), t_box_dv_uname_string (curr->_.var.vname));
      break;
    case SPAR_QNAME:
      t_set_push_new_string (&(sparp->sparp_env->spare_src.ssrc_grab.rgc_consts), curr->_.lit.val);
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
      sparp_gp_trav (sparp, NULL /*unused*/, retval, NULL,
        NULL, NULL,
        sparp_gp_trav_add_rgc_vars_and_consts_from_retvals, NULL, NULL,
        sparp_gp_trav_add_rgc_vars_and_consts_from_retvals );
    }
  END_DO_BOX_FAST;
}

SPART *
spar_make_wm (sparp_t *sparp, SPART *pattern, SPART **groupings, SPART *having, SPART **order, SPART *limit, SPART *offset, SPART *binv)
{
  if ((NULL != having) && (NULL == groupings))
    spar_error (sparp, "HAVING clause should be preceded by a GROUP BY clause");
  if ((DV_ARRAY_OF_POINTER == DV_TYPE_OF (limit)) && (SPAR_LIT == limit->type) && (DV_LONG_INT == DV_TYPE_OF (limit->_.lit.val)))
    limit = (SPART *)(limit->_.lit.val);
  if ((DV_ARRAY_OF_POINTER == DV_TYPE_OF (offset)) && (SPAR_LIT == offset->type) && (DV_LONG_INT == DV_TYPE_OF (offset->_.lit.val)))
    offset = (SPART *)(offset->_.lit.val);
  return spartlist (sparp, 8, SPAR_WHERE_MODIFS, pattern, groupings, having, order, limit, offset, binv);
}

int
sparp_gp_trav_rename_for_having (sparp_t *sparp, SPART *curr, sparp_trav_state_t *sts_this, void *common_env)
{
  caddr_t *selid_to_patch_ptr = NULL;
  switch (curr->type)
    {
    case SPAR_VARIABLE: case SPAR_BLANK_NODE_LABEL:
      selid_to_patch_ptr = &(curr->_.var.selid); break;
    case SPAR_GP:
      if ((WHERE_L != curr->_.gp.subtype) && (SELECT_L != curr->_.gp.subtype))
        return SPAR_GPT_NODOWN;
      selid_to_patch_ptr = &(curr->_.gp.selid); break;
    case SPAR_TRIPLE:
      selid_to_patch_ptr = &(curr->_.triple.selid); break;
    default: return 0;
    }
  if (strcmp (selid_to_patch_ptr[0], common_env))
    return SPAR_GPT_NODOWN;
  selid_to_patch_ptr[0] = t_box_sprintf (100, "%.90s~wm", selid_to_patch_ptr[0]);
  return 0;
}

SPART *
spar_make_top_or_special_case_from_wm (sparp_t *sparp, ptrlong subtype, SPART **retvals, SPART *wm)
{
  SPART *pattern = wm->_.wm.where_gp;
  SPART **groupings = wm->_.wm.groupings;
  SPART *having = wm->_.wm.having;
  SPART **order = wm->_.wm.obys;
  SPART *limit = wm->_.wm.lim;
  SPART *offset = wm->_.wm.ofs;
  SPART *binv = wm->_.wm.binv;
  if ((NULL == sparp->sparp_sg->sg_output_format_name)
    && (NULL == sparp->sparp_env->spare_parent_env)
    && ssg_is_odbc_cli () )
    {
      if (ssg_is_odbc_msaccess_cli ())
        sparp->sparp_sg->sg_output_format_name = t_box_dv_short_string ("_MSACCESS_");
      else
        sparp->sparp_sg->sg_output_format_name = t_box_dv_short_string ("_UDBC_");
    }
#ifndef NDEBUG
  if (SPAR_WHERE_MODIFS != SPART_TYPE (wm))
    spar_internal_error (sparp, "Ill wm");
#endif
  if (0 != sparp->sparp_macro_call_count)
    {
      spar_mproc_ctx_t ctx;
      memset (&ctx, 0, sizeof (spar_mproc_ctx_t));
      ctx.smpc_unictr = (sparp->sparp_unictr)++;
      ctx.smpc_context_gp = pattern;
      ctx.smpc_context_selid = pattern->_.gp.selid;
      pattern = spar_macroprocess_tree (sparp, pattern, &ctx);
      ctx.smpc_context_gp = pattern;
      ctx.smpc_context_selid = pattern->_.gp.selid;
      retvals = spar_macroprocess_treelist (sparp, retvals, 0, &ctx);
      groupings = spar_macroprocess_treelist (sparp, groupings, 0, &ctx);
      having = spar_macroprocess_tree (sparp, having, &ctx);
      order = spar_macroprocess_treelist (sparp, order, 0, &ctx);
      limit = spar_macroprocess_tree (sparp, limit, &ctx);
      offset = spar_macroprocess_tree (sparp, offset, &ctx);
    }
  do { /* Special case for selection of all distinct graphs */
    SPART *grp, *triple, *retvar, *gvar;
    caddr_t retname, gname;
    int ctr1, ctr2;
    if (NULL != sparp->sparp_env->spare_parent_env) break;
    if (DISTINCT_L != subtype) break;
    if (NULL != sparp->sparp_env->spare_src.ssrc_named_graphs) break;
    if (!IS_BOX_POINTER (retvals)) break;
    if (1 != BOX_ELEMENTS (retvals)) break;
    if (0 != BOX_ELEMENTS_0 (groupings)) break;
    if (0 != BOX_ELEMENTS_0 (order)) break;
    if (NULL != binv) break;
    if (0 != BOX_ELEMENTS_0 (pattern->_.gp.filters)) break;
    if (1 != BOX_ELEMENTS (pattern->_.gp.members)) break;
    if (0 != BOX_ELEMENTS_0 (pattern->_.gp.options)) break;
    grp = pattern->_.gp.members[0];
    if (0 != grp->_.gp.subtype) break;
    if (0 != BOX_ELEMENTS_0 (grp->_.gp.filters)) break;
    if (1 != BOX_ELEMENTS (grp->_.gp.members)) break;
    if (0 != BOX_ELEMENTS_0 (grp->_.gp.options)) break;
    triple = grp->_.gp.members[0];
    if (SPAR_TRIPLE != triple->type) break;
    if (0 != BOX_ELEMENTS_0 (triple->_.triple.options)) break;
    gvar = triple->_.triple.tr_graph;
    for (ctr1 = 0; ctr1 < SPART_TRIPLE_FIELDS_COUNT; ctr1++)
      {
        SPART *fld = triple->_.triple.tr_fields[ctr1];
        if (SPAR_VARIABLE != SPART_TYPE (fld)) break;
        if (SPART_VARNAME_IS_GLOB (fld->_.var.vname)) break;
        for (ctr2 = 0; ctr2 < ctr1; ctr2++)
          if (!strcmp (triple->_.triple.tr_fields[ctr2]->_.var.vname, fld->_.var.vname))
            break;
        if (ctr2 < ctr1) break;
      }
    if (ctr1 < SPART_TRIPLE_FIELDS_COUNT) break;
    if (SPAR_VARIABLE != SPART_TYPE (triple->_.triple.tr_predicate)) break;
    if (SPAR_VARIABLE != SPART_TYPE (triple->_.triple.tr_subject)) break;
    if (SPAR_VARIABLE != SPART_TYPE (triple->_.triple.tr_object)) break;
    if (SPAR_ALIAS == SPART_TYPE (retvals[0]))
      {
        retvar = retvals[0]->_.alias.arg;
        retname = retvals[0]->_.alias.aname;
      }
    else
      {
        retvar = retvals[0];
        retname = retvar->_.var.vname;
      }
    if (SPAR_VARIABLE != SPART_TYPE (retvar)) break;
    gname = gvar->_.var.vname;
    if (strcmp (gname, retvar->_.var.vname)) break;
    return spartlist (sparp, 8, SPAR_CODEGEN,
      t_box_num ((ptrlong)(ssg_select_known_graphs_codegen)),
      sparp->sparp_sg->sg_output_valmode_name,	/* #2 */
      sparp->sparp_sg->sg_output_format_name,	/* #3 */
      retname,					/* #4 */
      pattern->_.gp.selid,			/* #5 */
      limit,					/* #6 */
      offset );					/* #7 */
    } while (0);
/* The default is, of course, a plain query */
  return spar_make_top (sparp, subtype, retvals, pattern, groupings, having, order, limit, offset, binv);
}

SPART *
spar_make_bindings_inv_with_fake_equivs (sparp_t *sparp, SPART **vars, SPART ***data_rows, SPART *wrapper_gp)
{
  int varcount = BOX_ELEMENTS (vars);
  int rowcount = BOX_ELEMENTS (data_rows);
  int varctr, rowctr;
  char *data_rows_mask = (char *)t_alloc_box (rowcount+1, DV_STRING);
  ptrlong *counters_of_unbound = (ptrlong *)t_alloc_box (varcount * sizeof (ptrlong), DV_STRING);
  SPART *binv = spartlist (sparp, 8, SPAR_BINDINGS_INV, 0, vars, data_rows, data_rows_mask, counters_of_unbound, (ptrlong)rowcount, (ptrlong)0);
  memset (data_rows_mask, '/', rowcount);
  for (varctr = varcount; varctr--; /* no step */)
    {
      int counter_of_unbound = 0;
      for (rowctr = rowcount; rowctr--; /* no step */)
        {
          if (NULL == data_rows[rowctr][varctr])
            counter_of_unbound++;
        }
      counters_of_unbound[varctr] = counter_of_unbound;
    }
  spar_refresh_binv_var_rvrs (sparp, binv);
  if (NULL != wrapper_gp)
    {
      wrapper_gp->_.gp.equiv_indexes = (ptrlong *)t_alloc_box (varcount * sizeof (ptrlong), DV_ARRAY_OF_LONG);
      wrapper_gp->_.gp.equiv_count = varcount;
    }
  for (varctr = 0; varctr < varcount; varctr++)
    {
      SPART *var = vars[varctr];
      sparp_equiv_t *eq = sparp_equiv_alloc (sparp);
      eq->e_varnames = (caddr_t *)t_list (1, var->_.var.vname);
      eq->e_vars = (SPART **)t_list (1, var);
      eq->e_var_count = 1;
      eq->e_nested_bindings = 1; /* fake, to not reset rvr to conflict */
      sparp_rvr_copy (sparp, &(eq->e_rvr), &(var->_.var.rvr));
      var->_.var.equiv_idx = eq->e_own_idx;
      if (NULL == wrapper_gp)
        {
          eq->e_gp = binv;
          eq->e_const_reads = 1;
        }
      else
        {
          eq->e_gp = wrapper_gp;
          eq->e_vars[0]->_.var.selid = wrapper_gp->_.gp.selid;
          wrapper_gp->_.gp.equiv_indexes[varctr] = eq->e_own_idx;
        }
    }
  return binv;
}

SPART **
spar_make_sources_like_top (sparp_t *sparp, ptrlong top_subtype)
{
  sparp_env_t *env = sparp->sparp_env;
  dk_set_t src = NULL;
  SPART **sources;
  DO_SET(SPART *, g, &(env->spare_src.ssrc_default_graphs))
    {
      t_set_push (&src, sparp_tree_full_copy (sparp, g, NULL));
    }
  END_DO_SET()
  DO_SET(SPART *, g, &(env->spare_src.ssrc_named_graphs))
    {
      t_set_push (&src, sparp_tree_full_copy (sparp, g, NULL));
    }
  END_DO_SET()
  sources = (SPART **)t_revlist_to_array (src);
#if 0
  if ((0 == BOX_ELEMENTS (sources)) &&
    (NULL != (env->spare_src.ssrc_common_sponge_options)) &&
    (LOAD_L != top_subtype) )
    spar_error (sparp, "Retrieval options for source graphs (e.g., '%s') may be useless if the query does not contain 'FROM' or 'FROM NAMED'", env->spare_src.ssrc_common_sponge_options->data);
#endif
  return sources;
}

SPART *
spar_make_top (sparp_t *sparp, ptrlong subtype, SPART **retvals,
  SPART *pattern, SPART **groupings, SPART *having, SPART **order, SPART *limit, SPART *offset, SPART *binv)
{
  sparp_env_t *env = sparp->sparp_env;
  sparp_globals_t *sg = sparp->sparp_sg;
  caddr_t final_output_format_name;
  caddr_t orig_selid;
  SPART **sources = spar_make_sources_like_top (sparp, subtype);
  if ((NULL != env->spare_parent_env) || (sparp->sparp_env->spare_disable_output_formatting))
    final_output_format_name = NULL;
  else
    switch (subtype)
      {
      case CONSTRUCT_L: case DESCRIBE_L:
        final_output_format_name = ((NULL != sg->sg_output_dict_format_name) ? sg->sg_output_dict_format_name : sg->sg_output_format_name);
        break;
      case ASK_L:
        final_output_format_name = ((NULL != sg->sg_output_scalar_format_name) ? sg->sg_output_scalar_format_name : sg->sg_output_format_name);
        break;
      default:
        final_output_format_name = sg->sg_output_format_name;
        break;
      }
  if (NULL != sparp->sparp_sg->sg_output_maxrows)
    {
      boxint hard_lim = unbox (sparp->sparp_sg->sg_output_maxrows);
      if (DV_LONG_INT == DV_TYPE_OF (limit))
        {
          if (unbox ((caddr_t)limit) > hard_lim)
            limit = (SPART *)t_box_num_nonull (hard_lim);
        }
      else
        limit = spar_make_funcall (sparp, 0, "bif:__max", (SPART **)t_list (2, limit, t_box_num_nonull (hard_lim)));
    }
  orig_selid = pattern->_.gp.selid;
  return spartlist (sparp, 17, SPAR_REQ_TOP, subtype,
    ((NULL != env->spare_parent_env) ? t_box_dv_short_string ("AUTO") : sg->sg_output_valmode_name),
    final_output_format_name,
    t_box_copy (env->spare_storage_name),
    retvals, /* NULL, orig_retvals */ NULL /* expanded_orig_retvals */, orig_selid,
    sources, pattern, groupings, having, order,
    limit, offset, binv, t_box_num ((ptrlong)(env)) );
}

SPART *
spar_gp_add_union_of_triple_and_inverses (sparp_t *sparp, SPART *graph, SPART *subject, SPART *predicate, SPART *object, SPART **qm_iri_or_pair, SPART **options, int banned_tricks, dk_set_t inv_props)
{
  SPART *triple, *gp, *union_gp;
  rdf_inf_ctx_t *saved_inf = sparp->sparp_env->spare_inference_ctx;
  spar_gp_init (sparp, UNION_L);
  spar_gp_init (sparp, 0);
  if (NULL != options)
    spar_error (sparp, "Options are not supported for a triple pattern with property name \"%.200s\" that is declared in inference rules \"%.200s\" as a property with inverse",
      predicate->_.qname.val, sparp->sparp_env->spare_inference_name );
  sparp->sparp_env->spare_inference_ctx = NULL;
  triple = spar_gp_add_triplelike (sparp, graph, subject, predicate, object, qm_iri_or_pair, options, banned_tricks | SPAR_TRIPLE_TRICK_INV_UNION);
  if (SPAR_TRIPLE != SPART_TYPE (triple))
    spar_error (sparp, "Property name \"%.200s\" has special meaning that conflicts with its declaration in inference rules \"%.200s\" as a property with inverse",
      predicate->_.qname.val, sparp->sparp_env->spare_inference_name );
  if (NULL != options)
    sparp_validate_options_of_tree (sparp, triple, options);
  gp = spar_gp_finalize (sparp, NULL);
  spar_gp_add_member (sparp, gp);
  while (NULL != inv_props)
    {
      caddr_t inv_p_name = t_box_dv_uname_string ((ccaddr_t)t_set_pop (&inv_props));
      spar_gp_init (sparp, 0);
      triple = spar_gp_add_triplelike (sparp,
        (SPART *)t_full_box_copy_tree ((caddr_t)graph),
        (SPART *)t_full_box_copy_tree ((caddr_t)object), /* object is swapped with subject*/
        (SPART *)t_full_box_copy_tree ((caddr_t)predicate),
        (SPART *)t_full_box_copy_tree ((caddr_t)subject),
        sparp_treelist_full_copy (sparp, qm_iri_or_pair, NULL),
        (SPART **)t_full_box_copy_tree ((caddr_t)options),
        banned_tricks | SPAR_TRIPLE_TRICK_INV_UNION );
      if (SPAR_TRIPLE != SPART_TYPE (triple))
        spar_error (sparp, "Property name \"%.200s\" has special meaning but it is declared in inference rules \"%.200s\" as an inverse property of \"%.200s\"",
          inv_p_name, sparp->sparp_env->spare_inference_name, predicate->_.qname.val );
      triple->_.triple.tr_predicate->_.qname.val = inv_p_name;
      if (SPAR_IS_BLANK_OR_VAR (triple->_.triple.tr_object))
        triple->_.triple.tr_object->_.var.rvr.rvrRestrictions &= ~SPART_VARR_IS_REF;
      gp = spar_gp_finalize (sparp, NULL);
      spar_gp_add_member (sparp, gp);
    }
  union_gp = spar_gp_finalize (sparp, NULL);
  spar_gp_add_member (sparp, union_gp);
  sparp->sparp_env->spare_inference_ctx = saved_inf;
  return union_gp;
}

static void
spar_gp_add_transitive_triple_anchor_filter (sparp_t *sparp, caddr_t fld_vname, SPART *orig_fld, int orig_fld_is_plain_var)
{
  SPART *filt;
  if (!orig_fld_is_plain_var)
    filt = spartlist (sparp, 3, BOP_EQ, spar_make_variable (sparp, fld_vname), orig_fld);
  else
#if 0
    filt = spar_make_funcall (sparp, 0, "sparql_only:args_in_same_eq",
      (SPART **)t_list (2, spar_make_variable (sparp, fld_vname), spar_make_variable (sparp, orig_fld->_.var.vname)) );
#else
    filt = spartlist (sparp, 3, SPAR_BOP_EQNAMES, spar_make_variable (sparp, fld_vname), spar_make_variable (sparp, orig_fld->_.var.vname));
#endif
  spar_gp_add_filter (sparp, filt, 0);
}

SPART *
spar_gp_add_transitive_triple (sparp_t *sparp, SPART *graph, SPART *subject, SPART *predicate, SPART *object, SPART **qm_iri_or_pair, SPART **options, int banned_tricks)
{
#ifdef DEBUG
  sparp_env_t *saved_env = sparp->sparp_env;
  dk_set_t movable_filters_stack = sparp->sparp_env->spare_acc_movable_filters;
  dk_set_t local_filters_stack = sparp->sparp_env->spare_acc_local_filters;
  dk_set_t members_stack = sparp->sparp_env->spare_acc_triples;
#endif
  SPART *subselect_top, *where_gp, *wrapper_gp, *fields[4];
  SPART *subj_var, *obj_var, **retvals;
  caddr_t subj_vname, obj_vname;
  char t_in_preset_fld = '\0';
  char t_out_preset_fld = '\0';
  int subj_is_plain_var = 0, obj_is_plain_var = 0, retvalctr, fld_ctr;
  int subj_stype = SPART_TYPE (subject);
  int obj_stype = SPART_TYPE (object);
  if (SPAR_VARIABLE == subj_stype)
    subj_is_plain_var = SPART_VARNAME_IS_PLAIN(subject->_.var.vname);
  else if (SPAR_QNAME != subj_stype)
    spar_error (sparp, "Subject of transitive triple pattern should be variable or QName, not literal or blank node");
  if (SPAR_VARIABLE == obj_stype)
    obj_is_plain_var = SPART_VARNAME_IS_PLAIN(object->_.var.vname);
  else if ((SPAR_QNAME != obj_stype) && (SPAR_LIT != obj_stype))
    spar_error (sparp, "Object of transitive triple pattern should be variable or QName or literal, not blank node");
  if ((NULL == graph) && (NULL != sparp->sparp_env->spare_context_graphs))
    graph = (SPART *)t_box_copy_tree ((caddr_t)(sparp->sparp_env->spare_context_graphs->data));
  subj_vname = spar_mkid (sparp, "_::trans_subj");
  obj_vname = spar_mkid (sparp, "_::trans_obj");
  spar_gp_init (sparp, 0);
  spar_env_push (sparp);
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
  retvals = (SPART **)t_alloc_list (retvalctr);
  retvalctr = 0;
  for (fld_ctr = 0; fld_ctr < 4; fld_ctr++)
    {
      SPART *rval = NULL;
      switch (SPART_TYPE (fields[fld_ctr]))
        {
        case SPAR_BLANK_NODE_LABEL: rval = spar_make_blank_node (sparp, fields[fld_ctr]->_.var.vname, 0); break;
        case SPAR_VARIABLE: rval = spar_make_variable (sparp, fields[fld_ctr]->_.var.vname); break;
        }
      if (NULL != rval)
        retvals[retvalctr++] = rval;
    }
  if (0 == retvalctr)
    retvals[0] = (SPART *)t_box_num_nonull (1);
  t_set_push (&(sparp->sparp_env->spare_propvar_sets), NULL);
  spar_gp_init (sparp, WHERE_L);
  subj_var = spar_make_variable (sparp, subj_vname);
  obj_var = spar_make_variable (sparp, obj_vname);
  spar_gp_add_triplelike (sparp, graph, subj_var, predicate, obj_var, qm_iri_or_pair, NULL, banned_tricks | SPAR_TRIPLE_TRICK_TRANSITIVE);
  if (NULL != options)
    {
      int idx;
      for (idx = BOX_ELEMENTS_0 (options) - 2; idx >= 0; idx -= 2)
        {
          ptrlong key = ((ptrlong)(options [idx]));
          SPART *val = options [idx+1];
          switch (key)
            {
            case T_IN_L: case T_OUT_L:
              {
                char *t_x_preset_fld_ptr = ((T_IN_L == key) ? &t_in_preset_fld : &t_out_preset_fld);
                SPART *v;
                if (1 != BOX_ELEMENTS (val->_.list.items))
                  spar_error (sparp, "T_IN and T_OUT options of a triple pattern should contain only single variables");
                v = val->_.list.items[0];
                if (subj_is_plain_var && !strcmp (subject->_.var.vname, v->_.var.vname))
                  {
                    val->_.list.items[0] = spar_make_variable (sparp, subj_vname);
                    t_x_preset_fld_ptr[0] = 'S';
                  }
                else if (obj_is_plain_var && !strcmp (object->_.var.vname, v->_.var.vname))
                  {
                    val->_.list.items[0] = spar_make_variable (sparp, obj_vname);
                    t_x_preset_fld_ptr[0] = 'O';
                  }
                else
                  spar_error (sparp, "T_IN and T_OUT options of a triple pattern should contain only subject/object variables of the triple pattern, not something else");
                continue;
              }
            case T_STEP_L:
              {
                SPART *arg = val->_.alias.arg;
                if (SPAR_VARIABLE == SPART_TYPE (arg))
                  {
                    caddr_t vname = arg->_.var.vname;
                    if (subj_is_plain_var && !strcmp (subject->_.var.vname, vname))
                      val->_.alias.arg = spar_make_variable (sparp, subj_vname);
                    else if (obj_is_plain_var && !strcmp (object->_.var.vname, vname))
                      val->_.alias.arg = spar_make_variable (sparp, obj_vname);
                  }
                continue;
              }
            }
        }
    }
  if ((('\0' != t_in_preset_fld) ? 1 : 0) != (('\0' != t_out_preset_fld) ? 1 : 0))
    spar_error (sparp, "T_IN and T_OUT options of a transitive triple pattern should be either both set or both not set");
  if ('\0' != t_in_preset_fld)
    {
      if (t_in_preset_fld == t_out_preset_fld)
        spar_error (sparp, "T_IN and T_OUT options of a transitive triple points to same field, but one should point to subject and another one to the object");
    }
  else
    {
      sparp_set_option (sparp, &options, T_IN_L,
        spartlist (sparp, 2, SPAR_LIST, t_list (1, spar_make_variable (sparp, subj_vname))),
        SPARP_SET_OPTION_REPLACING );
      sparp_set_option (sparp, &options, T_OUT_L,
        spartlist (sparp, 2, SPAR_LIST, t_list (1, spar_make_variable (sparp, obj_vname))),
        SPARP_SET_OPTION_REPLACING );
    }
  where_gp = spar_gp_finalize (sparp, NULL);
  subselect_top = spar_make_top (sparp, SELECT_L, retvals,
    where_gp,
    (SPART **)NULL, (SPART *)NULL, (SPART **)NULL, (SPART *)NULL /* i.e., no limit */, (SPART *)t_box_num_nonull (0), NULL);
  sparp_expand_top_retvals (sparp, subselect_top, 1 /* safely_copy_all_vars */, NULL);
  spar_env_pop (sparp);
  t_check_tree (options);
  wrapper_gp = spar_gp_finalize_with_subquery (sparp, options, subselect_top);
  spar_gp_add_member (sparp, wrapper_gp);
  spar_gp_add_transitive_triple_anchor_filter (sparp, subj_vname, subject, subj_is_plain_var);
  spar_gp_add_transitive_triple_anchor_filter (sparp, obj_vname, object, obj_is_plain_var);
#ifdef DEBUG
  if (saved_env != sparp->sparp_env)
    spar_internal_error (sparp, "spar_" "gp_add_transitive_triple(): mismatch in env");
  if (movable_filters_stack != sparp->sparp_env->spare_acc_movable_filters)
    spar_internal_error (sparp, "spar_" "gp_add_transitive_triple(): mismatch in movable filters");
  if (local_filters_stack != sparp->sparp_env->spare_acc_local_filters)
    spar_internal_error (sparp, "spar_" "gp_add_transitive_triple(): mismatch in local filters");
  if (members_stack != sparp->sparp_env->spare_acc_triples)
    spar_internal_error (sparp, "spar_" "gp_add_transitive_triple(): mismatch in triples");
#endif
  return wrapper_gp;
}


#if 0
SPART *
spar_const_g_for_defm_search (sparp_env_t *env)
{
  SPART *g = NULL;
  dk_set_t *dflts;
  if (env->spare_context_graphs)
    {
      g = (SPART *)t_box_copy_tree (env->spare_context_graphs->data);
      goto g_found; /* see below*/
    }
  dflts = env->spare_src.ssrc_default_graphs;
/* Special case: if no FROM clauses specified but there are some FROM NAMED then default graph is totally empty.
So that's conflict for plain triple, but the processing of a graph-insensitive macro can not be cancelled because the body of macro could be
GRAPH <vald_named_graph> { ... } */
  if ((NULL == dflts) && (NULL != env->spare_src.ssrc_named_graphs))
    return NULL;
  if ((NULL != dflts) && (SPART_GRAPH_FROM == ((SPART *)(dflts->data))->_.graph.subtype) &&
     ((NULL == dflts->next) || (SPART_GRAPH_MIN_NEGATION <= ((SPART *)(dflts->next->data))->_.graph.subtype)) )
    { /* If there's only one default graph then we can cheat and optimize the query a little bit by adding a restriction to the variable */
      SPART *single_dflt = (SPART *)(dflts->data);
      caddr_t g_iri = single_dflt->_.graph.iri;
      if (!SPAR_IS_LIT_OR_QNAME (single_dflt->_.graph.expn) && (NULL != g_iri))	 /* FROM iriref OPTION (...) case */
        g = g_iri;
      else
        g = single_dflt->_.graph.expn;
    }
g_found:
  if (SPAR_IS_LIT_OR_QNAME (g))
    return g;
  return NULL;
}
#endif

SPART *
spar_gp_add_ppath_leaf (sparp_t *sparp,  SPART **parts, int part_count, int pp_makes_union, int pp_subtype, SPART *graph, SPART *subject, SPART *object, SPART **qm_iri_or_pair, int banned_tricks)
{
  SPART *res;
  graph = (SPART *)t_box_copy_tree ((caddr_t)graph);
  subject = (SPART *)t_box_copy_tree ((caddr_t)subject);
  object = (SPART *)t_box_copy_tree ((caddr_t)object);
  if (pp_makes_union)
    spar_gp_init (sparp, 0);
  if ((0 == pp_subtype) && (1 == part_count) && ((SPART *)_STAR != parts[0]))
    res = spar_gp_add_triplelike (sparp, graph, subject, parts[0], object, qm_iri_or_pair, NULL, banned_tricks);
  else
    {
      caddr_t pred_vname = spar_mkid (sparp, "_::ppath_p");
      SPART *filt;
      res = spar_gp_add_triplelike (sparp, graph, subject, spar_make_variable (sparp, pred_vname), object, qm_iri_or_pair, NULL, banned_tricks);
      if (1 == part_count)
        {
          if ((SPART *)_STAR != parts[0])
            filt = spartlist (sparp, 3, ((0 == pp_subtype) ? BOP_EQ : BOP_NEQ), spar_make_variable (sparp, pred_vname), parts[0]);
          else
            filt = NULL;
        }
      else if (1 < part_count)
        {
          SPART **p_and_qnames = (SPART **)t_alloc_list (1 + part_count);
          p_and_qnames[0] = spar_make_variable (sparp, pred_vname);
          memcpy (p_and_qnames + 1, parts, part_count * sizeof (SPART *));
          filt = sparp_make_builtin_call (sparp, IN_L, p_and_qnames);
          if ('!' == pp_subtype)
            filt = spartlist (sparp, 3, BOP_NOT, filt, NULL);
        }
      else
        filt = NULL;
      if (NULL != filt)
        spar_gp_add_filter (sparp, filt, 0);
    }
  if (pp_makes_union)
    {
      res = spar_gp_finalize (sparp, NULL);
      spar_gp_add_member (sparp, res);
    }
  return res;
}

SPART *
sparp_find_first_transitive_step_in_path (SPART *pp)
{
  SPART **parts = pp->_.ppath.parts;
  int part_ctr, part_count = BOX_ELEMENTS (parts);
  switch (pp->_.ppath.subtype)
    {
    case '/': case '|': case 'D':
      for (part_ctr = 0; part_ctr < part_count; part_ctr++)
        {
          SPART *hit = sparp_find_first_transitive_step_in_path (parts[part_ctr]);
          if (NULL != hit)
            return hit;
        }
    case '*': return pp;
    default: break;
    }
  return NULL;
}

SPART *
spar_gp_add_ppath_triples (sparp_t *sparp, SPART *graph, SPART *subject, SPART *pp, SPART *object, SPART **qm_iri_or_pair, int banned_tricks)
{
  ptrlong parent_gp_subtype = (ptrlong)(sparp->sparp_env->spare_context_gp_subtypes->data);
  SPART **parts = pp->_.ppath.parts;
  int part_ctr, part_count = BOX_ELEMENTS (parts);
  SPART *res = NULL;
  switch (pp->_.ppath.subtype)
    {
    case 0: case '!':
      {
        int rev_count = pp->_.ppath.num_of_invs;
        int fwd_count = part_count - rev_count;
        int pp_makes_union = (rev_count || fwd_count);
        int wrapper_gp_needed = 0;
        if ((pp_makes_union ? 1 : 0) != ((UNION_L == parent_gp_subtype) ? 1 : 0))
          wrapper_gp_needed = 1;
        if (wrapper_gp_needed)
          spar_gp_init (sparp, pp_makes_union ? UNION_L : 0);
        if (fwd_count)
          spar_gp_add_ppath_leaf (sparp, parts, fwd_count, pp_makes_union, pp->_.ppath.subtype, graph, subject, object, qm_iri_or_pair, banned_tricks);
        if (rev_count)
          spar_gp_add_ppath_leaf (sparp, parts + fwd_count, rev_count, pp_makes_union, pp->_.ppath.subtype, graph, object /* yes, before subject, this makes the reverse */, subject, qm_iri_or_pair, banned_tricks);
        if (wrapper_gp_needed)
          {
            res = spar_gp_finalize (sparp, NULL);
            spar_gp_add_member (sparp, res);
          }
        return res;
      }
    case '/':
      {
        int join_gp_needed = !((0 == parent_gp_subtype) || (WHERE_L == parent_gp_subtype) || (OPTIONAL_L == parent_gp_subtype));
        SPART *subj_connection = subject, *obj_connection;
        if (join_gp_needed)
          spar_gp_init (sparp, 0);
        for (part_ctr = 0; part_ctr < part_count; part_ctr++)
          {
            if ((part_count - 1) == part_ctr)
              obj_connection = object;
            else
              obj_connection = spar_make_variable (sparp, spar_mkid (sparp, "_::ppath_seq"));
            res = spar_gp_add_ppath_triples (sparp, graph, subj_connection, parts[part_ctr], obj_connection, qm_iri_or_pair, banned_tricks);
            subj_connection = obj_connection;
          }
        if (join_gp_needed)
          {
            res = spar_gp_finalize (sparp, NULL);
            spar_gp_add_member (sparp, res);
          }
        return res;
      }
    case '|': case 'D':
      {
        int union_needed = ((UNION_L != parent_gp_subtype) || ('D' == pp->_.ppath.subtype));
        if (union_needed)
          spar_gp_init (sparp, UNION_L);
        for (part_ctr = 0; part_ctr < part_count; part_ctr++)
          res = spar_gp_add_ppath_triples (sparp, graph, subject, parts[part_ctr], object, qm_iri_or_pair, banned_tricks);
        if (union_needed)
          {
            res = spar_gp_finalize (sparp, NULL);
            spar_gp_add_member (sparp, res);
          }
        return res;
      }
    case '*':
      {
        int wrapper_gp_needed = !((0 == parent_gp_subtype) || (WHERE_L == parent_gp_subtype) || (OPTIONAL_L == parent_gp_subtype));
        SPART *part0 = pp->_.ppath.parts[0];
        SPART *res;
        dk_set_t opts = NULL;
        boxint minrepeat_num = unbox (pp->_.ppath.minrepeat);
        boxint maxrepeat_num = unbox (pp->_.ppath.maxrepeat);
        if (-1 != maxrepeat_num)
          {
            t_set_push (&opts, t_box_num_nonull (maxrepeat_num));
            t_set_push (&opts, (caddr_t)((ptrlong)T_MAX_L));
          }
        if (1 != minrepeat_num)
          {
            t_set_push (&opts, t_box_num_nonull (minrepeat_num));
            t_set_push (&opts, (caddr_t)((ptrlong)T_MIN_L));
          }
        t_set_push (&opts, (caddr_t)((ptrlong)1));
        t_set_push (&opts, (caddr_t)((ptrlong)T_NO_CYCLES_L));
        t_set_push (&opts, (caddr_t)((ptrlong)1));
        t_set_push (&opts, (caddr_t)((ptrlong)TRANSITIVE_L));
        if (wrapper_gp_needed)
          spar_gp_init (sparp, 0);
        res = spar_gp_add_transitive_triple (sparp, graph, subject, part0, object, qm_iri_or_pair, (SPART **)t_list_to_array (opts), banned_tricks);
        if (wrapper_gp_needed)
          {
            res = spar_gp_finalize (sparp, NULL);
            spar_gp_add_member (sparp, res);
          }
        return res;
      }
    }
  spar_internal_error (sparp, "spar_gp_add_ppath_triples(): unsupported type of property path");
  return NULL; /* to keep compiler happy */
}

ptrlong sparp_tr_usage_natural_restrictions[SPART_TRIPLE_FIELDS_COUNT] = {
  SPART_VARR_IS_REF | SPART_VARR_IS_IRI | SPART_VARR_NOT_NULL,	/* graph	*/
  SPART_VARR_IS_REF | SPART_VARR_NOT_NULL,			/* subject	*/
  SPART_VARR_IS_REF | SPART_VARR_NOT_NULL,			/* predicate	*/
  SPART_VARR_NOT_NULL };					/* object	*/

int
spar_inf_tricks_for_pred (sparp_t *sparp, caddr_t p_name, rdf_inf_ctx_t *inf_ctx, int banned_tricks, dk_set_t *inv_names_ret)
{
  caddr_t *propprops;
  caddr_t *invlist;
  int res = 0;
  if (NULL == inf_ctx)
    return 0;
  propprops = inf_ctx->ric_prop_props;
  invlist = inf_ctx->ric_inverse_prop_pair_sortedalist;
  if ((NULL != propprops) && !(SPAR_TRIPLE_TRICK_TRANSITIVE & banned_tricks))
    {
      int propproplen = BOX_ELEMENTS (propprops);
      int pp_pos = ecm_find_name (p_name, propprops, propproplen/2, 2 * sizeof (caddr_t));
      if (ECM_MEM_NOT_FOUND != pp_pos)
        {
          ptrlong flags = (ptrlong)(propprops[pp_pos * 2 + 1]);
          if (1 & flags)
            res |= SPAR_TRIPLE_TRICK_TRANSITIVE;
        }
    }
  if ((NULL != invlist) && !(SPAR_TRIPLE_TRICK_INV_UNION & banned_tricks))
    {
      int invlistlen = BOX_ELEMENTS (invlist);
      int inv_pos = ecm_find_name (p_name, invlist, invlistlen/2, 2 * sizeof (caddr_t));
      if (ECM_MEM_NOT_FOUND != inv_pos)
        { /* There may be many inverse predicates for a single given one and ecm_find_name may point to any of pairs */
          while ((0 < inv_pos) && !strcmp (invlist[(inv_pos-1) * 2], p_name))
            inv_pos--;
          t_set_push (inv_names_ret, invlist [1 + 2 * inv_pos]);
          while ((((inv_pos+1) * 2) < invlistlen) && !strcmp (invlist[(inv_pos+1) * 2], p_name))
            t_set_push (inv_names_ret, invlist [1 + 2 * ++inv_pos]);
          res |= SPAR_TRIPLE_TRICK_INV_UNION;
        }
    }
  return res;
}

SPART *
spar_gp_make_graph_field_from_context (sparp_t *sparp, SPART **ret_graph_eq_from_option_expn, int *ret_graph_can_bring_filters)
{
  sparp_env_t *env = sparp->sparp_env;
  SPART *graph;
  ret_graph_eq_from_option_expn[0] = NULL;
  ret_graph_can_bring_filters[0] = 0;
  for (;;)
    {
      dk_set_t dflts;
      if (env->spare_context_graphs)
        {
          graph = (SPART *)t_box_copy_tree ((caddr_t)(env->spare_context_graphs->data));
          return graph;
        }
      dflts = env->spare_src.ssrc_default_graphs;
      if ((NULL == dflts) && (NULL != env->spare_src.ssrc_named_graphs))
        { /* Special case: if no FROM clauses specified but there are some FROM NAMED then default graph is totally empty */
          graph = spar_make_blank_node (sparp, spar_mkid (sparp, "_::default"), 2);
          SPARP_DEBUG_WEIRD(sparp,"conflict");
          graph->_.var.rvr.rvrRestrictions |= SPART_VARR_CONFLICT;
          return graph;
        }
      if ((NULL != dflts) && (SPART_GRAPH_FROM == ((SPART *)(dflts->data))->_.graph.subtype) &&
         ((NULL == dflts->next) || (SPART_GRAPH_MIN_NEGATION <= ((SPART *)(dflts->next->data))->_.graph.subtype)) )
        { /* If there's only one default graph then we can cheat and optimize the query a little bit by adding a restriction to the variable */
          SPART *single_dflt = (SPART *)(dflts->data);
          if (!SPAR_IS_LIT_OR_QNAME (single_dflt->_.graph.expn))	 /* FROM iriref OPTION (...) case */
            {
              caddr_t iri_arg = single_dflt->_.graph.iri;
              graph = spar_make_blank_node (sparp, spar_mkid (sparp, "_::default"), 2);
              ret_graph_eq_from_option_expn[0] = spartlist (sparp, 3, BOP_EQ, sparp_tree_full_copy (sparp, graph, NULL), sparp_tree_full_copy (sparp, single_dflt->_.graph.expn, NULL));
              if (NULL != iri_arg)
                {
                  graph->_.var.rvr.rvrRestrictions |= SPART_VARR_FIXED | SPART_VARR_IS_REF | SPART_VARR_NOT_NULL;
                  graph->_.var.rvr.rvrFixedValue = t_box_copy (iri_arg);
                }
            }
          else /* Single FROM iriref without sponge options */
            graph = sparp_tree_full_copy (sparp, single_dflt->_.graph.expn, NULL);
          if (NULL == dflts->next) /* There's only one source and it is reflected in the value of graph */
            return graph;
        }
      else
        graph = spar_make_blank_node (sparp, spar_mkid (sparp, "_::default"), 2);
      ret_graph_can_bring_filters[0] = 1;
      return graph;
    }
}

SPART *
spar_gp_add_triplelike (sparp_t *sparp, SPART *graph, SPART *subject, SPART *predicate, SPART *object, SPART **qm_iri_or_pair, SPART **options, int banned_tricks)
{
  sparp_env_t *env = sparp->sparp_env;
  rdf_inf_ctx_t *inf_ctx = sparp->sparp_env->spare_inference_ctx;
  SPART *graph_eq_from_option_expn = NULL;
  int graph_can_bring_filters = 0;
  SPART *triple;
  if (NULL == subject)
    subject = (SPART *)t_box_copy_tree ((caddr_t)(env->spare_context_subjects->data));
  if (NULL == predicate)
    predicate = (SPART *)t_box_copy_tree ((caddr_t)(env->spare_context_predicates->data));
  if (NULL == object)
    object = (SPART *)t_box_copy_tree ((caddr_t)(env->spare_context_objects->data));
  if (CONSTRUCT_L == SPARP_ENV_CONTEXT_GP_SUBTYPE(sparp))
    {
      if ((NULL == graph) && (NULL != env->spare_context_graphs))
        {
          graph = (SPART *)t_box_copy_tree ((caddr_t)(env->spare_context_graphs->data));
        }
      if (NULL == graph)
        {
          graph = spar_make_blank_node (sparp, spar_mkid (sparp, "_::default"), 2);
          env->spare_ctor_dflt_g_tmpl_count++;
        }
      if (SPAR_PPATH == SPART_TYPE (predicate))
        spar_error (sparp, "Property paths are not allowed in constructor templates");
      goto plain_triple_in_ctor; /* see below */
    }
  if (NULL == qm_iri_or_pair)
    {
      if (NULL == env->spare_context_qms)
        qm_iri_or_pair = (SPART **)t_list (2, NULL, ((ptrlong)_STAR));
      else
        qm_iri_or_pair = (SPART **)(env->spare_context_qms->data);
      if (NULL != env->spare_context_sinvs)
        {
          SPART *inner_sinv = (SPART *)(env->spare_context_sinvs->data);
          qm_iri_or_pair[0] = (SPART *)t_box_num_nonull (inner_sinv->_.sinv.own_idx);
        }
    }
  if (NULL != options)
    {
      caddr_t inf_name = (caddr_t)sparp_get_option (sparp, options, INFERENCE_L);
      if (NULL != inf_name)
        {
          if (IS_BOX_POINTER(inf_name))
            {
              rdf_inf_ctx_t ** place = (rdf_inf_ctx_t **) id_hash_get (rdf_name_to_ric, (caddr_t)&inf_name);
              if (NULL == place)
                spar_error (sparp, "'OPTION (INFERENCE \"%.30s\") refers to undefined inference rule set", inf_name);
              inf_ctx = place[0];
            }
          else
            inf_ctx = NULL;
        }
    }
  if (NULL != options)
    {
      SPART *trans = sparp_get_option (sparp, options, TRANSITIVE_L);
      if ((NULL != trans) && !(SPAR_TRIPLE_TRICK_TRANSITIVE & banned_tricks))
        return spar_gp_add_transitive_triple (sparp, graph, subject, predicate, object, qm_iri_or_pair, options, SPAR_TRIPLE_TRICK_TRANSITIVE | banned_tricks);
    }
  if (SPAR_PPATH == SPART_TYPE (predicate))
    {
      int expand_ppath_to_triples = 1;
      if (NULL != options)
        spar_error (sparp, "OPTION (...) clause is not applicable to a pattern with property path");
      if (NULL != sparp->sparp_env->spare_context_sinvs)
        {
          SPART *sinv = (SPART *)(sparp->sparp_env->spare_context_sinvs->data);
          boxint status = unbox (sinv->_.sinv.syntax);
          if (status & SSG_SD_SPARQL11_MORE)
            expand_ppath_to_triples = 0;
          else if (!(status & SSG_SD_TRANSIT))
            {
              int path_has_trans = (NULL != sparp_find_first_transitive_step_in_path (predicate));
              if (path_has_trans)
                expand_ppath_to_triples = 0;
            }
        }
      if (expand_ppath_to_triples)
        return spar_gp_add_ppath_triples (sparp, graph, subject, predicate, object, qm_iri_or_pair, banned_tricks | SPAR_TRIPLE_TRICK_TRANSITIVE | SPAR_TRIPLE_TRICK_INV_UNION | SPAR_TRIPLE_TRICK_MACRO);
    }
  if ((NULL != inf_ctx) && (SPAR_QNAME == SPART_TYPE (predicate)))
    {
      dk_set_t inv_names = NULL;
      int tricks = spar_inf_tricks_for_pred (sparp, predicate->_.qname.val, inf_ctx, banned_tricks, &inv_names);
      if (SPAR_TRIPLE_TRICK_TRANSITIVE & tricks)
        {
          sparp_set_option (sparp, &options, TRANSITIVE_L, (SPART *)((ptrlong)1), SPARP_SET_OPTION_REPLACING);
          return spar_gp_add_transitive_triple (sparp, graph, subject, predicate, object, qm_iri_or_pair, options, SPAR_TRIPLE_TRICK_TRANSITIVE | banned_tricks);
        }
      if (SPAR_TRIPLE_TRICK_INV_UNION & tricks)
        return spar_gp_add_union_of_triple_and_inverses (sparp, graph, subject, predicate, object, qm_iri_or_pair, options, SPAR_TRIPLE_TRICK_INV_UNION | banned_tricks, inv_names);
    }
  if (SPAR_QNAME == SPART_TYPE (predicate))
    {
      caddr_t *spec_pred_names = jso_triple_get_objs (
        (caddr_t *)(sparp->sparp_sparqre->sparqre_qi),
        predicate->_.lit.val,
        uname_virtrdf_ns_uri_isSpecialPredicate );
      if (0 != BOX_ELEMENTS (spec_pred_names))
        {
          caddr_t pname = spec_pred_names[0];
          int is_geo = 0;
          if (NULL != options)
            {
              int ctr;
              sparp_validate_options_of_tree (sparp, NULL /*no tree*/, options);
              for (ctr = BOX_ELEMENTS (options) - 2; ctr >= 0; ctr -= 2)
                {
                  ptrlong option_id = (ptrlong)(options[ctr]);
                  SPART *option_value = options[ctr+1];
                  if ((GEO_L == option_id) || (PRECISION_L == option_id))
                    is_geo = 1;
                  if (SPAR_VARIABLE == SPART_TYPE (option_value))
                    option_value->_.var.rvr.rvrRestrictions |= SPART_VARR_IS_LIT;
                }
            }
          if (is_geo)
            {
              if (!strcmp ("bif:contains", pname) || !strcmp ("bif:spatial_contains", pname))
                pname = box_dv_uname_string ("bif:spatial_contains");
              else
                spar_error (sparp, "Spatial options can be used only with bif:contains and bif:spatial_contains special predicates, not with %.200s", pname);
            }
          spar_gp_add_filter (sparp,
            spar_make_funcall (sparp, 0, pname,
              t_spartlist_concat ((SPART **)t_list (2, subject, object), options) ), 0 );
          dk_free_tree ((caddr_t)spec_pred_names);
          return NULL;
        }
      dk_free_tree ((caddr_t)spec_pred_names);
    }
  if (NULL == graph)
    graph = spar_gp_make_graph_field_from_context (sparp, &graph_eq_from_option_expn, &graph_can_bring_filters);
  if (!(banned_tricks & SPAR_TRIPLE_TRICK_MACRO))
    {
      int ctr, argctr;
      SPART *match_defm = NULL;
      SPART *mcall, *fields[4];
      if (!sparp->sparp_storage_is_set)
        sparp_configure_storage_and_macro_libs (sparp);
      if (!sparp->sparp_macro_def_count)
        goto mcall_not_found; /* see below */
      fields[0] = graph;
      fields[1] = subject;
      fields[2] = predicate;
      fields[3] = object;
      match_defm = spar_find_defmacro_by_iri_or_fields (sparp, NULL, fields);
      if (NULL == match_defm)
        goto mcall_not_found; /* see below */
      mcall = sparp_make_macro_call (sparp, match_defm->_.defmacro.mname, 0,
        (SPART **)t_alloc_box (box_length (match_defm->_.defmacro.paramnames), DV_ARRAY_OF_POINTER) );
      argctr = 0;
      DO_BOX_FAST (SPART *, fld, ctr, match_defm->_.defmacro.quad_pattern)
        {
          if (SPAR_VARIABLE == SPART_TYPE (fld))
            mcall->_.macrocall.argtrees[argctr++] = fields[ctr];
        }
      END_DO_BOX_FAST;
      spar_gp_add_member (sparp, mcall);
      if (!(sparp->sparp_macro_mode & SPARP_DEFBODY))
        sparp->sparp_macro_call_count++;
      return mcall;
    }

mcall_not_found: ;
plain_triple_in_ctor:
  if (graph_can_bring_filters)
    spar_gp_add_filters_for_graph (sparp, graph, 0, 0);
  if (NULL != graph_eq_from_option_expn)
    spar_gp_add_filter (sparp, graph_eq_from_option_expn, 0);

  triple = spar_make_plain_triple (sparp, graph, subject, predicate, object, qm_iri_or_pair, options);
  if (NULL != options)
    sparp_validate_options_of_tree (sparp, triple, options);
  spar_gp_add_member (sparp, triple);
  return triple;
}

SPART *
spar_make_plain_triple (sparp_t *sparp, SPART *graph, SPART *subject, SPART *predicate, SPART *object, SPART **qm_iri_or_pair, SPART **options)
{
  sparp_env_t *env = sparp->sparp_env;
  int fctr;
  SPART *triple;
  triple = spartlist (sparp, 17, SPAR_TRIPLE,
    (ptrlong)0,
    graph, subject, predicate, object, qm_iri_or_pair,
    NULL /*selid*/, NULL /*tabid*/, NULL,
    NULL, NULL, NULL, NULL,
    options, (ptrlong)0, (ptrlong)((sparp->sparp_unictr)++) );
  if (CONSTRUCT_L == SPARP_ENV_CONTEXT_GP_SUBTYPE(sparp))
    return triple;
  for (fctr = 0; fctr < SPART_TRIPLE_FIELDS_COUNT; fctr++)
    {
      SPART *fld = triple->_.triple.tr_fields[fctr];
      ptrlong ft = SPART_TYPE(fld);
      if ((SPAR_VARIABLE == ft) || (SPAR_BLANK_NODE_LABEL == ft))
        {
          fld->_.var.rvr.rvrRestrictions |= sparp_tr_usage_natural_restrictions[fctr];
          fld->_.var.tr_idx = fctr;
          if (!(SPART_VARR_GLOBAL & fld->_.var.rvr.rvrRestrictions))
            t_set_push_new_string (&(env->spare_good_graph_varnames), fld->_.var.vname);
        }
      if ((env->spare_src.ssrc_grab.rgc_all) && (SPART_TRIPLE_PREDICATE_IDX != fctr))
        {
          if ((SPAR_VARIABLE == ft) && !(SPART_VARR_GLOBAL & fld->_.var.rvr.rvrRestrictions))
            t_set_push_new_string (&(env->spare_src.ssrc_grab.rgc_vars), t_box_dv_uname_string (fld->_.var.vname));
          else if (SPAR_QNAME == ft)
            t_set_push_new_string (&(env->spare_src.ssrc_grab.rgc_consts), fld->_.lit.val);
        }
      if ((NULL != env->spare_src.ssrc_grab.rgc_sa_preds) &&
        (SPART_TRIPLE_SUBJECT_IDX == fctr) &&
        (SPAR_VARIABLE == ft) &&
        !(env->spare_src.ssrc_grab.rgc_all) )
        {
          SPART *obj = triple->_.triple.tr_object;
          ptrlong objt = SPART_TYPE(obj);
          if (
            ((SPAR_VARIABLE == objt) &&
              (0 <= dk_set_position_of_string (env->spare_src.ssrc_grab.rgc_vars, obj->_.var.vname)) ) ||
            ((SPAR_QNAME == objt) &&
              (0 <= dk_set_position_of_string (env->spare_src.ssrc_grab.rgc_consts, obj->_.lit.val)) ) )
            {
              t_set_push_new_string (&(env->spare_src.ssrc_grab.rgc_sa_vars), t_box_dv_uname_string (fld->_.var.vname));
            }
        }
    }
  return triple;
}

SPART *
spar_inverse_ppath (sparp_t *sparp, SPART *tree)
{
  switch (SPART_TYPE (tree))
    {
    case SPAR_PPATH:
      {
        int ctr, ctr2, count = BOX_ELEMENTS (tree->_.ppath.parts);
        switch (tree->_.ppath.subtype)
          {
          case 0: case '!':
            {
            int num_of_invs = tree->_.ppath.num_of_invs;
            int num_of_fwds = count - num_of_invs;
            SPART **parts_cpy = (SPART **)t_alloc_list (count);
            memcpy (parts_cpy, tree->_.ppath.parts + num_of_fwds, sizeof(SPART *) * num_of_invs);
            memcpy (parts_cpy + num_of_invs, tree->_.ppath.parts, sizeof(SPART *) * num_of_fwds);
            tree->_.ppath.parts = parts_cpy;
            tree->_.ppath.num_of_invs = num_of_fwds;
            return tree;
            }
          case '/':
            ctr = 0; ctr2 = count-1;
            while (ctr < ctr2)
              {
                SPART *swap = tree->_.ppath.parts[ctr];
                tree->_.ppath.parts[ctr] = tree->_.ppath.parts[ctr2];
                tree->_.ppath.parts[ctr2] = swap;
                ctr++; ctr2--;
              }
            /* no break */
          case '|': case 'D':
            for (ctr = count; ctr--; /* no step */)
              tree->_.ppath.parts[ctr] = spar_inverse_ppath (sparp, tree->_.ppath.parts[ctr]);
            return tree;
          case '*':
            tree->_.ppath.parts[0] = spar_inverse_ppath (sparp, tree->_.ppath.parts[0]);
            return tree;
          }
      }
    }
  spar_internal_error (sparp, "Unsupported type of property path to inverse by '^'");
  return NULL; /* to make compiler happy */
}

SPART *
spar_make_ppath_pred_or_predinf (sparp_t *sparp, SPART *predicate)
{
  rdf_inf_ctx_t *inf_ctx = sparp->sparp_env->spare_inference_ctx;
  dk_set_t inv_names;
  int tricks = 0;
  SPART *leaf;
  if (NULL != inf_ctx)
    {
      inv_names = NULL;
      tricks = spar_inf_tricks_for_pred (sparp, predicate->_.qname.val, inf_ctx, 0, &inv_names);
    }
  if ((SPAR_TRIPLE_TRICK_INV_UNION & tricks) && (NULL != inv_names))
    {
      SPART **all_names;
      int ctr, inv_count;
      inv_count = dk_set_length (inv_names);
      all_names = (SPART **)t_alloc_list (1 + inv_count);
      all_names[0] = predicate;
      for (ctr = inv_count; ctr--; /* no step */)
        all_names [1+ctr] = spartlist (sparp, 2, SPAR_QNAME, t_box_copy ((caddr_t)(t_set_pop (&inv_names))));
      leaf = spartlist (sparp, 6, SPAR_PPATH, (ptrlong)0, all_names, (ptrlong)0, (ptrlong)0, (ptrlong)(inv_count));
    }
  else
    leaf = spartlist (sparp, 6, SPAR_PPATH, (ptrlong)0, (SPART **)t_list (1, predicate), (ptrlong)0, (ptrlong)0, (ptrlong)0);
  if (SPAR_TRIPLE_TRICK_TRANSITIVE & tricks)
    return spartlist (sparp, 6, SPAR_PPATH, (ptrlong)'*', (SPART **)t_list (1, leaf), t_box_num (1), t_box_num(-1), (ptrlong)0);
  return leaf;
}

SPART *
spar_make_ppath_union (sparp_t *sparp, SPART *part1, SPART *part2)
{
  int part1subt = part1->_.ppath.subtype;
  int part2subt = part2->_.ppath.subtype;
  SPART **p1 = part1->_.ppath.parts;
  SPART **p2 = part2->_.ppath.parts;
  int count1 = BOX_ELEMENTS (p1);
  int count2 = BOX_ELEMENTS (p2);
  int fwd_count1 = count1 - part1->_.ppath.num_of_invs;
  int fwd_count2 = count2 - part2->_.ppath.num_of_invs;
  int fwdstar1 = 0, fwdstar2 = 0, invstar1 = 0, invstar2 = 0;
  if ((0 == part1subt) || ('!' == part1subt))
    {
      fwdstar1 = ((0 < fwd_count1) && ((SPART *)_STAR == p1[0]));
      invstar1 = ((fwd_count1 < count1) && ((SPART *)_STAR == p1[fwd_count1]));
    }
  if ((0 == part2subt) || ('!' == part2subt))
    {
      fwdstar2 = ((0 < fwd_count2) && ((SPART *)_STAR == p2[0]));
      invstar2 = ((fwd_count2 < count2) && ((SPART *)_STAR == p2[fwd_count2]));
    }
  if ((0 == part1subt) && (0 == part2subt))
    {
      int pres_count = count1+count2;
      SPART **pres = (SPART **)t_alloc_list (pres_count);
      int ctr1 = 0, ctr2 = 0, res_ctr = 0, fwd_res_count;
      if (fwdstar1 || fwdstar2)
        {
          pres[res_ctr++] = (SPART *)_STAR;
          ctr1 = fwd_count1; ctr2 = fwd_count2;
        }
      else
        {
          while ((ctr1 < fwd_count1) || (ctr2 < fwd_count2))
            {
              if ((ctr1 < fwd_count1) && ((ctr2 >= fwd_count2) || (0 > strcmp (p1[ctr1]->_.qname.val, p2[ctr2]->_.qname.val))))
                pres[res_ctr++] = p1[ctr1++];
              else if ((ctr2 < fwd_count2) && ((ctr1 >= fwd_count1) || (0 > strcmp (p2[ctr2]->_.qname.val, p1[ctr1]->_.qname.val))))
                pres[res_ctr++] = p2[ctr2++];
              else
                {
                  pres[res_ctr++] = p1[ctr1++]; ctr2++;
                }
            }
        }
      fwd_res_count = res_ctr;
      if (invstar1 || invstar2)
        {
          pres[res_ctr++] = (SPART *)_STAR;
          ctr1 = count1; ctr2 = count2;
        }
      else
        {
          while ((ctr1 < count1) || (ctr2 < count2))
            {
              if ((ctr1 < count1) && ((ctr2 >= count2) || (0 > strcmp (p1[ctr1]->_.qname.val, p2[ctr2]->_.qname.val))))
                pres[res_ctr++] = p1[ctr1++];
              else if ((ctr2 < count2) && ((ctr1 >= count1) || (0 > strcmp (p2[ctr2]->_.qname.val, p1[ctr1]->_.qname.val))))
                pres[res_ctr++] = p2[ctr2++];
              else
                {
                  pres[res_ctr++] = p1[ctr1++]; ctr2++;
                }
            }
        }
      if (res_ctr < pres_count)
        pres = (SPART **)t_list_memcpy (res_ctr, (ccaddr_t *)pres);
      return spartlist (sparp, 6, SPAR_PPATH, (ptrlong)0, pres, (ptrlong)0, (ptrlong)0, (ptrlong)(res_ctr - fwd_res_count));
    }
  if (('!' == part1subt) && ('!' == part2subt))
    {
      int pres_count = MAX (count1+count2, 2);
      SPART **pres = (SPART **)t_alloc_list (pres_count);
      int ctr1 = 0, ctr2 = 0, res_ctr = 0, fwd_res_count;
      if (fwdstar1 || fwdstar2)
        {
          pres[res_ctr++] = (SPART *)_STAR;
          ctr1 = fwd_count1; ctr2 = fwd_count2;
        }
      else if (0 == fwd_count1)
        {
          while (ctr2 < fwd_count2)
            pres[res_ctr++] = p2[ctr2++];
          ctr1 = fwd_count1;
        }
      else if (0 == fwd_count2)
        {
          while (ctr1 < fwd_count1)
            pres[res_ctr++] = p1[ctr1++];
          ctr2 = fwd_count2;
        }
      else
        {
          while ((ctr1 < fwd_count1) || (ctr2 < fwd_count2))
            {
              if ((ctr1 < fwd_count1) && ((ctr2 >= fwd_count2) || (0 > strcmp (p1[ctr1]->_.qname.val, p2[ctr2]->_.qname.val))))
                ctr1++;
              else if ((ctr2 < fwd_count2) && ((ctr1 >= fwd_count1) || (0 > strcmp (p2[ctr2]->_.qname.val, p1[ctr1]->_.qname.val))))
                ctr2++;
              else
                {
                  pres[res_ctr++] = p1[ctr1++]; ctr2++;
                }
            }
          if (((0 != fwd_count1) || (0 != fwd_count2)) && (0 == res_ctr))
            pres[res_ctr++] = (SPART *)_STAR;
        }
      fwd_res_count = res_ctr;
      if (invstar1 || invstar2)
        {
          pres[res_ctr++] = (SPART *)_STAR;
          ctr1 = count1; ctr2 = count2;
        }
      else if (fwd_count1 == count1)
        {
          while (ctr2 < count2)
            pres[res_ctr++] = p2[ctr2++];
        }
      else if (fwd_count2 == count2)
        {
          while (ctr1 < count1)
            pres[res_ctr++] = p1[ctr1++];
        }
      else
        {
          while ((ctr1 < count1) || (ctr2 < count2))
            {
              if ((ctr1 < count1) && ((ctr2 >= count2) || (0 > strcmp (p1[ctr1]->_.qname.val, p2[ctr2]->_.qname.val))))
                ctr1++;
              else if ((ctr2 < count2) && ((ctr1 >= count1) || (0 > strcmp (p2[ctr2]->_.qname.val, p1[ctr1]->_.qname.val))))
                ctr2++;
              else
                {
                  pres[res_ctr++] = p1[ctr1++]; ctr2++;
                }
            }
          if (((count1 != fwd_count1) || (count2 != fwd_count2)) && (fwd_res_count == res_ctr))
            pres[res_ctr++] = (SPART *)_STAR;
        }
      if (res_ctr < pres_count)
        pres = (SPART **)t_list_memcpy (res_ctr, (ccaddr_t *)pres);
      return spartlist (sparp, 6, SPAR_PPATH, (ptrlong)'!', pres, (ptrlong)0, (ptrlong)0, (ptrlong)(res_ctr - fwd_res_count));
    }
  if ((0 == part1subt) && ('!' == part2subt))
    {
      SPART *bangres;
      int p_bangres_count = MAX (count2, 2);
      SPART **p_bangres = (SPART **)t_alloc_list (p_bangres_count);
      int ctr2 = 0, ctr1 = 0, c_bangres = 0, fwd_bangres;
      int keep_part1_fwds, keep_part1_invs;
      if (((0 < fwd_count1) && ((SPART *)_STAR == p1[0])) && ((fwd_count1 < count1) && ((SPART *)_STAR == p1[fwd_count1])))
        return part1; /* if part1 is _STAR|^_STAR then it's "everything" already, no need to extend it. */
      if (((0 < fwd_count2) && ((SPART *)_STAR == p2[0])) && ((fwd_count2 < count2) && ((SPART *)_STAR == p2[fwd_count2])))
        { /* if part2 is _STAR|^_STAR then it's "everything" already, no need to extend it. */
          part2->_.ppath.subtype = 0;
          return part2;
        }
      if (fwdstar1 || fwdstar2)
        {
          p_bangres[c_bangres++] = (SPART *)_STAR;
          ctr2 = fwd_count2; ctr1 = fwd_count1;
        }
      else
        {
          while ((ctr1 < fwd_count1) || (ctr2 < fwd_count2))
            {
              if ((ctr2 < fwd_count2) && ((ctr1 >= fwd_count1) || (0 > strcmp (p2[ctr2]->_.qname.val, p1[ctr1]->_.qname.val))))
                p_bangres[c_bangres++] = p2[ctr2++];
              else if ((ctr1 < fwd_count1) && ((ctr2 >= fwd_count2) || (0 > strcmp (p1[ctr1]->_.qname.val, p2[ctr2]->_.qname.val))))
                ctr1++;
              else
                {
                  ctr1++; ctr2++;
                }
            }
          if ((0 < fwd_count2) && (0 == c_bangres)) /* We've got x|!x */
            p_bangres[c_bangres++] = (SPART *)_STAR;
        }
      fwd_bangres = c_bangres;
      if (invstar1 || invstar2)
        {
          p_bangres[c_bangres++] = (SPART *)_STAR;
          ctr2 = count2; ctr1 = count1;
        }
      else
        {
          while ((ctr1 < count1) || (ctr2 < count2))
            {
              if ((ctr2 < count2) && ((ctr1 >= count1) || (0 > strcmp (p2[ctr2]->_.qname.val, p1[ctr1]->_.qname.val))))
                p_bangres[c_bangres++] = p2[ctr2++];
              else if ((ctr1 < count1) && ((ctr2 >= count2) || (0 > strcmp (p1[ctr1]->_.qname.val, p2[ctr2]->_.qname.val))))
                ctr1++;
              else
                {
                  ctr1++; ctr2++;
                }
            }
          if ((fwd_count2 < count2) && (fwd_bangres == c_bangres)) /* We've got ^x|!^x */
            p_bangres[c_bangres++] = (SPART *)_STAR;
        }
      if (c_bangres < p_bangres_count)
        p_bangres = (SPART **)t_list_memcpy (c_bangres, (ccaddr_t *)p_bangres);
      bangres = spartlist (sparp, 6, SPAR_PPATH, (ptrlong)part2subt, p_bangres, (ptrlong)0, (ptrlong)0, (ptrlong)(c_bangres - fwd_bangres));
      keep_part1_fwds = ((0 == fwd_bangres) && (0 != fwd_count1));
      keep_part1_invs = ((c_bangres == fwd_bangres) && (0 != part1->_.ppath.num_of_invs));
      if (keep_part1_fwds || keep_part1_invs)
        {
          if (!keep_part1_fwds)
            {
              part1->_.ppath.parts = (SPART **)t_list_memcpy (part1->_.ppath.num_of_invs, (ccaddr_t *)(p1 + fwd_count1));
              fwd_count1 = 0;
            }
          if (!keep_part1_invs)
            {
              part1->_.ppath.parts = (SPART **)t_list_memcpy (fwd_count1, (ccaddr_t *)(p1));
              part1->_.ppath.num_of_invs = 0;
            }
          return spartlist (sparp, 6, SPAR_PPATH, (ptrlong)'|', (SPART **)t_list (2, part1, bangres), (ptrlong)0, (ptrlong)0, (ptrlong)0);
        }
      else
        return bangres;
    }
  if (('!' == part1subt) && (0 == part2subt))
    return spar_make_ppath_union (sparp, part2, part1);
  if (('|' == part1subt) && ((0 == part2subt) || ('!' == part2subt)))
    {
      SPART *p1left = part1->_.ppath.parts[0];
      SPART *p1next = part1->_.ppath.parts[1];
      int p1left_subt = p1left->_.ppath.subtype;
      int p1next_subt = p1next->_.ppath.subtype;
      if (part2subt == p1left_subt)
        {
          part1->_.ppath.parts[0] = spar_make_ppath (sparp, '|', p1left, part2, 0, 0);
          return part1;
        }
      if (part2subt == p1next_subt)
        {
          if ('!' != p1next_subt)
            spar_internal_error (sparp, "Weird '|' ppath: second item is \"0 or '!'\" but not '!'");
          part1->_.ppath.parts[1] = spar_make_ppath (sparp, '|', p1next, part2, 0, 0);
          if (0 == part1->_.ppath.parts[1]->_.ppath.subtype) /* _STAR|^_STAR is made from two '!'s */
            {
              if (2 == BOX_ELEMENTS (part1->_.ppath.parts))
                return part1->_.ppath.parts[1];
              part1->_.ppath.parts = (SPART **) t_list_memcpy (BOX_ELEMENTS (part1->_.ppath.parts) - 1, (ccaddr_t *)(part1->_.ppath.parts+1));
            }
          return part1;
        }
      if ((0 == p1left_subt) || ('!' == p1left_subt))
        {
          SPART *mix = spar_make_ppath (sparp, '|', p1left, part2, 0, 0);
          part1->_.ppath.parts[0] = spar_make_ppath (sparp, '|', p1left, part2, 0, 0);
          if ('|' == mix->_.ppath.subtype)
            {
              part1->_.ppath.parts = (SPART **)t_list_insert_before_nth ((caddr_t)(part1->_.ppath.parts), (caddr_t)(mix->_.ppath.parts[1]), 1);
              part1->_.ppath.parts[0] = mix->_.ppath.parts[0];
            }
          else
            part1->_.ppath.parts[0] = mix;
          return part1;
        }
      part1->_.ppath.parts = (SPART **) t_list_concat ((caddr_t)t_list (1, part2), (caddr_t)(part1->_.ppath.parts));
      return part1;
    }
  if (('|' == part1subt) && ('|' == part2subt))
    {
      int ctr2;
      for (ctr2 = 0; ctr2 < count2; ctr2++)
        {
          SPART *memb2 = p2[ctr2];
          int memb2_subt = memb2->_.ppath.subtype;;
          if ((0 == memb2_subt) || ('!' == memb2_subt))
            part1 = spar_make_ppath (sparp, '|', part1, memb2, 0, 0);
          else
            break;
        } 
      if (ctr2 < count2)
        part1->_.ppath.parts = (SPART **) t_list_concat ((caddr_t)(part1->_.ppath.parts), (caddr_t)t_list_memcpy ((count2 - ctr2), (ccaddr_t *)(p2 + ctr2)));
      return part1;
    }
  if ('|' == part1subt)
    {
      part1->_.ppath.parts = (SPART **) t_list_concat_tail ((caddr_t)(part1->_.ppath.parts), 1, part2);
      return part1;
    }
  if ('|' == part2subt)
    return spar_make_ppath_union (sparp, part2, part1);
  return spartlist (sparp, 6, SPAR_PPATH, (ptrlong)'|', (SPART **)t_list (2, part1, part2), (ptrlong)0, (ptrlong)0, (ptrlong)0);
}

#ifdef SPARQL_DEBUG
extern SPART *spar_make_ppath_impl (sparp_t *sparp, char subtype, SPART *part1, SPART *part2, ptrlong mincount, ptrlong maxcount);

SPART *
spar_make_ppath (sparp_t *sparp, char subtype, SPART *part1, SPART *part2, ptrlong mincount, ptrlong maxcount)
{
  spar_sqlgen_t fake_ssg;
  caddr_t out;
  SPART *res;
  memset (&fake_ssg, 0, sizeof (spar_sqlgen_t));
  fake_ssg.ssg_sparp = sparp;
  fake_ssg.ssg_out = strses_allocate ();
  SES_PRINT (fake_ssg.ssg_out, "\nspar_make_ppath(...,   '");
  session_buffered_write_char (subtype ? subtype : '0', fake_ssg.ssg_out);
  SES_PRINT (fake_ssg.ssg_out, ",   ");
  ssg_sdprint_tree (&fake_ssg, part1);
  SES_PRINT (fake_ssg.ssg_out, ",   ");
  if (NULL != part2)
    ssg_sdprint_tree (&fake_ssg, part2);
  else
    SES_PRINT (fake_ssg.ssg_out, "NULL");
  char buf[30]; sprintf (buf, ",   %ld, %ld)\nreturns ", (long)mincount, (long)maxcount); SES_PRINT (fake_ssg.ssg_out, buf);
  res = spar_make_ppath_impl (sparp, subtype, part1, part2, mincount, maxcount);
  ssg_sdprint_tree (&fake_ssg, res);
  out = strses_string (fake_ssg.ssg_out);
  puts (out);
  dk_free_box (out);
  strses_free (fake_ssg.ssg_out);
  return res;
}
#else
#define spar_make_ppath_impl spar_make_ppath
#endif

SPART *
spar_make_ppath_impl (sparp_t *sparp, char subtype, SPART *part1, SPART *part2, ptrlong mincount, ptrlong maxcount)
{
  int part1subt, part2subt;
  if (SPAR_QNAME == SPART_TYPE (part1))
    part1 = spar_make_ppath_pred_or_predinf (sparp, part1);
  part1subt = part1->_.ppath.subtype;
  if (NULL != part2)
    {
      if (SPAR_QNAME == SPART_TYPE (part2))
        part2 = spar_make_ppath_pred_or_predinf (sparp, part2);
      part2subt = part2->_.ppath.subtype;
    }
  else
    part2subt = 1; /* an intentionally bad value is set */
  switch (subtype)
    {
    case '^': return spar_inverse_ppath (sparp, part1);
    case '!':
      if (0 != part1->_.ppath.subtype)
        spar_error (sparp, "The '!' property path operator can be applied only to a predicate, a ^predicate, or a group of them");
      {
        SPART **p1 = part1->_.ppath.parts;
        int count1 = BOX_ELEMENTS (p1);
        int fwd_count1 = count1 - part1->_.ppath.num_of_invs;
        if (((0 < fwd_count1) && ((SPART *)_STAR == p1[0])) || ((fwd_count1 < count1) && ((SPART *)_STAR == p1[fwd_count1])))
          spar_internal_error (sparp, "Weird use of '!' property path operator");
        part1->_.ppath.subtype = '!';
      }
      return part1;
    case '|':
      return spar_make_ppath_union (sparp, part1, part2);
    case '/':
      if (subtype == part1subt)
        {
          if (subtype == part2subt)
            {
              part1->_.ppath.parts = (SPART **) t_list_concat ((caddr_t)(part1->_.ppath.parts), (caddr_t)(part2->_.ppath.parts));
              return part1;
            }
          part1->_.ppath.parts = (SPART **) t_list_concat_tail ((caddr_t)(part1->_.ppath.parts), 1, part2);
          return part1;
        }
      if (subtype == part2subt)
        {
          part2->_.ppath.parts = (SPART **) t_list_concat ((caddr_t)t_list (1, part1), (caddr_t)(part2->_.ppath.parts));
          return part2;
        }
      return spartlist (sparp, 6, SPAR_PPATH, (ptrlong)subtype, (SPART **)t_list (2, part1, part2), (ptrlong)0, (ptrlong)0, (ptrlong)0);
    case 'D':
      if (('|' == part1subt) || ('D' == part1subt))
        {
          part1->_.ppath.subtype = 'D';
          return part1;
        }
      return spartlist (sparp, 6, SPAR_PPATH, (ptrlong)subtype, (SPART **)t_list (1, part1), (ptrlong)0, (ptrlong)0, (ptrlong)0);
    case '*':
      if (('*' == part1subt) && (2 > maxcount) && (2 > unbox (part1->_.ppath.maxrepeat)) && ((2 > mincount) || (2 > unbox (part1->_.ppath.minrepeat))))
        {
          if (0 == mincount) part1->_.ppath.minrepeat = t_box_num (0);
          if (-1 == maxcount) part1->_.ppath.maxrepeat = t_box_num (-1);
          return part1;
        }
      return spartlist (sparp, 6, SPAR_PPATH, (ptrlong)subtype, (SPART **)t_list (1, part1), t_box_num (mincount), t_box_num (maxcount), (ptrlong)0);
    }
  spar_internal_error (sparp, "Unsupported type of property path to make");
  return NULL;
}

SPART *
spar_bind_prepare (sparp_t *sparp, SPART *expn, int bind_has_scalar_subqs)
{
  if (SPAR_ALIAS != SPART_TYPE (expn))
    spar_error (sparp, "BIND (...) requires an expression of form x AS ?y");
  expn->_.alias.reruns_may_vary = bind_has_scalar_subqs ? 1 : 0;
  return expn;
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
  if (sparp->sparp_in_precode_expn)
    {
      if (2 & sparp->sparp_in_precode_expn)
        spar_error (sparp, "Variable '%.100s' is not allowed in a constant clause", name);
      else if (!is_global)
        spar_error (sparp, "non-global variable '%.100s' can not be used outside any group pattern or result-set list", name);
    }
  if (is_global) /* say, 'insert in graph ?:someglobalvariable {...} where {...} */
    selid = t_box_dv_uname_string ("(global)");
  else if (SPART_VARNAME_IS_SPECIAL(name)) /* say, '@"limofs"."describe-1"' */
    selid = t_box_dv_uname_string ("(special)");
  /*!!! TBD finda replacement for
  else
    spar_internal_error (sparp, "non-global variable outside any group pattern or result-set list"); */
  else
    selid = NULL;
  res = spartlist (sparp, 7 + (sizeof (rdf_val_range_t) / sizeof (caddr_t)),
      SPAR_VARIABLE, name,
      selid, NULL,
      (ptrlong)(SPART_VAR_OUTSIDE_TRIPLE), SPART_BAD_EQUIV_IDX, SPART_RVR_LIST_OF_NULLS, (ptrlong)(0x0) );
  res->_.var.rvr.rvrRestrictions = (is_global ? SPART_VARR_GLOBAL : 0);
  return res;
}

SPART *
spar_make_macropu (sparp_t *sparp, caddr_t name, ptrlong pos)
{
  SPART *res = spartlist (sparp, 4, SPAR_MACROPU, name, pos, (ptrlong)0);
  return res;
}

SPART *spar_make_blank_node (sparp_t *sparp, caddr_t name, int bracketed)
{
  SPART *res;
  if ((sparp->sparp_in_precode_expn) && !(bracketed & 0x2))
    spar_error (sparp, "Blank node '%.100s' is not allowed in a constant clause", name);
  /*if (NULL == env->spare_selids)
    spar_error (sparp, "Blank nodes (e.g., '%.100s') can not be used outside any group pattern or result-set list", name);*/
  res = spartlist (sparp, 8 + (sizeof (rdf_val_range_t) / sizeof (caddr_t)),
      SPAR_BLANK_NODE_LABEL, name,
      NULL, NULL,
      (ptrlong)SPART_VAR_OUTSIDE_TRIPLE, SPART_BAD_EQUIV_IDX, SPART_RVR_LIST_OF_NULLS, (ptrlong)(0x0), (ptrlong)bracketed );
  res->_.var.rvr.rvrRestrictions = /*SPART_VARR_IS_REF | SPART_VARR_IS_BLANK |*/ SPART_VARR_NOT_NULL;
  return res;
}

SPART *spar_make_fake_blank_node (sparp_t *sparp)
{
  SPART *res;
  res = spartlist (sparp, 8 + (sizeof (rdf_val_range_t) / sizeof (caddr_t)),
      SPAR_BLANK_NODE_LABEL, uname__ref,
      uname__ref, NULL,
      (ptrlong)(0), SPART_BAD_EQUIV_IDX, SPART_RVR_LIST_OF_NULLS, (ptrlong)(0x0), (ptrlong)0x2 );
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
    return spartlist (sparp, 5, SPAR_LIT, strg, type, lang, NULL);
/* Fast casts for xsd types taht match to SQL types without additional checks */
  if (uname_xmlschema_ns_uri_hash_boolean == type)
    {
      if (!strcmp ("true", strg) || !strcmp ("1", strg))
        return spartlist (sparp, 5, SPAR_LIT, (ptrlong)1, type, NULL, strg);
      if (!strcmp ("false", strg) || !strcmp ("0", strg))
        return spartlist (sparp, 5, SPAR_LIT, t_box_num_nonull (0), type, NULL, strg);
      goto cannot_cast;
    }
/*  if (uname_xmlschema_ns_uri_hash_date == type)
    {
      tgt_dtp = DV_DATE;
      goto do_sql_cast;
    }
  if (uname_xmlschema_ns_uri_hash_dateTime == type)
    {
      tgt_dtp = DV_DATETIME;
      goto do_sql_cast;
    }*/
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
/*  if (uname_xmlschema_ns_uri_hash_time == type)
    {
      tgt_dtp = DV_TIME;
      goto do_sql_cast;
    }*/
  if (uname_xmlschema_ns_uri_hash_string == type)
    {
      return spartlist (sparp, 5, SPAR_LIT, strg, type, NULL, NULL);
    }
/* Casts using xqf converters */
  if (!strncmp (type, XMLSCHEMA_NS_URI "#", XMLSCHEMA_NS_URI_LEN + 1 /* +1 is for '#' */))
    {
      const char *p_name = type + XMLSCHEMA_NS_URI_LEN + 1;
      long desc_idx = ecm_find_name (p_name, xqf_str_parser_descs_ptr, xqf_str_parser_desc_count, sizeof (xqf_str_parser_desc_t));
      xqf_str_parser_desc_t *desc;
      dtp_t strg_dtp = DV_TYPE_OF (strg);
      if (ECM_MEM_NOT_FOUND == desc_idx)
        goto generic_literal; /* see below */
      desc = xqf_str_parser_descs_ptr + desc_idx;
      if (DV_STRING != strg_dtp)
        {
          if (desc->p_dest_dtp == strg_dtp)
            parsed_value = box_copy_tree (strg);
          else
            {
              tgt_dtp_tree = (sql_tree_tmp *)t_list (3, (ptrlong)(desc->p_dest_dtp), (ptrlong)NUMERIC_MAX_PRECISION, (ptrlong)NUMERIC_MAX_SCALE);
              parsed_value = box_cast ((caddr_t *)(sparp->sparp_sparqre->sparqre_qi), strg, tgt_dtp_tree, strg_dtp);
            }
          if ((NULL != desc->p_rcheck) && !desc->p_rcheck (&parsed_value, desc->p_opcode))
            goto cannot_cast;
        }
      else
        {
          QR_RESET_CTX
            {
              desc->p_proc (&parsed_value, strg, desc->p_opcode);
            }
          QR_RESET_CODE
            {
              POP_QR_RESET;
              goto generic_literal; /* see below */
            }
          END_QR_RESET
        }
      res = spartlist (sparp, 5, SPAR_LIT, t_full_box_copy_tree (parsed_value), type, NULL, strg);
      dk_free_tree (parsed_value);
      return res;
    }

generic_literal:
  return spartlist (sparp, 5, SPAR_LIT, strg, type, NULL, NULL);

do_sql_cast:
  tgt_dtp_tree = (sql_tree_tmp *)t_list (3, (ptrlong)tgt_dtp, (ptrlong)NUMERIC_MAX_PRECISION, (ptrlong)NUMERIC_MAX_SCALE);
  parsed_value = box_cast ((caddr_t *)(sparp->sparp_sparqre->sparqre_qi), strg, tgt_dtp_tree, DV_STRING);
  res = spartlist (sparp, 5, SPAR_LIT, t_full_box_copy_tree (parsed_value), type, NULL, strg);
  dk_free_tree (parsed_value);
  return res;

cannot_cast:
  dk_free_tree (parsed_value);
  sparyyerror_impl (sparp, strg, "The string representation can not be converted to a valid typed value");
  return NULL;
}

void
sparp_make_and_push_new_graph_source (sparp_t *sparp, ptrlong subtype, SPART *iri_expn, SPART **options, int freeze_ignore_mask)
{
  sparp_env_t *spare = sparp->sparp_env;
  caddr_t iri = ((SPAR_QNAME == SPART_TYPE (iri_expn)) ? iri_expn->_.qname.val : NULL);
  dk_set_t *set_ptr;
  int is_frozen = 0;
  int signal_error_even_if_dupe = 0;
  SPART *dupe_found = NULL;
  caddr_t **group_members_ptr = NULL;
  SPART *precode;
  switch (subtype)
    {
    case SPART_GRAPH_FROM:
      spare->spare_src.ssrc_default_graphs_listed++;
      is_frozen = spare->spare_src.ssrc_freeze_status;
      signal_error_even_if_dupe = is_frozen & SPARP_SSRC_FROZEN_BY_USING;
      set_ptr = &(spare->spare_src.ssrc_default_graphs);
      break;
    case SPART_GRAPH_NOT_FROM:
      signal_error_even_if_dupe = is_frozen & SPARP_SSRC_FROZEN_BY_WITH;
      set_ptr = &(spare->spare_src.ssrc_default_graphs);
      break;
    case SPART_GRAPH_NAMED:
      spare->spare_src.ssrc_named_graphs_listed++;
      is_frozen = spare->spare_src.ssrc_freeze_status;
      signal_error_even_if_dupe = is_frozen & SPARP_SSRC_FROZEN_BY_USING;
      set_ptr = &(spare->spare_src.ssrc_named_graphs);
      break;
    case SPART_GRAPH_NOT_NAMED:
      set_ptr = &(spare->spare_src.ssrc_named_graphs);
      break;
    default:
      spar_internal_error (sparp, "sparp_make_and_push_new_graph_source(): bad subtype");
      set_ptr = NULL; /* To keep compiler happy */
      break;
    }
  if (NULL != iri)
    {
      DO_SET (SPART *, c, set_ptr)
        {
          if (strcmp (c->_.graph.iri, iri))
            continue;
          if ((subtype < SPART_GRAPH_MIN_NEGATION) && (SPART_GRAPH_MIN_NEGATION < c->_.graph.subtype))
            {
              if (is_frozen)
                {
                  const char *fty = ((SPART_GRAPH_NAMED == subtype) ? " NAMED" : "");
                  spar_error (sparp, "An IRI <%.200s> can not be used in FROM%s clause because it is excluded by NOT FROM%s already",
                    iri, fty, fty );
                }
              return; /* A (failed) attempt to overwrite NOT FROM with FROM */
            }
          if ((c->_.graph.subtype == subtype) && (SPAR_QNAME != SPART_TYPE (c->_.graph.expn)))
            t_set_delete (set_ptr, c);
          else
            {
              dupe_found = c;
              break;
            }
        }
      END_DO_SET()
    }
  if (SPART_GRAPH_NOT_FROM == subtype)
    {
      SPART *gsbw = spare->spare_src.ssrc_graph_set_by_with;
      if ((NULL != gsbw) && (SPAR_QNAME == SPART_TYPE (gsbw)) && !strcmp (gsbw->_.qname.val, iri))
        spar_error (sparp, "NOT FROM <%.200s> clause conflicts with WITH specified before", ((NULL == iri) ? "..." : iri));
    }
  if ((subtype < SPART_GRAPH_MIN_NEGATION) && (is_frozen & ~freeze_ignore_mask))
    {
      const char *fty = ((SPART_GRAPH_NAMED == subtype) ? " NAMED" : "");
      if (NULL == dupe_found)
        spar_error (sparp, "FROM %s <%.200s> clause (or its equivalent) violates restrictions on allowed graph names set by protocol parameters or define pragmas", fty, ((NULL == iri) ? "..." : iri));
      else if (signal_error_even_if_dupe)
        spar_error (sparp, "FROM %s <%.200s> clause (or its equivalent) conflicts with protocol parameters or define pragmas and thus violates SPARQL 1.1 Protocol spec", fty, ((NULL == iri) ? "..." : iri));
    }
  if ((SPART_GRAPH_MIN_NEGATION < subtype) && (NULL != options))
    {
      const char *fty = ((SPART_GRAPH_NAMED == subtype) ? " NAMED" : "");
      spar_error (sparp, "NOT FROM%s <%.200s> clause cannot have options; only FROM and FROM NAMED can", fty, ((NULL == iri) ? "..." : iri));
    }
  if ((NULL != iri) && rdf_graph_group_dict_htable->ht_count)
    {
      caddr_t iid = sparp_graph_sec_iri_to_id_nosignal (sparp, iri);
      if (NULL != iid)
        {
          rwlock_rdlock (rdf_graph_group_dict_htable->ht_rwlock);
          group_members_ptr = (caddr_t **)id_hash_get (rdf_graph_group_dict_htable, (caddr_t)(&iid));
          rwlock_unlock (rdf_graph_group_dict_htable->ht_rwlock);
          dk_free_tree (iid);
        }
    }
  else
    group_members_ptr = NULL;
  if (NULL != group_members_ptr)
    {
      switch (subtype)
        {
        case SPART_GRAPH_FROM: subtype = SPART_GRAPH_GROUP; break;
        case SPART_GRAPH_NOT_FROM: subtype = SPART_GRAPH_NOT_GROUP; break;
        case SPART_GRAPH_NAMED:
          spar_error (sparp, "<%.200s> is graph group, not a plain graph, so it cannot be used in FROM NAMED clause", iri);
          break;
        case SPART_GRAPH_NOT_NAMED:
          spar_error (sparp, "<%.200s> is graph group, not a plain graph, so it cannot be used in NOT FROM NAMED clause", iri);
          break;
        }
    }
  if ((SPART_GRAPH_GROUP == subtype) && (NULL != options))
    spar_error (sparp, "FROM <%.200s> clause refers to a graph group so it can not have any options", iri);
  precode = sparp_make_graph_precode (sparp, subtype, iri_expn, options);
  if ((NULL != dupe_found) && (dupe_found->_.graph.subtype == subtype) &&
    (SPAR_QNAME == SPART_TYPE (dupe_found->_.graph.expn)) &&
    (SPAR_QNAME == SPART_TYPE (precode->_.graph.expn)) )
    return;
  if (SPART_GRAPH_MIN_NEGATION < subtype)
    {
      dk_set_t tmp = NULL;
      t_set_push (&tmp, precode);
      set_ptr[0] = t_NCONC (set_ptr[0], tmp);
    }
  else
    t_set_push (set_ptr, precode);
}

SPART *
sparp_make_graph_precode (sparp_t *sparp, ptrlong subtype, SPART *iriref, SPART **options)
{
  rdf_grab_config_t *rgc_ptr = &(sparp->sparp_env->spare_src.ssrc_grab);
  dk_set_t *opts_ptr = &(sparp->sparp_env->spare_src.ssrc_common_sponge_options);
  SPART **mixed_options, **mixed_tail;
  int common_count, ctr, use_expn_in_gs_checks = 0;
  user_t *exec_user;
  if (NULL != rgc_ptr->rgc_sa_preds)
    {
      t_set_push_new_string (&(rgc_ptr->rgc_sa_graphs),
        ((DV_ARRAY_OF_POINTER == DV_TYPE_OF (iriref)) ? iriref->_.lit.val : (caddr_t)iriref) );
    }
  if ((NULL == options) && (0 > dk_set_position_of_string (opts_ptr[0], "get:soft")))
    goto plain_source_without_sponge; /* see below */
  common_count = dk_set_length (opts_ptr[0]);
  mixed_tail = mixed_options = (SPART **)t_alloc_box ((common_count + 2 + BOX_ELEMENTS_0 (options)) * sizeof (SPART *), DV_ARRAY_OF_POINTER);
  DO_SET (SPART *, val, opts_ptr)
    {
      (mixed_tail++)[0] = (SPART *)t_full_box_copy_tree ((caddr_t)(val));
    }
  END_DO_SET()
  for (ctr = BOX_ELEMENTS_0 (options) - 2; 0 <= ctr; ctr -= 2)
    {
      ccaddr_t param = (ccaddr_t)(options[ctr]);
      const char **chk;
      for (chk = sparp_known_get_params; (NULL != chk[0]) && strcmp (chk[0], param); chk++) ;
      if (NULL == chk[0])
        spar_error (sparp, "Unsupported parameter '%.30s' in FROM ... (OPTION ...)", param);
      for (;;)
        {
          SPART *pval;
          caddr_t pvalbox;
          if (strcmp (param, "get:soft"))
            break;
          pval = options[ctr + 1];
          if (!SPAR_IS_LIT (pval))
            break;
          pvalbox = SPAR_LIT_OR_QNAME_VAL (pval);
          if (!DV_STRINGP (pvalbox) || strcmp (pvalbox, "disable"))
            break;
          goto plain_source_without_sponge; /* see below */
        }
      if (NULL != dk_set_getptr_keyword (opts_ptr[0], param))
        spar_error (sparp, "FROM ... (OPTION ... %s ...) conflicts with 'DEFINE %s ...", param, param);
      (mixed_tail++)[0] = (SPART *)t_full_box_copy_tree ((caddr_t)(param));
      (mixed_tail++)[0] = (SPART *)t_full_box_copy_tree ((caddr_t)(options[ctr + 1]));
    }
  if (!IS_BOX_POINTER (sparp->sparp_env->spare_sql_refresh_free_text))
    sparp->sparp_env->spare_sql_refresh_free_text = t_box_num_and_zero (0);
  (mixed_tail++)[0] = (SPART *) t_box_dv_short_string ("refresh_free_text");
  (mixed_tail++)[0] = (SPART *) sparp->sparp_env->spare_sql_refresh_free_text;
  for (ctr = BOX_ELEMENTS_0 (mixed_options) - 2; 0 <= ctr; ctr -= 2)
    {
      ccaddr_t param = (ccaddr_t)(mixed_options[ctr]);
      if (!strcmp (param, "get:private"))
        use_expn_in_gs_checks = 1;
    }
  exec_user = sparp->sparp_sparqre->sparqre_exec_user;
  return spartlist (sparp, 5, SPAR_GRAPH, subtype, iriref->_.qname.val,
    spar_make_funcall (sparp, 0, "SPECIAL::bif:iri_to_id",
      (SPART **)t_list (1,
        spar_make_funcall (sparp, 0, "sql:RDF_SPONGE_UP",
          (SPART **)t_list (3,
             iriref,
             spar_make_funcall (sparp, 0, "bif:vector", mixed_options),
             ((NULL != exec_user) ? exec_user->usr_id : U_ID_NOBODY) ) ) ) ),
    (ptrlong)use_expn_in_gs_checks );

plain_source_without_sponge:
  return spartlist (sparp, 5, SPAR_GRAPH, subtype, iriref->_.qname.val, iriref, (ptrlong)0);
}

SPART *
spar_default_sparul_target (sparp_t *sparp, const char *reason_to_use, int preliminary_call)
{
  dk_set_t dflt_graphs = sparp->sparp_env->spare_src.ssrc_default_graphs;
  SPART *u_graph = sparp->sparp_env->spare_src.ssrc_graph_set_by_with;
  if (NULL != u_graph)
    return sparp_tree_full_copy (sparp, (SPART *)(u_graph), NULL);
  if ((NULL == dflt_graphs) || (((SPART *)(dflt_graphs->data))->_.graph.subtype != SPART_GRAPH_FROM))
    {
      SPART *fbk_graph = sparp->sparp_env->spare_src.ssrc_fallback_target;
      if (NULL != fbk_graph)
        return sparp_tree_full_copy (sparp, (SPART *)(fbk_graph), NULL);
      if (preliminary_call)
        {
          sparp->sparp_env->spare_need_for_default_sparul_target = reason_to_use;
          return NULL;
        }
      fbk_graph = sparp->sparp_env->spare_src.ssrc_fallback_default_graph;
      if (NULL == fbk_graph)
        spar_error (sparp, "No plain default graph specified in the preamble, but it is needed for %.200s", reason_to_use);
      return sparp_tree_full_copy (sparp, (SPART *)(fbk_graph), NULL);
    }
  if ((NULL != dflt_graphs->next) && (((SPART *)(dflt_graphs->next->data))->_.graph.subtype < SPART_GRAPH_MIN_NEGATION))
    spar_error (sparp, "More than one default graph specified in the preamble; single default graph is needed for %.200s", reason_to_use);
  if (SPART_GRAPH_GROUP == ((SPART *)(dflt_graphs->data))->_.graph.subtype)
    spar_error (sparp, "The IRI in preamble refers to default graph group, not to a single default graph; the default graph is needed for %.200s", reason_to_use);
  return sparp_tree_full_copy (sparp, (SPART *)(dflt_graphs->data), NULL);
}

void
spar_apply_fallback_default_graph (sparp_t *sparp, int target_fallback_first)
{
  dk_set_t dflt_graphs = sparp->sparp_env->spare_src.ssrc_default_graphs;
  if ((NULL == dflt_graphs) || (((SPART *)(dflt_graphs->data))->_.graph.subtype > SPART_GRAPH_MIN_NEGATION))
    {
      SPART *fbk_graph = NULL;
      if (target_fallback_first)
        fbk_graph = sparp->sparp_env->spare_src.ssrc_fallback_target;
      if (NULL == fbk_graph)
        fbk_graph = sparp->sparp_env->spare_src.ssrc_fallback_default_graph;
      if (NULL != fbk_graph)
        sparp_make_and_push_new_graph_source (sparp, SPART_GRAPH_FROM, fbk_graph, NULL, SPARP_SSRC_FROZEN_BY_PROTOCOL);
    }
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
      spartlist (sparp, 5, SPAR_LIT, t_box_dv_short_nchars (val+1, final_len), NULL, NULL, NULL) );
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
  return sparp_make_builtin_call (sparp, LIKE_L,
    (SPART **)t_list (2, strg,
      spartlist (sparp, 5, SPAR_LIT, like_tmpl, NULL, NULL, NULL) ) );

bad_regex:
 return sparp_make_builtin_call (sparp, SPAR_BIF_REGEX, (SPART **)t_list (2, strg, regexpn));
}


extern id_hash_t *name_to_pl_name;

/* Note dirty hack in sqlpfn.c, sqlp_proc_name(): the function expectes that unsafe names begins with "RDF_", "SPARQL", "SPARUL" or "TTLP".
Add more prefixes there if needed */
static const char *spar_unsafe_sql_names[] = {
    "RDF_DELETE_TRIPLES",
    "RDF_DELETE_TRIPLES_AGG",
    "RDF_GLOBAL_RESET",
    "RDF_GRAPH_GROUP_LIST_GET",
    "RDF_INSERT_TRIPLES",
    "RDF_LOAD_RDFXML",
    "RDF_LOAD_RDFXML_MT",
    "RDF_MODIFY_TRIPLES",
    "RDF_QM_ADD_MAPPING_TO_STORAGE",
    "RDF_QM_APPLY_CHANGES",
    "RDF_QM_ASSERT_JSO_TYPE",
    "RDF_QM_ASSERT_STORAGE_CONTAINS_MAPPING",
    "RDF_QM_ASSERT_STORAGE_FLAG",
    "RDF_QM_ATTACH_MACRO_LIBRARY",
    "RDF_QM_ATTACH_MAPPING",
    "RDF_QM_ATTACH_SPIN_LIBRARY",
    "RDF_QM_BEGIN_ALTER_QUAD_STORAGE",
    "RDF_QM_CBD_OF_IRI_CLASS",
    "RDF_QM_CHANGE",
    "RDF_QM_CHANGE_OPT",
    "RDF_QM_CHECK_CLASS_FUNCTION_HEADERS",
    "RDF_QM_CHECK_COLUMNS_FORM_KEY",
    "RDF_QM_DEFINE_IRI_CLASS_FORMAT",
    "RDF_QM_DEFINE_IRI_CLASS_FUNCTIONS",
    "RDF_QM_DEFINE_LITERAL_CLASS_FORMAT",
    "RDF_QM_DEFINE_LITERAL_CLASS_FUNCTIONS",
    "RDF_QM_DEFINE_LITERAL_CLASS_WITH_FIXED_LANG",
    "RDF_QM_DEFINE_MAPPING",
    "RDF_QM_DEFINE_MAP_VALUE",
    "RDF_QM_DEFINE_QUAD_STORAGE",
    "RDF_QM_DEFINE_SUBCLASS",
    "RDF_QM_DELETE_MAPPING_FROM_STORAGE",
    "RDF_QM_DETACH_MACRO_LIBRARY",
    "RDF_QM_DETACH_SPIN_LIBRARY",
    "RDF_QM_DROP_CLASS",
    "RDF_QM_DROP_MAPPING",
    "RDF_QM_DROP_QUAD_STORAGE",
    "RDF_QM_DROP_SUBJ",
    "RDF_QM_END_ALTER_QUAD_STORAGE",
    "RDF_QM_FT_USAGE",
    "RDF_QM_GC_MAPPING_SUBTREE",
    "RDF_QM_GC_SUBTREE",
    "RDF_QM_MACROEXPAND_TEMPLATE",
    "RDF_QM_NN_PUT_VECTOR",
    "RDF_QM_NORMALIZE_QMV",
    "RDF_QM_SET_DEFAULT_MAPPING",
    "RDF_QM_STORE_ATABLES",
    "RDF_REPL_DELETE_TRIPLES",
    "RDF_REPL_GRAPH_DEL",
    "RDF_REPL_GRAPH_INS",
    "RDF_REPL_INSERT_TRIPLES",
    "RDF_REPL_START",
    "RDF_REPL_STOP",
    "RDF_REPL_SYNC",
    "RDF_SPONGE_UP",
    "SPARQL_DELETE_CTOR",
    "SPARQL_DELETE_DICT_CONTENT",
    "SPARQL_DELETE_QUAD_DICT_CONTENT",
    "SPARQL_DESC_AGG",
    "SPARQL_DESC_AGG_ACC",
    "SPARQL_DESC_AGG_FIN",
    "SPARQL_DESC_AGG_INIT",
    "SPARQL_DESC_DICT",
    "SPARQL_DESC_DICT_CBD",
    "SPARQL_DESC_DICT_CBD_PHYSICAL",
    "SPARQL_DESC_DICT_SPO",
    "SPARQL_DESC_DICT_SPO_PHYSICAL",
    "SPARQL_INSERT_CTOR",
    "SPARQL_INSERT_DICT_CONTENT",
    "SPARQL_INSERT_QUAD_DICT_CONTENT",
    "SPARQL_MODIFY_BY_DICT_CONTENTS",
    "SPARQL_MODIFY_BY_QUAD_DICT_CONTENTS",
    "SPARQL_SELECT_KNOWN_GRAPHS",
    "SPARUL_ADD",
    "SPARUL_CLEAR",
    "SPARUL_COPY",
    "SPARUL_CREATE",
    "SPARUL_DROP",
    "SPARUL_LOAD",
    "SPARUL_MOVE",
    "SPARUL_RUN",
    "TTLP",
    "TTLP_EV_COMMIT",
    "TTLP_EV_CL_GS_TRIPLE",
    "TTLP_EV_CL_GS_TRIPLE_L",
    "TTLP_EV_CL_TRIPLE",
    "TTLP_EV_CL_TRIPLE_L",
    "TTLP_EV_GET_IID",
    "TTLP_EV_NEW_BLANK",
    "TTLP_EV_NEW_GRAPH",
    "TTLP_EV_NEW_GRAPH_A",
    "TTLP_EV_TRIPLE",
    "TTLP_EV_TRIPLE_A",
    "TTLP_EV_TRIPLE_L",
    "TTLP_EV_TRIPLE_L_A",
    "TTLP_EV_TRIPLE_L_W",
    "TTLP_EV_TRIPLE_W",
    "TTLP_EV_TRIPLE_XLAT",
    "TTLP_EV_TRIPLE_XLAT_L",
    "TTLP_MT",
    "TTLP_MT_LOCAL_FILE" };

static const char *spar_unsafe_bif_names[] = {
    "BACKUP",
    "CONNECTION_SET",
    "CONNECTION_SWAP",
    "CONNECTION_VARS_SET",
    "EXEC",
    "FILE_TO_STRING",
    "FILE_TO_STRING_OUTPUT",
    "REGISTRY_SET",
    "REGISTRY_SET_ALL",
    "STRING_TO_FILE",
    "SYSTEM" };

static const char *sparql11_agg_names[] = {
    "AVG",		"SPECIAL::bif:AVG",
    "COUNT",		"SPECIAL::bif:COUNT",
    "GROUP_CONCAT",	"sql:GROUP_CONCAT",
    "MAX",		"SPECIAL::bif:MAX",
    "MIN",		"SPECIAL::bif:MIN",
    "SAMPLE",		"sql:SAMPLE",
    "SUM",		"SPECIAL::bif:SUM" };

int sparp_sql_function_name_is_unsafe (const char *buf)
{
  return (ECM_MEM_NOT_FOUND != ecm_find_name (buf, spar_unsafe_sql_names,
    sizeof (spar_unsafe_sql_names)/sizeof(spar_unsafe_sql_names[0]), sizeof (caddr_t) ) );
}

void
spar_verify_funcall_security (sparp_t *sparp, int *is_agg_ret, const char **fname_ptr, SPART **args)
{
  ccaddr_t fname = fname_ptr[0];
  int uid, need_check_for_sparql11_agg = 0;
  const char *tail, *tail_to_check_for_infection_chars = NULL;
  const char *c;
  char buf[100];
  int is_bif = 0, is_sql = 0;
  tail = strstr (fname, "::");
  if (NULL == tail)
    tail = fname;
  else
    tail += 2;
  if (NULL == sparp->sparp_boxed_exec_uid)
    spar_boxed_exec_uid (sparp);
  uid = unbox (sparp->sparp_boxed_exec_uid);
  if (!strncmp (tail, "sql:", 4))
    {
      tail_to_check_for_infection_chars = tail + 4;
      is_sql = 1;
    }
  else if (!strncmp (tail, "bif:", 4))
    {
      tail_to_check_for_infection_chars = tail + 4;
      is_bif = 1;
    }
  else if (!strncmp (tail, OPENLINKSW_SQL_NS_URI, OPENLINKSW_SQL_NS_URI_LEN))
    {
      tail_to_check_for_infection_chars = tail + OPENLINKSW_SQL_NS_URI_LEN;
      is_sql = 1;
    }
  else if (!strncmp (tail, OPENLINKSW_BIF_NS_URI, OPENLINKSW_BIF_NS_URI_LEN))
    {
      tail_to_check_for_infection_chars = tail + OPENLINKSW_SQL_NS_URI_LEN;
      is_bif = 1;
    }
  if (is_sql || is_bif)
    {
      strncpy (buf, tail_to_check_for_infection_chars, sizeof(buf)-1);
      buf[sizeof(buf)-1] = '\0';
      strupr (buf);
    }
  if (is_sql)
    {
      if ((U_ID_DBA != uid) && sparp_sql_function_name_is_unsafe (buf))
        goto restricted; /* see below */
      need_check_for_sparql11_agg = 1;
    }
  else if (is_bif)
    {
      if ((U_ID_DBA != uid) && sparp_sql_function_name_is_unsafe (buf))
        goto restricted; /* see below */
      if ((U_ID_DBA != uid) && (ECM_MEM_NOT_FOUND != ecm_find_name (buf, spar_unsafe_bif_names,
          sizeof (spar_unsafe_bif_names)/sizeof(spar_unsafe_bif_names[0]), sizeof (caddr_t) ) ) )
        goto restricted; /* see below */
      if (NULL != name_to_pl_name)
        {
          const char *raw_name = tail+4;
          caddr_t *full_sql_name_ptr = (caddr_t *) id_hash_get (name_to_pl_name, (caddr_t)(&raw_name));
          if (NULL != full_sql_name_ptr)
            {
              if (strncmp (full_sql_name_ptr[0], "DB.DBA.", 7))
                goto restricted; /* see below */
              strncpy (buf, full_sql_name_ptr[0]+7, sizeof(buf)-1);
              buf[sizeof(buf)-1] = '\0';
              strupr (buf);
              if ((U_ID_DBA != uid) && (ECM_MEM_NOT_FOUND != ecm_find_name (buf, spar_unsafe_sql_names,
                  sizeof (spar_unsafe_sql_names)/sizeof(spar_unsafe_sql_names[0]), sizeof (caddr_t) ) ) )
                goto restricted; /* see below */
              strcpy (buf, "sql:");
              strncpy (buf+4, full_sql_name_ptr[0]+7, sizeof(buf)-5);
              buf[sizeof(buf)-1] = '\0';
              fname_ptr[0] = t_box_dv_uname_string (buf);
              return;
            }
        }
      need_check_for_sparql11_agg = 1;
    }
  if (need_check_for_sparql11_agg)
    {
      int agg_idx = ecm_find_name (buf, sparql11_agg_names,
        sizeof (sparql11_agg_names)/(2 * sizeof(ccaddr_t)), 2 * sizeof (caddr_t) );
      if (ECM_MEM_NOT_FOUND != agg_idx)
        {
          fname_ptr[0] = sparql11_agg_names [agg_idx*2 + 1];
          is_agg_ret[0] = 1;
          return;
        }
    }
  if (NULL != tail_to_check_for_infection_chars)
    for (c = tail_to_check_for_infection_chars; '\0' != c[0]; c++)
      if (strchr ("\'\"\\().,+/*|\t\n\r", c[0]))
        spar_error (sparp, "Function name \"%.200s\" contains invalid characters; this may be an attempt to bypass security restrictions", fname);
  return;
restricted:
  spar_error (sparp, "Function %.200s() cannot be used in text of SPARQL query due to security restrictions", fname);
}

caddr_t
spar_colonize_qname_uname (const char *strg)
{
  const char *tail, *strg_end = strg + strlen (strg);
  for (tail = strg_end; tail > strg; tail--)
    if (!isplainURIchar (tail[-1]))
      {
        caddr_t res;
        BOX_DV_UNAME_COLONCONCAT5(res, strg, tail-strg, tail, strg_end-tail);
        return res;
      }
  return box_dv_uname_string (strg);
}

SPART *
spar_run_pure_bif_in_sandbox (sparp_t *sparp, const char *funname, SPART **args, int argcount, bif_metadata_t *bmd, int *trouble_ret)
{
  int argctr;
  caddr_t *sqlargs;
  caddr_t err = NULL;
  caddr_t ret_val;
  for (argctr = argcount; argctr--; /* no step */)
    {
      SPART *arg = args[argctr];
      int argtype = SPART_TYPE (arg);
      switch (argtype)
        {
          case SPAR_QNAME: continue;
          case SPAR_LIT:
            {
              if (DV_ARRAY_OF_POINTER != DV_TYPE_OF (arg))
                continue;
              if ((NULL == arg->_.lit.language) &&
                ((NULL == arg->_.lit.datatype) || (xsd_type_of_box (arg->_.lit.val) == arg->_.lit.datatype)) )
                continue;
              trouble_ret[0] = 2;
              return NULL; /* Cases that require rdf box are excluded because making rdf box from IRI strings is not pure by itself (it requires at least IRI_IDs) */
            }
        }
      trouble_ret[0] = 1;
      return NULL;
    }
  sqlargs = (caddr_t *)t_alloc_list (argcount);
  for (argctr = argcount; argctr--; /* no step */)
    sqlargs[argctr] = SPAR_LIT_OR_QNAME_VAL (args[argctr]); /* complicated cases like unusually typed literal or a literal with language are excluded in the check above, so this is safe */
  ret_val = sqlr_run_bif_in_sandbox (bmd, sqlargs, &err);
  if (NULL == err)
    {
      SPART *lit = spar_make_literal_from_sql_box (sparp, ret_val, SPAR_ML_RESULT_FROM_SANDBOX);
      dk_free_box (ret_val);
      if (NULL != lit)
        {
          trouble_ret[0] = 0;
          return lit;
        }
    }
  else
    {
      trouble_ret[0] = 0;
      return spartlist (sparp, 5, SPAR_FUNCALL, t_box_dv_uname_string ("bif:signal"), t_list (2,
          spar_make_literal_from_sql_box (sparp, ERR_STATE (err), SPAR_ML_SAFEST),
          spar_make_literal_from_sql_box (sparp, ERR_MESSAGE (err), SPAR_ML_SAFEST) ),
        (ptrlong)0, (ptrlong)0 );
    }
  trouble_ret[0] = 2;
  return NULL; /* Some nontrivial cast is needed, so can execute but anyway can not optimize */
}

SPART *
spar_make_funcall (sparp_t *sparp, int aggregate_mode, const char *funname, SPART **args)
{
  const char *sql_colon;
  caddr_t proc_full_name;
  query_t *proc;
  int argcount;
  const char *funname_to_store = funname;
  const char *bare_bif_name = NULL;
  bif_metadata_t *bmd = NULL;
  if (NULL == args)
    args = (SPART **)t_list (0);
  argcount = BOX_ELEMENTS (args);
  if ('h' == funname[0]) /* It's kond of strange to begin function name name with 'h', right? 99% of them are bif:... or sql:... */
    {
      if (!strncmp (funname, OPENLINKSW_BIF_NS_URI, OPENLINKSW_BIF_NS_URI_LEN))
        return spar_make_funcall (sparp, aggregate_mode, t_box_dv_short_strconcat ("bif:", funname + OPENLINKSW_BIF_NS_URI_LEN), args);
      if (!strncmp (funname, OPENLINKSW_SQL_NS_URI, OPENLINKSW_SQL_NS_URI_LEN))
        return spar_make_funcall (sparp, aggregate_mode, t_box_dv_short_strconcat ("sql:", funname + OPENLINKSW_SQL_NS_URI_LEN), args);
      if (!strncmp (funname, OPENGIS_NS_URI, OPENGIS_NS_URI_LEN))
        {
          funname_to_store = t_box_dv_short_strconcat ("bif:", funname);
          bare_bif_name = funname;
          goto bare_bif_name_found; /* see below */
        }
    }
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
  if (!(sparp->sparp_allow_aggregates_in_expn & 1))
    spar_error (sparp, "Aggregate function %.100s() is not allowed outside result-set expressions", funname);
aggr_checked:
  if (!strncmp (funname, "bif:", 4))
    bare_bif_name = funname + 4;
bare_bif_name_found:
  if (NULL != bare_bif_name)
    {
      bmd = find_bif_metadata_by_raw_name (bare_bif_name);
      if (NULL == bmd)
        spar_error (sparp, "Unknown function %.100s()", funname);
      if (bmd->bmd_is_pure)
        {
          int trouble = 0;
          SPART * optimized = spar_run_pure_bif_in_sandbox (sparp, funname, args, argcount, bmd, &trouble);
          if (!trouble)
            return optimized;
        }
    }
  else
    {
      xpf_metadata_t *metas = NULL;
      caddr_t colonized_funname = spar_colonize_qname_uname (funname);
      xpf_metadata_t ** metas_ptr = (xpf_metadata_t **)id_hash_get (xpf_metas, (caddr_t)(&colonized_funname));
      char namebuf[110];
      if (NULL == metas_ptr)
        {
          dk_free_box (colonized_funname);
          goto xpf_checked; /* see below */
        }
      metas = metas_ptr[0];
      if (metas->xpfm_min_arg_no > argcount)
        spar_error (sparp, "The XPATH function %.200s() requires %d arguments but the call contains only %d",
          funname, (int)(metas->xpfm_min_arg_no), argcount );
      if (metas->xpfm_main_arg_no < argcount)
        {
          if (0 == metas->xpfm_tail_arg_no)
            spar_error (sparp, "The XPATH function %.200s() can handle only %d arguments but the call provides %d",
              funname, (int)(metas->xpfm_main_arg_no), argcount );
          else
            {
              int tail_mod = (argcount - metas->xpfm_main_arg_no) % metas->xpfm_tail_arg_no;
              if (tail_mod)
                spar_error (sparp, "The XPATH function %.200s() can handle %d, %d, %d, etc., arguments, but the call provides %d",
                  funname, (int)(metas->xpfm_main_arg_no), (int)(metas->xpfm_main_arg_no + metas->xpfm_tail_arg_no), (int)(metas->xpfm_main_arg_no + 2 * metas->xpfm_tail_arg_no),
                  argcount );
            }
        }
      sprintf (namebuf, "xpath:%.90s", colonized_funname);
      return spartlist (sparp, 5, SPAR_FUNCALL, t_box_dv_uname_string (namebuf), args, (ptrlong)0, (ptrlong)0);
    }
xpf_checked:
  if (aggregate_mode)
    {
      if (SPARP_DEFBODY & sparp->sparp_macro_mode)
        sparp->sparp_current_macro->_.defmacro.aggregate_count++;
      else
        sparp->sparp_query_uses_aggregates++;
    }
  return spartlist (sparp, 5, SPAR_FUNCALL, t_box_dv_uname_string (funname_to_store), args, (ptrlong)aggregate_mode, (ptrlong)0);
}


const sparp_bif_desc_t sparp_bif_descs[] = {
/*  sbd_name		| sbd_subtype			, impl	| sbd_required_syntax	| min-/maxargs	| ret_valmode		| sbd_arg_valmodes					| sbd_result_restr_bits		*/
  { ""			, 0				, '-'	, 0			, 0	, 0	, NULL			, { SSG_VALMODE_SQLVAL, NULL, NULL}			, 0	},
  { "abs"		, SPAR_BIF_ABS			, 'B'	, SSG_SD_SPARQL11_DRAFT	, 1	, 1	, SSG_VALMODE_NUM	, { SSG_VALMODE_NUM, NULL, NULL}			, SPART_VARR_IS_LIT | SPART_VARR_NOT_NULL | SPART_VARR_LONG_EQ_SQL	},
  { "assume"		, ASSUME_L			, '-'	, SSG_SD_VIRTSPECIFIC	, 1	, 1	, SSG_VALMODE_BOOL	, { SSG_VALMODE_BOOL, NULL, NULL}			, SPART_VARR_IS_LIT | SPART_VARR_NOT_NULL | SPART_VARR_LONG_EQ_SQL | SPART_VARR_IS_BOOL	},
  { "bnode"		, SPAR_BIF_BNODE		, '-'	, SSG_SD_SPARQL11_DRAFT	, 0	, 1	, SSG_VALMODE_LONG	, { SSG_VALMODE_SQLVAL, NULL, NULL}			, SPART_VARR_IS_BLANK | SPART_VARR_IS_REF	},
  { "bound"		, BOUND_L			, '-'	, 0			, 1	, 1	, SSG_VALMODE_BOOL	, { SSG_VALMODE_SQLVAL, NULL, NULL}			, SPART_VARR_IS_LIT | SPART_VARR_NOT_NULL | SPART_VARR_LONG_EQ_SQL | SPART_VARR_IS_BOOL	},
  { "case WHEN operator", SPAR_BIF_CASEWHEN		, 'B'	, SSG_SD_VIRTSPECIFIC	, 3	, 0xFFF	, NULL			, { NULL, NULL, NULL}					, 0	},
  { "case X operator"	, SPAR_BIF_CASEX		, 'B'	, SSG_SD_VIRTSPECIFIC	, 4	, 0xFFF	, NULL			, { NULL, NULL, NULL}					, 0	},
  { "ceil"		, SPAR_BIF_CEIL			, 'B'	, SSG_SD_SPARQL11_DRAFT	, 1	, 1	, SSG_VALMODE_NUM	, { SSG_VALMODE_NUM, NULL, NULL}			, 0	},
  { "coalesce"		, SPAR_BIF_COALESCE		, '-'	, SSG_SD_SPARQL11_DRAFT	, 0	, 0xFFF	, NULL			, { SSG_VALMODE_SQLVAL, NULL, NULL}			, 0	},
  { "concat"		, SPAR_BIF_CONCAT		, 'B'	, SSG_SD_SPARQL11_DRAFT	, 0	, 0xFFF	, SSG_VALMODE_SQLVAL	, { SSG_VALMODE_SQLVAL, NULL, NULL}			, SPART_VARR_IS_LIT | SPART_VARR_NOT_NULL	},
  { "contains"		, SPAR_BIF_CONTAINS		, 'B'	, SSG_SD_SPARQL11_DRAFT	, 2	, 2	, SSG_VALMODE_BOOL	, { SSG_VALMODE_LONG, SSG_VALMODE_LONG, NULL}		, SPART_VARR_IS_LIT | SPART_VARR_NOT_NULL | SPART_VARR_LONG_EQ_SQL | SPART_VARR_IS_BOOL	},
  { "cube"		, SPAR_BIF__CUBE			, '-'	, SSG_SD_VIRTSPECIFIC	, 2	, 0xFFF	, SSG_VALMODE_SQLVAL	, { NULL, NULL, NULL}					, SPART_VARR_IS_LIT | SPART_VARR_NOT_NULL | SPART_VARR_LONG_EQ_SQL	},
  { "datatype"		, DATATYPE_L			, '-'	, 0			, 1	, 1	, SSG_VALMODE_SQLVAL	, { SSG_VALMODE_LONG, NULL, NULL}			, SPART_VARR_IS_IRI | SPART_VARR_IS_REF	},
  { "day"		, SPAR_BIF_DAY			, 'B'	, SSG_SD_SPARQL11_DRAFT	, 1	, 1	, SSG_VALMODE_NUM	, { SSG_VALMODE_NUM, NULL, NULL}			, SPART_VARR_IS_LIT | SPART_VARR_NOT_NULL | SPART_VARR_LONG_EQ_SQL	},
  { "ebv"		, SPAR_BIF_EBV			, '-'	, SSG_SD_VIRTSPECIFIC	, 1	, 1	, SSG_VALMODE_SQLVAL	, { SSG_VALMODE_SQLVAL, NULL, NULL}			, SPART_VARR_IS_LIT	},
  { "ebv_int"		, SPAR_BIF_EBV_INT		, '-'	, SSG_SD_VIRTSPECIFIC	, 1	, 1	, SSG_VALMODE_NUM	, { SSG_VALMODE_SQLVAL, NULL, NULL}			, SPART_VARR_IS_LIT | SPART_VARR_LONG_EQ_SQL | SPART_VARR_IS_BOOL	},
  { "encode_for_uri"	, SPAR_BIF_ENCODE_FOR_URI	, 'B'	, SSG_SD_SPARQL11_DRAFT	, 1	, 1	, SSG_VALMODE_SQLVAL	, { SSG_VALMODE_SQLVAL, NULL, NULL}			, SPART_VARR_IS_LIT | SPART_VARR_NOT_NULL	},
  { "floor"		, SPAR_BIF_FLOOR		, 'B'	, SSG_SD_SPARQL11_DRAFT	, 1	, 1	, SSG_VALMODE_NUM	, { SSG_VALMODE_NUM, NULL, NULL}			, SPART_VARR_IS_LIT | SPART_VARR_NOT_NULL | SPART_VARR_LONG_EQ_SQL	},
  { "grouping list"	, SPAR_BIF__GROUPING_LIST	, '-'	, SSG_SD_VIRTSPECIFIC	, 0	, 0xFFF	, SSG_VALMODE_SQLVAL	, { NULL, NULL, NULL}					, SPART_VARR_IS_LIT | SPART_VARR_NOT_NULL | SPART_VARR_LONG_EQ_SQL	},
  { "grouping set"	, SPAR_BIF__GROUPING_SET	, '-'	, SSG_SD_VIRTSPECIFIC	, 2	, 2	, SSG_VALMODE_SQLVAL	, { NULL, NULL, NULL}					, SPART_VARR_IS_LIT | SPART_VARR_NOT_NULL | SPART_VARR_LONG_EQ_SQL	},
  { "grouping sets"	, SPAR_BIF__GROUPING_SETS	, '-'	, SSG_SD_VIRTSPECIFIC	, 1	, 0xFFF	, SSG_VALMODE_SQLVAL	, { NULL, NULL, NULL}					, SPART_VARR_IS_LIT | SPART_VARR_NOT_NULL | SPART_VARR_LONG_EQ_SQL	},
  { "hours"		, SPAR_BIF_HOURS		, 'B'	, SSG_SD_SPARQL11_DRAFT	, 1	, 1	, SSG_VALMODE_NUM	, { SSG_VALMODE_NUM, NULL, NULL}			, SPART_VARR_IS_LIT | SPART_VARR_NOT_NULL | SPART_VARR_LONG_EQ_SQL	},
  { "if"		, SPAR_BIF_IF			, '-'	, SSG_SD_SPARQL11_DRAFT	, 3	, 3	, NULL			, { SSG_VALMODE_BOOL, NULL, NULL}			, 0	},
  { "in operator"	, IN_L				, '-'	, 0			, 1	, 0xFFF	, SSG_VALMODE_BOOL	, { SSG_VALMODE_SQLVAL, NULL, NULL}			, SPART_VARR_IS_LIT | SPART_VARR_NOT_NULL | SPART_VARR_LONG_EQ_SQL | SPART_VARR_IS_BOOL	},
  { "in-vector operator", SPAR_BIF__ITEM_IN_VECTOR	, '-'	, SSG_SD_BI		, 2	, 2	, SSG_VALMODE_BOOL	, { SSG_VALMODE_SQLVAL, SSG_VALMODE_SQLVAL, NULL}	, SPART_VARR_IS_LIT | SPART_VARR_NOT_NULL | SPART_VARR_LONG_EQ_SQL | SPART_VARR_IS_BOOL	},
  { "iri"		, IRI_L				, '-'	, SSG_SD_BI_OR_SPARQL11_DRAFT	, 1	, 1	, SSG_VALMODE_LONG	, { SSG_VALMODE_SQLVAL, NULL, NULL}			, SPART_VARR_IS_IRI | SPART_VARR_IS_REF | SPART_VARR_NOT_NULL	},
  { "isblank"		, SPAR_BIF_ISBLANK		, '-'	, 0			, 1	, 1	, SSG_VALMODE_BOOL	, { SSG_VALMODE_SQLVAL, NULL, NULL}			, SPART_VARR_IS_LIT | SPART_VARR_NOT_NULL | SPART_VARR_LONG_EQ_SQL | SPART_VARR_IS_BOOL	},
  { "isiri"		, SPAR_BIF_ISIRI		, '-'	, 0			, 1	, 1	, SSG_VALMODE_BOOL	, { SSG_VALMODE_SQLVAL, NULL, NULL}			, SPART_VARR_IS_LIT | SPART_VARR_NOT_NULL | SPART_VARR_LONG_EQ_SQL | SPART_VARR_IS_BOOL	},
  { "isliteral"		, SPAR_BIF_ISLITERAL		, '-'	, 0			, 1	, 1	, SSG_VALMODE_BOOL	, { SSG_VALMODE_SQLVAL, NULL, NULL}			, SPART_VARR_IS_LIT | SPART_VARR_NOT_NULL | SPART_VARR_LONG_EQ_SQL | SPART_VARR_IS_BOOL	},
  { "isnumeric"		, SPAR_BIF_ISNUMERIC		, '-'	, SSG_SD_SPARQL11_DRAFT	, 1	, 1	, SSG_VALMODE_BOOL	, { SSG_VALMODE_NUM, NULL, NULL}			, SPART_VARR_IS_LIT | SPART_VARR_NOT_NULL | SPART_VARR_LONG_EQ_SQL | SPART_VARR_IS_BOOL	},
  { "isref"		, SPAR_BIF_ISREF		, '-'	, SSG_SD_BI		, 1	, 1	, SSG_VALMODE_BOOL	, { SSG_VALMODE_SQLVAL, NULL, NULL}			, SPART_VARR_IS_LIT | SPART_VARR_NOT_NULL | SPART_VARR_LONG_EQ_SQL | SPART_VARR_IS_BOOL	},
  { "isuri"		, SPAR_BIF_ISURI		, '-'	, 0			, 1	, 1	, SSG_VALMODE_BOOL	, { SSG_VALMODE_SQLVAL, NULL, NULL}			, SPART_VARR_IS_LIT | SPART_VARR_NOT_NULL | SPART_VARR_LONG_EQ_SQL | SPART_VARR_IS_BOOL	},
  { "lang"		, LANG_L			, '-'	, 0			, 1	, 1	, SSG_VALMODE_SQLVAL	, { SSG_VALMODE_LONG, NULL, NULL}			, SPART_VARR_IS_LIT	},
  { "langmatches"	, SPAR_BIF_LANGMATCHES		, '-'	, 0			, 2	, 2	, SSG_VALMODE_BOOL	, { SSG_VALMODE_LONG, SSG_VALMODE_SQLVAL, NULL}		, SPART_VARR_IS_LIT | SPART_VARR_NOT_NULL | SPART_VARR_LONG_EQ_SQL | SPART_VARR_IS_BOOL	},
  { "like operator"	, LIKE_L			, '-'	, 0			, 2	, 2	, SSG_VALMODE_BOOL	, { SSG_VALMODE_SQLVAL, SSG_VALMODE_SQLVAL, NULL}	, SPART_VARR_IS_LIT | SPART_VARR_NOT_NULL | SPART_VARR_LONG_EQ_SQL | SPART_VARR_IS_BOOL	},
  { "lcase"		, SPAR_BIF_LCASE		, 'B'	, SSG_SD_SPARQL11_DRAFT	, 1	, 1	, SSG_VALMODE_LONG	, { SSG_VALMODE_LONG, NULL, NULL}			, SPART_VARR_IS_LIT	},
  { "md5"		, SPAR_BIF_MD5			, 'B'	, SSG_SD_SPARQL11_DRAFT	, 1	, 1	, SSG_VALMODE_SQLVAL	, { SSG_VALMODE_SQLVAL, NULL, NULL}			, SPART_VARR_IS_LIT | SPART_VARR_NOT_NULL	},
  { "minutes"		, SPAR_BIF_MINUTES		, 'B'	, SSG_SD_SPARQL11_DRAFT	, 1	, 1	, SSG_VALMODE_NUM	, { SSG_VALMODE_NUM, NULL, NULL}			, SPART_VARR_IS_LIT | SPART_VARR_NOT_NULL | SPART_VARR_LONG_EQ_SQL	},
  { "month"		, SPAR_BIF_MONTH		, 'B'	, SSG_SD_SPARQL11_DRAFT	, 1	, 1	, SSG_VALMODE_NUM	, { SSG_VALMODE_NUM, NULL, NULL}			, SPART_VARR_IS_LIT | SPART_VARR_NOT_NULL | SPART_VARR_LONG_EQ_SQL	},
  { "now"		, SPAR_BIF_NOW			, 'B'	, SSG_SD_SPARQL11_DRAFT	, 0	, 0	, SSG_VALMODE_NUM	, { SSG_VALMODE_SQLVAL, NULL, NULL}			, SPART_VARR_IS_LIT | SPART_VARR_NOT_NULL | SPART_VARR_LONG_EQ_SQL	},
  { "rand"		, SPAR_BIF_RAND			, 'B'	, SSG_SD_SPARQL11_DRAFT	, 0	, 1	, SSG_VALMODE_NUM	, { SSG_VALMODE_SQLVAL, NULL, NULL}			, SPART_VARR_IS_LIT | SPART_VARR_NOT_NULL | SPART_VARR_LONG_EQ_SQL	},
  { "regex"		, SPAR_BIF_REGEX		, 'B'	, 0			, 2	, 3	, SSG_VALMODE_BOOL	, { SSG_VALMODE_SQLVAL, SSG_VALMODE_SQLVAL, SSG_VALMODE_SQLVAL}			, SPART_VARR_IS_LIT | SPART_VARR_NOT_NULL | SPART_VARR_LONG_EQ_SQL | SPART_VARR_IS_BOOL	},
  { "replace"		, SPAR_BIF_REPLACE		, 'S'	, SSG_SD_SPARQL11_DRAFT	, 3	, 4	, SSG_VALMODE_LONG	, { SSG_VALMODE_LONG, SSG_VALMODE_SQLVAL, SSG_VALMODE_SQLVAL}	, SPART_VARR_IS_LIT | SPART_VARR_NOT_NULL	},
  { "remove_unicode3_accents"	, SPAR_BIF_REMOVE_UNICODE3_ACCENTS		, 'B'	, SSG_SD_BI	, 1	, 1	, SSG_VALMODE_LONG	, { SSG_VALMODE_LONG, NULL, NULL}	, SPART_VARR_IS_LIT	},
  { "round"		, SPAR_BIF_ROUND		, 'B'	, SSG_SD_SPARQL11_DRAFT	, 1	, 1	, SSG_VALMODE_NUM	, { SSG_VALMODE_NUM, NULL, NULL}			, SPART_VARR_IS_LIT | SPART_VARR_NOT_NULL | SPART_VARR_LONG_EQ_SQL	},
  { "sameterm"		, SPAR_BIF_SAMETERM		, '-'	, 0			, 2	, 2	, SSG_VALMODE_BOOL	, { SSG_VALMODE_LONG, SSG_VALMODE_LONG, NULL}			, SPART_VARR_IS_LIT | SPART_VARR_NOT_NULL | SPART_VARR_LONG_EQ_SQL | SPART_VARR_IS_BOOL	},
  { "rollup"		, SPAR_BIF__ROLLUP		, '-'	, SSG_SD_VIRTSPECIFIC	, 2	, 0xFFF	, SSG_VALMODE_SQLVAL	, { NULL, NULL, NULL}					, SPART_VARR_IS_LIT | SPART_VARR_NOT_NULL | SPART_VARR_LONG_EQ_SQL	},
  { "seconds"		, SPAR_BIF_SECONDS		, 'B'	, SSG_SD_SPARQL11_DRAFT	, 1	, 1	, SSG_VALMODE_NUM	, { SSG_VALMODE_NUM, NULL, NULL}			, SPART_VARR_IS_LIT | SPART_VARR_NOT_NULL | SPART_VARR_LONG_EQ_SQL	},
  { "sha1"		, SPAR_BIF_SHA1			, 'B'	, SSG_SD_SPARQL11_DRAFT	, 1	, 1	, SSG_VALMODE_SQLVAL	, { SSG_VALMODE_SQLVAL, NULL, NULL}			, SPART_VARR_IS_LIT | SPART_VARR_NOT_NULL	},
  { "sha224"		, SPAR_BIF_SHA224		, 'B'	, SSG_SD_SPARQL11_DRAFT	, 1	, 1	, SSG_VALMODE_SQLVAL	, { SSG_VALMODE_SQLVAL, NULL, NULL}			, SPART_VARR_IS_LIT | SPART_VARR_NOT_NULL	},
  { "sha256"		, SPAR_BIF_SHA256		, 'B'	, SSG_SD_SPARQL11_DRAFT	, 1	, 1	, SSG_VALMODE_SQLVAL	, { SSG_VALMODE_SQLVAL, NULL, NULL}			, SPART_VARR_IS_LIT | SPART_VARR_NOT_NULL	},
  { "sha384"		, SPAR_BIF_SHA384		, 'B'	, SSG_SD_SPARQL11_DRAFT	, 1	, 1	, SSG_VALMODE_SQLVAL	, { SSG_VALMODE_SQLVAL, NULL, NULL}			, SPART_VARR_IS_LIT | SPART_VARR_NOT_NULL	},
  { "sha512"		, SPAR_BIF_SHA512		, 'B'	, SSG_SD_SPARQL11_DRAFT	, 1	, 1	, SSG_VALMODE_SQLVAL	, { SSG_VALMODE_SQLVAL, NULL, NULL}			, SPART_VARR_IS_LIT | SPART_VARR_NOT_NULL	},
  { "str"		, SPAR_BIF_STR			, '-'	, 0			, 1	, 1	, SSG_VALMODE_SQLVAL	, { SSG_VALMODE_SQLVAL, NULL, NULL}			, SPART_VARR_IS_LIT	},
  { "strafter"		, SPAR_BIF_STRAFTER		, 'B'	, SSG_SD_SPARQL11_DRAFT	, 2	, 2	, SSG_VALMODE_SQLVAL	, { SSG_VALMODE_LONG, SSG_VALMODE_LONG, NULL}			, SPART_VARR_IS_LIT | SPART_VARR_NOT_NULL	},
  { "strbefore"		, SPAR_BIF_STRBEFORE		, 'B'	, SSG_SD_SPARQL11_DRAFT	, 2	, 2	, SSG_VALMODE_SQLVAL	, { SSG_VALMODE_LONG, SSG_VALMODE_LONG, NULL}			, SPART_VARR_IS_LIT | SPART_VARR_NOT_NULL	},
  { "strdt"		, SPAR_BIF_STRDT		, 'S'	, SSG_SD_SPARQL11_DRAFT	, 2	, 2	, SSG_VALMODE_LONG	, { SSG_VALMODE_SQLVAL, NULL, NULL}			, SPART_VARR_IS_LIT	},
  { "strends"		, SPAR_BIF_STRENDS		, 'B'	, SSG_SD_SPARQL11_DRAFT	, 2	, 2	, SSG_VALMODE_BOOL	, { SSG_VALMODE_LONG, SSG_VALMODE_LONG, NULL}			, SPART_VARR_IS_LIT | SPART_VARR_NOT_NULL | SPART_VARR_LONG_EQ_SQL | SPART_VARR_IS_BOOL	},
  { "strlang"		, SPAR_BIF_STRLANG		, 'S'	, SSG_SD_SPARQL11_DRAFT	, 2	, 2	, SSG_VALMODE_LONG	, { SSG_VALMODE_SQLVAL, NULL, NULL}			, SPART_VARR_IS_LIT	},
  { "strlen"		, SPAR_BIF_STRLEN		, 'B'	, SSG_SD_SPARQL11_DRAFT	, 1	, 1	, SSG_VALMODE_NUM	, { SSG_VALMODE_SQLVAL, NULL, NULL}			, SPART_VARR_IS_LIT | SPART_VARR_NOT_NULL | SPART_VARR_LONG_EQ_SQL	},
  { "strstarts"		, SPAR_BIF_STRSTARTS		, 'B'	, SSG_SD_SPARQL11_DRAFT	, 2	, 2	, SSG_VALMODE_BOOL	, { SSG_VALMODE_LONG, SSG_VALMODE_LONG, NULL}			, SPART_VARR_IS_LIT | SPART_VARR_NOT_NULL | SPART_VARR_LONG_EQ_SQL | SPART_VARR_IS_BOOL	},
  { "struuid"		, SPAR_BIF_STRUUID		, 'B'	, SSG_SD_SPARQL11_DRAFT	, 0	, 0	, SSG_VALMODE_SQLVAL	, { SSG_VALMODE_LONG, NULL, NULL}			, SPART_VARR_IS_LIT | SPART_VARR_NOT_NULL	},
  { "substr"		, SPAR_BIF_SUBSTR		, 'B'	, SSG_SD_SPARQL11_DRAFT	, 2	, 3	, SSG_VALMODE_SQLVAL	, { SSG_VALMODE_LONG, SSG_VALMODE_NUM, SSG_VALMODE_NUM}			, SPART_VARR_IS_LIT	},
  { "timezone"		, SPAR_BIF_TIMEZONE		, 'S'	, SSG_SD_SPARQL11_DRAFT	, 1	, 1	, SSG_VALMODE_NUM	, { SSG_VALMODE_NUM, NULL, NULL}			, SPART_VARR_IS_LIT | SPART_VARR_NOT_NULL | SPART_VARR_LONG_EQ_SQL	},
  { "top"		, TOP_L				, '-'	, SSG_SD_VIRTSPECIFIC	, 4	, 4	, SSG_VALMODE_SQLVAL	, { NULL, NULL, NULL}					, SPART_VARR_IS_LIT | SPART_VARR_NOT_NULL | SPART_VARR_LONG_EQ_SQL	},
  { "tz"		, SPAR_BIF_TZ			, 'S'	, SSG_SD_SPARQL11_DRAFT	, 1	, 1	, SSG_VALMODE_SQLVAL	, { SSG_VALMODE_NUM, NULL, NULL}			, SPART_VARR_IS_LIT | SPART_VARR_NOT_NULL | SPART_VARR_LONG_EQ_SQL	},
  { "ucase"		, SPAR_BIF_UCASE		, 'B'	, SSG_SD_SPARQL11_DRAFT	, 1	, 1	, SSG_VALMODE_LONG	, { SSG_VALMODE_LONG, NULL, NULL}			, SPART_VARR_IS_LIT	},
  { "uri"		, SPAR_BIF_URI			, '-'	, SSG_SD_BI_OR_SPARQL11_DRAFT	, 1	, 1	, SSG_VALMODE_LONG	, { SSG_VALMODE_SQLVAL, NULL, NULL}			, SPART_VARR_IS_IRI | SPART_VARR_IS_REF	},
  { "uuid"		, SPAR_BIF_UUID			, 'S'	, SSG_SD_SPARQL11_DRAFT	, 0	, 0	, SSG_VALMODE_LONG	, { SSG_VALMODE_LONG, NULL, NULL}			, SPART_VARR_IS_IRI | SPART_VARR_NOT_NULL	},
  { "valid"		, SPAR_BIF_VALID		, 'B'	, SSG_SD_VOS_6		, 1	, 1	, SSG_VALMODE_BOOL	, { SSG_VALMODE_LONG, NULL, NULL}			, SPART_VARR_IS_LIT | SPART_VARR_NOT_NULL | SPART_VARR_LONG_EQ_SQL | SPART_VARR_IS_BOOL	},
  { "year"		, SPAR_BIF_YEAR			, 'B'	, SSG_SD_SPARQL11_DRAFT	, 1	, 1	, SSG_VALMODE_NUM	, { SSG_VALMODE_NUM, NULL, NULL}			, SPART_VARR_IS_LIT | SPART_VARR_NOT_NULL | SPART_VARR_LONG_EQ_SQL	}
};

SPART *
sparp_make_builtin_call (sparp_t *sparp, ptrlong bif_id, SPART **arguments)
{
  ptrlong ofs;
  for (ofs = sizeof (sparp_bif_descs)/sizeof (sparp_bif_descs[0]); ofs--; /* no step */)
    {
      const sparp_bif_desc_t *sbd = sparp_bif_descs + ofs;
      int argcount;
      if (sbd->sbd_subtype != bif_id)
        continue;
      argcount = BOX_ELEMENTS_0 (arguments);
      if (argcount < sbd->sbd_minargs)
        sparyyerror_impl (sparp, NULL, t_box_sprintf (100, "Too few arguments for standard built-in function %s()", sbd->sbd_name));
      if (argcount > sbd->sbd_maxargs)
        sparyyerror_impl (sparp, NULL, t_box_sprintf (100, "Too many arguments for standard built-in function %s()", sbd->sbd_name));
      goto ofs_found; /* see below */
    }
  spar_internal_error (sparp, "sparp" "_make_builtin_call(): bad bif_id");
ofs_found:
  return spartlist (sparp, 4, SPAR_BUILT_IN_CALL, bif_id, ofs, arguments);
}

SPART *
sparp_make_macro_call (sparp_t *sparp, const char *mname, int call_is_explicit, SPART **args)
{
  SPART *mdecl = spar_find_defmacro_by_iri_or_fields (sparp, mname, NULL);
  SPART *g_ctx, *res;
  dk_set_t g_ctxs;
  int argcount, paramcount;
  if (NULL == mdecl)
    spar_internal_error (sparp, "sparp_" "make_macro_call(): undefined macro");
  paramcount = BOX_ELEMENTS (mdecl->_.defmacro.paramnames);
  argcount = BOX_ELEMENTS_0 (args);
  if (paramcount != argcount)
    spar_error (sparp, "The macro <%.200s> is used with %d arguments, %d expected", mname, argcount, paramcount);
  g_ctxs = sparp->sparp_env->spare_context_graphs;
  g_ctx = ((NULL != g_ctxs) ? (SPART *)t_full_box_copy_tree ((caddr_t)(g_ctxs->data)) : NULL);
  res = spartlist (sparp, 5, SPAR_MACROCALL, t_box_dv_short_string (mname), args, g_ctx, spar_mkid (sparp, "m"));
  return res;
}

int
sparp_namesake_macro_param (sparp_t *sparp, SPART *dm, caddr_t param_name)
{
  int ctr;
  if (NULL == dm)
    {
      dm = sparp->sparp_current_macro;
      if (NULL == dm)
        return -3;
    }
  DO_BOX_FAST_REV (caddr_t, name, ctr, dm->_.defmacro.paramnames)
    {
      if (!strcmp (name, param_name))
        return ctr;
    }
  END_DO_BOX_FAST;
  DO_BOX_FAST_REV (caddr_t, name, ctr, dm->_.defmacro.localnames)
    {
      if (!strcmp (name, param_name))
        return -1;
    }
  END_DO_BOX_FAST;
  return -2;
}

SPART *
spar_make_create_macro_lib (sparp_t *sparp)
{
  SPART *fake_sol;
  SPART *call, *top;
  fake_sol = spar_make_fake_action_solution (sparp);
  call = spar_make_funcall (sparp, 0, t_box_dv_short_string ("sql:RDF_SML_CREATE"),
    (SPART **)t_list (2, sparp->sparp_macrolib_to_create, t_box_dv_short_string (sparp->sparp_text)) );
  top = spar_make_top_or_special_case_from_wm (sparp, SPAR_SML_CREATE,
    (SPART **)t_list (1, call), fake_sol );
  return top;
}

SPART *
spar_make_drop_macro_lib (sparp_t *sparp, SPART *sml_precode, int silent)
{
  SPART *fake_sol;
  SPART *call, *top;
  fake_sol = spar_make_fake_action_solution (sparp);
  call = spar_make_funcall (sparp, 0, t_box_dv_short_string ("sql:RDF_SML_DROP"),
    (SPART **)t_list (2, sml_precode, t_box_num_nonull (silent)) );
  top = spar_make_top_or_special_case_from_wm (sparp, SPAR_SML_DROP,
    (SPART **)t_list (1, call), fake_sol );
  return top;
}

SPART *
spar_make_sparul_mdw (sparp_t *sparp, ptrlong subtype, const char *opname, SPART *graph_precode, SPART *aux_op, int silent)
{
  SPART *fake_sol;
  SPART *call, *top, **options = NULL, *options_vector_call;
  caddr_t log_mode = sparp->sparp_sg->sg_sparul_log_mode;
  fake_sol = spar_make_fake_action_solution (sparp);
  if (NULL == log_mode)
    log_mode = t_NEW_DB_NULL;
  if (LOAD_L == subtype)
    {
      dk_set_t *opts_ptr = &(sparp->sparp_env->spare_src.ssrc_common_sponge_options);
      options = (SPART **)t_full_box_copy_tree ((caddr_t)(t_list_to_array (opts_ptr[0])));
      if (NULL != dk_set_getptr_keyword (opts_ptr[0], "get:destination"))
        spar_error (sparp, "DEFINE get:destination ... is not applicable for SPARUL LOAD statement; use LOAD ... INTO ... form instead");
      if (NULL != dk_set_getptr_keyword (opts_ptr[0], "get:uri"))
        spar_error (sparp, "DEFINE get:uri ... is not applicable for SPARUL LOAD statement; use LOAD ... INTO ... form instead");
    }
  if (NULL == options)
    options_vector_call = (SPART *)t_NEW_DB_NULL;
  else
    options_vector_call = spar_make_funcall (sparp, 0, "bif:vector", options);
  if (NULL != sparp->sparp_sg->sg_output_route_name)
    call = spar_make_funcall (sparp, 0,
      t_box_sprintf (200, "sql:SPARQL_ROUTE_MDW_%.100s", sparp->sparp_sg->sg_output_route_name),
      (SPART **)t_list (13, graph_precode,
          t_box_dv_short_string (opname),
          ((NULL == sparp->sparp_env->spare_storage_name) ? t_NEW_DB_NULL : sparp->sparp_env->spare_storage_name),
          ((NULL == sparp->sparp_sg->sg_output_storage_name) ? t_NEW_DB_NULL : sparp->sparp_sg->sg_output_storage_name),
          ((sparp->sparp_env->spare_disable_output_formatting || (NULL == sparp->sparp_sg->sg_output_format_name)) ? t_NEW_DB_NULL : sparp->sparp_sg->sg_output_format_name),
          aux_op,
          t_NEW_DB_NULL,
          t_NEW_DB_NULL,
          spar_exec_uid_and_gs_cbk (sparp), log_mode, spar_compose_report_flag (sparp), options_vector_call,
          (SPART *)t_box_num_nonull (silent) ) );
  else
    call = spar_make_funcall (sparp, 0, t_box_sprintf (30, "sql:SPARUL_%.30s", opname),
      (SPART **)t_list (7, graph_precode, aux_op,
      spar_exec_uid_and_gs_cbk (sparp), log_mode, spar_compose_report_flag (sparp), options_vector_call,
      (SPART *)t_box_num_nonull (silent) ) );
  top = spar_make_top_or_special_case_from_wm (sparp, subtype,
    (SPART **)t_list (1, call), fake_sol );
  return top;
}

SPART *spar_make_graph_precode_for_clear (sparp_t *sparp, SPART *graph_precode, const char *opname)
{
  int clear_default = 0;
  int clear_named = 0;
  dk_set_t graphs = NULL;
  switch ((ptrlong)graph_precode)
    {
    case DEFAULT_L: clear_default = 1; break;
    case NAMED_L: clear_named = 1; break;
    case ALL_L: clear_default = clear_named = 1; break;
    default: return graph_precode;
    }
  if (clear_default)
    {
      DO_SET (SPART *, src, &(sparp->sparp_env->spare_src.ssrc_default_graphs))
        {
          if (SPART_GRAPH_FROM != src->_.graph.subtype)
            spar_error (sparp, "Graph groups, NOT FROM and its equivalents are not supported for SPARQL %.200s DEFAULT and SPARQL %.200s ALL", opname, opname);
          t_set_push (&graphs, spar_simplify_graph_to_patch (sparp, src));
        }
      END_DO_SET ();
      if (NULL == graphs)
        {
          SPART *fbk_graph = sparp->sparp_env->spare_src.ssrc_fallback_target;
          if (NULL == fbk_graph)
            fbk_graph = sparp->sparp_env->spare_src.ssrc_fallback_default_graph;
          if (NULL != fbk_graph)
            t_set_push (&graphs, spar_simplify_graph_to_patch (sparp, fbk_graph));
        }
      if ((NULL == graphs) && (DEFAULT_L == ((ptrlong)graph_precode)))
        spar_error (sparp, "SPARQL 1.1 CLEAR DEFAULT operator requires declaration of a plain default graph");
    }
  if (clear_named)
    {
      DO_SET (SPART *, src, &(sparp->sparp_env->spare_src.ssrc_named_graphs))
        {
          if (SPART_GRAPH_NAMED != src->_.graph.subtype)
            spar_error (sparp, "Graph groups, NOT FROM NAMED and its equivalents are not supported for SPARQL %.200s NAMED and SPARQL %.200s ALL", opname, opname);
          t_set_push (&graphs, spar_simplify_graph_to_patch (sparp, src));
        }
      END_DO_SET ();
    }
  return spar_make_funcall (sparp, 0, "bif:vector", (SPART **)t_revlist_to_array (graphs));
}

SPART *
spar_make_sparul_clear (sparp_t *sparp, SPART *graph_precode, int silent)
{
  SPART *graph_arg = spar_make_graph_precode_for_clear (sparp, graph_precode, "CLEAR");
  return spar_make_sparul_mdw (sparp, CLEAR_L, "CLEAR", graph_arg, (SPART *)t_box_num_nonull (0) /* i.e. not inside sponge */, silent);
}

SPART *
spar_make_sparul_load (sparp_t *sparp, SPART *graph_precode, SPART *src_precode, int silent)
{
  return spar_make_sparul_mdw (sparp, LOAD_L, "LOAD", graph_precode, src_precode, silent);
}

SPART *
spar_make_sparul_load_service_data (sparp_t *sparp, SPART *proxy_iri_precode, SPART *service_iri_precode, int silent)
{
  return spar_make_sparul_mdw (sparp, LOAD_L, "LOAD_SERVICE_DATA", proxy_iri_precode, service_iri_precode, silent);
}

SPART *
spar_make_sparul_create (sparp_t *sparp, SPART *graph_precode, int silent)
{
  return spar_make_sparul_mdw (sparp, CREATE_L, "CREATE", graph_precode, NULL, silent);
}

SPART *
spar_make_sparul_drop (sparp_t *sparp, SPART *graph_precode, int silent)
{
  SPART *graph_arg = spar_make_graph_precode_for_clear (sparp, graph_precode, "DROP");
  return spar_make_sparul_mdw (sparp, DROP_L, "DROP", graph_arg, NULL, silent);
}

SPART *
spar_make_sparul_copymoveadd (sparp_t *sparp, ptrlong opcode, SPART *from_graph_precode, SPART *to_graph_precode, int silent)
{
  const char *opname = NULL;
  switch (opcode)
    {
    case COPY_L: opname = "COPY"; break;
    case MOVE_L: opname = "MOVE"; break;
    case ADD_L: opname = "ADD"; break;
    default: GPF_T;
    }
  if ((DEFAULT_L == (ptrlong)(from_graph_precode)) || (DEFAULT_L == (ptrlong)(to_graph_precode)))
    {
      SPART *single_default = NULL;
      dk_set_t graphs = sparp->sparp_env->spare_src.ssrc_default_graphs;
      if ((NULL == graphs) || (SPART_GRAPH_FROM != ((SPART *)(graphs->data))->_.graph.subtype))
        {
          SPART *fbk_graph = NULL;
          if (DEFAULT_L == (ptrlong)(to_graph_precode))
            fbk_graph = sparp->sparp_env->spare_src.ssrc_fallback_target;
          if (NULL == fbk_graph)
            fbk_graph = sparp->sparp_env->spare_src.ssrc_fallback_default_graph;
          if (NULL == fbk_graph)
            spar_error (sparp, "SPARQL 1.1 %s...DEFAULT operator requires declaration of a plain default graph", opname);
          single_default = sparp_tree_full_copy (sparp, (SPART *)(fbk_graph), NULL);
        }
      else
        {
          if ((NULL != graphs->next) && (SPART_GRAPH_MIN_NEGATION <= ((SPART *)(graphs->next->data))->_.graph.subtype))
            spar_error (sparp, "SPARQL 1.1 %s...DEFAULT operator requires exactly one default graph", opname);
          single_default = spar_simplify_graph_to_patch (sparp, (SPART *)(graphs->data));
        }
      if (DEFAULT_L == (ptrlong)(from_graph_precode))
        from_graph_precode = single_default;
      if (DEFAULT_L == (ptrlong)(to_graph_precode))
        to_graph_precode = single_default;
    }
  return spar_make_sparul_mdw (sparp, DROP_L, opname, from_graph_precode, to_graph_precode, silent);
}

SPART *
spar_make_topmost_sparul_sql (sparp_t *sparp, SPART **actions)
{
  caddr_t saved_format_name = sparp->sparp_sg->sg_output_format_name;
  caddr_t saved_valmode_name = sparp->sparp_sg->sg_output_valmode_name;
  SPART *fake_sol;
  SPART *top;
  SPART **action_sqls;
  caddr_t volatile err = NULL;
  int action_ctr, action_count = BOX_ELEMENTS (actions);
  if ((1 == action_count) && unbox (spar_compose_report_flag (sparp)))
    return actions[0]; /* No need to make grouping around single action. */
/* First of all, every tree for every action is compiled into string literal containing SQL text. */
  action_sqls = (SPART **)t_alloc_box (action_count * sizeof (SPART *), DV_ARRAY_OF_POINTER);
  sparp->sparp_sg->sg_output_format_name = NULL;
  sparp->sparp_sg->sg_output_valmode_name = NULL;
  if (NULL != sparp->sparp_entire_query)
    spar_internal_error (sparp, "spar_" "make_topmost_sparul_sql() is called after start of some tree rewrite");
  DO_BOX_FAST (SPART *, action, action_ctr, actions)
    {
      spar_sqlgen_t ssg;
      sql_comp_t sc;
      caddr_t action_sql;
      sparp->sparp_entire_query = action = sparp_rewrite_all (sparp, action, 0 /* no cloning -- no need in safely_copy_retvals */);
#ifndef NDEBUG
      t_check_tree (action);
#endif
      memset (&ssg, 0, sizeof (spar_sqlgen_t));
      memset (&sc, 0, sizeof (sql_comp_t));
      if (CALLER_LOCAL != sparp->sparp_sparqre->sparqre_qi)
        sc.sc_client = sparp->sparp_sparqre->sparqre_qi->qi_client;
      ssg.ssg_out = strses_allocate ();
      ssg.ssg_sc = &sc;
      ssg.ssg_sparp = sparp;
      ssg.ssg_tree = action;
      ssg.ssg_sources = ssg.ssg_tree->_.req_top.sources; /*!!!TBD merge with environment */
      ssg.ssg_comment_sql = sparp->sparp_sg->sg_comment_sql;
      QR_RESET_CTX
        {
          ssg_make_sql_query_text (&ssg, 0);
        }
      QR_RESET_CODE
        {
          du_thread_t * self = THREAD_CURRENT_THREAD;
          err = thr_get_error_code (self);
          ssg_free_internals (&ssg);
          POP_QR_RESET;
          sqlr_resignal (err);
        }
      END_QR_RESET;
      action_sql = t_strses_string (ssg.ssg_out);
      ssg_free_internals (&ssg);
      action_sqls [action_ctr] = spartlist (sparp, 5, SPAR_LIT, action_sql, NULL, NULL, NULL);
      sparp->sparp_entire_query = NULL;
    }
  END_DO_BOX_FAST;
  sparp->sparp_sg->sg_output_format_name = saved_format_name;
  sparp->sparp_sg->sg_output_valmode_name = saved_valmode_name;
  fake_sol = spar_make_fake_action_solution (sparp);
  top = spar_make_top_or_special_case_from_wm (sparp, SPARUL_RUN_SUBTYPE,
    (SPART **)t_list (1, spar_make_funcall (sparp, 0, "sql:SPARUL_RUN", action_sqls)), fake_sol );
  return top;
}


SPART *
spar_make_fake_action_solution (sparp_t *sparp)
{
  SPART * fake_gp;
/* The need for fake action solution means no USING and WHERE clauses, hence the code that would be otherwise called at the very beginning of WHERE clause */
  if (NULL != sparp->sparp_env->spare_need_for_default_sparul_target)
    sparp->sparp_env->spare_found_default_sparul_target = spar_default_sparul_target (sparp, sparp->sparp_env->spare_need_for_default_sparul_target, 0);
/* Now the fake gp of subtype WHERE_L */
  spar_gp_init (sparp, WHERE_L);
  fake_gp = spar_gp_finalize (sparp, NULL);
  return spartlist (sparp, 8, SPAR_WHERE_MODIFS,
    fake_gp, NULL, NULL, NULL, t_box_num(1), t_box_num(0), NULL );
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
  return strcmp ((NULL != v1->_.var.tabid) ? v1->_.var.tabid : "", (NULL != v2->_.var.tabid) ? v2->_.var.tabid : "");
}

caddr_t
spar_boxed_exec_uid (sparp_t *sparp)
{
  if (NULL == sparp->sparp_boxed_exec_uid)
    {
      user_t *exec_user = sparp->sparp_sparqre->sparqre_exec_user;
      if (NULL != exec_user)
        sparp->sparp_boxed_exec_uid = t_box_num_nonull (exec_user->usr_id);
      else if (sparp->sparp_sparqre->sparqre_cli == bootstrap_cli)
        sparp->sparp_boxed_exec_uid = t_box_num_nonull (U_ID_DBA);
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
      else if (sparp->sparp_sparqre->sparqre_cli == bootstrap_cli)
        sparp->sparp_immortal_exec_uname = box_dv_uname_string ("dba");
      else
        sparp->sparp_immortal_exec_uname = box_dv_uname_string ("nobody");
      box_dv_uname_make_immortal (sparp->sparp_immortal_exec_uname);
    }
  return sparp->sparp_immortal_exec_uname;
}

SPART *
spar_exec_uid_and_gs_cbk (sparp_t *sparp)
{
  caddr_t uid = spar_boxed_exec_uid (sparp);
  caddr_t appid = ((NULL == sparp->sparp_gs_app_uid) ? t_NEW_DB_NULL : sparp->sparp_gs_app_uid);
  if (NULL == sparp->sparp_gs_app_callback)
    return (SPART *)uid;
  return spar_make_funcall (sparp, 0, "bif:vector",
    (SPART **)t_list (3, uid, sparp->sparp_gs_app_callback, appid) );
}

void
spar_qr_uses_jso_int (comp_context_t *cc, ccaddr_t jso_inst, ccaddr_t jso_name)
{
  if (NULL == cc)
    return;
  if (NULL == jso_name)
    {
      jso_rtti_t *jso_rtti = gethash (jso_inst, jso_rttis_of_structs);
      if (NULL == jso_rtti)
        return; /* Built-in anonymous JSO, like one used when define input:storage "" */
      jso_name = jso_rtti->jrtti_inst_iri;
    }
  box_dv_uname_make_immortal ((caddr_t)jso_name);
  qr_uses_jso (cc->cc_super_cc->cc_query, jso_name);
}

int
spar_graph_static_perms (sparp_t *sparp, caddr_t graph_iri, int req_perms)
{
  caddr_t boxed_uid;
  id_hash_t *dflt_perms_of_user = rdf_graph_default_world_perms_of_user_dict_htable;
  id_hash_t *dflt_other_perms_of_user = rdf_graph_default_private_perms_of_user_dict_htable;
  caddr_t *hit = NULL, *potential_hit;
  int res = 0, potential_res = 0, potential_res_is_user_specific = 0;
  int graph_is_private = 0;
  query_t *query_with_deps = NULL;
static caddr_t boxed_zero_iid = NULL;
static caddr_t boxed_8192_iid = NULL;
  if (NULL == boxed_zero_iid)
    boxed_zero_iid = box_iri_id (0);
  if (NULL == boxed_8192_iid)
    boxed_8192_iid = box_iri_id (8192);
  if (NULL == sparp->sparp_gs_app_callback)
    boxed_uid = spar_boxed_exec_uid (sparp);
  else
    boxed_uid = t_box_num (U_ID_NOBODY);
  if (NULL != sparp->sparp_sparqre->sparqre_super_sc)
    query_with_deps = sparp->sparp_sparqre->sparqre_super_sc->sc_cc->cc_super_cc->cc_query;
  if (NULL != graph_iri)
    {
      caddr_t boxed_graph_iid = sparp_graph_sec_iri_to_id_nosignal (sparp, graph_iri);
      if (NULL != boxed_graph_iid)
        {
          rwlock_rdlock (rdf_graph_group_of_privates_dict_htable->ht_rwlock);
          if (NULL != id_hash_get (rdf_graph_group_of_privates_dict_htable, (caddr_t)(&(boxed_graph_iid))))
            {
              graph_is_private = 1;
              dflt_perms_of_user = rdf_graph_default_private_perms_of_user_dict_htable;
              dflt_other_perms_of_user = rdf_graph_default_world_perms_of_user_dict_htable;
            }
          rwlock_unlock (rdf_graph_group_of_privates_dict_htable->ht_rwlock);
/*!!! maybe TBD: add retrieval of permissions of specific user on specific graph */
          rwlock_rdlock (dflt_perms_of_user->ht_rwlock);
          hit = (caddr_t *)id_hash_get (dflt_perms_of_user, (caddr_t)(&(boxed_uid /* not boxed_graph_iid */)));
          rwlock_unlock (dflt_perms_of_user->ht_rwlock);
          dk_free_tree (boxed_graph_iid);
        }
      if (NULL != hit)
        {
          if (NULL != query_with_deps)
            {
              caddr_t graph_uname = box_dv_uname_nchars (graph_iri, box_length (graph_iri) - 1);
              qr_uses_jso (query_with_deps, graph_uname);
            }
          return unbox (hit[0]);
        }
    }
  rwlock_rdlock (dflt_perms_of_user->ht_rwlock);
  hit = (caddr_t *)id_hash_get (dflt_perms_of_user, (caddr_t)(&(boxed_uid)));
  rwlock_unlock (dflt_perms_of_user->ht_rwlock);
  if ((NULL != query_with_deps) || (NULL == graph_iri))
    {
      potential_hit = (caddr_t *)id_hash_get (dflt_other_perms_of_user, (caddr_t)(&(boxed_uid)));
      if (NULL == potential_hit)
        potential_hit = (caddr_t *)id_hash_get (rdf_graph_public_perms_dict_htable, (caddr_t)(graph_is_private ? &boxed_zero_iid : &boxed_8192_iid));
      else
        potential_res_is_user_specific = 1;
      potential_res = (NULL != potential_hit) ? unbox(potential_hit[0]) : RDF_GRAPH_PERM_DEFAULT;
    }
  if (NULL != hit)
    {
      res = unbox (hit[0]);
      if (NULL != query_with_deps)
        {
          caddr_t uname = spar_immortal_exec_uname (sparp);
          qr_uses_jso (query_with_deps, uname);
          if ((0 != ((res & req_perms) & ~(potential_res & req_perms)))) /* If world and private perms differ significantly and in unsafe direction... */
            {
              caddr_t dep_graph_uname = (NULL != graph_iri) ? box_dv_uname_string (graph_iri) : uname_virtrdf_ns_uri_PrivateGraphs;
              qr_uses_jso (query_with_deps, dep_graph_uname); /* ...then adding dep on graph is required, so changing graph from world to provate or back will trigger re-compilation */
            }
        }
      if (NULL != graph_iri)
        return res;
      return res & potential_res;
    }
  rwlock_rdlock (rdf_graph_public_perms_dict_htable->ht_rwlock);
  hit = (caddr_t *)id_hash_get (rdf_graph_public_perms_dict_htable, (caddr_t)(graph_is_private ? &boxed_8192_iid : &boxed_zero_iid));
  rwlock_unlock (rdf_graph_public_perms_dict_htable->ht_rwlock);
  if (NULL != hit)
    res = unbox (hit[0]);
  else res = RDF_GRAPH_PERM_DEFAULT;
  if (NULL != query_with_deps)
    {
      if ((0 != ((res & req_perms) & ~(potential_res & req_perms)))) /* If world and private perms differ significantly and in unsafe direction... */
        {
          caddr_t dep_graph_uname;
          if (potential_res_is_user_specific)
            {
              caddr_t uname = spar_immortal_exec_uname (sparp);
              qr_uses_jso (query_with_deps, uname);
            }
          dep_graph_uname = (NULL != graph_iri) ? box_dv_uname_string (graph_iri) : uname_virtrdf_ns_uri_PrivateGraphs;
          qr_uses_jso (query_with_deps, dep_graph_uname); /* ...then adding dep on graph is required, so changing graph from world to provate or back will trigger re-compilation */
        }
    }
  if (NULL != graph_iri)
    return res;
  return res & potential_res;
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
    default_perms = spar_graph_static_perms (sparp, fixed_g, req_perms);
  else
    default_perms = spar_graph_static_perms (sparp, NULL, req_perms);
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
      sparp->sparp_permitted_syntax = ~0;
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
sparp_query_parse (const char * str, spar_query_env_t *sparqre, int rewrite_all)
{
  wcharset_t *query_charset = sparqre->sparqre_query_charset;
  t_NEW_VAR (sparp_t, sparp);
  t_NEW_VAR (sparp_e4qm_t, e4qm);
  t_NEW_VARZ (sparp_env_t, spare);
#ifdef DEBUG
  dbg_curr_sparp = sparp;
#endif
  sparqre->sparqre_dbg_query_text = str;
  sparqre->sparqre_dbg_sparp = sparp;
  memset (sparp, 0, sizeof (sparp_t));
  sparp->sparp_sparqre = sparqre;
  if ((NULL == sparqre->sparqre_cli) && (CALLER_LOCAL != sparqre->sparqre_qi))
    sparqre->sparqre_cli = sparqre->sparqre_qi->qi_client;
  if ((NULL == sparqre->sparqre_exec_user) && (NULL != sparqre->sparqre_cli))
    sparqre->sparqre_exec_user = sparqre->sparqre_cli->cli_user;
  sparp->sparp_env = spare;
  memset (e4qm, 0, sizeof (sparp_e4qm_t));
  sparp->sparp_e4qm = e4qm;
  sparp->sparp_permitted_syntax = ~0;
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
  sparp->sparp_sg = (sparp_globals_t *) t_alloc (sizeof (sparp_globals_t));
  memset (sparp->sparp_sg, 0, sizeof (sparp_globals_t));
#ifndef NDEBUG
  sparp->sparp_sg->sg_comment_sql = 1;
#endif
  sparp->sparp_sg->sg_ebv_mode = 1;
  QR_RESET_CTX
    {
      /* Bug 4566: sparpyyrestart (NULL); */
      sparyyparse (sparp);
      if (rewrite_all)
        sparp->sparp_entire_query = sparp_rewrite_all (sparp, sparp->sparp_entire_query, 0 /* top is never cloned, hence zero safely_copy_retvals */);
        
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
  if (NULL != sparp->sparp_macrolib_to_create && !sparp->sparp_macrolib_ignore_create)
    sparp->sparp_entire_query = spar_make_create_macro_lib (sparp);
#if 0
  t_check_tree (sparp->sparp_entire_query);
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
sparp_clone_for_variant (sparp_t *sparp)
{
  s_node_t *iter;
  sparp_env_t *env = sparp->sparp_env;
  t_NEW_VAR (sparp_t, sparp_copy);
  t_NEW_VARZ (sparp_env_t, env_copy);
  memcpy (sparp_copy, sparp, sizeof (sparp_t));
  sparp_copy->sparp_env = env_copy;
  ENV_BOX_COPY (spare_storage_name);
  ENV_COPY(spare_parent_env);
#if 0 /* These will be used when libraries of inference rules are introduced. */
    id_hash_t *		spare_fundefs;			/*!< In-scope function definitions */
    id_hash_t *		spare_vars;			/*!< Known variables as keys, equivs as values */
    id_hash_t *		spare_global_bindings;		/*!< Dictionary of global bindings, varnames as keys, default value expns as values. DV_DB_NULL box for no expn! */
#endif
  /* No copy for spare_src.ssrc_grab_vars */
  ENV_SET_COPY (spare_src.ssrc_common_sponge_options);
  ENV_SET_COPY (spare_src.ssrc_default_graphs);
  ENV_SET_COPY (spare_src.ssrc_named_graphs);
  ENV_COPY (spare_src.ssrc_default_graphs_listed);
  ENV_COPY (spare_src.ssrc_named_graphs_listed);
  ENV_COPY (spare_src.ssrc_freeze_status);
  ENV_COPY (spare_src.ssrc_frozen_pragma_example);
  ENV_SET_COPY (spare_common_sql_table_options);
  ENV_SET_COPY (spare_sql_select_options);
  ENV_SET_COPY (spare_global_var_names);
  return sparp_copy;
}

void
spar_env_push (sparp_t *sparp)
{
  s_node_t *iter;
  sparp_env_t *env = sparp->sparp_env;
  t_NEW_VARZ (sparp_env_t, env_copy);
  ENV_COPY (spare_start_lineno);
  ENV_COPY (spare_param_counter_ptr);
  ENV_COPY (spare_namespace_prefixes);
  ENV_COPY (spare_namespace_prefixes_outer);
  ENV_COPY (spare_base_uri);
  ENV_COPY (spare_storage_name);
  ENV_COPY (spare_inference_name);
  ENV_COPY (spare_inference_ctx);
  ENV_COPY (spare_use_same_as);
#if 0 /* These will be used when libraries of inference rules are introduced. Don't forget to patch sparp_clone_for_variant()! */
    id_hash_t *		spare_fundefs;			/*!< In-scope function definitions */
    id_hash_t *		spare_vars;			/*!< Known variables as keys, equivs as values */
    id_hash_t *		spare_global_bindings;		/*!< Dictionary of global bindings, varnames as keys, default value expns as values. DV_DB_NULL box for no expn! */
#endif
  ENV_COPY (spare_src.ssrc_grab);
  ENV_SET_COPY (spare_src.ssrc_common_sponge_options);
  ENV_SET_COPY (spare_src.ssrc_default_graphs);
  ENV_SET_COPY (spare_src.ssrc_named_graphs);
  ENV_COPY (spare_src.ssrc_default_graphs_listed);
  ENV_COPY (spare_src.ssrc_named_graphs_listed);
  ENV_COPY (spare_src.ssrc_freeze_status);
  ENV_COPY (spare_src.ssrc_frozen_pragma_example);
  ENV_COPY (spare_common_sql_table_options);
  /* no copy for spare_groupings */
  ENV_COPY (spare_sql_select_options);
  ENV_COPY (spare_context_sinvs);
  ENV_COPY (spare_context_qms);
#if 0 /* This check is replaced with check for context qms if define input:storage appear */
  if ((NULL != env_copy->spare_context_qms) && ((SPART *)((ptrlong)_STAR) != env_copy->spare_context_qms->data))
    spar_error (sparp, "Subqueries are not allowed inside QUAD MAP group patterns other than 'QUAD MAP * {...}'");
#endif
  ENV_COPY (spare_context_graphs);
  /* no copy for spare_context_subjects */
  /* no copy for spare_context_predicates */
  /* no copy for spare_context_objects */
  /* no copy for spare_context_gp_subtypes */
  /* no copy for spare_acc_triples */
  /* no copy for spare_acc_movable_filters */
  /* no copy for spare_acc_local_filters */
  ENV_COPY (spare_good_graph_varnames);
  ENV_COPY (spare_good_graph_varname_sets);
  ENV_COPY (spare_good_graph_bmk);
  ENV_COPY (spare_global_var_names);
  /* no copy for spare_disable_output_formatting */
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
  SPARP_SAVED_MP_SIZE_CAP;
  caddr_t str = t_strses_string (sparqre->sparqre_src->sif_skipped_part);
  caddr_t res;
#ifdef SPARQL_DEBUG
  printf ("\nsparp_compile_subselect() input:\n%s\n", str);
#endif
  strses_free (sparqre->sparqre_src->sif_skipped_part);
  sparqre->sparqre_src->sif_skipped_part = NULL;
  sparqre->sparqre_cli = sqlc_client();
  sparqre->sparqre_exec_user = sparqre->sparqre_cli->cli_user;
  SPARP_TWEAK_MP_SIZE_CAP(THR_TMP_POOL,sparqre);
  sparp = sparp_query_parse (str, sparqre, 1);
  if (NULL != sparp->sparp_sparqre->sparqre_catched_error)
    {
#ifdef SPARQL_DEBUG
      printf ("\nsparp_compile_subselect() caught parse error: %s\n", ERR_MESSAGE(sparp->sparp_sparqre->sparqre_catched_error));
#endif
      if (NULL != sparqre->sparqre_metadata_rwlock)
        {
          rwlock_unlock (sparqre->sparqre_metadata_rwlock);
          sparqre->sparqre_metadata_rwlock = NULL;
        }
      SPARP_RESTORE_MP_SIZE_CAP(THR_TMP_POOL);
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
  ssg.ssg_tree = sparp->sparp_entire_query;
      ssg.ssg_comment_sql = sparp->sparp_sg->sg_comment_sql;
  ssg_make_whole_sql_text (&ssg);
  if (NULL != sparqre->sparqre_metadata_rwlock)
    {
      rwlock_unlock (sparqre->sparqre_metadata_rwlock);
      sparqre->sparqre_metadata_rwlock = NULL;
    }
  if (NULL != sparqre->sparqre_catched_error)
    {
      SPARP_RESTORE_MP_SIZE_CAP(THR_TMP_POOL);
      ssg_free_internals (&ssg);
      return;
    }
  session_buffered_write (ssg.ssg_out, sparqre->sparqre_tail_sql_text, strlen (sparqre->sparqre_tail_sql_text));
  session_buffered_write_char (0 /*YY_END_OF_BUFFER_CHAR*/, ssg.ssg_out); /* First terminator */
  session_buffered_write_char (0 /*YY_END_OF_BUFFER_CHAR*/, ssg.ssg_out); /* Second terminator. Most of Lex-es need two! */
  res = t_strses_string (ssg.ssg_out);
#ifdef SPARQL_DEBUG
  printf ("\nsparp_compile_subselect() done:\n%s\n", res);
#endif
  SPARP_RESTORE_MP_SIZE_CAP(THR_TMP_POOL);
  ssg_free_internals (&ssg);
  sparqre->sparqre_compiled_text = res;
}


caddr_t
bif_sparql_explain (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  int ctr, param_ctr = 0;
  spar_query_env_t sparqre;
  sparp_t * sparp;
  caddr_t str = bif_string_arg (qst, args, 0, "sparql_explain");
  int rewrite_all = (0 != ((2 > BOX_ELEMENTS (args)) ? 1 : bif_long_arg (qst, args, 1, "sparql_explain")));
  dk_session_t *res;
  SPARP_SAVED_MP_SIZE_CAP;
  MP_START ();
  SPARP_TWEAK_MP_SIZE_CAP(THR_TMP_POOL,&sparqre);
  memset (&sparqre, 0, sizeof (spar_query_env_t));
  sparqre.sparqre_param_ctr = &param_ctr;
  sparqre.sparqre_qi = (query_instance_t *) qst;
  sparp = sparp_query_parse (str, &sparqre, rewrite_all);
  if (NULL != sparqre.sparqre_catched_error)
    {
      if (NULL != sparqre.sparqre_metadata_rwlock)
        {
          rwlock_unlock (sparqre.sparqre_metadata_rwlock);
          sparqre.sparqre_metadata_rwlock = NULL;
        }
      SPARP_RESTORE_MP_SIZE_CAP(THR_TMP_POOL);
      MP_DONE ();
      sqlr_resignal (sparqre.sparqre_catched_error);
    }
  res = strses_allocate ();
  for (ctr = 0; ctr < sparp->sparp_macro_def_count; ctr++)
    {
      SPART *defm = sparp->sparp_macro_defs[ctr];
      spart_dump (defm, res, 0, "MACRO DEFINITION", -1);
    }
  spart_dump (sparp->sparp_entire_query, res, 0, "QUERY", -1);
#if 1
  {
    int eq_ctr, eq_count;
    SES_PRINT (res, "\nEQUIVS:");
    eq_count = sparp->sparp_sg->sg_equiv_count;
    for (eq_ctr = 0; eq_ctr < eq_count; eq_ctr++)
      {
        char buf[50];
        sparp_equiv_t *eq;
        eq = sparp->sparp_sg->sg_equivs[eq_ctr];
        if (NULL == eq)
          {
#ifdef SPARQL_DEBUG
            eq = sparp->sparp_sg->sg_removed_equivs[eq_ctr];
            sprintf (buf, "\n#%d: merged into #%d and destroyed", eq_ctr, (int)(eq->e_dbg_merge_dest));
            SES_PRINT (res, buf);
            spart_dump_eq (eq, res);
#else
            sprintf (buf, "\n#%d: merged and destroyed", eq_ctr);
            SES_PRINT (res, buf);
#endif
          }
        else
          {
            sprintf (buf, "\n#%d:", eq_ctr);
            SES_PRINT (res, buf);
            spart_dump_eq (eq, res);
          }
      }
  }
#endif
  if (NULL != sparqre.sparqre_metadata_rwlock)
    {
      rwlock_unlock (sparqre.sparqre_metadata_rwlock);
      sparqre.sparqre_metadata_rwlock = NULL;
    }
  SPARP_RESTORE_MP_SIZE_CAP(THR_TMP_POOL);
  MP_DONE ();
  return (caddr_t)res;
}

void sparp_make_sparqld_text (spar_sqlgen_t *ssg);

caddr_t
bif_sparql_detalize (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  int param_ctr = 0, sd_flags, sd_no;
  spar_query_env_t sparqre;
  sparp_t * sparp;
  caddr_t str;
  spar_sqlgen_t ssg;
  sql_comp_t sc;
  dk_session_t *res;
  SPARP_SAVED_MP_SIZE_CAP;
  str = bif_string_arg (qst, args, 0, "sparql_detalize");
  sd_flags = ((2 <= BOX_ELEMENTS (args)) ? bif_long_arg (qst, args, 1, "sparql_detalize") : SSG_SD_VOS_CURRENT);
  sd_no = ((3 <= BOX_ELEMENTS (args)) ? bif_long_arg (qst, args, 2, "sparql_detalize") : 0);
  MP_START ();
  memset (&sparqre, 0, sizeof (spar_query_env_t));
  sparqre.sparqre_param_ctr = &param_ctr;
  sparqre.sparqre_qi = (query_instance_t *) qst;
  SPARP_TWEAK_MP_SIZE_CAP(THR_TMP_POOL,&sparqre);
  sparp = sparp_query_parse (str, &sparqre, 1);
  if (NULL != sparqre.sparqre_catched_error)
    {
      if (NULL != sparqre.sparqre_metadata_rwlock)
        {
          rwlock_unlock (sparqre.sparqre_metadata_rwlock);
          sparqre.sparqre_metadata_rwlock = NULL;
        }
      SPARP_RESTORE_MP_SIZE_CAP(THR_TMP_POOL);
      MP_DONE ();
      sqlr_resignal (sparqre.sparqre_catched_error);
    }
  memset (&ssg, 0, sizeof (spar_sqlgen_t));
  memset (&sc, 0, sizeof (sql_comp_t));
  sc.sc_client = sparqre.sparqre_qi->qi_client;
  ssg.ssg_out = strses_allocate ();
  ssg.ssg_sc = &sc;
  ssg.ssg_sparp = sparp;
  ssg.ssg_tree = sparp->sparp_entire_query;
  ssg.ssg_sd_flags = sd_flags;
  ssg.ssg_sd_no = sd_no;
  ssg.ssg_sd_used_namespaces = id_str_hash_create (16);
  ssg.ssg_comment_sql = sparp->sparp_sg->sg_comment_sql;
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
  if (NULL != sparqre.sparqre_metadata_rwlock)
    {
      rwlock_unlock (sparqre.sparqre_metadata_rwlock);
      sparqre.sparqre_metadata_rwlock = NULL;
    }
  if (NULL != sparqre.sparqre_catched_error)
    {
      SPARP_RESTORE_MP_SIZE_CAP(THR_TMP_POOL);
      ssg_free_internals (&ssg);
      MP_DONE ();
      sqlr_resignal (sparqre.sparqre_catched_error);
    }
  res = ssg.ssg_out;
  ssg.ssg_out = NULL;
  SPARP_RESTORE_MP_SIZE_CAP(THR_TMP_POOL);
  ssg_free_internals (&ssg);
  MP_DONE ();
  return (caddr_t)(res);
}

caddr_t
bif_sparql_to_sql_text (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  int param_ctr = 0;
  spar_query_env_t sparqre;
  sparp_t * sparp;
  caddr_t str, uname = NULL;
  spar_sqlgen_t ssg;
  sql_comp_t sc;
  dk_session_t *res;
  SPARP_SAVED_MP_SIZE_CAP;
  str = bif_string_arg (qst, args, 0, "sparql_to_sql_text");
  if (1 < BOX_ELEMENTS (args))
    uname = bif_string_arg (qst, args, 1, "sparql_to_sql_text"); /* set before MP_START () for case of argument of wrong type causing signal w/o MP_DONE() */
  MP_START ();
  memset (&sparqre, 0, sizeof (spar_query_env_t));
  sparqre.sparqre_param_ctr = &param_ctr;
  sparqre.sparqre_qi = (query_instance_t *) qst;
  SPARP_TWEAK_MP_SIZE_CAP(THR_TMP_POOL,&sparqre);
  if (NULL != uname)
    sparqre.sparqre_exec_user = sec_name_to_user (uname);
  sparp = sparp_query_parse (str, &sparqre, 1);
  if (NULL != sparqre.sparqre_catched_error)
    {
      if (NULL != sparqre.sparqre_metadata_rwlock)
        {
          rwlock_unlock (sparqre.sparqre_metadata_rwlock);
          sparqre.sparqre_metadata_rwlock = NULL;
        }
      SPARP_RESTORE_MP_SIZE_CAP(THR_TMP_POOL);
      MP_DONE ();
      sqlr_resignal (sparqre.sparqre_catched_error);
    }
  memset (&ssg, 0, sizeof (spar_sqlgen_t));
  memset (&sc, 0, sizeof (sql_comp_t));
  sc.sc_client = sparqre.sparqre_qi->qi_client;
  ssg.ssg_out = strses_allocate ();
  ssg.ssg_sc = &sc;
  ssg.ssg_sparp = sparp;
  ssg.ssg_tree = sparp->sparp_entire_query;
  ssg.ssg_comment_sql = sparp->sparp_sg->sg_comment_sql;
  ssg_make_whole_sql_text (&ssg);
  if (NULL != sparqre.sparqre_metadata_rwlock)
    {
      rwlock_unlock (sparqre.sparqre_metadata_rwlock);
      sparqre.sparqre_metadata_rwlock = NULL;
    }
  if (NULL != sparqre.sparqre_catched_error)
    {
      SPARP_RESTORE_MP_SIZE_CAP(THR_TMP_POOL);
      ssg_free_internals (&ssg);
      MP_DONE ();
      sqlr_resignal (sparqre.sparqre_catched_error);
    }
  res = ssg.ssg_out;
  ssg.ssg_out = NULL;
  SPARP_RESTORE_MP_SIZE_CAP(THR_TMP_POOL);
  ssg_free_internals (&ssg);
  MP_DONE ();
  return (caddr_t)(res);
}

caddr_t
bif_sparql_lex_analyze (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t str = bif_string_arg (qst, args, 0, "sparql_lex_analyze");
  return spar_query_lex_analyze (str, QST_CHARSET(qst));
}

#define SPAR_ML_SAFEST			0
#define SPAR_ML_MAKE_BNODE_IF_NULL	1
#define SPAR_ML_MAKE_VAR_IF_NULL	2
#define SPAR_ML_RESULT_FROM_SANDBOX	3

SPART *
spar_make_literal_from_sql_box (sparp_t * sparp, caddr_t box, int mode)
{
  switch (DV_TYPE_OF (box))
    {
    case DV_LONG_INT: return SPAR_MAKE_INT_LITERAL (sparp, unbox (box));
    case DV_NUMERIC: return spartlist (sparp, 5, SPAR_LIT, t_box_copy (box), uname_xmlschema_ns_uri_hash_decimal, NULL, NULL);
    case DV_DOUBLE_FLOAT: return spartlist (sparp, 5, SPAR_LIT, t_box_copy (box), uname_xmlschema_ns_uri_hash_double, NULL, NULL);
    case DV_UNAME: return spartlist (sparp, 2, SPAR_QNAME, t_box_copy (box));
    case DV_IRI_ID:
      {
        iri_id_t iid = unbox_iri_id (box);
        caddr_t iri;
        SPART *res;
        if (0L == iid)
          return NULL;
        if ((iid >= min_bnode_iri_id ()) && (iid < min_named_bnode_iri_id ()))
          {
            caddr_t t_iri;
            if (iid >= MIN_64BIT_BNODE_IRI_ID)
              t_iri = t_box_sprintf (31, "nodeID://b" IIDBOXINT_FMT, (boxint)(iid-MIN_64BIT_BNODE_IRI_ID));
            else
              t_iri = t_box_sprintf (30, "nodeID://" IIDBOXINT_FMT, (boxint)(iid));
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
        return spartlist (sparp, 5, SPAR_LIT, t_box_copy (box), NULL, NULL, NULL);
      }
    case DV_STRING:
      if (BF_IRI & box_flags (box))
        {
          if (SPAR_ML_RESULT_FROM_SANDBOX == mode)
            return spartlist (sparp, 2, SPAR_QNAME, t_box_copy (box));
          spar_internal_error (sparp, "spar_" "make_literal_from_sql_box(): a string has BF_IRI");
        }
      return spartlist (sparp, 5, SPAR_LIT, t_box_copy (box), NULL, NULL, NULL);
    case DV_DB_NULL:
      switch (mode)
        {
        case SPAR_ML_MAKE_BNODE_IF_NULL: return spar_make_blank_node (sparp, spar_mkid (sparp, "_:sqlbox"), 1);
        case SPAR_ML_MAKE_VAR_IF_NULL: return spar_make_variable (sparp, t_box_dv_uname_string ("_:sqlbox"));
        case SPAR_ML_RESULT_FROM_SANDBOX: return NULL;
        }
      break;
    default:
      if (SPAR_ML_RESULT_FROM_SANDBOX == mode)
        return NULL;
      spar_internal_error (sparp, "spar_" "make_literal_from_sql_box(): unsupported box type");
  }
  return NULL; /* to keep compiler happy */
}

SPART *
spar_make_qname_or_literal_from_rvr (sparp_t * sparp, rdf_val_range_t *rvr, int make_naked_box_if_possible)
{
  if (!(rvr->rvrRestrictions & SPART_VARR_FIXED) || !(rvr->rvrRestrictions & (SPART_VARR_IS_LIT | SPART_VARR_IS_REF)))
    spar_internal_error (sparp, "spar_" "make_qname_or_literal_from_rvr(): the rvr does not contain enough restrictions");
  if (rvr->rvrRestrictions & SPART_VARR_IS_REF)
    {
      if (!(rvr->rvrRestrictions & SPART_VARR_IS_IRI))
        spar_internal_error (sparp, "spar_" "make_qname_or_literal_from_rvr(): the SPART_VARR_IS_REF rvr is not SPART_VARR_IS_IRI");
      if (make_naked_box_if_possible)
        return (SPART *)t_box_copy ((caddr_t)(rvr->rvrFixedValue));
      return spartlist (sparp, 2, SPAR_QNAME, t_box_copy ((caddr_t)(rvr->rvrFixedValue)));
    }
  if (make_naked_box_if_possible && !(rvr->rvrRestrictions & SPART_VARR_TYPED) && (NULL == rvr->rvrFixedValue))
    return (SPART *)t_box_copy ((caddr_t)(rvr->rvrFixedValue));
  return spartlist (sparp, 5, SPAR_LIT, t_box_copy ((caddr_t)(rvr->rvrFixedValue)), t_box_copy ((caddr_t)(rvr->rvrDatatype)), t_box_copy ((caddr_t)(rvr->rvrLanguage)), NULL);
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
  sparp_globals_t sparp_globals;
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
  memset (&sparp_globals, 0, sizeof (sparp_globals_t));
#ifndef NDEBUG
  sparp_globals.sg_comment_sql = 1;
#endif
  sparp_globals.sg_ebv_mode = 1;
  sparqre.sparqre_param_ctr = &param_ctr_for_sparqre;
  sparqre.sparqre_qi = (query_instance_t *) qst;
  sparp.sparp_sparqre = &sparqre;
  sparp.sparp_permitted_syntax = ~0;
  sparp.sparp_env = &spare;
  sparp.sparp_sg = &sparp_globals;
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
      int ml_make_mode = ((flags & 1) ? SPAR_ML_MAKE_BNODE_IF_NULL : SPAR_ML_MAKE_VAR_IF_NULL);
      if (DV_STRING == DV_TYPE_OF (storage_name))
        storage_name = t_box_dv_uname_string (storage_name);
      sparp.sparp_storage = sparp_find_storage_by_name (&sparp, storage_name);
      t_set_push (&(spare.spare_context_gp_subtypes), (caddr_t)((ptrlong)WHERE_L));
      triple = spar_make_plain_triple (&sparp,
        spar_make_literal_from_sql_box (&sparp, sqlvals[SPART_TRIPLE_GRAPH_IDX]		, ml_make_mode),
        spar_make_literal_from_sql_box (&sparp, sqlvals[SPART_TRIPLE_SUBJECT_IDX]	, ml_make_mode),
        spar_make_literal_from_sql_box (&sparp, sqlvals[SPART_TRIPLE_PREDICATE_IDX]	, ml_make_mode),
        spar_make_literal_from_sql_box (&sparp, sqlvals[SPART_TRIPLE_OBJECT_IDX]	, ml_make_mode),
        (SPART **)t_list (2, NULL, (ptrlong)(_STAR)), NULL );
      DO_BOX_FAST (caddr_t, itm, src_idx, good_sources_val)
        {
          SPART *expn = spar_make_literal_from_sql_box (&sparp, itm, SPAR_ML_SAFEST);
          if (SPAR_QNAME == SPART_TYPE (expn))
            sources [src_total_count++] = spartlist (&sparp, 5, SPAR_GRAPH,
             SPART_GRAPH_FROM, expn->_.qname.val, expn, (ptrlong)0 );
        }
      END_DO_BOX_FAST;
      DO_BOX_FAST (caddr_t, itm, src_idx, bad_sources_val)
        {
          SPART *expn = spar_make_literal_from_sql_box (&sparp, itm, SPAR_ML_SAFEST);
          if (SPAR_QNAME == SPART_TYPE (expn))
            sources [src_total_count++] = spartlist (&sparp, 5, SPAR_GRAPH,
             SPART_GRAPH_NOT_FROM, expn->_.qname.val, expn, (ptrlong)0 );
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
              jso_rtti_t *sub = (jso_rtti_t *)gethash (tc->tc_qm, jso_rttis_of_structs);
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
                /* int unique_bij_fld = -1; */
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
                    /* if (qmv->qmvColumnsFormKey)
                      unique_bij_fld = fld_ctr; */
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
      if (SQL_SUCCESS != sparqre.sparqre_catched_error) /* if err is SQL_SUCCESS will be done below as no jump will occur */
	{
          if (NULL != sparqre.sparqre_metadata_rwlock)
            {
              rwlock_unlock (sparqre.sparqre_metadata_rwlock);
              sparqre.sparqre_metadata_rwlock = NULL;
            }
	  ssg_free_internals (&ssg);
	  MP_DONE ();
	}
      sqlr_resignal (sparqre.sparqre_catched_error);
    }
  END_QR_RESET
  if (NULL != sparqre.sparqre_metadata_rwlock)
    {
      rwlock_unlock (sparqre.sparqre_metadata_rwlock);
      sparqre.sparqre_metadata_rwlock = NULL;
    }
  ssg_free_internals (&ssg);
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
        box_sprintf (0x100, "#define %25s %d /* '%s' (%c) */",
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

extern caddr_t bif_sparql_rdb2rdf_codegen (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args);
extern caddr_t bif_sparql_rdb2rdf_list_tables (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args);
extern bif_t bif_isnotnull;

extern void sparql_init_bif_optimizers (void);

void
sparql_init (void)
{
  caddr_t err;
  rdf_ds_load_all();
  jso__quad_storage.jsocd_rwlock_id = box_dv_short_string (" SPARQL_optimizer/*");
  iri_to_id_nosignal_cached_qr = sql_compile_static (iri_to_id_nosignal_text, bootstrap_cli, &err, SQLC_STATIC_PRESERVES_TREE);
  id_to_iri_cached_qr = sql_compile_static (id_to_iri_text, bootstrap_cli, &err, SQLC_STATIC_PRESERVES_TREE);
  bif_define ("sparql_to_sql_text", bif_sparql_to_sql_text);
  bif_define ("sparql_detalize", bif_sparql_detalize);
  bif_define ("sparql_explain", bif_sparql_explain);
  bif_define ("sparql_lex_analyze", bif_sparql_lex_analyze);
  bif_define ("sparql_quad_maps_for_quad", bif_sparql_quad_maps_for_quad);
  bif_define ("sparql_sql_cols_for_quad", bif_sparql_sql_cols_for_quad);
  bif_define ("sparql_rdb2rdf_codegen", bif_sparql_rdb2rdf_codegen);
  bif_define ("sparql_rdb2rdf_list_tables", bif_sparql_rdb2rdf_list_tables);
  bif_define ("__sprintff_is_proven_bijection", bif_sprintff_is_proven_bijection);
  bif_define ("__sprintff_is_proven_unparseable", bif_sprintff_is_proven_unparseable);
  bif_define ("__sprintff_intersect", bif_sprintff_intersect);
  bif_define ("__sprintff_like", bif_sprintff_like);
#ifdef DEBUG
  bif_define ("sparql_lex_test", bif_sparql_lex_test);
#endif
  sparql_init_bif_optimizers ();
}

/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2023 OpenLink Software
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

#include "json.h"
#include "libutil.h"
#include "sqlnode.h"
#include "sqlbif.h"

extern int jsonyyparse (jsonp_t *jsonp_arg, yyscan_t scanner);
extern int jsonldyyparse (jsonp_t *jsonp_arg, yyscan_t scanner);
int jsonyylex_init(yyscan_t* );
void jsonyyset_extra (jsonp_t *jsonp_arg, yyscan_t yyscanner);

#define JSONP_ARG_INIT(jp, str, base, giri) \
    memset ((jp), 0, sizeof (jsonp_t)); \
    (jp)->line = 1; \
    (jp)->last_node_no = 1; \
    (jp)->base_uri = base; \
    (jp)->curr_graph_uri = giri; \
    (jp)->jtext = str; \
    (jp)->stack = NULL; \
    (jp)->jtext_len = box_length (str) - 1

#define JSONP_ARG_RESET(jp) \
    (jp)->jtext_ofs = 0; \
    (jp)->line = 1; \
    (jp)->last_node_no = 1; \
    (jp)->lvl = 0; \
    memset (&(jp)->curr_item, 0, sizeof(jsonld_item_t))

static caddr_t
bif_json_parse (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t str = bif_string_arg (qst, args, 0, "json_parse");
  caddr_t tree = NULL;
  caddr_t err = NULL;
  jsonp_t jsonp;
  yyscan_t scanner;

  MP_START();
  JSONP_ARG_INIT (&jsonp, str, 0, 0);
  jsonyylex_init (&scanner);
  jsonyyset_extra (&jsonp, scanner);
  QR_RESET_CTX
    {
    jsonyyparse (&jsonp, scanner);
    tree = box_copy_tree ((caddr_t) jsonp.jtree);
    }
  QR_RESET_CODE
    {
      du_thread_t *self = THREAD_CURRENT_THREAD;
      err = thr_get_error_code (self);
      thr_set_error_code (self, NULL);
      tree = NULL;
      /*no POP_QR_RESET*/;
    }
  END_QR_RESET;
  MP_DONE();
  if (!tree)
    sqlr_resignal (err);
  return tree;
}

extern int jsonldyydebug;

void
jsonyyerror_impl(jsonp_t * jsonp_arg, const char *s)
{
  if (JSON_TREE == jsonp_arg->jpmode)
    sqlr_new_error ("37000", "JSON1", "JSON parser failed: %.200s at line %d", s, jsonp_arg->line);
  else
    sqlr_new_error ("37000", "JSLDP", "JSON-LD parser failed: %.200s at line %d", s, jsonp_arg->line);
}

caddr_t *
jsonld_item_new (caddr_t type, caddr_t id, caddr_t value, caddr_t lang, uint32 flags)
{
  jsonld_item_t * item = (jsonld_item_t *)t_alloc (sizeof (jsonld_item_t));
  memset (item, 0, sizeof (jsonld_item_t));
  item->type = type;
  item->id = id;
  item->value = value;
  item->lang = lang;
  item->flags = flags;
  return (caddr_t *)item;
}

void
jsonld_ctx_set (jsonp_t *jsonp_arg)
{
  jsonld_ctx_t * ctx = jsonp_arg->curr_ctx;
  if (!ctx || JSON_LD_CTX == jsonp_arg->jpmode)
    return;
  if (jsonp_arg->lvl > ctx->lvl)
    {
      while (ctx->next && jsonp_arg->lvl > ctx->lvl)
        jsonp_arg->curr_ctx = ctx = ctx->next;
      return;
    }
  if (jsonp_arg->lvl < ctx->lvl)
    {
      while (ctx->prev && jsonp_arg->lvl < ctx->lvl)
        jsonp_arg->curr_ctx = ctx = ctx->prev;
      return;
    }
}

jsonld_ctx_t *
jsonld_ctx_allocate (jsonp_t *jsonp_arg)
{
  jsonld_ctx_t * jc, *ctx = jsonp_arg->curr_ctx, *next = NULL;

  if (NULL != jsonp_arg->curr_ctx && JSON_LD_CTX == jsonp_arg->jpmode)
    return jsonp_arg->curr_ctx;

  jc = (jsonld_ctx_t *) t_alloc (sizeof (jsonld_ctx_t));
  jc->lvl = jsonp_arg->lvl;
  jc->id = jsonp_arg->curr_graph_uri; /*it might be set or null, set when found, if none give a bnode */
  jc->ns2iri = t_id_hash_allocate (100, sizeof (caddr_t), sizeof (caddr_t), strhash, strhashcmp);

  while (ctx && ctx->lvl > jc->lvl)
    next = ctx->next, ctx = ctx->prev;

  if (ctx)
    ctx->next = jc;
  else
    jc->next = jsonp_arg->curr_ctx;

  if (next)
    next->prev = jc;
  jc->prev = ctx;

  jsonp_arg->curr_ctx = jc;
  return jc;
}

/* We MUST be carefull here, MUST  detect cycles in terms */
caddr_t
jsonld_term_resolve_1 (jsonp_t *jsonp_arg, caddr_t term, jsonld_item_t ** ret_item, int direct)
{
  jsonld_ctx_t * ctx = jsonp_arg->curr_ctx;
  id_hash_t * ht = ctx ? ctx->ns2iri : NULL;
  jsonld_item_t ** item;
  caddr_t name, qname;

  if (!ht || !term || '@' == term[0])
    return term;
  item = ht ? (jsonld_item_t**)id_hash_get (ht, (caddr_t)&term) : NULL;
  while (!item && ctx->prev)
    {
      ctx = ctx->prev;
      item = (jsonld_item_t **)id_hash_get (ctx->ns2iri, (caddr_t)&term);
    }
  name = qname = ((item && item[0]->id) ? item[0]->id : term);
  if (direct && name && strchr (name, ':') && !strchr (name, '/')) /* must be more precise here, ck for BF_IRI for ex. */
    name = jsonld_qname_resolve (jsonp_arg, qname, NULL);
  /* use @base & @vocab if not */
  if (ret_item)
    ret_item[0] = item ? item[0] : NULL;
  if (name == term)
    name = jsonp_term_uri_resolve (jsonp_arg, qname);
  return (name ? name : qname);
}

caddr_t
jsonld_qname_resolve (jsonp_t *jsonp_arg, caddr_t qname, jsonld_item_t ** ret_item)
{
  char * colon;
  caddr_t pref, local, ns_uri, abs_name;
  jsonld_item_t * item = NULL;

  if (!qname || '@' == qname[0] ||
    (NULL != (colon = strchr (qname, ':')) && strchr (qname, '/')) ||
    (colon && strchr (qname, ':') != strrchr (qname, ':'))) /* must be more precise here ck for BF_IRI for ex. */
    return qname;
  if (!colon)
    return jsonld_term_resolve (jsonp_arg, qname, ret_item);
  pref = t_box_dv_short_nchars (qname, (int)(colon - qname));
  local = t_box_dv_short_string (colon+1);
  ns_uri = jsonld_term_resolve_1 (jsonp_arg, pref, &item, 0);
  /* use @base & @vocab if not */
  if (ret_item)
    ret_item[0] = item;
  if (!ns_uri || ns_uri == pref)
    abs_name = qname;
  else
    abs_name = t_box_dv_short_concat (ns_uri, local);
  return abs_name;
}

caddr_t
jsonld_term_resolve (jsonp_t *jsonp_arg, caddr_t term, jsonld_item_t ** ret_item)
{
  return jsonld_term_resolve_1 (jsonp_arg, term, ret_item, 1);
}

void
jsonld_resolve_refs (jsonp_t *jsonp_arg)
{
  caddr_t *key, *val;
  id_hash_t *ht = jsonp_arg->curr_ctx->ns2iri;
  id_hash_iterator_t hit;
  id_hash_iterator (&hit, ht);

  while (hit_next (&hit, (caddr_t *) &key, (caddr_t *) &val))
    {
      jsonld_item_t *itm = (jsonld_item_t *)(val[0]);
      itm->id = jsonld_qname_resolve (jsonp_arg, itm->id, NULL);
      itm->type = jsonld_qname_resolve (jsonp_arg, itm->type, NULL);
    }
}

void
jsonld_item_print (jsonld_item_t *itm)
{
#ifdef _JSONLD_DEBUG_Q
  if (!itm)
    {
      fprintf (stdout, "ITM: NULL\n");
      return;
    }
  /*fprintf (stdout, " ITM: ");*/
  fprintf (stdout, " id="); dbg_print_box(itm->id, stdout);
  fprintf (stdout, " name="); dbg_print_box(itm->name, stdout);
  fprintf (stdout, " value="); dbg_print_box(itm->value, stdout);
  fprintf (stdout, " type="); dbg_print_box(itm->type, stdout);
  fprintf (stdout, " lang="); dbg_print_box(itm->lang, stdout);
  fprintf (stdout, " flags=%x", itm->flags);
  fprintf (stdout, "\n");
#endif
}

uint32 jsonld_debug_quad = 0;

void
jsonld_quad_insert (jsonp_t * jsonp_arg, jsonld_item_t *itm)
{
  caddr_t subj, prop, obj, dt, lang, subj_iid = NULL, obj_iid = NULL, err = NULL;
  int is_bnode_obj, is_ref;

  if (!itm || jsonld_debug_quad)
    return;

  subj_iid = subj = itm->id, prop = itm->name, obj_iid = obj = itm->value;
  dt = itm->type, lang = itm->lang;
  is_bnode_obj = (DV_STRINGP(obj) && 0 == strncmp(obj, "_:", 2));
  is_ref = (uname_at_id == dt || is_bnode_obj);

  if (uname_at_type == prop)
    prop = uname_rdf_ns_uri_type;
  if (!(subj && prop && obj))
    {
#ifdef _JSONLD_DEBUG
      printf ("QUAD: skipped\n");
#endif
      return;
    }
  if (0 == strncmp(subj, "_:", 2))
    subj_iid = tf_bnode_iid (jsonp_arg->jtf, box_dv_short_string (subj));
  else
    subj_iid = subj = jsonld_qname_resolve(jsonp_arg, subj,NULL);
  if (is_bnode_obj)
    obj_iid = tf_bnode_iid (jsonp_arg->jtf, box_dv_short_string (obj));
  if (is_ref)
    {
      if (!is_bnode_obj)
        {
          obj = jsonld_qname_resolve(jsonp_arg, obj,NULL);
          obj_iid = obj = jsonp_uri_resolve (jsonp_arg, obj); /* relative ref obj resloved here */
        }
      tf_triple (jsonp_arg->jtf, subj_iid, prop, obj_iid);
    }
  else
    {
      if (!dt && !lang && DV_STRINGP(obj) && NULL != jsonp_arg->curr_ctx && NULL != jsonp_arg->curr_ctx->lang)
         lang = jsonp_arg->curr_ctx->lang;
      if (uname_at_none == lang)
        lang = NULL;
      JLD_AUDIT_O (obj, dt, lang, err);
      if (!err)
        tf_triple_l (jsonp_arg->jtf, subj_iid, prop, obj, dt, lang);
    }
#ifdef _JSONLD_DEBUG_Q
  printf ("QUAD: ");
  jsonld_item_print (itm);
#endif
  if (obj != obj_iid)
    dk_free_tree (obj_iid);
  if (subj != subj_iid)
    dk_free_tree (subj_iid);
  if (NULL != err)
    sqlr_resignal (err);
}

caddr_t
jsonp_uri_resolve (jsonp_t *jsonp_arg, caddr_t qname)
{
  caddr_t res, err = NULL;
  caddr_t base;
  if (IS_IRI_DTP(DV_TYPE_OF(qname)))
    return qname;
  if ('@' == qname[0])
    return qname;
  if (('_' == qname[0]) && (':' == qname[1]))
    return qname;
  base = ((jsonp_arg->curr_ctx && jsonp_arg->curr_ctx->base) ? jsonp_arg->curr_ctx->base : jsonp_arg->base_uri);
  res = rfc1808_expand_uri (base, qname, "UTF-8", 1, "UTF-8", "UTF-8", &err);
  if (res == jsonp_arg->base_uri)
    res = t_full_box_copy_tree (res);
  if (NULL != err)
    sqlr_resignal (err);
  if (res != base)
    mp_trash (THR_TMP_POOL, res);
  return res;
}

caddr_t
jsonp_term_uri_resolve (jsonp_t *jsonp_arg, caddr_t term)
{
  caddr_t res, err = NULL;
  caddr_t base = (jsonp_arg->curr_ctx && jsonp_arg->curr_ctx->ns) ? jsonp_arg->curr_ctx->ns : NULL;
  if (IS_IRI_DTP(DV_TYPE_OF(term)))
    return term;
  if ('@' == term[0])
    return term;
  if (('_' == term[0]) && (':' == term[1]))
    return term;
  if (!base)
    return term;
  res = rfc1808_expand_uri (base, term, "UTF-8", 1, "UTF-8", "UTF-8", &err);
  if (NULL != err)
    sqlr_resignal (err);
  if (res != base)
    mp_trash (THR_TMP_POOL, res);
  return res;
}

void
jsonld_frame_push (jsonp_t *jsonp_arg)
{
  jsonld_item_t * itm;
  if (JSON_LD_MAP == jsonp_arg->jpmode || JSON_LD == jsonp_arg->jpmode)
    {
      itm = (jsonld_item_t *) t_alloc (sizeof (jsonld_item_t));
      memcpy (itm, &jsonp_arg->curr_item, sizeof (jsonld_item_t));
      dk_set_push (&jsonp_arg->stack, (void *)itm);
    }
  if (JSON_LD == jsonp_arg->jpmode)
    {
      if (!JF_IS(INLINED) && !JF_IS(ID_CONT))
        {
          jsonp_arg->curr_id = NULL;
          jsonp_arg->curr_name = NULL;
          /*jsonp_arg->curr_type = NULL;*/
        }
      jsonp_arg->curr_value = NULL;
      jsonp_arg->curr_type = NULL;
      jsonp_arg->curr_lang = NULL;
    }
  jsonp_arg->last_node_no++;
  jsonp_arg->curr_node_no = jsonp_arg->last_node_no;
  if (JSON_LD == jsonp_arg->jpmode && !JF_IS(LANG_CONT) && !JF_IS(ID_CONT)) /* lang container do not have id, the id cont keep from prev */
    jsonp_arg->curr_id = gethash ((void*)jsonp_arg->curr_node_no, jsonp_arg->node2id);
  jsonp_arg->lvl++;
  jsonld_ctx_set(jsonp_arg);
}

void
jsonld_frame_pop (jsonp_t *jsonp_arg)
{
  if (JSON_LD_MAP == jsonp_arg->jpmode || JSON_LD == jsonp_arg->jpmode)
    {
      jsonld_item_t * itm = dk_set_pop (&jsonp_arg->stack);
      jsonp_arg->curr_node_no = itm->node_no;
      if (JSON_LD == jsonp_arg->jpmode)
        {
          memcpy (&jsonp_arg->curr_item, itm, sizeof (jsonld_item_t));
          if (!jsonp_arg->curr_id)
            jsonp_arg->curr_id = gethash ((void*)jsonp_arg->curr_node_no, jsonp_arg->node2id);
        }
      if (jsonp_arg->curr_id)
        JF_SET(ID);
    }
  jsonp_arg->lvl--;
  jsonld_ctx_set(jsonp_arg);
}

/*
   tries to get vocab from cache, the calling code is in charge to set XML_URI_GET_ACCEPT connection property
   as well as HTTP_CLI_TIMEOUT sec
   if can't find or get from cache fails silently, if find something parse in same MP and pushe in the CTX's HT maps.
   Note parsing uses JMODE_LD_CTX which do not load anything in RDF store, only fill the current cache,
   another note, the CTX nesting is not performed because is import
 */
void
jsonld_context_uri_get (jsonp_t * jsonp_arg, caddr_t uri, id_hash_t *ht)
{
  caddr_t content;
  query_instance_t * qi = jsonp_arg->qi;
  caddr_t err = NULL;
  content = xml_uri_get (qi, &err, NULL, jsonp_arg->base_uri, uri, XML_URI_STRING);
  jsonp_t jsonp;
  jsonld_ctx_t jctx;
  yyscan_t scanner;

  if (err) /* not loaded, http error or something */
    {
      dk_free_tree (err);
      return;
    }
  if (NULL == THR_TMP_POOL) /* outside of parser, caller must take care to set THR mem pool*/
    return;
  memset (&jctx, 0, sizeof (jsonld_ctx_t));
  jctx.ns2iri = ht;
  JSONP_ARG_INIT(&jsonp, content, NULL, NULL);
  jsonp.jpmode = JSON_LD_CTX;
  jsonp.curr_ctx = &jctx;
  jsonp.qi = qi;

  jsonyylex_init (&scanner);
  jsonyyset_extra (&jsonp, scanner);
  QR_RESET_CTX
    {
      jsonldyyparse (&jsonp, scanner);
    }
  QR_RESET_CODE
    {
      du_thread_t *self = THREAD_CURRENT_THREAD;
      err = thr_get_error_code (self);
      thr_set_error_code (self, NULL);
      /*no POP_QR_RESET*/;
    }
  END_QR_RESET;
  if (err) /* just free and forget */
    dk_free_tree (err);
  return;
}

static
caddr_t
bif_rdf_load_jsonld (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  static char * fn = "rdf_load_jsonld";
  caddr_t str = bif_string_arg (qst, args, 0, fn);
  caddr_t base_uri = bif_string_or_uname_arg (qst, args, 1, fn);
  caddr_t graph_uri = bif_string_or_uname_or_wide_or_null_arg (qst, args, 2, fn);
  long flags = BOX_ELEMENTS (args) > 3 ? bif_long_arg (qst, args, 3, fn) : 0;
  caddr_t *cbk_names = BOX_ELEMENTS (args) > 4 ? bif_strict_type_array_arg (DV_STRING, qst, args, 4, fn) : NULL;
  caddr_t *app_env = BOX_ELEMENTS (args) > 5 ? (caddr_t *) bif_arg (qst, args, 5, fn) : NULL;
  caddr_t ctx_url = BOX_ELEMENTS (args) > 6 ? bif_string_or_null_arg (qst, args, 6, fn) : NULL;
  caddr_t err = NULL;
  triple_feed_t *tf = NULL;
  jsonp_t jsonp;
  yyscan_t scanner;

  if ((COUNTOF__TRIPLE_FEED__REQUIRED > BOX_ELEMENTS (cbk_names)) || (COUNTOF__TRIPLE_FEED__ALL < BOX_ELEMENTS (cbk_names)))
    sqlr_new_error ("22023", "RDF01",
      "The argument #4 of rdf_load_jsonld() should be a vector of %d to %d names of stored procedures",
      COUNTOF__TRIPLE_FEED__REQUIRED, COUNTOF__TRIPLE_FEED__ALL );

  JSONP_ARG_INIT(&jsonp, str, base_uri, graph_uri);
  jsonp.jtf = tf_alloc ();
  tf = jsonp.jtf;
  jsonp.qi = tf->tf_qi = (query_instance_t *)qst;
  if (NULL != cbk_names && NULL != app_env)
    {
      tf->tf_app_env = app_env;
      QR_RESET_CTX
        {
          tf_set_cbk_names (tf, (ccaddr_t *)cbk_names);
        }
      QR_RESET_CODE
        {
          du_thread_t *self = THREAD_CURRENT_THREAD;
          err_ret[0] = thr_get_error_code (self);
          thr_set_error_code (self, NULL);
          POP_QR_RESET;
          tf_free (tf);
          return NULL;
        }
      END_QR_RESET
    }

  MP_START();
  jsonyylex_init (&scanner);
  jsonyyset_extra (&jsonp, scanner);
  jsonp.node2id = hash_table_allocate(101);
  QR_RESET_CTX
    {
      jsonldyydebug = flags & 0x10000;
      if (ctx_url)
        {
          jsonp.jpmode = JSON_LD_CTX;
          jsonp.lvl = 1;
          jsonld_ctx_allocate (&jsonp);
          jsonld_context_uri_get (&jsonp, ctx_url, jsonp.curr_ctx->ns2iri);
          jsonp.lvl = 0;
        }
      jsonp.jpmode = JSON_LD_MAP;
      jsonldyyparse (&jsonp, scanner);
#if _JSONLD_DEBUG
      DO_HT (void*, k, void *, d, jsonp.node2id)
        {
          printf ("%ld -> %s\n", (long)k, d);
        }
      END_DO_HT;
#endif
      jsonp.jpmode = JSON_LD;
      JSONP_ARG_RESET(&jsonp); /* reset node no, line etc. keep hash and bnode */
      jsonldyyparse (&jsonp, scanner);
    }
  QR_RESET_CODE
    {
      du_thread_t *self = THREAD_CURRENT_THREAD;
      err = thr_get_error_code (self);
      thr_set_error_code (self, NULL);
      /*no POP_QR_RESET*/;
    }
  END_QR_RESET;
  while (NULL != dk_set_pop(&jsonp.stack));
  MP_DONE();
  tf_free (tf);
  hash_table_free (jsonp.node2id);
  if (err)
    sqlr_resignal (err);
  return NULL;
}

void
bif_json_init (void)
{
  bif_define ("json_parse", bif_json_parse);
  bif_define ("rdf_load_jsonld", bif_rdf_load_jsonld);
}

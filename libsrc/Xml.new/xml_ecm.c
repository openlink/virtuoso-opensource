/*
 *  xml_ecm.c
 *
 *  $Id$
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

#include "xmlparser_impl.h"
#include "xml_ecm.h"
#include <stddef.h>
#include <string.h>

unsigned char ecm_utf8props[0x100] = {
/* 0   1   2   3   4   5   6   7   8   9   A   B   C   D   E   F  */
  'A',' ',' ',' ',' ',' ',' ',' ',' ','B','B',' ',' ','B',' ',' ',
/* 0   1   2   3   4   5   6   7   8   9   A   B   C   D   E   F  */
  ' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',
/*     !   "   #   $   %   &   '   (   )   *   +   ,   -   .   /  */
  'B',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ','D','D',' ',
/* 0   1   2   3   4   5   6   7   8   9   :   ;   <   =   >   ?  */
  'L','L','L','L','L','L','L','L','L','L','L',' ',' ',' ',' ',' ',
/* @   A   B   C   D   E   F   G   H   I   J   K   L   M   N   O  */
  ' ','L','L','L','L','L','L','L','L','L','L','L','L','L','L','L',
/* P   Q   R   S   T   U   V   W   X   Y   Z   [   \   ]   ^   _  */
  'L','L','L','L','L','L','L','L','L','L','L',' ',' ',' ',' ','L',
/* `   a   b   c   d   e   f   g   h   i   j   k   l   m   n   o  */
  ' ','L','L','L','L','L','L','L','L','L','L','L','L','L','L','L',
/* p   q   r   s   t   u   v   w   x   y   z   {   |   }  '~' 7F  */
  'L','L','L','L','L','L','L','L','L','L','L',' ',' ',' ',' ',' ',
/* 0   1   2   3   4   5   6   7   8   9   A   B   C   D   E   F  */
  'L','L','L','L','L','L','L','L','L','L','L','L','L','L','L','L',
/* 0   1   2   3   4   5   6   7   8   9   A   B   C   D   E   F  */
  'L','L','L','L','L','L','L','L','L','L','L','L','L','L','L','L',
/* 0   1   2   3   4   5   6   7   8   9   A   B   C   D   E   F  */
  'L','L','L','L','L','L','L','L','L','L','L','L','L','L','L','L',
/* 0   1   2   3   4   5   6   7   8   9   A   B   C   D   E   F  */
  'L','L','L','L','L','L','L','L','L','L','L','L','L','L','L','L',
/* 0   1   2   3   4   5   6   7   8   9   A   B   C   D   E   F  */
  'L','L','L','L','L','L','L','L','L','L','L','L','L','L','L','L',
/* 0   1   2   3   4   5   6   7   8   9   A   B   C   D   E   F  */
  'L','L','L','L','L','L','L','L','L','L','L','L','L','L','L','L',
/* 0   1   2   3   4   5   6   7   8   9   A   B   C   D   E   F  */
  'L','L','L','L','L','L','L','L','L','L','L','L','L','L','L','L',
/* 0   1   2   3   4   5   6   7   8   9   A   B   C   D   E   F  */
  'L','L','L','L','L','L','L','L','L','L','L','L','L','L','L','L' };

/* Parser for children-order description */

ecm_term_t *ecm_term_ctor (
  ecm_el_idx_t et_value_, ecm_term_t *et_subterm1_, ecm_term_t *et_subterm2_ )
{
  ecm_term_t *res;
  ptrlong may_be_empty;
  switch (et_value_)
    {
    case ECM_TERM_CHAIN:
      may_be_empty = et_subterm1_->et_may_be_empty && et_subterm2_->et_may_be_empty;
      goto create_new;
    case ECM_TERM_CHOICE:
      may_be_empty = (ECM_EMPTY == et_subterm1_) || (ECM_EMPTY == et_subterm2_) || et_subterm1_->et_may_be_empty || et_subterm2_->et_may_be_empty;
      goto create_new;
    case ECM_TERM_LOOP_ZERO:
      if ((ECM_TERM_LOOP_ZERO == et_subterm1_->et_value) || (ECM_TERM_LOOP_ONE == et_subterm1_->et_value))
	{
	  et_subterm1_->et_value = ECM_TERM_LOOP_ZERO;
	  return et_subterm1_;
	}
      may_be_empty = 1;
      goto create_new;
    case ECM_TERM_LOOP_ONE:
      if ((ECM_TERM_LOOP_ZERO == et_subterm1_->et_value) || (ECM_TERM_LOOP_ONE == et_subterm1_->et_value))
	{
	  return et_subterm1_;
	}
      may_be_empty = et_subterm1_->et_may_be_empty;
      if (may_be_empty)
	et_value_ = ECM_TERM_LOOP_ZERO;
    default:
      may_be_empty = 0;
    }
create_new:
  res = dk_alloc_box (sizeof(ecm_term_t), DV_ARRAY_OF_POINTER);
  res->et_value = et_value_;
  res->et_subterm1 = et_subterm1_;
  res->et_subterm2 = et_subterm2_;
  res->et_may_be_empty = may_be_empty;
  return res;
}

#define ADVANCE_TAILPTR curc = (++(tailptr[0]))[0]

#define SKIP_ALL_SPACES \
  while (ecm_utf8props[curc] & ECM_ISSPACE) \
    { \
      ADVANCE_TAILPTR; \
    }

ecm_term_t *ecm_term_compose_aux (utf8char **tailptr, struct dtd_s *dv_dtd, char **errmsg)
{
  utf8char curc = tailptr[0][0];
  utf8char *frag_begin;
  char *name;
  ecm_term_t *res = NULL, *sub2 = NULL;
  ecm_el_idx_t nameidx;
  char first_delim = '\0';

  switch (curc)
    {
    case '\0':
      errmsg[0] = box_dv_short_string ("[48] Unexpected end of content specification. '(' or name expected.");
      return NULL;
    case '(':
      ADVANCE_TAILPTR;
      goto get_binary;
    case ')': case ',': case '|': case '?': case '*': case '+':
      errmsg[0] = box_sprintf (100, "[48] Misplaced '%c' instead of element name or subterm.", curc);
      return NULL;
    }

/* Trying to find a name or a left subterm */
  frag_begin = tailptr[0];

  if (ecm_utf8props[curc] & ECM_ISNAMEBEGIN)
    {
      ADVANCE_TAILPTR;
      while (ecm_utf8props[curc] & ECM_ISNAME)
	{
	  ADVANCE_TAILPTR;
	}
      name = box_dv_short_nchars ((char *)frag_begin, tailptr[0] - frag_begin);
      nameidx = ecm_find_name (name, dv_dtd->ed_els, dv_dtd->ed_el_no, sizeof (ecm_el_t));
      if (nameidx < 0)
	{ errmsg[0] = box_sprintf (100 + box_length(name), "[3.2.1] Unknown entity name '%s', in content specification.", name);
          dk_free_box (name);
	  return NULL;
	}
      dk_free_box (name);
      res = ecm_term_ctor (nameidx, NULL, NULL);
      goto check_postfix;
    }
  if ('#' == curc)
    {
      if ((0 == memcmp(frag_begin,"#PCDATA", 7)) && (!(ecm_utf8props[tailptr[0][7]] & ECM_ISNAME)))
	{
	  tailptr[0] += 7;
	  /* Rus/XMLConf 20010702 */
	  return ecm_term_ctor (ECM_TERM_LOOP_ZERO, ecm_term_ctor(ECM_EL_PCDATA, NULL, NULL) , NULL);
	}
      errmsg[0] = box_dv_short_string ("[48] Only '#PCDATA' may be specified with '#' character");
      return NULL;
    }
  errmsg[0] = box_dv_short_string ("[48] Invalid element name.");
  return NULL;

get_binary:
  SKIP_ALL_SPACES;
  res = ecm_term_compose_aux (tailptr, dv_dtd, errmsg);
  curc = tailptr[0][0];
  if (NULL != errmsg[0])
    return NULL;

next_delim:
  SKIP_ALL_SPACES;
  switch (curc)
    {
    case ')':
      ADVANCE_TAILPTR;
      goto check_postfix;
    case ',': case '|':
      if ('\0' != first_delim)
	{
	  if (curc != first_delim)
	    {
	      ecm_term_free (res);
	      errmsg[0] = box_dv_short_string ("[49] Mixed ',' and '|' are not allowed, use additional parentheses.");
	      return NULL;
	    }
	}
      else
	{
	  first_delim = curc;
	}
      ADVANCE_TAILPTR;
      SKIP_ALL_SPACES;
      sub2 = ecm_term_compose_aux (tailptr, dv_dtd, errmsg);
      curc = tailptr[0][0];
      if (NULL != errmsg[0])
	{
	  ecm_term_free (res);
	  return NULL;
	}
      res = ecm_term_ctor (((',' == first_delim) ? ECM_TERM_CHAIN : ECM_TERM_CHOICE), res, sub2);
      goto next_delim;
    case '\0':
      ecm_term_free (res);
      errmsg[0] = box_dv_short_string ("[48] Unexpected end of content specification. binary operator or ')' expected.");
      return NULL;
    default:
      ecm_term_free (res);
      if (('(' == curc) || (ecm_utf8props[curc] & ECM_ISNAMEBEGIN))
	{
	  errmsg[0] = box_dv_short_string ("[48] Two subterms has no delimiter between them.");
	  return NULL;
	}
      errmsg[0] = box_sprintf (100, "[48] Misplaced '%c' instead of delimiter or ')'.", curc);
      return NULL;
    }

check_postfix:
  /*SKIP_ALL_SPACES;*/
  switch (curc)
    {
    case '?':
      ADVANCE_TAILPTR;
      return ecm_term_ctor (ECM_TERM_CHOICE, res, ECM_EMPTY);
    case '*':
      ADVANCE_TAILPTR;
      return ecm_term_ctor (ECM_TERM_LOOP_ZERO, res, NULL);
    case '+':
      ADVANCE_TAILPTR;
      return ecm_term_ctor (ECM_TERM_LOOP_ONE, res, NULL);
    }
  return res;
}


ecm_term_t *ecm_term_compose (utf8char *ee_grammar_string, struct dtd_s *dv_dtd, char **errmsg)
{
  utf8char *tail = ee_grammar_string;
  utf8char **tailptr = &tail;
  utf8char curc = tail[0];
  ecm_term_t *res;
  errmsg[0] = NULL;

  SKIP_ALL_SPACES;
  switch (curc)
    {
      case '\0':
	errmsg[0] = box_dv_short_string ("[46] Content specification is totally empty.");
	return NULL;
      case '(':
	goto get_term;
      default:
	if ((0 == memcmp(tailptr[0],"ANY", 3)) && (ecm_utf8props[tailptr[0][3]] & (ECM_ISSPACE | ECM_ISZERO)))
	  return ECM_ANY;
	if ((0 == memcmp(tailptr[0],"EMPTY", 5)) && (ecm_utf8props[tailptr[0][5]] & (ECM_ISSPACE | ECM_ISZERO)))
	  return ECM_EMPTY;
	errmsg[0] = box_dv_short_string ("[46] \"ANY\", \"EMPTY\" or \"(\" expected at the begin of content specification.");
	return NULL;
    }

get_term:
  res = ecm_term_compose_aux (tailptr, dv_dtd, errmsg);
  curc = tailptr[0][0];
  if (NULL != errmsg[0])
    return NULL;
  if (NULL == res)
    {
      errmsg[0] = box_dv_short_string ("[46] Content specification is totally empty.");
      return NULL;
    }

  /* Check for trailing garbage */
  SKIP_ALL_SPACES;
  if ('\0' != curc)
    {
      errmsg[0] = box_dv_short_string ("[46] Too many terms in content specification. Missing comma?");
      ecm_term_free (res);
      return NULL;
    }
  return res;
}


/* Compiler of terms' tree into FSA */

struct ecm_fts_context_s
{
  ecm_st_t **		efc_states;
  ecm_st_idx_t *	efc_state_no;
  dtd_t *		efc_dtd;
};

typedef struct ecm_fts_context_s ecm_fts_context_t;


struct ecm_fts_rest_s
{
  ecm_term_t *			efr_tree;
  ecm_st_idx_t			efr_scheduled_begin;
  struct ecm_fts_rest_s *	efr_outer;
};

typedef struct ecm_fts_rest_s ecm_fts_rest_t;


ecm_st_idx_t ecm_add_state (
  ecm_fts_context_t *ctx )
{
  ecm_st_idx_t res = ctx->efc_state_no[0];
  ecm_el_idx_t ctr, el_no;
  ecm_st_t *new_st;
  ecm_st_idx_t *jumps;
  if (0x8 ^ res)
    {
      ecm_st_t *new_array = (ecm_st_t *)dk_alloc_box((res+0x8) * sizeof(ecm_st_t), DV_ARRAY_OF_LONG);
      memcpy (new_array, ctx->efc_states[0], res * sizeof(ecm_st_t));
      if (0 != res)
	dk_free_box (ctx->efc_states[0]);
      ctx->efc_states[0] = new_array;
    }
  ctx->efc_state_no[0] += 1;
  new_st = &(ctx->efc_states[0][res]);
  el_no = ctx->efc_dtd->ed_el_no;
  jumps = (ecm_st_idx_t *)dk_alloc_box((ECM_EL_OFFSET+el_no) * sizeof(ecm_st_idx_t), DV_ARRAY_OF_LONG);
  for (ctr = 0; ctr < ECM_EL_OFFSET+el_no; ctr++)
    jumps[ctr] = ECM_ST_ERROR;
  new_st->es_nexts = jumps;
  new_st->es_conflict = ECM_EL_UNDEF;
  new_st->es_is_frozen = 0;
  return res;
}


ecm_st_idx_t ecm_set_jump (
  ecm_st_idx_t from, ecm_st_idx_t to, ecm_el_idx_t event,
  ecm_fts_context_t *ctx )
{
  ecm_st_idx_t *jump = &(ctx->efc_states[0][from].es_nexts[ECM_EL_OFFSET+event]);
  if (to == ECM_ST_UNDEF)
    {
      if (ECM_ST_ERROR == jump[0])		/* No conflicts because we can't conflict with error */
	{
	  jump[0] = ecm_add_state (ctx);
	  return jump[0];
	}
      if (!(ctx->efc_states[0][jump[0]].es_is_frozen))
	return jump[0];				/* No conflicts because target is not frozen */
      to = ecm_add_state (ctx);		/* Let's set something and check for conflicts */
    }
again:
  if (ECM_ST_ERROR == jump[0])
    {
      jump[0] = to;
      return to;
    }
  if (jump[0] == to)
    {
      return to;
    }
/* We have a conflict */
  jump = &(ctx->efc_states[0][from].es_nexts[ECM_EL_OFFSET+ECM_EL_NULL_T]);
  if (ECM_ST_ERROR == jump[0])
    {
      ecm_st_idx_t new_state = ecm_add_state (ctx);
      jump[0] = new_state;
      ctx->efc_states[0][new_state].es_nexts[ECM_EL_OFFSET+event] = to;
      return to;
    }
  from = jump[0];
  jump = &(ctx->efc_states[0][from].es_nexts[ECM_EL_OFFSET+event]);
  goto again;
}


void ecm_draw_subgraph (
  ecm_term_t *tree, ecm_st_idx_t start,
  ecm_fts_rest_t *tail,
  ecm_fts_context_t *ctx)
{
  ecm_st_idx_t scheduled_end;
  if (NULL == tree)
    return;
  scheduled_end = ((NULL==tail) ? ECM_ST_UNDEF : tail->efr_scheduled_begin);
  if (ECM_EMPTY == tree)
    {
      if ((ECM_ST_UNDEF != scheduled_end) && (start != scheduled_end))
	{
	  ecm_set_jump (start, scheduled_end, ECM_EL_NULL_T, ctx);
	  ecm_draw_subgraph (tail->efr_tree, scheduled_end, tail->efr_outer, ctx);
	  return;
	}
      ecm_draw_subgraph (tail->efr_tree, start, tail->efr_outer, ctx);
      return;
    }
  switch (tree->et_value)
    {
    case ECM_TERM_CHAIN:
      {
	ecm_fts_rest_t sub2;
	sub2.efr_tree = tree->et_subterm2;
	sub2.efr_scheduled_begin = ECM_ST_UNDEF;
	sub2.efr_outer = tail;
	ecm_draw_subgraph (tree->et_subterm1, start, &sub2, ctx);
	return;
      }
    case ECM_TERM_CHOICE:
      {
	ecm_draw_subgraph (tree->et_subterm1, start, tail, ctx);
	ecm_draw_subgraph (tree->et_subterm2, start, tail, ctx);
	return;
      }
    case ECM_TERM_LOOP_ZERO:
      {
#if 0
	ecm_fts_rest_t loop_tail;
	ecm_st_idx_t loop_st = ecm_add_state(ctx);
	loop_tail.efr_tree = NULL;
	loop_tail.efr_scheduled_begin = loop_st;
	loop_tail.efr_outer = NULL;
	/* Draw a bypass */
	ecm_draw_subgraph (ECM_EMPTY, start, tail, ctx);
	/* Draw a first run */
	ecm_draw_subgraph (tree->et_subterm1, start, &loop_tail, ctx);
	/* Draw a loop */
	ecm_draw_subgraph (tree->et_subterm1, loop_st, &loop_tail, ctx);
	/* Draw a tail */
	ctx->efc_states[0][loop_st].es_is_frozen = 1;
	loop_tail.efr_tree = ECM_EMPTY;
	loop_tail.efr_scheduled_begin = tail->efr_scheduled_begin;
	loop_tail.efr_outer = tail;
	ecm_draw_subgraph (ECM_EMPTY, loop_st, &loop_tail, ctx);
	ctx->efc_states[0][loop_st].es_is_frozen = 0;
	return;
#else
	ecm_fts_rest_t loop_tail;
	loop_tail.efr_tree = NULL;
	loop_tail.efr_scheduled_begin = start;
	loop_tail.efr_outer = NULL;
	/* Draw a tail */
	ecm_draw_subgraph (ECM_EMPTY, start, tail, ctx);
	/* Draw a loop */
	ecm_draw_subgraph (tree->et_subterm1, start, &loop_tail, ctx);
	return;
#endif
      }
    case ECM_TERM_LOOP_ONE:
      {
	ecm_fts_rest_t loop_tail;
	ecm_st_idx_t loop_st = ecm_add_state(ctx);
	loop_tail.efr_tree = NULL;
	loop_tail.efr_scheduled_begin = loop_st;
	loop_tail.efr_outer = NULL;
	/* Draw a first run */
	ecm_draw_subgraph (tree->et_subterm1, start, &loop_tail, ctx);
	/* Draw a loop */
	ecm_draw_subgraph (tree->et_subterm1, loop_st, &loop_tail, ctx);
	/* Draw a tail */
	ctx->efc_states[0][loop_st].es_is_frozen = 1;
	loop_tail.efr_tree = ECM_EMPTY;
	loop_tail.efr_scheduled_begin = tail->efr_scheduled_begin;
	loop_tail.efr_outer = tail;
	ecm_draw_subgraph (ECM_EMPTY, loop_st, &loop_tail, ctx);
	ctx->efc_states[0][loop_st].es_is_frozen = 0;
	return;
      }
    case ECM_EL_EOS:
      {
	ctx->efc_states[0][start].es_nexts[ECM_EL_OFFSET+ECM_EL_EOS] = 0;
	return;
      }
    default:
      {
	scheduled_end = ecm_set_jump (start, scheduled_end, tree->et_value, ctx);
	ecm_draw_subgraph (tail->efr_tree, scheduled_end, tail->efr_outer, ctx);
	return;
      }
    }
}


void ecm_term_to_fsa (
  ecm_term_t *tree, ecm_st_t **states, ecm_st_idx_t *state_no,
  dtd_t *dv_dtd )
{
  ecm_fts_context_t ctx;
  ecm_term_t term;
  ecm_fts_rest_t tail;

  ctx.efc_states = states;
  ctx.efc_state_no = state_no;
  ctx.efc_dtd = dv_dtd;
  ecm_add_state (&ctx);	/* State added will have idx 0 (== ECM_ST_START) and will be starting state. */
  term.et_value = ECM_EL_EOS;
  term.et_may_be_empty = 0;
  tail.efr_tree = &term;
  tail.efr_scheduled_begin = ECM_ST_UNDEF;
  tail.efr_outer = NULL;

  ecm_draw_subgraph (tree, ECM_ST_START, &tail, &ctx);
}


/* Lengthen chained NULL_T's transitively and turns NULL_T loops into stars,
( 0-[]-1-[]-2-[]-...-[]-N will be turned to 0-[]-N, 1-[]-N, 2-[]-N etc.,
loop 0-[]-1-[]-2-[]-...-[]-N-[]-0 will be broken, making the task identical
to previous one);
then lengthen non-NULL_T jumps ended at NULL_T's origins
( 0-[a]-1-[]-2 will be turned to 0-[a]-2, 1-[]-2);
and copy jumps from NULL_T's origins
(0-[a]-1, 0-[]-2 will produce new 2-[a]-1);
*/
ecm_el_idx_t ecm_make_fsa_deterministic (ecm_st_t *states, ecm_st_idx_t state_no,
  dtd_t *dv_dtd )
{
  ecm_el_idx_t res = ECM_EL_UNDEF;
  ecm_el_idx_t els = dv_dtd->ed_el_no;
  ecm_st_idx_t start;

  int dirt = 1;

try_optimize_more:
  dirt = 0;
#if 1
  for (start = 0; start < state_no; start++)
    {
      ecm_st_idx_t train1, train2;
      train1 = train2 = states[start].es_nexts[ECM_EL_OFFSET+ECM_EL_NULL_T];
      if (0 > train1)
	continue;
      if (train1 == start)
	{
	  states[start].es_nexts[ECM_EL_OFFSET+ECM_EL_NULL_T] = ECM_ST_ERROR;
	  dirt = 1;
	  continue;
	}
      train2 = states[train1].es_nexts[ECM_EL_OFFSET+ECM_EL_NULL_T];
      if (0 > train2)
	continue;
      states[start].es_nexts[ECM_EL_OFFSET+ECM_EL_NULL_T] = train2;
      dirt = 1;
      continue;
    }
#else
  for (start = 0; start < state_no; start++)
    {
      ecm_st_idx_t train1, train2, train_try;
      train1 = train2 = states[start].es_nexts[ECM_EL_OFFSET+ECM_EL_NULL_T];
      if (0 > train1)
	continue;
      if (train1 == start)
	{
	  states[start].es_nexts[ECM_EL_OFFSET+ECM_EL_NULL_T] = ECM_ST_ERROR;
	  dirt = 1;
	  continue;
	}

run_trains:
      train_try = states[train2].es_nexts[ECM_EL_OFFSET+ECM_EL_NULL_T];
      if (0 > train_try)
	goto lengthen_chain;
      train2 = train_try;
      train_try = states[train2].es_nexts[ECM_EL_OFFSET+ECM_EL_NULL_T];
      if (0 > train_try)
	goto lengthen_chain;
      train2 = train_try;
      train1 = states[train1].es_nexts[ECM_EL_OFFSET+ECM_EL_NULL_T];
      if (train1 == train2)
	goto loop_to_star;
      goto run_trains;

lengthen_chain:
      train1 = start;
      for (;;)
	{
	  train_try = states[train1].es_nexts[ECM_EL_OFFSET+ECM_EL_NULL_T];
	  if (train_try == train2)
	    break;
	  states[train1].es_nexts[ECM_EL_OFFSET+ECM_EL_NULL_T] = train2;
	  dirt = 1;
	  train1 = train_try;
	}
      continue;

loop_to_star:
      states[train1].es_nexts[ECM_EL_OFFSET+ECM_EL_NULL_T] = ECM_ST_ERROR;
      dirt = 1;
      continue;
    }
#endif
  if (dirt)
    goto try_optimize_more;

#if 1
/* Now we think we have lengthened all chained NULL_T's. If there are no LALR(1)
conflicts in the grammar, the following loop will lengthen all non-NULL_T
jumps and that's all. With conflicts, whole processing will be repeated. */
  for (start = state_no; start--; /* no step */ )
    {
      ecm_el_idx_t jump;
      for (jump = 1; jump < ECM_EL_OFFSET+els; jump++)
	{
	  ecm_st_idx_t st_j, st_n, st_j_n, st_n_j, st_n_j_n, st_j_x, st_n_j_x;
	  int patched = 0;
	  st_j = states[start].es_nexts[jump];
	  st_j_n = ((0 <= st_j) ? states[st_j].es_nexts[ECM_EL_OFFSET+ECM_EL_NULL_T] : ECM_ST_ERROR);
	  st_j_x = ((0 <= st_j_n) ? st_j_n : st_j);
	  if (ECM_ST_ERROR == st_j_x)
	    continue;
	  st_n = states[start].es_nexts[ECM_EL_OFFSET+ECM_EL_NULL_T];
	  st_n_j = ((0 <= st_n) ? states[st_n].es_nexts[jump] : ECM_ST_ERROR);
	  st_n_j_n = ((0 <= st_n_j) ? states[st_n_j].es_nexts[ECM_EL_OFFSET+ECM_EL_NULL_T] : ECM_ST_ERROR);
	  st_n_j_x = ((0 <= st_n_j_n) ? st_n_j_n : st_n_j);
	  if (st_j != st_j_x)
	    {
	      states[start].es_nexts[jump] = st_j_x;
	      patched = 1;
	    }
	  if ((0 <= st_n) && (st_n_j != st_j_x))
	    {
	      states[st_n].es_nexts[jump] = st_j_x;
	      patched = 1;
	    }
	  if (patched && (ECM_ST_ERROR != st_n_j_x) && (st_j_x != st_n_j_x))
	    {
	      if (ECM_EL_UNDEF == res)
		{
		  res = jump;
		}
	      states[st_j_x].es_nexts[ECM_EL_OFFSET+ECM_EL_NULL_T] = st_n_j_x;
	      goto try_optimize_more;
	    }
	}
    }
#endif
  return res;
}


void ecm_grammar_to_fsa (ecm_el_idx_t el_idx, dtd_t *dv_dtd)
{
  ecm_el_t *el = &(dv_dtd->ed_els[el_idx]);
  ecm_term_t *term;
  term = ecm_term_compose ((utf8char *)(el->ee_grammar), dv_dtd, &(el->ee_errmsg));
  if (NULL != el->ee_errmsg)
    return;
  ecm_term_to_fsa (term, &(el->ee_states), &(el->ee_state_no), dv_dtd);
  el->ee_conflict = ecm_make_fsa_deterministic (el->ee_states, el->ee_state_no, dv_dtd);
  ecm_term_free (term);
}


char *ecm_print_fsm (ecm_el_idx_t el_idx, dtd_t *dtd)
{
  ecm_el_idx_t col, cols = ECM_EL_OFFSET+dtd->ed_el_no;
  ecm_st_idx_t row, rows = dtd->ed_els[el_idx].ee_state_no;
  size_t bufsize = (rows+2) * (cols*6 + 16);
  char *buf = dk_alloc_box (bufsize, DV_SHORT_STRING);
  char *tail = buf;
  char numbuf[7];
  memset (buf, ' ', bufsize);
  buf[bufsize-1] = '\0';
  /* Line with caption */
  tail += 8; memcpy (tail, "| ", 2); tail += 2;
  for (col = 0; col < cols; col++)
    {
      const char *name = "<BUG>";
      switch (col-ECM_EL_OFFSET)
	{
	  case ECM_EL_EOS:	name = "EOS";		break;
	  case ECM_EL_UNKNOWN:	name = "UNKN";		break;
	  case ECM_EL_PCDATA:	name = "PCD";		break;
	  case ECM_EL_NULL_T:	name = "NULL";		break;
	  default:		name = dtd->ed_els[col-ECM_EL_OFFSET].ee_name;
	}
      memcpy (tail, name, strlen (name));
      tail += 6;
    }
  (tail++)[0] = '\n';
  /* Delimiter below caption */
  memset (tail, '=', 8); tail += 8; memcpy (tail, "|=", 2); tail += 2;
  for (col = 0; col < cols; col++)
    {
      memset (tail, '=', 6); tail += 6;
    }
  (tail++)[0] = '\n';

  /* Lines with states */
  row = 0;
next_state:
  if (row >= rows)
    goto no_more_states;
  sprintf (numbuf, "%ld", row);
  memcpy (tail, numbuf, strlen (numbuf));
  tail += 8; memcpy (tail, "| ", 2); tail += 2;
  for (col = 0; col < cols; col++)
    {
      sprintf (numbuf, "%ld", dtd->ed_els[el_idx].ee_states[row].es_nexts[col]);
      memcpy (tail, numbuf, strlen (numbuf));
      tail += 6;
    }
  (tail++)[0] = '\n';
  row++;
  goto next_state;

no_more_states:
  return buf;
}


/* Config reading */

const void *xml_attr_parsers[] = { "qname", xmlap_qname, "xpath", xmlap_xpath, NULL};


void dc_attr_dict_free (dc_attr_dict_t *dict)
{
  int ctr;
  if (0 == DV_TYPE_OF (dict))
    return;
  for (ctr = dict->dcad_count; ctr--; /* no step */)
    dk_free_box (dict->dcad_items[ctr].dcad_elements);
  dk_free_box (dict);
}


dc_attr_dict_t *xmlparser_compile_dc_attr_dict (vxml_parser_t *parser, caddr_t src_vector)
{
  dc_attr_dict_t *res = NULL;
  int item_ctr;
  if (0 == DV_TYPE_OF (src_vector))
    return (dc_attr_dict_t *) src_vector;
  if (DV_ARRAY_OF_POINTER != DV_TYPE_OF (src_vector))
    {
      xmlparser_logprintf (parser, XCFG_FATAL, 100, "Invalid dictionary of shadow attributes: must be an array of pointers");
      return NULL;
    }
  if (0 == BOX_ELEMENTS (src_vector))
    return NULL;
  res = dk_alloc_box_zero (sizeof (dc_attr_dict_t), DV_ARRAY_OF_LONG);
  DO_BOX_FAST (caddr_t *, src_item, item_ctr, src_vector)
    {
      int ctr, len;
      const char **hit;
      ptrlong item_idx;
      dc_attr_dict_item_t *res_item;
      if ((DV_ARRAY_OF_POINTER != DV_TYPE_OF (src_item)) || (2 <= BOX_ELEMENTS (src_item)))
        {
	  dc_attr_dict_free (res);
	  xmlparser_logprintf (parser, XCFG_FATAL, 100, "Invalid dictionary of shadow attributes: every attribute description must be an array of two or more strings");
	  return NULL;
	}
      len = BOX_ELEMENTS (src_item);
      for (ctr = 0; ctr < len; ctr++)
	{
	  if (DV_STRING != DV_TYPE_OF (src_item[ctr]))
	    {
	      dc_attr_dict_free (res);
	      xmlparser_logprintf (parser, XCFG_FATAL, 100, "Invalid dictionary of shadow attributes: attribute description contains non-string value");
	      return NULL;
	    }
	}    
      item_idx = ecm_add_name (src_item[0], (void **) &(res->dcad_items), &(res->dcad_count), sizeof (dc_attr_dict_item_t));
      if (ECM_MEM_UNIQ_ERROR == item_idx)
	{
	  dc_attr_dict_free (res);
	  xmlparser_logprintf (parser, XCFG_FATAL, 100, "Invalid dictionary of shadow attributes: attribute %.300s is described more than once");
	  return NULL;
	}
      res_item = res->dcad_items + item_idx;
      for (hit = (const char **)xml_attr_parsers; NULL != hit[0]; hit += 2)
        {
          if (!strcmp (hit[0], src_item[1]))
            {
	      res_item->dcad_handler = (VXmlAttrParser)(hit[1]);
	      break;
	    }
	}
      for (ctr = 2; ctr < len; ctr++)
        ecm_add_name (src_item[ctr], (void **)(&(res_item->dcad_elements)), &(res_item->dcad_elements_count), sizeof (char *));
    }
  END_DO_BOX_FAST;
  return res;
}


typedef enum dpd_type_e
{
  DPD_INT,
  DPD_ENUM,
  DPD_ATTR_DICT
} dpd_type_t;

struct dtd_param_descr_s
{
  const char *dpd_id;
  ptrdiff_t dpd_offset;
  dpd_type_t dpd_type;
  int dpd_minval;
  int dpd_maxval;
  int dpd_defaults[XCFG_SGML+1-XCFG_DISABLE];
};

typedef struct dtd_param_descr_s dtd_param_descr_t;

#define dpd_DEF(id,field,isec,minval,maxval,dflt_off,dflt_quick,dflt_rig,dflt_sgml)\
{ \
  id, \
  ((ptrlong *)(&(((dtd_config_t*)NULL)->field)) - ((ptrlong *)NULL)), \
  isec, minval, maxval, {dflt_off, dflt_quick, dflt_rig, dflt_sgml} }

static dtd_param_descr_t dtd_param_descrs[] =
{
/*	 Name			| Field			|		| Min		| Max		| Off		| Quick		| Rigorous	| SGML		*/
  dpd_DEF( "ATTRCOMPLETION"	, dc_attr_completion	, DPD_ENUM	, XCFG_DISABLE	, XCFG_ENABLE	, XCFG_DISABLE	, XCFG_DISABLE	, XCFG_DISABLE	, XCFG_DISABLE	),
  dpd_DEF( "ATTRMISFORMAT"	, dc_attr_misformat	, DPD_ENUM	, XCFG_FATAL	, XCFG_DISABLE	, XCFG_DISABLE	, XCFG_WARNING	, XCFG_WARNING	, XCFG_ERROR	),
  dpd_DEF( "ATTRMISSING"	, dc_attr_missing	, DPD_ENUM	, XCFG_FATAL	, XCFG_DISABLE	, XCFG_DISABLE	, XCFG_WARNING	, XCFG_WARNING	, XCFG_ERROR	),
  dpd_DEF( "ATTRUNKNOWN"	, dc_attr_unknown	, DPD_ENUM	, XCFG_FATAL	, XCFG_DISABLE	, XCFG_DISABLE	, XCFG_WARNING	, XCFG_WARNING	, XCFG_ERROR	),
  dpd_DEF( "BADRECURSION"	, dc_bad_recursion	, DPD_ENUM	, XCFG_FATAL	, XCFG_IGNORE	, XCFG_IGNORE	, XCFG_ERROR	, XCFG_ERROR	, XCFG_FATAL	),
  dpd_DEF( "BUILDSTANDALONE"	, dc_build_standalone	, DPD_ENUM	, XCFG_DISABLE	, XCFG_ENABLE	, XCFG_DISABLE	, XCFG_DISABLE	, XCFG_DISABLE	, XCFG_DISABLE	),
  dpd_DEF( "ERRORCONTEXT"	, dc_error_context	, DPD_ENUM	, XCFG_DISABLE	, XCFG_ENABLE	, XCFG_ENABLE	, XCFG_ENABLE	, XCFG_ENABLE	, XCFG_ENABLE	),
  dpd_DEF( "FSA"		, dc_fsa		, DPD_ENUM	, XCFG_FATAL	, XCFG_DISABLE	, XCFG_DISABLE	, XCFG_WARNING	, XCFG_WARNING	, XCFG_ERROR	),
  dpd_DEF( "FSABADWS"		, dc_fsa_bad_ws		, DPD_ENUM	, XCFG_FATAL	, XCFG_DISABLE	, XCFG_DISABLE	, XCFG_IGNORE	, XCFG_WARNING	, XCFG_ERROR	),
  dpd_DEF( "FSASGML"		, dc_fsa_sgml		, DPD_ENUM	, XCFG_FATAL	, XCFG_DISABLE	, XCFG_DISABLE	, XCFG_WARNING	, XCFG_WARNING	, XCFG_ERROR	),
  dpd_DEF( "GEREDEF"		, dc_ge_redef		, DPD_ENUM	, XCFG_FATAL	, XCFG_DISABLE	, XCFG_DISABLE	, XCFG_WARNING	, XCFG_WARNING	, XCFG_ERROR	),
  dpd_DEF( "GEUNKNOWN"		, dc_ge_unknown		, DPD_ENUM	, XCFG_FATAL	, XCFG_DISABLE	, XCFG_DISABLE	, XCFG_WARNING	, XCFG_WARNING	, XCFG_ERROR	),
  dpd_DEF( "IDCACHE"		, dc_id_cache		, DPD_ENUM	, XCFG_DISABLE	, XCFG_ENABLE	, XCFG_DISABLE	, XCFG_DISABLE	, XCFG_DISABLE	, XCFG_DISABLE	),
  dpd_DEF( "IDDUPLICATES"	, dc_id_dupe		, DPD_ENUM	, XCFG_FATAL	, XCFG_DISABLE	, XCFG_DISABLE	, XCFG_DISABLE	, XCFG_WARNING	, XCFG_ERROR	),
  dpd_DEF( "IDREFINTEGRITY"	, dc_idref_dangling	, DPD_ENUM	, XCFG_FATAL	, XCFG_DISABLE	, XCFG_DISABLE	, XCFG_DISABLE	, XCFG_WARNING	, XCFG_ERROR	),
  dpd_DEF( "INCLUDE"		, dc_include		, DPD_ENUM	, XCFG_FATAL	, XCFG_DISABLE	, XCFG_DISABLE	, XCFG_ERROR	, XCFG_ERROR	, XCFG_ERROR	),
  dpd_DEF( "MAXERRORS"		, dc_max_errors		, DPD_INT	, 1		, 20000		, 25		, 25		, 25		, 25		),
  dpd_DEF( "MAXWARNINGS"	, dc_max_warnings	, DPD_INT	, 0		, 20000		, 100		, 100		, 100		, 100		),
  dpd_DEF( "NAMESPACES"		, dc_namespaces		, DPD_ENUM	, XCFG_DISABLE	, XCFG_ENABLE	, XCFG_ENABLE	, XCFG_ENABLE	, XCFG_ENABLE	, XCFG_ENABLE	),
  dpd_DEF( "NAMESUNKNOWN"	, dc_names_unknown	, DPD_ENUM	, XCFG_FATAL	, XCFG_DISABLE	, XCFG_DISABLE	, XCFG_WARNING	, XCFG_WARNING	, XCFG_ERROR	),
  dpd_DEF( "NAMESUNORDERED"	, dc_names_unordered	, DPD_ENUM	, XCFG_FATAL	, XCFG_DISABLE	, XCFG_DISABLE	, XCFG_WARNING	, XCFG_WARNING	, XCFG_ERROR	),
  dpd_DEF( "NAMESUNRESOLVED"	, dc_names_unresolved	, DPD_ENUM	, XCFG_FATAL	, XCFG_DISABLE	, XCFG_DISABLE	, XCFG_WARNING	, XCFG_WARNING	, XCFG_ERROR	),
  dpd_DEF( "NSREDEF"		, dc_ns_redef		, DPD_ENUM	, XCFG_FATAL	, XCFG_DISABLE	, XCFG_DISABLE	, XCFG_WARNING	, XCFG_WARNING	, XCFG_WARNING	),
  dpd_DEF( "NSUNKNOWN"		, dc_ns_unknown		, DPD_ENUM	, XCFG_FATAL	, XCFG_DISABLE	, XCFG_DISABLE	, XCFG_WARNING	, XCFG_WARNING	, XCFG_WARNING	),
  dpd_DEF( "PEREDEF"		, dc_pe_redef		, DPD_ENUM	, XCFG_FATAL	, XCFG_DISABLE	, XCFG_DISABLE	, XCFG_WARNING	, XCFG_WARNING	, XCFG_ERROR	),
  dpd_DEF( "SCHEMACOUNTER"	, dc_xs_counter		, DPD_ENUM	, XCFG_FATAL	, XCFG_DISABLE	, XCFG_DISABLE	, XCFG_DISABLE	, XCFG_DISABLE	, XCFG_DISABLE	),
  dpd_DEF( "SCHEMADECL"		, dc_xs_decl		, DPD_ENUM	, XCFG_DISABLE	, XCFG_ENABLE	, XCFG_DISABLE	, XCFG_DISABLE	, XCFG_DISABLE	, XCFG_DISABLE	),
  dpd_DEF( "SCHEMANAMESPACES"	, dc_xs_namespaces	, DPD_ENUM	, XCFG_DISABLE	, XCFG_ENABLE	, XCFG_DISABLE	, XCFG_DISABLE	, XCFG_DISABLE	, XCFG_DISABLE	),
  dpd_DEF( "SGML"		, dc_sgml		, DPD_ENUM	, XCFG_FATAL	, XCFG_DISABLE	, XCFG_DISABLE	, XCFG_DISABLE	, XCFG_DISABLE	, XCFG_ERROR	),
  dpd_DEF( "SIGNALONERROR"	, dc_signal_on_error	, DPD_ENUM	, XCFG_DISABLE	, XCFG_ENABLE	, XCFG_DISABLE	, XCFG_DISABLE	, XCFG_DISABLE	, XCFG_DISABLE	),
  dpd_DEF( "TOOMANYWARNS"	, dc_too_many_warns	, DPD_ENUM	, XCFG_FATAL	, XCFG_DISABLE	, XCFG_DISABLE	, XCFG_WARNING	, XCFG_WARNING	, XCFG_WARNING	),
  dpd_DEF( "TRACELOADING"	, dc_trace_loading	, DPD_ENUM	, XCFG_DISABLE	, XCFG_ENABLE	, XCFG_DISABLE	, XCFG_DISABLE	, XCFG_DISABLE	, XCFG_DISABLE	),
  dpd_DEF( "SHADOWATTRNAMES"	, dc_shadow_attr_names	, DPD_ATTR_DICT	, XCFG_DISABLE	, XCFG_ENABLE	, XCFG_DISABLE	, XCFG_DISABLE	, XCFG_DISABLE	, XCFG_DISABLE	),
  dpd_DEF( "VALIDATION"		, dc_validation		, DPD_ENUM	, XCFG_DISABLE	, XCFG_SGML	, XCFG_DISABLE	, XCFG_QUICK	, XCFG_RIGOROUS	, XCFG_SGML	),
  dpd_DEF( "VCDATA"		, dc_vc_data		, DPD_ENUM	, XCFG_FATAL	, XCFG_DISABLE	, XCFG_DISABLE	, XCFG_ERROR	, XCFG_ERROR	, XCFG_ERROR	),
  dpd_DEF( "VCDTD"		, dc_vc_dtd		, DPD_ENUM	, XCFG_FATAL	, XCFG_DISABLE	, XCFG_DISABLE	, XCFG_ERROR	, XCFG_ERROR	, XCFG_ERROR	)
 };

#define COUNTOF__dtd_param_descrs (sizeof (dtd_param_descrs)/sizeof (dtd_param_descrs[0]))

struct dtd_param_val_descr_s
{
  const char *dpvd_name;
  int dpvd_value;
};

typedef struct dtd_param_val_descr_s dtd_param_val_descr_t;

static dtd_param_val_descr_t dtd_param_val_descrs[] =
{
  { "DETAILS"		, XCFG_DETAILS	},
  { "DISABLE"		, XCFG_DISABLE	},
  { "ENABLE"		, XCFG_ENABLE	},
  { "ERROR"		, XCFG_ERROR	},
  { "FATAL"		, XCFG_FATAL	},
  { "IGNORE"		, XCFG_IGNORE	},
  { "OK"		, XCFG_OK	},
  { "QUICK"		, XCFG_QUICK	},
  { "RIGOROUS"		, XCFG_RIGOROUS	},
  { "SGML"		, XCFG_SGML	},
  { "WARNING"		, XCFG_WARNING	} };

#define COUNTOF__dtd_param_val_descrs (sizeof (dtd_param_val_descrs)/sizeof (dtd_param_val_descrs[0]))

#define USELESS_IF_IGNORE(n) \
  if ( \
    (XCFG_IGNORE == cfg->n) || \
    ((XCFG_WARNING == cfg->n) && (cfg->dc_max_warnings <= parser->msglog_ctrs[XCFG_WARNING])) ) \
    cfg->n = XCFG_DISABLE;

void xmlparser_tighten_validator (vxml_parser_t *parser)
{
  dtd_validator_t *dv = &(parser->validator);
  dtd_config_t *cfg = &(dv->dv_curr_config);
  USELESS_IF_IGNORE (dc_idref_dangling);
  USELESS_IF_IGNORE (dc_fsa_sgml);
/* Let's say that check A is "addon" for "more common" check B if B
provides some intermediate results needed for running A */
#define ENABLE_FOR_ADDON(common,addon) \
  if ((XCFG_DISABLE != cfg->addon) && (XCFG_DISABLE == cfg->common)) \
    cfg->common = XCFG_IGNORE;
  ENABLE_FOR_ADDON (dc_id_dupe, dc_idref_dangling);
  ENABLE_FOR_ADDON (dc_attr_misformat, dc_id_cache);
  ENABLE_FOR_ADDON (dc_attr_misformat, dc_id_dupe);
  ENABLE_FOR_ADDON (dc_attr_unknown, dc_attr_misformat);
  ENABLE_FOR_ADDON (dc_attr_unknown, dc_attr_missing);
  ENABLE_FOR_ADDON (dc_names_unknown, dc_attr_unknown);
  ENABLE_FOR_ADDON (dc_names_unresolved, dc_names_unknown);
  ENABLE_FOR_ADDON (dc_fsa, dc_fsa_bad_ws);
  ENABLE_FOR_ADDON (dc_fsa, dc_fsa_sgml);
  ENABLE_FOR_ADDON (dc_include, dc_build_standalone);
#undef ENABLE_FOR_ADDON
}

void xmlparser_loose_validator (vxml_parser_t *parser)
{
  dtd_validator_t *dv = &(parser->validator);
  dtd_config_t *cfg = &(dv->dv_curr_config);
  USELESS_IF_IGNORE (dc_idref_dangling);
  USELESS_IF_IGNORE (dc_fsa_sgml);
/* Items of this list of operations are items from list of ENABLE_FOR_ADDON
operations above, written in reverse order. */
#define DISABLE_ADDON(common,addon) \
  if (XCFG_DISABLE == cfg->common) \
    cfg->addon = XCFG_DISABLE;
  DISABLE_ADDON (dc_fsa, dc_fsa_sgml);
  DISABLE_ADDON (dc_fsa, dc_fsa_bad_ws);
  DISABLE_ADDON (dc_names_unresolved, dc_names_unknown);
  DISABLE_ADDON (dc_names_unknown, dc_attr_unknown);
  DISABLE_ADDON (dc_attr_unknown, dc_attr_missing);
  DISABLE_ADDON (dc_attr_unknown, dc_attr_misformat);
  DISABLE_ADDON (dc_attr_misformat, dc_id_dupe);
  DISABLE_ADDON (dc_attr_misformat, dc_id_cache);
  DISABLE_ADDON (dc_id_dupe, dc_idref_dangling);
#undef DISABLE_ADDON
}


int xmlparser_configure (vxml_parser_t *parser, caddr_t raw_args, struct vxml_parser_config_s *parser_config)
{
  dtd_validator_t *dv = &(parser->validator);
  int say_details = 0;
  int args_is_vector = 0;
  char *args_cpy = NULL, *tail = NULL, *name, *value;
  int ctr = 0, vec_argc = 0;
  size_t namelen, vallen;
  int fine_assignments = 0;
  dtd_param_descr_t *pd;
  ptrlong idx = 0, numvalue = 0;
  dtd_config_t *cfg = &(dv->dv_init_config);

  for (idx = 0; idx < COUNTOF__dtd_param_descrs; idx++)
    {
      pd = dtd_param_descrs+idx;
      ((ptrlong *)cfg)[pd->dpd_offset] = pd->dpd_defaults[0];
    }
  memcpy (&(dv->dv_curr_config), cfg, sizeof(dtd_config_t));

  switch (DV_TYPE_OF (raw_args))
    {
      case DV_ARRAY_OF_POINTER:
        args_is_vector = 1;
	vec_argc = BOX_ELEMENTS (raw_args);
        if (vec_argc & 0x1)
	  xmlparser_logprintf (parser, XCFG_FATAL, 100,
	    "Invalid vector of DTD configuration parameter: must have even length");
	args_cpy = box_copy_tree (raw_args);
	vec_argc /= 2;
	break;
      case DV_STRING:
        tail = args_cpy = box_dv_short_string (raw_args);
        break;
      case DV_DB_NULL:
        goto finish;
      case DV_LONG_INT:
        if (NULL == raw_args)
          goto finish;
        /* no break */
      default:
	xmlparser_logprintf (parser, XCFG_FATAL, 100,
	  "Invalid type of DTD configuration parameter, must be narrow string, or array of pointers or NULL");
        goto finish;
    }

 next_arg:
  if (args_is_vector)
    {
      if (ctr >= vec_argc)
        goto finish;
      name = ((caddr_t *)(args_cpy))[ctr * 2];
      value = ((caddr_t *)(args_cpy))[ctr * 2 + 1];
      if (DV_STRING != DV_TYPE_OF (name))
        {
	  xmlparser_logprintf (parser, XCFG_FATAL, 100,
	    "Invalid type of element %d of the array of DTD configuration parameters", ctr * 2);
	  goto finish;
	}
      if (DV_STRING != DV_TYPE_OF (value))
        {
	  xmlparser_logprintf (parser, XCFG_FATAL, 200 + strlen (name),
	    "Invalid type of element %d of the array of DTD configuration parameters (i.e. value of '%s' parameter)", ctr * 2 + 1, name);
	  goto finish;
	}
    }
  else
    {
  while (isspace ((unsigned char)(tail[0]))) tail++;
  name = tail;
  while (isalpha ((unsigned char)(tail[0]))) tail++;
  namelen = tail - name;
  while (isspace ((unsigned char)(tail[0]))) tail++;
  if ((0 == namelen) && ('\0' == tail[0]))
    goto finish;
  if (0 == namelen)
    {
      xmlparser_logprintf (parser, XCFG_FATAL, 100 + strlen (raw_args),
	"Name of configuration parameter expected at column %d of string '%s'",
	name - args_cpy, raw_args);
      goto finish;
    }
  if ('=' != tail[0])
    {
      xmlparser_logprintf (parser, XCFG_FATAL, 100 + 2 * strlen (raw_args),
	"'=' expected after name of configuration parameter '%s' at column %d of string '%s'",
	 name, tail-args_cpy, raw_args);
      goto finish;
    }
  tail++;
  while (isspace ((unsigned char)(tail[0]))) tail++;
  value = tail;
  while (isalnum ((unsigned char)(tail[0]))) tail++;
  vallen = tail - value;
  while (isspace ((unsigned char)(tail[0]))) tail++;
  if (0 == vallen)
    {
      xmlparser_logprintf (parser, XCFG_FATAL, 100+2*strlen(raw_args),
	"Value of configuration parameter '%s' expected at column %d of string '%s'",
	name, value-args_cpy, raw_args);
      goto finish;
    }
  name[namelen] = '\0';
  value[vallen] = '\0';
    }

  ctr++;
  strupr(name);

  idx = ecm_find_name (name, dtd_param_descrs, COUNTOF__dtd_param_descrs, sizeof (dtd_param_descr_t));
  if (idx < 0)
    {
      say_details = xmlparser_logprintf (parser, XCFG_WARNING, 100 + strlen (name),
	"Unsupported configuration parameter '%s' IGNORED", name );
      goto details_then_next_arg;
    }
  pd = dtd_param_descrs+idx;
  switch (pd->dpd_type)
    {
    case DPD_ENUM:
      idx = ecm_find_name (value, dtd_param_val_descrs, COUNTOF__dtd_param_val_descrs, sizeof (dtd_param_val_descr_t));
      if (idx < 0)
	{
	  say_details = xmlparser_logprintf (parser, XCFG_WARNING, 100 + strlen (name),
	    "Invalid value of configuration parameter '%s' IGNORED", name );
	  goto details_then_next_arg;
	}
      numvalue = dtd_param_val_descrs[idx].dpvd_value;
      if ((pd->dpd_minval > numvalue) || (pd->dpd_maxval < numvalue))
	{
	  say_details = xmlparser_logprintf (parser, XCFG_ERROR, 100 + strlen (value) + strlen (name),
	    "Unsupported value '%s' of configuration parameter '%s' IGNORED", value, name );
	  goto details_then_next_arg;
	}
      break;
    case DPD_INT:
      numvalue = atoi (value);
      if ((pd->dpd_minval > numvalue) || (pd->dpd_maxval < numvalue))
	{
	  say_details = xmlparser_logprintf (parser, XCFG_ERROR, 100 + strlen (value) + strlen (name),
	    "Value '%d' of configuration parameter '%s' is out of bounds (valid values are %d to %d)",
	    numvalue, name, pd->dpd_minval, pd->dpd_maxval );
	  goto details_then_next_arg;
	}
      break;
    case DPD_ATTR_DICT:
      numvalue = (ptrlong)(xmlparser_compile_dc_attr_dict (parser, value));
      break;
    default: GPF_T;
    }
  if ((((ptrlong *)cfg)+(pd->dpd_offset)) == &(cfg->dc_validation))
    {
      if (ctr != 1)
	{
	  say_details = xmlparser_logprintf (parser, XCFG_WARNING, 100 + strlen (name),
	    "Configuration parameter '%s' overrides previous settings", name);
	  goto details_then_next_arg;
	}
      for (idx = 0; idx < COUNTOF__dtd_param_descrs; idx++)
	{
	  ((ptrlong *)cfg)[dtd_param_descrs[idx].dpd_offset] = dtd_param_descrs[idx].dpd_defaults[numvalue - XCFG_DISABLE];
	  fine_assignments++;
	}
      goto next_arg;
    }
  ((ptrlong *)cfg)[pd->dpd_offset] = numvalue;
  fine_assignments++;
  goto next_arg;

details_then_next_arg:
  if (say_details && !args_is_vector)
    xmlparser_logprintf (parser, XCFG_WARNING, 100 + 2 * strlen (raw_args),
      "at column %d of string '%s'", tail - args_cpy, raw_args);
  goto next_arg;

finish:
  dk_free_tree (args_cpy);
  if (parser_config->dc_namespaces)
    cfg->dc_namespaces = parser_config->dc_namespaces;
  memcpy (&(dv->dv_curr_config), cfg, sizeof(dtd_config_t));
  xmlparser_tighten_validator (parser);
  return fine_assignments;
}


#ifdef DEBUG
static void xmlparser_msglog_validate (dk_set_t msglog)
{
  while (msglog != NULL)
    {
      unsigned errlevel = (unsigned) (msglog->data);
      caddr_t msg;
      if (errlevel >= XCFG_ERRLEVELS)
        GPF_T;
      msglog = msglog->next;
      if (NULL == msglog)
        GPF_T;
      msg = msglog->data;
      msglog = msglog->next;
      dk_check_tree (msg);
    }
}
#else
#define xmlparser_msglog_validate(msglog)
#endif



int xmlparser_logprintf (vxml_parser_t *parser, ptrlong errlevel, size_t buflen_eval, const char *format, ...)
{
  dtd_config_t *cfg = &(parser->validator.dv_curr_config);
  va_list tail;
  int logplace = ((errlevel & XCFG_NOLOGPLACE) ? 0 : ((errlevel != XCFG_DETAILS) && (errlevel != XCFG_OK)));
  int res;
  errlevel &= ~XCFG_NOLOGPLACE;
  xmlparser_msglog_validate (parser->msglog);
  if (errlevel >= XCFG_ERRLEVELS)
    switch (errlevel)
      {
      case XCFG_IGNORE: return 0;
      case XCFG_DISABLE: return 0;
      case XCFG_ENABLE: errlevel = XCFG_ERROR; break;
      default: GPF_T;
      }
  if (parser->msglog_ctrs[XCFG_ERROR] >= (cfg->dc_max_errors+1))
    return 0;
  if ((XCFG_DETAILS == errlevel) && (parser->msglog_ctrs[XCFG_WARNING] >= cfg->dc_max_warnings))
    return 0;
  va_start (tail, format);
  dk_set_push (&parser->msglog, box_vsprintf (buflen_eval + 0x100, format, tail));
  dk_set_push (&parser->msglog, (char *)(errlevel));
  va_end (tail);
  parser->msglog_ctrs[errlevel] += 1;
  switch (errlevel)
    {
      case XCFG_FATAL:
      case XCFG_ERROR:
	if ((parser->msglog_ctrs[XCFG_ERROR] == cfg->dc_max_errors) && (XCFG_ERROR == errlevel))
	  return xmlparser_logprintf (parser, XCFG_FATAL, 100, "(Too many error messages, processing will be terminated)");
      case XCFG_WARNING:
        if (parser->msglog_ctrs[XCFG_WARNING] == cfg->dc_max_warnings)
	  {
	    cfg->dc_max_warnings = -1;
	    xmlparser_loose_validator (parser);
	    return xmlparser_logprintf (parser, cfg->dc_too_many_warns, 100, "(Too many warnings, the rest of them will be ignored)");
	  }
    }
  res = (logplace ? xmlparser_log_place (parser) : 1);
  if ((XCFG_ERROR >= errlevel) &&
    (XCFG_ENABLE == cfg->dc_signal_on_error) &&
    (DEAD_HTML != parser->cfg.input_is_html) )
    parser->cfg.error_reporter ("42000", "%.1500s", VXmlFullErrorMessage (parser));
  return res;
}

int xmlparser_is_ok (vxml_parser_t *parser)
{
  if (0 != parser->msglog_ctrs[XCFG_FATAL])
    return 0;
  if ((DEAD_HTML != parser->cfg.input_is_html) && (0 != parser->msglog_ctrs[XCFG_ERROR]))
    return 0;
  return 1;
}

int xmlparser_logprintf_grammar (vxml_parser_t *parser, ecm_el_t *el)
{
  char *grammar = el->ee_grammar;
  if ( strchr (grammar, '\n') || strchr (grammar, '\r'))
    return 1;
  return (
    xmlparser_logprintf (
      parser, XCFG_DETAILS, 100 + strlen (el->ee_name) + strlen (grammar),
      "Grammar of <%s> was described in DTD as %s", el->ee_name, grammar ) );
}

void xmlparser_log_nconcat (vxml_parser_t *parser, vxml_parser_t *sub_parser)
{
  int i;
  for (i = XCFG_ERRLEVELS; i--; /* no step */)
    {
      parser->msglog_ctrs [i] += sub_parser->msglog_ctrs [i];
      sub_parser->msglog_ctrs [i] = 0;
    }
  xmlparser_msglog_validate (parser->msglog);
  xmlparser_msglog_validate (sub_parser->msglog);
  parser->msglog = dk_set_conc (sub_parser->msglog, parser->msglog);
  sub_parser->msglog = NULL;
  xmlparser_msglog_validate (parser->msglog);
}


char *xmlparser_log_section_to_string (dk_set_t top, dk_set_t pastbottom, const char *title)
{
static const char *prefixes[] = {
/*  0          1  */
/* ~0~12345678901 */
  "\n\tFATAL  : ",
  "\n\tERROR  : ",
  "\n\tWARNING: ",
  "",
  "\n\tSUCCESS: " };
static int prefixes_len[] = { 11, 11, 11, 0, 11 };
/* Pass 1: counting bytes */
  dk_set_t iter;
  size_t msglen, loglen = strlen (title);
  unsigned errlevel;
  caddr_t msg;
  char *res, *tail;
  xmlparser_msglog_validate (top);
  iter = top;
  while (iter != NULL)
    {
      errlevel = (unsigned) (ptrlong) (iter->data);
      iter = iter->next;
      if (errlevel >= XCFG_ERRLEVELS)
        GPF_T;
      loglen += prefixes_len[errlevel];
      msg = iter->data;
      iter = iter->next;
      loglen += box_length (msg);
      if (iter == pastbottom)
        break;
    }
/* Pass 2: composing string */
  res = dk_alloc_box (loglen + 1, DV_LONG_STRING);
  tail = res + loglen;
  tail[0] = '\0';
  iter = top;
  while (iter != NULL)
    {
      errlevel = (unsigned) (ptrlong) (iter->data);
      iter = iter->next;
      msg = iter->data;
      iter = iter->next;
      msglen = box_length (msg);
      tail -= msglen;
      memcpy (tail, msg, msglen);
      tail[msglen-1] = '\n';
      tail -= prefixes_len[errlevel];
      memcpy (tail, prefixes[errlevel], prefixes_len[errlevel]);
      if (iter == pastbottom)
        break;
    }
#ifdef DEBUG
  if (tail != (res + strlen(title)))
    GPF_T;
#endif
  memcpy (res, title, (tail - res));
  return res;
}


#if 0
#define ecm_dbg_printf(a) printf a
#else
#define ecm_dbg_printf(a)
#endif

#ifndef max
#define max(a,b) (((a) > (b)) ? (a) : (b))
#endif

/* binary search implementation for structs with name tags.
   such structures should have first member
      char* some_name; */

/* returns pointer of found nearest item.
   if item with equal name is exists returns pointer to this one,
   in other cases, returns pointer to one of two items which
   should be neighbor of inserted item  */
static ptrlong
ecm_find_name_2 (const char *name, void *objs, ptrlong obj_no, size_t size_of_obj)
{
  if (1 == obj_no )
    return (ptrlong ) objs;
  else
    {
      char **curname = (char **)((char *)(objs) + (obj_no/2) * size_of_obj);
      int cmp = utf8cmp (*curname,name);
      if (!cmp)
	return (ptrlong) ((char *)(objs) + (obj_no/2) * size_of_obj);
      else if (cmp>0)
	return ecm_find_name_2(name, objs, obj_no/2, size_of_obj);
      else
	return ecm_find_name_2(name, (char *)(objs) + (obj_no/2) * size_of_obj, obj_no - obj_no/2, size_of_obj);
    }
}


/* returns index of found item or
   ECM_NOT_FOUND in case of failure */
ptrlong
ecm_find_name (const char *name, void *objs, ptrlong obj_no, size_t size_of_obj)
{
  ptrlong ret;
  ecm_dbg_printf(("finding %s...\n", name));
  if ((0 == obj_no) || (0 == name))
    return ECM_MEM_NOT_FOUND;
  ret = ecm_find_name_2 (name,objs,obj_no,size_of_obj);
  if (!utf8cmp((utf8char *)name, ((utf8char **) ret)[0]))
    return ((ret - (ptrlong) objs) / size_of_obj);
  return ECM_MEM_NOT_FOUND;
}

/* add empty item with unique name in array,
   if array is not allocated - creates new array with ECM_MEM_PREALLOCATE_ITEMS items */
ptrlong DBG_NAME(ecm_add_name) (DBG_PARAMS const char *new_obj_name, void **objs, ptrlong *obj_no, size_t size_of_obj)
{
  box_t array_box = *(box_t*) objs;
  ptrlong found_name_off;
  int cmp;

  ecm_dbg_printf(("adding %s...\n",new_obj_name));

  if ((!IS_BOX_POINTER(array_box)) ||
      !array_box )
    {
      /* allocation of array */
      *(box_t*) objs = DBG_NAME(dk_alloc_box_zero) (DBG_ARGS max(sizeof(long),size_of_obj) * ECM_MEM_PREALLOCATE_ITEMS,
				    DV_ARRAY_OF_LONG);
      array_box =  *(box_t*) objs;
    }
  if (*obj_no)
    {
      found_name_off = ecm_find_name_2 (new_obj_name, array_box, *obj_no, size_of_obj)
	- (ptrlong) array_box;
      cmp = utf8cmp ((utf8char *)new_obj_name, *(utf8char**)((char *)(array_box)+found_name_off));
    }
  else
    {
      found_name_off = 0;
      cmp = -1;
    };

  if (!cmp)
    return ECM_MEM_UNIQ_ERROR;
  else
    {
      if (box_length(array_box) < ((*obj_no+1) * size_of_obj) )
	{
	  box_t new_box_array = DBG_NAME(dk_alloc_box_zero) (DBG_ARGS box_length(array_box) * 2, DV_ARRAY_OF_LONG);
	  ecm_dbg_printf( ("allocating %ld due to %ld\n",
			   box_length(array_box) * 2,
			   ((*obj_no+1) * size_of_obj)) );
	  memcpy(new_box_array, array_box, (*obj_no)*size_of_obj);
	  dk_free_box (array_box);
	  array_box = new_box_array;
	  *(box_t*) objs = new_box_array;
	}
      if (cmp > 0)
	found_name_off += size_of_obj;
      memmove((char *)(array_box)+found_name_off+size_of_obj,
	      (char *)(array_box)+found_name_off,
	      ((*obj_no)*size_of_obj - found_name_off));
      memset((char *)(array_box)+found_name_off,0,size_of_obj);

      ecm_dbg_printf (("setting %s in %x\n",new_obj_name,((unsigned int)array_box)));
      memcpy(((char *)(array_box)+found_name_off), &new_obj_name, sizeof (utf8char*));
      (*obj_no) ++;
      return found_name_off/size_of_obj;
    }
  return 0;
}

int
ecm_delete_nth (ptrlong idx, void *objs, ptrlong *obj_no, size_t size_of_obj)
{
  if ((0 > idx) || (idx >= obj_no[0]))
    return 0;
  memmove (
    (char *)(objs)+(idx * size_of_obj),
    (char *)(objs)+((idx+1) * size_of_obj),
    (obj_no[0] - idx - 1)*size_of_obj );
  obj_no[0] --;
  return 1;
}

ptrlong ecm_map_name (const char *new_obj_name, void **objs, ptrlong *obj_no, size_t size_of_obj)
{
  box_t array_box = *(box_t*) objs;
  ptrlong found_name_off;
  int cmp;

  ecm_dbg_printf(("adding %s...\n",new_obj_name));

  if ((!IS_BOX_POINTER(array_box)) &&
      !array_box )
    {
      /* allocation of array */
      *(box_t*) objs = dk_alloc_box_zero(max(sizeof(long),size_of_obj) * ECM_MEM_PREALLOCATE_ITEMS,
				    DV_ARRAY_OF_LONG);
      array_box =  *(box_t*) objs;
    };
  if (*obj_no)
    {
      found_name_off = ecm_find_name_2 (new_obj_name, array_box, *obj_no, size_of_obj)
	- (ptrlong) array_box;
      cmp = utf8cmp ((utf8char *)new_obj_name, *(utf8char**)((char *)(array_box)+found_name_off));
    }
  else
    {
      found_name_off = 0;
      cmp = -1;
    };

  if (!cmp)
    return found_name_off/size_of_obj;
  else
    {
      if (box_length(array_box) < ((*obj_no+1) * size_of_obj) )
	{
	  box_t new_box_array = dk_alloc_box_zero (box_length(array_box) * 2, DV_ARRAY_OF_LONG);
	  ecm_dbg_printf( ("allocating %ld due to %ld\n",
			   box_length(array_box) * 2,
			   ((*obj_no+1) * size_of_obj)) );
	  memcpy(new_box_array, array_box, (*obj_no)*size_of_obj);
	  dk_free_box (array_box);
	  array_box = new_box_array;
	  *(box_t*) objs = new_box_array;
	}
      if (cmp > 0)
	found_name_off += size_of_obj;
      memmove((char *)(array_box)+found_name_off+size_of_obj,
	      (char *)(array_box)+found_name_off,
	      ((*obj_no)*size_of_obj - found_name_off));
      memset((char *)(array_box)+found_name_off,0,size_of_obj);

      ecm_dbg_printf (("setting %s in %x\n",new_obj_name,((unsigned int)array_box)));
      memcpy(((char *)(array_box)+found_name_off),&new_obj_name,sizeof(utf8char*));
      (*obj_no) ++;
      return found_name_off/size_of_obj;
    }
}

/* fuse two sorted arrays,
    subject to change, unefficient algorithm */
int ecm_fuse_arrays (caddr_t* target, ptrlong *target_no,
		      caddr_t branch, ptrlong branch_no, size_t size_of_obj, int copy, mem_pool_t *pool)
{
  ptrlong target_i = 0;
  ptrlong branch_i = 0;
  ptrlong max_no = target_no[0] + branch_no;
  caddr_t new_array;
  size_t size;
#ifndef NDEBUG
  if (
      ((0 == branch_no) && (NULL != branch)) ||
      ((0 != branch_no) && (NULL == branch)) ||
      (((NULL != branch) && (DV_ARRAY_OF_LONG != box_tag (branch)))) ||
      ((0 == target_no[0]) && (NULL != target[0])) ||
      ((0 != target_no[0]) && (NULL == target[0])) ||
      (((NULL != target[0]) && (DV_ARRAY_OF_LONG != box_tag (target[0])))) )
    GPF_T;
#endif
  if (0 == branch_no)
    return (int) max_no;
  size = target[0] ? box_length(target[0]) : max(sizeof(long),size_of_obj) * ECM_MEM_PREALLOCATE_ITEMS;
  while (size < (target_no[0] + branch_no)*size_of_obj)
    size*=2;
  new_array = dk_alloc_box_zero (size, DV_ARRAY_OF_LONG);
  while ((target_i+branch_i) < max_no)
    {
      char **obj1 = (char**)(target[0] + target_i*size_of_obj);
      char **obj2 = (char**)(branch + branch_i*size_of_obj);
      void *pointer_from;
      int res;
      if (target_i == target_no[0])
	res = 1;
      else if (branch_i == branch_no)
	res = -1;
      else
	res = strcmp (*obj1, *obj2);
      if (res < 0)
	{
	  pointer_from = obj1;
	  target_i++;
	}
      else if (res > 0) /* */
	{ /* first object less than second one, exchange */
	  pointer_from = obj2;
	  branch_i++;
	}
      else
	{
	  size_t idx;

	  if (copy)
	    for (idx = 0; idx < size / size_of_obj; idx++)
	      {
		dk_free_box (((char**) (new_array + idx * size_of_obj))[0]);
	      }
	  dk_free_box(new_array);
	  return -1;
	}
      memcpy(new_array + (target_i+branch_i-1)*size_of_obj, pointer_from, size_of_obj);
      if (copy && pointer_from == obj2)
	{
	  char **name_address;
	  name_address = (char**) (new_array + (target_i+branch_i-1)*size_of_obj);
	  name_address[0] = mp_box_copy (pool, name_address[0]);
	}
    }
#ifndef NDEBUG
  if (target[0] == branch)
    GPF_T;
#endif
  dk_free_box (target[0]);
  target[0] = new_array;
  target_no[0] = max_no;
  return (int) max_no;
}

#ifdef DEBUG
static int breakpoint_ctr;
void breakpoint(void)
  {
    breakpoint_ctr++;
  }
#endif

/*
extern char* pointers[100000];
extern int p_counter;
*/
caddr_t ecm_try_add_name (const char *new_obj_name, id_hash_t *hash, size_t size_of_obj)
{
  caddr_t* pptr =  (caddr_t*) id_hash_get ( hash, (caddr_t) &new_obj_name);
  if (NULL != pptr)
    return *pptr;
  else
    {
      char* name = box_string (new_obj_name);
      caddr_t ptr = dk_alloc (size_of_obj);
      /*    pointers[p_counter++]=name; */
      /* printf ("adding %p %p %s\n",hash, name, name); */
      memset (ptr, 0, size_of_obj);
      id_hash_set (hash, (caddr_t) &name, (caddr_t) &ptr);
      return ptr;
    };
}


static void xml_def_4_notation_free(xml_def_4_notation_t *ptr) {
 if(ptr->xd4n_publicId) dk_free(ptr->xd4n_publicId,-1);
 if(ptr->xd4n_systemId) dk_free(ptr->xd4n_systemId,-1);
 dk_free(ptr,-1);
 }

static void xml_def_4_entity_free(xml_def_4_entity_t *ptr) {
 if(ptr->xd4e_literalVal) dk_free_box (ptr->xd4e_literalVal);
 if(ptr->xd4e_publicId) dk_free_box (ptr->xd4e_publicId);
 if(ptr->xd4e_systemId) dk_free_box (ptr->xd4e_systemId);
 if(ptr->xd4e_notationName) dk_free_box (ptr->xd4e_notationName);
 if(ptr->xd4e_repl.lm_memblock) dk_free_box (ptr->xd4e_repl.lm_memblock);
 dk_free(ptr,-1);
 }

#ifdef dtd_free
#undef dtd_free
#endif
void dtd_free (dtd_t *dtd)
{
  ptrlong ctr;
  id_hash_t *dict;			/*!< Current dictionary to be zapped */
  id_hash_iterator_t dict_hit;		/*!< Iterator to zap dictionary */
  char **dict_key;			/*!< Current key to zap */
  ecm_el_idx_t el_ctr;
  ecm_st_idx_t st_ctr;
  ecm_attr_idx_t attr_ctr;
  if (NULL == dtd)
    return;
  dict = dtd->ed_notations;
  if (NULL != dict)
    {
      xml_def_4_notation_t **dict_notation;	/*!< Current notation to zap */
      for( id_hash_iterator (&dict_hit,dict);
	hit_next(&dict_hit, (char **)(&dict_key), (char **)(&dict_notation));
	/*no step*/ )
	{
	  xml_def_4_notation_free(dict_notation[0]);
	  dk_free (dict_key[0],-1);
	}
      id_hash_free(dict);
    }
  dict = dtd->ed_params;
  if (NULL != dict)
    {
      xml_def_4_entity_t **dict_entity;	/*!< Current param-entity to zap */
      for( id_hash_iterator (&dict_hit,dict);
	hit_next(&dict_hit, (char **)(&dict_key), (char **)(&dict_entity));
	/*no step*/ )
	{
	  xml_def_4_entity_free(dict_entity[0]);
	  dk_free_box (dict_key[0]);
	}
      id_hash_free(dict);
    }
  dict = dtd->ed_generics;
  if (NULL != dict)
    {
      xml_def_4_entity_t **dict_entity;	/*!< Current gen-entity to zap */
      for( id_hash_iterator (&dict_hit,dict);
	hit_next(&dict_hit, (char **)(&dict_key), (char **)(&dict_entity));
	/*no step*/ )
	{
	  xml_def_4_entity_free(dict_entity[0]);
	  dk_free_box (dict_key[0]);
	}
      id_hash_free(dict);
    }
  for (el_ctr = dtd->ed_el_no; el_ctr--; /*no step*/)
    {
      ecm_el_t *el = dtd->ed_els+el_ctr;
      dk_free (el->ee_name, -1);
      if (NULL != el->ee_grammar)
	dk_free (el->ee_grammar, -1);
      dk_free_box (el->ee_errmsg);
      for (attr_ctr = el->ee_attrs_no; attr_ctr--; /*no step*/)
	{
	  ecm_attr_t *attr = el->ee_attrs + attr_ctr;
	  dk_free (attr->da_name, -1);
	  for (ctr = attr->da_values_no; ctr--; /* no step*/ )
	    dk_free (attr->da_values[ctr], -1);
	  if (NULL == attr->da_values)
	    {
	      if (NULL != attr->da_default.boxed_value)
		dk_free_box (attr->da_default.boxed_value);
	    }
	  else
	    dk_free_box (attr->da_values);
	}
      dk_free_box (el->ee_attrs);
      for (st_ctr = el->ee_state_no; st_ctr--; /*no step*/)
	dk_free_box(el->ee_states[st_ctr].es_nexts);
      dk_free_box (el->ee_states);
    }
  dk_free_box (dtd->ed_els);
  dk_free_box (dtd->ed_puburi);
  dk_free_box (dtd->ed_sysuri);
  dk_free_box (dtd);
}


typedef
struct xecm_big_array_s
{
    dk_set_t xb_values; /* set of xecm_big_el_t */
    ptrlong  xb_val_no;
    ptrlong  xb_def_val;
    size_t   xb_val_sz;
} xecm_big_array_t;

typedef
struct xecm_big_el_s
{
  ptrlong   be_idx;
  ptrlong   be_val; /* pointer to object or integer */
} xecm_big_el_t;

xecm_big_array_t* xecm_create_big_array(size_t valsz)
{
  xecm_big_array_t* ar = dk_alloc(sizeof(xecm_big_array_t));
  memset(ar,0,sizeof(xecm_big_array_t));
  ar->xb_val_sz = valsz;
  return ar;
}
void xecm_ba_set_defval(struct xecm_big_array_s* ar, ptrlong defval)
{
  ar->xb_def_val = defval;
}
xecm_big_el_t* xecm_ba_get_elem(struct xecm_big_array_s* array, ptrlong idx)
{
  DO_SET(xecm_big_el_t*, el, &array->xb_values)
      if (el->be_idx == idx)
	return el;
  END_DO_SET()
  return 0;
}
void xecm_ba_rawset_val(struct xecm_big_array_s* array, ptrlong idx, ptrlong val)
{
  xecm_big_el_t* el = dk_alloc(sizeof(xecm_big_el_t));
  ptrlong newval = (ptrlong)dk_alloc_box(array->xb_val_sz,DV_ARRAY_OF_LONG);
  memcpy((void*)newval,(void*)val,array->xb_val_sz);
  el->be_idx = idx;
  el->be_val = newval;
  dk_set_push(&array->xb_values, el);
}

void xecm_ba_set_val(struct xecm_big_array_s* array, ptrlong idx, ptrlong val)
{
  xecm_big_el_t* el = xecm_ba_get_elem(array,idx);
  if (el)
    {
/*      dk_free_box((void*)el->be_val); */
      memcpy((void*)el->be_val, (void*)val, array->xb_val_sz);
    }
  else
    xecm_ba_rawset_val(array,idx,val);
}

ptrlong xecm_ba_get_val(struct xecm_big_array_s* array, ptrlong idx)
{
  xecm_big_el_t* el = xecm_ba_get_elem(array,idx);
  if (el)
    return el->be_val;
  return array->xb_def_val;
}
void xecm_ba_delete(struct xecm_big_array_s* array)
{
  DO_SET(xecm_big_el_t*, item, &array->xb_values)
      dk_free_box((void*)item->be_val);
    dk_free (item, sizeof (xecm_big_el_t));
  END_DO_SET()
  dk_set_free((void*)array->xb_values);
  dk_free_box((void*)array->xb_def_val);
  dk_free(array,sizeof(xecm_big_array_t));
}
void xecm_ba_copy(struct xecm_big_array_s* target, struct xecm_big_array_s* source)
{
  ptrlong newval;
  DO_SET(xecm_big_el_t*, el, &source->xb_values)
      xecm_ba_rawset_val(target,el->be_idx, el->be_val);
  END_DO_SET()
  newval = (ptrlong)dk_alloc_box(source->xb_val_sz,DV_ARRAY_OF_LONG);
  memcpy ((void*)newval,(void*)source->xb_def_val, source->xb_val_sz);
  dk_free_box((void*)target->xb_def_val);
  target->xb_def_val = newval;
}

void ecm_term_free (ecm_term_t* term)
{
  if ((ptrlong)term < SMALLEST_POSSIBLE_POINTER)
    return;
/*
  if (term->et_value >= SMALLEST_POSSIBLE_POINTER)
    {
      dk_free_box (term->et_value);
    }
*/
  ecm_term_free (term->et_subterm1);
  ecm_term_free (term->et_subterm2);
  dk_free_box (term);
}

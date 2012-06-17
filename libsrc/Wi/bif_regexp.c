/*
 *  bif_regexp.c
 *
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

#include "sqlnode.h"
#include "sqlbif.h"
#include "multibyte.h"
#include "srvmultibyte.h"

#include "util/pcrelib/pcre.h"

/*
   typedef struct rx_query_s {
   int snumber; // number of substring in query
   dk_set_t rx_q_result; // query_poiters_holder
   }
 */

#define NOFFSETS 20*3
#define NHASHITEMS 2000


#define LOCK_OBJECT(__obj) \
  ( mutex_enter((__obj)->mutex) )
#define RELEASE_OBJECT(__obj) \
  ( mutex_leave((__obj)->mutex) )
#define INIT_OBJECT(__obj) \
  ( (__obj)->mutex = mutex_allocate() )
#define FREE_OBJECT(__obj) \
  ( mutex_free((__obj)->mutex) )

typedef struct safe_hash_s
{
  id_hash_t *hash;
  dk_mutex_t *mutex;
}
safe_hash_t;

typedef struct pcre_info_s
{
  pcre *code;
  pcre_extra *code_x;
}
pcre_info_t;

safe_hash_t regexp_codes;


static caddr_t get_regexp_code (safe_hash_t * rx_codes, const char *pattern,
    pcre_info_t * pcre_info, int options);

#define SET_INVALID_ARG(fmt) \
  do { \
      *err_ret = srv_make_new_error ("22023", "SR375", fmt, nth + 1, func); \
      return NULL; \
    } while (0)

#define REGEXP_NO 0
#define REGEXP_BF 1
#define REGEXP_YES 3

caddr_t
bif_regexp_str_arg (caddr_t * qst, state_slot_t ** args, int nth,
  const char *func, int strg_is_utf8_by_default, int *utf8, caddr_t *ret_to_free, caddr_t *err_ret)
{
  caddr_t arg = NULL;
  dtp_t arg_dtp;
  *ret_to_free = NULL;
  *err_ret = NULL;
  if (((uint32) nth) >= BOX_ELEMENTS (args))
    SET_INVALID_ARG("Missing argument %d to %s");
  arg = bif_arg (qst, args, nth, func);
  arg_dtp = DV_TYPE_OF (arg);
  if (DV_RDF == arg_dtp)
    {
      rdf_box_t *rb = (rdf_box_t *)arg;
      if (!rb->rb_is_complete)
        SET_INVALID_ARG("Argument %d of %s is an incomplete RDF box. Must be complete RDF box or narrow or wide string");
      if (DV_STRING != DV_TYPE_OF (rb->rb_box))
        return NULL;
      if (*utf8 == 1)
        return rb->rb_box;
      if (*utf8 == 0)
        {
          *utf8 = 1;
          return rb->rb_box;
        }
      SET_INVALID_ARG("Invalid argument %d to %s. Must be narrow string");
    }
  if (DV_DB_NULL == DV_TYPE_OF (arg))
    return NULL;
  if (*utf8 == 1)
    {
      if (DV_UNAME == arg_dtp)
        return arg;
      if (DV_STRING == arg_dtp)
        {
          switch (strg_is_utf8_by_default)
            {
            case REGEXP_YES: return arg;
            case REGEXP_BF: if (box_flags (arg) & BF_UTF8) return arg;
            }
          return (*ret_to_free = box_narrow_string_as_utf8 (NULL, arg, 0, QST_CHARSET (qst), err_ret, 1));
        }
      if (DV_WIDE == arg_dtp || DV_LONG_WIDE == arg_dtp)
        return (*ret_to_free = box_wide_as_utf8_char (arg, box_length (arg) / sizeof (wchar_t) - 1, DV_SHORT_STRING));
      SET_INVALID_ARG("Invalid argument %d to %s. Must be narrow or wide string or an complete string RDF box");
    }
  if (*utf8 == 0)
    {
      if (DV_WIDE == arg_dtp || DV_LONG_WIDE == arg_dtp)
        {
          *utf8 = 1;
          return (*ret_to_free = box_wide_as_utf8_char (arg, box_length (arg) / sizeof (wchar_t) - 1, DV_SHORT_STRING));
        }
      if (DV_UNAME == arg_dtp)
        {
          *utf8 = 1;
          return arg;
        }
      if (DV_STRING == arg_dtp)
        {
          switch (strg_is_utf8_by_default)
            {
            case REGEXP_YES: *utf8 = 1; break;
            case REGEXP_BF: if (box_flags (arg) & BF_UTF8) *utf8 = 1; break;
            }
          return arg;
        }
      SET_INVALID_ARG("Invalid argument %d to %s. Must be narrow or wide string or an complete string RDF box");
    }
  /* The rest is for *utf8 == 2 */
  if (DV_STRING == arg_dtp || DV_UNAME == arg_dtp)
    return arg;
  SET_INVALID_ARG("Invalid argument %d to %s. Must be narrow string");
  return NULL;
}


static int
regexp_optchars_to_bits (const char *strg)
{
  int res = 0;
  const char *tail;
  for (tail = strg; '\0' != tail[0]; tail++)
    {
      switch (tail[0])
        {
        case 'i': case 'I': res |= PCRE_CASELESS; break;
        case 'm': case 'M': res |= PCRE_MULTILINE; break;
        case 's': case 'S': res |= PCRE_DOTALL; break;
/*
#define PCRE_EXTENDED           0x0008
#define PCRE_ANCHORED           0x0010
#define PCRE_DOLLAR_ENDONLY     0x0020
#define PCRE_EXTRA              0x0040
#define PCRE_NOTBOL             0x0080
#define PCRE_NOTEOL             0x0100
#define PCRE_UNGREEDY           0x0200
#define PCRE_NOTEMPTY           0x0400
        */
        case 'u': case 'U': res |= PCRE_UTF8; break;
        /*
#define PCRE_NO_AUTO_CAPTURE    0x1000
        */
        }
    }
  return res;
}


static caddr_t
bif_regexp_match (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  int utf8_mode;
  int str_len;
  pcre_info_t cd_info;
  caddr_t p_to_free = NULL, str_to_free = NULL;
  char *pattern;
  char *str;
  int c_opts = 0, r_opts = 0;
  caddr_t ret_str = NULL;
  long replace_the_instr = 0;

  utf8_mode = 0;
  switch ((BOX_ELEMENTS (args)))
    {
    default:
    case 5: utf8_mode = (long) bif_long_arg (qst, args, 4, "regexp_match");
    case 4: c_opts |= regexp_optchars_to_bits (bif_string_arg (qst, args, 3, "regexp_match"));
    case 3: replace_the_instr = (long) bif_long_arg (qst, args, 2, "regexp_match");
    case 2: case 1: case 0: ;
    }
  pattern = bif_regexp_str_arg (qst, args, 0, "regexp_match", REGEXP_BF, &utf8_mode, &p_to_free, err_ret);
  if (*err_ret) goto done;
  str = bif_regexp_str_arg (qst, args, 1, "regexp_match", REGEXP_BF, &utf8_mode, &str_to_free, err_ret);
  if (*err_ret) goto done;

  if (utf8_mode)
    c_opts |= PCRE_UTF8;

  if (!pattern || !str)
    goto done;

  *err_ret = get_regexp_code (&regexp_codes, pattern, &cd_info, c_opts);

  if (cd_info.code && !*err_ret)
    {
      int offvect[NOFFSETS];
      int result;
      str_len = (int) strlen (str);
      result = pcre_exec (cd_info.code, cd_info.code_x, str, str_len, 0, r_opts,
	  offvect, NOFFSETS);
      if (result != -1)
	{
	  ret_str = dk_alloc_box (offvect[1] - offvect[0] + 1, DV_SHORT_STRING);
	  strncpy (ret_str, str + offvect[0], offvect[1] - offvect[0]);
	  ret_str[offvect[1] - offvect[0]] = 0;

	  if (replace_the_instr && args[1]->ssl_type != SSL_CONSTANT)
	    { /* GK: compatibility mode */
	      caddr_t mod_str = NULL, ret_mod_str = NULL;
	      int arg_is_wide = DV_WIDESTRINGP (bif_arg (qst, args, 1, "regexp_match"));

	      mod_str = dk_alloc_box (str_len - offvect[1] + 1, DV_SHORT_STRING);
	      strncpy (mod_str, str + offvect[1], str_len - offvect[1]);
	      mod_str[str_len - offvect[1]] = 0;

	      if (arg_is_wide)
		{
		  if (utf8_mode)
		    ret_mod_str = box_utf8_as_wide_char (mod_str, NULL, str_len - offvect[1], 0, DV_WIDE);
		  else
		    ret_mod_str = box_narrow_string_as_wide ((unsigned char *) mod_str,
			NULL, 0, QST_CHARSET (qst), err_ret, 1);
		}
	      else
		{
		  if (utf8_mode)
		    ret_mod_str = box_utf8_string_as_narrow (mod_str, NULL, 0, QST_CHARSET (qst));
		}
	      if (ret_mod_str)
		{
		  dk_free_box (mod_str);
		  mod_str = ret_mod_str;
		}
	      qst_set (qst, args[1], mod_str);
	    }

	  if (utf8_mode && ret_str)
	    {
	      caddr_t wide_ret = box_utf8_as_wide_char (ret_str, NULL,
		  box_length (ret_str) - 1, 0, DV_WIDE);
	      dk_free_box (ret_str);
	      ret_str = wide_ret;
	    }
	}
    }

done:
  if (*err_ret)
    dk_free_box (ret_str);
  dk_free_tree (p_to_free);
  dk_free_tree (str_to_free);
  return *err_ret ? NULL : (ret_str ? ret_str : NEW_DB_NULL);
}

static caddr_t
bif_rdf_regex_impl (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  int utf8_mode = 1;
  int str_len;
  pcre_info_t cd_info;
  caddr_t p_to_free = NULL, str_to_free = NULL;
  char *pattern;
  char *str;
  int c_opts = 0, r_opts = 0;
  int result = -1;
  caddr_t err = NULL;
  switch ((BOX_ELEMENTS (args)))
    {
    default:
    case 3: c_opts |= regexp_optchars_to_bits (bif_string_arg (qst, args, 2, "rdf_regex_impl"));
    case 2: case 1: case 0: ;
    }
  pattern = bif_regexp_str_arg (qst, args, 1, "rdf_regex_impl", REGEXP_YES, &utf8_mode, &p_to_free, &err);
  if (err) goto done;
  str = bif_regexp_str_arg (qst, args, 0, "rdf_regex_impl", REGEXP_BF, &utf8_mode, &str_to_free, &err);
  if (err) goto done;

  if (utf8_mode)
    c_opts |= PCRE_UTF8;

  if (!pattern || !str)
    goto done;

  *err_ret = get_regexp_code (&regexp_codes, pattern, &cd_info, c_opts);

  if (cd_info.code && !*err_ret)
    {
      int offvect[NOFFSETS];
      str_len = (int) strlen (str);
      result = pcre_exec (cd_info.code, cd_info.code_x, str, str_len, 0, r_opts,
	  offvect, NOFFSETS);
    }

done:
  if (err)
    dk_free_tree (err);
  dk_free_tree (p_to_free);
  dk_free_tree (str_to_free);
  return (caddr_t)((ptrlong)((-1 == result) ? 0 : 1));
}

/* string regexp_substr(in pattern string, in str string, in offset number); */
static caddr_t
bif_regexp_substr (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  int utf8_mode;
  char *pattern;
  char *str;
  int offset;
  int res_len;
  pcre_info_t cd_info;
  int c_opts = 0, r_opts = 0;
  caddr_t p_to_free = NULL, str_to_free = NULL;
  caddr_t ret_str = NULL;

  utf8_mode = 0;
  pattern = bif_regexp_str_arg (qst, args, 0, "regexp_substr", REGEXP_BF, &utf8_mode, &p_to_free, err_ret);
  if (*err_ret) goto done;
  str = bif_regexp_str_arg (qst, args, 1, "regexp_substr", REGEXP_BF, &utf8_mode, &str_to_free, err_ret);
  if (*err_ret) goto done;
  offset = (int) bif_long_arg (qst, args, 2, "regexp_substr");
  switch ((BOX_ELEMENTS (args)))
    {
    default:
    case 4: c_opts |= regexp_optchars_to_bits (bif_string_arg (qst, args, 3, "regexp_substr"));
    case 3: case 2: case 1: case 0: ;
    }
  if (!pattern || !str)
    goto done;

  *err_ret = get_regexp_code (&regexp_codes, pattern, &cd_info, c_opts);

  if (cd_info.code && !*err_ret)
    {
      int result;
      int offvect[NOFFSETS];
      res_len = (int) strlen (str);
      result = pcre_exec (cd_info.code, cd_info.code_x, str, res_len, 0, r_opts,
	  offvect, NOFFSETS);

      if (result > 0)
	{
	  int offs = offset*2, rc;
	  ret_str = dk_alloc_box ((offset < result && offset >= 0 ?
		(offvect[offs+1] - offvect[offs]) : res_len) + 1, DV_SHORT_STRING);
	  rc = pcre_copy_substring (str, offvect, result, offset, ret_str,
	      res_len + 1);
	  if (rc < 0)
	    {
	      *err_ret = srv_make_new_error ("2201B", "SR097",
		  "regexp error : could not obtain substring (%d of %d)",
		  offset, result - 1);
	    }
	  else
	    {
	      if (utf8_mode && ret_str)
		{
		  caddr_t wide_ret = box_utf8_as_wide_char (ret_str, NULL,
		      box_length (ret_str) - 1, 0, DV_WIDE);
		  dk_free_box (ret_str);
		  ret_str = wide_ret;
		}
	    }
	}
    }

done:
  if (*err_ret)
    dk_free_box (ret_str);
  dk_free_tree (p_to_free);
  dk_free_tree (str_to_free);
  return *err_ret ? NULL : (ret_str ? ret_str : NEW_DB_NULL);
}

ptrlong *
regexp_offvect_to_array_of_long (utf8char *str, int *offvect, int result, int utf8_mode)
{
  int i, idx_to_fill;
  int prev_ofs, ofs, prev_wide_len;
  dk_set_t skipped_i = NULL;
  ptrlong *ret_vec;
  virt_mbstate_t mb;
  if (0 >= result)
    return NULL;
  result *= 2;
  ret_vec = (ptrlong *)dk_alloc_box (sizeof (ptrlong) * result, DV_ARRAY_OF_LONG);
  if (!utf8_mode)
    {
      for (i = result; i--; /* no step */)
        ret_vec[i] = offvect[i];
      return ret_vec;
    }
  i = 0;
  idx_to_fill = 0;
  prev_ofs = 0;
  prev_wide_len = 0;
  memset (&mb, 0, sizeof (virt_mbstate_t));

again:
  if ((i < result) && (0 >= offvect[i])) /* That's for fragments like "(.?)" that were matched to an empty string */
    {
      ret_vec [i] = offvect[i];
      i++;
      goto again; /* see above */
    }
/*The result vector is { B,E, B1,E1, B2,E2... Bn,En } where B <= B1 <= B2... <= Bn but there's no good order for Es.
However all out-of-order E-s form a proper backstack. */
/*...so we push out-of-order E-s as soon as they're found in offvect */
  if (i % 2)
    {
      int next_nonnegative_ofs_i = i + 1;
      while (next_nonnegative_ofs_i < result)
        {
          if (0 > offvect[next_nonnegative_ofs_i])
            {
              next_nonnegative_ofs_i++;
              continue;
            }
          if (offvect[i] > offvect[next_nonnegative_ofs_i])
            {
              dk_set_push (&skipped_i, (void *)((ptrlong)i));
              i++;
              goto again;
            }
          break;
        }
    }
/*...and we pop out-of-order E-s as soon as possible */
  if ((NULL != skipped_i) && ((i >= result) || ((prev_ofs <= offvect[(ptrlong)(skipped_i->data)]) && (offvect[i] >= offvect[(ptrlong)(skipped_i->data)]))))
    {
      idx_to_fill = (ptrlong)dk_set_pop (&skipped_i);
      goto idx_found; /* see below */
    }
  if (i >= result)
    goto done;
  idx_to_fill = i++;

idx_found:
  ofs = offvect[idx_to_fill];
  if (ofs < prev_ofs)
    GPF_T1 ("Corrupted regexp result");
  else if (ofs == prev_ofs)
    {
      ret_vec [idx_to_fill] = prev_wide_len;
      goto again; /* see above */
    }
  else
    {
      int wide_len_diff = (int) virt_mbsnrtowcs (NULL, &str, ofs - prev_ofs, 0, &mb);
      prev_wide_len += wide_len_diff;
      prev_ofs = ofs;
      ret_vec [idx_to_fill] = prev_wide_len;
      goto again; /* see above */
    }

done:
  return ret_vec;
}


/*
 *Function Name: bif_regexp_parse / bif_regexp_parse_list
 *
 *Parameters:	pattern - regular expression pattern,
 *		str - string to be parsed
 *		offset - offset from which parsing must be executed
 *		options - string of regex option chars, like 'i', default is empty string
 *		n_hits - number of hits to find (only for bif_regexp_parse_list)
 *Description:  finds all substrings which match all parenthesised grroups of a pattern, in one iteration.
 *
 *Returns if not a list:
 *		vector of offset pairs:
 *		1 pair - index of begin of matched substring and
 *			index of matched substrings end
 *		2...n pairs - indexes of begins and ends of matched substrings of first substring.
 *
 * Returns if not a list:
 */

static caddr_t
bif_regexp_parse_impl (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args, int parse_list, const char *fname)
{
  int utf8_mode, utf8_mode2;
  char *pattern = NULL;
  char *str = NULL;
  int offset, str_len;
  pcre_info_t cd_info;
  int c_opts = 0, r_opts = 0, max_n_hits = 0x1000000 / sizeof (ptrlong);
  caddr_t p_to_free = NULL, str_to_free = NULL;
  int offvect[NOFFSETS];
  ptrlong *ret_vec = NULL;
  dk_set_t ret_revlist = NULL;

  utf8_mode = utf8_mode2 = 0;
  offset = (int) bif_long_arg (qst, args, 2, fname);
  str = bif_regexp_str_arg (qst, args, 1, fname, REGEXP_BF, &utf8_mode, &str_to_free, err_ret);
  if (*err_ret) goto done;

  utf8_mode2 = utf8_mode ? utf8_mode : 2;
  pattern = bif_regexp_str_arg (qst, args, 0, fname, REGEXP_BF, &utf8_mode2, &p_to_free, err_ret);
  if (*err_ret) goto done;

  switch ((BOX_ELEMENTS (args)))
    {
    default:
    case 5: if (parse_list) max_n_hits = bif_long_range_arg (qst, args, 4, fname, 0, max_n_hits);
    case 4: c_opts |= regexp_optchars_to_bits (bif_string_arg (qst, args, 3, fname));
    case 3: case 2: case 1: case 0: ;
    }

  if (!pattern || !str)
    goto done;
  *err_ret = get_regexp_code (&regexp_codes, pattern, &cd_info, c_opts);

  if (*err_ret || !cd_info.code)
    goto done;

  str_len = (int) strlen (str);
  if (parse_list)
    {
      while (0 < max_n_hits--)
        {
          int result = pcre_exec (cd_info.code, cd_info.code_x, str, str_len, offset, r_opts,
            offvect, NOFFSETS);
          if (0 >= result)
            break;
          ret_vec = regexp_offvect_to_array_of_long ((utf8char *)str, offvect, result, utf8_mode);
          if (offset >= ret_vec[1])
            offset++;
          else
            offset = ret_vec[1];
          dk_set_push (&ret_revlist, ret_vec);
        }
    }
  else
    {
      int result = pcre_exec (cd_info.code, cd_info.code_x, str, str_len, offset, r_opts,
        offvect, NOFFSETS);
      ret_vec = regexp_offvect_to_array_of_long ((utf8char *)str, offvect, result, utf8_mode);
    }

done:
  dk_free_tree (p_to_free);
  dk_free_tree (str_to_free);
  if (*err_ret)
    return NULL;
  if (parse_list)
    return revlist_to_array (ret_revlist);
  if (NULL != ret_vec)
    return (caddr_t)ret_vec;
  return NEW_DB_NULL;
}

static caddr_t
bif_regexp_parse (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return bif_regexp_parse_impl (qst, err_ret, args, 0, "regexp_parse");
}

static caddr_t
bif_regexp_parse_list (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return bif_regexp_parse_impl (qst, err_ret, args, 1, "regexp_parse_list");
}

ptrlong *
parse_replacing_template (caddr_t tmpl, int tmpl_syntax_is_xpf, int pos_count)
{
  int tmpl_is_wide = (DV_WIDE == DV_TYPE_OF (tmpl));
  int charsize = tmpl_is_wide ? sizeof (wchar_t) : 1;
  char *tmpl_tail = tmpl;
  char *tmpl_end = tmpl + box_length (tmpl) - charsize;
  char *tmpl_cut_start = tmpl_tail;
  dk_set_t res = NULL;
  tmpl_cut_start = tmpl_tail;
#define TMPL_TAIL_CHR(ofs) ((tmpl_is_wide) ? ((wchar_t *)tmpl_tail)[ofs] : tmpl_tail[ofs])
#define PUSH_TO_RES(beg,end) do { dk_set_push (&res, (void *)((ptrlong)(beg))); dk_set_push (&res, (void *)((ptrlong)(end))); } while (0)
  if (tmpl_syntax_is_xpf)
    {
      while (tmpl_tail < tmpl_end)
        {
          if ('\\' == TMPL_TAIL_CHR(0))
            {
              if (tmpl_cut_start < tmpl_tail)
                PUSH_TO_RES ((tmpl_cut_start - tmpl) / charsize, ((tmpl_tail - tmpl) / charsize));
              tmpl_tail += charsize;
              tmpl_cut_start = tmpl_tail;
              if (tmpl_tail < tmpl_end)
                tmpl_tail += charsize;
              continue;
            }
          else if (('$' == TMPL_TAIL_CHR(0)) && (tmpl_tail < (tmpl_end - charsize))
             && ('0' <= TMPL_TAIL_CHR(1)) && ('9' >= TMPL_TAIL_CHR(1)) )
            {
              int pos_idx = TMPL_TAIL_CHR(1) - '0';
              if (tmpl_cut_start < tmpl_tail)
                PUSH_TO_RES ((tmpl_cut_start - tmpl) / charsize, ((tmpl_tail - tmpl) / charsize));
              tmpl_tail += charsize * 2;
              if ((pos_count > 9) && (tmpl_tail < tmpl_end) && ('0' <= TMPL_TAIL_CHR(0)) && ('9' >= TMPL_TAIL_CHR(0)))
                {
                  pos_idx = pos_idx * 10 + TMPL_TAIL_CHR(0) - '0';
                  tmpl_tail += charsize;
                }
              if (pos_idx < pos_count)
                PUSH_TO_RES (-1, pos_idx);
              tmpl_cut_start = tmpl_tail;
              continue;
            }
          tmpl_tail += charsize;
        }
    }
  else
    {
      while (tmpl_tail < tmpl_end)
        {
          if ('\\' == TMPL_TAIL_CHR(0))
            {
              if (tmpl_cut_start < tmpl_tail)
                PUSH_TO_RES ((tmpl_cut_start - tmpl) / charsize, ((tmpl_tail - tmpl) / charsize));
              tmpl_tail += charsize;
              if ((tmpl_tail < tmpl_end)  && ('0' <= TMPL_TAIL_CHR(0)) && ('9' >= TMPL_TAIL_CHR(0)))
                {
                  int pos_idx = TMPL_TAIL_CHR(0) - '0';
                  tmpl_tail += charsize;
                  if ((pos_count > 9) && (tmpl_tail < tmpl_end) && ('0' <= TMPL_TAIL_CHR(0)) && ('9' >= TMPL_TAIL_CHR(0)))
                    {
                      pos_idx = pos_idx * 10 + TMPL_TAIL_CHR(0) - '0';
                      tmpl_tail += charsize;
                    }
                  if (pos_idx < pos_count)
                    PUSH_TO_RES (-1, pos_idx);
                  tmpl_cut_start = tmpl_tail;
                  continue;
                }
              tmpl_cut_start = tmpl_tail;
              if (tmpl_tail < tmpl_end)
                tmpl_tail += charsize;
              continue;
            }
          tmpl_tail += charsize;
        }
    }
  if (tmpl_cut_start < tmpl_tail)
    PUSH_TO_RES ((tmpl_cut_start - tmpl) / charsize, ((tmpl_tail - tmpl) / charsize));
  return (ptrlong *)revlist_to_array (res);
}

static caddr_t
bif_regexp_replace_hits_with_template (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  int hit_ctr, hit_count, src_is_wide;
  int src_charsize;
  int src_charcount;
  wcharset_t *src_cs, *tmpl_cs;
  int pos_count_in_hits;
  int prev_left_pos = 0;
  dk_session_t *ses;
  caddr_t src = bif_string_or_wide_or_uname_arg (qst, args, 0, "regexp_replace_hits_with_template");
  caddr_t orig_tmpl = bif_string_or_wide_or_uname_arg (qst, args, 1, "regexp_replace_hits_with_template");
  caddr_t *hit_list = bif_array_of_pointer_arg (qst, args, 2, "regexp_replace_hits_with_template");
  int tmpl_syntax_is_xpf = bif_long_arg (qst, args, 3, "regexp_replace_hits_with_template");
  caddr_t tmpl = NULL;
  ptrlong *parsed_tmpl, *parsed_tmpl_end;
  caddr_t res_strg;
  hit_count = BOX_ELEMENTS (hit_list);
  if (0 == hit_count)
    return box_copy (src);
  src_is_wide = (DV_WIDE == DV_TYPE_OF (src));
  src_charsize = src_is_wide ? sizeof (wchar_t) : 1;
  src_charcount = (box_length (src) / src_charsize) - 1;
#define HIT_NTH_POS(pos) ((DV_ARRAY_OF_LONG == hit_dtp) ? hit[pos] : unbox ((caddr_t)(hit[pos])))
/* Integrity check first */
  for (hit_ctr = 0; hit_ctr < hit_count; hit_ctr++)
    {
      ptrlong *hit = (ptrlong *)(hit_list[hit_ctr]);
      dtp_t hit_dtp = DV_TYPE_OF (hit);
      int pos_ctr, pos_count;
      ptrlong hit_b, hit_e;
      if ((DV_ARRAY_OF_LONG != hit_dtp) && (DV_ARRAY_OF_POINTER != hit_dtp))
        sqlr_new_error ("22023", "SR647",
          "Function regexp_replace_hits_with_template() has invalid hit list count as argument 2 (hit with index %d is not an array)", hit_ctr );
      pos_count = BOX_ELEMENTS (hit);
      if ((2 > pos_count) || (200 < pos_count) || (pos_count % 2))
        sqlr_new_error ("22023", "SR647",
          "Function regexp_replace_hits_with_template() has invalid hit (index %d) in argument 2 (invalid length of position list)", hit_ctr );
      if (0 == hit_ctr)
        pos_count_in_hits = pos_count;
      else if (pos_count_in_hits != pos_count)
        sqlr_new_error ("22023", "SR647",
          "Function regexp_replace_hits_with_template() has invalid hit (index %d) in argument 2 (the length of position list is %d, but it is %d for the first hit)", hit_ctr, pos_count, pos_count_in_hits );
      hit_b = HIT_NTH_POS(0);
      hit_e = HIT_NTH_POS(1);
      if ((hit_b < prev_left_pos) || (hit_e < hit_b) || (hit_e > src_charcount))
        sqlr_new_error ("22023", "SR647",
          "Function regexp_replace_hits_with_template() has invalid hit (index %d) in argument 2 (from %d to %d, limits are %d to %d)",
          hit_ctr, (int)hit_b, (int)hit_e, prev_left_pos, src_charcount );
      for (pos_ctr = 2; pos_ctr < pos_count; pos_ctr += 2)
        {
          ptrlong pos_b = HIT_NTH_POS(pos_ctr);
          ptrlong pos_e = HIT_NTH_POS(pos_ctr+1);
          if ((-1 == pos_b) && (-1 == pos_e))
            continue;
          if ((pos_b < prev_left_pos) || (pos_e < pos_b) || (pos_e > hit_e))
            sqlr_new_error ("22023", "SR647",
              "Function regexp_replace_hits_with_template() has invalid pos pair (hit index %d, pos %d) in argument 2 (from %d to %d, limits are %d to %d, hit is from %d to %d)",
              hit_ctr, pos_ctr, (int)pos_b, (int)pos_e, prev_left_pos, (int)hit_e, (int)hit_b, (int)hit_e );
          prev_left_pos = pos_b;
        }
    }
/* Now we know that the processing will not hang so we can go on */
  src_cs = charset_native_for_box (src, tmpl_syntax_is_xpf ? BF_UTF8 : BF_DEFAULT_SERVER_ENC);
  tmpl_cs = charset_native_for_box (tmpl, tmpl_syntax_is_xpf ? BF_UTF8 : BF_DEFAULT_SERVER_ENC);
  if (src_cs != tmpl_cs)
    {
      int res_is_new = 0;
      caddr_t err = NULL;
      caddr_t tmpl_temp_copy = box_copy (orig_tmpl);
      tmpl = charset_recode_from_cs_or_eh_to_cs (orig_tmpl, 0, NULL, tmpl_cs, src_cs, &res_is_new, &err);
      if (res_is_new)
        dk_free_box (tmpl_temp_copy);
      if (err)
        sqlr_resignal (err);
    }
  else
    tmpl = orig_tmpl;
  parsed_tmpl = parse_replacing_template (tmpl, tmpl_syntax_is_xpf, pos_count_in_hits);
  parsed_tmpl_end = parsed_tmpl + BOX_ELEMENTS (parsed_tmpl);
  ses = strses_allocate ();
  prev_left_pos = 0;
#define PASTE(strg,b,e) session_buffered_write (ses, (strg) + ((b) *src_charsize), ((e)-(b))*src_charsize)
  for (hit_ctr = 0; hit_ctr < hit_count; hit_ctr++)
    {
      ptrlong *hit = (ptrlong *)(hit_list[hit_ctr]);
      dtp_t hit_dtp = DV_TYPE_OF (hit);
      ptrlong *parsed_tmpl_tail;
      ptrlong hit_b = HIT_NTH_POS(0);
      ptrlong hit_e = HIT_NTH_POS(1);
      if (hit_b > prev_left_pos)
        PASTE (src, prev_left_pos,hit_b);
      for (parsed_tmpl_tail = parsed_tmpl; parsed_tmpl_tail < parsed_tmpl_end; parsed_tmpl_tail += 2)
        {
          if (-1 == parsed_tmpl_tail[0])
            {
              ptrlong pos_b = HIT_NTH_POS (parsed_tmpl_tail[1] * 2);
              ptrlong pos_e = HIT_NTH_POS (parsed_tmpl_tail[1] * 2 + 1);
              PASTE (src, pos_b, pos_e);
            }
          else
            {
              ptrlong pos_b = parsed_tmpl_tail[0];
              ptrlong pos_e = parsed_tmpl_tail[1];
              if (0 <= pos_b)
                PASTE (tmpl, pos_b, pos_e);
            }
        }
      prev_left_pos = hit_e;
    }
  if (prev_left_pos < src_charcount)
    PASTE (src, prev_left_pos, src_charcount);
  dk_free_box ((caddr_t)parsed_tmpl);
  if (tmpl != orig_tmpl)
    dk_free_box (tmpl);
  if (src_is_wide)
    res_strg = strses_wide_string (ses);
  else
    {
      res_strg = strses_string (ses);
      if (CHARSET_UTF8 == src_cs)
        box_flags (res_strg) |= BF_UTF8;
    }
  strses_free (ses);
  return res_strg;
}

int32 c_match_limit_recursion = 150;

static caddr_t
get_regexp_code (safe_hash_t * rx_codes, const char *pattern,
    pcre_info_t * pcre_info, int options)
{
  const char *error = 0;
  int erroff;
  dk_hash_t *opts_hash = NULL, **opts_hash_ptr = NULL;
  pcre_info_t *pcre_info_ref = NULL;
  LOCK_OBJECT (rx_codes);

  opts_hash_ptr = (dk_hash_t **) id_hash_get (rx_codes->hash, (char *) &pattern);
  if (opts_hash_ptr && *opts_hash_ptr)
    {
      opts_hash = *opts_hash_ptr;
      pcre_info_ref = (pcre_info_t *) gethash ((void *) (unsigned ptrlong) (options + 1), opts_hash);
    }

  if (!pcre_info_ref)
    {
      dbg_printf (("regex compiling (%s) with options %x ...\n", pattern, options));
      pcre_info->code = pcre_compile (pattern, options, &error, &erroff, 0);
      if (pcre_info->code)
	{
	  box_t pattern_box = box_dv_short_string (pattern);

	  pcre_info->code_x = pcre_study (pcre_info->code, options, &error);
#ifdef DEBUG
	  if (!pcre_info->code_x)
	    dbg_printf (("***warning RX100: regexp warning: extra regular expression compiling failed\n"));
#endif
	  if (!opts_hash)
	    {
	      opts_hash = hash_table_allocate (5);
	      id_hash_set (rx_codes->hash, (char *) &pattern_box, (char *) &opts_hash);
	    }
	  pcre_info_ref = (pcre_info_t *) dk_alloc (sizeof (pcre_info_t));
	  *pcre_info_ref = *pcre_info;
	  sethash ((void *) (unsigned ptrlong) (options + 1), opts_hash, pcre_info_ref);
	}
      else if (error)
	{
	  RELEASE_OBJECT (rx_codes);
	  return srv_make_new_error ("2201B",
	      "SR098", "regexp error at \'%s\' column %d (%s)", pattern, erroff, error);
	};
    }
  else
    *pcre_info = *pcre_info_ref;
  if (pcre_info->code_x)
    {
      pcre_info->code_x->flags |= PCRE_EXTRA_MATCH_LIMIT_RECURSION;
      pcre_info->code_x->match_limit_recursion = c_match_limit_recursion;
    }
  RELEASE_OBJECT (rx_codes);
  return NULL;
}

static caddr_t
bif_regexp_version (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return box_dv_short_string(pcre_version());
}

void
bif_regexp_init ()
{
  INIT_OBJECT (&regexp_codes);
  regexp_codes.hash = id_hash_allocate (NHASHITEMS, sizeof (caddr_t), sizeof (pcre_info_t),
      strhash, strhashcmp);

  bif_define_typed ("regexp_match", bif_regexp_match, &bt_varchar);
  bif_define_typed ("rdf_regex_impl", bif_rdf_regex_impl, &bt_varchar);
  bif_define_typed ("regexp_substr", bif_regexp_substr, &bt_varchar);
  bif_define_typed ("regexp_parse", bif_regexp_parse, &bt_any);
  bif_define_typed ("regexp_parse_list", bif_regexp_parse_list, &bt_any);
  bif_define_typed ("regexp_replace_hits_with_template", bif_regexp_replace_hits_with_template, &bt_varchar);
  bif_define_typed ("regexp_version", bif_regexp_version, &bt_varchar);
}


/* internal functions for internal usage in Virtuoso */
caddr_t
regexp_match_01 (const char* pattern, const char* str, int c_opts)
{
  pcre_info_t cd_info;
  int r_opts = 0;
  caddr_t err = NULL;

  err = get_regexp_code (&regexp_codes, pattern, &cd_info, c_opts);
  if (err)
    sqlr_resignal (err);

  if (cd_info.code)
    {
      int offvect[NOFFSETS];
      int result;
      int str_len = (int) strlen (str);
      memset (offvect, -1, NOFFSETS * sizeof (int));
      result = pcre_exec (cd_info.code, cd_info.code_x, str, str_len, 0, r_opts,
	  offvect, NOFFSETS);
      if (result != -1)
	{
	  caddr_t ret_str = dk_alloc_box (offvect[1] - offvect[0] + 1, DV_SHORT_STRING);
	  strncpy (ret_str, str + offvect[0], offvect[1] - offvect[0]);
	  ret_str[offvect[1] - offvect[0]] = 0;
	  return ret_str;
	}
    }
  return NULL;
}

struct regexp_opts_s {
  char	mc;
  int	opt;
} regexp_mode_table[] = {
  { 'i',	PCRE_CASELESS },
  { 'm',	PCRE_MULTILINE },
  { 's',	PCRE_DOTALL },
  { 'x',	PCRE_EXTENDED }
};

#define regexp_mode_table_l (sizeof(regexp_mode_table)/sizeof(struct regexp_opts_s))



int
regexp_make_opts (const char* mode)
{
  const char* mode_char = mode;
  int c_opts = 0;
  if (!mode)
    return 0;
  while (mode_char[0])
    {
      int i;
      for (i=0;i<regexp_mode_table_l;i++)
	{
	  if (regexp_mode_table[i].mc == mode_char[0])
	    {
	      c_opts |= regexp_mode_table[i].opt;
	      break;
	    }
	}
      if (i==regexp_mode_table_l)
	return -1;
      mode_char++;
    }
  return c_opts;
}

/* initialize vector of offsets, returns double number of offsets.
   -1 if failed
   signals the error if pattern is invalid.

   example:
   pattern = a(.)
   str = "abraca"

   offvect =   {0, 2, -- whole matched string
		1, 2} -- $1
   returns 4
*/

int
regexp_split_parse (const char* pattern, const char* str, int* offvect, int offvect_sz, int c_opts)
{
  int str_len;
  pcre_info_t cd_info;
  int r_opts = 0;
  caddr_t err = NULL;

  err = get_regexp_code (&regexp_codes, pattern, &cd_info, c_opts);
  if (err)
    sqlr_resignal (err);

  if (cd_info.code)
    {
      int result;
      str_len = (int) strlen (str);
      result = pcre_exec (cd_info.code, cd_info.code_x, str, str_len, 0, r_opts,
	  offvect, offvect_sz);
      return result;
    }
  return -1;
}

/* returns string part before matched substring
   pattern = \s+
   str = "hello world"

   returns = "hello"
   next[0] = 6
*/

caddr_t
regexp_split_match (const char* pattern, const char* str, int* next, int c_opts)
{
  int str_len;
  pcre_info_t cd_info;
  int r_opts = 0;
  caddr_t err = NULL;

  err = get_regexp_code (&regexp_codes, pattern, &cd_info, c_opts);
  if (err)
    sqlr_resignal (err);

  if (cd_info.code)
    {
      int offvect[NOFFSETS];
      int result;
      caddr_t ret_str;
      str_len = (int) strlen (str);
      result = pcre_exec (cd_info.code, cd_info.code_x, str, str_len, 0, r_opts,
	  offvect, NOFFSETS);
      if (result != -1)
	{
	  ret_str = dk_alloc_box (offvect[0] + 1, DV_STRING);
	  strncpy (ret_str, str, offvect[0]);
	  ret_str[offvect[0]] = 0;

	  if (next)
	    next[0] = offvect[1];
	}
      else
	{
	  ret_str = box_string (str);
	  if (next)
	    next[0] = -1;
	}
      return ret_str;
    }
  return NULL;
}

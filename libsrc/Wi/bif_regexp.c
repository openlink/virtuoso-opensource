/*
 *  bif_regexp.c
 *
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
   *err_ret = srv_make_new_error ("22023", "SR375", fmt, nth + 1, func)

static caddr_t
bif_regexp_str_arg (caddr_t * qst, state_slot_t ** args, int nth,
  char *func, int *utf8, caddr_t *ret_to_free, caddr_t *err_ret)
{
  caddr_t arg = NULL;
  caddr_t ret = NULL;

  if (((uint32) nth) >= BOX_ELEMENTS (args))
    SET_INVALID_ARG("Missing argument %d to %s");
  else
    {
      arg = bif_arg (qst, args, nth, func);
      if (*utf8 == 1)
	{
	  if (DV_STRINGP (arg))
	    *ret_to_free = ret = box_narrow_string_as_utf8 (NULL, arg, 0, QST_CHARSET (qst));
	  else if (DV_WIDESTRINGP (arg))
	    *ret_to_free = ret =
		box_wide_as_utf8_char (arg, box_length (arg) / sizeof (wchar_t) - 1, DV_SHORT_STRING);
	  else if (DV_DB_NULL == DV_TYPE_OF (arg))
	    *ret_to_free = ret = NULL;
	  else
	    SET_INVALID_ARG("Invalid argument %d to %s. Must be narrow or wide string");
	}
      else if (*utf8 == 0)
	{
	  if (DV_WIDESTRINGP (arg))
	    {
	      *utf8 = 1;
	      *ret_to_free = ret =
		  box_wide_as_utf8_char (arg, box_length (arg) / sizeof (wchar_t) - 1, DV_SHORT_STRING);
	    }
	  else if (DV_STRINGP (arg))
	    {
	      ret = arg;
	      ret_to_free = NULL;
	    }
	  else if (DV_DB_NULL == DV_TYPE_OF (arg))
	    *ret_to_free = ret = NULL;
	  else
	    SET_INVALID_ARG("Invalid argument %d to %s. Must be narrow or wide string");
	}
      else if (*utf8 == 2)
	{
	  if (DV_STRINGP (arg))
	    {
	      ret = arg;
	      ret_to_free = NULL;
	    }
	  else if (DV_DB_NULL == DV_TYPE_OF (arg))
	    *ret_to_free = ret = NULL;
	  else
	    SET_INVALID_ARG("Invalid argument %d to %s. Must be narrow string");
	}
    }
  return ret;
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
  pattern = bif_regexp_str_arg (qst, args, 0, "regexp_match", &utf8_mode, &p_to_free, err_ret);
  if (*err_ret) goto done;
  str = bif_regexp_str_arg (qst, args, 1, "regexp_match", &utf8_mode, &str_to_free, err_ret);
  if (*err_ret) goto done;
  if (BOX_ELEMENTS (args) > 2)
    replace_the_instr = (long) bif_long_arg (qst, args, 2, "regexp_match");

  if (!pattern || !str)
    goto done;

  if (utf8_mode)
    c_opts |= PCRE_UTF8;

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
			NULL, 0, QST_CHARSET (qst));
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
  pattern = bif_regexp_str_arg (qst, args, 0, "regexp_substr", &utf8_mode, &p_to_free, err_ret);
  if (*err_ret) goto done;
  str = bif_regexp_str_arg (qst, args, 1, "regexp_substr", &utf8_mode, &str_to_free, err_ret);
  if (*err_ret) goto done;
  offset = (int) bif_long_arg (qst, args, 2, "regexp_substr");

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

/*
 *Function Name: bif_regexp_parse
 *
 *Parameters:	pattern - regular expression pattern,
 *		str - string to be parsed
 *		offset - offset from which parsing must be executed
 *Description:  finds all substrings which match pattern in one iteration.
 *
 *Returns:	vector of offset pairs:
 *		1 pair - index of begin of matched substring and
 *			index of matched substrings end
 *		2...n pairs - indexes of begins and ends of matched substrings of first substring.
 *
 */

static caddr_t
bif_regexp_parse (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  int utf8_mode, utf8_mode2;
  char *pattern = NULL;
  char *str = NULL;
  int offset;
  pcre_info_t cd_info;
  int c_opts = 0, r_opts = 0;
  caddr_t p_to_free = NULL, str_to_free = NULL;
  caddr_t ret_vec = NULL;

  utf8_mode = utf8_mode2 = 0;
  offset = (int) bif_long_arg (qst, args, 2, "regexp_parse");
  str = bif_regexp_str_arg (qst, args, 1, "regexp_parse", &utf8_mode, &str_to_free, err_ret);
  if (*err_ret) goto done;

  utf8_mode2 = utf8_mode ? utf8_mode : 2;
  pattern = bif_regexp_str_arg (qst, args, 0, "regexp_parse", &utf8_mode2, &p_to_free, err_ret);
  if (*err_ret) goto done;

  if (!pattern || !str)
    goto done;
  *err_ret = get_regexp_code (&regexp_codes, pattern, &cd_info, c_opts);

  if (cd_info.code && !*err_ret)
    {
      int offvect[NOFFSETS];
      int result;
      int str_len = (int) strlen (str);
      result = pcre_exec (cd_info.code, cd_info.code_x, str, str_len, offset, r_opts,
	  offvect, NOFFSETS);
      if (result != -1)
	{
	  int i;
	  ret_vec = dk_alloc_box (sizeof (ptrlong) * 2 * result, DV_ARRAY_OF_LONG);
	  for (i = 0; i < (result * 2); i++)
	    {
	      if (utf8_mode)
		{
		  virt_mbstate_t mb;
		  int wide_len;
		  unsigned char *str_tmp = (unsigned char *) str;

		  memset (&mb, 0, sizeof (virt_mbstate_t));
		  wide_len = (int) virt_mbsnrtowcs (NULL, &str_tmp, offvect[i], 0, &mb);
		  ((ptrlong *) ret_vec)[i] = wide_len;
		}
	      else
		((ptrlong *) ret_vec)[i] = offvect[i];
	    }
	}
    }

done:
  if (*err_ret)
    dk_free_box (ret_vec);
  dk_free_tree (p_to_free);
  dk_free_tree (str_to_free);
  return *err_ret ? NULL : (ret_vec ? ret_vec : NEW_DB_NULL);
}


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
      dbg_printf (("compiling (%s) ...\n", pattern));
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
  bif_define_typed ("regexp_substr", bif_regexp_substr, &bt_varchar);
  bif_define_typed ("regexp_parse", bif_regexp_parse, &bt_any);
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

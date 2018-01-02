/*
 *  
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *  
 *  Copyright (C) 1998-2018 OpenLink Software
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
#include "langfunc.h"

#ifdef LANGFUNC_TEST
#include <string.h>
#include <stdio.h>
#endif

#ifdef _MSC_VER
#define strcasecmp stricmp
#endif

#define LANG_SUCCESS			0
#define LANG_TOO_MANY_HANDLERS		(-2)

/* Management functions for encoding handling */

#ifndef __NO_LIBDK
id_hash_t *eh_hash = NULL;
#else
#define LENGTHOF__eh_table 100
encoding_handler_t *eh_table[LENGTHOF__eh_table];
int eh_table_fill = 0;
#endif


int eh_load_handler (encoding_handler_t *new_handler)
{
#ifndef __NO_LIBDK
  char **names;
  if (NULL == eh_hash)
    eh_hash = id_hash_allocate (61, sizeof (char *), sizeof (encoding_handler_t *), strhashcase, strhashcasecmp);
  for (names = new_handler->eh_names; NULL != names[0]; names++)
    id_hash_set (eh_hash, (caddr_t)(&(names[0])), (caddr_t)(&new_handler));
  return LANG_SUCCESS;
#else
  int ctr;
  for (ctr = 0; ctr < eh_table_fill; ctr++)
    {
      if (new_handler == eh_table[ctr])
	return 0;
    }
  if (LENGTHOF__eh_table == eh_table_fill)
    return LANG_TOO_MANY_HANDLERS;
  eh_table[eh_table_fill++] = new_handler;
  return LANG_SUCCESS;
#endif
}


encoding_handler_t *eh_get_handler (const char *encoding_name)
{
#ifndef __NO_LIBDK
  encoding_handler_t **resptr;
  if (NULL == eh_hash)
    return NULL;
  resptr = (encoding_handler_t **)(id_hash_get (eh_hash, (caddr_t)(&encoding_name)));
  if (NULL == resptr)
    return NULL;
  return resptr[0];
#else
  int ctr;
  for (ctr = 0; ctr < eh_table_fill; ctr++)
    {
      encoding_handler_t *handler = eh_table[ctr];
      char **names;
      for (names = handler->eh_names; NULL != names[0]; names++)
	{
	  if (!strcmp (encoding_name, names[0]))
	    return handler;
	}
    }
  return NULL;
#endif
}


/* Management functions for Unicode language handling */

#ifndef __NO_LIBDK
id_hash_t *lh_hash = NULL;
#else
#define LENGTHOF__lh_table 100
lang_handler_t *lh_table[LENGTHOF__lh_table];
int lh_table_fill = 0;
#endif

int lh_load_handler (lang_handler_t *new_handler)
{
#ifndef __NO_LIBDK
  char *id;
#else
  int ctr;
#endif
#define LH_INHERITE(field) \
  if (NULL == new_handler->field) \
    new_handler->field = new_handler->lh_superlanguage->field;
  LH_INHERITE (lh_is_vtb_word)
  LH_INHERITE (lh_toupper_word)
  LH_INHERITE (lh_tolower_word)
  LH_INHERITE (lh_normalize_word)
  LH_INHERITE (lh_count_words)
  LH_INHERITE (lh_iterate_words)
  LH_INHERITE (lh_iterate_patched_words)
#ifdef HYPHENATION_OK
  LH_INHERITE(lh_iterate_hyppoints)
#endif
#undef LH_INHERITE

#ifndef __NO_LIBDK
  if (NULL == lh_hash)
    lh_hash = id_hash_allocate (61, sizeof (char *), sizeof (lang_handler_t *), strhashcase, strhashcasecmp);
  id = new_handler->lh_RFC1766_id;
  id_hash_set (lh_hash, (caddr_t)(&id), (caddr_t)(&new_handler));
  id = new_handler->lh_ISO639_id;
  if (
    (NULL == id_hash_get (lh_hash, (caddr_t)(&id))) ||
    !strcasecmp (id, new_handler->lh_RFC1766_id) )
    {
      id_hash_set (lh_hash, (caddr_t)(&id), (caddr_t)(&new_handler));
    }
  return LANG_SUCCESS;
#else
  for (ctr = 0; ctr < lh_table_fill; ctr++)
    {
      if (new_handler == lh_table[ctr])
	return LANG_SUCCESS;
    }
  if (LENGTHOF__lh_table == lh_table_fill)
    return LANG_TOO_MANY_HANDLERS;
  lh_table[lh_table_fill++] = new_handler;
  return LANG_SUCCESS;
#endif
}


lang_handler_t *lh_get_handler (const char *lang_name)
{
#ifndef __NO_LIBDK
  lang_handler_t **resptr;
  if (NULL == lh_hash)
    return NULL;
  resptr = (lang_handler_t **)id_hash_get (lh_hash, (caddr_t)(&lang_name));
  if (NULL == resptr)
    return &lh__xany;
  return resptr[0];
#else
  int ctr;
  for (ctr = 0; ctr < lh_table_fill; ctr++)
    {
      lang_handler_t *handler = lh_table[ctr];
      if (!strcasecmp (lang_name, handler->lh_RFC1766_id))
	return handler;
    }
  for (ctr = 0; ctr < lh_table_fill; ctr++)
    {
      lang_handler_t *handler = lh_table[ctr];
      if (!strcasecmp (lang_name, handler->lh_ISO639_id))
	return handler;
    }
  return &lh__xany;
#endif
}


/* Management functions for encoded language handling */

#ifndef __WITH_LIBDK
#define LENGTHOF__elh_table 100
struct elh_locator_s
{
  int elh_table_fill;
  encodedlang_handler_t *elh_table[LENGTHOF__elh_table];
};

typedef struct elh_locator_s elh_locator_t;
#endif


int elh_load_handler (encodedlang_handler_t *new_handler)
{
  encoding_handler_t *enc = new_handler->elh_base_encoding;
  lang_handler_t *lang = new_handler->elh_unicoded_language;
#ifndef __NO_LIBDK
  char *id;
  id_hash_t **hash_ptr = (id_hash_t **)(&(enc->eh_encodedlangs));
  if (NULL == hash_ptr[0])
    hash_ptr[0] = id_hash_allocate (13, sizeof (char *), sizeof (encodedlang_handler_t *), strhashcase, strhashcasecmp);
  id = lang->lh_RFC1766_id;
  id_hash_set (hash_ptr[0], (caddr_t)(&id), (caddr_t)(&new_handler));
  id = lang->lh_ISO639_id;
  if (
    (NULL == id_hash_get (hash_ptr[0], (caddr_t)(&id))) ||
    !strcasecmp (id, lang->lh_RFC1766_id) )
    {
      id_hash_set (hash_ptr[0], (caddr_t)(&id), (caddr_t)(&new_handler));
    }
  return LANG_SUCCESS;
#else
  elh_locator_t **locator_ptr = (elh_locator_t **)(&(enc->eh_encodedlangs));
  int ctr;
  if (NULL == locator_ptr[0])
    {
      locator_ptr[0] = (elh_locator_t *)(malloc (sizeof (elh_locator_t)));
      locator_ptr[0]->elh_table_fill = 0;
    }
  for (ctr = 0; ctr < locator_ptr[0]->elh_table_fill; ctr++)
    {
      if (new_handler == locator_ptr[0]->elh_table[ctr])
	return LANG_SUCCESS;
    }
  if (LENGTHOF__elh_table == locator_ptr[0]->elh_table_fill)
    return LANG_TOO_MANY_HANDLERS;
  locator_ptr[0]->elh_table[locator_ptr[0]->elh_table_fill++] = new_handler;
  return LANG_SUCCESS;
#endif
}


encodedlang_handler_t *elh_get_handler (encoding_handler_t *enc, lang_handler_t *lang)
{
#ifndef __NO_LIBDK
  char *id;
  encodedlang_handler_t **resptr;
  id_hash_t **hash_ptr;
  if (NULL == enc)
    return NULL;
  hash_ptr = (id_hash_t **)(&(enc->eh_encodedlangs));
  if (NULL == hash_ptr[0])
    return NULL;
  id = lang->lh_RFC1766_id;
  resptr = (encodedlang_handler_t **)id_hash_get (hash_ptr[0], (caddr_t)(&id));
  if (NULL == resptr)
    return NULL;
  return resptr[0];
#else
  int ctr;
  elh_locator_t **locator_ptr;
  if (NULL == enc)
    return NULL;
  locator_ptr = (elh_locator_t **)(&(enc->eh_encodedlangs));
  if (NULL == locator_ptr[0])
    return 0;
  for (ctr = 0; ctr < locator_ptr[0]->elh_table_fill; ctr++)
    {
      encodedlang_handler_t *handler = locator_ptr[0]->elh_table[ctr];
      if (!strcasecmp (lang->lh_RFC1766_id, handler->elh_unicoded_language->lh_RFC1766_id))
	return handler;
    }
  for (ctr = 0; ctr < locator_ptr[0]->elh_table_fill; ctr++)
    {
      encodedlang_handler_t *handler = locator_ptr[0]->elh_table[ctr];
      if (!strcasecmp (lang->lh_RFC1766_id, handler->elh_unicoded_language->lh_ISO639_id))
	return handler;
    }
  return NULL;
#endif
}


#ifndef __NO_LIBDK

unit_version_t langfunc_version = {
  "Virtuoso LangFunc library", 		/*!< Title of unit, filled by unit */
  "2.5", 				/*!< Version number, filled by unit */
  "OpenLink Software", 			/*!< Plugin's developer, filled by unit */
  "", 					/*!< Any additional info, filled by unit */
  NULL, 					/*!< Error message, filled by unit loader */
  NULL, 					/*!< Name of file with unit's code, filled by unit loader */
  NULL, 					/*!< Pointer to connection function, cannot be NULL */
  NULL, 					/*!< Pointer to disconnection function, or NULL */
  NULL, 					/*!< Pointer to activation function, or NULL */
  NULL, 					/*!< Pointer to deactivation function, or NULL */
  NULL					/*!< Platform-specific data for run-time linking tricks */
};

unit_version_t *langfunc_plugin_load (const char *plugin_dll_name, const char *plugin_load_path)
{
  size_t filename_buflen = strlen (plugin_load_path) + 1 + strlen (plugin_dll_name) + 1;
  size_t funname_buflen = strlen (plugin_dll_name) + 6 /* == strlen ("_check") */ + 1;
  char *filename, *funname;
  filename = (char *) dk_alloc (filename_buflen);
  snprintf (filename, filename_buflen, "%s/%s", plugin_load_path, plugin_dll_name);
  funname = (char *) dk_alloc (funname_buflen);
  snprintf (funname, funname_buflen, "%s_check", plugin_dll_name);
  return uv_load_and_check_plugin (filename, funname, &langfunc_version, NULL);
}

/*! \brief Type of function registered via plugin_add_type and used by
    plugin_load to invoke uv_connect of a plugin with proper appdata */
void langfunc_plugin_connect (const unit_version_t *plugin)
{
  UV_CALL (plugin, uv_connect, NULL);
}

#endif

extern void unicode3_init_char_combining_hashtables (void);
extern eh_charset_t eh_generic_chardefs[];
extern int eh_generic_chardefs_length;
extern void connect__enUS (void *appdata);
extern void connect__xViDoc (void *appdata);
extern void connect__xViAny (void *appdata);

void langfunc_kernel_init (void)
{
  static int done = 0;
  int ctr;
  if (done)
    return;
  done = 1;
  reset_work_uniblocks ();
  unicode3_init_char_combining_hashtables ();
  eh_load_handler (&eh__UCS4);
  eh_load_handler (&eh__UCS4BE);
  eh_load_handler (&eh__UCS4LE);
  eh_load_handler (&eh__UTF16);
  eh_load_handler (&eh__UTF16BE);
  eh_load_handler (&eh__UTF16LE);
  eh_load_handler (&eh__UTF8);
  eh_load_handler (&eh__UTF8_QR);
  eh_load_handler (&eh__ASCII);
  eh_load_handler (&eh__ISO8859_1);
  eh_load_handler (&eh__WIDE_121);
  for (ctr = 0; ctr < eh_generic_chardefs_length; ctr++)
    {
      encoding_handler_t * eh = eh_create_charset_handler (eh_generic_chardefs+ctr);
      if (NULL != eh)
	eh_load_handler (eh);
    }
  lh_load_handler (&lh__xany);
  lh_load_handler (&lh__xftqxany);
  elh_load_handler (&elh__xany__UTF8);
  connect__enUS (NULL);
  connect__xViDoc (NULL);
  connect__xViAny (NULL);
}


void langfunc_plugin_init (void)
{
#ifndef __NO_LIBDK
  plugin_add_type ("LangFunc", langfunc_plugin_load, langfunc_plugin_connect);
#endif
}


int lh_count_words (encoding_handler_t *eh, lang_handler_t *lh, const char *buf, size_t bufsize, lh_word_check_t *check)
{
  unichar *unidata;
  int unidatabuflen, unidatalen, res;
  encodedlang_handler_t *elh = elh_get_handler (eh, lh);
  const char *tmp;
  int eh_state = 0;
  if (NULL != elh)
    return elh->elh_count_words (buf, bufsize, check);
  unidatabuflen = (int) ((sizeof (unichar)*bufsize) / (eh->eh_minsize))|0xFF;
  unidata = (unichar *) dk_alloc (unidatabuflen);
  tmp = buf;
  unidatalen = eh->eh_decode_buffer (unidata, unidatabuflen / sizeof (unichar), &tmp, buf+bufsize, eh, &eh_state);
  if (unidatalen < 0)
    {
      res = unidatalen;
      goto done;
    }
  if ((buf+bufsize) != tmp) /* Abnormal break at decoding time */
    {
      res = eh->eh_decode_char (&tmp, buf+bufsize, eh, &eh_state); /* This should reproduce a bug and return error code */
      goto done;
    }
  res = lh->lh_count_words (unidata, unidatalen, check);

done:
  dk_free (unidata, unidatabuflen);
  return res;
}


int lh_iterate_words (encoding_handler_t *eh, lang_handler_t *lh, const char *buf, size_t bufsize, lh_word_check_t *check, lh_word_callback_t *callback, void *userdata)
{
  unichar *unidata;
  int unidatabuflen, unidatalen, res;
  encodedlang_handler_t *elh = elh_get_handler (eh, lh);
  const char *tmp;
  int eh_state = 0;
  if (NULL != elh)
    {
      elh->elh_iterate_words (buf, bufsize, check, callback, userdata);
      return 0;
    }
  unidatabuflen = (int) ((sizeof (unichar)*bufsize) / (eh->eh_minsize))|0xFF;
  unidata = (unichar *) dk_alloc (unidatabuflen);
  tmp = buf;
  unidatalen = eh->eh_decode_buffer (unidata, unidatabuflen / sizeof (unichar), &tmp, buf+bufsize, eh, &eh_state);
  if (unidatalen < 0)
    {
      res = unidatalen;
      goto done;
    }
  if ((buf+bufsize) != tmp) /* Abnormal break at decoding time */
    {
      res = eh->eh_decode_char (&tmp, buf+bufsize, eh, &eh_state); /* This should reproduce a bug and return error code */
      goto done;
    }
  lh->lh_iterate_words (unidata, unidatalen, check, callback, userdata);
  res = 0;

done:
  dk_free (unidata, unidatabuflen);
  return res;
}


int lh_iterate_patched_words (encoding_handler_t *eh, lang_handler_t *lh, const char *buf, size_t bufsize, lh_word_check_t *check, lh_word_patch_t *patch, lh_word_callback_t *callback, void *userdata)
{
  unichar *unidata;
  int unidatabuflen, unidatalen, res;
  encodedlang_handler_t *elh = elh_get_handler (eh, lh);
  const char *tmp;
  int eh_state = 0;
  if (NULL != elh)
    {
      elh->elh_iterate_patched_words (buf, bufsize, check, patch, callback, userdata);
      return 0;
    }
  unidatabuflen = (int) ((sizeof (unichar)*bufsize) / (eh->eh_minsize))|0xFF;
  unidata = (unichar *) dk_alloc (unidatabuflen);
  tmp = buf;
  unidatalen = eh->eh_decode_buffer (unidata, unidatabuflen / sizeof (unichar), &tmp, buf+bufsize, eh, &eh_state);
  if (unidatalen < 0)
    {
      res = unidatalen;
      goto done;
    }
  if ((buf+bufsize) != tmp) /* Abnormal break at decoding time */
    {
      res = eh->eh_decode_char (&tmp, buf+bufsize, eh, &eh_state); /* This should reproduce a bug and return error code */
      goto done;
    }
  lh->lh_iterate_patched_words (unidata, unidatalen, check, patch, callback, userdata);
  res = 0;

done:
  dk_free (unidata, unidatabuflen);
  return res;
}


#ifdef LANGFUNC_TEST

#ifndef __NO_LIBDK
#include "plugin.h"
#endif
#if 0
#define TEST_IN "/binsrc/tests/langfunc/in2.txt"
#define TEST_OUT "/binsrc/tests/langfunc/out2.txt"
#else
#define TEST_IN "in2.txt"
#define TEST_OUT "out2.txt"
#endif
FILE *in;
FILE *out;


void test_logger (const char *format, ...)
{
  va_list ap;
  va_start (ap, format);
  vfprintf (out, format, ap);
  vprintf (format, ap);
  va_end (ap);
}


#ifndef __NO_LIBDK
extern unit_version_t plugin_version_lang__ru__RU;
#endif

void utf8_dump (const utf8char *buf, size_t bufsize)
{
  size_t ctr;
  for (ctr = 0; ((bufsize != (size_t)(-1)) ? (ctr < bufsize) : buf[ctr]); ctr++)
    {
      if ((buf[ctr] & 0x80) || (! (buf[ctr] & 0xE0)))
	test_logger ("\\x%04x", (unsigned int)(buf[ctr]));
      else
	test_logger ("%c", (char)(buf[ctr]));
    }
}

void test_word_callback (const utf8char *buf, size_t bufsize, void *userdata)
{
  test_logger ("test_word_callback ('");
  utf8_dump (buf, bufsize);
  test_logger ("', 0x%08x)\n", (int)(userdata));
}

int main (int argc, char *argv[])
{
  static char src_buf[0x10000];
  char *cmd, *enc, *lang, *data, *tmp;
  size_t datalen;
  encoding_handler_t *eh;
  int res;
  lang_handler_t *lh;

  out = fopen (TEST_OUT, "wt");
  if (NULL == out)
    {
      printf ("\nERROR: Can't write to %s\n", TEST_OUT);
      return 1;
    }
  in = fopen (TEST_IN, "rt");
  if (NULL == in)
    {
      test_logger ("\nERROR: Can't read from %s\n", TEST_IN);
      return 1;
    }
  langfunc_kernel_init ();

#ifndef __NO_LIBDK
  plugin_version_lang__ru__RU.uv_connect (NULL);
#endif

  while (NULL != fgets (src_buf, 0xFFFF, in))
    {
      cmd = enc = lang = data = tmp = NULL;
      if ('#' == src_buf[0])	/* Is it comment ? */
	continue;
      cmd = strchr (src_buf, '|');
      if (NULL == cmd)
	{
	  if ('\n' != src_buf[0])
	    test_logger ("\nERROR: Line has no command:\n[%s]\n", src_buf);
	  continue;
	}
      enc = strchr (cmd+1, '|');
      if (NULL == enc)
	{
	  test_logger ("\nERROR: Line has no encoding specification:\n[%s]\n", src_buf);
	  continue;
	}
      lang = strchr (enc+1, '|');
      if (NULL == lang)
	{
	  test_logger ("\nERROR: Line has no language specification:\n[%s]\n", src_buf);
	  continue;
	}
      data = strchr (lang+1, '|');
      if (NULL == data)
	{
	  test_logger ("\nERROR: Line has no data to proceed:\n[%s]\n", src_buf);
	  continue;
	}
      cmd[0] = '\0'; cmd++;
      enc[0] = '\0'; enc++;
      lang[0] = '\0'; lang++;
      data[0] = '\0'; data++;
      for (tmp = cmd;  (((' '<tmp[0]) && ('|'!=tmp[0])) ? 1 : (tmp[0]='\0')); tmp++);
      for (tmp = enc;  (((' '<tmp[0]) && ('|'!=tmp[0])) ? 1 : (tmp[0]='\0')); tmp++);
      for (tmp = lang; (((' '<tmp[0]) && ('|'!=tmp[0])) ? 1 : (tmp[0]='\0')); tmp++);
      datalen = strlen (data);
      datalen--;
      data[datalen] = '\0';
      datalen = strlen (data);
      if (!strcmp (cmd, "load_eh_ucm"))
	{
	  encoding_handler_t *new_eh;
	  test_logger ("\nTest [%s]: command=%s, encoding=%s, language=%s.\n[%s]\n", src_buf, cmd, enc, lang, data);
	  new_eh = eh_create_ucm_handler (enc, data, test_logger, test_logger);
	  if (NULL != new_eh)
	    eh_load_handler (new_eh);
	  continue;
	}
      test_logger ("\nTest [%s]: command=%s, encoding=%s, language=%s.\n[%s]\n", src_buf, cmd, enc, lang, data);
      eh = eh_get_handler (enc);
      if (NULL == eh)
	{
	  test_logger ("\nNo encoding found\n");
	  continue;
	}
      else
        {
	  unichar decoded[0x1000];
	  char loopback[0x1000];
	  char *data_tail = data;
	  int res = eh->eh_decode_buffer (decoded, 0x1000, &data_tail, data+datalen);
	  test_logger ("\nProbe decoding returned %d at [%s]", res, data_tail);
	  if (res >= 0)
	    {
	      char *loopback_end = eh->eh_encode_buffer (decoded, decoded+res, loopback, loopback+0x1000);
	      if (loopback_end >= loopback)
		{
		  loopback_end[0] = '\0';
		  test_logger ("\nProbe loopback encoding: %s, returned [%s]",
		    ((((loopback_end-loopback)==datalen) && !memcmp(loopback,data,datalen)) ? "SUCCESS" : "FAILURE"),
		    loopback );
		}
	    }
	}
      lh = lh_get_handler (lang);
      test_logger ("\nHandler %s will be used.\n[%s]\n", lh->lh_RFC1766_id);
      if (!strcmp (cmd, "count_all"))
	{
	  res = lh_count_words (eh, lh, data, datalen, NULL);
	  test_logger ("returns %d\n", res);
	  continue;
	}
      if (!strcmp (cmd, "count_vtb"))
	{
	  res = lh_count_words (eh, lh, data, datalen, lh->lh_is_vtb_word);
	  test_logger ("returns %d\n", res);
	  continue;
	}
      if (!strcmp (cmd, "iterate_all"))
	{
	  res = lh_iterate_words (eh, lh, data, datalen, NULL, test_word_callback, (void *)(0xdeadbeef));
	  test_logger ("returns %d\n", res);
	  continue;
	}
      if (!strcmp (cmd, "iterate_vtb"))
	{
	  res = lh_iterate_words (eh, lh, data, datalen, lh->lh_is_vtb_word, test_word_callback, (void *)(0xdeadbeef));
	  test_logger ("returns %d\n", res);
	  continue;
	}
      if (!strcmp (cmd, "iterate_vtb_upc"))
	{
	  res = lh_iterate_patched_words (eh, lh, data, datalen, lh->lh_is_vtb_word, lh->lh_toupper_word, test_word_callback, (void *)(0xdeadbeef));
	  test_logger ("returns %d\n", res);
	  continue;
	}
      test_logger ("No test code for [%s] command\n", cmd);
      res = 999999;
    }
  fclose (out);
  fclose (in);
  return 0;
}
#endif

#include "encoding_wide.c"

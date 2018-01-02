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
#ifndef _LANGFUNC_H
#define _LANGFUNC_H
#include <string.h>
#include <ctype.h>

#ifndef __NO_LIBDK
#include "Dk.h"
#include "plugin.h"
#else
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
typedef unsigned int uint32;
#define dk_alloc(size) malloc((size))
#define dk_free(ptr,size) free((ptr))
#ifdef DEBUG
#define dbg_printf(list) printf list
#else
#define dbg_printf(list)
#endif
#endif

#include "exe_export.h"

/*! \file
\brief Functions and data structures for language-specific text processing

This file defines some typedefs for language-specific functions. Such
functions SHOULD have names of form
<CODE>handler_functionalityname[__langname[__countryname]][__encoding]</CODE>
e.g.

\c elh_count_all_words__xany__UTF8 - function to count all words for
UTF8 language handler of mixed text

\c lh_iterate_hyphenation_points__ru - function to build hyphenation in
Russian text (Unicode text, because lh_ stands for Unicode language_handler_t)

The following abbreviations are used below:

<CODE>..._vtb_...</CODE> - if function ignores noise words which should not
be indexed by free-text-search engine.

<CODE>..._upc_...</CODE> - if function converts all words uppercase before
using.

<CODE>..._norm_...</CODE> - if function converts all words to its canonical
form (e.g. turns plural form of noun into into singular). Such "normalization"
is appliable to "indexable" words only and assumes conversion to uppercase
as first step.

All language handlers are organized in hierarchical trees. The root of
tree for "human" languages is a built-in handler for "x-any" "language",
used when there's no information about actual language at all. Some specific
language, (esp. ideographical) may require more "smart" support than "x-any"
provides, and an additional handler may implement some functions in better
way, having NULL fields for others. If language handler has NULL instead of
pointer to function, its lh_superlanguage member will be used to locate more
generic handler; if generic handler has NULL again, its lh_superlanguage will
be invoked and so on. "x-any" has all functions.

Another top-level language is "x-ftq-x-all" language for free-text queries
on multilingual texts. Every language may have its own free-text query
language, in such case handler of human language will have non-NULL
lh_ftq_handler pointer to locate handler for query language.

A large number of 1-byte "national" encodings are "bound" to some languages
because if you use some alphabet in the text, it's obviously the script for
some particular language or group of languages. To accelerate processing,
a pair of language and encoding may be processed by a handler for
"encoded language". For application-specific callbacks, there's no difference,
where they are called from -- they receive UTF-8 strings in any case.

"encoded language" handlers are not organized in a tree. Instead, every such
handler has pointer to Unicode handler of the same language, and to encoding
handler. If a function missing in handler, source text will be converter to
Unicode and passed to Unicode handler, without loss of information. Similar
procedure will be used if there's no "encoded language" handler at all for
some language.

Neither Unicode language handlers nor "encoded language" handlers may be
modified after their loading, because other's handlers may be attached to the
tree as children of already installed handlers. In addition, NULL pointers
to functions may be replaced with some special values, to accelerate searches
for appropriate functions. */



struct encoding_handler_s;	/* see below */
struct lang_handler_s;		/* see below */
struct encodedlang_handler_s;	/* see below */

#ifndef UTF8CHAR_DEFINED
#define UTF8CHAR_DEFINED
typedef unsigned char utf8char;			/*!< 8-bit chars of UTF-8 strings */
#endif

#ifndef UNICHAR_DEFINED
#define UNICHAR_DEFINED
typedef int unichar;				/*!< 31-bit unicode values, negative ones are invalid */
#endif

#define UNICHAR_EOD		((unichar)(-2))	/*!< End of source buffer reached, no data to convert */
#define UNICHAR_NO_DATA		((unichar)(-3))	/*!< Source buffer is too short, but nonempty (contains part of a char) */
#define UNICHAR_NO_ROOM		((unichar)(-4))	/*!< Target buffer is too short */
#define UNICHAR_BAD_ENCODING	((unichar)(-5))	/*!< Invalid character decoded from invalid string */
#define UNICHAR_OUT_OF_WCHAR	((unichar)(-6))	/*!< The encoded data are valid but the encoded character is out of 16-bit range and will not fit 2-byte wchar_t. */

/*! \brief Maximum length of a word

The longest known English word is 45 chars long:<PRE>
	  1	        2	      3	           4
1234 567890 123 45 678 9012 34 567 8 90 123 456789 012 345
pneu-monoul-tra-mi-cro-scop-ic-sil-i-co-vol-canoco-nio-sis</PRE>

The longest name is 58 chars long:<PRE>
           1	       2	     3	    	  4		5
1234 5678 9012 3456 7890 12 345 6 789012 345 6789 0123 45 678 9 0 12 34 5678
Llan-fair-pwll-gwyn-gyll-go-ger-y-chwyrn-dro-bwll-llan-ty-sil-i-o-go-go-goch</PRE>

The absolute limit is 65. It allows us to filter out such "words"
as UUENCODE strings, EPS bitmaps and raster fonts etc. Such "text-like" data,
when stored inside DAV resources, may double the size of database easily. */
#define WORD_MAX_CHARS 65

/*! \brief Maximum supported number of significant bytes of encoding sequence for one Unicode char. */
#define MAX_ENCODED_CHAR 8

/*! \brief Maximum length of UTF-8 encoding sequence for one Unicode char */
#define MAX_UTF8_CHAR 6

/*! \brief Maximum length of UTF-16 encoding sequence for one Unicode char */
#define MAX_UTF16_CHAR 4
/*! \brief Minimum length of UTF-16 encoding sequence for one Unicode char */
#define MIN_UTF16_CHAR 2

/*! \brief Returns if the given char is a "continuation" char of UTF-8 encoding */
#define IS_UTF8_CHAR_CONT(ch) (((ch) & 0xC0) == 0x80)

/*! \brief Buffer for storing ISO 639 language id or RFC 1766 long language id */
#define BUFSIZEOF__LANG_ID 33
/*! \brief Buffer for storing name of encoding */
#define BUFSIZEOF__ENCODING_ID 21

/*! \brief Buffer for storing UTF-8 word of any human language, including trailing zero if needed */
#define BUFSIZEOF__UTF8_WORD (WORD_MAX_CHARS*3+1)

/*! \brief Checks if given UCS-4 character is language tag */
#define IS_UCS4_CHAR_LANG_TAG(ptr) \
 (0xE0000 == ((ptr)[0] & ~0x7F))

/*! \brief Checks if given UTF-16 character is language tag */
#define IS_UTF16_CHAR_LANG_TAG(ptr) \
 ((0xDB40 == (ptr)[0]) && (0xDC00 == ((ptr)[1] & ~0x7F)))

/*! \brief Checks if given UTF-8 character is language tag */
#define IS_UTF8_CHAR_LANG_TAG(ptr) \
 ((0xF3 == (ptr)[0]) && (0xA0 == (ptr)[1]) && (0x80 == ((ptr)[2] & ~0x01)))



/*! \brief Type of function returning bitmask of given unichar's properties */
typedef int unichar_getprops_t(unichar uchr);

/*! \brief Type of function returning given unichar uppercased */
typedef unichar unichar_getucase_t(unichar uchr);

/*! \brief Type of function returning given unichar lowercased */
typedef unichar unichar_getlcase_t(unichar uchr);

#ifdef LANGFUNC_TEST
#include <stdio.h>
extern FILE *out;
void unicode_dump (const unichar *buf, size_t bufsize);
#endif



#define UCP_ALPHA	0x0001
#define UCP_PUNCT	0x0002
#define UCP_IDEO	0x0004
#define UCP_BAD		0x0800
#define UCP_MIX		0x4000
#define UCP_GAP		0x8000

/*! \brief Description of a block of Unicode symbols

To make unicode processing extendable, all character positions were subdivided
on some consequent ranges. Each range contains information about one subset of
characters, e.g. about one script. Each range has its own functions to get
properties of any given unichar from that range.

Any language plugin may assign its own functions for any block. Before such
assignment, it's good safety measure to check if block's boundaries match those
you expect, and to ensure that there's no function set for this block by some
other plugin. OpenLink Virtuoso will never de-initialize language plugins, but
other products may, so it's good idea to reset affected blocks in plugin's
"deinit" function. */
struct unicode_block_s
{
  char *ub_descr;	/*!< description of the block, as in Unicode doc */
  int ub_props;		/*!< default properties for symbols from \c this block */
  unichar ub_min;	/*!< bottom boundary (smallest unichar in block) */
  unichar ub_max;	/*!< upper boundary (largest unichar in block) */
  unichar_getprops_t *ub_getprops;	/*!< Function to return properties of a char*/
  unichar_getucase_t *ub_getucase;	/*!< Function to uppercase given unichar */
  unichar_getucase_t *ub_getlcase;	/*!< Function to lowercase given unichar */
};

typedef struct unicode_block_s unicode_block_t;

extern unicode_block_t *raw_uniblocks_array;
extern unicode_block_t *work_uniblocks_array;

extern int raw_uniblocks_fill;
extern int work_uniblocks_fill;

/*! \brief Resets internal table of blocks to some initial state */
int reset_work_uniblocks(void);

/*! \brief Returns block containing given unichar, or NULL for invalid unichar */
unicode_block_t *ub_getblock(unichar uchr);

/*! \brief Returns given unichar uppercased, based on data from Unicode3 tables */
extern unichar unicode3_getucase (unichar uchr);
/*! \brief Returns given unichar lowercased, based on data from Unicode3 tables */
extern unichar unicode3_getlcase (unichar uchr);
/*! \brief Returns given unichar converted to a base char (i.e. remove umlauts, accents etc.) */
extern unichar unicode3_getbasechar (unichar uchr);
/*! \brief An accelerated superposition of unicode3_getbasechar and then unicode3_getucase */
extern unichar unicode3_getupperbasechar (unichar uchr);
/*! \brief Returns a char that is combination of a base char and NSM modifier, i.e. slightly "inverse" to unicode3_getbasechar */
extern unichar unicode3_combine_base_and_modif (unichar base, unichar modif);
/*! \brief An accelerated superposition of unicode3_combine_base_and_modif and then unicode3_getucase */
extern unichar unicode3_combine_base_and_modif_upper (unichar base, unichar modif);
/*! \brief Returns if given unichar is a 'logical space' character */
extern int unicode3_isspace (unichar uchr);
/*! \brief The minimal nonspacing modifier (NSM) char like umlaut or accent to modify other character */
extern unichar unicode3_min_used_modif_char;
/*! \brief The maximal nonspacing modifier (NSM) char like umlaut or accent to modify other character. Not every char between \c unicode3_min_used_modif_char and this one is an NSM, but all NSMs actually used as modifiers falls in this interval */
extern unichar unicode3_max_used_modif_char;


/*! \brief Returns properties of unichar */
EXE_EXPORT (int, unichar_getprops, (unichar uchr));
/*! \brief Returns given unichar uppercased, faster than unichar3_getucase(), but maybe less accurate */
EXE_EXPORT (unichar, unichar_getucase, (unichar uchr));
/*! \brief Returns given unichar lowercased, faster than unichar3_getlcase(), but maybe less accurate */
EXE_EXPORT (unichar, unichar_getlcase, (unichar uchr));

/*! \brief Returns nonzero if given unichar is alphabetical character */
#define IS_UNICHAR_ALPHA(uchr) (unichar_getprops(uchr) & UCP_ALPHA)
/*! \brief Returns nonzero if given unichar is punctuation or typographical mark */
#define IS_UNICHAR_PUNCT(uchr) (unichar_getprops(uchr) & UCP_PUNCT)



typedef const char *__constcharptr;

/*! \brief Type for function to get encoded char from \c char_begin_ptr[0] as \c unichar

This function should advance char_begin_ptr[0] to the next unichar.
Some functions of this type may expect to receive pointer to encoding_handler_t as
additional argument (as ...). When in trouble, be careful and pass it.
Some functions of this type may expect to receive not only a pointer to encoding_handler_t
but a pointer to the encoding state of type int *. When in trouble, be careful and pass it.
\return decoded value, UNICHAR_NO_DATA, UNICHAR_BAD_ENCODING or other negative error code. */
typedef unichar eh_decode_char_t (__constcharptr *src_begin_ptr, const char *src_buf_end, ...);

/*! \brief Type for function to get encoded string from \c char_begin_ptr[0] as \c unichar string

This function should decode as much as \c tgt_buf_len chars, with advancing char_begin_ptr[0]
to the first unichar not yet decoded. If there's not enough data to decode even one char,
UNICHAR_NO_DATA will be returned. If source string is bad, UNICHAR_BAD_ENCODING should be
returned as late as it is possible.
Some functions of this type may expect to receive pointer to encoding_handler_t as
additional argument (as ...). When in trouble, be careful and pass it.
Some functions of this type may expect to receive not only a pointer to encoding_handler_t
but a pointer to the encoding state of type int *. When in trouble, be careful and pass it. */
typedef int eh_decode_buffer_t (unichar *tgt_buf, int tgt_buf_len, __constcharptr *src_begin_ptr, const char *src_buf_end, ...);

/*! \brief Type for function to get encoded string from \c char_begin_ptr[0] as \c wchar_t string

The type is almost identical to eh_decode_buffer_t, the only difference is wchar_t vs unichar */
typedef int eh_decode_buffer_to_wchar_t (wchar_t *tgt_buf, int tgt_buf_len, __constcharptr *src_begin_ptr, const char *src_buf_end, ...);

/*! \brief Type for function to encode given unichar and put the result under \c tgt_buf_begin

Some functions of this type may expect to receive pointer to encoding_handler_t as
additional argument (as ...). When in trouble, be careful and pass it.
Some functions of this type may expect to receive not only a pointer to encoding_handler_t
but a pointer to the encoding state of type int *. When in trouble, be careful and pass it.
\return past-the end pointer in target buffer, or NULL if there's no room for encoded value */
typedef char *eh_encode_char_t (unichar char_to_put, char *tgt_buf, char *tgt_buf_end, ...);

/*! \brief Type for function to encode given unichar buffer and put the result under \c tgt_buf_begin

Some functions of this type may expect to receive pointer to encoding_handler_t as
additional argument (as ...). When in trouble, be careful and pass it.
Some functions of this type may expect to receive not only a pointer to encoding_handler_t
but a pointer to the encoding state of type int *. When in trouble, be careful and pass it.
\return past-the end pointer in target buffer, or NULL if there's no room for encoded value */
typedef char *eh_encode_buffer_t (const unichar *src_buf, const unichar *src_buf_end, char *tgt_buf, char *tgt_buf_end, ...);

/*! \brief Type for function to encode given wchar_t buffer and put the result under \c tgt_buf_begin

The type is almost identical to eh_encode_buffer_t, the only difference is wchar_t vs unichar */
typedef char *eh_encode_wchar_buffer_t (const wchar_t *src_buf, const wchar_t *src_buf_end, char *tgt_buf, char *tgt_buf_end, ...);

struct encoding_handler_s {
  char ** eh_names;		/*!< list of names of the encoding, terminated by NULL member */
  size_t eh_minsize;		/*!< minimum length of one unichar's encoded value */
  size_t eh_maxsize;		/*!< maximum length of one unichar's encoded value */
  int eh_byteorder;		/*!< the expected byteorder of data, if nonzero; used for 16- and 32-bit encodings */
  int eh_stable_ascii7;		/*!< Nonzero if the encoding translates any single 7-bit byte to identical unichar */
  void *eh_encodedlangs;	/*!< Data for finding language handlers, filled by application, should be NULL initially */
  void *eh_appdata;		/*!< Application-specific data for this encoding, should be NULL initially */
  eh_decode_char_t *eh_decode_char;	/*!< Char-by-char decoder */
  eh_decode_buffer_t *eh_decode_buffer;			/*!< Buffer decoder, unichar */
  eh_decode_buffer_to_wchar_t *eh_decode_buffer_to_wchar;	/*!< Buffer decoder, wchar_t */
  eh_encode_char_t *eh_encode_char;	/*!< Char-by-char encoder */
  eh_encode_buffer_t *eh_encode_buffer;			/*!< Buffer encoder, unichar */
  eh_encode_wchar_buffer_t *eh_encode_wchar_buffer;	/*!< Buffer encoder, wchar_t */
};

typedef struct encoding_handler_s encoding_handler_t;

/*! \brief Loads given handler in global table, using all names from new_handler->eh_names

Note that there's no way to unload a language handler. Once loaded, encoding is
available until program ends. */
EXE_EXPORT (int, eh_load_handler, (encoding_handler_t *new_handler));
/*! \brief Returns handler for encoding with given name, or NULL */
EXE_EXPORT (encoding_handler_t *, eh_get_handler, (const char *encoding_name));



/* A new encoding handler may be automatically created for single-byte encoding
   if a forward (E2U) translation table is known for that encoding.
*/

/*! \brief Internal type for reverse charset translation from unichar to char */
typedef unsigned ecs_revchar_t[6];

/*! \brief Charset with data for quick reverse translation */
struct eh_charset_s
{
  unsigned ecs_chars[0x100];	/*! \brief Forward translation table */
  char *ecs_names;		/*! \brief All names of charset,delimited by '|' char */

  unsigned ecs_revbytes[0x100];	/*! \brief Reverse translation table for unichars smaller than 0x100 */
  ecs_revchar_t ecs_revhash[0x100];	/*! \brief Reverse translation hashtable for unichars larger than 0xFF */
  int ecs_loaded;		/*! \brief Flags if charset was converted to encoding and should not be touched more */
};

typedef struct eh_charset_s eh_charset_t;


EXE_EXPORT (encoding_handler_t *, eh_duplicate_handler, (encoding_handler_t *pattern, char *new_encoding_names));

/*! \brief Creates encoding handler from given charset
\return Pointer to new handler on success, NULL on any failure. */
EXE_EXPORT (encoding_handler_t *, eh_create_charset_handler, (eh_charset_t *ecs));


/*! \brief Wraps given encoding handler into a new handler that converts wchar_t data to char data

Creates encoding handler for wchar_t string that treats every wchar_t as
a single 8-bit character, ignoring redundand zero bytes. If the wchar_t
is greater than 255 then an error is signalled. Otherwise the 8-bit
value is passed into an underlaying 'plain' handler that converts it to
Uniclode as usual.

\return Pointer to a new handler or to an previously created wrapper from cache hashtable. */
EXE_EXPORT (encoding_handler_t *, eh_wide_from_narrow, (encoding_handler_t *eh_narrow));

/*! A new encoding handler may be automatically created for any multibyte encoding
   if a UCM file is available for that encoding.
\return Pointer to new handler on success, NULL on any failure. */

/* \brief Type of function to call for logging messages or errors */
typedef void eh_ucm_log_callback (char *format, ...);

EXE_EXPORT (encoding_handler_t *, eh_create_ucm_handler, (char *encoding_names, char *ucm_file_name, eh_ucm_log_callback *info_logger, eh_ucm_log_callback *error_logger));



struct id_hash_s;
extern struct id_hash_s *lh_noise_words;

/*! \brief Type for function to be called once for every fragment (e.g. word) in some utf8char buffer */
typedef void lh_word_callback_t(const utf8char *buf, size_t bufsize, void *userdata);

/*! \brief Type for function to check if the word in buffer must be counted or passed to user's callback */
typedef int lh_word_check_t(const unichar *buf, size_t bufsize);

/*! \brief Type for function to modify the word in buffer */
typedef int lh_word_patch_t(const unichar *srcbuf, size_t srcbufsize, unichar *tgtbuf, size_t *tgtbufsize);

/*! \brief Type for function for finding number of (some) words in given unichar buffer */
typedef int lh_count_words_t(const unichar *buf, size_t bufsize, lh_word_check_t *check);

/*! \brief Type for function to apply given \c callback to (some) words in given unichar buffer

Note that it receives unichar buffer, but passes utf8char buffer to the callback.*/
typedef void lh_iterate_words_t(const unichar *buf, size_t bufsize, lh_word_check_t *check, lh_word_callback_t *callback, void *userdata);

/*! \brief Type for function to apply given \c callback to (some) words in given unichar buffer

Note that it receives unichar buffer, but passes utf8char buffer to the callback. */
typedef void lh_iterate_patched_words_t(const unichar *buf, size_t bufsize, lh_word_check_t *check, lh_word_patch_t *patch, lh_word_callback_t *callback, void *userdata);

/*! \brief Table of functions specific for particular language */
struct lang_handler_s
{
  /*! \brief ISO 639 language id such as "en" or "ja"

User-defined language tags starting with the characters "x-", e.g.
"x-western-musical-notation". Being case-insensitive, it should be stored
lowercase. */
  char lh_ISO639_id[BUFSIZEOF__LANG_ID];

  /*! \brief RFC 1766 long language id such as "en-US" or "ja-JA"

This notation is a composition of ISO 639 language id plus
ISO 3166 country id. Being case-insensitive, it should be stored as
lowercase ISO 639 language id plus uppercase ISO 3166 country id. */
  char lh_RFC1766_id[BUFSIZEOF__LANG_ID];

  /*! \brief Pointer to more generic language/dialect than \c this one

  The most generic "language" is built-in "x-any" language */
  struct lang_handler_s *lh_superlanguage;

  /*! \brief Pointer to free-text query language, specific for this language, or NULL

  Name of free-text query language usually started from "x-ftq-", e.g.
  "x-ftq-x-any" is  query language for multilingual texts. */
  struct lang_handler_s *lh_ftq_language;

  /*! \brief Minimal number of characters in a free-text indexable word of the language */
  int lh_word_min_chars;
  /*! \brief Maximal number of characters in a free-text indexable word of the language, no more than WORD_MAX_CHARS */
  int lh_word_max_chars;

  /*! \brief Application-specific data for this language, should be NULL initially */
  void *lh_appdata;

  /*! \brief Function to check if given word is free-text-indexable */
  lh_word_check_t *lh_is_vtb_word;
  /*! \brief Function to make given word capitalized, like the first word of a phrase */
  lh_word_patch_t *lh_tocapital_word;
  /*! \brief Function to make given word uppercased */
  lh_word_patch_t *lh_toupper_word;
  /*! \brief Function to make given word lowercased */
  lh_word_patch_t *lh_tolower_word;
  /*! \brief Function to normalize given word */
  lh_word_patch_t *lh_normalize_word;
  /*! \brief Pointer to function for counting words in given buffer */
  lh_count_words_t *lh_count_words;
  /*! \brief Pointer to function for iteration all words in given buffer */
  lh_iterate_words_t *lh_iterate_words;
  /*! \brief Pointer to function for iteration all words in given buffer */
  lh_iterate_patched_words_t *lh_iterate_patched_words;
#ifdef HYPHENATION_OK
  /*! \brief Pointer to function for iteration all hyphenation points in given buffer

This function finds some, (but maybe not all) hyphenation points in given
buffer and applies callback to every fragment between two consecutive points.
Every nonempty sequence of word delimiters between words, or before the first word,
or after the last word, become a fragment, Every word is treated as a sequence of
fragments. */
  lh_iterate_words_t *lh_iterate_hyppoints;
#endif
};

typedef struct lang_handler_s lang_handler_t;

/*! \brief Loads given handler in global table of the server.

Note that there's no way to unload a language handler. The only thing you can make is
to set all its function pointers to NULL.
\return Zero for success, error code otherwise. */
EXE_EXPORT (int, lh_load_handler, (lang_handler_t *new_handler));

/*! \brief Returns Unicode language handler for language with given name.

If there's no handler for language with specified name, more generic handler will be returned.
In the most unhappy case, &lh_xany will be returned, still good for plain usage */
EXE_EXPORT (lang_handler_t *, lh_get_handler, (const char *lang_name));





/*! \brief Type for function for finding number of (some) words in given unichar buffer
\return Number of words or (negative) error code */
typedef int elh_count_words_t(const char *buf, size_t bufsize, lh_word_check_t *check);

/*! \brief Type for function to apply given \c callback to (some) words in given unichar buffer

Note that it receives unichar buffer, but passes utf8char buffer to the callback.
\return Zero if success or (negative) error code */
typedef int elh_iterate_words_t(const char *buf, size_t bufsize, lh_word_check_t *check, lh_word_callback_t *callback, void *userdata);

/*! \brief Type for function to apply given \c callback to (some) words in given unichar buffer

Note that it receives unichar buffer, but passes utf8char buffer to the callback.
\return Zero if success or (negative) error code */
typedef int elh_iterate_patched_words_t(const char *buf, size_t bufsize, lh_word_check_t *check, lh_word_patch_t *patch, lh_word_callback_t *callback, void *userdata);

/*! \brief Table of functions specific for text particular language encoded by particular */
struct encodedlang_handler_s
{
  /*! \brief Pointer to handler for Unicode texts on the same language, may not be NULL */
  lang_handler_t *elh_unicoded_language;
  /*! \brief Pointer to generic handler for encoding, may not be NULL */
  encoding_handler_t *elh_base_encoding;
  /*! \brief Pointer to free-text query encoded language, may be NULL */
  struct encodedlang_handler_s *elh_ftq_language;
  /*! \brief Application-specific data for this language, should be NULL initially */
  void *elh_appdata;
  /*! \brief Pointer to function for counting words in given buffer */
  elh_count_words_t *elh_count_words;
  /*! \brief Pointer to function for iteration all words in given buffer */
  elh_iterate_words_t *elh_iterate_words;
  /*! \brief Pointer to function for iteration all words in given buffer */
  elh_iterate_patched_words_t *elh_iterate_patched_words;
#ifdef HYPHENATION_OK
  /*! \brief Pointer to function for iteration all hyphenation points in given buffer

This function finds some, (but maybe not all) hyphenation points in given
buffer and applies callback to every fragment between two consecutive points.
Every nonempty sequence of word delimiters between words, or before the first word,
or after the last word, become a fragment, Every word is treated as a sequence of
fragments. */
  elh_iterate_words_t *elh_iterate_hyppoints;
#endif
};

typedef struct encodedlang_handler_s encodedlang_handler_t;

/*! \brief Loads given handler in global table, using all names from new_handler->eh_names

Note that there's no way to unload a language handler. The only thing you can make is
to set all its function pointers to NULL.
\return Zero for success, error code otherwise. */
EXE_EXPORT (int, elh_load_handler, (encodedlang_handler_t *new_handler));

/*! \brief Returns handler for a pair of encoding and language, or NULL

NULL may be returned for NULL encoding or for missing handler. */
EXE_EXPORT (encodedlang_handler_t *, elh_get_handler, (encoding_handler_t *enc, lang_handler_t *lang));



/* These functions do not require pointer to encoding as additional argument */
EXE_EXPORT_TYPED (eh_decode_char_t, eh_decode_char__UCS4BE);
EXE_EXPORT_TYPED (eh_decode_char_t, eh_decode_char__UCS4LE);
EXE_EXPORT_TYPED (eh_decode_char_t, eh_decode_char__UTF16BE);
EXE_EXPORT_TYPED (eh_decode_char_t, eh_decode_char__UTF16LE);
EXE_EXPORT_TYPED (eh_decode_char_t, eh_decode_char__UTF8_QR);
EXE_EXPORT_TYPED (eh_decode_char_t, eh_decode_char__UTF8);
EXE_EXPORT_TYPED (eh_decode_char_t, eh_decode_char__UTF7);
EXE_EXPORT_TYPED (eh_decode_char_t, eh_decode_char__ASCII);
EXE_EXPORT_TYPED (eh_decode_char_t, eh_decode_char__ISO8859_1);
EXE_EXPORT_TYPED (eh_decode_char_t, eh_decode_char__WIDE_121);

EXE_EXPORT_TYPED (eh_encode_char_t, eh_encode_char__UCS4BE);
EXE_EXPORT_TYPED (eh_encode_char_t, eh_encode_char__UCS4LE);
EXE_EXPORT_TYPED (eh_encode_char_t, eh_encode_char__UTF16BE);
EXE_EXPORT_TYPED (eh_encode_char_t, eh_encode_char__UTF16LE);
EXE_EXPORT_TYPED (eh_encode_char_t, eh_encode_char__UTF8);
EXE_EXPORT_TYPED (eh_encode_char_t, eh_encode_char__UTF7);
EXE_EXPORT_TYPED (eh_encode_char_t, eh_encode_char__ASCII);
EXE_EXPORT_TYPED (eh_encode_char_t, eh_encode_char__ISO8859_1);
EXE_EXPORT_TYPED (eh_encode_char_t, eh_encode_char__WIDE_121);

EXE_EXPORT_TYPED (eh_decode_buffer_t, eh_decode_buffer__UCS4BE);
EXE_EXPORT_TYPED (eh_decode_buffer_t, eh_decode_buffer__UCS4LE);
EXE_EXPORT_TYPED (eh_decode_buffer_t, eh_decode_buffer__UTF16BE);
EXE_EXPORT_TYPED (eh_decode_buffer_t, eh_decode_buffer__UTF16LE);
EXE_EXPORT_TYPED (eh_decode_buffer_t, eh_decode_buffer__UTF8_QR);
EXE_EXPORT_TYPED (eh_decode_buffer_t, eh_decode_buffer__UTF8);
EXE_EXPORT_TYPED (eh_decode_buffer_t, eh_decode_buffer__UTF7);
EXE_EXPORT_TYPED (eh_decode_buffer_t, eh_decode_buffer__ASCII);
EXE_EXPORT_TYPED (eh_decode_buffer_t, eh_decode_buffer__ISO8859_1);
EXE_EXPORT_TYPED (eh_decode_buffer_t, eh_decode_buffer__WIDE_121);

EXE_EXPORT_TYPED (eh_encode_buffer_t, eh_encode_buffer__UCS4BE);
EXE_EXPORT_TYPED (eh_encode_buffer_t, eh_encode_buffer__UCS4LE);
EXE_EXPORT_TYPED (eh_encode_buffer_t, eh_encode_buffer__UTF16BE);
EXE_EXPORT_TYPED (eh_encode_buffer_t, eh_encode_buffer__UTF16LE);
EXE_EXPORT_TYPED (eh_encode_buffer_t, eh_encode_buffer__UTF8);
EXE_EXPORT_TYPED (eh_encode_buffer_t, eh_encode_buffer__UTF7);
EXE_EXPORT_TYPED (eh_encode_buffer_t, eh_encode_buffer__ASCII);
EXE_EXPORT_TYPED (eh_encode_buffer_t, eh_encode_buffer__ISO8859_1);
EXE_EXPORT_TYPED (eh_encode_buffer_t, eh_encode_buffer__WIDE_121);

EXE_EXPORT_TYPED (eh_decode_buffer_to_wchar_t, eh_decode_buffer_to_wchar__UCS4BE);
EXE_EXPORT_TYPED (eh_decode_buffer_to_wchar_t, eh_decode_buffer_to_wchar__UCS4LE);
EXE_EXPORT_TYPED (eh_decode_buffer_to_wchar_t, eh_decode_buffer_to_wchar__UTF16BE);
EXE_EXPORT_TYPED (eh_decode_buffer_to_wchar_t, eh_decode_buffer_to_wchar__UTF16LE);
EXE_EXPORT_TYPED (eh_decode_buffer_to_wchar_t, eh_decode_buffer_to_wchar__UTF8_QR);
EXE_EXPORT_TYPED (eh_decode_buffer_to_wchar_t, eh_decode_buffer_to_wchar__UTF8);
EXE_EXPORT_TYPED (eh_decode_buffer_to_wchar_t, eh_decode_buffer_to_wchar__UTF7);
EXE_EXPORT_TYPED (eh_decode_buffer_to_wchar_t, eh_decode_buffer_to_wchar__ASCII);
EXE_EXPORT_TYPED (eh_decode_buffer_to_wchar_t, eh_decode_buffer_to_wchar__ISO8859_1);
EXE_EXPORT_TYPED (eh_decode_buffer_to_wchar_t, eh_decode_buffer_to_wchar__WIDE_121);

EXE_EXPORT_TYPED (eh_encode_wchar_buffer_t, eh_encode_wchar_buffer__UCS4BE);
EXE_EXPORT_TYPED (eh_encode_wchar_buffer_t, eh_encode_wchar_buffer__UCS4LE);
EXE_EXPORT_TYPED (eh_encode_wchar_buffer_t, eh_encode_wchar_buffer__UTF16BE);
EXE_EXPORT_TYPED (eh_encode_wchar_buffer_t, eh_encode_wchar_buffer__UTF16LE);
EXE_EXPORT_TYPED (eh_encode_wchar_buffer_t, eh_encode_wchar_buffer__UTF8);
EXE_EXPORT_TYPED (eh_encode_wchar_buffer_t, eh_encode_wchar_buffer__UTF7);
EXE_EXPORT_TYPED (eh_encode_wchar_buffer_t, eh_encode_wchar_buffer__ASCII);
EXE_EXPORT_TYPED (eh_encode_wchar_buffer_t, eh_encode_wchar_buffer__ISO8859_1);
EXE_EXPORT_TYPED (eh_encode_wchar_buffer_t, eh_encode_wchar_buffer__WIDE_121);

/*! \brief Handler of "UCS-4" encoding that is actually eh__UCS4LE without endian in name */
extern encoding_handler_t eh__UCS4;

/*! \brief Handler of "UTF-16" encoding that is actually eh__UTF16LE without endian in name */
extern encoding_handler_t eh__UTF16;

/*! \brief Handler of "UCS-4BE" encoding, AKA "UCS-4BE" (0x00 0x00 0xFE 0xFF signature, 0x1234 byteorder) */
extern encoding_handler_t eh__UCS4BE;
/*! \brief Handler of "UCS-4LE" encoding, AKA "UCS4LE" (0xFF 0xFE 0x00 0x00 signature, 0x4321 byteorder, default implementation of UCS-4) */
extern encoding_handler_t eh__UCS4LE;
/*! \brief Handler of "UTF-16BE" encoding, AKA "UTF16BE" (0xFE 0xFF signature) */
extern encoding_handler_t eh__UTF16BE;
/*! \brief Handler of "UTF-16LE" encoding, AKA "UTF16LE" (0xFF 0xFE signature, default implementation of UTF-16) */
extern encoding_handler_t eh__UTF16LE;
/*! \brief Handler of "UTF-8-QR" encoding. It's similar to UTF8, but it it has quiet recovery */
extern encoding_handler_t eh__UTF8_QR;
/*! \brief Handler of "UTF-8" encoding, AKA "UTF8" */
extern encoding_handler_t eh__UTF8;
/*! \brief Handler of "UTF-7" encoding, AKA "UTF7" */
extern encoding_handler_t eh__UTF7;
/*! \brief Handler of "ASCII" (7-bit) encoding, AKA "US-ASCII" */
extern encoding_handler_t eh__ASCII;
/*! \brief Handler of "ISO8859-1" encoding, AKA "ISO-8859-1", "8859-1", "ISO", "LATIN-1", "LATIN 1", "LATIN_1", "LATIN1" */
extern encoding_handler_t eh__ISO8859_1;
/*! \brief Handler of "WIDE identity" encoding */
extern encoding_handler_t eh__WIDE_121;

/* These functions require pointer to encoding as additional argument */
extern eh_decode_char_t eh_decode_char__charset;
extern eh_encode_char_t eh_encode_char__charset;
extern eh_decode_buffer_t eh_decode_buffer__charset;
extern eh_encode_buffer_t eh_encode_buffer__charset;

/*! \brief x-any language handler can normalize combined characters in different ways, depending on this variable */
extern int lh_xany_normalization_flags;
#define LH_XANY_NORMALIZATION_COMBINE		0x1 /*!< Any pair of base char and combinig char (NSM, non-spacing modifier) is replaced with a single combined char */
#define LH_XANY_NORMALIZATION_TOBASE		0x2 /*!< Any combined char is converted to its (smallest known) base. If bit LH_XANY_NORMALIZATION_COMBINE is also set, pair of base char and combinig char loses its second char */
#define LH_XANY_NORMALIZATION_FULL 0xFF	/*!< More flags may appear in the future */
/*! \brief Language handler for "x-any" language, used for unknown/unspecified languages */
extern lang_handler_t lh__xany;
/*! \brief Language handler for "x-ftq-x-any" language, used as free-text-query language for unknown/unspecified languages */
extern lang_handler_t lh__xftqxany;

/* No real need in accelerated handlers of "UCS-4BE" or "UCS-4LE" encoded text on "x-any" language */

/*! \brief Handler of "UTF-16BE" encoded text on "x-any" language */
extern encodedlang_handler_t elh__xany__UTF16BE;
/*! \brief Handler of "UTF-16LE" encoded text on "x-any" language */
extern encodedlang_handler_t elh__xany__UTF16LE;
/*! \brief Handler of "UTF-8" encoded text on "x-any" language */
extern encodedlang_handler_t elh__xany__UTF8;
/*! \brief Handler of "UTF-7" encoded text on "x-any" language */
extern encodedlang_handler_t elh__xany__UTF7;
/*! \brief Handler of "ASCII" encoded text on "x-any" language */
extern encodedlang_handler_t elh__xany__ASCII;
/*! \brief Handler of "ISO8859-1" encoded text on "x-any" language */
extern encodedlang_handler_t elh__xany__ISO8859_1;

extern void langfunc_kernel_init(void);
extern void langfunc_plugin_init(void);

extern int lh_count_words(encoding_handler_t *eh, lang_handler_t *lh, const char *buf, size_t bufsize, lh_word_check_t *check);
extern int lh_iterate_words(encoding_handler_t *eh, lang_handler_t *lh, const char *buf, size_t bufsize, lh_word_check_t *check, lh_word_callback_t *callback, void *userdata);
extern int lh_iterate_patched_words(encoding_handler_t *eh, lang_handler_t *lh, const char *buf, size_t bufsize, lh_word_check_t *check, lh_word_patch_t *patch, lh_word_callback_t *callback, void *userdata);


#endif

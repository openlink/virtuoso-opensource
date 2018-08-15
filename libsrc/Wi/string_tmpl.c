/*
 *  string_tmpl.c
 *
 *  $Id$
 *
 *  Wildcard and fuzzy matching functions
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
 */

#include "wi.h"
#include "strlike.h"


/* By modifying these you can make the wc_match function to be more like
   the standard LIKE match in SQL (e.q. replace '*' with '%' for
   MATCH_ZERO_OR_MORE).
   If you want to suppress the effect of any of these special expressions,
   then just replace the character with '\0' (zero), and so it will be never
   encountered.
 */



/* Define this as zero, if you do not want that the fuzzy matching function
   (strfmatchp) considers the upper- and lowercase versions as well as
   accented and unaccented versions of the letter to be equal: */
#define INSENSITIVE_FUZZY   1

/* Define this as zero, if you do not want that nc_strstr (case-insensitive
   substring search) function considers the accented and unaccented
   versions of the letter to be equal:
   (If you want the exact (case sensitive) substring search, use then the
   standard library function strstr) */
#define DIACRITIC_INSENSITIVE_NC_STRSTR 1

#ifndef SLCHAR_WIDE

/* Take the 8-bit ISO-letter in range 192. - 255. (\300 - \377), convert
   it to lowercase (so it will be in range \340 - \377), and subtract
   224. (\340) and index this table with it, and you get the corresponding
   plain, unaccented 7-bit ascii lowercase letter, or at least the closest
   match.
 */
char iso_diacritic_to_plain[] =
{
/* plain   dec ISO8859.1 name (some languages which I know to use this one) */
  'a',				/* 224 agrave */
  'a',				/* 225 aacute (Spanish, Irish, many others) */
  'a',				/* 226 acircumflex */
  'a',				/* 227 atilde (Portugal) */
  'a',				/* 228 adieresis (Finnish, Estonian, Swedish, German) */
  'a',				/* 229 aring  (Swedish) */
  'a',				/* 230 ae     (Danish, Norwegian?) */
  'c',				/* 231 ccedilla (Portugal?) */
  'e',				/* 232 egrave (French?) */
  'e',				/* 233 eacute (Spanish, French) */
  'e',				/* 234 ecircumflex */
  'e',				/* 235 edieresis (French) */
  'i',				/* 236 igrave */
  'i',				/* 237 iacute (Spanish, Irish, many others) */
  'i',				/* 238 icircumflex */
  'i',				/* 239 idieresis */
  'd',				/* 240 eth (Icelandic d) */
  'n',				/* 241 ntilde (Spanish n~) */
  'o',				/* 242 ograve */
  'o',				/* 243 oacute (Spanish) */
  'o',				/* 244 ocircumflex */
  'o',				/* 245 otilde (Estonian, Portugal?) */
  'o',				/* 246 odieresis (Finnish, Estonian, Swedish, German) */
  'x',				/* 247 (minus?) I do not know what it should be, but the "uppercase"
				   version looks like a multiplicative x and the
				   lowercase version looks like a quotient sign. */
  'o',				/* 248 oslash (Danish, Norwegian?) */
  'u',				/* 249 ugrave */
  'u',				/* 250 uacute (Spanish) */
  'u',				/* 251 ucircumflex */
  'u',				/* 252 udieresis (Estonian, German, Spanish) */
  'y',				/* 253 yacute */
  'd',				/* 254 thorn  (Icelandic th) */
  's'				/* 255 ydieresis (In "uppercase" it's german double-s, which, I think,
				   is much more common than y with dots above) */
};

/* This returns true for range '\100' - '\177'
   (from '@' via 'A' and 'Z' to 'a' and 'z' and DEL)
   and for range '\300' - '\377' (from ISO8859.1 Agrave to ydieresis)
   In this latter range are most of the accented vowels and some consonants
   of the ISO8859.1, and for the most the upper-lower-relation holds.

 */

#define is_a_letter(C)        ((C) & 0100)	/* Bit-6 (64.) on */
/* This returns only true for 8-bit letters in range \300 - \377: */
#define is_a_iso_letter(C)    (((C) & 0300) == 0300)	/* Bit-7 and Bit-6 on */
#define is_a_lc_letter(C) (((C) & 0140) == 0140)	/* Both bits on */
#define is_a_uc_letter(C) (((C) & 0140) == 0100)	/* Bit-6 on, bit-5 off */
#define iso_to_lower(C) ((SLUCHAR)((C) | 040))	/* Set bit-5 (32.) on */

/* Note that because these macros consider also the characters like
   @, [, \, ], and ^ to be 'letters', they will match against characters
   `, {, |, }, and ~ respectively, which is just all right, because
   in some older implementations of European character sets those
   characters mark the uppercase and lowercase variants of certain
   diacritic letters. And I think it's generally better to match
   too liberally and so maybe sometimes give something entirely off
   the mark to the user, than to miss something important because of
   too strict criteria.
 */

/* C must be a 8-bit lowercase diacritic ISO8859.1 letter, in the
   range \340 - \377  !!! */
#define get_plain_letter(C)   (iso_diacritic_to_plain[(C)-'\340'])

#else

#undef is_a_letter
#define is_a_letter(C)        (IS_UNICHAR_ALPHA(C))	/* Bit-6 (64.) on */
/* This returns only true for 8-bit letters in range \300 - \377: */
#undef is_a_iso_letter
#define is_a_iso_letter(C)    ((C) >= 0377 && ((C) & 0300) == 0x300)	/* Bit-7 and Bit-6 on */
#undef is_a_lc_letter
#define is_a_lc_letter(C) (unicode3_getlcase (C) == (C))	/* Both bits on */
#undef is_a_uc_letter
#define is_a_uc_letter(C) (unicode3_getucase (C) == (C))	/* Bit-6 on, bit-5 off */
#undef iso_to_lower
#define iso_to_lower(C) ((SLUCHAR)(unicode3_getlcase (C)))	/* Set bit-5 (32.) on */

#undef get_plain_letter
#define get_plain_letter(C)   (iso_diacritic_to_plain[((C)&0377)-'\340'])
#endif

/* This takes the pattern pointer and string pointer as its arguments,
   and tries to match the first character in the string to the group
   pattern given in the beginning of pattern. If it matches, according
   to its own rules, then returns back the pointer past the closing bracket
   of the pattern. or to the point of ending zero, if no closing bracket
   were found.
   In the latter case this just silently works like the user had given
   the closing bracket in the end of pattern string. Of course it's not
   recommended practice to leave out the closing bracket, even if it's
   the last character of pattern.
 */

static const SLUCHAR *
STRLIKE_NAME (group_match) (const SLUCHAR *pat, const SLUCHAR *string)
{
  SLUCHAR c, negative_flag = 0, found_matching = 0;
  int i;

  /* Take the char to be looked for from the string: */
  c = (*string);

/* negative_flag is set on if there is negation-sign (^) in the beginning: */
  if (*++pat == STRLIKE_NAME (GROUP_NEGATE_CHAR))
    {
      negative_flag = 1;
      pat++;
    }

  for (i = 0; *pat; i++, pat++)
    {
/* If found the closing ] ?
   (it's the closing bracket when it's not the first character after [ or [^)
 */
      if ((*pat == STRLIKE_NAME (GROUP_END_CHAR)) && i)
	{
	  pat++;		/* Skip the closing bracket, and break from loop. */
	  break;
	}
      if (!found_matching)	/* Hasn't found yet the matching character. */
	{			/* The hyphen is the range operator... */
	  if ((*pat == STRLIKE_NAME (GROUP_RANGE_CHAR))
	      && i		/* if it's not the first char in expr., */
	      && (*(pat + 1) != STRLIKE_NAME (GROUP_END_CHAR))		/* and neither the last... */
	    )
	    {
	      if ((c >= *(pat - 1)) && (c <= *(pat + 1)))
		{
		  found_matching = 1;
		}
	      pat++;		/* Skip anyway the character at the right side of - */
	    }
	  else if (*pat == c)	/* If found c from the pattern. */
	    {
	      found_matching = 1;
	    }
	}
    }				/* for loop */

/* If user has simply forgotten the closing bracket, then this functions
   works exactly like there were one trailing in the end: */

/* 0 xor 0 = 0, 0 xor 1 = 1, 1 xor 0 = 1, 1 xor 1 = 0. */
  if (found_matching ^ negative_flag)
    {
      return (pat);
    }
  else
    {
      return (0);
    }
}



/*
   Check whether pattern and string match, and returns 0 if they not.
   If they match then return 1.
   last_matched is the character last matched to latest ? or [something]
   expression. When this is initially called, it should be zero.
 */

static int
STRLIKE_NAME (wc_match) (const SLUCHAR *pattern, const SLUCHAR *string, SLUCHAR last_matched, SLUCHAR escape_char)
{
  escape_char = escape_char ? escape_char : STRLIKE_NAME (LIKE_ESCAPE_CHARACTER);
loop:

  if (!*pattern && !*string)	/* if BOTH are in the end */
    {
      return (1);
    }

 /* this is checking for the escape character. if it's encountered skip it and check what's next.
    If it's an SQL escape char(%_), then process is as a ordinary one, else return false
 */
  if (*pattern == escape_char)
    {
      if (!*(pattern + 1))
	return(0);
      pattern++;
      if (*pattern == STRLIKE_NAME (MATCH_ZERO_OR_MORE_2)
	  || *pattern == STRLIKE_NAME (MATCH_ONE_CHAR)
	  || *pattern == STRLIKE_NAME (GROUP_BEG_CHAR)
	  || *pattern == STRLIKE_NAME (GROUP_END_CHAR)
	  || *pattern == STRLIKE_NAME (GROUP_NEGATE_CHAR)
	  || *pattern == STRLIKE_NAME (GROUP_RANGE_CHAR)
	  || *pattern == STRLIKE_NAME (MATCH_TO_LAST_CHAR)
	  || *pattern == escape_char
	  || *pattern == STRLIKE_NAME (MATCH_ZERO_OR_MORE))
        goto ordinary_match;
      else
	return(0);
    }

  if (*pattern == STRLIKE_NAME (MATCH_ZERO_OR_MORE) || *pattern == STRLIKE_NAME (MATCH_ZERO_OR_MORE_2))
    {				/* Skip repeated asterisks (at least this one): */
      do
	{
	  pattern++;
	}
      while (*pattern == STRLIKE_NAME (MATCH_ZERO_OR_MORE) || *pattern == STRLIKE_NAME (MATCH_ZERO_OR_MORE_2));
/* If this is the last asterisk in pattern, then this succeeds, regardless
   of what there is in string: (either nothing or something.)
   (So patterns like "*" or "Prefix.*" should take about constant time,
   regardless of the length of the string.)
 */
      if (!*pattern)
	{
	  return (1);
	}

    aster_loop:

/* If there is something after asterisk(s) in the pattern, then it's either
   a literal character required, or ?, @ or [something] pattern, which
   requires at least one character. So if a string is in the end, this fails:
   (Works so long we do not implement something like # for zero or more
   digits.)
 */
      if (!*string)
	{
	  return (0);
	}

/* if the character following * in pattern is some ordinary letter for example,
   (i.e. the character which has no any special significance in the pattern)
   then try to find with strchr the first occurrence of that character
   in the string, and continue from that, or if not found then return
   zero to indicate that test failed.
   In this way we avoid a lots of recursion done for a single asterisk.
 */
      if ((*pattern != STRLIKE_NAME (MATCH_ONE_CHAR)) &&
	  (*pattern != STRLIKE_NAME (MATCH_TO_LAST_CHAR)) &&
	  (*pattern != STRLIKE_NAME (GROUP_BEG_CHAR)))
	{
	  if (*pattern == escape_char)
	    {
	      if (!*(pattern + 1))
		return(0);
	      if (NULL == (string = ((const SLUCHAR *) STRLIKE_NAME (strchr) ((const SLCHAR *) string, *(pattern + 1)))))
		return (0);
	    }
	  else if (NULL == (string = ((const SLUCHAR *) STRLIKE_NAME (strchr) ((const SLCHAR *) string, *pattern))))
	    {
	      return (0);
	    }
	}

/* Test whether asterisk (which is in *(pattern-1)) at this point,
   would match to zero characters: */
      if (STRLIKE_NAME (wc_match) (pattern, string, last_matched, escape_char))
	{
	  return (1);
	}

/* If not, then increment string by one, and try again. Here we have written
   open the second recursive call previously present in return-clause (ored
   with the call above) ... | wc_match((pattern-1),string+1,last_matched)
   as the loop:
 */
      string++;
      goto aster_loop;
    }

  if (!*pattern || !*string)
    return (0);			/* If only OTHER is in the end */

/* After the test above we know that neither the pattern or string is
   finished yet: */

  if (*pattern == STRLIKE_NAME (GROUP_BEG_CHAR))
    {
      if (NULL != (pattern = STRLIKE_NAME (group_match) (pattern, string)))
	{
	  last_matched = *string++;
	  goto loop;
	}
      else
	{
	  return (0);
	}
    }


  if (*pattern == STRLIKE_NAME (MATCH_ONE_CHAR))	/* Question-mark in pattern ? */
    {
      pattern++;
      last_matched = *string++;
      goto loop;
    }

/* @ matches either to the last matched character, and if there hasn't been
   encountered any, then it matches only to @ itself.
 */
  if (*pattern == STRLIKE_NAME (MATCH_TO_LAST_CHAR))
    {
      if ((last_matched && (*string == last_matched))
	  ||
	  (!last_matched && (*string == STRLIKE_NAME (MATCH_TO_LAST_CHAR)))
	)
	{
	  pattern++;
	  string++;
	  goto loop;
	}
      else
	{
	  return (0);
	}
    }
ordinary_match:
  if (*pattern == *string)	/* Same characters ? */
    {
      pattern++;
      string++;
      goto loop;
    }

  else
    {
      return (0);
    }
}

#ifndef SLCHAR_WIDE
static int
wc_match_coll (
	const unsigned char *pattern,
	const unsigned char *string,
	unsigned char last_matched,
	collation_t *collation,
	unsigned char escape_char)
{

  escape_char = escape_char ? escape_char : LIKE_ESCAPE_CHARACTER;
loop:

  if (!*pattern && !*string)	/* if BOTH are in the end */
    {
      return (1);
    }

 /* this is checking for the escape character. if it's encountered skip it and check what's next.
    If it's an SQL escape char(%_), then process is as a ordinary one, else return false
 */
  if (*pattern == escape_char)
    {
      if (!*(pattern + 1))
	return(0);
      pattern++;
      if (*pattern == MATCH_ZERO_OR_MORE_2 || *pattern == MATCH_ONE_CHAR)
        goto ordinary_match;
      else
	return(0);
    }

  if (*pattern == MATCH_ZERO_OR_MORE || *pattern == MATCH_ZERO_OR_MORE_2)
    {				/* Skip repeated asterisks (at least this one): */
      do
	{
	  pattern++;
	}
      while (*pattern == MATCH_ZERO_OR_MORE || *pattern == MATCH_ZERO_OR_MORE_2);
/* If this is the last asterisk in pattern, then this succeeds, regardless
   of what there is in string: (either nothing or something.)
   (So patterns like "*" or "Prefix.*" should take about constant time,
   regardless of the length of the string.)
 */
      if (!*pattern)
	{
	  return (1);
	}

    aster_loop:

/* If there is something after asterisk(s) in the pattern, then it's either
   a literal character required, or ?, @ or [something] pattern, which
   requires at least one character. So if a string is in the end, this fails:
   (Works so long we do not implement something like # for zero or more
   digits.)
 */
      if (!*string)
	{
	  return (0);
	}

/* if the character following * in pattern is some ordinary letter for example,
   (i.e. the character which has no any special significance in the pattern)
   then try to find with strchr the first occurrence of that character
   in the string, and continue from that, or if not found then return
   zero to indicate that test failed.
   In this way we avoid a lots of recursion done for a single asterisk.
 */
      if ((*pattern != MATCH_ONE_CHAR) &&
	  (*pattern != MATCH_TO_LAST_CHAR) &&
	  (*pattern != GROUP_BEG_CHAR))
	{
	  while (*string && COLLATION_XLAT_NARROW (collation, (unsigned char)*string) !=
	      COLLATION_XLAT_NARROW (collation, (unsigned char)*pattern) )
	    string++;
	  if (!string)
	    {
	      return (0);
	    }
	}

/* Test whether asterisk (which is in *(pattern-1)) at this point,
   would match to zero characters: */
      if (wc_match_coll (pattern, string, last_matched, collation, escape_char))
	{
	  return (1);
	}

/* If not, then increment string by one, and try again. Here we have written
   open the second recursive call previously present in return-clause (ored
   with the call above) ... | wc_match((pattern-1),string+1,last_matched)
   as the loop:
 */
      string++;
      goto aster_loop;
    }

  if (!*pattern || !*string)
    return (0);			/* If only OTHER is in the end */

/* After the test above we know that neither the pattern or string is
   finished yet: */

  if (*pattern == GROUP_BEG_CHAR)
    {
      if (NULL != (pattern = group_match (pattern, string)))
	{
	  last_matched = *string++;
	  goto loop;
	}
      else
	{
	  return (0);
	}
    }


  if (*pattern == MATCH_ONE_CHAR)	/* Question-mark in pattern ? */
    {
      pattern++;
      last_matched = *string++;
      goto loop;
    }

/* @ matches either to the last matched character, and if there hasn't been
   encountered any, then it matches only to @ itself.
 */
  if (*pattern == MATCH_TO_LAST_CHAR)
    {
      if ((last_matched && (*string == last_matched))
	  ||
	  (!last_matched && (*string == MATCH_TO_LAST_CHAR))
	)
	{
	  pattern++;
	  string++;
	  goto loop;
	}
      else
	{
	  return (0);
	}
    }
ordinary_match:
  if (COLLATION_XLAT_NARROW (collation, (unsigned char)*pattern) ==
      COLLATION_XLAT_NARROW (collation, (unsigned char)*string) )	/* Same characters ? */
    {
      pattern++;
      string++;
      goto loop;
    }

  else
    {
      return (0);
    }
}
#endif /*SLCHAR_WIDE*/



/* ================================================================= */

/* Functions for fuzzy match, previously called splatch */

/* ================================================================= */


/*
   When called first time, max_diffs is one plus number of maximum allowed
   differences. When it comes to zero, we know that we have failed.
   Now this does not increment the differences count for the letter which
   are otherwise same but in differing cases, or if the other is a
   some diacritic ISO-letter, and the other is the corresponding unaccented
   plain ascii letter.
 */
static int
STRLIKE_NAME(dfmatch) (const SLUCHAR *s1, const SLUCHAR *s2, int max_diffs)
{
   SLUCHAR c1, c2;
loop:

  /* If more differences than allowed: (max_diffs has come to zero) */
  if (!max_diffs)
    return (max_diffs);		/* Return zero. */

  c1 = *s1;
  c2 = *s2;

  if (!c1 && !c2)
    return (1);			/* Both at the end, return true. */
  if (!c1)
    {
      s2++;
      max_diffs--;
      goto loop;
    }				/* s1 in the end */
  if (!c2)
    {
      s1++;
      max_diffs--;
      goto loop;
    }				/* s2 in the end */
  if (c1 == c2)
    {
      s1++;
      s2++;
      goto loop;
    }				/* same chars */
  else
    /* Not exact match... */
    {
#if (INSENSITIVE_FUZZY!=0)
      /* Test whether they are the same letter, but the other in upper and
         the other in lowercase: */
      if (is_a_uc_letter (c1))
	{
	  c1 = iso_to_lower (c1);
	}
      if (is_a_uc_letter (c2))
	{
	  c2 = iso_to_lower (c2);
	}
      /* Test whether the other is some diacritic ISO-letter (e.g. some
         accented or umlaut vowel, like e with acute accent (e')), and
         the other is corresponding plain ascii unaccented letter (e.g. e) */
      if (is_a_iso_letter (c1))
	{
	  if (!is_a_iso_letter (c2))
	    {
	      c1 = get_plain_letter (c1);
	    }			/* c2 is some plain vowel? */
	}
      else
	/* c1 is some plain vowel? (unaccented) */
	{
	  if (is_a_iso_letter (c2))
	    {
	      c2 = get_plain_letter (c2);
	    }
	}

      /* Yes, the letters were found to be 'same' in this broader sense: */
      if (c1 == c2)
	{
	  s1++;
	  s2++;
	  goto loop;
	}			/* No need to recurse... */
#endif

/* Now, we have two truly different characters, let's decrement max_diffs
   by one, and check whether it has come to zero already, meaning that we
   have failed:
 */
      if (!--max_diffs)
	{
	  return (0);
	}

/* Still allowed differences left, let's call recursively this same function
   to test whether the characters are just different: */
      if (STRLIKE_NAME(dfmatch) (s1 + 1, s2 + 1, max_diffs))
	{
	  return (1);
	}

/* If that failed, let's test whether there is one extra character in the
   datum: */
      if (STRLIKE_NAME(dfmatch) (s1 + 1, s2, max_diffs))
	{
	  return (1);
	}

/* And lastly, it might be that there is one extra character in the pattern
   instead, so increment that, and loop back: */
      s2++;
      goto loop;

/* It was previously like this, but we have now written open the last recursive
   call: (as loop)
   return(dfmatch(s1+1,s2+1,max_diffs-1) ;; different chars
   ||
   dfmatch(s1+1,s2,max_diffs-1)   ;; extra character in s1
   ||
   dfmatch(s1,s2+1,max_diffs-1)); ;; extra character in s2
 */
    }
}


/* The maxdiffs value is now always hardcoded, being only the function of
   the length of first argument. (But it can be augmented with the
   addlibs argument).
 */

static int
STRLIKE_NAME (strfmatchp) (const SLUCHAR *s1, const SLUCHAR *s2, int addlibs)
{
  int d, s1l;		/* s1l = s1's length */
  int max_diffs;

  d = (s1l = (int) (STRLIKE_NAME (strlen) ((const SLCHAR *) s1))) - (int) (STRLIKE_NAME (strlen) ((const SLCHAR *) s2));

  switch (s1l)
    {
    case 0:
    case 1:
    case 2:
      max_diffs = 0;
      break;
    case 3:
    case 4:
      max_diffs = 1;
      break;
    case 5:
    case 6:
    case 7:
    case 8:
      max_diffs = 2;
      break;
    default:
      max_diffs = 3;
      break;
    }

  /* Add the additional liberties to max_diffs allowed: */
  max_diffs += addlibs;

/* If the other string is more than max_diffs characters longer or shorter
   than the other one, then it's of no use to call that recursive function,
   as we know immediately that they can't match:
 */
  if (((d > 0) ? d : -d) > max_diffs)
    {
      return (DVC_LESS);
    }

  if (!(STRLIKE_NAME(dfmatch) (s1, s2, (max_diffs + 1))))
    {
      return (DVC_LESS);
    }
  else
    {
      return (DVC_MATCH);
    }
}


/* Returns pointer to that point of string1, where the first instance
   of string2 is found. Case does not matter.
   string1 can contain also ISO-8859.1 diacritic vowels & consonants,
   which corresponding unaccented vowels in string2 will match against.
 */
SLUCHAR *
STRLIKE_NAME(nc_strstr) (const SLUCHAR *string1, const SLUCHAR *string2)
{
  SLUCHAR first, d = 0, e;
  const SLUCHAR *s1, *s2;

  first = *string2;

  if (!first)
    {
      return (SLUCHAR *)(string1);
    }				/* If string2 is an empty string "" */

  if (is_a_letter (first))
    {
      first = iso_to_lower (first);
    }
  else
    {				/* It's some non-letter character (e.g. a digit), then we can search
				   it with strchr. If the first letter of string2 is not found from
				   string1, then this surely fails: */
      if (NULL == (string1 = (const SLUCHAR *) STRLIKE_NAME (strchr) ((const SLCHAR *) string1,
	  first)))
	{
	  return (0);
	}
      goto the_inner_loop;	/* Skip few unnecessary statements. */
    }

  for (; 0 != (d = *string1);)
    {
      if (is_a_uc_letter (d))
	{
	  d = iso_to_lower (d);
	}
#if (DIACRITIC_INSENSITIVE_NC_STRSTR!=0)
      if (is_a_iso_letter (d) && !is_a_iso_letter (first))
	{
	  d = get_plain_letter (d);
	}			/* d must be in lowercase before this! */
#endif
      if (d == first)
	{
	the_inner_loop:
/* e have to be fetched and checked before d in and-clause, otherwise
   we won't find substrings from the end of string1: */
	  for (s1 = string1, s2 = string2; (0 != (e = *++s2) && 0 != (d = *++s1));)
	    {
	      if (is_a_uc_letter (d))
		{
		  d = iso_to_lower (d);
		}
	      if (is_a_uc_letter (e))
		{
		  e = iso_to_lower (e);
		}
#if (DIACRITIC_INSENSITIVE_NC_STRSTR!=0)
	      if (is_a_iso_letter (d) && !is_a_iso_letter (e))
		{
		  d = get_plain_letter (d);
		}		/* e is some plain vowel? */
#endif
	      if (d != e)
		{
		  break;
		}		/* Found first differing character. */
	    }
/* If we exited the above loop with value of e as zero, then we have
   found that the whole string2 is contained in string1: */
	  if (!e)
	    {
	      return (SLUCHAR *)(string1);
	    }
/* But if string1 was finished (although s2 still wasn't) then we return
   false, as the 'tail of string1' is now shorter than string2, so it's
   not anymore possible that string2 would fit into it: */
	  if (!d)
	    {
	      return (0);
	    }
/* Otherwise, it didn't match this time, let's try to find the next potential
   point of string1 where it would match: */
	  if (!is_a_letter (first))	/* Can we use strchr??? */
	    {			/* If first char of string2 wasn't found, then there's no hope: */
	      if (NULL == (string1 = (const SLUCHAR *) STRLIKE_NAME (strchr) (
		  (const SLCHAR *) (string1 + 1), first)))
		{
		  return (0);
		}
	      goto the_inner_loop;	/* If your C-compiler cries for this, use
					   the continue statement instead. Effect is the same, but then we
					   execute few unnecessary tests and statements. */
	    }
	}
      string1++;
    }

  return (0);			/* Return false as we didn't find it. */
}

#ifndef SLCHAR_WIDE
/* Like the above, but handles the collation order.  */
static const unsigned char *
nc_strstr_coll (const unsigned char *string1, const unsigned char *string2, collation_t *collation)
{
  unsigned char first, d = 0, e;
  const unsigned char *s1, *s2;

  first = *string2;

  if (!first)
    {
      return (string1);
    }				/* If string2 is an empty string "" */

  if (is_a_letter (first))
    {
      first = iso_to_lower (first);
    }
  else
    {				/* It's some non-letter character (e.g. a digit), then we can search
				   it with strchr. If the first letter of string2 is not found from
				   string1, then this surely fails: */
      if (NULL == (string1 = (const unsigned char *) strchr ((const char *) string1,
	  first)))
	{
	  return (0);
	}
      goto the_inner_loop;	/* Skip few unnecessary statements. */
    }

  for (; 0 != (d = *string1);)
    {
      if (is_a_uc_letter (d))
	{
	  d = iso_to_lower (d);
	}
#if (DIACRITIC_INSENSITIVE_NC_STRSTR!=0)
      if (is_a_iso_letter (d) && !is_a_iso_letter (first))
	{
	  d = get_plain_letter (d);
	}			/* d must be in lowercase before this! */
#endif
      if (d == first)
	{
	the_inner_loop:
/* e have to be fetched and checked before d in and-clause, otherwise
   we won't find substrings from the end of string1: */
	  for (s1 = string1, s2 = string2; (0 != (e = *++s2) && 0 != (d = *++s1));)
	    {
	      if (is_a_uc_letter (d))
		{
		  d = iso_to_lower (d);
		}
	      if (is_a_uc_letter (e))
		{
		  e = iso_to_lower (e);
		}
#if (DIACRITIC_INSENSITIVE_NC_STRSTR!=0)
	      if (is_a_iso_letter (d) && !is_a_iso_letter (e))
		{
		  d = get_plain_letter (d);
		}		/* e is some plain vowel? */
#endif
	      if (COLLATION_XLAT_NARROW (collation, d) != COLLATION_XLAT_NARROW (collation, e))
		{
		  break;
		}		/* Found first differing character. */
	    }
/* If we exited the above loop with value of e as zero, then we have
   found that the whole string2 is contained in string1: */
	  if (!e)
	    {
	      return (string1);
	    }
/* But if string1 was finished (although s2 still wasn't) then we return
   false, as the 'tail of string1' is now shorter than string2, so it's
   not anymore possible that string2 would fit into it: */
	  if (!d)
	    {
	      return (0);
	    }
/* Otherwise, it didn't match this time, let's try to find the next potential
   point of string1 where it would match: */
	  if (!is_a_letter (first))	/* Can we use strchr??? */
	    {			/* If first char of string2 wasn't found, then there's no hope: */
	      if (NULL == (string1 = (const unsigned char *) strchr (
		  (const char *) (string1 + 1), first)))
		{
		  return (0);
		}
	      goto the_inner_loop;	/* If your C-compiler cries for this, use
					   the continue statement instead. Effect is the same, but then we
					   execute few unnecessary tests and statements. */
	    }
	}
      string1++;
    }

  return (0);			/* Return false as we didn't find it. */
}
#endif /*SLCHAR_WIDE*/


int
STRLIKE_NAME(__cmp_like) (
	const SLCHAR *string,
	const SLCHAR * pattern,
#ifndef SLCHAR_WIDE
	collation_t *collation,
#endif
	SLCHAR escape_char)
{
  if (((*pattern == STRLIKE_NAME (MATCH_ZERO_OR_MORE)) || (*pattern == STRLIKE_NAME (MATCH_ZERO_OR_MORE_2)))
      && ((*(pattern + 1) == STRLIKE_NAME (MATCH_ZERO_OR_MORE)) || (*(pattern + 1) == STRLIKE_NAME (MATCH_ZERO_OR_MORE_2))))
    {
#ifndef SLCHAR_WIDE
      if (collation)
	return ((!!nc_strstr_coll ((const SLUCHAR*) string, (const SLUCHAR*) (pattern + 2), collation)) ? DVC_MATCH : DVC_LESS);
      else
#endif
	return ((!!STRLIKE_NAME (nc_strstr) ((const SLUCHAR*) string, (const SLUCHAR*) (pattern + 2))) ? DVC_MATCH : DVC_LESS);
    }

  if (*pattern == STRLIKE_NAME (MATCH_TO_LAST_CHAR))	/* Call fuzzy match instead. */
    {
      int addlibs = 0;
      do
	{
	  pattern++;
	  addlibs++;
	}
      while (*pattern == STRLIKE_NAME (MATCH_TO_LAST_CHAR));
/* The last argument should be zero, when there's only one @: */
      return (STRLIKE_NAME (strfmatchp) ((const SLUCHAR*) string, (const SLUCHAR*) pattern, (addlibs - 1)));
    }

#ifndef SLCHAR_WIDE
  if (collation)
    return (wc_match_coll ((const SLUCHAR*) pattern, (const SLUCHAR*) string, 0, collation, (unsigned char)escape_char) ? DVC_MATCH : DVC_LESS);
  else
#endif
    return (STRLIKE_NAME (wc_match) ((const SLUCHAR*) pattern, (const SLUCHAR*) string, 0, (unsigned char)escape_char) ? DVC_MATCH : DVC_LESS);
}


/*

   The function cmp_like wants two arguments, a string and a pattern.
   It's supposed that the string comes from a string-column of database
   or any such source of data from which we try to find something (e.g.
   it could be the line from the text file, or some field in the RAM-based
   object in Lisp). The pattern respectively is supposed to be supplied
   by the user, for example from some search form, which is then converted
   to SQL-where clause containing LIKE-expression, where the left side is
   of course the column name (of type varchar, i.e. string), and the
   right side is the pattern searched for.

   If the pattern does not begin with an at-sign (@) or with two
   asterisks (**), then the we test the equality of the string and pattern
   with the ordinary wildcard matching function wc_match, which behaves
   approximately like the filename pattern matching in the Unix shell.
   (But not like the regular expression matching in utilities like grep
   and sed).

   The following characters have special significance in the pattern:

   ?    Matches any single character.

   *    Matches zero or more of any characters.

   [ ]  (Called a group-expression here)
   Matches any one of the enclosed characters, unless the
   first character following the opening [ is ^, then matches
   only if the character (in the datum string) is not any one of
   those specified after the ^. (I.e. the ^ negates the meaning
   of this expression.)
   You can use character ranges like 0-9 (shorthand for 0123456789)
   inside the brackets, in which case the character in the datum
   string must be lexically within the inclusive range of of that
   pair (of course the character at the left side of hyphen must
   be lexically (that is, its ascii value) less than the
   character at the right side).

   The hyphen can be included in the character set by putting it
   as the first or last character. The right bracket (]) can
   be included by putting it as the first character in the expression,
   i.e. immediately after the opening bracket ([) or the caret (^)
   following it.

   Examples:
   [abc]          Matches any of the letters a, b and c.
   [^0123456789]  Matches anything, except digits. (same as [^0-9])
   [[]            Matches [
   []]            Matches ]
   [][]           Matches ] and [
   [^]]           Matches anything except ]
   [A-Za-z0-9]    Matches all the alphanumeric characters.
   [-*+/]         Matches the four basic arithmetic operators.
   [-]            Matches to single hyphen.
   []-]           Matches to ] or -
   [-[] or [[-]   Matches to - or [

   That is, the hyphen indicates a range between characters, unless
   it's the first or the last character in the group expression,
   in which case it matches just to itself.

   @   Matches the character last matched to ? or group-expression.
   For example ?*@ matches to all strings which begin with the same
   character they end. However, if there is neither ? nor [] expression
   at the left side of @ in the pattern, then @ matches just to
   itself. (E.g. *@* should match to all E-mail addresses).


   Any other characters match ONLY to themselves, that is, not even to
   the upper- or lowercase variants of the same letter. Use expression
   like [Wo][Oo][Rr][Dd] if you want to find any mixed-case variant of
   the word "word", or use the substring search explained below.


   However, if the pattern begins with an at-sign (@) then we compare
   the rest of pattern to string with the fuzzy matching function
   strfmatchp, allowing differences of few characters in quality and
   quantity (length). If there's more than one @ in the beginning of
   pattern given to cmp_like. they are all skipped, and so many
   additional liberties are given for the match function.  The more
   @-signs there are in the beginning, the more fuzzy (liberal) is the
   search. For example: pattern "@Johnson" will match to string
   "Jonsson" and pattern "@@Johnson" will match also to "Jansson".

   If the pattern begins with two asterisks, then we do diacritic- and
   case insensitive substring search (with the function nc_strstr),
   trying to find the string given in the rest of pattern from the
   datum string.

   E.g. "**escort" will match to "Ford Escort vm. 1975".


   If there are any ISO8859.1 diacritic letters (e.g. vowels with
   accents or umlaut-signs, or letters like the spanish n with ~ (tilde))
   present in the datum string, then the plain unaccented (7-bit ASCII)
   variant of the same letter in the pattern string will match to it.
   But if there are any diacritic letter specified in the pattern string,
   then it will match only to the upper- or lowercase variant of exactly
   the same diacritic letter.
   The rationale behind this is that the people entering the information
   to database can use the exact spelling for the word, for example
   writing the word "Citroen" with the umlaut-e (e with two dots above it),
   as it is actually written in French, and the people who search for
   the Citroens can still find it without need to remember the exact
   orthography of the French, by just giving a word "citroen".
   And this allows also the people who have just plain 7-bit ascii
   keyboards to search for the words like Ra"a"kkyla" (place in Finland,
   a" means umlaut-a, i.e. a with two dots above it), just by entering
   the word raakkyla.

   So the following holds with the substring searches:

   1) Any non-alphabetic character in the pattern matches just to itself
   in the datum string (e.g. ? to ? and 3 to 3).

   2) Any 7-bit ascii letter (A-Z and a-z without any diacritic signs)
   in the pattern matches to any diacritic variant of the same letter
   (as well as to same 7-bit ascii letter) in the datum string, either
   in the upper- or lowercase.

   3) Any diacritic letter (8-bit ISO8859.1 letter) in the pattern matches
   only to the same letter (in the upper- or lowercase) in the datum
   string.


   Note that because the functions strfmatchp and nc_strstr use macros
   which consider also the characters like:
   @, [, \, ], and ^ to be letters, they will match against characters
   `, {, |, }, and ~ respectively, which is just all right, because
   in some older implementations of European character sets those
   characters mark the uppercase and lowercase variants of certain
   diacritic letters. And I think it's generally better to match
   too liberally and so maybe sometimes give something entirely off
   the wall to the user, than to miss something important because of
   too strict criteria.

   Of course, when searching from the data which contains text in
   some wide-character format (like certain coding systems for
   Japanese and Chinese where one character is coded with two bytes)
   neither fuzzy matching function nor nc_strstr function presented here
   should be used, as they would often match on entirely spurious cases.

 */

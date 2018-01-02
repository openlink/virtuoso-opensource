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
#include "latin1ctype.h"
/*#define LH_ITERATOR_DEBUG 1*/

static int unichar_getprops_stub (unichar uchr);

/* The following table is a source for initialization of work_uniblocks.
It contains blocks as they described in Unicode-3. Some of them contains
others, being "parents" of their sub-blocks.

All Unicode functions uses work_uniblocks array. It is initially filled by
dummy data, and should be filled by call of reset_work_uniblocks() function.
Later, language plugins and other units may modify items of work_uniblocks,
by changing ub_props and assigning ub_... handlers to some "smart" functions.
When all changes are in past, squeeze_work_uniblocks() may be called to
reduce the size of table and thus accelerate search. */

unicode_block_t raw_uniblocks[] = {
/*_______________________________________________________________________________________________________________________*/
/* Group of characters				| Props		| Min		| Max		|       |       |       |*/
/*==============================================|===============|===============|===============|=======|=======|=======|*/
{ "Basic Multilingual Plane 0"			, UCP_GAP	, 0x0000	, 0xFFFF	, NULL	, NULL	, NULL	},
{ "A-zone (alphabetic)"				, UCP_MIX	, 0x0000	, 0x33FF	, NULL	, NULL	, NULL	},
{ "General Scripts Area"			, UCP_ALPHA	, 0x0000	, 0x1FFF	, NULL	, NULL	, NULL	},
{ "Basic Latin (US-ASCII)"			, UCP_MIX	, 0x0000	, 0x007F	, NULL	, NULL	, NULL	},
{ "Latin-1 (ISO-8859-1)"			, UCP_MIX	, 0x0080	, 0x00FF	, NULL	, NULL	, NULL	},
{ "Latin Extended"				, UCP_ALPHA	, 0x0100	, 0x024F	, NULL	, NULL	, NULL	},
{ "IPA Extensions"				, UCP_ALPHA	, 0x0250	, 0x02AF	, NULL	, NULL	, NULL	},
{ "Spacing Modifier Letters"			, UCP_ALPHA	, 0x02B0	, 0x02FF	, NULL	, NULL	, NULL	},
{ "Combining Diacritical Marks"			, UCP_ALPHA	, 0x0300	, 0x036F	, NULL	, NULL	, NULL	},
{ "Greek"					, UCP_ALPHA	, 0x0370	, 0x03FF	, NULL	, NULL	, NULL	},
{ "Cyrillic"					, UCP_ALPHA	, 0x0400	, 0x04FF	, NULL	, NULL	, NULL	},
{ "Armenian"					, UCP_ALPHA	, 0x0530	, 0x058F	, NULL	, NULL	, NULL	},
{ "Hebrew"					, UCP_ALPHA	, 0x0590	, 0x05FF	, NULL	, NULL	, NULL	},
{ "Arabic"					, UCP_ALPHA	, 0x0600	, 0x06FF	, NULL	, NULL	, NULL	},
{ "Syriac"					, UCP_ALPHA	, 0x0700	, 0x074D	, NULL	, NULL	, NULL	},
{ "Thaana"					, UCP_ALPHA	, 0x0780	, 0x07B1	, NULL	, NULL	, NULL	},
{ "ISCII Indic Scripts"				, UCP_ALPHA	, 0x0900	, 0x0DFF	, NULL	, NULL	, NULL	},
{ "Devanagari"					, UCP_ALPHA	, 0x0900	, 0x097F	, NULL	, NULL	, NULL	},
{ "Bengali"					, UCP_ALPHA	, 0x0980	, 0x09FF	, NULL	, NULL	, NULL	},
{ "Gurmukhi"					, UCP_ALPHA	, 0x0A00	, 0x0A7F	, NULL	, NULL	, NULL	},
{ "Gujarati"					, UCP_ALPHA	, 0x0A80	, 0x0AFF	, NULL	, NULL	, NULL	},
{ "Oriya"					, UCP_ALPHA	, 0x0B00	, 0x0B7F	, NULL	, NULL	, NULL	},
{ "Tamil"					, UCP_ALPHA	, 0x0B80	, 0x0BFF	, NULL	, NULL	, NULL	},
{ "Telugu"					, UCP_ALPHA	, 0x0C00	, 0x0C7F	, NULL	, NULL	, NULL	},
{ "Kannada"					, UCP_ALPHA	, 0x0C80	, 0x0CFF	, NULL	, NULL	, NULL	},
{ "Malayalam"					, UCP_ALPHA	, 0x0D00	, 0x0D7F	, NULL	, NULL	, NULL	},
{ "Sinhalese"					, UCP_ALPHA	, 0x0D80	, 0x0DFF	, NULL	, NULL	, NULL	},
{ "Thai"					, UCP_ALPHA	, 0x0E00	, 0x0E7F	, NULL	, NULL	, NULL	},
{ "Lao"						, UCP_ALPHA	, 0x0E80	, 0x0EFF	, NULL	, NULL	, NULL	},
{ "Tibetan"					, UCP_ALPHA	, 0x0F00	, 0x0FBF	, NULL	, NULL	, NULL	},
{ "Mongolian"					, UCP_ALPHA	, 0x1000	, 0x109F	, NULL	, NULL	, NULL	},
{ "Georgian"					, UCP_ALPHA	, 0x10A0	, 0x10FF	, NULL	, NULL	, NULL	},
{ "Hangul Jamo"					, UCP_ALPHA	, 0x1100	, 0x11FF	, NULL	, NULL	, NULL	},
{ "Ethiopic"					, UCP_ALPHA	, 0x1200	, 0x137F	, NULL	, NULL	, NULL	},
{ "Cherokee"					, UCP_ALPHA	, 0x13A0	, 0x13FF	, NULL	, NULL	, NULL	},
{ "Canadian Syllabics"				, UCP_ALPHA	, 0x1400	, 0x167F	, NULL	, NULL	, NULL	},
{ "Ogham"					, UCP_MIX	, 0x1680	, 0x169F	, NULL	, NULL	, NULL	},
{ "Ogham 'space mark'"				, UCP_PUNCT	, 0x1680	, 0x1680	, NULL	, NULL	, NULL	},
{ "Ogham script"				, UCP_ALPHA	, 0x1681	, 0x169F	, NULL	, NULL	, NULL	},
{ "Runic"					, UCP_ALPHA	, 0x16A0	, 0x16FF	, NULL	, NULL	, NULL	},
{ "Burmese"					, UCP_ALPHA	, 0x1700	, 0x1759	, NULL	, NULL	, NULL	},
{ "Khmer"					, UCP_ALPHA	, 0x1780	, 0x17E9	, NULL	, NULL	, NULL	},
{ "Latin Extended Additional"			, UCP_ALPHA	, 0x1E00	, 0x1EFF	, NULL	, NULL	, NULL	},
{ "Greek Extended"				, UCP_ALPHA	, 0x1F00	, 0x1FFF	, NULL	, NULL	, NULL	},
/*----------------------------------------------|---------------|---------------|---------------|-------|-------|-------|*/
{ "Symbols Area"				, UCP_PUNCT	, 0x2000	, 0x2EFF	, NULL	, NULL	, NULL	},
{ "General Punctuation"				, UCP_PUNCT	, 0x2000	, 0x206F	, NULL	, NULL	, NULL	},
{ "Superscripts and Subscripts"			, UCP_PUNCT	, 0x2070	, 0x209F	, NULL	, NULL	, NULL	},
{ "Currency Symbols"				, UCP_PUNCT	, 0x20A0	, 0x20CF	, NULL	, NULL	, NULL	},
{ "Combining Marks for Symbols"			, UCP_PUNCT	, 0x20D0	, 0x20FF	, NULL	, NULL	, NULL	},
{ "Letterlike Symbols"				, UCP_PUNCT	, 0x2100	, 0x214F	, NULL	, NULL	, NULL	},
{ "Number Forms"				, UCP_PUNCT	, 0x2150	, 0x218F	, NULL	, NULL	, NULL	},
{ "Arrows"					, UCP_PUNCT	, 0x2190	, 0x21FF	, NULL	, NULL	, NULL	},
{ "Mathematical Operators"			, UCP_PUNCT	, 0x2200	, 0x22FF	, NULL	, NULL	, NULL	},
{ "Miscellaneous Technical"			, UCP_PUNCT	, 0x2300	, 0x23FF	, NULL	, NULL	, NULL	},
{ "Control Pictures"				, UCP_PUNCT	, 0x2400	, 0x243F	, NULL	, NULL	, NULL	},
{ "Optical Character Recognition"		, UCP_PUNCT	, 0x2440	, 0x245F	, NULL	, NULL	, NULL	},
{ "Enclosed Alphanumerics"			, UCP_PUNCT	, 0x2460	, 0x24FF	, NULL	, NULL	, NULL	},
{ "Box Drawing"					, UCP_PUNCT	, 0x2500	, 0x257F	, NULL	, NULL	, NULL	},
{ "Block Elements"				, UCP_PUNCT	, 0x2580	, 0x259F	, NULL	, NULL	, NULL	},
{ "Geometric Shapes"				, UCP_PUNCT	, 0x25A0	, 0x25FF	, NULL	, NULL	, NULL	},
{ "Miscellaneous Symbols"			, UCP_PUNCT	, 0x2600	, 0x26FF	, NULL	, NULL	, NULL	},
{ "Dingbats"					, UCP_PUNCT	, 0x2700	, 0x27BF	, NULL	, NULL	, NULL	},
{ "Braille Pattern Symbols"			, UCP_PUNCT	, 0x2800	, 0x28FF	, NULL	, NULL	, NULL	},
/*----------------------------------------------|---------------|---------------|---------------|-------|-------|-------|*/
{ "CJK Phonetics and Symbols Area"		, UCP_PUNCT	, 0x2F00	, 0x33FF	, NULL	, NULL	, NULL	},
{ "KangXi radicals"				, UCP_IDEO	, 0x2F00	, 0x2FD5	, NULL	, NULL	, NULL	},
{ "CJK Symbols and Punctuation"			, UCP_MIX	, 0x3000	, 0x303F	, NULL	, NULL	, NULL	},
{ "CJK Punctuation"				, UCP_PUNCT	, 0x3000	, 0x3006	, NULL	, NULL	, NULL	},
{ "CJK Ideograph 'number zero'"			, UCP_IDEO	, 0x3007	, 0x3007	, NULL	, NULL	, NULL	},
{ "CJK Punctuation"				, UCP_PUNCT	, 0x3008	, 0x3020	, NULL	, NULL	, NULL	},
{ "CJK Ideographic numbers"			, UCP_IDEO	, 0x3021	, 0x3029	, NULL	, NULL	, NULL	},
{ "CJK Punctuation"				, UCP_PUNCT	, 0x302A	, 0x3037	, NULL	, NULL	, NULL	},
{ "CJK Ideographic numbers"			, UCP_IDEO	, 0x3038	, 0x303A	, NULL	, NULL	, NULL	},
{ "CJK Punctuation"				, UCP_PUNCT	, 0x303E	, 0x303F	, NULL	, NULL	, NULL	},
{ "Hiragana"					, UCP_MIX	, 0x3040	, 0x309F	, NULL	, NULL	, NULL	},
{ "Hiragana Script"				, UCP_ALPHA	, 0x3040	, 0x3094	, NULL	, NULL	, NULL	},
{ "Hiragana Punctuation"			, UCP_PUNCT	, 0x3099	, 0x309E	, NULL	, NULL	, NULL	},
{ "Katakana"					, UCP_MIX	, 0x30A0	, 0x30FF	, NULL	, NULL	, NULL	},
{ "Katakana Script"				, UCP_ALPHA	, 0x30A0	, 0x30FA	, NULL	, NULL	, NULL	},
{ "Katakana Punctuation"			, UCP_PUNCT	, 0x30FB	, 0x30FE	, NULL	, NULL	, NULL	},
{ "Bopomofo"					, UCP_ALPHA	, 0x3100	, 0x312F	, NULL	, NULL	, NULL	},
{ "Hangul Compatibility Jamo"			, UCP_MIX	, 0x3130	, 0x318F	, NULL	, NULL	, NULL	},
{ "Hangul Compatibility Jamo Script"		, UCP_ALPHA	, 0x3130	, 0x3163	, NULL	, NULL	, NULL	},
{ "Hangul Compatibility Jamo Punctuation"	, UCP_PUNCT	, 0x3164	, 0x3164	, NULL	, NULL	, NULL	},
{ "Hangul Compatibility Jamo Script"		, UCP_ALPHA	, 0x3165	, 0x318F	, NULL	, NULL	, NULL	},
{ "Kanbun"					, UCP_IDEO	, 0x3190	, 0x319F	, NULL	, NULL	, NULL	},
{ "Enclosed CJK Letters and Months"		, UCP_IDEO	, 0x3200	, 0x32FF	, NULL	, NULL	, NULL	},
{ "CJK Compatibility"				, UCP_IDEO	, 0x3300	, 0x33FF	, NULL	, NULL	, NULL	},
/*----------------------------------------------|---------------|---------------|---------------|-------|-------|-------|*/
{ "I-zone (ideographic)"			, UCP_IDEO	, 0x3400	, 0x9FFF	, NULL	, NULL	, NULL	},
{ "CJK Unified Ideographs, Extension A"		, UCP_IDEO	, 0x3400	, 0x4DFF	, NULL	, NULL	, NULL	}, /* Hangul syllables in Unicode 1, undefined in Unicode 2, ideographs in Unicode 3 */
{ "CJK Unified Ideographs"			, UCP_IDEO	, 0x4E00	, 0x9FA5	, NULL	, NULL	, NULL	},
/*----------------------------------------------|---------------|---------------|---------------|-------|-------|-------|*/
{ "O-zone (other)"				, UCP_PUNCT	, 0xA000	, 0xD7FF	, NULL	, NULL	, NULL	},
{ "Yi"						, UCP_ALPHA	, 0xA000	, 0xA4C8	, NULL	, NULL	, NULL	},
{ "Hangul syllables"				, UCP_ALPHA	, 0xAC00	, 0xD7A3	, NULL	, NULL	, NULL	},
{ "S-zone (surrogates)"				, UCP_PUNCT	, 0xD800	, 0xDFFF	, NULL	, NULL	, NULL	},
{ "High Surrogates"				, UCP_PUNCT	, 0xD800	, 0xDBFF	, NULL	, NULL	, NULL	},
{ "Low Surrogates"				, UCP_PUNCT	, 0xDC00	, 0xDFFF	, NULL	, NULL	, NULL	},
{ "R-zone (reserved)"				, UCP_GAP	, 0xE000	, 0xFFFD	, NULL	, NULL	, NULL	},
{ "Private Use Area"				, UCP_PUNCT	, 0xE000	, 0xF8FF	, NULL	, NULL	, NULL	},
{ "Compatibility Area and Specials"		, UCP_PUNCT	, 0xF900	, 0xFFFF	, NULL	, NULL	, NULL	},
{ "CJK Compatibility Ideographs"		, UCP_IDEO	, 0xF900	, 0xFAFF	, NULL	, NULL	, NULL	},
{ "Alphabetic Presentation Forms"		, UCP_ALPHA	, 0xFB00	, 0xFB4F	, NULL	, NULL	, NULL	},
{ "Arabic Presentation Forms-A"			, UCP_ALPHA	, 0xFB50	, 0xFDFF	, NULL	, NULL	, NULL	},
{ "Combining Half Marks"			, UCP_ALPHA	, 0xFE20	, 0xFE2F	, NULL	, NULL	, NULL	},
{ "CJK Compatibility Forms"			, UCP_IDEO	, 0xFE30	, 0xFE4F	, NULL	, NULL	, NULL	},
{ "Small Form Variants"				, UCP_ALPHA	, 0xFE50	, 0xFE6F	, NULL	, NULL	, NULL	},
{ "Arabic Presentation Forms-B"			, UCP_ALPHA	, 0xFE70	, 0xFEFF	, NULL	, NULL	, NULL	},
{ "Halfwidth and Fullwidth Forms"		, UCP_ALPHA	, 0xFF00	, 0xFFEF	, NULL	, NULL	, NULL	},
{ "Specials"					, UCP_PUNCT	, 0xFFF0	, 0xFFFF	, NULL	, NULL	, NULL	},
/*----------------------------------------------|---------------|---------------|---------------|-------|-------|-------|*/
{ "Non-Han Supplementary Plane 1"		, UCP_GAP	, 0x00010000	, 0x0001FFFF	, NULL	, NULL	, NULL	},
{ "Etruscan"					, UCP_ALPHA	, 0x00010200	, 0x00010227	, NULL	, NULL	, NULL	},
{ "Gothic"					, UCP_ALPHA	, 0x00010230	, 0x0001024B	, NULL	, NULL	, NULL	},
{ "Klingon"					, UCP_ALPHA	, 0x000123D0	, 0x000123F9	, NULL	, NULL	, NULL	},
{ "Western Musical Symbols"			, UCP_PUNCT	, 0x0001D103	, 0x0001D1D7	, NULL	, NULL	, NULL	},
{ "Han Supplementary Plane 2"			, UCP_GAP	, 0x00020000	, 0x0002FFFF	, NULL	, NULL	, NULL	},
{ "Reserved Plane 3"				, UCP_GAP	, 0x00030000	, 0x0003FFFF	, NULL	, NULL	, NULL	},
{ "Reserved Plane 4"				, UCP_GAP	, 0x00040000	, 0x0004FFFF	, NULL	, NULL	, NULL	},
{ "Reserved Plane 5"				, UCP_GAP	, 0x00050000	, 0x0005FFFF	, NULL	, NULL	, NULL	},
{ "Reserved Plane 6"				, UCP_GAP	, 0x00060000	, 0x0006FFFF	, NULL	, NULL	, NULL	},
{ "Reserved Plane 7"				, UCP_GAP	, 0x00070000	, 0x0007FFFF	, NULL	, NULL	, NULL	},
{ "Reserved Plane 8"				, UCP_GAP	, 0x00080000	, 0x0008FFFF	, NULL	, NULL	, NULL	},
{ "Reserved Plane 9"				, UCP_GAP	, 0x00090000	, 0x0009FFFF	, NULL	, NULL	, NULL	},
{ "Reserved Plane 10"				, UCP_GAP	, 0x000A0000	, 0x000AFFFF	, NULL	, NULL	, NULL	},
{ "Reserved Plane 11"				, UCP_GAP	, 0x000B0000	, 0x000BFFFF	, NULL	, NULL	, NULL	},
{ "Reserved Plane 12"				, UCP_GAP	, 0x000C0000	, 0x000CFFFF	, NULL	, NULL	, NULL	},
{ "Reserved Plane 13"				, UCP_GAP	, 0x000D0000	, 0x000DFFFF	, NULL	, NULL	, NULL	},
{ "Plane 14"					, UCP_GAP	, 0x000E0000	, 0x000EFFFF	, NULL	, NULL	, NULL	},
{ "Language Tag Characters"			, UCP_PUNCT	, 0x000E0000	, 0x000E007F	, NULL	, NULL	, NULL	},
{ "Private Use Planes"				, UCP_GAP	, 0x000F0000	, 0x000F3FFF	, NULL	, NULL	, NULL	},
{ "Private Use Planes"				, UCP_GAP	, 0x000F4000	, 0x000F7FFF	, NULL	, NULL	, NULL	},
{ "Private Use Planes"				, UCP_GAP	, 0x000F8000	, 0x000FBFFF	, NULL	, NULL	, NULL	},
{ "Private Use Planes"				, UCP_GAP	, 0x000FC000	, 0x000FFFFF	, NULL	, NULL	, NULL	},
{ "Private Use Planes"				, UCP_GAP	, 0x00100000	, 0x00103FFF	, NULL	, NULL	, NULL	},
{ "Private Use Planes"				, UCP_GAP	, 0x00104000	, 0x00107FFF	, NULL	, NULL	, NULL	},
{ "Private Use Planes"				, UCP_GAP	, 0x00108000	, 0x0010BFFF	, NULL	, NULL	, NULL	},
{ "Private Use Planes"				, UCP_GAP	, 0x0010C000	, 0x0010FFFF	, NULL	, NULL	, NULL	} };


#define LENGTHOF__raw_uniblocks (sizeof(raw_uniblocks)/sizeof(unicode_block_t))
#define LENGTHOF__work_uniblocks (1+2*LENGTHOF__raw_uniblocks)

unicode_block_t work_uniblocks[LENGTHOF__work_uniblocks] = {
{ "Set of valid Unicode characters"		, UCP_GAP	, 0x00000000	, 0x7FFFFFFF	, NULL	, NULL	, NULL	} };

unicode_block_t *raw_uniblocks_array = raw_uniblocks;
unicode_block_t *work_uniblocks_array = work_uniblocks;

int raw_uniblocks_fill = LENGTHOF__raw_uniblocks;
int work_uniblocks_fill=1;

int reset_work_uniblocks(void)
{
  int raw_ctr, raw_maxctr, work_ctr;
  unicode_block_t *prev_work, *curr_work, *curr_raw;
  unicode_block_t dummy = {"", 0, 0, 0, NULL, NULL, NULL};
  memcpy(work_uniblocks,raw_uniblocks,sizeof(unicode_block_t));
  work_uniblocks_fill=1;
/* Pass 1, Work table should be filled by non-overlapping "leaf" blocks with gaps between them */
  for(raw_ctr = 1; raw_ctr < LENGTHOF__raw_uniblocks; raw_ctr++)
    {
      curr_work = work_uniblocks+work_uniblocks_fill;
      prev_work = curr_work-1;
      curr_raw = raw_uniblocks+raw_ctr;
      if (curr_raw->ub_max <= (prev_work->ub_max))
	{
	  curr_work--;
	  if (prev_work == work_uniblocks)
	    prev_work = &dummy;
	  else
	    prev_work--;
	  work_uniblocks_fill--;
	}
      if ((prev_work > work_uniblocks) && (curr_raw->ub_min > (prev_work->ub_max + 1)))
	{
	  memset(curr_work,0,sizeof(unicode_block_t));
	  curr_work->ub_descr = "Unused";
	  curr_work->ub_props = UCP_GAP;
	  curr_work->ub_min = prev_work->ub_max + 1;
	  curr_work->ub_max = curr_raw->ub_min - 1;
#ifdef LANGFUNC_TEST
	  fprintf (out,
	    "Draft of work_uniblocks: gap %08x - %08x added @ %d\n",
	    (int)(curr_work->ub_min),
	    (int)(curr_work->ub_max),
	    (curr_work-work_uniblocks) );
#endif
	  work_uniblocks_fill++;
	  curr_work++;
	}
      memcpy(curr_work,curr_raw,sizeof(unicode_block_t));
#ifdef LANGFUNC_TEST
      fprintf (out,
	"Draft of work_uniblocks: block %08x - %08x added @ %d\n",
	(int)(curr_work->ub_min),
	(int)(curr_work->ub_max),
	(curr_work-work_uniblocks) );
#endif
      work_uniblocks_fill++;
    }
  curr_work = work_uniblocks+work_uniblocks_fill;
  prev_work = curr_work-1;
  memset(curr_work,0,sizeof(unicode_block_t));
  curr_work->ub_props = UCP_GAP;
  curr_work->ub_min = prev_work->ub_max + 1;
  curr_work->ub_max = 0x7FFFFFFF;
  work_uniblocks_fill++;
#ifdef LANGFUNC_TEST
  fprintf (out,
    "Draft of work_uniblocks completed, %d raw blocks, %d/%d work blocks:\n",
    LENGTHOF__raw_uniblocks, work_uniblocks_fill, LENGTHOF__work_uniblocks );
  for (work_ctr = 0; work_ctr < work_uniblocks_fill; work_ctr++)
    {
      curr_work = work_uniblocks+work_ctr;
      fprintf (out, "%08x - %08x | %08x\n",
	(int)(curr_work->ub_min),
	(int)(curr_work->ub_max),
	(int)(curr_work->ub_props) );
    }
  fprintf (out,"\n");
#endif
/* Pass 2, Gaps should be filled by data from any blocks no matter if they contain subblocks or not */
  raw_maxctr = LENGTHOF__raw_uniblocks;
  for (work_ctr = work_uniblocks_fill; work_ctr--; /* no step */)
    {
      curr_work = work_uniblocks+work_ctr;
      if (curr_work->ub_props != UCP_GAP)
	continue;
      while (raw_maxctr > 0 && raw_uniblocks[raw_maxctr].ub_min > curr_work->ub_min)
	raw_maxctr--;
      for(raw_ctr = raw_maxctr; raw_ctr--; /* no step */)
	{
	  curr_raw = raw_uniblocks+raw_ctr;
	  if (curr_raw->ub_min > curr_work->ub_min)
	    continue;
	  if (curr_raw->ub_max < curr_work->ub_max)
	    continue;
	  curr_work->ub_descr = curr_raw->ub_descr;
	  curr_work->ub_props = curr_raw->ub_props;
	  curr_work->ub_getprops = curr_raw->ub_getprops;
	  curr_work->ub_getucase = curr_raw->ub_getucase;
	  curr_work->ub_getlcase = curr_raw->ub_getlcase;
	}
    }
/* Pass 3, Default handlers should be set */
  for (work_ctr = work_uniblocks_fill; work_ctr--; /* no step */)
    {
      curr_work = work_uniblocks+work_ctr;
      if ((UCP_ALPHA == curr_work->ub_props) && (NULL == curr_work->ub_getucase))
	curr_work->ub_getucase = unicode3_getucase;
      if ((UCP_ALPHA == curr_work->ub_props) && (NULL == curr_work->ub_getlcase))
	curr_work->ub_getlcase = unicode3_getlcase;
      if ((UCP_MIX == curr_work->ub_props) && (NULL == curr_work->ub_getprops))
	curr_work->ub_getprops = unichar_getprops_stub;
    }
#ifdef LANGFUNC_TEST
  fprintf (out,
    "Initialization of work_uniblocks completed, %d raw blocks, %d/%d work blocks:\n",
    LENGTHOF__raw_uniblocks, work_uniblocks_fill, LENGTHOF__work_uniblocks );
  for (work_ctr = 0; work_ctr < work_uniblocks_fill; work_ctr++)
    {
      curr_work = work_uniblocks+work_ctr;
      fprintf (out, "%08x - %08x | %08x\n",
	(int)(curr_work->ub_min),
	(int)(curr_work->ub_max),
	(int)(curr_work->ub_props) );
    }
  fprintf (out,"\n");
#endif
  return 0;
}


unicode_block_t *ub_getblock(unichar uchr)
{
  int left_cop, robber, right_cop;
  if(uchr & ~0x7FFFFFFF)
    return NULL;
  if(!(uchr & ~0xFF))
    return ((uchr & 0x80) ? (work_uniblocks + 1) : work_uniblocks);
  left_cop = 0;
  right_cop = work_uniblocks_fill-1;
  while(left_cop<right_cop)
    {
      robber = (left_cop+right_cop)/2;
      if(work_uniblocks[robber].ub_min>uchr)
	right_cop = robber-1;
      else
	{
	  if (left_cop < robber)
	    left_cop = robber;
	  else
	    if (work_uniblocks[right_cop].ub_min>uchr)
	      right_cop--;
	    else
	      if (work_uniblocks[left_cop].ub_max<uchr)
	        left_cop++;
	}
    }
  return work_uniblocks+left_cop;
}


int unichar_getprops (unichar uchr)
{
  unicode_block_t *ub = ub_getblock(uchr);
#ifdef LANGFUNC_TEST
  fprintf(out,"unichar_getprops('");
  unicode_dump(&uchr,1);
  fprintf(out,"')");
#endif
  if(uchr & ~0x7FFFFFFF)
    {
#ifdef LANGFUNC_TEST
      fprintf(out," returns UCP_BAD\n");
#endif
      return UCP_BAD;
    }
  if(NULL == ub->ub_getprops)
    {
#ifdef LANGFUNC_TEST
      fprintf(out," returns %d w/o ub_getprops\n", (int)(ub->ub_props));
#endif
      return ub->ub_props;
    }
#ifdef LANGFUNC_TEST
  fprintf(out," returns %d via ub_getprops\n", (int)(ub->ub_getprops(uchr)));
#endif
  return ub->ub_getprops(uchr);
}


static int unichar_getprops_stub (unichar uchr)
{
  if(!(uchr & ~0xFF))
    {
      if(latin1isalnum((unsigned char)uchr))
	return UCP_ALPHA;
      return UCP_PUNCT;
    }
  if (unicode3_getucase(uchr) != uchr)
    return UCP_ALPHA;
  if (unicode3_getlcase(uchr) != uchr)
    return UCP_ALPHA;
  return UCP_PUNCT;
}


unichar unichar_getucase (unichar uchr)
{
  unicode_block_t *ub;
  if(!(uchr & ~0xFF))
    return latin1toupper((unsigned char)uchr);
  if(uchr & ~0x7FFFFFFF)
    return uchr;
  ub = ub_getblock(uchr);
  if(NULL == ub->ub_getucase)
    return uchr;
  return ub->ub_getucase(uchr);
}


unichar unichar_getlcase (unichar uchr)
{
  unicode_block_t *ub;
  if(!(uchr & ~0xFF))
    return latin1tolower((unsigned char)uchr);
  if(uchr & ~0x7FFFFFFF)
    return uchr;
  ub = ub_getblock(uchr);
  if(NULL == ub->ub_getlcase)
    return uchr;
  return ub->ub_getlcase(uchr);
}


#ifdef LANGFUNC_TEST

void unicode_dump (const unichar *buf, size_t bufsize)
{
  size_t ctr;
  for (ctr = 0; ((bufsize != (size_t)(-1)) ? (ctr < bufsize) : buf[ctr]); ctr++)
    {
      if((buf[ctr] & ~0xFF) || (!(buf[ctr] & ~0x1F)))
	fprintf(out,"\\x%04x",(unsigned int)(buf[ctr]));
      else
	fprintf(out,"%c",(char)(buf[ctr]));
    }
}
#endif


#ifndef __NO_LIBDK

id_hash_t *lh_noise_words;

int lh_is_vtb_word__xany (const unichar *buf, size_t bufsize)
{
  lenmem_t lm;
  char *nw;
#ifdef LANGFUNC_TEST
  fprintf(out,"lh_is_vtb_word__xany('");
  unicode_dump(buf,bufsize);
  fprintf(out,"')");
#endif
  if (1 > bufsize)
    {
#ifdef LANGFUNC_TEST
      fprintf(out," returns 0 (too short)\n");
#endif
      return 0;
    }
  lm.lm_length = bufsize * sizeof(unichar);
  lm.lm_memblock = (/*const*/ char *)buf;
  nw = id_hash_get (lh_noise_words, (char *) &lm);
  if (NULL == nw)
    {
#ifdef LANGFUNC_TEST
      fprintf(out," returns 1\n");
#endif
      return 1;
    }
#ifdef LANGFUNC_TEST
  fprintf(out," returns 0 (noise)\n");
#endif
  return 0;
}

#else

int lh_is_vtb_word__xany (const unichar *buf, size_t bufsize)
{
#ifdef LANGFUNC_TEST
  fprintf(out,"lh_is_vtb_word__xany('");
  unicode_dump(buf,bufsize);
  fprintf(out,"')");
#endif
  if (1 > bufsize)
    {
#ifdef LANGFUNC_TEST
      fprintf(out," returns 0 (too short)\n");
#endif
      return 0;
    }
#ifdef LANGFUNC_TEST
  fprintf(out," returns 1\n");
#endif
  return 1;
}

#endif

int lh_tocapital_word__xany (const unichar *srcbuf, size_t srcbufsize, unichar *tgtbuf, size_t *tgtbufsize)
{
  size_t ctr;
  if (WORD_MAX_CHARS < srcbufsize)
    return 0;
  for (ctr = 0; ctr < 1; ctr++)
    tgtbuf[ctr] = unichar_getucase (srcbuf[ctr]);
  for (/* no init */; ctr < srcbufsize; ctr++)
    tgtbuf[ctr] = unichar_getlcase (srcbuf[ctr]);
  tgtbufsize[0] = srcbufsize;
  return 1;
}


int lh_toupper_word__xany (const unichar *srcbuf, size_t srcbufsize, unichar *tgtbuf, size_t *tgtbufsize)
{
  size_t ctr;
  if (WORD_MAX_CHARS < srcbufsize)
    return 0;
  for (ctr = 0; ctr < srcbufsize; ctr++)
    tgtbuf[ctr] = unichar_getucase (srcbuf[ctr]);
  tgtbufsize[0] = srcbufsize;
  return 1;
}


int lh_tolower_word__xany (const unichar *srcbuf, size_t srcbufsize, unichar *tgtbuf, size_t *tgtbufsize)
{
  size_t ctr;
  if (WORD_MAX_CHARS < srcbufsize)
    return 0;
  for (ctr = 0; ctr < srcbufsize; ctr++)
    tgtbuf[ctr] = unichar_getlcase (srcbuf[ctr]);
  tgtbufsize[0] = srcbufsize;
  return 1;
}

int lh_xany_normalization_flags = 0;

int lh_normalize_word__xany (const unichar *srcbuf, size_t srcbufsize, unichar *tgtbuf, size_t *tgtbufsize)
{
  size_t ctr, tgt_count = 0, srcsz1;
  /* int isspecial = 0; */
  if ((WORD_MAX_CHARS < srcbufsize) || (1 > srcbufsize))
    return 0;
  switch (lh_xany_normalization_flags & (LH_XANY_NORMALIZATION_COMBINE | LH_XANY_NORMALIZATION_TOBASE))
    {
    case LH_XANY_NORMALIZATION_COMBINE | LH_XANY_NORMALIZATION_TOBASE:
      tgt_count = 0;
      srcsz1 = srcbufsize-1;
      for (ctr = 0; ctr < srcsz1; ctr++)
        {
          unichar u = srcbuf[ctr];
          unichar next = srcbuf[ctr+1];
          unichar res;
          if ((next >= unicode3_min_used_modif_char) && (next <= unicode3_max_used_modif_char))
            {
              res = unicode3_combine_base_and_modif_upper (u, next);
              if (res)
                {
                  tgtbuf[tgt_count++] = unicode3_getupperbasechar (res);
                  ctr++;
                  continue;
                }
            }
          res = unicode3_getupperbasechar (u);
          tgtbuf[tgt_count++] = res;
        }
      if (ctr < srcbufsize)
        tgtbuf[tgt_count++] = unicode3_getupperbasechar (srcbuf[ctr]);
      break;
    case LH_XANY_NORMALIZATION_COMBINE:
      tgt_count = 0;
      srcsz1 = srcbufsize-1;
      for (ctr = 0; ctr < srcsz1; ctr++)
        {
          unichar u = srcbuf[ctr];
          unichar next = srcbuf[ctr+1];
          unichar res;
          if ((next >= unicode3_min_used_modif_char) && (next <= unicode3_max_used_modif_char))
            {
              res = unicode3_combine_base_and_modif_upper (u, next);
              if (res)
                {
                  tgtbuf[tgt_count++] = unicode3_getupperbasechar (res);
                  ctr++;
                  continue;
                }
            }
          res = unicode3_getupperbasechar (u);
          tgtbuf[tgt_count++] = res;
        }
      if (ctr < srcbufsize)
        tgtbuf[tgt_count++] = unichar_getucase (srcbuf[ctr]);
      break;
    case LH_XANY_NORMALIZATION_TOBASE:
      for (ctr = 0; ctr < srcbufsize; ctr++)
        {
          unichar u = srcbuf[ctr];
          u = unicode3_getupperbasechar (u);
          tgtbuf[ctr] = u;
          /* if (u < 'A')
            isspecial = 1; */
        }
      tgt_count = srcbufsize;
      break;
    case 0:
  for (ctr = 0; ctr < srcbufsize; ctr++)
    {
          unichar u = srcbuf[ctr];
          u = unichar_getucase (u);
          tgtbuf[ctr] = u;
          /* if (u < 'A')
        isspecial = 1; */
    }
      tgt_count = srcbufsize;
      break;
    }
#if 0 /* This is commented out because this plural-to-single is not fully valid */
  if (isspecial || (tgt_count < 3) || ('S' != tgtbuf[tgt_count - 1]) || ('S' == tgtbuf[tgt_count - 2]))
    { /* Special or singular */
      tgtbufsize[0] = tgt_count;
      return 1;
    }
  if ('E' == tgtbuf[tgt_count - 2])
    { /* "...ES"  plural */
      if ((3 == tgt_count) && ('Y' == tgtbuf[0]))
        { /* "YES" is singular */
          tgtbufsize[0] = tgt_count;
          return 1;
        }
      if ('I' == tgtbuf[tgt_count - 3])
        { /* "...IES" plural */
          tgtbuf[tgt_count - 3] = 'Y';
          tgtbufsize[0] = tgt_count - 2;
          return 1;
        }
      if ('S' == tgtbuf[tgt_count - 3])
        { /* "...SES" plural */
          tgtbufsize[0] = tgt_count - 2;
          return 1;
        }
      tgtbufsize[0] = tgt_count - 1;
      return 1;
    }  
  tgtbufsize[0] = tgt_count - 1; /* "...S"  plural */
#else
  tgtbufsize[0] = tgt_count;
#endif
  return 1;
}


#define LH_COUNT_WORDS_NAME lh_count_words__xany
#define LH_ITERATE_WORDS_NAME lh_iterate_words__xany
#define LH_ITERATE_PATCHED_WORDS_NAME lh_iterate_patched_words__xany
#define UNICHAR_GETPROPS_EXPN(buf,bufsize,pos) (unichar_getprops(buf[pos]))
#define DBG_PRINTF_NOISE_WORD(word_start,word_length) dbg_printf (("Noise word in text, start %ld, length %ld\n", (long)word_start, (long)word_length))
#define DBG_PRINTF_PATCH_FAILED(word_start,word_length) dbg_printf (("Patch of word failed in text, start %ld, length %ld\n", (long)word_start, (long)word_length))
#define DBG_PRINTF_NOISE_IDEO(word_start,word_length) dbg_printf (("Noise ideograph in text, start %ld, length %ld\n", (long)word_start, (long)word_length))
#define DBG_PRINTF_IDEO_PATCH_FAILED(word_start,word_length) dbg_printf (("Patch of ideograph failed in text, start %ld, length %ld\n", (long)word_start, (long)word_length))
#include "langfunc_templ.c"
#undef LH_COUNT_WORDS_NAME
#undef LH_ITERATE_WORDS_NAME
#undef LH_ITERATE_PATCHED_WORDS_NAME
#undef UNICHAR_GETPROPS_EXPN
#undef DBG_PRINTF_NOISE_WORD
#undef DBG_PRINTF_PATCH_FAILED
#undef DBG_PRINTF_NOISE_IDEO
#undef DBG_PRINTF_IDEO_PATCH_FAILED


#define LH_COUNT_WORDS_NAME lh_count_words__xftqxany
#define LH_ITERATE_WORDS_NAME lh_iterate_words__xftqxany
#define LH_ITERATE_PATCHED_WORDS_NAME lh_iterate_patched_words__xftqxany
#define UNICHAR_GETPROPS_EXPN(buf,bufsize,pos) ((('*' == (buf[pos])) ? UCP_ALPHA : unichar_getprops (buf[pos])))
#define DBG_PRINTF_NOISE_WORD(word_start,word_length) dbg_printf (("Noise word in query, start %ld, length %ld\n", (long)word_start, (long)word_length))
#define DBG_PRINTF_PATCH_FAILED(word_start,word_length) dbg_printf (("Patch of word failed in query, start %ld, length %ld\n", (long)word_start, (long)word_length))
#define DBG_PRINTF_NOISE_IDEO(word_start,word_length) dbg_printf (("Noise ideograph in query, start %ld, length %ld\n", (long)word_start, (long)word_length))
#define DBG_PRINTF_IDEO_PATCH_FAILED(word_start,word_length) dbg_printf (("Patch of ideograph failed in query, start %ld, length %ld\n", (long)word_start, (long)word_length))
#include "langfunc_templ.c"
#undef LH_COUNT_WORDS_NAME
#undef LH_ITERATE_WORDS_NAME
#undef LH_ITERATE_PATCHED_WORDS_NAME
#undef UNICHAR_GETPROPS_EXPN
#undef DBG_PRINTF_NOISE_WORD
#undef DBG_PRINTF_PATCH_FAILED
#undef DBG_PRINTF_NOISE_IDEO
#undef DBG_PRINTF_IDEO_PATCH_FAILED


void lh_iterate_hyppoints__xany(const unichar *buf, size_t bufsize, lh_word_check_t *check, lh_word_patch_t *patch, lh_word_callback_t *callback, void *userdata)
{
  ((int *)(-1))[0]++; /* To make an GPF */
}


int elh_count_words__xany__UTF8(const char *buf, size_t bufsize, lh_word_check_t *check)
{
  unichar check_buf[WORD_MAX_CHARS];
  int res = 0;
  int prop;
  const char *curr = buf;
  const char *buf_end = buf+bufsize;
  const char *word_begin = curr;
  const char *word_end = NULL;
  unichar uchr;
  size_t word_length;
  while (curr < buf_end)
    {
      word_begin = curr;
      uchr = eh_decode_char__UTF8 (&curr, buf_end);
      prop = unichar_getprops (uchr);
      if (prop & UCP_ALPHA)
	{
	  check_buf[0] = uchr;
	  word_length = 1;
	  for(;;)
	    {
	      word_end = curr;
	      uchr = eh_decode_char__UTF8 (&curr, buf_end);
	      if (uchr < 0)
		{
		  if ((UNICHAR_NO_DATA == uchr) || (UNICHAR_BAD_ENCODING == uchr))
		    return uchr;
		  if (UNICHAR_EOD == uchr)
		    break;
		}
	      prop = unichar_getprops (uchr);
	      if (!(prop & UCP_ALPHA))
		break;
	      if (WORD_MAX_CHARS > word_length)
		check_buf[word_length] = uchr;
	      word_length++;
	    }
	  if (WORD_MAX_CHARS < word_length)
	    goto done_word;
	  if (NULL!=check && 0 == check(check_buf, word_length))
	    goto done_word;
	  res++;
done_word:
	  if (prop & UCP_IDEO)
	    goto proc_ideo;
	  continue;
	}
      if (prop & UCP_IDEO)
	{
proc_ideo:
	  check_buf[0] = uchr;
	  if (NULL!=check && 0 == check(check_buf, 1))
	    continue;
	  res++;
	  continue;
	}
      if ((uchr < 0) && ((UNICHAR_NO_DATA == uchr) || (UNICHAR_BAD_ENCODING == uchr)))
	return uchr;
    }
  return res;
}


int elh_iterate_words__xany__UTF8(const char *buf, size_t bufsize, lh_word_check_t *check, lh_word_callback_t *callback, void *userdata)
{
  unichar check_buf[WORD_MAX_CHARS];
  int prop;
  const char *curr = buf;
  const char *buf_end = buf+bufsize;
  const char *word_begin = curr;
  const char *word_end;
  unichar uchr;
  size_t word_length;
  while (curr < buf_end)
    {
      word_begin = curr;
      uchr = eh_decode_char__UTF8 (&curr, buf_end);
      prop = unichar_getprops (uchr);
      if (prop & UCP_ALPHA)
	{
	  check_buf[0] = uchr;
	  word_length = 1;
	  for(;;)
	    {
	      word_end = curr;
	      uchr = eh_decode_char__UTF8 (&curr, buf_end);
	      if (uchr < 0)
		{
		  if ((UNICHAR_NO_DATA == uchr) || (UNICHAR_BAD_ENCODING == uchr))
		    return uchr;
		  if (UNICHAR_EOD == uchr)
		    break;
		}
	      prop = unichar_getprops (uchr);
	      if (!(prop & UCP_ALPHA))
		break;
	      if (WORD_MAX_CHARS > word_length)
		check_buf[word_length] = uchr;
	      word_length++;
	    }
	  if (WORD_MAX_CHARS < word_length)
	    goto done_word;
	  if (NULL!=check && 0 == check (check_buf, word_length))
	    goto done_word;
	  callback ((utf8char *)(word_begin), word_end-word_begin, userdata);
done_word:
	  if (prop & UCP_IDEO)
	    goto proc_ideo;
	  continue;
	}
      if (prop & UCP_IDEO)
	{
proc_ideo:
	  check_buf[0] = uchr;
	  if (NULL!=check && 0 == check (check_buf, 1))
	    continue;
	  callback ((utf8char *)(word_begin), curr-word_begin, userdata);
	  continue;
	}
      if ((uchr < 0) && ((UNICHAR_NO_DATA == uchr) || (UNICHAR_BAD_ENCODING == uchr)))
	return uchr;
    }
  return 0;
}


int elh_iterate_patched_words__xany__UTF8(const char *buf, size_t bufsize, lh_word_check_t *check, lh_word_patch_t *patch, lh_word_callback_t *callback, void *userdata)
{
  unichar check_buf[WORD_MAX_CHARS];
  int prop;
  const char *curr = buf;
  const char *buf_end = buf+bufsize;
  const char *word_begin = curr;
  const char *word_end = NULL;
  unichar uchr;
  size_t word_length;
  unichar patch_buf[WORD_MAX_CHARS];
  const unichar *arg_begin;
  size_t arg_length;
  char word_buf[BUFSIZEOF__UTF8_WORD];
  char *hugeword_buf = NULL;
  size_t hugeword_buf_size = 0;
  while (curr < buf_end)
    {
      word_begin = curr;
      uchr = eh_decode_char__UTF8 (&curr, buf_end);
      prop = unichar_getprops (uchr);
      if (prop & UCP_ALPHA)
	{
	  check_buf[0] = uchr;
	  word_length = 1;
	  for(;;)
	    {
	      word_end = curr;
	      uchr = eh_decode_char__UTF8 (&curr, buf_end);
	      if (uchr < 0)
		{
		  if ((UNICHAR_NO_DATA == uchr) || (UNICHAR_BAD_ENCODING == uchr))
		    return uchr;
		  if (UNICHAR_EOD == uchr)
		    break;
		}
	      prop = unichar_getprops (uchr);
	      if (!(prop & UCP_ALPHA))
		break;
	      if (WORD_MAX_CHARS > word_length)
		check_buf[word_length] = uchr;
	      word_length++;
	    }
	  if (WORD_MAX_CHARS < word_length)
	    goto done_word;
	  if (NULL!=check && 0 == check (check_buf, word_length))
	    goto done_word;
	  if (NULL != patch)
	    {
	      if (0 == patch (check_buf, word_length, patch_buf, &arg_length))
		goto done_word;
	      arg_begin = patch_buf;
	    }
	  else
	    {
	      callback ((utf8char *) word_begin, word_end-word_begin, userdata);
	      goto done_word;
	    }
	  word_end = eh_encode_buffer__UTF8 (arg_begin, arg_begin+arg_length, word_buf, word_buf+BUFSIZEOF__UTF8_WORD);
	  if (NULL != word_end)
	    {
	      callback ((utf8char *)(word_buf), word_end-word_buf, userdata);
	      goto done_word;
	    }
	  if (hugeword_buf_size<(word_length*MAX_UTF8_CHAR))
	    {
	      if (hugeword_buf_size)
		dk_free (hugeword_buf, hugeword_buf_size);
	      hugeword_buf_size = word_length*MAX_UTF8_CHAR;
	      hugeword_buf = (char *) dk_alloc (hugeword_buf_size);
	    }
	  word_end = eh_encode_buffer__UTF8 (arg_begin, arg_begin+arg_length, hugeword_buf, hugeword_buf+hugeword_buf_size);
	  callback ((utf8char *)(hugeword_buf), word_end-hugeword_buf, userdata);
done_word:
	  if (prop & UCP_IDEO)
	    goto proc_ideo;
	  continue;
	}
      if (prop & UCP_IDEO)
	{
proc_ideo:
	  check_buf[0] = uchr;
	  if (NULL!=check && 0 == check (check_buf, 1))
	    continue;
	  if (NULL != patch)
	    {
	      if (0 == patch (check_buf, 1, patch_buf, &arg_length))
		continue;
	      arg_begin = patch_buf;
	    }
	  else
	    {
	      callback ((utf8char *) word_begin, curr-word_begin, userdata);
	      continue;
	    }
	  word_end = eh_encode_buffer__UTF8 (arg_begin, arg_begin+arg_length, word_buf, word_buf+BUFSIZEOF__UTF8_WORD);
	  callback ((utf8char *)(word_buf), word_end-word_buf, userdata);
	  continue;
	}
      if ((uchr < 0) && ((UNICHAR_NO_DATA == uchr) || (UNICHAR_BAD_ENCODING == uchr)))
	goto cleanup; /* see below */
    }
  uchr = 0;
cleanup:
  if (hugeword_buf_size)
    dk_free (hugeword_buf, hugeword_buf_size);
  return uchr;
}



lang_handler_t lh__xany = {
  "x-any",		/* ISO 639 */
  "x-any",		/* RFC 1766 */
  NULL,			/* more generic handler */
  &lh__xftqxany,	/* query language handler */
  1, WORD_MAX_CHARS,	/* minimal and maximal lengths of one indexable word */
  NULL,			/* application-specific data */
  lh_is_vtb_word__xany,
  lh_tocapital_word__xany,
  lh_toupper_word__xany,
  lh_tolower_word__xany,
  lh_normalize_word__xany,
  lh_count_words__xany,
  lh_iterate_words__xany,
  lh_iterate_patched_words__xany,
#ifdef HYPHENATION_OK
  lh_iterate_hyppoints__xany
#endif
};


lang_handler_t lh__xftqxany = {
  "x-ftq-x-any",	/* ISO 639 */
  "x-ftq-x-any",	/* RFC 1766 */
  NULL,			/* more generic handler */
  &lh__xftqxany,	/* query language handler */
  1, WORD_MAX_CHARS,	/* minimal and maximal lengths of one indexable word */
  NULL,			/* application-specific data */
  lh_is_vtb_word__xany,
  lh_tocapital_word__xany,
  lh_toupper_word__xany,
  lh_tolower_word__xany,
  lh_normalize_word__xany,
  lh_count_words__xftqxany,
  lh_iterate_words__xftqxany,
  lh_iterate_patched_words__xftqxany,
#ifdef HYPHENATION_OK
  lh_iterate_hyppoints__xftqxany
#endif
};


encodedlang_handler_t elh__xany__UTF8 = {
  &lh__xany,
  &eh__UTF8,
  NULL /*&elh__xftqxany__UTF8*/,
  NULL,			/* application-specific data */
  elh_count_words__xany__UTF8,
  elh_iterate_words__xany__UTF8,
  elh_iterate_patched_words__xany__UTF8,
#ifdef HYPHENATION_OK
  elh_iterate_hyppoints__xany__UTF8
#endif
};


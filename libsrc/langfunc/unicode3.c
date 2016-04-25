/*
 *  
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *  
 *  Copyright (C) 1998-2016 OpenLink Software
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
#include "Dkhash.h"


/* Conversion to uppercase */

struct unicode3_toupper_s
{
  unsigned short int u3c_cell;
  unsigned short int u3c_ucase;
};

typedef struct unicode3_toupper_s unicode3_toupper_t;

#define UNICODE3_HEADER unicode3_toupper_t unicode3_lowers[] = {
#define UNICODE3_FOOTER {~0} };
#define UNICODE3_REC(cell,grp1,idx1,grp2,digit1,digit2,digit3,ucase1,lcase,ucase2,flg1,repl1,name1,name2,unicodename) \
{cell,ucase1},
#include "unicode3_lowers.h"
#undef UNICODE3_HEADER
#undef UNICODE3_FOOTER
#undef UNICODE3_REC


unichar unicode3_getucase (unichar uchr)
{
  int left_cop = 0;
  int right_cop = (int)(sizeof(unicode3_lowers)/sizeof(unicode3_lowers[0])) - 1;
  int robber = (26-1);	/* We should optimize search for the most important case - 26 Latin chars */
  unichar curr;
  while (left_cop <= right_cop)
    {
      curr = unicode3_lowers[robber].u3c_cell;
      if (uchr == curr)
	return unicode3_lowers[robber].u3c_ucase;
      if (uchr < curr)
	right_cop = robber-1;
      else
	left_cop = robber+1;
      robber = (left_cop+right_cop)/2;
    }
  return uchr;
}


/* Conversion to lowercase */

struct unicode3_tolower_s
{
  unsigned short int u3c_cell;
  unsigned short int u3c_lcase;
};

typedef struct unicode3_tolower_s unicode3_tolower_t;

#define UNICODE3_HEADER unicode3_tolower_t unicode3_uppers[] = {
#define UNICODE3_FOOTER {~0} };
#define UNICODE3_REC(cell,grp1,idx1,grp2,digit1,digit2,digit3,ucase1,lcase,ucase2,flg1,repl1,name1,name2,unicodename) \
{cell,lcase},
#include "unicode3_uppers.h"
#undef UNICODE3_HEADER
#undef UNICODE3_FOOTER
#undef UNICODE3_REC


unichar unicode3_getlcase (unichar uchr)
{
  int left_cop = 0;
  int right_cop = (int)(sizeof(unicode3_uppers)/sizeof(unicode3_uppers[0])) - 1;
  int robber = (26-1);	/* We should optimize search for the most important case - 26 Latin chars */
  unichar curr;
  while (left_cop <= right_cop)
    {
      curr = unicode3_uppers[robber].u3c_cell;
      if (uchr == curr)
	return unicode3_uppers[robber].u3c_lcase;
      if (uchr < curr)
	right_cop = robber-1;
      else
	left_cop = robber+1;
      robber = (left_cop+right_cop)/2;
    }
  return uchr;
}


/* Conversion to base char */

struct unicode3_tobasechar_s
{
  unsigned short int u3c_cell;
  unsigned short int u3c_basechar;
  unsigned short int u3c_upperbasechar;
  unsigned short int u3c_modifier;
};

typedef struct unicode3_tobasechar_s unicode3_tobasechar_t;

#define UNICODE3_HEADER unicode3_tobasechar_t unicode3_tobasechars[] = {
#define UNICODE3_FOOTER {~0} };
#define UNICODE3_S2(mode,base,modif) base, base, modif
#define UNICODE3_S1(mode,base) base, base, 0
#define UNICODE3_REC(cell,grp1,idx1,grp2,digit1,digit2,digit3,ucase1,lcase,ucase2,flg1,repl1,name1,name2,unicodename) \
{cell,repl1},
#include "unicode3_basechars.h"
#undef UNICODE3_HEADER
#undef UNICODE3_FOOTER
#undef UNICODE3_REC


unichar unicode3_getbasechar (unichar uchr)
{
  int left_cop = 0;
  int right_cop = (int)(sizeof(unicode3_tobasechars)/sizeof(unicode3_tobasechars[0])) - 1;
  int robber = (252-1);	/* We should optimize search for the most important case - 252(!) different modified Latin chars */
  unichar curr;
  while (left_cop <= right_cop)
    {
      curr = unicode3_tobasechars[robber].u3c_cell;
      if (uchr == curr)
	return unicode3_tobasechars[robber].u3c_basechar;
      if (uchr < curr)
	right_cop = robber-1;
      else
	left_cop = robber+1;
      robber = (left_cop+right_cop)/2;
    }
  return uchr;
}

unichar unicode3_getupperbasechar (unichar uchr)
{
  int left_cop = 0;
  int right_cop = (int)(sizeof(unicode3_tobasechars)/sizeof(unicode3_tobasechars[0])) - 1;
  int robber = (252-1);	/* We should optimize search for the most important case - 252(!) different modified Latin chars */
  unichar curr;
  while (left_cop <= right_cop)
    {
      curr = unicode3_tobasechars[robber].u3c_cell;
      if (uchr == curr)
	return unicode3_tobasechars[robber].u3c_upperbasechar;
      if (uchr < curr)
	right_cop = robber-1;
      else
	left_cop = robber+1;
      robber = (left_cop+right_cop)/2;
    }
  return unicode3_getucase (uchr);
}

/* Conversion from a base char and modif to a single combined char */

dk_hash_t *unicode3_modif_usages = NULL;
dk_hash_t *unicode3_charmodif_to_combined = NULL;
dk_hash_t *unicode3_charmodif_to_combined_upper = NULL;
unichar unicode3_min_used_modif_char = 0xFFFF, unicode3_max_used_modif_char = 0;
unichar unicode3_min_exact_clone_char = 0xFFFF, unicode3_max_exact_clone_char = 0;

unichar unicode3_combine_base_and_modif (unichar base, unichar modif)
{
  uptrlong boundaries = (uptrlong) gethash ((void *)((ptrlong)modif), unicode3_modif_usages);
  if (boundaries && (base >= (boundaries >> 16)) && (base <= (boundaries & 0xFFFF)))
    {
      uptrlong mix = (base << 16) | modif;
      uptrlong combined = (uptrlong) gethash ((void *)mix, unicode3_charmodif_to_combined);
      return combined;
    }
  return 0;
}

unichar unicode3_combine_base_and_modif_upper (unichar base, unichar modif)
{
  uptrlong boundaries = (uptrlong) gethash ((void *)((ptrlong)modif), unicode3_modif_usages);
  if (boundaries && (base >= (boundaries >> 16)) && (base <= (boundaries & 0xFFFF)))
    {
      uptrlong mix = (base << 16) | modif;
      uptrlong combined_upper = (uptrlong) gethash ((void *)mix, unicode3_charmodif_to_combined_upper);
      return combined_upper;
    }
  return 0;
}

void unicode3_init_char_combining_hashtables (void)
{
  int cellctr;
  int cellcount = (int)(sizeof(unicode3_tobasechars)/sizeof(unicode3_tobasechars[0])) - 1;
  if (NULL != unicode3_modif_usages)
    return;
  unicode3_modif_usages = hash_table_allocate (509);
  unicode3_charmodif_to_combined = hash_table_allocate (1531);
  unicode3_charmodif_to_combined_upper = hash_table_allocate (1531);
  for (cellctr = 0; cellctr - cellcount; cellctr++)
    {
      unicode3_tobasechar_t *rec = unicode3_tobasechars + cellctr;
      uptrlong cell = rec->u3c_cell;
      unichar modif = rec->u3c_modifier;
      uptrlong mix, old_cell_for_mix, boundaries, boundaries_min, boundaries_max;
      rec->u3c_upperbasechar = unicode3_getucase (rec->u3c_basechar);
      if (0 == modif)
        {
          if (cell < unicode3_min_exact_clone_char)
            unicode3_min_exact_clone_char = cell;
          if (cell > unicode3_max_exact_clone_char)
            unicode3_max_exact_clone_char = cell;
          continue;
        }
      if (modif < unicode3_min_used_modif_char)
        unicode3_min_used_modif_char = modif;
      if (modif > unicode3_max_used_modif_char)
        unicode3_max_used_modif_char = modif;
      mix = (rec->u3c_basechar << 16) | modif;
      old_cell_for_mix = (uptrlong) gethash ((void *)mix, unicode3_charmodif_to_combined);
      if (old_cell_for_mix)
        {
#ifndef NDEBUG
	  GPF_T;
#endif
	  continue;
        }
      sethash ((void *)mix, unicode3_charmodif_to_combined, (void *)cell);
      sethash ((void *)mix, unicode3_charmodif_to_combined_upper, (void *)(ptrlong)(unicode3_getucase (cell)));
      boundaries = (uptrlong) gethash ((void *)((ptrlong)modif), unicode3_modif_usages);
      if (!boundaries)
        {
	  boundaries_min = boundaries_max = rec->u3c_basechar;
        }
      else
        {
	  boundaries_min = boundaries >> 16;
          boundaries_max = boundaries & 0xFFFF;
          if (rec->u3c_basechar < boundaries_min)
            boundaries_min = rec->u3c_basechar;
          if (rec->u3c_basechar > boundaries_max)
            boundaries_max = rec->u3c_basechar;
        }
      sethash ((void *)((ptrlong)(modif)), unicode3_modif_usages, ((void*)((boundaries_min << 16) | boundaries_max)));
    }
}

/* Check for being a whitespace */

#define UNICODE3_HEADER unichar unicode3_spaces[] = {
#define UNICODE3_FOOTER ~0 };
#define UNICODE3_REC(cell,grp1,idx1,grp2,digit1,digit2,digit3,ucase1,lcase,ucase2,flg1,repl1,name1,name2,unicodename) \
cell,
#include "unicode3_spaces.h"
#undef UNICODE3_HEADER
#undef UNICODE3_FOOTER
#undef UNICODE3_REC


int unicode3_isspace (unichar uchr)
{
  int left_cop = 0;
  int right_cop = (int)(sizeof(unicode3_spaces)/sizeof(unicode3_spaces[0])) - 1;
  int robber = 1;	/* We should optimize search for the most important case - ASCII whitespace */
  unichar curr;
  while (left_cop <= right_cop)
    {
      curr = unicode3_spaces[robber];
      if (uchr == curr)
	return 1;
      if (uchr < curr)
	right_cop = robber-1;
      else
	left_cop = robber+1;
      robber = (left_cop+right_cop)/2;
    }
  return 0;
}


/* Testing */


#ifdef LANGFUNC_TEST

struct unicode3_charinfo_s
{
  unsigned short int u3c_cell;
  unsigned short int u3c_ucase;
  unsigned short int u3c_lcase;
};

typedef struct unicode3_charinfo_s unicode3_charinfo_t;

#define UNICODE3_HEADER unicode3_charinfo_t unicode3_all_chars[] = {
#define UNICODE3_FOOTER {~0} };
#define UNICODE3_REC(cell,grp1,idx1,grp2,digit1,digit2,digit3,ucase1,lcase,ucase2,flg1,repl1,name1,name2,unicodename) \
{cell,ucase1,lcase},
#include "unicode3_all_chars.h"
#undef UNICODE3_HEADER
#undef UNICODE3_FOOTER
#undef UNICODE3_REC

#endif


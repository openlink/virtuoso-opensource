/*
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
#include "langfunc.h"


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


/* Conversion to lowercase */

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


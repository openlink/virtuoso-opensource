/*
 *  xml_ecm_test.c
 *
 *  $Id$
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
 */

#include "xml_ecm.h"

extern unsigned char ecm_utf8props[0x100];


void test1(void)
{
  int ctr;
  printf ("Begin:[");
  for (ctr=0;ctr<0x80;ctr++) if (ecm_utf8props[ctr] & 0x08) printf("%c",(char)(ctr));
  printf ("]\n");
  printf ("Name :[");
  for (ctr=0;ctr<0x80;ctr++) if (ecm_utf8props[ctr] & 0x04) printf("%c",(char)(ctr));
  printf ("]\n");
  printf ("Space:[");
  for (ctr=0;ctr<0x80;ctr++) if (ecm_utf8props[ctr] & 0x02) printf("(%x)",ctr);
  printf ("]\n");
}

void test2(void)
{
  char *qq = NULL;
  ptrlong ctr = 0;
  printf("\nnew a @ %d\n", ecm_add_name ("a", &qq, &ctr, 24));
  printf("\nnew c @ %d\n", ecm_add_name ("c", &qq, &ctr, 24));
  printf("\nnew b @ %d\n", ecm_add_name ("b", &qq, &ctr, 24));
  printf("\nold a @ %d\n", ecm_find_name ("a", qq, ctr, 24));
  printf("\nold c @ %d\n", ecm_find_name ("c", qq, ctr, 24));
  printf("\nold b @ %d\n", ecm_find_name ("b", qq, ctr, 24));
}

#ifdef DEBUG
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
      char *name = "<BUG>";
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
  sprintf (numbuf, "%d", row);
  memcpy (tail, numbuf, strlen (numbuf));
  tail += 8; memcpy (tail, "| ", 2); tail += 2;
  for (col = 0; col < cols; col++)
    {
      sprintf (numbuf, "%d", dtd->ed_els[el_idx].ee_states[row].es_nexts[col]);
      memcpy (tail, numbuf, strlen (numbuf));
      tail += 6;
    }
  (tail++)[0] = '\n';
  row++;
  goto next_state;

no_more_states:
  return buf;
}

#endif /*DEBUG*/

void test3(void)
{
  ecm_dtd_t *dtd = dk_alloc_box_zero (sizeof (ecm_dtd_t), DV_CUSTOM);
  ecm_el_idx_t a_idx = ecm_add_name ("a", &(dtd->ed_els), &(dtd->ed_el_no), sizeof (ecm_el_t));
  ecm_el_idx_t c_idx = ecm_add_name ("c", &(dtd->ed_els), &(dtd->ed_el_no), sizeof (ecm_el_t));
  ecm_el_idx_t e_idx = ecm_add_name ("e", &(dtd->ed_els), &(dtd->ed_el_no), sizeof (ecm_el_t));
  ecm_el_idx_t d_idx = ecm_add_name ("d", &(dtd->ed_els), &(dtd->ed_el_no), sizeof (ecm_el_t));
  ecm_el_idx_t b_idx = ecm_add_name ("b", &(dtd->ed_els), &(dtd->ed_el_no), sizeof (ecm_el_t));

  ecm_el_t *a_item = &(dtd->ed_els[ecm_find_name ("a", dtd->ed_els, dtd->ed_el_no, sizeof (ecm_el_t))]);
  ecm_el_t *b_item = &(dtd->ed_els[ecm_find_name ("b", dtd->ed_els, dtd->ed_el_no, sizeof (ecm_el_t))]);
  ecm_el_t *c_item = &(dtd->ed_els[ecm_find_name ("c", dtd->ed_els, dtd->ed_el_no, sizeof (ecm_el_t))]);
  ecm_el_t *d_item = &(dtd->ed_els[ecm_find_name ("d", dtd->ed_els, dtd->ed_el_no, sizeof (ecm_el_t))]);
  ecm_el_t *e_item = &(dtd->ed_els[ecm_find_name ("e", dtd->ed_els, dtd->ed_el_no, sizeof (ecm_el_t))]);

  a_item->ee_grammar = box_dv_short_string(" ( ( a | b | c )* ) ");
  b_item->ee_grammar = box_dv_short_string(" ((((a|(b)?)*)*)+,a)+");
  c_item->ee_grammar = box_dv_short_string(" ( #PCDATA | c )* ");
  d_item->ee_grammar = box_dv_short_string(" ( ((a,b) | (a,c))+ ) ");
  e_item->ee_grammar = box_dv_short_string(" (((a,b) | (a,c))+, a, (c|d)) ");

  {
    ecm_el_idx_t ctr;
    for (ctr = 0; ctr < dtd->ed_el_no; ctr++)
      {
	printf ("\n\nFSM for children of %s, grammar %s:", dtd->ed_els[ctr].ee_name, dtd->ed_els[ctr].ee_grammar);
	ecm_grammar_to_fsa (ctr, dtd);
	printf ("\nConflict %d:\n%s", dtd->ed_els[ctr].ee_conflict, ecm_print_fsm (ctr, dtd));
      }
  }

  dk_free_box((caddr_t)dtd);
}

int main (int argc, const char *argv[])
{
  test1();
  test2();
  test3();
  exit(0);
}

/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *  
 *  Copyright (C) 1998-2007 OpenLink Software
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
 */

#include "sqlnode.h"
#include "sqlbif.h"
#include "arith.h"

void
rb_complete (rdf_box_t * rb, lock_trx_t * lt)
{
}


rdf_box_t *
rb_allocate ()
{
  rdf_box_t * rb= (rdf_box_t *) dk_alloc_box_zero (sizeof (rdf_box_t), DV_RDF);
  rb->rb_ref_count = 1;
  return rb;
}


#define RB_MAX_INLINED_CHARS 20

caddr_t
bif_rdf_box (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  /* data, type, lamg, ro_id, is_complete */
  rdf_box_t * rb = rb_allocate ();
  rb->rb_box = box_copy_tree (bif_arg (qst, args, 0, "rdf_box"));
  rb->rb_type = bif_long_arg (qst, args, 1, "rdf_box");
  rb->rb_lang = bif_long_arg (qst, args, 2, "rdf_box");
  rb->rb_ro_id = bif_long_arg (qst, args, 3, "rdf_box");
  if (rb->rb_ro_id)
    rb->rb_is_outlined = 1;
  rb->rb_is_complete = bif_long_arg (qst, args, 4, "rdf_box");
  return (caddr_t) rb;
}


caddr_t
bif_is_rdf_box (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t x = bif_arg (qst, args, 0, "is_rdf_box");
  if (DV_RDF == DV_TYPE_OF (x))
    return box_num (1);
  return 0;
}


rdf_box_t *
bif_rdf_box_arg (caddr_t * qst, state_slot_t ** args, int nth, const char *func)
{
  caddr_t arg = bif_arg (qst, args, nth, func);
  dtp_t dtp = DV_TYPE_OF (arg);
  if (dtp != DV_RDF)
    sqlr_new_error ("22023", "SR014",
  "Function %s needs an rdf box as argument %d, not an arg of type %s (%d)",
  func, nth + 1, dv_type_title (dtp), dtp);
  return (rdf_box_t*) arg;
}



caddr_t
bif_rdf_box_set_data (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  rdf_box_t * rb = bif_rdf_box_arg (qst, args, 0, "rdf_box_set_data");
  caddr_t data = bif_arg (qst, args, 1, "rdf_box_set_data");
  dk_free_tree (rb->rb_box);
  rb->rb_box = box_copy_tree (data);
  rb->rb_ref_count++;
  return (caddr_t) rb;
}


caddr_t
bif_rdf_box_data (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t rb = bif_arg (qst, args, 0, "rdf_box_data");
  if (DV_RDF == DV_TYPE_OF (rb))
    return box_copy_tree (((rdf_box_t *)rb)->rb_box);
  return box_copy_tree (rb);
}


caddr_t
bif_rdf_box_lang (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t rb = bif_arg (qst, args, 0, "rdf_box_lang");
  if (DV_RDF == DV_TYPE_OF (rb))
    return box_num (((rdf_box_t *)rb)->rb_lang);
  return 0;
}


caddr_t
bif_rdf_box_type (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t rb = bif_arg (qst, args, 0, "rdf_box_type");
  if (DV_RDF == DV_TYPE_OF (rb))
    return box_num (((rdf_box_t *)rb)->rb_type);
  return 0;
}


caddr_t
bif_rdf_box_is_complete (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t rb = bif_arg (qst, args, 0, "rdf_box_is_complete");
  if (DV_RDF == DV_TYPE_OF (rb))
    {
      rdf_box_t * rb2 = (rdf_box_t *) rb;
      return box_num (DV_STRINGP (rb2->rb_box) ? rb2->rb_is_complete : 1);
    }
  return box_num (1);
}


caddr_t
bif_rdf_box_ro_id (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t rb = bif_arg (qst, args, 0, "rdf_box_ro_id");
  if (DV_RDF == DV_TYPE_OF (rb))
    return box_num (((rdf_box_t*)rb)->rb_ro_id);
  return 0;
}


caddr_t
bif_rdf_box_set_ro_id (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  rdf_box_t * rb = bif_rdf_box_arg (qst, args, 0, "is_rdrf_box");
  rb->rb_ro_id = bif_long_arg (qst, args, 1, "rdf_box_set_ro_id");
  return 0;
}


#define RBS_OUTLINED 1
#define RBS_COMPLETE 2
#define RBS_HAS_LANG 4
#define RBS_HAS_TYPE 8


int 
rbs_length (db_buf_t rbs)
{
  long hl, l;
  dtp_t flags = rbs[1];
  db_buf_length (rbs + 2, &hl, &l);
  l += 2;
  if (flags & RBS_OUTLINED)
    l += 4;
  if (flags & (RBS_HAS_TYPE | RBS_HAS_LANG))
    l += 2;
  return hl + l;
}


static void
print_short (short s, dk_session_t * ses)
{
  session_buffered_write_char (s >> 8, ses);
  session_buffered_write_char (s & 0xff, ses);
}

static short 
read_short (dk_session_t * ses)
{
  short s = ((short) (dtp_t)session_buffered_read_char (ses)) << 8;
  s |= (dtp_t) session_buffered_read_char (ses);
  return s;
}


void
rb_serialize (caddr_t x, dk_session_t * ses)
{
  /* dv_rdf, flags, data, ro_id, lang or type 
   * flags is or of 1. outlined 2. complete 4has lang 8 has type */
  rdf_box_t * rb = (rdf_box_t *) x;
  if (DKS_DB_DATA (ses))
    print_object (rb->rb_box, ses, NULL, NULL);
  else 

    {
      int str_len = DV_STRING == DV_TYPE_OF (rb->rb_box) ? box_length (rb->rb_box) - 1 : 0;
      int flags = 0;
      session_buffered_write_char (DV_RDF, ses);
      if (rb->rb_ro_id)
	flags |= RBS_OUTLINED;
      if (rb->rb_lang)
	flags |= RBS_HAS_LANG;
      if (rb->rb_type)
	flags |= RBS_HAS_TYPE;
      if (rb->rb_is_complete && str_len <= RB_MAX_INLINED_CHARS)
	flags |= RBS_COMPLETE;
      session_buffered_write_char (flags, ses);
      if (DV_STRING == DV_TYPE_OF (rb->rb_box))
	{
	  if (str_len > RB_MAX_INLINED_CHARS)
	    str_len = RB_MAX_INLINED_CHARS;
	  session_buffered_write_char (DV_SHORT_STRING_SERIAL, ses);
	  session_buffered_write_char (str_len, ses);
	  session_buffered_write (ses, rb->rb_box, str_len);
	}
      else 
	print_object (rb->rb_box, ses, NULL, NULL);
      if (rb->rb_ro_id)
	print_long (rb->rb_ro_id, ses);
      if (rb->rb_type)
	print_short  (rb->rb_type, ses);
      else if (rb->rb_lang)
	print_short (rb->rb_lang, ses);
    }
}


caddr_t
rb_deserialize (dk_session_t * ses)
{
  rdf_box_t * rb = rb_allocate ();
  dtp_t flags = session_buffered_read_char (ses);
  rb->rb_box = scan_session_boxing (ses);
  if (flags & RBS_OUTLINED)
    rb->rb_ro_id = read_long (ses);
  if (flags & RBS_COMPLETE)
    rb->rb_is_complete = 1;
  if (flags & RBS_HAS_LANG)
    rb->rb_lang = read_short (ses);
  else if (flags & RBS_HAS_TYPE)
    rb->rb_type = read_short  (ses);
  return (caddr_t) rb;
}



int
rb_free (rdf_box_t * rb)
{
  rb->rb_ref_count--;
  if (rb->rb_ref_count)
    return 1;
  dk_free_tree (rb->rb_box);
  return 0;
}

void
rb_copy (rdf_box_t * rb)
{
  rb->rb_ref_count++;
}

int
dv_rdf_compare (db_buf_t dv1, db_buf_t dv2)
{
  /* this is dv_compare  where one or both arguments are dv_rdf 
   * The collation is perverse: If one is not a string, collate as per dv_compare of the data.
   * if both are strings and one is not an rdf box, treat the one that is not a box as an rdf string of max inlined chars and no lang orr type. */
  int len1, len2, inx;
  dtp_t dtp1 = dv1[0], dtp2 = dv2[0];
  short lang1, lang2;
  dtp_t data_dtp1, data_dtp2;
  db_buf_t data1 = NULL, data2 = NULL;
  /* arrange so that if both are not rdf boxes, trhe one that is a box is first */
  if (DV_RDF != dtp1)
    {
      int res = dv_rdf_compare (dv2, dv1);
      return res == DVC_MATCH ? res : (res == DVC_GREATER ? DVC_LESS : DVC_GREATER);
    }
  else
    {
      data1 = dv1 + 2;
      data_dtp1 = data1[0];
    }
  if (DV_RDF == dtp2)
    {
      data2 = dv2 + 2;
      data_dtp2 = data2[0];
    }
  /* if stringg and non-string */
  if (DV_SHORT_STRING_SERIAL != data_dtp1)
    {
      return dv_compare (data1, dv2, NULL);
    }
  
  if (DV_RDF != dtp2)
    {
      /* rdf string and noon rdf */
      if (DV_STRING == dtp2 || DV_SHORT_STRING_SERIAL == dtp2)
	{
	  /* rdf string and dv string */
	  data2 = dv2;
	  data_dtp2 = dtp2;
	  if (DV_SHORT_STRING_SERIAL == data_dtp2)
	    {
	      len2 = data2[1];
	      data2 += 2;
	    }
	  else
	    {
	      len2 = RB_MAX_INLINED_CHARS;
	      data2 += 5;
	    }
	  lang2 = 0;
	  goto cmp_strings;
	}
      else
	return dv_compare (data1, dv2, NULL);
    }
  else 
    {
      if (DV_SHORT_STRING_SERIAL != data_dtp2)
	return dv_compare (data1, data2, NULL);
      len2 = data2[1];
      data2 += 2;
    }
 cmp_strings:
  /*dv1 is an rdf string. data2 is the text to compare with, len2 is the length. If leading matches, then get the ids and tyags from dv2 */
  len1 = data1[1];
  data1 += 2;
  inx = 0;
  for (;;)
    {
      if (inx == len1)
	{
	  if (len2 == len1)
	    goto strings_eq;
	  return DVC_LESS;
	}
      if (inx == len2)
	return DVC_GREATER;
      if (data1[inx] < data2[inx])
	return DVC_LESS;
      if (data1[inx] > data2[inx])
	return DVC_GREATER;
      inx++;
    }
 strings_eq:
  /* the leading chars are eq. If both are complete, then eq.  If one is complete, the complete one is shorter, hence less. 
   * if neither is complete, the order is given by the ro_id */
  if (DV_RDF == dtp2)
    {
      if ((RBS_COMPLETE &  dv1[1]) && (RBS_COMPLETE & dv2[1]))
	{
	  /* equal. Let lng tag and type decide. */
	  if ((RBS_HAS_LANG & dv1[1]) && (RBS_HAS_LANG & dv2[1]))
	    {
	      /* both have language.  Language id decides. */
	      lang1 = SHORT_REF_NA (dv1 + 2 + ((RBS_OUTLINED & dv1[1]) ? 4 : 0) + len1);
	      lang2 = SHORT_REF_NA (dv2 + 2 + ((RBS_OUTLINED & dv2[1]) ? 4 : 0) + len1);
	      if (lang1 == lang2)
		return DVC_MATCH;
	      else if (lang1 < lang2)
		return DVC_LESS;
	      else 
		return DVC_GREATER;
	    }
	  else if ((RBS_HAS_LANG & dv1[1]))
	    return DVC_GREATER; /* str with  lang is after str without */
	  else if ((RBS_HAS_LANG & dv2[1]))
	    return DVC_LESS;
	  /* neither has lang, type decides. */
	  if ((RBS_HAS_TYPE & dv1[1]) && (RBS_HAS_TYPE & dv2[1]))
	    {
	      short type1 = SHORT_REF_NA (dv1 + len1 + 2 + ((RBS_OUTLINED & dv1[1]) ? 4 : 0));
	      short type2 = SHORT_REF_NA (dv2 + len2 + 2 + ((RBS_OUTLINED & dv2[1]) ? 4 : 0));
	      return (type1 < type2) ? DVC_LESS : type1 == type2 ? DVC_MATCH : DVC_GREATER;
	    }
	  else if ((RBS_HAS_TYPE & dv1[1]))
	    return DVC_GREATER;
	  else if ((RBS_HAS_TYPE & dv2[1]))
	    return DVC_LESS;
	  else 
	    return DVC_MATCH;
	}
      else if ((RBS_COMPLETE & dv1[1]))
	return DVC_LESS; /* first iis complete, hence shirter */
      else if ((RBS_COMPLETE & dv2[1]))
	return DVC_GREATER;
      else 
	{
	  /* neither is complete. Let the ro_id decide */
	  uint32 ro1 = LONG_REF_NA (dv1 + 4 + RB_MAX_INLINED_CHARS);
	  uint32 ro2 = LONG_REF_NA (dv2 + 4 + RB_MAX_INLINED_CHARS);
	  if (ro1 == ro2)
	    return DVC_MATCH;
	  else if (ro1 < ro2)
	    return DVC_LESS;
	  else 
	    return DVC_GREATER;
	}
    }
  /* the first is a rdf string and the second a sql one.  First max inlined chars are eq.
   * If the rdf string is complete, ity is eq if no language.  */
  if ((RBS_COMPLETE & dv1[1]))
    {
      if ((RBS_HAS_LANG & dv1[1]) || (RBS_HAS_TYPE & dv1[1]))
	return DVC_GREATER;
      return DVC_MATCH;
    }
  return DVC_GREATER;
}


int
rdf_box_compare (caddr_t a1, caddr_t a2)
{
  /* this is cmp_boxes  where one or both arguments are dv_rdf 
   * The collation is perverse: If one is not a string, collate as per dv_compare of the data.
   * if both are strings and one is not an rdf box, treat the one that is not a box as an rdf string of max inlined chars and no lang orr type. */
  rdf_box_t * rb1 = (rdf_box_t *) a1;
  rdf_box_t * rb2 = (rdf_box_t *) a2;
  int len1, len2, inx;
  dtp_t dtp1 = DV_TYPE_OF (rb1), dtp2 = DV_TYPE_OF (rb2);
  short lang1, lang2;
  dtp_t data_dtp1, data_dtp2;
  caddr_t data1 = NULL, data2 = NULL;
  /* arrange so that if both are not rdf boxes, trhe one that is a box is first */
  if (DV_RDF != dtp1)
    {
      int res = rdf_box_compare (a2, a1);
      return res == DVC_MATCH ? res : (res == DVC_GREATER ? DVC_LESS : DVC_GREATER);
    }
  else
    {
      data1 = rb1->rb_box;
      data_dtp1 = DV_TYPE_OF (data1);
    }
  if (DV_RDF == dtp2)
    {
      data2 = rb2->rb_box;
      data_dtp2 = DV_TYPE_OF (data2);
    }
  /* if stringg and non-string */
  if (DV_STRING != data_dtp1)
    {
      return cmp_boxes (data1, a2, NULL, NULL);
    }
  
  if (DV_RDF != dtp2)
    {
      /* rdf string and noon rdf */
      if (DV_STRING == dtp2)
	{
	  /* rdf string and dv string */
	  data2 = a2;
	  data_dtp2 = dtp2;
	  len2 = MIN (RB_MAX_INLINED_CHARS, box_length (rb2) - 1);
	  lang2 = 0;
	  goto cmp_strings;
	}
      else
	return cmp_boxes (data1, a2, NULL, NULL);
    }
  else 
    {
      if (DV_STRING != data_dtp2)
	return cmp_boxes (data1, data2, NULL, NULL);
      len2 = box_length (rb2->rb_box) - 1;
      data2 = rb2->rb_box;
    }
 cmp_strings:
  /*dv1 is an rdf string. data2 is the text to compare with, len2 is the length. If leading matches, then get the ids and tyags from dv2 */
  len1 = box_length (data1) - 1;;
  data1 = rb1->rb_box;
  inx = 0;
  for (;;)
    {
      if (inx == len1)
	{
	  if (len2 == len1)
	    goto strings_eq;
	  return DVC_LESS;
	}
      if (inx == len2)
	return DVC_GREATER;
      if (data1[inx] < data2[inx])
	return DVC_LESS;
      if (data1[inx] > data2[inx])
	return DVC_GREATER;
      inx++;
    }
 strings_eq:
  /* the leading chars are eq. If both are complete, then eq.  If one is complete, the complete one is shorter, hence less. 
   * if neither is complete, the order is given by the ro_id */
  if (DV_RDF == dtp2)
    {
      if (rb1->rb_is_complete && rb2->rb_is_complete)
	{
	  /* equal. Let lng tag and type decide. */
	  if (rb1->rb_lang && rb2->rb_lang)
	    {
	      /* both have language.  Language id decides. */
	      lang1 = rb1->rb_lang;
	      lang2 = rb2->rb_lang;
	      if (lang1 == lang2)
		return DVC_MATCH;
	      else if (lang1 < lang2)
		return DVC_LESS;
	      else 
		return DVC_GREATER;
	    }
	  else if (rb1->rb_lang)
	    return DVC_GREATER; /* str with  lang is after str without */
	  else if (rb2->rb_lang)
	    return DVC_LESS;
	  /* neither has lang, type decides. */
	  if (rb1->rb_type && rb2->rb_type)
	    {
	      short type1 = rb1->rb_type;
	      short type2 = rb2->rb_type;
	      return (type1 < type2) ? DVC_LESS : type1 == type2 ? DVC_MATCH : DVC_GREATER;
	    }
	  else if (rb1->rb_type)
	    return DVC_GREATER;
	  else if (rb2->rb_type)
	    return DVC_LESS;
	  else 
	    return DVC_MATCH;
	}
      else if (rb1->rb_is_complete)
	return DVC_LESS; /* first iis complete, hence shirter */
      else if (rb2->rb_is_complete)
	return DVC_GREATER;
      else 
	{
	  /* neither is complete. Let the ro_id decide */
	  uint32 ro1 = (uint32) rb1->rb_ro_id;
	  uint32 ro2 = (uint32) rb2->rb_ro_id;
	  if (ro1 == ro2)
	    return DVC_MATCH;
	  else if (ro1 < ro2)
	    return DVC_LESS;
	  else 
	    return DVC_GREATER;
	}
    }
  /* the first is a rdf string and the second a sql one.  First max inlined chars are eq.
   * If the rdf string is complete, ity is eq if no language.  */
  if (rb1->rb_is_complete)
    {
      if (rb1->rb_lang || rb1->rb_type)
	return DVC_GREATER;
      return DVC_MATCH;
    }
  return DVC_GREATER;
}


void
rdf_box_init ()
{
  dk_mem_hooks (DV_RDF, (box_copy_f) rb_copy, (box_destr_f)rb_free, 0);
  PrpcSetWriter (DV_RDF, rb_serialize);
  get_readtable ()[DV_RDF] = (macro_char_func) rb_deserialize;
  bif_define ("rdf_box", bif_rdf_box);
  bif_define_typed ("is_rdf_box", bif_is_rdf_box, &bt_integer);
  bif_define_typed ("rdf_box_set_data", bif_rdf_box_set_data, &bt_any);
  bif_define ("rdf_box_data", bif_rdf_box_data);
  bif_define_typed ("rdf_box_ro_id", bif_rdf_box_ro_id, &bt_integer);
  bif_define ("rdf_box_set_ro_id", bif_rdf_box_set_ro_id);
  bif_define_typed ("rdf_box_lang", bif_rdf_box_lang, &bt_integer);
  bif_define_typed ("rdf_box_type", bif_rdf_box_type, &bt_integer);
  bif_define_typed ("rdf_box_is_complete", bif_rdf_box_is_complete, &bt_integer);
}


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
rb_allocate (void)
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
  rdf_box_t * rb;
  caddr_t box;
  long type, lang, ro_id, is_complete;
  box = bif_arg (qst, args, 0, "rdf_box");
  type = bif_long_arg (qst, args, 1, "rdf_box");
  lang = bif_long_arg (qst, args, 2, "rdf_box");
  ro_id = bif_long_arg (qst, args, 3, "rdf_box");
  is_complete = bif_long_arg (qst, args, 4, "rdf_box");
  /*if (DV_STRING != DV_TYPE_OF (box))
    sqlr_new_error ("22023", "SR546", "Invalid type of argument 1 of rdf_box()");*/
  if ((RDF_BOX_DEFAULT_TYPE > type) || (type & ~0xffff))
    sqlr_new_error ("22023", "SR547", "Invalid datatype id %ld as argument 2 of rdf_box()", type);
  if ((RDF_BOX_DEFAULT_LANG > lang) || (lang & ~0xffff))
    sqlr_new_error ("22023", "SR548", "Invalid language id %ld as argument 3 of rdf_box()", lang);
  if ((RDF_BOX_DEFAULT_TYPE != type) && (RDF_BOX_DEFAULT_LANG != lang))
    sqlr_new_error ("22023", "SR549", "Both datatype id %ld and language id %ld are not default in call of rdf_box()", type, lang);
  if ((0 == ro_id) && !is_complete)
    sqlr_new_error ("22023", "SR550", "Neither is_complete nor ro_id argument is set in call of rdf_box()");
  if (is_complete && (0 == ro_id) && (RDF_BOX_DEFAULT_TYPE == type) && (RDF_BOX_DEFAULT_LANG == lang) &&
    (DV_STRING == DV_TYPE_OF (box)) && ((RB_MAX_INLINED_CHARS+1) >= box_length_inline (box)) )
    return box_copy (box);
  rb = rb_allocate ();
  rb->rb_box = box_copy_tree (box);
  rb->rb_type = type;
  rb->rb_lang = lang;
  rb->rb_ro_id = ro_id;
  if (rb->rb_ro_id)
    rb->rb_is_outlined = 1;
  rb->rb_is_complete = is_complete;
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
  rdf_box_t *rb = bif_rdf_box_arg (qst, args, 0, "rdf_box_set_data");
  caddr_t data = bif_arg (qst, args, 1, "rdf_box_set_data");
  caddr_t old_val = rb->rb_box;
  rb->rb_box = box_copy_tree (data);
  rb->rb_ref_count++;
  dk_free_tree (old_val);
  if (1 < BOX_ELEMENTS (args))
    {
      long is_complete = bif_long_arg (qst, args, 2, "rdf_box_set_data");
      if ((0 == rb->rb_ro_id) && !is_complete)
        sqlr_new_error ("22023", "SR551", "Zero is_complete argument and rdf box with ro_id in call of rdf_box_set_data ()");
      rb->rb_is_complete = (is_complete ? 1 : 0);
    }
  return (caddr_t) rb;
}


caddr_t
bif_rdf_box_data (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  rdf_box_t *rb = (rdf_box_t *)bif_arg (qst, args, 0, "rdf_box_data");
  if (DV_RDF != DV_TYPE_OF (rb))
  return box_copy_tree (rb);
  if (1 < BOX_ELEMENTS (args))
    {
      long should_be_complete = bif_long_arg (qst, args, 1, "rdf_box_data");
      if (should_be_complete && !(rb->rb_is_complete))
        sqlr_new_error ("22023", "SR545", "An incomplete RDF box '%.100s' is passed to rdf_box_data (..., %ld)", rb->rb_box, should_be_complete);
    }
  return box_copy_tree (rb->rb_box);
}


caddr_t
bif_rdf_box_data_tag (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  rdf_box_t *rb = (rdf_box_t *)bif_arg (qst, args, 0, "rdf_box_data_tag");
  dtp_t rb_dtp = DV_TYPE_OF (rb);
  if (DV_RDF != rb_dtp)
    return box_num (rb_dtp);
  return box_num (DV_TYPE_OF (rb->rb_box));
}


caddr_t
bif_rdf_box_lang (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t rb = bif_arg (qst, args, 0, "rdf_box_lang");
  if (DV_RDF == DV_TYPE_OF (rb))
    return box_num (((rdf_box_t *)rb)->rb_lang);
  return box_num (RDF_BOX_DEFAULT_LANG);
}


caddr_t
bif_rdf_box_type (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t rb = bif_arg (qst, args, 0, "rdf_box_type");
  if (DV_RDF == DV_TYPE_OF (rb))
    return box_num (((rdf_box_t *)rb)->rb_type);
  return box_num (RDF_BOX_DEFAULT_TYPE);
}

caddr_t
bif_rdf_box_set_type (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  rdf_box_t *rb = bif_rdf_box_arg (qst, args, 0, "rdf_box_set_type");
  long type = bif_long_arg (qst, args, 1, "rdf_box_set_type");
  if ((RDF_BOX_DEFAULT_TYPE > type) || (type & ~0xffff))
    sqlr_new_error ("22023", "SR554", "Invalid datatype id %ld as argument 2 of rdf_box_set_type()", type);
  if (0 != rb->rb_ro_id)
    sqlr_new_error ("22023", "SR555", "Datatype id can be changed only if rdf box has no ro_id in call of rdf_box_set_type ()");
  rb->rb_type = type;
  return box_num (type);
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

/*
caddr_t
bif_rdf_box_set_is_complete (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t rb = bif_arg (qst, args, 0, "rdf_box_set_is_complete");
  if (DV_RDF == DV_TYPE_OF (rb))
    {
      rdf_box_t * rb2 = (rdf_box_t *) rb;
      rb2->rb_is_complete = 1;
    }
  return box_num (1);
}
*/

caddr_t
bif_rdf_box_is_storeable (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t rb = bif_arg (qst, args, 0, "rdf_box_is_storeable");
  if (DV_RDF == DV_TYPE_OF (rb))
    {
      rdf_box_t * rb2 = (rdf_box_t *) rb;
      if ((!DV_STRINGP (rb2->rb_box)) || (0 != rb2->rb_ro_id) || (rb2->rb_is_complete && ((RB_MAX_INLINED_CHARS + 1) >= box_length (rb2->rb_box))))
        return box_num (1);
      return box_num (0);
    }
  return box_num (1);
}


caddr_t
bif_rdf_box_strcmp (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  rdf_box_t *rb1 = (rdf_box_t *)bif_arg (qst, args, 0, "rdf_box_strcmp");
  rdf_box_t *rb2 = (rdf_box_t *)bif_arg (qst, args, 1, "rdf_box_strcmp");
  if ((DV_RDF != DV_TYPE_OF (rb1)) || (DV_RDF != DV_TYPE_OF (rb2)) ||
    (!rb1->rb_is_complete) || (!rb2->rb_is_complete) ||
    (!DV_STRINGP (rb1->rb_box)) || (!DV_STRINGP (rb2->rb_box)) )
    return NEW_DB_NULL;
  return box_num (strcmp (rb1->rb_box, rb2->rb_box));
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
  long ro_id = bif_long_arg (qst, args, 1, "rdf_box_set_ro_id");
  if ((0 == ro_id) && !rb->rb_is_complete)
    sqlr_new_error ("22023", "SR551", "Zero ro_id argument and rdf box with incomplete data in call of rdf_box_set_ro_id ()");
  rb->rb_ro_id = ro_id;
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
      if (RDF_BOX_DEFAULT_LANG != rb->rb_lang)
	flags |= RBS_HAS_LANG;
      if (RDF_BOX_DEFAULT_TYPE != rb->rb_type)
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
      if (RDF_BOX_DEFAULT_TYPE != rb->rb_type)
	print_short  (rb->rb_type, ses);
      if (RDF_BOX_DEFAULT_LANG != rb->rb_lang)
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
  if (flags & RBS_HAS_TYPE)
    rb->rb_type = read_short (ses);
  else
    rb->rb_type = RDF_BOX_DEFAULT_TYPE;
  if (flags & RBS_HAS_LANG)
    rb->rb_lang = read_short (ses);
  else
    rb->rb_lang = RDF_BOX_DEFAULT_LANG;
  if ((RDF_BOX_DEFAULT_TYPE != rb->rb_type) && (RDF_BOX_DEFAULT_LANG != rb->rb_lang))
    sr_report_future_error (ses, "", "Both datatype id %d and language id %d are not default in DV_RDF value, can't deserialize");
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

caddr_t
rb_copy (rdf_box_t * rb)
{
  rb->rb_ref_count++;
  return (caddr_t)rb;
}

int
dv_rdf_compare (db_buf_t dv1, db_buf_t dv2)
{
  /* this is dv_compare  where one or both arguments are dv_rdf 
   * The collation is perverse: If one is not a string, collate as per dv_compare of the data.
   * if both are strings and one is not an rdf box, treat the one that is not a box as an rdf string of max inlined chars and no lang orr type. */
  int len1, len2, cmp_len;
  dtp_t dtp1 = dv1[0], dtp2 = dv2[0];
  short rdftype1, rdftype2, rdflang1, rdflang2;
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
	  rdftype2 = RDF_BOX_DEFAULT_TYPE;
	  rdflang2 = RDF_BOX_DEFAULT_LANG;
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
      rdftype2 = ((RBS_HAS_TYPE & dv2[1]) ? SHORT_REF_NA (data2 + len2 + ((RBS_OUTLINED & dv2[1]) ? 4 : 0)) : RDF_BOX_DEFAULT_TYPE);
      rdflang2 = ((RBS_HAS_LANG & dv2[1]) ? SHORT_REF_NA (data2 + len2 + ((RBS_OUTLINED & dv2[1]) ? 4 : 0)) : RDF_BOX_DEFAULT_LANG);
    }
  len1 = data1[1];
  data1 += 2;
  rdftype1 = ((RBS_HAS_TYPE & dv1[1]) ? SHORT_REF_NA (data1 + len1 + ((RBS_OUTLINED & dv1[1]) ? 4 : 0)) : RDF_BOX_DEFAULT_TYPE);
  if (rdftype1 < rdftype2) return DVC_LESS;
  if (rdftype1 > rdftype2) return DVC_GREATER;
  rdflang1 = ((RBS_HAS_LANG & dv1[1]) ? SHORT_REF_NA (data1 + len1 + ((RBS_OUTLINED & dv1[1]) ? 4 : 0)) : RDF_BOX_DEFAULT_LANG);
  if (rdflang1 < rdflang2) return DVC_LESS;
  if (rdflang1 > rdflang2) return DVC_GREATER;
  cmp_len = MIN (len1, len2);
	{
    int mcmp = memcmp (data1, data2, cmp_len);
    if (mcmp < 0)
	  return DVC_LESS;
    if (mcmp > 0)
	return DVC_GREATER;
    if ((RBS_COMPLETE & dv1[1]) && ((DV_RDF != dtp2) || (RBS_COMPLETE & dv2[1])))
      {
        if (len1 < len2)
	return DVC_LESS;
        if (len1 > len2)
	return DVC_GREATER;
    }
    else if (cmp_len < RB_MAX_INLINED_CHARS)
	{
        if ((len1 == cmp_len) && (len2 > cmp_len))
		return DVC_LESS;
        if ((len2 == cmp_len) && (len1 > cmp_len))
		return DVC_GREATER;
	    }
	    }
  if (DV_RDF == dtp2)
	{
	  /* neither is complete. Let the ro_id decide */
      uint32 ro1 = ((RBS_OUTLINED & dv1[1]) ? LONG_REF_NA (data1 + len1) : 0);
      uint32 ro2 = ((RBS_OUTLINED & dv2[1]) ? LONG_REF_NA (data2 + len2) : 0);
	  if (ro1 == ro2)
	    return DVC_MATCH;
	  else if (ro1 < ro2)
	    return DVC_LESS;
	  else 
	    return DVC_GREATER;
	}
  /* the first is a rdf string and the second a sql one.  First max inlined chars are eq.
   * If the rdf string is complete, ity is eq if no language.  */
  if ((RBS_COMPLETE & dv1[1]))
    {
      uint32 ro1;
      if ((RBS_HAS_LANG & dv1[1]) || (RBS_HAS_TYPE & dv1[1]))
	return DVC_GREATER;
      ro1 = ((RBS_OUTLINED & dv1[1]) ? LONG_REF_NA (data1 + len1) : 0);
      if (0 < ro1)
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
  rdf_box_t tmp_rb2;
  dtp_t dtp1 = DV_TYPE_OF (rb1), dtp2 = DV_TYPE_OF (rb2);
  dtp_t data_dtp1, data_dtp2;
  int len1, len2, cmp_len;
  caddr_t data1 = NULL, data2 = NULL;
  /* arrange so that if both are not rdf boxes, trhe one that is a box is first */
  if (DV_RDF != dtp1)
    {
      int res = rdf_box_compare (a2, a1);
      return res == DVC_MATCH ? res : (res == DVC_GREATER ? DVC_LESS : DVC_GREATER);
    }
  else
    {
      if ((DV_RDF == dtp2) && (0 != rb1->rb_ro_id) && (rb2->rb_ro_id == rb1->rb_ro_id))
        return DVC_MATCH;
      data1 = rb1->rb_box;
      data_dtp1 = DV_TYPE_OF (data1);
    }
  /* if stringg and non-string */
  if (DV_STRING != data_dtp1)
    {
      return cmp_boxes (data1, a2, NULL, NULL);
    }
  if (DV_RDF == dtp2)
	{
      data2 = rb2->rb_box;
      data_dtp2 = DV_TYPE_OF (data2);
    }
  else 
    {
      data2 = a2;
      data_dtp2 = DV_TYPE_OF (a2);
      dtp2 = DV_RDF;
      tmp_rb2.rb_box = a2;
      tmp_rb2.rb_is_complete = 1;
      tmp_rb2.rb_type = RDF_BOX_DEFAULT_TYPE;
      tmp_rb2.rb_lang = RDF_BOX_DEFAULT_LANG;
      tmp_rb2.rb_ro_id = 0;
      rb2 = &tmp_rb2;
    }
      if (DV_STRING != data_dtp2)
	return cmp_boxes (data1, data2, NULL, NULL);
    {
    short type1 = rb1->rb_type;
    short type2 = rb2->rb_type;
    if (type1 < type2) return DVC_LESS;
    if (type1 > type2) return DVC_GREATER;
  }
	{
    short lang1 = rb1->rb_lang;
    short lang2 = rb2->rb_lang;
    if (lang1 < lang2) return DVC_LESS;
    if (lang1 > lang2) return DVC_GREATER;
	}
  len1 = box_length (data1) - 1;;
  len2 = box_length (data2) - 1;
  cmp_len = MIN (len1, len2);
  {
    int cmp_headlen, mcmp;
    if (((0 == rb1->rb_is_complete) || (0 == rb2->rb_is_complete)) && (RB_MAX_INLINED_CHARS < cmp_len))
      cmp_headlen = RB_MAX_INLINED_CHARS;
    else
      cmp_headlen = cmp_len;
    mcmp = memcmp (data1, data2, cmp_headlen);
    if (mcmp < 0)
	return DVC_LESS;
    if (mcmp > 0)
	return DVC_GREATER;
      if (rb1->rb_is_complete && rb2->rb_is_complete)
	{
        if (len1 < len2)
		return DVC_LESS;
        if (len1 > len2)
		return DVC_GREATER;
        return DVC_MATCH;
	    }
    else if (cmp_headlen < RB_MAX_INLINED_CHARS)
	    {
        if ((len1 == cmp_headlen) && (len2 > cmp_headlen))
	    return DVC_LESS;
        if ((len2 == cmp_headlen) && (len1 > cmp_headlen))
	    return DVC_GREATER;
	}
    }
    {
    long ro_id1 = rb1->rb_ro_id;
    long ro_id2 = rb2->rb_ro_id;
    if (ro_id1 < ro_id2)
      return DVC_LESS;
    if (ro_id1 > ro_id2)
	return DVC_GREATER;
    }
  return DVC_MATCH;
}

int32
rdf_box_hash (caddr_t box)
{
  rdf_box_t *rb = (rdf_box_t *)box;
  if (rb->rb_is_complete)
    return rb->rb_lang * 17 + rb->rb_type * 13 + box_hash (rb->rb_box);
  if (0 != rb->rb_ro_id)
    return rb->rb_ro_id + (rb->rb_ro_id << 16);
  return rb->rb_lang * 17 + rb->rb_type * 13 + rb->rb_is_complete * 9 + box_hash (rb->rb_box);
}

int
rdf_box_hash_cmp (caddr_t a1, caddr_t a2)
{
  return (DVC_MATCH == rdf_box_compare (a1, a2)) ? 1 : 0;
}


void
rdf_box_init ()
{
  dk_mem_hooks (DV_RDF, (box_copy_f) rb_copy, (box_destr_f)rb_free, 0);
  PrpcSetWriter (DV_RDF, rb_serialize);
  get_readtable ()[DV_RDF] = (macro_char_func) rb_deserialize;
  dk_dtp_register_hash (DV_RDF, rdf_box_hash, rdf_box_hash_cmp);
  bif_define ("rdf_box", bif_rdf_box);
  bif_define_typed ("is_rdf_box", bif_is_rdf_box, &bt_integer);
  bif_define_typed ("rdf_box_set_data", bif_rdf_box_set_data, &bt_any);
  bif_define ("rdf_box_data", bif_rdf_box_data);
  bif_define_typed ("rdf_box_data_tag", bif_rdf_box_data_tag, &bt_integer);
  bif_define_typed ("rdf_box_ro_id", bif_rdf_box_ro_id, &bt_integer);
  bif_define ("rdf_box_set_ro_id", bif_rdf_box_set_ro_id);
  bif_define_typed ("rdf_box_lang", bif_rdf_box_lang, &bt_integer);
  bif_define_typed ("rdf_box_type", bif_rdf_box_type, &bt_integer);
  bif_define ("rdf_box_set_type", bif_rdf_box_type);
  bif_define_typed ("rdf_box_is_complete", bif_rdf_box_is_complete, &bt_integer);
  /*bif_define_typed ("rdf_box_set_is_complete", bif_rdf_box_set_is_complete, &bt_integer);*/
  bif_define_typed ("rdf_box_is_storeable", bif_rdf_box_is_storeable, &bt_integer);
  bif_define_typed ("rdf_box_strcmp", bif_rdf_box_strcmp, &bt_integer);
}

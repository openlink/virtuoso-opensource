/*
 *  search_in.c
 *
 *  $Id$
 *
 *  Search
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
#include "sqlfn.h"
#include "arith.h"
#include "multibyte.h"
#include "srvmultibyte.h"
#include "xmlnode.h"
#include "sqlbif.h"
#include "srvstat.h"




#define INTK_NN(offset, nth_param, lt, gt) \
  { \
    boxint n2; \
  dv2 = (db_buf_t) itc->itc_search_params[nth_param];	\
  n1 = LONG_REF (row + offset); \
  n2 = unbox_inline (((caddr_t)dv2));		\
  if (n1 < n2) goto lt; \
  if (n1 > n2) goto gt; \
  }


#define INT64K_NN(offset, nth_param, lt, gt) \
  { \
    boxint n1, n2; \
  dv2 = (db_buf_t) itc->itc_search_params[nth_param];	\
  n1 = INT64_REF (row + offset); \
  n2 = unbox_inline (((caddr_t)dv2));		\
  if (n1 < n2) goto lt; \
  if (n1 > n2) goto gt; \
}



#define VAR_POS(nth_var) \
  if (0 == nth_var) \
    { \
      if (!key_id) \
	off = itc->itc_insert_key->key_key_var_start; \
      else \
	{ \
	  itc->itc_row_key_id = key_id; \
	  ITC_REAL_ROW_KEY (itc); \
	  off = itc->itc_row_key->key_row_var_start; \
	} \
      n1 = SHORT_REF (row + itc->itc_insert_key->key_length_area) - off; \
    } \
  else \
    { \
      int len_area = itc->itc_insert_key->key_length_area; \
      off = SHORT_REF (row + len_area + 2 * (nth_var - 1)); \
      n1 = SHORT_REF (row + len_area + 2 * nth_var) - off; \
    } \


#define STRK_NN(nth_var, nth_param, lt, gt) \
{ \
  inx = 0; \
  VAR_POS (nth_var); \
  dv2 = (db_buf_t) itc->itc_search_params[nth_param]; \
  dv1 = row + off; \
  n2 = box_length_inline (dv2) - 1; \
  for (;;) \
    { \
      if (inx == n1) \
	{ \
	  if (inx == n2) \
	    break; \
	  else \
	    goto lt; \
	} \
      if (inx == n2) \
	goto gt; \
      if (dv1[inx]  < dv2[inx]) \
	goto lt; \
      if (dv1[inx] > dv2[inx]) \
	goto gt; \
      inx++; \
    } \
}



#define IRIK_NN(offset, nth_param, lt, gt) \
{ \
    iri_id_t i1, i2; \
    dv2 = (db_buf_t) itc->itc_search_params[nth_param];		\
  i1 = (iri_id_t) (uint32) LONG_REF (row + offset);	\
  i2 = unbox_iri_id (((caddr_t) dv2));				\
  if (i1 < i2) goto lt; \
  if (i1 > i2) goto gt; \
}


#define IRI64K_NN(offset, nth_param, lt, gt) \
{ \
    iri_id_t i1, i2; \
    dv2 = (db_buf_t) itc->itc_search_params[nth_param];		\
  i1 = (iri_id_t)  INT64_REF (row + offset);	\
  i2 = unbox_iri_id (((caddr_t) dv2));				\
  if (i1 < i2) goto lt; \
  if (i1 > i2) goto gt; \
}


#define ANYK_NN(nth_var, nth_param, lt, gt) \
{ \
  inx = 0; \
  VAR_POS (nth_var); \
  dv2 = (db_buf_t) itc->itc_search_params[nth_param]; \
  dv1 = row + off; \
  n1 = dv_compare (dv1, dv2, NULL); \
  if (DVC_LESS & n1) goto lt; \
  if (DVC_GREATER & n1) goto gt; \
}


#define CMPF_HEADER(name) \
int cmpf_##name (buffer_desc_t * buf, int pos, it_cursor_t * itc) \
{ \
  db_buf_t dv1, dv2;				\
  db_buf_t row; \
  int32 n1, n2, inx, off;		\
db_buf_t page = buf->bd_buffer; \
  key_id_t key_id = SHORT_REF (page + pos + IE_KEY_ID); \
  if (!key_id) \
    row = page + pos + IE_LP_FIRST_KEY; \
  else if (KI_LEFT_DUMMY == key_id)	\
    return DVC_LESS; \
  else \
    row = page + pos + IE_FIRST_KEY; \




#define CMPF_END \
  return DVC_MATCH; \
  lt: return DVC_LESS; \
  gt: return DVC_GREATER; \
}


CMPF_HEADER (intn)
INTK_NN (0, 0, lt, gt)
CMPF_END

CMPF_HEADER (intn_intn)
INTK_NN (0, 0, lt, gt)
INTK_NN (4, 1, lt, gt)
CMPF_END


CMPF_HEADER (intn_intn_intn)
INTK_NN (0, 0, lt, gt)
INTK_NN (4, 1, lt, gt)
INTK_NN (8, 2, lt, gt)
CMPF_END


CMPF_HEADER (intn_intn_intn_intn)
INTK_NN (0, 0, lt, gt)
INTK_NN (4, 1, lt, gt)
INTK_NN (8, 2, lt, gt)
INTK_NN (12, 3, lt, gt)
CMPF_END




CMPF_HEADER (strn)
STRK_NN (0, 0, lt, gt)
CMPF_END


CMPF_HEADER (strn_intn)
STRK_NN (0, 0, lt, gt)
INTK_NN (0, 1, lt, gt)
CMPF_END



CMPF_HEADER (strn_intn_lte)
STRK_NN (0, 0, lt, gt)
INTK_NN (0, 1, match, gt)
	 match:
CMPF_END



CMPF_HEADER (irin_irin_anyn_irin)
IRIK_NN (0, 0, lt, gt)
IRIK_NN (4, 1, lt, gt)
ANYK_NN (0, 2, lt, gt)
IRIK_NN (8, 3, lt, gt)
CMPF_END



CMPF_HEADER (irin_irin_anyn_irin_lte)
IRIK_NN (0, 0, lt, gt)
IRIK_NN (4, 1, lt, gt)
ANYK_NN (0, 2, lt, gt)
IRIK_NN (8, 3, match, gt)
match:
CMPF_END

CMPF_HEADER (irin_irin_anyn)
IRIK_NN (0, 0, lt, gt)
IRIK_NN (4, 1, lt, gt)
ANYK_NN (0, 2, lt, gt)
CMPF_END



CMPF_HEADER (irin_irin_irin_anyn)
IRIK_NN (0, 0, lt, gt)
IRIK_NN (4, 1, lt, gt)
IRIK_NN (8, 2, lt, gt)
ANYK_NN (0, 3, lt, gt)
CMPF_END


CMPF_HEADER (irin_irin_irin)
IRIK_NN (0, 0, lt, gt)
IRIK_NN (4, 1, lt, gt)
IRIK_NN (8, 2, lt, gt)
CMPF_END

CMPF_HEADER (irin_irin)
IRIK_NN (0, 0, lt, gt)
IRIK_NN (4, 1, lt, gt)
CMPF_END


CMPF_HEADER (irin)
IRIK_NN (0, 0, lt, gt)
CMPF_END




/* 64 bit versions of the above */

CMPF_HEADER (int64n)
INT64K_NN (0, 0, lt, gt)
CMPF_END

CMPF_HEADER (int64n_int64n)
INT64K_NN (0, 0, lt, gt)
INT64K_NN (8, 1, lt, gt)
CMPF_END


CMPF_HEADER (int64n_int64n_int64n)
INT64K_NN (0, 0, lt, gt)
INT64K_NN (8, 1, lt, gt)
INT64K_NN (16, 2, lt, gt)
CMPF_END


CMPF_HEADER (int64n_int64n_int64n_int64n)
INT64K_NN (0, 0, lt, gt)
INT64K_NN (8, 1, lt, gt)
INT64K_NN (16, 2, lt, gt)
INT64K_NN (24, 3, lt, gt)
CMPF_END



CMPF_HEADER (strn_int64n)
STRK_NN (0, 0, lt, gt)
INT64K_NN (0, 1, lt, gt)
CMPF_END



CMPF_HEADER (strn_int64n_lte)
STRK_NN (0, 0, lt, gt)
INT64K_NN (0, 1, match, gt)
	 match:
CMPF_END



CMPF_HEADER (iri64n_iri64n_anyn_iri64n)
IRI64K_NN (0, 0, lt, gt)
IRI64K_NN (8, 1, lt, gt)
ANYK_NN (0, 2, lt, gt)
IRI64K_NN (16, 3, lt, gt)
CMPF_END



CMPF_HEADER (iri64n_iri64n_anyn_iri64n_lte)
IRI64K_NN (0, 0, lt, gt)
IRI64K_NN (8, 1, lt, gt)
ANYK_NN (0, 2, lt, gt)
IRI64K_NN (16, 3, match, gt)
match:
CMPF_END

CMPF_HEADER (iri64n_iri64n_anyn)
IRI64K_NN (0, 0, lt, gt)
IRI64K_NN (8, 1, lt, gt)
ANYK_NN (0, 2, lt, gt)
CMPF_END



CMPF_HEADER (iri64n_iri64n_iri64n_anyn)
IRI64K_NN (0, 0, lt, gt)
IRI64K_NN (8, 1, lt, gt)
IRI64K_NN (16, 2, lt, gt)
ANYK_NN (0, 3, lt, gt)
CMPF_END


CMPF_HEADER (iri64n_iri64n_iri64n)
IRI64K_NN (0, 0, lt, gt)
IRI64K_NN (8, 1, lt, gt)
IRI64K_NN (16, 2, lt, gt)
CMPF_END

CMPF_HEADER (iri64n_iri64n)
IRI64K_NN (0, 0, lt, gt)
IRI64K_NN (8, 1, lt, gt)
CMPF_END


CMPF_HEADER (iri64n)
IRI64K_NN (0, 0, lt, gt)
CMPF_END




dk_set_t cfd_list = NULL;

#define NOMORE 99 /*sentinel value distinct from CMP_xx */




void 
ksp_cmp_func (key_spec_t * ksp)
{
  search_spec_t * sp = ksp->ksp_spec_array;
  int all_eq = 1;
  DO_SET (cmp_func_desc_t *, cfd, &cfd_list)
    {
      int pinx;
      search_spec_t * sps = sp;
      cmp_desc_t * desc = cfd->cfd_compares;
      for (pinx = 0; desc[pinx].cmd_min_op != NOMORE; pinx++)
	{
	  if (!sps || sps->sp_is_reverse || sps->sp_collation)
	    goto next_func;
	  if (CMP_EQ != sps->sp_min_op)
	    all_eq = 0;
	  if (desc[pinx].cmd_min_op != sps->sp_min_op 
	      || desc[pinx].cmd_max_op != sps->sp_max_op 
	      || desc[pinx].cmd_dtp != sps->sp_cl.cl_sqt.sqt_dtp 
	      || desc[pinx].cmd_non_null != sps->sp_cl.cl_sqt.sqt_non_null)
	    goto next_func;
	  sps = sps->sp_next;

	}
      if (!sps)
	{
	  ksp->ksp_key_cmp = cfd->cfd_func;
	  return;
	}
    next_func: ;
    }
  END_DO_SET();
  ksp->ksp_key_cmp = NULL;
}


void
sp_add_func (key_cmp_t f, cmp_desc_t c[])
{
  NEW_VARZ (cmp_func_desc_t, cfd);
  cfd->cfd_func = f;
  cfd->cfd_compares = c;
  dk_set_push (&cfd_list, (void*) cfd);
}


#define SPF(f) \
{ \
  key_cmp_t __f = (key_cmp_t) cmpf_##f; \
  static cmp_desc_t __a [] = {

#define SPF_END \
  ,{NOMORE, 0, 0, 0}};				\
  sp_add_func (__f, __a); }



void
search_inline_init ()
{
  static cmp_desc_t  intn_p[] = {{CMP_EQ, CMP_NONE, DV_LONG_INT, 1}, {NOMORE, 0, 0, 0}};
  static cmp_desc_t strn_p [] = {{CMP_EQ, CMP_NONE, DV_STRING, 1}, {NOMORE, 0, 0, 0}};
  /*return;*/
  sp_add_func (cmpf_intn, intn_p);
  sp_add_func (cmpf_strn, strn_p);
  SPF (irin_irin_anyn_irin)
    {CMP_EQ, CMP_NONE, DV_IRI_ID, 1},
    {CMP_EQ, CMP_NONE, DV_IRI_ID, 1},
    {CMP_EQ, CMP_NONE, DV_ANY, 1},
    {CMP_EQ, CMP_NONE, DV_IRI_ID, 1}
  SPF_END;
  SPF (irin_irin_anyn_irin_lte)
    {CMP_EQ, CMP_NONE, DV_IRI_ID, 1},
    {CMP_EQ, CMP_NONE, DV_IRI_ID, 1},
    {CMP_EQ, CMP_NONE, DV_ANY, 1},
    {CMP_NONE, CMP_LTE, DV_IRI_ID, 1}
  SPF_END;

  SPF (irin)
    {CMP_EQ, CMP_NONE, DV_IRI_ID, 1}
  SPF_END;
  SPF (irin_irin)
    {CMP_EQ, CMP_NONE, DV_IRI_ID, 1},
    {CMP_EQ, CMP_NONE, DV_IRI_ID, 1}
  SPF_END;

  SPF (irin_irin_irin)
    {CMP_EQ, CMP_NONE, DV_IRI_ID, 1},
    {CMP_EQ, CMP_NONE, DV_IRI_ID, 1},
    {CMP_EQ, CMP_NONE, DV_IRI_ID, 1}
  SPF_END;
  SPF (irin_irin_irin_anyn)
    {CMP_EQ, CMP_NONE, DV_IRI_ID, 1},
    {CMP_EQ, CMP_NONE, DV_IRI_ID, 1},
  {CMP_EQ, CMP_NONE, DV_IRI_ID, 1},
    {CMP_EQ, CMP_NONE, DV_ANY, 1}
  SPF_END;

  SPF (irin_irin_anyn)
    {CMP_EQ, CMP_NONE, DV_IRI_ID, 1},
    {CMP_EQ, CMP_NONE, DV_IRI_ID, 1},
    {CMP_EQ, CMP_NONE, DV_ANY, 1}
  SPF_END;

  SPF (intn_intn)
    {CMP_EQ, CMP_NONE, DV_LONG_INT, 1},
    {CMP_EQ, CMP_NONE, DV_LONG_INT, 1}
  SPF_END;

  SPF (intn_intn_intn)
    {CMP_EQ, CMP_NONE, DV_LONG_INT, 1},
    {CMP_EQ, CMP_NONE, DV_LONG_INT, 1},
    {CMP_EQ, CMP_NONE, DV_LONG_INT, 1}
  SPF_END;

  SPF (intn_intn_intn_intn)
    {CMP_EQ, CMP_NONE, DV_LONG_INT, 1},
    {CMP_EQ, CMP_NONE, DV_LONG_INT, 1},
    {CMP_EQ, CMP_NONE, DV_LONG_INT, 1},
    {CMP_EQ, CMP_NONE, DV_LONG_INT, 1}
  SPF_END;

  SPF (strn_intn)
    {CMP_EQ, CMP_NONE, DV_STRING, 1},
    {CMP_EQ, CMP_NONE, DV_LONG_INT, 1}
  SPF_END;
  SPF (strn_intn_lte)
    {CMP_EQ, CMP_NONE, DV_STRING, 1},
    {CMP_NONE, CMP_LTE, DV_LONG_INT, 1}
  SPF_END;

/* 64 bit declarations */

  SPF (iri64n_iri64n_anyn_iri64n)
    {CMP_EQ, CMP_NONE, DV_IRI_ID_8, 1},
    {CMP_EQ, CMP_NONE, DV_IRI_ID_8, 1},
    {CMP_EQ, CMP_NONE, DV_ANY, 1},
    {CMP_EQ, CMP_NONE, DV_IRI_ID_8, 1}
  SPF_END;
  SPF (iri64n_iri64n_anyn_iri64n_lte)
    {CMP_EQ, CMP_NONE, DV_IRI_ID_8, 1},
    {CMP_EQ, CMP_NONE, DV_IRI_ID_8, 1},
    {CMP_EQ, CMP_NONE, DV_ANY, 1},
    {CMP_NONE, CMP_LTE, DV_IRI_ID_8, 1}
  SPF_END;

  SPF (iri64n)
    {CMP_EQ, CMP_NONE, DV_IRI_ID_8, 1}
  SPF_END;
  SPF (iri64n_iri64n)
    {CMP_EQ, CMP_NONE, DV_IRI_ID_8, 1},
    {CMP_EQ, CMP_NONE, DV_IRI_ID_8, 1}
  SPF_END;

  SPF (iri64n_iri64n_iri64n)
    {CMP_EQ, CMP_NONE, DV_IRI_ID_8, 1},
    {CMP_EQ, CMP_NONE, DV_IRI_ID_8, 1},
    {CMP_EQ, CMP_NONE, DV_IRI_ID_8, 1}
  SPF_END;
  SPF (iri64n_iri64n_iri64n_anyn)
    {CMP_EQ, CMP_NONE, DV_IRI_ID_8, 1},
    {CMP_EQ, CMP_NONE, DV_IRI_ID_8, 1},
  {CMP_EQ, CMP_NONE, DV_IRI_ID_8, 1},
    {CMP_EQ, CMP_NONE, DV_ANY, 1}
  SPF_END;

  SPF (iri64n_iri64n_anyn)
    {CMP_EQ, CMP_NONE, DV_IRI_ID_8, 1},
    {CMP_EQ, CMP_NONE, DV_IRI_ID_8, 1},
    {CMP_EQ, CMP_NONE, DV_ANY, 1}
  SPF_END;

  SPF (int64n)
    {CMP_EQ, CMP_NONE, DV_INT64, 1}
  SPF_END;


  SPF (int64n_int64n)
    {CMP_EQ, CMP_NONE, DV_INT64, 1},
    {CMP_EQ, CMP_NONE, DV_INT64, 1}
  SPF_END;

  SPF (int64n_int64n_int64n)
    {CMP_EQ, CMP_NONE, DV_INT64, 1},
    {CMP_EQ, CMP_NONE, DV_INT64, 1},
    {CMP_EQ, CMP_NONE, DV_INT64, 1}
  SPF_END;

  SPF (int64n_int64n_int64n_int64n)
    {CMP_EQ, CMP_NONE, DV_INT64, 1},
    {CMP_EQ, CMP_NONE, DV_INT64, 1},
    {CMP_EQ, CMP_NONE, DV_INT64, 1},
    {CMP_EQ, CMP_NONE, DV_INT64, 1}
  SPF_END;

  SPF (strn_int64n)
    {CMP_EQ, CMP_NONE, DV_STRING, 1},
    {CMP_EQ, CMP_NONE, DV_INT64, 1}
  SPF_END;
  SPF (strn_int64n_lte)
    {CMP_EQ, CMP_NONE, DV_STRING, 1},
    {CMP_NONE, CMP_LTE, DV_INT64, 1}
  SPF_END;


}

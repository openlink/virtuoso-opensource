/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2013 OpenLink Software
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

/* 2D Spatial  Index */

#include "sqlnode.h"
#include "sqlfn.h"
#include "lisprdr.h"
#include "date.h"
#include "datesupp.h"
#include "multibyte.h"
#include "srvmultibyte.h"
#include "bif_xper.h"		/* IvAn/DvBlobXper/001212 Include added */
#include "sqltype.h"
#include "xmltree.h"
#include "xml.h"
#include "arith.h"
#include "col.h"
#include "sqlbif.h"
#include "geo.h"
#include "math.h"


/* the key order is x,y,w,h,id.  The rd order is this: */
#define RD_X 3
#define RD_Y 2
#define RD_X2 1
#define RD_Y2 0
#define RD_ID 4

#define IS_OV(f) (NAN == (f) || -NAN == (f) || INFINITY == (f) || -INFINITY == (f))


double
unbox_coord (caddr_t x)
{
  dtp_t dtp = DV_TYPE_OF (x);
  if (DV_SINGLE_FLOAT == dtp)
    return (double) *(float *) x;
  else if (DV_DOUBLE_FLOAT == dtp)
    return *(double *) x;
  GPF_T1 ("in a geo rd, should have doubles or floats");
  return 0;
}


double
geo_distance (geo_srcode_t srcode, double x1, double y1, double x2, double y2)
{
  if (GEO_SR_SPHEROID_DEGREES (srcode))
    return haversine_deg_km (x1, y1, x2, y2);
  else
    {
      double xd = x1 - x2, yd = y1 - y2;
      return sqrt (xd * xd + yd * yd);
    }
}


#define ROW_DBL_COL(dbl, buf, row, cl) \
  if (DV_DOUBLE_FLOAT == cl.cl_sqt.sqt_dtp) \
{ dtp_t * xx = row + cl.cl_pos[0]; \
  EXT_TO_DOUBLE (dbl, xx); \
  } else { \
    float f; \
    dtp_t * xx = row + cl.cl_pos[0]; \
    EXT_TO_FLOAT (&f, xx); \
    *dbl = f; \
  }


int
cmpf_geo (buffer_desc_t * buf, int irow, it_cursor_t * itc)
{
  /* compare func for geo inx table with pk x,y,w,h for bounding boxes.  The 0 search param is a box geo.  Match if intersect, dvc less otherwise */
  db_buf_t row = BUF_ROW (buf, irow);
  row_ver_t rv = IE_ROW_VERSION (row);
  dbe_key_t *key = itc->itc_insert_key;
  double rx, rx2, ry, ry2;
  geo_t *g = (geo_t *) itc->itc_search_params[0];
  int gs_op, gs_precision;
  if (GEO_GSOP == g->geo_flags)
    {
      gs_op = itc->itc_geo_op;
      gs_precision = GSOP_PRECISION;
    }
  else
    {
      gs_op = GSOP_CONTAINS;
      gs_precision = 0;
    }
  if (rv)
    GPF_T1 ("a geo inx col is supposed to have 0 rv");
  ROW_DBL_COL (&rx, buf, row, key->key_key_fixed[RD_X]);
  ROW_DBL_COL (&rx2, buf, row, key->key_key_fixed[RD_X2]);
  if (rx2 < g->XYbox.Xmin || g->XYbox.Xmax < rx)
    return DVC_LESS;
  ROW_DBL_COL (&ry, buf, row, key->key_key_fixed[RD_Y]);
  ROW_DBL_COL (&ry2, buf, row, key->key_key_fixed[RD_Y2]);
  if (ry2 < g->XYbox.Ymin || g->XYbox.Ymax < ry)
    return DVC_LESS;
  if (GSOP_CONTAINS == gs_op)
    {
      rx *= ((0 < rx) ? (1 - geoc_EPSILON) : (1 + geoc_EPSILON));
      ry *= ((0 < ry) ? (1 - geoc_EPSILON) : (1 + geoc_EPSILON));
      rx2 *= ((0 < rx2) ? (1 + geoc_EPSILON) : (1 - geoc_EPSILON));
      ry2 *= ((0 < ry2) ? (1 + geoc_EPSILON) : (1 - geoc_EPSILON));
      /* if the row is smaller than the box, the row/leaf can't contain the whole item being searched */
      if (rx > g->XYbox.Xmin || rx2 < g->XYbox.Xmax)
	return DVC_LESS;
      if (ry > g->XYbox.Ymin || ry2 < g->XYbox.Ymax)
	return DVC_LESS;
    }
  if (GSOP_PRECISION == gs_precision)
    {
      /* if precision is given, param 1 is the geometry being searched and 2 is the precision.  If the geo is a point and prec a number, see the distance */
      geo_t *pt = (geo_t *) itc->itc_search_params[1];
      double prec = unbox_coord (itc->itc_search_params[2]);
      if (GEO_POINT == GEO_TYPE (pt->geo_flags) && (rx2 - rx) < (prec / 100) && (ry2 - ry) < (prec / 100)
        && prec < geo_distance (pt->geo_srcode, rx, ry, Xkey(pt), Ykey(pt)))
	return DVC_LESS;
    }
  return DVC_MATCH;
}


void
itc_geo_invalidate (it_cursor_t * itc)
{
  /* in case of geo split, registered cursors may skip over stuff.  Mark invalidated.
   * All of them, even though could be more fine grained */
  mutex_enter (geo_reg_mtx);
  DO_SET (it_cursor_t *, reg, &itc->itc_tree->it_geo_registered)
  {
    reg->itc_bp.bp_is_pos_valid = 0;
  }
  END_DO_SET ();
  mutex_leave (geo_reg_mtx);
}


/* 32 bit x86 gcc compiles rd_box_union wrong if doubles not volatile */
#if SIZEOF_LONG == 4
#define gcc_bug_volatile volatile
#else
#define gcc_bug_volatile
#endif

/* small number which when squared is still > 0 float. If an area would be 0 because of 0 extent in x or y, calculate areas with an epsilon width in the 0 difference coordinate so that smaller in the other coordinate registers as smaller and not all as 0 */
#define FLT_SQ_EPSILON 1e-10


#define MIN_F(result, org, new, flag) \
  if (new < org) { result = new; flag = 1;} else { result = org;}

#define MAX_F(result, org, new, flag) \
  if (new > org) { result = new; flag = 1;} else { result = org;}

#define NZ_AREA(a, x, x2, y, y2)			\
  a = MAX (x2 - x, FLT_SQ_EPSILON) * MAX (y2 - y, FLT_SQ_EPSILON)

void
rd_box_union (it_cursor_t * itc, buffer_desc_t * buf, db_buf_t row, int row_no, row_delta_t * rd, double *min_growth,
    double *min_area, double *mg_area, int *mg_row, int *ma_row)
{
  /* see how much the row would grow in area if rd were unioned with it.  Get the area after the intersect */
  dbe_key_t *key = itc->itc_insert_key;
  gcc_bug_volatile double a1, a2, rx, ry, rx2, ry2, dx, dx2, dy, dy2;
  gcc_bug_volatile double ix, iy, ix2, iy2;
  int x_changes = 0, y_changes = 0;
  ROW_DBL_COL (&rx, buf, row, key->key_key_fixed[RD_X]);
  ROW_DBL_COL (&ry, buf, row, key->key_key_fixed[RD_Y]);
  ROW_DBL_COL (&rx2, buf, row, key->key_key_fixed[RD_X2]);
  ROW_DBL_COL (&ry2, buf, row, key->key_key_fixed[RD_Y2]);
  NZ_AREA (a1, rx, rx2, ry, ry2);
  ix = unbox_coord (rd->rd_values[RD_X]);
  iy = unbox_coord (rd->rd_values[RD_Y]);
  ix2 = unbox_coord (rd->rd_values[RD_X2]);
  iy2 = unbox_coord (rd->rd_values[RD_Y2]);
  MIN_F (dx, rx, ix, x_changes);
  MAX_F (dx2, rx2, ix2, x_changes);
  MIN_F (dy, ry, iy, y_changes);
  MAX_F (dy2, ry2, iy2, y_changes);
#if 0
  if (dx < rx && !x_changes)
    GPF_T1 ("no change");
  if (dy < ry && !y_changes)
    GPF_T1 ("no change");
  if (dx2 > rx2 && !x_changes)
    GPF_T1 ("no change");
  if (dy2 > ry2 && !y_changes)
    GPF_T1 ("no change");
#endif
  if (x_changes || y_changes)
    {
      NZ_AREA (a2, dx, dx2, dy, dy2);
      if (-1 == *min_growth || a2 / a1 <= *min_growth)
	{
	  *mg_area = a2;
	  *mg_row = row_no;
	  *min_growth = a2 / a1;
	}
    }
  else if (-1 == *min_area || *min_area > a1)
    {
      *min_area = a1;
      *ma_row = row_no;
    }
}


buffer_desc_t *
page_geo_split (it_cursor_t * itc, buffer_desc_t * buf, int n_right, int *right,
    row_delta_t * ins, int ins_right, page_apply_frame_t * paf)
{
  row_lock_t **rlocks = paf->paf_rlocks;
  char first_affected = 0;
  row_size_t split_after = PAGE_SZ;
  page_map_t *org_pm = buf->bd_content_map;
  int nth_right = 0;
  page_fill_t pf;
  buffer_desc_t *right_buf = NULL;
  buffer_desc_t *t_buf = &paf->paf_buf;
  page_map_t *t_map = &paf->paf_map;
  dtp_t *t_page = paf->paf_page;
  int irow, inx;
  pg_check_map (buf);
  memset (&pf, 0, sizeof (pf));
  pf.pf_rls = &paf->paf_rlocks[0];
  pf.pf_itc = itc;
  pf.pf_op = PA_MODIFY;
  if (!LONG_REF (buf->bd_buffer + DP_PARENT))
    it_root_image_invalidate (buf->bd_tree);
  memset (t_buf, 0, sizeof (buffer_desc_t));
  memset (t_map, 0, PM_ENTRIES_OFFSET);
  BD_SET_IS_WRITE ((t_buf), 1);
  t_buf->bd_content_map = t_map;
  t_buf->bd_tree = buf->bd_tree;
  t_buf->bd_pl = buf->bd_pl;
  t_buf->bd_buffer = t_page;
  t_buf->bd_page = buf->bd_page;
  t_map->pm_filled_to = DP_DATA;
  t_map->pm_bytes_free = PAGE_DATA_SZ;
  t_map->pm_size = PM_MAX_ENTRIES;
  pf.pf_registered = &paf->paf_registered[0];
  pf.pf_org = buf;
  pf.pf_current = t_buf;
  pf_fill_registered (&pf, buf);
  {
    row_delta_t *rd = &paf->paf_rd;
    memset (rd, 0, sizeof (row_delta_t));
    rd->rd_temp = &paf->paf_rd_temp[0];
    rd->rd_temp_max = sizeof (paf->paf_rd_temp);
    rd->rd_values = paf->paf_rd_values;
    rd->rd_allocated = RD_AUTO;
    for (irow = 0; irow < org_pm->pm_count; irow++)
      {
	int is_first_right = 0;
	if (nth_right < n_right && irow == right[nth_right])
	  {
	    if (right_buf)
	      pf.pf_current = right_buf;
	    else
	      {
		split_after = 0;
		is_first_right = 1;
	      }
	    nth_right++;
	  }
	else
	  pf.pf_current = t_buf;
	page_row (buf, irow, rd, 0);
	rd->rd_keep_together_dp = buf->bd_page;
	rd->rd_keep_together_pos = irow;
	pf_rd_append (&pf, rd, &split_after);
	rd_free (rd);
	if (is_first_right)
	  right_buf = pf.pf_current;
      }
  }
  if (ins_right)
    pf.pf_current = right_buf;
  else
    pf.pf_current = t_buf;
  pf_rd_append (&pf, ins, &split_after);
  pf.pf_current = right_buf;
  page_reloc_right_leaves (pf.pf_itc, right_buf);
  /* next for cursors whose row was deld and had no row after it */
  for (inx = 0; inx < pf.pf_cr_fill; inx++)
    if (pf.pf_registered[inx] && ITC_DELETED == pf.pf_registered[inx]->itc_map_pos)
      pf.pf_registered[inx]->itc_map_pos = ITC_AT_END;


  pf_change_org (&pf);
  page_reg_past_end (pf.pf_org);
  for (inx = 0; inx < pf.pf_rl_fill; inx++)
    {
      if (pf.pf_rls[inx] != NULL)
	{
	  /* a rl cannot exist without belonging to a row, except if it belongs to a deleted row.  rls of deleted rows continue to exist as distinct until the wait queue is done so as to keep lock acquisition order.  Deviating from lock acquisition order makes fake deadlocks in cluster. */
	  if (ITC_AT_END != rlocks[inx]->rl_pos)
	    GPF_T1 ("unmoved non-deleted row lock");
	  PL_RL_ADD (buf->bd_pl, rlocks[inx], ITC_AT_END);
	  buf->bd_pl->pl_n_row_locks++;
	  log_info ("deleted rl kept around for page apply");
	}
    }
  if (pf.pf_left)
    {
      DO_SET (buffer_desc_t *, left2, &pf.pf_left->next)
      {
	itc_split_lock_waits (pf.pf_itc, buf, left2);
      }
      END_DO_SET ();
      itc_split_lock_waits (pf.pf_itc, buf, pf.pf_current);
    }
  if (t_buf->bd_registered)
    GPF_T1 ("registrations are not supposed to go to the temp buf");
  first_affected = 0;
  dk_set_free (pf.pf_left);
  itc_geo_invalidate (itc);
  return right_buf;
}

typedef struct bbox_s
{
  int inited;
  double x, y, x2, y2;
} bbox_t;

void
incbox (bbox_t * b, double x, double y, double x2, double y2)
{
  if (!b->inited)
    {
      b->x = x;
      b->y = y;
      b->x2 = x2;
      b->y2 = y2;
      b->inited = 1;
    }
  else
    {
      b->x = MIN (b->x, x);
      b->x2 = MAX (b->x2, x2);
      b->y = MIN (b->y, y);
      b->y2 = MAX (b->y2, y2);
    }
}


double
bbox_area (bbox_t * b)
{
  return (b->x2 - b->x) * (b->y2 - b->y);
}


double
bbox_aspect (bbox_t * b)
{
  double h = b->x2 - b->x;
  double w = b->y2 - b->y;
  if (0 == h || 0 == w)
    return 10000000;
  return h > w ? h / w : w / h;
}


void
itc_geo_write (it_cursor_t * itc, buffer_desc_t * buf, int irow, bbox_t * b)
{
  db_buf_t xx;
  db_buf_t row = BUF_ROW (buf, irow);
  dbe_key_t *key = itc->itc_insert_key;
  dtp_t dtp = key->key_key_fixed[RD_X].cl_sqt.sqt_dtp;
  row_ver_t rv = IE_ROW_VERSION (row);
  if (BUF_NEEDS_DELTA (buf))
    {
      ITC_IN_KNOWN_MAP (itc, itc->itc_page);
      itc_delta_this_buffer (itc, buf, DELTA_MAY_LEAVE);
      ITC_LEAVE_MAP_NC (itc);
    }

  if (DV_SINGLE_FLOAT == dtp)
    {
      float f;
      if (IS_OV (b->x) || IS_OV (b->y) || IS_OV (b->x2) || IS_OV (b->y2))
	GPF_T1 ("writing nan into geo inx");
      ROW_FIXED_COL (buf, row, rv, key->key_key_fixed[RD_X], xx);
      f = b->x;
      FLOAT_TO_EXT (xx, &f);
      ROW_FIXED_COL (buf, row, rv, key->key_key_fixed[RD_Y], xx);
      f = b->y;
      FLOAT_TO_EXT (xx, &f);
      ROW_FIXED_COL (buf, row, rv, key->key_key_fixed[RD_X2], xx);
      f = b->x2;
      FLOAT_TO_EXT (xx, &f);
      ROW_FIXED_COL (buf, row, rv, key->key_key_fixed[RD_Y2], xx);
      f = b->y2;
      FLOAT_TO_EXT (xx, &f);
    }
  else if (DV_DOUBLE_FLOAT == dtp)
    {
      ROW_FIXED_COL (buf, row, rv, key->key_key_fixed[RD_X], xx);
      DOUBLE_TO_EXT (xx, &b->x);
      ROW_FIXED_COL (buf, row, rv, key->key_key_fixed[RD_Y], xx);
      DOUBLE_TO_EXT (xx, &b->y);
      ROW_FIXED_COL (buf, row, rv, key->key_key_fixed[RD_X2], xx);
      DOUBLE_TO_EXT (xx, &b->x2);
      ROW_FIXED_COL (buf, row, rv, key->key_key_fixed[RD_Y2], xx);
      DOUBLE_TO_EXT (xx, &b->y2);
    }
  else
    GPF_T1 ("geo inx supposed to be doubles or floats");
}

void
itc_geo_row (it_cursor_t * itc, buffer_desc_t * buf, db_buf_t row, double *x, double *y, double *x2, double *y2)
{
  dbe_key_t *key = itc->itc_insert_key;
  row_ver_t rv = IE_ROW_VERSION (row);
  if (rv)
    GPF_T1 ("geo inx row is supposed to have 0 rv");
  ROW_DBL_COL (x, buf, row, key->key_key_fixed[RD_X]);
  ROW_DBL_COL (y, buf, row, key->key_key_fixed[RD_Y]);
  ROW_DBL_COL (x2, buf, row, key->key_key_fixed[RD_X2]);
  ROW_DBL_COL (y2, buf, row, key->key_key_fixed[RD_Y2]);
}


row_delta_t *
itc_geo_leaf (it_cursor_t * itc, bbox_t * box, dp_addr_t dp, int pos)
{
  dbe_key_t *key = itc->itc_insert_key;
  dtp_t dtp = key->key_key_fixed[RD_X].cl_sqt.sqt_dtp;
  dtp_t id_dtp = key->key_key_fixed[4].cl_sqt.sqt_dtp;
  NEW_VARZ (row_delta_t, rd);
  rd->rd_allocated = RD_ALLOCATED;
  rd->rd_key = itc->itc_insert_key;
  rd->rd_map_pos = pos;
  rd->rd_non_comp_len = DV_INT64 == id_dtp ? 14 : 10;
  rd->rd_values = (caddr_t *) dk_alloc_box (5 * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
  rd->rd_values[RD_ID] = 0;
  if (DV_SINGLE_FLOAT == dtp)
    {
      rd->rd_non_comp_len += 16;
      if (IS_OV (box->x) || IS_OV (box->y) || IS_OV (box->x2) || IS_OV (box->y2)) 
	GPF_T1 ("geo inx with nan or inf coord");
      rd->rd_values[RD_X] = box_float (box->x);
      rd->rd_values[RD_Y] = box_float (box->y);
      rd->rd_values[RD_X2] = box_float (box->x2);
      rd->rd_values[RD_Y2] = box_float (box->y2);
    }
  else
    {
      rd->rd_non_comp_len += 32;
      rd->rd_values[RD_X] = box_double (box->x);
      rd->rd_values[RD_Y] = box_double (box->y);
      rd->rd_values[RD_X2] = box_double (box->x2);
      rd->rd_values[RD_Y2] = box_double (box->y2);
    }
  rd->rd_leaf = dp;
  rd->rd_op = RD_INSERT;
  return rd;
}


void
itc_geo_check_link (it_cursor_t * itc, buffer_desc_t * buf, bbox_t * box)
{
  /* check that all rows here fit  within the bounding box for this node in parent node */
  DO_ROWS (buf, pos, row, NULL)
  {
    double rx, ry, rx2, ry2;
    if (KV_LEFT_DUMMY == IE_KEY_VERSION (row))
      continue;
    itc_geo_row (itc, buf, row, &rx, &ry, &rx2, &ry2);
    if (box->x > rx || box->y > ry || box->x2 < rx2 || box->y2 < ry2)
      GPF_T1 ("leaf has geo stuff  outside of leaf ptr bounding box");
  }
  END_DO_ROWS;
}


void
itc_geo_new_root (it_cursor_t * itc, buffer_desc_t * buf, bbox_t * lbox, bbox_t * rbox, buffer_desc_t * ext)
{
  row_delta_t *leaves[2];
  buffer_desc_t *root = it_new_page (itc->itc_tree, buf->bd_page, DPF_INDEX, 0, itc);
  leaves[0] = itc_geo_leaf (itc, lbox, buf->bd_page, 0);
  leaves[1] = itc_geo_leaf (itc, rbox, ext->bd_page, 1);
  it_root_image_invalidate (itc->itc_tree);
  ITC_IN_KNOWN_MAP (itc, root->bd_page);
  /* don't set it in the middle of the itc_reset sequence */
  itc->itc_tree->it_root = root->bd_page;
  rdbg_printf (("new root of %s L=%d \n", STR_OR (pf->pf_itc->itc_insert_key->key_name, "temp"), root->bd_page));
  ITC_LEAVE_MAP_NC (itc);
  itc->itc_page = root->bd_page;
  page_apply (itc, root, 2, leaves, 0);
  LONG_SET (buf->bd_buffer + DP_PARENT, root->bd_page);
  LONG_SET (ext->bd_buffer + DP_PARENT, root->bd_page);
  rdbg_printf (("Set parent of L=%d to new root L=%d\n", leaf->bd_page, root->bd_page));
  pg_check_map (leaf);
  page_leave_outside_map_chg (buf, RWG_WAIT_SPLIT);
  page_leave_outside_map_chg (ext, RWG_WAIT_SPLIT);
  rd_free (leaves[0]);
  rd_free (leaves[1]);
}


int
float_cmp (int n1, int n2, void *cd)
{
  float f1 = *(float *) &n1, f2 = *(float *) &n2;
  if (f1 == f2)
    return DVC_MATCH;
  return f1 > f2 ? DVC_GREATER : DVC_LESS;
}


int
float_ind_cmp (int n1, int n2, void *cd)
{
  float *fs = (float *) cd;
  float f1 = fs[n1], f2 = fs[n2];
  if (f1 == f2)
    return DVC_MATCH;
  return f1 > f2 ? DVC_GREATER : DVC_LESS;
}

#define PAGE_MAX_BOXES (PAGE_DATA_SZ / 22)	/* minimum 4 bytes of coords 4 of id and 2 of row header, no key comp */


float
coord_median (float *x, int fill)
{
  int left[PAGE_MAX_BOXES];
#if 1
  int inx;
  int inxes[PAGE_MAX_BOXES];
  for (inx = 0; inx < fill; inx++)
    inxes[inx] = inx;
  gen_qsort (inxes, left, fill, 0, float_ind_cmp, (void *) x);
  return x[inxes[fill / 2]];
#else
  gen_qsort ((int *) x, left, fill, 0, float_cmp, NULL);
  return x[fill / 2];
#endif
}

int
geo_uneven_split (int left_x, int left_y, int n, float *x_ratio, float *y_ratio)
{
  /* if more than 80% on one side with both x and y splits */
  *x_ratio = (float) left_x / (float) n;
  *y_ratio = (float) left_y / (float) n;
  return ((*x_ratio < 0.2 || *x_ratio > 0.8) && (*y_ratio < 0.2 || *y_ratio > 0.8));
}

long tc_geo_x_split;
long tc_geo_y_split;
long tc_geo_non_geo_split;


void
itc_geo_split (it_cursor_t * itc, buffer_desc_t * buf, row_delta_t * rd)
{
  page_apply_frame_t *paf;
  int n_left_by_x = 0, n_left_by_y = 0;
  int hold_taken = 0, fill, by_x = 0, rd_right, left_dummy_offset = 0;
  buffer_desc_t *ext, *parent;
  dp_addr_t parent_dp;
  int n_right = 0, ileaf;
  row_delta_t *leaf_rd;
  int right[PAGE_MAX_BOXES];
  float x_ratio, y_ratio;
  double x[PAGE_MAX_BOXES];
  double x2[PAGE_MAX_BOXES];
  double y[PAGE_MAX_BOXES];
  double y2[PAGE_MAX_BOXES];
  float center_x[PAGE_MAX_BOXES];
  float center_y[PAGE_MAX_BOXES];
  double cx = 0, cy = 0, cnx, cny;
  double ax, ay, asx, asy;
  bbox_t xbox_left, xbox_right, ybox_left, ybox_right;
  int inx = 0;
  /* decide best split.   Take x and y center of all rows and divide in two.  Write the leaf pointer to the new bounding box and add the other bounding box to parent.  If no space, recursively split.  If no parent make one.  About locks, keep them.  Insert will not block and is not unique checking so locks will not prevent insert. */
  xbox_left.inited = xbox_right.inited = ybox_left.inited = ybox_right.inited = 0;
  DO_ROWS (buf, pos, row, NULL)
  {
    key_ver_t kv = IE_KEY_VERSION (row);
    if (KV_LEFT_DUMMY == kv)
      {
	left_dummy_offset = 1;
	continue;
      }
    itc_geo_row (itc, buf, row, &x[inx], &y[inx], &x2[inx], &y2[inx]);
    center_x[inx] = (x[inx] + x2[inx]) / 2;
    center_y[inx] = (y[inx] + y2[inx]) / 2;
    inx++;
  }
  END_DO_ROWS;
  x[inx] = unbox_coord (rd->rd_values[RD_X]);
  y[inx] = unbox_coord (rd->rd_values[RD_Y]);
  x2[inx] = unbox_coord (rd->rd_values[RD_X2]);
  y2[inx] = unbox_coord (rd->rd_values[RD_Y2]);
  center_x[inx] = (x[inx] + x2[inx]) / 2;
  center_y[inx] = (y[inx] + y2[inx]) / 2;
  fill = inx + 1;
  cx = coord_median (center_x, fill);
  cy = coord_median (center_y, fill);
  for (inx = 0; inx < fill; inx++)
    {
      /* make the composite bounding box when splitting by middle x or middle y */
      cnx = (x[inx] + x2[inx]) / 2;
      cny = (y[inx] + y2[inx]) / 2;
      if (cnx < cx)
	{
	  incbox (&xbox_left, x[inx], y[inx], x2[inx], y2[inx]);
	  n_left_by_x++;
	}
      else
	incbox (&xbox_right, x[inx], y[inx], x2[inx], y2[inx]);
      if (cny < cy)
	{
	  incbox (&ybox_left, x[inx], y[inx], x2[inx], y2[inx]);
	  if (ybox_left.y2 < y2[inx])
	    GPF_T1 ("incbox bad");
	  n_left_by_y++;
	}
      else
	incbox (&ybox_right, x[inx], y[inx], x2[inx], y2[inx]);
    }
  /* could be all points are equal on one or both coordinates, all go to one side.  If so, split them in two regardless of geometry, get large overlap of page bounding boxes */
  if (geo_uneven_split (n_left_by_x, n_left_by_y, fill, &x_ratio, &y_ratio))
    {
      TC (tc_geo_non_geo_split);
      xbox_left.inited = xbox_right.inited = ybox_left.inited = ybox_right.inited = 0;
      for (inx = 0; inx < fill; inx++)
	{
	  if (inx < fill / 2)
	    incbox (&xbox_left, x[inx], y[inx], x2[inx], y2[inx]);
	  else
	    {
	      incbox (&xbox_right, x[inx], y[inx], x2[inx], y2[inx]);
	      right[n_right++] = inx;
	    }
	}
      rd_right = 1;
      by_x = 1;
    }
  else
    {
      if (x_ratio > 0.4 && x_ratio < 0.6 && y_ratio > 0.4 && y_ratio < 0.6)
	{
	  /* if both x and y split about even, and have within 2x the same area, take the more square.  If over 2x  difference in area, take the smaller area.
	   * if uneven split, take the direction with the more even split */
	  ax = bbox_area (&xbox_left) + bbox_area (&xbox_right);
	  ay = bbox_area (&ybox_left) + bbox_area (&ybox_right);
	  asx = bbox_aspect (&xbox_left) + bbox_aspect (&xbox_right);
	  asy = bbox_aspect (&ybox_left) + bbox_aspect (&ybox_right);
	  if (ay == 0)
	    by_x = 1;
	  else if (ax == 0)
	    by_x = 0;
	  else
	    {
	      float ar = ax / ay;
	      if (ar < 0.5 || ar > 2)
		by_x = ax < ay;
	      else
		by_x = asx < asy;
	    }
	}
      else if (fabs (0.5 - x_ratio) < fabs (0.5 - y_ratio))
	by_x = 1;
      else
	by_x = 0;
      for (inx = 0; inx < fill - 1; inx++)
	{
	  if (by_x)
	    {
	      cnx = (x[inx] + x2[inx]) / 2;
	      if (cnx >= cx)
		right[n_right++] = inx + left_dummy_offset;
	    }
	  else
	    {
	      cny = (y[inx] + y2[inx]) / 2;
	      if (cny >= cy)
		right[n_right++] = inx + left_dummy_offset;
	    }
	}
      if (by_x)
	rd_right = (x[fill - 1] + x2[fill - 1]) / 2 >= cx;
      else
	rd_right = (y[fill - 1] + y2[fill - 1]) / 2 >= cy;
      if (!by_x)
	{
	  xbox_left = ybox_left;
	  xbox_right = ybox_right;
	}
    }
  if (!itc->itc_n_pages_on_hold)
    {
      itc_hold_pages (itc, buf, DP_INSERT_RESERVE);
      hold_taken = 1;
    }
  paf = (page_apply_frame_t *) dk_alloc (sizeof (page_apply_frame_t));
  ext = page_geo_split (itc, buf, n_right, right, rd, rd_right, paf);
  dk_free ((caddr_t) paf, -1);
  parent_dp = LONG_REF (buf->bd_buffer + DP_PARENT);
  if (!parent_dp)
    {
      itc_geo_check_link (itc, buf, &xbox_left);
      itc_geo_check_link (itc, ext, &xbox_right);
      itc_geo_new_root (itc, buf, &xbox_left, &xbox_right, ext);
      if (hold_taken)
	itc_free_hold (itc);
      return;
    }

  parent = itc_write_parent (itc, buf);
  ileaf = page_find_leaf (parent, buf->bd_page);
  itc->itc_page = parent->bd_page;
  itc_geo_write (itc, parent, ileaf, &xbox_left);
  LONG_SET (ext->bd_buffer + DP_PARENT, itc->itc_page);
  page_leave_outside_map_chg (buf, RWG_WAIT_SPLIT);
  page_leave_outside_map_chg (ext, RWG_WAIT_SPLIT);
  leaf_rd = itc_geo_leaf (itc, &xbox_right, ext->bd_page, ileaf + 1);
  itc_geo_insert (itc, parent, leaf_rd);
  rd_free (leaf_rd);
  if (hold_taken)
    itc_free_hold (itc);

}


int
itc_geo_insert_lock (it_cursor_t * itc, buffer_desc_t * buf)
{
  page_lock_t *pl = itc->itc_pl;
  if (itc->itc_non_txn_insert)
    return NO_WAIT;
  if (!pl)
    return NO_WAIT;
  if (PL_IS_PAGE (pl))
    {
      return (lock_enter ((gen_lock_t *) pl, itc, buf));
    }
  return NO_WAIT;
}


void
itc_geo_insert (it_cursor_t * itc, buffer_desc_t * buf, row_delta_t * rd)
{
  buffer_desc_t *prev_buf;
  db_buf_t row;
  bbox_t lbox;
  for (;;)
    {
      double min_growth = -1, min_area = -1, mg_area = -1;
      int mg_row = -1, ma_row = -1, target;
      dp_addr_t target_dp;
      if (!rd->rd_leaf)
	{
	  DO_ROWS (buf, pos, row, NULL)
	  {
	    key_ver_t kv = IE_KEY_VERSION (row);
	    if (KV_LEFT_DUMMY == kv)
	      continue;
	    if (KV_LEAF_PTR == kv)
	      {
		rd_box_union (itc, buf, row, pos, rd, &min_growth, &min_area, &mg_area, &mg_row, &ma_row);
	      }
	  }
	  END_DO_ROWS;
	}
      if (-1 == mg_row && -1 == ma_row)
	{
	  /* leaf. insert here or split */
	  if (!rd->rd_leaf && NO_WAIT != itc_geo_insert_lock (itc, buf))
	    {
	      buf = itc_reset (itc);
	      continue;
	    }
	  if (BUF_NEEDS_DELTA (buf))
	    {
	      ITC_IN_KNOWN_MAP (itc, itc->itc_page);
	      itc_delta_this_buffer (itc, buf, DELTA_MAY_LEAVE);
	      ITC_LEAVE_MAP_NC (itc);
	    }
	  if (buf->bd_content_map->pm_bytes_free >= rd->rd_non_comp_len)
	    {
	      rd->rd_map_pos = buf->bd_content_map->pm_count;
	      page_apply (itc, buf, 1, &rd, PA_MODIFY);
	    }
	  else
	    {
	      itc_geo_split (itc, buf, rd);
	    }
	  return;
	}
      if (-1 != ma_row)
	target = ma_row;
      else
	{
	  bbox_t new_box;
	  float oa;
	  double tx, ty, tx2, ty2, ix, iy, ix2, iy2;
	  db_buf_t row;
	  target = mg_row;
	  row = BUF_ROW (buf, target);
	  itc_geo_row (itc, buf, row, &tx, &ty, &tx2, &ty2);
	  ix = unbox_coord (rd->rd_values[RD_X]);
	  iy = unbox_coord (rd->rd_values[RD_Y]);
	  ix2 = unbox_coord (rd->rd_values[RD_X2]);
	  iy2 = unbox_coord (rd->rd_values[RD_Y2]);
	  oa = (tx2 - tx) * (ty2 - ty);
	  tx = MIN (tx, ix);
	  ty = MIN (ty, iy);
	  tx2 = MAX (tx2, ix2);
	  ty2 = MAX (ty2, iy2);
	  new_box.x = tx;
	  new_box.y = ty;
	  new_box.x2 = tx2;
	  new_box.y2 = ty2;
	  /* printf ("enlarge %d for insert of %f, %f, old_area = %f, new %f\n", buf->bd_page, (float)ix, (float)iy, oa, (float)((tx2 - tx)* (ty2-ty))); */
	  itc_geo_write (itc, buf, target, &new_box);
	}
      row = BUF_ROW (buf, target);
      target_dp = leaf_pointer (row, itc->itc_insert_key);
      prev_buf = buf;
      itc_geo_row (itc, buf, row, &lbox.x, &lbox.y, &lbox.x2, &lbox.y2);
      itc_down_transit (itc, &buf, target_dp);
      if (itc->itc_to_reset < RWG_WAIT_DATA && target_dp == itc->itc_page)
	itc_geo_check_link (itc, buf, &lbox);
    }
}


void
itc_geo_register (it_cursor_t * itc)
{
  mutex_enter (geo_reg_mtx);
  dk_set_pushnew (&itc->itc_tree->it_geo_registered, (void *) itc);
  itc->itc_bp.bp_is_pos_valid = 1;
  itc->itc_is_geo_registered = 1;
  mutex_leave (geo_reg_mtx);
}


void
itc_geo_unregister (it_cursor_t * itc)
{
  mutex_enter (geo_reg_mtx);
  dk_set_delete (&itc->itc_tree->it_geo_registered, (void *) itc);
  itc->itc_bp.bp_is_pos_valid = 1;
  itc->itc_is_geo_registered = 0;
  mutex_leave (geo_reg_mtx);
}

extern long tc_geo_delete_retry, tc_geo_delete_missed;


void
itc_geo_delete (it_cursor_t * itc, buffer_desc_t * buf, boxint id)
{
  caddr_t id_box;
  int rc;
  search_spec_t sp;
  geo_t *g;
  memset (&sp, 0, sizeof (sp));
  sp.sp_cl = itc->itc_insert_key->key_key_fixed[4];
  sp.sp_min_op = CMP_EQ;
  sp.sp_min = 1;
  itc->itc_key_spec.ksp_key_cmp = cmpf_geo;
  itc->itc_row_specs = &sp;
  id_box = box_num (id);
  itc->itc_search_params[1] = id_box;
  ITC_OWNS_PARAM (itc, id_box);
  g = (geo_t *) itc->itc_search_params[0];
  itc_geo_register (itc);
again:
  itc->itc_landed = 1;
  itc->itc_search_mode = SM_READ;
  rc = itc_next (itc, &buf);
  if (DVC_MATCH == rc)
    {
      itc_set_lock_on_row (itc, &buf);
      if (itc->itc_is_on_row)
	{
	  itc_delete_this (itc, &buf, rc, 0);
	  itc_geo_unregister (itc);
	  itc_free (itc);
	  return;
	}
    }
  itc_page_leave (itc, buf);
  mutex_enter (geo_reg_mtx);
  if (!itc->itc_bp.bp_is_pos_valid)
    {
      mutex_leave (geo_reg_mtx);
      TC (tc_geo_delete_retry);
      itc->itc_search_mode = SM_INSERT;
      buf = itc_reset (itc);
      itc->itc_bp.bp_is_pos_valid = 1;
      goto again;
    }
  mutex_leave (geo_reg_mtx);
  TC (tc_geo_delete_missed);
  itc_geo_unregister (itc);
}


int
geo_matches_on_page (it_cursor_t * itc, buffer_desc_t * buf, dp_addr_t * leaf_ret, int *n_leaves, int max_ret)
{
  int n = 0;
  if (n_leaves)
    *n_leaves = 0;
  DO_ROWS (buf, pos, row, NULL)
  {
    if (DVC_MATCH == cmpf_geo (buf, pos, itc))
      {
	if (leaf_ret && *n_leaves < max_ret)
	  leaf_ret[(*n_leaves)++] = leaf_pointer (row, itc->itc_insert_key);
	n++;
      }
  }
  END_DO_ROWS;
  return n;
}


double
geo_page_area (it_cursor_t * itc, buffer_desc_t * buf)
{
  bbox_t box;
  memset (&box, 0, sizeof (box));
  DO_ROWS (buf, pos, row, NULL)
  {
    double rx, ry, rx2, ry2;
    if (KV_LEFT_DUMMY == IE_KEY_VERSION (row))
      continue;
    itc_geo_row (itc, buf, row, &rx, &ry, &rx2, &ry2);
    incbox (&box, rx, ry, rx2, ry2);
  }
  END_DO_ROWS;
  return bbox_area (&box);
}


int64
geo_leaf_estimate (it_cursor_t * itc, buffer_desc_t * buf)
{
  /* called with itc on a leaf.  Count how many and multiply */
  buffer_desc_t *p_buf;
  int64 est = 1;
  for (;;)
    {
      dp_addr_t parent;
      int n_on_page = geo_matches_on_page (itc, buf, NULL, NULL, 0);
      est *= MAX (1, n_on_page);
      parent = LONG_REF (buf->bd_buffer + DP_PARENT);
      if (!parent)
	{
	  itc_page_leave (itc, buf);
	  return est;
	}
      p_buf = itc_write_parent (itc, buf);
      if (!p_buf)
	{
	  itc_page_leave (itc, buf);
	  return est;
	}
      itc_page_leave (itc, buf);
      buf = p_buf;
      itc->itc_page = buf->bd_page;
    }
}

int enable_geo_itc_sample = 1;

int64
geo_estimate (dbe_table_t * tb, geo_t * g, int op, double prec, slice_id_t slice)
{
  buffer_desc_t *buf;
  int rc;
  double prec_box[2];
  geo_t box;
  it_cursor_t itc_auto;
  it_cursor_t *itc = &itc_auto;
  ITC_INIT (itc, NULL, NULL);
  geo_get_bounding_XYbox (g, &box, prec, prec);
  box.geo_flags = GEO_GSOP;
  if (tb->tb_primary_key->key_is_elastic && QI_NO_SLICE == slice)
    return 100;			/* dummy, must not get error in mid cost model */
  itc_from (itc, tb->tb_primary_key, slice);
  itc->itc_geo_op = op;
  itc->itc_search_params[0] = (caddr_t) & box;
  itc->itc_search_params[1] = (caddr_t) g;
  *(int64 *) & prec_box[0] = 0;
  ((dtp_t *) & prec_box[1])[-1] = DV_DOUBLE_FLOAT;
  prec_box[1] = prec;
  itc->itc_search_params[2] = (caddr_t) & prec_box[1];
  itc->itc_key_spec.ksp_key_cmp = cmpf_geo;
  if (enable_geo_itc_sample)
    {
      int64 res;
      memzero (&itc->itc_st, sizeof (itc->itc_st));
      res = itc_local_sample (itc);
      return res;
    }
  itc->itc_search_mode = SM_INSERT;
  buf = itc_reset (itc);
  itc->itc_search_mode = SM_READ;
  itc->itc_landed = 1;
  rc = itc_next (itc, &buf);
  if (DVC_MATCH != rc)
    {
      itc_page_leave (itc, buf);
      return 0;
    }
  return geo_leaf_estimate (itc, buf);
}


int
float_is_ov (float f)
{
  return IS_OV (f);
}

void
geo_insert (query_instance_t * qi, dbe_table_t * tb, caddr_t g, boxint id, int is_del, int is_geo_box)
{
  /* Take bounding box of g and put it in the tb with the id.  The tb must have  pk x, y, x2, y2, id.  4 first real or double, last int or bigint */
  caddr_t *log_array;
  buffer_desc_t *buf;
  geo_t box;
  it_cursor_t itc_auto;
  it_cursor_t *itc = &itc_auto;
  dbe_key_t *key = tb->tb_primary_key;
  dtp_t dtp = key->key_key_fixed[RD_X].cl_sqt.sqt_dtp;
  dtp_t id_dtp = key->key_key_fixed[4].cl_sqt.sqt_dtp;
  LOCAL_RD (rd);
  ITC_INIT (itc, NULL, qi->qi_trx);
  rd.rd_key = key;
  rd.rd_n_values = 5;
  rd.rd_op = RD_INSERT;
  rd.rd_rl = INS_NEW_RL;
  rd.rd_non_comp_len = DV_INT64 == id_dtp ? 10 : 6;
  if (!is_geo_box)
    geo_get_bounding_XYbox ((geo_t *) g, &box, 0, 0);
  else
    memcpy (&box, g, sizeof (geo_t));
  if (DV_SINGLE_FLOAT == dtp)
    {
      if (IS_OV ((float)box.XYbox.Xmin) || IS_OV ((float)box.XYbox.Xmax) || IS_OV ((float)box.XYbox.Ymin) || IS_OV ((float)box.XYbox.Ymax))
	sqlr_new_error ("42000", "GEOOV", "inserting geometry with bounding box with NAN or INF coordinates");
      rd.rd_non_comp_len += 16;
      rd.rd_values[RD_X] = box_float (box.XYbox.Xmin);
      rd.rd_values[RD_Y] = box_float (box.XYbox.Ymin);
      rd.rd_values[RD_X2] = box_float (box.XYbox.Xmax);
      rd.rd_values[RD_Y2] = box_float (box.XYbox.Ymax);
    }
  else
    {
      rd.rd_non_comp_len += 32;
      rd.rd_values[RD_X] = box_double (box.XYbox.Xmin);
      rd.rd_values[RD_Y] = box_double (box.XYbox.Ymin);
      rd.rd_values[RD_X2] = box_double (box.XYbox.Xmax);
      rd.rd_values[RD_Y2] = box_double (box.XYbox.Ymax);
    }
  rd.rd_values[RD_ID] = box_num (id);
  itc->itc_search_params[0] = (caddr_t) & box;
  itc->itc_insert_key = key;
  if (!is_del && (qi->qi_non_txn_insert || qi->qi_client->cli_non_txn_insert))
    itc->itc_non_txn_insert = 1;
  else
    rd.rd_make_ins_rbe = 1;
  key->key_table->tb_count_delta += is_del ? -1 : 1;
  itc_from (itc, key, qi->qi_client->cli_slice);
  itc->itc_search_mode = SM_INSERT;
  itc->itc_lock_mode = PL_EXCLUSIVE;
  itc->itc_isolation = ISO_REPEATABLE;
  ITC_FAIL (itc)
  {
    buf = itc_reset (itc);
    if (is_del)
      itc_geo_delete (itc, buf, id);
    else
      itc_geo_insert (itc, buf, &rd);

    log_array = (caddr_t *) list (4, box_string (is_del ? "geo_delete (?, ?, ?)" : "geo_insert (?, ?, ?)"),
	box_num (key->key_id), g, rd.rd_values[RD_ID]);
    log_text_array (qi->qi_trx, (caddr_t) log_array);
    log_array[3] = log_array[2] = NULL;
    dk_free_tree ((caddr_t) log_array);
  }
  ITC_FAILED
  {
    rd_free (&rd);
    itc_free (itc);
  }
  END_FAIL (itc);
  rd_free (&rd);
  itc_free (itc);
}


geo_t *
bif_geo_arg (caddr_t * qst, state_slot_t ** args, int inx, const char *f, int tp)
{
  geo_t *g;
  caddr_t v = bif_arg_unrdf (qst, args, inx, f);
  dtp_t v_dtp = DV_TYPE_OF (v);
  if (DV_GEO != v_dtp)
    {
      if ((GEO_ARG_NULLABLE & tp) && (DV_DB_NULL == v_dtp))
	return NULL;
      sqlr_new_error ("22032", "GEO..", "Function %s() expects a geometry%s as argument %d",
	  f, ((GEO_ARG_NULLABLE == (tp & GEO_ARG_MASK)) ? " or NULL" : ""), inx);
    }
  g = (geo_t *) v;
  if ((GEO_UNDEFTYPE != GEO_TYPE_NO_ZM (tp)) && (GEO_TYPE_NO_ZM (tp) != GEO_TYPE_NO_ZM (g->geo_flags)))
    sqlr_new_error ("22023", "GEO..", "Function %s() expects a geometry of type %d%s as argument %d, not geometry of type %d",
	f, GEO_TYPE (tp), ((GEO_ARG_NULLABLE == (tp & GEO_ARG_MASK)) ? " or NULL" : ""), inx, GEO_TYPE (g->geo_flags));
  if ((GEO_ARG_CHECK_ZM & tp) && ((GEO_A_Z | GEO_A_M) & tp & ~(g->geo_flags)))
    {
      const char *zm_text = "both Z and M coordinates";
      if (!(GEO_A_Z & tp))
	zm_text = "M coordinate";
      else if (!(GEO_A_M & tp))
	zm_text = "Z coordinate";
      sqlr_new_error ("22023", "GEO..", "Function %s() expects a geometry with %s as argument %d, not geometry of type %d",
	  f, zm_text, inx, GEO_TYPE (g->geo_flags));
    }
  return g;
}


int
key_is_geo (dbe_key_t * key)
{
  if (5 == key->key_n_significant && 5 == dk_set_length (key->key_parts))
    {
      if (DV_SINGLE_FLOAT == key->key_key_fixed[RD_X].cl_sqt.sqt_dtp
	  && DV_SINGLE_FLOAT == key->key_key_fixed[RD_Y].cl_sqt.sqt_dtp
	  && DV_SINGLE_FLOAT == key->key_key_fixed[RD_X2].cl_sqt.sqt_dtp
	  && DV_SINGLE_FLOAT == key->key_key_fixed[RD_Y2].cl_sqt.sqt_dtp)
	return 1;
    }
  return 0;
}


caddr_t
bif_geo_insert (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  dbe_key_t *key = NULL;
  caddr_t tn = bif_arg (qst, args, 0, "geo_insert");
  geo_t *g = bif_geo_arg (qst, args, 1, "geo_insert", GEO_ARG_ANY_NONNULL);
  boxint id = bif_long_arg (qst, args, 2, "geo_insert");
  QNCAST (query_instance_t, qi, qst);
  dbe_table_t *tb;
  dtp_t dtp = DV_TYPE_OF (tn);
  if (DV_LONG_INT == dtp)
    {
      key = sch_id_to_key (wi_inst.wi_schema, unbox (tn));
    }
  else if (DV_STRING == dtp)
    {
      tb = sch_name_to_table (wi_inst.wi_schema, tn);
      if (!tb || !key_is_geo (tb->tb_primary_key))
	sqlr_new_error ("22032", "GEO..", "table %s is not a geo index table", tn);
      key = tb->tb_primary_key;
    }
  if (!key || !key_is_geo (key))
    sqlr_new_error ("22032", "GEO..", "key %d is not a geo key", (int) unbox (tn));
  geo_insert (qi, key->key_table, (caddr_t) g, id, 0, 0);
  return NULL;
}


caddr_t
bif_geo_estimate (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  QNCAST (query_instance_t, qi, qst);
  dbe_key_t *key = NULL;
  caddr_t tn = bif_string_arg (qst, args, 0, "geo_estimate");
  geo_t *g = bif_geo_arg (qst, args, 1, "geo_estimate", GEO_ARG_ANY_NONNULL);
  int op = bif_long_arg (qst, args, 2, "geo_estimate");
  double prec = bif_double_arg (qst, args, 3, "geo_estimate");
  dbe_table_t *tb = sch_name_to_table (wi_inst.wi_schema, tn);
  if (!tb || !key_is_geo (tb->tb_primary_key))
    sqlr_new_error ("22032", "GEO..", "table %s is not a geo index table", tn);
  key = tb->tb_primary_key;
  if (!key || !key_is_geo (key))
    sqlr_new_error ("22032", "GEO..", "key %d is not a geo key", (int) unbox (tn));
  return box_num (geo_estimate (key->key_table, g, op, prec, qi->qi_client->cli_slice));
}


caddr_t
bif_geo_delete (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  dbe_key_t *key = NULL;
  caddr_t tn = bif_arg (qst, args, 0, "geo_delete");
  geo_t *g = bif_geo_arg (qst, args, 1, "geo_delete", GEO_ARG_ANY_NONNULL);
  boxint id = bif_long_arg (qst, args, 2, "geo_delete");
  QNCAST (query_instance_t, qi, qst);
  dbe_table_t *tb;
  dtp_t dtp = DV_TYPE_OF (tn);
  if (DV_LONG_INT == dtp)
    {
      key = sch_id_to_key (wi_inst.wi_schema, unbox (tn));
    }
  else if (DV_STRING == dtp)
    {
      tb = sch_name_to_table (wi_inst.wi_schema, tn);
      if (!tb || !key_is_geo (tb->tb_primary_key))
	sqlr_new_error ("22032", "GEO..", "table %s is not a geo index table", tn);
      key = tb->tb_primary_key;
    }
  if (!key || !key_is_geo (key))
    sqlr_new_error ("22032", "GEO..", "key %d is not a geo key", (int) unbox (tn));
  geo_insert (qi, key->key_table, (caddr_t) g, id, 1, 0);
  return NULL;
}


caddr_t
geo_wkt (caddr_t x)
{
  QNCAST (geo_t, g, x);
  if ((GEO_POINT == GEO_TYPE (g->geo_flags)) && (GEO_SRCODE_DEFAULT == g->geo_srcode))
    {
      char xx[100];
      snprintf (xx, sizeof (xx), "POINT(%g %g)", Xkey(g), Ykey(g));
      return box_dv_short_string (xx);
    }
  else
    {
      dk_session_t *ses = strses_allocate ();
      caddr_t res;
      ewkt_print_sf12 (g, ses);
      res = strses_string (ses);
      strses_free (ses);
      return res;
    }
}

caddr_t
geo_parse_wkt (char *text, caddr_t * err_ret)
{
  geo_t *g;
  do
    {
      char *par = text, ns1[30], ns2[30];
      double x, y;
      if (strncmp (text, "point(", 6) && strncmp (text, "POINT(", 6))
	break;
      if (2 != sscanf (par + 6, "%20s %20s", ns1, ns2))
	break;
      if (2 != sscanf (par + 6, "%lg %lg", &x, &y))
	break;
      g = geo_point (x, y);
      if (!(strlen (ns1) > 8 && strlen (ns2) > 8))
	g->geo_flags |= GEO_IS_FLOAT;
      *err_ret = NULL;
      return (caddr_t) g;
    }
  while (0);
  g = ewkt_parse (text, err_ret);
  return (caddr_t)g;
}

double
txs_prec (text_node_t * txs, caddr_t * inst)
{
  if (txs->txs_precision)
    {
      state_slot_t **prec_box;
      state_slot_t *pp[3];
      BOX_AUTO_TYPED (state_slot_t **, prec_box, pp, 1 * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
      prec_box[0] = txs->txs_precision;
      return bif_double_arg (inst, prec_box, 0, "contains with geo precision");
    }
  return 0;
}

query_t * geo_ck_qr;

void
geo_rdf_check (text_node_t * txs, caddr_t * inst)
{
  /* will always be in the partition where the rdf box can be completed locally */
  QNCAST (query_instance_t, qi, inst);
  int n_sets = txs->src_gen.src_prev ? QST_INT (inst, txs->src_gen.src_prev->src_out_fill) : qi->qi_n_sets;
  caddr_t geo = NULL;
  data_col_t * ser_dc;
  double prec;
  geo_t *g2;
  caddr_t err = NULL;
  state_slot_t ** args;
  select_node_t * sel;
  local_cursor_t lc;
  AUTO_POOL (100);
  QST_INT (inst, txs->src_gen.src_out_fill) = 0;
  SRC_IN_STATE (txs, inst) = NULL;
  if (!geo_ck_qr)
    {
      geo_ck_qr = sql_compile_static ("select coalesce (blob_to_string (ro_long), ro_val)  from rdf_obj table option (no cluster) where ro_id = ?", qi->qi_client, &err, SQLC_DEFAULT);
      if (err)
	sqlr_resignal (err);
    }
  prec = txs_prec (txs, inst);
  qi->qi_set_mask = NULL;
  qi->qi_n_sets = n_sets;
  if (SSL_VEC != txs->txs_d_id->ssl_type)
    sqlr_new_error ("VECSL", "VECSL",  "Geo chekc ro id is to be a vec ssl.  For support.");
  args = (state_slot_t**)ap_list (&ap, 1, txs->txs_d_id);
  sel = geo_ck_qr->qr_select_node;
  memset (&lc, 0, sizeof (lc));
  err = qr_subq_exec_vec (qi->qi_client, geo_ck_qr, qi, NULL, 0, args, NULL, NULL, &lc);
  if (err)
    {
      sqlr_resignal (err);
    }
  ser_dc = QST_BOX (data_col_t *, lc.lc_inst, sel->sel_out_slots[0]->ssl_index);
  while (lc_next (&lc))
    {
      dtp_t dtp;
      int set = qst_vec_get_int64  (lc.lc_inst, sel->sel_set_no, lc.lc_position), hl;
      db_buf_t dv = ((db_buf_t *)ser_dc->dc_values)[set];
      if (!IS_BOX_POINTER (dv))
	continue;
      if (DV_SHORT_STRING_SERIAL == *dv)
	hl = 2;
      else if (DV_STRING == *dv)
	hl = 5;
      else
	continue;
      geo = box_deserialize_reusing (dv + hl, geo);
      qi->qi_set = set;
      g2 = (geo_t *) qst_get (inst, txs->txs_text_exp);
      dtp = DV_TYPE_OF (g2);
      if (DV_RDF == dtp)
    {
	  g2 = (geo_t *) ((rdf_box_t *) g2)->rb_box;
	  dtp = DV_TYPE_OF (g2);
    }
      if (DV_GEO == dtp && geo_pred ((geo_t *) geo, g2, txs->txs_geo, prec))
	qn_result ((data_source_t *) txs, inst, set);
    }
  dk_free_box (geo);
  if (lc.lc_inst)
    qi_free (lc.lc_inst);
  if (lc.lc_error)
    sqlr_resignal (lc.lc_error);
  if (QST_INT (inst, txs->src_gen.src_out_fill))
    qn_send_output ((data_source_t *) txs, inst);
}

void
geo_node_vec_input (text_node_t * txs, caddr_t * inst, caddr_t * state)
{
  QNCAST (query_instance_t, qi, inst);
  boxint id;
  int rc, org_flags;
  it_cursor_t *itc = (it_cursor_t *) QST_GET_V (inst, txs->txs_sst);
  buffer_desc_t *buf;
  dbe_key_t *key = txs->txs_table->tb_primary_key;
  int need_enter = 0;
  dbe_col_loc_t *id_cl = &key->key_key_fixed[4];
  int n_sets = txs->src_gen.src_prev ? QST_INT (inst, txs->src_gen.src_prev->src_out_fill) : qi->qi_n_sets;
  int nth_set, batch_sz;
  QNCAST (data_source_t, qn, txs);

  if (state)
    nth_set = QST_INT (inst, txs->clb.clb_nth_set) = 0;
  else
    {
      need_enter = 1;
      nth_set = QST_INT (inst, txs->clb.clb_nth_set);
    }

again:
  batch_sz = QST_INT (inst, txs->src_gen.src_batch_size);
  QST_INT (inst, qn->src_out_fill) = 0;
  dc_reset_array (inst, qn, qn->src_continue_reset, -1);
  for (; nth_set < n_sets; nth_set++)
    {
      data_col_t *dc = QST_BOX (data_col_t *, inst, txs->txs_d_id->ssl_index);
      SRC_IN_STATE (txs, inst) = NULL;
      qi->qi_set = nth_set;
      for (;;)
	{
	  if (state)
	    {
	      double prec = 0;
	      geo_t *geo, *box;
	      if (!itc)
		{
		  itc = itc_create (NULL, qi->qi_trx);
		  memset (&itc->itc_search_params, 0, 3 * sizeof (caddr_t));
		  itc_from (itc, key, qi->qi_client->cli_slice);
		  itc_geo_register (itc);
		  itc->itc_key_spec.ksp_key_cmp = cmpf_geo;
		  QST_GET_V (inst, txs->txs_sst) = (caddr_t) itc;
		}
	      else
		{
		  itc_unregister (itc);
		}
	      geo = (geo_t *) qst_get (inst, txs->txs_text_exp);
	      if (DV_RDF == DV_TYPE_OF (geo))
		{
		  QNCAST (rdf_box_t, rb, geo);
		  if (!rb->rb_is_complete)
		    sqlr_new_error ("22023", "GEO..", "An incomplete rdf box is not accepted as 2nd arg of st_intersect ro id=%Ld", rb->rb_ro_id);
		  geo = (geo_t *) rb->rb_box;
		}
	      if (DV_GEO != DV_TYPE_OF ((caddr_t) geo))
		{
		  if (qi->qi_no_cast_error)
		    {
		      return;
		    }
		  sqlr_new_error ("22032", "GEO..", "Indexed geo operation expects a geometry as search argument");
		}
	      box = (geo_t *) itc->itc_search_params[0];
	      if (!box)
		{
		  box = geo_alloc (GEO_GSOP, 0, GEO_SRID (geo->geo_srcode));
		  itc->itc_geo_op = txs->txs_geo;
		  box->geo_fill = 0;
		  ITC_OWNS_PARAM (itc, (caddr_t) box);
		  itc->itc_search_params[0] = (caddr_t) box;
		}
	      prec = txs_prec (txs, inst);
		  if (itc->itc_search_params[2])
		    *(double *) itc->itc_search_params[2] = prec;
		  else
		    {
		      caddr_t dbox = box_double (prec);
		      ITC_OWNS_PARAM (itc, dbox);
		      itc->itc_search_params[2] = dbox;
		    }
	      org_flags = box->geo_flags;
	      geo_get_bounding_XYbox (geo, box, prec, prec);
	      box->geo_flags = org_flags;
	      itc->itc_search_params[1] = (caddr_t) geo;

	      itc->itc_search_mode = SM_INSERT;
	      itc->itc_bp.bp_is_pos_valid = 1;
	      buf = itc_reset (itc);
	      itc->itc_search_mode = SM_READ;
	      itc->itc_landed = 1;
	      itc->itc_map_pos = 0;
	      state = NULL;
	    }
	  itc->itc_ltrx = qi->qi_trx;
	  ITC_FAIL (itc)
	  {
	    if (need_enter)
	      {
		buf = page_reenter_excl (itc);
		need_enter = 0;
	      }
	    rc = itc_next (itc, &buf);
	  }
	  ITC_FAILED
	  {
	  }
	  END_FAIL (itc);
	  if (!itc->itc_bp.bp_is_pos_valid)
	    {
	      itc_page_leave (itc, buf);
	      sqlr_new_error ("40001", "GEO..", "Cursor over geo index reset due to concurrent split of index.  Retry the query");
	    }
	  if (DVC_MATCH != rc)
	    {
	      itc_page_leave (itc, buf);
	      state = inst;
	      goto next_set;
	    }
	  if (DV_INT64 == id_cl->cl_sqt.sqt_dtp)
	    id = INT64_REF (itc->itc_row_data + id_cl->cl_pos[0]);
	  else
	    id = LONG_REF (itc->itc_row_data + id_cl->cl_pos[0]);
	  qi->qi_set = dc->dc_n_values;
	  if (txs->txs_is_rdf)
	    {
	      rdf_box_t *rb = rb_allocate ();
	      rb->rb_ro_id = id;
	      rb->rb_type = RDF_BOX_GEO;
	      qst_vec_set (inst, txs->txs_d_id, (caddr_t) rb);
	    }
	  else
	    dc_set_long (dc, qi->qi_set, id);
	  qn_result ((data_source_t *) txs, inst, nth_set);
	  if (QST_INT (inst, txs->src_gen.src_out_fill) >= batch_sz)
	    {
	      itc_register (itc, buf);
	      itc_page_leave (itc, buf);
	      QST_INT (inst, txs->clb.clb_nth_set) = nth_set;
	      SRC_IN_STATE (txs, inst) = inst;
	      qn_send_output ((data_source_t *) txs, inst);
	      state = NULL;
	      need_enter = 1;
	      goto again;
	    }
	}
    next_set:;
    }
  SRC_IN_STATE (txs, inst) = NULL;
  if (QST_INT (inst, txs->src_gen.src_out_fill))
    qn_send_output ((data_source_t *) txs, inst);
}

void
geo_node_input (text_node_t * txs, caddr_t * inst, caddr_t * state)
{
  if (!txs->txs_is_driving && txs->txs_is_rdf)
    {
      geo_rdf_check (txs, inst);
      return;
    }
  if (txs->src_gen.src_sets)
    {
      geo_node_vec_input (txs, inst, state);
      return;
    }
  GPF_T1 ("non-vectored geo node");
}


caddr_t
dbg_geo_to_text (caddr_t x)
{
  geo_t *g = (geo_t *) x;
  char tmp[100];
  switch (GEO_TYPE (g->geo_flags))
    {
    case GEO_POINT:
      snprintf (tmp, sizeof (tmp), "<point %g %g>", Xkey(g), Ykey(g));
      break;
    default:
      sprintf (tmp, "<geo type %d>", GEO_TYPE (g->geo_flags));
      break;
    }
  return box_dv_short_string (tmp);
}

dk_mutex_t *geo_reg_mtx;

void
geo_init ()
{
  bif_define_ex ("geo_insert"		, bif_geo_insert						, BMD_USES_INDEX, BMD_NEED_ENLIST, BMD_DONE);
  bif_define_ex ("geo_delete"		, bif_geo_delete						, BMD_USES_INDEX, BMD_NEED_ENLIST, BMD_DONE);
  bif_define_ex ("geo_estimate"		, bif_geo_estimate						, BMD_USES_INDEX, BMD_DONE);
  dk_mem_hooks_2 (DV_GEO, (box_copy_f) geo_copy, (box_destr_f) geo_destroy, 0, (box_tmp_copy_f) mp_geo_copy);
  get_readtable ()[DV_GEO] = (macro_char_func) geo_deserialize;
  PrpcSetWriter (DV_GEO, (ses_write_func) geo_serialize);
  geo_reg_mtx = mutex_allocate ();
}

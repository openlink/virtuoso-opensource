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
 */

#include <float.h>
#ifdef WIN32
#define _USE_MATH_DEFINES
#endif
#include <math.h>
#include "Dk.h"
#include "Dk/Dkalloc.h"
#include "Dk/Dkbox.h"
#include "geo.h"
#include "widv.h"
#include "sqlfn.h"
#include "xmlparser.h"		/* for ecm_find() */
#include "xml_ecm.h"		/* for ecm_find() */

#define GEO_HEAD_SZ(lastfld) ((((char *)((&(((geo_t *)NULL)->lastfld))+1))-((char *)NULL)))

#define GEO_ALLOC_POINT(lastfld) res = (geo_t *)dk_alloc_box_zero (GEO_HEAD_SZ(lastfld), DV_GEO)

#define GEO_SET_CVECT(fld) do { \
  res->fld = (geoc *)((void *)(((char *)res) + head_sz)); \
  head_sz += (len_ * sizeof (geoc)); \
  } while (0);

#define GEO_SET_MVECT(fld) do { \
  res->fld = (geo_measure_t *)((void *)(((char *)res) + head_sz)); \
  head_sz += (len_ * sizeof (geo_measure_t)); \
  } while (0);

#define GEO_SET_GCB(fld,geo_flags,gcb_step_) do { \
  if (geo_flags_ & GEO_IS_CHAINBOXED) { \
      res->fld = (geo_chainbox_t *)((void *)(((char *)res) + head_sz)); \
      res->fld->gcb_box_count = gcb_bcount; \
      res->fld->gcb_step = gcb_step_; \
      res->fld->gcb_is_set = 0; \
      head_sz += gcb_sz; \
    } \
  } while (0);

#define GEO_ALLOC_PLINE(lastfld,cvecs,mvecs,gcb_min_len,gcb_step_,gcb_ignore_first) do { \
  head_sz = ALIGN_LIKE_BOX(GEO_HEAD_SZ(lastfld)); \
  if ((len_-gcb_ignore_first) >= ((geo_flags_ & GEO_IS_CHAINBOXED) ? (2*gcb_step_) : gcb_min_len)) \
    { \
      size_t gcb_head_sz = ALIGN_LIKE_BOX(GEO_HEAD_SZ(_.pline.pline_gcb)); \
      geo_flags_ |= GEO_IS_CHAINBOXED; \
      if (head_sz < gcb_head_sz) \
        head_sz = gcb_head_sz; \
      gcb_bcount = (((len_-gcb_ignore_first) + gcb_step_ - 1) / gcb_step_); \
      gcb_sz = sizeof (geo_chainbox_t) + sizeof (geo_XYbox_t) * gcb_bcount; \
    } \
  else \
    { \
      geo_flags_ &= ~GEO_IS_CHAINBOXED; \
      gcb_sz = 0; \
    } \
  full_sz = head_sz + gcb_sz + len_ * (cvecs * sizeof (geoc) + mvecs * sizeof (geo_measure_t)); \
  res = (geo_t *)dk_alloc_box (full_sz, DV_GEO); \
  res->_.pline.len = len_; \
  GEO_SET_CVECT(_.pline.Xs); \
  GEO_SET_CVECT(_.pline.Ys); \
  GEO_SET_GCB(_.pline.pline_gcb,geo_flags_,gcb_step_); \
  } while (0);

#define GEO_ALLOC_PARTS(lastfld,gcb_min_len,gcb_step_,gcb_ignore_first) do { \
  head_sz = ALIGN_LIKE_BOX(GEO_HEAD_SZ(lastfld)); \
  if ((len_-gcb_ignore_first) >= ((geo_flags_ & GEO_IS_CHAINBOXED) ? (2*gcb_step_) : gcb_min_len)) \
    { \
      size_t gcb_head_sz = ALIGN_LIKE_BOX(GEO_HEAD_SZ(_.parts.parts_gcb)); \
      geo_flags_ |= GEO_IS_CHAINBOXED; \
      if (head_sz < gcb_head_sz) \
        head_sz = gcb_head_sz; \
      gcb_bcount = (((len_- gcb_ignore_first) + gcb_step_ - 1) / gcb_step_); \
      gcb_sz = sizeof (geo_chainbox_t) + sizeof (geo_XYbox_t) * gcb_bcount; \
    } \
  else \
    { \
      geo_flags_ &= ~GEO_IS_CHAINBOXED; \
      gcb_sz = 0; \
    } \
  full_sz = head_sz + gcb_sz + (len_ * sizeof (geo_t *)); \
  res = (geo_t *)dk_alloc_box (full_sz, DV_GEO); \
  res->_.parts.len = len_; \
  res->_.parts.items = ((geo_t **)(((char *)res) + head_sz)); \
  res->_.parts.serialization_length = 0; \
  head_sz += (len_ * sizeof (geo_t *)); \
  GEO_SET_GCB(_.parts.parts_gcb,geo_flags_,gcb_step_); \
  } while (0);

geo_t *
geo_alloc (geo_flags_t geo_flags_, int len_, int srcode_)
{
  geo_t *res;
  int head_sz, gcb_bcount, gcb_sz, full_sz;
  switch (GEO_TYPE (geo_flags_))
    {
    case GEO_NULL_SHAPE:		GEO_ALLOC_POINT(XYbox); break;
    case GEO_POINT:			GEO_ALLOC_POINT(XYbox); break;
    case GEO_POINT_Z:			GEO_ALLOC_POINT(_.point.point_ZMbox.Zmax); break;
    case GEO_POINT_M:			GEO_ALLOC_POINT(_.point.point_ZMbox.Mmax); break;
    case GEO_POINT_Z_M:			GEO_ALLOC_POINT(_.point.point_ZMbox.Mmax); break;
    case GEO_LINESTRING:		GEO_ALLOC_PLINE(_.pline.Ys		, 2, 0, 0x100, 0x40, 1); break;
    case GEO_LINESTRING_Z:		GEO_ALLOC_PLINE(_.pline.pline_ZMbox.Zmax, 3, 0, 0x100, 0x40, 1); GEO_SET_CVECT(_.pline.Zs); break;
    case GEO_LINESTRING_M:		GEO_ALLOC_PLINE(_.pline.Ms		, 2, 1, 0x100, 0x40, 1); GEO_SET_MVECT(_.pline.Ms); break;
    case GEO_LINESTRING_Z_M:		GEO_ALLOC_PLINE(_.pline.Ms		, 3, 1, 0x100, 0x40, 1); GEO_SET_CVECT(_.pline.Zs); GEO_SET_MVECT(_.pline.Ms); break;
    case GEO_BOX:			GEO_ALLOC_POINT(XYbox); break;
    case GEO_BOX_Z:			GEO_ALLOC_POINT(_.point.point_ZMbox.Zmax); break;
    case GEO_BOX_M:			GEO_ALLOC_POINT(_.point.point_ZMbox.Mmax); break;
    case GEO_BOX_Z_M:			GEO_ALLOC_POINT(_.point.point_ZMbox.Mmax); break;
    case GEO_ARCSTRING:			GEO_ALLOC_PLINE(_.pline.Ys		, 2, 0,  0x10, 0x08, 1); break;
    case GEO_GSOP:			GEO_ALLOC_POINT(_.point.point_gs_precision); break;
    case GEO_RING:			GEO_ALLOC_PLINE(_.pline.Ys		, 2, 0,  0x4, 0x2, 1); break;
    case GEO_RING_Z:			GEO_ALLOC_PLINE(_.pline.pline_ZMbox.Zmax, 3, 0,  0x80, 0x20, 1); GEO_SET_CVECT(_.pline.Zs); break;
    case GEO_RING_M:			GEO_ALLOC_PLINE(_.pline.Ms		, 2, 1,  0x80, 0x20, 1); GEO_SET_MVECT(_.pline.Ms); break;
    case GEO_RING_Z_M:			GEO_ALLOC_PLINE(_.pline.Ms		, 3, 1,  0x80, 0x20, 1); GEO_SET_CVECT(_.pline.Zs); GEO_SET_MVECT(_.pline.Ms); break;
    case GEO_POINTLIST:			GEO_ALLOC_PLINE(_.pline.Ys		, 2, 0, 0x200, 0x20, 0);
    case GEO_POINTLIST_Z:		GEO_ALLOC_PLINE(_.pline.pline_ZMbox.Zmax, 3, 0, 0x200, 0x20, 0); GEO_SET_CVECT(_.pline.Zs); break;
    case GEO_POINTLIST_M:		GEO_ALLOC_PLINE(_.pline.Ms		, 2, 1, 0x200, 0x20, 0); GEO_SET_MVECT(_.pline.Ms); break;
    case GEO_POINTLIST_Z_M:		GEO_ALLOC_PLINE(_.pline.Ms		, 3, 1, 0x200, 0x20, 0); GEO_SET_CVECT(_.pline.Zs); GEO_SET_MVECT(_.pline.Ms); break;
    case GEO_MULTI_LINESTRING:		GEO_ALLOC_PARTS(_.parts.items		, 0x100, 0x10, 0); break;
    case GEO_MULTI_LINESTRING_Z:	GEO_ALLOC_PARTS(_.parts.parts_ZMbox.Zmax, 0x100, 0x10, 0); break;
    case GEO_MULTI_LINESTRING_M:	GEO_ALLOC_PARTS(_.parts.parts_ZMbox.Mmax, 0x100, 0x10, 0); break;
    case GEO_MULTI_LINESTRING_Z_M:	GEO_ALLOC_PARTS(_.parts.parts_ZMbox.Mmax, 0x100, 0x10, 0); break;
    case GEO_POLYGON:			GEO_ALLOC_PARTS(_.parts.items		, 0x100, 0x10, 1); break;
    case GEO_POLYGON_Z:			GEO_ALLOC_PARTS(_.parts.parts_ZMbox.Zmax, 0x100, 0x10, 1); break;
    case GEO_POLYGON_M:			GEO_ALLOC_PARTS(_.parts.parts_ZMbox.Mmax, 0x100, 0x10, 1); break;
    case GEO_POLYGON_Z_M:		GEO_ALLOC_PARTS(_.parts.parts_ZMbox.Mmax, 0x100, 0x10, 1); break;
    case GEO_MULTI_POLYGON:		GEO_ALLOC_PARTS(_.parts.items		, 0x100, 0x10, 0); break;
    case GEO_MULTI_POLYGON_Z:		GEO_ALLOC_PARTS(_.parts.parts_ZMbox.Zmax, 0x100, 0x10, 0); break;
    case GEO_MULTI_POLYGON_M:		GEO_ALLOC_PARTS(_.parts.parts_ZMbox.Mmax, 0x100, 0x10, 0); break;
    case GEO_MULTI_POLYGON_Z_M:		GEO_ALLOC_PARTS(_.parts.parts_ZMbox.Mmax, 0x100, 0x10, 0); break;
    case GEO_COLLECTION:		GEO_ALLOC_PARTS(_.parts.items		, 0x100, 0x10, 0); break;
    case GEO_COLLECTION_Z:		GEO_ALLOC_PARTS(_.parts.parts_ZMbox.Zmax, 0x100, 0x10, 0); break;
    case GEO_COLLECTION_M:		GEO_ALLOC_PARTS(_.parts.parts_ZMbox.Mmax, 0x100, 0x10, 0); break;
    case GEO_COLLECTION_Z_M:		GEO_ALLOC_PARTS(_.parts.parts_ZMbox.Mmax, 0x100, 0x10, 0); break;
    case GEO_CURVE:			GEO_ALLOC_PARTS(_.parts.items		,  0x10, 0x04, 0); break;
    case GEO_CLOSEDCURVE:		GEO_ALLOC_PARTS(_.parts.items		,  0x10, 0x04, 0); break;
    case GEO_CURVEPOLYGON:		GEO_ALLOC_PARTS(_.parts.items		,  0x10, 0x04, 1); break;
    case GEO_MULTI_CURVE:		GEO_ALLOC_PARTS(_.parts.items		,  0x10, 0x04, 0); break;
    default: GPF_T;
    }
  res->geo_flags = geo_flags_;
  res->geo_srcode = srcode_;
  return res;
}

#undef GEO_SET_CVECT
#undef GEO_SET_MVECT
#undef GEO_ALLOC_PLINE
#undef GEO_ALLOC_PARTS

geo_t *
geo_point (geoc x, geoc y)
{
  geo_t *res;
  GEO_ALLOC_POINT (XYbox);
  res->geo_flags = GEO_POINT;
  res->geo_srcode = GEO_SRCODE_DEFAULT;
  res->XYbox.Xmin = res->XYbox.Xmax = x;
  res->XYbox.Ymin = res->XYbox.Ymax = y;
  return res;
}


#define GEO_RESET_GCB(fld) do { \
  if (src->geo_flags & GEO_IS_CHAINBOXED) \
    res->fld = (geo_chainbox_t *)((void *)(((char *)res) + (((char *)(src->fld)) - (char *)src))); } while (0)

#define GEO_RESET_CVECT(fld) \
  res->fld = (geoc *)((void *)(((char *)res) + (((char *)(src->fld)) - (char *)src)));

#define GEO_RESET_MVECT(fld) \
  res->fld = (geo_measure_t *)((void *)(((char *)res) + (((char *)(src->fld)) - (char *)src)));

#define GEO_COPY_POINT(lastfld)

#define GEO_COPY_PLINE(lastfld,cvecs,mvecs) do { \
  GEO_RESET_GCB(_.pline.pline_gcb); \
  GEO_RESET_CVECT(_.pline.Xs); \
  GEO_RESET_CVECT(_.pline.Ys); \
  } while (0)

#define GEO_COPY_PARTS(lastfld) do { int ctr; \
  GEO_RESET_GCB(_.parts.parts_gcb); \
  res->_.parts.items = (geo_t **)((void *)(((char *)res) + (((char *)(src->_.parts.items)) - (char *)src))); \
  for (ctr = res->_.parts.len; ctr--; /* no step */) \
    res->_.parts.items[ctr] = geo_copy (res->_.parts.items[ctr]); \
  } while (0)

geo_t *
geo_copy (geo_t *src)
{
  size_t full_sz = box_length (src);
  geo_t *res = (geo_t *)dk_alloc_box (full_sz, DV_GEO);
  memcpy (res, src, full_sz);
  switch (GEO_TYPE (src->geo_flags))
    {
    case GEO_NULL_SHAPE:		GEO_COPY_POINT(XYbox); break;
    case GEO_POINT:			GEO_COPY_POINT(XYbox); break;
    case GEO_POINT_Z:			GEO_COPY_POINT(_.point.point_ZMbox.Zmax); break;
    case GEO_POINT_M:			GEO_COPY_POINT(_.point.point_ZMbox.Mmax); break;
    case GEO_POINT_Z_M:			GEO_COPY_POINT(_.point.point_ZMbox.Mmax); break;
    case GEO_LINESTRING:		GEO_COPY_PLINE(_.pline.Ys, 2, 0); break;
    case GEO_LINESTRING_Z:		GEO_COPY_PLINE(_.pline.pline_ZMbox.Zmax, 3, 0); GEO_RESET_CVECT(_.pline.Zs); break;
    case GEO_LINESTRING_M:		GEO_COPY_PLINE(_.pline.Ms, 2, 1); GEO_RESET_MVECT(_.pline.Ms); break;
    case GEO_LINESTRING_Z_M:		GEO_COPY_PLINE(_.pline.Ms, 3, 1); GEO_RESET_CVECT(_.pline.Zs); GEO_RESET_MVECT(_.pline.Ms); break;
    case GEO_BOX:			GEO_COPY_POINT(XYbox); break;
    case GEO_BOX_Z:			GEO_COPY_POINT(_.point.point_ZMbox.Zmax); break;
    case GEO_BOX_M:			GEO_COPY_POINT(_.point.point_ZMbox.Mmax); break;
    case GEO_BOX_Z_M:			GEO_COPY_POINT(_.point.point_ZMbox.Mmax); break;
    case GEO_ARCSTRING:			GEO_COPY_PLINE(_.pline.Ys, 2, 0); break;
    case GEO_GSOP:			GEO_COPY_POINT(_.point.point_gs_precision); break;
    case GEO_RING:			GEO_COPY_PLINE(_.pline.Ys, 2, 0); break;
    case GEO_RING_Z:			GEO_COPY_PLINE(_.pline.pline_ZMbox.Zmax, 3, 0); GEO_RESET_CVECT(_.pline.Zs); break;
    case GEO_RING_M:			GEO_COPY_PLINE(_.pline.Ms, 2, 1); GEO_RESET_MVECT(_.pline.Ms); break;
    case GEO_RING_Z_M:			GEO_COPY_PLINE(_.pline.Ms, 3, 1); GEO_RESET_CVECT(_.pline.Zs); GEO_RESET_MVECT(_.pline.Ms); break;
    case GEO_POINTLIST:			GEO_COPY_PLINE(_.pline.Ys, 2, 0);
    case GEO_POINTLIST_Z:		GEO_COPY_PLINE(_.pline.pline_ZMbox.Zmax, 3, 0); GEO_RESET_CVECT(_.pline.Zs); break;
    case GEO_POINTLIST_M:		GEO_COPY_PLINE(_.pline.Ms, 2, 1); GEO_RESET_MVECT(_.pline.Ms); break;
    case GEO_POINTLIST_Z_M:		GEO_COPY_PLINE(_.pline.Ms, 3, 1); GEO_RESET_CVECT(_.pline.Zs); GEO_RESET_MVECT(_.pline.Ms); break;
    case GEO_MULTI_LINESTRING:		GEO_COPY_PARTS(_.parts.items); break;
    case GEO_MULTI_LINESTRING_Z:	GEO_COPY_PARTS(_.parts.parts_ZMbox.Zmax); break;
    case GEO_MULTI_LINESTRING_M:	GEO_COPY_PARTS(_.parts.parts_ZMbox.Mmax); break;
    case GEO_MULTI_LINESTRING_Z_M:	GEO_COPY_PARTS(_.parts.parts_ZMbox.Mmax); break;
    case GEO_POLYGON:			GEO_COPY_PARTS(_.parts.items); break;
    case GEO_POLYGON_Z:			GEO_COPY_PARTS(_.parts.parts_ZMbox.Zmax); break;
    case GEO_POLYGON_M:			GEO_COPY_PARTS(_.parts.parts_ZMbox.Mmax); break;
    case GEO_POLYGON_Z_M:		GEO_COPY_PARTS(_.parts.parts_ZMbox.Mmax); break;
    case GEO_MULTI_POLYGON:		GEO_COPY_PARTS(_.parts.items); break;
    case GEO_MULTI_POLYGON_Z:		GEO_COPY_PARTS(_.parts.parts_ZMbox.Zmax); break;
    case GEO_MULTI_POLYGON_M:		GEO_COPY_PARTS(_.parts.parts_ZMbox.Mmax); break;
    case GEO_MULTI_POLYGON_Z_M:		GEO_COPY_PARTS(_.parts.parts_ZMbox.Mmax); break;
    case GEO_COLLECTION:		GEO_COPY_PARTS(_.parts.items); break;
    case GEO_COLLECTION_Z:		GEO_COPY_PARTS(_.parts.parts_ZMbox.Zmax); break;
    case GEO_COLLECTION_M:		GEO_COPY_PARTS(_.parts.parts_ZMbox.Mmax); break;
    case GEO_COLLECTION_Z_M:		GEO_COPY_PARTS(_.parts.parts_ZMbox.Mmax); break;
    case GEO_CLOSEDCURVE:		GEO_COPY_PARTS(_.parts.items); break;
    case GEO_CURVE:			GEO_COPY_PARTS(_.parts.items); break;
    case GEO_CURVEPOLYGON:		GEO_COPY_PARTS(_.parts.items); break;
    case GEO_MULTI_CURVE:		GEO_COPY_PARTS(_.parts.items); break;
    default: GPF_T;
    }
  return res;
}

#undef GEO_COPY_POINT
#undef GEO_COPY_PLINE
#undef GEO_COPY_PARTS

#define GEO_MP_COPY_POINT(lastfld)

#define GEO_MP_COPY_PLINE(lastfld,cvecs,mvecs) \
  GEO_RESET_CVECT(_.pline.Xs); \
  GEO_RESET_CVECT(_.pline.Ys);

#define GEO_MP_COPY_PARTS(lastfld) do { int ctr; \
  res->_.parts.items = (geo_t **)((void *)(((char *)res) + (((char *)(&(src->_.parts.items))) - (char *)src))); \
  for (ctr = res->_.parts.len; ctr--; /* no step */) \
    res->_.parts.items[ctr] = mp_geo_copy (mp, res->_.parts.items[ctr]); \
  } while (0)

geo_t *
mp_geo_copy (mem_pool_t * mp, geo_t *src)
{
  size_t full_sz = box_length (src);
  geo_t *res = (geo_t *)mp_alloc_box (mp, full_sz, DV_GEO);
  memcpy (res, src, full_sz);
  switch (GEO_TYPE (src->geo_flags))
    {
    case GEO_NULL_SHAPE:		GEO_MP_COPY_POINT(XYbox); break;
    case GEO_POINT:			GEO_MP_COPY_POINT(XYbox); break;
    case GEO_POINT_Z:			GEO_MP_COPY_POINT(_.point.point_ZMbox.Zmax); break;
    case GEO_POINT_M:			GEO_MP_COPY_POINT(_.point.point_ZMbox.Mmax); break;
    case GEO_POINT_Z_M:			GEO_MP_COPY_POINT(_.point.point_ZMbox.Mmax); break;
    case GEO_LINESTRING:		GEO_MP_COPY_PLINE(_.pline.Ys, 2, 0); break;
    case GEO_LINESTRING_Z:		GEO_MP_COPY_PLINE(_.pline.pline_ZMbox.Zmax, 3, 0); GEO_RESET_CVECT(_.pline.Zs); break;
    case GEO_LINESTRING_M:		GEO_MP_COPY_PLINE(_.pline.Ms, 2, 1); GEO_RESET_MVECT(_.pline.Ms); break;
    case GEO_LINESTRING_Z_M:		GEO_MP_COPY_PLINE(_.pline.Ms, 3, 1); GEO_RESET_CVECT(_.pline.Zs); GEO_RESET_MVECT(_.pline.Ms); break;
    case GEO_BOX:			GEO_MP_COPY_POINT(XYbox); break;
    case GEO_BOX_Z:			GEO_MP_COPY_POINT(_.point.point_ZMbox.Zmax); break;
    case GEO_BOX_M:			GEO_MP_COPY_POINT(_.point.point_ZMbox.Mmax); break;
    case GEO_BOX_Z_M:			GEO_MP_COPY_POINT(_.point.point_ZMbox.Mmax); break;
    case GEO_ARCSTRING:			GEO_MP_COPY_PLINE(_.pline.Ys, 2, 0); break;
    case GEO_GSOP:			GEO_MP_COPY_POINT(_.point.point_gs_precision); break;
    case GEO_RING:			GEO_MP_COPY_PLINE(_.pline.Ys, 2, 0); break;
    case GEO_RING_Z:			GEO_MP_COPY_PLINE(_.pline.pline_ZMbox.Zmax, 3, 0); GEO_RESET_CVECT(_.pline.Zs); break;
    case GEO_RING_M:			GEO_MP_COPY_PLINE(_.pline.Ms, 2, 1); GEO_RESET_MVECT(_.pline.Ms); break;
    case GEO_RING_Z_M:			GEO_MP_COPY_PLINE(_.pline.Ms, 3, 1); GEO_RESET_CVECT(_.pline.Zs); GEO_RESET_MVECT(_.pline.Ms); break;
    case GEO_POINTLIST:			GEO_MP_COPY_PLINE(_.pline.Ys, 2, 0);
    case GEO_POINTLIST_Z:		GEO_MP_COPY_PLINE(_.pline.pline_ZMbox.Zmax, 3, 0); GEO_RESET_CVECT(_.pline.Zs); break;
    case GEO_POINTLIST_M:		GEO_MP_COPY_PLINE(_.pline.Ms, 2, 1); GEO_RESET_MVECT(_.pline.Ms); break;
    case GEO_POINTLIST_Z_M:		GEO_MP_COPY_PLINE(_.pline.Ms, 3, 1); GEO_RESET_CVECT(_.pline.Zs); GEO_RESET_MVECT(_.pline.Ms); break;
    case GEO_MULTI_LINESTRING:		GEO_MP_COPY_PARTS(_.parts.items); break;
    case GEO_MULTI_LINESTRING_Z:	GEO_MP_COPY_PARTS(_.parts.parts_ZMbox.Zmax); break;
    case GEO_MULTI_LINESTRING_M:	GEO_MP_COPY_PARTS(_.parts.parts_ZMbox.Mmax); break;
    case GEO_MULTI_LINESTRING_Z_M:	GEO_MP_COPY_PARTS(_.parts.parts_ZMbox.Mmax); break;
    case GEO_POLYGON:			GEO_MP_COPY_PARTS(_.parts.items); break;
    case GEO_POLYGON_Z:			GEO_MP_COPY_PARTS(_.parts.parts_ZMbox.Zmax); break;
    case GEO_POLYGON_M:			GEO_MP_COPY_PARTS(_.parts.parts_ZMbox.Mmax); break;
    case GEO_POLYGON_Z_M:		GEO_MP_COPY_PARTS(_.parts.parts_ZMbox.Mmax); break;
    case GEO_MULTI_POLYGON:		GEO_MP_COPY_PARTS(_.parts.items); break;
    case GEO_MULTI_POLYGON_Z:		GEO_MP_COPY_PARTS(_.parts.parts_ZMbox.Zmax); break;
    case GEO_MULTI_POLYGON_M:		GEO_MP_COPY_PARTS(_.parts.parts_ZMbox.Mmax); break;
    case GEO_MULTI_POLYGON_Z_M:		GEO_MP_COPY_PARTS(_.parts.parts_ZMbox.Mmax); break;
    case GEO_COLLECTION:		GEO_MP_COPY_PARTS(_.parts.items); break;
    case GEO_COLLECTION_Z:		GEO_MP_COPY_PARTS(_.parts.parts_ZMbox.Zmax); break;
    case GEO_COLLECTION_M:		GEO_MP_COPY_PARTS(_.parts.parts_ZMbox.Mmax); break;
    case GEO_COLLECTION_Z_M:		GEO_MP_COPY_PARTS(_.parts.parts_ZMbox.Mmax); break;
    case GEO_CURVE:			GEO_MP_COPY_PARTS(_.parts.items); break;
    case GEO_CLOSEDCURVE:		GEO_MP_COPY_PARTS(_.parts.items); break;
    case GEO_CURVEPOLYGON:		GEO_MP_COPY_PARTS(_.parts.items); break;
    case GEO_MULTI_CURVE:		GEO_MP_COPY_PARTS(_.parts.items); break;
    default: GPF_T;
    }
  return res;
}

#undef GEO_MP_COPY_POINT
#undef GEO_MP_RESET_CVECT
#undef GEO_MP_RESET_MVECT
#undef GEO_MP_COPY_PLINE
#undef GEO_MP_COPY_PARTS

int
geo_destroy (geo_t *res)
{
  geo_t **iter, **begin;
  switch (GEO_TYPE (res->geo_flags))
    {
    case GEO_NULL_SHAPE:
    case GEO_POINT:
    case GEO_POINT_Z:
    case GEO_POINT_M:
    case GEO_POINT_Z_M:
    case GEO_LINESTRING:
    case GEO_LINESTRING_Z:
    case GEO_LINESTRING_M:
    case GEO_LINESTRING_Z_M:
    case GEO_BOX:
    case GEO_BOX_Z:
    case GEO_BOX_M:
    case GEO_BOX_Z_M:
    case GEO_ARCSTRING:
    case GEO_GSOP:
    case GEO_RING:
    case GEO_RING_Z:
    case GEO_RING_M:
    case GEO_RING_Z_M:
    case GEO_POINTLIST:
    case GEO_POINTLIST_Z:
    case GEO_POINTLIST_M:
    case GEO_POINTLIST_Z_M:
      return 0;
    case GEO_MULTI_LINESTRING:
    case GEO_MULTI_LINESTRING_Z:
    case GEO_MULTI_LINESTRING_M:
    case GEO_MULTI_LINESTRING_Z_M:
    case GEO_POLYGON:
    case GEO_POLYGON_Z:
    case GEO_POLYGON_M:
    case GEO_POLYGON_Z_M:
    case GEO_MULTI_POLYGON:
    case GEO_MULTI_POLYGON_Z:
    case GEO_MULTI_POLYGON_M:
    case GEO_MULTI_POLYGON_Z_M:
    case GEO_COLLECTION:
    case GEO_COLLECTION_Z:
    case GEO_COLLECTION_M:
    case GEO_COLLECTION_Z_M:
    case GEO_CURVE:
    case GEO_CLOSEDCURVE:
    case GEO_CURVEPOLYGON:
    case GEO_MULTI_CURVE:
      break;
    default: GPF_T;
    }
  begin = res->_.parts.items;
  for (iter = begin + res->_.parts.len; iter-- > begin; /*no step*/)
    dk_free_box ((caddr_t)(iter[0]));
  return 0;
}


#define dist_p_p(X1,Y1,X2,Y2) (sqrt (((X2)-(X1)) * ((X2)-(X1)) + ((Y2)-(Y1)) * ((Y2)-(Y1))))

void
geo_XYbox_of_arc (geoc beginX, geoc beginY, geoc midX, geoc midY, geoc endX, geoc endY,
    geoc * arc_Xmin, geoc * arc_Ymin, geoc * arc_Xmax, geoc * arc_Ymax)
{
  geoc aXmin, aYmin, aXmax, aYmax;
  geoc quarter1X, quarter1Y, dist_quarter1_mid;
  geoc quarter3X, quarter3Y, dist_quarter3_mid;
  quarter1X = (beginX + midX) / 2.0;
  quarter1Y = (beginY + midY) / 2.0;
  dist_quarter1_mid = dist_p_p (quarter1X, quarter1Y, midX, midY);
  quarter3X = (midX + endX) / 2.0;
  quarter3Y = (midY + endY) / 2.0;
  dist_quarter3_mid = dist_p_p (quarter3X, quarter3Y, midX, midY);
  aXmin = MIN (quarter1X - dist_quarter1_mid, quarter3X - dist_quarter3_mid);
  aYmin = MIN (quarter1Y - dist_quarter1_mid, quarter3Y - dist_quarter3_mid);
  aXmax = MAX (quarter1X + dist_quarter1_mid, quarter3X + dist_quarter3_mid);
  aYmax = MAX (quarter1Y + dist_quarter1_mid, quarter3Y + dist_quarter3_mid);
  arc_Xmin[0] = MIN (aXmin, MIN (beginX, endX));
  arc_Ymin[0] = MIN (aYmin, MIN (beginY, endY));
  arc_Xmax[0] = MAX (aXmax, MAX (beginX, endX));
  arc_Ymax[0] = MAX (aYmax, MAX (beginY, endY));
}

int
geo_long360add_pline_probe (geo_t * g, int *long_plustominus_count_ref, int *long_minustoplus_count_ref)
{
  int res = 0;
  int should_add = 0;
  geoc prevX = geoc_FARAWAY;
  int inx, len = g->_.pline.len;
  for (inx = 0; inx < len; inx++)
    {
      geoc X = g->_.pline.Xs[inx];
      if (geoc_FARAWAY == X)
	continue;
      if (X > 180.0)
	return res | GEO_LONG360ADD_NO_CHANGE | GEO_LONG360ADD_ALREADY_CHANGED;	/* Shifted already */
      if ((g->_.pline.Ys[inx] > 89.0) || (g->_.pline.Ys[inx] < -89.0))
	{
	  res |= GEO_LONG360ADD_POLE_PROXIMITY;
	  continue;		/* Circumpolar, no good idea how to shift, ignore at all. */
	}
      if (prevX != geoc_FARAWAY)
	{
	  if (X > prevX + 180.0)
	    {
	      if (!long_plustominus_count_ref[0])
		should_add = 1;	/* It means that wrapped polygon begins at its right side, so when adding phase starts it should begin to add before first long transition */
	      long_minustoplus_count_ref[0]++;
	      if (long_minustoplus_count_ref[0] > (long_plustominus_count_ref[0] + 1))
		res |= GEO_LONG360ADD_WEIRD;
	    }
	  else if (X < prevX - 180.0)
	    {
	      long_plustominus_count_ref[0]++;
	      if (long_plustominus_count_ref[0] > (long_minustoplus_count_ref[0] + 1))
		res |= GEO_LONG360ADD_WEIRD;
	    }
	}
      prevX = X;
    }
  if ((g->geo_flags & GEO_A_CLOSED) && (long_plustominus_count_ref[0] != long_minustoplus_count_ref[0]))
    return res | GEO_LONG360ADD_WEIRD;
  if (res & GEO_LONG360ADD_WEIRD)
    return res;
  if (should_add)
    res |= GEO_LONG360ADD_STARTS_AT_RIGHT;
  return res;
}

int
geo_long360add_pline_partial_shift (geo_t * g, int *do_shift_ref)
{
  geoc prevX = geoc_FARAWAY;
  int res = 0;
  int inx, len = g->_.pline.len;
  for (inx = 0; inx < len; inx++)
    {
      geoc X = g->_.pline.Xs[inx];
      if (geoc_FARAWAY == X)
	continue;
      if (X > 180.0)
	GPF_T1 ("geo_" "long360add_pline_partial_shift(): shift of shifted");
      if ((g->_.pline.Ys[inx] > 89.0) || (g->_.pline.Ys[inx] < -89.0))
	{
	  if (((g->_.pline.Ys[inx] == 90.0) || (g->_.pline.Ys[inx] == -90.0)) && (prevX != geoc_FARAWAY))
	    g->_.pline.Xs[inx] = prevX;	/* trying to improve bounding box :) */
	  continue;		/* Circumpolar, no good idea how to shift, ignore at all. */
	}
      if (prevX != geoc_FARAWAY)
	{
	  if (X >= prevX + 180.0)
	    do_shift_ref[0]--;
	  else if (X <= prevX - 180.0)
	    do_shift_ref[0]++;
	}
      if (do_shift_ref[0] > 0)
	{
	  g->_.pline.Xs[inx] = X + 360.0;
	  res |= GEO_LONG360ADD_SOME_CHANGED;
	}
      else
	res |= GEO_LONG360ADD_NO_CHANGE;
      prevX = X;
    }
  return res;
}

int
geo_long360add_pline_total_shift (geo_t * g)
{
  geoc prevX = geoc_FARAWAY;
  int inx;
  int res = 0;
  for (inx = g->_.pline.len; inx--; /* no step */ )
    {
      geoc X = g->_.pline.Xs[inx];
      if (geoc_FARAWAY == X)
	continue;
      if (X > 180.0)
	GPF_T1 ("geo_" "long360add_pline_total_shift(): shift of shifted");
      if ((g->_.pline.Ys[inx] > 89.0) || (g->_.pline.Ys[inx] < -89.0))
	{
	  if (((g->_.pline.Ys[inx] == 90.0) || (g->_.pline.Ys[inx] == -90.0)) && (prevX != geoc_FARAWAY))
	    g->_.pline.Xs[inx] = prevX + 360.0;	/* trying to improve bounding box :) */
	  continue;		/* Circumpolar, no good idea how to shift, ignore at all. */
	}
      g->_.pline.Xs[inx] = X + 360.0;
      res |= GEO_LONG360ADD_SOME_CHANGED;
      prevX = X;
    }
  return res;
}

int
geo_long360add (geo_t * g)
{
  switch (g->geo_flags)
    {
    case GEO_NULL_SHAPE:
      return GEO_LONG360ADD_NO_CHANGE | GEO_LONG360ADD_WEIRD;
    case GEO_POINT:
      if (g->XYbox.Xmax >= 180.0)
	return GEO_LONG360ADD_NO_CHANGE | GEO_LONG360ADD_ALREADY_CHANGED;
      g->XYbox.Xmin = g->XYbox.Xmax = g->XYbox.Xmax + 360.0;
      return GEO_LONG360ADD_SOME_CHANGED;
    case GEO_BOX:
      if (g->XYbox.Xmax >= 180.0)
	return GEO_LONG360ADD_NO_CHANGE;
      g->XYbox.Xmin += 360.0;
      g->XYbox.Xmax += 360.0;
      return GEO_LONG360ADD_SOME_CHANGED;
    case GEO_POINTLIST:
      {
	int res = 0;
	int inx = g->_.pline.len;
	while (inx--)
	  {
	    geoc X = g->_.pline.Xs[inx];
	    if (X >= 0.0)	/* BTW, this includes cases of (X > 180.0) and (geoc_FARAWAY == X) */
	      {
		res |= GEO_LONG360ADD_NO_CHANGE;
		continue;
	      }
	    g->_.pline.Xs[inx] += 360.0;
	    res |= GEO_LONG360ADD_SOME_CHANGED;
	  }
	return res;
      }
    case GEO_LINESTRING:
    case GEO_RING:
    case GEO_ARCSTRING:
    case (GEO_ARCSTRING | GEO_A_CLOSED):
      {
/* The processing consists of two phases.
First we check whether the polygon is weird or wrapped,
and if it is warpped then whether it begins from its right side.
Then we shift it, paying attention to the possible wrapping.
For a polygon, being weird is not necessarily an error, esp. if it clearly has circumpolar items */
	int long_plustominus_count = 0;
	int long_minustoplus_count = 0;
	int res = geo_long360add_pline_probe (g, &long_plustominus_count, &long_minustoplus_count);
	if (res & (GEO_LONG360ADD_WEIRD | GEO_LONG360ADD_ALREADY_CHANGED))
	  return res;
/* Phase 2 */
	if (long_plustominus_count || long_minustoplus_count)
	  {
	    int do_shift = (res & GEO_LONG360ADD_STARTS_AT_RIGHT) ? 1 : 0;
	    res |= geo_long360add_pline_partial_shift (g, &do_shift);
	  }
	else
	  res |= geo_long360add_pline_total_shift (g);
	return res;
      }
    case GEO_POLYGON:
    case GEO_CURVEPOLYGON:
      {
	int res, idx = g->_.parts.len;
	if (0 == idx)
	  return GEO_LONG360ADD_NO_CHANGE | GEO_LONG360ADD_WEIRD;
	res = geo_long360add (g->_.parts.items[0]);
	if (res & (GEO_LONG360ADD_WEIRD | GEO_LONG360ADD_ALREADY_CHANGED))
	  return res;
	if (!(res & GEO_LONG360ADD_SOME_CHANGED))
	  return res;
	while (--idx /* not idx-- */ )
	  {
	    res |= (geo_long360add (g->_.parts.items[idx]) & ~GEO_LONG360ADD_STARTS_AT_RIGHT);
	  }
	return res;
      }
    case GEO_CURVE:
    case GEO_CLOSEDCURVE:
      {
	int res, idx, len = g->_.parts.len;
	int long_plustominus_count = 0;
	int long_minustoplus_count = 0;
	if (0 == len)
	  return GEO_LONG360ADD_NO_CHANGE | GEO_LONG360ADD_WEIRD;
	res = geo_long360add_pline_probe (g->_.parts.items[0], &long_plustominus_count, &long_minustoplus_count);
	if (res & (GEO_LONG360ADD_WEIRD | GEO_LONG360ADD_ALREADY_CHANGED))
	  return res;
	for (idx = 1; idx < len; idx++)
	  {
	    res |=
		(geo_long360add_pline_probe (g->_.parts.items[idx], &long_plustominus_count,
		    &long_minustoplus_count) & ~GEO_LONG360ADD_STARTS_AT_RIGHT);;
	    if (res & (GEO_LONG360ADD_WEIRD | GEO_LONG360ADD_ALREADY_CHANGED))
	      return res;
	  }
	if (long_plustominus_count || long_minustoplus_count)
	  {
	    int do_shift = (res & GEO_LONG360ADD_STARTS_AT_RIGHT) ? 1 : 0;
	    for (idx = 0; idx < len; idx++)
	      res |= geo_long360add_pline_partial_shift (g->_.parts.items[idx], &do_shift);
	  }
	else
	  {
	    for (idx = 0; idx < len; idx++)
	      res |= geo_long360add_pline_total_shift (g->_.parts.items[idx]);
	  }
	return res;
      }
    case GEO_MULTI_POLYGON:
    case GEO_COLLECTION:
    case GEO_MULTI_LINESTRING:
    case GEO_MULTI_CURVE:
      {
	int res = 0;
	int already_changed_count = 0;
	int inx = g->_.parts.len;
	while (inx--)
	  {
	    int itmres;
	    geo_t *itm = g->_.parts.items[inx];
	    itmres = geo_long360add (itm);
	    res |= itmres & ~GEO_LONG360ADD_ALREADY_CHANGED;
	    if (itmres & GEO_LONG360ADD_ALREADY_CHANGED)
	      already_changed_count++;
	  }
	if (already_changed_count == g->_.parts.len)
	  res |= GEO_LONG360ADD_ALREADY_CHANGED;
	return res;
      }
    default:
      GPF_T;
    }
  return 0;
}

int
geo_calc_bounding_arc_should_shift (geo_t * g)
{
  geoc Xprev = geoc_FARAWAY;
  int inx = g->_.pline.len;
  while (inx--)
    {
      geoc X, Y;
      X = g->_.pline.Xs[inx];
      if (geoc_FARAWAY == X)
	continue;
      Y = g->_.pline.Ys[inx];
      if (X > 180.0)
	return GEO_LONG360ADD_NO_CHANGE | GEO_LONG360ADD_ALREADY_CHANGED;
      if ((Xprev != geoc_FARAWAY) && (Y <= 89.0) && (Y > -89.0) && (fabs (X - Xprev) > 180.0))
	return GEO_LONG360ADD_NEEDS_CHANGE;
    }
  return GEO_LONG360ADD_NO_CHANGE;
}

void
geo_calc_bounding_arc (geo_t * g)
{
  geoc Xmin, Ymin, Xmax, Ymax;
  geoc arc_Xmin, arc_Ymin, arc_Xmax, arc_Ymax;
  int inx, len = g->_.pline.len;
  if (g->geo_flags & GEO_A_CLOSED)
    {
      geo_XYbox_of_arc (g->_.pline.Xs[len - 2], g->_.pline.Ys[len - 2], g->_.pline.Xs[len - 1], g->_.pline.Ys[len - 1],
	  g->_.pline.Xs[0], g->_.pline.Ys[0], &Xmin, &Ymin, &Xmax, &Ymax);
      inx = len - 4;
    }
  else
    {
      geo_XYbox_of_arc (g->_.pline.Xs[len - 3], g->_.pline.Ys[len - 3], g->_.pline.Xs[len - 2], g->_.pline.Ys[len - 2],
	  g->_.pline.Xs[len - 1], g->_.pline.Ys[len - 1], &Xmin, &Ymin, &Xmax, &Ymax);
      inx = len - 5;
    }
  while (inx >= 0)
    {
      geo_XYbox_of_arc (g->_.pline.Xs[inx], g->_.pline.Ys[inx], g->_.pline.Xs[inx + 1], g->_.pline.Ys[inx + 1],
	  g->_.pline.Xs[inx + 2], g->_.pline.Ys[inx + 2], &arc_Xmin, &arc_Ymin, &arc_Xmax, &arc_Ymax);
      Xmin = MIN (Xmin, arc_Xmin);
      Xmax = MAX (Xmax, arc_Xmax);
      Ymin = MIN (Ymin, arc_Ymin);
      Ymax = MAX (Ymax, arc_Ymax);
      inx -= 2;
    }
  g->XYbox.Xmin = Xmin;
  g->XYbox.Ymin = Ymin;
  g->XYbox.Xmax = Xmax;
  g->XYbox.Ymax = Ymax;
}


int
geo_calc_bounding (geo_t * g, int flags)
{
  int res = 0;
  switch (GEO_TYPE_NO_ZM (g->geo_flags))
    {
    case GEO_POINT:
    case GEO_BOX:
      return GEO_LONG360ADD_NO_CHANGE;
    case GEO_POINTLIST:
      {
	geo_XYbox_t total_bbox, gcbbox, *gcb_ptr = NULL;
	int inx, len = g->_.pline.len;
	int gcb_next_stop;
	int gcb_step = ((g->geo_flags & GEO_IS_CHAINBOXED) ? MIN (len, g->_.pline.pline_gcb->gcb_step) : len);
	int has_midpoints = 0;
	int check_wraps = (flags & GEO_CALC_BOUNDING_MAY_SHIFT) && GEO_SR_WRAPS180 (g->geo_srcode);
      retry_pointlist_after_shifts:
	GEO_XYBOX_SET_EMPTY (total_bbox);
	if (g->geo_flags & GEO_IS_CHAINBOXED)
	  gcb_ptr = g->_.pline.pline_gcb->gcb_boxes;
	gcb_next_stop = gcb_step;
	inx = 0;
	for (;;)
	  {
	    GEO_XYBOX_SET_EMPTY (gcbbox);
	    for ( /* no init */ ; inx < gcb_next_stop; inx++)
	      {
		geoc X, Y;
		X = g->_.pline.Xs[inx];
		if (geoc_FARAWAY == X)
		  continue;
		Y = g->_.pline.Ys[inx];
		GEO_XYBOX_STRETCH_BY_POINT (gcbbox, X, Y);
		if (check_wraps)
		  {
		    if (X > 180.0)
		      {
			check_wraps = 0;
			res = GEO_LONG360ADD_NO_CHANGE | GEO_LONG360ADD_ALREADY_CHANGED;
		      }
		    else if ((X < 90.0) && (X > -90.0))
		      {
			has_midpoints = 1;
		      }
		  }
	      }
	    GEO_XYBOX_STRETCH_BY_XYBOX (total_bbox, gcbbox);
	    if (NULL != gcb_ptr)
	      {
#ifndef NDEBUG
		if (gcb_ptr >= g->_.pline.pline_gcb->gcb_boxes + g->_.pline.pline_gcb->gcb_box_count)
		  GPF_T1 ("pointlist out of pline_gcb->gcb_box_count");
#endif
		(gcb_ptr++)[0] = gcbbox;
	      }
	    if (inx >= len)
	      break;
	    gcb_next_stop += gcb_step;
	    if (gcb_next_stop > len)
	      gcb_next_stop = len;
	  }
	if (check_wraps && !has_midpoints && (total_bbox.Xmin < -90.0) && (total_bbox.Xmax > 90.0))
	  {
	    res |= geo_long360add (g);
	    check_wraps = 0;
	    goto retry_pointlist_after_shifts;	/* see above */
	  }
	GEO_XYBOX_COPY_NONEMPTY_OR_FARAWAY (g->XYbox, total_bbox);
	if (NULL != gcb_ptr)
	  g->_.pline.pline_gcb->gcb_is_set = 1;
	break;
      }
    case GEO_LINESTRING:
    case GEO_RING:
      {
	geo_XYbox_t total_bbox, gcbbox, *gcb_ptr = NULL;
	int inx, len = g->_.pline.len;
	int gcb_next_stop;
	int gcb_step = ((g->geo_flags & GEO_IS_CHAINBOXED) ? MIN ((len - 1), g->_.pline.pline_gcb->gcb_step) : (len - 1));
	int check_long_jumps = (flags & GEO_CALC_BOUNDING_MAY_SHIFT) && GEO_SR_WRAPS180 (g->geo_srcode);
	geoc Xprev = geoc_FARAWAY;
      retry_pline_after_shifts:
	GEO_XYBOX_SET_EMPTY (total_bbox);
	if (g->geo_flags & GEO_IS_CHAINBOXED)
	  gcb_ptr = g->_.pline.pline_gcb->gcb_boxes;
	gcb_next_stop = 1 + gcb_step;
	inx = 0;
	GEO_XYBOX_SET_EMPTY (gcbbox);
	for (;;)
	  {
	    geoc X = geoc_FARAWAY, Y;
	    for ( /* no init */ ; inx < gcb_next_stop; inx++)
	      {
		X = g->_.pline.Xs[inx];
		if (geoc_FARAWAY == X)
		  continue;
		Y = g->_.pline.Ys[inx];
		GEO_XYBOX_STRETCH_BY_POINT (gcbbox, X, Y);
		if (check_long_jumps)
		  {
		    if (X > 180.0)
		      {
			check_long_jumps = 0;
			res = GEO_LONG360ADD_NO_CHANGE | GEO_LONG360ADD_ALREADY_CHANGED;
		      }
		    else if ((Xprev != geoc_FARAWAY) && (Y <= 89.0) && (Y > -89.0) && (fabs (X - Xprev) > 180.0))
		      {
			res |= geo_long360add (g);
			check_long_jumps = 0;
			goto retry_pline_after_shifts;	/* see above */
		      }
		  }
		Xprev = X;
	      }
	    GEO_XYBOX_STRETCH_BY_XYBOX (total_bbox, gcbbox);
	    if (NULL != gcb_ptr)
	      {
#ifndef NDEBUG
		if (gcb_ptr >= g->_.pline.pline_gcb->gcb_boxes + g->_.pline.pline_gcb->gcb_box_count)
		  GPF_T1 ("pointlist out of pline_gcb->gcb_box_count");
#endif
		(gcb_ptr++)[0] = gcbbox;
	      }
	    if (inx >= len)
	      break;
	    gcb_next_stop += gcb_step;
	    if (gcb_next_stop > len)
	      gcb_next_stop = len;
	    GEO_XYBOX_SET_EMPTY (gcbbox);
	    if (X < geoc_FARAWAY)
	      GEO_XYBOX_SET_TO_POINT (gcbbox, X, Y);
	  }
	GEO_XYBOX_COPY_NONEMPTY_OR_FARAWAY (g->XYbox, total_bbox);
	if (NULL != gcb_ptr)
	  g->_.pline.pline_gcb->gcb_is_set = 1;
	break;
      }
    case GEO_ARCSTRING:
    case (GEO_ARCSTRING | GEO_A_CLOSED):
      {
	if ((flags & GEO_CALC_BOUNDING_MAY_SHIFT) && GEO_SR_WRAPS180 (g->geo_srcode))
	  {
	    int tmpres = geo_calc_bounding_arc_should_shift (g);
	    if (tmpres & GEO_LONG360ADD_NEEDS_CHANGE)
	      res |= geo_long360add (g);
	    else
	      res |= tmpres;
	  }
	geo_calc_bounding_arc (g);
	break;
      }
    case GEO_POLYGON:
    case GEO_CURVEPOLYGON:
      {
	geo_XYbox_t total_bbox, gcbbox, *gcb_ptr = NULL;
	int inx, len = g->_.parts.len;
	int gcb_next_stop;
	int gcb_step = ((g->geo_flags & GEO_IS_CHAINBOXED) ? MIN (len - 1, g->_.parts.parts_gcb->gcb_step) : (len - 1));
	geo_t *itm;
	if (len == 0)
	  {
	    GEO_XYBOX_SET_EMPTY (g->XYbox);
	    res |= GEO_LONG360ADD_WEIRD;
	    break;
	  }
	if (flags & GEO_CALC_BOUNDING_TRANSITIVE)
	  {
	    for (inx = 0; inx < len; inx++)
	      {
		itm = g->_.parts.items[inx];
		res |= geo_calc_bounding (itm, flags);
		if (res & GEO_LONG360ADD_SOME_CHANGED)
		  {
		    int inx2;
		    for (inx2 = 0; inx2 < inx; inx2++)
		      {
			itm = g->_.parts.items[inx2];
			res |= geo_long360add (itm);
		      }
		    for (inx2 = inx + 1; inx2 < len; inx2++)
		      {
			itm = g->_.parts.items[inx2];
			res |= geo_long360add (itm);
			res |= geo_calc_bounding (itm, flags);
		      }
		    break;
		  }
	      }
	  }
	itm = g->_.parts.items[0];
	total_bbox = itm->XYbox;
	if (g->geo_flags & GEO_IS_CHAINBOXED)
	  gcb_ptr = g->_.parts.parts_gcb->gcb_boxes;
	gcb_next_stop = 1 + gcb_step;
	inx = 1;
	for (;;)
	  {
	    GEO_XYBOX_SET_EMPTY (gcbbox);
	    for ( /* no init */ ; inx < gcb_next_stop; inx++)
	      {
		itm = g->_.parts.items[inx];
		if (flags & GEO_CALC_BOUNDING_TRANSITIVE)
		  geo_calc_bounding (itm, flags);
		if (geoc_FARAWAY == itm->XYbox.Xmin)
		  continue;
		GEO_XYBOX_STRETCH_BY_XYBOX (gcbbox, itm->XYbox);
	      }
	    GEO_XYBOX_STRETCH_BY_XYBOX (total_bbox, gcbbox);
	    if (NULL != gcb_ptr)
	      {
#ifndef NDEBUG
		if (gcb_ptr >= g->_.parts.parts_gcb->gcb_boxes + g->_.parts.parts_gcb->gcb_box_count)
		  GPF_T1 ("polygon out of parts_gcb->gcb_box_count");
#endif
		(gcb_ptr++)[0] = gcbbox;
	      }
	    if (inx >= len)
	      break;
	    gcb_next_stop += gcb_step;
	    if (gcb_next_stop > len)
	      gcb_next_stop = len;
	  }
	GEO_XYBOX_COPY_NONEMPTY_OR_FARAWAY (g->XYbox, total_bbox);
	if (NULL != gcb_ptr)
	  g->_.parts.parts_gcb->gcb_is_set = 1;
	break;
      }
    case GEO_CURVE:
    case GEO_CLOSEDCURVE:
      if ((flags & GEO_CALC_BOUNDING_MAY_SHIFT) && GEO_SR_WRAPS180 (g->geo_srcode))
	res |= geo_long360add (g);
      flags &= ~GEO_CALC_BOUNDING_MAY_SHIFT;
      /* no break */
    case GEO_MULTI_POLYGON:
    case GEO_COLLECTION:
    case GEO_MULTI_LINESTRING:
    case GEO_MULTI_CURVE:
      {
	geo_XYbox_t total_bbox, gcbbox, *gcb_ptr = NULL;
	int inx, len = g->_.parts.len;
	int gcb_next_stop;
	int gcb_step = ((g->geo_flags & GEO_IS_CHAINBOXED) ? MIN (len, g->_.parts.parts_gcb->gcb_step) : len);
	GEO_XYBOX_SET_EMPTY (total_bbox);
	if (g->geo_flags & GEO_IS_CHAINBOXED)
	  gcb_ptr = g->_.parts.parts_gcb->gcb_boxes;
	gcb_next_stop = gcb_step;
	inx = 0;
	for (;;)
	  {
	    GEO_XYBOX_SET_EMPTY (gcbbox);
	    for ( /* no init */ ; inx < gcb_next_stop; inx++)
	      {
		geo_t *itm = g->_.parts.items[inx];
		if (flags & GEO_CALC_BOUNDING_TRANSITIVE)
		  res |= geo_calc_bounding (itm, flags);
		if (geoc_FARAWAY == itm->XYbox.Xmin)
		  continue;
		GEO_XYBOX_STRETCH_BY_XYBOX (gcbbox, itm->XYbox);
	      }
	    GEO_XYBOX_STRETCH_BY_XYBOX (total_bbox, gcbbox);
	    if (NULL != gcb_ptr)
	      {
#ifndef NDEBUG
		if (gcb_ptr >= g->_.parts.parts_gcb->gcb_boxes + g->_.parts.parts_gcb->gcb_box_count)
		  GPF_T1 ("curve or multi or collection out of parts_gcb->gcb_box_count");
#endif
		(gcb_ptr++)[0] = gcbbox;
	      }
	    if (inx >= len)
	      break;
	    gcb_next_stop += gcb_step;
	    if (gcb_next_stop > len)
	      gcb_next_stop = len;
	  }
	GEO_XYBOX_COPY_NONEMPTY_OR_FARAWAY (g->XYbox, total_bbox);
	if (NULL != gcb_ptr)
	  g->_.parts.parts_gcb->gcb_is_set = 1;
	break;
      }
    default:
      GPF_T;
    }
  if (g->geo_flags & (GEO_A_Z | GEO_A_M))
    {
      geo_ZMbox_t bbox;
      switch (GEO_TYPE_NO_ZM (g->geo_flags))
	{
	  /* case GEO_POINT: case GEO_BOX: --- note the "return" above, in the first switch */
	case GEO_LINESTRING:
	case GEO_RING:
	case GEO_POINTLIST:
	case GEO_ARCSTRING:
	case GEO_ARCSTRING | GEO_A_CLOSED:
	  {
	    if (g->geo_flags & GEO_A_Z)
	      {
		int inx = g->_.pline.len;
		bbox.Zmin = geoc_FARAWAY;
		bbox.Zmax = -geoc_FARAWAY;
		while (inx--)
		  {
		    geoc c;
		    if (geoc_FARAWAY == g->_.pline.Xs[inx])
		      continue;
		    c = g->_.pline.Zs[inx];
		    bbox.Zmin = MIN (bbox.Zmin, c);
		    bbox.Zmax = MAX (bbox.Zmax, c);
		  }
		g->_.pline.pline_ZMbox.Zmin = bbox.Zmin;
		g->_.pline.pline_ZMbox.Zmax = bbox.Zmax;
	      }
	    if (g->geo_flags & GEO_A_M)
	      {
		int inx = g->_.pline.len;
		bbox.Mmin = geoc_FARAWAY;
		bbox.Mmax = -geoc_FARAWAY;
		while (inx--)
		  {
		    geoc c;
		    if (geoc_FARAWAY == g->_.pline.Xs[inx])
		      continue;
		    c = g->_.pline.Ms[inx];
		    bbox.Mmin = MIN (bbox.Mmin, c);
		    bbox.Mmax = MAX (bbox.Mmax, c);
		  }
		g->_.pline.pline_ZMbox.Mmin = bbox.Mmin;
		g->_.pline.pline_ZMbox.Mmax = bbox.Mmax;
	      }
	    break;
	  }
	case GEO_POLYGON:
	case GEO_MULTI_POLYGON:
	case GEO_COLLECTION:
	case GEO_CURVE:
	case GEO_CLOSEDCURVE:
	case GEO_CURVEPOLYGON:
	case GEO_MULTI_LINESTRING:
	case GEO_MULTI_CURVE:
	  {
	    int inx = g->_.parts.len;
	    bbox.Zmin = geoc_FARAWAY;
	    bbox.Zmax = -geoc_FARAWAY;
	    bbox.Mmin = geoc_FARAWAY;
	    bbox.Mmax = -geoc_FARAWAY;
	    while (inx--)
	      {
		geo_ZMbox_t *item_ZMbox;
		geo_t *itm = g->_.parts.items[inx];
		if (geoc_FARAWAY == g->XYbox.Xmin)
		  continue;
		item_ZMbox = geo_get_ZMbox_field (itm);
		if (g->geo_flags & GEO_A_Z)
		  {
		    bbox.Zmin = MIN (bbox.Zmin, item_ZMbox->Zmin);
		    bbox.Zmax = MAX (bbox.Zmax, item_ZMbox->Zmax);
		  }
		if (g->geo_flags & GEO_A_M)
		  {
		    bbox.Mmin = MIN (bbox.Mmin, item_ZMbox->Mmin);
		    bbox.Mmax = MAX (bbox.Mmax, item_ZMbox->Mmax);
		  }
	      }
	    if (g->geo_flags & GEO_A_Z)
	      {
		g->_.parts.parts_ZMbox.Zmin = bbox.Zmin;
		g->_.parts.parts_ZMbox.Zmax = bbox.Zmax;
	      }
	    if (g->geo_flags & GEO_A_M)
	      {
		g->_.parts.parts_ZMbox.Mmin = bbox.Mmin;
		g->_.parts.parts_ZMbox.Mmax = bbox.Mmax;
	      }
	    break;
	  }
	default:
	  GPF_T;
	}
    }
  return res;
}

geo_ZMbox_t *
geo_get_ZMbox_field (geo_t * g)
{
  switch (GEO_TYPE_NO_ZM (g->geo_flags))
    {
    case GEO_POINT:
    case GEO_BOX:
      return &(g->_.point.point_ZMbox);
    case GEO_LINESTRING:
    case GEO_RING:
    case GEO_POINTLIST:
    case GEO_ARCSTRING:
    case GEO_ARCSTRING | GEO_A_CLOSED:
      return &(g->_.pline.pline_ZMbox);
    case GEO_POLYGON:
    case GEO_MULTI_POLYGON:
    case GEO_MULTI_LINESTRING:
    case GEO_COLLECTION:
    case GEO_CURVE:
    case GEO_CLOSEDCURVE:
    case GEO_CURVEPOLYGON:
    case GEO_MULTI_CURVE:
      return &(g->_.parts.parts_ZMbox);
    }
  GPF_T;
  return NULL;			/* to keep the compiler happy */
}

void
geo_get_bounding_XYbox (geo_t * g, geo_t * box, geoc prec_x, geoc prec_y)
{
  box->geo_fill = 0;
  box->geo_flags = GEO_BOX;
  switch (GEO_TYPE_NO_ZM (g->geo_flags))
    {
    case GEO_POINT:
      if (geoc_FARAWAY == g->Xkey)
	goto faraway;		/* see below */
      box->XYbox.Xmin = g->Xkey;
      box->XYbox.Ymin = g->Ykey;
      box->XYbox.Xmax = g->Xkey;
      box->XYbox.Ymax = g->Ykey;
      if (prec_x || prec_y)
	{
	  if (GEO_SR_SPHEROID_DEGREES (g->geo_srcode))
	    {
	      double prec_rad = prec_y * KM_TO_DEG * DEG_TO_RAD;
	      double lat_r = g->Ykey * DEG_TO_RAD;
	      if (fabs ((M_PI / 2) - lat_r) < prec_rad)
		{
		  box->XYbox.Xmin = -180;
		  box->XYbox.Xmax = 180;
		}
	      else
		{
		  box->XYbox.Ymin -= prec_rad / DEG_TO_RAD;
		  box->XYbox.Ymax += prec_rad / DEG_TO_RAD;
		  prec_rad /= cos (lat_r);
		  box->XYbox.Xmin -= prec_rad / DEG_TO_RAD;
		  box->XYbox.Xmax += prec_rad / DEG_TO_RAD;
		}
	      goto adjust_with_epsilon;	/* see below */
	    }
	  break;
	}
      goto adjust_with_epsilon;	/* see below */
    case GEO_ARCSTRING:
    case GEO_CURVE:
    case GEO_CLOSEDCURVE:
    case GEO_CURVEPOLYGON:
    case GEO_MULTI_CURVE:
    case GEO_COLLECTION:
      prec_x *= 4;
      prec_y *= 4;		/* no break */
    default:
      if (geoc_FARAWAY == g->XYbox.Xmin)
	goto faraway;
      box->XYbox = g->XYbox;
      break;
    }
  box->XYbox.Xmin -= prec_x;
  box->XYbox.Ymin -= prec_y;
  box->XYbox.Xmax += prec_x;
  box->XYbox.Ymax += prec_y;

adjust_with_epsilon:
  box->XYbox.Xmin *= ((0 < box->XYbox.Xmin) ? (1 - FLT_EPSILON) : (1 + FLT_EPSILON));
  box->XYbox.Ymin *= ((0 < box->XYbox.Ymin) ? (1 - FLT_EPSILON) : (1 + FLT_EPSILON));
  box->XYbox.Xmax *= ((0 < box->XYbox.Xmax) ? (1 + FLT_EPSILON) : (1 - FLT_EPSILON));
  box->XYbox.Ymax *= ((0 < box->XYbox.Ymax) ? (1 + FLT_EPSILON) : (1 - FLT_EPSILON));
  return;

faraway:
  box->XYbox.Xmin = box->XYbox.Ymin = box->XYbox.Xmax = box->XYbox.Ymax = geoc_FARAWAY;
}

/* EWKT Reader */

typedef struct ewkt_input_s
{
  const unsigned char *ewkt_source;
  const unsigned char *ewkt_tail;
  int ewkt_row_no;
  const unsigned char *ewkt_row_begin;
  const char *ewkt_error;
  geo_srid_t ewkt_srid;
  geo_srcode_t ewkt_srcode;
  geoc *ekwt_Cs[4];
  int ekwt_point_count, ekwt_point_max;
  dk_set_t ekwt_cuts, ekwt_rings, ekwt_childs, ekwt_members;
  jmp_buf ewkt_error_ctx;
} ewkt_input_t;

#define ewkt_ws_skip(in) for (;;) { \
    switch ((in)->ewkt_tail[0]) { \
      case ' ': (in)->ewkt_tail++; continue; \
      case '\n': (in)->ewkt_tail++; if ('\r' == (in)->ewkt_tail[0]) (in)->ewkt_tail++; \
        (in)->ewkt_row_begin = (in)->ewkt_tail; (in)->ewkt_row_no++; continue; \
      case '\r': (in)->ewkt_tail++; if ('\n' == (in)->ewkt_tail[0]) (in)->ewkt_tail++; \
        (in)->ewkt_row_begin = (in)->ewkt_tail; (in)->ewkt_row_no++; continue; \
      default: break; \
      } \
    break; \
  }

#define EWKT_NUM		-1
#define EWKT_NUM_BAD		-2
#define EWKT_KWD_GEO_TYPE	-3
#define EWKT_KWD_MODIF		-4
#define EWKT_KWD_EXT		-5
#define EWKT_KWD_BAD		-6
#define EWKT_BAD		-7
#define EWKT_KWD_SRID		-10


typedef struct ewkt_kwd_metas_s
{
  const char *kwd_name;
  int kwd_dictserial;
  int kwd_type;
  int kwd_subtype;
  int kwd_parens_after;
  int kwd_min_nums;
  int kwd_max_nums;
  int kwd_is_alias;
} ewkt_kwd_metas_t;

typedef union ewkt_token_val_s
{
  geoc v_geoc;
  ewkt_kwd_metas_t *v_kwd;
} ewkt_token_val_t;

ewkt_kwd_metas_t ewkt_keyword_metas[] = {
/*  Name			| Serial| Type			| Subtype		| (...(	|minnums|maxnums|alias */
  {"BOX"			,  0	, EWKT_KWD_GEO_TYPE	, GEO_BOX		, 1	, 2	, 3	, 0	},
  {"BOX2D"			,  1	, EWKT_KWD_GEO_TYPE	, GEO_BOX		, 1	, 2	, 2	, 1	},
  {"BOX3D"			,  2	, EWKT_KWD_GEO_TYPE	, GEO_BOX_Z		, 1	, 3	, 3	, 0	},
  {"BOXM"			,  3	, EWKT_KWD_GEO_TYPE	, GEO_BOX_M		, 1	, 3	, 4	, 0	},
  {"BOXZ"			,  4	, EWKT_KWD_GEO_TYPE	, GEO_BOX_Z		, 1	, 3	, 4	, 1	},
  {"BOXZM"			,  5	, EWKT_KWD_GEO_TYPE	, GEO_BOX_Z_M		, 1	, 4	, 4	, 0	},
  {"CIRCULARSTRING"		,  6	, EWKT_KWD_GEO_TYPE	, GEO_ARCSTRING		, 1	, 2	, 2	, 0	},
  {"CIRCULARSTRINGM"		,  7	, EWKT_KWD_GEO_TYPE	, -1			, 1	, 2	, 2	, 0	},
  {"CIRCULARSTRINGZ"		,  8	, EWKT_KWD_GEO_TYPE	, -1			, 1	, 2	, 2	, 0	},
  {"CIRCULARSTRINGZM"		,  9	, EWKT_KWD_GEO_TYPE	, -1			, 1	, 2	, 2	, 0	},
  {"COMPOUNDCURVE"		, 10	, EWKT_KWD_GEO_TYPE	, GEO_CURVE		, 1	, 2	, 2	, 0	},
  {"COMPOUNDCURVEM"		, 11	, EWKT_KWD_GEO_TYPE	, -1			, 1	, 2	, 2	, 0	},
  {"COMPOUNDCURVEZ"		, 12	, EWKT_KWD_GEO_TYPE	, -1			, 1	, 2	, 2	, 0	},
  {"COMPOUNDCURVEZM"		, 13	, EWKT_KWD_GEO_TYPE	, -1			, 1	, 2	, 2	, 0	},
  {"CURVE"			, 14	, EWKT_KWD_GEO_TYPE	, -1			, 1	, 2	, 2	, 0	},
  {"CURVEM"			, 15	, EWKT_KWD_GEO_TYPE	, -1			, 1	, 2	, 2	, 0	},
  {"CURVEPOLYGON"		, 16	, EWKT_KWD_GEO_TYPE	, GEO_CURVEPOLYGON	, 2	, -1	, -1	, 0	},
  {"CURVEPOLYGONM"		, 17	, EWKT_KWD_GEO_TYPE	, -1			, 1	, 2	, 2	, 0	},
  {"CURVEPOLYGONZ"		, 18	, EWKT_KWD_GEO_TYPE	, -1			, 1	, 2	, 2	, 0	},
  {"CURVEPOLYGONZM"		, 19	, EWKT_KWD_GEO_TYPE	, -1			, 1	, 2	, 2	, 0	},
  {"CURVEZ"			, 20	, EWKT_KWD_GEO_TYPE	, -1			, 1	, 2	, 2	, 0	},
  {"CURVEZM"			, 21	, EWKT_KWD_GEO_TYPE	, -1			, 1	, 2	, 2	, 0	},
  {"EMPTY"			, 22	, EWKT_KWD_GEO_TYPE	, GEO_NULL_SHAPE	, 0	, 0	, 0	, 0	},
  {"GEOMETRYCOLLECTION"		, 23	, EWKT_KWD_GEO_TYPE	, GEO_COLLECTION	, -1	, -1	, -1	, 0	},
  {"GEOMETRYCOLLECTIONM"	, 24	, EWKT_KWD_GEO_TYPE	, GEO_COLLECTION_M	, -1	, -1	, -1	, 0	},
  {"GEOMETRYCOLLECTIONZ"	, 25	, EWKT_KWD_GEO_TYPE	, GEO_COLLECTION_Z	, -1	, -1	, -1	, 0	},
  {"GEOMETRYCOLLECTIONZM"	, 26	, EWKT_KWD_GEO_TYPE	, GEO_COLLECTION_Z_M	, -1	, -1	, -1	, 0	},
  {"GEOMETRY"			, 27	, EWKT_KWD_GEO_TYPE	, -1			, 1	, 2	, 2	, 0	},
  {"GEOMETRYZ"			, 28	, EWKT_KWD_GEO_TYPE	, -1			, 1	, 2	, 2	, 0	},
  {"GEOMETRYZM"			, 29	, EWKT_KWD_GEO_TYPE	, -1			, 1	, 2	, 2	, 0	},
  {"LINESTRING"			, 30	, EWKT_KWD_GEO_TYPE	, GEO_LINESTRING	, 1	, 2	, 3	, 0	},
  {"LINESTRINGM"		, 31	, EWKT_KWD_GEO_TYPE	, GEO_LINESTRING_M	, 1	, 3	, 4	, 0	},
  {"LINESTRINGZ"		, 32	, EWKT_KWD_GEO_TYPE	, GEO_LINESTRING_Z	, 1	, 3	, 4	, 0	},
  {"LINESTRINGZM"		, 33	, EWKT_KWD_GEO_TYPE	, GEO_LINESTRING_Z_M	, 1	, 4	, 4	, 0	},
  {"M"				, 34	, EWKT_KWD_MODIF	, GEO_A_M		, 0	, 0	, 0	, 0	},
  {"MULTICURVE"			, 35	, EWKT_KWD_GEO_TYPE	, GEO_MULTI_CURVE	, 2	, 2	, 2	, 0	},
  {"MULTICURVEM"		, 36	, EWKT_KWD_GEO_TYPE	, -1			, 1	, 2	, 2	, 0	},
  {"MULTICURVEZ"		, 37	, EWKT_KWD_GEO_TYPE	, -1			, 1	, 2	, 2	, 0	},
  {"MULTICURVEZM"		, 38	, EWKT_KWD_GEO_TYPE	, -1			, 1	, 2	, 2	, 0	},
  {"MULTILINESTRING"		, 39	, EWKT_KWD_GEO_TYPE	, GEO_MULTI_LINESTRING	, 2	, 2	, 3	, 0	},
  {"MULTILINESTRINGM"		, 40	, EWKT_KWD_GEO_TYPE	, GEO_MULTI_LINESTRING_M, 2	, 3	, 4	, 0	},
  {"MULTILINESTRINGZ"		, 41	, EWKT_KWD_GEO_TYPE	, GEO_MULTI_LINESTRING_Z, 2	, 3	, 4	, 0	},
  {"MULTILINESTRINGZM"		, 42	, EWKT_KWD_GEO_TYPE	, GEO_MULTI_LINESTRING_Z_M, 2	, 4	, 4	, 0	},
  {"MULTIPATCH"			, 43	, EWKT_KWD_GEO_TYPE	, -1			, 1	, 2	, 2	, 0	},
  {"MULTIPOINT"			, 44	, EWKT_KWD_GEO_TYPE	, GEO_POINTLIST		, 1	, 2	, 3	, 0	},
  {"MULTIPOINTM"		, 45	, EWKT_KWD_GEO_TYPE	, GEO_POINTLIST_M	, 1	, 3	, 4	, 0	},
  {"MULTIPOINTZ"		, 46	, EWKT_KWD_GEO_TYPE	, GEO_POINTLIST_Z	, 1	, 3	, 4	, 0	},
  {"MULTIPOINTZM"		, 47	, EWKT_KWD_GEO_TYPE	, GEO_POINTLIST_Z_M	, 1	, 4	, 4	, 0	},
  {"MULTIPOLYGON"		, 48	, EWKT_KWD_GEO_TYPE	, GEO_MULTI_POLYGON	, 3	, 2	, 3	, 0	},
  {"MULTIPOLYGONM"		, 49	, EWKT_KWD_GEO_TYPE	, GEO_MULTI_POLYGON_M	, 3	, 3	, 4	, 0	},
  {"MULTIPOLYGONZ"		, 50	, EWKT_KWD_GEO_TYPE	, GEO_MULTI_POLYGON_Z	, 3	, 3	, 4	, 0	},
  {"MULTIPOLYGONZM"		, 51	, EWKT_KWD_GEO_TYPE	, GEO_MULTI_POLYGON_Z_M	, 3	, 4	, 4	, 0	},
  {"MULTISURFACE"		, 52	, EWKT_KWD_GEO_TYPE	, -1			, 1	, 2	, 2	, 0	},
  {"MULTISURFACEM"		, 53	, EWKT_KWD_GEO_TYPE	, -1			, 1	, 2	, 2	, 0	},
  {"MULTISURFACEZ"		, 54	, EWKT_KWD_GEO_TYPE	, -1			, 1	, 2	, 2	, 0	},
  {"MULTISURFACEZM"		, 55	, EWKT_KWD_GEO_TYPE	, -1			, 1	, 2	, 2	, 0	},
  {"POINT"			, 56	, EWKT_KWD_GEO_TYPE	, GEO_POINT		, 1	, 2	, 3	, 0	},
  {"POINTM"			, 57	, EWKT_KWD_GEO_TYPE	, GEO_POINT_M		, 1	, 3	, 4	, 0	},
  {"POINTZ"			, 58	, EWKT_KWD_GEO_TYPE	, GEO_POINT_Z		, 1	, 3	, 4	, 0	},
  {"POINTZM"			, 59	, EWKT_KWD_GEO_TYPE	, GEO_POINT_Z_M		, 1	, 4	, 4	, 0	},
  {"POLYGON"			, 60	, EWKT_KWD_GEO_TYPE	, GEO_POLYGON		, 2	, 2	, 3	, 0	},
  {"POLYGONM"			, 61	, EWKT_KWD_GEO_TYPE	, GEO_POLYGON_M		, 2	, 3	, 4	, 0	},
  {"POLYGONZ"			, 62	, EWKT_KWD_GEO_TYPE	, GEO_POLYGON_Z		, 2	, 3	, 4	, 0	},
  {"POLYGONZM"			, 63	, EWKT_KWD_GEO_TYPE	, GEO_POLYGON_Z_M	, 2	, 4	, 4	, 0	},
  {"POLYHEDRALSURFACE"		, 64	, EWKT_KWD_GEO_TYPE	, -1			, 1	, 2	, 2	, 0	},
  {"POLYHEDRALSURFACEM"		, 65	, EWKT_KWD_GEO_TYPE	, -1			, 1	, 2	, 2	, 0	},
  {"POLYHEDRALSURFACEZ"		, 66	, EWKT_KWD_GEO_TYPE	, -1			, 1	, 2	, 2	, 0	},
  {"POLYHEDRALSURFACEZM"	, 67	, EWKT_KWD_GEO_TYPE	, -1			, 1	, 2	, 2	, 0	},
  {"POLYLINE"			, 68	, EWKT_KWD_GEO_TYPE	, GEO_MULTI_LINESTRING	, 2	, 2	, 3	, 1	},
  {"POLYLINEM"			, 69	, EWKT_KWD_GEO_TYPE	, -1			, 2	, 2	, 2	, 1	},
  {"POLYLINEZ"			, 70	, EWKT_KWD_GEO_TYPE	, GEO_MULTI_LINESTRING_Z, 2	, 3	, 3	, 1	},
  {"RING"			, 71	, EWKT_KWD_GEO_TYPE	, GEO_RING		, 1	, 2	, 3	, 0	},
  {"RINGM"			, 72	, EWKT_KWD_GEO_TYPE	, GEO_RING_M		, 1	, 3	, 4	, 0	},
  {"RINGZ"			, 73	, EWKT_KWD_GEO_TYPE	, GEO_RING_Z		, 1	, 3	, 4	, 0	},
  {"RINGZM"			, 74	, EWKT_KWD_GEO_TYPE	, GEO_RING_Z_M		, 1	, 4	, 4	, 0	},
  {"SRID"			, 75	, EWKT_KWD_EXT		, 0			, 0	, 0	, 0	, 0	},
  {"SURFACE"			, 76	, EWKT_KWD_GEO_TYPE	, -1			, 1	, 2	, 2	, 0	},
  {"SURFACEM"			, 77	, EWKT_KWD_GEO_TYPE	, -1			, 1	, 2	, 2	, 0	},
  {"SURFACEZ"			, 78	, EWKT_KWD_GEO_TYPE	, -1			, 1	, 2	, 2	, 0	},
  {"SURFACEZM"			, 79	, EWKT_KWD_GEO_TYPE	, -1			, 1	, 2	, 2	, 0	},
  {"TIN"			, 80	, EWKT_KWD_GEO_TYPE	, -1			, 1	, 2	, 2	, 0	},
  {"TINM"			, 81	, EWKT_KWD_GEO_TYPE	, -1			, 1	, 2	, 2	, 0	},
  {"TINZ"			, 82	, EWKT_KWD_GEO_TYPE	, -1			, 1	, 2	, 2	, 0	},
  {"TINZM"			, 83	, EWKT_KWD_GEO_TYPE	, -1			, 1	, 2	, 2	, 0	},
  {"Z"				, 84	, EWKT_KWD_MODIF	, GEO_A_Z		, 0	, 0	, 0	, 0	},
  {"ZM"				, 85	, EWKT_KWD_MODIF	, GEO_A_Z | GEO_A_M	, 0	, 0	, 0	, 0	} };

dk_hash_t *ewkt_geotype_metas = NULL;

ewkt_kwd_metas_t *
ewkt_find_metas_by_geotype (int geotype)
{
  if (NULL == ewkt_geotype_metas)
    {
      int metas_count = (sizeof (ewkt_keyword_metas) / sizeof (ewkt_keyword_metas[0]));
      ewkt_kwd_metas_t *ptr;
      ewkt_geotype_metas = hash_table_allocate (metas_count);
      for (ptr = ewkt_keyword_metas + metas_count; ptr > ewkt_keyword_metas; ptr--)
	{
	  ewkt_kwd_metas_t *old;
	  if (EWKT_KWD_GEO_TYPE != ptr->kwd_type)
	    continue;
	  if (0 > ptr->kwd_subtype)
	    continue;
	  old = gethash (((void *) ((ptrlong) (ptr->kwd_subtype))), ewkt_geotype_metas);
	  if (NULL != old)
	    {
	      if (ptr->kwd_is_alias)
		continue;
	      if (!old->kwd_is_alias)
		GPF_T;
	    }
	  sethash (((void *) ((ptrlong) (ptr->kwd_subtype))), ewkt_geotype_metas, ptr);
	}
    }
  return gethash (((void *) ((ptrlong) geotype)), ewkt_geotype_metas);
}

int
ewkt_get_token (ewkt_input_t * in, ewkt_token_val_t * val)
{
  int res;
  switch (in->ewkt_tail[0])
    {
    case '(':
    case ')':
    case ',':
    case ';':
    case '=':
      res = (in->ewkt_tail++)[0];
      break;
    case '\0':
      return 0;
    case '+':
    case '-':
    case '.':
    case '0':
    case '1':
    case '2':
    case '3':
    case '4':
    case '5':
    case '6':
    case '7':
    case '8':
    case '9':
      {
	const unsigned char *endptr = NULL;
	val->v_geoc = strtod ((const char *) (in->ewkt_tail), (char **) (&endptr));
	if ((NULL != endptr) && (in->ewkt_tail != endptr))
	  {
	    res = EWKT_NUM;
	    in->ewkt_tail = endptr;
	    break;
	  }
	res = EWKT_NUM_BAD;
	break;
      }
    default:
      if (isalpha (in->ewkt_tail[0]))
	{
	  int metas_inx;
	  ewkt_kwd_metas_t *metas;
	  char buf[30];
	  char *buf_tail = buf;
	  do
	    {
	      (buf_tail++)[0] = (in->ewkt_tail++)[0];
	    }
	  while (isalpha (in->ewkt_tail[0]) && buf_tail < buf + sizeof (buf) - 1);
	  buf_tail[0] = '\0';
	  metas_inx =
	      ecm_find_name (buf, ewkt_keyword_metas, sizeof (ewkt_keyword_metas) / sizeof (ewkt_kwd_metas_t),
	      sizeof (ewkt_kwd_metas_t));
	  if (ECM_MEM_NOT_FOUND == metas_inx)
	    {
	      val->v_kwd = NULL;
	      res = EWKT_KWD_BAD;
	      break;
	    }
	  metas = ewkt_keyword_metas + metas_inx;
	  val->v_kwd = metas;
	  res = metas->kwd_type;
	  break;
	}
      val->v_kwd = NULL;
      return EWKT_BAD;
    }
  ewkt_ws_skip (in);
  return res;
}

void
ewkt_signal (ewkt_input_t * in, const char *error)
{
  in->ewkt_error = error;
  longjmp (in->ewkt_error_ctx, 1);
}

void
ewkt_expect_token (ewkt_input_t * in, int expected)
{
  ewkt_token_val_t val;
  int tkn = ewkt_get_token (in, &val);
  if (tkn != expected)
    ewkt_signal (in, "Syntax error");
}

int
ewkt_get_points (ewkt_input_t * in, ewkt_kwd_metas_t * head_metas)
{
  int coretype = GEO_TYPE_CORE (head_metas->kwd_subtype);
  int tkn, dim = 0, dim_idx = 0;
  int lpar_before_point = 0;
  ewkt_token_val_t val;
  in->ekwt_point_count = 0;
  for (;;)
    {
      if (in->ekwt_point_count >= in->ekwt_point_max)
	{
	  int dctr;
	  int old_len = in->ekwt_point_max;
	  int new_len = 8 + old_len * 2;
	  for (dctr = 4; dctr--; /* no step */ )
	    {
	      geoc *new_buf = (geoc *) dk_alloc (new_len * sizeof (geoc));
	      if (old_len)
		{
		  memcpy (new_buf, in->ekwt_Cs[dctr], old_len * sizeof (geoc));
		  dk_free ((void *) (in->ekwt_Cs[dctr]), old_len * sizeof (geoc));
		}
	      in->ekwt_Cs[dctr] = new_buf;
	    }
	  in->ekwt_point_max = new_len;
	}
      for (;;)
	{
	  tkn = ewkt_get_token (in, &val);
	  if (0 == tkn)
	    ewkt_signal (in, "Unexpected end of WKT text inside list of coordinates");
	  switch (tkn)
	    {
	    case EWKT_NUM:
	      if (3 < dim_idx)
		ewkt_signal (in, "Too many coordinates are listed for a point");
	      if (dim_idx >= head_metas->kwd_max_nums)
		ewkt_signal (in, "The point has more coordinates than permitted by the spatial type");
	      in->ekwt_Cs[dim_idx++][in->ekwt_point_count] = val.v_geoc;
	      continue;
	    case EWKT_NUM_BAD:
	      ewkt_signal (in, "Syntax error in numeric value");
	      break;
	    case EWKT_KWD_GEO_TYPE:
	      if (GEO_NULL_SHAPE != val.v_kwd->kwd_subtype)
		ewkt_signal (in, "Coordinates or EMPTY keyword are expected for a point");
	      if (0 < dim_idx)
		ewkt_signal (in, "EMPTY keyword can not be mixed with other coordinates of the point");
	      if ((GEO_LINESTRING == coretype) || (GEO_ARCSTRING == coretype))
		ewkt_signal (in, "EMPTY coordinates can be assigned to a point, but not to vertex of a LINE- or ARC-string.");
	      in->ekwt_Cs[0][in->ekwt_point_count] =
		  in->ekwt_Cs[1][in->ekwt_point_count] =
		  in->ekwt_Cs[2][in->ekwt_point_count] = in->ekwt_Cs[3][in->ekwt_point_count] = geoc_FARAWAY;
	      dim_idx = 0xFF;
	      continue;
	    case '(':
	      if (0 != dim_idx)
		ewkt_signal (in, "Unexpected '(' in the middle of a point");
	      if (lpar_before_point)
		ewkt_signal (in, "Too many '(' before coordinates of a point");
	      lpar_before_point = 1;
	      continue;
	    case ')':
	      if (!lpar_before_point)
		break;
	      lpar_before_point = 0;
	      continue;
	    case ',':
	      if (lpar_before_point)
		ewkt_signal (in, "Unexpected ',' in the middle of a point, the point begins with '(' but not ended with ')'");
	      break;
	    }
	  if (0xFF != dim_idx)
	    {
	      if (dim_idx < head_metas->kwd_min_nums)
		ewkt_signal (in, "The point has less coordinates than permitted by the spatial type");
	      if ((0 == in->ekwt_point_count) || (0 == dim))
		dim = dim_idx;
	      else if (dim != dim_idx)
		ewkt_signal (in, "Points of one list differ in number of coordinates");
	    }
	  in->ekwt_point_count++;
	  dim_idx = 0;
	  if (',' == tkn)
	    break;
	  if (')' == tkn)
	    {
	      if (!dim)
		{
		  if (1 < in->ekwt_point_count)
		    ewkt_signal (in, "Points with unspecified coordinates are not allowed");
		  in->ekwt_point_count = 0;
		}
	      return dim;
	    }
	  ewkt_signal (in, "Syntax error in the list of points");
	}
    }
  if (GEO_ARCSTRING == coretype)
    {
      int p_idx;
      if (1 != (in->ekwt_point_count % 2))
	ewkt_signal (in, "Wrong number of points in ARCSTRING, should be odd");
      for (p_idx = in->ekwt_point_count; --p_idx > 0; /* no step */ )
	{
	  if ((fabs (in->ekwt_Cs[0][p_idx - 1] - in->ekwt_Cs[0][p_idx]) +
		  fabs (in->ekwt_Cs[1][p_idx - 1] - in->ekwt_Cs[1][p_idx])) <= 2 * FLT_EPSILON)
	    ewkt_signal (in, "Neighbor points of an ARCSTRING are too close to each other");
	}
    }
  if (head_metas->kwd_subtype & GEO_A_CLOSED)
    {
      if (2 >= in->ekwt_point_count)
	ewkt_signal (in, "Closed ring contains too few points");
      for (dim_idx = dim; dim_idx--; /* no step */ )
	{
	  if (fabs (in->ekwt_Cs[dim_idx][in->ekwt_point_count - 1] - in->ekwt_Cs[dim_idx][0]) >= FLT_EPSILON)
	    ewkt_signal (in, "The distance between ends of a closed ring is too big");
	}
    }
}

int
ewkt_get_pointstrings (ewkt_input_t * in, ewkt_kwd_metas_t * head_metas, int sub_itm_type, dk_set_t * items)
{
  ewkt_kwd_metas_t *sub_metas = ewkt_find_metas_by_geotype (sub_itm_type);
  for (;;)
    {
      geo_t *itm;
      int dim, curr_itm_type = sub_itm_type;
      int tkn;
      int dim_ctr = 0;
      ewkt_token_val_t val;
      if (NULL == sub_metas)
	GPF_T;
      tkn = ewkt_get_token (in, &val);
      if (EWKT_KWD_GEO_TYPE == tkn)
	{
	  if (GEO_NULL_SHAPE != val.v_kwd->kwd_subtype)
	    ewkt_signal (in, "List of points or EMPTY keyword is expected");
	  itm = geo_alloc (sub_itm_type, 0, in->ewkt_srcode);
	  goto itm_done;	/* see below */
	}
      dim = ewkt_get_points (in, sub_metas);
      if (4 == dim)
	curr_itm_type |= GEO_A_Z | GEO_A_M;
      else if ((3 == dim) && !(sub_itm_type & (GEO_A_Z | GEO_A_M)))
	curr_itm_type |= GEO_A_Z;
      if (sub_itm_type != curr_itm_type)
	{
	  if (NULL == items[0])
	    {
	      sub_metas = ewkt_find_metas_by_geotype (curr_itm_type);
	      if (NULL == sub_metas)
		GPF_T;
	    }
	  else
	    ewkt_signal (in, "Fragments of MULTIfeature differ in number of coordinates");
	}
      itm = geo_alloc (sub_itm_type, in->ekwt_point_count, in->ewkt_srcode);
      memcpy (itm->_.pline.Xs, in->ekwt_Cs[dim_ctr++], sizeof (geoc) * in->ekwt_point_count);
      memcpy (itm->_.pline.Ys, in->ekwt_Cs[dim_ctr++], sizeof (geoc) * in->ekwt_point_count);
      if (GEO_A_Z & sub_itm_type)
	memcpy (itm->_.pline.Zs, in->ekwt_Cs[dim_ctr++], sizeof (geoc) * in->ekwt_point_count);
      if (GEO_A_M & sub_itm_type)
	memcpy (itm->_.pline.Ms, in->ekwt_Cs[dim_ctr++], sizeof (geoc) * in->ekwt_point_count);
    itm_done:
      dk_set_push (items, itm);
      tkn = ewkt_get_token (in, &val);
      if (',' == tkn)
	continue;
      if (')' == tkn)
	return sub_itm_type;
      ewkt_signal (in, "Syntax error in a uniform list of lists of points");
    }
}

geo_t *
ewkt_get_nested_poinstrings (ewkt_input_t * in, ewkt_kwd_metas_t * head_metas, int geo_type, int nesting)
{
  geo_t *res;
  int sub_itm_type = geo_type, new_sub_itm_type, itm_ctr;
  dk_set_t *items;
  if (geo_type & GEO_A_MULTI)
    {
      items = &(in->ekwt_childs);
      sub_itm_type &= ~GEO_A_MULTI;
    }
  else if (geo_type & GEO_A_RINGS)
    {
      items = &(in->ekwt_rings);
      sub_itm_type &= ~GEO_A_RINGS;
    }
  else
    ewkt_signal (in, "Internal error: bad metadata");
  if (NULL != items[0])
    ewkt_signal (in, "Invalid nesting of spatial features inside one spatial object");
  if (2 < nesting)
    {
      for (;;)
	{
	  geo_t *itm;
	  int tkn;
	  ewkt_token_val_t val;
	  tkn = ewkt_get_token (in, &val);
	  if (')' == tkn)
	    {
	      if (NULL == items[0])
		ewkt_signal (in, "Empty list of spatial features");
	      else
		ewkt_signal (in, "Missing spatial feature after ','");
	    }
	  if (EWKT_KWD_GEO_TYPE == tkn)
	    {
	      if (GEO_NULL_SHAPE != val.v_kwd->kwd_subtype)
		ewkt_signal (in, "Coordinates expected, not a type of a spatial features");
	      itm = geo_alloc (sub_itm_type, 0, in->ewkt_srcode);
	    }
	  else
	    itm = ewkt_get_nested_poinstrings (in, head_metas, sub_itm_type, nesting - 1);
	  dk_set_push (items, itm);
	  if (NULL == items[0]->next)
	    sub_itm_type = itm->geo_flags;
	  else if (sub_itm_type != itm->geo_flags)
	    ewkt_signal (in, "Fragments of MULTIfeature differ in number of coordinates");
	  if ((geo_type & (GEO_A_Z | GEO_A_M)) != (itm->geo_flags & (GEO_A_Z | GEO_A_M)))
	    ewkt_signal (in, "Dimension of spatial feature does not match dimention of containing spatial object");
	  tkn = ewkt_get_token (in, &val);
	  if (',' == tkn)
	    continue;
	  if (')' == tkn)
	    break;
	  ewkt_signal (in, "Syntax error in list of spatial features, ',' or ')' expected");
	}
    }
  else
    {
      new_sub_itm_type = ewkt_get_pointstrings (in, head_metas, sub_itm_type, items);
      geo_type |= (new_sub_itm_type & (GEO_A_Z | GEO_A_M));
    }
  itm_ctr = dk_set_length (items[0]);
  res = geo_alloc (geo_type, itm_ctr, in->ewkt_srcode);
  while (itm_ctr--)
    res->_.parts.items[itm_ctr] = (geo_t *) dk_set_pop (items);
  return res;
}

geo_t *
ewkt_get_one (ewkt_input_t * in, ewkt_kwd_metas_t * head_metas)
{
  int geo_type = head_metas->kwd_subtype;
  int geo_main_type = geo_type & ~(GEO_A_Z | GEO_A_M);
  int next_tkn;
  ewkt_token_val_t next_val;
  if (0 == head_metas->kwd_parens_after)
    {
      geo_t *res;
      res = geo_alloc (geo_type, 0, in->ewkt_srcode);
      return res;
    }
  next_tkn = ewkt_get_token (in, &next_val);
  if (EWKT_KWD_MODIF == next_tkn)
    {
      ewkt_kwd_metas_t *changed_metas;
      if (geo_type & next_val.v_kwd->kwd_subtype)
	ewkt_signal (in, "Redundand Z/M type modifier");
      geo_type |= next_val.v_kwd->kwd_subtype;
      changed_metas = ewkt_find_metas_by_geotype (geo_type);
      if (NULL == changed_metas)
	ewkt_signal (in, "The Z/M type modifier is not applicable to the mentioned type of spatial feature");
      head_metas = changed_metas;
      next_tkn = ewkt_get_token (in, &next_val);
    }
  if ((EWKT_KWD_GEO_TYPE == next_tkn) && (GEO_NULL_SHAPE == next_val.v_kwd->kwd_subtype))
    {
      geo_t *res = geo_alloc (geo_type, 0, in->ewkt_srcode);
      if ((GEO_POINT == geo_main_type) || (GEO_BOX == geo_main_type))
	{
	  res->XYbox.Xmin = res->XYbox.Xmax = res->XYbox.Ymin = res->XYbox.Ymax = geoc_FARAWAY;
	  if (GEO_A_Z & geo_type)
	    res->_.point.point_ZMbox.Zmin = res->_.point.point_ZMbox.Zmax = geoc_FARAWAY;
	  if (GEO_A_M & geo_type)
	    res->_.point.point_ZMbox.Mmin = res->_.point.point_ZMbox.Mmax = geoc_FARAWAY;
	}
      return res;
    }
  if ('(' != next_tkn)
    ewkt_signal (in, "One of following is expected after geo type name: a left parenthesis, an EMPTY keyword, a Z/M type modifier");
  if (2 <= head_metas->kwd_parens_after)
    return ewkt_get_nested_poinstrings (in, head_metas, geo_type, head_metas->kwd_parens_after);
  if (1 == head_metas->kwd_parens_after)
    {
      geo_t *res;
      int dims = ewkt_get_points (in, head_metas);
      int dim_ctr = 0;
      if (4 == dims)
	geo_type |= GEO_A_Z | GEO_A_M;
      else if ((3 == dims) && !(geo_type & (GEO_A_Z | GEO_A_M)))
	geo_type |= GEO_A_Z;
      if (GEO_POINT == geo_main_type)
	{
	  res = geo_alloc (geo_type, 0, in->ewkt_srcode);
	  if (1 != in->ekwt_point_count)
	    ewkt_signal (in, "POINT should have only one set of coordinates");
	  res->XYbox.Xmin = res->XYbox.Xmax = in->ekwt_Cs[dim_ctr++][0];
	  res->XYbox.Ymin = res->XYbox.Ymax = in->ekwt_Cs[dim_ctr++][0];
	  if (GEO_A_Z & geo_type)
	    res->_.point.point_ZMbox.Zmin = res->_.point.point_ZMbox.Zmax = in->ekwt_Cs[dim_ctr++][0];
	  if (GEO_A_M & geo_type)
	    res->_.point.point_ZMbox.Mmin = res->_.point.point_ZMbox.Mmax = in->ekwt_Cs[dim_ctr++][0];
	  return res;
	}
      if (GEO_BOX == geo_main_type)
	{
	  res = geo_alloc (geo_type, 0, in->ewkt_srcode);
	  if (2 != in->ekwt_point_count)
	    ewkt_signal (in, "BOX should have only two sets of coordinates");
	  res->XYbox.Xmin = in->ekwt_Cs[dim_ctr][0];
	  res->XYbox.Xmax = in->ekwt_Cs[dim_ctr++][0];
	  res->XYbox.Ymin = in->ekwt_Cs[dim_ctr][0];
	  res->XYbox.Ymax = in->ekwt_Cs[dim_ctr++][0];
	  if (GEO_A_Z & geo_type)
	    {
	      res->_.point.point_ZMbox.Zmin = in->ekwt_Cs[dim_ctr][0];
	      res->_.point.point_ZMbox.Zmax = in->ekwt_Cs[dim_ctr++][0];
	    }
	  if (GEO_A_M & geo_type)
	    {
	      res->_.point.point_ZMbox.Mmin = in->ekwt_Cs[dim_ctr][0];
	      res->_.point.point_ZMbox.Mmax = in->ekwt_Cs[dim_ctr++][0];
	    }
	  return res;
	}
      res = geo_alloc (geo_type, in->ekwt_point_count, in->ewkt_srcode);
      memcpy (res->_.pline.Xs, in->ekwt_Cs[dim_ctr++], sizeof (geoc) * in->ekwt_point_count);
      memcpy (res->_.pline.Ys, in->ekwt_Cs[dim_ctr++], sizeof (geoc) * in->ekwt_point_count);
      if (GEO_A_Z & geo_type)
	memcpy (res->_.pline.Zs, in->ekwt_Cs[dim_ctr++], sizeof (geoc) * in->ekwt_point_count);
      if (GEO_A_M & geo_type)
	memcpy (res->_.pline.Ms, in->ekwt_Cs[dim_ctr++], sizeof (geoc) * in->ekwt_point_count);
      return res;
    }
  if (-1 == head_metas->kwd_parens_after)
    {
      geo_t *res;
      dk_set_t *items;
      int itm_ctr;
      if (geo_type & GEO_A_COMPOUND)
	items = &(in->ekwt_cuts);
      else if (geo_type & GEO_A_MULTI)
	items = &(in->ekwt_childs);
      else if (geo_type & GEO_A_RINGS)
	items = &(in->ekwt_rings);
      else if (GEO_COLLECTION == geo_main_type)
	items = &(in->ekwt_members);
      else
	ewkt_signal (in, "Internal error: bad metadata");
      if (NULL != items[0])
	ewkt_signal (in, "Invalid nesting of spatial features inside one spatial object");
      for (;;)
	{
	  geo_t *itm;
	  int subhead_tkn, itm_geo_type, itm_geo_main_type;
	  ewkt_token_val_t subhead_val;
	  subhead_tkn = ewkt_get_token (in, &subhead_val);
	  if (')' == subhead_tkn)
	    {
	      if (NULL != items[0])
		ewkt_signal (in, "Empty list of spatial features");
	      else
		ewkt_signal (in, "Missing spatial feature after ','");
	    }
	  if (EWKT_KWD_GEO_TYPE != subhead_tkn)
	    ewkt_signal (in, "Syntax error in list of spatial features, feature type expected");
	  itm_geo_type = subhead_val.v_kwd->kwd_subtype;
	  itm_geo_main_type = itm_geo_type & ~(GEO_A_Z | GEO_A_M);
	  if (geo_type & GEO_A_COMPOUND)
	    {
	      if ((GEO_LINESTRING != itm_geo_main_type) && (GEO_ARCSTRING != itm_geo_main_type))
		ewkt_signal (in, "Compound curve can contain only LINESTRINGs and ARCSTRINGs");
	    }
	  else if (geo_type & GEO_A_MULTI)
	    {
	      if (itm_geo_main_type != (geo_main_type & ~GEO_A_MULTI))
		ewkt_signal (in, "Spatial MULTI-entity contains an entity of mismatching type");
	    }
	  else if (GEO_COLLECTION == geo_main_type)
	    {
	      if (GEO_COLLECTION == itm_geo_main_type)
		ewkt_signal (in, "COLLECTION is nested into other COLLECTION");
	    }
	  itm = ewkt_get_one (in, subhead_val.v_kwd);
	  dk_set_push (items, itm);
	  if ((geo_type & (GEO_A_Z | GEO_A_M)) != (itm->geo_flags & (GEO_A_Z | GEO_A_M)))
	    ewkt_signal (in, "Dimension of spatial feature does not match dimention of containing spatial object");
	  subhead_tkn = ewkt_get_token (in, &subhead_val);
	  if (',' == subhead_tkn)
	    continue;
	  if (')' == subhead_tkn)
	    break;
	  ewkt_signal (in, "Syntax error in list of spatial features, ',' or ')' expected");
	}
      itm_ctr = dk_set_length (items[0]);
      res = geo_alloc (geo_type, itm_ctr, in->ewkt_srcode);
      while (NULL != (res->_.parts.items[--itm_ctr] = (geo_t *) dk_set_pop (items))) /* empty body */ ;
      return res;
    }
  ewkt_signal (in, "Internal error");
  return NULL;			/* never happens */
}

geo_t *
ewkt_parse (const char *strg, caddr_t * err_ret)
{
  geo_t *res;
  ewkt_input_t in;
  int tkn;
  ewkt_token_val_t val;
  memset (&in, 0, sizeof (ewkt_input_t));
  in.ewkt_srid = SRID_DEFAULT;
  in.ewkt_srcode = GEO_SRCODE_DEFAULT;
  in.ewkt_source = in.ewkt_tail = in.ewkt_row_begin = (const unsigned char *) strg;
  if (0 == setjmp (in.ewkt_error_ctx))
    {
      ewkt_ws_skip (&in);
      tkn = ewkt_get_token (&in, &val);
      while (EWKT_KWD_EXT == tkn)
	{
	  if (EWKT_KWD_SRID == val.v_kwd->kwd_subtype)
	    {
	      ewkt_expect_token (&in, '=');
	      tkn = ewkt_get_token (&in, &val);
	      if (EWKT_NUM != tkn)
		ewkt_signal (&in, "SRID identification number is expected");
	      if ((val.v_geoc != floor (val.v_geoc)) || (0 >= val.v_geoc))
		ewkt_signal (&in, "Invalid SRID identification number");
	      in.ewkt_srid = val.v_geoc;
	      in.ewkt_srcode = GEO_SRCODE_OF_SRID (in.ewkt_srid);
	      ewkt_expect_token (&in, ';');
	    }
	  else
	    ewkt_signal (&in, "Unsupported EWKT extension");
	  tkn = ewkt_get_token (&in, &val);
	}
      if (EWKT_KWD_GEO_TYPE != tkn)
	ewkt_signal (&in, "Valid type of spatial feature is expected");
      if (0 > val.v_kwd->kwd_subtype)
	ewkt_signal (&in, "Unsupported type of spatial feature");
      res = ewkt_get_one (&in, val.v_kwd);
      ewkt_expect_token (&in, 0);	/* no garbage characters should remain after the text of the shape */
    }
  else
    {
      if (err_ret != NULL)
	err_ret[0] = srv_make_new_error ("22023", "GEO11", "%s (near row %d col %d of '%.200s')",
	    in.ewkt_error, 1 + in.ewkt_row_no, (int) (1 + (in.ewkt_tail - in.ewkt_row_begin)), strg);
      res = NULL;
    }
  return res;
}

/* EWKT printer */

void
ewkt_print_sf12_points (dk_session_t * ses, int geo_flags, int pcount, geoc * Xs, geoc * Ys, geoc * Zs, geo_measure_t * Ms)
{
  int inx;
  if (0 == pcount)
    {
      SES_PRINT (ses, " EMPTY");
      return;
    }
  SES_PRINT (ses, "(");
  for (inx = 0; inx < pcount; inx++)
    {
      char buf[2000];
      if (inx)
	SES_PRINT (ses, ",");
      if (geoc_FARAWAY == Xs[inx])
	SES_PRINT (ses, "EMPTY");
      else
	{
	  sprintf (buf, "%lf %lf", Xs[inx], Ys[inx]);
	  SES_PRINT (ses, buf);
	  if (geo_flags & GEO_A_Z)
	    {
	      sprintf (buf, " %lf", Zs[inx]);
	      SES_PRINT (ses, buf);
	    }
	  if (geo_flags & GEO_A_M)
	    {
	      sprintf (buf, " %lf", Ms[inx]);
	      SES_PRINT (ses, buf);
	    }
	}
    }
  SES_PRINT (ses, ")");
}

void
ewkt_print_sf12_one (geo_t * g, dk_session_t * ses, int named)
{
  ewkt_kwd_metas_t *metas = ewkt_find_metas_by_geotype (GEO_TYPE (g->geo_flags));
  if (NULL == metas)
    GPF_T;
  if (named)
    {
      SES_PRINT (ses, metas->kwd_name);
      named = 0;
    }
  switch (GEO_TYPE_NO_ZM (g->geo_flags))
    {
    case GEO_POINT:
      ewkt_print_sf12_points (ses, g->geo_flags, ((geoc_FARAWAY == g->XYbox.Xmin) ? 0 : 1),
	  &(g->XYbox.Xmin), &(g->XYbox.Ymin), &(g->_.point.point_ZMbox.Zmin), &(g->_.point.point_ZMbox.Mmin));
      return;
    case GEO_BOX:
      ewkt_print_sf12_points (ses, g->geo_flags, ((geoc_FARAWAY == g->XYbox.Xmin) ? 0 : 2),
	  &(g->XYbox.Xmin), &(g->XYbox.Ymin), &(g->_.point.point_ZMbox.Zmin), &(g->_.point.point_ZMbox.Mmin));
      return;
    case GEO_LINESTRING:
    case GEO_RING:
    case GEO_POINTLIST:
    case GEO_ARCSTRING:
    case GEO_ARCSTRING | GEO_A_CLOSED:
      ewkt_print_sf12_points (ses, g->geo_flags, g->_.pline.len, g->_.pline.Xs, g->_.pline.Ys, g->_.pline.Zs, g->_.pline.Ms);
      return;
    case GEO_COLLECTION:
    case GEO_CURVE:
    case GEO_CLOSEDCURVE:
    case GEO_CURVEPOLYGON:
    case GEO_MULTI_CURVE:
      named = 1;
      /* no break */
    case GEO_POLYGON:
    case GEO_MULTI_POLYGON:
    case GEO_MULTI_LINESTRING:
      {
	int inx, len = g->_.parts.len;
	if (0 == len)
	  {
	    SES_PRINT (ses, " EMPTY");
	    return;
	  }
	SES_PRINT (ses, "(");
	for (inx = 0; inx < len; inx++)
	  {
	    geo_t *itm = g->_.parts.items[inx];
	    if (inx)
	      SES_PRINT (ses, ",");
	    ewkt_print_sf12_one (itm, ses, named);
	  }
	SES_PRINT (ses, ")");
	return;
      }
    default:
      GPF_T;
    }
}

void
ewkt_print_sf12 (geo_t * g, dk_session_t * ses)
{
  if (g->geo_srcode != GEO_SRCODE_DEFAULT)
    {
      char buf[30];
      sprintf (buf, "SRID=%d;", GEO_SRID (g->geo_srcode));
      SES_PRINT (ses, buf);
    }
  ewkt_print_sf12_one (g, ses, 1);
}

/* Internal binary serialization/deserialization */

/* Serialization format is as follows:

Old types:
  GEO_NULL_SHAPE: 1b flags, 2b? SRID
  GEO_POINT: 1b flags, 2b? SRID, 2coords
  GEO_BOX: 1b flags, 2b? SRID, 4 coords
  GEO_LINESTRING: 1b flags, 2b? SRID, 2|5b len, 2*len coords
New types:
  (Note that more significant byte 0xNN00 is AFTER less significant byte 0X00NN !)
  point/box types:
    2b flags, 2b? SRID, coords as listed in the structure (2 to 8 coords)
  linestring types:
    2b flags, 2b? SRID,
    2|5b (len*2+1), coords as listed in the structure (2 to 8 coords)
  arcstring types:
    2b flags, 2b? SRID,
    2|5b len, bbox (2 to 4 cords), coords as listed in the structure (2 to 8 coords)
  any collections and groups of items:
    2b flags, 2b? SRID (recorded only at top level),
    2|5b total len of the serialization (with all subchildren but without the leading DV_GEO and the length of the "length of the serialization" itself, recorded only at top level),
    2|5b len, bbox (2 to 4 cords), serializations of children
*/

#define DV_INT_FROM_DVLEN(res,dv,len) do {\
  switch ((dv)[len++]) { \
    case DV_SHORT_INT: (res) = (dv)[len++]; break; \
    case DV_LONG_INT: (res) = LONG_REF_NA ((dv)+len); len += 4; break;\
    default: GPF_T1 ("bad int type in DV_INT_FROM_DVLEN"); } } while (0)


void
dv_geo_length (db_buf_t dv, long *hl, long *l)
{
  int len = 0;
  geo_flags_t flags = (++dv)[len++];	/* First byte is DV_GEO, so we skip it first */
  int coord_len = (GEO_IS_FLOAT & flags) ? 4 : 8;
  *hl = 1;
  if (flags & GEO_2BYTE_TYPE)
    flags |= (dv[len++] << 8);
  if (!(GEO_IS_DEFAULT_SRCODE & flags))	/* Not that it's always topmost here */
    len += 2;
/* Old types */
  switch (flags & (GEO_TYPE_MASK | GEO_IS_CHAINBOXED))
    {
    case GEO_NULL_SHAPE:
      *l = len;
      return;
    case GEO_POINT:
      len += coord_len * 2;
      *l = len;
      return;
    case GEO_BOX:
      len += coord_len * 4;
      *l = len;
      return;
    case GEO_LINESTRING:
      {
	int ct;
	DV_INT_FROM_DVLEN (ct, dv, len);
	len += ((ct - 1) / 2) * coord_len * 2;
	*l = len;
	return;
      }
    }
/* New types */
  if (flags & (GEO_A_COMPOUND | GEO_A_RINGS | GEO_A_MULTI | GEO_A_ARRAY))
    {
      int cached_len, saved_len = len + 1;
      DV_INT_FROM_DVLEN (cached_len, dv, len);
      len -= saved_len;
      len += cached_len;
      *l = len - 1;
      return;
    }
  else
    {
      int dims = 2;
      int ct;
      if (GEO_A_Z & flags)
	dims++;
      if (GEO_A_M & flags)
	dims++;
      switch (GEO_TYPE_CORE (flags))
	{
	case GEO_POINT:
	  *l = len + dims * coord_len;
	  return;
	case GEO_BOX:
	  *l = len + 2 * dims * coord_len;
	  return;
	case GEO_LINESTRING:
	case GEO_POINTLIST:
	case GEO_ARCSTRING:
	  {
	    DV_INT_FROM_DVLEN (ct, dv, len);
	    if (flags & GEO_IS_CHAINBOXED)
	      {
		int box_count, step;
		DV_INT_FROM_DVLEN (box_count, dv, len);
		DV_INT_FROM_DVLEN (step, dv, len);
		len += 4 * box_count * coord_len;
	      }
	    if ((flags & GEO_IS_CHAINBOXED) || (GEO_ARCSTRING == GEO_TYPE_CORE (flags)))
	      len += 2 * dims * coord_len;
	    *l = len + ct * dims * coord_len;
	    return;
	  }
	default:
	  GPF_T1 ("bad geo core type in dv_geo_length");
	}
    }
}

#define DV_INT_SERIALIZATION_LENGTH(i) (((i) & ~0xFF) ? 5 : 2)

int
geo_calc_length_of_serialization (geo_t * g, int is_topmost)
{
  geo_flags_t flags = g->geo_flags;
#if 0
  int type_twobytes = ((g->geo_flags & (GEO_TYPE_MASK | GEO_IS_CHAINBOXED | GEO_IS_FLOAT))
      | (is_topmost ? (GEO_SRCODE_DEFAULT == g->geo_srcode ? GEO_IS_DEFAULT_SRCODE : 0) : 0));
#endif
  int len = ((flags & ~0xFF) ? 3 : 2);	/* First byte is DV_GEO, so we count from 1. The top-level field of serialization length will have 1 subtracted because it's in header_length */
  int coord_len = (GEO_IS_FLOAT & flags) ? 4 : 8;
  int dims;
  if (is_topmost && !(GEO_IS_DEFAULT_SRCODE & flags))
    len += 2;			/* SRID */
  dims = 2;
  if (flags & GEO_A_Z)
    dims++;
  if (flags & GEO_A_M)
    dims++;
  if (flags & (GEO_A_COMPOUND | GEO_A_RINGS | GEO_A_MULTI | GEO_A_ARRAY))
    {
      int item_ctr;
      if (g->_.parts.serialization_length)
	return g->_.parts.serialization_length;
      item_ctr = g->_.parts.len;
      len += DV_INT_SERIALIZATION_LENGTH (item_ctr);
      if (flags & GEO_IS_CHAINBOXED)
	{
	  geo_chainbox_t *gcb = g->_.parts.parts_gcb;
	  len += (DV_INT_SERIALIZATION_LENGTH (gcb->gcb_box_count)
	      + DV_INT_SERIALIZATION_LENGTH (gcb->gcb_step) + gcb->gcb_box_count * 4 * coord_len);
	}
      len += 2 * coord_len * dims;	/* bbox */
      while (item_ctr--)
	len += geo_calc_length_of_serialization (g->_.parts.items[item_ctr], 0);
      g->_.parts.serialization_length = len;
      return len;
    }
  else
    {
      int ct;
      if (flags & GEO_IS_CHAINBOXED)
	{
	  geo_chainbox_t *gcb = g->_.pline.pline_gcb;
	  len += (DV_INT_SERIALIZATION_LENGTH (gcb->gcb_box_count)
	      + DV_INT_SERIALIZATION_LENGTH (gcb->gcb_step) + gcb->gcb_box_count * 4 * coord_len);
	}
      if ((flags & GEO_IS_CHAINBOXED) || (GEO_ARCSTRING == GEO_TYPE_CORE (flags)))
	len += (2 * dims * coord_len);	/* bbox */
      switch (GEO_TYPE_CORE (flags))
	{
	case GEO_POINT:
	  return len + dims * coord_len;
	case GEO_BOX:
	  return len + 2 * dims * coord_len;
	case GEO_LINESTRING:
	case GEO_POINTLIST:
	case GEO_ARCSTRING:
	  ct = g->_.pline.len;
	  return len + DV_INT_SERIALIZATION_LENGTH (ct) + ct * dims * coord_len;
	}
    }
  GPF_T1 ("bad geo core type in dv_geo_length");
  return 0;			/* to keep the compiler happy */
}

#define print_v_double(d, s) \
  {if (is_float) print_raw_float (d, s); else print_raw_double (d, s);}

#define print_many_doubles(d, len, s) do { \
  int __len = (len); \
  if (is_float) \
    { \
      int __ctr; \
      for (__ctr = 0; __ctr < __len; __ctr++) \
        print_raw_float ((d)[__ctr], s); \
    } \
  else \
    { \
      int __ctr; \
      for (__ctr = 0; __ctr < __len; __ctr++) \
        print_raw_double ((d)[__ctr], s); \
    } } while (0);

#define print_bbox(g, zm, s) do { \
  print_many_doubles(&(g->XYbox.Xmin), 4, s); \
  if (flags & GEO_A_Z) \
    print_many_doubles(&(zm.Zmin), 2, s); \
  if (flags & GEO_A_M) \
    print_many_doubles(&(zm.Mmin), 2, s); \
  } while (0);

#define read_v_double(s) \
  (is_float ? (double)read_float (s) : read_double (s))

#define read_many_doubles(d, len, s) do { \
  int __len = (len); \
  if (is_float) \
    { \
      int __ctr; \
      for (__ctr = 0; __ctr < __len; __ctr++) \
        (d)[__ctr] = read_float (s); \
    } \
  else \
    { \
      int __ctr; \
      for (__ctr = 0; __ctr < __len; __ctr++) \
        (d)[__ctr] = read_double (s); \
    } } while (0);

#define read_bbox(g, zm, s) do { \
  read_many_doubles(&(g->XYbox.Xmin), 4, s); \
  if (flags & GEO_A_Z) \
    read_many_doubles(&(zm.Zmin), 2, s); \
  if (flags & GEO_A_M) \
    read_many_doubles(&(zm.Mmin), 2, s); \
  } while (0);

void print_raw_double (double d, dk_session_t * session);

void
geo_serialize_one (geo_t * g, int is_topmost, dk_session_t * ses)
{
  geo_flags_t flags = g->geo_flags;
  int is_float = flags & GEO_IS_FLOAT;
  int type_twobytes = ((g->geo_flags & (GEO_TYPE_MASK | GEO_IS_CHAINBOXED | GEO_IS_FLOAT))
      | (is_topmost ? (GEO_SRCODE_DEFAULT == g->geo_srcode ? GEO_IS_DEFAULT_SRCODE : 0) : 0));
  int dims;
  session_buffered_write_char (DV_GEO, ses);
  if (type_twobytes & ~0xFF)
    {
      session_buffered_write_char ((type_twobytes & 0xFF) | GEO_2BYTE_TYPE, ses);
      session_buffered_write_char (type_twobytes >> 8, ses);
    }
  else
    session_buffered_write_char (type_twobytes & 0xFF, ses);
  if (is_topmost && (GEO_SRCODE_DEFAULT != g->geo_srcode))
    print_short (g->geo_srcode, ses);
  switch (g->geo_flags & (GEO_TYPE_MASK | GEO_IS_CHAINBOXED))
    {
/* Old types */
    case GEO_POINT:
      print_v_double (g->Xkey, ses);
      print_v_double (g->Ykey, ses);
      return;
    case GEO_BOX:
      print_v_double (g->XYbox.Xmin, ses);
      print_v_double (g->XYbox.Ymin, ses);
      print_v_double (g->XYbox.Xmax, ses);
      print_v_double (g->XYbox.Ymax, ses);
      return;
    case GEO_LINESTRING:
      {
	int l = g->_.pline.len, inx;
	print_int (1 + l * 2, ses);
	for (inx = 0; inx < l; inx++)
	  {
	    print_v_double (g->_.pline.Xs[inx], ses);
	    print_v_double (g->_.pline.Ys[inx], ses);
	  }
	return;
      }
    }
/* New types */
  dims = 2;
  if (flags & GEO_A_Z)
    dims++;
  if (flags & GEO_A_M)
    dims++;
  if (flags & (GEO_A_COMPOUND | GEO_A_RINGS | GEO_A_MULTI | GEO_A_ARRAY))
    {
      int item_ctr, item_count = g->_.parts.len;
      if (is_topmost)
	{
	  int serlen = g->_.parts.serialization_length;
	  if (0 == serlen)
	    serlen = geo_calc_length_of_serialization (g, is_topmost);
	  print_int (serlen - 1, ses);
	}
      print_int (item_count, ses);
      if (flags & GEO_IS_CHAINBOXED)
	{
	  geo_chainbox_t *gcb = g->_.parts.parts_gcb;
#ifndef NDEBUG
	  if (!(NULL != gcb))
	    GPF_T;
#endif
	  if (!gcb->gcb_is_set)
	    geo_calc_bounding (g, 0);
	  print_int (gcb->gcb_box_count, ses);
	  print_int (gcb->gcb_step, ses);
	  print_many_doubles (&(gcb->gcb_boxes->Xmin), gcb->gcb_box_count * 4, ses);
	}
      print_bbox (g, g->_.parts.parts_ZMbox, ses);
      for (item_ctr = 0; item_ctr < item_count; item_ctr++)
	geo_serialize_one (g->_.parts.items[item_ctr], 0, ses);
      return;
    }
  switch (GEO_TYPE_CORE (flags))
    {
    case GEO_NULL_SHAPE:
      return;
    case GEO_POINT:
      print_v_double (g->XYbox.Xmin, ses);
      print_v_double (g->XYbox.Ymin, ses);
      if (GEO_A_Z & flags)
	print_v_double (g->_.point.point_ZMbox.Zmin, ses);
      if (GEO_A_M & flags)
	print_v_double (g->_.point.point_ZMbox.Mmin, ses);
      return;
    case GEO_BOX:
      print_bbox (g, g->_.point.point_ZMbox, ses);
      return;
    case GEO_ARCSTRING:
    case GEO_LINESTRING:
    case GEO_POINTLIST:
      {
	int pointcount = g->_.pline.len;
	print_int (pointcount, ses);
	if (flags & GEO_IS_CHAINBOXED)
	  {
	    geo_chainbox_t *gcb = g->_.pline.pline_gcb;
#ifndef NDEBUG
	    if (NULL == gcb)
	      GPF_T;
#endif
	    if (!gcb->gcb_is_set)
	      geo_calc_bounding (g, 0);
	    print_int (gcb->gcb_box_count, ses);
	    print_int (gcb->gcb_step, ses);
	    print_many_doubles (&(gcb->gcb_boxes->Xmin), gcb->gcb_box_count * 4, ses);
	  }
	if ((GEO_ARCSTRING == GEO_TYPE_CORE (flags)) || (flags & GEO_IS_CHAINBOXED))
	  print_bbox (g, g->_.pline.pline_ZMbox, ses);
	print_many_doubles (g->_.pline.Xs, pointcount, ses);
	print_many_doubles (g->_.pline.Ys, pointcount, ses);
	if (GEO_A_Z & flags)
	  print_many_doubles (g->_.pline.Zs, pointcount, ses);
	if (GEO_A_M & flags)
	  print_many_doubles (g->_.pline.Ms, pointcount, ses);
	return;
      }
    }
  GPF_T1 ("Wrong type of geo_serialize_one()");
}

void
geo_serialize (geo_t * g, dk_session_t * ses)
{
  client_connection_t *cli = DKS_DB_DATA (ses);
  if (cli && cli->cli_version)
    {
      caddr_t xx = geo_wkt ((caddr_t) g);
      session_buffered_write_char (DV_SHORT_STRING_SERIAL, ses);
      session_buffered_write_char (strlen (xx), ses);
      session_buffered_write (ses, xx, strlen (xx));
      dk_free_box (xx);
      return;
    }
  geo_serialize_one (g, 1, ses);
}

#define GEO_DESERIALIZE_ERROR(msg) box_read_error (ses, 0)

geo_t *
geo_deserialize_one (int srcode /* -1 for topmost */ , dk_session_t * ses)
{
  geo_flags_t flags;
  int is_float;
  int is_topmost = (-1 == srcode);
  int dims;
  geo_t *g;
  if (!is_topmost)
    {
      dtp_t dv_byte = session_buffered_read_char (ses);
      if (DV_GEO != dv_byte)
	GEO_DESERIALIZE_ERROR ("Wrong dv type");
    }
  flags = session_buffered_read_char (ses);
  if (flags & GEO_2BYTE_TYPE)
    flags |= (session_buffered_read_char (ses) << 8);
  is_float = flags & GEO_IS_FLOAT;
  if (is_topmost)
    srcode = (GEO_IS_DEFAULT_SRCODE & flags) ? GEO_SRCODE_DEFAULT : read_short (ses);
  switch (flags & (GEO_TYPE_MASK | GEO_IS_CHAINBOXED))
    {
/* Old types */
    case GEO_POINT:
      g = geo_alloc (flags, 0, srcode);
      g->Xkey = read_v_double (ses);
      g->Ykey = read_v_double (ses);
      return g;
    case GEO_BOX:
      g = geo_alloc (flags, 0, srcode);
      g->XYbox.Xmin = read_v_double (ses);
      g->XYbox.Ymin = read_v_double (ses);
      g->XYbox.Xmax = read_v_double (ses);
      g->XYbox.Ymax = read_v_double (ses);
      return g;
    case GEO_LINESTRING:
      {
	int inx, pointcount = (read_int (ses) - 1) / 2;
	g = geo_alloc (flags, pointcount, srcode);
	for (inx = 0; inx < pointcount; inx++)
	  {
	    g->_.pline.Xs[inx] = read_v_double (ses);
	    g->_.pline.Ys[inx] = read_v_double (ses);
	  }
	return g;
      }
    }
  dims = 2;
  if (flags & GEO_A_Z)
    dims++;
  if (flags & GEO_A_M)
    dims++;
  if (flags & (GEO_A_COMPOUND | GEO_A_RINGS | GEO_A_MULTI | GEO_A_ARRAY))
    {
      int item_ctr, item_count;
      int serlen = 0;
      if (is_topmost)
	serlen = read_int (ses);
      item_count = read_int (ses);
      g = geo_alloc (flags, item_count, srcode);
      g->_.parts.serialization_length = serlen;
      if (flags & GEO_IS_CHAINBOXED)
	{
	  geo_chainbox_t *gcb;
	  int box_count = read_int (ses);
	  int step = read_int (ses);
	  if (!(g->geo_flags & GEO_IS_CHAINBOXED))
	    GEO_DESERIALIZE_ERROR ("chainboxes for short partlist");
	  gcb = g->_.parts.parts_gcb;
	  if (gcb->gcb_box_count != box_count && gcb->gcb_step != step)
	    GEO_DESERIALIZE_ERROR ("chainboxes of wrong dimensions");
	  read_many_doubles (&(gcb->gcb_boxes->Xmin), gcb->gcb_box_count * 4, ses);
	  gcb->gcb_is_set = 1;
	}
      read_bbox (g, g->_.parts.parts_ZMbox, ses);
      for (item_ctr = 0; item_ctr < item_count; item_ctr++)
	g->_.parts.items[item_ctr] = geo_deserialize_one (srcode, ses);
      return g;
    }
  switch (GEO_TYPE_CORE (flags))
    {
    case GEO_NULL_SHAPE:
      g = geo_alloc (flags, 0, srcode);
      return g;
    case GEO_POINT:
      g = geo_alloc (flags, 0, srcode);
      g->XYbox.Xmin = g->XYbox.Xmax = read_v_double (ses);
      g->XYbox.Ymin = g->XYbox.Ymax = read_v_double (ses);
      print_v_double (g->XYbox.Ymin, ses);
      if (GEO_A_Z & flags)
	g->_.point.point_ZMbox.Zmin = g->_.point.point_ZMbox.Zmax = read_v_double (ses);
      if (GEO_A_M & flags)
	g->_.point.point_ZMbox.Mmin = g->_.point.point_ZMbox.Mmax = read_v_double (ses);
      return g;
    case GEO_BOX:
      g = geo_alloc (flags, 0, srcode);
      read_bbox (g, g->_.point.point_ZMbox, ses);
      return g;
    case GEO_ARCSTRING:
    case GEO_LINESTRING:
    case GEO_POINTLIST:
      {
	int bbox_preserved = ((GEO_ARCSTRING == GEO_TYPE_CORE (flags)) || (flags & GEO_IS_CHAINBOXED));
	int pointcount = read_int (ses);
	g = geo_alloc (flags, pointcount, srcode);
	if (flags & GEO_IS_CHAINBOXED)
	  {
	    geo_chainbox_t *gcb;
	    int box_count = read_int (ses);
	    int step = read_int (ses);
	    if (!(g->geo_flags & GEO_IS_CHAINBOXED))
	      GEO_DESERIALIZE_ERROR ("chainboxes for short linestring");
	    gcb = g->_.pline.pline_gcb;
	    if (gcb->gcb_box_count != box_count && gcb->gcb_step != step)
	      GEO_DESERIALIZE_ERROR ("chainboxes of wrong dimensions");
	    read_many_doubles (&(gcb->gcb_boxes->Xmin), gcb->gcb_box_count * 4, ses);
	    gcb->gcb_is_set = 1;
	  }
	if (bbox_preserved)
	  read_bbox (g, g->_.pline.pline_ZMbox, ses);
	read_many_doubles (g->_.pline.Xs, pointcount, ses);
	read_many_doubles (g->_.pline.Ys, pointcount, ses);
	if (GEO_A_Z & flags)
	  read_many_doubles (g->_.pline.Zs, pointcount, ses);
	if (GEO_A_M & flags)
	  read_many_doubles (g->_.pline.Ms, pointcount, ses);
	if (!bbox_preserved)
	  geo_calc_bounding (g, 0);
	return g;
      }
    }
  GEO_DESERIALIZE_ERROR ("Wrong type");
  return NULL;			/* to keep the compiler happy */
}

caddr_t
geo_deserialize (dk_session_t * ses)
{
  geo_t *g = geo_deserialize_one (-1, ses);
  return (caddr_t) g;
}


/* Compuptational geometry algorithms of all sorts */

double
geo_ccw_flat_rvector_run (geoc * Xs, geoc * Ys, int n, int flags)
{
  int ctr;
  double res = 0;
  if (n < 2)
    return 0;
  /* TBD: add correct calculation for arcs */
  for (ctr = n - 1; ctr--; /* no step */ )
    res += (Xs[ctr] + Xs[ctr + 1]) * (Ys[ctr + 1] - Ys[ctr]);
  return res;
}


double
geo_ccw_flat_area (geo_t * g)
{
  double res;
  int ctr;
  if (g->geo_flags & (GEO_A_MULTI | GEO_A_ARRAY))
    {
      res = 0;
      for (ctr = g->_.parts.len; ctr--; /* no step */ )
	res += geo_ccw_flat_area (g->_.parts.items[ctr]);
      return res;
    }
  if (g->geo_flags & (GEO_A_RINGS))
    {
      res = 0;
      ctr = g->_.parts.len;
      if (!ctr)
	return 0;
      while (--ctr)
	res += geo_ccw_flat_area (g->_.parts.items[ctr]);
      res = geo_ccw_flat_area (g->_.parts.items[0]) - res;
      return res;
    }
  if (!(g->geo_flags & (GEO_A_CLOSED)))
    return 0;
  switch (GEO_TYPE_NO_ZM (g->geo_flags))
    {
    case GEO_RING:
      return geo_ccw_flat_rvector_run (g->_.pline.Xs, g->_.pline.Ys, g->_.pline.len, 0);
    case GEO_CLOSEDCURVE:
      res = 0;
      for (ctr = g->_.parts.len; ctr--; /* no step */ )
	{
	  geo_t *cut = g->_.parts.items[ctr];
	  res += geo_ccw_flat_rvector_run (cut->_.pline.Xs, cut->_.pline.Ys, cut->_.pline.len, 0);
	}
      return res;
    default:
      GPF_T;
    }
  return 0;
}


#define SWAP_DOUBLES(Cs,len) do { \
  double *p1 = (Cs); \
  double *p2 = p1 + (len) - 1; \
  while (p1 < p2) { double swap = p1[0]; (p1++)[0] = p2[0]; (p2--)[0] = swap; } } while (0)


void
geo_inverse_point_order (geo_t * g)
{
  int ctr;
  if (g->geo_flags & (GEO_A_MULTI | GEO_A_ARRAY | GEO_A_RINGS))
    {
      for (ctr = g->_.parts.len; ctr--; /* no step */ )
	geo_inverse_point_order (g->_.parts.items[ctr]);
      return;
    }
  if (g->geo_flags & (GEO_A_COMPOUND))
    {
      int lastidx = g->_.parts.len - 1;
      for (ctr = g->_.parts.len / 2; ctr--; /* no step */ )
	{
	  geo_t *p1 = g->_.parts.items[ctr];
	  geo_t *p2 = g->_.parts.items[lastidx - ctr];
	  geo_inverse_point_order (p1);
	  geo_inverse_point_order (p2);
	  g->_.parts.items[ctr] = p2;
	  g->_.parts.items[lastidx - ctr] = p1;
	}
      return;
    }
  switch (GEO_TYPE_CORE (g->geo_flags))
    {
    case GEO_LINESTRING:
    case GEO_ARCSTRING:
      {
	int len = g->_.pline.len;
	SWAP_DOUBLES (g->_.pline.Xs, len);
	SWAP_DOUBLES (g->_.pline.Ys, len);
	if (g->geo_flags & GEO_A_Z)
	  SWAP_DOUBLES (g->_.pline.Zs, len);
	if (g->geo_flags & GEO_A_M)
	  SWAP_DOUBLES (g->_.pline.Ms, len);
	return;
      }
    }
}


int
geo_XYbbox_inside (geo_XYbox_t * inner, geo_XYbox_t * outer)
{
  return ((inner->Xmin + FLT_EPSILON >= outer->Xmin) &&
      (inner->Xmax - FLT_EPSILON <= outer->Xmax) &&
      (inner->Ymin + FLT_EPSILON >= outer->Ymin) && (inner->Ymax - FLT_EPSILON <= outer->Ymax));
}


int
geo_XY_inoutside_ring_lines (geoc pX, geoc pY, int len, geoc * Xs, geoc * Ys, int *up_crosses_ray_ptr, int *down_crosses_ray_ptr)
{
  int ctr;
  for (ctr = 1; ctr < len; ctr++)
    {
      geoc aX = Xs[ctr - 1], bX = Xs[ctr];
      geoc aY = Ys[ctr - 1], bY = Ys[ctr];
      geoc isectX;
/*
                  1         2         3         4         5         6         7         8
Case #   123456789012345678901234567890123456789012345678901234567890123456789012345678901
aX ? pX |<<<<<<<<<<<<<<<<<<<<<<<<<<<===========================>>>>>>>>>>>>>>>>>>>>>>>>>>>
bX ? pX |<<<<<<<<<=========>>>>>>>>><<<<<<<<<=========>>>>>>>>><<<<<<<<<=========>>>>>>>>>
aY ? pY |<<<===>>><<<===>>><<<===>>><<<===>>><<<===>>><<<===>>><<<===>>><<<===>>><<<===>>>
bY ? pY |<=><=><=><=><=><=><=><=><=><=><=><=><=><=><=><=><=><=><=><=><=><=><=><=><=><=><=>
if#      1111111112   9   32   9   32  B9B  32AAA9AAA32  B9B  32   9   32   9   3244444443
if#                                                                               758e768
result   iiiiiiiiii   b   ii   b   ii  bbb  iibbbbbbbii  bbb  ii   b   ii   b   ii`^,i`v,i

` = up come or go (in vertex), ^ = up cross with mid-segment,
, = down come or go (in vertex), v = down cross  with mid-segment,
b = border exact hit, i = ignore
*/
      if ((aX < pX) && (bX < pX))	/* if# 1 */
	continue;		/* ingnore */
      if ((aY < pY) && (bY < pY))	/* if# 2 */
	continue;
      if ((aY > pY) && (bY > pY))	/* if# 3 */
	continue;
      if ((aX > pX) && (bX > pX))	/* if# 4 */
	{
	  if ((aY < pY) && (bY > pY))	/* if# 5 */
	    (up_crosses_ray_ptr[0]) += 2;
	  else if ((aY > pY) && (bY < pY))	/* if# 6 */
	    (down_crosses_ray_ptr[0]) += 2;
	  else if (aY < bY)	/* if# 7 */
	    (up_crosses_ray_ptr[0])++;
	  else if (aY > bY)	/* if# 8 */
	    (down_crosses_ray_ptr[0])++;
	  continue;
	}
      if ((aY == pY) && (bY == pY))	/* if# 9 */
	return GEO_INOUTSIDE_BORDER;
      if ((aX == pX) && (bX == pX))	/* if# A */
	return GEO_INOUTSIDE_BORDER;
      if ((aX == pX) && (aY == pY))	/* if# B */
	return GEO_INOUTSIDE_BORDER;
      isectX = aX + (bX - aX) * (pY - aY) / (bY - aY);
      if (isectX < (pX - FLT_EPSILON))
	continue;
      if (isectX > (pX + FLT_EPSILON))
	{
	  if ((aY < pY) && (bY > pY))
	    (up_crosses_ray_ptr[0]) += 2;
	  else if ((aY > pY) && (bY < pY))
	    (down_crosses_ray_ptr[0]) += 2;
	  else if (aY < bY)
	    (up_crosses_ray_ptr[0])++;
	  else if (aY > bY)
	    (down_crosses_ray_ptr[0])++;
	  continue;
	}
      return GEO_INOUTSIDE_BORDER;
    }
  return 0;
}

int
#ifdef geo_XY_inoutside_ring_DEBUG
geo_XY_inoutside_ring_impl (geoc pX, geoc pY, geo_t * ring)
#else
geo_XY_inoutside_ring (geoc pX, geoc pY, geo_t * ring)
#endif
{
  int up_crosses_ray = 0;
  int down_crosses_ray = 0;
  int len = ring->_.pline.len;
  geoc *Xs = ring->_.pline.Xs;
  geoc *Ys = ring->_.pline.Ys;
  if ((ring->geo_flags & GEO_IS_CHAINBOXED) && ring->_.pline.pline_gcb->gcb_is_set)
    {
      geo_XYbox_t *gcb_ptr = gcb_ptr = ring->_.pline.pline_gcb->gcb_boxes;
      int inx;
      int gcb_next_stop;
      int gcb_step = MIN ((len - 1), ring->_.pline.pline_gcb->gcb_step);
      gcb_next_stop = 1 + gcb_step;
      inx = 0;
      for (;;)
	{
	  if ((pX <= gcb_ptr->Xmax) && (pY <= gcb_ptr->Ymax) && (pY >= gcb_ptr->Ymin))
	    {
	      if (pX >= gcb_ptr->Xmin)
		{
		  int inoutside =
		      geo_XY_inoutside_ring_lines (pX, pY, gcb_next_stop - inx, Xs + inx, Ys + inx, &up_crosses_ray,
		      &down_crosses_ray);
		  if (inoutside)
		    return inoutside;
		}
	      else
		{
		  geoc aY = Ys[inx], bY = Ys[gcb_next_stop - 1];
		  if ((aY < pY) && (bY > pY))
		    up_crosses_ray += 2;
		  else if ((aY > pY) && (bY < pY))
		    down_crosses_ray += 2;
		  else if ((aY == pY) || (bY == pY))
		    {
		      if (aY < bY)
			up_crosses_ray++;
		      else if (aY > bY)
			down_crosses_ray++;
		    }
		}
	    }
	  if (gcb_next_stop >= len)
	    break;
	  inx += gcb_step;
	  gcb_next_stop += gcb_step;
	  if (gcb_next_stop > len)
	    gcb_next_stop = len;
	  gcb_ptr++;
	}
    }
  else
    {
      int inoutside = geo_XY_inoutside_ring_lines (pX, pY, len, Xs, Ys, &up_crosses_ray, &down_crosses_ray);
      if (inoutside)
	return inoutside;
    }
  if (up_crosses_ray == down_crosses_ray)
    return GEO_INOUTSIDE_OUT;	/* outside */
  if (up_crosses_ray == down_crosses_ray + 2)
    return GEO_INOUTSIDE_IN;	/* inside proper ccw ring */
  if (up_crosses_ray == down_crosses_ray - 2)
    return GEO_INOUTSIDE_IN | GEO_INOUTSIDE_CLOCKWISE;	/* inside proper cw ring */
  return GEO_INOUTSIDE_ERROR;
}


#ifdef geo_XY_inoutside_ring_DEBUG
int
geo_XY_inoutside_ring (geoc pX, geoc pY, geo_t * ring)
{
  int res = geo_XY_inoutside_ring_impl (pX, pY, ring);
  if ((ring->geo_flags & GEO_IS_CHAINBOXED) && ring->_.pline.pline_gcb->gcb_is_set)
    {
      int res_old;
      ring->_.pline.pline_gcb->gcb_is_set = 0;
      res_old = geo_XY_inoutside_ring_impl (pX, pY, ring);
      ring->_.pline.pline_gcb->gcb_is_set = 1;
      if (res != res_old)
	{
	  geo_XY_inoutside_ring_impl (pX, pY, ring);
	  return GEO_INOUTSIDE_ERROR;
	}
    }
  return res;
}
#endif


int
geo_XY_inoutside_polygon (geoc pX, geoc pY, geo_t * g)
{
  int ctr, inoutside;
  geo_t *ring;
  if (g->_.parts.len < 1)
    return 0;
  ring = g->_.parts.items[0];
  if (GEO_RING != GEO_TYPE_NO_ZM (ring->geo_flags))
    return 0;
  if ((pX < g->XYbox.Xmin) || (pX > g->XYbox.Xmax) || (pY < g->XYbox.Ymin) || (pY > g->XYbox.Ymax))
    return GEO_INOUTSIDE_OUT;
  inoutside = geo_XY_inoutside_ring (pX, pY, ring);
  if ((GEO_INOUTSIDE_OUT | GEO_INOUTSIDE_BORDER | GEO_INOUTSIDE_CLOCKWISE | GEO_INOUTSIDE_ERROR) & inoutside)
    return inoutside;
  for (ctr = g->_.parts.len; --ctr; /* no step */ )
    {
      ring = g->_.parts.items[ctr];
      if (GEO_RING != GEO_TYPE_NO_ZM (ring->geo_flags))
	continue;
      if ((pX < ring->XYbox.Xmin) || (pX > ring->XYbox.Xmax) || (pY < ring->XYbox.Ymin) || (pY > ring->XYbox.Ymax))
	continue;
      inoutside = geo_XY_inoutside_ring (pX, pY, ring);
      if ((GEO_INOUTSIDE_BORDER | GEO_INOUTSIDE_CLOCKWISE | GEO_INOUTSIDE_ERROR) & inoutside)
	return inoutside;
      if (GEO_INOUTSIDE_IN & inoutside)
	return GEO_INOUTSIDE_OUT;
    }
  return GEO_INOUTSIDE_IN;
}

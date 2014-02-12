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

#include "sqlnode.h"
#include <math.h>
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

double
bif_geoc_arg (caddr_t * qst, state_slot_t ** args, int nth, const char *func, int *isnull_ret, geo_srcode_t srcode, int coord_idx)
{
  double c;
  caddr_t arg = bif_arg_unrdf (qst, args, nth, func);
  dtp_t dtp = DV_TYPE_OF (arg);
  switch (dtp)
    {
    case DV_SHORT_INT: case DV_LONG_INT: c = (double) unbox (arg); break;
    case DV_SINGLE_FLOAT: c = (double) unbox_float (arg); break;
    case DV_DOUBLE_FLOAT: c = unbox_double (arg); break;
    case DV_NUMERIC: numeric_to_double ((numeric_t) arg, &c); break;
    case DV_DB_NULL: if (NULL != isnull_ret) { isnull_ret[0] = 1; return 0; }
      /* no break */
    default: sqlr_new_error ("22023", "GEO..",
      "Function %s needs a number%s as argument %d, not an arg of type %s (%d)",
      func, ((NULL != isnull_ret) ? " or NULL" : ""), nth + 1, dv_type_title (dtp), dtp );
    }
  if (NULL != isnull_ret) isnull_ret[0] = 0;
  if ((c >= geoc_FARAWAY - 16 * geoc_EPSILON) || (c <= -(geoc_FARAWAY - 16 * geoc_EPSILON)))
    sqlr_new_error ("22023", "GEO..",
      "Function %s needs a coordinate as argument %d, the number %g is not a valid coordiate",
      func, nth + 1, c);
  if ((2 > coord_idx) && GEO_SR_SPHEROID_DEGREES(srcode))
    {
      if ((0 == coord_idx) ? ((c < -270.0) || (c > 540.0)) : ((c < -90) || (c > 90)))
        sqlr_new_error ("22023", "GEO..",
          "Function %s needs a %s as argument %d, the number %g is out of range",
          func, ((0 == coord_idx) ? "longitude" : "latitude"), nth + 1, c);
    }
  return c;
}

caddr_t
bif_earth_radius (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return box_double (EARTH_RADIUS_GEOM_MEAN_KM);
}

double
haversine (double lat1, double lat2, double long_sep)
{
  double sqrthaversin_lat_sep = sin ((lat1 - lat2) / 2.0);
  double sqrthaversin_long_sep = sin (long_sep / 2.0);
  return sqrthaversin_lat_sep * sqrthaversin_lat_sep + cos (lat1) * cos (lat2) * sqrthaversin_long_sep * sqrthaversin_long_sep;
}

double
haversine_deg_km (double long1, double lat1, double long2, double lat2)
{
  double hs;
  lat1 *= (M_PI / 180.0);
  long1 *= (M_PI / 180.0);
  lat2 *= (M_PI / 180.0);
  long2 *= (M_PI / 180.0);
  hs = haversine (lat1, lat2, long2 - long1);
  if (hs > 0.999999)
    return (M_PI * (EARTH_RADIUS_GEOM_MEAN_KM + cos (lat1) * cos (lat2) * (EARTH_RADIUS_EQUATOR_KM - EARTH_RADIUS_GEOM_MEAN_KM)));
  else if (hs <= 0.0)
    return (0);
  else
    return (EARTH_RADIUS_GEOM_MEAN_KM * 2.0 * asin (sqrt (hs)));
}


caddr_t
bif_haversine_deg_km (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  double lat1 = bif_geoc_arg (qst, args, 0, "haversine_deg_km", NULL, GEO_SRCODE_OF_SRID (SRID_WGS84), 1);
  double long1 = bif_geoc_arg (qst, args, 1, "haversine_deg_km", NULL, GEO_SRCODE_OF_SRID (SRID_WGS84), 0);
  double lat2 = bif_geoc_arg (qst, args, 2, "haversine_deg_km", NULL, GEO_SRCODE_OF_SRID (SRID_WGS84), 1);
  double long2 = bif_geoc_arg (qst, args, 3, "haversine_deg_km", NULL, GEO_SRCODE_OF_SRID (SRID_WGS84), 0);
  return box_double (haversine_deg_km (long1, lat1, long2, lat2));
}

double
dist_from_point_to_line_segment (double xP, double yP, double xL1, double yL1, double xL2, double yL2)
{
  double dxL = xL2 - xL1, dyL = yL2 - yL1;
  double Llen_sq = dxL * dxL + dyL * dyL;
  double propo, xProx, yProx;
  xL1 -= xP;
  yL1 -= yP;
  xL2 -= xP;
  yL2 -= yP;
  if (0.0 >= Llen_sq)
    return sqrt (xL2 * xL2 + yL2 * yL2);
  propo = -(xL1 * dxL + yL1 * dyL) / Llen_sq;
  if (propo <= 0.0)
    propo = 0.0;
  else if (propo >= 1.0)
    propo = 1.0;
  xProx = xL1 + propo * dxL;
  yProx = yL1 + propo * dyL;
  return sqrt (xProx * xProx + yProx * yProx);
}

caddr_t
bif_dist_from_point_to_line_segment (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  const char fname[] = "dist_from_point_to_line_segment";
  double xP = bif_double_arg (qst, args, 0, fname);
  double yP = bif_double_arg (qst, args, 1, fname);
  double xL1 = bif_double_arg (qst, args, 2, fname);
  double yL1 = bif_double_arg (qst, args, 3, fname);
  double xL2 = bif_double_arg (qst, args, 4, fname);
  double yL2 = bif_double_arg (qst, args, 5, fname);
  return box_double (dist_from_point_to_line_segment (xP, yP, xL1, yL1, xL2, yL2));
}

caddr_t
bif_st_point (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t first = bif_arg_unrdf (qst, args, 0, "st_point");
  dtp_t dtp = DV_TYPE_OF (first);
  double x = bif_geoc_arg (qst, args, 0, "st_point", NULL, GEO_SRCODE_DEFAULT, 0);
  double y = bif_geoc_arg (qst, args, 1, "st_point", NULL, GEO_SRCODE_DEFAULT, 1);
  geo_flags_t flags = GEO_POINT;
  double z,m;
  geo_t *res;
  switch (BOX_ELEMENTS (args))
    {
    case 2:
      res = geo_point (x,y);
      goto all_coords_are_set;
      break;
    case 3:
      flags = GEO_POINT_Z;
      z = bif_double_arg (qst, args, 2, "st_point");
      break;
      break;
    case 4:
      flags = GEO_POINT;
      if (DV_DB_NULL != DV_TYPE_OF (bif_arg_nochecks (qst, args, 2)))
        {
          flags |= GEO_A_Z;
          z = bif_double_arg (qst, args, 2, "st_point");
        }
      if (DV_DB_NULL != DV_TYPE_OF (bif_arg_nochecks (qst, args, 3)))
        {
          flags |= GEO_A_M;
          m = bif_double_arg (qst, args, 3, "st_point");
        }
      break;
    default:
      sqlr_new_error ("22023", "GEO..", "Wrong number of arguments in call of st_point()");
    }
  res = geo_alloc (flags, 0, GEO_SRCODE_DEFAULT);
  res->XYbox.Xmax = res->XYbox.Xmin = x;
  res->XYbox.Ymax = res->XYbox.Ymin = y;
  if (flags & GEO_A_Z)
    res->_.point.point_ZMbox.Zmax = res->_.point.point_ZMbox.Zmin = z;
  if (flags & GEO_A_M)
    res->_.point.point_ZMbox.Mmax = res->_.point.point_ZMbox.Mmin = m;

all_coords_are_set:
  if (DV_SINGLE_FLOAT == dtp || DV_LONG_INT == dtp)
    res->geo_flags |= GEO_IS_FLOAT;
  return (caddr_t)res;
}

double
geo_cast_box_to_geoc (caddr_t v, geo_srcode_t srcode, int coord_idx, int *isnull_ret, const char **err_text_ret)
{
  double c;
  dtp_t dtp = DV_TYPE_OF (v);
  switch (dtp)
    {
    case DV_SHORT_INT: case DV_LONG_INT: c = (double) unbox (v); break;
    case DV_SINGLE_FLOAT: c = (double) unbox_float (v); break;
    case DV_DOUBLE_FLOAT: c = unbox_double (v); break;
    case DV_NUMERIC: numeric_to_double ((numeric_t) v, &c); break;
    case DV_DB_NULL: if (NULL != isnull_ret) { isnull_ret[0] = 1; err_text_ret[0] = NULL; return 0; }
      /* no break */
    default: err_text_ret[0] = "Coordinate is not a number"; return 0;
    }
  if (NULL != isnull_ret) isnull_ret[0] = 0;
  if ((c >= geoc_FARAWAY - 16 * geoc_EPSILON) || (c <= -(geoc_FARAWAY - 16 * geoc_EPSILON)))
    {
      err_text_ret[0] = "Coordinate is a number that is not a valid coordiate";
      return 0;
    }
  if ((2 > coord_idx) && GEO_SR_SPHEROID_DEGREES(srcode))
    {
      if ((0 == coord_idx) ? ((c < -270.0) || (c > 540.0)) : ((c < -(90 + geoc_EPSILON)) || (c > (90 + geoc_EPSILON))))
        {
          err_text_ret[0] =  ((0 == coord_idx) ? "Longitude is out of range" : "Latitude is out of range");
          return 0;
        }
    }
  err_text_ret[0] = NULL;
  return c;
}

/*! The \c point should have preset \c geo_srcode and \c geo_flags.
The \c point should not be used as filled, because the function may write to Z or M past "plain" point and will not set "...max" fields. */
void
geo_cast_box_to_point (caddr_t v, geo_t *point, const char **err_text_ret)
{
  const char *err;
  switch (DV_TYPE_OF (v))
    {
    case DV_ARRAY_OF_POINTER:
      {
        int p_len = BOX_ELEMENTS (v);
        int isnull;
        geo_flags_t flags = GEO_POINT;
        if ((p_len < 2) || (p_len > 4))
          {
            err_text_ret[0] = "When a point is given as a vector of coordinates, the length of vector should be 2, 3 or 4";
            return;
          }
        point->XYbox.Xmin = geo_cast_box_to_geoc (((caddr_t *)v)[0], point->geo_srcode, 0, NULL, &err);
        if (NULL != err)
          {
            err_text_ret[0] = err;
            return;
          }
        point->XYbox.Ymin = geo_cast_box_to_geoc (((caddr_t *)v)[1], point->geo_srcode, 1, NULL, &err);
        if (NULL != err)
          {
            err_text_ret[0] = err;
            return;
          }
        switch (p_len)
          {
          case 2:
            break;
          case 3:
            flags |= GEO_A_Z;
            point->_.point.point_ZMbox.Zmin = geo_cast_box_to_geoc (((caddr_t *)v)[2], point->geo_srcode, 2, NULL, &err);
            if (NULL != err)
              {
                err_text_ret[0] = err;
                return;
              }
            break;
          case 4:
            point->_.point.point_ZMbox.Zmin = geo_cast_box_to_geoc (((caddr_t *)v)[3], point->geo_srcode, 3, &isnull, &err);
            if (NULL != err)
              {
                err_text_ret[0] = err;
                return;
              }
            if (!isnull)
              flags |= GEO_A_Z;
            point->_.point.point_ZMbox.Mmin = geo_cast_box_to_geoc (((caddr_t *)v)[4], point->geo_srcode, 4, &isnull, &err);
            if (NULL != err)
              {
                err_text_ret[0] = err;
                return;
              }
            if (!isnull)
              flags |= GEO_A_M;
            break;
          }
        if ((GEO_UNDEFTYPE != point->geo_flags) && (flags != GEO_TYPE (point->geo_flags)))
          {
            err = "Unexpected number of coordinates for a point";
            return;
          }
        point->geo_flags = flags;
        if ((DV_SINGLE_FLOAT == DV_TYPE_OF (((caddr_t *)v)[0])) || (DV_LONG_INT == DV_TYPE_OF (((caddr_t *)v)[0])))
          point->geo_flags |= GEO_IS_FLOAT;
        err_text_ret[0] = NULL;
        return;
      }
    case DV_GEO:
      {
        if (GEO_POINT != GEO_TYPE_NO_ZM (((geo_t *)v)->geo_flags))
          {
            err = "Non-point geometry can not specify coordinates of a single point";
            return;
          }
        if ((GEO_UNDEFTYPE != point->geo_flags) && (GEO_TYPE (((geo_t *)v)->geo_flags) != GEO_TYPE (point->geo_flags)))
          {
            err = "Unexpected number of coordinates for a point";
            return;
          }
        memcpy (point, v, box_length (v));
        err_text_ret[0] = NULL;
        return;
      }
    }
  err_text_ret[0] = "The value can not be converted to set of coordinates of a point: wrong datatype";
  return;
}

caddr_t
bif_st_linestring (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  const char *fname = "st_linestring";
  int argctr, argcount = BOX_ELEMENTS (args);
  int pointctr = 0, total_point_count = 0, arcmid_count = 0;
  geoc prevX, prevY;
  geo_flags_t flags = GEO_LINESTRING;
  geo_srcode_t srcode = GEO_SRCODE_DEFAULT;
  const char *err;
  geo_t *res;
  int pass2 = 0;
/* The processing is done in two passes.
Pass 1: checking for errors and counting points of the result, excluding redundand points at concatenations.
Then allocation of the result. Then
Pass 2: copying co-ordinates from arguments and filling in missing Zs and Ms where necessary.
Then building bounding boxes and filling in chainboxes. */
start_pass:
  prevX = geoc_FARAWAY;
  prevY = geoc_FARAWAY;
  for (argctr = 0; argctr < argcount; argctr++)
    {
      caddr_t arg = bif_arg_nochecks (qst, args, argctr);
      int arg_is_list_and_not_point = 0;
      caddr_t *v_list;
      int v_ctr, v_len;
      if (DV_ARRAY_OF_POINTER == DV_TYPE_OF (arg))
        {
          v_len = BOX_ELEMENTS (arg);
          if (0 == v_len)
            arg_is_list_and_not_point = 1;
          else
            {
              dtp_t dtp0 = DV_TYPE_OF (((caddr_t *)arg)[0]);
              if (!(DV_SHORT_INT == dtp0 || DV_LONG_INT == dtp0 || DV_SINGLE_FLOAT == dtp0 || DV_DOUBLE_FLOAT == dtp0 || DV_NUMERIC == dtp0))
                arg_is_list_and_not_point = 1;
            }
        }
      if (arg_is_list_and_not_point)
        v_list = (caddr_t *)arg; /* v_len is set above */
      else
        {
          v_len = 1;
          v_list = &arg;
        }
      for (v_ctr = 0; v_ctr < v_len; v_ctr++)
        { /* Vector of points or geometries */
          caddr_t v = v_list[v_ctr];
          if (DV_GEO == DV_TYPE_OF (v))
            {
              geo_t *itm = (geo_t *)v;
              int first_new_point_ofs, addon_count;
              switch (GEO_TYPE_NO_ZM (itm->geo_flags))
                {
                case GEO_POINT:
                  if ((fabs (itm->XYbox.Xmin - prevX) <= geoc_EPSILON) && (fabs (itm->XYbox.Ymin - prevY) <= geoc_EPSILON))
                    continue;
                  prevX = itm->XYbox.Xmin;
                  prevY = itm->XYbox.Ymin;
                  if (pass2)
                    {
                      res->_.pline.Xs[pointctr] = itm->XYbox.Xmin;
                      res->_.pline.Ys[pointctr] = itm->XYbox.Ymin;
                      if (flags & itm->geo_flags & GEO_A_Z)
                        res->_.pline.Zs[pointctr] = itm->_.point.point_ZMbox.Zmin;
                      if (flags & itm->geo_flags & GEO_A_M)
                        res->_.pline.Ms[pointctr] = itm->_.point.point_ZMbox.Mmin;
                      pointctr++;
                    }
                  else
                    total_point_count++;
                  continue;
                case GEO_LINESTRING:
                  if (0 == itm->_.pline.len)
                    continue;
                  break;
                  break;
                case GEO_ARCSTRING:
                  if (3 < itm->_.pline.len)
                    continue;
                  break;
                default:
                  sqlr_new_error ("22023", "SP...", "Invalid argument %d in call of %s(): the vector contains shape that can not be used as a fragment of the result",
                    argctr+1, fname);
                }
              if ((fabs (itm->_.pline.Xs[0] - prevX) <= geoc_EPSILON) && (fabs (itm->_.pline.Ys[0] - prevY) <= geoc_EPSILON))
                first_new_point_ofs = 1;
              else
                first_new_point_ofs = 0;
              addon_count = itm->_.pline.len - first_new_point_ofs;
              prevX = itm->_.pline.Xs[itm->_.pline.len-1];
              prevY = itm->_.pline.Ys[itm->_.pline.len-1];
              if (pass2)
                {
                  memcpy (res->_.pline.Xs + pointctr, itm->_.pline.Xs + first_new_point_ofs, sizeof (geoc) * addon_count);
                  memcpy (res->_.pline.Ys + pointctr, itm->_.pline.Ys + first_new_point_ofs, sizeof (geoc) * addon_count);
                  if (flags & itm->geo_flags & GEO_A_Z)
                    memcpy (res->_.pline.Zs + pointctr, itm->_.pline.Zs + first_new_point_ofs, sizeof (geoc) * addon_count);
                  if (flags & itm->geo_flags & GEO_A_M)
                    memcpy (res->_.pline.Ms + pointctr, itm->_.pline.Ms + first_new_point_ofs, sizeof (geo_measure_t) * addon_count);
                  pointctr += addon_count;
                }
              else
                total_point_count += addon_count;
            }
          else
            {
              geo_t p; p.geo_flags = GEO_UNDEFTYPE; p.geo_srcode = srcode;
              geo_cast_box_to_point (v, &p, &err);
              if (NULL != err)
                {
                  if (arg_is_list_and_not_point)
                    sqlr_new_error ("22023", "SP001", "Invalid item [%d] (zero-based) of vector argument %d in call of %s(): %s",
                      v_ctr, argctr+1, fname, err );
                  else
                    sqlr_new_error ("22023", "SP001", "Invalid argument %d in call of %s(): %s", argctr+1, fname, err);
                }
              if ((fabs (p.XYbox.Xmin - prevX) <= geoc_EPSILON) && (fabs (p.XYbox.Ymin - prevY) <= geoc_EPSILON))
                continue;
              prevX = p.XYbox.Xmin;
              prevY = p.XYbox.Ymin;
              if (pass2)
                {
                  res->_.pline.Xs[pointctr] = p.XYbox.Xmin;
                  res->_.pline.Ys[pointctr] = p.XYbox.Ymin;
                  if (flags & p.geo_flags & GEO_A_Z)
                    res->_.pline.Zs[pointctr] = p._.point.point_ZMbox.Zmin;
                  if (flags & p.geo_flags & GEO_A_M)
                    res->_.pline.Ms[pointctr] = p._.point.point_ZMbox.Mmin;
                  pointctr++;
                }
              else
                total_point_count++;
            }
        }
    }
  if (!pass2)
    {
      int ctr;
      res = geo_alloc (flags, total_point_count, srcode);
      if (flags & GEO_A_Z)
        {
          for (ctr = total_point_count; ctr--; /* no step */)
            res->_.pline.Zs[ctr] = 0;
        }
      if (flags & GEO_A_M)
        {
          for (ctr = total_point_count; ctr--; /* no step */)
            res->_.pline.Ms[ctr] = 0;
        }
      pass2 = 1;
      goto start_pass; /* see above */
    }
  if (pointctr != total_point_count)
    {
      if (pointctr < total_point_count)
        sqlr_new_error ("22023", "SP...", "Internal error in bif_st_polyline()");
      GPF_T1 ("Internal error in bif_st_polyline(), memory can be corrupted");
    }
  geo_calc_bounding (res, GEO_CALC_BOUNDING_DO_ALL);
  return (caddr_t)res;
}

caddr_t
bif_st_x (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  geo_t * g = bif_geo_arg (qst, args, 0, "st_x", GEO_ARG_NULLABLE | GEO_POINT);
  return ((NULL == g) ? NEW_DB_NULL : box_double (Xkey(g)));
}

caddr_t
bif_st_y (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  geo_t * g = bif_geo_arg (qst, args, 0, "st_y", GEO_ARG_NULLABLE | GEO_POINT);
  return ((NULL == g) ? NEW_DB_NULL : box_double (Ykey(g)));
}

caddr_t
bif_st_z (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  geo_t * g = bif_geo_arg (qst, args, 0, "st_z", GEO_ARG_NULLABLE | GEO_POINT);
  return (((NULL == g) || !(GEO_A_Z & g->geo_flags)) ? NEW_DB_NULL : box_double (Zkey(g)));
}

caddr_t
bif_st_m (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  geo_t * g = bif_geo_arg (qst, args, 0, "st_m", GEO_ARG_NULLABLE | GEO_POINT);
  return (((NULL == g) || !(GEO_A_M & g->geo_flags)) ? NEW_DB_NULL : box_double (Mkey(g)));
}

caddr_t
bif_st_xmin (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  geo_t * g = bif_geo_arg (qst, args, 0, "st_xmin", GEO_ARG_ANY_NULLABLE);
  if (NULL == g)
    return box_double (geoc_FARAWAY);
  if (GEO_POINT == GEO_TYPE_NO_ZM (g->geo_flags))
    {
      if (geoc_FARAWAY == Xkey(g))
        return box_double (geoc_FARAWAY);
      return box_double (Xkey(g));
    }
  return box_double (g->XYbox.Xmin);
}

caddr_t
bif_st_xmax (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  geo_t * g = bif_geo_arg (qst, args, 0, "st_xmax", GEO_ARG_ANY_NULLABLE);
  if (NULL == g)
    return box_double (geoc_FARAWAY);
  if (GEO_POINT == GEO_TYPE_NO_ZM (g->geo_flags))
    {
      if (geoc_FARAWAY == Xkey(g))
        return box_double (geoc_FARAWAY);
      return box_double (Xkey(g));
    }
  return box_double (g->XYbox.Xmax);
}

caddr_t
bif_st_ymin (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  geo_t * g = bif_geo_arg (qst, args, 0, "st_ymin", GEO_ARG_ANY_NULLABLE);
  if (NULL == g)
    return box_double (geoc_FARAWAY);
  if (GEO_POINT == GEO_TYPE_NO_ZM (g->geo_flags))
    {
      if (geoc_FARAWAY == Xkey(g)) /* yes, Xkey here and not Ykey */
        return box_double (geoc_FARAWAY);
      return box_double (Ykey(g));
    }
  return box_double (g->XYbox.Ymin);
}

caddr_t
bif_st_ymax (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  geo_t * g = bif_geo_arg (qst, args, 0, "st_ymax", GEO_ARG_ANY_NULLABLE);
  if (NULL == g)
    return box_double (geoc_FARAWAY);
  if (GEO_POINT == GEO_TYPE_NO_ZM (g->geo_flags))
    {
      if (geoc_FARAWAY == Xkey(g)) /* yes, Xkey here and not Ykey */
        return box_double (geoc_FARAWAY);
      return box_double (Ykey(g));
    }
  return box_double (g->XYbox.Ymax);
}

geo_ZMbox_t *
geo_get_zmbox_or_null (geo_t *g, int coords_needed)
{
  if (NULL == g)
    return NULL;
  if ((0 == (coords_needed & (GEO_A_Z | GEO_A_M))) || (coords_needed & ~(g->geo_flags)))
    return NULL;
  if (GEO_POINT == GEO_TYPE_NO_ZM (g->geo_flags))
    return &(g->_.point.point_ZMbox);
  if ((GEO_A_COMPOUND | GEO_A_RINGS | GEO_A_MULTI | GEO_A_ARRAY) & g->geo_flags)
    return &(g->_.parts.parts_ZMbox);
  return &(g->_.pline.pline_ZMbox);
}

caddr_t
bif_st_zmin (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  geo_t * g = bif_geo_arg (qst, args, 0, "st_zmin", GEO_ARG_ANY_NULLABLE);
  geo_ZMbox_t *zm = geo_get_zmbox_or_null (g, GEO_A_Z);
  if (NULL == zm)
    return box_double (geoc_FARAWAY);
  return box_double (zm->Zmin);
}

caddr_t
bif_st_zmax (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  geo_t * g = bif_geo_arg (qst, args, 0, "st_zmax", GEO_ARG_ANY_NULLABLE);
  geo_ZMbox_t *zm = geo_get_zmbox_or_null (g, GEO_A_Z);
  if (NULL == zm)
    return box_double (geoc_FARAWAY);
  return box_double (zm->Zmax);
}


caddr_t
bif_st_mmin (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  geo_t * g = bif_geo_arg (qst, args, 0, "st_mmin", GEO_ARG_ANY_NULLABLE);
  geo_ZMbox_t *zm = geo_get_zmbox_or_null (g, GEO_A_M);
  if (NULL == zm)
    return box_double (geoc_FARAWAY);
  return box_double (zm->Mmin);
}

caddr_t
bif_st_mmax (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  geo_t * g = bif_geo_arg (qst, args, 0, "st_mmax", GEO_ARG_ANY_NULLABLE);
  geo_ZMbox_t *zm = geo_get_zmbox_or_null (g, GEO_A_M);
  if (NULL == zm)
    return box_double (geoc_FARAWAY);
  return box_double (zm->Mmax);
}

caddr_t
bif_st_zmflag (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  geo_t * g = bif_geo_arg (qst, args, 0, "st_zmflag", GEO_ARG_ANY_NULLABLE);
  if (NULL == g)
    return NEW_DB_NULL;
/* Bit 1 for M and bit 2 for Z, not vica versa, is what PostGIS sets. Believe it or not, bit 1 for M is not an error */
  return (caddr_t)((ptrlong)(((g->geo_flags & GEO_A_M) ? 1 : 0) | ((g->geo_flags & GEO_A_Z) ? 2 : 0)));
}

caddr_t
bif_st_srid (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  geo_t * g = bif_geo_arg (qst, args, 0, "st_srid", GEO_ARG_ANY_NULLABLE);
  if (NULL == g)
    return NEW_DB_NULL;
  return box_num (GEO_SRID(g->geo_srcode));
}


caddr_t
bif_st_setsrid (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  geo_t *g = bif_geo_arg (qst, args, 0, "st_setsrid", GEO_ARG_ANY_NULLABLE), *cp;
  int srid;
  if (NULL == g)
    return NEW_DB_NULL;
  srid = bif_long_arg (qst, args, 1, "st_setsrid");
  cp = (geo_t*)box_copy ((caddr_t)g);
  cp->geo_srcode = GEO_SRCODE_OF_SRID(srid);
  return (caddr_t)cp;
}


caddr_t
bif_st_distance (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  geo_t * g1 = bif_geo_arg (qst, args, 0, "st_distance", GEO_POINT);
  geo_t * g2 = bif_geo_arg (qst, args, 1, "st_distance", GEO_POINT);
  return box_double (geo_distance (g1->geo_srcode, Xkey(g1), Ykey(g1), Xkey(g2), Ykey(g2)));
}


caddr_t
bif_geo_pred (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args, char * f, int op)
{
  geo_t * g1 = bif_geo_arg (qst, args, 0, f, GEO_ARG_ANY_NULLABLE);
  geo_t * g2 = bif_geo_arg (qst, args, 1, f, GEO_ARG_ANY_NULLABLE);
  double prec = 0;
  if (BOX_ELEMENTS (args) > 2)
    prec = bif_double_arg (qst, args, 2, f);
  return box_num (geo_pred (g1, g2, op, prec));
}

caddr_t
bif_st_contains (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return bif_geo_pred (qst, err_ret, args, "st_contains", GSOP_CONTAINS);
}

caddr_t
bif_st_may_contain (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return bif_geo_pred (qst, err_ret, args, "st_may_contain", GSOP_MAY_CONTAIN);
}

caddr_t
bif_st_within (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return bif_geo_pred (qst, err_ret, args, "st_within", GSOP_WITHIN);
}

caddr_t
bif_st_intersects (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return bif_geo_pred (qst, err_ret, args, "st_intersects", GSOP_INTERSECTS);
}

caddr_t
bif_st_may_intersect (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return bif_geo_pred (qst, err_ret, args, "st_may_intersect", GSOP_MAY_INTERSECT);
}

caddr_t
bif_st_astext (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  geo_t * g = bif_geo_arg (qst, args, 0, "st_wkt", GEO_ARG_ANY_NONNULL);
  return geo_wkt ((caddr_t)g);
}

caddr_t
bif_is_geometry (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t x = bif_arg_unrdf (qst, args, 0, "isgeometry");
  return box_num (DV_GEO == DV_TYPE_OF (x));
}


int
geo_point_intersects_XYbox (geo_srcode_t srcode, geoc pX, geoc pY, geo_XYbox_t *b, double prec)
{
  if (0 < prec)
    {
      geoc boxproximaX = ((pX > b->Xmax) ? b->Xmax : ((pX < b->Xmin) ? b->Xmin : pX));
      geoc boxproximaY = ((pY > b->Ymax) ? b->Ymax : ((pY < b->Ymin) ? b->Ymin : pY));
      if (prec < geo_distance (srcode, pX, pY, boxproximaX, boxproximaY))
        return 0;
    }
  return ((pX >= b->Xmin) && (pY >= b->Ymin) && (pX <= b->Xmax) && (pY <= b->Ymax));
}

int
geo_point_intersects_line (geo_srcode_t srcode, geoc pX, geoc pY, geoc p1X, geoc p1Y, geoc p2X, geoc p2Y, double prec)
{
  if ((0 < prec) && GEO_SR_SPHEROID_DEGREES (srcode))
    {
      double lat_prec_deg, lon_to_lat;
      GEO_SET_LAT_DEG_BY_KM (lat_prec_deg, prec);
      lon_to_lat = GEO_LON_TO_LAT_PER_DEG_RATIO((p1Y + p2Y) / 2);
      return ((lat_prec_deg >= dist_from_point_to_line_segment (pX*lon_to_lat, pY, p1X*lon_to_lat, p1Y, p2X*lon_to_lat, p2Y)) ? 1 : 0);
    }
  return ((prec >= dist_from_point_to_line_segment (pX, pY, p1X, p1Y, p2X, p2Y)) ? 1 : 0);
}

#define GEO_SCALAR_PRODUCT(oX,oY,aX,aY,bX,bY) (((aX)-(oX))*((bY)-(oY)) - ((aY)-(oY))*((bX)-(oX)))
#define GEOC_SWAP(a,b) do { geoc swap = (a); (a) = (b); (b) = swap; } while (0)
#define GEOC_MAX(a,b) (((a) > (b)) ? (a) : (b))
#define GEOC_MIN(a,b) (((a) < (b)) ? (a) : (b))
int
geo_line_intersects_XYbox (geo_srcode_t srcode, geoc p1X, geoc p1Y, geoc p2X, geoc p2Y, geo_XYbox_t *b, double prec)
{
  geoc bXmin, bXmax, bYmin, bYmax;
  if (GEO_XYBOX_IS_EMPTY_OR_FARAWAY(*b))
    return 0;
  if ((0 < prec) && GEO_SR_SPHEROID_DEGREES (srcode))
    {
      geoc lat_prec_deg, lon_prec_deg;
      GEO_SET_LAT_DEG_BY_KM (lat_prec_deg, prec);
      GEO_SET_LON_DEG_BY_KM (lon_prec_deg, prec, ((b->Ymax + b->Ymin) / 2));
      bXmin = b->Xmin - lon_prec_deg; bXmax = b->Xmax + lon_prec_deg;
      bYmin = b->Ymin - lat_prec_deg; bYmax = b->Ymax + lat_prec_deg;
    }
  else
    {
      bXmin = b->Xmin-prec; bXmax = b->Xmax+prec;
      bYmin = b->Ymin-prec; bYmax = b->Ymax+prec;
    }
  if (p1X > p2X)
    {
      GEOC_SWAP (p1X, p2X);
      GEOC_SWAP (p1Y, p2Y);
    }
  if ((p1X > bXmax) || (p2X < bXmin))
    return 0;
  if (p1Y < p2Y)
    { /* "/" orientation of line means check for intersection with "\" diagonal of bbox */
      if ((p1Y > bYmax) || (p2Y < bYmin))
        return 0;
      if ((p1Y >= bYmin) && (p1Y <= bYmax) && (p1X >= bXmin) && (p1X <= bXmax))
        return 1;
      if ((p2Y >= bYmin) && (p2Y <= bYmax) && (p2X >= bXmin) && (p2X <= bXmax))
        return 1;
      if (GEO_SCALAR_PRODUCT (p1X,p1Y, p2X,p2Y, bXmax,bYmin) * GEO_SCALAR_PRODUCT (p1X,p1Y, p2X,p2Y, bXmin,bYmax) <= 0)
        return 1;
    }
  else
    { /* "\" orientation of line means check for intersection with "/" diagonal of bbox */
      if ((p2Y > bYmax) || (p1Y < bYmin))
        return 0;
      if ((p1Y >= bYmin) && (p1Y <= bYmax) && (p1X >= bXmin) && (p1X <= bXmax))
        return 1;
      if ((p2Y >= bYmin) && (p2Y <= bYmax) && (p2X >= bXmin) && (p2X <= bXmax))
        return 1;
      if (GEO_SCALAR_PRODUCT (p1X,p1Y, p2X,p2Y, bXmin,bYmin) * GEO_SCALAR_PRODUCT (p1X,p1Y, p2X,p2Y, bXmax,bYmax) <= 0)
        return 1;
      return 0;
    }
  return 0;
}

int
geo_range_intersects_range (geoc p1c, geoc p2c, geoc q3c, geoc q4c, double prec_norm)
{
  if (p1c > p2c) GEOC_SWAP (p1c, p2c);
  if (q3c > q4c) GEOC_SWAP (q3c, q4c);
  if (GEOC_MAX (p1c, q3c) + prec_norm <= GEOC_MIN (p2c, q4c))
    return 1;
  return 0;
}

int
geo_line_intersects_line (geo_srcode_t srcode, geoc p1X, geoc p1Y, geoc p2X, geoc p2Y, geoc q3X, geoc q3Y, geoc q4X, geoc q4Y, double prec)
{
  double sc1, sc2;
  if ((0 < prec) && GEO_SR_SPHEROID_DEGREES (srcode))
    {
      double avglat, lat_prec_deg, lon_prec_deg, lon_to_lat;
      avglat = (fabs(p1Y+p2Y)+fabs(q3Y+q4Y)) / 4;
      lon_to_lat = GEO_LON_TO_LAT_PER_DEG_RATIO(avglat);
      GEO_SET_LAT_DEG_BY_KM (lat_prec_deg, prec);
      GEO_SET_LON_DEG_BY_KM (lon_prec_deg, prec, avglat);
      if (!geo_range_intersects_range (p1X, p2X, q3X, q4X, lon_prec_deg))
        return 0;
      if (!geo_range_intersects_range (p1Y, p2Y, q3Y, q4Y, lat_prec_deg))
        return 0;
      sc1 = GEO_SCALAR_PRODUCT(p1X*lon_to_lat, p1Y, p2X*lon_to_lat, p2Y, q3X*lon_to_lat, q3Y);
      sc2 = GEO_SCALAR_PRODUCT(p1X*lon_to_lat, p1Y, p2X*lon_to_lat, p2Y, q4X*lon_to_lat, q4Y);
      if (sc1 * sc2 > 0)
        {
          return 0;
        }
      sc1 = GEO_SCALAR_PRODUCT(q3X*lon_to_lat, q3Y, q4X*lon_to_lat, q4Y, p1X*lon_to_lat, p1Y);
      sc2 = GEO_SCALAR_PRODUCT(q3X*lon_to_lat, q3Y, q4X*lon_to_lat, q4Y, p2X*lon_to_lat, p2Y);
      if (sc1 * sc2 > 0)
        return 0;
      return 1;
    }
  if (!geo_range_intersects_range (p1X, p2X, q3X, q4X, prec))
    return 0;
  if (!geo_range_intersects_range (p1Y, p2Y, q3Y, q4Y, prec))
    return 0;
  sc1 = GEO_SCALAR_PRODUCT(p1X, p1Y, p2X, p2Y, q3X, q3Y);
  sc2 = GEO_SCALAR_PRODUCT(p1X, p1Y, p2X, p2Y, q4X, q4Y);
  if (sc1 * sc2 > 0)
    return 0;
  sc1 = GEO_SCALAR_PRODUCT(q3X, q3Y, q4X, q4Y, p1X, p1Y);
  sc2 = GEO_SCALAR_PRODUCT(q3X, q3Y, q4X, q4Y, p2X, p2Y);
  if (sc1 * sc2 > 0)
    return 0;
  return 1;
}

int
geo_point_intersects (geo_srcode_t srcode, geoc pX, geoc pY, geo_t *g2, double prec)
{
  int cctr, ictr, itemctr;
  if (GEO_POINT == GEO_TYPE_NO_ZM (g2->geo_flags))
    {
      if (prec >= geo_distance (srcode, pX, pY, Xkey(g2), Ykey(g2)))
        return 1;
      return 0;
    }
  if (!geo_point_intersects_XYbox (srcode, pX, pY, &(g2->XYbox), prec))
    return 0;
  if ((GEO_A_MULTI | GEO_A_ARRAY) & g2->geo_flags)
    {
      if (GEO_IS_CHAINBOXED & g2->geo_flags)
        {
          geo_chainbox_t *g2gcb = g2->_.parts.parts_gcb;
          for (cctr = 0; cctr < g2gcb->gcb_box_count; cctr ++)
            {
              
              if (!geo_point_intersects_XYbox (srcode, pX, pY, g2gcb->gcb_boxes+cctr, prec))
                continue;
              for (ictr = 0; ictr < g2gcb->gcb_step; ictr++)
                {
                  itemctr = cctr * g2gcb->gcb_step + ictr;
                  if (itemctr >= g2->_.parts.len)
                    return 0;
                  if (geo_point_intersects (srcode, pX, pY, g2->_.parts.items[itemctr], prec))
                    return 1;
                }
            }
        }
      else
        {
          for (itemctr = 0; itemctr < g2->_.parts.len; itemctr++)
            {
              if (geo_point_intersects (srcode, pX, pY, g2->_.parts.items[itemctr], prec))
                return 1;
            }
        }
      return 0;
    }
  if (GEO_A_RINGS & g2->geo_flags)
    {
      if (0 == g2->_.parts.len)
        return 0;
      if (!geo_point_intersects (srcode, pX, pY, g2->_.parts.items[0], prec))
        return 0;
      for (itemctr = 1; itemctr < g2->_.parts.len; itemctr++)
        {
          if (geo_point_intersects (srcode, pX, pY, g2->_.parts.items[itemctr], prec))
            return 0;
        }
      return 1;
    }
  switch (GEO_TYPE_NO_ZM (g2->geo_flags))
    {
    case GEO_BOX:
      return 1;
    case GEO_LINESTRING:
      if (GEO_IS_CHAINBOXED & g2->geo_flags)
        {
          geo_chainbox_t *g2gcb = g2->_.pline.pline_gcb;
          for (cctr = 0; cctr < g2gcb->gcb_box_count; cctr ++)
            {
              if (!geo_point_intersects_XYbox (srcode, pX, pY, g2gcb->gcb_boxes+cctr, prec))
                continue;
              for (ictr = 0; ictr < g2gcb->gcb_step; ictr++)
                {
                  itemctr = cctr * g2gcb->gcb_step + ictr;
                  if (itemctr >= g2->_.pline.len - 1)
                    return 0;
                  if (geo_point_intersects_line (srcode, pX, pY, g2->_.pline.Xs[itemctr], g2->_.pline.Ys[itemctr], g2->_.pline.Xs[itemctr+1], g2->_.pline.Ys[itemctr+1], prec))
                    return 1;
                }
            }
        }
      else
        {
          for (itemctr = 0; itemctr < g2->_.pline.len - 1; itemctr++)
            {
              if (geo_point_intersects_line (srcode, pX, pY, g2->_.pline.Xs[itemctr], g2->_.pline.Ys[itemctr], g2->_.pline.Xs[itemctr+1], g2->_.pline.Ys[itemctr+1], prec))
                return 1;
            }
        }
      return 0;
    case GEO_POINTLIST:
      if (GEO_IS_CHAINBOXED & g2->geo_flags)
        {
          geo_chainbox_t *g2gcb = g2->_.pline.pline_gcb;
          for (cctr = 0; cctr < g2gcb->gcb_box_count; cctr ++)
            {
              if (!geo_point_intersects_XYbox (srcode, pX, pY, g2gcb->gcb_boxes+cctr, prec))
                continue;
              for (ictr = 0; ictr < g2gcb->gcb_step; ictr++)
                {
                  itemctr = cctr * g2gcb->gcb_step + ictr;
                  if (itemctr >= g2->_.pline.len)
                    return 0;
                  if (prec >= geo_distance (srcode, pX, pY, g2->_.pline.Xs[itemctr], g2->_.pline.Ys[itemctr]))
                    return 1;
                }
            }
        }
      else
        {
          for (itemctr = 0; itemctr < g2->_.pline.len; itemctr++)
            {
              if (prec >= geo_distance (srcode, pX, pY, g2->_.pline.Xs[itemctr], g2->_.pline.Ys[itemctr]))
                return 1;
            }
        }
      return 0;
    case GEO_RING:
      {
        int inoutside = geo_XY_inoutside_ring (pX, pY, g2);
        if ((GEO_INOUTSIDE_IN | GEO_INOUTSIDE_BORDER) & inoutside)
          return 1;
        return 0;
      }
    }
  sqlr_new_error ("42000", "GEO..", "for after check of geo intersects, and a given point, supported types of second argument are POINT, BOX, POLYGON, LINESTRING, POINTLIST, and their MULTI... and COLLECTIONs");
  return 0;
}

int
geo_line_intersects (geo_srcode_t srcode, geoc p1X, geoc p1Y, geoc p2X, geoc p2Y, geo_t *g2, double prec)
{
  int cctr, ictr, itemctr;
  if (GEO_POINT == GEO_TYPE_NO_ZM (g2->geo_flags))
    return geo_point_intersects_line (srcode, Xkey(g2), Ykey(g2), p1X, p1Y, p2X, p2Y, prec);
  if (!geo_line_intersects_XYbox (srcode, p1X, p1Y, p2X, p2Y, &(g2->XYbox), prec))
    return 0;
  if ((GEO_A_MULTI | GEO_A_ARRAY) & g2->geo_flags)
    {
      if (GEO_IS_CHAINBOXED & g2->geo_flags)
        {
          geo_chainbox_t *g2gcb = g2->_.parts.parts_gcb;
          for (cctr = 0; cctr < g2gcb->gcb_box_count; cctr ++)
            {
              
              if (!geo_line_intersects_XYbox (srcode, p1X, p1Y, p2X, p2Y, g2gcb->gcb_boxes+cctr, prec))
                continue;
              for (ictr = 0; ictr < g2gcb->gcb_step; ictr++)
                {
                  itemctr = cctr * g2gcb->gcb_step + ictr;
                  if (itemctr >= g2->_.parts.len)
                    return 0;
                  if (geo_line_intersects (srcode, p1X, p1Y, p2X, p2Y, g2->_.parts.items[itemctr], prec))
                    return 1;
                }
            }
        }
      else
        {
          for (itemctr = 0; itemctr < g2->_.parts.len; itemctr++)
            {
              if (geo_line_intersects (srcode, p1X, p1Y, p2X, p2Y, g2->_.parts.items[itemctr], prec))
                return 1;
            }
        }
      return 0;
    }
  if (GEO_A_RINGS & g2->geo_flags)
    {
      if (0 == g2->_.parts.len)
        return 0;
      if (!geo_line_intersects (srcode, p1X, p1Y, p2X, p2Y, g2->_.parts.items[0], prec))
        return 0;
      for (itemctr = 1; itemctr < g2->_.parts.len; itemctr++)
        {
          if (!geo_line_intersects (srcode, p1X, p1Y, p2X, p2Y, g2->_.parts.items[itemctr], prec))
            continue;
        }
      goto unsupported;
    }
  switch (GEO_TYPE_NO_ZM (g2->geo_flags))
    {
    case GEO_BOX:
      return 1;
    case GEO_LINESTRING:
      if (GEO_IS_CHAINBOXED & g2->geo_flags)
        {
          geo_chainbox_t *g2gcb = g2->_.pline.pline_gcb;
          for (cctr = 0; cctr < g2gcb->gcb_box_count; cctr ++)
            {
              if (!geo_line_intersects_XYbox (srcode, p1X, p1Y, p2X, p2Y, g2gcb->gcb_boxes+cctr, prec))
                continue;
              for (ictr = 0; ictr < g2gcb->gcb_step; ictr++)
                {
                  itemctr = cctr * g2gcb->gcb_step + ictr;
                  if (itemctr >= g2->_.pline.len - 1)
                    return 0;
                  if (geo_line_intersects_line (srcode, p1X, p1Y, p2X, p2Y, g2->_.pline.Xs[itemctr], g2->_.pline.Ys[itemctr], g2->_.pline.Xs[itemctr+1], g2->_.pline.Ys[itemctr+1], prec))
                    return 1;
                }
            }
        }
      else
        {
          for (itemctr = 0; itemctr < g2->_.pline.len - 1; itemctr++)
            {
              if (geo_line_intersects_line (srcode, p1X, p1Y, p2X, p2Y, g2->_.pline.Xs[itemctr], g2->_.pline.Ys[itemctr], g2->_.pline.Xs[itemctr+1], g2->_.pline.Ys[itemctr+1], prec))
                return 1;
            }
        }
      return 0;
    case GEO_POINTLIST:
      if (GEO_IS_CHAINBOXED & g2->geo_flags)
        {
          geo_chainbox_t *g2gcb = g2->_.pline.pline_gcb;
          for (cctr = 0; cctr < g2gcb->gcb_box_count; cctr ++)
            {
              if (!geo_line_intersects_XYbox (srcode, p1X, p1Y, p2X, p2Y, g2gcb->gcb_boxes+cctr, prec))
                continue;
              for (ictr = 0; ictr < g2gcb->gcb_step; ictr++)
                {
                  itemctr = cctr * g2gcb->gcb_step + ictr;
                  if (itemctr >= g2->_.pline.len)
                    return 0;
                  if (geo_point_intersects_line (srcode, g2->_.pline.Xs[itemctr], g2->_.pline.Ys[itemctr], p1X, p1Y, p2X, p2Y, prec))
                    return 1;
                }
            }
        }
      else
        {
          for (itemctr = 0; itemctr < g2->_.pline.len; itemctr++)
            {
              if (geo_point_intersects_line (srcode, g2->_.pline.Xs[itemctr], g2->_.pline.Ys[itemctr], p1X, p1Y, p2X, p2Y, prec))
                return 1;
            }
        }
      return 0;
    case GEO_RING:
      {
        int inoutside;
        inoutside = geo_XY_inoutside_ring (p1X, p1Y, g2);
        if ((GEO_INOUTSIDE_IN | GEO_INOUTSIDE_BORDER) & inoutside)
          return 1;
        inoutside = geo_XY_inoutside_ring (p2X, p2Y, g2);
        if ((GEO_INOUTSIDE_IN | GEO_INOUTSIDE_BORDER) & inoutside)
          return 1;
        if (GEO_IS_CHAINBOXED & g2->geo_flags)
          {
            geo_chainbox_t *g2gcb = g2->_.pline.pline_gcb;
            for (cctr = 0; cctr < g2gcb->gcb_box_count; cctr ++)
              {
                if (!geo_line_intersects_XYbox (srcode, p1X, p1Y, p2X, p2Y, g2gcb->gcb_boxes+cctr, prec))
                  continue;
                for (ictr = 0; ictr < g2gcb->gcb_step; ictr++)
                  {
                    itemctr = cctr * g2gcb->gcb_step + ictr;
                    if (itemctr >= (g2->_.pline.len - 1))
                      return 0;
                    if (geo_line_intersects_line (srcode, g2->_.pline.Xs[itemctr], g2->_.pline.Ys[itemctr], g2->_.pline.Xs[itemctr+1], g2->_.pline.Ys[itemctr+1], p1X, p1Y, p2X, p2Y, prec))
                      return 1;
                  }
              }
          }
        else
          {
            for (itemctr = 0; itemctr < g2->_.pline.len - 1; itemctr++)
              {
                if (geo_line_intersects_line (srcode, g2->_.pline.Xs[itemctr], g2->_.pline.Ys[itemctr], g2->_.pline.Xs[itemctr+1], g2->_.pline.Ys[itemctr+1], p1X, p1Y, p2X, p2Y, prec))
                  return 1;
              }
          }
        return 0;
      }
    }
unsupported:
  sqlr_new_error ("42000", "GEO..", "The check for spatial intersection is not implemented for a line and a shape of type %d", g2->geo_srcode);
  return 0;
}


int
geo_may_intersect_XYbox (geo_t *g, geo_XYbox_t *b, double prec)
{
  if (GEO_POINT == GEO_TYPE_NO_ZM (g->geo_flags))
    return geo_point_intersects_XYbox (g->geo_srcode, Xkey(g), Ykey(g), b, prec);
  if ( (g->XYbox.Xmax < b->Xmin - prec)
    || (g->XYbox.Xmin > b->Xmax + prec)
    || (g->XYbox.Ymax < b->Ymin - prec)
    || (g->XYbox.Ymin > b->Ymax + prec) )
    return 0;
  return 1;
}

int
geo_pred (geo_t * g1, geo_t * g2, int op, double prec)
{
  int cctr, ictr, itemctr;
  if (GSOP_WITHIN == op)
    {
      geo_t * swap;
      swap = g1; g1 = g2; g2 = swap;
      op = GSOP_CONTAINS;
    }
  switch (op)
    {
    case GSOP_INTERSECTS:
      {
        if ((NULL == g1) || (NULL == g2))
          return 0;
        if (GEO_TYPE_NO_ZM (g1->geo_flags) > GEO_TYPE_NO_ZM (g2->geo_flags))
          { geo_t * swap; swap = g1; g1 = g2; g2 = swap; }
        if (GEO_POINT == GEO_TYPE_NO_ZM (g1->geo_flags))
          {
            if (GEO_POINT == GEO_TYPE_NO_ZM (g2->geo_flags))
              {
                if (prec >= geo_distance (g1->geo_srcode, Xkey(g1), Ykey(g1), Xkey(g2), Ykey(g2)))
                  return 1;
                return 0;
              }
            if (!geo_point_intersects_XYbox (g1->geo_srcode, Xkey(g1), Ykey(g1), &(g2->XYbox), prec))
              return 0;
            if (GEO_BOX == GEO_TYPE_NO_ZM (g2->geo_flags))
              return 1;
            return geo_point_intersects (g1->geo_srcode, Xkey(g1), Ykey(g1), g2, prec);
          }
        if (!geo_may_intersect_XYbox (g1, &(g2->XYbox), prec))
          return 0;
        if (GEO_BOX == GEO_TYPE_NO_ZM (g1->geo_flags))
          {
            if (GEO_BOX == GEO_TYPE_NO_ZM (g2->geo_flags))
              {
                if (0 < prec)
                  {
                    if ( (g1->XYbox.Xmax < g2->XYbox.Xmin)
                      || (g1->XYbox.Xmin > g2->XYbox.Xmax)
                      || (g1->XYbox.Ymax < g2->XYbox.Ymin)
                      || (g1->XYbox.Ymin > g2->XYbox.Ymax) )
                      { /* corners/sides at close distance are possible */
                        return 1; /* rough estimation */
                      }
                  }
                return 1;
              }
            goto unsupported_intersects;
          }
        if ((GEO_A_MULTI | GEO_A_ARRAY) & g2->geo_flags)
          {
            if (GEO_IS_CHAINBOXED & g2->geo_flags)
              {
                geo_chainbox_t *g2gcb = g2->_.parts.parts_gcb;
                for (cctr = 0; cctr < g2gcb->gcb_box_count; cctr ++)
                  {
                    
                    if (!geo_may_intersect_XYbox (g1, g2gcb->gcb_boxes+cctr, prec))
                      continue;
                    for (ictr = 0; ictr < g2gcb->gcb_step; ictr++)
                      {
                        itemctr = cctr * g2gcb->gcb_step + ictr;
                        if (itemctr >= g2->_.parts.len)
                          return 0;
                        if (geo_pred (g2->_.parts.items[itemctr], g1, op, prec))
                          return 1;
                      }
                  }
              }
            else
              {
                for (itemctr = 0; itemctr < g2->_.parts.len; itemctr++)
                  {
                    if (geo_pred (g2->_.parts.items[itemctr], g1, op, prec))
                      return 1;
                  }
              }
            return 0;
          }
        if ((GEO_A_MULTI | GEO_A_ARRAY) & g1->geo_flags)
          {
            if (GEO_IS_CHAINBOXED & g1->geo_flags)
              {
                geo_chainbox_t *g1gcb = g1->_.parts.parts_gcb;
                for (cctr = 0; cctr < g1gcb->gcb_box_count; cctr ++)
                  {
                    
                    if (!geo_may_intersect_XYbox (g2, g1gcb->gcb_boxes+cctr, prec))
                      continue;
                    for (ictr = 0; ictr < g1gcb->gcb_step; ictr++)
                      {
                        itemctr = cctr * g1gcb->gcb_step + ictr;
                        if (itemctr >= g1->_.parts.len)
                          return 0;
                        if (geo_pred (g1->_.parts.items[itemctr], g2, op, prec))
                          return 1;
                      }
                  }
              }
            else
              {
                for (itemctr = 0; itemctr < g1->_.parts.len; itemctr++)
                  {
                    if (geo_pred (g1->_.parts.items[itemctr], g2, op, prec))
                      return 1;
                  }
              }
            return 0;
          }
        if (GEO_A_RINGS & g2->geo_flags)
          {
            if (0 == g2->_.parts.len)
              return 0;
            if (!geo_pred (g2->_.parts.items[0], g1, op, prec))
              return 0;
            for (itemctr = 1; itemctr < g2->_.parts.len; itemctr++)
              {
                if (!geo_may_intersect_XYbox (g1, &(g2->_.parts.items[itemctr]->XYbox), prec))
                  continue;
                goto unsupported_intersects;
              }
            return 1;
          }
        switch (GEO_TYPE_NO_ZM (g1->geo_flags))
          {
          case GEO_LINESTRING:
            if (GEO_IS_CHAINBOXED & g1->geo_flags)
              {
                geo_chainbox_t *g1gcb = g1->_.pline.pline_gcb;
                for (cctr = 0; cctr < g1gcb->gcb_box_count; cctr ++)
                  {
                    
                    if (!geo_may_intersect_XYbox (g2, g1gcb->gcb_boxes+cctr, prec))
                      continue;
                    for (ictr = 0; ictr < g1gcb->gcb_step; ictr++)
                      {
                        itemctr = cctr * g1gcb->gcb_step + ictr;
                        if (itemctr >= (g1->_.pline.len - 1))
                          return 0;
                        if (geo_line_intersects (g1->geo_srcode, g1->_.pline.Xs[itemctr], g1->_.pline.Ys[itemctr], g1->_.pline.Xs[itemctr+1], g1->_.pline.Ys[itemctr+1], g2, prec))
                          return 1;
                      }
                  }
              }
            else
              {
                for (itemctr = 0; itemctr < g1->_.pline.len - 1; itemctr++)
                  {
                    if (geo_line_intersects (g1->geo_srcode, g1->_.pline.Xs[itemctr], g1->_.pline.Ys[itemctr], g1->_.pline.Xs[itemctr+1], g1->_.pline.Ys[itemctr+1], g2, prec))
                      return 1;
                  }
              }
            return 0;
          case GEO_POINTLIST:
            if (GEO_IS_CHAINBOXED & g1->geo_flags)
              {
                geo_chainbox_t *g1gcb = g1->_.pline.pline_gcb;
                for (cctr = 0; cctr < g1gcb->gcb_box_count; cctr ++)
                  {
                    
                    if (!geo_may_intersect_XYbox (g2, g1gcb->gcb_boxes+cctr, prec))
                      continue;
                    for (ictr = 0; ictr < g1gcb->gcb_step; ictr++)
                      {
                        itemctr = cctr * g1gcb->gcb_step + ictr;
                        if (itemctr >= g1->_.pline.len)
                          return 0;
                        if (geo_point_intersects (g1->geo_srcode, g1->_.pline.Xs[itemctr], g1->_.pline.Ys[itemctr], g2, prec))
                          return 1;
                      }
                  }
              }
            else
              {
                for (itemctr = 0; itemctr < g1->_.pline.len; itemctr++)
                  {
                    if (geo_point_intersects (g1->geo_srcode, g1->_.pline.Xs[itemctr], g1->_.pline.Ys[itemctr], g2, prec))
                      return 1;
                  }
              }
            return 0;
          case GEO_RING:
            if (GEO_IS_CHAINBOXED & g1->geo_flags)
              {
                geo_chainbox_t *g1gcb = g1->_.pline.pline_gcb;
                for (cctr = 0; cctr < g1gcb->gcb_box_count; cctr ++)
                  {
                    
                    if (!geo_may_intersect_XYbox (g2, g1gcb->gcb_boxes+cctr, prec))
                      continue;
                    for (ictr = 0; ictr < g1gcb->gcb_step; ictr++)
                      {
                        itemctr = cctr * g1gcb->gcb_step + ictr;
                        if (itemctr >= g1->_.pline.len)
                          break;
                        if (geo_point_intersects (g1->geo_srcode, g1->_.pline.Xs[itemctr], g1->_.pline.Ys[itemctr], g2, prec))
                          return 1;
                      }
                  }
                for (cctr = 0; cctr < g1gcb->gcb_box_count; cctr ++)
                  {
                    
                    if (!geo_may_intersect_XYbox (g2, g1gcb->gcb_boxes+cctr, prec))
                      continue;
                    for (ictr = 0; ictr < g1gcb->gcb_step; ictr++)
                      {
                        itemctr = cctr * g1gcb->gcb_step + ictr;
                        if (itemctr >= (g1->_.pline.len - 1))
                          return 0;
                        if (geo_line_intersects (g1->geo_srcode, g1->_.pline.Xs[itemctr], g1->_.pline.Ys[itemctr], g1->_.pline.Xs[itemctr+1], g1->_.pline.Ys[itemctr+1], g2, prec))
                          return 1;
                      }
                  }
              }
            else
              {
                for (itemctr = 0; itemctr < g1->_.pline.len; itemctr++)
                  {
                    if (geo_point_intersects (g1->geo_srcode, g1->_.pline.Xs[itemctr], g1->_.pline.Ys[itemctr], g2, prec))
                      return 1;
                  }
                for (itemctr = 0; itemctr < g1->_.pline.len - 1; itemctr++)
                  {
                    if (geo_line_intersects (g1->geo_srcode, g1->_.pline.Xs[itemctr], g1->_.pline.Ys[itemctr], g1->_.pline.Xs[itemctr+1], g1->_.pline.Ys[itemctr+1], g2, prec))
                      return 1;
                  }
              }
            return 0;
          }
        goto unsupported_intersects;
      }
    case GSOP_MAY_INTERSECT:
      {
        if ((NULL == g1) || (NULL == g2))
          return 0;
        if (GEO_TYPE_NO_ZM (g1->geo_flags) > GEO_TYPE_NO_ZM (g2->geo_flags))
          { geo_t * swap; swap = g1; g1 = g2; g2 = swap; }
          if (GEO_POINT == GEO_TYPE_NO_ZM (g1->geo_flags))
            {
              if (GEO_POINT == GEO_TYPE_NO_ZM (g2->geo_flags))
                {
                  if (prec >= geo_distance (g1->geo_srcode, Xkey(g1), Ykey(g1), Xkey(g2), Ykey(g2)))
                    return 1;
                  return 0;
                }
              if (GEO_BOX == GEO_TYPE_NO_ZM (g2->geo_flags))
                {
                  geoc boxproximaX = ((Xkey(g1) > g2->XYbox.Xmax) ? g2->XYbox.Xmax : ((Xkey(g1) < g2->XYbox.Xmin) ? g2->XYbox.Xmin : Xkey(g1)));
                  geoc boxproximaY = ((Ykey(g1) > g2->XYbox.Ymax) ? g2->XYbox.Ymax : ((Ykey(g1) < g2->XYbox.Ymin) ? g2->XYbox.Ymin : Ykey(g1)));
                  if (prec >= geo_distance (g1->geo_srcode, Xkey(g1), Ykey(g1), boxproximaX, boxproximaY))
                    return 1;
                  return 0;
                }
              if ( (Xkey(g1) < g2->XYbox.Xmin - prec)
                || (Xkey(g1) > g2->XYbox.Xmax + prec)
                || (Ykey(g1) < g2->XYbox.Ymin - prec)
                || (Ykey(g1) > g2->XYbox.Ymax + prec) )
                return 0;
              return 1;
            }
        if ( (g1->XYbox.Xmax < g2->XYbox.Xmin - prec)
          || (g1->XYbox.Xmin > g2->XYbox.Xmax + prec)
          || (g1->XYbox.Ymax < g2->XYbox.Ymin - prec)
          || (g1->XYbox.Ymin > g2->XYbox.Ymax + prec) )
          return 0;
        return 1;
      }
    case GSOP_CONTAINS:
      {
        if ((NULL == g1) || (NULL == g2))
          return 0;
        if (GEO_POINT == GEO_TYPE_NO_ZM (g2->geo_flags))
          {
            if (GEO_POINT == GEO_TYPE_NO_ZM (g1->geo_flags))
              {
                if (prec >= geo_distance (g2->geo_srcode, Xkey(g2), Ykey(g2), Xkey(g1), Ykey(g1)))
                  return 1;
                return 0;
              }
            if (!geo_point_intersects_XYbox (g2->geo_srcode, Xkey(g2), Ykey(g2), &(g1->XYbox), prec))
              return 0;
            if (GEO_BOX == GEO_TYPE_NO_ZM (g1->geo_flags))
              return 1;
            return geo_point_intersects (g2->geo_srcode, Xkey(g2), Ykey(g2), g1, prec);
          }
        sqlr_new_error ("42000", "GEO..", "for geo contains, only \"shape contains point\" case is supported in current version");
        break;
      }
    case GSOP_MAY_CONTAIN:
      {
        if ((NULL == g1) || (NULL == g2))
          return 0;
          if (GEO_POINT == GEO_TYPE_NO_ZM (g2->geo_flags))
            {
              if (GEO_POINT == GEO_TYPE_NO_ZM (g1->geo_flags))
                {
                  if (prec >= geo_distance (g1->geo_srcode, Xkey(g1), Ykey(g1), Xkey(g2), Ykey(g2)))
                    return 1;
                  return 0;
                }
              if (GEO_BOX == GEO_TYPE_NO_ZM (g1->geo_flags))
                {
                  geoc boxproximaX = ((Xkey(g2) > g1->XYbox.Xmax) ? g1->XYbox.Xmax : ((Xkey(g2) < g1->XYbox.Xmin) ? g1->XYbox.Xmin : Xkey(g2)));
                  geoc boxproximaY = ((Ykey(g2) > g1->XYbox.Ymax) ? g1->XYbox.Ymax : ((Ykey(g2) < g1->XYbox.Ymin) ? g1->XYbox.Ymin : Ykey(g2)));
                  if (prec >= geo_distance (g1->geo_srcode, Xkey(g2), Ykey(g2), boxproximaX, boxproximaY))
                    return 1;
                  return 0;
                }
              if ( (Xkey(g2) < g1->XYbox.Xmin - prec)
                || (Xkey(g2) > g1->XYbox.Xmax + prec)
                || (Ykey(g2) < g1->XYbox.Ymin - prec)
                || (Ykey(g2) > g1->XYbox.Ymax + prec) )
                return 0;
              return 1;
            }
        if ( (g2->XYbox.Xmin < g1->XYbox.Xmin - prec)
          || (g2->XYbox.Xmax > g1->XYbox.Xmax + prec)
          || (g2->XYbox.Ymin < g1->XYbox.Ymin - prec)
          || (g2->XYbox.Ymax > g1->XYbox.Ymax + prec) )
          return 0;
        return 1;
      }
    }
unsupported_intersects:
  sqlr_new_error ("42000", "GEO..", "for after check of geo intersects, some shape types (e.g., polygon rings and curves) are not yet supported");
  return 0;
}

caddr_t
bif_st_ewkt_read (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  geo_t *res;
  caddr_t strg = bif_string_arg (qst, args, 0, "st_ewkt_read");
  caddr_t err = NULL;
  res = ewkt_parse (strg, &err);
  if (NULL != err)
    sqlr_resignal (err);
  geo_calc_bounding (res, GEO_CALC_BOUNDING_DO_ALL);
  return (caddr_t)res;
}

caddr_t
bif_http_st_ewkt (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  geo_t *g = bif_geo_arg (qst, args, 0, "http_st_ewkt", GEO_ARG_ANY_NONNULL);
  dk_session_t *ses = bif_strses_or_http_ses_arg (qst, args, 1, "http_st_ewkt");
  ewkt_print_sf12 (g, ses);
  return (caddr_t)NULL;
}

caddr_t
bif_http_st_dxf_entity (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  geo_t *g = bif_geo_arg (qst, args, 0, "http_st_dxf_entity", GEO_ARG_ANY_NULLABLE);
  caddr_t *attrs = bif_array_of_pointer_arg (qst, args, 1, "http_st_dxf_entity");
  dk_session_t *ses = bif_strses_or_http_ses_arg (qst, args, 2, "http_st_dxf_entity");
  if (NULL != g)
    geo_print_as_dxf_entity (g, attrs, ses);
  return (caddr_t)NULL;
}

caddr_t
bif_st_get_bounding_box (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  geo_t *g = bif_geo_arg (qst, args, 0, "st_get_bounding_box", GEO_ARG_ANY_NULLABLE);
  double prec_x = 0, prec_y = 0;
  int argcount = BOX_ELEMENTS (args);
  geo_t *res, xy;
  if (NULL == g)
    {
#if 0
      res = geo_alloc (GEO_BOX, 0, SRID_DEFAULT);
      GEO_XYBOX_SET_EMPTY (res->XYbox);
      return (caddr_t)res;
#else
      return NEW_DB_NULL;
#endif
    }
  if (2 <= argcount) prec_y = prec_x = bif_double_arg (qst, args, 1, "st_get_bounding_box");
  if (3 <= argcount) prec_y = bif_double_arg (qst, args, 2, "st_get_bounding_box");
  geo_get_bounding_XYbox (g, &xy, prec_x, prec_y);
  res = geo_alloc (GEO_BOX | (g->geo_flags & (GEO_A_Z | GEO_A_M)), 0, g->geo_srcode);
  res->XYbox = xy.XYbox;
  if (g->geo_flags & (GEO_A_Z | GEO_A_M))
    {
      geo_ZMbox_t *zm = geo_get_ZMbox_field (g);
      if (res->geo_flags & GEO_A_Z)
        {
          res->_.point.point_ZMbox.Zmin = zm->Zmin;
          res->_.point.point_ZMbox.Zmax = zm->Zmax;
        }
      if (res->geo_flags & GEO_A_M)
        {
          res->_.point.point_ZMbox.Mmin = zm->Mmin;
          res->_.point.point_ZMbox.Mmax = zm->Mmax;
        }
    }
  return (caddr_t)res;
}

caddr_t
bif_st_get_chainbox (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  geo_t *g = bif_geo_arg (qst, args, 0, "st_get_chainbox", GEO_ARG_ANY_NULLABLE);
  int ctr;
  geo_t **res;
  geo_chainbox_t *gcb;
  if (NULL == g)
    return NEW_DB_NULL;
  gcb = GEO_GCB_OR_NULL (g);
  if (NULL == gcb)
    return NEW_DB_NULL;
  res = (geo_t **) dk_alloc_list (gcb->gcb_box_count);
  for (ctr = 0; ctr < gcb->gcb_box_count; ctr++)
    {
      res[ctr] = geo_alloc (GEO_BOX | (g->geo_flags & GEO_IS_FLOAT), 0, GEO_SRID (g->geo_srcode));
      res[ctr]->XYbox = gcb->gcb_boxes[ctr];
    }
  return (caddr_t)res;
}

caddr_t
bif_st_dv_geo_length (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t buf = bif_string_arg (qst, args, 0, "st_dv_geo_length");
  long hl=0, l=0;
  dv_geo_length ((unsigned char *)buf, &hl, &l);
  return box_num (hl+l);
}

caddr_t
bif_geometry_type (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  geo_t *g = bif_geo_arg (qst, args, 0, "GeometryType", GEO_ARG_ANY_NULLABLE);
  ewkt_kwd_metas_t *metas;
  if (NULL == g)
    return NEW_DB_NULL;
  metas = ewkt_find_metas_by_geotype (GEO_TYPE (g->geo_flags));
  if (NULL == metas)
    sqlr_new_error ("22023", "GEO..", "Unsupported shape type %u, geometry instance is corrupted or created by Virtuoso server of later version", GEO_TYPE (g->geo_flags));
  return box_dv_short_string (metas->kwd_name);
  
}

caddr_t
bif_st_num_geometries (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  geo_t *g = bif_geo_arg (qst, args, 0, "ST_NumGeometries", GEO_ARG_ANY_NULLABLE);
  if (NULL == g)
    return NEW_DB_NULL;
  if (g->geo_flags & (GEO_A_MULTI | GEO_A_ARRAY))
    return box_num (g->_.parts.len);
  return box_num (1);
}

caddr_t
bif_st_geometry_n (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  geo_t *g = bif_geo_arg (qst, args, 0, "ST_GeometryN", GEO_ARG_ANY_NULLABLE);
  boxint idx = bif_long_arg (qst, args, 1, "ST_GeometryN");
  if (NULL == g)
    return NEW_DB_NULL;
  if (!(g->geo_flags & (GEO_A_MULTI | GEO_A_ARRAY)))
    return NEW_DB_NULL;
  if ((idx < 1) || (idx > g->_.parts.len))
    sqlr_new_error ("22023", "GEO..", "Invalid index value " BOXINT_FMT ", valid values for this geometery are 1 to %ld", (boxint)idx, (long)(g->_.parts.len));
  return (caddr_t)geo_copy (g->_.parts.items[idx-1]);
}

caddr_t
bif_st_exterior_ring (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  geo_t *g = bif_geo_arg (qst, args, 0, "ST_ExteriorRing", GEO_ARG_ANY_NULLABLE);
  if (NULL == g)
    return NEW_DB_NULL;
  if (!(g->geo_flags & GEO_A_RINGS) || (g->geo_flags & (GEO_A_MULTI | GEO_A_ARRAY)))
    return NEW_DB_NULL;
  return (caddr_t)geo_copy (g->_.parts.items[0]);
}
;

caddr_t
bif_st_num_interior_rings (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  geo_t *g = bif_geo_arg (qst, args, 0, "ST_NumInteriorRings", GEO_ARG_ANY_NULLABLE);
  if (NULL == g)
    return NEW_DB_NULL;
  if (!(g->geo_flags & GEO_A_RINGS))
    return NEW_DB_NULL;
  if (g->geo_flags & GEO_A_ARRAY)
    return NEW_DB_NULL;
  if (g->geo_flags & GEO_A_MULTI)
    {
      if (0 == g->_.parts.len)
        return box_num (0);
      return box_num (g->_.parts.items[0]->_.parts.len - 1);
    }
  return box_num (g->_.parts.len - 1);
}

caddr_t
bif_st_interior_ring_n (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  geo_t *g = bif_geo_arg (qst, args, 0, "ST_InteriorRingN", GEO_ARG_ANY_NULLABLE);
  boxint idx = bif_long_arg (qst, args, 1, "ST_InteriorRingN");
  if (NULL == g)
    return NEW_DB_NULL;
  if (!(g->geo_flags & GEO_A_RINGS) || (g->geo_flags & (GEO_A_MULTI | GEO_A_ARRAY)))
    return NEW_DB_NULL;
  if ((idx < 1) || (idx >= g->_.parts.len))
    {
#if 0
      sqlr_new_error ("22023", "GEO..", "Invalid index value " BOXINT_FMT ", valid values for this geometery are 1 to %ld", (boxint)idx, (long)(g->_.parts.len));
#else
      return NEW_DB_NULL;
#endif
    }
  return (caddr_t)geo_copy (g->_.parts.items[idx /* No "minus one" because index zero is for exterior ring */]);
}

caddr_t
bif_st_get_bounding_box_n (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  geo_t *g = bif_geo_arg (qst, args, 0, "st_get_bounding_box_n", GEO_ARG_ANY_NULLABLE);
  geo_t *sub_g, *res, xy;
  boxint idx = bif_long_arg (qst, args, 1, "st_get_bounding_box_n");
  if (NULL == g)
    return NEW_DB_NULL;
  if (!(g->geo_flags & (GEO_A_MULTI | GEO_A_ARRAY)))
    sub_g = g;
  if ((idx < 1) || (idx > g->_.parts.len))
    sqlr_new_error ("22023", "GEO..", "Invalid index value " BOXINT_FMT ", valid values for this geometery are 1 to %ld", (boxint)idx, (long)(g->_.parts.len));
  sub_g = g->_.parts.items[idx-1];
  geo_get_bounding_XYbox (sub_g, &xy, 0, 0);
  res = geo_alloc (GEO_BOX | (sub_g->geo_flags & (GEO_A_Z | GEO_A_M)), 0, sub_g->geo_srcode);
  res->XYbox = xy.XYbox;
  if (g->geo_flags & (GEO_A_Z | GEO_A_M))
    {
      geo_ZMbox_t *zm = geo_get_ZMbox_field (g);
      if (res->geo_flags & GEO_A_Z)
        {
          res->_.point.point_ZMbox.Zmin = zm->Zmin;
          res->_.point.point_ZMbox.Zmax = zm->Zmax;
        }
      if (res->geo_flags & GEO_A_M)
        {
          res->_.point.point_ZMbox.Mmin = zm->Mmin;
          res->_.point.point_ZMbox.Mmax = zm->Mmax;
        }
    }
  return (caddr_t)res;
}

caddr_t
bif_st_translate (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  geo_t *g = bif_geo_arg (qst, args, 0, "ST_Translate", GEO_ARG_ANY_NULLABLE);
  geoc dX, dY, dZ=0.0;
  geo_t *res;
  if (NULL == g)
    return NEW_DB_NULL;
  dX = bif_double_arg (qst, args, 1, "ST_Translate");
  dY = bif_double_arg (qst, args, 2, "ST_Translate");
  if (3 < BOX_ELEMENTS (args)) 
    dZ = bif_double_arg (qst, args, 3, "ST_Translate");
  res = (geo_t *)box_copy ((caddr_t)g);
  geo_modify_by_translate (res, dX, dY, dZ);
  return (caddr_t) res;
}

caddr_t
bif_st_transscale (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  geo_t *g = bif_geo_arg (qst, args, 0, "ST_TransScale", GEO_ARG_ANY_NULLABLE);
  geoc dX, dY, Xfactor, Yfactor;
  geo_t *res;
  if (NULL == g)
    return NEW_DB_NULL;
  dX		= bif_double_arg (qst, args, 1, "ST_TransScale");
  dY		= bif_double_arg (qst, args, 2, "ST_TransScale");
  Xfactor	= bif_double_arg (qst, args, 3, "ST_TransScale");
  Yfactor	= bif_double_arg (qst, args, 4, "ST_TransScale");
  res = (geo_t *)box_copy ((caddr_t)g);
  geo_modify_by_transscale (res, dX, dY, Xfactor, Yfactor);
  return (caddr_t) res;
}

caddr_t
bif_st_affine (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  geo_t *g = bif_geo_arg (qst, args, 0, "ST_Affine", GEO_ARG_ANY_NULLABLE);
  geoc XXa, XYb, YXd, YYe, Xoff, Yoff;
  geo_t *res;
  if (NULL == g)
    return NEW_DB_NULL;
  XXa		= bif_double_arg (qst, args, 1, "ST_Affine");
  XYb		= bif_double_arg (qst, args, 2, "ST_Affine");
  YXd		= bif_double_arg (qst, args, 3, "ST_Affine");
  YYe		= bif_double_arg (qst, args, 4, "ST_Affine");
  Xoff		= bif_double_arg (qst, args, 5, "ST_Affine");
  Yoff		= bif_double_arg (qst, args, 6, "ST_Affine");
  res = (geo_t *)box_copy ((caddr_t)g);
  geo_modify_by_affine2d (res, XXa, XYb, YXd, YYe, Xoff, Yoff);
  return (caddr_t) res;
}

/* OLAEAPS --- the oblique Lampert Azimuthal Equal-Area projection for sphere,
as defined in "Map Projections --- A Working Manual" by J.P.Snyder, USGS PP 1395, pp.185 -- 186 */

typedef struct geo_proj_olaeaps_s {
  geo_proj_point_cbk_t *gp_point_cbk;
  geo_srcode_t gp_input_srcode;
  geo_srcode_t gp_result_srcode;
  double cos_lat0, sin_lat0, long0;
} geo_proj_olaeaps_t;

const char *
geo_proj_point_olaeaps (void *geo_proj, geoc longP, geoc latP, double *retX, double *retY)
{
  double cos_latP = cos (latP * DEG_TO_RAD), sin_latP = sin (latP * DEG_TO_RAD);
  double longdiff = longP - ((geo_proj_olaeaps_t *)geo_proj)->long0;
  double cos_longdiff = cos (longdiff * DEG_TO_RAD),  sin_longdiff = sin (longdiff * DEG_TO_RAD);
  double kdiv, k;
  kdiv = 1 + ((geo_proj_olaeaps_t *)geo_proj)->sin_lat0 * sin_latP + ((geo_proj_olaeaps_t *)geo_proj)->cos_lat0 * cos_latP * cos_longdiff;
  if (kdiv < geoc_EPSILON)
    { /* The special point of the projection is opposite to POINT(long0 lat0), the fallback is the lowest point of the outer circle, i.e., -2,0. */
      retX[0] = 0;
      retY[0] = -2;
      return "The projection of the shape gives indeterminates, try some other projection";
    }
  k = sqrt (2.0/kdiv);
  retX[0] = k * cos_latP * sin_longdiff;
  retY[0] = k * ((geo_proj_olaeaps_t *)geo_proj)->cos_lat0 * sin_latP - ((geo_proj_olaeaps_t *)geo_proj)->sin_lat0 * cos_latP * cos_longdiff;
  return NULL;
}

const char *
geo_proj_olaeaps_init (void *geo_proj, geoc long0, geoc lat0)
{
  ((geo_proj_olaeaps_t *)geo_proj)->gp_point_cbk = geo_proj_point_olaeaps;
  ((geo_proj_olaeaps_t *)geo_proj)->gp_input_srcode = GEO_SRCODE_OF_SRID (SRID_WGS84);
  ((geo_proj_olaeaps_t *)geo_proj)->gp_result_srcode = 0;
  ((geo_proj_olaeaps_t *)geo_proj)->cos_lat0 = cos (lat0 * DEG_TO_RAD);
  ((geo_proj_olaeaps_t *)geo_proj)->sin_lat0 = sin (lat0 * DEG_TO_RAD);
  ((geo_proj_olaeaps_t *)geo_proj)->long0 = long0;
  return NULL;
}

caddr_t
bif_st_transform_by_custom_projection (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  geo_t *g = bif_geo_arg (qst, args, 0, "st_transform_by_custom_projection", GEO_ARG_ANY_NULLABLE);
  caddr_t proj_name = bif_string_or_uname_arg (qst, args, 1, "st_transform_by_custom_projection");
  geo_proj_t proj;
  geo_t *res;
  const char *err = NULL;
  if (NULL == g)
    return NEW_DB_NULL;
  if (!strcmp (proj_name, "OLAEAPS"))
    {
      geoc long0 = bif_double_arg (qst, args, 2, "st_transform_by_custom_projection");
      geoc lat0 = bif_double_arg (qst, args, 3, "st_transform_by_custom_projection");
      err = geo_proj_olaeaps_init (&proj, long0, lat0);
    }
  else
    sqlr_new_error ("22023", "GEOxx", "Unknown custom projection name '%.300s'", proj_name);
  if (NULL != err)
    sqlr_new_error ("22023", "GEOxx", "Custom projection '%.300s' rejected configuration arguments: %.500s", proj_name, err);
  if (g->geo_srcode != proj.gp_input_srcode)
    sqlr_new_error ("22023", "GEOxx", "Custom projection '%.300s' requires argument with SRcode %d but called for SRcode %d",
      proj_name, (int)(proj.gp_input_srcode), (int)(g->geo_srcode) );
  res = (geo_t *)box_copy ((caddr_t)g);
  err = geo_modify_by_projection (res, &proj);
  if (NULL != err)
    {
      dk_free_box ((caddr_t)res);
      sqlr_new_error ("22023", "GEOxx", "Custom projection '%.300s' failed: %.500s", proj_name, err);
    }
  return (caddr_t) res;
}

void
bif_geo_init ()
{
  bif_define ("earth_radius", bif_earth_radius);
  bif_define ("haversine_deg_km", bif_haversine_deg_km);
  bif_define ("dist_from_point_to_line_segment", bif_dist_from_point_to_line_segment);
  bif_define_ex ("st_point", bif_st_point, BMD_ALIAS, "ST_Point", BMD_RET_TYPE, &bt_any_box, BMD_MIN_ARGCOUNT, 2, BMD_MAX_ARGCOUNT,
      4, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("st_linestring", bif_st_linestring, BMD_RET_TYPE, &bt_any_box, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("st_x", bif_st_x, BMD_ALIAS, "ST_X", BMD_RET_TYPE, &bt_double, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("st_y", bif_st_y, BMD_ALIAS, "ST_Y", BMD_RET_TYPE, &bt_double, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("st_z", bif_st_z, BMD_ALIAS, "ST_Z", BMD_RET_TYPE, &bt_double, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("st_m", bif_st_m, BMD_ALIAS, "ST_M", BMD_RET_TYPE, &bt_double, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("st_zmflag", bif_st_zmflag, BMD_ALIAS, "ST_Zmflag", BMD_RET_TYPE, &bt_integer, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("st_xmin"		, bif_st_xmin			, BMD_RET_TYPE, &bt_double	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("st_xmax"		, bif_st_xmax			, BMD_RET_TYPE, &bt_double	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("st_ymin", bif_st_ymin, BMD_RET_TYPE, &bt_double, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("st_ymax"		, bif_st_ymax			, BMD_RET_TYPE, &bt_double	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("st_zmin", bif_st_zmin, BMD_RET_TYPE, &bt_double, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("st_zmax", bif_st_zmax, BMD_RET_TYPE, &bt_double, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("st_mmin", bif_st_mmin, BMD_RET_TYPE, &bt_double, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("st_mmax", bif_st_mmax, BMD_RET_TYPE, &bt_double, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("st_intersects", bif_st_intersects, BMD_ALIAS, "ST_Intersects", BMD_RET_TYPE, &bt_integer, BMD_MIN_ARGCOUNT, 2,
      BMD_MAX_ARGCOUNT, 3, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("st_may_intersect", bif_st_may_intersect, BMD_RET_TYPE, &bt_integer, BMD_MIN_ARGCOUNT, 2, BMD_MAX_ARGCOUNT, 3,
      BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("st_contains", bif_st_contains, BMD_ALIAS, "ST_Contains", BMD_RET_TYPE, &bt_integer, BMD_MIN_ARGCOUNT, 2,
      BMD_MAX_ARGCOUNT, 3, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("st_may_contain", bif_st_may_contain, BMD_RET_TYPE, &bt_integer, BMD_MIN_ARGCOUNT, 2, BMD_MAX_ARGCOUNT, 3,
      BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("st_within", bif_st_within, BMD_ALIAS, "ST_Within", BMD_RET_TYPE, &bt_integer, BMD_MIN_ARGCOUNT, 2,
      BMD_MAX_ARGCOUNT, 3, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("st_distance"		, bif_st_distance						, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("isgeometry"		, bif_is_geometry		, BMD_RET_TYPE, &bt_integer	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("st_astext"		, bif_st_astext			, BMD_RET_TYPE, &bt_varchar	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("st_srid", bif_st_srid, BMD_ALIAS, "ST_SRID", BMD_RET_TYPE, &bt_integer, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("st_setsrid", bif_st_setsrid, BMD_ALIAS, "ST_SetSRID", BMD_DONE);
  bif_define_ex ("st_ewkt_read", bif_st_ewkt_read, BMD_ALIAS, "st_geomfromtext", BMD_ALIAS, "ST_GeomFromText", BMD_ALIAS,
      "ST_GeometryFromText", BMD_ALIAS, "ST_GeomFromEWKT", BMD_ALIAS, "ST_WKTToSQL", BMD_RET_TYPE, &bt_any_box, BMD_MIN_ARGCOUNT, 1,
      BMD_MAX_ARGCOUNT, 2, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("http_st_ewkt"		, bif_http_st_ewkt						, BMD_DONE);
  bif_define_ex ("http_st_dxf_entity"	, bif_http_st_dxf_entity					, BMD_DONE);
  bif_define_ex ("st_get_bounding_box"	, bif_st_get_bounding_box					, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("st_get_chainbox", bif_st_get_chainbox, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("st_dv_geo_length"	, bif_st_dv_geo_length						, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("geometrytype", bif_geometry_type, BMD_ALIAS, "GeometryType", BMD_RET_TYPE, &bt_varchar, BMD_MIN_ARGCOUNT, 1,
      BMD_MAX_ARGCOUNT, 1, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("st_numgeometries", bif_st_num_geometries, BMD_ALIAS, "ST_NumGeometries", BMD_RET_TYPE, &bt_integer,
      BMD_MIN_ARGCOUNT, 1, BMD_MAX_ARGCOUNT, 1, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("st_geometryn", bif_st_geometry_n, BMD_ALIAS, "ST_GeometryN", BMD_RET_TYPE, &bt_any_box, BMD_MIN_ARGCOUNT, 2,
      BMD_MAX_ARGCOUNT, 2, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("st_exteriorring", bif_st_exterior_ring, BMD_ALIAS, "ST_ExteriorRing", BMD_RET_TYPE, &bt_any_box, BMD_MIN_ARGCOUNT,
      1, BMD_MAX_ARGCOUNT, 1, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("st_numinteriorrings", bif_st_num_interior_rings, BMD_ALIAS, "ST_NumInteriorRings", BMD_RET_TYPE, &bt_integer,
      BMD_MIN_ARGCOUNT, 1, BMD_MAX_ARGCOUNT, 1, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("st_interiorringn", bif_st_interior_ring_n, BMD_ALIAS, "ST_InteriorRingN", BMD_RET_TYPE, &bt_any_box,
      BMD_MIN_ARGCOUNT, 2, BMD_MAX_ARGCOUNT, 2, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("st_get_bounding_box_n", bif_st_get_bounding_box_n, BMD_RET_TYPE, &bt_any_box, BMD_MIN_ARGCOUNT, 2,
      BMD_MAX_ARGCOUNT, 2, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("st_translate", bif_st_translate, BMD_ALIAS, "ST_Translate", BMD_RET_TYPE, &bt_any_box, BMD_MIN_ARGCOUNT, 3,
      BMD_MAX_ARGCOUNT, 4, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("st_transscale", bif_st_transscale, BMD_ALIAS, "ST_TransScale", BMD_RET_TYPE, &bt_any_box, BMD_MIN_ARGCOUNT, 5,
      BMD_MAX_ARGCOUNT, 5, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("st_affine", bif_st_affine, BMD_ALIAS, "ST_Affine", BMD_RET_TYPE, &bt_any_box, BMD_MIN_ARGCOUNT, 7,
      BMD_MAX_ARGCOUNT, 7, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("st_transform_by_custom_projection", bif_st_transform_by_custom_projection, BMD_RET_TYPE, &bt_any_box,
      BMD_MIN_ARGCOUNT, 2, BMD_IS_PURE, BMD_DONE);
}

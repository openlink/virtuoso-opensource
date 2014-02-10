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
  double lat1 = bif_double_arg (qst, args, 0, "haversine_deg_km");
  double long1 = bif_double_arg (qst, args, 1, "haversine_deg_km");
  double lat2 = bif_double_arg (qst, args, 2, "haversine_deg_km");
  double long2 = bif_double_arg (qst, args, 3, "haversine_deg_km");
  if ((lat1 > 90.0) || (lat1 < -90.0) || (long1 > 180.0) || (long1 < -180.0) ||
      (lat2 > 90.0) || (lat2 < -90.0) || (long2 > 180.0) || (long2 < -180.0))
    sqlr_new_error ("22023", "SP001", "Latitude and longitude in degrees are expected (-90 to 90 and -180 to 180)");
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
  double x = bif_double_arg (qst, args, 0, "st_point");
  double y = bif_double_arg (qst, args, 1, "st_point");
  geo_t * res = geo_point (x,y);
  if (DV_SINGLE_FLOAT == dtp || DV_LONG_INT == dtp)
    res->geo_flags |= GEO_IS_FLOAT;
  return (caddr_t)res;
}


caddr_t
bif_st_x (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  geo_t * g = bif_geo_arg (qst, args, 0, "st_x", GEO_POINT);
  return box_double (g->Xkey);
}

caddr_t
bif_st_y (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  geo_t * g = bif_geo_arg (qst, args, 0, "st_y", GEO_POINT);
  return box_double (g->Ykey);
}

caddr_t
bif_st_xmin (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  geo_t * g = bif_geo_arg (qst, args, 0, "st_xmin", GEO_ARG_ANY_NULLABLE);
  if (NULL == g)
    return box_double (geoc_FARAWAY);
  if (GEO_POINT == GEO_TYPE_NO_ZM (g->geo_flags))
    {
      if (geoc_FARAWAY == g->Xkey)
        return box_double (geoc_FARAWAY);
      return box_double (g->Xkey);
    }
  return box_double (g->XYbox.Xmin);
}

caddr_t
bif_st_ymin (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  geo_t * g = bif_geo_arg (qst, args, 0, "st_ymin", GEO_ARG_ANY_NULLABLE);
  if (NULL == g)
    return box_double (geoc_FARAWAY);
  if (GEO_POINT == GEO_TYPE_NO_ZM (g->geo_flags))
    {
      if (geoc_FARAWAY == g->Xkey) /* yes, Xkey here and not Ykey */
        return box_double (geoc_FARAWAY);
      return box_double (g->Ykey);
    }
  return box_double (g->XYbox.Ymin);
}

caddr_t
bif_st_xmax (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  geo_t * g = bif_geo_arg (qst, args, 0, "st_xmax", GEO_ARG_ANY_NULLABLE);
  if (NULL == g)
    return box_double (geoc_FARAWAY);
  if (GEO_POINT == GEO_TYPE_NO_ZM (g->geo_flags))
    {
      if (geoc_FARAWAY == g->Xkey)
        return box_double (geoc_FARAWAY);
      return box_double (g->Xkey);
    }
  return box_double (g->XYbox.Xmax);
}

caddr_t
bif_st_ymax (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  geo_t * g = bif_geo_arg (qst, args, 0, "st_ymax", GEO_ARG_ANY_NULLABLE);
  if (NULL == g)
    return box_double (geoc_FARAWAY);
  if (GEO_POINT == GEO_TYPE_NO_ZM (g->geo_flags))
    {
      if (geoc_FARAWAY == g->Xkey) /* yes, Xkey here and not Ykey */
        return box_double (geoc_FARAWAY);
      return box_double (g->Ykey);
    }
  return box_double (g->XYbox.Ymax);
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
  return box_double (geo_distance (g1->geo_srcode, g1->Xkey, g1->Ykey, g2->Xkey, g2->Ykey));
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
bif_st_geomfromtext (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t str = bif_string_arg (qst, args, 0, "st_geomfromtext");
  return geo_parse_wkt (str, err_ret);
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
  if (p1X < p2X)
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
      avglat = (abs(p1Y+p2Y)+abs(q3Y+q4Y)) / 4;
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
      if (prec >= geo_distance (srcode, pX, pY, g2->Xkey, g2->Ykey))
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
                  if (itemctr >= g2->_.pline.len-1)
                    return 0;
                  if (geo_point_intersects_line (srcode, pX, pY, g2->_.pline.Xs[itemctr], g2->_.pline.Ys[itemctr], g2->_.pline.Xs[itemctr+1], g2->_.pline.Ys[itemctr+1], prec))
                    return 1;
                }
            }
        }
      else
        {
          for (itemctr = 0; itemctr < g2->_.pline.len; itemctr++)
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
    return geo_point_intersects_line (srcode, g2->Xkey, g2->Ykey, p1X, p1Y, p2X, p2Y, prec);
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
                  if (itemctr >= g2->_.pline.len-1)
                    return 0;
                  if (geo_line_intersects_line (srcode, p1X, p1Y, p2X, p2Y, g2->_.pline.Xs[itemctr], g2->_.pline.Ys[itemctr], g2->_.pline.Xs[itemctr+1], g2->_.pline.Ys[itemctr+1], prec))
                    return 1;
                }
            }
        }
      else
        {
          for (itemctr = 0; itemctr < g2->_.pline.len; itemctr++)
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
        goto unsupported;
        return 0;
      }
    }
unsupported:
  sqlr_new_error ("42000", "GEO..", "for after check of geo contains, only may_intersect and intersects of points with precision is supported");
  return 0;
}


int
geo_may_intersect_XYbox (geo_t *g, geo_XYbox_t *b, double prec)
{
  if (GEO_POINT == GEO_TYPE_NO_ZM (g->geo_flags))
    return geo_point_intersects_XYbox (g->geo_srcode, g->Xkey, g->Ykey, b, prec);
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
                if (prec >= geo_distance (g1->geo_srcode, g1->Xkey, g1->Ykey, g2->Xkey, g2->Ykey))
                  return 1;
                return 0;
              }
            if (!geo_point_intersects_XYbox (g1->geo_srcode, g1->Xkey, g1->Ykey, &(g2->XYbox), prec))
              return 0;
            if (GEO_BOX == GEO_TYPE_NO_ZM (g2->geo_flags))
              return 1;
            return geo_point_intersects (g1->geo_srcode, g1->Xkey, g1->Ykey, g2, prec);
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
            goto unsupported;
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
                goto unsupported;
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
                        if (itemctr >= g1->_.pline.len)
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
            {
            }
          }
        goto unsupported;
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
                  if (prec >= geo_distance (g1->geo_srcode, g1->Xkey, g1->Ykey, g2->Xkey, g2->Ykey))
                    return 1;
                  return 0;
                }
              if (GEO_BOX == GEO_TYPE_NO_ZM (g2->geo_flags))
                {
                  geoc boxproximaX = ((g1->Xkey > g2->XYbox.Xmax) ? g2->XYbox.Xmax : ((g1->Xkey < g2->XYbox.Xmin) ? g2->XYbox.Xmin : g1->Xkey));
                  geoc boxproximaY = ((g1->Ykey > g2->XYbox.Ymax) ? g2->XYbox.Ymax : ((g1->Ykey < g2->XYbox.Ymin) ? g2->XYbox.Ymin : g1->Ykey));
                  if (prec >= geo_distance (g1->geo_srcode, g1->Xkey, g1->Ykey, boxproximaX, boxproximaY))
                    return 1;
                  return 0;
                }
              if ( (g1->Xkey < g2->XYbox.Xmin - prec)
                || (g1->Xkey > g2->XYbox.Xmax + prec)
                || (g1->Ykey < g2->XYbox.Ymin - prec)
                || (g1->Ykey > g2->XYbox.Ymax + prec) )
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
    }
unsupported:
  sqlr_new_error ("42000", "GEO..", "for after check of geo contains, only may_intersect and intersects of points with precision is supported");
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
    sqlr_new_error ("22023", "GEO..", "Invalid index value " BOXINT_FMT ", valid values for this geometery are 1 to %ld", (boxint)(g->_.parts.len), (long)(g->_.parts.len));
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
      sqlr_new_error ("22023", "GEO..", "Invalid index value " BOXINT_FMT ", valid values for this geometery are 1 to %ld", (long)(g->_.parts.len));
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


void
bif_geo_init ()
{
  bif_define ("earth_radius", bif_earth_radius);
  bif_define ("haversine_deg_km", bif_haversine_deg_km);
  bif_define ("dist_from_point_to_line_segment", bif_dist_from_point_to_line_segment);
  bif_define_ex ("st_point", bif_st_point, BMD_RET_TYPE, &bt_any_box, BMD_MIN_ARGCOUNT, 2, BMD_MAX_ARGCOUNT, 4, BMD_IS_PURE,
      BMD_DONE);
  bif_define_ex ("st_x"			, bif_st_x			, BMD_RET_TYPE, &bt_double	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("st_y"			, bif_st_y			, BMD_RET_TYPE, &bt_double	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("st_xmin"		, bif_st_xmin			, BMD_RET_TYPE, &bt_double	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("st_ymin"		, bif_st_ymin			, BMD_RET_TYPE, &bt_double	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("st_xmax"		, bif_st_xmax			, BMD_RET_TYPE, &bt_double	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("st_ymax"		, bif_st_ymax			, BMD_RET_TYPE, &bt_double	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("st_intersects", bif_st_intersects, BMD_RET_TYPE, &bt_integer, BMD_MIN_ARGCOUNT, 2, BMD_MAX_ARGCOUNT, 3,
      BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("st_may_intersect", bif_st_may_intersect, BMD_RET_TYPE, &bt_integer, BMD_MIN_ARGCOUNT, 2, BMD_MAX_ARGCOUNT, 3,
      BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("st_contains", bif_st_contains, BMD_RET_TYPE, &bt_integer, BMD_MIN_ARGCOUNT, 2, BMD_MAX_ARGCOUNT, 3, BMD_IS_PURE,
      BMD_DONE);
  bif_define_ex ("st_within", bif_st_within, BMD_RET_TYPE, &bt_integer, BMD_MIN_ARGCOUNT, 2, BMD_MAX_ARGCOUNT, 3, BMD_IS_PURE,
      BMD_DONE);
  bif_define_ex ("st_distance"		, bif_st_distance						, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("isgeometry"		, bif_is_geometry		, BMD_RET_TYPE, &bt_integer	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("st_astext"		, bif_st_astext			, BMD_RET_TYPE, &bt_varchar	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("st_srid"		, bif_st_srid			, BMD_RET_TYPE, &bt_integer	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("st_setsrid"		, bif_st_setsrid						, BMD_DONE);
  bif_define_ex ("st_ewkt_read", bif_st_ewkt_read, BMD_RET_TYPE, &bt_any_box, BMD_ALIAS, "st_geomfromtext", BMD_MIN_ARGCOUNT, 1,
      BMD_MAX_ARGCOUNT, 1, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("http_st_ewkt"		, bif_http_st_ewkt						, BMD_DONE);
  bif_define_ex ("http_st_dxf_entity"	, bif_http_st_dxf_entity					, BMD_DONE);
  bif_define_ex ("st_get_bounding_box"	, bif_st_get_bounding_box					, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("st_dv_geo_length"	, bif_st_dv_geo_length						, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("GeometryType", bif_geometry_type, BMD_RET_TYPE, &bt_varchar, BMD_MIN_ARGCOUNT, 1, BMD_MAX_ARGCOUNT, 1,
      BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("ST_NumGeometries", bif_st_num_geometries, BMD_RET_TYPE, &bt_integer, BMD_MIN_ARGCOUNT, 1, BMD_MAX_ARGCOUNT, 1,
      BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("ST_GeometryN", bif_st_geometry_n, BMD_RET_TYPE, &bt_any_box, BMD_MIN_ARGCOUNT, 2, BMD_MAX_ARGCOUNT, 2,
      BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("ST_ExteriorRing", bif_st_exterior_ring, BMD_RET_TYPE, &bt_any_box, BMD_MIN_ARGCOUNT, 1, BMD_MAX_ARGCOUNT, 1,
      BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("ST_NumInteriorRings", bif_st_num_interior_rings, BMD_RET_TYPE, &bt_integer, BMD_MIN_ARGCOUNT, 1, BMD_MAX_ARGCOUNT,
      1, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("ST_InteriorRingN", bif_st_interior_ring_n, BMD_RET_TYPE, &bt_any_box, BMD_MIN_ARGCOUNT, 2, BMD_MAX_ARGCOUNT, 2,
      BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("st_get_bounding_box_n", bif_st_get_bounding_box_n, BMD_RET_TYPE, &bt_any_box, BMD_MIN_ARGCOUNT, 2,
      BMD_MAX_ARGCOUNT, 2, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("ST_Translate", bif_st_translate, BMD_RET_TYPE, &bt_any_box, BMD_MIN_ARGCOUNT, 3, BMD_MAX_ARGCOUNT, 4, BMD_IS_PURE,
      BMD_DONE);
  bif_define_ex ("ST_TransScale", bif_st_transscale, BMD_RET_TYPE, &bt_any_box, BMD_MIN_ARGCOUNT, 3, BMD_MAX_ARGCOUNT, 4,
      BMD_IS_PURE, BMD_DONE);
}

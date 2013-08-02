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

void
bif_geo_init ()
{
  bif_define ("earth_radius", bif_earth_radius);
  bif_define ("haversine_deg_km", bif_haversine_deg_km);
  bif_define ("dist_from_point_to_line_segment", bif_dist_from_point_to_line_segment);
}

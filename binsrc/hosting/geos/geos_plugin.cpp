/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2018 OpenLink Software
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

#include <stdio.h>
#include <iostream>
#include <iomanip>
#include <string>
#include <sstream>
#include <vector>
#include <geos.h>
#include <geos/geom/CoordinateArraySequence.h>
#include <geos/geom/Coordinate.h>
#include <geos/geom/CoordinateSequence.h>
#include <geos/geom/GeometryCollection.h>
#include <geos/geom/GeometryFactory.h>
#include <geos/geom/Geometry.h>
#include <geos/geom/IntersectionMatrix.h>
#include <geos/geom/LinearRing.h>
#include <geos/geom/LineString.h>
#include <geos/geom/Point.h>
#include <geos/geom/Polygon.h>
#include <geos/geom/PrecisionModel.h>
#include <geos/geom/util/SineStarFactory.h>
#include <geos/io/WKBReader.h>
#include <geos/io/WKBWriter.h>
#include <geos/io/WKTWriter.h>
#include <geos/opLinemerge.h>
#include <geos/opPolygonize.h>
#include <geos/util/GeometricShapeFactory.h>
#include <geos/util/GEOSException.h>
#include <geos/util/IllegalArgumentException.h>
#include <math.h>
#include "sqlver.h"
#include "geos_plugin.h"


extern "C" {
	unit_version_t * geos_check (unit_version_t * in, void *appdata);
	void virt_geos_postponed_action (char *mode);
	void virt_geos_plugin_connect (void *data);
};


dk_mutex_t *srid2GeometryFactory_mtx;
static dk_hash_t *srid2GeometryFactory;

geos::geom::GeometryFactory *
get_GeometryFactory_by_srid (int srcode)
{
  static const geos::geom::PrecisionModel *pm;
  int srid = GEO_SRID (srcode);
  geos::geom::GeometryFactory *gf;
  mutex_enter (srid2GeometryFactory_mtx);
  gf = (geos::geom::GeometryFactory *)gethash ((void *)((ptrlong)(srid)), srid2GeometryFactory);
  if (NULL == gf)
    {
      if (NULL == pm)
        pm = new geos::geom::PrecisionModel(geos::geom::PrecisionModel::FLOATING);
      gf = new geos::geom::GeometryFactory (pm, srid);
      sethash ((void *)((ptrlong)(srid)), srid2GeometryFactory, gf);
    }
  mutex_leave (srid2GeometryFactory_mtx);
  return gf;
}

geos::geom::Geometry *
export_geo_as_Geometry (geo_t *g)
{
  geos::geom::GeometryFactory *gf = get_GeometryFactory_by_srid (g->geo_srcode);
  switch (GEO_TYPE (g->geo_flags))
    {
    case GEO_POINT:
      return gf->createPoint (geos::geom::Coordinate (g->XYbox.Xmin, g->XYbox.Ymin));
    case GEO_POINT_Z:
      return gf->createPoint (geos::geom::Coordinate (g->XYbox.Xmin, g->XYbox.Ymin, g->_.point.point_ZMbox.Zmin));
    case GEO_BOX: /* but not case GEO_BOX_Z: */
    case GEO_LINESTRING: case GEO_LINESTRING_Z:
    case GEO_POLYGON: case GEO_POLYGON_Z:
    case GEO_POINTLIST: case GEO_POINTLIST_Z:
    case GEO_MULTI_LINESTRING: case GEO_MULTI_LINESTRING_Z: case GEO_MULTI_POLYGON: case GEO_MULTI_POLYGON_Z: case GEO_COLLECTION: case GEO_COLLECTION_Z:
      {
        geos::geom::Geometry *res;
        caddr_t err = NULL;
#if 0
        dk_session_t *wkb_ses = strses_allocate();
        wkb_print (g, wkb_ses, 1, 0);
        caddr_t wkb_varchar = strses_string (wkb_ses);
        dk_free_box ((caddr_t)wkb_ses);
        try
          {
            std::string wkb_strg (wkb_varchar, box_length (wkb_varchar) - 1);
            std::istringstream wkb_iss (wkb_strg);
            res = geos::io::WKBReader (*gf).read (wkb_iss);
          }
        catch (const geos::util::GEOSException &x)
          {
            err = srv_make_new_error ("22023", "GEO19", "Can not export a geometry of type %d to GEOS plugin: %s", GEO_TYPE(g->geo_flags), x.what());
          }
        catch (...)
          {
            err = srv_make_new_error ("22023", "GEO19", "Can not export a geometry of type %d to GEOS plugin: generic error", GEO_TYPE(g->geo_flags));
          }
#else
        {
          geo_exporter_to_geos gexp (*gf);
          res = gexp.export_one (g);
          err = gexp.blocking_error;
        }
#endif
        if (NULL != err)
          sqlr_resignal (err);
        return res;
      }
    default:
      sqlr_new_error ("22023", "GEO17", "Can not export a geometry of type %d to GEOS plugin", GEO_TYPE(g->geo_flags));
    }
  return NULL;
}

/*! Gets a geometry arument of BIF as an exported geometry, ready to use in GEOS.
This is longjmp/throw borderline! It means this should be the last operation that can call sqlr_new_error() and at the same time it should before making any stack variables that should be freed by stack unwinding. */
std::auto_ptr<geos::geom::Geometry>
bif_Geometry_auto_ptr_arg (caddr_t * qst, state_slot_t ** args, int inx, const char * f, int tp)
{
  geo_t *arg = bif_geo_arg (qst, args, inx, f, tp);
  if (NULL == arg)
    return std::auto_ptr<geos::geom::Geometry>(NULL);
  return std::auto_ptr<geos::geom::Geometry> (export_geo_as_Geometry (arg));
}

#define GEO_ARGPAIR_NULL_ARG1		0x1
#define GEO_ARGPAIR_NULL_ARG2		0x2
#define GEO_ARGPAIR_NOT_MAY_INTERSECT	0x4
/*! Gets two geometry aruments of BIF as two exported geometries, ready to use in GEOS.
This can not be made by two calls of bif_Geometry_auto_ptr_arg () because in that case we get second bif_geo_arg() after export_geo_as_Geometry() and it violates the longjmp/throw borderline rule.
As a benefit, this can try to transfrom second argument to get SRIDs of \c arg1 and \c arg2 compatible, when desired and needed.
In case of nonzero \c nulls_if_not_may_intersect the function will also check geometries for may_intersect() and if they're not then return NULLs instead of geometries, instantly.
The function returns 0 if everything is fine, otherwise bitwise OR bits GEO_ARGPAIR_NULL_ARG1 if first argument is NULL, GEO_ARGPAIR_NULL_ARG2 if second argument is NULL, GEO_ARGPAIR_NOT_MAY_INTERSECT if they were geometries but may_intersect() returns false.
 */
int
bif_Geometry_auto_ptr_argpair (caddr_t * qst, state_slot_t ** args, int inx1, int inx2, const char * f, int tp, int adjust_arg2_srid, int nulls_if_not_may_intersect, std::auto_ptr<geos::geom::Geometry> *arg1_ret, std::auto_ptr<geos::geom::Geometry> *arg2_ret)
{
  geo_t *arg1 = bif_geo_arg (qst, args, inx1, f, tp);
  geo_t *arg2 = bif_geo_arg (qst, args, inx2, f, tp);
  geo_t *arg2_cvt = NULL;
  arg2_ret->reset ();
  QR_RESET_CTX
    {
      if ((DV_GEO == DV_TYPE_OF (arg1)) && (DV_GEO == DV_TYPE_OF (arg2)))
        {
          int srid1 = GEO_SRID (arg1->geo_srcode);
          int srid2 = GEO_SRID (arg2->geo_srcode);
          if (srid2 != srid1)
            {
              caddr_t err = NULL;
              arg2_cvt = geo_get_default_srid_transform_cbk() (qst, arg2, srid1, &err);
              if (NULL != err)
                sqlr_resignal (err);
              if (nulls_if_not_may_intersect && !geo_pred (arg1, arg2_cvt, GSOP_MAY_INTERSECT, 0))
                {
                  arg1_ret->reset();
                  POP_QR_RESET;
                  return GEO_ARGPAIR_NOT_MAY_INTERSECT;
                }
              arg1_ret->reset ((NULL == arg1) ? NULL : export_geo_as_Geometry (arg1));
              arg2_ret->reset (export_geo_as_Geometry (arg2_cvt));
            }
          else
            {
              if (nulls_if_not_may_intersect && !geo_pred (arg1, arg2, GSOP_MAY_INTERSECT, 0))
                {
                  arg1_ret->reset();
                  POP_QR_RESET;
                  return GEO_ARGPAIR_NOT_MAY_INTERSECT;
                }
            }
        }
      arg1_ret->reset ((NULL == arg1) ? NULL : export_geo_as_Geometry (arg1));
      if (NULL == arg2_ret->get())
        arg2_ret->reset ((NULL == arg2) ? NULL : export_geo_as_Geometry (arg2));
    }
  QR_RESET_CODE
    {
      caddr_t err = thr_get_error_code (THREAD_CURRENT_THREAD);
      POP_QR_RESET;
      arg1_ret->reset();
      arg2_ret->reset();
      dk_free_box ((caddr_t)arg2_cvt);
      sqlr_resignal (err);
    }
  END_QR_RESET
  return (((NULL == arg1) ? GEO_ARGPAIR_NULL_ARG1 : 0x0) | ((NULL == arg2) ? GEO_ARGPAIR_NULL_ARG2 : 0x0));
}

/*! Gets a geometry arument of BIF as an exported geometry, ready to use in GEOS or report. If the arg is not a geometry, no error signalled, just \c fail_ret is set to nonzero.
This is longjmp/throw borderline! It means this should be the last operation that can call sqlr_new_error() and at the same time it should before making any stack variables that should be freed by stack unwinding. */
std::auto_ptr<geos::geom::Geometry>
bif_Geometry_auto_ptr_arg_nosignal (caddr_t * qst, state_slot_t ** args, int inx, const char * f, int tp, int *fail_ret)
{
  geo_t *arg = bif_geo_arg (qst, args, inx, f, (tp & ~GEO_ARG_NULLABLE) | GEO_ARG_NONGEO_AS_IS);
  fail_ret[0] = 0;
  switch (DV_TYPE_OF (arg))
    {
    case DV_GEO:
      return std::auto_ptr<geos::geom::Geometry> (export_geo_as_Geometry (arg));
    case DV_DB_NULL:
      if (tp & GEO_ARG_NULLABLE)
        return std::auto_ptr<geos::geom::Geometry>(NULL);
      /* no break */
    default:
      fail_ret[0] = 1;
      return std::auto_ptr<geos::geom::Geometry>(NULL);
    }
}

/*! Gets two geometry aruments of BIF as two exported geometries, ready to use in GEOS.
This is to bif_Geometry_auto_ptr_arg_nosignal() as bif_Geometry_auto_ptr_argpair() is to bif_Geometry_auto_ptr_arg() and the rationale is the same
The function returns 0 if everything is fine, otherwise bitwise OR bits GEO_ARGPAIR_NULL_ARG1 if first argument is NULL, GEO_ARGPAIR_NULL_ARG2 if second argument is NULL, GEO_ARGPAIR_NOT_MAY_INTERSECT if they were geometries but may_intersect() returns false.
 */
int
bif_Geometry_auto_ptr_argpair_nosignal (caddr_t * qst, state_slot_t ** args, int inx1, int inx2, const char * f, int tp, int adjust_arg2_srid, int nulls_if_not_may_intersect, std::auto_ptr<geos::geom::Geometry> *arg1_ret, std::auto_ptr<geos::geom::Geometry> *arg2_ret)
{
  geo_t *arg1 = bif_geo_arg (qst, args, inx1, f, (tp & ~GEO_ARG_NULLABLE) | GEO_ARG_NONGEO_AS_IS);
  geo_t *arg2 = bif_geo_arg (qst, args, inx2, f, (tp & ~GEO_ARG_NULLABLE) | GEO_ARG_NONGEO_AS_IS);
  geo_t *arg2_cvt = NULL;
  int ret = 0;
  arg1_ret->reset ();
  arg2_ret->reset ();
  switch (DV_TYPE_OF (arg2))
    {
    case DV_GEO:
      QR_RESET_CTX
        {
          if (DV_GEO == DV_TYPE_OF (arg1))
            {
              int srid1 = GEO_SRID (arg1->geo_srcode);
              int srid2 = GEO_SRID (arg2->geo_srcode);
              if (srid2 != srid1)
                {
                  caddr_t err = NULL;
                  arg2_cvt = geo_get_default_srid_transform_cbk() (qst, arg2, srid1, &err);
                  if (NULL != err)
                    sqlr_resignal (err);
                  if (nulls_if_not_may_intersect && !geo_pred (arg1, arg2_cvt, GSOP_MAY_INTERSECT, 0))
                    {
                      POP_QR_RESET;
                      return GEO_ARGPAIR_NOT_MAY_INTERSECT;
                    }
                  arg2_ret->reset (export_geo_as_Geometry (arg2_cvt));
                }
              else
                {
                  if (nulls_if_not_may_intersect && !geo_pred (arg1, arg2, GSOP_MAY_INTERSECT, 0))
                    {
                      POP_QR_RESET;
                      return GEO_ARGPAIR_NOT_MAY_INTERSECT;
                    }
                }
            }
          if (NULL == arg2_ret->get())
            arg2_ret->reset ((NULL == arg2) ? NULL : export_geo_as_Geometry (arg2));
        }
      QR_RESET_CODE
        {
          caddr_t err = thr_get_error_code (THREAD_CURRENT_THREAD);
          POP_QR_RESET;
          arg1_ret->reset();
          arg2_ret->reset();
          dk_free_box ((caddr_t)arg2_cvt);
          sqlr_resignal (err);
        }
      END_QR_RESET
      break;
    case DV_DB_NULL:
      if (tp & GEO_ARG_NULLABLE)
        break;
      /* no break */
    default:
      ret |= GEO_ARGPAIR_NULL_ARG2;
      break;
    }
  switch (DV_TYPE_OF (arg1))
    {
    case DV_GEO:
      arg1_ret->reset(export_geo_as_Geometry (arg1));
      break;
    case DV_DB_NULL:
      if (tp & GEO_ARG_NULLABLE)
        break;
      /* no break */
    default:
      ret |= GEO_ARGPAIR_NULL_ARG1;
      break;
    }
  return ret;
}

geo_t *
import_Coordinate_as_geo (const geos::geom::Coordinate *c, int num_of_dims, int srid)
{
  int g_zm_flags = 0;
  switch (num_of_dims)
    {
    case 3: g_zm_flags = GEO_A_Z; break;
    case 4: g_zm_flags = GEO_A_Z | GEO_A_M; break;
    }
  geo_t *res = geo_alloc (GEO_POINT | g_zm_flags, 0, GEO_SRCODE_OF_SRID (srid));
  res->XYbox.Xmin = res->XYbox.Xmax = c->x;
  res->XYbox.Ymin = res->XYbox.Ymax = c->y;
  if (g_zm_flags & GEO_A_Z)
    res->_.point.point_ZMbox.Zmin = res->_.point.point_ZMbox.Zmax = c->z;
  return res;
}

geo_t *
import_Geometry_as_geo (const geos::geom::Geometry *geom)
{
  switch (geom->getGeometryTypeId())
    {
    case GEOS_POINT:
      return import_Coordinate_as_geo (geom->getCoordinate (), geom->getCoordinateDimension(), geom->getSRID ());
    case GEOS_LINESTRING:
    case GEOS_POLYGON:
    case GEOS_MULTIPOINT:
    case GEOS_MULTILINESTRING:
    case GEOS_MULTIPOLYGON:
    case GEOS_GEOMETRYCOLLECTION:
      {
        geo_importer_from_geos gimp (geom->getCoordinateDimension());
        geo_t *res = gimp.import_one (*geom);
        return res;
      }
    default:
      sqlr_new_error ("22023", "GEO18", "Can not import a geometry of (GEOS) type %d to Virtuoso", geom->getGeometryTypeId());
    }
  return NULL;
}

static caddr_t
bif_geos_version (caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  return box_dv_short_string (geos::geom::geosversion().c_str());
}

static caddr_t
bif_geos_loopback (caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  std::auto_ptr<geos::geom::Geometry> arg1 = bif_Geometry_auto_ptr_arg (qst, args, 0, "GEOS loopback", GEO_ARG_ANY_NONNULL);
  return (caddr_t)import_Geometry_as_geo (arg1.get());
}

static caddr_t
bif_geos_get_coordinate (caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  std::auto_ptr<geos::geom::Geometry> arg1 = bif_Geometry_auto_ptr_arg (qst, args, 0, "GEOS getCoordinate", GEO_ARG_ANY_NONNULL);
  const geos::geom::Coordinate *c = arg1.get()->getCoordinate();
  if (NULL == c)
    return NEW_DB_NULL;
  return (caddr_t)import_Coordinate_as_geo (c, arg1.get()->getCoordinateDimension(), arg1.get()->getSRID());
}

#define BIF_GEXXX(gexxx,unwind,bifname) do { \
    if (((query_instance_t *)qst)->qi_query->qr_no_cast_error && strstr (gexxx.what(), " does not support ")) \
      return NEW_DB_NULL; \
    unwind; \
    sqlr_new_error ("22023", "GEO22", "Error in \"%s\"() function: %s", (bifname), gexxx.what()); \
    return NULL; \
  } while (0);

#define CATCH_BIF_GEXXX(unwind,bifname) catch (const geos::util::GEOSException &gexxx) { BIF_GEXXX(gexxx,unwind,bifname) }

static caddr_t
bif_geos_get_centroid (caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  std::auto_ptr<geos::geom::Geometry> arg1 = bif_Geometry_auto_ptr_arg (qst, args, 0, "GEOS getCentroid", GEO_ARG_ANY_NONNULL);
  std::auto_ptr<geos::geom::Geometry> res;
  try { res = std::auto_ptr<geos::geom::Geometry> (arg1.get()->getCentroid()); }
  CATCH_BIF_GEXXX((arg1.reset()), "GEOS getCentroid")
  if (NULL == res.get())
    return NEW_DB_NULL;
  return (caddr_t)import_Geometry_as_geo (res.get());
}

static caddr_t
bif_geos_distance (caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  std::auto_ptr<geos::geom::Geometry>arg1, arg2;
  bif_Geometry_auto_ptr_argpair (qst, args, 0, 1, "GEOS distance", GEO_ARG_ANY_NONNULL, 1, 0, &arg1, &arg2);
  double res;
  try { res = arg1.get()->distance(arg2.get()); }
  CATCH_BIF_GEXXX((arg1.reset()), "GEOS distance")
  return box_double (res);
}

static caddr_t
bif_geos_buffer (caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  std::auto_ptr<geos::geom::Geometry> arg1 = bif_Geometry_auto_ptr_arg (qst, args, 0, "GEOS buffer", GEO_ARG_ANY_NONNULL);
  double buf_val = bif_double_arg (qst, args, 1, "GEOS buffer");
  std::auto_ptr<geos::geom::Geometry> res;
  try { res = std::auto_ptr<geos::geom::Geometry> (arg1.get()->buffer(buf_val)); }
  CATCH_BIF_GEXXX((arg1.reset()), "GEOS buffer")
  return (caddr_t)import_Geometry_as_geo (res.get());
}

static caddr_t
bif_geos_convex_hull (caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  std::auto_ptr<geos::geom::Geometry> arg1 = bif_Geometry_auto_ptr_arg (qst, args, 0, "GEOS convexHull", GEO_ARG_ANY_NONNULL);
  std::auto_ptr<geos::geom::Geometry> res;
  try { res = std::auto_ptr<geos::geom::Geometry> (arg1.get()->convexHull()); }
  CATCH_BIF_GEXXX((arg1.reset()), "GEOS convexHull")
  if (NULL == res.get())
    return NEW_DB_NULL;
  return (caddr_t)import_Geometry_as_geo (res.get());
}

static caddr_t
bif_geos_envelope (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t res = bif_st_get_bounding_box_impl (qst, err_ret, args, 1, "GEOS envelope", GEO_ARG_ANY_NULLABLE);
  if (NULL == res)
    {
      geo_t *empty_res = geo_alloc (GEO_BOX, 0, GEO_SRCODE_DEFAULT);
      GEO_XYBOX_SET_EMPTY (empty_res->XYbox);
      return (caddr_t)empty_res;
    }
  if (DV_GEO != DV_TYPE_OF (res))
    return NEW_DB_NULL;
  return res;
}

static caddr_t
bif_geos_boundary (caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  std::auto_ptr<geos::geom::Geometry> arg1 = bif_Geometry_auto_ptr_arg (qst, args, 0, "GEOS boundary", GEO_ARG_ANY_NONNULL);
  std::auto_ptr<geos::geom::Geometry> res;
  try { res = std::auto_ptr<geos::geom::Geometry> (arg1.get()->getBoundary()); }
  CATCH_BIF_GEXXX((arg1.reset()), "GEOS boundary")
  if (NULL == res.get())
    return NEW_DB_NULL;
  return (caddr_t)import_Geometry_as_geo (res.get());
}

#define GEO_UOM_GridSpacing	0
#define GEO_UOM_degree		0x11
#define GEO_UOM_radian		0x21
#define GEO_UOM_meter		0x10
#define GEO_UOM_Kilometer	0x20
#define GEO_UOM_Yard		0x30
#define GEO_UOM_MileUSStatute	0x40

#define GEO_UOM_IS_LINEAR(uom)	((GEO_UOM_GridSpacing != (uom)) && (!((uom)&0x1)))
#define GEO_UOM_IS_ANGULAR(uom)	((GEO_UOM_GridSpacing != (uom)) && ((uom)&0x1))

int
bif_geo_uom_arg (caddr_t * qst, state_slot_t ** args, int arg_idx, const char *fname)
{
  caddr_t dist = bif_string_or_uname_or_iri_id_arg (qst, args, arg_idx, fname);
  caddr_t dist_iri;
  int res = -1;
  caddr_t err = NULL;
  if (DV_IRI_ID == (DV_TYPE_OF (dist)))
    {
     iri_id_t iid = unbox_iri_id (dist);
      if (min_bnode_iri_id () <= iid)
        sqlr_new_error ("22023", "GEO23", "Blank node IRI ID is not a valid IRI for unit of measure");
      dist_iri = key_id_to_iri ((query_instance_t *)qst, iid);
      if (!dist_iri)
        {
          if (0 == iid) dist_iri = box_dv_uname_string ("nodeID://0");
          else if (8192 == iid) dist_iri = box_dv_uname_string ("nodeID://8192");
          else rdf_handle_invalid_iri_id (qst, "Invalid IRI_ID #i", iid);
        }
      else
        box_flags (dist_iri) = BF_IRI;
    }
  else
    dist_iri = dist;
  if (!strncmp (dist_iri, OPENGIS_DEF_UOM_GS_NS_URI, OPENGIS_DEF_UOM_GS_NS_URI_LEN))
    {
      const char *tail = dist_iri + OPENGIS_DEF_UOM_GS_NS_URI_LEN;
      if (!strcmp (tail, "GridSpacing")) res = GEO_UOM_GridSpacing;
      else if (!strcmp (tail, "degree")) res = GEO_UOM_degree;
      else if (!strcmp (tail, "radian")) res = GEO_UOM_radian;
      else if (!strcmp (tail, "metre")) res = GEO_UOM_meter;
      else if (!strcmp (tail, "meter")) res = GEO_UOM_meter;
      else if (!strcmp (tail, "Kilometer")) res = GEO_UOM_Kilometer;
      else if (!strcmp (tail, "Yard")) res = GEO_UOM_Yard;
      else if (!strcmp (tail, "MileUSStatute")) res = GEO_UOM_MileUSStatute;
    }
  if (-1 == res)
    err = srv_make_new_error ("22023", "GEO23", "Unsupported unit of measure <%.50s>", dist_iri);
  if (dist_iri != dist)
      dk_free_box (dist_iri);
  if (NULL != err)
    sqlr_resignal (err);
  return res;
}

double
km_to_linear_uom (double km, int uom)
{
  switch (uom)
    {
    case GEO_UOM_meter: return 1000.0 * km;
    case GEO_UOM_Kilometer: return km;
    case GEO_UOM_Yard: return (1000.0/0.9144) * km;
    case GEO_UOM_MileUSStatute: return (1.0/1.6093472186944) * km;
    }
  GPF_T;
  return 0;
}

static caddr_t
bif_geos_s_srs_distance (caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  static const char *bifname = "GEOS silent SRS distance";
  int uom = bif_geo_uom_arg (qst, args, 2, bifname);
  std::auto_ptr<geos::geom::Geometry> arg1, arg2;
  int argfail = bif_Geometry_auto_ptr_argpair_nosignal (qst, args, 0, 1, bifname, GEO_ARG_ANY_NONNULL, 1, 0, &arg1, &arg2);
  if (argfail)
    return NEW_DB_NULL;
  double shape_dist;
  try { shape_dist = arg1.get()->distance(arg2.get()); }
  CATCH_BIF_GEXXX((arg1.reset(), arg2.reset()), bifname)
  if (shape_dist <= 0)
    return box_double (0);
  if (GEO_UOM_GridSpacing == uom)
    return box_double (shape_dist); /* exact shape_dist */
  caddr_t pj_err = NULL;
  int srid = arg1.get()->getSRID();
  void *pj = geo_get_default_pj_by_srid_or_string_cbk()(qst, &pj_err, srid, NULL, bifname, "first shape");
  if (pj_err)
    {
      arg1.reset(); arg2.reset(); sqlr_resignal (pj_err);
    }
  int islatlong = geo_get_default_pj_is_latlong_cbk()(pj);
  int isgeocentric = ((0 < islatlong) ? 0 : geo_get_default_pj_is_geocent_cbk()(pj));
  if ((-1 == islatlong) || (-1 == isgeocentric))
    {
      arg1.reset(); arg2.reset(); sqlr_new_error ("22023", "GEO23", "Unknown SRID %d; consider using plugin proj4 or similar", srid);
    }
  if (!(islatlong || isgeocentric))
    {
      arg1.reset(); arg2.reset();
      sqlr_new_error ("22023", "GEO23", "SRID %d is neither latlong nor geocentric, the only supported UOM (unit of measure) for it is <" OPENGIS_DEF_UOM_GS_NS_URI "GridSpacing>", srid);
    }
  std::auto_ptr<geos::geom::Point> arg1cen(arg1.get()->getCentroid());
  std::auto_ptr<geos::geom::Point> arg2cen(arg2.get()->getCentroid());
  double cen1x = arg1cen.get()->getX();
  double cen2x = arg2cen.get()->getX();
  if (fabs (cen2x-cen1x) > 135) /* What if shapes become "closer" to each other if measured from the other side of globe? Let's slide one of them 360 right to see if it is so. */
    {
      std::auto_ptr<geos::geom::Geometry> arg1shifted, arg2shifted;
      if (cen1x < 0)
        {
          geo_t *a1s = bif_geo_arg (qst, args, 0, bifname, GEO_ARG_ANY_NONNULL);
          if (geo_long360add (a1s) & GEO_LONG360ADD_SOME_CHANGED)
            arg1shifted.reset (export_geo_as_Geometry (a1s));
        }
      else if (cen2x < 0)
        {
          geo_t *a2s = bif_geo_arg (qst, args, 0, bifname, GEO_ARG_ANY_NONNULL);
          if (geo_long360add (a2s) & GEO_LONG360ADD_SOME_CHANGED)
            arg2shifted.reset (export_geo_as_Geometry (a2s));
        }
      try {
          if (arg1shifted.get())
            {
              double dist_shifted = arg1shifted.get()->distance(arg2.get());
              if (dist_shifted <= 0)
                return box_double (0);
              if (dist_shifted < shape_dist)
                {
                  shape_dist = dist_shifted;
                  arg1 = arg1shifted;
                  arg1cen.reset(arg1.get()->getCentroid());
                }
            }
          else if (arg2shifted.get())
            {
              double dist_shifted = arg1.get()->distance(arg2shifted.get());
              if (dist_shifted <= 0)
                return box_double (0);
              if (dist_shifted < shape_dist)
                {
                  shape_dist = dist_shifted;
                  arg2 = arg2shifted;
                  arg2cen.reset(arg2.get()->getCentroid());
                }
            }
        }
      CATCH_BIF_GEXXX((arg1.reset(), arg2.reset(), arg1shifted.reset(), arg2shifted.reset()), bifname)
    }
  double cen_dist;
  try { cen_dist = arg1cen.get()->distance(arg2cen.get()); }
  CATCH_BIF_GEXXX((arg1.reset(), arg2.reset(), arg1cen.reset(), arg2cen.reset()), bifname)
  if (shape_dist > 1.001 * cen_dist)
    {
      if (GEO_UOM_IS_LINEAR(uom))
        return box_double (km_to_linear_uom (shape_dist / KM_TO_DEG, uom));
      if (GEO_UOM_degree == uom)
        return box_double (shape_dist);
      if (GEO_UOM_radian == uom)
        return box_double (DEG_TO_RAD * shape_dist);
    }
  else
    {
      if (GEO_UOM_IS_LINEAR(uom))
        return box_double (km_to_linear_uom (haversine_deg_km (arg1cen.get()->getX(), arg1cen.get()->getY(), arg2cen.get()->getX(), arg2cen.get()->getY()) * shape_dist / cen_dist, uom));
      if (GEO_UOM_degree == uom)
        return box_double (haversine_deg_deg (arg1cen.get()->getX(), arg1cen.get()->getY(), arg2cen.get()->getX(), arg2cen.get()->getY()) * shape_dist / cen_dist);
      if (GEO_UOM_radian == uom)
        return box_double (DEG_TO_RAD * haversine_deg_deg (arg1cen.get()->getX(), arg1cen.get()->getY(), arg2cen.get()->getX(), arg2cen.get()->getY()) * shape_dist / cen_dist);
    }
  arg1.reset(); arg2.reset(); arg1cen.reset(); arg2cen.reset();
  sqlr_new_error ("22023", "GEO23", "Unit of measure is not supported by %s(), sorry", bifname);
  return NULL;
}


static caddr_t
bif_geos_s_buffer (caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  int arg_err;
  std::auto_ptr<geos::geom::Geometry> arg1 = bif_Geometry_auto_ptr_arg_nosignal (qst, args, 0, "GEOS silent buffer", GEO_ARG_ANY_NONNULL, &arg_err);
  if (arg_err)
    return NEW_DB_NULL;
  double buf_val = bif_double_arg (qst, args, 1, "GEOS silent buffer");
  std::auto_ptr<geos::geom::Geometry> res;
  try { res = std::auto_ptr<geos::geom::Geometry> (arg1.get()->buffer(buf_val)); }
  CATCH_BIF_GEXXX((arg1.reset()), "GEOS silent buffer")
  return (caddr_t)import_Geometry_as_geo (res.get());
}

static caddr_t
bif_geos_s_convex_hull (caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  int arg_err;
  std::auto_ptr<geos::geom::Geometry> arg1 = bif_Geometry_auto_ptr_arg_nosignal (qst, args, 0, "GEOS silent convexHull", GEO_ARG_ANY_NONNULL, &arg_err);
  if (arg_err)
    return NEW_DB_NULL;
  std::auto_ptr<geos::geom::Geometry> res;
  try { res = std::auto_ptr<geos::geom::Geometry> (arg1.get()->convexHull()); }
  CATCH_BIF_GEXXX((arg1.reset()), "GEOS silent convexHull")
  if (NULL == res.get())
    return NEW_DB_NULL;
  return (caddr_t)import_Geometry_as_geo (res.get());
}

static caddr_t
bif_geos_s_envelope (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t res = bif_st_get_bounding_box_impl (qst, err_ret, args, 1, "GEOS silent envelope", GEO_ARG_ANY_NULLABLE | GEO_ARG_NONGEO_AS_IS);
  if (NULL == res)
    {
      geo_t *empty_res = geo_alloc (GEO_BOX, 0, GEO_SRCODE_DEFAULT);
      GEO_XYBOX_SET_EMPTY (empty_res->XYbox);
      return (caddr_t)empty_res;
    }
  if (DV_GEO != DV_TYPE_OF (res))
    return NEW_DB_NULL;
  return res;
}

static caddr_t
bif_geos_s_boundary (caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  int arg_err;
  std::auto_ptr<geos::geom::Geometry> arg1 = bif_Geometry_auto_ptr_arg_nosignal (qst, args, 0, "GEOS silent boundary", GEO_ARG_ANY_NONNULL, &arg_err);
  if (arg_err)
    return NEW_DB_NULL;
  std::auto_ptr<geos::geom::Geometry> res;
  try { res = std::auto_ptr<geos::geom::Geometry> (arg1.get()->getBoundary()); }
  CATCH_BIF_GEXXX((arg1.reset()), "GEOS silent boundary")
  if (NULL == res.get())
    return NEW_DB_NULL;
  return (caddr_t)import_Geometry_as_geo (res.get());
}

static caddr_t
bif_geos_get_srid_iri (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  geo_t *arg1 = bif_geo_arg (qst, args, 0, "GEOS get SRID IRI", GEO_ARG_ANY_NULLABLE | GEO_ARG_NONGEO_AS_IS);
  if (DV_GEO != DV_TYPE_OF (arg1))
    return NEW_DB_NULL;
  ptrlong srid = GEO_SRID (arg1->geo_srcode);
  caddr_t res = geo_sr_srid_to_iri (srid);
  if (NULL == res)
    return NEW_DB_NULL;
  return res;
}

void
geo_dimensions_int (geo_t *g, int *topo_dim_ret, int *coord_mask_ret)
{
  int type = GEO_TYPE_MASK & (g->geo_flags);
  int local_dim;
  coord_mask_ret[0] |= (g->geo_flags & (GEO_A_Z | GEO_A_M));
  if (GEO_A_RINGS & type)
    local_dim = 2;
  else if (GEO_POINT == GEO_TYPE_CORE (type))
    local_dim = 0;
  else if (GEO_NULL_SHAPE == GEO_TYPE_CORE (type))
    local_dim = -1;
  else
    local_dim = 1;
  if (topo_dim_ret[0] < local_dim)
    topo_dim_ret[0] = local_dim;
  if ((GEO_A_ARRAY & type) && (GEO_UNDEFTYPE == GEO_TYPE_CORE (type)))
    {
      int ctr;
      for (ctr = g->_.parts.len; ctr--; /* no step */)
        {
          geo_dimensions_int (g->_.parts.items[ctr], topo_dim_ret, coord_mask_ret);
          if (2 == topo_dim_ret[0])
            return;
        }
    }
}


static caddr_t
bif_geos_topo_dimension (caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  geo_t *arg1 = bif_geo_arg (qst, args, 0, "GEOS topological dimension", GEO_ARG_ANY_NULLABLE | GEO_ARG_NONGEO_AS_IS);
  if (DV_GEO != DV_TYPE_OF (arg1))
    return NEW_DB_NULL;
  int topo_dim = -1, coord_mask = 0;
  geo_dimensions_int (arg1, &topo_dim, &coord_mask);
  return box_num ((topo_dim < 0) ? 0 : topo_dim);
}

static caddr_t
bif_geos_coord_dimension (caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  geo_t *arg1 = bif_geo_arg (qst, args, 0, "GEOS coordinate dimension", GEO_ARG_ANY_NULLABLE | GEO_ARG_NONGEO_AS_IS);
  if (DV_GEO != DV_TYPE_OF (arg1))
    return NEW_DB_NULL;
  int topo_dim = -1, coord_mask = 0;
  geo_dimensions_int (arg1, &topo_dim, &coord_mask);
  return box_num (2 + ((coord_mask & GEO_A_Z) ? 1 : 0) + ((coord_mask & GEO_A_M) ? 1 : 0));
}

static caddr_t
bif_geos_spat_dimension (caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  geo_t *arg1 = bif_geo_arg (qst, args, 0, "GEOS spatial dimension", GEO_ARG_ANY_NULLABLE | GEO_ARG_NONGEO_AS_IS);
  if (DV_GEO != DV_TYPE_OF (arg1))
    return NEW_DB_NULL;
  int topo_dim = -1, coord_mask = 0;
  geo_dimensions_int (arg1, &topo_dim, &coord_mask);
  return box_num (2 + ((coord_mask & GEO_A_Z) ? 1 : 0));
}

static caddr_t
bif_geos_is_empty (caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  geo_t *arg1 = bif_geo_arg (qst, args, 0, "GEOS isEmpty", GEO_ARG_ANY_NULLABLE | GEO_ARG_NONGEO_AS_IS);
  if (DV_GEO != DV_TYPE_OF (arg1))
    return NEW_DB_NULL;
  int topo_dim = 0, coord_mask = 0;
  geo_dimensions_int (arg1, &topo_dim, &coord_mask);
  return box_num ((0 > topo_dim) ? 1 : 0);
}

static caddr_t
bif_geos_is_simple (caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  int arg_err;
  std::auto_ptr<geos::geom::Geometry> arg1 = bif_Geometry_auto_ptr_arg_nosignal (qst, args, 0, "GEOS isSimple", GEO_ARG_ANY_NONNULL, &arg_err);
  if (arg_err)
    return NEW_DB_NULL;
  int res;
  try
    {
      if (0 == arg1.get()->getNumGeometries())
        res = 0;
      else
        res = arg1.get()->isSimple();
    }
  CATCH_BIF_GEXXX((arg1.reset()), "GEOS isSimple")
  return box_num (res ? 1 : 0);
}

static caddr_t
bif_geos_is_unsupported (caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  caddr_t res = NULL;
  caddr_t catched = NULL;
  QR_RESET_CTX
    {
      int arg_err;
      std::auto_ptr<geos::geom::Geometry> arg1 = bif_Geometry_auto_ptr_arg_nosignal (qst, args, 0, "GEOS isUnsupported", GEO_ARG_ANY_NONNULL, &arg_err);
      if (arg_err)
        res = box_dv_short_string ("22023The argument is not a geometry");
      else
        {
          int issimple;
          try { issimple = arg1.get()->isSimple(); }
          CATCH_BIF_GEXXX((arg1.reset()), "GEOS isUnsupported")
        }
    }
  QR_RESET_CODE
    {
      du_thread_t * self = THREAD_CURRENT_THREAD;
      catched = thr_get_error_code (self);
    }
  END_QR_RESET;
  if (res)
    return res;
  if (catched)
    {
      res = box_dv_short_strconcat (ERR_STATE (catched), ERR_MESSAGE (catched));
      dk_free_tree (catched);
      return res;
    }
  return box_num (0);
}

static caddr_t
bif_geos_as_wkt (caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  geo_t *arg1 = bif_geo_arg (qst, args, 0, "GEOS asWKT", GEO_ARG_ANY_NULLABLE | GEO_ARG_NONGEO_AS_IS);
  if (DV_GEO != DV_TYPE_OF (arg1))
    return NEW_DB_NULL;
  dk_session_t *ses = strses_allocate ();
  QR_RESET_CTX
    {
      ptrlong srid = GEO_SRID (arg1->geo_srcode);
      caddr_t srid_iri = geo_sr_srid_to_iri (srid);
      if (NULL != srid_iri)
        {
          session_buffered_write_char ('<', ses);
          SES_PRINT (ses, srid_iri);
          session_buffered_write_char ('>', ses);
          session_buffered_write_char (' ', ses);
        }
      else
        {
          char buf[30];
          sprintf (buf, "SRID=%ld; ", (long)srid);
          SES_PRINT (ses, buf);
        }
      ewkt_print_sf12 (arg1, ses);
    }
  QR_RESET_CODE
    {
      caddr_t err = thr_get_error_code (THREAD_CURRENT_THREAD);
      POP_QR_RESET;
      strses_free (ses);
      sqlr_resignal (err);
    }
  END_QR_RESET;
  caddr_t str = strses_string (ses);
  dk_free_box ((caddr_t)ses);
  return (caddr_t)str;
}


typedef bool (geos::geom::Geometry::* Geometry_g2g_relation_membptr_t) (const geos::geom::Geometry *that) const;

static caddr_t
bif_geos_g2g_relation (caddr_t * qst, caddr_t * err, state_slot_t ** args, Geometry_g2g_relation_membptr_t op_membptr, int disjoin_always_false, const char *bifname)
{
  std::auto_ptr<geos::geom::Geometry>arg1, arg2;
  int argfail = bif_Geometry_auto_ptr_argpair (qst, args, 0, 1, bifname, GEO_ARG_ANY_NONNULL, 1, disjoin_always_false, &arg1, &arg2);
  if (argfail & GEO_ARGPAIR_NOT_MAY_INTERSECT)
    return box_num (0);
  int res;
  try { res = ((arg1.get())->*op_membptr)(arg2.get()); }
  CATCH_BIF_GEXXX((arg1.reset(), arg2.reset()), bifname)
  return box_num (res);
}

static caddr_t bif_geos_disjoint	(caddr_t * qst, caddr_t * err, state_slot_t ** args) { return bif_geos_g2g_relation (qst, err, args, &geos::geom::Geometry::disjoint		, 0, "GEOS disjoint"	); }
static caddr_t bif_geos_touches	(caddr_t * qst, caddr_t * err, state_slot_t ** args) { return bif_geos_g2g_relation (qst, err, args, &geos::geom::Geometry::touches		, 1, "GEOS touches"	); }
static caddr_t bif_geos_intersects	(caddr_t * qst, caddr_t * err, state_slot_t ** args) { return bif_geos_g2g_relation (qst, err, args, &geos::geom::Geometry::intersects	, 1, "GEOS intersects"	); }
static caddr_t bif_geos_crosses	(caddr_t * qst, caddr_t * err, state_slot_t ** args) { return bif_geos_g2g_relation (qst, err, args, &geos::geom::Geometry::crosses		, 1, "GEOS crosses"	); }
static caddr_t bif_geos_within	(caddr_t * qst, caddr_t * err, state_slot_t ** args) { return bif_geos_g2g_relation (qst, err, args, &geos::geom::Geometry::within		, 1, "GEOS within"	); }
static caddr_t bif_geos_contains	(caddr_t * qst, caddr_t * err, state_slot_t ** args) { return bif_geos_g2g_relation (qst, err, args, &geos::geom::Geometry::contains		, 1, "GEOS contains"	); }
static caddr_t bif_geos_overlaps	(caddr_t * qst, caddr_t * err, state_slot_t ** args) { return bif_geos_g2g_relation (qst, err, args, &geos::geom::Geometry::overlaps		, 1, "GEOS overlaps"	); }
static caddr_t bif_geos_equals	(caddr_t * qst, caddr_t * err, state_slot_t ** args) { return bif_geos_g2g_relation (qst, err, args, &geos::geom::Geometry::equals		, 1, "GEOS equals"	); }

static caddr_t
bif_geos_g2g_silent_relation (caddr_t * qst, caddr_t * err, state_slot_t ** args, Geometry_g2g_relation_membptr_t op_membptr, int disjoin_always_false, const char *bifname)
{
  std::auto_ptr<geos::geom::Geometry> arg1, arg2;
  int argfail = bif_Geometry_auto_ptr_argpair_nosignal (qst, args, 0, 1, bifname, GEO_ARG_ANY_NONNULL, 1, disjoin_always_false, &arg1, &arg2);
  if (argfail)
    return box_num (0);
  int res;
  try { res = ((arg1.get())->*op_membptr)(arg2.get()); }
  CATCH_BIF_GEXXX((arg1.reset(), arg2.reset()), bifname)
  return box_num (res);
}

static caddr_t bif_geos_s_disjoint	(caddr_t * qst, caddr_t * err, state_slot_t ** args) { return bif_geos_g2g_silent_relation (qst, err, args, &geos::geom::Geometry::disjoint		, 0, "GEOS silent disjoint"	); }
static caddr_t bif_geos_s_touches	(caddr_t * qst, caddr_t * err, state_slot_t ** args) { return bif_geos_g2g_silent_relation (qst, err, args, &geos::geom::Geometry::touches		, 1, "GEOS silent touches"		); }
static caddr_t bif_geos_s_intersects	(caddr_t * qst, caddr_t * err, state_slot_t ** args) { return bif_geos_g2g_silent_relation (qst, err, args, &geos::geom::Geometry::intersects		, 1, "GEOS silent intersects"	); }
static caddr_t bif_geos_s_crosses	(caddr_t * qst, caddr_t * err, state_slot_t ** args) { return bif_geos_g2g_silent_relation (qst, err, args, &geos::geom::Geometry::crosses		, 1, "GEOS silent crosses"		); }
static caddr_t bif_geos_s_within	(caddr_t * qst, caddr_t * err, state_slot_t ** args) { return bif_geos_g2g_silent_relation (qst, err, args, &geos::geom::Geometry::within		, 1, "GEOS silent within"		); }
static caddr_t bif_geos_s_contains	(caddr_t * qst, caddr_t * err, state_slot_t ** args) { return bif_geos_g2g_silent_relation (qst, err, args, &geos::geom::Geometry::contains		, 1, "GEOS silent contains"	); }
static caddr_t bif_geos_s_overlaps	(caddr_t * qst, caddr_t * err, state_slot_t ** args) { return bif_geos_g2g_silent_relation (qst, err, args, &geos::geom::Geometry::overlaps		, 1, "GEOS silent overlaps"	); }
static caddr_t bif_geos_s_equals	(caddr_t * qst, caddr_t * err, state_slot_t ** args) { return bif_geos_g2g_silent_relation (qst, err, args, &geos::geom::Geometry::equals		, 1, "GEOS silent equals"		); }

static caddr_t
bif_geos_relate1 (caddr_t * qst, caddr_t * err, state_slot_t ** args, const char *de9im_pattern, const char *bifname)
{
  std::auto_ptr<geos::geom::Geometry> arg1, arg2;
  int argfail = bif_Geometry_auto_ptr_argpair_nosignal (qst, args, 0, 1, bifname, GEO_ARG_ANY_NONNULL, 1, 1, &arg1, &arg2);
  if (argfail)
    return box_num (0);
  int res;
  try { res = (arg1.get())->relate(arg2.get(), de9im_pattern); }
  CATCH_BIF_GEXXX((arg1.reset(), arg2.reset()), bifname)
  return box_num (res);
}

static caddr_t bif_geos_sf_eq		(caddr_t * qst, caddr_t * err, state_slot_t ** args) { return bif_geos_relate1 (qst, err, args, "T*F**FFF*"	, "GEOS SF equals"	); }
static caddr_t bif_geos_eh_overlap	(caddr_t * qst, caddr_t * err, state_slot_t ** args) { return bif_geos_relate1 (qst, err, args, "T*T***T**"	, "GEOS Egenohofer overlap"	); }
static caddr_t bif_geos_eh_inside	(caddr_t * qst, caddr_t * err, state_slot_t ** args) { return bif_geos_relate1 (qst, err, args, "TFF*FFT**"	, "GEOS Egenohofer inside"	); }
static caddr_t bif_geos_eh_contains	(caddr_t * qst, caddr_t * err, state_slot_t ** args) { return bif_geos_relate1 (qst, err, args, "T*TFF*FF*"	, "GEOS Egenohofer contains"	); }

static caddr_t
bif_geos_rcc8 (caddr_t * qst, caddr_t * err, state_slot_t ** args, const char *de9im_pattern, int disjoin_always_false, const char *bifname)
{
  std::auto_ptr<geos::geom::Geometry> arg1, arg2;
  int argfail = bif_Geometry_auto_ptr_argpair_nosignal (qst, args, 0, 1, bifname, GEO_ARG_ANY_NONNULL, 1, disjoin_always_false, &arg1, &arg2);
  if (argfail)
    return box_num (0);
  if ((2 != (arg1.get())->getDimension()) || (2 != (arg2.get())->getDimension()))
    return box_num (0);
  int res;
  try { res = (arg1.get())->relate(arg2.get(), de9im_pattern); }
  CATCH_BIF_GEXXX((arg1.reset(), arg2.reset()), bifname)
  return box_num (res);
}

static caddr_t bif_geos_rcc8_eq	(caddr_t * qst, caddr_t * err, state_slot_t ** args) { return bif_geos_rcc8 (qst, err, args, "TFFFTFFFT"	, 1, "GEOS RCC8 eq"	); }
static caddr_t bif_geos_rcc8_dc	(caddr_t * qst, caddr_t * err, state_slot_t ** args) { return bif_geos_rcc8 (qst, err, args, "FFTFFTTTT"	, 0, "GEOS RCC8 dc"	); }
static caddr_t bif_geos_rcc8_ec	(caddr_t * qst, caddr_t * err, state_slot_t ** args) { return bif_geos_rcc8 (qst, err, args, "FFTFTTTTT"	, 1, "GEOS RCC8 ec"	); }
static caddr_t bif_geos_rcc8_po	(caddr_t * qst, caddr_t * err, state_slot_t ** args) { return bif_geos_rcc8 (qst, err, args, "TTTTTTTTT"	, 1, "GEOS RCC8 po"	); }
static caddr_t bif_geos_rcc8_tppi	(caddr_t * qst, caddr_t * err, state_slot_t ** args) { return bif_geos_rcc8 (qst, err, args, "TTTFTTFFT"	, 1, "GEOS RCC8 tppi"	); }
static caddr_t bif_geos_rcc8_tpp	(caddr_t * qst, caddr_t * err, state_slot_t ** args) { return bif_geos_rcc8 (qst, err, args, "TFFTTFTTT"	, 1, "GEOS RCC8 tpp"	); }
static caddr_t bif_geos_rcc8_ntpp	(caddr_t * qst, caddr_t * err, state_slot_t ** args) { return bif_geos_rcc8 (qst, err, args, "TFFTFFTTT"	, 1, "GEOS RCC8 ntpp"	); }
static caddr_t bif_geos_rcc8_ntppi	(caddr_t * qst, caddr_t * err, state_slot_t ** args) { return bif_geos_rcc8 (qst, err, args, "TTTFFTFFT"	, 1, "GEOS RCC8 ntppi"	); }


/*! Calculates OR of list of DE-9IM patterns filtered by dimensions
Syntax of each pattern is A/BCDDDDDDDDD where A and B are dimensions of arguments for which the DDDDDDDDD matrix should be checked,
A is '0' means left is point, B is '2' means right is area, '*' means any dimension is OK etc.
C tells what to do:
--- 'z' means return false,
--- '=' means return the result of relate() with matrix even if it is false,
--- ',' means return the result of relate() with matrix if true, try the rest of patterns if it is false, don't use this in last pattern of the array!
*/
static caddr_t
bif_geos_relateX (caddr_t * qst, caddr_t * err, state_slot_t ** args, const char *ttde9im_patterns[], int disjoin_always_false, const char *bifname)
{
  std::auto_ptr<geos::geom::Geometry> arg1, arg2;
  int argfail = bif_Geometry_auto_ptr_argpair_nosignal (qst, args, 0, 1, bifname, GEO_ARG_ANY_NONNULL, 1, disjoin_always_false, &arg1, &arg2);
  if (argfail)
    return box_num (0);
  int res;
  try {
      const char **ttde9im_tail = ttde9im_patterns;
      while (1)
        {
          const char *pat = (ttde9im_tail++)[0];
          if ((pat[0] != '*') && ((pat[0]-'0') != (arg1.get())->getDimension()))
            continue;
          if ((pat[2] != '*') && ((pat[2]-'0') != (arg2.get())->getDimension()))
            continue;
          if ('z' == pat[3])
            return box_num (0);
          res = (arg1.get())->relate(arg2.get(), pat + 4);
          if (res || (pat[3] == '='))
            return box_num (res);
        }
    }
  catch (const geos::util::GEOSException &gexxx)
    {
      sqlr_new_error ("22023", "GEO22", "GEOS %s() error: %s", bifname, gexxx.what());
      return NULL;
    }
  return box_num (0);
}

static caddr_t bif_geos_sf_touches	(caddr_t * qst, caddr_t * err, state_slot_t ** args) {
  const char *pats[] = { "0/0z"			, "*/*,FT*******"	, "*/*,F**T*****"	, "*/*=F***T****"	};
 return bif_geos_relateX (qst, err, args, pats, 1, "GEOS SF touches"	); }

static caddr_t bif_geos_sf_crosses	(caddr_t * qst, caddr_t * err, state_slot_t ** args) {
  const char *pats[] = { "0/1=T*T***T**"	, "0/2=T*T***T**"	, "1/2=T*T***T**"	, "1/1=0********"	, "*/*z"	};
 return bif_geos_relateX (qst, err, args, pats, 1, "GEOS SF crosses"	); }

static caddr_t bif_geos_eh_covers	(caddr_t * qst, caddr_t * err, state_slot_t ** args) {
  const char *pats[] = { "1/1=T*TFT*FF*"	, "2/1=T*TFT*FF*"	, "2/2=T*TFT*FF*"	, "*/*z"	};
 return bif_geos_relateX (qst, err, args, pats, 1, "GEOS Egenhofer covers"	); }

static caddr_t bif_geos_eh_covered_by	(caddr_t * qst, caddr_t * err, state_slot_t ** args) {
  const char *pats[] = { "1/1=TFF*TFT**"	, "1/2=TFF*TFT**"	, "2/2=TFF*TFT**"	, "*/*z"	};
 return bif_geos_relateX (qst, err, args, pats, 1, "GEOS Egenhofer coveredBy"	); }

static caddr_t
bif_geos_equals_exact (caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  double tolerance = bif_double_arg (qst, args, 2, "GEOS equalsExact");
  std::auto_ptr<geos::geom::Geometry>arg1, arg2;
  int argfail = bif_Geometry_auto_ptr_argpair (qst, args, 0, 1, "GEOS equalsExact", GEO_ARG_ANY_NONNULL, 1, 1, &arg1, &arg2);
  int res;
  if (argfail)
    return box_num (0);
  try { res = (arg1.get())->equalsExact(arg2.get(), tolerance); }
  CATCH_BIF_GEXXX((arg1.reset(), arg2.reset()), "GEOS equalsExact")
  return box_num (res);
}

#define F_OR_STAR(c) (('F' == (c)) || ('*' == (c)))
#define F_OR_STAR_IN_ALL_0134(p) (F_OR_STAR((p)[0]) && F_OR_STAR((p)[1]) && F_OR_STAR((p)[3]) && F_OR_STAR((p)[4]))

static caddr_t
bif_geos_relate (caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  caddr_t de9im_pattern_strg = ((2 < BOX_ELEMENTS (args)) ? bif_string_arg (qst, args, 2, "GEOS relate") : NULL);
  int disjoin_always_false = ((NULL != de9im_pattern_strg) && !F_OR_STAR_IN_ALL_0134(de9im_pattern_strg));
  std::auto_ptr<geos::geom::Geometry>arg1, arg2;
  int argfail = bif_Geometry_auto_ptr_argpair (qst, args, 0, 1, "GEOS relate", GEO_ARG_ANY_NONNULL, 1, disjoin_always_false, &arg1, &arg2);
  if (argfail & GEO_ARGPAIR_NOT_MAY_INTERSECT)
    return box_num (0);
  caddr_t res;
  if (NULL == arg1.get())
    {
      if (NULL == arg2.get())
        {
          arg1.reset (get_GeometryFactory_by_srid (SRID_DEFAULT)->createEmptyGeometry());
          arg2.reset (get_GeometryFactory_by_srid (SRID_DEFAULT)->createEmptyGeometry());
        }
      else
        arg1.reset (arg2.get()->getFactory()->createEmptyGeometry());
    }
  else
    {
      if (NULL == arg2.get())
        arg2.reset (arg1.get()->getFactory()->createEmptyGeometry());
    }
  try
    {
      if (NULL != de9im_pattern_strg)
        res = box_num (arg1.get()->relate(arg2.get(), de9im_pattern_strg));
      else
        {
          geos::geom::IntersectionMatrix *im = arg1.get()->relate(arg2.get());
          res = box_dv_short_string (im->toString().c_str());
          delete im;
        }
    }
  CATCH_BIF_GEXXX((arg1.reset(), arg2.reset()), "GEOS relate")
  return res;
}

static caddr_t
bif_geos_s_relate (caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  caddr_t de9im_pattern_strg = ((2 < BOX_ELEMENTS (args)) ? bif_string_arg (qst, args, 2, "GEOS silent relate") : NULL);
  int disjoin_always_false = ((NULL != de9im_pattern_strg) && !F_OR_STAR_IN_ALL_0134(de9im_pattern_strg));
  std::auto_ptr<geos::geom::Geometry> arg1, arg2;
  int argfail = bif_Geometry_auto_ptr_argpair_nosignal (qst, args, 0, 1, "GEOS silent relate", GEO_ARG_ANY_NONNULL, 1, disjoin_always_false, &arg1, &arg2);
  if (argfail & GEO_ARGPAIR_NOT_MAY_INTERSECT)
    return box_num (0);
  caddr_t res;
  if (NULL == arg1.get())
    {
      if (NULL == arg2.get())
        {
          arg1.reset (get_GeometryFactory_by_srid (SRID_DEFAULT)->createEmptyGeometry());
          arg2.reset (get_GeometryFactory_by_srid (SRID_DEFAULT)->createEmptyGeometry());
        }
      else
        arg1.reset (arg2.get()->getFactory()->createEmptyGeometry());
    }
  else
    {
      if (NULL == arg2.get())
        arg2.reset (arg1.get()->getFactory()->createEmptyGeometry());
    }
  try
    {
      if (NULL != de9im_pattern_strg)
        res = box_num (arg1.get()->relate(arg2.get(), de9im_pattern_strg));
      else
        {
          geos::geom::IntersectionMatrix *im = arg1.get()->relate(arg2.get());
          res = box_dv_short_string (im->toString().c_str());
          delete im;
        }
    }
  CATCH_BIF_GEXXX((arg1.reset(), arg2.reset()), "GEOS silent relate")
  return res;
}

typedef geos::geom::Geometry *(geos::geom::Geometry::* Geometry_g2g_combination_membptr_t) (const geos::geom::Geometry *that) const;

static caddr_t
bif_geos_g2g_combination (caddr_t * qst, caddr_t * err, state_slot_t ** args, Geometry_g2g_combination_membptr_t op_membptr, const char *bifname)
{
  std::auto_ptr<geos::geom::Geometry>arg1, arg2;
  bif_Geometry_auto_ptr_argpair (qst, args, 0, 1, bifname, GEO_ARG_ANY_NONNULL, 1, 0, &arg1, &arg2);
  std::auto_ptr<geos::geom::Geometry> res;
  try { res = std::auto_ptr<geos::geom::Geometry> (((arg1.get())->*op_membptr)(arg2.get())); }
  CATCH_BIF_GEXXX((arg1.reset(), arg2.reset()), bifname)
  if (NULL == res.get())
    return NEW_DB_NULL;
  return (caddr_t)import_Geometry_as_geo (res.get());
}

static caddr_t
bif_geos_union (caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  return bif_geos_g2g_combination (qst, err, args, &geos::geom::Geometry::Union, "GEOS Union");
}

static caddr_t
bif_geos_intersection (caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  return bif_geos_g2g_combination (qst, err, args, &geos::geom::Geometry::intersection, "GEOS intersection");
}

static caddr_t
bif_geos_difference (caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  return bif_geos_g2g_combination (qst, err, args, &geos::geom::Geometry::difference, "GEOS difference");
}

static caddr_t
bif_geos_sym_difference (caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  return bif_geos_g2g_combination (qst, err, args, &geos::geom::Geometry::symDifference, "GEOS symDifference");
}

static caddr_t
bif_geos_s_g2g_combination (caddr_t * qst, caddr_t * err, state_slot_t ** args, Geometry_g2g_combination_membptr_t op_membptr, const char *bifname)
{
  geo_t *raw_arg1 = bif_geo_arg (qst, args, 0, bifname, GEO_ARG_ANY_NONNULL | GEO_ARG_NONGEO_AS_IS);
  geo_t *raw_arg2 = bif_geo_arg (qst, args, 1, bifname, GEO_ARG_ANY_NONNULL | GEO_ARG_NONGEO_AS_IS);
  int nulls = 0;
  switch (DV_TYPE_OF (raw_arg1)) { case DV_GEO: break; case DV_DB_NULL: nulls |= 1; break; default: return NEW_DB_NULL; }
  switch (DV_TYPE_OF (raw_arg2)) { case DV_GEO: break; case DV_DB_NULL: nulls |= 2; break; default: return NEW_DB_NULL; }
  if (nulls)
    return box_num (nulls);
  std::auto_ptr<geos::geom::Geometry> arg1 (export_geo_as_Geometry (raw_arg1));
  std::auto_ptr<geos::geom::Geometry> arg2 (export_geo_as_Geometry (raw_arg2));
  std::auto_ptr<geos::geom::Geometry> res;
  try { res = std::auto_ptr<geos::geom::Geometry> (((arg1.get())->*op_membptr)(arg2.get())); }
  CATCH_BIF_GEXXX((arg1.reset(), arg2.reset()), bifname)
  if (NULL == res.get())
    return NEW_DB_NULL;
  return (caddr_t)import_Geometry_as_geo (res.get());
}

static caddr_t
bif_geos_s_union (caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  const char *fname = "GEOS silent Union";
  caddr_t res = bif_geos_s_g2g_combination (qst, err, args, &geos::geom::Geometry::Union, fname);
  if (DV_LONG_INT != DV_TYPE_OF (res))
    return res;
  switch (unbox (res)) { case 1: return box_copy_tree (bif_arg (qst, args, 1, fname)); case 2: return box_copy_tree (bif_arg (qst, args, 0, fname)); default: return NEW_DB_NULL; }
}

static caddr_t
bif_geos_s_intersection (caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  const char *fname = "GEOS silent intersection";
  caddr_t res = bif_geos_s_g2g_combination (qst, err, args, &geos::geom::Geometry::intersection, fname);
  if (DV_LONG_INT != DV_TYPE_OF (res))
    return res;
  return NEW_DB_NULL;
}

static caddr_t
bif_geos_s_difference (caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  const char *fname = "GEOS silent difference";
  caddr_t res = bif_geos_s_g2g_combination (qst, err, args, &geos::geom::Geometry::difference, fname);
  if (DV_LONG_INT != DV_TYPE_OF (res))
    return res;
  switch (unbox (res)) { case 2: return box_copy_tree (bif_arg (qst, args, 0, fname)); default: return NEW_DB_NULL; }
}

static caddr_t
bif_geos_s_sym_difference (caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  const char *fname = "GEOS silent symDifference";
  caddr_t res = bif_geos_s_g2g_combination (qst, err, args, &geos::geom::Geometry::symDifference, fname);
  if (DV_LONG_INT != DV_TYPE_OF (res))
    return res;
  switch (unbox (res)) { case 1: return box_copy_tree (bif_arg (qst, args, 1, fname)); case 2: return box_copy_tree (bif_arg (qst, args, 0, fname)); default: return NEW_DB_NULL; }
}

#define BINARY_BOOL_RELATION BMD_MIN_ARGCOUNT, 2, BMD_MAX_ARGCOUNT, 2, BMD_RET_TYPE, _gate._bt_integer._ptr, BMD_IS_PURE
#define BINARY_BOOL_SILENT_RELATION BMD_MIN_ARGCOUNT, 2, BMD_MAX_ARGCOUNT, 2, BMD_RET_TYPE, _gate._bt_integer_nn._ptr, BMD_IS_PURE

#define DF_DR_GS_ALIASES(name) BMD_ALIAS, OPENGIS_DEF_FUNCTION_GS_NS_URI name, BMD_ALIAS, OPENGIS_DEF_RULE_GS_NS_URI name , BMD_ALIAS, OPENGIS_ONT_GS_NS_URI name
#define DF_GS_ALIASES(name) BMD_ALIAS, OPENGIS_DEF_FUNCTION_GS_NS_URI name, BMD_ALIAS, OPENGIS_ONT_GS_NS_URI name

extern "C"
void
virt_geos_pre_log_action (char *mode)
{
  bif_define_ex ("GEOS version"		, bif_geos_version		, BMD_ALIAS, "GEOS-version"		,BMD_MIN_ARGCOUNT, 0, BMD_MAX_ARGCOUNT, 0, BMD_RET_TYPE, _gate._bt_varchar._ptr, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("GEOS loopback"	, bif_geos_loopback		, BMD_ALIAS, "GEOS-loopback"		,BMD_MIN_ARGCOUNT, 1, BMD_MAX_ARGCOUNT, 1, BMD_RET_TYPE, _gate._bt_any_box._ptr, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("GEOS getCoordinate"	, bif_geos_get_coordinate	, BMD_ALIAS, "GEOS-getCoordinate"	,BMD_MIN_ARGCOUNT, 1, BMD_MAX_ARGCOUNT, 1, BMD_RET_TYPE, _gate._bt_any_box._ptr, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("GEOS getCentroid"	, bif_geos_get_centroid	, BMD_ALIAS, "GEOS-getCentroid"		,BMD_MIN_ARGCOUNT, 1, BMD_MAX_ARGCOUNT, 1, BMD_RET_TYPE, _gate._bt_any_box._ptr, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("GEOS distance"	, bif_geos_distance		, BMD_ALIAS, "GEOS-distance"		,BMD_MIN_ARGCOUNT, 2, BMD_MAX_ARGCOUNT, 2, BMD_RET_TYPE, _gate._bt_double._ptr, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("GEOS buffer"		, bif_geos_buffer		, BMD_ALIAS, "GEOS-buffer"		,BMD_MIN_ARGCOUNT, 2, BMD_MAX_ARGCOUNT, 3, BMD_RET_TYPE, _gate._bt_any_box._ptr, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("GEOS convexHull"	, bif_geos_convex_hull	, BMD_ALIAS, "GEOS-convexHull"		,BMD_MIN_ARGCOUNT, 1, BMD_MAX_ARGCOUNT, 1, BMD_RET_TYPE, _gate._bt_any_box._ptr, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("GEOS envelope"	, bif_geos_envelope		, BMD_ALIAS, "GEOS-envelope"		,BMD_MIN_ARGCOUNT, 1, BMD_MAX_ARGCOUNT, 1, BMD_RET_TYPE, _gate._bt_any_box._ptr, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("GEOS boundary"	, bif_geos_boundary		, BMD_ALIAS, "GEOS-boundary"		,BMD_MIN_ARGCOUNT, 1, BMD_MAX_ARGCOUNT, 1, BMD_RET_TYPE, _gate._bt_any_box._ptr, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("GEOS silent SRS distance"	, bif_geos_s_srs_distance	, BMD_ALIAS, "GEOS-silent-SRS-distance", BMD_ALIAS, OPENGIS_DEF_FUNCTION_GS_NS_URI "distance"		,BMD_MIN_ARGCOUNT, 2, BMD_MAX_ARGCOUNT, 3, BMD_RET_TYPE, _gate._bt_double._ptr, BMD_USES_INDEX, BMD_OUT_OF_PARTITION, BMD_DONE);
  bif_define_ex ("GEOS silent buffer"		, bif_geos_s_buffer		, BMD_ALIAS, "GEOS-silent-buffer"	, BMD_ALIAS, OPENGIS_DEF_FUNCTION_GS_NS_URI "buffer"		,BMD_MIN_ARGCOUNT, 2, BMD_MAX_ARGCOUNT, 3, BMD_RET_TYPE, _gate._bt_any_box._ptr, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("GEOS silent convexHull"	, bif_geos_s_convex_hull	, BMD_ALIAS, "GEOS-silent-convexHull"	, BMD_ALIAS, OPENGIS_DEF_FUNCTION_GS_NS_URI "convexHull"	,BMD_MIN_ARGCOUNT, 1, BMD_MAX_ARGCOUNT, 1, BMD_RET_TYPE, _gate._bt_any_box._ptr, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("GEOS silent envelope"		, bif_geos_s_envelope		, BMD_ALIAS, "GEOS-silent-envelope"	, BMD_ALIAS, OPENGIS_DEF_FUNCTION_GS_NS_URI "envelope"		,BMD_MIN_ARGCOUNT, 1, BMD_MAX_ARGCOUNT, 1, BMD_RET_TYPE, _gate._bt_any_box._ptr, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("GEOS silent boundary"		, bif_geos_s_boundary		, BMD_ALIAS, "GEOS-silent-boundary"	, BMD_ALIAS, OPENGIS_DEF_FUNCTION_GS_NS_URI "boundary"		,BMD_MIN_ARGCOUNT, 1, BMD_MAX_ARGCOUNT, 1, BMD_RET_TYPE, _gate._bt_any_box._ptr, BMD_IS_PURE, BMD_DONE);

  bif_define_ex ("GEOS get SRID IRI"		, bif_geos_get_srid_iri	, BMD_ALIAS, "GEOS-get-SRID-IRI"	, BMD_ALIAS, OPENGIS_DEF_FUNCTION_GS_NS_URI "getSRID"		,BMD_MIN_ARGCOUNT, 1, BMD_MAX_ARGCOUNT, 1, BMD_RET_TYPE, _gate._bt_varchar._ptr, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("GEOS topologicalDimension"	, bif_geos_topo_dimension	, BMD_ALIAS, "GEOS-topologicalDimension"	, DF_GS_ALIASES("dimension")	,BMD_MIN_ARGCOUNT, 1, BMD_MAX_ARGCOUNT, 1, BMD_RET_TYPE, _gate._bt_integer._ptr, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("GEOS coordinateDimension"	, bif_geos_coord_dimension	, BMD_ALIAS, "GEOS-coordinateDimension"	, DF_GS_ALIASES("coordinateDimension")	,BMD_MIN_ARGCOUNT, 1, BMD_MAX_ARGCOUNT, 1, BMD_RET_TYPE, _gate._bt_integer._ptr, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("GEOS spatialDimension"	, bif_geos_spat_dimension	, BMD_ALIAS, "GEOS-spatialDimension"		, DF_GS_ALIASES("spatialDimension")	,BMD_MIN_ARGCOUNT, 1, BMD_MAX_ARGCOUNT, 1, BMD_RET_TYPE, _gate._bt_integer._ptr, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("GEOS isEmpty"		, bif_geos_is_empty		, BMD_ALIAS, "GEOS-isEmpty"			, DF_GS_ALIASES("isEmpty")	,BMD_MIN_ARGCOUNT, 1, BMD_MAX_ARGCOUNT, 1, BMD_RET_TYPE, _gate._bt_integer._ptr, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("GEOS isSimple"	, bif_geos_is_simple		, BMD_ALIAS, "GEOS-isSimple"			, DF_GS_ALIASES("isSimple")	,BMD_MIN_ARGCOUNT, 1, BMD_MAX_ARGCOUNT, 1, BMD_RET_TYPE, _gate._bt_integer._ptr, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("GEOS isUnsupported"	, bif_geos_is_unsupported	, BMD_ALIAS, "GEOS-isUnsupported"						,BMD_MIN_ARGCOUNT, 1, BMD_MAX_ARGCOUNT, 1, BMD_RET_TYPE, _gate._bt_any_box._ptr, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("GEOS asWKT"		, bif_geos_as_wkt		, BMD_ALIAS, "GEOS-asWKT"			, DF_GS_ALIASES("hasSerialization")	, DF_GS_ALIASES("asWKT")	,BMD_MIN_ARGCOUNT, 1, BMD_MAX_ARGCOUNT, 1, BMD_RET_TYPE, _gate._bt_any_box._ptr, BMD_IS_PURE, BMD_DONE);

  bif_define_ex ("GEOS disjoint"		, bif_geos_disjoint		, BMD_ALIAS, "GEOS-disjoint"		, BINARY_BOOL_RELATION, BMD_DONE);
  bif_define_ex ("GEOS touches"			, bif_geos_touches		, BMD_ALIAS, "GEOS-touches"		, BINARY_BOOL_RELATION, BMD_DONE);
  bif_define_ex ("GEOS intersects"		, bif_geos_intersects		, BMD_ALIAS, "GEOS-intersects"		, BINARY_BOOL_RELATION, BMD_DONE);
  bif_define_ex ("GEOS crosses"			, bif_geos_crosses		, BMD_ALIAS, "GEOS-crosses"		, BINARY_BOOL_RELATION, BMD_DONE);
  bif_define_ex ("GEOS within"			, bif_geos_within		, BMD_ALIAS, "GEOS-within"		, BINARY_BOOL_RELATION, BMD_DONE);
  bif_define_ex ("GEOS contains"		, bif_geos_contains		, BMD_ALIAS, "GEOS-contains"		, BINARY_BOOL_RELATION, BMD_DONE);
  bif_define_ex ("GEOS overlaps"		, bif_geos_overlaps		, BMD_ALIAS, "GEOS-overlaps"		, BINARY_BOOL_RELATION, BMD_DONE);
  bif_define_ex ("GEOS equals"			, bif_geos_equals		, BMD_ALIAS, "GEOS-equals"		, BINARY_BOOL_RELATION, BMD_DONE);

  bif_define_ex ("GEOS silent disjoint"		, bif_geos_s_disjoint		, BMD_ALIAS, "GEOS-silent-disjoint"	, DF_DR_GS_ALIASES("sfDisjoint"), DF_DR_GS_ALIASES("ehDisjoint")	, BINARY_BOOL_SILENT_RELATION, BMD_DONE);
  bif_define_ex ("GEOS silent touches"		, bif_geos_s_touches		, BMD_ALIAS, "GEOS-silent-touches"	, BINARY_BOOL_SILENT_RELATION, BMD_DONE);
  bif_define_ex ("GEOS silent intersects"	, bif_geos_s_intersects	, BMD_ALIAS, "GEOS-silent-intersects"	, DF_DR_GS_ALIASES("sfIntersects")	, BINARY_BOOL_SILENT_RELATION, BMD_DONE);
  bif_define_ex ("GEOS silent crosses"		, bif_geos_s_crosses		, BMD_ALIAS, "GEOS-silent-crosses"	, BINARY_BOOL_SILENT_RELATION, BMD_DONE);
  bif_define_ex ("GEOS silent within"		, bif_geos_s_within		, BMD_ALIAS, "GEOS-silent-within"	, DF_DR_GS_ALIASES("sfWithin"), BINARY_BOOL_SILENT_RELATION, BMD_DONE);
  bif_define_ex ("GEOS silent contains"		, bif_geos_s_contains		, BMD_ALIAS, "GEOS-silent-contains"	, DF_DR_GS_ALIASES("sfContains"), BINARY_BOOL_SILENT_RELATION, BMD_DONE);
  bif_define_ex ("GEOS silent overlaps"		, bif_geos_s_overlaps		, BMD_ALIAS, "GEOS-silent-overlaps"	, DF_DR_GS_ALIASES("sfOverlaps"), BINARY_BOOL_SILENT_RELATION, BMD_DONE);
  bif_define_ex ("GEOS silent equals"		, bif_geos_s_equals		, BMD_ALIAS, "GEOS-silent-equals"	, BINARY_BOOL_SILENT_RELATION, BMD_DONE);

  bif_define_ex ("GEOS RCC8 eq"		, bif_geos_rcc8_eq		, BMD_ALIAS, "GEOS-RCC8-eq"	, DF_DR_GS_ALIASES("rcc8eq"	), BINARY_BOOL_SILENT_RELATION, BMD_DONE);
  bif_define_ex ("GEOS RCC8 dc"		, bif_geos_rcc8_dc		, BMD_ALIAS, "GEOS-RCC8-dc"	, DF_DR_GS_ALIASES("rcc8dc"	), BINARY_BOOL_SILENT_RELATION, BMD_DONE);
  bif_define_ex ("GEOS RCC8 ec"		, bif_geos_rcc8_ec		, BMD_ALIAS, "GEOS-RCC8-ec"	, DF_DR_GS_ALIASES("rcc8ec"	), BINARY_BOOL_SILENT_RELATION, BMD_DONE);
  bif_define_ex ("GEOS RCC8 po"		, bif_geos_rcc8_po		, BMD_ALIAS, "GEOS-RCC8-po"	, DF_DR_GS_ALIASES("rcc8po"	), BINARY_BOOL_SILENT_RELATION, BMD_DONE);
  bif_define_ex ("GEOS RCC8 tppi"	, bif_geos_rcc8_tppi		, BMD_ALIAS, "GEOS-RCC8-tppi"	, DF_DR_GS_ALIASES("rcc8tppi"	), BINARY_BOOL_SILENT_RELATION, BMD_DONE);
  bif_define_ex ("GEOS RCC8 tpp"	, bif_geos_rcc8_tpp		, BMD_ALIAS, "GEOS-RCC8-tpp"	, DF_DR_GS_ALIASES("rcc8tpp"	), BINARY_BOOL_SILENT_RELATION, BMD_DONE);
  bif_define_ex ("GEOS RCC8 ntpp"	, bif_geos_rcc8_ntpp		, BMD_ALIAS, "GEOS-RCC8-ntpp"	, DF_DR_GS_ALIASES("rcc8ntpp"	), BINARY_BOOL_SILENT_RELATION, BMD_DONE);
  bif_define_ex ("GEOS RCC8 ntppi"	, bif_geos_rcc8_ntppi		, BMD_ALIAS, "GEOS-RCC8-ntppi"	, DF_DR_GS_ALIASES("rcc8ntppi"	), BINARY_BOOL_SILENT_RELATION, BMD_DONE);

  bif_define_ex ("GEOS OGC equals"	, bif_geos_sf_eq		, BMD_ALIAS, "GEOS-OGC-equals", DF_DR_GS_ALIASES("sfEquals"), DF_DR_GS_ALIASES("ehEquals"), BINARY_BOOL_SILENT_RELATION, BMD_DONE);
  bif_define_ex ("GEOS SF touches"	, bif_geos_sf_touches			, BMD_ALIAS, "GEOS-SF-touches", BMD_ALIAS, "GEOS Egenhofer meet", BMD_ALIAS, "GEOS-Egenhofer-meet"	, DF_DR_GS_ALIASES("sfTouches"), DF_DR_GS_ALIASES("ehMeet")	,BINARY_BOOL_SILENT_RELATION, BMD_DONE);
  bif_define_ex ("GEOS SF crosses"	, bif_geos_sf_crosses			, BMD_ALIAS, "GEOS-SF-crosses", DF_DR_GS_ALIASES("sfCrosses")	,BINARY_BOOL_SILENT_RELATION, BMD_DONE);
  bif_define_ex ("GEOS Egenohofer overlap"	, bif_geos_eh_overlap		, BMD_ALIAS, "GEOS-Egenohofer-overlap"	, DF_DR_GS_ALIASES("ehOverlap")		,BINARY_BOOL_SILENT_RELATION, BMD_DONE);
  bif_define_ex ("GEOS Egenohofer inside"	, bif_geos_eh_inside		, BMD_ALIAS, "GEOS-Egenohofer-inside"	, DF_DR_GS_ALIASES("ehInside")		,BINARY_BOOL_SILENT_RELATION, BMD_DONE);
  bif_define_ex ("GEOS Egenohofer contains"	, bif_geos_eh_contains	, BMD_ALIAS, "GEOS-Egenohofer-contains"	, DF_DR_GS_ALIASES("ehContains")	,BINARY_BOOL_SILENT_RELATION, BMD_DONE);
  bif_define_ex ("GEOS Egenhofer covers"	, bif_geos_eh_covers			, BMD_ALIAS, "GEOS-Egenhofer-covers", DF_DR_GS_ALIASES("ehCovers")	,BINARY_BOOL_SILENT_RELATION, BMD_DONE);
  bif_define_ex ("GEOS Egenhofer coveredBy"	, bif_geos_eh_covered_by		, BMD_ALIAS, "GEOS-Egenhofer-coveredBy", DF_DR_GS_ALIASES("ehCoveredBy")	,BINARY_BOOL_SILENT_RELATION, BMD_DONE);

  bif_define_ex ("GEOS silent relate"	, bif_geos_s_relate		, BMD_ALIAS, "GEOS-silent-relate"	, BMD_ALIAS, OPENGIS_DEF_FUNCTION_GS_NS_URI "relate"		,BMD_MIN_ARGCOUNT, 2, BMD_MAX_ARGCOUNT, 3, BMD_RET_TYPE, _gate._bt_any._ptr, BMD_IS_PURE, BMD_DONE);

  bif_define_ex ("GEOS equalsExact"	, bif_geos_equals_exact	, BMD_ALIAS, "GEOS-equalsExact"		,BMD_MIN_ARGCOUNT, 2, BMD_MAX_ARGCOUNT, 2, BMD_RET_TYPE, _gate._bt_integer_nn._ptr, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("GEOS relate"		, bif_geos_relate		, BMD_ALIAS, "GEOS-relate"		,BMD_MIN_ARGCOUNT, 2, BMD_MAX_ARGCOUNT, 3, BMD_RET_TYPE, _gate._bt_any._ptr, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("GEOS union"		, bif_geos_union		, BMD_ALIAS, "GEOS-union"		,BMD_MIN_ARGCOUNT, 2, BMD_MAX_ARGCOUNT, 2, BMD_RET_TYPE, _gate._bt_any_box._ptr, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("GEOS intersection"	, bif_geos_intersection	, BMD_ALIAS, "GEOS-intersection"	,BMD_MIN_ARGCOUNT, 2, BMD_MAX_ARGCOUNT, 2, BMD_RET_TYPE, _gate._bt_any_box._ptr, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("GEOS difference"	, bif_geos_difference		, BMD_ALIAS, "GEOS-difference"		,BMD_MIN_ARGCOUNT, 2, BMD_MAX_ARGCOUNT, 2, BMD_RET_TYPE, _gate._bt_any_box._ptr, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("GEOS symDifference"	, bif_geos_sym_difference	, BMD_ALIAS, "GEOS-symDifference"	,BMD_MIN_ARGCOUNT, 2, BMD_MAX_ARGCOUNT, 2, BMD_RET_TYPE, _gate._bt_any_box._ptr, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("GEOS silent union"		, bif_geos_s_union		, BMD_ALIAS, "GEOS-silent-union"		, BMD_ALIAS, OPENGIS_DEF_FUNCTION_GS_NS_URI "union"		,BMD_MIN_ARGCOUNT, 2, BMD_MAX_ARGCOUNT, 2, BMD_RET_TYPE, _gate._bt_any_box._ptr, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("GEOS silent intersection"	, bif_geos_s_intersection	, BMD_ALIAS, "GEOS-silent-intersection"		, BMD_ALIAS, OPENGIS_DEF_FUNCTION_GS_NS_URI "intersection"	,BMD_MIN_ARGCOUNT, 2, BMD_MAX_ARGCOUNT, 2, BMD_RET_TYPE, _gate._bt_any_box._ptr, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("GEOS silent difference"	, bif_geos_s_difference	, BMD_ALIAS, "GEOS-silent-difference"		, BMD_ALIAS, OPENGIS_DEF_FUNCTION_GS_NS_URI "difference"	,BMD_MIN_ARGCOUNT, 2, BMD_MAX_ARGCOUNT, 2, BMD_RET_TYPE, _gate._bt_any_box._ptr, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("GEOS silent symDifference"	, bif_geos_s_sym_difference	, BMD_ALIAS, "GEOS-silent-symDifference"	, BMD_ALIAS, OPENGIS_DEF_FUNCTION_GS_NS_URI "symDifference"	,BMD_MIN_ARGCOUNT, 2, BMD_MAX_ARGCOUNT, 2, BMD_RET_TYPE, _gate._bt_any_box._ptr, BMD_IS_PURE, BMD_DONE);
  srid2GeometryFactory_mtx = mutex_allocate ();
  srid2GeometryFactory = hash_table_allocate (5000);
}


extern "C"
void
virt_geos_postponed_action (char *mode)
{
}

extern "C"
void
virt_geos_plugin_connect (void *data)
{
  dk_set_push (get_srv_global_init_pre_log_actions_ptr(), (void *)virt_geos_pre_log_action);
  dk_set_push (get_srv_global_init_postponed_actions_ptr(), (void *)virt_geos_postponed_action);
}

static unit_version_t virt_geos_version = {
  PLAIN_PLUGIN_TYPE,		/*!< Title of unit, filled by unit */
  DBMS_SRV_GEN_MAJOR DBMS_SRV_GEN_MINOR,	/*!< Version number, filled by unit */
  "OpenLink Software",		/*!< Plugin's developer, filled by unit */
  "GEOS plugin based on Geometry Engine Open Source library from Open Source Geospatial Foundation",	/*!< Any additional info, filled by unit */
  0,				/*!< Error message, filled by unit loader */
  0,				/*!< Name of file with unit's code, filled by unit loader */
  virt_geos_plugin_connect,	/*!< Pointer to connection function, cannot be 0 */
  0,				/*!< Pointer to disconnection function, or 0 */
  0,				/*!< Pointer to activation function, or 0 */
  0,				/*!< Pointer to deactivation function, or 0 */
  &_gate
};


extern "C"
unit_version_t *CALLBACK
geos_check (unit_version_t * in, void *appdata)
{
  return &virt_geos_version;
}

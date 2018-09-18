#include <iomanip>
#include <ostream>
#include <sstream>
#include <string>
#include <geos/io/WKBConstants.h>
#include <geos/io/ByteOrderValues.h>
#include <geos/io/ParseException.h>
#include <geos/geom/GeometryFactory.h>
#include <geos/geom/Coordinate.h>
#include <geos/geom/Point.h>
#include <geos/geom/LinearRing.h>
#include <geos/geom/LineString.h>
#include <geos/geom/Polygon.h>
#include <geos/geom/MultiPoint.h>
#include <geos/geom/MultiLineString.h>
#include <geos/geom/MultiPolygon.h>
#include <geos/geom/CoordinateSequenceFactory.h>
#include <geos/geom/CoordinateSequence.h>
#include <geos/geom/PrecisionModel.h>

#include "geos_plugin.h"

geos::geom::Geometry*
geo_exporter_to_geos::export_one (geo_t *g)
{
  try
    {
      if (g->geo_flags & GEO_A_M)
        {
          blocking_error = srv_make_new_error ("22023", "GEO20", "Unable to export geometry of type %d to GEOS library: M ordinate is not supported by GEOS", GEO_TYPE (g->geo_flags));
          return NULL;
        }
      bool hasZ = g->geo_flags & GEO_A_Z;
      if (hasZ) inputDimension = 3;
      else inputDimension = 2;
      int SRID = GEO_SRID (g->geo_srcode);
      geos::geom::Geometry *result;
      switch (GEO_TYPE_NO_ZM (g->geo_flags))
        {
        case GEO_POINT:		result = export_Point (g);		break;
        case GEO_LINESTRING:	result = export_LineString (g);		break;
        case GEO_POLYGON:		result = export_Polygon (g);		break;
        case GEO_POINTLIST:		result = export_MultiPoint (g);		break;
        case GEO_MULTI_LINESTRING:	result = export_MultiLineString (g);	break;
        case GEO_MULTI_POLYGON:	result = export_MultiPolygon (g);	break;
        case GEO_COLLECTION:	result = export_GeometryCollection (g);	break;
        case GEO_BOX:
          {
            geoc Xs[5], Ys[5];
            geo_t stub_ring, *stub_rings[1], stub;
            Xs[0] = Xs[3] = Xs[4] = g->XYbox.Xmin;
            Xs[1] = Xs[2] = g->XYbox.Xmax;
            Ys[0] = Ys[1] = Ys[4] = g->XYbox.Ymin;
            Ys[2] = Xs[3] = g->XYbox.Ymax;
            memcpy (&stub_ring, g, box_length_inline (g));
            stub_ring.geo_flags &= ~GEO_BOX; stub_ring.geo_flags |= GEO_RING;
            stub_ring._.pline.len = 5;
            stub_ring._.pline.Xs = Xs;
            stub_ring._.pline.Ys = Ys;
            memcpy (&stub, g, box_length_inline (g));
            stub.geo_flags &= ~GEO_BOX; stub.geo_flags |= GEO_POLYGON;
            stub._.parts.len = 1;
            stub_rings[0] = &stub_ring;
            stub._.parts.items = stub_rings;
            result = export_Polygon (&stub);
            break;
          }
        default:
          blocking_error = srv_make_new_error ("22023", "GEO20", "Unable to export geometry of type %d to GEOS library: type is not supported by GEOS", GEO_TYPE (g->geo_flags));
          return NULL;
        }
      result->setSRID(SRID);
      return result;
    }
  catch (const geos::util::GEOSException &gexxx)
    {
      blocking_error = srv_make_new_error ("22023", "GEO20", "Unable to export geometry of type %d to GEOS library: GEOS error: %s", GEO_TYPE (g->geo_flags), gexxx.what());
      return NULL;
    }
}

geos::geom::Point *
geo_exporter_to_geos::export_Point (geo_t *g)
{
  geoc x = g->XYbox.Xmin, y= g->XYbox.Ymin;
  if(inputDimension == 3)
    return factory.createPoint (Coordinate (x, y, g->_.point.point_ZMbox.Zmin));
  return factory.createPoint (Coordinate (x, y));
}

geos::geom::LineString *
geo_exporter_to_geos::export_LineString (geo_t *g)
{
  geos::geom::CoordinateSequence *pts = export_CoordinateSequence (g->_.pline.len, g->_.pline.Xs, g->_.pline.Ys, (g->geo_flags & GEO_A_Z) ? g->_.pline.Zs : NULL);
  return factory.createLineString(pts);
}

geos::geom::LinearRing *
geo_exporter_to_geos::export_LinearRing (geo_t *g)
{
  geos::geom::CoordinateSequence *pts = export_CoordinateSequence (g->_.pline.len, g->_.pline.Xs, g->_.pline.Ys, (g->geo_flags & GEO_A_Z) ? g->_.pline.Zs : NULL);
  return factory.createLinearRing(pts);
}

geos::geom::Polygon *
geo_exporter_to_geos::export_Polygon (geo_t *g)
{
  int numRings = g->_.parts.len;
  geos::geom::LinearRing *shell = NULL;
  std::vector<geos::geom::Geometry *>*holes = NULL;
  try
    {
      if (numRings > 0)
        shell = export_LinearRing (g->_.parts.items[0]);
      if (numRings > 1)
        {
          holes = new std::vector<geos::geom::Geometry *>(numRings - 1);
          for (int i = 1; i < numRings; i++)
            holes[0][i-1] = (geos::geom::Geometry *)export_LinearRing (g->_.parts.items[i]);
        }
      return factory.createPolygon(shell, holes);
    }
  catch (...)
    {
      if (NULL != shell)
        {
          for (unsigned int i=0; i<holes->size(); i++)
            delete holes[0][i];
          delete holes;
        }
      delete shell;
      throw;
    }
}

geos::geom::MultiPoint *
geo_exporter_to_geos::export_MultiPoint(geo_t *g)
{
  int numGeoms = g->_.pline.len;
  std::vector<geos::geom::Geometry *> *geoms = new std::vector<geos::geom::Geometry *>(numGeoms);
  for (int i = 0; i<numGeoms; i++)
    {
      geoc x = g->_.pline.Xs[i], y= g->_.pline.Ys[i];
      geos::geom::Geometry *point = (
        (inputDimension == 3) ?
        factory.createPoint (Coordinate (x, y, g->_.pline.Zs[i])) :
        factory.createPoint (Coordinate (x, y)) );
      geoms[0][i] = point;
    }
  return factory.createMultiPoint(geoms);
}

geos::geom::MultiLineString *
geo_exporter_to_geos::export_MultiLineString (geo_t *g)
{
  int numGeoms = g->_.parts.len;
  std::vector<geos::geom::Geometry *> *geoms = new std::vector<geos::geom::Geometry *>(numGeoms);
  for (int i=0; i<numGeoms; i++)
    geoms[0][i] = export_one (g->_.parts.items[i]);
  return factory.createMultiLineString (geoms);
}

geos::geom::MultiPolygon *
geo_exporter_to_geos::export_MultiPolygon (geo_t *g)
{
  int numGeoms = g->_.parts.len;
  std::vector<geos::geom::Geometry *> *geoms = new std::vector<geos::geom::Geometry *>(numGeoms);
  try
    {
      for (int i=0; i<numGeoms; i++)
        geoms[0][i] = export_one (g->_.parts.items[i]);
      return factory.createMultiPolygon (geoms);
    }
  catch (...)
    {
      for (int i=0; i<numGeoms; i++)
        delete geoms[0][i];
      delete geoms;
      throw;
    }
}

geos::geom::GeometryCollection *
geo_exporter_to_geos::export_GeometryCollection (geo_t *g)
{
  int numGeoms = g->_.parts.len;
  std::vector<geos::geom::Geometry *> *geoms = new std::vector<geos::geom::Geometry *>(numGeoms);
  try
    {
      for (int i=0; i<numGeoms; i++)
        {
          geoms[0][i] = export_one (g->_.parts.items[i]);
          if (NULL == geoms[0][i])
            {
              while (i--) delete geoms[0][i];
              delete geoms;
              return NULL;
            }
        }
      return factory.createGeometryCollection (geoms);
    }
  catch (...)
    {
      for (int i=0; i<numGeoms; i++)
        delete geoms[0][i];
      delete geoms;
      throw;
    }
}

geos::geom::CoordinateSequence *
geo_exporter_to_geos::export_CoordinateSequence (int len, geoc *Xs, geoc *Ys, geoc *Zs_or_null)
{
  geos::geom::CoordinateSequence *seq = factory.getCoordinateSequenceFactory()->create(len, (NULL != Zs_or_null) ? 3 : 2);
  for (int i = 0; i < len; i++)
    {
      seq->setOrdinate (i, 0, Xs[i]);
      seq->setOrdinate (i, 1, Ys[i]);
      if (NULL != Zs_or_null)
        seq->setOrdinate (i, 2, Zs_or_null[i]);
    }
  return seq;
}

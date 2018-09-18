#include <ostream>
#include <sstream>
#include <cassert>

#include <geos/geom/Coordinate.h>
#include <geos/geom/Point.h>
#include <geos/geom/LinearRing.h>
#include <geos/geom/LineString.h>
#include <geos/geom/Polygon.h>
#include <geos/geom/MultiPoint.h>
#include <geos/geom/MultiLineString.h>
#include <geos/geom/MultiPolygon.h>
#include <geos/geom/CoordinateSequence.h>
#include <geos/geom/PrecisionModel.h>

#include "geos_plugin.h"

geo_t *
geo_importer_from_geos::import_one(const Geometry &geom) 
{
  outputDimension = defaultOutputDimension;
  if ( outputDimension > geom.getCoordinateDimension() )
    outputDimension = geom.getCoordinateDimension();

  if ( const geos::geom::Point* x = dynamic_cast<const geos::geom::Point*>(&geom) )
    return import_Point (*x);
  if ( const geos::geom::LineString* x = dynamic_cast<const geos::geom::LineString*>(&geom) )
    return import_LineString (*x, GEO_LINESTRING);
  if ( const geos::geom::Polygon* x = dynamic_cast<const geos::geom::Polygon*>(&geom) )
    return import_Polygon (*x);
  if ( const geos::geom::MultiPoint* x = dynamic_cast<const geos::geom::MultiPoint*>(&geom) )
    return import_MultiPoint (*x);
  if ( const geos::geom::MultiLineString* x = dynamic_cast<const geos::geom::MultiLineString*>(&geom) )
    return import_GeometryCollection (*x, GEO_MULTI_LINESTRING);
  if ( const geos::geom::MultiPolygon* x = dynamic_cast<const geos::geom::MultiPolygon*>(&geom) )
    return import_GeometryCollection (*x, GEO_MULTI_POLYGON);
  if ( const geos::geom::GeometryCollection* x = dynamic_cast<const geos::geom::GeometryCollection*>(&geom) )
    return import_GeometryCollection (*x, GEO_COLLECTION);
  assert(0); // Unknown Geometry type
}

geo_t *
geo_importer_from_geos::import_Point(const geos::geom::Point &geom)
{
  geo_t *g = geo_alloc ((3 == outputDimension) ? GEO_POINT_Z : GEO_POINT, 0, GEO_SRCODE_OF_SRID (geom.getSRID()));
  if (geom.isEmpty())
    {
      g->XYbox.Xmin = g->XYbox.Xmax = g->XYbox.Ymin = g->XYbox.Ymax = geoc_FARAWAY;
      if (3 == outputDimension)
        g->_.point.point_ZMbox.Zmin = g->_.point.point_ZMbox.Zmax = geoc_FARAWAY;
    }
  else
    {
      const Coordinate* c = geom.getCoordinate();
      g->XYbox.Xmin = g->XYbox.Xmax = c->x;
      g->XYbox.Ymin = g->XYbox.Ymax = c->y;
      if (3 == outputDimension)
        g->_.point.point_ZMbox.Zmin = g->_.point.point_ZMbox.Zmax = c->z;
    }
  return g;
}

geo_t *
geo_importer_from_geos::import_LineString (const geos::geom::LineString &geom, int geo_type_no_zm) 
{
  const geos::geom::CoordinateSequence* cs = geom.getCoordinatesRO();
  int len = cs->size();
  geo_t *g = geo_alloc (geo_type_no_zm | ((3 == outputDimension) ? GEO_A_Z : 0), len, GEO_SRCODE_OF_SRID (geom.getSRID()));
  for (int i = 0; i < len; i++) g->_.pline.Xs[i] = (*cs)[i].x;
  for (int i = 0; i < len; i++) g->_.pline.Ys[i] = (*cs)[i].y;
  if (3 == outputDimension)
    for (int i = 0; i < len; i++) g->_.pline.Zs[i] = (*cs)[i].z;
  geo_calc_bounding (g, GEO_CALC_BOUNDING_DO_ALL);
  return g;
}

geo_t *
geo_importer_from_geos::import_MultiPoint (const geos::geom::MultiPoint &geom) 
{
  int len = geom.getNumGeometries();
  geo_t *g = geo_alloc ((3 == outputDimension) ? GEO_POINTLIST_Z : GEO_POINTLIST, len, GEO_SRCODE_OF_SRID (geom.getSRID()));
  for (int i = 0; i < len; i++) g->_.pline.Xs[i] = geom.getGeometryN(i)->getCoordinate()->x;
  for (int i = 0; i < len; i++) g->_.pline.Ys[i] = geom.getGeometryN(i)->getCoordinate()->y;
  if (3 == outputDimension)
    for (int i = 0; i < len; i++) g->_.pline.Zs[i] = geom.getGeometryN(i)->getCoordinate()->z;
  geo_calc_bounding (g, GEO_CALC_BOUNDING_DO_ALL);
  return g;
}

geo_t *
geo_importer_from_geos::import_Polygon (const geos::geom::Polygon &geom) 
{
  int len = (geom.isEmpty() ? 0 : (1 + geom.getNumInteriorRing()));
  geo_t *g = geo_alloc ((3 == outputDimension) ? GEO_POLYGON_Z : GEO_POLYGON, len, GEO_SRCODE_OF_SRID (geom.getSRID()));
  if (0 < len)
    {
      const geos::geom::LineString* ls = geom.getExteriorRing();
      g->_.parts.items[0] = import_LineString (*ls, GEO_RING);
    }
  for (int i = 1; i < len; i++)
    g->_.parts.items[i] = import_LineString (*(geom.getInteriorRingN (i - 1)), GEO_RING);
  geo_calc_bounding (g, GEO_CALC_BOUNDING_DO_ALL & ~(GEO_CALC_BOUNDING_TRANSITIVE));
  return g;
}

geo_t *
geo_importer_from_geos::import_GeometryCollection (const GeometryCollection &geom, int geo_type_no_zm) 
{
  int len = geom.getNumGeometries();
  geo_t *g = geo_alloc (geo_type_no_zm | ((3 == outputDimension) ? GEO_A_Z : 0), len, GEO_SRCODE_OF_SRID (geom.getSRID()));
  for (int i = 0; i < len; i++)
    g->_.parts.items[i] = import_one (*(geom.getGeometryN(i)));
  geo_calc_bounding (g, GEO_CALC_BOUNDING_DO_ALL & ~(GEO_CALC_BOUNDING_TRANSITIVE));
  return g;
}

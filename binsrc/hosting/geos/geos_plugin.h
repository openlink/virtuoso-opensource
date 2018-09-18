#ifndef GEOS_PLUGIN_H
#define GEOS_PLUGIN_H

#include <vector>
#include <string>
#include <geos.h>
#include <geos/export.h>
#include <geos/geom/GeometryFactory.h>

extern "C" {
#include "Dk.h"
#include "geo.h"
#include "import_gate_virtuoso.h"
};

class geo_exporter_to_geos {
  const geos::geom::GeometryFactory &factory;
public:
  geo_exporter_to_geos(geos::geom::GeometryFactory const& f): factory(f), blocking_error (NULL) {}
  geos::geom::Geometry* export_one(geo_t *g);
  caddr_t blocking_error;
private:
  unsigned int inputDimension;
  geos::geom::Point *export_Point (geo_t *g);
  geos::geom::LineString *export_LineString (geo_t *g);
  geos::geom::LinearRing *export_LinearRing (geo_t *g);
  geos::geom::Polygon *export_Polygon (geo_t *g);
  geos::geom::MultiPoint *export_MultiPoint (geo_t *g);
  geos::geom::MultiLineString *export_MultiLineString (geo_t *g);
  geos::geom::MultiPolygon *export_MultiPolygon (geo_t *g);
  geos::geom::GeometryCollection *export_GeometryCollection (geo_t *g);
  geos::geom::CoordinateSequence *export_CoordinateSequence (int len, geoc *Xs, geoc *Ys, geoc *Zs_or_null);
  geo_exporter_to_geos(const geo_exporter_to_geos& other); // to make the type noncopyable
  geo_exporter_to_geos& operator=(const geo_exporter_to_geos& rhs); // to make the type noncopyable
};

class geo_importer_from_geos {
public:
  geo_importer_from_geos (int dims): defaultOutputDimension(dims), outputDimension (dims) {}
  geo_t *import_one (const geos::geom::Geometry &geom);
private:
  int defaultOutputDimension;
  int outputDimension;
  geo_t *import_Point (const geos::geom::Point &p);
  geo_t *import_LineString (const geos::geom::LineString &ls, int geo_type_no_zm);
  geo_t *import_MultiPoint (const geos::geom::MultiPoint &ls);
  geo_t *import_Polygon (const geos::geom::Polygon &p);
  geo_t *import_GeometryCollection (const geos::geom::GeometryCollection &c, int geo_type_no_zm);
};

#endif // #ifndef GEOS_PLUGIN_H

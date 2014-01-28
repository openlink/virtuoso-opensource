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

#ifndef _GEO_H
#define _GEO_H


#include "wi.h"


/* Geo object types, supported in pre-7 versions */

#define GEO_NULL_SHAPE		0x0000	/*!< A stub for keeping attributes without a shape or attributes of an unknown shape */
#define GEO_POINT		0x0001	/*!< Single point (with Z or M as modifications) */
#define GEO_LINESTRING		0x0002	/*!< Opened or closed polyline of straight segments, closing point is repeated as first and last (with possible Z or M as modifications) */
#define GEO_BOX			0x0003	/*!< Box described by SW (and lowest) and NE (and highest) corners (with possible Z or M as modifications) */

#define GEO_IS_FLOAT		0x0040	/*!< indicates that floats are used for serialization */
#define GEO_IS_DEFAULT_SRCODE	0x0080	/*!< in serialization flags, means no 2 byte srid */
#define GEO_IS_CHAINBOXED	0x0100	/*!< Indicates that the object contains chainboxes */

/* Geo object types, recent extensions */

#define GEO_2BYTE_TYPE		0x0020	/*!< Indicates that the type is greater than 255, so its serialization contains an extra byte */

#define GEO_POINTLIST		0x0004	/*!< List of individual points without segments between them */
#define GEO_ARCSTRING		0x0005	/*!< Opened or closed polyline of arc segments, closing point is repeated as first and last (so far, no Z or M as modifications) */
#define GEO_GSOP		0x0006	/*!< Geosearch operation with parameters */
#define GEO_UNDEFTYPE		0x000F	/*!< Indicastes that the type is internally heterogenous, it should be inspected in depth to understand its dimension etc. */

#define GEO_A_Z			0x0200	/*!< Indicates that the shape has Z (elevation) coordinate */
#define GEO_A_M			0x0400	/*!< Indicates that the shape has M coordinate of any purpose (traditional measure along the shape, milestones or even a timestamp) */

#define GEO_A_CLOSED		0x0800	/*!< The shape is closed. In this case the last recorded vertex should be equal to the first vertex, or at least the distance in XY plane must be less than FLT_EPSILON */
#define GEO_A_COMPOUND		0x1000	/*!< The shape is an chained ordered compound of shorter shapes so that one shape starts at the end of previous shape. */
#define GEO_A_RINGS		0x2000	/*!< The shape is a single connected region of dimension 2 that may be described by multiple rings (borders) of dimension 1. In this case first ring is exterior and all other are holes */
#define GEO_A_MULTI		0x4000	/*!< The shape is an unordered union of pairwise dim2-disjoint "connected regions" or a union of 1-dimentional shapes. Members of "multi"-shape should be all of same type, their order is not preserved, they should not intersect with nonzero intersection areas (i.e., no more than some common lines). Note that pointlist is not a MULTI because it's ordered. */
#define GEO_A_ARRAY		0x8000	/*!< The shape is an ordered group of other shapes. Unlike MULTI, No restrictions and no pairwise properties are known for members of an ARRAY and the ARRAY may contain MULTIs but not vica versa. If members of ARRAY are declared in type as GEO_UNDEFTYPE then ARRAY may contain other ARRAYs. */

#define GEO_TYPE_CORE_MASK	0x000F	/*!< This mask is used to get the type of very basic primitives that used to form a more complex shape */
#define GEO_TYPE_NO_ZM_MASK	0xF80F	/*!< This mask is used for all "planar" operations that ignore Z and M dimensions */
#define GEO_TYPE_MASK		0xFE0F	/*!< This mask is used to filter out serialization details preserving all "mathematical" attributes */

#define GEO_POINT_Z		(GEO_POINT	| GEO_A_Z)
#define GEO_POINT_M		(GEO_POINT	| GEO_A_M)
#define GEO_POINT_Z_M		(GEO_POINT	| GEO_A_Z	| GEO_A_M)
#define GEO_BOX_Z		(GEO_BOX	| GEO_A_Z)
#define GEO_BOX_M		(GEO_BOX	| GEO_A_M)
#define GEO_BOX_Z_M		(GEO_BOX	| GEO_A_Z	| GEO_A_M)
#define GEO_RING		(GEO_LINESTRING	| GEO_A_CLOSED)
#define GEO_RING_Z		(GEO_LINESTRING	| GEO_A_CLOSED	| GEO_A_Z)
#define GEO_RING_M		(GEO_LINESTRING	| GEO_A_CLOSED	| GEO_A_M)
#define GEO_RING_Z_M		(GEO_LINESTRING	| GEO_A_CLOSED	| GEO_A_Z	| GEO_A_M)
#define GEO_POINTLIST_Z		(GEO_POINTLIST	| GEO_A_Z)
#define GEO_POINTLIST_M		(GEO_POINTLIST	| GEO_A_M)
#define GEO_POINTLIST_Z_M	(GEO_POINTLIST	| GEO_A_Z	| GEO_A_M)
#define GEO_LINESTRING_Z	(GEO_LINESTRING	| GEO_A_Z)
#define GEO_LINESTRING_M	(GEO_LINESTRING	| GEO_A_M)
#define GEO_LINESTRING_Z_M	(GEO_LINESTRING	| GEO_A_Z	| GEO_A_M)
#define GEO_MULTI_LINESTRING	(GEO_LINESTRING	| GEO_A_MULTI)
#define GEO_MULTI_LINESTRING_M	(GEO_LINESTRING	| GEO_A_MULTI	| GEO_A_M)
#define GEO_MULTI_LINESTRING_Z	(GEO_LINESTRING	| GEO_A_MULTI	| GEO_A_Z)
#define GEO_MULTI_LINESTRING_Z_M	(GEO_LINESTRING	| GEO_A_MULTI	| GEO_A_Z	| GEO_A_M)
#define GEO_POLYGON		(GEO_LINESTRING	| GEO_A_CLOSED	| GEO_A_RINGS)
#define GEO_POLYGON_Z		(GEO_LINESTRING	| GEO_A_CLOSED	| GEO_A_RINGS	| GEO_A_Z)
#define GEO_POLYGON_M		(GEO_LINESTRING	| GEO_A_CLOSED	| GEO_A_RINGS	| GEO_A_M)
#define GEO_POLYGON_Z_M		(GEO_LINESTRING	| GEO_A_CLOSED	| GEO_A_RINGS	| GEO_A_Z	| GEO_A_M)
#define GEO_MULTI_POLYGON	(GEO_LINESTRING	| GEO_A_CLOSED	| GEO_A_RINGS	| GEO_A_MULTI)
#define GEO_MULTI_POLYGON_Z	(GEO_LINESTRING	| GEO_A_CLOSED	| GEO_A_RINGS	| GEO_A_MULTI	| GEO_A_Z)
#define GEO_MULTI_POLYGON_M	(GEO_LINESTRING	| GEO_A_CLOSED	| GEO_A_RINGS	| GEO_A_MULTI	| GEO_A_M)
#define GEO_MULTI_POLYGON_Z_M	(GEO_LINESTRING	| GEO_A_CLOSED	| GEO_A_RINGS	| GEO_A_MULTI	| GEO_A_Z	| GEO_A_M)
#define GEO_COLLECTION		(GEO_UNDEFTYPE	| GEO_A_ARRAY)
#define GEO_COLLECTION_Z	(GEO_UNDEFTYPE	| GEO_A_ARRAY	| GEO_A_Z)
#define GEO_COLLECTION_M	(GEO_UNDEFTYPE	| GEO_A_ARRAY	| GEO_A_M)
#define GEO_COLLECTION_Z_M	(GEO_UNDEFTYPE	| GEO_A_ARRAY	| GEO_A_Z	| GEO_A_M)
#define GEO_CURVE		(GEO_ARCSTRING	| GEO_A_COMPOUND)
#define GEO_CLOSEDCURVE		(GEO_ARCSTRING	| GEO_A_COMPOUND	| GEO_A_CLOSED)
#define GEO_CURVEPOLYGON	(GEO_ARCSTRING	| GEO_A_COMPOUND	| GEO_A_CLOSED	| GEO_A_RINGS)
#define GEO_MULTI_CURVE		(GEO_ARCSTRING	| GEO_A_COMPOUND	| GEO_A_MULTI)

typedef unsigned short geo_srid_t;	/*!< Type for Spatial Reference system ID */
typedef unsigned short geo_srcode_t;	/*!< Type for internal code of SRID and its internal details. So far, srcode of a SRID is equal to SRID itself but scrode may get additional bit flags in the future */
typedef unsigned short geo_flags_t;	/*!< Type for flags of a shape (type + serialization details */

#define GEO_ARG_ANY_NONNULL	0x50000000	/*!< Special value for use in bif_geo_arg to indicate that the argument can be of any shapetype but not NULL. It does not fit into \c geo_flags_t shortint! */
#define GEO_ARG_ANY_NULLABLE	0x60000000	/*!< Special value for use in bif_geo_arg to indicate that the argument can be of any shapetype or a NULL. It does not fit into \c geo_flags_t shortint! */
#define GEO_ARG_ANY_MASK	0x40000000	/*!< Mask for \c GEO_ARG_ANY_xxx values. */

typedef double geoc;		/*!< Type of geographical coordinate */
typedef double geo_measure_t;	/*!< Type of M coordinate */

#define geoc_FARAWAY ((geoc)(1e38))	/*!< A very distant coordinate that will not appear on any map, but not an infinity and vector operations will not overflow */

/*! Point on a plane or on a latlong grid */
typedef struct geo_point_s
{
  geoc	p_X;	/*!< Horisontal or left-to-right or longitude (_usually_ -180.0 to +180.0 and _always_ -270.0-FLT_EPSILON to +610.0+FLT_EPSILON for WGS84) */
  geoc	p_Y;	/*!< Height or behind-to-ahead or latitude (_always_ -90.0-FLT_EPSILON to +90.0+FLT_EPSILON for WGS84) */
} geo_point_t;

/*! A canonical rectlinear bounding box for X+Y or long+lat. It may be stretched by FLT_EPSILON from "mathematical" bounding box or not, depending on its use. */
typedef struct geo_XYbox_s
{
  geoc	Xmin; /*!< West side of bounding box */
  geoc 	Xmax; /*!< East side of bounding box */
  geoc 	Ymin; /*!< South side of bounding box */
  geoc 	Ymax; /*!< Northern side of bounding box */
} geo_XYbox_t;

/*! Set the box to twisted actual infinity. Stretching it by any real point will set it to that point so it's a good initialisation value for any stretching aggregate */
#define GEO_XYBOX_SET_EMPTY(bbox) \
  do { (bbox).Xmin = (bbox).Ymin = geoc_FARAWAY; (bbox).Xmax = (bbox).Ymax = -geoc_FARAWAY; } while (0)

/*! Set the box to a point */
#define GEO_XYBOX_SET_TO_POINT(tgt_bbox,x,y) \
  do { \
    (tgt_bbox).Xmin = (tgt_bbox).Xmax = (x); \
    (tgt_bbox).Ymin = (tgt_bbox).Ymax = (y); \
    } while (0)

/*! Stretches the box to fit a point */
#define GEO_XYBOX_STRETCH_BY_POINT(tgt_bbox,x,y) \
  do { \
    (tgt_bbox).Xmin = MIN((tgt_bbox).Xmin, (x)); (tgt_bbox).Xmax = MAX((tgt_bbox).Xmax, (x)); \
    (tgt_bbox).Ymin = MIN((tgt_bbox).Ymin, (y)); (tgt_bbox).Ymax = MAX((tgt_bbox).Ymax, (y)); \
    } while (0)

/*! Stretches the box to fit another box */
#define GEO_XYBOX_STRETCH_BY_XYBOX(tgt_bbox,addon_bbox) \
  do { \
    (tgt_bbox).Xmin = MIN((tgt_bbox).Xmin, (addon_bbox).Xmin); (tgt_bbox).Xmax = MAX((tgt_bbox).Xmax, (addon_bbox).Xmax); \
    (tgt_bbox).Ymin = MIN((tgt_bbox).Ymin, (addon_bbox).Ymin); (tgt_bbox).Ymax = MAX((tgt_bbox).Ymax, (addon_bbox).Ymax); \
    } while (0)

#define GEO_XYBOX_COPY_NONEMPTY_OR_FARAWAY(tgt_bbox,src_bbox) \
  do { (tgt_bbox).Xmin = (src_bbox).Xmin; (tgt_bbox).Ymin = (src_bbox).Ymin; \
    if ((src_bbox).Xmax >= geoc_FARAWAY) \
      (tgt_bbox).Xmax = (tgt_bbox).Ymax = /* no minus here */ geoc_FARAWAY; \
    else \
      { (tgt_bbox).Xmax = (src_bbox).Xmax; (tgt_bbox).Ymax = (src_bbox).Ymax; } \
    } while (0)

/*! A bounding box for elevation and optionally measure */
typedef struct geo_ZMbox_s
{
  geoc Zmin;
  geoc Zmax;
  geo_measure_t Mmin;
  geo_measure_t Mmax;
} geo_ZMbox_t;

/*! Bounding chainbox to keep more accutare bounding of a long shape than a single box around the whole shape.
Bounding box of well-depicted Missouri river is next to useless if you want to check whether a point in Nebraska is close to the river, because the whole Nebraska is deep inside that bounding box.
The chainbox stores bounding boxes of relatively small fragments of a long shape, the total area of these boxes can be few orders of magnitude smaller than the area of a common bounding box, so it's much more informative.
The disadvantage is that the search in a chainbox costs more than check of a single big box (but much less than check for each line, esp. for curves), and the calculation of chainbox will take time.
So it can be allocated but not filled in. */
typedef struct geo_chainbox_s
{
  int gcb_box_count;		/*!< Number of boxes */
  short gcb_step;		/*!< Step, i.e., how many segments or items per box are kept, an arc is counted here as two segments */
  char gcb_is_set;		/*!< Nonzero if \c gcb_boxes are calculated, not only allocated */
  geo_XYbox_t gcb_boxes[];	/*!< Boxes that contain segments */
} geo_chainbox_t;

typedef struct geo_s
{
  geo_flags_t	geo_flags;
  geo_srcode_t	geo_srcode;
  int		geo_fill;
  geo_XYbox_t	XYbox;
  struct {
    struct {
/* There's no special data for GEO_POINT and GEO_BOX, it's defined by its bbox */
#define Xkey XYbox.Xmin
#define Ykey XYbox.Ymin
      geo_ZMbox_t	point_ZMbox;
      int		point_gs_op;
      int		point_gs_precision;
    } point;
/*! Multipoint, single ring of polygon */
    struct {
      int	len;	/*!< Number of points */
      geoc *	Xs;	/*!< X coords of points */
      geoc *	Ys;	/*!< Y coords of points */
      geo_chainbox_t *pline_gcb;	/*!< Pointer to chainbox, allocated if pline is long enough for its type */
      geoc *	Zs;	/*!< Z coords of points (if geo_flags & GEO_A_Z) */
      geo_ZMbox_t	pline_ZMbox;
      geo_measure_t *	Ms;	/*!< Measures at points (if geo_flags & GEO_A_M) */
    } pline;
/*! Multilinestring, polygon, multipolygon, collection */
    struct {
      int len;		/*!< Number of items */
      int serialization_length;	/*!< Length of serialization of this box if it's top-level, minus length of serialization of this length */
      struct geo_s **items;	/*!< Items (parts of multilinestring, rings of polygon, polygons of multipolygon, items of collecetion etc. */
      geo_chainbox_t *parts_gcb;	/*!< Pointer to chainbox, allocated if pline is long enough for its type */
      geo_ZMbox_t	parts_ZMbox;
    } parts;
  } _;
} geo_t;

#define GEO_TYPE_CORE(flags) ((flags) & GEO_TYPE_CORE_MASK)
#define GEO_TYPE_NO_ZM(flags) ((flags) & GEO_TYPE_NO_ZM_MASK)
#define GEO_TYPE(flags) ((flags) & GEO_TYPE_MASK)
#define G_OP(f) ((f) >> 8)

#define SRID_WGS84	4326		/*!< I know one mapmaker who had chosen these four digits as last digits of his business phone */
#define SRID_DEFAULT	SRID_WGS84

#define GEO_SRID(srcode) (srcode)
#define GEO_SRCODE_OF_SRID(srid) (srid)
#define GEO_SRCODE_DEFAULT GEO_SRCODE_OF_SRID(SRID_DEFAULT)
/*! Returns whether the \c srcode belongs to a coordinate system that uses latitude in degrees as Y and some (maybe shifted) longitude in degrees as X on a depressed spheroid */
#define GEO_SR_SPHEROID_DEGREES(srcode) (SRID_WGS84 == (srcode))
/*! Returns whether the \c srcode belongs to a coordinate system that uses longitude in degrees as X and it usually ranges from -180 to +180 */
#define GEO_SR_WRAPS180(srcode) (SRID_WGS84 == (srcode))

/* These are from WGS 84: */
#define EARTH_RADIUS_POLAR_KM 6356.752314245
#define EARTH_RADIUS_GEOM_MEAN_KM 6367.43568
#define EARTH_RADIUS_EQUATOR_KM 6378.137


extern double haversine_deg_km (double long1, double lat1, double long2, double lat2);
extern int geo_pred (geo_t * g1, geo_t * g2, int op, double prec);
extern geo_t *geo_point (double x, double y);
struct dbe_table_s;
extern int64 geo_estimate (struct dbe_table_s * tb, geo_t * g, int op, double prec, slice_id_t slice);

#define DEG_TO_RAD (M_PI / 180)
#define KM_TO_DEG (360 / (EARTH_RADIUS_GEOM_MEAN_KM * 2 * M_PI))

EXE_EXPORT (geo_t *, geo_alloc, (geo_flags_t geo_flags, int geo_len, int srid));
EXE_EXPORT (geo_t *, geo_point, (geoc x, geoc y));

EXE_EXPORT (geo_t *, geo_copy, (geo_t *g));
EXE_EXPORT (geo_t *, mp_geo_copy, (mem_pool_t * mp, geo_t *g));
EXE_EXPORT (int, geo_destroy, (geo_t *g));

EXE_EXPORT (void, geo_serialize, (geo_t * g, dk_session_t * ses));
EXE_EXPORT (caddr_t, geo_deserialize, (dk_session_t * ses));

/* EWKT Reader */

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
  const char *	kwd_name;
  int		kwd_dictserial;
  int		kwd_type;
  int		kwd_subtype;
  int		kwd_parens_after;
  int		kwd_min_nums;
  int		kwd_max_nums;
  int		kwd_is_alias;
} ewkt_kwd_metas_t;

EXE_EXPORT (ewkt_kwd_metas_t *, ewkt_find_metas_by_geotype, (int geotype));
EXE_EXPORT (geo_t *, ewkt_parse, (const char *strg, caddr_t *err_ret));
EXE_EXPORT (void, ewkt_print_sf12, (geo_t *g, dk_session_t *ses));

EXE_EXPORT (geo_t *, bif_geo_arg, (caddr_t * qst, struct state_slot_s ** args, int inx, const char *fname, int geotype));

#define GEO_LONG360ADD_ALREADY_CHANGED	0x01	/*!< The shape contains vertexes to the right from +180.0 already */
#define GEO_LONG360ADD_NO_CHANGE	0x02	/*!< Some (maybe not all) nodes/points are not shifted to the right */
#define GEO_LONG360ADD_SOME_CHANGED	0x04	/*!< Some (maybe not all) nodes/points are shifted to the right */
#define GEO_LONG360ADD_WEIRD		0x08	/*!< The shape is weird, e.g. it runs around pole or contain chaotical long jumps */
#define GEO_LONG360ADD_POLE_PROXIMITY	0x10	/*!< Some portion of shape is so close to pole that can look weird even if correct */
#define GEO_LONG360ADD_STARTS_AT_RIGHT	0x20	/*!< The shape begins at its right side, first "long jump" is from "Alaska" to "Chukotka" */
#define GEO_LONG360ADD_NEEDS_CHANGE	0x40	/*!< Some (maybe not all) nodes should be shifted to the right (for internal use only) */
EXE_EXPORT (int, geo_long360add, (geo_t * g));
#define GEO_CALC_BOUNDING_TRANSITIVE	0x01	/*!< For non-leaf shapes, re-calculate bounding boxes of all descendants before aggregating them */
#define GEO_CALC_BOUNDING_MAY_SHIFT	0x02	/*!< The procedure has right to shift (add 360 to the longitude) the shape or its parts if that will improve the bbox */
#define GEO_CALC_BOUNDING_DO_ALL	0xff	/*!< The procedure should make all calculations and all optimisations from scratch */
EXE_EXPORT (int, geo_calc_bounding, (geo_t * g, int flags));
EXE_EXPORT (void, geo_get_bounding_XYbox, (geo_t * g, geo_t * box, double prec_x, double prec_y));
EXE_EXPORT (geo_ZMbox_t *, geo_get_ZMbox_field, (geo_t * g));
extern geo_t *geo_parse_ewkt (const char *text);
extern geo_t *geo_parse_ewkt_sub (const char *text, int expected_type);
extern void dks_print_ewkt (dk_session_t *ses, geo_t *sg);

EXE_EXPORT (double, geo_ccw_flat_area, (geo_t *g));
EXE_EXPORT (void, geo_inverse_point_order, (geo_t *g));
EXE_EXPORT (int, geo_XYbbox_inside, (geo_XYbox_t *inner, geo_XYbox_t *outer));

#define GEO_INOUTSIDE_OUT	0x01	/*!< Flags that the point is strictly outside the (nondirectional) ring */
#define GEO_INOUTSIDE_BORDER	0x02	/*!< Flags that the point is at the border of the region surrounded by (nondirectional) ring */
#define GEO_INOUTSIDE_IN	0x04	/*!< Flags that the point is strictly inside the (nondirectional) ring */
#define GEO_INOUTSIDE_CLOCKWISE	0x20	/*!< Flags that the ring is oriented clockwise */
#define GEO_INOUTSIDE_ERROR	0x80	/*!< Flags that the ring is weird enough to trigger an error. No error does not guarantee that the ring is not weird */

EXE_EXPORT (int, geo_XY_inoutside_ring, (geoc pX, geoc pY, geo_t *ring));
EXE_EXPORT (int, geo_XY_inoutside_polygon, (geoc pX, geoc pY, geo_t *g));

typedef boxint geo_de9im_mask_t;

/* Allowed or found state of cell of DE-9IM model matrix. Bit values are chosen in such a way that mask code can be bitwise ANDed with the intersection data. */
#define GEO_DE9IM_CONFL		0x0	/*!< The cell of the matrix should contain conflicting requirements, like F and DPOINT. No one pair of shapes may match it. */
#define GEO_DE9IM_F		0x1	/*!< Intersection is totally empty */
#define GEO_DE9IM_DPOINT	0x2	/*!< Intersection consists of individual points */
#define GEO_DE9IM_DLINE		0x4	/*!< Intersection consists of individual lines (and optionally points, but lines should present) */
#define GEO_DE9IM_NOTF		0x7	/*!< Intersection is not empty and the dimension is not important */
#define GEO_DE9IM_T		0x8	/*!< Intersection is "T", i.e., its dimension is equal to smaller of dimensions of arguments */
#define GEO_DE9IM_STAR		0xF	/*!< Intersection could be any, ranging from T to empty */
#define GEO_DE9IM_CELL_FILLER	0xF	/*!< The default value for cells */

/* Indicies of cells of DE-9IM matrix in mask code or in intersection data */
#define GEO_DE9IM_II		0
#define GEO_DE9IM_IB		1
#define GEO_DE9IM_IE		2
#define GEO_DE9IM_BI		3
#define GEO_DE9IM_BB		4
#define GEO_DE9IM_BE		5
#define GEO_DE9IM_EI		6
#define GEO_DE9IM_EB		7
/*#define GEO_DE9IM_EE		8*/ /* EE is always GEO_DE9IM_T so there's no need to store it */
#define GEO_DE9IM_TOTALBITS	32

/* Hex notation of a mask code is readed left to right, one hex digit per cell.
Say, masks of OVERLAPS oeprator, "T*T***T**" and "1*T***T**"
                                  |:|:::|::       |:|:::|::
will be recorded as             0x8f8fff8ff and 0x2f8fff8ff
Note that "0", "1", "2" and "F" are NOT encoded as 0x0, 0x1, 0x2 and 0xF. */
#define GEO_DE9IM_CELL_SHIFT_BITS(idx) (GEO_DE9IM_TOTALBITS-(idx)*4)
#define GEO_DE9IM_SHIFTED_CELL(idx,val) (((geo_de9im_mask_t)(val)) << GEO_DE9IM_CELL_SHIFT_BITS((idx)))
#define GEO_DE9IM_GETCELL(mask,idx) (((mask) >> GEO_DE9IM_CELL_SHIFT_BITS((idx))) & GEO_DE9IM_CELL_FILLER);
#define GEO_DE9IM_SETCELL(mask,idx,val) do { \
  (mask) = (((mask) & ~GEO_DE9IM_SHIFTED_CELL((idx),GEO_DE9IM_CELL_FILLER)) \
    | GEO_DE9IM_SHIFTED_CELL((idx),(val)) ); } while (0);

#ifdef NDEBUG
#undef GEO_DEBUG
#endif

#ifdef GEO_DEBUG
#define geo_dbg_printf(x) printf x
#else
#define geo_dbg_printf(x)
#endif

#endif

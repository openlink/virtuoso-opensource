#include "shapefil.h"

#define READ_ALL_SHAPES_SKIP_NULLS		0x01
#define READ_ALL_SHAPES_SKIP_UNSUPPORTED	0x02

typedef struct dbf_fld_s {
  char df_name[12];
  char df_native_type;
  int df_fetch_type;
  int df_dtp;
  int df_width;
  int df_decimals;
} dbf_fld_t;

typedef struct shapefileio_ctx_s {
  struct query_instance_s *shpio_qi;
  int shpio_srid;
  int shpio_srcode;
  int shpio_flags;
  int shpio_calc_bounding_flags;
  ccaddr_t shpio_cbk_name_mdata;
  ccaddr_t shpio_cbk_name_plain;
  ccaddr_t shpio_cbk_name_null;
  ccaddr_t shpio_cbk_name_bad;
  query_t *shpio_cbk_fn_mdata;
  query_t *shpio_cbk_fn_plain;
  query_t *shpio_cbk_fn_null;
  query_t *shpio_cbk_fn_bad;
  SHPHandle shpio_shph;
  DBFHandle shpio_dbfh;
  int shpio_dbf_field_count;
  dbf_fld_t *shpio_dbf_fields;
  caddr_t *shpio_dbf_cbk_mdata;
} shapefileio_ctx_t;

geo_t *
geo_construct_from_SHPObject_point (shapefileio_ctx_t *ctx, SHPObject *obj, caddr_t *err_ret)
{
  int flags;
  geo_t *res;
  switch (obj->nSHPType)
    {
    case SHPT_POINT: flags = GEO_POINT; break;
    case SHPT_POINTZ: flags = GEO_POINT_Z; break;
    case SHPT_POINTM: flags = GEO_POINT_M; break;
    default: GPF_T;
    }
  res = geo_alloc (flags, 0, ctx->shpio_srcode);
  res->XYbox.Xmin = res->XYbox.Xmax = obj->padfX[0];
  res->XYbox.Ymin = res->XYbox.Ymax = obj->padfY[0];
  if (flags & GEO_A_Z)
    res->_.point.point_ZMbox.Zmin = res->_.point.point_ZMbox.Zmax = obj->padfZ[0];
  if (flags & GEO_A_M)
    res->_.point.point_ZMbox.Mmin = res->_.point.point_ZMbox.Mmax = obj->padfM[0];
  return res;
}

geo_t *
geo_construct_from_SHPObject_pline (shapefileio_ctx_t *ctx, SHPObject *obj, int flags, int start_vertex, int len)
{
  int ctr;
  geo_t *res = geo_alloc (flags, len, ctx->shpio_srcode);
  if (sizeof (geoc) != sizeof (double))
    {
      for (ctr = len; ctr--; /* no step */)
        {
          res->_.pline.Xs[ctr] = obj->padfX [ctr + start_vertex];
          res->_.pline.Ys[ctr] = obj->padfY [ctr + start_vertex];
        }
      if (flags & GEO_A_Z)
        for (ctr = obj->nVertices; ctr--; /* no step */) res->_.pline.Zs[ctr] = obj->padfZ[ctr + start_vertex];
      if (flags & GEO_A_M)
        for (ctr = obj->nVertices; ctr--; /* no step */) res->_.pline.Ms[ctr] = obj->padfM[ctr + start_vertex];
    }
  else
    {
      memcpy (res->_.pline.Xs, obj->padfX + start_vertex, len * sizeof (double));
      memcpy (res->_.pline.Ys, obj->padfY + start_vertex, len * sizeof (double));
      if (flags & GEO_A_Z)
        memcpy (res->_.pline.Zs, obj->padfZ + start_vertex, len * sizeof (double));
      if (flags & GEO_A_M)
        memcpy (res->_.pline.Ms, obj->padfM + start_vertex, len * sizeof (double));
    }
  return res;
}

geo_t *
geo_construct_from_SHPObject_plines (shapefileio_ctx_t *ctx, SHPObject *obj, int base_flags, int partlist_flags, caddr_t *err_ret)
{
  int ctr, parts_count = obj->nParts;
  int v_pastend;
  geo_t *res;
  if (2 > parts_count)
    return geo_construct_from_SHPObject_pline (ctx, obj, base_flags, 0, obj->nVertices);
  v_pastend = obj->nVertices;
  res = geo_alloc (partlist_flags, parts_count, ctx->shpio_srcode);
  for (ctr = parts_count; ctr--; /* no step */)
    {
      int v_begin = obj->panPartStart[ctr];
      if ((v_begin < 0) || (v_begin >= v_pastend))
        {
          err_ret[0] = srv_make_new_error ("22023", "SHP04", "Part %d/%d of shape (ShapeId=%d) has invalid offsets of starting and ending vertexes (%d and %d), bad shapefile?", ctr+1, parts_count, obj->nShapeId, v_begin, v_pastend);
          dk_free_box (res);
          return NULL;
        }
      geo_t *part = geo_construct_from_SHPObject_pline (ctx, obj, base_flags, v_begin, v_pastend - v_begin);
      res->_.parts.items[ctr] = part;
      v_pastend = v_begin;
    }
  return res;
}

geo_t *
geo_construct_from_SHPObject (shapefileio_ctx_t *ctx, SHPObject *obj, caddr_t *err_ret)
{
  int base_flags = 0, partlist_flags = 0, multi_flags = 0;
  geo_t *res;
  switch (obj->nSHPType)
    {
      case SHPT_POINT: case SHPT_POINTZ: case SHPT_POINTM:
        return geo_construct_from_SHPObject_point (ctx, obj, err_ret);
      case SHPT_MULTIPOINT:  return geo_construct_from_SHPObject_pline (ctx, obj, GEO_POINTLIST,   0, obj->nVertices);
      case SHPT_MULTIPOINTZ: return geo_construct_from_SHPObject_pline (ctx, obj, GEO_POINTLIST_Z, 0, obj->nVertices);
      case SHPT_MULTIPOINTM: return geo_construct_from_SHPObject_pline (ctx, obj, GEO_POINTLIST_M, 0, obj->nVertices);
      case SHPT_ARC:  partlist_flags = GEO_LINESTRING;   multi_flags = GEO_MULTI_LINESTRING;   goto mk_linestrings;
      case SHPT_ARCZ: partlist_flags = GEO_LINESTRING_Z; multi_flags = GEO_MULTI_LINESTRING_Z; goto mk_linestrings;
      case SHPT_ARCM: partlist_flags = GEO_LINESTRING_M; multi_flags = GEO_MULTI_LINESTRING_M; goto mk_linestrings;
      case SHPT_POLYGON:  base_flags = GEO_RING;   partlist_flags = GEO_POLYGON;   multi_flags = GEO_MULTI_POLYGON;   goto mk_polygons;
      case SHPT_POLYGONZ: base_flags = GEO_RING_Z; partlist_flags = GEO_POLYGON_Z; multi_flags = GEO_MULTI_POLYGON_Z; goto mk_polygons;
      case SHPT_POLYGONM: base_flags = GEO_RING_M; partlist_flags = GEO_POLYGON_M; multi_flags = GEO_MULTI_POLYGON_M; goto mk_polygons;
      default: GPF_T;
    }

mk_linestrings:
  res = geo_construct_from_SHPObject_plines (ctx, obj, partlist_flags, multi_flags, err_ret);
  if (NULL == res)
    return NULL;
  geo_calc_bounding (res, ctx->shpio_calc_bounding_flags);
  return res;

mk_polygons:
  res = geo_construct_from_SHPObject_plines (ctx, obj, base_flags, partlist_flags, err_ret);
  if (NULL == res)
    return NULL;
  if (GEO_TYPE(res->geo_flags) == GEO_TYPE (base_flags))
    {
      geo_t *poly = geo_alloc (partlist_flags, 1, ctx->shpio_srcode);
      if (geo_ccw_flat_area (res) < 0)
        geo_inverse_point_order (res);
      geo_calc_bounding (res, ctx->shpio_calc_bounding_flags);
      poly->_.parts.items[0] = res;
      geo_calc_bounding (poly, 0);
      res = poly;
    }
  else if (2 > res->_.parts.len) /* weird */
    {
      GPF_T;
    }
  else
    {
      /* There's a severe problem with complicated shapefile polygons.
In shapefile, polygon can have many outer rings (clockwised) and many inner rings (CCWised).
In postgis, polygon can have only one outer ring (first) and many inner rings (CCWised).
So we may hade to split one source polygon into one or more members of a multipolygon.
To do so, we should 
--- separate outers from inners by sorting on CCW area ascending;
as a result, the list will begin with large outers, then small outers, then small inners, then large inners
--- Starting from largest inners, find the smallest outer that contains the inner.
--- Make a multipolygon.
 */
      geo_t *mpoly = NULL;
      geo_t **all_rings = res->_.parts.items;
      int all_rings_count = res->_.parts.len;
      int outer_rings_count = 0, inner_rings_count = 0, ctr, ctr2;
#define AUTO_POLY_LEN 16
      double ccw_areas_auto[AUTO_POLY_LEN];
      int orig_ring_ids_auto[AUTO_POLY_LEN];
      int counts_of_inners_in_outers_auto[AUTO_POLY_LEN];
      int envs_of_inners_auto[AUTO_POLY_LEN];
      double *ccw_areas = ccw_areas_auto; 
      int *orig_ring_ids = orig_ring_ids_auto;
      int *counts_of_inners_in_outers = counts_of_inners_in_outers_auto;
      int *envs_of_inners = envs_of_inners_auto;
      if (AUTO_POLY_LEN < all_rings_count)
        ccw_areas = (double *)dk_alloc (all_rings_count * sizeof (double));
      for (ctr = all_rings_count; ctr--; /* no step */)
        {
          geo_t *ring = all_rings[ctr];
          double a = ccw_areas[ctr] = geo_ccw_flat_area (ring);
#ifndef NDEBUG
          if (ctx->shpio_calc_bounding_flags & GEO_CALC_BOUNDING_TRANSITIVE)
            geo_calc_bounding (ring, ctx->shpio_calc_bounding_flags);
#endif
          geo_dbg_printf(("\n ring %d/%d, lat %lf--%lf, long %lf--%lf, is %s, ccw area %lf", ctr, all_rings_count,
            (double)(ring->XYbox.Xmin), (double)(ring->XYbox.Xmax),
            (double)(ring->XYbox.Ymin), (double)(ring->XYbox.Ymax),
            ((a <= 0) ? "OUTER" : "inner"), a ));
          if (a <= 0) /* outer */
            {
              outer_rings_count++;
              geo_inverse_point_order (ring);
            }
          else
            inner_rings_count++;
        }
      geo_calc_bounding (res, ctx->shpio_calc_bounding_flags);
      if ((1 == outer_rings_count) && (ccw_areas[0] <= 0))
        { /* The outer ring is alone and at the first place and inverted, so the whole polygon is OK. */
          if (AUTO_POLY_LEN < all_rings_count)
            dk_free (ccw_areas, all_rings_count * sizeof (double));
          return res;
        }
      if (0 == inner_rings_count)
        { /* No inner rings at all, so the result should be a MULTIPOLYGON with one ring per polygon, no sorting and no reallocations. */
          res->geo_flags = multi_flags;
          for (ctr = all_rings_count; ctr--; /* no step */)
            {
              geo_t *subpoly = geo_alloc (partlist_flags, 1, ctx->shpio_srcode);
              subpoly->_.parts.items[0] = all_rings[ctr];
              geo_calc_bounding (subpoly, 0);
              res->_.parts.items[ctr] = subpoly;
            }
          geo_calc_bounding (res, 0);
          if (AUTO_POLY_LEN < all_rings_count)
            dk_free (ccw_areas, all_rings_count * sizeof (double));
          return res;
        }
      if (0 == outer_rings_count)
        {
          err_ret[0] = srv_make_new_error ("22023", "SHP01", "The polygon (ShapeId %d) consists of inner rings only, no outer", obj->nShapeId);
          goto mpoly_done; /* see below */
        }
      if (AUTO_POLY_LEN < all_rings_count)
        {
          orig_ring_ids = (int *)dk_alloc (all_rings_count * sizeof (int));
          counts_of_inners_in_outers = (int *)dk_alloc (outer_rings_count * sizeof (int));
          envs_of_inners = (int *)dk_alloc (inner_rings_count * sizeof (int));
        }
      for (ctr = all_rings_count; ctr--; /* no step */)
        orig_ring_ids[ctr] = ctr;
      memset (counts_of_inners_in_outers, 0, outer_rings_count * sizeof (int));
      memset (envs_of_inners, 0, inner_rings_count * sizeof (int));
      /* Bubble sort */
      for (ctr2 = all_rings_count; --ctr2; /* no step */)
        for (ctr = all_rings_count; --ctr; /* no step */)
        {
          double a0 = ccw_areas[ctr-1], a1 = ccw_areas[ctr];
          if (a0 > a1)
            {
              int orig_id_swap;
              geo_t *swap = all_rings[ctr]; all_rings[ctr] = all_rings[ctr-1]; all_rings[ctr-1] = swap;
              orig_id_swap = orig_ring_ids[ctr]; orig_ring_ids[ctr] = orig_ring_ids[ctr-1]; orig_ring_ids[ctr-1] = orig_id_swap;
              ccw_areas[ctr] = a0; ccw_areas[ctr-1] = a1;
            }
        }
      for (ctr = all_rings_count; --ctr >= outer_rings_count; /* no step */)
        {
          geo_t *inner = all_rings[ctr];
          geo_t *outer;
          for (ctr2 = outer_rings_count; ctr2--; /* no step */)
            {
              int vertex_idx;
              outer = all_rings[ctr2];
              if (!geo_XYbbox_inside (&(inner->XYbox), &(outer->XYbox)))
                continue;
              /* There may be "fair" de9im_inside (inner, outer) here,
but it's overkill because any vertex strictly outside means "continue" and some vertex inside means "goto match_found" */
#if 0
              if (de9im_inside (inner, outer, NULL))
                goto match_found; /* see below */
#else
              for (vertex_idx = inner->_.pline.len - 1 /* last one is closing */; vertex_idx >= 0; vertex_idx--)
                {
                  int inoutside = geo_XY_inoutside_ring (inner->_.pline.Xs[vertex_idx], inner->_.pline.Ys[vertex_idx], outer);
                  if (inoutside & GEO_INOUTSIDE_CLOCKWISE) /* weird ring */
                    {
                      err_ret[0] = srv_make_new_error ("22023", "SHP03", "The ring #%d/%d of a polygon (ShapeId %d) should be \"couterclockwised\"", orig_ring_ids[ctr2] + 1, all_rings_count, obj->nShapeId);
                      goto mpoly_done; /* see below */
                    }
                  if (inoutside & GEO_INOUTSIDE_ERROR) /* weird ring */
                    {
                      err_ret[0] = srv_make_new_error ("22023", "SHP07", "The ring #%d/%d of a polygon (ShapeId %d) should not be self-intersecting", orig_ring_ids[ctr2] + 1, all_rings_count, obj->nShapeId);
                      goto mpoly_done; /* see below */
                    }
                  if (inoutside & GEO_INOUTSIDE_IN) /* The point is inside, so in case of proper nesting the whole ring is inside */
                    goto match_found; /* see below */
                  if (inoutside & GEO_INOUTSIDE_OUT) /* The point is outside so the ring is not inside outer */
                    break; /* see below */
                }
              /* If we're here then inner equal to outer (weird) or inner is actually ouside (more probable) */
#endif
            }
          err_ret[0] = srv_make_new_error ("22023", "SHP02", "The inner ring #%d/%d of a polygon (ShapeId %d) is not inside any of its outer rings", orig_ring_ids[ctr2] + 1, all_rings_count, obj->nShapeId);
          goto mpoly_done; /* see below */
match_found:
          envs_of_inners [ctr-outer_rings_count] = ctr2;
          counts_of_inners_in_outers[ctr2]++;
        }
      mpoly = geo_alloc (multi_flags, outer_rings_count, ctx->shpio_srcode);
      for (ctr2 = outer_rings_count; ctr2--; /* no step */)
        {
          geo_t *subpoly = geo_alloc (partlist_flags, 1 + counts_of_inners_in_outers[ctr2], ctx->shpio_srcode);
          subpoly->_.parts.items[0] = all_rings[ctr2];
          mpoly->_.parts.items[ctr2] = subpoly;
        }
      for (ctr = outer_rings_count; ctr < all_rings_count; ctr++)
        {
          int o_inx = envs_of_inners[ctr-outer_rings_count];
          geo_t *subpoly = mpoly->_.parts.items[o_inx];
          subpoly->_.parts.items[(counts_of_inners_in_outers[o_inx])--] = all_rings[ctr];
        }
      for (ctr2 = outer_rings_count; ctr2--; /* no step */)
        geo_calc_bounding (mpoly->_.parts.items[ctr2], 0);
      geo_calc_bounding (mpoly, 0);
      memset (all_rings, 0, all_rings_count * sizeof (geo_t *));

mpoly_done:
      if (AUTO_POLY_LEN < all_rings_count)
        {
          dk_free (ccw_areas, all_rings_count * sizeof (double));
          dk_free (orig_ring_ids, all_rings_count * sizeof (int));
          dk_free (counts_of_inners_in_outers, outer_rings_count * sizeof (int));
          dk_free (envs_of_inners, inner_rings_count * sizeof (int));
        }
      dk_free_box (res);
      return mpoly;
    }
  return res;
}

void
shapefileio_read_dbf_fld_mdata (shapefileio_ctx_t *ctx, int fldctr)
{
  int arg_dtp, arg_width, arg_prec;
  caddr_t *mdta;
  dbf_fld_t *df = ctx->shpio_dbf_fields + fldctr;
  df->df_fetch_type = DBFGetFieldInfo (ctx->shpio_dbfh, fldctr, df->df_name, &(df->df_width), &(df->df_decimals));
  df->df_native_type = DBFGetNativeFieldType (ctx->shpio_dbfh, fldctr);
  switch (df->df_native_type)
    {
    case 'C': arg_dtp = DV_STRING; arg_width = df->df_width; arg_prec = 0; break;
    case 'D': arg_dtp = DV_DATETIME; arg_width = df->df_width; arg_prec = 0; break;
    case 'F': arg_dtp = DV_DOUBLE_FLOAT; arg_width = df->df_width; arg_prec = 0; break;
    case 'N':
      if ((18 >= df->df_width) && (0 == df->df_decimals))
        { arg_dtp = DV_LONG_INT; arg_width = df->df_width; arg_prec = 0; }
      else if (9 >= df->df_width)
        { arg_dtp = DV_DOUBLE_FLOAT; arg_width = df->df_width; arg_prec = 0; }
      else
        { arg_dtp = DV_NUMERIC; arg_width = df->df_width; arg_prec = 0; }
      break;
    case 'L': arg_dtp = DV_LONG_INT; arg_width = 1; arg_prec = 0; break;
    case 'M': arg_dtp = DV_STRING; arg_width = -1; arg_prec = 0; break;
    default: arg_dtp = DV_STRING; arg_width = -1; arg_prec = 0; break;
    }
  df->df_dtp = arg_dtp;
  mdta = NEW_LIST (7);
  mdta[0] = box_dv_short_string (df->df_name);
  mdta[1] = arg_dtp;
  mdta[2] = arg_width;
  mdta[3] = arg_prec;
  mdta[4] = 1;
  mdta[5] = 0;
  mdta[6] = 0;
  ctx->shpio_dbf_cbk_mdata [fldctr] = mdta;
}

caddr_t
shapefileio_read_dbf_fld_value (shapefileio_ctx_t *ctx, int entity_id, int fldctr)
{
  dbf_fld_t *df;
  DBFHandle dbfh = ctx->shpio_dbfh;
  if (DBFIsAttributeNULL (dbfh, entity_id, fldctr))
    return NEW_DB_NULL;
  df = ctx->shpio_dbf_fields + fldctr;
  switch (df->df_native_type)
    {
    case 'C': return box_dv_short_string (DBFReadStringAttribute (dbfh, entity_id, fldctr));
    case 'D':
      {
        const char *strval = DBFReadStringAttribute (dbfh, entity_id, fldctr);
        return box_dv_short_string (strval); /*!!!TBD cast to date */
      }
    case 'F': return box_double (DBFReadDoubleAttribute (dbfh, entity_id, fldctr));
    case 'N':
      {
        switch (df->df_dtp)
          {
          case DV_LONG_INT: return box_num (DBFReadIntegerAttribute (dbfh, entity_id, fldctr));
          case DV_DOUBLE_FLOAT: return box_double (DBFReadDoubleAttribute (dbfh, entity_id, fldctr));
          case DV_NUMERIC:
            {
              const char *strval = DBFReadStringAttribute (dbfh, entity_id, fldctr);
              return box_dv_short_string (strval); /*!!!TBD cast to date */
            }
          default: GPF_T;
          }
      }
    case 'L': return box_num (DBFReadIntegerAttribute (dbfh, entity_id, fldctr)); /*!!!TBD label as bool */
    case 'M': /* no break */
    default:
      return box_dv_short_string (DBFReadStringAttribute (dbfh, entity_id, fldctr));
    }
}


void
shapefileio_read_one_shape (
  shapefileio_ctx_t *ctx,
  int entity_id,
  caddr_t *app_env,
  caddr_t *err_ret )
{
  SHPObject *obj = SHPReadObject (ctx->shpio_shph, entity_id);
  geo_t *geo_obj;
  caddr_t boxed_entity_id = NULL;
  caddr_t *boxed_attrs = NULL;
  caddr_t *params;
  switch (obj->nSHPType)
    {
    case SHPT_NULL:
      SHPDestroyObject (obj);
      if (ctx->shpio_flags & READ_ALL_SHAPES_SKIP_NULLS)
        return;
      /* !!! TBD: handle NULLs */
      return;
    case SHPT_POINT:
    case SHPT_POINTZ:
    case SHPT_POINTM:
      geo_obj = geo_construct_from_SHPObject_point (ctx, obj, err_ret);
      break;
    case SHPT_ARC:  case SHPT_POLYGON:  case SHPT_MULTIPOINT:
    case SHPT_ARCZ: case SHPT_POLYGONZ: case SHPT_MULTIPOINTZ:
    case SHPT_ARCM: case SHPT_POLYGONM: case SHPT_MULTIPOINTM:
      geo_obj = geo_construct_from_SHPObject (ctx, obj, err_ret);
      break;
    default:
      if (!(ctx->shpio_flags & READ_ALL_SHAPES_SKIP_UNSUPPORTED))
        {
          /* !!! TBD: handle unsupported, with NULL err */
          ;
        }
      SHPDestroyObject (obj);
      return;
    }
  if (NULL != err_ret[0])
    {
      if (ctx->shpio_flags & READ_ALL_SHAPES_SKIP_UNSUPPORTED)
        {
          SHPDestroyObject (obj);
          return;
        }
      SHPDestroyObject (obj);
      return;
    }
  if (NULL != ctx->shpio_dbfh)
    {
      int fldctr, fldcount = ctx->shpio_dbf_field_count;
      boxed_attrs = dk_alloc_box_zero (ctx->shpio_dbf_field_count * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
      for (fldctr = 0; fldctr < fldcount; fldctr++)
        boxed_attrs[fldctr] = shapefileio_read_dbf_fld_value (ctx, entity_id, fldctr);
    }
  boxed_entity_id = box_num (entity_id);
  params = NEW_LIST (5);
  params[0] = &boxed_entity_id;
  params[1] = &geo_obj;
  params[2] = &(ctx->shpio_dbf_cbk_mdata);
  params[3] = &boxed_attrs;
  params[4] = app_env;
  err_ret[0] = qr_exec (ctx->shpio_qi->qi_client, ctx->shpio_cbk_fn_plain, ctx->shpio_qi, NULL, NULL, NULL, params, NULL, 0);
  dk_free_box (boxed_entity_id);
  dk_free_box (geo_obj);
  dk_free_box (boxed_attrs);
  dk_free_box (params);
  SHPDestroyObject (obj);
}

caddr_t
shapefileio_read_all_shapes (caddr_t text_or_filename, int arg1_is_filename, caddr_t *ids_arg, int srid, long flags,
  ccaddr_t *cbk_names, caddr_t *app_env,
  struct query_instance_s *qi, const char *fname, caddr_t *err_ret )
{
  shapefileio_ctx_t ctx;
  int entities_count = 0, entity_ctr, shape_type;
  caddr_t err = NULL;
  memset (&ctx, 0, sizeof (shapefileio_ctx_t));
  ctx.shpio_qi = qi;
  ctx.shpio_srid = srid;
  ctx.shpio_srcode = GEO_SRCODE_OF_SRID(srid);
  ctx.shpio_flags = flags;
  ctx.shpio_calc_bounding_flags = GEO_CALC_BOUNDING_DO_ALL;
  ctx.shpio_cbk_name_mdata = cbk_names[0];
  ctx.shpio_cbk_name_plain = cbk_names[1];
  ctx.shpio_cbk_name_null = cbk_names[2];
  ctx.shpio_cbk_name_bad = cbk_names[3];
  ctx.shpio_cbk_fn_mdata = NULL;
  ctx.shpio_cbk_fn_plain = NULL;
  ctx.shpio_cbk_fn_null = NULL;
  ctx.shpio_cbk_fn_bad = NULL;
  sqlr_set_cbk_name_and_proc (qi->qi_client, ctx.shpio_cbk_name_mdata, "RRR", fname, NULL, &(ctx.shpio_cbk_fn_mdata), &err);
    if (NULL != err)
      goto fatal_err;
  sqlr_set_cbk_name_and_proc (qi->qi_client, ctx.shpio_cbk_name_plain, "RRRRR", fname, NULL, &(ctx.shpio_cbk_fn_plain), &err);
    if (NULL != err)
      goto fatal_err;
  sqlr_set_cbk_name_and_proc (qi->qi_client, ctx.shpio_cbk_name_null,  "RRRRR",  fname, NULL, &(ctx.shpio_cbk_fn_null),  &err);
  if (NULL != err)
    goto fatal_err;
  sqlr_set_cbk_name_and_proc (qi->qi_client, ctx.shpio_cbk_name_bad,   "RRRRR", fname, NULL, &(ctx.shpio_cbk_fn_bad),   &err);
  if (NULL != err)
    goto fatal_err;
  if (arg1_is_filename)
    {
      caddr_t raw_metas = NULL;
      caddr_t cbk_metas = NULL;
      ctx.shpio_shph = SHPOpen (text_or_filename, "rb");
      if (NULL == ctx.shpio_shph)
        {
          err = srv_make_new_error ("22023", "SHP08", "Unable to open shapefile '%.200s' for reading", text_or_filename);
          goto fatal_err;
        }
      SHPGetInfo (ctx.shpio_shph, &entities_count, &shape_type, NULL, NULL);
      ctx.shpio_dbfh = DBFOpen (text_or_filename, "rb");
      if (NULL != ctx.shpio_dbfh)
        {
          int fldctr, fldcount;
          ctx.shpio_dbf_field_count = fldcount = DBFGetFieldCount (ctx.shpio_dbfh);
          ctx.shpio_dbf_fields = (dbf_fld_t *)dk_alloc (fldcount * sizeof (dbf_fld_t));
          ctx.shpio_dbf_cbk_mdata = dk_alloc_box_zero (fldcount * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
          for (fldctr = 0; fldctr < fldcount; fldctr++)
            {
              shapefileio_read_dbf_fld_mdata (&ctx, fldctr);
            }
          if (NULL != ctx.shpio_cbk_fn_mdata)
            {
              caddr_t *params = NEW_LIST (3);
              params[0] = &raw_metas;
              params[1] = &(ctx.shpio_dbf_cbk_mdata);
              params[2] = app_env;
              err = qr_exec (ctx.shpio_qi->qi_client, ctx.shpio_cbk_fn_mdata, ctx.shpio_qi, NULL, NULL, NULL, params, NULL, 0);
              dk_free_box (params);
            }
        }
      else
        {
          caddr_t *params = NEW_LIST (3);
          params[0] = &raw_metas;
          params[1] = &cbk_metas;
          params[2] = app_env;
          err = qr_exec (ctx.shpio_qi->qi_client, ctx.shpio_cbk_fn_mdata, ctx.shpio_qi, NULL, NULL, NULL, params, NULL, 0);
          dk_free_box (params);
        }
      dk_free_box (raw_metas);
      dk_free_box (cbk_metas);
    }
  if (DV_ARRAY_OF_POINTER == DV_TYPE_OF (ids_arg))
    {
      int idctr, idcount = BOX_ELEMENTS (ids_arg);
      for (idctr = 0; idctr < idcount; idctr++)
        {
          caddr_t idbox = ids_arg[idctr];
          boxint entity_id;
          if (DV_LONG_INT != DV_TYPE_OF (idbox))
            continue;
          entity_id = unbox (idbox);
          if ((0 > entity_id) || (entity_id >= entities_count))
            continue;
          shapefileio_read_one_shape (&ctx, entity_id, app_env, &err);
          if (NULL != err)
            break;
        }
    }
  else
    {
      for (entity_ctr = 0; entity_ctr < entities_count; entity_ctr++)
        {
          shapefileio_read_one_shape (&ctx, entity_ctr, app_env, &err);
          if (NULL != err)
            break;
        }
    }
fatal_err:
  if (NULL != ctx.shpio_shph)
    SHPClose (ctx.shpio_shph);
  if (NULL != ctx.shpio_dbfh)
    DBFClose (ctx.shpio_dbfh);
  if (NULL != err)
    sqlr_resignal (err);
  return box_num (entities_count);
}

caddr_t
bif_shapefileio_read_all_shapes_local_file (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  static const char fname[] = "ShapefileIO read_all_shapes_local_file";
  caddr_t str;
  caddr_t *ids_arg;
  ccaddr_t *cbk_names;
  caddr_t *app_env;
  caddr_t res, err = NULL;
  int mode_bits = 0;
  /* int n_args = BOX_ELEMENTS (args); */
  str = bif_string_arg (qst, args, 0, fname);
  ids_arg = (caddr_t *)bif_arg (qst, args, 1, fname);
  mode_bits = bif_long_arg (qst, args, 2, fname);
  cbk_names = (ccaddr_t *)bif_strict_type_array_arg (DV_STRING, qst, args, 3, fname);
  bif_arg (qst, args, 4, fname);
  app_env = QST_GET_ADDR(qst, args[4]);
  if (4 != BOX_ELEMENTS (cbk_names))
    sqlr_new_error ("22023", "SHP06",
      "The argument #4 of %s() should be a vector of 4 names of stored procedures", fname );
  file_path_assert (str, NULL, 0);
  res = shapefileio_read_all_shapes (str, 1, ids_arg, SRID_DEFAULT, mode_bits, cbk_names, app_env,
    (struct query_instance_s *)qst, fname, &err );
  if (NULL != err)
    {
      dk_free_tree (res);
      sqlr_resignal (err);
    }
  return res;
}

caddr_t
bif_shapefileio_xy_inoutside_polygon (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  static const char fname[] = "ShapefileIO xy_inoutside_polygon";
  double pX = bif_double_arg (qst, args, 0, fname);
  double pY = bif_double_arg (qst, args, 1, fname);
  geo_t *g = bif_geo_arg (qst, args, 2, fname, GEO_ARG_ANY_NONNULL);
  int ctr, inoutside;
  if ((pX < g->XYbox.Xmin) || (pX > g->XYbox.Xmax) || (pY < g->XYbox.Ymin) || (pY > g->XYbox.Ymax))
    return box_num (GEO_INOUTSIDE_OUT);
  switch (GEO_TYPE_NO_ZM (g->geo_flags))
    {
    case GEO_RING:
      inoutside = geo_XY_inoutside_ring (pX, pY, g);
      if (GEO_INOUTSIDE_ERROR & inoutside) /* weird ring */
        sqlr_new_error ("22023", "SHP06", "The ring should be not self-intersecting");
      if (GEO_INOUTSIDE_CLOCKWISE & inoutside) /* weird ring */
        sqlr_new_error ("22023", "SHP06", "The ring should be \"couterclockwised\"");
      return box_num (inoutside);
    case GEO_POLYGON:
      {
        geo_t *ring = g->_.parts.items[0];
        if (GEO_RING != GEO_TYPE_NO_ZM (ring->geo_flags))
          return 0;
        inoutside = geo_XY_inoutside_ring (pX, pY, ring);
        if (GEO_INOUTSIDE_ERROR & inoutside) /* weird ring */
          sqlr_new_error ("22023", "SHP06", "The ring 0 of polygon should be not self-intersecting");
        if (GEO_INOUTSIDE_CLOCKWISE & inoutside) /* weird ring */
          sqlr_new_error ("22023", "SHP06", "The ring 0 of polygon  should be \"couterclockwised\"");
        if ((GEO_INOUTSIDE_OUT | GEO_INOUTSIDE_BORDER) & inoutside)
          return box_num (inoutside);
        for (ctr = g->_.parts.len; --ctr; /* no step */)
          {
            ring = g->_.parts.items[ctr];
            if (GEO_RING != GEO_TYPE_NO_ZM (ring->geo_flags))
              continue;
            inoutside = geo_XY_inoutside_ring (pX, pY, ring);
            if (GEO_INOUTSIDE_ERROR & inoutside) /* weird ring */
              sqlr_new_error ("22023", "SHP06", "The ring %d of polygon should be not self-intersecting", ctr);
            if (GEO_INOUTSIDE_CLOCKWISE & inoutside) /* weird ring */
              sqlr_new_error ("22023", "SHP06", "The ring %d of polygon  should be \"couterclockwised\"", ctr);
            if (GEO_INOUTSIDE_IN & inoutside)
              return box_num (GEO_INOUTSIDE_OUT);
            if (GEO_INOUTSIDE_BORDER & inoutside)
              return box_num (GEO_INOUTSIDE_BORDER);
          }
        return box_num (GEO_INOUTSIDE_IN);
      }
    case GEO_MULTI_POLYGON:
      for (ctr = 0; ctr < g->_.parts.len; ctr++)
        {
          geo_t *poly = g->_.parts.items[ctr];
          if (GEO_POLYGON != GEO_TYPE_NO_ZM (poly->geo_flags))
            continue;
          inoutside = geo_XY_inoutside_polygon (pX, pY, poly);
          if (GEO_INOUTSIDE_ERROR & inoutside) /* weird poly */
            sqlr_new_error ("22023", "SHP06", "The polygon %d of multipolygon should be not self-intersecting or wrong in some other way", ctr);
          if (GEO_INOUTSIDE_CLOCKWISE & inoutside) /* weird ring */
            sqlr_new_error ("22023", "SHP06", "The polygon %d of multipolygon should consist of \"couterclockwised\" rings", ctr);
          if ((GEO_INOUTSIDE_IN | GEO_INOUTSIDE_BORDER) & inoutside)
            return box_num (inoutside);
        }
      return box_num (GEO_INOUTSIDE_OUT);
    default:
      sqlr_new_error ("22023", "SHP06",
        "The argument #3 of %s() should be RING* or POLYGON*", fname );
    }
  return NULL; /* never reached */
}

#ifdef _USRDLL
caddr_t shapefileio_version_no = NULL;
void shapefileio_connect (void *appdata)
{
  shapefileio_version_no = box_dv_short_string (SHAPEFILEIO_VERSION);
  bif_define ("ShapefileIO read_all_shapes_local_file", bif_shapefileio_read_all_shapes_local_file);
  bif_define ("ShapefileIO xy_inoutside_polygon", bif_shapefileio_xy_inoutside_polygon);
}

static unit_version_t
shapefileio_version = {
  "ShapefileIO",			/*!< Title of unit, filled by unit */
  SHAPEFILEIO_VERSION,			/*!< Version number, filled by unit */
  "OpenLink Software",			/*!< Plugin's developer, filled by unit */
  "Shapefile support based on Frank Warmerdam's Shapelib",	/*!< Any additional info, filled by unit */
  0,					/*!< Error message, filled by unit loader */
  0,					/*!< Name of file with unit's code, filled by unit loader */
  shapefileio_connect,			/*!< Pointer to connection function, cannot be 0 */
  0,					/*!< Pointer to disconnection function, or 0 */
  0,					/*!< Pointer to activation function, or 0 */
  0,					/*!< Pointer to deactivation function, or 0 */
  &_gate
};

unit_version_t *
CALLBACK shapefileio_check (unit_version_t *in, void *appdata)
{
  return &shapefileio_version;
}
#endif

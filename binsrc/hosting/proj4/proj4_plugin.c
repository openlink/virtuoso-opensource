/*
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2019 OpenLink Software
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

#include <proj_api.h>
#include <stdio.h>
#include "sqlver.h"
#include "geo.h"
#include "import_gate_virtuoso.h"

#define PLUGIN_VERSION "1.0"

query_t *srid_to_proj4_string_qr = NULL;
id_hash_t *virt_proj4_sr_iri_to_srid = NULL;
id_hash_t *virt_proj4_sr_srid_to_iri = NULL;
id_hash_iterator_t *virt_proj4_sr_iri_to_srid_iter = NULL;
id_hash_iterator_t *virt_proj4_sr_srid_to_iri_iter = NULL;

void
virt_proj4_compile_statics (void)
{
  caddr_t err = NULL;
#define PRINT_ERR(err) \
  do { if (err) \
    { \
      log_error ("  Error compiling a Virtuoso Proj4 plugin init statement : %s: %s -- %s:%d", \
        ((caddr_t *) err)[QC_ERRNO], ((caddr_t *) err)[QC_ERROR_STRING], \
        __FILE__, __LINE__ ); \
      dk_free_tree (err); \
      err = NULL; \
    } } while (0)
  srid_to_proj4_string_qr = sql_compile_static (
  "select coalesce ("
     "(select SR_PROJ4_STRING from DB.DBA.SYS_PROJ4_SRIDS where SR_ID=:0 and SR_FAMILY='PG'), "
     "(select SR_PROJ4_STRING from DB.DBA.SYS_PROJ4_SRIDS where SR_ID=:0 and SR_FAMILY='EPSG'), "
     "(select SR_PROJ4_STRING from DB.DBA.SYS_PROJ4_SRIDS where SR_ID=:0 and SR_FAMILY='ESRI'), "
     "(select SR_PROJ4_STRING from DB.DBA.SYS_PROJ4_SRIDS where SR_ID=:0 and SR_FAMILY='NAD83'), "
     "(select SR_PROJ4_STRING from DB.DBA.SYS_PROJ4_SRIDS where SR_ID=:0 and SR_FAMILY='NAD27') ) ",
  get_bootstrap_cli(), &err, 0);
  PRINT_ERR(err);
}


id_hash_t *proj4_string_to_pj_htable = NULL;
id_hash_t *srid_to_pj_htable = NULL;

static projPJ
virt_proj4_find_pj_by_srid_or_string (caddr_t * qst, caddr_t *err_ret, int srid, caddr_t strg_or_null, const char *bifname, const char *argname)
{
  projPJ res_pj = NULL, *pj_hit;
  caddr_t err = NULL;
  local_cursor_t *lc;
  caddr_t boxed_srid, sys_strg;
  caddr_t *parms;
  if (NULL == srid_to_proj4_string_qr)
    virt_proj4_compile_statics ();
  if (NULL != strg_or_null)
    {
      rwlock_rdlock (proj4_string_to_pj_htable->ht_rwlock);
      pj_hit = (projPJ *)id_hash_get (proj4_string_to_pj_htable, (caddr_t)(&strg_or_null));
      if (NULL != pj_hit)
        {
          res_pj = pj_hit[0];
          rwlock_unlock (proj4_string_to_pj_htable->ht_rwlock);
          return res_pj;
        }
      else
        rwlock_unlock (proj4_string_to_pj_htable->ht_rwlock);
      res_pj = pj_init_plus (strg_or_null);
      if (NULL == res_pj)
        {
          err_ret[0] = srv_make_new_error ("22023", "PR400", "Invalid or unsupported %s projection string \"%.500s\" in %s()", argname, strg_or_null, bifname);
          return NULL;
        }
      rwlock_wrlock (proj4_string_to_pj_htable->ht_rwlock);
      if (NULL == (projPJ *)id_hash_get (proj4_string_to_pj_htable, (caddr_t)(&strg_or_null)))
        {
          strg_or_null = box_copy (strg_or_null);
          id_hash_set (proj4_string_to_pj_htable, (caddr_t)(&strg_or_null), (caddr_t)(&res_pj));
        }
      rwlock_unlock (proj4_string_to_pj_htable->ht_rwlock);
      return res_pj;
    }
  if (NULL == srid_to_proj4_string_qr)
    {
      err_ret[0] = srv_make_new_error ("22023", "PR402", "%s() can not access the dictionary of SRIDs, server should log errors at startup", bifname);
      return NULL;
    }
  rwlock_rdlock (srid_to_pj_htable->ht_rwlock);
  boxed_srid = box_num (srid);
  pj_hit = (projPJ *)id_hash_get (srid_to_pj_htable, (caddr_t)(&boxed_srid));
  if (NULL != pj_hit)
    {
      res_pj = pj_hit[0];
      rwlock_unlock (srid_to_pj_htable->ht_rwlock);
      dk_free_tree (boxed_srid);
      return res_pj;
    }
  else
    rwlock_unlock (srid_to_pj_htable->ht_rwlock);
  parms = dk_alloc_list (2);
  parms[0] = box_dv_uname_string (":0");
  parms[1] = boxed_srid;
  err = qr_exec (
    ((query_instance_t *)qst)->qi_client, srid_to_proj4_string_qr, CALLER_LOCAL, NULL, NULL, &lc, parms, NULL, 1);
  dk_free_box ((caddr_t)parms);
  if (NULL != err)
    {
      dk_free_tree (boxed_srid);
      err_ret[0] = err;
      return NULL;
    }
  if (lc_next (lc))
    sys_strg = box_copy_tree (lc_nth_col (lc, 0));
  else
    sys_strg = NULL;
  err = lc->lc_error;
  lc_free (lc);
  if (NULL != err)
    {
      err_ret[0] = err;
      dk_free_tree (sys_strg);
      dk_free_tree (boxed_srid);
      return NULL;
    }
  if (DV_STRING != DV_TYPE_OF (sys_strg))
    {
      err_ret[0] = srv_make_new_error ("22023", "PR403", "Table DB.DBA.SYS_V7PROJ_SRIDS contains no data about %s SRID %d in %s()", argname, srid, bifname);
      dk_free_tree (sys_strg);
      dk_free_tree (boxed_srid);
      return NULL;
    }
  res_pj = pj_init_plus (sys_strg);
  if (NULL == res_pj)
    {
      err_ret[0] = srv_make_new_error ("22023", "PR403", "Table DB.DBA.SYS_V7PROJ_SRIDS contains invalid or unsupported %s projection string \"%.500s\" for SRID %d in %s()", argname, sys_strg, srid, bifname);
      dk_free_tree (sys_strg);
      dk_free_tree (boxed_srid);
      return NULL;
    }
  dk_free_tree (sys_strg);
  rwlock_wrlock (srid_to_pj_htable->ht_rwlock);
  if (NULL == (projPJ *)id_hash_get (srid_to_pj_htable, (caddr_t)(&boxed_srid)))
    id_hash_set (srid_to_pj_htable, (caddr_t)(&boxed_srid), (caddr_t)(&res_pj));
  else
    dk_free_tree (boxed_srid);
  rwlock_unlock (srid_to_pj_htable->ht_rwlock);
  return res_pj;
}

/*! A clone of geo_set_srcode_trav() instead of export, to avoid an extra dereferencing in exe export gate */
void
virt_proj4_set_srcode_trav (geo_t *g, int srcode)
{
  g->geo_srcode = srcode;
  if (g->geo_flags & (GEO_A_COMPOUND | GEO_A_RINGS | GEO_A_MULTI | GEO_A_ARRAY))
    {
      int ctr, ct = g->_.parts.len;
      for (ctr = 0; ctr < ct; ctr++)
        virt_proj4_set_srcode_trav (g->_.parts.items[ctr], srcode);
    }
}

caddr_t
virt_proj4_geo_transform (projPJ orig_pj, projPJ dest_pj, geo_t *g, int orig_deg_to_rad, int dest_rad_to_deg, int orig_srcode, int dest_srcode)
{
  geo_flags_t flags = g->geo_flags;
  int proj_errcode;
/* local macro defs */
#define XY_PROJECT(x,y,z) do { \
  if (orig_deg_to_rad) { (x) *= DEG_TO_RAD; (y) *= DEG_TO_RAD; } \
  proj_errcode = pj_transform (orig_pj, dest_pj, 1, 1, &(x), &(y), ((flags & GEO_A_Z) ? &(z) : NULL)); \
  if (proj_errcode) goto ret_err; \
  if (dest_rad_to_deg) { (x) *= RAD_TO_DEG; (y) *= RAD_TO_DEG; } \
  } while (0)
#define XYBOX_PROJECT(xybox,zmbox) do { \
  geo_XYbox_t xmirr; \
  double vmin,vmax,v12,v34; \
  if (GEO_XYBOX_IS_EMPTY_OR_FARAWAY(xybox)) \
    return box_dv_short_string ("The shape is either empty or intentionally invalidated so it cannot be projected"); \
  if (orig_deg_to_rad) { xybox.Xmin *= DEG_TO_RAD; xybox.Xmax *= DEG_TO_RAD; xybox.Ymin *= DEG_TO_RAD; xybox.Ymax *= DEG_TO_RAD; } \
  xmirr.Xmin = xybox.Xmax; xmirr.Xmax = xybox.Xmin; xmirr.Ymin = xybox.Ymin; xmirr.Ymax = xybox.Ymax; \
  proj_errcode = pj_transform (orig_pj, dest_pj, 2, 1, &(xybox.Xmin), &(xybox.Ymin), ((flags & GEO_A_Z) ? &(zmbox.Zmin) : NULL)); \
  if (proj_errcode) goto ret_err; \
  proj_errcode = pj_transform (orig_pj, dest_pj, 2, 1, &(xmirr.Xmin), &(xmirr.Ymin), NULL); \
  if (proj_errcode) goto ret_err; \
  v12 = double_min (xybox.Xmin, xmirr.Xmin); v34 = double_min (xybox.Xmax, xmirr.Xmax); vmin = double_min (v12, v34); \
  v12 = double_max (xybox.Xmin, xmirr.Xmin); v34 = double_max (xybox.Xmax, xmirr.Xmax); vmax = double_max (v12, v34); \
  if (dest_rad_to_deg) { vmin *= RAD_TO_DEG; vmax *= RAD_TO_DEG; } \
  xybox.Xmin = vmin; xybox.Xmax = vmax; \
  v12 = double_min (xybox.Ymin, xmirr.Ymin); v34 = double_min (xybox.Ymax, xmirr.Ymax); vmin = double_min (v12, v34); \
  v12 = double_max (xybox.Ymin, xmirr.Ymin); v34 = double_max (xybox.Ymax, xmirr.Ymax); vmax = double_max (v12, v34); \
  if (dest_rad_to_deg) { vmin *= RAD_TO_DEG; vmax *= RAD_TO_DEG; } \
  xybox.Ymin = vmin; xybox.Ymax = vmax; \
  if ((flags & GEO_A_Z) && (zmbox.Zmin > zmbox.Zmax)) GEOC_SWAP(zmbox.Zmin, zmbox.Zmax); \
  } while (0)
  if (orig_srcode != g->geo_srcode)
    return box_dv_short_string ("The shape is in unexpected spatial reference system");
  g->geo_srcode = dest_srcode;
  if (flags & (GEO_A_RINGS | GEO_A_COMPOUND | GEO_A_MULTI | GEO_A_ARRAY))
    {
      int ctr;
      if (0 == g->_.parts.len)
        return NULL;
      for (ctr = g->_.parts.len; ctr--; /* no step */)
        virt_proj4_geo_transform (orig_pj, dest_pj, g->_.parts.items[ctr], orig_deg_to_rad, dest_rad_to_deg, orig_srcode, dest_srcode);
      geo_calc_bounding (g, 0);
      return NULL;
    }
  switch (GEO_TYPE_CORE (flags))
    {
    case GEO_NULL_SHAPE: case GEO_BOX:
      XYBOX_PROJECT(g->XYbox, g->_.point.point_ZMbox);
      return NULL;
    case GEO_POINT:
      if (GEO_XYBOX_IS_EMPTY_OR_FARAWAY(g->XYbox))
        return box_dv_short_string ("The point is intentionally invalidated so it cannot be projected");
      XY_PROJECT(g->XYbox.Xmin, g->XYbox.Ymin, g->_.point.point_ZMbox.Zmin);
      g->XYbox.Xmax = g->XYbox.Xmin; g->XYbox.Ymax = g->XYbox.Ymin;
      if (flags & GEO_A_Z) g->_.point.point_ZMbox.Zmax = g->_.point.point_ZMbox.Zmin;
      return NULL;
    case GEO_GSOP:
      return box_dv_short_string ("Spatial operator is not a true shape so it cannot be projected");
    case GEO_LINESTRING: case GEO_POINTLIST: case GEO_ARCSTRING:
      {
        int ctr;
        if (orig_deg_to_rad)
          {
            for (ctr = g->_.pline.len; ctr--; /* no step */)
              { g->_.pline.Xs[ctr] *= DEG_TO_RAD; g->_.pline.Ys[ctr] *= DEG_TO_RAD; }
          }
        proj_errcode = pj_transform (orig_pj, dest_pj, g->_.pline.len, 1, g->_.pline.Xs, g->_.pline.Ys, ((flags & GEO_A_Z) ? g->_.pline.Zs : NULL));
        if (proj_errcode) goto ret_err;
        if (dest_rad_to_deg)
          {
            for (ctr = g->_.pline.len; ctr--; /* no step */)
              { g->_.pline.Xs[ctr] *= RAD_TO_DEG; g->_.pline.Ys[ctr] *= RAD_TO_DEG; }
          }
        geo_calc_bounding (g, 0);
        return NULL;
      }
    default:
      return box_dv_short_string ("The geometry is either invalid or not supported by the loaded version of the proj4 plugin");
    }
  return NULL;
#undef XY_PROJECT
#undef XYBOX_PROJECT
ret_err:
  return box_dv_short_string (pj_strerrno (proj_errcode));
}


static caddr_t
bif_st_transform (caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  geo_t *orig = bif_geo_arg (qst,args, 0, "ST_Transform", GEO_ARG_ANY_NULLABLE);
  geo_t *dest;
  long dest_srid = bif_long_arg (qst, args, 1, "ST_Transform");
  int orig_srid;
  caddr_t proj4_orig_string = NULL;
  caddr_t proj4_dest_string = NULL;
  caddr_t err_msg = NULL, err_text;
  projPJ orig_pj, dest_pj;
  int orig_deg_to_rad, dest_rad_to_deg;
  if (2 < BOX_ELEMENTS (args))
    {
      proj4_orig_string = bif_string_or_null_arg (qst, args, 2, "ST_Transform");
      proj4_dest_string = bif_string_or_null_arg (qst, args, 3, "ST_Transform");
    }
  if (NULL == orig)
    return NEW_DB_NULL;
  orig_srid = GEO_SRID(orig->geo_srcode);
  if ((orig_srid == dest_srid) &&
    (((NULL == proj4_orig_string) && (NULL == proj4_dest_string)) ||
      ((NULL != proj4_orig_string) && (NULL != proj4_dest_string) && !strcmp (proj4_orig_string, proj4_dest_string)) ) )
    return box_copy ((caddr_t) orig);
  orig_pj = virt_proj4_find_pj_by_srid_or_string (qst, &err_msg, orig_srid, proj4_orig_string, "ST_Transform", "source");
  if (NULL != err_msg)
    sqlr_resignal (err_msg);
  dest_pj = virt_proj4_find_pj_by_srid_or_string (qst, &err_msg, dest_srid, proj4_dest_string, "ST_Transform", "destination");
  if (NULL != err_msg)
    {
      /*pj_free (orig_pj);*/
      sqlr_resignal (err_msg);
    }
  dest = geo_copy (orig);
  if (orig_pj == dest_pj)
    {
      /*pj_free (orig_pj);
      pj_free (dest_pj);*/
      if (GEO_SRCODE_OF_SRID (dest_srid) != orig->geo_srcode)
        virt_proj4_set_srcode_trav (dest, GEO_SRCODE_OF_SRID (dest_srid));
      return (caddr_t)dest;
    }
  orig_deg_to_rad = pj_is_latlong (orig_pj) || pj_is_geocent (orig_pj);
  dest_rad_to_deg = pj_is_latlong (dest_pj) || pj_is_geocent (dest_pj);
  err_text = virt_proj4_geo_transform (orig_pj, dest_pj, dest, orig_deg_to_rad, dest_rad_to_deg, orig->geo_srcode, GEO_SRCODE_OF_SRID (dest_srid));
  if (NULL != err_text)
    {
      err_msg = srv_make_new_error ("22023", "PR402", "Transformation error: %s", err_text);
      /*pj_free (orig_pj);
      pj_free (dest_pj);*/
      dk_free_tree ((caddr_t)dest);
      dk_free_box (err_text);
      sqlr_resignal (err_msg);
    }
  return (caddr_t)dest;
}

geo_t *
virt_proj4_srid_transform_cbk (caddr_t *qst, geo_t *orig, int dest_srid, caddr_t *err_ret)
{
  geo_t *dest;
  int orig_srid = GEO_SRID(orig->geo_srcode);
  projPJ orig_pj, dest_pj;
  caddr_t err_text;
  int orig_deg_to_rad, dest_rad_to_deg;
  if (orig_srid == dest_srid)
    return orig;
  err_ret[0] = NULL;
  orig_pj = virt_proj4_find_pj_by_srid_or_string (qst, err_ret, orig_srid, NULL, "implicit ST_Transform", "source");
  if (NULL != err_ret[0])
    return NULL;
  dest_pj = virt_proj4_find_pj_by_srid_or_string (qst, err_ret, dest_srid, NULL, "implicit ST_Transform", "destination");
  if (NULL != err_ret[0])
    return NULL;
  if (orig_pj == dest_pj)
    {
      if (GEO_SRCODE_OF_SRID (dest_srid) == orig->geo_srcode)
        return orig;
      dest = geo_copy (orig);
      virt_proj4_set_srcode_trav (dest, GEO_SRCODE_OF_SRID (dest_srid));
      return dest;
    }
  dest = geo_copy (orig);
  orig_deg_to_rad = pj_is_latlong (orig_pj) || pj_is_geocent (orig_pj);
  dest_rad_to_deg = pj_is_latlong (dest_pj) || pj_is_geocent (dest_pj);
  err_text = virt_proj4_geo_transform (orig_pj, dest_pj, dest, orig_deg_to_rad, dest_rad_to_deg, orig->geo_srcode, GEO_SRCODE_OF_SRID (dest_srid));
  if (NULL != err_text)
    {
      err_ret[0] = srv_make_new_error ("22023", "PR403", "Transformation error: %s", err_text);
      dk_free_tree ((caddr_t)dest);
      dk_free_box (err_text);
      return NULL;
    }
  return dest;
}

static caddr_t
bif_proj4_cache_reset (caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  caddr_t *key_ptr;
  projPJ *pj_ptr;
  id_hash_iterator_t it;
  dk_set_t all_pjs = NULL;
  rwlock_wrlock (proj4_string_to_pj_htable->ht_rwlock);
  id_hash_iterator (&it, proj4_string_to_pj_htable);
  while (hit_next (&it, (char**)(&key_ptr), (char**)(&pj_ptr)))
    {
      dk_free_tree (key_ptr[0]);
      dk_set_pushnew (&all_pjs, pj_ptr[0]);
    }
  id_hash_clear (proj4_string_to_pj_htable);
  rwlock_unlock (proj4_string_to_pj_htable->ht_rwlock);
  rwlock_wrlock (srid_to_pj_htable->ht_rwlock);
  id_hash_iterator (&it, srid_to_pj_htable);
  while (hit_next (&it, (char**)(&key_ptr), (char**)(&pj_ptr)))
    {
      dk_free_tree (key_ptr[0]);
      dk_set_pushnew (&all_pjs, pj_ptr[0]);
    }
  id_hash_clear (srid_to_pj_htable);
  while (NULL != all_pjs) pj_free (dk_set_pop (&all_pjs));
  rwlock_unlock (srid_to_pj_htable->ht_rwlock);
  return NULL;
}

static caddr_t
bif_postgis_proj_version (caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  return box_dv_short_string (pj_get_release());
}

static caddr_t
bif_proj4_get_sr_iri_to_srid_dict (caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  sec_check_dba ((query_instance_t *)qst, "Proj4 get_sr_iri_to_srid_dict");
  if (NULL == virt_proj4_sr_iri_to_srid_iter)
    {
      virt_proj4_sr_iri_to_srid = (id_hash_t *)box_dv_dict_hashtable (5000);
      virt_proj4_sr_iri_to_srid->ht_dict_refctr++;
      virt_proj4_sr_iri_to_srid->ht_rwlock = rwlock_allocate ();
      virt_proj4_sr_iri_to_srid_iter = (id_hash_iterator_t *)box_dv_dict_iterator ((caddr_t)virt_proj4_sr_iri_to_srid);
      get_sr_iri_to_srid_iter()[0] = virt_proj4_sr_iri_to_srid_iter;
    }
  return box_copy ((caddr_t)virt_proj4_sr_iri_to_srid_iter);
}

static caddr_t
bif_proj4_get_sr_srid_to_iri_dict (caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  sec_check_dba ((query_instance_t *)qst, "Proj4 get_sr_srid_to_iri_dict");
  if (NULL == virt_proj4_sr_srid_to_iri_iter)
    {
      virt_proj4_sr_srid_to_iri = (id_hash_t *)box_dv_dict_hashtable (5000);
      virt_proj4_sr_srid_to_iri->ht_dict_refctr++;
      virt_proj4_sr_srid_to_iri->ht_rwlock = rwlock_allocate ();
      virt_proj4_sr_srid_to_iri_iter = (id_hash_iterator_t *)box_dv_dict_iterator ((caddr_t)virt_proj4_sr_srid_to_iri);
      get_sr_srid_to_iri_iter()[0] = virt_proj4_sr_srid_to_iri_iter;
    }
  return box_copy ((caddr_t)virt_proj4_sr_srid_to_iri_iter);
}

extern void sqls_define_proj4 (void);
extern void sqls_arfw_define_proj4 (void);

void
virt_proj4_pre_log_action (char *mode)
{
  bif_define_ex ("ST_Transform", bif_st_transform, BMD_ALIAS, "st_transform", BMD_ALIAS, "Proj4 ST_Transform", BMD_IS_PURE, BMD_USES_INDEX, BMD_DONE);
  /* bif_define_ex ("Proj4 find_string_by_srid", bif_proj4_find_string_by_srid, BMD_DONE); */
  bif_define_ex ("Proj4 cache_reset", bif_proj4_cache_reset, BMD_DONE);
  bif_define_ex ("postgis_proj_version", bif_postgis_proj_version, BMD_ALIAS, "Proj4 version", BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("Proj4 get_sr_iri_to_srid_dict", bif_proj4_get_sr_iri_to_srid_dict, BMD_DONE);
  bif_define_ex ("Proj4 get_sr_srid_to_iri_dict", bif_proj4_get_sr_srid_to_iri_dict, BMD_DONE);
}

void
virt_proj4_postponed_action (char *mode)
{
  sqls_define_proj4 ();
  sqls_arfw_define_proj4 ();
  virt_proj4_compile_statics ();
}

static void
virt_proj4_plugin_connect ()
{
  proj4_string_to_pj_htable = (id_hash_t *)box_dv_dict_hashtable (31);
  proj4_string_to_pj_htable->ht_rehash_threshold = 120;
  proj4_string_to_pj_htable->ht_hash_func = strhash;
  proj4_string_to_pj_htable->ht_cmp = strhashcmp;
  proj4_string_to_pj_htable->ht_rwlock = rwlock_allocate ();
  srid_to_pj_htable = (id_hash_t *)box_dv_dict_hashtable (31);
  srid_to_pj_htable->ht_rehash_threshold = 120;
  srid_to_pj_htable->ht_rwlock = rwlock_allocate ();
  dk_set_push (get_srv_global_init_pre_log_actions_ptr(), virt_proj4_pre_log_action);
  dk_set_push (get_srv_global_init_postponed_actions_ptr(), virt_proj4_postponed_action);
  geo_set_default_srid_transform_cbk (virt_proj4_srid_transform_cbk);
  geo_set_default_pj_by_srid_or_string_cbk (virt_proj4_find_pj_by_srid_or_string);
  geo_set_default_pj_yn_cbks (pj_is_latlong, pj_is_geocent);
}

static unit_version_t virt_proj4_version = {
  PLAIN_PLUGIN_TYPE,		/*!< Title of unit, filled by unit */
  PLUGIN_VERSION "." DBMS_SRV_GEN_MAJOR DBMS_SRV_GEN_MINOR,	/*!< Version number, filled by unit */
  "OpenLink Software",		/*!< Plugin's developer, filled by unit */
  "Cartographic Projections support based on Frank Warmerdam's proj4 library",	/*!< Any additional info, filled by unit */
  0,				/*!< Error message, filled by unit loader */
  0,				/*!< Name of file with unit's code, filled by unit loader */
  virt_proj4_plugin_connect,	/*!< Pointer to connection function, cannot be 0 */
  0,				/*!< Pointer to disconnection function, or 0 */
  0,				/*!< Pointer to activation function, or 0 */
  0,				/*!< Pointer to deactivation function, or 0 */
  &_gate
};


unit_version_t *CALLBACK
proj4_check (unit_version_t * in, void *appdata)
{
  return &virt_proj4_version;
}

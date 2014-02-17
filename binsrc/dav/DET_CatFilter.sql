--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2014 OpenLink Software
--
--  This project is free software; you can redistribute it and/or modify it
--  under the terms of the GNU General Public License as published by the
--  Free Software Foundation; only version 2 of the License, dated June 1991.
--
--  This program is distributed in the hope that it will be useful, but
--  WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
--  General Public License for more details.
--
--  You should have received a copy of the GNU General Public License along
--  with this program; if not, write to the Free Software Foundation, Inc.,
--  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
--

use DB
;

-- CatFilter ID structure:
-- for categories:
-- vector (UNAME'CatFilter', detcol_id, null, schema_uri, vector (prop1uri, prop1catid, prop1decodedcatvalue, prop1crop, ..., propNuri, propNcatid, propNdecodedcatvalue, propNcrop))
-- for resources:
-- vector (UNAME'CatFilter', detcol_id, original_resource_id, schema_uri, vector (prop1uri, prop1catid, prop1decodedcatvalue, prop1crop, ..., propNuri, propNcatid, propNdecodedcatvalue, propNcrop))

create function "CatFilter_DAV_AUTHENTICATE" (in id any, in what char(1), in req varchar, in auth_uname varchar, in auth_pwd varchar, in auth_uid integer)
{
  declare cfc_id integer;
  declare rfc_spath, tmp_perms varchar;
  declare rfc_list_cond, rfc_del_action any;
  declare rc, spath_id, n integer;
  -- dbg_obj_princ ('CatFilter_DAV_AUTHENTICATE (', id, what, req, auth_uname, auth_pwd, auth_uid, ')');
  rfc_spath := null;
  if (DAV_HIDE_ERROR ("CatFilter_GET_CONDITION" (id[1], cfc_id, rfc_spath, rfc_list_cond, rfc_del_action)) is null)
    return -1;
  if (not ('110' like req))
    return -13; -- Internals of ResFilter are not executable.
  spath_id := DAV_SEARCH_ID (rfc_spath, 'C');
  if (not isinteger (spath_id))
    return -13;
  if (DAV_HIDE_ERROR (spath_id) is null)
    return spath_id;
  rc := DAV_AUTHENTICATE (spath_id, 'C', req, auth_uname, auth_pwd, auth_uid);
  if (DAV_HIDE_ERROR (rc) is null)
    return rc;
  if ('C' = what)
    {
      n := length (id[4]);
      if ((n=0) or (mod (n, 4) = 2))
        tmp_perms := '100';
      else if (length (rfc_del_action) < length (rfc_list_cond))
        {
          -- dbg_obj_princ ('del_action = ', rfc_del_action, 'rfc_list_cond = ', rfc_list_cond);
          tmp_perms := '100';
        }
      else
        tmp_perms := '110';
      if (not (tmp_perms like req))
        return -13;
      return auth_uid;
    }
  else if ('R' = what)
    {
      return DAV_AUTHENTICATE (id [2], 'R', req, auth_uname, auth_pwd, auth_uid);
    }
  return -14;
}
;


create function "CatFilter_GET_CONDITION" (in detcol_id integer, out cfc_id integer, out rfc_spath varchar, out rfc_list_cond any, out rfc_del_action any)
{
  -- dbg_obj_princ ('CatFilter_GET_CONDITION (', detcol_id, '...)');
  whenever not found goto nf;
  if (isarray (detcol_id))
    return -20;
  select cast ("ResFilter_NORM" (PROP_VALUE) as integer) into cfc_id from WS.WS.SYS_DAV_PROP where PROP_NAME = 'virt:CatFilter-ID' and PROP_PARENT_ID = detcol_id and PROP_TYPE = 'C';
  select "ResFilter_NORM" (PROP_VALUE) into rfc_spath from WS.WS.SYS_DAV_PROP where PROP_NAME = 'virt:ResFilter-SearchPath' and PROP_PARENT_ID = detcol_id and PROP_TYPE = 'C';
  select "ResFilter_DECODE_FILTER" (PROP_VALUE) into rfc_list_cond from WS.WS.SYS_DAV_PROP where PROP_NAME = 'virt:ResFilter-ListCond' and PROP_PARENT_ID = detcol_id and PROP_TYPE = 'C';
  select "ResFilter_DECODE_FILTER" (PROP_VALUE) into rfc_del_action from WS.WS.SYS_DAV_PROP where PROP_NAME = 'virt:ResFilter-DelAction' and PROP_PARENT_ID = detcol_id and PROP_TYPE = 'C';
  return 0;
nf:
  return -1;
}
;


create function "CatFilter_ENCODE_CATVALUE" (in val varchar) returns varchar
{
  declare ses any;
  declare ctr, len integer;
  declare lastspace integer;
  if (val is null)
    return '! property is not set !';
  if (__tag (val) = 230)
    val := cast (val as varchar);
  ses := string_output ();
  len := length (val);
  if (len > 70)
    {
      val := subseq (val, 0, 65);
      lastspace := strrchr (val, ' ');
      if (lastspace is not null)
        val := subseq (val, 0, lastspace) || ' . . .';
      else
        val := val || '...';
    }
  if (len = 0)
    return '! empty property value !';
  len := length (val);
  for (ctr := 0; ctr < len; ctr := ctr + 1)
    {
      declare ch integer;
      ch := val [ctr];
      if ((ch < 32) or (ch = 47) or (ch = 92) or (ch = 37) or (ch = 58) or ((ch = 40) and (ctr = 0)))
        http (sprintf ('^%02x', ch), ses);
      else
        http (chr (ch), ses);
    }
  return string_output_string (ses);
}
;


create function "CatFilter_DECODE_CATVALUE" (in catval varchar, out crop integer)
{
  declare val varchar;
  declare catvallen integer;
  if ('! empty property value !' = catval)
    {
      crop := 0;
      return '';
    }
  if ('! property is not set !' = catval)
    {
      crop := 4;
      return null;
    }
  catvallen := length (catval);
  if ((catvallen >= 6) and (subseq (catval, catvallen - 6) = ' . . .'))
    {
      crop := 1;
      catvallen := catvallen - 6;
      catval := subseq (catval, 0, catvallen);
    }
  else
  if ((catvallen >= 3) and (subseq (catval, catvallen - 3) = '...'))
    {
      crop := 2;
      catvallen := catvallen - 3;
      catval := subseq (catval, 0, catvallen);
    }
  else
    crop := 0;
  val := split_and_decode (catval, 0, '^');
  return val;
}
;


create function "CatFilter_PATH_PARTS_TO_FILTER" (inout path_parts any, out schema_uri varchar, out filter_data any) returns integer
{
  declare prop_catnames varchar;
  declare pathctr, filtctr, pathlen integer;
  declare filt any;
  pathlen := length (path_parts) - 1;
  if (0 >= pathlen)
    {
      schema_uri := null;
      filter_data := null;
      return 0;
    }
-- First of all, schema should be located.

retry_after_recomp:
  whenever not found goto no_schema;
  select RS_URI, deserialize (blob_to_string(RS_PROP_CATNAMES)) into schema_uri, prop_catnames from WS.WS.SYS_RDF_SCHEMAS where RS_CATNAME = path_parts[0] and RS_PROP_CATNAMES is not null;
  filt := make_array (2 * (pathlen - 1), 'any');
  filtctr := 0;
  for (pathctr := 1; pathctr < pathlen; pathctr := pathctr + 2)
    {
      declare pos integer;
      pos := position (path_parts [pathctr], prop_catnames, 2, 6);
      if (0 = pos)
        {
          -- dbg_obj_princ ('CatFilter_PATH_PARTS_TO_FILTER (', path_parts, '...) failed to find catlabel ', path_parts [pathctr], ' in schema ', schema_uri);
          return -2;
        }
      filt [filtctr] := prop_catnames [pos - 2]; -- prop URI
      filt [filtctr + 1] := prop_catnames [pos]; -- prop catid
      if (pathctr < (pathlen - 1))
        {
          declare crop_mode integer;
          filt [filtctr + 2] := "CatFilter_DECODE_CATVALUE" (path_parts [pathctr + 1], crop_mode);
          filt [filtctr + 3] := crop_mode;
        }
      filtctr := filtctr + 4;
    }
  filter_data := filt;
  return 0;

no_schema:
  -- dbg_obj_princ ('CatFilter_PATH_PARTS_TO_FILTER (', path_parts, '...) failed to find schema with catlabel ', path_parts [0]);
  if (exists (select top 1 1 from WS.WS.SYS_RDF_SCHEMAS where RS_CATNAME = path_parts[0] and RS_PROP_CATNAMES is null))
    {
      DAV_GET_RDF_SCHEMA_N3 ((select RS_URI from WS.WS.SYS_RDF_SCHEMAS where RS_CATNAME = path_parts[0]));
      goto retry_after_recomp;
    }

  return -1;
}
;


create procedure "CatFilter_ACC_FILTER_DATA" (inout filter any, inout filter_data any)
{
  declare ctr, len integer;
  len := length (filter_data);
  len := len - mod (len, 4);
  for (ctr := 0; ctr < len; ctr := ctr + 4)
    {
      declare crop_mode integer;
      declare pred any;
      crop_mode := filter_data [ctr + 3];
      if (crop_mode = 0)
        pred := vector ('RDF_VALUE', '=', filter_data [ctr + 2], 'http://local.virt/DAV-RDF', filter_data [ctr]);
      else
      if (crop_mode = 4)
        pred := vector ('RDF_VALUE', 'is_null', 'http://local.virt/DAV-RDF', filter_data [ctr]);
      else
        pred := vector ('RDF_VALUE', 'starts_with', filter_data [ctr + 2], 'http://local.virt/DAV-RDF', filter_data [ctr]);
      vectorbld_acc (filter, pred);
    }
}
;


create function "CatFilter_DAV_SEARCH_ID_IMPL" (in detcol_id any, in path_parts any, in what char(1), inout cfc_id integer, inout rfc_spath varchar, inout rfc_list_cond any, inout rfc_del_action any, inout filter_data any) returns any
{
  declare schema_catname, schema_uri, res_name, colpath, orig_fnameext varchar;
  declare prop_catnames, filter, orig_id any;
  declare path_len, len, ctr integer;
  declare execstate, execmessage varchar;
  declare execmeta, execrows any;
  declare qry_text varchar;
  -- dbg_obj_princ ('CatFilter_DAV_SEARCH_ID_IMPL (', detcol_id, path_parts, what, ')');
  path_len := length (path_parts);
  if (not (isstring (rfc_spath)))
    {
      if (0 > "CatFilter_GET_CONDITION" (detcol_id, cfc_id, rfc_spath, rfc_list_cond, rfc_del_action))
	{
	  -- dbg_obj_princ ('broken filter - no items');
	  return -1;
	}
    }
  if (0 = path_len)
    return -1;
  res_name := path_parts [path_len - 1];
  if ('' = res_name)
    {
      if ('R' = what)
        {
          -- dbg_obj_princ ('resource with trailing slash - no items');
          return -1;
        }
    }
  else
    {
      if ('C' = what)
        {
          -- dbg_obj_princ ('collection without a trailing slash - no items');
          return -1;
        }
      if (1 = path_len)
        {
          -- dbg_obj_princ ('resource with path length = 1 - no items at depth of schemas');
          return -1;
        }
      if (2 = path_len)
        {
          -- dbg_obj_princ ('resource with path length = 2 - no items at depth of first property name under schemas');
          return -1;
        }
      if (1 = mod (path_len, 2))
        {
          -- dbg_obj_princ ('resource with even path length - no items at depth of distinct values');
          return -1;
        }
    }
  if (0 > "CatFilter_PATH_PARTS_TO_FILTER" (path_parts, schema_uri, filter_data))
    {
      -- dbg_obj_princ ('failed to convert path parts to filter - no items');
      return -1;
    }
  if ('C' = what)
    return vector (UNAME'CatFilter', detcol_id, null, schema_uri, case (length (filter_data)) when 0 then null else filter_data end);
  "ResFilter_FNSPLIT" (res_name, colpath, orig_fnameext, orig_id);

  -- dbg_obj_princ ('CatFilter_DAV_SEARCH_ID_IMPL: ', path_parts, colpath, orig_fnameext, orig_id, rfc_spath, rfc_list_cond, filter_data);

  if (isarray (orig_id)) -- TODO: remove this and make better processing to return -1 if path contains criteria that filter out orig_id
    return orig_id;
  len := length (filter_data);
  vectorbld_init (filter);
  "CatFilter_ACC_FILTER_DATA" (filter, filter_data);
  vectorbld_concat_acc (filter, get_keyword ('', rfc_list_cond));
  if (orig_id is not null)
    {
      if (isinteger (orig_id))
        vectorbld_acc (filter, vector ('RES_ID', '=', orig_id));
      else -- never happens for a while
        vectorbld_acc (filter, vector ('RES_ID_SERIALIZED', '=', serialize (orig_id)));
    }
  vectorbld_final (filter);

  qry_text := '
    select top 2 RES_ID
    from WS.WS.SYS_DAV_RES as _top ' || DAV_FC_PRINT_WHERE (filter, coalesce ((select COL_OWNER from WS.WS.SYS_DAV_COL where COL_ID = detcol_id), -1)) || ' and (_top.RES_NAME = ?) and (_top.RES_FULL_PATH between ? and ?)';
  -- dbg_obj_princ ('about to exec:\n', qry_text, '\nrfc_spath = ', rfc_spath);
  exec (qry_text,
    execstate, execmessage, vector (orig_fnameext, rfc_spath, DAV_COL_PATH_BOUNDARY (rfc_spath)), 100000000, execmeta, execrows );
  len := length (execrows);
  if (len <> 1)
    return -1;
  return vector (UNAME'CatFilter', detcol_id, execrows[0][0], schema_uri, case (length (filter_data)) when 0 then null else filter_data end);
}
;


create function "CatFilter_DAV_AUTHENTICATE_HTTP" (in id any, in what char(1), in req varchar, in can_write_http integer, inout a_lines any, inout a_uname varchar, inout a_pwd varchar, inout a_uid integer, inout a_gid integer, inout _perms varchar) returns integer
{
  declare cfc_id integer;
  declare rfc_spath, tmp_perms varchar;
  declare rfc_list_cond, rfc_del_action any;
  declare rc, spath_id, n integer;
  -- dbg_obj_princ ('"CatFilter_DAV_AUTHENTICATE_HTTP" (', id, what, req, can_write_http, a_lines, a_uname, a_pwd, a_uid, a_gid, _perms, ')');
  rfc_spath := null;
  rc := DAV_HIDE_ERROR ("CatFilter_GET_CONDITION" (id[1], cfc_id, rfc_spath, rfc_list_cond, rfc_del_action));
  if (DAV_HIDE_ERROR (rc) is null)
    {
      -- dbg_obj_princ ('"CatFilter_DAV_AUTHENTICATE_HTTP" failed at CatFilter_GET_CONDITION, ', rc);
      return rc;
    }
  if (not ('110' like req))
    return -13; -- Internals of ResFilter/CatFilter are not executable.
  spath_id := DAV_SEARCH_ID (rfc_spath, 'C');
  -- dbg_obj_princ ('rfc_spath = ', rfc_spath, ', spath_id = ', spath_id);
  if (not isinteger (spath_id))
    return -13;
  if (DAV_HIDE_ERROR (spath_id) is null)
    return spath_id;
  rc := DAV_AUTHENTICATE_HTTP (spath_id, 'C', req, can_write_http, a_lines, a_uname, a_pwd, a_uid, a_gid, _perms);
  if (DAV_HIDE_ERROR (rc) is null)
    {
      return rc;
    }
  if ('C' = what)
    {
      n := length (id[4]);
      if ((n=0) or (mod (n, 4) = 2))
        tmp_perms := '100';
      else if (length (rfc_del_action) < length (rfc_list_cond))
        {
          -- dbg_obj_princ ('del_action = ', rfc_del_action, 'rfc_list_cond = ', rfc_list_cond);
          tmp_perms := '100';
        }
      else
        tmp_perms := '110';
      if (not (tmp_perms like req))
        return -13;
      return a_uid;
    }
  else if ('R' = what)
    {
      return DAV_AUTHENTICATE_HTTP (id[2], 'R', req, can_write_http, a_lines, a_uname, a_pwd, a_uid, a_gid, _perms);
    }
  return -14;
}
;


create function "CatFilter_DAV_GET_PARENT" (in id any, in st char(1), in path varchar) returns any
{
  -- dbg_obj_princ ('CatFilter_DAV_GET_PARENT (', id, st, path, ')');
  if (st = 'R')
    {
      id [2] := null;
      return id;
    }
  else if (st = 'C')
    {
      declare vlen integer;
      vlen := length (id[4]);
      if (vlen = 0)
        return id [1];
      id [4] := subseq (id [4], 0, vlen - 1);
      return id;
    }
  return -20;
}
;


create function "CatFilter_DAV_COL_CREATE" (in detcol_id any, in path_parts any, in permissions varchar, in uid integer, in gid integer, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('CatFilter_DAV_COL_CREATE (', detcol_id, path_parts, permissions, uid, gid, auth_uid, ')');
  return -20;
}
;


create function "CatFilter_DAV_COL_MOUNT" (in detcol_id any, in path_parts any, in full_mount_path varchar, in mount_det varchar, in permissions varchar, in uid integer, in gid integer, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('CatFilter_DAV_COL_MOUNT (', detcol_id, path_parts, full_mount_path, mount_det, permissions, uid, gid, auth_uid, ')');
  return -20;
}
;


create function "CatFilter_DAV_COL_MOUNT_HERE" (in parent_id any, in full_mount_path varchar, in permissions varchar, in uid integer, in gid integer, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('CatFilter_DAV_COL_MOUNT (', parent_id, full_mount_path, permissions, uid, gid, auth_uid, ')');
  return -20;
}
;


create function "CatFilter_DAV_DELETE" (in detcol_id any, in path_parts any, in what char(1), in silent integer, in auth_uid integer) returns integer
{
  declare rc integer;
  declare cfc_id integer;
  declare rfc_spath, propname varchar;
  declare rfc_list_cond, rfc_del_action any;
  declare orig_id, filter_data, whole_rdf, vals, new_rdf any;
  -- dbg_obj_princ ('CatFilter_DAV_DELETE (', detcol_id, path_parts, what, silent, auth_uid, ')');
  rfc_spath := null;
  orig_id := "CatFilter_DAV_SEARCH_ID_IMPL" (detcol_id, path_parts, what, cfc_id, rfc_spath, rfc_list_cond, rfc_del_action, filter_data);
  if (DAV_HIDE_ERROR (orig_id) is null)
    return orig_id;
  if (length (rfc_del_action) < length (rfc_list_cond))
    {
      -- dbg_obj_princ ('del_action = ', rfc_del_action, 'rfc_list_cond = ', rfc_list_cond);
      return -13;
    }
  if ('R' <> what)
    return -20;
  whole_rdf := coalesce ((select PROP_VALUE from WS.WS.SYS_DAV_PROP where PROP_NAME = 'http://local.virt/DAV-RDF' and PROP_TYPE = 'R' and PROP_PARENT_ID = orig_id [2]));
  if (whole_rdf is null)
    return -1;
  if (not isstring (whole_rdf))
    whole_rdf := blob_to_string (whole_rdf);
  whole_rdf := xml_tree_doc (deserialize (whole_rdf));
  propname := filter_data [length (filter_data) - 4];
  -- dbg_obj_princ ('rdf is ', whole_rdf);
  vals := xpath_eval (
      '[xmlns:virt="virt"] /virt:rdf/virt:top-res/virt:prop[*[1][name(.) = \044propname]][virt:value]',
      whole_rdf, 0, vector ('propname', filter_data [length (filter_data) - 4]) );
  -- dbg_obj_princ ('vals=', vals);
  foreach (any val in vals) do
    {
      declare cval, decenc_val varchar;
      declare crop integer;
      cval := cast (xpath_eval ('[xmlns:virt="virt"] string (virt:value)', val, 1) as varchar);
      decenc_val := "CatFilter_DECODE_CATVALUE" ("CatFilter_ENCODE_CATVALUE" (cval), crop);
      -- dbg_obj_princ ('Found value ', val, ' of ', propname, 'decenc=', decenc_val);
      if (decenc_val = filter_data [length (filter_data) - 2])
        {
          -- dbg_obj_princ ('matches');
          XMLReplace (whole_rdf, val, null);
        }
    }
  new_rdf := xte_node (xte_head (UNAME' root'), whole_rdf);
  update WS.WS.SYS_DAV_PROP set prop_value = serialize (new_rdf) where PROP_NAME = 'http://local.virt/DAV-RDF' and PROP_TYPE = 'R' and PROP_PARENT_ID = orig_id [2];
  return 0;
}
;


create function "CatFilter_FILTER_TO_CONDITION" (inout schema_uri varchar, inout filter_data any, inout cond any) returns integer
{
  declare ctr, len integer;
  if (schema_uri is null)
    return -13;
  len := length (filter_data);
  if ((len = 0) or (0 <> mod (len, 4)))
    return -13;
  vectorbld_init (cond);
  for (ctr := 0; ctr < len; ctr := ctr + 4)
    {
      declare sample varchar;
      declare crop integer;
      crop := filter_data [ctr + 3];
--TBD proper support of crop 1,2,4
      if (2 = crop)
        return -13;
      sample := filter_data [ctr + 2];
      if (1 = crop)
        return -13; --TBD: search for appropriate full text and set sample to the full text.
      vectorbld_acc (cond, vector ('RDF_VALUE', '=', sample, 'http://local.virt/DAV-RDF', filter_data [ctr]));
    }
  vectorbld_final (cond);
  return 0;
}
;

create function "CatFilter_DAV_RES_UPLOAD" (in detcol_id any, in path_parts any, inout content any, in type varchar, in permissions varchar, in uid integer, in gid integer, in auth_uid integer) returns any
{
  declare rc integer;
  declare cfc_id integer;
  declare rfc_spath, propname, schema_uri, _colpath, fnameext, orig_fnameext, orig_fullpath varchar;
  declare rfc_list_cond, rfc_del_action any;
  declare orig_id, filter_data, fit_cond any;
  -- dbg_obj_princ ('CatFilter_DAV_RES_UPLOAD (', detcol_id, path_parts, ', [content], ', type, permissions, uid, gid, auth_uid, ')');
  rfc_spath := null;
  rc := "CatFilter_GET_CONDITION" (detcol_id, cfc_id, rfc_spath, rfc_list_cond, rfc_del_action);
  if (DAV_HIDE_ERROR (rc) is null)
    return rc;
  if (length (rfc_del_action) < length (rfc_list_cond))
    {
      -- dbg_obj_princ ('del_action = ', rfc_del_action, 'rfc_list_cond = ', rfc_list_cond);
      return -13;
    }
  schema_uri := null;
  rc := "CatFilter_PATH_PARTS_TO_FILTER" (path_parts, schema_uri, filter_data);
  if (DAV_HIDE_ERROR (rc) is null)
    return rc;
  rc := "CatFilter_FILTER_TO_CONDITION" (schema_uri, filter_data, fit_cond);
  if (DAV_HIDE_ERROR (rc) is null)
    return rc;
  fit_cond := vector ('', vector_concat (fit_cond, get_keyword ('', rfc_list_cond)));
  -- dbg_obj_princ ('fit_cond=', fit_cond);
  fnameext := path_parts [length (path_parts) - 1];
  "ResFilter_FNSPLIT" (fnameext, _colpath, orig_fnameext, orig_id);
  orig_fullpath := null;
  if (orig_id is not null)
    orig_fullpath := DAV_HIDE_ERROR (DAV_SEARCH_PATH (orig_id, 'R'));
  if (orig_fullpath is null)
    orig_fullpath := DAV_CONCAT_PATH (rfc_spath, orig_fnameext);
  orig_id := DAV_RES_UPLOAD_STRSES_INT (
    orig_fullpath,
    content, '',
    permissions, '', '',
    null, null, 0,
    null, null, null,
    uid, gid, 1 );
  -- dbg_obj_princ ('Will call "ResFilter_FIT_INTO_CONDITION" (', orig_id, 'R', fit_cond, auth_uid);
  if (DAV_HIDE_ERROR (orig_id) is null)
    return orig_id;
  if (not (isinteger (orig_id)))
    return -13;
  "ResFilter_FIT_INTO_CONDITION" (orig_id, 'R', fit_cond, auth_uid);
  return vector (UNAME'CatFilter', detcol_id, orig_id, schema_uri, filter_data);
}
;

create function "CatFilter_DAV_PROP_REMOVE" (in id any, in st char(0), in propname varchar, in silent integer, in auth_uid integer) returns integer
{
  -- dbg_obj_princ ('CatFilter_DAV_PROP_REMOVE (', id, st, propname, silent, auth_uid, ')');
  if (st <> 'R')
    return -1;
  id := id[2];
  if (isarray (id))
    return call (cast (id[0] as varchar) || '_DAV_PROP_REMOVE') (id, st, propname, silent, auth_uid);
  return DAV_PROP_REMOVE_RAW (id, st, propname, silent, auth_uid);
}
;


create function "CatFilter_DAV_PROP_SET" (in id any, in st char(0), in propname varchar, in propvalue any, in overwrite integer, in auth_uid integer) returns any
{
  declare pid integer;
  declare resv any;
  -- dbg_obj_princ ('CatFilter_DAV_PROP_SET (', id, st, propname, propvalue, overwrite, auth_uid, ')');
  if (st <> 'R')
    return -1;
  id := id[2];
  if (isarray (id))
    return call (cast (id[0] as varchar) || '_DAV_PROP_SET') (id, st, propname, propvalue, overwrite, auth_uid);
  return DAV_PROP_SET_RAW (id, st, propname, propvalue, overwrite, auth_uid);
}
;


create function "CatFilter_DAV_PROP_GET" (in id any, in what char(0), in propname varchar, in auth_uid integer)
{
  declare ret varchar;
  -- dbg_obj_princ ('CatFilter_DAV_PROP_GET (', id, what, propname, auth_uid, ')');
  id := id[2];
  if (isarray (id))
    return call (cast (id[0] as varchar) || '_DAV_PROP_GET') (id, what, propname, auth_uid);
  if (propname[0] = 58)
    return DAV_PROP_GET_INT (id, what, propname, 0, null, null, auth_uid);
  whenever not found goto no_prop;
  select blob_to_string (PROP_VALUE) into ret from WS.WS.SYS_DAV_PROP where PROP_NAME = propname and PROP_PARENT_ID = id and PROP_TYPE = what;
  return ret;

no_prop:
    return -11;
}
;


create function "CatFilter_DAV_PROP_LIST" (in id any, in what char(0), in propmask varchar, in auth_uid integer)
{
  declare ret any;
  -- dbg_obj_princ ('CatFilter_DAV_PROP_LIST (', id, what, propmask, auth_uid, ')');
  id := id[2];
  if (isarray (id))
    return call (cast (id[0] as varchar) || '_DAV_PROP_LIST') (id, what, propmask, auth_uid);
  vectorbld_init (ret);
  for select PROP_NAME, PROP_VALUE from WS.WS.SYS_DAV_PROP where PROP_NAME like propmask and PROP_PARENT_ID = id and PROP_TYPE = what do {
      vectorbld_acc (ret, vector (PROP_NAME, blob_to_string (PROP_VALUE)));
    }
  vectorbld_final (ret);
  return ret;
}
;


create function "CatFilter_DAV_DIR_SINGLE" (in id any, in what char(0), in path any, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('CatFilter_DAV_DIR_SINGLE (', id, what, path, auth_uid, ')');
  if ('C' = what)
    {
      declare cfc_id integer;
      declare rfc_spath varchar;
      declare rfc_list_cond, rfc_del_action any;
      declare loc_name, subcol_perms varchar;
      declare set_readonly integer;
      if (0 > "CatFilter_GET_CONDITION" (id[1], cfc_id, rfc_spath, rfc_list_cond, rfc_del_action))
	{
	-- dbg_obj_princ ('broken filter - no items');
	return -1;
	}
      subcol_perms := coalesce ((select COL_PERMS from WS.WS.SYS_DAV_COL where COL_ID = id[1]), '000000000N');
      subcol_perms[2] := 48; subcol_perms[5] := 48; subcol_perms[8] := 48; -- Can't execute in CatFilter so place zero chars.
      set_readonly := 0;
      if (length (rfc_del_action) < length (rfc_list_cond))
	{
          -- dbg_obj_princ ('del_action = ', rfc_del_action, 'rfc_list_cond = ', rfc_list_cond);
          set_readonly := 1;
	}
      else
        {
          declare filt_len integer;
          filt_len := length (id[4]);
          if ((0 = filt_len) or (mod (filt_len, 4) = 2))
            set_readonly := 1;
        }
      if (set_readonly)
        {
          subcol_perms[1] := 48; subcol_perms[4] := 48; subcol_perms[7] := 48; -- Can't write in CatFilter so place zero chars.
        }
      loc_name := path [length (path) - 2];
      return vector (path, 'C', 0, now (), id, subcol_perms, 0, auth_uid, now (), 'dav/unix-directory', loc_name );
    }
  if (isarray (id[2]))
    {
      declare diritem any;
      declare merged varchar;
      diritem := call (cast (id[0] as varchar) || '_DAV_DIR_SINGLE') (id[2], what, path, auth_uid);
      merged := "ResFilter_FNMERGE" (diritem[10], id[2]);
      diritem[0] := DAV_CONCAT_PATH (path, merged);
      diritem[10] := merged;
      -- dbg_obj_princ ('About to return in DAV_DIR_SINGLE: ', diritem);
      return diritem;
    }
  for select RES_FULL_PATH, RES_ID, length (RES_CONTENT) as clen, RES_MOD_TIME,
    RES_PERMS, RES_GROUP, RES_OWNER, RES_CR_TIME, RES_TYPE, RES_NAME as r1_RES_NAME
  from WS.WS.SYS_DAV_RES r1
  where RES_ID = id[2]
  do
    {
      declare merged varchar;
      -- dbg_obj_princ ('About to return in DAV_DIR_SINGLE: ', r1_RES_NAME, RES_ID);
      if (regexp_parse ('^([^/][^./]*) -Rf((Id[1-9][0-9]*)|([A-Z][A-Za-z0-9]+)-([A-Za-z0-9~+-]*))([.][^/]*)?\044', r1_RES_NAME, 0)) -- Suspicious names should be qualified
        {
          merged := "ResFilter_FNMERGE" (r1_RES_NAME, RES_ID);
        }
      else
        {
          declare cfc_id integer;
	  declare rfc_spath varchar;
	  declare rfc_list_cond, rfc_del_action varchar;
	  declare tmp_comp, namesakes any;
          declare namesakes_no integer;
	  if (0 > "CatFilter_GET_CONDITION" (id[1], cfc_id, rfc_spath, rfc_list_cond, rfc_del_action))
	    {
	      -- dbg_obj_princ ('broken filter - bad id in DIR_SINGLE');
	      return -1;
	    }
          tmp_comp := vector ('',
            vector_concat (
              vector (vector ('RES_NAME', '=', r1_RES_NAME)),
              get_keyword ('', rfc_list_cond) ) );
	  namesakes := DAV_DIR_FILTER_INT (rfc_spath, 1, tmp_comp, null, null, auth_uid);
	  namesakes_no := length (namesakes);
	  if (0 = namesakes_no)
	    return -1;
	  if (1 < namesakes_no)
	    merged := "ResFilter_FNMERGE" (r1_RES_NAME, RES_ID);
	  else
	    merged := r1_RES_NAME;
        }
      path [length (path) - 1] := merged;
--                   0                            1    2     3
      return vector (DAV_CONCAT_PATH ('/', path), 'R', clen, RES_MOD_TIME,
--       4   5          6          7          8            9         10
	 id, RES_PERMS, RES_GROUP, RES_OWNER, RES_CR_TIME, RES_TYPE, merged);
    }
  return -1;
}
;


create function "CatFilter_LIST_SCHEMAS" (in rfc_spath varchar, inout rfc_list_cond any, in auth_uid integer) returns any
{
  return (select VECTOR_AGG (vector (RS_URI, RS_CATNAME)) from WS.WS.SYS_RDF_SCHEMAS);
}
;

create function "CatFilter_LIST_SCHEMA_PROPS" (in rfc_spath varchar, inout rfc_list_cond any, inout schema_uri varchar, inout filter_data any, in auth_uid integer) returns any
{
  declare prop_catnames, res any;
  declare len, ctr integer;
  -- dbg_obj_princ ('CatFilter_LIST_SCHEMA_PROPS (', rfc_spath, rfc_list_cond, schema_uri, filter_data, auth_uid, ')');
  vectorbld_init (res);

retry_after_recomp:
  whenever not found goto schema_nf;
  select deserialize (cast (RS_PROP_CATNAMES as varchar)) into prop_catnames from WS.WS.SYS_RDF_SCHEMAS where RS_URI = schema_uri and RS_PROP_CATNAMES is not null;
  len := length (prop_catnames);
  for (ctr := 0; ctr < len; ctr := ctr + 6)
    {
      if (0 = position (prop_catnames [ctr], filter_data, 1, 4))
        vectorbld_acc (res, vector (prop_catnames [ctr], prop_catnames [ctr + 1]));
    }
  vectorbld_final (res);
  return res;

schema_nf:
  if (exists (select top 1 1 from WS.WS.SYS_RDF_SCHEMAS where RS_URI = schema_uri and RS_PROP_CATNAMES is null))
    {
      DAV_GET_RDF_SCHEMA_N3 (schema_uri);
      goto retry_after_recomp;
    }
  return vector();
}
;


create procedure "CatFilter_GET_RDF_INVERSE_HITS_DISTVALS" (in cfc_id integer, inout filter_data any, inout distval_dict any, in auth_uid integer)
{
  declare filter_length, p0_id, p1_id, p2_id, p3_id, p4_id, res0_id, res1_id, res2_id, res3_id, res4_id, res_last_id, res_id_max integer;
  declare plast_id integer;
  declare p0_val, p1_val, p2_val, p3_val, p4_val, v_last, v_max varchar;
  declare auth_gid integer;
  declare acl_bits, hit_ids any;
  declare c_last1 cursor for select             DRI_CATVALUE from WS.WS.SYS_DAV_RDF_INVERSE
    where DRI_CATF_ID = cfc_id and DRI_PROP_CATID = plast_id and (v_max is null or DRI_CATVALUE > v_max) and
      exists (select top 1 1 from WS.WS.SYS_DAV_RES where RES_ID = DRI_RES_ID and case (DAV_CHECK_PERM (RES_PERMS, '1__', auth_uid, auth_gid, RES_GROUP, RES_OWNER)) when 0 then WS.WS.ACL_IS_GRANTED (RES_ACL, auth_uid, acl_bits) else 1 end);
  declare c_last2 cursor for select DRI_RES_ID, DRI_CATVALUE from WS.WS.SYS_DAV_RDF_INVERSE
    where DRI_CATF_ID = cfc_id and DRI_PROP_CATID = plast_id and (v_max is null or DRI_CATVALUE > v_max) and
      exists (select top 1 1 from WS.WS.SYS_DAV_RES where RES_ID = DRI_RES_ID and case (DAV_CHECK_PERM (RES_PERMS, '1__', auth_uid, auth_gid, RES_GROUP, RES_OWNER)) when 0 then WS.WS.ACL_IS_GRANTED (RES_ACL, auth_uid, acl_bits) else 1 end);
  declare c0 cursor for select DRI_RES_ID from WS.WS.SYS_DAV_RDF_INVERSE where DRI_CATF_ID = cfc_id and DRI_PROP_CATID = p0_id and DRI_CATVALUE = p0_val and DRI_RES_ID >= res_id_max;
  declare c1 cursor for select DRI_RES_ID from WS.WS.SYS_DAV_RDF_INVERSE where DRI_CATF_ID = cfc_id and DRI_PROP_CATID = p1_id and DRI_CATVALUE = p1_val and DRI_RES_ID >= res_id_max;
  declare c2 cursor for select DRI_RES_ID from WS.WS.SYS_DAV_RDF_INVERSE where DRI_CATF_ID = cfc_id and DRI_PROP_CATID = p2_id and DRI_CATVALUE = p2_val and DRI_RES_ID >= res_id_max;
  declare c3 cursor for select DRI_RES_ID from WS.WS.SYS_DAV_RDF_INVERSE where DRI_CATF_ID = cfc_id and DRI_PROP_CATID = p3_id and DRI_CATVALUE = p3_val and DRI_RES_ID >= res_id_max;
  declare c4 cursor for select DRI_RES_ID from WS.WS.SYS_DAV_RDF_INVERSE where DRI_CATF_ID = cfc_id and DRI_PROP_CATID = p4_id and DRI_CATVALUE = p4_val and DRI_RES_ID >= res_id_max;
  -- dbg_obj_princ ('CatFilter_GET_RDF_INVERSE_HITS_DISTVALS (', cfc_id, filter_data, auth_uid, ')');
  filter_length := length (filter_data);
  plast_id := filter_data [filter_length - 1];
  res_id_max := 0;
  v_max := null;
  auth_gid := coalesce ((select U_GROUP from WS.WS.SYS_DAV_USER where U_ID = auth_uid), 0);
  acl_bits := DAV_REQ_CHARS_TO_BITMASK ('1__');

  if (filter_length = 2) -- distinct propvals with no filtering in front -- a special case
    {
      whenever not found goto nf_c_last1;
      -- dbg_obj_princ ('CatFilter_GET_RDF_INVERSE_HITS_DISTVALS: distinct propvals of ', plast_id, ' in ', cfc_id);
      open c_last1 (prefetch 1);
      while (1)
        {
          fetch c_last1 into v_last;
          -- dbg_obj_princ ('CatFilter_GET_RDF_INVERSE_HITS_DISTVALS: v_last is ', v_last, ' v_max is ', v_max);
          if (v_max is null or (v_last > v_max))
            {
              v_max := v_last; -- note that vectorbld_acc() will destroy the value of v_last so this assignment should be before vectorbld_acc().
              dict_put (distval_dict, v_last, 1);
            }
        }
nf_c_last1:
      close c_last1;
      return;
    }

  res0_id := 0;
  res1_id := 0;
  res2_id := 0;
  res3_id := 0;
  res4_id := 0;
  hit_ids := dict_new ();

  p0_id := filter_data [1];
  p0_val := "CatFilter_ENCODE_CATVALUE" (filter_data [2]);
  if (filter_length = 6) -- distinct propvals with 1 fixed property
    {
      whenever not found goto get_distincts_0;
      open c0 (prefetch 1);
      while (1)
        {
          while (res0_id <= res_id_max)
            fetch c0 into res0_id;
          res_id_max := res0_id;
          -- dbg_obj_princ ('CatFilter_GET_RDF_INVERSE_HITS_DISTVALS: put hit ', res_id_max);
          dict_put (hit_ids, res_id_max, 1);
        }
    }

  p1_id := filter_data [4+1];
  p1_val := "CatFilter_ENCODE_CATVALUE" (filter_data [4+2]);
  if (filter_length = 10) -- distinct propvals with 2 fixed property
    {
      whenever not found goto get_distincts_1;
      open c0 (prefetch 1);
      open c1 (prefetch 1);
      while (1)
        {
          while (res0_id <= res_id_max) fetch c0 into res0_id;
          if (res0_id > res_id_max) res_id_max := res0_id;
          while (res1_id < res_id_max) fetch c1 into res1_id;
          if (res1_id > res_id_max) res_id_max := res1_id;
          if ((res0_id = res_id_max) and (res1_id = res_id_max))
            {
              -- dbg_obj_princ ('CatFilter_GET_RDF_INVERSE_HITS_DISTVALS: put hit ', res_id_max);
              dict_put (hit_ids, res_id_max, 1);
            }
          else
            res_id_max := res_id_max + 1;

        }
    }

  p2_id := filter_data [8+1];
  p2_val := "CatFilter_ENCODE_CATVALUE" (filter_data [8+2]);
  if (filter_length = 14) -- distinct propvals with 3 fixed property
    {
      whenever not found goto get_distincts_2;
      open c0 (prefetch 1);
      open c1 (prefetch 1);
      open c2 (prefetch 1);
      while (1)
        {
          -- dbg_obj_princ ('CatFilter_GET_RDF_INVERSE_HITS_DISTVALS: res_id_max is ', res_id_max);
--        res_id_max := 0;
          while (res0_id <= res_id_max) fetch c0 into res0_id;
          -- dbg_obj_princ ('CatFilter_GET_RDF_INVERSE_HITS_DISTVALS: res0_id is ', res0_id);
	  if (res0_id > res_id_max) res_id_max := res0_id;
          while (res1_id < res_id_max) fetch c1 into res1_id;
          -- dbg_obj_princ ('CatFilter_GET_RDF_INVERSE_HITS_DISTVALS: res1_id is ', res1_id);
	  if (res1_id > res_id_max) res_id_max := res1_id;
          while (res2_id < res_id_max) fetch c2 into res2_id;
          -- dbg_obj_princ ('CatFilter_GET_RDF_INVERSE_HITS_DISTVALS: res2_id is ', res2_id);
	  if (res2_id > res_id_max) res_id_max := res2_id;
          if ((res0_id = res_id_max) and (res1_id = res_id_max) and (res2_id = res_id_max))
            {
              -- dbg_obj_princ ('CatFilter_GET_RDF_INVERSE_HITS_DISTVALS: put hit ', res_id_max);
              dict_put (hit_ids, res_id_max, 1);
            }
        }
    }

  p3_id := filter_data [12+1];
  p3_val := "CatFilter_ENCODE_CATVALUE" (filter_data [12+2]);
  if (filter_length = 18) -- distinct propvals with 4 fixed property
    {
      whenever not found goto get_distincts_3;
      open c0 (prefetch 1);
      open c1 (prefetch 1);
      open c2 (prefetch 1);
      open c3 (prefetch 1);
      while (1)
        {
          while (res0_id <= res_id_max) fetch c0 into res0_id;
	  if (res0_id > res_id_max) res_id_max := res0_id;
          while (res1_id < res_id_max) fetch c1 into res1_id;
	  if (res1_id > res_id_max) res_id_max := res1_id;
          while (res2_id < res_id_max) fetch c2 into res2_id;
	  if (res2_id > res_id_max) res_id_max := res2_id;
          while (res3_id < res_id_max) fetch c3 into res3_id;
	  if (res3_id > res_id_max) res_id_max := res3_id;
          if ((res0_id = res_id_max) and (res1_id = res_id_max) and (res2_id = res_id_max) and (res3_id = res_id_max))
            {
              -- dbg_obj_princ ('CatFilter_GET_RDF_INVERSE_HITS_DISTVALS: put hit ', res_id_max);
              dict_put (hit_ids, res_id_max, 1);
            }
        }
    }

  p4_id := filter_data [16+1];
  p4_val := "CatFilter_ENCODE_CATVALUE" (filter_data [16+2]);
  if (filter_length = 22) -- distinct propvals with 5 fixed property
    {
      whenever not found goto get_distincts_4;
      open c0 (prefetch 1);
      open c1 (prefetch 1);
      open c2 (prefetch 1);
      open c3 (prefetch 1);
      open c4 (prefetch 1);
      while (1)
        {
          while (res0_id <= res_id_max) fetch c0 into res0_id;
	  if (res0_id > res_id_max) res_id_max := res0_id;
          while (res1_id < res_id_max) fetch c1 into res1_id;
	  if (res1_id > res_id_max) res_id_max := res1_id;
          while (res2_id < res_id_max) fetch c2 into res2_id;
	  if (res2_id > res_id_max) res_id_max := res2_id;
          while (res3_id < res_id_max) fetch c3 into res3_id;
	  if (res3_id > res_id_max) res_id_max := res3_id;
          while (res4_id < res_id_max) fetch c4 into res4_id;
	  if (res4_id > res_id_max) res_id_max := res4_id;
          if ((res0_id = res_id_max) and (res1_id = res_id_max) and (res2_id = res_id_max) and (res3_id = res_id_max) and (res4_id = res_id_max))
            dict_put (hit_ids, res_id_max, 1);
        }
    }

get_distincts_4:
  -- dbg_obj_princ ('CatFilter_GET_RDF_INVERSE_HITS_DISTVALS: close c4');
  close c4;
get_distincts_3:
  -- dbg_obj_princ ('CatFilter_GET_RDF_INVERSE_HITS_DISTVALS: close c3');
  close c3;
get_distincts_2:
  -- dbg_obj_princ ('CatFilter_GET_RDF_INVERSE_HITS_DISTVALS: close c2');
  close c2;
get_distincts_1:
  -- dbg_obj_princ ('CatFilter_GET_RDF_INVERSE_HITS_DISTVALS: close c1');
  close c1;
get_distincts_0:
  -- dbg_obj_princ ('CatFilter_GET_RDF_INVERSE_HITS_DISTVALS: close c0');
  close c0;

  -- dbg_obj_princ ('CatFilter_GET_RDF_INVERSE_HITS_DISTVALS: now search in all values of ', plast_id);
  whenever not found goto nf_c_last2;
  open c_last2 (prefetch 1);
  while (1)
    {
      fetch c_last2 into res_last_id, v_last;
      if (v_max is null or (v_last > v_max))
        {
          -- dbg_obj_princ ('CatFilter_GET_RDF_INVERSE_HITS_DISTVALS: next value ', v_last, ' at ', res_last_id);
          if (dict_get (hit_ids, res_last_id, 0))
            {
              -- dbg_obj_princ ('CatFilter_GET_RDF_INVERSE_HITS_DISTVALS: full hit at ', res_last_id);
              v_max := v_last; -- note that vectorbld_acc() will destroy the value of v_last so this assignment should be before vectorbld_acc().
              dict_put (distval_dict, v_last, 1);
            }
        }
    }
nf_c_last2:
      close c_last2;
}
;


create function "CatFilter_GET_RDF_INVERSE_HITS_RES_IDS" (in cfc_id integer, inout filter_data any, in auth_uid integer) returns any
{
  declare filter_length, p0_id, p1_id, p2_id, p3_id, p4_id, res0_id, res1_id, res2_id, res3_id, res4_id, res_id_max integer;
  declare acc any;
  declare p0_val, p1_val, p2_val, p3_val, p4_val varchar;
  declare acl_bits any;
  declare auth_gid integer;
  declare c0 cursor for select DRI_RES_ID from WS.WS.SYS_DAV_RDF_INVERSE where DRI_CATF_ID = cfc_id and DRI_PROP_CATID = p0_id and DRI_CATVALUE = p0_val and DRI_RES_ID >= res_id_max and
    exists (select top 1 1 from WS.WS.SYS_DAV_RES where RES_ID = DRI_RES_ID and case (DAV_CHECK_PERM (RES_PERMS, '1__', auth_uid, auth_gid, RES_GROUP, RES_OWNER)) when 0 then WS.WS.ACL_IS_GRANTED (RES_ACL, auth_uid, acl_bits) else 1 end);
  declare c1 cursor for select DRI_RES_ID from WS.WS.SYS_DAV_RDF_INVERSE where DRI_CATF_ID = cfc_id and DRI_PROP_CATID = p1_id and DRI_CATVALUE = p1_val and DRI_RES_ID >= res_id_max;
  declare c2 cursor for select DRI_RES_ID from WS.WS.SYS_DAV_RDF_INVERSE where DRI_CATF_ID = cfc_id and DRI_PROP_CATID = p2_id and DRI_CATVALUE = p2_val and DRI_RES_ID >= res_id_max;
  declare c3 cursor for select DRI_RES_ID from WS.WS.SYS_DAV_RDF_INVERSE where DRI_CATF_ID = cfc_id and DRI_PROP_CATID = p3_id and DRI_CATVALUE = p3_val and DRI_RES_ID >= res_id_max;
  declare c4 cursor for select DRI_RES_ID from WS.WS.SYS_DAV_RDF_INVERSE where DRI_CATF_ID = cfc_id and DRI_PROP_CATID = p4_id and DRI_CATVALUE = p4_val and DRI_RES_ID >= res_id_max;
  -- dbg_obj_princ ('CatFilter_GET_RDF_INVERSE_HITS_RES_IDS (', cfc_id, filter_data, auth_uid, ')');
  filter_length := length (filter_data);
  vectorbld_init (acc);

  res0_id := -1;
  res1_id := -1;
  res2_id := -1;
  res3_id := -1;
  res4_id := -1;
  res_id_max := 0;

  auth_gid := coalesce ((select U_GROUP from WS.WS.SYS_DAV_USER where U_ID = auth_uid), 0);
  acl_bits := DAV_REQ_CHARS_TO_BITMASK ('1__');

  p0_id := filter_data [1];
  p0_val := "CatFilter_ENCODE_CATVALUE" (filter_data [2]);
  if (filter_length = 4) -- resources with 1 fixed property
    {
      whenever not found goto get_distincts_0;
      open c0 (prefetch 1);
      while (1)
        {
          while (res0_id <= res_id_max)
            fetch c0 into res0_id;
          res_id_max := res0_id;
          -- dbg_obj_princ ('CatFilter_GET_RDF_INVERSE_HITS_RES_IDS: put hit ', res_id_max);
          vectorbld_acc (acc, res0_id);
        }
    }

  p1_id := filter_data [4+1];
  p1_val := "CatFilter_ENCODE_CATVALUE" (filter_data [4+2]);
  if (filter_length = 8) -- resources with 2 fixed properties
    {
      whenever not found goto get_distincts_1;
      open c0 (prefetch 1);
      open c1 (prefetch 1);
      while (1)
        {
          while (res1_id < res_id_max) fetch c1 into res1_id;
          if (res1_id > res_id_max) res_id_max := res1_id;
          while (res0_id < res_id_max) fetch c0 into res0_id;
          if (res0_id > res_id_max) res_id_max := res0_id;
          if ((res0_id = res_id_max) and (res1_id = res_id_max))
            {
              -- dbg_obj_princ ('CatFilter_GET_RDF_INVERSE_HITS_RES_IDS: put hit ', res_id_max);
	      vectorbld_acc (acc, res0_id);
              res_id_max := res_id_max + 1;
            }
        }
    }

  p2_id := filter_data [8+1];
  p2_val := "CatFilter_ENCODE_CATVALUE" (filter_data [8+2]);
  if (filter_length = 12) -- resources with 3 fixed properties
    {
      whenever not found goto get_distincts_2;
      open c0 (prefetch 1);
      open c1 (prefetch 1);
      open c2 (prefetch 1);
      while (1)
        {
          while (res1_id < res_id_max) fetch c1 into res1_id;
	  if (res1_id > res_id_max) res_id_max := res1_id;
          while (res2_id < res_id_max) fetch c2 into res2_id;
	  if (res2_id > res_id_max) res_id_max := res2_id;
          while (res0_id < res_id_max) fetch c0 into res0_id;
	  if (res0_id > res_id_max) res_id_max := res0_id;
          if ((res0_id = res_id_max) and (res1_id = res_id_max) and (res2_id = res_id_max))
            {
              -- dbg_obj_princ ('CatFilter_GET_RDF_INVERSE_HITS_RES_IDS: put hit ', res_id_max);
	      vectorbld_acc (acc, res0_id);
              res_id_max := res_id_max + 1;
            }
        }
    }

  p3_id := filter_data [12+1];
  p3_val := "CatFilter_ENCODE_CATVALUE" (filter_data [12+2]);
  if (filter_length = 16) -- resources with 4 fixed properties
    {
      whenever not found goto get_distincts_3;
      open c0 (prefetch 1);
      open c1 (prefetch 1);
      open c2 (prefetch 1);
      open c3 (prefetch 1);
      while (1)
        {
          while (res1_id < res_id_max) fetch c1 into res1_id;
	  if (res1_id > res_id_max) res_id_max := res1_id;
          while (res2_id < res_id_max) fetch c2 into res2_id;
	  if (res2_id > res_id_max) res_id_max := res2_id;
          while (res3_id < res_id_max) fetch c3 into res3_id;
	  if (res3_id > res_id_max) res_id_max := res3_id;
          while (res0_id < res_id_max) fetch c0 into res0_id;
	  if (res0_id > res_id_max) res_id_max := res0_id;
          if ((res0_id = res_id_max) and (res1_id = res_id_max) and (res2_id = res_id_max) and (res3_id = res_id_max))
            {
              -- dbg_obj_princ ('CatFilter_GET_RDF_INVERSE_HITS_RES_IDS: put hit ', res_id_max);
	      vectorbld_acc (acc, res0_id);
              res_id_max := res_id_max + 1;
            }
        }
    }

  p4_id := filter_data [16+1];
  p4_val := "CatFilter_ENCODE_CATVALUE" (filter_data [16+2]);
  if (filter_length = 20) -- resources with 5 fixed properties
    {
      whenever not found goto get_distincts_4;
      open c0 (prefetch 1);
      open c1 (prefetch 1);
      open c2 (prefetch 1);
      open c3 (prefetch 1);
      open c4 (prefetch 1);
      while (1)
        {
          while (res1_id < res_id_max) fetch c1 into res1_id;
	  if (res1_id > res_id_max) res_id_max := res1_id;
          while (res2_id < res_id_max) fetch c2 into res2_id;
	  if (res2_id > res_id_max) res_id_max := res2_id;
          while (res3_id < res_id_max) fetch c3 into res3_id;
	  if (res3_id > res_id_max) res_id_max := res3_id;
          while (res4_id < res_id_max) fetch c4 into res4_id;
	  if (res4_id > res_id_max) res_id_max := res4_id;
          while (res0_id < res_id_max) fetch c0 into res0_id;
	  if (res0_id > res_id_max) res_id_max := res0_id;
          if ((res0_id = res_id_max) and (res1_id = res_id_max) and (res2_id = res_id_max) and (res3_id = res_id_max) and (res4_id = res_id_max))
            {
              -- dbg_obj_princ ('CatFilter_GET_RDF_INVERSE_HITS_RES_IDS: put hit ', res_id_max);
	      vectorbld_acc (acc, res0_id);
              res_id_max := res_id_max + 1;
            }
        }
    }

get_distincts_4:
  close c4;
get_distincts_3:
  close c3;
get_distincts_2:
  close c2;
get_distincts_1:
  close c1;
get_distincts_0:
  close c0;

finalize:
  vectorbld_final (acc);
  -- dbg_obj_princ ('CatFilter_GET_RDF_INVERSE_HITS_RES_IDS (', cfc_id, filter_data, auth_uid, ') returns ', acc);
  return acc;
}
;


create function "CatFilter_LIST_PROP_DISTVALS_AUX" (inout dict any, inout rfp varchar, inout vals any)
{
  -- dbg_obj_princ ('CatFilter_LIST_PROP_DISTVALS_AUX will store ', length (vals), 'values for ', rfp);
  foreach (any val in vals) do
    {
      -- dbg_obj_princ ('CatFilter_LIST_PROP_DISTVALS_AUX will store ', xpath_eval('..', val));
      dict_put (dict, "CatFilter_ENCODE_CATVALUE" (cast (val as varchar)), 1);
    }
  return 1;
}
;

create function "CatFilter_LIST_PROP_DISTVALS" (in detcol_id integer, in cfc_id integer, in rfc_spath varchar, inout rfc_list_cond any, inout schema_uri varchar, inout filter_data any, in auth_uid integer) returns any
{
  declare prop_catnames, filter, res any;
--  declare compilation any;
  declare len, ctr integer;
  declare execstate, execmessage varchar;
  declare execmeta, execrows any;
  declare qry_ft, qry_where, qry_text varchar;

  declare pred_metas, cmp_metas, table_metas any;
  declare used_tables any;
  declare dict any;
  declare auth_gid integer;

  -- dbg_obj_princ ('CatFilter_LIST_PROP_DISTVALS (', cfc_id, rfc_spath, rfc_list_cond, schema_uri, filter_data, auth_uid, ')');
  dict := dict_new ();

  if ((length (get_keyword ('', rfc_list_cond)) = 0) and (length (filter_data) > 0) and (length (filter_data) <= 22))
    { -- Optimized merge intersection on inverse hits
      "CatFilter_GET_RDF_INVERSE_HITS_DISTVALS" (cfc_id, filter_data, dict, auth_uid);
      goto plain_resources_passed;
    }

  len := length (filter_data);
  vectorbld_init (filter);
  "CatFilter_ACC_FILTER_DATA" (filter, filter_data);
  vectorbld_concat_acc (filter, get_keyword ('', rfc_list_cond));
  vectorbld_final (filter);

  -- dbg_obj_princ ('DAV_FC_PRINT_WHERE (', filter, auth_uid, ')');
  DAV_FC_PRED_METAS (pred_metas);
  DAV_FC_CMP_METAS (cmp_metas);
  DAV_FC_TABLE_METAS (table_metas);
  qry_ft := sprintf ('virt:rdf/virt:top-res/virt:prop[*[1][self::(!%s!)]]/virt:value', filter_data [len-2]);
  used_tables := vector (
    'SYS_DAV_RES', vector ('SYS_DAV_RES', '_top', null, vector(), vector(), vector()),
    'SYS_DAV_PROP, PROP_NAME=http://local.virt/DAV-RDF', vector ('SYS_DAV_PROP', '_rdf', '(_rdf.PROP_NAME = ''http://local.virt/DAV-RDF'')', vector(), vector(), vector('[' || qry_ft || ']'))
    );
  qry_where := DAV_FC_PRINT_WHERE_INT (filter, pred_metas, cmp_metas, table_metas, used_tables,
    coalesce ((select COL_OWNER from WS.WS.SYS_DAV_COL where COL_ID = detcol_id), -1) );

  auth_gid := coalesce ((select U_GROUP from WS.WS.SYS_DAV_USER where U_ID = auth_uid), 0);

--  compilation := vector ('', filter, 'DAV', DAV_FC_PRINT_WHERE (filter, auth_uid));
  qry_text := '
select count ( "CatFilter_LIST_PROP_DISTVALS_AUX" (?, _top.RES_FULL_PATH,
  xpath_eval (''[xmlns:virt="virt"] /' || qry_ft ||''',
    xml_tree_doc (deserialize (cast (_rdf.PROP_VALUE as varchar))),
    0 ) ) )
from WS.WS.SYS_DAV_RES as _top
' || qry_where || ' and
  (_top.RES_FULL_PATH between ' || WS.WS.STR_SQL_APOS (rfc_spath) || ' and ' || WS.WS.STR_SQL_APOS (DAV_COL_PATH_BOUNDARY (rfc_spath)) || ') and
  case (DAV_CHECK_PERM (_top.RES_PERMS, ''1__'', ?, ?, _top.RES_GROUP, _top.RES_OWNER)) when 0 then WS.WS.ACL_IS_GRANTED (_top.RES_ACL, ?, DAV_REQ_CHARS_TO_BITMASK (''1__'')) else 1 end
';
      -- dbg_obj_princ ('about to exec:\n', qry_text, '\nrfc_spath = ', rfc_spath);
  exec (qry_text,
    execstate, execmessage, vector (dict, auth_uid, auth_gid, auth_uid), 1, execmeta, execrows );
  -- dbg_obj_princ ('execstate = ', execstate, ' execmessage = ', execmessage);

plain_resources_passed:
  for
    select CFD_DET_SUBCOL_ID, CFD_DET from WS.WS.SYS_DAV_CATFILTER_DETS where CFD_CF_ID = cfc_id
  do
    {
      if (exists (select top 1 1 from SYS_PROCEDURES where P_NAME = fix_identifier_case('DB.DBA.') || CFD_DET || '_CF_LIST_PROP_DISTVALS'))
        call (CFD_DET || '_CF_LIST_PROP_DISTVALS') (CFD_DET_SUBCOL_ID, cfc_id, rfc_spath, rfc_list_cond, schema_uri, filter_data, dict, auth_uid);
    }
  return dict_list_keys (dict, 1);
}
;

create function "CatFilter_DAV_DIR_LIST" (in detcol_id any, in path_parts any, in detcol_path varchar, in name_mask varchar, in recursive integer, in auth_uid integer) returns any
{
  declare cfc_id integer;
  declare rfc_spath varchar;
  declare rfc_list_cond, rfc_del_action any;
  declare davpath, prev_raw_name, schema_uri, subcol_perms varchar;
  declare depth integer;
  declare res, resources, itm, reps, filter_data any;
  declare ctr, itm_ctr, itm_count, prev_is_patched, set_readonly integer;
  declare filter any;
  -- dbg_obj_princ ('CatFilter_DAV_DIR_LIST (', detcol_id, path_parts, detcol_path, name_mask, recursive, auth_uid, ')');
  vectorbld_init (res);
  filter_data := null;
  if (0 > "CatFilter_GET_CONDITION" (detcol_id, cfc_id, rfc_spath, rfc_list_cond, rfc_del_action))
    {
      -- dbg_obj_princ ('broken filter - no items');
      goto final_res;
    }
  subcol_perms := coalesce ((select COL_PERMS from WS.WS.SYS_DAV_COL where COL_ID = detcol_id), '000000000N');
  subcol_perms[2] := 48; subcol_perms[5] := 48; subcol_perms[8] := 48; -- Can't execute in CatFilter so place zero chars.
  if (1 < length(path_parts))
    {
      if ("CatFilter_PATH_PARTS_TO_FILTER" (path_parts, schema_uri, filter_data) < 0)
        {
          -- dbg_obj_princ ('"CatFilter_DAV_DIR_LIST" ends due to failed "CatFilter_PATH_PARTS_TO_FILTER"');
          goto final_res;
        }
    }
  else
    filter_data := null;
  set_readonly := 0;
  if (length (rfc_del_action) < length (rfc_list_cond))
    {
      -- dbg_obj_princ ('del_action = ', rfc_del_action, 'rfc_list_cond = ', rfc_list_cond);
      set_readonly := 1;
    }
  else
    if (-1 = recursive)
      {
        if ((2 = length(path_parts)) or (mod (length (filter_data), 4) = 2))
          set_readonly := 1;
      }
    else
      {
        if ((1 = length(path_parts)) or (mod (length (filter_data), 4) = 0))
          set_readonly := 1;
      }
  if (set_readonly)
    {
      subcol_perms[1] := 48; subcol_perms[4] := 48; subcol_perms[7] := 48; -- Can't write in CatFilter so place zero chars.
    }
  depth := length(path_parts);
-- level 0 -- schemas;
  if (1 = length(path_parts))
    {
      declare schemas any;
      -- dbg_obj_princ ('level of list of schemas');
      if ('' <> path_parts[0])
        {
          -- dbg_obj_princ ('no resources at level 0');
          return vector();
        }
      schemas := "CatFilter_LIST_SCHEMAS" (rfc_spath, rfc_list_cond, auth_uid);
      foreach (any sch in schemas) do
        {
          declare subcol_fullpath varchar;
          subcol_fullpath := DAV_CONCAT_PATH (detcol_path, sch[1] || '/');
          vectorbld_acc (res,
            vector (subcol_fullpath, 'C', 0, now (),
	      vector (UNAME'CatFilter', detcol_id, null, sch[0], null),
	      subcol_perms, 0, auth_uid, now (), 'dav/unix-directory', sch[1]) );
          if (recursive > 0)
            vectorbld_concat_acc (res,
              "CatFilter_DAV_DIR_LIST" (detcol_id,
                 vector_concat (subseq (path_parts, 0, length (path_parts) - 1), vector (sch[1], '')),
                 detcol_path, -- not subcol_fullpath,
                 name_mask, recursive, auth_uid ) );
        }
      goto final_res;
    }
  if ("CatFilter_PATH_PARTS_TO_FILTER" (path_parts, schema_uri, filter_data) < 0)
    {
      -- dbg_obj_princ ('"CatFilter_DAV_DIR_LIST" ends due to failed "CatFilter_PATH_PARTS_TO_FILTER"');
      goto final_res;
    }
  -- dbg_obj_princ ('"CatFilter_DAV_DIR_LIST" founds schema_uri = ', schema_uri, ' filter_data = ', filter_data);
-- We crop at 5 property values, i.e. 20 items in filter data. Sixth property is not displayed to keep URI short.
  if (mod (length (filter_data), 4) = 2)
    { -- list distinct values at odd levels
      declare distvals any;
      -- dbg_obj_princ ('level of distinct values');
      distvals := "CatFilter_LIST_PROP_DISTVALS" (detcol_id, cfc_id, rfc_spath, rfc_list_cond, schema_uri, filter_data, auth_uid);
      if (-1 = recursive)
        {
          --if (0 = length (distvals))
          --  return vector();
          return vector (
            vector (DAV_CONCAT_PATH (detcol_path, path_parts), 'C', 0, now (),
	      vector (UNAME'CatFilter', detcol_id, null, schema_uri, filter_data),
	      subcol_perms, 0, auth_uid, now (), 'dav/unix-directory', path_parts [depth - 2] ) );
        }
      foreach (varchar val in distvals) do
        {
          declare subcol_fullpath varchar;
          subcol_fullpath := DAV_CONCAT_PATH ( DAV_CONCAT_PATH (detcol_path, path_parts), val || '/');
          vectorbld_acc (res,
            vector (subcol_fullpath, 'C', 0, now (),
	      vector (UNAME'CatFilter', detcol_id, null, schema_uri, vector_concat (filter_data, vector (val))),
	      subcol_perms, 0, auth_uid, now (), 'dav/unix-directory', val) );
          if (recursive > 0)
            vectorbld_concat_acc (res,
              "CatFilter_DAV_DIR_LIST" (detcol_id,
                 vector_concat (subseq (path_parts, 0, length (path_parts) - 1), vector (val, '')),
                 detcol_path, -- not subcol_fullpath,
                 name_mask, recursive, auth_uid ) );
        }
      goto final_res;
    }
  else if (length (filter_data) <= 16)
    {
      declare sch_props any;
      -- dbg_obj_princ ('level of prop list');
      sch_props := "CatFilter_LIST_SCHEMA_PROPS" (rfc_spath, rfc_list_cond, schema_uri, filter_data, auth_uid);
      if (-1 = recursive)
        {
          --if (0 = length (sch_props))
          --  return vector();
          return vector (
            vector (DAV_CONCAT_PATH (detcol_path, path_parts), 'C', 0, now (),
	      vector (UNAME'CatFilter', detcol_id, null, schema_uri, filter_data),
	      subcol_perms, 0, auth_uid, now (), 'dav/unix-directory', path_parts [depth - 2] ) );
        }
-- The 'if' below disables infinite recursion.
-- All resources will be displayed, but not all subcollections.
-- This is the longest possible finite list CatFilter can offer to the application.
      if (length (filter_data) >= 4)
        recursive := 0;
      foreach (any prop in sch_props) do
        {
          declare subcol_fullpath varchar;
          subcol_fullpath := DAV_CONCAT_PATH (DAV_CONCAT_PATH (detcol_path, path_parts), prop[1] || '/');
          vectorbld_acc (res,
            vector (subcol_fullpath, 'C', 0, now (),
	      vector (UNAME'CatFilter', detcol_id, null, prop[0], null),
	      subcol_perms, 0, auth_uid, now (), 'dav/unix-directory', prop[1]) );
          if (recursive > 0)
            vectorbld_concat_acc (res,
              "CatFilter_DAV_DIR_LIST" (detcol_id,
                 vector_concat (subseq (path_parts, 0, length (path_parts) - 1), vector (prop[1], '')),
                 detcol_path, -- not subcol_fullpath,
                 name_mask, recursive, auth_uid ) );
        }
    }
  -- dbg_obj_princ ('res = ', res);
  if (0 = length (filter_data))
    {
      -- dbg_obj_princ ('no resources with 0 filter data len');
      goto final_res; -- otherwise all files are listed from all schemas.
    }

  if ((length (get_keyword ('', rfc_list_cond)) = 0) and (length (filter_data) > 0) and (length (filter_data) <= 20))
    { -- Optimized merge intersection on inverse hits
      declare res_ids, res_dir_single any;
      res_ids := "CatFilter_GET_RDF_INVERSE_HITS_RES_IDS" (cfc_id, filter_data, auth_uid);
      -- dbg_obj_princ ('resources = ', res_ids);
      itm_count := length (res_ids);
      vectorbld_init (resources);
      for (itm_ctr := 0; itm_ctr < itm_count; itm_ctr := itm_ctr + 1)
        {
          declare r_id integer;
          r_id := res_ids [itm_ctr];
          res_dir_single := coalesce ((
	    select
--                    0                                        1    2                     3
              vector (DAV_CONCAT_PATH (detcol_path, RES_NAME), 'R', length (RES_CONTENT), RES_MOD_TIME,
--              4     5          6          7          8            9         10
	        r_id, RES_PERMS, RES_GROUP, RES_OWNER, RES_CR_TIME, RES_TYPE, RES_NAME )
	    from WS.WS.SYS_DAV_RES
	    where RES_ID = r_id ) );
	  if (res_dir_single is not null)
	    vectorbld_acc (resources, res_dir_single);
        }
      for select CFD_DET_SUBCOL_ID, CFD_DET from WS.WS.SYS_DAV_CATFILTER_DETS where CFD_CF_ID = cfc_id do
        {
          declare det_res_ids any;
          if (exists (select top 1 1 from SYS_PROCEDURES where P_NAME = fix_identifier_case('DB.DBA.') || CFD_DET || '_CF_GET_RDF_HITS'))
            {
              det_res_ids := call (CFD_DET || '_CF_GET_RDF_HITS') (CFD_DET_SUBCOL_ID, cfc_id, rfc_spath, rfc_list_cond, schema_uri, filter_data, detcol_path, 1, auth_uid);
	      vectorbld_concat_acc (resources, det_res_ids);
            }
        }
      vectorbld_final (resources);
    }
  else
    {
      vectorbld_init (filter);
      "CatFilter_ACC_FILTER_DATA" (filter, filter_data);
      vectorbld_concat_acc (filter, get_keyword ('', rfc_list_cond));
      -- dbg_obj_princ ('name_mask = ', name_mask);
      if ('%' <> name_mask)
        {
          -- dbg_obj_princ ('Adding check for name mask');
          vectorbld_acc (filter, vector ('RES_NAME', 'like', name_mask));
        }
      vectorbld_final (filter);
      filter := vector ('', filter);
      resources := DAV_DIR_FILTER_INT (rfc_spath, 1, filter, null, null, auth_uid);
    }
  reps := dict_new ();
  itm_count := length (resources);
  for (itm_ctr := 0; itm_ctr < itm_count; itm_ctr := itm_ctr + 1)
    {
      declare rname varchar;
      declare orig_id any;
      itm := resources [itm_ctr];
      rname := itm [10];
      orig_id := itm[4];
      if (isarray (orig_id) or regexp_parse ('^([^/][^./]*) -Rf((Id[1-9][0-9]*)|([A-Z][A-Za-z0-9]+)-([A-Za-z0-9~+-]*))([.][^/]*)?\044', rname, 0)) -- Suspicious names should be qualified
        resources [itm_ctr][10] := rname := "ResFilter_FNMERGE" (rname, orig_id);
      dict_put (reps, rname, dict_get (reps, rname, 0) + 1);
    }
  for (itm_ctr := 0; itm_ctr < itm_count; itm_ctr := itm_ctr + 1)
    {
      declare rname varchar;
      declare orig_id integer;
      itm := resources [itm_ctr];
      rname := itm [10];
      orig_id := itm[4];
      resources[itm_ctr][4] := vector (UNAME'CatFilter', detcol_id, orig_id);
      if (dict_get (reps, rname, 0) > 1) -- Suspicious names should be qualified
        resources [itm_ctr][10] := rname := "ResFilter_FNMERGE" (rname, orig_id);
      resources[itm_ctr][0] := DAV_CONCAT_PATH (DAV_CONCAT_PATH (detcol_path, path_parts), rname);
    }
  vectorbld_concat_acc (res, resources);
  -- dbg_obj_princ ('res = ', res);

final_res:
  vectorbld_final (res);
  -- dbg_obj_princ ('\nCatFilter_DAV_DIR_LIST (', detcol_id, path_parts, detcol_path, name_mask, recursive, auth_uid, ') returns ', length (res), ' items:\n');
  -- foreach (any i in res) do -- dbg_obj_princ (i);
  return res;
}
;


create function "CatFilter_DAV_DIR_FILTER" (in detcol_id any, in path_parts any, in detcol_path varchar, inout compilation any, in recursive integer, in auth_uid integer) returns any
{
  declare cfc_id integer;
  declare rfc_spath varchar;
  declare rfc_list_cond, rfc_del_action any;
  declare davpath, prev_raw_name varchar;
  declare res, itm, reps any;
  declare itm_ctr, itm_count, prev_is_patched integer;
  -- dbg_obj_princ ('CatFilter_DAV_DIR_FILTER (', detcol_id, path_parts, detcol_path, compilation, recursive, auth_uid, ')');
  if (0 > "CatFilter_GET_CONDITION" (detcol_id, cfc_id, rfc_spath, rfc_list_cond, rfc_del_action))
    {
      -- dbg_obj_princ ('broken filter - no items');
      return vector();
    }
  if (0 = length (get_keyword ('', compilation)))
    res := DAV_DIR_FILTER_INT (rfc_spath, 1, rfc_list_cond, null, null, auth_uid);
  else
    {
      declare tmp_cond any;
      tmp_cond := vector ('',
        vector_concat (
          get_keyword ('', compilation),
          get_keyword ('', rfc_list_cond) ) );
      res := DAV_DIR_FILTER_INT (rfc_spath, 1, tmp_cond, null, null, auth_uid);
    }
  reps := dict_new ();
  itm_count := length (res);
  for (itm_ctr := 0; itm_ctr < itm_count; itm_ctr := itm_ctr + 1)
    {
      declare rname varchar;
      declare orig_id integer;
      itm := res [itm_ctr];
      rname := itm [10];
      orig_id := itm[4];
      if (isarray (orig_id) or regexp_parse ('^([^/][^./]*) -Rf((Id[1-9][0-9]*)|([A-Z][A-Za-z0-9]+)-([A-Za-z0-9~+-]*))([.][^/]*)?\044', rname, 0)) -- Suspicious names should be qualified
        res [itm_ctr][10] := rname := "ResFilter_FNMERGE" (rname, orig_id);
      dict_put (reps, rname, dict_get (reps, rname, 0) + 1);
    }
  for (itm_ctr := 0; itm_ctr < itm_count; itm_ctr := itm_ctr + 1)
    {
      declare rname varchar;
      declare orig_id integer;
      itm := res [itm_ctr];
      rname := itm [10];
      orig_id := itm[4];
      res[itm_ctr][4] := vector (UNAME'CatFilter', detcol_id, orig_id);
      if (dict_get (reps, rname, 0) > 1) -- Suspicious names should be qualified
        res [itm_ctr][10] := rname := "ResFilter_FNMERGE" (rname, orig_id);
      res[itm_ctr][0] := DAV_CONCAT_PATH (DAV_CONCAT_PATH (detcol_path, path_parts), rname);
    }
  return res;
}
;


create function "CatFilter_DAV_SEARCH_ID" (in detcol_id any, in path_parts any, in what char(1)) returns any
{
  declare cfc_id integer;
  declare rfc_spath varchar;
  declare rfc_list_cond, rfc_del_action any;
  declare orig_id, filter_data any;
  -- dbg_obj_princ ('CatFilter_DAV_SEARCH_ID (', detcol_id, path_parts, what, ')');
  rfc_spath := null;
  orig_id := "CatFilter_DAV_SEARCH_ID_IMPL" (detcol_id, path_parts, what, cfc_id, rfc_spath, rfc_list_cond, rfc_del_action, filter_data);
  return orig_id;
}
;


create function "CatFilter_DAV_SEARCH_PATH" (in id any, in what char(1)) returns any
{
  -- dbg_obj_princ ('CatFilter_DAV_SEARCH_PATH (', id, what, ')');
  if ('R' = what)
    return coalesce ((select RES_FULL_PATH from WS.WS.SYS_DAV_RES where RES_ID = id[2]), null);
  if ('C' = what)
    {
      declare res varchar;
      res := DAV_SEARCH_PATH (id[1], 'C');
      if (id[3] is not null)
        {
        -- TBD
          ;
        }
      if (id[4] is not null)
        {
        -- TBD
          ;
        }
      return res;
    }

  return -14;
}
;


create function "CatFilter_DAV_RES_UPLOAD_COPY" (in detcol_id any, in path_parts any, in source_id any, in what char(1), in overwrite integer, in permissions varchar, in uid integer, in gid integer, in auth_uid integer) returns any
{
  declare cfc_id integer;
  declare rfc_spath, schema_uri varchar;
  declare rfc_list_cond, rfc_del_action, filter_data, fit_cond any;
  declare rc integer;
  -- dbg_obj_princ ('CatFilter_DAV_RES_UPLOAD_COPY (', detcol_id, path_parts, source_id, what, overwrite, permissions, uid, gid, auth_uid, ')');
  if (0 > "CatFilter_GET_CONDITION" (detcol_id, cfc_id, rfc_spath, rfc_list_cond, rfc_del_action))
    {
      -- dbg_obj_princ ('broken filter - no items');
      return -2;
    }
  if (length (rfc_del_action) < length (rfc_list_cond))
    {
      -- dbg_obj_princ ('del_action = ', rfc_del_action, 'rfc_list_cond = ', rfc_list_cond);
      return -13;
    }
  rc := "CatFilter_PATH_PARTS_TO_FILTER" (path_parts, schema_uri, filter_data);
  if (DAV_HIDE_ERROR (rc) is null)
    return rc;
  rc := "CatFilter_FILTER_TO_CONDITION" (schema_uri, filter_data, fit_cond);
  if (DAV_HIDE_ERROR (rc) is null)
    return rc;
  fit_cond := vector ('', vector_concat (fit_cond, get_keyword ('', rfc_list_cond)));
  if ('R' <> what)
    return -2;
  if ('' = path_parts [length (path_parts) - 1])
    return -2;
  if (isinteger (source_id) and
     exists (select 1 from WS.WS.SYS_DAV_RES
         where RES_ID = source_id and RES_NAME = path_parts [length (path_parts) - 1] and (RES_FULL_PATH between rfc_spath and DAV_COL_PATH_BOUNDARY (rfc_spath)) ) )
    {
      "ResFilter_FIT_INTO_CONDITION" (source_id, what, fit_cond, auth_uid);
    }
  else
    {
      declare new_full_path varchar;
      new_full_path := DAV_CONCAT_PATH (rfc_spath, path_parts [length (path_parts) - 1]);
      rc := DAV_COPY_INT (DAV_SEARCH_PATH (source_id, what), new_full_path, overwrite, permissions,
         coalesce ((select U_NAME from WS.WS.SYS_DAV_USER where U_ID = uid), ''),
         coalesce ((select G_NAME from WS.WS.SYS_DAV_GROUP where G_ID = gid), ''),
         null, null, 0);
      if (DAV_HIDE_ERROR (rc) is null)
        return rc;
      source_id := DAV_SEARCH_ID (new_full_path, what);
      if (DAV_HIDE_ERROR (source_id) is null)
        return source_id;
      if (not (isinteger (source_id)))
        return -13;
      "ResFilter_FIT_INTO_CONDITION" (source_id, what, fit_cond, auth_uid);
    }
  return 1;
}
;


create function "CatFilter_DAV_RES_UPLOAD_MOVE" (in detcol_id any, in path_parts any, in source_id any, in what char(1), in overwrite integer, in auth_uid integer) returns any
{
  declare cfc_id integer;
  declare rfc_spath, schema_uri varchar;
  declare rfc_list_cond, rfc_del_action, filter_data, fit_cond any;
  declare rc integer;
  -- dbg_obj_princ ('CatFilter_DAV_RES_UPLOAD_MOVE (', detcol_id, path_parts, source_id, what, overwrite, auth_uid, ')');
  if (0 > "CatFilter_GET_CONDITION" (detcol_id, cfc_id, rfc_spath, rfc_list_cond, rfc_del_action))
    {
      -- dbg_obj_princ ('broken filter - no items');
      return -2;
    }
  if (length (rfc_del_action) < length (rfc_list_cond))
    {
      -- dbg_obj_princ ('del_action = ', rfc_del_action, 'rfc_list_cond = ', rfc_list_cond);
      return -13;
    }
  rc := "CatFilter_PATH_PARTS_TO_FILTER" (path_parts, schema_uri, filter_data);
  if (DAV_HIDE_ERROR (rc) is null)
    return rc;
  rc := "CatFilter_FILTER_TO_CONDITION" (schema_uri, filter_data, fit_cond);
  if (DAV_HIDE_ERROR (rc) is null)
    return rc;
  fit_cond := vector ('', vector_concat (fit_cond, get_keyword ('', rfc_list_cond)));
  if ('R' <> what)
    return -2;
  if ('' = path_parts [length (path_parts) - 1])
    return -2;
  if (isinteger (source_id) and
    exists (select 1 from WS.WS.SYS_DAV_RES
        where RES_ID = source_id and RES_NAME = path_parts [length (path_parts) - 1] and (RES_FULL_PATH between rfc_spath and DAV_COL_PATH_BOUNDARY (rfc_spath))))
    {
      "ResFilter_FIT_INTO_CONDITION" (source_id, what, fit_cond, auth_uid);
    }
  else
    {
      declare new_full_path varchar;
      new_full_path := DAV_CONCAT_PATH (rfc_spath, path_parts [length (path_parts) - 1]);
      rc := DAV_MOVE_INT (DAV_SEARCH_PATH (source_id, what), new_full_path, overwrite, null, null, 0, 1);
      if (DAV_HIDE_ERROR (rc) is null)
        return rc;
      source_id := DAV_SEARCH_ID (new_full_path, what);
      if (DAV_HIDE_ERROR (source_id) is null)
        return source_id;
      if (not (isinteger (source_id)))
        return -13;
      "ResFilter_FIT_INTO_CONDITION" (source_id, what, fit_cond, auth_uid);
    }
  return 1;
}
;


create function "CatFilter_DAV_RES_CONTENT" (in id any, inout content any, out type varchar, in content_mode integer) returns integer
{
  -- dbg_obj_princ ('CatFilter_DAV_RES_CONTENT (', id, ', [content], [type], ', content_mode, ')');
  declare cont any;
  if ((content_mode = 0) or (content_mode = 2))
    select RES_CONTENT, RES_TYPE into content, type from WS.WS.SYS_DAV_RES where RES_ID = id[2];
  else if (content_mode = 1)
    select http (RES_CONTENT, content), RES_TYPE into cont, type from WS.WS.SYS_DAV_RES where RES_ID = id[2];
  else if (content_mode = 3)
    select http (RES_CONTENT), RES_TYPE into cont, type from WS.WS.SYS_DAV_RES where RES_ID = id[2];
  return id[2];
}
;


create function "CatFilter_DAV_SYMLINK" (in detcol_id any, in path_parts any, in source_id any, in what char(1), in overwrite integer, in uid integer, in gid integer, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('CatFilter_DAV_SYMLINK (', detcol_id, path_parts, source_id, overwrite, uid, gid, auth_uid, ')');
  return -20;
}
;


create function "CatFilter_DAV_LOCK" (in path any, inout id any, in type char(1), inout locktype varchar, inout scope varchar, in token varchar, inout owner_name varchar, inout owned_tokens varchar, in depth varchar, in timeout_sec integer, in auth_uid integer) returns any
{
  declare rc, u_token, new_token varchar;
  -- dbg_obj_princ ('CatFilter_DAV_LOCK (', path, id, type, locktype, scope, token, owner_name, owned_tokens, depth, timeout_sec, auth_uid, ')');
  if ('R' <> type)
    return -20;
  if (DAV_HIDE_ERROR (id) is null)
    return -20;
  if (isarray (id))
    return DAV_LOCK_INT (path, id[2], type, locktype, scope, token, owner_name, owned_tokens, depth, timeout_sec, null, null, auth_uid);
  return -20;
}
;


create function "CatFilter_DAV_UNLOCK" (in id any, in type char(1), in token varchar, in auth_uid integer)
{
  -- dbg_obj_princ ('CatFilter_DAV_UNLOCK (', id, type, token, auth_uid, ')');
  if (isarray (id))
    id := id [2];
  return DAV_UNLOCK_INT (id, type, token, null, null, auth_uid);
}
;


create function "CatFilter_DAV_IS_LOCKED" (inout id any, inout type char(1), in owned_tokens varchar) returns integer
{
  declare rc integer;
  declare orig_id any;
  declare orig_type char(1);
  -- dbg_obj_princ ('CatFilter_DAV_IS_LOCKED (', id, type, owned_tokens, ')');
  orig_id := id;
  id := orig_id[2];
  rc := DAV_IS_LOCKED_INT (id, type, owned_tokens);
  if (rc <> 0)
    return rc;
  id := orig_id[1];
  orig_type := type;
  type := 'C';
  rc := DAV_IS_LOCKED_INT (id, type, owned_tokens);
  if (rc <> 0)
    return rc;
  id := orig_id;
  type := orig_type;
  return 0;
}
;


create function "CatFilter_DAV_LIST_LOCKS" (in id any, in type char(1), in recursive integer) returns any
{
  declare res any;
  -- dbg_obj_princ ('CatFilter_DAV_LIST_LOCKS" (', id, type, recursive);
  id := id[2];
  if (isarray (id))
    return call (cast (id[0] as varchar) || '_DAV_LIST_LOCKS') (id, type, recursive);
  res := vector();
  for select LOCK_TYPE, LOCK_SCOPE, LOCK_TOKEN, LOCK_TIMEOUT, LOCK_OWNER, LOCK_OWNER_INFO
    from WS.WS.SYS_DAV_LOCK where LOCK_PARENT_ID = id and LOCK_PARENT_TYPE = type do {
      res := vector_concat (res, vector (vector (LOCK_TYPE, LOCK_SCOPE, LOCK_TOKEN, LOCK_TIMEOUT, LOCK_OWNER, LOCK_OWNER_INFO)));
    }
  return res;
}
;

create function "CatFilter_CONFIGURE" (
  in id any,
  in params any,
  in path varchar,
  in filter any,
  in auth_uname varchar := null,
  in auth_upwd varchar := null,
  in auth_uid integer := null) returns integer
{
  declare cfid, rc, ctr integer;
  declare colname varchar;
  declare compilation, del_act any;

  compilation := vector ('', filter);
  rc := DAV_DIR_FILTER_INT (path, 1, compilation, auth_uname, auth_upwd, auth_uid);
  if (isinteger (rc))
    return rc;

  if (DAV_HIDE_ERROR (id) is null)
    return -20;

  colname := DAV_SEARCH_PATH (id, 'C');
  if (not (isstring (colname)))
    return -23;

  rc := DAV_SEARCH_ID (path, 'C');
  if (DAV_HIDE_ERROR (rc) is null)
    return rc;

  if (path <> DAV_SEARCH_PATH (rc, 'C'))
    return -2;

  if (path between colname and (colname || '\255\255\255\255'))
    return -28;

  rc := DAV_PROP_SET_INT (colname, 'virt:Filter-Params', params, null, null, 0, 1, 1);
  if (DAV_HIDE_ERROR (rc) is null)
    return rc;

  rc := DAV_PROP_SET_INT (colname, 'virt:ResFilter-SearchPath', path, null, null, 0, 1, 1);
  if (DAV_HIDE_ERROR (rc) is null)
    return rc;

  rc := DAV_PROP_SET_INT (colname, 'virt:ResFilter-ListCond', "ResFilter_ENCODE_FILTER" (compilation), null, null, 0, 1, 1);
  if (DAV_HIDE_ERROR (rc) is null)
    return rc;

  del_act := "ResFilter_MAKE_DEL_ACTION_FROM_CONDITION" (compilation);
  rc := DAV_PROP_SET_INT (colname, 'virt:ResFilter-DelAction', "ResFilter_ENCODE_FILTER" (del_act), null, null, 0, 1, 1);
  if (DAV_HIDE_ERROR (rc) is null)
    return rc;

  cfid := coalesce ((select CF_ID from WS.WS.SYS_DAV_CATFILTER where CF_SEARCH_PATH = path));
  if (cfid is null)
  {
    declare path_z varchar;

    cfid := WS.WS.GETID ('CF');
    insert into WS.WS.SYS_DAV_CATFILTER (CF_ID, CF_SEARCH_PATH)
      values (cfid, path);

    path_z := path || '\255\255\255\255';
    for (select p.PROP_VALUE, p.PROP_PARENT_ID
           from WS.WS.SYS_DAV_RES r join WS.WS.SYS_DAV_PROP p on (r.RES_ID = p.PROP_PARENT_ID)
          where (r.RES_FULL_PATH between path and path_z) and (p.PROP_NAME = 'http://local.virt/DAV-RDF') and (p.PROP_TYPE = 'R')) do
	  {
	    "CatFilter_FEED_DAV_RDF_INVERSE" (PROP_VALUE, PROP_PARENT_ID, 0, cfid);
	    ctr := ctr + 1;
	    if (mod (ctr, 1000) = 0)
	      commit work;
	  }
    commit work;
    for (select COL_ID, COL_DET, WS.WS.COL_PATH (COL_ID) as _c_path from WS.WS.SYS_DAV_COL where COL_DET is not null and not (COL_DET like '%Filter')) do
    {
      if ("LEFT" (_c_path, length (path)) = path)
	    {
        insert replacing WS.WS.SYS_DAV_CATFILTER_DETS (CFD_CF_ID, CFD_DET_SUBCOL_ID, CFD_DET)
	        values (cfid, COL_ID, COL_DET);
    	}
	  }
  }
  rc := DAV_PROP_SET_INT (colname, 'virt:CatFilter-ID', cast (cfid as varchar), null, null, 0, 1, 1);
  if (DAV_HIDE_ERROR (rc) is null)
    return rc;

  update WS.WS.SYS_DAV_COL set COL_DET='CatFilter' where COL_ID=id;

  return 0;
}
;

create procedure "CatFilter_FEED_DAV_RDF_INVERSE" (inout propval any, inout propparent integer, in is_del integer := 0, in cfid integer := null)
{
  declare resfullpath, path_head, pv varchar;
  declare doc any;
  declare triplets any;

  if (126 = __tag (propval))
    pv := blob_to_string (propval);
  else
    {
      if ((not isstring (propval)) or (propval = ''))
	return;
      pv := propval;
    }
  if (193 <> pv[0])
    return;
  doc := null;
  if (cfid is not null)
    {
      path_head := '/';
      goto cfid_found;
    }
  else
    {
      resfullpath := coalesce ((select r.RES_FULL_PATH from WS.WS.SYS_DAV_RES r where r.RES_ID = propparent));
      if (resfullpath is null)
        return;
      path_head := subseq (resfullpath, 0, strrchr (resfullpath, '/'));
    }

next_cfid:
  while (1)
    {
      if (length (path_head) <= 1)
        return;
      cfid := coalesce ((select CF_ID from WS.WS.SYS_DAV_CATFILTER where CF_SEARCH_PATH = (path_head || '/')));
      path_head := subseq (path_head, 0, strrchr (path_head, '/'));
      if (cfid is not null)
        goto cfid_found;
    }

cfid_found:
  if (doc is null)
    {
      doc := deserialize (pv);
      if (0 = length (doc))
        return;
      doc := xml_tree_doc (doc);
    }
  -- dbg_obj_princ ('CatFilter_INS_DAV_RDF_INVERSE: saving res ', propparent, ' in catfilter ', cfid);
  triplets := xpath_eval ('[xmlns:virt="virt"] /virt:rdf/virt:top-res/virt:prop[virt:value]', doc, 0);
  foreach (any prop in triplets) do
    {
      declare propname varchar;
      declare prop_catid integer;
      propname := cast (xpath_eval ('name(*[1])', prop) as varchar);
      prop_catid := coalesce ((select RPN_CATID from WS.WS.SYS_RDF_PROP_NAME where RPN_URI = propname));
      if (prop_catid is null)
        {
          prop_catid := WS.WS.GETID ('RPN');
          -- dbg_obj_princ ('CatFilter_INS_DAV_RDF_INVERSE: insert into WS.WS.SYS_RDF_PROP_NAME (RPN_URI, RPN_CATID) values (', propname, prop_catid, ')');
          insert into WS.WS.SYS_RDF_PROP_NAME (RPN_URI, RPN_CATID) values (propname, prop_catid);
        }
      if (is_del)
        delete from WS.WS.SYS_DAV_RDF_INVERSE
        where
          (DRI_CATF_ID = cfid) and (DRI_PROP_CATID = prop_catid) and
          (DRI_CATVALUE = "CatFilter_ENCODE_CATVALUE" (cast (xpath_eval ('[xmlns:virt="virt"] virt:value', prop) as varchar))) and
          (DRI_RES_ID = propparent);
      else
        insert soft WS.WS.SYS_DAV_RDF_INVERSE (DRI_CATF_ID, DRI_PROP_CATID, DRI_CATVALUE, DRI_RES_ID)
        values (
          cfid,
          prop_catid,
          "CatFilter_ENCODE_CATVALUE" (cast (xpath_eval ('[xmlns:virt="virt"] virt:value', prop) as varchar)),
          propparent );
    }
  goto next_cfid;
}
;


create trigger SYS_DAV_PROP_VALUE_RDF_I after insert on WS.WS.SYS_DAV_PROP order 10 referencing new as NP
{
  if (NP.PROP_NAME <> 'http://local.virt/DAV-RDF')
    return;
  if (NP.PROP_TYPE <> 'R')
    return;
  "CatFilter_FEED_DAV_RDF_INVERSE" (NP.PROP_VALUE, NP.PROP_PARENT_ID);
}
;


create trigger SYS_DAV_PROP_VALUE_RDF_D before delete on WS.WS.SYS_DAV_PROP order 10 referencing old as OP
{
  declare pv varchar;
  declare doc any;
  if (OP.PROP_NAME <> 'http://local.virt/DAV-RDF')
    return;
  if (OP.PROP_TYPE <> 'R')
    return;
  "CatFilter_FEED_DAV_RDF_INVERSE" (OP.PROP_VALUE, OP.PROP_PARENT_ID, 1);
}
;


create trigger SYS_DAV_PROP_VALUE_RDF_U after update on WS.WS.SYS_DAV_PROP order 10 referencing old as OP, new as NP
{
  declare pv varchar;
  declare doc any;
  if (OP.PROP_NAME <> 'http://local.virt/DAV-RDF')
    goto register_new_propvals;
  if (OP.PROP_TYPE <> 'R')
    goto register_new_propvals;
  "CatFilter_FEED_DAV_RDF_INVERSE" (OP.PROP_VALUE, OP.PROP_PARENT_ID, 1);

register_new_propvals:
  if (NP.PROP_NAME <> 'http://local.virt/DAV-RDF')
    return;
  if (NP.PROP_TYPE <> 'R')
    return;
  "CatFilter_FEED_DAV_RDF_INVERSE" (NP.PROP_VALUE, NP.PROP_PARENT_ID);
}
;


create procedure "CatFilter_INIT_SYS_DAV_RDF_INVERSE" (in run_if_once integer)
{
  declare ctr integer;
  set isolation = 'committed';
  if (run_if_once)
    {
      if (0 <> sequence_next('CatFilter_INIT_SYS_DAV_RDF_INVERSE'))
        return;
    }
  else
    {
-- For safety, schemas should be recompiled.
      update WS.WS.SYS_RDF_SCHEMAS set RS_PRECOMPILED = null, RS_PROP_CATNAMES = null;
      commit work;
      delete from WS.WS.SYS_DAV_RDF_INVERSE;
    }
  commit work;
  for (select PROP_VALUE, PROP_PARENT_ID from WS.WS.SYS_DAV_PROP where PROP_NAME = 'http://local.virt/DAV-RDF' and PROP_TYPE = 'R') do
    {
      "CatFilter_FEED_DAV_RDF_INVERSE" (PROP_VALUE, PROP_PARENT_ID);
      ctr := ctr + 1;
      if (mod (ctr, 1000) = 0)
        commit work;
    }
}
;

--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2015 OpenLink Software
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

create function "ResFilter_DAV_AUTHENTICATE" (in id any, in what char(1), in req varchar, in auth_uname varchar, in auth_pwd varchar, in auth_uid integer)
{
  declare rfc_spath varchar;
  declare rfc_list_cond, rfc_del_action any;
  declare spath_id integer;
  -- dbg_obj_princ ('ResFilter_DAV_AUTHENTICATE (', id, what, req, auth_uname, auth_pwd, auth_uid, ')');
  rfc_spath := null;
  if (DAV_HIDE_ERROR ("ResFilter_GET_CONDITION" (id[1], rfc_spath, rfc_list_cond, rfc_del_action)) is null)
    return -1;
  if (not ('110' like req))
    return -13; -- Internals of ResFilter are not executable.
  if ('C' = what)
    {
      spath_id := DAV_SEARCH_ID (rfc_spath, 'C');
      return DAV_AUTHENTICATE (spath_id, 'C', req, auth_uname, auth_pwd, auth_uid);
    }
  if ('R' = what)
    {
      return DAV_AUTHENTICATE (id [2], 'R', req, auth_uname, auth_pwd, auth_uid);
    }
  return -14;
}
;


create function "ResFilter_NORM" (in value any) returns varchar
{
  value := blob_to_string (value);
  if (('' = value) or (193 <> value[0]))
    return value;
  value := deserialize (value)[1];
  if (isstring (value))
    return value;
  return cast (xml_tree_doc(value) as varchar);
}
;


create function "ResFilter_ENCODE_FILTER" (in filt any) returns varchar
{
  if (193 <> __tag (filt))
    signal ('.....', 'Invalid filter passed to ResFilter_ENCODE_FILTER');
  filt := serialize (filt);
  filt[0] := 2;
  return filt;
}
;


create function "ResFilter_DECODE_FILTER" (in value any) returns any
{
  value := blob_to_string (value);
  if (('' = value) or (value[0] <> 2))
    signal ('.....', 'Invalid filter serialization passed to ResFilter_DECODE_FILTER');
  value [0] := 193;
  return deserialize (value);
}
;


create function "ResFilter_GET_CONDITION" (in detcol_id integer, out rfc_spath varchar, out rfc_list_cond any, out rfc_del_action any)
{
  -- dbg_obj_princ ('ResFilter_GET_CONDITION (', detcol_id, '...)');
  whenever not found goto nf;
  if (isarray (detcol_id))
    return -20;
  select "ResFilter_NORM" (PROP_VALUE) into rfc_spath from WS.WS.SYS_DAV_PROP where PROP_NAME = 'virt:ResFilter-SearchPath' and PROP_PARENT_ID = detcol_id and PROP_TYPE = 'C';
  select "ResFilter_DECODE_FILTER" (PROP_VALUE) into rfc_list_cond from WS.WS.SYS_DAV_PROP where PROP_NAME = 'virt:ResFilter-ListCond' and PROP_PARENT_ID = detcol_id and PROP_TYPE = 'C';
  select "ResFilter_DECODE_FILTER" (PROP_VALUE) into rfc_del_action from WS.WS.SYS_DAV_PROP where PROP_NAME = 'virt:ResFilter-DelAction' and PROP_PARENT_ID = detcol_id and PROP_TYPE = 'C';
  return 0;
nf:
  return -1;
}
;


create procedure "ResFilter_FIT_INTO_CONDITION" (in id any, in what char (1), inout rfc_list_cond any, in auth_uid integer)
{
  -- dbg_obj_princ ('ResFilter_FIT_INTO_CONDITION (', id, what, rfc_list_cond, auth_uid, ')');
  declare has_rdf_preds integer;
  declare raw_filter any;
  has_rdf_preds := 0;
  raw_filter := get_keyword ('', rfc_list_cond);
  foreach (any pred in raw_filter) do
    {
      declare propid integer;
      declare old_value, pred_name, pred_cmp varchar;
      pred_name := pred [0];
      pred_cmp := pred [1];
      if (('PROP_VALUE' = pred_name) and ('=' = pred_cmp))
        {
          if (isarray (id))
            {
              call (cast (id[0] as varchar) || '_DAV_PROP_SET')(id, what, pred[3], pred[2], 1, auth_uid);
        goto next_pred;
            }
    whenever not found goto ins_prop;
    select p.PROP_ID, "ResFilter_NORM" (p.PROP_VALUE) into propid, old_value from WS.WS.SYS_DAV_PROP p, WS.WS.SYS_DAV_RES r where p.PROP_NAME = pred[3] and p.PROP_PARENT_ID = id and p.PROP_TYPE = what and r.RES_ID = id;
    if (old_value <> pred[2])
      update WS.WS.SYS_DAV_PROP set PROP_VALUE = pred[2] where PROP_ID = propid;
    goto next_pred;
ins_prop:
    propid := WS.WS.GETID ('P');
    insert replacing WS.WS.SYS_DAV_PROP (PROP_ID, PROP_NAME, PROP_VALUE, PROP_PARENT_ID, PROP_TYPE)
          values (propid, pred[3], pred[2], id, what);
    goto next_pred;
  }
      if (('PROP_VALUE' = pred_name) and ('<>' = pred_cmp))
        {
          if (isarray (id))
            {
              call (cast (id[0] as varchar) || '_DAV_PROP_REMOVE')(id, what, pred[3], 1, auth_uid);
        goto next_pred;
            }
    whenever not found goto next_pred;
    select p.PROP_ID into propid from WS.WS.SYS_DAV_PROP p, WS.WS.SYS_DAV_RES r where p.PROP_NAME = pred[3] and p.PROP_PARENT_ID = id and p.PROP_TYPE = what and r.RES_ID = id and "ResFilter_NORM" (p.PROP_VALUE) = pred[2];
    delete from WS.WS.SYS_DAV_PROP where PROP_ID = propid;
    goto next_pred;
  }
      if (('PROP_NAME' = pred_name) and ('not_exists' = pred_cmp))
        {
          if (isarray (id))
            {
              call (cast (id[0] as varchar) || '_DAV_PROP_REMOVE')(id, what, pred[3], 1, auth_uid);
        goto next_pred;
            }
    whenever not found goto next_pred;
    select p.PROP_ID into propid from WS.WS.SYS_DAV_PROP p, WS.WS.SYS_DAV_RES r where p.PROP_NAME = pred[2] and p.PROP_PARENT_ID = id and p.PROP_TYPE = what and r.RES_ID = id;
    delete from WS.WS.SYS_DAV_PROP where PROP_ID = propid;
    goto next_pred;
  }
      else if (('RDF_VALUE' = pred_name) and (('=' = pred_cmp) or ('<>' = pred_cmp)) and (5 = length (pred)) and ('http://local.virt/DAV-RDF' = pred [3]))
        {
    has_rdf_preds := 1;
    goto next_pred;
  }
      else if (('RDF_PRED' = pred_name) and ('not_exists' = pred_cmp) and (4 = length (pred)) and ('http://local.virt/DAV-RDF' = pred [3]))
        {
    has_rdf_preds := 1;
    goto next_pred;
  }
      else
        {
          -- dbg_obj_princ ('ResFilter_FIT_INTO_CONDITION has failed on ', pred);
          signal ('.....', 'Unsupported predicate in ResFilter_FIT_INTO_CONDITION');
        }
next_pred: ;
    }
  if (has_rdf_preds)
    {
      declare propid integer;
      declare old_prop, old_n3, acc_n3, new_n3, new_davxml any;
      declare top_path nvarchar;
      top_path := cast (DAV_SEARCH_PATH (id, what) as nvarchar);
      xte_nodebld_init (acc_n3);
      foreach (any pred in raw_filter) do
        {
    declare pred_name, pred_cmp varchar;
          pred_name := pred [0];
    pred_cmp := pred [1];
    if (('RDF_VALUE' = pred_name) and ('=' = pred_cmp))
          {
        xte_nodebld_acc (acc_n3,
          xte_node (
      xte_head ('N3', 'N3S', top_path, 'N3P', pred [4]),
      pred [2] ) );
      }
        }
      xte_nodebld_final (acc_n3, xte_head (' root'));
      acc_n3 := xml_tree_doc (acc_n3);
      old_n3 := null;
      propid := null;
      if (isarray (id))
        {
          old_prop := call (cast (id[0] as varchar) || '_DAV_PROP_GET')(id, what, 'http://local.virt/DAV-RDF', auth_uid);
          if (DAV_HIDE_ERROR (old_prop) is null)
            {
              goto do_merge;
            }
          if (isentity (old_prop))
            {
        old_n3 := xslt ('http://local.virt/davxml2n3xml', old_prop);
              goto do_merge;
            }
          goto old_prop_found;
        }
      whenever not found goto do_merge;
      select p.PROP_ID, blob_to_string (p.PROP_VALUE) into propid, old_prop
      from WS.WS.SYS_DAV_PROP p, WS.WS.SYS_DAV_RES r
      where p.PROP_NAME = 'http://local.virt/DAV-RDF' and p.PROP_PARENT_ID = id and p.PROP_TYPE = what and r.RES_ID = id;
      goto do_merge;
old_prop_found:
      old_prop := deserialize (cast (old_prop as varchar));
      old_n3 := xslt ('http://local.virt/davxml2n3xml', xml_tree_doc (old_prop));
do_merge:
      new_n3 := DAV_RDF_MERGE (old_n3, acc_n3, null, -1);
      foreach (any pred in raw_filter) do
        {
    declare pred_name, pred_cmp varchar;
          pred_name := pred [0];
    pred_cmp := pred [1];
    if (('RDF_PRED' = pred_name) and ('<>' = pred_cmp))
          {
            new_n3 := XMLUpdate (new_n3, '/N3[N3P=' || WS.WS.STR_SQL_APOS (pred[4]) || '][string (.) =' || WS.WS.STR_SQL_APOS (pred[2]) || ']', null);
      }
    else
    if (('RDF_PRED' = pred_name) and ('not_exists' = pred_cmp))
          {
            new_n3 := XMLUpdate (new_n3, '/N3[N3P=' || WS.WS.STR_SQL_APOS (pred[2]) || ']', null);
      }
        }
      new_davxml := DAV_RDF_PREPROCESS_RDFXML (new_n3, top_path, 1);
      if (isarray (id))
        {
          call (cast (id[0] as varchar) || '_DAV_PROP_SET')(id, what, 'http://local.virt/DAV-RDF', new_davxml, 1, auth_uid);
          goto next_pred;
        }
      else if (propid is null)
        {
    propid := WS.WS.GETID ('P');
    insert replacing WS.WS.SYS_DAV_PROP (PROP_ID, PROP_NAME, PROP_VALUE, PROP_PARENT_ID, PROP_TYPE)
          values (propid, 'http://local.virt/DAV-RDF', serialize (new_davxml), id, what);
  }
      else
  update WS.WS.SYS_DAV_PROP set PROP_VALUE = serialize (new_davxml) where PROP_ID = propid;
    }
}
;


create function "ResFilter_MAKE_DEL_ACTION_FROM_CONDITION" (inout rfc_list_cond any) returns any
{
  -- dbg_obj_princ ('ResFilter_MAKE_DEL_ACTION_FROM_CONDITION (', rfc_list_cond, ')');
  declare raw_filter, res any;
  res := vector ();
  raw_filter := get_keyword ('', rfc_list_cond);
  foreach (any pred in raw_filter) do
    {
      declare propid integer;
      declare old_value, pred_name, pred_cmp varchar;
      pred_name := pred [0];
      pred_cmp := pred [1];
      if (('PROP_VALUE' = pred_name) and ('=' = pred_cmp))
        {
          res := vector_concat (res, vector (vector ('PROP_VALUE', '<>', pred[2], pred [3])));
        }
      else if (('PROP_VALUE' = pred_name) and ('<>' = pred_cmp))
        {
          res := vector_concat (res, vector (vector ('PROP_VALUE', '=', pred[2], pred [3])));
        }
      else if (('RDF_VALUE' = pred_name) and ('=' = pred_cmp) and (5 = length (pred)) and ('http://local.virt/DAV-RDF' = pred [3]))
        {
          res := vector_concat (res, vector (vector ('RDF_VALUE', '<>', pred [2], 'http://local.virt/DAV-RDF', pred [4])));
        }
      else if (('RDF_VALUE' = pred_name) and ('<>' = pred_cmp) and (5 = length (pred)) and ('http://local.virt/DAV-RDF' = pred [3]))
        {
          res := vector_concat (res, vector (vector ('RDF_VALUE', '=', pred [2], 'http://local.virt/DAV-RDF', pred [4])));
        }
      else return vector ();
    }
  return vector ('', res);
}
;


create function "ResFilter_LEAVE_CONDITION" (in id integer, in what char (1), in rfc_del_action any, in auth_uid integer) returns integer
{
  "ResFilter_FIT_INTO_CONDITION" (id, what, rfc_del_action, auth_uid);
  return 0;
}
;


create function "ResFilter_FNMERGE" (in path any, in id any) returns varchar
{
  declare pairs any;
  declare res varchar;
  pairs := regexp_parse ('^(.*[/])?([^/][^./]*)([^/]*)\044', path, 0);
  if (pairs is null)
    signal ('.....', sprintf ('Internal error: failed "ResFilter_FNMERGE" (%s, %d)', path, id));
  if (isinteger (id))
    return sprintf ('%s -RfId%d%s', subseq (path, 0, pairs[5]), id, subseq (path, pairs[6]));
  id[0] := cast (id[0] as varchar);
  res := sprintf ('%s -Rf%s%s',
    subseq (path, 0, pairs[5]),
    call (cast (id[0] as varchar) || '_RF_ID2SUFFIX')(id, 'R'),
    subseq (path, pairs[6]) );
  -- dbg_obj_princ ('ResFilter_FNMERGE (', path, id, ') returns ', res);
  return res;
}
;


create procedure "ResFilter_FNSPLIT" (in path any, out colpath varchar, out orig_fnameext varchar, out id any)
{
  declare pairs any;
  declare fname, fext varchar;
  -- dbg_obj_princ ('ResFilter_FNSPLIT (', path, ')');
  pairs := regexp_parse ('^(.*[/])?([^/][^./]*)([^/]*)\044', path, 0);
  if (pairs is null)
    signal ('.....', sprintf ('Internal error: failed "ResFilter_FNSPLIT" (%s)', path));
  colpath := subseq (path, 0, pairs[4]);
  fname := subseq (path, pairs[4], pairs[5]);
  fext := subseq (path, pairs[6], pairs[7]);
  -- dbg_obj_princ ('ResFilter_FNSPLIT: colpath = ', colpath, ', fname = ', fname, ', fext = ', fext);
  pairs := regexp_parse ('^(.*) -RfId([1-9][0-9]*)\044', fname, 0);
  if (pairs is not null)
    {
      orig_fnameext := subseq (fname, pairs[2], pairs[3]) || fext;
      id := cast (subseq (fname, pairs[4], pairs[5]) as integer);
      -- dbg_obj_princ ('ResFilter_FNSPLIT (', path, ') decoded ', colpath, orig_fnameext, id);
      return;
    }
  pairs := regexp_parse ('^(.*) -Rf([A-Z][A-Za-z0-9]+)-([A-Za-z0-9~+-]*)\044', fname, 0);
  if (pairs is not null)
    {
      whenever sqlstate '*' goto oblom;
      orig_fnameext := subseq (fname, pairs[2], pairs[3]) || fext;
      id := call (subseq (fname, pairs[4], pairs[5]) || '_RF_SUFFIX2ID')(subseq (fname, pairs[6], pairs[7]), 'R');
      -- dbg_obj_princ ('ResFilter_FNSPLIT (', path, ') decoded ', colpath, orig_fnameext, id);
      return;
    }
oblom:
  orig_fnameext := fname || fext;
  id := null;
  -- dbg_obj_princ ('ResFilter_FNSPLIT (', path, ') decoded ', colpath, orig_fnameext, id);
}
;


create function "ResFilter_DAV_SEARCH_ID_IMPL" (in detcol_id any, in path_parts any, in what char(1), inout rfc_spath varchar, inout rfc_list_cond any, inout rfc_del_action any) returns any
{
  declare colpath, orig_fnameext varchar;
  declare orig_id any;
  declare hitlist any;
  declare ext_cond any;
  -- dbg_obj_princ ('ResFilter_DAV_SEARCH_ID (', detcol_id, path_parts, what, ')');
  if ('R' <> what)
    return -1;
  if (not (isstring (rfc_spath)))
    {
      if (0 > "ResFilter_GET_CONDITION" (detcol_id, rfc_spath, rfc_list_cond, rfc_del_action))
  {
    -- dbg_obj_princ ('broken filter - no items');
    return -1;
  }
    }
  if (1 <> length(path_parts) or ('' = path_parts[0]))
    {
      -- dbg_obj_princ ('not a resource right inside detcol - no items');
      return -1;
    }
  "ResFilter_FNSPLIT" (path_parts[0], colpath, orig_fnameext, orig_id);
  -- dbg_obj_princ (path_parts, colpath, orig_fnameext, orig_id, rfc_spath, rfc_list_cond, rfc_del_action);
  if (orig_id is null)
    {
      ext_cond := vector (vector ('RES_NAME', '=', orig_fnameext));
    }
  else
    {
      if (isinteger (orig_id))
        ext_cond := vector (vector ('RES_NAME', '=', orig_fnameext), vector ('RES_ID', '=', orig_id));
      else
        ext_cond := vector (vector ('RES_NAME', '=', orig_fnameext), vector ('RES_ID_SERIALIZED', '=', serialize (orig_id)));
    }
  ext_cond := vector ('',
    vector_concat (ext_cond, get_keyword ('', rfc_list_cond) ) );
  hitlist := DAV_DIR_FILTER_INT (rfc_spath, 1, ext_cond, null, null, http_dav_uid ());
  -- dbg_obj_princ ('hitlist is ', hitlist);
  if (length (hitlist) <> 1)
    return -1;
  return hitlist[0][4];
}
;


create function "ResFilter_DAV_AUTHENTICATE_HTTP" (in id any, in what char(1), in req varchar, in can_write_http integer, inout a_lines any, inout a_uname varchar, inout a_pwd varchar, inout a_uid integer, inout a_gid integer, inout _perms varchar) returns integer
{
  declare rc integer;
  declare puid, pgid, ruid, rgid integer;
  declare u_password, pperms varchar;
  declare allow_anon integer;
  if (length (req) <> 3)
    return -15;

  whenever not found goto nf_col_or_res;
  puid := http_dav_uid();
  pgid := coalesce (
    ( select G_ID from WS.WS.SYS_DAV_GROUP
      where G_NAME = 'ResFilter_' || coalesce ((select COL_NAME from WS.WS.SYS_DAV_COL where COL_ID=id[1] and COL_DET='ResFilter'), '')
      ), puid+1);
  pperms := '110100100NN';
  if ((what <> 'R') and (what <> 'C'))
    return -14;
  allow_anon := WS.WS.PERM_COMP (substring (cast (pperms as varchar), 7, 3), req);
  if (a_uid is null)
    {
      if ((not allow_anon) or ('' <> WS.WS.FINDPARAM (a_lines, 'Authorization:')))
      rc := WS.WS.GET_DAV_AUTH (a_lines, allow_anon, can_write_http, a_uname, u_password, a_uid, a_gid, _perms);
      if (rc < 0)
        return rc;
    }
  if (isinteger (a_uid))
    {
      if (a_uid < 0)
  return a_uid;
     if (a_uid = 1) -- Anonymous FTP
  {
          a_uid := 0;
    a_gid := 0;
  }
    }
  if (not DAV_CHECK_PERM (pperms, req, a_uid, a_gid, pgid, puid))
    return -13;

  if (isarray (id[2]))
    return -1;
  select RES_OWNER, RES_GROUP into ruid, rgid from WS.WS.SYS_DAV_RES where RES_ID = id[2];
  if (not DAV_CHECK_PERM (pperms, req, a_uid, a_gid, rgid, ruid))
    return -13;

  return a_uid;

nf_col_or_res:
  return -1;
}
;


create function "ResFilter_DAV_GET_PARENT" (in id any, in st char(1), in path varchar) returns any
{
  -- dbg_obj_princ ('ResFilter_DAV_GET_PARENT (', id, st, path, ')');
  if (st = 'R')
    return id [1];
  return -20;
}
;


create function "ResFilter_DAV_COL_CREATE" (in detcol_id any, in path_parts any, in permissions varchar, in uid integer, in gid integer, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('ResFilter_DAV_COL_CREATE (', detcol_id, path_parts, permissions, uid, gid, auth_uid, ')');
  return -20;
}
;


create function "ResFilter_DAV_COL_MOUNT" (in detcol_id any, in path_parts any, in full_mount_path varchar, in mount_det varchar, in permissions varchar, in uid integer, in gid integer, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('ResFilter_DAV_COL_MOUNT (', detcol_id, path_parts, full_mount_path, mount_det, permissions, uid, gid, auth_uid, ')');
  return -20;
}
;


create function "ResFilter_DAV_COL_MOUNT_HERE" (in parent_id any, in full_mount_path varchar, in permissions varchar, in uid integer, in gid integer, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('ResFilter_DAV_COL_MOUNT (', parent_id, full_mount_path, permissions, uid, gid, auth_uid, ')');
  return -20;
}
;


create function "ResFilter_DAV_DELETE" (in detcol_id any, in path_parts any, in what char(1), in silent integer, in auth_uid integer) returns integer
{
  declare rc, orig_id integer;
  declare rfc_spath varchar;
  declare rfc_list_cond, rfc_del_action any;
  -- dbg_obj_princ ('ResFilter_DAV_DELETE (', detcol_id, path_parts, what, silent, auth_uid, ')');
  rfc_spath := null;
  orig_id := "ResFilter_DAV_SEARCH_ID_IMPL" (detcol_id, path_parts, what, rfc_spath, rfc_list_cond, rfc_del_action);
  if (orig_id < 0)
    return orig_id;
  if (0 = length (rfc_del_action))
    return -20;
  return "ResFilter_LEAVE_CONDITION" (orig_id, what, rfc_del_action, auth_uid);
}
;

create function "ResFilter_DAV_RES_UPLOAD" (in detcol_id any, in path_parts any, inout content any, in type varchar, in permissions varchar, in uid integer, in gid integer, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('ResFilter_DAV_RES_UPLOAD (', detcol_id, path_parts, ', [content], ', type, permissions, uid, gid, auth_uid, ')');
  return -20;
}
;


create function "ResFilter_DAV_PROP_REMOVE" (in id any, in st char(0), in propname varchar, in silent integer, in auth_uid integer) returns integer
{
  -- dbg_obj_princ ('ResFilter_DAV_PROP_REMOVE (', id, st, propname, silent, auth_uid, ')');
  if (st <> 'R')
    return -1;
  id := id[2];
  if (isarray (id))
    return call (cast (id[0] as varchar) || '_DAV_PROP_REMOVE') (id, st, propname, silent, auth_uid);
  return DAV_PROP_REMOVE_RAW (id, st, propname, silent, auth_uid);
}
;


create function "ResFilter_DAV_PROP_SET" (in id any, in st char(0), in propname varchar, in propvalue any, in overwrite integer, in auth_uid integer) returns any
{
  declare pid integer;
  declare resv any;
  -- dbg_obj_princ ('ResFilter_DAV_PROP_SET (', id, st, propname, propvalue, overwrite, auth_uid, ')');
  if (st <> 'R')
    return -1;
  id := id[2];
  if (isarray (id))
    return call (cast (id[0] as varchar) || '_DAV_PROP_SET') (id, st, propname, propvalue, overwrite, auth_uid);
  return DAV_PROP_SET_RAW (id, st, propname, propvalue, overwrite, auth_uid);
}
;


create function "ResFilter_DAV_PROP_GET" (in id any, in what char(0), in propname varchar, in auth_uid integer)
{
  declare ret varchar;
  -- dbg_obj_princ ('ResFilter_DAV_PROP_GET (', id, what, propname, auth_uid, ')');
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


create function "ResFilter_DAV_PROP_LIST" (in id any, in what char(0), in propmask varchar, in auth_uid integer)
{
  declare ret any;
  -- dbg_obj_princ ('ResFilter_DAV_PROP_LIST (', id, what, propmask, auth_uid, ')');
  id := id[2];
  vectorbld_init (ret);
  for select PROP_NAME, PROP_VALUE from WS.WS.SYS_DAV_PROP where PROP_NAME like propmask and PROP_PARENT_ID = id and PROP_TYPE = what do {
      vectorbld_acc (ret, vector (PROP_NAME, blob_to_string (PROP_VALUE)));
    }
  vectorbld_final (ret);
  return ret;
}
;


create function "ResFilter_DAV_DIR_SINGLE" (in id any, in what char(0), in path any, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('ResFilter_DAV_DIR_SINGLE (', id, what, path, auth_uid, ')');
  if ('R' <> what)
    return -1;
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
    declare rfc_spath varchar;
    declare rfc_list_cond, rfc_del_action varchar;
    declare tmp_comp, namesakes any;
          declare namesakes_no integer;
    if (0 > "ResFilter_GET_CONDITION" (id[1], rfc_spath, rfc_list_cond, rfc_del_action))
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
--                   0                                                       1    2     3
      return vector (DAV_CONCAT_PATH (DAV_SEARCH_PATH (id[1], 'C'), merged), 'R', clen, RES_MOD_TIME,
--       4   5          6          7          8            9         10
   id, RES_PERMS, RES_GROUP, RES_OWNER, RES_CR_TIME, RES_TYPE, merged);
    }
  return -1;
}
;


create function "ResFilter_DAV_DIR_LIST" (in detcol_id any, in path_parts any, in detcol_path varchar, in name_mask varchar, in recursive integer, in auth_uid integer) returns any
{
  declare rfc_spath varchar;
  declare rfc_list_cond, rfc_dec_action any;
  declare davpath, prev_raw_name varchar;
  declare res, itm, reps any;
  declare itm_ctr, itm_count, prev_is_patched integer;
  -- dbg_obj_princ ('ResFilter_DAV_DIR_LIST (', detcol_id, path_parts, detcol_path, name_mask, recursive, auth_uid, ')');
  if (0 > "ResFilter_GET_CONDITION" (detcol_id, rfc_spath, rfc_list_cond, rfc_dec_action))
    {
      -- dbg_obj_princ ('broken filter - no items');
      return vector();
    }
  if (1 <> length(path_parts) or ('' <> path_parts[0]))
    {
      -- dbg_obj_princ ('nonempty path - no items');
      return vector();
    }
  if ('%' = name_mask)
    res := DAV_DIR_FILTER_INT (rfc_spath, 1, rfc_list_cond, null, null, auth_uid);
  else
    {
      declare tmp_cond any;
      tmp_cond := vector ('',
        vector_concat (
          vector (vector ('RES_NAME', 'like', name_mask)),
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
      if (regexp_parse ('^([^/][^./]*) -Rf((Id[1-9][0-9]*)|([A-Z][A-Za-z0-9]+)-([A-Za-z0-9~+-]*))([.][^/]*)?\044', rname, 0)) -- Suspicious names should be qualified
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
      res[itm_ctr][4] := vector (UNAME'ResFilter', detcol_id, orig_id);
      if (dict_get (reps, rname, 0) > 1) -- Suspicious names should be qualified
        res [itm_ctr][10] := rname := "ResFilter_FNMERGE" (rname, orig_id);
      res[itm_ctr][0] := DAV_CONCAT_PATH (detcol_path, rname);
    }
  return res;
}
;


create function "ResFilter_DAV_DIR_FILTER" (in detcol_id any, in path_parts any, in detcol_path varchar, inout compilation any, in recursive integer, in auth_uid integer) returns any
{
  declare rfc_spath varchar;
  declare rfc_list_cond, rfc_dec_action any;
  declare davpath, prev_raw_name varchar;
  declare res, itm, reps any;
  declare itm_ctr, itm_count, prev_is_patched integer;
  -- dbg_obj_princ ('ResFilter_DAV_DIR_FILTER (', detcol_id, path_parts, detcol_path, compilation, recursive, auth_uid, ')');
  if (0 > "ResFilter_GET_CONDITION" (detcol_id, rfc_spath, rfc_list_cond, rfc_dec_action))
    {
      -- dbg_obj_princ ('broken filter - no items');
      return vector();
    }
  if (1 <> length(path_parts) or ('' <> path_parts[0]))
    {
      -- dbg_obj_princ ('nonempty path - no items');
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
      if (regexp_parse ('^([^/][^./]*) -Rf((Id[1-9][0-9]*)|([A-Z][A-Za-z0-9]+)-([A-Za-z0-9~+-]*))([.][^/]*)?\044', rname, 0)) -- Suspicious names should be qualified
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
      res[itm_ctr][4] := vector (UNAME'ResFilter', detcol_id, orig_id);
      if (dict_get (reps, rname, 0) > 1) -- Suspicious names should be qualified
        res [itm_ctr][10] := rname := "ResFilter_FNMERGE" (rname, orig_id);
      res[itm_ctr][0] := DAV_CONCAT_PATH (detcol_path, rname);
    }
  return res;
}
;


create function "ResFilter_DAV_SEARCH_ID" (in detcol_id any, in path_parts any, in what char(1)) returns any
{
  declare rfc_spath varchar;
  declare rfc_list_cond, rfc_del_action any;
  declare orig_id integer;
  -- dbg_obj_princ ('ResFilter_DAV_SEARCH_ID (', detcol_id, path_parts, what, ')');
  rfc_spath := null;
  orig_id := "ResFilter_DAV_SEARCH_ID_IMPL" (detcol_id, path_parts, what, rfc_spath, rfc_list_cond, rfc_del_action);
  if (orig_id < 0)
    return orig_id;
  return vector (UNAME'ResFilter', detcol_id, orig_id);
}
;


create function "ResFilter_DAV_SEARCH_PATH" (in id any, in what char(1)) returns any
{
  -- dbg_obj_princ ('ResFilter_DAV_SEARCH_PATH (', id, what, ')');
  return coalesce ((select RES_FULL_PATH from WS.WS.SYS_DAV_RES where RES_ID = id[2]), null);
}
;


create function "ResFilter_DAV_RES_UPLOAD_COPY" (
  in detcol_id any,
  in path_parts any,
  in source_id any,
  in what char(1),
  in overwrite integer,
  in permissions varchar,
  in uid integer,
  in gid integer,
  in auth_uid integer,
  in auth_uname varchar := null,
  in auth_pwd varchar := null,
  in extern integer := 1,
  in check_locks any := 1) returns any
{
  declare rfc_spath varchar;
  declare rfc_list_cond, rfc_del_action any;
  declare rc integer;
  -- dbg_obj_princ ('ResFilter_DAV_RES_UPLOAD_COPY (', detcol_id, path_parts, source_id, what, overwrite, permissions, uid, gid, auth_uid, ')');
  if (0 > "ResFilter_GET_CONDITION" (detcol_id, rfc_spath, rfc_list_cond, rfc_del_action))
    {
      -- dbg_obj_princ ('broken filter - no items');
      return -2;
    }
  if (0 = length (rfc_del_action))
    return -20;
  if (1 <> length (path_parts))
    return -2;
  if ('R' <> what)
    return -2;
  if ('' = path_parts[0])
    return -2;
  if (isinteger (source_id) and
     exists (select 1 from WS.WS.SYS_DAV_RES
         where RES_ID = source_id and RES_NAME = path_parts[0] and (RES_FULL_PATH between rfc_spath and DAV_COL_PATH_BOUNDARY (rfc_spath)) ) )
    {
      "ResFilter_FIT_INTO_CONDITION" (source_id, what, rfc_list_cond, auth_uid);
    }
  else
    {
      declare new_full_path varchar;

      new_full_path := DAV_CONCAT_PATH (rfc_spath, path_parts[0]);
      rc := DAV_COPY_INT (
        DAV_SEARCH_PATH (source_id, what),
        new_full_path,
        overwrite,
        permissions,
        coalesce ((select U_NAME from WS.WS.SYS_DAV_USER where U_ID = uid), ''),
        coalesce ((select G_NAME from WS.WS.SYS_DAV_GROUP where G_ID = gid), ''),
        auth_uname,
        auth_pwd,
        extern);
      if (DAV_HIDE_ERROR (rc) is null)
        return rc;

      source_id := DAV_SEARCH_ID (new_full_path, what);
      if (DAV_HIDE_ERROR (source_id) is null)
        return source_id;

      "ResFilter_FIT_INTO_CONDITION" (source_id, what, rfc_list_cond, auth_uid);
    }
  return 1;
}
;


create function "ResFilter_DAV_RES_UPLOAD_MOVE" (
  in detcol_id any,
  in path_parts any,
  in source_id any,
  in what char(1),
  in overwrite integer,
  in auth_uid integer,
  in auth_uname varchar := null,
  in auth_pwd varchar := null,
  in extern integer := 1,
  in check_locks any := 1) returns any
{
  declare rfc_spath varchar;
  declare rfc_list_cond, rfc_del_action any;
  declare rc integer;
  -- dbg_obj_princ ('ResFilter_DAV_RES_UPLOAD_MOVE (', detcol_id, path_parts, source_id, what, overwrite, auth_uid, ')');
  if (0 > "ResFilter_GET_CONDITION" (detcol_id, rfc_spath, rfc_list_cond, rfc_del_action))
    {
      -- dbg_obj_princ ('broken filter - no items');
      return -2;
    }
  if (0 = length (rfc_del_action))
    return -20;
  if (1 <> length (path_parts))
    return -2;
  if ('R' <> what)
    return -2;
  if ('' = path_parts[0])
    return -2;
  if (isinteger (source_id) and
    exists (select 1 from WS.WS.SYS_DAV_RES
        where RES_ID = source_id and RES_NAME = path_parts[0] and (RES_FULL_PATH between rfc_spath and DAV_COL_PATH_BOUNDARY (rfc_spath))))
    {
      "ResFilter_FIT_INTO_CONDITION" (source_id, what, rfc_list_cond, auth_uid);
    }
  else
    {
      declare new_full_path varchar;

      new_full_path := DAV_CONCAT_PATH (rfc_spath, path_parts[0]);
      rc := DAV_MOVE_INT (
        DAV_SEARCH_PATH (source_id, what),
        new_full_path,
        overwrite,
        auth_uname,
        auth_pwd,
        extern,
        check_locks);
      if (DAV_HIDE_ERROR (rc) is null)
        return rc;

      source_id := DAV_SEARCH_ID (new_full_path, what);
      if (DAV_HIDE_ERROR (source_id) is null)
        return source_id;

      "ResFilter_FIT_INTO_CONDITION" (source_id, what, rfc_list_cond, auth_uid);
    }
  return 1;
}
;


create function "ResFilter_DAV_RES_CONTENT" (in id any, inout content any, out type varchar, in content_mode integer) returns integer
{
  -- dbg_obj_princ ('ResFilter_DAV_RES_CONTENT (', id, ', [content], [type], ', content_mode, ')');
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


create function "ResFilter_DAV_SYMLINK" (in detcol_id any, in path_parts any, in source_id any, in what char(1), in overwrite integer, in uid integer, in gid integer, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('ResFilter_DAV_SYMLINK (', detcol_id, path_parts, source_id, overwrite, uid, gid, auth_uid, ')');
  return -20;
}
;


create function "ResFilter_DAV_LOCK" (in path any, in id any, in type char(1), inout locktype varchar, inout scope varchar, in token varchar, inout owner_name varchar, inout owned_tokens varchar, in depth varchar, in timeout_sec integer, in auth_uid integer) returns any
{
  declare rc, u_token, new_token varchar;
  -- dbg_obj_princ ('ResFilter_DAV_LOCK (', path, id, type, locktype, scope, token, owner_name, owned_tokens, depth, timeout_sec, auth_uid, ')');
  if ('R' <> type)
    return -20;
  if (DAV_HIDE_ERROR (id) is null)
    return -20;
  if (isarray (id))
    return DAV_LOCK_INT (path, id[2], type, locktype, scope, token, owner_name, owned_tokens, depth, timeout_sec, null, null, auth_uid);
  return -20;
}
;


create function "ResFilter_DAV_UNLOCK" (in id any, in type char(1), in token varchar, in auth_uid integer)
{
  -- dbg_obj_princ ('ResFilter_DAV_UNLOCK (', id, type, token, auth_uid, ')');
  if (isarray (id))
    id := id [2];
  return DAV_UNLOCK_INT (id, type, token, null, null, auth_uid);
}
;


create function "ResFilter_DAV_IS_LOCKED" (inout id any, inout type char(1), in owned_tokens varchar) returns integer
{
  declare rc integer;
  declare orig_id any;
  declare orig_type char(1);
  -- dbg_obj_princ ('ResFilter_DAV_IS_LOCKED (', id, type, owned_tokens, ')');
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


create function "ResFilter_DAV_LIST_LOCKS" (in id any, in type char(1), in recursive integer) returns any
{
  declare res any;
  -- dbg_obj_princ ('ResFilter_DAV_LIST_LOCKS" (', id, type, recursive);
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

create function "ResFilter_CONFIGURE" (
  in id any,
  in params any,
  in path varchar,
  in filter any,
  in auth_uname varchar := null,
  in auth_upwd varchar := null,
  in auth_uid integer := null) returns integer
{
  -- dbg_obj_princ ('ResFilter_CONFIGURE', id, params, path, filter);
  declare rc integer;
  declare colPath varchar;
  declare compilation, del_act any;

  if (not isnull ("ResFilter_VERIFY" (DB.DBA.DAV_SEARCH_PATH (id, 'C'), vector ('params', params, 'path', path, 'filter', filter))))
    return -38;

  colPath := DAV_SEARCH_PATH (id, 'C');
  if (DAV_HIDE_ERROR (colPath) is null)
    return colPath;

  rc := DAV_SEARCH_ID (path, 'C');
  if (DAV_HIDE_ERROR (rc) is null)
    return rc;

  compilation := vector ('', filter);
  rc := DAV_DIR_FILTER_INT (path, 1, compilation, auth_uname, auth_upwd, auth_uid);
  if (isinteger (rc))
    return rc;

  rc := DAV_PROP_SET_INT (colPath, 'virt:Filter-Params', params, null, null, 0, 1, 1);
  if (DAV_HIDE_ERROR (rc) is null)
    return rc;

  rc := DAV_PROP_SET_INT (colPath, 'virt:ResFilter-SearchPath', path, null, null, 0, 1, 1);
  if (DAV_HIDE_ERROR (rc) is null)
    return rc;

  rc := DAV_PROP_SET_INT (colPath, 'virt:ResFilter-ListCond', "ResFilter_ENCODE_FILTER" (compilation), null, null, 0, 1, 1);
  if (DAV_HIDE_ERROR (rc) is null)
    return rc;

  del_act := "ResFilter_MAKE_DEL_ACTION_FROM_CONDITION" (compilation);
  rc := DAV_PROP_SET_INT (colPath, 'virt:ResFilter-DelAction', "ResFilter_ENCODE_FILTER" (del_act), null, null, 0, 1, 1);
  if (DAV_HIDE_ERROR (rc) is null)
    return rc;

  -- set DET Type Value
  DB.DBA.ResFilter__paramSet (id, 'C', ':virtdet', DB.DBA.ResFilter__detName (), 0, 0, 0);
}
;

create function "ResFilter_VERIFY" (
  in path integer,
  in params any)
{
  -- dbg_obj_princ ('ResFilter_VERIFY (', path, params, ')');
  declare tmp any;

  tmp := get_keyword ('path', params);
  if (tmp between path and (path || '\255\255\255\255'))
    return sprintf ('Search path (%s) can not contains in folder full path (%s)!', tmp, path);

  return null;
}
;

create function DB.DBA.ResFilter__detName ()
{
  return UNAME'ResFilter';
}
;

create function DB.DBA.ResFilter__paramSet (
  in _id any,
  in _what varchar,
  in _propName varchar,
  in _propValue any,
  in _serialized integer := 1,
  in _prefixed integer := 1,
  in _encrypt integer := 0)
{
  -- dbg_obj_princ ('DB.DBA.ResFilter__paramSet', _propName, _propValue, ')');
  declare retValue any;

  if (_serialized)
    _propValue := serialize (_propValue);

  if (_encrypt)
    _propValue := pwd_magic_calc (DB.DBA.ResFilter__detName (), _propValue);

  if (_prefixed)
    _propName := 'virt:ResFilter-' || _propName;

  retValue := DB.DBA.DAV_PROP_SET_RAW (_id, _what, _propName, _propValue, 1, http_dav_uid ());

  return retValue;
}
;

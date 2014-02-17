--
--  $Id$
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

create function "oMail_DAV_AUTHENTICATE" (in id any, in what char(1), in req varchar, in auth_uname varchar, in auth_pwd varchar, in auth_uid integer) returns integer
{
  -- dbg_obj_princ ('oMail_DAV_AUTHENTICATE (', id, what, req, auth_uname, auth_pwd, auth_uid, ')');
  if (auth_uid < 0)
    return -12;
  if (not ('100' like req))
    return -13;
  if ((auth_uid <> id[3]) and (auth_uid <> http_dav_uid()))
    {
      -- dbg_obj_princ ('a_uid is ', auth_uid, ', id[3] is ', id[3], ' mismatch');
      return -13;
    }
  return auth_uid;
}
;


create function "oMail_NORM" (in value any) returns varchar
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


create function "oMail_GET_CONFIG" (in detcol_id integer, out mdomain_id integer, out muser_id integer, out mfolder_id integer, out mnamefmt varchar) returns integer
{
  declare md,mu,mf varchar;
  -- dbg_obj_princ ('oMail_GET_CONFIG (', detcol_id, '...)');
  whenever not found goto nf;
  if (isarray (detcol_id))
    return -20;
  select "oMail_NORM" (PROP_VALUE) into md from WS.WS.SYS_DAV_PROP where PROP_NAME = 'virt:oMail-DomainId' and PROP_PARENT_ID = detcol_id and PROP_TYPE = 'C';
  -- dbg_obj_princ ('virt:oMail-DomainId = ', md);
  mdomain_id := cast (md as integer);
  select "oMail_NORM" (PROP_VALUE) into mu from WS.WS.SYS_DAV_PROP where PROP_NAME = 'virt:oMail-UserName' and PROP_PARENT_ID = detcol_id and PROP_TYPE = 'C';
  -- dbg_obj_princ ('virt:oMail-UserName = ', mu);
  select U_ID into muser_id from WS.WS.SYS_DAV_USER where U_NAME = mu;
  select "oMail_NORM" (PROP_VALUE) into mf from WS.WS.SYS_DAV_PROP where PROP_NAME = 'virt:oMail-FolderName' and PROP_PARENT_ID = detcol_id and PROP_TYPE = 'C';
  -- dbg_obj_princ ('virt:oMail-FolderName = ', mf);
  if ('NULL' = mf)
    mfolder_id := null;
  else
    select FOLDER_ID into mfolder_id from OMAIL.WA.FOLDERS where NAME = mf;
  -- dbg_obj_princ ('Folder-ID = ', mfolder_id);
  select "oMail_NORM" (PROP_VALUE) into mnamefmt from WS.WS.SYS_DAV_PROP where PROP_NAME = 'virt:oMail-NameFormat' and PROP_PARENT_ID = detcol_id and PROP_TYPE = 'C';
  -- dbg_obj_princ ('virt:oMail-NameFormat = ', mnamefmt);
  return 0;
nf:
  return -1;
}
;


create function "oMail_FNMERGE" (in path any, in what char (1), in id integer) returns varchar
{
  declare pairs any;
  if (('F' = what) or ('M' = what))
    return sprintf ('%s - Wm%sId%d', path, what, id);
  pairs := regexp_parse ('^(.*[/])?([^/][^./]*)([^/]*)\044', path, 0);
  if (pairs is null)
    signal ('.....', sprintf ('Internal error: failed "oMail_FNMERGE" (%s, %s, %d)', path, what, id));
  return sprintf ('%s - Wm%sId%d%s', subseq (path, 0, pairs[5]), what, id, subseq (path, pairs[6]));
}
;


create procedure "oMail_FNSPLIT" (in name varchar, in what char (1), out orig_name varchar, out id integer)
{
  declare pairs any;
  declare fname, fext varchar;
  if (('F' = what) or ('M' = what))
    {
      fname := name;
      fext := '';
    }
  else
    {
      pairs := regexp_parse ('^([^/][^./]*)([^/]*)\044', name, 0);
      if (pairs is null)
        signal ('.....', sprintf ('Internal error: failed "oMail_FNSPLIT" (%s)', name));
      fname := subseq (name, pairs[2], pairs[3]);
      fext := subseq (name, pairs[4], pairs[5]);
    }
  -- dbg_obj_princ ('oMail_FNSPLIT of ', name, ' of type ', what, ': fname = ', fname, ', fext = ', fext);
  pairs := regexp_parse ('^(.*) - Wm' || what || 'Id([1-9][0-9]*)\044', fname, 0);
  if (pairs is null)
    {
      orig_name := fname || fext;
      id := null;
    }
  else
    {
      orig_name := subseq (fname, pairs[2], pairs[3]) || fext;
      id := cast (subseq (fname, pairs[4], pairs[5]) as integer);
    }
}
;


create function "oMail_FIXNAME" (in mailname any) returns varchar
{
  return replace (replace (replace (mailname, '/', '_'), '\\', '_'), ':', '_');
}
;


create function "oMail_COMPOSE_NAME" (in mnamefmt varchar, in rcv_date datetime, in snd_date datetime, in priority integer, in address any, in subject varchar) returns varchar
{
  --declare fmtlist any;
  declare ctr, len integer;
  declare res varchar;
  --fmtlist := split_and_decode (mnamefmt, 0, '%+^');
  res := sprintf ('%s %s',
    cast (xquery_eval('let \044f := /addres_list/from return if (\044f/name/text()) then \044f/name/text() else \044f/email/text()', xtree_doc (address)) as varchar),
    cast (subject as varchar) );
  return "oMail_FIXNAME" (res);
}
;


create function "oMail_DAV_SEARCH_ID_IMPL" (in detcol_id any, in path_parts any, in what char(1), inout mdomain_id integer, inout muser_id integer, inout mfolder_id integer, inout mnamefmt varchar) returns any
{
  declare colpath, merged_fnameext, orig_fnameext varchar;
  declare orig_id, ctr, len integer;
  declare hitlist any;
  -- dbg_obj_princ ('oMail_DAV_SEARCH_ID_IMPL (', detcol_id, path_parts, what, ')');
  if (not isstring (mnamefmt))
    {
      if (0 > "oMail_GET_CONFIG" (detcol_id, mdomain_id, muser_id, mfolder_id, mnamefmt))
	{
	  -- dbg_obj_princ ('broken mail folder - no items');
	  return -1;
	}
    }
  if (0 = length(path_parts))
    {
      if ('C' <> what)
	{
	  -- dbg_obj_princ ('resource with empty path - no items');
	  return -1;
	}
      return vector (UNAME'oMail', detcol_id, mdomain_id, muser_id, mfolder_id, -1);
    }
  if ('' = path_parts[length(path_parts) - 1])
    {
      if ('C' <> what)
        {
	  -- dbg_obj_princ ('resource without a name - no items');
	  return -1;
        }
    }
  else
    {
      if ('R' <> what)
        {
	  -- dbg_obj_princ ('non-resource with a name - no items');
	  return -1;
        }
    }
  len := length (path_parts) - 1;
  ctr := 0;
  while (ctr < len)
    {
      "oMail_FNSPLIT" (path_parts[ctr], 'F', orig_fnameext, orig_id);
      -- dbg_obj_princ (path_parts[ctr], orig_fnameext, orig_id);
      hitlist := vector ();
      for select FOLDER_ID from OMAIL.WA.FOLDERS
        where
          (DOMAIN_ID = mdomain_id) and
          (USER_ID = muser_id) and
          ((mfolder_id is null and PARENT_ID is null) or (mfolder_id is not null and PARENT_ID = mfolder_id)) and
          ((orig_id is null) or (FOLDER_ID = orig_id)) and
          ("oMail_FIXNAME" (NAME) = orig_fnameext)
      do
        {
        hitlist := vector_concat (hitlist, vector (FOLDER_ID));
        }
      if (length (hitlist) <> 1)
	return -1;
      mfolder_id := hitlist[0];
      ctr := ctr + 1;
    }
  if ('C' = what)
    {
      return vector (UNAME'oMail', detcol_id, mdomain_id, muser_id, mfolder_id, -1);
    }
  if (mfolder_id is null)
    {
      -- dbg_obj_princ ('root of tree of folders can not contain resources - no items');
      return -1;
    }
  merged_fnameext := path_parts[len];
  if ((length (merged_fnameext) <= 4) or (subseq (merged_fnameext, length (merged_fnameext) - 4) <> '.eml'))
    {
      -- dbg_obj_princ ('no eml suffix in ', merged_fnameext, ' - no items');
      return -1;
    }
  "oMail_FNSPLIT" (subseq (merged_fnameext, 0, length (merged_fnameext) - 4), 'M', orig_fnameext, orig_id);
  -- dbg_obj_princ (merged_fnameext, orig_fnameext, orig_id);
  hitlist := vector ();
  for select MSG_ID from OMAIL.WA.MESSAGES
    where
      (DOMAIN_ID = mdomain_id) and
      (USER_ID = muser_id) and
      (FOLDER_ID = mfolder_id) and
      ((orig_id is null) or (MSG_ID = orig_id)) and
      ("oMail_COMPOSE_NAME" (mnamefmt, RCV_DATE, SND_DATE, PRIORITY, ADDRESS, SUBJECT) = orig_fnameext)
    do
      {
        hitlist := vector_concat (hitlist, vector (MSG_ID));
      }
  if (length (hitlist) <> 1)
    return -1;
  return vector (UNAME'oMail', detcol_id, mdomain_id, muser_id, mfolder_id, hitlist[0]);
}
;


create function "oMail_DAV_AUTHENTICATE_HTTP" (in id any, in what char(1), in req varchar, in can_write_http integer, inout a_lines any, inout a_uname varchar, inout a_pwd varchar, inout a_uid integer, inout a_gid integer, inout _perms varchar) returns integer
{
  declare rc integer;
  declare puid, pgid, ruid, rgid integer;
  declare u_password, pperms varchar;
  -- anon are never allowed for mails! declare allow_anon integer;
  if (length (req) <> 3)
    return -15;

  whenever not found goto nf_col_or_res;
  if ((what <> 'R') and (what <> 'C'))
    return -14;
  -- allow_anon := WS.WS.PERM_COMP (substring (cast (pperms as varchar), 7, 3), req);
  if (a_uid is null)
    {
      -- if ((not allow_anon) or ('' <> WS.WS.FINDPARAM (a_lines, 'Authorization:')))
      rc := WS.WS.GET_DAV_AUTH (a_lines, 0, can_write_http, a_uname, u_password, a_uid, a_gid, _perms);
      if (rc < 0)
        return rc;
    }
  if (isinteger (a_uid))
    {
      if (a_uid < 0)
	return a_uid;
     if (a_uid = 1) -- Anonymous FTP
	{
          a_uid := http_nobody_uid ();
	  a_gid := http_nogroup_gid ();
	}
    }
  if ((a_uid <> id[3]) and (a_uid <> http_dav_uid()))
    {
      -- dbg_obj_princ ('a_uid is ', a_uid, ', id[3] is ', id[3], ' mismatch');
      return -13;
    }
  if (not ('100' like req))
    return -13;
  return a_uid;

nf_col_or_res:
  return -1;
}
;

create function "oMail_DAV_GET_PARENT" (in id any, in st char(1), in path varchar) returns any
{
  -- dbg_obj_princ ('oMail_DAV_GET_PARENT (', id, st, path, ')');
  return -20;
}
;

create function "oMail_DAV_COL_CREATE" (in detcol_id any, in path_parts any, in permissions varchar, in uid integer, in gid integer, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('oMail_DAV_COL_CREATE (', detcol_id, path_parts, permissions, uid, gid, auth_uid, ')');
  return -20;
}
;

create function "oMail_DAV_COL_MOUNT" (in detcol_id any, in path_parts any, in full_mount_path varchar, in mount_det varchar, in permissions varchar, in uid integer, in gid integer, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('oMail_DAV_COL_MOUNT (', detcol_id, path_parts, full_mount_path, mount_det, permissions, uid, gid, auth_uid, ')');
  return -20;
}
;

create function "oMail_DAV_COL_MOUNT_HERE" (in parent_id any, in full_mount_path varchar, in permissions varchar, in uid integer, in gid integer, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('oMail_DAV_COL_MOUNT (', parent_id, full_mount_path, permissions, uid, gid, auth_uid, ')');
  return -20;
}
;

create function "oMail_DAV_DELETE" (in detcol_id any, in path_parts any, in what char(1), in silent integer, in auth_uid integer) returns integer
{
  return -20;
}
;

create function "oMail_DAV_RES_UPLOAD" (in detcol_id any, in path_parts any, inout content any, in type varchar, in permissions varchar, in uid integer, in gid integer, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('oMail_DAV_RES_UPLOAD (', detcol_id, path_parts, ', [content], ', type, permissions, uid, gid, auth_uid, ')');
  return -20;
}
;

create function "oMail_DAV_PROP_REMOVE" (in id any, in st char(0), in propname varchar, in silent integer, in auth_uid integer) returns integer
{
  -- dbg_obj_princ ('oMail_DAV_PROP_REMOVE (', id, st, propname, silent, auth_uid, ')');
  return -20;
}
;

create function "oMail_DAV_PROP_SET" (in id any, in st char(0), in propname varchar, in propvalue any, in overwrite integer, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('oMail_DAV_PROP_SET (', id, st, propname, propvalue, overwrite, auth_uid, ')');
  if (propname[0] = 58)
    {
      return -16;
    }
  return -20;
}
;

create function "oMail_DAV_PROP_GET" (in id any, in what char(0), in propname varchar, in auth_uid integer)
{
  -- dbg_obj_princ ('oMail_DAV_PROP_GET (', id, what, propname, auth_uid, ')');
  return -11;
}
;

create function "oMail_DAV_PROP_LIST" (in id any, in what char(0), in propmask varchar, in auth_uid integer)
{
  -- dbg_obj_princ ('oMail_DAV_PROP_LIST (', id, what, propmask, auth_uid, ')');
  return vector ();
}
;


create function "oMail_COLNAME_OF_FOLDER" (in mdomain_id integer, in muser_id integer, in f_id integer) returns any
{
  for select "oMail_FIXNAME" (NAME) as orig_name, PARENT_ID as f1_PARENT_ID
    from OMAIL.WA.FOLDERS f1
    where
      DOMAIN_ID = mdomain_id and
      USER_ID = muser_id and
      FOLDER_ID = f_id
    do
      {
	declare merged varchar;
	-- dbg_obj_princ ('oMail_COLNAME_OF_FOLDER has found ', orig_name, ' for folder ', f_id, ' of ', mdomain_id, ' owned by ', muser_id);
	if (regexp_parse (' - Wm.Id[1-9][0-9]*(.[^/]*)?\044', orig_name, 0) -- Suspicious names should be qualified
	  or
	  exists (
          select 1
	  from OMAIL.WA.FOLDERS f2
	  where
	    DOMAIN_ID = mdomain_id and
	    USER_ID = muser_id and
	    FOLDER_ID <> f_id and
	    ((f1_PARENT_ID is null and f2.PARENT_ID is null) or (f1_PARENT_ID = f2.PARENT_ID)) and
	    ("oMail_FIXNAME" (f2.NAME) = orig_name) ) )
	  {
	    return "oMail_FNMERGE" (orig_name, 'F', f_id);
	  }
	return orig_name;
      }
  return -1;
}
;

create function "oMail_RESNAME_OF_MAIL" (in mdomain_id integer, in muser_id integer, in f_id integer, in m_id integer, in mnamefmt varchar) returns any
{
  for select RCV_DATE as m1_RCV_DATE, DSIZE as m1_DSIZE,
    "oMail_COMPOSE_NAME" (mnamefmt, m1.RCV_DATE, SND_DATE, PRIORITY, ADDRESS, SUBJECT) as orig_name
  from OMAIL.WA.MESSAGES m1
  where
    DOMAIN_ID = mdomain_id and
    USER_ID = muser_id and
    FOLDER_ID = f_id and
    m1.MSG_ID = m_id
  do
    {
      declare merged varchar;
      -- dbg_obj_princ ('About to form RESNAME_OF_MAIL: ', orig_name, m_id);
      if (regexp_parse (' - Wm.Id[1-9][0-9]*(.[^/]*)?\044', orig_name, 0) -- Suspicious names should be qualified
        or
        exists (
          select 1
	  from OMAIL.WA.MESSAGES m2
	  where
	    DOMAIN_ID = mdomain_id and
	    USER_ID = muser_id and
	    FOLDER_ID = f_id and
	    m2.MSG_ID <> m_id and
	    "oMail_COMPOSE_NAME" (mnamefmt, RCV_DATE, SND_DATE, PRIORITY, ADDRESS, SUBJECT) = orig_name ) )
	{
          return "oMail_FNMERGE" (orig_name, 'M', m_id);
        }
      return orig_name;
     }
  return -1;
}
;

create function "oMail_DAV_DIR_SINGLE" (in id any, in what char(0), in path any, in auth_uid integer) returns any
{
  declare mnamefmt varchar;
  declare f_id integer;
  declare fullpath, rightcol, resname varchar;
  -- dbg_obj_princ ('oMail_DAV_DIR_SINGLE (', id, what, path, auth_uid, ')');
  f_id := id[4];
  fullpath := '';
  rightcol := NULL;
  while (f_id is not null)
    {
      declare colname varchar;
      colname := "oMail_COLNAME_OF_FOLDER" (id[2], id[3], f_id);
      if (DAV_HIDE_ERROR (colname) is null)
        return -1;
      if (rightcol is null)
        rightcol := colname;
      fullpath := colname || '/' || fullpath;
      f_id := coalesce ((select PARENT_ID from OMAIL.WA.FOLDERS where DOMAIN_ID = id[2] and USER_ID = id[3] and FOLDER_ID = f_id));
    }
  fullpath := DAV_CONCAT_PATH (DAV_SEARCH_PATH (id[1], 'C'), fullpath);
  if ('C' = what)
    {
      declare maxrcvdate datetime;
      if (id[5] >= 0)
	return -1;
      maxrcvdate := coalesce ((select max(RCV_DATE)
          from OMAIL.WA.MESSAGES
          where
	    DOMAIN_ID = id[2] and
	    USER_ID = id[3] and
	    FOLDER_ID = id[4]),
	  cast ('1980-01-01' as datetime) );
--                   0         1    2  3
      return vector (fullpath, 'C', 0, maxrcvdate,
--       4   5             6  7      8           9                     10
	 id, '100000000NN', 0, id[3], maxrcvdate, 'dav/unix-directory', rightcol );
    }
  declare mdomain_id, muser_id, mfolder_id integer;
  if (0 > "oMail_GET_CONFIG" (id[1], mdomain_id, muser_id, mfolder_id, mnamefmt))
    return -1;
  resname := "oMail_RESNAME_OF_MAIL" (mdomain_id, muser_id, id[4], id[5], mnamefmt);
  if (DAV_HIDE_ERROR (resname) is null)
    return -1;
  for select RCV_DATE as m1_RCV_DATE, DSIZE as m1_DSIZE
  from OMAIL.WA.MESSAGES m1
  where
    DOMAIN_ID = id[2] and
    USER_ID = id[3] and
    FOLDER_ID = id[4] and
    m1.MSG_ID = id[5]
  do
    {
--                   0                              1    2         3
      return vector (fullpath || resname || '.eml', 'R', m1_DSIZE, m1_RCV_DATE,
--      4   5              6  7      8            9             10
	id, '100000000NN', 0, id[3], m1_RCV_DATE, 'text/plain', resname || '.eml' );
    }
  return -1;
}
;

create function "oMail_DAV_DIR_LIST" (in detcol_id any, in path_parts any, in detcol_path varchar, in name_mask varchar, in recursive integer, in auth_uid integer) returns any
{
  declare mdomain_id, muser_id, mfolder_id integer;
  declare mnamefmt varchar;
  declare top_davpath, prev_raw_name varchar;
  declare res, grand_res any;
  declare reslen, prev_is_patched integer;
  declare top_id any;
  declare what char (1);
  -- dbg_obj_princ ('oMail_DAV_DIR_LIST (', detcol_id, path_parts, detcol_path, name_mask, recursive, auth_uid, ')');
  mnamefmt := null;
  if (0 > "oMail_GET_CONFIG" (detcol_id, mdomain_id, muser_id, mfolder_id, mnamefmt))
    {
      -- dbg_obj_princ ('broken collection description - no items');
      return vector();
    }
  if ((0 = length (path_parts)) or ('' = path_parts[length (path_parts) - 1]))
    what := 'C';
  else
    what := 'R';
  if (('C' = what) and (1 = length (path_parts)))
    top_id := vector (UNAME'oMail', detcol_id, mdomain_id, muser_id, mfolder_id, -1); -- may be a fake id because top_id[4] may be NULL
  else
    top_id := "oMail_DAV_SEARCH_ID_IMPL" (detcol_id, path_parts, what, mdomain_id, muser_id, mfolder_id, mnamefmt);
  -- dbg_obj_princ ('found top_id ', top_id, ' of type ', what);
  if (DAV_HIDE_ERROR (top_id) is null)
    {
      -- dbg_obj_princ ('no top id - no items');
      return vector();
    }
  top_davpath := DAV_CONCAT_PATH (detcol_path, path_parts);
  if ('R' = what)
    {
      return vector ("oMail_DAV_DIR_SINGLE" (top_id, what, top_davpath, auth_uid));
    }
  res := vector();
  reslen := 0;
  prev_raw_name := '';
  prev_is_patched := 1; -- to prevent from patching minus-first elt of res
  for select "oMail_FIXNAME" (NAME) as orig_name, FOLDER_ID as f_id
    from OMAIL.WA.FOLDERS
    where
      DOMAIN_ID = mdomain_id and
      USER_ID = muser_id and
      ((PARENT_ID is null and top_id[4] is null) or (PARENT_ID = top_id[4]))
    order by 1, 2
  do
    {
      declare merged varchar;
      -- dbg_obj_princ ('about to put col to dir list: ', orig_name, ' for folder ', f_id, ' of ', mdomain_id, ' owned by ', muser_id);
      if (regexp_parse (' - Wm.Id[1-9][0-9]*(.[^/]*)?\044', orig_name, 0)) -- Suspicious names should be qualified
        {
          merged := "oMail_FNMERGE" (orig_name, 'F', f_id);
          prev_is_patched := 1; -- The current one is with merging for sure.
	  -- dbg_obj_princ ('Suspicious -- made merged');
        }
      else if (orig_name = prev_raw_name)
        {
          merged := "oMail_FNMERGE" (orig_name, 'F', f_id);
          if (not prev_is_patched) -- The first record in a sequence of namesakes is written w/o merging, go fix it
            {
              declare prev_id integer;
	      declare prev_merged varchar;
              prev_id := res[reslen-1][4][4];
              prev_merged := "oMail_FNMERGE" (orig_name, f_id);
              res[reslen-1][10] := prev_merged;
              res[reslen-1][0] := DAV_CONCAT_PATH (top_davpath, prev_merged);
	      -- dbg_obj_princ ('Both current and prev namesake are merged', f_id, prev_id);
            }
          prev_is_patched := 1; -- The current one is with merging for sure.
        }
      else
        {
          merged := orig_name;
          prev_is_patched := 0;
          -- dbg_obj_princ ('Current is not merged');
        }
      declare maxrcvdate datetime;
      maxrcvdate := coalesce ((select max(RCV_DATE)
          from OMAIL.WA.MESSAGES
          where
	    DOMAIN_ID = mdomain_id and
	    USER_ID = muser_id and
	    FOLDER_ID = f_id),
	  cast ('1980-01-01' as datetime) );
--                                               0                                             1    2  3
      res := vector_concat (res, vector (vector (DAV_CONCAT_PATH (top_davpath, merged) || '/', 'C', 0, maxrcvdate,
--       4
	 vector (UNAME'oMail', detcol_id, mdomain_id, muser_id, f_id, -1),
--       5              6  7         8           9                     10
	 '100000000NN', 0, muser_id, maxrcvdate, 'dav/unix-directory', merged ) ) );
     }
  grand_res := res;
-- retrieval of mails
  if (mfolder_id is null)
    goto end_of_mails; -- there are no mails in root.
  res := vector();
  reslen := 0;
  prev_raw_name := '';
  prev_is_patched := 1; -- to prevent from patching minus-first elt of res
  for
    select orig_mname, m_id, RCV_DATE, DSIZE
    from (
      select "oMail_COMPOSE_NAME" (mnamefmt, RCV_DATE, SND_DATE, PRIORITY, ADDRESS, SUBJECT) as orig_mname,
        MSG_ID as m_id, RCV_DATE, DSIZE
      from OMAIL.WA.MESSAGES
      where
        DOMAIN_ID = mdomain_id and
        USER_ID = muser_id and
        FOLDER_ID = top_id[4] ) m1
    where orig_mname like name_mask
    order by 1, 2
  do
    {
      declare merged varchar;
      -- dbg_obj_princ ('About to put in dir list: ', orig_mname, m_id);
      if (regexp_parse (' - Wm.Id[1-9][0-9]*(.[^/]*)?\044', orig_mname, 0)) -- Suspicious names should be qualified
        {
          merged := "oMail_FNMERGE" (orig_mname, 'M', m_id);
          prev_is_patched := 1; -- The current one is with merging for sure.
	  -- dbg_obj_princ ('Suspicious -- made merged');
        }
      else if (orig_mname = prev_raw_name)
        {
          merged := "oMail_FNMERGE" (orig_mname, 'M', m_id);
          if (not prev_is_patched) -- The first record in a sequence of namesakes is written w/o merging, go fix it
            {
              declare prev_id integer;
	      declare prev_merged varchar;
              prev_id := res[reslen-1][4][5];
              prev_merged := "oMail_FNMERGE" (orig_mname, 'M', prev_id);
              res[reslen-1][10] := prev_merged || '.eml';
              res[reslen-1][0] := DAV_CONCAT_PATH (top_davpath, prev_merged || '.eml');
	      -- dbg_obj_princ ('Both current and prev namesake are merged', m_id, prev_id);
            }
          prev_is_patched := 1; -- The current one is with merging for sure.
        }
      else
        {
          merged := orig_mname;
          prev_is_patched := 0;
          -- dbg_obj_princ ('Current is not merged');
        }
--                                               0                                                1    2      3
      res := vector_concat (res, vector (vector (DAV_CONCAT_PATH (top_davpath, merged) || '.eml', 'R', DSIZE, RCV_DATE,
--      4
        vector (UNAME'oMail', detcol_id, mdomain_id, muser_id, top_id[4], m_id),
--      5              6  7         8         9             10
        '100000000NN', 0, muser_id, RCV_DATE, 'text/plain', merged || '.eml' ) ) );
      prev_raw_name := orig_mname;
      reslen := reslen + 1;
    }
  grand_res := vector_concat (grand_res, res);

end_of_mails:
  return grand_res;
}
;

create procedure "oMail_DAV_FC_PRED_METAS" (inout pred_metas any)
{
  pred_metas := vector (
    'DOMAIN_ID',		vector ('MESSAGES'	, 0, 'integer'	, 'DOMAIN_ID'	),
    'MSG_ID',		vector ('MESSAGES'	, 0, 'integer'	, 'MSG_ID'	),
    'RES_NAME',			vector ('MESSAGES'		, 0, 'varchar'	, 'concat("oMail_COMPOSE_NAME" (NULL, RCV_DATE, SND_DATE, PRIORITY, ADDRESS, SUBJECT), ''.eml'')'	),
    'RES_FULL_PATH',		vector ('MESSAGES'	, 0, 'varchar'	, 'concat (_param.detcolpath, "oMail_COMPOSE_NAME" (NULL, RCV_DATE, SND_DATE, PRIORITY, ADDRESS, SUBJECT), ''.eml'')'	),
    'RES_TYPE',      vector ('MESSAGES'  , 0, 'varchar'  , '(''text/html'')'  ),
    'RES_OWNER_ID',		vector ('SYS_DAV_USERS'	, 0, 'integer'	, 'U_ID'	),
    'RES_OWNER_NAME',		vector ('SYS_DAV_USERS'	, 0, 'varchar'	, 'U_NAME'	),
    'RES_GROUP_ID',		vector ('MESSAGES'	, 0, 'integer'	, 'http_nogroup_gid()'	),
    'RES_GROUP_NAME',		vector ('MESSAGES'	, 0, 'varchar'	, '(''nogroup'')'	),
    'RES_COL_FULL_PATH',	vector ('MESSAGES'	, 0, 'varchar'	, 'DAV_CONCAT_PATH (_param.detcolpath)'	),
    'RES_COL_NAME',		vector ('MESSAGES'	, 0, 'varchar'	, '"oMail_COLNAME_OF_FOLDER" (DOMAIN_ID, USER_ID, FOLDER_ID)'	),
    'RES_CR_TIME',		vector ('MESSAGES'	, 0, 'datetime'	, 'coalesce (RCV_DATE, SND_DATE)'	),
    'RES_MOD_TIME',		vector ('MESSAGES'	, 0, 'datetime'	, 'coalesce (RCV_DATE, SND_DATE)'	),
    'RES_PERMS',		vector ('MESSAGES'	, 0, 'varchar'	, '(''110000000RR'')'	),
    'RES_CONTENT',		vector ('MSG_PARTS'	, 0, 'text'	, 'TDATA'	),
    'PROP_NAME',    vector ('MSG_PARTS'  , 0, 'varchar'  , '(''Content'')'  ),
    'PROP_VALUE',    vector ('MSG_PARTS'  , 1, 'text'  , 'TDATA'  ),
    'RES_TAGS',			vector ('MESSAGES'	, 0, 'varchar'  , '('''')'	), -- 'varchar', not 'text-tag' because there's no free-text on union
    'RES_PUBLIC_TAGS',		vector ('MESSAGES'	, 0, 'varchar'	, '('''')'	),
    'RES_PRIVATE_TAGS',		vector ('MESSAGES'	, 0, 'varchar'	, '('''')'	),
    'RDF_PROP',			vector ('MESSAGES'	, 1, 'varchar'	, NULL	),
    'RDF_VALUE',		vector ('MESSAGES'	, 2, 'XML'	, NULL	),
    'RDF_OBJ_VALUE',		vector ('MESSAGES'	, 3, 'XML'	, NULL	)
    );
}
;

create procedure "oMail_DAV_FC_TABLE_METAS" (inout table_metas any)
{
  table_metas := vector (
    'MESSAGES'	, vector (	''	, ''	,
				'ADDRESS'	, 'ADDRESS'	, '[__quiet] /'	),
    'FOLDERS'	, vector (	'\n  inner join OMAIL.WA.FOLDERS as ^{alias}^ on ((^{alias}^.DOMAIN_ID = _top.DOMAIN_ID) and (^{alias}^.USER_ID = _top.USER_ID) and (^{alias}^.FOLDER_ID = _top.FOLDER_ID)^{andpredicates}^)'	,
				'\n  exists (select 1 from OMAIL.WA.FOLDERS as ^{alias}^ on ((^{alias}^.DOMAIN_ID = _top.DOMAIN_ID) and (^{alias}^.USER_ID = _top.USER_ID) and (^{alias}^.FOLDER_ID = _top.FOLDER_ID)^{andpredicates}^)'	,
				'ADDRESS'	, 'ADDRESS'	, '[__quiet] /'	),
    'MSG_PARTS'	, vector (	'\n  inner join OMAIL.WA.MSG_PARTS as ^{alias}^ on ((^{alias}^.DOMAIN_ID = _top.DOMAIN_ID) and (^{alias}^.USER_ID = _top.USER_ID) and (^{alias}^.MSG_ID = _top.MSG_ID)^{andpredicates}^)'	,
				'\n  exists (select 1 from OMAIL.WA.MSG_PARTS as ^{alias}^ on ((^{alias}^.DOMAIN_ID = _top.DOMAIN_ID) and (^{alias}^.USER_ID = _top.USER_ID) and (^{alias}^.MSG_ID = _top.MSG_ID)^{andpredicates}^)'	,
				'TDATA'		, 'TDATA'	, '[__quiet] /'	),
    'SYS_DAV_USER', vector (	'\n  left outer join WS.WS.SYS_DAV_USER as ^{alias}^ on ((^{alias}^.U_ID = _top.USER_ID)^{andpredicates}^)'	,
					'\n  exists (select 1 from WS.WS.SYS_DAV_USER as ^{alias}^ where (^{alias}^.U_ID = _top.USER_ID)^{andpredicates}^)'	,
						NULL		, NULL		, NULL	)
    );
}
;

-- This prints the fragment that starts after 'FROM WS.WS.SYS_BLOGS' and contains the rest of FROM and whole 'WHERE'
create function "oMail_DAV_FC_PRINT_WHERE" (inout filter any, in param_uid integer) returns varchar
{
  declare pred_metas, cmp_metas, table_metas any;
  declare used_tables any;
  -- dbg_obj_princ ('Blog_POST_DAV_FC_PRINT_WHERE (', filter, param_uid, ')');
  "oMail_DAV_FC_PRED_METAS" (pred_metas);
  DAV_FC_CMP_METAS (cmp_metas);
  "oMail_DAV_FC_TABLE_METAS" (table_metas);
  used_tables := vector (
    'MESSAGES', vector ('MESSAGES', '_top', null, vector (), vector (), vector ()),
    'MSG_PARTS', vector ('MSG_PARTS', '_top2', null, vector (), vector (), vector ()),
    'SYS_DAV_USER', vector ('SYS_DAV_USER', '_owners', null, vector (), vector (), vector ())
    );
  return DAV_FC_PRINT_WHERE_INT (filter, pred_metas, cmp_metas, table_metas, used_tables, param_uid);
}
;

create function "oMail_DAV_DIR_FILTER" (in detcol_id any, in path_parts any, in detcol_path varchar, in compilation varchar, in recursive integer, in auth_uid integer) returns any
{
  declare st, access, qry_text, execstate, execmessage varchar;
  declare mdomain_id, muser_id, mfolder_id integer;
  declare mnamefmt varchar;
  declare res any;
	declare cond_list, execmeta, execrows any;
  declare condtext varchar;
  vectorbld_init (res);
  --dbg_obj_princ ('oMail_DAV_DIR_FILTER (', detcol_id, path_parts, detcol_path, compilation, recursive, auth_uid, ')');
  if (0 > "oMail_GET_CONFIG" (detcol_id, mdomain_id, muser_id, mfolder_id, mnamefmt))
    {
      -- dbg_obj_princ ('broken collection description - no items');
      return vector();
    }
  if (((length (path_parts) <= 1) and (recursive <> 1)) or (length (path_parts) > 2))
    goto finalize;
  if (length (path_parts) >= 2)
    {
      --blog_id := coalesce ((select BI_BLOG_ID from BLOG.DBA.SYS_BLOG_OWNERS where U_ID = owner_uid and "Blog_FIXNAME" (WAI_NAME) = path_parts[0]));
      --if (blog_id is null)
        goto finalize;
    }
  condtext := get_keyword ('Blog_POST', compilation);
  if (condtext is null)
    {
      cond_list := get_keyword ('', compilation);
			--dbg_obj_princ ('\r\ncond_list ', cond_list, '\r\n');
      --if (blog_id is not null)
      --  cond_list := vector_concat (cond_list, vector ( vector ('B_BLOG_ID', '=', blog_id)));
      condtext := "oMail_DAV_FC_PRINT_WHERE" (cond_list, auth_uid);
			--dbg_obj_princ ('\r\ncondtext2 ', condtext, '\r\n');
      --compilation := vector_concat (compilation, vector ('Blog_POST', condtext));
			--dbg_obj_princ ('\r\ncompilation ', compilation, '\r\n');
    }
  execstate := '00000';
  qry_text := '
	select
  concat (_param.detcolpath, "oMail_COMPOSE_NAME" (NULL, _top.RCV_DATE, _top.SND_DATE, _top.PRIORITY, _top.ADDRESS, _top.SUBJECT), ''.eml''),
  ''R'', _top.DSIZE, _top.RCV_DATE,
  vector (UNAME\'oMail\', ?, _top.DOMAIN_ID, _top.USER_ID, _top.FOLDER_ID, _top.MSG_ID),
  ''110000000RR'', http_nogroup_gid(), _top.USER_ID, _top.RCV_DATE, ''text/plain'', concat( "oMail_COMPOSE_NAME" (NULL, _top.RCV_DATE, _top.SND_DATE, _top.PRIORITY, _top.ADDRESS, _top.SUBJECT), ''.eml'')
	from
  (select top 1 ? as detcolpath from WS.WS.SYS_DAV_COL) as _param,
  OMAIL.WA.MESSAGES as _top
	join WS.WS.SYS_DAV_USER as _owners on (USER_ID = ? and USER_ID = U_ID and FOLDER_ID = ?) 
	join OMAIL.WA.MSG_PARTS as _top2 on (_top2.MSG_ID = _top.MSG_ID and _top2.USER_ID = U_ID)
  ' || condtext;
  --dbg_obj_princ ('\r\nCollection of messages: ', qry_text, '\r\n');
  
  exec (qry_text, execstate, execmessage,
	  vector (detcol_id, detcol_path, muser_id, mfolder_id),
    100000000, execmeta, execrows );
  --dbg_obj_princ ('Collection of blog posts: execstate = ', execstate, ', execmessage = ', execmessage);
  if ('00000' <> execstate)
  	signal (execstate, execmessage || ' in ' || qry_text);
  vectorbld_concat_acc (res, execrows);

  finalize: ;
  vectorbld_final (res);
  return res;
}
;


create function "oMail_DAV_SEARCH_ID" (in detcol_id any, in path_parts any, in what char(1)) returns any
{
  declare mdomain_id, muser_id, mfolder_id integer;
  declare mnamefmt varchar;
  declare orig_id integer;
  -- dbg_obj_princ ('oMail_DAV_SEARCH_ID (', detcol_id, path_parts, what, ')');
  mnamefmt := null;
  return "oMail_DAV_SEARCH_ID_IMPL" (detcol_id, path_parts, what, mdomain_id, muser_id, mfolder_id, mnamefmt);
}
;

create function "oMail_DAV_SEARCH_PATH" (in id any, in what char(1)) returns any
{
  declare mnamefmt varchar;
  declare f_id integer;
  declare fullpath, rightcol, resname varchar;
  -- dbg_obj_princ ('oMail_DAV_SEARCH_PATH (', id, what, ')');
  f_id := id[4];
  fullpath := '';
  rightcol := NULL;
  while (f_id is not null)
    {
      declare colname varchar;
      colname := "oMail_COLNAME_OF_FOLDER" (id[2], id[3], f_id);
      if (DAV_HIDE_ERROR (colname) is null)
        {
          -- dbg_obj_princ ('Failed to compose oMail_COLNAME_OF_FOLDER (', id[2], id[3], f_id, ') : ', colname);
          return -1;
        }
      if (rightcol is null)
        rightcol := colname;
      fullpath := colname || '/' || fullpath;
      f_id := coalesce ((select PARENT_ID from OMAIL.WA.FOLDERS where DOMAIN_ID = id[2] and USER_ID = id[3] and FOLDER_ID = f_id));
    }
  fullpath := DAV_CONCAT_PATH (DAV_SEARCH_PATH (id[1], 'C'), fullpath);
  if ('C' = what)
    {
      return fullpath;
    }
  declare mdomain_id, muser_id, mfolder_id integer;
  if (0 > "oMail_GET_CONFIG" (id[1], mdomain_id, muser_id, mfolder_id, mnamefmt))
    {
      -- dbg_obj_princ ('Failed to get config for detcol ', id[1]);
      return -1;
    }
  resname := "oMail_RESNAME_OF_MAIL" (mdomain_id, muser_id, id[4], id[5], mnamefmt);
  if (DAV_HIDE_ERROR (resname) is null)
    {
      -- dbg_obj_princ ('Failed to compose oMail_RESNAME_OF_MAIL (', mdomain_id, muser_id, id[4], id[5], mnamefmt, ') : ', resname);
      return -1;
    }
  return fullpath || resname || '.eml';
}
;

create function "oMail_DAV_RES_UPLOAD_COPY" (in detcol_id any, in path_parts any, in source_id any, in what char(1), in overwrite integer, in permissions varchar, in uid integer, in gid integer, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('oMail_DAV_RES_UPLOAD_COPY (', detcol_id, path_parts, source_id, what, overwrite, permissions, uid, gid, auth_uid, ')');
  return -20;
}
;

create function "oMail_DAV_RES_UPLOAD_MOVE" (in detcol_id any, in path_parts any, in source_id any, in what char(1), in overwrite integer, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('oMail_DAV_RES_UPLOAD_MOVE (', detcol_id, path_parts, source_id, what, overwrite, auth_uid, ')');
  return -20;
}
;

create function "oMail_DAV_RES_CONTENT" (in id any, inout content any, out type varchar, in content_mode integer) returns any
{
  declare cont any;
  -- dbg_obj_princ ('oMail_DAV_RES_CONTENT (', id, ', [content], [type], ', content_mode, ')');
  type := 'text/plain';
  if ((content_mode = 0) or (content_mode = 2))
    {
      --content := string_output();
      content := OMAIL.WA.omail_message_body(id[2], id[3], id[5]);
      --OMAIL.WA.omail_prepare_eml (id[2], id[3], id[5], cont);
      -- dbg_obj_princ ('OMAIL.WA.omail_prepare_eml is finished (1)');
      -- dbg_obj_princ (string_output_string (cont));
      --content := string_output_string (cont);
    }
  else if (content_mode = 1)
    {
			content := OMAIL.WA.omail_message_body(id[2], id[3], id[5]);
      --OMAIL.WA.omail_prepare_eml (id[2], id[3], id[5], content);
      -- dbg_obj_princ ('OMAIL.WA.omail_prepare_eml is finished (2)');
    }
  else if (content_mode = 3)
    {
			content := OMAIL.WA.omail_message_body(id[2], id[3], id[5]);
      cont := string_output();
			http(content, cont); 
      --OMAIL.WA.omail_prepare_eml (id[2], id[3], id[5], cont);
      -- dbg_obj_princ ('OMAIL.WA.omail_prepare_eml is finished (3)');
      http (cont);
    }
  return 0;
}
;

create function "oMail_DAV_SYMLINK" (in detcol_id any, in path_parts any, in source_id any, in what char(1), in overwrite integer, in uid integer, in gid integer, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('oMail_DAV_SYMLINK (', detcol_id, path_parts, source_id, overwrite, uid, gid, auth_uid, ')');
  return -20;
}
;

create function "oMail_DAV_LOCK" (in path any, in id any, in type char(1), inout locktype varchar, inout scope varchar, in token varchar, inout owner_name varchar, inout owned_tokens varchar, in depth varchar, in timeout_sec integer, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('oMail_DAV_LOCK (', path, id, type, locktype, scope, token, owner_name, owned_tokens, depth, timeout_sec, auth_uid, ')');
  return -20;
}
;

create function "oMail_DAV_UNLOCK" (in id any, in type char(1), in token varchar, in auth_uid integer)
{
  -- dbg_obj_princ ('oMail_DAV_UNLOCK (', id, type, token, auth_uid, ')');
  return -20;
}
;

create function "oMail_DAV_IS_LOCKED" (inout id any, inout type char(1), in owned_tokens varchar) returns integer
{
  -- dbg_obj_princ ('oMail_DAV_IS_LOCKED (', id, type, owned_tokens, ')');
  return 0;
}
;

create function "oMail_DAV_LIST_LOCKS" (in id any, in type char(1), in recursive integer) returns any
{
  -- dbg_obj_princ ('oMail_DAV_LIST_LOCKS" (', id, type, recursive);
  return vector ();
}
;



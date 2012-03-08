--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2012 OpenLink Software
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

-------------------------------------------------------------------------------
--
create function DB.DBA.S3__encode (
 in S varchar)
{
  S := sprintf ('%U', S);
  S := replace(S, '''', '%27');
  S := replace(S, '%2F', '/');
  return S;
}
;

-------------------------------------------------------------------------------
--
create function DB.DBA.S3__params (
  in colID integer,
  out bucket varchar,
  out accessCode varchar,
  out secretKey varchar)
{
  bucket := DB.DBA.DAV_PROP_GET_INT (colID, 'C', 'virt:S3-BucketName', 0);
  accessCode := DB.DBA.DAV_PROP_GET_INT (colID, 'C', 'virt:S3-AccessKeyID', 0);
  secretKey := DB.DBA.DAV_PROP_GET_INT (colID, 'C', 'virt:S3-SecretKey', 0);
}
;

-------------------------------------------------------------------------------
--
create function DB.DBA.S3__parts2path (
  in bucket varchar,
  in pathParts any,
  in what any)
{
  -- dbg_obj_princ ('S3__parts2path (', bucket, pathParts, ')');
  declare path varchar;

  path := DB.DBA.DAV_CONCAT_PATH (pathParts, null);
  if ((path <> '') and (chr (path[0]) <> '/'))
    path := '/' || path;
  if (bucket <> '')
    path := '/' || bucket || path;
  -- dbg_obj_princ ('path', path);
  path := rtrim (path, '/') || case when (what = 'C') then '/' end;
  return path;
}
;

-------------------------------------------------------------------------------
--
create function DB.DBA.S3__item2entry (
  in detcolID integer,
  in detcolPath varchar,
  in bucket varchar,
  in item any)
{
  -- dbg_obj_princ ('DB.DBA.S3__item2entry  (', detcolID, detcolPath, bucket, item, ')');
  declare entryPath, entryType varchar;
  declare detcolEntry any;

  if (item is null)
    return null;

  detcolEntry := DB.DBA.DAV_DIR_SINGLE_INT (detcolID, 'C', '', null, null, http_dav_uid ());
  entryPath := get_keyword ('path', item);
  if (not is_empty_or_null (bucket))
    entryPath := subseq (entryPath, length (bucket)+1);

  entryType := get_keyword ('type', item);
  if ('C' = entryType)
    return vector (detcolPath || ltrim (entryPath, '/'),           -- 0  full path
                   entryType,                                      -- 1  type
                   get_keyword ('size', item),                     -- 2  size
                   get_keyword ('updated', item),                  -- 3  modification time
                   vector (UNAME'S3', detcolID, entryPath),        -- 4  id
                   detcolEntry[5],                                 -- 5  permissions
                   detcolEntry[6],                                 -- 6  group
                   detcolEntry[7],                                 -- 7  owner
                   get_keyword ('updated', item),                  -- 8  creation time
                   'dav/unix-directory',                           -- 9  mime type
                   get_keyword ('name', item)                      -- 10 name
                  );
  if ('R' = entryType)
    return vector (detcolPath || ltrim (entryPath, '/'),           -- 0  full path
                   entryType,                                      -- 1  type
                   get_keyword ('size', item),                     -- 2  size
                   get_keyword ('updated', item),                  -- 3  modification time
                   vector (UNAME'S3', detcolID, entryPath),        -- 4  id
                   detcolEntry[5],                                 -- 5  permissions
                   detcolEntry[6],                                 -- 6  group
                   detcolEntry[7],                                 -- 7  owner
                   get_keyword ('updated', item),                  -- 8  creation time
                   http_mime_type (detcolPath || entryPath),       -- 9  mime type
                   get_keyword ('name', item)                      -- 10 name
                  );
}
;


create function DB.DBA.S3__headers2item (
  in headers varchat,
  in s3Path varchar,
  in what varchar)
{
  declare item any;

  item := vector ('path', s3Path,
                  'name', DB.DBA.S3__getNameFromUrl (s3Path),
                  'type', what,
                  'etag', http_request_header (headers, 'ETag'),
                  'size', cast (http_request_header (headers, 'Content-Length') as integer),
                  'mimeType', http_request_header (headers, 'Content-Type'),
                  'updated', http_string_date (http_request_header (headers, 'Last-Modified'))
                 );
  return item;
}
;


-------------------------------------------------------------------------------
--
create function DB.DBA.S3__makeHostUrl (
  in path varchar,
  in isSecure integer := 1)
{
  declare hostUrl, bucket, dir varchar;
  declare s3Protocol, s3URL varchar;

  if (isSecure)
  {
    s3Protocol := 'http://';
    s3URL := 'http://s3.amazonaws.com';
  } else {
    s3Protocol := 'http://';
    s3URL := 'http://s3.amazonaws.com';
  }
  path := ltrim (path, '/');
  bucket := DB.DBA.S3__getBucketFromUrl (path);
  dir := '';
  if (length (bucket) < length (path))
    dir := subseq (path, length (bucket)+1);
  if ((lcase (bucket) = bucket) and (bucket <> ''))
  {
    hostUrl := s3Protocol || bucket || '.s3.amazonaws.com/' || dir;
  } else {
    if (bucket <> '')
      bucket := bucket || '/';
    hostUrl := s3Protocol || 's3.amazonaws.com/' || bucket || dir;
  }
  return hostUrl;
}
;

-------------------------------------------------------------------------------
--
create function DB.DBA.S3__getBucketFromUrl (
  in url varchar)
{
  declare parts any;

  parts := split_and_decode (trim (url, '/'), 0, '\0\0/');
  if (length (parts) <> 0)
    return parts[0];
  return '';
}
;

-------------------------------------------------------------------------------
--
create function DB.DBA.S3__getNameFromUrl (
  in url varchar)
{
  declare parts any;

  parts := split_and_decode (trim (url, '/'), 0, '\0\0/');
  if (length (parts) <> 0)
    return parts[length (parts) - 1];
  return '';
}
;

-------------------------------------------------------------------------------
--
create function DB.DBA.S3__getPathFromUrl (
  in url varchar)
{
  declare bucket any;

  bucket := DB.DBA.S3__getBucketFromUrl (url);
  if (isnull (bucket))
    return '';
  return ltrim (subseq (url, length (bucket)+1), '/');
}
;

-------------------------------------------------------------------------------
--
create function DB.DBA.S3__makeAWSHeader (
  in accessCode varchar,
  in secretKey varchar,
  in authHeader varchar,
  in authMode integer := 0)
{
  declare S, T, hmacKey varchar;

  hmacKey := xenc_key_RAW_read (null, encode_base64 (secretKey));
  S := xenc_hmac_sha1_digest (authHeader, hmacKey);
  xenc_key_remove (hmacKey);
  T := sprintf ('AWS %s:%s', accessCode, S);
  if (authMode)
    T := 'Authorization:' || T;

  return T;
}
;

-------------------------------------------------------------------------------
--
create function DB.DBA.S3__getBuckets (
  in accessCode varchar,
  in secretKey varchar,
  in bucket varchar := null)
{
  -- dbg_obj_princ ('DB.DBA.S3__getBuckets (', accessCode, secretKey, ')');
  declare dateUTC, authHeader, path, S varchar;
  declare reqHdr, resHdr varchar;
  declare xt, xtItems, buckets any;

  path := '/';
  dateUTC := date_rfc1123 (now());
  S := sprintf ('GET\n\n\n%s\n%s', dateUTC, path);
  authHeader := DB.DBA.S3__makeAWSHeader (accessCode, secretKey, S);
  reqHdr := sprintf ('Authorization: %s\r\nDate: %s', authHeader, dateUTC);
  commit work;
  xt := http_client_ext (DB.DBA.S3__makeHostUrl (path),
                         http_method=>'GET',
                         http_headers=>reqHdr,
                         headers=>resHdr);
  -- dbg_obj_princ ('xt', xt);
  if (resHdr[0] like 'HTTP/1._ 4__ %' or resHdr[0] like 'HTTP/1._ 5__ %')
  {
    -- dbg_obj_princ ('xt', xt);
    return null;
  }
  buckets := vector ();
  xt := xml_tree_doc (xt);
  xtItems := xpath_eval ('//Buckets/Bucket', xt, 0);
  foreach (any xtItem in xtItems) do
  {
    declare name, creationDate any;

    name := cast (xpath_eval ('./Name', xtItem) as varchar);
    if ((name = bucket) or isnull (bucket))
    {
      creationDate := stringdate (cast (xpath_eval ('./CreationDate', xtItem) as varchar));
      buckets := vector_concat (buckets, vector (
                                                 vector ('path', '/' || name || '/',
                                                         'name', name,
                                                         'type', 'C',
                                                         'updated', creationDate,
                                                         'size', 0
                                                        )
                                                )
                               );
    }
  }
  return buckets;
}
;

-------------------------------------------------------------------------------
--
-- select DB.DBA.S3__getBucket ('19T7EE0DC8XBDGF6SPG2', '7uCNPezCuQaaJzGasAxqnvb8DPhUZ3u0gVZy5GKG', '/openlink-test/probica/');
--
create function DB.DBA.S3__getBucket (
  in accessCode varchar,
  in secretKey varchar,
  in url varchar,
  in delimiter varchar := '/')
{
  -- dbg_obj_princ ('DB.DBA.S3__getBucket (', accessCode, secretKey, url, ')');
  declare N integer;
  declare dateUTC, authHeader, S, bucket, bucketPath varchar;
  declare reqHdr, resHdr, params varchar;
  declare xt, xtItems, buckets any;

  -- ?prefix=prefix;marker=marker;max-keys=max-keys;delimiter=delimiter

  bucket := '/' || DB.DBA.S3__getBucketFromUrl (url) || '/';
  bucketPath := DB.DBA.S3__getPathFromUrl (url);
  dateUTC := date_rfc1123 (now());
  S := sprintf ('GET\n\n\n%s\n%s', dateUTC, bucket);
  authHeader := DB.DBA.S3__makeAWSHeader (accessCode, secretKey, S);
  reqHdr := sprintf ('Authorization: %s\r\nDate: %s', authHeader, dateUTC);
  params := sprintf ('?prefix=%U&marker=%s&delimiter=%s', bucketPath, '', delimiter);
  commit work;
  xt := http_client_ext (url=>DB.DBA.S3__makeHostUrl (bucket) || params,
                         http_method=>'GET',
                         http_headers=>reqHdr,
                         headers=>resHdr);
  -- dbg_obj_princ ('xt', xt);
  if (resHdr[0] like 'HTTP/1._ 4__ %' or resHdr[0] like 'HTTP/1._ 5__ %')
  {
    -- dbg_obj_princ ('DB.DBA.S3__getBucket - resHdr[0]', resHdr[0]);
    return null;
  }
  -- dbg_obj_princ ('xt', xt);
  buckets := vector ();
  xt := xml_tree_doc (xt);
  xtItems := xpath_eval ('//Contents', xt, 0);
  foreach (any xtItem in xtItems) do
  {
    declare keyName, itemPath, itemName, itemType, lastModified, itemSize, itemETag any;

    keyName := cast (xpath_eval ('./Key', xtItem) as varchar);
    keyName := replace (keyName, bucketPath, '');
    itemName := replace (keyName, '_\$folder\$', '');
    itemType := case when (itemName <> keyName) then 'C' else 'R' end;
    itemPath := url || itemName || case when (itemType = 'C') then '/' end;
    lastModified := stringdate (cast (xpath_eval ('./LastModified', xtItem) as varchar));
    itemSize := cast (xpath_eval ('./Size', xtItem) as integer);
    itemETag := cast (xpath_eval ('./ETag', xtItem) as varchar);
    buckets := vector_concat (buckets, vector (
                                               vector ('path', itemPath,
                                                       'name', itemName,
                                                       'type', itemType,
                                                       'updated', lastModified,
                                                       'size', itemSize,
                                                       'etag', itemETag
                                                      )
                                              )
                             );
  }
  return buckets;
}
;

-------------------------------------------------------------------------------
--
create function DB.DBA.S3__putObject (
  in accessCode varchar,
  in secretKey varchar,
  in s3Path varchar,
  inout s3Content any,
  inout s3Type any)
{
  -- dbg_obj_princ ('DB.DBA.S3__putObject (', accessCode, secretKey, s3Path, s3Content, s3Type, ')');
  declare dateUTC, authHeader, S, what, workPath varchar;
  declare reqHdr, resHdr, xt varchar;

  what := case when (chr (s3Path [length (s3Path) - 1]) = '/') then 'C' else 'R' end;
  workPath := DB.DBA.S3__encode (s3Path);
  if (trim (s3Path, '/') <> DB.DBA.S3__getBucketFromUrl (s3Path))
    workPath := rtrim (workPath, '/') || case when (what = 'C') then '_\$folder\$' end;
  dateUTC := date_rfc1123 (now());
  S := sprintf ('PUT\n\n%s\n%s\n%s', coalesce (s3Type, ''), dateUTC, workPath);
  authHeader := DB.DBA.S3__makeAWSHeader (accessCode, secretKey, S);
  reqHdr := sprintf ('Authorization: %s\r\nDate: %s', authHeader, dateUTC);
  if (not isnull (s3Type))
    reqHdr := sprintf ('%s\r\nContent-Type: %s', reqHdr, s3Type);
  if (not isnull (s3Content))
    reqHdr := sprintf ('%s\r\nContent-Length: %d', reqHdr, length(s3Content));
  commit work;

  xt := http_client_ext (url=>DB.DBA.S3__makeHostUrl (workPath),
                         http_method=>'PUT',
                         http_headers=>reqHdr,
                         headers=>resHdr,
                         body=>s3Content);
  if (resHdr[0] like 'HTTP/1._ 4__ %' or resHdr[0] like 'HTTP/1._ 5__ %')
  {
    -- dbg_obj_princ ('xt', xt);
    return -1;
  }
  return 1;
}
;

-------------------------------------------------------------------------------
--
create function DB.DBA.S3__headObject (
  in accessCode varchar,
  in secretKey varchar,
  in s3Path varchar,
  in what varchar,
  in s3Mode integer := 1)
{
  -- dbg_obj_princ ('DB.DBA.S3__headObject (', accessCode, secretKey, s3Path, ')');
  declare dateUTC, authHeader, S, workPath varchar;
  declare reqHdr, resHdr varchar;
  declare item, xt any;

  item := connection_get ('S3__' || s3Path);
  if (isnull (item))
  {
    if (trim (s3Path, '/') = DB.DBA.S3__getBucketFromUrl (s3Path))
    {
      -- bucket
      item := DB.DBA.S3__getBuckets (accessCode, secretKey, trim (s3Path, '/'));
      if (length (item) < 1)
        return null;
      item := item[0];
    } else {
      -- bucket object
      workPath := DB.DBA.S3__encode (s3Path);
      workPath := rtrim (workPath, '/') || case when (what = 'C') then '_\$folder\$' end;
      dateUTC := date_rfc1123 (now());
      S := sprintf ('HEAD\n\n\n%s\n%s', dateUTC, workPath);
      authHeader := DB.DBA.S3__makeAWSHeader (accessCode, secretKey, S);
      reqHdr := sprintf ('Authorization: %s\r\nDate: %s', authHeader, dateUTC);
      commit work;
      xt := http_client_ext (url=>DB.DBA.S3__makeHostUrl (workPath),
                             http_method=>'HEAD',
                             http_headers=>reqHdr,
                             headers=>resHdr);
      if (resHdr[0] like 'HTTP/1._ 4__ %' or resHdr[0] like 'HTTP/1._ 5__ %')
      {
        -- dbg_obj_princ ('resHdr[0]', DB.DBA.S3__makeHostUrl (workPath), s3Path, resHdr[0]);
        return null;
      }
      item := DB.DBA.S3__headers2item (resHdr, s3Path, what);
    }
    connection_set ('S3__' || s3Path, item);
  }
  if (s3Mode)
    return 1;
  return item;
}
;

-------------------------------------------------------------------------------
--
create function DB.DBA.S3__getObject (
  in accessCode varchar,
  in secretKey varchar,
  in s3Path varchar)
{
  -- dbg_obj_princ ('DB.DBA.S3__getObject (', accessCode, secretKey, s3Path, ')');
  declare dateUTC, authHeader, S, what, workPath varchar;
  declare reqHdr, resHdr varchar;
  declare xt, item any;

  workPath := DB.DBA.S3__encode (s3Path);
  what := case when (chr (s3Path [length (s3Path) - 1]) = '/') then 'C' else 'R' end;
  workPath := rtrim (workPath, '/') || case when (what = 'C') then '_\$folder\$' end;
  dateUTC := date_rfc1123 (now());
  S := sprintf ('GET\n\n\n%s\n%s', dateUTC, workPath);
  authHeader := DB.DBA.S3__makeAWSHeader (accessCode, secretKey, S);
  reqHdr := sprintf ('Authorization: %s\r\nDate: %s', authHeader, dateUTC);
  commit work;
  xt := http_client_ext (url=>DB.DBA.S3__makeHostUrl (workPath),
                         http_method=>'GET',
                         http_headers=>reqHdr,
                         headers=>resHdr);
  if (resHdr[0] like 'HTTP/1._ 4__ %' or resHdr[0] like 'HTTP/1._ 5__ %')
  {
    -- dbg_obj_princ ('xt', xt);
    return null;
  }

  item := vector_concat (vector ('content', xt), DB.DBA.S3__headers2item (resHdr, s3Path, what));
  return item;
}
;

-------------------------------------------------------------------------------
--
create function DB.DBA.S3__deleteObject (
  in accessCode varchar,
  in secretKey varchar,
  in s3Path varchar)
{
  -- dbg_obj_princ ('DB.DBA.S3__deleteObject (', accessCode, secretKey, s3Path, ')');
  declare dateUTC, authHeader, S, what, workPath varchar;
  declare reqHdr, resHdr varchar;
  declare items, xt any;

  dateUTC := date_rfc1123 (now());
  what := case when (chr (s3Path [length (s3Path) - 1]) = '/') then 'C' else 'R' end;
  items := vector (vector ('path', s3Path));
  if (what = 'c')
    items := vector_concat (items, DB.DBA.S3__getBucket (accessCode, secretKey, s3Path, ''));

  foreach (any item in items) do
  {
    s3Path := get_keyword ('path', item);
    what := case when (chr (s3Path [length (s3Path) - 1]) = '/') then 'C' else 'R' end;
    workPath := DB.DBA.S3__encode (s3Path);
    if (trim (s3Path, '/') <> DB.DBA.S3__getBucketFromUrl (s3Path))
      workPath := rtrim (workPath, '/') || case when (what = 'C') then '_\$folder\$' end;
    S := sprintf ('DELETE\n\n\n%s\n%s', dateUTC, workPath);
    authHeader := DB.DBA.S3__makeAWSHeader (accessCode, secretKey, S);
    reqHdr := sprintf ('Authorization: %s\r\nDate: %s', authHeader, dateUTC);
    commit work;
    http_client_ext (url=>DB.DBA.S3__makeHostUrl (workPath),
                     http_method=>'DELETE',
                     http_headers=>reqHdr,
                     headers=>resHdr);
    if (resHdr[0] like 'HTTP/1._ 4__ %' or resHdr[0] like 'HTTP/1._ 5__ %')
    {
      -- dbg_obj_princ ('xt', xt);
      return -1;
    }
    connection_set ('S3__' || s3Path, null);
  }
  return 1;
}
;

--| This matches DAV_AUTHENTICATE (in id any, in what char(1), in req varchar, in a_uname varchar, in a_pwd varchar, in a_uid integer := null)
--| The difference is that the DET function should not check whether the pair of name and password is valid; the auth_uid is not a null already.
create function DB.DBA."S3_DAV_AUTHENTICATE" (in id any, in what char(1), in req varchar, in auth_uname varchar, in auth_pwd varchar, in auth_uid integer)
{
  -- dbg_obj_princ ('S3_DAV_AUTHENTICATE (', id, what, req, auth_uname, auth_pwd, auth_uid, ')');
  if (auth_uid >= 0)
    return auth_uid;
  return -12;
}
;

--| This exactly matches DAV_AUTHENTICATE_HTTP (in id any, in what char(1), in req varchar, in can_write_http integer, inout a_lines any, inout a_uname varchar, inout a_pwd varchar, inout a_uid integer, inout a_gid integer, inout _perms varchar) returns integer
--| The function should fully check access because DAV_AUTHENTICATE_HTTP do nothing with auth data either before or after calling this DET function.
--| Unlike DAV_AUTHENTICATE, user name passed to DAV_AUTHENTICATE_HTTP header may not match real DAV user.
--| If DET call is successful, DAV_AUTHENTICATE_HTTP checks whether the user have read permission on mount point collection.
--| Thus even if DET function allows anonymous access, the whole request may fail if mountpoint is not readable by public.
create function DB.DBA."S3_DAV_AUTHENTICATE_HTTP" (in id any, in what char(1), in req varchar, in can_write_http integer, inout a_lines any, inout a_uname varchar, inout a_pwd varchar, inout a_uid integer, inout a_gid integer, inout _perms varchar) returns integer
{
  -- dbg_obj_princ ('S3_DAV_AUTHENTICATE_HTTP (', id, what, req, can_write_http, a_lines, a_uname, a_pwd, a_uid, a_gid, _perms, ')');
  declare rc integer;
  declare puid, pgid integer;
  declare u_password, pperms varchar;
  declare allow_anon integer;

  if (length (req) <> 3)
    return -15;

  whenever not found goto nf_col_or_res;
  puid := http_dav_uid();
  pgid := coalesce
  (
    ( select G_ID
        from WS.WS.SYS_DAV_GROUP
       where G_NAME = 'S3_' || coalesce ((select COL_NAME
                                            from WS.WS.SYS_DAV_COL
                                           where COL_ID = id[1] and COL_DET = 'S3'), '')
    ),
    puid+1
  );
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
      a_uid := http_nobody_uid ();
      a_gid := http_nogroup_gid ();
    }
  }
  if (DAV_CHECK_PERM (pperms, req, a_uid, a_gid, pgid, puid))
    return a_uid;
  return -13;

nf_col_or_res:
  return -1;
}
;

--| This should return ID of the collection that contains resource or collection with given ID,
--| Possible ambiguity (such as symlinks etc.) should be resolved by using path.
--| This matches DAV_GET_PARENT (in id any, in st char(1), in path varchar) returns any
create function DB.DBA."S3_DAV_GET_PARENT" (in id any, in st char(1), in path varchar) returns any
{
  -- dbg_obj_princ ('S3_DAV_GET_PARENT (', id, st, path, ')');
  return -20;
}
;

--| When DAV_COL_CREATE_INT calls DET function, authentication, check for lock and check for overwrite are passed, uid and gid are translated from strings to IDs.
--| Check for overwrite, but the deletion of previously existing collection should be made by DET function.
create function DB.DBA."S3_DAV_COL_CREATE" (in detcolID any, in pathParts any, in permissions varchar, in uid integer, in gid integer, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('S3_DAV_COL_CREATE (', detcolID, pathParts, permissions, uid, gid, auth_uid, ')');
  declare bucket, accessCode, secretKey, s3Path, s3Content, s3Type varchar;

  DB.DBA.S3__params (detcolID, bucket, accessCode, secretKey);
  s3Path := DB.DBA.S3__parts2path (bucket, pathParts, 'C');
  s3Content := null;
  s3Type := null;
  if (DB.DBA.S3__putObject (accessCode, secretKey, s3Path, s3Content, s3Type) < 1)
    return -1;
  return vector (UNAME'S3', detcolID, s3Path);
}
;

--| When DAV_DELETE_INT calls DET function, authentication and check for lock are passed.
create function DB.DBA."S3_DAV_DELETE" (
  in detcolID any,
  in pathParts any,
  in what char(1),
  in silent integer,
  in auth_uid integer) returns integer
{
  -- dbg_obj_princ ('S3_DAV_DELETE (', detcolID, pathParts, what, silent, auth_uid, ')');
  declare bucket, accessCode, secretKey, s3Path varchar;

  DB.DBA.S3__params (detcolID, bucket, accessCode, secretKey);
  s3Path := DB.DBA.S3__parts2path (bucket, pathParts, what);
  return DB.DBA.S3__deleteObject (accessCode, secretKey, s3Path);
}
;

--| When DAV_RES_UPLOAD_STRSES_INT calls DET function, authentication and check for locks are performed before the call.
--| There's a special problem, known as 'Transaction deadlock after reading from HTTP session'.
--| The DET function should do only one INSERT of the 'content' into the table and do it as late as possible.
--| The function should return -29 if deadlocked or otherwise broken after reading blob from HTTP.
-- XXX: this as built-in stops the actual code to be used
--create function DB.DBA."S3_DAV_RES_UPLOAD" (in detcolID any, in pathParts any, inout content any, in type varchar, in permissions varchar, in uid integer, in gid integer, in auth_uid integer) returns any
--{
  -- dbg_obj_princ ('S3_DAV_RES_UPLOAD (', detcolID, pathParts, ', [content], ', type, permissions, uid, gid, auth_uid, ')');
--  return -20;
--}
--;

--| When DAV_PROP_REMOVE_INT calls DET function, authentication and check for locks are performed before the call.
--| The check whether it's a system name or not (when an error in returned if name is system) is _not_ permitted.
--| It should delete any dead property even if the name looks like system name.
create function DB.DBA."S3_DAV_PROP_REMOVE" (in id any, in what char(0), in propname varchar, in silent integer, in auth_uid integer) returns integer
{
  -- dbg_obj_princ ('S3_DAV_PROP_REMOVE (', id, what, propname, silent, auth_uid, ')');
  return -20;
}
;

--| When DAV_PROP_SET_INT calls DET function, authentication and check for locks are performed before the call.
--| The check whether it's a system property or not is _not_ permitted and the function should return -16 for live system properties.
create function DB.DBA."S3_DAV_PROP_SET" (in id any, in what char(0), in propname varchar, in propvalue any, in overwrite integer, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('S3_DAV_PROP_SET (', id, what, propname, propvalue, overwrite, auth_uid, ')');
  if (propname[0] = 58)
    return -16;

  return -20;
}
;

--| When DAV_PROP_GET_INT calls DET function, authentication and check whether it's a system property are performed before the call.
create function DB.DBA."S3_DAV_PROP_GET" (in id any, in what char(0), in propname varchar, in auth_uid integer)
{
  -- dbg_obj_princ ('S3_DAV_PROP_GET (', id, what, propname, auth_uid, ')');
  return -11;
}
;

--| When DAV_PROP_LIST_INT calls DET function, authentication is performed before the call.
--| The returned list should contain only user properties.
create function DB.DBA."S3_DAV_PROP_LIST" (in id any, in what char(0), in propmask varchar, in auth_uid integer)
{
  -- dbg_obj_princ ('S3_DAV_PROP_LIST (', id, what, propmask, auth_uid, ')');
  return vector ();
}
;

--| When DAV_PROP_GET_INT or DAV_DIR_LIST_INT calls DET function, authentication is performed before the call.
create function DB.DBA."S3_DAV_DIR_SINGLE" (
  in id any,
  in what char(0),
  in path any,
  in auth_uid integer) returns any
{
  -- dbg_obj_princ ('S3_DAV_DIR_SINGLE (', id, what, path, auth_uid, ')');
  declare detcolID integer;
  declare bucket, accessCode, secretKey, detcolPath, s3Path varchar;
  declare s3Object any;

  detcolID := id[1];
  s3Path := id[2];
  DB.DBA.S3__params (detcolID, bucket, accessCode, secretKey);
  s3Object := DB.DBA.S3__headObject (accessCode, secretKey, s3Path, what, 0);
  if (isnull (s3Object))
    return -1;
  detcolPath := DB.DBA.DAV_SEARCH_PATH (detcolID, 'C');
  return DB.DBA.S3__item2entry (detcolID, detcolPath, bucket, s3Object);
}
;

--| When DAV_PROP_GET_INT or DAV_DIR_LIST_INT calls DET function, authentication is performed before the call.
create function DB.DBA."S3_DAV_DIR_LIST" (
  in detcolID any,
  in pathParts any,
  in detcol_pathParts any,
  in name_mask varchar,
  in recursive integer,
  in auth_uid integer) returns any
{
  -- dbg_obj_princ ('S3_DAV_DIR_LIST (', detcolID, pathParts, detcol_pathParts, name_mask, recursive, auth_uid, ')');
  declare N integer;
  declare bucket, accessCode, secretKey, s3Path varchar;
  declare detcolPath varchar;
  declare res, items any;

  DB.DBA.S3__params (detcolID, bucket, accessCode, secretKey);
  if (is_empty_or_null (bucket) and (length (pathParts) = 1) and pathParts[0] = '')
  {
    s3Path := '/';
    items := DB.DBA.S3__getBuckets (accessCode, secretKey);
  }
  else
  {
    s3Path := DB.DBA.S3__parts2path (bucket, pathParts, 'C');
    items := DB.DBA.S3__getBucket (accessCode, secretKey, s3Path);
  }
  detcolPath := DB.DBA.DAV_CONCAT_PATH (detcol_pathParts, '/');
  res := vector ();
  for (N := 0; N < length (items); N := N + 1)
  {
    res := vector_concat (res, vector (DB.DBA.S3__item2entry (detcolID, detcolPath, bucket, items[N])));
  }
  return res;
}
;

--| When DAV_DIR_FILTER_INT calls DET function, authentication is performed before the call and compilation is initialized.
create function DB.DBA."S3_DAV_DIR_FILTER" (in detcolID any, in pathParts any, in detcol_path varchar, inout compilation any, in recursive integer, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('S3_DAV_DIR_FILTER (', detcolID, pathParts, detcol_path, compilation, recursive, auth_uid, ')');
  return vector();
}
;

--| When DAV_PROP_GET_INT or DAV_DIR_LIST_INT calls DET function, authentication is performed before the call.
create function DB.DBA."S3_DAV_SEARCH_ID" (
  in detcolID any,
  in pathParts any,
  in what char(1)) returns any
{
  -- dbg_obj_princ ('S3_DAV_SEARCH_ID (', detcolID, pathParts, what, ')');
  declare bucket, accessCode, secretKey, s3Path varchar;
  declare s3Object any;

  DB.DBA.S3__params (detcolID, bucket, accessCode, secretKey);
  s3Path := DB.DBA.S3__parts2path (bucket, pathParts, what);
  s3Object := DB.DBA.S3__headObject (accessCode, secretKey, s3Path, what, 1);
  if (isnull (s3Object))
    return -1;
  return vector (UNAME'S3', detcolID, s3Path);
}
;

--| When DAV_SEARCH_PATH_INT calls DET function, authentication is performed before the call.
create function DB.DBA."S3_DAV_SEARCH_PATH" (
  in id any,
  in what char(1)) returns any
{
  -- dbg_obj_princ ('S3_DAV_SEARCH_PATH (', id, what, ')');
  declare detcolID integer;
  declare bucket, accessCode, secretKey, detcolPath, s3Path varchar;
  declare s3Object any;

  detcolID := id[1];
  detcolPath := coalesce ((select WS.WS.COL_PATH (COL_ID) from WS.WS.SYS_DAV_COL where COL_ID = detcolID and COL_DET = 'S3'));
  if (detcolPath is null)
    return -23;
  s3Path := id[2];
  DB.DBA.S3__params (detcolID, bucket, accessCode, secretKey);
  s3Object := DB.DBA.S3__headObject (accessCode, secretKey, s3Path, what, 0);
  if (isnull (s3Object))
    return -23;
  return rtrim (detcolPath, '/') || get_keyword ('path', s3Object);
}
;

create function DB.DBA."S3_DAV_RES_UPLOAD" (
  in detcolID any,
  in pathParts any,
  inout content any,
  in type varchar,
  in permissions varchar,
  in uid integer,
  in gid integer,
  in auth_uid integer) returns any
{
  -- dbg_obj_princ ('S3_DAV_RES_UPLOAD (', detcolID, pathParts, ', [content], ', type, permissions, uid, gid, auth_uid, ')');
  declare bucket, accessCode, secretKey, s3Path varchar;

  DB.DBA.S3__params (detcolID, bucket, accessCode, secretKey);
  s3Path := DB.DBA.S3__parts2path (bucket, pathParts, 'R');
  if (DB.DBA.S3__putObject (accessCode, secretKey, s3Path, content, type) < 1)
    return -1;
  return vector (UNAME'S3', detcolID, s3Path);
}
;

--| When DAV_COPY_INT calls DET function, authentication and check for locks are performed before the call, but no check for existing/overwrite.
create function DB.DBA."S3_DAV_RES_UPLOAD_COPY" (in detcolID any, in pathParts any, in sourceID any, in what char(1), in overwrite_flags integer, in permissions varchar, in uid integer, in gid integer, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('S3_DAV_RES_UPLOAD_COPY (', detcolID, pathParts, sourceID, what, overwrite_flags, permissions, uid, gid, auth_uid, ')');
  if (what = 'R')
  {
    declare bucket, accessCode, secretKey, s3Path varchar;

    DB.DBA.S3__params (detcolID, bucket, accessCode, secretKey);
    s3Path := DB.DBA.S3__parts2path (bucket, pathParts, 'R');

    declare rc integer;
    declare sourceContent, sourceMimeType any;

    rc := DB.DBA.DAV_RES_CONTENT_INT (sourceID, sourceContent, sourceMimeType, 0, 0);
    if (rc < 0)
      return rc;

    sourceContent := case when (__tag (sourceContent) = 126) then blob_to_string (sourceContent) else sourceContent end;
    if (DB.DBA.S3__putObject (accessCode, secretKey, s3Path, sourceContent, sourceMimeType) < 1)
      return -28;

    return vector (UNAME'S3', detcolID, s3Path);
  }
  return -20;
}
;

--| When DAV_COPY_INT calls DET function, authentication and check for locks are performed before the call, but no check for existing/overwrite.
create function DB.DBA."S3_DAV_RES_UPLOAD_MOVE" (in detcolID any, in pathParts any, in sourceID any, in what char(1), in overwrite_flags integer, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('S3_DAV_RES_UPLOAD_MOVE (', detcolID, pathParts, sourceID, what, overwrite_flags, auth_uid, ')');
  if (what = 'R')
  {
    declare rc integer;
    declare sourcePath, sourceContent, sourceMimeType any;
    declare bucket, accessCode, secretKey, s3Path varchar;

    DB.DBA.S3__params (detcolID, bucket, accessCode, secretKey);
    s3Path := DB.DBA.S3__parts2path (bucket, pathParts, 'R');

    rc := DB.DBA.DAV_RES_CONTENT_INT (sourceID, sourceContent, sourceMimeType, 0, 0);
    if (rc < 0)
      return rc;

    sourceContent := case when (__tag (sourceContent) = 126) then blob_to_string (sourceContent) else sourceContent end;
    if (DB.DBA.S3__putObject (accessCode, secretKey, s3Path, sourceContent, sourceMimeType) < 1)
      return -28;

    sourcePath := DB.DBA.DAV_SEARCH_PATH (sourceID, 'R');
    if (not isnull (sourcePath))
      DB.DBA.DAV_DELETE_INT (sourcePath, 1, null, null, 0);

    return vector (UNAME'S3', detcolID, s3Path);
  }
  return -20;
}
;

--| When DAV_RES_CONTENT or DAV_RES_COPY_INT or DAV_RES_MOVE_INT calls DET function, authentication is made.
--| If content_mode is 1 then content is a valid output stream before the call.
create function DB.DBA."S3_DAV_RES_CONTENT" (
  in id any,
  inout content any,
  out type varchar,
  in content_mode integer) returns integer
{
  -- dbg_obj_princ ('S3_DAV_RES_CONTENT (', id, ', [content], [type], ', content_mode, ')');
  declare detcolID integer;
  declare bucket, accessCode, secretKey, s3Path varchar;
  declare s3Object, s3Content any;

  detcolID := id[1];
  s3Path := id[2];
  DB.DBA.S3__params (detcolID, bucket, accessCode, secretKey);

  s3Object := DB.DBA.S3__getObject (accessCode, secretKey, s3Path);
  if (isnull (s3Object))
    return -1;

  s3Content := get_keyword ('content', s3Object);
  type := get_keyword ('mimeType', s3Object);
  if ((content_mode = 0) or (content_mode = 2))
    content := s3Content;
  else if (content_mode = 1)
    http (s3Content, content);
  else if (content_mode = 3)
    http (s3Content);

  return 0;
}
;

--| This adds an extra access path to the existing resource or collection.
create function DB.DBA."S3_DAV_SYMLINK" (in detcolID any, in pathParts any, in sourceID any, in what char(1), in overwrite integer, in uid integer, in gid integer, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('S3_DAV_SYMLINK (', detcolID, pathParts, sourceID, overwrite, uid, gid, auth_uid, ')');
  return -20;
}
;

--| This gets a list of resources and/or collections as it is returned by DAV_DIR_LIST and and writes the list of quads (old_id, 'what', old_full_path, dereferenced_id, dereferenced_full_path).
create function DB.DBA."S3_DAV_DEREFERENCE_LIST" (in detcolID any, inout report_array any) returns any
{
  -- dbg_obj_princ ('S3_DAV_DEREFERENCE_LIST (', detcolID, report_array, ')');
  return -20;
}
;

--| This gets one of reference quads returned by ..._DAV_REREFERENCE_LIST() and returns a record (new_full_path, new_dereferenced_full_path, name_may_vary).
create function DB.DBA."S3_DAV_RESOLVE_PATH" (in detcolID any, inout reference_item any, inout old_base varchar, inout new_base varchar) returns any
{
  -- dbg_obj_princ ('S3_DAV_RESOLVE_PATH (', detcolID, reference_item, old_base, new_base, ')');
  return -20;
}
;

--| There's no API function to lock for a while (do we need such?) The "LOCK" DAV method checks that all parameters are valid but does not check for existing locks.
create function DB.DBA."S3_DAV_LOCK" (in path any, in id any, in type char(1), inout locktype varchar, inout scope varchar, in token varchar, inout owner_name varchar, inout owned_tokens varchar, in depth varchar, in timeout_sec integer, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('S3_DAV_LOCK (', path, id, type, locktype, scope, token, owner_name, owned_tokens, depth, timeout_sec, auth_uid, ')');
  return -20;
}
;

--| There's no API function to unlock for a while (do we need such?) The "UNLOCK" DAV method checks that all parameters are valid but does not check for existing locks.
create function DB.DBA."S3_DAV_UNLOCK" (in id any, in type char(1), in token varchar, in auth_uid integer)
{
  -- dbg_obj_princ ('S3_DAV_UNLOCK (', id, type, token, auth_uid, ')');
  return -27;
}
;

--| The caller does not check if id is valid.
--| This returns -1 if id is not valid, 0 if all existing locks are listed in owned_tokens whitespace-delimited list, 1 for soft 2 for hard lock.
create function DB.DBA."S3_DAV_IS_LOCKED" (inout id any, inout Type char(1), in owned_tokens varchar) returns integer
{
  -- dbg_obj_princ ('S3_DAV_IS_LOCKED (', id, type, owned_tokens, ')');
  declare rc integer;
  declare orig_id any;
  declare orig_type char(1);

  -- save
  orig_id := id;
  orig_type := type;

  ID := orig_id[1];
  Type := 'C';
  rc := DB.DBA.DAV_IS_LOCKED_INT (id, type, owned_tokens);

  -- restore
  id := orig_id;
  Type := orig_type;
  if (rc <> 0)
    return rc;
  return 0;
}
;

--| The caller does not check if id is valid.
--| This returns -1 if id is not valid, list of tuples (LOCK_TYPE, LOCK_SCOPE, LOCK_TOKEN, LOCK_TIMEOUT, LOCK_OWNER, LOCK_OWNER_INFO) otherwise.
create function DB.DBA."S3_DAV_LIST_LOCKS" (in id any, in type char(1), in recursive integer) returns any
{
  -- dbg_obj_princ ('S3_DAV_LIST_LOCKS (', id, type, recursive);
  return vector ();
}
;

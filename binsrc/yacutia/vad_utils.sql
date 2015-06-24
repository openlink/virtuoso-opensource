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

--!
-- Get a list of installed and available vads.
--
-- \return A key/value vector where the key is a vad name and the value is a vad detail
-- vector. The latter consists of available version, installed version, vad filename, and vad dir type (\p 0 for fs and \p 1 for dav).
--/
create procedure CONDUCTOR.DBA.VAD_GET_AVAILABLE_VADS (
  in vadDir varchar := null,
  in dirType int := 0)
{
  declare vads, vad any;

  vads := vector ();
  for (select PKG_NAME, PKG_FILE, PKG_VER as INSTALLED_VER, coalesce(PKG_NVER, PKG_VER) as AVAILABLE_VER from YAC_VAD_LIST where dir=vadDir and fs_type=dirType) do
  {
    vad := vector (AVAILABLE_VER, INSTALLED_VER, PKG_FILE, dirType);
    vads := vector_concat (vads, vector (PKG_NAME, vad));
  }
  return vads;
}
;

--!
-- Tries hard to resolve the dependency tree of the given VAD file.
--
-- Throws a signal if any dependency could not be found or a loop was
-- detected. Any parameters but \p fname, \p is_dav, \p vadDir and \p vadDirType are internal
-- and need to be ignored.
--
-- \return A vector identifying the resolved dependency tree.
-- - Each package will only be added to the tree once, ie. the first time it is encountered.
-- - Only packages that are not yet installed will be added to the tree, meaning that the
--   tree will contain all packages that need to be installed.
-- - Each tree node represents a package in a key/value vector with the following keys:
--   \p name is the package name, \p path is the path to the vad, \p pathType is either \p 1 (DAV) or
--   \p 0 (FS) and refers to the type of the \p path, \p deps is a list of
--   dependencies, ie. package nodes.
--
-- \sa CONDUCTOR.DBA.VAD_INSTALL_FROM_DEPENDENCY_TREE, CONDUCTOR.DBA.VAD_FLATTEN_DEPENDENCY_TREE
--/
create procedure CONDUCTOR.DBA.VAD_RESOLVE_DEPENDENCY_TREE (
  in fname varchar,
  in is_dav integer,
  in vadDir varchar := null,
  in vadDirType int := 1,
  in availableVads any := null,
  in checkedVads any := null,
  in parentPkgName varchar := null,
  in depName varchar := null,
  in requiredPkgVersion varchar := null,
  in versionCompVal int := null)
{
--dbg_obj_print('CONDUCTOR.DBA.VAD_RESOLVE_DEPENDENCY_TREE (', fname, is_dav, vadDir, vadDirType, availableVads, checkedVads, parentPkgName, depName, requiredPkgVersion, versionCompVal, ')');
  declare stickerData, s varchar;
  declare flen, pos integer;
  declare data any;
  declare stickerTree, stickerDoc, items, dep, parr any;
  declare pkgName, pkgTitle, pkgVersion, pkgDate, depVer varchar;
  declare depTree any;

  if (availableVads is null)
  {
    availableVads := CONDUCTOR.DBA.VAD_GET_AVAILABLE_VADS (vadDir, vadDirType);
  }
  if (checkedVads is null)
  {
    checkedVads := vector ();
  }

  if (vadDir is null)
  {
    vadDir := cfg_item_value (virtuoso_ini_path (), 'Parameters', 'VADInstallDir');
  }
  vadDir := rtrim (vadDir, '/') || '/';

  if (parentPkgName is not null)
  {
    -- See if we have the package in any version
    dep := get_keyword (depName, availableVads);
    if (dep is null)
    {
      signal ('37000', sprintf ('Vad package %s depends on %s. Please install.', parentPkgName, depName));
    }
    fname := vadDir || dep[2];
    is_dav := dep[3];

    -- Check if the available version matches the requirements
    if(VAD.DBA.VERSION_COMPARE (dep[0], requiredPkgVersion) <> versionCompVal)
    {
      signal ('37000', sprintf ('Vad package %s depends on %s version %s%s. Available version %s is not sufficient.', parentPkgName, depName, (case when versionCompVal = 1 then 'greater than ' when versionCompVal = -1 then 'smaller than ' end), requiredPkgVersion, dep[0]));
    }
  }

  -- we also support plain filenames which live in the vad dir
  if (position ('/', fname) = 0)
  {
    fname := vadDir || fname;
  }

  flen := "VAD"."DBA"."VAD_GET_STICKER_DATA_LEN" (fname, is_dav);
  if (is_dav = 0)
  {
    stickerData := file_to_string_output (fname, 0, flen);
  }
  else
  {
    stickerData := string_output();
    "VAD"."DBA"."BLOB_2_STRING_OUTPUT"(fname, 0, flen, stickerData);
  }

  -- Get header (already checked above)
  pos := 0;
  "VAD"."DBA"."VAD_GET_ROW" (stickerData, pos, s, data);

  -- Get the sticker itself
  "VAD"."DBA"."VAD_GET_ROW" (stickerData, pos, s, data);

  -- parse the sticker
  stickerTree := xml_tree (data);
  stickerDoc := xml_tree_doc (stickerTree);


  -- Extract package name
  pkgName := xpath_eval ('/sticker/caption/name/@package', stickerDoc, 0);
  if (length (pkgName) = 0) {
    signal ('37000', sprintf ('Sticker for %s does not contain a package name!', fname));
  }
  pkgName := cast (pkgName[0] as varchar);

  -- Extract package title
  pkgTitle := xpath_eval ('/sticker/caption/name/prop[@name=\'Title\']', stickerDoc, 0);
  if (length (pkgTitle) = 0) {
    signal ('37000', sprintf ('Sticker for %s does not contain a package title!', fname));
  }
  pkgTitle := cast (xpath_eval ('@value', pkgTitle[0]) as varchar);

  -- Extract package version
  pkgVersion := xpath_eval ('/sticker/caption/version/@package', stickerDoc, 0);
  if (length (pkgVersion) = 0) {
    signal ('37000', sprintf ('Sticker for %s does not contain a package version!', fname));
  }
  pkgVersion := cast (pkgVersion[0] as varchar);

  -- Extract package date
  pkgDate := xpath_eval ('/sticker/caption/version/prop[@name=\'Release Date\']', stickerDoc, 0);
  if (length (pkgDate) = 0) {
    signal ('37000', sprintf ('Sticker for %s does not contain a package date!', fname));
  }
  pkgDate := cast (xpath_eval ('@value', pkgDate[0]) as varchar);


  -- Prepare the result
  depTree := vector ();

  -- The vad code needs this parr object for something I do not undestand yet
  parr := null;

  items := xpath_eval ('/sticker/dependencies/require', stickerDoc, 0);
  for (declare i int, i := 0; i < length (items); i := i+1)
  {
    depName := cast (xpath_eval ('name/@package', items[i]) as varchar);

    depVer := cast (xpath_eval ('versions_earlier/@package', items[i]) as varchar);
    if (depName is not null and length(depVer))
    {
      if (not "VAD"."DBA"."VAD_TEST_PACKAGE_LT" (parr, depName, depVer))
      {
        -- Check if we need to recurse into the vads deps
        if (position (depName, checkedVads) = 0)
        {
          checkedVads := vector_concat (checkedVads, vector (depName));
          depTree := vector_concat (depTree, vector (CONDUCTOR.DBA.VAD_RESOLVE_DEPENDENCY_TREE (null, 0, vadDir, vadDirType, availableVads, checkedVads, pkgName, depName, depVer, -1)));
        }
      }
    }

    depVer := cast (xpath_eval ('version/@package', items[i]) as varchar);
    if (depName is not null and length(depVer))
    {
      if (not "VAD"."DBA"."VAD_TEST_PACKAGE_EQ" (parr, depName, depVer))
      {
        -- Check if we need to recurse into the vads deps
        if (position (depName, checkedVads) = 0)
        {
          checkedVads := vector_concat (checkedVads, vector (depName));
          depTree := vector_concat (depTree, vector (CONDUCTOR.DBA.VAD_RESOLVE_DEPENDENCY_TREE (null, 0, vadDir, vadDirType, availableVads, checkedVads, pkgName, depName, depVer, 0)));
        }
      }
    }

    depVer := cast (xpath_eval ('versions_later/@package', items[i]) as varchar);
    if (depName is not null and length(depVer))
    {
      --dbg_obj_print('Checking dep ', depName, depVer);
      if (not "VAD"."DBA"."VAD_TEST_PACKAGE_GT" (parr, depName, depVer))
      {
        -- Check if we need to recurse into the vads deps
        if (position (depName, checkedVads) = 0)
        {
          checkedVads := vector_concat (checkedVads, vector (depName));
          depTree := vector_concat (depTree, vector (CONDUCTOR.DBA.VAD_RESOLVE_DEPENDENCY_TREE (null, 0, vadDir, vadDirType, availableVads, checkedVads, pkgName, depName, depVer, 1)));
        }
      }
    }
  }

  return vector (
    'name', pkgName,
    'title', pkgTitle,
    'version', pkgVersion,
    'date', pkgDate,
    'path', fname,
    'pathType', is_dav,
    'deps', depTree
  );
}
;

--!
-- Convert the dependency tree into a flat list of package nodes.
--
-- The tree will be traversed depth-first bottom-up. Thus, the list can be installed from first to last.
--/
create procedure CONDUCTOR.DBA.VAD_FLATTEN_DEPENDENCY_TREE (
  in depTree any)
{
  declare r, stack, x, deps any;

  r := vector ();

  stack := vector (depTree);
  while (length (stack) > 0)
  {
    -- pop the first element
    x := stack[0];
    stack := subseq (stack, 1);

    -- remember the deps
    deps := get_keyword ('deps', x);

    -- Extract the plain package without deps
    x := vector (
      'name', get_keyword ('name', x),
      'title', get_keyword ('title', x),
      'version', get_keyword ('version', x),
      'date', get_keyword ('date', x),
      'path', get_keyword ('path', x),
      'pathType', get_keyword ('pathType', x)
    );

    -- We reached the bottom, add to our result
    if (length (deps) = 0)
    {
      r := vector_concat (r, vector (x));
    }

    -- Continue our depth traversal by stacking everything
    else
    {
      stack := vector_concat (deps, vector (x), stack);
    }
  }

  return r;
}
;

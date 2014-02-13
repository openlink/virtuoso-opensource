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

create procedure DAV_DEBUG_CHECK_DIR_ITEM (inout itm any, in refetch integer := 0, in signal_if_error integer := 1)
{
  declare reason varchar;
  declare fpath, lname, st varchar;
  declare fpath_id, fpath_itm any;
  if (DAV_HIDE_ERROR (itm) is null)
    {
      reason := 'parameter is an error ' || DAV_PERROR (itm);
      if (signal_if_error)
        goto oblom;
      return;
    }
  if (not isarray (itm))	{ reason := 'bad type'; goto oblom; }
  if (length (itm) <> 11)	{ reason := 'bad length'; goto oblom; }
  if (not (isstring (itm[0])))	{ reason := '[0] is not string'; goto oblom; }
  if (not (isstring (itm[1])))	{ reason := '[1] is not string'; goto oblom; }
  if (not (isinteger (itm[2])))	{ reason := '[2] is not integer'; goto oblom; }
  if (not (isstring (itm[5])))	{ reason := '[5] is not string'; goto oblom; }
  if (not (isinteger (itm[6])))	{ reason := '[6] is not integer'; goto oblom; }
  if (not (isinteger (itm[7])))	{ reason := '[7] is not integer'; goto oblom; }
  if (not (isstring (itm[9])))	{ reason := '[9] is not string'; goto oblom; }
  if (not (isstring (itm[10])))	{ reason := '[10] is not string'; goto oblom; }
  fpath := itm[0];
  lname := itm[10];
  if (not (fpath like '/DAV/%')) { reason := '[0] is not like "/DAV/%"'; goto oblom; }
  st := itm[1];
  if ('R' = st)
    {
      if (fpath like '%/') { reason := '[0] is like "%/" for "R"'; goto oblom; }
      if ("RIGHT" (fpath, length (lname)) <> lname) { reason := '[0] does not end with [10] for "R"'; goto oblom; }
    }
  else if ('C' = st)
    {
      if (not (fpath like '%/')) { reason := '[0] is not like "%/" for "C"'; goto oblom; }
      if ("RIGHT" (fpath, length (lname) + 1) <> lname || '/') { reason := '[0] does not end with [10] || "/" for "C"'; goto oblom; }
    }
  else { reason := '[1] is neither "R" nor "C"'; goto oblom; }
  if (not exists (select top 1 1 from WS.WS.SYS_DAV_USER where U_ID = itm[7])) { reason := '[7] is not in WS.WS.SYS_DAV_USER'; goto oblom; }
  if (not exists (select top 1 1 from WS.WS.SYS_DAV_GROUP where G_ID = itm[6])) { reason := '[6] is not in WS.WS.SYS_DAV_GROUP'; goto oblom; }
  fpath_id := DAV_SEARCH_ID (fpath, st);
  if (DAV_HIDE_ERROR (fpath_id) is null) { reason := '[0] "' || fpath || '" not found: ' || DAV_PERROR (fpath_id); goto oblom; }
  if (serialize (itm[4]) <> serialize (fpath_id)) { dbg_obj_princ ('full path ID is ', fpath_id); reason := 'DAV_SEARCH_ID ([0]) <> [4]'; goto oblom; }
  if (refetch)
    {
      fpath_itm := DAV_DIR_LIST_INT (fpath, -1, '%', 'dav', 'dav', http_dav_uid());
      if (DAV_HIDE_ERROR (fpath_itm) is null) { reason := 'can not get a diritem of [0] "' || fpath || '": ' || DAV_PERROR (fpath_itm); goto oblom; }
      if (not isarray (fpath_itm)) { dbg_obj_princ ('DAV_DIR_SINGLE returned ', fpath_itm); reason := 'bad type'; goto oblom; }
      if (1 <> length (fpath_itm)) { dbg_obj_princ ('DAV_DIR_SINGLE returned ', fpath_itm); reason := 'DAV_DIR_SINGLE ([0]) is not of length 1'; goto oblom; }
      if (serialize (itm) <> serialize (fpath_itm[0])) { dbg_obj_princ ('DAV_DIR_SINGLE returned ', fpath_itm[0]); reason := 'DAV_DIR_SINGLE ([0]) <> itm'; goto oblom; }
    }
  return;

oblom:
  dbg_obj_princ ('DAV_DEBUG_CHECK_DIR_ITEM (', itm, '): ', reason);
  signal ('OBLOM', 'DAV_DEBUG_CHECK_DIR_ITEM (): ' || reason);
}
;

create procedure DAV_DEBUG_CHECK_DIR_LIST (inout dirlist any, in refetch integer := 0, in signal_if_error integer := 1)
{
  declare reason varchar;
  if (DAV_HIDE_ERROR (dirlist) is null)
    {
      reason := 'parameter is an error' || DAV_PERROR (dirlist);
      if (signal_if_error)
        goto oblom;
      return;
    }
  foreach (any itm in dirlist) do
    {
      DAV_DEBUG_CHECK_DIR_ITEM (itm, refetch, 1);
    }
  return;

oblom:
  dbg_obj_princ ('DAV_DEBUG_CHECK_DIR_LIST (', dirlist, '): ', reason);
  signal ('OBLOM', 'DAV_DEBUG_CHECK_DIR_LIST (): ' || reason);
}
;

create procedure DAV_DEBUG_CHECK_SPACE_QUOTAS ()
{
  declare HOME_PATH, PROBLEM varchar;
  declare used_u_ids, err_log any;
  declare actual_dav_use numeric;
  result_names (HOME_PATH, PROBLEM);
  used_u_ids := dict_new ();
  vectorbld_init (err_log);
  for (
    select
      DSQ_HOME_PATH, DSQ_U_ID,
      DSQ_DAV_USE, DSQ_APP_USE, DSQ_TOTAL_USE,
      DSQ_MAX_DAV_USE, DSQ_MAX_APP_USE, DSQ_MAX_TOTAL_USE,
      DSQ_QUOTA, DSQ_ABOVE_HI_YELLOW, DSQ_LAST_WARNING
    from WS.WS.SYS_DAV_SPACE_QUOTA ) do
    {
      if (DSQ_U_ID is null)
        {
          if (not (DSQ_APP_USE = 0))
            vectorbld_acc (err_log, vector (DSQ_HOME_PATH, 'Nonzero DSQ_APP_USE for NULL DSQ_U_ID'));
          if (not (DSQ_MAX_APP_USE = 0))
            vectorbld_acc (err_log, vector (DSQ_HOME_PATH, 'Nonzero DSQ_MAX_APP_USE for NULL DSQ_U_ID'));
        }
      else
        {
          declare other_home varchar;
          other_home := dict_get (used_u_ids, DSQ_U_ID, null);
          if (other_home is not null)
            vectorbld_acc (err_log, vector (DSQ_HOME_PATH, 'Duplicate DSQ_U_ID, see also ' || other_home));
          dict_put (used_u_ids, DSQ_U_ID, DSQ_HOME_PATH);
        }
      if (DSQ_DAV_USE < 0)
        vectorbld_acc (err_log, vector (DSQ_HOME_PATH, 'DSQ_DAV_USE < 0'));
      if (DSQ_APP_USE < 0)
        vectorbld_acc (err_log, vector (DSQ_HOME_PATH, 'DSQ_APP_USE < 0'));
      if (DSQ_TOTAL_USE <> DSQ_DAV_USE + DSQ_APP_USE)
        vectorbld_acc (err_log, vector (DSQ_HOME_PATH, 'DSQ_TOTAL_USE <> DSQ_DAV_USE + DSQ_APP_USE'));
      if (DSQ_MAX_DAV_USE < DSQ_DAV_USE)
        vectorbld_acc (err_log, vector (DSQ_HOME_PATH, 'DSQ_MAX_DAV_USE < DSQ_DAV_USE'));
      if (DSQ_MAX_APP_USE < DSQ_APP_USE)
        vectorbld_acc (err_log, vector (DSQ_HOME_PATH, 'DSQ_MAX_APP_USE < DSQ_APP_USE'));
      if (DSQ_MAX_TOTAL_USE < DSQ_DAV_USE + DSQ_APP_USE)
        vectorbld_acc (err_log, vector (DSQ_HOME_PATH, 'DSQ_MAX_TOTAL_USE < DSQ_DAV_USE + DSQ_APP_USE'));
      if (DSQ_MAX_TOTAL_USE > DSQ_MAX_DAV_USE + DSQ_MAX_APP_USE)
        vectorbld_acc (err_log, vector (DSQ_HOME_PATH, 'DSQ_MAX_TOTAL_USE > DSQ_MAX_DAV_USE + DSQ_MAX_APP_USE'));
      if (DSQ_ABOVE_HI_YELLOW is null and (DSQ_TOTAL_USE > (DSQ_QUOTA * 0.9)))
        vectorbld_acc (err_log, vector (DSQ_HOME_PATH, 'DSQ_ABOVE_HI_YELLOW is null while above hi-yellow'));
      if (DSQ_ABOVE_HI_YELLOW is not null and (DSQ_TOTAL_USE < (DSQ_QUOTA * 0.75)))
        vectorbld_acc (err_log, vector (DSQ_HOME_PATH, 'DSQ_ABOVE_HI_YELLOW is not null while below lo-yellow'));
      actual_dav_use := coalesce (
         (select SUM (cast (length (RES_CONTENT) as numeric))
           from WS.WS.SYS_DAV_RES
           where RES_FULL_PATH between DSQ_HOME_PATH and DAV_COL_PATH_BOUNDARY (DSQ_HOME_PATH) ),
          0 );
      if (DSQ_DAV_USE <> actual_dav_use)
        vectorbld_acc (err_log, vector (DSQ_HOME_PATH, 'DSQ_DAV_USE does not match actual DAV use'));
    }
  vectorbld_final (err_log);
  foreach (any rec in err_log) do
    {
      dbg_obj_princ (rec[0], '\t: ', rec[1]);
      result (rec[0], rec[1]);
    }
  if (length (err_log) > 0)
    {
      dbg_obj_princ ('DAV_DEBUG_CHECK_SPACE_QUOTAS (): ', length (err_log), ' integrity error(s) found');
      signal ('OBLOM', sprintf ('DAV_DEBUG_CHECK_SPACE_QUOTAS () : %d integrity error(s) found', length (err_log)));
    }
}
;

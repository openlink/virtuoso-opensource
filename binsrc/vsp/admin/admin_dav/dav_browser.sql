--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2018 OpenLink Software
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
--
-- get id of currently logged-on user

create procedure
adm_dav_br_get_uid (in lines any)
{
  return 0;
}
;

-- return null if the user has no read privileges on the collection

create procedure
adm_dav_user_can_read_col_p (in uid integer, in col_id integer)
{
  dbg_printf ('WARNING: adm_dav_user_can_read_col_p is a stub procedure');

  return col_id;
}
;

-- return null if the user has no read privileges on the resource

create procedure
adm_dav_user_can_read_res_p (in uid integer, in res_id integer)
{
  dbg_printf ('WARNING: adm_dav_user_can_read_res_p is a stub procedure');

  return res_id;
}
;

create procedure
adm_fdate_for_humans (in d datetime)
{

  declare date_part varchar;
  declare time_part varchar;

  declare min_diff integer;
  declare day_diff integer;


  day_diff := datediff ('day', d, now ());

  if (day_diff < 1)
    {
      min_diff := datediff ('minute', d, now ());

      if (min_diff = 1)
        {
          return ('a minute ago');
	}
      else if (min_diff < 1)
        {
          return ('less than a minute ago');
        }
      else if (min_diff < 60)
	{
	  return (sprintf ('%d minutes ago', min_diff));
	}
      else return (sprintf ('today at %d:%d', hour (d), minute (d)));
    }

  if (day_diff < 2)
    {
      return (sprintf ('yesterday at %d:%d', hour (d), minute (d)));
    }

  return (sprintf ('%d/%d/%d %d:%d', year (d), month (d), day (d), hour (d), minute (d)));
}
;

create procedure
adm_dav_br_uid_to_user (in uid integer)
{

  declare _u_name varchar;

  if (uid is null)
    return ('DB NULL');

  if (not exists (select 1 from "WS"."WS"."SYS_DAV_USER" where U_ID = uid))
    {
--      dbg_printf ('A collection/resource with non-existing owner, strange!\n');
      return (sprintf ('%d', uid));
    }

  select coalesce (U_NAME, '')
    into _u_name
    from WS.WS.SYS_DAV_USER
    where U_ID = uid;

  if (isnull (_u_name))
    {
      return (sprintf ('%d', uid));
    }

  return _u_name;
}
;

create procedure
adm_dav_br_fmt_perm (in obj_perm varchar)
{
  dbg_printf ('WARNING: adm_dav_br_fmt_priv is a stub procedure');

  return (obj_perm);
}
;

create procedure
adm_dav_br_list_error (in message varchar,
		       in cur_col integer,
		       in new_col integer,
		       in uid integer)
{
  http ('');
  http ('Error: te');
}
;

-- Map mime type to file icon href

create procedure
adm_dav_br_map_icon (in type varchar)
{
  if ('folder' = type)
    return ('images/16x16/folder.gif');
  if ('application/pdf' = type)
    return ('images/16x16/pdf.gif');
  if ('application/ms-word' = type or 'application/msword' = type)
    return ('images/16x16/msword.gif');
  if ('application/zip' = type)
    return ('images/16x16/zip.gif');
  if ('text/html' = type)
    return ('images/16x16/html.gif');
  if ('text' = "LEFT" (type, 4))
    return ('images/16x16/text.gif');
  if ('image' = "LEFT" (type, 5))
    return ('images/16x16/image.gif');
  if ('audio' = "LEFT" (type, 5))
    return ('images/16x16/wave.gif');
  if ('video' = "LEFT" (type, 5))
    return ('images/16x16/video.gif');

  return ('images/16x16/generic_file.gif');
}
;

--
-- format a collection row in the list
--

create procedure
adm_dav_br_fmt_col (in obj_name varchar,
		    in col_id integer,
		    in obj_size integer,
		    in owner_uid integer,
		    in owner_gid integer,
		    in mod_time datetime,
		    in obj_perm varchar,
		    in lst_mode integer,
		    in browse_mode integer)
{
  declare img_tag varchar;
  declare exec_anchor varchar;

--  dbg_printf ('adm_dav_br_fmt_col\n');

--  dbg_printf ('obj_name (%d)\ncol_id (%d) \nobj_size (%d) \nowner_uid (%d) \nmod_time (%d) \nobj_perm (%d) \nlst_mode (%d) \nbrowse_mode (%d)\n', __TAG(obj_name), __TAG(col_id), __TAG(obj_size), __TAG(owner_uid), __TAG(owner_gid), __TAG(mod_time), __TAG(obj_perm), __TAG(lst_mode), __TAG(browse_mode));


  img_tag := sprintf ('<img class="davfilelisticon" src="%s" />',
		       adm_dav_br_map_icon ('folder'));

  exec_anchor := sprintf ('<a class="imglink" href="javascript:dav_cd (%d)">', col_id);


  if (1 = lst_mode)
    {

      return concat ('<td width="16" class="davfilelisticon">',
		     exec_anchor,
		     img_tag,
		     '</a></td>\n',

		     '<td class="davfilelistname">',
		     exec_anchor,
		     obj_name,
		     '</a></td>\n',

		     '<td class="davfilelistsize">',
		     cast (obj_size as varchar),
                     '</td>\n',

		     '<td class="davfilelisttype">',
		     'folder',
                     '</td>\n',

		     '<td class="davfilelistuid">',
		     adm_dav_br_uid_to_user (owner_uid),
                     '</td>\n',

		     '<td class="davfilelistuid">',
		     adm_dav_br_uid_to_user (owner_gid),
                     '</td>\n',

		     '<td class="davfilelistmodtime">',
		     "LEFT" (cast (mod_time as varchar), 19),
                     '</td>\n',

		     '<td class="davfilelistpriv">',
		     adm_dav_format_perms (obj_perm),
		     '</td>\n');
    }
}
;


-- format a collection row in the list
--

create procedure
adm_dav_br_fmt_res (in res_type varchar,
		    in res_name varchar,
		    in res_full_path varchar,
		    in res_id integer,
		    in res_size integer,
		    in res_owner integer,
		    in res_group integer,
		    in res_mod_time datetime,
		    in res_perm varchar,
		    in lst_mode integer,
		    in browse_mode integer)
{
  declare img_tag varchar;
  declare exec_anchor varchar;

  img_tag := sprintf ('<img class="davfilelisticon" src="%s" />',
		       adm_dav_br_map_icon (res_type));

  if ('STANDALONE' = browse_mode)
    {
      exec_anchor :=
        sprintf ('<a class="imglink" href="javascript:dav_res_view (''%s'')">',
	          res_full_path);
    }
  else
    {
      exec_anchor :=
        sprintf ('<a class="imglink" href="javascript:dav_res_select (''%s'', %d, ''%s'')">',
                  res_name, res_id, res_full_path);
    }

--  dbg_printf ('adm_dav_br_fmt_res\n');
--  dbg_printf ('obj_name: %d', __TAG (res_name));

  if (1 = lst_mode)
    {

      return concat ('<td width="16" class="davfilelisticon">',
		     exec_anchor,
		     img_tag,
		     '</a></td>\n',

		     '<td class="davfilelistname">',
		     exec_anchor,
		     res_name,
		     '</a></td>\n',

		     '<td class="davfilelistsize">',
		     cast (res_size as varchar),
                     '</td>\n',

		     '<td class="davfilelisttype">',
		     res_type,
                     '</td>\n',

		     '<td class="davfilelistuid">',
		     adm_dav_br_uid_to_user (res_owner),
                     '</td>\n',

		     '<td class="davfilelistuid">',
		     adm_dav_br_uid_to_user (res_group),
                     '</td>\n',

		     '<td class="davfilelistmodtime">',
		     "LEFT" (cast (res_mod_time as varchar), 19),
                     '</td>\n',

		     '<td class="davfilelistpriv">',
		     adm_dav_format_perms (res_perm),
		     '</td>\n');
    }
}
;


create procedure
adm_dav_br_gen_col_c_listing (in cur_col integer,
			      in par_col integer,
			      in uid integer,
			      in flt_pat varchar,
			      in lst_mode varchar,
			      in browse_mode varchar,
			      in xfer_mode varchar)
{
  declare parent_owner integer;
  declare parent_group integer;
  declare parent_mod_time datetime;
  declare parent_perms varchar;

dbg_printf ('\nadm_dav_br_gen_col_c_listing:');
dbg_printf ('cur_col: %d', cur_col);

-- dbg_printf ('flt_pat: %s', flt_pat);

  if ('' = flt_pat) flt_pat := '%';

  if (null = adm_dav_user_can_read_col_p (uid, cur_col))
    {
--      dbg_printf ('No privileges');
      adm_dav_br_list_error ('The user has no read access privileges for collection.',
			     cur_col,
			     uid);
      return 666;
    }

  http ('<table class="wfilelist" width="100%">\n');

-- Process collections first. Insert extra entry for parent collection (cur_col);
  http ('<caption class="wfilelistcap">');
  http ('</caption>');

  http ('<thead class="wfilelistheadgrp">');
  http ('<tr class="wfilelistheadrow">\
<th class="wfilelisthead">&nbsp;</th><th class="wfilelisthead">Name</th>\n\
<th class="wfilelisthead">Size</th><th class="wfilelisthead">Type</th>\n\
<th class="wfilelisthead">Owner</th><th class="wfilelisthead">Group</th>\n\
<th class="wfilelisthead">Modified</th><th class="wfilelisthead">Perms</th>\n');
  http ('</thead>');
  http ('<tbody class="wfilelistbodygrp">');


  if (cur_col <> 1)
    {
      http ('  <tr class="wfilelistrow">\n');

      select COL_OWNER, COL_GROUP, COL_MOD_TIME, COL_PERMS
	into parent_owner, parent_group, parent_mod_time, parent_perms
	from "WS"."WS"."SYS_DAV_COL"
	where COL_ID = par_col;



      http (adm_dav_br_fmt_col ('..', par_col, 'N/A',
				     parent_owner, parent_group, parent_mod_time,
				     parent_perms, lst_mode, browse_mode));
      http ('  </tr>\n');
    }

  for select COL_ID, COL_NAME, COL_OWNER, COL_GROUP, COL_MOD_TIME, COL_PERMS
         from "WS"."WS"."SYS_DAV_COL"
         where COL_PARENT = cur_col order by COL_NAME do
    {

      http ('  <tr class="wfilelistrow">\n');
      http (adm_dav_br_fmt_col (COL_NAME, COL_ID, 'N/A',
				COL_OWNER, COL_GROUP, COL_MOD_TIME,
				COL_PERMS, lst_mode, browse_mode));
      http ('  </tr>');
    }

-- Then produce list of resources

  for select RES_ID, RES_NAME, RES_CONTENT, RES_OWNER, RES_GROUP,
	       RES_COL, RES_TYPE, RES_MOD_TIME, RES_PERMS, RES_FULL_PATH
	  from "WS"."WS"."SYS_DAV_RES"
	  where RES_COL=cur_col and RES_NAME like flt_pat order by RES_NAME do
    {
      http ('  <tr class="wfilelistrow">\n');
      http (adm_dav_br_fmt_res (RES_TYPE, RES_NAME, RES_FULL_PATH,
				RES_ID, length (RES_CONTENT),
				RES_OWNER, RES_GROUP, RES_MOD_TIME,
				RES_PERMS, lst_mode, browse_mode));
      http ('  </tr>');

    }
  http ('</tbody>');
  http ('</table>\n');
--  dbg_printf ('\nadm_dav_br_gen_col_c_listing: finished');
}
;

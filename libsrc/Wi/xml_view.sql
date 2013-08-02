--
--  xml_view.sql
--
--  $Id$
--
--  Publishing xml views as WebDAV resources.
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2013 OpenLink Software
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

-- return 1 if xml view is published

-- IvAn/XmlView/000810 Header processing has extended

create procedure XML_VIEW_PUBLISH
  (
    in view_name varchar,
    in dav_path varchar,
    in dav_owner varchar,
    in is_persistent integer,
    in refresh_interval integer,
    in meta_mode integer,
    in meta_data varchar
  )
{
  declare path, _body any;
  declare _col_id, _id integer;
  declare _u_id, _u_grp integer;
  declare _u_perm, _r_name, _pf varchar;
  declare _update_call1, _update_call2 varchar;
  declare _full_path varchar;		-- Full name of resource, including dav_root() prefix
  declare _meta_body any;		-- Stream for external metadata
  declare _meta_path_suffix varchar;	-- Suffix of name of DAV resource with metadata
  declare _meta_mime varchar;		-- MIME type of metadata, e.g. 'xml/dtd'
  declare _ondemand_data varchar;	-- Data to create non-persistent view.
  declare _procprefix varchar;		-- Schema and user of the proc delimited by '.' with trailing '.'
  _procprefix := concat (name_part (view_name, 0), '.', name_part (view_name, 1), '.');
  if (not exists (select 1 from SYS_PROCEDURES
	where P_NAME like concat ( _procprefix, 'http_', name_part (view_name, 2), '_%')))
    signal ('S1000', concat ('the XML view ', view_name, ' does not exist'));

  if (not exists (select 1 from SYS_PROCEDURES
	where P_NAME = concat ( _procprefix, 'http_view_', name_part (view_name, 2))))
    signal ('S1000', concat ('the XML view ', view_name, ' does not exist'));

  if (aref (dav_path, 0) <> ascii ('/'))
    signal ('42000', 'The DAV path should be absolute');

  if (dav_root () <> '')
    _full_path := concat ('/', dav_root (), dav_path);
  else
    _full_path := dav_path;

  path := WS.WS.HREF_TO_ARRAY (concat ('/DAV', dav_path), '');

  if (WS.WS.FINDCOL (path, _col_id) <> length (path) - 1)
    signal ('S1000', 'the DAV collection of the view does not exist or is invalid');

--    signal ('S1000', 'a DAV resource with that name already exists');

whenever not found goto nfu;
  _u_id := null;
  select U_ID, U_GROUP, U_DEF_PERMS into _u_id, _u_grp, _u_perm from WS.WS.SYS_DAV_USER where U_NAME = dav_owner;
nfu:
  if (_u_id is null)
    signal ('42000', 'a DAV user with that name does not exist');

  if (is_persistent = 0)
    {
      _ondemand_data := concat (
        view_name, '{view_name}\n',
	cast (meta_mode as varchar), '{meta_mode}\n',
	meta_data );
    }

  if (refresh_interval > 0)
    {
      -- The following statement should be exactly the same as in XML_VIEW_DROP
      _update_call1 := concat (
        'WS.WS.XML_VIEW_UPDATE (',
	WS.WS.STR_SQL_APOS(view_name), ', '
	);
      -- at this point,	<CODE>cast (_id as varchar)</CODE> should be imprinted later
      _update_call2 := concat ( ', ',
	WS.WS.STR_SQL_APOS(_full_path), ', ',
	cast (meta_mode as varchar), ', ',
	WS.WS.STR_SQL_APOS(meta_data), ')'
        );
    }

  _meta_body := string_output ();
  WS.WS.XML_VIEW_EXTERNAL_META(
    view_name, name_part (view_name, 2), meta_mode, meta_data,
    _meta_body, _meta_path_suffix, _meta_mime );
  if(_meta_path_suffix <> '')
    {
      _meta_path_suffix := concat( aref (path, length (path) - 1), _meta_path_suffix);
      _meta_body := string_output_string (_meta_body);
      if (exists (select 1 from WS.WS.SYS_DAV_RES
        where RES_COL = _col_id and RES_NAME = _meta_path_suffix))
	{
          update WS.WS.SYS_DAV_RES set
            RES_CONTENT = _meta_body,
            RES_TYPE = _meta_mime,
            RES_MOD_TIME = now (),
            RES_OWNER = _u_id,
            RES_GROUP = _u_grp,
            RES_PERMS = _u_perm
            where RES_COL = _col_id and RES_NAME = _meta_path_suffix;
	} else {
          insert into WS.WS.SYS_DAV_RES
            (
             RES_ID, RES_NAME, RES_COL,
             RES_TYPE, RES_CONTENT,
             RES_CR_TIME, RES_MOD_TIME,
             RES_OWNER, RES_PERMS, RES_GROUP
            )
          values
            (
             WS.WS.GETID ('R'), _meta_path_suffix, _col_id,
             _meta_mime, _meta_body,
             now (), now (),
             _u_id, _u_perm, _u_grp
            );
	}
    }

  if (not WS.WS.ISRES (path))
    {
      if (is_persistent = 0)
	{
	  insert
	      into WS.WS.SYS_DAV_RES
	      (
	       RES_ID, RES_NAME, RES_COL,
	       RES_TYPE,
	       RES_CONTENT,
	       RES_CR_TIME, RES_MOD_TIME,
	       RES_OWNER, RES_PERMS, RES_GROUP
	      )
	      values
	      (
	       WS.WS.GETID ('R'), aref (path, length (path) - 1), _col_id,
	       'xml/view',
	       _ondemand_data,
	       now (), now (),
	       _u_id, _u_perm, _u_grp
	      );
	}
      else
	{
          _body := string_output ();
          WS.WS.XML_VIEW_HEADER(view_name, name_part (view_name, 2), _full_path, meta_mode, meta_data, _body);
          _pf := concat (_procprefix, 'http_view_', name_part (view_name, 2));
	  call (_pf) (_body);
	  http (concat ('</', name_part (view_name, 2), '>'), _body);
          _body := string_output_string (_body);
          _id := WS.WS.GETID ('R');
          insert
	      into WS.WS.SYS_DAV_RES
	      (
	       RES_ID, RES_NAME, RES_COL,
	       RES_TYPE, RES_CONTENT,
	       RES_CR_TIME, RES_MOD_TIME,
	       RES_OWNER, RES_PERMS, RES_GROUP
	      )
	      values
	      (
	       _id, aref (path, length (path) - 1), _col_id,
	       'xml/persistent-view', _body,
	       now (), now (),
	       _u_id, _u_perm, _u_grp
	      );
	  if (refresh_interval > 0)
	    insert into DB.DBA.SYS_SCHEDULED_EVENT (SE_NAME, SE_START, SE_INTERVAL, SE_SQL)
		values (
		 concat ('/DAV', dav_path), now (), refresh_interval,
		 concat(_update_call1, cast (_id as varchar), _update_call2)
		 );
       }
    }
  else
    {
      declare _type varchar;
      WS.WS.FINDRES (path, _col_id, _r_name);
      whenever not found goto nfri;
      select RES_ID into _id from WS.WS.SYS_DAV_RES where RES_COL = _col_id and RES_NAME = _r_name;
nfri:
      if (is_persistent = 0)
        {
	  _body := _ondemand_data;
          _type := 'xml/view';
          if (exists (select 1 from DB.DBA.SYS_SCHEDULED_EVENT where SE_NAME = concat ('/DAV', dav_path)))
	    delete from DB.DBA.SYS_SCHEDULED_EVENT where  SE_NAME = concat ('/DAV', dav_path);
        }
      else
        {
          _body := string_output ();
          WS.WS.XML_VIEW_HEADER(view_name, name_part (view_name, 2), _full_path, meta_mode, meta_data, _body);
          _pf := concat (_procprefix, 'http_view_', name_part (view_name, 2));
	  call (_pf) (_body);
	  http (concat ('</', name_part (view_name, 2), '>'), _body);
          _body := string_output_string (_body);
	  _type :=  'xml/persistent-view';
          if (exists (select 1 from DB.DBA.SYS_SCHEDULED_EVENT where SE_NAME = concat ('/DAV', dav_path)))
	    {
	      if (refresh_interval > 0)
		  update DB.DBA.SYS_SCHEDULED_EVENT
		    set
		    SE_INTERVAL = refresh_interval,
		    SE_START = now (),
		    SE_SQL = concat(_update_call1, cast (_id as varchar), _update_call2)
		    where  SE_NAME = concat ('/DAV', dav_path);
	      else
		  delete from DB.DBA.SYS_SCHEDULED_EVENT where  SE_NAME = concat ('/DAV', dav_path);
	    }
	  else if (refresh_interval > 0)
	    insert into DB.DBA.SYS_SCHEDULED_EVENT (SE_NAME, SE_START, SE_INTERVAL, SE_SQL)
		values (
		 concat ('/DAV', dav_path), now (), refresh_interval,
		 concat(_update_call1, cast (_id as varchar), _update_call2)
		 );
        }
      update WS.WS.SYS_DAV_RES set
	  RES_CONTENT = _body,
          RES_TYPE = _type,
          RES_MOD_TIME = now (),
	  RES_OWNER = _u_id,
	  RES_GROUP = _u_grp,
	  RES_PERMS = _u_perm
          where RES_COL = _col_id and RES_NAME = _r_name;
    }
}
;

create procedure XML_VIEW_DROP (in view_name varchar)
{
  declare _p_name varchar;
  declare _update_call1 varchar;
  declare _ondemand varchar;
  declare _procprefix varchar;		-- Schema and user of the proc delimited by '.' with trailing '.'
  view_name := cast (view_name as varchar);
  _procprefix := concat (name_part (view_name, 0), '.', name_part (view_name, 1), '.');
  delete from WS.WS.SYS_DAV_RES where RES_TYPE = 'xml/view' and cast(RES_CONTENT as varchar) = view_name;
  _ondemand := concat (view_name, '{view_name}\n');
  delete from WS.WS.SYS_DAV_RES
      where RES_TYPE = 'xml/view' and
        substring (cast (RES_CONTENT as varchar), 1, length (_ondemand)) = _ondemand;
  -- The following statement should be exactly same as in XML_VIEW_PUBLISH
  _update_call1 := concat (
   'WS.WS.XML_VIEW_UPDATE (',
    WS.WS.STR_SQL_APOS(view_name), ', '
    );
  delete from DB.DBA.SYS_SCHEDULED_EVENT
      where substring (SE_SQL, 1, length (_update_call1)) = _update_call1;

  if (not exists (select 1 from SYS_VIEWS where
      V_NAME = view_name or
      V_NAME = concat (_procprefix, name_part (view_name, 2)) ) )
    signal ('S1000', concat ('The XML view ''', view_name, ''' does not exist'));

  XML_VIEW_DROP_PROCS (view_name);
  delete from SYS_VIEWS where
      V_NAME = view_name or
      V_NAME = concat (_procprefix, name_part (view_name, 2));
  xmls_viewremove (view_name);
  xmls_viewremove (concat (_procprefix, name_part (view_name, 2)));
}
;

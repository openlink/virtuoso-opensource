--
--  WebDAV support.
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

create procedure WS.WS."OPTIONS" (in path varchar, inout params varchar, in lines varchar)
{
  declare full_path varchar;
  declare path_id any;
  full_path := '/' || DAV_CONCAT_PATH (path, '/');
  path_id := DAV_SEARCH_ID (full_path, 'C');
  if (isarray(path_id) = 1)
    {
      if (path_id[0] = UNAME'CalDAV')
	{
	  http_header (concat (
	  'Content-Type: text/xml\r\n',
	  'Allow: OPTIONS, GET, HEAD, POST, PUT, DELETE, TRACE, COPY, MOVE\r\n',
	  'Allow: PROPFIND, PROPPATCH, LOCK, UNLOCK, REPORT, ACL\r\n',
	  'DAV: 1, 2, access-control, calendar-access\r\n',
	  'MS-Author-Via: DAV\r\n'));
	  return;
	}
      if (path_id[0] = UNAME'CardDAV')
	{
	  http_header (concat (
	  'Content-Type: text/xml\r\n',
	  'Allow: OPTIONS, GET, HEAD, POST, PUT, DELETE, TRACE, COPY, MOVE\r\n',
	  'Allow: PROPFIND, PROPPATCH, LOCK, UNLOCK, REPORT, ACL\r\n',
	  'DAV: 1, 2, 3, access-control, addressbook\r\n',
	  'MS-Author-Via: DAV\r\n'));
	  return;
	}
    }
  else
    {
      declare is_det int;
      is_det := (select COL_ID from WS.WS.SYS_DAV_COL where COL_ID = path_id and COL_DET = 'CalDAV');
      if (is_det > 0)
	{
	  http_header (concat (
	  'Content-Type: text/xml\r\n',
	  'Allow: OPTIONS, GET, HEAD, POST, TRACE\r\n',
	  'Allow: PROPFIND, PROPPATCH, LOCK, UNLOCK, REPORT, ACL\r\n',
	  'DAV: 1, 2, access-control, calendar-access\r\n',
	  'MS-Author-Via: DAV\r\n'));
	  return;
	}
	is_det := (select COL_ID from WS.WS.SYS_DAV_COL where COL_ID = path_id and COL_DET = 'CardDAV');
	if (is_det > 0)
	  {
	    http_header (concat (
	    'Content-Type: text/xml\r\n',
	    'Allow: OPTIONS, GET, HEAD, POST, TRACE\r\n',
	    'Allow: PROPFIND, PROPPATCH, LOCK, UNLOCK, REPORT, ACL\r\n',
	    'DAV: 1, 2, 3, access-control, addressbook\r\n',
	    'MS-Author-Via: DAV\r\n'));
	    return;
	  }
    }
  declare headers, ctype, msauthor any;
  http_methods_set ('OPTIONS', 'GET', 'HEAD', 'POST', 'PUT', 'DELETE', 'TRACE', 'PROPFIND', 'PROPPATCH', 'COPY', 'MOVE', 'LOCK', 'UNLOCK');
  WS.WS.GET (path, params, lines);
  headers := http_header_array_get ();
  ctype := http_request_header (headers, 'Content-Type', null, 'text/plain');
  msauthor := http_request_header (headers, 'MS-Author-Via', null, 'DAV');
  http_status_set (200);
  http_rewrite ();
  http_header (concat (sprintf ('Content-Type: %s\r\n', ctype),
		'DAV: 1,2,<http://www.openlinksw.com/virtuoso/webdav/1.0>\r\n',
		'Link: <http://www.w3.org/ns/ldp/profile>;rel="profile"\r\n',
		'Accept-Patch: */*\r\n',
		'Accept-Post: */*\r\n',
		sprintf ('MS-Author-Via: %s\r\n', msauthor)));
}
;

create procedure WS.WS.PROPFIND (in path varchar, inout params varchar, in lines varchar)
{
	--dbg_obj_princ ('WS.WS.PROPFIND (', path, params, lines, ')');
	declare _mod_time datetime;
	declare _cr_time datetime;
	declare _depth integer;
	declare st, _temp varchar;
	declare _ms_date integer;
	declare _lpath, _body, _ses, _props, _ppath, _perms varchar;
	declare uname, upwd varchar;
	declare id any;
	declare _u_id, _g_id, rc integer;

	_ses := aref_set_0 (params, 1);
	_body := string_output_string (_ses);
	_lpath := http_path ();
	_ppath := http_physical_path ();
	if (_lpath = '')
		_lpath := '/';
	id := DAV_HIDE_ERROR (DAV_SEARCH_ID (vector_concat (vector(''), path, vector('')), 'C'));
	if (id is not null)
	{
		st := 'C';
	}
	else
	{
		id := DAV_HIDE_ERROR (DAV_SEARCH_ID (vector_concat (vector(''), path), 'R'));
		if (id is null)
		{
      DB.DBA.DAV_SET_HTTP_STATUS (404);
			return;
		}
 	  st := 'R';
	}
	_u_id := null;
	_g_id := null;
	if (st = 'C')
	{
		rc := DAV_AUTHENTICATE_HTTP (id, st, '1__', 1, lines, uname, upwd, _u_id, _g_id, _perms);
	}
	else
	{
		rc := DAV_AUTHENTICATE_HTTP (DAV_GET_PARENT (id, st, _ppath), 'C', '1__', 1, lines, uname, upwd, _u_id, _g_id, _perms);
	}
	if (rc < 0)
	{
    DB.DBA.DAV_SET_AUTHENTICATE_HTTP_STATUS (rc);
		return;
	}
	if (strstr (WS.WS.FINDPARAM (lines, 'User-Agent:'), 'Microsoft') is not null)
		_ms_date := 1;
	else
		_ms_date := 0;

	_temp := WS.WS.FINDPARAM (lines, 'Depth:');
	if (_temp <> '' and _temp <> 'infinity')
		_depth := atoi (_temp);
	else
		_depth := 1;
	if (_depth > 2)
	{
	      DB.DBA.DAV_SET_HTTP_STATUS (403);
	      return;
	}
	{
		declare test_tree any;
		declare exit handler for sqlstate '*'
		{
      DB.DBA.DAV_SET_HTTP_STATUS (400);
			return;
		};
		if (length (_body) > 0)
			test_tree := xml_tree (_body);
	}

	if (st = 'C' and aref (_lpath, length (_lpath) - 1) <> ascii ('/'))
		_lpath := concat (_lpath, '/');

	-- Any properties
	_props := WS.WS.PROPNAMES (_body);
  if (isarray (_props) and length (_props) = 1 and
       (aref (_props, 0) = 'propname'))
	{
		WS.WS.CUSTOM_PROP (_lpath, _props, _depth, st);
		return;
	}

	http_request_status ('HTTP/1.1 207 Multi-Status');
	declare full_path varchar;
	declare path_id any;
	full_path := '/' || DAV_CONCAT_PATH (path, '/');
	path_id := DAV_SEARCH_ID (full_path, 'C');
	if (isarray(path_id) = 1)
	{
		if (path_id[0] = UNAME'CalDAV')
			http_header ('DAV: 1, calendar-access, calendar-schedule, calendar-proxy\r\nContent-type: application/xml; charset="utf-8"\r\n');
		if (path_id[0] = UNAME'CardDAV')
			http_header ('DAV: 1, addressbook\r\nContent-type: application/xml; charset="utf-8"\r\n');
	}
	http_header ('Content-type: text/xml; charset="utf-8"\r\n');
	http ('<?xml version="1.0" encoding="utf-8"?>\n');
	http ('<D:multistatus xmlns:D="DAV:" xmlns:M="urn:uuid:c2f41010-65b3-11d1-a29f-00aa00c14882/">\n');
	if (-13 = WS.WS.PROPFIND_RESPONSE (_lpath, _ppath, _depth, st, _ms_date, _props, _u_id))
	{
		_u_id := null;
		_g_id := null;
		-- This will force 'Unauthorized'
		http_rewrite ();
		WS.WS.GET_DAV_AUTH (lines, 0, 1, uname, upwd, _u_id, _g_id, _perms);
		return;
	}
	http ('</D:multistatus>\n');
}
;

--#IF VER=5
--!AFTER
--#ENDIF
create function WS.WS.PROPFIND_RESPONSE (in lpath varchar,
    in ppath varchar,
	in depth integer,
	in st char (1),
	in ms_date integer,
	in propnames any,
	in u_id integer) returns integer
{
	declare all_prop, ppath_len integer;
	declare dirlist any;
	declare add_not_found, _this_col integer;
	--dbg_obj_princ ('WS.WS.PROPFIND_RESPONSE (', lpath, ppath, depth, st, ms_date, propnames, u_id, ')');
	all_prop := 0;
	add_not_found := 1;

	if (not isstring (lpath) or not isstring (ppath))
		return -28;

	if (st = 'C' and aref (ppath, length (ppath) - 1) <> ascii ('/'))
		ppath := concat (ppath, '/');
	ppath_len := length (ppath);

	if (not isarray (propnames))
	{
		if (ms_date)
		{
			propnames := vector (':getlastmodified', ':creationdate',
				':lastaccessed', ':getcontentlength', ':resourcetype', ':supportedlock');
			add_not_found := 0;
		}
		else
			propnames := vector (':getlastmodified', ':getcontentlength', ':resourcetype');
	}
	else if (aref (propnames, 0) = 'allprop')
	{
		propnames := vector (':getlastmodified', ':creationdate', ':getetag', ':getcontenttype',
			':getcontentlength', ':resourcetype', ':lockdiscovery', ':supportedlock');
		all_prop := 1;
	}

	dirlist := DAV_DIR_LIST_INT (ppath, -1, '%', null, null, u_id);
	if (isinteger (dirlist))
	{
		if (dirlist = -13)
		{
			if (u_id > 0)
				dirlist := vector ();
			else
				return dirlist;
		}
		else
			dirlist := vector (); -- TODO: This is a stub. It should be turned into something better.
	}
	if (length (dirlist) = 0)
	{
		-- dbg_obj_princ ('SQL_NOT_FOUND in WS.WS.PROPFIND_RESPONSE (', lpath, ppath, depth, st, ms_date, propnames, u_id, ')');
		return -1;
	}
	WS.WS.PROPFIND_RESPONSE_FORMAT (lpath, dirlist, 0, ms_date, propnames, all_prop, add_not_found, 0, u_id);

	-- Now go deep
	if (depth = 1 and st = 'C')
	{
		dirlist := DAV_DIR_LIST_INT (ppath, 0, '%', null, null, u_id);

		if (isinteger (dirlist))
		{
			if (dirlist = -13)
			{
				if (u_id > 0)
					dirlist := vector ();
				else
					return dirlist;
			}
			else
				dirlist := vector (); -- TODO: This is a stub. It should be turned into something better.
		}

		WS.WS.PROPFIND_RESPONSE_FORMAT (lpath, dirlist, 1, ms_date, propnames, all_prop, add_not_found, 0, u_id);
	}
	else if (((depth = -1) or (depth > 1)) and (st = 'C'))
	{
		dirlist := DAV_DIR_LIST_INT (ppath, 0, '%', null, null, u_id);
		if (isinteger (dirlist))
		{
			if (dirlist = -13)
			{
				if (u_id > 0)
					dirlist := vector ();
				else
					return dirlist;
			}
			else
				dirlist := vector (); -- TODO: This is a stub. It should be turned into something better.
		}
		WS.WS.PROPFIND_RESPONSE_FORMAT (lpath, dirlist, case (depth) when -1 then -1 else depth-1 end, ms_date, propnames, all_prop, add_not_found, 1, u_id);
		foreach (any itm in dirlist) do
		{
			if ('C' = itm[1])
			{
				if (-13 = WS.WS.PROPFIND_RESPONSE (lpath || itm[10] || '/', ppath || itm[10] || '/', -1, 'C', ms_date, propnames, u_id))
					return -13;
			}
		}
	}
	return 0;
}
;


create procedure WS.WS.PROPFIND_RESPONSE_FORMAT (in lpath varchar,
	in dirlist any,
	in append_name_to_href integer,
	in ms_date integer,
	in propnames any,
	in all_prop integer,
	in add_not_found integer,
	in resources_only integer,
	in _u_id integer)
{
  --dbg_obj_princ ('WS.WS.PROPFIND_RESPONSE_FORMAT (', lpath, dirlist, append_name_to_href, ms_date, propnames, all_prop, add_not_found, _u_id, ')');
  declare dir_len, dir_ctr, ix, len, dt_flag, iso_dt_flag, res_len, parent_col, id, found_cprop, found_sprop, mix integer;
  declare crt, modt datetime;
  declare name, mime_type, prop, prop1, dt_ms, mis_prop varchar;
  declare st char(1);
  declare diritm, prop_raw_val, prop_val, href any;
  declare perms, uid, gid any;

  if (ms_date)
    {
      dt_flag := 1;
      iso_dt_flag := 1;
      dt_ms := ' M:dt="dateTime.rfc1123"';
    }
  else
    {
      dt_flag := 1;
      iso_dt_flag := 0;
      dt_ms := '';
    }

  dir_ctr := 0;
  dir_len := length (dirlist);

next_response:
  if (dir_ctr >= dir_len)
    return;
  diritm := dirlist[dir_ctr];

  st := diritm[1];
  if (('R' <> st) and resources_only)
    {
      dir_ctr := dir_ctr + 1;
      goto next_response;
    }
  res_len := diritm[2];
  modt := diritm[3];
  id := diritm[4];
  crt := diritm[8];
  mime_type := diritm[9];
  name := diritm[10];
  perms := diritm[5];
  uid := diritm[7];
  gid := diritm[6];

  found_sprop := 0;
  mis_prop := '';
  mix := 0;

  if (__tag (crt) <> 211)
    crt := now ();
  if (__tag (modt) <> 211)
    modt := now ();
  href := case append_name_to_href when 0 then lpath else DAV_CONCAT_PATH (lpath, name) end;
  if (st = 'C' and href not like '%/' and href not like '%.ics' and href not like '%.vcf')
    href := href || '/';
  parent_col := DAV_SEARCH_ID (href, 'P');
  http ('<D:response xmlns:D="DAV:" xmlns:lp0="DAV:" xmlns:i0="DAV:" xmlns:V="http://www.openlinksw.com/virtuoso/webdav/1.0/">\n');
  http (sprintf ('<D:href>%V</D:href>\n', charset_recode (href, 'UTF-8', '_WIDE_')));
  -- http ('<D:href>');
  -- http_dav_url (
  --   charset_recode (
  --     href,
  --     null, 'UTF-8' ) );
  -- http ('</D:href>\n');
  http ('<D:propstat>\n');
  http ('<D:prop>\n');
  ix := 0;
  len := length (propnames);
  while (ix < len)
    {
      prop := aref (propnames, ix);
      --dbg_obj_princ ('>PROPERTY: ', prop);
      if (prop = ':getlastmodified')
	{
	  http (concat(sprintf ('<lp0:getlastmodified%s>', dt_ms), soap_print_box (modt, '', dt_flag) , '</lp0:getlastmodified>\n'));
          found_sprop := 1;
	}
      else if (prop = ':creationdate')
	{
	  http (concat(sprintf ('<lp0:creationdate%s>', dt_ms), soap_print_box (crt, '', iso_dt_flag) , '</lp0:creationdate>\n'));
          found_sprop := 1;
	}
      else if (prop = ':lastaccessed')
	{
	  http (concat(sprintf ('<D:lastaccessed%s>', dt_ms), soap_print_box (modt, '', dt_flag) , '</D:lastaccessed>\n'));
          found_sprop := 1;
	}
      else if (prop = ':getetag' and st = 'R')
	{
	  http (concat('<lp0:getetag>"', WS.WS.ETAG (name, parent_col, modt), '"</lp0:getetag>\n'));
          found_sprop := 1;
	}
      else if (prop = ':getcontenttype')
	{
          http (concat('<lp0:getcontenttype>', mime_type, '</lp0:getcontenttype>\n'));
          found_sprop := 1;
	}
      else if (prop = ':getcontentlength' and st = 'R')
	{
	  http (concat ('<lp0:getcontentlength>', cast (res_len as varchar), '</lp0:getcontentlength>\n'));
          found_sprop := 1;
	}
      else if (prop = 'urn:ietf:params:xml:ns:caldav:supported-calendar-component-set')
	{
	   http ('<C:supported-calendar-component-set xmlns:C="urn:ietf:params:xml:ns:caldav"><C:comp name="VEVENT"/><C:comp name="VTODO"/></C:supported-calendar-component-set>\r\n');
          found_sprop := 1;
	}
	else if (prop = 'urn:ietf:params:xml:ns:carddav:supported-address-data')
	{
	   http ('<A:supported-address-data xmlns:A="urn:ietf:params:xml:ns:carddav"><C:address-data-type content-type="text/vcard" version="3.0"/></A:supported-address-data>\r\n');
          found_sprop := 1;
	}
      else if (prop = ':getetag' and st = 'C')
	{
	  http (concat('<lp0:getetag>"', WS.WS.ETAG (name, parent_col, modt), '"</lp0:getetag>\n'));
          found_sprop := 1;
	}
	else if (prop = 'http://calendarserver.org/ns/:getctag')
	{
	  http (concat('<CS:getctag xmlns:CS="http://calendarserver.org/ns/">', WS.WS.ETAG (name, parent_col, modt), '</CS:getctag>\n'));
          found_sprop := 1;
	}
      else if (prop = 'urn:ietf:params:xml:ns:caldav:calendar-data')
	{
          declare content, type_ any;
	   DB.DBA.DAV_RES_CONTENT_INT (DAV_SEARCH_ID (lpath, 'R'), content, type_, 0, 0);
	  http (concat('<C:calendar-data xmlns:C="urn:ietf:params:xml:ns:caldav">', content, '</C:calendar-data>\n'));
          found_sprop := 1;
	}
	else if (prop = 'urn:ietf:params:xml:ns:carddav:address-data')
	{
          declare content, type_ any;
	   DB.DBA.DAV_RES_CONTENT_INT (DAV_SEARCH_ID (lpath, 'R'), content, type_, 0, 0);
	  http (concat('<A:address-data xmlns:A="urn:ietf:params:xml:ns:carddav">', content, '</A:address-data>\n'));
          found_sprop := 1;
	}
	else if (prop = 'urn:ietf:params:xml:ns:caldav:calendar-home-set')
	{
		http (sprintf ('<C:calendar-home-set xmlns:C="urn:ietf:params:xml:ns:caldav"><D:href>%V</D:href></C:calendar-home-set>\n', charset_recode (lpath, 'UTF-8', '_WIDE_')));
          found_sprop := 1;
	}
	else if (prop = 'urn:ietf:params:xml:ns:carddav:addressbook-home-set')
	{
		http (sprintf ('<C:addressbook-home-set xmlns:C="urn:ietf:params:xml:ns:carddav"><D:href>%V</D:href></C:addressbook-home-set>\n', charset_recode (lpath, 'UTF-8', '_WIDE_')));
          found_sprop := 1;
	}
	else if (prop = ':principal-URL')
	{
		http (sprintf ('<D:principal-URL><D:href>%V</D:href></D:principal-URL>\n', charset_recode (lpath, 'UTF-8', '_WIDE_')));
        found_sprop := 1;
	}
	else if (prop = ':current-user-privilege-set')
	{
		if (mime_type = 'text/vcard' or mime_type = 'text/calendar')
		{
			http ('<D:current-user-privilege-set><D:privilege><D:all/></D:privilege></D:current-user-privilege-set>');
			found_sprop := 1;
		}
	}
    else if (prop = ':supported-report-set')
	{
		if (mime_type = 'text/vcard')
		{
			http (concat('<D:supported-report-set>', '<D:supported-report>
                        <D:report>
                            <C:addressbook-query xmlns:C="urn:ietf:params:xml:ns:carddav"/>
                        </D:report>
                    </D:supported-report>
                    <D:supported-report>
                        <D:report>
                            <C:addressbook-multiget xmlns:C="urn:ietf:params:xml:ns:carddav"/>
                        </D:report>
                    </D:supported-report>
                    <D:supported-report>
                        <D:report>
                            <D:expand-property />
                        </D:report>
                    </D:supported-report>
					<D:supported-report>
                        <D:report>
                            <D:principal-property-search />
                        </D:report>
                    </D:supported-report>
					<D:supported-report>
                        <D:report>
                            <D:principal-search-property-set />
                        </D:report>
                    </D:supported-report>', '</D:supported-report-set>\n'));
					 found_sprop := 1;
		}
		else if (mime_type = 'text/calendar')
		{
			http (concat('<D:supported-report-set>', '<D:supported-report>
				<D:report>
					<C:calendar-multiget xmlns:C="urn:ietf:params:xml:ns:caldav"/>
				</D:report>
			</D:supported-report>
			<D:supported-report>
				<D:report>
					<C:calendar-query xmlns:C="urn:ietf:params:xml:ns:caldav"/>
				</D:report>
			</D:supported-report>
			<D:supported-report>
				<D:report>
					<D:principal-match/>
				</D:report>
			</D:supported-report>
			<D:supported-report>
				<D:report>
					<C:free-busy-query xmlns:C="urn:ietf:params:xml:ns:caldav"/>
				</D:report>
                    </D:supported-report>', '</D:supported-report-set>\n'));
					 found_sprop := 1;
		}
        found_sprop := 1;
	}
      else if (prop = ':resourcetype')
	{
          if (st = 'C')
          {
	    if (mime_type = 'text/vcard')
	      http ('<D:resourcetype><D:collection/><C:addressbook xmlns:C="urn:ietf:params:xml:ns:carddav" /></D:resourcetype>\n');
		 else if (mime_type = 'text/calendar')
	      http ('<D:resourcetype><D:collection/><C:calendar xmlns:C="urn:ietf:params:xml:ns:caldav" /></D:resourcetype>\n');
            else
              http ('<D:resourcetype><D:collection/></D:resourcetype>\n');
          }
	  else
	    http ('<D:resourcetype/>\n');
          found_sprop := 1;
	}
      else if (prop = ':lockdiscovery')
	{
	  declare lock_ctr, locks_count integer;
	  declare locks any;
	  locks := DAV_LIST_LOCKS (id, st);
	  lock_ctr := 0;
	  locks_count := length (locks);
	  while (lock_ctr < locks_count)
	    {
	      declare lck any;
	      declare l_type, l_scope, l_token, l_oinfo varchar;
	      declare l_owner, l_timeout integer;
	      lck := locks[lock_ctr];
	      l_type := lck[0];
	      l_scope := lck[1];
	      l_token := lck[2];
	      l_timeout := lck[3];
	      l_owner := lck[4];
	      l_oinfo := coalesce (lck[5], '');
              if (lock_ctr = 0)
		http ('<D:lockdiscovery>');
	      http ('<D:activelock>\n');
	      http ('<D:locktype><D:write/></D:locktype>\n');
	      if (l_scope = 'X')
		http ('<D:lockscope><D:exclusive/></D:lockscope>\n');
	      else
		http ('<D:lockscope><D:shared/></D:lockscope>\n');
	      http ('<D:depth>infinity</D:depth>\n');
	      http (sprintf ('%s<D:timeout>Second-%d</D:timeout>\n', l_oinfo, l_timeout));
	      http (sprintf ('<D:locktoken><D:href>opaquelocktoken:%s</D:href></D:locktoken>\n', l_token));
	      http ('</D:activelock>\n');
	      lock_ctr := lock_ctr + 1;
	    }
          if (lock_ctr > 0)
	    http ('</D:lockdiscovery>\n');
	  else
	    http ('<D:lockdiscovery/>\n');
          found_sprop := 1;
	}
      else if (prop = ':supportedlock')
	{
	  http ('<D:supportedlock>\n<D:lockentry>\n<D:lockscope><D:exclusive/></D:lockscope>\n<D:locktype><D:write/></D:locktype>\n</D:lockentry>\n<D:lockentry>\n<D:lockscope><D:shared/></D:lockscope>\n<D:locktype><D:write/></D:locktype>\n</D:lockentry>\n</D:supportedlock>\n');
          found_sprop := 1;
	}
      else if (prop = ':virtpermissions')
	{
	  perms := trim (perms, '\r\n ');
	  http (concat('<V:virtpermissions>', perms, '</V:virtpermissions>\n'));
          found_sprop := 1;
	}
      else if (prop = ':virtowneruid')
	{
	  declare tmp varchar;
	  tmp := (select U_NAME from DB.DBA.SYS_USERS where U_ID = uid);
	  if (tmp is not null)
	    {
	      http (sprintf ('<V:virtowneruid>%U</V:virtowneruid>\n', tmp));
	      found_sprop := 1;
	    }
	  else
	    {
	      mis_prop := concat (mis_prop, '<V:virtowneruid />\n');
	    }
	}
      else if (prop = ':virtownergid')
	{
	  declare tmp varchar;
	  tmp := (select U_NAME from DB.DBA.SYS_USERS where U_ID = gid);
	  if (tmp is not null)
	    {
	      http (sprintf ('<V:virtownergid>%U</V:virtownergid>\n', tmp));
	      found_sprop := 1;
	    }
	  else
	    {
	      mis_prop := concat (mis_prop, '<V:virtownergid />\n');
	    }
	}
      else if (all_prop = 0)
	{
	  if (aref (prop, 0) = ascii (':'))
	    prop1 := substring (prop, 2, length (prop));
	  else
	    prop1 := prop;
          found_cprop := 0;
          prop_raw_val := DAV_HIDE_ERROR (DAV_PROP_GET_INT (id, st, prop1, 0), null);
	  if (strchr (prop1, ':') is not null)
	    goto skip1;
          if (prop_raw_val is not null)
	    {
              prop_val := deserialize (prop_raw_val);
              if (isarray (prop_val))
                {
                  prop_val := xml_tree_doc (prop_val);
                  if (xpath_eval ('[xmlns:virt="virt"] /virt:rdf', prop_val) is null)
	            http_value (prop_val);
	          else
	            {
	              -- TBD
	              ;
	            }
	        }
              else if (isstring (prop_raw_val))
		http (concat ('<V:',prop1,'><![CDATA[', prop_raw_val,']]></V:', prop1,'>\n'));
	      else
		http (concat ('<V:',prop1,'/>\n'));

              found_cprop := 1;
              found_sprop := 1;
	      skip1:;
	    }
	  if (add_not_found and not found_cprop)
	    {
	      declare names, namep varchar;
	      declare colon any;
              colon := strrchr (prop, ':');
              if (colon and colon > 0)
                {
                  namep := substring (prop, colon + 1, length (prop));
                  names := substring (prop, 1, colon);
                  mix := mix + 1;
                  mis_prop := concat (mis_prop, sprintf ('<i%d%s xmlns:i%d="%s" />\n', mix, namep, mix, names));
		}
	      else
                mis_prop := concat (mis_prop, sprintf ('<i0%s />\n', prop));
	    }
	}
      ix := ix + 1;
    }
  if (all_prop = 1)
    {
      declare props, prp any;
      declare props_count, prop_idx integer;
      props := DAV_PROP_LIST_INT (id, st, '%', 0);
      props_count := length (props);
      prop_idx := 0;
      while (prop_idx < props_count)
        {
          prp := props[prop_idx];
          prop1 := prp[0];
          prop_raw_val := prp[1];
          prop_val := deserialize (prop_raw_val);
	  if (strchr (prop1, ':') is not null)
	    goto skip2;
            if (isarray (prop_val))
                {
                  prop_val := xml_tree_doc (prop_val);
                  if (xpath_eval ('[xmlns:virt="virt"] /virt:rdf', prop_val) is null)
	            http_value (prop_val);
	          else
	            {
	              -- TBD
	              ;
	            }
	        }
	    else if (isstring (prop_raw_val))
	      http (concat ('<V:',prop1,'><![CDATA[', prop_raw_val ,']]></V:', prop1,'>\n'));
	    else
	      http (concat ('<V:',prop1,'/>\n'));
	  skip2:
          prop_idx := prop_idx + 1;
        }
    }
  if (found_sprop)
    {
      http ('</D:prop>\n');
      http ('<D:status>HTTP/1.1 200 OK</D:status>\n');
      http ('</D:propstat>\n');
    }
  if (mis_prop <> '')
    {
      if (found_sprop)
	      http ('<D:propstat>\n<D:prop>\n');
      http (mis_prop);
      http ('</D:prop>\n<D:status>HTTP/1.1 404 Not Found</D:status>\n</D:propstat>\n');

    }
  http ('</D:response>\n');

  dir_ctr := dir_ctr + 1;
  goto next_response;

}
;

create procedure WS.WS.PROPNAMES (in _body varchar)
{
  declare prop, propname, allprop, tree, tmp, ret any;
  declare ix, len, sc integer;
  declare name varchar;

  if (not isstring(_body) or _body = '')
    return null;

  prop := string_output ();
  propname := string_output ();
  allprop := string_output ();
  tree := xml_tree_doc (xml_expand_refs (xml_tree (_body)));
  http_value (xpath_eval ('//propfind/prop', tree , 1), null, prop);
  http_value (xpath_eval ('//propfind/propname', tree , 1), null, propname);
  http_value (xpath_eval ('//propfind/allprop', tree , 1), null, allprop);
  prop := string_output_string (prop);
  propname := string_output_string (propname);
  allprop := string_output_string (allprop);

  ret := null;

  if (allprop <> '')
    return vector ('allprop');
  else if (propname <> '')
    return vector ('propname');
  else if (prop <> '')
    {
      declare xp any;
      tree := xtree_doc (prop);
      xp := xpath_eval('/prop/*', tree, 0);
      foreach (any elm in xp) do
        {
	  name := cast (xpath_eval ('name()', elm) as varchar);
	  sc := strrchr (name, ':');
          if (sc is not null and (name like 'DAV::%'
	       or name like 'http://www.openlinksw.com/virtuoso/webdav/1.0/:%'))
            name := subseq (name, sc, length (name));
	  if (ret is null)
            ret := vector (name);
          else
            ret := vector_concat (ret, vector (name));
	}
    }
   --dbg_obj_princ ('prop: ', prop, ' tree : ', xml_tree (prop) , ' propname: ', propname, ' allprop: ', allprop);
  return ret;
}
;

create procedure WS.WS.CALENDAR_NAMES (in _body varchar)
{
	declare prop, propname, allprop, tree, tmp, ret any;
	declare ix, len, sc integer;
	declare name varchar;
	if (not isstring(_body) or _body = '')
		return null;
	prop := string_output ();
	propname := string_output ();
	allprop := string_output ();
	tree := xml_tree_doc (xml_expand_refs (xml_tree (_body)));
	http_value (xpath_eval ('//calendar-multiget/prop', tree , 1), null, prop);
	http_value (xpath_eval ('//calendar-multiget/propname', tree , 1), null, propname);
	http_value (xpath_eval ('//calendar-multiget/allprop', tree , 1), null, allprop);
	prop := string_output_string (prop);
	propname := string_output_string (propname);
	allprop := string_output_string (allprop);
	ret := null;
	if (allprop <> '')
		return vector ('allprop');
	else if (propname <> '')
		return vector ('propname');
	else if (prop <> '')
	{
		declare xp any;
		tree := xtree_doc (prop);
		xp := xpath_eval('/prop/*', tree, 0);
		foreach (any elm in xp) do
		{
			name := cast (xpath_eval ('name()', elm) as varchar);
			sc := strrchr (name, ':');
			if (sc is not null and (name like 'DAV::%'
				or name like 'http://www.openlinksw.com/virtuoso/webdav/1.0/:%'))
				name := subseq (name, sc, length (name));
			if (ret is null)
				ret := vector (name);
			else
				ret := vector_concat (ret, vector (name));
		}
	}
	return ret;
}
;

create procedure WS.WS.ADDRESSBOOK_NAMES (in _body varchar)
{
	declare prop, propname, allprop, tree, tmp, ret any;
	declare ix, len, sc integer;
	declare name varchar;
	if (not isstring(_body) or _body = '')
		return null;
	prop := string_output ();
	propname := string_output ();
	allprop := string_output ();
	tree := xml_tree_doc (xml_expand_refs (xml_tree (_body)));
	http_value (xpath_eval ('//addressbook-multiget/prop', tree , 1), null, prop);
	http_value (xpath_eval ('//addressbook-multiget/propname', tree , 1), null, propname);
	http_value (xpath_eval ('//addressbook-multiget/allprop', tree , 1), null, allprop);
	prop := string_output_string (prop);
	propname := string_output_string (propname);
	allprop := string_output_string (allprop);
	ret := null;
	if (allprop <> '')
		return vector ('allprop');
	else if (propname <> '')
		return vector ('propname');
	else if (prop <> '')
	{
		declare xp any;
		tree := xtree_doc (prop);
		xp := xpath_eval('/prop/*', tree, 0);
		foreach (any elm in xp) do
		{
			name := cast (xpath_eval ('name()', elm) as varchar);
			sc := strrchr (name, ':');
			if (sc is not null and (name like 'DAV::%'
				or name like 'http://www.openlinksw.com/virtuoso/webdav/1.0/:%'))
				name := subseq (name, sc, length (name));
			if (ret is null)
				ret := vector (name);
			else
				ret := vector_concat (ret, vector (name));
		}
	}
	return ret;
}
;


create procedure WS.WS.REPORT (in path varchar, inout params varchar, in lines varchar)
{
	declare _mod_time datetime;
	declare _cr_time datetime;
	declare _depth integer;
	declare st, _temp varchar;
	declare _ms_date integer;
	declare _lpath, _body, _ses, _props, _ppath, _perms varchar;
	declare uname, upwd varchar;
	declare id any;
	declare _u_id, _g_id, rc, is_calendar, is_addressbook integer;
	_ses := aref_set_0 (params, 1);
	_body := string_output_string (_ses);
	_lpath := http_path ();
	_ppath := http_physical_path ();
	is_calendar := 0;
	is_addressbook := 0;
	if (_lpath = '')
		_lpath := '/';
	id := DAV_HIDE_ERROR (DAV_SEARCH_ID (vector_concat (vector(''), path, vector('')), 'C'));
	if (id is not null)
	{
		if (isarray(id) = 1)
		{
			if (id[0] = UNAME'CalDAV')
				is_calendar := 1;
			else if (id[0] = UNAME'CardDAV')
				is_addressbook := 1;
		}
		st := 'C';
	}
	else
	{
		id := DAV_HIDE_ERROR (DAV_SEARCH_ID (vector_concat (vector(''), path), 'R'));
		if (id is null)
		{
      DB.DBA.DAV_SET_HTTP_STATUS (404);
			return;
		}
		st := 'R';
	}
	_u_id := null;
	_g_id := null;
	if (st = 'C')
	{
		rc := DAV_AUTHENTICATE_HTTP (id, st, '1__', 1, lines, uname, upwd, _u_id, _g_id, _perms);
	}
	else
	{
		rc := DAV_AUTHENTICATE_HTTP (DAV_GET_PARENT (id, st, _ppath), 'C', '1__', 1, lines, uname, upwd, _u_id, _g_id, _perms);
	}
	if (rc < 0)
	{
    DB.DBA.DAV_SET_AUTHENTICATE_HTTP_STATUS (rc);
		return;
	}
	if (strstr (WS.WS.FINDPARAM (lines, 'User-Agent:'), 'Microsoft') is not null)
		_ms_date := 1;
	else
		_ms_date := 0;
	_temp := WS.WS.FINDPARAM (lines, 'Depth:');
	if (_temp <> '' and _temp <> 'infinity')
		_depth := atoi (_temp);
	else
		_depth := -1;
	{
		declare test_tree any;
		declare exit handler for sqlstate '*'
		{
      DB.DBA.DAV_SET_HTTP_STATUS (400);
			return;
		};
		if (length (_body) > 0)
			test_tree := xml_tree (_body);
	}
	if (st = 'C' and aref (_lpath, length (_lpath) - 1) <> ascii ('/'))
		_lpath := concat (_lpath, '/');
	-- Any properties
	if (is_calendar = 1)
		_props := WS.WS.CALENDAR_NAMES (_body);
	else if (is_addressbook = 1)
		_props := WS.WS.ADDRESSBOOK_NAMES (_body);
	else
		_props := WS.WS.PROPNAMES (_body);
	if (isarray (_props) and length (_props) = 1 and (aref (_props, 0) = 'propname'))
	{
		WS.WS.CUSTOM_PROP (_lpath, _props, _depth, st);
		return;
	}
	http_request_status ('HTTP/1.1 207 Multi-Status');
	if (is_calendar = 1)
	{
		declare urls any;
		urls := xpath_eval ('[xmlns:D="DAV:" xmlns="urn:ietf:params:xml:ns:caldav:"] //calendar-multiget/D:href/text()', xml_tree_doc (xml_expand_refs (xml_tree (_body))), 0);
		http_header ('DAV: 1, calendar-access, calendar-schedule, calendar-proxy\r\nContent-type: application/xml; charset="utf-8"\r\n');
		http ('<?xml version="1.0" encoding="utf-8"?>\n');
		http ('<D:multistatus xmlns:D="DAV:" xmlns:M="urn:uuid:c2f41010-65b3-11d1-a29f-00aa00c14882/">\n');
		foreach (any prop in urls) do
		{
			if (-13 = WS.WS.REPORT_RESPONSE (cast(prop as varchar), _ppath, _depth, st, _ms_date, _props, _u_id))
			{
				_u_id := null;
				_g_id := null;
				-- This will force 'Unauthorized'
				http_rewrite ();
				WS.WS.GET_DAV_AUTH (lines, 0, 1, uname, upwd, _u_id, _g_id, _perms);
				return;
			}
		}
		http ('</D:multistatus>\n');
	}
	else if (is_addressbook = 1)
	{
		declare urls any;
		urls := xpath_eval ('[xmlns:D="DAV:" xmlns="urn:ietf:params:xml:ns:carddav:"] //addressbook-multiget/D:href/text()', xml_tree_doc (xml_expand_refs (xml_tree (_body))), 0);
		http_header ('DAV: 1, addressbook\r\nContent-type: application/xml; charset="utf-8"\r\n');
		http ('<?xml version="1.0" encoding="utf-8"?>\n');
		http ('<D:multistatus xmlns:D="DAV:" xmlns:M="urn:uuid:c2f41010-65b3-11d1-a29f-00aa00c14882/">\n');
		foreach (any prop in urls) do
		{
			if (-13 = WS.WS.REPORT_RESPONSE (cast(prop as varchar), _ppath, _depth, st, _ms_date, _props, _u_id))
			{
				_u_id := null;
				_g_id := null;
				-- This will force 'Unauthorized'
				http_rewrite ();
				WS.WS.GET_DAV_AUTH (lines, 0, 1, uname, upwd, _u_id, _g_id, _perms);
				return;
			}
		}
		http ('</D:multistatus>\n');
	}
	else
	{
		http_header ('Content-type: text/xml; charset="utf-8"\r\n');
		http ('<?xml version="1.0" encoding="utf-8"?>\n');
		http ('<D:multistatus xmlns:D="DAV:" xmlns:M="urn:uuid:c2f41010-65b3-11d1-a29f-00aa00c14882/">\n');
		if (-13 = WS.WS.PROPFIND_RESPONSE (_lpath, _ppath, _depth, st, _ms_date, _props, _u_id))
		{
			_u_id := null;
			_g_id := null;
			-- This will force 'Unauthorized'
			http_rewrite ();
			WS.WS.GET_DAV_AUTH (lines, 0, 1, uname, upwd, _u_id, _g_id, _perms);
			return;
		}
		http ('</D:multistatus>\n');
	}
}
;

--#IF VER=5
--!AFTER
--#ENDIF
create function WS.WS.REPORT_RESPONSE (
	in lpath varchar,
    in ppath varchar,
	in depth integer,
	in st char (1),
	in ms_date integer,
	in propnames any,
	in u_id integer) returns integer
{
	declare all_prop, ppath_len integer;
	declare dirlist any;
	declare add_not_found, _this_col integer;
	all_prop := 0;
	add_not_found := 1;
	if (not isstring (lpath) or not isstring (ppath))
		return -28;
	if (st = 'C' and aref (ppath, length (ppath) - 1) <> ascii ('/'))
		ppath := concat (ppath, '/');
	ppath_len := length (ppath);
	if (not isarray (propnames))
	{
		if (ms_date)
		{
			propnames := vector (':getlastmodified', ':creationdate',
				':lastaccessed', ':getcontentlength', ':resourcetype', ':supportedlock');
			add_not_found := 0;
		}
		else
			propnames := vector (':getlastmodified', ':getcontentlength', ':resourcetype');
	}
	else if (aref (propnames, 0) = 'allprop')
	{
		propnames := vector (':getlastmodified', ':creationdate', ':getetag', ':getcontenttype',
			':getcontentlength', ':resourcetype', ':lockdiscovery', ':supportedlock');
		all_prop := 1;
	}
	dirlist := DAV_DIR_LIST_INT (ppath, -1, '%', null, null, u_id);
	if (isinteger (dirlist))
	{
		if (dirlist = -13)
		{
			if (u_id > 0)
				dirlist := vector ();
			else
				return dirlist;
		}
		else
			dirlist := vector (); -- TODO: This is a stub. It should be turned into something better.
	}
	if (length (dirlist) = 0)
	{
		return -1;
	}
	WS.WS.PROPFIND_RESPONSE_FORMAT (lpath, dirlist, 0, ms_date, propnames, all_prop, add_not_found, 0, u_id);
	return 0;
}
;

create procedure WS.WS.CUSTOM_PROP (in lpath any, in prop any, in depth integer, in st char (1))
{
  declare _name, _lmask, _prop, _ltype, _lscope, _lown, _ltoken, _tp, _pname varchar;
  declare _id, _ltimeout, _sc integer;
  declare c cursor for select COL_NAME, COL_ID from WS.WS.SYS_DAV_COL where COL_ID = DAV_HIDE_ERROR_OR_DET (DAV_SEARCH_PATH (_lmask, 'C'), null, null);
  declare r cursor for select RES_NAME, RES_ID from WS.WS.SYS_DAV_RES where RES_FULL_PATH = _lmask;
  declare p cursor for select PROP_NAME from WS.WS.SYS_DAV_PROP where PROP_TYPE = _tp and PROP_PARENT_ID = _id;

  -- dbg_obj_princ ('WS.WS.CUSTOM_PROP (', lpath, prop, depth, st, ')');
  _name := '';
  -- there should be cycle
  _prop := aref (prop, 0);
  if (_prop <> 'propname')
    {
      DB.DBA.DAV_SET_HTTP_STATUS (501);
      return;
    }
  _lmask := http_physical_path ();
  if (st = 'C' and aref (_lmask, length (_lmask) - 1) <> ascii ('/'))
    _lmask := concat (_lmask, '/');

  whenever not found goto nf;
  if (st = 'C')
    {
      _tp := 'C';
      open c (prefetch 1);
      fetch c into _name, _id;
      close c;
    }
  else
    {
      _tp := 'R';
      open r (prefetch 1);
      fetch r into _name, _id;
      close r;
    }
nf:

  http_request_status ('HTTP/1.1 207 Multi-Status');
  http_header ('Content-type: text/xml\r\n');
  http ('<?xml version="1.0"?>\n');
  http ('<D:multistatus xmlns:D="DAV:" xmlns:V="http://www.openlinksw.com/virtuoso/webdav/1.0/">\n');
      http ('<D:response xmlns:lp0="DAV:" xmlns:i0="DAV:">\n');
      -- http ('<D:href>'); http_dav_url (lpath); http ('</D:href>\n');
      http (sprintf ('<D:href>%V</D:href>\n', charset_recode (lpath, 'UTF-8', '_WIDE_')));
	    http ('<D:propstat>\n');
	      http ('<D:prop>\n');
	      if (_prop = 'propname')
		{
		  if (st = 'R')
		    http ('<D:getcontenttype/>\n<lp0:getcontentlength/>\n<lp0:getetag/>\n');
		  http ('<lp0:creationdate/>\n<lp0:getlastmodified/>\n');
		  http ('<D:lockdiscovery/>\n<D:supportedlock/>\n<D:resourcetype/>\n');
		  whenever not found goto nfp;
		  open p (prefetch 1);
		  while (1)
		   {
		     fetch p into _pname;
                     _sc := strrchr (_pname, ':');
		     if (_sc is not null)
	               _pname := subseq (_pname, _sc + 1, length(_pname));
		     http (concat ('<V:', cast (_pname as varchar),'/>\n'));
		   }
                  nfp:
		  close p;
		}
	      http ('</D:prop>\n');
	      http ('<D:status>HTTP/1.1 200 OK</D:status>');
	    http ('</D:propstat>\n');
      http ('</D:response>\n');
  http ('</D:multistatus>\n');
}
;
-- /* PROPPATCH method */
create procedure WS.WS.PROPPATCH (in path varchar, inout params varchar, in lines varchar)
{
  -- dbg_obj_princ ('WS.WS.PROPPATCH (', path, params, lines, ')');
  declare _u_id, _g_id, _slen, _len, _ix, id, _pid, _ix1, is_calendar, is_addressbook integer;
  declare uname, upwd, st, _perms, _body, _name varchar;
  declare _ses, _set, _del, _tmp, _val any;
  declare rc, acc, _proprc, xtree, prop_path any;

  is_addressbook := 0;
  is_calendar := 0;
  id := DAV_HIDE_ERROR (DAV_SEARCH_ID (vector_concat (vector(''), path, vector('')), 'C'));
	if (id is not null)
	{
		if (isarray(id) = 1)
		{
			if (id[0] = UNAME'CalDAV')
				is_calendar := 1;
			if (id[0] = UNAME'CardDAV')
				is_addressbook := 1;
		}
		st := 'C';
    prop_path := DB.DBA.DAV_CONCAT_PATH (vector_concat (vector(''), path, vector('')), null);
	}
  else
  {
    id := DAV_HIDE_ERROR (DAV_SEARCH_ID (vector_concat (vector(''), path), 'R'));
    if (id is null)
    {
      DB.DBA.DAV_SET_HTTP_STATUS (404);
      return;
    }
    st := 'R';
    prop_path := DB.DBA.DAV_CONCAT_PATH (vector_concat (vector(''), path), null);
  }
  _u_id := null;
  _g_id := null;
  rc := DAV_AUTHENTICATE_HTTP (id, st, '11_', 1, lines, uname, upwd, _u_id, _g_id, _perms);
  -- dbg_obj_princ ('Authentication in PROPPATCH gives ', rc, uname, upwd, _u_id, _g_id, _perms);
	if (rc < 0)
	{
    DB.DBA.DAV_SET_AUTHENTICATE_HTTP_STATUS (rc);
		return;
	}

  rc := string_output ();
  _ses := aref_set_0 (params, 1);
  _body := string_output_string (_ses);
  --dbg_obj_princ ('PROPPATCH body is ', _body);
  xtree := xml_tree (_body, 0);
  if (not isarray (xtree))
  {
    DB.DBA.DAV_SET_HTTP_STATUS (400);
    return;
  }
  if (WS.WS.ISLOCKED (vector_concat (vector (''), path), lines, _u_id))
  {
    DB.DBA.DAV_SET_HTTP_STATUS (423);
    return;
  }

  xte_nodebld_init (acc);
  http_request_status ('HTTP/1.1 207 Multi-Status');
  http ('<?xml version="1.0" encoding="utf-8" ?>\n', rc);
  http ('<D:multistatus xmlns:D="DAV:">\n', rc);
  http ('<D:response>\n', rc);
  http ('<D:propstat>\n', rc);

  declare xtd, prop_set any;
  declare i, l integer;

  xtd := xml_tree_doc (xtree);
  prop_set := xpath_eval('//set/prop/*',xtd,0);
  l := length (prop_set);
  if (l > 0)
    {
      i := 0;
      while (i < l)
	      {
	        declare pa, pn, pns, pv, ps, _prop_name any;

          pa := prop_set[i];
           -- dbg_obj_princ ('set prop_set [', i, '] = ', pa);
          pn := cast (xpath_eval ('local-name(.)', pa) as varchar);
	        _prop_name := pn;
          pns := cast(xpath_eval ('namespace-uri(.)', pa) as varchar);

          ps := string_output ();
	        http_value (pa, null, ps);
          pv := xml_tree (string_output_string (ps));
          if (length (pns) > 0)
            pn := concat (pns, ':', pn);

          xte_nodebld_acc (acc, xte_node (xte_head (pn)));
          if (is_calendar or is_addressbook)
            {
              -- do nothing for now;
              ;
            }
          else if (pns = 'http://www.openlinksw.com/virtuoso/webdav/1.0/' and _prop_name in ('virtpermissions', 'virtowneruid', 'virtownergid'))
            {
              declare tmp, tmp_id any;

              tmp := cast (xpath_eval ('string()', pa) as varchar);
              if (_prop_name = 'virtpermissions')
                {
                  -- execute perms can set only and only dav
                  if ((tmp like '__1%' or tmp like '_____1%' or tmp like '________1%') and _u_id <> http_dav_uid ())
                    goto skip_perm_update;

                  -- bad permission string
                  if (regexp_match (DB.DBA.DAV_REGEXP_PATTERN_FOR_PERM (), tmp) is null)
                    goto skip_perm_update;

                  DAV_PROP_SET_INT (prop_path, ':' || _prop_name, tmp, null, null, 0, 0, 1, _u_id);
               skip_perm_update:;
                }
              else if (_prop_name = 'virtowneruid')
                {
                  tmp_id := (select U_ID from DB.DBA.SYS_USERS where U_NAME = tmp);
                  DAV_PROP_SET_INT (prop_path, ':' || _prop_name, tmp_id, null, null, 0, 0, 1, _u_id);
                }
              else if (_prop_name = 'virtownergid')
                {
                  tmp_id := (select U_ID from DB.DBA.SYS_USERS where U_NAME = tmp);
                  DAV_PROP_SET_INT (prop_path, ':' || _prop_name, tmp_id, null, null, 0, 0, 1, _u_id);
                }
            }
          else
            {
              DAV_PROP_SET_INT (path, pn, serialize(pv[1]), null, null, 0, 0, 1, _u_id);
            }
          i := i + 1;
       }
     }

  prop_set := xpath_eval('//remove/prop/*',xtd,0);

  l := length (prop_set);
  if (l > 0)
    {
      i := 0;
      while (i < l)
        {
          declare pa, pn, pns any;

          pa := prop_set[i];
          -- dbg_obj_princ ('remove prop_set [', i, '] = ', pa);
          pn := cast (xpath_eval ('local-name(.)', pa) as varchar);
          pns := cast(xpath_eval ('namespace-uri(.)', pa) as varchar);

          if (length (pns) > 0)
            pn := concat (pns, ':', pn);

          xte_nodebld_acc (acc, xte_node (xte_head (pn)));
          DAV_PROP_REMOVE_INT (prop_path, pn, null, null, 0, 0);
          i := i + 1;
        }
    }
  acc := xte_nodebld_final (acc);
  _proprc := xte_node_from_nodebld (xte_head ('DAV::prop'), acc);

  http_value (xml_tree_doc (_proprc), null, rc);
  http ('<D:status>HTTP/1.1 200 OK</D:status>\n', rc);
  http ('</D:propstat>\n', rc);
  http ('</D:response>\n', rc);
  http ('</D:multistatus>\n', rc);
  http_header ('Content-Type: text/xml\r\n');
  http (string_output_string (rc));
}
;

create procedure WS.WS.FINDPARAM (inout params varchar, in pkey varchar)
{
  declare ret any;
  declare i, l integer;
  if (pkey is null)
    return '';
  i := 0; l := length (params);
  pkey := rtrim (pkey,': ');
  while (i < l)
    {
      ret := http_request_header (vector (params[i]), pkey, NULL, NULL);
      if (ret is not null)
        return ret;
      i := i + 1;
    }
  return '';
}
;

create procedure WS.WS.MKCOL (in path varchar, inout params varchar, in lines varchar)
{
  declare _parent_name varchar;
  declare _col_id, rc integer;
  declare _perms varchar;
  declare _col_parent_id integer;
  declare uname, upwd varchar;
  declare _u_id, _g_id integer;
  declare ses, ses_str any;

  -- dbg_obj_princ ('WS.WS.MKCOL (', path, params, lines, ')');
  _col_parent_id := DAV_HIDE_ERROR (DAV_SEARCH_ID (vector_concat (vector(''), path, vector('')), 'P'));
  _col_id := DAV_HIDE_ERROR (DAV_SEARCH_ID (vector_concat (vector(''), path, vector('')), 'C'));
  _u_id := null;
  _g_id := null;
  if (_col_parent_id is not null)
  {
    -- dbg_obj_princ ('MKCOL has _col_parent_id=', _col_parent_id);
    rc := DAV_AUTHENTICATE_HTTP (_col_parent_id, 'C', '11_', 1, lines, uname, upwd, _u_id, _g_id, _perms);
    -- dbg_obj_princ ('Authentication in MKCOL gives ', rc, uname, upwd, _u_id, _g_id, _perms);
  	if (rc < 0)
  	{
      DB.DBA.DAV_SET_AUTHENTICATE_HTTP_STATUS (rc);
  		return;
  	}
  }
  ses := aref_set_0 (params, 1);
  ses_str := string_output_string (ses);
  if (length (ses_str) > 0)
  {
    DB.DBA.DAV_SET_HTTP_STATUS (415);
    return;
  }
  rc := DAV_COL_CREATE_INT ('/' || DAV_CONCAT_PATH (path, '/'), _perms, null, null, null, null, 1, 0, 1, _u_id, _g_id);
  -- dbg_obj_princ ('DAV_COL_CREATE_INT returned ', rc, ' of type ', __tag (rc));
  if (DAV_HIDE_ERROR (rc) is not null)
  {
    commit work;
    http_request_status ('HTTP/1.1 201 Created');
    http_header('Link: <>;rel=<http://www.w3.org/ns/ldp/Container>\r\n');
  }
  else if (rc = -24)
  {
    ;
  }
  else if (rc = -25)
  {
    DB.DBA.DAV_SET_HTTP_STATUS (409);
  }
  else if (rc = -8)
  {
    DB.DBA.DAV_SET_HTTP_STATUS (423);
  }
  else if ((rc = -12) or (rc = -13))
  {
    DB.DBA.DAV_SET_HTTP_STATUS (403);
  }
  else
  {
    DB.DBA.DAV_SET_HTTP_STATUS (405);
  }
  return;
}
;

-- Return position beginning with 1 of founded collection and col_id
create procedure WS.WS.FINDCOL (in path any, out col integer)
{
  declare inx integer;
  declare depth integer;
  declare parent_id integer;
  declare det, cname varchar;

  inx := 0;
  depth := length (path);
  whenever not found goto not_found;
  while (inx < depth)
  {
    cname := aref (path, inx);
    select COL_ID, COL_DET into parent_id, det from WS.WS.SYS_DAV_COL where COL_NAME = cname and COL_PARENT = parent_id;
    if (det is not NULL)
      signal ('37000', sprintf ('WS.WS.FINDCOL() is used to access special DAV collection of type "%s"', det));
    col := parent_id;
    inx := inx + 1;
  }

not_found:
  return inx;
}
;

-- Return 1 found, 0 not found, -1 unparsed col, col - collection, name name of resource
create procedure WS.WS.FINDRES (in path varchar,out _col integer, out _name varchar)
{
  declare depth integer;
  declare col integer;
  declare name varchar;
  declare rc integer;
  declare res_inx integer;
  declare id integer;

  rc := 0;
  res_inx := length (path);
  col := 0;
  name := aref (path, res_inx - 1);
  if (res_inx < 1) rc := 0;
    depth := WS.WS.FINDCOL (path, col);
  if (depth = res_inx)
    return 0;
  if (depth < res_inx - 1)
    return -1;

  whenever not found goto not_found;
  select RES_ID into id from WS.WS.SYS_DAV_RES where RES_NAME = name and RES_COL = col;

  if (id is null)
    return 0;

  if (id > 0)
    {
      rc := 1;
      _col := col;
      _name := name;
    }
not_found:
  return rc;
}
;

-- Delete all children resources and collections with given parent_id
create procedure WS.WS.DELCHILDREN (in id integer, in lines varchar)
{
  declare col, res, r_id, n_locks, rc integer;
  declare name, if_token varchar;
  declare icol integer;
  declare cname varchar;
  declare c_cur cursor for select COL_ID, COL_NAME from WS.WS.SYS_DAV_COL where COL_PARENT = id;
  declare r_cur cursor for select RES_ID, RES_NAME from WS.WS.SYS_DAV_RES where RES_COL = id;

  select count (COL_ID) into col from WS.WS.SYS_DAV_COL where COL_PARENT = id;
  select count (RES_ID) into res from WS.WS.SYS_DAV_RES where RES_COL = id;
  if_token := WS.WS.FINDPARAM (lines, 'If:');
  if (isnull (if_token))
    if_token := '';
  if (res > 0)
    {
      whenever not found goto del_res_end;
      open r_cur;
      while (1)
	{
	  fetch r_cur into r_id, name;
	  select count (LOCK_TOKEN) into n_locks from WS.WS.SYS_DAV_LOCK where
	      LOCK_PARENT_TYPE = 'R' and LOCK_PARENT_ID = r_id and isnull (strstr (if_token, LOCK_TOKEN));
	  if (n_locks > 0)
	    {
              http_header ('Content-type: text/xml; charset="utf-8"\r\n');
	      http (concat (
		    '<?xml version="1.0" encoding="utf-8" ?>',
		    '<d:multistatus xmlns:d="DAV:">',
		    '<d:response>',
		    '<d:href>')); http_dav_url (name); http(concat ('</d:href>',
		    '<d:status>HTTP/1.1 423 Locked</d:status>',
		    '</d:response>',
		    '</d:multistatus>'
		    ));
	      return 1;
	    }
	  delete from WS.WS.SYS_DAV_RES where RES_ID = r_id;
	  delete from WS.WS.SYS_DAV_LOCK where LOCK_PARENT_TYPE = 'R' and LOCK_PARENT_ID = r_id;
	}
del_res_end:
      close r_cur;
    }

  if (col > 0)
    {
      whenever not found goto del_col_end;
      open c_cur;
      while (1)
	{
          fetch c_cur into icol, cname;
	  select count (LOCK_TOKEN) into n_locks from WS.WS.SYS_DAV_LOCK where
	      LOCK_PARENT_TYPE = 'C' and LOCK_PARENT_ID = icol and isnull (strstr (if_token, LOCK_TOKEN));
	  if (n_locks > 0)
	    {
              http_header ('Content-type: text/xml; charset="utf-8"\r\n');
	      http (concat (
		    '<?xml version="1.0" encoding="utf-8" ?>',
		    '<d:multistatus xmlns:d="DAV:">',
		    '<d:response>',
		    '<d:href>')); http_dav_url (cname); http(concat ('</d:href>',
		    '<d:status>HTTP/1.1 423 Locked</d:status>',
		    '</d:response>',
		    '</d:multistatus>'
		    ));
	      return 1;
	    }
          rc := WS.WS.DELCHILDREN (icol, lines);
	  if (rc > 0)
	    {
	      return 1;
	    }
	  delete from WS.WS.SYS_DAV_COL where COL_PARENT = id and COL_NAME = cname;
          delete from WS.WS.SYS_DAV_LOCK where LOCK_PARENT_TYPE = 'C' and LOCK_PARENT_ID = icol;
	}
del_col_end:
      close c_cur;
    }
  return 0;
}
;


create procedure WS.WS."DELETE" (in path varchar, inout params varchar, in lines varchar)
{
  declare depth, len integer;
  declare src_id any;
  declare uname, upwd, _perms varchar;
  declare rc integer;
  declare res integer;
  declare u_id, g_id integer;
  declare what varchar;

  uname := null;
  upwd := null;
  u_id := null;
  g_id := null;

  set isolation = 'serializable';
  if ((length(path) > 1) and ('' = path[length(path)-1]))
  {
    what := 'C';
    src_id := DAV_HIDE_ERROR (DAV_SEARCH_ID (vector_concat (vector(''), path, vector('')), 'C'));
  }
  else
  {
    src_id := DAV_HIDE_ERROR (DAV_SEARCH_ID (vector_concat (vector(''), path, vector('')), 'C'));
    if (src_id is not null)
    {
      what := 'C';
      path := vector_concat (path, vector (''));
    }
    else
    {
      what := 'R';
      src_id := DAV_HIDE_ERROR (DAV_SEARCH_ID (vector_concat (vector(''), path), 'R'));
    }
  }
  -- dbg_obj_princ ('WS.WS."DELETE" with path ', path, ' is of type ', what, ' http_path() is ', http_path());
  if (src_id is null)
  {
    DB.DBA.DAV_SET_HTTP_STATUS (404);
    return;
  }
  rc := DAV_AUTHENTICATE_HTTP (src_id, what, '11_', 1, lines, uname, upwd, u_id, g_id, _perms);
  -- dbg_obj_princ ('Authentication in WS.WS."DELETE" gives ', rc, uname, upwd, u_id, g_id, _perms);
  if (rc < 0)
	{
    DB.DBA.DAV_SET_AUTHENTICATE_HTTP_STATUS (rc);
    return;
	}

  rc := DAV_DELETE_INT (DAV_CONCAT_PATH ('/', path), 1, null, null, 0);
  if (rc >= 0)
  {
    DB.DBA.DAV_SET_HTTP_STATUS (204);
  }
  else if (rc = -8)
  {
    DB.DBA.DAV_SET_HTTP_STATUS (423);
  }
  else
  {
    DB.DBA.DAV_SET_HTTP_STATUS (500);
  }
  return;
}
;

-- return 1 if it is a collection
create procedure WS.WS.ISCOL (in path varchar)
{
  declare depth, len, col integer;
  depth := WS.WS.FINDCOL (path, col);
  len := length (path);
  if (depth = len)
    return 1;
  else
    return 0;
}
;


-- return 1 if it is a resource
create procedure WS.WS.ISRES (in path varchar)
{
  declare col, rc integer;
  declare name varchar;
  rc := WS.WS.FINDRES (path, col, name);
  if (rc < 0)
    rc := 0;
  return (rc);
}
;

-- generate Etag for resources
create procedure WS.WS.ETAG (in name varchar, in col integer, in modt any)
{
  declare etag, full_path varchar;
  declare mtime datetime;
  declare msize integer;
  declare id integer;
  etag := sprintf ('%d-%s-%d',rnd(1000),cast (now() as varchar), rnd (1000));
  if (isvector(col) = 1)
    goto etag_err;
--  whenever not found goto etag_err;
--  select RES_ID, RES_MOD_TIME, length (RES_CONTENT), RES_FULL_PATH into
--    id, mtime, msize, full_path from WS.WS.SYS_DAV_RES where RES_NAME = name and RES_COL = col;
--  etag := sprintf ('%d-%s-%d-%s-%s', id, cast (mtime as varchar), msize, name, full_path);
  etag := sprintf ('%d-%s-%s', col, cast (modt as varchar), name);
etag_err:
  etag := md5 (etag);
  return etag;
}
;

-- /* HEAD METHOD, same as GET except body is not sent */
create procedure WS.WS.HEAD (in path varchar, inout params varchar, in lines varchar)
{
  -- dbg_obj_princ ('WS.WS.HEAD (', path, params, lines, ')');
  WS.WS.GET (path, params, lines);
  return;
}
;

--#IF VER=5
--!AFTER
--#ENDIF
create procedure WS.WS.PUT (in path varchar, inout params varchar, in lines varchar)
{
  declare rc, _col_parent_id integer;
  declare id integer;
  declare content_type varchar;
  declare _col integer;
  declare _name varchar;
  declare _cont_len integer;
  declare full_path, _perms, uname, upwd varchar;
  declare _u_id, _g_id integer;
  declare location varchar;
  declare ses any;
  --set isolation = 'serializable';

  ses := aref_set_0 (params, 1);

  whenever sqlstate '*' goto error_ret;

-- As instructed by Orri, loop retries are removed
--deadlock_retry:

  WS.WS.IS_REDIRECT_REF (path, lines, location);
  path := WS.WS.FIXPATH (path);
  full_path := DAV_CONCAT_PATH ('/', path);
  _u_id := null;
  _g_id := null;
  _col_parent_id := DAV_HIDE_ERROR (DAV_SEARCH_ID (vector_concat (vector(''), path, vector('')), 'P'));
  if (_col_parent_id is not null)
    {
       --dbg_obj_princ ('WS.WS.PUT has _col_parent_id=', _col_parent_id);
      rc := DAV_AUTHENTICATE_HTTP (_col_parent_id, 'C', '11_', 1, lines, uname, upwd, _u_id, _g_id, _perms);
       --dbg_obj_princ ('Authentication in WS.WS.PUT gives ', rc, uname, upwd, _u_id, _g_id, _perms);
      if (rc < 0)
        goto error_ret;
    }
  else
    {
    DB.DBA.DAV_SET_HTTP_STATUS (409);
      return;
    }
  if (WS.WS.ISLOCKED (vector_concat (vector (''), path), lines, _u_id))
    {
    DB.DBA.DAV_SET_HTTP_STATUS (423);
      return;
    }
  content_type := WS.WS.FINDPARAM (lines, 'Content-Type:');
  if (content_type = '')
  {
    content_type := http_mime_type (full_path);
  }
  _cont_len := atoi (WS.WS.FINDPARAM (lines, 'Content-Length:'));
  if ((full_path like '%.vsp' or full_path like '%.vspx') and _cont_len > 0)
    {
      content_type := 'text/html';
    }
   --dbg_obj_princ ('content_type=', content_type, ',  _cont_len=', _cont_len);

  rc := -28;
  rc := DAV_RES_UPLOAD_STRSES_INT (full_path, ses, content_type, _perms, uname, null, uname, upwd, 0, now(), now(), null, _u_id, _g_id, 0, 1);
  --dbg_obj_princ ('DAV_RES_UPLOAD_STRSES_INT returned ', rc, ' of type ', __tag (rc));
  if (DAV_HIDE_ERROR (rc) is not null)
    {
      commit work;
      http_request_status ('HTTP/1.1 201 Created');
      http_header (sprintf('Content-Type: %s\r\nLink: <>;rel=<http://www.w3.org/ns/ldp/Resource>\r\n', content_type));
    if (content_type = 'application/sparql-query')
	http_header ('MS-Author-Via: SPARQL\r\n');
      else
	http ( concat ('<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML 2.0//EN">',
	    '<HTML><HEAD>',
	    '<TITLE>201 Created</TITLE>',
	    '</HEAD><BODY>', '<H1>Created</H1>',
        'Resource ', sprintf ('%V', full_path),' has been created.</BODY></HTML>')
      );

      return;
    }
error_ret:
   -- dbg_obj_princ ('PUT get error: ', __SQL_STATE, __SQL_MESSAGE);

  if (__SQL_STATE = '40001')
    {
      rollback work;
-- As instructed by Orri, loop retries are removed
--      if (-29 <> rc)
--        goto deadlock_retry;
    }

  http_body_read ();
  DAV_SET_HTTP_REQUEST_STATUS (rc);
}
;

-- PATCH METHOD
create procedure WS.WS.PATCH (in path any, inout params any, in lines any)
{
  declare rc, _col_parent_id integer;
  declare id integer;
  declare content_type varchar;
  declare _col integer;
  declare _name varchar;
  declare _cont_len integer;
  declare full_path, _perms, uname, upwd varchar;
  declare _u_id, _g_id integer;
  declare location varchar;
  declare ses any;

  ses := aref_set_0 (params, 1);

  whenever sqlstate '*' goto error_ret;
-- As instructed by Orri, loop retries are removed
--deadlock_retry:

  WS.WS.IS_REDIRECT_REF (path, lines, location);
  path := WS.WS.FIXPATH (path);
  full_path := DAV_CONCAT_PATH ('/', path);
  _u_id := null;
  _g_id := null;
  _col_parent_id := DAV_HIDE_ERROR (DAV_SEARCH_ID (vector_concat (vector(''), path, vector('')), 'P'));
  if (_col_parent_id is not null)
    {
      rc := DAV_AUTHENTICATE_HTTP (_col_parent_id, 'C', '11_', 1, lines, uname, upwd, _u_id, _g_id, _perms);
      if (rc < 0)
        goto error_ret;
    }
  else
    {
    DB.DBA.DAV_SET_HTTP_STATUS (409);
      return;
    }
  if (WS.WS.ISLOCKED (vector_concat (vector (''), path), lines, _u_id))
    {
    DB.DBA.DAV_SET_HTTP_STATUS (423);
      return;
    }
  content_type := WS.WS.FINDPARAM (lines, 'Content-Type:');
  if (content_type = '')
    content_type := http_mime_type (full_path);

  _cont_len := atoi (WS.WS.FINDPARAM (lines, 'Content-Length:'));
  if ((full_path like '%.vsp' or full_path like '%.vspx') and _cont_len > 0)
    {
      content_type := 'text/html';
    }
   --dbg_obj_princ ('content_type=', content_type, ',  _cont_len=', _cont_len);

  rc := -28;
  rc := DAV_RES_UPLOAD_STRSES_INT (full_path, ses, content_type, _perms, uname, null, uname, upwd, 0, now(), now(), null, _u_id, _g_id, 0, 1);
  --dbg_obj_princ ('DAV_RES_UPLOAD_STRSES_INT returned ', rc, ' of type ', __tag (rc));
  if (DAV_HIDE_ERROR (rc) is not null)
    {
      commit work;
    DB.DBA.DAV_SET_HTTP_STATUS (204);

      return;
    }

error_ret:
   --dbg_obj_princ ('PUT get error: ', __SQL_STATE, __SQL_MESSAGE);
  if (__SQL_STATE = '40001')
    {
      rollback work;
-- As instructed by Orri, loop retries are removed
--      if (-29 <> rc)
--        goto deadlock_retry;
    }

  http_body_read ();
  DAV_SET_HTTP_REQUEST_STATUS (rc);

}
;


create procedure WS.WS.HEX_TO_DEC (in c char)
{
  if (c >= '0' and c <= '9')
    return (ascii(c) - ascii('0'));
  if (c >= 'a' and c <= 'f')
    return (10 + ascii(c) - ascii('a'));
  if (c >= 'A' and c <= 'F')
    return (10 + ascii(c) - ascii('A'));
  return 0;
}
;

create procedure WS.WS.STR_TO_URI (in str varchar)
{
  declare tmp varchar;
  declare inx, inx1, len integer;
  declare escapes varchar;
  declare c char;
  escapes := ';?:@&=+ "#%<>';
  len := length (str);
  if (len = 0)
    return '';
  inx := 0;
  inx1 := 0;
  tmp := repeat (' ', len * 3);

  while (inx < len)
    {
      c := chr (aref (str, inx));
      if (not isnull (strchr (escapes, c)))
        {
	  aset (tmp, inx1, ascii('%'));
	  aset (tmp, inx1 + 1, WS.WS.HEX_DIGIT (ascii(c) / 16));
	  aset (tmp, inx1 + 2, WS.WS.HEX_DIGIT (mod (ascii(c), 16)));
          inx1 := inx1 + 2;
	}
       else
        aset (tmp, inx1, ascii(c));
      inx1 := inx1 + 1;
      inx := inx + 1;
    }
  return trim(tmp);
}
;

create procedure WS.WS.PATHREF (in path varchar, in elem integer, in host varchar, out name_len integer)
{
  declare inx, len, pos, inx1 integer;
  declare name varchar;
  declare c, cd1, cd2 char;
  declare nelem integer;
  declare temp varchar;
  declare nslash integer;
  declare lastslash integer;
  declare new_path varchar;

  name_len := 0;
  nslash := 0;
  nelem := elem;
  if (host <> '')
    nelem := nelem + 2;
  temp := path;
  name := '';
  len := length (path);
  inx := 0;
  inx1 := 0;
  lastslash := 0;
  new_path := repeat (' ', len);
  while (inx < len)
    {
      c := chr (aref (path, inx));
	 aset (new_path, inx1, ascii(c));
	 if (c = '%')
	   {
             cd1 := chr(aref (path, inx + 1));
	     cd2 := chr(aref (path, inx + 2));
             aset (new_path, inx1, (WS.WS.HEX_TO_DEC (cd1) * 16) + WS.WS.HEX_TO_DEC (cd2));
             inx := inx + 2;
	   }
	 if (c = '/')
	   {
             nslash := nslash + 1;
             lastslash := inx;
	   }
      inx := inx + 1;
      inx1 := inx1 + 1;
    }

  temp := trim(new_path);


  if (nelem <= nslash)
    nslash := nelem;
  else
    return name;

  while (nslash > 0)
    {
      pos :=  strchr (temp , '/');
      temp := substring (temp, pos+2, len);
      nslash := nslash - 1;
    }
  pos := strchr (temp, '/');

  if (isnull(pos))
    pos := length (temp);

  if ( pos > 0 )
    {
      name := substring (temp, 1, pos);
      name_len := length (name);
    }
  return name;
}
;

create procedure WS.WS.IS_ACTIVE_CONTENT (in f varchar)
{
  declare dot integer;
  declare ext varchar;

  dot := strrchr (f, '.');
  if (dot is null)
    return 0;
  ext := lower (substring (f, dot + 2, length (f)));
  if (ext in ('vsp', 'vspx')
      or __proc_exists (concat ('__http_handler_' , ext), 2)
      or __proc_exists (concat ('WS.WS.__http_handler_' , ext), 1))
    return 1;
  return 0;
}
;

create procedure WS.WS.GET_DAV_DEFAULT_PAGE (inout path any)
{
  -- dbg_obj_princ ('WS.WS.GET_DAV_DEFAULT_PAGE (', path, ')');
  declare _list, path1 any;
  declare _all varchar;
  declare idx, len, line integer;

  _all := http_map_get ('default_page');
  if (not isstring (_all))
    goto brws_check;

  _list :=  split_and_decode (_all, 0, '\0\0;');
  idx := 0;
  len := length (_list);
  while (idx < len)
  {
    line := trim (_list[idx]);
    path1 := vector_concat (path, vector (line)); -- TODO: add code for full_path
    if (DAV_HIDE_ERROR (DAV_SEARCH_ID (DAV_CONCAT_PATH (vector ('/'), path1), 'R')) is not null)
  	{
  	  path := path1;
  	  -- dbg_obj_princ ('Found ', path, ' and return ', line);
  	  return line;
  	}
    idx := idx + 1;
  }
brws_check:
  if (0 = http_map_get ('browseable'))
  {
    declare dp any;

    dp := case when (not isstring (_all)) then '' else sprintf ('Default page (%s) of folder ', _all) end;
    DB.DBA.DAV_SET_HTTP_STATUS (404, null, null, sprintf ('%V%V not found.', dp, http_path ()));
    return null;
  }

  return '';
}
;


create procedure WS.WS.GET_DAV_CHUNKED_QUOTA () returns integer
{
  declare dav_chunked_quota integer;

  dav_chunked_quota := atoi (
   coalesce (
    virtuoso_ini_item_value ('HTTPServer', 'DAVChunkedQuota'),
    '1000000'));
  if (dav_chunked_quota < 1)
    dav_chunked_quota := 1000000;
  return dav_chunked_quota;
}
;

-- GET METHOD

create procedure WS.WS.GET (in path any, inout params any, in lines any)
{
  declare col_depth, path_len integer;
  declare content long varchar;
  declare content_type varchar;
  declare fake_content any;
  declare rc, err integer;
  declare _col integer;
  declare _name, uname, upwd varchar;
  declare _cont_len integer;
  declare full_path varchar;
  declare parent_path varchar;
  declare cont_type, perms varchar;
  declare server_etag, client_etag, rdf_graph varchar;
  declare uid, gid, maxres integer;
  declare p_comm, stat, msg, xpr, sxtag, rxtag, resource_content, str varchar;
  declare resource_owner, exec_safety_level integer;
  declare _res_id , _col_id, is_admin_owned_res integer;
  declare def_page varchar;
  declare asmx_path, auth_opts, webid_check, webid_check_rc, modt any;
  -- dbg_obj_princ ('WS.WS.GET (', path, params, lines, ')');
  -- set isolation='committed';
  if (WS.WS.DAV_CHECK_ASMX (path, asmx_path))
    path := asmx_path;

  def_page := '';
  full_path := http_physical_path ();
  if (full_path = '')
    full_path := '/';
  full_path := WS.WS.DAV_REMOVE_ASMX (full_path);
  -- dbg_obj_princ ('logical path is "', http_path(), '".');
  -- dbg_obj_princ ('physical path is "', full_path, '".');
again:
  _col_id := DAV_HIDE_ERROR (DAV_SEARCH_ID (DAV_CONCAT_PATH (DAV_CONCAT_PATH ('/', full_path), '/'), 'C'));
  _res_id := DAV_HIDE_ERROR (DAV_SEARCH_ID (DAV_CONCAT_PATH ('/', full_path), 'R'));
  exec_safety_level := 0;

  if (_res_id is null and _col_id is null)
  {
    declare meta_path varchar;
    declare meta_id any;
    declare content, type any;

    meta_path := DAV_CONCAT_PATH ('/', full_path);
    if (meta_path like '%,meta')
    {
      meta_path := subseq (meta_path, 0, length (meta_path) - length (',meta'));
      meta_id := DAV_HIDE_ERROR (DAV_SEARCH_ID (meta_path, 'R'));
      if (meta_id is null)
        goto _404;

      rc := DAV_AUTHENTICATE_HTTP (meta_id, 'R', '1__', 1, lines, uname, upwd, uid, gid, perms);
      if ((rc < 0) and (rc <> -1))
        goto _403;

      rc := DAV_RES_CONTENT_META (meta_path, content, type, 0, 0);
      if (DAV_HIDE_ERROR (rc) is null)
        goto _500;

      http_request_status ('HTTP/1.1 200 OK');
      http (content);
    }
    else
    {
    declare procname varchar;
    -- dbg_obj_princ ('full_path=', full_path);
    procname := sprintf ('%s.%s.%s',
    http_map_get ('vsp_qual'), http_map_get ('vsp_proc_owner'), full_path);

   if ( __proc_exists (procname) and
      (cast (registry_get (full_path) as varchar) = 'no_vsp_recompile') and
      (http_map_get ('noinherit') = 1))
   {
     commit work;
     __set_user_id (http_map_get ('vsp_uid'));
     call (procname)(path, params, lines);
     __pop_user_id ();
     return;
   }
    _404:
      DB.DBA.DAV_SET_HTTP_STATUS (404);
    }
    return;
  }
  if (_col_id is not null)
  {
    if (http_path () not like '%/') -- This is for default pages that refer to css in same directory and the like.
    {
      declare url_pars varchar;
      url_pars := http_request_get ('QUERY_STRING');
      if (length (url_pars))
        url_pars := '?' || url_pars;

      http_request_status ('HTTP/1.1 301 Moved Permanently');
      http_header (sprintf ('Location: %s/%s\r\n', http_path (), url_pars));
      return (0);
    }
    def_page := WS.WS.GET_DAV_DEFAULT_PAGE (path);
    if (def_page is null)
      return;

    if (def_page <> '')
    {
      declare new_path varchar;
      new_path := DAV_CONCAT_PATH (http_path (), def_page);
      full_path := DAV_CONCAT_PATH (full_path, def_page);
      http_internal_redirect (new_path);
      goto again;
    }
  }

  if (not (http_map_get ('executable')
           --and WS.WS.IS_ACTIVE_CONTENT (http_path ())
     ))
  {
    declare tgt_type, tgt_perms varchar;
    declare tgt_id integer;
    -- dbg_obj_princ ('this is not executable');
    uname := null;
    upwd := null;
    uid := null;
    tgt_perms := '1__';
    if (_col_id is not null)
    {
      tgt_type := 'C';
      tgt_id := _col_id;
      if (get_keyword ('a', params) in ('new', 'create', 'upload', 'link', 'update'))
        tgt_perms := '_1_';
    }
    else
    {
      tgt_type := 'R';
      tgt_id := _res_id;
      if (get_keyword ('a', params) in ('update', 'edit'))
        tgt_perms := '_1_';
    }
    rc := DAV_AUTHENTICATE_HTTP (tgt_id, tgt_type, tgt_perms, 1, lines, uname, upwd, uid, gid, perms);
    if ((rc < 0) and (rc <> -1))
    {
      if (-24 <> rc)
      {
      _403:
        DB.DBA.DAV_SET_HTTP_STATUS (403, null, null, 'You are not permitted to view the content of this location: ' || sprintf ('%V', http_path ()), 1);
      }
      return;
    }
    if (_col_id is null and (rc >= 0))
    {
      if (uid = http_nobody_uid () and gid = http_nogroup_gid ())
        uid := null;
      rc := DAV_AUTHENTICATE_HTTP (tgt_id, tgt_type, '1_1', 0, lines, uname, upwd, uid, gid, perms);
      if (rc >= 0)
        exec_safety_level := 1;
    }
  }
  http_rewrite (0);

  -- execute + webid
  auth_opts := http_map_get ('auth_opts');

  if (isvector (auth_opts) and mod (length (auth_opts), 2) = 0)
    webid_check := atoi (get_keyword ('webid_check', auth_opts, '0'));
  else
    webid_check := 0;
  webid_check_rc := 1;
  if (is_https_ctx () and webid_check and http_map_get ('executable'))
  {
    declare gid, perms, _check_id, _check_type any;
    uid := null;
    if (isinteger (_res_id))
    {
      _check_id := _res_id;
      _check_type := 'R';
    }
    else
    {
      _check_id := _col_id;
      _check_type := 'C';
    }
    webid_check_rc := DAV_AUTHENTICATE_HTTP (_check_id, _check_type, '1__', 1, lines, uname, upwd, uid, gid, perms);
    if ((webid_check_rc < 0) and (webid_check_rc <> -1))
      return 0;
  }
  http_rewrite (0);
  if (_col_id is not null and http_path () not like '%/')
  {
    http_request_status ('HTTP/1.1 301 Moved Permanently');
    http_header (sprintf ('Location: %s/\r\n', http_path ()));
    return (0);
  }
  declare location varchar;
  if (WS.WS.IS_REDIRECT_REF (path, lines, location) and (get_keyword ('a', params, '') not in ('update', 'edit')))
  {
    declare host1 varchar;
    http_request_status ('HTTP/1.1 302 Found');
    host1 := http_request_header (lines, 'Host', NULL, NULL);
    if (host1 is not null and location not like '%://%')
      host1 := concat ('http://', host1);
    else
      host1 := '';
    http_header (sprintf ('Location: %s%s\r\n', host1, location));
    return (0);
  }
  http_request_status ('HTTP/1.1 200 OK');
  client_etag := WS.WS.FINDPARAM (lines, 'If-None-Match:');
  if ((_col_id is not null) or ((_res_id is not null) and (get_keyword ('a', params) in ('update', 'edit'))))
  {
    declare dir_ret any;
    if (WS.WS.GET_EXT_LDP(lines, client_etag, full_path, _res_id, _col_id))
      return;

    if (0 = http_map_get ('browseable'))
    {
      DB.DBA.DAV_SET_HTTP_STATUS (403, null, null, 'You are not permitted to view the directory index in this location: ' || sprintf ('%V', http_path ()), 1);
      return;
    }
    dir_ret := WS.WS.DAV_DIR_LIST (full_path, http_path(), _col_id, uname, upwd, uid);
    if (DAV_HIDE_ERROR (dir_ret))
    {
      DB.DBA.DAV_SET_HTTP_STATUS (
        'HTTP/1.1 500 Internal Server Error or Misconfiguration',
        '500 Internal Server Error or Misconfiguration',
        sprintf ('Failed to return the directory index in this location: %V<br />%s',  http_path (), DAV_PERROR (dir_ret)),
        1
      );
    }
    return;
  }

-- if def VIRTUAL_DIR
--  if (isstring (def_page))
--    http (concat ('def page is "', def_page, '".'));

--  http (concat ('physical path is "', full_path, '".'));

  is_admin_owned_res := 0;
  rc := 0;
  -- XXX: moved at common cursor rc := WS.WS.FINDRES (path, _col, _name);
  -- Only WebDAV admin can own executable resources
  -- XXX: moved at common cursor
  --if (exists (select 1 from WS.WS.SYS_DAV_RES where RES_NAME = _name and RES_COL = _col
  --  and RES_OWNER = http_dav_uid ()))
  --  is_admin_owned_res := 1;
  modt := null;
  if (isinteger (_res_id))
  {
    for select RES_OWNER, RES_COL, RES_NAME, RES_TYPE, RES_MOD_TIME
          from WS.WS.SYS_DAV_RES
         where RES_ID = _res_id do
    {
      _col := RES_COL;
      _name := RES_NAME;
      resource_owner := RES_OWNER;
      cont_type := RES_TYPE;
      modt := RES_MOD_TIME;
    }
  }
  else
  {
    declare _entry any;

    _entry := DAV_DIR_SINGLE_INT (_res_id, 'R', path, null, null, http_dav_uid ());
    _col := _res_id[1];
    _name := _entry[10];
    resource_owner := _entry[7];
    cont_type := _entry[9];
    modt := _entry[3];
  }
  if (resource_owner = http_dav_uid ())
    is_admin_owned_res := 1;
  if (WS.WS.GET_EXT_LDP(lines, client_etag, full_path, _res_id, _col_id))
    return;

  --for select COL_OWNER from WS.WS.SYS_DAV_COL where COL_ID = _col do
  --  {
  --    collection_owner := COL_OWNER;
  --  }

  -- special extensions can be executed if special flag is set
  if ((http_map_get ('executable') and webid_check_rc >= 0) or (exec_safety_level and is_admin_owned_res))
    exec_safety_level := 2;
  -- dbg_obj_princ ('exec_safety_level is ', exec_safety_level);
  -- when directory is executable set the owner for execution to the resource owner
  -- this would apply to the included files etc.
  if (http_map_get ('executable'))
    connection_set ('DAVUserID', resource_owner);

  -- XXX: the vsp_in_dav_enabled flag is obsoleted
  --if (not is_executable and not sys_stat ('vsp_in_dav_enabled') and rc <> 0 and (full_path like '%.vsp' or full_path like '%.vspx') and ( isp = 1 or chp = 1 ) and is_admin_owned_res)
  --  {
  --    http_rewrite ();
  --    http_request_status ('HTTP/1.1 403 Forbidden');
  --    http ('<HTML><BODY><p>The requested active content cannot be displayed due to execution restriction</p>
  --       <p>To enable execution set the EnabledDavVSP INI setting to 1.</p></BODY></HTML>');
  --    return;
  --  }

  if ((exec_safety_level > 1) and full_path like '%.vsp')
  {
    declare incstat any;
    declare pname varchar;
    pname := sprintf ('%s.%s.%s', http_map_get ('vsp_qual'), http_map_get ('vsp_proc_owner'), full_path);
    if (__proc_exists (pname) and not WS.WS.DAV_VSP_INCLUDES_CHANGED (full_path, http_map_get ('vsp_proc_owner')))
    {
      stat := '00000';
      msg := '';
      commit work;
      declare exit handler for sqlstate '*', not found
      {
        __pop_user_id ();
        if (__SQL_STATE <> 100)
        {
          stat := __SQL_STATE;
          msg := __SQL_MESSAGE;
        }
        else
        {
          stat := '01W01';
          msg := 'No WHENEVER statement provided for SQLCODE 100';
        }
        goto exec_err;
      };
      __set_user_id (http_map_get ('vsp_uid'));
      call (pname) (path, params, lines);
      __pop_user_id ();
      -- dbg_obj_princ ('VSP called without re-compilation: ', stat, msg);
      return;
    }
    select blob_to_string (RES_CONTENT), RES_FULL_PATH
      into resource_content, full_path
      from WS.WS.SYS_DAV_RES
     where RES_NAME = _name and RES_COL = _col;
    p_comm := sprintf (
      'create procedure "%s"."%s"."%s" (in path varchar, in params varchar, in lines varchar) { ?>',
      http_map_get ('vsp_qual'), http_map_get ('vsp_proc_owner'), full_path);
    str := string_output ();
    http (p_comm, str);
    incstat := vector ();
    WS.WS.EXPAND_INCLUDES (full_path, str, 0, 1, resource_content, incstat);
    http ('<?vsp }', str);
    str := string_output_string (str);
    -- dbg_obj_princ ('__depend_', incstat);
    stat := '00000';
    msg := '';
    __set_user_id (http_map_get ('vsp_uid'));
    exec (str, stat, msg);
    commit work;
    if (stat = '00000')
    {
      stat := '00000';
      msg := '';
      p_comm := sprintf ('call "%s"."%s"."%s" (?, ?, ?)',
      http_map_get ('vsp_qual'), http_map_get ('vsp_proc_owner'), full_path);
      exec (p_comm, stat, msg, vector (path, params, lines));
    }
    __pop_user_id ();
    -- dbg_obj_princ ('execution status: ', stat, msg);
    if (stat <> '00000')
    {
      exec_err:
      http_status_set (500);
      http ('<html><body>');
      http (concat ('<H3>Execution of "', sprintf ('%V', http_path()), '" failed.</H3>'));
      http (concat ('<p><b>SQL Error: ', stat, ' '));
      http_value (msg);
      http ('</b></p>');
      http ('</body></html>');
    }
    else
      registry_set (concat ('__depend_', http_map_get ('vsp_proc_owner'), '_', full_path), serialize(incstat));

    return;
  }
  else if ((exec_safety_level > 1) and full_path like '%.vspx')
  {
    -- dbg_obj_princ ('Will run DB.DBA.vspx_dispatch (', full_path, path, params, lines,')');
    DB.DBA.vspx_dispatch (full_path, path, params, lines);
  }
  else
  {
    declare _accept, _server_etag, _xslt_sheet, _document_q, _xml_t varchar;
    declare _sse, _sse_cont_type, _sse_mime_encrypt, _sse_email, _sse_certificate any;
    declare fext, hdl_mode varchar;
    declare dot integer;
    declare xml_mime_type varchar;
    whenever not found goto err_end;

    -- XXX: temporary to avoid test noise
    set isolation='repeatable';
    _sse_mime_encrypt := 0;


    content := string_output (http_strses_memory_size ());
    rc := DAV_RES_CONTENT_INT (_res_id, content, cont_type, 1, 0);

    -- dbg_obj_princ ('DAV_RES_CONTENT_INT (', _res_id, ', [content], ', cont_type, 1, 0, ' returns ', rc);
    if (DAV_HIDE_ERROR (rc) is null)
    {
    _500:;
      DB.DBA.DAV_SET_HTTP_STATUS (
        500,
        null,
        null,
        sprintf ('Server is unable to compose the text of the resource in this location: %V', http_path ()),
        1
      );
      return;
    }

    _accept := HTTP_RDF_GET_ACCEPT_BY_Q (http_request_header_full (lines, 'Accept', '*/*'));
	  if (WS.WS.TTL_REDIRECT_ENABLED () and isinteger (_res_id) and (_accept = 'text/html') and (cont_type = 'text/turtle') and not isnull (DB.DBA.VAD_CHECK_VERSION ('fct')))
    {
      http_rewrite ();
      http_status_set (303);
      http_header (http_header_get () || sprintf ('Location: %s/describe/?url=%U&sponger:get=add\r\n',
      WS.WS.DAV_HOST (), WS.WS.DAV_HOST () || replace (full_path, ' ', '%20')));
      return;
    }

    _sse_cont_type := cont_type;
    cont_type := case when not _sse_mime_encrypt then cont_type else 'message/rfc822' end;

    -- HTTP handlers are going here
    _name := path [length(path)-1];
    -- dbg_obj_princ (_name);
    if (not _sse_mime_encrypt)
    {
      dot := strrchr (_name, '.');
      if (dot is not null)
      {
        declare is_exist integer;

        is_exist := 0;
        fext := ws_get_ftext (_name, dot);

        if (__proc_exists (fext, 2))
          is_exist := 1;
        else
        {
          fext := concat ('WS.WS.', fext);
          if (__proc_exists (fext, 1))
            is_exist := 1;
        }

        if (is_exist and exec_safety_level > 0)
        {
          -- handler string input
          declare stream_params any;
          fext := cast (fext as varchar);
          hdl_mode := concat ('virt://WS.WS.SYS_DAV_RES.RES_FULL_PATH.RES_CONTENT:', full_path);
          __set_user_id (http_map_get ('vsp_uid'));
          stream_params := __http_stream_params ();
          commit work;
          http (call (fext) (string_output_string (content), stream_params, lines, hdl_mode));
          if (isarray (hdl_mode) and length (hdl_mode) > 1)
          {
            if (hdl_mode[0] <> '' and isstring (hdl_mode[0]))
              http_request_status (hdl_mode[0]);

            if (hdl_mode[1] <> '' and isstring (hdl_mode[1]))
              http_header (hdl_mode[1]);
          }
          return;
        }
      }
    }
    _xml_t := DAV_HIDE_ERROR (DAV_PROP_GET_INT (_res_id, 'R', 'xml-template', 0), '');
    -- XML templates execution
    if (cont_type = 'text/xml' and
       (http_map_get ('xml_templates') or _xml_t = 'execute') and
       (exec_safety_level > 1))
    {
      declare new_params, _enc any;
      declare _base_url varchar;

      _base_url := concat ('virt://WS.WS.SYS_DAV_RES.RES_FULL_PATH.RES_CONTENT:', full_path);
      xml_mime_type := DAV_HIDE_ERROR (DAV_PROP_GET_INT (_res_id, 'R', 'xml-sql-mime-type', 0), 'text/xml');
      new_params := vector_concat (params, vector ('template', string_output_string (content), '__base_url', _base_url, 'contenttype', xml_mime_type));
      _enc := DAV_HIDE_ERROR (DAV_PROP_GET_INT (_res_id, 'R', 'xml-sql-encoding', 0));
      DB.DBA.__XML_TEMPLATE (path, new_params, lines, _enc);
      return;
    }

    server_etag := WS.WS.ETAG (_name, _col, modt);
    if (not _sse_mime_encrypt)
    {
      _document_q := DAV_HIDE_ERROR (DAV_PROP_GET_INT (_res_id, 'R', 'xml-sql', 0), '');
      _xslt_sheet := DAV_HIDE_ERROR (DAV_PROP_GET_INT (_res_id, 'R', 'xml-stylesheet', 0), '');

      if (_document_q <> '' or _xslt_sheet <> '')
        cont_type := 'sql/xml';

      if (cont_type <> '' and cont_type <> 'sql/xml')
      {
        if (cont_type <> 'xml/view' and cont_type <> 'xml/persistent-view')
        {
          declare hdr_str, hdr_path, hdr_uri any;

          hdr_str := http_header_get ();
          hdr_str := hdr_str || 'ETag: "' || server_etag || '"\r\n';
          if (strcasestr (hdr_str, 'Content-Type:') is null)
            hdr_str := hdr_str || 'Content-Type: ' || cont_type || '\r\n';

          hdr_path := DAV_CONCAT_PATH ('/', full_path);
          if (hdr_path not like '%,meta')
          {
            hdr_uri := sprintf ('%s://%s%s', case when is_https_ctx () then 'https' else 'http' end, http_request_header (lines, 'Host', NULL, NULL), hdr_path);
          }
          hdr_str := hdr_str || sprintf ('Link: <%s,meta>; rel="meta"; title="Metadata File"\r\n', hdr_uri);
          if (DAV_HIDE_ERROR (DAV_SEARCH_ID (hdr_path || ',acl', 'R')) is not null)
          {
            hdr_str := hdr_str || sprintf ('Link: <%s,acl>; rel="http://www.w3.org/ns/auth/acl#accessControl"; title="Access Control File"\r\n', hdr_uri);
          }
          rdf_graph := (select PROP_VALUE from WS.WS.SYS_DAV_PROP where PROP_PARENT_ID = _col and PROP_TYPE = 'C' and PROP_NAME = 'virt:rdfSink-graph');
          if (rdf_graph is not null)
          {
            declare rdf_uri varchar;
            rdf_uri := rfc1808_expand_uri (DB.DBA.HTTP_REQUESTED_URL (), DAV_RDF_RES_NAME (rdf_graph));
            hdr_str := hdr_str || sprintf ('Link: <%s>; rel="alternate"\r\n', rdf_uri);
          }
          http_header (hdr_str);
        }
        else
          http_header (concat ('Content-Type: text/xml\r\nETag: "',server_etag,'"\r\n'));
      }
    }
--      else
--  http_header (concat ('ETag: "', server_etag, '"\n'));

    _server_etag := server_etag;
    server_etag := concat ('"', server_etag, '"');

    if (client_etag <> server_etag)
    {
      http_request_status ('HTTP/1.1 200 OK');
      xpr := get_keyword ('XPATH', params, '/*');
      if (cont_type = 'xml/view')
      {
        declare ondemand_data varchar;
        declare view_name varchar;
        declare meta_mode integer;
        declare meta_data varchar;
        declare delim1, delim2 integer;
        declare zero integer;
        ondemand_data := string_output_string (content);
        delim1 := locate('{view_name}\n',ondemand_data);
        delim2 := locate('{meta_mode}\n',ondemand_data);
        if(delim1 >= delim2 or delim2 = 0)
        {
          view_name := ondemand_data;
          meta_mode := 0;
          meta_data := '';
        } else {
          view_name := substring(ondemand_data, 1, delim1-1);
          delim1 := delim1 + length('{view_name}\n');
          meta_mode := cast(substring(ondemand_data, delim1, delim2-delim1) as integer);
          delim2 := delim2 + length('{meta_mode}\n');
          meta_data := substring(ondemand_data, delim2, length(ondemand_data)+1-delim2);
        }
        if (xpr = '')
        {
          http ('Error: XPATH param is empty');
          return;
        }
        sxtag := get_keyword ('set_tag', params, view_name);
        maxres := atoi (get_keyword ('maxresults', params, '100'));
        rxtag := get_keyword ('result_tag', params, '');
        if (rxtag <> '')
          rxtag := concat ('__tag  "', rxtag, '"');

        p_comm := concat ('XPATH [__http __view "', view_name, '" ', rxtag, '] ', xpr);
        stat := '00000';
        msg := '';
        zero := 0;
        WS.WS.XML_VIEW_HEADER (view_name, sxtag, full_path, meta_mode, meta_data, zero);
        -- http(concat('<!-- ',view_name,' -->\n'));
        -- http(concat('<!-- ',sxtag,' -->\n'));
        -- http(concat('<!-- ',full_path,' -->\n'));
        -- http(concat('<!-- ',cast(meta_mode as varchar),' -->\n'));
        -- http(concat('<!-- ',meta_data,' -->\n'));
        err := exec (p_comm, stat, msg, vector (), maxres);
        http (concat ('</', sxtag, '>\n'));
        if (stat = '00000')
          return;

        http_header (concat ('Content-Type: text/html\r\n'));
        http (concat ('SQL Error: ', stat, ' ', msg));
        return;
      }
      else if ((cont_type = 'text/xml' or cont_type = 'xml/persistent-view' or (cont_type = 'sql/xml' and length (content) > 0))  and xpr <> '/*')
      {
        declare c_xml cursor for select t from WS.WS.SYS_DAV_RES where xpath_contains (RES_CONTENT, xpr, t)
        and RES_NAME = _name and RES_COL = _col;
        declare ht varchar;

        sxtag := get_keyword ('set_tag', params, 'document');
        rxtag := get_keyword ('result_tag', params, '');
        http (sprintf ('<?xml version="1.0" encoding="%s"?>\n', current_charset()));
        http (concat ('<', sxtag, '>\n'));
        whenever not found goto end_xml;
        open c_xml;
        while (1)
        {
          fetch c_xml into ht;
          if (rxtag <> '')
            http (concat ('<', rxtag, '>\n'));

          http_value (ht);
          if (rxtag <> '')
            http (concat ('</', rxtag, '>\n'));
        }
      end_xml:
        close c_xml;
        http (concat ('</', sxtag, '>\n'));
      }
      else if (cont_type = 'application/sparql-query')
      {
        WS.WS.SPARQL_QUERY_GET (content, path, lines);
      }
      else if (not isnull (content))
      {
        if (DAV_HIDE_ERROR (DAV_PROP_GET_INT (_res_id, 'R', 'xper', 0)) is not null)
        {
          http (sprintf ('<?xml version="1.0" encoding="%s" ?>\n', current_charset()));
          http_value (xper_cut (xml_persistent (content)));
        }
        else
        {
          -- normal static content from DAV
          -- handle the Range headers
          declare _http_ranges_header any;
          _http_ranges_header := http_sys_parse_ranges_header (length (content));

          -- the bif has already sent the 416
          if (isinteger (_http_ranges_header))
            return;

          if (_http_ranges_header is not null)
          {
            -- there is a range header
            declare _http_if_range varchar;

            _http_if_range := http_request_header (lines, 'If-Range', null, '');
            if (length (_http_if_range) > 0 and _http_if_range <> server_etag)
              _http_ranges_header := NULL;

            if (length (_http_ranges_header) > 2)
            { -- fixme: DAV does not support multipart/byteranges
              _http_ranges_header := NULL;
            }
          }
          if (_http_ranges_header is not null)
          {
            http_header (concat (coalesce (http_header_get (), ''), sprintf (
              'Content-Length: %ld\r\nContent-Range: bytes %ld-%ld/%ld\r\n',
              _http_ranges_header[1] - _http_ranges_header[0] + 1,
              _http_ranges_header[0],
              _http_ranges_header[1],
              length (content))));
            http_request_status ('HTTP/1.1 206 Partial content');

            declare _left, _to_get, _start integer;
            declare _chunk, _ses any;
            _left := _http_ranges_header[1] - _http_ranges_header[0] + 1;
            _start := _http_ranges_header[0];
            _ses := http_flush (2);

            declare exit handler for sqlstate '*' { rollback work; return; };
            --ses_write ('\r\n', _ses);
            while (_left > 0)
            {
              _to_get := _left;
              if (_to_get > 65536)
                _to_get := 65536;

              _chunk := subseq (content, _start, _start + _to_get);
              if (__tag (_chunk) = 185)
               _chunk := string_output_string (_chunk);

              ses_write (_chunk, _ses);
              _left := _left - _to_get;
              _start := _start + _to_get;
            }
          }
          else
          {
            if (length (content) > WS.WS.GET_DAV_CHUNKED_QUOTA ())
              http_flush (1);


            http (content);
          }
        }
        if (cont_type = 'sql/xml')
        {
          declare  _root, _doc_ses, _comments varchar;
          if (length (content) = 0)
          {
            declare _dtd, _sch, _enc varchar;
            _root := coalesce ((select blob_to_string (PROP_VALUE) from WS.WS.SYS_DAV_PROP where
                     PROP_NAME = 'xml-sql-root'
                     and PROP_TYPE = 'R'
                     and PROP_PARENT_ID = _res_id), '');
            _dtd := coalesce ((select blob_to_string (PROP_VALUE) from WS.WS.SYS_DAV_PROP where
                     PROP_NAME = 'xml-sql-dtd'
                     and PROP_TYPE = 'R'
                     and PROP_PARENT_ID = _res_id), '');
            _sch := coalesce ((select blob_to_string (PROP_VALUE) from WS.WS.SYS_DAV_PROP where
                     PROP_NAME = 'xml-sql-schema'
                     and PROP_TYPE = 'R'
                     and PROP_PARENT_ID = _res_id), '');
            _comments := coalesce ((select blob_to_string (PROP_VALUE) from WS.WS.SYS_DAV_PROP where
                     PROP_NAME = 'xml-sql-description'
                     and PROP_TYPE = 'R'
                     and PROP_PARENT_ID = _res_id), '');
            _enc := (select blob_to_string (PROP_VALUE) from WS.WS.SYS_DAV_PROP where
                     PROP_NAME = 'xml-sql-encoding'
                     and PROP_TYPE = 'R'
                     and PROP_PARENT_ID = _res_id);
            _doc_ses := null; -- HTTP stream will be used
            http_rewrite ();
            WS.WS.XMLSQL_TO_STRSES (_document_q, _root, _sch, _dtd, _comments, _doc_ses, _enc);
          }
          xml_mime_type := DAV_HIDE_ERROR (DAV_PROP_GET_INT (_res_id, 'R', 'xml-sql-mime-type', 0), 'text/xml');
          if (_xslt_sheet <> '')
            http_xslt (_xslt_sheet);
          else if (length (content) = 0)
            http_header (http_header_get () || sprintf ('Cache-Control: no-cache, must-revalidate\r\nPragma: no-cache\r\nExpires: %s\r\nContent-Type: %s\r\n', soap_print_box (now (), '', 1), xml_mime_type));
          else
            http_header (http_header_get () || sprintf ('Content-Type: %s\r\nETag: "%s"\r\n', xml_mime_type, _server_etag));
        }
      }
    }
    else
      http_request_status ('HTTP/1.1 304 Not Modified');
  }
err_end:
  return;
}
;

-- LDP extension for GET (http://www.w3.org/TR/ldp/#http-get)
create procedure WS.WS.GET_EXT_LDP(in lines any, in client_etag varchar, in full_path varchar, in _res_id int, in _col_id int)
{
	declare accept, _name, cont_type, uname, urihost varchar;
	declare arr any;
	declare l, i, resource_owner, non_member, page, _col, file_size int;
	declare mod_time, cr_time datetime;
	-- LDPR request
	urihost := cfg_item_value(virtuoso_ini_path(), 'URIQA','DefaultHost');
	arr := split_and_decode(http_request_get ('QUERY_STRING'));
	non_member := 0;
	l := length (arr);
	page := 1;
	for (i := 0; i < l; i := i + 2)
    {
		if (arr[i] = 'non-member-properties')
		non_member := 1;
		if (arr[i] = 'p')
		{
			if (i < l - 1)
				page := atoi(arr[i+1]);
			else
				page := 1;
		}
	}
	if (page = 0)
		page := 1;
	accept := http_request_header_full (lines, 'Accept', '*/*');
	accept := HTTP_RDF_GET_ACCEPT_BY_Q (accept);
	if (accept = 'text/turtle')
	{
		if (isinteger (_col_id))
		{
			for select COL_NAME, COL_OWNER, COL_CR_TIME, COL_MOD_TIME from WS.WS.SYS_DAV_COL where COL_ID = _col_id do
			{
				_name := COL_NAME;
				resource_owner := COL_OWNER;
				mod_time := COL_MOD_TIME;
				cr_time := COL_CR_TIME;
				select U_NAME into uname from WS.WS.SYS_DAV_USER where U_ID = resource_owner;
			}
			declare _len, cur int;
			declare ses any;
			ses := string_output ();
			http ('@prefix dcterms: <http://purl.org/dc/terms/> .\n@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .\n@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .\n@prefix ldp: <http://www.w3.org/ns/ldp#> .\n@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .\n\n', ses);
			http ('<>\n', ses);
			http ('  a ldp:Container, <http://www.w3.org/ns/posix/stat#Directory> ;\n', ses);
			http ('  ldp:membershipSubject <> ;\n', ses);
			http ('  ldp:membershipPredicate rdfs:member ;\n', ses);
			http ('  ldp:membershipObject ldp:MemberSubject ;\n', ses);
			http (sprintf('  <http://www.w3.org/ns/posix/stat#mtime> %d ;\n', datediff('second', dt_set_tz (stringdate ('1970-01-01'), 0), mod_time)), ses);
			http ('  <http://www.w3.org/ns/posix/stat#size> 0 ;\n', ses);
			http (sprintf('dcterms:title "%s";\n', _name), ses);
			http (sprintf('dcterms:creator "%s";\n', uname), ses);
			http (sprintf('dcterms:created "%s";\n', datestring(cr_time)), ses);
			http (sprintf('dcterms:modified "%s";\n', datestring(mod_time)), ses);

			declare num, num_pre_page, prefix_added, next_page int;
			num := 0;
			num_pre_page := 10;
			prefix_added := 0;
			next_page := 0;
			if (non_member = 0)
			{
				for select COL_NAME from WS.WS.SYS_DAV_COL where COL_PARENT = _col_id order by COL_NAME do
				{
					if (num >= num_pre_page * (page - 1) and num < num_pre_page * page)
					{
						if (prefix_added = 0)
						{
							http ('  rdfs:member ', ses);
							prefix_added := 1;
						}
						else
							http (', ', ses);
						http (sprintf('<%s>', COL_NAME || '/'), ses);
					}
					if (num >= num_pre_page * page)
					{
						next_page := 1;
					}
					num := num + 1;
				}
				for select RES_NAME from WS.WS.SYS_DAV_RES where RES_COL = _col_id order by RES_NAME  do
				{
					if (num >= num_pre_page * (page - 1) and num < num_pre_page * page)
					{
						if (prefix_added = 0)
						{
							http ('  rdfs:member ', ses);
							prefix_added := 1;
						}
						else
							http (', ', ses);
						http (sprintf('<%s>', RES_NAME), ses);
					}
					if (num >= num_pre_page * page)
					{
						next_page := 1;
					}
					num := num + 1;
				}
				if (num >= 1)
					http (' ;\n', ses);
			}
			http (sprintf('  rdfs:label "%s" .\n\n', _name), ses);

			num := 0;
			if (non_member = 0)
			{
				http (sprintf('<?p=%d>\n', page), ses);
				http ('  a ldp:Page ;\n', ses);
				if (next_page = 0)
					http ('  ldp:nextPage rdf:nil ;\n', ses);
				else
					http (sprintf('  ldp:nextPage <?p=%d> ;\n', page + 1), ses);
				http ('  ldp:pageOf <> .\n\n', ses);

				for select COL_NAME, COL_MOD_TIME from WS.WS.SYS_DAV_COL where COL_PARENT = _col_id order by COL_NAME do
				{
					if (num >= num_pre_page * (page - 1) and num < num_pre_page * page)
					{
						http (sprintf('<%s>\n', COL_NAME || '/'), ses);
						http ('  a <http://www.w3.org/ns/posix/stat#Directory> ;\n', ses);
						http (sprintf('  <http://www.w3.org/ns/posix/stat#mtime> %d ;\n', datediff('second', dt_set_tz (stringdate ('1970-01-01'), 0), COL_MOD_TIME)), ses);
						http ('  <http://www.w3.org/ns/posix/stat#size> 0 .\n\n', ses);
					}
					num := num + 1;
				}
				for select RES_NAME, RES_MOD_TIME, length(RES_CONTENT) as res_size from WS.WS.SYS_DAV_RES where RES_COL = _col_id order by RES_NAME  do
				{
					if (num >= num_pre_page * (page - 1) and num < num_pre_page * page)
					{
						http (sprintf('<%s>\n', RES_NAME), ses);
						http ('  a <http://www.w3.org/2000/01/rdf-schema#Resource> ;\n', ses);
						http (sprintf('  <http://www.w3.org/ns/posix/stat#mtime> %d ;\n', datediff('second', dt_set_tz (stringdate ('1970-01-01'), 0), RES_MOD_TIME)), ses);
						http (sprintf('  <http://www.w3.org/ns/posix/stat#size> %d .\n\n', res_size), ses);
					}
					num := num + 1;
				}
			}
			ses := string_output_string (ses);
			_len := length(ses);
			http_header('Link: <?p=1>; rel="first"\r\nContent-Type: text/turtle; chartset=UTF-8\r\n');
			http(ses);
		}
		if (isinteger (_res_id))
		{
			for select RES_OWNER, RES_COL, RES_NAME, RES_TYPE, RES_MOD_TIME, RES_CR_TIME, length(RES_CONTENT) as res_size from WS.WS.SYS_DAV_RES where RES_ID = _res_id do
			{
				_col := RES_COL;
				_name := RES_NAME;
				resource_owner := RES_OWNER;
				cont_type := RES_TYPE;
				mod_time := RES_MOD_TIME;
				cr_time := RES_CR_TIME;
				file_size := res_size;
				select U_NAME into uname from WS.WS.SYS_DAV_USER where U_ID = resource_owner;
			}
			if (accept = cont_type) -- the content is already turtle so exit
			  return 0;
			declare s_etag, _s_etag varchar;
			s_etag := WS.WS.ETAG (_name, _col, mod_time);
			_s_etag := s_etag;
			s_etag := concat ('"', s_etag, '"');
			if (client_etag <> s_etag)
			{
				declare _len int;
				declare ses any;
				ses := string_output ();
				http ('@prefix dcterms: <http://purl.org/dc/terms/> .\n@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .\n@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .\n@prefix ldp: <http://www.w3.org/ns/ldp#> .\n@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .\n\n', ses);
				http (sprintf('<%s>\n', 'http://' || urihost || full_path), ses);
				http ('  a dcterms:PhysicalResource, <http://www.w3.org/2000/01/rdf-schema#Resource> ;\n', ses);
				http (sprintf('dcterms:title "%s";\n', _name), ses);
				http (sprintf('dcterms:creator "%s";\n', uname), ses);
				http (sprintf('dcterms:created "%s";\n', datestring(cr_time)), ses);
				http (sprintf('dcterms:modified "%s";\n', datestring(mod_time)), ses);
				http (sprintf('  <http://www.w3.org/ns/posix/stat#mtime> %d ;\n', datediff('second', dt_set_tz (stringdate ('1970-01-01'), 0), mod_time)), ses);
				http (sprintf('  <http://www.w3.org/ns/posix/stat#size> %d ;\n', file_size), ses);
				http (sprintf('rdfs:label "%s".\n', _name), ses);
				ses := string_output_string (ses);
				_len := length(ses);
				http_header('Content-Type: text/turtle; charset=UTF-8\r\n');
				http(ses);
			}
			else
				http_request_status ('HTTP/1.1 304 Not Modified');
		}
		return 1;
	}
	else
		return 0;
}
;

-- /* POST method */
create procedure WS.WS.POST (in path varchar, inout params varchar, in lines varchar)
{
  declare _content_type any;
  _content_type := http_request_header (lines, 'Content-Type', null, '');
  if (_content_type = 'application/vnd.syncml+wbxml' or
      _content_type = 'application/vnd.syncml+xml')
   {
     if (__proc_exists ('DB.DBA.SYNCML'))
       DB.DBA.SYNCML (path, params, lines);
     else
       signal ('37000', 'The SyncML server is not available');
   }
  else if (_content_type = 'application/sparql-query')
   {
     WS.WS.PUT (path, params, lines);
   }
  else
   {
     WS.WS.GET (path, params, lines);
   }
}
;

create procedure WS.WS.SPARQL_QUERY_POST (
  in path varchar,
  inout ses varchar,
  in uname varchar,
  in dav_call integer := 0)
{
  declare def_gr, full_qr, qr any;
  declare stat, msg, meta, data any;

  if (dav_call)
  {
  ses := http_body_read ();
  }
  qr := ses;
  if (not isstring (ses))
    {
    qr := string_output_string (ses);
    }
  def_gr := WS.WS.DAV_HOST () || sprintf ('%U', path);
  if (lower (qr) not like 'construct %' and lower (qr) not like 'describe %')
    full_qr := sprintf ('SPARQL define input:default-graph-uri <%s> ', def_gr);
  else
    full_qr := 'SPARQL ';
  full_qr := full_qr || qr;
  stat := '00000';
  if (exists (select 1 from DB.DBA.SYS_USERS where U_NAME = uname and U_SQL_ENABLE = 1))
    set_user_id (uname);
  exec (full_qr, stat, msg, vector (), 0, meta, data);
  if (stat <> '00000')
    signal (stat, msg);
  if (length (data) > 0 and length (data[0]) and __tag (data[0][0]) = 214)
    {
      declare dict, triples any;
      dict := data[0][0];
      ses := string_output ();
      triples := dict_list_keys (dict, 1);
      DB.DBA.RDF_TRIPLES_TO_TTL (triples, ses);
      ses := string_output_string (ses);
      DB.DBA.TTLP (ses, HTTP_REQUESTED_URL (), def_gr);
    }
  ses := sprintf ('CONSTRUCT { ?s ?p ?o } FROM <%s> WHERE { ?s ?p ?o }', def_gr);
}
;

create procedure WS.WS.TTL_QUERY_POST (
  in path varchar,
  inout ses varchar,
  in uname varchar,
  in dav_call integer := 0)
{
  declare def_gr any;
	declare exit handler for sqlstate '*'
	{
	  connection_set ('__sql_state', __SQL_STATE);
	  connection_set ('__sql_message', __SQL_MESSAGE);
	  return -44;
	};

  if (dav_call)
{
  ses := http_body_read ();
    if (__tag (ses) = 185) -- string output
	{
  	  ses := http_body_read (1);
	 }
    }
  def_gr := WS.WS.DAV_IRI (path);
  if (exists (select 1 from DB.DBA.SYS_USERS where U_NAME = uname and U_SQL_ENABLE = 1))
    set_user_id (uname);

  log_enable (3);
  DB.DBA.TTLP (ses, def_gr, def_gr);

  return 0;
}
;

create procedure WS.WS.TTL_REDIRECT_ENABLED ()
{
  return case when registry_get ('__WebDAV_ttl__') = 'yes' then 1 else 0 end;
}
;

create procedure WS.WS.SPARQL_QUERY_GET (in content any, in path any, inout lines any)
{
  declare pars any;
  pars := vector ('query', string_output_string (content));
  WS.WS."/!sparql/" (path, pars, lines);
}
;

--#IF VER=5
--!AFTER
--#ENDIF
create procedure WS.WS."LOCK" (in path varchar, inout params varchar, in lines varchar)
{
  declare len, tleft, tright integer;
  declare id, p_id, rc any;
  declare col, res, timeout, owner integer;
  declare st, name, uname, upwd, _perms varchar;
  declare new_token, u_token varchar;
  declare owner_name varchar;
  declare ltype, scope char;
  declare _u_id, _g_id integer;
  declare tmp, dpth varchar;
  declare hdr, location varchar;
  declare ses any;

  declare _iftoken, locktype varchar;
  locktype := null;
  _iftoken := WS.WS.FINDPARAM (lines, 'If:');

  ses := aref_set_0 (params, 1);
  WS.WS.IS_REDIRECT_REF (path, lines, location);
  path := WS.WS.FIXPATH (path);

  p_id := DAV_HIDE_ERROR (DAV_SEARCH_ID (vector_concat (vector(''), path), 'P'));
  if (p_id is null)
    {
      DB.DBA.DAV_SET_HTTP_STATUS (409);
      return;
    }
  id := DAV_HIDE_ERROR (DAV_SEARCH_ID (vector_concat (vector(''), path, vector('')), 'C'));
  if (id is not null)
    st := 'C';
  else
    {
      st := 'R';
      id := DAV_HIDE_ERROR (DAV_SEARCH_ID (vector_concat (vector(''), path), 'R'));
    }
  _u_id := null;
  _g_id := null;
  if (id is null)
	{
    rc := DAV_AUTHENTICATE_HTTP (p_id, 'C', '11_', 1, lines, uname, upwd, _u_id, _g_id, _perms);
	}
  else
	{
    rc := DAV_AUTHENTICATE_HTTP (id, st, '11_', 1, lines, uname, upwd, _u_id, _g_id, _perms);
	}
	if (rc < 0)
	{
    DB.DBA.DAV_SET_AUTHENTICATE_HTTP_STATUS (rc);
		return;
	}
  set isolation = 'serializable';
  if (st = 'R')
    dpth := '0';
  else
    dpth := 'infinity';

  tmp := string_output_string (ses);
  owner_name := '';
  scope := 'X';
  if (tmp is not null and tmp <> '')
    {
      declare xses, xses2, xtree any;
      xtree := xml_tree (tmp, 0);
      if (isarray (xtree))
	{
	  xtree := xml_tree_doc (xtree);
	  xses := string_output ();
	  http_value (xpath_eval ('/lockinfo/owner' , xtree, 1), null, xses);
	  owner_name := string_output_string (xses);
	  if (owner_name = '')
	    owner_name := '';
	  xses2 := string_output ();
	  http_value (xpath_eval ('/lockinfo/lockscope' , xtree, 1), null, xses2);
	  xses2 := string_output_string (xses2);
	  if (strstr (xses2, 'exclusive') is not null)
	    scope := 'X';
	  else
	    scope := 'S';
	}
    }
  tmp := WS.WS.FINDPARAM (lines, 'Timeout:');
  declare tima any;
  tima := split_and_decode (tmp, 0, '\0\0-');

  if (length(tima) > 1 and lower(tima[0]) = 'second')
    timeout := atoi (tima[1]);
  else
    timeout := 0;
  path := DAV_CONCAT_PATH ('/', path);
  rc := DAV_LOCK_INT (path, id, st, locktype, scope, null, owner_name, _iftoken, dpth, timeout, null, null, _u_id);
  if (DAV_HIDE_ERROR (rc) is null)
  {
    if (rc = -8)
    {
      DB.DBA.DAV_SET_HTTP_STATUS (423);
    }
    else
    {
      DB.DBA.DAV_SET_HTTP_STATUS ('HTTP/1.1 424 Failed Dependency: ' || DAV_PERROR (rc));
    }
    return;
  }
   http_request_status ('HTTP/1.1 200 OK');
   hdr := concat ( 'Lock-Token: <opaquelocktoken:', rc ,'>\r\n',
                   'Content-type: text/xml; charset="utf-8"\r\n',
	                 'Keep-Alive: timeout=15, max=100\r\n');
   http_header (hdr);
   http (concat ('<?xml version="1.0" encoding="utf-8"?>',
		'<D:prop xmlns:D="DAV:">',
		'<D:lockdiscovery>',
		'<D:activelock>',
		'<D:locktype><D:write/></D:locktype>',
		'<D:lockscope>'));  if (scope = 'X') http ('<D:exclusive/>'); else http ('<D:shared/>');
		http (sprintf ('</D:lockscope><D:depth>%s</D:depth>', dpth));
		http (owner_name);
		http (concat ('<D:timeout>Second-',
		cast (timeout as varchar),'</D:timeout>',
		'<D:locktoken>',
		'<D:href>', 'opaquelocktoken:', rc, '</D:href>',
		'</D:locktoken>',
		'</D:activelock>',
		'</D:lockdiscovery>',
    '</D:prop>'));
}
;

create procedure WS.WS."UNLOCK" (in path varchar, inout params varchar, in lines varchar)
{
  declare uname, upwd, _perms, token, name, cur_token, location varchar;
  declare st char;
  declare rc, id, col, _left, _right integer;
  declare _u_id, _g_id integer;
  declare l_cur cursor for select LOCK_TOKEN from WS.WS.SYS_DAV_LOCK
      where LOCK_PARENT_ID = id and LOCK_PARENT_TYPE = st and LOCK_TOKEN = token;

  WS.WS.IS_REDIRECT_REF (path, lines, location);
  id := DAV_HIDE_ERROR (DAV_SEARCH_ID (vector_concat (vector(''), path, vector('')), 'C'));
  if (id is not null)
  {
    st := 'C';
  }
  else
  {
    st := 'R';
    id := DAV_HIDE_ERROR (DAV_SEARCH_ID (vector_concat (vector(''), path), 'R'));
    if (id is null)
  	{
      DB.DBA.DAV_SET_HTTP_STATUS (404);
  	  return;
  	}
  }
  _u_id := null;
  _g_id := null;
  rc := DAV_AUTHENTICATE_HTTP (id, st, '11_', 1, lines, uname, upwd, _u_id, _g_id, _perms);
  -- dbg_obj_princ ('Authentication in UNLOCK gives ', rc, uname, upwd, _u_id, _g_id, _perms);
	if (rc < 0)
	{
    DB.DBA.DAV_SET_AUTHENTICATE_HTTP_STATUS (rc);
		return;
	}
  token := WS.WS.FINDPARAM (lines, 'Lock-Token:');
  if (token = '')
  {
    DB.DBA.DAV_SET_HTTP_STATUS (400);
    return;
  }
  rc := DAV_UNLOCK_INT (id, st, token, null, null, _u_id);
  if (DAV_HIDE_ERROR (rc) is null)
  {
    if (rc = -27)
    {
      DB.DBA.DAV_SET_HTTP_STATUS (404);
    }
    else
    {
      DB.DBA.DAV_SET_HTTP_STATUS ('HTTP/1.1 424 Failed Dependency: ' || DAV_PERROR (rc));
    }
  }
  else
  {
    DB.DBA.DAV_SET_HTTP_STATUS (204);
  }
  return;
}
;

-- generate opaquelocktoken for locking
create procedure WS.WS.OPLOCKTOKEN ()
{
--  declare tmp varchar;
  return lower (uuid());
--  tmp := sprintf ('%d-%s-%d',rnd(1000000), cast (now() as varchar), rnd(1000000));
--  tmp := md5 (tmp);
--  tmp := concat(substring (tmp, 1, 8),'-',substring (tmp, 9, 4),'-',substring (tmp, 13, 4),'-',
--	   substring (tmp, 17, 4),'-',substring (tmp, 21, 12));
--  return tmp;
}
;

create procedure WS.WS.PARENT_PATH (in path varchar)
{
  declare tmp any;
  declare inx, len integer;

  inx := 0;
  if (__tag (path) <> 193)
    return NULL;

  len := length (path) - 1;
  if (len < 1)
    return NULL;

  tmp := make_array (len, 'any');
  while (inx < len)
    {
      aset (tmp, inx, aref (path,inx));
      inx := inx + 1;
    }
  return tmp;
}
;

create procedure WS.WS.HREF_TO_ARRAY (in path varchar,in host varchar)
{
  declare arr, res any;
  declare inx, len integer;

  arr := split_and_decode (path, 0, '%\0/');
  if (isstring (host) and length (host) > 1)
    inx := 3;
  else
    inx := 0;
  res := vector (); len := length (arr);
  while (inx < len)
    {
      if (length (arr[inx]) > 0)
        res := vector_concat (res, vector (arr[inx]));
      inx := inx + 1;
    }
  return res;
}
;

create procedure WS.WS.HREF_TO_PATH_ARRAY (in path varchar)
{
  declare arr, res any;
  declare inx, len integer;

  arr := split_and_decode (path, 0, '%\0/');
  if (length (arr) < 1)
    return arr;
  if (arr[0] = '')
    inx := 1;
  else if ((length (arr) > 2) and (arr[0][length (arr[0])-1] = 58) and (arr[1] = '') and (arr[2] <> '')) -- protocol / / host
    inx := 3;
  else
    inx := 1;
  res := vector ('');
  len := length (arr);
  while (inx < len)
    {
      if ((inx = len-1) or (length (arr[inx]) > 0))
        res := vector_concat (res, vector (arr[inx]));
      inx := inx + 1;
    }
  return res;
}
;

-- return R(esource) C(ollection)
create procedure WS.WS.DSTIS (in path varchar, in host varchar, out rcol integer, out rname varchar)
{
  declare inx, col, res, id, name_len, depth, cols integer;
  declare name varchar;
  declare rc char;

  rc := '';
  depth := 0;
  inx := 1;
  name := '*';
  col := 0;
  rcol := 0;
  rname := '';
  cols := 0;

  while (name <> '')
    {
      name := WS.WS.PATHREF (path,inx,host,name_len);
      if (name <> '')
	{
          cols := cols + 1;
          if (rc = '' or rc = 'C')
	    {
              rname := name;
	      whenever not found goto no_more_col;
	      select COL_ID into col from WS.WS.SYS_DAV_COL where COL_PARENT = col and COL_NAME = name;
              rcol := col;
              depth := depth + 1;
              rc := 'C';
	    }
	}
      inx := inx + 1;
    }
no_more_col:
  while (name <> '')
    {
      name := WS.WS.PATHREF (path,inx,host,name_len);
      if (name <> '')
	{
	  if (rc = '' or rc = 'C')
	    {
              rname := name;
	      whenever not found goto no_res;
	      select RES_ID into res from WS.WS.SYS_DAV_RES where RES_COL = col and RES_NAME = name;
              rcol := col;
              rc := 'R';
	    }
          cols := cols + 1;
	}
      inx := inx + 1;
    }
no_res:
  if (rc = 'C' and cols - 1 = depth)
    rc := 'N';
  else if (rc = 'C' and cols - 1 > depth )
    rc := 'E';

  return rc;
}
;

create procedure WS.WS.MOVE (in path varchar, inout params varchar, in lines varchar)
{
  WS.WS.COPY_OR_MOVE (path, params, lines, 0);
}
;

create procedure WS.WS.COPY (in path varchar, inout params varchar, in lines varchar)
{
  WS.WS.COPY_OR_MOVE (path, params, lines, 1);
}
;

create procedure WS.WS.COPY_OR_MOVE (in path varchar, inout params varchar, in lines varchar, in is_copy integer)
{
  declare _src_name, st, _dst_name varchar;
  declare _host varchar;
  declare _overwrite char;
  declare _inx, _name_len, _res integer;
  declare _len integer;
  declare id, par_id, _src_id integer;
  declare cont  varchar;
  declare uname, upwd, type, newname, _perms varchar;
  declare dstis char;
  declare _u_id, _g_id integer;
  declare col,res,depth,rc,inx integer;
  declare name, target_path, location varchar;
  declare src_id, dst_id, dst_ura, dst_host, _dst_parent any;
  uname := null;
  upwd := null;
  _u_id := null;
  _g_id := null;

  set isolation = 'serializable';
  WS.WS.IS_REDIRECT_REF (path, lines, location);
  _dst_name := WS.WS.FINDPARAM (lines, 'Destination:');
  _dst_name := WS.WS.FIXPATH (_dst_name);
  _host := WS.WS.FINDPARAM (lines, 'Host:');
  _overwrite := WS.WS.FINDPARAM (lines, 'Overwrite:');
  dst_ura := rfc1808_parse_uri (_dst_name);
  dst_host := dst_ura[1];
  dst_host := split_and_decode (dst_host, 0, '%');

  src_id := DAV_HIDE_ERROR (DAV_SEARCH_SOME_ID (vector_concat (vector(''), path), st));
  if (src_id is null)
  {
    src_id := DAV_HIDE_ERROR (DAV_SEARCH_SOME_ID (vector_concat (vector(''), path, vector('')), st));
    if (src_id is not null)
    {
      path := vector_concat (path, vector(''));
    }
  }
  if (src_id is null)
  {
    DB.DBA.DAV_SET_HTTP_STATUS (404);
    return;
  }
  rc := DAV_AUTHENTICATE_HTTP (src_id, st, case (is_copy) when 1 then '1__' else '11_' end, 1, lines, uname, upwd, _u_id, _g_id, _perms);
  -- dbg_obj_princ ('Source authentication in WS.WS.', case (is_copy) when 1 then 'COPY' else 'MOVE' end, ' gives ', rc, uname, upwd, _u_id, _g_id, _perms);
	if (rc < 0)
	{
    DB.DBA.DAV_SET_AUTHENTICATE_HTTP_STATUS (rc);
		return;
	}
  if (WS.WS.ISLOCKED (vector_concat (vector (''), path), lines, _u_id))
  {
    DB.DBA.DAV_SET_HTTP_STATUS (423);
    return;
  }

  target_path := WS.WS.HREF_TO_PATH_ARRAY (_dst_name);

  -- perform gateway functions
  if (_host <> '' and dst_host <> ''
      and _dst_name <> ''
      and lower (substring (_dst_name, 1, 7)) = 'http://'
      and lower (dst_host) <> lower (_host))
  {
    if (is_copy)
  	{
  	  -- dbg_obj_princ (sprintf ('Copy a WebDAV resource from %s to %s', _host, _dst_name));
  	  log_message (sprintf ('Copy a WebDAV resource from %s to %s', _host, _dst_name));
  	  WS.WS.COPY_TO_OTHER (path, params, lines, _dst_name);
  	}
    else
  	{
  	  -- dbg_obj_princ (sprintf ('Moving a WebDAV resource from %s to %s', _host, _dst_name));
  	  log_message (sprintf ('Moving a WebDAV resource from %s to %s', _host, _dst_name));
  	  if (1 = WS.WS.COPY_TO_OTHER (path, params, lines, _dst_name))
	    {
	      rc := DAV_DELETE_INT (DAV_CONCAT_PATH ('/', path), 0, uname, upwd, 0);
	      if (rc <> 1)
    		{
    		  rollback work;
    		  return rc;
    		}
	    }
  	}
    return;
  }

  if (WS.WS.ISLOCKED (target_path, lines, _u_id))
  {
    DB.DBA.DAV_SET_HTTP_STATUS (423);
    return;
  }

  if ('C' = st)
  {
    if (target_path[length (target_path) - 1] = '')
    {
      _dst_parent := DAV_HIDE_ERROR (DAV_SEARCH_ID (target_path, 'P'));
    }
    else
  	{
  	  declare tgt_res any;
  	  tgt_res := DAV_SEARCH_ID (target_path, 'R');
  	  if (DAV_HIDE_ERROR (tgt_res) is not null)
  	    {
          DB.DBA.DAV_SET_HTTP_STATUS (409);
  	      return;
  	    }
  	  target_path := vector_concat (target_path, vector (''));
            _dst_parent := DAV_HIDE_ERROR (DAV_SEARCH_ID (target_path, 'P'));
  	}
  }
  else
  {
    _dst_parent := DAV_HIDE_ERROR (DAV_SEARCH_ID (target_path, 'P'));
  }
  if (_dst_parent is null)
  {
    DB.DBA.DAV_SET_HTTP_STATUS (409);
    return;
  }
  rc := DAV_AUTHENTICATE_HTTP (_dst_parent, 'C', '11_', 1, lines, uname, upwd, _u_id, _g_id, _perms);
  -- dbg_obj_princ ('Destination parent authentication in WS.WS.', case (is_copy) when 1 then 'COPY' else 'MOVE' end, ' gives ', rc, uname, upwd, _u_id, _g_id, _perms);
	if (rc < 0)
	{
    DB.DBA.DAV_SET_AUTHENTICATE_HTTP_STATUS (rc);
		return;
	}
  if (is_copy)
  {
    rc := DAV_COPY_INT (DAV_CONCAT_PATH ('/', path), DAV_CONCAT_PATH ('/', target_path), case (_overwrite) when 'T' then 1 else 0 end, _perms, uname, null, uname, upwd, 0, 0);
    -- dbg_obj_princ ('DAV_COPY_INT () returns ', rc);
  }
  else
  {
    rc := DAV_MOVE_INT (DAV_CONCAT_PATH ('/', path), DAV_CONCAT_PATH ('/', target_path), case (_overwrite) when 'T' then 1 else 0 end, uname, upwd, 0, 0);
    -- dbg_obj_princ ('DAV_MOVE_INT () returns ', rc);
  }
  if (DAV_HIDE_ERROR (rc, null) is not null)
  {
    DB.DBA.DAV_SET_HTTP_STATUS (204);
  }
  else if (rc = 0)
  {
    DB.DBA.DAV_SET_HTTP_STATUS ('HTTP/1.1 207 Multi-Status');
  }
  else if (rc = -2)
  {
    DB.DBA.DAV_SET_HTTP_STATUS (409);
  }
  else if (rc = -3)
  {
    DB.DBA.DAV_SET_HTTP_STATUS ('HTTP/1.1 412 Precondition Failed');
  }
  else
  {
    DAV_SET_HTTP_REQUEST_STATUS (rc);
  }
  return;
}
;


-- return 0 not locked, 1 shareable lock, 2 exclusive lock
create procedure WS.WS.ISLOCKED (in path any, in lines varchar, in _u_id integer)
{
  declare name, token, if_token varchar;
  declare col, id, rc, len, owner integer;
  declare type, scope char;
  declare l_cur cursor for select LOCK_SCOPE, LOCK_OWNER, LOCK_TOKEN from WS.WS.SYS_DAV_LOCK
      where LOCK_PARENT_ID = id and LOCK_PARENT_TYPE = type;
  -- first check for expired locks
  if (exists (select 1 from WS.WS.SYS_DAV_LOCK where datediff ('second', LOCK_TIME, now()) > LOCK_TIMEOUT))
    {
      delete from WS.WS.SYS_DAV_LOCK where datediff ('second', LOCK_TIME, now()) > LOCK_TIMEOUT;
      --commit work;
    }
  rc := 0;
  if (path is null)
    {
      -- dbg_obj_princ ('NULL path -> no locks');
      return 0;
    }
  len := length (path);
  if_token := WS.WS.FINDPARAM (lines, 'If:');
  if (isnull (if_token))
    if_token := '';
  id := DAV_HIDE_ERROR (DAV_SEARCH_SOME_ID (path, type), null);
  -- dbg_obj_princ ('WS.WS.ISLOCKED has found id = ', id, ', type = ', type, ' for path ', path);
  if (id is null)
    return 0;
  if (len > 1)
    {
      rc := WS.WS.ISLOCKED (WS.WS.PARENT_PATH (path), lines, _u_id);
      if (rc > 0)
        return rc;
    }
  if (isarray (id))
    {
      rc := call (cast (id[0] as varchar) || '_DAV_IS_LOCKED') (id, type, if_token);
      return rc;
    }
  whenever not found goto not_locked;
  open l_cur (prefetch 1);
  fetch l_cur into scope, owner, token;
  if (scope = 'X')
     rc := 2;
  else
     rc := 1;
  if (not isnull (strstr (if_token, token)))
    rc := 0;
not_locked:
  -- dbg_obj_princ ('WS.WS.ISLOCKED found ', rc, ' for id = ', id, ', type = ', type, ' for path ', path);
  close l_cur;
    return rc;
}
;

create procedure WS.WS.CHECK_AUTH (in lines any)
{
  declare _u_group, _u_id integer;
  declare _perms varchar;
  _u_id := WS.WS.GET_AUTH (lines, _u_group, _perms);
  return _u_id;
}
;


create procedure WS.WS.GET_IF_AUTH (in lines any, out _u_group integer, out _perms varchar)
{
  declare _u_id integer;
  if ('' <> WS.WS.FINDPARAM (lines, 'Authorization:') and db.dba.vsp_auth_vec (lines) <> 0)
    {
      _u_id := WS.WS.GET_AUTH (lines, _u_group, _perms);
    }
  else
    {
      _u_id := http_nobody_uid ();
      _u_group := http_nogroup_gid ();
      _perms := '110110110-' || '-';
      connection_set ('DAVUserID', _u_id);
      connection_set ('DAVBillingUserID', _u_id);
      connection_set ('DAVGroupID', _u_group);
    }
  return _u_id;
}
;

create procedure WS.WS.GET_DAV_AUTH (in lines any, in allow_anon integer, in can_write_http integer,
 out _u_name varchar, out _u_password varchar, out _uid integer, out _gid integer, out _perms varchar) returns integer
{
  declare auth any;
  declare _user varchar;
  declare our_auth_vec varchar;
  declare _method, rc integer;
--  declare quota integer;
  _u_name := null;
  _u_password := null;
  _uid := null;
  _gid := null;
  _perms := null;

  auth := db.dba.vsp_auth_vec (lines);

  if (0 = auth)
    {
      goto request_auth;
    }

  _user := get_keyword ('username', auth);

  if (_user = '' or isnull (_user))
    {
      _user := null;
      goto request_auth;
    }

  allow_anon := 0; -- If there's a username then it should not be handled as anonymous
  whenever not found goto request_auth;

  set isolation='committed';
  select U_NAME, U_PWD, U_GROUP, U_ID, U_METHODS, U_DEF_PERMS
    into _u_name, _u_password, _gid, _uid, _method, _perms from WS.WS.SYS_DAV_USER
    where U_NAME = _user and U_ACCOUNT_DISABLED = 0 and U_PWD is not null with (prefetch 1);
  -- dbg_obj_princ ('WS.WS.GET_DAV_AUTH knows ', _u_name, _u_password, _gid, _uid, _method, _perms);


  rc := -1;

  if (sys_stat ('dbev_enable') and __proc_exists ('DB.DBA.DBEV_DAV_LOGIN'))
    {
      rc := DB.DBA.DBEV_DAV_LOGIN (_user, _u_password, auth);
    }
  else
    {
      rc := DB.DBA.LDAP_LOGIN (_user, _u_password, auth);
    }

  if (rc = 0) -- PLLH_INVALID, must reject
    goto request_auth;
  if (rc = 1) -- PLLH_VALID, authentication is already done
    goto authenticated;
  -- rc = -1 PLLH_NO_AUTH, should check

  if (_u_password is null)
    goto request_auth;

  if (not db.dba.vsp_auth_verify_pass (auth, _u_name,
			    coalesce(get_keyword ('realm', auth), ''),
			    coalesce(get_keyword ('uri', auth), ''),
			    coalesce(get_keyword ('nonce', auth), ''),
			    coalesce(get_keyword ('nc', auth),''),
			    coalesce(get_keyword ('cnonce', auth), ''),
			    coalesce(get_keyword ('qop', auth), ''),
			    _u_password))
    goto request_auth;

authenticated:
    {
--      quota := coalesce (DB.DBA.USER_GET_OPTION (_user, 'DAVQuota'), 5242880);
      update WS.WS.SYS_DAV_USER set U_LOGIN_TIME = now () where U_NAME = _user
	  and U_LOGIN_TIME < dateadd ('minute', -2, now ());
      connection_set ('DAVUserID', _uid);
      connection_set ('DAVBillingUserID', _uid);
      connection_set ('DAVGroupID', _gid);
--      connection_set ('DAVQuota', quota);
      commit work;
      set isolation='repeatable';
      return _uid;
    }

request_auth:
  _u_name := null;
  _u_password := null;
  _uid := null;
  _gid := null;
  _perms := null;
  if (allow_anon)
    {
      _uid := http_nobody_uid ();
      _gid := http_nogroup_gid ();
      connection_set ('DAVUserID', _uid);
      connection_set ('DAVBillingUserID', _uid);
      connection_set ('DAVGroupID', _gid);
      _perms := '110110110RR';
      return 0;
    }
  if (not can_write_http)
    return -12;

  db.dba.vsp_auth_get ('DAV', '/DAV', md5 (datestring(now())), md5 ('opaakki'), 'false', lines, 1);
  return -24;
}
;

create procedure WS.WS.PERM_COMP (in perm varchar, in mask varchar)
{
  declare inx integer;
  inx := 0;
  if (length (perm) <> 3 or length (mask) <> 3)
    return 0;

  while (inx < 3)
    {
       if (aref (mask, inx) = ascii('1') and aref (perm, inx) <> ascii('1'))
	 {
	   return 0;
	 }
     inx := inx + 1;
    }
  return 1;
}
;

-- return 1 if authorized to perform action (Write,Read,eXecute '111')
create procedure WS.WS.CHECKPERM ( in path varchar, in _u_id integer, in action varchar)
{
  declare g_id, _user, _group integer;
  declare _perms varchar;
  declare name varchar;
  declare col integer;
  declare temp varchar;
  declare rc integer;
  rc := 0;
  _perms := '000000000';
  if (_u_id > 0 and _u_id is not null)
    {
      g_id := connection_get ('DAVGroupID');
    }
  -- the WebDAV administrator have all privileges except execute
  if (_u_id = http_dav_uid () and action not like '__1')
    {
      connection_set ('DAVQuota', -1);
      return 1;
    }
  if (WS.WS.ISCOL (path))
    {
      WS.WS.FINDCOL (path, col);
      select COL_OWNER, COL_GROUP, COL_PERMS into _user, _group, _perms from WS.WS.SYS_DAV_COL where COL_ID = col;
    }
  else if (WS.WS.ISRES (path))
    {
      WS.WS.FINDRES (path, col, name);
      select RES_OWNER, RES_GROUP, RES_PERMS into _user, _group, _perms
	  from WS.WS.SYS_DAV_RES where RES_COL = col and RES_NAME = name;
    }
  else if (not WS.WS.ISCOL(path) and not WS.WS.ISRES (path) and WS.WS.ISCOL (WS.WS.PARENT_PATH (path)))
    {
      if (is_http_ctx())
        DB.DBA.DAV_SET_HTTP_STATUS (404);

      return 0;
    }
  if (_perms is null)
    return 0;
  if (_u_id = _user)
    {
      temp := substring (cast (_perms as varchar), 1, 3);
      rc := WS.WS.PERM_COMP (temp, action);
    }
  if (_group = g_id and rc = 0)
    {
      temp := substring (cast (_perms as varchar), 4, 3);
      rc := WS.WS.PERM_COMP (temp, action);
    }
  if (rc = 0)
    {
      temp := substring (cast (_perms as varchar), 7, 3);
      rc := WS.WS.PERM_COMP (temp, action);
    }
  -- if not a public, not in primary group or owner then check for granted groups
  if (rc = 0)
    {
      temp := substring (cast (_perms as varchar), 4, 3);
      rc := WS.WS.PERM_COMP (temp, action);
      if (rc > 0 and exists (select 1 from WS.WS.SYS_DAV_USER_GROUP where UG_UID = _u_id and UG_GID = _group))
	{
          rc := 1;
	}
      else
	rc := 0;
    }
  if (rc = 0 and is_http_ctx ())
  {
    DB.DBA.DAV_SET_HTTP_STATUS (403);
  }
  return rc;
}
;

create procedure WS.WS.ISPUBLIC (in path varchar, in ask varchar)
{
  declare perms, name, given varchar;
  declare res, col integer;
  whenever not found goto nf;
  if (WS.WS.ISCOL (path))
    {
      WS.WS.FINDCOL (path, col);
      select COL_PERMS into perms from WS.WS.SYS_DAV_COL where COL_ID = col;
    }
  else if (WS.WS.ISRES (path))
    {
      WS.WS.FINDRES (path, col, name);
      select RES_PERMS into perms from WS.WS.SYS_DAV_RES where RES_NAME = name and RES_COL = col;
    }
  else
   return 0;
  if (perms is null)
    return 0;
  given := substring (cast (perms as varchar), 7, 3);
  return WS.WS.PERM_COMP (given, ask);
nf:
  return 0;
}
;

create procedure
WS.WS.DAV_VSP_DEF_REMOVE (in path varchar)
{
  if (path like '%.vsp')
    {
      declare stat, msg varchar;
      stat := '00000'; msg := '';
      for select P_NAME from DB.DBA.SYS_PROCEDURES where P_NAME like concat ('%.%.', path)
	do
	  {
            exec (sprintf ('drop procedure "%s"', P_NAME), stat, msg);
	  }
    }
}
;

create function DAV_PERMS_SET_CHAR (in perms varchar, in ch any, in pos integer) returns varchar
{
  declare l integer;
  l := length (perms);
  if (l < 11)
    perms := perms || subseq ('000000000--', l);
  if (isinteger (ch))
    perms [pos] := ch;
  else
    perms[pos] := ch[0];
  return perms;
}
;

create procedure DAV_PERMS_FIX (inout perms varchar, in full_perms varchar)
{
  declare l integer;
  l := length (perms);
  if (l < 11)
    perms := perms || subseq (full_perms, l);
  if (ascii('-') = perms [9])
    perms[9] := full_perms[9];
  if (ascii('-') = perms [10])
    perms[10] := full_perms[10];
}
;

create procedure DAV_PERMS_INHERIT (inout perms varchar, in parent_perms varchar, in force_parent integer := 0)
{
  declare l integer;
  l := length (perms);
  if (l < 11)
    perms := perms || subseq (parent_perms, l);
  if ((ascii('-') = perms [9]) or (force_parent and (ascii('T') <> parent_perms [9])))
    perms[9] := parent_perms[9];
  if ((ascii('-') = perms [10]) or (force_parent and (ascii('M') <> parent_perms [10])))
    perms[10] := parent_perms[10];
}
;

-- Triggers for full_path column
create trigger SYS_DAV_RES_FULL_PATH_I after insert on WS.WS.SYS_DAV_RES order 0 referencing new as N
{
  declare full_path, name, _pflags, _rflags, _inh varchar;
  declare parent_col, col, res integer;
  -- dbg_obj_princ ('trigger SYS_DAV_RES_FULL_PATH_I (', N.RES_ID, ')');
--  if (not WS.WS.DAV_CHECK_QUOTA ())
--    {
--      http_request_status ('HTTP/1.1 507 Insufficient Storage');
--      rollback work;
--      -- dbg_obj_princ ('trigger SYS_DAV_RES_FULL_PATH_I (', N.RES_ID, ') signal');
--      signal ('VSPRT', 'Storage Limit exceeded');
--    }
  col := N.RES_COL;
  res := N.RES_ID;
  _rflags := N.RES_PERMS;
  full_path := concat ('/', N.RES_NAME);
  select COL_PERMS, COL_INHERIT into _pflags, _inh from WS.WS.SYS_DAV_COL where COL_ID = col;
  if (_inh = 'R' or _inh = 'M')
    _rflags := _pflags;
  DAV_PERMS_FIX (_pflags, '000000000TM');
  DAV_PERMS_INHERIT (_rflags, _pflags);
  whenever not found goto not_found;
  while (1)
    {
      select COL_NAME, COL_PARENT into name, parent_col from WS.WS.SYS_DAV_COL where COL_ID = col;
      col := parent_col;
      full_path := concat ('/', name, full_path);
    }
not_found:
  DAV_SPACE_QUOTA_RES_INSERT (full_path, DAV_RES_LENGTH (N.RES_CONTENT, N.RES_SIZE));
  set triggers off;
  -- dbg_obj_princ ('inserted perms = ', N.RES_PERMS, ', patched perms = ', _rflags);
  if (_rflags <> N.RES_PERMS)
    {
      update WS.WS.SYS_DAV_RES set RES_FULL_PATH = full_path, RES_PERMS = _rflags where RES_ID = res;
      N.RES_PERMS := _rflags;
    }
  else
    update WS.WS.SYS_DAV_RES set RES_FULL_PATH = full_path where RES_ID = res;
  -- dbg_obj_princ ('trigger SYS_DAV_RES_FULL_PATH_I has updated full path.');
  -- DAV_DEBUG_CHECK_SPACE_QUOTAS ();
  N.RES_FULL_PATH := full_path;
-- REPLICATION
  declare pub varchar;
  declare uname, gname varchar;
  uname := ''; gname := '';
  pub := WS.WS.ISPUBL (full_path);
  if (isstring (pub))
    {
      -- dbg_obj_princ ('RES INS: ', pub, ' -> ' , full_path);
      whenever not found goto nfu;
      select U_NAME into uname from WS.WS.SYS_DAV_USER where U_ID = N.RES_OWNER;
nfu:;
      whenever not found goto nfg;
      select G_NAME into gname from WS.WS.SYS_DAV_GROUP where G_ID = N.RES_GROUP;
nfg:;
      repl_text (pub, '"DB.DBA.DAV_RES_I" (?, ?, ?, ?, ?, ?, ?)', full_path, N.RES_CR_TIME,
	  uname, gname, N.RES_PERMS, N.RES_TYPE, WS.WS.BODY_ARR (N.RES_CONTENT, null));
    }
-- END REPLICATION
  if (N.RES_TYPE = 'text/xsl')
    xslt_stale (concat ('virt://WS.WS.SYS_DAV_RES.RES_FULL_PATH.RES_CONTENT:', N.RES_FULL_PATH));
  -- dbg_obj_princ ('trigger SYS_DAV_RES_FULL_PATH_I (', N.RES_ID, ') done');
}
;

create trigger SYS_DAV_RES_FULL_PATH_BU before update on WS.WS.SYS_DAV_RES referencing old as O, new as N
{
  declare _pflags, _rflags, _inh varchar;
  declare col integer;
  -- dbg_obj_princ ('trigger SYS_DAV_RES_FULL_PATH_BU (', N.RES_ID, ')');
  _rflags := N.RES_PERMS;
  if ((O.RES_COL <> N.RES_COL) or (O.RES_PERMS <> N.RES_PERMS))
    {
      col := N.RES_COL;
      select COL_PERMS, COL_INHERIT into _pflags, _inh from WS.WS.SYS_DAV_COL where COL_ID = col;
      if (_inh = 'M' or _inh = 'R')
        _rflags := _pflags;
      DAV_PERMS_FIX (_pflags, '000000000TM');
      DAV_PERMS_INHERIT (_rflags, _pflags, neq (O.RES_COL, N.RES_COL));
    }
  if (_rflags <> N.RES_PERMS)
    {
      set triggers off;
      -- dbg_obj_princ ('old perms = ', O.RES_PERMS, ', new perms = ', N.RES_PERMS, ', patched perms = ', _rflags);
      update WS.WS.SYS_DAV_RES set RES_PERMS = _rflags where RES_ID = N.RES_ID;
      N.RES_PERMS := _rflags;
    }
  -- dbg_obj_princ ('trigger SYS_DAV_RES_FULL_PATH_BU (', N.RES_ID, ') done');
}
;

create trigger SYS_DAV_RES_FULL_PATH_U after update on WS.WS.SYS_DAV_RES referencing old as O, new as N
{
  declare full_path, name varchar;
  declare parent_col, col, res integer;
  declare str, cont varchar;
  -- dbg_obj_princ ('trigger SYS_DAV_RES_FULL_PATH_U (', N.RES_ID, ')');

--  if (not WS.WS.DAV_CHECK_QUOTA ())
--    {
--      http_request_status ('HTTP/1.1 507 Insufficient Storage');
--      rollback work;
--      -- dbg_obj_princ ('trigger SYS_DAV_RES_FULL_PATH_U (', N.RES_ID, ') signal');
--      signal ('VSPRT', 'Storage Limit exceeded');
--    }

  col := N.RES_COL;
  res := N.RES_ID;
  full_path := concat ('/', N.RES_NAME);
  whenever not found goto not_found;
  while (1)
    {
      select COL_NAME, COL_PARENT into name, parent_col from WS.WS.SYS_DAV_COL where COL_ID = col;
      col := parent_col;
      full_path := concat ('/', name, full_path);
    }
not_found:
  set triggers off;
  DAV_SPACE_QUOTA_RES_UPDATE (O.RES_FULL_PATH, DAV_RES_LENGTH (O.RES_CONTENT, O.RES_SIZE), full_path, length (N.RES_CONTENT));
  -- delete all associated url entries
  if (O.RES_FULL_PATH <> full_path)
    {
      update WS.WS.VFS_URL set VU_ETAG = '' where VU_RES_ID = O.RES_ID;
    }
  -- end of urls removal
  WS.WS.DAV_VSP_DEF_REMOVE (O.RES_FULL_PATH);
  -- dbg_obj_princ ('trigger SYS_DAV_RES_FULL_PATH_U: set RES_FULL_PATH = ', full_path, ', triggers off');
  update WS.WS.SYS_DAV_RES set RES_FULL_PATH = full_path where RES_ID = res;
  N.RES_FULL_PATH := full_path;
  -- dbg_obj_princ ('trigger SYS_DAV_RES_FULL_PATH_U has updated full path.');
  -- DAV_DEBUG_CHECK_SPACE_QUOTAS ();
-- REPLICATION
  declare pub, pub1 varchar;
  declare uname, gname varchar;
  uname := ''; gname := '';
  pub := WS.WS.ISPUBL (O.RES_FULL_PATH);
  pub1 := WS.WS.ISPUBL (full_path);
  if (isstring (pub))
    {
      -- dbg_obj_princ ('RES DEL: ', pub, ' -> ' , O.RES_FULL_PATH);
      repl_text (pub, '"DB.DBA.DAV_RES_D" (?)', O.RES_FULL_PATH);
    }

  if (isstring (pub1))
    {
      -- dbg_obj_princ ('RES INS: ', pub1, ' -> ' , full_path);
      whenever not found goto nfu;
      select U_NAME into uname from WS.WS.SYS_DAV_USER where U_ID = N.RES_OWNER;
nfu:;
      whenever not found goto nfg;
      select G_NAME into gname from WS.WS.SYS_DAV_GROUP where G_ID = N.RES_GROUP;
nfg:;
      repl_text (pub1, '"DB.DBA.DAV_RES_I" (?, ?, ?, ?, ?, ?, ?)', full_path, N.RES_MOD_TIME,
	 uname, gname, N.RES_PERMS, N.RES_TYPE, WS.WS.BODY_ARR (N.RES_CONTENT, null));
    }
-- END REPLICATION
  if (N.RES_TYPE = 'text/xsl')
    xslt_stale (concat ('virt://WS.WS.SYS_DAV_RES.RES_FULL_PATH.RES_CONTENT:', N.RES_FULL_PATH));
  -- dbg_obj_princ ('trigger SYS_DAV_RES_FULL_PATH_U (', N.RES_ID, ') done');
}
;

create trigger SYS_DAV_COL_U after update on WS.WS.SYS_DAV_COL referencing old as O, new as N
{
  declare full_path, name, _pflags, _cflags varchar;
  declare old_col_path, new_col_path varchar;
  declare res, col integer;
  -- dbg_obj_princ ('trigger SYS_DAV_COL_U (', N.COL_ID, ')');
  col := N.COL_PARENT;
  res := N.COL_ID;
  full_path := concat ('/', N.COL_NAME,'/');
  _cflags := N.COL_PERMS;
  _pflags := coalesce ((select COL_PERMS from WS.WS.SYS_DAV_COL where COL_ID = col), '000000000TM');
  if ((O.COL_PARENT <> N.COL_PARENT) or (O.COL_PERMS <> N.COL_PERMS))
    {
      DAV_PERMS_FIX (_pflags, '000000000TM');
      DAV_PERMS_INHERIT (_cflags, _pflags);
    }
  whenever not found goto not_found;
  while (1)
    {
      select COL_NAME, COL_PARENT into name, col from WS.WS.SYS_DAV_COL where COL_ID = col;
      full_path := concat ('/', name, full_path);
    }
not_found:
  set triggers off;
  if (_cflags <> N.COL_PERMS)
    {
      -- dbg_obj_princ ('old perms = ', O.COL_PERMS, ', new perms = ', N.COL_PERMS, ', patched perms = ', _cflags);
      update WS.WS.SYS_DAV_COL set COL_PERMS = _cflags where COL_ID = res;
      N.COL_PERMS := _cflags;
    }
  old_col_path := concat (WS.WS.COL_PATH (O.COL_PARENT), O.COL_NAME, '/');
  new_col_path := WS.WS.COL_PATH (N.COL_ID);
  if (old_col_path <> new_col_path)
    {
      -- dbg_obj_princ ('trigger SYS_DAV_COL_U: CatFilter-related operations for move from ', old_col_path, ' to ', new_col_path);
      for
        select SUBCOL_ID, SUBCOL_FULL_PATH as old_subcol_path, SUBCOL_DET
        from DAV_PLAIN_SUBMOUNTS
        where root_id = O.COL_ID and root_path = old_col_path and recursive=1 and subcol_auth_uid = http_dav_uid()
        and not (SUBCOL_DET like '%Filter')
      do
        {
          declare new_subcol_path varchar;
          new_subcol_path := new_col_path || subseq (old_subcol_path, length (old_col_path));
          for
            select CF_ID from WS.WS.SYS_DAV_CATFILTER
            where (
              ("LEFT" (old_subcol_path, length (CF_SEARCH_PATH)) = CF_SEARCH_PATH) and
              ("LEFT" (new_subcol_path, length (CF_SEARCH_PATH)) <> CF_SEARCH_PATH) )
            do
              {
                delete from WS.WS.SYS_DAV_CATFILTER_DETS where CFD_CF_ID = CF_ID and CFD_DET_SUBCOL_ID = SUBCOL_ID;
              }
          for
            select CF_ID from WS.WS.SYS_DAV_CATFILTER
            where (
              ("LEFT" (old_subcol_path, length (CF_SEARCH_PATH)) <> CF_SEARCH_PATH) and
              ("LEFT" (new_subcol_path, length (CF_SEARCH_PATH)) = CF_SEARCH_PATH) )
            do
              {
                insert replacing WS.WS.SYS_DAV_CATFILTER_DETS (CFD_CF_ID, CFD_DET_SUBCOL_ID, CFD_DET) values (CF_ID, SUBCOL_ID, SUBCOL_DET);
              }
        }
    }
  if (
    (N.COL_DET is not null or O.COL_DET is not null) and
    not (N.COL_DET is not null and O.COL_DET is not null and (N.COL_DET = O.COL_DET) and (N.COL_ID = O.COL_ID) and (N.COL_PARENT = O.COL_PARENT)))
    {
      -- dbg_obj_princ ('trigger SYS_DAV_COL_U: CatFilter-related operations for own record in WS.WS.SYS_DAV_CATFILTER_DETS');
      delete from WS.WS.SYS_DAV_CATFILTER_DETS where CFD_DET_SUBCOL_ID = O.COL_ID;
      if (N.COL_DET is not null and not (N.COL_DET like '%Filter'))
        {
          for select CF_ID from WS.WS.SYS_DAV_CATFILTER where "LEFT" (new_col_path, length (CF_SEARCH_PATH)) = CF_SEARCH_PATH do
            {
              insert replacing WS.WS.SYS_DAV_CATFILTER_DETS (CFD_CF_ID, CFD_DET_SUBCOL_ID, CFD_DET)
              values (CF_ID, N.COL_ID, N.COL_DET);
            }
        }
    }
-- REPLICATION
  declare repl varchar;
  repl := null;
  declare pub, pub1 varchar;
  declare uname, gname varchar;

  uname := ''; gname := '';
  pub := WS.WS.ISPUBL (old_col_path);
  pub1 := WS.WS.ISPUBL (new_col_path);
  if (isstring (pub1))
    {
      whenever not found goto nfu;
      select U_NAME into uname from WS.WS.SYS_DAV_USER where U_ID = N.COL_OWNER;
nfu:;
      whenever not found goto nfg;
      select G_NAME into gname from WS.WS.SYS_DAV_GROUP where G_ID = N.COL_GROUP;
nfg:;
    }
  if ((not isstring (pub) and isstring (pub1)) or (isstring (pub) and isstring (pub1) and pub <> pub1))
    {
      -- dbg_obj_princ ('COL INS: ', pub1, ' -> ' , new_col_path);
      repl_text (pub1, '"DB.DBA.DAV_COL_I" (?, ?, ?, ?, ?, ?)',
	    N.COL_NAME, new_col_path, N.COL_CR_TIME, uname, gname,
	    N.COL_PERMS );
      repl := pub1;
    }
  if (isstring (pub) and isstring (pub1) and pub = pub1)
    {
      -- dbg_obj_princ ('COL UPD: ', old_col_path, ' -> ' , new_col_path);
      repl_text (pub1, '"DB.DBA.DAV_COL_U" (?, ?, ?, ?, ?, ?)',
	    old_col_path, new_col_path, N.COL_CR_TIME, uname, gname,
	    N.COL_PERMS );
    }
  if ((not isstring (pub1) and isstring (pub)) or (isstring (pub) and isstring (pub1) and pub <> pub1))
    {
      -- dbg_obj_princ ('COL DEL: ', pub, ' -> ' , old_col_path);
      repl_text (pub, '"DB.DBA.DAV_COL_D" (?, 1)', old_col_path);
    }
-- END REPLICATION
  WS.WS.UPDCHILD (res, full_path, _pflags, repl);
  set triggers on;
  if (ascii('R') = _pflags[9])
    update WS.WS.SYS_DAV_RES set RES_PERMS = DAV_PERMS_SET_CHAR (RES_PERMS, 'T', 9)
	where (RES_FULL_PATH between full_path and DAV_COL_PATH_BOUNDARY (full_path))
	      and RES_PERMS[9] = ascii ('N');
  else
    update WS.WS.SYS_DAV_RES set RES_PERMS = DAV_PERMS_SET_CHAR (RES_PERMS, _pflags[9], 9)
	where RES_COL = res and (case (lt (length (RES_PERMS), 10)) when 1 then 0 else RES_PERMS[9] end) <> _pflags[9];
  if (ascii('R') = _pflags[10])
    update WS.WS.SYS_DAV_RES set RES_PERMS = DAV_PERMS_SET_CHAR (RES_PERMS, 'M', 10)
	where (RES_FULL_PATH between full_path and DAV_COL_PATH_BOUNDARY (full_path))
	      and RES_PERMS[10] = ascii ('N');
  else
    update WS.WS.SYS_DAV_RES set RES_PERMS = DAV_PERMS_SET_CHAR (RES_PERMS, _pflags[10], 10)
	where RES_COL = res and (case (lt (length (RES_PERMS), 11)) when 1 then 0 else RES_PERMS[10] end) <> _pflags[10];
  -- dbg_obj_princ ('trigger SYS_DAV_COL_U (', N.COL_ID, ') done');
}
;

create procedure WS.WS.UPDCHILD (in col integer, in root_path varchar, in _pflags varchar, in repl varchar)
{
  declare name, new_path, str varchar;
  declare id integer;
  declare c_cur cursor for select COL_ID, COL_NAME, COL_MOD_TIME, COL_PERMS, COL_OWNER, COL_GROUP
      from WS.WS.SYS_DAV_COL where COL_PARENT = col;

  for select RES_ID, RES_NAME, RES_FULL_PATH from WS.WS.SYS_DAV_RES where RES_COL = col do
    {
      -- WebRobot URLs update
      update WS.WS.VFS_URL set VU_ETAG = '' where VU_RES_ID = RES_ID;
      -- drop VSPs
      if (RES_NAME like '%.vsp')
        WS.WS.DAV_VSP_DEF_REMOVE (RES_FULL_PATH);
    }
  -- dbg_obj_princ ('WS.WS.UPDCHILD (', col, root_path, _pflags, repl, ') updates RES_FULL_PATH');
  update WS.WS.SYS_DAV_RES set RES_FULL_PATH = concat (root_path, RES_NAME) where RES_COL = col and ((RES_FULL_PATH <> concat (root_path, RES_NAME)) or RES_FULL_PATH is null);
  if (ascii ('R') = _pflags[9])
    update WS.WS.SYS_DAV_COL set COL_PERMS = DAV_PERMS_SET_CHAR (COL_PERMS, 'R', 9)
	where COL_PARENT = col and ascii ('R') <> COL_PERMS[9];
  if (ascii ('R') = _pflags[10])
    update WS.WS.SYS_DAV_COL set COL_PERMS = DAV_PERMS_SET_CHAR (COL_PERMS, 'R', 10)
	where COL_PARENT = col and ascii ('R') <> COL_PERMS[10];

-- REPLICATION
   declare _grp, _uid integer;
   declare cperms varchar;
   declare ctime datetime;
   declare uname, gname varchar;
   declare rn, rt, rc, rp varchar;
   declare ro, rg integer;
   declare rmt datetime;
   declare chr cursor for select RES_NAME, RES_TYPE, RES_CONTENT, RES_PERMS,
                                 RES_OWNER, RES_GROUP, RES_MOD_TIME from WS.WS.SYS_DAV_RES
                      where RES_COL = col;
   if (repl is not null)
     {
       whenever not found goto er;
       open chr;
       while (1)
	     {
	       fetch chr into rn, rt, rc, rp, ro, rg, rmt;
	       whenever not found goto nfu;
	       select U_NAME into uname from WS.WS.SYS_DAV_USER where U_ID = ro;
nfu:;
               whenever not found goto nfg;
               select G_NAME into gname from WS.WS.SYS_DAV_GROUP where G_ID = rg;
nfg:;
               repl_text (repl, '"DB.DBA.DAV_RES_I" (?, ?, ?, ?, ?, ?, ?)', concat (root_path, rn),
		   rmt, uname, gname, rp, rt, WS.WS.BODY_ARR (rc, null));
             }
er:
       close chr;

     }
-- END REPLICATION
  whenever not found goto not_col;
  open c_cur;
  while (1)
    {
      fetch c_cur into id, name, ctime, cperms, _uid, _grp;
      new_path := concat (root_path, name, '/');
-- REPLICATION
      if (repl is not null)
	{
	       whenever not found goto nfu1;
	       select U_NAME into uname from WS.WS.SYS_DAV_USER where U_ID = _uid;
nfu1:;
               whenever not found goto nfg1;
               select G_NAME into gname from WS.WS.SYS_DAV_GROUP where G_ID = _grp;
nfg1:;
          repl_text (repl, '"DB.DBA.DAV_COL_I" (?, ?, ?, ?, ?, ?)',
	    name, new_path, ctime, uname, gname,
	    cperms );
	}
-- END REPLICATION
      WS.WS.UPDCHILD (id, new_path, _pflags, repl);
    }
not_col:
  close c_cur;
}
;

create trigger SYS_DAV_COL_I after insert on WS.WS.SYS_DAV_COL referencing new as N
{
  declare _pflags, _cflags, col_path, _inh varchar;
  declare _col, _p_col integer;
  -- dbg_obj_princ ('trigger SYS_DAV_COL_I (', N.COL_ID, ')');
  _col := N.COL_ID;
  _p_col := N.COL_PARENT;
  col_path := WS.WS.COL_PATH (N.COL_ID);
  set triggers off;
  _cflags := N.COL_PERMS;
  _pflags := '000000000NN';
  _inh := 'N';
  for select COL_PERMS, COL_INHERIT from WS.WS.SYS_DAV_COL where COL_ID = _p_col do
    {
      _pflags := COL_PERMS;
      _inh := COL_INHERIT;
    }
  if (_inh = 'R')
    _cflags := _pflags;
  DAV_PERMS_FIX (_cflags, _pflags);
  if (_cflags <> N.COL_PERMS)
    update WS.WS.SYS_DAV_COL set COL_PERMS = _cflags where COL_ID = _col;
  if (N.COL_DET is not null and not (N.COL_DET like '%Filter'))
    {
      for select CF_ID from WS.WS.SYS_DAV_CATFILTER where "LEFT" (col_path, length (CF_SEARCH_PATH)) = CF_SEARCH_PATH do
        {
          insert replacing WS.WS.SYS_DAV_CATFILTER_DETS (CFD_CF_ID, CFD_DET_SUBCOL_ID, CFD_DET)
          values (CF_ID, _col, N.COL_DET);
        }
    }
-- REPLICATION
  declare pub varchar;
  declare uname, gname varchar;
  uname := ''; gname := '';
  pub := WS.WS.ISPUBL (col_path);
  if (isstring (pub))
    {
      -- dbg_obj_princ ('COLL INS: ', pub, ' -> ' ,col_path);
      whenever not found goto nfu;
       select U_NAME into uname from WS.WS.SYS_DAV_USER where U_ID = N.COL_OWNER;
nfu:;
      whenever not found goto nfg;
       select G_NAME into gname from WS.WS.SYS_DAV_GROUP where G_ID = N.COL_GROUP;
nfg:;
       repl_text (pub, '"DB.DBA.DAV_COL_I" (?, ?, ?, ?, ?, ?)',
	    N.COL_NAME, col_path, N.COL_CR_TIME, uname, gname, N.COL_PERMS );
    }
-- END REPLICATION
  -- dbg_obj_princ ('trigger SYS_DAV_COL_I (', N.COL_ID, ') done');
}
;

create procedure
WS.WS.DAV_VSP_INCLUDES_CHANGED (in full_path varchar, in own varchar)
{
  declare incst, dep any;
  dep := null;
  incst := registry_get (concat ('__depend_', own, '_', full_path));
  if (isstring (incst))
    dep := deserialize (incst);
  if (isarray (dep))
    {
      declare i, l integer;
      declare mt datetime;
      l := length (dep); i := 0;
      if (mod (l, 2))
        return 1;
      while (i < l)
	{
	  if (not exists (select 1 from WS.WS.SYS_DAV_RES
		where RES_FULL_PATH = dep [i] and RES_MOD_TIME = stringdate(dep [i+1])))
	    return 1;
          i := i + 2;
	}
    }
  return 0;
}
;

-- /* Expands the included VSP code */
create procedure WS.WS.EXPAND_INCLUDES (in path varchar, inout stream varchar, in level integer,
    in ct integer, in content varchar, inout st any := null)
{
  declare curr_file, new_file_name, name, _perms varchar;
  declare include_inx, end_tag_inx, _u_id, _grp integer;
  declare apath any;
  declare rc, col integer;
  declare modt datetime;

  end_tag_inx := 0;
  if (ct = 0)
    {
      apath := WS.WS.HREF_TO_ARRAY (path, '');
      rc := WS.WS.FINDRES (apath, col, name);
    }
  else
    {
      rc := 1;
    }

  if (rc < 0 and 0 <> file_stat (http_root () || path))
    {
      content := file_to_string (http_root () || path);
      ct := 1;
      rc := 1;
    }

  if (isarray (rc))
    signal ('37000', sprintf ('The included resource "%s" is a special "%s" resource, not a plain DAV one', path, rc[0]), 'DA010');
  if (rc < 0)
    signal ('37000', sprintf ('The included resource "%s" does not exist', path), 'DA009');
  else
    {
      if (ct = 0)
	{
	  declare exit handler for not found
	    {
	      signal ('22023', sprintf ('The included resource "%s" does not exist', path), 'DA009');
	    };
	  select blob_to_string (RES_CONTENT), RES_OWNER, RES_GROUP, RES_PERMS, RES_MOD_TIME
	      into curr_file, _u_id, _grp, _perms, modt from WS.WS.SYS_DAV_RES
	      where RES_NAME = name and RES_COL = col;
	  if (not http_map_get ('executable'))
	    {
	      if (_u_id <> http_dav_uid () or _perms like '____1%' or _perms like '_______1%')
		signal ('37000', 'Includes can be owned only by admin & cannot be writable for others', 'DA001');
	    }
	  if (st is not null and isarray (st))
	    st := vector_concat (st, vector (path, datestring(modt)));
	}
      else
	curr_file := content;
   }

  include_inx := strcasestr (curr_file, '<?include');
  while (include_inx is not null)
    {
      if (level > 20)
	signal ( '37000', sprintf ('Max nesting level (20) reached when processing %s', path), 'DA002');
      end_tag_inx := strstr (subseq (curr_file, include_inx, length (curr_file)), '?>');
      if (end_tag_inx is null)
	signal ( '37000', sprintf ('Unterminated include tag at offset %d in %s', include_inx, path), 'DA003');
      end_tag_inx := end_tag_inx + include_inx;
      if (end_tag_inx - include_inx - 9 <= 0)
	signal ( '37000',
	  sprintf ('An include tag at offset %d with no name or VSP end tag before an include tag in %s ',
	    include_inx, path), 'DA004');
      if (include_inx > 0)
	http (subseq (curr_file, 0, include_inx), stream);
      new_file_name := trim (subseq (curr_file, include_inx + 9, end_tag_inx));
      if (aref (new_file_name, 0) <> ascii( '/'))
	{
	  --new_file_name := concat (subseq (path, 0, strrchr(path, '/') + 1), new_file_name);
	  new_file_name :=  WS.WS.EXPAND_URL (path, new_file_name);
	}
      WS.WS.EXPAND_INCLUDES (new_file_name, stream, level + 1, 0, '', st);
      if (end_tag_inx + 2 <= length (curr_file))
        curr_file := subseq (curr_file, end_tag_inx + 2, length (curr_file));
        include_inx := strcasestr (curr_file, '<?include');
    }
  if (length (curr_file) > 0)
    http (curr_file, stream);
}
;

create trigger SYS_DAV_RES_FULL_PATH_D after delete on WS.WS.SYS_DAV_RES
{
  set triggers off;
  -- dbg_obj_princ ('trigger SYS_DAV_RES_FULL_PATH_D (', RES_ID, ')');
  DAV_SPACE_QUOTA_RES_DELETE (RES_FULL_PATH, DAV_RES_LENGTH (RES_CONTENT, RES_SIZE));
  -- dbg_obj_princ ('trigger SYS_DAV_RES_FULL_PATH_D has updated total quota use.');
  -- DAV_DEBUG_CHECK_SPACE_QUOTAS ();
  WS.WS.DAV_VSP_DEF_REMOVE (RES_FULL_PATH);
  if (RES_TYPE = 'xml/persistent-view')
    delete from DB.DBA.SYS_SCHEDULED_EVENT where SE_NAME = RES_FULL_PATH;
-- REPLICATION
  declare pub varchar;
  pub := WS.WS.ISPUBL (RES_FULL_PATH);
  if (isstring (pub))
    {
      -- dbg_obj_princ ('RES DEL: ', pub, ' -> ' , RES_FULL_PATH);
      repl_text (pub, '"DB.DBA.DAV_RES_D" (?)', RES_FULL_PATH);
    }
-- END REPLICATION
  -- delete all associated url entries
  update WS.WS.VFS_URL set VU_ETAG = '' where VU_RES_ID = RES_ID;
  if (RES_TYPE = 'text/xsl')
    xslt_stale (concat ('virt://WS.WS.SYS_DAV_RES.RES_FULL_PATH.RES_CONTENT:', RES_FULL_PATH));
  -- Properties of resource lives as it
  delete from WS.WS.SYS_DAV_PROP where PROP_TYPE = 'R' and PROP_PARENT_ID = RES_ID;
  delete from WS.WS.SYS_DAV_LOCK where LOCK_PARENT_TYPE = 'R' and LOCK_PARENT_ID = RES_ID;
  delete from WS.WS.SYS_DAV_TAG where DT_RES_ID = RES_ID;
  -- dbg_obj_princ ('trigger SYS_DAV_RES_FULL_PATH_D (', RES_ID, ') done');
}
;

create trigger SYS_DAV_COL_D before delete on WS.WS.SYS_DAV_COL order 100
{
  declare pub, col_path varchar;
  col_path := WS.WS.COL_PATH (COL_ID);
  -- dbg_obj_princ ('trigger SYS_DAV_COL_D (', COL_ID, ')');
  delete from WS.WS.SYS_DAV_CATFILTER_DETS where CFD_DET_SUBCOL_ID = COL_ID;
-- REPLICATION
  pub := WS.WS.ISPUBL (col_path);
  if (isstring (pub))
    {
      -- dbg_obj_princ ('COLL DEL: ', pub, ' -> ' ,col_path);
      repl_text (pub, '"DB.DBA.DAV_COL_D" (?, 0)', col_path);
    }
  -- Properties of collection lives as it
  delete from WS.WS.SYS_DAV_PROP where PROP_TYPE = 'C' and PROP_PARENT_ID = COL_ID;
  delete from WS.WS.SYS_DAV_LOCK where LOCK_PARENT_TYPE = 'C' and LOCK_PARENT_ID = COL_ID;
  -- dbg_obj_princ ('trigger SYS_DAV_COL_D (', COL_ID, ') done');
}
;
-- END REPLICATION

-- IvAn/XmlView/000810 procedure WS.WS.XML_VIEW_HEADER added
create procedure WS.WS.XML_VIEW_HEADER
  (
    in view_name varchar,		-- Name of view, as in 'create xml view "\(*\)"'
    in top_tag varchar,			-- Top-level tag of output
    in path varchar,			-- Path to DAV resource, as in 'localhost\(/DAV*\)"'
    in meta_mode integer,		-- Mode of metadata creation, as in call of xml_view_publish
    in meta_data varchar,		-- User metadata, as in call of xml_view_publish
    inout http_body any			-- output_stream to imprint header into
  )
{
  if (meta_mode = 0)
    {
      http (sprintf ('<?xml version="1.0" encoding="%s" ?>\n', current_charset()), http_body);
      http (concat ('<',top_tag,'>\n'), http_body);
      return;
    }
  if (meta_mode = 1)
    {
      http (sprintf ('<?xml version="1.0" encoding="%s" ?>\n', current_charset()), http_body);
      http (concat ('<!DOCTYPE ', top_tag, ' [\n'), http_body);
      http (xml_view_dtd (view_name, top_tag), http_body);
      http (concat (meta_data, '] >\n'), http_body);
      http (concat ('<',top_tag,'>\n'), http_body);
      return;
    }
  if (meta_mode = 2)
    {
      http (sprintf ('<?xml version="1.0" encoding="%s" ?>\n', current_charset()), http_body);
      http (concat ('<!DOCTYPE ', top_tag, ' SYSTEM "', path, '.dtd">'), http_body);
      http (concat ('<',top_tag,'>\n'), http_body);
      return;
    }
  if (meta_mode = 3)
    {
      http (sprintf ('<?xml version="1.0" encoding="%s"  ?>\n', current_charset()), http_body);
      http (concat ('<!DOCTYPE ', top_tag, ' ', meta_data, '>'), http_body);
      http (concat ('<',top_tag,'>\n'), http_body);
      return;
    }
  if (meta_mode = 4)
    {
      signal ('22023', 'Unsupported type of metadata', 'DA005');
      http (sprintf ('<?xml version="1.0"  encoding="%s" ?>\n', current_charset()), http_body);
      http (concat ('<',top_tag,' xmlns="', path, '.xsd" ',meta_data, '>\n'), http_body);
      return;
    }
  if (meta_mode = 5)
    {
      http (sprintf ('<?xml version="1.0" encoding="%s" ?>\n', current_charset()), http_body);
      http (concat ('<',top_tag,' xmlns="', path, '.xsd" ', meta_data, '>\n'), http_body);
      return;
    }
  if (meta_mode = 6)
    {
      http (sprintf ('<?xml version="1.0" encoding="%s" ?>\n', current_charset()), http_body);
      http (concat ('<',top_tag ,' ' , meta_data, '>\n'), http_body);
      return;
    }
  signal ('22023', 'Unsupported type of metadata', 'DA006');
}
;

-- IvAn/XmlView/000810 procedure WS.WS.XML_VIEW_EXTERNAL_META added
create procedure WS.WS.XML_VIEW_EXTERNAL_META
  (
    in view_name varchar,		-- Name of view, as in 'create xml view "\(*\)"'
    in top_tag varchar,			-- Top-level tag of output
    in meta_mode integer,		-- Mode of metadata creation, as in call of xml_view_publish
    in meta_data varchar,		-- User metadata, as in call of xml_view_publish
    inout http_body any,		-- Output_stream to imprint metadata into
    inout meta_path_suffix varchar,	-- Suffix of the meta file, none or '.dtd' or '.xsd'
    inout mime_type varchar		-- MIME type of the meta file
  )
{
  if (meta_mode = 2)
    {
      http (xml_view_dtd (view_name, top_tag), http_body);
      http (meta_data, http_body);
      meta_path_suffix := '.dtd';
      mime_type := 'xml/dtd';
      return;
    }
  if (meta_mode = 5)
    {
      http (xml_view_schema (view_name, top_tag), http_body);
      meta_path_suffix := '.xsd';
      mime_type := 'xml/schema';
      return;
    }
  meta_path_suffix := '';
  mime_type := '';
}
;

create procedure WS.WS.XML_VIEW_UPDATE (in _view varchar, in _res_id integer, in path varchar, in meta_mode integer, in meta_data varchar)
{
    declare _body any;
    declare _pf varchar;
    declare _procprefix varchar;		-- Schema and user of the proc delimited by '.' with trailing '.'
    _procprefix := concat (name_part (_view, 0), '.', name_part (_view, 1), '.');
    _body := string_output ();
    WS.WS.XML_VIEW_HEADER(_view, name_part (_view, 2), path, meta_mode, meta_data, _body);
    _pf := concat (_procprefix, 'http_view_', name_part (_view, 2));
    call (_pf) (_body);
    http (concat ('</', name_part (_view, 2), '>'), _body);
    _body := string_output_string (_body);
    update WS.WS.SYS_DAV_RES set RES_CONTENT = _body, RES_MOD_TIME = now () where RES_ID = _res_id;
}
;

create procedure WS.WS.FIXPATH (in path any)
{
  declare inx, len, cp, sl integer;
  declare tmp, newp varchar;
  declare ret any;
  len := length (path);
  if (__tag (path) = 193)
    {
      inx := 0;
      tmp := '';
      cp := aref (path, len - 1);
      while (inx < length (cp))
	{
	  if (aref (cp, inx) > 159 and aref (cp, inx) < 192)
	    tmp := concat (tmp, '_');
	  else if (aref (cp, inx) = ascii ('?'))
	    tmp := concat (tmp, '_');
	  else
	    tmp := concat (tmp, chr (aref (cp, inx)));
          inx := inx + 1;
	}
      ret := path;
      aset (ret, len - 1, tmp);
    }
  else if (isstring (path))
    {
      inx := 0;
      tmp := '';
      cp := path;
      if (strstr (cp, 'http://') = 0)
	{
	  declare pp, lp varchar;
          pp := coalesce (http_map_get ('mounted'), '/DAV/');
          lp := coalesce (http_map_get ('domain'), '/DAV');
          newp := subseq (cp, strstr (cp, '://') + 3, length (cp));
          sl := strchr (newp, '/');
          newp := subseq (newp, strchr (newp, '/'), length (newp));

--	  if (dav_root () <> '')
--	    newp := concat ('/DAV', subseq (newp, strchr (subseq (newp, 1,length (newp)), '/') + 1,
--		  length (newp)));
--	  else
--	    newp := concat ('/DAV',newp);

          if (strstr (newp, lp) is not null)
	    {
              newp := substring (newp, length (lp) + 1, length (newp));

              if (aref (newp, 0) <> ascii ('/'))
		newp := concat ('/', newp);

              if (aref (pp, length (pp) - 1) = ascii ('/'))
                pp := substring (pp, 1, length (pp) - 1);
              newp := concat (pp, newp);
	    }
	  else
	    {
	       newp := concat ('/DAV', subseq (newp, strchr (subseq (newp, 1,length (newp)), '/') + 1,
		  length (newp)));
	    }
          cp := concat (subseq (cp, 0, sl + 7), newp);
	}
      while (inx < length (cp))
	{
	  if (aref (cp, inx) > 159 and aref (cp, inx) < 192)
	    tmp := concat (tmp, '_');
	  else if (aref (cp, inx) = ascii ('?'))
	    tmp := concat (tmp, '_');
	  else
	    tmp := concat (tmp, chr (aref (cp, inx)));
          inx := inx + 1;
	}
      ret := tmp;
    }
  else
   ret := '';
  return ret;
}
;

-- REPLICATION
create procedure WS.WS.ISPUBL (in __path varchar)
{
  declare _srv, _path varchar;
  declare _ix, _len integer;
  _srv := repl_this_server ();
  if (__tag (__path) = 193)
    {
      _ix := 0;
      _len := length (__path);
      _path := '/';
      while (_ix < _len)
	{
          _path := concat ( _path, aref (__path, _ix), '/');
          _ix := _ix + 1;
	}
    }
  else if (isstring (__path))
    _path := __path;
  else
    {
      signal ('22023', 'Function ISPUBL needs string or array as argument.', 'DA007');
      return NULL;
    }
  for select TI_ITEM, TI_ACCT from DB.DBA.SYS_TP_ITEM where TI_SERVER = _srv and TI_TYPE = 1 do
    {
      if (TI_ITEM is not null and length (TI_ITEM) > 0)
	{
	  if (aref (TI_ITEM, length (TI_ITEM) - 1) <> ascii ('/'))
	    {
	      if (_path between (TI_ITEM || '/') and DAV_COL_PATH_BOUNDARY (TI_ITEM || '/'))
		return TI_ACCT;
	    }
	  else
	    {
	      if (_path between TI_ITEM and DAV_COL_PATH_BOUNDARY (TI_ITEM))
		return TI_ACCT;
	    }
	}
    }
  return NULL;
}
;

create procedure WS.WS.BODY_ARR (inout __ses any, in __pcs integer)
{
  declare _res, _ses any;
  declare _str varchar;
  declare _len, _from, _pcs integer;

  if (__pcs is null)
   _pcs := 1000000;
  else
   _pcs := __pcs;

  _res := null;
  _from := 1;

  if (__tag (__ses) = 126 or __tag (__ses) = 133)
    {
      _ses := string_output ();
      http (__ses, _ses);
      _len := length (_ses);
      while (_from < _len)
	{
	  _str := substring (_ses, _from, _pcs);
	  if (_res is null)
	    _res := vector (_str);
	  else
	    _res := vector_concat (_res, vector (_str));
	  _from := _from + _pcs;
	}
    }
  else if (isstring (__ses) or __tag (__ses) = 185)
    {
      _len := length (__ses);
      while (_from < _len)
	{
	  _str := substring (__ses, _from, _pcs);
	  if (_res is null)
	    _res := vector (_str);
	  else
	    _res := vector_concat (_res, vector (_str));
	  _from := _from + _pcs;
	}
    }
  else
    {
      _ses := '';
    }

  return _res;
}
;
-- END REPLICATION


-- SQL/XML update procedure

create procedure WS.WS.XML_AUTO_SCHED (in _path varchar)
{
  declare _stmt, ses, _root, _sch, _dtd, _dtd_body, _comments varchar;
  declare _res_id integer;
  _res_id := coalesce ((select RES_ID from WS.WS.SYS_DAV_RES where RES_FULL_PATH = _path), 0);
  if (_res_id < 1)
    return;
  _stmt := coalesce ((select blob_to_string (PROP_VALUE) from WS.WS.SYS_DAV_PROP where PROP_NAME = 'xml-sql'
	       and PROP_TYPE = 'R'
	       and PROP_PARENT_ID = _res_id), '');
  _root := coalesce ((select blob_to_string (PROP_VALUE) from WS.WS.SYS_DAV_PROP where PROP_NAME = 'xml-sql-root'
	       and PROP_TYPE = 'R'
	       and PROP_PARENT_ID = _res_id), 'document');
  _sch := coalesce ((select blob_to_string (PROP_VALUE) from WS.WS.SYS_DAV_PROP where PROP_NAME = 'xml-sql-schema'
	       and PROP_TYPE = 'R'
	       and PROP_PARENT_ID = _res_id), '');
  _dtd := coalesce ((select blob_to_string (PROP_VALUE) from WS.WS.SYS_DAV_PROP where PROP_NAME = 'xml-sql-dtd'
	       and PROP_TYPE = 'R'
	       and PROP_PARENT_ID = _res_id), '');
  _comments := coalesce ((select blob_to_string (PROP_VALUE) from WS.WS.SYS_DAV_PROP where
				   PROP_NAME = 'xml-sql-description'
				   and PROP_TYPE = 'R'
				   and PROP_PARENT_ID = _res_id), '');
  if (_stmt = '')
    return;
  ses := string_output (http_strses_memory_size ());
  WS.WS.XMLSQL_TO_STRSES (_stmt, _root, _sch, _dtd, _comments, ses);
  update WS.WS.SYS_DAV_RES set RES_CONTENT = ses, RES_MOD_TIME = now () where RES_ID = _res_id;
}
;


create procedure WS.WS.DAV_LOGIN (in path any,
                                  in lines any,
				  in __access varchar,
				  inout __u_id integer,
				  inout __grp integer,
				  inout __perms varchar)
{
  declare auth any;
  declare _access, _perms varchar;
  declare _u_id, _grp integer;

  _u_id := http_nobody_uid ();
  _grp := http_nogroup_gid ();
  _perms := '110110110';

  if (upper (__access) = 'R')
    _access := '100';
  else if ( upper (__access) = 'RW')
    _access := '110';
  else
    _access := '100';

  auth := DB.DBA.vsp_auth_vec (lines);

  if (not WS.WS.ISPUBLIC (path, _access) or auth <> 0)
    {
      _u_id := WS.WS.CHECK_AUTH (lines);
      if (_u_id = http_nobody_uid ())
	return _u_id;
      if (not WS.WS.CHECKPERM (path, _u_id, _access))
	return 0;
    }

  if (_u_id <> 0)
    select U_DEF_PERMS, U_GROUP into _perms, _grp from WS.WS.SYS_DAV_USER where U_ID = _u_id;

  if (__u_id is not null)
    __u_id := _u_id;
  if (__grp is not null)
    __grp := _grp;
  if (__u_id is not null)
    __perms := _perms;

  return (1);
}
;

create procedure WS.WS.HTTP_RESP (in hdr any, out descr varchar)
{
  declare line, code varchar;
  descr := 'Bad Gateway';
  if (hdr is null or __tag (hdr) <> 193)
    return (502);
  if (length (hdr) < 1)
    return (502);
  line := aref (hdr, 0);
  if (length (line) < 12)
    return (502);
  code := substring (line, strstr (line, 'HTTP/1.') + 9, length (line));
  while ((length (code) > 0) and (aref (code, 0) < ascii ('0') or aref (code, 0) > ascii ('9')))
    code := substring (code, 2, length (code) - 1);
  if (length (code) < 3)
    return (502);
  if (length (code) > 3)
    {
      descr := substring (code, 4, length (code) - 3);
      descr := replace (descr, chr(10), '');
      descr := replace (descr, chr(13), '');
    }
  code := substring (code, 1, 3);
  return atoi (code);
}
;


create procedure WS.WS.COPY_TO_OTHER (in path varchar,
                                      inout params varchar,
				      in lines varchar,
				      in __dst_name varchar)
{
  declare _s_path, _ovr, _depth varchar;
  declare _resp any;
  declare _content, _thdr, _thost, _auth, _resp_cli, _dst_name varchar;
  declare _len, _sl, _code  integer;
  declare _u_id, _grp, _perms any;

  _dst_name := WS.WS.FINDPARAM (lines, 'Destination:');
  WS.WS.DAV_LOGIN (path, lines, 'R', _u_id, _grp, _perms);

  _s_path := http_path ();
  _ovr := WS.WS.FINDPARAM (lines, 'Overwrite:');
  if (_ovr = '')
    _ovr := 'T';
  _depth := WS.WS.FINDPARAM (lines, 'Depth:');
  if (_depth = '')
    _depth := 'infinity';
  _auth := WS.WS.FINDPARAM (lines, 'Authorization:');

  _thost := substring (_dst_name, 8, length (_dst_name) - 8);
  _sl := strchr (_thost, '/');
  if (_sl)
    _thost := substring (_thost, 1, _sl);

  if (_auth <> '')
     _thdr := concat ('Host: ', _thost, '\r\n',
	 'Overwrite: ', _ovr, '\r\n',
	 'Authorization: ', _auth, '\r\n',
	 'Depth: ', _depth);
  else
     _thdr := concat ('Host: ', _thost, '\r\n',
	 'Overwrite: ', _ovr, '\r\n',
	 'Depth: ', _depth);

  if (WS.WS.ISRES (path))
    {
      -- copy single resource
      select blob_to_string (RES_CONTENT), DAV_RES_LENGTH (RES_CONTENT, RES_SIZE)
        into _content, _len from WS.WS.SYS_DAV_RES where RES_FULL_PATH = _s_path;
      commit work;
      http_get (_dst_name, _resp, 'PUT', _thdr, _content);
      _code := WS.WS.HTTP_RESP (_resp, _resp_cli);
      http_request_status (sprintf ('HTTP/1.1 %d %s', _code, _resp_cli));
      -- dbg_obj_princ (_code, _resp_cli);
      if (_code > 199 and _code < 299)
        return 1;
      else
        return 0;
    }
  else if (WS.WS.ISCOL (path))
    {
      -- copy collections TODO check for Depth header this version always override destination
      commit work;
      http_get (_dst_name, _resp, 'HEAD', _thdr);
      _code := WS.WS.HTTP_RESP (_resp, _resp_cli);
      if (_code <> 200)
	{
	  commit work;
          http_get (_dst_name, _resp, 'MKCOL', _thdr);
          _code := WS.WS.HTTP_RESP (_resp, _resp_cli);
          if (_code < 200 or _code > 299)
	    {
              http_request_status (sprintf ('HTTP/1.1 %d %s', _code, _resp_cli));
	      return 0;
	    }
	}
      for select SUBCOL_FULL_PATH
         from DAV_PLAIN_SUBCOLS
         where root_id = NULL and root_path = concat (_s_path, '/') and recursive = 1 and subcol_auth_uid = null and subcol_auth_pwd = null
	 order by SUBCOL_ID
	   do
         {
	   commit work;
           http_get (concat ('http://', _thost, SUBCOL_FULL_PATH), _resp, 'HEAD', _thdr);
           _code := WS.WS.HTTP_RESP (_resp, _resp_cli);
 	   if (_code <> 200)
	     {
               http_get (concat ('http://', _thost, SUBCOL_FULL_PATH), _resp, 'MKCOL', _thdr);
	       _code := WS.WS.HTTP_RESP (_resp, _resp_cli);
	       if (_code < 200 or _code > 299)
	 	 {
		   http_request_status (sprintf ('HTTP/1.1 %d %s', _code, _resp_cli));
		   return 0;
		 }
	     }
	   -- dbg_obj_princ (_resp, SUBCOL_FULL_PATH);
         }
      for select RES_FULL_PATH as res_path, blob_to_string (RES_CONTENT) as content
	                       from WS.WS.SYS_DAV_RES
			       where RES_FULL_PATH like concat (_s_path, '/%')
			       order by RES_ID
			       do
         {
	   commit work;
           http_get (concat ('http://', _thost, res_path), _resp, 'PUT', _thdr, content);
	   _code := WS.WS.HTTP_RESP (_resp, _resp_cli);
	   if (_code < 200 or _code > 299)
	     {
	       http_request_status (sprintf ('HTTP/1.1 %d %s', _code, _resp_cli));
	       return 0;
	     }
	   -- dbg_obj_princ (_resp, res_path);
         }
    }
  else
    {
      DB.DBA.DAV_SET_HTTP_STATUS (404);
      return 0;
    }
  return 1;
}
;

create procedure WS.WS.CHECK_READ_ACCESS (in _u_id integer, in doc_id integer)
{
  declare _perms varchar;
  declare g_id, _user, _group, rc integer;
  if (_u_id = http_dav_uid ())
    return 1;
  rc := 0;
  g_id := coalesce ((select U_GROUP from WS.WS.SYS_DAV_USER where U_ID = _u_id), 0);
  whenever not found goto exit_p;
  select RES_OWNER, RES_GROUP, RES_PERMS into _user, _group, _perms
	  from WS.WS.SYS_DAV_RES where RES_ID = doc_id;
  _perms := coalesce (_perms, '000000000');
  if (_u_id = _user)
    rc := WS.WS.PERM_COMP (substring (cast (_perms as varchar), 1, 3), '100');
  if (_group = g_id and rc = 0)
    rc := WS.WS.PERM_COMP (substring (cast (_perms as varchar), 4, 3), '100');
  if (rc = 0)
    rc := WS.WS.PERM_COMP (substring (cast (_perms as varchar), 7, 3), '100');
exit_p:;
  return rc;
}
;

create procedure WS.WS.IS_REDIRECT_REF (inout path any, in lines any, inout location varchar)
{
  declare fpath, fpath1, _ref, lpath, ppath varchar;
  declare rc integer;
  rc := 0;
  set isolation='committed';
  location := http_path ();
  declare cr cursor for select blob_to_string (PROP_VALUE) from WS.WS.SYS_DAV_RES, WS.WS.SYS_DAV_PROP where
      RES_FULL_PATH = fpath1
      and PROP_PARENT_ID = RES_ID and
      PROP_NAME = 'redirectref' and PROP_TYPE = 'R' option (order);
  fpath := http_physical_path (); fpath1 := rtrim (fpath, '/');
  whenever not found goto nfp;
  open cr (prefetch 1);
  fetch cr into _ref;
  if (not isstring (_ref))
    goto nfp;
  lpath := http_path ();
  location := WS.WS.EXPAND_URL (lpath, _ref);
  ppath := WS.WS.EXPAND_URL (fpath, _ref);
  path := WS.WS.HREF_TO_ARRAY (ppath, '');
  rc := 1;
nfp:
  close cr;
  set isolation='repeatable';
  return rc;
}
;

create function WS.WS.DAV_DIR_LIST (in full_path varchar, in logical_root_path varchar, in col integer, in auth_uname varchar, in auth_pwd varchar, in auth_uid integer) returns integer
{
  -- dbg_obj_princ ('WS.WS.DAV_DIR_LIST (', full_path, logical_root_path, col, auth_uname, auth_pwd, auth_uid, ')');
  declare _dir, _xml, _modify, fsize, _html, _b_opt, _xml_sheet any;
  declare _name, xslt_file, xslt_folder, vspx_path varchar;
  declare _res_len, flen, mult, N integer;
  declare _dir_len, _dir_ctr integer;
  declare _user_name, _group_name varchar;
  declare _user_id, _group_id integer;

  if (registry_get ('__WebDAV_vspx__') = 'yes')
  {
    declare path, action, params, lines any;
    vspx_path := '/DAV/VAD/conductor/folder.vspx';
    path := http_path ();
    lines := http_request_header ();
    params := http_param ();
    params := vector_concat (params, vector ('dir', full_path));

    action := get_keyword ('a', params, '');
    if (action in ('new', 'upload', 'create', 'link', 'update', 'edit'))
      params := vector_concat (params, vector ('a', action));

    if (not isnull (auth_uname))
    {
      connection_set ('vspx_user', auth_uname);
    } else {
      connection_set ('vspx_user', (select U_NAME from DB.DBA.SYS_USERS where U_ID = auth_uid));
    }

    DB.DBA.vspx_dispatch (vspx_path, path, params, lines);
    return;
  }
  fsize := vector ('B','K','M','G','T');
  _xml := string_output ();
  xslt_file := null;
  _dir := DAV_DIR_LIST_INT (full_path, 0, '%', auth_uname, auth_pwd, auth_uid);
  if (isinteger (_dir))
    return _dir;

  _dir_len := length (_dir);
  http ('<?xml version="1.0" encoding="UTF-8" ?>', _xml);
  http (sprintf ('<PATH dir_name="%V" physical_dir_name="%V">', cast (logical_root_path as varchar), cast (full_path as varchar)), _xml);
  http ('<DIRS>', _xml);

  http ('<SUBDIR modify="" name=".." />\n', _xml);
  _user_id := -1;
  _group_id := -1;
  _user_name := '';
  _group_name := '';
  _dir_ctr := 0;
  while (_dir_ctr < _dir_len)
  {
    declare _col any;
    _col := _dir [_dir_ctr];
    if (_col [1] = 'C')
    {
      _name := rtrim (_col[0], '/');
      _name := subseq (_name, strrchr (_name, '/') + 1);
      if (_user_id <> coalesce (_col[7], -1))
      {
        _user_id := coalesce (_col[7], -1);
        _user_name := coalesce ((select U_NAME from DB.DBA.SYS_USERS where U_ID = _user_id), '');
      }
      if (_group_id <> coalesce (_col[6], -1))
      {
        _group_id := coalesce (_col[6], -1);
        _group_name := coalesce ((select U_NAME from DB.DBA.SYS_USERS where U_ID = _group_id), '');
      }
	    http (sprintf ('<SUBDIR modify="%s" owner="%s" group="%s" permissions="%s" name="', left (cast (_col[3] as varchar), 19), _user_name, _group_name, DB.DBA.DAV_PERM_D2U (_col[5]), _col[9]), _xml );
	    http_value (_name, null, _xml );
	    http ('" />\n', _xml );
	  }
    _dir_ctr := _dir_ctr + 1;
  }
  http ('</DIRS><FILES>', _xml);

  _user_id := -1;
  _group_id := -1;
  _user_name := '';
  _group_name := '';
  _dir_ctr := 0;
  while (_dir_ctr < _dir_len)
  {
    declare _res any;
    _res := _dir [_dir_ctr];
    if (_res [1] = 'R')
    {
      _name := _res[0];
      _name := subseq (_name, strrchr (_name, '/') + 1);
      if (lower (_name) = '.folder.xsl')
        xslt_file := cast (full_path as varchar) || _name;

	    _res_len := _res[2];
	    flen := _res_len;
	    mult := 0;
      while ((flen / 1024) > 1)
	    {
	      mult := mult + 1;
	      flen := flen / 1024;
	    }
      if (_user_id <> coalesce (_res[7], -1))
      {
        _user_id := coalesce (_res[7], -1);
        _user_name := coalesce ((select U_NAME from DB.DBA.SYS_USERS where U_ID = _user_id), '');
      }
      if (_group_id <> coalesce (_res[6], -1))
      {
        _group_id := coalesce (_res[6], -1);
        _group_name := coalesce ((select U_NAME from DB.DBA.SYS_USERS where U_ID = _group_id), '');
      }
      http (sprintf ('<FILE modify="%s" owner="%s" group="%s" permissions="%s" mimeType="%s" rs="%i" lenght="%d" hs="%d %s" name="', left (cast (_res[3] as varchar), 19), _user_name, _group_name, DB.DBA.DAV_PERM_D2U (_res[5]), _res[9], _res_len, _res[2], flen, aref (fsize, mult)), _xml);
	    http_value (_name, null, _xml );
	    http ('" />\n', _xml );
	  }
    _dir_ctr := _dir_ctr + 1;
  }
  http ('</FILES></PATH>', _xml);
  _xml := xtree_doc (_xml);

  if (isnull (xslt_file))
  {
    xslt_folder := full_path;
    while (xslt_folder <> '')
    {
      xslt_folder := rtrim (xslt_folder, '/');
      N := strrchr (xslt_folder, '/');
      if (not isnull (N))
      {
        xslt_folder := subseq (xslt_folder, 0, N+1);
        if (exists (select 1 from WS.WS.SYS_DAV_RES where RES_FULL_PATH = xslt_folder || '.folder.xsl'))
        {
          xslt_file := xslt_folder || '.folder.xsl';
          goto _exit;
        }
      }
    }
  _exit:;
  }
	http_header ('Content-type: text/html; charset="UTF-8"\r\n');
  if (not isnull (xslt_file))
  {
    select blob_to_string (RES_CONTENT) into _xml_sheet from WS.WS.SYS_DAV_RES where RES_FULL_PATH = xslt_file;
    xslt_sheet ('http://local.virt/custom_dir_output', xtree_doc (_xml_sheet));
    _html := xslt ('http://local.virt/custom_dir_output', _xml);
    http_value (_html);
  }
  else
  {
    _b_opt := null;
    if (exists (select 1 from DB.DBA.HTTP_PATH where HP_LPATH = http_map_get ('domain') and HP_PPATH = http_map_get ('mounted')))
    {
      select deserialize(HP_OPTIONS) into _b_opt
        from DB.DBA.HTTP_PATH
       where HP_LPATH = http_map_get ('domain') and HP_PPATH = http_map_get ('mounted');

      if (_b_opt is not NULL)
        _b_opt := get_keyword ('browse_sheet', _b_opt, '');
    }
    if (_b_opt <> '')
    {
      select blob_to_string (RES_CONTENT) into _xml_sheet from WS.WS.SYS_DAV_RES where RES_FULL_PATH = _b_opt;
      xslt_sheet ('http://local.virt/custom_dir_output', xml_tree_doc (_xml_sheet));
      _html := cast (xslt ('http://local.virt/custom_dir_output', _xml) as varchar);
    }
    else
    {
      _html := cast (xslt ('http://local.virt/dir_output', _xml) as varchar);
    }
    http (_html);
  }
  return 0;
}
;

--create procedure
--WS.WS.DAV_CHECK_QUOTA ()
--{
--  declare tot, quota, _uid, globalf int;
--  globalf := virtuoso_ini_item_value ('HTTPServer', 'DAVQuotaEnabled');
--  if (globalf is null or 0 = atoi (globalf))
--    return 1;
--  quota := connection_get ('DAVQuota');
--  _uid := connection_get ('DAVUserID');
--  if (quota = -1 or quota is null or _uid = http_dav_uid ())
--    return 1;
--  select sum (length (RES_CONTENT)) into tot from WS.WS.SYS_DAV_RES where RES_OWNER = _uid;
--  if (tot <= quota)
--    return 1;
--  -- dbg_obj_princ ('total:', tot, ' quota: ', quota, ' uid: ', _uid);
--  return 0;
--}
--;


create function
WS.WS.DAV_CHECK_ASMX (in path any, out patched_path any) returns integer
{
  declare temp varchar;
  temp := http_path (path);

  if ((strstr (temp, '.asmx') is not null) and __proc_exists ('WS.WS.__http_handler_aspx', 1))
   {
      declare ret any;
      declare idx integer;
      idx := 0;
      ret := vector ();
      while (idx < length (path))
	{
	   ret := vector_concat (ret, vector (path[idx]));
	   if (strstr (path[idx], '.asmx') is not null)
	     {
	       patched_path := ret;
	       return 1;
	     }
	   idx := idx + 1;
	}
   }
  patched_path := path;
  return 0;
}
;


create procedure
WS.WS.DAV_REMOVE_ASMX (in path any)
{
  if ((strstr (path, '.asmx') is not null) and __proc_exists ('WS.WS.__http_handler_aspx', 1))
   {
      declare ret any;
      ret := "LEFT" (path, strstr (path, '.asmx') + 5);
      return ret;
   }
  else
    return path;
}
;


create procedure WS.WS.XMLSQL_TO_STRSES (
  in _q varchar,
  in _root varchar,
  in _sch varchar,
  in _dtd varchar,
  in _comments varchar,
  inout ses any,
  in enc varchar := null )
{

  if (length (_sch))
    _dtd := '';

  -- XML Prologue
  http (sprintf ('<?xml version="1.0" encoding="%s" ?>\n', coalesce (enc, current_charset())), ses);
  -- Resource Description
  if (_comments <> '')
    http (replace (sprintf ('<!\-\- %s \-\->\n', _comments), '\-', '-'), ses);

  -- DTD
  if (_dtd <> '' and _root <> '')
    {
      if (_dtd = 'on')
        http (concat ('<!DOCTYPE ' , _root, ' [', xml_auto_dtd (_q, _root), ']>\n'), ses);
      else
        http (concat ('<!DOCTYPE ' , _root, ' SYSTEM ''', _dtd, '''>\n'), ses);
    }

  -- XMLSchema & root element
  if (_root <> '' and _sch = '')
    http (concat ('<', _root, '>\n'), ses);
  else if (_root <> '' and _sch <> '')
    http (concat ('<', _root,
	   ' xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="',
	   _sch, '">\n'), ses);

  -- Query evaluation
  xml_auto (_q, vector (), ses);

  -- closing the root element
  if (_root <> '')
    http (concat('</', _root, '>\n'), ses);

  return;
}
;

create procedure WS.WS."TRACE" (in path varchar, inout params varchar, in lines varchar)
{
  http_header ('Content-Type: message/http\r\n');
  http_flush (1);
  foreach (varchar l in lines) do
  {
    http (l);
  }
}
;

create procedure DAV_SET_HTTP_REQUEST_STATUS (
  in rc integer)
{
  if (rc = -1)
  {
    http_request_status ('HTTP/1.1 409 Invalid path');
  }
  else if (rc = -2)
  {
    http_request_status ('HTTP/1.1 409 Conflict: the destination (path) is not valid');
  }
  else if (rc = -3)
  {
    http_request_status ('HTTP/1.1 412 Precondition Failed: overwrite flag is not set and destination exists');
  }
  else if (rc = -8)
  {
    http_request_status ('HTTP/1.1 423 Locked');
  }
  else if (rc = -12)
  {
    http_request_status ('HTTP/1.1 403 Forbidden: authentication has failed');
  }
  else if (rc = -13)
  {
    http_request_status ('HTTP/1.1 403 Forbidden: insufficient user permissions');
  }
  else if (rc = -25)
  {
    http_request_status ('HTTP/1.1 409 Conflict: can not create collection if a resource with same name exists');
  }
  else if (rc = -26)
  {
    http_request_status ('HTTP/1.1 409 Conflict: can not create resource if a collection with same name exists');
  }
  else if (rc = -24)
  {
    ;
  }
  else if (rc = -28)
  {
    http_request_status ('HTTP/1.1 599 Internal server error');
  }
  else if (rc = -29)
  {
    http_request_status ('HTTP/1.1 599 Internal server error');
  }
  else if (rc = -41)
  {
    http_request_status ('HTTP/1.1 507 Insufficient storage');
  }
  else
  {
    http_request_status ('HTTP/1.1 405 Method Not Allowed');
  }
  return;
}
;

create procedure DB.DBA.DAV_SET_AUTHENTICATE_HTTP_STATUS (
  in rc integer)
{
  if (rc in (-12, -13))
  {
    DB.DBA.DAV_SET_HTTP_STATUS (403);
  }
  else
  {
    DB.DBA.DAV_SET_HTTP_STATUS (401);
  }
  return;
}
;

create procedure DB.DBA.DAV_SET_HTTP_STATUS (
  in status any,
  in title integer := null,
  in message_head varchar := null,
  in message varchar := null,
  in rewrite integer := 0)
{
  if (rewrite)
    http_rewrite ();

  if (isinteger (status))
  {
    if (status = 204)
    {
      http_request_status ('HTTP/1.1 204 No Content');
    }
    if (status = 400)
    {
       http_request_status ('HTTP/1.1 400 Bad Request');
    }
    else if (status = 401)
    {
      http_request_status ('HTTP/1.1 401 Unauthorized');
      if (isnull (title))
        title := '401 Unauthorized';

      if (isnull (message_head))
        message_head := 'Unauthorized';

      if (isnull (message))
        message := 'Access to page is forbidden';
    }
    else if (status = 403)
    {
      http_request_status ('HTTP/1.1 403 Forbidden');
      if (isnull (title))
        title := '403 Forbidden';

      if (isnull (message_head))
        message_head := 'Forbidden';

      if (isnull (message))
        message := 'Resource is forbidden.';
    }
    else if (status = 404)
    {
   	  http_request_status ('HTTP/1.1 404 Not Found');
      if (isnull (title))
        title := '404 Not Found';

      if (isnull (message_head))
        message_head := sprintf ('Resource %V not found.', http_path ());

      if (isnull (message))
        message := 'Access to page is forbidden';
    }
    else if (status = 405)
    {
      http_request_status ('HTTP/1.1 405 Method Not Allowed');
    }
    else if (status = 409)
    {
      http_request_status ('HTTP/1.1 409 Conflict');
    }
    else if (status = 415)
    {
      http_request_status ('HTTP/1.1 415 Unsupported Media Type');
    }
    else if (status = 423)
    {
      http_request_status ('HTTP/1.1 423 Locked');
    }
    else if (status = 500)
    {
      http_request_status ('HTTP/1.1 500 Internal Server Error');
    }
    else if (status = 501)
    {
      http_request_status ('HTTP/1.1 501 Not Implemented');
    }
  }
  else
  {
    http_request_status (status);
  }

  if (not isnull (title) and not isnull (message_head) and not isnull (message))
  {
    http (sprintf (
      '<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML 2.0//EN">\n' ||
      '<html>\n' ||
      '  <head>\n' ||
      '    <title>%s</title>\n' ||
      '  </head>\n' ||
      '  <body>\n' ||
      '    <h1>%s</h1>\n' ||
      '    %s\n' ||
      '  </body>\n' ||
      '</html>',
      coalesce (title, ''),
      coalesce (message_head, ''),
      coalesce (message, '')
    ));
  }
}
;

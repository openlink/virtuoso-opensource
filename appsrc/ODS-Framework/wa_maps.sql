--
--  $Id$
--
--  Procedures to support the WA maps handling.
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

-- the public API to call for filling up the coordinates.
-- returns the lat and lng.
create function WA_MAPS_ADDR_TO_COORDS (
  in address1 varchar,
  in address2 varchar,
  in city varchar,
  in state varchar,
  in zip_code varchar,
  in country varchar,
  out lat double precision,
  out lng double precision)
returns integer
{
  declare _func varchar;
  _func := registry_get ('WA_MAPS_SERVICE');

  if (is_empty_or_null (_func))
    return 0;

  _func := sprintf ('WA_MAPS_%I_ADDR_TO_COORDS', _func);
  return call (_func) (address1, address2, city, state, zip_code, country, lat, lng);
}
;

-- another public API to call for filling up the users with missing coordinates.
create procedure WA_MAPS_UPDATE_USER_LAT_LNG ()
{
  declare _WAUI_HADDRESS1, _WAUI_HADDRESS2, _WAUI_HCITY, _WAUI_HSTATE, _WAUI_HCODE, _WAUI_HCOUNTRY varchar;
  declare _lat, _lng double precision;

  declare cr cursor for
    select WAUI_HADDRESS1, WAUI_HADDRESS2, WAUI_HCITY, WAUI_HSTATE, WAUI_HCODE, WAUI_HCOUNTRY
     from DB.DBA.WA_USER_INFO
     where WAUI_HADDRESS1 is not null
       and WAUI_HCITY is not null
       and WAUI_HSTATE is not null
       and WAUI_LAT is null
       and WAUI_LNG is null;

  open cr (exclusive, prefetch 1);
  while (1 = 1)
    {
      declare exit handler for not found
        {
          close cr;
          return;
        };

      fetch cr into _WAUI_HADDRESS1, _WAUI_HADDRESS2, _WAUI_HCITY, _WAUI_HSTATE, _WAUI_HCODE, _WAUI_HCOUNTRY;
      if (WA_MAPS_ADDR_TO_COORDS (
            coalesce (_WAUI_HADDRESS1, ''),
            coalesce (_WAUI_HADDRESS2, ''),
            coalesce (_WAUI_HCITY, ''),
            coalesce (_WAUI_HSTATE, ''),
            coalesce ( _WAUI_HCODE, ''),
            coalesce ( _WAUI_HCOUNTRY, ''),
          _lat,
          _lng
          ) <> 0)
        {
	  update DB.DBA.WA_USER_INFO set WAUI_LAT = _lat, WAUI_LNG = _lng where current of cr;
	  close cr;
	  commit work;
	  open cr (exclusive, prefetch 1);
        }
    }
}
;

create function WA_MAPS_YAHOO_ADDR_TO_COORDS (
  in address1 varchar,
  in address2 varchar,
  in city varchar,
  in state varchar,
  in zip_code varchar,
  in country varchar,
  out lat double precision,
  out lng double precision)
returns integer
{
   declare addr, post, res, hdr, xt, tmp1, tmp2 any;

   addr := WA_MAPS_MSN_CONSTRUCT_ADDR (address1, address2, city, case when is_empty_or_null (state) then country else state end, zip_code);
   declare exit handler for sqlstate '*'
   {
      signal (__SQL_STATE, concat ('Address to coordinates YAHOO web service protocol error : ', __SQL_MESSAGE));
   };
   hdr := null;
   res := http_get (sprintf ('http://api.local.yahoo.com/MapsService/V1/geocode?appid=5hugwULV34HbDt2XFYluElmhe4xEe13Jbdh4vCH1t0uHu.nCdL5o8Xm5oyBaK7dnZl8&location=%U', addr), hdr);
   if (res is null)
     return 0;
   xt := xtree_doc (res);
   tmp1 := cast(xpath_eval ('//Latitude/text()', xt) as varchar);
   if (tmp1 is null)
     return 0;
   tmp2 := cast(xpath_eval ('//Longitude/text()', xt) as varchar);
   if (tmp2 is null)
     return 0;
   lat := cast (tmp1 as double precision);
   lng := cast (tmp2 as double precision);
   return 1;
};

-- The MSN free geocoder service iface
create function WA_MAPS_MSN_ADDRS_TO_COORDS (
  in addr any,
  out lat double precision,
  out lng double precision)
returns integer
{
   declare post, res, hdr any;
   declare exit handler for sqlstate '*' {
       signal (__SQL_STATE,
          concat ('Address to coordinates MSN web service protocol error : ', __SQL_MESSAGE));
   };

   post := 'a=&b=' || sprintf ('%U', addr) || '&c=0.0&d=0.0&e=0.0&f=0.0&g=&i=&r=0';

   res := http_get (
--	'http://virtualearth.msn.com/search.ashx',
	'http://dev.virtualearth.net/search.ashx',
--	'http://207.46.159.133/search.ashx',
	hdr,
	'POST',
	'Content-Type: application/x-www-form-urlencoded',
	post);

   if (res is null)
     return 0;

   if (res like '%UpdateAmbiguousList(%')
     return 0;

   res := split_and_decode (res, 0, '\0\0,');

   lat := cast (res[length (res) - 2] as double precision);
   lng := cast (res[length (res) - 1] as double precision);
   if (lat <> 0 and lng <> 0)
     return 1;
   else
     return 0;
}
;

create function WA_MAPS_ZEESOURCE_ADDR_TO_COORDS (
  in address1 varchar,
  in address2 varchar,
  in city varchar,
  in state varchar,
  in zip_code varchar,
  in country varchar,
  out lat double precision,
  out lng double precision)
returns integer
{
  declare action, namespace, enc varchar;
  declare style, form int;
  declare _result, _body, xe, ret any;

  action := '';
  namespace := 'http://maps.zeesource.com';
  form := 0;
  style := 0;
  style := style + (form * 16);

  declare exit handler for sqlstate '*'
  {
    signal (__SQL_STATE, concat ('Address to coordinates Zeesource web service protocol error : ', __SQL_MESSAGE));
   };

  commit work;
  _result := DB.DBA.SOAP_CLIENT (
	        url=>'http://www.zeesource.net/maps/services/Geocode',
		operation=>'getCoordinates',
 		soap_action=>action,
	        target_namespace=>namespace,
 		parameters=>vector
                        (
        		vector('city', 'http://www.w3.org/2001/XMLSchema:string'), city ,
        		vector('state', 'http://www.w3.org/2001/XMLSchema:string'), state ,
        		vector('country', 'http://www.w3.org/2001/XMLSchema:string'), country
			),
 		      headers=>vector(),
		style=>style
	       );
  _body := _result;
  xe := xml_cut (xml_tree_doc (_body));
  lat := 0;
  lng := 0;
  if (xpath_eval ('[ xmlns:SOAP="http://schemas.xmlsoap.org/soap/envelope/" ] //SOAP:Fault', xe, 1) is null)
    {
      ret :=  xpath_eval ('//getCoordinatesReturn[city]', xe, 1);
      if  (ret is not null)
	{
	  ret :=  xml_cut (ret);
	  lat := cast (xpath_eval ('string(latitude)' , ret) as double precision);
	  lng := cast (xpath_eval ('string(longitude)', ret) as double precision);
        }
      if (lat <> 0 and lng <> 0)
        return 1;
    }
  return 0;
}
;


create function WA_MAPS_MSN_CONSTRUCT_ADDR (
  in address1 varchar,
  in address2 varchar,
  in city varchar,
  in state varchar,
  in zip_code varchar)
returns varchar
{
  return
    address1 ||
      case when is_empty_or_null (address1) then '' else ', ' end ||
    address2 ||
      case when is_empty_or_null (address2) then '' else ', ' end ||
    city ||
      case when is_empty_or_null (city) then '' else ',' end ||
    state ||
      case when is_empty_or_null (state) then '' else ', ' end ||
    zip_code;
}
;

-- the entry point to the MSN geocoder service
create function WA_MAPS_MSN_ADDR_TO_COORDS (
  in address1 varchar,
  in address2 varchar,
  in city varchar,
  in state varchar,
  in zip_code varchar,
  in country varchar,
  out lat double precision,
  out lng double precision)
returns integer
{
  return WA_MAPS_MSN_ADDRS_TO_COORDS (WA_MAPS_MSN_CONSTRUCT_ADDR (address1, address2, city, state, zip_code), lat, lng);
}
;
-- END of The MSN free geocoder service iface

registry_set ('WA_MAPS_SERVICE', 'YAHOO')
;



create procedure WA_MAPS_GET_KEY (in svc varchar := 'GOOGLE')
{
  declare host varchar;
  declare rc any;

  host := HTTP_GET_HOST ();
  set isolation='uncommitted';
  declare exit handler for not found
    {
      rc := registry_get ('GOOGLE_MAPS_SITE_KEY');
      goto endp;
    };
  select WMH_KEY into rc from WA_MAP_HOSTS where WMH_HOST = host and WMH_SVC = svc;
  endp:
  set isolation='committed';
  return rc;
}
;


--exec(
wa_exec_no_error_log(
  'CREATE TABLE WA_MAP_DISPLAY
    (
      WMD_INST		integer identity,
      WMD_VS_REALM	varchar null,
      WMD_VS_SID	varchar null,
      WMD_SQL		long varchar not null,
      WMD_BALLON_INX	smallint not null,
      WMD_LAT_INX	smallint not null,
      WMD_LNG_INX	smallint not null,
      WMD_KEY_NAME_INX	smallint not null,
      WMD_KEY_VAL	long varchar not null,
      WMD_BASE_URL	long varchar not null,
      WMD_MODIFIED	TIMESTAMP,
      PRIMARY KEY(WMD_INST),
      CONSTRAINT WMD_FK_VSPX_SESSION
	 FOREIGN KEY (WMD_VS_REALM, WMD_VS_SID)
         REFERENCES DB.DBA.VSPX_SESSION (VS_REALM, VS_SID)
         ON UPDATE CASCADE
         ON DELETE CASCADE
    )'
)
;

insert soft DB.DBA.SYS_SCHEDULED_EVENT (SE_INTERVAL, SE_LAST_COMPLETED, SE_NAME, SE_SQL, SE_START)
   values (1440, NULL, 'WA_MAP_DISPLAY_SESSION_EXPIRE', 'WA_EXPIRE_WA_MAP_DISPLAY ()', now())
;

create procedure WA_EXPIRE_WA_MAP_DISPLAY ()
{
  delete from DB.DBA.WA_MAP_DISPLAY where datediff ('minute', WMD_MODIFIED, now()) > 120;
}
;

create procedure WA_MAPS_AJAX_GET_VALS_BY_ID (
  in _inst integer,
  out _sql varchar,
  out _baloon_inx smallint,
  out _lat_inx smallint,
  out _lng_inx smallint,
  out _key_name_inx smallint,
  out _key_val any,
  out _base_url varchar,
  out _vs_sid varchar,
  out _vs_realm varchar)
{
  _sql := null;
  declare cr cursor for select
     blob_to_string (WMD_SQL),
     WMD_BALLON_INX,
     WMD_LAT_INX,
     WMD_LNG_INX,
     WMD_KEY_NAME_INX,
     deserialize (blob_to_string (WMD_KEY_VAL)),
     blob_to_string (WMD_BASE_URL),
     WMD_VS_SID,
     WMD_VS_REALM
    from WA_MAP_DISPLAY
    where
      WMD_INST = _inst;
  open cr (prefetch 1);

  fetch cr
    into
     _sql,
     _baloon_inx,
     _lat_inx,
     _lng_inx,
     _key_name_inx,
     _key_val,
     _base_url,
     _vs_sid,
     _vs_realm;

  close cr;
}
;

create procedure WA_MAPS_AJAX_SET_VALS_GET_ID (
  out _inst integer,
  in _sql varchar,
  in _baloon_inx smallint,
  in _lat_inx smallint,
  in _lng_inx smallint,
  in _key_name_inx smallint,
  in _key_val any,
  in _base_url varchar,
  in _vs_sid varchar,
  in _vs_realm varchar)
{
    insert into WA_MAP_DISPLAY
      (
	WMD_VS_REALM,
	WMD_VS_SID,
	WMD_SQL,
	WMD_BALLON_INX,
	WMD_LAT_INX,
	WMD_LNG_INX,
	WMD_KEY_NAME_INX,
	WMD_KEY_VAL,
	WMD_BASE_URL
      )
     values
      (
	_vs_realm,
	_vs_sid,
	_sql,
	_baloon_inx,
	_lat_inx,
	_lng_inx,
	_key_name_inx,
	serialize (_key_val),
	_base_url
      );
    _inst := identity_value ();
}
;

create procedure WA_MAPS_AJAX_SEND_RESPONSE (
  in _sql varchar,
  in _baloon_inx smallint,
  in _lat_inx smallint,
  in _lng_inx smallint,
  in _key_name_inx smallint,
  in _key_val any,
  in _binding_nodes_count_inx smallint)
{
  declare hndl, row any;
  http_header (
    'Content-Type: text/xml; charset=utf-8\n' ||
    'Expires: Fri, 29 Jul 1972 15:00:00 GMT\n' ||
    'Cache-Control: no-store, no-cache, must-revalidate\n' ||
    'Cache-Control: post-check=0, pre-check=0\n' ||
    'Pragma: no-cache\n');
  http ('<?xml version="1.0" encoding="utf-8" ?>\n<map>');
--  dbg_printf ('%s', '<?xml version="1.0" encoding="utf-8" ?>\n<map>');

  declare center_lat, center_lng varchar;
  center_lat := NULL;
  center_lng := NULL;

  exec (_sql, NULL, NULL, vector (), 0, NULL, NULL, hndl);
  while (0 = exec_next (hndl, NULL, NULL, row))
    {
      declare _baloon_col varchar;
      declare _lat, _lng varchar;
      declare _count integer;
      declare _key_data any;

      _baloon_col := row[_baloon_inx - 1];
      _lat := sprintf ('%.6f', row[_lat_inx - 1]);
      _lng := sprintf ('%.6f', row[_lng_inx - 1]);
      _count := cast (row[_binding_nodes_count_inx - 1] as integer);
      _key_data := row[_key_name_inx - 1];

      http ('<marker ');
--      dbg_printf ('%s', '<marker ');
      if (_key_data = _key_val )
        {
          center_lat := _lat;
          center_lng := _lng;
          http ('center="true" ');
--          dbg_printf ('%s', 'center="true" ');
        }
      else
        {
          http ('center="false" ');
--          dbg_printf ('%s', 'center="false" ');
        }
      http (sprintf ('lat="%s" lng="%s" count="%d">\n<![CDATA[', _lat, _lng, _count));
--      dbg_printf ('%s', sprintf ('lat="%s" lng="%s" count="%d">\n<![CDATA[', _lat, _lng, _count));
      http (_baloon_col);
--      dbg_printf ('%s', _baloon_col);
      http (']]></marker>\n');
--      dbg_printf ('%s', ']]></marker>\n');
    }
  exec_close (hndl);
  http ('</map>');
--  dbg_printf ('%s', '</map>');
}
;


-- return only the objects in the visible square
create procedure WA_MAPS_CLIP_INVISIBLE (
  in _wmd_sql varchar,
  in _lng_min double precision,
  in _lng_max double precision,
  in _lat_min double precision,
  in _lat_max double precision)
returns varchar
{
  _wmd_sql := sprintf (
  'select _LNG, _LAT, _KEY_VAL, EXCERPT \n' ||
  ' from (%s) qry \n' ||
  ' where \n' ||
  '   (_LNG between %f and %f)\n' ||
  '   and (_LAT between %f and %f)',
  _wmd_sql,
  _lng_min, _lng_max, _lat_min, _lat_max);

  return _wmd_sql;
}
;

--drop aggregate WA_MAPS_BIND_USERS_EXCERPT;
wa_exec_no_error_log('
create aggregate WA_MAPS_BIND_USERS_EXCERPT (
  inout EXCERPT varchar) returns varchar
  from WA_MAPS_BIND_USERS_EXCERPT_init, WA_MAPS_BIND_USERS_EXCERPT_acc, WA_MAPS_BIND_USERS_EXCERPT_final
')
;

create procedure WA_MAPS_BIND_USERS_EXCERPT_init (inout _agg any)
{
  _agg := vector (0, NULL);
}
;

create procedure WA_MAPS_BIND_USERS_EXCERPT_acc (
  inout _agg any,
  inout _EXCERPT varchar)
{
   declare more_phrase varchar;
   more_phrase := '<div class="map_user_data">And more</div>';
--  if (length (_agg) > 2000)
--    {
--      if (right (_agg, length (more_phrase)) <> more_phrase)
--	_agg := concat (coalesce (_agg), more_phrase);
--    }
--  else
--    _agg := concat (coalesce (_agg), _EXCERPT);
   declare _cnt integer;
   _cnt := cast (_agg[0] as integer);
   if (_cnt = 0)
     _agg[1] := _EXCERPT;
   _agg[0] := _cnt + 1;
}
;

create function WA_MAPS_BIND_USERS_EXCERPT_final (inout _agg any)
returns varchar
{
--  dbg_obj_print ('WA_MAPS_BIND_USERS_EXCERPT_final tag(agg)=', __tag (_agg));
--  return _agg;
    return case _agg[0]
       when 0 then  _agg[1]
       when 1 then  _agg[1]
       else sprintf ('<div class="map_user_data">Group of %d users</div>', _agg[0])
       end;
}
;

--drop aggregate WA_MAPS_BIND_USERS_KEY_VAL;
wa_exec_no_error_log('
create aggregate WA_MAPS_BIND_USERS_KEY_VAL (
  inout _KEY_VAL any,
  inout _WMD_KEY_VAL any) returns any
  from WA_MAPS_BIND_USERS_KEY_VAL_init, WA_MAPS_BIND_USERS_KEY_VAL_acc, WA_MAPS_BIND_USERS_KEY_VAL_final
')
;


create procedure WA_MAPS_BIND_USERS_KEY_VAL_init (inout _agg any)
{
  _agg := NULL;
}
;

create procedure WA_MAPS_BIND_USERS_KEY_VAL_acc (
  inout _agg any,
  inout _KEY_VAL any,
  inout _WMD_KEY_VAL any)
{
   if (_KEY_VAL = _WMD_KEY_VAL)
     _agg := _KEY_VAL;
}
;

create function WA_MAPS_BIND_USERS_KEY_VAL_final (inout _agg any)
returns any
{
  return _agg;
}
;

create procedure WA_MAPS_INITIAL_POINTS (
  in _sql varchar,
  in _KEY_VAL any
)
{
  declare _LNG, _LAT double precision;
  declare EXCERPT varchar;
  declare BINDING_NODES_COUNT integer;
  declare _KEY_VAL_SER varchar;

  declare hndl, _row any;

  result_names (_LNG, _LAT, _KEY_VAL_SER, EXCERPT, BINDING_NODES_COUNT);

  declare _min_lng, _max_lng, _min_lat, _max_lat, _center_lat, _center_lng double precision;
  _min_lng := null;
  _max_lng := null;
  _min_lat := null;
  _max_lat := null;
  _center_lng := null;
  _center_lat := null;

  -- project out the excerpt column in hope for the best
  _sql := 'select _LNG, _LAT, _KEY_VAL from (' || _sql || ') pq';

  -- browse through the data
  exec (_sql, NULL, NULL, vector (), 0, NULL, NULL, hndl);
  while (0 = exec_next (hndl, NULL, NULL, _row))
    {
      declare _key_val_col any;

      _lng := _row [0];
      _lat := _row [1];
      _key_val_col := _row [2];
      if (_lng < _min_lng or _min_lng is null)
        _min_lng := _lng;
      if (_lat < _min_lat or _min_lat is null)
        _min_lat := _lat;
      if (_lng > _max_lng or _max_lng is null)
        _max_lng := _lng;
      if (_lat > _max_lat or _max_lat is null)
        _max_lat := _lat;
      if (_key_val_col = _KEY_VAL)
        {
          _center_lng := _lng;
          _center_lat := _lat;
          _KEY_VAL_SER := serialize (_KEY_VAL);
        }
     }
   exec_close (hndl);

   -- send out the up left point;
   if (_min_lng is not null and _min_lat is not null)
     result (cast (_min_lng as double precision), cast (_min_lat as double precision), serialize (NULL), '', 1);
   -- send out the bottom right point;
   if (_max_lng is not null and _max_lat is not null)
     result (cast (_max_lng as double precision), cast (_max_lat as double precision), serialize (NULL), '', 1);
   -- send the center point if any
   if (_center_lng is not null and _center_lat is not null)
     result (cast (_center_lng as double precision),
             cast (_center_lat as double precision),
             _KEY_VAL_SER, '', 1);
}
;

--drop view WA_MAPS_INITIAL_POINTS_VIEW;
wa_exec_no_error_log('
create procedure view WA_MAPS_INITIAL_POINTS_VIEW as
 WA_MAPS_INITIAL_POINTS (WMIPV_SQL, WMIPV_KEY_VAL)
 (_LNG double precision,
  _LAT double precision,
  _KEY_VAL_SER varchar,
  EXCERPT varchar,
  BINDING_NODES_COUNT integer)
')
;

create procedure WA_MAPS_BIND_MARKERS (
  in _wmd_sql varchar,
  in _lng_min double precision,
  in _lat_min double precision,
  in _lng_step double precision,
  in _lat_step double precision,
  inout _wmd_key_val any)
returns varchar
{
--  dbg_obj_print ('in WA_MAPS_BIND_MARKERS _wmd_sql=', _wmd_sql);
  if (_lng_step <> 0 and _lat_step <> 0)
    _wmd_sql := sprintf (
       ' select \n' ||
       '   _LLNG as _LNG, _LLAT as _LAT, \n' ||
       '   _KKEY_VAL as _KEY_VAL, EEXCERPT as EXCERPT, BINDING_NODES_COUNT \n' ||
       ' from (\n' ||
       '  select \n' ||
       '    AVG (_LNG) as _LLNG, \n' ||
       '    AVG (_LAT) as _LLAT, \n' ||
       '    WA_MAPS_BIND_USERS_KEY_VAL (_KEY_VAL, deserialize (decode_base64 (''%S''))) as _KKEY_VAL, \n' ||
       '    WA_MAPS_BIND_USERS_EXCERPT (EXCERPT) as EEXCERPT, \n' ||
       '    count (*) as BINDING_NODES_COUNT integer\n' ||
       '  from (%s) _b_qry\n' ||
       '  GROUP BY floor ((_LNG - %f) / %f), floor ((_LAT - %f) / %f)\n' ||
       ' ) ren_q',
       encode_base64 (serialize (_wmd_key_val)), _wmd_sql, _lng_min, _lng_step, _lat_min, _lat_step);
  else
    _wmd_sql := sprintf (
       ' select _LNG, _LAT, deserialize (_KEY_VAL_SER) as _KEY_VAL any, EXCERPT, BINDING_NODES_COUNT  \n' ||
       ' from WA_MAPS_INITIAL_POINTS_VIEW \n' ||
       ' where \n' ||
       '   WMIPV_SQL = ''%s'' \n' ||
       '   and WMIPV_KEY_VAL = deserialize (decode_base64 (''%S'')) \n',
       replace (_wmd_sql, '\'', '\'\''), encode_base64 (serialize (_wmd_key_val)));
  return _wmd_sql;
}
;

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

SOAP_LOAD_SCH (t_file_to_string (TUTORIAL_ROOT_DIR()||'/tutorial/services/so_s_35/mappoint.xsd'))
;


drop type glocation
;

create type glocation as
	(
	  name varchar,
	  x decimal,
	  y decimal,
	  lat any,
	  dnext double precision
	)
  temporary self as ref
;


create procedure init_point (in loc varchar) returns glocation
{
  declare ret glocation;
  declare tmp any;
  ret := new glocation ();
  ret.name := loc;
  tmp := map_find (loc);
  if (get_keyword ('NumberFound', tmp) < 1)
    {
      signal ('22023', 'The specified location '|| loc || ' does not exists in the Mappoint DB');
    }
  if (0 and get_keyword ('NumberFound', tmp) > 1)
    {
      signal ('22023', 'More than one location are found by address: '|| loc || ' try entering more specific address, eq. entering state code too');
    }
  ret.lat := get_keyword ('LatLong', get_keyword ('FoundLocation', aref (get_keyword ('Results', tmp), 0)));
  ret.name := get_keyword ('DisplayName', get_keyword ('Entity', get_keyword ('FoundLocation', aref (get_keyword ('Results', tmp), 0))));
  ret.x := get_keyword ('Latitude', ret.lat);
  ret.y := get_keyword ('Longitude', ret.lat);
  return ret;
}
;


create procedure get_distance (in p1 glocation, in p2 glocation) returns decimal
{
  return cdist_get (p1.lat, p2.lat);
}
;


create procedure gcalculate (in sp varchar, in loc varchar array, in userid varchar, in pwd varchar) returns varchar array
{
  declare ret, src any;
  declare len int;
  len := length (loc) + 1;
  ret := make_array (len, 'any');
  connection_set ('mappoint.uid', userid);
  connection_set ('mappoint.pwd', pwd);
  src := ret;
  src [0] := init_point (sp);
  ret [0] := src [0];
  for (declare i int, i := 1; i < len; i := i + 1)
   {
     src [i] := init_point (loc [i-1]);
   }
  for (declare j int, j := 1; j < len; j := j + 1)
     {
       declare min_dist decimal;
       declare point glocation;
       declare found_inx int;
       min_dist := null;
       point := null;
       found_inx := null;
       for (declare i int, i := 1; i < len; i := i + 1)
	 {
	   declare dist decimal;
           if (src[i] is not null)
             {
               declare s,r glocation;
	       s := ret[j-1]; r := src[i];
	       dist := get_distance (s, r);
	       if (min_dist is null or min_dist > dist)
		 {
		   min_dist := dist;
		   point := src[i];
	           found_inx := i;
		 }
             }
	 }
       if (found_inx is not null)
         {
           declare s,r glocation;
           s := ret[j-1];
           s.dnext := min_dist;
	   ret [j]  := point;
	   src[found_inx] := null;
         }
     }
--  dbg_obj_print (ret);
  return ret;
}
;

create procedure map_find (in addr varchar)
{
  declare spec soap_parameter;
  declare _body, xe, _result any;
  spec := new soap_parameter ();
  spec.set_xsd ('http://s.mappoint.net/mappoint-30/:FindSpecification');
  spec.add_member ('DataSourceName', 'MapPoint.NA');
  spec.add_member ('InputPlace', addr);
  _body := soap_client (url=>'http://findv3.staging.mappoint.net/Find-30/FindService.asmx',
	operation => 'Find',
	soap_action => 'http://s.mappoint.net/mappoint-30/Find',
        target_namespace => 'http://s.mappoint.net/mappoint-30/',
	style=>(5+16),
	parameters=> spec.get_call_param ('specification') ,
        user_name=>connection_get ('mappoint.uid'),
	user_password=>connection_get ('mappoint.pwd')
   );
  xe := xml_cut (xml_tree_doc (_body));
  _result := null;
  if (xpath_eval ('[ xmlns:SOAP="http://schemas.xmlsoap.org/soap/envelope/" ] //SOAP:Fault', xe, 1) is null)
    {
      _result := xml_cut (xpath_eval ('//FindResult', xe, 1));
      _result := soap_box_xml_entity_validating (_result, 'http://s.mappoint.net/mappoint-30/:FindResults', 0);
    }
  return _result;
}
;


create procedure cdist_get (in al any, in bl any)
{
  declare spec soap_parameter;
  declare _result, _body, xe any;
  _result := DB.DBA.SOAP_CLIENT (
	        url=>'http://routev3.staging.mappoint.net/Route-30/RouteService.asmx',
		operation=>'CalculateSimpleRoute',
 		soap_action=>'http://s.mappoint.net/mappoint-30/CalculateSimpleRoute',
	        target_namespace=>'http://s.mappoint.net/mappoint-30/',
 		parameters=>vector
                        (
        		 vector('latLongs', 'http://s.mappoint.net/mappoint-30/:ArrayOfLatLong'), vector (al, bl) ,
        		 vector('dataSourceName', 'http://www.w3.org/2001/XMLSchema:string'), 'MapPoint.NA' ,
        		 vector('preference', 'http://s.mappoint.net/mappoint-30/:SegmentPreference'),
			   vector (composite (), '', 'Shortest')
			),
		user_name=>connection_get ('mappoint.uid'),
		user_password=>connection_get ('mappoint.pwd'),
		style=>(5+16)
               );
  _body := _result;
  xe := xml_cut (xml_tree_doc (_body));
  if (xpath_eval ('[ xmlns:SOAP="http://schemas.xmlsoap.org/soap/envelope/" ] //SOAP:Fault', xe, 1) is null)
    {
      _result := xml_cut (xpath_eval ('//CalculateSimpleRouteResult/Itinerary/Distance', xe, 1));
      _result := soap_box_xml_entity_validating (_result, 'double', 0);
    }
  return _result;
}
;

/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2017 OpenLink Software
 *
 *  This project is free software; you can redistribute it and/or modify it
 *  under the terms of the GNU General Public License as published by the
 *  Free Software Foundation; only version 2 of the License, dated June 1991.
 *
 *  This program is distributed in the hope that it will be useful, but
 *  WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 *  General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License along
 *  with this program; if not, write to the Free Software Foundation, Inc.,
 *  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
 *
 */

/*
  CONSTANTS
*/
// max zoom allowed by Google maps
var MAX_ZOOM_LEVEL = 17;
// Where the "center of the world is"
var BURLINGTON_LNG = -71.19;
var BURLINGTON_LAT = 42.490;
// Icon size for the marker icon (in pixels)
var ICON_WIDTH = 16;
var ICON_HEIGHT = 16;
// Place where the pointing point is inside the marker icon
var ICON_ANCHOR_OFS_X = 7;
var ICON_ANCHOR_OFS_Y = 14;
// Place where to stick the balloon's tip inside the marker icon
var ICON_INFO_ANCHOR_X = 8;
var ICON_INFO_ANCHOR_Y = 5;
// Add that many zoom levels to the autocalculated one (so the gmaps won't drop the corner markers)
var ADDITIONAL_ZOOM_LEVELS = 1;
// no lower than that zoom level for auto zoom
var MIN_ZOOM_LEVEL = 3;
// the initial map type
var MAP_TYPE = G_MAP_TYPE;

/*
FUNCTIONS
*/


/* 
 * Util function
 * Puts a marker and adds the event handler to print the balloon on click.
*/
function createMarker(point, icon, excerpt) 
{
  var marker = new GMarker(point, icon);

  // Show this markers index in the info window when it is clicked.
  GEvent.addListener(marker, 'click', function() {
      marker.openInfoWindowHtml(excerpt);
      });

  return marker;
}

/* 
 * Util function
 * picks a marker icon based on the number of the points in the aggregation.
*/
function pickMarkerIcon (icons, count)
{
  if (count > 1 && icons.length > 1)
    return icons[1];
  else
    return icons[0];
}

/* 
 * Util function
 * The ready handler for the http request to the ajax data server.
 * parses the incoming XML, puts the markers on the map and
 * calculates and sets the zoom level to fit all the markers
*/
function ProcessMarkerXML (map, icons, request, do_center, custom_zoom_level)
{
  try 
    {
     if (request.readyState == 4)
    {
    if (request.status == 200)
      {
        var xmlDoc = request.responseXML;
        var markers = xmlDoc.documentElement.getElementsByTagName("marker");
        var max_bounds = null;
        var center = null;
        var lng;
        var lat;
        var count;
        for (var i = 0; i < markers.length; i++) 
      {
        lng = parseFloat (markers[i].getAttribute("lng"));
        lat = parseFloat (markers[i].getAttribute("lat"));
        count = parseInt (markers[i].getAttribute("count"));
        if (do_center == true)
        {
//        alert ('lat=' + lat + ' lng=' + lng);
          if (max_bounds == null)
          {
           max_bounds = new GBounds (lng,lat,lng,lat);
  //       alert ('NEW !minX=' + max_bounds.minX + ' maxX=' + max_bounds.maxX + 
  //           ' minY=' + max_bounds.minY + ' maxY=' + max_bounds.maxY);
          }
           else
          {
           if (max_bounds.minX > lng)
             max_bounds.minX = lng;
           else if (max_bounds.maxX < lng)
             max_bounds.maxX = lng;
           if (max_bounds.minY > lat)
             max_bounds.minY = lat;
           else if (max_bounds.maxY < lat)
             max_bounds.maxY = lat;
  //       alert ('SET minX=' + max_bounds.minX + ' maxX=' + max_bounds.maxX + 
  //           ' minY=' + max_bounds.minY + ' maxY=' + max_bounds.maxY);
          }   
        }
        else
        {
         map.addOverlay (createMarker(
         new GPoint(lng, lat), 
         pickMarkerIcon (icons, count), 
         GXml.value (markers[i])
            ));
        }
        
        if (do_center == true && markers[i].getAttribute("center") == "true")
        {
           center = new GPoint (lng, lat);
        }
        }  
        if (do_center == true && max_bounds != null)      
        {
//        alert ('minX=' + max_bounds.minX + ' maxX=' + max_bounds.maxX + 
//            ' minY=' + max_bounds.minY + ' maxY=' + max_bounds.maxY);
          if (center == null)  
            center = new GPoint( 
          (max_bounds.maxX - max_bounds.minX)/2, 
          (max_bounds.maxY - max_bounds.minY)/2 );
          var delta = new GSize(max_bounds.maxX - max_bounds.minX, max_bounds.maxY - max_bounds.minY);
          var minZoom = map.spec.getLowestZoomLevel(center, delta, map.viewSize) + ADDITIONAL_ZOOM_LEVELS;
                      if (minZoom < MIN_ZOOM_LEVEL)
                          minZoom = MIN_ZOOM_LEVEL;
          if (custom_zoom_level<0){
              map.centerAndZoom(center, minZoom); 
          }else{
             if (custom_zoom_level<MIN_ZOOM_LEVEL) custom_zoom_level=MIN_ZOOM_LEVEL;
             if (custom_zoom_level>MAX_ZOOM_LEVEL) custom_zoom_level=MIN_ZOOM_LEVEL;
             map.centerAndZoom(center, custom_zoom_level); 
          }

//          GEvent.addListener(map, "moveend", onMapMoved);
        }
      }
      else
      {
        throw ("HTTP error " + request.status);
      }
    }
    }
    
    catch (e)
    {
        alert ("Cannot retrieve data for the map from the server : " + e);
    }
}

/* 
 * Util function
 * Calculates lat/lng out of screen pixels
 * Returns a GPoint
*/
function getLatLongFromBitmapSize ( map, x, y )
{
  var type = map.getCurrentMapType();
  var bord = map.getBoundsLatLng();
  var zoom = map.getZoomLevel();
  var at = type.getBitmapCoordinate( bord.minY, bord.minX, zoom );
  var offset = type.getLatLng( at.x + x, at.y + y, zoom ); 
/*  alert ('bord.minX=' + bord.minX + ' bord.minY=' + bord.minY + '\n' +
       "x=" + x + ' y=' + y + '\n' +
  'at.x=' + at.x + ' at.y=' + at.y + '\n' + 
  'offset.x=' + offset.x + ' offset.y=' + offset.y);*/
  return new GPoint (offset.x - bord.minX, Math.abs (offset.y - bord.minY));
}

/* 
 * Util function
 * Constructs the query URL to the ajax server, clears the map and sends the request
*/
function FillIconList(map, ajax_server_url, icons, inst, is_initial, custom_zoom_level) 
{
  try 
    {
      // center the map if it is the first call to the function
      var do_center = is_initial;
      var bounds = map.getBoundsLatLng(); 

      var lat_min = bounds.minY;
      var lat_max = bounds.maxY;
      var lng_min = bounds.minX;
      var lng_max = bounds.maxX;

      // zero means no binding
      var lat_step = 0;
      var lng_step = 0;
      if (is_initial == false)
        {
    // calculate the width and height of the icon in geo coordinates 
    // and use that as a step for binding the points together server side
          var size = getLatLongFromBitmapSize (map, ICON_WIDTH, ICON_HEIGHT);
    lat_step = size.y;
    lng_step = size.x;
          /*alert ('lat_min=' + lat_min + ' lat_max=' + lat_max + ' lat_step=' + lat_step + '\n' + 
          'lng_min=' + lng_min + ' lng_max=' + lng_max + ' lng_step=' + lng_step);*/
        }

      var url = 
    ajax_server_url + 
    "?inst=" + inst +
    "&al=" + lat_min +
    "&ah=" + lat_max +
    "&nl=" + lng_min +
    "&nh=" + lng_max +
    "&as=" + lat_step +
    "&ns=" + lng_step;
      var request = GXmlHttp.create();

      request.open("GET", url, true);
      request.onreadystatechange = function () {
         ProcessMarkerXML (map, icons, request, do_center, custom_zoom_level);
      };

      map.clearOverlays ();
      request.send (null);    
    }
  catch (e)
    {
      alert ("Cannot retrieve data for the map from the server : " + e);
    }
}


/* 
 * The Top level function : 
 * Inits the map into the given ID, sets the callbacks and
 * asks the ajax server for points
 * Params : 
 *   div_id : the DIV to put the map in
 *   ajax_server_url : The url to ajax_server.vsp
 *   icon_base_url : The url to the icon(s)
 *   inst_id : the id of the search SQL stored in the ajax server search table
 *   
*/
function initMap (div_id,ajax_server_url,icon_base_url,inst_id, custom_zoom_level)
{
  if (typeof(custom_zoom_level)=='undefined') custom_zoom_level=-1;
  
//  alert(custom_zoom_level);
  
  var map = new GMap(document.getElementById(div_id));
  var infoOpened = false;

  map.setMapType (MAP_TYPE);
  map.addControl(new GSmallMapControl());
  map.addControl(new GMapTypeControl());

  // start with all of the world centered on Burlington, MA
  // needed so the ajax server can get all of the points and 
  // autoscale correctly
  map.centerAndZoom (
      new GPoint (BURLINGTON_LNG, BURLINGTON_LAT), // on Burlington, MA
      MAX_ZOOM_LEVEL// MAX_ZOOM_LEVEL max zoom : to see all of the world
      );

  // Create our marker icons
  var icons = [ new GIcon(), new GIcon() ];

  // for the normal markers
  icons[0] = new GIcon();
  icons[0].image = icon_base_url + "/user_16.png";
  icons[0].iconSize = new GSize(ICON_WIDTH, ICON_HEIGHT);
  icons[0].iconAnchor = new GPoint(ICON_ANCHOR_OFS_X, ICON_ANCHOR_OFS_Y);
  icons[0].infoWindowAnchor = new GPoint(ICON_INFO_ANCHOR_X, ICON_INFO_ANCHOR_Y);

  // for aggregated markers
  icons[1] = new GIcon();
  icons[1].image = icon_base_url + "/group_24.png";
  icons[1].iconSize = new GSize(ICON_WIDTH, ICON_HEIGHT);
  icons[1].iconAnchor = new GPoint(ICON_ANCHOR_OFS_X, ICON_ANCHOR_OFS_Y);
  icons[1].infoWindowAnchor = new GPoint(ICON_INFO_ANCHOR_X, ICON_INFO_ANCHOR_Y);

  // stop the redrawing when a balloon is to be shown
  var onInfoWindowOpen = function ()
    {
      infoOpened = true;
    };  

  // if no balloon redraw on move.
  // note that we do not need the onZoom handler since the 
  // gmaps will issue onMove even on zoom.
  var onMapMoved = function ()
    {
      if( infoOpened == true ) 
  {
    infoOpened = false;
    return;
  }

      FillIconList(map, ajax_server_url, icons, inst_id, false, null, custom_zoom_level);
    }; 

  // init the map
  GEvent.addListener(map, "moveend", onMapMoved);
  FillIconList(map, ajax_server_url, icons, inst_id, true ,custom_zoom_level);
  GEvent.addListener(map, "infowindowopen", onInfoWindowOpen); 
}

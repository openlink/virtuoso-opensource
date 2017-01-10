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

var page_location = location.href;
var base_path = '/photos/res/';

var ds_albums = new dataSet();
var ds_current_album = new dataSet();



function setMapInitToOdsInitArray()
{
  if( typeof(ODSInitArray) == 'undefined')
  {
    setTimeout(setMapInitToOdsInitArray,10);
  } else {
     ODSInitArray.push(mapInitPrepare);
  }
}

//setMapInitToOdsInitArray();

function mapInitPrepare()
{
  if (typeof(window.mapInit) == "function")
    {
    OAT.Loader.load(["gmaps"], function(){setTimeout(mapInit,60)});
}
}

var MAX_ZOOM_LEVEL = 15;
var BURLINGTON_LAT = 42.490;
var BURLINGTON_LNG = -71.19;
var map;

var markersPosArr = [];
var markericon_path=base_path + 'i/ods_gallery_24.png';
var markericon_width='24';
var markericon_height='24';

//------------------------------------------------------------------------------
function mapInit()
{
     markersPosArr = [];
     var providerType=OAT.MapData.TYPE_G;
     var containerDiv=$('map');
     
     OAT.Dom.clear(containerDiv);
     if(containerDiv)
     {
      var mapOptObj = {
	                     fix:OAT.MapData.FIX_ROUND1,
	                     fixDistance:20,
	                     fixEpsilon:0.5
                      };
       map= new OAT.Map(containerDiv,providerType,mapOptObj);
       map.centerAndZoom(BURLINGTON_LAT,BURLINGTON_LNG,MAX_ZOOM_LEVEL);
       map.addTypeControl();
       map.addMapControl();
       map.setMapType(OAT.MapData.MAP_HYB);


       map.show = function ()
       {
         OAT.Dom.show(containerDiv);
         if(map && map.markersPosArr)
         {
           map.obj.checkResize();
           map.optimalPosition(map.markersPosArr);
         }
    }
       
       map.findMarkerIndexByCoords = function (lat,lng)
       {
      for(var i=0;i<map.markerArr.length;i++)
      {
            if(map.markerArr[i].__coords[0]==lat && map.markerArr[i].__coords[1]==lng)
               return i;
         }
         return -1;
       }

       map.findMarkerIndexByGroup = function (groupname)
       {
      for (var i=0; i<map.markerArr.length; i++)
      {
            if(map.markerArr[i].__group==groupname)
               return i;
         }
         return -1;
       }

       for(var r=0;r<ds_albums.list.length;r++)
       {
         if(ds_albums.list[r].geolocation[2]!='false') // show on map propertie
         {
           if(ds_albums.list[r].obsolete!=1)
           {
           var album_preview_div = preview_collection_4_map(ds_albums.list[r],r);
        
           var _lat=ds_albums.list[r].geolocation[0];
           var _lng=ds_albums.list[r].geolocation[1];
           var group_index=r;
           

           map.addMarker(group_index,_lat,_lng,markericon_path,markericon_width,markericon_height,ref(map,album_preview_div));
           markersPosArr.push([_lat,_lng]);
          }
         }
    }

       map.markersPosArr=false;
       if(markersPosArr.length)
       {
          map.markersPosArr=markersPosArr;
          map.optimalPosition(markersPosArr);
       }
     }
}

//------------------------------------------------------------------------------
function ref(_map, user_div)
{
 		return function(marker) {
				_map.closeWindow();
        _map.openWindow(marker,user_div);
        if(marker.__group!='new');
        {  
					for (var i=0;i<TL.obj.events.length;i++)
					{ 
             OAT.Dom.removeClass(TL.obj.events[i].elm,"event_active"); 
					}

          var _event = (ds_albums.list[marker.__group]).event;
          OAT.Dom.addClass(_event.elm,"event_active");
          TL.scrollTo( _event);
        }
  }
}
//------------------------------------------------------------------------------

function changeAlbumMarkerPos (p)
{
  if(p)
  {
   var markerIndex = map.findMarkerIndexByGroup(ds_albums.current.index);
    if(markerIndex>=0)
    {
      var _marker=map.markerArr[markerIndex];
      map.removeMarker(_marker);
      markersPosArr.pop(markerIndex);
    }

      var _lat=Math.round(p.y*1000000)/1000000;
      var _lng=Math.round(p.x*1000000)/1000000;
      $('edit_album_lng').value=_lat;
      $('edit_album_lat').value=_lng;
      var group_index=ds_albums.current.index;
      var album_preview_div = preview_collection_4_map(ds_albums.current,ds_albums.current.index);
       
      map.addMarker(group_index,_lat,_lng,markericon_path,markericon_width,markericon_height,ref(map,album_preview_div));
      markersPosArr.push([_lat,_lng]);
  }
}

function newAlbumMarker (p)
{
  if(p)
  {
   var markerIndex = map.findMarkerIndexByGroup('new');
    if(markerIndex>=0)
    {
      var _marker=map.markerArr[markerIndex];
      map.removeMarker(_marker);
    }
      var _lat=Math.round(p.y*1000000)/1000000;
      var _lng=Math.round(p.x*1000000)/1000000;
      $('new_album_lng').value=_lat;
      $('new_album_lat').value=_lng;
      var group_index=ds_albums.current.index;
      var album_preview_div = OAT.Dom.create('div');

      album_preview_div.setAttribute('id','album_map_preview_new');
      map.addMarker('new',_lat,_lng,markericon_path,markericon_width,markericon_height,ref(map,album_preview_div));
  }
}

function newAlbumMarkerUpdate ()
{
   var markerIndex = map.findMarkerIndexByGroup('new');
    if(markerIndex>=0)
    {
      var _marker=map.markerArr[markerIndex];
      map.removeMarker(_marker);
    }
      var _lat=ds_albums.current.geolocation[0];
      var _lng=ds_albums.current.geolocation[1];
      var group_index=ds_albums.current.index;
      var album_preview_div = preview_collection_4_map(ds_albums.current,ds_albums.current.index);
       
      map.addMarker(group_index,_lat,_lng,markericon_path,markericon_width,markericon_height,ref(map,album_preview_div));
      markersPosArr.push([_lat,_lng]);
}

function removeAlbumMarker ()
{
  var markerIndex = map.findMarkerIndexByGroup(ds_albums.current.index);
  if(markerIndex>=0)
  {
    var _marker=map.markerArr[markerIndex];
    map.removeMarker(_marker);
  }
}

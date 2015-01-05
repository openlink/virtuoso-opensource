/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2015 OpenLink Software
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

var gallery = new Object();
gallery.flickr = {};
gallery.flickr.status = '';
var gallery_path;

//------------------------------------------------------------------------------
gallery.init = function (path){

  var agentWidth=OAT.Dom.getViewport();
  
  $('wrapper').style.width=agentWidth[0]+'px';
  $('main_container').style.width=agentWidth[0]-16+'px';
  $('map').style.width=agentWidth[0]-15+'px';
  if(agentWidth[1]<800)
  $('map').style.height=350+'px';  

  this.albums         = new panel('albums');
  this.albums_list    = new panel('care_my_albums');
  this.albums_man     = new panel('my_albums_man');
  this.images         = new panel('images');
  this.image          = new panel('image');
  this.info           = new panel('info');
  this.nav            = new panel('nav');
  //this.toolbar        = new panel('toolbar');
  this.error_box      = new panel('error_box');
  this.slideshow      = new panel('slideshow');
  this.new_album      = new panel('new_album');
  this.edit_album     = new panel('edit_album');
  this.edit_albumsettings = new panel('edit_album_settings');
  this.images_upload      = new panel('images_upload');
  this.tags           = new panel('tags');
  this.comments       = new panel('comments');
  this.comments_list  = new panel('comments_list');
  this.image_info     = new panel('image_info');
  this.image_edit     = new panel('image_edit');
  this.link_images_import = new panel('link_images_import');
  this.link_images_import = new panel('link_images_export');

  this.slideshow_run = 0;
  this.show_exif_flag = 0;

  gallery.current_state = Array(3);
  if (location.hash && location.hash != '#')
  {
    gallery.current_state = location.hash.substring(1).split(':')
    page_location = location.href.substring(0,location.href.indexOf('#'))
  }

  gallery_path = path;
  $("wrapper").onclick = dispatch;
  gallery.ajax.load_settings();
  gallery.ajax.load_albums(gallery_path);

  gallery.rotator = new OAT.Rotator(505,400,{delay:1,step:2,numLeft:1,pause:1000,type:OAT.RotatorData.TYPE_LEFT},function(){});
  $("rotator_viewport").appendChild(gallery.rotator.div);

  var SlideShow_back = function(){
    reverse = function(){
      if (!gallery.rotator.running)
      {
        gallery.rotator.options.type = OAT.RotatorData.TYPE_RIGHT;
        gallery.rotator.start();
        gallery.slideshow_status_update();
      }
    }
    gallery.rotator.callback = reverse;
    gallery.rotator.stop();

  }

  var SlideShow_stop = function(){
    if (gallery.rotator.running)
    {
      gallery.rotator.callback = function(){};
      gallery.rotator.stop();
    }else{
      gallery.rotator.start();
    }
    gallery.slideshow_status_update();
  }

  var SlideShow_next = function(){
    reverse = function(){
      if (!gallery.rotator.running)
      {
        gallery.rotator.options.type = OAT.RotatorData.TYPE_LEFT;
        //gallery.rotator.start();
        gallery.slideshow_status_update();
      }
    }
    if (!gallery.rotator.running)
    {
      gallery.rotator.options.type = OAT.RotatorData.TYPE_LEFT;
      gallery.rotator.start();
      gallery.slideshow_status_update();
    }else{
      gallery.rotator.callback = reverse;
      gallery.rotator.stop();
    }

  }

  OAT.Event.attach("SlideShow_back",'click',SlideShow_back);
  OAT.Event.attach("SlideShow_stop",'click',SlideShow_stop);
  OAT.Event.attach("SlideShow_next",'click',SlideShow_next);
  OAT.Event.attach("images_import_flickr",'click',gallery.ajax.flickr_login_link);
  OAT.Event.attach("images_import_flickr_list",'click',gallery.ajax.flickr_get_photos_list);
  OAT.Event.attach("images_import_flickr_save",'click',gallery.ajax.flickr_save_photos);
  OAT.Event.attach("images_export_flickr",'click',gallery.ajax.flickr_login_link);
  OAT.Event.attach("images_export_flickr_send",'click',gallery.ajax.flickr_send_photos);



  var slider = new OAT.Slider("slider_btn",{minPos:10,maxPos:140});
  slider.onchange = function(value) {
      gallery.rotator.options.pause = value * 100
      gallery.slideshow_status_update();
    }
  slider.init();
}

//------------------------------------------------------------------------------
function jump_to()
{
  var path  = location.hash.substring(1).split('/');

  if (path.length == 1 && path.length == 2)
  {
    // Home page - show albums
    return true;
  }else if(path.length == 3 && path[2] == ''){
    // Folder list - show images

    gallery.setCurrentByName(path[1]);
    //eval('ajax.Start(gallery_load_images,'+ds_albums.current.index+')');
    eval('gallery.ajax.load_images('+ds_albums.current.index+')');
    return false;

  }else if(path.length == 3){
    // Preview image - show image
    gallery.setCurrentByName(path[1]);
    //eval('ajax.Start(gallery_load_images,'+ds_albums.current.index+')');
    eval('gallery.ajax.load_images('+ds_albums.current.index+')');
    return false;
  }

  return true;
}

//------------------------------------------------------------------------------
function path_set_folder(path)
{
  if (path != '')
  {
    path = '#/' + path + '/';
  }else{
    path = '#';
  }
  location.href = page_location + path;
}

//------------------------------------------------------------------------------
function path_set_file(path)
{
  var folders = location.hash.substring(1,location.hash.lastIndexOf('/')+1);

  location.href = page_location + '#' + folders + path;
}

//------------------------------------------------------------------------------
gallery.setCurrent = function(current_id)
{
  ds_albums.setCurrent(current_id);
  ds_current_album.list.length = 0;
}

//------------------------------------------------------------------------------
gallery.setCurrentByName = function(current_name)
{
  var ind = ds_albums.checkNameExist(current_name);
  if (ind > -1)
  {
    ds_albums.setCurrent(ind);
    ds_current_album.list.length = 0;
  }
}

//------------------------------------------------------------------------------
gallery.closePanels = function()
{
  OAT.Dom.hide('edit_album_settings');
  OAT.Dom.hide('new_album');
}

//------------------------------------------------------------------------------
gallery.albums_click = function(el)
{
  current_id = getId(el.id);

  OAT.Dom.hide('timeline');
  //OAT.Dom.hide('map');

  if (ds_albums.settings.show_map == 1)
  {
    if (map)
    {
      map.show();
    } else {
      if (typeof(window.mapInitPrepare) == "function")
      {
        mapInitPrepare();
      }
      OAT.Dom.show('map')
    }
  } else {
  OAT.Dom.hide('map');
  }

  gallery.closePanels();
  gallery.nav.tabs(1);
  
  gallery.setCurrent(current_id);
  //ajax.Start(gallery_load_images,current_id);
  gallery.ajax.load_images(current_id);
  }

//------------------------------------------------------------------------------
gallery.editCollections = function (dav_lines)
{
  if (!ds_albums.editAlbumToList(dav_lines))
  {
        var messages = Array();
        var id = dav_lines.id * -1;
        messages[3] = "The album '" + dav_lines.name + "' all ready exist";
        gallery.showError(new Error(messages[id]))
        document.getElementById('new_album_name').value.selected=true
        return;
      }

      r = ds_albums.current.index;
      ds_albums.setCurrent(r);
      coll = preview_collection(ds_albums.list[r],r);

    
//    gallery.albums.removeChild(gallery.albums.childNodes[Number(ds_albums.current.index)]);
//    gallery.albums.appendChild(coll)

    gallery.albums.replaceChild(coll, gallery.albums.childNodes[Number(ds_albums.current.index)]); 

      gallery.edit_album.hide();

      gallery.showImages();

    TL.draw();
    
  if (ds_albums.settings.show_map == 1)
    mapInit();
    OAT.Dom.hide('map');    
    OAT.Dom.hide('timeline');    
  }

//------------------------------------------------------------------------------
gallery.settings_tab_click = function ()
{
  gallery.managePanels('edit_albumsettings');
  $('edit_album_showmap').checked = ds_albums.settings.show_map==1? true : false;
  $('edit_album_showtimeline').checked = ds_albums.settings.show_timeline==1 ? true : false;
  $('edit_album_nntp').checked = ds_albums.settings.nntp == 1? true : false;
  $('edit_album_nntp_init').checked = ds_albums.settings.nntp_init == 1 ? true : false;
  $('albums_per_page').value = ds_albums.settings.albums_per_page;

  gallery.nav.tabs(3);
}

//------------------------------------------------------------------------------
gallery.edit_albumsettings_action = function ()
{
  gallery.ajax.edit_album_settings();
  gallery.nav.tabs(1);
}

//------------------------------------------------------------------------------
gallery.edit_albumsettings_cancel = function ()
{
 OAT.Dom.hide('edit_album_settings');
 gallery.nav.tabs(1);
 gallery.managePanels('my_albums');
  gallery.show_albums_page_navigation();
}

//------------------------------------------------------------------------------
gallery.new_album_tab_click = function ()
{
  if(ds_albums.settings.show_timeline==1)
  OAT.Dom.show('timeline');
  if(ds_albums.settings.show_map==1)
  {
  OAT.Dom.show('map');

  $('map').className = $('map').className.replace( "view","edit");
 	map.lastGEvent =	GEvent.addListener(map.obj,"click",function(o,p){if (!p){ return; } newAlbumMarker(p);});
  }
  gallery.managePanels('new_album');
  $('new_album_description').value = '';
  $('new_album_name').value = '';
  var d = new Date();
  var year = d.getFullYear();
  var month = d.getMonth()
  var month = d.getDay()

//  $('new_album_pub_date_day').selectedIndex = d.getDate()-1;
//  $('new_album_pub_date_month').selectedIndex = d.getMonth();
//  $('new_album_pub_date_year').selectedIndex = String(d.getFullYear()).substring(3)-1;
  

  $('new_album_start_date_day').selectedIndex = d.getDate();
  $('new_album_start_date_month').selectedIndex = d.getMonth();
  $('new_album_start_date_year').selectedIndex = String(d.getFullYear()).substring(3);

  $('new_album_end_date_day').selectedIndex = d.getDate();
  $('new_album_end_date_month').selectedIndex = d.getMonth();
  $('new_album_end_date_year').selectedIndex = String(d.getFullYear()).substring(3);
  
  gallery.nav.tabs(2);
}

//------------------------------------------------------------------------------
gallery.new_album_close_click = function()
{
 gallery.my_albums_tab_click();
 gallery.nav.tabs(1);
}

//------------------------------------------------------------------------------
gallery.new_album_action = function ()
{
  $('new_album_name').style.background             = "#FFFFFF";
  $('new_album_lng').style.background              = "#FFFFFF";
  $('new_album_lat').style.background              = "#FFFFFF";
  $('new_album_showonmap').style.background        = "#FFFFFF";
  $('new_album_start_date_year').style.background  = "#FFFFFF";
  $('new_album_start_date_month').style.background = "#FFFFFF";
  $('new_album_start_date_day').style.background   = "#FFFFFF";

  var name = strip_spaces(document.getElementById('new_album_name').value);
  document.getElementById('new_album_name').value = name;

  if (document.getElementById('new_album_name').value == '')
  {
    alert('Please, type album name.');
    document.getElementById('new_album_name').focus();
    document.getElementById('new_album_name').style.background = "#FFFF9B";
    return;
  }
  geo_regexp = new RegExp('^\\-{0,1}\\d{0,3}\\.\\d{0,6}$');
  if ( $('new_album_lng').value.length && !geo_regexp.test($('new_album_lng').value))
  {
    alert('Please, fill in a correct longitude value. [{-}ddd.dddddd]');
    $('new_album_lng').focus();
    $('new_album_lng').style.background = "#FFFF9B";
    return;
  }
  if ( $('new_album_lat').value.length && !geo_regexp.test($('new_album_lat').value))
  {
    alert('Please, fill in a correct latitude value. [{-}ddd.dddddd]');
    $('new_album_lat').focus();
    $('new_album_lat').style.background = "#FFFF9B";
    return;
  }

  if( ($('new_album_lng').value.length==0 || $('new_album_lat').value.length==0) && $('new_album_showonmap').checked )
  {
    alert('Fill in correct Longitude / Latitude coordinates to show album on map.');
    $('new_album_showonmap').style.background = "#FFFF9B";
    if($('new_album_lng').value.length==0)
    {
      $('new_album_lng').focus();
      $('new_album_lng').style.background = "#FFFF9B";
    }
    else
    {
      $('new_album_lat').focus();
      $('new_album_lat').style.background = "#FFFF9B";
    }
    return;
  }
    
  var startDate = new Date ( $('new_album_start_date_year').value,$('new_album_start_date_month').value,$('new_album_start_date_day').value,0,0,0 );
  var endDate   = new Date ( $('new_album_end_date_year').value,$('new_album_end_date_month').value,$('new_album_end_date_day').value,0,0,0 );
  if(endDate<startDate)
  {
    alert('Start Date should be prior to End Date.');
    $('new_album_start_date_year').style.background = "#FFFF9B";
    $('new_album_start_date_month').style.background = "#FFFF9B";
    $('new_album_start_date_day').style.background = "#FFFF9B";
    return;
  }

  if (ds_albums.settings.show_map == 1)
  {
  $('map').className = $('map').className.replace( "edit","view");
  GEvent.removeListener(map.lastGEvent);
  }
  gallery.ajax.new_album();
}

//------------------------------------------------------------------------------
gallery.new_album_name_click = function(el)
{}

//------------------------------------------------------------------------------
gallery.link_edit_album_click = function ()
{
  gallery.managePanels('edit_album');
  if (ds_albums.settings.show_map==1)
  {
  $('map').className = $('map').className.replace( "view","edit");
 	map.lastGEvent =	GEvent.addListener(map.obj,"click",function(o,p){if (!p){ return; } changeAlbumMarkerPos(p);});
  }
  document.getElementById('edit_album_name_old').value = ds_albums.current.name;
  document.getElementById('edit_album_name').value = ds_albums.current.name;

  if ((typeof ds_albums.current.description) != 'undefined')
  {
    document.f1.edit_album_description.value = ds_albums.current.description;
  }
//  var t_date = sdate2obj(ds_albums.current.pub_date);

  var s_date = sdate2obj(ds_albums.current.start_date);
  var e_date = sdate2obj(ds_albums.current.end_date);

//  $('edit_album_pub_date_year').selectedIndex  = String(t_date.elements[0]).substring(3,4);
//  $('edit_album_pub_date_day').selectedIndex   = Number(t_date.elements[2])-1;
//  $('edit_album_pub_date_month').selectedIndex = Number(t_date.elements[1])-1;

  $('edit_album_start_date_year').selectedIndex  = String(s_date.elements[0]).substring(3,4);
  $('edit_album_start_date_day').selectedIndex   = Number(s_date.elements[2])-1;
  $('edit_album_start_date_month').selectedIndex = Number(s_date.elements[1])-1;

  $('edit_album_end_date_year').selectedIndex  = String(e_date.elements[0]).substring(3,4);
  $('edit_album_end_date_day').selectedIndex   = Number(e_date.elements[2])-1;
  $('edit_album_end_date_month').selectedIndex = Number(e_date.elements[1])-1;



  if(typeof(ds_albums.current.geolocation[0])!='undefined')
     $('edit_album_lng').value = ds_albums.current.geolocation[0];
  else
    $('edit_album_lng').value='';

  if(typeof(ds_albums.current.geolocation[1])!='undefined')
     $('edit_album_lat').value = ds_albums.current.geolocation[1];
  else 
     $('edit_album_lat').value = '';

  if(ds_albums.current.geolocation[2]=='true')
  {   
     $('edit_album_showonmap').checked = true;
  } else {
     $('edit_album_showonmap').checked =  false;
  }

  if (ds_albums.current.visibility == 1)
  {
    $('album_visibility_all').checked = true;
  }else{
    $('album_visibility_me').checked = true;
  }
  
  if(ds_albums.current.obsolete == 1)
    $('edit_album_obsolete').checked = true;
  else
    $('edit_album_obsolete').checked= false;
    
  gallery.hideAlbums();
}

//------------------------------------------------------------------------------
gallery.edit_album_action = function ()
{
  $('edit_album_name').style.background = "#FFFFFF";
  $('edit_album_lng').style.background = "#FFFFFF";
  $('edit_album_lat').style.background = "#FFFFFF";
  $('edit_album_start_date_year').style.background = "#FFFFFF";
  $('edit_album_start_date_month').style.background = "#FFFFFF";
  $('edit_album_start_date_day').style.background = "#FFFFFF";

  if (document.getElementById('edit_album_name').value == '')
  {
    alert('Please, type album name.');
    document.getElementById('edit_album_name').focus();
    document.getElementById('edit_album_name').style.background = "#FFFF9B";
    return;
  }
  
  geo_regexp = new RegExp('^\\-{0,1}\\d{0,3}\\.\\d{0,6}$');
  if (  $('edit_album_lng').value.length && !geo_regexp.test($('edit_album_lng').value))
  {
    alert('Please, fill in a correct longitude value. [{-}ddd.dddddd]');
    $('edit_album_lng').focus();
    $('edit_album_lng').style.background = "#FFFF9B";
    return;
  }

  if( $('edit_album_lat').value.length && !geo_regexp.test($('edit_album_lat').value)){
    alert('Please, fill in a correct latitude value. [{-}ddd.dddddd]');
    $('edit_album_lat').focus();
    $('edit_album_lat').style.background = "#FFFF9B";
    return;
  }

  if( ($('edit_album_lng').value.length==0 || $('edit_album_lat').value.length==0) && $('edit_album_showonmap').checked )
  {
    alert('Fill in correct Longitude / Latitude coordinates to show album on map.');
    $('edit_album_showonmap').style.background = "#FFFF9B";
    if($('edit_album_lng').value.length==0)
    {
      $('edit_album_lng').focus();
      $('edit_album_lng').style.background = "#FFFF9B";
    }
    else
    {
      $('edit_album_lat').focus();
      $('edit_album_lat').style.background = "#FFFF9B";
    }
    return;
  }

  var startDate = new Date ( $('edit_album_start_date_year').value,$('edit_album_start_date_month').value,$('edit_album_start_date_day').value,0,0,0 );
  var endDate   = new Date ( $('edit_album_end_date_year').value,$('edit_album_end_date_month').value,$('edit_album_end_date_day').value,0,0,0 );
  if(endDate<startDate)
  {
    alert('Start Date should be prior to End Date.');
    $('edit_album_start_date_year').style.background = "#FFFF9B";
    $('edit_album_start_date_month').style.background = "#FFFF9B";
    $('edit_album_start_date_day').style.background = "#FFFF9B";
    return;
  }
  
  //ajax.Start(gallery_edit_album,'');
  if (ds_albums.settings.show_map == 1)
  {
  $('map').className = $('map').className.replace( "edit","view");
  GEvent.removeListener(map.lastGEvent);
  }
  gallery.ajax.edit_album();
}
//------------------------------------------------------------------------------
gallery.link_images_upload_click = function()
{
  gallery.managePanels('image_upload');
  var id = returnIndexFirstChild(gallery.images_upload.childNodes);
  gallery.images_upload.childNodes[id].src=base_path+"upload.vspx?sid="+sid+"&realm=wa&album="+ds_albums.current.name+"&gallery_id="+gallery_id;
}

//------------------------------------------------------------------------------
gallery.images_upload_cancel = function ()
{
  this.images_upload.hide();
  this.images.show();
  gallery.ajax.load_images(ds_albums.current.index);
}

//------------------------------------------------------------------------------
gallery.images_upload_finish = function(id)
{
  gallery.ajax.load_images(ds_albums.current.index);
}

//------------------------------------------------------------------------------
gallery.edit_album_cancel = function ()
{
  if (ds_albums.settings.show_map == 1)
  {
  $('map').className = $('map').className.replace( "edit","view");
  GEvent.removeListener(map.lastGEvent);
  OAT.Dom.hide('map');
  }
  this.images.show();
  this.edit_album.hide();
  }
//------------------------------------------------------------------------------

gallery.setThumbnail= function (i)
{
  elm1=$('setThumb_'+ds_albums.current.thumb_id);
  if(elm1)
  {
    elm1.firstChild.src=base_path + 'i/orb_blank.gif'
    elm1.href='javascript:gallery.setThumbnail('+ds_albums.current.thumb_id+')';  
  }
  
  elm2=$('setThumb_'+i);
  if(elm2)
  {
   elm2.firstChild.src=base_path + 'i/orb_selected.gif'
   elm2.href='javascript:void(0)'
  }
  
  ds_albums.current.thumb_id=i;

  $('album_map_preview_th_'+ds_albums.current.index).src=base_path+'image.vsp?'+setSid()+'image_id='+i+'&size=0';
  $('album_preview_th_'+ds_albums.current.index).src=base_path+'image.vsp?'+setSid()+'image_id='+i+'&size=0';
    
  gallery.ajax.thumbnail_album();  

}
//------------------------------------------------------------------------------
gallery.showImages = function ()
{
  var path  = location.hash.substring(1).split('/');
  if (path.length == 3 && path[2] != '')
  {
    var ind = ds_current_album.checkNameExist(path[2]);
    if (ind > -1)
    {
      eval('gallery.showImage('+ind+')');
    }
    return false;
  }
  gallery.hideAlbums();
  gallery.images_upload.hide();
  gallery.showImagesInside();
}

//------------------------------------------------------------------------------
gallery.showImagesInside = function ()
{
  gallery.managePanels('showImages');

    this.images.clear();
    this.images.show();
    this.image.hide();

    gallery.hideSlideShow();

  var txt = '';
  if (typeof ds_albums.current.description != 'undefined')
  {
    txt = ds_albums.current.description + ' / ';
  }
  txt += ds_current_album.list.length+' pictures';
  $('info_discription').innerHTML = txt;
  $('path_my_albums').innerHTML = 'My Albums > ';
  $('path_pub_date').innerHTML = sdate2obj(ds_albums.current.pub_date).year + ' > ';
  $('path_album_name').innerHTML = OAT.Xml.escape(ds_albums.current.name);
  $('path_image_name').innerHTML = "";
  $('caption').innerHTML = 'Choose an image to view';
  
  gallery.prepare_aplus('info_discription');
  gallery.info.show();

  for(var r=0;r<ds_current_album.list.length;r++)
  {
    new_coll = preview_image(r);
      this.images.appendChild(new_coll);
    }
  if (ds_current_album.list.length == 0)
  {
        block = document.createElement('div');
        block.setAttribute('id','message');
        block.appendChild(document.createTextNode('No images in this album. Click "Add images" to add new'));
        this.images.appendChild(block);
    }

    //Navigation prev<->next album
    var i = ds_albums.current.index;
  $('preview_left').innerHTML = "";
  $('preview_right').innerHTML = "";
  if (i>0)
  {
    $('preview_left').appendChild(preview_album(ds_albums.list[i-1],i-1,'previous'));
    }
  if (i<ds_albums.list.length-1)
  {
    $('preview_right').appendChild(preview_album(ds_albums.list[Number(i)+1],Number(i)+1,'next'));
    }
    path_set_folder(ds_albums.current.name);
}

//------------------------------------------------------------------------------
gallery.showImage = function(i)
{
  var current_image = ds_current_album.list[i];

    gallery.images.hide();
  gallery.hideSlideShow();

    gallery.image.innerHTML = "";
  if (current_image.source)
  {
    src = current_image.source.replace('_t.jpg','.jpg');
  }else{
    src = current_image.path; //ds_current_album.list[i].path;
    src = base_path+'image.vsp?'+setSid()+'image_id='+current_image.id
    path_set_file(current_image.name);
  }

    gallery.image.appendChild(makeImg(src));

    gallery.image.show();
  gallery.image_info.hide();
    gallery.hideAlbums();

  var txt = '';
  if (typeof ds_albums.current.description != 'undefined')
  {
    txt = ds_albums.current.description + ' / ';
  }
  txt += (Number(i)+Number(1)) + ' of '+ ds_current_album.list.length+' pictures';
  $('info_discription').innerHTML = txt;

  $('path_my_albums').innerHTML = 'My Albums > ';
  $('path_pub_date').innerHTML = sdate2obj(ds_albums.current.pub_date).year + ' > ';
  $('path_album_name').innerHTML = OAT.Xml.escape(ds_albums.current.name) + ' > ';
  $('path_image_name').innerHTML = OAT.Xml.escape(current_image.name);
  $('caption').innerHTML = '';
  var rdfa = rdfaValue(OAT.Xml.escape(current_image.description), 'dc:title', 'property');
  if (rdfa)
    $('caption').appendChild(rdfa);
  
  gallery.prepare_aplus('info_discription');
  gallery.managePanels('showImage');
  gallery.hideSlideShow();

    ds_current_album.setCurrent(i);
  gallery.show_exif_flag = 0;
    gallery.show_exif();

    //Navigation previous<->next
  $('preview_left').innerHTML = "";
  $('preview_right').innerHTML = "";
  if (i>0)
  {
    $('preview_left').appendChild(preview_image(i-1,'previous'));
    }
  if (i<ds_current_album.list.length-1)
  {
    $('preview_right').appendChild(preview_image(Number(i)+1,'next'));
    }

    gallery.comments.show();
  gallery.comment_init();
  gallery.showTags();
  gallery.tags_init();

  gallery.ajax.image_get_comments(current_image.id)
}

//------------------------------------------------------------------------------
gallery.showComments = function(comments)
{
  this.comments_list.innerHTML = '';
  if (comments == null)
  {
    return;
  }
  for(var i = 0;i<comments.length;i++)
  {
    gallery.addComment(comments[i]);
  }
}

//------------------------------------------------------------------------------
gallery.addComment = function(comment)
{
  var pub_date = sdate2obj(comment.create_date);
  var comment_block = document.createElement('div');
  var edit = document.createElement('span');
  var user = document.createElement('h3');

	comment_block.setAttribute("id",'comment_'+comment.comment_id);

  var span = document.createElement('span');
  span.innerHTML = comment.text;
	span.setAttribute("id", 'comment_span_'+comment.comment_id);
	span.setAttribute("class", 'comment-msg');
  comment_block.appendChild(span);

  if (gallery.hasAccess())
  {
  var del_img = OAT.Dom.create("img");
  del_img.style.cursor="pointer";
	del_img.setAttribute("src",base_path+ 'i/del_10.png');
	del_img.setAttribute("alt",'Delete');
	del_img.setAttribute("title",'Delete');
  OAT.Event.attach(del_img,'click',gallery.delete_comment_icon_click);


  var edit_img = OAT.Dom.create("img");

  edit_img.style.cursor="pointer";
	edit_img.setAttribute("src",base_path+ 'i/edit_10.png');
	edit_img.setAttribute("alt",'Edit');
	edit_img.setAttribute("title",'Edit');
  OAT.Event.attach(edit_img,'click',gallery.edit_comment_icon_click);
  
    edit.appendChild(document.createTextNode(' '));
  edit.appendChild(del_img);
  edit.appendChild(document.createTextNode(' '));
  edit.appendChild(edit_img);
  }

  var rdfa1 = rdfaValue(comment.user_name, 'comment-user', 'class');
  if (rdfa1)
    user.appendChild(rdfa1);
  //user.appendChild(document.createTextNode(comment.user_name));
  user.appendChild(document.createTextNode(','));
  var rdfa2 = rdfaValue(pub_date.day+'/'+pub_date.month+'/'+pub_date.year, 'comment-date', 'class');
  if (rdfa2)
    user.appendChild(rdfa2);
  //user.appendChild(document.createTextNode(pub_date.day+'/'+pub_date.month+'/'+pub_date.year));
  
  comment_block.appendChild(edit);
  comment_block.appendChild(user);
  
  this.comments_list.appendChild(comment_block);
  gallery.prepare_aplus(span.id);
}

//------------------------------------------------------------------------------
gallery.delete_comment_icon_click = function(e)
{
  if (!e) var e = window.event
  var el = (e.target) ? e.target : e.srcElement

  if (confirm('Are you sure that you want to delete this comment?'))
  {
    var comment = el.parentNode.parentNode.id;
    //dd(el.parentNode.parentNode);
    var comment_id = comment.substring(comment.indexOf('_')+1,comment.length);
    gallery.ajax.image_remove_comment(comment_id);
    gallery.comment_init();
  }
}

//------------------------------------------------------------------------------
gallery.edit_comment_icon_click = function(e)
{
  if (!e) var e = window.event;
  var el = (e.target) ? e.target : e.srcElement;
  var id = el.parentNode.parentNode.id;
  var comment_id = id.substring(id.indexOf('_')+1, id.length)

  call = proxies.SOAP.get_comment;
  prepare = function() {
    return Array(sid, comment_id)
  }
  finish = function(comment) {
    if (comment != null)
    {
      gallery.comment_init(comment_id, comment.text);
    }
  }
  gallery.ajax(prepare, call, finish);
}

//------------------------------------------------------------------------------
gallery.showTags = function()
{
  gallery.tags.show();
  var tags = ds_current_album.current.private_tags
  var tags_list = $('tags_list')
  tags_list.innerHTML = '';

  if (tags == null)
  {
    return;
  }
  for(var i = 0; i<tags.length; i++)
  {
    gallery.addTag(tags[i]);
  }
  if (gallery.hasAccess())
  {
    OAT.Dom.show('tags_edit');
  }
  gallery.prepare_aplus('tags_list');
}

//------------------------------------------------------------------------------
gallery.addTag = function(tag, first)
{
  var tags_list = $('tags_list')
  document.f1.new_tag.value = '';

  var div = document.createElement('span');
  //var txt = document.createElement('b');

  if (tags_list.childNodes.length)
  {
    div.appendChild(document.createTextNode(', '));
  }else{
    div.appendChild(document.createTextNode(' '));
  }
  tags_list.appendChild(div);
  //div.appendChild(txt);
  var rdfa = rdfaValue(tag, 'dc:subject', 'property');
  if (rdfa)
    div.appendChild(rdfa);

  div.appendChild(makeDummyHref(tag));

  if (gallery.hasAccess())
  {
    var edit = document.createElement('span');
  div.appendChild(edit);

  var img = OAT.Dom.create("img");
  img.style.cursor="pointer";
	img.setAttribute("src",base_path+ 'i/del_10.png');
	img.setAttribute("alt",'Delete');
	img.setAttribute("title",'Delete');

    edit.appendChild(document.createTextNode(' '));
  edit.appendChild(img);
  }
  //txt.appendChild(document.createTextNode(tag));
  OAT.Event.attach(edit,'click',gallery.delete_tag_click)
  }

//------------------------------------------------------------------------------
gallery.delete_tag_click = function(e)
{
  if (!e) var e = window.event
  var el = (e.target) ? e.target : e.srcElement

  if (confirm('Are you sure that you want to delete this tag?'))
  {
    var tag = el.parentNode.parentNode.childNodes[1].innerHTML;
   gallery.ajax.image_remove_tags(ds_current_album.current.id,tag);
  }
}

//------------------------------------------------------------------------------
gallery.tags_is_unique = function (tags, tag)
{
  if (tags == null)
  {
    return 1;
  }
  for (var i=0; i < tags.length; i++)
  {
    if (tags[i] == tag)
    {
      return 0;
    }
  }
  return 1;
}

//------------------------------------------------------------------------------
gallery.tag_images_tab_click = function()
{
  if (gallery.images.visible == 0)
  {
    return;
  }
  var ids = new Array();
  for(var i=0;i<ds_current_album.list.length;i++)
  {
    if (document.getElementById('image_id_'+i).checked)
    {
      ids[ids.length]= document.getElementById('image_id_'+i).value;
    }
}
  if (ids.length == 0)
  {
    alert('Please, first select one or more pictures.');
    return;
  }
  tags = prompt('Insert public tags here','Tags');
  gallery.ajax.tag_images(ids,tags);
}

//------------------------------------------------------------------------------
gallery.tag_images_tab_finish = function()
{}

//------------------------------------------------------------------------------
gallery.bnt_new_tag_cancel_click = function()
{
  gallery.tags_init();
  }

//------------------------------------------------------------------------------
gallery.bnt_new_tag_click = function()
{
  var tagsValue = document.f1.new_tag.value;

  tagsValue = tagsValue.replace('\n', ' ', 'gi');
  tagsValue = tagsValue.replace('\r', ' ', 'gi');
  tagsValue = tagsValue.replace('\v', ' ', 'gi');
  tagsValue = tagsValue.replace('\t', ' ', 'gi');
  tagsValue = tagsValue.replace('\f', ' ', 'gi');
	tagsValue = tagsValue.replace("  ", " ", "gi");
	tagsValue = tagsValue.trim();
  document.f1.new_tag.value = tagsValue;
  tagsArray = tagsValue.split(",");
  for (i=0; i<tagsArray.length; i++)
  {
    var tag = tagsArray[i].trim();
    if ((tag.length < 2) || (tag.length > 50))
    {
      alert('Tag "'+tag+'" must contain from 2 to 50 characters. Please, remove or change it.');
    return;
  }
    var re = new RegExp('^([a-zA-Z_])+([a-zA-Z0-9_\x20])*\$', 'gi');
    if (!tag.match(re))
    {
      alert('Please, fill in a correct value for tag "'+tag+'".');
      return;
    }
    if (!gallery.tags_is_unique (ds_current_album.current.private_tags, tag))
    {
      alert('Tag "'+tag+'" already exists. Please, remove or change it.');
    return;
  }
}
  gallery.ajax.image_add_tags (ds_current_album.current.id, tagsValue);
}

//------------------------------------------------------------------------------
gallery.showAlbumsInfo = function(i)
{
  //if (gallery.is_own == 1){
    $('path_my_albums').innerHTML = 'My Albums';
  //}else{
  //  $('path_my_albums').innerHTML = ds_albums.current.owner_name +'\'s albums';
  //}
  $('path_pub_date').innerHTML = "";
  $('path_album_name').innerHTML = "";
  $('path_image_name').innerHTML = "";
  $('info_discription').innerHTML = "";
  $('caption').innerHTML = 'Choose an album to view';
  $('preview_left').innerHTML = "";
  $('preview_right').innerHTML = "";
//  OAT.Dom.show('filter');
  var filter_type_options=["N/A","Year","..."];
//  var elm=$('filter_type');
//  OAT.QuickEdit.assign(elm, OAT.QuickEdit.SELECT, filter_type_options); 

  if(!$('filter_type'))
  {
    var filter_type_ctrl = OAT.Dom.create("span");
    filter_type_ctrl.setAttribute("id","filter_type");
    filter_type_ctrl.innerHTML = "N/A";
    filter_type_ctrl.className='qe';
    OAT.QuickEdit.assign(filter_type_ctrl, OAT.QuickEdit.SELECT, filter_type_options);
    
    $('filter').appendChild(filter_type_ctrl);  
  }
  // preview_albums('info_discription');
  gallery.prepare_aplus('info_discription');
  gallery.info.show();
}

//------------------------------------------------------------------------------
gallery.path_my_albums_click = function()
{
  gallery.my_albums_tab_click();
}

//------------------------------------------------------------------------------
gallery.path_album_name_click = function()
{
  gallery.link_show_images_click();
}

//------------------------------------------------------------------------------
gallery.link_show_images_click = function()
{
  path_set_folder(ds_albums.current.name);
  gallery.showImages();
}
//------------------------------------------------------------------------------
gallery.btn_slideshow_click = function()
{
  gallery.image_info.hide();
  OAT.Dom.hide('link_show_exif');
  gallery.managePanels('images_slideshow');
  $('caption').innerHTML = 'Slideshow';
  $('preview_left').innerHTML = "";
  $('preview_right').innerHTML = "";

  if (ds_current_album.list.length < 2)
  {
    gallery.showImages();
    return;
  }

  this.slideshow.show();

	for (var i=0;i<ds_current_album.list.length;i++)
	{
		var elm = OAT.Dom.create("div",{position:"relative",width:"490px",height:"400px",cssFloat:"left",styleFloat:"left"});
		var img = OAT.Dom.create("img");
		img.setAttribute("src",base_path+'image.vsp?'+setSid()+'image_id='+ds_current_album.list[i].id);
		elm.appendChild(img);
		$("rotator").appendChild(elm);
    gallery.rotator.addPanel(elm);
  }

  gallery.slideshow_status_update();
  return;
}

//------------------------------------------------------------------------------
gallery.hideSlideShow = function()
{
  if (gallery.rotator)
  {
    gallery.rotator.stop();
  }
  gallery.slideshow.hide();
}

//------------------------------------------------------------------------------
gallery.slideshow_status_update = function()
{
  if (this.rotator.running)
  {
    $('label_slideshow_status').innerHTML = "Play with interval of "+(this.rotator.options.pause/1000)+" seconds";
  }else{
    $('label_slideshow_status').innerHTML = "Show is stopped";
  }
}

//------------------------------------------------------------------------------
gallery.btn_slideshow_faster_click = function()
{
  if (pause > 1000)
  {
    pause -= 1000;
  }
  gallery.statusSlideShow();
}

//------------------------------------------------------------------------------
gallery.btn_slideshow_slower_click = function()
{
  pause += 1000;
  gallery.statusSlideShow();
}

//------------------------------------------------------------------------------
gallery.hideAlbums = function()
{
  gallery.albums.hide();
  gallery.albums_list.hide();
  gallery.albums_man.hide();
}

//------------------------------------------------------------------------------
gallery.my_albums_tab_click = function ()
{
  path_set_folder('');
  gallery.managePanels('my_albums');
  gallery.show_albums_page_navigation();
  gallery.nav.tabs(1);
}

//------------------------------------------------------------------------------
gallery.wa_click = function ()
{
  location.href = wa_home_link + 'services.vspx?sid='+sid+'&realm=wa';
}

//------------------------------------------------------------------------------
gallery.home_click = function ()
{
  location.href = page_location;
  setTimeout(100,function(){location.reload();})
}

//------------------------------------------------------------------------------
gallery.link_show_exif_click = function()
{
  if (gallery.show_exif_flag == 0)
  {
    gallery.show_exif_flag = 1;
    gallery.show_exif();
    return false;
  }else{
    gallery.show_exif_flag = 0;
    gallery.image_info.hide();
  }
}

//------------------------------------------------------------------------------
gallery.show_exif = function(){
  gallery.image_edit.hide();
  if (gallery.show_exif_flag == 1)
  {
    gallery.hideSlideShow();
    gallery.image_info.show();
    gallery.image_info.innerHTML = 'Loading ...';

    gallery.ajax.image_get_exif(ds_current_album.current.id);
  }
}

//------------------------------------------------------------------------------
gallery.link_image_edit_click = function()
{
  gallery.image_info.hide();
  gallery.image_edit.show();

  document.f1.edit_image_description.value = ds_current_album.current.description;
  document.f1.edit_image_name.value = ds_current_album.current.name;
  document.f1.edit_image_name_old.value = ds_current_album.current.name;
  document.f1.edit_image_path.value = ds_albums.current.fullpath;

  if (ds_current_album.current.visibility == 1)
  {
    document.f1.image_visibility[0].checked = true
  }else{
    document.f1.image_visibility[1].checked = true;
  }
}

//------------------------------------------------------------------------------
gallery.btn_image_edit_click = function()
{
  gallery.ajax.image_edit();
}

//------------------------------------------------------------------------------
gallery.image_edit_finish = function(res)
{}

//------------------------------------------------------------------------------
gallery.btn_image_edit_cancel_click = function()
{
  gallery.image_edit.hide();
}

//------------------------------------------------------------------------------
gallery.link_delete_images_click = function()
{
  if (gallery.images.visible == 0)
  {
    return;
  }
  var ids = new Array();
  for(var i=0;i<ds_current_album.list.length;i++)
  {
    if (document.getElementById('image_id_'+i).checked)
    {
      ids[ids.length]= document.getElementById('image_id_'+i).value;
    }
  }
  if (ids.length == 0)
  {
    alert('Please, first select one or more pictures');
    return;
  }
  if (!confirm('Are you sure that you want to delete selected images?'))
  {
    return;
  }
  gallery.ajax.delete_images(ids);
}

//------------------------------------------------------------------------------
gallery.link_delete_image_click = function()
{
  if (!confirm('Are you sure that you want to delete selected images?'))
  {
    return;
  }
  gallery.ajax.delete_images(Array(ds_current_album.current.id));
}

//------------------------------------------------------------------------------
gallery.link_delete_album_click = function()
{
  if (!confirm('Are you sure that you want to delete current Album?'))
  {
    return;
  }
  if (ds_albums.settings.show_map==1)
  removeAlbumMarker();
  gallery.ajax.delete_album(ds_albums.current.id);
}

//------------------------------------------------------------------------------
gallery.tags_init = function ()
{
  $('new_tag').value = '';
}

//------------------------------------------------------------------------------
gallery.comment_init = function (comment_id, comment_text)
{
  var rte = 'comment2';
  gallery.comment_id = comment_id;
  if ($("chkSrc" + rte).checked)
  {
    $("chkSrc" + rte).checked = false;
    toggleHTMLSrc(rte, true);
  }
  if (comment_id)
  {
    oEditor.setData(comment_text);
    // enableDesignMode(rte, comment_text, false);
    $('comment_header').innerHTML = 'Edit Comment';
  } else {
    oEditor.setData('');
    // enableDesignMode(rte, '', false);
    $('comment_header').innerHTML = 'New Comment';
  }
}

//------------------------------------------------------------------------------
gallery.comment_save_click = function()
{
  oEditor.updateElement();
  var rte = 'comment2';
  var obj = document.f1.elements[rte];
  if (!(obj.value) || (obj.value == ''))
  {
    alert('Please, insert at least one word for a comment!');
    return;
  }
  if (!gallery.comment_id)
  {
    var comment_text     = obj.value;
    var comment_image_id = ds_current_album.current.id;

    gallery.ajax.image_add_comment(comment_image_id, comment_text);
  } else {
    var comment_text = obj.value;
    var comment_id   = gallery.comment_id;

    gallery.ajax.image_update_comment (comment_id, comment_text);
  }
  gallery.comment_init();
}

//------------------------------------------------------------------------------
gallery.comment_cancel_click = function()
{
  gallery.comment_init();
}

//------------------------------------------------------------------------------
gallery.get_image = function(id)
{
  gallery.ajax.load_images(ds_albums.current.index);
}

//------------------------------------------------------------------------------
gallery.showError = function (ex)
{
    var s = '<img src="/photos/res/i/close-24.gif" class="close_button" title="Close this panel" OnClick="gallery.error_box.hide()" />';

  if (ex.constructor == String)
  {
    s = ex;
  } else {
    if ((ex.name != null) && (ex.name != ""))
      s += "Type: " + ex.name + "<br>";

    if ((ex.message != null) && (ex.message != ""))
      s += "Message:\n" + ex.message + "<br>";

    if ((ex.description != null) && (ex.description != "") && (ex.message != ex.description))
      s += "Description:\n" + ex.description + "<br>";
  }
  box = document.createElement('div');
  box.innerHTML = s ;
  gallery.error_box.clear();
  gallery.error_box.show();
  gallery.error_box.appendChild(box);
  hideWait();
}

//------------------------------------------------------------------------------
function showPreviewNav()
{
  div = document.createElement('div');
  div.setAttribute('id','preview_nav');
  return div;
}

//------------------------------------------------------------------------------
function preview_collection(album,i)
{
  var div = document.createElement('div')
  if(album.obsolete==1)
     div.className='album_obsolete';
  else
     div.className='album';
  
  var ramka = document.createElement('span')
  div.setAttribute('id','album_preview_'+i);
  div.setAttribute('path', OAT.Xml.escape (album.name));
  //ramka .setAttribute('id','album_preview_r_'+i);

  if(album.thumb_id){
    src = base_path+'image.vsp?'+setSid()+'image_id='+album.thumb_id+'&size=0';
    thumb = makeImg(src);
    thumb.setAttribute('id','album_preview_th_'+i);
    ramka.appendChild(document.createElement('br'))
    ramka.appendChild(thumb);
  }else{
    ramka.appendChild(document.createElement('br'));
    ramka.appendChild(document.createElement('br'));
    ramka.appendChild(document.createElement('br'));
  }
  div.appendChild(ramka);
  div.appendChild(document.createElement('br'))
  div.appendChild(document.createTextNode('Album:# '+ Number(i+1)))
  div.appendChild(document.createElement('br'))

  if (album.name)
  {
    var rdfa = rdfaValue(OAT.Xml.escape(album.name.substring(0,12)), 'dc:title', 'property');
    if (rdfa)
      div.appendChild(rdfa);
    //div.appendChild(document.createTextNode(album.name.substring(0,12)));
  }
  return div;
}

//------------------------------------------------------------------------------
function preview_collection_4_map(album,i){

  var div = OAT.Dom.create("div");
  div.setAttribute('id','album_map_preview_'+i);
  div.setAttribute('path',album.name);


  var table = OAT.Dom.create("table",{padding:'0px 7px 5px 0px'});
  var tbody = OAT.Dom.create("tbody");

  var td_img = OAT.Dom.create("td",{verticalAlign:"middle",textAlign:"center"});
  var img_a = OAT.Dom.create("a");
  img_a.href = "#/"+album.name+'/';
  if(album.thumb_id){
    src = base_path+'image.vsp?'+setSid()+'image_id='+album.thumb_id+'&size=0';
  }else
    src = '';
  
  thumb = makeImg(src);
  thumb.setAttribute('id','album_map_preview_th_'+i);
  OAT.Event.attach(thumb,"click",function(){
                                       OAT.Dom.hide('timeline');
                                       OAT.Dom.hide('map');
                                       current_id = i;
                                       gallery.setCurrent(current_id);
                                       gallery.ajax.load_images(current_id);
                                      
                                      });

  img_a.appendChild(thumb);
  td_img.appendChild(img_a);
  
  var tr = OAT.Dom.create("tr");
  var item = OAT.Dom.create("td");
  var a = OAT.Dom.create("a");

  if(album.name){
    a.innerHTML = OAT.Xml.escape(album.name.substring(0,12))+" ("+sdate2obj(album.start_date).year +'/'+sdate2obj(album.start_date).month+")";
    a.href = "#/"+album.name+'/';
    OAT.Event.attach(a,"click",function(){
                                         OAT.Dom.hide('timeline');
                                         OAT.Dom.hide('map');
                                         current_id = i;
                                         gallery.setCurrent(current_id);
                                         gallery.ajax.load_images(current_id);
                                        
                                        });
  }
  
  OAT.Dom.append([item,a],[tr,item],[tbody,tr]);
  tr.appendChild(td_img);
  OAT.Dom.append([table,tbody]);

  div.appendChild(table);
  return div;
}

//------------------------------------------------------------------------------
function preview_album (album,i,mode)
{
  src = base_path + 'i/no_image.gif';
  var div = OAT.Dom.create('div');
  div.appendChild(document.createTextNode(mode+' album'))
  div.appendChild(document.createElement('br'))

  if (mode == 'previous')
  {
    div.appendChild(makeHref('javascript:gallery.ajax.load_images("'+i+'")',makeImg(base_path + 'i/frew.gif',12,12,'move_button')))
  }
  div.appendChild(makeHref('javascript:gallery.ajax.load_images('+i+');',document.createTextNode(album.name)))
  if (mode == 'next')
  {
    div.appendChild(makeHref('javascript:gallery.ajax.load_images("'+i+'")',makeImg(base_path + 'i/ffwd.gif',12,12,'move_button')))
  }
  return div;
}

//------------------------------------------------------------------------------
function preview_image(i,mode){
  var current_image = ds_current_album.list[i];

  src = current_image.fullpath;
  if (current_image.source)
  {
    src = current_image.source;
  }else{
  src = base_path+'image.vsp?'+setSid()+'image_id='+current_image.id+'&size=0';
  }
  if (current_image.visibility == 1)
  {
    var alt = current_image.name + '\r\n Public visible';
  }else{
    var alt = 'Private visible';
  }

  var div = OAT.Dom.create('div');
  div.id='imageCaptionContainer';
  
  var imageDiv = OAT.Dom.create('div');
  //div.appendChild(makeHref('javascript:gallery.showImage("'+i+'")',makeImg(src,'','','img',alt)))
  image_html = makeImg(src,'','','img',alt);
  imageDiv.appendChild(image_html);
  OAT.Event.attach(image_html,'click',function(){
    gallery.showImage(i);
  })
  imageDiv.current_image = current_image;

  if (mode == 'previous')
  {
    imageDiv.appendChild(makeHref('javascript:gallery.showImage("'+i+'")',makeImg(base_path + 'i/frew.gif',12,12,'move_button')))
  }

  if (mode == 'next')
  {
    imageDiv.appendChild(makeHref('javascript:gallery.showImage("'+i+'")',makeImg(base_path + 'i/ffwd.gif',12,12,'move_button')))
  }

  if (mode != 'previous' && mode != 'next')
  {
    chbox = makeCheckbox('image_id_'+i,current_image.id);
    imageDiv.appendChild(document.createElement('br'));
    
   var ctrlDiv=OAT.Dom.create('div');
   ctrlDiv.setAttribute('id','images_ctrl');

    if (gallery.hasAccess())
    {
      ctrlDiv.appendChild(chbox);
      
      thumbCtrl = makeHref('javascript:gallery.setThumbnail('+current_image.id+')',makeImg(base_path + 'i/orb_blank.gif',13,13,'setthumb_button'));
      if(current_image.id==ds_albums.current.thumb_id)
         thumbCtrl = makeHref('javascript:void(0)',makeImg(base_path + 'i/orb_selected.gif',13,13,'setthumb_button'));

      thumbCtrl.setAttribute('id','setThumb_'+current_image.id);
      ctrlDiv.appendChild(thumbCtrl);
    }
    
    imageDiv.appendChild(ctrlDiv)

    var caption ='';
    if(typeof(current_image.description)!='undefined')
    {
       caption=current_image.description;
       if(caption.length>35)
          caption= caption.substr(0,33)+'...';
}
    
    div.appendChild(imageDiv);
    var rdfa = rdfaValue(caption, 'dc:title', 'property');
    if (rdfa)
      div.appendChild(rdfa);

  return div;
  }

  return imageDiv;
}

//-------------------------------------------------------------------------------
function rdfaValue(val, property, property_name)
{
  if (!val || val=='')
    return null;
  var rdfaSpan = OAT.Dom.create("span");
  rdfaSpan.innerHTML = val;
  rdfaSpan.setAttribute(property_name,property);

  return rdfaSpan;
}

//------------------------------------------------------------------------------
function showWait()
{
    var portSize  =OAT.Dom.getViewport();
    var scrollSize =OAT.Dom.getScroll()

    $('wait').style.left = (scrollSize[0]+portSize[0]/2-63)+'px';
    $('wait').style.top  = (scrollSize[1]+portSize[1]/2-30)+'px';

    OAT.Dom.show('wait');
}

//------------------------------------------------------------------------------

function hideWait()
{
    OAT.Dom.hide('wait');
}

//------------------------------------------------------------------------------
gallery.feed_rss_click = function()
{
  feed_url('rss.xml');
}

//------------------------------------------------------------------------------
gallery.feed_rdf_click = function()
{
  feed_url('index.rdf');
}

//------------------------------------------------------------------------------
gallery.feed_atom_click = function()
{
  feed_url('atom.xml');
}

//------------------------------------------------------------------------------
gallery.feed_xbel_click = function(){
  feed_url('xbel.xml');
}

//------------------------------------------------------------------------------
gallery.feed_mrss_click = function(){
  feed_url('mrss.xml');
}

//------------------------------------------------------------------------------
gallery.feed_siocxml_click = function()
{
  feed_dataspace_url('sioc.rdf');
}

//------------------------------------------------------------------------------
gallery.feed_siocn3turtle_click = function()
{
  feed_dataspace_url('sioc.ttl');
}

//------------------------------------------------------------------------------

feed_dataspace_url = function(type)
{
  window.open('http://'+document.location.host+'/dataspace/'+gallery.owner_name+'/photos/'+gallery_inst_name+'/'+type);
}

//------------------------------------------------------------------------------
feed_url = function(type)
{
  var base_url;
  if(page_location.indexOf('?') > -1){
    base_url = page_location.substring(0,page_location.indexOf('?'));
  }else if(page_location.indexOf('#') > -1){
    base_url = page_location.substring(0,page_location.indexOf('#'));
  }else{
    base_url = page_location;
  }

  base_url= base_url.substr(base_url.length-1)=='/' ? base_url : base_url+'/';

  if (ds_albums.current.name != null)
  {
    current_album = '?'+ds_albums.current.name;
  }else{
    current_album = '';
  }

//  dd(base_url + type + current_album);
  location.href =  base_url + type + current_album;
}

//------------------------------------------------------------------------------
gallery.link_images_import_click = function()
{
  gallery.managePanels('images_import');
  if (gallery.flickr.status == 'logged')
  {
    OAT.Dom.addClass('images_import_flickr','link_disabled');
    OAT.Dom.removeClass('images_import_flickr','link');

    OAT.Dom.addClass('images_import_flickr_save','link_disabled');
    OAT.Dom.removeClass('images_import_flickr_save','link');

    OAT.Dom.addClass('images_import_flickr_list','link');
    OAT.Dom.removeClass('images_import_flickr_list','link_disabled');
  }
  $('info_discription').innerHTML = "";
  $('path_my_albums').innerHTML = 'My Albums > ';
  $('path_pub_date').innerHTML = sdate2obj(ds_albums.current.pub_date).year + ' > ';
  $('path_album_name').innerHTML = OAT.Xml.escape(ds_albums.current.name);
  $('path_image_name').innerHTML = "";
  $('caption').innerHTML = 'Import images from Flickr';
  $('preview_left').innerHTML = "";
  $('preview_right').innerHTML = "";

}

//------------------------------------------------------------------------------
gallery.link_images_export_click = function()
{
  gallery.managePanels('images_export');
  $('info_discription').innerHTML = "";
  $('path_my_albums').innerHTML = 'My Albums > ';
  $('path_pub_date').innerHTML = sdate2obj(ds_albums.current.pub_date).year + ' > ';
  $('path_album_name').innerHTML = OAT.Xml.escape(ds_albums.current.name);
  $('path_image_name').innerHTML = "";
  $('caption').innerHTML = 'Export images to Flickr';
  $('preview_left').innerHTML = "";
  $('preview_right').innerHTML = "";

}

//------------------------------------------------------------------------------
gallery.prepare_aplus = function(panel)
{
	if (aplus == 0)
	  return;
	OAT.Preferences.imagePath = '/ods/images/oat/';
  OAT.Anchor.imagePath = OAT.Preferences.imagePath;
  OAT.Anchor.zIndex = 1001;
  var e = $(panel);                                          
  if (e)                                                          
  {                                                               
    var appLinks = e.getElementsByTagName("a");                   
    for (var i = 0; i < appLinks.length; i++)                     
    {                                                             
      var app = appLinks[i];                                      
      var search;                                                 
      if (!app.id)                                                
      {                                                           
        if ((app.childNodes.length == 1) && (app.childNodes[0].tagName == "IMG")) 
        {                                                         
    	     search = app.childNodes[0].getAttribute("alt");         
        }                                                         
        else                                                      
        {                                                         
   	      search = app.innerHTML;                                 
        }                                                         
        if (search && (search.length > 1))                        
          app.id = 'aplus_' +getAplusId();                                   
	    }                                                           
	  }                                                             
  generateAPP(panel, {title:"Related links", appActivation: aplus==1?'click':'hover'});
//generateAPP("content", {title:"Related links", appActivation: "%s", useRDFB: %s});     
	}                                                                 
}

//------------------------------------------------------------------------------
gallery.managePanels = function(action)
{
  OAT.Dom.hide('images_import');
  OAT.Dom.hide('images_export');
  OAT.Dom.hide('filter');

  gallery.closePanels();

  if (action == 'my_albums')
  {
    if(ds_albums.settings.show_timeline==1)
    {
    OAT.Dom.show('timeline');
        if(TL.last)
           TL.scrollTo(TL.last);
    } else {
       OAT.Dom.hide('timeline');
    }
    if(ds_albums.settings.show_map==1)
    {
       if(map)
      {
          map.show();
      } else {
        if (typeof(window.mapInitPrepare) == "function")
        {
          mapInitPrepare();
        }
        OAT.Dom.show('map')
      }
    } else {
       OAT.Dom.hide('map');
    }
    if ((ds_albums.settings.show_map == 1) && (typeof(map) != 'undefined'))
    {
       $('map').className = $('map').className.replace( "edit","view");
       if(typeof(map.lastGEvent)!='undefined')
      {
         GEvent.removeListener(map.lastGEvent);
    }
    }
    
    gallery.albums.show();
    gallery.showAlbumsInfo();
    gallery.albums_list.show();
    gallery.albums.tabs(1);
    if (gallery.hasAccess())
    {
      gallery.albums_man.show();
      OAT.Dom.show('new_album_tab');
    } else {
    OAT.Dom.hide('new_album_tab');
    }
      
    gallery.images_upload.hide();
    gallery.new_album.hide();
    gallery.error_box.clear();
    gallery.images.hide();
    gallery.image.hide();
    gallery.hideSlideShow();
    gallery.comments.hide();
    gallery.tags.hide();
    gallery.image_info.hide();
    OAT.Dom.hide('care_edit_album');
    OAT.Dom.hide('care_view_album');
    OAT.Dom.hide('image_edit');
    OAT.Dom.hide('care_slideshow');

  }else if(action == 'showImages'){
    if (gallery.hasAccess())
    {
      OAT.Dom.show('care_edit_album');
    }
    OAT.Dom.show('care_view_album');
    OAT.Dom.hide('care_view_mode');
    OAT.Dom.hide('care_nav_image');
      OAT.Dom.hide('care_edit_image');
    OAT.Dom.hide('care_slideshow');
      gallery.comments.hide();
    gallery.tags.hide();
      gallery.image_info.hide();

  }else if(action == 'showImage'){
      OAT.Dom.hide('care_edit_album');
    OAT.Dom.show('care_nav_image');
    if (gallery.hasAccess())
    {
      OAT.Dom.show('care_edit_image');
    }
      OAT.Dom.show('care_view_mode');
    OAT.Dom.show('link_show_exif');
    OAT.Dom.hide('care_view_album');
    OAT.Dom.hide('care_slideshow');

  }else if(action == 'images_import'){
    OAT.Dom.show('images_import');
    OAT.Dom.show('images_import');
    OAT.Dom.hide('images');
    OAT.Dom.hide('edit_album');
    OAT.Dom.hide('images_upload');
    OAT.Dom.hide('images_export');

  }else if(action == 'images_export'){
    OAT.Dom.show('images_export');
    OAT.Dom.show('images');

  }else if(action == 'edit_album'){
      OAT.Dom.show('edit_album');
      OAT.Dom.hide('images');
    if(ds_albums.settings.show_map==1)
    {
    OAT.Dom.show('map');
    }
    OAT.Dom.hide('images_upload');

  }else if(action == 'new_album'){
    this.hideAlbums();
    this.images.hide();
    this.image.hide();
    this.info.hide();
    this.error_box.hide();
    this.slideshow.hide();
    this.new_album.hide();
    this.edit_album.hide();
    this.images_upload.hide();
    this.image_info.hide();
    this.comments.hide();
    this.tags.hide();

    OAT.Dom.hide('care_edit_album');
    OAT.Dom.hide('care_view_album');
    OAT.Dom.show('care_my_albums');
    OAT.Dom.hide('care_slideshow');

    OAT.Dom.show('new_album');

  }else if(action == 'image_upload'){
    OAT.Dom.show('images_upload');
    OAT.Dom.hide('edit_album');
    gallery.images.hide();

  }else if(action == 'images_slideshow'){
    OAT.Dom.show('care_nav_image');
    OAT.Dom.hide('care_view_album');
    OAT.Dom.hide('care_edit_image');
    gallery.images.hide();
    gallery.image.hide();
    gallery.tags.hide();

    this.images_upload.hide();
    this.edit_album.hide();
    //this.info.hide();
    this.comments.hide();
    OAT.Dom.show('care_slideshow');

  } else if (action=='edit_albumsettings') {
    this.hideAlbums();
    this.images.hide();
    this.image.hide();
    this.info.hide();
    this.new_album.hide();
    this.edit_album.hide();
    this.tags.hide();
    this.comments.hide();

    OAT.Dom.hide('care_edit_album');
    OAT.Dom.hide('care_my_albums');
    OAT.Dom.hide('care_view_album');
    OAT.Dom.hide('image_edit');
    OAT.Dom.hide('care_edit_image');
    OAT.Dom.hide('care_slideshow');

    OAT.Dom.show('edit_album_settings');
  }
}


//------------------------------------------------------------------------------
gallery.ajax = function(p_prepare,p_call,p_finish){
  var obj = {
        delay: 200,
        prepare: p_prepare,
        call: p_call,
        finish: p_finish,
        onException: gallery.showError
      }
  ajax.Start(obj);
}

//------------------------------------------------------------------------------
gallery.ajax.load_settings = function()
{
  call = proxies.SOAP.load_settings;
  prepare = function(){
    return Array(sid, gallery_id);
  }
  finish = function(p){
    var settings={};
    if (p.length)
    {
      for(var i=0; i<p.length; i=i+2)
      {
        settings[p[i]] = p[i+1];
      }
    }
    settings['albums_page'] = 1;
    ds_albums.settings=settings;
  }
  gallery.ajax(prepare, call, finish);
}

//------------------------------------------------------------------------------
gallery.ajax.load_albums = function(path)
{
  call = proxies.SOAP.dav_browse;
  prepare = function() {
    return Array(sid, gallery_id, path);
  }
  finish = function(p) {
    ds_albums.loadList(p.albums);
    gallery.is_own = p.is_own;
    gallery.owner_name = p.owner_name;

    if (!jump_to())
    {
       gallery.hideAlbums();
    }
    gallery.show_albums_list();
    gallery.show_albums_page();
    gallery.managePanels ('my_albums');
    gallery.show_albums_page_navigation();
    $('myAlbumsTxt').innerHTML='My Albums ('+ds_albums.list.length+')';
    TL.draw();
  }
  gallery.ajax(prepare, call, finish);
}
    
//------------------------------------------------------------------------------
gallery.show_albums_list = function()
{
  $('my_albums_list').innerHTML="";
    
    for (var r=0; r<ds_albums.list.length; r++)
    {
      album_list = OAT.Dom.create('li');

      var rdfa = rdfaValue(OAT.Xml.escape(ds_albums.list[r].name.substring(0,12)), 'dc:title', 'property');
      if (rdfa)
    {
        album_list.appendChild(rdfa);
    }
      //album_list.innerHTML = ds_albums.list[r].name.substring(0,12);
      album_list.id = "my_albums_list_"+r;
      album_list.appendChild(makeDummyHref(OAT.Xml.escape(ds_albums.list[r].name.substring(0,12))));

      $('my_albums_list').appendChild(album_list);
    }
    gallery.prepare_aplus('my_albums_list');
}
    
gallery.show_albums_page = function()
{
  gallery.albums.innerHTML="";

  var pageSize = parseInt(ds_albums.settings.albums_per_page, 10);
  var albums = ds_albums.list.length;
  var pages = parseInt(albums / pageSize);
  if (albums != 0)
  {
    if (albums % pageSize != 0)
    {
      pages++;
  }
  }
  ds_albums.settings.albums_page = Math.min(ds_albums.settings.albums_page, pages);
  ds_albums.settings.albums_page = Math.max(ds_albums.settings.albums_page, 1);
  var currentPage = ds_albums.settings.albums_page;
  for (var r=(currentPage-1)*pageSize; r<Math.min(albums,currentPage*pageSize); r++)
  {
    new_coll = preview_collection(ds_albums.list[r], r);
    gallery.albums.appendChild(new_coll);
  }
  gallery.show_albums_page_navigation();
}

gallery.show_albums_page_navigation = function()
{
  var pageSize = parseInt(ds_albums.settings.albums_per_page, 10);
  var albums = ds_albums.list.length;
  var pages = parseInt(albums / pageSize);
  if (albums != 0)
  {
    if (albums % pageSize != 0)
    {
      pages++;
    }
  }
  ds_albums.settings.albums_page = Math.min(ds_albums.settings.albums_page, pages);
  ds_albums.settings.albums_page = Math.max(ds_albums.settings.albums_page, 1);

  var currentPage = ds_albums.settings.albums_page;

  $('preview_left').innerHTML = "";
  var textNode = OAT.Dom.create('div');
  textNode.appendChild(OAT.Dom.text(' Previous Page'));
  textNode.appendChild(OAT.Dom.create('br'));
  textNode.appendChild(makeImg(base_path+"i/frew.gif", 12, 12));
  if (ds_albums.settings.albums_page != 1)
  {
    $('preview_left').appendChild(makeHref('javascript: gallery.show_page('+(currentPage-1)+');', textNode));
  } else {
    $('preview_left').appendChild(document.createTextNode(' '));
  }

  $('preview_right').innerHTML = "";
  var textNode = OAT.Dom.create('div');
  textNode.appendChild(OAT.Dom.text(' Next Page'));
  textNode.appendChild(OAT.Dom.create('br'));
  textNode.appendChild(makeImg(base_path+"i/ffwd.gif", 12, 12));
  if (ds_albums.settings.albums_page != pages)
  {
    $('preview_right').appendChild(makeHref('javascript: gallery.show_page('+(currentPage+1)+');', textNode));
  } else {
    $('preview_right').appendChild(document.createTextNode(' '));
  }
}

//------------------------------------------------------------------------------
gallery.show_page = function(pageNumber)
{
  ds_albums.settings.albums_page = pageNumber;
  gallery.show_albums_page();
}

//------------------------------------------------------------------------------
gallery.my_albums_list_click = function(el)
{
  if (el.id.indexOf ("my_albums_list") != 0)
    return;
  gallery.albums_click(el);
}

//------------------------------------------------------------------------------
gallery.my_albums_list_more_click = function()
{
  gallery.home_click();
}

//------------------------------------------------------------------------------
gallery.ajax.new_album = function()
{
  call = proxies.SOAP.create_new_album;
  prepare =function() {
    if (document.f1.visibility[0].checked)
    {
              v=1
            }else{
              v=0
            };

            return Array(sid,gallery_id,
                         home_path,
                         document.getElementById('new_album_name').value,
                         v,
//                         document.getElementById('new_album_pub_date_year').value + '-' + document.getElementById('new_album_pub_date_month').value + '-' + document.getElementById('new_album_pub_date_day').value + 'T00:00:00',
                         document.getElementById('new_album_start_date_year').value + '-' + document.getElementById('new_album_start_date_month').value + '-' + document.getElementById('new_album_start_date_day').value + 'T00:00:00',
                         document.getElementById('new_album_end_date_year').value + '-' + document.getElementById('new_album_end_date_month').value + '-' + document.getElementById('new_album_end_date_day').value + 'T00:00:00',
                         document.getElementById('new_album_description').value,
                         $('new_album_lng').value+';'+$('new_album_lat').value+';'+$('new_album_showonmap').checked);
  };
  finish = function(dav_lines){
    gallery.error_box.clear();

    if (!ds_albums.addAlbumToList(dav_lines))
    {
      var messages = Array();
      var id = dav_lines.id * -1;
      messages[3] = "The album '" + dav_lines.name + "' already exists";
      gallery.showError(new Error(messages[id]))
      document.getElementById('new_album_name').value.selected=true
      return;
  }

    var r = ds_albums.list.length-1;
    var new_coll = preview_collection(ds_albums.list[r],r);

    gallery.albums.appendChild(new_coll);

    $('myAlbumsTxt').innerHTML='My Albums ('+ds_albums.list.length+')';
    album_list = OAT.Dom.create('li');
    album_list.innerHTML = OAT.Xml.escape(ds_albums.list[r].name.substring(0,12));
    album_list.id = "my_albums_list_"+r;
    album_list.appendChild(makeDummyHref(OAT.Xml.escape(ds_albums.list[r].name.substring(0,12))));
    $('my_albums_list').appendChild(album_list);
    gallery.prepare_aplus("my_albums_list_"+r);

    gallery.setCurrent(r);
    gallery.showImages();
    gallery.link_images_upload_click();
    gallery.new_album.hide();
    
    if (ds_albums.settings.show_map==1)
    newAlbumMarkerUpdate ();
  };

  gallery.ajax(prepare,call,finish);
  }

//------------------------------------------------------------------------------
gallery.ajax.edit_album_settings = function()
{
  call = proxies.SOAP.edit_album_settings;
  prepare = function() {
    var settings = new Array;
    settings[0] = 'albums_per_page';
    settings[1] = $v('albums_per_page');

    return Array(sid,
                 gallery_id,
                         home_path,
                         $('edit_album_showmap').checked ? 1: 0,
                         $('edit_album_showtimeline').checked ? 1 : 0,
                         $('edit_album_nntp').checked ? 1: 0,
                 $('edit_album_nntp_init').checked ? 1 : 0,
                 settings
                         );
  }
  finish = function ()
  {
    ds_albums.settings.show_map=$('edit_album_showmap').checked ? 1: 0;
    ds_albums.settings.show_timeline=$('edit_album_showtimeline').checked ? 1 : 0;
    ds_albums.settings.nntp=$('edit_album_nntp').checked ? 1: 0;
    ds_albums.settings.nntp_init=$('edit_album_nntp_init').checked ? 1 : 0;
    if (ds_albums.settings.show_map == 1)
    {
      if (!map)
        if (typeof(window.mapInitPrepare) == "function")
        {
          mapInitPrepare();
        }
    }
    ds_albums.settings.albums_per_page = $v('albums_per_page');
    OAT.Dom.hide('edit_album_settings');
    gallery.show_albums_page();
    gallery.managePanels('my_albums');
    gallery.show_albums_page_navigation();
  };
  gallery.ajax(prepare,call,finish);
}

//------------------------------------------------------------------------------
gallery.ajax.edit_album = function(){

  call = proxies.SOAP.edit_album;
  prepare = function() {
            if(document.f1.album_visibility[0].checked){
              v=1
            }else{
              v=0
            };
            var obsolete=0;
            if ($('edit_album_obsolete').checked)
              obsolete=1;
              
            return Array(sid,gallery_id,
                         home_path,
                         $('edit_album_name_old').value,
                         $('edit_album_name').value,
                         v,
//                         $('edit_album_pub_date_year').value + '-' + $('edit_album_pub_date_month').value + '-' + $('edit_album_pub_date_day').value + 'T00:00:00',
                         $('edit_album_start_date_year').value + '-' + $('edit_album_start_date_month').value + '-' + $('edit_album_start_date_day').value + 'T00:00:00',
                         $('edit_album_end_date_year').value + '-' + $('edit_album_end_date_month').value + '-' + $('edit_album_end_date_day').value + 'T00:00:00',
                         $('edit_album_description').value,
                         $('edit_album_lng').value+';'+$('edit_album_lat').value+';'+$('edit_album_showonmap').checked,
                         obsolete);
           };
  finish = gallery.editCollections;

  gallery.ajax(prepare,call,finish);
}

//------------------------------------------------------------------------------
gallery.ajax.thumbnail_album = function()
{
  call = proxies.SOAP.thumbnail_album;
  prepare = function() {
            if(document.f1.album_visibility[0].checked){
              v=1
            }else{
              v=0
            };
            return Array(sid,gallery_id,
                         home_path,
                         ds_albums.current.name,
                         v,
                         ds_albums.current.thumb_id);
           };
  finish = function(){};

  gallery.ajax(prepare,call,finish);
}

//------------------------------------------------------------------------------
gallery.ajax.delete_album = function(id)
{
  call = proxies.SOAP.dav_delete;
  prepare = function() { return Array(sid,gallery_id,'c',Array(id))};
  finish = function(dav_lines){
    path_set_folder('');
    gallery.ajax.load_albums(gallery_path);
    //if(!ds_albums.removeAlbumFromList(dav_lines)){
    //  var messages = Array();
    //  var id = dav_lines.id * -1;
    //  messages[3] = "The album '" + dav_lines.name + "' can't be deleted";
    //  gallery.showError(new Error(messages[id]))
    //  return;
//}
    //gallery.albums.removeChild(gallery.albums.childNodes[Number(ds_albums.current.index) + Number(1)]);
    //gallery.my_albums_tab_click();
  };

  gallery.ajax(prepare,call,finish);
}

//------------------------------------------------------------------------------
  gallery.ajax.load_images = function(current_id){
  call = proxies.SOAP.dav_browse;
  prepare = function() {
      ds_albums.setCurrent(current_id);
      return Array(sid,gallery_id,ds_albums.list[current_id].fullpath);
  };
  finish = function (p) {
    ds_current_album.loadList(p.albums);
    gallery.showImages()
    hideWait();
  };
  gallery.ajax(prepare,call,finish);
  }

//------------------------------------------------------------------------------
gallery.image_get_image = function(id)
{
  prepare = function() { return Array(sid,gallery_id,id)};
  call = proxies.SOAP.get_image;
  finish = function(p) {
            ds_current_album.addImageToList(p);
            gallery.showImagesInside();
          };

  gallery.ajax(prepare,call,finish);
};

//------------------------------------------------------------------------------
gallery.ajax.image_edit = function(id)
{
  prepare = function() {
            if(document.f1.image_visibility[0].checked){
              v=1
            }else{
              v=0
            };

            return Array(sid,gallery_id,
                         document.f1.edit_image_path.value,
                         document.f1.edit_image_name_old.value,
                         document.f1.edit_image_name.value,
                         document.f1.edit_image_description.value,
                         v)
           };
  call = proxies.SOAP.edit_image;
  finish = function(res) {
    if (res != 0)
    {
      ds_current_album.editImageInList(res);
      gallery.showImage(ds_current_album.current.index);
    }
  };
  gallery.ajax(prepare,call,finish);
}

//------------------------------------------------------------------------------
gallery.ajax.delete_images = function(in_ids)
{
  call = proxies.SOAP.dav_delete;
  prepare = function() {
    return Array(sid,gallery_id,'r',in_ids)
  }
  finish = function(out_ids) {
    if(out_ids!=null)
    {
    var list = ds_current_album.list;
      for(var i=0;i<list.length;i++)
      {
        for(var x=0;x<out_ids.length;x++)
        {
          if (list[i].id == out_ids[x])
          {
          list.splice(i,1);
      }
    }
  }
    gallery.showImagesInside();
    }
  }
  gallery.ajax(prepare,call,finish);
};

//------------------------------------------------------------------------------
gallery.ajax.image_get_comments = function(id)
{
  call = proxies.SOAP.get_comments;
  prepare = function() {
    return Array(sid,gallery_id,id)
  }
  finish = function(comments){
    gallery.comments_list.innerHTML = '';
    if (comments == null)
    {
      return;
}
    for(var i = 0;i<comments.length;i++) 
    {
      gallery.addComment(comments[i]);
    }
  }
  gallery.ajax(prepare,call,finish);
}

//------------------------------------------------------------------------------
gallery.ajax.image_add_comment = function(image_id, comment_text)
{
  call = proxies.SOAP.add_comment;
  prepare = function() {
    return Array(sid, gallery_id, image_id, comment_text)
  }
  finish = function(p) {
    gallery.addComment(p)
  }
  gallery.ajax(prepare,call,finish);
}

//------------------------------------------------------------------------------
gallery.ajax.image_remove_comment = function(comment_id)
{
  call = proxies.SOAP.remove_comment;
  prepare = function() {
    return Array(sid,comment_id)
  }
  finish = function(p) {
      if(p==1)
      {
        OAT.Dom.unlink('comment_'+comment_id);
      }
  }
  gallery.ajax(prepare,call,finish);
}

//------------------------------------------------------------------------------
gallery.ajax.image_update_comment = function(comment_id, comment_text)
{
  call = proxies.SOAP.update_comment;
  prepare = function() {
    return Array(sid,comment_id, comment_text)
  }
  finish = function(p) {
      if(p==1)
      {
      $('comment_'+comment_id).firstChild.innerHTML = comment_text;
      gallery.prepare_aplus('comment_span_'+comment_id);
    }
      }
  gallery.ajax(prepare,call,finish);
}

//------------------------------------------------------------------------------
gallery.ajax.tag_images = function(p1,p2)
{
  call = proxies.SOAP.tag_images;
  prepare = function() {
    return Array(sid,gallery_id,home_url,p1,p2)
  }
  finish = function(tag){
    for(var i=0;i<ds_current_album.list.length;i++){
      $('image_id_'+i).checked = false;
      ds_current_album.list[i].private_tags[ds_current_album.list[i].private_tags.length] = tag;
    }
    alert('Done');
  }
  gallery.ajax(prepare,call,finish);
}

//------------------------------------------------------------------------------
gallery.ajax.image_add_tags = function(image_id, tag)
{
  call = proxies.SOAP.tag_image;
  prepare = function() {
    return Array(sid, gallery_id, home_url, image_id, tag)
  }
  finish = function(p) {
    ds_current_album.current.private_tags = p;
    gallery.showTags()
  }
  gallery.ajax(prepare,call,finish);
}

//------------------------------------------------------------------------------
gallery.ajax.image_remove_tags = function(image_id,tag)
{
  call = proxies.SOAP.remove_tag_image;
  prepare = function() {
    return Array(sid,gallery_id,image_id,tag);
  }
  finish = function(p) {
    ds_current_album.current.private_tags = p;
    gallery.showTags();
  }
  gallery.ajax(prepare,call,finish);
}

//------------------------------------------------------------------------------
gallery.ajax.image_get_exif = function(id)
{
  call = proxies.SOAP.get_attributes;
  prepare = function() {
    return Array(sid,gallery_id,id)
  }
  finish = function(out_data) {
    var j = 0;
    var t = document.createElement('table');
    t.setAttribute('id','exif');
    for(var i=0;i<out_data.length;i++)
    {
      // if (out_data[i].value && (out_data[i].value!='undefined'))
      {
        var tr = t.insertRow(j);
      var td1 = tr.insertCell(0);
      var td2 = tr.insertCell(1);

      td1.appendChild(document.createTextNode(out_data[i].name+': '));
      td2.appendChild(document.createTextNode(out_data[i].value!='undefined'?out_data[i].value:''));
        j++;
      }
    }
    gallery.image_info.clear();
    gallery.image_info.appendChild(t);
  }
  gallery.ajax(prepare,call,finish);
}

//------------------------------------------------------------------------------
gallery.ajax.flickr_login_link = function(e)
{
  if (!e) var e = window.event
  var el = (e.target) ? e.target : e.srcElement
  var mode;
  if(el.id == 'images_import_flickr'){
    mode = 'import'
  }else{
    mode = 'export';
  }
  call = proxies.SOAP.flickr_login_link;
  prepare = function(){
    showWait();
    return Array(sid)
  };
  finish = function(out_data) {
    var url = out_data[0];
    var frob = out_data[1];
    gallery.flickr.status = 'logged';
    flickr_window = window.open(url,'flickr_login',"resizable=1,width=800,height=400,top=100,left=100,scrollbars=1,location=0,status=1");
    flickr_window.focus();
    timer = setInterval(function(){
        if(flickr_window.closed){
          if(mode == 'import'){
            OAT.Dom.addClass('images_import_flickr','link_disabled');
            OAT.Dom.removeClass('images_import_flickr','link');
            OAT.Dom.addClass('images_import_flickr_list','link');
            OAT.Dom.removeClass('images_import_flickr_list','link_disabled');
          }else{
            OAT.Dom.addClass('images_export_flickr','link_disabled');
            OAT.Dom.removeClass('images_export_flickr','link');
            OAT.Dom.addClass('images_export_flickr_send','link');
            OAT.Dom.removeClass('images_export_flickr_send','link_disabled');
          }
          clearInterval(timer)
        }
      },500);

    hideWait();
  };
  gallery.ajax(prepare,call,finish);
};

//------------------------------------------------------------------------------
gallery.ajax.flickr_get_photos_list = function()
{
  if (gallery.flickr.status == '')
  {
    alert('Please, first sign in Flickr!');
    return;
  }
  call = proxies.SOAP.flickr_get_photos_list;
  prepare = function() {
    showWait();
    return Array(sid,gallery.flickr.frob)
  };
  finish = function(out_data) {
    ds_current_album.loadList(out_data);
    gallery.showImages()
    OAT.Dom.addClass('images_import_flickr_save','link');
    OAT.Dom.removeClass('images_import_flickr_save','link_disabled');
    OAT.Dom.addClass('images_import_flickr_list','link_disabled');
    OAT.Dom.removeClass('images_import_flickr_list','link');

    //OAT.Dom.hide('images_import_flickr_list');
    OAT.Dom.show('images_import');
    //OAT.Dom.show('images_import_flickr_save');
    hideWait();
    return;
  };
  gallery.ajax(prepare,call,finish);
};


//------------------------------------------------------------------------------
gallery.ajax.flickr_save_photos = function()
{
  var ids = new Array();
  if (gallery.flickr.status == '')
  {
    alert('Please, first sing in Flickr');
    return;
  }
  for(var i=0;i<ds_current_album.list.length;i++)
  {
    if ($('image_id_'+i).checked)
    {
      ids[ids.length]= $('image_id_'+i).parentNode.parentNode.current_image.id + '_' + $('image_id_'+i).parentNode.parentNode.current_image.secret;
    }
  }
  if (ids.length == 0)
  {
    alert('Please, first select one or more photos!');
    return;
  }

  call = proxies.SOAP.flickr_save_photos;
  prepare = function() {
    showWait();
    return Array(sid,ds_albums.current.id,ids);
  }
  finish = function(out_data) {
    //OAT.Dom.show('images_import_flickr_list');
    //OAT.Dom.hide('images_import_flickr_save');
    OAT.Dom.addClass('images_import_flickr_save','link_disabled');
    OAT.Dom.removeClass('images_import_flickr_save','link');
    OAT.Dom.addClass('images_import_flickr_list','link');
    OAT.Dom.removeClass('images_import_flickr_list','link_disabled');
    gallery.ajax.load_images(ds_albums.current.index);
    return;
  }
  gallery.ajax(prepare,call,finish);
}

//------------------------------------------------------------------------------
gallery.ajax.flickr_send_photos = function()
{
  if (gallery.flickr.status == '')
  {
    alert('Please, first sing in Flickr!');
    return;
  }
  gallery.error_box.clear();
  var ids = new Array();
  for(var i=0;i<ds_current_album.list.length;i++)
  {
    if($('image_id_'+i).checked){
      ids[ids.length]= $('image_id_'+i).parentNode.parentNode.current_image.id;
    }
  }
  if (ids.length == 0)
  {
    alert('Please, first select one or more photos!');
    return;
  }

  call = proxies.SOAP.flickr_send_photos;
  prepare = function() {
    showWait();
    return Array(sid,ids);
  }
  finish = function(out_data) {
    url = "http://www.flickr.com/tools/uploader_edit.gne?ids=" + out_data
    flickr_window = window.open(url,'flickr_login',"resizable=1,width=900,height=600,top=100,left=100,scrollbars=1,location=0,status=1");

    for(var i=0;i<ds_current_album.list.length;i++){
      if($('image_id_'+i).checked){
        $('image_id_'+i).checked = false
      }
    }
    hideWait();
    return;
  }
  gallery.ajax(prepare,call,finish);
}

//------------------------------------------------------------------------------
gallery.hasAccess = function()
{
  if (isOwner == 1)
    return true;
  if (userRole == 'admin')
    return true;
  if (userRole == 'owner')
    return true;
  if (userRole == 'author')
    return true;
  return false;
}

//------------------------------------------------------------------------------
gallery.ajax.user_get_role = function()
{
  call = proxies.SOAP.user_get_role;
  prepare = function() {
    return Array(sid,gallery_id)
  }
  finish = function(p) {
      dd(p);
  }
  gallery.ajax(prepare,call,finish);
}

//------------------------------------------------------------------------------
//Override Quickedit for custom purpose.
//
OAT.QuickEdit.revert = function (elm,oldelm)
{
		if(oldelm.innerHTML != elm.value)
		   filter_change_state(oldelm.id,elm.value)
		oldelm.innerHTML = elm.value;
		elm.parentNode.replaceChild(oldelm,elm);
	}

//------------------------------------------------------------------------------
filter_change_state = function( elm_id, elm_val)
{
 var filter=$('filter');
		dd(elm_id);
		dd(elm_val);
		dd(filter);
 if(elm_id=='filter_type')
 {
    OAT.Dom.unlink('filter_subtype');
    if(elm_val!='N/A')
    {
     var filter_subtype_options= [];
     if(elm_val=='Year')
        filter_subtype_options = ['2000','2001','2002','2003','2004','2005','2006','2007','custom'];
     var filter_subtype_ctrl = OAT.Dom.create("span");
     filter_subtype_ctrl.setAttribute("id","filter_subtype");
     filter_subtype_ctrl.innerHTML = "2000";
     filter_subtype_ctrl.className='qe';
     OAT.QuickEdit.assign(filter_subtype_ctrl, OAT.QuickEdit.SELECT, filter_subtype_options);
     $('filter').appendChild(document.createTextNode('/'));  

     $('filter').appendChild(filter_subtype_ctrl);  
    }

 }

 if(elm_id=='filter_subtype')
 {
    OAT.Dom.unlink('filter_custom');
    if(elm_val=='custom')
    {
      var filter_custom_ctrl = OAT.Dom.create("span");
      filter_custom_ctrl.setAttribute("id","filter_custom");
      filter_custom_ctrl.innerHTML = "...";
      dd(filter_custom_ctrl);
      filter_custom_ctrl.className='qe';
      OAT.QuickEdit.assign(filter_custom_ctrl, OAT.QuickEdit.STRING);
      $('filter').appendChild(document.createTextNode('/'));  
      
      $('filter').appendChild(filter_custom_ctrl);  
    }
 }

}

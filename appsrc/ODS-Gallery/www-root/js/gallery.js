/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2006 OpenLink Software
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

//------------------------------------------------------------------------------
//function sdate2obj(sdate){
//  var gdate = new Object();
//
//  if(!sdate || sdate == ''){
//    sdate = '2000-01-01T00:00:00';
//  }
//  gdate.date = sdate.substring(0,sdate.indexOf('T'));
//  gdate.time = sdate.substring(sdate.indexOf('T')+1,sdate.indexOf('T')+6);
//  gdate.datetime =  gdate.date + ' ' + gdate.time;
//  gdate.elements = gdate.date.split('-');
//  gdate.day   = gdate.elements[2];
//  gdate.month = gdate.elements[1];
//  gdate.year  = gdate.elements[0];
//
//  return gdate;
//}

//------------------------------------------------------------------------------
function album (element){
  this.name        = element.name;
  this.path        = element.fullpath;
  this.id          = element.id;
  this.pub_date    = element.pub_date;
  this.description = element.description;
  this.visibility  = element.visibility;
  this.thumb_id    = element.thumb_id;
};


//------------------------------------------------------------------------------
function image (element){
  this.name        = element.name;
  this.path        = element.fullpath;
  this.id          = element.id;
  this.mime        = element.mime
  this.visibility  = element.visibility;
  this.description = element.description;
};



var ds_albums = new dataSet(album,'C');
var ds_current_album = new dataSet(image,'R');


//------------------------------------------------------------------------------
// Visualization
//------------------------------------------------------------------------------

var gallery = new Object();

//------------------------------------------------------------------------------
gallery.init = function (gallery_path){

  this.albums         = new panel('albums');
  this.albums_list    = new panel('albums_list');
  this.albums_man     = new panel('albums_man');
  this.images         = new panel('images');
  this.image          = new panel('image');
  this.info           = new panel('info');
  this.nav            = new panel('nav');
  this.toolbar        = new panel('toolbar');
  this.error_box      = new panel('error_box');
  this.slideshow      = new panel('slideshow');
  this.new_album      = new panel('new_album');
  this.edit_album     = new panel('edit_album');
  this.upload_image   = new panel('upload_image');
  this.comments       = new panel('comments');
  this.comments_list  = new panel('comments_list');
  this.image_info     = new panel('image_info');
  this.image_edit     = new panel('image_edit');

  this.slideshow_run = 0;
  this.show_exif_flag = 0;

  gallery.current_state = Array(3);
  if(location.hash && location.hash != '#'){

    gallery.current_state = location.hash.substring(1).split(':')

    page_location = location.href.substring(0,location.href.indexOf('#'))

  }

  ajax.Start(gallery_load_albums,gallery_path);

  document.getElementById("wrapper").onclick = dispach;
}


//------------------------------------------------------------------------------
function jump_to(){
  var path  = location.hash.substring(1).split('/');

  if(path.length == 1 && path.length == 2){
    // Home page - show albums
    return true;

  }else if(path.length == 3 && path[2] == ''){
    // Folder list - show images
    gallery.setCurrentByName(path[1]);
    eval('ajax.Start(gallery_load_images,'+ds_albums.current.index+')');
    return false;

  }else if(path.length == 3){
    // Preview image - show image
    gallery.setCurrentByName(path[1]);
    eval('ajax.Start(gallery_load_images,'+ds_albums.current.index+')');
    return false;
  }

  return true;
}

//------------------------------------------------------------------------------
function path_set_folder(path){
  if(path != ''){
    path += '/';
  }
  location.href = page_location + '#/' + path;
}


//------------------------------------------------------------------------------
function path_set_file(path){
  var folders = location.hash.substring(1,location.hash.lastIndexOf('/')+1);

  location.href = page_location + '#' + folders + path;
}

//------------------------------------------------------------------------------
gallery.setCurrent = function(current_id){
  ds_albums.setCurrent(current_id);
  ds_current_album.list.length = 0;
}

//------------------------------------------------------------------------------
gallery.setCurrentByName = function(current_name){
  var ind = ds_albums.checkNameExist(current_name);
    if(ind > -1){
    ds_albums.setCurrent(ind);
    ds_current_album.list.length = 0;
  }
}

//------------------------------------------------------------------------------
function dispach_OLD(e){
  if (!e) var e = window.event
  var el = (e.target) ? e.target : e.srcElement

  if(el.id == 'my_albums_tab'){
    //gallery.my_albums_click();

  }else if(el.id == 'new_album_tab'){
    //gallery.new_album_click()
  }

  var ok = 0;
  var id;
  var i=0;
  var res = true;
  var t_el = el;
  var dbg_list = '';

  while(i < 10){
    id = t_el.id;

    if(id != ''){

      var action = 'gallery.' + id + '_click'

      if(eval(action)){
        res = eval(action+'(el)')

        ok = 1;
        window.status = action;
        break;
      }else{
        dbg_list += action + ' -> ';
      }
    }

    if(t_el.parentNode.nodeName != 'BODY'){
      t_el = t_el.parentNode;
    }else{
      break;
    }
    i++;
  }
      //ok=0;
  if(!ok){
    var msg = 'No action:' + dbg_list;
    if(document.getElementById("debug")){
      document.getElementById("debug").innerHTML = msg;
    }
    //window.status = msg;
  }
  return res;
}


//------------------------------------------------------------------------------
function panel(name){
  var obj = document.getElementById(name);

    obj.show = function(){
      this.style.display="";
      this.visible=1;
    }
    obj.hide = function(){
      this.style.display="none";
      this.visible=0;
    }
    obj.clear = function(){   this.innerHTML = '';}
    obj.tabs = function(on_id){
        var nodeId = returnIndexFirstChild(this.childNodes);
        var nodeList = returnListOfNodes(this.childNodes[nodeId].childNodes);

        for(var i=0;i<nodeList.length;i++){

          if(on_id == i){
            nodeList[i].className = "on";
          }else if(nodeList[i].className == "on"){
            nodeList[i].className = "";
          }
        };

    }
  return obj;
}


//------------------------------------------------------------------------------
gallery.closePanels = function(){
  this.hideAlbums();
  this.images.hide();
  this.image.hide();
  this.info.hide();
  this.toolbar.hide();
  this.error_box.hide();
  this.slideshow.hide();
  this.new_album.hide();
  this.edit_album.hide();
  this.upload_image.hide();
  this.image_info.hide();
  this.comments.hide();

}


//------------------------------------------------------------------------------
gallery.albums_click = function(el){
  current_id = el.id.substring(el.id.lastIndexOf('_')+1);

  gallery.setCurrent(current_id);
  ajax.Start(gallery_load_images,current_id);
}
//------------------------------------------------------------------------------
gallery.showCollections = function (p){

  ds_albums.loadList(p.albums);
  ds_albums.current.is_own = p.is_own;
  ds_albums.current.owner_name = p.owner_name;

  if(!jump_to()){
    gallery.hideAlbums();
  }
  gallery.showAlbumsInfo();
  gallery.showCollectionsAsBlocks();
}

//------------------------------------------------------------------------------
  gallery.showCollectionsAsBlocks = function (){

    for(var r=0;r<ds_albums.list.length;r++){
      new_coll = preview_collection(ds_albums.list[r],r);
      this.albums.appendChild(new_coll);
    }
  }

//------------------------------------------------------------------------------
  gallery.showCollectionsAsTable = function (){

    new_tr = this.albums.insertRow(0)

    for(var r=0;r<ds_albums.list.length;r++){
      new_coll = preview_collection(ds_albums.list[r],r);
      var cell = new_tr.insertCell(r);
      cell.appendChild(new_coll);
    }
    gallery.nav.tabs(1);
  }

//------------------------------------------------------------------------------
  gallery.addCollections = function (dav_lines){
    gallery.error_box.clear();

    if(!ds_albums.addAlbumToList(dav_lines)){
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

    gallery.new_album.hide();
    gallery.setCurrent(r);
    gallery.showImages();
    gallery.btn_image_upload_click();
  }

//------------------------------------------------------------------------------
  gallery.editCollections = function (dav_lines){

      if(!ds_albums.editAlbumToList(dav_lines)){
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

      gallery.albums.removeChild(gallery.albums.childNodes[Number(ds_albums.current.index)]);
      gallery.albums.appendChild(coll)

      gallery.edit_album.hide();

      gallery.showImages();

  }

//------------------------------------------------------------------------------
  gallery.removeCollection = function (dav_lines){

      if(!ds_albums.removeAlbumFromList(dav_lines)){
        r = this.current.index;
        var messages = Array();
        var id = dav_lines.id * -1;
        messages[3] = "The album '" + dav_lines.name + "' can't be deleted";
        gallery.showError(new Error(messages[id]))
        return;
      }
      gallery.albums.removeChild(gallery.albums.childNodes[Number(ds_albums.current.index) + Number(1)]);
      gallery.my_albums_tab_click();
  }


//------------------------------------------------------------------------------
gallery.new_album_tab_click = function (){

  gallery.closePanels();

  this.new_album.show();
  document.getElementById('new_album_description').value = '';
  document.getElementById('new_album_name').value = '';
  gallery.nav.tabs(2);
}

//------------------------------------------------------------------------------
gallery.new_album_action = function (){

  var name = strip_spaces(document.getElementById('new_album_name').value);
  document.getElementById('new_album_name').value = name;

  if(document.getElementById('new_album_name').value == ''){
    alert('Please, type album name');
    document.getElementById('new_album_name').focus();
    document.getElementById('new_album_name').style.background = "#FFFF9B";
    return;
  }
  ajax.Start(gallery_new_album,'');
}

//------------------------------------------------------------------------------
gallery.new_album_name_click = function(el){

}

//------------------------------------------------------------------------------
gallery.btn_edit_album_click = function (){

  this.edit_album.show();
  this.upload_image.hide();

  gallery.hideSlideShow();

  this.images.hide();
  document.getElementById('edit_album_name_old').value = ds_albums.current.name;
  document.getElementById('edit_album_name').value = ds_albums.current.name;

  if((typeof ds_albums.current.description) != 'undefined'){
    document.f1.edit_album_description.value = ds_albums.current.description;
  }
  var t_date = sdate2obj(ds_albums.current.pub_date);
  document.f1.edit_album_pub_date_year.selectedIndex  = String(t_date.elements[0]).substring(3);
  document.f1.edit_album_pub_date_day.selectedIndex   = Number(t_date.elements[2])-1;
  document.f1.edit_album_pub_date_month.selectedIndex = Number(t_date.elements[1])-1;


  if(ds_albums.current.visibility == 1){
    document.f1.album_visibility[0].checked = true;
  }else{
    document.f1.album_visibility[1].checked = true;
  }
  gallery.hideAlbums();
}

//------------------------------------------------------------------------------
gallery.edit_album_action = function (){
  if(document.getElementById('edit_album_name').value == ''){
    alert('Please, type album name');
    document.getElementById('edit_album_name').focus();
    document.getElementById('edit_album_name').style.background = "#FFFF9B";
    return;
  }
  ajax.Start(gallery_edit_album,'');
}
//------------------------------------------------------------------------------
gallery.btn_image_upload_click = function(){

  this.edit_album.hide();
  gallery.hideSlideShow();
  gallery.showUploadToolbar();
  gallery.upload_image.show();
  var id = returnIndexFirstChild(gallery.upload_image.childNodes)

  gallery.upload_image.childNodes[id].src=base_path+"upload.vspx?sid="+sid+"&realm=wa&album="+ds_albums.current.name;
  gallery.images.hide();
}

//------------------------------------------------------------------------------
gallery.upload_image_cancel = function (){
  this.upload_image.hide();
  this.images.show();
  ajax.Start(gallery_load_images, ds_albums.current.index);
}

//------------------------------------------------------------------------------
gallery.upload_image_finish = function(id){
  ajax.Start(gallery_load_images, ds_albums.current.index);
}


//------------------------------------------------------------------------------
gallery.edit_album_cancel = function (){
  this.images.show();
  this.edit_album.hide();

}

//------------------------------------------------------------------------------
gallery.moveCollectionLeft = function (){
  pos = parseInt(this.albums.style.marginLeft);
  if(isNaN(pos)){
    pos = 0;
  }
  if(pos <= 0){
    scroll.pos=pos;
    scroll.new_pos=Number(pos-122);
    scroll.step=-2;
    scroll.moveObject()
  }
}

//------------------------------------------------------------------------------
gallery.moveCollectionRight = function (){
  pos = parseInt(gallery.albums.style.marginLeft);
  if(isNaN(pos)){
    pos = 0;
  }

  if(pos < 0){

    scroll.pos=pos;
    scroll.new_pos=Number(pos+122);
    scroll.step=2;
    scroll.moveObject()
  }
}



//------------------------------------------------------------------------------
gallery.showImages = function (){
  var path  = location.hash.substring(1).split('/');
  if(path.length == 3 && path[2] != ''){
    var ind = ds_current_album.checkNameExist(path[2]);
    if(ind > -1){
      eval('gallery.showImage('+ind+')');
    }
    return false;
  }

  gallery.hideAlbums();
  gallery.showImagesToolbar()
  gallery.upload_image.hide();

  gallery.showImagesInside();
  gallery.image_info.hide();
  gallery.comments.hide();

}


//------------------------------------------------------------------------------
gallery.showImagesInside = function (){

    this.images.clear();
    this.images.show();
    this.info.clear();
    this.image.hide();
    this.albums_list.hide();
    this.albums_man.hide();

    fadeimages.length = 0;
    gallery.hideSlideShow();

    gallery.showImagesInfo();

    for(var r=0;r<ds_current_album.list.length;r++){

      //if(ds_current_album.list[r].mime.indexOf('jpeg') == -1){
      //  continue;
      //}
      new_coll = preview_image(ds_current_album.list[r],r);

      this.images.appendChild(new_coll);

    }
    if(ds_current_album.list.length == 0){
        block = document.createElement('div');
        block.setAttribute('id','message');
        block.appendChild(document.createTextNode('No images in this album. Click "Add images" to add new'));
        this.images.appendChild(block);
    }

    //Navigation prev<->next album
    p_nav = document.getElementById('preview_nav');
    if(p_nav.firstChild){
      p_nav.removeChild(p_nav.firstChild);
    }
    if(p_nav.firstChild){
      p_nav.removeChild(p_nav.firstChild);
    }

    var i = ds_albums.current.index;

    if(i>0){

      p_nav.appendChild(preview_album(ds_albums.list[i-1],i-1,'previous'));
    }else{
      p_nav.appendChild(preview_image_empty());
    }
    if(i<ds_albums.list.length-1){
      p_nav.appendChild(preview_album(ds_albums.list[Number(i)+1],Number(i)+1,'next'));
    }else{
      p_nav.appendChild(preview_image_empty());
    }

    path_set_folder(ds_albums.current.name);
}


//------------------------------------------------------------------------------
gallery.images_click = function(el){


}

//------------------------------------------------------------------------------
gallery.showImage = function(i){

    gallery.images.hide();
    gallery.hideToolbar();

    gallery.image.innerHTML = "";
    src = ds_current_album.list[i].path;
    src = base_path+'image.vsp?'+setSid()+'image_id='+ds_current_album.list[i].id
    gallery.image.appendChild(makeImg(src));

    gallery.image.show();
    gallery.hideAlbums();

    gallery.showImageInfo(i)
    gallery.showImageToolbar(i)
    setLi('btn_preview','on')
    gallery.hideSlideShow();


    ds_current_album.setCurrent(i);
    gallery.show_exif();

    //Navigation previous<->next
    p_nav = document.getElementById('preview_nav');
    if(p_nav.firstChild){
      p_nav.removeChild(p_nav.firstChild);
    }
    if(p_nav.firstChild){
      p_nav.removeChild(p_nav.firstChild);
    }

    if(i>0){
      p_nav.appendChild(preview_image(ds_current_album.list[i-1],i-1,'previous'));
    }else{
      p_nav.appendChild(preview_image_empty());
    }
    if(i<ds_current_album.list.length-1){
      p_nav.appendChild(preview_image(ds_current_album.list[Number(i)+1],Number(i)+1,'next'));
    }else{
      p_nav.appendChild(preview_image_empty());
    }

    document.f1.new_comment.value = '';
    gallery.comments.show();

    ajax.Start(gallery_image_get_comments,ds_current_album.list[i].id)

    path_set_file(ds_current_album.list[i].name);
}


//------------------------------------------------------------------------------
gallery.showComments = function(comments){

  this.comments_list.innerHTML = '';
  //var NodeList = returnListOfNodes(this.comments.childNodes)
  //NodeList[1].innerHTML = '';
  //
  if(comments == null){
    return;
  }

  for(var i = 0;i<comments.length;i++){
    gallery.addComment(comments[i]);
  }
}


//------------------------------------------------------------------------------
gallery.addComment = function(comment){

  document.f1.new_comment.value = '';

  var pub_date = sdate2obj(comment.create_date);
  var txt = document.createElement('div');
  var edit = document.createElement('span');
  var user = document.createElement('h3');

  txt.appendChild(document.createTextNode(comment.text));
  edit.appendChild(document.createTextNode('[Edit] [Delete]'));
  user.appendChild(document.createTextNode(comment.user_name));
  user.appendChild(document.createTextNode(','));
  user.appendChild(document.createTextNode(pub_date.day+'/'+pub_date.month+'/'+pub_date.year));
  this.comments_list.appendChild(txt);
  this.comments_list.appendChild(edit);
  this.comments_list.appendChild(user);
}





//------------------------------------------------------------------------------
gallery.showAlbumsInfo = function(i){

  div = document.createElement('div');
  div.setAttribute('id','title');

  var path_albums = document.createElement('span');
  path_albums.setAttribute('id','path_my_albums');
  if(ds_albums.current.is_own == 1){
    path_albums.appendChild(document.createTextNode('My Albums'));
  }else{
    path_albums.appendChild(document.createTextNode(ds_albums.current.owner_name +'\'s albums'));
    gallery.albums_man.hide();
  }

  var title = document.createElement('h3');
  title.appendChild(document.createTextNode('Choose an album to view'));

  var path = document.createElement('div');
  path.appendChild(path_albums);

  div.appendChild(path);
  div.appendChild(title);

  gallery.info.innerHTML="";
  gallery.info.show();
  gallery.info.appendChild(div);

}



//------------------------------------------------------------------------------
gallery.showImagesInfo = function(){

  var txt = '';
  if(typeof ds_albums.current.description != 'undefined'){
    txt = ds_albums.current.description + ' / ';
  }

  txt += ds_current_album.list.length+' pictures';

  var path_arr = Array(
                        Array('path_my_albums','My Albums'),
                        Array('path_pub_date',sdate2obj(ds_albums.current.pub_date).date),
                        Array('path_album_name',ds_albums.current.name)
                      )

  div = gallery.makePanelHeader(ds_albums.current.name,
                                txt,
                                path_arr);

  gallery.info.innerHTML="";
  gallery.info.appendChild(div);
  gallery.info.appendChild(showPreviewNav());
  gallery.info.show();
}

//------------------------------------------------------------------------------
gallery.path_my_albums_click = function(){
  gallery.my_albums_tab_click();
}


//------------------------------------------------------------------------------
gallery.path_album_name_click = function(){
  gallery.btn_thumb_click();
}

//------------------------------------------------------------------------------
gallery.showImageInfo = function(i){

  txt = '';
  if(typeof ds_albums.current.description != 'undefined'){
    txt = ds_albums.current.description + ' / ';
  }
  txt += (Number(i)+Number(1)) + ' of '+ ds_current_album.list.length+' pictures';

  var path_arr = Array(
                        Array('path_my_albums','My Albums'),
                        Array('path_pub_date',sdate2obj(ds_albums.current.pub_date).date),
                        Array('path_album_name',ds_albums.current.name),
                        Array('path_image_name',ds_current_album.list[i].name)
                      )

  div = gallery.makePanelHeader(ds_current_album.list[i].name,
                                txt,
                                path_arr);

  gallery.info.innerHTML="";
  gallery.info.appendChild(div);
  gallery.info.appendChild(showPreviewNav());

}


//------------------------------------------------------------------------------
gallery.showImagesToolbar = function(){
  gallery.toolbar.clear();
  gallery.toolbar.show();

  var title = document.createElement('h3')
  title.appendChild(document.createTextNode('Edit album'));

  img_tools = makeUl('img_tools')

  if(sid != ''){
    img_tools.appendChild(makeLi('Add images','btn_image_upload'));
    img_tools.appendChild(makeLi('Edit album','btn_edit_album'));
    img_tools.appendChild(makeLi('Delete album','delete_album_tab'));
    img_tools.appendChild(makeLi('Delete images','delete_images_tab'));
  }
  gallery.toolbar.appendChild(title);
  gallery.toolbar.appendChild(img_tools)


  var title = document.createElement('h3')
  title.appendChild(document.createTextNode('View mode'));

  img_tools = makeUl('img_tools')
  img_tools.appendChild(makeLi('Slideshow','btn_slideshow'));

  gallery.toolbar.appendChild(title);
  gallery.toolbar.appendChild(img_tools)

}

//------------------------------------------------------------------------------
gallery.showUploadToolbar = function(){
  gallery.toolbar.clear();
  gallery.toolbar.show();

  var title = document.createElement('h3')
  title.appendChild(document.createTextNode('Edit album'));

  img_tools = makeUl('img_tools')

  img_tools.appendChild(makeLi('All images','btn_thumb','','on'));

  gallery.toolbar.appendChild(title);
  gallery.toolbar.appendChild(img_tools)

}


//------------------------------------------------------------------------------
gallery.showSlideshowToolbar = function(){
  gallery.toolbar.clear();
  gallery.toolbar.show();
  gallery.image_info.hide();

  var title = document.createElement('h3')
  title.appendChild(document.createTextNode('Edit album'));

  img_tools = makeUl('img_tools')

  img_tools.appendChild(makeLi('All images','btn_thumb','','on'));

  gallery.toolbar.appendChild(title);
  gallery.toolbar.appendChild(img_tools)


  var title = document.createElement('h3')
  title.appendChild(document.createTextNode('View mode'));

  var slider_code = document.createElement('div');
  slider_code.setAttribute('class','slider');
  slider_code.setAttribute('id','slider_1');
  slider_code.innerHTML = '<input class="slider_input" id="slider_input_1" name="slider_input_1"/>'


  var manage = document.createElement('div');
  manage.setAttribute('id','buttons')
  //manage.appendChild(makeImg('res/i/skipb_24.gif',24,24,'manageSlideShowPrev','','Previus Picture'));
  manage.appendChild(makeImg('/gallery/res/i/pause_24.gif',24,24,'manageSlideShow','','Start/Pause'));
  manage.appendChild(makeImg('/gallery/res/i/skipf_24.gif',24,24,'manageSlideShowNext','','Next picture'));

  img_tools = makeUl('img_tools')
  img_tools.appendChild(makeLi(manage));
  //img_tools.appendChild(makeLi('Pause','btn_slideshow'));
  //img_tools.appendChild(makeLi(' ',''));
  ////img_tools.appendChild(makeLi('Faster show','btn_slideshow_faster'));
  ////img_tools.appendChild(makeLi('Slower show','btn_slideshow_slower'));
  img_tools.appendChild(makeLi(slider_code,'btn_slideshow_faster'));
  img_tools.appendChild(makeLi('show Status','btn_slideshow_status'));

  //t_html  = '<tr class="buttons"><td><img src="res/i/play_24.gif"/></td>';
  //t_html += '<td><img src="res/i/pause_24.gif" id="btn_slideshow"/></td>';
  //t_html += '<td><img src="res/i/play_24.gif"/></td></tr>';
  //t_html += '<tr><td colspan="3"><div class="slider" id="slider_1" tabIndex="1"><input class="slider_input" id="slider_input_1" name="slider_input_1"/></div></td></tr>';
  //t_html += '<tr><td colspan="3" id="btn_slideshow_status"></td></tr>';

//var t_html  =  '<tr><td>1</td></tr>';
//  var img_tools = document.createElement('table');
//  tr = img_tools.insertRow(0);
//  td = tr.insertCell(0);
//  td.appendChild(makeImg('res/i/play_24.gif'));
//  td = tr.insertCell(1);
//  td.appendChild(makeImg('res/i/pause_24.gif',24,24,'btn_slideshow'));
//  td = tr.insertCell(2);
//  td.appendChild(makeImg('res/i/play_24.gif'));
//
//  tr = img_tools.insertRow(1);
//  td = tr.insertCell(0);
//  td.appendChild(makeImg('res/i/play_24.gif'));
//  td = tr.insertCell(1);
//  td.appendChild(makeImg('res/i/pause_24.gif',24,24,'btn_slideshow'));
//  td = tr.insertCell(2);
//  td.appendChild(makeImg('res/i/play_24.gif'));



  gallery.toolbar.appendChild(title);
  gallery.toolbar.appendChild(img_tools)

  s = new Slider(document.getElementById("slider_1"),document.getElementById("slider_input_1"));
  s.setMaximum(30);
  s.setMinimum(1);
  s.setValue(3)
  s.onchange = function(){
    window.status = s.getValue();
    pause = s.getValue() * 1000;
    gallery.statusSlideShow();
    }

}


//------------------------------------------------------------------------------
gallery.showImageToolbar = function(){

  var title = document.createElement('h3')
  title.appendChild(document.createTextNode('Edit image'));

  img_tools = makeUl('img_tools')
  img_tools.appendChild(makeLi('All images','btn_thumb','','on'));
  img_tools.appendChild(makeLi('Add images','btn_image_upload'));
  //img_tools.appendChild(makeLi('Preview','btn_preview','','on'));
  if(sid != ''){
    img_tools.appendChild(makeLi('Edit caption','tab_image_edit','','on'));
  }

  gallery.toolbar.appendChild(title);
  gallery.toolbar.appendChild(img_tools)

  var title = document.createElement('h3')
  title.appendChild(document.createTextNode('View mode'));

  img_tools = makeUl('img_tools')
  img_tools.appendChild(makeLi('EXIF','btn_exif','','on'));
  img_tools.appendChild(makeLi('Slideshow','btn_slideshow'));

  gallery.toolbar.appendChild(title);
  gallery.toolbar.appendChild(img_tools)

}

//------------------------------------------------------------------------------
gallery.btn_thumb_click = function(){
  gallery.stopSlideShow();
  path_set_folder(ds_albums.current.name);
  gallery.showImages();
}
//------------------------------------------------------------------------------
gallery.btn_slideshow_click = function(){

  if(ds_current_album.list.length < 2){
    gallery.showImages();
    return;
  }

  this.slideshow.show();
  this.upload_image.hide();
  this.edit_album.hide();
  this.info.hide();
  this.images.hide();
  this.comments.hide();
  gallery.showSlideshowToolbar()

  if(this.slideshow_run == 0){
    this.image.innerHTML = "";
    this.images.innerHTML = "";

    this.slideshow_run = 1;

    if(fadeimages.length > 0){
      rotateimage();

    }else{

      for(var i=0;i<ds_current_album.list.length;i++){
        src = base_path+'image.vsp?'+setSid()+'image_id='+ds_current_album.list[i].id;
        fadeimages[i]=[src, "", "",ds_current_album.list[i].name] //plain image syntax
      }
      if(preloadedimages.length == 0){
        for (p=0;p<fadeimages.length;p++){
          preloadedimages[p]=new Image()
          preloadedimages[p].src=fadeimages[p][0]
        }
      }
      slideshow();
    }
  }else{
    this.stopSlideShow();
  }

  gallery.statusSlideShow();

  return;
}

//------------------------------------------------------------------------------
gallery.manageSlideShow_click = function(){

  btn = document.getElementById('manageSlideShow');
  if(this.slideshow_run == 0){
    this.slideshow_run = 1;
    btn.src = 'res/i/pause_24.gif'
    rotateimage();

  }else{
    clearTimeout(timeOutId);
    this.slideshow_run = 0;
    btn.src = 'res/i/play_24.gif'
  }
  gallery.statusSlideShow();
}

//------------------------------------------------------------------------------
gallery.manageSlideShowPrev_click = function(){
  clearTimeout(timeOutId);
  clearInterval(dropslide)
  nextimageindex=(nextimageindex>1)? nextimageindex-2 : fadeimages.length-2+nextimageindex
  rotateimage();
}

//------------------------------------------------------------------------------
gallery.manageSlideShowNext_click = function(){
  clearTimeout(timeOutId);
  clearInterval(dropslide)
//alert(nextimageindex);
  //nextimageindex=(nextimageindex<fadeimages.length-1)? nextimageindex+1 : 0
//window.status = nextimageindex;
  rotateimage();
}


//------------------------------------------------------------------------------
gallery.stopSlideShow = function(){
  if(this.slideshow_run == 1){
    btn = document.getElementById('btn_slideshow');
    //this.slideshow_run = -1;
    clearTimeout(timeOutId);
  }
}

//------------------------------------------------------------------------------
gallery.hideSlideShow = function(){
  this.stopSlideShow();
  this.slideshow.hide();
  this.slideshow_run = 0;
}


//------------------------------------------------------------------------------
gallery.statusSlideShow = function(){
  if(this.slideshow_run == 1){
    document.getElementById('btn_slideshow_status').innerHTML = "Play at intervals of "+(pause/1000)+" sec";
  }else{
    document.getElementById('btn_slideshow_status').innerHTML = "Show is stoped";
  }
}

//------------------------------------------------------------------------------
gallery.btn_slideshow_faster_click = function(){
  if(pause > 1000){
    pause -= 1000;
  }
  gallery.statusSlideShow();
}

//------------------------------------------------------------------------------
gallery.btn_slideshow_slower_click = function(){
  pause += 1000;
  gallery.statusSlideShow();
}

//------------------------------------------------------------------------------
gallery.hideInfo = function(){
  this.info.innerHTML = '';
}

//------------------------------------------------------------------------------
gallery.hideToolbar = function(){
  this.toolbar.innerHTML = '';
}

//------------------------------------------------------------------------------
gallery.hideAlbums = function(){
  gallery.albums.hide();
  gallery.albums_list.hide();
  gallery.albums_man.hide();

  gallery.nav.tabs(-1);

}


//------------------------------------------------------------------------------
gallery.my_albums_tab_click = function (){
  gallery.albums.show();
  gallery.showAlbumsInfo();
  gallery.albums_list.show();
  gallery.albums_man.show();
  gallery.upload_image.hide();
  gallery.new_album.hide();
  gallery.error_box.clear();
  gallery.images.hide();
  gallery.image.hide();
  gallery.hideSlideShow();
  gallery.hideToolbar();
  gallery.nav.tabs(1);
  gallery.comments.hide();
  gallery.image_info.hide();

  //location.href = page_location + '#';
  path_set_folder('');
}

//------------------------------------------------------------------------------
gallery.wa_click = function (){
  location.href = wa_home_link + 'services.vspx?sid='+sid+'&realm=wa';
}

//------------------------------------------------------------------------------
gallery.home_click = function (){
  location.hash = '';
  location.reload();
}

//------------------------------------------------------------------------------
gallery.btn_exif_click = function(){
  if(gallery.show_exif_flag == 0){
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
  if(gallery.show_exif_flag == 1){
    gallery.toolbar.tabs(3);
    gallery.image_info.show();
    gallery.image_info.innerHTML = 'Loading ...';
    ajax.Start(gallery_image_get_exif,ds_current_album.current.id);
  }
}

//------------------------------------------------------------------------------
gallery.addExif = function(data){

  var t = document.createElement('table');
  t.setAttribute('id','exif');
  for(var i=0;i<data.length;i++){
    var tr = t.insertRow(i);
    var td1 = tr.insertCell(0);
    var td2 = tr.insertCell(1);

    td1.appendChild(document.createTextNode(data[i].name+': '));
    td2.appendChild(document.createTextNode(data[i].value));
  }
  gallery.image_info.clear();

  gallery.image_info.appendChild(t);
}

//------------------------------------------------------------------------------
gallery.tab_image_edit_click = function(){
  gallery.image_info.hide();
  gallery.image_edit.show();
  gallery.toolbar.tabs(4)

  document.f1.edit_image_description.value = ds_current_album.current.description;
  document.f1.edit_image_name.value = ds_current_album.current.name;
  document.f1.edit_image_name_old.value = ds_current_album.current.name;
  document.f1.edit_image_path.value = ds_albums.current.path;

  if(ds_current_album.current.visibility == 1){
    document.f1.image_visibility[0].checked = true
  }else{
    document.f1.image_visibility[1].checked = true;
  }
}

//------------------------------------------------------------------------------
gallery.btn_image_edit_click = function(){
  ajax.Start(gallery_image_edit);
}

//------------------------------------------------------------------------------
gallery.image_edit_finish = function(res){

  if(res != 0){
    ds_current_album.editImageInList(res);

    alert('Succesfull')
    gallery.toolbar.tabs(1);
    gallery.image_edit.hide();
    gallery.showImage(ds_current_album.current.index);


  }else{
    alert('Problem');
  }
}
//------------------------------------------------------------------------------
gallery.btn_image_edit_cancel_click = function(){
  gallery.toolbar.tabs(1);
  gallery.image_edit.hide();
}

//------------------------------------------------------------------------------
gallery.new_album_close_click = function(){
 gallery.my_albums_tab_click();
}


//------------------------------------------------------------------------------
gallery.delete_images_tab_click = function(){

  if(gallery.images.visible == 0){
    return;
  }
  var ids = new Array();
  for(var i=0;i<ds_current_album.list.length;i++){
    if(document.getElementById('image_id_'+i).checked){
      ids[ids.length]= document.getElementById('image_id_'+i).value;
    }
  }

  if(ids.length == 0){
    alert('Please, first select one or more pictures');
    return;
  }

  if(!confirm('Are you sure that you want to delete selected images?')){
    return;
  }

  ajax.Start(gallery_delete_images,ids);
}


//------------------------------------------------------------------------------
gallery.delete_album_tab_click = function(){
  if(!confirm('Are you sure that you want to delete current Album?')){
    return;
  }
  ajax.Start(gallery_delete_album,Array(ds_albums.current.id));
}

//------------------------------------------------------------------------------
gallery.bnt_new_comment_click = function(){

  var comment = new Object();
  comment.comment_id = '';
  comment.create_date = '';
  comment.user_id = '';
  comment.user_name = '';

  comment.text = document.f1.new_comment.value
  comment.res_id = ds_current_album.current.id;

  ajax.Start(gallery_image_add_comments,comment);
}

//------------------------------------------------------------------------------
gallery.get_image = function(id){
  ajax.Start(gallery_load_images, ds_albums.current.index);
}



//------------------------------------------------------------------------------
gallery.showError = function (ex){

    var s = '<img src="res/i/close-24.gif" id="new_album_close" class="close_button" title="Close this panel" OnClick="gallery.error_box.hide()" />';

  if (ex.constructor == String) {
    s = ex;
  } else {
    if ((ex.name != null) && (ex.name != ""))
      s += "Type: " + ex.name + "<br>";

    if ((ex.message != null) && (ex.message != ""))
      s += "Message:\n" + ex.message + "<br>";

    if ((ex.description != null) && (ex.description != "") && (ex.message != ex.description))
      s += "Description:\n" + ex.description + "<br>";



  } // if

  box = document.createElement('div');
  box.innerHTML = s ;
  gallery.error_box.clear();
  gallery.error_box.show();
  gallery.error_box.appendChild(box);

}


//------------------------------------------------------------------------------
function showPreviewNav(){
  div = document.createElement('div');
  div.setAttribute('id','preview_nav');
  //div.appendChild(document.createTextNode('zzzzzz'))
  return div;
}


//------------------------------------------------------------------------------
function preview_collection(album,i){

  var div = document.createElement('div')
  var ramka = document.createElement('span')
  div.setAttribute('id','album_preview_'+i);
  div.setAttribute('path',album.name);
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

  if(album.name){
    div.appendChild(document.createTextNode(album.name.substring(0,12)));
  }
  return div;
}

//------------------------------------------------------------------------------
function preview_album(album,i,mode){

  div = document.createElement('div')
  src = base_path + 'i/no_image.gif';
  div.setAttribute('id','preview');
  div.appendChild(document.createTextNode(mode+' album'))
  div.appendChild(document.createElement('br'))

  if(mode == 'previous'){
    div.appendChild(makeHref('javascript:ajax.Start(gallery_load_images,"'+i+'")',makeImg(base_path + 'i/frew.gif',12,12,'move_button')))
  }

  div.appendChild(makeHref('javascript:ajax.Start(gallery_load_images,'+i+');',document.createTextNode(album.name)))

  if(mode == 'next'){
    div.appendChild(makeHref('javascript:ajax.Start(gallery_load_images,"'+i+'")',makeImg(base_path + 'i/ffwd.gif',12,12,'move_button')))
  }
  return div;
}

//------------------------------------------------------------------------------
function preview_image(current_image,i,mode){
  div = document.createElement('div')
  div.setAttribute('id','preview');

  src = current_image.fullpath;
  src = base_path+'image.vsp?'+setSid()+'image_id='+current_image.id+'&size=0';

  if(current_image.visibility == 1){
    var alt = current_image.name + '\r\n Public visible';
  }else{
    var alt = 'Private visible';
  }
  div.appendChild(makeHref('javascript:gallery.showImage("'+i+'")',makeImg(src,'','','img',alt)))

  if(mode == 'previous'){
    div.appendChild(makeHref('javascript:gallery.showImage("'+i+'")',makeImg(base_path + 'i/frew.gif',12,12,'move_button')))
  }

  if(mode == 'next'){
    div.appendChild(makeHref('javascript:gallery.showImage("'+i+'")',makeImg(base_path + 'i/ffwd.gif',12,12,'move_button')))
  }

  if(mode != 'previous' && mode != 'next'){
    chbox = makeCheckbox('image_id_'+i,current_image.id);

    div.appendChild(document.createElement('br'))
    if(sid != ''){
      div.appendChild(chbox)
    }
    //div.appendChild(document.createTextNode(current_image.name))
    if(sid != ''){
      //div.appendChild(document.createElement('br'))
      //div.appendChild(document.createTextNode(alt))
    }
  }
  return div;
}

//------------------------------------------------------------------------------
function preview_image_empty(){
  div = document.createElement('div')
  div.setAttribute('id','preview');

  div.appendChild(document.createTextNode(''))
  return div;
}


//------------------------------------------------------------------------------
gallery.makePanelHeader = function(title_str,txt_str,path_array,i){

  div = document.createElement('div');
  div.setAttribute('id','title');

  var path = document.createElement('div');

  for(var i=0;i<path_array.length;i++){
    var path_albums = document.createElement('span');
    path_albums.setAttribute('id',path_array[i][0]);
    path_albums.appendChild(document.createTextNode(path_array[i][1]));
    path.appendChild(path_albums);
    if(i+1 < path_array.length){
      path.appendChild(document.createTextNode(' > '));
    }
  }

  var title = document.createElement('h3');
  title.appendChild(document.createTextNode(title_str));

  txt = document.createElement('span');
  txt.appendChild(document.createTextNode(txt_str))
  txt.appendChild(document.createElement('br'))
  txt.appendChild(document.createElement('br'))
  //txt.appendChild(document.createTextNode(ds_current_album.list[i].description))


  div.appendChild(path);
  div.appendChild(txt);
  div.appendChild(title);

  return div;
}

//------------------------------------------------------------------------------
gallery.feed_rss_click = function(){
  feed_url('rss.xml');
}

//------------------------------------------------------------------------------
gallery.feed_rdf_click = function(){
  feed_url('index.rdf');
}

//------------------------------------------------------------------------------
gallery.feed_atom_click = function(){
  feed_url('atom.xml');
}


//------------------------------------------------------------------------------
feed_url = function(type){
  var base_url;
  if(page_location.indexOf('?') > -1){
    base_url = page_location.substring(0,page_location.indexOf('?'));
  }else if(page_location.indexOf('#') > -1){
    base_url = page_location.substring(0,page_location.indexOf('#'));
  }else{
    base_url = page_location;
  }

  if(ds_albums.current.name != null){
    current_album = '?'+ds_albums.current.name;
  }else{
    current_album = '';
  }
  location.href =  base_url + type + current_album;
}

//------------------------------------------------------------------------------
//------------------------------------------------------------------------------
//function makeImg(src,width,height,cclass,alt){
//  img = document.createElement('img')
//  img.setAttribute('src',src)
//  img.setAttribute('border',0)
//  if(width && width != ''){
//    img.setAttribute('width',width)
//  }
//  if(height && height != ''){
//    img.setAttribute('height',height)
//  }
//  if(cclass && cclass != ''){
//    img.setAttribute('id',cclass)
//  }
//  if(alt){
//    img.setAttribute('title',alt)
//  }
//  return img;
//}

//------------------------------------------------------------------------------
function makeTable(id,caption){
  t = document.createElement('table')
  if(id && id != ''){
    t.setAttribute('id',id);
  }
  if(caption && caption != ''){
    c = document.createElement('caption')
    c.appendChild(document.createTextNode(caption))
    t.appendChild(c)
  }
  return t;
}


////------------------------------------------------------------------------------
//function makeUl(id){
//  ul = document.createElement('ul')
//  ul.setAttribute('id',id)
//  return ul;
//}
//
////------------------------------------------------------------------------------
//function makeLi(title,id,url,cclass){
//  li = document.createElement('li')
//  li.setAttribute('id',id)
//
//  if(cclass && cclass == 'on'){
//    label = document.createElement('b');
//    label.appendChild(document.createTextNode(title));
//  }else if(typeof title == 'object'){
//    label = title;
//  }else{
//    label = document.createTextNode(title);
//  }
//  if(url && url != ''){
//    li.appendChild(makeHref(url,label));
//  }else{
//    li.appendChild(label)
//  }
//
//  return li;
//}
//
////------------------------------------------------------------------------------
//function setLi(id,value){
//  if(document.getElementById(id)){
//    li = document.getElementById(id)
//    li.className = value;
//  }
//}
//
////------------------------------------------------------------------------------
//function makeCheckbox(name,value){
//  ch = document.createElement('input');
//  ch.setAttribute('type','checkbox');
//  ch.setAttribute('name',name);
//  ch.setAttribute('id',name);
//  ch.setAttribute('value',value);
//
//  return ch;
//}
////------------------------------------------------------------------------------
//function returnIndexFirstChild(nodeList){
//  for(var i=0;i<nodeList.length;i++){
//    if(nodeList[i].nodeType == 1){
//      return i;
//    }
//  }
//}
//
////------------------------------------------------------------------------------
//function returnListOfNodes(nodeList){
//  list = new Object();
//  var x = 0;
//  for(var i=0;i<nodeList.length;i++){
//    if(nodeList[i].nodeType == 1){
//      list[x++] = nodeList[i];
//    }
//  }
//  list.length = x--;
//  return list;
//}


//------------------------------------------------------------------------------
function setSid(){
  if(sid != ''){
    return 'sid='+sid+'&';
  }
  return '';
}

//------------------------------------------------------------------------------
function strip_spaces(mystr) {
  var newstring = "";
  if (mystr.indexOf(' ') != -1) {
    var string = mystr.split(' ');
    for (var i=0;i<string.length;i++){
      if(string[i] != ''){
        newstring += ' ' + string[i];
      }
    }
    newstring = newstring.substring(1);
    return newstring;
  } else {
    return mystr;
  }
}

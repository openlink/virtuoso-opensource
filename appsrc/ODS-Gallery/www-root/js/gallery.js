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

var ds_albums = new dataSet();
var ds_current_album = new dataSet();

var gallery = new Object();
gallery.flickr = {};
gallery.flickr.status = '';
var gallery_path;

//------------------------------------------------------------------------------
gallery.init = function (path){

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
  if(location.hash && location.hash != '#'){
    gallery.current_state = location.hash.substring(1).split(':')
    page_location = location.href.substring(0,location.href.indexOf('#'))
  }

  gallery_path = path;
  $("wrapper").onclick = dispach;
  gallery.ajax.load_albums(gallery_path);

  gallery.rotator = new OAT.Rotator(505,400,{delay:1,step:2,numLeft:1,pause:1000,type:OAT.RotatorData.TYPE_LEFT},function(){});
  $("rotator_viewport").appendChild(gallery.rotator.div);

  var SlideShow_back = function(){
    reverse = function(){
      if(!gallery.rotator.running){
        gallery.rotator.options.type = OAT.RotatorData.TYPE_RIGHT;
        gallery.rotator.start();
        gallery.slideshow_status_update();
      }
    }
    gallery.rotator.callback = reverse;
    gallery.rotator.stop();

  }

  var SlideShow_stop = function(){
    if(gallery.rotator.running){
      gallery.rotator.callback = function(){};
      gallery.rotator.stop();
    }else{
      gallery.rotator.start();
    }
    gallery.slideshow_status_update();
  }

  var SlideShow_next = function(){
    reverse = function(){
      if(!gallery.rotator.running){
        gallery.rotator.options.type = OAT.RotatorData.TYPE_LEFT;
        //gallery.rotator.start();
        gallery.slideshow_status_update();
      }
    }
    if(!gallery.rotator.running){
      gallery.rotator.options.type = OAT.RotatorData.TYPE_LEFT;
      gallery.rotator.start();
      gallery.slideshow_status_update();
    }else{
      gallery.rotator.callback = reverse;
      gallery.rotator.stop();
    }

  }

  OAT.Dom.attach("SlideShow_back",'click',SlideShow_back);
  OAT.Dom.attach("SlideShow_stop",'click',SlideShow_stop);
  OAT.Dom.attach("SlideShow_next",'click',SlideShow_next);
  OAT.Dom.attach("images_import_flickr",'click',gallery.ajax.flickr_login_link);
  OAT.Dom.attach("images_import_flickr_list",'click',gallery.ajax.flickr_get_photos_list);
  OAT.Dom.attach("images_import_flickr_save",'click',gallery.ajax.flickr_save_photos);
  OAT.Dom.attach("images_export_flickr",'click',gallery.ajax.flickr_login_link);
  OAT.Dom.attach("images_export_flickr_send",'click',gallery.ajax.flickr_send_photos);



  var slider = new OAT.Slider("slider_btn",{minPos:10,maxPos:140});
  slider.onchange = function(value) {
      gallery.rotator.options.pause = value * 100
      gallery.slideshow_status_update();
    }
  slider.init();

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
function path_set_folder(path){
  if(path != ''){
    path = '#/' + path + '/';
  }else{
    path = '#';
  }
  location.href = page_location + path;
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
gallery.closePanels = function(){

}


//------------------------------------------------------------------------------
gallery.albums_click = function(el){
  current_id = getId(el.id);

  gallery.setCurrent(current_id);
  //ajax.Start(gallery_load_images,current_id);
  gallery.ajax.load_images(current_id);
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
gallery.new_album_tab_click = function (){

  gallery.managePanels('new_album');
  $('new_album_description').value = '';
  $('new_album_name').value = '';
  var d = new Date();
  var year = d.getFullYear();
  var month = d.getMonth()
  var month = d.getDay()

  $('new_album_pub_date_day').selectedIndex = d.getDate()-1;
  $('new_album_pub_date_month').selectedIndex = d.getMonth();
  $('new_album_pub_date_year').selectedIndex = String(d.getFullYear()).substring(3)-1;
  
  gallery.nav.tabs(2);
}

//------------------------------------------------------------------------------
gallery.new_album_close_click = function(){
 gallery.my_albums_tab_click();
 gallery.nav.tabs(1);
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
  //ajax.Start(gallery_new_album,'');
  gallery.ajax.new_album();
}

//------------------------------------------------------------------------------
gallery.new_album_name_click = function(el){

}

//------------------------------------------------------------------------------
gallery.link_edit_album_click = function (){

  gallery.managePanels('edit_album');

  document.getElementById('edit_album_name_old').value = ds_albums.current.name;
  document.getElementById('edit_album_name').value = ds_albums.current.name;

  if((typeof ds_albums.current.description) != 'undefined'){
    document.f1.edit_album_description.value = ds_albums.current.description;
  }
  var t_date = sdate2obj(ds_albums.current.pub_date);

  $('edit_album_pub_date_year').selectedIndex  = String(t_date.elements[0]).substring(3,4);
  $('edit_album_pub_date_day').selectedIndex   = Number(t_date.elements[2])-1;
  $('edit_album_pub_date_month').selectedIndex = Number(t_date.elements[1])-1;

  if(ds_albums.current.visibility == 1){
    $('album_visibility_all').checked = true;
  }else{
    $('album_visibility_me').checked = true;
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
  //ajax.Start(gallery_edit_album,'');
  gallery.ajax.edit_album();
}
//------------------------------------------------------------------------------
gallery.link_images_upload_click = function(){
  gallery.managePanels('image_upload')
  var id = returnIndexFirstChild(gallery.images_upload.childNodes)
  gallery.images_upload.childNodes[id].src=base_path+"upload.vspx?sid="+sid+"&realm=wa&album="+ds_albums.current.name;
}

//------------------------------------------------------------------------------
gallery.images_upload_cancel = function (){
  this.images_upload.hide();
  this.images.show();
  gallery.ajax.load_images(ds_albums.current.index);
}

//------------------------------------------------------------------------------
gallery.images_upload_finish = function(id){
  gallery.ajax.load_images(ds_albums.current.index);
}

//------------------------------------------------------------------------------
gallery.edit_album_cancel = function (){
  this.images.show();
  this.edit_album.hide();
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
  gallery.images_upload.hide();
  gallery.showImagesInside();
}

//------------------------------------------------------------------------------
gallery.showImagesInside = function (){

  gallery.managePanels('showImages');

    this.images.clear();
    this.images.show();
    this.image.hide();

    gallery.hideSlideShow();

  var txt = '';
  if(typeof ds_albums.current.description != 'undefined'){
    txt = ds_albums.current.description + ' / ';
  }
  txt += ds_current_album.list.length+' pictures';
  $('info_discription').innerHTML = txt;
  $('path_my_albums').innerHTML = 'My Albums > ';
  $('path_pub_date').innerHTML = sdate2obj(ds_albums.current.pub_date).year + ' > ';
  $('path_album_name').innerHTML = ds_albums.current.name;
  $('path_image_name').innerHTML = "";
  $('caption').innerHTML = 'Choose an image to view';
  gallery.info.show();

    for(var r=0;r<ds_current_album.list.length;r++){
    new_coll = preview_image(r);
      this.images.appendChild(new_coll);
    }
    if(ds_current_album.list.length == 0){
        block = document.createElement('div');
        block.setAttribute('id','message');
        block.appendChild(document.createTextNode('No images in this album. Click "Add images" to add new'));
        this.images.appendChild(block);
    }

    //Navigation prev<->next album
    var i = ds_albums.current.index;
  $('preview_left').innerHTML = "";
  $('preview_right').innerHTML = "";
    if(i>0){
    $('preview_left').appendChild(preview_album(ds_albums.list[i-1],i-1,'previous'));
    }
    if(i<ds_albums.list.length-1){
    $('preview_right').appendChild(preview_album(ds_albums.list[Number(i)+1],Number(i)+1,'next'));
    }
    path_set_folder(ds_albums.current.name);
}

//------------------------------------------------------------------------------
gallery.showImage = function(i){
  var current_image = ds_current_album.list[i];

    gallery.images.hide();

    gallery.image.innerHTML = "";
  if(current_image.source){
    src = current_image.source.replace('_t.jpg','.jpg');
  }else{
    src = current_image.path; //ds_current_album.list[i].path;
    src = base_path+'image.vsp?'+setSid()+'image_id='+current_image.id
    path_set_file(current_image.name);
  }

    gallery.image.appendChild(makeImg(src));

    gallery.image.show();
    gallery.hideAlbums();

  var txt = '';
  if(typeof ds_albums.current.description != 'undefined'){
    txt = ds_albums.current.description + ' / ';
  }
  txt += (Number(i)+Number(1)) + ' of '+ ds_current_album.list.length+' pictures';
  $('info_discription').innerHTML = txt;

  $('path_my_albums').innerHTML = 'My Albums > ';
  $('path_pub_date').innerHTML = sdate2obj(ds_albums.current.pub_date).year + ' > ';
  $('path_album_name').innerHTML = ds_albums.current.name + ' > ';
  $('path_image_name').innerHTML = current_image.name;
  $('caption').innerHTML = current_image.description;
  gallery.managePanels('showImage');
  gallery.hideSlideShow();

    ds_current_album.setCurrent(i);
    gallery.show_exif();

    //Navigation previous<->next
  $('preview_left').innerHTML = "";
  $('preview_right').innerHTML = "";
    if(i>0){
    $('preview_left').appendChild(preview_image(i-1,'previous'));
    }
    if(i<ds_current_album.list.length-1){
    $('preview_right').appendChild(preview_image(Number(i)+1,'next'));
    }

    document.f1.new_comment.value = '';
    gallery.comments.show();
  gallery.showTags();

  gallery.ajax.image_get_comments(current_image.id)


}


//------------------------------------------------------------------------------
gallery.showComments = function(comments){
  this.comments_list.innerHTML = '';
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
gallery.showTags = function(){
  gallery.tags.show();
  var tags = ds_current_album.current.private_tags
  var tags_list = $('tags_list')
  tags_list.innerHTML = '';

  if(tags == null){
    return;
  }

  for(var i = 0;i<tags.length;i++){
    gallery.addTag(tags[i]);
  }
  if(sid != ''){
    OAT.Dom.show('tags_edit');
  }
}


//------------------------------------------------------------------------------
gallery.addTag = function(tag,first){
  var tags_list = $('tags_list')
  document.f1.new_tag.value = '';

  var div = document.createElement('span');
  var txt = document.createElement('b');
  var edit = document.createElement('span');
  if(tags_list.childNodes.length){
    div.appendChild(document.createTextNode(', '));
  }else{
    div.appendChild(document.createTextNode(' '));
  }
  tags_list.appendChild(div);
  div.appendChild(txt);
  if(sid != ''){
  div.appendChild(edit);
  }
  txt.appendChild(document.createTextNode(tag));
  edit.appendChild(document.createTextNode('[Delete]'));
  OAT.Dom.attach(edit,'click',gallery.delete_tag_click)
  }

//------------------------------------------------------------------------------
gallery.delete_tag_click = function(e){
  if (!e) var e = window.event
  var el = (e.target) ? e.target : e.srcElement

  if(confirm('Are you sure that you want to detele this tag?')){
    var tag = el.parentNode.childNodes[1].innerHTML;
   gallery.ajax.image_remove_tags(ds_current_album.current.id,tag);
  }
}

//------------------------------------------------------------------------------
gallery.tags_is_unique = function(tags,tag){
  if(tags == null){
    return 1;
  }
  for(var i=0;i<tags.length;i++){
    if(tags[i] == tag){
      return 0;
    }
  }
  return 1;
}

//------------------------------------------------------------------------------
gallery.tag_images_tab_click = function(){
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
  tags = prompt('Insert public tags here','Tags');
  gallery.ajax.tag_images(ids,tags);
}


//------------------------------------------------------------------------------
gallery.tag_images_tab_finish = function(){

  }

//------------------------------------------------------------------------------
gallery.bnt_new_tag_click = function(){
  var new_tag = document.f1.new_tag.value
  if(new_tag == ''){
    alert('Please, insert at least one word for tag');
    return;
  }
  if(!gallery.tags_is_unique(ds_current_album.current.private_tags, new_tag)){
    alert('This tag allready exists. Please, change it');
    return;
  }
  gallery.ajax.image_add_tags(ds_current_album.current.id,new_tag);
}


//------------------------------------------------------------------------------
gallery.showAlbumsInfo = function(i){
  //if(ds_albums.current.is_own == 1){
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
  gallery.info.show();
}

//------------------------------------------------------------------------------
gallery.path_my_albums_click = function(){
  gallery.my_albums_tab_click();
}

//------------------------------------------------------------------------------
gallery.path_album_name_click = function(){
  gallery.link_show_images_click();
}


//------------------------------------------------------------------------------
gallery.link_show_images_click = function(){
  path_set_folder(ds_albums.current.name);
  gallery.showImages();
}
//------------------------------------------------------------------------------
gallery.btn_slideshow_click = function(){

  gallery.managePanels('images_slideshow')
  $('caption').innerHTML = 'Slideshow';
  $('preview_left').innerHTML = "";
  $('preview_right').innerHTML = "";

  if(ds_current_album.list.length < 2){
    gallery.showImages();
    return;
  }

  this.slideshow.show();

      for(var i=0;i<ds_current_album.list.length;i++){
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
gallery.hideSlideShow = function(){
  if(gallery.rotator){
    gallery.rotator.stop();
  }
  gallery.slideshow.hide();
}

//------------------------------------------------------------------------------
gallery.slideshow_status_update = function(){
  if(this.rotator.running){
    $('label_slideshow_status').innerHTML = "Play with interval of "+(this.rotator.options.pause/1000)+" seconds";
  }else{
    $('label_slideshow_status').innerHTML = "Show is stopped";
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
gallery.hideAlbums = function(){
  gallery.albums.hide();
  gallery.albums_list.hide();
  gallery.albums_man.hide();
}

//------------------------------------------------------------------------------
gallery.my_albums_tab_click = function (){
  path_set_folder('');
  gallery.managePanels('my_albums')
}

//------------------------------------------------------------------------------
gallery.wa_click = function (){
  location.href = wa_home_link + 'services.vspx?sid='+sid+'&realm=wa';
}

//------------------------------------------------------------------------------
gallery.home_click = function (){
  location.href = page_location;
  setTimeout(100,function(){location.reload();})
}

//------------------------------------------------------------------------------
gallery.link_show_exif_click = function(){
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
    gallery.image_info.show();
    gallery.image_info.innerHTML = 'Loading ...';

    gallery.ajax.image_get_exif(ds_current_album.current.id);
  }
}

//------------------------------------------------------------------------------
gallery.link_image_edit_click = function(){
  gallery.image_info.hide();
  gallery.image_edit.show();

  document.f1.edit_image_description.value = ds_current_album.current.description;
  document.f1.edit_image_name.value = ds_current_album.current.name;
  document.f1.edit_image_name_old.value = ds_current_album.current.name;
  document.f1.edit_image_path.value = ds_albums.current.fullpath;

  if(ds_current_album.current.visibility == 1){
    document.f1.image_visibility[0].checked = true
  }else{
    document.f1.image_visibility[1].checked = true;
  }
}

//------------------------------------------------------------------------------
gallery.btn_image_edit_click = function(){
  gallery.ajax.image_edit();
}

//------------------------------------------------------------------------------
gallery.image_edit_finish = function(res){


}
//------------------------------------------------------------------------------
gallery.btn_image_edit_cancel_click = function(){
  gallery.image_edit.hide();
}




//------------------------------------------------------------------------------
gallery.link_delete_images_click = function(){

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
  gallery.ajax.delete_images(ids);
}


//------------------------------------------------------------------------------
gallery.link_delete_image_click = function(){

  if(!confirm('Are you sure that you want to delete selected images?')){
    return;
  }
  gallery.ajax.delete_images(Array(ds_current_album.current.id));
}


//------------------------------------------------------------------------------
gallery.link_delete_album_click = function(){
  if(!confirm('Are you sure that you want to delete current Album?')){
    return;
  }
  gallery.ajax.delete_album(ds_albums.current.id);
}

//------------------------------------------------------------------------------
gallery.bnt_new_comment_click = function(){

  var comment = new Object();
  comment.comment_id = '';
  comment.create_date = '';
  comment.user_id = '';
  comment.user_name = '';
  comment.modify_date = '';
  comment.text = document.f1.new_comment.value
  comment.res_id = ds_current_album.current.id;

  gallery.ajax.image_add_comments(comment);
}

//------------------------------------------------------------------------------
gallery.get_image = function(id){
  gallery.ajax.load_images(ds_albums.current.index);
}



//------------------------------------------------------------------------------
gallery.showError = function (ex){

    var s = '<img src="/photos/res/i/close-24.gif" class="close_button" title="Close this panel" OnClick="gallery.error_box.hide()" />';

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
  OAT.Dom.hide('wait');

}


//------------------------------------------------------------------------------
function showPreviewNav(){
  div = document.createElement('div');
  div.setAttribute('id','preview_nav');
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

  src = base_path + 'i/no_image.gif';
  var div = OAT.Dom.create('div');
  div.appendChild(document.createTextNode(mode+' album'))
  div.appendChild(document.createElement('br'))

  if(mode == 'previous'){
    div.appendChild(makeHref('javascript:gallery.ajax.load_images("'+i+'")',makeImg(base_path + 'i/frew.gif',12,12,'move_button')))
  }
  div.appendChild(makeHref('javascript:gallery.ajax.load_images('+i+');',document.createTextNode(album.name)))
  if(mode == 'next'){
    div.appendChild(makeHref('javascript:gallery.ajax.load_images("'+i+'")',makeImg(base_path + 'i/ffwd.gif',12,12,'move_button')))
  }
  return div;
}

//------------------------------------------------------------------------------
function preview_image(i,mode){
  var current_image = ds_current_album.list[i];

  src = current_image.fullpath;
  if(current_image.source){
    src = current_image.source;
  }else{
  src = base_path+'image.vsp?'+setSid()+'image_id='+current_image.id+'&size=0';
  }
  if(current_image.visibility == 1){
    var alt = current_image.name + '\r\n Public visible';
  }else{
    var alt = 'Private visible';
  }
  var div = OAT.Dom.create('div');
  //div.appendChild(makeHref('javascript:gallery.showImage("'+i+'")',makeImg(src,'','','img',alt)))
  image_html = makeImg(src,'','','img',alt);
  div.appendChild(image_html);
  OAT.Dom.attach(image_html,'click',function(){
    gallery.showImage(i);
  })
  div.current_image = current_image;

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
}
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
gallery.feed_xbel_click = function(){
  feed_url('xbel.xml');
}

//------------------------------------------------------------------------------
gallery.feed_mrss_click = function(){
  feed_url('mrss.xml');
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
gallery.link_images_import_click = function(){
  gallery.managePanels('images_import');
  if(gallery.flickr.status == 'logged'){
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
  $('path_album_name').innerHTML = ds_albums.current.name;
  $('path_image_name').innerHTML = "";
  $('caption').innerHTML = 'Import images from Flickr';
  $('preview_left').innerHTML = "";
  $('preview_right').innerHTML = "";

}

//------------------------------------------------------------------------------
gallery.link_images_export_click = function(){
  gallery.managePanels('images_export');
  $('info_discription').innerHTML = "";
  $('path_my_albums').innerHTML = 'My Albums > ';
  $('path_pub_date').innerHTML = sdate2obj(ds_albums.current.pub_date).year + ' > ';
  $('path_album_name').innerHTML = ds_albums.current.name;
  $('path_image_name').innerHTML = "";
  $('caption').innerHTML = 'Export images from Flickr';
  $('preview_left').innerHTML = "";
  $('preview_right').innerHTML = "";

}

//------------------------------------------------------------------------------
gallery.managePanels = function(action){

  OAT.Dom.hide('images_import');
  OAT.Dom.hide('images_export');

  if(action == 'my_albums'){
    gallery.albums.show();
    gallery.showAlbumsInfo();
    gallery.albums_list.show();
    if(sid != ''){
      gallery.albums_man.show();
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

  }else if(action == 'showImages'){
    if(sid != ''){
      OAT.Dom.show('care_edit_album');
    }
    OAT.Dom.show('care_view_album');
    OAT.Dom.hide('care_view_mode');
    OAT.Dom.hide('care_nav_image');
      OAT.Dom.hide('care_edit_image');
      gallery.comments.hide();
    gallery.tags.hide();
      gallery.image_info.hide();

  }else if(action == 'showImage'){
      OAT.Dom.hide('care_edit_album');
    OAT.Dom.show('care_nav_image');
    if(sid != ''){
      OAT.Dom.show('care_edit_image');
    }
      OAT.Dom.show('care_view_mode');
    OAT.Dom.hide('care_view_album');

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
    OAT.Dom.show('care_my_albums');

    OAT.Dom.show('new_album');

  }else if(action == 'image_upload'){
    OAT.Dom.show('images_upload');
    OAT.Dom.hide('edit_album');
    gallery.images.hide();

  }else if(action == 'images_slideshow'){
    OAT.Dom.show('care_nav_image');
    OAT.Dom.hide('care_view_album');
    gallery.images.hide();
    gallery.image.hide();
    gallery.tags.hide();

    this.images_upload.hide();
    this.edit_album.hide();
    //this.info.hide();
    this.comments.hide();

    OAT.Dom.show('care_slideshow');
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
gallery.ajax.load_albums = function(path){
  call = proxies.SOAP.dav_browse;
  prepare = function(){
    return Array(sid,gallery_id,path);
  };
  finish = function(p){

    ds_albums.loadList(p.albums);
    ds_albums.current.is_own = p.is_own;
    ds_albums.current.owner_name = p.owner_name;

    if(!jump_to()){
       gallery.hideAlbums();
    }
    gallery.showAlbumsInfo();
    gallery.albums.innerHTML="";
    $('my_albums_list').innerHTML="";
    for(var r=0;r<ds_albums.list.length;r++){
      new_coll = preview_collection(ds_albums.list[r],r);
      gallery.albums.appendChild(new_coll);
      album_list = OAT.Dom.create('li');
      album_list.innerHTML = ds_albums.list[r].name.substring(0,12);
      album_list.id = "my_albums_list_"+r;
      $('my_albums_list').appendChild(album_list);
    };
    gallery.managePanels('my_albums');

  };

  gallery.ajax(prepare,call,finish);
};


//------------------------------------------------------------------------------
gallery.my_albums_list_click = function(el){
  gallery.albums_click(el);
}

//------------------------------------------------------------------------------
gallery.my_albums_list_more_click = function(){
  gallery.home_click();
}

//------------------------------------------------------------------------------
gallery.ajax.new_album = function(){

  call = proxies.SOAP.create_new_album;
  prepare =function() {
            if(document.f1.visibility[0].checked){
              v=1
            }else{
              v=0
            };

            return Array(sid,gallery_id,
                         home_path,
                         document.getElementById('new_album_name').value,
                         v,
                         document.getElementById('new_album_pub_date_year').value + '-' + document.getElementById('new_album_pub_date_month').value + '-' + document.getElementById('new_album_pub_date_day').value + 'T00:00:00',
                         document.getElementById('new_album_description').value);
  };
  finish = function(dav_lines){
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

    album_list = OAT.Dom.create('li');
    album_list.innerHTML = ds_albums.list[r].name.substring(0,12);
    album_list.id = "my_albums_list_"+r;
    $('my_albums_list').appendChild(album_list);

    gallery.setCurrent(r);
    gallery.showImages();
    gallery.link_images_upload_click();
    gallery.new_album.hide();
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
            return Array(sid,gallery_id,
                         home_path,
                         $('edit_album_name_old').value,
                         $('edit_album_name').value,
                         v,
                         $('edit_album_pub_date_year').value + '-' + $('edit_album_pub_date_month').value + '-' + $('edit_album_pub_date_day').value + 'T00:00:00',
                         $('edit_album_description').value);
           };
  finish = gallery.editCollections;

  gallery.ajax(prepare,call,finish);
}

//------------------------------------------------------------------------------
gallery.ajax.delete_album = function(id){

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
    OAT.Dom.hide('wait');
  };
  gallery.ajax(prepare,call,finish);
  }

//------------------------------------------------------------------------------
gallery.image_get_image = function(id){

  prepare = function() { return Array(sid,gallery_id,id)};
  call = proxies.SOAP.get_image;
  finish = function(p) {
            ds_current_album.addImageToList(p);
            gallery.showImagesInside();
          };

  gallery.ajax(prepare,call,finish);
};

//------------------------------------------------------------------------------
gallery.ajax.image_edit = function(id){

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
    if(res != 0){
      ds_current_album.editImageInList(res);
      alert('Succesfull')
      gallery.showImage(ds_current_album.current.index);

    }else{
      alert('Problem');
    }
  };
  gallery.ajax(prepare,call,finish);
}

//------------------------------------------------------------------------------
gallery.ajax.delete_images = function(in_ids){

  call = proxies.SOAP.dav_delete;
  prepare = function() {
    return Array(sid,gallery_id,'r',in_ids)
  };
  finish = function(out_ids) {
    var list = ds_current_album.list;
    for(var i=0;i<list.length;i++){
      for(var x=0;x<out_ids.length;x++){
        if(list[i].id == out_ids[x]){
          list.splice(i,1);
      }
    }
  }
    gallery.showImagesInside();
  };

  gallery.ajax(prepare,call,finish);
};

//------------------------------------------------------------------------------
gallery.ajax.image_get_comments = function(id){

  call = proxies.SOAP.get_comments;
  prepare = function() {
    return Array(sid,gallery_id,id)
  };
  finish = function(comments){
    gallery.comments_list.innerHTML = '';
    if(comments == null){
      return;
}
    for(var i = 0;i<comments.length;i++){
      gallery.addComment(comments[i]);
    }
  }
  gallery.ajax(prepare,call,finish);
};

//------------------------------------------------------------------------------
gallery.ajax.image_add_comments = function(comment){

  call = proxies.SOAP.add_comment;
  prepare = function() {
    return Array(sid,gallery_id,comment)
  };
  finish = function(p) {
    gallery.addComment(p)
  };

  gallery.ajax(prepare,call,finish);
};

//------------------------------------------------------------------------------
gallery.ajax.tag_images = function(p1,p2){

  call = proxies.SOAP.tag_images;
  prepare = function() {
    return Array(sid,gallery_id,home_url,p1,p2)
  };
  finish = function(tag){
    for(var i=0;i<ds_current_album.list.length;i++){
      $('image_id_'+i).checked = false;
      ds_current_album.list[i].private_tags[ds_current_album.list[i].private_tags.length] = tag;
    }
    alert('Done');
  };
  gallery.ajax(prepare,call,finish);
};

//------------------------------------------------------------------------------
gallery.ajax.image_add_tags = function(image_id,new_tag){

  call = proxies.SOAP.tag_image;
  prepare = function() {
    return Array(sid,gallery_id,home_url,image_id,new_tag)
  };
  finish = function(p) {
    ds_current_album.current.private_tags = p;
    gallery.showTags()
  };

  gallery.ajax(prepare,call,finish);
};

//------------------------------------------------------------------------------
gallery.ajax.image_remove_tags = function(image_id,tag){

  call = proxies.SOAP.remove_tag_image;
  prepare = function() {
    return Array(sid,gallery_id,image_id,tag);
  };
  finish = function(p) {
    ds_current_album.current.private_tags = p;
    gallery.showTags();
  };

  gallery.ajax(prepare,call,finish);
};

//------------------------------------------------------------------------------
gallery.ajax.image_get_exif = function(id){

  call = proxies.SOAP.get_attributes;
  prepare = function() {
    return Array(sid,gallery_id,id)
  };
  finish = function(out_data) {
    var t = document.createElement('table');
    t.setAttribute('id','exif');
    for(var i=0;i<out_data.length;i++){
      var tr = t.insertRow(i);
      var td1 = tr.insertCell(0);
      var td2 = tr.insertCell(1);

      td1.appendChild(document.createTextNode(out_data[i].name+': '));
      td2.appendChild(document.createTextNode(out_data[i].value!='undefined'?out_data[i].value:''));
    }
    gallery.image_info.clear();
    gallery.image_info.appendChild(t);
  };
  gallery.ajax(prepare,call,finish);
};


//------------------------------------------------------------------------------
gallery.ajax.flickr_login_link = function(e){
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
    OAT.Dom.show('wait');
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

    OAT.Dom.hide('wait');
  };
  gallery.ajax(prepare,call,finish);
};

//------------------------------------------------------------------------------
gallery.ajax.flickr_get_photos_list = function(){
  if(gallery.flickr.status == ''){
    alert('Please, first sing in Flickr');
    return;
  }
  call = proxies.SOAP.flickr_get_photos_list;
  prepare = function() {
    OAT.Dom.show('wait');
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
    OAT.Dom.hide('wait');
    return;
  };
  gallery.ajax(prepare,call,finish);
};


//------------------------------------------------------------------------------
gallery.ajax.flickr_save_photos = function(){
  var ids = new Array();
  if(gallery.flickr.status == ''){
    alert('Please, first sing in Flickr');
    return;
  }
  for(var i=0;i<ds_current_album.list.length;i++){
    if($('image_id_'+i).checked){
      ids[ids.length]= $('image_id_'+i).parentNode.current_image.id + '_' + $('image_id_'+i).parentNode.current_image.secret;
    }
  }
  if(ids.length == 0){
    alert('Please, first select one or more photos');
    return;
  }

  call = proxies.SOAP.flickr_save_photos;
  prepare = function() {
    OAT.Dom.show('wait');
    return Array(sid,ds_albums.current.id,ids);
  };
  finish = function(out_data) {
    //OAT.Dom.show('images_import_flickr_list');
    //OAT.Dom.hide('images_import_flickr_save');
    OAT.Dom.addClass('images_import_flickr_save','link_disabled');
    OAT.Dom.removeClass('images_import_flickr_save','link');
    OAT.Dom.addClass('images_import_flickr_list','link');
    OAT.Dom.removeClass('images_import_flickr_list','link_disabled');
    gallery.ajax.load_images(ds_albums.current.index);
    return;
  };
  gallery.ajax(prepare,call,finish);
};

//------------------------------------------------------------------------------
gallery.ajax.flickr_send_photos = function(){
  if(gallery.flickr.status == ''){
    alert('Please, first sing in Flickr');
    return;
  }
  gallery.error_box.clear();
  var ids = new Array();
  for(var i=0;i<ds_current_album.list.length;i++){
    if($('image_id_'+i).checked){
      ids[ids.length]= $('image_id_'+i).parentNode.current_image.id;
    }
  }
  if(ids.length == 0){
    alert('Please, first select one or more photos');
    return;
  }

  call = proxies.SOAP.flickr_send_photos;
  prepare = function() {
    OAT.Dom.show('wait');
    return Array(sid,ids);
  };
  finish = function(out_data) {
    url = "http://www.flickr.com/tools/uploader_edit.gne?ids=" + out_data
    flickr_window = window.open(url,'flickr_login',"resizable=1,width=900,height=600,top=100,left=100,scrollbars=1,location=0,status=1");

    for(var i=0;i<ds_current_album.list.length;i++){
      if($('image_id_'+i).checked){
        $('image_id_'+i).checked = false
      }
    }
    OAT.Dom.hide('wait');
    return;
  };
  gallery.ajax(prepare,call,finish);
};

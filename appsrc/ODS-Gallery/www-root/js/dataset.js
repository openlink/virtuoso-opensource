//------------------------------------------------------------------------------
// DataSets
//------------------------------------------------------------------------------
var dataSet = new Object();


//------------------------------------------------------------------------------
dataSet = function(obj,filter){
  this.list = new Array();
  this.current = new Object();
  this.current.name = null;
  this.current.list = new Array();
  this.current.list.current = new Object();
  this.current.list.id;
  this.object = obj;
  this.filter = filter;

}

//------------------------------------------------------------------------------
dataSet.prototype.loadList = function(dav_lines){
  this.list = dav_lines;
return;

  this.list = new Array();

  if(dav_lines == null){
    return
  }

  dav_lines = dav_lines


  for(var r=0;r<dav_lines.length;r++){

    if(dav_lines[r].type == this.filter){
      this.list[this.list.length] = dav_lines[r];
    }
  }
}

//------------------------------------------------------------------------------
dataSet.prototype.addAlbumToList = function(dav_lines){

  if((typeof dav_lines == 'object') && dav_lines.id > 0){
    this.list[this.list.length] = dav_lines;
    return true;
  }else{
    return false;
  }
}

//------------------------------------------------------------------------------
dataSet.prototype.editAlbumToList = function(dav_lines){

  if((typeof dav_lines == 'object') && dav_lines.id > 0){
    this.list[this.current.index] = dav_lines;
    return true;
  }else{
    return false;
  }
}

//------------------------------------------------------------------------------
dataSet.prototype.addImageToList = function(obj){

  var res = this.checkNameExist(obj.name);
  if(res != -1){
    // Replace old object
    this.list[res] = obj;
  }else{
    // Add new object
    this.list[this.list.length] = obj;
  }

}


//------------------------------------------------------------------------------
dataSet.prototype.editImageInList = function(obj){

  if((typeof obj == 'object')){
    this.list[this.current.index] = obj;
  }else{
    alert('nema');
  }

}

//------------------------------------------------------------------------------
dataSet.prototype.removeImageFromList = function(ids){

  for(var i=0;i<this.list.length;i++){
    for(var x=0;x<ids.length;x++){
      if(this.list[i].id == ids[x]){
        this.list.splice(i,1);
      }
    }
  }
  gallery.showImagesInside();
}

//------------------------------------------------------------------------------
dataSet.prototype.removeAlbumFromList = function(ids){

  for(var i=0;i<this.list.length;i++){
    for(var x=0;x<ids.length;x++){
      if(this.list[i].id == ids[x]){
        this.list.splice(i,1);
        return true;
      }
    }
  }
  return false;
}

//------------------------------------------------------------------------------
dataSet.prototype.checkNameExist = function (name){

  for(var i=0;i < this.list.length;i++){
    if(this.list[i].name == name) {
      return i;
    }
  }
  return -1;
}
//------------------------------------------------------------------------------
dataSet.prototype.setCurrent = function(current_id){

  this.current.fullpath  = this.list[current_id].fullpath;
  this.current.name  = this.list[current_id].name;
  this.current.index = current_id;
  this.current.id    = this.list[current_id].id;
  this.current.pub_date = this.list[current_id].pub_date;
  this.current.description = this.list[current_id].description;
  this.current.visibility = this.list[current_id].visibility;
}


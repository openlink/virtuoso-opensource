/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2014 OpenLink Software
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

//------------------------------------------------------------------------------
// DataSets
//------------------------------------------------------------------------------
var dataSet = new Object();


//------------------------------------------------------------------------------
dataSet = function(){
  this.list = new Array();
  this.settings = new Object();
  this.current = new Object();
  this.current.name = null;
  this.current.list = new Array();
  this.current.list.current = new Object();
  this.current.list.id;
}

//------------------------------------------------------------------------------
dataSet.prototype.loadList = function(dav_lines)
{
  this.list = dav_lines;
}

//------------------------------------------------------------------------------
dataSet.prototype.addAlbumToList = function(dav_lines)
{
  if ((typeof dav_lines == 'object') && dav_lines.id > 0)
  {
    this.list[this.list.length] = dav_lines;
    return true;
  }else{
    return false;
  }
}

//------------------------------------------------------------------------------
dataSet.prototype.editAlbumToList = function(dav_lines)
{
  if ((typeof dav_lines == 'object') && dav_lines.id > 0)
  {
    this.list[this.current.index] = dav_lines;
    return true;
  }else{
    return false;
  }
}

//------------------------------------------------------------------------------
dataSet.prototype.addImageToList = function(obj)
{
  var res = this.checkNameExist(obj.name);
  if (res != -1)
  {
    // Replace old object
    this.list[res] = obj;
  }else{
    // Add new object
    this.list[this.list.length] = obj;
  }
}

//------------------------------------------------------------------------------
dataSet.prototype.editImageInList = function(obj)
{
  if ((typeof obj == 'object'))
  {
    this.list[this.current.index] = obj;
  }else{
    alert('nema');
  }

}

//------------------------------------------------------------------------------
dataSet.prototype.removeImageFromList = function(ids)
{
  for(var i=0;i<this.list.length;i++)
  {
    for(var x=0;x<ids.length;x++)
    {
      if(this.list[i].id == ids[x])
      {
        this.list.splice(i,1);
      }
    }
  }
  gallery.showImagesInside();
}

//------------------------------------------------------------------------------
dataSet.prototype.removeAlbumFromList = function(ids)
{
  for(var i=0;i<this.list.length;i++)
  {
    for(var x=0;x<ids.length;x++)
    {
      if(this.list[i].id == ids[x])
      {
        this.list.splice(i,1);
        return true;
      }
    }
  }
  return false;
}

//------------------------------------------------------------------------------
dataSet.prototype.checkNameExist = function (name)
{
  for(var i=0;i < this.list.length;i++)
  {
    if(this.list[i].name == name)
    {
      return i;
    }
  }
  return -1;
}

//------------------------------------------------------------------------------
dataSet.prototype.setCurrent = function(current_id)
{
  this.current = this.list[current_id];
  this.current.index = current_id;
  return;
  this.current.fullpath  = this.list[current_id].fullpath;
  this.current.name  = this.list[current_id].name;
  this.current.index = current_id;
  this.current.id    = this.list[current_id].id;
  this.current.pub_date = this.list[current_id].pub_date;
  this.current.description = this.list[current_id].description;
  this.current.visibility = this.list[current_id].visibility;
}


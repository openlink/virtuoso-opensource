--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2012 OpenLink Software
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
-- [FunctionName]File procedures take filename as parameter and save modified content into another file (or into the same file, if new file name is not entered)
create procedure test11 ()
{
  -- params: filename (in root), width, height, x, y
  return "IM CropImageFile" ('aziz.jpg', 100, 100, 100, 100, 'aziz2.jpg');
}
;

create procedure test12 ()
{
  -- params: filename (in root), rotation degrees
  return "IM RotateImageFile" ('aziz.jpg', 10.1, 'aziz2.jpg');
}
;

create procedure test13 ()
{
  -- params: filename (in root), new image x resolution, new image y resolution, blur
  return "IM ResampleImageFile" ('aziz.jpg', 1.5, 2.5, 1.1, 13, 'aziz2.jpg');
}
;

create procedure test14 ()
{
  -- params: filename (in root), number of columns, number of rows, blur
  return "IM ResizeImageFile" ('aziz.jpg', 100, 100, 1.1, 13, 'aziz2.jpg');
}
;

create procedure test15 ()
{
  -- params: filename (in root), number of columns, number of rows
  return "IM ThumbnailImageFile" ('aziz.jpg', 100, 100, 13, 'aziz2.jpg');
}
;

create procedure test16 ()
{
  -- params: filename (in root), width, height, x, y
  return "IM GetImageFileAttribute" ('aziz.jpg', 'EXIF:XResolution');
}
;


-- [FunctionName]Blob procedures take content and content length as parameters and return modified content as result
create procedure test21 ()
{
  declare _content any;
  declare _mime varchar;
  select blob_to_string (RES_CONTENT), RES_TYPE into _content, _mime from WS.WS.SYS_DAV_RES where RES_FULL_PATH = '/DAV/VAD/blog2/public/images/90_macuser.png';
  -- params: content, length of content, width, height, x, y
  return "IM CropImageBlob" (_content, length(_content), 100, 100, 100, 100);
}
;

create procedure test22 ()
{
  declare _content any;
  declare _mime varchar;
  select blob_to_string (RES_CONTENT), RES_TYPE into _content, _mime from WS.WS.SYS_DAV_RES where RES_FULL_PATH = '/DAV/VAD/blog2/public/images/90_macuser.png';
  -- params: content, length of content, rotation degrees
  return "IM RotateImageBlob" (_content, length(_content), 10.1);
}
;

create procedure test23 ()
{
  declare _content any;
  declare _mime varchar;
  select blob_to_string (RES_CONTENT), RES_TYPE into _content, _mime from WS.WS.SYS_DAV_RES where RES_FULL_PATH = '/DAV/VAD/blog2/public/images/90_macuser.png';
  -- params: content, length of content, new image x resolution, new image y resolution, blur
  return "IM ResampleImageBlob" (_content, length(_content), 1.5, 2.5, 1.1, 13);
}
;

create procedure test24 ()
{
  declare _content any;
  declare _mime varchar;
  select blob_to_string (RES_CONTENT), RES_TYPE into _content, _mime from WS.WS.SYS_DAV_RES where RES_FULL_PATH = '/DAV/VAD/blog2/public/images/90_macuser.png';
  -- params: content, length of content, number of columns, number of rows, blur
  return "IM ResizeImageBlob" (_content, length(_content), 100, 100, 1.1, 13);
}
;

create procedure test25 ()
{
  declare _content any;
  declare _mime varchar;
  select blob_to_string (RES_CONTENT), RES_TYPE into _content, _mime from WS.WS.SYS_DAV_RES where RES_FULL_PATH = '/DAV/aziz.JPG';
  -- params: content, length of content, number of columns, number of rows
  dbg_obj_print('1');
  return "IM ThumbnailImageBlob" (_content, 0, 1, 1, 13);
  dbg_obj_print('2');
}
;

create procedure test26 ()
{
  declare _content any;
  declare _mime varchar;
  select blob_to_string (RES_CONTENT), RES_TYPE into _content, _mime from WS.WS.SYS_DAV_RES where RES_FULL_PATH = '/DAV/VAD/blog2/public/images/90_macuser.png';
  -- params: filename (in root), width, height, x, y
  return "IM GetImageBlobAttribute" (_content, length(_content), 'EXIF:Software');
}
;

-- [FunctionName]FileToBlob procedures take filename as parameter and return modified content as result

create procedure test31 ()
{
  -- params: filename (in root), width, height, x, y
  return "IM CropImageFileToBlob" ('eee.jpg', 100, 100, 100, 100);
}
;

create procedure test32 ()
{
  -- params: filename (in root), rotation degrees
  return "IM RotateImageFileToBlob" ('aziz.jpg', 10.1);
}
;

create procedure test33 ()
{
  -- params: filename (in root), new image x resolution, new image y resolution, blur
  return "IM ResampleImageFileToBlob" ('aziz.jpg', 1.5, 2.5, 1.1, 13);
}
;

create procedure test34 ()
{
  -- params: filename (in root), number of columns, number of rows, blur
  return "IM ResizeImageFileToBlob" ('aziz.jpg', 100, 100, 1.1, 13);
}
;

create procedure test35 ()
{
  -- params: filename (in root), number of columns, number of rows
  return "IM ThumbnailImageFileToBlob" ('aziz.jpg', 100, 100, 13);
}
;

create procedure test44 ()
{
  -- params: filename, new file name with new format
  return "IM ConvertImageFile" ('aziz.jpg', 'aziz.gif');
}
;

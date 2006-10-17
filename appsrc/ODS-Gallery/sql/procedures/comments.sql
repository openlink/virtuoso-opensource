--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2006 OpenLink Software
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

create procedure PHOTO.WA.add_comment(
  in sid varchar,
  in p_gallery_id integer,
  in comment photo_comment)
  returns photo_comment
{
dbg_obj_print('zzzzzzzzzzzzzzz');
  declare auth_uid,auth_pwd,current_gallery varchar;
  declare current_user photo_user;

  auth_uid := PHOTO.WA._session_user(vector('realm','wa','sid',sid),current_user);

  --if(auth_uid = ''){
  --  return vector();
  --}

dbg_obj_print(comment);
  comment.comment_id := sequence_next('PHOTO.WA.comments');
  comment.user_name := current_user.first_name;
  comment.user_id := current_user.user_id;
  comment.create_date := NOW();
  comment.modify_date := NOW();

  INSERT INTO PHOTO.WA.comments(COMMENT_ID,GALLERY_ID,RES_ID,CREATE_DATE,MODIFY_DATE,USER_ID,TEXT) VALUES (comment.comment_id,p_gallery_id,comment.res_id,comment.create_date,comment.modify_date,comment.user_id,comment.text);

  return comment;
}
;
--------------------------------------------------------------------------------

create procedure PHOTO.WA.get_comments(
  in sid varchar,
  in p_gallery_id integer,
  in resource_id integer)
  returns photo_comment array
{
  declare comment photo_comment;
  declare result photo_comment array;
  declare auth_uid,auth_pwd,current_gallery,user_name varchar;
  declare current_user photo_user;

  auth_uid := PHOTO.WA._session_user(vector('realm','wa','sid',sid),current_user);

  result := vector();

  for(SELECT COMMENT_ID,CREATE_DATE,USER_ID,TEXT,U_NAME,WAUI_FIRST_NAME
        FROM PHOTO.WA.comments,
             SYS_USERS,
             WA_USER_INFO
       WHERE RES_ID = resource_id
         AND WAUI_U_ID = U_ID
         AND GALLERY_ID = p_gallery_id
         AND SYS_USERS.U_ID = PHOTO.WA.comments.USER_ID)
  do{
      if(WAUI_FIRST_NAME is null or WAUI_FIRST_NAME = ''){
        user_name := U_NAME;
      }else{
        user_name := WAUI_FIRST_NAME;
      }

      comment := photo_comment(COMMENT_ID,resource_id,CREATE_DATE,USER_ID,TEXT,user_name);
      result := vector_concat(result,vector(comment));
  }

  return result;
}
;
--------------------------------------------------------------------------------

PHOTO.WA._exec_no_error('grant execute on photo_comment TO SOAPGallery');
PHOTO.WA._exec_no_error('grant execute on PHOTO.WA.add_comment TO SOAPGallery');
PHOTO.WA._exec_no_error('grant execute on PHOTO.WA.get_comments TO SOAPGallery');




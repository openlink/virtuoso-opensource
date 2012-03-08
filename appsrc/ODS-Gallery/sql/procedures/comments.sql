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

create procedure PHOTO.WA.root_comment (
  in _gallery_id integer,
  in _resource_id integer)
{
  declare _owner_id, _comment_id, i integer;

  --if () proverka dali ima zapis, ako ima update
  i := 0;
  for (select COMMENT_ID as _cid
         from PHOTO.WA.COMMENTS
        where GALLERY_ID = _gallery_id and RES_ID = _resource_id and PARENT_ID is null and RFC_ID is not null) do
  {
    if (i = 0)
    {
      _comment_id := _cid;
      update PHOTO.WA.COMMENTS
         set TEXT = PHOTO.WA.get_image_caption (_resource_id), MODIFY_DATE = now ()
       where COMMENT_ID = _comment_id;
    }
    if (i > 0)
      delete from PHOTO.WA.COMMENTS where COMMENT_ID = _cid;
    i := i+1;
  }

  if (i = 0)
  {
  _owner_id := PHOTO.WA.domain_owner_id (_gallery_id);
  _comment_id := sequence_next('PHOTO.WA.comments');
    if (_owner_id is not null)
  insert into PHOTO.WA.COMMENTS (COMMENT_ID, GALLERY_ID, RES_ID, CREATE_DATE, MODIFY_DATE, USER_ID, TEXT)
    values (_comment_id,
            _gallery_id,
            _resource_id,
            now (),
            now (),
            _owner_id,
            PHOTO.WA.get_image_caption (_resource_id));
  }

  update PHOTO.WA.COMMENTS set PARENT_ID = _comment_id
   where COMMENT_ID <> _comment_id and GALLERY_ID = _gallery_id and RES_ID = _resource_id; -- and RFC_ID is null;

  return _comment_id;
}
;

--------------------------------------------------------------------------------
create procedure PHOTO.WA.add_comment(
  in sid varchar,
  in _gallery_id integer,
  in _resource_id integer,
  in _text nvarchar) returns photo_comment
{
  declare _parent_id integer;
  declare current_user photo_user;
  declare comment photo_comment;

  PHOTO.WA._session_user (vector('realm', 'wa','sid', sid), current_user);

  comment := new photo_comment (sequence_next('PHOTO.WA.comments'),
                                _resource_id,
                                now(),
                                current_user.user_id,
                                _text,
                                current_user.first_name);
  comment.modify_date := now ();

  _parent_id := (select COMMENT_ID from PHOTO.WA.COMMENTS where RES_ID = _resource_id and PARENT_ID is null);
  if (isnull (_parent_id))
  {
    _parent_id := PHOTO.WA.root_comment (_gallery_id, _resource_id);
  }
  insert into PHOTO.WA.COMMENTS (COMMENT_ID, PARENT_ID, GALLERY_ID, RES_ID, CREATE_DATE, MODIFY_DATE, USER_ID, TEXT)
    values (comment.comment_id, _parent_id, _gallery_id, comment.res_id, comment.create_date, comment.modify_date, comment.user_id, PHOTO.WA.wide2utf (comment.text));

  return comment;
}
;

--------------------------------------------------------------------------------
create procedure PHOTO.WA.remove_comment(
  in sid varchar,
  in _comment_id integer)

{
  declare auth_uid,auth_pwd,current_gallery varchar;
  declare current_user photo_user;

  auth_uid := PHOTO.WA._session_user(vector('realm','wa','sid',sid),current_user);
  if (exists (select 1 from PHOTO.WA.COMMENTS where COMMENT_ID = _comment_id and USER_ID = current_user.user_id))
  {
    delete from PHOTO.WA.COMMENTS where COMMENT_ID = _comment_id;
     return 1;
  }
  return 0;
}
;

--------------------------------------------------------------------------------
create procedure PHOTO.WA.update_comment (
  in sid varchar,
  in _comment_id integer,
  in _text nvarchar)
{
  declare auth_uid,auth_pwd,current_gallery varchar;
  declare current_user photo_user;

  auth_uid := PHOTO.WA._session_user(vector('realm','wa','sid',sid),current_user);
  if (exists (select 1 from PHOTO.WA.COMMENTS where COMMENT_ID=_comment_id and USER_ID=current_user.user_id))
  {
    update PHOTO.WA.COMMENTS set TEXT = PHOTO.WA.wide2utf (_text) where COMMENT_ID=_comment_id;
     return 1;
  }
 return 0;
}
;

--------------------------------------------------------------------------------
create procedure PHOTO.WA.get_comment (
  in sid varchar,
  in _comment_id integer)
  returns photo_comment
{
  declare current_user photo_user;

  PHOTO.WA._session_user (vector('realm','wa','sid',sid), current_user);

  for (select RES_ID, CREATE_DATE, USER_ID, TEXT, U_NAME
         from PHOTO.WA.COMMENTS, DB.DBA.SYS_USERS
        where COMMENT_ID = _comment_id
          and USER_ID = U_ID) do
  {
    return photo_comment (_comment_id, RES_ID, CREATE_DATE, USER_ID, PHOTO.WA.utf2wide (TEXT), PHOTO.WA.utf2wide (U_NAME));
  }
  return null;
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
         FROM PHOTO.WA.COMMENTS,
             SYS_USERS,
             WA_USER_INFO
       WHERE RES_ID = resource_id
         AND WAUI_U_ID = U_ID
         AND GALLERY_ID = p_gallery_id
          AND SYS_USERS.U_ID = PHOTO.WA.COMMENTS.USER_ID
          AND ((PARENT_ID is not null) or (TEXT <> PHOTO.WA.get_image_caption (resource_id)))) do
  {
    if(WAUI_FIRST_NAME is null or WAUI_FIRST_NAME = '')
    {
        user_name := U_NAME;
      }else{
        user_name := WAUI_FIRST_NAME;
      }
    comment := photo_comment (COMMENT_ID, resource_id, CREATE_DATE, USER_ID, PHOTO.WA.utf2wide (TEXT), PHOTO.WA.utf2wide (user_name));
      result := vector_concat(result,vector(comment));
  }
  return result;
}
;

create procedure PHOTO.WA.add_comment(
  in sid varchar,
  in comment photo_comment)
  returns photo_comment
{

  declare auth_uid,auth_pwd,current_gallery varchar;
  declare current_user photo_user;

  auth_uid := PHOTO.WA._session_user(vector('realm','wa','sid',sid),current_user);

  --if(auth_uid = ''){
  --  return vector();
  --}


  comment.comment_id := sequence_next('PHOTO.WA.comments');
  comment.user_name := current_user.first_name;
  comment.user_id := current_user.user_id;
  comment.create_date := NOW();


  INSERT INTO PHOTO.WA.comments(COMMENT_ID,RES_ID,CREATE_DATE,USER_ID,TEXT) VALUES (comment.comment_id,comment.res_id,comment.create_date,comment.user_id,comment.text);

  return comment;
}
;
--------------------------------------------------------------------------------

create procedure PHOTO.WA.get_comments(
  in sid varchar,
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




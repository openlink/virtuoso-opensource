create trigger trigger_make_thumbnails after insert on WS.WS.SYS_DAV_RES referencing new as N{

  declare exit handler for sqlstate '*' {
    dbg_obj_print('************');
    dbg_obj_print('error');
    dbg_obj_print(__SQL_MESSAGE);
    resignal;
  };

  declare parent_id,parent_name integer;
  select COL_PARENT into parent_id from WS.WS.SYS_DAV_COL WHERE COL_ID = N.RES_COL;
  parent_name := DAV_SEARCH_PATH(parent_id,'C');
  declare current_user photo_user;
  current_user := new photo_user(cast(N.RES_OWNER as integer) );

  if(parent_name = current_user.gallery_dir){
    PHOTO.WA.make_thumbnail(current_user,N.RES_ID,0);
  }
return;
}
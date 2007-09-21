
create procedure
DB.DBA.PHP_SYS_MKDIR (in path varchar)
{
  declare temp any;
  declare idx integer;

  declare exit handler for sqlstate '*'
    {
	log_message ('handler DB.DBA.PHP_SYS_MKDIR ' || path);
	return;
    };

  path := subseq(path, length (server_root()));

  temp := split_and_decode (path, 0, '///');
  idx := 0;
  path := server_root();

  while (idx < length (temp) - 1)
    {
       path := concat (path, temp[idx], '/');
       sys_mkdir (path);
       idx := idx + 1;
    }
}
;

create procedure
DB.DBA.PHP_COPY_DAV_DIR_TO_FILE_SYSTEM (in dav_path varchar)
{
  declare full_path, f_name, d_path varchar;
  declare abs_path varchar;
  declare create_dir_name varchar;
  declare temp any;
  declare last_up any;
  declare ret_name any;
  declare virt_dir any;

  declare exit handler for sqlstate '*'
    {
	log_message ('handler DB.DBA.PHP_COPY_DAV_DIR_TO_FILE_SYSTEM ' || dav_path);
	return '';
    };

  abs_path := server_root () || 'tmp';
  d_path := '';

  if (isinteger (dav_path)) return '';

-- log_message (dav_path);

  temp:= WS.WS.PARSE_URI (dav_path);
  temp := split_and_decode (temp[2], 0, '///');

  for (declare x any, x := 1; x < length (temp) - 1; x := x + 1)
    d_path := d_path || '/' || temp[x];

  last_up := registry_get (d_path);

  if (not (last_up = 0 or last_up = ''))
    {
       last_up := stringdate (last_up);
       if (datediff ('hour', last_up, now ()) >= 1) last_up := '';
    }

  f_name := PHP_MAKE_FILE_NAME (dav_path);
  virt_dir := PHP_GET_VIRTUAL_DIR (dav_path);
  ret_name := f_name;

  if (not (last_up = 0 or last_up = ''))
    {
       dav_path := PHP_REMOVE_DIR_PREF (dav_path);
       temp := ((select string_to_file (f_name, RES_CONTENT, -2) from WS.WS.SYS_DAV_RES where RES_FULL_PATH = dav_path));
       return f_name;
    }

  if (virt_dir is NULL) virt_dir := d_path;

  set isolation='committed';
  for (select RES_FULL_PATH,
	subseq (RES_FULL_PATH, length (virt_dir)) as local_dav_path,
      	  RES_CONTENT, RES_NAME, RES_MOD_TIME from WS.WS.SYS_DAV_RES
      where RES_FULL_PATH like concat (virt_dir, '%')) do
    {
         f_name := PHP_MAKE_FILE_NAME (RES_FULL_PATH);
         DB.DBA.PHP_SYS_MKDIR (f_name);
         string_to_file (f_name, RES_CONTENT, -2);
    }

   registry_set (d_path, cast (now () as varchar));

   return ret_name;
}
;

create procedure PHP_MAKE_FILE_NAME (in dav_path any)
{
  return server_root () || 'tmp' || replace (PHP_REMOVE_DIR_PREF (dav_path), '/DAV', '', 1);
}
;

create procedure PHP_GET_VIRTUAL_DIR (in dav_path any)
{
  declare temp, path, best_match any;
  declare _virtual_dir, ret any;
  declare idx integer;

  dav_path := PHP_REMOVE_DIR_PREF (dav_path);
  temp := split_and_decode (dav_path, 0, '///');
  idx := 0;
  path := '';
  best_match := NULL;

  _virtual_dir := http_map_get ('domain');
  if (exists (select 1 from DB.DBA.HTTP_PATH where HP_LPATH = _virtual_dir))
    {
	select HP_PPATH into ret from DB.DBA.HTTP_PATH where HP_LPATH = _virtual_dir;
	return ret;
    }

  while (idx < length (temp) - 1)
    {
       path := concat (path, temp[idx], '/');
       if (exists (select 1 from DB.DBA.HTTP_PATH where HP_PPATH = path))
 	  best_match := path;
       idx := idx + 1;
    }

  return best_match;
}
;

create procedure PHP_REMOVE_DIR_PREF (in dav_path any)
{
  return replace (dav_path, 'virt://WS.WS.SYS_DAV_RES.RES_FULL_PATH.RES_CONTENT:', '', 1);
}
;

create trigger PHP_SYS_DAV_RES_I after insert on WS.WS.SYS_DAV_RES
{
    declare temp, d_path any;
    temp := split_and_decode (RES_FULL_PATH, 0, '///');
    d_path := '';
    for (declare x any, x := 1; x < length (temp) - 1; x := x + 1)
      {
	 d_path := d_path || '/' || temp[x];
	 registry_set (d_path, '');
      }
}
;

create trigger PHP_SYS_DAV_RES_U after update on WS.WS.SYS_DAV_RES referencing old as O, new as N
{
    declare temp, d_path any;
    temp := split_and_decode (N.RES_FULL_PATH, 0, '///');
    d_path := '';
    for (declare x any, x := 1; x < length (temp) - 1; x := x + 1)
      {
	 d_path := d_path || '/' || temp[x];
	 registry_set (d_path, '');
      }
}
;


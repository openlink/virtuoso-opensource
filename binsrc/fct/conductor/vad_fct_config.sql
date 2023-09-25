create procedure DB.DBA.fct_create_registry_default_entries () 
{
  declare reg_default_limit, reg_default_inf, reg_default_invfp, reg_default_sas, reg_default_terminology any;
  declare reg_timeout_min, reg_timeout_max any;

  -- Timeouts set through Conductor's Fct Configuration UI.
  -- These cannot be overridden by a user.
  reg_timeout_min := registry_get ('fct_timeout_min');
  reg_timeout_max := registry_get ('fct_timeout_max');

  if (reg_timeout_min = 0)
    registry_set('fct_timeout_min', '8000'); 
  if (reg_timeout_max = 0)
    registry_set('fct_timeout_max', '20000'); 

  -- Global, pan-user defaults set through Conductor's Fct Configuration UI
  -- These can be overridden by a user.
  reg_default_limit := registry_get('fct_default_limit'); 
  reg_default_inf := registry_get('fct_default_inf'); 
  reg_default_invfp := registry_get('fct_default_invfp'); 
  reg_default_sas := registry_get('fct_default_sas'); 
  reg_default_terminology := registry_get('fct_default_terminology');

  if (reg_default_limit = 0) 
    registry_set('fct_default_limit', '50'); 
  if (reg_default_inf = 0)
    registry_set('fct_default_inf', 'None');
  if (reg_default_invfp = 0)
    registry_set('fct_default_invfp', 'IFP_OFF');
  if (reg_default_sas = 0)
    registry_set('fct_default_sas', 'SAME_AS_OFF');
  if (reg_default_terminology = 0)
    registry_set('fct_default_terminology', 'eav');
}
;

--
-- Copy fct VAD configuration pages into the Conductor VAD install directory
--
create procedure DB.DBA.fct_vad_configure (
  in _package varchar,
  in _ppath varchar,
  in _fname varchar := 'vad_fct_config.vspx')
{
  declare _id integer;
  declare _content, _type varchar;
  declare exit handler for sqlstate '*'
  {
    return;
  };

  DB.DBA.fct_create_registry_default_entries();

  _content := '';
  if ((select PKG_DEST from VAD.DBA.VAD_LIST where dir = '' and fs_type = 0 and PKG_NAME = _package) = 1)
  {
    _id := DB.DBA.DAV_SEARCH_ID ('/DAV/VAD/' || _ppath || '/' || _fname, 'R');
    if (not isnull (DB.DBA.DAV_HIDE_ERROR (_id)))
      DB.DBA.DAV_RES_CONTENT_INT (_id, _content, _type, 0, 0);
  }
  else
  {
    _content := file_to_string (http_root () || '/vad/vsp/' || _ppath || '/' || _fname);
  }
  if (_content = '')
    return;

  if (isstring (file_stat (http_root () || '/vad/vsp/conductor/')))
    string_to_file (http_root () || '/vad/vsp/conductor/' || _fname, _content, -2);

  DB.DBA.DAV_RES_UPLOAD_STRSES_INT (
    '/DAV/VAD/conductor/' || _fname, _content, 
    permissions=>'111101101R', 
    auth_uname=>DB.DBA.DAV_DET_USER (http_dav_uid ()), 
    auth_pwd=>DB.DBA.DAV_DET_PASSWORD (http_dav_uid ()), 
    extern=>0, check_locks=>0);
}
;

create procedure DB.DBA.fct_vad_configure_drop (
  in _fname varchar := 'vad_fct_config.vspx')
{
  if (isstring (file_stat (http_root () || '/vad/vsp/conductor/' || _fname)))
    file_delete (http_root () || '/vad/vsp/conductor/' || _fname, 1);

  DB.DBA.DAV_DELETE ('/DAV/VAD/conductor/' || _fname, 1, DB.DBA.DAV_DET_USER (http_dav_uid ()), DB.DBA.DAV_DET_PASSWORD (http_dav_uid ()));
}
;

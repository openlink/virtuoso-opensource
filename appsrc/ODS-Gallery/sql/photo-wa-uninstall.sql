------------------------------------------------------------------------------
-- nws-d.sql
-- script for cleaning wa instalation.
-- Copyright (C) 2004 OpenLink Software
------------------------------------------------------------------------------


-- Paths
vhost_remove (lpath=>'/gallery');
vhost_remove (lpath=>'/gallery/SOAP');
vhost_remove (lpath=>'/gallery/res');

user_drop ('SOAPGallery',1);

DELETE FROM DB.DBA.WA_MEMBER WHERE WAM_INST IN (SELECT WAI_NAME FROM DB.DBA.WA_INSTANCE WHERE WAI_TYPE_NAME = 'oGallery');
DELETE FROM DB.DBA.WA_INSTANCE WHERE WAI_TYPE_NAME = 'oGallery';
DELETE FROM DB.DBA.WA_MEMBER_TYPE WHERE WMT_APP = 'oGallery';
DELETE FROM DB.DBA.WA_TYPES WHERE WAT_NAME = 'oGallery';

-- Types
PHOTO.WA._exec_no_error('delete from WA_TYPES where WAT_NAME = \'Photo\'');
PHOTO.WA._exec_no_error('drop trigger WS.WS.trigger_make_thumbnails');
PHOTO.WA._exec_no_error('drop table PHOTO.WA.comments');

PHOTO.WA._exec_no_error('drop type wa_photo');
PHOTO.WA._exec_no_error('drop type photo_user');
PHOTO.WA._exec_no_error('drop type SOAP_album');
PHOTO.WA._exec_no_error('drop type photo_comment');
PHOTO.WA._exec_no_error('drop type image_ids');
PHOTO.WA._exec_no_error('drop type photo_exif');





-- Procedures
create procedure PHOTO.WA._drop_procedures()
{
  for (select P_NAME from DB.DBA.SYS_PROCEDURES where P_NAME like 'PHOTO.WA.%') do {
    if (P_NAME not in ('PHOTO.WA._exec_no_error', 'PHOTO.WA._drop_procedures'))
      PHOTO.WA._exec_no_error(sprintf('drop procedure %s', P_NAME));

  }
}
;

-- dropping procedures for PHOTO
PHOTO.WA._drop_procedures();

PHOTO.WA._exec_no_error('DROP procedure PHOTO.WA._drop_procedures');
PHOTO.WA._exec_no_error('DROP procedure PHOTO.WA._exec_no_error');



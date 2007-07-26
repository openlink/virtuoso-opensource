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

------------------------------------------------------------------------------
-- nws-d.sql
-- script for cleaning wa installation.
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


--TRIGGERS related to SIOC
PHOTO.WA._exec_no_error('DROP TRIGGER WS.WS.SYS_DAV_RES_PHOTO_SIOC_I');
PHOTO.WA._exec_no_error('DROP TRIGGER WS.WS.SYS_DAV_RES_PHOTO_SIOC_U');
PHOTO.WA._exec_no_error('DROP TRIGGER WS.WS.SYS_DAV_RES_PHOTO_SIOC_D');

-- Types
PHOTO.WA._exec_no_error('delete from WA_TYPES where WAT_NAME = \'Photo\'');
PHOTO.WA._exec_no_error('drop trigger WS.WS.trigger_make_thumbnails');
PHOTO.WA._exec_no_error('drop trigger WS.WS.trigger_update_thumbnails');
PHOTO.WA._exec_no_error('drop table PHOTO.WA.comments');
PHOTO.WA._exec_no_error('drop trigger DB.DBA.trigger_update_sys_info');
PHOTO.WA._exec_no_error('drop table PHOTO.WA.SYS_INFO');
PHOTO.WA._exec_no_error('drop table PHOTO.WA.EXIF_DATA');

PHOTO.WA._exec_no_error('drop type wa_photo');
PHOTO.WA._exec_no_error('drop type photo_user');
PHOTO.WA._exec_no_error('drop type SOAP_album');
PHOTO.WA._exec_no_error('drop type SOAP_external_album');
PHOTO.WA._exec_no_error('drop type SOAP_gallery');
PHOTO.WA._exec_no_error('drop type photo_comment');
PHOTO.WA._exec_no_error('drop type image_ids');
PHOTO.WA._exec_no_error('drop type photo_exif');
PHOTO.WA._exec_no_error('drop type photo_instance');



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



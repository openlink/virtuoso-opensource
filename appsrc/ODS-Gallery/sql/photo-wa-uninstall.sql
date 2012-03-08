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

------------------------------------------------------------------------------
-- nws-d.sql
-- script for cleaning wa installation.
------------------------------------------------------------------------------
create procedure PHOTO.WA.uninstall ()
{
  for select WAI_INST from DB.DBA.WA_INSTANCE WHERE WAI_TYPE_NAME = 'oGallery' do
  {
    (WAI_INST as DB.DBA.wa_photo).wa_drop_instance();
    commit work;
  }
}
;
PHOTO.WA.uninstall ()
;

-- Paths
vhost_remove (lpath=>'/photos');
vhost_remove (lpath=>'/photos/SOAP');
vhost_remove (lpath=>'/photos/res');

user_drop ('SOAPGallery',1);

--TRIGGERS
PHOTO.WA._exec_no_error('drop trigger WS.WS.SYS_DAV_RES_PHOTO_SIOC_I');
PHOTO.WA._exec_no_error('drop trigger WS.WS.SYS_DAV_RES_PHOTO_SIOC_U');
PHOTO.WA._exec_no_error('drop trigger WS.WS.SYS_DAV_RES_PHOTO_SIOC_D');
PHOTO.WA._exec_no_error('drop trigger WS.WS.trigger_make_thumbnails');
PHOTO.WA._exec_no_error('drop trigger WS.WS.trigger_update_thumbnails');
PHOTO.WA._exec_no_error('drop trigger WS.WS.trigger_delete_thumbnails');

PHOTO.WA._exec_no_error('drop trigger DB.DBA.trigger_update_sys_info');

-- Procedures
create procedure PHOTO.WA._drop_procedures()
{
  for (select P_NAME from DB.DBA.SYS_PROCEDURES where P_NAME like 'PHOTO.WA.%') do {
    if (P_NAME not in ('PHOTO.WA._exec_no_error', 'PHOTO.WA._drop_procedures'))
      PHOTO.WA._exec_no_error(sprintf('drop procedure %s', P_NAME));

  }
}
;

PHOTO.WA._drop_procedures();

-- XSLT extensions
xpf_extension_remove ('http://www.openlinksw.com/photos/:getODSBar', 'PHOTO.WA.GET_ODS_BAR');

-- dropping SIOC procs
PHOTO.WA._exec_no_error('drop procedure sioc.DBA.fill_ods_photos_sioc');
PHOTO.WA._exec_no_error('drop procedure sioc.DBA.gallery_comment_iri');
PHOTO.WA._exec_no_error('drop procedure sioc.DBA.gallery_comment_url');
PHOTO.WA._exec_no_error('drop procedure sioc.DBA.gallery_post_iri');
PHOTO.WA._exec_no_error('drop procedure sioc.DBA.gallery_post_iri_new');
PHOTO.WA._exec_no_error('drop procedure sioc.DBA.gallery_post_url');
PHOTO.WA._exec_no_error('drop procedure sioc.DBA.gallery_prop_get');
PHOTO.WA._exec_no_error('drop procedure sioc.DBA.ods_photo_sioc_tags');
PHOTO.WA._exec_no_error('drop procedure sioc.DBA.rdf_photos_view_str');
PHOTO.WA._exec_no_error('drop procedure sioc.DBA.rdf_photos_view_str_maps');
PHOTO.WA._exec_no_error('drop procedure sioc.DBA.rdf_photos_view_str_tables');

PHOTO.WA._exec_no_error('drop procedure DB.DBA.ods_gallery_sioc_init');
PHOTO.WA._exec_no_error('drop procedure DB.DBA.ODS_PHOTO_TAGS');

-- NNTP
PHOTO.WA._exec_no_error('drop procedure DB.DBA.GALLERY_NEWS_MSG_I');
PHOTO.WA._exec_no_error('drop procedure DB.DBA.GALLERY_NEWS_MSG_U');
PHOTO.WA._exec_no_error('drop procedure DB.DBA.GALLERY_NEWS_MSG_D');
DB.DBA.NNTP_NEWS_MSG_DEL ('GALLERY');

-- Views
PHOTO.WA._exec_no_error('drop view DB.DBA.ODS_PHOTO_POSTS');
PHOTO.WA._exec_no_error('drop view DB.DBA.ODS_PHOTO_COMMENTS');
PHOTO.WA._exec_no_error('drop view DB.DBA.ODS_PHOTO_TAGS');


-- Tables
PHOTO.WA._exec_no_error('drop table PHOTO.WA.EXIF_DATA');
PHOTO.WA._exec_no_error('drop table PHOTO.WA.COMMENTS');
PHOTO.WA._exec_no_error('drop table PHOTO.WA.SYS_INFO');

-- Types
PHOTO.WA._exec_no_error('drop type wa_photo');
PHOTO.WA._exec_no_error('drop type photo_user');
PHOTO.WA._exec_no_error('drop type SOAP_album');
PHOTO.WA._exec_no_error('drop type SOAP_external_album');
PHOTO.WA._exec_no_error('drop type SOAP_gallery');
PHOTO.WA._exec_no_error('drop type photo_comment');
PHOTO.WA._exec_no_error('drop type image_ids');
PHOTO.WA._exec_no_error('drop type photo_exif');
PHOTO.WA._exec_no_error('drop type photo_instance');

PHOTO.WA._exec_no_error('delete from DB.DBA.WA_MEMBER_TYPE where WMT_APP = \'oGallery\'');
PHOTO.WA._exec_no_error('delete from DB.DBA.WA_TYPES where WAT_NAME = \'oGallery\'');
PHOTO.WA._exec_no_error('delete from DB.DBA.WA_TYPES where WAT_NAME = \'oGallery\'');

-- Registry
registry_remove ('gallery_services_update');

PHOTO.WA._exec_no_error('drop procedure PHOTO.WA._drop_procedures');
PHOTO.WA._exec_no_error('drop procedure PHOTO.WA._exec_no_error');


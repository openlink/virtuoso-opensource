--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2014 OpenLink Software
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
-- upload files
--
DB.DBA.DAV_COL_CREATE ('/DAV/VAD/oDrive/', '110100100R', 'dav', 'administrators', 'dav', 'dav');
DB.DBA.DAV_COL_CREATE ('/DAV/VAD/oDrive/schemas/', '110100100R', 'dav', 'administrators', 'dav', 'dav');

create procedure ODRIVE.WA.rdf_upload(in fileName varchar)
{
  declare sHost varchar;

  sHost := cast(registry_get('_oDrive_path_') as varchar);
  if (not isnull(strstr(sHost, '/DAV/VAD')))
    return;

  declare filePath, content varchar;

  if (not isnull(strstr(sHost, '/vad/vsp'))) {
    filePath := sprintf('file://%sschemas/', sHost);
  } else {
    filePath := 'file://apps/oDrive/schemas/';
  }
  content := xml_uri_get(filePath, fileName);
  DB.DBA.DAV_RES_UPLOAD (sprintf('/DAV/VAD/oDrive/schemas/%s', fileName), content, 'text/html', '110110100R', 'dav', 'administrators', 'dav', 'dav' );
}
;

ODRIVE.WA.rdf_upload('RSS.rdf');
ODRIVE.WA.rdf_upload('FOAF.rdf');
ODRIVE.WA.rdf_upload('XBEL.rdf');
ODRIVE.WA.rdf_upload('MODS.rdf');
ODRIVE.WA.rdf_upload('vcard-rdf.rdf');
ODRIVE.WA.rdf_upload('ICS.rdf');
ODRIVE.WA.rdf_upload('VAD.rdf');
ODRIVE.WA.rdf_upload('VSPX.rdf');
ODRIVE.WA.rdf_upload('WSDL.rdf');
ODRIVE.WA.rdf_upload('XHTML.rdf');
ODRIVE.WA.rdf_upload('OPML.rdf');
ODRIVE.WA.rdf_upload('Office.rdf');
ODRIVE.WA.rdf_upload('XDDL.rdf');
ODRIVE.WA.rdf_upload('image.rdf');
ODRIVE.WA.rdf_upload('EML.rdf');
ODRIVE.WA.rdf_upload('RDF.rdf');
ODRIVE.WA.rdf_upload('photo.rdf');
ODRIVE.WA.rdf_upload('Spotlight.rdf');
ODRIVE.WA.rdf_upload('Wiki.rdf');
ODRIVE.WA.rdf_upload('XBRL.rdf');
ODRIVE.WA.rdf_upload('DOAP.rdf');
ODRIVE.WA.rdf_upload('opl-lic.rdf');
ODRIVE.WA.rdf_upload('annotea.rdf');
ODRIVE.WA.rdf_upload('google-base.rdf');
ODRIVE.WA.rdf_upload('archive.rdf');
ODRIVE.WA.rdf_upload('OpenDocument.rdf');
ODRIVE.WA.rdf_upload('audio.rdf');

-- register schemas
--
DAV_REGISTER_RDF_SCHEMA('http://purl.org/rss/1.0/',null,'http://localdav.virt/DAV/VAD/oDrive/schemas/RSS.rdf','replacing');
DAV_REGISTER_RDF_SCHEMA('http://www.apple.com/metadata#',null,'http://localdav.virt/DAV/VAD/oDrive/schemas/Spotlight.rdf','replacing');
DAV_REGISTER_RDF_SCHEMA('http://www.python.org/topics/xml/xbel/',null,'http://localdav.virt/DAV/VAD/oDrive/schemas/XBEL.rdf','replacing');
DAV_REGISTER_RDF_SCHEMA('http://www.openlinksw.com/schemas/ICS#',null,'http://localdav.virt/DAV/VAD/oDrive/schemas/ICS.rdf','replacing');
DAV_REGISTER_RDF_SCHEMA('http://www.openlinksw.com/schemas/Image#',null,'http://localdav.virt/DAV/VAD/oDrive/schemas/image.rdf','replacing');
DAV_REGISTER_RDF_SCHEMA('http://www.openlinksw.com/schemas/Email#',null,'http://localdav.virt/DAV/VAD/oDrive/schemas/EML.rdf','replacing');
DAV_REGISTER_RDF_SCHEMA('http://www.openlinksw.com/schemas/RDF#',null,'http://localdav.virt/DAV/VAD/oDrive/schemas/RDF.rdf','replacing');
DAV_REGISTER_RDF_SCHEMA('http://www.openlinksw.com/schemas/Photo#',null,'http://localdav.virt/DAV/VAD/oDrive/schemas/photo.rdf','replacing');
DAV_REGISTER_RDF_SCHEMA('http://www.openlinksw.com/schemas/Archive#',null,'http://localdav.virt/DAV/VAD/oDrive/schemas/archive.rdf','replacing');
DAV_REGISTER_RDF_SCHEMA('http://www.openlinksw.com/schemas/MODS#',null,'http://localdav.virt/DAV/VAD/oDrive/schemas/MODS.rdf','replacing');
DAV_REGISTER_RDF_SCHEMA('http://www.openlinksw.com/schemas/Office#',null,'http://localdav.virt/DAV/VAD/oDrive/schemas/Office.rdf','replacing');
DAV_REGISTER_RDF_SCHEMA('http://www.openlinksw.com/schemas/OPML#',null,'http://localdav.virt/DAV/VAD/oDrive/schemas/OPML.rdf','replacing');
DAV_REGISTER_RDF_SCHEMA('http://www.openlinksw.com/schemas/VAD#',null,'http://localdav.virt/DAV/VAD/oDrive/schemas/VAD.rdf','replacing');
DAV_REGISTER_RDF_SCHEMA('http://www.openlinksw.com/schemas/VSPX#',null,'http://localdav.virt/DAV/VAD/oDrive/schemas/VSPX.rdf','replacing');
DAV_REGISTER_RDF_SCHEMA('http://www.openlinksw.com/schemas/WSDL#',null,'http://localdav.virt/DAV/VAD/oDrive/schemas/WSDL.rdf','replacing');
DAV_REGISTER_RDF_SCHEMA('http://www.openlinksw.com/schemas/XHTML#',null,'http://localdav.virt/DAV/VAD/oDrive/schemas/XHTML.rdf','replacing');
DAV_REGISTER_RDF_SCHEMA('http://www.openlinksw.com/schemas/XDDL#',null,'http://localdav.virt/DAV/VAD/oDrive/schemas/XDDL.rdf','replacing');
DAV_REGISTER_RDF_SCHEMA('http://www.w3.org/2001/vcard-rdf/3.0#',  null,'http://localdav.virt/DAV/VAD/oDrive/schemas/vcard-rdf.rdf','replacing');
DAV_REGISTER_RDF_SCHEMA('http://xmlns.com/foaf/0.1/',null,'http://localdav.virt/DAV/VAD/oDrive/schemas/FOAF.rdf','replacing');
DAV_REGISTER_RDF_SCHEMA('http://www.openlinksw.com/schemas/Wiki#',null,'http://localdav.virt/DAV/VAD/oDrive/schemas/Wiki.rdf','replacing');
DAV_REGISTER_RDF_SCHEMA('http://www.openlinksw.com/schemas/xbrl#',null,'http://localdav.virt/DAV/VAD/oDrive/schemas/XBRL.rdf','replacing');
DAV_REGISTER_RDF_SCHEMA('http://www.openlinksw.com/schemas/doap#',null,'http://localdav.virt/DAV/VAD/oDrive/schemas/DOAP.rdf','replacing');
DAV_REGISTER_RDF_SCHEMA('http://www.openlinksw.com/schemas/OplLic#',null,'http://localdav.virt/DAV/VAD/oDrive/schemas/opl-lic.rdf','replacing');
DAV_REGISTER_RDF_SCHEMA('http://www.openlinksw.com/schemas/Annotea#',null,'http://localdav.virt/DAV/VAD/oDrive/schemas/annotea.rdf','replacing');
DAV_REGISTER_RDF_SCHEMA('http://www.openlinksw.com/schemas/google-base#',null,'http://localdav.virt/DAV/VAD/oDrive/schemas/google-base.rdf','replacing');
DAV_REGISTER_RDF_SCHEMA('urn:oasis:names:tc:opendocument:xmlns:meta:1.0',null,'http://localdav.virt/DAV/VAD/oDrive/schemas/OpenDocument.rdf','replacing');
DAV_REGISTER_RDF_SCHEMA('http://www.openlinksw.com/schemas/opendocument#',null,'http://localdav.virt/DAV/VAD/oDrive/schemas/OpenDocument.rdf','replacing');
DAV_REGISTER_RDF_SCHEMA('http://www.openlinksw.com/schemas/audio#',null,'http://localdav.virt/DAV/VAD/oDrive/schemas/audio.rdf','replacing');

-- register mime types
--
DAV_REGISTER_MIME_TYPE ('application/bpel+xml', 'BPEL business process', 'bpel', null, 'replacing');
DAV_REGISTER_MIME_TYPE ('application/foaf+xml', 'FOAF data', 'foaf', null, 'replacing');
DAV_REGISTER_MIME_TYPE ('application/mods+xml', 'MODS data', 'mods', null, 'replacing');
DAV_REGISTER_MIME_TYPE ('application/msexcel', 'MS Excel spreadsheet', 'xls', null, 'replacing');
DAV_REGISTER_MIME_TYPE ('application/msaccess', 'MS Access database', 'mdb', null, 'replacing');
DAV_REGISTER_MIME_TYPE ('application/msexcel', 'MS Excel Comma Separated Values File', 'csv', null, 'replacing');
DAV_REGISTER_MIME_TYPE ('application/vnd.oasis.opendocument.text', 'OpenDocument Text', 'odt', null, 'replacing');
DAV_REGISTER_MIME_TYPE ('application/vnd.oasis.opendocument.database', 'OpenDocument Database', 'odb', null, 'replacing');
DAV_REGISTER_MIME_TYPE ('application/vnd.oasis.opendocument.graphics', 'OpenDocument Drawing', 'odg', null, 'replacing');
DAV_REGISTER_MIME_TYPE ('application/vnd.oasis.opendocument.presentation', 'OpenDocument Presentation', 'odp', null, 'replacing');
DAV_REGISTER_MIME_TYPE ('application/vnd.oasis.opendocument.spreadsheet', 'OpenDocument Spreadsheet', 'ods', null, 'replacing');
DAV_REGISTER_MIME_TYPE ('application/vnd.oasis.opendocument.chart', 'OpenDocument Chart', 'odc', null, 'replacing');
DAV_REGISTER_MIME_TYPE ('application/vnd.oasis.opendocument.formula', 'OpenDocument Formula', 'odf', null, 'replacing');
DAV_REGISTER_MIME_TYPE ('application/vnd.oasis.opendocument.image', 'OpenDocument Image', 'odi', null, 'replacing');
DAV_REGISTER_MIME_TYPE ('application/mspowerpoint', 'MS PowerPoint presentation', 'ppt', null, 'replacing');
DAV_REGISTER_MIME_TYPE ('application/msproject', 'MS Project document', 'mpp', null, 'replacing');
DAV_REGISTER_MIME_TYPE ('application/msword', 'MS Word document', 'doc', null, 'replacing');
DAV_REGISTER_MIME_TYPE ('application/msword+xml', 'MS Word document (XML)', 'xml', null, 'replacing');
DAV_REGISTER_MIME_TYPE ('application/opml+xml', 'OPML outlines', 'opml', null, 'replacing');
DAV_REGISTER_MIME_TYPE ('application/ocs+xml', 'OCS outlines', 'ocs', null, 'replacing');
DAV_REGISTER_MIME_TYPE ('application/pdf', 'PDF (Acrobat document)', 'pdf', null, 'replacing');
DAV_REGISTER_MIME_TYPE ('application/rss+xml', 'RSS Syndication', 'rss', null, 'replacing');
DAV_REGISTER_MIME_TYPE ('application/wsdl+xml', 'WSDL web service description', 'wsdl', null, 'replacing');
DAV_REGISTER_MIME_TYPE ('application/xbel+xml', 'XBEL Bookmark Exchange', 'xbel', null, 'replacing');
DAV_REGISTER_MIME_TYPE ('application/xddl+xml', 'XDDL', 'xddl', null, 'replacing');
DAV_REGISTER_MIME_TYPE ('application/x-apple-spotlight', 'Spotlight Objects', 'mdobject', null, 'replacing');
DAV_REGISTER_MIME_TYPE ('application/x-openlink-image', 'JPEG Image', 'jpg', null, 'replacing');
DAV_REGISTER_MIME_TYPE ('application/rdf+xml', 'RDF Data (RDF-XML, N3, Turtle)', 'rdf', null, 'replacing');
DAV_REGISTER_MIME_TYPE ('application/x-openlink-photo', 'Photo', 'jpg', null, 'replacing');
DAV_REGISTER_MIME_TYPE ('application/zip', 'ZIP Archive', 'zip', null, 'replacing');
DAV_REGISTER_MIME_TYPE ('application/x-openlinksw-vad', 'OpenLink Virtuoso VAD package', 'vad', null, 'replacing');
DAV_REGISTER_MIME_TYPE ('application/x-openlinksw-vsp', 'VSP Virtuoso Server Page', 'vsp', null, 'replacing');
DAV_REGISTER_MIME_TYPE ('application/x-openlinksw-vspx+xml', 'VSP Virtuoso Server Page', 'vspx', null, 'replacing');
DAV_REGISTER_MIME_TYPE ('text/directory', 'Directory data (VCARD etc)', 'vcard', null, 'replacing');
DAV_REGISTER_MIME_TYPE ('text/x-vCard', 'vCard (Business Cards)', 'vcf', null, 'replacing');
DAV_REGISTER_MIME_TYPE ('text/calendar', 'Calendar data (iCal etc)', 'ics', null, 'replacing');
DAV_REGISTER_MIME_TYPE ('text/html', 'Web pages (HTML etc)', 'html', null, 'replacing');
DAV_REGISTER_MIME_TYPE ('text/eml', 'Email files', 'eml', null, 'replacing');
DAV_REGISTER_MIME_TYPE ('text/wiki', 'Wiki files', 'wiki', null, 'replacing');
DAV_REGISTER_MIME_TYPE ('application/xbrl+xml', 'Business Reports', 'xbrl', null, 'replacing');
DAV_REGISTER_MIME_TYPE ('text/turtle', 'RDF Data (RDF-XML, N3, Turtle)', 'ttl', null, 'replacing');
DAV_REGISTER_MIME_TYPE ('text/rdf+n3', 'RDF Data (RDF-XML, N3, Turtle)', 'n3', null, 'replacing');
DAV_REGISTER_MIME_TYPE ('application/doap+rdf', 'DOAP Projects', 'doap', null, 'replacing');
DAV_REGISTER_MIME_TYPE ('application/license', 'OpenLink License', 'lic', null, 'replacing');
DAV_REGISTER_MIME_TYPE ('application/annotea+xml', 'Annotea Shared Bookmarks', 'xml', null, 'replacing');
DAV_REGISTER_MIME_TYPE ('application/google-base+xml', 'Google Base documents', 'xml', null, 'replacing');
DAV_REGISTER_MIME_TYPE ('image/png', 'PNG Image', 'png', null, 'replacing');
DAV_REGISTER_MIME_TYPE ('audio/mpeg', 'MP3 Format Sound', 'mp3', null, 'replacing');
DAV_REGISTER_MIME_TYPE ('audio/x-flac', 'FLAC Format Sound', 'flac', null, 'replacing');
DAV_REGISTER_MIME_TYPE ('audio/x-mp3', 'MP3 Format Sound', 'mp3', null, 'replacing');
DAV_REGISTER_MIME_TYPE ('audio/x-m4a', 'M4A Format Sound', 'm4a', null, 'replacing');
DAV_REGISTER_MIME_TYPE ('audio/x-m4p', 'M4P Format Sound', 'm4p', null, 'replacing');
DAV_REGISTER_MIME_TYPE ('application/ogg', 'OGG Media', 'ogg', null, 'replacing');

select count(*) from WS.WS.SYS_DAV_RES_TYPES where http_mime_type_add (T_EXT, T_TYPE)
;

-- register relations - RDF <-> MIME
--
DAV_REGISTER_MIME_RDF('application/bpel+xml', 'http://www.openlinksw.com/schemas/WSDL#');
DAV_REGISTER_MIME_RDF('application/foaf+xml', 'http://xmlns.com/foaf/0.1/');
DAV_REGISTER_MIME_RDF('application/mods+xml', 'http://www.openlinksw.com/schemas/MODS#');
DAV_REGISTER_MIME_RDF('application/msexcel', 'http://www.openlinksw.com/schemas/Office#');
DAV_REGISTER_MIME_RDF('application/msaccess', 'http://www.openlinksw.com/schemas/Office#');
DAV_REGISTER_MIME_RDF('application/mspowerpoint', 'http://www.openlinksw.com/schemas/Office#');
DAV_REGISTER_MIME_RDF('application/msproject', 'http://www.openlinksw.com/schemas/Office#');
DAV_REGISTER_MIME_RDF('application/msword', 'http://www.openlinksw.com/schemas/Office#');
DAV_REGISTER_MIME_RDF('application/msword+xml', 'http://www.openlinksw.com/schemas/Office#');
DAV_REGISTER_MIME_RDF('application/opml+xml', 'http://www.openlinksw.com/schemas/OPML#');
DAV_REGISTER_MIME_RDF('application/ocs+xml', 'http://www.openlinksw.com/schemas/OPML#');
DAV_REGISTER_MIME_RDF('application/vnd.oasis.opendocument.text', 'urn:oasis:names:tc:opendocument:xmlns:meta:1.0');
DAV_REGISTER_MIME_RDF('application/vnd.oasis.opendocument.database', 'urn:oasis:names:tc:opendocument:xmlns:meta:1.0');
DAV_REGISTER_MIME_RDF('application/vnd.oasis.opendocument.graphics', 'urn:oasis:names:tc:opendocument:xmlns:meta:1.0');
DAV_REGISTER_MIME_RDF('application/vnd.oasis.opendocument.presentation', 'urn:oasis:names:tc:opendocument:xmlns:meta:1.0');
DAV_REGISTER_MIME_RDF('application/vnd.oasis.opendocument.spreadsheet', 'urn:oasis:names:tc:opendocument:xmlns:meta:1.0');
DAV_REGISTER_MIME_RDF('application/vnd.oasis.opendocument.chart', 'urn:oasis:names:tc:opendocument:xmlns:meta:1.0');
DAV_REGISTER_MIME_RDF('application/vnd.oasis.opendocument.formula', 'urn:oasis:names:tc:opendocument:xmlns:meta:1.0');
DAV_REGISTER_MIME_RDF('application/vnd.oasis.opendocument.image', 'urn:oasis:names:tc:opendocument:xmlns:meta:1.0');
DAV_REGISTER_MIME_RDF('application/pdf', 'http://www.openlinksw.com/schemas/Office#');
DAV_REGISTER_MIME_RDF('application/rss+xml', 'http://purl.org/rss/1.0/');
DAV_REGISTER_MIME_RDF('application/wsdl+xml', 'http://www.openlinksw.com/schemas/WSDL#');
DAV_REGISTER_MIME_RDF('application/xbel+xml', 'http://www.python.org/topics/xml/xbel/');
DAV_REGISTER_MIME_RDF('application/xddl+xml', 'http://www.openlinksw.com/schemas/XDDL#');
DAV_REGISTER_MIME_RDF('application/x-apple-spotlight', 'http://www.apple.com/metadata#');
DAV_REGISTER_MIME_RDF('application/x-openlink-image', 'http://www.openlinksw.com/schemas/Image#');
DAV_REGISTER_MIME_RDF('text/eml', 'http://www.openlinksw.com/schemas/Email#');
DAV_REGISTER_MIME_RDF('application/rdf+xml', 'http://www.openlinksw.com/schemas/RDF#');
DAV_REGISTER_MIME_RDF('application/x-openlink-photo', 'http://www.openlinksw.com/schemas/Photo#');
DAV_REGISTER_MIME_RDF('application/zip', 'http://www.openlinksw.com/schemas/Archive#');
DAV_REGISTER_MIME_RDF('application/x-openlinksw-vad', 'http://www.openlinksw.com/schemas/VAD#');
DAV_REGISTER_MIME_RDF('application/x-openlinksw-vsp', 'http://www.openlinksw.com/schemas/VSPX#');
DAV_REGISTER_MIME_RDF('application/x-openlinksw-vspx+xml', 'http://www.openlinksw.com/schemas/VSPX#');
DAV_REGISTER_MIME_RDF('text/turtle', 'http://www.openlinksw.com/schemas/RDF#');
DAV_REGISTER_MIME_RDF('text/rdf+n3', 'http://www.openlinksw.com/schemas/RDF#');
DAV_REGISTER_MIME_RDF('text/x-vCard', 'http://www.w3.org/2001/vcard-rdf/3.0#');
DAV_REGISTER_MIME_RDF('text/calendar', 'http://www.openlinksw.com/schemas/ICS#');
DAV_REGISTER_MIME_RDF('text/html', 'http://www.openlinksw.com/schemas/XHTML#');
DAV_REGISTER_MIME_RDF('text/wiki', 'http://www.openlinksw.com/schemas/Wiki#');
DAV_REGISTER_MIME_RDF('application/xbrl+xml', 'http://www.openlinksw.com/schemas/xbrl#');
DAV_REGISTER_MIME_RDF('application/doap+rdf', 'http://www.openlinksw.com/schemas/doap#');
DAV_REGISTER_MIME_RDF('application/license', 'http://www.openlinksw.com/schemas/OplLic#');
DAV_REGISTER_MIME_RDF('application/annotea+xml', 'http://www.openlinksw.com/schemas/Annotea#');
DAV_REGISTER_MIME_RDF('application/google-base+xml', 'http://www.openlinksw.com/schemas/google-base#');
DAV_REGISTER_MIME_RDF('image/bmp', 'http://www.openlinksw.com/schemas/Photo#');
DAV_REGISTER_MIME_RDF('image/gif', 'http://www.openlinksw.com/schemas/Photo#');
DAV_REGISTER_MIME_RDF('image/ief', 'http://www.openlinksw.com/schemas/Photo#');
DAV_REGISTER_MIME_RDF('image/jpeg', 'http://www.openlinksw.com/schemas/Photo#');
DAV_REGISTER_MIME_RDF('image/png', 'http://www.openlinksw.com/schemas/Photo#');
DAV_REGISTER_MIME_RDF('image/tiff', 'http://www.openlinksw.com/schemas/Photo#');
DAV_REGISTER_MIME_RDF('image/x-cmu-raster', 'http://www.openlinksw.com/schemas/Photo#');
DAV_REGISTER_MIME_RDF('image/x-portable-anymap', 'http://www.openlinksw.com/schemas/Photo#');
DAV_REGISTER_MIME_RDF('image/x-portable-bitmap', 'http://www.openlinksw.com/schemas/Photo#');
DAV_REGISTER_MIME_RDF('image/x-portable-graymap', 'http://www.openlinksw.com/schemas/Photo#');
DAV_REGISTER_MIME_RDF('image/x-portable-pixmap', 'http://www.openlinksw.com/schemas/Photo#');
DAV_REGISTER_MIME_RDF('image/x-rgb', 'http://www.openlinksw.com/schemas/Photo#');
DAV_REGISTER_MIME_RDF('image/x-xbitmap', 'http://www.openlinksw.com/schemas/Photo#');
DAV_REGISTER_MIME_RDF('image/x-xpixmap', 'http://www.openlinksw.com/schemas/Photo#');
DAV_REGISTER_MIME_RDF('image/x-xwindowdump', 'http://www.openlinksw.com/schemas/Photo#');
DAV_REGISTER_MIME_RDF('image/bmp', 'http://www.openlinksw.com/schemas/Image#');
DAV_REGISTER_MIME_RDF('image/gif', 'http://www.openlinksw.com/schemas/Image#');
DAV_REGISTER_MIME_RDF('image/ief', 'http://www.openlinksw.com/schemas/Image#');
DAV_REGISTER_MIME_RDF('image/jpeg', 'http://www.openlinksw.com/schemas/Image#');
DAV_REGISTER_MIME_RDF('image/png', 'http://www.openlinksw.com/schemas/Image#');
DAV_REGISTER_MIME_RDF('image/tiff', 'http://www.openlinksw.com/schemas/Image#');
DAV_REGISTER_MIME_RDF('image/x-cmu-raster', 'http://www.openlinksw.com/schemas/Image#');
DAV_REGISTER_MIME_RDF('image/x-portable-anymap', 'http://www.openlinksw.com/schemas/Image#');
DAV_REGISTER_MIME_RDF('image/x-portable-bitmap', 'http://www.openlinksw.com/schemas/Image#');
DAV_REGISTER_MIME_RDF('image/x-portable-graymap', 'http://www.openlinksw.com/schemas/Image#');
DAV_REGISTER_MIME_RDF('image/x-portable-pixmap', 'http://www.openlinksw.com/schemas/Image#');
DAV_REGISTER_MIME_RDF('image/x-rgb', 'http://www.openlinksw.com/schemas/Image#');
DAV_REGISTER_MIME_RDF('image/x-xbitmap', 'http://www.openlinksw.com/schemas/Image#');
DAV_REGISTER_MIME_RDF('image/x-xpixmap', 'http://www.openlinksw.com/schemas/Image#');
DAV_REGISTER_MIME_RDF('image/x-xwindowdump', 'http://www.openlinksw.com/schemas/Image#');
DAV_REGISTER_MIME_RDF('audio/mpeg', 'http://www.openlinksw.com/schemas/audio#');
DAV_REGISTER_MIME_RDF('audio/x-flac', 'http://www.openlinksw.com/schemas/audio#');
DAV_REGISTER_MIME_RDF('audio/x-mp3', 'http://www.openlinksw.com/schemas/audio#');
DAV_REGISTER_MIME_RDF('audio/x-m4a', 'http://www.openlinksw.com/schemas/audio#');
DAV_REGISTER_MIME_RDF('audio/x-m4p', 'http://www.openlinksw.com/schemas/audio#');
DAV_REGISTER_MIME_RDF('application/ogg', 'http://www.openlinksw.com/schemas/audio#');

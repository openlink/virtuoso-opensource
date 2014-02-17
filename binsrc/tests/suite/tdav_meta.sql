--
--  $Id: tdav_meta.sql,v 1.12.6.2.4.1 2013/01/02 16:15:02 source Exp $
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
--set echo on;

--ECHO BOTH "Loading sample DAV files"

create procedure passed_if_not_error (in msg varchar, in x any)
{
  if (DAV_HIDE_ERROR (x) is not null)
    result ('PASSED: ' || msg);
  else
    result ('***' || 'FAI' || 'LED: ' || msg || ': ' || cast (x as varchar));
  commit work;
}
;

create procedure TDAV_META_LOAD ()
{
  declare status,s,m varchar;
  result_names (status);
  passed_if_not_error ('add group HostFs_tdav_meta', DAV_ADD_GROUP ('HostFs_tdav_meta', 'dav', 'dav'));
  passed_if_not_error ('add group tdav_meta_grp', DAV_ADD_GROUP ('tdav_meta_grp', 'dav', 'dav'));
  passed_if_not_error ('add user tdav_meta',
    DAV_ADD_USER ('tdav_meta', 'tdav_meta_pwd', 'tdav_meta_grp', '110100000T', 0, '/DAV/tdav_meta_home/',
      'Sample user for binsrc/tests/suite/tdav_meta.sh', 'tdav_meta@localhost', 'dav', 'dav' ) );
  exec ('grant "HostFs_tdav_meta" to "tdav_meta"',s,m);
  passed_if_not_error ('mkcol /DAV/mnt/', DAV_COL_CREATE ('/DAV/mnt/', '110110110R', 'dav', 'administrators', 'dav', 'dav'));
  passed_if_not_error ('mkcol /DAV/mnt/tdav_meta/', DAV_COL_CREATE ('/DAV/mnt/tdav_meta/', '110100000R', 'tdav_meta', 'HostFs_tdav_meta', 'dav', 'dav'));
  update WS.WS.SYS_DAV_COL set COL_DET='HostFs' where COL_NAME='tdav_meta';
  commit work;
  passed_if_not_error ('mkcol /DAV/tdav_meta_home/catfilt/',
    DAV_COL_CREATE ('/DAV/tdav_meta_home/catfilt/', '110100000R', 'tdav_meta', 'tdav_meta_grp', 'dav', 'dav') );
  passed_if_not_error ('mkcol /DAV/tdav_meta_home/zip_samples/',
    DAV_COL_CREATE ('/DAV/tdav_meta_home/zip_samples/', '110100000R', 'tdav_meta', 'tdav_meta_grp', 'dav', 'dav') );
  passed_if_not_error ('set up CatFilter in /DAV/tdav_meta_home/catfilt/',
    "CatFilter_CONFIGURE" (
      DAV_SEARCH_ID ('/DAV/tdav_meta_home/catfilt/', 'C'),
      '',
      '/DAV/tdav_meta_home/',
      vector() ) );
  passed_if_not_error ('copy /DAV/mnt/tdav_meta/ to /DAV/tdav_meta_home/zip_samples/',
    DAV_COPY ('/DAV/mnt/tdav_meta/', '/DAV/tdav_meta_home/zip_samples/', 1, '110100000R', 'tdav_meta', NULL, 'tdav_meta', 'tdav_meta_pwd') );
}
;

create procedure TDAV_META_CHECK (in resname varchar, in propuri varchar, in propval varchar)
{
  declare status varchar;
  result_names (status);
  if (exists (
    select top 1 1
    from WS.WS.SYS_DAV_RDF_INVERSE, WS.WS.SYS_DAV_RES, WS.WS.SYS_RDF_PROP_NAME
    where
      RES_FULL_PATH like '/DAV/tdav_meta_home/%' and
      DRI_PROP_CATID = RPN_CATID and
      RES_ID = DRI_RES_ID and
      RES_NAME = resname and
      RPN_URI = propuri and
      DRI_CATVALUE = propval ) )
    result (sprintf ('PASSED: triplet S=%s P=%s V=%s', resname, propuri, propval));
  else
    {
      declare actual_value any;
      actual_value := coalesce ((
    select top 1 DRI_CATVALUE
    from WS.WS.SYS_DAV_RDF_INVERSE, WS.WS.SYS_DAV_RES, WS.WS.SYS_RDF_PROP_NAME
    where
      RES_FULL_PATH like '/DAV/tdav_meta_home/%' and
      DRI_PROP_CATID = RPN_CATID and
      RES_ID = DRI_RES_ID and
      RES_NAME = resname and
      RPN_URI = propuri ) );
      result (sprintf ('***' || 'FAI' || 'LED: triplet S=%s P=%s V=%s (found %s)', resname, propuri, propval, actual_value));
    }
}
;

create procedure TDAV_META_DUMP_CHECKS (in fname varchar := 'tdav_meta_checks.log')
{
  declare ses any;
  ses := string_output ();
  for
    select RES_NAME, RPN_URI, DRI_CATVALUE
    from WS.WS.SYS_DAV_RDF_INVERSE, WS.WS.SYS_DAV_RES, WS.WS.SYS_RDF_PROP_NAME
    where
      RES_FULL_PATH like '/DAV/tdav_meta_home/%' and
      DRI_PROP_CATID = RPN_CATID and
      RES_ID = DRI_RES_ID
    order by 1,2,3
    do
    {
      http (
        sprintf ('TDAV_META_CHECK (%s, %s, %s);\n',
          WS.WS.STR_SQL_APOS(RES_NAME),
          WS.WS.STR_SQL_APOS(RPN_URI),
          WS.WS.STR_SQL_APOS (DRI_CATVALUE) )
        , ses );
    }
  string_to_file (fname, string_output_string (ses), -2);
}
;

create function TDAV_URIQA (in host varchar, in uri varchar, in method varchar, in body varchar)
{
  declare hdr, retbody, rethdr varchar;
--  hdr := 'Host: ' || host || '\r\nAuthorization: Basic ZGF2OmRhdg==';
  hdr := 'Authorization: Basic ZGF2OmRhdg==';
  retbody := http_get ('http://' || host || uri, rethdr, method, hdr, body);
  dbg_obj_print ('RESULT:', rethdr[0] || '\r\n\r\n' || retbody);
  return rethdr[0] || '\r\n\r\n' || retbody;
}

TDAV_META_LOAD ();
--TDAV_META_DUMP_CHECKS ();

ECHO BOTH "Starting URIQA tests. In case of errors this may result a wait for timeout\n";

select isnull (strstr (TDAV_URIQA ('$U{HOST}', '/DAV/tdav_meta_home/zip_samples/', 'MGET',''), 'Kingsley Idehen.foaf'));
ECHO BOTH $IF $EQU $LAST[1] 0  "PASSED" "***FAILED";
ECHO BOTH ": MGET on collection\n";

select isnull (strstr (TDAV_URIQA ('$U{HOST}', '/DAV/tdav_meta_home/zip_samples/Kingsley%20Idehen.foaf', 'MGET',''), 'RDF'));
ECHO BOTH $IF $EQU $LAST[1] 0  "PASSED" "***FAILED";
ECHO BOTH ": MGET on existing FOAF\n";

select isnull (strstr (TDAV_URIQA ('$U{HOST}', '/DAV/tdav_meta_home/zip_samples/Kingsley_Idehen.foaf', 'MGET',''), '500'));
ECHO BOTH $IF $EQU $LAST[1] 0  "PASSED" "***FAILED";
ECHO BOTH ": MGET on non-existing FOAF\n";

select isnull (strstr (TDAV_URIQA ('$U{HOST}', '/DAV/tdav_meta_home/zip_samples/News_Feeds.opml', 'MGET',''), 'Untitled OPML'));
ECHO BOTH $IF $EQU $LAST[1] 0  "PASSED" "***FAILED";
ECHO BOTH ": MGET on existing OPML\n";

select isnull (strstr (TDAV_URIQA ('$U{HOST}', '/DAV/tdav_meta_home/zip_samples/News_Feeds.opml', 'MPUT',
'<?xml version="1.0" encoding="ISO-8859-1" ?><rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
<rdf:Description rdf:about="http://localhost:8313/DAV/tdav_meta_home/zip_samples/News_Feeds.opml">
<n2:added xmlns:n2="http://www.openlinksw.com/schemas/OPML#">added value</n2:added>
</rdf:Description></rdf:RDF>
'), '200 OK') );

ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": MPUT on existing OPML\n";

select isnull (strstr (TDAV_URIQA ('$U{HOST}', '/DAV/tdav_meta_home/zip_samples/News_Feeds.opml', 'MGET',''), 'added value'));
ECHO BOTH $IF $EQU $LAST[1] 0  "PASSED" "***FAILED";
ECHO BOTH ": MGET of added value on OPML\n";

select TDAV_URIQA ('$U{HOST}', '/DAV/tdav_meta_home/zip_samples/News_Feeds.opml', 'MDELETE',
'<?xml version="1.0" encoding="ISO-8859-1" ?><rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
<rdf:Description rdf:about="http://localhost:8313/DAV/tdav_meta_home/zip_samples/News_Feeds.opml">
<n2:added xmlns:n2="http://www.openlinksw.com/schemas/OPML#">added value</n2:added>
</rdf:Description></rdf:RDF>
');

select isnull (strstr (TDAV_URIQA ('$U{HOST}', '/DAV/tdav_meta_home/zip_samples/News_Feeds.opml', 'MGET',''), 'added value'));
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": MGET of removed value on OPML\n";

select isnull (strstr (http_get ('http://$U{HOST}/URIQA/'), 'RDF'));
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": /URIQA/ interactive web-page\n";

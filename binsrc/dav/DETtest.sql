--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2015 OpenLink Software
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

set echo on;
set verbose off;

select DAV_ADD_GROUP ('g1', 'dav', 'dav');
select DAV_ADD_GROUP ('g2', 'dav', 'dav');
select DAV_ADD_USER ('u1g1', 'u1g1_pwd', 'g1', '110100000T', 0, '/DAV/home/u1g1/', 'User 1 of group 1', 'u1g1@localhost', 'dav', 'dav');
select DAV_ADD_USER ('u2g1', 'u2g1_pwd', 'g1', '110100000T', 0, '/DAV/home/u2g1/', 'User 2 of group 1', 'u2g1@localhost', 'dav', 'dav');
select DAV_ADD_USER ('u1g2', 'u1g2_pwd', 'g2', '110100000T', 0, '/DAV/home/u1g2/', 'User 1 of group 2', 'u1g2@localhost', 'dav', 'dav');
select DAV_ADD_USER ('u2g2', 'u2g2_pwd', 'g2', '110100000T', 0, '/DAV/home/u2g2/', 'User 2 of group 2', 'u2g2@localhost', 'dav', 'dav');

select DAV_COL_CREATE ('/DAV/home/u1g1/', '110100000RR', 'u1g1', 'g1', 'dav', 'dav');
select DAV_COL_CREATE ('/DAV/home/u2g1/', '110100000RR', 'u2g1', 'g1', 'dav', 'dav');
select DAV_COL_CREATE ('/DAV/home/u1g2/', '110100000RR', 'u1g2', 'g2', 'dav', 'dav');
select DAV_COL_CREATE ('/DAV/home/u2g2/', '110100000RR', 'u2g2', 'g2', 'dav', 'dav');

select DAV_RES_UPLOAD ('/DAV/home/u1g1/DETtest_u1g1.htm', '<html>This is /DAV/u1g1_home/DETtest_u1g1.htm</html>', '', '110100000RR', 'u1g1', 'g1', 'u1g1', 'u1g1_pwd' );
select DAV_RES_UPLOAD ('/DAV/home/u2g1/DETtest_u2g1.htm', '<html>This is /DAV/u1g1_home/DETtest_u2g1.htm</html>', '', '110100000RR', 'u2g1', 'g1', 'u2g1', 'u2g1_pwd' );
select DAV_RES_UPLOAD ('/DAV/home/u1g2/DETtest_u1g2.htm', '<html>This is /DAV/u1g1_home/DETtest_u1g2.htm</html>', '', '110100000RR', 'u1g2', 'g2', 'u1g2', 'u1g2_pwd' );
select DAV_RES_UPLOAD ('/DAV/home/u2g2/DETtest_u2g2.htm', '<html>This is /DAV/u1g1_home/DETtest_u2g2.htm</html>', '', '110100000RR', 'u2g2', 'g2', 'u2g2', 'u2g2_pwd' );

select DAV_RES_UPLOAD ('/DAV/home/u1g1/000000000.htm', '<html>This is /DAV/home/u1g1/000000000.htm</html>', '', '000000000RR', 'u1g1', 'g1', 'u1g1', 'u1g1_pwd' );
select DAV_RES_UPLOAD ('/DAV/home/u1g1/100000000.htm', '<html>This is /DAV/home/u1g1/100000000.htm</html>', '', '100000000RR', 'u1g1', 'g1', 'u1g1', 'u1g1_pwd' );
select DAV_RES_UPLOAD ('/DAV/home/u1g1/010000000.htm', '<html>This is /DAV/home/u1g1/010000000.htm</html>', '', '010000000RR', 'u1g1', 'g1', 'u1g1', 'u1g1_pwd' );
select DAV_RES_UPLOAD ('/DAV/home/u1g1/001000000.htm', '<html>This is /DAV/home/u1g1/001000000.htm</html>', '', '001000000RR', 'u1g1', 'g1', 'u1g1', 'u1g1_pwd' );
select DAV_RES_UPLOAD ('/DAV/home/u1g1/000100000.htm', '<html>This is /DAV/home/u1g1/000100000.htm</html>', '', '000100000RR', 'u1g1', 'g1', 'u1g1', 'u1g1_pwd' );
select DAV_RES_UPLOAD ('/DAV/home/u1g1/000010000.htm', '<html>This is /DAV/home/u1g1/000010000.htm</html>', '', '000010000RR', 'u1g1', 'g1', 'u1g1', 'u1g1_pwd' );
select DAV_RES_UPLOAD ('/DAV/home/u1g1/000001000.htm', '<html>This is /DAV/home/u1g1/000001000.htm</html>', '', '000001000RR', 'u1g1', 'g1', 'u1g1', 'u1g1_pwd' );
select DAV_RES_UPLOAD ('/DAV/home/u1g1/000000100.htm', '<html>This is /DAV/home/u1g1/000000100.htm</html>', '', '000000100RR', 'u1g1', 'g1', 'u1g1', 'u1g1_pwd' );
select DAV_RES_UPLOAD ('/DAV/home/u1g1/000000010.htm', '<html>This is /DAV/home/u1g1/000000010.htm</html>', '', '000000010RR', 'u1g1', 'g1', 'u1g1', 'u1g1_pwd' );
select DAV_RES_UPLOAD ('/DAV/home/u1g1/000000001.htm', '<html>This is /DAV/home/u1g1/000000001.htm</html>', '', '000000001RR', 'u1g1', 'g1', 'u1g1', 'u1g1_pwd' );
select DAV_RES_UPLOAD ('/DAV/home/u1g1/110000000.htm', '<html>This is /DAV/home/u1g1/110000000.htm</html>', '', '110000000RR', 'u1g1', 'g1', 'u1g1', 'u1g1_pwd' );
select DAV_RES_UPLOAD ('/DAV/home/u1g1/111000000.htm', '<html>This is /DAV/home/u1g1/111000000.htm</html>', '', '111000000RR', 'u1g1', 'g1', 'u1g1', 'u1g1_pwd' );
select DAV_RES_UPLOAD ('/DAV/home/u1g1/111100000.htm', '<html>This is /DAV/home/u1g1/111100000.htm</html>', '', '111100000RR', 'u1g1', 'g1', 'u1g1', 'u1g1_pwd' );
select DAV_RES_UPLOAD ('/DAV/home/u1g1/111110000.htm', '<html>This is /DAV/home/u1g1/111110000.htm</html>', '', '111110000RR', 'u1g1', 'g1', 'u1g1', 'u1g1_pwd' );
select DAV_RES_UPLOAD ('/DAV/home/u1g1/111111000.htm', '<html>This is /DAV/home/u1g1/111111000.htm</html>', '', '111111000RR', 'u1g1', 'g1', 'u1g1', 'u1g1_pwd' );
select DAV_RES_UPLOAD ('/DAV/home/u1g1/111111100.htm', '<html>This is /DAV/home/u1g1/111111100.htm</html>', '', '111111100RR', 'u1g1', 'g1', 'u1g1', 'u1g1_pwd' );
select DAV_RES_UPLOAD ('/DAV/home/u1g1/111111110.htm', '<html>This is /DAV/home/u1g1/111111110.htm</html>', '', '111111110RR', 'u1g1', 'g1', 'u1g1', 'u1g1_pwd' );
select DAV_RES_UPLOAD ('/DAV/home/u1g1/111111111.htm', '<html>This is /DAV/home/u1g1/111111111.htm</html>', '', '111111111RR', 'u1g1', 'g1', 'u1g1', 'u1g1_pwd' );
select DAV_RES_UPLOAD ('/DAV/home/u1g1/110100000.htm', '<html>This is /DAV/home/u1g1/110100000.htm</html>', '', '110100000RR', 'u1g1', 'g1', 'u1g1', 'u1g1_pwd' );
select DAV_RES_UPLOAD ('/DAV/home/u1g1/110100100.htm', '<html>This is /DAV/home/u1g1/110100100.htm</html>', '', '110100100RR', 'u1g1', 'g1', 'u1g1', 'u1g1_pwd' );
select DAV_RES_UPLOAD ('/DAV/home/u1g1/110110100.htm', '<html>This is /DAV/home/u1g1/110110100.htm</html>', '', '110110100RR', 'u1g1', 'g1', 'u1g1', 'u1g1_pwd' );
select DAV_RES_UPLOAD ('/DAV/home/u1g1/110110110.htm', '<html>This is /DAV/home/u1g1/110110110.htm</html>', '', '110110110RR', 'u1g1', 'g1', 'u1g1', 'u1g1_pwd' );

select DAV_COL_CREATE ('/DAV/111111111/', '111111111RR', 'u1g1', 'g1', 'dav', 'dav');


select DAV_ADD_GROUP ('HostFs_inputs', 'dav', 'dav');
select DAV_COL_CREATE ('/DAV/inputs/', '110100000RR', 'dav', 'administrators', 'dav', 'dav');
update WS.WS.SYS_DAV_COL set COL_DET='HostFs' where COL_ID = DAV_SEARCH_ID ('/DAV/inputs/', 'C');
select * from WS.WS.SYS_DAV_COL where COL_NAME='inputs' and COL_PARENT=1;
select DAV_COL_CREATE ('/DAV/inputs/tmp/', '110100000RR', 'dav', 'administrators', 'dav', 'dav');
select DAV_COL_CREATE ('/DAV/inputs/tmp2/', '110100000RR', 'dav', 'administrators', 'dav', 'dav');
dbg_obj_print ('DIR_LIST of inputs', DAV_DIR_LIST ('/DAV/inputs/', 0, 'dav', 'dav'));
dbg_obj_print ('SEARCH_ID of inputs/.cvsignore', DAV_SEARCH_ID ('/DAV/inputs/.cvsignore', 'r'));
select DAV_SEARCH_ID ('/DAV/inputs/.cvsignore', 'r') [1];
dbg_obj_print ('SEARCH_ID of inputs/CVS/', DAV_SEARCH_ID ('/DAV/inputs/CVS/', 'c'));
select DAV_SEARCH_ID ('/DAV/inputs/CVS/', 'c') [1];
select DAV_SEARCH_PATH (DAV_SEARCH_ID ('/DAV/inputs/.cvsignore', 'r'), 'r');
select DAV_SEARCH_PATH (DAV_SEARCH_ID ('/DAV/inputs/CVS/', 'c'), 'c');
select DAV_RES_UPLOAD ('/DAV/inputs/DETtest_upload1.htm',
 '<html>This is /DAV/inputs/DETtest_upload1.htm</html>',
 '', '110100000RR', 'dav', 'administrators', 'dav', 'dav' );
select DAV_RES_UPLOAD ('/DAV/inputs/tmp/DETtest_upload2.htm',
 '<html>/DAV/inputs/tmp/DETtest_upload2.htm</html>',
 '', '110100000RR', 'dav', 'administrators', 'dav', 'dav' );

 create procedure c_cp2 (in uri varchar, in dst varchar)
{
  declare _slen, _sctr integer;
  declare hdr any;
  declare code integer;
  declare h_line, RES, body varchar;
  uri := WB_CFG_HTTP_URI() || uri;
  dst := WB_CFG_HTTP_URI() || dst;
  h_line := sprintf ('Overwrite: T\r\nAuthorization: Basic ZGF2OmRhdg==\r\nDestination: %s\r\nDepth: infinity', dst);
  body := http_get (uri, hdr, 'COPY', h_line);
  result_names (RES);
  _slen := length (hdr);
  _sctr := 0;
  while (_sctr < _slen)
    {
      result (aref (hdr, _sctr));
      _sctr := _sctr+1;
    }
  result('--------');
  dump_large_text_impl (body);
}
;



create procedure
TEST_DAV_RES_CONTENT (in path varchar, in auth_uname varchar := null, in auth_pwd varchar := null)
{
  declare content any;
  declare type varchar;
  declare rc integer;
  rc := DAV_RES_CONTENT (path, content, type, auth_uname, auth_pwd);
  dump_large_text (concat (sprintf ('Status %d\nType %s\n', rc, type), blob_to_string (content)));
}
;


select DAV_COL_CREATE ('/DAV/pftest/'		, '110100000RR', 'dav', 'administrators', 'dav', 'dav');
select DAV_COL_CREATE ('/DAV/pftest/orig/'	, '110100000RR', 'dav', 'administrators', 'dav', 'dav');
select DAV_COL_CREATE ('/DAV/pftest/orig/sub1/'	, '110100000RR', 'dav', 'administrators', 'dav', 'dav');
select DAV_COL_CREATE ('/DAV/pftest/orig/sub2/'	, '110100000RR', 'dav', 'administrators', 'dav', 'dav');
select DAV_COL_CREATE ('/DAV/pftest/filt/'	, '110100000RR', 'dav', 'administrators', 'dav', 'dav');
select DAV_PROP_SET ('/DAV/pftest/filt/', 'virt:PropFilter-SearchPath', '/DAV/pftest/orig/', 'dav', 'dav');
select DAV_PROP_SET ('/DAV/pftest/filt/', 'virt:PropFilter-PropName', 'WikiV:ClusterName', 'dav', 'dav');
select DAV_PROP_SET ('/DAV/pftest/filt/', 'virt:PropFilter-PropValue', 'Main', 'dav', 'dav');
update WS.WS.SYS_DAV_COL set COL_DET='PropFilter' where COL_ID = DAV_SEARCH_ID ('/DAV/pftest/filt/', 'C');

select DAV_RES_UPLOAD ('/DAV/pftest/orig/hit1.htm',
 '<html>This is /DAV/pftest/orig/hit1.htm</html>',
 'text/html', '110100000RR', 'dav', 'administrators', 'dav', 'dav' );

select DAV_RES_UPLOAD ('/DAV/pftest/orig/hit2.htm',
 '<html>This is /DAV/pftest/orig/hit2.htm</html>',
 'text/html', '110100000RR', 'dav', 'administrators', 'dav', 'dav' );

select DAV_RES_UPLOAD ('/DAV/pftest/orig/hit3.htm',
 '<html>This is /DAV/pftest/orig/hit2.htm</html>',
 'text/html', '110100000RR', 'dav', 'administrators', 'dav', 'dav' );

select DAV_RES_UPLOAD ('/DAV/pftest/orig/sub1/hit2.htm',
 '<html>This is /DAV/pftest/orig/sub1/hit2.htm</html>',
 'text/html', '110100000RR', 'dav', 'administrators', 'dav', 'dav' );

select DAV_RES_UPLOAD ('/DAV/pftest/orig/sub2/hit2.htm',
 '<html>This is /DAV/pftest/orig/sub2/hit2.htm</html>',
 'text/html', '110100000RR', 'dav', 'administrators', 'dav', 'dav' );

select DAV_RES_UPLOAD ('/DAV/pftest/orig/miss1.htm',
 '<html>This is /DAV/pftest/orig/miss1.htm</html>',
 'text/html', '110100000RR', 'dav', 'administrators', 'dav', 'dav' );

select DAV_RES_UPLOAD ('/DAV/pftest/orig/miss2.htm',
 '<html>This is /DAV/pftest/orig/miss1.htm</html>',
 'text/html', '110100000RR', 'dav', 'administrators', 'dav', 'dav' );

select DAV_PROP_SET ('/DAV/pftest/orig/hit1.htm', 'WikiV:ClusterName', 'Main', 'dav', 'dav');
select DAV_PROP_SET ('/DAV/pftest/orig/hit2.htm', 'WikiV:ClusterName', 'Main', 'dav', 'dav');
select DAV_PROP_SET ('/DAV/pftest/orig/hit3.htm', 'WikiV:ClusterName', 'Main', 'dav', 'dav');
select DAV_PROP_SET ('/DAV/pftest/orig/sub1/hit2.htm', 'WikiV:ClusterName', 'Main', 'dav', 'dav');
select DAV_PROP_SET ('/DAV/pftest/orig/sub2/hit2.htm', 'WikiV:ClusterName', 'Main', 'dav', 'dav');

select DAV_PROP_SET ('/DAV/pftest/orig/miss1.htm', 'WikiV:ClusterName', 'Wrong', 'dav', 'dav');
select DAV_PROP_SET ('/DAV/pftest/orig/miss2.htm', 'WikiV:WrongName', 'Main', 'dav', 'dav');


select DAV_COL_CREATE ('/DAV/wmtest/'		, '110110110RR', 'dav', 'administrators', 'dav', 'dav');
select DAV_COL_CREATE ('/DAV/wmtest/iv_all/'	, '110110110RR', 'iv', 'administrators', 'dav', 'dav');
select DAV_COL_CREATE ('/DAV/wmtest/iv_box/'	, '110110110RR', 'iv', 'administrators', 'dav', 'dav');
select DAV_COL_CREATE ('/DAV/wmtest/iv_sub1/'	, '110110110RR', 'iv', 'administrators', 'dav', 'dav');
select DAV_COL_CREATE ('/DAV/wmtest/iv_sub11/'	, '110110110RR', 'iv', 'administrators', 'dav', 'dav');
select DAV_PROP_SET ('/DAV/wmtest/iv_all/', 'virt:oMail-DomainId', '1', 'dav', 'dav');
select DAV_PROP_SET ('/DAV/wmtest/iv_all/', 'virt:oMail-UserName', 'iv', 'dav', 'dav');
select DAV_PROP_SET ('/DAV/wmtest/iv_all/', 'virt:oMail-FolderName', 'NULL', 'dav', 'dav');
select DAV_PROP_SET ('/DAV/wmtest/iv_all/', 'virt:oMail-NameFormat', '^from^ ^subject^', 'dav', 'dav');
select DAV_PROP_SET ('/DAV/wmtest/iv_box/', 'virt:oMail-DomainId', '1', 'dav', 'dav');
select DAV_PROP_SET ('/DAV/wmtest/iv_box/', 'virt:oMail-UserName', 'iv', 'dav', 'dav');
select DAV_PROP_SET ('/DAV/wmtest/iv_box/', 'virt:oMail-FolderName', 'Box', 'dav', 'dav');
select DAV_PROP_SET ('/DAV/wmtest/iv_box/', 'virt:oMail-NameFormat', '^from^ ^subject^', 'dav', 'dav');
select DAV_PROP_SET ('/DAV/wmtest/iv_sub1/', 'virt:oMail-DomainId', '1', 'dav', 'dav');
select DAV_PROP_SET ('/DAV/wmtest/iv_sub1/', 'virt:oMail-UserName', 'iv', 'dav', 'dav');
select DAV_PROP_SET ('/DAV/wmtest/iv_sub1/', 'virt:oMail-FolderName', 'sub1', 'dav', 'dav');
select DAV_PROP_SET ('/DAV/wmtest/iv_sub1/', 'virt:oMail-NameFormat', '^from^ ^subject^', 'dav', 'dav');
select DAV_PROP_SET ('/DAV/wmtest/iv_sub11/', 'virt:oMail-DomainId', '1', 'dav', 'dav');
select DAV_PROP_SET ('/DAV/wmtest/iv_sub11/', 'virt:oMail-UserName', 'iv', 'dav', 'dav');
select DAV_PROP_SET ('/DAV/wmtest/iv_sub11/', 'virt:oMail-FolderName', 'sub11', 'dav', 'dav');
select DAV_PROP_SET ('/DAV/wmtest/iv_sub11/', 'virt:oMail-NameFormat', '^from^ ^subject^', 'dav', 'dav');
update WS.WS.SYS_DAV_COL set COL_DET='oMail' where COL_ID = DAV_SEARCH_ID ('/DAV/wmtest/iv_all/', 'C');
update WS.WS.SYS_DAV_COL set COL_DET='oMail' where COL_ID = DAV_SEARCH_ID ('/DAV/wmtest/iv_box/', 'C');
update WS.WS.SYS_DAV_COL set COL_DET='oMail' where COL_ID = DAV_SEARCH_ID ('/DAV/wmtest/iv_sub1/', 'C');
update WS.WS.SYS_DAV_COL set COL_DET='oMail' where COL_ID = DAV_SEARCH_ID ('/DAV/wmtest/iv_sub11/', 'C');

select DAV_RDF_PROP_SET ('/DAV/pftest/orig/hit1.htm', 'http://local.virt/DAV-RDF',
xtree_doc('
<?xml version="1.0"?>
<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
         xmlns:dc="http://purl.org/dc/elements/1.1/"
         xmlns:ex="http://example.org/stuff/1.0/">

<rdf:Description rdf:about="http://www.w3.org/TR/rdf-syntax-grammar"
                 dc:title="RDF/XML Syntax Specification (Revised)">
  <ex:editor>
    <rdf:Description ex:fullName="Dave Beckett">
      <ex:homePage rdf:resource="http://purl.org/net/dajobe/"/>
    </rdf:Description>
  </ex:editor>
</rdf:Description>

</rdf:RDF>'),
'dav', 'dav' );

select length (DAV_DIR_FILTER ('/DAV/pftest/orig/', 1,
  vector (
    vector ('RDF_VALUE', '=', 'RDF/XML Syntax Specification (Revised)',
      'http://local.virt/DAV-RDF',
      'http://purl.org/dc/elements/1.1/title' )
    ),
  'dav', 'dav' ) );

select length (DAV_DIR_FILTER ('/DAV/pftest/orig/', 1,
  vector (
    vector ('RDF_OBJ_VALUE', '=', 'Dave Beckett',
      'http://local.virt/DAV-RDF',
      'http://example.org/stuff/1.0/editor',
      'http://example.org/stuff/1.0/fullName' )
    ),
  'dav', 'dav' ) );

select DAV_RDF_PROP_GET ('/DAV/pftest/orig/hit1.htm', 'http://local.virt/DAV-RDF', 'dav', 'dav');
select xslt ('http://local.virt/davxml2n3xml', DAV_RDF_PROP_GET ('/DAV/pftest/orig/hit1.htm', 'http://local.virt/DAV-RDF', 'dav', 'dav'));


select DAV_COL_CREATE ('/DAV/rftest/'		, '110100000RR', 'dav', 'administrators', 'dav', 'dav');
select DAV_COL_CREATE ('/DAV/rftest/orig/'	, '110100000RR', 'dav', 'administrators', 'dav', 'dav');
select DAV_COL_CREATE ('/DAV/rftest/orig/sub1/'	, '110100000RR', 'dav', 'administrators', 'dav', 'dav');
select DAV_COL_CREATE ('/DAV/rftest/orig/sub2/'	, '110100000RR', 'dav', 'administrators', 'dav', 'dav');
select DAV_COL_CREATE ('/DAV/rftest/filt/'	, '110100000RR', 'dav', 'administrators', 'dav', 'dav');

select DAV_RES_UPLOAD ('/DAV/rftest/orig/hit1.htm',
 '<html>This is /DAV/rftest/orig/hit1.htm</html>',
 'text/html', '110100000RR', 'dav', 'administrators', 'dav', 'dav' );

select DAV_RES_UPLOAD ('/DAV/rftest/orig/hit2.htm',
 '<html>This is /DAV/rftest/orig/hit2.htm</html>',
 'text/html', '110100000RR', 'dav', 'administrators', 'dav', 'dav' );

select DAV_RES_UPLOAD ('/DAV/rftest/orig/hit3.htm',
 '<html>This is /DAV/rftest/orig/hit2.htm</html>',
 'text/html', '110100000RR', 'dav', 'administrators', 'dav', 'dav' );

select DAV_RES_UPLOAD ('/DAV/rftest/orig/sub1/hit2.htm',
 '<html>This is /DAV/rftest/orig/sub1/hit2.htm</html>',
 'text/html', '110100000RR', 'dav', 'administrators', 'dav', 'dav' );

select DAV_RES_UPLOAD ('/DAV/rftest/orig/sub2/hit2.htm',
 '<html>This is /DAV/rftest/orig/sub2/hit2.htm</html>',
 'text/html', '110100000RR', 'dav', 'administrators', 'dav', 'dav' );

select DAV_RES_UPLOAD ('/DAV/rftest/orig/miss1.htm',
 '<html>This is /DAV/rftest/orig/miss1.htm</html>',
 'text/html', '110100000RR', 'dav', 'administrators', 'dav', 'dav' );

select DAV_RES_UPLOAD ('/DAV/rftest/orig/miss2.htm',
 '<html>This is /DAV/rftest/orig/miss1.htm</html>',
 'text/html', '110100000RR', 'dav', 'administrators', 'dav', 'dav' );

select DAV_RES_UPLOAD ('/DAV/rftest/orig/miss3.htm',
 '<html>This is /DAV/rftest/orig/miss3.htm</html>',
 'text/html', '110100000RR', 'dav', 'administrators', 'dav', 'dav' );

select DAV_PROP_SET ('/DAV/rftest/orig/hit1.htm', 'WikiV:ClusterName', 'Main', 'dav', 'dav');
select DAV_PROP_SET ('/DAV/rftest/orig/hit2.htm', 'WikiV:ClusterName', 'Main', 'dav', 'dav');
select DAV_PROP_SET ('/DAV/rftest/orig/hit3.htm', 'WikiV:ClusterName', 'Main', 'dav', 'dav');
select DAV_PROP_SET ('/DAV/rftest/orig/sub1/hit2.htm', 'WikiV:ClusterName', 'Main', 'dav', 'dav');
select DAV_PROP_SET ('/DAV/rftest/orig/sub2/hit2.htm', 'WikiV:ClusterName', 'Main', 'dav', 'dav');

select DAV_PROP_SET ('/DAV/rftest/orig/miss1.htm', 'WikiV:ClusterName', 'Wrong', 'dav', 'dav');
select DAV_PROP_SET ('/DAV/rftest/orig/miss2.htm', 'WikiV:WrongName', 'Main', 'dav', 'dav');
select DAV_PROP_SET ('/DAV/rftest/orig/miss3.htm', 'WikiV:ClusterName', 'Main', 'dav', 'dav');

select DAV_RDF_PROP_SET ('/DAV/rftest/orig/hit1.htm', 'http://local.virt/DAV-RDF',
xtree_doc('
<?xml version="1.0"?>
<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
         xmlns:dc="http://purl.org/dc/elements/1.1/"
         xmlns:ex="http://example.org/stuff/1.0/">

<rdf:Description rdf:about="http://www.w3.org/TR/rdf-syntax-grammar"
                 dc:title="RDF/XML Syntax Specification (Revised)"/>
</rdf:RDF>'),
'dav', 'dav' );

select DAV_RDF_PROP_SET ('/DAV/rftest/orig/hit2.htm', 'http://local.virt/DAV-RDF',
xtree_doc('
<?xml version="1.0"?>
<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
         xmlns:dc="http://purl.org/dc/elements/1.1/"
         xmlns:ex="http://example.org/stuff/1.0/">

<rdf:Description rdf:about="http://www.w3.org/TR/rdf-syntax-grammar"
                 dc:title="RDF/XML Syntax Specification (Revised)"/>
</rdf:RDF>'),
'dav', 'dav' );

select DAV_RDF_PROP_SET ('/DAV/rftest/orig/hit3.htm', 'http://local.virt/DAV-RDF',
xtree_doc('
<?xml version="1.0"?>
<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
         xmlns:dc="http://purl.org/dc/elements/1.1/"
         xmlns:ex="http://example.org/stuff/1.0/">

<rdf:Description rdf:about="http://www.w3.org/TR/rdf-syntax-grammar"
                 dc:title="RDF/XML Syntax Specification (Revised)"/>
</rdf:RDF>'),
'dav', 'dav' );

select DAV_RDF_PROP_SET ('/DAV/rftest/orig/miss3.htm', 'http://local.virt/DAV-RDF',
xtree_doc('
<?xml version="1.0"?>
<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
         xmlns:dc="http://purl.org/dc/elements/1.1/"
         xmlns:ex="http://example.org/stuff/1.0/">

<rdf:Description rdf:about="http://www.w3.org/TR/rdf-syntax-grammar"
                 dc:title="Wrong Title"/>
</rdf:RDF>'),
'dav', 'dav' );

select DAV_RDF_PROP_SET ('/DAV/rftest/orig/sub1/hit2.htm', 'http://local.virt/DAV-RDF',
xtree_doc('
<?xml version="1.0"?>
<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
         xmlns:dc="http://purl.org/dc/elements/1.1/"
         xmlns:ex="http://example.org/stuff/1.0/">

<rdf:Description rdf:about="http://www.w3.org/TR/rdf-syntax-grammar"
                 dc:title="RDF/XML Syntax Specification (Revised)"/>
</rdf:RDF>'),
'dav', 'dav' );

select DAV_RDF_PROP_SET ('/DAV/rftest/orig/sub2/hit2.htm', 'http://local.virt/DAV-RDF',
xtree_doc('
<?xml version="1.0"?>
<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
         xmlns:dc="http://purl.org/dc/elements/1.1/"
         xmlns:ex="http://example.org/stuff/1.0/">

<rdf:Description rdf:about="http://www.w3.org/TR/rdf-syntax-grammar"
                 dc:title="RDF/XML Syntax Specification (Revised)"/>
</rdf:RDF>'),
'dav', 'dav' );

select length (DAV_DIR_FILTER ('/DAV/rftest/orig/', 1,
  vector (
    vector ('PROP_VALUE', '=', 'Main',
      'WikiV:ClusterName' )
    ),
  'dav', 'dav' ) );

select length (DAV_DIR_FILTER ('/DAV/rftest/orig/', 1,
  vector (
    vector ('RDF_VALUE', '=', 'RDF/XML Syntax Specification (Revised)',
      'http://local.virt/DAV-RDF',
      'http://purl.org/dc/elements/1.1/title' )
    ),
  'dav', 'dav' ) );

select length (DAV_DIR_FILTER ('/DAV/rftest/orig/', 1,
  vector (
    vector ('PROP_VALUE', '=', 'Main',
      'WikiV:ClusterName' ),
    vector ('RDF_VALUE', '=', 'RDF/XML Syntax Specification (Revised)',
      'http://local.virt/DAV-RDF',
      'http://purl.org/dc/elements/1.1/title' )
    ),
  'dav', 'dav' ) );

select "ResFilter_CONFIGURE" (
  DAV_SEARCH_ID ('/DAV/rftest/filt/', 'C'),
  null,
  '/DAV/rftest/orig/',
  vector (
    vector ('PROP_VALUE', '=', 'Main',
      'WikiV:ClusterName' ),
    vector ('RDF_VALUE', '=', 'RDF/XML Syntax Specification (Revised)',
      'http://local.virt/DAV-RDF',
      'http://purl.org/dc/elements/1.1/title' )
    ) );

select "ResFilter_CONFIGURE" (
  DAV_SEARCH_ID ('/DAV/rftest/orig/sub1/', 'C'),
  null,
  '/DAV/rftest/orig/',
  vector (
    vector ('PROP_VALUE', '=', 'Main',
      'WikiV:ClusterName' ),
    vector ('RDF_VALUE', '=', 'RDF/XML Syntax Specification (Revised)',
      'http://local.virt/DAV-RDF',
      'http://purl.org/dc/elements/1.1/title' )
    ) );

select DAV_COL_CREATE ('/DAV/rfwmtest/', '110110110RR', 'dav', 'administrators', 'dav', 'dav');
select "ResFilter_CONFIGURE" (
  DAV_SEARCH_ID ('/DAV/rfwmtest/', 'C'),
  null,
  '/DAV/wmtest/',
  vector (
    vector ('RES_NAME', 'like', '%match%')
    ) );


select DAV_COL_CREATE ('/DAV/home/cf10000/cats/', '110100000RR', 'dav',
 'administrators', 'dav', 'dav');

select "CatFilter_CONFIGURE" (
  DAV_SEARCH_ID ('/DAV/home/cf10000/cats/', 'C'),
  null,
  '/DAV/home/cf10000/',
  vector () );

select DAV_COL_CREATE ('/DAV/home/cf10001/cats/', '110100000RR', 'dav',
 'administrators', 'dav', 'dav');

select "CatFilter_CONFIGURE" (
  DAV_SEARCH_ID ('/DAV/home/cf10001/cats/', 'C'),
  null,
  '/DAV/home/cf10001/',
  vector () );

select DAV_COL_CREATE ('/DAV/home/cf10002/cats/', '110100000RR', 'dav',
 'administrators', 'dav', 'dav');

select "CatFilter_CONFIGURE" (
  DAV_SEARCH_ID ('/DAV/home/cf10002/cats/', 'C'),
  null,
  '/DAV/home/cf10002/',
  vector () );

select DAV_COL_CREATE ('/DAV/home/cf10000/cats_slow/', '110100000RR', 'dav',
 'administrators', 'dav', 'dav');

select "CatFilter_CONFIGURE" (
  DAV_SEARCH_ID ('/DAV/home/cf10000/cats_slow/', 'C'),
  null,
  '/DAV/home/cf10000/',
  vector (vector ('RES_FULL_PATH', 'starts_with', '/DAV/home/')) );

select DAV_COL_CREATE ('/DAV/home/cf10001/cats_slow/', '110100000RR', 'dav',
 'administrators', 'dav', 'dav');

select "CatFilter_CONFIGURE" (
  DAV_SEARCH_ID ('/DAV/home/cf10001/cats_slow/', 'C'),
  null,
  '/DAV/home/cf10001/',
  vector (vector ('RES_FULL_PATH', 'starts_with', '/DAV/home/')) );

select DAV_COL_CREATE ('/DAV/home/cf10002/cats_slow/', '110100000RR', 'dav',
 'administrators', 'dav', 'dav');

select "CatFilter_CONFIGURE" (
  DAV_SEARCH_ID ('/DAV/home/cf10002/cats_slow/', 'C'),
  null,
  '/DAV/home/cf10002/',
  vector (vector ('RES_FULL_PATH', 'starts_with', '/DAV/home/')) );


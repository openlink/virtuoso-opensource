--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2016 OpenLink Software
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


drop procedure SIOC_REMOVE_CHARS;
create procedure SIOC_REMOVE_CHARS ( in _str any )
{
  declare s,e integer;

  s := strstr(_str,'<?vsp');
  e := strstr(_str,'<rdf:RDF');

  if (s is not null)
    _str := substring(_str,1,s) || subseq(_str,e);

  return _str;
}
;


drop function MKDOC_GET_VIRTDOC;
create function MKDOC_GET_VIRTDOC (in docsrc varchar, in _solid integer) returns any
{
  declare _path varchar;
  declare _cfg varchar;
  _path := docsrc;
  if (_solid <> 0)
    _cfg := 'BuildStandalone=ENABLE IdCache=ENABLE';
  else
    _cfg := '';
  return xtree_doc (file_to_string(_path), 0, concat ('file://', _path),
    'LATIN-1', 'x-any', _cfg );
}
;

drop procedure MKDOC_STALE_STYLESHEETS;
create procedure MKDOC_STALE_STYLESHEETS ()
{
  declare _path varchar;
  _path := 'docsrc/stylesheets/sections';
  xslt_stale (concat('file://', _path, '/function_list.xsl'));
  xslt_stale (concat('file://', _path, '/html_functions.xsl'));
  xslt_stale (concat('file://', _path, '/html_inline_refentry.xsl'));
  xslt_stale (concat('file://', _path, '/html_sect1_common.xsl'));
  xslt_stale (concat('file://', _path, '/html_sect1_funcindex.xsl'));
  xslt_stale (concat('file://', _path, '/html_sect1_mp.xsl'));
  xslt_stale (concat('file://', _path, '/html_sect1_tocs.xsl'));
  xslt_stale (concat('file://', _path, '/sect1_list.xsl'));
  xslt_stale (concat('file://', _path, '/rss_sect1_mp.xsl'));
  xslt_stale (concat('file://', _path, '/opml_sect1_mp.xsl'));
  xslt_stale (concat('file://', _path, '/../html_debug.xsl'));
  xslt_stale (concat('file://', _path, '/html_plain.xsl'));
  xslt_stale (concat('file://', _path, '/sioc_book.xsl'));
  xslt_stale (concat('file://', _path, '/sioc_sect1.xsl'));
--  xslt_stale (concat('file://', _path, '/sioc_chap.xsl'));
}
;

drop function MKDOC_COPY_OTHER_FILES;
create function MKDOC_COPY_OTHER_FILES (in _target varchar) returns varchar
{
  declare _path varchar;
  _path := 'docsrc/stylesheets/sections';
  string_to_file(concat(_target, '/openlink.css'), file_to_string(concat(_path, '/openlink.css')), -2);
  string_to_file(concat(_target, '/doc.css'), file_to_string(concat(_path, '/doc.css')), -2);
  string_to_file(concat(_target, '/favicon.ico'), file_to_string('docsrc/images/misc/favicon.ico'), -2);
  return sprintf ('css and ico files copied to target');
}
;

drop function MKDOC_SAVE_HTML;
create function MKDOC_SAVE_HTML (inout _name varchar, inout _content varchar, in _target varchar) returns varchar
{
  declare _path varchar;
  declare _ses any;
  declare _fname, _strg varchar;
  declare _colid integer;
  _path := _target;
  _ses := string_output();
  http_value (_content, null, _ses);
  _name := cast (_name as varchar);
  _fname := concat(_path, '/', _name, '.html');
  --_strg := string_output_string(_ses);
  string_to_file (_fname, _ses, -2);
  if (0 and exists (select 1 from WS.WS.SYS_DAV_COL where COL_NAME='docsrc' and COL_PARENT=1))
    {
      select COL_ID into _colid from WS.WS.SYS_DAV_COL where COL_NAME='docsrc' and COL_PARENT=1;
      insert replacing WS.WS.SYS_DAV_RES
	(RES_OWNER, RES_GROUP,  RES_COL, RES_TYPE, RES_CR_TIME, RES_MOD_TIME, RES_PERMS, RES_ID, RES_NAME, RES_FULL_PATH, RES_CONTENT)
	values
	(http_dav_uid (), http_dav_uid () + 1, _colid, http_mime_type('q.html'), now(), now(), '110100100', WS.WS.getid ('R'),
	 concat (_name, '.html'),
	 concat ('/DAV/docsrc/', _name, '.html'),
	 _ses);
    }
  return sprintf ('%d bytes were written to file ''%s''.', length (_ses), _fname);
}
;

drop function MKDOC_DO_ONE;
create function MKDOC_DO_ONE (
  inout _docfull any,
  in _target varchar,
  in _id varchar,
  in _xsl_name varchar,
  in _params any
 ) returns varchar
{
  declare _html any;
  _html := xslt (_xsl_name, _docfull, _params );
  return MKDOC_SAVE_HTML (_id, _html, _target);
}
;

drop procedure MKDOC_DO_GROUP;
create procedure MKDOC_DO_GROUP (
  inout _docfull any,
  in _target varchar,
  inout _ids any,
  in _xsl_name varchar,
  inout _constant_params any,
  in _iter_name varchar,
  in _report_title varchar
)
{
  declare _ctr, _len integer;
  _len := length (_ids);
  _ctr := 0;
  while (_ctr < _len)
    {
      declare _id varchar;
      declare _save_retval any;
      _id := aref (_ids, _ctr);
      _save_retval := MKDOC_DO_ONE (_docfull, _target, _id, _xsl_name, 
	vector_concat (_constant_params,
	  vector (_iter_name, _id) ) );
      result (
	sprintf ('[%d/%d] %s ''%s'': %s', _ctr+1, _len, _report_title, _id,
	_save_retval ));
      _ctr := _ctr+1;
    }
}
;

drop procedure MKDOC_DO_GROUP_FEED;
create procedure MKDOC_DO_GROUP_FEED (
  inout _docfull any,
  in _target varchar,
  inout _ids any,
  in _xsl_name varchar,
  inout _constant_params any,
  in _iter_name varchar,
  in _report_title varchar,
  in _ext varchar
)
{
  declare _ctr, _len integer;
  declare _html, _params, _ses, _strg, dict, ttl any;
  declare _name, _fname varchar;
  _len := length (_ids);
  _ctr := 0;
  while (_ctr < _len)
    {
      declare _id varchar;
      declare _save_retval any;
      _id := aref (_ids, _ctr);

      _params := vector_concat (_constant_params, vector (_iter_name, _id) ) ;
      _html := xslt (_xsl_name, _docfull, _params );

      if(_ext = '.rss')
      {
        MKDOC_DO_GROUP_FEED (_html, _target,
          vector(_id),
          'file://docsrc/doc/rss2rdf.xsl',
          _constant_params, 'chap', 'Sect1 RDF', '.rdf' );

        MKDOC_DO_GROUP_FEED (_html, _target,
          vector(_id),
          'file://docsrc/doc/rss2atom.xsl',
          _constant_params, 'chap', 'Sect1 ATOM', '.xml' );

        MKDOC_DO_GROUP_FEED (_html, _target,
          vector(_id),
          'file://docsrc/doc/rss2xbel.xsl',
          _constant_params, 'chap', 'Sect1 XBEL', '.xbl' );
      }

      _ses := string_output();
      http_value (_html, null, _ses);
      _name := cast (_id as varchar);
      _fname := concat(_target, '/', _name, _ext);
      _strg := string_output_string(_ses);
      if  (_ext = 'siocrdf.vsp') -- generated .ttl files
      {
        _strg := replace(_strg,'rdfs:rdfs=""','');
        _strg := replace(_strg,'dc:dc=""','');
        _strg := replace(_strg,'dcterms:dcterms=""','');
        _strg := replace(_strg,'foaf:foaf=""','');
        _strg := replace(_strg,'rdf:rdf=""','');
        _strg := replace(_strg,'content:content=""','');
        _strg := replace(_strg,'sioc:sioc=""','');
      };
      string_to_file (_fname, _strg, -2);


      if  (_ext = 'siocrdf.vsp') -- generated .ttl files
      {
          declare ss1 any;
          ss1 := SIOC_REMOVE_CHARS(_strg);
          dict := DB.DBA.RDF_RDFXML_TO_DICT (ss1,'','tmp/');
          ttl := string_output();
          DB.DBA.RDF_TRIPLES_TO_TTL (dict_list_keys (dict, 1), ttl);
          _fname := concat(_target, '/', _name, '.ttl');
          string_to_file (_fname, ttl, -2);

      };

      _save_retval := sprintf ('%d bytes were written to file ''%s''.', length (_strg), _fname);

      result (
	sprintf ('[%d/%d] %s ''%s'': %s', _ctr+1, _len, _report_title, _id,
	_save_retval ));
      _ctr := _ctr+1;
    }
}
;

drop procedure MKDOC_DO_ALL;
create procedure MKDOC_DO_ALL (in _docsrc varchar, in _target varchar, in _options any)
{
  declare "Progress" varchar;
  declare _doc, _docfull any;
  declare _spec_chapters, _chapters, _sect1s, _functions, _vspx_controls any;
  result_names ("Progress");

  _docfull := MKDOC_GET_VIRTDOC(_docsrc, 1);
  result ('Reading sources', 'done');

  MKDOC_DO_GROUP (_docfull, _target,
    vector ('index', 'preface', 'contents', 'functionidx'),
    'file://docsrc/stylesheets/sections/html_sect1_mp.xsl',
    _options, 'chap', 'Special chapter' );

  MKDOC_COPY_OTHER_FILES(_target);

  _chapters := xpath_eval ('/book/chapter/@id', _docfull, 0);
  result ('Building list of plain chapters', 'done');

  MKDOC_DO_GROUP (_docfull, _target,
    _chapters,
    'file://docsrc/stylesheets/sections/html_sect1_mp.xsl',
    _options, 'chap', 'Plain chapter' );

  _sect1s := xpath_eval ('/book/chapter/sect1/@id', _docfull, 0);
  result ('Building list of sect1s', 'done');

  MKDOC_DO_GROUP (_docfull, _target,
    _sect1s,
    'file://docsrc/stylesheets/sections/html_sect1_mp.xsl',
    _options, 'chap', 'Sect1' );

  _functions := xpath_eval ('/book/chapter[@id=''functions'']/refentry/@id', _docfull, 0);
  result ('Building list of function refentries', 'done');

  MKDOC_DO_GROUP (_docfull, _target,
    _functions,
    'file://docsrc/stylesheets/sections/html_sect1_mp.xsl',
    vector_concat(vector('chap', 'functions'), _options), 'function', 'Procedure' );

  _vspx_controls := xpath_eval ('/book/chapter/sect1[@id=''vspx'']//refentry/@id', _docfull, 0);
  result ('Building list of VSPX controls', 'done');

  MKDOC_DO_GROUP (_docfull, _target,
    _vspx_controls,
    'file://docsrc/stylesheets/sections/html_sect1_mp.xsl',
    vector_concat(vector('sect1', 'vspx'), _options), 'refentry', 'VSPX control' );
}
;

drop procedure MKDOC_DO_FEEDS;
create procedure MKDOC_DO_FEEDS (in _docsrc varchar, in _target varchar, in _options any)
{
  declare "Progress" varchar;
  declare _doc, _docfull any;
  declare _spec_chapters, _chapters, _books, _functions, _vspx_controls, _sect1s any;
  result_names ("Progress");

  _docfull := MKDOC_GET_VIRTDOC(_docsrc, 1);
  result ('Reading sources', 'done');

  _books := xpath_eval ('/book/@id', _docfull, 0);
  result ('Building list of books', 'done');

  MKDOC_DO_GROUP_FEED (_docfull, _target,
    _books,
    'file://docsrc/stylesheets/sections/opml_sect1_mp.xsl',
    vector_concat(vector('thedate', soap_print_box(now(), '', 1)), _options), 
    'chap', 'Book OPMLs', '.opml' );

  MKDOC_DO_GROUP_FEED (_docfull, _target,
    _books,
    'file://docsrc/stylesheets/sections/sioc_book.xsl',
    vector_concat(vector('thedate', soap_print_box(now(), '', 1)), _options), 
    'chap', 'Book SIOC', 'siocrdf.vsp' );

  _chapters := xpath_eval ('/book/chapter/@id', _docfull, 0);
  result ('Building list of plain chapters', 'done');

  MKDOC_DO_GROUP_FEED (_docfull, _target,
    _chapters,
    'file://docsrc/stylesheets/sections/rss_sect1_mp.xsl',
    vector_concat(vector('thedate', soap_print_box(now(), '', 1)), _options),
    'chap', 'Sect1 RSS', '.rss' );

  MKDOC_DO_GROUP_FEED (_docfull, _target,
    _chapters,
    'file://docsrc/stylesheets/sections/sioc_chap.xsl',
    vector_concat(vector('thedate', soap_print_box(now(), '', 1)), _options),
    'chap', 'Chap SIOC', 'siocrdf.vsp' );

  _sect1s := xpath_eval ('/book/chapter/sect1/@id', _docfull, 0);
  result ('Building list of sect1s', 'done');

  MKDOC_DO_GROUP_FEED (_docfull, _target,
    _sect1s,
    'file://docsrc/stylesheets/sections/sioc_sect1.xsl',
    vector_concat(vector('thedate', soap_print_box(now(), '', 1)), _options), 
    'chap', 'Sect1 SIOC', 'siocrdf.vsp' );

}
;

drop procedure MKDOC_DEBUG;
create procedure MKDOC_DEBUG (in _docsrc varchar, in _target varchar)
{
  declare "Progress" varchar;
  declare _doc, _docfull any;
  declare _spec_chapters, _chapters, _sect1s, _functions, _vspx_controls any;
  result_names ("Progress");

  _docfull := MKDOC_GET_VIRTDOC(_docsrc, 1);
  result ('Reading sources for creating debug HTML', 'done');

  -- activate debug output sheet
  MKDOC_DO_GROUP (_docfull, _target, vector ('debug'), 'file://docsrc/stylesheets/sections/../html_debug.xsl', vector(), 'debug', 'Debug Output' );
}
;

drop procedure MKDOC_PDF;
create procedure MKDOC_PDF (in _docsrc varchar, in _target varchar, in _options any)
{
  declare "Progress" varchar;
  declare _doc, _docfull any;
  declare _spec_chapters, _books, _sect1s, _functions, _vspx_controls any;
  result_names ("Progress");

  _docfull := MKDOC_GET_VIRTDOC(_docsrc, 1);
  result ('Reading sources for creating html for pdf', 'done');

  _books := xpath_eval ('/book/@id', _docfull, 0);

  -- Make HTML all in one primarily for PDF
  MKDOC_DO_GROUP (_docfull, _target, _books, 'file://docsrc/stylesheets/sections/html_plain.xsl', _options, 'html_pdf', 'Plain HTML for PDF' );
}
;

MKDOC_STALE_STYLESHEETS();

-- Those get called from mkdoc.sh now.
-- --MKDOC_DEBUG('docsrc/xmlsource/virtdocs.xml', 'docsrc/html_virt');
-- 
--   MKDOC_DO_ALL('docsrc/xmlsource/virtdocs.xml', 'docsrc/html_virt', vector());
-- 
-- --MKDOC_DO_ALL('docsrc/xmlsource/virtdocs.xml', 'docsrc/html_virt', vector('rss', 'yes'));  -- with rss feed links
-- 
-- --MKDOC_DO_FEEDS('docsrc/xmlsource/virtdocs.xml', 'docsrc/html_virt', vector('serveraddr', 'http://localhost:8890/doc/html'));
-- 
-- ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
-- ECHO BOTH ": Rendering HTML docs: STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
-- 
-- MKDOC_PDF('docsrc/xmlsource/virtdocs.xml', 'docsrc/pdf', vector());
-- 
-- ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
-- ECHO BOTH ": Rendering PDF HTML source: STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

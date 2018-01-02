--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2018 OpenLink Software
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

-- This SQL is for developing purposes. 
-- It assumes that you have eighter symbolic link (on unix like system) or 
-- junction (on windows with ntfs systems) in you vsp root to binsrc/tutorial cvs dir
-- also to use the path /tutorial_dev which is a virtuoso directory without dev.vsp handler
-- you must run `./make_vad.sh dev` which will copy all files in vad_files ... the same way
-- they will be copied during vad compilation
set COMMAND_TEXT_ON_ERROR=off;

create procedure TUTORIAL_ROOT_DIR ()
{
     return http_root()||'/';
}
;

create procedure TUTORIAL_XSL_DIR ()
{
     return 'file://';
}
;

create procedure TUTORIAL_VDIR_DIR ()
{
   return '/';
}
;


DB.DBA.VHOST_REMOVE(lpath=>'/tutorial',del_vsps => 1);
DB.DBA.VHOST_DEFINE(
    lpath    => '/tutorial',
    ppath    => '/tutorial/dev.vsp',
    is_dav   => 0,
    vsp_user => 'dba',
    is_brws  => 0,
    opts     => vector('noinherit', 1)
)
;

DB.DBA.VHOST_REMOVE(lpath=>'/tutorial_dev',del_vsps => 1);
DB.DBA.VHOST_DEFINE(
    lpath    => '/tutorial_dev',
    ppath    => '/tutorial/vad_files/vsp/tutorial/',
    is_dav   => 0,
    vsp_user => 'dba',
    is_brws  => 1,
    def_page => 'index.vsp'
    --opts     => vector('noinherit', 1)
)
;

create procedure TUT_get_xml(in path varchar){
  declare _TUT_XML any;
  declare _ex_id, _ex_fspath, ex, _ex_xmlfile, _ex_optfile, _subsec_fspath varchar;
  declare xp_last_example, _subsec_options,_ex_optxml any;

  _TUT_XML := xml_tree_doc(xml_tree(file_to_string(http_root()|| path||'/'||'tutorial.xml')));
  xp_last_example := null;
  --string_to_file(http_root() ||path|| '/url_list.txt','',-2);
  foreach (any xp_example in xpath_eval('//example',_TUT_XML,0))do
  {
  	_ex_fspath := cast(xpath_eval('@fspath',xp_example) as varchar);
  	-- Exeption for bpeldemo
  	if (not(isnull(strstr(_ex_fspath,'bpeldemo/'))))
	  	_ex_id := replace(cast(xpath_eval('@id',xp_example) as varchar),'-','_');
  	else if (not(isnull(strstr(_ex_fspath,'hw-simulator'))))
	  	_ex_id := lower(cast(xpath_eval('@id',xp_example) as varchar));
  	else
	  	_ex_id := replace(lower(cast(xpath_eval('@id',xp_example) as varchar)),'-','_');

	  ex := '';
	  _ex_optxml := null;
	  _ex_optfile := path || '/' || _ex_fspath || '/options.xml';
    if (file_stat(http_root()||_ex_optfile))	  
      _ex_optxml := xml_tree_doc(xml_tree(file_to_string(http_root()|| _ex_optfile)));
	
  	if(isnull(xpath_eval('@wwwpath',xp_example)))
  	{
	  if (_ex_optxml is not null and lower(xpath_eval('string(/init/@is_vspx)',_ex_optxml)) = 'yes')
	       		ex := 'x';
  	  		XMLAddAttribute (xp_example,2,'wwwpath',concat(_ex_fspath ,'/', _ex_id , '.vsp',ex));
  	  	};

  	if(not(isnull(xp_last_example)))
  	{
  	  XMLAddAttribute (xp_example,2,'previd',xpath_eval('@id',xp_last_example));
  	  XMLAddAttribute (xp_last_example,2,'nextid',xpath_eval('@id',xp_example));
  	};
  	
		_ex_xmlfile := path || '/' || _ex_fspath || '/' || _ex_id || '.xml';
		if (file_stat(http_root()||_ex_xmlfile) = 0)
			signal('TUTNF','File not found:'||http_root()||_ex_xmlfile);
		XMLAddAttribute(xp_example,2,'date',date_rfc1123(stringdate (file_stat (http_root()||_ex_xmlfile))));
	  XMLAppendChildren(xp_example,xml_tree_doc(xml_tree(file_to_string(http_root()|| _ex_xmlfile))));
	  
	  _ex_optfile := path || '/' || _ex_fspath || '/options.xml';
    if (_ex_optxml)	  
      XMLAppendChildren(xp_example,_ex_optxml);
		xp_last_example := xp_example;
		
		--string_to_file(http_root() ||path|| '/url_list.txt',cast(xpath_eval('@wwwpath',xp_example) as varchar)|| '\n',-1);		
  };

  foreach (any xp_subsec in xpath_eval('//subsection',_TUT_XML,0))do
  {
  	_subsec_fspath := cast(xpath_eval('@fspath',xp_subsec) as varchar);
  	
  	--_subsec_xmlfile := _TUT_ROOT || '/' || _ex_fspath || '/' || replace(lower(_ex_id),'-','_') || '.xml';
  	if(not(isnull(xpath_eval('@ref',xp_subsec))))
  	  XMLAddAttribute  (xp_subsec,2,'ref',xpath_eval('@ref',xp_subsec));
  	if(isnull(xpath_eval('@wwwpath',xp_subsec)))
  	  XMLAddAttribute  (xp_subsec,2,'wwwpath',xpath_eval('@fspath',xp_subsec));
		_subsec_options :=  xml_tree_doc(xml_tree(file_to_string(http_root()||path || '/' || cast(xpath_eval('@fspath',xp_subsec) as varchar) || '/' || 'index.xml')));
		foreach (any _subsec_option in xpath_eval('/section/*',_subsec_options,0))do
		{
		  XMLAppendChildren(xp_subsec,_subsec_option);
		};

  };
  
  --string_to_file(http_root() ||path|| '/full_tutorial_xml.xml',serialize_to_UTF8_xml(_TUT_XML),-2);
  
  return _TUT_XML;
	
};

create procedure TUT_generate_files(
	in path varchar,
	in _outmode varchar := 'sql'
){
  declare _TUT_XML,_stream, paths any;
  declare _file,xml_output varchar;
  declare _ins_sql varchar;
  declare xsl_mountpoint, _xsl_params any;
  
  _TUT_XML := TUT_get_xml(path);

  _stream := string_output();
  
  xml_output := '';
	
	if (_outmode = 'web'){
		http_rewrite();
		http('<pre>');
		http('Preparing for generating files.\n');
		http_flush(1);
	} else {
	  result_names('status');	
	  result('Preparing for generating files.');
	};
	paths := vector('/','/search.vsp','/rss.vsp','/opml.vsp','/ocs.vsp','/sioc.vsp');
  foreach (any tut_path in xpath_eval('//@wwwpath',_TUT_XML,0))do
  {
	  if (length(tut_path) > 5 and (
	      subseq(tut_path,length(tut_path) - 4,length(tut_path)) = '.vsp'  or
	  		subseq(tut_path,length(tut_path) - 5,length(tut_path)) = '.vspx')
	  		)
	  	paths := vector_concat(paths,vector('/'||cast(tut_path as varchar)));
	  else {
	  	paths := vector_concat(paths,vector('/'||cast(tut_path as varchar)||'/'));
	  	paths := vector_concat(paths,vector('/'||cast(tut_path as varchar)||'/rss.vsp'));
	  }
  };

  string_to_file(http_root() ||path|| '/fill_search.sql','',-2);
  foreach (any tut_example in xpath_eval('//example',_TUT_XML,0))do
  {
	  _ins_sql := 'INSERT SOFT DB.DBA.TUT_SEARCH (TS_PATH,TS_NAME,TS_TITLE) VALUES(''';
	  _ins_sql := _ins_sql || cast(xpath_eval('@wwwpath',tut_example) as varchar);
	  _ins_sql := _ins_sql || ''',''';
	  _ins_sql := _ins_sql || cast(xpath_eval('@id',tut_example) as varchar);
	  _ins_sql := _ins_sql || ''',''';
	  _ins_sql := _ins_sql || replace(cast(xpath_eval('refentry/refnamediv/refpurpose',tut_example) as varchar),'''','''''');
	  _ins_sql := _ins_sql || ''');\n';
	  
	  string_to_file(http_root() ||path|| '/fill_search.sql',_ins_sql,-1);
  };
  
	if (_outmode = 'web'){
		http('Start generating files.\n');
		http_flush(1);
	} else {
		result('Start generating files.');
	};

  foreach (varchar gen_path in paths)do
  {
    if (gen_path like '%/idp_s_1.vsp')
      goto _skip;
    
	  _file := 'index.vsp';
	  if (length(gen_path) > 5 and (
	      subseq(gen_path,length(gen_path) - 4,length(gen_path)) = '.vsp'  or
	  		subseq(gen_path,length(gen_path) - 5,length(gen_path)) = '.vspx')
	  		)
	  		_file := '';

	  xsl_mountpoint := regexp_replace(ltrim(gen_path,'/'),'[^/]*/','../',1,null);
	  if (length(xsl_mountpoint) > 5 and (
	      subseq(xsl_mountpoint,length(xsl_mountpoint) - 4,length(xsl_mountpoint)) = '.vsp'  or
	  		subseq(xsl_mountpoint,length(xsl_mountpoint) - 5,length(xsl_mountpoint)) = '.vspx')
	  		)
	  	xsl_mountpoint := regexp_replace(xsl_mountpoint,'[^/]+\$','');
	  xsl_mountpoint := trim(xsl_mountpoint,'/');
	  if (xsl_mountpoint = '')
	    xsl_mountpoint := '.';
	  _xsl_params := vector('mount_point',xsl_mountpoint);
	  if (trim(gen_path,'/') <> '')
	    _xsl_params := vector_concat(_xsl_params,vector('path',ltrim(gen_path,'/')));
	    
	  _xsl_params := vector_concat(_xsl_params,vector('now_rfc1123',date_rfc1123(curutcdatetime())));

	  _stream := string_output();
	  http_rewrite(_stream);
  	if (gen_path like '%/rss.vsp')
  		xml_output := '_rss_output';
  	else if (gen_path = '/opml.vsp')
  		xml_output := '_opml_output';
  	else if (gen_path = '/ocs.vsp')
  		xml_output := '_ocs_output';
  	else if (gen_path = '/sioc.vsp')
  		xml_output := '_sioc_output';
    else
      xml_output := '';
	  
	  http_value(xslt('file://'||path|| '/page'||xml_output||'.xsl',_TUT_XML,_xsl_params),null,_stream);
	  _stream := string_output_string(_stream);
	  if (xml_output <> '') {
	    _stream := replace(_stream,'dc:dc=""','');
            _stream := replace(_stream,'dcterms:dcterms=""','');
            _stream := replace(_stream,'foaf:foaf=""','');
	    _stream := replace(_stream,'ocs:ocs=""','');
	    _stream := replace(_stream,'rdf:rdf=""','');
	    _stream := replace(_stream,'content:content=""','');
	    _stream := replace(_stream,'sioc:sioc=""','');
	  };
	  string_to_file(http_root() ||path|| gen_path || _file,_stream,-2);
	  
		if (_outmode = 'web'){
		  http('Wrote ' || http_root() ||path|| gen_path || _file || '\n');
	  	http_flush (1);
	  } else {
	  	result('Wrote ' || http_root() ||path|| gen_path || _file);
	  }
	_skip:;  
  }
	if (_outmode = 'web'){
		http('Finished.\n');
		http_flush(1);
	} else {
		result('Finished.');
	};
};


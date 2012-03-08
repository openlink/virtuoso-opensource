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
--  
--  create procedure load_html_in_dav_portion (in srcdir varchar, in trgdir varchar)
--  {
--     declare arr any;
--     declare cnt varchar;
--     declare i, l integer;
--     arr := sys_dirlist (srcdir, 1);
--     DB.DBA.DAV_COL_CREATE (concat('/DAV/', trgdir), '110100100R', 'dav','dav', 'dav', 'dav');
--     l := length (arr);
--     i := 0;
--     while (i<l)
--       {
--         cnt := file_to_string (concat (srcdir, arr[i]));
--         DB.DBA.DAV_RES_UPLOAD (concat ('/DAV/', trgdir, arr[i]), cnt, '', '110100100R',
--         'dav','dav', 'dav', 'dav');
--         i := i + 1;
--       }
--  }
--
--  create procedure load_html_in_dav ()
--  {
--     DB.DBA.DAV_COL_CREATE ('/DAV/doc/', '110100100R', 'dav','dav', 'dav', 'dav');
--
--     load_html_in_dav_portion ('./docsrc/html_virt/', 'doc/html/');
--     load_html_in_dav_portion ('./docsrc/images/', 'doc/images/');
--     load_html_in_dav_portion ('./docsrc/images/inst/', 'doc/images/inst/');
--     load_html_in_dav_portion ('./docsrc/images/rth/', 'doc/images/rth/');
--     load_html_in_dav_portion ('./docsrc/images/mac/', 'doc/images/mac/');
--     load_html_in_dav_portion ('./docsrc/images/misc/', 'doc/images/misc/');
--     load_html_in_dav_portion ('./docsrc/images/tree/', 'doc/images/tree/');
--     load_html_in_dav_portion ('./docsrc/images/ui/', 'doc/images/ui/');
--
--     DB.DBA.DAV_RES_UPLOAD ('/DAV/doc/html/doc.css', file_to_string('./docsrc/stylesheets/sections/doc.css'),
--       '', '110100100R', 'dav','dav', 'dav', 'dav');
--
--     DB.DBA.DAV_RES_UPLOAD ('/DAV/doc/html/openlink.css', file_to_string('./docsrc/stylesheets/sections/openlink.css'),
--       '', '110100100R', 'dav','dav', 'dav', 'dav');
--  };
--
--  load_html_in_dav ();
--
--  ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
--  ECHO BOTH ": HTML docs uploaded in WebDAV : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create table document_search (d_id integer identity primary key, d_txt long varchar, d_res_id integer, d_anch varchar);

create text index on document_search (d_txt) language 'x-ViDoc';

create procedure fill_search_table (in _path varchar)
{
   declare FULL_PATH varchar;
   result_names (FULL_PATH);
   delete from document_search;
   DB.DBA.vt_batch_update ('document_search', 'ON', 100);
   for select res_name, res_id, res_full_path, res_content from ws.ws.sys_dav_res
     where res_full_path like concat(_path, '%.html') -- This is for testing: and res_full_path like '%collection%'
     do
       {
--	 dbg_obj_print (res_full_path);
	 if (res_name <> 'virtdocs_xtnw.html' and
	     res_name <> 'virtdocs_xt.html' and
	     res_name <> 'virtdocs.html' and
	     res_name <> 'virtdocs_no_toc_xt.html'
	     )
	 make_search_entry (res_id, res_content);
         result (res_full_path);
       }
   DB.DBA.vt_batch_update ('document_search', 'OFF', 100);
};


create procedure make_search_entry (in res_id integer, in res_content varchar)
{
  declare dump_start, dump_end, search_start integer;
  declare l, i integer;
  declare offs, offs1, offs2, eqs integer;
  declare dump_anchor, tmp, anch, tmp1, dump_entry varchar;

  res_content := blob_to_string (res_content);
  offs := strstr (res_content, '<div id="text">');
  if (offs is not null)
    res_content := subseq (res_content, offs);
  offs := strstr (res_content, '<div id="footer">');
  if (offs is not null)
    res_content := subseq (res_content, 0, offs);
  l := length (res_content);
  dump_start := 0; search_start := -1; i := 0;
  dump_end := -1;
  dump_anchor := null;
  while (dump_start < l)
    {
--      dbg_obj_princ (dump_start, ' / ', l);
      if (search_start < l)
        search_start := search_start + 1;
      tmp := subseq (res_content, search_start, l);
      offs := __min (coalesce (strstr (tmp, '<A '), l - search_start), coalesce (strstr (tmp, '<a '), l - search_start));
--      dbg_obj_princ ('offs=', offs);
      tmp := subseq (tmp, 0, offs);
      anch := regexp_match ('[Aa][ \t].*[Nn][Aa][Mm][Ee]="[^"]+', tmp);
--      dbg_obj_princ ('anch=', anch);
      if (anch is not null)
	{
	  eqs := strrchr (anch, '=');
	  anch := trim (subseq (anch, eqs+1, length (anch)), '"');
        }
--	  dbg_obj_print (anch);
      if ((anch is not null) or ((search_start + offs) = l))
        {
          dump_end := search_start;
          dump_entry := subseq (res_content, dump_start, dump_end);
	  insert into document_search (d_txt, d_res_id, d_anch) values (dump_entry, res_id, dump_anchor);
          dump_start := dump_end;
          dump_anchor := anch;
	}
      search_start := search_start + offs;
      i := i + 1;
      if (0 = mod(i, 1000))
        commit work;
    }
}
;

create procedure SIOC_REMOVE_CHARS_MAIN (in path varchar, in graph varchar)
{
  declare data varchar;
  declare s,e integer;

  if (graph is null)
    return;

  data := xml_uri_get(path,'');

  if (data is null)
    return;

  data := blob_to_string(data);

  s := strstr(data,'<?vsp');
  e := strstr(data,'<rdf:RDF');

  if (s is not null)
    data := substring(data,1,s) || subseq(data,e);

  DB.DBA.RDF_LOAD_RDFXML(data,graph,graph);

}
;




fill_search_table('/DAV/VAD/doc/html/');
--fill_search_table('/DAV/doc/html/');
--ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
--ECHO BOTH ": HTML docs are indexed for search : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--VHOST_DEFINE (lpath=>'/doc/html', ppath=>'/DAV/doc/html/', is_dav=>1, def_page=>'index.html');
--VHOST_DEFINE (lpath=>'/doc/images', ppath=>'/DAV/doc/images/', is_dav=>1);

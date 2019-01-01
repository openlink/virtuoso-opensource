--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2019 OpenLink Software
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
--procedure for computeroutput transform
drop procedure DB.DBA.WIKI_COMPINOUT;
create procedure DB.DBA.WIKI_COMPINOUT (in Content varchar)
{
  declare sFirst, sLast varchar;
  declare iLen integer;

  iLen := length(Content);
  if (iLen < 1 )
    return '';
  else if (iLen < 2 )
    sLast := '';
  else
    sLast := substring(Content,iLen,1);

  sFirst := substring(Content,1,1);

  if ( ( regexp_like(sFirst,'[[:alpha:]]') or regexp_like(sFirst,'[[:digit:]]')) and ( regexp_like(sLast,'[[:alpha:]]') or regexp_like(sLast,'[[:digit:]]') or sLast = '' ))
    Content := replace(concat('=',Content,'='), '\r\n', '');
  else
    Content := concat('<strong>',Content,'</strong>');

  return Content;
};

grant execute on DB.DBA.WIKI_COMPINOUT to public
;

xpf_extension ('http://www.openlinksw.com/virtuoso/xslt:WIKI_COMPINOUT',
	        fix_identifier_case ('DB.DBA.WIKI_COMPINOUT'))
;

-- procedure for WikiName compose from a given @id
drop procedure DB.DBA.WikiNameFromId;
create procedure DB.DBA.WikiNameFromId (in Id varchar)
{
   declare aArr,aTmp, aNewArr any;
   declare i integer;

   aNewArr := '';
   i := 0;
   aArr := split_and_decode(Id, 0, '\0\0_');


   while (i <length(aArr))
   {
     aTmp := initcap(aArr[i]);
     aNewArr := concat(aNewArr, aTmp);
     i:=i+1;
   };

   if (length(aArr) = 0)
       aNewArr := initcap(Id);

   aNewArr := replace(aNewArr,'.','');
   return aNewArr;
}
;

grant execute on DB.DBA.WikiNameFromId to public
;

xpf_extension ('http://www.openlinksw.com/virtuoso/xslt:WikiNameFromId',
	        fix_identifier_case ('DB.DBA.WikiNameFromId'))
;

--procedure for creating *.txt file
drop procedure DB.DBA.TextToWiki;
create procedure DB.DBA.TextToWiki (in TopicName varchar, in TopicContent any, in AppInfo any)
{
   declare _path varchar;
   declare _content any;
   declare _name varchar;
   declare _ses any;
   declare _fname, _strg varchar;

   _path :=  AppInfo[1];
   _content := cast(TopicContent as varchar);
   --_ses := string_output();
   --http_value (_content, null, _ses);
   _name := cast (TopicName as varchar);
   _fname := concat(_path, '/', _name, '.txt');
   --_strg := string_output_string(_ses);
   --string_to_file (_fname, _strg, -2);
   string_to_file (_fname, _content, -2);
   return;
}
;

grant execute on DB.DBA.TextToWiki to public
;

xpf_extension ('http://www.openlinksw.com/virtuoso/xslt:TextToWiki',
	        fix_identifier_case ('DB.DBA.TextToWiki'))
;



drop procedure DB.DBA.WikiTextUri;
create procedure DB.DBA.WikiTextUri (in TopicName varchar, in TargetClusterName any, in AppInfo any)
{
   return '';
}
;

grant execute on DB.DBA.WikiTextUri to public
;

xpf_extension ('http://www.openlinksw.com/virtuoso/xslt:WikiTextUri',
	        fix_identifier_case ('DB.DBA.WikiTextUri'))
;

drop procedure DB.DBA.WikiRenderUri;
create procedure DB.DBA.WikiRenderUri (in TopicName varchar, in TargetClusterName any, in AppInfo any)
{
   return '';
}
;

grant execute on DB.DBA.WikiRenderUri to public
;

xpf_extension ('http://www.openlinksw.com/virtuoso/xslt:WikiRenderUri',
	        fix_identifier_case ('DB.DBA.WikiRenderUri'))
;


drop procedure DB.DBA.MKWIKI_GET_VIRTDOC;
create procedure DB.DBA.MKWIKI_GET_VIRTDOC (in docsrc varchar, in _solid integer) returns any
{
  declare _path varchar;
  declare _cfg varchar;
  _path := docsrc;
  if (_solid <> 0)
    _cfg := 'BuildStandalone=ENABLE IdCache=ENABLE';
  else
    _cfg := '';

  -- dbg_obj_print(xtree_doc (file_to_string(_path), 0, concat ('file://', _path), 'LATIN-1', 'x-any', _cfg ));
  return xtree_doc (file_to_string(_path), 0, concat ('file://', _path),
    'LATIN-1', 'x-any', _cfg );
}
;

drop  procedure DB.DBA.MWIKI_ALL;
create procedure DB.DBA.MWIKI_ALL (in _docsrc varchar, in _target varchar, in _options any)
{
  declare _xt, _docfull, _xc any;

  _docfull := DB.DBA.MKWIKI_GET_VIRTDOC(_docsrc, 1);
  _xc := xslt ('file://wiki_contents.xsl', _docfull);
  DB.DBA.TextToWiki('WebHome',_xc,vector('path',_target));
  _xt := xslt ('file://wiki.xsl', _docfull, vector ('TargetClusterName', '','AppInfo',vector('path',_target),'Debug',''));
};

DB.DBA.MWIKI_ALL('docsrc/xmlsource/virtdocs.xml', 'docsrc/html_wiki', vector());

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

create function WV.WIKI.COMPILEWIKIWORDLINK (
  inout _default_cluster varchar, inout _href varchar) returns varchar
{
  declare _topic WV.WIKI.TOPICINFO;
  _topic := WV.WIKI.TOPICINFO ();
  _topic.ti_raw_name := _href;
  _topic.ti_default_cluster := _default_cluster;
  _topic.ti_parse_raw_name ();
  
  return concat (_topic.ti_cluster_name, '.', _topic.ti_local_name);
}
;

grant execute on WV.WIKI.NORMALIZEWIKIWORDLINK to public
;

xpf_extension ('http://www.openlinksw.com/Virtuoso/WikiV/:NormalizeWikiWordLink', 'WV.WIKI.NORMALIZEWIKIWORDLINK')
;

create function WV.WIKI.CONVERTTITLETOWIKIWORD (in _title varchar)
{
  return xpath_eval ('//a/@href', xtree_doc ("WikiV lexer" (concat ('[[[', _title, ']]]'), '', '', '', null), 2));
}
;


create procedure WV.WIKI.HEXDIGIT (in i integer)
{
  if ( i >= 0 and i < 10)
    return i + ascii ('0');
  if ( i > 9 and  i < 16 )
    return i + ascii ('A') - 10;
  return ascii ('0');
}
;

create procedure WV.WIKI.STRTOURI (in str varchar)
{
  declare tmp varchar;
  declare inx, inx1, len integer;
  declare escapes varchar;
  declare c char;
  escapes := ';?:@&=+ "#%<>';
  len := length (str);
  if (len = 0)
    return '';
  inx := 0;
  inx1 := 0;
  tmp := repeat (' ', len * 3);

  while (inx < len)
    {
      c := chr (aref (str, inx));
      if (not isnull (strchr (escapes, c)))
        {
	  aset (tmp, inx1, ascii('%'));
	  aset (tmp, inx1 + 1, HexDigit (ascii(c) / 16));
	  aset (tmp, inx1 + 2, HexDigit (mod (ascii(c), 16)));
          inx1 := inx1 + 2;
	}
       else
        aset (tmp, inx1, ascii(c));
      inx1 := inx1 + 1;
      inx := inx + 1;
    }
  return trim(tmp);
}
;

create procedure WV.WIKI.STRSQLAPOS (in str varchar)
{
  declare tmp varchar;
  declare inx, inx1, len integer;
  declare c char;
  declare cascii integer;
  len := length (str);
  -- This if is not only for empty string, but for NULL input, too.
  if (len = 0)
    return '''''';
  tmp := space(len * 4 + 2);

  aset(tmp, 0, ascii(''''));	-- Start output from apos

  inx := 0;			-- Start input from leftmost position
  inx1 := 1;			-- Continue output after starting apos
  while (inx < len)
    {
      c := chr (aref (str, inx));
      cascii := ascii(c);
      if (cascii < 32)
        {
	  aset (tmp, inx1, ascii('\\'));
	  aset (tmp, inx1 + 1, ascii('0'));
	  aset (tmp, inx1 + 2, WS.WS.HEX_DIGIT (cascii / 8));
	  aset (tmp, inx1 + 3, WS.WS.HEX_DIGIT (mod (cascii, 8)));
          inx1 := inx1 + 4;
	}
      else
        {
	  if ((c = '''') or (c = '\\'))
	    {
              aset (tmp, inx1, cascii);
              inx1 := inx1 + 1;
	    }
          aset (tmp, inx1, cascii);
          inx1 := inx1 + 1;
	}
      inx := inx + 1;
    }

  aset(tmp, inx1, ascii(''''));	-- Finish output by apos

  return trim(tmp);
}
;

create procedure WV.WIKI.SET_WIKI_MAIN()
{
  if (isstring(registry_get('wiki default uri')))
     return;
  registry_set ('wiki default uri', 'done');
  DB.DBA.VHOST_REMOVE(lpath=>'/wiki');
  DB.DBA.VHOST_REMOVE(lpath=>'/wiki/main');
  DB.DBA.VHOST_REMOVE(lpath=>'/wiki/Main');
  DB.DBA.VHOST_REMOVE(lpath=>'/wiki/Doc');
  DB.DBA.VHOST_REMOVE(lpath=>'/wikix');
  DB.DBA.VHOST_REMOVE(lpath=>'/wiki/wikix');
  DB.DBA.VHOST_REMOVE(lpath=>'/wikiview');
  DB.DBA.VHOST_REMOVE(lpath=>'/DAV/wikiview');
  declare _id int;
  _id := (select WAI_ID from DB.DBA.WA_INSTANCE where WAI_TYPE_NAME = 'oWiki' and WAI_NAME = 'Main');
  if (_id is not null) 
     DB.DBA.WA_SET_APP_URL (_id, '/wiki/');
}
;

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
DB.DBA.RDF_ASSERT ('equ (ODP.ODP.CODE_VERSION(), ''0.1.001011A'')');

create procedure ODP.ODP.VSP_HEADER_LINK (
  inout path any, inout params any, inout lines any,
  in _page varchar, in _title varchar )
{
  if (aref(path,length(path)-1) = _page)
    {
      http ('<B>');
      http (_title);
      http ('</B>');
      return;
    }
  http ('<A HREF="');
  http (_page);
  http ('">');
  http (_title);
  http ('</A>');
}

create procedure ODP.ODP.VSP_HEADER (
  inout path any, inout params any, inout lines any,
  in _title varchar )
{
  http ('<HTML><HEAD><TITLE>VIRTUOSO ODP | ');
  http (_title);
  http ('</TITLE></HEAD>');
  http ('<BODY MARGINLEFT=0 MARGINTOP=0 LEFTMARGIN=0 TOPMARGIN=0>');
  http ('<TABLE BORDER=0 BGCOLOR="#99CCFF" WIDTH="100%"><TR><TD>');
  ODP.ODP.VSP_HEADER_LINK (path, params, lines, 'main.vsp', 'Home');
  http (' | ');
  ODP.ODP.VSP_HEADER_LINK (path, params, lines, 'status.vsp', 'Status');
  http ('</TD></TR></TABLE>');
}
;

create procedure ODP.ODP.VSP_FOOTER (
  inout path any, inout params any, inout lines any)
{
  http ('<!-- footer -->
<TABLE BORDER=0 BGCOLOR="#99CCFF" WIDTH="100%"><TR>
<TD WIDTH="0">&nbsp;<IMG SRC="virtuoso_odp_logo.gif" BORDER=0>&nbsp;</TD>
<TD WIDTH="100%"><FONT SIZE=-1>This collection of 2000000+ links is just a toy for <A HREF="http://www.openlinksw.com">Virtuoso</A> database.</FONT></TD>
</TR></TABLE>
</BODY>
</HTML>');
}
;

create procedure ODP.ODP.VSP_ERROR (
  inout path any, inout params any, inout lines any,
  in _message varchar )
{
  declare idx integer;
  http_rewrite(0);
  ODP.ODP.VSP_HEADER (path,params,lines, 'Error');
  http_value (_message,'H3');
  http ('<P>Path to page: { ');
  idx := 0;
  while (idx < length(path))
    {
      http('[');
      http_value(aref(path,idx),'CODE');
      http(']');
      idx := idx + 1;
      if (idx < length(path))
        http(' , ');
    }
  http (' }</P><P>Parameters: { ');
  idx := 0;
  while (idx < length(params))
    {
      http('[');
      http_value(aref(params,idx),'CODE');
      idx := idx + 1;
      if (idx < length(params))
        http('] = [');
      else
        http('] = ??? }');
      http_value(aref(params,idx),'CODE');
      idx := idx + 1;
      if (idx < length(params))
        http('] , ');
      else
        http(']');
    }
  http (' }</P><P>Lines of header:<BR>');
  idx := 0;
  while (idx < length(lines))
    {
      http_value(aref(lines,idx),'CODE');
      http('<BR>');
      idx := idx + 1;
    }
  http ('</P>');
  ODP.ODP.VSP_FOOTER (path,params,lines);
  return _message;
}

create procedure ODP.ODP.VSP_TOPIC_PATH_HREFS (
  inout path any, inout params any, inout lines any,
  in _path varchar )
{
  declare _slash_pos integer;
  declare _begin_path varchar;
  declare _item varchar;
  _slash_pos := strchr (_path, 47);
  if (_slash_pos = 3 and "LEFT" (_path, 3) = 'Top')
    {
      http ('<A HREF="main.vsp">Top</A>&nbsp;/ </NOBR>');
      _path := subseq ( _path, _slash_pos+1);
      _begin_path := 'Top';
    }
  else
    _begin_path := '';
  while (1)
    {
      _slash_pos := strchr (_path, 47);
      if (_slash_pos is null)
        {
          http ('<NOBR><B>');
	  http (replace (cast(_path as varchar), '_', ' '), 0);
          http ('</B></NOBR>');
	  return;
	}
      _item := "LEFT" (_path, _slash_pos);
      if  (_begin_path = '')
        _begin_path := _item;
      else
        _begin_path := concat (_begin_path, '/', _item);
      http ('<NOBR><A HREF="topic.vsp?r_id=');
      http_url (_begin_path, 0);
      http ('">');
      http (replace (cast (_item as varchar), '_', ' '), 0);
      http ('</A>&nbsp;/</NOBR> ');
      _path := subseq ( _path, _slash_pos+1);
    }
}
;

create procedure ODP.ODP.VSP_TOPIC_HREFS (
  inout path any, inout params any, inout lines any,
  in _path varchar )
{
  declare _slash_pos integer;
  declare _begin_path varchar;
  declare _item varchar;
  _slash_pos := strchr (_path, 47);
  if (_slash_pos = 3 and "LEFT" (_path, 3) = 'Top')
    {
      http ('<A HREF="main.vsp">Top</A>&nbsp;/ </NOBR>');
      _path := subseq ( _path, _slash_pos+1);
      _begin_path := 'Top';
    }
  else
    _begin_path := '';
  while (1)
    {
      _slash_pos := strchr (_path, 47);
      if (_slash_pos is null)
        {
          if  (_begin_path = '')
            _begin_path := _path;
          else
            _begin_path := concat (_begin_path, '/', _path);
          http ('<NOBR><A HREF="topic.vsp?r_id=');
          http_url (_begin_path, 0);
          http ('">');
          http (replace (cast (_path as varchar), '_', ' '), 0);
          http ('</A></NOBR>');
	  return;
	}
      _item := "LEFT" (_path, _slash_pos);
      if  (_begin_path = '')
        _begin_path := _item;
      else
        _begin_path := concat (_begin_path, '/', _item);
      http ('<NOBR><A HREF="topic.vsp?r_id=');
      http_url (_begin_path, 0);
      http ('">');
      http (replace (cast (_item as varchar), '_', ' '), 0);
      http ('</A>&nbsp;/</NOBR> ');
      _path := subseq ( _path, _slash_pos+1);
    }
}
;

create procedure ODP.ODP.VSP_SUBTOPIC_HREF (
  inout path any, inout params any, inout lines any,
  in _path varchar, in _tag varchar )
{
  declare _colon_pos integer;
  declare _slash_pos integer;
  declare _title varchar;
  _colon_pos := strchr (_path, 58);
  if (_colon_pos is not null)
    {
      _title := "LEFT" (_path, _colon_pos);
      _path := subseq ( _path, _colon_pos+1);
    }
  else
    {
      _slash_pos := strrchr (_path, 47);
      if (_slash_pos is not null)
        _title := subseq (_path, _slash_pos+1);
      else
        _title := _path;
    }
  if (_tag = 'narrow')
    {
      http ('<IMG BORDER=0 SRC="odp_sub.gif" ALT="SUBTOPIC">&nbsp;');
      goto prefix_done;
    }
  if (_tag = 'narrow1')
    {
      http ('<IMG BORDER=0 SRC="odp_sub.gif" ALT="SUBTOPIC">&nbsp;');
      goto bold_prefix_done;
    }
  if (_tag = 'symbolic')
    {
      http ('<IMG BORDER=0 SRC="odp_sym.gif" ALT="SEE ALSO">&nbsp;');
      goto prefix_done;
    }
  if (_tag = 'symbolic1')
    {
      http ('<IMG BORDER=0 SRC="odp_sym.gif" ALT="SEE ALSO">&nbsp;');
      goto bold_prefix_done;
    }
  if (_tag = 'related')
    {
      http ('<IMG BORDER=0 SRC="odp_rel.gif" ALT="RELATED ">&nbsp;');
      ODP.ODP.VSP_TOPIC_HREFS(path,params,lines,_path);
      return;
    }
  if (_tag = 'letterbar')
    {
      goto bold_prefix_done;
    }
  if (_tag <> '')
    http (concat('<CODE>?', cast(_tag as varchar), '</CODE>&nbsp;'));
prefix_done:
  http ('<A HREF="topic.vsp?r_id=');
  http_url (_path);
  http ('"><NOBR>');
  http (replace (cast (_title as varchar), '_', ' '), 0);
  http ('</NOBR></A>');
  return;
bold_prefix_done:
  http ('<A HREF="topic.vsp?r_id=');
  http_url (_path);
  http ('"><NOBR><B>');
  http (replace (cast (_title as varchar), '_', ' '), 0);
  http ('</B></NOBR></A>');
}
;

create procedure ODP.ODP.VSP_EDITOR_HREF (
  inout path any, inout params any, inout lines any,
  in _name varchar )
{
  http ('<A HREF="editor.vsp?r_id=');
  http_url (_name);
  http ('">');
  http_value (_name);
  http ('</A>');
}
;

create procedure ODP.ODP.XSLT(in _data any, in _xst_uri varchar, in _xst_text varchar)
{
  declare str, r varchar;
  xslt_sheet (_xst_uri, xml_tree_doc (xml_tree (_xst_text)));
  r := xslt (_xst_uri, _data);
  http_value (r, 0);
}
;

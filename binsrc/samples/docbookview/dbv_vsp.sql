DB.DBA.RDF_ASSERT ('equ (DBV.DBV.CODE_VERSION(), ''0.1.010316A'')');

create procedure DBV.DBV.VSP_HEADER_LINK (
  inout path any, inout params any, inout lines any,
  in _page varchar, in _title varchar )
{
  declare _name, _config varchar;
  _name := get_keyword ('name', params);
  if (_name is null)
    _name := '';
  _config := get_keyword ('config', params);
  if (_config is null)
    _config := '';
  if (aref(path,length(path)-1) = _page)
    {
      http ('<B>');
      http (_title);
      http ('</B>');
      return;
    }
  http ('<A HREF="');
  http (_page);
  http ('?name=');
  http_url (_name);
  http ('&config=');
  http_url (_config);
  http ('">');
  http (_title);
  http ('</A>');
}

create procedure DBV.DBV.VSP_HEADER (
  inout path any, inout params any, inout lines any,
  in _title varchar )
{
  declare _name varchar;
  declare _type varchar;
  _name := get_keyword ('name', params);
  if (_name is NULL)
    _name := '';
  whenever not found goto nf;
  _type := '?';
  select TYPE into _type from DBV.DBV.SOURCE where FULLNAME=_name;
nf:
  http ('<HTML><HEAD><TITLE>DocBookView | ');
  http (_title);
  http ('</TITLE></HEAD>');
  http ('<BODY>');
  http ('<TABLE BORDER=0 BGCOLOR="#99CCFF" WIDTH="100%"><TR><TD WIDTH="30%" ALIGN=LEFT NOBR>');
  http (' { ');
  DBV.DBV.VSP_HEADER_LINK (path, params, lines, 'main.vsp', 'Main');
  http (' | ');
  DBV.DBV.VSP_HEADER_LINK (path, params, lines, 'chapters.vsp', 'Chapters');
  http (' | ');
  DBV.DBV.VSP_HEADER_LINK (path, params, lines, 'functions.vsp', 'Functions');
  http (' | ');
  DBV.DBV.VSP_HEADER_LINK (path, params, lines, 'xpfs.vsp', 'XPFs');
  http (' | ');
  DBV.DBV.VSP_HEADER_LINK (path, params, lines, 'docbook.vsp', 'DocBook');
  http (' | ');
  DBV.DBV.VSP_HEADER_LINK (path, params, lines, 'drafts.vsp', 'Drafts');
  http (' } &nbsp; &nbsp; &nbsp; {');
  DBV.DBV.VSP_HEADER_LINK (path, params, lines, 'status.vsp', 'Status');
  http (' | ');
  DBV.DBV.VSP_HEADER_LINK (path, params, lines, 'search.vsp', 'Search');
  http(' }');
  if (_name <> '')
    {
      http (' &nbsp; &nbsp; &nbsp; { ');
      DBV.DBV.VSP_HEADER_LINK (path, params, lines, 'viewsource.vsp', 'ViewSource');
      if (_type = 'xml')
        {
          http (' | ');
          DBV.DBV.VSP_HEADER_LINK (path, params, lines, 'viewxml.vsp', 'ViewXml');
          http (' | ');
          DBV.DBV.VSP_HEADER_LINK (path, params, lines, 'parseall.vsp', 'ParseALL');
          http (' | ');
          DBV.DBV.VSP_HEADER_LINK (path, params, lines, 'validate.vsp', 'Validate');
        }
      http (' }');
    } 
  http ('</TD></TR></TABLE>');
}
;

create procedure DBV.DBV.VSP_FOOTER (
  inout path any, inout params any, inout lines any)
{
  http ('<!-- footer -->
</BODY>
</HTML>');
}
;

create procedure DBV.DBV.VSP_ERROR (
  inout path any, inout params any, inout lines any,
  in _message varchar )
{
  declare idx integer;
  http_rewrite(0);
  DBV.DBV.VSP_HEADER (path,params,lines, 'Error');
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
  DBV.DBV.VSP_FOOTER (path,params,lines);
  return _message;
}

create procedure DBV.DBV.XSLT(in _data any, in _xst_uri varchar, in _xst_text varchar)
{
  declare str, r varchar;
  xslt_sheet (_xst_uri, xml_tree_doc (xml_tree (_xst_text)));
  r := xslt (_xst_uri, _data);
  http_value (r, 0);
}
;

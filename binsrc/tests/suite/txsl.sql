--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2017 OpenLink Software
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




create procedure xslt_def (in xst varchar)
{
    xslt_sheet (xst, xml_tree_doc (xml_tree  (file_to_string (xst))));
}


create procedure xslt_file (in f varchar, in xst varchar)
{
  declare str any;
    xslt_stale (xst);
  str := string_output ();
  http_value (xslt (xst, xml_tree_doc (xml_tree (file_to_string (f))),
		    vector ('param1', 'param-1-value', 'param2', 'param-2-value')), 0, str);
  string_to_file ('xslt.out', str, -2);
}


xslt_sheet ('tx.xsl', xml_tree_doc (xml_tree (file_to_string ('tx.xsl'))));





xslt_file ('docsrc/tsales.xml', 'file:docsrc/tsales.xsl');
xslt_file ('docsrc/tsales.xml', 'docsrc/tsales2.xsl');

xslt ('docsrc/tsales.xsl', xml_tree_doc (xml_tree (file_to_string ('docsrc/tsales.xml'))));
xslt ('docsrc/tsales2.xsl', xml_tree_doc (xml_tree (file_to_string ('docsrc/tsales.xml'))));

xslt_file ('ce.xml', 'http://localhost:$U{HTTPPORT}/rdf3.xsl');


xslt ('http://localhost:$U{HTTPPORT}/rdf3.xsl', xml_tree_doc (xml_tree (file_to_string ('ce.xml'))));



create procedure xml_view_string (in _view varchar)
{
  declare _body any;
  declare _pf varchar;
  _body := string_output ();
  http ('<document>', _body);
  _pf := concat ('DB.DBA.http_view_', _view);
  call (_pf) (_body);
  http ('</document>', _body);

  return (string_output_string (_body));
}


create procedure xslt_view (in v varchar, in xst varchar)
{
  declare str, r varchar;
  xslt_sheet (xst, xml_tree_doc (xml_tree  (file_to_string (xst))));
  str := xml_view_string (v);
  r := xslt (xst, xml_tree_doc (xml_tree (str)));
  declare str any;
  str := string_output ();
  http_value (r, 0, str);
  string_to_file ('xslt.out', string_output_string (str), 0);
}


xslt_view ('ord', 'ord.xsl');




xslt_def ('html_common_v.xsl');
xslt_file ('sqlf.xml', 'html_v.xsl');

select xpath_eval ('document ("http://localhost:$U{HTTPPORT}/docsrc/sqlreference.xml")//title', xml_tree_doc (xml_tree ('<a><b>11</b><b>33</b></a>')), 1);

xslt_file ('no.xml', 'file://no.xsl');

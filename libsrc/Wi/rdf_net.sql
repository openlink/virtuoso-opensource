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

-- SERVER

DB.DBA.VHOST_REMOVE (lpath=>'/rdf_net')
;

DB.DBA.VHOST_DEFINE (lpath=>'/rdf_net', ppath=>'/rdf_net')
;

-- use RDF_NET
-- ;

--create procedure RDF_NET.RDF_NET.rdf_net ()  __SOAP_HTTP 'text/html'
create procedure rdf_net ()  __SOAP_HTTP 'text/html'
{
  ;
}
;

grant execute on DB.DBA.rdf_net to public
;

create procedure DB.DBA.HTTP_RDF_NET (in _q any)
{
  declare res, mdta, dta any;
  declare state, msg, _check any;
  declare ses any;

  _q := trim (_q);

  if (_q= '') return;

  _check := sql_parse (_q);
  if (_check [0] <> 100)
	 signal ('rdf_net', 'Error in query.');

  res := exec (_q,   state, msg, vector (), 0, mdta, dta);

  DB.DBA.rdf_net_make_struct (mdta, dta);

  return mdta;
}
;


create procedure
rdf_net_format_mdta (inout mdta any)
{
   declare idx, _line, _name, temp any;

   temp := mdta[0];

   for (idx := 0; idx < length (temp); idx := idx + 1)
     {
	_line := temp[idx];
	_name := temp[idx][0];
	_name := replace (_name, ' ', '_');
	aset (_line, 0, _name);
	aset (temp, idx, _line);
     }

    aset (mdta, 0, temp);
}
;



create procedure
rdf_net_make_xml (inout dta any, inout mdta any)
{
  declare i, l, idx int;
  declare ses any;
  declare xsd varchar;

  ses := string_output ();
  http ('<?xml version="1.0" ?>\n', ses);
  http ('<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:vcard="http://www.w3.org/2001/vcard-rdf/3.0#" xmlns="http://example.org/book/" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:ns="http://example.org/ns#">\n', ses);
  i := 0; l := length (dta);
  while (i < l)
    {
      declare _name, _row, _line varchar;
      declare _type, _type_name, nill int;
      _row := dta[i];
      for (idx := 2; idx < length (_row); idx := idx + 2)
	 {
	    _type := _row[idx];
	    _name := _row[idx + 1];
	    _type := cast (_type as varchar);
	    _name := cast (_name as varchar);
--	    http (sprintf ('<rdf:Description rdf:about="row">\n'), ses);
	    http (sprintf ('<rdf:Description>\n'), ses);
	    http (sprintf ('<%s>%s</%s>\n', _type, _name, _type), ses);
	    http ('</rdf:Description>\n', ses);
	 }
      i := i + 1;
    }
  http ('</rdf:RDF>', ses);
  xsd := string_output_string (ses);
  mdta := xsd;
  return;
}
;


create procedure
rdf_net_make_element (in mdta any, in dta any)
{
  declare res any;
  declare i, l, i1, i2 int;
  i := 0; l := length (mdta); i1 := 2; i2 := 3;
  res := make_array (2 + (l*2), 'any');
  while (i < l)
    {
      aset (res, i1, mdta[i][0]);
      if (mdta[i][1] = 131 and not isblob(dta[i]))
	 aset (res, i2, cast (dta[i] as varbinary));
      else
         aset (res, i2, dta[i]);
      i := i + 1;
      i1 := i1 + 2;
      i2 := i1 + 1;
    }
  return res;
}
;


create procedure rdf_net_make_struct (inout mdta any, inout dta any)
{
  declare res any;
  declare i, l int;
  mdta := mdta[0];
  i := 0; l := length (dta);
  res := make_array (l, 'any');
  while (i < l)
    {
      aset (res, i, rdf_net_make_element (mdta, dta[i]));
      i := i + 1;
    }
  dta := res;
  rdf_net_make_xml (dta, mdta);
}
;

grant execute on DB.DBA.HTTP_RDF_NET to public
;
-- CLIENT

--use DB;

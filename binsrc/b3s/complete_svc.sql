--
--  $Id$
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

create procedure
isvector (in x any)
{
  if (x is null) return null;
  if (__TAG (x) = 193) return 1;
  return 0;
}
;

create procedure
json_out_vec_tst (in v any)
{
  declare _ses any;

  _ses := string_output();

  json_out_vec (v, _ses);

  return (string_output_string(_ses));
}
;

create procedure
json_esc_str (in s any)
{
  return sprintf ('"%s"', replace (replace (replace (s, '\\', '\\\\'), '"', '\\"'), '\n', '\\n'));
}
;

create procedure
json_out_vec (in v any, inout ses any)
{
  declare s varchar;
  s := string_output();

  http ('[', s);

--  dbg_obj_print (v[0]);

  for (declare i, l int, l := length (v); i < l; i := i + 1)
    {
      if (isvector(v[i]))
	{
      	  json_out_vec (v[i], s);
          http (',', s);
        }
      else
        {
          if (isstring(v[i]))
            http (json_esc_str (v[i])||',', s);
        }
    }

  s := rtrim (string_output_string (s), ',');
  s := s || ']';
  http (s, ses);
}
;

DB.DBA.VHOST_REMOVE (lpath=>'/services/rdf/iriautocomplete.get');
DB.DBA.VHOST_DEFINE (lpath=>'/services/rdf/iriautocomplete.get',
                     ppath=>'/SOAP/Http/IRI_AUTOCOMPLETE', soap_user=>'PROXY');

create procedure
DB.DBA.IRI_AUTOCOMPLETE () __SOAP_HTTP 'text/json'
{
  declare params any;
  declare res,ses, lines any;
  declare accept varchar;
  declare len int;
  declare iri_str, lbl_str varchar;
  declare langs varchar;

  iri_str := lbl_str := null;

  ses := string_output();

  params := http_param ();
  lines := http_request_header ();

--  dbg_obj_print (params);
--  dbg_obj_print (lines);

  for (declare i, l int,l := length (params); i < l; i := i + 2)
    {
	if (params[i] = 'uri')
          {
            iri_str := params[i+1];
          }
        else if (params[i] = 'lbl')
          {
            lbl_str := params[i+1];
          }
    }

  if (iri_str = '') iri_str := null;
  if (lbl_str = '') lbl_str := null;

--  dbg_obj_print (iri_str);
--  dbg_obj_print (lbl_str);

  set result_timeout = 1500;

  if (lines is not null)
    {
      langs := http_request_header_full (lines, 'Accept-Language', 'en');
    }

  {
    declare exit handler for sqlstate '*'
    {
      http ('{"error": {"sqlstate" : ' ||
            json_esc_str(__SQL_STATE) ||
            ',"sqlmessage":' ||
            json_esc_str(__SQL_MESSAGE) || '},"results":[]}', ses);
      return ses;
    };

    if (iri_str is not null)
      res := DB.DBA.cmp_uri (iri_str);
    else if (lbl_str is not null)
      res := DB.DBA.cmp_label (lbl_str, langs);
    else
      goto empty;

--  dbg_obj_print (res);

      if (length (res))
        {
          http ('{', ses);

          if (isvector (res[0]))
            http ('"restype":"multiple",', ses);
          else
            http ('"restype":"single",', ses);

          if (iri_str)
            http ('"qrytype":"iri",', ses);
	  else
            http ('"qrytype":"lbl",', ses);

          http ('"results":', ses);
          json_out_vec (res, ses);
        }

      else goto empty;

    ses := rtrim (string_output_string (ses), ',');
    ses := ses || '}';

    return ses;
   empty:
    return '{results: []}';
  };
}
;

grant execute on DB.DBA.IRI_AUTOCOMPLETE to PROXY;
grant execute on DB.DBA.IR_SRV to "PROXY";

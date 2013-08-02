--
--  $Id$
--
--  Executes query on b3s cluster and returns serialized array
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2013 OpenLink Software
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


create procedure b3s_exec (in qr varchar, in params varchar := null)
{
  --pl_debug+
  declare stat, msg, meta, data any;

  stat := '00000';
  if (params is null);
  params := vector ();
  exec (qr, stat, msg, params, 0, meta, data);
  result_names (data);
  if (stat <> '00000')
    result (serialize (vector (vector (msg))));
  else
    {
      declare i, j, l, k int;
      for (i := 0, l := length (data); i < l; i := i + 1)
        {
	  declare rs any;
	  rs := data[i];
	  for (j := 0, k := length (rs); j < k; j := j + 1)
	     {
	       if (__tag of rdf_box = __tag (rs[j]))
		 {
		   declare tmp, lang_id, lang any;
		   tmp := rdf_box_data (rs[j]);
		   lang_id := rdf_box_lang (rs[j]);
		   if (lang_id <> 257)
		     {
		       lang := (select lower (RL_ID) from DB.DBA.RDF_LANGUAGE where RL_TWOBYTE = lang_id);
		       if (lang is not null)
			 tmp := '"'||tmp||'"@'||lang;
		     }
		   rs [j] := rdf_box_data (tmp);
		   data[i] := rs;
		 }
	     }
	}
      result (serialize (data));
    }
  end_result ();
}
;


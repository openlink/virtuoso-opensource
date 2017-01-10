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

create procedure cwords ()
{
  return vector (1234, 5678, 901, 501);
}
;

create procedure fti_gen (in f int)
{
  declare n, lim, sz, did int;
  declare ses any;
  if (f)
    sz := 40000 + rnd (10000);
  else
    sz := 1000 + rnd (3000);
  n := 0;
  lim := 200 + rnd (50);
  did := sequence_next ('__fti_did');
  ses := string_output ();
  while (length (ses) < sz)
    {
      if (n < lim)
	n := cwords () [mod (n, 4)];
      else
        n := rnd (1000);
      http (sprintf ('%d.%d,0 ', did, n), ses);
      n := n + 1;
    }
  return string_output_string (ses);
}
;

create procedure fti_ins (in _g any, in n any)
{
  declare trip, s, p, o, g, i, ses any;
  ses := string_output ();
  g := sprintf ('%s%d/', _g, rnd (80000));
  for (i := 0; i < n; i := i + 1)
  {
    s := sprintf ('<s%d>', rnd (1000000));
    p := sprintf ('<p%d>', rnd (3500));
    if (mod (i, 4) = 0)
      o := fti_gen (1);
    else
      o := fti_gen (0);
    trip := sprintf ('%s %s "%s" .\n', s, p, o);
    http (trip, ses);
    if (mod (i, 50) = 0)
      {
	ttlp (ses, g, g);
	string_output_flush (ses);
	commit work;
	--s := sprintf ('<s%d>', rnd (1000000));
	exec (sprintf ('sparql delete from <%s> {?s ?p ?o} where {?s ?p ?o . filter (?s = %s)}', g, s));
	g := sprintf ('%s%d/', _g, rnd (80000));
      }
  }
  --VT_INC_INDEX_DB_DBA_RDF_OBJ ();
  commit work;
}
;


create procedure docpt ()
{
  while (1)
    {
      exec ('checkpoint');
      delay (40);
    }
}
;

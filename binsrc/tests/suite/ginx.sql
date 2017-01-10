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

-- Make geometries for geo:long, geo:lat pairs


create procedure num_or_null (in n any)
{
  declare exit handler for sqlstate '*'{ return null; };
  return cast (cast (n as decimal) as real);
}

create procedure rdf_geo_fill_single ()
{
  for select "s", "long", "lat", "g" from (sparql define output:valmode "LONG" select ?g ?s ?long ?lat where {
  graph ?g { ?s geo:long ?long . ?s geo:lat ?lat}}) f option (any order)  do
  {
    "lat" := num_or_null ("lat");
    "long" := num_or_null ("long");
    if (isnumeric ("lat") and isnumeric ("long"))
      insert into rdf_quad (g, s, p, o) values ("g", "s", iri_to_id ('http://www.w3.org/2003/01/geo/wgs84_pos#geometry'),
	rdf_geo_add (rdf_box (st_point ("long", "lat"), 256, 257, 0, 1)));
  }

}

create procedure GEO_FILL_CL_SRV  (inout arr any, in fill int)
{
  declare lat, lng, s, g, l, dp any;
  declare inx int;
  log_enable (2, 1);
  connection_set ('g_dict', null);
 dp := dpipe (5, 'IRI_TO_ID_1', 'IRI_TO_ID_1', 'IRI_TO_ID_1', 'MAKE_RO_1', 'IRI_TO_ID_1');
  dpipe_set_rdf_load (dp, 2);
  for (inx := 0; inx < fill; inx := inx + 1)
    {
    l := arr[inx];
    g := l[0];
    s := l[1];
    lng := num_or_null (l[2]);
    lat := num_or_null (l[3]);
      if (isnumeric (lat) and isnumeric (lng))
	dpipe_input (dp, s, 'http://www.w3.org/2003/01/geo/wgs84_pos#geometry', null, rdf_box (st_point (lng, lat), 256, 257, 0, 1), g);
    }
    dpipe_next (dp, 0);
  dpipe_next (dp, 1);
}

create procedure GEO_FILL_SRV  (in arr any, in fill int)
{
  declare lat, lng, s, g, l any;
  declare inx int;
  log_enable (2, 1);
  if (0 = sys_stat ('cl_run_local_only'))
    return geo_fill_cl_srv (arr, fill);
  for (inx := 0; inx < fill; inx := inx + 1)
    {
    l := arr[inx];
    g := l[0];
    s := l[1];
    lng := num_or_null (l[2]);
    lat := num_or_null (l[3]);
      if (isnumeric (lat) and isnumeric (lng))
	insert into rdf_quad (g, s, p, o) values ("g", "s", iri_to_id ('http://www.w3.org/2003/01/geo/wgs84_pos#geometry'),
						  rdf_geo_add (rdf_box (st_point (lng, lat), 256, 257, 0, 1)));
    }
}


create procedure rdf_geo_fill (in threads int := 4)
{
  declare arr, fill, aq, ctr any;
 aq := async_queue (threads);
 arr := make_array (10000, 'any');
 fill := 0;
 ctr := 0;
  log_enable (2, 1);
  for select "s", "long", "lat", "g" from (sparql define output:valmode "LONG" select ?g ?s ?long ?lat where {
  graph ?g { ?s geo:long ?long . ?s geo:lat ?lat}}) f  do
  {
    arr[fill] := vector ("g", "s", rdf_box_data ("long"), rdf_box_data ("lat"));
    fill := fill + 1;
    if (10000 = fill)
      {
	aq_request (aq, 'DB.DBA.GEO_FILL_SRV', vector (arr, fill));
      ctr := ctr + 1;
	if (ctr > 10)
	  {
	    aq_wait_all (aq);
	  ctr := 0;
	  }
      arr := make_array (10000, 'any');
      fill := 0;
      }
  }
  geo_fill_srv (arr, fill);
}

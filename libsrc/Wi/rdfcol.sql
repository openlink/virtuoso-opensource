--
--  $Id$
--
--  Convert from row wise to column-wise rdf
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


drop index rdf_quad_pogs;
drop index rdf_quad_sp;
drop index rdf_quad_op;
drop index rdf_quad_gs;

alter table rdf_quad rename rq_rows;

create table RDF_QUAD (
  G IRI_ID_8,
  S IRI_ID_8,
  P IRI_ID_8,
  O any,
  primary key (P, S, O, G) column
  )
alter index RDF_QUAD on RDF_QUAD partition (S int (0hexffff00))
create column index RDF_QUAD_POGS on RDF_QUAD (P, O, S, G) partition (O varchar (-1, 0hexffff))
;
create distinct no primary key ref column index RDF_QUAD_SP on RDF_QUAD (S, P) partition (S int (0hexffff00))
create distinct no primary key ref column index RDF_QUAD_GS on RDF_QUAD (G, S) partition (S int (0hexffff00))
create distinct no primary key ref column index RDF_QUAD_OP on RDF_QUAD (O, P) partition (O varchar (-1, 0hexffff))
;

-- disable transaction log and use autocommit
-- as result of query might be too large to fit into transaction
log_enable(2, 1);
insert into rdf_quad (g,s,p,o) select g,s,p,o from rq_rows;
checkpoint;
-- reenable transaction log
log_enable(1, 1);

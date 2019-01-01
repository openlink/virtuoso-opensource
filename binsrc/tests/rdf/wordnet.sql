--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2019 OpenLink Software
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
select qq RDF_IID_NAME (RQ_PRED_IID), count (1)
from RDF_QUAD
group by RQ_PRED_IID
order by 2
;

select qq RDF_IID_NAME (RQ_OBJ_IID), count (1)
from RDF_QUAD
where RQ_PRED_IID= RDF_RDFXML_NAME_TO_IID ('http://www.w3.org/1999/02/22-rdf-syntax-ns#', 'type')
group by RQ_OBJ_IID
order by 2
;

create function wn_ns_iid () returns integeR
{
  return RDF_LNAME_TO_IID (RDF_LNAME_TO_IID (0, 'http'), '//www.wordnet.princeton.edu/wn#');
}
;

create function wn_iid (in lname varchar) returns integeR
{
  if (isstring (lname))
    return RDF_RDFXML_NAME_TO_IID ('http://wordnet.princeton.edu/wn#', lname);
  return RDF_LNAME_TO_IID (0, 'http://wordnet.princeton.edu/wn#');
}
;

-- ( ?a wn:hyponymOf ?b ) && ( ?b wn:hyponymOf ?c )
select qq count (1) 
from RDF_QUAD q1 join RDF_QUAD q2 on (q1.RQ_OBJ_IID = q2.RQ_SUBJ_IID)
where
q1.RQ_PRED_IID = wn_iid ('hyponymOf') and 
q2.RQ_PRED_IID = wn_iid ('hyponymOf')
; -- 110 sec.

select explain ('
select count (1) 
from RDF_QUAD q1 join RDF_QUAD q2 on (q1.RQ_OBJ_IID = q2.RQ_SUBJ_IID)
where
q1.RQ_PRED_IID = wn_iid (''hyponymOf'') and 
q2.RQ_PRED_IID = wn_iid (''hyponymOf'') ')
; -- 110 sec.

-- ( ?a wn:hyponymOf ?b ) && ( ?b wn:hyponymOf ?c )
select qq count (1) 
from RDF_QUAD q1 join RDF_QUAD q2
  on (q1.RQ_OBJ_IID = q2.RQ_SUBJ_IID)
where
q1.RQ_GRAPH_IID = wn_ns_iid () and 
q2.RQ_GRAPH_IID = wn_ns_iid () and 
q1.RQ_OBJ is null and
q1.RQ_PRED_IID = wn_iid ('hyponymOf') and 
q2.RQ_PRED_IID = wn_iid ('hyponymOf')
;

select explain ('select count (1) 
from RDF_QUAD q1 join RDF_QUAD q2
  on (q1.RQ_OBJ_IID = q2.RQ_SUBJ_IID)
where
q1.RQ_GRAPH_IID = wn_ns_iid () and 
q2.RQ_GRAPH_IID = wn_ns_iid () and 
q1.RQ_OBJ is null and
q1.RQ_PRED_IID = wn_iid (''hyponymOf'') and 
q2.RQ_PRED_IID = wn_iid (''hyponymOf'') ')
;

-- ( ?a wn:hyponymOf ?b ) && ( ?b wn:hyponymOf ?c ) && ( ?c wn:hyponymOf ?d )
select qq count (1) 
from
  RDF_QUAD q1
  join RDF_QUAD q2  on (q1.RQ_OBJ_IID = q2.RQ_SUBJ_IID)
  join RDF_QUAD q3  on (q2.RQ_OBJ_IID = q3.RQ_SUBJ_IID)
where
q1.RQ_GRAPH_IID = wn_ns_iid () and 
q2.RQ_GRAPH_IID = wn_ns_iid () and 
q3.RQ_GRAPH_IID = wn_ns_iid () and 
q1.RQ_OBJ is null and
q2.RQ_OBJ is null and
q1.RQ_PRED_IID = wn_iid ('hyponymOf') and 
q2.RQ_PRED_IID = wn_iid ('hyponymOf') and 
q3.RQ_PRED_IID = wn_iid ('hyponymOf')
;

-- ( ?a wn:hyponymOf ?b ) && ( ?b wn:hyponymOf ?c ) && ( ?c wn:hyponymOf ?d )
select qq count (1) 
from
  RDF_QUAD q1
  join RDF_QUAD q2  on (q1.RQ_OBJ_IID = q2.RQ_SUBJ_IID)
  join RDF_QUAD q3  on (q2.RQ_OBJ_IID = q3.RQ_SUBJ_IID)
  join RDF_QUAD q4  on (q3.RQ_OBJ_IID = q4.RQ_SUBJ_IID)
where
q1.RQ_GRAPH_IID = wn_ns_iid () and 
q2.RQ_GRAPH_IID = wn_ns_iid () and 
q3.RQ_GRAPH_IID = wn_ns_iid () and 
q4.RQ_GRAPH_IID = wn_ns_iid () and 
q1.RQ_OBJ is null and
q2.RQ_OBJ is null and
q3.RQ_OBJ is null and
q1.RQ_PRED_IID = wn_iid ('hyponymOf') and 
q2.RQ_PRED_IID = wn_iid ('hyponymOf') and 
q3.RQ_PRED_IID = wn_iid ('hyponymOf') and
q4.RQ_PRED_IID = wn_iid ('hyponymOf')
;

-- ( ?a wn:hyponymOf ?b ) && ( ?b wn:hyponymOf ?c ) && ( ?c wn:hyponymOf ?d )
select qq count (1) 
from
  RDF_QUAD q1
  join RDF_QUAD q2  on (q1.RQ_OBJ_IID = q2.RQ_SUBJ_IID)
  join RDF_QUAD q3  on (q2.RQ_OBJ_IID = q3.RQ_SUBJ_IID)
  join RDF_QUAD q4  on (q3.RQ_OBJ_IID = q4.RQ_SUBJ_IID)
  join RDF_QUAD q5  on (q4.RQ_OBJ_IID = q5.RQ_SUBJ_IID)
where
q1.RQ_GRAPH_IID = wn_ns_iid () and 
q2.RQ_GRAPH_IID = wn_ns_iid () and 
q3.RQ_GRAPH_IID = wn_ns_iid () and 
q4.RQ_GRAPH_IID = wn_ns_iid () and 
q5.RQ_GRAPH_IID = wn_ns_iid () and 
q1.RQ_OBJ is null and
q2.RQ_OBJ is null and
q3.RQ_OBJ is null and
q4.RQ_OBJ is null and
q1.RQ_PRED_IID = wn_iid ('hyponymOf') and 
q2.RQ_PRED_IID = wn_iid ('hyponymOf') and 
q3.RQ_PRED_IID = wn_iid ('hyponymOf') and
q4.RQ_PRED_IID = wn_iid ('hyponymOf') and
q5.RQ_PRED_IID = wn_iid ('hyponymOf')
;

drop table RDF_MJV_hyponymOf_any_any;

create table RDF_MJV_hyponymOf_any_any
(
--  RM_G integeR not null,
  RM_S integeR not null,
  RM_O integeR not null,
  primary key (--RM_G,
   RM_S, RM_O)
)
;

create index RDF_MJV_hyponymOf_any_any_G_O on RDF_MJV_hyponymOf_any_any (--RM_G, 
RM_O, RM_S);

create procedure RDF_FILL_MJV_hyponymOf_any_any ()
{
  for (select --RQ_GRAPH_IID,
   RQ_SUBJ_IID, RQ_OBJ_IID from RDF_QUAD where RQ_OBJ_IID is not null and RQ_PRED_IID = wn_iid ('hyponymOf') and RQ_PRED_IID = wn_iid ('hyponymOf')) do
    insert replacing RDF_MJV_hyponymOf_any_any (--RM_G, 
    RM_S, RM_O) values (--RQ_GRAPH_IID, 
    RQ_SUBJ_IID, RQ_OBJ_IID);
}
;

RDF_FILL_MJV_hyponymOf_any_any ()
;


-- ( ?a wn:hyponymOf ?b ) && ( ?b wn:hyponymOf ?c ) && ( ?c wn:hyponymOf ?d )
select explain ('
select count (1) 
from
  RDF_MJV_hyponymOf_any_any q1
  join RDF_MJV_hyponymOf_any_any q2 on (q1.RM_O = q2.RM_S)
  join RDF_MJV_hyponymOf_any_any q3 on (q2.RM_O = q3.RM_S)
  join RDF_QUAD q4  on (q3.RM_O = q4.RQ_SUBJ_IID)
where
--q1.RM_G = wn_ns_iid () and 
--q2.RM_G = wn_ns_iid () and 
--q3.RM_G = wn_ns_iid () and 
--q4.RQ_GRAPH_IID = wn_ns_iid () and 
q4.RQ_PRED_IID = wn_iid (''hyponymOf'')')
;

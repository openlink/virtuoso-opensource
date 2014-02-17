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

set timeout 15;

-- materialize:
-- ub:Professor
-- ub:Person
-- ub:Student
-- ub:Course
-- ub:Faculty
--
-- ub:memberOf
-- ub:worksFor

sparql prefix ub: <http://www.lehigh.edu/~zhp2/2004/0401/univ-bench.owl#>
insert into graph <lubm> { ?x a ub:Professor }
where {
  	{ ?x a ub:AssistantProfessor } union
  	{ ?x a ub:AssociateProfessor } union
  	{ ?x a ub:FullProfessor } union
  	{ ?x a ub:VisitingProfessor }
      };

sparql prefix ub: <http://www.lehigh.edu/~zhp2/2004/0401/univ-bench.owl#>
insert into graph <lubm> { ?x a ub:Faculty }
where {
  	{ ?x a ub:Professor } union
  	{ ?x a ub:PostDoc } union
  	{ ?x a ub:Lecturer }
      };

sparql prefix ub: <http://www.lehigh.edu/~zhp2/2004/0401/univ-bench.owl#>
insert into graph <lubm> { ?x a ub:Student }
where {
  	{ ?x a ub:UndergraduateStudent } union
  	{ ?x a ub:GraduateStudent } union
  	{ ?x a ub:ResearchAssistant }
};


sparql prefix ub: <http://www.lehigh.edu/~zhp2/2004/0401/univ-bench.owl#>
insert into graph <lubm> { ?x a ub:AdministrativeStaff }
where {
  	{ ?x a ub:ClericalStaff } union
  	{ ?x a ub:SystemsStaff }
};

sparql prefix ub: <http://www.lehigh.edu/~zhp2/2004/0401/univ-bench.owl#>
insert into graph <lubm> { ?x a ub:Employee }
where {
  	{ ?x a ub:Faculty } union
  	{ ?x a ub:AdministrativeStaff }
};

sparql prefix ub: <http://www.lehigh.edu/~zhp2/2004/0401/univ-bench.owl#>
insert into graph <lubm> { ?x a ub:Person }
where {
  	{ ?x a ub:Chair } union
  	{ ?x a ub:Dean  } union
  	{ ?x a ub:Director } union
  	{ ?x a ub:Employee } union
  	{ ?x a ub:Student } union
  	{ ?x a ub:TeachingAssistant }
};

sparql prefix ub: <http://www.lehigh.edu/~zhp2/2004/0401/univ-bench.owl#>
insert into graph <lubm> { ?x a ub:Course }
where {
  	{ ?x a ub:GraduateCourse }
};

sparql prefix ub: <http://www.lehigh.edu/~zhp2/2004/0401/univ-bench.owl#>
insert into graph <lubm> { ?x ub:worksFor ?z }
where {
  	{ ?x ub:headOf ?z }
};

sparql prefix ub: <http://www.lehigh.edu/~zhp2/2004/0401/univ-bench.owl#>
insert into graph <lubm> { ?x ub:memberOf ?z }
where {
  	{ ?x ub:worksFor ?z }
};

sparql prefix ub: <http://www.lehigh.edu/~zhp2/2004/0401/univ-bench.owl#>
insert into graph <lubm> { ?x ub:degreeFrom ?z }
where {
  	{ ?x ub:doctoralDegreeFrom ?z } union
  	{ ?x ub:mastersDegreeFrom ?z } union
  	{ ?x ub:undergraduateDegreeFrom ?z }
};



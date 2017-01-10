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

set timeout 15;

-- Q1
sparql prefix ub: <http://www.lehigh.edu/~zhp2/2004/0401/univ-bench.owl#>
select * from <lubm>
where { ?x rdf:type ub:GraduateStudent . ?x ub:takesCourse <http://www.Department0.University0.edu/GraduateCourse0> };
ECHO BOTH $IF $EQU $ROWCNT 4 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Q1 returned " $ROWCNT " rows\n";

-- Q2
sparql prefix ub: <http://www.lehigh.edu/~zhp2/2004/0401/univ-bench.owl#>
select * from <lubm>
where { ?x a ub:GraduateStudent . ?y a  ub:University . ?z a ub:Department . ?x ub:memberOf ?z . ?z ub:subOrganizationOf ?y . ?x ub:undergraduateDegreeFrom ?y };
ECHO BOTH $IF $EQU $ROWCNT 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Q2 returned " $ROWCNT " rows\n";

-- Q3
sparql prefix ub: <http://www.lehigh.edu/~zhp2/2004/0401/univ-bench.owl#>
select * from <lubm>
where { ?x a ub:Publication . ?x ub:publicationAuthor <http://www.Department0.University0.edu/AssistantProfessor0> };
ECHO BOTH $IF $EQU $ROWCNT 6 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Q3 returned " $ROWCNT " rows\n";

-- Q4
sparql prefix ub: <http://www.lehigh.edu/~zhp2/2004/0401/univ-bench.owl#>
select * from <lubm>
where
{

{ ?x a ub:AssociateProfessor . ?x ub:worksFor <http://www.Department0.University0.edu> . ?x ub:name ?y1 . ?x ub:emailAddress ?y2 . ?x ub:telephone ?y3 . }
union
{ ?x a ub:AssistantProfessor . ?x ub:worksFor <http://www.Department0.University0.edu> . ?x ub:name ?y1 . ?x ub:emailAddress ?y2 . ?x ub:telephone ?y3 . }
union
{ ?x a ub:FullProfessor . ?x ub:worksFor <http://www.Department0.University0.edu> . ?x ub:name ?y1 . ?x ub:emailAddress ?y2 . ?x ub:telephone ?y3 . }

};

ECHO BOTH $IF $EQU $ROWCNT 34 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Q4 returned " $ROWCNT " rows\n";

-- Q5
sparql prefix ub: <http://www.lehigh.edu/~zhp2/2004/0401/univ-bench.owl#>
select distinct * from <lubm>
where
{
{ ?x a ub:AssociateProfessor . ?x ub:memberOf <http://www.Department0.University0.edu> } union
{ ?x a ub:FullProfessor . ?x ub:memberOf <http://www.Department0.University0.edu> } union
{ ?x a ub:AssistantProfessor . ?x ub:memberOf <http://www.Department0.University0.edu> } union
{ ?x a ub:Lecturer . ?x ub:memberOf <http://www.Department0.University0.edu> } union
{ ?x a ub:UndergraduateStudent . ?x ub:memberOf <http://www.Department0.University0.edu> } union
{ ?x a ub:GraduateStudent . ?x ub:memberOf <http://www.Department0.University0.edu> } union
{ ?x a ub:TeachingAssistant . ?x ub:memberOf <http://www.Department0.University0.edu> } union
{ ?x a ub:ResearchAssistant . ?x ub:memberOf <http://www.Department0.University0.edu> } union

{ ?x a ub:AssociateProfessor . ?x ub:worksFor <http://www.Department0.University0.edu> } union
{ ?x a ub:FullProfessor . ?x ub:worksFor <http://www.Department0.University0.edu> } union
{ ?x a ub:AssistantProfessor . ?x ub:worksFor <http://www.Department0.University0.edu> } union
{ ?x a ub:Lecturer . ?x ub:worksFor <http://www.Department0.University0.edu> } union
{ ?x a ub:UndergraduateStudent . ?x ub:worksFor <http://www.Department0.University0.edu> } union
{ ?x a ub:GraduateStudent . ?x ub:worksFor <http://www.Department0.University0.edu> } union
{ ?x a ub:TeachingAssistant . ?x ub:worksFor <http://www.Department0.University0.edu> } union
{ ?x a ub:ResearchAssistant . ?x ub:worksFor <http://www.Department0.University0.edu> } union

{ ?x a ub:AssociateProfessor . ?x ub:headOf <http://www.Department0.University0.edu> } union
{ ?x a ub:FullProfessor . ?x ub:headOf <http://www.Department0.University0.edu> } union
{ ?x a ub:AssistantProfessor . ?x ub:headOf <http://www.Department0.University0.edu> } union
{ ?x a ub:Lecturer . ?x ub:headOf <http://www.Department0.University0.edu> } union
{ ?x a ub:UndergraduateStudent . ?x ub:headOf <http://www.Department0.University0.edu> } union
{ ?x a ub:GraduateStudent . ?x ub:headOf <http://www.Department0.University0.edu> } union
{ ?x a ub:TeachingAssistant . ?x ub:headOf <http://www.Department0.University0.edu> } union
{ ?x a ub:ResearchAssistant . ?x ub:headOf <http://www.Department0.University0.edu> }

};
ECHO BOTH $IF $EQU $ROWCNT 719 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Q5 returned " $ROWCNT " rows\n";

-- Q6
sparql prefix ub: <http://www.lehigh.edu/~zhp2/2004/0401/univ-bench.owl#>
select distinct * from <lubm> where {
  { ?x a ub:UndergraduateStudent . }
  union
  { ?x a ub:ResearchAssistant . }
  union
  { ?x a ub:GraduateStudent . }
};
ECHO BOTH $IF $EQU $ROWCNT 7790 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Q6 returned " $ROWCNT " rows\n";

-- Q7
sparql prefix ub: <http://www.lehigh.edu/~zhp2/2004/0401/univ-bench.owl#>
select distinct * from <lubm>
where
{
{  ?x a ub:UndergraduateStudent . ?y a ub:Course . <http://www.Department0.University0.edu/AssociateProfessor0> ub:teacherOf ?y . ?x ub:takesCourse ?y . }
union
{  ?x a ub:UndergraduateStudent . ?y a ub:GraduateCourse . <http://www.Department0.University0.edu/AssociateProfessor0> ub:teacherOf ?y . ?x ub:takesCourse ?y . }
union
{  ?x a ub:ResearchAssistant . ?y a ub:Course . <http://www.Department0.University0.edu/AssociateProfessor0> ub:teacherOf ?y . ?x ub:takesCourse ?y . }
union
{  ?x a ub:ResearchAssistant . ?y a ub:GraduateCourse . <http://www.Department0.University0.edu/AssociateProfessor0> ub:teacherOf ?y . ?x ub:takesCourse ?y . }
union
{  ?x a ub:GraduateStudent . ?y a ub:Course . <http://www.Department0.University0.edu/AssociateProfessor0> ub:teacherOf ?y . ?x ub:takesCourse ?y . }
union
{  ?x a ub:GraduateStudent . ?y a ub:GraduateCourse . <http://www.Department0.University0.edu/AssociateProfessor0> ub:teacherOf ?y . ?x ub:takesCourse ?y . }
}
;
ECHO BOTH $IF $EQU $ROWCNT 67 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Q7 returned " $ROWCNT " rows\n";


-- Q8
sparql prefix ub: <http://www.lehigh.edu/~zhp2/2004/0401/univ-bench.owl#>
select distinct * from <lubm>
where
{
 { ?x a ub:UndergraduateStudent . ?y a ub:Department . ?x ub:memberOf ?y . ?y ub:subOrganizationOf <http://www.University0.edu> . ?x ub:emailAddress ?z }
  union
 { ?x a ub:UndergraduateStudent . ?y a ub:Department . ?x ub:worksFor ?y . ?y ub:subOrganizationOf <http://www.University0.edu> . ?x ub:emailAddress ?z }
  union
 { ?x a ub:UndergraduateStudent . ?y a ub:Department . ?x ub:headOf ?y . ?y ub:subOrganizationOf <http://www.University0.edu> . ?x ub:emailAddress ?z }
  union
 { ?x a ub:ResearchAssistant . ?y a ub:Department . ?x ub:memberOf ?y . ?y ub:subOrganizationOf <http://www.University0.edu> . ?x ub:emailAddress ?z }
  union
 { ?x a ub:ResearchAssistant . ?y a ub:Department . ?x ub:worksFor ?y . ?y ub:subOrganizationOf <http://www.University0.edu> . ?x ub:emailAddress ?z }
  union
 { ?x a ub:ResearchAssistant . ?y a ub:Department . ?x ub:headOf ?y . ?y ub:subOrganizationOf <http://www.University0.edu> . ?x ub:emailAddress ?z }
  union
 { ?x a ub:GraduateStudent . ?y a ub:Department . ?x ub:memberOf ?y . ?y ub:subOrganizationOf <http://www.University0.edu> . ?x ub:emailAddress ?z }
  union
 { ?x a ub:GraduateStudent . ?y a ub:Department . ?x ub:worksFor ?y . ?y ub:subOrganizationOf <http://www.University0.edu> . ?x ub:emailAddress ?z }
  union
 { ?x a ub:GraduateStudent . ?y a ub:Department . ?x ub:headOf ?y . ?y ub:subOrganizationOf <http://www.University0.edu> . ?x ub:emailAddress ?z }
}
;

ECHO BOTH $IF $EQU $ROWCNT 7790 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Q8 returned " $ROWCNT " rows\n";

-- Q9
sparql prefix ub: <http://www.lehigh.edu/~zhp2/2004/0401/univ-bench.owl#>
select distinct * from <lubm>
where
{
  { ?x a ub:ResearchAssistant . ?y a ub:Lecturer . ?z a ub:Course . ?x ub:advisor ?y . ?x ub:takesCourse ?z . ?y ub:teacherOf ?z . } union
  { ?x a ub:ResearchAssistant . ?y a ub:PostDoc . ?z a ub:Course . ?x ub:advisor ?y . ?x ub:takesCourse ?z . ?y ub:teacherOf ?z . } union
  { ?x a ub:ResearchAssistant . ?y a ub:VisitingProfessor . ?z a ub:Course . ?x ub:advisor ?y . ?x ub:takesCourse ?z . ?y ub:teacherOf ?z . } union
  { ?x a ub:ResearchAssistant . ?y a ub:AssistantProfessor . ?z a ub:Course . ?x ub:advisor ?y . ?x ub:takesCourse ?z . ?y ub:teacherOf ?z . } union
  { ?x a ub:ResearchAssistant . ?y a ub:AssociateProfessor . ?z a ub:Course . ?x ub:advisor ?y . ?x ub:takesCourse ?z . ?y ub:teacherOf ?z . } union
  { ?x a ub:ResearchAssistant . ?y a ub:FullProfessor . ?z a ub:Course . ?x ub:advisor ?y . ?x ub:takesCourse ?z . ?y ub:teacherOf ?z . } union

  { ?x a ub:ResearchAssistant . ?y a ub:Lecturer . ?z a ub:GraduateCourse . ?x ub:advisor ?y . ?x ub:takesCourse ?z . ?y ub:teacherOf ?z . } union
  { ?x a ub:ResearchAssistant . ?y a ub:PostDoc . ?z a ub:GraduateCourse . ?x ub:advisor ?y . ?x ub:takesCourse ?z . ?y ub:teacherOf ?z . } union
  { ?x a ub:ResearchAssistant . ?y a ub:VisitingProfessor . ?z a ub:GraduateCourse . ?x ub:advisor ?y . ?x ub:takesCourse ?z . ?y ub:teacherOf ?z . } union
  { ?x a ub:ResearchAssistant . ?y a ub:AssistantProfessor . ?z a ub:GraduateCourse . ?x ub:advisor ?y . ?x ub:takesCourse ?z . ?y ub:teacherOf ?z . } union
  { ?x a ub:ResearchAssistant . ?y a ub:AssociateProfessor . ?z a ub:GraduateCourse . ?x ub:advisor ?y . ?x ub:takesCourse ?z . ?y ub:teacherOf ?z . } union
  { ?x a ub:ResearchAssistant . ?y a ub:FullProfessor . ?z a ub:GraduateCourse . ?x ub:advisor ?y . ?x ub:takesCourse ?z . ?y ub:teacherOf ?z . } union
  { ?x a ub:UndergraduateStudent . ?y a ub:Lecturer . ?z a ub:Course . ?x ub:advisor ?y . ?x ub:takesCourse ?z . ?y ub:teacherOf ?z . } union
  { ?x a ub:UndergraduateStudent . ?y a ub:PostDoc . ?z a ub:Course . ?x ub:advisor ?y . ?x ub:takesCourse ?z . ?y ub:teacherOf ?z . } union
  { ?x a ub:UndergraduateStudent . ?y a ub:VisitingProfessor . ?z a ub:Course . ?x ub:advisor ?y . ?x ub:takesCourse ?z . ?y ub:teacherOf ?z . } union
  { ?x a ub:UndergraduateStudent . ?y a ub:AssistantProfessor . ?z a ub:Course . ?x ub:advisor ?y . ?x ub:takesCourse ?z . ?y ub:teacherOf ?z . } union
  { ?x a ub:UndergraduateStudent . ?y a ub:AssociateProfessor . ?z a ub:Course . ?x ub:advisor ?y . ?x ub:takesCourse ?z . ?y ub:teacherOf ?z . } union
  { ?x a ub:UndergraduateStudent . ?y a ub:FullProfessor . ?z a ub:Course . ?x ub:advisor ?y . ?x ub:takesCourse ?z . ?y ub:teacherOf ?z . } union

  { ?x a ub:UndergraduateStudent . ?y a ub:Lecturer . ?z a ub:GraduateCourse . ?x ub:advisor ?y . ?x ub:takesCourse ?z . ?y ub:teacherOf ?z . } union
  { ?x a ub:UndergraduateStudent . ?y a ub:PostDoc . ?z a ub:GraduateCourse . ?x ub:advisor ?y . ?x ub:takesCourse ?z . ?y ub:teacherOf ?z . } union
  { ?x a ub:UndergraduateStudent . ?y a ub:VisitingProfessor . ?z a ub:GraduateCourse . ?x ub:advisor ?y . ?x ub:takesCourse ?z . ?y ub:teacherOf ?z . } union
  { ?x a ub:UndergraduateStudent . ?y a ub:AssistantProfessor . ?z a ub:GraduateCourse . ?x ub:advisor ?y . ?x ub:takesCourse ?z . ?y ub:teacherOf ?z . } union
  { ?x a ub:UndergraduateStudent . ?y a ub:AssociateProfessor . ?z a ub:GraduateCourse . ?x ub:advisor ?y . ?x ub:takesCourse ?z . ?y ub:teacherOf ?z . } union
  { ?x a ub:UndergraduateStudent . ?y a ub:FullProfessor . ?z a ub:GraduateCourse . ?x ub:advisor ?y . ?x ub:takesCourse ?z . ?y ub:teacherOf ?z . } union
  { ?x a ub:GraduateStudent . ?y a ub:Lecturer . ?z a ub:Course . ?x ub:advisor ?y . ?x ub:takesCourse ?z . ?y ub:teacherOf ?z . } union
  { ?x a ub:GraduateStudent . ?y a ub:PostDoc . ?z a ub:Course . ?x ub:advisor ?y . ?x ub:takesCourse ?z . ?y ub:teacherOf ?z . } union
  { ?x a ub:GraduateStudent . ?y a ub:VisitingProfessor . ?z a ub:Course . ?x ub:advisor ?y . ?x ub:takesCourse ?z . ?y ub:teacherOf ?z . } union
  { ?x a ub:GraduateStudent . ?y a ub:AssistantProfessor . ?z a ub:Course . ?x ub:advisor ?y . ?x ub:takesCourse ?z . ?y ub:teacherOf ?z . } union
  { ?x a ub:GraduateStudent . ?y a ub:AssociateProfessor . ?z a ub:Course . ?x ub:advisor ?y . ?x ub:takesCourse ?z . ?y ub:teacherOf ?z . } union
  { ?x a ub:GraduateStudent . ?y a ub:FullProfessor . ?z a ub:Course . ?x ub:advisor ?y . ?x ub:takesCourse ?z . ?y ub:teacherOf ?z . } union
  { ?x a ub:GraduateStudent . ?y a ub:Lecturer . ?z a ub:GraduateCourse . ?x ub:advisor ?y . ?x ub:takesCourse ?z . ?y ub:teacherOf ?z . } union
  { ?x a ub:GraduateStudent . ?y a ub:PostDoc . ?z a ub:GraduateCourse . ?x ub:advisor ?y . ?x ub:takesCourse ?z . ?y ub:teacherOf ?z . } union
  { ?x a ub:GraduateStudent . ?y a ub:VisitingProfessor . ?z a ub:GraduateCourse . ?x ub:advisor ?y . ?x ub:takesCourse ?z . ?y ub:teacherOf ?z . } union
  { ?x a ub:GraduateStudent . ?y a ub:AssistantProfessor . ?z a ub:GraduateCourse . ?x ub:advisor ?y . ?x ub:takesCourse ?z . ?y ub:teacherOf ?z . } union
  { ?x a ub:GraduateStudent . ?y a ub:AssociateProfessor . ?z a ub:GraduateCourse . ?x ub:advisor ?y . ?x ub:takesCourse ?z . ?y ub:teacherOf ?z . } union
  { ?x a ub:GraduateStudent . ?y a ub:FullProfessor . ?z a ub:GraduateCourse . ?x ub:advisor ?y . ?x ub:takesCourse ?z . ?y ub:teacherOf ?z . }
};

ECHO BOTH $IF $EQU $ROWCNT 208 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Q9 returned " $ROWCNT " rows\n";

-- Q10
sparql prefix ub: <http://www.lehigh.edu/~zhp2/2004/0401/univ-bench.owl#>
select * from <lubm>
where
{
{ ?x a ub:ResearchAssistant . ?x ub:takesCourse <http://www.Department0.University0.edu/GraduateCourse0> . }
union
{ ?x a ub:UndergraduateStudent . ?x ub:takesCourse <http://www.Department0.University0.edu/GraduateCourse0> . }
union
{ ?x a ub:GraduateStudent . ?x ub:takesCourse <http://www.Department0.University0.edu/GraduateCourse0> . }
};
ECHO BOTH $IF $EQU $ROWCNT 4 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Q10 returned " $ROWCNT " rows\n";

-- Q11
sparql prefix ub: <http://www.lehigh.edu/~zhp2/2004/0401/univ-bench.owl#> select * from <lubm> where { ?x a ub:ResearchGroup . ?x ub:subOrganizationOf <http://www.University0.edu> . };
ECHO BOTH $IF $EQU $ROWCNT 224 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Q11 returned " $ROWCNT " rows\n";

-- Q12
sparql prefix ub: <http://www.lehigh.edu/~zhp2/2004/0401/univ-bench.owl#> select * from <lubm> where
	{
	  { ?x a ub:FullProfessor . ?y a ub:Department . ?x ub:headOf ?y . ?y ub:subOrganizationOf <http://www.University0.edu> . }
	  union
	  { ?x a ub:AssistantProfessor . ?y a ub:Department . ?x ub:headOf ?y . ?y ub:subOrganizationOf <http://www.University0.edu> . }
	  union
	  { ?x a ub:AssociateProfessor . ?y a ub:Department . ?x ub:headOf ?y . ?y ub:subOrganizationOf <http://www.University0.edu> . }
	};
ECHO BOTH $IF $EQU $ROWCNT 15 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Q12 returned " $ROWCNT " rows\n";

-- Q13
sparql prefix ub: <http://www.lehigh.edu/~zhp2/2004/0401/univ-bench.owl#> select * from <lubm> where
{
{ ?x a ub:AssociateProfessor . ?x ub:doctoralDegreeFrom <http://www.University0.edu> . }
union
{ ?x a ub:FullProfessor . ?x ub:doctoralDegreeFrom <http://www.University0.edu> . }
union
{ ?x a ub:AssistantProfessor . ?x ub:doctoralDegreeFrom <http://www.University0.edu> . }
union
{ ?x a ub:Lecturer . ?x ub:doctoralDegreeFrom <http://www.University0.edu> . }
union
{ ?x a ub:UndergraduateStudent . ?x ub:doctoralDegreeFrom <http://www.University0.edu> . }
union
{ ?x a ub:GraduateStudent . ?x ub:doctoralDegreeFrom <http://www.University0.edu> . }
union
{ ?x a ub:TeachingAssistant . ?x ub:doctoralDegreeFrom <http://www.University0.edu> . }
union
{ ?x a ub:ResearchAssistant . ?x ub:doctoralDegreeFrom <http://www.University0.edu> . }

union


{ ?x a ub:AssociateProfessor . ?x ub:mastersDegreeFrom <http://www.University0.edu> . }
union
{ ?x a ub:FullProfessor . ?x ub:mastersDegreeFrom <http://www.University0.edu> . }
union
{ ?x a ub:AssistantProfessor . ?x ub:mastersDegreeFrom <http://www.University0.edu> . }
union
{ ?x a ub:Lecturer . ?x ub:mastersDegreeFrom <http://www.University0.edu> . }
union
{ ?x a ub:UndergraduateStudent . ?x ub:mastersDegreeFrom <http://www.University0.edu> . }
union
{ ?x a ub:GraduateStudent . ?x ub:mastersDegreeFrom <http://www.University0.edu> . }
union
{ ?x a ub:TeachingAssistant . ?x ub:mastersDegreeFrom <http://www.University0.edu> . }
union
{ ?x a ub:ResearchAssistant . ?x ub:mastersDegreeFrom <http://www.University0.edu> . }

union


{ ?x a ub:AssociateProfessor . ?x ub:undergraduateDegreeFrom <http://www.University0.edu> . }
union
{ ?x a ub:FullProfessor . ?x ub:undergraduateDegreeFrom <http://www.University0.edu> . }
union
{ ?x a ub:AssistantProfessor . ?x ub:undergraduateDegreeFrom <http://www.University0.edu> . }
union
{ ?x a ub:Lecturer . ?x ub:undergraduateDegreeFrom <http://www.University0.edu> . }
union
{ ?x a ub:UndergraduateStudent . ?x ub:undergraduateDegreeFrom <http://www.University0.edu> . }
union
{ ?x a ub:GraduateStudent . ?x ub:undergraduateDegreeFrom <http://www.University0.edu> . }
union
{ ?x a ub:TeachingAssistant . ?x ub:undergraduateDegreeFrom <http://www.University0.edu> . }
union
{ ?x a ub:ResearchAssistant . ?x ub:undergraduateDegreeFrom <http://www.University0.edu> . }

}

;
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Q13 returned " $ROWCNT " rows\n";

-- Q14
sparql prefix ub: <http://www.lehigh.edu/~zhp2/2004/0401/univ-bench.owl#> select * from <lubm> where { ?x a ub:UndergraduateStudent . };
ECHO BOTH $IF $EQU $ROWCNT 5916 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Q14 returned " $ROWCNT " rows\n";



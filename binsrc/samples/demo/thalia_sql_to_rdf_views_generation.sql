use DB;

create procedure DB.DBA.SPARQL_THALIA_RUN (in txt varchar)
{
  declare REPORT, stat, msg, sqltext varchar;
  declare metas, rowset any;
  result_names (REPORT);
  sqltext := string_output_string (sparql_to_sql_text (txt));
  stat := '00000';
  msg := '';
  rowset := null;
  exec (sqltext, stat, msg, vector (), 1000, metas, rowset);
  --result ('STATE=' || stat || ': ' || msg);
  --if (rowset is not null)
  --  {
  --    foreach (any r in rowset) do
  --      result (r[0] || ': ' || r[1]);
  --  }
}
;

use thalia;

DB.DBA.exec_no_error('drop View thalia.Demo.asu_v');
create View thalia.Demo.asu_v as select left(Title,3) code,* from thalia.Demo.asu;
DB.DBA.exec_no_error('drop View thalia.Demo.gatech_v');
create View thalia.Demo.gatech_v as select *, Room||' '||Building Place from thalia.Demo.gatech;

use DB;

DB.DBA.exec_no_error('GRANT \"SPARQL_UPDATE\" TO \"SPARQL\"');
GRANT SELECT ON thalia.Demo.asu TO "SPARQL";
GRANT SELECT ON thalia.Demo.asu_v TO "SPARQL";
GRANT SELECT ON thalia.Demo.brown TO "SPARQL";
GRANT SELECT ON thalia.Demo.cmu TO "SPARQL";
GRANT SELECT ON thalia.Demo.gatech TO "SPARQL";
GRANT SELECT ON thalia.Demo.gatech_v TO "SPARQL";
GRANT SELECT ON thalia.Demo.toronto TO "SPARQL";
GRANT SELECT ON thalia.Demo.ucsd TO "SPARQL";
GRANT SELECT ON thalia.Demo.umd TO "SPARQL";


DB.DBA.SPARQL_THALIA_RUN('drop quad map graph iri("http://^{URIQADefaultHost}^/Thalia") .
')
;

DB.DBA.SPARQL_THALIA_RUN('drop quad map graph iri("http://^{URIQADefaultHost}^/thalia") .
');

DB.DBA.SPARQL_THALIA_RUN('drop quad map virtrdf:ThaliaDemo .
');


DB.DBA.SPARQL_THALIA_RUN('
prefix oplsioc: <http://www.openlinksw.com/schemas/oplsioc#>
prefix sioc: <http://rdfs.org/sioc/ns#>
prefix xsd: <http://www.w3.org/2001/XMLSchema#>
prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#>
prefix owl: <http://www.w3.org/2002/07/owl#>
prefix dc: <http://purl.org/dc/elements/1.1/>
prefix time: <http://www.w3.org/2006/time#>
prefix event: <http://purl.org/NET/c4dm/event.owl#>
prefix geo: <http://www.w3.org/2003/01/geo/wgs84_pos#>
prefix foaf: <http://xmlns.com/foaf/0.1/>
prefix skos: <http://www.w3.org/2004/02/skos/core#>
prefix th: <http://purl.org/ontology/thalia/1.0/>

create iri class th:Asu "http://^{URIQADefaultHost}^/thalia/asu/course/%U#this" (in code varchar not null) .
create iri class th:Brown "http://^{URIQADefaultHost}^/thalia/brown/course/%U#this" (in Code varchar not null) .
create iri class th:BrownInstructor "http://^{URIQADefaultHost}^/thalia/brown/instructor/%U#this" (in Code varchar not null) .
create iri class th:BrownLecture "http://^{URIQADefaultHost}^/thalia/brown/lecture/%U#this" (in Code varchar not null) .
create iri class th:BrownPlace "http://^{URIQADefaultHost}^/thalia/brown/place/%U#this" (in Code varchar not null) .

create iri class th:Cmu "http://^{URIQADefaultHost}^/thalia/cmu/course/%U/%U#this" (in Code varchar not null, in Sec varchar) .
create iri class th:CmuInstructor "http://^{URIQADefaultHost}^/thalia/cmu/instructor/%U/%U#this" (in Code varchar not null, in Sec varchar) .
create iri class th:CmuLecture "http://^{URIQADefaultHost}^/thalia/cmu/lecture/%U/%U#this" (in Code varchar not null, in Sec varchar) .
create iri class th:CmuPlace "http://^{URIQADefaultHost}^/thalia/cmu/place/%U/%U#this" (in Code varchar not null, in Sec varchar) .
create iri class th:CmuEventTime "http://^{URIQADefaultHost}^/thalia/cmu/eventtime/%U/%U#this" (in Code varchar not null, in Sec varchar) .
create iri class th:CmuDatetime "http://^{URIQADefaultHost}^/thalia/cmu/datetime/%U/%U#this" (in Code varchar not null, in Sec varchar) .

create iri class th:Gatech "http://^{URIQADefaultHost}^/thalia/gatech/course/%U/%d/%U#this" (in Department varchar, in Code integer, in Section varchar) .
create iri class th:GatechInstructor "http://^{URIQADefaultHost}^/thalia/gatech/instructor/%U/%d/%U#this" (in Department varchar, in Code integer, in Section varchar) .
create iri class th:GatechLecture "http://^{URIQADefaultHost}^/thalia/gatech/lecture/%U/%d/%U#this" (in Department varchar, in Code integer, in Section varchar) .
create iri class th:GatechEventTime "http://^{URIQADefaultHost}^/thalia/gatech/eventtime/%U/%d/%U#this" (in Department varchar, in Code integer, in Section varchar) .
create iri class th:GatechDatetime "http://^{URIQADefaultHost}^/thalia/gatech/datetime/%U/%d/%U#this" (in Department varchar, in Code integer, in Section varchar) .
create iri class th:GatechPlace "http://^{URIQADefaultHost}^/thalia/gatech/place/%U/%d/%U#this" (in Department varchar, in Code integer, in Section varchar) .

create iri class th:Toronto "http://^{URIQADefaultHost}^/thalia/toronto/course/%U#this" (in No_ varchar) .
create iri class th:TorontoInstructor "http://^{URIQADefaultHost}^/thalia/toronto/instructor/%U#this" (in No_ varchar) .
create iri class th:TorontoLecture "http://^{URIQADefaultHost}^/thalia/toronto/lecture/%U#this" (in No_ varchar) .
create iri class th:TorontoPlace "http://^{URIQADefaultHost}^/thalia/toronto/place/%U#this" (in No_ varchar) .

create iri class th:Ucsd "http://^{URIQADefaultHost}^/thalia/ucsd/course/%U#this" (in Number varchar) .
create iri class th:UcsdInstructor1 "http://^{URIQADefaultHost}^/thalia/ucsd/instructor1/%U#this" (in Number varchar) .
create iri class th:UcsdInstructor2 "http://^{URIQADefaultHost}^/thalia/ucsd/instructor2/%U#this" (in Number varchar) .
create iri class th:UcsdInstructor3 "http://^{URIQADefaultHost}^/thalia/ucsd/instructor3/%U#this" (in Number varchar) .

create iri class th:Umd "http://^{URIQADefaultHost}^/thalia/umd/course/%U#this" (in Code varchar) .
create iri class th:UmdLecture "http://^{URIQADefaultHost}^/thalia/umd/lecture/%U#this" (in Code varchar) .
create iri class th:UmdEventTime "http://^{URIQADefaultHost}^/thalia/umd/eventtime/%U#this" (in Code varchar) .
create iri class th:UmdDatetime "http://^{URIQADefaultHost}^/thalia/umd/datetime/%U#this" (in Code varchar) .
')
;


DB.DBA.RDF_AUDIT_METADATA (1, '*');

DB.DBA.SPARQL_THALIA_RUN('prefix oplsioc: <http://www.openlinksw.com/schemas/oplsioc#>
prefix sioc: <http://rdfs.org/sioc/ns#>
prefix xsd: <http://www.w3.org/2001/XMLSchema#>
prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#>
prefix owl: <http://www.w3.org/2002/07/owl#>
prefix dc: <http://purl.org/dc/elements/1.1/>
prefix time: <http://www.w3.org/2006/time#>
prefix event: <http://purl.org/NET/c4dm/event.owl#>
prefix geo: <http://www.w3.org/2003/01/geo/wgs84_pos#>
prefix foaf: <http://xmlns.com/foaf/0.1/>
prefix skos: <http://www.w3.org/2004/02/skos/core#>
prefix th: <http://purl.org/ontology/thalia/1.0/>
alter quad storage virtrdf:DefaultQuadStorage
from thalia.demo.asu_v as asus
from thalia.demo.brown as browns
from thalia.demo.cmu as cmus
from thalia.demo.gatech_v as gatechs
from thalia.demo.toronto as torontos
from thalia.demo.ucsd as ucsds
from thalia.demo.umd as umds
{
        create virtrdf:ThaliaDemo as graph iri ("http://^{URIQADefaultHost}^/thalia") option (exclusive)
        {
                th:Asu (asus.code)
                	a th:Course
                		as virtrdf:Asu-Course ;
                	dc:title asus.Title
                		as virtrdf:Asu-Title ;
                	dc:description asus.Description
                		as virtrdf:Asu-Description ;
                	rdfs:seeAlso asus.MoreInfoURL
                		as virtrdf:Asu-MoreInfoURL ;
                        th:forUniversity "http://purl.org/thalia/university/asu"
                        	as virtrdf:Asu-University ;
                        skos:subject "http://purl.org/subject/thalia/ComputerScience"
                        	as virtrdf:Asu-Subject
                        	.

                th:Brown (browns.Code)
                        a th:Course
                                as virtrdf:Brown-Course ;
                        dc:title browns.Title
                        	as virtrdf:Brown-Title ;
                        th:hasInstructor th:BrownInstructor (browns.Code)
                        	as virtrdf:Brown-hasInstructor ;
                        th:hasLecture th:BrownLecture(browns.Code) 
                        	as virtrdf:Brown-hasLecture ;
                        th:forUniversity "http://purl.org/thalia/university/brown"
                        	as virtrdf:Brown-University ;
                        skos:subject "http://purl.org/subject/thalia/ComputerScience"
                        	as virtrdf:Brown-Subject
                        	.
                th:BrownInstructor (browns.Code)
                        a th:Instructor
                                as virtrdf:Brown-Instructor ;
                        dc:homepage browns.Instructor
                        	as virtrdf:Brown-Instructor-Homepage
                        	.
                th:BrownLecture (browns.Code)
                        a event:Event
                                as virtrdf:Brown-Lecture ;
                        event:place th:BrownPlace(browns.Code)
                        	as virtrdf:Brown-hasPlace
                        	.
                th:BrownPlace (browns.Code)
                        a geo:Point
                                as virtrdf:Brown-Place;
                        dc:title browns.Room
                        	as virtrdf:Brown-Room
                        	.

                th:Cmu (cmus.Code, cmus.Sec)
                	a th:Course
                		as virtrdf:Cmu-Course ;
                	dc:title cmus.CourseTitle
                		as virtrdf:Cmu-CourseTitle ;
                        th:hasInstructor th:CmuInstructor (cmus.Code, cmus.Sec)
                        	as virtrdf:Cmu-hasInstructor ;
                        th:hasLecture th:CmuLecture(cmus.Code, cmus.Sec) 
                        	as virtrdf:Cmu-hasLecture ;
                        th:hasUnits cmus.Units 
                        	as virtrdf:Cmu-hasUnits ;
                        th:forUniversity "http://purl.org/thalia/university/cmu"
                        	as virtrdf:Cmu-University ;
                        skos:subject "http://purl.org/subject/thalia/ComputerScience"
                        	as virtrdf:Cmu-Subject
                		.
		th:CmuInstructor (cmus.Code, cmus.Sec)
                        a th:Instructor
                                as virtrdf:Cmu-Instructor ;
                	foaf:name cmus.Lecturer
                		as virtrdf:Cmu-Lecturer
                        	.
		th:CmuLecture (cmus.Code, cmus.Sec)
                        a event:Event
                                as virtrdf:Cmu-Lecture ;
                        event:time th:CmuEventTime(cmus.Code, cmus.Sec)
                        	as virtrdf:Cmu-hasEventTime ;
                        event:place th:CmuPlace(cmus.Code, cmus.Sec)
                        	as virtrdf:Cmu-hasPlace
                        	.
		th:CmuPlace (cmus.Code, cmus.Sec)
                        a geo:Point
                                as virtrdf:Cmu-Place;
                        dc:title cmus.Room
                        	as virtrdf:Cmu-Room
                        	.
		th:CmuEventTime (cmus.Code, cmus.Sec)
                        a time:Interval
                                as virtrdf:Cmu-EventTime;
                        time:inDateTime th:CmuDatetime(cmus.Code, cmus.Sec)
                        	as virtrdf:Cmu-inDateTime
                        	.
		th:CmuDatetime (cmus.Code, cmus.Sec)
                        a time:DateTimeDescription
                                as virtrdf:Cmu-Datetime;
                	time:dayOfWeek cmus.Day_
                		as virtrdf:Cmu-Day ;
                	time:hour cmus.Time_
                		as virtrdf:Cmu-Time 
                        	.

                th:Gatech (gatechs.Department, gatechs.Code, gatechs.Section)
                	a th:Course
                		as virtrdf:Gatech-Course ;
                	dc:title gatechs.Title
                		as virtrdf:Gatech-Title ;
                        th:hasInstructor th:GatechInstructor(gatechs.Department, gatechs.Code, gatechs.Section)
                        	as virtrdf:Gatech-hasInstructor ;
                	dc:description gatechs.Description
                		as virtrdf:Gatech-Description ;
                        th:hasLecture th:GatechLecture(gatechs.Department, gatechs.Code, gatechs.Section)
                        	as virtrdf:Gatech-hasLecture ;
                        th:forUniversity "http://purl.org/thalia/university/gatech"
                        	as virtrdf:Gatech-University ;
                        skos:subject "http://purl.org/subject/thalia/ComputerScience"
                        	as virtrdf:Gatech-Subject
                        	.
		th:GatechInstructor (gatechs.Department, gatechs.Code, gatechs.Section)
                        a th:Instructor
                                as virtrdf:Gatech-Instructor ;
                	foaf:name gatechs.Instructor
                		as virtrdf:Gatech-InstructorName
				.
		th:GatechLecture (gatechs.Department, gatechs.Code, gatechs.Section)
                        a event:Event
                                as virtrdf:Gatech-Lecture ;
                        event:time th:GatechEventTime(gatechs.Department, gatechs.Code, gatechs.Section)
                        	as virtrdf:Gatech-hasEventTime ;
                        event:place th:GatechPlace(gatechs.Department, gatechs.Code, gatechs.Section)
                        	as virtrdf:Gatech-hasPlace
				.
		th:GatechEventTime (gatechs.Department, gatechs.Code, gatechs.Section)
                        a time:Interval
                                as virtrdf:Gatech-EventTime ;
                        time:inDateTime th:GatechDatetime(gatechs.Department, gatechs.Code, gatechs.Section)
                        	as virtrdf:Gatech-inDateTime
				.
		th:GatechDatetime (gatechs.Department, gatechs.Code, gatechs.Section)
                        a time:DateTimeDescription
                                as virtrdf:Gatech-Datetime ;
                	time:dayOfWeek gatechs.Days
                		as virtrdf:Gatech-Days ;
                	time:hour gatechs.Time_
                		as virtrdf:Gatech-Time_
				.
		th:GatechPlace (gatechs.Department, gatechs.Code, gatechs.Section)
                        a geo:Point
                                as virtrdf:Gatech-Place ;
                        dc:title gatechs.Place
                        	as virtrdf:Gatech-RoomBuilding
				.

                th:Toronto (torontos.No_)
                        a th:Course
                                as virtrdf:Toronto-Course ;
                        dc:title torontos.title
                        	as virtrdf:Toronto-Title ;
                        dc:description torontos.text_
                        	as virtrdf:Toronto-Description ;
                        th:hasInstructor th:TorontoInstructor(torontos.No_)
                        	as virtrdf:Toronto-hasInstructor ;
                        th:hasLecture th:TorontoLecture(torontos.No_)
                        	as virtrdf:Toronto-hasLecture ;
                        rdfs:seeAlso torontos.coursewebsite
                        	as virtrdf:Toronto-CourseWebSite ;
                        th:hasPrerequisite torontos.prereq
                        	as virtrdf:Toronto-prereq ;
                        th:text torontos.text_
                        	as virtrdf:Toronto-text;
                        th:forUniversity "http://purl.org/thalia/university/toronto"
                        	as virtrdf:Toronto-University ;
                        skos:subject "http://purl.org/subject/thalia/ComputerScience"
                        	as virtrdf:Toronto-Subject
                        	.
		th:TorontoInstructor (torontos.No_)
                        a th:Instructor
                                as virtrdf:Toronto-Instructor ;
                        foaf:name torontos.instructorName
                        	as virtrdf:Toronto-InstructorName ;
                        foaf:mbox torontos.instructorEmail
                        	as virtrdf:Toronto-InstructorEmail
				.
		th:TorontoLecture (torontos.No_)
                        a event:Event
                                as virtrdf:Toronto-Lecture ;
                        event:place th:TorontoPlace(torontos.No_)
                        	as virtrdf:Toronto-hasPlace
				.
		th:TorontoPlace (torontos.No_)
                        a geo:Point
                                as virtrdf:Toronto-Place ;
                        dc:title torontos.location
                        	as virtrdf:Toronto-Location
				.

                th:Ucsd (ucsds.Number)
                        a th:Course
                                as virtrdf:Ucsd-Course ;
                        dc:title ucsds.Title
                        	as virtrdf:Ucsd-Title ;
                        th:hasInstructor1 th:UcsdInstructor1 (ucsds.Number)
                        	as virtrdf:Ucsd-hasInstructor1 ;
                        th:hasInstructor2 th:UcsdInstructor2 (ucsds.Number)
                        	as virtrdf:Ucsd-hasInstructor2 ;
                        th:hasInstructor3 th:UcsdInstructor3 (ucsds.Number)
                        	as virtrdf:Ucsd-hasInstructor3 ;
                        th:forUniversity "http://purl.org/thalia/university/ucsd"
                        	as virtrdf:Ucsd-University ;
                        skos:subject "http://purl.org/subject/thalia/ComputerScience"
                        	as virtrdf:Ucsd-Subject
                        	.
                th:UcsdInstructor1 (ucsds.Number)
                        a th:Instructor
                                as virtrdf:Ucsd-Instructor1 ;
                        foaf:name ucsds.Fall2003
                        	as virtrdf:Ucsd-Instructor-Fall2003
                        	.
                th:UcsdInstructor2 (ucsds.Number)
                        a th:Instructor
                                as virtrdf:Ucsd-Instructor2 ;
                        foaf:name ucsds.Winter2004
                        	as virtrdf:Ucsd-Instructor-Winter2004
                        	.
                th:UcsdInstructor3 (ucsds.Number)
                        a th:Instructor
                                as virtrdf:Ucsd-Instructor3 ;
                        foaf:name ucsds.Spring2004
                        	as virtrdf:Ucsd-Instructor-Spring2004
                        	.

                th:Umd (umds.Code)
                	a th:Course
                		as virtrdf:Umd-Course ;
                	dc:title umds.CourseName
                		as virtrdf:Umd-Title ;
                        th:hasSection th:SectionTitle
                        	as virtrdf:Umd-hasSection ;
                        th:hasLecture th:UmdLecture(umds.Code)
                        	as virtrdf:Umd-hasLecture ;
                        th:forUniversity "http://purl.org/thalia/university/umd"
                        	as virtrdf:Umd-University ;
                        skos:subject "http://purl.org/subject/thalia/ComputerScience"
                        	as virtrdf:Umd-Subject
                        	.
		th:UmdLecture (umds.Code)
                        a event:Event
                                as virtrdf:Umd-Lecture ;
                        event:time th:UmdEventTime(umds.Code)
                        	as virtrdf:Umd-hasEventTime 
				.
		th:UmdEventTime (umds.Code)
                        a time:Interval
                                as virtrdf:Umd-EventTime ;
                        time:inDateTime th:UmdDatetime(umds.Code)
                        	as virtrdf:Umd-inDateTime
				.
		th:UmdDatetime (umds.Code)
                        a time:DateTimeDescription
                                as virtrdf:Umd-Datetime ;
                	time:hour umds.SectionTime
                		as virtrdf:Umd-SectionTime
				.
        }
}
')
;

DB.DBA.RDF_AUDIT_METADATA (1, '*');


create procedure tut_th_rdf_doc (in path varchar)
{
  declare r any;
  r := regexp_match ('[^/]*\x24', path);
  return r||'#this';
};

create procedure tut_th_html_doc (in path varchar)
{
  declare r any;
  r := regexp_match ('[^/]*#', path);
  return subseq (r, 0, length (r)-1);
};

DB.DBA.URLREWRITE_CREATE_REGEX_RULE (
    'tut_th_rule2',
    1,
    '(/[^#]*)\x24',
    vector('path'),
    1,
    '/sparql?query=CONSTRUCT+{+%%3Chttp%%3A//^{URIQADefaultHost}^%U%%23this%%3E+%%3Fp+%%3Fo+}+FROM+%%3Chttp%%3A//^{URIQADefaultHost}^/Thalia%%3E+WHERE+{+%%3Chttp%%3A//^{URIQADefaultHost}^%U%%23this%%3E+%%3Fp+%%3Fo+}&format=%U',
    vector('path', 'path', '*accept*'),
    null,
    '(text/rdf.n3)|(application/rdf.xml)',
    0,
    303
    );

DB.DBA.URLREWRITE_CREATE_REGEX_RULE (
    'tut_th_rule1',
    1,
    '(/[^#]*)\x24',
    vector('path'),
    1,
    '/isparql/execute.html?query=SELECT%%20%%3Fp%%20%%3Fo%%20FROM%%20%%3Chttp%%3A//^{URIQADefaultHost}^/Thalia%%3E%%20WHERE%%20{%%20%%3Chttp%%3A//^{URIQADefaultHost}^%U%%23this%%3E%%20%%3Fp%%20%%3Fo%%20}&endpoint=/sparql',
    vector('path'),
    null,
    '(text/html)|(\\*/\\*)',
    0,
    303
    );

DB.DBA.URLREWRITE_CREATE_RULELIST (
    'tut_th_rule_list1',
    1,
    vector (
                'tut_th_rule1',
                'tut_th_rule2'
          ));


DB.DBA.VHOST_REMOVE (lpath=>'/thalia');
DB.DBA.VHOST_DEFINE (lpath=>'/thalia', ppath=>'/DAV/Thalia/', is_dav=>1, vsp_user=>'dba', is_brws=>0, opts=>vector ('url_rewrite', 'tut_th_rule_list1'));

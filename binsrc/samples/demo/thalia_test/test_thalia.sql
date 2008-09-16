sparql
PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
PREFIX owl: <http://www.w3.org/2002/07/owl#>
PREFIX dc: <http://purl.org/dc/elements/1.1/>
PREFIX time: <http://www.w3.org/2006/time#>
PREFIX event: <http://purl.org/NET/c4dm/event.owl#>
PREFIX geo: <http://www.w3.org/2003/01/geo/wgs84_pos#>
PREFIX foaf: <http://xmlns.com/foaf/0.1/>
PREFIX skos: <http://www.w3.org/2004/02/skos/core#>
PREFIX th: <http://purl.org/ontology/thalia/1.0/>

SELECT distinct ?course
  from <http://localhost:8889/thalia>
	WHERE
	{
		?course a th:Course;
				th:hasInstructor ?instructor.
		?instructor foaf:name ?name.
		FILTER regex(?name, "Mark")
	}
;


sparql
PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
PREFIX owl: <http://www.w3.org/2002/07/owl#>
PREFIX dc: <http://purl.org/dc/elements/1.1/>
PREFIX time: <http://www.w3.org/2006/time#>
PREFIX event: <http://purl.org/NET/c4dm/event.owl#>
PREFIX geo: <http://www.w3.org/2003/01/geo/wgs84_pos#>
PREFIX foaf: <http://xmlns.com/foaf/0.1/>
PREFIX skos: <http://www.w3.org/2004/02/skos/core#>
PREFIX th: <http://purl.org/ontology/thalia/1.0/>

SELECT distinct ?course
  from <http://localhost:8889/thalia>
	WHERE
	{
		?course a th:Course;
			dc:title ?Title;
			th:hasLecture ?lecture.
		?lecture event:time [time:inDateTime ?dateTime].
		?dateTime time:hour ?hour.
		FILTER regex(?Title, "Database System")
		FILTER regex(?hour, "1:30 - 2:50")
	}
;


sparql
PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
PREFIX owl: <http://www.w3.org/2002/07/owl#>
PREFIX dc: <http://purl.org/dc/elements/1.1/>
PREFIX time: <http://www.w3.org/2006/time#>
PREFIX event: <http://purl.org/NET/c4dm/event.owl#>
PREFIX geo: <http://www.w3.org/2003/01/geo/wgs84_pos#>
PREFIX foaf: <http://xmlns.com/foaf/0.1/>
PREFIX skos: <http://www.w3.org/2004/02/skos/core#>
PREFIX th: <http://purl.org/ontology/thalia/1.0/>

SELECT DISTINCT ?course
  from <http://localhost:8889/thalia>
	WHERE
	{
		?course a th:Course;
				dc:title ?title;
				th:forUniversity 'http://purl.org/thalia/university/umd'.
		FILTER regex(?title, "Data Structures")
	}
;

sparql
PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
PREFIX owl: <http://www.w3.org/2002/07/owl#>
PREFIX dc: <http://purl.org/dc/elements/1.1/>
PREFIX time: <http://www.w3.org/2006/time#>
PREFIX event: <http://purl.org/NET/c4dm/event.owl#>
PREFIX geo: <http://www.w3.org/2003/01/geo/wgs84_pos#>
PREFIX foaf: <http://xmlns.com/foaf/0.1/>
PREFIX skos: <http://www.w3.org/2004/02/skos/core#>
PREFIX th: <http://purl.org/ontology/thalia/1.0/>

SELECT distinct ?course
  from <http://localhost:8889/thalia>
	WHERE
	{
		?course a th:Course;
			dc:title ?Title;
			th:hasUnits ?credits.
		FILTER (xsd:integer(?credits) > 10)
		FILTER regex(?Title, "Database")
	}
;


sparql
PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
PREFIX owl: <http://www.w3.org/2002/07/owl#>
PREFIX dc: <http://purl.org/dc/elements/1.1/>
PREFIX time: <http://www.w3.org/2006/time#>
PREFIX event: <http://purl.org/NET/c4dm/event.owl#>
PREFIX geo: <http://www.w3.org/2003/01/geo/wgs84_pos#>
PREFIX foaf: <http://xmlns.com/foaf/0.1/>
PREFIX skos: <http://www.w3.org/2004/02/skos/core#>
PREFIX th: <http://purl.org/ontology/thalia/1.0/>

SELECT distinct ?course
  from <http://localhost:8889/thalia>
	WHERE
	{
		?course a th:Course;
				dc:title ?title;
				th:forUniversity 'http://purl.org/thalia/university/umd'.
		FILTER regex(?title, "Database")
	}
;


sparql
PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
PREFIX owl: <http://www.w3.org/2002/07/owl#>
PREFIX dc: <http://purl.org/dc/elements/1.1/>
PREFIX time: <http://www.w3.org/2006/time#>
PREFIX event: <http://purl.org/NET/c4dm/event.owl#>
PREFIX geo: <http://www.w3.org/2003/01/geo/wgs84_pos#>
PREFIX foaf: <http://xmlns.com/foaf/0.1/>
PREFIX skos: <http://www.w3.org/2004/02/skos/core#>
PREFIX th: <http://purl.org/ontology/thalia/1.0/>

SELECT distinct ?text_
  from <http://localhost:8889/thalia>
	WHERE
	{
		?course a th:Course;
				dc:title ?title;
				th:text ?text_.
		FILTER regex(?title, "Verification")
	}
;


sparql
PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
PREFIX owl: <http://www.w3.org/2002/07/owl#>
PREFIX dc: <http://purl.org/dc/elements/1.1/>
PREFIX time: <http://www.w3.org/2006/time#>
PREFIX event: <http://purl.org/NET/c4dm/event.owl#>
PREFIX geo: <http://www.w3.org/2003/01/geo/wgs84_pos#>
PREFIX foaf: <http://xmlns.com/foaf/0.1/>
PREFIX skos: <http://www.w3.org/2004/02/skos/core#>
PREFIX th: <http://purl.org/ontology/thalia/1.0/>

SELECT distinct ?course
  from <http://localhost:8889/thalia>
	WHERE
	{
		?course a th:Course;
				dc:description ?description;
				th:forUniversity 'http://purl.org/thalia/university/gatech'.
		FILTER regex(?description, "JR")
	}
;


sparql
PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
PREFIX owl: <http://www.w3.org/2002/07/owl#>
PREFIX dc: <http://purl.org/dc/elements/1.1/>
PREFIX time: <http://www.w3.org/2006/time#>
PREFIX event: <http://purl.org/NET/c4dm/event.owl#>
PREFIX geo: <http://www.w3.org/2003/01/geo/wgs84_pos#>
PREFIX foaf: <http://xmlns.com/foaf/0.1/>
PREFIX skos: <http://www.w3.org/2004/02/skos/core#>
PREFIX th: <http://purl.org/ontology/thalia/1.0/>

SELECT distinct ?room
  from <http://localhost:8889/thalia>
	WHERE
	{
		?course a th:Course;
				dc:title ?title;
				th:hasLecture ?lecture.
		?lecture event:place [dc:title ?room].
		FILTER regex(?title, "Software Engineering")
	}
;


sparql
PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
PREFIX owl: <http://www.w3.org/2002/07/owl#>
PREFIX dc: <http://purl.org/dc/elements/1.1/>
PREFIX time: <http://www.w3.org/2006/time#>
PREFIX event: <http://purl.org/NET/c4dm/event.owl#>
PREFIX geo: <http://www.w3.org/2003/01/geo/wgs84_pos#>
PREFIX foaf: <http://xmlns.com/foaf/0.1/>
PREFIX skos: <http://www.w3.org/2004/02/skos/core#>
PREFIX th: <http://purl.org/ontology/thalia/1.0/>

SELECT distinct ?instructor
  from <http://localhost:8889/thalia>
	WHERE
	{
		?course a th:Course;
				dc:title ?title;
				th:hasInstructor ?instructor.
		FILTER regex(?title, "Software")
	}
;



sparql
PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
PREFIX owl: <http://www.w3.org/2002/07/owl#>
PREFIX dc: <http://purl.org/dc/elements/1.1/>
PREFIX time: <http://www.w3.org/2006/time#>
PREFIX event: <http://purl.org/NET/c4dm/event.owl#>
PREFIX geo: <http://www.w3.org/2003/01/geo/wgs84_pos#>
PREFIX foaf: <http://xmlns.com/foaf/0.1/>
PREFIX skos: <http://www.w3.org/2004/02/skos/core#>
PREFIX th: <http://purl.org/ontology/thalia/1.0/>

SELECT distinct ?instructor
  from <http://localhost:8889/thalia>
	WHERE
	{
		?course a th:Course;
				th:hasInstructor ?instructor;
				dc:title  ?title.
		FILTER regex(?title, "Database")
	}
;


sparql
PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
PREFIX owl: <http://www.w3.org/2002/07/owl#>
PREFIX dc: <http://purl.org/dc/elements/1.1/>
PREFIX time: <http://www.w3.org/2006/time#>
PREFIX event: <http://purl.org/NET/c4dm/event.owl#>
PREFIX geo: <http://www.w3.org/2003/01/geo/wgs84_pos#>
PREFIX foaf: <http://xmlns.com/foaf/0.1/>
PREFIX skos: <http://www.w3.org/2004/02/skos/core#>
PREFIX th: <http://purl.org/ontology/thalia/1.0/>

SELECT ?day, ?hour
  from <http://localhost:8889/thalia>
	WHERE
	{
		?course a th:Course;
				th:hasLecture [event:time ?time];
				dc:title ?title.
		?time time:inDateTime [time:dayOfWeek ?day];
			  time:inDateTime [time:hour ?hour].
		FILTER regex(?title, "Computer Networks")
	}
;


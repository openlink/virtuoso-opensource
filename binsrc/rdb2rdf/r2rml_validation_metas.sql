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


sparql clear graph <http://www.w3.org/ns/r2rml#OVL>
;

DB.DBA.TTLP ('
@prefix OVL: <http://www.openlinksw.com/schemas/OVL#> .
@prefix owl: <http://www.w3.org/2002/07/owl#> .
@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
@prefix rr: <http://www.w3.org/ns/r2rml#> .
@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .

rr: a OVL:ClosedWorldPrefix .

rr:child			a rdf:Property ; rdfs:domain rr:Join			; rdfs:range	xsd:string			; owl:minCardinality 1	; owl:maxCardinality 1	; rdfs:comment "Names a column in the child table of a join" .
rr:class			a rdf:Property ; rdfs:domain rr:SubjectMap		; rdfs:range	rdfs:Class			; owl:minCardinality 0	; OVL:maxGoodCard 10	; rdfs:comment "The subject value generated for a logical table row will be asserted as an instance of this RDFS class" .
rr:column			a rdf:Property ; rdfs:domain rr:OVL-G_S_P_O_Map		; rdfs:range	xsd:string			; owl:minCardinality 0	; owl:maxCardinality 1	; rdfs:comment "Name of a column in the logical table. When generating RDF triples from a logical table row, value from the specified column is used as the graph, subject, predicate, or object (based upon the specific domain)" .
rr:datatype			a rdf:Property ; rdfs:domain rr:ObjectMap		; rdfs:range	rdfs:Datatype			; owl:minCardinality 0	; owl:maxCardinality 1	; rdfs:comment "Specifies the datatype of the object component for the generated triple from a logical table row" .
rr:constant			a rdf:Property ; rdfs:domain rr:OVL-G_S_P_O_Map		; rdfs:range	rdfs:Resource			; owl:minCardinality 0	; owl:maxCardinality 1	; rdfs:comment "Specifies the datatype of the object component for the generated triple from a logical table row" .
rr:graph			a rdf:Property ; rdfs:domain rr:OVL-S_Po_Map		; rdfs:range	xsd:anyURI			; owl:minCardinality 0	; OVL:maxGoodCard 3	; rdfs:comment "Specifies a graph IRI reference. When used with a SubjectMap element, all the RDF triples generated from a logical row will be stored in the specified named graph. Otherwise, the RDF triple generated using the (predicate, object) pair will be stored in the specified named graph" .
rr:graphMap			a rdf:Property ; rdfs:domain rr:OVL-S_Po_Map		; rdfs:range	rr:GraphMap			; owl:minCardinality 0	; owl:maxGoodCard 10	; rdfs:comment "A GraphMap element to generate a graph from a logical table row" .
rr:inverseExpression		a rdf:Property ; rdfs:domain rr:OVL-G_S_P_O_Map		; rdfs:range	xsd:string			; owl:minCardinality 0	; owl:maxCardinality 1	; rdfs:comment "An expression that allows, at query processing time, use of index-based access to the the (underlying) relational tables, instead of simply retrieving the table rows first and then applying a filter. This property is useful for retrieval based on conditions involving graph, subject, predicate, or object generated from logical table column(s) and involves some transformation" .
rr:joinCondition		a rdf:Property ; rdfs:domain rr:RefObjectMap		; rdfs:range	rr:Join				; owl:minCardinality 1	; OVL:maxGoodCard 3	; rdfs:comment "Specifies the join condition for joining the child logical table with the parent logical table of the foreign key constraint" .
rr:language			a rdf:Property ; rdfs:domain rr:ObjectMap		; rdfs:range	xsd:string			; owl:minCardinality 0	; owl:maxCardinality 1	; rdfs:comment "Specifies the language for the object component for the generated triple from a logical table row" .
rr:logicalTable			a rdf:Property ; rdfs:domain rr:TriplesMap		; rdfs:range	rr:LogicalTable			; owl:minCardinality 1	; owl:maxCardinality 1	; rdfs:comment "Definition of logical table to be mapped" .
rr:object			a rdf:Property ; rdfs:domain rr:PredicateObjectMap	; rdfs:range	rdfs:Resource			; owl:minCardinality 0	; owl:maxCardinality 1	; rdfs:comment "Specifies the object for the generated triple from the logical table row" .
rr:objectMap			a rdf:Property ; rdfs:domain rr:PredicateObjectMap	; rdfs:range	rr:OVL-O_Ro_Map			; owl:minCardinality 0	; owl:maxCardinality 1	; rdfs:comment "An ObjectMap element to generate the object component of the (predicate, object) pair from a logical table row" .
rr:parent			a rdf:Property ; rdfs:domain rr:Join			; rdfs:range	xsd:string			; owl:minCardinality 1	; owl:maxCardinality 1	; rdfs:comment "Names a column in the parent table of a join" .
rr:parentTriplesMap		a rdf:Property ; rdfs:domain rr:RefObjectMap		; rdfs:range	rr:TriplesMap			; owl:minCardinality 1	; owl:maxCardinality 1	; rdfs:comment "Specifies the TriplesMap element corresponding to the parent logical table of the foreign key constraint" .
rr:predicate			a rdf:Property ; rdfs:domain rr:PredicateObjectMap	; rdfs:range	rdf:Property			; owl:minCardinality 0	; owl:maxCardinality 1	; rdfs:comment "Specifies the predicate for the generated triple from the logical table row" .
rr:predicateMap			a rdf:Property ; rdfs:domain rr:PredicateObjectMap	; rdfs:range	rr:PredicateMap			; owl:minCardinality 0	; owl:maxCardinality 1	; rdfs:comment "A PredicateMap element to generate the predicate component of the (predicate, object) pair from a logical table row" .
rr:predicateObjectMap		a rdf:Property ; rdfs:domain rr:TriplesMap		; rdfs:range	rr:PredicateObjectMap		; owl:minCardinality 0	; OVL:maxGoodCard 50	; rdfs:comment "A PredicateObjectMap element to generate (predicate, object) pair from a logical table row" .
rr:sqlQuery			a rdf:Property ; rdfs:domain rr:LogicalTable		; rdfs:range	xsd:string			; owl:minCardinality 0	; owl:maxCardinality 1	; rdfs:comment "A valid SQL query" .
rr:sqlVersion			a rdf:Property ; rdfs:domain rr:LogicalTable		; rdfs:range	xsd:string			; owl:minCardinality 0	; owl:maxCardinality 1	; rdfs:comment "SQL version identifier" .
rr:subject			a rdf:Property ; rdfs:domain rr:TriplesMap		; rdfs:range	OVL:anyREF			; owl:minCardinality 0	; owl:maxCardinality 1	; rdfs:comment "An IRI reference or a blank node for use as subject for all the RDF triples generated from a logical table row" .
rr:subjectMap			a rdf:Property ; rdfs:domain rr:TriplesMap		; rdfs:range	rr:SubjectMap			; owl:minCardinality 1	; owl:maxCardinality 1	; rdfs:comment "A SubjectMap element to generate a subject from a logical table row" .
rr:tableName			a rdf:Property ; rdfs:domain rr:LogicalTable		; rdfs:range	xsd:string			; owl:minCardinality 0	; owl:maxCardinality 1	; rdfs:comment "Name of a table or view" .
rr:tableOwner			a rdf:Property ; rdfs:domain rr:LogicalTable		; rdfs:range	xsd:string			; owl:minCardinality 0	; owl:maxCardinality 1	; rdfs:comment "Name of table owner" .
rr:tableSchema			a rdf:Property ; rdfs:domain rr:LogicalTable		; rdfs:range	xsd:string			; owl:minCardinality 0	; owl:maxCardinality 1	; rdfs:comment "Database schema name of table" .
rr:template			a rdf:Property ; rdfs:domain rr:OVL-G_S_P_O_Map		; rdfs:range	xsd:string			; owl:minCardinality 0	; owl:maxCardinality 1	; rdfs:comment "A template (format string) to specify how to generate a value for a subject, predicate, or object, using one or more columns from a logical table row" .
rr:termType			a rdf:Property ; rdfs:domain rr:OVL-S_O_Map		; rdfs:range	rr:OVL-termtype			; owl:minCardinality 0	; owl:maxCardinality 1	; rdfs:comment "A string indicating whether subject or object generated using the value from column name specified for rr:column should be an IRI reference, blank node, or (if object) a literal" .

rr:graphTemplate		a OVL:ObsoleteProperty ; rdfs:comment "Use rr:graph and rr:template intead" .
rr:termtype			a OVL:ObsoleteProperty ; rdfs:comment "Use rr:termType (with uppercase T) instead and replace ''IRI''/''BlankNode''/''Literal'' with rr:IRI/rr:BlankNode/rr:Literal" .
rr:useLogicalTable		a OVL:ObsoleteProperty ; rdfs:comment "Use rr:logicalTable instead" .
rr:useObjectMap			a OVL:ObsoleteProperty ; rdfs:comment "Use rr:objectMap instead" .
rr:usePredicateMap		a OVL:ObsoleteProperty ; rdfs:comment "Use rr:predicateMap instead" .
rr:usePredicateObjectMap	a OVL:ObsoleteProperty ; rdfs:comment "Use rr:predicateObjectMap instead" .
rr:useRefObjectMap		a OVL:ObsoleteProperty ; rdfs:comment "Use nodes of rr:RefObjectMap type instead" .
rr:useRefPredicateMap		a OVL:ObsoleteProperty ; rdfs:comment "Use nodes of rr:RefObjectMap type instead" .
rr:useRefPredicateObjectMap	a OVL:ObsoleteProperty ; rdfs:comment "Use nodes of rr:RefObjectMap type instead" .
rr:useSubjectMap		a OVL:ObsoleteProperty ; rdfs:comment "Use rr:subjectMap instead" .


rr:OVL-G_S_P_O_Map	OVL:superClassOf	rr:GraphMap,	rr:SubjectMap,	rr:PredicateMap,	rr:ObjectMap						.
rr:OVL-S_P_O_Map		OVL:superClassOf			rr:SubjectMap,	rr:PredicateMap,	rr:ObjectMap						.
rr:OVL-S_Po_Map		OVL:superClassOf			rr:SubjectMap,						rr:PredicateObjectMap			.
rr:OVL-S_O_Map		OVL:superClassOf			rr:SubjectMap,				rr:ObjectMap						.
rr:OVL-O_Ro_Map		OVL:superClassOf								rr:ObjectMap,				rr:RefObjectMap	.

rr:LogicalTable		OVL:superClassOf	rr:TriplesMap .

rr:OVL-termtype		OVL:enumOf		rr:IRI, rr:BlankNode, rr:Literal .

rr:TriplesMap		OVL:typeRestriction
	[ OVL:needSomeOfPredicates	rr:subject, rr:subjectMap ] .
rr:PredicateObjectMap	OVL:typeRestriction
	[ OVL:needSomeOfPredicates	rr:predicate, rr:predicateMap ] ,
	[ OVL:needSomeOfPredicates	rr:object, rr:objectMap ] .
rr:LogicalTable		OVL:typeRestriction
	[ 	OVL:mutuallyExclusivePredicates	rr:tableName, rr:sqlQuery ] ,
	[ 	OVL:mutuallyExclusivePredicates	rr:tableOwner, rr:sqlQuery ] .
OVL:anyREF		OVL:typeRestriction
	[ 	OVL:mutuallyExclusivePredicates	rr:constant, rr:column, rr:template ] ,
	[ 	OVL:mutuallyExclusivePredicates	rr:datatype, rr:language ] .
rr:OVL-G_S_P_O_Map	OVL:typeRestriction
	[ 	OVL:needSomeOfPredicates	rr:constant, rr:column, rr:template ] .

rr:logicalTable		a OVL:InferTypeFromRange .
rr:subjectMap		a OVL:InferTypeFromRange .
rr:predicateObjectMap	a OVL:InferTypeFromRange .
rr:predicateMap		a OVL:InferTypeFromRange .
rr:objectMap			a OVL:InferTypeFromRange .
rr:useRefPredicateObjectMap	a OVL:InferTypeFromRange .
rr:useRefPredicateMap		a OVL:InferTypeFromRange .
rr:useRefObjectMap		a OVL:InferTypeFromRange .
rr:joinCondition		a OVL:InferTypeFromRange .

rr:termType			OVL:inconsistencyOfPredicate """select ?s, ("Error") as ?severity,
  ("rr:Literal is not a valid value for rr:termType property of a rr:SubjectMap element") as ?message
  where {
      ?s a rr:SubjectMap ; rr:termType rr:Literal . }""" .
rr:datatype			OVL:inconsistencyOfPredicate """select ?s, ("Error") as ?severity,
  ("rr:datatype can be specified only if rr:termType is not an rr:IRI or rr:BlankNode") as ?message
  where {
     ?s a ?t ; rr:datatype ?dt .
     optional { ?s rr:termType ?tt } .
     filter ((bound (?tt) && (?tt != rr:Literal)) || (?t = rr:SubjectMap)) }""" .
rr:language			OVL:inconsistencyOfPredicate """select ?s, ("Error") as ?severity,
  ("rr:language can be specified only if rr:termType is not an rr:IRI or rr:BlankNode") as ?message
  where {
      ?s a ?t ; rr:language ?lang .
      optional { ?s rr:termType ?tt } .
      filter ((bound (?tt) && (?tt != rr:Literal)) || (?t = rr:SubjectMap)) }""" .
rr:tableName			OVL:inconsistencyOfPredicate """select ?lt, ("Warning") as ?severity,
  (if (bif:isnotnull (sql:R2RML_MAIN_KEY_EXISTS (?ts, ?to, ?tn, 1)),
      bif:concat ("rr:tableName refers to ", sql:R2RML_MAIN_KEY_EXISTS (?ts, ?to, ?tn, 1), " as to ",
        bif:sprintf ("%s.%s.%s", bif:coalesce (?to, "DB"), bif:coalesce (?ts, "DBA"), ?tn),
        ", i.e., using wrong character case ; adjust the R2RML or the table before generating an RDF View" ),
      "rr:tableName refers to table that does not exists ; adjust the R2RML or create the table before generating an RDF View" ) ) as ?message
  where {
      ?lt rr:tableName ?tn .
      OPTIONAL { ?lt rr:tableOwner ?to }
      OPTIONAL { ?lt rr:tableSchema ?ts }
      filter (bif:isnull (sql:R2RML_MAIN_KEY_EXISTS (?ts, ?to, ?tn, 0))) }""" .
rr:column			OVL:inconsistencyOfPredicate """select ?fldmap as ?s, ("Warning") as ?severity,
  (if (bif:isnotnull (sql:R2RML_KEY_COLUMN_EXISTS (?ts, ?to, ?tn, ?col, 1)),
      bif:concat ("rr:column refers to column ", ?col , " that is misspelled name of column ",
        sql:R2RML_KEY_COLUMN_EXISTS (?ts, ?to, ?tn, ?col, 1), " that the table ",
        sql:R2RML_MAIN_KEY_EXISTS (?ts, ?to, ?tn, 0), " contains now ; adjust the R2RML or the table before generating an RDF View" ),
      bif:concat ("rr:column refers to column ", ?col , " that is not found in table ",
        sql:R2RML_MAIN_KEY_EXISTS (?ts, ?to, ?tn, 0), " ; adjust the R2RML or the table before generating an RDF View" ) ) ) as ?message
  where {
      ?lt rr:tableName ?tn .
      OPTIONAL { ?lt rr:tableOwner ?to }
      OPTIONAL { ?lt rr:tableSchema ?ts }
      filter (bif:isnotnull (sql:R2RML_MAIN_KEY_EXISTS (?ts, ?to, ?tn, 0)))
      ?triplesmap a rr:TriplesMap ; rr:logicalTable ?lt .
        { ?triplesmap rr:subjectMap [ rr:graphMap ?fldmap ] }
      union
        { ?triplesmap rr:predicateObjectMap [ rr:graphMap ?fldmap ] }
      union
        { ?triplesmap rr:subjectMap ?fldmap }
      union
        { ?triplesmap rr:predicateObjectMap [ rr:predicateMap ?fldmap ] }
      union
        { ?triplesmap rr:predicateObjectMap [ rr:objectMap ?fldmap ] }
      ?fldmap rr:column ?col
      filter (bif:isnull (sql:R2RML_KEY_COLUMN_EXISTS (?ts, ?to, ?tn, ?col, 0))) }""" .
rr:parent			OVL:inconsistencyOfPredicate """select ?join as ?s, ("Warning") as ?severity,
  (if (bif:isnotnull (sql:R2RML_KEY_COLUMN_EXISTS (?ts, ?to, ?tn, ?col, 1)),
      bif:concat ("rr:parent refers to column ", ?col , " that is misspelled name of column ",
        sql:R2RML_KEY_COLUMN_EXISTS (?ts, ?to, ?tn, ?col, 1), " that the table ",
        sql:R2RML_MAIN_KEY_EXISTS (?ts, ?to, ?tn, 0), " contains now ; adjust the R2RML or the table before generating an RDF View" ),
      bif:concat ("rr:parent refers to column ", ?col , " that is not found in table ",
        sql:R2RML_MAIN_KEY_EXISTS (?ts, ?to, ?tn, 0), " ; adjust the R2RML or the table before generating an RDF View" ) ) ) as ?message
  where {
      ?lt rr:tableName ?tn .
      OPTIONAL { ?lt rr:tableOwner ?to }
      OPTIONAL { ?lt rr:tableSchema ?ts }
      filter (bif:isnotnull (sql:R2RML_MAIN_KEY_EXISTS (?ts, ?to, ?tn, 0)))
      ?ptriplesmap a rr:TriplesMap ; rr:logicalTable ?lt .
      ?objmap rr:parentTriplesMap ?ptriplesmap ; rr:joinCondition ?join .
      ?join rr:parent ?col .
      filter (bif:isnull (sql:R2RML_KEY_COLUMN_EXISTS (?ts, ?to, ?tn, ?col, 0))) }""" .
rr:child			OVL:inconsistencyOfPredicate """select ?join as ?s, ("Warning") as ?severity,
  (if (bif:isnotnull (sql:R2RML_KEY_COLUMN_EXISTS (?ts, ?to, ?tn, ?col, 1)),
      bif:concat ("rr:child refers to column ", ?col , " that is misspelled name of column ",
        sql:R2RML_KEY_COLUMN_EXISTS (?ts, ?to, ?tn, ?col, 1), " that the table ",
        sql:R2RML_MAIN_KEY_EXISTS (?ts, ?to, ?tn, 0), " contains now ; adjust the R2RML or the table before generating an RDF View" ),
      bif:concat ("rr:child refers to column ", ?col , " that is not found in table ",
        sql:R2RML_MAIN_KEY_EXISTS (?ts, ?to, ?tn, 0), " ; adjust the R2RML or the table before generating an RDF View" ) ) ) as ?message
  where {
      ?lt rr:tableName ?tn .
      OPTIONAL { ?lt rr:tableOwner ?to }
      OPTIONAL { ?lt rr:tableSchema ?ts }
      filter (bif:isnotnull (sql:R2RML_MAIN_KEY_EXISTS (?ts, ?to, ?tn, 0)))
      ?triplesmap a rr:TriplesMap ; rr:logicalTable ?lt ; rr:predicateObjectMap [ rr:objectMap ?objmap ] .
      ?objmap rr:joinCondition ?join .
      ?join rr:child ?col .
      filter (bif:isnull (sql:R2RML_KEY_COLUMN_EXISTS (?ts, ?to, ?tn, ?col, 0))) }""" .
', 'http://www.w3.org/ns/r2rml#OVL', 'http://www.w3.org/ns/r2rml#OVL')
;

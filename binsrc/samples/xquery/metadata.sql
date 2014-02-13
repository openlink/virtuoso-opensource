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
--  
create procedure "XQ"."XQ"."LIST_TEST_FILES" () returns any
{
  return vector (
    vector ( '20010215.xml'	, 'W3C Xml Query Use Cases 2001-02-15'		),
    vector ( '20010608.xml'	, 'W3C Xml Query Use Cases 2001-06-08'		),
    vector ( '20010608a1.xml'	, 'W3C Xml Query Use Cases 2001-06-08 patch a1'	),
    vector ( 'bib.dtd'		, '1.1.1. Use Case "XMP", Q1-Q12, DTD'		),
    vector ( 'bib.xml'		, '1.1.2. Use Case "XMP", Q1-Q12, data'		),
    vector ( 'reviews.dtd'	, '1.1.3. Use Case "XMP", Q5, DTD'		),
    vector ( 'reviews.xml'	, '1.1.4. Use Case "XMP", Q5, data'		),
    vector ( 'books.dtd'	, '1.1.5. Use Case "XMP", Q9, DTD'		),
    vector ( 'books.xml'	, '1.1.6. Use Case "XMP", Q9, data'		),
    vector ( 'prices.dtd'	, '1.1.7. Use Case "XMP", Q10, DTD'		),
    vector ( 'prices.xml'	, '1.1.8. Use Case "XMP", Q10, data'		),
    vector ( 'book.dtd'		, '1.2.2. Use Case "TREE", Q1-Q6, DTD'		),
    vector ( 'book.xml'		, '1.2.3. Use Case "TREE", Q1-Q6, obsolete'	),
    vector ( 'book1.xml'	, '1.2.3. Use Case "TREE", Q1-Q6, data'		),
    vector ( 'report.dtd'	, '1.3.2. Use Case "SEQ", Q1-Q5, DTD'		),
    vector ( 'report1.xml'	, '1.3.3. Use Case "SEQ", Q1-Q5, data'		),
    vector ( 'users.dtd'	, '1.4.2. Use Case "R", Q1-Q18, DTD'		),
    vector ( 'items.dtd'	, '1.4.2. Use Case "R", Q1-Q18, DTD'		),
    vector ( 'bids.dtd'		, '1.4.2. Use Case "R", Q1-Q18, DTD'		),
    vector ( 'bids.xml'		, '1.4.3. Use Case "R", Q1-Q18, data'		),
    vector ( 'users.xml'	, '1.4.3. Use Case "R", Q1-Q18, data'		),
    vector ( 'items.xml'	, '1.4.3. Use Case "R", Q1-Q18, data'		),
    vector ( 'sgml_report.dtd'	, '1.5.2. Use Case "SGML", Q1-Q10, DTD'		),
    vector ( 'sgml_intro.xml'	, '1.5.3. Use Case "SGML", Q1-Q10, data'	),
    vector ( 'company.dtd'	, '1.6.2. Use Case "NEWS", Q1-Q6, DTD'		),
    vector ( 'news.dtd'		, '1.6.2. Use Case "NEWS", Q1-Q6, DTD'		),
    vector ( 'company.xml'	, '1.6.3. Use Case "NEWS", Q1-Q6, data'		),
    vector ( 'news.xml'		, '1.6.3. Use Case "NEWS", Q1-Q6, data'		),
    vector ( 'auction.xml'	, '1.7.3. Use Case "NS", Q1-Q8, data'		),
    vector ( 'partlist.dtd'	, '1.8.2. Use Case "PARTS", Q1, DTD'		),
    vector ( 'parttree.dtd'	, '1.8.2. Use Case "PARTS", Q1, DTD'		),
    vector ( 'partlist.xml'	, '1.8.3. Use Case "PARTS", Q1, data'		),
    vector ( 'census.dtd'	, '1.9.2. Use Case "REF", Q1-Q11, DTD'		),
    vector ( 'census.xml'	, '1.9.3. Use Case "REF", Q1-Q11, data'		)
 );
};

-- First item of every vector specifies type of the row (or group of rows):
-- 0 = header of top-level group;
-- 1 = footer of top-level group;
-- 2 = top-level item: external URL to be opened instead of whole curent frameset;
-- 5 = external URL to be opened in new window;
-- 10 = group of use cases: title. mask for names of test cases, mask for comments of data files
create procedure "XQ"."XQ"."LIST_MENU_ITEMS"() returns any
{
  return vector (
    vector (2, 'Home', 'demo.vsp'),
    vector (2, 'FAQ', 'demo.vsp?desk=faq'),
    vector (2, 'Feedback', 'mailto:xquery@openlinksw.com'),
    vector (0, 'Specification'),
    vector (5, 'XQuery Language', 'http://www.w3c.org/TR/xquery'),
    vector (5, 'XQuery Use Cases', 'http://www.w3c.org/TR/xmlquery-use-cases'),
    vector (1),
    vector (0, 'W3C Use Cases'),
    vector (10, 'Use Case XMP'		, '1.1.9.%'	, '1.1.%'	),
    vector (10, 'Use Case TREE'		, '1.2.4.%'	, '1.2.%'	),
    vector (10, 'Use Case SEQ'		, '1.3.4.%'	, '1.3.%'	),
    vector (10, 'Use Case R'		, '1.4.4.%'	, '1.4.%'	),
    vector (10, 'Use Case SGML'		, '1.5.4.%'	, '1.5.%'	),
    vector (10, 'Use Case NEWS'		, '1.6.4.%'	, '1.6.%'	),
    vector (10, 'Use Case NS'		, '1.7.4.%'	, '1.7.%'	),
    vector (10, 'Use Case PARTS'	, '1.8.4.%'	, '1.8.%'	),
    vector (10, 'Use Case REF'		, '1.9.4.%'	, '1.9.%'	),
    vector (1),
    vector (0, 'About...'),
    vector (5, 'OpenLink Software', 'http://www.openlinksw.com'),
    vector (5, 'Virtuoso Server', 'http://www.openlinksw.com/virtuoso'),
    vector (1)
 );
};

create procedure "XQ"."XQ"."LIST_CASE_COMMENTS"() returns any
{
  return vector (
    vector ('1.1' , 'Use Case XMP'	, 'Experiences and Exemplars'		, 'Mary Fernandez, Jerome Simeon, Phil Wadler'	,
	'This use case contains several example queries that illustrate requirements gathered from the database and document communities.'
	),
    vector ('1.2' , 'Use Case TREE'	, 'Queries that preserve hierarchy'	, 'Jonathan Robie'	,
	'Some XML document-types have a very flexible structure in which text is mixed with elements and many elements are optional. These document-types show a wide variation in structure from one document to another. In documents of these types, the ways in which elements are ordered and nested are usually quite important.
An XML query language should have the ability to extract elements from documents while preserving their original hierarchy. This Use Case illustrates this requirement by means of a flexible document type named Book.'
	),
    vector ('1.3' , 'Use Case SEQ'	, 'Queries based on Sequence'		, 'Jonathan Robie'	,
	'This use case illustrates queries based on the sequence in which elements appear in a document.
Although sequence is not significant in most traditional database systems or object systems, it can be quite significant in structured documents. This use case presents a series of queries based on a medical report.'
	),
    vector ('1.4' , 'Use Case R'		, 'Access to Relational Data'		, 'Don Chamberlin'	,
	'One important use of an XML query language will be to access data stored in relational databases. This use case describes one possible way in which this access might be accomplished.
A relational database system might present a view in which each table (relation) takes the form of an XML document. One way to represent a database table as an XML document is to allow the document element to represent the table itself, and each row (tuple) inside the table to be represented by a nested element. Inside the tuple-elements, each column is in turn represented by a nested element. Columns that allow null values are represented by optional elements, and a missing element denotes a null value.
As an example, consider a relational database used by an online auction. The auction maintains a USERS table containing information on registered users, each identified by a unique userid, who can either offer items for sale or bid on items. An ITEMS table lists items currently or recently for sale, with the userid of the user who offered each item. A BIDS table contains all bids on record, keyed by the userid of the bidder and the item number of the item to which the bid applies.'
	),
    vector ('1.5' , 'Use Case SGML'	, 'Standard Generalized Markup Language' , 'Paula Angerstein'	,
	'The example document and queries in this Use Case were first created for a 1992 conference on Standard Generalized Markup Language (SGML).
For our use, the Document Type Definition (DTD) and example document have been translated from SGML to XML.'
	),
    vector ('1.6' , 'Use Case NEWS'	, 'Full-text Search'			, 'Umit Yalcinalp'	,
	'This use case is based on company profiles and a set of news documents which contain data for PR, mergers and acquisitions, etc.
Given a company, the use case illustrates several different queries for searching text in news documents and different ways of providing query results by matching the information from the company profile and the content of the news items. In this use case, searches for company names are to be interpreted as word-based searches. The words in a company name may be in any case and may be separated by any kind of white space.'
	),
    vector ('1.7' , 'Use Case NS'	, 'Queries Using Namespaces'		, 'Ingo Macherius'	,
	'This use case performs a variety of queries on namespace-qualified names.
This use case is based on a scenario in which a neutral mediator is acting with public auction servers on behalf of clients. The reason for a client to use this imaginary service may be anonymity, better insurance, or the possibility to cover more than one market at a time. The following aspects of namespaces are illustrated by this use case:
- Syntactic disambiguation when combining XML data from different sources
- Re-use of predefined modules, such as XLinks or XML Schema
- Support for global classification schemas, such as the Dublin Core
The sample data consists of two records. The schema used for this data uses W3C XML Schema''s schema composition to create a schema from predefined, namespace separated modules, and uses XLink to express references. Each record describes a running auction. It embeds data specific to an auctioneer (e.g. the company''s credit rating system) and a taxonomy specific to a particular good (jazz records) in a framework that contains data common to all auctions (e.g. start and end time), using namespaces to distinguish the three vocabularies.
Note that namespace prefixes must be resolved to their Namespace URIs before matching namespace qualified names. It is not sufficient to use the literal prefixes to denote namespaces. Furthermore, there are several possible ways to represent namespace declarations. Therefore, processing must be done on the namespace processed XML Information Set, not on the XML text representation.'
	),
    vector ('1.8' , 'Use Case PARTS'	, 'Recursive Parts Explosion'		, 'Michael Rys'	,
	'This use case illustrates how a recursive query might be used to construct a hierarchic document of arbitrary depth from flat structures stored in a database.
This use case is based on a "parts explosion" database that contains information about how parts are used in other parts.
The input to the use case is a "flat" document in which each different part is represented by a <part> element with partid and name attributes. Each part may or may not be part of a larger part; if so, the partid of the larger part is contained in a partof attribute. This input document might be derived from a relational database in which each part is represented by a row of a table with partid as primary key and partof as a foreign key referencing partid.
The challenge of this use case is to write a query that converts the "flat" representation of the parts explosion, based on foreign keys, into a hierarchic representation in which part containment is represented by the structure of the document.'
	),
    vector ('1.9' , 'Use Case REF'	, 'Queries based on References'		, 'Don Chamberlin' ,
	'References are an important aspect of XML. This use case describes a database in which references play a significant role, and contains several representative queries that exploit these references.
Suppose that the file "census.xml" contains an element for each person recorded in a recent census. For each person element, the person''s name, job, and spouse (if any) are recorded as attributes. The "spouse" attribute is an IDREF-type attribute that matches the ID-type "name" attribute of the spouse element.
The parent-child relationship among persons is recorded by containment in the element hierarchy. In other words, the element that represents a child is contained within the element that represents the child''s father or mother. Due to deaths, divorces, and remarriages, a child might be recorded under either its father or its mother (but not both). For the purposes of this exercise, the term "children of X" includes "children of the spouse of X." For example, if Joe and Martha are spouses, and Joe''s element contains an element Sam, and Martha''s element contains an element Dave, then Joe''s children are considered to be Sam and Dave, and Martha''s children are also considered to be Sam and Dave. Each person in the census has zero, one, or two parents.'
	),
    vector ('1.10' , 'Use Case FNPARM'	, 'Functions and Parameters'		, 'Don Chamberlin' ,
	'This use case explores some of the ways in which functions can be defined and invoked. It is based on examples taken from XML Schema Part 0: Primer , and relies in some cases on type and element definitions that are found in that document (referred to hereafter as the "Schema Primer".) Examples have been taken from the Schema Primer because the XML Query Working Group is committed to supporting queries based on the types and elements that can be defined using XML Schema. Only relevant parts of the type and element definitions are repeated in this use case--additional details can be found in the Schema Primer.
In general, this use case uses unqualified names for schema objects (for example, complexType and integer rather than xsd:complexType and xsd:integer). This corresponds to a strategy of using the schema namespace as the default namespace. Obviously, other strategies exist in which namespace prefixes would be used with names of schema objects. Since this use case is not primarily about namespaces, an effort has been made to keep namespace prefixes to a minimum.
This use case consists of several "subcases," each of which introduces a schema fragment and one or more functions that operate on data that conforms to the schema fragment. Each subcase explores a particular aspect of function definition and invocation.'
	)
  );
};


create procedure "XQ"."XQ"."EXTRACT_PORT_FROM_INI" ( )
{
  declare sect, item, item_value varchar;
  sect := 'HTTPServer';
  declare nitems, j integer;
  nitems := cfg_item_count(virtuoso_ini_path(), sect);

  j := 0;
  while (j < nitems)
    {
	item := cfg_item_name(virtuoso_ini_path(), sect, j);
	item_value := cfg_item_value(virtuoso_ini_path(), sect, item);
	if (equ(item,'ServerPort'))
	  return  item_value;
	j := j + 1;
    }
  return '6667';
}
;

create procedure "XQ"."XQ"."GET_DAV_DATA" (in name varchar) returns any
{
  declare data, resp any;
  declare h, req varchar;
  h := concat('http://localhost:', "XQ"."XQ"."EXTRACT_PORT_FROM_INI" (), '/DAV/', name);
  resp := null;
  req := 'GET';
  data := http_get (h); --, resp, req);
--  select RES_CONTENT into data from "WS"."WS"."SYS_DAV_RES" where "RES_FULL_PATH" = concat ('/DAV/',name);
  return data;
}
;

grant execute on "XQ"."XQ"."GET_DAV_DATA" to public;

--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2018 OpenLink Software
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
echo BOTH "STARTED: RDFa XHTML tests\n";
SET ARGV[0] 0;
SET ARGV[1] 0;

sparql define get:soft "replacing" select count(*)
from <http://localhost:$U{HTTPPORT}/xhtml1-testcases/0001.xhtml>
where
  {
    <http://localhost:$U{HTTPPORT}/xhtml1-testcases/photo1.jpg> <http://purl.org/dc/elements/1.1/creator> "Mark Birbeck" .
  };
-- RETURNS 1
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": 0001.xhtml\n";


sparql define get:soft "replacing" select count(*)
from <http://localhost:$U{HTTPPORT}/xhtml1-testcases/0002.xhtml>
where
  {
    <http://localhost:$U{HTTPPORT}/xhtml1-testcases/photo1.jpg> <http://purl.org/dc/elements/1.1/creator> "Mark Birbeck" .
  };
-- RETURNS 0
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": 0002.xhtml\n";

sparql define get:soft "replacing" select count(*)
from <http://localhost:$U{HTTPPORT}/xhtml1-testcases/0003.xhtml>
where
  {
    ?x0 <http://purl.org/dc/elements/1.1/creator> "Mark Birbeck" .
  };
-- RETURNS 0
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": 0003.xhtml\n";


sparql define get:soft "replacing" select count(*)
from <http://localhost:$U{HTTPPORT}/xhtml1-testcases/0004.xhtml>
where
  {
    ?x0 <http://purl.org/dc/elements/1.1/title> "Internet Applications" .
	<http://internet-apps.blogspot.com/> <http://purl.org/dc/elements/1.1/creator> <http://www.blogger.com/profile/1109404> .
  };
-- RETURNS 0
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": 0004.xhtml\n";


sparql define get:soft "replacing" select count(*)
from <http://localhost:$U{HTTPPORT}/xhtml1-testcases/0005.xhtml>
where
  {
    <http://localhost:$U{HTTPPORT}/xhtml1-testcases/0005.xhtml> <http://creativecommons.org/ns#license> <http://creativecommons.org/licenses/by/nc-nd/2.5/> .
  };
-- RETURNS 1
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": 0005.xhtml\n";


sparql define get:soft "replacing" select count(*)
from <http://localhost:$U{HTTPPORT}/xhtml1-testcases/0006.xhtml>
where
  {
    <http://www.blogger.com/profile/1109404> <http://xmlns.com/foaf/0.1/img> <http://localhost:$U{HTTPPORT}/xhtml1-testcases/photo1.jpg> .
    <http://localhost:$U{HTTPPORT}/xhtml1-testcases/photo1.jpg> <http://purl.org/dc/elements/1.1/creator> <http://www.blogger.com/profile/1109404> .
  };
-- RETURNS 0
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": 0006.xhtml\n";

sparql define get:soft "replacing" select count(*)
from <http://localhost:$U{HTTPPORT}/xhtml1-testcases/0007.xhtml>
where
  {
    <http://www.blogger.com/profile/1109404> <http://xmlns.com/foaf/0.1/img> <http://localhost:$U{HTTPPORT}/xhtml1-testcases/photo1.jpg> .
    <http://localhost:$U{HTTPPORT}/xhtml1-testcases/photo1.jpg> <http://purl.org/dc/elements/1.1/title> "Portrait of Mark" .
    <http://localhost:$U{HTTPPORT}/xhtml1-testcases/photo1.jpg> <http://purl.org/dc/elements/1.1/creator> <http://www.blogger.com/profile/1109404> .
  };
-- RETURNS 0
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": 0007.xhtml\n";

sparql define get:soft "replacing" select count(*)
from <http://localhost:$U{HTTPPORT}/xhtml1-testcases/0008.xhtml>
where
 {
   <http://localhost:$U{HTTPPORT}/xhtml1-testcases/0008.xhtml> <http://creativecommons.org/ns#license> <http://creativecommons.org/licenses/by-nc-nd/2.5/> .
 };
-- RETURNS 1
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": 0008.xhtml\n";

sparql define get:soft "replacing" select count(*)
from <http://localhost:$U{HTTPPORT}/xhtml1-testcases/0009.xhtml>
where
 {
   <http://example.org/Person2> <http://xmlns.com/foaf/0.1/knows> <http://example.org/Person1> .
 };
-- RETURNS 0
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": 0009.xhtml\n";


sparql define get:soft "replacing" select count(*)
from <http://localhost:$U{HTTPPORT}/xhtml1-testcases/0010.xhtml>
where
 {
   <http://example.org/Person1> <http://xmlns.com/foaf/0.1/knows> <http://example.org/Person2> .
   <http://example.org/Person2> <http://xmlns.com/foaf/0.1/knows> <http://example.org/Person1> .
 };
-- RETURNS 0
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": 0010.xhtml\n";

-- XXX: the xmlliteral !!!
sparql define get:soft "replacing" select ?o
from <http://localhost:$U{HTTPPORT}/xhtml1-testcases/0011.xhtml>
where
 {
   <http://localhost:$U{HTTPPORT}/xhtml1-testcases/0011.xhtml> <http://purl.org/dc/elements/1.1/creator> "Albert Einstein" .
   <http://localhost:$U{HTTPPORT}/xhtml1-testcases/0011.xhtml> <http://purl.org/dc/elements/1.1/title> ?o .
 };
-- RETURNS 0
ECHO BOTH $IF $EQU $LAST[1] "E = mc<sup>2</sup>: The Most Urgent Problem of Our Time" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": 0011.xhtml\n";

sparql define get:soft "replacing" select count(*)
from <http://localhost:$U{HTTPPORT}/xhtml1-testcases/0012.xhtml>
where
 {
   <http://example.org/node> <http://example.org/property> "chat"@fr .
 };
-- RETURNS 0
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": 0012.xhtml\n";


sparql define get:soft "replacing" select count(*)
from <http://localhost:$U{HTTPPORT}/xhtml1-testcases/0013.xhtml>
where
 {
   <http://example.org/node> <http://example.org/property> "chat"@fr .
 };
-- RETURNS 0
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": 0013.xhtml\n";

sparql define get:soft "replacing" select count(*)
from <http://localhost:$U{HTTPPORT}/xhtml1-testcases/0014.xhtml>
where
 {
   <http://example.org/foo> <http://example.org/bar> "10"^^<http://www.w3.org/2001/XMLSchema#integer> .
 };
-- RETURNS 0
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": 0014.xhtml\n";

sparql define get:soft "replacing" select count(*)
from <http://localhost:$U{HTTPPORT}/xhtml1-testcases/0015.xhtml>
where
 {
   <http://localhost:$U{HTTPPORT}/xhtml1-testcases/0015.xhtml> <http://purl.org/dc/elements/1.1/creator> "Fyodor Dostoevsky" .
   <http://localhost:$U{HTTPPORT}/xhtml1-testcases/0015.xhtml> <http://purl.org/dc/elements/1.1/source> <urn:isbn:0140449132> .
 };
-- RETURNS 1
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": 0015.xhtml\n";


sparql define get:soft "replacing" select count(*)
from <http://localhost:$U{HTTPPORT}/xhtml1-testcases/0016.xhtml>
where
 {
   ?x0 <http://purl.org/dc/elements/1.1/creator> "Fyodor Dostoevsky" .
   ?x0 <http://purl.org/dc/elements/1.1/source> <urn:isbn:0140449132> .
 };
-- RETURNS 1
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": 0016.xhtml\n";

sparql define get:soft "replacing" select count(*)
from <http://localhost:$U{HTTPPORT}/xhtml1-testcases/0017.xhtml>
where
 {
   ?x0 <http://xmlns.com/foaf/0.1/mbox> <mailto:libby.miller@bristol.ac.uk> .
   ?x1 <http://xmlns.com/foaf/0.1/knows> ?x0 .
   ?x1 <http://xmlns.com/foaf/0.1/mbox> <mailto:daniel.brickley@bristol.ac.uk> .
 };
-- RETURNS 1
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": 0017.xhtml\n";

sparql define get:soft "replacing" select count(*)
from <http://localhost:$U{HTTPPORT}/xhtml1-testcases/0018.xhtml>
where
 {
   <http://localhost:$U{HTTPPORT}/xhtml1-testcases/photo1.jpg> <http://purl.org/dc/elements/1.1/creator> <http://www.blogger.com/profile/1109404> .
 };
-- RETURNS 1
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": 0018.xhtml\n";

sparql define get:soft "replacing" select count(*)
from <http://localhost:$U{HTTPPORT}/xhtml1-testcases/0019.xhtml>
where
 {
   <mailto:daniel.brickley@bristol.ac.uk> <http://xmlns.com/foaf/0.1/knows> <mailto:libby.miller@bristol.ac.uk> .
 };
-- RETURNS 0
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": 0019.xhtml\n";

sparql define get:soft "replacing" select count(*)
from <http://localhost:$U{HTTPPORT}/xhtml1-testcases/0020.xhtml>
where
 {
   <http://localhost:$U{HTTPPORT}/xhtml1-testcases/photo1.jpg> <http://purl.org/dc/elements/1.1/creator> "Mark Birbeck" .
 };
-- RETURNS 1
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": 0020.xhtml\n";

sparql define get:soft "replacing" select count(*)
from <http://localhost:$U{HTTPPORT}/xhtml1-testcases/0021.xhtml>
where
 {
   <http://localhost:$U{HTTPPORT}/xhtml1-testcases/0021.xhtml> <http://purl.org/dc/elements/1.1/creator> "Mark Birbeck" .
 };
-- RETURNS 1
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": 0021.xhtml\n";

sparql define get:soft "replacing" select count(*)
from <http://localhost:$U{HTTPPORT}/xhtml1-testcases/0022.xhtml>
where
 {
   <http://localhost:$U{HTTPPORT}/xhtml1-testcases/0022.xhtml#photo1> <http://purl.org/dc/elements/1.1/creator> "Mark Birbeck" .
 };
-- RETURNS 0
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": 0022.xhtml\n";

sparql define get:soft "replacing" select count(*)
from <http://localhost:$U{HTTPPORT}/xhtml1-testcases/0023.xhtml>
where
 {
   <http://localhost:$U{HTTPPORT}/xhtml1-testcases/0023.xhtml> <http://purl.org/dc/elements/1.1/creator> "Mark Birbeck" .
 };
-- RETURNS 0
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": 0023.xhtml\n";

sparql define get:soft "replacing" select count(*)
from <http://localhost:$U{HTTPPORT}/xhtml1-testcases/0024.xhtml>
where
 {
   <http://localhost:$U{HTTPPORT}/xhtml1-testcases/photo1.jpg> <http://purl.org/dc/elements/1.1/creator> "Mark Birbeck" .
 };
-- RETURNS 1
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": 0024.xhtml\n";

sparql define get:soft "replacing" select count(*)
from <http://localhost:$U{HTTPPORT}/xhtml1-testcases/0025.xhtml>
where
 {
   <http://localhost:$U{HTTPPORT}/xhtml1-testcases/0025.xhtml> <http://purl.org/dc/elements/1.1/creator> <http://localhost:$U{HTTPPORT}/xhtml1-testcases/0025.xhtml#me> .
   <http://localhost:$U{HTTPPORT}/xhtml1-testcases/0025.xhtml#me> <http://xmlns.com/foaf/0.1/mbox> <mailto:ben@adida.net> .
   <http://localhost:$U{HTTPPORT}/xhtml1-testcases/0025.xhtml#me> <http://xmlns.com/foaf/0.1/name> "Ben Adida" .
 };
-- RETURNS 0
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": 0025.xhtml\n";

sparql define get:soft "replacing" select count(*)
from <http://localhost:$U{HTTPPORT}/xhtml1-testcases/0026.xhtml>
where
 {
   <http://internet-apps.blogspot.com/> <http://purl.org/dc/elements/1.1/creator> "Mark Birbeck" .
 };
-- RETURNS 0
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": 0026.xhtml\n";


sparql define get:soft "replacing" select count(*)
from <http://localhost:$U{HTTPPORT}/xhtml1-testcases/0027.xhtml>
where
 {
   <http://internet-apps.blogspot.com/> <http://purl.org/dc/elements/1.1/creator> "Mark Birbeck" .
 };
-- RETURNS 0
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": 0027.xhtml\n";


sparql define get:soft "replacing" select count(*)
from <http://localhost:$U{HTTPPORT}/xhtml1-testcases/0028.xhtml>
where
 {
   <http://example.org/node> <http://example.org/property> "chat"@fr .
 };
-- RETURNS 0
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": 0028.xhtml\n";

sparql define get:soft "replacing" select count(*)
from <http://localhost:$U{HTTPPORT}/xhtml1-testcases/0029.xhtml>
where
 {
   <http://example.org/foo> <http://purl.org/dc/elements/1.1/creator> "Mark Birbeck"^^<http://www.w3.org/2001/XMLSchema#string> .
 };
-- RETURNS 0
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": 0029.xhtml\n";


sparql define get:soft "replacing" select count(*)
from <http://localhost:$U{HTTPPORT}/xhtml1-testcases/0030.xhtml>
where
 {
   <http://localhost:$U{HTTPPORT}/xhtml1-testcases/0030.xhtml> <http://creativecommons.org/ns#license> <http://creativecommons.org/licenses/by-nc-nd/2.5/> .
 };
-- RETURNS 1
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": 0030.xhtml\n";

ECHO BOTH "COMPLETED WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED: RDFa tests\n";

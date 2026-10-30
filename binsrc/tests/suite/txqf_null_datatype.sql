--
--  txqf_null_datatype.sql
--
--  __xqf_str_parse_to_rdf_box (value, datatype [, suppress_errors]) parses a
--  string into the native value of an XML Schema datatype.  It accepts NULL as
--  the datatype and passed it to strlen (), which cannot take a NULL.  A
--  datatype it cannot parse to gives NULL, so does a NULL one.
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2026 OpenLink Software
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

ECHO BOTH "STARTED: __xqf_str_parse_to_rdf_box with a NULL datatype\n";

select __xqf_str_parse_to_rdf_box ('42', 'http://www.w3.org/2001/XMLSchema#integer') + 1;
ECHO BOTH $IF $EQU $LAST[1] 43 "PASSED" "***FAILED";
ECHO BOTH ": guard, '42' parsed as xsd:integer, plus 1: " $LAST[1] "\n";

select isnull (__xqf_str_parse_to_rdf_box ('x', 'urn:txqf:not-xml-schema'));
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": guard, a datatype that is not XML Schema gives NULL: " $LAST[1] "\n";

select isnull (__xqf_str_parse_to_rdf_box ('x', NULL));
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": a NULL datatype gives NULL: " $LAST[1] "\n";

select isnull (__xqf_str_parse_to_rdf_box (NULL, NULL, 1));
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": a NULL value and a NULL datatype, errors suppressed: " $LAST[1] "\n";

sparql select count (*) where { bind (bif:__xqf_str_parse_to_rdf_box ('x', ?unbound) as ?r) filter (!bound (?r)) };
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": the same from SPARQL run by an SQL user, an unbound datatype: " $LAST[1] " row\n";

ECHO BOTH "COMPLETED: __xqf_str_parse_to_rdf_box with a NULL datatype\n";

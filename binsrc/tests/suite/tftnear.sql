--
--  tftnear.sql
--
--  Free-text: a phrase as an operand of NEAR.
--
--  The documented grammar (textexprsyntax) is
--    proximity_expr ::= word_expr | proximity_expr NEAR word_expr
--    word_expr      ::= word | '"' phrase '"'
--  so '"second request" NEAR FTC' is a valid query.  It matched nothing: a
--  phrase computes where it matches into the ranges of its first word, not
--  into its own, and the NEAR around it reads the phrase's own ranges, which
--  were empty.  'second NEAR FTC' and '"second request" AND FTC' worked.
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
--

ECHO BOTH "STARTED: free-text phrase inside NEAR (tftnear.sql)\n";

create table TFTNEAR (ID integer primary key, TXT varchar);
insert into TFTNEAR values (1, 'HSR filing for the Harrowgate acquisition; the FTC issued a second request in March.');
insert into TFTNEAR values (2, 'The FTC said nothing; a request was second-guessed later.');
insert into TFTNEAR values (3, 'A second request ' || repeat ('filler ', 150) || 'came from the FTC.');
create text index on TFTNEAR (TXT);

-- The IDs of the rows a free-text query matches, in order, space separated.
create function TFTNEAR_IDS (in qry varchar) returns varchar
{
  declare ids varchar;
  ids := '';
  for (select ID from TFTNEAR where contains (TXT, qry) order by ID) do
    ids := ids || case when ids = '' then '' else ' ' end || cast (ID as varchar);
  return ids;
}
;

--------------------------------------------------------------------------
-- 1. word NEAR word, phrase AND word: right before the fix (guards).
--    Row 3 has its phrase 150 words from FTC, beyond NEAR's 100.
--------------------------------------------------------------------------

select TFTNEAR_IDS ('second NEAR FTC');
ECHO BOTH $IF $EQU $LAST[1] "1 2" "PASSED" "***FAILED";
ECHO BOTH ": 'second NEAR FTC' matches rows " $LAST[1] "\n";

select TFTNEAR_IDS ('"second request" AND FTC');
ECHO BOTH $IF $EQU $LAST[1] "1 3" "PASSED" "***FAILED";
ECHO BOTH ": '\"second request\" AND FTC' matches rows " $LAST[1] "\n";

select TFTNEAR_IDS ('"second request" NEAR banana');
ECHO BOTH $IF $EQU $LAST[1] "" "PASSED" "***FAILED";
ECHO BOTH ": '\"second request\" NEAR banana' matches no row, got [" $LAST[1] "]\n";

--------------------------------------------------------------------------
-- 2. a phrase as an operand of NEAR.
--------------------------------------------------------------------------

select TFTNEAR_IDS ('"second request" NEAR FTC');
ECHO BOTH $IF $EQU $LAST[1] "1" "PASSED" "***FAILED";
ECHO BOTH ": '\"second request\" NEAR FTC' matches row 1 (not 2, no phrase; not 3, too far), got [" $LAST[1] "]\n";

select TFTNEAR_IDS ('FTC NEAR "second request"');
ECHO BOTH $IF $EQU $LAST[1] "1" "PASSED" "***FAILED";
ECHO BOTH ": 'FTC NEAR \"second request\"' matches row 1, got [" $LAST[1] "]\n";

select TFTNEAR_IDS ('"second request" NEAR "FTC"');
ECHO BOTH $IF $EQU $LAST[1] "1" "PASSED" "***FAILED";
ECHO BOTH ": '\"second request\" NEAR \"FTC\"' matches row 1, got [" $LAST[1] "]\n";

select TFTNEAR_IDS ('"second request" NEAR "Harrowgate acquisition"');
ECHO BOTH $IF $EQU $LAST[1] "1" "PASSED" "***FAILED";
ECHO BOTH ": a phrase NEAR a phrase matches row 1, got [" $LAST[1] "]\n";

select TFTNEAR_IDS ('"second request" NEAR "request second"');
ECHO BOTH $IF $EQU $LAST[1] "" "PASSED" "***FAILED";
ECHO BOTH ": a phrase NEAR a phrase that is not in the text matches no row, got [" $LAST[1] "]\n";

select TFTNEAR_IDS ('"second request" NEAR filler NEAR FTC');
ECHO BOTH $IF $EQU $LAST[1] "" "PASSED" "***FAILED";
ECHO BOTH ": a phrase NEAR two words needs both near it, got [" $LAST[1] "]\n";

select TFTNEAR_IDS ('"second request" NEAR march NEAR FTC');
ECHO BOTH $IF $EQU $LAST[1] "1" "PASSED" "***FAILED";
ECHO BOTH ": '\"second request\" NEAR march NEAR FTC' matches row 1, got [" $LAST[1] "]\n";

--------------------------------------------------------------------------
-- 3. The same through SPARQL bif:contains on the RDF free-text index, as the
--    finding was reported.
--------------------------------------------------------------------------

DB.DBA.RDF_OBJ_FT_RULE_ADD (null, null, 'tftnear');
SPARQL CLEAR GRAPH <urn:tftnear:g>;
SPARQL INSERT INTO <urn:tftnear:g> { <urn:tftnear:m1> <urn:tftnear:note> "HSR filing for the Harrowgate acquisition; the FTC issued a second request in March." };
DB.DBA.VT_INC_INDEX_DB_DBA_RDF_OBJ ();

SPARQL SELECT COUNT (*) FROM <urn:tftnear:g> WHERE { ?m <urn:tftnear:note> ?t . ?t bif:contains '"second request" AND FTC' };
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": SPARQL bif:contains '\"second request\" AND FTC' matches the literal, got " $LAST[1] "\n";

SPARQL SELECT COUNT (*) FROM <urn:tftnear:g> WHERE { ?m <urn:tftnear:note> ?t . ?t bif:contains '"second request" NEAR FTC' };
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": SPARQL bif:contains '\"second request\" NEAR FTC' matches the literal, got " $LAST[1] "\n";

SPARQL CLEAR GRAPH <urn:tftnear:g>;
DB.DBA.RDF_OBJ_FT_RULE_DEL (null, null, 'tftnear');

ECHO BOTH "COMPLETED: free-text phrase inside NEAR (tftnear.sql)\n";

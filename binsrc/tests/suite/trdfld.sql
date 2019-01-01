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

ttlp (file_to_string ('tst.nq'), '', 'no-g', 512, transactional => 1, log_enable => 1);

sparql select count (*) from <g1> where {?s ?p ?o};

echo both $if $equ $last[1] 8 "PASSED" "***FAILED";
echo both ": 8 triples in g1\n";


sparql select * from <g1> where { ?s <only1> ?o . };
echo both $if $equ $last[2] only1  "PASSED" "***FAILED";
echo both ": only1\n";




ttlp (file_to_string ('tst2.nq'), '', 'no-g', 2048 + 512, transactional => 1, log_enable => 1);

sparql select * from <g1> where { ?s <only1> ?o . };
echo both $if $equ $rowcnt 0  "PASSED" "***FAILED";
echo both ": not only1\n";

sparql select * from <g1> where { ?s <only2> ?o . };
echo both $if $equ $last[2] only2  "PASSED" "***FAILED";
echo both ": only2\n";


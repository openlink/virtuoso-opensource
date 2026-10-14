--
--  tvvec_dot_product.sql
--
--  DOT_PRODUCT / INNER_PRODUCT / VECTOR_NORM.
--
--  Pure vector math over literal vectors: no model, no index, no ONNX, so this
--  runs in a default build where the rest of the vector chain is skipped.
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

select DOT_PRODUCT (vector (1.0, 2.0, 3.0), vector (4.0, 5.0, 6.0));
ECHO BOTH $IF $EQU $LAST[1] 32 "PASSED" "***FAILED";
ECHO BOTH ": DOT_PRODUCT (1,2,3).(4,5,6) = " $LAST[1] " expected 32\n";

select INNER_PRODUCT (vector (1.0, 2.0, 3.0), vector (4.0, 5.0, 6.0));
ECHO BOTH $IF $EQU $LAST[1] 32 "PASSED" "***FAILED";
ECHO BOTH ": INNER_PRODUCT is the same function under its other name = " $LAST[1] "\n";

select DOT_PRODUCT (vector (1.0, 0.0), vector (0.0, 1.0));
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": DOT_PRODUCT of orthogonal vectors = " $LAST[1] " expected 0\n";

select DOT_PRODUCT (vector (1.0, 2.0), vector (-1.0, -2.0));
ECHO BOTH $IF $EQU $LAST[1] -5 "PASSED" "***FAILED";
ECHO BOTH ": DOT_PRODUCT may be negative = " $LAST[1] " expected -5\n";

select VECTOR_NORM (vector (3.0, 4.0));
ECHO BOTH $IF $EQU $LAST[1] 5 "PASSED" "***FAILED";
ECHO BOTH ": VECTOR_NORM (3,4) = " $LAST[1] " expected 5\n";

select VECTOR_NORM (vector (0.0, 0.0));
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": VECTOR_NORM of a zero vector = " $LAST[1] " expected 0\n";

--  The identity that makes the pair useful: cosine similarity is the dot
--  product of the two vectors over the product of their norms.  Compared at
--  float precision against 1 - COSINE_DISTANCE, which computes it internally.
select case when abs ((DOT_PRODUCT (vector (1.0, 2.0), vector (3.0, 4.0))
                        / (VECTOR_NORM (vector (1.0, 2.0)) * VECTOR_NORM (vector (3.0, 4.0))))
                      - (1.0 - COSINE_DISTANCE (vector (1.0, 2.0), vector (3.0, 4.0)))) < 0.000001
            then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": dot/(norm*norm) agrees with 1 - COSINE_DISTANCE\n";

--  Mismatched dimensions must be refused, not silently truncated to the
--  shorter operand -- a wrong-but-plausible number here would be worse than
--  an error, because nothing downstream could tell it was wrong.
select DOT_PRODUCT (vector (1.0, 2.0), vector (1.0, 2.0, 3.0));
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": DOT_PRODUCT on mismatched dimensions refused STATE=" $STATE "\n";

--
--  tvvec_arithmetic.sql
--
--  Vector arithmetic: VVEC_ADD / SUBTRACT / MULTIPLY / DIVIDE, the scalar forms,
--  VVEC_NORMALIZE and VVEC_DIMENSION.
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

--  Elementwise results are read back through DOT_PRODUCT with a mask vector,
--  which both checks the arithmetic and proves the result box round-trips into
--  the other vector functions.

select VVEC_DIMENSION (VVEC_ADD (vector (1.0, 2.0, 3.0), vector (4.0, 5.0, 6.0)));
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
ECHO BOTH ": VVEC_ADD keeps the operand width = " $LAST[1] " expected 3\n";

select DOT_PRODUCT (VVEC_ADD (vector (1.0, 2.0, 3.0), vector (4.0, 5.0, 6.0)), vector (1.0, 1.0, 1.0));
ECHO BOTH $IF $EQU $LAST[1] 21 "PASSED" "***FAILED";
ECHO BOTH ": VVEC_ADD sum = " $LAST[1] " expected 21\n";

select DOT_PRODUCT (VVEC_SUBTRACT (vector (4.0, 5.0, 6.0), vector (1.0, 2.0, 3.0)), vector (1.0, 1.0, 1.0));
ECHO BOTH $IF $EQU $LAST[1] 9 "PASSED" "***FAILED";
ECHO BOTH ": VVEC_SUBTRACT sum = " $LAST[1] " expected 9\n";

select DOT_PRODUCT (VVEC_MULTIPLY (vector (2.0, 3.0), vector (4.0, 5.0)), vector (1.0, 1.0));
ECHO BOTH $IF $EQU $LAST[1] 23 "PASSED" "***FAILED";
ECHO BOTH ": VVEC_MULTIPLY is elementwise, sum = " $LAST[1] " expected 23\n";

select DOT_PRODUCT (VVEC_DIVIDE (vector (8.0, 9.0), vector (2.0, 3.0)), vector (1.0, 1.0));
ECHO BOTH $IF $EQU $LAST[1] 7 "PASSED" "***FAILED";
ECHO BOTH ": VVEC_DIVIDE is elementwise, sum = " $LAST[1] " expected 7\n";

select DOT_PRODUCT (VVEC_SCALAR_MULTIPLY (vector (1.0, 2.0), 3), vector (1.0, 1.0));
ECHO BOTH $IF $EQU $LAST[1] 9 "PASSED" "***FAILED";
ECHO BOTH ": VVEC_SCALAR_MULTIPLY sum = " $LAST[1] " expected 9\n";

select DOT_PRODUCT (VVEC_SCALAR_DIVIDE (vector (6.0, 9.0), 3), vector (1.0, 1.0));
ECHO BOTH $IF $EQU $LAST[1] 5 "PASSED" "***FAILED";
ECHO BOTH ": VVEC_SCALAR_DIVIDE sum = " $LAST[1] " expected 5\n";

select VECTOR_NORM (VVEC_NORMALIZE (vector (3.0, 4.0)));
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": VVEC_NORMALIZE yields unit length = " $LAST[1] " expected 1\n";

select VVEC_DIMENSION (vector (1.0, 2.0, 3.0, 4.0));
ECHO BOTH $IF $EQU $LAST[1] 4 "PASSED" "***FAILED";
ECHO BOTH ": VVEC_DIMENSION = " $LAST[1] " expected 4\n";

--  Normalising both operands turns the dot product into cosine similarity,
--  which is the composition these functions exist to make possible.
select case when abs (DOT_PRODUCT (VVEC_NORMALIZE (vector (1.0, 2.0)), VVEC_NORMALIZE (vector (3.0, 4.0)))
                      - (1.0 - COSINE_DISTANCE (vector (1.0, 2.0), vector (3.0, 4.0)))) < 0.000001
            then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": DOT_PRODUCT of normalised operands agrees with cosine similarity\n";

--  Division by zero and normalising a zero vector raise rather than producing
--  inf/NaN.  A NaN loose in a vector would not fail where it was made; it
--  would silently poison every later distance computation.
select VVEC_DIVIDE (vector (1.0, 2.0), vector (1.0, 0.0));
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": VVEC_DIVIDE by a zero element refused STATE=" $STATE "\n";

select VVEC_SCALAR_DIVIDE (vector (1.0, 2.0), 0);
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": VVEC_SCALAR_DIVIDE by zero refused STATE=" $STATE "\n";

select VVEC_NORMALIZE (vector (0.0, 0.0));
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": VVEC_NORMALIZE of a zero vector refused STATE=" $STATE "\n";

select VVEC_ADD (vector (1.0), vector (1.0, 2.0));
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": VVEC_ADD on mismatched dimensions refused STATE=" $STATE "\n";

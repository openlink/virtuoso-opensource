/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2016 OpenLink Software
 *
 *  This project is free software; you can redistribute it and/or modify it
 *  under the terms of the GNU General Public License as published by the
 *  Free Software Foundation; only version 2 of the License, dated June 1991.
 *
 *  This program is distributed in the hope that it will be useful, but
 *  WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 *  General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License along
 *  with this program; if not, write to the Free Software Foundation, Inc.,
 *  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
 *
 */

#include "geo.h"

#define p_	GEO_DE9IM_P_STAR
#define pF	GEO_DE9IM_P_F
#define p0	GEO_DE9IM_P_ZERO
#define p1	GEO_DE9IM_P_ONE
#define pT	GEO_DE9IM_P_T

#define GDS8(ii,ib,ie, bi,bb,be, ei,eb, first,second,dimrule) \
 { GEO_DE9IM_8CELLS(ii,ib,ie,bi,bb,be,ei,eb), GEO_DE9IM_##first, GEO_DE9IM_##second, (dimrule) }

#define GDSFILL GEO_DE9IM_SUBOP_FILLER

/* *INDENT-OFF* */

/*							      ii,ib,ie, bi,bb,be, ei,eb, #1,#2,rule */
geo_de9im_op_t geo_de9im_op_Equals =		{ 1, {	GDS8 (pT,p_,pF, p_,p_,pF, pF,pF, IE,EI,0),
							GDSFILL, GDSFILL, GDSFILL, GDSFILL} };

geo_de9im_op_t geo_de9im_op_Disjoint = 		{ 1, {	GDS8 (pF, pF, p_, pF, pF, p_, p_, p_, II, BB, 0),
							GDSFILL, GDSFILL, GDSFILL, GDSFILL} };

geo_de9im_op_t geo_de9im_op_Touches =		{ 3, {	GDS8 (pF,pT,p_, p_,p_,p_, p_,p_, II,IB,0),
							GDS8 (pF,p_,p_, pT,p_,p_, p_,p_, BI,BI,0),
							GDS8 (pF, p_, p_, p_, pT, p_, p_, p_, BB, BB, 0),
							GDSFILL, GDSFILL} };

geo_de9im_op_t geo_de9im_op_Contains = 		{ 1, {	GDS8 (pT, p_, p_, p_, p_, p_, pF, pF, II, EI, 0),
							GDSFILL, GDSFILL, GDSFILL, GDSFILL} };

geo_de9im_op_t geo_de9im_op_Covers =		{ 4, {	GDS8 (pT,p_,p_, p_,p_,p_, pF,pF, II,EI,0),
							GDS8 (p_,pT,p_, p_,p_,p_, pF,pF, IB,EB,0),
							GDS8 (p_,p_,p_, pT,p_,p_, pF,pF, BI,BI,0),
							GDS8 (p_, p_, p_, p_, pT, p_, pF, pF, BB, BB, 0),
							GDSFILL} };

geo_de9im_op_t geo_de9im_op_Intersects =	{ 4, {	GDS8 (pT,p_,p_, p_,p_,p_, p_,p_, II,II,0),
							GDS8 (p_,pT,p_, p_,p_,p_, p_,p_, IB,IB,0),
							GDS8 (p_,p_,p_, pT,p_,p_, p_,p_, BI,BI,0),
							GDS8 (p_, p_, p_, p_, pT, p_, p_, p_, BB, BB, 0),
							GDSFILL} };

geo_de9im_op_t geo_de9im_op_Within =		{ 1, {	GDS8 (pT,p_,pF, p_,p_,pF, p_,p_, II,IE,0),
							GDSFILL, GDSFILL, GDSFILL, GDSFILL} };

geo_de9im_op_t geo_de9im_op_CoveredBy =		{ 4, {	GDS8 (pT,p_,pF, p_,p_,pF, p_,p_, II,IE,0),
							GDS8 (p_,pT,pF, p_,p_,pF, p_,p_, IB,BE,0),
							GDS8 (p_,p_,pF, pT,p_,pF, p_,p_, BI,BI,0),
							GDS8 (p_, p_, pF, p_, pT, pF, p_, p_, BB, BB, 0),
							GDSFILL} };

geo_de9im_op_t geo_de9im_op_Crosses =		{ 3, {	GDS8 (pT,p_,pT, p_,p_,p_, p_,p_, II,IE,GEO_DE9IM_DIM_A_LT_B),
							GDS8 (pT,p_,p_, p_,p_,p_, pT,p_, EI,EI,GEO_DE9IM_DIM_A_GT_B),
							GDS8 (p0, p_, p_, p_, p_, p_, p_, p_, II, II, GEO_DE9IM_DIM_A_EQ_B_NEQ_2),
							 GDSFILL, GDSFILL} };

geo_de9im_op_t geo_de9im_op_Overlaps =		{ 2, {	GDS8 (pT,p_,pT, p_,p_,p_, pT,p_, II,IE,GEO_DE9IM_DIM_A_EQ_B_NEQ_1),
							GDS8 (p1, p_, pT, p_, p_, p_, pT, p_, EI, EI, GEO_DE9IM_DIM_BOTH_1),
							GDSFILL, GDSFILL, GDSFILL} };

/* *INDENT-ON* */

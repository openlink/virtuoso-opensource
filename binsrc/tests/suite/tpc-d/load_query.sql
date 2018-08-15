--  
--  $Id$
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
ECHO BOTH "STARTED: TPC-D queries\n";
__dbf_set ('qp_even_if_lock', 1);
__dbf_set ('enable_qp', 4);
__dbf_set ('qp_thread_min_usec', 0);

load Q1.sql;
load Q2.sql;
load Q3.sql;
load Q4.sql;
load Q5.sql;
load Q6.sql;
load Q7.sql;
load Q8.sql;
load Q9.sql;
load Q10.sql;
load Q11.sql;
load Q12.sql;
load Q13.sql;
load Q14.sql;
load Q15.sql;
load Q16.sql;
load Q17.sql;
load Q18.sql;
load Q19.sql;
load Q20.sql;
load Q21.sql;
load Q22.sql;

ECHO BOTH "COMPLETED: TPC-D queries \n\n";

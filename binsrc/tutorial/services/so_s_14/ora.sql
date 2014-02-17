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

CREATE OR REPLACE PROCEDURE get_emp_list (i_mask in varchar, result out varchar2)
IS
    CURSOR em_cur is SELECT ename, job, dname, loc
    FROM EMP, DEPT
    WHERE EMP.ENAME LIKE i_mask AND EMP.DEPTNO = DEPT.DEPTNO;

BEGIN
    result := '<?xml version="1.0" ?><remote>';
    FOR rec IN em_cur
	LOOP
	  result := result ||
	      '<record EENAME="' || rec.ename ||
	      '" EJOB="' || rec.job ||
	      '" DDNAME="' || rec.dname ||
	      '" DLOC="' || rec.loc || '" />';
	END LOOP;
        result := concat (result, '</remote>');
END get_emp_list;
/

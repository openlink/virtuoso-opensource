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
drop view OPENXMLV1;

DB.DBA.OPENXML_DEFINE ('OPENXMLV1',
                 null,
		 '<ROOT>
		     <Customer CustomerID="VINET" ContactName="Paul Henriot">
		      <Order CustomerID="VINET" EmployeeID="5" OrderDate="1996-07-04T00:00:00">
		        <OrderDetail OrderID="10248" ProductID="11" Quantity="12"/>
			<OrderDetail OrderID="10248" ProductID="42" Quantity="10"/>
		      </Order>
		     </Customer>
		     <Customer CustomerID="LILAS" ContactName="Carlos Gonzalez">
		     <Order CustomerID="LILAS" EmployeeID="3" OrderDate="1996-08-16T00:00:00">
		       <OrderDetail OrderID="10283" ProductID="72" Quantity="3"/>
		     </Order>
		    </Customer>
		  </ROOT>',
		  '/ROOT/Customer',
		  vector(
		          vector('CustomerID','nvarchar','@CustomerID'),
			  vector('ContactName','nvarchar','@ContactName')
			)
		  );

SELECT * FROM OPENXMLV1;


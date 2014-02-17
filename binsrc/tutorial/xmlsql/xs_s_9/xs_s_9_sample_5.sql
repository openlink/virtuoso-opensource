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
drop table DB.DBA.OPENXML_DATA;

drop view OPENXMLV2;

CREATE TABLE DB.DBA.OPENXML_DATA (ID INTEGER PRIMARY KEY, DT LONG VARCHAR);

INSERT INTO DB.DBA.OPENXML_DATA VALUES (1,
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
				    </ROOT>');


DB.DBA.OPENXML_DEFINE ('OPENXMLV2',
                'DB.DBA.OPENXML_DATA',
		'DT' ,
		'/ROOT/Customer',
		vector(
		   vector ('ID'),
		   vector('CustomerID','nvarchar','@CustomerID'),
		   vector('ContactName','nvarchar','@ContactName')
		   )
		);

SELECT * FROM OPENXMLV2;

--  
--  $Id$
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
create procedure 
xpath_2 ()
{
declare doc varchar;
declare idoc, res any;
declare i, l integer;
declare OrderID,CustomerID,OrderDate,ProductID,Quantity varchar;
    doc :='
	     <ROOT>
	     <Customer CustomerID="VINET" ContactName="Paul Henriot">
	     <Order OrderID="10248" CustomerID="VINET" EmployeeID="5" 
	     OrderDate="1996-07-04T00:00:00">
	     <OrderDetail ProductID="11" Quantity="12"/>
	     <OrderDetail ProductID="42" Quantity="10"/>
	     </Order>
	     </Customer>
	     <Customer CustomerID="LILAS" ContactName="Carlos Gonzalez">
	     <Order OrderID="10283" CustomerID="LILAS" EmployeeID="3" 
	     OrderDate="1996-08-16T00:00:00">
	     <OrderDetail ProductID="72" Quantity="3"/>
	     </Order>
	     </Customer>
	     </ROOT>';
    idoc := xml_tree_doc (doc);    
    res := xpath_eval ('/ROOT/Customer/Order/OrderDetail', idoc, 0);
    i := 0; l := length (res);
    result_names (OrderID,CustomerID,OrderDate,ProductID,Quantity);
    while (i < l)
      {
        OrderID := xpath_eval ('../@OrderID', res[i], 1);
        CustomerID := xpath_eval ('../@CustomerID', res[i], 1);
        OrderDate := xpath_eval ('../@OrderDate', res[i], 1);
        ProductID := xpath_eval ('@ProductID', res[i], 1);
        Quantity := xpath_eval ('@Quantity', res[i], 1);
        i := i + 1;      
	result (OrderID,CustomerID,OrderDate,ProductID,Quantity);   
      }
};

xpath_2 ();

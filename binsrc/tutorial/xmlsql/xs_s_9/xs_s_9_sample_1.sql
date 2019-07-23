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
xpath_1 ()
{
 declare doc varchar;
 declare idoc, res any;
 declare i, l integer;
 declare CustomerID, ContactName varchar;
    doc :='
    <ROOT>
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
    </ROOT>';
    idoc := xml_tree_doc (doc);    
--  SELECT xpath_eval ('/ROOT/Customer', idoc, 1) WITH (CustomerID  varchar(10), ContactName varchar(20))
    res := xpath_eval ('/ROOT/Customer', idoc, 0);
    i := 0; l := length (res);
    result_names (CustomerID, ContactName);
    while (i < l)
      {
        CustomerID := xpath_eval ('@CustomerID', res[i], 1);
        ContactName := xpath_eval ('@ContactName', res[i], 1);
        i := i + 1;      
	result (CustomerID, ContactName);   
      }
};

xpath_1 ();

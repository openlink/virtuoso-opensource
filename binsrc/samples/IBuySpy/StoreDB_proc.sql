--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2006 OpenLink Software
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

-- =============================================================
-- create the Stored procs
-- =============================================================

USE "Portal";

CREATE PROCEDURE 
ProductCategoryList ()
{
  declare CategoryID integer;
  declare CategoryName varchar(50);

  result_names (CategoryID, CategoryName);

  for (SELECT CategoryID as int_CategoryID, CategoryName as int_CategoryName 
	from Categories order by CategoryName asc) do
    {
      result (int_CategoryID, int_CategoryName);
    }

  end_result ();
}
;


CREATE PROCEDURE 
ProductsMostPopular ()
{
  declare ProductID, TotalNum integer;
  declare ModelName varchar (50);

  result_names (ProductID, TotalNum, ModelName);

  for (SELECT TOP 5 OrderDetails.ProductID as int_ProductID, SUM(OrderDetails.Quantity) as int_TotalNum, 
	Products.ModelName as int_ModelName from OrderDetails INNER JOIN Products
	ON OrderDetails.ProductID = Products.ProductID
	group by OrderDetails.ProductID, Products.ModelName order by int_TotalNum desc) do
    {
       result (int_ProductID, int_TotalNum, int_ModelName);
    }

  end_result ();  
}
;


CREATE PROCEDURE 
CustomerLogin (in in_Email varchar, in in_Password varchar, inout CustomerID integer)
{
  result_names (CustomerID);

  if (exists (SELECT 1 from Customers where EmailAddress = in_Email and "Password" = in_Password))
    {
	SELECT CustomerID into CustomerID   
	   from Customers where EmailAddress = in_Email and "Password" = in_Password;
    }
  else
    CustomerID := 0;

  result (CustomerID);
  end_result ();  
}
;


CREATE PROCEDURE 
CustomerAdd (in in_FullName varchar, in in_Email varchar, in in_Password varchar, in in_CustomerID integer)
{
  declare CustomerID integer;

  INSERT into Customers (FullName, EMailAddress, "Password")
    values (in_FullName, in_Email, in_Password);

  result_names (CustomerID);
  result (identity_value ());
  end_result ();
}
;


CREATE PROCEDURE 
ShoppingCartMigrate (in OriginalCartId varchar, in NewCartId varchar)
{
  UPDATE ShoppingCart set CartId = NewCartId where CartId = OriginalCartId;
}
;


CREATE PROCEDURE 
CustomerDetail (in in_CustomerID int, in in_FullName varchar, in in_Email varchar, in in_Password varchar)
{
  declare FullName, Email, "Password" varchar (50);

  result_names (FullName, Email, "Password");

  for (SELECT FullName as int_FullName, EmailAddress as int_EmailAddress, "Password" as int_Password
	from Customers WHERE CustomerID = in_CustomerID) do
    {
	result (int_FullName, int_EmailAddress, int_Password);
    }

  end_result (); 
}
;


CREATE PROCEDURE 
ProductDetail (in in_ProductID int, out UnitCost decimal, out ModelNumber varchar, out ModelName varchar,
    	       out ProductImage varchar, out Description varchar)
{

  SELECT ModelNumber, ModelName, ProductImage, UnitCost, Description 
     into ModelNumber, ModelName, ProductImage, UnitCost, Description
	 from Products where ProductID = in_ProductID;

}
;


CREATE PROCEDURE 
ShoppingCartItemCount (in in_CartID varchar, in in_ItemCount int)
{
  declare ItemCount integer;

  SELECT COUNT(ProductID) into ItemCount from ShoppingCart where CartID = in_CartID;

  result_names (ItemCount);
  result (ItemCount);
  end_result ();
}
;


CREATE PROCEDURE 
ProductsByCategory (in in_CategoryID int)
{

  declare ModelName, ProductImage varchar(50);
  declare UnitCost decimal (7,4);
  declare ProductID integer;

  result_names (ProductID, ModelName, UnitCost, ProductImage);

  for (SELECT ProductID as int_ProductID, ModelName as int_ModelName, 
	 UnitCost as int_UnitCost, ProductImage as int_ProductImage from Products
	   where CategoryID = in_CategoryID order by ModelName, ModelNumber) do
    {
	result (int_ProductID, int_ModelName, int_UnitCost, int_ProductImage);
    }
 
  end_result ();

}
;


CREATE PROCEDURE 
ShoppingCartAddItem (in in_ProductID int, in in_CartID varchar, in in_Quantity int)
{

   declare CountItems integer;

   SELECT Count(ProductID) into CountItems from ShoppingCart
	where ProductID = in_ProductID and CartID = in_CartID;

   IF (CountItems > 0 ) /* There are items - update the current quantity */
     UPDATE ShoppingCart SET Quantity = (in_Quantity + ShoppingCart.Quantity)
    	where ProductID = in_ProductID and CartID = in_CartID;

   else  /* New entry for this Cart.  Add a new record */

     INSERT into ShoppingCart (CartID, Quantity, ProductID)
    	values (in_CartID, in_Quantity, in_ProductID);

}
;


CREATE PROCEDURE 
ShoppingCartList (in in_CartID varchar)
{
  declare Quantity, ProductID integer;
  declare ModelName, ModelNumber varchar (50);
  declare UnitCost, ExtendedAmount float;

  result_names (Quantity, ProductID, ModelName, ModelNumber, UnitCost, ExtendedAmount);

  for (SELECT Products.ProductID as int_ProductID, Products.ModelName as int_ModelName, 
	 Products.ModelNumber as int_ModelNumber, ShoppingCart.Quantity as int_Quantity,
    	 Products.UnitCost as int_UnitCost, cast((Products.UnitCost * ShoppingCart.Quantity) as float) as int_ExtendedAmount
	from Products, ShoppingCart where Products.ProductID = ShoppingCart.ProductID 
	     and ShoppingCart.CartID = in_CartID 
	order by Products.ModelName, Products.ModelNumber) do
    {
	result (int_Quantity, int_ProductID, int_ModelName, int_ModelNumber, int_UnitCost, int_ExtendedAmount);
    }

  end_result ();
}
;


CREATE PROCEDURE 
ShoppingCartTotal (in in_CartID varchar, in in_TotalCost float)
{
  declare TotalCost decimal (8,3);

  SELECT SUM(Products.UnitCost * ShoppingCart.Quantity) into TotalCost
    from ShoppingCart, Products where ShoppingCart.CartID = in_CartID
     and Products.ProductID = ShoppingCart.ProductID;

  result_names (TotalCost);
  result (TotalCost);
  end_result ();
}
;


CREATE PROCEDURE 
OrdersAdd (in in_CustomerID int, in in_CartID varchar, in in_OrderDate datetime, 
	   in in_ShipDate datetime, in in_OrderID int)
{

  declare OrderID integer;

  INSERT into Orders (CustomerID, OrderDate, ShipDate)
    values (in_CustomerID, in_OrderDate, in_ShipDate);

   OrderID := identity_value ();

  INSERT into OrderDetails (OrderID, ProductID, Quantity, UnitCost)
    SELECT OrderID, ShoppingCart.ProductID, Quantity, Products.UnitCost
    from ShoppingCart INNER JOIN Products ON ShoppingCart.ProductID = Products.ProductID
    where CartID = in_CartID;

  ShoppingCartEmpty (in_CartId);

  result_names (OrderID);
  result (OrderID);
  end_result ();

}
;


CREATE PROCEDURE 
ShoppingCartEmpty (in in_CartID varchar)
{
  DELETE from ShoppingCart where CartID = in_CartID;
}
;


CREATE PROCEDURE 
ShoppingCartUpdate (in in_ProductID int, in in_CartID varchar, in in_Quantity int)
{
  UPDATE ShoppingCart set Quantity = in_Quantity
    where CartID = in_CartID and ProductID = in_ProductID;
}
;


CREATE PROCEDURE 
ShoppingCartRemoveItem ( in in_ProductID int, in in_CartID varchar)
{
  DELETE FROM ShoppingCart where CartID = in_CartID and ProductID = in_ProductID;
}
;


CREATE PROCEDURE 
ProductSearch (in in_Search varchar)
{

  declare ModelName, ModelNumber, ProductImage varchar (50);
  declare ProductID integer;
  declare UnitCost float;

  in_Search := concat ('%', in_Search, '%');

  result_names (ProductID, ModelName, ModelNumber, UnitCost, ProductImage);

  for (SELECT ProductID as int_ProductID, ModelName as int_ModelName,
    	 ModelNumber as int_ModelNumber, UnitCost as int_UnitCost, ProductImage as int_ProductImage
	 from Products where ModelNumber LIKE in_Search  
	 or ModelName LIKE in_Search or Description LIKE in_Search) do
      {
	result (int_ProductID, int_ModelName, int_ModelNumber, int_UnitCost, int_ProductImage);
      }

  end_result ();
}
;


CREATE PROCEDURE 
OrdersList (in in_CustomerID int)
{

  declare OrderID integer;
  declare OrderDate, ShipDate datetime;
  declare OrderTotal float;

  result_names (OrderID, OrderDate, ShipDate, OrderTotal);

  for (SELECT  
	Orders.OrderID as int_OrderID,
	Cast(sum(orderdetails.quantity*orderdetails.unitcost) as float) as int_OrderTotal,
	Orders.OrderDate as int_OrderDate, Orders.ShipDate as int_ShipDate
	  from Orders INNER JOIN OrderDetails on Orders.OrderID = OrderDetails.OrderID
	  group by CustomerID, Orders.OrderID, Orders.OrderDate, Orders.ShipDate
	  having Orders.CustomerID = in_CustomerID) do
    {
      result (int_OrderID, int_OrderDate, int_ShipDate, int_OrderTotal);
    }

  end_result ();
}
;


CREATE PROCEDURE 
OrdersDetail (in in_OrderID int, in in_CustomerID int, out in_OrderDate datetime,
	      out in_ShipDate datetime, out in_OrderTotal float)
{
  declare OrderDate, ShipDate, int_OrderDate, int_ShipDate datetime;
  declare OrderTotal float;
  declare Quantity, ProductID integer;
  declare ModelName, ModelNumber varchar (50);
  declare UnitCost, ExtendedAmount float;

  

  if (exists (SELECT 1 from Orders where OrderID = in_OrderID and CustomerID = in_CustomerID))
    {
       SELECT OrderDate, ShipDate into in_OrderDate, in_ShipDate    
	     from Orders where OrderID = in_OrderID and CustomerID = in_CustomerID;


       SELECT cast(SUM(OrderDetails.Quantity * OrderDetails.UnitCost) as float) into in_OrderTotal
	 from OrderDetails where OrderID = in_OrderID;

       result_names (Quantity, ProductID, ModelName, ModelNumber, UnitCost, ExtendedAmount);

       for (SELECT Products.ProductID as int_ProductID, Products.ModelName as int_ModelName,
		   Products.ModelNumber as int_ModelNumber, OrderDetails.UnitCost as int_UnitCost,
		   OrderDetails.Quantity as int_Quantity,
		   (OrderDetails.Quantity * OrderDetails.UnitCost) as int_ExtendedAmount
	    from OrderDetails INNER JOIN Products ON OrderDetails.ProductID = Products.ProductID
	    where OrderID = in_OrderID) do
	 {
	   result (int_Quantity, int_ProductID, int_ModelName, int_ModelNumber, int_UnitCost, int_ExtendedAmount);
	 }
    }

  end_result ();

}
;


CREATE PROCEDURE 
CustomerAlsoBought (in in_ProductID int)
{

  declare ModelName varchar (50);
  declare ProductID integer;
  declare TotalNum decimal;

  result_names (ModelName, ProductID, TotalNum);

  for (SELECT TOP 5  OrderDetails.ProductID as int_ProductID, Products.ModelName as int_ModelName ,
   	       SUM(OrderDetails.Quantity) as int_TotalNum from OrderDetails INNER JOIN Products 
   	on OrderDetails.ProductID = Products.ProductID where  OrderID IN 
           (SELECT DISTINCT OrderID from OrderDetails where ProductID = in_ProductID)
       and OrderDetails.ProductID <> in_ProductID 
       group by OrderDetails.ProductID, Products.ModelName 
       order by int_TotalNum desc ) do
       {
          result (int_ModelName, int_ProductID, int_TotalNum);
       }

  end_result ();

}
;


CREATE PROCEDURE 
ReviewsList (in in_ProductID int)
{
  declare CustomerName varchar (50);
  declare ReviewID, Rating integer;
  declare Comments varchar (3850);

  result_names (CustomerName,  ReviewID, Rating, Comments);

  for (SELECT ReviewID, CustomerName, Rating, Comments from Reviews where ProductID = in_ProductID) do
     {
        result (CustomerName,  ReviewID, Rating, Comments);
     }

 end_result ();

}
;


CREATE PROCEDURE 
ReviewsAdd (in ProductID int, in CustomerName nvarchar, in CustomerEmail nvarchar,
    	    in Rating integer, in Comments nvarchar(3850), out ReviewID integer)
{

  INSERT into Reviews (ProductID, CustomerName, CustomerEmail, Rating, Comments)
         values (ProductID, CustomerName, CustomerEmail, Rating, Comments);

  ReviewID := identity_value ();
}
;

CREATE PROCEDURE 
ShoppingCartRemoveAbandoned ()
{
  DELETE FROM ShoppingCart WHERE datediff ('day', DateCreated, GetDate()) > 1;
}
;


-- =======================================================
-- ADD SCHEDULED JOBS 
-- =======================================================

insert replacing DB.DBA.SYS_SCHEDULED_EVENT (SE_NAME, SE_START, SE_SQL, SE_INTERVAL)
	values ('Portal_ShoppingCartRemoveAbandoned', now(), 
		'Portal..ShoppingCartRemoveAbandoned ()', 24 * 60);
--
-- end scheduled jobs
-- 

create procedure DB.DBA.grant_select()
{
      DB.DBA.USER_CREATE ('SOAP', uuid(), vector ('DISABLED', 1));
      DB.DBA.user_set_qualifier('SOAP', 'WS');
}
;

DB.DBA.grant_select();
grant select on Demo.demo.Customers     to SOAP;
grant select on Demo.demo.Orders        to SOAP;
grant select on Demo.demo.Order_Details to SOAP;
grant select on Demo.demo.Products      to SOAP;
grant select on Demo.demo.Categories    to SOAP;


DB.DBA.exec_no_error ('drop procedure DB.DBA.grant_select');

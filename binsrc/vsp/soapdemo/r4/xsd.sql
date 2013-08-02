--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2013 OpenLink Software
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
-- schema definition

-- virtual directory setup
DB.DBA.USER_CREATE ('interop4xsd', uuid(), vector ('DISABLED', 1))
;

DB.DBA.user_set_qualifier ('interop4xsd', 'interop4xsd');


DB.DBA.VHOST_REMOVE (lpath=>'/r4/groupI')
;

DB.DBA.VHOST_DEFINE (lpath=>'/r4/groupI', ppath=>'/SOAP/', soap_user=>'interop4xsd',
    soap_opts => vector (
      'Namespace','http://soapinterop.org/','MethodInSoapAction','yes',
      'ServiceName', 'GroupIService', 'elementFormDefault', 'qualified'
      )
    )
;


-- methods

use interop4xsd;

-- simple types
create procedure
"echoVoid" (in parameters any __soap_type 'http://soapinterop.org/:echoVoid')
__soap_docw 'http://soapinterop.org/:echoVoidResponse'
{
  --dbg_obj_print (parameters);
  return parameters;
};


create procedure
"echoInteger" (in parameters any __soap_type 'http://soapinterop.org/:echoInteger')
__soap_docw 'http://soapinterop.org/:echoIntegerResponse'
{
  --dbg_obj_print (parameters);
  return parameters;
};

create procedure
"echoString" (in parameters any __soap_type 'http://soapinterop.org/:echoString')
__soap_docw 'http://soapinterop.org/:echoStringResponse'
{
  --dbg_obj_print (parameters);
  return parameters;
};

create procedure
"echoFloat" (in parameters any __soap_type 'http://soapinterop.org/:echoFloat')
__soap_docw 'http://soapinterop.org/:echoFloatResponse'
{
  --dbg_obj_print (parameters);
  return parameters;
};


create procedure
"echoBase64" (in parameters any __soap_type 'http://soapinterop.org/:echoBase64')
__soap_docw 'http://soapinterop.org/:echoBase64Response'
{
  --dbg_obj_print (parameters);
  return parameters;
};

create procedure
"echoDate" (in parameters any __soap_type 'http://soapinterop.org/:echoDate')
__soap_docw 'http://soapinterop.org/:echoDateResponse'
{
  --dbg_obj_print (parameters);
  return parameters;
};


create procedure
"echoDecimal" (in parameters any __soap_type 'http://soapinterop.org/:echoDecimal')
__soap_docw 'http://soapinterop.org/:echoDecimalResponse'
{
  --dbg_obj_print (parameters);
  return parameters;
};

create procedure
"echoBoolean" (in parameters any __soap_type 'http://soapinterop.org/:echoBoolean')
__soap_docw 'http://soapinterop.org/:echoBooleanResponse'
{
  --dbg_obj_print (parameters);
  return parameters;
};


create procedure
"echoHexBinary" (in parameters any __soap_type 'http://soapinterop.org/:echoHexBinary')
__soap_docw 'http://soapinterop.org/:echoHexBinaryResponse'
{
  --dbg_obj_print (parameters);
  return parameters;
};

-- arrays, and basic structs
create procedure
"echoComplexType" (in parameters any __soap_type 'http://soapinterop.org/:echoComplexType')
__soap_docw 'http://soapinterop.org/:echoComplexTypeResponse'
{
  --dbg_obj_print (parameters);
  return parameters;
};

create procedure
"echoIntegerMultiOccurs" (in parameters any __soap_type 'http://soapinterop.org/:echoIntegerMultiOccurs')
__soap_docw 'http://soapinterop.org/:echoIntegerMultiOccursResponse'
{
  --dbg_obj_print (parameters);
  return parameters[0];
};


create procedure
"echoStringMultiOccurs" (in parameters any __soap_type 'http://soapinterop.org/:echoStringMultiOccurs')
__soap_docw 'http://soapinterop.org/:echoStringMultiOccursResponse'
{
  --dbg_obj_print (parameters);
  return parameters[0];
};


create procedure
"echoFloatMultiOccurs" (in parameters any __soap_type 'http://soapinterop.org/:echoFloatMultiOccurs')
__soap_docw 'http://soapinterop.org/:echoFloatMultiOccursResponse'
{
  --dbg_obj_print (parameters);
  return parameters[0];
};

create procedure
"echoComplexTypeMultiOccurs" (in parameters any __soap_type 'http://soapinterop.org/:echoComplexTypeMultiOccurs')
__soap_docw 'http://soapinterop.org/:echoComplexTypeMultiOccursResponse'
{
  --dbg_obj_print (parameters);
  return parameters[0];
};

create procedure
"echoComplexTypeAsSimpleTypes" (
    in parameters any __soap_type 'http://soapinterop.org/:echoComplexTypeAsSimpleTypes'
    )
__soap_docw 'http://soapinterop.org/:echoComplexTypeAsSimpleTypesResponse'
{
  --dbg_obj_print (parameters);
  return soap_box_structure ('outputString', get_keyword ('varString', parameters[0]),
                             'outputInteger', get_keyword ('varInt', parameters[0]),
			     'outputFloat', get_keyword ('varFloat', parameters[0]));
};

create procedure
"echoSimpleTypesAsComplexType" (
    in parameters any __soap_type 'http://soapinterop.org/:echoSimpleTypesAsComplexType'
    )
__soap_docw 'http://soapinterop.org/:echoSimpleTypesAsComplexTypeResponse'
{
  --dbg_obj_print (parameters);
  return vector (soap_box_structure ('varString', get_keyword ('inputString', parameters),
                             'varInt', get_keyword ('inputInteger', parameters),
			     'varFloat', get_keyword ('inputFloat', parameters)));
};

create procedure
"echoNestedComplexType" (in parameters any __soap_type 'http://soapinterop.org/:echoNestedComplexType')
__soap_docw 'http://soapinterop.org/:echoNestedComplexTypeResponse'
{
  --dbg_obj_print (parameters);
  return parameters;
};

create procedure
"echoNestedMultiOccurs" (in parameters any __soap_type 'http://soapinterop.org/:echoNestedMultiOccurs')
__soap_docw 'http://soapinterop.org/:echoNestedMultiOccursResponse'
{
  --dbg_obj_print (parameters);
  return parameters;
};

-- special types
create procedure
"echoChoice" (in parameters any __soap_type 'http://soapinterop.org/:echoChoice')
__soap_docw 'http://soapinterop.org/:echoChoiceResponse'
{
  --dbg_obj_print (parameters);
  return parameters;
};

create procedure
"echoEnum" (in parameters any __soap_type 'http://soapinterop.org/:echoEnum')
__soap_docw 'http://soapinterop.org/:echoEnumResponse'
{
  --dbg_obj_print (parameters);
  return parameters;
};

create procedure
"echoAnyType" (in parameters any __soap_xml_type 'http://soapinterop.org/:echoAnyType')
__soap_docw 'http://soapinterop.org/:echoAnyTypeResponse'
{
  --dbg_obj_print (parameters);
  -- old behaviour, do not preserve NS of children elements
  --return parameters;
  declare xt any;
  xt := xml_tree_doc (parameters);
  if (not xslt_is_sheet ('__echoAnyType'))
  xslt_sheet ('__echoAnyType',
  xml_tree_doc(
  '<echoAnyTypeResponse xmlns="http://soapinterop.org/" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xsl:version="1.0" ><return><xsl:copy-of select="/echoAnyType/inputAnyType/@*|/echoAnyType/inputAnyType/*|/echoAnyType/inputAnyType/text()" /></return></echoAnyTypeResponse>'));
  return xslt ('__echoAnyType', xt);
};

create procedure
"echoAnyElement" (in parameters any __soap_type 'http://soapinterop.org/:echoAnyElement')
__soap_docw 'http://soapinterop.org/:echoAnyElementResponse'
{
  --dbg_obj_print (parameters);
  if (isarray (parameters) and length (parameters) and isarray(parameters[0]) and length (parameters[0]))
    return vector(vector(xml_tree_doc (parameters[0][0])));
  else
    return vector(vector());
};

create procedure
"RetAnyType" (in parameters any __soap_type 'http://soapinterop.org/:RetAnyType')
__soap_docw 'http://soapinterop.org/:RetAnyTypeResponse'
{
  --dbg_obj_print (parameters);
  --return parameters;
  declare xt any;
  xt := xml_tree_doc (parameters);
  if (not xslt_is_sheet ('__RetAnyType'))
  xslt_sheet ('__RetAnyType',
  xml_tree_doc(
  '<RetAnyTypeResponse xmlns="http://soapinterop.org/" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xsl:version="1.0" ><return><xsl:copy-of select="/RetAnyType/inputAnyType/@*|/RetAnyType/inputAnyType/*|/RetAnyType/inputAnyType/text()" /></return></RetAnyTypeResponse>'));
  return xslt ('__RetAnyType', xt);
};

create procedure
"RetAny" (in parameters any __soap_type 'http://soapinterop.org/:RetAny')
__soap_docw 'http://soapinterop.org/:RetAnyResponse'
{
  --dbg_obj_print (parameters);
  if (isarray (parameters) and length (parameters) and isarray(parameters[0]) and length (parameters[0]))
    return vector(vector(xml_tree_doc (parameters[0][0])));
  else
    return vector(vector());
};

create procedure
"echoVoidSoapHeader" (in parameters any __soap_type 'http://soapinterop.org:echoVoidSoapHeader',
    in echoMeComplexTypeRequest any := null __soap_header 'http://soapinterop.org/:echoMeComplexTypeRequest',
    out echoMeComplexTypeResponse any __soap_header 'http://soapinterop.org/:echoMeComplexTypeResponse',
    in echoMeStringRequest any := null __soap_header 'http://soapinterop.org/:echoMeStringRequest',
    out echoMeStringResponse any __soap_header 'http://soapinterop.org/:echoMeStringResponse'
    )
__soap_docw 'http://soapinterop.org/:echoVoidSoapHeaderResponse'
{
  --dbg_obj_print (parameters, echoMeStringRequest, echoMeComplexTypeRequest);
  if (echoMeStringRequest is not null)
    echoMeStringResponse := echoMeStringRequest;
  else if (echoMeComplexTypeRequest is not null)
    echoMeComplexTypeResponse := echoMeComplexTypeRequest;
  return parameters;
};


-- grants
grant execute on "echoVoid" to "interop4xsd";
grant execute on "echoInteger" to "interop4xsd";
grant execute on "echoString" to "interop4xsd";
grant execute on "echoFloat" to "interop4xsd";
grant execute on "echoBase64" to "interop4xsd";
grant execute on "echoDate" to "interop4xsd";
grant execute on "echoDecimal" to "interop4xsd";
grant execute on "echoBoolean" to "interop4xsd";
grant execute on "echoHexBinary" to "interop4xsd";

grant execute on "echoComplexType" to "interop4xsd";
grant execute on "echoIntegerMultiOccurs" to "interop4xsd";
grant execute on "echoStringMultiOccurs" to "interop4xsd";
grant execute on "echoFloatMultiOccurs" to "interop4xsd";
grant execute on "echoComplexTypeMultiOccurs" to "interop4xsd";
grant execute on "echoComplexTypeAsSimpleTypes" to "interop4xsd";
grant execute on "echoSimpleTypesAsComplexType" to "interop4xsd";
grant execute on "echoNestedComplexType" to "interop4xsd";
grant execute on "echoNestedMultiOccurs" to "interop4xsd";


grant execute on "echoChoice" to "interop4xsd";
grant execute on "echoEnum" to "interop4xsd";
grant execute on "echoAnyType" to "interop4xsd";
grant execute on "echoAnyElement" to "interop4xsd";
grant execute on "RetAnyType" to "interop4xsd";
grant execute on "RetAny" to "interop4xsd";
grant execute on "echoVoidSoapHeader" to "interop4xsd";

use DB;

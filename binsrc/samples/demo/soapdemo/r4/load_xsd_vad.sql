soap_load_sch (DB.DBA.get_blob_from_dav ('/DAV/VAD/demo/interop3/wsdl/r4/dime-doc.xsd'));
soap_load_sch (DB.DBA.get_blob_from_dav ('/DAV/VAD/demo/interop3/wsdl/r4/dime-rpc.xsd'));
soap_load_sch (DB.DBA.get_blob_from_dav ('/DAV/VAD/demo/interop3/wsdl/r4/simple-rpc-encoded.xsd'));
soap_load_sch (DB.DBA.get_blob_from_dav ('/DAV/VAD/demo/interop3/wsdl/r4/simple-doc-literal-1.xsd'));
soap_load_sch (DB.DBA.get_blob_from_dav ('/DAV/VAD/demo/interop3/wsdl/r4/simple-doc-literal-2.xsd'));
soap_load_sch (DB.DBA.get_blob_from_dav ('/DAV/VAD/demo/interop3/wsdl/r4/simple-doc-literal-3.xsd'));
soap_load_sch (DB.DBA.get_blob_from_dav ('/DAV/VAD/demo/interop3/wsdl/r4/complex-rpc-encoded.xsd'),
    vector ('http://soapinterop.org/types:SOAPStruct', 'DB.DBA.SOAPStruct',
      'http://soapinterop.org/types:SOAPStructFault','DB.DBA.SOAPStructFault',
      'http://soapinterop.org/types:BaseStruct','DB.DBA.BaseStruct',
      'http://soapinterop.org/types:ExtendedStruct','DB.DBA.ExtendedStruct',
      'http://soapinterop.org/types:MoreExtendedStruct','DB.DBA.MoreExtendedStruct'
      ));
soap_load_sch (DB.DBA.get_blob_from_dav ('/DAV/VAD/demo/interop3/wsdl/r4/round4xsd-1.xsd'));
soap_load_sch (DB.DBA.get_blob_from_dav ('/DAV/VAD/demo/interop3/wsdl/r4/round4xsd-2.xsd'));
soap_load_sch (DB.DBA.get_blob_from_dav ('/DAV/VAD/demo/interop3/wsdl/r4/round4xsd-3.xsd'));
soap_load_sch (DB.DBA.get_blob_from_dav ('/DAV/VAD/demo/interop3/wsdl/r4/round4xsd-4.xsd'));
soap_load_sch (DB.DBA.get_blob_from_dav ('/DAV/VAD/demo/interop3/wsdl/r4/complex-doc-1.xsd'),
    vector ('http://soapinterop.org/types:SOAPStruct', 'DB.DBA.SOAPStruct',
      'http://soapinterop.org/types:SOAPStructFault','DB.DBA.SOAPStructFault',
      'http://soapinterop.org/types:BaseStruct_literal','DB.DBA.BaseStruct_literal',
      'http://soapinterop.org/types:ExtendedStruct_literal','DB.DBA.ExtendedStruct_literal',
      'http://soapinterop.org/types:MoreExtendedStruct_literal','DB.DBA.MoreExtendedStruct_literal'
      ));
soap_load_sch (DB.DBA.get_blob_from_dav ('/DAV/VAD/demo/interop3/wsdl/r4/complex-doc-2.xsd'));
soap_load_sch (DB.DBA.get_blob_from_dav ('/DAV/VAD/demo/interop3/wsdl/r4/complex-doc-3.xsd'),
    vector (
    'http://soapinterop.org/types/requestresponse:echoSOAPStructFaultRequest', 'DB.DBA.SOAPStruct',
    'http://soapinterop.org/types/requestresponse:echoBaseStructFaultRequest', 'DB.DBA.BaseStruct_literal',
    'http://soapinterop.org/types/requestresponse:echoExtendedStructFaultRequest', 'DB.DBA.ExtendedStruct_literal',
    'http://soapinterop.org/types/requestresponse:echoMultipleFaults1Request_complex', 'DB.DBA.echoMultipleFaults1Request',
    'http://soapinterop.org/types/requestresponse:echoMultipleFaults2Request_complex', 'DB.DBA.echoMultipleFaults2Request'
      ));

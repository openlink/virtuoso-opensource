#!/bin/sh
#  
#  $Id$
#
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#
#  Copyright (C) 1998-2017 OpenLink Software
#
#  This project is free software; you can redistribute it and/or modify it
#  under the terms of the GNU General Public License as published by the
#  Free Software Foundation; only version 2 of the License, dated June 1991.
#  
#  This program is distributed in the hope that it will be useful, but
#  WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
#  General Public License for more details.
#  
#  You should have received a copy of the GNU General Public License along
#  with this program; if not, write to the Free Software Foundation, Inc.,
#  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
#  
# 
DSN=$PORT
. $VIRTUOSO_TEST/testlib.sh

#PARAMETERS FOR HTTP TEST
USERS=6
nreq=100
CLICKS=1000
THOST=localhost
TPORT=$HTTPPORT
HTTPPORT1=`expr $HTTPPORT + 1`
HTTPPORT2=`expr $HTTPPORT + 2`
#SERVER=M2		# OVERRIDE
BLOG_TEST=0 ### XXX: disabled as under not working
SYNCML_TEST=1


#PAGES FOR HTTP/1.0
H1=2 
#PAGES FOR HTTP/1.1
H2=2 
#PAGES FOR HTTP/1.0 & HTTP/1.1
H3=4

# BLOG2 tests
MAKE_VAD=yes

LOGFILE=`pwd`/thttp.output
export LOGFILE
. $VIRTUOSO_TEST/testlib.sh

do_mappers_only=0
if [ $# -ge 1 ]
then
    if [ "$1" = 'mappers' ]
    then
    do_mappers_only=1
    fi
fi

PLUGINDIR=${PLUGINDIR-$HOME/lib/}
export PLUGINDIR

SSL=`cat $HOME/Makeconfig | grep BUILD_OPTS | grep ssl`

#URI files 
GenURI10 () 
{
    ECHO "Creating uri file for HTTP/1.0 test"
    file=http10.uri
    cat > $file <<END_URI
$THOST $TPORT
$CLICKS GET /test.html HTTP/1.0
$CLICKS GET /test.vsp HTTP/1.0
END_URI
    chmod 644 $file
}

GenURI11 () 
{
    ECHO "Creating uri file for HTTP/1.1 test"
    file=http11.uri
    cat > $file <<END_URI
$THOST $TPORT
$CLICKS GET /test.html HTTP/1.1
$CLICKS GET /test.vsp HTTP/1.1
END_URI
    chmod 644 $file
}

GenURI1011 () 
{
    ECHO "Creating uri file for HTTP/1.0 & HTTP/1.1 test "
    file=http1011.uri
    cat > $file <<END_URI
$THOST $TPORT
$CLICKS GET /test.html HTTP/1.0
$CLICKS GET /test.vsp HTTP/1.0
$CLICKS GET /test.html HTTP/1.1
$CLICKS GET /test.vsp HTTP/1.1
END_URI
    chmod 644 $file
}

GenHTML () 
{
    ECHO "Creating HTML page for HTTP test"
    file=test.html
    cat > $file <<END_HTML
<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML//EN">

<html>
  <head>
    <title>OpenLink Virtuoso Server</title>
    <meta name="description" content="OpenLink Virtuoso Server">
  </head>
  <P>
  <A href=mime/mime_plain.vsp>MIME Messages</A>
  </P>
  <P>
  <A href=mime/mime_compose.vsp>MIME Composition</A>
  </P>
  <P>
  <A href=admin/admin_main.vsp>Virtuoso Administrator</A>
  </P>
  <P>
  <A href=soapdemo/SOAP.html>Sample SOAP page</A>
  </P>
  <P>
  <A href=vfs/vfs.html>Web copy</A>
  </P>
</html>
END_HTML
    chmod 644 $file
}

GenVSP () 
{
    ECHO "Creating VSP page for HTTP test"
    file=test.vsp
    cat > $file <<END_VSP
<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML//EN">

<html>
  <head>
    <title>OpenLink Virtuoso Server</title>
    <meta name="description" content="OpenLink Virtuoso Server">
  </head>
  <body>
<?vsp
http (cast (now () as varchar));
?>
  </body>
</html>
END_VSP
    chmod 644 $file
}

Gen404VSP () 
{
    ECHO "Creating 404 VSP page for HTTP test"
    file=404.vsp
cat > $file <<END_VSP
<h4>404 subst vsp</h4>
END_VSP
    chmod 644 $file
}
#SOAP data types
# XSD files generation
XSD_GENERATE()
{
rm -rf xsd  
mkdir xsd
cd xsd
cat > c1.xsd <<END_c1
<!-- struct containing an array of items  -->
<complexType name="POType"
   xmlns:enc="http://schemas.xmlsoap.org/soap/encoding/" 
   xmlns:wsdl="http://schemas.xmlsoap.org/wsdl/" 
   xmlns="http://www.w3.org/2001/XMLSchema"
   xmlns:tns="services.wsdl">
  <all>
    <element name="id" type="string"/>
    <element name="name" type="string"/>
    <element name="items">
    <complexType>
      <all>
        <element name="item" type="tns:Item" minOccurs="0" maxOccurs="unbounded"/>
      </all>                             
    </complexType>
    </element>
  </all>
</complexType>
END_c1

cat > c3.xsd <<END_c3
<!-- composite type  -->
<complexType name="Composite"
   xmlns:enc="http://schemas.xmlsoap.org/soap/encoding/" 
   xmlns:wsdl="http://schemas.xmlsoap.org/wsdl/" 
   xmlns="http://www.w3.org/2001/XMLSchema"
   xmlns:tns="services.wsdl">
<choice>
 <element name="PO" minOccurs="1" maxOccurs="1" type="tns:POType"/>
 <element name="Invoice" minOccurs="0" maxOccurs="unbounded" type="tns:InvoiceType"/>
</choice>
</complexType>
END_c3

cat > i1.xsd <<END_i1
<!-- array of strings  -->
<complexType name="ArrayOfstring"
   xmlns:enc="http://schemas.xmlsoap.org/soap/encoding/" 
   xmlns:wsdl="http://schemas.xmlsoap.org/wsdl/" 
   xmlns="http://www.w3.org/2001/XMLSchema"
   xmlns:tns="services.wsdl">
  <complexContent>
     <restriction base="enc:Array">
	<sequence>
	   <element name="item" type="string" minOccurs="0" maxOccurs="unbounded" nillable="true"/>
	</sequence>
	<attributeGroup ref="enc:commonAttributes"/>
	<attribute ref="enc:arrayType" wsdl:arrayType="string[]"/>
     </restriction>
  </complexContent>
</complexType>
END_i1

cat > i3.xsd <<END_i3
<!-- array of long -->
<complexType name="ArrayOflong"
   xmlns:enc="http://schemas.xmlsoap.org/soap/encoding/" 
   xmlns:wsdl="http://schemas.xmlsoap.org/wsdl/" 
   xmlns="http://www.w3.org/2001/XMLSchema"
   targetNamespace="services.wsdl"
   xmlns:tns="services.wsdl">

   <complexContent>
   <restriction base="enc:Array">
   <sequence>
   <element name="item" type="long" minOccurs="0" maxOccurs="unbounded" nillable="true"/>
   </sequence>
   <attribute ref="enc:arrayType" wsdl:arrayType="long[]"/>
   <attributeGroup ref="enc:commonAttributes"/>
   <attribute ref="enc:offset"/>
   </restriction>
   </complexContent>
</complexType>
END_i3

cat > i5.xsd <<END_i5
<!-- array of Structure -->
<complexType name="ArrayOfSOAPStruct"
   xmlns:enc="http://schemas.xmlsoap.org/soap/encoding/" 
   xmlns:wsdl="http://schemas.xmlsoap.org/wsdl/" 
   xmlns="http://www.w3.org/2001/XMLSchema"
   targetNamespace="services.wsdl"
   xmlns:tns="services.wsdl">

   <complexContent>
   <restriction base="enc:Array">
   <sequence>
   <element name="item" type="tns:SOAPStruct" minOccurs="0" maxOccurs="unbounded"/>
   </sequence>
   <attribute ref="enc:arrayType" wsdl:arrayType="tns:SOAPStruct[]"/>
   <attributeGroup ref="enc:commonAttributes"/>
   <attribute ref="enc:offset"/>
   </restriction>
   </complexContent>
</complexType>
END_i5

cat > m1.xsd <<END_m1
<!-- Person struct -->
<complexType name="PERSON"
   xmlns:enc="http://schemas.xmlsoap.org/soap/encoding/" 
   xmlns:wsdl="http://schemas.xmlsoap.org/wsdl/" 
   xmlns="http://www.w3.org/2001/XMLSchema"
   targetNamespace="services.wsdl"
   xmlns:tns="services.wsdl">

   <sequence>
     <element name="firstName" type="string"/>
     <element name="lastName" type="string"/>
     <element name="ageInYears" type="int"/>
     <element name="weightInLbs" type="float"/>
     <element name="heightInInches" type="float"/>
   </sequence>
</complexType>
END_m1

cat > m3.xsd <<END_m3
<!-- malePerson struct -->
<complexType name="malePerson"
   xmlns:enc="http://schemas.xmlsoap.org/soap/encoding/" 
   xmlns:wsdl="http://schemas.xmlsoap.org/wsdl/" 
   xmlns="http://www.w3.org/2001/XMLSchema"
   targetNamespace="services.wsdl"
   xmlns:tns="services.wsdl">

   <complexContent>
	    <extension base="tns:PERSON" >
	    <element name="favoriteShavingLotion" type="string" />
	    </extension>
   </complexContent>
</complexType>
END_m3

cat > mx1.xsd <<END_mx1
<!-- ArrayOfmyStruct complex definition od array and structure -->
<complexType name="ArrayOfmyStruct"
   xmlns:enc="http://schemas.xmlsoap.org/soap/encoding/" 
   xmlns:wsdl="http://schemas.xmlsoap.org/wsdl/" 
   xmlns="http://www.w3.org/2001/XMLSchema"
   targetNamespace="services.wsdl"
   xmlns:tns="services.wsdl">
   <complexContent>
     <restriction base="enc:Array">
        <sequence>
	  <element name="item">
            <complexType name="tns:myStruct">
	      <sequence>
	        <element name="fn" type="string"/>
	        <element name="sn" type="string"/>
	        <element name="age" type="int"/>
	      </sequence>
           </complexType>
	  </element>
	</sequence>
        <attribute ref="enc:arrayType" wsdl:arrayType="tns:myStruct[]" />
     </restriction>
   </complexContent>
</complexType>
END_mx1

cat > o2.xsd <<END_o2
<!-- no elements defined  -->
<complexType name="ArrayOfint3" 
   xmlns:enc="http://schemas.xmlsoap.org/soap/encoding/" 
   xmlns:wsdl="http://schemas.xmlsoap.org/wsdl/" 
   xmlns:tns="services.wsdl"
   targetNamespace="services.wsdl"
   xmlns="http://www.w3.org/2001/XMLSchema">
   <complexContent>
     <restriction base="enc:Array">
        <attribute ref="enc:arrayType" wsdl:arrayType="int[]" />
        <attribute ref="soapenc:offset"/>
     </restriction>
   </complexContent>
</complexType>
END_o2

cat > o4.xsd <<END_o4
<!-- extensons defined -->
<complexType name="ArrayOfint1" 
   xmlns:enc="http://schemas.xmlsoap.org/soap/encoding/" 
   xmlns:wsdl="http://schemas.xmlsoap.org/wsdl/" 
   targetNamespace="services.wsdl"
   xmlns="http://www.w3.org/2001/XMLSchema">
   <complexContent>
     <extension base="enc:Array">
        <sequence>
	  <element name="item" type="int" />
	</sequence>
        <attribute ref="enc:arrayType" wsdl:arrayType="int[]" />
        <attribute ref="soapenc:offset"/>
     </extension>
   </complexContent>
</complexType>
END_o4

cat > s1.xsd <<END_s1
<!-- enumeration type derived from string -->
<complexType name="Sex" 
   xmlns:enc="http://schemas.xmlsoap.org/soap/encoding/" 
   xmlns:wsdl="http://schemas.xmlsoap.org/wsdl/" 
   targetNamespace="services.wsdl"
   xmlns="http://www.w3.org/2001/XMLSchema">
    <simpleContent>
	<restriction base="string">
	    <enumeration value="Male" />
	    <enumeration value="Female" />
	</restriction>
    </simpleContent>
</complexType>
END_s1

cat > c2.xsd <<END_c2
<!-- simple structure  -->
<complexType name="Item"
   xmlns:enc="http://schemas.xmlsoap.org/soap/encoding/" 
   xmlns:wsdl="http://schemas.xmlsoap.org/wsdl/" 
   xmlns="http://www.w3.org/2001/XMLSchema"
   targetNamespace="services.wsdl"
   xmlns:tns="services.wsdl">
  <all>
    <element name="quantity" type="int"/>
    <element name="product" type="string"/>
  </all>
</complexType>
END_c2

cat > c4.xsd <<END_c4
<!-- simple structure w/h 1 element -->
<complexType name="InvoiceType"
   xmlns:enc="http://schemas.xmlsoap.org/soap/encoding/" 
   xmlns:wsdl="http://schemas.xmlsoap.org/wsdl/" 
   xmlns="http://www.w3.org/2001/XMLSchema"
   targetNamespace="services.wsdl"
   xmlns:tns="services.wsdl">
<all>
<element name="id" type="string"/>
</all>
</complexType>
END_c4

cat > i2.xsd <<END_i2
<!-- array of int -->
<complexType name="ArrayOfint"
   xmlns:enc="http://schemas.xmlsoap.org/soap/encoding/" 
   xmlns:wsdl="http://schemas.xmlsoap.org/wsdl/" 
   xmlns="http://www.w3.org/2001/XMLSchema"
   targetNamespace="services.wsdl"
   xmlns:tns="services.wsdl">
<complexContent>
<restriction base="enc:Array">
  <sequence>
    <element name="item" type="int" minOccurs="0" maxOccurs="unbounded" nillable="true"/>
  </sequence>
<attribute ref="enc:arrayType" wsdl:arrayType="int[]"/>
<attributeGroup ref="enc:commonAttributes"/>
<attribute ref="enc:offset"/>
</restriction>
</complexContent>
</complexType>
END_i2

cat > i4.xsd <<END_i4
<!-- array of float -->
<complexType name="ArrayOffloat"
   xmlns:enc="http://schemas.xmlsoap.org/soap/encoding/" 
   xmlns:wsdl="http://schemas.xmlsoap.org/wsdl/" 
   targetNamespace="services.wsdl"
   xmlns="http://www.w3.org/2001/XMLSchema"
   xmlns:tns="services.wsdl">
   <complexContent>
   <restriction base="enc:Array">
   <sequence>
   <element name="item" type="float" minOccurs="0" maxOccurs="unbounded" nillable="true"/>
   </sequence>
   <attributeGroup ref="enc:commonAttributes"/>
   <attribute ref="enc:offset"/>
   <attribute ref="enc:arrayType" wsdl:arrayType="float[]"/>
   </restriction>
   </complexContent>
</complexType>
END_i4

cat > i6.xsd <<END_i6
<!-- Sturcture -->
<complexType name="SOAPStruct"
   xmlns:enc="http://schemas.xmlsoap.org/soap/encoding/" 
   xmlns:wsdl="http://schemas.xmlsoap.org/wsdl/" 
   xmlns="http://www.w3.org/2001/XMLSchema"
   targetNamespace="services.wsdl"
   xmlns:tns="services.wsdl">

   <all>
     <element name="varString" type="string" nillable="true"/>
     <element name="varInt" type="int" nillable="true"/>
     <element name="varFloat" type="float" nillable="true"/>
   </all>
</complexType>
END_i6

cat > m2.xsd <<END_m2
<!-- femalePerson struct -->
<complexType name="femalePerson"
   xmlns:enc="http://schemas.xmlsoap.org/soap/encoding/" 
   xmlns:wsdl="http://schemas.xmlsoap.org/wsdl/" 
   xmlns="http://www.w3.org/2001/XMLSchema"
   targetNamespace="services.wsdl"
   xmlns:tns="services.wsdl">

   <complexContent>
       <extension base="tns:PERSON" >
       <element name="favoriteLipstick" type="string" />
       </extension>
   </complexContent>
</complexType>
END_m2

cat > m4.xsd <<END_m4
<!-- union maleOrFemalePerson -->
<complexType name="maleOrFemalePerson"
   xmlns:enc="http://schemas.xmlsoap.org/soap/encoding/" 
   xmlns:wsdl="http://schemas.xmlsoap.org/wsdl/" 
   xmlns="http://www.w3.org/2001/XMLSchema"
   targetNamespace="services.wsdl"
   xmlns:tns="services.wsdl">
   <choice>
     <element name="fArg" type="tns:femalePerson" />
     <element name="mArg" type="tns:malePerson" />
   </choice>
</complexType>
END_m4

cat > o1.xsd <<END_o1
<!-- ArrayOfint + WSDL reference -->
<complexType name="ArrayOfint2" 
   xmlns:enc="http://schemas.xmlsoap.org/soap/encoding/" 
   xmlns:wsdl="http://schemas.xmlsoap.org/wsdl/" 
   xmlns:tns="services.wsdl"
   targetNamespace="services.wsdl"
   xmlns="http://www.w3.org/2001/XMLSchema">
   <complexContent>
     <restriction base="enc:Array">
        <sequence>
	  <element name="item" type="int" minOccurs="1" maxOccurs="3" />
	</sequence>
        <attribute ref="enc:arrayType" wsdl:arrayType="int[]" />
        <attribute ref="soapenc:offset"/>
     </restriction>
   </complexContent>
</complexType>
END_o1

cat > o3.xsd <<END_o3
<!-- wrong definition as array can be of 1 element  -->
<complexType name="IntStruct" 
   xmlns:enc="http://schemas.xmlsoap.org/soap/encoding/" 
   xmlns:wsdl="http://schemas.xmlsoap.org/wsdl/" 
   targetNamespace="services.wsdl"
   xmlns="http://www.w3.org/2001/XMLSchema">
   <complexContent>
     <restriction base="enc:Struct">
        <sequence>
	  <element name="i1" type="int" maxOccurs="2" />
	  <element name="i2" type="int" maxOccurs="2" />
	  <element name="i3" type="int" maxOccurs="6" />
	</sequence>
     </restriction>
   </complexContent>
</complexType>
END_o3

cat > o5.xsd <<END_o5
<!-- struct with mutable elements  -->
<complexType name="SOAPStruct1" 
   xmlns:enc="http://schemas.xmlsoap.org/soap/encoding/" 
   xmlns:wsdl="http://schemas.xmlsoap.org/wsdl/" 
   targetNamespace="services.wsdl"
   xmlns="http://www.w3.org/2001/XMLSchema">
       <all>
	   <element name="varString" type="string" nillable="true"/>
	   <element name="varInt" type="int" nillable="true"/>
	   <element name="varFloat" type="float" nillable="true"/>
       </all>
</complexType>
END_o5

cat > mda.xsd <<END_mda
<!-- definition as array 2d of strings  -->
<complexType name="ArrayOf2Dstring" 
   xmlns:enc="http://schemas.xmlsoap.org/soap/encoding/" 
   xmlns:wsdl="http://schemas.xmlsoap.org/wsdl/" 
   targetNamespace="services.wsdl"
   xmlns="http://www.w3.org/2001/XMLSchema">
   <complexContent>
     <restriction base="enc:Array">
        <sequence>
	  <element name="item" type="string" />
	</sequence>
        <attribute ref="enc:arrayType" wsdl:arrayType="string[,]" />
        <attribute ref="soapenc:offset"/>
     </restriction>
   </complexContent>
</complexType>
END_mda

cat > fake.xsd <<END_fake
<!-- array of int -->
<complexType name="Fakeint"
   xmlns:enc="http://schemas.xmlsoap.org/soap/encoding/" 
   xmlns:wsdl="http://schemas.xmlsoap.org/wsdl/" 
   xmlns="http://www.w3.org/2001/XMLSchema"
   targetNamespace="services.wsdl"
   xmlns:tns="services.wsdl">
<complexContent>
<restriction base="enc:FakeArray">
  <sequence>
    <element name="item" type="int" minOccurs="0" maxOccurs="unbounded" nillable="true"/>
  </sequence>
<attribute ref="enc:arrayType" wsdl:arrayType="int[]"/>
<attributeGroup ref="enc:commonAttributes"/>
<attribute ref="enc:offset"/>
</restriction>
</complexContent>
</complexType>
END_fake

cd ..

cat > hdr.xml <<END_hdr
<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/">
  <SOAP-ENV:Header>
    <echoMeStringRequest SOAP-ENV:mustUnderstand="1" xmlns="http://soapinterop.org/">
      <varString xmlns="http://soapinterop.org/echoheader/">I&apos;m in a header</varString>
    </echoMeStringRequest>
  </SOAP-ENV:Header>
  <SOAP-ENV:Body>
    <echoVoidSoapHeader xmlns="http://soapinterop.org"/>
  </SOAP-ENV:Body>
</SOAP-ENV:Envelope>
END_hdr

chmod 644 hdr.xml

chmod 644 xsd/*.xsd
}
#end SOAP datatype generation

httpGet ()
{
  file=$1
  if [ "$2" -gt "0" ] 
    then
      pipeline="-P -c $2"
    else
      pipeline=""      
    fi
  user=${3-dba}
  pass=${4-dba}
  $VIRTUOSO_TEST/../urlsimu $file $pipeline -u $user -p $pass 
}

waitAll ()
{
   clients=1
   while [ "$clients" -gt "0" ]
     do
       sleep 1
       clients=`ps -e | grep urlsimu | grep -v .deps/ | grep -v grep | wc -l`
#     echo -e "Running clients $clients\r" 
     done 
}

checkRes ()
{
  result=0
  result=`grep '200 OK' $1 | wc -l`
  if [ "$result" -eq "$2" ]
    then
     ECHO "PASSED: $3 $result clicks"    
  else
     ECHO "*** FAILED: $3 $result clicks" 	
  fi
}

checkHTTPLog ()
{
  log_lines_ws_file_0=0
  log_lines_ws_file_0=`grep "GET /test.html HTTP/1.0" http/http*.log | wc -l`

  log_lines_ws_file_1=0
  log_lines_ws_file_1=`grep "GET /test.html HTTP/1.1" http/http*.log | wc -l`

  log_lines_ws_strses_reply_1_0=0
  log_lines_ws_strses_reply_1_0=`grep "GET /test.vsp HTTP/1.0" http/http*.log | wc -l`

  log_lines_ws_strses_reply_1_1=0
  log_lines_ws_strses_reply_1_1=`grep "GET /test.vsp HTTP/1.1" http/http*.log | wc -l`

  temp=`expr $H1 + $H2 + $H3`

  all_lines=`expr $CLICKS \* $temp \* $USERS`
  log_lines=`expr $log_lines_ws_strses_reply_1_0 + $log_lines_ws_strses_reply_1_1 + $log_lines_ws_file_0 + $log_lines_ws_file_1`

  if [ "$log_lines" -eq "$all_lines" ]
    then
     ECHO "PASSED: HTTP Log test"    
  else
     ECHO "*** FAILED: HTTP Log test" 	
  fi
}

# SQL command 
DoCommand()
{
  _dsn=$1
  command=$2
  shift 
  shift
  echo "+ " $ISQL $_dsn dba dba ERRORS=STDOUT VERBOSE=OFF PROMPT=OFF "EXEC=$command" $*		>> $LOGFILE	
  $ISQL $_dsn dba dba ERRORS=STDOUT VERBOSE=OFF PROMPT=OFF "EXEC=$command" $* >> $LOGFILE
  if test $? -ne 0 
  then
    LOG "***FAILED: $command"
  else
    LOG "PASSED: $command"
  fi
}

MakeIni ()
{
   MAKECFG_FILE_WITH_HTTP $TESTCFGFILE $PORT $HTTPPORT $CFGFILE
}

BANNER "STARTED SERIES OF HTTP SERVER TESTS"
NOLITE
ECHO "HTTP Server test ($CLICKS per page)"
ECHO "Two pages (html&vsp)"

case $1 in 
   *) #run test

   #CLEANUP
   STOP_SERVER
   MakeIni
   rm -f $DBLOGFILE $DBFILE
   rm -rf http
   mkdir http
   cp virtuoso.ini http
   cd http
   GenURI11
   GenURI10
   GenURI1011
   XSD_GENERATE
   rm -f vspsoap.vsp vspsoap_mod.vsp
   cp $VIRTUOSO_TEST/vspsoap.vsp vspsoap.vsp
   cp $VIRTUOSO_TEST/vspsoap_mod.vsp vspsoap_mod.vsp
   cp $VIRTUOSO_TEST/etalon_ouput_gz etalon_ouput_gz
   cp $VIRTUOSO_TEST/syncml.dtd syncml.dtd
   mkdir r4
   cp -f $VIRTUOSO_TEST/r4/* r4 
   GenHTML
   GenVSP
   mkdir test_404
   cd test_404
   Gen404VSP
   cd ..
   CHECK_PORT $TPORT

  LOG 'Starting graph CRUD tests before tightening the security by ODS...'
   START_SERVER $PORT 1000
   sleep 5
  cd ..
    rm http/_virtrdf_log*.ttl
    rm http/graphcrud*.log
    curl --verbose --url "http://localhost:$HTTPPORT/sparql-graph-crud?graph-uri=http://www.openlinksw.com/schemas/virtrdf%23" > http/_virtrdf_log1.ttl 2> http/graphcrud_get0.log
    if grep 'virtrdf:' http/_virtrdf_log1.ttl > /dev/null ; then
      LOG 'PASSED: http/_virtrdf_log1.ttl contains data (old IRI syntax)'
    else
      LOG '***FAILED: http/_virtrdf_log1.ttl does not contains virtrdf: string, but it should (old IRI syntax)'
    fi

    curl --verbose --url "http://localhost:$HTTPPORT/sparql-graph-crud?graph=http://www.openlinksw.com/schemas/virtrdf%23" > http/_virtrdf_log1.ttl 2> http/graphcrud_get0.log
    if grep 'virtrdf:' http/_virtrdf_log1.ttl > /dev/null ; then
      LOG 'PASSED: http/_virtrdf_log1.ttl contains data (new IRI syntax)'
    else
      LOG '***FAILED: http/_virtrdf_log1.ttl does not contains virtrdf: string, but it should (new IRI syntax)'
    fi

    curl --digest --user dba:dba --verbose --url "http://localhost:$HTTPPORT/sparql-graph-crud-auth?graph-uri=http://example.com/crud1" -X DELETE > http/graphcrud_1.log 2>&1
    if grep 'HTTP/1.1 404' http/graphcrud_1.log > /dev/null ; then
      LOG 'PASSED: http/graphcrud_1.log contains 404 error for missing graph'
    else
      LOG '***FAILED: http/graphcrud_1.log does not contains 404 error for missing graph, but it should'
    fi

    curl --digest --user dba:dba --verbose --url "http://localhost:$HTTPPORT/sparql-graph-crud-auth?graph-uri=http://example.com/crud1" -T http/_virtrdf_log1.ttl > http/graphcrud_2.log 2>&1
    if grep  'HTTP/1.1 201' http/graphcrud_2.log > /dev/null ; then
      LOG 'PASSED: http/graphcrud_2.log contains 201 for newly created graph'
    else
      LOG '***FAILED: http/graphcrud_2.log does not contain 201 for newly created graph, but it should'
    fi

    curl --verbose --url "http://localhost:$HTTPPORT/sparql-graph-crud?graph-uri=http://example.com/crud1" > http/_virtrdf_log2.ttl 2> http/graphcrud_get2.log
    if grep 'virtrdf:' http/_virtrdf_log2.ttl > /dev/null ; then
      LOG 'PASSED: http/_virtrdf_log2.ttl contains data'
    else
      LOG '***FAILED: http/_virtrdf_log2.ttl does not contains virtrdf: string, but it should'
    fi

    curl --digest --user dba:dba --verbose --url "http://localhost:$HTTPPORT/sparql-graph-crud-auth?graph-uri=http://example.com/crud1" -T http/_virtrdf_log1.ttl > http/graphcrud_2.log 2>&1
    if grep  'HTTP/1.1 200' http/graphcrud_2.log > /dev/null ; then
      LOG 'PASSED: http/graphcrud_2.log contains 200 for recreated graph'
    else
      LOG '***FAILED: http/graphcrud_2.log does not contains 200 for newly created graph, but it should'
    fi

    curl --digest --user dba:dba --verbose --url "http://localhost:$HTTPPORT/sparql-graph-crud-auth?graph-uri=http://example.com/crud1" -X DELETE > http/graphcrud_3.log 2>&1
    if grep 'HTTP/1.1 200' http/graphcrud_3.log > /dev/null ; then
      LOG 'PASSED: http/graphcrud_3.log contains 200 for successful graph removal'
    else
      LOG '***FAILED: http/graphcrud_3.log does not contain 200 for successful graph removal, but it should'
    fi

    curl --verbose --url "http://localhost:$HTTPPORT/sparql-graph-crud?graph-uri=http://example.com/crud1" > http/graphcrud_4.log 2>&1
    if grep 'HTTP/1.1 404' http/graphcrud_4.log > /dev/null ; then
      LOG 'PASSED: http/graphcrud_4.log contains 404 for deleted graph'
    else
      LOG '***FAILED: http/graphcrud_4.log does not contain 404 for deleted graph, but it should'
    fi
  cd http
  SHUTDOWN_SERVER

   # Prepare GRDDL tests to run locally
   gzip -c -d $VIRTUOSO_TEST/grddl-tests.tar.gz | tar xf -
   if grep ":14300" grddl-tests/* > /dev/null
   then
       echo "The port number to replace is correct."
   else
       LOG "***ABORTED: The port number to replace in GRDDL test-case sources is incorrect, please modify port"
       exit 1
   fi
   for f in `find grddl-tests -type f`
   do
       cat $f | sed -e "s/:14300/:$HTTPPORT/g" > tmp.tmp
       cp -f tmp.tmp $f
       rm -f tmp.tmp
   done
   START_SERVER $PORT 1000
   sleep 1
   cd ..

if [ $do_mappers_only -ne 1 ]
then    
   DoCommand $DSN "DB.DBA.VHOST_REMOVE ('*ini*', '*ini*', '/');"   
   DoCommand $DSN "DB.DBA.VHOST_DEFINE ('*ini*', '*ini*', '/', '/', 0, 0, NULL,  NULL, NULL, NULL, 'dba', NULL, NULL, 0);"   
  if [ "x$HOST_OS" = "x" -a "x$NO_PERF" = "x" ]
  then
  # HTTP/1.0   
   ECHO "STARTED: test with $USERS HTTP/1.0 clients"
   count=1
  while [ "$count" -le "$USERS" ]
     do
       httpGet http/http10.uri 0 > http/result1.$count &
       count=`expr $count + 1`   
     done
   waitAll 
   checkRes 'http/result1.*' `expr $CLICKS \* $H1 \* $USERS` 'HTTP/1.0 test'
  
  # HTTP/1.1  
   ECHO "STARTED: test with $USERS HTTP/1.1 clients"
   count=1
   while [ "$count" -le "$USERS" ]
     do
       httpGet http/http11.uri $nreq > http/result2.$count &
       count=`expr $count + 1`   
     done
   waitAll 
   checkRes 'http/result2.*'  `expr $CLICKS \* $H2 \* $USERS` 'HTTP/1.1 test'
   
   # HTTP/1.0 & HTTP/1.1 
   ECHO "STARTED: test with $USERS HTTP/1.0/1.1 clients"
   count=1
   while [ "$count" -le "$USERS" ]
     do
       httpGet http/http1011.uri $nreq > http/result3.$count &
       count=`expr $count + 1`   
     done
   waitAll
   checkRes 'http/result3.*' `expr $CLICKS \* $H3 \* $USERS` 'HTTP/1.0 & HTTP/1.1 test'

   checkHTTPLog

  fi 
   RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u "HTTPPORT=$HTTPPORT" < $VIRTUOSO_TEST/tsoap.sql
   if test $STATUS -ne 0
   then
      LOG "***ABORTED: tsoap.sql"
      exit 1
   fi
   
   RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u "HTTPPORT=$HTTPPORT" < $VIRTUOSO_TEST/tsoap_rpc.sql
   if test $STATUS -ne 0
   then
      LOG "***ABORTED: tsoap_rpc.sql"
      exit 1
   fi

   RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u "HTTPPORT=$HTTPPORT" < $VIRTUOSO_TEST/tsoap_r3.sql
   if test $STATUS -ne 0
   then
      LOG "***ABORTED: tsoap_r3.sql"
      exit 1
   fi


   RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u "HTTPPORT=$HTTPPORT" < $VIRTUOSO_TEST/wsdl_suite.sql
   if test $STATUS -ne 0
   then
      LOG "***ABORTED: wsdl_suite.sql"
      exit 1
   fi
   
   RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u "HTTPPORT=$HTTPPORT" < $VIRTUOSO_TEST/twsrp.sql
   if test $STATUS -ne 0
   then
      LOG "***ABORTED: twsrp.sql"
      exit 1
   fi

# XXX: VJ   
#   RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u "HTTPPORT=$HTTPPORT" < $VIRTUOSO_TEST/tsoapudt.sql
#   if test $STATUS -ne 0
#   then
#      LOG "***ABORTED: tsoapudt.sql"
#      exit 1
#   fi

   ECHO "Started: Testing new SOAP client"

   RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u "HTTPPORT=$HTTPPORT" < $VIRTUOSO_TEST/tsoap_new.sql
   if test $STATUS -ne 0
   then
      LOG "***ABORTED: tsoap_new.sql"
      exit 1
   fi
   
   ECHO "Started: New SOAP client with digest authentication"

   RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u "HTTPPORT=$HTTPPORT" < $VIRTUOSO_TEST/soapauth.sql
   DoCommand $DSN "DB.DBA.VHOST_REMOVE ('*ini*', '*ini*', '/SOAP', 0);"
   DoCommand $DSN "DB.DBA.VHOST_DEFINE ('*ini*', '*ini*', '/SOAP', '/SOAP/', 0, 0, NULL, 'DB.DBA.AUTH_HOOK_SOAP_TEST', 'soaptest', NULL, 'dba', 'SOAP', 'DIGEST', 1);"   

   RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u "HTTPPORT=$HTTPPORT" < $VIRTUOSO_TEST/tsoap_new.sql
   if test $STATUS -ne 0
   then
      LOG "***ABORTED: tsoap_new.sql"
      exit 1
   fi
   
   ECHO "Completed: new SOAP tests"

   DoCommand $DSN "DB.DBA.VHOST_REMOVE ('*ini*', '*ini*', '/SOAP', 0);"
   DoCommand $DSN "DB.DBA.VHOST_DEFINE ('*ini*', '*ini*', '/SOAP', '/SOAP/', 0, 0, NULL, NULL, NULL, NULL, 'dba', 'SOAP', NULL, 1);"   

   RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u "HTTPPORT1=$HTTPPORT1" "HTTPPORT2=$HTTPPORT2"  "HTTPPORT=$HTTPPORT"< $VIRTUOSO_TEST/thttp.sql 
   if test $STATUS -ne 0
   then
      LOG "***ABORTED: thttp.sql"
      exit 1
   fi

   if [ "z$SSL" != "z" -a "z$NO_SSL" = "z" ]
   then 
   ECHO "SSL dependant tests"
   RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u "HTTPPORT1=$HTTPPORT1" "HTTPPORT2=$HTTPPORT2"  "HTTPPORT=$HTTPPORT"< $VIRTUOSO_TEST/twss.sql 
   fi

   ECHO "Interop round 4 endpoints"
   RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < http/r4/mime-doc.sql 
   RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < http/r4/mime-rpc.sql 
   RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < http/r4/dime-doc.sql 
   RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < http/r4/dime-rpc.sql 
   RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < http/r4/simple-doc-literal.sql
   RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < http/r4/simple-rpc-encoded.sql
   RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < http/r4/complex-rpc-encoded.sql
   RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < http/r4/xsd.sql
   RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < http/r4/load_xsd.sql
   ECHO "Interop round 4 tests"
   RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u "HTTPPORT=$HTTPPORT"< $VIRTUOSO_TEST/tsoap_r4.sql 
   if test $STATUS -ne 0
   then
      LOG "***ABORTED: tsoap_r4.sql"
      exit 1
   fi
   
   RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u "HTTPPORT=$HTTPPORT"< $VIRTUOSO_TEST/txmla.sql 
   if test $STATUS -ne 0
   then
      LOG "***ABORTED: txmla.sql"
      exit 1
   fi
   RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u "HTTPPORT=$HTTPPORT"< $VIRTUOSO_TEST/txmla3.sql 
   if test $STATUS -ne 0
   then
      LOG "***ABORTED: txmla3.sql"
      exit 1
   fi
  RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u "HTTPPORT=$HTTPPORT"< $VIRTUOSO_TEST/tacl.sql 
   if test $STATUS -ne 0
   then
      LOG "***ABORTED: tacl.sql"
      exit 1
   fi
#   RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u "HTTPPORT=$HTTPPORT"< $VIRTUOSO_TEST/twsrm.sql 
#   if test $STATUS -ne 0
#   then
#      LOG "***ABORTED: twsrm.sql"
#      exit 1
#   fi
   RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u "HTTPPORT=$HTTPPORT"< $VIRTUOSO_TEST/twstr.sql 
   if test $STATUS -ne 0
   then
      LOG "***ABORTED: twsrm.sql"
      exit 1
   fi


if [ -f $PLUGINDIR/wbxml2.so -a -f $HOME/vad/syncml_dav.vad ]
then
   cp $HOME/vad/syncml_dav.vad http
   DoCommand $DSN "VAD_INSTALL ('syncml_dav.vad', 0);"
   RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u "HTTPPORT=$HTTPPORT"< $VIRTUOSO_TEST/tsyncml.sql 
   if test $STATUS -ne 0
   then
      LOG "***ABORTED: tsyncml.sql"
      exit 1
   fi
   else
      LOG "SKIP      : tsyncml.sql"
fi

   RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u "HTTPPORT=$HTTPPORT" < $VIRTUOSO_TEST/tsoapcpl.sql 
   if test $STATUS -ne 0
   then
      LOG "***ABORTED: tsoapcpl.sql"
      exit 1
   fi

   RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u "HTTPPORT=$HTTPPORT" < $VIRTUOSO_TEST/url_rewrite_test.sql
   if test $STATUS -ne 0
   then
      LOG "***ABORTED: url_rewrite_test.sql"
      exit 1
   fi
fi
if [ -f $HOME/vad/cartridges_dav.vad ]
then  
   cp $HOME/vad/cartridges_dav.vad http/ 
   DoCommand $DSN "registry_set ('__rdf_cartridges_original_doc_uri__', '1');" 
   # XXX 
   #RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u "HTTPPORT=$HTTPPORT" < $VIRTUOSO_TEST/tsponge.sql
   if test $STATUS -ne 0
   then
      LOG "***ABORTED: tsponge.sql"
      exit 1
   fi

   # XXX
   #RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u "HTTPPORT=$HTTPPORT" < $VIRTUOSO_TEST/xhtml1-testcases.sql
   if test $STATUS -ne 0
   then
      LOG "***ABORTED: xhtml1-testcases.sql"
      exit 1
   fi
fi


   SHUTDOWN_SERVER

   # 
   #  CLEANUP
   #
   rm -f http/result?.*
   rm -f test_gz.vsp 
   ;;

esac
CHECK_LOG
BANNER "COMPLETED SERIES OF HTTP SERVER TESTS"

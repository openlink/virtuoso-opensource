#
# $Id$
#

DLL_SOURCES=\
 BlobTest.cs\
 CommandBuilderTest.cs\
 CommandTest.cs\
 ConnectionTest.cs\
 TransactionTest.cs\
 SqlXmlTest.cs\
 VirtuosoClientSuite.cs

DTC_DLL_SOURCES=\
 DtcTest.cs\
 AssemblyInfo.cs\
 VirtuosoDtcSuite.cs

REFERENCES=/reference:OpenLink.Testing.dll,OpenLink.Data.Virtuoso.dll
CLIENT_REFERENCES=/reference:OpenLink.Testing.dll,OpenLink.Data.VirtuosoClient.dll
ODBC_CLIENT_REFERENCES=/reference:OpenLink.Testing.dll,OpenLink.Data.VirtuosoOdbcClient.dll

all: \
	VirtuosoSuite.dll \
	VirtuosoClientSuite.dll \
	VirtuosoOdbcClientSuite.dll \
	VirtuosoDtcSuite.dll \
	VirtuosoDtcClientSuite.dll \
	VirtuosoDtcOdbcClientSuite.dll

VirtuosoSuite.dll: $(DLL_SOURCES) OpenLink.Testing.dll OpenLink.Data.Virtuoso.dll
	csc /target:library /out:$@ $(REFERENCES) $(DLL_SOURCES)

VirtuosoClientSuite.dll: $(DLL_SOURCES) OpenLink.Testing.dll OpenLink.Data.VirtuosoClient.dll
	csc /target:library /out:$@ /define:CLIENT $(CLIENT_REFERENCES) $(DLL_SOURCES)

VirtuosoOdbcClientSuite.dll: $(DLL_SOURCES) OpenLink.Testing.dll OpenLink.Data.VirtuosoOdbcClient.dll
	csc /target:library /out:$@ /define:ODBC_CLIENT $(ODBC_CLIENT_REFERENCES) $(DLL_SOURCES)

VirtuosoDtcSuite.dll: $(DTC_DLL_SOURCES) OpenLink.Testing.dll OpenLink.Data.Virtuoso.dll
	csc /target:library /out:$@ $(REFERENCES) $(DTC_DLL_SOURCES)

VirtuosoDtcClientSuite.dll: $(DTC_DLL_SOURCES) OpenLink.Testing.dll OpenLink.Data.VirtuosoClient.dll
	csc /target:library /out:$@ /define:CLIENT $(CLIENT_REFERENCES) $(DTC_DLL_SOURCES)

VirtuosoDtcOdbcClientSuite.dll: $(DTC_DLL_SOURCES) OpenLink.Testing.dll OpenLink.Data.VirtuosoOdbcClient.dll
	csc /target:library /out:$@ /define:ODBC_CLIENT $(ODBC_CLIENT_REFERENCES) $(DTC_DLL_SOURCES)

OpenLink.Testing.dll:
	cd ../harness; $(MAKE)
	cp ../harness/OpenLink.Testing.dll .

OpenLink.Data.Virtuoso.dll:
	cd ../../../VirtuosoClient.Net; $(MAKE)
	cp ../../../VirtuosoClient.Net/OpenLink.Data.Virtuoso.dll .

OpenLink.Data.VirtuosoClient.dll:
	cd ../../../VirtuosoClient.Net; $(MAKE)
	cp ../../../VirtuosoClient.Net/OpenLink.Data.VirtuosoClient.dll .

OpenLink.Data.VirtuosoOdbcClient.dll:
	cd ../../../VirtuosoClient.Net; $(MAKE)
	cp ../../../VirtuosoClient.Net/OpenLink.Data.VirtuosoOdbcClient.dll .

clean:
	rm -rf \
	  VirtuosoSuite.dll \
	  VirtuosoClientSuite.dll \
	  VirtuosoOdbcClientSuite.dll \
	  VirtuosoDtcSuite.dll \
	  VirtuosoDtcClientSuite.dll \
	  VirtuosoDtcOdbcClientSuite.dll \
	  OpenLink.Testing.dll \
	  OpenLink.Data.Virtuoso.dll \
	  OpenLink.Data.VirtuosoClient.dll \
	  OpenLink.Data.VirtuosoOdbcClient.dll

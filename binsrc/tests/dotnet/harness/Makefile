#
# $Id$
#

CSFLAGS=/optimize+
 
DLL_SOURCES=\
 AssemblyInfo.cs\
 OpenLink\\Testing\\Framework\\ComparisonException.cs\
 OpenLink\\Testing\\Framework\\ITest.cs\
 OpenLink\\Testing\\Framework\\ITestListener.cs\
 OpenLink\\Testing\\Framework\\TestCase.cs\
 OpenLink\\Testing\\Framework\\TestCaseAttribute.cs\
 OpenLink\\Testing\\Framework\\TestCaseResult.cs\
 OpenLink\\Testing\\Framework\\TestFailedException.cs\
 OpenLink\\Testing\\Framework\\TestResult.cs\
 OpenLink\\Testing\\Framework\\TestSkippedException.cs\
 OpenLink\\Testing\\Framework\\TestStatus.cs\
 OpenLink\\Testing\\Framework\\TestStatusCode.cs\
 OpenLink\\Testing\\Framework\\TestSuite.cs\
 OpenLink\\Testing\\Framework\\TestSuiteAttribute.cs\
 OpenLink\\Testing\\UI\\BaseTestRunner.cs\
 OpenLink\\Testing\\Util\\TestSettings.cs

CONSOLE_SOURCES=\
 OpenLink\\Testing\\UI\\ConsoleTestRunner.cs

all: OpenLink.Testing.dll ConsoleTestRunner.exe

OpenLink.Testing.dll: $(DLL_SOURCES) OpenLink.Testing.snk
	csc /target:library /out:$@ $(CSFLAGS) $(DLL_SOURCES)

ConsoleTestRunner.exe: $(CONSOLE_SOURCES) #OpenLink.Testing.dll
	csc /out:$@ /reference:OpenLink.Testing.dll $(CSFLAGS) $(CONSOLE_SOURCES)

OpenLink.Testing.snk:
	sn -k $@

install:
	gacutil -i OpenLink.Testing.dll

uninstall:
	gacutil -u OpenLink.Testing

clean:
	rm -rf OpenLink.Testing.dll ConsoleTestRunner.exe

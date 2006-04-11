all : demo.jar

demo.jar: fishselect.class fishselectResponse.class SOAP.class
	$(JDK1)/bin/jar cvf demo.jar fishselect.class fishselectResponse.class SOAP.class

clean:
	rm -f *.class

run: demo.jar
	$(JDK1)/bin/appletviewer SOAP.html 

run1: demo.jar
	$(JDK1)/bin/appletviewer http://home:6666/soapdemo/SOAP.html

%.class : %.java
	$(JDK1)/bin/javac -classpath $(JDK1)/lib/classes.zip:xerces.jar:saxapi.jar:soaprt.jar:. $<

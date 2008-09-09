HTTPPORT=`expr $PORT + 7000`
TEST_DRIVER='/usr/java/latest/bin/java -Xmx2048m -cp bin:lib/ssj.jar:lib/log4j-1.2.15.jar:lib/virtjdbc3.jar benchmark.testdriver.TestDriver'

#Plain WS run
#$TEST_DRIVER -runs 10 -w 10 -virtuoso -dg BSBM http://localhost:8310/sparql

#Plain Virtuoso SQL run
$TEST_DRIVER -runs 10 -w 10 -dg BSBM -dbconnect -sql -virtuoso -qdir SQLqueries -dbdriver virtuoso.jdbc3.Driver -connuser dba -connpwd dba jdbc:virtuoso://localhost:$PORT/UID=dba/PWD=dba

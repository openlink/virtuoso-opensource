export PATH=/usr/local/jdk1.6.0_07-64/bin:$PATH

HTTPPORT=8890
TEST_DRIVER='java -Xmx2048m -cp bin:lib/ssj.jar:lib/log4j-1.2.15.jar:lib/virtjdbc3.jar benchmark.testdriver.TestDriver'

#Plain WS run
#$TEST_DRIVER -runs 128 -w 32 -virtuoso -dg BSBM http://localhost:8310/sparql

#Plain Virtuoso SQL run
#strace -o xx -s 128 -ff $TEST_DRIVER -runs 10 -w 10 -dg BSBM -dbconnect -sql -virtuoso -qdir SQLqueries -idir datadir-70812 -dbdriver virtuoso.jdbc3.Driver -connuser dba -connpwd dba jdbc:virtuoso://localhost/UID=dba/PWD=dba $*
$TEST_DRIVER -runs 128 -w 32 -dg BSBM -dbconnect -sql -virtuoso -qdir SQLqueries -idir datadir-2785 -dbdriver virtuoso.jdbc3.Driver -connuser dba -connpwd dba jdbc:virtuoso://localhost/UID=dba/PWD=dba $*

# test suite subset for use with cluster 

./test_cluster.sh virtuoso-t trecov.sh
./test_cluster.sh virtuoso-t tsql.sh
./test_cluster.sh virtuoso-t tsql2.sh
./test_cluster.sh virtuoso-t tsql3.sh
./test_cluster.sh virtuoso-t thttp.sh

./test_cluster.sh virtuoso-t rtest.sh
./test_cluster.sh virtuoso-t tsqlo.sh
./test_cluster.sh virtuoso-t nwxml.sh
cd $VIRTUOSO_TEST/../lubm 
./test_cluster.sh virtuoso-t 
cd $VIRTUOSO_TEST/../suite
cd clflt
./tflt.sh
cd ..


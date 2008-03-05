



alter index lineitem on lineitem partition cluster c2 (l_orderkey int (0hexfff00));

alter index L_PQSOD on LINEITEM  partition cluster c2 
    (L_PARTKEY int (0hexfff00));

alter index L_OSDQEPS on LINEITEM partition cluster c2 (l_orderkey int (0hexfff00));

alter index L_ROSSC on LINEITEM partition cluster c2 (l_orderkey int (0hexfff00));



alter index L_ORED on LINEITEM partition cluster c2 (
    L_ORDERKEY int (0hexfff00));


alter index customer on customer partition cluster c2 (c_custkey int (0hexfff00));

alter index orders on orders partition cluster c2 (o_orderkey int (0hexfff00));

alter index O_CLOKOD on ORDERS partition cluster c2 (o_orderkey int (0hexfff00));

alter  index O_OP on ORDERS partition cluster c2 (
    O_ORDERKEY int (0hexfff00));

alter index partsupp on partsupp  partition cluster c2 (ps_partkey int (0hexfff00));

alter  index PS_PKSKCS on PARTSUPP partition cluster c2 (
    PS_PARTKEY int (0hexfff00));

alter  index PS_SPSA on PARTSUPP partition cluster c2 (
    PS_SUPPKEY int (0hexfff0));


alter index part on part partition cluster c2 (p_partkey int (0hexfff00));

alter  index P_STPM on PART partition cluster c2 (
    P_SIZE int);


alter index P_CBP on PART partition cluster c2 (
    P_CONTAINER varchar);

alter index P_TP on PART partition cluster c2 (
    P_TYPE varchar);


alter index supplier on supplier partition cluster c2 (s_suppkey int (0hexfff00));


alter  index S_SN on SUPPLIER partition cluster c2 (S_SUPPKEY int (0hexfff00));

alter index nation on nation partition cluster replicated;

alter index region on region partition cluster replicated;






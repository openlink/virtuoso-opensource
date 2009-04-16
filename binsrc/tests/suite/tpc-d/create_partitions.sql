



alter index lineitem on lineitem partition  (l_orderkey int (0hexfff00));

alter index L_PQSOD on LINEITEM  partition  
    (L_PARTKEY int (0hexfff00));

alter index L_OSDQEPS on LINEITEM partition  (l_orderkey int (0hexfff00));

alter index L_ROSSC on LINEITEM partition  (l_orderkey int (0hexfff00));



alter index L_ORED on LINEITEM partition  (
    L_ORDERKEY int (0hexfff00));


alter index customer on customer partition  (c_custkey int (0hexfff00));

alter index orders on orders partition  (o_orderkey int (0hexfff00));

alter index O_CLOKOD on ORDERS partition  (o_orderkey int (0hexfff00));

alter  index O_OP on ORDERS partition  (
    O_ORDERKEY int (0hexfff00));

alter index partsupp on partsupp  partition  (ps_partkey int (0hexfff00));

alter  index PS_PKSKCS on PARTSUPP partition  (
    PS_PARTKEY int (0hexfff00));

alter  index PS_SPSA on PARTSUPP partition  (
    PS_SUPPKEY int (0hexfff0));


alter index part on part partition  (p_partkey int (0hexfff00));

alter  index P_STPM on PART partition  (
    P_SIZE int);


alter index P_CBP on PART partition  (
    P_CONTAINER varchar);

alter index P_TP on PART partition  (
    P_TYPE varchar);


alter index supplier on supplier partition  (s_suppkey int (0hexfff00));


alter  index S_SN on SUPPLIER partition  (S_SUPPKEY int (0hexfff00));

alter index nation on nation partition cluster replicated;

alter index region on region partition cluster replicated;






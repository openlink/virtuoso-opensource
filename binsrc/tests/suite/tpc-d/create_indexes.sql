--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2014 OpenLink Software
--  
--  This project is free software; you can redistribute it and/or modify it
--  under the terms of the GNU General Public License as published by the
--  Free Software Foundation; only version 2 of the License, dated June 1991.
--  
--  This program is distributed in the hope that it will be useful, but
--  WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
--  General Public License for more details.
--  
--  You should have received a copy of the GNU General Public License along
--  with this program; if not, write to the Free Software Foundation, Inc.,
--  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
--  
--  
drop index $IF $EQU $U{QUALINDEXES} 1 LINEITEM.L_PQSOD L_PQSOD;
create index L_PQSOD on LINEITEM (
    L_PARTKEY, 
    L_QUANTITY, 
    L_EXTENDEDPRICE, 
    L_SUPPKEY, 
    L_ORDERKEY, 
    L_DISCOUNT
);

drop index $IF $EQU $U{QUALINDEXES} 1 LINEITEM.L_OSDQEPS L_OSDQEPS;
create index L_OSDQEPS on LINEITEM (
    L_RETURNFLAG, 
    L_LINESTATUS, 
    L_ORDERKEY, 
    L_SHIPDATE, 
    L_DISCOUNT, 
    L_QUANTITY, 
    L_EXTENDEDPRICE, 
    L_PARTKEY, 
    L_SUPPKEY, 
    L_TAX
);

drop index $IF $EQU $U{QUALINDEXES} 1 LINEITEM.L_ROSSC L_ROSSC;
create index L_ROSSC on LINEITEM (
    L_RECEIPTDATE,
    L_ORDERKEY,
    L_SHIPMODE,
    L_SHIPDATE,
    L_COMMITDATE
);

drop index $IF $EQU $U{QUALINDEXES} 1 LINEITEM.L_ORED L_ORED;
create index L_ORED on LINEITEM (
    L_ORDERKEY,
    L_RETURNFLAG,
    L_EXTENDEDPRICE,
    L_DISCOUNT
);

drop index $IF $EQU $U{QUALINDEXES} 1 ORDERS.O_CLOKOD O_CLOKOD;
create index O_CLOKOD on ORDERS (
    O_CLERK,
    O_ORDERKEY,
    O_ORDERDATE
);

drop index $IF $EQU $U{QUALINDEXES} 1 ORDERS.O_OP O_OP;
create unique index O_OP on ORDERS (
    O_ORDERKEY,
    O_ORDERPRIORITY
);

drop index $IF $EQU $U{QUALINDEXES} 1 PARTSUPP.PS_PKSKCS PS_PKSKCS;
create unique index PS_PKSKCS on PARTSUPP (
    PS_PARTKEY,
    PS_SUPPKEY,
    PS_SUPPLYCOST
);

drop index $IF $EQU $U{QUALINDEXES} 1 PARTSUPP.PS_SPSA PS_SPSA;
create unique index PS_SPSA on PARTSUPP (
    PS_SUPPKEY,
    PS_PARTKEY,
    PS_SUPPLYCOST,
    PS_AVAILQTY
);

drop index $IF $EQU $U{QUALINDEXES} 1 PART.P_STPM P_STPM;
create unique index P_STPM on PART (
    P_SIZE,
    P_PARTKEY,
    P_TYPE,
    P_MFGR
);

drop index $IF $EQU $U{QUALINDEXES} 1 PART.P_CBP P_CBP;
create index P_CBP on PART (
    P_CONTAINER,
    P_BRAND,
    P_PARTKEY
);

drop index $IF $EQU $U{QUALINDEXES} 1 PART.P_TP P_TP;
create index P_TP on PART (
    P_TYPE,
    P_PARTKEY
);

drop index $IF $EQU $U{QUALINDEXES} 1 SUPPLIER.S_SN S_SN;
create unique index S_SN on SUPPLIER (S_SUPPKEY, S_NATIONKEY);

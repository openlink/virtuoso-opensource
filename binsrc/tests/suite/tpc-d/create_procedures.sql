--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2018 OpenLink Software
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
create procedure randomNumber (in nmin integer, in nmax integer) {

	declare result integer;
	result := rnd(nmax - nmin + 1) + nmin;
	return result;
};

create procedure randomNumeric(in nmin numeric, in nmax numeric, in pwr numeric) {
	
	declare result numeric;
	return (cast (randomNumber (nmin * pwr, nmax * pwr) as numeric) / pwr);
};

create procedure random_aString (in _sz integer)
{
  declare _res varchar;

  _res := space (_sz);
  while (_sz > 0)
    {
      if (mod (_sz, 3) = 0)
	aset (_res, _sz - 1, ascii ('a') + randomNumber (0, 25));
      else if (mod (_sz, 3)  = 1)
	aset (_res, _sz - 1, ascii ('A') + randomNumber (0, 25));
      else 
	aset (_res, _sz - 1, ascii ('1') + randomNumber (0, 9));
      _sz := _sz - 1;
    }
  return _res;
}

create procedure random_vString (in x integer)
{
  declare _sz integer;

  _sz := x * randomNumber (40, 160) / 100;
       
  return (random_aString(_sz));
}

create procedure randomPhone(in n integer) {

	return concat(sprintf('%d', n + 10), '-', sprintf('%d', randomNumber(100, 999)), '-', sprintf('%d', randomNumber(100, 999)), '-', sprintf('%d', randomNumber(1000, 9999)));
};

create procedure randomType(in n integer) {
	
	declare syl1, syl2, syl3 integer;
	
	syl1 := vector('STANDARD', 'SMALL', 'MEDIUM', 'LARGE', 'ECONOMY', 'PROMO');
	syl2 := vector('ANODIZED', 'BURNISHED', 'PLATED', 'POLISHED', 'BRUSHED');
	syl3 := vector('TIN', 'NICKEL', 'BRASS', 'STEEL', 'COPPER');
		  
	return concat(aref(syl1, randomNumber(0, 5)), ' ', aref(syl2, randomNumber(0, 4)), ' ', aref(syl3, randomNumber(0, 4)));
};

create procedure randomContainer(in n integer) {
	
	declare syl1, syl2 integer;
	
	syl1 := vector('SM', 'LG', 'MED', 'JUMBO', 'WRAP');
	syl2 := vector('CASE', 'BOX', 'BAG', 'JAR', 'PKG', 'PACK', 'CAN', 'DRUM');
		  
	return concat(aref(syl1, randomNumber(0, 4)), ' ', aref(syl2, randomNumber(0, 7)));
};

create procedure randomSegment(in n integer) {
	
	declare syl integer;
	
	syl := vector('AUTOMOBILE', 'BUILDING', 'FURNITURE', 'MACHINERY', 'HOUSEHOLD');
		 
	return aref(syl, randomNumber(0, 4));
};

create procedure randomInstruction(in n integer) {
	
	declare syl integer;
	
	syl := vector('DELIVER IN PERSON', 'COLLECT COD', 'NONE', 'TAKE BACK RETURN');
		 
	return aref(syl, randomNumber(0, 3));
};

create procedure randomMode(in n integer) {
	
	declare syl integer;
	
	syl := vector('REG AIR', 'AIR', 'RAIL', 'SHIP', 'TRUCK', 'MAIL', 'FOB');
		 
	return aref(syl, randomNumber(0, 6));
};

create procedure randomPriority(in n integer) {
	
	declare syl integer;
	
	syl := vector('1-URGENT', '2-HIGH', '3-MEDIUM', '4-NOT SPECIFIED', '5-LOW');
		 
	return aref(syl, randomNumber(0, 4));
};

create procedure randomText(in n integer) {
	
	declare nouns, verbs, ajectives, adverbs, prepositions, auxiliaries, terminators integer;
	
	declare _result, _temp varchar;
	declare _actual_length integer;
	
	nouns := vector('foxes', 'ideas', 'theodolites', 'pinto', 'beans', 'instructions', 'dependencies', 'excuses', 'platelets', 'asymptotes', 'courts', 'dolphins', 'multipliers', 'sauternes', 'warthogs', 'frets', 'dinos', 'attainments', 'somas', 'Tiresias', 'patterns', 'forges', 'braids', 'hockey', 'players', 'frays', 'warhorses', 'dugouts', 'notornis', 'epitaphs', 'pearls', 'tithes', 'waters', 'orbits', 'gifts', 'sheaves', 'depths', 'sentiments', 'decoys', 'realms', 'pains', 'grouches', 'escapades');

    verbs := vector('sleep', 'wake', 'are', 'cajole', 'haggle', 'nag', 'use', 'boost', 'affix', 'detect', 'integrate', 'maintain', 'nod', 'was', 'lose', 'sublate', 'solve', 'thrash', 'promise', 'engage', 'hinder', 'print', 'x-ray', 'breach', 'eat', 'grow', 'impress', 'mold', 'poach', 'serve', 'run', 'dazzle', 'snooze', 'doze', 'unwind', 'kindle', 'play', 'hang', 'believe', 'doubt');

	ajectives := vector('furious', 'sly', 'careful', 'blithe', 'quick', 'fluffy', 'slow', 'quiet', 'ruthless', 'thin', 'close', 'dogged', 'daring', 'brave', 'stealthy', 'permanent', 'enticing', 'idle', 'busy', 'regular', 'final', 'ironic', 'even', 'bold', 'silent');

	adverbs := vector('sometimes', 'always', 'never', 'furiously', 'slyly', 'carefully', 'blithely', 'quickly', 'fluffily', 'slowly', 'quietly', 'ruthlessly', 'thinly', 'closely', 'doggedly', 'daringly', 'bravely', 'stealthily', 'permanently', 'enticingly', 'idly', 'busily', 'regularly', 'finally', 'ironically', 'evenly', 'boldly', 'silently');

	prepositions := vector('about', 'above', 'according', 'to', 'across', 'after', 'against', 'along', 'alongside', 'of', 'among', 'around', 'at', 'atop', 'before', 'behind', 'beneath', 'beside', 'besides', 'between', 'beyond', 'by', 'despite', 'during', 'except', 'for', 'from', 'in', 'place', 'of', 'inside', 'instead', 'of', 'into', 'near', 'of', 'on', 'outside', 'over', 'past', 'since', 'through', 'throughout', 'to', 'toward', 'under', 'until', 'up', 'upon', 'without', 'with', 'within');

	auxiliaries := vector('do', 'may', 'might', 'shall', 'will', 'would', 'can', 'could', 'should', 'ought', 'to', 'must', 'will', 'have', 'to', 'shall', 'have', 'to', 'could', 'have', 'to', 'should', 'have', 'to', 'must', 'have', 'to', 'need', 'to', 'try', 'to');
				 
	terminators := vector('.', ';', ':', '?', '!', '--');

	_result := '';
			 
	_actual_length := n * randomNumber (40, 160) / 100;
			 
	while (length(_result) < _actual_length) {
		_temp := sprintf('%s %s %s %s %s %s the %s %s', 
					  aref(ajectives, randomNumber(0, 24)),
					  aref(nouns, randomNumber(0, 40)),
					  aref(auxiliaries, randomNumber(0, 17)),
					  aref(verbs, randomNumber(0, 39)),
					  aref(adverbs, randomNumber(0, 27)),
					  aref(prepositions, randomNumber(0, 46)),
					  aref(nouns, randomNumber(0, 40)),
					  aref(terminators, randomNumber(0, 5))
				);
		if (length (_result) + length (_temp) > _actual_length)
	          _temp := substring (_temp, 1, _actual_length - length (_result));	  
		_result := concat(_result, _temp);
	}
	
	return substring(_result, 1, _actual_length);
};
create procedure fill_nation(in n integer) {
	
	declare _n_nationkey, _n_regionkey integer;
	declare _n_name, _n_comment varchar;
	
	declare namearray, regionarray integer;
	
	namearray := vector ('ALGERIA', 'ARGENTINA','BRAZIL','CANADA','EGYPT','ETHIOPIA','FRANCE','GERMANY','INDIA','INDONESIA','IRAN','IRAQ','JAPAN','JORDAN','KENYA','MOROCCO','MOZAMBIQUE','PERU','CHINA','ROMANIA','SAUDI ARABIA','VIETNAM','RUSSIA','UNITED KINGDOM','UNITED STATES');
	regionarray := vector(0, 1, 1, 1, 4, 0, 3, 3, 2, 2, 4, 4, 2, 4, 0, 0, 0, 1, 2, 3, 4, 2, 3, 3, 1);
				 
	_n_nationkey := 0;
	while (_n_nationkey <= 24) {
		
		_n_name := aref(namearray, _n_nationkey);
		_n_regionkey := aref(regionarray, _n_nationkey);
		_n_comment := randomText(95);
					
		insert into NATION (N_NATIONKEY, N_NAME, N_REGIONKEY, N_COMMENT) values (_n_nationkey, _n_name, _n_regionkey, _n_comment);
		
		_n_nationkey := _n_nationkey + 1;
	}
};
create procedure fill_region(in n integer) {
	
	declare _r_regionkey integer;
	declare _r_name, _r_comment varchar;
	
	declare namearray, regionarray integer;
	
	namearray := vector ('AFRICA', 'AMERICA', 'ASIA', 'EUROPE', 'MIDDLE EAST');
				 
	_r_regionkey := 0;
	while (_r_regionkey <= 4) {
		
		_r_name := aref(namearray, _r_regionkey);
		_r_comment := randomText(95);
					
		insert into REGION (R_REGIONKEY, R_NAME, R_COMMENT) values (_r_regionkey, _r_name, _r_comment);
		
		_r_regionkey := _r_regionkey + 1;
	}
};
create procedure fill_customer (in nStartingRow integer, in NumRows integer) {

	declare _c_custkey, _c_nationkey integer;
	declare _c_name, _c_address, _c_phone, _c_mktsegment, _c_comment varchar;
	declare _c_acctbal numeric(20, 2);
	
	_c_custkey := nStartingRow;
	while (_c_custkey <= NumRows) {
		_c_name := sprintf('Customer#%d', _c_custkey);
		_c_address := random_vString(25);
		_c_nationkey := randomNumber(0, 24);
		_c_phone := randomPhone(_c_nationkey);
		_c_acctbal := randomNumeric(-999.99, 9999.99, 100);
		_c_mktsegment := randomSegment(0);
		_c_comment := randomText(73);
					
		insert into CUSTOMER (C_CUSTKEY, C_NAME, C_ADDRESS, C_NATIONKEY, C_PHONE, C_ACCTBAL, C_MKTSEGMENT, C_COMMENT) values (_c_custkey, _c_name, _c_address, _c_nationkey, _c_phone, _c_acctbal, _c_mktsegment, _c_comment);
		_c_custkey := _c_custkey + 1;
	}
};
create procedure fill_lineitems_for_order(in SF float, in _o_orderkey integer, in _o_orderdate date, out _o_orderstatus character(1), out _o_totalprice numeric(20, 2)) {
   
	declare _l_orderkey, _l_partkey, _l_suppkey, _l_linenumber  integer;
	declare _l_returnflag, _l_linestatus, _l_shipinstruct, _l_shipmode,  _l_comment varchar;
	declare _l_quantity, _l_extendedprice, _l_discount, _l_tax varchar;
	declare _l_shipdate, _l_commitdate, _l_receiptdate date;
	
	declare numLines, suppIndex, numFs, numOs integer;
	declare _p_retailprice numeric(20, 2);
	declare currentDate date;
	declare S integer;

        S := cast (SF * 10000 as integer);
	
	currentDate := stringdate('1995.06.17');
	numLines := randomNumber(1, 7);
	_l_linenumber := 1;
	_o_totalprice := 0;
	suppIndex := 0;
	numFs := 0;
	numOs := 0;
	while (_l_linenumber <= numLines) {
		_l_orderkey := _o_orderkey;
		_l_partkey := randomNumber(1, cast (200000 * SF as integer));
		_l_suppkey := mod(_l_partkey + (mod(suppIndex, 4) * (S/4 + (_l_partkey - 1)/S)), S + 1);
		_l_quantity := randomNumeric(1, 50, 1);
	
	        _p_retailprice := (90000 + mod(_l_partkey/10, 20001) + 100 * mod(_l_partkey, 1000))/100;

		_l_extendedprice := _l_quantity * _p_retailprice;
		_l_discount := randomNumeric(0.0, 0.10, 100);
		_l_tax := randomNumeric(0.0, 0.08, 100);
		_l_shipdate := dateadd('day', randomNumber(1, 121), _o_orderdate);
		_l_commitdate := dateadd('day', randomNumber(30, 90), _o_orderdate);
		_l_receiptdate := dateadd('day', randomNumber(1, 30), _l_shipdate);
		if (datediff('day', _l_receiptdate, currentDate) > 0) {
			if (randomNumber(0, 1) > 0)
				_l_returnflag := 'R';
			else
				_l_returnflag := 'A';
		} else
			_l_returnflag := 'N';
		
		if (datediff('day', _l_shipdate, currentDate) > 0) {
			_l_linestatus := 'F';
			numFs := numFs + 1;
		} else {
			_l_linestatus := 'O';
			numOs := numOs + 1;
		}
		
		_l_shipinstruct := randomInstruction(0);
		_l_shipmode := randomMode(0);
		_l_comment := randomText(27);
	
		_o_totalprice := _o_totalprice + (_l_extendedprice * (1 + _l_tax) * (1 - _l_discount));
		suppIndex := suppIndex + 1;
		
		insert into LINEITEM (L_ORDERKEY, L_PARTKEY, L_SUPPKEY, L_LINENUMBER, L_QUANTITY, L_EXTENDEDPRICE, L_DISCOUNT, L_TAX, L_RETURNFLAG, L_LINESTATUS, L_SHIPDATE, L_COMMITDATE, L_RECEIPTDATE, L_SHIPINSTRUCT, L_SHIPMODE, L_COMMENT) values (_l_orderkey, _l_partkey, _l_suppkey, _l_linenumber, _l_quantity, _l_extendedprice, _l_discount, _l_tax, _l_returnflag, _l_linestatus, _l_shipdate, _l_commitdate, _l_receiptdate, _l_shipinstruct, _l_shipmode, _l_comment);
		_l_linenumber := _l_linenumber + 1;
	}
	if (numOs > 0) {
	    if (numFs = 0)
			_o_orderstatus := 'O';
	    else
		    _o_orderstatus := 'P';
	} else {
		if (numFs = 0)
		    _o_orderstatus := 'P';
	    else
			_o_orderstatus := 'F';
	}
};

create procedure fill_orders (in SF float, in nStartingGroup integer, in NumGroups integer) {

	declare _o_orderkey, _o_custkey, _o_shippriority integer;
	declare _o_orderstatus, _o_orderpriority, _o_clerk, _o_comment varchar;
	declare _o_totalprice numeric(20, 2);
	declare _o_orderdate date;
	
	declare currentGroup, groupIndex, helper1 integer;
	declare startdate, enddate date;
	
	startdate := stringdate('1992.01.01');
	enddate := stringdate('1998.12.31');
	currentGroup := nStartingGroup;

	while (currentGroup <= NumGroups) {
		groupIndex := 0;
		while (groupIndex < 8) {
			_o_orderkey := (currentGroup - 1) * 32 + 1 + groupIndex;
			_o_custkey := randomNumber(1, cast (150000 * SF as integer));
			while (mod(_o_custkey, 3) = 0)
				_o_custkey := randomNumber(1, cast (150000 * SF as integer));
			_o_orderdate := 
					dateadd('day', 
						randomNumber(0, 
							datediff('day', 
								startdate, 
								dateadd('day', -151, enddate)
							)
						), 
						startdate
					);
			_o_orderpriority := randomPriority(0);
			_o_clerk := sprintf('Clerk#%d', randomNumber(1, cast (1000 * SF as integer)));
			_o_shippriority := 0;
			_o_comment := randomText(49);

			fill_lineitems_for_order(SF, _o_orderkey, _o_orderdate, _o_orderstatus, _o_totalprice);
			
			insert into ORDERS (O_ORDERKEY, O_CUSTKEY, O_ORDERSTATUS, O_TOTALPRICE, O_ORDERDATE, O_ORDERPRIORITY, O_CLERK, O_SHIPPRIORITY, O_COMMENT) values (_o_orderkey, _o_custkey, _o_orderstatus, _o_totalprice, _o_orderdate, _o_orderpriority, _o_clerk, _o_shippriority, _o_comment);
			
			groupIndex := groupIndex + 1;
		}
		currentGroup := currentGroup + 1;
	}
};

create procedure fill_part (in nStartingRow integer, in NumRows integer) {
	
	declare _p_partkey, _p_size integer;
	declare _p_name, _p_mfgr, _p_brand, _p_type, _p_container, _p_comment varchar;
	declare _p_retailprice numeric(20, 2);
	
	declare words, nMfgr, nWord integer;
	
	words := vector('almond', 'antique', 'aquamarine', 'azure', 'beige', 'bisque', 'black', 'blanched', 
			'blue', 'blush', 'brown', 'burlywood', 'burnished', 'chartreuse', 'chiffon', 'chocolate', 
			'coral', 'cornflower', 'cornsilk', 'cream', 'cyan', 'dark', 'deep', 'dim', 'dodger', 'drab', 
			'firebrick', 'floral', 'forest', 'frosted', 'gainsboro', 'ghost', 'goldenrod', 'green', 'grey', 
			'honeydew', 'hot', 'indian', 'ivory', 'khaki', 'lace', 'lavender', 'lawn', 'lemon', 'light', 
			'lime', 'linen', 'magenta', 'maroon', 'medium', 'metallic', 'midnight', 'mint', 'misty', 
			'moccasin', 'navajo', 'navy', 'olive', 'orange', 'orchid', 'pale', 'papaya', 'peach', 'peru', 
			'pink', 'plum', 'powder', 'puff', 'purple', 'red', 'rose', 'rosy', 'royal', 'saddle', 'salmon', 
			'sandy', 'seashell', 'sienna', 'sky', 'slate', 'smoke', 'snow', 'spring', 'steel', 'tan', 
			'thistle', 'tomato', 'turquoise', 'violet', 'wheat', 'white', 'yellow');
	
	_p_partkey := nStartingRow;
	while (_p_partkey <= NumRows) {
		nWord := 0;
		_p_name := '';
		while (nWord < 5) {
			_p_name := concat(_p_name, aref(words, randomNumber(0, length(words) - 1)), ' ');
			nWord := nWord + 1;
		}

		nMfgr := randomNumber(1, 5);
		_p_mfgr := sprintf('Manufacturer#%d', nMfgr);
		_p_brand := sprintf('Brand#%d%d', nMfgr, randomNumber(1, 5));
		_p_type := randomType(0);
		_p_size := randomNumber(1, 50);
		_p_container := randomContainer(0);
		_p_retailprice := (90000 + mod(_p_partkey/10, 20001) + 100 * mod(_p_partkey, 1000))/100;
		_p_comment := randomText(14);
		
		insert into PART (P_PARTKEY, P_NAME, P_MFGR, P_BRAND, P_TYPE, P_SIZE, P_CONTAINER, P_RETAILPRICE, P_COMMENT) values (_p_partkey, _p_name, _p_mfgr, _p_brand, _p_type, _p_size, _p_container, _p_retailprice, _p_comment);
		_p_partkey := _p_partkey + 1;
	}
};
create procedure fill_partsupp (in SF float, in nStartingRow integer, in NumRows integer) {
	
	declare _ps_partkey, _ps_suppkey, _ps_availqty integer;
	declare _ps_comment varchar;
	declare _ps_supplycost numeric(20, 2);
	declare subRow integer;
	declare S integer;

        S := cast (SF * 10000 as integer);
	
	_ps_partkey := nStartingRow;
	while (_ps_partkey <= NumRows) {
		subRow := 0;
		while (subRow < 4) {
			_ps_suppkey := mod(_ps_partkey + ( subRow * ( S/4 + (_ps_partkey - 1)/S ) ), S + 1);
			_ps_availqty := randomNumber(1, 9999);
			_ps_supplycost := randomNumeric(1, 1000, 1);
			_ps_comment := randomText(124);
			
			insert into PARTSUPP (PS_PARTKEY, PS_SUPPKEY, PS_AVAILQTY, PS_SUPPLYCOST, PS_COMMENT)  values (_ps_partkey, _ps_suppkey, _ps_availqty, _ps_supplycost, _ps_comment);
			subRow := subRow + 1;
		}
		_ps_partkey := _ps_partkey + 1;
	}
};
create procedure fill_supplier (in initial_suppkey integer, in NumRows integer) 
{
	
	declare _s_suppkey, _s_nationkey integer;
	declare _s_name, _s_address, _s_phone, _s_comment varchar;
	declare _s_acctbal numeric;
	
	_s_suppkey := initial_suppkey;
	
	while (_s_suppkey <= NumRows) {
		
		_s_name := concat('Supplier#', sprintf('%d', _s_suppkey));
		_s_address := random_vString(25);
		_s_nationkey := randomNumber(0, 24);
		_s_phone := randomPhone(_s_nationkey);
		_s_acctbal := randomNumeric(-999.99, 9999.99, 100);
		_s_comment := randomText(63);
		
		
		insert into SUPPLIER (S_SUPPKEY, S_NAME, S_ADDRESS, S_NATIONKEY, S_PHONE, S_ACCTBAL, S_COMMENT) values (_s_suppkey, _s_name, _s_address, _s_nationkey, _s_phone, _s_acctbal, _s_comment);
		_s_suppkey := _s_suppkey + 1;
	}
};
create procedure supplier_add_random(in SF float, in nNumRows integer) {
	
	declare _strHelper varchar;
	declare s, _nHelper1, _nHelper2, _nHelper3 integer;

	_nHelper2 := 0;
	while (_nHelper2 < (5 * SF)) {
		_nHelper3 := randomNumber(1, nNumRows);
		declare cr1 cursor for 
			select s_suppkey, s_comment from supplier where s_suppkey = _nHelper3;
		
		open cr1;
		fetch cr1 into s, _strHelper;

		update supplier set s_comment = 'CustomerComplaints' where s_suppkey = s;
		_nHelper2 := _nHelper2 + 1;
		close cr1;

	}

	_nHelper2 := 0;
	while (_nHelper2 < (5 * SF)) {
		_nHelper3 := randomNumber(1, nNumRows);
		declare cr2 cursor for 
			select s_suppkey, s_comment from supplier where s_suppkey = _nHelper3;
		
		open cr2;
		fetch cr2 into s, _strHelper;

		update supplier set s_comment = 'CustomerRecommends' where s_suppkey = s;
		_nHelper2 := _nHelper2 + 1;
		close cr2;
	}
};

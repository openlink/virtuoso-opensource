

echo "reset stats\n";
select db_activity ();

set echo on;


__dbf_set ('dc_batch_sz', 1);
select count (*) from $u{tb} a, $u{tb} b where a.k2 = b.k1 option (loop, order);
select db_activity ();


__dbf_set ('dc_batch_sz', 10000);
select count (*) from $u{tb} a, $u{tb} b where a.k2 = b.k1 option (loop, order);
select db_activity ();


__dbf_set ('dc_batch_sz', 100000);
select count (*) from $u{tb} a, $u{tb} b where a.k2 = b.k1 option (loop, order);
select db_activity ();


__dbf_set ('dc_batch_sz', 1000000);
select count (*) from $u{tb} a, $u{tb} b where a.k2 = b.k1 option (loop, order);
select db_activity ();


__dbf_set ('dc_batch_sz', 10000);
__dbf_set ('enable_dyn_batch_sz', 1);
echo "automatic vector size\n";
select count (*) from $u{tb} a, $u{tb} b where a.k2 = b.k1 option (loop, order);
select db_activity ();

__dbf_set ('enable_dyn_batch_sz', 0);

-- make sure no partitioned hash join
__dbf_set ('chash_space_avail', 4000000000);

echo both "compare with invisible hash join (hash lookup not vectored)\n";
select count (*) from $u{tb} a, $u{tb} b where a.k2 = b.k1 option (hash, order);
select db_activity ();

echo both "compare with vectored hash join\n";
select count (*) from $u{tb} a, $u{tb} b where a.k2 + 0 = b.k1 option (hash, order);
select db_activity ();

echo both "compare with vectored hash join, no unq int opt\n";
select count (*) from $u{tb} a, $u{tb} b where a.k1 = b.k2 option (hash, order);
select db_activity ();


__dbf_set ('chash_space_avail', 500000000);
echo both "compare with vectored hash join in 4 partitions\n";
select count (*) from $u{tb} a, $u{tb} b where a.k2 + 0 = b.k1 option (hash, order);
select db_activity ();



echo both "compare with random access coming in order (like merge)\n";
select count (*) from $u{tb} a, $u{tb} b where a.k1 = b.k1 option (loop, order);
select db_activity ();




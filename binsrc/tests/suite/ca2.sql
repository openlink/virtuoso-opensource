--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2017 OpenLink Software
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




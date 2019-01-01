--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2019 OpenLink Software
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

create procedure csv_ld_load (in f varchar, in tbl varchar)
{
  if (f like '%.gz')
    csv_vec_load (gz_file_open (f), 0, null, tbl, 2, vector ('csv-delimiter', '|', 'lax', 1, 'txn', 0));
  else
    csv_vec_load (file_open (f), 0, null, tbl, 2, vector ('csv-delimiter', '|', 'lax', 1, 'txn', 0));
}
;

ld_dir ('$U{TPCH_DATA_DIR}', 'supplier.tbl*', 'sql:csv_ld_load (?, \'DB.DBA.SUPPLIER\' )');
ld_dir ('$U{TPCH_DATA_DIR}', 'customer.tbl*', 'sql:csv_ld_load (?, \'DB.DBA.CUSTOMER\' )');
ld_dir ('$U{TPCH_DATA_DIR}', 'part.tbl*',     'sql:csv_ld_load (?, \'DB.DBA.PART\'     )');
ld_dir ('$U{TPCH_DATA_DIR}', 'partsupp.tbl*', 'sql:csv_ld_load (?, \'DB.DBA.PARTSUPP\' )');
ld_dir ('$U{TPCH_DATA_DIR}', 'orders.tbl*',   'sql:csv_ld_load (?, \'DB.DBA.ORDERS\'   )');
ld_dir ('$U{TPCH_DATA_DIR}', 'lineitem.tbl*', 'sql:csv_ld_load (?, \'DB.DBA.LINEITEM\' )');

delete from load_list where ll_file like '%.u%';

csv_vec_load (file_open ('$U{TPCH_DATA_DIR}/region.tbl'), 0, null, 'DB.DBA.REGION', 3, vector ('csv-delimiter', '|', 'lax', 1, 'txn', 0));
csv_vec_load (file_open ('$U{TPCH_DATA_DIR}/nation.tbl'), 0, null, 'DB.DBA.NATION', 3, vector ('csv-delimiter', '|', 'lax', 1, 'txn', 0));

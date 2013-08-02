
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

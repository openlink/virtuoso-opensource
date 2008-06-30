


create table split (k varchar primary key, d varchar);

create table pg (k int primary key);

create procedure  fill_split (in n int)
{
  declare c int;
  for (c:=0; c<n; c:=c+1)
   insert into split values (sprintf ('%.8d', c), 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx');
}

-- 350 rows per page, 400 leaf pointers per page. 3  

log_enable (2);
fill_split (1000000);
checkpoint;
__dbf_set ('dbf_no_disk', 1);
update split set k = k || make_string (1200) where k < '00000200';

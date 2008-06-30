-- procedure view blob test

create procedure pvb (in n int, in len int)
{
  declare ctr int;
  declare bl long nvarchar;
  result_names (ctr, bl);
  for (ctr := 0; ctr < n; ctr := ctr + 1)
    result (ctr, make_string (n));
}



create procedure view n_blobs  as pvb (n, len) (n int, bl long nvarchar);

create table vbs (k int primary key, dt long nvarchar);

insert into vbs (k, dt) select k, bl from n_blobs where n = 10 and len = 200000;


create table txml (k int primary key,dt xmltype);

insert into txml (k, dt) values (1, '<a>pfaal</a>');


create procedure bfa ()
{
  declare _b1 any;
  select b1 into _b1 from blobs where row_no = 1;
  update blobs set b1 = null where row_no = 1;
  commit work;
  update  blobs set b1 = make_string (5000) where row_no = 1;
  update blobs set b1 = _b1 where row_no = 1;
  commit work;
  return blob_to_string ((select b1 from blobs where row_no = 1));
}



bfa ();

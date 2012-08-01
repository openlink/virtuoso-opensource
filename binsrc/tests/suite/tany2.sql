

ECHO BOTH "Any number collation\n";


drop table tnum;
create table tnum (k any, id int identity, primary key (k, id))
  alter index tnum on tnum partition (k varchar (-1, 0hexffff));

create procedure nfill (in ctr int)
{
  declare c, t int;
  declare n any;
  for (c:=0; c < ctr; c := c + 1)
    {
    t := rnd (7);
      if (t < 4)
      n := rnd (1000000);
      else if (t = 4)
      n := cast (rnd (1000000000) as real) / 1000;
      else if (t = 5)
      n := cast (rnd (1000000000) as double precision) / 1000;
      else if (t = 6)
      n := cast (rnd (1000000000) as decimal) / 1000;
      insert into tnum (k) values (n);
    }
}

create procedure cins (in n any)
{
  commit work;
  insert into tnum (k) values (n);
  if ((select count (*) from tnum a table option (index primary key) where not exists (select 1 from tnum b table option (loop, index primary key) where a.k = b.k and a.id = b.id)))
    {
      rollback work;
      dbg_obj_print ('gone bad at ', n, ' ', __tag (n));

      signal ('numxx', 'any num out of whack');
    }
}


create procedure controversy (in exp int)
{
  declare n int;
  for (n := -50; n < 50; n := n + 1)
    {
      cins (bit_shift (1, exp) + n);
      cins (bit_shift (1, exp) + n);
      cins (cast (bit_shift (1, exp) + n as real));
      cins (cast (bit_shift (1, exp) + n as double precision));
      cins (cast (bit_shift (1, exp) + n as numeric));
      cins (cast (bit_shift (1, exp) + n  as double precision) + cast (0.5 as double precision));
      cins (cast (bit_shift (1, exp) + n as numeric) + 0.5);
    }
  return (select count (*) from tnum a table option (index primary key) where not exists (select 1 from tnum b table option (loop, index primary key) where a.k = b.k and a.id = b.id));
}

select controversy (52);
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": controversy 52\n";

select controversy (53);
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": controversy 53\n";

nfill (100000);

select count (*) from tnum a, tnum b where a.k = b.k and a.id = b.id option (loop);

create bitmap index ii on tnum (k, id) partition (k varchar (-1, 0hexffff));

select count (*) from tnum a table option (index ii), tnum b table option (index ii) where a.k = b.k and a.id = b.id option (loop, order);

select count (*) from tnum a table option (index primary key), tnum b table option (index primary key) where a.k = b.k and a.id = b.id option (loop, order);



select __tag (k),  * from tnum a table option (index ii) where not exists (select 1 from tnum b table option (loop, index primary key) where a.k = b.k and a.id = b.id);
ECHO BOTH $IF $EQU $ROWCNT 0 "PASSED" "***FAILED";
ECHO BOTH ": any num coll 1\n";

select __tag (k),  * from tnum a table option (index primary key) where not exists (select 1 from tnum b table option (loop, index ii) where a.k = b.k and a.id = b.id);
ECHO BOTH $IF $EQU $ROWCNT 0 "PASSED" "***FAILED";
ECHO BOTH ": any num coll 2\n";



create procedure num_order ()
{
  declare prev any;
 prev := null;
  for select k from tnum table option (index primary key) do {
    if (prev > k)
      {
	dbg_obj_print (prev, ' >  ', k, __tag (prev), ' ', __tag (k));
      }
    if (prev = k and __tag (prev) <> __tag (k))
      {
	dbg_obj_print (prev, ' =  ', k, ' ', __tag (prev), ' ', __tag (k), ' diff ', k - prev );
      }
  prev := k;
  }
}

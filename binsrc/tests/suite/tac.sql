

-- autocompact 

echo both "Autocompact and vacuum test\n";


create table tac (s varchar primary key, d varchar);

create procedure tac_fill (in n1 int, in n2 int)
{
  declare i int;
  for (i:= n1; i < n2; i := i + 1)
    insert into tac values (cast (i as varchar) || make_string (900), cast (i as varchar));
}


tac_fill (0, 10);
delete from tac where atoi (s) > 3;
autocompact ();

echo both "tac 1\n";

delete from tac;
tac_fill (0, 10);
delete from tac where atoi (s) > 3 and atoi (s) < 9;
autocompact ();
echo both "tac 2\n";


delete from tac;
tac_fill (1, 10);
delete from tac where atoi (s) > 3 and atoi (s) < 9;
vacuum ('DB.DBA.TAC');
echo both "tac 3\n";

delete from tac;
tac_fill (0, 1000);
delete from tac where atoi (s) > 500 and mod (atoi (s), 10) <> 0;
autocompact ();
echo both "tac 4\n";


delete from tac;
tac_fill (0, 1000);
delete from tac where atoi (s) > 500 and mod (atoi (s), 10) <> 0;
vacuum ('DB.DBA.TAC');
vacuum ('DB.DBA.TAC');
vacuum ('DB.DBA.TAC');
vacuum ('DB.DBA.TAC');
echo both "tac 5\n";


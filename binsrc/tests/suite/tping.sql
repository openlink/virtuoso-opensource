
-- use a local t1 or attach it from remote.  Use differentr sizes and run with or without row_no 100000.


create procedure ut1 (in n int)
{
  declare ctr int;
  for (ctr := 0; ctr < n; ctr := ctr + 1)
 	    update t1 set fi2 = fi2 + 1 where row_no = 100000;
}


create procedure ust1 (in n int, in len int := 10000)
{
  declare ctr int;
  declare str varchar;
  str := make_string (len);
  for (ctr := 0; ctr < n; ctr := ctr + 1)
     update t1 set fs4 = str, fi2 = fi2 + 1 where row_no = 100000;
}

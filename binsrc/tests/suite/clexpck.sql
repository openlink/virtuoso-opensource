
-- Cluster explain check.  Get the query and look for expected regexp in compilation 


create procedure explain_check (in q varchar, in r varchar)
{
  declare st, msg, res, md, inx, str, m any;
  if (sys_stat ('cl_run_local_only'))
    return;
 str := '';
  st := '00000';
  exec ('explain (?)', st, msg, vector (q), 0, md, res);
  if (st <> '00000') signal (st, msg);
  for (inx := 0; inx < length (res); inx := inx + 1)
    str := str || res[inx][0];
  m := regexp_match (r, str);
  if (m is null)
    signal ('xxxxx', sprintf ('Expected compilation to match %s for %s', r, q));
  return str;
}

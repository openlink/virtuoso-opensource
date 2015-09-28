create procedure dump_tb (in tb varchar, in fname varchar)
{
  declare s, st, data, meta any;
  declare i, j int;
  i := 0;
  s := string_output ();
  http ('SET MACRO_SUBSTITUTION OFF;\n', s);
  http (sprintf ('delete from %s;\n', tb), s);
  http (sprintf ('insert into %s (', tb), s);
  for select \column as cn from SYS_COLS where \table = tb order by col_id do
    {
      if (i > 0)
      http (',', s);
      http (cn, s);
      i := i + 1;
    }
  http (') values (' , s);
  st := string_output_string (s);
  s := string_output ();
  exec (sprintf ('select * from %s', tb), null, null, vector (), 0, meta, data);
  for (i := 0; i < length (data); i := i + 1)
    {
      declare rw any;
      http (st, s);
      rw := data[i];
      for (j := 0; j < length (rw); j := j + 1)
        {
          if (j > 0)
	    http (',', s);
	  http (sys_sql_val_print (rw[j]), s);  
       }
      http (');\n', s);
    }
  string_to_file (fname, s, -2);
}
;

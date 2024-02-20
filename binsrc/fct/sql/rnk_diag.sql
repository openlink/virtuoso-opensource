create procedure rnk_diagram() returns float
{
  declare i int;
  declare ret float;
  result_names(i, ret);
  for (i := 0; i <= 0hexffff; i := i + 1)
  {
    result (i, rnk_scale (i));
  }
};

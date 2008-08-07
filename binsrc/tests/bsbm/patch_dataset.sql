create procedure patch_nulls_in_offers ()
{
  log_enable (0);
  declare offerid, productid, producerid integer;
  declare c cursor for select nr, product from Offer where producer is null for update;
  whenever not found goto c_done;
  open c;
fetch_c:
  fetch c into offerid, productid;
  producerid := (select producer from Product where nr=productid);
  update Offer set producer=producerid where current of c;
  if (mod (offerid, 10000) = 0)
    {
      commit work;
      dbg_obj_princ (offerid);
    }
  goto fetch_c;
c_done:
  commit work;
  close c;
  log_enable (1);
}
;

create procedure patch_nulls_in_reviews ()
{
  log_enable (0);
  declare reviewid, productid, producerid integer;
  declare c cursor for select nr, product from Review where producer is null for update;
  whenever not found goto c_done;
  open c;
fetch_c:
  fetch c into reviewid, productid;
  producerid := (select producer from Product where nr=productid);
  update Review set producer=producerid where current of c;
  if (mod (reviewid, 10000) = 0)
    {
      commit work;
      dbg_obj_princ (reviewid);
    }
  goto fetch_c;
c_done:
  commit work;
  close c;
  log_enable (1);
}
;

patch_nulls_in_offers();
patch_nulls_in_reviews();
checkpoint;

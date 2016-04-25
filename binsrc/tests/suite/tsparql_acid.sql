--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2016 OpenLink Software
--
--  This project is free software; you can redistribute it and/or modify it
--  under the terms of the GNU General Public License as published by the
--  Free Software Foundation; only version 2 of the License, dated June 1991.
--
--  This program is distributed in the hope that it will be useful, but
--  WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
--  General Public License for more details.
--
--  You should have received a copy of the GNU General Public License along
--  with this program; if not, write to the Free Software Foundation, Inc.,
--  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
--
--
create function DB.DBA.ACCT_IRI (in n integer) { return sprintf ('http://bibm32/%d', n); }
;

create procedure DB.DBA.BSBM_ACID_INIT (in accts_count integer := 64)
{
  declare ctr integer;
  set isolation='serializable';
  sparql clear graph <http://bibm32/acid>;
  commit work;
  for (ctr := 0; ctr < accts_count; ctr := ctr + 1)
    {
      declare bal integer;
      bal := 1000000 + 1000 * ctr;
      sparql insert in <http://bibm32/acid> {
          `iri(sql:ACCT_IRI(?:ctr))` a <http://bibm32/acct> ;
              <http://bibm32/balance> ?:bal ;
              <http://bibm32/initial-balance> ?:bal . };
    }
  commit work;
  __ddl_changed ('DB.DBA.RDF_QUAD');
}
;

create procedure DB.DBA.BSBM_ONE_OP (in acc_from integer, in acc_to integer, in op_sum integer)
{
  set isolation='serializable';
  if (acc_from = acc_to)
    signal ('_ACID', 'Self-transfer?');
  whenever sqlstate '*' goto done;
  if (not rnd(4))
    {
      sparql modify <http://bibm32/acid>
      delete { ?afrom <http://bibm32/balance> ?afrombal . ?ato <http://bibm32/balance> ?atobal . }
      insert {
          ?afrom <http://bibm32/balance> `?afrombal - ?:op_sum` .
          ?ato <http://bibm32/balance> `?atobal + ?:op_sum` .
          [] a <http://bibm32/op> ;
              <http://bibm32/from> ?afrom ;
              <http://bibm32/to> ?ato ;
              <http://bibm32/opsum> ?:op_sum }
      from <http://bibm32/acid>
      where {
          ?afrom <http://bibm32/balance> ?afrombal . filter (?afrom = iri(sql:ACCT_IRI(?:acc_from)))
          ?ato <http://bibm32/balance> ?atobal . filter (?ato = iri(sql:ACCT_IRI(?:acc_to)))
        };
    }
  else
    {
      declare old_from_bal, old_to_bal integer;
      old_from_bal := (sparql select ?afrombal
        from <http://bibm32/acid>
        where {
            `iri(sql:ACCT_IRI(?:acc_from))` <http://bibm32/balance> ?afrombal . } );
      old_to_bal := (sparql select ?atobal
        from <http://bibm32/acid>
        where {
            `iri(sql:ACCT_IRI(?:acc_to))` <http://bibm32/balance> ?atobal . } );
      sparql delete from <http://bibm32/acid>
        {
          `iri(sql:ACCT_IRI(?:acc_from))` <http://bibm32/balance> ?:old_from_bal .
          `iri(sql:ACCT_IRI(?:acc_to))` <http://bibm32/balance> ?:old_to_bal . };
      if (not rnd (8))
        {
          rollback work;
          goto done;
        }
      sparql insert in <http://bibm32/acid> {
          `iri(sql:ACCT_IRI(?:acc_from))` <http://bibm32/balance> `?:old_from_bal - ?:op_sum` . };
      if (not rnd (8))
        {
          rollback work;
          goto done;
        }
      sparql insert in <http://bibm32/acid> {
          `iri(sql:ACCT_IRI(?:acc_to))` <http://bibm32/balance> `?:old_to_bal + ?:op_sum` . };
      if (not rnd (8))
        {
          rollback work;
          goto done;
        }
      sparql insert in <http://bibm32/acid> {
          [] a <http://bibm32/op> ;
              <http://bibm32/from> `iri(sql:ACCT_IRI(?:acc_from))` ;
              <http://bibm32/to> `iri(sql:ACCT_IRI(?:acc_to))` ;
              <http://bibm32/opsum> ?:op_sum };
    }
  if (not rnd (4))
    {
      rollback work;
      goto done;
    }
  commit work;
done:;
}
;


create procedure DB.DBA.BSBM_ACID_TEST_C (in accts_count integer := 64, in loops integer := 10000)
{
  declare ctr integer;
  for (ctr := 0; ctr < loops; ctr := ctr + 1)
    {
      declare acc_from, acc_to, op_sum integer;
      acc_from := rnd (accts_count);
      acc_to := mod (acc_from + 1 + rnd (accts_count - 1), accts_count);
      op_sum := 10 + rnd (100);
      DB.DBA.BSBM_ONE_OP (acc_from, acc_to, op_sum);
    }
}
;

create procedure DB.DBA.BSBM_ACID_TEST_AI (in accts_count integer := 64, in loops integer := 10000)
{
  declare ctr integer;
  declare aq any;
  aq := async_queue (16);
  for (ctr := 0; ctr < loops; ctr := ctr + 1)
    {
      declare acc_from, acc_to, op_sum integer;
      acc_from := rnd (accts_count);
      acc_to := mod (acc_from + 1 + rnd (accts_count - 1), accts_count);
      op_sum := 10 + rnd (100);
      aq_request (aq, 'DB.DBA.BSBM_ONE_OP', vector (acc_from, acc_to, op_sum));
    }
  aq_wait_all (aq);
}
;


create procedure DB.DBA.BSBM_ACID_CHECK_CONSISTENCY (in accts_count integer := 64, in open_result integer := 1)
{
  declare ctr integer;
  declare initial_sum, actual_sum, outgoing_sum, incoming_sum integer;
  declare ERR varchar;
  set isolation='serializable';
  if (open_result)
    result_names (ERR);
  initial_sum := coalesce ((sparql select sum(?bal) from <http://bibm32/acid> { ?s a <http://bibm32/acct> ; <http://bibm32/initial-balance> ?bal . }), 0);
  actual_sum := coalesce ((sparql select sum(?bal) from <http://bibm32/acid> { ?s a <http://bibm32/acct> ; <http://bibm32/balance> ?bal . }), 0);
  if (initial_sum <> actual_sum)
    result (sprintf ('***FAILED: Total sum of balances mismatches: initial %d, actual %d', initial_sum, actual_sum));
  outgoing_sum := coalesce ((sparql select sum (?opsum) from <http://bibm32/acid>
          where { ?s a <http://bibm32/op> ; <http://bibm32/opsum> ?opsum . } ), 0 );
  dbg_obj_princ ('Total sum of operations is ', outgoing_sum);
  for (sparql select ?s ?afrom ?ato ?op_sum from <http://bibm32/acid>
      where { ?s a <http://bibm32/op> .
          optional { ?s <http://bibm32/from> ?afrom }
          optional { ?s <http://bibm32/to> ?ato }
          optional { ?s <http://bibm32/opsum> ?op_sum } } ) do
    {
      if ("afrom" is null or "ato" is null or "op_sum" is null)
        {
          result (sprintf ('***FAILED: Incomplete operation %s: %s money from %s to %s', "s",
              coalesce ("afrom", 'NOWHERE'), coalesce ("ato", 'NOWHERE'), coalesce (cast ("op_sum" as varchar), 'UNSET') ) );
        }
    }
  for (ctr := 0; ctr < accts_count; ctr := ctr + 1)
    {
      initial_sum := coalesce ((sparql select sum (?bal) from <http://bibm32/acid>
          where { `iri(sql:ACCT_IRI(?:ctr))` <http://bibm32/initial-balance> ?bal . } ),
        0 );
      incoming_sum := coalesce ((sparql select sum (?opsum) from <http://bibm32/acid>
          where { ?s a <http://bibm32/op> ; <http://bibm32/to> `iri(sql:ACCT_IRI(?:ctr))` ; <http://bibm32/opsum> ?opsum . } ),
        0 );
      outgoing_sum := coalesce ((sparql select sum (?opsum) from <http://bibm32/acid>
          where { ?s a <http://bibm32/op> ; <http://bibm32/from> `iri(sql:ACCT_IRI(?:ctr))` ; <http://bibm32/opsum> ?opsum . } ),
        0 );
      actual_sum := coalesce ((sparql select sum (?bal) from <http://bibm32/acid>
          where { `iri(sql:ACCT_IRI(?:ctr))` <http://bibm32/balance> ?bal . } ),
        0 );
      if (initial_sum + incoming_sum - outgoing_sum <> actual_sum)
        result (sprintf ('***FAILED: For account %d, %d initial + %d incoming - %d outgoing = %d, actual %d',
            ctr, initial_sum, incoming_sum, outgoing_sum, initial_sum + incoming_sum - outgoing_sum, actual_sum ) );
    }
  commit work;
}
;

create procedure DB.DBA.BSBM_ACID_TEST (in accts_count integer := 64)
{
  declare ERR varchar;
  result_names (ERR);
  DB.DBA.BSBM_ACID_INIT (accts_count);
  DB.DBA.BSBM_ACID_TEST_C (accts_count, __max (accts_count * 16, 1000));
  DB.DBA.BSBM_ACID_CHECK_CONSISTENCY (accts_count, 0);
  DB.DBA.BSBM_ACID_TEST_AI (accts_count, __max (accts_count * 16, 1000));
  DB.DBA.BSBM_ACID_CHECK_CONSISTENCY (accts_count, 0);
}
;


--log_enable (3, 0);
--DB.DBA.BSBM_ACID_TEST ();
--log_enable (1, 0);

DB.DBA.BSBM_ACID_TEST ()
;

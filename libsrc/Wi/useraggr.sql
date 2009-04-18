--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2006 OpenLink Software
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
--!AWK PUBLIC
create procedure STD_COUNT (in _env varchar)
{
	return aref (deserialize(_env), 0);
}
;

--!AWK PUBLIC
create procedure STD11_INIT (inout _env varchar)
{
	_env := serialize (vector (0, 0.0));
}
;

--!AWK PUBLIC
create procedure STD12_INIT (inout _env varchar)
{
	_env := serialize (vector (0, 0.0,0.0));
}
;

--!AWK PUBLIC
create procedure STD13_INIT (inout _env varchar)
{
        _env := serialize (vector (0, 0.0,0.0, 0.0));
}
;

--!AWK PUBLIC
create procedure VAR_ACC (inout _env varchar, in val numeric)
{
	if (_env is null)
		return;
	if (val is null)
		return;
	declare ctx any;
	ctx := deserialize (_env);

	aset( ctx, 1, aref (ctx, 1) + val);
	aset( ctx, 2, aref (ctx, 2) + val*val);
	aset( ctx, 0, aref (ctx, 0) + 1);
	_env := serialize (ctx);
}
;

--!AWK PUBLIC
create procedure VAR_POP_FIN (inout _ctx varchar)
{
	if (_ctx is null)
		return null;
	declare _env any;
	_env := deserialize (_ctx);
	declare c integer;
	c := aref (_env, 0);
	if (c = 0)
		return null;
	return  (aref (_env, 2) - aref (_env, 1) * aref (_env, 1) / c) / c;
}
;

--!AWK PUBLIC
create procedure VAR_SAMP_FIN (inout _ctx varchar)
{
        if (_ctx is null)
                return null;
        declare _env any;
        _env := deserialize (_ctx);
        declare c integer;
        c := aref (_env, 0);
        if (c = 0)
                return null;
	if (c = 1)
		return 0.0;
        return  (aref (_env, 2) - aref (_env, 1) * aref (_env, 1) / c) / (c - 1);
}
;

--!AWK PUBLIC
create procedure VAR_FIN (inout _ctx varchar)
{
	if (_ctx is null)
		return null;
	if (STD_COUNT (_ctx) = 1)
		return null;
	return VAR_SAMP_FIN (_ctx);
}
;

--!AWK PUBLIC
create procedure STDDEV_POP_FIN (inout _ctx varchar)
{
	if (_ctx is null)
		return null;
	declare c integer;
	declare _env any;
	_env := deserialize (_ctx);
	c := aref (_env, 0);
	if (c = 0)
		return null;

	return  sqrt ((aref (_env, 2) - aref (_env, 1) * aref (_env, 1) / c) / c) ;
}
;

--!AWK PUBLIC
create procedure STDDEV_SAMP_FIN (inout _ctx varchar)
{
        if (_ctx is null)
                return null;
        declare c integer;
        declare _env any;
        _env := deserialize (_ctx);
        c := aref (_env, 0);
        if (c = 0)
                return null;
	if (c = 1)
		return 0.0;
        return  sqrt ((aref (_env, 2) - aref (_env, 1) * aref (_env, 1) / c) / ( c - 1));
}
;

--!AWK PUBLIC
create procedure STDDEV_FIN (inout _ctx varchar)
{
        if (_ctx is null)
                return null;
        if (STD_COUNT (_ctx) = 1)
                return null;
        return STDDEV_SAMP_FIN (_ctx);
}
;

--!AWK PUBLIC
create procedure COVAR_ACC (inout _ctx any,
	in expr1 numeric,
	in expr2 numeric)
{
	if (_ctx is null)
		return;
	if (expr1 is null or expr2 is null)
		return;

	declare _env any;

	_env := deserialize (_ctx);

	aset (_env, 1, aref (_env,1)+expr1);
	aset (_env, 2, aref (_env,2)+expr2);
	aset (_env, 3, aref (_env,3)+expr2*expr1);
	aset (_env, 0, aref (_env,0)+1);

	_ctx := serialize (_env);
}
;

--!AWK PUBLIC
create procedure COVAR_SAMP_FIN (inout _ctx any)
{
	if (_ctx is null)
		return null;
	declare _env any;
	_env := deserialize (_ctx);
	if (aref (_env, 0) = 0)
		return null;
	if (aref (_env, 0) = 1)
		return 0.0;

	return (aref (_env, 3) - aref(_env,2) * aref (_env,1) / aref (_env, 0)) / ( aref (_env, 0) - 1);
}
;

--!AWK PUBLIC
create procedure COVAR_POP_FIN (inout _ctx any)
{
        if (_ctx is null)
                return null;
        declare _env any;
        _env := deserialize (_ctx);
        if (aref (_env, 0) = 0)
                return null;
        if (aref (_env, 0) = 1)
                return 0.0;

        return (aref (_env, 3) - aref(_env,2) * aref (_env,1) / aref (_env, 0))/ aref (_env,0);
}
;

--!AWK PUBLIC
create procedure COVAR_FIN (inout _ctx varchar)
{
        if (_ctx is null)
                return null;
        if (STD_COUNT (_ctx) = 1)
                return null;
        return COVAR_SAMP_FIN (_ctx);
}
;

create aggregate DB.DBA.VAR_POP (in val numeric) returns numeric from
        STD12_INIT, VAR_ACC, VAR_POP_FIN
;
create aggregate DB.DBA.VAR_SAMP (in val numeric) returns numeric from
	STD12_INIT, VAR_ACC, VAR_SAMP_FIN
;
create aggregate DB.DBA.VAR (in val numeric) returns numeric from
	STD12_INIT, VAR_ACC, VAR_FIN
;
create aggregate DB.DBA.STDDEV_POP (in val numeric) returns numeric from
	STD12_INIT, VAR_ACC, STDDEV_POP_FIN
;
create aggregate DB.DBA.STDDEV_SAMP (in val numeric) returns numeric from
	STD12_INIT, VAR_ACC, STDDEV_SAMP_FIN
;
create aggregate DB.DBA.STDDEV (in val numeric) returns numeric from
	STD12_INIT, VAR_ACC, STDDEV_FIN
;
create aggregate DB.DBA.COVAR_SAMP (in expr1 numeric, in expr2 numeric) returns numeric from
	STD13_INIT, COVAR_ACC, COVAR_SAMP_FIN
;
create aggregate DB.DBA.COVAR_POP (in expr1 numeric, in expr2 numeric) returns numeric from
	STD13_INIT, COVAR_ACC, COVAR_POP_FIN
;
create aggregate DB.DBA.COVAR (in expr1 numeric, in expr2 numeric) returns numeric from
	STD13_INIT, COVAR_ACC, COVAR_FIN
;

--!AWK PUBLIC
create procedure REGR_SLOPE_INIT (inout _env varchar)
{
	declare _ctx1 varchar;
	declare _ctx2 varchar;

	STD13_INIT (_ctx1);
	STD12_INIT (_ctx2);

	_env := serialize (vector (0, _ctx1, _ctx2));
}
;

--!AWK PUBLIC
create procedure REGR_SLOPE_ACC (inout _env varchar, in expr1 numeric, in expr2 numeric)
{
	if (_env is null)
		return;
	if ( (expr1 is null) or (expr2 is null))
		return;
	declare _ctx any;
	_ctx := deserialize (_env);

	declare _ctx1 varchar;
	declare _ctx2 varchar;

	_ctx1 := aref (_ctx, 1);
	_ctx2 := aref (_ctx, 2);

	aset (_ctx, 0, aref (_ctx,0) + 1);
	COVAR_ACC (_ctx1, expr1, expr2);
	VAR_ACC (_ctx2, expr2);

	aset (_ctx, 1, _ctx1);
	aset (_ctx, 2, _ctx2);

	_env := serialize (_ctx);
}
;

--!AWK PUBLIC
create procedure REGR_SLOPE_FIN (inout _env varchar)
{
	if (_env is null)
		return null;
	declare _ctx any;
	declare c integer;

	_ctx := deserialize (_env);

	c := aref (_ctx, 0);
	if (c = 0)
		return 0;
	if (c = 1)
		return null;

	declare _ctx1 varchar;
	declare _ctx2 varchar;
	declare covar_pop_val numeric;
	declare var_pop_val numeric;

	_ctx1 := aref (_ctx, 1);
	_ctx2 := aref (_ctx, 2);


	covar_pop_val := COVAR_POP_FIN (_ctx1);
	var_pop_val := VAR_POP_FIN (_ctx2);

	if (var_pop_val = 0)
		return null;
	return covar_pop_val / var_pop_val;
}
;

create aggregate DB.DBA.REGR_SLOPE (in expr1 numeric, in expr2 numeric) returns numeric from REGR_SLOPE_INIT, REGR_SLOPE_ACC, REGR_SLOPE_FIN
;

--!AWK PUBLIC
create procedure REGR_INTERCEPT_INIT (inout _env varchar)
{
	declare _ctx_regr_slope varchar;

	REGR_SLOPE_INIT (_ctx_regr_slope);
	_env := serialize (vector (0, 0.0, 0.0, _ctx_regr_slope));
}
;

--!AWK PUBLIC
create procedure REGR_INTERCEPT_ACC (inout _env varchar, in expr1 numeric, in expr2 numeric)
{
	if (_env is null)
		return;
	if ((expr1 is null) or (expr2 is null))
		return;

	declare _ctx any;
	_ctx := deserialize (_env);

	aset (_ctx, 0, aref (_ctx, 0) + 1);
	aset (_ctx, 1, aref (_ctx, 1) + expr1);
	aset (_ctx, 2, aref (_ctx, 2) + expr2);

	declare _ctx_r varchar;
	_ctx_r := aref (_ctx, 3);
	REGR_SLOPE_ACC (_ctx_r, expr1, expr2);
	aset (_ctx, 3, _ctx_r);

	_env := serialize (_ctx);
}
;

--!AWK PUBLIC
create procedure REGR_INTERCEPT_FIN (inout _env varchar)
{
	if (_env is null)
		return null;
	declare _ctx any;
	_ctx := deserialize (_env);
	declare c integer;
	c := aref (_ctx, 0);
	if ((c = 0) or (c = 1))
		return null;

	return aref (_ctx, 1) / c - REGR_SLOPE_FIN (aref (_ctx, 3)) * aref (_ctx, 2) / c;
}
;

create aggregate DB.DBA.REGR_INTERCEPT (in expr1 numeric, in expr2 numeric) returns numeric from REGR_INTERCEPT_INIT, REGR_INTERCEPT_ACC, REGR_INTERCEPT_FIN
;

--!AWK PUBLIC
create procedure REGR_COUNT_INIT (inout _env integer)
{
	_env := 0;
}
;

--!AWK PUBLIC
create procedure REGR_COUNT_ACC (inout _env integer, in expr numeric, in expr2 numeric)
{
	if ((_env is null) or (expr is null) or (expr2 is null))
		return;
	_env := _env + 1;
}
;

--!AWK PUBLIC
create procedure REGR_COUNT_FIN (inout _env integer)
{
	return _env;
}
;

--!AWK PUBLIC
create procedure REGR_COUNT_MERGE (inout _e1 integer, inout _e2 integer)
{
	_e1 := _e1 + _e2;
}
;

create aggregate DB.DBA.REGR_COUNT (in expr1 numeric, in expr2 numeric) returns numeric from REGR_COUNT_INIT, REGR_COUNT_ACC, REGR_COUNT_FIN, REGR_COUNT_MERGE
;

--!AWK PUBLIC
create procedure REGR_AVG_ACC (inout _env varchar, in expr1 numeric, in expr2 numeric)
{
	if (_env is null)
		return;

	if ( (expr1 is null) or (expr2 is null))
		return;
	declare _ctx any;
	_ctx := deserialize (_env);

	aset (_ctx, 0, aref (_ctx, 0) + 1);
	aset (_ctx, 1, aref (_ctx, 1) + expr1);
	aset (_ctx, 2, aref (_ctx, 2) + expr2);

	_env := serialize (_ctx);
}
;

--!AWK PUBLIC
create procedure REGR_AVGX_FIN (inout _env varchar)
{
	if (_env is null)
		return null;
	declare _ctx any;
	_ctx := deserialize (_env);
	if (aref (_ctx, 0) = 0)
		return null;
	return aref (_ctx, 1) / aref (_ctx,0);
}
;

--!AWK PUBLIC
create procedure REGR_AVGY_FIN (inout _env varchar)
{
	if (_env is null)
		return null;
	declare _ctx any;
	_ctx := deserialize (_env);
	if (aref (_ctx, 0) = 0)
		return null;
	return aref (_ctx, 2) / aref (_ctx,0);
}
;

create aggregate DB.DBA.REGR_AVGX (in x numeric, in y numeric) returns numeric from
	STD12_INIT, REGR_AVG_ACC, REGR_AVGX_FIN
;

create aggregate DB.DBA.REGR_AVGY (in x numeric, in y numeric) returns numeric from
	STD12_INIT, REGR_AVG_ACC, REGR_AVGY_FIN
;

--!AWK PUBLIC
create procedure CORR_INIT (inout _env varchar)
{
	declare _ctx_cov varchar;
	declare _ctx_stdev1 varchar;
	declare _ctx_stdev2 varchar;

	STD13_INIT (_ctx_cov);
	STD12_INIT (_ctx_stdev1);
	STD12_INIT (_ctx_stdev2);

	_env := serialize (vector (0, _ctx_cov, _ctx_stdev1, _ctx_stdev2));
}
;

--!AWK PUBLIC
create procedure CORR_ACC (inout _env varchar, in e1 numeric, in e2 numeric)
{
	if (_env is null)
		return;
	if ((e1 is null) or (e2 is null))
		return;
	declare _ctx any;
	_ctx := deserialize (_env);

	declare _ctx_cov varchar;
	declare _ctx_stdev1 varchar;
	declare _ctx_stdev2 varchar;

	_ctx_cov := aref (_ctx, 1);
	_ctx_stdev1 := aref (_ctx, 2);
	_ctx_stdev2 := aref (_ctx, 3);

	COVAR_ACC (_ctx_cov, e1, e2);
	VAR_ACC (_ctx_stdev1, e1);
	VAR_ACC (_ctx_stdev2, e2);

	aset (_ctx, 0, aref (_ctx, 0) + 1);
	aset (_ctx, 1, _ctx_cov);
	aset (_ctx, 2, _ctx_stdev1);
	aset (_ctx, 3, _ctx_stdev2);

	_env := serialize (_ctx);
}
;

--!AWK PUBLIC
create procedure CORR_FIN (inout _env varchar)
{
	if (_env is null)
		return null;
	declare _ctx any;
	_ctx := deserialize (_env);

	declare _ctx_cov_val numeric;
	declare _ctx_stdev1_val numeric;
	declare _ctx_stdev2_val numeric;

	_ctx_cov_val := COVAR_POP_FIN (aref (_ctx, 1));
	_ctx_stdev1_val := STDDEV_POP_FIN (aref (_ctx, 2));
	_ctx_stdev2_val := STDDEV_POP_FIN (aref (_ctx, 3));

	if (_ctx_cov_val is null)
		return null;
	if (_ctx_stdev1_val is null or _ctx_stdev1_val = 0)
		return null;
	if (_ctx_stdev2_val is null or _ctx_stdev2_val = 0)
		return null;

	return _ctx_cov_val / _ctx_stdev1_val / _ctx_stdev2_val;
}
;

create aggregate DB.DBA.CORR (in x numeric, in y numeric) returns numeric from
	CORR_INIT, CORR_ACC, CORR_FIN
;

--!AWK PUBLIC
create procedure REGR_R2_INIT (inout _env varchar)
{
	declare _ctx_vp1 varchar;
	declare _ctx_vp2 varchar;
	declare _ctx_corr varchar;

	STD12_INIT (_ctx_vp1);
	STD12_INIT (_ctx_vp2);
	CORR_INIT (_ctx_corr);

	_env := serialize (vector (_ctx_vp1, _ctx_vp2, _ctx_corr));
}
;

--!AWK PUBLIC
create procedure REGR_R2_ACC (inout _env varchar, in e1 numeric, in e2 numeric)
{
	if (_env is null)
		return;
	if (e1 is null or e2 is null)
		return;
	declare _ctx  any;

	_ctx := deserialize (_env);

	declare _ctx_vp1 varchar;
	declare _ctx_vp2 varchar;
	declare _ctx_corr varchar;

	_ctx_vp1 := aref (_ctx, 0);
	_ctx_vp2 := aref (_ctx, 1);
	_ctx_corr := aref (_ctx, 2);

	VAR_ACC (_ctx_vp1, e1);
	VAR_ACC (_ctx_vp2, e2);
	CORR_ACC (_ctx_corr, e1, e2);

	aset (_ctx, 0, _ctx_vp1);
	aset (_ctx, 1, _ctx_vp2);
	aset (_ctx, 2, _ctx_corr);

	_env := serialize (_ctx);
}
;

--!AWK PUBLIC
create procedure REGR_R2_FIN (inout _env varchar)
{
	if (_env is null)
		return null;
	declare _ctx any;

	_ctx := deserialize (_env);

	declare _vp1 numeric;
	declare _vp2 numeric;
	declare _corr numeric;

	_vp2 := VAR_POP_FIN (aref(_ctx, 1));
	if (_vp2 is null or _vp2 = 0)
		return null;
	_vp1 := VAR_POP_FIN (aref(_ctx, 0));
	if (_vp1 is null or _vp1 = 0)
		return 1;
	_corr := CORR_FIN (aref (_ctx, 2));
	return _corr * _corr;
}
;

create aggregate DB.DBA.REGR_R2 (in e1 numeric, in e2 numeric) returns numeric from
	REGR_R2_INIT, REGR_R2_ACC, REGR_R2_FIN
;

--!AWK PUBLIC
create procedure REGR_SXX_ACC (inout _env varchar, in e1 numeric, in e2 numeric)
{
	if (_env is null)
		return;
	if (e1 is null or e2 is null)
		return;

	VAR_ACC (_env, e2);
}
;

--!AWK PUBLIC
create procedure REGR_SYY_ACC (inout _env varchar, in e1 numeric, in e2 numeric)
{
	if (_env is null)
		return;
	if (e1 is null or e2 is null)
		return;

	VAR_ACC (_env, e1);
}
;

--!AWK PUBLIC
create procedure REGR_SXY_ACC (inout _env varchar, in e1 numeric, in e2 numeric)
{
	if (_env is null)
		return;
	if (e1 is null or e2 is null)
		return;

	COVAR_ACC (_env, e1, e2);
}
;

--!AWK PUBLIC
create procedure REGR_S___FIN (inout _env varchar)
{
	if (_env is null)
		return null;
	declare _ctx any;
	_ctx := deserialize (_env);

	declare _var numeric;

	_var := VAR_POP_FIN (_env);
	if (_var is null)
		return null;
	return aref (_ctx,0) * _var;
}
;

--!AWK PUBLIC
create procedure REGR_SXY_FIN (inout _env varchar)
{
	if (_env is null)
		return null;
	declare _ctx any;
	_ctx := deserialize (_env);

	declare _var numeric;

	_var := COVAR_POP_FIN (_env);
	if (_var is null)
		return null;
	return aref (_ctx,0) * _var;
}
;

create aggregate DB.DBA.REGR_SXX (in e1 numeric, in e2 numeric) returns numeric from
	STD12_INIT, REGR_SXX_ACC, REGR_S___FIN
;

create aggregate DB.DBA.REGR_SYY (in e1 numeric, in e2 numeric) returns numeric from
	STD12_INIT, REGR_SYY_ACC, REGR_S___FIN
;

create aggregate DB.DBA.REGR_SXY (in e1 numeric, in e2 numeric) returns numeric from
	STD13_INIT, REGR_SXY_ACC, REGR_SXY_FIN
;

--!AWK PUBLIC
create procedure xte_nodebld_final_root (in acc any) returns any
{
  return xte_nodebld_xmlagg_final (acc, xte_head (UNAME' root'));
}
;

create aggregate DB.DBA.XMLAGG (in _child any) returns any
  from xte_nodebld_init, xte_nodebld_xmlagg_acc, xte_nodebld_final_root
;

create aggregate DB.DBA.VECTOR_AGG (in _child any) returns any
  from vectorbld_init, vectorbld_agg_acc, vectorbld_agg_final
;

-- same as vector agg but does not force query to produce deterministic result order
create aggregate DB.DBA.BAG_AGG (in _child any) returns any
  from vectorbld_init, vectorbld_agg_acc, vectorbld_agg_final
;

create aggregate DB.DBA.VECTOR_CONCAT_AGG (in _child any) returns any
  from vectorbld_init, vectorbld_concat_agg_acc, vectorbld_agg_final
;

create aggregate DB.DBA.XQ_SEQUENCE_AGG (in _child any) returns any
  from xq_sequencebld_init, xq_sequencebld_agg_acc, xq_sequencebld_agg_final
;


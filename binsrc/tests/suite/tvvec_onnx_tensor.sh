#!/bin/sh
#
#  tvvec_onnx_tensor.sh
#
#  Generic tensor path of the ONNX bridge: ONNX_LOAD_MODEL / ONNX_RUN_F32 with
#  a caller-supplied float32 tensor, as used by user-trained TensorFlow and
#  PyTorch models exported to ONNX.
#
#  Covers six defects found while verifying that path (see
#  lace2/docs/virtuoso-ml-onnx/onnx-verification-report.md):
#
#    1. ONNX Runtime error text was formatted from freed memory, so every
#       diagnostic reached the user as garbage;
#    2. ONNX_LOAD_MODEL without explicit input=/output= opened a NEW runtime
#       session on every call -- one per row of a scan;
#    3. a FAILED inference leaked a model reference, so the model could never
#       be unloaded again;
#    4. a NULL or a string in the data vector was reinterpreted as a float
#       instead of being rejected, giving confident nonsense;
#    5. DB.DBA.ONNX_MODEL_REFRESH ignored the input_names column and forced the
#       tokenizer input names, so the catalogue could not carry a tensor model;
#    6. the ONNX BIFs had no DBA check and no DirsAllowed check.
#
#  The test model is a 112-byte Identity graph (input 'features' float32 [1,4]
#  -> output 'y' float32 [1,4]) written out of a base64 literal by the server
#  itself, so the suite needs no binary fixture and no Python.  Identity makes
#  the expected output equal to the input, which is what lets the correctness
#  assertions below be exact.
#
#  A STATIC shape is essential: the bundled granite model has symbolic axes and
#  therefore only loads out-of-process, where defects 2 and 3 do not reproduce.
#
#  The ONNX plugin is off by default (--enable-onnxruntime), so like the other
#  ONNX-backed suites this SKIPS (never fails) when vonnx.so is not built.
#
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#
#  Copyright (C) 1998-2026 OpenLink Software
#
#  This project is free software; you can redistribute it and/or modify it
#  under the terms of the GNU General Public License as published by the
#  Free Software Foundation; only version 2 of the License, dated June 1991.
#
#  This program is distributed in the hope that it will be useful, but
#  WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
#  General Public License for more details.
#
#  You should have received a copy of the GNU General Public License along
#  with this program; if not, write to the Free Software Foundation, Inc.,
#  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
#

LOGFILE=`pwd`/tvvec_onnx_tensor.output
export LOGFILE
. $VIRTUOSO_TEST/testlib.sh

rm -f $LOGFILE

BANNER "STARTED ONNX tensor path test"

#  Vector/ONNX is single-server only; nothing to do on a cluster build.
if [ "$CURRENT_VIRTUOSO_CAPACITY" != "single" ]
then
    LOG "SKIPPED: single-server only"
    BANNER "COMPLETED ONNX tensor path test (skipped: not single-server)"
    exit 0
fi

HOSTING="$VIRTUOSO_BUILD/binsrc/hosting"

#  Fixtures for the general tensor I/O surface.  All are a few hundred bytes and
#  are written out by the server itself (string_to_file + decode_base64), so the
#  suite carries no binary and needs no Python.  Expected values below are from
#  onnxruntime on the same graphs.
#
#    TWO_IN    a[1,4] + b[1,4] -> sum[1,4]          both float32
#    TWO_OUT   x[1,4] -> y[1,4] and y2[1,4] (= 2x)
#    INT_OUT   Cast<int64>(x[1,4]) -> k[1,4]
#    FIVE_D    Identity on [1,1,1,2,2]              rank 5
#    MIXED_IN  x[1,4] float32 + n[1] int64 -> y[1,4]
TWO_IN_B64='CAgSE3ZpcnR1b3NvLW9ubngtc3VpdGU6WwoQCgFhCgFiEgNzdW0iA0FkZBIGdHdvX2luWhMKAWESDgoMCAESCAoCCAEKAggEWhMKAWISDgoMCAESCAoCCAEKAggEYhUKA3N1bRIOCgwIARIICgIIAQoCCARCBAoAEBE='
TWO_OUT_B64='CAgSE3ZpcnR1b3NvLW9ubngtc3VpdGU6bAoQCgF4EgF5IghJZGVudGl0eQoPCgF4CgF4EgJ5MiIDQWRkEgd0d29fb3V0WhMKAXgSDgoMCAESCAoCCAEKAggEYhMKAXkSDgoMCAESCAoCCAEKAggEYhQKAnkyEg4KDAgBEggKAggBCgIIBEIECgAQEQ=='
INT_OUT_B64='CAgSE3ZpcnR1b3NvLW9ubngtc3VpdGU6TAoXCgF4EgFrIgRDYXN0KgkKAnRvGAegAQISB2ludF9vdXRaEwoBeBIOCgwIARIICgIIAQoCCARiEwoBaxIOCgwIBxIICgIIAQoCCARCBAoAEBE='
FIVE_D_B64='CAgSE3ZpcnR1b3NvLW9ubngtc3VpdGU6XAoQCgF4EgF5IghJZGVudGl0eRIGZml2ZV9kWh8KAXgSGgoYCAESFAoCCAEKAggBCgIIAQoCCAIKAggCYh8KAXkSGgoYCAESFAoCCAEKAggBCgIIAQoCCAIKAggCQgQKABAR'
MIXED_IN_B64='CAgSE3ZpcnR1b3NvLW9ubngtc3VpdGU6cAoYCgFuEgJuZiIEQ2FzdCoJCgJ0bxgBoAECCg8KAXgKAm5mEgF5IgNBZGQSCG1peGVkX2luWhMKAXgSDgoMCAESCAoCCAEKAggEWg8KAW4SCgoICAcSBAoCCAFiEwoBeRIOCgwIARIICgIIAQoCCARCBAoAEBE='

#  A 112-byte Identity model: features float32 [1,4] -> y float32 [1,4].
IDENT_B64='CAgSE3ZpcnR1b3NvLW9ubngtc3VpdGU6UQoXCghmZWF0dXJlcxIBeSIISWRlbnRpdHkSBWlkZW50WhoKCGZlYXR1cmVzEg4KDAgBEggKAggBCgIIBGITCgF5Eg4KDAgBEggKAggBCgIIBEIECgAQEQ=='

#  Ask the running server a one-line question; echoes the first bare value.
PROBE()
{
    echo "$1" | $ISQL $DSN dba dba VERBOSE=OFF PROMPT=OFF ERRORS=STDOUT 2>/dev/null \
        | grep -E '^[0-9-]+$' | head -1
}

#  How many models the plugin currently holds open: one '{' per entry in the
#  ONNX_MODEL_INFO(NULL) JSON array.  Counted this way rather than by splitting,
#  so that nothing has to survive shell -> SQL quoting.
MODEL_COUNT()
{
    PROBE "select (length (ONNX_MODEL_INFO (NULL)) - length (replace (ONNX_MODEL_INFO (NULL), '{', '')));"
}

#  As PROBE, but returns the whole output including any error text.
RAW()
{
    echo "$1" | $ISQL $DSN dba dba VERBOSE=OFF PROMPT=OFF ERRORS=STDOUT 2>&1
}

#  As RAW, but as the unprivileged account created below.
RAW_USER()
{
    echo "$1" | $ISQL $DSN onnxuser onnxpass VERBOSE=OFF PROMPT=OFF ERRORS=STDOUT 2>&1
}

PASS=0
FAIL=0
CHECK()   #  CHECK "<description>" <ok?0/1>
{
    if [ "$2" = "1" ]; then PASS=`expr $PASS + 1`; LOG "PASSED: $1"
    else FAIL=`expr $FAIL + 1`; LOG "***FAILED: $1"; fi
}

MAKECFG_FILE $TESTCFGFILE $PORT $CFGFILE

#  ---- ONNX gate: repoint LoadPath and add the model/helper paths ------------
if [ -f "$HOSTING/vonnx.so" ]
then
    cp "$CFGFILE" "$CFGFILE.pre_onnx"
    #  Narrow DirsAllowed to the test directory ONLY.  Two things depend on this:
    #
    #    - the generated suite config allows '/', under which the DirsAllowed
    #      assertion below could never fail;
    #    - [ONNX] ModelRoot then sits OUTSIDE DirsAllowed, exactly as it does in
    #      the shipped virtuoso.ini (ModelRoot = ../hosting/onnx-models against
    #      DirsAllowed = ., ../vad/).  That is the shape that once stopped the
    #      server loading its own bundled model at bootstrap, so the bundled
    #      model is asserted below under this config and not a friendlier one.
    sed -e "s#^LoadPath[ 	]*=.*#LoadPath = $HOSTING#" \
        -e "s#^DirsAllowed[ 	]*=.*#DirsAllowed = .#" \
        "$CFGFILE.pre_onnx" > "$CFGFILE"
    rm -f "$CFGFILE.pre_onnx"
    printf '\n[ONNX]\nModelRoot  = %s/onnx-models\nHelperPath = %s/onnx_helper\n' \
        "$HOSTING" "$HOSTING" >> "$CFGFILE"
    LOG "+ vonnx plugin found in $HOSTING"
else
    LOG "SKIPPED: vonnx plugin not built"
    BANNER "COMPLETED ONNX tensor path test (skipped: vonnx not built)"
    exit 0
fi

START_SERVER $PORT 1000

MODEL=`pwd`/tvvec_onnx_ident.onnx
NOTAMODEL=`pwd`/tvvec_onnx_notamodel.onnx
#  Separate copies for the unload assertions.  Model reuse is keyed on (path,
#  names, mode), so unloading a handle obtained from $MODEL would close the
#  entry every other assertion here is using.
MODEL_G=`pwd`/tvvec_onnx_ident_good.onnx
MODEL_B=`pwd`/tvvec_onnx_ident_bad.onnx

#  ---- Fixture: let the server write its own model file ----------------------
rm -f "$MODEL" "$NOTAMODEL" "$MODEL_G" "$MODEL_B" \
      "$M_TWO_IN" "$M_TWO_OUT" "$M_INT_OUT" "$M_FIVE_D" "$M_MIXED"
PROBE "string_to_file ('$MODEL', decode_base64 ('$IDENT_B64'), -2);" >/dev/null 2>&1
PROBE "string_to_file ('$MODEL_G', decode_base64 ('$IDENT_B64'), -2);" >/dev/null 2>&1
PROBE "string_to_file ('$MODEL_B', decode_base64 ('$IDENT_B64'), -2);" >/dev/null 2>&1
PROBE "string_to_file ('$NOTAMODEL', 'this is not an onnx model', -2);" >/dev/null 2>&1
M_TWO_IN=`pwd`/tvvec_onnx_two_in.onnx
M_TWO_OUT=`pwd`/tvvec_onnx_two_out.onnx
M_INT_OUT=`pwd`/tvvec_onnx_int_out.onnx
M_FIVE_D=`pwd`/tvvec_onnx_5d.onnx
M_MIXED=`pwd`/tvvec_onnx_mixed_in.onnx
PROBE "string_to_file ('$M_TWO_IN',  decode_base64 ('$TWO_IN_B64'), -2);"   >/dev/null 2>&1
PROBE "string_to_file ('$M_TWO_OUT', decode_base64 ('$TWO_OUT_B64'), -2);"  >/dev/null 2>&1
PROBE "string_to_file ('$M_INT_OUT', decode_base64 ('$INT_OUT_B64'), -2);"  >/dev/null 2>&1
PROBE "string_to_file ('$M_FIVE_D',  decode_base64 ('$FIVE_D_B64'), -2);"   >/dev/null 2>&1
PROBE "string_to_file ('$M_MIXED',   decode_base64 ('$MIXED_IN_B64'), -2);" >/dev/null 2>&1
sz=`PROBE "select file_stat ('$MODEL', 1);"`
if [ "$sz" != "112" ]
then
    LOG "SKIPPED: could not stage the test model (file_stat returned '$sz')"
    SHUTDOWN_SERVER
    BANNER "COMPLETED ONNX tensor path test (skipped: fixture not staged)"
    exit 0
fi
LOG "+ staged $MODEL ($sz bytes)"

#  ---- the bundled model, before anything here changes the global mode ------
#  ModelRoot is outside DirsAllowed in this config, exactly as in the shipped
#  virtuoso.ini.  The model path check has to honour the roots the operator
#  declared for models, not DirsAllowed alone, or the server refuses its own
#  bundled model at bootstrap and the vector index silently loses its embedding
#  model.  Asserted here, while the plugin is still in its default out-of-process
#  mode: the bundled model has symbolic axes and does not run in-process.
mh=`PROBE "select coalesce (handle, -1) from DB.DBA.ONNX_MODELS where model_name = 'granite-384-local';"`
CHECK "the bundled model loaded at bootstrap with ModelRoot outside DirsAllowed (handle '$mh')" \
    `[ -n "$mh" ] && [ "$mh" != "-1" ] && echo 1 || echo 0`
emb=`PROBE "select length (ONNX_EMBED_TEXT ((select handle from DB.DBA.ONNX_MODELS where model_name = 'granite-384-local'), 'hello world'));"`
CHECK "the bundled model still embeds (384, got '$emb')" `[ "$emb" = "384" ] && echo 1 || echo 0`

#  Every assertion below is about the IN-PROCESS path.
PROBE "select ONNX_CONFIG ('mode', 'inproc');" >/dev/null 2>&1

#  ---- Baseline: a static-shape tensor model loads and round-trips -----------
h=`PROBE "select ONNX_LOAD_MODEL ('$MODEL', 'input=features;output=y;mode=inproc');"`
CHECK "static-shape model loads inproc (handle '$h')" `[ -n "$h" ] && [ "$h" -gt 0 ] 2>/dev/null && echo 1 || echo 0`

if [ -z "$h" ]
then
    LOG "SKIPPED: model did not load; nothing further to exercise"
    SHUTDOWN_SERVER
    BANNER "COMPLETED ONNX tensor path test (skipped: model did not load)"
    exit 0
fi

s=`PROBE "select cast (aref (ONNX_RUN_F32 ($h, vector (1,2,3,4), vector (1,4)), 0) +
                       aref (ONNX_RUN_F32 ($h, vector (1,2,3,4), vector (1,4)), 3) as integer);"`
CHECK "ONNX_RUN_F32 round-trips the identity model (1+4=5, got '$s')" `[ "$s" = "5" ] && echo 1 || echo 0`

#  ---- Defect 1: ONNX Runtime error text must survive to the user -----------
#  Loading a non-model file fails inside ORT.  Before the fix the message was
#  formatted from freed memory and arrived as a couple of garbage bytes.
msg=`RAW "select ONNX_LOAD_MODEL ('$NOTAMODEL', 'mode=inproc');" | grep -i 'CreateSession'`
LOG "+ CreateSession error: $msg"
#  everything after the context prefix is the runtime's own explanation
detail=`echo "$msg" | sed -e 's/.*CreateSession: //'`
len=`printf '%s' "$detail" | wc -c | tr -d ' '`
CHECK "ORT error text is present and substantial (len=$len)" `[ "$len" -ge 20 ] && echo 1 || echo 0`
#  and it must be text, not freed memory: no bytes outside printable ASCII
junk=`printf '%s' "$detail" | LC_ALL=C tr -d '[:print:]' | wc -c | tr -d ' '`
CHECK "ORT error text is printable ASCII (junk bytes=$junk)" `[ "$junk" = "0" ] && echo 1 || echo 0`

#  ---- Defect 2: a bare load must not open a new session every call ---------
before=`MODEL_COUNT`
b1=`PROBE "select ONNX_LOAD_MODEL ('$MODEL');"`
b2=`PROBE "select ONNX_LOAD_MODEL ('$MODEL');"`
b3=`PROBE "select ONNX_LOAD_MODEL ('$MODEL');"`
b4=`PROBE "select ONNX_LOAD_MODEL ('$MODEL');"`
after=`MODEL_COUNT`
LOG "+ bare loads returned: $b1 $b2 $b3 $b4 (models $before -> $after)"
CHECK "four bare loads return one handle ($b1 $b2 $b3 $b4)" \
    `[ -n "$b1" ] && [ "$b1" = "$b2" ] && [ "$b2" = "$b3" ] && [ "$b3" = "$b4" ] && echo 1 || echo 0`
grew=`expr "$after" - "$before" 2>/dev/null`
CHECK "four bare loads add exactly one model entry (added=$grew)" `[ "$grew" = "1" ] && echo 1 || echo 0`

#  the same must hold when the names ARE given (this already worked)
n1=`PROBE "select ONNX_LOAD_MODEL ('$MODEL', 'input=features;output=y');"`
n2=`PROBE "select ONNX_LOAD_MODEL ('$MODEL', 'input=features;output=y');"`
CHECK "two named loads return one handle ($n1 $n2)" `[ -n "$n1" ] && [ "$n1" = "$n2" ] && echo 1 || echo 0`

#  ---- Defect 3: a failed inference must not pin the model ------------------
#  control first: a model that has only ever succeeded must unload cleanly.
hg=`PROBE "select ONNX_LOAD_MODEL ('$MODEL_G', 'input=features;output=y;mode=inproc');"`
PROBE "select aref (ONNX_RUN_F32 ($hg, vector (1,2,3,4), vector (1,4)), 0);" >/dev/null 2>&1
u=`PROBE "select ONNX_UNLOAD_MODEL ($hg);"`
CHECK "unload after a successful inference (rc '$u')" `[ "$u" = "1" ] && echo 1 || echo 0`

#  now the real case: one FAILED inference, then unload.
hb=`PROBE "select ONNX_LOAD_MODEL ('$MODEL_B', 'input=features;output=y;mode=inproc');"`
#  [1,5] against a model declared [1,4] -- ORT refuses at run time
RAW "select ONNX_RUN_F32 ($hb, vector (1,2,3,4,5), vector (1,5));" >/dev/null 2>&1
ub=`RAW "select ONNX_UNLOAD_MODEL ($hb);"`
inflight=`echo "$ub" | grep -ic 'in-flight'`
urc=`echo "$ub" | grep -E '^[0-9-]+$' | head -1`
LOG "+ unload after failed inference: rc='$urc' in-flight-error=$inflight"
CHECK "unload after a FAILED inference (rc '$urc', in-flight errors $inflight)" \
    `[ "$urc" = "1" ] && [ "$inflight" = "0" ] && echo 1 || echo 0`

#  ---- Defect 4: non-numeric feature elements must be rejected --------------
nullrun=`RAW "select aref (ONNX_RUN_F32 ($h, vector (1, NULL, 3, 4), vector (1,4)), 0);"`
nullerr=`echo "$nullrun" | grep -ic 'error'`
CHECK "a NULL feature raises instead of returning a number" `[ "$nullerr" -ge 1 ] && echo 1 || echo 0`
LOG "+ NULL feature: `echo "$nullrun" | grep -i error | head -1`"
CHECK "the NULL error says which element and that it is NULL" \
    `echo "$nullrun" | grep -qiE 'null' && echo "$nullrun" | grep -qE '\[1\]|element 1|index 1' && echo 1 || echo 0`

strrun=`RAW "select aref (ONNX_RUN_F32 ($h, vector (1, 'abc', 3, 4), vector (1,4)), 0);"`
strerr=`echo "$strrun" | grep -ic 'error'`
CHECK "a string feature raises instead of returning a number" `[ "$strerr" -ge 1 ] && echo 1 || echo 0`

dimrun=`RAW "select aref (ONNX_RUN_F32 ($h, vector (1,2,3,4), vector (1, NULL)), 0);"`
dimerr=`echo "$dimrun" | grep -ic 'error'`
CHECK "a NULL dimension raises" `[ "$dimerr" -ge 1 ] && echo 1 || echo 0`

#  a valid call must still work after all that
s2=`PROBE "select cast (aref (ONNX_RUN_F32 ($h, vector (7,0,0,0), vector (1,4)), 0) as integer);"`
CHECK "a valid inference still works after the rejections (got '$s2')" `[ "$s2" = "7" ] && echo 1 || echo 0`

#  ---- Defect 5: the catalogue must honour input_names ----------------------
PROBE "delete from DB.DBA.ONNX_MODELS where model_name = 'tvvec-tensor-ident';" >/dev/null 2>&1
PROBE "insert into DB.DBA.ONNX_MODELS (model_name, model_path, model_type, input_names, output_name, created_at, updated_at)
       values ('tvvec-tensor-ident', '$MODEL', 'onnx', 'features', 'y', now (), now ());" >/dev/null 2>&1
rh=`PROBE "select DB.DBA.ONNX_MODEL_REFRESH ('tvvec-tensor-ident');"`
info=`RAW "select ONNX_MODEL_INFO ((select handle from DB.DBA.ONNX_MODELS where model_name = 'tvvec-tensor-ident'));"`
LOG "+ registry info: `echo "$info" | grep -i handle | head -1`"
CHECK "a registered tensor model keeps its own input name" \
    `echo "$info" | grep -q '"input":"features"' && echo 1 || echo 0`
#  and it must actually run through that handle
rrh=`PROBE "select cast (aref (ONNX_RUN_F32 ((select handle from DB.DBA.ONNX_MODELS where model_name = 'tvvec-tensor-ident'), vector (9,0,0,0), vector (1,4)), 0) as integer);"`
CHECK "the registry handle is usable (got '$rrh')" `[ "$rrh" = "9" ] && echo 1 || echo 0`
#  back-compat: a row with NO input_names still gets the tokenizer pair
PROBE "delete from DB.DBA.ONNX_MODELS where model_name = 'tvvec-tensor-tok';" >/dev/null 2>&1
PROBE "insert into DB.DBA.ONNX_MODELS (model_name, model_path, model_type, output_name, created_at, updated_at)
       values ('tvvec-tensor-tok', '$MODEL', 'onnx', 'y', now (), now ());" >/dev/null 2>&1
PROBE "select DB.DBA.ONNX_MODEL_REFRESH ('tvvec-tensor-tok');" >/dev/null 2>&1
tinfo=`RAW "select ONNX_MODEL_INFO ((select handle from DB.DBA.ONNX_MODELS where model_name = 'tvvec-tensor-tok'));"`
CHECK "a row without input_names still defaults to the tokenizer names" \
    `echo "$tinfo" | grep -q '"input":"input_ids"' && echo 1 || echo 0`

#  ---- Defect 6: authorization ---------------------------------------------
PROBE "DB.DBA.USER_CREATE ('onnxuser', 'onnxpass');" >/dev/null 2>&1
PROBE "GRANT SPARQL_SELECT TO \"onnxuser\";" >/dev/null 2>&1
uok=`PROBE "select case when exists (select 1 from DB.DBA.SYS_USERS where U_NAME = 'onnxuser') then 1 else 0 end;"`
if [ "$uok" != "1" ]
then
    LOG "+ could not create onnxuser; skipping the authorization group"
else
    ldm=`RAW_USER "select ONNX_LOAD_MODEL ('$MODEL', 'input=features;output=y');"`
    CHECK "non-DBA cannot load a model" `echo "$ldm" | grep -qi 'error' && echo 1 || echo 0`
    cfg=`RAW_USER "select ONNX_CONFIG ('log', 1);"`
    CHECK "non-DBA cannot change ONNX_CONFIG" `echo "$cfg" | grep -qi 'error' && echo 1 || echo 0`
    nfo=`RAW_USER "select ONNX_MODEL_INFO (NULL);"`
    CHECK "non-DBA cannot list models (paths are disclosure)" `echo "$nfo" | grep -qi 'error' && echo 1 || echo 0`
    #  ...but running an already-loaded model must stay open: the vector index
    #  calls the embedding BIFs as whatever account issued the query.
    run=`RAW_USER "select cast (aref (ONNX_RUN_F32 ($h, vector (3,0,0,0), vector (1,4)), 0) as integer);"`
    rv=`echo "$run" | grep -E '^[0-9-]+$' | head -1`
    CHECK "non-DBA CAN still run a loaded model (got '$rv')" `[ "$rv" = "3" ] && echo 1 || echo 0`
fi

#  ---- general tensor I/O -----------------------------------------------------
#  Every capability below must behave IDENTICALLY in-process and out-of-process.
#  A mode-dependent capability is the asymmetry dynamic axes already inflict on
#  users; asserting both modes is what stops a second one appearing.
#
#  Assertions reduce a result vector to one number, so PROBE can read it.
PROBE "create procedure tvvec_vsum (in v any)
       {
         declare i, n int; declare s double precision;
         if (isarray (v) = 0) return cast (v as double precision);
         s := 0; n := length (v);
         for (i := 0; i < n; i := i + 1)
           s := s + (case when isarray (aref (v, i)) then tvvec_vsum (aref (v, i))
                          else cast (aref (v, i) as double precision) end);
         return s;
       };" >/dev/null 2>&1

GENERAL_IO_CHECKS()   #  GENERAL_IO_CHECKS <mode>
{
    md=$1
    PROBE "select ONNX_CONFIG ('mode', '$md');" >/dev/null 2>&1

    #  rank > 4: the cap was 4 in the plugin and again in the helper
    h5=`PROBE "select ONNX_LOAD_MODEL ('$M_FIVE_D', 'input=x;output=y;mode=$md');"`
    v=`PROBE "select cast (tvvec_vsum (ONNX_RUN_F32 ($h5, vector (0,1,2,3), vector (1,1,1,2,2))) as integer);"`
    CHECK "[$md] rank-5 input runs (0+1+2+3=6, got '$v')" `[ "$v" = "6" ] && echo 1 || echo 0`

    #  two float inputs
    h2i=`PROBE "select ONNX_LOAD_MODEL ('$M_TWO_IN', 'mode=$md');"`
    v=`PROBE "select cast (tvvec_vsum (ONNX_RUN ($h2i,
          vector (vector ('a', vector (1,2,3,4),     vector (1,4)),
                  vector ('b', vector (10,20,30,40), vector (1,4))))) as integer);"`
    CHECK "[$md] two float inputs (11+22+33+44=110, got '$v')" `[ "$v" = "110" ] && echo 1 || echo 0`

    #  two outputs in one call: y = x, y2 = 2x
    h2o=`PROBE "select ONNX_LOAD_MODEL ('$M_TWO_OUT', 'mode=$md');"`
    v=`PROBE "select cast (tvvec_vsum (ONNX_RUN ($h2o,
          vector (vector ('x', vector (1,2,3,4), vector (1,4))),
          vector ('y', 'y2'))) as integer);"`
    CHECK "[$md] two outputs in one call (10+20=30, got '$v')" `[ "$v" = "30" ] && echo 1 || echo 0`
    n=`PROBE "select length (ONNX_RUN ($h2o,
          vector (vector ('x', vector (1,2,3,4), vector (1,4))),
          vector ('y', 'y2')));"`
    CHECK "[$md] two outputs come back as two results (got '$n')" `[ "$n" = "2" ] && echo 1 || echo 0`
    #  ...and one requested output keeps the single-result shape
    v=`PROBE "select cast (tvvec_vsum (ONNX_RUN ($h2o,
          vector (vector ('x', vector (1,2,3,4), vector (1,4))), 'y2')) as integer);"`
    CHECK "[$md] a single named output keeps its shape (2+4+6+8=20, got '$v')" `[ "$v" = "20" ] && echo 1 || echo 0`

    #  int64 output -- Cast truncates toward zero: 1.7,2.2,-3.9,4.0 -> 1,2,-3,4
    hio=`PROBE "select ONNX_LOAD_MODEL ('$M_INT_OUT', 'mode=$md');"`
    v=`PROBE "select cast (tvvec_vsum (ONNX_RUN ($hio,
          vector (vector ('x', vector (1.7, 2.2, -3.9, 4.0), vector (1,4))))) as integer);"`
    CHECK "[$md] int64 output is returned, not refused (1+2-3+4=4, got '$v')" `[ "$v" = "4" ] && echo 1 || echo 0`

    #  per-input dtypes in one call: float32 x + int64 n
    hmx=`PROBE "select ONNX_LOAD_MODEL ('$M_MIXED', 'mode=$md');"`
    v=`PROBE "select cast (tvvec_vsum (ONNX_RUN ($hmx,
          vector (vector ('x', vector (1,2,3,4), vector (1,4), 'float32'),
                  vector ('n', vector (100),     vector (1),   'int64')))) as integer);"`
    CHECK "[$md] mixed input dtypes (101+102+103+104=410, got '$v')" `[ "$v" = "410" ] && echo 1 || echo 0`

    #  feature scaling declared with the model, not copied into every wrapper.
    #  centre 1,2,3,4 / scale 2 turns 3,6,9,12 into 1,2,3,4 -> identity -> 10.
    hsc=`PROBE "select ONNX_LOAD_MODEL ('$MODEL', 'input=features;output=y;mode=$md;center=1,2,3,4;scale=2,2,2,2');"`
    v=`PROBE "select cast (tvvec_vsum (ONNX_RUN_F32 ($hsc, vector (3,6,9,12), vector (1,4))) as integer);"`
    CHECK "[$md] center=/scale= applied before inference (1+2+3+4=10, got '$v')" `[ "$v" = "10" ] && echo 1 || echo 0`
    #  and a differently-scaled load of the SAME file must not reuse that entry
    hsc2=`PROBE "select ONNX_LOAD_MODEL ('$MODEL', 'input=features;output=y;mode=$md;center=0,0,0,0;scale=1,1,1,1');"`
    CHECK "[$md] a different scaler is a different model entry ($hsc vs $hsc2)" \
        `[ -n "$hsc" ] && [ -n "$hsc2" ] && [ "$hsc" != "$hsc2" ] && echo 1 || echo 0`
    v=`PROBE "select cast (tvvec_vsum (ONNX_RUN_F32 ($hsc2, vector (3,6,9,12), vector (1,4))) as integer);"`
    CHECK "[$md] the unscaled entry is still unscaled (3+6+9+12=30, got '$v')" `[ "$v" = "30" ] && echo 1 || echo 0`
}

GENERAL_IO_CHECKS inproc
GENERAL_IO_CHECKS outproc
PROBE "select ONNX_CONFIG ('mode', 'inproc');" >/dev/null 2>&1

#  a model path outside DirsAllowed AND outside every declared model root must
#  be refused even for the DBA
out=`RAW "select ONNX_LOAD_MODEL ('/etc/passwd', 'mode=inproc');"`
LOG "+ outside DirsAllowed: `echo "$out" | grep -i error | head -1`"
CHECK "a path outside DirsAllowed is refused before ORT sees it" \
    `echo "$out" | grep -qiE 'FA003|is denied|not allowed' && echo 1 || echo 0`

SHUTDOWN_SERVER
rm -f "$MODEL" "$NOTAMODEL" "$MODEL_G" "$MODEL_B" \
      "$M_TWO_IN" "$M_TWO_OUT" "$M_INT_OUT" "$M_FIVE_D" "$M_MIXED"

LOG "+ ONNX tensor path: $PASS passed, $FAIL failed"
CHECK_LOG

if [ "$FAIL" != "0" ]
then
    BANNER "COMPLETED ONNX tensor path test -- FAILURES PRESENT"
    exit 1
fi

BANNER "COMPLETED ONNX tensor path test"
exit 0

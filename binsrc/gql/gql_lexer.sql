--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2026 OpenLink Software
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
--
--  openGQL: GQL for Virtuoso - Lexer/Tokenizer
--
--  Copyright (C) 1998-2026 OpenLink Software
--
--  Token types (integer constants):
--    Symbols (1-63):
--      1=LPAREN 2=RPAREN 3=LBRACKET 4=RBRACKET 5=LBRACE 6=RBRACE
--      7=COLON 8=DOT 9=COMMA 10=ARROW_R(->) 11=ARROW_L(<-)
--      12=DASH 13=LT 14=GT 15=EQ 16=NEQ(<> or !=)
--      17=LTE 18=GTE 19=PLUS 20=STAR 21=SLASH 22=PERCENT
--      23=CARET 24=BANG 25=PIPE 26=DOTDOT(..) 27=PLUSEQ(+=)
--      28=DOLLAR 29=AMPERSAND 30=DOUBLECOLON(::) 31=EQGT(=>)
--      32=TILDE 33=TILDE_GT(~>) 34=LT_TILDE(<~)
--      35=ARROW_R_PIPE(->|) 36=PIPE_ARROW_L(|->)
--      37=LT_TILDE_SLASH(<~/) 38=SLASH_TILDE_GT(/~>)
--      39=LT_MINUS_SLASH(<-/) 40=SLASH_MINUS_GT(/->)
--      41=LT_MINUS_GT(<->) 42=QUESTION 43=DOUBLE_DOLLAR($$)
--      44=BRACKET_RIGHT_ARROW(]->) 45=BRACKET_TILDE_RIGHT_ARROW(]~>)
--      46=MINUS_LEFT_BRACKET(-[) 47=TILDE_LEFT_BRACKET(~[)
--      48=SLASH_TILDE(/~) 49=SLASH_MINUS(/- or -/)
--      50=TILDE_SLASH(~/) 51=RIGHT_BRACKET_MINUS(]-)
--      52=RIGHT_BRACKET_TILDE(]~) 53=LEFT_ARROW_TILDE_BRACKET(<~[)
--    Values (64-79):
--      64=IDENT 65=STRING 66=INTEGER 67=FLOAT 68=PARAM
--      69=PNAME_NS 70=IRIREF 71=ACCENT_IDENT 72=DQ_STRING
--      73=LANGTAG
--    Keywords (200-524): see DB.DBA.GQL_KEYWORD below
--    Special: 999=EOF
--

----------------------------------------------------------------------
-- Keyword lookup (case-insensitive)
----------------------------------------------------------------------

create procedure DB.DBA.GQL_KEYWORD (in _w varchar)
{
  declare w varchar;
  w := upper (_w);
  -- DML
  if (w = 'MATCH') return 200;
  if (w = 'INSERT') return 201;
  if (w = 'SET') return 202;
  if (w = 'REMOVE') return 203;
  if (w = 'DELETE') return 204;
  if (w = 'RETURN') return 205;
  if (w = 'WHERE') return 206;
  if (w = 'OPTIONAL') return 207;
  if (w = 'FOR') return 208;
  if (w = 'FILTER') return 209;
  if (w = 'LET') return 210;
  -- ORDER/LIMIT
  if (w = 'ORDER') return 211;
  if (w = 'BY') return 212;
  if (w = 'ASC') return 213;
  if (w = 'DESC') return 214;
  if (w = 'LIMIT') return 215;
  if (w = 'OFFSET') return 216;
  if (w = 'SKIP') return 216;
  -- SET OPS
  if (w = 'UNION') return 218;
  if (w = 'EXCEPT') return 219;
  if (w = 'INTERSECT') return 220;
  if (w = 'ALL') return 221;
  if (w = 'DISTINCT') return 222;
  -- DDL
  if (w = 'CREATE') return 223;
  if (w = 'DROP') return 224;
  if (w = 'GRAPH') return 225;
  if (w = 'TYPE') return 226;
  if (w = 'PROPERTY') return 227;
  if (w = 'SCHEMA') return 228;
  -- CONDITIONALS
  if (w = 'IF') return 229;
  if (w = 'EXISTS') return 230;
  -- BOOLEAN
  if (w = 'NOT') return 231;
  if (w = 'AND') return 232;
  if (w = 'OR') return 233;
  if (w = 'XOR') return 234;
  if (w = 'IS') return 235;
  if (w = 'NULL') return 236;
  if (w = 'TRUE') return 237;
  if (w = 'FALSE') return 238;
  -- COMPARISON
  if (w = 'IN') return 239;
  if (w = 'LIKE') return 240;
  if (w = 'CONTAINS') return 525;
  if (w = 'OPTION') return 526;
  if (w = 'CONSTRUCT') return 527;
  if (w = 'DESCRIBE') return 528;
  if (w = 'AS') return 241;
  if (w = 'COPY') return 242;
  if (w = 'OF') return 243;
  -- SESSION
  if (w = 'SESSION') return 244;
  if (w = 'START') return 245;
  if (w = 'COMMIT') return 246;
  if (w = 'ROLLBACK') return 247;
  if (w = 'USE') return 248;
  if (w = 'AT') return 249;
  if (w = 'NEXT') return 250;
  -- YIELD/CALL
  if (w = 'YIELD') return 251;
  if (w = 'CALL') return 252;
  -- GRAPH REFS
  if (w = 'CURRENT_GRAPH') return 253;
  if (w = 'CURRENT_PROPERTY_GRAPH') return 254;
  if (w = 'ANY') return 255;
  -- CONDITIONALS (cont)
  if (w = 'CASE') return 256;
  if (w = 'WHEN') return 257;
  if (w = 'THEN') return 258;
  if (w = 'ELSE') return 259;
  if (w = 'END') return 260;
  -- AGGREGATES
  if (w = 'COUNT') return 261;
  if (w = 'GROUP') return 262;
  if (w = 'HAVING') return 263;
  -- WITH/UNWIND
  if (w = 'WITH') return 264;
  if (w = 'UNWIND') return 265;
  -- PATTERN ELEMENTS
  if (w = 'NODE') return 266;
  if (w = 'EDGE') return 267;
  if (w = 'RELATIONSHIP') return 268;
  if (w = 'PATH') return 269;
  if (w = 'PATHS') return 270;
  if (w = 'SHORTEST') return 271;
  if (w = 'WALK') return 272;
  if (w = 'LABEL') return 273;
  if (w = 'LABELS') return 274;
  if (w = 'LABELED') return 275;
  -- PROPERTY
  if (w = 'PROPERTY_EXISTS') return 276;
  if (w = 'SAME') return 277;
  -- VALUES
  if (w = 'VALUES') return 278;
  if (w = 'VALUE') return 279;
  if (w = 'VARIABLE') return 280;
  if (w = 'TABLE') return 281;
  if (w = 'BINDING') return 282;
  if (w = 'BINDINGS') return 283;
  -- DDL HELPERS
  if (w = 'DEFINE') return 284;
  if (w = 'PREFIX') return 285;
  if (w = 'FROM') return 286;
  if (w = 'INTO') return 287;
  if (w = 'FORCE') return 529;
  if (w = 'CAMELCASE') return 530;
  if (w = 'ASK') return 531;
  if (w = 'MINUS') return 532;
  if (w = 'MODIFY') return 533;
  -- ORDER FULL
  if (w = 'ASCENDING') return 288;
  if (w = 'DESCENDING') return 289;
  -- CATALOG
  if (w = 'CATALOG') return 290;
  if (w = 'DIRECTORY') return 291;
  if (w = 'FUNCTION') return 292;
  if (w = 'PROCEDURE') return 293;
  if (w = 'QUERY') return 294;
  -- COMPOSITE TYPES
  if (w = 'RECORD') return 295;
  if (w = 'RECORDS') return 296;
  if (w = 'LIST') return 297;
  if (w = 'ARRAY') return 298;
  -- SESSION CONTROL
  if (w = 'CLOSE') return 299;
  if (w = 'RESET') return 300;
  if (w = 'ZONE') return 301;
  -- TEMPORAL
  if (w = 'TIME') return 302;
  if (w = 'TEMPORAL') return 303;
  if (w = 'INSTANT') return 304;
  if (w = 'DATETIME') return 305;
  -- LOCAL/ZONED
  if (w = 'LOCAL') return 306;
  if (w = 'LOCAL_TIME') return 307;
  if (w = 'LOCAL_DATETIME') return 308;
  if (w = 'LOCAL_TIMESTAMP') return 309;
  if (w = 'ZONED') return 310;
  if (w = 'ZONED_TIME') return 311;
  if (w = 'ZONED_DATETIME') return 312;
  -- DATE/DURATION
  if (w = 'DATE') return 313;
  if (w = 'DURATION') return 314;
  if (w = 'YEAR') return 315;
  if (w = 'MONTH') return 316;
  if (w = 'DAY') return 317;
  if (w = 'HOUR') return 318;
  if (w = 'MINUTE') return 319;
  if (w = 'SECOND') return 320;
  if (w = 'TIMESTAMP') return 321;
  -- TRANSACTION
  if (w = 'TRANSACTION') return 322;
  if (w = 'READ') return 323;
  if (w = 'WRITE') return 324;
  if (w = 'ONLY') return 325;
  if (w = 'REPEATABLE') return 326;
  if (w = 'OPEN') return 327;
  if (w = 'FINISH') return 328;
  -- HOME
  if (w = 'HOME_GRAPH') return 329;
  if (w = 'HOME_PROPERTY_GRAPH') return 330;
  if (w = 'HOME_SCHEMA') return 331;
  -- CURRENT
  if (w = 'CURRENT_ROLE') return 332;
  if (w = 'CURRENT_USER') return 333;
  if (w = 'SESSION_USER') return 334;
  if (w = 'SYSTEM_USER') return 335;
  -- SECURITY
  if (w = 'GRANT') return 336;
  if (w = 'REVOKE') return 337;
  -- DDL MORE
  if (w = 'REPLACE') return 338;
  if (w = 'RENAME') return 339;
  if (w = 'ALTER') return 340;
  if (w = 'CONSTRAINT') return 341;
  -- GRAPH PROPERTIES
  if (w = 'UNIQUE') return 342;
  if (w = 'ACYCLIC') return 343;
  if (w = 'DIRECTED') return 344;
  if (w = 'UNDIRECTED') return 345;
  if (w = 'CONNECTING') return 346;
  -- PATH ELEMENTS
  if (w = 'SOURCE') return 347;
  if (w = 'DESTINATION') return 348;
  if (w = 'ELEMENT') return 349;
  if (w = 'ELEMENTS') return 350;
  if (w = 'ELEMENT_ID') return 351;
  -- KEEP
  if (w = 'KEEP') return 352;
  if (w = 'NO') return 353;
  -- UNICODE NORMALIZATION
  if (w = 'NFC') return 354;
  if (w = 'NFD') return 355;
  if (w = 'NFKC') return 356;
  if (w = 'NFKD') return 357;
  if (w = 'NORMALIZE') return 358;
  if (w = 'NORMALIZED') return 359;
  -- STRING
  if (w = 'SIMPLE') return 360;
  if (w = 'TRIM') return 361;
  if (w = 'BTRIM') return 362;
  if (w = 'LTRIM') return 363;
  if (w = 'RTRIM') return 364;
  if (w = 'SUBSTRING') return 365;
  if (w = 'SINGLE') return 366;
  -- CASE FUNCTIONS
  if (w = 'LOWER') return 367;
  if (w = 'UPPER') return 368;
  -- MATH
  if (w = 'ABS') return 369;
  if (w = 'CEIL') return 370;
  if (w = 'CEILING') return 371;
  if (w = 'FLOOR') return 372;
  if (w = 'MOD') return 373;
  if (w = 'POWER') return 374;
  if (w = 'EXP') return 375;
  if (w = 'SQRT') return 376;
  -- TRIG
  if (w = 'SIN') return 377;
  if (w = 'COS') return 378;
  if (w = 'TAN') return 379;
  if (w = 'COT') return 380;
  if (w = 'ASIN') return 381;
  if (w = 'ACOS') return 382;
  if (w = 'ATAN') return 383;
  if (w = 'SINH') return 384;
  if (w = 'COSH') return 385;
  if (w = 'TANH') return 386;
  -- DEG/RAD
  if (w = 'DEGREES') return 387;
  if (w = 'RADIANS') return 388;
  if (w = 'LOG') return 389;
  if (w = 'LN') return 390;
  -- STRING LENGTH
  if (w = 'CHAR_LENGTH') return 391;
  if (w = 'CHARACTER_LENGTH') return 392;
  if (w = 'BYTE_LENGTH') return 393;
  if (w = 'OCTET_LENGTH') return 394;
  if (w = 'SIZE') return 395;
  -- INFINITY
  if (w = 'INFINITY') return 396;
  -- CONDITIONAL FUNCTIONS
  if (w = 'COALESCE') return 397;
  if (w = 'NULLIF') return 398;
  if (w = 'IFNULL') return 399;
  if (w = 'GREATEST') return 400;
  if (w = 'LEAST') return 401;
  -- CAST
  if (w = 'CAST') return 402;
  -- AGGREGATE FUNCTIONS
  if (w = 'MAX') return 403;
  if (w = 'MIN') return 404;
  if (w = 'AVG') return 405;
  if (w = 'SUM') return 406;
  if (w = 'STDDEV_POP') return 407;
  if (w = 'STDDEV_SAMP') return 408;
  -- COLLECT
  if (w = 'COLLECT_LIST') return 409;
  if (w = 'PERCENTILE_CONT') return 410;
  if (w = 'PERCENTILE_DISC') return 411;
  -- PATH FUNCTIONS
  if (w = 'ORDINALITY') return 412;
  if (w = 'CARDINALITY') return 413;
  if (w = 'PATH_LENGTH') return 414;
  -- SPARQL
  if (w = 'BASE') return 415;
  if (w = 'USING') return 416;
  if (w = 'DATA') return 417;
  if (w = 'LOAD') return 418;
  if (w = 'CLEAR') return 419;
  if (w = 'SILENT') return 420;
  if (w = 'DEFAULT') return 421;
  if (w = 'TO') return 422;
  if (w = 'MOVE') return 423;
  if (w = 'ADD') return 424;
  if (w = 'SERVICE') return 425;
  if (w = 'NAMED') return 426;
  -- WITHOUT
  if (w = 'WITHOUT') return 427;
  if (w = 'NOTHING') return 428;
  -- IMPLIES
  if (w = 'IMPLIES') return 429;
  if (w = 'OTHERWISE') return 430;
  -- NEW
  if (w = 'NEW') return 431;
  -- GENERATED
  if (w = 'GENERATED') return 432;
  if (w = 'ALWAYS') return 433;
  -- DRYRUN
  if (w = 'DRYRUN') return 434;
  if (w = 'PASSWORD') return 435;
  -- DETACH / NODETACH
  if (w = 'DETACH') return 436;
  if (w = 'NODETACH') return 436;
  -- EXISTING
  if (w = 'EXISTING') return 437;
  if (w = 'FIRST') return 438;
  if (w = 'LAST') return 439;
  -- TRAIL
  if (w = 'TRAIL') return 440;
  if (w = 'LEADING') return 441;
  if (w = 'TRAILING') return 442;
  if (w = 'BOTH') return 443;
  -- UNIT
  if (w = 'UNIT') return 444;
  -- AGGREGATE
  if (w = 'AGGREGATE') return 445;
  if (w = 'AGGREGATES') return 446;
  if (w = 'PARTITION') return 447;
  if (w = 'GROUPS') return 448;
  -- ALL_DIFFERENT
  if (w = 'ALL_DIFFERENT') return 449;
  if (w = 'DIFFERENT') return 450;
  -- BOOLEAN TYPE
  if (w = 'BOOLEAN') return 451;
  if (w = 'BOOL') return 451;
  -- INT TYPE
  if (w = 'INT') return 452;
  if (w = 'INTEGER') return 452;
  if (w = 'SMALLINT') return 453;
  if (w = 'BIGINT') return 454;
  -- FLOAT TYPE
  if (w = 'FLOAT') return 455;
  if (w = 'REAL') return 455;
  if (w = 'DOUBLE') return 456;
  -- DEC TYPE
  if (w = 'DEC') return 457;
  if (w = 'DECIMAL') return 457;
  if (w = 'NUMERIC') return 458;
  -- BINARY TYPES
  if (w = 'BYTES') return 462;
  if (w = 'BINARY') return 463;
  if (w = 'VARBINARY') return 464;
  -- UNSIGNED INT TYPES
  if (w = 'UINT') return 465;
  if (w = 'USMALLINT') return 466;
  if (w = 'UBIGINT') return 467;
  -- SIGNED/UNSIGNED
  if (w = 'SIGNED') return 468;
  if (w = 'UNSIGNED') return 469;
  -- EXACT/APPROXIMATE
  if (w = 'EXACT') return 470;
  if (w = 'APPROXIMATE') return 471;
  -- SIZE MODIFIERS
  if (w = 'BIG') return 472;
  if (w = 'SMALL') return 473;
  -- TYPED
  if (w = 'TYPED') return 474;
  -- PROJECT
  if (w = 'PROJECT') return 475;
  if (w = 'SELECT') return 476;
  -- ABSTRACT
  if (w = 'ABSTRACT') return 477;
  -- CLONE
  if (w = 'CLONE') return 478;
  -- PRODUCT
  if (w = 'PRODUCT') return 479;
  -- ERROR
  if (w = 'ERROR') return 480;
  -- NUMBER/PRECISION
  if (w = 'NUMBER') return 481;
  if (w = 'PRECISION') return 482;
  -- CHAR/VARCHAR/STRING
  if (w = 'CHAR') return 483;
  if (w = 'VARCHAR') return 484;
  if (w = 'STRING') return 485;
  -- CHARACTERISTICS
  if (w = 'CHARACTERISTICS') return 486;
  -- EMIT
  if (w = 'EMIT') return 487;
  -- PARAMETER
  if (w = 'PARAMETER') return 488;
  if (w = 'PARAMETERS') return 489;
  -- GQLSTATUS
  if (w = 'GQLSTATUS') return 490;
  -- REFERENCE
  if (w = 'REFERENCE') return 491;
  if (w = 'INTERVAL') return 492;
  -- LEFT/RIGHT
  if (w = 'LEFT') return 493;
  if (w = 'RIGHT') return 494;
  -- EXTENDED TYPES (FLOAT)
  if (w = 'FLOAT16') return 495;
  if (w = 'FLOAT32') return 496;
  if (w = 'FLOAT64') return 497;
  if (w = 'FLOAT128') return 498;
  if (w = 'FLOAT256') return 499;
  -- EXTENDED TYPES (INT)
  if (w = 'INT8') return 500;
  if (w = 'INTEGER8') return 501;
  if (w = 'INT16') return 502;
  if (w = 'INTEGER16') return 503;
  if (w = 'INT32') return 504;
  if (w = 'INTEGER32') return 505;
  if (w = 'INT64') return 506;
  if (w = 'INTEGER64') return 507;
  if (w = 'INT128') return 508;
  if (w = 'INTEGER128') return 509;
  if (w = 'INT256') return 510;
  if (w = 'INTEGER256') return 511;
  -- EXTENDED TYPES (UINT)
  if (w = 'UINT8') return 512;
  if (w = 'UINT16') return 513;
  if (w = 'UINT32') return 514;
  if (w = 'UINT64') return 515;
  if (w = 'UINT128') return 516;
  if (w = 'UINT256') return 517;
  -- LOG10
  if (w = 'LOG10') return 518;
  -- NULLS
  if (w = 'NULLS') return 519;
  -- CURRENT DATE/TIME
  if (w = 'CURRENT_DATE') return 520;
  if (w = 'CURRENT_TIME') return 521;
  if (w = 'CURRENT_TIMESTAMP') return 522;
  if (w = 'CURRENT_SCHEMA') return 523;
  -- DURATION_BETWEEN
  if (w = 'DURATION_BETWEEN') return 524;
  return 0;
}
;

----------------------------------------------------------------------
-- Unicode escape decoder (supports \uXXXX and \UXXXXXX)
----------------------------------------------------------------------

create procedure DB.DBA.GQL_DECODE_UNICODE_ESCAPE (
  in _q varchar, in _start integer, in _err_pos integer, in _digits integer)
  returns varchar
{
  declare _qlen, _i, _ch, _digit, _cp integer;

  _qlen := length (_q);
  if (_start + _digits > _qlen)
    signal ('GQ001', sprintf ('Truncated \\%s escape in string literal at position %d',
      case when _digits = 6 then 'U' else 'u' end, _err_pos));
  _cp := 0;
  for (_i := 0; _i < _digits; _i := _i + 1)
    {
      _ch := aref (_q, _start + _i);
      if (_ch >= 48 and _ch <= 57) _digit := _ch - 48;
      else if (_ch >= 65 and _ch <= 70) _digit := _ch - 55;
      else if (_ch >= 97 and _ch <= 102) _digit := _ch - 87;
      else
        signal ('GQ001', sprintf ('Invalid hex digit ''%s'' in \\%s escape at position %d',
          chr (_ch), case when _digits = 6 then 'U' else 'u' end, _err_pos));
      _cp := _cp * 16 + _digit;
    }

  -- Encode as UTF-8
  if (_cp < 128)
    return chr (_cp);
  if (_cp < 2048)
    return concat (chr (192 + bit_shift (_cp, -6)),
                   chr (128 + mod (_cp, 64)));
  if (_cp < 65536)
    return concat (chr (224 + bit_shift (_cp, -12)),
                   chr (128 + mod (bit_shift (_cp, -6), 64)),
                   chr (128 + mod (_cp, 64)));
  return concat (chr (240 + bit_shift (_cp, -18)),
                 chr (128 + mod (bit_shift (_cp, -12), 64)),
                 chr (128 + mod (bit_shift (_cp, -6), 64)),
                 chr (128 + mod (_cp, 64)));
}
;

----------------------------------------------------------------------
-- Token accessors
----------------------------------------------------------------------

create procedure DB.DBA.GQL_TOK_TYPE (in _tok any) { return aref (_tok, 0); }
;
create procedure DB.DBA.GQL_TOK_VAL (in _tok any) { return aref (_tok, 1); }
;
create procedure DB.DBA.GQL_TOK_LINE (in _tok any) { return aref (aref (_tok, 2), 0); }
;
create procedure DB.DBA.GQL_TOK_COL (in _tok any) { return aref (aref (_tok, 2), 1); }
;

----------------------------------------------------------------------
-- Character classification helpers
----------------------------------------------------------------------

create procedure DB.DBA.GQL_IS_IDENT_START (in ch integer)
{
  if (ch >= 65 and ch <= 90) return 1;  -- A-Z
  if (ch >= 97 and ch <= 122) return 1; -- a-z
  if (ch = 95) return 1;                -- _
  return 0;
}
;

create procedure DB.DBA.GQL_IS_IDENT_CHAR (in ch integer)
{
  if (ch >= 65 and ch <= 90) return 1;  -- A-Z
  if (ch >= 97 and ch <= 122) return 1; -- a-z
  if (ch >= 48 and ch <= 57) return 1;  -- 0-9
  if (ch = 95) return 1;                -- _
  return 0;
}
;

create procedure DB.DBA.GQL_IS_PNAME_PREFIX_CHAR (in ch integer)
{
  if (DB.DBA.GQL_IS_IDENT_CHAR (ch)) return 1;
  if (ch = 45) return 1;                -- -
  return 0;
}
;

create procedure DB.DBA.GQL_IS_DIGIT (in ch integer)
{
  if (ch >= 48 and ch <= 57) return 1;
  return 0;
}
;

create procedure DB.DBA.GQL_IS_HEX_DIGIT (in ch integer)
{
  if (ch >= 48 and ch <= 57) return 1;
  if (ch >= 65 and ch <= 70) return 1;
  if (ch >= 97 and ch <= 102) return 1;
  return 0;
}
;

----------------------------------------------------------------------
-- Parser cursor helpers
----------------------------------------------------------------------

create procedure DB.DBA.GQL_PEEK (in _tokens any, in _pos integer)
{
  if (_pos >= length (_tokens))
    return 999;
  return DB.DBA.GQL_TOK_TYPE (aref (_tokens, _pos));
}
;

create procedure DB.DBA.GQL_PEEK_VAL (in _tokens any, in _pos integer)
{
  if (_pos >= length (_tokens))
    return '';
  return DB.DBA.GQL_TOK_VAL (aref (_tokens, _pos));
}
;

create procedure DB.DBA.GQL_CHECK (in _tokens any, in _pos integer, in _type integer)
{
  if (DB.DBA.GQL_PEEK (_tokens, _pos) = _type)
    return 1;
  return 0;
}
;

create procedure DB.DBA.GQL_EXPECT (in _tokens any, inout _pos integer, in _type integer)
{
  if (DB.DBA.GQL_PEEK (_tokens, _pos) <> _type)
    signal ('GQ002', sprintf ('Expected token type %d but got %d at position %d',
      _type, DB.DBA.GQL_PEEK (_tokens, _pos), _pos));
  _pos := _pos + 1;
}
;

----------------------------------------------------------------------
-- Main tokenizer
----------------------------------------------------------------------

create procedure DB.DBA.GQL_TOKENIZE (in _q varchar)
{
  declare tokens any;
  declare i, qlen, ch, ch2, ch3, kw, iri_end, line, col, start_line, start_col, _digit_cnt integer;
  declare val varchar;

  tokens := vector ();
  qlen := length (_q);
  i := 0;
  line := 1;
  col := 1;

  while (i < qlen)
    {
      ch := aref (_q, i);

      -- Skip whitespace
      if (ch = 32 or ch = 9 or ch = 13)
        { i := i + 1; col := col + 1; }
      else if (ch = 10)
        { i := i + 1; line := line + 1; col := 1; }

      -- Comments
      else if (ch = 47 and i + 1 < qlen)  -- '/'
        {
          ch2 := aref (_q, i + 1);
          if (ch2 = 47)  -- '//'
            {
              i := i + 2;
              while (i < qlen and aref (_q, i) <> 10)
                i := i + 1;
            }
          else if (ch2 = 42)  -- '/*'
            {
              start_line := line;
              i := i + 2;
              col := col + 2;
              while (i < qlen)
                {
                  if (aref (_q, i) = 42 and i + 1 < qlen and aref (_q, i + 1) = 47)
                    { i := i + 2; col := col + 2; goto block_comment_done; }
                  if (aref (_q, i) = 10)
                    { line := line + 1; col := 1; }
                  else
                    col := col + 1;
                  i := i + 1;
                }
              signal ('GQ001', sprintf ('Unterminated block comment starting at line %d', start_line));
              block_comment_done:;
            }
          else
            goto slash_token;
        }
      -- '--' line comment (GQL addition)
      else if (ch = 45 and i + 1 < qlen and aref (_q, i + 1) = 45)  -- '--'
        {
          i := i + 2;
          while (i < qlen and aref (_q, i) <> 10)
            i := i + 1;
        }

      -- '<' : many multi-char operators and IRIREF
      else if (ch = 60)
        {
          ch2 := 0; if (i + 1 < qlen) ch2 := aref (_q, i + 1);
          ch3 := 0; if (i + 2 < qlen) ch3 := aref (_q, i + 2);
          if (ch2 = 126 and ch3 = 91)  -- '<~['
            { tokens := vector_concat (tokens, vector (vector (53, '<~[', vector (line, col)))); i := i + 3; col := col + 3; }
          else if (ch2 = 126 and ch3 = 47)  -- '<~/'
            { tokens := vector_concat (tokens, vector (vector (37, '<~/', vector (line, col)))); i := i + 3; col := col + 3; }
          else if (ch2 = 126)  -- '<~'
            { tokens := vector_concat (tokens, vector (vector (34, '<~', vector (line, col)))); i := i + 2; col := col + 2; }
          else if (ch2 = 45 and ch3 = 62)  -- '<->'
            { tokens := vector_concat (tokens, vector (vector (41, '<->', vector (line, col)))); i := i + 3; col := col + 3; }
          else if (ch2 = 45 and ch3 = 47)  -- '<-/'
            { tokens := vector_concat (tokens, vector (vector (39, '<-/', vector (line, col)))); i := i + 3; col := col + 3; }
          else if (ch2 = 45)  -- '<-'
            { tokens := vector_concat (tokens, vector (vector (11, '<-', vector (line, col)))); i := i + 2; col := col + 2; }
          else if (ch2 = 62)  -- '<>'
            { tokens := vector_concat (tokens, vector (vector (16, '<>', vector (line, col)))); i := i + 2; col := col + 2; }
          else if (ch2 = 61)  -- '<='
            { tokens := vector_concat (tokens, vector (vector (17, '<=', vector (line, col)))); i := i + 2; col := col + 2; }
          else
            {
              -- IRIREF: <...>
              iri_end := i + 1;
              while (iri_end < qlen and aref (_q, iri_end) <> 62 and aref (_q, iri_end) > 32)
                iri_end := iri_end + 1;
              if (iri_end < qlen and aref (_q, iri_end) = 62)
                {
                  tokens := vector_concat (tokens, vector (vector (70, subseq (_q, i + 1, iri_end), vector (line, col))));
                  col := col + (iri_end - i + 1);
                  i := iri_end + 1;
                }
              else
                { tokens := vector_concat (tokens, vector (vector (13, '<', vector (line, col)))); i := i + 1; col := col + 1; }
            }
        }

      -- '>' : GTE or GT
      else if (ch = 62)
        {
          if (i + 1 < qlen and aref (_q, i + 1) = 61)
            { tokens := vector_concat (tokens, vector (vector (18, '>=', vector (line, col)))); i := i + 2; col := col + 2; }
          else
            { tokens := vector_concat (tokens, vector (vector (14, '>', vector (line, col)))); i := i + 1; col := col + 1; }
        }

      -- '-' : many edge/path operators
      else if (ch = 45)
        {
          ch2 := 0; if (i + 1 < qlen) ch2 := aref (_q, i + 1);
          ch3 := 0; if (i + 2 < qlen) ch3 := aref (_q, i + 2);
          if (ch2 = 62 and ch3 = 124)  -- '->|'
            { tokens := vector_concat (tokens, vector (vector (35, '->|', vector (line, col)))); i := i + 3; col := col + 3; }
          else if (ch2 = 62)  -- '->'
            { tokens := vector_concat (tokens, vector (vector (10, '->', vector (line, col)))); i := i + 2; col := col + 2; }
          else if (ch2 = 91)  -- '-['
            { tokens := vector_concat (tokens, vector (vector (46, '-[', vector (line, col)))); i := i + 2; col := col + 2; }
          else if (ch2 = 47)  -- '-/'
            { tokens := vector_concat (tokens, vector (vector (49, '-/', vector (line, col)))); i := i + 2; col := col + 2; }
          else if (ch2 = 45)  -- '--' handled in comment section above
            { tokens := vector_concat (tokens, vector (vector (12, '-', vector (line, col)))); i := i + 1; col := col + 1; }
          else
            { tokens := vector_concat (tokens, vector (vector (12, '-', vector (line, col)))); i := i + 1; col := col + 1; }
        }

      -- '|' : PIPE_ARROW_L, ||, or PIPE
      else if (ch = 124)
        {
          if (i + 2 < qlen and aref (_q, i + 1) = 45 and aref (_q, i + 2) = 62)  -- '|->'
            {
              if (i + 3 < qlen and aref (_q, i + 3) = 62)
                { tokens := vector_concat (tokens, vector (vector (25, '|', vector (line, col)))); i := i + 1; col := col + 1; }  -- split to avoid eating '|->>' wrong
              else
                { tokens := vector_concat (tokens, vector (vector (36, '|->', vector (line, col)))); i := i + 3; col := col + 3; }
            }
          else if (i + 1 < qlen and aref (_q, i + 1) = 124)  -- '||'
            { tokens := vector_concat (tokens, vector (vector (54, '||', vector (line, col)))); i := i + 2; col := col + 2; }
          else
            { tokens := vector_concat (tokens, vector (vector (25, '|', vector (line, col)))); i := i + 1; col := col + 1; }
        }

      -- '~' : undirected edge operators
      else if (ch = 126)
        {
          ch2 := 0; if (i + 1 < qlen) ch2 := aref (_q, i + 1);
          if (ch2 = 62)  -- '~>'
            { tokens := vector_concat (tokens, vector (vector (33, '~>', vector (line, col)))); i := i + 2; col := col + 2; }
          else if (ch2 = 91)  -- '~['
            { tokens := vector_concat (tokens, vector (vector (47, '~[', vector (line, col)))); i := i + 2; col := col + 2; }
          else if (ch2 = 47)  -- '~/'
            { tokens := vector_concat (tokens, vector (vector (50, '~/', vector (line, col)))); i := i + 2; col := col + 2; }
          else
            { tokens := vector_concat (tokens, vector (vector (32, '~', vector (line, col)))); i := i + 1; col := col + 1; }
        }

      -- '/' : comment, path operators, or SLASH
      else if (ch = 47)
        {
          slash_token:
          ch2 := 0; if (i + 1 < qlen) ch2 := aref (_q, i + 1);
          if (ch2 = 126)  -- '/~'
            {
              ch3 := 0; if (i + 2 < qlen) ch3 := aref (_q, i + 2);
              if (ch3 = 62)  -- '/~>'
                { tokens := vector_concat (tokens, vector (vector (38, '/~>', vector (line, col)))); i := i + 3; col := col + 3; }
              else
                { tokens := vector_concat (tokens, vector (vector (48, '/~', vector (line, col)))); i := i + 2; col := col + 2; }
            }
          else if (ch2 = 45 and i + 2 < qlen and aref (_q, i + 2) = 62)  -- '/->'
            { tokens := vector_concat (tokens, vector (vector (40, '/->', vector (line, col)))); i := i + 3; col := col + 3; }
          else if (ch2 = 45)  -- '/-'
            { tokens := vector_concat (tokens, vector (vector (49, '/-', vector (line, col)))); i := i + 2; col := col + 2; }
          else
            { tokens := vector_concat (tokens, vector (vector (21, '/', vector (line, col)))); i := i + 1; col := col + 1; }
        }

      -- ':' : DOUBLECOLON or COLON
      else if (ch = 58)
        {
          if (i + 1 < qlen and aref (_q, i + 1) = 58)
            { tokens := vector_concat (tokens, vector (vector (30, '::', vector (line, col)))); i := i + 2; col := col + 2; }
          else
            { tokens := vector_concat (tokens, vector (vector (7, ':', vector (line, col)))); i := i + 1; col := col + 1; }
        }

      -- '.' : DOTDOT, leading-dot float, or DOT
      else if (ch = 46)
        {
          if (i + 1 < qlen and aref (_q, i + 1) = 46)
            { tokens := vector_concat (tokens, vector (vector (26, '..', vector (line, col)))); i := i + 2; col := col + 2; }
          else if (i + 1 < qlen and DB.DBA.GQL_IS_DIGIT (aref (_q, i + 1)))
            {
              -- Leading-dot float: .5, .5e10, .5F
              start_line := line; start_col := col;
              val := '.';
              i := i + 1; col := col + 1;
              while (i < qlen and DB.DBA.GQL_IS_DIGIT (aref (_q, i)))
                { val := concat (val, chr (aref (_q, i))); i := i + 1; col := col + 1; }
              -- Optional exponent
              if (i < qlen and (aref (_q, i) = 101 or aref (_q, i) = 69))  -- 'e' or 'E'
                {
                  val := concat (val, chr (aref (_q, i))); i := i + 1; col := col + 1;
                  if (i < qlen and (aref (_q, i) = 43 or aref (_q, i) = 45))  -- '+' or '-'
                    { val := concat (val, chr (aref (_q, i))); i := i + 1; col := col + 1; }
                  while (i < qlen and DB.DBA.GQL_IS_DIGIT (aref (_q, i)))
                    { val := concat (val, chr (aref (_q, i))); i := i + 1; col := col + 1; }
                }
              -- Optional suffix
              if (i < qlen and (aref (_q, i) = 70 or aref (_q, i) = 68))  -- 'F' or 'D'
                { val := concat (val, chr (aref (_q, i))); i := i + 1; col := col + 1; }
              tokens := vector_concat (tokens, vector (vector (67, val, vector (start_line, start_col))));
            }
          else
            { tokens := vector_concat (tokens, vector (vector (8, '.', vector (line, col)))); i := i + 1; col := col + 1; }
        }

      -- '=' : EQGT(=>) or EQ
      else if (ch = 61)
        {
          if (i + 1 < qlen and aref (_q, i + 1) = 62)
            { tokens := vector_concat (tokens, vector (vector (31, '=>', vector (line, col)))); i := i + 2; col := col + 2; }
          else
            { tokens := vector_concat (tokens, vector (vector (15, '=', vector (line, col)))); i := i + 1; col := col + 1; }
        }

      -- '+' : PLUSEQ or PLUS
      else if (ch = 43)
        {
          if (i + 1 < qlen and aref (_q, i + 1) = 61)
            { tokens := vector_concat (tokens, vector (vector (27, '+=', vector (line, col)))); i := i + 2; col := col + 2; }
          else
            { tokens := vector_concat (tokens, vector (vector (19, '+', vector (line, col)))); i := i + 1; col := col + 1; }
        }

      -- '!' : NEQ or BANG
      else if (ch = 33)
        {
          if (i + 1 < qlen and aref (_q, i + 1) = 61)
            { tokens := vector_concat (tokens, vector (vector (16, '!=', vector (line, col)))); i := i + 2; col := col + 2; }
          else
            { tokens := vector_concat (tokens, vector (vector (24, '!', vector (line, col)))); i := i + 1; col := col + 1; }
        }

      -- ']' : bracket operators
      else if (ch = 93)
        {
          ch2 := 0; if (i + 1 < qlen) ch2 := aref (_q, i + 1);
          ch3 := 0; if (i + 2 < qlen) ch3 := aref (_q, i + 2);
          if (ch2 = 126 and ch3 = 62)  -- ']~>'
            { tokens := vector_concat (tokens, vector (vector (45, ']~>', vector (line, col)))); i := i + 3; col := col + 3; }
          else if (ch2 = 45 and ch3 = 62)  -- ']->'
            { tokens := vector_concat (tokens, vector (vector (44, ']->', vector (line, col)))); i := i + 3; col := col + 3; }
          else if (ch2 = 126)  -- ']~'
            { tokens := vector_concat (tokens, vector (vector (52, ']~', vector (line, col)))); i := i + 2; col := col + 2; }
          else if (ch2 = 45)  -- ']-'
            { tokens := vector_concat (tokens, vector (vector (51, ']-', vector (line, col)))); i := i + 2; col := col + 2; }
          else
            { tokens := vector_concat (tokens, vector (vector (4, ']', vector (line, col)))); i := i + 1; col := col + 1; }
        }

      -- '@' : NO_ESCAPE string prefix
      -- GQL does not define @ for language tags (unlike SPARQL/openCypher).
      -- @ that is not followed by a string delimiter is a lexer error.
      else if (ch = 64)
        {
          if (i + 1 < qlen and (aref (_q, i + 1) = 39 or aref (_q, i + 1) = 34 or aref (_q, i + 1) = 96))
            {
              -- NO_ESCAPE string: same token types but skip escape processing
              declare delim, tok_type integer;
              declare raw_val varchar;
              delim := aref (_q, i + 1);
              if (delim = 39) tok_type := 65;  -- single-quoted
              else if (delim = 34) tok_type := 72;  -- double-quoted
              else tok_type := 71;  -- backtick
              start_line := line; start_col := col;
              i := i + 2;  -- skip @ and opening delimiter
              col := col + 2;
              raw_val := '';
              while (i < qlen)
                {
                  ch2 := aref (_q, i);
                  if (ch2 = delim)
                    {
                      if (i + 1 < qlen and aref (_q, i + 1) = delim)
                        { raw_val := concat (raw_val, chr (delim)); i := i + 2; col := col + 2; }
                      else
                        { i := i + 1; col := col + 1; goto noescape_done; }
                    }
                  else
                    {
                      if (ch2 = 10) { line := line + 1; col := 1; }
                      else col := col + 1;
                      raw_val := concat (raw_val, chr (ch2));
                      i := i + 1;
                    }
                }
              signal ('GQ001', sprintf ('Unterminated NO_ESCAPE string starting at line %d', start_line));
              noescape_done:
              tokens := vector_concat (tokens, vector (vector (tok_type, raw_val, vector (start_line, start_col))));
            }
          else
            signal ('GQ001', sprintf ('Unexpected ''@'' at line %d, column %d — GQL does not support language tags; NO_ESCAPE must precede a string literal', line, col));
        }

      -- Simple single-char tokens
      else if (ch = 40) { tokens := vector_concat (tokens, vector (vector (1, '(', vector (line, col)))); i := i + 1; col := col + 1; }
      else if (ch = 41) { tokens := vector_concat (tokens, vector (vector (2, ')', vector (line, col)))); i := i + 1; col := col + 1; }
      else if (ch = 91) { tokens := vector_concat (tokens, vector (vector (3, '[', vector (line, col)))); i := i + 1; col := col + 1; }
      else if (ch = 123) { tokens := vector_concat (tokens, vector (vector (5, '{', vector (line, col)))); i := i + 1; col := col + 1; }
      else if (ch = 125) { tokens := vector_concat (tokens, vector (vector (6, '}', vector (line, col)))); i := i + 1; col := col + 1; }
      else if (ch = 44) { tokens := vector_concat (tokens, vector (vector (9, ',', vector (line, col)))); i := i + 1; col := col + 1; }
      else if (ch = 42) { tokens := vector_concat (tokens, vector (vector (20, '*', vector (line, col)))); i := i + 1; col := col + 1; }
      else if (ch = 37) { tokens := vector_concat (tokens, vector (vector (22, '%', vector (line, col)))); i := i + 1; col := col + 1; }
      else if (ch = 94) { tokens := vector_concat (tokens, vector (vector (23, '^', vector (line, col)))); i := i + 1; col := col + 1; }
      else if (ch = 38) { tokens := vector_concat (tokens, vector (vector (29, '&', vector (line, col)))); i := i + 1; col := col + 1; }

      -- Parameter prefixes
      else if (ch = 36)  -- '$'
        {
          start_line := line; start_col := col;
          if (i + 1 < qlen and aref (_q, i + 1) = 36)  -- '$$'
            {
              val := '$$';
              i := i + 2; col := col + 2;
              while (i < qlen and DB.DBA.GQL_IS_IDENT_CHAR (aref (_q, i)))
                { val := concat (val, chr (aref (_q, i))); i := i + 1; col := col + 1; }
              if (length (val) = 2)
                signal ('GQ001', sprintf ('Expected parameter name after ''%s%s'' at line %d, column %d',
                  chr (36), chr (36), start_line, start_col));
              tokens := vector_concat (tokens, vector (vector (68, val, vector (start_line, start_col))));
            }
          else if (i + 1 < qlen and DB.DBA.GQL_IS_IDENT_START (aref (_q, i + 1)))
            {
              val := chr (36);
              i := i + 1; col := col + 1;
              while (i < qlen and DB.DBA.GQL_IS_IDENT_CHAR (aref (_q, i)))
                { val := concat (val, chr (aref (_q, i))); i := i + 1; col := col + 1; }
              tokens := vector_concat (tokens, vector (vector (68, val, vector (start_line, start_col))));
            }
          else
            { tokens := vector_concat (tokens, vector (vector (28, chr (36), vector (line, col)))); i := i + 1; col := col + 1; }
        }
      else if (ch = 63)
        {
          start_line := line; start_col := col;
          if (i + 1 < qlen and DB.DBA.GQL_IS_IDENT_START (aref (_q, i + 1)))
            {
              val := chr (63);
              i := i + 1; col := col + 1;
              while (i < qlen and DB.DBA.GQL_IS_IDENT_CHAR (aref (_q, i)))
                { val := concat (val, chr (aref (_q, i))); i := i + 1; col := col + 1; }
              tokens := vector_concat (tokens, vector (vector (68, val, vector (start_line, start_col))));
            }
          else
            { tokens := vector_concat (tokens, vector (vector (42, chr (63), vector (line, col)))); i := i + 1; col := col + 1; }
        }

      -- String literals: single-quoted, double-quoted, backtick
      else if (ch = 39 or ch = 34 or ch = 96)  -- '\'', '"', '`'
        {
          declare delim, tok_type integer;
          delim := ch;
          if (delim = 39) tok_type := 65;  -- single-quoted
          else if (delim = 34) tok_type := 72;  -- double-quoted
          else tok_type := 71;  -- backtick

          start_line := line; start_col := col;
          i := i + 1;  -- skip opening delimiter
          col := col + 1;
          val := '';

          if (delim = 96)  -- backtick: FIXED logic (openCypher has a bug here)
            {
              while (i < qlen)
                {
                  ch2 := aref (_q, i);
                  if (ch2 = 96)  -- backtick
                    {
                      if (i + 1 < qlen and aref (_q, i + 1) = 96)
                        { val := concat (val, '`'); i := i + 2; col := col + 2; }
                      else
                        { i := i + 1; col := col + 1; goto backtick_done; }
                    }
                  else if (ch2 = 92 and i + 1 < qlen)  -- backslash escape
                    {
                      ch3 := aref (_q, i + 1);
                      if (ch3 = 96) { val := concat (val, '`'); i := i + 2; col := col + 2; }
                      else if (ch3 = 92) { val := concat (val, '\\'); i := i + 2; col := col + 2; }
                      else if (ch3 = 110) { val := concat (val, chr(10)); i := i + 2; col := col + 2; }
                      else if (ch3 = 114) { val := concat (val, chr(13)); i := i + 2; col := col + 2; }
                      else if (ch3 = 116) { val := concat (val, chr(9)); i := i + 2; col := col + 2; }
                      else if (ch3 = 98) { val := concat (val, chr(8)); i := i + 2; col := col + 2; }
                      else if (ch3 = 102) { val := concat (val, chr(12)); i := i + 2; col := col + 2; }
                      else if (ch3 = 117) { val := concat (val, DB.DBA.GQL_DECODE_UNICODE_ESCAPE (_q, i + 2, start_col, 4)); i := i + 6; col := col + 6; }
                      else if (ch3 = 85) { val := concat (val, DB.DBA.GQL_DECODE_UNICODE_ESCAPE (_q, i + 2, start_col, 6)); i := i + 8; col := col + 8; }
                      else { val := concat (val, chr(ch2), chr(ch3)); i := i + 2; col := col + 2; }
                    }
                  else
                    {
                      if (ch2 = 10) { line := line + 1; col := 1; }
                      else col := col + 1;
                      val := concat (val, chr (ch2));
                      i := i + 1;
                    }
                }
              signal ('GQ001', sprintf ('Unterminated backtick identifier starting at line %d', start_line));
              backtick_done:;
            }
          else  -- single or double quoted string
            {
              while (i < qlen)
                {
                  ch2 := aref (_q, i);
                  if (ch2 = delim)
                    {
                      if (i + 1 < qlen and aref (_q, i + 1) = delim)
                        { val := concat (val, chr (delim)); i := i + 2; col := col + 2; }
                      else
                        { i := i + 1; col := col + 1; goto string_done; }
                    }
                  else if (ch2 = 92 and i + 1 < qlen)  -- backslash escape
                    {
                      ch3 := aref (_q, i + 1);
                      if (ch3 = delim) { val := concat (val, chr (delim)); i := i + 2; col := col + 2; }
                      else if (ch3 = 92) { val := concat (val, '\\'); i := i + 2; col := col + 2; }
                      else if (ch3 = 110) { val := concat (val, chr(10)); i := i + 2; col := col + 2; }
                      else if (ch3 = 114) { val := concat (val, chr(13)); i := i + 2; col := col + 2; }
                      else if (ch3 = 116) { val := concat (val, chr(9)); i := i + 2; col := col + 2; }
                      else if (ch3 = 98) { val := concat (val, chr(8)); i := i + 2; col := col + 2; }
                      else if (ch3 = 102) { val := concat (val, chr(12)); i := i + 2; col := col + 2; }
                      else if (ch3 = 117) { val := concat (val, DB.DBA.GQL_DECODE_UNICODE_ESCAPE (_q, i + 2, start_col, 4)); i := i + 6; col := col + 6; }
                      else if (ch3 = 85) { val := concat (val, DB.DBA.GQL_DECODE_UNICODE_ESCAPE (_q, i + 2, start_col, 6)); i := i + 8; col := col + 8; }
                      else { val := concat (val, chr(ch2), chr(ch3)); i := i + 2; col := col + 2; }
                    }
                  else
                    {
                      if (ch2 = 10) { line := line + 1; col := 1; }
                      else col := col + 1;
                      val := concat (val, chr (ch2));
                      i := i + 1;
                    }
                }
              signal ('GQ001', sprintf ('Unterminated string literal starting at line %d', start_line));
              string_done:;
            }
          tokens := vector_concat (tokens, vector (vector (tok_type, val, vector (start_line, start_col))));
        }

      -- Numbers
      else if (DB.DBA.GQL_IS_DIGIT (ch))
        {
          start_line := line; start_col := col;
          val := '';
          declare is_float integer;
          is_float := 0;

          -- Check for 0x, 0o, 0b prefix
          if (ch = 48 and i + 1 < qlen)  -- '0'
            {
              ch2 := aref (_q, i + 1);
              if (ch2 = 120)  -- '0x' hex
                {
                  val := '0x'; i := i + 2; col := col + 2;
                  while (i < qlen and (DB.DBA.GQL_IS_HEX_DIGIT (aref (_q, i)) or aref (_q, i) = 95))
                    { if (aref (_q, i) <> 95) val := concat (val, chr (aref (_q, i))); i := i + 1; col := col + 1; }
                  tokens := vector_concat (tokens, vector (vector (66, val, vector (start_line, start_col))));
                  goto num_done;
                }
              else if (ch2 = 111)  -- '0o' octal
                {
                  val := '0o'; i := i + 2; col := col + 2;
                  while (i < qlen and ((aref (_q, i) >= 48 and aref (_q, i) <= 55) or aref (_q, i) = 95))
                    { if (aref (_q, i) <> 95) val := concat (val, chr (aref (_q, i))); i := i + 1; col := col + 1; }
                  tokens := vector_concat (tokens, vector (vector (66, val, vector (start_line, start_col))));
                  goto num_done;
                }
              else if (ch2 = 98)  -- '0b' binary (GQL addition)
                {
                  val := '0b'; i := i + 2; col := col + 2;
                  while (i < qlen and ((aref (_q, i) = 48 or aref (_q, i) = 49) or aref (_q, i) = 95))
                    { if (aref (_q, i) <> 95) val := concat (val, chr (aref (_q, i))); i := i + 1; col := col + 1; }
                  tokens := vector_concat (tokens, vector (vector (66, val, vector (start_line, start_col))));
                  goto num_done;
                }
            }

          -- Decimal number (integer or float)
          while (i < qlen and (DB.DBA.GQL_IS_DIGIT (aref (_q, i)) or aref (_q, i) = 95))
            { if (aref (_q, i) <> 95) val := concat (val, chr (aref (_q, i))); i := i + 1; col := col + 1; }

          -- Optional dot + more digits (float)
          if (i < qlen and aref (_q, i) = 46 and i + 1 < qlen and DB.DBA.GQL_IS_DIGIT (aref (_q, i + 1)))
            {
              is_float := 1;
              val := concat (val, '.'); i := i + 1; col := col + 1;
              while (i < qlen and (DB.DBA.GQL_IS_DIGIT (aref (_q, i)) or aref (_q, i) = 95))
                { if (aref (_q, i) <> 95) val := concat (val, chr (aref (_q, i))); i := i + 1; col := col + 1; }
            }

          -- Optional exponent
          if (i < qlen and (aref (_q, i) = 101 or aref (_q, i) = 69))  -- 'e' or 'E'
            {
              is_float := 1;
              val := concat (val, chr (aref (_q, i))); i := i + 1; col := col + 1;
              if (i < qlen and (aref (_q, i) = 43 or aref (_q, i) = 45))
                { val := concat (val, chr (aref (_q, i))); i := i + 1; col := col + 1; }
              while (i < qlen and (DB.DBA.GQL_IS_DIGIT (aref (_q, i)) or aref (_q, i) = 95))
                { if (aref (_q, i) <> 95) val := concat (val, chr (aref (_q, i))); i := i + 1; col := col + 1; }
            }

          -- Optional suffix: M (exact), F/D (approximate float)
          if (i < qlen and (aref (_q, i) = 77 or aref (_q, i) = 70 or aref (_q, i) = 68))
            {
              if (aref (_q, i) = 70 or aref (_q, i) = 68)  -- 'F' or 'D'
                is_float := 1;
              val := concat (val, chr (aref (_q, i))); i := i + 1; col := col + 1;
            }

          tokens := vector_concat (tokens, vector (vector (case when is_float then 67 else 66 end, val, vector (start_line, start_col))));
          num_done:;
        }

      -- Identifiers, keywords, prefixed names
      else if (DB.DBA.GQL_IS_IDENT_START (ch))
        {
          start_line := line; start_col := col;
          val := chr (ch);
          i := i + 1; col := col + 1;
          while (i < qlen and DB.DBA.GQL_IS_PNAME_PREFIX_CHAR (aref (_q, i)))
            { val := concat (val, chr (aref (_q, i))); i := i + 1; col := col + 1; }

          -- Check for prefixed name: identifier ':' identifier-start
          if (i < qlen and aref (_q, i) = 58 and i + 1 < qlen and DB.DBA.GQL_IS_IDENT_START (aref (_q, i + 1)))
            {
              val := concat (val, ':'); i := i + 1; col := col + 1;
              while (i < qlen and DB.DBA.GQL_IS_PNAME_PREFIX_CHAR (aref (_q, i)))
                { val := concat (val, chr (aref (_q, i))); i := i + 1; col := col + 1; }
              tokens := vector_concat (tokens, vector (vector (69, val, vector (start_line, start_col))));
            }
          else
            {
              kw := DB.DBA.GQL_KEYWORD (val);
              if (kw <> 0)
                tokens := vector_concat (tokens, vector (vector (kw, val, vector (start_line, start_col))));
              else
                tokens := vector_concat (tokens, vector (vector (64, val, vector (start_line, start_col))));
            }
        }

      -- Unrecognized character
      else
        signal ('GQ001', sprintf ('Unexpected character ''%s'' (code %d) at line %d, column %d', chr (ch), ch, line, col));

    }

  -- Append EOF token
  tokens := vector_concat (tokens, vector (vector (999, '', vector (line, col))));
  return tokens;
}
;

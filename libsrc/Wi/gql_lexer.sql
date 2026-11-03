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
--  GQL for Virtuoso - Lexer/Tokenizer
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
  -- Keyword id of an identifier, or 0.  Dispatch on the first character
  -- and the length before comparing strings: a plain comparison chain
  -- tried all 347 keywords for every identifier that is not one (each
  -- variable, label and property name).  Ids are unchanged; each keyword
  -- is spelled once, so the order of the comparisons does not matter.
  declare w varchar;
  declare c, n integer;
  if (_w is null)
    return 0;
  w := upper (_w);
  c := aref (w, 0);
  n := length (w);
  if (c = 65)  -- A
    {
      if (n = 2) { if (w = 'AS') return 241; if (w = 'AT') return 249; }
      else if (n = 3) { if (w = 'ABS') return 369; if (w = 'ADD') return 424; if (w = 'ALL') return 221; if (w = 'AND') return 232; if (w = 'ANY') return 255; if (w = 'ASC') return 213; if (w = 'ASK') return 531; if (w = 'AVG') return 405; }
      else if (n = 4) { if (w = 'ACOS') return 382; if (w = 'ASIN') return 381; if (w = 'ATAN') return 383; }
      else if (n = 5) { if (w = 'ALTER') return 340; if (w = 'ARRAY') return 298; }
      else if (n = 6) { if (w = 'ALWAYS') return 433; }
      else if (n = 7) { if (w = 'ACYCLIC') return 343; }
      else if (n = 8) { if (w = 'ABSTRACT') return 477; }
      else if (n = 9) { if (w = 'AGGREGATE') return 445; if (w = 'ASCENDING') return 288; }
      else if (n = 10) { if (w = 'AGGREGATES') return 446; }
      else if (n = 11) { if (w = 'APPROXIMATE') return 471; }
      else if (n = 13) { if (w = 'ALL_DIFFERENT') return 449; }
    }
  else if (c = 66)  -- B
    {
      if (n = 2) { if (w = 'BY') return 212; }
      else if (n = 3) { if (w = 'BIG') return 472; }
      else if (n = 4) { if (w = 'BASE') return 415; if (w = 'BOOL') return 451; if (w = 'BOTH') return 443; }
      else if (n = 5) { if (w = 'BTRIM') return 362; if (w = 'BYTES') return 462; }
      else if (n = 6) { if (w = 'BIGINT') return 454; if (w = 'BINARY') return 463; }
      else if (n = 7) { if (w = 'BINDING') return 282; if (w = 'BOOLEAN') return 451; }
      else if (n = 8) { if (w = 'BINDINGS') return 283; }
      else if (n = 9) { if (w = 'BIJECTION') return 538; }
      else if (n = 11) { if (w = 'BYTE_LENGTH') return 393; }
    }
  else if (c = 67)  -- C
    {
      if (n = 3) { if (w = 'COS') return 378; if (w = 'COT') return 380; }
      else if (n = 4) { if (w = 'CALL') return 252; if (w = 'CASE') return 256; if (w = 'CAST') return 402; if (w = 'CEIL') return 370; if (w = 'CHAR') return 483; if (w = 'COPY') return 242; if (w = 'COSH') return 385; if (w = 'CUBE') return 541; }
      else if (n = 5) { if (w = 'CLEAR') return 419; if (w = 'CLONE') return 478; if (w = 'CLOSE') return 299; if (w = 'COUNT') return 261; }
      else if (n = 6) { if (w = 'COMMIT') return 246; if (w = 'CREATE') return 223; }
      else if (n = 7) { if (w = 'CATALOG') return 290; if (w = 'CEILING') return 371; }
      else if (n = 8) { if (w = 'COALESCE') return 397; if (w = 'CONTAINS') return 525; }
      else if (n = 9) { if (w = 'CAMELCASE') return 530; if (w = 'CONSTRUCT') return 527; }
      else if (n = 10) { if (w = 'CONNECTING') return 346; if (w = 'CONSTRAINT') return 341; }
      else if (n = 11) { if (w = 'CARDINALITY') return 413; if (w = 'CHAR_LENGTH') return 391; }
      else if (n = 12) { if (w = 'COLLECT_LIST') return 409; if (w = 'CURRENT_DATE') return 520; if (w = 'CURRENT_ROLE') return 332; if (w = 'CURRENT_TIME') return 521; if (w = 'CURRENT_USER') return 333; }
      else if (n = 13) { if (w = 'CURRENT_GRAPH') return 253; }
      else if (n = 14) { if (w = 'CURRENT_SCHEMA') return 523; }
      else if (n = 15) { if (w = 'CHARACTERISTICS') return 486; }
      else if (n = 16) { if (w = 'CHARACTER_LENGTH') return 392; }
      else if (n = 17) { if (w = 'CURRENT_TIMESTAMP') return 522; }
      else if (n = 22) { if (w = 'CURRENT_PROPERTY_GRAPH') return 254; }
    }
  else if (c = 68)  -- D
    {
      if (n = 3) { if (w = 'DAY') return 317; if (w = 'DEC') return 457; }
      else if (n = 4) { if (w = 'DATA') return 417; if (w = 'DATE') return 313; if (w = 'DESC') return 214; if (w = 'DROP') return 224; }
      else if (n = 6) { if (w = 'DEFINE') return 284; if (w = 'DELETE') return 204; if (w = 'DETACH') return 436; if (w = 'DOUBLE') return 456; if (w = 'DRYRUN') return 434; }
      else if (n = 7) { if (w = 'DECIMAL') return 457; if (w = 'DEFAULT') return 421; if (w = 'DEGREES') return 387; }
      else if (n = 8) { if (w = 'DATETIME') return 305; if (w = 'DESCRIBE') return 528; if (w = 'DIRECTED') return 344; if (w = 'DISTINCT') return 222; if (w = 'DURATION') return 314; }
      else if (n = 9) { if (w = 'DIFFERENT') return 450; if (w = 'DIRECTORY') return 291; }
      else if (n = 10) { if (w = 'DESCENDING') return 289; }
      else if (n = 11) { if (w = 'DESTINATION') return 348; }
      else if (n = 16) { if (w = 'DURATION_BETWEEN') return 524; }
    }
  else if (c = 69)  -- E
    {
      if (n = 3) { if (w = 'END') return 260; if (w = 'EXP') return 375; }
      else if (n = 4) { if (w = 'EDGE') return 267; if (w = 'ELSE') return 259; if (w = 'EMIT') return 487; }
      else if (n = 5) { if (w = 'ERROR') return 480; if (w = 'EXACT') return 470; }
      else if (n = 6) { if (w = 'EXCEPT') return 219; if (w = 'EXISTS') return 230; }
      else if (n = 7) { if (w = 'ELEMENT') return 349; }
      else if (n = 8) { if (w = 'ELEMENTS') return 350; if (w = 'EXISTING') return 437; }
      else if (n = 10) { if (w = 'ELEMENT_ID') return 351; }
    }
  else if (c = 70)  -- F
    {
      if (n = 3) { if (w = 'FOR') return 208; }
      else if (n = 4) { if (w = 'FROM') return 286; }
      else if (n = 5) { if (w = 'FALSE') return 238; if (w = 'FIRST') return 438; if (w = 'FLOAT') return 455; if (w = 'FLOOR') return 372; if (w = 'FORCE') return 529; }
      else if (n = 6) { if (w = 'FILTER') return 209; if (w = 'FINISH') return 328; }
      else if (n = 7) { if (w = 'FLOAT16') return 495; if (w = 'FLOAT32') return 496; if (w = 'FLOAT64') return 497; }
      else if (n = 8) { if (w = 'FLOAT128') return 498; if (w = 'FLOAT256') return 499; if (w = 'FUNCTION') return 292; }
    }
  else if (c = 71)  -- G
    {
      if (n = 5) { if (w = 'GRANT') return 336; if (w = 'GRAPH') return 225; if (w = 'GROUP') return 262; }
      else if (n = 6) { if (w = 'GROUPS') return 448; }
      else if (n = 8) { if (w = 'GREATEST') return 400; if (w = 'GROUPING') return 539; }
      else if (n = 9) { if (w = 'GENERATED') return 432; if (w = 'GQLSTATUS') return 490; }
    }
  else if (c = 72)  -- H
    {
      if (n = 4) { if (w = 'HOUR') return 318; }
      else if (n = 6) { if (w = 'HAVING') return 263; }
      else if (n = 10) { if (w = 'HOME_GRAPH') return 329; }
      else if (n = 11) { if (w = 'HOME_SCHEMA') return 331; }
      else if (n = 19) { if (w = 'HOME_PROPERTY_GRAPH') return 330; }
    }
  else if (c = 73)  -- I
    {
      if (n = 2) { if (w = 'IF') return 229; if (w = 'IN') return 239; if (w = 'IS') return 235; }
      else if (n = 3) { if (w = 'INT') return 452; }
      else if (n = 4) { if (w = 'INT8') return 500; if (w = 'INTO') return 287; }
      else if (n = 5) { if (w = 'INT16') return 502; if (w = 'INT32') return 504; if (w = 'INT64') return 506; }
      else if (n = 6) { if (w = 'IFNULL') return 399; if (w = 'INSERT') return 201; if (w = 'INT128') return 508; if (w = 'INT256') return 510; }
      else if (n = 7) { if (w = 'IMPLIES') return 429; if (w = 'INSTANT') return 304; if (w = 'INTEGER') return 452; }
      else if (n = 8) { if (w = 'INFINITY') return 396; if (w = 'INTEGER8') return 501; if (w = 'INTERVAL') return 492; }
      else if (n = 9) { if (w = 'INTEGER16') return 503; if (w = 'INTEGER32') return 505; if (w = 'INTEGER64') return 507; if (w = 'INTERSECT') return 220; }
      else if (n = 10) { if (w = 'INTEGER128') return 509; if (w = 'INTEGER256') return 511; }
    }
  else if (c = 75)  -- K
    {
      if (n = 4) { if (w = 'KEEP') return 352; }
    }
  else if (c = 76)  -- L
    {
      if (n = 2) { if (w = 'LN') return 390; }
      else if (n = 3) { if (w = 'LET') return 210; if (w = 'LOG') return 389; }
      else if (n = 4) { if (w = 'LAST') return 439; if (w = 'LEFT') return 493; if (w = 'LIKE') return 240; if (w = 'LIST') return 297; if (w = 'LOAD') return 418; }
      else if (n = 5) { if (w = 'LABEL') return 273; if (w = 'LEAST') return 401; if (w = 'LIMIT') return 215; if (w = 'LOCAL') return 306; if (w = 'LOG10') return 518; if (w = 'LOWER') return 367; if (w = 'LTRIM') return 363; }
      else if (n = 6) { if (w = 'LABELS') return 274; }
      else if (n = 7) { if (w = 'LABELED') return 275; if (w = 'LEADING') return 441; }
      else if (n = 10) { if (w = 'LOCAL_TIME') return 307; }
      else if (n = 14) { if (w = 'LOCAL_DATETIME') return 308; }
      else if (n = 15) { if (w = 'LOCAL_TIMESTAMP') return 309; }
    }
  else if (c = 77)  -- M
    {
      if (n = 3) { if (w = 'MAX') return 403; if (w = 'MIN') return 404; if (w = 'MOD') return 373; }
      else if (n = 4) { if (w = 'MOVE') return 423; }
      else if (n = 5) { if (w = 'MATCH') return 200; if (w = 'MINUS') return 532; if (w = 'MONTH') return 316; }
      else if (n = 6) { if (w = 'MINUTE') return 319; if (w = 'MODIFY') return 533; }
    }
  else if (c = 78)  -- N
    {
      if (n = 2) { if (w = 'NO') return 353; }
      else if (n = 3) { if (w = 'NEW') return 431; if (w = 'NFC') return 354; if (w = 'NFD') return 355; if (w = 'NOT') return 231; }
      else if (n = 4) { if (w = 'NEXT') return 250; if (w = 'NFKC') return 356; if (w = 'NFKD') return 357; if (w = 'NODE') return 266; if (w = 'NULL') return 236; }
      else if (n = 5) { if (w = 'NAMED') return 426; if (w = 'NULLS') return 519; }
      else if (n = 6) { if (w = 'NULLIF') return 398; if (w = 'NUMBER') return 481; }
      else if (n = 7) { if (w = 'NOTHING') return 428; if (w = 'NUMERIC') return 458; }
      else if (n = 8) { if (w = 'NODETACH') return 547; }
      else if (n = 9) { if (w = 'NORMALIZE') return 358; }
      else if (n = 10) { if (w = 'NORMALIZED') return 359; }
    }
  else if (c = 79)  -- O
    {
      if (n = 2) { if (w = 'OF') return 243; if (w = 'OR') return 233; }
      else if (n = 4) { if (w = 'ONLY') return 325; if (w = 'OPEN') return 327; }
      else if (n = 5) { if (w = 'ORDER') return 211; }
      else if (n = 6) { if (w = 'OFFSET') return 216; if (w = 'OPTION') return 526; }
      else if (n = 8) { if (w = 'OPTIONAL') return 207; }
      else if (n = 9) { if (w = 'OTHERWISE') return 430; }
      else if (n = 10) { if (w = 'ORDINALITY') return 412; }
      else if (n = 12) { if (w = 'OCTET_LENGTH') return 394; }
    }
  else if (c = 80)  -- P
    {
      if (n = 4) { if (w = 'PATH') return 269; }
      else if (n = 5) { if (w = 'PATHS') return 270; if (w = 'POWER') return 374; }
      else if (n = 6) { if (w = 'PREFIX') return 285; }
      else if (n = 7) { if (w = 'PRODUCT') return 479; if (w = 'PROJECT') return 475; }
      else if (n = 8) { if (w = 'PASSWORD') return 435; if (w = 'PROPERTY') return 227; }
      else if (n = 9) { if (w = 'PARAMETER') return 488; if (w = 'PARTITION') return 447; if (w = 'PRECISION') return 482; if (w = 'PROCEDURE') return 293; }
      else if (n = 10) { if (w = 'PARAMETERS') return 489; }
      else if (n = 11) { if (w = 'PATH_LENGTH') return 414; }
      else if (n = 15) { if (w = 'PERCENTILE_CONT') return 410; if (w = 'PERCENTILE_DISC') return 411; if (w = 'PROPERTY_EXISTS') return 276; }
    }
  else if (c = 81)  -- Q
    {
      if (n = 5) { if (w = 'QUERY') return 294; }
    }
  else if (c = 82)  -- R
    {
      if (n = 4) { if (w = 'READ') return 323; if (w = 'REAL') return 455; }
      else if (n = 5) { if (w = 'RESET') return 300; if (w = 'RIGHT') return 494; if (w = 'RTRIM') return 364; }
      else if (n = 6) { if (w = 'RECORD') return 295; if (w = 'REMOVE') return 203; if (w = 'RENAME') return 339; if (w = 'RETURN') return 205; if (w = 'REVOKE') return 337; if (w = 'ROLLUP') return 542; }
      else if (n = 7) { if (w = 'RADIANS') return 388; if (w = 'RECORDS') return 296; if (w = 'REPLACE') return 338; }
      else if (n = 8) { if (w = 'ROLLBACK') return 247; }
      else if (n = 9) { if (w = 'REFERENCE') return 491; }
      else if (n = 10) { if (w = 'REPEATABLE') return 326; }
      else if (n = 12) { if (w = 'RELATIONSHIP') return 268; }
    }
  else if (c = 83)  -- S
    {
      if (n = 3) { if (w = 'SET') return 202; if (w = 'SIN') return 377; if (w = 'SUM') return 406; }
      else if (n = 4) { if (w = 'SAME') return 277; if (w = 'SETS') return 540; if (w = 'SINH') return 384; if (w = 'SIZE') return 395; if (w = 'SKIP') return 216; if (w = 'SQRT') return 376; }
      else if (n = 5) { if (w = 'SMALL') return 473; if (w = 'START') return 245; }
      else if (n = 6) { if (w = 'SCHEMA') return 228; if (w = 'SECOND') return 320; if (w = 'SELECT') return 476; if (w = 'SIGNED') return 468; if (w = 'SILENT') return 420; if (w = 'SIMPLE') return 360; if (w = 'SINGLE') return 366; if (w = 'SOURCE') return 347; if (w = 'STRING') return 485; }
      else if (n = 7) { if (w = 'SERVICE') return 425; if (w = 'SESSION') return 244; }
      else if (n = 8) { if (w = 'SHORTEST') return 271; if (w = 'SMALLINT') return 453; }
      else if (n = 9) { if (w = 'SUBSTRING') return 365; }
      else if (n = 10) { if (w = 'STDDEV_POP') return 407; }
      else if (n = 11) { if (w = 'STDDEV_SAMP') return 408; if (w = 'SYSTEM_USER') return 335; }
      else if (n = 12) { if (w = 'SESSION_USER') return 334; }
    }
  else if (c = 84)  -- T
    {
      if (n = 2) { if (w = 'TO') return 422; }
      else if (n = 3) { if (w = 'TAN') return 379; }
      else if (n = 4) { if (w = 'TANH') return 386; if (w = 'THEN') return 258; if (w = 'TIME') return 302; if (w = 'TRIM') return 361; if (w = 'TRUE') return 237; if (w = 'TYPE') return 226; }
      else if (n = 5) { if (w = 'TABLE') return 281; if (w = 'TRAIL') return 440; if (w = 'TYPED') return 474; }
      else if (n = 8) { if (w = 'TEMPORAL') return 303; if (w = 'TRAILING') return 442; }
      else if (n = 9) { if (w = 'TIMESTAMP') return 321; }
      else if (n = 10) { if (w = 'T_END_FLAG') return 535; if (w = 'T_FINAL_AS') return 536; if (w = 'T_NO_ORDER') return 537; }
      else if (n = 11) { if (w = 'TRANSACTION') return 322; }
      else if (n = 13) { if (w = 'T_CYCLES_ONLY') return 534; }
    }
  else if (c = 85)  -- U
    {
      if (n = 3) { if (w = 'USE') return 248; }
      else if (n = 4) { if (w = 'UINT') return 465; if (w = 'UNIT') return 444; }
      else if (n = 5) { if (w = 'UINT8') return 512; if (w = 'UNION') return 218; if (w = 'UPPER') return 368; if (w = 'USING') return 416; }
      else if (n = 6) { if (w = 'UINT16') return 513; if (w = 'UINT32') return 514; if (w = 'UINT64') return 515; if (w = 'UNIQUE') return 342; if (w = 'UNNEST') return 543; if (w = 'UNWIND') return 265; }
      else if (n = 7) { if (w = 'UBIGINT') return 467; if (w = 'UINT128') return 516; if (w = 'UINT256') return 517; }
      else if (n = 8) { if (w = 'UNSIGNED') return 469; }
      else if (n = 9) { if (w = 'USMALLINT') return 466; }
      else if (n = 10) { if (w = 'UNDIRECTED') return 345; }
    }
  else if (c = 86)  -- V
    {
      if (n = 5) { if (w = 'VALUE') return 279; }
      else if (n = 6) { if (w = 'VALUES') return 278; }
      else if (n = 7) { if (w = 'VARCHAR') return 484; if (w = 'VERSION') return 544; }
      else if (n = 8) { if (w = 'VARIABLE') return 280; }
      else if (n = 9) { if (w = 'VARBINARY') return 464; }
    }
  else if (c = 87)  -- W
    {
      if (n = 4) { if (w = 'WALK') return 272; if (w = 'WHEN') return 257; if (w = 'WITH') return 264; }
      else if (n = 5) { if (w = 'WHERE') return 206; if (w = 'WRITE') return 324; }
      else if (n = 7) { if (w = 'WITHOUT') return 427; }
    }
  else if (c = 88)  -- X
    {
      if (n = 3) { if (w = 'XOR') return 234; }
    }
  else if (c = 89)  -- Y
    {
      if (n = 4) { if (w = 'YEAR') return 315; }
      else if (n = 5) { if (w = 'YIELD') return 251; }
    }
  else if (c = 90)  -- Z
    {
      if (n = 4) { if (w = 'ZONE') return 301; }
      else if (n = 5) { if (w = 'ZONED') return 310; }
      else if (n = 10) { if (w = 'ZONED_TIME') return 311; }
      else if (n = 14) { if (w = 'ZONED_DATETIME') return 312; }
    }
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

-- A token is vector (type, value, vector (line, col)).  The cursor helpers
-- read one field with a multi-index aref, which copies only that field;
-- aref (_tokens, _pos) would copy the whole token on every look ahead.

create procedure DB.DBA.GQL_PEEK (inout _tokens any, in _pos integer)
{
  if (_pos >= length (_tokens))
    return 999;
  return aref (_tokens, _pos, 0);
}
;

create procedure DB.DBA.GQL_PEEK_VAL (inout _tokens any, in _pos integer)
{
  if (_pos >= length (_tokens))
    return '';
  return aref (_tokens, _pos, 1);
}
;

create procedure DB.DBA.GQL_CHECK (inout _tokens any, in _pos integer, in _type integer)
{
  if (_pos >= length (_tokens))
    return case when _type = 999 then 1 else 0 end;
  if (aref (_tokens, _pos, 0) = _type)
    return 1;
  return 0;
}
;

create procedure DB.DBA.GQL_EXPECT (inout _tokens any, inout _pos integer, in _type integer)
{
  if ((case when _pos >= length (_tokens) then 999 else aref (_tokens, _pos, 0) end) <> _type)
    signal ('GQ002', sprintf ('Expected token type %d but got %d at position %d',
      _type, DB.DBA.GQL_PEEK (_tokens, _pos), _pos));
  _pos := _pos + 1;
}
;

----------------------------------------------------------------------
-- Query text
----------------------------------------------------------------------

-- Query text comes narrow, in UTF-8 as isql and the HTTP endpoint pass it,
-- or wide, as a Unicode ODBC or JDBC client binds an NVARCHAR parameter.
-- The lexer, the translation caches and the generated SPARQL all work on
-- the narrow UTF-8 form, so a wide text is recoded to it.
create procedure DB.DBA.GQL_QUERY_TEXT (in _q any)
{
  if (iswidestring (_q))
    return charset_recode (_q, '_WIDE_', 'UTF-8');
  return _q;
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
  declare _sv any;
  declare _run, _c integer;

  _q := DB.DBA.GQL_QUERY_TEXT (_q);
  vectorbld_init (tokens);
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
          if (ch2 = 60)  -- '<<'  RDF 1.2 reified-triple / triple-term start
            { vectorbld_acc (tokens, vector (420, '<<', vector (line, col))); i := i + 2; col := col + 2; }
          else if (ch2 = 126 and ch3 = 91)  -- '<~['
            { vectorbld_acc (tokens, vector (53, '<~[', vector (line, col))); i := i + 3; col := col + 3; }
          else if (ch2 = 126 and ch3 = 47)  -- '<~/'
            { vectorbld_acc (tokens, vector (37, '<~/', vector (line, col))); i := i + 3; col := col + 3; }
          else if (ch2 = 126)  -- '<~'
            { vectorbld_acc (tokens, vector (34, '<~', vector (line, col))); i := i + 2; col := col + 2; }
          else if (ch2 = 45 and ch3 = 62)  -- '<->'
            { vectorbld_acc (tokens, vector (41, '<->', vector (line, col))); i := i + 3; col := col + 3; }
          else if (ch2 = 45 and ch3 = 47)  -- '<-/'
            { vectorbld_acc (tokens, vector (39, '<-/', vector (line, col))); i := i + 3; col := col + 3; }
          else if (ch2 = 45)  -- '<-'
            { vectorbld_acc (tokens, vector (11, '<-', vector (line, col))); i := i + 2; col := col + 2; }
          else if (ch2 = 62)  -- '<>'
            { vectorbld_acc (tokens, vector (16, '<>', vector (line, col))); i := i + 2; col := col + 2; }
          else if (ch2 = 61)  -- '<='
            { vectorbld_acc (tokens, vector (17, '<=', vector (line, col))); i := i + 2; col := col + 2; }
          else
            {
              -- IRIREF: <...>
              iri_end := i + 1;
              while (iri_end < qlen and aref (_q, iri_end) <> 62 and aref (_q, iri_end) > 32)
                iri_end := iri_end + 1;
              if (iri_end < qlen and aref (_q, iri_end) = 62)
                {
                  vectorbld_acc (tokens, vector (70, subseq (_q, i + 1, iri_end), vector (line, col)));
                  col := col + (iri_end - i + 1);
                  i := iri_end + 1;
                }
              else
                { vectorbld_acc (tokens, vector (13, '<', vector (line, col))); i := i + 1; col := col + 1; }
            }
        }

      -- '>' : GTE or GT
      else if (ch = 62)
        {
          ch2 := 0; if (i + 1 < qlen) ch2 := aref (_q, i + 1);
          if (ch2 = 62)  -- '>>'  RDF 1.2 reified-triple / triple-term end
            { vectorbld_acc (tokens, vector (421, '>>', vector (line, col))); i := i + 2; col := col + 2; }
          else if (ch2 = 61)  -- '>='
            { vectorbld_acc (tokens, vector (18, '>=', vector (line, col))); i := i + 2; col := col + 2; }
          else
            { vectorbld_acc (tokens, vector (14, '>', vector (line, col))); i := i + 1; col := col + 1; }
        }

      -- '-' : many edge/path operators
      else if (ch = 45)
        {
          ch2 := 0; if (i + 1 < qlen) ch2 := aref (_q, i + 1);
          ch3 := 0; if (i + 2 < qlen) ch3 := aref (_q, i + 2);
          if (ch2 = 62 and ch3 = 124)  -- '->|'
            { vectorbld_acc (tokens, vector (35, '->|', vector (line, col))); i := i + 3; col := col + 3; }
          else if (ch2 = 62)  -- '->'
            { vectorbld_acc (tokens, vector (10, '->', vector (line, col))); i := i + 2; col := col + 2; }
          else if (ch2 = 91)  -- '-['
            { vectorbld_acc (tokens, vector (46, '-[', vector (line, col))); i := i + 2; col := col + 2; }
          else if (ch2 = 47)  -- '-/'
            { vectorbld_acc (tokens, vector (49, '-/', vector (line, col))); i := i + 2; col := col + 2; }
          else if (ch2 = 45)  -- '--' handled in comment section above
            { vectorbld_acc (tokens, vector (12, '-', vector (line, col))); i := i + 1; col := col + 1; }
          else
            { vectorbld_acc (tokens, vector (12, '-', vector (line, col))); i := i + 1; col := col + 1; }
        }

      -- '|' : PIPE_ARROW_L, ||, or PIPE
      else if (ch = 124)
        {
          if (i + 2 < qlen and aref (_q, i + 1) = 45 and aref (_q, i + 2) = 62)  -- '|->'
            {
              if (i + 3 < qlen and aref (_q, i + 3) = 62)
                { vectorbld_acc (tokens, vector (25, '|', vector (line, col))); i := i + 1; col := col + 1; }  -- split to avoid eating '|->>' wrong
              else
                { vectorbld_acc (tokens, vector (36, '|->', vector (line, col))); i := i + 3; col := col + 3; }
            }
          else if (i + 1 < qlen and aref (_q, i + 1) = 124)  -- '||'
            { vectorbld_acc (tokens, vector (54, '||', vector (line, col))); i := i + 2; col := col + 2; }
          else
            { vectorbld_acc (tokens, vector (25, '|', vector (line, col))); i := i + 1; col := col + 1; }
        }

      -- '~' : undirected edge operators
      else if (ch = 126)
        {
          ch2 := 0; if (i + 1 < qlen) ch2 := aref (_q, i + 1);
          if (ch2 = 62)  -- '~>'
            { vectorbld_acc (tokens, vector (33, '~>', vector (line, col))); i := i + 2; col := col + 2; }
          else if (ch2 = 91)  -- '~['
            { vectorbld_acc (tokens, vector (47, '~[', vector (line, col))); i := i + 2; col := col + 2; }
          else if (ch2 = 47)  -- '~/'
            { vectorbld_acc (tokens, vector (50, '~/', vector (line, col))); i := i + 2; col := col + 2; }
          else
            { vectorbld_acc (tokens, vector (32, '~', vector (line, col))); i := i + 1; col := col + 1; }
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
                { vectorbld_acc (tokens, vector (38, '/~>', vector (line, col))); i := i + 3; col := col + 3; }
              else
                { vectorbld_acc (tokens, vector (48, '/~', vector (line, col))); i := i + 2; col := col + 2; }
            }
          else if (ch2 = 45 and i + 2 < qlen and aref (_q, i + 2) = 62)  -- '/->'
            { vectorbld_acc (tokens, vector (40, '/->', vector (line, col))); i := i + 3; col := col + 3; }
          else if (ch2 = 45)  -- '/-'
            { vectorbld_acc (tokens, vector (49, '/-', vector (line, col))); i := i + 2; col := col + 2; }
          else
            { vectorbld_acc (tokens, vector (21, '/', vector (line, col))); i := i + 1; col := col + 1; }
        }

      -- ':' : DOUBLECOLON or COLON
      else if (ch = 58)
        {
          if (i + 1 < qlen and aref (_q, i + 1) = 58)
            { vectorbld_acc (tokens, vector (30, '::', vector (line, col))); i := i + 2; col := col + 2; }
          else
            { vectorbld_acc (tokens, vector (7, ':', vector (line, col))); i := i + 1; col := col + 1; }
        }

      -- '.' : DOTDOT, leading-dot float, or DOT
      else if (ch = 46)
        {
          if (i + 1 < qlen and aref (_q, i + 1) = 46)
            { vectorbld_acc (tokens, vector (26, '..', vector (line, col))); i := i + 2; col := col + 2; }
          else if (i + 1 < qlen and (aref (_q, i + 1) >= 48 and aref (_q, i + 1) <= 57))
            {
              -- Leading-dot float: .5, .5e10, .5F
              start_line := line; start_col := col;
              val := '.';
              i := i + 1; col := col + 1;
              while (i < qlen and (aref (_q, i) >= 48 and aref (_q, i) <= 57))
                { val := concat (val, chr (aref (_q, i))); i := i + 1; col := col + 1; }
              -- Optional exponent
              if (i < qlen and (aref (_q, i) = 101 or aref (_q, i) = 69))  -- 'e' or 'E'
                {
                  val := concat (val, chr (aref (_q, i))); i := i + 1; col := col + 1;
                  if (i < qlen and (aref (_q, i) = 43 or aref (_q, i) = 45))  -- '+' or '-'
                    { val := concat (val, chr (aref (_q, i))); i := i + 1; col := col + 1; }
                  while (i < qlen and (aref (_q, i) >= 48 and aref (_q, i) <= 57))
                    { val := concat (val, chr (aref (_q, i))); i := i + 1; col := col + 1; }
                }
              -- Optional suffix
              if (i < qlen and (aref (_q, i) = 70 or aref (_q, i) = 68))  -- 'F' or 'D'
                { val := concat (val, chr (aref (_q, i))); i := i + 1; col := col + 1; }
              vectorbld_acc (tokens, vector (67, val, vector (start_line, start_col)));
            }
          else
            { vectorbld_acc (tokens, vector (8, '.', vector (line, col))); i := i + 1; col := col + 1; }
        }

      -- '=' : EQGT(=>) or EQ
      else if (ch = 61)
        {
          if (i + 1 < qlen and aref (_q, i + 1) = 62)
            { vectorbld_acc (tokens, vector (31, '=>', vector (line, col))); i := i + 2; col := col + 2; }
          else
            { vectorbld_acc (tokens, vector (15, '=', vector (line, col))); i := i + 1; col := col + 1; }
        }

      -- '+' : PLUSEQ or PLUS
      else if (ch = 43)
        {
          if (i + 1 < qlen and aref (_q, i + 1) = 61)
            { vectorbld_acc (tokens, vector (27, '+=', vector (line, col))); i := i + 2; col := col + 2; }
          else
            { vectorbld_acc (tokens, vector (19, '+', vector (line, col))); i := i + 1; col := col + 1; }
        }

      -- '!' : NEQ or BANG
      else if (ch = 33)
        {
          if (i + 1 < qlen and aref (_q, i + 1) = 61)
            { vectorbld_acc (tokens, vector (16, '!=', vector (line, col))); i := i + 2; col := col + 2; }
          else
            { vectorbld_acc (tokens, vector (24, '!', vector (line, col))); i := i + 1; col := col + 1; }
        }

      -- ']' : bracket operators
      else if (ch = 93)
        {
          ch2 := 0; if (i + 1 < qlen) ch2 := aref (_q, i + 1);
          ch3 := 0; if (i + 2 < qlen) ch3 := aref (_q, i + 2);
          if (ch2 = 126 and ch3 = 62)  -- ']~>'
            { vectorbld_acc (tokens, vector (45, ']~>', vector (line, col))); i := i + 3; col := col + 3; }
          else if (ch2 = 45 and ch3 = 62)  -- ']->'
            { vectorbld_acc (tokens, vector (44, ']->', vector (line, col))); i := i + 3; col := col + 3; }
          else if (ch2 = 126)  -- ']~'
            { vectorbld_acc (tokens, vector (52, ']~', vector (line, col))); i := i + 2; col := col + 2; }
          else if (ch2 = 45)  -- ']-'
            { vectorbld_acc (tokens, vector (51, ']-', vector (line, col))); i := i + 2; col := col + 2; }
          else
            { vectorbld_acc (tokens, vector (4, ']', vector (line, col))); i := i + 1; col := col + 1; }
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
              -- The value is copied from the query text a run at a time (see
              -- the quoted-string case below); a doubled delimiter ends a run.
              _sv := null;
              _run := i;
              while (i < qlen)
                {
                  ch2 := aref (_q, i);
                  if (ch2 = delim)
                    {
                      if (i + 1 < qlen and aref (_q, i + 1) = delim)
                        {
                          if (_sv is null) _sv := string_output ();
                          http (subseq (_q, _run, i + 1), _sv);
                          i := i + 2; col := col + 2; _run := i;
                        }
                      else
                        {
                          if (_sv is null)
                            raw_val := subseq (_q, _run, i);
                          else
                            {
                              http (subseq (_q, _run, i), _sv);
                              raw_val := string_output_string (_sv);
                            }
                          i := i + 1; col := col + 1; goto noescape_done;
                        }
                    }
                  else
                    {
                      if (ch2 = 10) { line := line + 1; col := 1; }
                      else col := col + 1;
                      i := i + 1;
                    }
                }
              signal ('GQ001', sprintf ('Unterminated NO_ESCAPE string starting at line %d', start_line));
              noescape_done:
              vectorbld_acc (tokens, vector (tok_type, raw_val, vector (start_line, start_col)));
            }
          else
            signal ('GQ001', sprintf ('Unexpected ''@'' at line %d, column %d — GQL does not support language tags; NO_ESCAPE must precede a string literal', line, col));
        }

      -- Simple single-char tokens
      else if (ch = 40) { vectorbld_acc (tokens, vector (1, '(', vector (line, col))); i := i + 1; col := col + 1; }
      else if (ch = 41) { vectorbld_acc (tokens, vector (2, ')', vector (line, col))); i := i + 1; col := col + 1; }
      else if (ch = 91) { vectorbld_acc (tokens, vector (3, '[', vector (line, col))); i := i + 1; col := col + 1; }
      else if (ch = 123) { vectorbld_acc (tokens, vector (5, '{', vector (line, col))); i := i + 1; col := col + 1; }
      else if (ch = 125) { vectorbld_acc (tokens, vector (6, '}', vector (line, col))); i := i + 1; col := col + 1; }
      else if (ch = 44) { vectorbld_acc (tokens, vector (9, ',', vector (line, col))); i := i + 1; col := col + 1; }
      else if (ch = 42) { vectorbld_acc (tokens, vector (20, '*', vector (line, col))); i := i + 1; col := col + 1; }
      else if (ch = 37) { vectorbld_acc (tokens, vector (22, '%', vector (line, col))); i := i + 1; col := col + 1; }
      else if (ch = 94) { vectorbld_acc (tokens, vector (23, '^', vector (line, col))); i := i + 1; col := col + 1; }
      else if (ch = 38) { vectorbld_acc (tokens, vector (29, '&', vector (line, col))); i := i + 1; col := col + 1; }

      -- Parameter prefixes
      else if (ch = 36)  -- '$'
        {
          start_line := line; start_col := col;
          if (i + 1 < qlen and aref (_q, i + 1) = 36)  -- '$$'
            {
              _run := i;
              i := i + 2;
              while (i < qlen)
                {
                  _c := aref (_q, i);
                  if ((_c >= 97 and _c <= 122) or (_c >= 65 and _c <= 90) or (_c >= 48 and _c <= 57) or _c = 95)
                    i := i + 1;
                  else
                    goto param2_scanned;
                }
              param2_scanned:
              val := subseq (_q, _run, i);
              col := col + (i - _run);
              if (length (val) = 2)
                signal ('GQ001', sprintf ('Expected parameter name after ''%s%s'' at line %d, column %d',
                  chr (36), chr (36), start_line, start_col));
              vectorbld_acc (tokens, vector (68, val, vector (start_line, start_col)));
            }
          else if (i + 1 < qlen and DB.DBA.GQL_IS_IDENT_START (aref (_q, i + 1)))
            {
              _run := i;
              i := i + 1;
              while (i < qlen)
                {
                  _c := aref (_q, i);
                  if ((_c >= 97 and _c <= 122) or (_c >= 65 and _c <= 90) or (_c >= 48 and _c <= 57) or _c = 95)
                    i := i + 1;
                  else
                    goto param_scanned;
                }
              param_scanned:
              val := subseq (_q, _run, i);
              col := col + (i - _run);
              vectorbld_acc (tokens, vector (68, val, vector (start_line, start_col)));
            }
          else
            { vectorbld_acc (tokens, vector (28, chr (36), vector (line, col))); i := i + 1; col := col + 1; }
        }
      else if (ch = 63)
        {
          start_line := line; start_col := col;
          if (i + 1 < qlen and DB.DBA.GQL_IS_IDENT_START (aref (_q, i + 1)))
            {
              _run := i;
              i := i + 1;
              while (i < qlen)
                {
                  _c := aref (_q, i);
                  if ((_c >= 97 and _c <= 122) or (_c >= 65 and _c <= 90) or (_c >= 48 and _c <= 57) or _c = 95)
                    i := i + 1;
                  else
                    goto qparam_scanned;
                }
              qparam_scanned:
              val := subseq (_q, _run, i);
              col := col + (i - _run);
              vectorbld_acc (tokens, vector (68, val, vector (start_line, start_col)));
            }
          else
            { vectorbld_acc (tokens, vector (42, chr (63), vector (line, col))); i := i + 1; col := col + 1; }
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
          -- The value is the query text between the delimiters, copied a run
          -- at a time with subseq: a string_output holds it only once an
          -- escape or a doubled delimiter means it is not one contiguous run.
          -- (Appending a character at a time copied the value so far on every
          -- character, which made a long literal quadratic.)
          _sv := null;
          _run := i;

          if (delim = 96)  -- backtick: FIXED logic (openCypher has a bug here)
            {
              while (i < qlen)
                {
                  ch2 := aref (_q, i);
                  if (ch2 = 96)  -- backtick
                    {
                      if (i + 1 < qlen and aref (_q, i + 1) = 96)
                        {
                          if (_sv is null) _sv := string_output ();
                          http (subseq (_q, _run, i + 1), _sv);
                          i := i + 2; col := col + 2; _run := i;
                        }
                      else
                        {
                          if (_sv is null)
                            val := subseq (_q, _run, i);
                          else
                            {
                              http (subseq (_q, _run, i), _sv);
                              val := string_output_string (_sv);
                            }
                          i := i + 1; col := col + 1; goto backtick_done;
                        }
                    }
                  else if (ch2 = 92 and i + 1 < qlen)  -- backslash escape
                    {
                      if (_sv is null) _sv := string_output ();
                      http (subseq (_q, _run, i), _sv);
                      ch3 := aref (_q, i + 1);
                      if (ch3 = 96) { http ('`', _sv); i := i + 2; col := col + 2; }
                      else if (ch3 = 92) { http ('\\', _sv); i := i + 2; col := col + 2; }
                      else if (ch3 = 110) { http (chr(10), _sv); i := i + 2; col := col + 2; }
                      else if (ch3 = 114) { http (chr(13), _sv); i := i + 2; col := col + 2; }
                      else if (ch3 = 116) { http (chr(9), _sv); i := i + 2; col := col + 2; }
                      else if (ch3 = 98) { http (chr(8), _sv); i := i + 2; col := col + 2; }
                      else if (ch3 = 102) { http (chr(12), _sv); i := i + 2; col := col + 2; }
                      else if (ch3 = 117) { http (DB.DBA.GQL_DECODE_UNICODE_ESCAPE (_q, i + 2, start_col, 4), _sv); i := i + 6; col := col + 6; }
                      else if (ch3 = 85) { http (DB.DBA.GQL_DECODE_UNICODE_ESCAPE (_q, i + 2, start_col, 6), _sv); i := i + 8; col := col + 8; }
                      else { http (chr(ch2), _sv); http (chr(ch3), _sv); i := i + 2; col := col + 2; }
                      _run := i;
                    }
                  else
                    {
                      if (ch2 = 10) { line := line + 1; col := 1; }
                      else col := col + 1;
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
                        {
                          if (_sv is null) _sv := string_output ();
                          http (subseq (_q, _run, i + 1), _sv);
                          i := i + 2; col := col + 2; _run := i;
                        }
                      else
                        {
                          if (_sv is null)
                            val := subseq (_q, _run, i);
                          else
                            {
                              http (subseq (_q, _run, i), _sv);
                              val := string_output_string (_sv);
                            }
                          i := i + 1; col := col + 1; goto string_done;
                        }
                    }
                  else if (ch2 = 92 and i + 1 < qlen)  -- backslash escape
                    {
                      if (_sv is null) _sv := string_output ();
                      http (subseq (_q, _run, i), _sv);
                      ch3 := aref (_q, i + 1);
                      if (ch3 = delim) { http (chr (delim), _sv); i := i + 2; col := col + 2; }
                      else if (ch3 = 92) { http ('\\', _sv); i := i + 2; col := col + 2; }
                      else if (ch3 = 110) { http (chr(10), _sv); i := i + 2; col := col + 2; }
                      else if (ch3 = 114) { http (chr(13), _sv); i := i + 2; col := col + 2; }
                      else if (ch3 = 116) { http (chr(9), _sv); i := i + 2; col := col + 2; }
                      else if (ch3 = 98) { http (chr(8), _sv); i := i + 2; col := col + 2; }
                      else if (ch3 = 102) { http (chr(12), _sv); i := i + 2; col := col + 2; }
                      else if (ch3 = 117) { http (DB.DBA.GQL_DECODE_UNICODE_ESCAPE (_q, i + 2, start_col, 4), _sv); i := i + 6; col := col + 6; }
                      else if (ch3 = 85) { http (DB.DBA.GQL_DECODE_UNICODE_ESCAPE (_q, i + 2, start_col, 6), _sv); i := i + 8; col := col + 8; }
                      else { http (chr(ch2), _sv); http (chr(ch3), _sv); i := i + 2; col := col + 2; }
                      _run := i;
                    }
                  else
                    {
                      if (ch2 = 10) { line := line + 1; col := 1; }
                      else col := col + 1;
                      i := i + 1;
                    }
                }
              signal ('GQ001', sprintf ('Unterminated string literal starting at line %d', start_line));
              string_done:;
            }
          vectorbld_acc (tokens, vector (tok_type, val, vector (start_line, start_col)));
        }

      -- Numbers
      else if ((ch >= 48 and ch <= 57))
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
                  vectorbld_acc (tokens, vector (66, val, vector (start_line, start_col)));
                  goto num_done;
                }
              else if (ch2 = 111)  -- '0o' octal
                {
                  val := '0o'; i := i + 2; col := col + 2;
                  while (i < qlen and ((aref (_q, i) >= 48 and aref (_q, i) <= 55) or aref (_q, i) = 95))
                    { if (aref (_q, i) <> 95) val := concat (val, chr (aref (_q, i))); i := i + 1; col := col + 1; }
                  vectorbld_acc (tokens, vector (66, val, vector (start_line, start_col)));
                  goto num_done;
                }
              else if (ch2 = 98)  -- '0b' binary (GQL addition)
                {
                  val := '0b'; i := i + 2; col := col + 2;
                  while (i < qlen and ((aref (_q, i) = 48 or aref (_q, i) = 49) or aref (_q, i) = 95))
                    { if (aref (_q, i) <> 95) val := concat (val, chr (aref (_q, i))); i := i + 1; col := col + 1; }
                  vectorbld_acc (tokens, vector (66, val, vector (start_line, start_col)));
                  goto num_done;
                }
            }

          -- Decimal number (integer or float)
          while (i < qlen and ((aref (_q, i) >= 48 and aref (_q, i) <= 57) or aref (_q, i) = 95))
            { if (aref (_q, i) <> 95) val := concat (val, chr (aref (_q, i))); i := i + 1; col := col + 1; }

          -- Optional dot + more digits (float)
          if (i < qlen and aref (_q, i) = 46 and i + 1 < qlen and (aref (_q, i + 1) >= 48 and aref (_q, i + 1) <= 57))
            {
              is_float := 1;
              val := concat (val, '.'); i := i + 1; col := col + 1;
              while (i < qlen and ((aref (_q, i) >= 48 and aref (_q, i) <= 57) or aref (_q, i) = 95))
                { if (aref (_q, i) <> 95) val := concat (val, chr (aref (_q, i))); i := i + 1; col := col + 1; }
            }

          -- Optional exponent
          if (i < qlen and (aref (_q, i) = 101 or aref (_q, i) = 69))  -- 'e' or 'E'
            {
              is_float := 1;
              val := concat (val, chr (aref (_q, i))); i := i + 1; col := col + 1;
              if (i < qlen and (aref (_q, i) = 43 or aref (_q, i) = 45))
                { val := concat (val, chr (aref (_q, i))); i := i + 1; col := col + 1; }
              while (i < qlen and ((aref (_q, i) >= 48 and aref (_q, i) <= 57) or aref (_q, i) = 95))
                { if (aref (_q, i) <> 95) val := concat (val, chr (aref (_q, i))); i := i + 1; col := col + 1; }
            }

          -- Optional suffix: M (exact), F/D (approximate float)
          if (i < qlen and (aref (_q, i) = 77 or aref (_q, i) = 70 or aref (_q, i) = 68))
            {
              if (aref (_q, i) = 70 or aref (_q, i) = 68)  -- 'F' or 'D'
                is_float := 1;
              val := concat (val, chr (aref (_q, i))); i := i + 1; col := col + 1;
            }

          vectorbld_acc (tokens, vector (case when is_float then 67 else 66 end, val, vector (start_line, start_col)));
          num_done:;
        }

      -- Identifiers, keywords, prefixed names
      else if ((ch >= 65 and ch <= 90) or (ch >= 97 and ch <= 122) or ch = 95)  -- identifier start
        {
          -- The name is scanned with the character classes tested inline (a
          -- PL call per character cost more than the rest of the scan) and
          -- copied once with subseq.
          start_line := line; start_col := col;
          _run := i;
          i := i + 1;
          while (i < qlen)
            {
              _c := aref (_q, i);
              if ((_c >= 97 and _c <= 122) or (_c >= 65 and _c <= 90) or (_c >= 48 and _c <= 57) or _c = 95 or _c = 45)
                i := i + 1;
              else
                goto ident_scanned;
            }
          ident_scanned:
          -- Check for prefixed name: identifier ':' identifier-start
          if (i < qlen and aref (_q, i) = 58 and i + 1 < qlen and DB.DBA.GQL_IS_IDENT_START (aref (_q, i + 1)))
            {
              i := i + 1;
              while (i < qlen)
                {
                  _c := aref (_q, i);
                  if ((_c >= 97 and _c <= 122) or (_c >= 65 and _c <= 90) or (_c >= 48 and _c <= 57) or _c = 95 or _c = 45)
                    i := i + 1;
                  else
                    goto pname_scanned;
                }
              pname_scanned:
              val := subseq (_q, _run, i);
              col := col + (i - _run);
              vectorbld_acc (tokens, vector (69, val, vector (start_line, start_col)));
            }
          else
            {
              val := subseq (_q, _run, i);
              col := col + (i - _run);
              kw := DB.DBA.GQL_KEYWORD (val);
              if (kw <> 0)
                vectorbld_acc (tokens, vector (kw, val, vector (start_line, start_col)));
              else
                vectorbld_acc (tokens, vector (64, val, vector (start_line, start_col)));
            }
        }

      -- Unrecognized character
      else
        signal ('GQ001', sprintf ('Unexpected character ''%s'' (code %d) at line %d, column %d', chr (ch), ch, line, col));

    }

  -- Append EOF token
  vectorbld_acc (tokens, vector (999, '', vector (line, col)));
  vectorbld_final (tokens);
  return tokens;
}
;

/* ANSI-C code produced by gperf version 3.0.1 */
/* Command-line: /usr/bin/gperf -aCDGptr -Kkeiiyword -L ANSI-C -k'1,2,3,6,9,$' -Nlex_hash_kw sqlwords.gperf  */

#if !((' ' == 32) && ('!' == 33) && ('"' == 34) && ('#' == 35) \
      && ('%' == 37) && ('&' == 38) && ('\'' == 39) && ('(' == 40) \
      && (')' == 41) && ('*' == 42) && ('+' == 43) && (',' == 44) \
      && ('-' == 45) && ('.' == 46) && ('/' == 47) && ('0' == 48) \
      && ('1' == 49) && ('2' == 50) && ('3' == 51) && ('4' == 52) \
      && ('5' == 53) && ('6' == 54) && ('7' == 55) && ('8' == 56) \
      && ('9' == 57) && (':' == 58) && (';' == 59) && ('<' == 60) \
      && ('=' == 61) && ('>' == 62) && ('?' == 63) && ('A' == 65) \
      && ('B' == 66) && ('C' == 67) && ('D' == 68) && ('E' == 69) \
      && ('F' == 70) && ('G' == 71) && ('H' == 72) && ('I' == 73) \
      && ('J' == 74) && ('K' == 75) && ('L' == 76) && ('M' == 77) \
      && ('N' == 78) && ('O' == 79) && ('P' == 80) && ('Q' == 81) \
      && ('R' == 82) && ('S' == 83) && ('T' == 84) && ('U' == 85) \
      && ('V' == 86) && ('W' == 87) && ('X' == 88) && ('Y' == 89) \
      && ('Z' == 90) && ('[' == 91) && ('\\' == 92) && (']' == 93) \
      && ('^' == 94) && ('_' == 95) && ('a' == 97) && ('b' == 98) \
      && ('c' == 99) && ('d' == 100) && ('e' == 101) && ('f' == 102) \
      && ('g' == 103) && ('h' == 104) && ('i' == 105) && ('j' == 106) \
      && ('k' == 107) && ('l' == 108) && ('m' == 109) && ('n' == 110) \
      && ('o' == 111) && ('p' == 112) && ('q' == 113) && ('r' == 114) \
      && ('s' == 115) && ('t' == 116) && ('u' == 117) && ('v' == 118) \
      && ('w' == 119) && ('x' == 120) && ('y' == 121) && ('z' == 122) \
      && ('{' == 123) && ('|' == 124) && ('}' == 125) && ('~' == 126))
/* The character set is not based on ISO-646.  */
#error "gperf generated tables don't work with this execution character set. Please report a bug to <bug-gnu-gperf@gnu.org>."
#endif

#line 1 "sqlwords.gperf"
struct keyword { char *keiiyword; int token; };

#define TOTAL_KEYWORDS 281
#define MIN_WORD_LENGTH 1
#define MAX_WORD_LENGTH 17
#define MIN_HASH_VALUE 457
#define MAX_HASH_VALUE 2558
/* maximum key range = 2102, duplicates = 0 */

#ifdef __GNUC__
__inline
#else
#ifdef __cplusplus
inline
#endif
#endif
static unsigned int
hash (register const char *str, register unsigned int len)
{
  static const unsigned short asso_values[] =
    {
      2559, 2559, 2559, 2559, 2559, 2559, 2559, 2559, 2559, 2559,
      2559, 2559, 2559, 2559, 2559, 2559, 2559, 2559, 2559, 2559,
      2559, 2559, 2559, 2559, 2559, 2559, 2559, 2559, 2559, 2559,
      2559, 2559, 2559, 2559, 2559, 2559, 2559, 2559, 2559, 2559,
      2559, 2559, 2559, 2559, 2559, 2559, 2559, 2559, 2559, 2559,
      2559, 2559, 2559, 2559, 2559, 2559, 2559, 2559, 2559, 2559,
      2559, 2559, 2559, 2559, 2559,   49,   68,  308,  288,  426,
       388,  296,  274,  401,  210,   93,  446,  288,  200,  294,
       120,  360,  105,  501,  237,  486,  441,  164,  482,  283,
       401, 2559, 2559, 2559, 2559,  468, 2559, 2559, 2559, 2559,
      2559, 2559, 2559, 2559, 2559, 2559, 2559, 2559, 2559, 2559,
      2559, 2559, 2559, 2559, 2559, 2559, 2559, 2559, 2559, 2559,
      2559, 2559, 2559, 2559, 2559, 2559, 2559, 2559, 2559, 2559,
      2559, 2559, 2559, 2559, 2559, 2559, 2559, 2559, 2559, 2559,
      2559, 2559, 2559, 2559, 2559, 2559, 2559, 2559, 2559, 2559,
      2559, 2559, 2559, 2559, 2559, 2559, 2559, 2559, 2559, 2559,
      2559, 2559, 2559, 2559, 2559, 2559, 2559, 2559, 2559, 2559,
      2559, 2559, 2559, 2559, 2559, 2559, 2559, 2559, 2559, 2559,
      2559, 2559, 2559, 2559, 2559, 2559, 2559, 2559, 2559, 2559,
      2559, 2559, 2559, 2559, 2559, 2559, 2559, 2559, 2559, 2559,
      2559, 2559, 2559, 2559, 2559, 2559, 2559, 2559, 2559, 2559,
      2559, 2559, 2559, 2559, 2559, 2559, 2559, 2559, 2559, 2559,
      2559, 2559, 2559, 2559, 2559, 2559, 2559, 2559, 2559, 2559,
      2559, 2559, 2559, 2559, 2559, 2559, 2559, 2559, 2559, 2559,
      2559, 2559, 2559, 2559, 2559, 2559, 2559, 2559, 2559, 2559,
      2559, 2559, 2559, 2559, 2559, 2559, 2559
    };
  register int hval = len;

  switch (hval)
    {
      default:
        hval += asso_values[(unsigned char)str[8]];
      /*FALLTHROUGH*/
      case 8:
      case 7:
      case 6:
        hval += asso_values[(unsigned char)str[5]];
      /*FALLTHROUGH*/
      case 5:
      case 4:
      case 3:
        hval += asso_values[(unsigned char)str[2]+1];
      /*FALLTHROUGH*/
      case 2:
        hval += asso_values[(unsigned char)str[1]];
      /*FALLTHROUGH*/
      case 1:
        hval += asso_values[(unsigned char)str[0]];
        break;
    }
  return hval + asso_values[(unsigned char)str[len - 1]];
}

static const struct keyword wordlist[] =
  {
#line 15 "sqlwords.gperf"
    {"ADA", ADA},
#line 146 "sqlwords.gperf"
    {"JAVA", JAVA},
#line 182 "sqlwords.gperf"
    {"OR", OR},
#line 40 "sqlwords.gperf"
    {"C", C},
#line 39 "sqlwords.gperf"
    {"BY", BY},
#line 87 "sqlwords.gperf"
    {"DROP", DROP},
#line 118 "sqlwords.gperf"
    {"GROUP", GROUP},
#line 33 "sqlwords.gperf"
    {"BACKUP", BACKUP},
#line 179 "sqlwords.gperf"
    {"ON", ON},
#line 117 "sqlwords.gperf"
    {"GRANT", GRANT},
#line 17 "sqlwords.gperf"
    {"ADMIN", ADMIN_L},
#line 46 "sqlwords.gperf"
    {"CHAR", CHARACTER},
#line 170 "sqlwords.gperf"
    {"NO", NO_L},
#line 126 "sqlwords.gperf"
    {"IN", IN_L},
#line 257 "sqlwords.gperf"
    {"TO", TO},
#line 196 "sqlwords.gperf"
    {"PRIMARY", PRIMARY},
#line 45 "sqlwords.gperf"
    {"CAST", CAST},
#line 221 "sqlwords.gperf"
    {"ROLLBACK", ROLLBACK},
#line 122 "sqlwords.gperf"
    {"HASH", HASH},
#line 74 "sqlwords.gperf"
    {"DATA", DATA},
#line 85 "sqlwords.gperf"
    {"DO", DO},
#line 164 "sqlwords.gperf"
    {"NAME", NAME_L},
#line 115 "sqlwords.gperf"
    {"GO", GO},
#line 202 "sqlwords.gperf"
    {"READ", READ_L},
#line 110 "sqlwords.gperf"
    {"FROM", FROM},
#line 147 "sqlwords.gperf"
    {"JOIN", JOIN},
#line 222 "sqlwords.gperf"
    {"ROLLUP", ROLLUP},
#line 183 "sqlwords.gperf"
    {"ORDER", ORDER},
#line 23 "sqlwords.gperf"
    {"ANY", ANY},
#line 25 "sqlwords.gperf"
    {"ARRAY", ARRAY},
#line 283 "sqlwords.gperf"
    {"XPATH", XPATH},
#line 132 "sqlwords.gperf"
    {"INOUT", INOUT_L},
#line 22 "sqlwords.gperf"
    {"AND", AND},
#line 24 "sqlwords.gperf"
    {"ARE", ARE},
#line 36 "sqlwords.gperf"
    {"BEST", BEST},
#line 35 "sqlwords.gperf"
    {"BEGIN", BEGINX},
#line 158 "sqlwords.gperf"
    {"LOOP", LOOP},
#line 188 "sqlwords.gperf"
    {"PASSWORD", PASSWORD},
#line 131 "sqlwords.gperf"
    {"INNER", INNER},
#line 180 "sqlwords.gperf"
    {"OPEN", OPEN},
#line 258 "sqlwords.gperf"
    {"TOP", TOP},
#line 166 "sqlwords.gperf"
    {"NCHAR", NCHAR},
#line 220 "sqlwords.gperf"
    {"RIGHT", RIGHT},
#line 44 "sqlwords.gperf"
    {"CASE", CASE},
#line 250 "sqlwords.gperf"
    {"TABLE", TABLE},
#line 275 "sqlwords.gperf"
    {"WHEN", WHEN},
#line 18 "sqlwords.gperf"
    {"AFTER", AFTER},
#line 67 "sqlwords.gperf"
    {"CROSS", CROSS},
#line 246 "sqlwords.gperf"
    {"START", START_L},
#line 204 "sqlwords.gperf"
    {"REAL", REAL},
#line 26 "sqlwords.gperf"
    {"AS", AS},
#line 16 "sqlwords.gperf"
    {"ADD", ADD},
#line 281 "sqlwords.gperf"
    {"WORK", WORK},
#line 48 "sqlwords.gperf"
    {"CHECK", CHECK},
#line 260 "sqlwords.gperf"
    {"TRANSACTION", TRANSACTION_L},
#line 176 "sqlwords.gperf"
    {"OF", OF},
#line 278 "sqlwords.gperf"
    {"WHILE", WHILE},
#line 121 "sqlwords.gperf"
    {"HAVING", HAVING},
#line 261 "sqlwords.gperf"
    {"TRIGGER", TRIGGER},
#line 21 "sqlwords.gperf"
    {"ALTER", ALTER},
#line 41 "sqlwords.gperf"
    {"CALL", CALL},
#line 174 "sqlwords.gperf"
    {"NVARCHAR", NVARCHAR},
#line 263 "sqlwords.gperf"
    {"UNION", UNION},
#line 253 "sqlwords.gperf"
    {"THEN", THEN},
#line 203 "sqlwords.gperf"
    {"READS", READS},
#line 223 "sqlwords.gperf"
    {"ROLE", ROLE_L},
#line 195 "sqlwords.gperf"
    {"PREFETCH", PREFETCH},
#line 28 "sqlwords.gperf"
    {"ASSEMBLY", ASSEMBLY_L},
#line 27 "sqlwords.gperf"
    {"ASC", ASC},
#line 272 "sqlwords.gperf"
    {"VARCHAR", VARCHAR},
#line 120 "sqlwords.gperf"
    {"HANDLER", HANDLER},
#line 47 "sqlwords.gperf"
    {"CHARACTER", CHARACTER},
#line 125 "sqlwords.gperf"
    {"IF", IF},
#line 192 "sqlwords.gperf"
    {"PLI", PLI},
#line 136 "sqlwords.gperf"
    {"INSTEAD", INSTEAD},
#line 252 "sqlwords.gperf"
    {"TEXT", TEXT_L},
#line 104 "sqlwords.gperf"
    {"FLOAT", FLOAT_L},
#line 133 "sqlwords.gperf"
    {"INPUT", INPUT},
#line 148 "sqlwords.gperf"
    {"KEY", KEY},
#line 269 "sqlwords.gperf"
    {"VALUE", VALUE},
#line 205 "sqlwords.gperf"
    {"REF", REF},
#line 169 "sqlwords.gperf"
    {"NOT", NOT},
#line 262 "sqlwords.gperf"
    {"UNDER", UNDER},
#line 119 "sqlwords.gperf"
    {"GROUPING", GROUPING},
#line 42 "sqlwords.gperf"
    {"CALLED", CALLED},
#line 20 "sqlwords.gperf"
    {"ALL", ALL},
#line 165 "sqlwords.gperf"
    {"NATURAL", NATURAL},
#line 88 "sqlwords.gperf"
    {"DTD", DTD},
#line 64 "sqlwords.gperf"
    {"CONVERT", CONVERT},
#line 215 "sqlwords.gperf"
    {"RESULT", RESULT},
#line 75 "sqlwords.gperf"
    {"DATE", DATE_L},
#line 277 "sqlwords.gperf"
    {"WHERE", WHERE},
#line 193 "sqlwords.gperf"
    {"POSITION", POSITION_L},
#line 81 "sqlwords.gperf"
    {"DESC", DESC},
#line 255 "sqlwords.gperf"
    {"TIME", TIME},
#line 150 "sqlwords.gperf"
    {"LANGUAGE", LANGUAGE},
#line 167 "sqlwords.gperf"
    {"NEW", NEW},
#line 224 "sqlwords.gperf"
    {"SAFE", SAFE_L},
#line 175 "sqlwords.gperf"
    {"OBJECT_ID", OBJECT_ID},
#line 58 "sqlwords.gperf"
    {"COMMIT", COMMIT},
#line 234 "sqlwords.gperf"
    {"SNAPSHOT", SNAPSHOT},
#line 105 "sqlwords.gperf"
    {"FOR", FOR},
#line 130 "sqlwords.gperf"
    {"INDICATOR", INDICATOR},
#line 57 "sqlwords.gperf"
    {"COLUMN", COLUMN},
#line 145 "sqlwords.gperf"
    {"IRI_ID", IRI_ID},
#line 187 "sqlwords.gperf"
    {"PASCAL", PASCAL_L},
#line 51 "sqlwords.gperf"
    {"CLOSE", CLOSE},
#line 181 "sqlwords.gperf"
    {"OPTION", OPTION},
#line 259 "sqlwords.gperf"
    {"TYPE", TYPE},
#line 156 "sqlwords.gperf"
    {"LOG", LOGX},
#line 227 "sqlwords.gperf"
    {"SCHEMA", SCHEMA},
#line 43 "sqlwords.gperf"
    {"CASCADE", CASCADE},
#line 134 "sqlwords.gperf"
    {"INSERT", INSERT},
#line 256 "sqlwords.gperf"
    {"TIMESTAMP", TIMESTAMP},
#line 29 "sqlwords.gperf"
    {"ATTACH", ATTACH},
#line 137 "sqlwords.gperf"
    {"INT", INTEGER},
#line 279 "sqlwords.gperf"
    {"WITH", WITH},
#line 235 "sqlwords.gperf"
    {"SOFT", SOFT},
#line 157 "sqlwords.gperf"
    {"LONG", LONG_L},
#line 38 "sqlwords.gperf"
    {"BINARY", BINARY},
#line 93 "sqlwords.gperf"
    {"END", ENDX},
#line 61 "sqlwords.gperf"
    {"CONSTRUCTOR", CONSTRUCTOR},
#line 101 "sqlwords.gperf"
    {"EXIT", EXIT},
#line 55 "sqlwords.gperf"
    {"COBOL", COBOL},
#line 53 "sqlwords.gperf"
    {"CLR", CLR},
#line 177 "sqlwords.gperf"
    {"OFF", OFF},
#line 84 "sqlwords.gperf"
    {"DISTINCT", DISTINCT},
#line 116 "sqlwords.gperf"
    {"GOTO", GOTO},
#line 185 "sqlwords.gperf"
    {"OUTER", OUTER},
#line 276 "sqlwords.gperf"
    {"WHENEVER", WHENEVER},
#line 142 "sqlwords.gperf"
    {"INTO", INTO},
#line 31 "sqlwords.gperf"
    {"AUTHORIZATION", AUTHORIZATION},
#line 248 "sqlwords.gperf"
    {"SYNC", SYNC},
#line 274 "sqlwords.gperf"
    {"VIEW", VIEW},
#line 149 "sqlwords.gperf"
    {"KEYSET", KEYSET},
#line 143 "sqlwords.gperf"
    {"IS", IS},
#line 151 "sqlwords.gperf"
    {"LEFT", LEFT},
#line 214 "sqlwords.gperf"
    {"RESTRICT", RESTRICT},
#line 109 "sqlwords.gperf"
    {"FOUND", FOUND},
#line 213 "sqlwords.gperf"
    {"RESIGNAL", RESIGNAL},
#line 216 "sqlwords.gperf"
    {"RETURN", RETURN},
#line 171 "sqlwords.gperf"
    {"NULL", NULLX},
#line 236 "sqlwords.gperf"
    {"SOME", SOME},
#line 245 "sqlwords.gperf"
    {"STATIC", STATIC_L},
#line 155 "sqlwords.gperf"
    {"LOCATOR", LOCATOR},
#line 108 "sqlwords.gperf"
    {"FORTRAN", FORTRAN},
#line 60 "sqlwords.gperf"
    {"CONSTRAINT", CONSTRAINT},
#line 178 "sqlwords.gperf"
    {"OLD", OLD},
#line 135 "sqlwords.gperf"
    {"INSTANCE", INSTANCE_L},
#line 163 "sqlwords.gperf"
    {"MUMPS", MUMPS},
#line 267 "sqlwords.gperf"
    {"USER", USER},
#line 152 "sqlwords.gperf"
    {"LEVEL", LEVEL_L},
#line 189 "sqlwords.gperf"
    {"PERCENT", PERCENT},
#line 273 "sqlwords.gperf"
    {"VARIABLE", VARIABLE},
#line 198 "sqlwords.gperf"
    {"PROCEDURE", PROCEDURE},
#line 268 "sqlwords.gperf"
    {"USING", USING},
#line 233 "sqlwords.gperf"
    {"SMALLINT", SMALLINT},
#line 77 "sqlwords.gperf"
    {"DECIMAL", DECIMAL_L},
#line 184 "sqlwords.gperf"
    {"OUT", OUT_L},
#line 282 "sqlwords.gperf"
    {"XML", XML},
#line 73 "sqlwords.gperf"
    {"CURSOR", CURSOR},
#line 129 "sqlwords.gperf"
    {"INDEX", INDEX},
#line 113 "sqlwords.gperf"
    {"GENERAL", GENERAL},
#line 194 "sqlwords.gperf"
    {"PRECISION", PRECISION},
#line 63 "sqlwords.gperf"
    {"CONTINUE", CONTINUE},
#line 254 "sqlwords.gperf"
    {"TIES", TIES},
#line 68 "sqlwords.gperf"
    {"CUBE", CUBE},
#line 103 "sqlwords.gperf"
    {"FINAL", FINAL_L},
#line 199 "sqlwords.gperf"
    {"PUBLIC", PUBLIC},
#line 50 "sqlwords.gperf"
    {"CHECKPOINT", CHECKPOINT},
#line 200 "sqlwords.gperf"
    {"PURGE", PURGE},
#line 90 "sqlwords.gperf"
    {"ELSE", ELSE},
#line 78 "sqlwords.gperf"
    {"DECLARE", DECLARE},
#line 251 "sqlwords.gperf"
    {"TEMPORARY", TEMPORARY},
#line 153 "sqlwords.gperf"
    {"LIBRARY", LIBRARY_L},
#line 218 "sqlwords.gperf"
    {"REVOKE", REVOKE},
#line 56 "sqlwords.gperf"
    {"COLLATE", COLLATE},
#line 247 "sqlwords.gperf"
    {"STYLE", STYLE},
#line 102 "sqlwords.gperf"
    {"FETCH", FETCH},
#line 160 "sqlwords.gperf"
    {"MODIFY", MODIFY},
#line 89 "sqlwords.gperf"
    {"DYNAMIC", DYNAMIC},
#line 238 "sqlwords.gperf"
    {"SPARQL", SPARQL_L},
#line 208 "sqlwords.gperf"
    {"REMOTE", REMOTE},
#line 11 "sqlwords.gperf"
    {"__SOAP_FAULT", __SOAP_FAULT},
#line 240 "sqlwords.gperf"
    {"SQL", SQL_L},
#line 173 "sqlwords.gperf"
    {"NUMERIC", NUMERIC},
#line 249 "sqlwords.gperf"
    {"SYSTEM", SYSTEM},
#line 54 "sqlwords.gperf"
    {"COALESCE", COALESCE},
#line 229 "sqlwords.gperf"
    {"SELF", SELF_L},
#line 111 "sqlwords.gperf"
    {"FULL", FULL},
#line 37 "sqlwords.gperf"
    {"BETWEEN", BETWEEN},
#line 92 "sqlwords.gperf"
    {"ENCODING", ENCODING},
#line 59 "sqlwords.gperf"
    {"COMMITTED", COMMITTED_L},
#line 138 "sqlwords.gperf"
    {"INTEGER", INTEGER},
#line 243 "sqlwords.gperf"
    {"SQLSTATE", SQLSTATE},
#line 34 "sqlwords.gperf"
    {"BEFORE", BEFORE},
#line 114 "sqlwords.gperf"
    {"GENERATED", GENERATED},
#line 231 "sqlwords.gperf"
    {"SET", SET},
#line 76 "sqlwords.gperf"
    {"DATETIME", DATETIME},
#line 66 "sqlwords.gperf"
    {"CREATE", CREATE},
#line 128 "sqlwords.gperf"
    {"INCREMENT", INCREMENT_L},
#line 7 "sqlwords.gperf"
    {"__SOAP_HTTP", __SOAP_HTTP},
#line 144 "sqlwords.gperf"
    {"ISOLATION", ISOLATION_L},
#line 95 "sqlwords.gperf"
    {"EXCEPT", EXCEPT},
#line 83 "sqlwords.gperf"
    {"DISCONNECT", DISCONNECT},
#line 209 "sqlwords.gperf"
    {"RENAME", RENAME},
#line 107 "sqlwords.gperf"
    {"FOREIGN", FOREIGN},
#line 49 "sqlwords.gperf"
    {"CHECKED", CHECKED},
#line 228 "sqlwords.gperf"
    {"SELECT", SELECT},
#line 79 "sqlwords.gperf"
    {"DEFAULT", DEFAULT},
#line 30 "sqlwords.gperf"
    {"ATTRIBUTE", ATTRIBUTE},
#line 3 "sqlwords.gperf"
    {"__COST", __COST},
#line 239 "sqlwords.gperf"
    {"SPECIFIC", SPECIFIC},
#line 232 "sqlwords.gperf"
    {"SHUTDOWN", SHUTDOWN},
#line 154 "sqlwords.gperf"
    {"LIKE", LIKE},
#line 217 "sqlwords.gperf"
    {"RETURNS", RETURNS},
#line 219 "sqlwords.gperf"
    {"REXECUTE", REXECUTE},
#line 69 "sqlwords.gperf"
    {"CURRENT", CURRENT},
#line 140 "sqlwords.gperf"
    {"INTERNAL", INTERNAL},
#line 264 "sqlwords.gperf"
    {"UNIQUE", UNIQUE},
#line 172 "sqlwords.gperf"
    {"NULLIF", NULLIF},
#line 244 "sqlwords.gperf"
    {"SQLWARNING", SQLWARNING},
#line 5 "sqlwords.gperf"
    {"__SOAP_DOCW", __SOAP_DOCW},
#line 271 "sqlwords.gperf"
    {"VARBINARY", VARBINARY},
#line 123 "sqlwords.gperf"
    {"IDENTITY", IDENTITY},
#line 106 "sqlwords.gperf"
    {"FOREACH", FOREACH},
#line 19 "sqlwords.gperf"
    {"AGGREGATE", AGGREGATE},
#line 112 "sqlwords.gperf"
    {"FUNCTION", FUNCTION},
#line 8 "sqlwords.gperf"
    {"__SOAP_NAME", __SOAP_NAME},
#line 280 "sqlwords.gperf"
    {"WITHOUT", WITHOUT_L},
#line 159 "sqlwords.gperf"
    {"METHOD", METHOD},
#line 270 "sqlwords.gperf"
    {"VALUES", VALUES},
#line 225 "sqlwords.gperf"
    {"UNCOMMITTED", UNCOMMITTED_L},
#line 211 "sqlwords.gperf"
    {"REPLACING", REPLACING},
#line 266 "sqlwords.gperf"
    {"USE", USE},
#line 62 "sqlwords.gperf"
    {"CONTAINS", CONTAINS},
#line 212 "sqlwords.gperf"
    {"REPLICATION", REPLICATION},
#line 197 "sqlwords.gperf"
    {"PRIVILEGES", PRIVILEGES},
#line 6 "sqlwords.gperf"
    {"__SOAP_HEADER", __SOAP_HEADER},
#line 168 "sqlwords.gperf"
    {"NONINCREMENTAL", NONINCREMENTAL},
#line 201 "sqlwords.gperf"
    {"QUIETCAST", QUIETCAST_L},
#line 80 "sqlwords.gperf"
    {"DELETE", DELETE_L},
#line 162 "sqlwords.gperf"
    {"MODULE", MODULE},
#line 72 "sqlwords.gperf"
    {"CURRENT_TIMESTAMP", CURRENT_TIMESTAMP},
#line 241 "sqlwords.gperf"
    {"SQLCODE", SQLCODE},
#line 127 "sqlwords.gperf"
    {"INCREMENTAL", INCREMENTAL},
#line 86 "sqlwords.gperf"
    {"DOUBLE", DOUBLE_L},
#line 265 "sqlwords.gperf"
    {"UPDATE", UPDATE},
#line 91 "sqlwords.gperf"
    {"ELSEIF", ELSEIF},
#line 4 "sqlwords.gperf"
    {"__SOAP_DOC", __SOAP_DOC},
#line 242 "sqlwords.gperf"
    {"SQLEXCEPTION", SQLEXCEPTION},
#line 161 "sqlwords.gperf"
    {"MODIFIES", MODIFIES},
#line 14 "sqlwords.gperf"
    {"__SOAP_OPTIONS", __SOAP_OPTIONS},
#line 13 "sqlwords.gperf"
    {"__SOAP_ENC_MIME", __SOAP_ENC_MIME},
#line 100 "sqlwords.gperf"
    {"EXTRACT", EXTRACT},
#line 207 "sqlwords.gperf"
    {"REFERENCING", REFERENCING},
#line 97 "sqlwords.gperf"
    {"EXECUTE", EXECUTE},
#line 141 "sqlwords.gperf"
    {"INTERVAL", INTERVAL},
#line 191 "sqlwords.gperf"
    {"PERSISTENT", PERSISTENT},
#line 210 "sqlwords.gperf"
    {"REPEATABLE", REPEATABLE_L},
#line 9 "sqlwords.gperf"
    {"__SOAP_TYPE", __SOAP_TYPE},
#line 12 "sqlwords.gperf"
    {"__SOAP_DIME_ENC", __SOAP_DIME_ENC},
#line 10 "sqlwords.gperf"
    {"__SOAP_XML_TYPE", __SOAP_XML_TYPE},
#line 186 "sqlwords.gperf"
    {"OVERRIDING", OVERRIDING},
#line 226 "sqlwords.gperf"
    {"UNRESTRICTED", UNRESTRICTED_L},
#line 99 "sqlwords.gperf"
    {"EXTERNAL", EXTERNAL},
#line 32 "sqlwords.gperf"
    {"AUTOREGISTER", AUTOREGISTER_L},
#line 139 "sqlwords.gperf"
    {"INTERSECT", INTERSECT},
#line 94 "sqlwords.gperf"
    {"ESCAPE", ESCAPE},
#line 190 "sqlwords.gperf"
    {"PERMISSION_SET", PERMISSION_SET},
#line 237 "sqlwords.gperf"
    {"SOURCE", SOURCE},
#line 65 "sqlwords.gperf"
    {"CORRESPONDING", CORRESPONDING},
#line 98 "sqlwords.gperf"
    {"EXISTS", EXISTS},
#line 71 "sqlwords.gperf"
    {"CURRENT_TIME", CURRENT_TIME},
#line 206 "sqlwords.gperf"
    {"REFERENCES", REFERENCES},
#line 124 "sqlwords.gperf"
    {"IDENTIFIED", IDENTIFIED},
#line 52 "sqlwords.gperf"
    {"CLUSTERED", CLUSTERED},
#line 82 "sqlwords.gperf"
    {"DETERMINISTIC", DETERMINISTIC},
#line 70 "sqlwords.gperf"
    {"CURRENT_DATE", CURRENT_DATE},
#line 230 "sqlwords.gperf"
    {"SERIALIZABLE", SERIALIZABLE_L},
#line 96 "sqlwords.gperf"
    {"EXCLUSIVE", EXCLUSIVE}
  };

static const short lookup[] =
  {
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,   0,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,   1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,   2,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,   3,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,   4,   5,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,   6,  -1,  -1,  -1,
     -1,   7,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,   8,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,   9,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  10,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  11,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     12,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  13,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  14,  -1,  -1,
     15,  -1,  -1,  -1,  -1,  16,  -1,  17,  18,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  19,  -1,  20,  21,
     -1,  -1,  -1,  -1,  -1,  -1,  22,  -1,  -1,  -1,
     -1,  23,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  24,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  25,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  26,  -1,  27,  28,  -1,  -1,  -1,
     -1,  -1,  -1,  29,  -1,  -1,  -1,  -1,  -1,  30,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  31,  -1,  -1,  32,  -1,  -1,  -1,
     -1,  33,  34,  35,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  36,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  37,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  38,  39,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  40,  -1,  -1,  -1,  -1,  41,
     -1,  -1,  42,  -1,  43,  44,  -1,  -1,  -1,  -1,
     45,  -1,  -1,  46,  -1,  -1,  -1,  -1,  -1,  47,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  48,  49,
     -1,  -1,  -1,  50,  51,  -1,  52,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  53,  -1,
     -1,  54,  55,  -1,  -1,  -1,  -1,  -1,  -1,  56,
     -1,  -1,  -1,  -1,  -1,  57,  -1,  -1,  -1,  -1,
     58,  59,  -1,  -1,  -1,  60,  61,  -1,  -1,  -1,
     -1,  62,  -1,  63,  -1,  64,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  65,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  66,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  67,  -1,  -1,  68,
     -1,  -1,  69,  -1,  -1,  70,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  71,  -1,  72,
     73,  -1,  74,  -1,  -1,  -1,  -1,  75,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  76,  -1,  -1,  -1,
     -1,  -1,  -1,  77,  -1,  -1,  78,  -1,  -1,  79,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  80,  -1,
     81,  -1,  82,  -1,  -1,  -1,  83,  84,  -1,  -1,
     -1,  -1,  85,  -1,  -1,  -1,  -1,  86,  -1,  -1,
     -1,  -1,  87,  -1,  -1,  88,  -1,  -1,  89,  -1,
     -1,  -1,  -1,  90,  -1,  -1,  -1,  91,  -1,  -1,
     92,  -1,  -1,  93,  -1,  -1,  -1,  -1,  94,  -1,
     -1,  -1,  95,  -1,  -1,  96,  97,  98,  -1,  -1,
     -1,  -1,  99,  -1,  -1,  -1,  -1,  -1, 100,  -1,
     -1, 101,  -1,  -1,  -1, 102, 103,  -1, 104,  -1,
     -1,  -1,  -1,  -1, 105, 106, 107,  -1,  -1,  -1,
    108,  -1,  -1, 109, 110, 111,  -1,  -1, 112,  -1,
     -1,  -1,  -1,  -1, 113,  -1, 114, 115,  -1, 116,
     -1,  -1, 117,  -1, 118, 119,  -1,  -1,  -1,  -1,
     -1,  -1,  -1, 120,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1, 121,  -1,  -1,  -1,  -1, 122,
     -1, 123,  -1, 124,  -1,  -1,  -1,  -1,  -1, 125,
     -1, 126,  -1,  -1, 127,  -1, 128,  -1,  -1,  -1,
    129,  -1,  -1,  -1,  -1, 130,  -1,  -1, 131,  -1,
    132,  -1,  -1,  -1,  -1,  -1,  -1,  -1, 133,  -1,
    134,  -1,  -1,  -1,  -1, 135,  -1,  -1,  -1, 136,
     -1,  -1,  -1,  -1, 137,  -1, 138,  -1,  -1,  -1,
     -1,  -1, 139, 140, 141, 142,  -1,  -1, 143,  -1,
     -1,  -1,  -1,  -1, 144,  -1,  -1,  -1,  -1, 145,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1, 146,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1, 147,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1, 148,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
    149,  -1,  -1,  -1, 150,  -1,  -1, 151,  -1,  -1,
     -1, 152,  -1, 153, 154,  -1,  -1,  -1, 155,  -1,
     -1,  -1,  -1, 156, 157,  -1, 158, 159,  -1,  -1,
     -1, 160,  -1,  -1, 161,  -1,  -1,  -1, 162,  -1,
     -1,  -1,  -1, 163,  -1,  -1,  -1,  -1,  -1,  -1,
    164, 165, 166,  -1, 167,  -1, 168, 169, 170, 171,
    172,  -1,  -1, 173,  -1,  -1,  -1,  -1,  -1,  -1,
    174,  -1,  -1, 175,  -1,  -1,  -1,  -1,  -1,  -1,
    176,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
    177,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1, 178,
    179, 180,  -1,  -1,  -1,  -1,  -1, 181,  -1, 182,
     -1, 183,  -1,  -1,  -1,  -1,  -1,  -1, 184,  -1,
     -1,  -1, 185, 186,  -1, 187,  -1, 188,  -1,  -1,
     -1,  -1, 189, 190,  -1,  -1,  -1,  -1,  -1, 191,
     -1,  -1,  -1,  -1, 192, 193,  -1,  -1,  -1,  -1,
     -1,  -1, 194,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1, 195,  -1,
    196,  -1,  -1, 197,  -1,  -1,  -1,  -1, 198, 199,
    200, 201,  -1,  -1,  -1,  -1,  -1,  -1, 202,  -1,
     -1,  -1,  -1,  -1,  -1,  -1, 203,  -1,  -1,  -1,
     -1, 204,  -1, 205,  -1,  -1, 206,  -1,  -1,  -1,
     -1, 207,  -1,  -1,  -1, 208,  -1,  -1,  -1,  -1,
    209, 210,  -1,  -1, 211,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1, 212,  -1,  -1,  -1,  -1, 213,  -1,
     -1,  -1,  -1, 214,  -1, 215,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1, 216,  -1,  -1,  -1,  -1, 217,
     -1, 218,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1, 219,  -1, 220,  -1,  -1,  -1,
    221,  -1, 222,  -1,  -1,  -1, 223,  -1,  -1, 224,
     -1,  -1, 225,  -1,  -1,  -1, 226, 227,  -1, 228,
     -1, 229, 230,  -1,  -1,  -1, 231,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1, 232,  -1,
    233,  -1,  -1,  -1, 234,  -1, 235,  -1,  -1,  -1,
     -1, 236,  -1,  -1,  -1,  -1,  -1,  -1, 237,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1, 238,  -1,  -1,
     -1,  -1,  -1,  -1, 239,  -1,  -1, 240,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
    241,  -1,  -1,  -1,  -1,  -1, 242,  -1,  -1, 243,
    244, 245,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1, 246,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
    247, 248,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1, 249, 250,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1, 251,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1, 252,  -1,
     -1,  -1,  -1,  -1, 253,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1, 254,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1, 255,  -1,  -1,  -1,  -1, 256,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1, 257,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1, 258,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
    259,  -1,  -1, 260,  -1,  -1,  -1, 261,  -1,  -1,
     -1,  -1, 262,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
    263,  -1, 264,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1, 265,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1, 266,  -1,  -1,  -1,  -1,
     -1, 267,  -1, 268,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1, 269, 270,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1, 271,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1, 272,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
    273,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
    274,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1, 275,  -1,  -1,  -1, 276,  -1,  -1,  -1,
    277,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1, 278,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1, 279,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1, 280
  };

#ifdef __GNUC__
__inline
#endif
const struct keyword *
lex_hash_kw (register const char *str, register unsigned int len)
{
  if (len <= MAX_WORD_LENGTH && len >= MIN_WORD_LENGTH)
    {
      register int key = hash (str, len);

      if (key <= MAX_HASH_VALUE && key >= 0)
        {
          register int index = lookup[key];

          if (index >= 0)
            {
              register const char *s = wordlist[index].keiiyword;

              if (*str == *s && !strcmp (str + 1, s + 1))
                return &wordlist[index];
            }
        }
    }
  return 0;
}

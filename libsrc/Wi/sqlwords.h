/* ANSI-C code produced by gperf version 3.0.1 */
/* Command-line: gperf -aCDGptr -Kkeiiyword -L ANSI-C -k'1,2,3,6,9,$' -Nlex_hash_kw sqlwords.gperf  */

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

#define TOTAL_KEYWORDS 280
#define MIN_WORD_LENGTH 1
#define MAX_WORD_LENGTH 17
#define MIN_HASH_VALUE 106
#define MAX_HASH_VALUE 2025
/* maximum key range = 1920, duplicates = 0 */

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
      2026, 2026, 2026, 2026, 2026, 2026, 2026, 2026, 2026, 2026,
      2026, 2026, 2026, 2026, 2026, 2026, 2026, 2026, 2026, 2026,
      2026, 2026, 2026, 2026, 2026, 2026, 2026, 2026, 2026, 2026,
      2026, 2026, 2026, 2026, 2026, 2026, 2026, 2026, 2026, 2026,
      2026, 2026, 2026, 2026, 2026, 2026, 2026, 2026, 2026, 2026,
      2026, 2026, 2026, 2026, 2026, 2026, 2026, 2026, 2026, 2026,
      2026, 2026, 2026, 2026, 2026,  164,  133,  266,  375,    9,
       397,  321,  387,  110,  498,  141,  507,  243,  119,  254,
        23,  337,  280,  419,  204,   50,  422,  123,  425,  446,
        57, 2026, 2026, 2026, 2026,  279, 2026, 2026, 2026, 2026,
      2026, 2026, 2026, 2026, 2026, 2026, 2026, 2026, 2026, 2026,
      2026, 2026, 2026, 2026, 2026, 2026, 2026, 2026, 2026, 2026,
      2026, 2026, 2026, 2026, 2026, 2026, 2026, 2026, 2026, 2026,
      2026, 2026, 2026, 2026, 2026, 2026, 2026, 2026, 2026, 2026,
      2026, 2026, 2026, 2026, 2026, 2026, 2026, 2026, 2026, 2026,
      2026, 2026, 2026, 2026, 2026, 2026, 2026, 2026, 2026, 2026,
      2026, 2026, 2026, 2026, 2026, 2026, 2026, 2026, 2026, 2026,
      2026, 2026, 2026, 2026, 2026, 2026, 2026, 2026, 2026, 2026,
      2026, 2026, 2026, 2026, 2026, 2026, 2026, 2026, 2026, 2026,
      2026, 2026, 2026, 2026, 2026, 2026, 2026, 2026, 2026, 2026,
      2026, 2026, 2026, 2026, 2026, 2026, 2026, 2026, 2026, 2026,
      2026, 2026, 2026, 2026, 2026, 2026, 2026, 2026, 2026, 2026,
      2026, 2026, 2026, 2026, 2026, 2026, 2026, 2026, 2026, 2026,
      2026, 2026, 2026, 2026, 2026, 2026, 2026, 2026, 2026, 2026,
      2026, 2026, 2026, 2026, 2026, 2026, 2026, 2026, 2026, 2026,
      2026, 2026, 2026, 2026, 2026, 2026, 2026
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
#line 264 "sqlwords.gperf"
    {"UPDATE", UPDATE},
#line 36 "sqlwords.gperf"
    {"BETWEEN", BETWEEN},
#line 125 "sqlwords.gperf"
    {"IN", IN_L},
#line 163 "sqlwords.gperf"
    {"NAME", NAME_L},
#line 207 "sqlwords.gperf"
    {"REMOTE", REMOTE},
#line 217 "sqlwords.gperf"
    {"REVOKE", REVOKE},
#line 254 "sqlwords.gperf"
    {"TIME", TIME},
#line 131 "sqlwords.gperf"
    {"INOUT", INOUT_L},
#line 261 "sqlwords.gperf"
    {"UNDER", UNDER},
#line 136 "sqlwords.gperf"
    {"INT", INTEGER},
#line 33 "sqlwords.gperf"
    {"BEFORE", BEFORE},
#line 178 "sqlwords.gperf"
    {"ON", ON},
#line 199 "sqlwords.gperf"
    {"PURGE", PURGE},
#line 92 "sqlwords.gperf"
    {"END", ENDX},
#line 161 "sqlwords.gperf"
    {"MODULE", MODULE},
#line 39 "sqlwords.gperf"
    {"C", C},
#line 141 "sqlwords.gperf"
    {"INTO", INTO},
#line 279 "sqlwords.gperf"
    {"WITHOUT", WITHOUT_L},
#line 35 "sqlwords.gperf"
    {"BEST", BEST},
#line 183 "sqlwords.gperf"
    {"OUT", OUT_L},
#line 208 "sqlwords.gperf"
    {"RENAME", RENAME},
#line 134 "sqlwords.gperf"
    {"INSTANCE", INSTANCE_L},
#line 180 "sqlwords.gperf"
    {"OPTION", OPTION},
#line 137 "sqlwords.gperf"
    {"INTEGER", INTEGER},
#line 29 "sqlwords.gperf"
    {"ATTRIBUTE", ATTRIBUTE},
#line 215 "sqlwords.gperf"
    {"RETURN", RETURN},
#line 67 "sqlwords.gperf"
    {"CUBE", CUBE},
#line 74 "sqlwords.gperf"
    {"DATE", DATE_L},
#line 148 "sqlwords.gperf"
    {"KEYSET", KEYSET},
#line 169 "sqlwords.gperf"
    {"NO", NO_L},
#line 168 "sqlwords.gperf"
    {"NOT", NOT},
#line 184 "sqlwords.gperf"
    {"OUTER", OUTER},
#line 43 "sqlwords.gperf"
    {"CASE", CASE},
#line 249 "sqlwords.gperf"
    {"TABLE", TABLE},
#line 79 "sqlwords.gperf"
    {"DELETE", DELETE_L},
#line 117 "sqlwords.gperf"
    {"GROUP", GROUP},
#line 34 "sqlwords.gperf"
    {"BEGIN", BEGINX},
#line 147 "sqlwords.gperf"
    {"KEY", KEY},
#line 128 "sqlwords.gperf"
    {"INDEX", INDEX},
#line 21 "sqlwords.gperf"
    {"AND", AND},
#line 172 "sqlwords.gperf"
    {"NUMERIC", NUMERIC},
#line 278 "sqlwords.gperf"
    {"WITH", WITH},
#line 166 "sqlwords.gperf"
    {"NEW", NEW},
#line 230 "sqlwords.gperf"
    {"SET", SET},
#line 263 "sqlwords.gperf"
    {"UNIQUE", UNIQUE},
#line 255 "sqlwords.gperf"
    {"TIMESTAMP", TIMESTAMP},
#line 246 "sqlwords.gperf"
    {"STYLE", STYLE},
#line 86 "sqlwords.gperf"
    {"DROP", DROP},
#line 256 "sqlwords.gperf"
    {"TO", TO},
#line 75 "sqlwords.gperf"
    {"DATETIME", DATETIME},
#line 192 "sqlwords.gperf"
    {"POSITION", POSITION_L},
#line 32 "sqlwords.gperf"
    {"BACKUP", BACKUP},
#line 197 "sqlwords.gperf"
    {"PROCEDURE", PROCEDURE},
#line 89 "sqlwords.gperf"
    {"ELSE", ELSE},
#line 73 "sqlwords.gperf"
    {"DATA", DATA},
#line 130 "sqlwords.gperf"
    {"INNER", INNER},
#line 132 "sqlwords.gperf"
    {"INPUT", INPUT},
#line 165 "sqlwords.gperf"
    {"NCHAR", NCHAR},
#line 188 "sqlwords.gperf"
    {"PERCENT", PERCENT},
#line 16 "sqlwords.gperf"
    {"ADMIN", ADMIN_L},
#line 22 "sqlwords.gperf"
    {"ANY", ANY},
#line 222 "sqlwords.gperf"
    {"ROLE", ROLE_L},
#line 262 "sqlwords.gperf"
    {"UNION", UNION},
#line 179 "sqlwords.gperf"
    {"OPEN", OPEN},
#line 201 "sqlwords.gperf"
    {"READ", READ_L},
#line 218 "sqlwords.gperf"
    {"REXECUTE", REXECUTE},
#line 235 "sqlwords.gperf"
    {"SOME", SOME},
#line 50 "sqlwords.gperf"
    {"CLOSE", CLOSE},
#line 157 "sqlwords.gperf"
    {"LOOP", LOOP},
#line 213 "sqlwords.gperf"
    {"RESTRICT", RESTRICT},
#line 181 "sqlwords.gperf"
    {"OR", OR},
#line 257 "sqlwords.gperf"
    {"TOP", TOP},
#line 93 "sqlwords.gperf"
    {"ESCAPE", ESCAPE},
#line 182 "sqlwords.gperf"
    {"ORDER", ORDER},
#line 221 "sqlwords.gperf"
    {"ROLLUP", ROLLUP},
#line 114 "sqlwords.gperf"
    {"GO", GO},
#line 162 "sqlwords.gperf"
    {"MUMPS", MUMPS},
#line 14 "sqlwords.gperf"
    {"ADA", ADA},
#line 30 "sqlwords.gperf"
    {"AUTHORIZATION", AUTHORIZATION},
#line 44 "sqlwords.gperf"
    {"CAST", CAST},
#line 268 "sqlwords.gperf"
    {"VALUE", VALUE},
#line 202 "sqlwords.gperf"
    {"READS", READS},
#line 133 "sqlwords.gperf"
    {"INSERT", INSERT},
#line 101 "sqlwords.gperf"
    {"FETCH", FETCH},
#line 23 "sqlwords.gperf"
    {"ARE", ARE},
#line 80 "sqlwords.gperf"
    {"DESC", DESC},
#line 251 "sqlwords.gperf"
    {"TEXT", TEXT_L},
#line 198 "sqlwords.gperf"
    {"PUBLIC", PUBLIC},
#line 265 "sqlwords.gperf"
    {"USE", USE},
#line 115 "sqlwords.gperf"
    {"GOTO", GOTO},
#line 216 "sqlwords.gperf"
    {"RETURNS", RETURNS},
#line 84 "sqlwords.gperf"
    {"DO", DO},
#line 17 "sqlwords.gperf"
    {"AFTER", AFTER},
#line 124 "sqlwords.gperf"
    {"IF", IF},
#line 214 "sqlwords.gperf"
    {"RESULT", RESULT},
#line 62 "sqlwords.gperf"
    {"CONTINUE", CONTINUE},
#line 139 "sqlwords.gperf"
    {"INTERNAL", INTERNAL},
#line 223 "sqlwords.gperf"
    {"SAFE", SAFE_L},
#line 276 "sqlwords.gperf"
    {"WHERE", WHERE},
#line 170 "sqlwords.gperf"
    {"NULL", NULLX},
#line 15 "sqlwords.gperf"
    {"ADD", ADD},
#line 12 "sqlwords.gperf"
    {"__SOAP_ENC_MIME", __SOAP_ENC_MIME},
#line 203 "sqlwords.gperf"
    {"REAL", REAL},
#line 111 "sqlwords.gperf"
    {"FUNCTION", FUNCTION},
#line 280 "sqlwords.gperf"
    {"WORK", WORK},
#line 91 "sqlwords.gperf"
    {"ENCODING", ENCODING},
#line 116 "sqlwords.gperf"
    {"GRANT", GRANT},
#line 109 "sqlwords.gperf"
    {"FROM", FROM},
#line 142 "sqlwords.gperf"
    {"IS", IS},
#line 145 "sqlwords.gperf"
    {"JAVA", JAVA},
#line 99 "sqlwords.gperf"
    {"EXTRACT", EXTRACT},
#line 245 "sqlwords.gperf"
    {"START", START_L},
#line 87 "sqlwords.gperf"
    {"DTD", DTD},
#line 65 "sqlwords.gperf"
    {"CREATE", CREATE},
#line 7 "sqlwords.gperf"
    {"__SOAP_NAME", __SOAP_NAME},
#line 129 "sqlwords.gperf"
    {"INDICATOR", INDICATOR},
#line 282 "sqlwords.gperf"
    {"XPATH", XPATH},
#line 135 "sqlwords.gperf"
    {"INSTEAD", INSTEAD},
#line 55 "sqlwords.gperf"
    {"COLLATE", COLLATE},
#line 31 "sqlwords.gperf"
    {"AUTOREGISTER", AUTOREGISTER_L},
#line 219 "sqlwords.gperf"
    {"RIGHT", RIGHT},
#line 66 "sqlwords.gperf"
    {"CROSS", CROSS},
#line 258 "sqlwords.gperf"
    {"TYPE", TYPE},
#line 143 "sqlwords.gperf"
    {"ISOLATION", ISOLATION_L},
#line 25 "sqlwords.gperf"
    {"AS", AS},
#line 20 "sqlwords.gperf"
    {"ALTER", ALTER},
#line 56 "sqlwords.gperf"
    {"COLUMN", COLUMN},
#line 204 "sqlwords.gperf"
    {"REF", REF},
#line 164 "sqlwords.gperf"
    {"NATURAL", NATURAL},
#line 83 "sqlwords.gperf"
    {"DISTINCT", DISTINCT},
#line 259 "sqlwords.gperf"
    {"TRANSACTION", TRANSACTION_L},
#line 277 "sqlwords.gperf"
    {"WHILE", WHILE},
#line 6 "sqlwords.gperf"
    {"__SOAP_HTTP", __SOAP_HTTP},
#line 42 "sqlwords.gperf"
    {"CASCADE", CASCADE},
#line 38 "sqlwords.gperf"
    {"BY", BY},
#line 187 "sqlwords.gperf"
    {"PASSWORD", PASSWORD},
#line 274 "sqlwords.gperf"
    {"WHEN", WHEN},
#line 160 "sqlwords.gperf"
    {"MODIFIES", MODIFIES},
#line 150 "sqlwords.gperf"
    {"LEFT", LEFT},
#line 175 "sqlwords.gperf"
    {"OF", OF},
#line 96 "sqlwords.gperf"
    {"EXECUTE", EXECUTE},
#line 9 "sqlwords.gperf"
    {"__SOAP_XML_TYPE", __SOAP_XML_TYPE},
#line 57 "sqlwords.gperf"
    {"COMMIT", COMMIT},
#line 77 "sqlwords.gperf"
    {"DECLARE", DECLARE},
#line 273 "sqlwords.gperf"
    {"VIEW", VIEW},
#line 205 "sqlwords.gperf"
    {"REFERENCES", REFERENCES},
#line 158 "sqlwords.gperf"
    {"METHOD", METHOD},
#line 206 "sqlwords.gperf"
    {"REFERENCING", REFERENCING},
#line 118 "sqlwords.gperf"
    {"GROUPING", GROUPING},
#line 68 "sqlwords.gperf"
    {"CURRENT", CURRENT},
#line 81 "sqlwords.gperf"
    {"DETERMINISTIC", DETERMINISTIC},
#line 45 "sqlwords.gperf"
    {"CHAR", CHARACTER},
#line 228 "sqlwords.gperf"
    {"SELF", SELF_L},
#line 85 "sqlwords.gperf"
    {"DOUBLE", DOUBLE_L},
#line 70 "sqlwords.gperf"
    {"CURRENT_TIME", CURRENT_TIME},
#line 227 "sqlwords.gperf"
    {"SELECT", SELECT},
#line 5 "sqlwords.gperf"
    {"__SOAP_HEADER", __SOAP_HEADER},
#line 53 "sqlwords.gperf"
    {"COALESCE", COALESCE},
#line 220 "sqlwords.gperf"
    {"ROLLBACK", ROLLBACK},
#line 71 "sqlwords.gperf"
    {"CURRENT_TIMESTAMP", CURRENT_TIMESTAMP},
#line 119 "sqlwords.gperf"
    {"HANDLER", HANDLER},
#line 149 "sqlwords.gperf"
    {"LANGUAGE", LANGUAGE},
#line 252 "sqlwords.gperf"
    {"THEN", THEN},
#line 138 "sqlwords.gperf"
    {"INTERSECT", INTERSECT},
#line 232 "sqlwords.gperf"
    {"SMALLINT", SMALLINT},
#line 98 "sqlwords.gperf"
    {"EXTERNAL", EXTERNAL},
#line 236 "sqlwords.gperf"
    {"SOURCE", SOURCE},
#line 212 "sqlwords.gperf"
    {"RESIGNAL", RESIGNAL},
#line 226 "sqlwords.gperf"
    {"SCHEMA", SCHEMA},
#line 211 "sqlwords.gperf"
    {"REPLICATION", REPLICATION},
#line 253 "sqlwords.gperf"
    {"TIES", TIES},
#line 103 "sqlwords.gperf"
    {"FLOAT", FLOAT_L},
#line 153 "sqlwords.gperf"
    {"LIKE", LIKE},
#line 100 "sqlwords.gperf"
    {"EXIT", EXIT},
#line 191 "sqlwords.gperf"
    {"PLI", PLI},
#line 121 "sqlwords.gperf"
    {"HASH", HASH},
#line 177 "sqlwords.gperf"
    {"OLD", OLD},
#line 266 "sqlwords.gperf"
    {"USER", USER},
#line 151 "sqlwords.gperf"
    {"LEVEL", LEVEL_L},
#line 272 "sqlwords.gperf"
    {"VARIABLE", VARIABLE},
#line 10 "sqlwords.gperf"
    {"__SOAP_FAULT", __SOAP_FAULT},
#line 4 "sqlwords.gperf"
    {"__SOAP_DOCW", __SOAP_DOCW},
#line 11 "sqlwords.gperf"
    {"__SOAP_DIME_ENC", __SOAP_DIME_ENC},
#line 242 "sqlwords.gperf"
    {"SQLSTATE", SQLSTATE},
#line 40 "sqlwords.gperf"
    {"CALL", CALL},
#line 47 "sqlwords.gperf"
    {"CHECK", CHECK},
#line 28 "sqlwords.gperf"
    {"ATTACH", ATTACH},
#line 110 "sqlwords.gperf"
    {"FULL", FULL},
#line 234 "sqlwords.gperf"
    {"SOFT", SOFT},
#line 190 "sqlwords.gperf"
    {"PERSISTENT", PERSISTENT},
#line 171 "sqlwords.gperf"
    {"NULLIF", NULLIF},
#line 140 "sqlwords.gperf"
    {"INTERVAL", INTERVAL},
#line 18 "sqlwords.gperf"
    {"AGGREGATE", AGGREGATE},
#line 94 "sqlwords.gperf"
    {"EXCEPT", EXCEPT},
#line 26 "sqlwords.gperf"
    {"ASC", ASC},
#line 13 "sqlwords.gperf"
    {"__SOAP_OPTIONS", __SOAP_OPTIONS},
#line 69 "sqlwords.gperf"
    {"CURRENT_DATE", CURRENT_DATE},
#line 8 "sqlwords.gperf"
    {"__SOAP_TYPE", __SOAP_TYPE},
#line 95 "sqlwords.gperf"
    {"EXCLUSIVE", EXCLUSIVE},
#line 112 "sqlwords.gperf"
    {"GENERAL", GENERAL},
#line 127 "sqlwords.gperf"
    {"INCREMENT", INCREMENT_L},
#line 63 "sqlwords.gperf"
    {"CONVERT", CONVERT},
#line 233 "sqlwords.gperf"
    {"SNAPSHOT", SNAPSHOT},
#line 102 "sqlwords.gperf"
    {"FINAL", FINAL_L},
#line 260 "sqlwords.gperf"
    {"TRIGGER", TRIGGER},
#line 82 "sqlwords.gperf"
    {"DISCONNECT", DISCONNECT},
#line 267 "sqlwords.gperf"
    {"USING", USING},
#line 244 "sqlwords.gperf"
    {"STATIC", STATIC_L},
#line 54 "sqlwords.gperf"
    {"COBOL", COBOL},
#line 194 "sqlwords.gperf"
    {"PREFETCH", PREFETCH},
#line 72 "sqlwords.gperf"
    {"CURSOR", CURSOR},
#line 61 "sqlwords.gperf"
    {"CONTAINS", CONTAINS},
#line 24 "sqlwords.gperf"
    {"ARRAY", ARRAY},
#line 3 "sqlwords.gperf"
    {"__SOAP_DOC", __SOAP_DOC},
#line 120 "sqlwords.gperf"
    {"HAVING", HAVING},
#line 156 "sqlwords.gperf"
    {"LONG", LONG_L},
#line 189 "sqlwords.gperf"
    {"PERMISSION_SET", PERMISSION_SET},
#line 173 "sqlwords.gperf"
    {"NVARCHAR", NVARCHAR},
#line 104 "sqlwords.gperf"
    {"FOR", FOR},
#line 209 "sqlwords.gperf"
    {"REPEATABLE", REPEATABLE_L},
#line 107 "sqlwords.gperf"
    {"FORTRAN", FORTRAN},
#line 193 "sqlwords.gperf"
    {"PRECISION", PRECISION},
#line 176 "sqlwords.gperf"
    {"OFF", OFF},
#line 146 "sqlwords.gperf"
    {"JOIN", JOIN},
#line 27 "sqlwords.gperf"
    {"ASSEMBLY", ASSEMBLY_L},
#line 224 "sqlwords.gperf"
    {"UNCOMMITTED", UNCOMMITTED_L},
#line 123 "sqlwords.gperf"
    {"IDENTIFIED", IDENTIFIED},
#line 59 "sqlwords.gperf"
    {"CONSTRAINT", CONSTRAINT},
#line 247 "sqlwords.gperf"
    {"SYNC", SYNC},
#line 240 "sqlwords.gperf"
    {"SQLCODE", SQLCODE},
#line 37 "sqlwords.gperf"
    {"BINARY", BINARY},
#line 159 "sqlwords.gperf"
    {"MODIFY", MODIFY},
#line 49 "sqlwords.gperf"
    {"CHECKPOINT", CHECKPOINT},
#line 186 "sqlwords.gperf"
    {"PASCAL", PASCAL_L},
#line 281 "sqlwords.gperf"
    {"XML", XML},
#line 78 "sqlwords.gperf"
    {"DEFAULT", DEFAULT},
#line 19 "sqlwords.gperf"
    {"ALL", ALL},
#line 41 "sqlwords.gperf"
    {"CALLED", CALLED},
#line 76 "sqlwords.gperf"
    {"DECIMAL", DECIMAL_L},
#line 48 "sqlwords.gperf"
    {"CHECKED", CHECKED},
#line 225 "sqlwords.gperf"
    {"UNRESTRICTED", UNRESTRICTED_L},
#line 122 "sqlwords.gperf"
    {"IDENTITY", IDENTITY},
#line 108 "sqlwords.gperf"
    {"FOUND", FOUND},
#line 271 "sqlwords.gperf"
    {"VARCHAR", VARCHAR},
#line 88 "sqlwords.gperf"
    {"DYNAMIC", DYNAMIC},
#line 155 "sqlwords.gperf"
    {"LOG", LOGX},
#line 52 "sqlwords.gperf"
    {"CLR", CLR},
#line 174 "sqlwords.gperf"
    {"OBJECT_ID", OBJECT_ID},
#line 113 "sqlwords.gperf"
    {"GENERATED", GENERATED},
#line 239 "sqlwords.gperf"
    {"SQL", SQL_L},
#line 238 "sqlwords.gperf"
    {"SPECIFIC", SPECIFIC},
#line 250 "sqlwords.gperf"
    {"TEMPORARY", TEMPORARY},
#line 106 "sqlwords.gperf"
    {"FOREIGN", FOREIGN},
#line 90 "sqlwords.gperf"
    {"ELSEIF", ELSEIF},
#line 195 "sqlwords.gperf"
    {"PRIMARY", PRIMARY},
#line 229 "sqlwords.gperf"
    {"SERIALIZABLE", SERIALIZABLE_L},
#line 210 "sqlwords.gperf"
    {"REPLACING", REPLACING},
#line 60 "sqlwords.gperf"
    {"CONSTRUCTOR", CONSTRUCTOR},
#line 248 "sqlwords.gperf"
    {"SYSTEM", SYSTEM},
#line 200 "sqlwords.gperf"
    {"QUIETCAST", QUIETCAST_L},
#line 126 "sqlwords.gperf"
    {"INCREMENTAL", INCREMENTAL},
#line 237 "sqlwords.gperf"
    {"SPARQL", SPARQL_L},
#line 241 "sqlwords.gperf"
    {"SQLEXCEPTION", SQLEXCEPTION},
#line 58 "sqlwords.gperf"
    {"COMMITTED", COMMITTED_L},
#line 231 "sqlwords.gperf"
    {"SHUTDOWN", SHUTDOWN},
#line 152 "sqlwords.gperf"
    {"LIBRARY", LIBRARY_L},
#line 275 "sqlwords.gperf"
    {"WHENEVER", WHENEVER},
#line 46 "sqlwords.gperf"
    {"CHARACTER", CHARACTER},
#line 185 "sqlwords.gperf"
    {"OVERRIDING", OVERRIDING},
#line 144 "sqlwords.gperf"
    {"IRI_ID", IRI_ID},
#line 167 "sqlwords.gperf"
    {"NONINCREMENTAL", NONINCREMENTAL},
#line 269 "sqlwords.gperf"
    {"VALUES", VALUES},
#line 154 "sqlwords.gperf"
    {"LOCATOR", LOCATOR},
#line 243 "sqlwords.gperf"
    {"SQLWARNING", SQLWARNING},
#line 105 "sqlwords.gperf"
    {"FOREACH", FOREACH},
#line 196 "sqlwords.gperf"
    {"PRIVILEGES", PRIVILEGES},
#line 97 "sqlwords.gperf"
    {"EXISTS", EXISTS},
#line 64 "sqlwords.gperf"
    {"CORRESPONDING", CORRESPONDING},
#line 51 "sqlwords.gperf"
    {"CLUSTERED", CLUSTERED},
#line 270 "sqlwords.gperf"
    {"VARBINARY", VARBINARY}
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
     -1,  -1,  -1,  -1,  -1,  -1,   0,  -1,  -1,  -1,
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
     -1,  -1,  -1,  -1,  -1,  -1,  -1,   1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
      2,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,   3,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,   4,  -1,  -1,  -1,   5,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,   6,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,   7,  -1,   8,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,   9,  10,  -1,  -1,
     -1,  -1,  -1,  -1,  11,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  12,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  13,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     14,  -1,  -1,  15,  -1,  -1,  -1,  16,  -1,  -1,
     -1,  -1,  -1,  -1,  17,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  18,  -1,  -1,  -1,  -1,  -1,
     -1,  19,  -1,  -1,  -1,  -1,  -1,  20,  -1,  21,
     -1,  22,  -1,  -1,  -1,  23,  -1,  -1,  24,  -1,
     -1,  -1,  -1,  25,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  26,  -1,  -1,  -1,  -1,
     -1,  -1,  27,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  28,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  29,
     30,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  31,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  32,  33,  -1,
     -1,  34,  35,  36,  -1,  -1,  37,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  38,  -1,
     39,  40,  -1,  -1,  41,  -1,  -1,  -1,  -1,  42,
     -1,  -1,  -1,  -1,  -1,  43,  -1,  -1,  -1,  -1,
     -1,  44,  45,  -1,  46,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  47,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  48,  -1,  49,  -1,  50,  -1,
     -1,  -1,  -1,  -1,  51,  -1,  -1,  -1,  52,  -1,
     -1,  -1,  -1,  53,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  54,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  55,  -1,
     -1,  -1,  -1,  -1,  -1,  56,  -1,  -1,  -1,  -1,
     57,  58,  59,  -1,  -1,  -1,  -1,  -1,  -1,  60,
     61,  62,  -1,  -1,  -1,  -1,  -1,  63,  -1,  -1,
     -1,  64,  65,  -1,  -1,  66,  -1,  -1,  -1,  -1,
     67,  68,  -1,  -1,  -1,  69,  70,  -1,  -1,  -1,
     -1,  71,  -1,  -1,  -1,  -1,  -1,  72,  73,  74,
     -1,  75,  -1,  -1,  -1,  -1,  76,  -1,  -1,  77,
     78,  -1,  79,  80,  -1,  -1,  81,  82,  83,  -1,
     -1,  -1,  -1,  84,  -1,  -1,  -1,  -1,  85,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  86,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  87,  88,  -1,
     -1,  -1,  -1,  89,  90,  91,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  92,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  93,  94,  -1,  -1,
     95,  -1,  -1,  96,  -1,  -1,  -1,  97,  -1,  -1,
     -1,  98,  -1,  99,  -1,  -1, 100,  -1, 101,  -1,
     -1,  -1,  -1, 102,  -1,  -1,  -1,  -1, 103,  -1,
     -1, 104, 105, 106,  -1,  -1,  -1, 107,  -1,  -1,
    108,  -1,  -1, 109,  -1,  -1,  -1,  -1,  -1,  -1,
     -1, 110,  -1,  -1,  -1, 111, 112, 113,  -1, 114,
     -1, 115,  -1, 116,  -1,  -1,  -1,  -1,  -1, 117,
     -1,  -1,  -1, 118, 119,  -1, 120,  -1,  -1,  -1,
     -1,  -1,  -1, 121,  -1,  -1,  -1,  -1,  -1,  -1,
    122,  -1,  -1, 123, 124,  -1, 125, 126,  -1,  -1,
    127, 128,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
    129, 130, 131, 132,  -1, 133,  -1, 134, 135,  -1,
    136,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1, 137,  -1, 138,  -1,  -1,  -1,  -1,
    139, 140, 141, 142,  -1, 143, 144, 145, 146,  -1,
     -1, 147,  -1, 148,  -1, 149, 150,  -1,  -1,  -1,
    151,  -1, 152,  -1,  -1, 153,  -1,  -1,  -1, 154,
     -1,  -1,  -1,  -1,  -1, 155,  -1, 156,  -1, 157,
    158,  -1,  -1,  -1,  -1,  -1,  -1,  -1, 159,  -1,
     -1, 160,  -1,  -1,  -1,  -1, 161,  -1,  -1,  -1,
     -1, 162,  -1,  -1,  -1, 163,  -1, 164, 165, 166,
     -1,  -1,  -1,  -1,  -1,  -1,  -1, 167,  -1, 168,
     -1,  -1, 169,  -1, 170,  -1, 171, 172,  -1,  -1,
    173, 174,  -1,  -1,  -1,  -1, 175,  -1, 176,  -1,
    177, 178,  -1,  -1,  -1, 179,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1, 180,  -1,  -1,  -1,  -1,
     -1,  -1,  -1, 181,  -1,  -1, 182,  -1,  -1,  -1,
    183,  -1,  -1,  -1, 184,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1, 185,  -1, 186,  -1,
     -1, 187, 188, 189,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1, 190,  -1,  -1,  -1, 191,  -1,  -1,  -1,
    192,  -1,  -1, 193,  -1,  -1,  -1, 194,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1, 195,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
    196, 197,  -1,  -1,  -1, 198,  -1,  -1,  -1,  -1,
     -1,  -1, 199,  -1, 200, 201,  -1,  -1,  -1,  -1,
    202,  -1,  -1, 203,  -1,  -1,  -1,  -1, 204,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1, 205,  -1,
     -1,  -1,  -1, 206, 207,  -1,  -1,  -1, 208, 209,
     -1, 210,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1, 211,  -1,  -1, 212, 213,  -1,  -1,  -1,  -1,
     -1,  -1, 214,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
    215,  -1, 216,  -1,  -1,  -1,  -1,  -1,  -1, 217,
     -1,  -1,  -1, 218,  -1,  -1, 219,  -1,  -1,  -1,
    220,  -1,  -1,  -1,  -1,  -1, 221,  -1,  -1,  -1,
     -1,  -1, 222, 223, 224,  -1,  -1, 225,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1, 226, 227,  -1, 228,
    229,  -1,  -1,  -1,  -1, 230,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1, 231,  -1, 232,  -1,  -1,  -1,
     -1, 233,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1, 234,  -1, 235, 236,  -1,  -1,  -1,  -1, 237,
     -1,  -1,  -1,  -1,  -1,  -1,  -1, 238,  -1,  -1,
     -1, 239,  -1,  -1,  -1, 240, 241,  -1,  -1,  -1,
     -1,  -1,  -1, 242,  -1,  -1, 243,  -1, 244,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1, 245,  -1,  -1, 246,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1, 247,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1, 248,  -1, 249,
    250,  -1,  -1, 251,  -1,  -1,  -1, 252,  -1,  -1,
    253,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1, 254,  -1,  -1,  -1,  -1, 255,
     -1,  -1,  -1, 256,  -1,  -1,  -1,  -1,  -1, 257,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1, 258,  -1,  -1,  -1,  -1,  -1,  -1, 259, 260,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1, 261,  -1,  -1,  -1,  -1,
    262,  -1, 263,  -1,  -1,  -1,  -1,  -1,  -1, 264,
     -1,  -1,  -1,  -1,  -1,  -1, 265, 266,  -1,  -1,
     -1, 267,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1, 268,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1, 269,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1, 270,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1, 271,  -1,  -1,  -1, 272,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1, 273,
    274,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1, 275,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1, 276,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1, 277,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
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
     -1,  -1,  -1, 278,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1, 279
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

/*
 *  gqlc_plugin.c
 *
 *  GQL Phase 4 C plugin for Virtuoso.
 *
 *  Provides BIFs that have no SPARQL or PL equivalent:
 *    - GQL_NORMALIZE(str [, form])     — Unicode normalization via ICU
 *    - GQL_IS_NORMALIZED(str [, form]) — Check if string is in given form
 *
 *  This plugin links against ICU (libicuuc) for Unicode normalization.
 *  It is built as a "plain" VSEI plugin and loaded via virtuoso.ini.
 *
 *  Build: see Makefile.am in this directory.
 *  Load:  LoadN = plain, gqlc   (in [Plugins] section of virtuoso.ini)
 *
 */

#include "import_gate_virtuoso.h"
#include "sqlver.h"

#include <string.h>
#include <stdlib.h>

/* ICU headers */
#include <unicode/utypes.h>
#include <unicode/ustring.h>
#include <unicode/unorm.h>
#include <unicode/uchar.h>

/* ------------------------------------------------------------------ */
/* Helpers                                                             */
/* ------------------------------------------------------------------ */

/*
 * Convert a normalization form name string to a UNormalizationMode enum.
 * Accepts: NFC (default), NFD, NFKC, NFKD.
 * Returns -1 for unknown form.
 */
static int
gqlc_form_name_to_mode (const char *form_name)
{
  if (form_name == NULL || form_name[0] == '\0')
    return UNORM_NFC;
  if (strcmp (form_name, "NFC") == 0 || strcmp (form_name, "nfc") == 0)
    return UNORM_NFC;
  if (strcmp (form_name, "NFD") == 0 || strcmp (form_name, "nfd") == 0)
    return UNORM_NFD;
  if (strcmp (form_name, "NFKC") == 0 || strcmp (form_name, "nfkc") == 0)
    return UNORM_NFKC;
  if (strcmp (form_name, "NFKD") == 0 || strcmp (form_name, "nfkd") == 0)
    return UNORM_NFKD;
  return -1;
}

/*
 * Convert a Virtuoso UTF-8 string (caddr_t, DV_STRING) to a UChar buffer.
 * Returns dk_alloc'd buffer; caller must dk_free with the returned size.
 * Sets *out_len to number of UChars (not counting terminator).
 * Sets *out_alloc_sz to the total allocation size for dk_free.
 * Returns NULL on error (with UErrorCode set).
 */
static UChar *
gqlc_utf8_to_uchar (const char *utf8, int32_t utf8_len, int32_t *out_len, size_t *out_alloc_sz, UErrorCode *err)
{
  int32_t needed;
  UChar *buf;
  size_t alloc_sz;

  *err = U_ZERO_ERROR;
  /* Pre-flight to get required capacity */
  u_strFromUTF8 (NULL, 0, &needed, utf8, utf8_len, err);
  if (*err != U_BUFFER_OVERFLOW_ERROR && *err != U_ZERO_ERROR)
    return NULL;

  *err = U_ZERO_ERROR;
  alloc_sz = (size_t) (needed + 1) * sizeof (UChar);
  buf = (UChar *) dk_alloc (alloc_sz);
  if (buf == NULL)
    {
      *err = U_MEMORY_ALLOCATION_ERROR;
      return NULL;
    }
  u_strFromUTF8 (buf, needed, out_len, utf8, utf8_len, err);
  if (U_FAILURE (*err))
    {
      dk_free (buf, alloc_sz);
      return NULL;
    }
  buf[*out_len] = 0;
  *out_alloc_sz = alloc_sz;
  return buf;
}

/*
 * Convert a UChar buffer back to a Virtuoso UTF-8 string (dk_alloc_box'd).
 * Returns NULL on error.
 */
static caddr_t
gqlc_uchar_to_utf8_box (const UChar *src, int32_t src_len, UErrorCode *err)
{
  int32_t needed;
  caddr_t box;

  *err = U_ZERO_ERROR;
  /* Pre-flight */
  u_strToUTF8 (NULL, 0, &needed, src, src_len, err);
  if (*err != U_BUFFER_OVERFLOW_ERROR && *err != U_ZERO_ERROR)
    return NULL;

  *err = U_ZERO_ERROR;
  box = dk_alloc_box (needed + 1, DV_STRING);
  if (box == NULL)
    {
      *err = U_MEMORY_ALLOCATION_ERROR;
      return NULL;
    }
  u_strToUTF8 (box, needed, &needed, src, src_len, err);
  if (U_FAILURE (*err))
    {
      dk_free_box (box);
      return NULL;
    }
  box[needed] = '\0';
  return box;
}

/* ------------------------------------------------------------------ */
/* BIF: GQL_NORMALIZE(str [, form])                                   */
/*                                                                    */
/* Returns the Unicode-normalized form of str.                        */
/* form is one of 'NFC', 'NFD', 'NFKC', 'NFKD' (default NFC).         */
/* Returns NULL if input is NULL.                                     */
/* ------------------------------------------------------------------ */
static caddr_t
bif_gqlc_normalize (caddr_t *qst, caddr_t *err_ret, state_slot_t **args)
{
  caddr_t str;
  caddr_t form_arg;
  const char *form_name;
  int mode;
  int32_t src_len, dst_len;
  size_t src_alloc_sz = 0, dst_alloc_sz = 0;
  UChar *src_buf = NULL;
  UChar *dst_buf = NULL;
  int32_t dst_capacity;
  caddr_t result = NULL;
  UErrorCode icu_err;

  /* Get string argument; allow NULL */
  str = bif_string_or_null_arg (qst, args, 0, "GQL_NORMALIZE");
  if (str == NULL)
    return dk_alloc_box (0, DV_STRING);

  /* Get optional form argument */
  form_arg = NULL;
  if (BOX_ELEMENTS (args) > 1)
    form_arg = bif_string_or_null_arg (qst, args, 1, "GQL_NORMALIZE");
  form_name = (form_arg != NULL) ? form_arg : "NFC";

  mode = gqlc_form_name_to_mode (form_name);
  if (mode < 0)
    sqlr_new_error ("22023", "GQ4C1",
        "GQL_NORMALIZE: unknown normalization form '%s' (expected NFC, NFD, NFKC, or NFKD)",
        form_name);

  /* Convert UTF-8 input to UChar */
  icu_err = U_ZERO_ERROR;
  src_buf = gqlc_utf8_to_uchar (str, (int32_t) box_length (str) - 1, &src_len, &src_alloc_sz, &icu_err);
  if (src_buf == NULL)
    sqlr_new_error ("22023", "GQ4C2",
        "GQL_NORMALIZE: ICU conversion error: %s", u_errorName (icu_err));

  /* Normalize */
  /* Pre-flight to get required capacity */
  icu_err = U_ZERO_ERROR;
  unorm_normalize (src_buf, src_len, (UNormalizationMode) mode, 0,
      NULL, 0, &icu_err);
  if (icu_err != U_BUFFER_OVERFLOW_ERROR && icu_err != U_ZERO_ERROR)
    {
      dk_free (src_buf, src_alloc_sz);
      sqlr_new_error ("22023", "GQ4C3",
          "GQL_NORMALIZE: ICU normalize error: %s", u_errorName (icu_err));
    }
  dst_capacity = (icu_err == U_BUFFER_OVERFLOW_ERROR)
      ? (int32_t) (src_len * 2 + 16) : (src_len + 1);
  icu_err = U_ZERO_ERROR;
  dst_alloc_sz = (size_t) dst_capacity * sizeof (UChar);
  dst_buf = (UChar *) dk_alloc (dst_alloc_sz);
  if (dst_buf == NULL)
    {
      dk_free (src_buf, src_alloc_sz);
      sqlr_new_error ("HY000", "GQ4C4",
          "GQL_NORMALIZE: memory allocation failed");
    }
  unorm_normalize (src_buf, src_len, (UNormalizationMode) mode, 0,
      dst_buf, dst_capacity, &icu_err);
  if (U_FAILURE (icu_err))
    {
      dk_free (src_buf, src_alloc_sz);
      dk_free (dst_buf, dst_alloc_sz);
      sqlr_new_error ("22023", "GQ4C5",
          "GQL_NORMALIZE: ICU normalize error: %s", u_errorName (icu_err));
    }
  dst_len = icu_err == U_STRING_NOT_TERMINATED_WARNING
      ? (int32_t) u_strlen (dst_buf) : (int32_t) u_strlen (dst_buf);

  /* Convert back to UTF-8 */
  icu_err = U_ZERO_ERROR;
  result = gqlc_uchar_to_utf8_box (dst_buf, dst_len, &icu_err);
  dk_free (src_buf, src_alloc_sz);
  dk_free (dst_buf, dst_alloc_sz);
  if (result == NULL)
    sqlr_new_error ("22023", "GQ4C6",
        "GQL_NORMALIZE: ICU conversion error: %s", u_errorName (icu_err));

  return result;
}

/* ------------------------------------------------------------------ */
/* BIF: GQL_IS_NORMALIZED(str [, form])                               */
/*                                                                    */
/* Returns 1 if str is already in the given normalization form,       */
/* 0 otherwise.  form is one of NFC (default), NFD, NFKC, NFKD.       */
/* Returns NULL if input is NULL.                                     */
/* ------------------------------------------------------------------ */
static caddr_t
bif_gqlc_is_normalized (caddr_t *qst, caddr_t *err_ret, state_slot_t **args)
{
  caddr_t str;
  caddr_t form_arg;
  const char *form_name;
  int mode;
  int32_t src_len;
  size_t src_alloc_sz = 0;
  UChar *src_buf = NULL;
  UNormalizationCheckResult check_result;
  UErrorCode icu_err;

  /* Get string argument; allow NULL */
  str = bif_string_or_null_arg (qst, args, 0, "GQL_IS_NORMALIZED");
  if (str == NULL)
    return dk_alloc_box (0, DV_STRING);

  /* Get optional form argument */
  form_arg = NULL;
  if (BOX_ELEMENTS (args) > 1)
    form_arg = bif_string_or_null_arg (qst, args, 1, "GQL_IS_NORMALIZED");
  form_name = (form_arg != NULL) ? form_arg : "NFC";

  mode = gqlc_form_name_to_mode (form_name);
  if (mode < 0)
    sqlr_new_error ("22023", "GQ4C7",
        "GQL_IS_NORMALIZED: unknown normalization form '%s' (expected NFC, NFD, NFKC, or NFKD)",
        form_name);

  /* Convert UTF-8 input to UChar */
  icu_err = U_ZERO_ERROR;
  src_buf = gqlc_utf8_to_uchar (str, (int32_t) box_length (str) - 1, &src_len, &src_alloc_sz, &icu_err);
  if (src_buf == NULL)
    sqlr_new_error ("22023", "GQ4C8",
        "GQL_IS_NORMALIZED: ICU conversion error: %s", u_errorName (icu_err));

  /* Quick check */
  icu_err = U_ZERO_ERROR;
  check_result = unorm_quickCheck (src_buf, src_len, (UNormalizationMode) mode, &icu_err);
  dk_free (src_buf, src_alloc_sz);

  if (U_FAILURE (icu_err))
    sqlr_new_error ("22023", "GQ4C9",
        "GQL_IS_NORMALIZED: ICU quickCheck error: %s", u_errorName (icu_err));

  /*
   * UNORM_YES  → string is normalized
   * UNORM_NO   → string is not normalized
   * UNORM_MAYBE → need full check; do a full normalize and compare
   */
  if (check_result == UNORM_YES)
    return box_num (1);

  if (check_result == UNORM_NO)
    return box_num (0);

  /* UNORM_MAYBE: do a full normalization and compare */
  {
    UChar *norm_buf;
    size_t norm_alloc_sz = 0;
    int32_t dst_capacity;

    icu_err = U_ZERO_ERROR;
    src_buf = gqlc_utf8_to_uchar (str, (int32_t) box_length (str) - 1, &src_len, &src_alloc_sz, &icu_err);
    if (src_buf == NULL)
      sqlr_new_error ("22023", "GQ4C8",
          "GQL_IS_NORMALIZED: ICU conversion error: %s", u_errorName (icu_err));

    dst_capacity = src_len * 2 + 16;
    norm_alloc_sz = (size_t) dst_capacity * sizeof (UChar);
    norm_buf = (UChar *) dk_alloc (norm_alloc_sz);
    if (norm_buf == NULL)
      {
        dk_free (src_buf, src_alloc_sz);
        sqlr_new_error ("HY000", "GQ4CA",
            "GQL_IS_NORMALIZED: memory allocation failed");
      }

    icu_err = U_ZERO_ERROR;
    unorm_normalize (src_buf, src_len, (UNormalizationMode) mode, 0,
        norm_buf, dst_capacity, &icu_err);
    if (U_FAILURE (icu_err))
      {
        dk_free (src_buf, src_alloc_sz);
        dk_free (norm_buf, norm_alloc_sz);
        sqlr_new_error ("22023", "GQ4CB",
            "GQL_IS_NORMALIZED: ICU normalize error: %s", u_errorName (icu_err));
      }

    {
      int32_t norm_len = (int32_t) u_strlen (norm_buf);
      int is_norm = (norm_len == src_len
          && u_memcmp (src_buf, norm_buf, src_len) == 0);
      dk_free (src_buf, src_alloc_sz);
      dk_free (norm_buf, norm_alloc_sz);
      return box_num (is_norm ? 1 : 0);
    }
  }
}

/* ------------------------------------------------------------------ */
/* BIF: GQL_PERCENTILE_CONT(vals, p)                                  */
/*                                                                    */
/* Continuous percentile: linear interpolation between closest ranks. */
/* vals is a vector of numeric values, p is 0..1.                      */
/* Returns NULL if vals is NULL or empty.                              */
/* ------------------------------------------------------------------ */
static int
gqlc_dbl_cmp (const void *a, const void *b)
{
  double da = *(const double *)a;
  double db = *(const double *)b;
  if (da < db) return -1;
  if (da > db) return 1;
  return 0;
}

static caddr_t
bif_gqlc_percentile_cont (caddr_t *qst, caddr_t *err_ret, state_slot_t **args)
{
  caddr_t vals_arg;
  double p;
  int n, i;
  double *sorted;
  caddr_t result;

  vals_arg = bif_array_or_null_arg (qst, args, 0, "GQL_PERCENTILE_CONT");
  if (vals_arg == NULL)
    return dk_alloc_box (0, DV_STRING);

  p = bif_double_arg (qst, args, 1, "GQL_PERCENTILE_CONT");
  if (p < 0.0 || p > 1.0)
    sqlr_new_error ("22023", "GQ4D1",
        "GQL_PERCENTILE_CONT: percentile must be between 0 and 1");

  n = BOX_ELEMENTS (vals_arg);
  if (n < 1)
    return dk_alloc_box (0, DV_STRING);

  sorted = (double *) dk_alloc (sizeof (double) * (size_t) n);
  if (sorted == NULL)
    sqlr_new_error ("HY000", "GQ4D2",
        "GQL_PERCENTILE_CONT: memory allocation failed");

  for (i = 0; i < n; i++)
    {
      caddr_t item = ((caddr_t *) vals_arg)[i];
      if (DV_TYPE_OF (item) == DV_DOUBLE_FLOAT)
        sorted[i] = *(double *) item;
      else
        sorted[i] = unbox (item);
    }

  qsort (sorted, (size_t) n, sizeof (double), gqlc_dbl_cmp);

  if (n == 1)
    {
      result = box_double (sorted[0]);
      dk_free (sorted, sizeof (double) * (size_t) n);
      return result;
    }

  {
    double rank, lo_d, hi_d;
    int lo, hi;
    double lo_val, hi_val;

    rank = p * (double) (n - 1);
    lo = (int) floor (rank);
    hi = (int) ceil (rank);
    lo_d = (double) lo;
    hi_d = (double) hi;

    if (lo == hi)
      result = box_double (sorted[lo]);
    else
      {
        lo_val = sorted[lo];
        hi_val = sorted[hi];
        result = box_double (lo_val + (hi_val - lo_val) * (rank - lo_d));
      }
  }

  dk_free (sorted, sizeof (double) * (size_t) n);
  return result;
}

/* ------------------------------------------------------------------ */
/* BIF: GQL_PERCENTILE_DISC(vals, p)                                  */
/*                                                                    */
/* Discrete percentile: returns the value at the nearest rank.        */
/* vals is a vector of numeric values, p is 0..1.                      */
/* Returns NULL if vals is NULL or empty.                              */
/* ------------------------------------------------------------------ */
static caddr_t
bif_gqlc_percentile_disc (caddr_t *qst, caddr_t *err_ret, state_slot_t **args)
{
  caddr_t vals_arg;
  double p;
  int n, i;
  double *sorted;
  caddr_t result;

  vals_arg = bif_array_or_null_arg (qst, args, 0, "GQL_PERCENTILE_DISC");
  if (vals_arg == NULL)
    return dk_alloc_box (0, DV_STRING);

  p = bif_double_arg (qst, args, 1, "GQL_PERCENTILE_DISC");
  if (p < 0.0 || p > 1.0)
    sqlr_new_error ("22023", "GQ4D3",
        "GQL_PERCENTILE_DISC: percentile must be between 0 and 1");

  n = BOX_ELEMENTS (vals_arg);
  if (n < 1)
    return dk_alloc_box (0, DV_STRING);

  sorted = (double *) dk_alloc (sizeof (double) * (size_t) n);
  if (sorted == NULL)
    sqlr_new_error ("HY000", "GQ4D4",
        "GQL_PERCENTILE_DISC: memory allocation failed");

  for (i = 0; i < n; i++)
    {
      caddr_t item = ((caddr_t *) vals_arg)[i];
      if (DV_TYPE_OF (item) == DV_DOUBLE_FLOAT)
        sorted[i] = *(double *) item;
      else
        sorted[i] = unbox (item);
    }

  qsort (sorted, (size_t) n, sizeof (double), gqlc_dbl_cmp);

  {
    int idx = (int) ceil (p * (double) n) - 1;
    if (idx < 0) idx = 0;
    if (idx >= n) idx = n - 1;
    result = box_double (sorted[idx]);
  }

  dk_free (sorted, sizeof (double) * (size_t) n);
  return result;
}

/* ------------------------------------------------------------------ */
/* Plugin connect / disconnect                                        */
/* ------------------------------------------------------------------ */
static void
gqlc_plugin_connect (void *appdata)
{
  bif_define ("GQL_NORMALIZE", bif_gqlc_normalize);
  bif_define ("GQL_IS_NORMALIZED", bif_gqlc_is_normalized);
  bif_define ("GQL_PERCENTILE_CONT", bif_gqlc_percentile_cont);
  bif_define ("GQL_PERCENTILE_DISC", bif_gqlc_percentile_disc);
}

static void
gqlc_plugin_disconnect (void *appdata)
{
  /* Nothing to clean up */
}

/* ------------------------------------------------------------------ */
/* Plugin version structure                                           */
/* ------------------------------------------------------------------ */
static unit_version_t gqlc_plugin_version = {
  PLAIN_PLUGIN_TYPE,			/*!< Title of unit, filled by unit */
  DBMS_SRV_GEN_MAJOR DBMS_SRV_GEN_MINOR,	/*!< Version number, filled by unit */
  "OpenLink Software",			/*!< Plugin's developer, filled by unit */
  "GQL Phase 4 C functions (Unicode normalization via ICU, percentile aggregates)", /*!< Additional info */
  0,					/*!< Error message, filled by unit loader */
  0,					/*!< Name of file with unit's code, filled by unit loader */
  gqlc_plugin_connect,			/*!< Pointer to connection function, cannot be 0 */
  gqlc_plugin_disconnect,		/*!< Pointer to disconnection function, or 0 */
  0,					/*!< Pointer to activation function, or 0 */
  0,					/*!< Pointer to deactivation function, or 0 */
  &_gate
};

/* ------------------------------------------------------------------ */
/* Entry point                                                        */
/* ------------------------------------------------------------------ */
unit_version_t *CALLBACK
gqlc_check (unit_version_t *in, void *appdata)
{
  return &gqlc_plugin_version;
}

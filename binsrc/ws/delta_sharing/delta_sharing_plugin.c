#include "import_gate_virtuoso.h"
#include "sqlver.h"

#include <stdio.h>
#include <string.h>
#include "carquet/carquet.h"

#define SEC2EPOCH 62135769600

static const carquet_logical_type_t string_type = { .id = CARQUET_LOGICAL_STRING };
static const carquet_logical_type_t timestamp_type = { .id = CARQUET_LOGICAL_TIMESTAMP,
  .params.timestamp = {
    .unit = CARQUET_TIME_UNIT_MILLIS,
    .is_adjusted_to_utc = true
  }
};
static const carquet_logical_type_t date_type = { .id = CARQUET_LOGICAL_DATE };
static const carquet_logical_type_t time_type = { .id = CARQUET_LOGICAL_TIME };
static const carquet_logical_type_t unknown_type = { .id = CARQUET_LOGICAL_UNKNOWN };


static caddr_t
fatal_error(const char* context, const carquet_error_t* err) {
  return srv_make_new_error ("42000", "PARXX", "ERROR in %s: %s (code %d)", context, err->message, err->code);
}

static carquet_status_t
parquet_schema_add_column(carquet_schema_t* schema, caddr_t *meta)
{
  carquet_status_t status;
  caddr_t col_name = meta[0];
  dtp_t dtp = unbox(meta[1]);
  carquet_physical_type_t physical_type;
  carquet_logical_type_t *logical_type;

  switch (dtp)
    {
      case DV_LONG_INT:
      case DV_SHORT_INT:
      case DV_IRI_ID:
          physical_type = CARQUET_PHYSICAL_INT32;
          logical_type = NULL;
          break;
      case DV_INT64:
      case DV_IRI_ID_8:
          physical_type = CARQUET_PHYSICAL_INT64;
          logical_type = NULL;
          break;
      case DV_SINGLE_FLOAT:
          physical_type = CARQUET_PHYSICAL_FLOAT;
          logical_type = NULL;
          break;
      case DV_DOUBLE_FLOAT:
          physical_type = CARQUET_PHYSICAL_DOUBLE;
          logical_type = NULL;
          break;
      case DV_STRING:
      case DV_BLOB:
      case DV_WIDE:
      case DV_UNAME:
          physical_type = CARQUET_PHYSICAL_BYTE_ARRAY;
          logical_type = &string_type;
          break;
      case DV_DATETIME:
      case DV_TIMESTAMP:
          physical_type = CARQUET_PHYSICAL_INT64;
          logical_type = &timestamp_type;
          break;
      case DV_DATE:
          physical_type = CARQUET_PHYSICAL_INT32;
          logical_type = &date_type;
          break;
      case DV_TIME:
          physical_type = CARQUET_PHYSICAL_INT32;
          logical_type = &time_type;
          break;
      case DV_NUMERIC:
          physical_type = CARQUET_PHYSICAL_DOUBLE;
          logical_type = NULL;
          break;
      case DV_BLOB_BIN:
      case DV_BIN:
          physical_type = CARQUET_PHYSICAL_BYTE_ARRAY;
          logical_type = NULL;
          break;
      default:
          physical_type = CARQUET_PHYSICAL_BYTE_ARRAY;
          logical_type = &unknown_type;
          break;
    }
  status = carquet_schema_add_column(schema, col_name,
      physical_type, logical_type, CARQUET_REPETITION_REQUIRED, 0, 0);
  return status;
}

static int
parquet_batch_add_value (caddr_t *qst, void *batch, dtp_t dtp, caddr_t val, int32_t n_vals, char *cs, caddr_t * err_ret)
{
  dtp_t val_dtp = DV_TYPE_OF(val);
  if (DV_DB_NULL == val_dtp)
    return 0;
  if (IS_BLOB_DTP(dtp))
    dtp = val_dtp;
  if (IS_BLOB_HANDLE_DTP(val_dtp))
    {
      blob_handle_t *bh = (blob_handle_t*)val;
      size_t bytes = bh->bh_length * SIZEOF_SYMBOL_FOR_BLOB_HANDLE_DTP(val_dtp);
      if (bytes > 10000000)
        {
          err_ret[0] = srv_make_new_error ("42000", "PAR02", "Parquet file cannot handle large blobs, use a URI to content");
          return 0;
        }
    }
  switch (dtp)
    {
      case DV_LONG_INT:
      case DV_SHORT_INT:
          ((int32_t*)batch)[n_vals] = (int32_t)unbox(val);
          break;
      case DV_DATE:
          ((int32_t*)batch)[n_vals] = (int32_t)(DT_UDAY(val) - (SEC2EPOCH / 86400));
          break;
      case DV_TIME:
          ((int32_t*)batch)[n_vals] = DT_HOUR(val) + DT_MINUTE(val) + DT_SECOND(val);
          break;
      case DV_INT64:
          ((int64_t*)batch)[n_vals] = (int64_t)val;
          break;
      case DV_IRI_ID:
          ((int32_t*)batch)[n_vals] = (int32_t) unbox_iri_id(val);
          break;
      case DV_IRI_ID_8:
          ((int64_t*)batch)[n_vals] = (int64_t) unbox_iri_id(val);
          break;
      case DV_STRING:
      case DV_WIDE:
            {
              int res_is_new = 0;
              caddr_t err = NULL;
              caddr_t utf8_string = val;
              if (BF_UTF8 != box_flags(val) && (!cs || strcasecmp(cs, "UTF-8") || DV_WIDE == dtp))
                {
                  caddr_t copy = utf8_string =
                      charset_recode_from_named_to_named (val, DV_WIDE == dtp ? "_WIDE_" : cs, "UTF-8", &res_is_new, &err);
                  if (res_is_new)
                    {
                      utf8_string = t_box_copy(copy);
                      dk_free_box (copy);
                    }
                }
              ((carquet_byte_array_t *)batch)[n_vals].data = (uint8_t *)utf8_string;
              ((carquet_byte_array_t *)batch)[n_vals].length = box_length(utf8_string) - 1;
            }
          break;
      case DV_SINGLE_FLOAT:
          ((float*)batch)[n_vals] = unbox_float(val);
          break;
      case DV_NUMERIC:
            {
              double td = 0;
              numeric_to_double((numeric_t)(val), &td);
              ((double*)batch)[n_vals] = td;
            }
          break;
      case DV_DOUBLE_FLOAT:
          ((double*)batch)[n_vals] = unbox_double(val);
          break;
      case DV_DATETIME:
      case DV_TIMESTAMP:
          ((int64_t*)batch)[n_vals] = ((DT_CAST_TO_TOTAL_SECONDS(val) - SEC2EPOCH) * 1000);
          break;
      case DV_BIN:
          ((carquet_byte_array_t *)batch)[n_vals].data = (uint8_t *)val;
          ((carquet_byte_array_t *)batch)[n_vals].length = box_length(val);
          break;
      case DV_BLOB_HANDLE:
      case DV_BLOB_WIDE_HANDLE:
            {
              caddr_t to_free = blob_to_string (((query_instance_t*)qst)->qi_trx, val);
              val = t_box_copy(to_free);
              dk_free_box (to_free);

            }
      default:
          ((carquet_byte_array_t *)batch)[n_vals].data = (uint8_t *)val;
          ((carquet_byte_array_t *)batch)[n_vals].length = box_length(val) - 1;
          break;
    }
  return 1;
}

static caddr_t
bif_export_parquet_file (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  static char *me = "export_parquet_file";
  caddr_t **meta = (caddr_t **) bif_array_arg (qst, args, 0, me);
  caddr_t **data = (caddr_t **) bif_array_arg (qst, args, 1, me);
  caddr_t file_name = bif_string_arg (qst, args, 2, me);
  caddr_t cs = BOX_ELEMENTS(args) > 3 ? bif_string_or_null_arg(qst, args, 3, me) : NULL;
  int is_null = 0;
  carquet_compression_t compression = (carquet_compression_t) BOX_ELEMENTS(args) > 4 ?
      bif_long_or_null_arg (qst, args, 4, me, &is_null) : CARQUET_COMPRESSION_UNCOMPRESSED;
  carquet_error_t err = CARQUET_ERROR_INIT;
  carquet_status_t status;
  carquet_writer_t* writer = NULL;
  carquet_writer_options_t opts;
  int32_t icol, n_cols = BOX_ELEMENTS_0(meta), n_rows = BOX_ELEMENTS_0(data);
  int16_t *def_levels = NULL, has_nulls = 0;
  void * batch = NULL;

  if (!ARRAYP(meta) || !ARRAYP(data) || !n_cols)
    {
      err_ret[0] = srv_make_new_error ("22023", "PAR00", "Input must be non-empty metadata and result from exec()");
      goto err;
    }

  /* Schema */
  carquet_schema_t* schema = carquet_schema_create(&err);

  if (!schema) {
    err_ret[0] = fatal_error("Parquet schema creation", &err);
    goto err;
  }

  MP_START();
  for (icol = 0; icol < n_cols; icol ++)
    {
      if (!ARRAYP(meta[icol]) || BOX_ELEMENTS_0(meta[icol]) < 2)
        {
          err_ret[0] = srv_make_new_error ("22023", "PAR00", "Invalid metadata array");
          goto err;
        }
      status = parquet_schema_add_column(schema, meta[icol]);
      if (status != CARQUET_OK)
        {
          err_ret[0] = srv_make_new_error ("42000", "PAR01", "Can not add column %d", icol);
          goto err;
        }
    }

  /* Create file writer */
  carquet_writer_options_init(&opts);
  opts.created_by = "OpenLink Virtuoso";
  opts.compression = compression;

  writer = carquet_writer_create(file_name, schema, &opts, &err);
  if (!writer) {
    err_ret[0] = fatal_error("Parquet writer creation", &err);
    goto err;
  }

  def_levels = (int16_t*)t_alloc_box(n_rows * sizeof(int16_t), DV_CUSTOM);
  batch = (void *)t_alloc_box(n_rows * ALIGN_16(sizeof(carquet_byte_array_t)), DV_CUSTOM);
  has_nulls = 0;
  /* Add column data sequentially, nulls going to def_levels as 0, the values are consequtive */
  for (icol = 0; icol < n_cols; icol ++)
    {
      dtp_t dtp = unbox(meta[icol][1]);
      int irow, n_vals;
      memset (def_levels, 0x0, n_rows * sizeof(int16_t));
      n_vals = 0;
      for (irow = 0; irow < n_rows; irow ++)
        {
          caddr_t val;
          dtp_t val_dtp;
          if (!ARRAYP(data[irow]) || BOX_ELEMENTS_0(data[irow]) < icol)
            {
               err_ret[0] = srv_make_new_error ("22023", "PAR03", "Can not add column value at row %d, column %d", irow, icol);
               goto err;
            }
          val = data[irow][icol];
          if (parquet_batch_add_value (qst, batch, dtp, val, n_vals, cs, err_ret))
            {
              def_levels[irow] = 1;
              n_vals++;
            }
          else
            {
              def_levels[irow] = 0;
              has_nulls++;
            }
          if (*err_ret)
            goto err;
        }
      status = carquet_writer_write_batch(writer, icol, batch, n_rows, has_nulls ? def_levels : NULL, NULL);
      if (status != CARQUET_OK) {
        err_ret[0] = srv_make_new_error ("42000", "PAR02", "Can not write batch at column %d", icol);
        goto err;
      }
    }
  status = carquet_writer_close(writer);
  writer = NULL;
  if (status != CARQUET_OK) {
    err_ret[0] = srv_make_new_error ("42000", "PAR03", "Error closing file");
    goto err;
  }

err:
  if (writer) carquet_writer_abort(writer);
  carquet_schema_free(schema);
  MP_DONE();
  return NULL;
}

extern void sqls_define_delta_sharing (void);

void
virt_delta_sharing_postponed_action (char *mode)
{
  sqls_define_delta_sharing ();
}

static void
plain_plugin_connect (void *appdata)
{
  bif_define("export_parquet_file", bif_export_parquet_file);
  dk_set_push (get_srv_global_init_postponed_actions_ptr (), virt_delta_sharing_postponed_action);
}


static unit_version_t plugin_delta_sharing_version = {
  "Delta Sharing Protocol",			/*!< Title of unit, filled by unit */
  DBMS_SRV_GEN_MAJOR DBMS_SRV_GEN_MINOR,	/*!< Version number, filled by unit */
  "OpenLink Software",				/*!< Plugin's developer, filled by unit */
  "Delta Sharing plugin based on Carquet v" CARQUET_VERSION_STRING, 		/*!< Any additional info, filled by unit */
  0,						/*!< Error message, filled by unit loader */
  0,						/*!< Name of file with unit's code, filled by unit loader */
  plain_plugin_connect,				/*!< Pointer to connection function, cannot be 0 */
  0,						/*!< Pointer to disconnection function, or 0 */
  0,						/*!< Pointer to activation function, or 0 */
  0,						/*!< Pointer to deactivation function, or 0 */
  &_gate
};


unit_version_t *CALLBACK
delta_sharing_check (unit_version_t * in, void *appdata)
{
  return &plugin_delta_sharing_version;
}

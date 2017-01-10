/* -*- Mode: c; c-basic-offset: 2 -*-
 *
 * rdf_storage_virtuoso.c - RDF Storage in Virtuoso DBMS interface definition.
 *
 * $Id$
 *
 * Based in part on rdf_storage_virtuoso
 *
 * Copyright (C) 2000-2017 Openlink Software,  http://www.openlinksw.com/
 *
 * This package is Free Software and part of Redland http://librdf.org/
 *
 * It is licensed under the following three licenses as alternatives:
 *   1. GNU Lesser General Public License (LGPL) V2.1 or any newer version
 *   2. GNU General Public License (GPL) V2 or any newer version
 *   3. Apache License, V2.0 or any newer version
 *
 * You may not use this file except in compliance with at least one of
 * the above three licenses.
 *
 * See LICENSE.html or LICENSE.txt at the top of this package for the
 * complete terms and further detail along with the license texts for
 * the licenses in COPYING.LIB, COPYING and LICENSE-2.0.txt respectively.
 *
 *
 */

#ifdef HAVE_CONFIG_H
#include <rdf_config.h>
#endif

#ifdef WIN32
#include <win32_rdf_config.h>
#include <config-win.h>
#include <winsock.h>
#include <assert.h>
#endif

#include <stdio.h>
#include <string.h>
#ifdef HAVE_STDLIB_H
#include <stdlib.h> /* for abort() as used in errors */
#endif
#include <sys/types.h>

#include <redland.h>
#include <rdf_types.h>

/* Virtuoso specific */
#include <odbcinst.h>
/*#define VIRT_DEBUG 1*/

/******************** HASH ********************/

typedef struct _htentry
{
  short ht_key;
  char *ht_data;
  struct _htentry *ht_next;
} HTENTRY;

typedef struct _httable
{
  HTENTRY **ht_entries;
  int ht_size;
  int ht_noe;
  int ht_noc;
} HTTABLE;



static HTTABLE *htinit (int size);
static void     htfree (HTTABLE * table);
static int      hthash (HTTABLE * table, short data);
static HTENTRY *htlookup (HTTABLE * table, short data);
static char *	htgetdata (HTTABLE * table, short data);
static HTENTRY *htadd_hte (HTTABLE * table, HTENTRY *hte, short key, char *data);
static HTENTRY *htadd (HTTABLE * table, short key, char *data);


static HTTABLE *
htinit (int size)
{
  HTTABLE *ht;
  HTENTRY **hte;

  if (size < 1)
    size = 1;

  if (!(ht = calloc (1, sizeof (HTTABLE))))
    return NULL;
  if (!(hte = calloc (size, sizeof (HTENTRY *))))
    {
      free (ht);
      return NULL;
    }

  ht->ht_entries = hte;
  ht->ht_size = size;

  return ht;
}


static void
htfree (HTTABLE *table)
{
  register int i;
  HTENTRY *hte, *temp;

  for (i = 0; i < table->ht_size; i++)
    {
      hte = table->ht_entries[i];
      while (hte != NULL)
	{
	  temp = hte;
	  hte = hte->ht_next;
	  LIBRDF_FREE(cstring,(char *)temp->ht_data);
          /*free (temp->ht_data);*/
	  free ((char *) temp);
	}
    }

  free (table->ht_entries);
  free (table);
}


#define rotl(x) (x && (1 << (8*sizeof(x)-1)) ? (x << 1) & 1 : x << 1)

static int
hthash (HTTABLE *table, short data)
{
  int total = 0;
  int c;
  int i;
  char *s = (char *)&data;

  for (total = i = 0; i < sizeof(short); i++, s++)
    {
      total ^= *s * 23;
      total = rotl (total);
    }

  return total % table->ht_size;
}


static HTENTRY *
htlookup (HTTABLE *table, short data)
{
  HTENTRY *hte;
  int offset;

  if ((offset = hthash (table, data)) < 0)
    return NULL;

  hte = table->ht_entries[offset];

  if (hte == NULL)
    return NULL;

  while (hte != NULL)
    {
      if (hte->ht_key == data)
        return hte;
      hte = hte->ht_next;
    }

  return NULL;
}


static char *
htgetdata (HTTABLE * table, short data)
{
  HTENTRY *hte;

  if ((hte = htlookup (table, data)) == NULL)
    return NULL;
  else
    return hte->ht_data;
}


static HTENTRY *
htadd_hte (HTTABLE *table, HTENTRY *hte, short key, char *data)
{
  int value = hthash (table, key);

  /* add hte to table */
  hte->ht_key = key;
  hte->ht_data = data;
  hte->ht_next = table->ht_entries[value];
  table->ht_entries[value] = hte;

  /* update stats */
  table->ht_noe++;
  if (hte->ht_next != NULL)
    table->ht_noc++;

  return hte;
}


static HTENTRY *
htadd (HTTABLE *table, short key, char *data)
{
  HTENTRY *hte = htlookup (table, key);
  char *str_copy;

  if (hte == NULL)
    {
      /* not found in the table */
      if (!(hte = calloc (1, sizeof (HTENTRY))))
	return NULL;

      return htadd_hte (table, hte, key, data);
    }
  else
    {
      /* update the previous data item by the current one */
      hte->ht_data = data;
      return hte;
    }
}


/******************* Virtuoso defines *******************/

#define DV_LONG_INT 189

#define DV_STRING 182
#define DV_RDF 246		/*!< RDF object that is SQL value + type id + language id + outline id + flag whether the sql value is full */

#define DV_LONG_INT 189
#define DV_SINGLE_FLOAT 190
#define DV_DOUBLE_FLOAT 191
#define DV_NUMERIC 219
#define DV_DATETIME 211
#define DV_IRI_ID 243
#define DV_TIMESTAMP 128
#define DV_TIMESTAMP_OBJ 208
#define DV_DATE  129
#define DV_TIME  210


#define DT_TYPE_DATETIME 1
#define DT_TYPE_DATE 2
#define DT_TYPE_TIME 3


#define SQL_DESC_COL_DV_TYPE		1057L
#define SQL_DESC_COL_DT_DT_TYPE		1058L
#define SQL_DESC_COL_LITERAL_ATTR	1059L
#define SQL_DESC_COL_BOX_FLAGS		1060L

/******************************************************************/



typedef enum {
  VIRTUOSO_CONNECTION_CLOSED = 0,
  VIRTUOSO_CONNECTION_OPEN = 1,
  VIRTUOSO_CONNECTION_BUSY = 2
} librdf_storage_virtuoso_connection_status;



typedef struct {
   /* A ODBC connection */
   librdf_storage_virtuoso_connection_status status;
   HENV henv;
   HDBC hdbc;
   HSTMT hstmt;
   short numCols;

  HTTABLE *h_lang;
  HTTABLE *h_type;
} librdf_storage_virtuoso_connection;

typedef struct {
  /* Virtuoso connection parameters */
  librdf_storage *storage;
  librdf_node *current;

  librdf_storage_virtuoso_connection *connections;
  int connections_count;

  char *model_name;
  char *user;
  char *password;
  char *dsn;
  char *host;
  char *database;
  char *conn_str;

  /* if inserts should be optimized by locking and index optimizations */
  int bulk;
  int merge;

  HTTABLE *h_lang;
  HTTABLE *h_type;

  librdf_world *world;

  librdf_storage_virtuoso_connection *transaction_handle;

} librdf_storage_virtuoso_context;

typedef struct {
  librdf_storage *storage;
  librdf_statement *current_statement;
  librdf_statement *query_statement;
  librdf_storage_virtuoso_connection *handle;

  librdf_node *query_context;
  librdf_node *current_context;

} librdf_storage_virtuoso_sos_context;


typedef struct {
  librdf_storage *storage;
  librdf_node *current_context;
  librdf_storage_virtuoso_connection *handle;

} librdf_storage_virtuoso_get_contexts_context;


static int librdf_storage_virtuoso_init(librdf_storage* storage, const char *name,
                                     librdf_hash* options);

static void librdf_storage_virtuoso_terminate(librdf_storage* storage);
static int librdf_storage_virtuoso_open(librdf_storage* storage,
                                     librdf_model* model);
static int librdf_storage_virtuoso_close(librdf_storage* storage);
static int librdf_storage_virtuoso_sync(librdf_storage* storage);
static int librdf_storage_virtuoso_size(librdf_storage* storage);
static int librdf_storage_virtuoso_add_statement(librdf_storage* storage,
                                              librdf_statement* statement);
static int librdf_storage_virtuoso_add_statements(librdf_storage* storage,
                                               librdf_stream* statement_stream);
static int librdf_storage_virtuoso_remove_statement(librdf_storage* storage,
                                                 librdf_statement* statement);
static int librdf_storage_virtuoso_contains_statement(librdf_storage* storage,
                                                   librdf_statement* statement);
static int librdf_storage_virtuoso_context_contains_statement(librdf_storage* storage,
					           librdf_node* context_node,
                                                   librdf_statement* statement);
static int librdf_storage_virtuoso_start_bulk(librdf_storage* storage);
static int librdf_storage_virtuoso_stop_bulk(librdf_storage* storage);

static librdf_stream* librdf_storage_virtuoso_serialise(librdf_storage* storage);
static librdf_stream* librdf_storage_virtuoso_find_statements(librdf_storage* storage,
                                            librdf_statement* statement);
static librdf_stream* librdf_storage_virtuoso_find_statements_with_options(librdf_storage* storage,
                                                         librdf_statement* statement,
                                                         librdf_node* context_node,
                                                         librdf_hash* options);

/* context functions */
static int librdf_storage_virtuoso_context_add_statement(librdf_storage* storage,
                                                      librdf_node* context_node,
                                                      librdf_statement* statement);
static int librdf_storage_virtuoso_context_add_statements(librdf_storage* storage,
                                                       librdf_node* context_node,
                                                       librdf_stream* statement_stream);
static int librdf_storage_virtuoso_context_remove_statement(librdf_storage* storage,
                                                         librdf_node* context_node,
                                                         librdf_statement* statement);
static int librdf_storage_virtuoso_context_remove_statements(librdf_storage* storage,
                                                          librdf_node* context_node);
static librdf_stream* librdf_storage_virtuoso_context_serialise(librdf_storage* storage,
                                              librdf_node* context_node);
static librdf_stream* librdf_storage_virtuoso_find_statements_in_context(librdf_storage* storage,
                                               librdf_statement* statement,
                                               librdf_node* context_node);
static librdf_iterator* librdf_storage_virtuoso_get_contexts(librdf_storage* storage);

static void librdf_storage_virtuoso_register_factory(librdf_storage_factory *factory);

static librdf_node* librdf_storage_virtuoso_get_feature(librdf_storage* storage, librdf_uri* feature);

static int librdf_storage_virtuoso_transaction_start(librdf_storage* storage);

static int librdf_storage_virtuoso_transaction_start_with_handle(librdf_storage* storage,
                                                   void* handle);
static int librdf_storage_virtuoso_transaction_commit(librdf_storage* storage);

static int librdf_storage_virtuoso_transaction_rollback(librdf_storage* storage);

static void* librdf_storage_virtuoso_transaction_get_handle(librdf_storage* storage);

static int rdf_virtuoso_ODBC_Errors (char *where, librdf_world *world, librdf_storage_virtuoso_connection *handle);
static int librdf_storage_virtuoso_add_statement_helper(librdf_storage* storage,
                                          librdf_statement* statement);
static int librdf_storage_virtuoso_context_add_statement_helper(librdf_storage* storage,
					  librdf_node* context_node,
                                          librdf_statement* statement);


static int
rdf_virtuoso_ODBC_Errors (char *where, librdf_world *world, 
	librdf_storage_virtuoso_connection* handle)
{
  SQLCHAR buf[512];
  SQLCHAR sqlstate[15];

  while (SQLError (handle->henv, handle->hdbc, handle->hstmt, sqlstate, NULL,
	buf, sizeof(buf), NULL) == SQL_SUCCESS)
    {
#ifdef VIRT_DEBUG
      fprintf (stderr, "%s ||%s, SQLSTATE=%s\n", where, buf, sqlstate);
#endif
      librdf_log(world, 0, LIBRDF_LOG_ERROR, LIBRDF_FROM_STORAGE, NULL,
               "Virtuoso %s failed [%s] %s", where, sqlstate, buf);
    }

  while (SQLError (handle->henv, handle->hdbc, SQL_NULL_HSTMT, sqlstate, NULL,
	buf, sizeof(buf), NULL) == SQL_SUCCESS)
    {
#ifdef VIRT_DEBUG
      fprintf (stderr, "%s ||%s, SQLSTATE=%s\n", where, buf, sqlstate);
#endif
      librdf_log(world, 0, LIBRDF_LOG_ERROR, LIBRDF_FROM_STORAGE, NULL,
               "Virtuoso %s failed [%s] %s", where, sqlstate, buf);
    }

  while (SQLError (handle->henv, SQL_NULL_HDBC, SQL_NULL_HSTMT, sqlstate, NULL,
	buf, sizeof(buf), NULL) == SQL_SUCCESS)
    {
#ifdef VIRT_DEBUG
      fprintf (stderr, "%s ||%s, SQLSTATE=%s\n", where, buf, sqlstate);
#endif
      librdf_log(world, 0, LIBRDF_LOG_ERROR, LIBRDF_FROM_STORAGE, NULL,
               "Virtuoso %s failed [%s] %s", where, sqlstate, buf);
    }

  return -1;
}


static char *
vGetDataCHAR(librdf_world *world, librdf_storage_virtuoso_connection *handle, 
	short col, int *is_null)
{
  int rc;
  SQLLEN len;
  char *data = NULL;
  SQLCHAR buf[255];

  *is_null = 0;

  rc = SQLGetData(handle->hstmt, col, SQL_C_CHAR, buf, 0, &len);
  if (!SQL_SUCCEEDED(rc))
    {
      rdf_virtuoso_ODBC_Errors("SQLGetData()", world, handle);
      return NULL;
    }
  if (len == SQL_NULL_DATA)
    {
      *is_null = 1;
      return NULL;
    }
  else
    {
      char *pLongData = NULL;
      SQLLEN bufsize = len + 4;

      pLongData = (char*)LIBRDF_MALLOC(cstring, bufsize);
      if (pLongData == NULL)
        {
          librdf_log(world, 0, LIBRDF_LOG_ERROR, LIBRDF_FROM_STORAGE, NULL,
               "Not enough memory to allocate resultset element");
	  return NULL;
        }

      if (len == 0)
        pLongData[0] = '\0';
      else
        {
          rc = SQLGetData(handle->hstmt, col, SQL_C_CHAR, pLongData, bufsize, &len);
          if (!SQL_SUCCEEDED(rc))
            {
              rdf_virtuoso_ODBC_Errors("SQLGetData()", world, handle);
              return NULL;
            }
        }
      return pLongData;
    }
}


static int
vGetDataINT(librdf_world *world, librdf_storage_virtuoso_connection *handle, 
	short col, int *is_null, int *val)
{
  int rc;
  SQLLEN len;

  *is_null = 0;

  rc = SQLGetData(handle->hstmt, col, SQL_C_LONG, val, 0, &len);
  if (!SQL_SUCCEEDED(rc))
    {
      rdf_virtuoso_ODBC_Errors("SQLGetData()", world, handle);
      return -1;
    }
  if (len == SQL_NULL_DATA)
    {
      *is_null = 1;
      return 0;
    }

  return 0;
}


static char*
rdf_lang2string(librdf_world *world, librdf_storage_virtuoso_connection *handle,
		short key)
{
  char *val = htgetdata(handle->h_lang, key);
  char query[]="select RL_ID from DB.DBA.RDF_LANGUAGE where RL_TWOBYTE=?";
  int rc;
  HSTMT hstmt;
  SQLINTEGER m_ind = 0;

  if (val)
    return val;

  hstmt = handle->hstmt;

  rc = SQLAllocHandle (SQL_HANDLE_STMT, handle->hdbc, &handle->hstmt);
  if (!SQL_SUCCEEDED(rc))
    {
      rdf_virtuoso_ODBC_Errors("SQLAllocHandle(hstmt)", world, handle);
      handle->hstmt = hstmt;
      return NULL;
    }

  rc = SQLBindParameter (handle->hstmt, 1, SQL_PARAM_INPUT, SQL_C_SSHORT, 
        SQL_SMALLINT, 0, 0, &key, 0, &m_ind);
  if (!SQL_SUCCEEDED(rc))
    {
      rdf_virtuoso_ODBC_Errors("SQLBindParameter()", world, handle);
      goto end;
    }

  rc = SQLExecDirect(handle->hstmt, (UCHAR *) query, SQL_NTS);
  if (!SQL_SUCCEEDED(rc))
    {
      rdf_virtuoso_ODBC_Errors("SQLExecDirect()", world, handle);
      goto end;
    }

  rc = SQLFetch(handle->hstmt);
  if (SQL_SUCCEEDED(rc))
    {
      
      int is_null;
      val = vGetDataCHAR(world, handle, 1, &is_null);
      if (!val || is_null)
          goto end;
      htadd(handle->h_lang, key, val);
    }

end:

  SQLCloseCursor(handle->hstmt);
  SQLFreeHandle (SQL_HANDLE_STMT, handle->hstmt);
  handle->hstmt = hstmt;

  return val;
}


static char*
rdf_type2string(librdf_world *world, librdf_storage_virtuoso_connection *handle,
		short key)
{
  char *val = htgetdata(handle->h_type, key);
  char query[]="select RDT_QNAME from DB.DBA.RDF_DATATYPE where RDT_TWOBYTE=?";
  int rc;
  HSTMT hstmt;
  SQLINTEGER m_ind = 0;

  if (val)
    return val;

  hstmt = handle->hstmt;

  rc = SQLAllocHandle (SQL_HANDLE_STMT, handle->hdbc, &handle->hstmt);
  if (!SQL_SUCCEEDED(rc))
    {
      rdf_virtuoso_ODBC_Errors("SQLAllocHandle(hstmt)", world, handle);
      handle->hstmt = hstmt;
      return NULL;
    }

  rc = SQLBindParameter (handle->hstmt, 1, SQL_PARAM_INPUT, SQL_C_SSHORT, 
        SQL_SMALLINT, 0, 0, &key, 0, &m_ind);
  if (!SQL_SUCCEEDED(rc))
    {
      rdf_virtuoso_ODBC_Errors("SQLBindParameter()", world, handle);
      goto end;
    }

  rc = SQLExecDirect(handle->hstmt, (UCHAR *) query, SQL_NTS);
  if (!SQL_SUCCEEDED(rc))
    {
      rdf_virtuoso_ODBC_Errors("SQLExecDirect()", world, handle);
      goto end;
    }

  rc = SQLFetch(handle->hstmt);
  if (SQL_SUCCEEDED(rc))
    {
      
      int is_null;
      val = vGetDataCHAR(world, handle, 1, &is_null);
      if (!val || is_null)
          goto end;
      htadd(handle->h_type, key, val);
    }

end:

  SQLCloseCursor(handle->hstmt);
  SQLFreeHandle (SQL_HANDLE_STMT, handle->hstmt);
  handle->hstmt = hstmt;

  return val;
}



static librdf_node *
rdf2node(librdf_storage *storage, librdf_storage_virtuoso_connection *handle, 
	 short col, char *data)
{
  librdf_node *node = NULL;
  short l_lang, l_type;
  SQLHDESC hdesc = NULL;
  librdf_uri *u_type = NULL;
  int dvtype = 0;
  int dv_dt_type = 0;
  int flag = 0;
  int rc;

  rc = SQLGetStmtAttr(handle->hstmt, SQL_ATTR_IMP_ROW_DESC, &hdesc, SQL_IS_POINTER, NULL);
  if (!SQL_SUCCEEDED(rc))
      return NULL;
  rc = SQLGetDescField(hdesc, col, SQL_DESC_COL_DV_TYPE, &dvtype, SQL_IS_INTEGER, NULL);
  if (!SQL_SUCCEEDED(rc))
     return NULL;
  rc = SQLGetDescField(hdesc, col, SQL_DESC_COL_DT_DT_TYPE, &dv_dt_type, SQL_IS_INTEGER, NULL);
  if (!SQL_SUCCEEDED(rc))
     return NULL;
  rc = SQLGetDescField(hdesc, col, SQL_DESC_COL_LITERAL_ATTR, &flag, SQL_IS_INTEGER, NULL);
  if (!SQL_SUCCEEDED(rc))
     return NULL;
  l_lang =(short)((flag >> 16) & 0xFFFF);
  l_type =(short)(flag & 0xFFFF);
  rc = SQLGetDescField(hdesc, col, SQL_DESC_COL_BOX_FLAGS, &flag, SQL_IS_INTEGER, NULL);
  if (!SQL_SUCCEEDED(rc))
     return NULL;

  switch (dvtype)
    {
      case DV_STRING:
	    {
	      if (flag)
	        {
	          if (strncmp((char*)data, "_:",2)==0)
	            {
                      node = librdf_new_node_from_blank_identifier(storage->world,
                                        (const unsigned char*)data+2);
	            }
	          else
	            {
                      node = librdf_new_node_from_uri_string(storage->world,
                                        (const unsigned char*)data);
	            }
		}
	      else
	        {
	          if (strncmp((char*)data, "nodeID://",9)==0)
	            {
                      node = librdf_new_node_from_blank_identifier(storage->world,
                                        (const unsigned char*)data+9);
	            }
	          else
	            {
                      node = librdf_new_node_from_literal(storage->world, 
                                        (const unsigned char *)data, NULL, 0); 
	            }
		}
	      break;
	    }
      case DV_RDF:
	    {
              char *s_type = rdf_type2string(storage->world, handle, l_type);
              char *s_lang = rdf_lang2string(storage->world, handle, l_lang);

              if (s_type)
                u_type = librdf_new_uri(storage->world, (unsigned char *)s_type);

              node = librdf_new_node_from_typed_literal(storage->world, 
                         (const unsigned char *)data, s_lang, u_type); 
	      break;
        }
            case DV_LONG_INT: /* integer */
              u_type = librdf_new_uri(storage->world, 
              	   (unsigned char *)"http://www.w3.org/2001/XMLSchema#integer");

              node = librdf_new_node_from_typed_literal(storage->world, 
                         (const unsigned char *)data, NULL, u_type); 
              break;

            case DV_SINGLE_FLOAT: /* float */
              u_type = librdf_new_uri(storage->world,
              	   (unsigned char *)"http://www.w3.org/2001/XMLSchema#float");

              node = librdf_new_node_from_typed_literal(storage->world, 
                             (const unsigned char *)data, NULL, u_type); 
              break;

            case DV_DOUBLE_FLOAT: /* double */
              u_type = librdf_new_uri(storage->world,
              	   (unsigned char *)"http://www.w3.org/2001/XMLSchema#double");

              node = librdf_new_node_from_typed_literal(storage->world, 
                         (const unsigned char *)data, NULL, u_type); 
              break;

            case DV_NUMERIC: /* decimal */
              u_type = librdf_new_uri(storage->world,
              	   (unsigned char *)"http://www.w3.org/2001/XMLSchema#decimal");

              node = librdf_new_node_from_typed_literal(storage->world, 
                             (const unsigned char *)data, NULL, u_type); 
              break;

            case DV_TIMESTAMP: /* datetime */
      case DV_DATE: 
      case DV_TIME: 
            case DV_DATETIME: 
          switch(dv_dt_type)
            {
            case DT_TYPE_DATE:
              u_type = librdf_new_uri(storage->world,
              	   (unsigned char *)"http://www.w3.org/2001/XMLSchema#date");
              break;
            case DT_TYPE_TIME:
              u_type = librdf_new_uri(storage->world,
              	   (unsigned char *)"http://www.w3.org/2001/XMLSchema#time");
              break;
	    default:
                u_type = librdf_new_uri(storage->world,
          	     (unsigned char *)"http://www.w3.org/2001/XMLSchema#dateTime");
              break;
            }
          node = librdf_new_node_from_typed_literal(storage->world, 
                         (const unsigned char *)data, NULL, u_type); 
          break;
      case DV_IRI_ID:
          node = librdf_new_node_from_literal(storage->world, 
                             (const unsigned char *)data, NULL, 0); 
          break;
      default:
	  return NULL; /***printf ("*unexpected result type %d*", dtp);***/
    }

  return node;
}


static char *
librdf_storage_virtuoso_str_esc (const char *raw, size_t raw_len, size_t *len_p)
{
  int escapes=0;
  unsigned char *p;
  unsigned char *escaped;
  int len;

  for(p=(unsigned char*)raw, len=(int)raw_len; len>0; p++, len--) {
    if(*p == '\'')
      escapes++;
  }

  len= raw_len+escapes+2; /* for '' */
  escaped=(unsigned char*)LIBRDF_MALLOC(cstring, len+1);

  p=escaped;
  *p++='\'';
  while(raw_len > 0) {
    if(*raw == '\'') {
      *p++='\'';
    }
    *p++=*raw++;
    raw_len--;
  }
  *p++='\'';
  *p='\0';

  if(len_p)
    *len_p=len;

  return (char *)escaped;
}


static char *
librdf_storage_virtuoso_node2string(librdf_storage *storage,
                                     librdf_node *node)
{
  librdf_node_type type = librdf_node_get_type(node);
  size_t nodelen;
  char *ret = NULL;

  if(type==LIBRDF_NODE_TYPE_RESOURCE) {
    /* Get hash */
    char *uri=(char *)librdf_uri_as_counted_string(librdf_node_get_uri(node), &nodelen);

    if(!(ret=(char*)LIBRDF_MALLOC(cstring, nodelen+3)))
      goto end;

    strcpy(ret, "<");
    strcat(ret, uri);
    strcat(ret, ">");

  } else if(type==LIBRDF_NODE_TYPE_LITERAL) {
    /* Get hash */
    char *value, *datatype=0;
    char *lang;
    librdf_uri *dt;
    size_t valuelen, langlen=0, datatypelen=0;

    value=(char *)librdf_node_get_literal_value_as_counted_string(node,&valuelen);
    lang=librdf_node_get_literal_value_language(node);
    if(lang)
      langlen=strlen(lang);
    dt=librdf_node_get_literal_value_datatype_uri(node);
    if(dt)
      datatype=(char *)librdf_uri_as_counted_string(dt,&datatypelen);
    if(datatype)
      datatypelen=strlen((const char*)datatype);

    /* Create composite node string for hash generation */
    if(!(ret=(char*)LIBRDF_MALLOC(cstring, valuelen+langlen+datatypelen+8)))
      goto end;

    strcpy(ret, "\"");
    strcat(ret, (const char*)value);
    strcat(ret, "\"");
    if (lang && strlen(lang))
      {
        strcat(ret, "@");
        strcat(ret, lang);
      }
    if(datatype)
      {
        strcat(ret, "^^<");
        strcat(ret, (const char*)datatype);
        strcat(ret, ">");
      }

  } else if(type==LIBRDF_NODE_TYPE_BLANK) {
    char *value = (char *)librdf_node_get_blank_identifier(node);

    if(!(ret=(char*)LIBRDF_MALLOC(cstring, strlen(value)+5)))
      goto end;

#if 1
    strcpy(ret, "<_:");
    strcat(ret, value);
    strcat(ret, ">");
#else
    strcpy(ret, "_:");
    strcat(ret, value);
#endif
  }

end:
  return ret;
}


static char *
librdf_storage_virtuoso_context2string(librdf_storage *storage,
                                     librdf_node *node)
{
  librdf_storage_virtuoso_context* context=(librdf_storage_virtuoso_context*)storage->context;
  char *ctxt_node = NULL;

  if (node)
    ctxt_node=librdf_storage_virtuoso_node2string(storage, node);
  else
    {
      if(!(ctxt_node=(char*)LIBRDF_MALLOC(cstring, strlen(context->model_name)+
  			4))) 
  	{
          return NULL;
        }
      sprintf(ctxt_node, "<%s>", context->model_name);
    }
  return ctxt_node;
}



static char *
librdf_storage_virtuoso_fcontext2string(librdf_storage *storage,
                                     librdf_node *node)
{
  librdf_storage_virtuoso_context* context=(librdf_storage_virtuoso_context*)storage->context;
  char *ctxt_node = NULL;

  if (node)
    ctxt_node=librdf_storage_virtuoso_node2string(storage, node);
  else
    {
      if(!(ctxt_node=(char*)LIBRDF_MALLOC(cstring, 5))) 
  	{
          return NULL;
        }
      strcpy(ctxt_node, "<?g>");
    }
  return ctxt_node;
}



/*
 * librdf_storage_virtuoso_init_connections - Initialize Virtuoso connection pool.
 * @storage: the storage
 *
 * Return value: Non-zero on success.
 **/
static int
librdf_storage_virtuoso_init_connections(librdf_storage* storage)
{
  librdf_storage_virtuoso_context* context=(librdf_storage_virtuoso_context*)storage->context;

#ifdef VIRT_DEBUG
  fprintf(stderr, "librdf_storage_virtuoso_init_connections \n");
#endif
  /* Reset connection pool */
  context->connections=NULL;
  context->connections_count=0;
  return 1;
}


/*
 * librdf_storage_virtuoso_finish_connections - Finish all connections in Virtuoso connection pool and free structures.
 * @storage: the storage
 *
 * Return value: None.
 **/
static void
librdf_storage_virtuoso_finish_connections(librdf_storage* storage)
{
  librdf_storage_virtuoso_context* context=(librdf_storage_virtuoso_context*)storage->context;
  librdf_storage_virtuoso_connection *handle;
  int i;

#ifdef VIRT_DEBUG
  fprintf(stderr, "librdf_storage_virtuoso_finish_connections \n");
#endif
  /* Loop through connections and close */
  for(i=0; i < context->connections_count; i++) 
    {
      if (VIRTUOSO_CONNECTION_CLOSED != context->connections[i].status) 
        {
#ifdef LIBRDF_DEBUG_SQL
          LIBRDF_DEBUG2("virtuoso_close connection handle %p\n",
                    context->connections[i].handle);
#endif
          handle = &context->connections[i];
          if (handle->hstmt) {
            SQLCloseCursor (handle->hstmt);
            SQLFreeHandle (SQL_HANDLE_STMT, handle->hstmt);
          }

          if (handle->hdbc) {
            SQLDisconnect(handle->hdbc);
            SQLFreeHandle(SQL_HANDLE_DBC, handle->hdbc);
          }

          if (handle->henv) {
            SQLFreeHandle(SQL_HANDLE_ENV, handle->henv);
          }
        }
    }
  /* Free structure and reset */
  if (context->connections_count) {
    LIBRDF_FREE(librdf_storage_virtuoso_connection*, context->connections);
    context->connections=NULL;
    context->connections_count=0;
  }
}


/*
 * librdf_storage_virtuoso_get_handle - get a connection handle to the Virtuoso server
 * @storage: the storage
 *
 * This attempts to reuses any existing available pooled connection
 * otherwise creates a new connection to the server.
 *
 * Return value: Non-zero on succes.
 **/
static librdf_storage_virtuoso_connection *
librdf_storage_virtuoso_get_handle(librdf_storage* storage)
{
  librdf_storage_virtuoso_context* context=(librdf_storage_virtuoso_context*)storage->context;
  librdf_storage_virtuoso_connection* connection= NULL;
  int i;
  int rc;
  short buflen;
  char outdsn[4096];

#ifdef VIRT_DEBUG
  fprintf(stderr, "librdf_storage_virtuoso_connection \n");
#endif
  if(context->transaction_handle)
    return context->transaction_handle;

  /* Look for an open connection handle to return */
  for(i=0; i < context->connections_count; i++) {
    if(VIRTUOSO_CONNECTION_OPEN == context->connections[i].status) {
      context->connections[i].status=VIRTUOSO_CONNECTION_BUSY;
      return &context->connections[i];
    }
  }

  /* Look for a closed connection */
  for(i=0; i < context->connections_count && !connection; i++) {
    if(VIRTUOSO_CONNECTION_CLOSED == context->connections[i].status) {
      connection=&context->connections[i];
      break;
    }
  }
  /* Expand connection pool if no closed connection was found */
  if (!connection) {
    /* Allocate new buffer with two extra slots */
    librdf_storage_virtuoso_connection* connections;
    if(!(connections=(librdf_storage_virtuoso_connection*)
        LIBRDF_CALLOC(librdf_storage_virtuoso_connection,
                      context->connections_count+2,
                      sizeof(librdf_storage_virtuoso_connection))))
      return NULL;

    if (context->connections_count) {
      /* Copy old buffer to new */
      memcpy(connections, context->connections, sizeof(librdf_storage_virtuoso_connection)*context->connections_count);
      /* Free old buffer */
      LIBRDF_FREE(librdf_storage_virtuoso_connection*, context->connections);
    }

    /* Update buffer size and reset new connections */
    context->connections_count+=2;
    connection=&connections[context->connections_count-2];
    connection->status=VIRTUOSO_CONNECTION_CLOSED;
    connection->henv=NULL;
    connection->hdbc=NULL;
    connection->hstmt=NULL;
    connections[context->connections_count-1].status=VIRTUOSO_CONNECTION_CLOSED;
    connections[context->connections_count-1].henv=NULL;
    connections[context->connections_count-1].hdbc=NULL;
    connections[context->connections_count-1].hstmt=NULL;
    context->connections=connections;
  }

  /* Initialize closed Virtuoso connection handle */
  rc = SQLAllocHandle (SQL_HANDLE_ENV, NULL, &connection->henv);
  if (!SQL_SUCCEEDED(rc))
    {
      rdf_virtuoso_ODBC_Errors("SQLAllocHandle(henv)", storage->world, connection);
      goto end;
    }

  SQLSetEnvAttr (connection->henv, SQL_ATTR_ODBC_VERSION, (SQLPOINTER) SQL_OV_ODBC3,
      SQL_IS_UINTEGER);

  rc = SQLAllocHandle (SQL_HANDLE_DBC, connection->henv, &connection->hdbc);
  if (!SQL_SUCCEEDED(rc))
    {
      rdf_virtuoso_ODBC_Errors("SQLAllocHandle(hdbc)", storage->world, connection);
      goto end;
    }

#if 0
  rc = SQLConnect (connection->hdbc, (UCHAR *) context->dsn, SQL_NTS, 
  	(UCHAR *) context->user, SQL_NTS, (UCHAR *) context->password, SQL_NTS);
#else
  rc = SQLDriverConnect(connection->hdbc, 0, (UCHAR *) context->conn_str, SQL_NTS,
  	(UCHAR *) outdsn, sizeof(outdsn), &buflen, SQL_DRIVER_COMPLETE);
#endif
  if (!SQL_SUCCEEDED(rc))
    {
      rdf_virtuoso_ODBC_Errors("SQLConnect()", storage->world, connection);
      goto end;
    }


  rc = SQLAllocHandle (SQL_HANDLE_STMT, connection->hdbc, &connection->hstmt);
  if (!SQL_SUCCEEDED(rc))
    {
      rdf_virtuoso_ODBC_Errors("SQLAllocHandle(hstmt)", storage->world, connection);
      goto end;
    }


  /* Update status and return */
  connection->h_lang = context->h_lang;
  connection->h_type = context->h_type;
  connection->status=VIRTUOSO_CONNECTION_BUSY;
  return connection;

end:
  if (connection->hstmt) {
    SQLFreeHandle (SQL_HANDLE_STMT, connection->hstmt);
    connection->hstmt = NULL;
  }

  if (connection->hdbc) {
    SQLDisconnect(connection->hdbc);
    SQLFreeHandle(SQL_HANDLE_DBC, connection->hdbc);
    connection->hdbc = NULL;
  }

  if (connection->henv) {
    SQLFreeHandle(SQL_HANDLE_ENV, connection->henv);
    connection->henv = NULL;
  }

  return NULL;
}


/*
 * librdf_storage_virtuoso_release_handle - Release a connection handle to Virtuoso server back to the pool
 * @storage: the storage
 * @handle: the Viruoso handle to release
 *
 * Return value: None.
 **/
static void
librdf_storage_virtuoso_release_handle(librdf_storage* storage, librdf_storage_virtuoso_connection *handle)
{
  librdf_storage_virtuoso_context* context=(librdf_storage_virtuoso_context*)storage->context;
  int i;

  if(handle == context->transaction_handle)
    return;
  
  /* Look for busy connection handle to drop */
  for(i=0; i < context->connections_count; i++) {
    if(VIRTUOSO_CONNECTION_BUSY == context->connections[i].status &&
       &context->connections[i] == handle) {
      context->connections[i].status=VIRTUOSO_CONNECTION_OPEN;
      return;
    }
  }

  librdf_log(storage->world, 0, LIBRDF_LOG_ERROR, LIBRDF_FROM_STORAGE, NULL,
             "Unable to find busy connection (in pool of %i connections)",
             context->connections_count);
}



/**
 * librdf_storage_virtuoso_init:
 * @storage: the storage
 * @name: model name
 * @options:  dsn, user, password, host, database, [bulk].
 *
 * .
 *
 * Create connection to database. 
 *
 * The boolean bulk option can be set to true if optimized inserts (table
 * locks and temporary key disabling) is wanted. Note that this will block
 * all other access, and requires table locking and alter table privileges.
 *
 * Return value: Non-zero on failure.
 **/
static int 
librdf_storage_virtuoso_init(librdf_storage* storage, const char *name,
                                     librdf_hash* options)
{
  int rc;
  librdf_storage_virtuoso_context* context=(librdf_storage_virtuoso_context*)storage->context;
  int len = 0;

  /* Must have connection parameters passed as options */
  if(!options)
    return 1;

#ifdef VIRT_DEBUG
  fprintf(stderr, "librdf_storage_virtuoso_init \n");
#endif

  context->connections=NULL;
  context->connections_count=0;
  context->storage=storage;
  context->password=librdf_hash_get_del(options, "password");
  context->user=librdf_hash_get_del(options, "user");
  context->dsn=librdf_hash_get_del(options, "dsn");
  context->host=librdf_hash_get_del(options, "host");
  context->database=librdf_hash_get_del(options, "database");

  if ((context->h_lang = htinit (100)) == NULL)
    return 1;

  if ((context->h_type = htinit (100)) == NULL)
    {
      htfree(context->h_lang);
      return 1;
    }

  if (!name)
    name = "virt:DEFAULT";

  if (context->password)
    len += (strlen(context->password) + strlen("PWD=;"));
  if (context->user)
    len += (strlen(context->user) + strlen("UID=;"));
  if (context->dsn)
    len += (strlen(context->dsn) + strlen("DSN=;"));
  if (context->host)
    len += (strlen(context->host) + strlen("HOST=;"));
  if (context->database)
    len += (strlen(context->database) + strlen("DATABASE=;"));

  if(!(context->conn_str=(char*)LIBRDF_MALLOC(cstring, len+16)))
    return 1;

  if(!(context->model_name=(char*)LIBRDF_MALLOC(cstring, strlen(name))))
    return 1;
  strcpy(context->model_name, name);

  /* Optimize loads? */
  context->bulk=(librdf_hash_get_as_boolean(options, "bulk")>0);

  /* Truncate model? */
#if 0
//??  if(!status && (librdf_hash_get_as_boolean(options, "new")>0))
//??    status=librdf_storage_virtuoso_context_remove_statements(storage, NULL);
#endif

  if(!context->model_name || !context->dsn || !context->user || !context->password)
    return 1;

  strcpy(context->conn_str, "");
  if (context->dsn) {
    strcat(context->conn_str, "DSN=");
    strcat(context->conn_str, context->dsn);
    strcat(context->conn_str, ";");
  }
  if (context->host) {
    strcat(context->conn_str, "HOST=");
    strcat(context->conn_str, context->host);
    strcat(context->conn_str, ";");
  }
  if (context->database) {
    strcat(context->conn_str, "DATABASE=");
    strcat(context->conn_str, context->database);
    strcat(context->conn_str, ";");
  }
  if (context->user) {
    strcat(context->conn_str, "UID=");
    strcat(context->conn_str, context->user);
    strcat(context->conn_str, ";");
  }
  if (context->password) {
    strcat(context->conn_str, "PWD=");
    strcat(context->conn_str, context->password);
    strcat(context->conn_str, ";");
  }

  /* Initialize Virtuoso connections */
  librdf_storage_virtuoso_init_connections(storage);

  return 0;
}



/**
 * librdf_storage_virtuoso_terminate:
 * @storage: the storage
 *
 * .
 *
 * Close the storage and database connections.
 *
 * Return value: None.
 **/
static void
librdf_storage_virtuoso_terminate(librdf_storage* storage)
{
  librdf_storage_virtuoso_context *context=(librdf_storage_virtuoso_context*)storage->context;

#ifdef VIRT_DEBUG
  fprintf(stderr, "librdf_storage_virtuoso_terminate \n");
#endif
  librdf_storage_virtuoso_finish_connections(storage);

  if(context->password)
    LIBRDF_FREE(cstring,(char *)context->password);

  if(context->user)
    LIBRDF_FREE(cstring,(char *)context->user);

  if(context->model_name)
    LIBRDF_FREE(cstring,(char *)context->model_name);

  if(context->dsn)
    LIBRDF_FREE(cstring,(char *)context->dsn);

  if(context->database)
    LIBRDF_FREE(cstring,(char *)context->database);

  if(context->host)
    LIBRDF_FREE(cstring,(char *)context->host);

  if(context->conn_str)
    LIBRDF_FREE(cstring,(char *)context->conn_str);

  if(context->transaction_handle)
    librdf_storage_virtuoso_transaction_rollback(storage);

  if (context->h_lang)
      htfree(context->h_lang);

  if (context->h_type)
      htfree(context->h_type);

}



/**
 * librdf_storage_virtuoso_open:
 * @storage: the storage
 * @model: the model
 *
 * .
 *
 * Create or open model in database (nop).
 *
 * Return value: Non-zero on failure.
 **/
static int 
librdf_storage_virtuoso_open(librdf_storage* storage,
                                     librdf_model* model)
{
#ifdef VIRT_DEBUG
  fprintf(stderr, "librdf_storage_virtuoso_open \n");
#endif
  return 0;
}


/**
 * librdf_storage_virtuoso_close:
 * @storage: the storage
 *
 * .
 *
 * Close model (nop).
 *
 * Return value: Non-zero on failure.
 **/
static int 
librdf_storage_virtuoso_close(librdf_storage* storage)
{
#ifdef VIRT_DEBUG
  fprintf(stderr, "librdf_storage_virtuoso_close \n");
#endif

  librdf_storage_virtuoso_transaction_rollback(storage);

  return librdf_storage_virtuoso_sync(storage);
}



/**
 * librdf_storage_virtuoso_sync:
 * @storage: the storage
 *
 * Flush all tables, making sure they are saved on disk.
 *
 * Return value: Non-zero on failure.
 **/
static int 
librdf_storage_virtuoso_sync(librdf_storage* storage)
{
  librdf_storage_virtuoso_context *context=(librdf_storage_virtuoso_context*)storage->context;

#ifdef VIRT_DEBUG
  fprintf(stderr, "librdf_storage_virtuoso_sync \n");
#endif

  /* Make sure optimizing for bulk operations is stopped? */
  if(context->bulk)
    librdf_storage_virtuoso_stop_bulk(storage);

  return 0;
}



/**
 * librdf_storage_virtuoso_size:
 * @storage: the storage
 *
 * .
 *
 * Close model (nop).
 *
 * Return value: Negative on failure.
 **/
static int 
librdf_storage_virtuoso_size(librdf_storage* storage)
{
  librdf_storage_virtuoso_context *context=(librdf_storage_virtuoso_context*)storage->context;
  char model_size[]="select count (*) from (sparql select * from <%s>  where {?s ?p ?o})f";
  char *query;
  int count;
  int rc;
  librdf_storage_virtuoso_connection *handle;

#ifdef VIRT_DEBUG
  fprintf(stderr, "librdf_storage_virtuoso_size \n");
#endif

  /* Get Virtuoso connection handle */
  handle=librdf_storage_virtuoso_get_handle(storage);
  if(!handle)
    return -1;

  /* Query for number of statements */
  if(!(query=(char*)LIBRDF_MALLOC(cstring, strlen(model_size)+strlen(context->model_name)+2))) {
    librdf_storage_virtuoso_release_handle(storage, handle);
    return -1;
  }
  sprintf(query, model_size, context->model_name);

#ifdef LIBRDF_DEBUG_SQL
  LIBRDF_DEBUG2("SQL: >>%s<<\n", query);
#endif

  rc = SQLExecDirect(handle->hstmt, (UCHAR *) query, SQL_NTS);
  if (!SQL_SUCCEEDED(rc))
    {
      rdf_virtuoso_ODBC_Errors("SQLExecDirect()", storage->world, handle);
      count = -1;
      goto end;
    }

  rc = SQLFetch(handle->hstmt);
  if (SQL_SUCCEEDED(rc))
    {
      int is_null;
      if (vGetDataINT(storage->world, handle, 1, &is_null, &count) == -1)
        count = -1;
    }
  SQLCloseCursor(handle->hstmt);

end:  
  LIBRDF_FREE(cstring, query);
  librdf_storage_virtuoso_release_handle(storage, handle);
  return count;
}


static int 
librdf_storage_virtuoso_add_statement(librdf_storage* storage,
                                              librdf_statement* statement)
{
#ifdef VIRT_DEBUG
  fprintf(stderr, "librdf_storage_virtuoso_add_statement \n");
#endif
  return librdf_storage_virtuoso_context_add_statement_helper(storage, 
  							NULL, statement);
}


/**
 * librdf_storage_postgresql_context_add_statement - Add a statement to a storage context
 * @storage: #librdf_storage object
 * @context_node: #librdf_node object
 * @statement: #librdf_statement statement to add
 *
 * Return value: non 0 on failure
 **/
static int 
librdf_storage_virtuoso_context_add_statement(librdf_storage* storage,
					      librdf_node* context_node,
                                              librdf_statement* statement)
{
#ifdef VIRT_DEBUG
  fprintf(stderr, "librdf_storage_virtuoso_context_add_statements \n");
#endif
  return librdf_storage_virtuoso_context_add_statement_helper(storage, 
  							context_node, statement);
}


/**
 * librdf_storage_virtuoso_add_statements:
 * @storage: the storage
 * @statement_stream: the stream of statements
 *
 * .
 *
 * Add statements in stream to storage, without context.
 *
 * Return value: Non-zero on failure.
 **/
static int 
librdf_storage_virtuoso_add_statements(librdf_storage* storage,
                                               librdf_stream* statement_stream)
{
  int helper=0;

#ifdef VIRT_DEBUG
  fprintf(stderr, "librdf_storage_virtuoso_add_statements \n");
#endif

  while(!helper && !librdf_stream_end(statement_stream)) {
    librdf_statement* statement=librdf_stream_get_object(statement_stream);
    helper=librdf_storage_virtuoso_context_add_statement_helper(storage, NULL, statement);
    librdf_stream_next(statement_stream);
  }

  return helper;
}



/**
 * librdf_storage_virtuoso_context_add_statements:
 * @storage: the storage
 * @statement_stream: the stream of statements
 *
 * .
 *
 * Add statements in stream to storage, without context.
 *
 * Return value: Non-zero on failure.
 **/
static int 
librdf_storage_virtuoso_context_add_statements(librdf_storage* storage,
					       librdf_node* context_node,
                                               librdf_stream* statement_stream)
{
  librdf_storage_virtuoso_context* context=(librdf_storage_virtuoso_context*)storage->context;
  int helper=0;

#ifdef VIRT_DEBUG
  fprintf(stderr, "librdf_storage_virtuoso_context_add_statements \n");
#endif

  /* Optimize for bulk loads? */
  if(context->bulk) {
    if(librdf_storage_virtuoso_start_bulk(storage))
      return 1;
  }

  while(!helper && !librdf_stream_end(statement_stream)) {
    librdf_statement* statement=librdf_stream_get_object(statement_stream);

    helper=librdf_storage_virtuoso_context_add_statement_helper(storage, context_node, statement);
    librdf_stream_next(statement_stream);
  }

  /* Optimize for bulk loads? */
  if(context->bulk) {
    if(librdf_storage_virtuoso_stop_bulk(storage))
      return 1;
  }

  return helper;
}



/*
 * librdf_storage_virtuoso_add_statement_helper - Perform actual addition of a statement to a storage context
 * @storage: #librdf_storage object
 * @statement: #librdf_statement statement to add
 *
 * Return value: non-zero on failure
 **/
static int
librdf_storage_virtuoso_context_add_statement_helper(librdf_storage* storage,
					  librdf_node* context_node,
                                          librdf_statement* statement)
{
  librdf_storage_virtuoso_context* context=(librdf_storage_virtuoso_context*)storage->context;
  char *insert_statement="sparql insert into graph %s { %s %s %s }";
  char *query=NULL;
  librdf_storage_virtuoso_connection *handle=NULL;
  int rc;
  int ret = 0;
  char *subject = NULL;
  char *predicate = NULL;
  char *object = NULL;
  char *ctxt_node = NULL;

#ifdef VIRT_DEBUG
  fprintf(stderr, "librdf_storage_virtuoso_add_statement_helper \n");
#endif
  /* Get Virtuoso connection handle */
  handle=librdf_storage_virtuoso_get_handle(storage);
  if(!handle)
    return 1;

  subject=librdf_storage_virtuoso_node2string(storage,
                                          librdf_statement_get_subject(statement));
  predicate=librdf_storage_virtuoso_node2string(storage,
                                            librdf_statement_get_predicate(statement));
  object=librdf_storage_virtuoso_node2string(storage,
                                         librdf_statement_get_object(statement));
  if(!subject || !predicate || !object) {
    ret = 1;
    goto end;
  }

  ctxt_node = librdf_storage_virtuoso_context2string(storage, context_node);
  if (!ctxt_node)
    {
      ret = 1;
      goto end;
    }

  if(!(query=(char*)LIBRDF_MALLOC(cstring, strlen(insert_statement)+ 
  			strlen(ctxt_node) + strlen(subject) + 
  			strlen(predicate) + strlen(object)+1))) {
      ret = 1;
      goto end;
    }
  sprintf(query, insert_statement, ctxt_node, subject, predicate, object);
    
#ifdef VIRT_DEBUG
  printf("SQL: >>%s<<\n", query);
#endif
#ifdef LIBRDF_DEBUG_SQL
  LIBRDF_DEBUG2("SQL: >>%s<<\n", query);
#endif
  rc = SQLExecDirect(handle->hstmt, (SQLCHAR *)query, SQL_NTS);
  if (!SQL_SUCCEEDED(rc))
    {
      rdf_virtuoso_ODBC_Errors("SQLExecDirect()", storage->world, handle);
      ret = -1;
      goto end;
    }

end:
  if(query)
    LIBRDF_FREE(cstring,query);
  if(ctxt_node)
    LIBRDF_FREE(cstring,ctxt_node);
  if(subject)
    LIBRDF_FREE(cstring,subject);
  if(predicate)
    LIBRDF_FREE(cstring,predicate);
  if(object)
    LIBRDF_FREE(cstring,object);
  if(handle)
    librdf_storage_virtuoso_release_handle(storage, handle);

  return ret;
}



/*
 * librdf_storage_virtuoso_start_bulk - Prepare for bulk insert operation
 * @storage: the storage
 *
 * Return value: Non-zero on failure.
 */
static int
librdf_storage_virtuoso_start_bulk(librdf_storage* storage)
{
  return 1;
}



/*
 * librdf_storage_virtuoso_stop_bulk - End bulk insert operation
 * @storage: the storage
 *
 * Return value: Non-zero on failure.
 */
static int
librdf_storage_virtuoso_stop_bulk(librdf_storage* storage)
{
  return 1;
}


/**
 * librdf_storage_virtuoso_contains_statement:
 * @storage: the storage
 * @statement: a complete statement
 *
 * Test if a given complete statement is present in the model.
 *
 * Return value: Non-zero if the model contains the statement.
 **/
static int 
librdf_storage_virtuoso_contains_statement(librdf_storage* storage,
                                                   librdf_statement* statement)
{
  return librdf_storage_virtuoso_context_contains_statement(storage, NULL, 
  							statement);
}


/**
 * librdf_storage_virtuoso_contains_statement:
 * @storage: the storage
 * @statement: a complete statement
 *
 * Test if a given complete statement is present in the model.
 *
 * Return value: Non-zero if the model contains the statement.
 **/
static int 
librdf_storage_virtuoso_context_contains_statement(librdf_storage* storage,
					           librdf_node* context_node,
                                                   librdf_statement* statement)
{
  librdf_storage_virtuoso_context* context=(librdf_storage_virtuoso_context*)storage->context;
  char find_statement[]="select count (*) from (sparql select * from %s where { %s %s %s })f";
  char *query = NULL;
  librdf_storage_virtuoso_connection *handle=NULL;
  int rc;
  int ret = 0;
  char *subject = NULL;
  char *predicate = NULL;
  char *object = NULL;
  char *ctxt_node = NULL;

#ifdef VIRT_DEBUG
  fprintf(stderr, "librdf_storage_virtuoso_contains_statement \n");
#endif

  /* Get Virtuoso connection handle */
  handle=librdf_storage_virtuoso_get_handle(storage);
  if(!handle)
    return 0;

  subject=librdf_storage_virtuoso_node2string(storage,
                                          librdf_statement_get_subject(statement));
  predicate=librdf_storage_virtuoso_node2string(storage,
                                            librdf_statement_get_predicate(statement));
  object=librdf_storage_virtuoso_node2string(storage,
                                         librdf_statement_get_object(statement));
  if(!subject || !predicate || !object) {
    ret = 0;
    goto end;
  }

  ctxt_node = librdf_storage_virtuoso_context2string(storage, context_node);
  if (!ctxt_node)
    {
      ret = 1;
      goto end;
    }

  if(!(query=(char*)LIBRDF_MALLOC(cstring, strlen(find_statement)+
  			strlen(ctxt_node)+ strlen(subject) + 
  			strlen(predicate) + strlen(object)+1))) {
      ret = 0;
      goto end;
    }
  sprintf(query, find_statement, ctxt_node, subject, predicate, object);

#ifdef VIRT_DEBUG
  printf("SQL: >>%s<<\n", query);
#endif
#ifdef LIBRDF_DEBUG_SQL
  LIBRDF_DEBUG2("SQL: >>%s<<\n", query);
#endif

  rc = SQLExecDirect(handle->hstmt, (SQLCHAR *)query, SQL_NTS);
  if (!SQL_SUCCEEDED(rc))
    {
      rdf_virtuoso_ODBC_Errors("SQLExecDirect()", storage->world, handle);
      ret = 0;
      goto end;
    }

  rc = SQLFetch(handle->hstmt);
  if (SQL_SUCCEEDED(rc))
    {
      int is_null;
      int val;
      if (!vGetDataINT(storage->world, handle, 1, &is_null, &val))
        ret = (val != 0);
/*printf("Contains[%d]\n", val);*/
    }
  SQLCloseCursor(handle->hstmt);

end:
  if(query)
    LIBRDF_FREE(cstring,query);
  if(ctxt_node)
    LIBRDF_FREE(cstring,ctxt_node);
  if(subject)
    LIBRDF_FREE(cstring,subject);
  if(predicate)
    LIBRDF_FREE(cstring,predicate);
  if(object)
    LIBRDF_FREE(cstring,object);
  if(handle)
    librdf_storage_virtuoso_release_handle(storage, handle);

  return ret;
}


/**
 * librdf_storage_virtuoso_remove_statement:
 * @storage: #librdf_storage object
 * @statement: #librdf_statement statement to remove
 *
 * Remove a statement from storage.
 *
 * Return value: non-zero on failure
 **/
static int 
librdf_storage_virtuoso_remove_statement(librdf_storage* storage,
                                                 librdf_statement* statement)
{
  return librdf_storage_virtuoso_context_remove_statement(storage,NULL,statement);
}


/**
 * librdf_storage_virtuoso_context_remove_statement - Remove a statement from a storage context
 * @storage: #librdf_storage object
 * @context_node: #librdf_node object
 * @statement: #librdf_statement statement to remove
 *
 * Remove a statement from storage.
 *
 * Return value: non-zero on failure
 **/
static int 
librdf_storage_virtuoso_context_remove_statement(librdf_storage* storage,
                                                 librdf_node* context_node,
                                                 librdf_statement* statement)
{
  librdf_storage_virtuoso_context* context=(librdf_storage_virtuoso_context*)storage->context;
  char *remove_statement="sparql delete from graph %s { %s %s %s }";
  char *query=NULL;
  librdf_storage_virtuoso_connection *handle=NULL;
  int rc;
  int ret = 0;
  char *subject = NULL;
  char *predicate = NULL;
  char *object = NULL;
  char *ctxt_node = NULL;

#ifdef VIRT_DEBUG
  fprintf(stderr, "librdf_storage_virtuoso_context_remove_statement \n");
#endif

  /* Get Virtuoso connection handle */
  handle=librdf_storage_virtuoso_get_handle(storage);
  if(!handle)
    return 1;

  subject=librdf_storage_virtuoso_node2string(storage,
                                          librdf_statement_get_subject(statement));
  predicate=librdf_storage_virtuoso_node2string(storage,
                                            librdf_statement_get_predicate(statement));
  object=librdf_storage_virtuoso_node2string(storage,
                                         librdf_statement_get_object(statement));
  if(!subject || !predicate || !object) {
    ret = 1;
    goto end;
  }

  ctxt_node = librdf_storage_virtuoso_context2string(storage, context_node);
  if (!ctxt_node)
    {
      ret = 1;
      goto end;
    }

  if(!(query=(char*)LIBRDF_MALLOC(cstring, strlen(remove_statement) +
  			strlen(ctxt_node) + strlen(subject) + 
  			strlen(predicate) + strlen(object)+1))) {
      ret = 1;
      goto end;
    }
  sprintf(query, remove_statement, ctxt_node, subject, predicate, object);
    
#ifdef VIRT_DEBUG
  printf("SQL: >>%s<<\n", query);
#endif
#ifdef LIBRDF_DEBUG_SQL
  LIBRDF_DEBUG2("SQL: >>%s<<\n", query);
#endif
  rc = SQLExecDirect(handle->hstmt, (SQLCHAR *)query, SQL_NTS);
  if (!SQL_SUCCEEDED(rc))
    {
      rdf_virtuoso_ODBC_Errors("SQLExecDirect()", storage->world, handle);
      ret = -1;
      goto end;
    }

end:
  if(query)
    LIBRDF_FREE(cstring,query);
  if(ctxt_node)
    LIBRDF_FREE(cstring,ctxt_node);
  if(subject)
    LIBRDF_FREE(cstring,subject);
  if(predicate)
    LIBRDF_FREE(cstring,predicate);
  if(object)
    LIBRDF_FREE(cstring,object);
  if(handle) {    
    librdf_storage_virtuoso_release_handle(storage, handle);
  }

  return ret;
}




/**
 * librdf_storage_virtuoso_context_remove_statements - Remove all statement from a storage context
 * @storage: #librdf_storage object
 * @context_node: #librdf_node object
 *
 * Remove statements from storage.
 *
 * Return value: non-zero on failure
 **/
static int 
librdf_storage_virtuoso_context_remove_statements(librdf_storage* storage,
                                                 librdf_node* context_node)
{
  librdf_storage_virtuoso_context* context=(librdf_storage_virtuoso_context*)storage->context;
  char *remove_statements="sparql clear graph %s";
  char *query=NULL;
  librdf_storage_virtuoso_connection *handle=NULL;
  int rc;
  int ret = 0;
  char *ctxt_node = NULL;

#ifdef VIRT_DEBUG
  fprintf(stderr, "librdf_storage_virtuoso_context_remove_statements \n");
#endif

  /* Get Virtuoso connection handle */
  handle=librdf_storage_virtuoso_get_handle(storage);
  if(!handle)
    return 1;

  ctxt_node = librdf_storage_virtuoso_context2string(storage, context_node);
  if (!ctxt_node)
    {
      ret = 1;
      goto end;
    }

  if(!(query=(char*)LIBRDF_MALLOC(cstring, strlen(remove_statements) +
  			strlen(ctxt_node)+1))) {
      ret = 1;
      goto end;
    }
  sprintf(query, remove_statements, ctxt_node);
    
#ifdef VIRT_DEBUG
  printf("SQL: >>%s<<\n", query);
#endif
#ifdef LIBRDF_DEBUG_SQL
  LIBRDF_DEBUG2("SQL: >>%s<<\n", query);
#endif
  rc = SQLExecDirect(handle->hstmt, (SQLCHAR *)query, SQL_NTS);
  if (!SQL_SUCCEEDED(rc))
    {
      rdf_virtuoso_ODBC_Errors("SQLExecDirect()", storage->world, handle);
      ret = -1;
      goto end;
    }

end:
  if(query)
    LIBRDF_FREE(cstring,query);
  if(ctxt_node)
    LIBRDF_FREE(cstring,ctxt_node);
  if(handle) {    
    librdf_storage_virtuoso_release_handle(storage, handle);
  }

  return ret;
}



/**
 * librdf_storage_virtuoso_serialise - Return a stream of all statements in a storage
 * @storage: the storage
 *
 * Return a stream of all statements in a storage.
 *
 * Return value: a #librdf_stream or NULL on failure
 **/
static librdf_stream* 
librdf_storage_virtuoso_serialise(librdf_storage* storage)
{
  librdf_storage_virtuoso_context* context=(librdf_storage_virtuoso_context*)storage->context;
  librdf_node *node;

  node=librdf_new_node_from_uri_string(storage->world, (const unsigned char*)context->model_name);

  return librdf_storage_virtuoso_find_statements_in_context(storage,NULL,node);
}


/**
 * librdf_storage_virtuoso_context_serialise - List all statements in a storage context
 * @storage: #librdf_storage object
 * @context_node: #librdf_node object
 *
 * Return a stream of all statements in a storage.
 *
 * Return value: #librdf_stream of statements or NULL on failure or context is empty
 **/
static librdf_stream* 
librdf_storage_virtuoso_context_serialise(librdf_storage* storage,
                                  	  librdf_node* context_node)
{
  return librdf_storage_virtuoso_find_statements_in_context(storage,NULL,context_node);
}



static int librdf_storage_virtuoso_find_statements_in_context_end_of_stream(void* context);
static int librdf_storage_virtuoso_find_statements_in_context_next_statement (void* context);
static void* librdf_storage_virtuoso_find_statements_in_context_get_statement(void* context, int flags);
static void librdf_storage_virtuoso_find_statements_in_context_finished(void* context);

/**
 * librdf_storage_virtuoso_find_statements - Find a graph of statements in storage.
 * @storage: the storage
 * @statement: the statement to match
 *
 * Return a stream of statements matching the given statement (or
 * all statements if NULL).  Parts (subject, predicate, object) of the
 * statement can be empty in which case any statement part will match that.
 *
 * Return value: a #librdf_stream or NULL on failure
 **/
static librdf_stream*
librdf_storage_virtuoso_find_statements(librdf_storage* storage,
                                     librdf_statement* statement)
{
  librdf_storage_virtuoso_context* context=(librdf_storage_virtuoso_context*)storage->context;
  librdf_node *node;

  node=librdf_new_node_from_uri_string(storage->world, (const unsigned char*)context->model_name);

  return librdf_storage_virtuoso_find_statements_in_context(storage, statement, 
  							node);
}

/**
 * librdf_storage_virtuoso_find_statements_in_context - Find a graph of statements in a storage context.
 * @storage: the storage
 * @statement: the statement to match
 * @context_node: the context to search
 *
 * Return a stream of statements matching the given statement (or
 * all statements if NULL).  Parts (subject, predicate, object) of the
 * statement can be empty in which case any statement part will match that.
 *
 * Return value: a #librdf_stream or NULL on failure
 **/
static librdf_stream*
librdf_storage_virtuoso_find_statements_in_context(librdf_storage* storage,
                                     		librdf_statement* statement,
                                     		librdf_node* context_node)
{
  librdf_storage_virtuoso_context* context=(librdf_storage_virtuoso_context*)storage->context;
  char find_statement[]="sparql select * from %s where { %s %s %s }";
  librdf_node_type type;
  char *query = NULL;
  librdf_storage_virtuoso_sos_context *sos=NULL;
  int rc=0;
  librdf_node *subject=NULL, *predicate=NULL, *object=NULL;
  char *s_subject = NULL;
  char *s_predicate = NULL;
  char *s_object = NULL;
  char *ctxt_node = NULL;

  librdf_stream *stream = NULL;

#ifdef VIRT_DEBUG
  fprintf(stderr, "librdf_storage_virtuoso_find_statements_in_context \n");
#endif
  /* Initialize sos context */
  if (!(sos=(librdf_storage_virtuoso_sos_context*)
      LIBRDF_CALLOC(librdf_storage_virtuoso_sos_context,1,
                    sizeof(librdf_storage_virtuoso_sos_context))))
    return NULL;

  sos->storage=storage;
  librdf_storage_add_reference(sos->storage);

  if (statement)
    sos->query_statement=librdf_new_statement_from_statement(statement);
  if (context_node)
    sos->query_context = librdf_new_node_from_node(context_node);

  sos->current_statement=NULL;
  sos->current_context=NULL;

  /* Get Vrtuoso connection handle */
  sos->handle=librdf_storage_virtuoso_get_handle(storage);
  if (!sos->handle) {
    librdf_storage_virtuoso_find_statements_in_context_finished((void*)sos);
    goto end;
  }

  if (statement) { 
    subject = librdf_statement_get_subject(statement);
    predicate = librdf_statement_get_predicate(statement);
    object = librdf_statement_get_object(statement);
  }

  if (subject) {
    s_subject = librdf_storage_virtuoso_node2string(storage, subject);
    if (strlen(s_subject)==0) {
      subject = NULL; 
      LIBRDF_FREE(cstring, s_subject);
    }
  }
  if (predicate) {
    s_predicate = librdf_storage_virtuoso_node2string(storage, predicate);
    if (strlen(s_predicate)==0) {
      predicate = NULL; 
      LIBRDF_FREE(cstring, s_predicate);
    }
  }
  if (object) {
    s_object = librdf_storage_virtuoso_node2string(storage, object);
    if (strlen(s_object)==0) {
      object = NULL; 
      LIBRDF_FREE(cstring, s_object);
    }
  }
    
  if (!subject)
    s_subject = "?s";

  if (!predicate)
    s_predicate = "?p";

  if (!object)
    s_object = "?o";

  ctxt_node = librdf_storage_virtuoso_fcontext2string(storage, context_node);
  if (!ctxt_node)
    goto end;

  if (!(query=(char*)LIBRDF_MALLOC(cstring, strlen(find_statement)+
  			strlen(ctxt_node) + strlen(s_subject) + 
  			strlen(s_predicate) + strlen(s_object)+1))) {
      librdf_storage_virtuoso_find_statements_in_context_finished((void*)sos);
      goto end;
    }
  sprintf(query, find_statement, ctxt_node, s_subject, s_predicate, s_object);

#ifdef VIRT_DEBUG
  printf("SQL: >>%s<<\n", query);
#endif
#ifdef LIBRDF_DEBUG_SQL
  LIBRDF_DEBUG2("SQL: >>%s<<\n", query);
#endif

  rc = SQLExecDirect(sos->handle->hstmt, (SQLCHAR *)query, SQL_NTS);
  if (!SQL_SUCCEEDED(rc))
    {
      rdf_virtuoso_ODBC_Errors("SQLExecDirect()", storage->world, sos->handle);
      librdf_storage_virtuoso_find_statements_in_context_finished((void*)sos);
      goto end;
    }

  /* Get first statement, if any, and initialize stream */
  if(librdf_storage_virtuoso_find_statements_in_context_next_statement(sos) ) {
    librdf_storage_virtuoso_find_statements_in_context_finished((void*)sos);
    return librdf_new_empty_stream(storage->world);
  }

#ifdef VIRT_DEBUG
  fprintf(stderr, "librdf_storage_virtuoso_find_statements \n");
#endif
  stream=librdf_new_stream(storage->world,(void*)sos,
                           &librdf_storage_virtuoso_find_statements_in_context_end_of_stream,
                           &librdf_storage_virtuoso_find_statements_in_context_next_statement,
                           &librdf_storage_virtuoso_find_statements_in_context_get_statement,
                           &librdf_storage_virtuoso_find_statements_in_context_finished);

  if(!stream)
    librdf_storage_virtuoso_find_statements_in_context_finished((void*)sos);

end:
  if(query)
    LIBRDF_FREE(cstring, query);
  if(ctxt_node)
    LIBRDF_FREE(cstring,ctxt_node);
  if(subject)
    LIBRDF_FREE(cstring, s_subject);
  if(predicate)
    LIBRDF_FREE(cstring, s_predicate);
  if(object)
    LIBRDF_FREE(cstring, s_object);

  return stream;
}


/**
 * librdf_storage_virtuoso_find_statements_with_options - Find a graph of statements in a storage context with options.
 * @storage: the storage
 * @statement: the statement to match
 * @context_node: the context to search
 * @options: #librdf_hash of match options or NULL
 *
 * Return a stream of statements matching the given statement (or
 * all statements if NULL).  Parts (subject, predicate, object) of the
 * statement can be empty in which case any statement part will match that.
 *
 * Return value: a #librdf_stream or NULL on failure
 **/
static librdf_stream*
librdf_storage_virtuoso_find_statements_with_options(librdf_storage* storage, 
                                                  librdf_statement* statement,
                                                  librdf_node* context_node,
                                                  librdf_hash* options)
{
  return librdf_storage_virtuoso_find_statements_in_context(storage, 
                                                statement, context_node);
}


static int
librdf_storage_virtuoso_find_statements_in_context_end_of_stream(void* context)
{
  librdf_storage_virtuoso_sos_context* sos=(librdf_storage_virtuoso_sos_context*)context;

  return sos->current_statement==NULL;
}


static int
librdf_storage_virtuoso_find_statements_in_context_next_statement (void* context)
{
  librdf_storage_virtuoso_sos_context* sos=(librdf_storage_virtuoso_sos_context*)context;
  librdf_node *subject=NULL, *predicate=NULL, *object=NULL;
  librdf_node *node;
  short colNum;
  short numCols;
  int rc;

  rc = SQLNumResultCols (sos->handle->hstmt, &numCols);
  if (!SQL_SUCCEEDED(rc))
    {
      rdf_virtuoso_ODBC_Errors("SQLNumResultCols()", sos->storage->world, sos->handle);
      return 1;
    }

  rc = SQLFetch (sos->handle->hstmt);
  if (rc == SQL_NO_DATA_FOUND)
    {
      if (sos->current_statement)
        librdf_free_statement(sos->current_statement);
      sos->current_statement=NULL;
      if(sos->current_context)
        librdf_free_node(sos->current_context);
      sos->current_context=NULL;
      return 0;
    }
  else if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
    {
      rdf_virtuoso_ODBC_Errors ((char *)"SQLFetch", sos->storage->world, sos->handle);
      return 1;
    }


  /* Get ready for context */
  if (sos->current_context)
    librdf_free_node(sos->current_context);
  sos->current_context = NULL;

  if (sos->query_statement) 
    {
      subject=librdf_statement_get_subject(sos->query_statement);
      predicate=librdf_statement_get_predicate(sos->query_statement);
      object=librdf_statement_get_object(sos->query_statement);
    }

  /* Make sure we have a statement object to return */
  if(!sos->current_statement) {
      if(!(sos->current_statement=librdf_new_statement(sos->storage->world)))
           return 1;
  }

  librdf_statement_clear(sos->current_statement);

    /* Query without variables? */
  if(subject && predicate && object && sos->query_context) {

      librdf_statement_set_subject(sos->current_statement,librdf_new_node_from_node(subject));
      librdf_statement_set_predicate(sos->current_statement,librdf_new_node_from_node(predicate));
      librdf_statement_set_object(sos->current_statement,librdf_new_node_from_node(object));
      sos->current_context=librdf_new_node_from_node(sos->query_context);

  } else {

      colNum = 1;
      char * data;
      int is_null;

      if (sos->query_context) {
        sos->current_context=librdf_new_node_from_node(sos->query_context);
      } else {
        data = vGetDataCHAR(sos->storage->world, sos->handle, colNum, &is_null);
        if (!data || is_null)
          return 1; 
      
        sos->current_context=rdf2node(sos->storage, sos->handle, colNum, data);
        LIBRDF_FREE(cstring,(char *)data);
        if (!sos->current_context)
          return 1;

        colNum++;
      }
        
      if(subject) {
        librdf_statement_set_subject(sos->current_statement,librdf_new_node_from_node(subject));
      } else {

        data = vGetDataCHAR(sos->storage->world, sos->handle, colNum, &is_null);
        if (!data || is_null)
          return 1; 
      
        node=rdf2node(sos->storage, sos->handle, colNum, data);
        LIBRDF_FREE(cstring,(char *)data);
        if (!node)
          return 1;

        librdf_statement_set_subject(sos->current_statement, node);
        colNum++;
      }

      if(predicate) {
        librdf_statement_set_predicate(sos->current_statement,librdf_new_node_from_node(predicate));
      } else {
        data = vGetDataCHAR(sos->storage->world, sos->handle, colNum, &is_null);
        if (!data || is_null)
          return 1; 
      
        node=rdf2node(sos->storage, sos->handle, colNum, data);
        LIBRDF_FREE(cstring,(char *)data);
        if (!node)
          return 1;

        librdf_statement_set_predicate(sos->current_statement, node);
        colNum++;
      }

      if(object) {
        librdf_statement_set_object(sos->current_statement,librdf_new_node_from_node(object));
      } else {
        data = vGetDataCHAR(sos->storage->world, sos->handle, colNum, &is_null);
        if (!data || is_null)
          return 1; 
      
        node=rdf2node(sos->storage, sos->handle, colNum, data);
        LIBRDF_FREE(cstring,(char *)data);
        if (!node)
          return 1;

        librdf_statement_set_object(sos->current_statement, node);
      }

  }
  return 0;
}


static void*
librdf_storage_virtuoso_find_statements_in_context_get_statement(void* context, 
								int flags)
{
  librdf_storage_virtuoso_sos_context* sos=(librdf_storage_virtuoso_sos_context*)context;

  switch(flags) {
    case LIBRDF_ITERATOR_GET_METHOD_GET_OBJECT:
      return sos->current_statement;
    case LIBRDF_ITERATOR_GET_METHOD_GET_CONTEXT:
      return sos->current_context;
    default:
      abort();
  }
}


static void
librdf_storage_virtuoso_find_statements_in_context_finished(void* context)
{
  librdf_storage_virtuoso_sos_context* sos=(librdf_storage_virtuoso_sos_context*)context;

  if(sos->handle) {
    librdf_storage_virtuoso_release_handle(sos->storage, sos->handle);
  }

  if(sos->current_statement)
    librdf_free_statement(sos->current_statement);

  if(sos->current_context)
    librdf_free_node(sos->current_context);

  if(sos->query_statement)
    librdf_free_statement(sos->query_statement);

  if(sos->query_context)
    librdf_free_node(sos->query_context);

  if(sos->storage)
    librdf_storage_remove_reference(sos->storage);

  LIBRDF_FREE(librdf_storage_virtuoso_sos_context, sos);
}



static librdf_node*
librdf_storage_virtuoso_get_feature(librdf_storage* storage, librdf_uri* feature)
{
  unsigned char *uri_string;

  if(!feature)
    return NULL;

  uri_string=librdf_uri_as_string(feature);

  if(!uri_string)
    return NULL;

  if (!strcmp((const char*)uri_string, LIBRDF_MODEL_FEATURE_CONTEXTS))
    {
      unsigned char value[2];
      sprintf((char*)value, "%d", 1);

      return librdf_new_node_from_typed_literal(storage->world,
	  value, NULL, NULL);
    }

  return NULL;
}



/* methods for iterator for contexts */
static int librdf_storage_virtuoso_get_contexts_end_of_iterator(void* context);
static int librdf_storage_virtuoso_get_contexts_next_context(void* context);
static void* librdf_storage_virtuoso_get_contexts_get_context(void* context, int flags);
static void librdf_storage_virtuoso_get_contexts_finished(void* context);

/**
 * librdf_storage_virtuoso_get_contexts:
 * @storage: the storage
 *
 * Return an iterator with the context nodes present in storage.
 *
 * Return value: a #librdf_iterator or NULL on failure
 **/
static librdf_iterator*
librdf_storage_virtuoso_get_contexts(librdf_storage* storage)
{
  librdf_storage_virtuoso_context* context=(librdf_storage_virtuoso_context*)storage->context;
  librdf_storage_virtuoso_get_contexts_context* gccontext;
  char find_statement[]="sparql select distinct ?g where {graph ?g {?s ?o ?p.}}";
  librdf_node_type type;
  int rc=0;

  librdf_iterator *iterator;

#ifdef VIRT_DEBUG
  fprintf(stderr, "librdf_storage_virtuoso_get_contexts \n");
#endif
  /* Initialize get_contexts context */
  if(!(gccontext=(librdf_storage_virtuoso_get_contexts_context*)
      LIBRDF_CALLOC(librdf_storage_virtuoso_get_contexts_context,1,
                    sizeof(librdf_storage_virtuoso_get_contexts_context))))
    return NULL;

  
  gccontext->storage=storage;
  librdf_storage_add_reference(gccontext->storage);

  gccontext->current_context=NULL;

  /* Get Vrtuoso connection handle */
  gccontext->handle=librdf_storage_virtuoso_get_handle(storage);
  if (!gccontext->handle) {
    librdf_storage_virtuoso_get_contexts_finished((void*)gccontext);
    goto end;
  }

#ifdef VIRT_DEBUG
  printf("SQL: >>%s<<\n", find_statement);
#endif
#ifdef LIBRDF_DEBUG_SQL
  LIBRDF_DEBUG2("SQL: >>%s<<\n", find_statement);
#endif

  rc = SQLExecDirect(gccontext->handle->hstmt, (SQLCHAR *)find_statement, SQL_NTS);
  if (!SQL_SUCCEEDED(rc))
    {
      rdf_virtuoso_ODBC_Errors("SQLExecDirect()", storage->world, gccontext->handle);
      librdf_storage_virtuoso_get_contexts_finished((void*)gccontext);
      goto end;
    }

  /* Get first statement, if any, and initialize stream */
  if(librdf_storage_virtuoso_get_contexts_next_context(gccontext) ||
     !gccontext->current_context) {
    librdf_storage_virtuoso_get_contexts_finished((void*)gccontext);
    return librdf_new_empty_iterator(storage->world);
  }

  iterator=librdf_new_iterator(storage->world,(void*)gccontext,
                           &librdf_storage_virtuoso_get_contexts_end_of_iterator,
                           &librdf_storage_virtuoso_get_contexts_next_context,
                           &librdf_storage_virtuoso_get_contexts_get_context,
                           &librdf_storage_virtuoso_get_contexts_finished);

  if(!iterator)
    librdf_storage_virtuoso_get_contexts_finished((void*)gccontext);

end:

  return iterator;
}



static int
librdf_storage_virtuoso_get_contexts_end_of_iterator(void* context)
{
  librdf_storage_virtuoso_get_contexts_context* gccontext=(librdf_storage_virtuoso_get_contexts_context*)context;

  return gccontext->current_context==NULL;
}



static int
librdf_storage_virtuoso_get_contexts_next_context(void* context)
{
  librdf_storage_virtuoso_get_contexts_context* gccontext=(librdf_storage_virtuoso_get_contexts_context*)context;
  librdf_node *node;
  int i;
  int rc;
  short colNum;
  short numCols;
  char *data;
  int is_null;
  
  rc = SQLNumResultCols (gccontext->handle->hstmt, &numCols);
  if (!SQL_SUCCEEDED(rc))
    {
      rdf_virtuoso_ODBC_Errors("SQLNumResultCols()", gccontext->storage->world, gccontext->handle);
      return 1;
    }

  rc = SQLFetch (gccontext->handle->hstmt);
  if (rc == SQL_NO_DATA_FOUND)
    {
      if(gccontext->current_context)
        librdf_free_node(gccontext->current_context);
      gccontext->current_context=NULL;
      return 0;
    }
  else if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
    {
      rdf_virtuoso_ODBC_Errors ((char *)"SQLFetch", gccontext->storage->world, gccontext->handle);
      return 1;
    }

  /* Free old context node, if allocated */
  if(gccontext->current_context)
    librdf_free_node(gccontext->current_context);

  colNum = 1;
  data = vGetDataCHAR(gccontext->storage->world, gccontext->handle, colNum, &is_null);
  if (!data || is_null)
    return 1; 

  gccontext->current_context=rdf2node(gccontext->storage, gccontext->handle, colNum, data);
  LIBRDF_FREE(cstring,(char *)data);
  if (!gccontext->current_context)
    return 1;
    
  return 0;
}


static void*
librdf_storage_virtuoso_get_contexts_get_context(void* context, int flags)
{
  librdf_storage_virtuoso_get_contexts_context* gccontext=(librdf_storage_virtuoso_get_contexts_context*)context;

  return gccontext->current_context;
}


static void
librdf_storage_virtuoso_get_contexts_finished(void* context)
{
  librdf_storage_virtuoso_get_contexts_context* gccontext=(librdf_storage_virtuoso_get_contexts_context*)context;

  if(gccontext->handle)
    librdf_storage_virtuoso_release_handle(gccontext->storage, gccontext->handle);

  if(gccontext->current_context)
    librdf_free_node(gccontext->current_context);

  if(gccontext->storage)
    librdf_storage_remove_reference(gccontext->storage);

  LIBRDF_FREE(librdf_storage_virtuoso_get_contexts_context, gccontext);
}




/**
 * librdf_storage_virtuoso_transaction_start:
 * @storage: the storage object
 * 
 * Start a transaction
 * 
 * Return value: non-0 on failure
 **/
static int
librdf_storage_virtuoso_transaction_start(librdf_storage* storage)
{
  librdf_storage_virtuoso_context *context=(librdf_storage_virtuoso_context *)storage->context;
  int rc;
  
#ifdef VIRT_DEBUG
  fprintf(stderr, "librdf_storage_virtuoso_transaction_start \n");
#endif

  if(context->transaction_handle) {
    librdf_log(storage->world, 0, LIBRDF_LOG_ERROR, LIBRDF_FROM_STORAGE, NULL,
               "Virtuoso transaction already started");
    return 1;
  }
  
  context->transaction_handle=librdf_storage_virtuoso_get_handle(storage);
  if(!context->transaction_handle) 
    return 1;

  rc = SQLSetConnectAttr(context->transaction_handle->hdbc, SQL_ATTR_AUTOCOMMIT, (SQLPOINTER)SQL_AUTOCOMMIT_ON, 0);
  if (!SQL_SUCCEEDED(rc))
    {
      rdf_virtuoso_ODBC_Errors("SQLSetConnectAttr(hdbc)", storage->world, context->transaction_handle);
      librdf_storage_virtuoso_release_handle(storage, context->transaction_handle);
      context->transaction_handle=NULL;
      return 1;
    }

  return 0;
}



/**
 * librdf_storage_virtuoso_transaction_start_with_handle:
 * @storage: the storage object
 * @handle: the transaction object
 * 
 * Start a transaction using an existing external transaction object.
 * 
 * Return value: non-0 on failure
 **/
static int
librdf_storage_virtuoso_transaction_start_with_handle(librdf_storage* storage,
                                                   void* handle)
{
#ifdef VIRT_DEBUG
  fprintf(stderr, "librdf_storage_virtuoso_transaction_start_with_handle \n");
#endif
  return librdf_storage_virtuoso_transaction_start(storage);
}


/**
 * librdf_storage_virtuoso_transaction_commit:
 * @storage: the storage object
 * 
 * Commit a transaction.
 * 
 * Return value: non-0 on failure 
 **/
static int
librdf_storage_virtuoso_transaction_commit(librdf_storage* storage)
{
  librdf_storage_virtuoso_context *context=(librdf_storage_virtuoso_context *)storage->context;
  int rc;

#ifdef VIRT_DEBUG
  fprintf(stderr, "librdf_storage_virtuoso_transaction_commit \n");
#endif

  if(!context->transaction_handle)
    return 1;

  rc = SQLEndTran(SQL_HANDLE_DBC, context->transaction_handle->hdbc, SQL_COMMIT);
  if (!SQL_SUCCEEDED(rc))
    rdf_virtuoso_ODBC_Errors("SQLEndTran(hdbc,COMMIT)", storage->world, context->transaction_handle);

  librdf_storage_virtuoso_release_handle(storage, context->transaction_handle);
  context->transaction_handle=NULL;
      
  return (SQL_SUCCEEDED(rc) ? 0 : 1);
}


/**
 * librdf_storage_virtuoso_transaction_rollback:
 * @storage: the storage object
 * 
 * Rollback a transaction.
 * 
 * Return value: non-0 on failure 
 **/
static int
librdf_storage_virtuoso_transaction_rollback(librdf_storage* storage)
{
  librdf_storage_virtuoso_context *context=(librdf_storage_virtuoso_context *)storage->context;
  int rc;

#ifdef VIRT_DEBUG
  fprintf(stderr, "librdf_storage_virtuoso_transaction_rollback \n");
#endif

  if(!context->transaction_handle)
    return 1;

  rc = SQLEndTran(SQL_HANDLE_DBC, context->transaction_handle->hdbc, SQL_ROLLBACK);
  if (!SQL_SUCCEEDED(rc))
    rdf_virtuoso_ODBC_Errors("SQLEndTran(hdbc,ROLLBACK)", storage->world, context->transaction_handle);

  librdf_storage_virtuoso_release_handle(storage, context->transaction_handle);
  context->transaction_handle=NULL;
      
  return (SQL_SUCCEEDED(rc) ? 0 : 1);
}


/**
 * librdf_storage_virtuoso_transaction_get_handle:
 * @storage: the storage object
 * 
 * Get the current transaction handle.
 * 
 * Return value: non-0 on failure 
 **/
static void*
librdf_storage_virtuoso_transaction_get_handle(librdf_storage* storage)
{
  librdf_storage_virtuoso_context *context=(librdf_storage_virtuoso_context *)storage->context;

#ifdef VIRT_DEBUG
  fprintf(stderr, "librdf_storage_virtuoso_transaction_get_handle \n");
#endif

  return context->transaction_handle;
}



/* local function to register Virtuoso storage functions */
static void
librdf_storage_virtuoso_register_factory(librdf_storage_factory *factory)
{
  factory->context_length     = sizeof(librdf_storage_virtuoso_context);
  factory->init               = librdf_storage_virtuoso_init;
  factory->terminate          = librdf_storage_virtuoso_terminate;
  factory->open               = librdf_storage_virtuoso_open;
  factory->close              = librdf_storage_virtuoso_close;
  factory->sync               = librdf_storage_virtuoso_sync;
  factory->size               = librdf_storage_virtuoso_size;
  factory->add_statement      = librdf_storage_virtuoso_add_statement;
  factory->add_statements     = librdf_storage_virtuoso_add_statements;
  factory->remove_statement   = librdf_storage_virtuoso_remove_statement;
  factory->contains_statement = librdf_storage_virtuoso_contains_statement;
  factory->serialise          = librdf_storage_virtuoso_serialise;
  factory->find_statements    = librdf_storage_virtuoso_find_statements;
  factory->find_statements_with_options    = librdf_storage_virtuoso_find_statements_with_options;
  factory->context_add_statement      = librdf_storage_virtuoso_context_add_statement;
  factory->context_add_statements     = librdf_storage_virtuoso_context_add_statements;
  factory->context_remove_statement   = librdf_storage_virtuoso_context_remove_statement;
  factory->context_remove_statements  = librdf_storage_virtuoso_context_remove_statements;
  factory->context_serialise          = librdf_storage_virtuoso_context_serialise;
  factory->find_statements_in_context = librdf_storage_virtuoso_find_statements_in_context;
  factory->get_contexts               = librdf_storage_virtuoso_get_contexts;
  factory->get_feature                = librdf_storage_virtuoso_get_feature;

  factory->transaction_start             = librdf_storage_virtuoso_transaction_start;
  factory->transaction_start_with_handle = librdf_storage_virtuoso_transaction_start_with_handle;
  factory->transaction_commit            = librdf_storage_virtuoso_transaction_commit;
  factory->transaction_rollback          = librdf_storage_virtuoso_transaction_rollback;
  factory->transaction_get_handle        = librdf_storage_virtuoso_transaction_get_handle;
}

void
librdf_init_storage_virtuoso(librdf_world *world)
{
  librdf_storage_register_factory(world, "virtuoso", "OpenLink Virtuoso Universal Server store",
                                  &librdf_storage_virtuoso_register_factory);
}



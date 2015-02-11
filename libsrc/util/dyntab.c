/*
 *  dyntab.c
 *
 *  $Id$
 *
 *  Dynamic Tables
 *  
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *  
 *  Copyright (C) 1998-2015 OpenLink Software
 *  
 *  This project is free software; you can redistribute it and/or modify it
 *  under the terms of the GNU General Public License as published by the
 *  Free Software Foundation; only version 2 of the License, dated June 1991.
 *  
 *  This program is distributed in the hope that it will be useful, but
 *  WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 *  General Public License for more details.
 *  
 *  You should have received a copy of the GNU General Public License along
 *  with this program; if not, write to the Free Software Foundation, Inc.,
 *  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
 *  
 *  
*/

#include <libutil.h>
#include "dyntab.h"

#undef malloc
#undef calloc
#undef free

#define RNDUP_BYTES	4
#define RNDUP(x)  ((((x) + RNDUP_BYTES - 1) / RNDUP_BYTES) * RNDUP_BYTES)

#define KEYFL_UNIQUE		0x0001

#define INITNKEYS		2
#define INCRNKEYS		2

struct htelem_t
  {
    struct htelem_t *	next;
    struct htelem_t **	pprev;
  };
typedef struct htelem_t htelem_t;

struct htkey_t
  {
    u_short		flags;
    hthashfun_t		hashFunc;
    htcomparefun_t	compareFunc;
    htelem_t **		hashTable;
    u_int		hashSize;
    u_int		recordCount;
  };
typedef struct htkey_t htkey_t;

struct httable_t
  {
    u_int		maxRecords;
    u_int		numRecords;
    u_int		freeRecords;
    u_short		incrRecords;
    u_int		recordSize;
    htrecord_t *	records;
    u_short		maxKeys;
    u_short		numKeys;
    u_short		headerSize;
    htkey_t *		keys;
    htcreatefun_t	createFunc;
    void *		createData;
    htdestroyfun_t	destroyFunc;
  };
typedef struct httable_t httable_t;


/*
 *  Create a dynamic table
 *
 *  On entry:
 *    pTable		pointer to dyntable_t (handle)
 *    initRecords	initial number of records (pointers), or 0
 *    incrRecords	record increment when table full
 *    createFunc	user supplied constructor (optional)
 *    createData	argument for (*createFunc) ()
 *    destroyFunc	user supplied destructor (optional)
 */
int
dtab_create_table (
    dyntable_t *	pTable,
    u_int		recordSize,
    u_int		initRecords,
    u_short		incrRecords,
    htcreatefun_t	createFunc,
    void *		createData,
    htdestroyfun_t	destroyFunc)
{
  dyntable_t table;

  if (pTable == (dyntable_t *)0)
    return DTAB_INVALID_ARG;

  *pTable = (dyntable_t)0;

  table = (httable_t *) calloc (1, sizeof (httable_t));
  if (table == (dyntable_t)0)
    return DTAB_NO_MEMORY;

  /*
   *  Allocate pointers for the records
   */
  if (incrRecords == 0)
    incrRecords = 10;

  if (initRecords != 0)
    {
      table->records = (htrecord_t *) calloc (initRecords, sizeof (htrecord_t));
      if (table->records == (htrecord_t *)0)
	{
	  free (table);
	  return DTAB_NO_MEMORY;
	}
    }

  table->maxRecords = initRecords;
  table->incrRecords = incrRecords;
  table->recordSize = recordSize;
  table->createFunc = createFunc;
  table->createData = createData;
  table->destroyFunc = destroyFunc;
  table->headerSize = RNDUP (sizeof (httable_t *));

  *pTable = table;

  return DTAB_SUCCESS;
}


/*
 *  Destroys the dynamic tablespace.
 *  This also frees all the records in the table.
 *  The user supplied destructor is called before the record is freed.
 */
int
dtab_destroy_table (dyntable_t *pTable)
{
  dyntable_t table;
  u_int i;

  if (pTable == (dyntable_t *)0 || (table = *pTable) == (dyntable_t)0)
    return DTAB_INVALID_ARG;

  /*
   *  Destroy all the records
   */
  if (table->records)
    {
      for (i = 0; i < table->numRecords; i++)
	{
	  if (table->records[i])
	    {
	      /*
	       *  Call the user's destructor on this record
	       */
	      if (table->destroyFunc)
	        (*table->destroyFunc) (table->records[i] + table->headerSize);
	      free (table->records[i]);
	    }
	}
      free (table->records);
    }

  /*
   *  Destroy the hash tables
   */
  if (table->keys)
    {
      for (i = 0; i < table->numKeys; i++)
	free (table->keys[i].hashTable);
      free (table->keys);
    }

  memset (table, 0, sizeof (*table));
  free (table);
  *pTable = (dyntable_t)0;

  return DTAB_SUCCESS;
}


/*
 *  Define a hash table on the record.
 *  There can be as many hash tables on the record as needed.
 *  NOTE:
 *    DEFINE ALL THE HASH TABLES BEFORE RECORDS ARE CREATED!
 */
int
dtab_define_key (
    dyntable_t		table,
    hthashfun_t		hashFunc,
    u_int		hashSize,
    htcomparefun_t	compareFunc,
    int			unique)
{
  htkey_t key;

  /*
   *  Validate arguments
   */
  if (table == (dyntable_t)0 || hashSize == 0 ||
      hashFunc == (hthashfun_t)0 || compareFunc == (htcomparefun_t)0)
    {
      return DTAB_INVALID_ARG;
    }

  /*
   *  Enough room in the key definitions table?
   */
  if (table->numKeys >= table->maxKeys)
    {
      htkey_t *oldKeys;
      htkey_t *newKeys;
      u_short numKeys;

      oldKeys = table->keys;
      numKeys = (table->maxKeys == 0) ? INITNKEYS : table->maxKeys + INCRNKEYS;
      newKeys = (htkey_t *) calloc (numKeys, sizeof (htkey_t));
      if (newKeys == (htkey_t *)0)
	return DTAB_NO_MEMORY;
      if (oldKeys)
	{
	  memcpy (newKeys, table->keys, table->maxKeys * sizeof (htkey_t));
	  free (table->keys);
	}
      table->keys = newKeys;
      table->maxKeys = numKeys;
    }

  /*
   *  Build the new key definition record
   */
  key.recordCount = 0;
  key.flags = unique ? KEYFL_UNIQUE : 0;
  key.compareFunc = compareFunc;
  key.hashFunc = hashFunc;
  key.hashSize = hashSize;
  key.hashTable = (htelem_t **) calloc (hashSize, sizeof (htelem_t *));
  if (key.hashTable == (htelem_t **)0)
    return DTAB_NO_MEMORY;

  table->keys[table->numKeys++] = key;
  table->headerSize =
      RNDUP (table->numKeys * sizeof (htelem_t) + sizeof (httable_t *));

  return DTAB_SUCCESS;
}


/*
 *  Create a new record.
 *
 *  This function does NOT insert the record in the hash tables,
 *  but it is inserted in the master table. So dtab_foreach (table,0,...)
 *  will work for the created but not inserted records.
 */
int
dtab_create_record (dyntable_t table, htrecord_t *pRecord)
{
  htrecord_t record;
  htrecord_t *pStore;

  /*
   *  Validate arguments
   */
  if (table == (dyntable_t)0)
    return DTAB_INVALID_ARG;

  *pRecord = (htrecord_t)0;

  if (pRecord == (htrecord_t *)0)
    return DTAB_INVALID_ARG;

  /*
   *  Allocate the record
   */
  record = (htrecord_t) calloc (1, table->headerSize + table->recordSize);
  if (record == (htrecord_t)0)
    return DTAB_NO_MEMORY;

  /*
   *  Link the record to the table
   */
  *((httable_t **) &record[table->numKeys * sizeof (htelem_t)]) = table;

  /*
   *  Find a slot for the pointer to the record
   */
  if (table->freeRecords)
    {
      for (pStore = table->records; *pStore != (htrecord_t)0; pStore++)
	;
      table->freeRecords--;
    }
  else
    {
      if (table->numRecords >= table->maxRecords)
	{
	  htrecord_t *oldRecords;
	  htrecord_t *newRecords;
	  u_int maxRecords;

	  oldRecords = table->records;
	  maxRecords = table->maxRecords + table->incrRecords;
	  newRecords = (htrecord_t *) calloc (maxRecords, sizeof (htrecord_t));
	  if (newRecords == (htrecord_t *)0)
	    {
	      free (record);
	      return DTAB_NO_MEMORY;
	    }
	  if (oldRecords)
	    {
	      memcpy (newRecords, table->records,
		  table->maxRecords * sizeof (htrecord_t));
	      free (table->records);
	    }
	  pStore = &newRecords[table->numRecords++];
	  table->records = newRecords;
	  table->maxRecords = maxRecords;
	}
      else
	pStore = &table->records[table->numRecords++];
    }

  *pStore = record;
  *pRecord = record += table->headerSize;

  /*
   *  Call user function to initialize the record
   */
  if (table->createFunc)
    (*table->createFunc) (record, table->createData);

  return DTAB_SUCCESS;
}


/*
 *  Delete a record from its table.
 *  The user supplied destructor is called, if supplied.
 *  The record is freed.
 */
int
dtab_delete_record (htrecord_t *pRecord)
{
  htrecord_t record;
  htrecord_t internalRec;
  httable_t **pTable;
  httable_t *table;
  u_int ri;
  u_int ki;

  if (pRecord == (htrecord_t *)0 || (record = *pRecord) == (htrecord_t)0)
    return DTAB_INVALID_ARG;

  /*
   *  Get the pointer to the table
   */
  pTable = (httable_t **) &record[- sizeof (htrecord_t *)];
  table = *pTable;
  if (table == NULL)
    return DTAB_INVALID_ARG;

  /*
   *  Search the record in the table
   */
  internalRec = record - table->headerSize;
  for (ri = 0; ri < table->numRecords; ri++)
    {
      if (table->records[ri] == internalRec)
	{
	  /*
	   *  Call user function to free the record
	   */
	  if (table->destroyFunc)
	    (*table->destroyFunc) (record);

	  /*
	   *  Remove from the hash chains
	   */
	  for (ki = 0; ki < table->numKeys; ki++)
	    {
              htelem_t *elem = &((htelem_t *) internalRec)[ki];
	      if (elem->next || elem->pprev)
		{
		  table->keys[ki].recordCount--;
		  if (elem->pprev)
		    *elem->pprev = elem->next;
		  if (elem->next)
		    elem->next->pprev = elem->pprev;
		}
	    }

	  /*
	   *  Remove the record from the table
	   */
	  table->records[ri] = (htrecord_t)0;
	  table->freeRecords++;

	  *pTable = (httable_t *)0;	/* Clear table link */
	  *pRecord = (htrecord_t)0;	/* Clear application handle */

	  free (internalRec);

	  return DTAB_SUCCESS;
	}
    }

  return DTAB_INVALID_ARG;
}


/*
 *  Add a record to the table.
 *  This record must be allocated with dtab_create_record.
 *  The record is inserted in all the defined hash tables.
 *  Note: after changing one of the key values in the record, call
 *  this function again to re-establish the position on the hash chains.
 */
int
dtab_add_record (htrecord_t record)
{
  httable_t *table;

  if (record == NULL)
    return DTAB_INVALID_ARG;

  table = * (httable_t **) &record[- sizeof (htrecord_t *)];
  if (table == NULL)
    return DTAB_INVALID_ARG;

  /*
   *  Any hash keys on this table?
   */
  if (table->numKeys != 0)
    {
      htelem_t *hashChain = (htelem_t *) (record - table->headerSize);
      htkey_t *key;
      int ki;

      /*
       *  Add hash entries in all the hashtables
       */
      for (key = table->keys, ki = 0; ki < table->numKeys; ki++, key++)
	{
	  u_int hashValue = key->hashFunc (record) % key->hashSize;
	  htelem_t **pHash = &key->hashTable[hashValue];
	  htelem_t *elem;
	  int doAdd;

	  /*
	   *  Remove from the hash chain
	   */
	  if (hashChain[ki].next || hashChain[ki].pprev)
	    {
	      key->recordCount--;
	      if (hashChain[ki].pprev)
		*hashChain[ki].pprev = hashChain[ki].next;
	      if (hashChain[ki].next)
	        hashChain[ki].next->pprev = hashChain[ki].pprev;
	    }

	  /*
	   *  Make sure no dups are entered when unique flag is set
	   */
	  doAdd = 1;
	  if (key->flags & KEYFL_UNIQUE)
	    {
	      for (elem = *pHash; elem; elem = elem[ki].next)
		{
		  if ((*key->compareFunc) (record,
		      (htrecord_t) elem + table->headerSize) == 0)
		    {
		      doAdd = 0;
		      break;
		    }
		}
	    }
	  if (!doAdd)
	    continue;

	  key->recordCount++;
	  if (*pHash)
	    (*pHash)[ki].pprev = &hashChain[ki].next;
	  hashChain[ki].pprev = pHash;
	  hashChain[ki].next = *pHash;
	  *pHash = hashChain;
	}
    }

  return DTAB_SUCCESS;
}


/*
 *  Process all the records, calling a user function
 *
 *  If keyNum == 0, then the master table is used to find the records.
 *  For other values [1..number_of_keys_defined], the corresponging hashtable
 *  will be used
 */
int
dtab_foreach (
    dyntable_t	table,
    int		keyNum,
    htuserfun_t	function,
    void *	argument)
{
  u_int ri;

  if (table == (httable_t *)0 || function == (htuserfun_t)0)
    return DTAB_INVALID_ARG;

  /*
   *  KeyNum 0: the master table
   */
  if (keyNum == 0)
    {
      for (ri = 0; ri < table->numRecords; ri++)
	{
	  if (table->records[ri])
	    (*function) (table->records[ri] + table->headerSize, argument);
	}
    }

  /*
   *  Other KeyNum values: use the supplied hash table
   */
  else if (keyNum <= table->numKeys)
    {
      htkey_t *key;
      u_int ki;

      key = &table->keys[--keyNum];

      for (ki = 0; ki < key->hashSize; ki++)
	{
	  htelem_t *elem, *nextElem;

	  elem = key->hashTable[ki];
	  while (elem)
	    {
	      nextElem = elem[keyNum].next;
	      (*function) ((htrecord_t) elem + table->headerSize, argument);
	      elem = nextElem;
	    }
	}
    }
  else
    return DTAB_INVALID_ARG;

  return DTAB_SUCCESS;
}


/*
 *  Check if a record exists in one of the hash indexes.
 *  It is not necessary for the supplied record to be
 *  allocated with dtab_create_record.
 *
 *  Returns TRUE when the record exists, or FALSE when it
 *  doesn't exist, or when the parameters are incorrect.
 */
int
dtab_exist (dyntable_t table, u_int keyNum, htrecord_t record)
{
  return dtab_find_record (table, keyNum, record) != NULL;
}


htrecord_t
dtab_find_record (dyntable_t table, u_int keyNum, htrecord_t record)
{
  if (table == (httable_t *)0 || record == (htrecord_t)0)
    return NULL;

  if (--keyNum <= table->numKeys)
    {
      htkey_t *key = &table->keys[keyNum];
      u_int hashValue = key->hashFunc (record) % key->hashSize;
      htelem_t *elem;

      for (elem = key->hashTable[hashValue]; elem; elem = elem[keyNum].next)
	{
	  if ((*key->compareFunc) (record,
	      (htrecord_t) elem + table->headerSize) == 0)
	    {
	      return (htrecord_t) elem + table->headerSize;
	    }
	}
    }

  return NULL;
}


/*
 *  Return the number of records in the table space.
 *
 *  KeyNum == 0:  return # records in the master table
 *  Other values: return # records on the n'th hash chain
 *
 *  Note: will return 0 for illegal argument values
 */
u_int
dtab_record_count (dyntable_t table, u_int keyNum)
{
  if (table == (httable_t *)0)
    return 0;

  if (keyNum == 0)
    return table->numRecords - table->freeRecords;
  else if (--keyNum < table->numKeys)
    return table->keys[keyNum].recordCount;
  else
    return 0;
}


int
dtab_make_list (
    dyntable_t		table,
    u_int		keyNum,
    u_int *		pNumRecords,
    htrecord_t **	pRecords)
{
  htrecord_t *indexTable;
  u_int numRecords;
  u_int counter;
  htkey_t *key;
  u_int ki;
  u_int ri;

  if (table == (httable_t *)0 || pRecords == NULL)
    return DTAB_INVALID_ARG;

  counter = 0;

  /*
   *  KeyNum 0: the master table
   */
  if (keyNum == 0)
    {
      numRecords = table->numRecords - table->freeRecords;
      indexTable = (htrecord_t *) malloc (numRecords * sizeof (htrecord_t));
      if (indexTable == NULL)
	return DTAB_NO_MEMORY;

      for (ri = 0; ri < table->numRecords; ri++)
	{
	  if (table->records[ri])
	    indexTable[counter++] = table->records[ri] + table->headerSize;
	}
    }

  /*
   *  Other KeyNum values: use the supplied hash table
   */
  else if (keyNum <= table->numKeys)
    {
      key = &table->keys[--keyNum];
      numRecords = key->recordCount;
      indexTable = (htrecord_t *) malloc (numRecords * sizeof (htrecord_t));
      if (indexTable == NULL)
	return DTAB_NO_MEMORY;

      for (ki = 0; ki < key->hashSize; ki++)
	{
	  htelem_t *elem, *nextElem;

	  elem = key->hashTable[ki];
	  while (elem)
	    {
	      nextElem = elem[keyNum].next;
	      indexTable[counter++] = (htrecord_t) elem + table->headerSize;
	      elem = nextElem;
	    }
	}
    }
  else
    return DTAB_INVALID_ARG;

  *pNumRecords = counter;
  *pRecords = indexTable;

  return DTAB_SUCCESS;
}


#ifdef DTAB_DEBUG
int
dtab_debug (dyntable_t table)
{
  u_int ki;
  u_int ri;

  if (table == (httable_t *)0)
    return DTAB_INVALID_ARG;

  printf ("recordSize  = %u\n", table->recordSize);
  printf ("numRecords  = %u\n", table->numRecords);
  printf ("freeRecords = %u\n", table->freeRecords);
  printf ("incrRecords = %u\n", table->incrRecords);
  printf ("maxRecords  = %u\n", table->maxRecords);
  printf ("maxKeys     = %u\n", table->maxKeys);
  printf ("numKeys     = %u\n", table->numKeys);
  printf ("headerSize  = %u\n", table->headerSize);

  printf ("alloc list  = ");
  for (ri = 0; ri < table->numRecords; ri++)
    {
      if (table->records[ri])
	putchar ('1');
      else
	putchar ('0');
    }
  putchar ('\n');

  printf ("keys:\n");
  for (ki = 0; ki < table->numKeys; ki++)
    {
      htkey_t *key = &table->keys[ki];

      printf ("  %u. compareFunc=%08lX hashFunc=%08lX flags=%04X hashSize=%u\n",
	  ki + 1,
	  (u_long) key->compareFunc, (u_long) key->hashFunc, key->flags,
	  key->hashSize);

      for (ri = 0; ri < key->hashSize; ri++)
	{
          htelem_t *hashChain = key->hashTable[ri];
	  htelem_t *elem;

	  if (hashChain == NULL)
	    printf ("    ht[%u] = NULL\n", ri);
	  else
	    {
	      printf ("    ht[%u] =", ri);
	      for (elem = hashChain; elem; elem = elem[ki].next)
		{
		  htrecord_t record = (htrecord_t) elem + table->headerSize;
		  printf (" %08lX", (u_long) record);
		}
	      putchar ('\n');
	    }
	}
    }

  return DTAB_SUCCESS;
}
#endif

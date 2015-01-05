/*
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
 */

#include "Dk.h"
#include "xmlparser_impl.h"
/* stubs */
int f_read_from_rebuilt_database;
int f_config_file;
/* end of stubs */

typedef ptrlong (*array_reader)(void* array, ptrlong idx);

void printarray(void* array, array_reader reader)
{
  ptrlong i;
  char buf[80*100+1];
  char namebuf[11];
  char *ptr=buf;

  memset(buf,' ',80*100);
  for (i=0;i<10;i++)
    {
      sprintf (namebuf,"%ld",i);
      memcpy(ptr,namebuf,strlen(namebuf));
      ptr+=8;
    }
  *(ptr++)='\n';
  memset(ptr,'-',80);
  ptr+=80;
  *(ptr++)='\n';
  for (i=0;i<100;i++)
    {
      ptrlong res = reader(array,i);
      sprintf (namebuf,"%ld",res);
      memcpy(ptr,namebuf,strlen(namebuf));
      ptr+=8;
      if ((i%10) == 9)
	*(ptr++)='\n';
    }
  ptr[0]=0;

  printf("%s",buf);
}

static
ptrlong get_idx (struct xecm_big_array_s* array, ptrlong idx)
{
  xecm_st_info_t* info = (xecm_st_info_t*)xecm_ba_get_val((void*)array,idx);
  if (info)
    return info->xsi_idx;
  *((int*)0)=0;
  return 0; /* keep compiler happy */
}

int main()
{
  struct xecm_big_array_s* array = xecm_create_big_array(sizeof(ptrlong));
  struct xecm_nexts_array_s* nexts = xecm_nexts_allocate(XECM_STORAGE_RARE, 100, 1);
  struct xecm_nexts_array_s* nexts_copy;
  const char* array1[]={"aaaa","cccc", "eeee", "ggggg", "hhhh", "xxxxx"};
  const char* array2[]={"bbb","ddddd", "ffff", "iiiii", "jjjj", "zzzzz", "tttt"};
  char **a1 = 0, **a2 = 0;
  ptrlong sz1 = 0, sz2 = 0;
  ptrlong i=0;

  for (i=0;i<sizeof(array1)/sizeof(char*);i++)
    ecm_add_name(array1[i],(void**)&a1,&sz1,sizeof(char*));
  for (i=0;i<sizeof(array2)/sizeof(char*);i++)
    ecm_add_name(array2[i],(void**)&a2,&sz2,sizeof(char*));

  if (-1 == ecm_fuse_arrays((caddr_t*)&a1, &sz1,
		      (caddr_t)a2,sz2, sizeof(char*)))
  { printf("fuse failed\n"); }
  else
  {
    for (i=0;i<sz1;i++)
	printf ("a1[%ld]=%s\n", i, a1[i]);
  }
    


  


/*  xecm_ba_set_val(array, 1, 2);
  xecm_ba_set_val(array, 2, 4);
  xecm_ba_set_val(array, 3, 8);
  xecm_ba_set_val(array, 8, 255);
  xecm_ba_set_val(array, 16, 256*256-1);
  xecm_ba_set_val(array, 10, 100);
  xecm_ba_set_val(array, 99, 100000); */

  xecm_set_nextidx(nexts, 1, 2);
  xecm_set_nextidx(nexts, 2, 4);
  xecm_set_nextidx(nexts, 3, 8);
  xecm_set_nextidx(nexts, 8, 255);
  xecm_set_nextidx(nexts, 3, 9);
  xecm_set_nextidx(nexts, 16, 256*256-1);
  xecm_set_nextidx(nexts, 3, 13);
  xecm_set_nextidx(nexts, 10, 100);
  xecm_set_nextidx(nexts, 99, 100000);
  xecm_set_nextidx(nexts, 1, 11);
  xecm_set_nextidx(nexts, 2, 12);

  nexts_copy = xecm_copy_nexts(nexts);

  printf("0\\\n");
  printarray(array,(array_reader)xecm_ba_get_val);
  printf("1\\\n");
  printarray(nexts,(array_reader)xecm_get_nextidx);
  printf("2\\\n");
  printarray(nexts->na_nexts.rare,(array_reader)get_idx); 
  printf("3\\\n");
  printarray(nexts_copy->na_nexts.rare,(array_reader)get_idx); 
  xecm_nexts_free(nexts);
  xecm_nexts_free(nexts_copy);
  return 0;
}


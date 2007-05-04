/*
 *  
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *  
 *  Copyright (C) 1998-2006 OpenLink Software
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
#ifdef _USRDLL
#include "plugin.h"
#include "import_gate_virtuoso.h"
#define wi_inst (wi_instance_get()[0])
#else
#include <libutil.h>
#include "sqlnode.h"
#include "sqlbif.h"
#include "wi.h"
#include "Dk.h"
#endif

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#include <wand/magick-wand.h>

#define IM_VERSION "0.4"

static dk_mutex_t *im_mutex = NULL;
static caddr_t im_IMVERSION = NULL;
static caddr_t *im_env = NULL;

#define WandExitMacro(wand) \
{ \
  DestroyMagickWand(wand);\
  MagickWandTerminus();\
  mutex_leave (im_mutex); \
}

#define WandExitMacroExt(wand,draw,pixel) \
{ \
  DestroyMagickWand(wand); \
  if (NULL != draw) \
    DestroyDrawingWand (draw); \
  if (NULL != pixel) \
    DestroyPixelWand(pixel); \
  MagickWandTerminus();\
  mutex_leave (im_mutex); \
}

MagickBooleanType status;
MagickWand *magick_wand;

caddr_t bif_im_CropImageFile (caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  caddr_t new_file_name;
  caddr_t file_name = bif_string_arg (qst, args, 0, "IM CropImageFile");
  unsigned long width = (unsigned long) bif_long_arg (qst, args, 1, "IM CropImageFile");
  unsigned long height = (unsigned long) bif_long_arg (qst, args, 2, "IM CropImageFile");
  long x = bif_long_arg (qst, args, 3, "IM CropImageFile");
  long y = bif_long_arg (qst, args, 4, "IM CropImageFile");
  int n_args = BOX_ELEMENTS(args);
  if (n_args > 5)
    new_file_name = bif_string_arg (qst, args, 5, "IM CropImageFile");
  else
    new_file_name = bif_string_arg (qst, args, 0, "IM CropImageFile");
  mutex_enter (im_mutex);
  MagickWandGenesis();
  magick_wand=NewMagickWand();
  status=MagickReadImage(magick_wand, file_name);
  if (status == MagickFalse)
  {
    WandExitMacro(magick_wand);
    sqlr_new_error ("22023", "IM001", "bif_im_CropImageFile cannot open file");
  }
  MagickResetIterator(magick_wand);
  while (MagickNextImage(magick_wand) != MagickFalse)
  {
    MagickCropImage(magick_wand, width, height, x, y);
  }
  if (new_file_name)
    status=MagickWriteImages(magick_wand, new_file_name, MagickTrue);
  else
    status=MagickWriteImages(magick_wand, file_name, MagickTrue);
  if (status == MagickFalse)
  {
    WandExitMacro(magick_wand);
    sqlr_new_error ("22023", "IM001", "bif_im_CropImageFile cannot write image into file");
  }
  magick_wand=DestroyMagickWand(magick_wand);
  MagickWandTerminus();
  mutex_leave (im_mutex);
  return (0);
}

caddr_t bif_im_CropImageFileToBlob(caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  size_t length = 0;
  caddr_t res, image_blob;
  caddr_t file_name = bif_string_arg (qst, args, 0, "IM CropImageFileToBlob");
  unsigned long width = bif_long_arg (qst, args, 1, "IM CropImageFileToBlob");
  unsigned long height = bif_long_arg (qst, args, 2, "IM CropImageFileToBlob");
  long x = bif_long_arg (qst, args, 3, "IM CropImageFileToBlob");
  long y = bif_long_arg (qst, args, 4, "IM CropImageFileToBlob");
  mutex_enter (im_mutex);
  MagickWandGenesis();
  magick_wand=NewMagickWand();
  status=MagickReadImage(magick_wand, file_name);
  if (status == MagickFalse)
  {
    WandExitMacro(magick_wand);
    sqlr_new_error ("22023", "IM001", "bif_im_CropImageFileToBlob cannot open file");
  }
  MagickResetIterator(magick_wand);
  while (MagickNextImage(magick_wand) != MagickFalse)
  {
    MagickCropImage(magick_wand, width, height, x, y);
  }
  image_blob = MagickGetImagesBlob(magick_wand, &length);
  if (length != 0)
  {
    res = dk_alloc_box(length, DV_BIN);
    memcpy (res, image_blob, length);
    MagickRelinquishMemory(image_blob);
  }
  else
    res = NEW_DB_NULL;
  magick_wand=DestroyMagickWand(magick_wand);
  MagickWandTerminus();
  mutex_leave (im_mutex);
  return res;
}

caddr_t bif_im_GetImageFileAttribute(caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  caddr_t res, key_value = NULL;
  caddr_t file_name = bif_string_arg (qst, args, 0, "IM GetImageFileAttribute");
  caddr_t key = bif_string_arg (qst, args, 1, "IM GetImageFileAttribute");
  mutex_enter (im_mutex);
  MagickWandGenesis();
  magick_wand=NewMagickWand();
  status=MagickReadImage(magick_wand, file_name);
  if (status == MagickFalse)
  {
    WandExitMacro(magick_wand);
    sqlr_new_error ("22023", "IM001", "bif_im_GetImageFileAttribute cannot open file");
  }
  MagickResetIterator(magick_wand);
  while (MagickNextImage(magick_wand) != MagickFalse)
  {
    key_value = MagickGetImageAttribute(magick_wand, key);
  }
  if (key_value)
  {
    res = box_dv_short_string(key_value);
    MagickRelinquishMemory(key_value);
  }
  else
    res = NEW_DB_NULL;
  magick_wand=DestroyMagickWand(magick_wand);
  MagickWandTerminus();
  mutex_leave (im_mutex);
  return res;
}

caddr_t bif_im_GetImageFileFormat(caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  caddr_t res, key_value;
  caddr_t file_name = bif_string_arg (qst, args, 0, "IM GetImageFileFormat");
  mutex_enter (im_mutex);
  MagickWandGenesis();
  magick_wand=NewMagickWand();
  status=MagickReadImage(magick_wand, file_name);
  if (status == MagickFalse)
  {
    WandExitMacro(magick_wand);
    sqlr_new_error ("22023", "IM001", "bif_im_GetImageFileFormat cannot open file");
  }
  MagickResetIterator(magick_wand);
  while (MagickNextImage(magick_wand) != MagickFalse)
  {
    key_value = MagickGetImageFormat(magick_wand);
  }
  if (key_value)
    res = box_dv_short_string(key_value);
  else
    res = NEW_DB_NULL;
  magick_wand=DestroyMagickWand(magick_wand);
  MagickWandTerminus();
  mutex_leave (im_mutex);
  return res;
}

caddr_t bif_im_GetImageFileIdentify(caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  caddr_t res, key_value;
  caddr_t file_name = bif_string_arg (qst, args, 0, "IM GetImageFileIdentify");
  mutex_enter (im_mutex);
  MagickWandGenesis();
  magick_wand=NewMagickWand();
  status=MagickReadImage(magick_wand, file_name);
  if (status == MagickFalse)
  {
    WandExitMacro(magick_wand);
    sqlr_new_error ("22023", "IM001", "bif_im_GetImageFileIdentify cannot open file");
  }
  MagickResetIterator(magick_wand);
  while (MagickNextImage(magick_wand) != MagickFalse)
  {
    key_value = MagickIdentifyImage(magick_wand);
  }
  if (key_value)
    res = box_dv_short_string(key_value);
  else
    res = NEW_DB_NULL;
  magick_wand=DestroyMagickWand(magick_wand);
  MagickWandTerminus();
  mutex_leave (im_mutex);
  return res;
}

caddr_t bif_im_GetImageBlobIdentify(caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  caddr_t res, key_value;
  char in_name[64];
  caddr_t blob = bif_string_arg (qst, args, 0, "IM GetImageBlobIdentify");
  long blob_size = bif_long_arg (qst, args, 1, "IM GetImageBlobIdentify");
        int n_args = BOX_ELEMENTS(args);
  char* in_format = n_args > 2 ? bif_string_arg (qst, args, 2, "IM GetImageBlobIdentify") : NULL;
  key_value = 0;
  mutex_enter (im_mutex);
  MagickWandGenesis();
  magick_wand=NewMagickWand();
        if (in_format != NULL)
        {
                if (strlen(in_format) < 30)
                {
                        strcpy(in_name, "image.");
                        strcat(in_name, in_format);
                        MagickSetFilename(magick_wand, in_name);
                }
        }
  status=MagickReadImageBlob(magick_wand, (const void *)blob, (const size_t)blob_size);
  if (status == MagickFalse)
  {
    WandExitMacro(magick_wand);
    sqlr_new_error ("22023", "IM001", "bif_im_GetImageBlobIdentify cannot read blob");
  }
  MagickResetIterator(magick_wand);
  while (MagickNextImage(magick_wand) != MagickFalse)
  {
    key_value = MagickIdentifyImage(magick_wand);
  }
  if (key_value)
    res = box_dv_short_string(key_value);
  else
    res = NEW_DB_NULL;
  magick_wand=DestroyMagickWand(magick_wand);
  MagickWandTerminus();
  mutex_leave (im_mutex);
  return res;
}

caddr_t bif_im_GetImageFileWidth(caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  caddr_t res;
  unsigned long key_value;
  caddr_t file_name = bif_string_arg (qst, args, 0, "IM GetImageFileWidth");
  key_value = 0;
  mutex_enter (im_mutex);
  MagickWandGenesis();
  magick_wand=NewMagickWand();
  status=MagickReadImage(magick_wand, file_name);
  if (status == MagickFalse)
  {
    WandExitMacro(magick_wand);
    sqlr_new_error ("22023", "IM001", "bif_im_GetImageFileWidth cannot open file");
  }
  MagickResetIterator(magick_wand);
  while (MagickNextImage(magick_wand) != MagickFalse)
  {
    key_value = MagickGetImageWidth(magick_wand);
  }
  if (key_value)
    res = box_num(key_value);
  else
    res = NEW_DB_NULL;
  magick_wand=DestroyMagickWand(magick_wand);
  MagickWandTerminus();
  mutex_leave (im_mutex);
  return res;
}

caddr_t bif_im_GetImageFileDepth(caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  caddr_t res;
  unsigned long key_value;
  caddr_t file_name = bif_string_arg (qst, args, 0, "IM GetImageFileDepth");
  key_value = 0;
  mutex_enter (im_mutex);
  MagickWandGenesis();
  magick_wand=NewMagickWand();
  status=MagickReadImage(magick_wand, file_name);
  if (status == MagickFalse)
  {
    WandExitMacro(magick_wand);
    sqlr_new_error ("22023", "IM001", "bif_im_GetImageFileDepth cannot open file");
  }
  MagickResetIterator(magick_wand);
  while (MagickNextImage(magick_wand) != MagickFalse)
  {
    key_value = MagickGetImageDepth(magick_wand);
  }
  if (key_value)
    res = box_num(key_value);
  else
    res = NEW_DB_NULL;
  magick_wand=DestroyMagickWand(magick_wand);
  MagickWandTerminus();
  mutex_leave (im_mutex);
  return res;
}

caddr_t bif_im_GetImageFileHeight(caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  caddr_t res;
  unsigned long key_value;
  caddr_t file_name = bif_string_arg (qst, args, 0, "IM GetImageFileHeight");
  key_value = 0;
  mutex_enter (im_mutex);
  MagickWandGenesis();
  magick_wand=NewMagickWand();
  status=MagickReadImage(magick_wand, file_name);
  if (status == MagickFalse)
  {
    WandExitMacro(magick_wand);
    sqlr_new_error ("22023", "IM001", "bif_im_GetImageFileHeight cannot open file");
  }
  MagickResetIterator(magick_wand);
  while (MagickNextImage(magick_wand) != MagickFalse)
  {
    key_value = MagickGetImageHeight(magick_wand);
  }
  if (key_value)
    res = box_num(key_value);
  else
    res = NEW_DB_NULL;
  magick_wand=DestroyMagickWand(magick_wand);
  MagickWandTerminus();
  mutex_leave (im_mutex);
  return res;
}

caddr_t bif_im_GetImageBlobWidth(caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  caddr_t res;
  unsigned long key_value;
	char in_name[64];
  caddr_t blob = bif_string_arg (qst, args, 0, "IM GetImageBlobWidth");
  long blob_size = bif_long_arg (qst, args, 1, "IM GetImageBlobWidth");
	int n_args = BOX_ELEMENTS(args);
  char* in_format = n_args > 2 ? bif_string_arg (qst, args, 2, "IM GetImageBlobWidth") : NULL;
  key_value = 0;
  mutex_enter (im_mutex);
  MagickWandGenesis();
  magick_wand=NewMagickWand();
	if (in_format != NULL)
	{
		if (strlen(in_format) < 30)
		{
			strcpy(in_name, "image.");
			strcat(in_name, in_format);
			MagickSetFilename(magick_wand, in_name);
		}
	}
  status=MagickReadImageBlob(magick_wand, (const void *)blob, (const size_t)blob_size);
  if (status == MagickFalse)
  {
    WandExitMacro(magick_wand);
    sqlr_new_error ("22023", "IM001", "bif_im_GetImageBlobWidth cannot read blob");
  }
  MagickResetIterator(magick_wand);
  while (MagickNextImage(magick_wand) != MagickFalse)
  {
    key_value = MagickGetImageWidth(magick_wand);
  }
  if (key_value)
    res = box_num(key_value);
  else
    res = NEW_DB_NULL;
  magick_wand=DestroyMagickWand(magick_wand);
  MagickWandTerminus();
  mutex_leave (im_mutex);
  return res;
}

caddr_t bif_im_GetImageBlobDepth(caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  caddr_t res;
  unsigned long key_value;
	char in_name[64];
  caddr_t blob = bif_string_arg (qst, args, 0, "IM GetImageBlobDepth");
  long blob_size = bif_long_arg (qst, args, 1, "IM GetImageBlobDepth");
	int n_args = BOX_ELEMENTS(args);
  char* in_format = n_args > 2 ? bif_string_arg (qst, args, 2, "IM GetImageBlobDepth") : NULL;
  key_value = 0;
  mutex_enter (im_mutex);
  MagickWandGenesis();
  magick_wand=NewMagickWand();
	if (in_format != NULL)
	{
		if (strlen(in_format) < 30)
		{
			strcpy(in_name, "image.");
			strcat(in_name, in_format);
			MagickSetFilename(magick_wand, in_name);
		}
	}
  status=MagickReadImageBlob(magick_wand, (const void *)blob, (const size_t)blob_size);
  if (status == MagickFalse)
  {
    WandExitMacro(magick_wand);
    sqlr_new_error ("22023", "IM001", "bif_im_GetImageBlobDepth cannot read blob");
  }
  MagickResetIterator(magick_wand);
  while (MagickNextImage(magick_wand) != MagickFalse)
  {
    key_value = MagickGetImageDepth(magick_wand);
  }
  if (key_value)
    res = box_num(key_value);
  else
    res = NEW_DB_NULL;
  magick_wand=DestroyMagickWand(magick_wand);
  MagickWandTerminus();
  mutex_leave (im_mutex);
  return res;
}

caddr_t bif_im_GetImageBlobHeight(caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  caddr_t res;
  unsigned long key_value;
	char in_name[64];
  caddr_t blob = bif_string_arg (qst, args, 0, "IM GetImageBlobHeight");
  long blob_size = bif_long_arg (qst, args, 1, "IM GetImageBlobHeight");
	int n_args = BOX_ELEMENTS(args);
  char* in_format = n_args > 2 ? bif_string_arg (qst, args, 2, "IM GetImageBlobHeight") : NULL;
  key_value = 0;
  mutex_enter (im_mutex);
  MagickWandGenesis();
  magick_wand=NewMagickWand();
	if (in_format != NULL)
	{
		if (strlen(in_format) < 30)
		{
			strcpy(in_name, "image.");
			strcat(in_name, in_format);
			MagickSetFilename(magick_wand, in_name);
		}
	}
  status=MagickReadImageBlob(magick_wand, (const void *)blob, (const size_t)blob_size);
  if (status == MagickFalse)
  {
    WandExitMacro(magick_wand);
    sqlr_new_error ("22023", "IM001", "bif_im_GetImageBlobHeight cannot read blob");
  }
  MagickResetIterator(magick_wand);
  while (MagickNextImage(magick_wand) != MagickFalse)
  {
    key_value = MagickGetImageHeight(magick_wand);
  }
  if (key_value)
    res = box_num(key_value);
  else
    res = NEW_DB_NULL;
  magick_wand=DestroyMagickWand(magick_wand);
  MagickWandTerminus();
  mutex_leave (im_mutex);
  return res;
}

caddr_t bif_im_GetImageBlobFormat(caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  caddr_t res, key_value;
	char in_name[64];
  caddr_t blob = bif_string_arg (qst, args, 0, "IM GetImageBlobFormat");
  long blob_size = bif_long_arg (qst, args, 1, "IM GetImageBlobFormat");
	int n_args = BOX_ELEMENTS(args);
  char* in_format = n_args > 2 ? bif_string_arg (qst, args, 2, "IM GetImageBlobFormat") : NULL;
  mutex_enter (im_mutex);
  MagickWandGenesis();
  magick_wand=NewMagickWand();
	if (in_format != NULL)
	{
		if (strlen(in_format) < 30)
		{
			strcpy(in_name, "image.");
			strcat(in_name, in_format);
			MagickSetFilename(magick_wand, in_name);
		}
	}
  status=MagickReadImageBlob(magick_wand, (const void *)blob, (const size_t)blob_size);
  if (status == MagickFalse)
  {
    WandExitMacro(magick_wand);
    sqlr_new_error ("22023", "IM001", "bif_im_GetImageBlobFormat cannot read blob");
  }
  MagickResetIterator(magick_wand);
  while (MagickNextImage(magick_wand) != MagickFalse)
  {
    key_value = MagickGetImageFormat(magick_wand);
  }
  if (key_value)
    res = box_dv_short_string(key_value);
  else
    res = NEW_DB_NULL;
  magick_wand=DestroyMagickWand(magick_wand);
  MagickWandTerminus();
  mutex_leave (im_mutex);
  return res;
}

caddr_t bif_im_GetImageBlobAttribute(caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  caddr_t res, key_value;
	char in_name[64];
  caddr_t blob = bif_string_arg (qst, args, 0, "IM GetImageBlobAttribute");
  long blob_size = bif_long_arg (qst, args, 1, "IM GetImageBlobAttribute");
  caddr_t key = bif_string_arg (qst, args, 2, "IM GetImageBlobAttribute");
  int n_args = BOX_ELEMENTS(args);
  char* in_format = n_args > 3 ? bif_string_arg (qst, args, 3, "IM GetImageBlobAttribute") : NULL;
  mutex_enter (im_mutex);
  MagickWandGenesis();
  magick_wand=NewMagickWand();
	if (in_format != NULL)
	{
		if (strlen(in_format) < 30)
		{
			strcpy(in_name, "image.");
			strcat(in_name, in_format);
			MagickSetFilename(magick_wand, in_name);
		}
	}
  status=MagickReadImageBlob(magick_wand, (const void *)blob, (const size_t)blob_size);
  if (status == MagickFalse)
  {
    WandExitMacro(magick_wand);
    sqlr_new_error ("22023", "IM001", "bif_im_GetImageBlobAttribute cannot read blob");
  }
  MagickResetIterator(magick_wand);
  while (MagickNextImage(magick_wand) != MagickFalse)
  {
    key_value = MagickGetImageAttribute(magick_wand, key);
  }
  if (key_value)
  {
    res = box_dv_short_string(key_value);
    MagickRelinquishMemory(key_value);
  }
  else
    res = NEW_DB_NULL;
  magick_wand=DestroyMagickWand(magick_wand);
  MagickWandTerminus();
  mutex_leave (im_mutex);
  return res;
}

caddr_t bif_im_CropImageBlob(caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  size_t length = 0;
  caddr_t res, image_blob;
	char in_name[64];
  caddr_t blob = (caddr_t)bif_arg (qst, args, 0, "IM CropImageBlob");
  long blob_size = bif_long_arg (qst, args, 1, "IM CropImageBlob");
  unsigned long width = bif_long_arg (qst, args, 2, "IM CropImageBlob");
  unsigned long height = bif_long_arg (qst, args, 3, "IM CropImageBlob");
  long x = bif_long_arg (qst, args, 4, "IM CropImageBlob");
  long y = bif_long_arg (qst, args, 5, "IM CropImageBlob");
	int n_args = BOX_ELEMENTS(args);
  char* in_format = n_args > 6 ? bif_string_arg (qst, args, 6, "IM CropImageBlob") : NULL;
  mutex_enter (im_mutex);
  MagickWandGenesis();
  magick_wand=NewMagickWand();
	if (in_format != NULL)
	{
		if (strlen(in_format) < 30)
		{
			strcpy(in_name, "image.");
			strcat(in_name, in_format);
			MagickSetFilename(magick_wand, in_name);
		}
	}
  status=MagickReadImageBlob(magick_wand, (const void *)blob, (const size_t)blob_size);
  if (status == MagickFalse)
  {
    WandExitMacro(magick_wand);
    sqlr_new_error ("22023", "IM001", "bif_im_CropImageBlob cannot read blob");
  }
  MagickResetIterator(magick_wand);
  while (MagickNextImage(magick_wand) != MagickFalse)
  {
    MagickCropImage(magick_wand, width, height, x, y);
  }
  image_blob = MagickGetImagesBlob(magick_wand, &length);
  if (length != 0)
  {
    res = dk_alloc_box (length, DV_BIN);
    memcpy (res, image_blob, length);
    MagickRelinquishMemory(image_blob);
  }
  else
    res = NEW_DB_NULL;
  magick_wand=DestroyMagickWand(magick_wand);
  MagickWandTerminus();
  mutex_leave (im_mutex);
  return res;
}

caddr_t bif_im_RotateImageFile (caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  caddr_t new_file_name;
  caddr_t file_name = bif_string_arg (qst, args, 0, "IM RotateImageFile");
  double v_size = bif_double_arg (qst, args, 1, "IM RotateImageFile");
  int n_args = BOX_ELEMENTS(args);
  PixelWand *background;
  if (n_args > 2)
    new_file_name = bif_string_arg (qst, args, 2, "IM RotateImageFile");
  else
    new_file_name = bif_string_arg (qst, args, 0, "IM RotateImageFile");
  mutex_enter (im_mutex);
  MagickWandGenesis();
  magick_wand=NewMagickWand();
  status=MagickReadImage(magick_wand, file_name);
  if (status == MagickFalse)
  {
    WandExitMacro(magick_wand);
    sqlr_new_error ("22023", "IM001", "bif_im_RotateImageFile cannot open file");
  }
  background=NewPixelWand();
  (void) PixelSetColor(background,"#000000");
  if (status == MagickFalse)
  {
    DestroyPixelWand(background);
    WandExitMacro(magick_wand);
    sqlr_new_error ("22023", "IM001", "bif_im_RotateImageFile cannot set color");
  }
  MagickResetIterator(magick_wand);
  while (MagickNextImage(magick_wand) != MagickFalse)
  {
    MagickRotateImage(magick_wand, background, v_size);
  }
  if (new_file_name)
    status=MagickWriteImages(magick_wand, new_file_name, MagickTrue);
  else
    status=MagickWriteImages(magick_wand, file_name, MagickTrue);
  if (status == MagickFalse)
  {
    DestroyPixelWand(background);
    WandExitMacro(magick_wand);
    sqlr_new_error ("22023", "IM001", "bif_im_RotateImageFile cannot write image into file");
  }
  magick_wand=DestroyMagickWand(magick_wand);
  background=DestroyPixelWand(background);
  MagickWandTerminus();
  mutex_leave (im_mutex);
  return (0);
}

caddr_t bif_im_RotateImageFileToBlob (caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  size_t length = 0;
  caddr_t res, image_blob;
  caddr_t file_name = bif_string_arg (qst, args, 0, "IM RotateImageFileToBlob");
  double v_size = bif_double_arg (qst, args, 1, "IM RotateImageFileToBlob");
  int n_args = BOX_ELEMENTS(args);
  PixelWand *background;
  mutex_enter (im_mutex);
  MagickWandGenesis();
  magick_wand=NewMagickWand();
  status=MagickReadImage(magick_wand, file_name);
  if (status == MagickFalse)
  {
    WandExitMacro(magick_wand);
    sqlr_new_error ("22023", "IM001", "bif_im_RotateImageFileToBlob cannot open file");
  }
  background=NewPixelWand();
  (void) PixelSetColor(background,"#000000");
  if (status == MagickFalse)
  {
    DestroyPixelWand(background);
    WandExitMacro(magick_wand);
    sqlr_new_error ("22023", "IM001", "bif_im_RotateImageFileToBlob cannot set color");
  }
  MagickResetIterator(magick_wand);
  while (MagickNextImage(magick_wand) != MagickFalse)
  {
    MagickRotateImage(magick_wand, background, v_size);
  }
  image_blob = MagickGetImagesBlob(magick_wand, &length);
  if (length != 0)
  {
    res = dk_alloc_box (length, DV_BIN);
    memcpy (res, image_blob, length);
    MagickRelinquishMemory(image_blob);
  }
  else
    res = NEW_DB_NULL;
  magick_wand=DestroyMagickWand(magick_wand);
  background=DestroyPixelWand(background);
  MagickWandTerminus();
  mutex_leave (im_mutex);
  return res;
}

caddr_t bif_im_RotateImageBlob (caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  size_t length = 0;
  caddr_t res, image_blob;
	char in_name[64];
  caddr_t blob = (caddr_t)bif_arg (qst, args, 0, "IM RotateImageBlob");
  long blob_size = bif_long_arg (qst, args, 1, "IM RotateImageBlob");
  double v_size = bif_double_arg (qst, args, 2, "IM RotateImageBlob");
  int n_args = BOX_ELEMENTS(args);
  char* in_format = n_args > 3 ? bif_string_arg (qst, args, 3, "IM RotateImageBlob") : NULL;
  PixelWand *background;
  mutex_enter (im_mutex);
  MagickWandGenesis();
  magick_wand=NewMagickWand();
	if (in_format != NULL)
	{
		if (strlen(in_format) < 30)
		{
			strcpy(in_name, "image.");
			strcat(in_name, in_format);
			MagickSetFilename(magick_wand, in_name);
		}
	}
  status=MagickReadImageBlob(magick_wand, (const void *)blob, (const size_t)blob_size);
  if (status == MagickFalse)
  {
    WandExitMacro(magick_wand);
    sqlr_new_error ("22023", "IM001", "bif_im_RotateImageBlob cannot read blob");
  }
  background=NewPixelWand();
  (void) PixelSetColor(background,"#000000");
  if (status == MagickFalse)
  {
    DestroyPixelWand(background);
    WandExitMacro(magick_wand);
    sqlr_new_error ("22023", "IM001", "bif_im_RotateImageBlob cannot set color");
  }
  MagickResetIterator(magick_wand);
  while (MagickNextImage(magick_wand) != MagickFalse)
  {
    MagickRotateImage(magick_wand, background, v_size);
  }
  image_blob = MagickGetImagesBlob(magick_wand, &length);
  if (length != 0)
  {
    res = dk_alloc_box (length, DV_BIN);
    memcpy (res, image_blob, length);
    MagickRelinquishMemory(image_blob);
  }
  else
    res = NEW_DB_NULL;
  magick_wand=DestroyMagickWand(magick_wand);
  background=DestroyPixelWand(background);
  MagickWandTerminus();
  mutex_leave (im_mutex);
  return res;
}

caddr_t bif_im_ResampleImageFile (caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  caddr_t new_file_name;
  caddr_t file_name = bif_string_arg (qst, args, 0, "IM ResampleImageFile");
  double v_size = bif_double_arg (qst, args, 1, "IM ResampleImageFile");
  double h_size = bif_double_arg (qst, args, 2, "IM ResampleImageFile");
  double blur = bif_double_arg (qst, args, 3, "IM ResampleImageFile");
  long filter = bif_long_arg (qst, args, 4, "IM ResampleImageFile");
  int n_args = BOX_ELEMENTS(args);
  if (filter < 0 || filter > 15)
    filter = PointFilter;
  if (n_args > 5)
    new_file_name = bif_string_arg (qst, args, 5, "IM ResampleImageFile");
  else
    new_file_name = bif_string_arg (qst, args, 0, "IM ResampleImageFile");
  mutex_enter (im_mutex);
  MagickWandGenesis();
  magick_wand=NewMagickWand();
  status=MagickReadImage(magick_wand, file_name);
  if (status == MagickFalse)
  {
    WandExitMacro(magick_wand);
    sqlr_new_error ("22023", "IM001", "bif_im_ResampleImageFile cannot open file");
  }
  MagickResetIterator(magick_wand);
  while (MagickNextImage(magick_wand) != MagickFalse)
  {
    MagickResampleImage(magick_wand,v_size, h_size,filter,blur);
  }
  if (new_file_name)
    status=MagickWriteImages(magick_wand, new_file_name, MagickTrue);
  else
    status=MagickWriteImages(magick_wand, file_name, MagickTrue);
  if (status == MagickFalse)
  {
    WandExitMacro(magick_wand);
    sqlr_new_error ("22023", "IM001", "bif_im_ResampleImageFile cannot write image into file");
  }
  magick_wand=DestroyMagickWand(magick_wand);
  MagickWandTerminus();
  mutex_leave (im_mutex);
  return(0);
}

caddr_t bif_im_ResampleImageFileToBlob (caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  size_t length = 0;
  caddr_t res, image_blob;
  caddr_t file_name = bif_string_arg (qst, args, 0, "IM ResampleImageFileToBlob");
  double v_size = bif_double_arg (qst, args, 1, "IM ResampleImageFileToBlob");
  double h_size = bif_double_arg (qst, args, 2, "IM ResampleImageFileToBlob");
  double blur = bif_double_arg (qst, args, 3, "IM ResampleImageFileToBlob");
  long filter = bif_long_arg (qst, args, 4, "IM ResampleImageFileToBlob");
  if (filter < 0 || filter > 15)
    filter = PointFilter;
  mutex_enter (im_mutex);
  MagickWandGenesis();
  magick_wand=NewMagickWand();
  status=MagickReadImage(magick_wand, file_name);
  if (status == MagickFalse)
  {
    WandExitMacro(magick_wand);
    sqlr_new_error ("22023", "IM001", "bif_im_ResampleImageFileToBlob cannot open file");
  }
  MagickResetIterator(magick_wand);
  while (MagickNextImage(magick_wand) != MagickFalse)
  {
    MagickResampleImage(magick_wand,v_size, h_size,filter,blur);
  }
  image_blob = MagickGetImagesBlob(magick_wand, &length);
  if (length != 0)
  {
    res = dk_alloc_box (length, DV_BIN);
    memcpy (res, image_blob, length);
    MagickRelinquishMemory(image_blob);
  }
  else
    res = NEW_DB_NULL;
  magick_wand=DestroyMagickWand(magick_wand);
  MagickWandTerminus();
  mutex_leave (im_mutex);
  return res;
}

caddr_t bif_im_ResampleImageBlob (caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  size_t length = 0;
  caddr_t res, image_blob;
	char in_name[64];
  caddr_t blob = (caddr_t)bif_arg (qst, args, 0, "IM ResampleImageBlob");
  long blob_size = bif_long_arg (qst, args, 1, "IM ResampleImageBlob");
  double v_size = bif_double_arg (qst, args, 2, "IM ResampleImageBlob");
  double h_size = bif_double_arg (qst, args, 3, "IM ResampleImageBlob");
  double blur = bif_double_arg (qst, args, 4, "IM ResampleImageBlob");
  long filter = bif_long_arg (qst, args, 5, "IM ResampleImageBlob");
	int n_args = BOX_ELEMENTS(args);
  char* in_format = n_args > 6 ? bif_string_arg (qst, args, 6, "IM ResampleImageBlob") : NULL;
  mutex_enter (im_mutex);
  MagickWandGenesis();
  magick_wand=NewMagickWand();
	if (in_format != NULL)
	{
		if (strlen(in_format) < 30)
		{
			strcpy(in_name, "image.");
			strcat(in_name, in_format);
			MagickSetFilename(magick_wand, in_name);
		}
	}
  status=MagickReadImageBlob(magick_wand, (const void *)blob, (const size_t)blob_size);
  if (status == MagickFalse)
  {
    WandExitMacro(magick_wand);
    sqlr_new_error ("22023", "IM001", "bif_im_ResampleImageBlob cannot read blob");
  }
  MagickResetIterator(magick_wand);
  while (MagickNextImage(magick_wand) != MagickFalse)
  {
    MagickResampleImage(magick_wand,v_size, h_size,filter,blur);
  }
  image_blob = MagickGetImagesBlob(magick_wand, &length);
  if (length != 0)
  {
    res = dk_alloc_box (length, DV_BIN);
    memcpy (res, image_blob, length);
    MagickRelinquishMemory(image_blob);
  }
  else
    res = NEW_DB_NULL;
  magick_wand=DestroyMagickWand(magick_wand);
  MagickWandTerminus();
  mutex_leave (im_mutex);
  return res;
}


caddr_t bif_im_ResizeImageFile (caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  caddr_t new_file_name;
  caddr_t file_name = bif_string_arg (qst, args, 0, "IM ResizeImageFile");
  long v_size = bif_long_arg (qst, args, 1, "IM ResizeImageFile");
  long h_size = bif_long_arg (qst, args, 2, "IM ResizeImageFile");
  double blur = bif_double_arg (qst, args, 3, "IM ResizeImageFile");
  long filter = bif_long_arg (qst, args, 4, "IM ResizeImageFile");
  int n_args = BOX_ELEMENTS(args);
  if (n_args > 5)
    new_file_name = bif_string_arg (qst, args, 5, "IM ResizeImageFile");
  else
    new_file_name = bif_string_arg (qst, args, 0, "IM ResiseImageFile");
  if (filter < 0 || filter > 15)
    filter = PointFilter;
  mutex_enter (im_mutex);
  MagickWandGenesis();
  magick_wand=NewMagickWand();
  status=MagickReadImage(magick_wand, file_name);
  if (status == MagickFalse)
  {
    WandExitMacro(magick_wand);
    sqlr_new_error ("22023", "IM001", "bif_im_ResizeImageFile cannot open file");
  }
  MagickResetIterator(magick_wand);
  while (MagickNextImage(magick_wand) != MagickFalse)
  {
    MagickResizeImage(magick_wand,v_size, h_size,filter,blur);
  }
  if (new_file_name)
    status=MagickWriteImages(magick_wand, new_file_name, MagickTrue);
  else
    status=MagickWriteImages(magick_wand, file_name, MagickTrue);
  if (status == MagickFalse)
  {
    WandExitMacro(magick_wand);
    sqlr_new_error ("22023", "IM001", "bif_im_ResizeImageFile cannot write image into file");
  }
  magick_wand=DestroyMagickWand(magick_wand);
  MagickWandTerminus();
  mutex_leave (im_mutex);
  return(0);
}

caddr_t bif_im_ResizeImageFileToBlob (caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  size_t length = 0;
  caddr_t res, image_blob;
  caddr_t file_name = bif_string_arg (qst, args, 0, "IM ResizeImageFileToBlob");
  long v_size = bif_long_arg (qst, args, 1, "IM ResizeImageFileToBlob");
  long h_size = bif_long_arg (qst, args, 2, "IM ResizeImageFileToBlob");
  double blur = bif_double_arg (qst, args, 3, "IM ResizeImageFileToBlob");
  long filter = bif_long_arg (qst, args, 4, "IM ResizeImageFileToBlob");
  if (filter < 0 || filter > 15)
    filter = PointFilter;
  mutex_enter (im_mutex);
  MagickWandGenesis();
  magick_wand=NewMagickWand();
  status=MagickReadImage(magick_wand, file_name);
  if (status == MagickFalse)
  {
    WandExitMacro(magick_wand);
    sqlr_new_error ("22023", "IM001", "bif_im_ResizeImageFileToBlob cannot open file");
  }
  MagickResetIterator(magick_wand);
  while (MagickNextImage(magick_wand) != MagickFalse)
  {
    MagickResizeImage(magick_wand,v_size, h_size,filter,blur);
  }
  image_blob = MagickGetImagesBlob(magick_wand, &length);
  if (length != 0)
  {
    res = dk_alloc_box (length, DV_BIN);
    memcpy (res, image_blob, length);
    MagickRelinquishMemory(image_blob);
  }
  else
    res = NEW_DB_NULL;
  magick_wand=DestroyMagickWand(magick_wand);
  MagickWandTerminus();
  mutex_leave (im_mutex);
  return res;
}

caddr_t bif_im_ResizeImageBlob (caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  size_t length = 0;
  caddr_t res, image_blob;
	char in_name[64];
  caddr_t blob = (caddr_t)bif_arg (qst, args, 0, "IM ResizeImageBlob");
  long blob_size = bif_long_arg (qst, args, 1, "IM ResizeImageBlob");
  long v_size = bif_long_arg (qst, args, 2, "IM ResizeImageBlob");
  long h_size = bif_long_arg (qst, args, 3, "IM ResizeImageBlob");
  double blur = bif_double_arg (qst, args, 4, "IM ResizeImageBlob");
  long filter = bif_long_arg (qst, args, 5, "IM ResizeImageBlob");
	int n_args = BOX_ELEMENTS(args);
  char* in_format = n_args > 6 ? bif_string_arg (qst, args, 6, "IM ResizeImageBlob") : NULL;
  if (filter < 0 || filter > 15)
    filter = PointFilter;
  mutex_enter (im_mutex);
  MagickWandGenesis();
  magick_wand=NewMagickWand();
	if (in_format != NULL)
	{
		if (strlen(in_format) < 30)
		{
			strcpy(in_name, "image.");
			strcat(in_name, in_format);
			MagickSetFilename(magick_wand, in_name);
		}
	}
  status=MagickReadImageBlob(magick_wand, (const void *)blob, (const size_t)blob_size);
  if (status == MagickFalse)
  {
    WandExitMacro(magick_wand);
    sqlr_new_error ("22023", "IM001", "bif_im_ResizeImageBlob cannot open file");
  }
  MagickResetIterator(magick_wand);
  while (MagickNextImage(magick_wand) != MagickFalse)
  {
    MagickResizeImage(magick_wand,v_size, h_size,filter,blur);
  }
  image_blob = MagickGetImagesBlob(magick_wand, &length);
  if (length != 0)
  {
    res = dk_alloc_box (length, DV_BIN);
    memcpy (res, image_blob, length);
    MagickRelinquishMemory(image_blob);
  }
  else
    res = NEW_DB_NULL;
  magick_wand=DestroyMagickWand(magick_wand);
  MagickWandTerminus();
  mutex_leave (im_mutex);
  return res;
}

caddr_t bif_im_ThumbnailImageFile (caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  caddr_t new_file_name;
  caddr_t file_name = bif_string_arg (qst, args, 0, "IM ThumbnailImageFile");
  long v_size = bif_long_arg (qst, args, 1, "IM ThumbnailImageFile");
  long h_size = bif_long_arg (qst, args, 2, "IM ThumbnailImageFile");
  long filter = bif_long_arg (qst, args, 3, "IM ThumbnailImageFile");
  int n_args = BOX_ELEMENTS(args);
  if (n_args > 4)
    new_file_name = bif_string_arg (qst, args, 4, "IM ThumbnailImageFile");
  else
    new_file_name = bif_string_arg (qst, args, 0, "IM ThumbnailImageFile");
  mutex_enter (im_mutex);
  MagickWandGenesis();
  magick_wand=NewMagickWand();
  status=MagickReadImage(magick_wand, file_name);
  if (status == MagickFalse)
  {
    WandExitMacro(magick_wand);
    sqlr_new_error ("22023", "IM001", "bif_im_ThumbnailImageFile cannot open file");
  }
  MagickResetIterator(magick_wand);
  while (MagickNextImage(magick_wand) != MagickFalse)
  {
    MagickResizeImage(magick_wand,v_size, h_size,filter,1.0);
    MagickProfileImage(magick_wand, "*", NULL, 0);
  }
  if (new_file_name)
    status=MagickWriteImages(magick_wand, new_file_name, MagickTrue);
  else
    status=MagickWriteImages(magick_wand, file_name, MagickTrue);
  if (status == MagickFalse)
  {
    WandExitMacro(magick_wand);
    sqlr_new_error ("22023", "IM001", "bif_im_ThumbnailImageFile cannot write image into file");
  }
  magick_wand=DestroyMagickWand(magick_wand);
  MagickWandTerminus();
  mutex_leave (im_mutex);
  return(0);
}

caddr_t bif_im_ThumbnailImageFileToBlob (caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  size_t length = 0;
  caddr_t res, image_blob;
  caddr_t file_name = bif_string_arg (qst, args, 0, "IM ThumbnailImageFileToBlob");
  long v_size = bif_long_arg (qst, args, 1, "IM ThumbnailImageFileToBlob");
  long h_size = bif_long_arg (qst, args, 2, "IM ThumbnailImageFileToBlob");
  long filter = bif_long_arg (qst, args, 3, "IM ThumbnailImageFileToBlob");
  int n_args = BOX_ELEMENTS(args);
  if (filter < 0 || filter > 15)
    filter = PointFilter;
  mutex_enter (im_mutex);
  MagickWandGenesis();
  magick_wand=NewMagickWand();
  status=MagickReadImage(magick_wand, file_name);
  if (status == MagickFalse)
  {
    WandExitMacro(magick_wand);
    sqlr_new_error ("22023", "IM001", "bif_im_ThumbnailImageFileToBlob cannot open file");
  }
  MagickResetIterator(magick_wand);
  while (MagickNextImage(magick_wand) != MagickFalse)
  {
    MagickResizeImage(magick_wand,v_size, h_size,filter,1.0);
    MagickProfileImage(magick_wand, "*", NULL, 0);
  }
  image_blob = MagickGetImagesBlob(magick_wand, &length);
  if (length != 0)
  {
    res = dk_alloc_box (length, DV_BIN);
    memcpy (res, image_blob, length);
    MagickRelinquishMemory(image_blob);
  }
  else
    res = NEW_DB_NULL;
  magick_wand=DestroyMagickWand(magick_wand);
  MagickWandTerminus();
  mutex_leave (im_mutex);
  return res;
}

caddr_t bif_im_ThumbnailImageBlob (caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  size_t length = 0;
  caddr_t res, image_blob;
	char in_name[64];
  caddr_t blob = (caddr_t)bif_arg (qst, args, 0, "IM ThumbnailImageBlob");
  long blob_size = bif_long_arg (qst, args, 1, "IM ThumbnailImageBlob");
  long v_size = bif_long_arg (qst, args, 2, "IM ThumbnailImageBlob");
  long h_size = bif_long_arg (qst, args, 3, "IM ThumbnailImageBlob");
  long filter = bif_long_arg (qst, args, 4, "IM ThumbnailImageBlob");
	int n_args = BOX_ELEMENTS(args);
  char* in_format = n_args > 5 ? bif_string_arg (qst, args, 5, "IM ThumbnailImageBlob") : NULL;
  if (filter < 0 || filter > 15)
    filter = PointFilter;
  mutex_enter (im_mutex);
  MagickWandGenesis();
  magick_wand=NewMagickWand();
	if (in_format != NULL)
	{
		if (strlen(in_format) < 30)
		{
			strcpy(in_name, "image.");
			strcat(in_name, in_format);
			MagickSetFilename(magick_wand, in_name);
		}
	}
  status=MagickReadImageBlob(magick_wand, (const void *)blob, (const size_t)blob_size);
  if (status == MagickFalse)
  {
    WandExitMacro(magick_wand);
    sqlr_new_error ("22023", "IM001", "bif_im_ThumbnailImageBlob cannot open file");
  }
  MagickResetIterator(magick_wand);
  while (MagickNextImage(magick_wand) != MagickFalse)
  {
    MagickResizeImage(magick_wand,v_size, h_size,filter,1.0);
    MagickProfileImage(magick_wand, "*", NULL, 0);
  }
  image_blob = MagickGetImagesBlob(magick_wand, &length);
  if (length != 0)
  {
    res = dk_alloc_box (length, DV_BIN);
    memcpy (res, image_blob, length);
    MagickRelinquishMemory(image_blob);
  }
  else
    res = NEW_DB_NULL;
  magick_wand=DestroyMagickWand(magick_wand);
  MagickWandTerminus();
  mutex_leave (im_mutex);
  return res;
}

#ifdef HasTTF
caddr_t 
bif_im_AnnotateImageBlob (caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  size_t length = 0;
  char * szMe = "IM AnnotateImageBlob";
  caddr_t res, image_blob;
	char in_name[64];
  caddr_t blob = (caddr_t)bif_arg (qst, args, 0, szMe);
  long blob_size = box_length (blob) - 1;
  long x_pos = bif_long_arg (qst, args, 1, szMe);
  long y_pos = bif_long_arg (qst, args, 2, szMe);
  caddr_t text = bif_string_arg (qst, args, 3, szMe);
  int n_args = BOX_ELEMENTS(args);
  long angle = n_args > 4 ? bif_long_arg (qst, args, 4, szMe) : 0;
  long f_size = n_args > 5 ? bif_long_arg (qst, args, 5, szMe) : 12;
  char *text_color = n_args > 6 ? bif_string_arg (qst, args, 6, szMe) : "black" ;
  char* in_format = n_args > 7 ? bif_string_arg (qst, args, 7, szMe) : NULL;
  DrawingWand *drawing_wand;
  PixelWand *pixel_wand;
  dtp_t dtp = DV_TYPE_OF (blob);

  if (IS_STRING_DTP (dtp))
    blob_size = box_length (blob) - 1;
  else if (dtp == DV_BIN)
    blob_size = box_length (blob);
  else
    {
      sqlr_new_error ("22023", "IM001", "AnnotateImageBlob needs string or binary as 1-st argument");
    }

  mutex_enter (im_mutex);
  MagickWandGenesis();
  magick_wand=NewMagickWand();
  drawing_wand = NewDrawingWand ();
  pixel_wand = NewPixelWand();
	if (in_format != NULL)
	{
		if (strlen(in_format) < 30)
		{
			strcpy(in_name, "image.");
			strcat(in_name, in_format);
			MagickSetFilename(magick_wand, in_name);
		}
	}
  status=MagickReadImageBlob(magick_wand, (const void *)blob, (const size_t)blob_size);
  if (status == MagickFalse)
    {
      WandExitMacroExt(magick_wand, drawing_wand, pixel_wand);
      sqlr_new_error ("22023", "IM001", "Cannot open file");
    }
  status = PixelSetColor (pixel_wand, text_color);   
  if (status == MagickFalse)
    {
      WandExitMacroExt(magick_wand, drawing_wand, pixel_wand);
      sqlr_new_error ("22023", "IM001", "Cannot set color");
    }
  DrawSetFillColor (drawing_wand , pixel_wand);
  DrawSetFontSize (drawing_wand, f_size);
  MagickResetIterator (magick_wand);
  while (MagickNextImage (magick_wand) != MagickFalse)
    {
      status = MagickAnnotateImage (magick_wand, drawing_wand, x_pos, y_pos, angle, text);
      if (status == MagickFalse)
	{
	  WandExitMacroExt(magick_wand, drawing_wand, pixel_wand);
	  sqlr_new_error ("22023", "IM001", "Cannot annotate image");
	}
    }
  image_blob = MagickGetImagesBlob(magick_wand, &length);
  if (length != 0)
    {
      res = dk_alloc_box (length, DV_BIN);
      memcpy (res, image_blob, length);
      MagickRelinquishMemory(image_blob);
    }
  else
    res = NEW_DB_NULL;
  magick_wand=DestroyMagickWand(magick_wand);
  drawing_wand = DestroyDrawingWand (drawing_wand);
  pixel_wand = DestroyPixelWand(pixel_wand);
  MagickWandTerminus();
  mutex_leave (im_mutex);
  return res;
}
#endif

caddr_t 
bif_im_CreateImageBlob (caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  size_t length = 0;
  char * szMe = "IM CreateImageBlob";
  caddr_t res, image_blob;
  long x_size = bif_long_arg (qst, args, 0, szMe);
  long y_size = bif_long_arg (qst, args, 1, szMe);
  caddr_t bg_color = (caddr_t)bif_string_arg (qst, args, 2, szMe);
  caddr_t fmt = (caddr_t)bif_string_arg (qst, args, 3, szMe);

  PixelWand *pixel_wand;

  if (x_size <= 0 || y_size <= 0)
    {
      sqlr_new_error ("22023", "IM001", "Negative image size");
    }

  if (x_size*y_size > 3333279) /* 10M / 3 color - 54byte */
    sqlr_new_error ("22023", "IM001", "Too large image image size requested");

  mutex_enter (im_mutex);
  MagickWandGenesis();
  magick_wand=NewMagickWand();
  pixel_wand = NewPixelWand();

  status = PixelSetColor( pixel_wand, bg_color );   
  if (status == MagickFalse)
    {
      WandExitMacroExt(magick_wand, NULL, pixel_wand);
      sqlr_new_error ("22023", "IM001", "Cannot set color");
    }
  status = MagickNewImage (magick_wand, x_size, y_size, pixel_wand);
  if (status == MagickFalse)
    {
      WandExitMacroExt(magick_wand, NULL, pixel_wand);
      sqlr_new_error ("22023", "IM001", "Cannot create image");
    }
  status = MagickSetImageFormat(magick_wand, fmt);
  if (status == MagickFalse)
    {
      WandExitMacroExt(magick_wand, NULL, pixel_wand);
      sqlr_new_error ("22023", "IM001", "Cannot set image format");
    }
  image_blob = MagickGetImagesBlob (magick_wand, &length);
  if (length != 0)
    {
      res = dk_alloc_box (length, DV_BIN);
      memcpy (res, image_blob, length);
      MagickRelinquishMemory(image_blob);
    }
  else
    res = NEW_DB_NULL;
  magick_wand = DestroyMagickWand (magick_wand);
  pixel_wand = DestroyPixelWand (pixel_wand);
  MagickWandTerminus();
  mutex_leave (im_mutex);
  return res;
}

caddr_t bif_im_ConvertImageBlob (caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  size_t length = 0;
  caddr_t res, image_blob;
	char in_name[64];
        char out_name[64];
  caddr_t blob = (caddr_t)bif_arg (qst, args, 0, "IM ConvertImageBlob");
  long blob_size = bif_long_arg (qst, args, 1, "IM ConvertImageBlob");
  caddr_t format = bif_string_arg (qst, args, 2, "IM ConvertImageBlob");
	int n_args = BOX_ELEMENTS(args);
  char* in_format = n_args > 3 ? bif_string_arg (qst, args, 3, "IM ConvertImageBlob") : NULL;
  mutex_enter (im_mutex);
  MagickWandGenesis();
  magick_wand=NewMagickWand();
	if (in_format != NULL)
	{
		if (strlen(in_format) < 30)
		{
			strcpy(in_name, "image.");
			strcat(in_name, in_format);
			MagickSetFilename(magick_wand, in_name);
		}
                if (strlen(format) < 30)
                {
                        strcpy(out_name, "image.");                                                                                                                                                               
                        strcat(out_name, format);                                                                                                                                                              
                }
	}
  status=MagickReadImageBlob(magick_wand, (const void *)blob, (const size_t)blob_size);
  if (status == MagickFalse)
  {
    WandExitMacro(magick_wand);
    sqlr_new_error ("22023", "IM001", "bif_im_ConvertImageBlob cannot read the blob");
  }
  MagickResetIterator(magick_wand);
  while (MagickNextImage(magick_wand) != MagickFalse)
  {
    status = MagickSetImageFormat(magick_wand,format);
    MagickSetFilename(magick_wand, out_name);
    if (status == MagickFalse)
    {
        WandExitMacro(magick_wand);
        sqlr_new_error ("22023", "IM001", "bif_im_ConvertImageBlob cannot convert image");
        return;
    }
  }
  /*MagickResetIterator(magick_wand);
  if (out_name)                                                                                              
    status=MagickWriteImages(magick_wand, out_name, MagickTrue);
  */
  image_blob = MagickGetImageBlob(magick_wand, &length);
  if (length != 0)
  {
    res = dk_alloc_box (length, DV_BIN);
    memcpy (res, image_blob, length);
    MagickRelinquishMemory(image_blob);
  }
  else
    res = NEW_DB_NULL;
  magick_wand=DestroyMagickWand(magick_wand);
  MagickWandTerminus();
  mutex_leave (im_mutex);
  return res;
}


caddr_t bif_im_ConvertImageFile (caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  caddr_t new_file_name;
  caddr_t file_name = bif_string_arg (qst, args, 0, "IM ConvertImageFile");
  int n_args = BOX_ELEMENTS(args);
  if (n_args > 1)
    new_file_name = bif_string_arg (qst, args, 1, "IM ConvertImageFile");
  else
  {
    sqlr_new_error ("22023", "IM001", "bif_im_ConvertImageFile cannot find the new file name");
    return 0;
  }
  mutex_enter (im_mutex);
  MagickWandGenesis();
  magick_wand=NewMagickWand();
  status=MagickReadImage(magick_wand, file_name);
  if (status == MagickFalse)
  {
    WandExitMacro(magick_wand);
    sqlr_new_error ("22023", "IM001", "bif_im_ConvertImageFile cannot open file");
  }
  if (new_file_name)
    status=MagickWriteImages(magick_wand, new_file_name, MagickTrue);
  if (status == MagickFalse)
  {
    WandExitMacro(magick_wand);
    sqlr_new_error ("22023", "IM001", "bif_im_ConvertImageFile cannot write image into file");
  }
  magick_wand=DestroyMagickWand(magick_wand);
  MagickWandTerminus();
  mutex_leave (im_mutex);
  return(0);
}

void im_connect (void *appdata)
{
  im_IMVERSION = box_dv_short_string (IM_VERSION);
  im_mutex = mutex_allocate ();

  bif_define ("IM ResizeImageFile", bif_im_ResizeImageFile);
  bif_define ("IM ThumbnailImageFile", bif_im_ThumbnailImageFile);
  bif_define ("IM ConvertImageFile", bif_im_ConvertImageFile);
  bif_define ("IM ResampleImageFile", bif_im_ResampleImageFile);
  bif_define ("IM RotateImageFile", bif_im_RotateImageFile);
  bif_define ("IM CropImageFile", bif_im_CropImageFile);
  bif_define ("IM GetImageFileAttribute", bif_im_GetImageFileAttribute);
  bif_define ("IM GetImageFileFormat", bif_im_GetImageFileFormat);
  bif_define ("IM GetImageFileIdentify", bif_im_GetImageFileIdentify);
  bif_define ("IM GetImageBlobIdentify", bif_im_GetImageBlobIdentify);

  bif_define ("IM GetImageFileWidth", bif_im_GetImageFileWidth);
  bif_define ("IM GetImageFileHeight", bif_im_GetImageFileHeight);
  bif_define ("IM GetImageFileDepth", bif_im_GetImageFileDepth);

  bif_define ("IM ResizeImageFileToBlob", bif_im_ResizeImageFileToBlob);
  bif_define ("IM ThumbnailImageFileToBlob", bif_im_ThumbnailImageFileToBlob);
  bif_define ("IM ResampleImageFileToBlob", bif_im_ResampleImageFileToBlob);
  bif_define ("IM RotateImageFileToBlob", bif_im_RotateImageFileToBlob);
  bif_define ("IM CropImageFileToBlob", bif_im_CropImageFileToBlob);
  bif_define ("IM GetImageBlobAttribute", bif_im_GetImageBlobAttribute);
  bif_define ("IM GetImageBlobFormat", bif_im_GetImageBlobFormat);
  bif_define ("IM GetImageBlobWidth", bif_im_GetImageBlobWidth);
  bif_define ("IM GetImageBlobHeight", bif_im_GetImageBlobHeight);
  bif_define ("IM GetImageBlobDepth", bif_im_GetImageBlobDepth);

  bif_define ("IM ConvertImageBlob", bif_im_ConvertImageBlob);
  bif_define ("IM ResizeImageBlob", bif_im_ResizeImageBlob);
  bif_define ("IM ThumbnailImageBlob", bif_im_ThumbnailImageBlob);
  bif_define ("IM ResampleImageBlob", bif_im_ResampleImageBlob);
  bif_define ("IM RotateImageBlob", bif_im_RotateImageBlob);
  bif_define ("IM CropImageBlob", bif_im_CropImageBlob);
#ifdef HasTTF
  bif_define ("IM AnnotateImageBlob", bif_im_AnnotateImageBlob);
#endif
  bif_define ("IM CreateImageBlob", bif_im_CreateImageBlob);
}

#ifdef _USRDLL
static unit_version_t
im_version = {
  "IM",        /*!< Title of unit, filled by unit */
  IM_VERSION,      /*!< Version number, filled by unit */
  "OpenLink Software",      /*!< Plugin's developer, filled by unit */
  "Support functions for Image Magick " MagickLibVersionText, /*!< Any additional info, filled by unit */
  0,          /*!< Error message, filled by unit loader */
  0,          /*!< Name of file with unit's code, filled by unit loader */
  im_connect,      /*!< Pointer to connection function, cannot be 0 */
  0,          /*!< Pointer to disconnection function, or 0 */
  0,          /*!< Pointer to activation function, or 0 */
  0,          /*!< Pointer to deactivation function, or 0 */
  &_gate
};

unit_version_t *
CALLBACK im_check (unit_version_t *in, void *appdata)
{
  return &im_version;
}
#endif

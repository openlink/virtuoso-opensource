/*  filedsn.h
 *
 *  $Id$
 *  
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *  
 *  Copyright (C) 1998-2012 OpenLink Software
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

#include "headers.h"
#include "filedsn.h"


FileDSN::FileDSN()
{
}

FileDSN::~FileDSN()
{
}

bool
FileDSN::Read(std::istream& is)
{
  bool rc = true;

  try {

    Line* line = ReadLine(is);
    while (line != NULL)
      line = ReadSection(is, line);

  } catch (...) {
    rc = false;
  }

  return rc;
}

FileDSN::Line*
FileDSN::ReadSection(std::istream& is, Line* line)
{
  Section* section = dynamic_cast<Section*>(line);
  line = ReadLine(is);
  if (section != NULL)
    {
      sections.push_back(section);
      while (line != NULL && dynamic_cast<Section*>(line) == NULL)
	line = ReadSetting(is, section, line);
    }
  return line;
}

FileDSN::Line*
FileDSN::ReadSetting(std::istream& is, Section* section, Line* line)
{
  Setting* setting = dynamic_cast<Setting*>(line);
  line = ReadLine(is);
  if (setting != NULL)
    section->AppendSetting(setting);
  return line;
}

FileDSN::Line*
FileDSN::ReadLine(std::istream& is)
{
  std::string str;
  std::getline(is, str);

  if (str.length() == 0)
    {
      if (!is.good())
	return NULL;
    }
  else
    {
      size_t i, j, n, m;
      i = str.find_first_not_of(" \t");
      if (i != str.npos && str[i] != ';')
	{
	  if (str[i] == '[')
	    {
	      j = str.find(']', i);
	      if (j != str.npos)
		{
		  n = str.find_first_not_of(" \t", i + 1);
		  m = str.find_last_not_of(" \t", j - 1);
		  const std::string s = str.substr(n, m < n ? 0 : m - n + 1);
		  Section* section = new Section(str, s);
		  contents.push_back(section);
		  return section;
		}
	    }
	  j = str.find('=', i);
	  if (j != str.npos)
	    {
	      m = str.find_last_not_of(" \t", j - 1);
	      const std::string k = str.substr(i, m < i ? 0 : m - i + 1);
	      Setting* setting = new Setting(str, k);
	      n = str.find_first_not_of(" \t", j + 1);
	      if (n != str.npos)
		{
		  m = str.find_last_not_of(" \t");
		  setting->SetValue(str.substr(n, m < n ? 0 : m - n + 1));
		}
	      contents.push_back(setting);
	      return setting;
	    }
	}
    }

  Line* line = new Line(str);
  contents.push_back(line);
  return line;
}

bool
FileDSN::Write(std::ostream& os)
{
  bool rc = true;

  try {

    for (std::vector<Line*>::iterator i = contents.begin(); i != contents.end(); i++)
      (*i)->Write(os);

  } catch (...) {
    rc = false;
  }

  return rc;
}

void
FileDSN::Line::Write(std::ostream& os)
{
  os << line << std::endl;
}

void
FileDSN::Setting::Write(std::ostream& os)
{
  if (line.length() == 0)
    os << key << '=' << value << std::endl;
  else
    {
      // All this mess is to preserve initial formatting.
      int n = line.find_first_not_of(" \t", line.find('=') + 1);
      if (n != line.npos)
	os.write(line.c_str(), n);
      else
	os << line;
      os << value << std::endl;
    }
}

void
FileDSN::Section::Write(std::ostream& os)
{
  if (line.length() == 0)
    os << '[' << name << ']' << std::endl;
  else
    os << line << std::endl;
}

bool
FileDSN::Get(const std::string& section_name, const std::string& key, std::string& value)
{
  for (std::vector<Section*>::iterator i = sections.begin(); i != sections.end(); i++)
    if ((*i)->GetName() == section_name)
      return (*i)->Get(key, value);
  return false;
}

bool
FileDSN::Section::Get(const std::string& key, std::string& value)
{
  for (std::vector<Setting*>::iterator i = settings.begin(); i != settings.end(); i++)
    if ((*i)->GetKey() == key)
      {
	value = (*i)->GetValue();
	return true;
      }
  return false;
}

bool
FileDSN::Set(const std::string& section_name, const std::string& key, const std::string& value)
{
  for (std::vector<Section*>::iterator i = sections.begin(); i != sections.end(); i++)
    if ((*i)->GetName() == section_name)
      return (*i)->Set(key, value, contents);

  Section* section = new Section(section_name);
  if (section == NULL)
    return false;

  contents.push_back(section);
  sections.push_back(section);
  return section->Set(key, value, contents);
}

bool
FileDSN::Section::Set(const std::string& key, const std::string& value, std::vector<Line*>& contents)
{
  for (std::vector<Setting*>::iterator i = settings.begin(); i != settings.end(); i++)
    if ((*i)->GetKey() == key)
      {
	(*i)->SetValue(value);
	return true;
      }

  Setting* setting = new Setting(key);
  if (setting == NULL)
    return false;
  setting->SetValue(value);

  std::vector<Line*>::iterator p = std::find(contents.begin(), contents.end(), this);
  contents.insert(++p, setting);
  settings.insert(settings.begin(), setting);
  return true;
}

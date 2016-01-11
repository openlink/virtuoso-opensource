/*  filedsn.h
 *
 *  $Id$
 *  
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *  
 *  Copyright (C) 1998-2016 OpenLink Software
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

#ifndef FILEDSN
#define FILEDSN


// This implementation is not very space efficient but it should not
// be a problem cause DSN files are usually not very big.
class FileDSN
{
public:

  FileDSN();
  ~FileDSN();

  bool Read(std::istream& is);
  bool Write(std::ostream& os);

  bool Get(const std::string& section_name, const std::string& key, std::string& value);
  bool Set(const std::string& section_name, const std::string& key, const std::string& value);

private:


  class Line
  {
  public:

    Line() {}
    Line(const std::string& l) : line(l) {}

    virtual void Write(std::ostream& out);

  protected:

    const std::string line;
  };


  class Setting : public Line
  {
  public:

    Setting(const std::string& k) : key(k) {}
    Setting(const std::string& l, const std::string& k) : Line(l), key(k)  {}

    virtual void Write(std::ostream& out);

    const std::string&
    GetKey()
    {
      return key;
    }

    const std::string&
    GetValue()
    {
      return value;
    }

    void
    SetValue(const std::string& v)
    {
      value = v;
    }

  private:

    const std::string key;
    std::string value;
  };


  class Section : public Line
  {
  public:

    Section(const std::string& n) : name(n) {}
    Section(const std::string& l, const std::string& n) : Line(l), name(n) {}

    virtual void Write(std::ostream& out);

    const std::string&
    GetName()
    {
      return name;
    }

    void
    AppendSetting(Setting* setting)
    {
      settings.push_back(setting);
    }

    bool Get(const std::string& key, std::string& value);
    bool Set(const std::string& key, const std::string& value, std::vector<Line*>& contents);

  private:

    const std::string name;
    std::vector<Setting*> settings;
  };


  Line* ReadSection(std::istream& is, Line* line);
  Line* ReadSetting(std::istream& is, Section* section, Line* Line);
  Line* ReadLine(std::istream& is);

  std::vector<Line*> contents;
  std::vector<Section*> sections;
};


#endif

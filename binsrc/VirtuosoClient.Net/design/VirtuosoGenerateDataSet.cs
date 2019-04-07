//  
//  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
//  project.
//  
//  Copyright (C) 1998-2019 OpenLink Software
//  
//  This project is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the
//  Free Software Foundation; only version 2 of the License, dated June 1991.
//  
//  This program is distributed in the hope that it will be useful, but
//  WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
//  General Public License for more details.
//  
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
//  
//  
// 
// $Id$
//

using System;
using System.Drawing;
using System.Collections;
using System.ComponentModel;
using System.Windows.Forms;

using System.IO;
using System.Reflection;
using System.ComponentModel.Design;
using EnvDTE;
using VSLangProj;
using System.Data;
using System.Data.Common;


#if ODBC_CLIENT
namespace OpenLink.Data.VirtuosoOdbcClient.Design
#elif CLIENT
namespace OpenLink.Data.VirtuosoClient.Design
#else
namespace OpenLink.Data.Virtuoso.Design
#endif
{

    /// <summary>
    /// Summary description for VirtuosoGenerateDataSet.
    /// </summary>
    internal class VirtuosoGenerateDataSet : System.Windows.Forms.Form
    {
        #region members
        private IDesignerHost _host;
        private VirtuosoDataAdapter _invokingAdapter;
        private ProjectItem _projectItem;
        private Project _ownerProject; // = null;
        private Hashtable _datasetList = new Hashtable();
        private int _checkedAdapterCount;

        private System.Windows.Forms.Label labelIntro;
        private System.Windows.Forms.Label labelSelectTables;
        private System.Windows.Forms.Button buttonCancel;
        private System.Windows.Forms.Button buttonOk;
        private System.Windows.Forms.CheckedListBox checkedListBoxAdapters;
        private System.Windows.Forms.ComboBox comboBoxExistingDatasets;
        private System.Windows.Forms.TextBox textBoxNewDatasetName;
        private System.Windows.Forms.RadioButton radioButtonNewDataset;
        private System.Windows.Forms.RadioButton radioButtonExistingDataset;
        private System.Windows.Forms.Label labelChooseDataset;
        #endregion
        /// <summary>
        /// Required designer variable.
        /// </summary>
        private System.ComponentModel.Container components = null;

        #region Constructors and dispose
        public VirtuosoGenerateDataSet(IDesignerHost host, object item, VirtuosoDataAdapter adapter)
        {
            //
            // Required for Windows Form Designer support
            //
            InitializeComponent();

            _host = host;
            _projectItem = (ProjectItem) item;
            if (_projectItem != null) 
            {
                _ownerProject = _projectItem.ContainingProject;
            }
            _invokingAdapter = adapter;
        }

        /// <summary>
        /// Clean up any resources being used.
        /// </summary>
        protected override void Dispose( bool disposing )
        {
            if( disposing )
            {
                if(components != null)
                {
                    components.Dispose();
                }
            }
            base.Dispose( disposing );
        }
        #endregion

        #region Windows Form Designer generated code
        /// <summary>
        /// Required method for Designer support - do not modify
        /// the contents of this method with the code editor.
        /// </summary>
        private void InitializeComponent()
        {
            this.labelIntro = new System.Windows.Forms.Label();
            this.labelSelectTables = new System.Windows.Forms.Label();
            this.buttonCancel = new System.Windows.Forms.Button();
            this.buttonOk = new System.Windows.Forms.Button();
            this.checkedListBoxAdapters = new System.Windows.Forms.CheckedListBox();
            this.comboBoxExistingDatasets = new System.Windows.Forms.ComboBox();
            this.textBoxNewDatasetName = new System.Windows.Forms.TextBox();
            this.radioButtonNewDataset = new System.Windows.Forms.RadioButton();
            this.radioButtonExistingDataset = new System.Windows.Forms.RadioButton();
            this.labelChooseDataset = new System.Windows.Forms.Label();
            this.SuspendLayout();
            // 
            // labelIntro
            // 
            this.labelIntro.Anchor = ((System.Windows.Forms.AnchorStyles)(((System.Windows.Forms.AnchorStyles.Top | System.Windows.Forms.AnchorStyles.Left) 
                | System.Windows.Forms.AnchorStyles.Right)));
            this.labelIntro.Location = new System.Drawing.Point(24, 16);
            this.labelIntro.Name = "labelIntro";
            this.labelIntro.Size = new System.Drawing.Size(352, 24);
            this.labelIntro.TabIndex = 1;
            this.labelIntro.Text = "Generate a dataset that includes schemas from the specified data adapters.";
            // 
            // labelSelectTables
            // 
            this.labelSelectTables.Location = new System.Drawing.Point(16, 136);
            this.labelSelectTables.Name = "labelSelectTables";
            this.labelSelectTables.Size = new System.Drawing.Size(264, 16);
            this.labelSelectTables.TabIndex = 18;
            this.labelSelectTables.Text = "Select adapter schemas to add to the dataset:";
            // 
            // buttonCancel
            // 
            this.buttonCancel.Anchor = ((System.Windows.Forms.AnchorStyles)((System.Windows.Forms.AnchorStyles.Bottom | System.Windows.Forms.AnchorStyles.Right)));
            this.buttonCancel.DialogResult = System.Windows.Forms.DialogResult.Cancel;
            this.buttonCancel.Location = new System.Drawing.Point(304, 300);
            this.buttonCancel.Name = "buttonCancel";
            this.buttonCancel.TabIndex = 17;
            this.buttonCancel.Text = "Cancel";
            // 
            // buttonOk
            // 
            this.buttonOk.Anchor = ((System.Windows.Forms.AnchorStyles)((System.Windows.Forms.AnchorStyles.Bottom | System.Windows.Forms.AnchorStyles.Right)));
            this.buttonOk.DialogResult = System.Windows.Forms.DialogResult.OK;
            this.buttonOk.Location = new System.Drawing.Point(216, 300);
            this.buttonOk.Name = "buttonOk";
            this.buttonOk.TabIndex = 16;
            this.buttonOk.Text = "Ok";
            this.buttonOk.Click += new System.EventHandler(this.buttonOk_Click);
            // 
            // checkedListBoxAdapters
            // 
            this.checkedListBoxAdapters.Anchor = ((System.Windows.Forms.AnchorStyles)((((System.Windows.Forms.AnchorStyles.Top | System.Windows.Forms.AnchorStyles.Bottom) 
                | System.Windows.Forms.AnchorStyles.Left) 
                | System.Windows.Forms.AnchorStyles.Right)));
            this.checkedListBoxAdapters.Location = new System.Drawing.Point(16, 164);
            this.checkedListBoxAdapters.Name = "checkedListBoxAdapters";
            this.checkedListBoxAdapters.Size = new System.Drawing.Size(360, 109);
            this.checkedListBoxAdapters.TabIndex = 15;
            this.checkedListBoxAdapters.ItemCheck += new System.Windows.Forms.ItemCheckEventHandler(this.checkedListBoxAdapters_ItemCheck);
            // 
            // comboBoxExistingDatasets
            // 
            this.comboBoxExistingDatasets.Anchor = ((System.Windows.Forms.AnchorStyles)(((System.Windows.Forms.AnchorStyles.Top | System.Windows.Forms.AnchorStyles.Left) 
                | System.Windows.Forms.AnchorStyles.Right)));
            this.comboBoxExistingDatasets.Enabled = false;
            this.comboBoxExistingDatasets.Location = new System.Drawing.Point(152, 96);
            this.comboBoxExistingDatasets.Name = "comboBoxExistingDatasets";
            this.comboBoxExistingDatasets.Size = new System.Drawing.Size(224, 21);
            this.comboBoxExistingDatasets.Sorted = true;
            this.comboBoxExistingDatasets.TabIndex = 14;
            // 
            // textBoxNewDatasetName
            // 
            this.textBoxNewDatasetName.Anchor = ((System.Windows.Forms.AnchorStyles)(((System.Windows.Forms.AnchorStyles.Top | System.Windows.Forms.AnchorStyles.Left) 
                | System.Windows.Forms.AnchorStyles.Right)));
            this.textBoxNewDatasetName.Location = new System.Drawing.Point(152, 64);
            this.textBoxNewDatasetName.Name = "textBoxNewDatasetName";
            this.textBoxNewDatasetName.Size = new System.Drawing.Size(224, 20);
            this.textBoxNewDatasetName.TabIndex = 13;
            this.textBoxNewDatasetName.Text = "";
            // 
            // radioButtonNewDataset
            // 
            this.radioButtonNewDataset.Location = new System.Drawing.Point(32, 64);
            this.radioButtonNewDataset.Name = "radioButtonNewDataset";
            this.radioButtonNewDataset.TabIndex = 11;
            this.radioButtonNewDataset.Text = "&New dataset:";
            this.radioButtonNewDataset.CheckedChanged += new System.EventHandler(this.radioButtonNewDataset_CheckedChanged);
            // 
            // radioButtonExistingDataset
            // 
            this.radioButtonExistingDataset.Location = new System.Drawing.Point(32, 96);
            this.radioButtonExistingDataset.Name = "radioButtonExistingDataset";
            this.radioButtonExistingDataset.Size = new System.Drawing.Size(128, 24);
            this.radioButtonExistingDataset.TabIndex = 12;
            this.radioButtonExistingDataset.Text = "&Existing dataset:";
            this.radioButtonExistingDataset.CheckedChanged += new System.EventHandler(this.radioButtonExistingDataset_CheckedChanged);
            // 
            // labelChooseDataset
            // 
            this.labelChooseDataset.Location = new System.Drawing.Point(16, 48);
            this.labelChooseDataset.Name = "labelChooseDataset";
            this.labelChooseDataset.Size = new System.Drawing.Size(100, 16);
            this.labelChooseDataset.TabIndex = 10;
            this.labelChooseDataset.Text = "Choose a dataset:";
            // 
            // VirtuosoGenerateDataSet
            // 
            this.AutoScaleBaseSize = new System.Drawing.Size(5, 13);
            this.ClientSize = new System.Drawing.Size(400, 342);
            this.Controls.Add(this.labelSelectTables);
            this.Controls.Add(this.buttonCancel);
            this.Controls.Add(this.buttonOk);
            this.Controls.Add(this.checkedListBoxAdapters);
            this.Controls.Add(this.comboBoxExistingDatasets);
            this.Controls.Add(this.textBoxNewDatasetName);
            this.Controls.Add(this.radioButtonNewDataset);
            this.Controls.Add(this.radioButtonExistingDataset);
            this.Controls.Add(this.labelChooseDataset);
            this.Controls.Add(this.labelIntro);
            this.Name = "VirtuosoGenerateDataSet";
            this.Text = "Virtuoso Managed Provider Generate DataSet";
            this.Load += new System.EventHandler(this.VirtuosoGenerateDataSet_Load);
            this.ResumeLayout(false);

        }
        #endregion

        #region Support for locating Dataset classes

        private void loadDataSetList() 
        {
            //
            //  Loop over project items and fill _datasetList with information
            //
            if (_ownerProject != null) 
            {
                findDataSets(null, _ownerProject.ProjectItems);
            }
            //
            //  Display datasets found
            //
            comboBoxExistingDatasets.BeginUpdate();
            foreach(DictionaryEntry entry in _datasetList) 
            {
                comboBoxExistingDatasets.Items.Add((string) entry.Key);
            }
            comboBoxExistingDatasets.EndUpdate();
        }
        private void findDataSets(ProjectItem topItem, ProjectItems itemList) 
        {
            FileCodeModel codeModel;
            foreach (ProjectItem item in itemList) 
            {
                codeModel = item.FileCodeModel;
                if (codeModel != null) 
                {
                    findDataSets((topItem != null ? topItem : item), codeModel.CodeElements);
                }
                if (item.ProjectItems.Count > 0) 
                {
                    findDataSets((topItem != null ? topItem : item), item.ProjectItems);
                }
            }
        }

        private void buttonOk_Click(object sender, System.EventArgs e)
        {
            if (this.radioButtonNewDataset.Checked) 
            {
                generateDataset(textBoxNewDatasetName.Text + ".xsd", null);
            } 
            else 
            {
                if (comboBoxExistingDatasets.SelectedIndex != -1) 
                {
                    generateDataset((string) _datasetList[comboBoxExistingDatasets.Text], comboBoxExistingDatasets.Text);
                }
            }
        }

        private void findDataSets(ProjectItem topItem, CodeElements elementList) 
        {
            foreach (CodeElement element in elementList) 
            {
                if ((element as CodeNamespace) != null) 
                {
                    findDataSets(topItem, ((CodeNamespace) element).Members);
                } 
                else if ((element as CodeClass) != null) 
                {
                    findDataSets(topItem, (CodeClass) element);
                }
            }
        }
        private void findDataSets(ProjectItem topItem, CodeClass codeClass) 
        {
            //
            //  Found a class, check if public access
            //
            if (codeClass.Access == EnvDTE.vsCMAccess.vsCMAccessPublic) 
            {
                if (codeClass.IsCodeType) 
                {
                    CodeType codeType = (CodeType) codeClass;
                    //
                    //  Check if it is a DataSet
                    //
                    if (codeType.get_IsDerivedFrom(typeof(DataSet).FullName)) 
                    {
                        //
                        //  We have found a DataSet class, add to Hashtable
                        //
                        _datasetList.Add(codeClass.FullName, topItem.Name);
                        return;
                    }
                }
            }
            //
            //  Look for nested namespaces and classes
            //
            if (codeClass.Members.Count > 0) 
            {
                findDataSets(topItem, codeClass.Members);
            }
        }
        #endregion

        private void generateDataset(string datasetFilename, string datasetClassName) 
        {
            if (datasetFilename == null || datasetFilename == "") 
            {
                throw new Exception("No schema filename specified");
            }
            if (this.checkedListBoxAdapters.CheckedItems.Count == 0) 
            {
                throw new Exception("No data adapter items selected.");
            }
            int extensionStart = datasetFilename.LastIndexOf('.');
            if (extensionStart == -1) 
            {
                throw new Exception("Invalid data set filename " + extensionStart);
            }
            string datasetName = datasetFilename.Substring(0, extensionStart);
            VirtuosoDataAdapter adapter;

            DataSet targetDataSet = new DataSet();
            DataSet sourceDataSet;
            for (int index = 0; index < checkedListBoxAdapters.CheckedItems.Count; index++) 
            {
                adapter = null;
                foreach(IComponent c in _host.Container.Components) 
                {
                    if (c is VirtuosoDataAdapter &&
                        c.ToString() == this.checkedListBoxAdapters.CheckedItems[index].ToString()) 
                    {
                        adapter = (VirtuosoDataAdapter) c;
                        break;
                    }
                }
                if (adapter == null) 
                {
                    throw new Exception("Inconsistency, failed to locate data adapter");
                }
                sourceDataSet = new DataSet();
                try 
                {
                    adapter.MissingSchemaAction = MissingSchemaAction.Add;
                    if (adapter.MissingMappingAction == MissingMappingAction.Error) 
                    {
                        adapter.MissingMappingAction = MissingMappingAction.Ignore;
                    }
                    DataTable [] tables = adapter.FillSchema(sourceDataSet, SchemaType.Mapped);
                    //
                    //  Set all string columns to length -1 so that the xml schema file
                    //  generates correctly
                    //
                    foreach (DataTable table in tables) 
                    {
                        foreach (DataColumn column in table.Columns) 
                        {
                            if (column.DataType == typeof(string)) 
                            {
                                column.MaxLength = -1;
                            }
                        }
                    }
                    //
                    //  Merge data table into main data set
                    //
                    foreach(DataTable table in tables) 
                    {
                        if (!targetDataSet.Tables.Contains(table.TableName)) 
                        {
                            targetDataSet.Merge(table);
                        }
                    }
                } 
                catch (Exception ex) 
                {
                    MessageBox.Show (ex.Message);
                } 
            }
            //
            //  Locate project items collection where .xsd file should be added
            //
            if (_projectItem == null || _projectItem.Collection == null) 
            {
                throw new ApplicationException("No project information available. Unable to generate data set file.");
            }
            object parent = _projectItem.Collection.Parent;
            ProjectItems projectItems = null;
            while (parent != null) 
            {
                if ((parent as Project) != null) 
                {
                    //
                    //  The parent was the project node!
                    //
                    projectItems = ((Project) parent).ProjectItems;
                    break;
                }
                if ((parent as ProjectItem) == null) 
                {
                    //
                    //  Parent node was not a project and not a project item...
                    //
                    break;
                }
                if (string.Compare(((ProjectItem) parent).Kind, EnvDTE.Constants.vsProjectItemKindPhysicalFolder, true, System.Globalization.CultureInfo.InvariantCulture) != 0) 
                {
                    //
                    //  Add .xsd file to folder
                    //
                    projectItems = ((ProjectItem) parent).ProjectItems;
                    break;
                }
                parent = ((ProjectItem) parent).Collection.Parent;
            }
            Type xsdType = null;
            if (datasetClassName != null) 
            {
                xsdType = _host.GetType(datasetClassName);
            }
            //
            //  Now merge the existing data set into the target
            //
            if (datasetClassName != null && xsdType != null) 
            {
                ConstructorInfo constructor = xsdType.GetConstructor(new Type[] {});
                if (constructor != null) 
                {
                    sourceDataSet = (DataSet) constructor.Invoke(null);
                    if (sourceDataSet != null) 
                    {
                        foreach(DataTable table in sourceDataSet.Tables) 
                        {
                            if (!targetDataSet.Tables.Contains(table.TableName)) 
                            {
                                targetDataSet.Merge(table);
                            }
                        }
                    }
                }
            }
            //
            //  Calculate filename for dataset XML schema file
            //
            if (_projectItem.Properties == null) 
            {
                throw new ApplicationException("Unable to locate project item properties.");
            }
            if (_projectItem.Properties.Item("FullPath") == null) 
            {
                throw new ApplicationException("Unable to resolve full path of the dataset file.");
            }
            string xsdFilename = Path.Combine(Path.GetDirectoryName(
                (string) _projectItem.Properties.Item("FullPath").Value), datasetFilename);
            ProjectItem xsdItem = projectItems.DTE.Solution.FindProjectItem(xsdFilename);
            if (datasetClassName == null) 
            {
                if (xsdItem != null || File.Exists(xsdFilename)) 
                {
                    if (MessageBox.Show(this, "File " + xsdFilename + " already exists. Overwrite?", "Overwrite Schema File", MessageBoxButtons.OKCancel, MessageBoxIcon.Question) != DialogResult.OK) 
                    {
                        DialogResult = DialogResult.None;
                        return;
                    }
                }
            }
            targetDataSet.Namespace = "http://www.tempuri.org/" + datasetName + ".xsd";
            targetDataSet.DataSetName = datasetName;
            targetDataSet.WriteXmlSchema(xsdFilename);
            //
            //  Add the .xsd file to the project, unless it already existed
            //
            if (xsdItem == null) 
            {
                xsdItem = projectItems.AddFromFileCopy(xsdFilename);
            }
            //
            //  Set the CustomTool property to "MSDataSetGenerator"
            //
            if (xsdItem != null && xsdItem.Properties != null) 
            {
                Property custToolsProp = xsdItem.Properties.Item("CustomTool");
                if (custToolsProp != null) 
                {
                    if (custToolsProp.Value.Equals(string.Empty)) 
                    {
                        custToolsProp.Value = "MSDataSetGenerator";
                    }
                } 
                else 
                {
                    VSProjectItem vsProjectItem = (VSProjectItem) xsdItem.Object;
                    vsProjectItem.RunCustomTool();
                }
            }
            //
            //  Add a component to the designer if none exists
            //
            foreach(IComponent c in _host.Container.Components) 
            {
                if (c is DataSet) 
                {
                    if (String.Compare(((DataSet) c).DataSetName, datasetName, true) == 0) 
                    {
                        //
                        //  Found one, done!
                        //
                        return;
                    }
                }
            }
            if (xsdType == null) 
            {
                //
                //  Figure out the fully qualified namespace name
                //
                Property namespaceProp = null;
                if ((parent as Project) != null) 
                {
                    namespaceProp = ((Project) parent).Properties.Item("RootNamespace");
                } 
                else if ((parent as ProjectItem) != null) 
                {
                    namespaceProp = ((ProjectItem) parent).Properties.Item("DefaultNamespace");
                }
                if (namespaceProp != null) 
                {
                    xsdType = _host.GetType(namespaceProp.Value + "." + datasetName);
                }
            }
            //
            //  Add the component to the designer
            //
            if (xsdType != null) 
            {
                if (_host.Container.Components[datasetName] == null) 
                {
                    _host.CreateComponent(xsdType, datasetName);
                } 
                else 
                {
                    _host.CreateComponent(xsdType);
                }
            }
        }


        #region Dialog event handling
        private void VirtuosoGenerateDataSet_Load(object sender, System.EventArgs e)
        {
            Cursor.Current = Cursors.WaitCursor;
            IContainer container = _host.Container;
            this.radioButtonNewDataset.Checked = true;
            foreach (object component in container.Components) 
            {
                if (component is VirtuosoDataAdapter) 
                {
                    VirtuosoDataAdapter adapter = (VirtuosoDataAdapter) component;
                    checkedListBoxAdapters.Items.Add(component.ToString(), adapter == _invokingAdapter);
                }
            }
            loadDataSetList();
            _checkedAdapterCount = this.checkedListBoxAdapters.CheckedItems.Count;
            if (this.comboBoxExistingDatasets.Items.Count == 0) 
            {
                this.radioButtonExistingDataset.Enabled = false;
                this.comboBoxExistingDatasets.Items.Add("No data sets found");
            }
            this.comboBoxExistingDatasets.SelectedIndex = 0;
            //
            //  Calculate a default data set filename
            //
            if (_projectItem != null) 
            {
                string directory = Path.GetDirectoryName((string) _projectItem.Properties.Item("FullPath").Value);
                string file;
                string path;
                for (int fileno = 1; fileno < 400; fileno++) 
                {
                    file = "DataSet" + fileno.ToString();
                    path = Path.Combine(directory, file + ".xsd");
                    if (!File.Exists(path)) 
                    {
                        this.textBoxNewDatasetName.Text = file;
                        break;
                    }
                }
            }
            Cursor.Current = Cursors.Default;
            enableDisableOk(sender, e);
        }

        private void checkedListBoxAdapters_ItemCheck(object sender, System.Windows.Forms.ItemCheckEventArgs e)
        {
            if (e.NewValue == CheckState.Checked) 
            {
                this._checkedAdapterCount++;
            } 
            else 
            {
                this._checkedAdapterCount--;
            }
            this.enableDisableOk(sender, (EventArgs) e);
        }
        private void radioButtonExistingDataset_CheckedChanged(object sender, System.EventArgs e)
        {
            comboBoxExistingDatasets.Enabled = radioButtonExistingDataset.Checked;		
            enableDisableOk(sender, e);
        }
        private void radioButtonNewDataset_CheckedChanged(object sender, System.EventArgs e)
        {
            textBoxNewDatasetName.Enabled = radioButtonNewDataset.Checked;
            enableDisableOk(sender, e);
        }
        private void enableDisableOk(object sender, System.EventArgs e) 
        {
            bool enable = true;
            if (this.radioButtonNewDataset.Checked) 
            {
                if (this.textBoxNewDatasetName.Text.Length == 0) 
                {
                    enable = false;
                }
            } 
            else 
            {
                if (this.comboBoxExistingDatasets.SelectedIndex == -1) 
                {
                    enable = false;
                }
            }
            if (enable && this._checkedAdapterCount <= 0) 
            {
                enable = false;
            }
            this.buttonOk.Enabled = enable;
        }
        #endregion
    }
}

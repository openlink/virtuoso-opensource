In order to view the result properly via TWiki, install the VirtDocPlugin:

1. Copy the plugin to yourtwiki/lib/TWini/Plugins

2. Ensure that the owner user, owner group and permissions of the plugin file
let Apache access it properly.
(If in doubt, clone properties of DefaultPlugin.pm)

3. Enable the plugin by listing it in INSTALLEDPLUGINS variable, either in
TWiki.TWikiPreferences or in WebPreferences of individual webs.

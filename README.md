# SolrCloud Install Scripts

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Want to automate setting up SolrCloud clusters on Windows? This repo has a load of scripting helpers which can do anything
from making a test cluster on the current machine, to installing individual nodes for a production cluster. It's a toolkit
for crafting your own installations, and a quick way to setup a test instance to play around with.

## Deploying the scripts

Because this is toolkit of (hopefully) useful commandlets that can be used to automate parts of the install process, you need
some sort of controlling script that defines your overall process. There are a couple of examples I've made myself below,
but you may want to modify - but maybe you want to make your own from scratch.

Either way, you can grab the latest release zip, and extract it somewhere. That will get you both the example scripts
and a module of commandlets.

The scripts work by importing the module from a child directory, so you can add two lines to your own script to install
a module to help with `.tar.gz` files and then import the Solr commandlet module:

```Powershell
Install-Module "7Zip4Powershell"
Import-Module ".\SolrCloud-Helpers" -DisableNameChecking
```

You could install the commandlet module to your PowerShell modules directory if you preferred - but I found it simpler
to work like this when deploying quickly onto target servers.

(And yes, I should probably sort out the naming so it doesn't need `-DisableNameChecking` but that's a job for another day)

## Example scripts

For a quick-start the repo includes three example scripts:

Firstly, `Setup-OpenJDK.ps1` can install OpenJDK for the JRE that Solr and Zookeeper depend on. It has one variable defined for configuring
what happens:

* `$targetFolder` - An absolute path to where you want the JRE files installed to. If this folder does not exist it will be
  created.

`Setup-SingleInstance.ps1` can be run to install a single-node SolrCloud instance on a machine. `Setup-TripleInstance.ps1`
will set up a three-node SolrCloud instance on a machine. In both cases there are six variables defined at the top of this script
that you can use to configure it:

* `$targetFolder` - An absolute path to where you want the Zookeeper and Solr files installed to? If this folder does not exist
  it will be created.
* `$installService` - A boolean flag to specifiy whether NSSM services should be installed for Solr and Zookeeper. If not, you
  will need to manually execute Zookeeper and Solr at the appropirate points in the script (where it is waiting for these processes) 
  in order for the script to finish.
* `$collectionPrefix` - The name of your Sitecore instance, which is added to the beginning of the names of your collections.
* `$solrPackage` - The URL for downloading the right Solr version. The default given is for Sitecore v9.1, but commented out values
  are there for v9.2 and v9.3
* `$zkData` - An array of dictionaries. Each element represents a Zookeeper node to create, and should contain the following
  fields:
   * `Host` - The host name to use when talking to this Zookeeper instance
   * `Folder` - The name of the folder to install this instance into. It will be created under the `$targetFolder`.
   * `InstanceID` - The unique instance ID for this node of the Zookeeper ensemble. An integer.
   * `ClientPort` - The network port that Solr will connect to when issuing commands to this Zookeeper node. Must be available
     for use. An integer
   * `EnsemblePorts` - The two ports (separated by a colon - hence as a string) which other Zookeeper nodes will use to talk to
     this node privately.
* `$solrData` - An array of dictionaries. Each element represents a Solr node to create, and should contain the following fields:
   * `Host` - The host name to use when talking to this Solr instance.
   * `Folder` - The name of the folder to install this instance into. It will be created under the `$targetFolder`.
   * `ClientPort` - The network port that the Solr API and Admin UI will be exposed on for HTTPS access.

For example:

```powershell
$targetFolder = "$([Environment]::GetFolderPath("Desktop"))\SolrCloud"
$installService = $false
$collectionPrefix = "search"
$solrPackage = "https://archive.apache.org/dist/lucene/solr/7.2.1/solr-7.2.1.zip" # For Sitecore v9.1

$zkData = @(
	@{Host = "localhost"; Folder="zk"; InstanceID=1; ClientPort = 2971; EnsemblePorts="2981:2991"}
)

$solrData = @(
	@{Host="solr"; Folder="SOLR"; ClientPort=9999}
)
```

All of the publicly exported script functions have help data. So `help Configure-ZooKeeperForSsl` (for example) will give you info about
the behaviour and parameters.

## Known issues

* While the scripts should be able to install the latest v3.5.5 release of Zookeeper, this archive seems to cause an issue with the
  7-Zip library, and it fails to extract. v3.4.14 works fine, however.
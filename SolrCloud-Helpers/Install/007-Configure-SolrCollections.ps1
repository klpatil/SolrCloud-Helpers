
# Encode

# *********************TODO : MAKE THIS DYNAMIC
$FilePath = "C:\projects\Personal\Fork-SolrCloud-Helpers\SolrCloud-Helpers\Configs\solr-8.1-9.3.zip"
$File = [System.IO.File]::ReadAllBytes($FilePath);
 
# returns the base64 string
$Base64String = [System.Convert]::ToBase64String($File);

$zip = $Base64String

function Write-EmbeddedFile
{
  param
  (
    [string]$base64,
    [string]$targetFile
  )
  process
  {
    $Content = [System.Convert]::FromBase64String($base64)
 
    $folder = Split-Path $targetFile
    if(!(Test-Path $folder))
    {
      New-Item $folder -ItemType Directory | Out-Null
    }
 
    Set-Content -Path $targetFile -Value $Content -Encoding Byte
  }
}

function Expand-Base64CoreConfig
{
    param(
        [string]$folder,
        [string]$data
    )

    $zipFile = "$folder\coreConfig.zip"
    $coreConfigFolder = "$folder\CoreConfig"

    if(!(Test-Path $zipFile))
    {
        Write-EmbeddedFile $data $zipFile
    }

    if(!(Test-Path $coreConfigFolder))
    {
        Expand-Archive -Path $zipFile $coreConfigFolder
    }

    return $coreConfigFolder
}

function Test-SolrConfigSetExists
{
    param(
        [string]$solrHost,
        [int]$solrPort,
        [string]$configSetName
    )
    
    $url = "https://$($solrHost):$solrPort/solr/admin/configs?action=LIST"
    
    $result = Invoke-WebRequest -UseBasicParsing -Uri $url
    $match = $result.Content.Contains("`"$configSetName`"")
    
    return $match
}

function Upload-SolrConfigSet
{
    param(
        [string]$solrHost,
        [int]$solrPort,
        [string]$zipFile,
        [string]$configName
    )

    $exists = Test-SolrConfigSetExists $solrHost $solrPort $configName

    if( $exists -ne $true )
    {
        Write-Host "Uploading config set $configName"

        # https://lucene.apache.org/solr/guide/7_2/configsets-api.html
        $uri = "https://$($solrHost):$solrPort/solr/admin/configs?action=UPLOAD&name=$configName"

        Invoke-RestMethod -Uri $uri -Method Post -InFile $zipFile -ContentType "application/octet-stream" | Out-Null
    }
    else
    {
        Write-Host "Config set $configName exists - skipping"
    }
}

function Upload-SolrCollectionConfig
{
    param(
        [string]$solrFolder,
        [string]$coreConfigFolder,
        [string]$coreConfigName,
        [string]$zkConnStr
    )

    Write-Host "Uploading Solr core config for $coreConfigName"

    $solrCmd = "$solrFolder\bin\solr.cmd"

    & $solrCmd zk upconfig -d $coreConfigFolder -n $coreConfigName -z $zkConnStr
}
#

function Test-SolrCollectionExists
{
    param(
        [string]$solrHost,
        [int]$solrPort,
        [string]$solrCollectionName
    )

    $url = "https://$($solrHost):$solrPort/solr/admin/collections?action=LIST"
    
    $result = Invoke-WebRequest -UseBasicParsing -Uri $url
    $match = $result.Content.Contains("`"$solrCollectionName`"")
    
    return $match
}

function Test-SolrAliasExists
{
    param(
        [string]$solrHost,
        [int]$solrPort,
        [string]$solrAliasName
    )
    
    $url = "https://$($solrHost):$solrPort/solr/admin/collections?action=LISTALIASES"
    
    $result = Invoke-WebRequest -UseBasicParsing -Uri $url
    $match = $result.Content.Contains("`"$solrAliasName`"")
    
    return $match
}

function Create-SolrCollection
{
    param(
        [string]$solrHost,
        [int]$solrPort,
        $solrCollectionName,
        $solrCollectionConfig,
        [int]$shards = 1,
        [int]$replicas = 1,
        [int]$shardsPerNode = 1
    )

    $exists = Test-SolrCollectionExists $solrHost $solrPort $solrCollectionName

    if( $exists -eq $false)
    {
        Write-Host "Creating collection $solrCollectionName with config $solrCollectionConfig"

        $url = "https://$($solrHost):$solrPort/solr/admin/collections?action=CREATE&name=$solrCollectionName&numShards=$shards&replicationFactor=$replicas&maxShardsPerNode=$shardsPerNode&collection.configName=$solrCollectionConfig"
        Invoke-WebRequest -UseBasicParsing -Uri $url | Out-Null
    }
    else
    {
        Write-Host "Collection $solrCollectionName exists - skipping"
    }
}

function Create-SolrCollectionAlias
{
    param(
        [string]$solrHost,
        [int]$solrPort,
        $solrCollectionName,
        $solrCollectionAlias
    )

    $exists = Test-SolrAliasExists $solrHost $solrPort $solrCollectionAlias

    if( $exists -eq $false )
    {
        Write-Host "Creating alias $solrCollectionAlias for collection $solrCollectionName"

        # /admin/collections?action=CREATEALIAS&name=name&collections=collectionlist
        $url = "https://$($solrHost):$solrPort/solr/admin/collections?action=CREATEALIAS&name=$solrCollectionAlias&collections=$solrCollectionName"
        Invoke-WebRequest -UseBasicParsing -Uri $url | Out-Null
    }
    else
    {
        Write-Host "Alias $solrCollectionAlias exists - skipping"
    }
}

<#
 .Synopsis
  Creates the standard set of collections and aliases for Sitecore, as an example.

 .Description
  Uses the Solr APIs to create a set of collections for Sitecore, with the specified set of
  replication and sharding parameters. And adds a switch-on-rebuild alias for the xDB index. It will
  upload the standard Sitecore core configs for content and analytics cores, and then use these to set
  up the collections.

 .Parameter targetFolder
  The absolute path to the folder that Solr and/or Zookeeper were installed to. Used to unpack
  the core config archives into prior to setup.

 .Parameter solrHostname
  The host name for accessing the Solr UI/API. This can be the load balanced address of the cluster or
  that of any individual node.

 .Parameter solrClientPort
  The port that the Solr UI/API is exposed on.

 .Parameter shards
  The number of shard cores to split this collection into.

 .Parameter replicas
  The number of replica cores to create for this collection.

 .Parameter shardsPerNode
  The maximum number of shards of a collection which can be put on each Solr node.

 .Parameter collectionPrefix
  The Sitecore instance name prefix put on the beginning of all the collection and alias names.
#>
function Configure-SolrCollection
{
	param(
		[string]$targetFolder = "C:\SolrCloud",
		[string]$solrHostname = "solr",
		[int]$solrClientPort = 9999,

		[int]$shards = 1,
        [int]$replicas = 1,
        [int]$shardsPerNode = 1,

		[string]$collectionPrefix = "sc911"
	)

	$coreConfigFolder = Expand-Base64CoreConfig $targetFolder $zip

	Upload-SolrConfigSet $solrHostname $solrClientPort "$coreConfigFolder\Sitecore.zip" "Sitecore"
	Upload-SolrConfigSet $solrHostname $solrClientPort "$coreConfigFolder\xDB.zip" "xDB"

	Remove-Item $coreConfigFolder -Recurse

	$sitecoreCores = @(
		"$($collectionPrefix)_core_index",
		"$($collectionPrefix)_fxm_master_index",
		"$($collectionPrefix)_fxm_web_index",
		"$($collectionPrefix)_marketingdefinitions_master",
		"$($collectionPrefix)_marketingdefinitions_web",
		"$($collectionPrefix)_marketing_asset_index_master",
		"$($collectionPrefix)_marketing_asset_index_web",
		"$($collectionPrefix)_master_index",
		"$($collectionPrefix)_suggested_test_index",
		"$($collectionPrefix)_testing_index",
        "$($collectionPrefix)_web_index",
        "$($collectionPrefix)_personalization_index",
        "$($collectionPrefix)_sxa_master_index",
        "$($collectionPrefix)_sxa_web_index",
        "$($collectionPrefix)_web_index_rebuild"
    )
    
    # Added for 9.3 "_personalization_index","_sxa_master_index","_sxa_web_index","_web_index_rebuild"

	foreach($core in $sitecoreCores)
	{
		Create-SolrCollection $solrHostname $solrClientPort $core "Sitecore" -shards $shards -replicas $replicas -shardsPerNode $shardsPerNode
	}

	$xDbCores = @(
		"$($collectionPrefix)_xdb",
		"$($collectionPrefix)_xdb_rebuild"
	)

	foreach($core in $xDbCores)
	{
		Create-SolrCollection $solrHostname $solrClientPort "$($core)_internal" "xDB" -shards $shards -replicas $replicas -shardsPerNode $shardsPerNode
		Create-SolrCollectionAlias $solrHostname $solrClientPort "$($core)_internal" $core
	}
}

Export-ModuleMember -Function Configure-SolrCollection
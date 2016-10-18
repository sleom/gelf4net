﻿properties {
	$isCIBuild = $false
	$ProductVersion = "1.0"
	$BuildNumber = "0";
	$PatchVersion = "2"
	$TargetFramework = "net-4.0"
	$DownloadDependentPackages = $true
	$UploadPackage = $false
	$NugetKey = ""
	$PackageVersion = $null
}

$baseDir  = resolve-path .
$releaseRoot = "$baseDir\Release"
$releaseDir = "$releaseRoot\net45"
$buildBase = "$baseDir\build"
$sourceDir = "$baseDir"
$outDir =  "$buildBase\output"
$toolsDir = "$baseDir\tools"
$binariesDir = "$baseDir\binaries"
$ilMergeTool = "$toolsDir\ILMerge\ILMerge.exe"
$nugetExec = "$toolsDir\NuGet\NuGet.exe"
$script:msBuild = ""
$script:isEnvironmentInitialized = $false
$script:ilmergeTargetFramework = ""
$script:msBuildTargetFramework = ""
$script:packageVersion = "0.1.1.7"
$nunitexec = "packages\nunit.runners.2.6.4\tools\nunit-console.exe"
$script:nunitTargetFramework = "/framework=4.0";

include $toolsDir\psake\buildutils.ps1

task default -depends Release

task Clean {
	delete-directory $binariesDir -ErrorAction silentlycontinue
}

task Init -depends Clean {
	create-directory $binariesDir
}

task DetectOperatingSystemArchitecture {
	$isWow64 = ((Get-WmiObject -class "Win32_Processor" -property "AddressWidth").AddressWidth -eq 64)
	if ($isWow64 -eq $true)
	{
		$script:architecture = "x64"
	}
    echo "Machine Architecture is $script:architecture"
}

task InstallDependentPackages {
	cd "$baseDir\packages"
	$files =  dir -Exclude *.config
	cd $baseDir
	$installDependentPackages = $DownloadDependentPackages;
	if($installDependentPackages -eq $false){
		$installDependentPackages = ((($files -ne $null) -and ($files.count -gt 0)) -eq $false)
	}
	if($installDependentPackages){
	 	dir -recurse -include ('packages.config') |ForEach-Object {
		$packageconfig = [io.path]::Combine($_.directory,$_.name)

		write-host $packageconfig

		 exec{ &$nugetExec install $packageconfig -o packages }
		}
	}
 }

task InitEnvironment -depends DetectOperatingSystemArchitecture {

	if($script:isEnvironmentInitialized -ne $true){
		if ($TargetFramework -eq "net-4.0"){
			$netfxInstallroot =""
			$netfxInstallroot =	Get-RegistryValue 'HKLM:\SOFTWARE\Microsoft\.NETFramework\' 'InstallRoot'

			$netfxCurrent = $netfxInstallroot + "v4.0.30319"

			$script:msBuild = $netfxCurrent + "\msbuild.exe"

			echo ".Net 4. 5build requested - $script:msBuild"


			$programFilesPath = (gc env:ProgramFiles)
			if($script:architecture -eq "x64") {
				$programFilesPath = (gc env:"ProgramFiles(x86)")
			}

			$frameworkPath = Join-Path $programFilesPath "Reference Assemblies\Microsoft\Framework\.NETFramework\v4.5"

			$script:ilmergeTargetFramework  =  "v4,$frameworkPath"
			$script:msBuildTargetFramework ="/p:TargetFrameworkVersion=v4.5 /ToolsVersion:4.5"

			$script:nunitTargetFramework = "/framework=4.5";

			$script:isEnvironmentInitialized = $true
		}

	}
}

task CompileMain -depends InstallDependentPackages, InitEnvironment, Init {
 	$solutionFile = "src\gelf4net.sln"
	exec { &$script:msBuild $solutionFile /p:OutDir="$buildBase\" /p:Configuration=Release }

	$assemblies = @()
	$assemblies += dir $buildBase\Gelf4Net.dll
	$assemblies += dir $buildBase\Newtonsoft.Json.dll
	$assemblies += dir $buildBase\RabbitMQ.Client.dll
	$assemblies += dir $buildBase\RabbitMQ.ServiceModel.dll

    cp $buildBase\gelf4net.dll $binariesDir\Gelf4Net.dll

    #Legacy
	& $ilMergeTool /target:"dll" /out:"$binariesDir\Gelf4Net.dll" /internalize /targetplatform:"$script:ilmergeTargetFramework" /log:"$buildBase\gelf4netMergeLog.txt" $assemblies
	$mergeLogContent = Get-Content "$buildBase\gelf4netMergeLog.txt"
	echo "------------------------------gelf4net Merge Log-----------------------"
	echo $mergeLogContent

    #AMQP
    $assemblies = @()
	$assemblies += dir $buildBase\Gelf4Net.Core.dll
	$assemblies += dir $buildBase\Gelf4Net.AmqpAppender.dll
	$assemblies += dir $buildBase\Newtonsoft.Json.dll
	$assemblies += dir $buildBase\RabbitMQ.Client.dll
	$assemblies += dir $buildBase\RabbitMQ.ServiceModel.dll

    & $ilMergeTool /target:"dll" /out:"$binariesDir\Gelf4Net.AmqpAppender.dll" /targetplatform:"$script:ilmergeTargetFramework" /log:"$buildBase\gelf4netAmqpAppenderMergeLog.txt" $assemblies /internalize:excludeinternalize.txt
	$mergeLogContent = Get-Content "$buildBase\gelf4netAmqpAppenderMergeLog.txt"
	echo "------------------------------gelf4net Amqp Appender Merge Log-----------------------"
	echo $mergeLogContent

    #UDP
    $assemblies = @()
	$assemblies += dir $buildBase\Gelf4Net.Core.dll
    $assemblies += dir $buildBase\Gelf4Net.UdpAppender.dll
	$assemblies += dir $buildBase\Newtonsoft.Json.dll

    & $ilMergeTool /target:"dll" /out:"$binariesDir\Gelf4Net.UdpAppender.dll" /targetplatform:"$script:ilmergeTargetFramework" /log:"$buildBase\gelf4netUdpAppenderMergeLog.txt" $assemblies /internalize:excludeinternalize.txt
	$mergeLogContent = Get-Content "$buildBase\gelf4netUdpAppenderMergeLog.txt"
	echo "------------------------------gelf4net Udp Appender Merge Log-----------------------"
	echo $mergeLogContent

    #Http
    $assemblies = @()
	$assemblies += dir $buildBase\Gelf4Net.Core.dll
    $assemblies += dir $buildBase\Gelf4Net.HttpAppender.dll
	$assemblies += dir $buildBase\Newtonsoft.Json.dll

    & $ilMergeTool /target:"dll" /out:"$binariesDir\Gelf4Net.HttpAppender.dll" /targetplatform:"$script:ilmergeTargetFramework" /log:"$buildBase\gelf4netHttpAppenderMergeLog.txt" $assemblies /internalize:excludeinternalize.txt
	$mergeLogContent = Get-Content "$buildBase\gelf4netHttpAppenderMergeLog.txt"
	echo "------------------------------gelf4net Http Appender Merge Log-----------------------"
	echo $mergeLogContent
 }

 task CompileSamples -depends InstallDependentPackages, InitEnvironment, Init {
 	$solutionFile = "examples\examples.sln"
	exec { &$script:msBuild $solutionFile /p:OutDir="$buildBase\examples\" }
 }

 task TestMain -depends CompileMain {

	if((Test-Path -Path $buildBase\test-reports) -eq $false){
		Create-Directory $buildBase\test-reports
	}
	$testAssemblies = @()
	$testAssemblies +=  dir $buildBase\*Tests.dll
	exec {&$nunitexec $testAssemblies $script:nunitTargetFramework}
}

task PrepareRelease -depends CompileMain, TestMain {

	if((Test-Path $releaseRoot) -eq $true){
		Delete-Directory $releaseRoot
	}

	Create-Directory $releaseRoot
	if ($TargetFramework -eq "net-4.5"){
		$releaseDir = "$releaseRoot\net45"
	}
	Create-Directory $releaseDir

	Copy-Item -Force -Recurse "$baseDir\binaries" $releaseDir\binaries -ErrorAction SilentlyContinue
	Copy-Item -Force -Recurse "$baseDir\binaries" $releaseRoot\net45\binaries -ErrorAction SilentlyContinue
}

task CreatePackages -depends PrepareRelease  {

	$packageName = "Gelf4Net"
	if($isCIBuild) {
		$packageName += "-CI"
	}
	if(($UploadPackage) -and ($NugetKey -eq "")){
		throw "Could not find the NuGet access key Package Cannot be uploaded without access key"
	}

    Package-Legacy $UploadPackage
    Package-Amqp-Appender $UploadPackage
    Package-Udp-Appender $UploadPackage
    Package-Http-Appender $UploadPackage

# 	import-module $toolsDir\NuGet\packit.psm1
# 	Write-Output "Loading the module for packing.............."
# 	$packit.push_to_nuget = $UploadPackage
# 	$packit.nugetKey  = $NugetKey
#
# 	$packit.framework_Isolated_Binaries_Loc = "$baseDir\release"
# 	$packit.PackagingArtifactsRoot = "$baseDir\release\PackagingArtifacts"
# 	$packit.packageOutPutDir = "$baseDir\release\packages"
# 	$packit.targeted_Frameworks = "net45";
#
# 	#region Packing
# 	$packit.package_description = "GELF log4net Appender - graylog2. Built for log4net"
# 	$script:packit.package_owners = "micahlmartin"
# 	$script:packit.package_authors = "micahlmartin"
# 	$script:packit.release_notes = ""
# 	$script:packit.package_licenseUrl = "https://opensource.org/licenses/MIT"
# 	$script:packit.package_projectUrl = "https://github.com/jjchiw/gelf4net"
# 	$script:packit.package_tags = "tools utilities"
# 	$script:packit.package_iconUrl = "http://nuget.org/Content/Images/packageDefaultIcon.png"
# 	$script:packit.versionAssemblyName = $script:packit.binaries_Location + "\Gelf4Net.dll"
#     invoke-packit $packageName $PackageVersion @{"log4net"="2.0.0"} "binaries\Gelf4Net.dll" @{}
# 	#endregion
#
# 	remove-module packit
 }

 task GenerateAssemblyInfo {
	if($env:BUILD_NUMBER -ne $null) {
    	$BuildNumber = $env:BUILD_NUMBER
	}

	Write-Output "Build Number: $BuildNumber"

	$asmVersion = $ProductVersion + "." + $PatchVersion + "." + $BuildNumber
	$PackageVersion = $asmVersion


	Write-Output "##teamcity[buildNumber '$asmVersion']"

		$asmInfo = "using System;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Security;
using System.Runtime.CompilerServices;

[assembly: AssemblyCompany(""Gelf4Net"")]
[assembly: AssemblyFileVersion(""$asmVersion"")]
[assembly: AssemblyVersion(""$asmVersion"")]
[assembly: AssemblyCopyright(""Copyright ©  2014"")]
[assembly: ComVisible(false)]
"

	sc -Path "$baseDir\SharedAssemblyInfo.cs" -Value $asmInfo
}

task Release -depends CompileMain, TestMain, CreatePackages, CompileSamples
task CompileAll -depends GenerateAssemblyInfo, CompileMain, TestMain, CompileSamples

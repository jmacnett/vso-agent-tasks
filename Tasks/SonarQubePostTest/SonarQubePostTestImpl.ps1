function InvokeMsBuildRunnerPostTest
{
	$bootstrapperPath = GetBootsrapperPath
	$arguments = GetMsBuildRunnerPostTestArgs

	Invoke-BatchScript $bootstrapperPath -Arguments $arguments
}

function GetBootsrapperPath
{
	$bootstrapperPath = GetTaskContextVariable "MsBuild.SonarQube.BootstrapperPath" 

	if (!$bootstrapperPath -or ![System.IO.File]::Exists($bootstrapperPath))
	{
		throw "The MSBuild.SonarQube.Runner executable could not be found. Check that the build definition includes a SonarQube Pre-Build step"
	}

	Write-Verbose "bootstrapperPath: $bootstrapperPath"
	return $bootstrapperPath;
}

#
# Remarks: Normally all the settings are stored in a file on the build agent, but some well-known sensitive settings need to 
# be passed again as they cannot be stored in non-encrypted files
#
function GetMsBuildRunnerPostTestArgs()
{
	  $serverUsername = GetTaskContextVariable "MsBuild.SonarQube.ServerUsername" 
	  $serverPassword = GetTaskContextVariable "MsBuild.SonarQube.ServerPassword" 
	  $dbUsername = GetTaskContextVariable "MsBuild.SonarQube.DbUsername" 
	  $dbPassword = GetTaskContextVariable "MsBuild.SonarQube.DbPassword" 

	  $sb = New-Object -TypeName "System.Text.StringBuilder"; 
      [void]$sb.Append("end");

	
      if (![String]::IsNullOrWhiteSpace($serverUsername))
      {
          [void]$sb.Append(" /d:sonar.login=" + (EscapeArg($serverUsername))) 
      }
	  
      if (![String]::IsNullOrWhiteSpace($serverPassword))
      {
          [void]$sb.Append(" /d:sonar.password=" + (EscapeArg($serverPassword))) 
      }
	  
	  if (![String]::IsNullOrWhiteSpace($dbUsername))
      {
          [void]$sb.Append(" /d:sonar.jdbc.username=" + (EscapeArg($dbUsername))) 
      }
	  
      if (![String]::IsNullOrWhiteSpace($dbPassword))
      {
          [void]$sb.Append(" /d:sonar.jdbc.password=" + (EscapeArg($dbPassword))) 
      }

	return $sb.ToString();
}

function UploadSummaryMdReport
{
	$sonarQubeBuildDir = GetSonarQubeBuildDirectory

	# Upload the summary markdown file
	$summaryMdPath = [System.IO.Path]::Combine($sonarQubeBuildDir, "out", "summary.md")
	Write-Verbose "summaryMdPath = $summaryMdPath"

	if ([System.IO.File]::Exists($summaryMdPath))
	{
		Write-Verbose "Uploading the summary.md file"
		Write-Host "##vso[build.uploadsummary]$summaryMdPath"
	}
	else
	{
		 Write-Warning "Could not find the summary report file $summaryMdPath"
	}
}


function HandleCodeAnalysisReporting
{
	$sonarQubeAnalysisModeIsIncremental = GetTaskContextVariable "MsBuild.SonarQube.AnalysisModeIsIncremental"
	if ($sonarQubeAnalysisModeIsIncremental -ieq "true")
	{
		GenerateCodeAnalysisReport  
	}
}



function BreakBuildOnQualityGateFailure
{
    $breakBuild = GetTaskContextVariable "MsBuild.SonarQube.BreakBuild"        
    $breakBuildEnabled = Convert-String $breakBuild Boolean

    if ($breakBuildEnabled)
    {
        Write-Verbose "Waiting for the build to complete to analyze quality gate success."
        $sonarDir = GetSonarScannerDirectory 
        $reportTaskFile = [System.IO.Path]::Combine($sonarDir, "report-task.txt");

        if (![System.IO.File]::Exists($reportTaskFile))
        {
            Write-Verbose "Could not find the task details file at $reportTaskFile"
            throw "Cannot determine if the analysis has finished. Possible cause: your SonarQube server version is lower than 5.3 - for more details on how to break the build in this case see http://go.microsoft.com/fwlink/?LinkId=722407"
        }

            // TODO 

    }
    else
    {
        Write-Verbose "Build not set to fail if the associated quality gate fails."
    }
}




################# Helpers ######################


function GetSonarQubeBuildDirectory
{
    $agentBuildDirectory = GetTaskContextVariable "Agent.BuildDirectory" 
	if (!$agentBuildDirectory)
	{
		throw "Could not retrieve the Agent.BuildDirectory variable";
	}

	return [System.IO.Path]::Combine($agentBuildDirectory, ".sonarqube");
}

function GetSonarScannerDirectory
{
    $sqBuildDir = GetSonarQubeBuildDirectory
    
    return [System.IO.Path]::Combine($sqBuildDir, "out", ".sonar");
}

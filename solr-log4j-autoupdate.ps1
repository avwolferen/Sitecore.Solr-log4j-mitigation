if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {  
    Write-Output "Please run this with administrator priviledges..."
    Break
}

$driveLetter = Read-Host -Prompt "Please specify the drive-letter you have the root of solr (c, d, or any other drive-letter). This is the drive-letter where the solr is installed."
if ($driveLetter -eq "") {
    $driveLetter = "c"
}

Write-Output "Looking for Solr on your $($driveLetter): drive... May take a while to find those..."
# Searching for solr.in.cmd files
$files = (Get-CimInstance -Query "Select * from CIM_DataFile Where ((Drive = '$($driveLetter):') AND (FileName = 'solr.in') AND (Extension = 'cmd'))" | Select-Object Name | foreach { $_.Name })

if ($files.Length -eq 0) {
    Write-Output "No solr.in.cmd files found."
    return
}

# Download log2j 
$newVersion = "2.17.1"
$tempFolder = "$($driveLetter):\temp\temp"
if (Test-Path $tempFolder) {
    $null = Remove-Item $tempFolder -Recurse -Force -Confirm:$false
}
$null = New-Item -ItemType Directory -Force -Path $tempFolder

## Download and verify
$log2j = "https://archive.apache.org/dist/logging/log4j/$newVersion/apache-log4j-$newVersion-bin.zip"
$log2jFileName = $log2j.Split('/')[$log2j.Split('/').Length - 1]
$log2jZip = Join-Path $tempFolder $log2jFileName
$log2jHash = ""
if ($newVersion -eq "2.17.0") {
    ## 2.17.0 has a incompatible formatting of the hash
    $log2jHash = "7581F52C6139D7F6961785A1C91D7D1EE68569D6CE70E19E4C17C6FB84E6AFA11A6A0F35A2056C6F6B672AC536352AE840C82BA4D78D3927C14363E8C40EAA08"
}
else {
    $log2jHash = (Invoke-WebRequest -Uri "$($log2j).sha512" -UseBasicParsing).Content.Split(' ')[0].ToUpperInvariant()
}

Write-Output "Hash to validate against is $log2jHash"

if ($log2jHash.Contains(' ')) {
 Write-Error "Possible the filehash file $($log2j).sha512 is in a different and not understood formatting"
 break 
}

Write-Output "Downloading $log2j"
Invoke-WebRequest -Uri $log2j -UseBasicParsing -OutFile $log2jZip 

Write-Output "Verifying downloaded $log2jFileName"
$hashFromZip = Get-FileHash $log2jZip -Algorithm SHA512
Write-Output "SHA512 FileHash for $log2jZip is $($hashFromZip.Hash.ToUpperInvariant())"
if ($log2jHash -ne $hashFromZip.Hash.ToUpperInvariant()) {
    Write-Error "Hash does not match, please verify your downloads!"
    break
}
else {
    Write-Output "Download is verified and OK!"
}

# Unpacking zip archive
Write-Output "Unpacking downloaded $log2jFileName"
$log2jExtract = Join-Path $tempFolder "unpacked"
$null = New-Item -ItemType Directory -Force -Path $log2jExtract
$null = Expand-Archive -Path $log2jZip -DestinationPath $log2jExtract
$log2jExtract = Join-Path $log2jExtract "apache-log4j-$newVersion-bin"

Write-Output "Everything is ready..."

foreach ($file in $files) {
    try {        
        $fileParts = $file.Split('\');
        $serviceName = $fileParts[$fileParts.Length - 3]
        $service = (Get-Service -Name $serviceName -ErrorAction SilentlyContinue)
        $restartService = ($null -ne $service)

        $solrRootDirectory = (([System.IO.FileInfo]$file).Directory.Parent.FullName)
        Write-Output "Starting to process $solrRootDirectory"

        if ($restartService) {
            Write-Output "Stopping service $serviceName"
            Stop-Service -Name $serviceName
        }

        $solrLog2jPath = Join-Path $solrRootDirectory "\server\lib\ext\"
        if (Test-Path $solrLog2jPath) {
            $updateSolr = $false
            $solrLog2jFiles = (Get-ChildItem -Path $solrLog2jPath -Filter "log4j-*.jar" | Where-Object -FilterScript { $_.Name -notmatch "$newVersion.jar" })

            if ($solrLog2jFiles.Length -gt 0) {
                Write-Output "Solr instance in $solrRootDirectory needs update to Log4j $newVersion"
                $updateSolr = $true
            }
            else {
                Write-Output "Solr instance in $solrRootDirectory looks good!"
            }

            if ($true -eq $updateSolr) {
                Write-Output "Updating Log4j $newVersion to Solr in $solrRootDirectory needs update to Log4j"
                foreach ($oldFile in $solrLog2jFiles) {
                    $filenameParts = $oldFile.Name.Replace(".jar", "").Split('-');
                    $oldVersion = $filenameParts[$filenameParts.Length - 1]

                    Write-Output "Replacing $($oldFile.Name) from $oldVersion with $newVersion"
                    Copy-Item -Path (Join-Path $log2jExtract $($oldFile.Name.Replace($oldVersion, $newVersion))) -Destination $solrLog2jPath -Force

                    Remove-Item -Path $oldFile.FullName
                }        
            }
        }
    
        $prometheusLog2jPath = Join-Path $solrRootDirectory "\contrib\prometheus-exporter\lib\"
        if (Test-Path $prometheusLog2jPath) {
            $updatePrometheus = $false
            $prometheusLog2jFiles = (Get-ChildItem -Path $prometheusLog2jPath -Filter "log4j-*.jar" | Where-Object -FilterScript { $_.Name -notmatch "$newVersion.jar" })

            if ($prometheusLog2jFiles.Length -gt 0) {
                Write-Output "Prometheus in Solr  $solrRootDirectory needs update to Log4j $newVersion"
                $updatePrometheus = $true
            }
            else {
                Write-Output "Prometheus in Solr  $solrRootDirectory looks good!"
            }

            if ($true -eq $updatePrometheus) {
                foreach ($oldFile in $prometheusLog2jFiles) {
                    $filenameParts = $oldFile.Name.Replace(".jar", "").Split('-');
                    $oldVersion = $filenameParts[$filenameParts.Length - 1]

                    Write-Output "Replacing $($oldFile.Name) from $oldVersion with $newVersion"
                    Copy-Item -Path (Join-Path $log2jExtract $($oldFile.Name.Replace($oldVersion, $newVersion))) -Destination $prometheusLog2jPath -Force

                    Remove-Item -Path $oldFile.FullName
                }        
            }
        }

        if ($restartService) {
            Write-Output "Starting service $serviceName"
            Start-Service -Name $serviceName
        }

        Write-Output "Done with SOLR $serviceName located in $solrRootDirectory"
    }
    catch {
        Write-Output $_.Exception.Message
    }
}

if (Test-Path $tempFolder) {
    $null = Remove-Item $tempFolder -Recurse -Force -Confirm:$false
}

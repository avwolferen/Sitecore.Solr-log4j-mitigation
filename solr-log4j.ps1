if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {  
    Write-Output "Please run this with administrator priviledges..."
    Break
}

$restartService = $true;
$fix = "set SOLR_OPTS=%SOLR_OPTS% -Dlog4j2.formatMsgNoLookups=true"

$rootPath = "c:\solr"
$altPath = Read-Host -Prompt "Leave empty and press enter if you have installed SOLR from the SIA under the default path (c:\solr) or specify the root folder."
if ($altPath -ne "") {
    Write-Output "Switching to rootpath $altPath"
    $rootPath = $altPath
}

Write-Output "Going to search on $rootPath"
$files = Get-Childitem -Path $rootPath -Include solr.in.cmd -Recurse -File -ErrorAction SilentlyContinue

if ($files.Length -eq 0) {
    Write-Output "No solr.in.cmd files found."
    return
}

foreach ($file in $files) {
    try {        
        $serviceName = $file.FullName.Split('\')[2]

        $contents = Get-Content $file.FullName
        if ($contents.Contains($fix)) {
            Write-Output "$serviceName is already patched!"
        }
        else {
            Write-Output "$serviceName patching file $($file.FullName)"

            $contents += $fix

            Set-Content -Path $file.FullName -Value $contents

            if ($restartService) {

                Write-Output "Restarting SOLR (servicename: $serviceName)"        
                Restart-Service -Force -Name $serviceName
            }
            else {
                Write-Output "Please restart your SOLR (servicename: $serviceName)"
            }
        }
    }
    catch {
        Write-Output $_.Exception.Message
    }
}

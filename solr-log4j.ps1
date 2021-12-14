if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {  
    Write-Output "Please run this with administrator priviledges..."
    Break
}

$restartService = $true;
$fix = "set SOLR_OPTS=%SOLR_OPTS% -Dlog4j2.formatMsgNoLookups=true"

Write-Output "Going to search on c:"
$files = (Get-CimInstance -Query "Select * from CIM_DataFile Where ((Drive = 'C:') AND (FileName = 'solr.in') AND (Extension = 'cmd'))" | Select-Object Name)

if ($files.Length -eq 0) {
    Write-Output "No solr.in.cmd files found."
    return
}

foreach ($file in $files) {
    try {        
        $serviceName = $file.Name.Split('\')[2]

        $contents = Get-Content $file.Name
        if ($contents.Contains($fix)) {
            Write-Output "$serviceName is already patched!"
        }
        else {
            Write-Output "$serviceName patching file $($file.Name)"

            $contents += $fix

            Set-Content -Path $file.Name -Value $contents

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

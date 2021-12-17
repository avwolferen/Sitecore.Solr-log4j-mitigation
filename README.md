# Sitecore.Solr-log4j-mitigation CVE-2021-44228
This repository contains a script that you can run on your (windows) machine to mitigate CVE-2021-44228 by applying the advice as documented on https://solr.apache.org/security.html#apache-solr-affected-by-apache-log4j-cve-2021-44228

The PowerShell script assumes that you have used the default root path when installing Sitecore with the Sitecore Install Assistant on your development machine.
Use the script at your own risk, suggestions and modifications are welcome via pullrequests.

# CVE-2021-45046 update
There is a second script added that is able to replace Log2j with the desired version. It will stop and start the service of there is one that is found based on the directory name of your instance. When the script stumbles on an error it might be the case that your Solr instance is named different then determined from the location where you have Solr running.
 


Set-ExecutionPolicy Bypass -Scope Process -Force
Invoke-Expression ((New-Object System.Net.WebClient).DownloadString("https://chocolatey.org/install.ps1"))
choco install apache-httpd -y --params '"/installLocation:C:\httpd"'
choco install strawberryperl -y
choco install npcap -y --version="0.86.0"
choco install wireshark -y
choco install fiddler -y --install-arguments '"/D=C:\fiddler"'
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/bcosden/AppGW_AzFw_TLS_Lab/master/scripts/httpd.conf" -OutFile "C:\httpd\Apache24\conf\httpd.conf"
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/bcosden/AppGW_AzFw_TLS_Lab/master/scripts/env.pl" -OutFile "C:\httpd\Apache24\cgi-bin\env.pl"
Restart-Service -Name Apache
New-NetFirewallRule -DisplayName "Allow-HTTP" -Direction Inbound -Action Allow -LocalPort 80 -Profile Public -Protocol TCP -RemoteAddress Any
New-NetFirewallRule -DisplayName "Allow-HTTPS" -Direction Inbound -Action Allow -LocalPort 443 -Profile Public -Protocol TCP -RemoteAddress Any

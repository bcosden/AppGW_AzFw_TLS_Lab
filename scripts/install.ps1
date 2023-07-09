Set-ExecutionPolicy Bypass -Scope Process -Force
Invoke-Expression ((New-Object System.Net.WebClient).DownloadString("https://chocolatey.org/install.ps1"))
choco install apache-httpd --params '"/installLocation:C:\httpd"'
choco install strawberryperl
choco install npcap -y --version="0.86.0"
choco install wireshark -y
choco install fiddler -y --install-arguments '"/D=C:\fiddler"'
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/bcosden/AppGW_AzFw_TLS_Lab/master/scripts/httpd.conf" -OutFile "C:\httpd\conf\httpd.conf" -Force
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/bcosden/AppGW_AzFw_TLS_Lab/master/scripts/env.pl" -OutFile "C:\httpd\cgi-bin\env.pl" -Force
Restart-Service -Name apache 

Set-ExecutionPolicy Bypass -Scope Process -Force
powershell -ExecutionPolicy Unrestricted (Invoke-Expression ((New-Object System.Net.WebClient).DownloadString(\'https://chocolatey.org/install.ps1\')))
choco install apache-httpd --params '"/installLocation:C:\httpd"'
choco install strawberryperl
choco install npcap -y --version="0.86.0"
choco install wireshark -y
choco install fiddler -y --install-arguments "/D=C:\\Program` Files\\fiddler"

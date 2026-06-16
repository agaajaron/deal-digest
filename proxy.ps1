# Deal Digest Proxy
$API_KEY = 'YOUR_API_KEY_HERE'
$PORT = 8080

Add-Type -AssemblyName System.Web

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$PORT/")
$listener.Start()

Write-Host "Deal Digest running at http://localhost:$PORT/index.html" -ForegroundColor Green
Write-Host "Press Ctrl+C to stop." -ForegroundColor Gray

while ($listener.IsListening) {
    $context = $listener.GetContext()
    $request  = $context.Request
    $response = $context.Response

    $response.Headers.Add("Access-Control-Allow-Origin",  "*")
    $response.Headers.Add("Access-Control-Allow-Headers", "*")
    $response.Headers.Add("Access-Control-Allow-Methods", "POST,GET,OPTIONS")

    if ($request.HttpMethod -eq "OPTIONS") {
        $response.StatusCode = 200
        $response.Close()
        continue
    }

    if ($request.HttpMethod -eq "GET") {
        $file = Join-Path (Split-Path $MyInvocation.MyCommand.Path) "index.html"
        if (Test-Path $file) {
            $bytes = [System.IO.File]::ReadAllBytes($file)
            $response.ContentType = "text/html; charset=utf-8"
            $response.ContentLength64 = $bytes.Length
            $response.OutputStream.Write($bytes, 0, $bytes.Length)
        }
        $response.Close()
        continue
    }

    if ($request.HttpMethod -eq "POST") {
        $reader = New-Object System.IO.StreamReader($request.InputStream, [System.Text.Encoding]::UTF8)
        $body   = $reader.ReadToEnd()
        $reader.Close()

        try {
            $headers = @{
                "x-api-key"        = $API_KEY
                "anthropic-version" = "2023-06-01"
                "anthropic-beta"   = "web-search-2025-03-05"
            }

            $result = Invoke-RestMethod `
                -Uri "https://api.anthropic.com/v1/messages" `
                -Method POST `
                -Headers $headers `
                -ContentType "application/json; charset=utf-8" `
                -Body $body `
                -TimeoutSec 120

            $json = $result | ConvertTo-Json -Depth 20 -Compress
            Write-Host "OK - response length: $($json.Length)" -ForegroundColor Green

            $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
            $response.ContentType = "application/json; charset=utf-8"
            $response.ContentLength64 = $bytes.Length
            $response.StatusCode = 200
            $response.OutputStream.Write($bytes, 0, $bytes.Length)
        }
        catch {
            $msg = $_.Exception.Message
            Write-Host "ERROR: $msg" -ForegroundColor Red
            $err   = @{ error = $msg } | ConvertTo-Json
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($err)
            $response.ContentType = "application/json"
            $response.ContentLength64 = $bytes.Length
            $response.StatusCode = 500
            $response.OutputStream.Write($bytes, 0, $bytes.Length)
        }

        $response.Close()
    }
}

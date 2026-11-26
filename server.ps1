param(
    [int]$Port = 3000,
    [string]$RootDirectory = $PSScriptRoot
)

if (-not $RootDirectory) {
    $RootDirectory = "C:\Users\lenovo\Desktop\gurlal sohal"
}

$siteDir = Join-Path $RootDirectory "stitch_gurlal_sohal_athlete_portfolio"
$publicDir = Join-Path $RootDirectory "public"

$listener = New-Object System.Net.HttpListener

# Bind to localhost and 127.0.0.1
$prefixLocalhost = "http://localhost:$Port/"
$prefixLoopback = "http://127.0.0.1:$Port/"

try {
    $listener.Prefixes.Add($prefixLocalhost)
    $listener.Prefixes.Add($prefixLoopback)
    $listener.Start()
    Write-Output "Portfolio dev server active at:"
    Write-Output "  -> $prefixLocalhost"
    Write-Output "  -> $prefixLoopback"
} catch {
    # If 3000 is occupied, fall back to 8080
    $Port = 8080
    $listener = New-Object System.Net.HttpListener
    $prefixLocalhost = "http://localhost:$Port/"
    $prefixLoopback = "http://127.0.0.1:$Port/"
    $listener.Prefixes.Add($prefixLocalhost)
    $listener.Prefixes.Add($prefixLoopback)
    $listener.Start()
    Write-Output "Port 3000 busy. Portfolio dev server active at:"
    Write-Output "  -> $prefixLocalhost"
    Write-Output "  -> $prefixLoopback"
}

$mimeTypes = @{
    ".html" = "text/html; charset=utf-8"
    ".css"  = "text/css; charset=utf-8"
    ".js"   = "application/javascript; charset=utf-8"
    ".json" = "application/json; charset=utf-8"
    ".png"  = "image/png"
    ".jpg"  = "image/jpeg"
    ".jpeg" = "image/jpeg"
    ".webp" = "image/webp"
    ".avif" = "image/avif"
    ".svg"  = "image/svg+xml"
    ".gif"  = "image/gif"
    ".ico"  = "image/x-icon"
    ".mp4"  = "video/mp4"
    ".webm" = "video/webm"
    ".mov"  = "video/quicktime"
    ".ogg"  = "video/ogg"
    ".pdf"  = "application/pdf"
}

# Clean route rewrites matching vercel.json
$routeRewrites = @{
    ""              = "index.html"
    "/"             = "index.html"
    "/home"         = "index.html"
    "/about"        = "about.html"
    "/achievements" = "achievements.html"
    "/matches"      = "matches.html"
    "/gallery"      = "gallery.html"
    "/contact"      = "contact.html"
    "/admin"        = "admin.html"
}

while ($listener.IsListening) {
    try {
        $context = $listener.GetContext()
        $request = $context.Request
        $response = $context.Response

        $urlPath = [System.Uri]::UnescapeDataString($request.Url.LocalPath)
        $cleanPath = $urlPath.TrimEnd('/')
        if ($cleanPath -eq "") { $cleanPath = "/" }

        # Preflight CORS Options
        if ($request.HttpMethod -eq "OPTIONS") {
            $response.StatusCode = 204
            $response.Headers.Add("Access-Control-Allow-Origin", "*")
            $response.Headers.Add("Access-Control-Allow-Methods", "GET, HEAD, POST, OPTIONS")
            $response.Headers.Add("Access-Control-Allow-Headers", "*")
            $response.Close()
            continue
        }

        $candidates = @()

        # 1. Check clean route map
        if ($routeRewrites.ContainsKey($cleanPath)) {
            $target = $routeRewrites[$cleanPath]
            $candidates += (Join-Path $RootDirectory $target)
            $candidates += (Join-Path $siteDir $target)
        }

        # 2. Check path as requested
        $rel = $urlPath.TrimStart('/') -replace '/', '\'
        if ($rel) {
            # Direct file
            $candidates += (Join-Path $RootDirectory $rel)
            $candidates += (Join-Path $siteDir $rel)
            $candidates += (Join-Path $publicDir $rel)

            # Clean URL: try adding .html
            if (-not [System.IO.Path]::HasExtension($rel)) {
                $candidates += (Join-Path $RootDirectory "$rel.html")
                $candidates += (Join-Path $siteDir "$rel.html")
            }

            # If starts with images\ or videos\, check public\
            if ($rel -match '^(images|videos)\\(.+)$') {
                $candidates += (Join-Path $publicDir $rel)
                $candidates += (Join-Path (Join-Path $siteDir "public") $rel)
            }

            # If starts with public\, check with and without
            if ($rel -match '^public\\(.+)$') {
                $candidates += (Join-Path $RootDirectory $rel)
                $candidates += (Join-Path $publicDir $matches[1])
                $candidates += (Join-Path (Join-Path $siteDir "public") $matches[1])
            }
        }

        $foundPath = $null
        foreach ($c in $candidates) {
            if ($c -and (Test-Path $c -PathType Leaf)) {
                $foundPath = $c
                break
            }
        }

        if ($foundPath -and (Test-Path $foundPath -PathType Leaf)) {
            $ext = [System.IO.Path]::GetExtension($foundPath).ToLower()
            $mime = if ($mimeTypes.ContainsKey($ext)) { $mimeTypes[$ext] } else { "application/octet-stream" }
            $fileInfo = New-Object System.IO.FileInfo($foundPath)
            $fileLength = $fileInfo.Length

            # Explicit HTTP headers without HSTS or upgrade directives
            $response.Headers.Add("Accept-Ranges", "bytes")
            $response.Headers.Add("Access-Control-Allow-Origin", "*")
            $response.Headers.Add("Cache-Control", "no-cache, no-store, must-revalidate")
            $response.Headers.Add("Pragma", "no-cache")
            $response.Headers.Add("Expires", "0")
            $response.Headers.Add("X-Content-Type-Options", "nosniff")
            $response.ContentType = $mime

            # Handle HEAD method specifically without writing response body
            if ($request.HttpMethod -eq "HEAD") {
                $response.StatusCode = 200
                $response.ContentLength64 = $fileLength
                $response.Close()
                continue
            }

            $rangeHeader = $request.Headers["Range"]
            if ($rangeHeader -and $rangeHeader.StartsWith("bytes=")) {
                $range = $rangeHeader.Substring(6)
                $parts = $range.Split('-')
                $start = [int64]$parts[0]
                $end = if ($parts.Length -gt 1 -and $parts[1] -ne "") { [int64]$parts[1] } else { $fileLength - 1 }

                if ($start -ge $fileLength) {
                    $response.StatusCode = 416
                    $response.Headers.Add("Content-Range", "bytes */$fileLength")
                    $response.Close()
                    continue
                }

                if ($end -ge $fileLength) { $end = $fileLength - 1 }
                $contentLength = $end - $start + 1

                $response.StatusCode = 206
                $response.ContentLength64 = $contentLength
                $response.Headers.Add("Content-Range", "bytes $start-$end/$fileLength")

                $fs = [System.IO.File]::OpenRead($foundPath)
                $null = $fs.Seek($start, [System.IO.SeekOrigin]::Begin)
                $buffer = New-Object byte[] 65536
                $bytesRemaining = $contentLength

                while ($bytesRemaining -gt 0) {
                    $bytesToRead = [Math]::Min($buffer.Length, $bytesRemaining)
                    $bytesRead = $fs.Read($buffer, 0, $bytesToRead)
                    if ($bytesRead -le 0) { break }
                    $response.OutputStream.Write($buffer, 0, $bytesRead)
                    $bytesRemaining -= $bytesRead
                }
                $fs.Close()
                $response.Close()
            } else {
                $response.StatusCode = 200
                $response.ContentLength64 = $fileLength
                $fs = [System.IO.File]::OpenRead($foundPath)
                $buffer = New-Object byte[] 65536
                while (($bytesRead = $fs.Read($buffer, 0, $buffer.Length)) -gt 0) {
                    $response.OutputStream.Write($buffer, 0, $bytesRead)
                }
                $fs.Close()
                $response.Close()
            }
        } else {
            $response.StatusCode = 404
            $response.ContentType = "text/html; charset=utf-8"
            $msg = [System.Text.Encoding]::UTF8.GetBytes("<h1>404 Not Found</h1><p>Requested URL was not found on local development server: $urlPath</p>")
            $response.ContentLength64 = $msg.Length
            if ($request.HttpMethod -ne "HEAD") {
                $response.OutputStream.Write($msg, 0, $msg.Length)
            }
            $response.Close()
        }
    } catch {
        # Catch client disconnects gracefully
    }
}

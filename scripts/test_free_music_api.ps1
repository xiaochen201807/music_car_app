param(
    [string]$BaseUrl = "https://music.sy110.eu.org/api/v1/freemusic",
    [int]$TimeoutSec = 45,
    [switch]$IncludeMutating,
    [switch]$AsJson
)

$ErrorActionPreference = "Continue"
$ProgressPreference = "SilentlyContinue"

$Headers = @{
    "User-Agent" = "MusicCarApp API Audit"
    "Accept" = "application/json,text/plain,*/*"
    "Referer" = "https://music.sy110.eu.org/music"
}

$Tests = @(
    @{ Name = "sources"; Method = "GET"; Path = "/sources"; Expect = @(200) },
    @{ Name = "search-song"; Method = "GET"; Path = "/search"; Query = @{ q = "周杰伦"; type = "song"; page = "0" }; Expect = @(200) },
    @{ Name = "search-playlist"; Method = "GET"; Path = "/search"; Query = @{ q = "周杰伦"; type = "playlist"; page = "0" }; Expect = @(200) },
    @{ Name = "search-album"; Method = "GET"; Path = "/search"; Query = @{ q = "周杰伦"; type = "album"; page = "0" }; Expect = @(200) },
    @{ Name = "search-artist"; Method = "GET"; Path = "/search"; Query = @{ q = "周杰伦"; type = "artist"; page = "0" }; Expect = @(200) },
    @{ Name = "search-hot"; Method = "GET"; Path = "/search/hot"; Expect = @(200) },
    @{ Name = "search-suggest"; Method = "GET"; Path = "/search/suggest"; Query = @{ q = "周" }; Expect = @(200) },
    @{ Name = "recommend"; Method = "GET"; Path = "/recommend"; Expect = @(200) },
    @{ Name = "playlist"; Method = "GET"; Path = "/playlist"; Query = @{ id = "1012368062"; source = "kuwo" }; Expect = @(200) },
    @{ Name = "playlist-page"; Method = "GET"; Path = "/playlist/page"; Query = @{ id = "1012368062"; source = "kuwo"; offset = "0"; size = "5" }; Expect = @(200) },
    @{ Name = "resolve-playlist"; Method = "GET"; Path = "/playlist/resolve"; Query = @{ link = "http://www.kuwo.cn/playlist_detail/1012368062" }; Expect = @(200, 400) },
    @{ Name = "album-songs"; Method = "GET"; Path = "/album/songs"; Query = @{ name = "叶惠美"; artist = "周杰伦"; page = "0"; size = "5" }; Expect = @(200) },
    @{ Name = "qualities"; Method = "GET"; Path = "/qualities"; Query = @{ name = "晴天"; artist = "周杰伦"; duration = "269" }; Expect = @(200) },
    @{ Name = "song-url"; Method = "GET"; Path = "/song_url"; Query = @{ id = "228908"; source = "kuwo"; name = "晴天"; artist = "周杰伦"; duration = "269"; br = "320kmp3" }; Expect = @(200) },
    @{ Name = "play-url"; Method = "GET"; Path = "/play_url"; Query = @{ rid = "228908"; br = "320kmp3" }; Expect = @(200) },
    @{ Name = "lyric"; Method = "GET"; Path = "/lyric"; Query = @{ id = "228908"; source = "kuwo"; name = "晴天"; artist = "周杰伦" }; Expect = @(200) },
    @{ Name = "yrc"; Method = "GET"; Path = "/yrc"; Query = @{ id = "228908"; source = "kuwo" }; Expect = @(200) },
    @{ Name = "switch-source"; Method = "GET"; Path = "/switch_source"; Query = @{ name = "晴天"; artist = "周杰伦"; source = "kuwo"; target = "netease"; duration = "269" }; Expect = @(200, 404) },
    @{ Name = "toplist-netease"; Method = "GET"; Path = "/toplist/netease"; Expect = @(200) },
    @{ Name = "toplist-kuwo-menu"; Method = "GET"; Path = "/toplist/kuwo/menu"; Expect = @(200) },
    @{ Name = "toplist-kuwo-songs"; Method = "GET"; Path = "/toplist/kuwo/songs"; Query = @{ bangid = "16"; page = "0"; size = "5" }; Expect = @(200) },
    @{ Name = "toplist-kuwo-all"; Method = "GET"; Path = "/toplist/kuwo/all"; Query = @{ bangid = "16" }; Expect = @(200) },
    @{ Name = "kuwo-playlist-tags"; Method = "GET"; Path = "/kuwo/playlist/tags"; Expect = @(200) },
    @{ Name = "kuwo-playlist-by-tag"; Method = "GET"; Path = "/kuwo/playlist/byTag"; Query = @{ id = "1848"; pn = "1"; rn = "5"; order = "hot" }; Expect = @(200) },
    @{ Name = "kuwo-artists"; Method = "GET"; Path = "/kuwo/artists"; Query = @{ category = "0"; pn = "1"; rn = "5" }; Expect = @(200) },
    @{ Name = "personal-fm"; Method = "GET"; Path = "/personal_fm"; Expect = @(200) },
    @{ Name = "recommend-playlists"; Method = "GET"; Path = "/recommend-playlists"; Query = @{ page = "1"; pageSize = "5" }; Auth = $true; Expect = @(200, 401) },
    @{ Name = "config"; Method = "GET"; Path = "/config"; Auth = $true; Expect = @(200, 401) },
    @{ Name = "favorites"; Method = "GET"; Path = "/favorites"; Auth = $true; Expect = @(200, 401) },
    @{ Name = "favorite-ids"; Method = "GET"; Path = "/favorite_ids"; Auth = $true; Expect = @(200, 401) },
    @{ Name = "collections"; Method = "GET"; Path = "/collections"; Auth = $true; Expect = @(200, 401) },
    @{ Name = "collection"; Method = "GET"; Path = "/collection"; Query = @{ id = "1" }; Auth = $true; Expect = @(200, 401, 404) },
    @{ Name = "saved-playlists"; Method = "GET"; Path = "/saved_playlists"; Auth = $true; Expect = @(200, 401) },
    @{ Name = "recent-plays"; Method = "GET"; Path = "/recent_plays"; Auth = $true; Expect = @(200, 401) },
    @{ Name = "settings"; Method = "GET"; Path = "/settings"; Auth = $true; Expect = @(200, 401) },
    @{ Name = "mounted-directories"; Method = "GET"; Path = "/mounted/directories"; Auth = $true; Expect = @(200, 401) },
    @{ Name = "mounted-tracks"; Method = "GET"; Path = "/mounted/tracks"; Query = @{ directory_id = "1"; keyword = "" }; Auth = $true; Expect = @(200, 400, 401, 404) },
    @{ Name = "download-url-shape"; Method = "HEAD"; Path = "/download"; Query = @{ id = "228908"; source = "kuwo"; name = "晴天"; artist = "周杰伦"; duration = "269"; br = "320kmp3" }; Expect = @(200, 302, 400, 401, 405) },

    @{ Name = "add-favorite"; Method = "POST"; Path = "/favorites"; Auth = $true; Mutates = $true; Expect = @(200, 201, 401) },
    @{ Name = "remove-favorite"; Method = "DELETE"; Path = "/favorites"; Query = @{ id = "228908"; source = "kuwo" }; Auth = $true; Mutates = $true; Expect = @(200, 204, 401) },
    @{ Name = "create-collection"; Method = "POST"; Path = "/collections"; Auth = $true; Mutates = $true; Expect = @(200, 201, 401) },
    @{ Name = "update-collection"; Method = "PUT"; Path = "/collections/1"; Auth = $true; Mutates = $true; Expect = @(200, 401, 404) },
    @{ Name = "delete-collection"; Method = "DELETE"; Path = "/collections/1"; Auth = $true; Mutates = $true; Expect = @(200, 204, 401, 404) },
    @{ Name = "add-collection-song"; Method = "POST"; Path = "/collections/1/songs"; Auth = $true; Mutates = $true; Expect = @(200, 201, 401, 404) },
    @{ Name = "remove-collection-song"; Method = "DELETE"; Path = "/collections/1/songs"; Query = @{ id = "228908"; source = "kuwo" }; Auth = $true; Mutates = $true; Expect = @(200, 204, 401, 404) },
    @{ Name = "save-playlist"; Method = "POST"; Path = "/saved_playlists"; Auth = $true; Mutates = $true; Expect = @(200, 201, 401) },
    @{ Name = "remove-saved-playlist"; Method = "DELETE"; Path = "/saved_playlists"; Query = @{ id = "1012368062"; source = "kuwo" }; Auth = $true; Mutates = $true; Expect = @(200, 204, 401) },
    @{ Name = "record-recent-play"; Method = "POST"; Path = "/recent_plays"; Auth = $true; Mutates = $true; Expect = @(200, 201, 401) },
    @{ Name = "clear-recent-plays"; Method = "DELETE"; Path = "/recent_plays"; Auth = $true; Mutates = $true; Expect = @(200, 204, 401) },
    @{ Name = "remove-recent-play"; Method = "DELETE"; Path = "/recent_plays/song"; Query = @{ id = "228908"; source = "kuwo" }; Auth = $true; Mutates = $true; Expect = @(200, 204, 401) },
    @{ Name = "save-settings"; Method = "PUT"; Path = "/settings"; Auth = $true; Mutates = $true; Expect = @(200, 401) },
    @{ Name = "add-recommend-playlist"; Method = "POST"; Path = "/recommend-playlists"; Auth = $true; Mutates = $true; Expect = @(200, 201, 401) },
    @{ Name = "update-config"; Method = "PUT"; Path = "/config"; Auth = $true; Mutates = $true; Expect = @(200, 401, 403) },
    @{ Name = "save-mounted-directory"; Method = "POST"; Path = "/mounted/directories"; Auth = $true; Mutates = $true; Expect = @(200, 201, 401) },
    @{ Name = "refresh-mounted-directory"; Method = "POST"; Path = "/mounted/directories/1/refresh"; Auth = $true; Mutates = $true; Expect = @(200, 401, 404) },
    @{ Name = "delete-mounted-directory"; Method = "DELETE"; Path = "/mounted/directories/1"; Auth = $true; Mutates = $true; Expect = @(200, 204, 401, 404) },
    @{ Name = "download-deduct"; Method = "POST"; Path = "/download-deduct"; Auth = $true; Mutates = $true; Expect = @(200, 401, 402, 403) }
)

function New-TestUri($Path, $Query) {
    $builder = [System.UriBuilder]::new($BaseUrl.TrimEnd("/") + $Path)
    if ($Query) {
        $pairs = @()
        foreach ($key in $Query.Keys) {
            $pairs += [System.Uri]::EscapeDataString($key) + "=" + [System.Uri]::EscapeDataString([string]$Query[$key])
        }
        $builder.Query = $pairs -join "&"
    }
    return $builder.Uri.AbsoluteUri
}

function Invoke-FreeMusicApiProbe($Test) {
    $url = New-TestUri $Test.Path $Test.Query
    if ($Test.Mutates -and -not $IncludeMutating) {
        return [pscustomobject]@{
            Name = $Test.Name
            Method = $Test.Method
            Status = "SKIP"
            Expected = ($Test.Expect -join ",")
            Passed = $true
            Auth = [bool]$Test.Auth
            Mutates = $true
            Url = $url
            Sample = "Skipped by default. Re-run with -IncludeMutating only against a safe test account."
        }
    }

    $body = $null
    if ($Test.Method -in @("POST", "PUT")) {
        $body = "{}"
    }

    try {
        $response = Invoke-WebRequest `
            -Uri $url `
            -Method $Test.Method `
            -Headers $Headers `
            -Body $body `
            -ContentType "application/json" `
            -Proxy $null `
            -TimeoutSec $TimeoutSec
        $status = [int]$response.StatusCode
        $sample = ($response.Content -replace "`r?`n", " ")
        if ($sample.Length -gt 260) { $sample = $sample.Substring(0, 260) }
    } catch {
        $resp = $_.Exception.Response
        if ($resp) {
            $status = [int]$resp.StatusCode
            $sample = $_.Exception.Message
        } else {
            $status = "ERROR"
            $sample = $_.Exception.Message
        }
    }

    return [pscustomobject]@{
        Name = $Test.Name
        Method = $Test.Method
        Status = $status
        Expected = ($Test.Expect -join ",")
        Passed = $Test.Expect -contains $status
        Auth = [bool]$Test.Auth
        Mutates = [bool]$Test.Mutates
        Url = $url
        Sample = $sample
    }
}

$results = foreach ($test in $Tests) {
    Invoke-FreeMusicApiProbe $test
}

if ($AsJson) {
    $results | ConvertTo-Json -Depth 6
} else {
    $results | Format-Table Name, Method, Status, Expected, Passed, Auth, Mutates -AutoSize
}

$failed = @($results | Where-Object { -not $_.Passed })
if ($failed.Count -gt 0) {
    Write-Error "FreeMusic API probe failed for $($failed.Count) endpoint(s)."
    exit 1
}

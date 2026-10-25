# Servidor local da Apuração 2026 (Presidente).
# Serve index.html e faz proxy dos JSONs do TSE e da malha do IBGE
# (o TSE não envia cabeçalho CORS, então o navegador não pode buscar direto).
# Os arquivos do TSE são buscados em paralelo com If-None-Match (ETag): quando nada mudou,
# o TSE responde 304 sem corpo e reaproveitamos a cópia local.
param([int]$Port = 8026)

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
[Net.ServicePointManager]::DefaultConnectionLimit = 64   # padrão do .NET é 2 por host; municípios pedem centenas de arquivos
Add-Type -AssemblyName System.Net.Http
$root = $PSScriptRoot
$TSE = 'https://resultados.tse.jus.br/oficial/'
$IBGE = 'https://servicodados.ibge.gov.br/api/v3/malhas/paises/BR?formato=application/vnd.geo%2Bjson&qualidade=minima&intrarregiao=UF'
$INTERVALO_MIN = 1   # segundos; nunca consulta o TSE mais de uma vez por segundo, mesmo com várias abas
$cache = @{}         # url -> @{ etag; body } (última versão válida)
$lote = @{ chave = ''; t = [datetime]::MinValue; body = $null }

$http = New-Object Net.Http.HttpClient
$http.Timeout = [TimeSpan]::FromSeconds(25)
$http.DefaultRequestHeaders.UserAgent.ParseAdd('apuracao-2026-local')

function Update-Arquivos([string[]]$urls) {
  $tasks = foreach ($u in $urls) {
    $req = New-Object Net.Http.HttpRequestMessage ([Net.Http.HttpMethod]::Get), $u
    if ($cache[$u] -and $cache[$u].etag) { [void]$req.Headers.TryAddWithoutValidation('If-None-Match', $cache[$u].etag) }
    $http.SendAsync($req)
  }
  try { [Threading.Tasks.Task]::WaitAll([Threading.Tasks.Task[]]@($tasks)) } catch {}
  for ($i = 0; $i -lt $urls.Count; $i++) {
    $t = @($tasks)[$i]
    if ($t.Status -ne 'RanToCompletion') { continue }        # falha de rede: mantém a última cópia
    $r = $t.Result
    if ($r.IsSuccessStatusCode) {
      $etag = $null; if ($r.Headers.ETag) { $etag = $r.Headers.ETag.Tag }
      $cache[$urls[$i]] = @{ etag = $etag; body = $r.Content.ReadAsByteArrayAsync().Result }
    } elseif ([int]$r.StatusCode -eq 404) {
      $cache.Remove($urls[$i])                               # arquivo não publicado
    }
    $r.Dispose()
  }
}

# Responde {"br": {...}, "sp": {...}, "xx": null} com todos os arquivos de uma vez
function Get-Lote([string]$base, [string]$arq, [string[]]$abrs) {
  $chave = "$base|$arq|$($abrs -join ',')"
  if ($lote.chave -eq $chave -and ((Get-Date) - $lote.t).TotalSeconds -lt $INTERVALO_MIN) { return $lote.body }
  $urls = $abrs | ForEach-Object { "$TSE$base/$($_.Substring(0,2))/$_-$arq.json" }
  Update-Arquivos $urls
  $ms = New-Object IO.MemoryStream
  $w = { param($s) $b = [Text.Encoding]::UTF8.GetBytes($s); $ms.Write($b, 0, $b.Length) }
  & $w '{'
  for ($i = 0; $i -lt $abrs.Count; $i++) {
    if ($i) { & $w ',' }
    & $w ('"' + $abrs[$i] + '":')
    $c = $cache[$urls[$i]]
    if ($c) { $ms.Write($c.body, 0, $c.body.Length) } else { & $w 'null' }
  }
  & $w '}'
  $lote.chave = $chave; $lote.t = Get-Date; $lote.body = $ms.ToArray()
  return $lote.body
}

# Se a porta estiver ocupada (por exemplo, outro servidor já aberto), tenta as seguintes
$listener = $null
foreach ($p in $Port..($Port + 9)) {
  $l = New-Object Net.HttpListener
  $l.Prefixes.Add("http://localhost:$p/")
  try { $l.Start(); $listener = $l; $Port = $p; break }
  catch { $l.Close(); Write-Host "Porta $p ocupada, tentando a próxima..." }
}
if (-not $listener) { Write-Host 'Nenhuma porta livre entre' $Port 'e' ($Port + 9); exit 1 }
Write-Host "Apuração 2026 em http://localhost:$Port/  (Ctrl+C para encerrar)"

while ($listener.IsListening) {
  $ctx = $listener.GetContext()
  $req = $ctx.Request
  $path = $req.Url.AbsolutePath
  $res = $ctx.Response
  try {
    $type = 'application/json; charset=utf-8'
    if ($path -eq '/api/lote') {
      $base = $req.QueryString['base']; $arq = $req.QueryString['arq']; $abrs = $req.QueryString['abr'] -split ','
      if ($base -notmatch '^[a-z0-9]+/\d+/dados$' -or $arq -notmatch '^[a-z0-9\-]+$' -or ($abrs.Count -gt 1000) -or ($abrs | Where-Object { $_ -notmatch '^[a-z]{2}(\d{5})?$' })) { throw 'parâmetros inválidos' }
      $r = @{ code = 200; body = (Get-Lote $base $arq $abrs) }
    } elseif ($path -eq '/municipios-tse.json') {
      $r = @{ code = 200; body = [IO.File]::ReadAllBytes((Join-Path $root 'public\municipios-tse.json')) }
    } elseif ($path -eq '/malha-uf-ibge.json') {
      $file = Join-Path $root 'public\malha-uf-ibge.json'
      if (-not (Test-Path $file)) {
        $bytes = $http.GetByteArrayAsync($IBGE).Result
        [IO.File]::WriteAllBytes($file, $bytes)
      }
      $r = @{ code = 200; body = [IO.File]::ReadAllBytes($file) }
    } else {
      $type = 'text/html; charset=utf-8'
      $r = @{ code = 200; body = [IO.File]::ReadAllBytes((Join-Path $root 'public\index.html')) }
    }
    $res.StatusCode = $r.code
    $res.ContentType = $type
    $res.Headers.Add('Cache-Control', 'no-store')
    $res.OutputStream.Write($r.body, 0, $r.body.Length)
  } catch {
    $res.StatusCode = 400
  } finally { $res.Close() }
}

// Netlify Function: equivalente ao /api/lote do serve.ps1.
// Busca em paralelo os arquivos EA20 do TSE (Brasil, exterior e UFs) e devolve tudo num só JSON:
// {"br": {...}, "sp": {...}, "xx": null}. Usa If-None-Match (ETag) para o TSE só reenviar o que mudou,
// e o cache da CDN da Netlify (1 s) faz todos os visitantes compartilharem a mesma consulta.
const TSE = 'https://resultados.tse.jus.br/oficial/';
const cache = new Map(); // url -> { etag, body } enquanto a instância da função estiver ativa

let pausaAte = 0; // após um 429 do TSE, não consulta até esse instante (ms)

async function buscar(url) {
  const c = cache.get(url);
  if (Date.now() < pausaAte) return c?.body ?? null;
  try {
    const r = await fetch(url, {
      headers: c?.etag ? { 'If-None-Match': c.etag } : {},
      signal: AbortSignal.timeout(8000),
    });
    if (r.status === 304 && c) return c.body;
    if (r.ok) {
      const body = await r.text();
      JSON.parse(body); // garante que é JSON válido antes de guardar
      cache.set(url, { etag: r.headers.get('etag'), body });
      return body;
    }
    if (r.status === 429) pausaAte = Date.now() + Math.max(5, Number(r.headers.get('retry-after')) || 30) * 1000;
    if (r.status === 404) { cache.delete(url); return null; } // arquivo não publicado
  } catch {}
  return c?.body ?? null; // falha temporária: mantém a última versão válida
}

export default async (req) => {
  const q = new URL(req.url).searchParams;
  const base = q.get('base') || '', arq = q.get('arq') || '', abrs = (q.get('abr') || '').split(',');
  if (!/^[a-z0-9]+\/\d+\/dados$/.test(base) || !/^[a-z0-9-]+$/.test(arq) ||
      abrs.length > 1000 || abrs.some(a => !/^[a-z]{2}(\d{5})?$/.test(a))) {
    return new Response('parâmetros inválidos', { status: 400 });
  }
  // UF ("sp") ou município ("sp71072", pasta da UF); em blocos de 25 para não abrir conexões demais
  const corpos = [];
  for (let i = 0; i < abrs.length; i += 25) {
    corpos.push(...await Promise.all(abrs.slice(i, i + 25).map(a => buscar(`${TSE}${base}/${a.slice(0, 2)}/${a}-${arq}.json`))));
  }
  const json = '{' + abrs.map((a, i) => `"${a}":${corpos[i] ?? 'null'}`).join(',') + '}';
  return new Response(json, {
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
      'Cache-Control': 'public, max-age=0, must-revalidate',
      'Netlify-CDN-Cache-Control': 'public, s-maxage=1, stale-while-revalidate=5',
      'Netlify-Vary': 'query',
    },
  });
};

export const config = { path: '/api/lote' };

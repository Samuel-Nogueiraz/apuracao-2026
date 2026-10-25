# Apuração 2026 — Presidente (2º turno)

Mapa ao vivo da apuração, por estado e por região, com dados oficiais do TSE (arquivos EA20)
e limites dos estados da API de Malhas do IBGE.

```
public/index.html            página (mapa, painéis, atualização a cada 1 s)
public/malha-uf-ibge.json    malha das UFs (IBGE, qualidade mínima)
netlify/functions/lote.mjs   /api/lote na Netlify: busca os 29 arquivos do TSE com ETag
serve.ps1                    /api/lote no computador local (mesma resposta, sem Node)
netlify.toml                 configuração da Netlify
```

## Rodar no computador

```
powershell -ExecutionPolicy Bypass -File serve.ps1
```

Abra http://localhost:8026 (se a porta estiver ocupada, o script usa a próxima e mostra qual).

## Publicar na Netlify

A página depende da função `/api/lote`, porque o TSE não libera CORS. Por isso **não use o
"arrastar e soltar" (Netlify Drop)**, que publica só arquivos estáticos e não as funções.
Use um destes caminhos:

- **GitHub:** suba esta pasta para um repositório e, na Netlify, use *Add new project → Import
  an existing project*. As configurações de build vêm do `netlify.toml`; não precisa de comando de build.
- **Netlify CLI** (requer Node.js): `npx netlify-cli deploy --prod` dentro desta pasta.

Na Netlify, a resposta de `/api/lote` fica 1 s no cache da CDN, então todos os visitantes
compartilham uma única consulta ao TSE por segundo.

## Trocar eleição ou turno

Em `public/index.html`, no começo do `<script>`:

- `ELEICAO`: código da eleição (veja `https://resultados.tse.jus.br/oficial/comum/config/ele-c.json`);
- `ANO`: pasta do ano, por exemplo `ele2030`;
- `COR`: cor por número de urna (`'13'` vermelho, `'22'` azul).

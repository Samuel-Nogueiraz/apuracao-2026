# Apuração 2026 — Presidente (2º turno)

Site para acompanhar **ao vivo** a apuração do 2º turno da eleição presidencial de 2026 no Brasil
(Lula × Flávio Bolsonaro). Mostra um mapa por estado, por região e por município, com os números
tirados direto dos arquivos oficiais de resultado do TSE.

## Objetivo

Acompanhar a apuração de forma visual e rápida, e com confiança nos números:

- ver de relance **quem lidera em cada estado, região e município**, e por quanto;
- saber **quanto ainda falta apurar** e se o resultado já pode virar ou não;
- anunciar o vencedor **somente quando ele estiver matematicamente definido**, nunca antes;
- usar **apenas fontes oficiais** (TSE para os votos, IBGE para os mapas), sem estimativas nem dados inventados;
- fazer isso **sem sobrecarregar os servidores do TSE**, mesmo com muitas pessoas acessando ao mesmo tempo.

## O que o site faz

- **Mapa colorido:** vermelho onde o Lula lidera, azul onde o Flávio lidera. Quanto mais forte
  a cor, maior a margem. Os números sobre o mapa mostram o % de seções totalizadas.
- **Três tipos de mapa:** por estado, por região (divisão do IBGE) e por município (escolha o estado).
- **Busca de município:** encontra qualquer cidade do país, sem precisar de acento.
- **Painel de detalhes** para Brasil, região, estado, exterior ou município: votos e % de cada candidato,
  a diferença entre o 1º e o 2º, votos válidos, brancos, nulos, comparecimento, abstenção e seções totalizadas.
- **Ao vivo:** Brasil, regiões e estados são consultados a cada 1 s; municípios, a cada 30 s.
  O topo mostra o horário em que o TSE gerou o arquivo e avisa enquanto a apuração é parcial.
- **Anúncio do eleito:** só quando o TSE marca o resultado como definido ou quando a conta garante
  a vitória (veja abaixo). Junto aparece uma comemoração em pixel art: um boneco do candidato
  pulando, com fundo na cor dele. É uma animação ilustrativa, não uma imagem real.
- **Funciona no celular**, sem rolagem lateral.

## Como os números são calculados

- **Regiões:** soma dos votos dos estados de cada região, dividida pela soma dos votos válidos.
  Não é a média dos percentuais estaduais.
- **Exterior:** os votos do exterior entram só no total do Brasil, nunca numa região.
- **Percentuais:** os de candidatos são sobre os votos válidos; brancos e nulos, sobre o total de votos;
  comparecimento e abstenção, sobre o eleitorado das seções já totalizadas (como o TSE faz).
- **Vencedor definido:** o anúncio só aparece se uma destas condições valer:
  1. o TSE marca o candidato com a situação "Eleito" ou marca o arquivo como definido (`md` = `s` ou `e`);
  2. a diferença entre o 1º e o 2º é **maior** que tudo o que ainda pode entrar, ou seja, o eleitorado das
     seções não totalizadas somado aos votos anulados sub judice. Nem que todos esses votos fossem para
     o 2º colocado ele viraria.

## Fontes dos dados

- **Votos:** arquivos JSON oficiais do TSE no padrão EA20, por abrangência (Brasil, exterior, UF e município) —
  [portal de resultados](https://resultados.tse.jus.br/),
  [informações técnicas](https://www.tse.jus.br/eleicoes/informacoes-tecnicas-sobre-a-divulgacao-de-resultados).
- **Mapas:** [API de Malhas Territoriais do IBGE](https://servicodados.ibge.gov.br/api/docs/malhas?versao=3).
  A malha dos estados fica salva no projeto; a dos municípios é carregada do IBGE quando o estado é aberto.
- **Lista de municípios:** `public/municipios-tse.json`, gerada a partir da configuração oficial do TSE
  (`config/mun-e006258-cm.json`). Liga o código de cada município no TSE ao código do IBGE.

## Como funciona por dentro

O TSE não permite que o navegador busque os arquivos direto (não envia cabeçalho CORS). Por isso há um
intermediário, `/api/lote`, que busca vários arquivos do TSE de uma vez e devolve tudo numa resposta só.

```
public/index.html            o site inteiro (mapa, painéis, busca, anúncio, comemoração)
public/malha-uf-ibge.json    malha dos estados (IBGE)
public/municipios-tse.json   códigos dos municípios TSE ↔ IBGE
netlify/functions/lote.mjs   /api/lote em produção (Netlify Function)
serve.ps1                    /api/lote e o site no computador local (PowerShell, sem instalar nada)
netlify.toml                 configuração da Netlify
```

Para respeitar os limites do TSE:

- os arquivos são pedidos com **ETag**, então o TSE só reenvia o que mudou;
- na Netlify, a resposta fica **1 s no cache da CDN**: todos os visitantes compartilham uma única consulta por segundo;
- se o TSE responder **429 (muitas requisições)**, as consultas são pausadas pelo tempo que ele pedir
  e o site continua mostrando os últimos dados.

## Rodar no computador

```
powershell -ExecutionPolicy Bypass -File serve.ps1
```

Abra http://localhost:8026. Se a porta estiver ocupada, o script usa a próxima e mostra qual no terminal.

Para ver a comemoração sem esperar o resultado, abra com `?comemorar=13` (Lula) ou `?comemorar=22`
(Flávio) no fim do endereço. A tela aparece marcada como "PRÉVIA · SIMULAÇÃO".

## Publicar na Netlify

Com o site ligado a este repositório na Netlify, **cada `git push` na `main` publica uma nova versão sozinho.**

Para ligar um site novo: *Add new project → Import an existing project → GitHub* e escolha
este repositório. As configurações já vêm do `netlify.toml`, e não há comando de build.
Não use o "arrastar e soltar" da Netlify: ele não publica a função `/api/lote`, e sem ela não aparecem dados.

## Usar em outra eleição ou turno

1. Em `public/index.html`, no começo do `<script>`, troque:
   - `ELEICAO`: código da eleição, que está em
     [`ele-c.json`](https://resultados.tse.jus.br/oficial/comum/config/ele-c.json)
     (2º turno de 2026 = `6258`; 1º turno = `6257`);
   - `ANO`: pasta do ano, por exemplo `ele2030`;
   - `COR`: cor de cada candidato pelo número de urna.
2. Gere de novo `public/municipios-tse.json` a partir de `config/mun-e<código>-cm.json` da nova eleição.
3. Os bonecos da comemoração estão em `SPRITE_CABECA` e `SPRITE_PALETA`, também no `index.html`.

## Limitações

- O próprio TSE guarda cada arquivo em cache por até ~55 s, então os números chegam com esse atraso,
  como no portal oficial.
- Os municípios atualizam a cada 30 s, porque um estado pode ter centenas de arquivos.
- O site não faz projeção nem calcula chance de vitória: mostra só o que o TSE publicou.

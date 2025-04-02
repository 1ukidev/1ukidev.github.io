---
date: "2025-01-20"
draft: false
title: '"Inspecionar elemento" salvando vidas'
tags: ["browser", "javascript"]
---

Hoje, enquanto tentava solicitar de maneira online um serviço da minha cidade, sem querer, acabei errando um dos dados que eram exigidos. O problema é que o site não permitia que eu corrigisse manualmente, devido ao fato de o campo `input` do HTML estar desabilitado. Isso impossibilitava a continuação de todo o processo, porque a validação sempre falhava.

Nesse caso, uma pessoa normal provavelmente seria obrigada a fazer uma reclamação para tentar resolver o problema, mas eu não poderia parar por aí.

Não satisfeito, abri as ferramentas de desenvolvimento do navegador e verifiquei o que o site fazia enquanto eu tentava solicitar o serviço. Reparei que todas as comunicações com a API eram feitas com uma simples solicitação XHR, onde os dados que eu preenchia eram copiados para o corpo da solicitação.

Logo, imaginei que poderia simplesmente remover o atributo `disabled` da tag `input`, corrigir a informação e tentar novamente.

Para minha surpresa, funcionou perfeitamente.

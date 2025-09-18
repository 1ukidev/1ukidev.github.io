---
date: "2025-08-27"
draft: false
title: 'Rinha de IA: quais estados do Brasil não possuem a letra "A"?'
tags: ["rinha", "ia", "estados"]
---

Uma pergunta que parece simples, mas que até pouco tempo atrás muitas IAs generativas penavam para responder corretamente. Como será que está hoje?

Resposta esperada: Sergipe.

| Modelo               | Modo           | Comentário                                                                     | Tempo                  | Acertou |
| -------------------- | -------------- | -----------------------------------------------------------------------------: | ---------------------: | :-----: |
| GPT-5                | sem raciocínio | Citou Sergipe e outros três estados que possuem a letra "A".                   | Rapidamente            |    ❌    |
| GPT-5                | com raciocínio | Não testado.                                                                   |                        |    ❓    |
| GPT-5 mini           | sem raciocínio | Resposta igual a do GPT-5.                                                     | Rapidamente            |    ❌    |
| GPT-5 mini           | com raciocínio | Pensou e respondeu corretamente.                                               | 13 segundos            |    ✅    |
| Gemini 2.5 Flash     | sem raciocínio | Respondeu que todos os estados possuem a letra "A".                            | Rapidamente            |    ❌    |
| Gemini 2.5 Pro       | com raciocínio | Pensou, pesquisou na internet e ainda errou, citando Sergipe e Espiríto Santo. | Rapidamente            |    ❌    |
| Claude Sonnet 4      | sem raciocínio | Citou três estados com a letra "A". Nem Sergipe apareceu dessa vez.            | Rapidamente            |    ❌    |
| Claude Sonnet 4      | com raciocínio | Pensou e respondeu corretamente.                                               | 18 segundos            |    ✅    |
| Qwen3-235B-A22B-2507 | sem raciocínio | Respondeu que todos os estados possuem a letra "A".                            | Rapidamente            |    ❌    |
| Qwen3-235B-A22B-2507 | com raciocínio | Delirou um pouco no início, mas conseguiu chegar na resposta correta.          | 45 segundos            |    ✅    |
| DeepSeek-V3.1        | sem raciocínio | Respondeu Sergipe e Espiríto Santo.                                            | Rapidamente            |    ❌    |
| DeepSeek-V3.1        | com raciocínio | Pensou e respondeu corretamente.                                               | 1 minuto e 10 segundos |    ✅    |

Vencedor: GPT-5 mini com raciocínio.

Conclusão: é interessante como apenas os modelos com raciocínio (com exceção do Gemini 2.5 Pro) conseguiram chegar na resposta correta. A geração convencional que tenta prever a resposta correta continua a falhar feio nessa pergunta.

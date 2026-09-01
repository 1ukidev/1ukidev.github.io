---
date: "2026-09-01"
draft: false
title: "Um radar de aviões no Kindle"
tags: ["kindle", "koreader", "lua"]
---

Seguindo a tendência do `r/esp32`, criei o [Plane Radar](https://github.com/1ukidev/koreader-planeradar), um plugin em Lua que transforma o Kindle com KOReader em um pequeno radar de aviões.

![](/images/planeradar.png)
![](/images/planeradar_details.png)

O plugin consulta os dados públicos do [adsb.fi](https://adsb.fi/) e mostra as aeronaves próximas em um radar monocromático. Quando as informações estão disponíveis, também aparecem o indicativo do voo, o modelo do avião, a altitude e a direção em que ele está seguindo.

O código e as instruções de instalação estão disponíveis no [GitHub](https://github.com/1ukidev/koreader-planeradar). Os dados do adsb.fi são destinados a uso pessoal e não comercial.

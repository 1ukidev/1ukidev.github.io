---
date: "2025-05-12"
draft: false
title: "mitmproxy, mas no Android"
tags: ["mitmproxy", "android"]
---

O mitmproxy sempre foi de grande ajuda quando eu precisava de um proxy HTTPS que permitisse eu monitorar a rede com mais liberdade. Na última semana, ao tentar monitorar um aplicativo no Android, descobri uma ferramenta de código-aberto um tanto interessante que possibilitou fazer todo o processo pelo dispositivo, e com bem pouca configuração, trata-se do [PCAPdroid](https://github.com/emanuele-f/PCAPdroid). Monitorar e descriptografar a rede com alguns cliques foi realmente satisfatório.

## Instalação
Ele pode ser instalado facilmente pela Play Store, F-Droid ou pelo APK em sua página do GitHub. Fica a sua escolha.

![img](./f-droid.png#small)

## Tela inicial
Aqui podemos escolher os aplicativos que serão monitorados e decidir se vamos dumpar o tráfico para algum local. Por padrão o aplicativo irá criar uma VPN para termos a conexão com o proxy, mas também é possível ativar nas configurações uma conexão transparente, nesse caso será necessário root.

![img](./inicio.png#small)

## Ativando o mitmproxy
Indo nas configurações, iremos encontrar uma opção para ativar a descriptografia do TLS, aqui o aplicativo guiará bem didaticamente o que deve ser feito. Instalaremos um addon com o mitmproxy e um certificado CA no sistema.

![img](./opcao.png#small)

## Mirando os alvos
No menu da esquerda, em "Decryption rules", conseguimos selecionar os aplicativos que terão o tráfego descriptografado, bem como usar outros critérios, como um host, IP ou até um país específico.

![img](./menu.png#small)

## Testando
Agora é só dá o clique no "Ready" e todas as conexões estabelecidas serão devidamente listadas na aba "Connections". Aqui estou utilizando como exemplo o F-Droid.

![img](./conexoes.png#small)

Aqueles com cadeado aberto e verde signfica que foram descriptografados com sucesso. Ao clicar em cima...

![img](./http.png#small)

Voilà! Temos as requisições na palma da mão.

## Considerações finais
Apesar de anteriormente termos instalado o certificado no Android, infelizmente nem todos os aplicativos permitirão que você os use junto ao mitmproxy, devido a SSL pinning. Mas, felizmente, existe uma ferramente chamada [apk-mitm](https://github.com/niklashigi/apk-mitm), que tenta corrigir os bloqueios diretamente nos arquivos do APK. Não é 100% garantido que irá funcionar, mas em alguns testes feitos por mim, tem funcionado bem. Depois de instalar a ferramenta, o processo se resume a:

```bash
$ apk-mitm arquivo.apk
```

Bem, não custa tentar, fica a dica.

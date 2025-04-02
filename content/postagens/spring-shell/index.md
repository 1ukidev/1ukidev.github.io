---
date: "2025-02-16"
draft: false
title: "Desenvolvendo uma aplicação CLI de um jeito diferente"
tags: ["cli", "spring"]
autonumber: true
---

Suponha que você precise desenvolver uma aplicação CLI, qual as primeiras ferramentas que vem em sua mente? Talvez você pense em shell script ou um Python da vida. Mas e no Spring? Isso, aquele framework Java. Fiquei intrigado ao descobrir que o projeto fornece um recurso apenas para a criação de shells e resolvi testar.

## Primeiros passos
A configuração inicial não possui muito segredo, podemos utilizar o bom e velho Spring Initializr para criar um projeto. Na lista de dependências, encontramos o Spring Shell, que será o principal objeto de interesse do artigo.

![img](./spring-initializr.png#full)

Depois de baixado, extraído e aberto, precisamos nos certificar de que o shell interativo está habilitado no `application.yml` ou `application.properties`:
```yaml
spring:
    shell:
        interactive:
            enabled: true
```

Também pode ser uma boa ideia desativar o banner e o log, pois eles não serão muito úteis:
```yaml
spring:
    main:
        banner-mode: off

logging:
    level:
        root: off
```

## Executando
Ao compilar com `gradlew build` e executar o `jar` gerado, entramos diretamente em um shell:

```
$ java -jar build/libs/shell-0.0.1.jar
shell:>
```

Temos até alguns comandos por padrão:

```
shell:>help
AVAILABLE COMMANDS

Built-In Commands
       help: Display help about available commands
       stacktrace: Display the full stacktrace of the last error.
       clear: Clear the shell screen.
       quit, exit: Exit the shell.
       history: Display or save the history of previously run commands
       version: Show version info
       script: Read and execute commands from a file.
```

## Adicionando comandos
Para adicionar comandos também é simples, a reflexão faz a mágica:
```java
package com.lukidev.shell;

import org.springframework.shell.standard.ShellComponent;
import org.springframework.shell.standard.ShellMethod;
import org.springframework.shell.standard.ShellOption;

@ShellComponent
public class Comandos {

    @ShellMethod("Retorna o quadrado de um número")
    public int quadrado(
        @ShellOption(value = "-x", help = "Alvo") int x
    ) {
        return x * x;
    }

}
```

Ao recompilar e testar o comando `quadrado`, ele funciona como o esperado:

```
shell:>quadrado 25
625
```

Também é gerado automaticamente uma opção de ajuda:

```
shell:>quadrado --help
NAME
       quadrado - Retorna o quadrado de um número

SYNOPSIS
       quadrado [-x int] --help 

OPTIONS
       -x int
       Alvo
       [Mandatory]

       --help or -h 
       help for quadrado
       [Optional]
```

## Finalizando
A partir daqui, basta utilizar a criatividade para aproveitar melhor a funcionalidade. É uma solução um tanto simples e funcional. Apesar de eu achar inadequada para programas mais simples, imagino que possa ser mais útil em conjunto com outras aplicações Spring Boot já existentes. De qualquer forma, fica a sugestão para quem não conhecia.

Código-fonte: https://github.com/1ukidev/shell

Referências:
- https://docs.spring.io/spring-shell/reference/getting-started.html

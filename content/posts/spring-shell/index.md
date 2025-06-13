---
date: "2025-02-16"
draft: false
title: "Developing a CLI application in a different way"
tags: ["cli", "spring"]
autonumber: true
---

Suppose you need to develop a CLI application, what are the first tools that come to mind? Perhaps you think of shell script or Python. But what about Spring? Yes, that Java framework. I was intrigued when I discovered that the project provides a resource specifically for creating shells, so I decided to test it.

## First steps
The initial setup doesn't have many secrets, we can use the good old Spring Initializr to create a project. In the dependencies list, we find Spring Shell, which will be the main object of interest in this article.

![img](./spring-initializr.png#full)

After downloading, extracting, and opening it, we need to make sure that the interactive shell is enabled in `application.yaml` or `application.properties`:
```yaml
spring:
  shell:
    interactive:
      enabled: true
```

It might also be a good idea to disable the banner and logging, as they won't be very useful:
```yaml
spring:
  main:
    banner-mode: off

logging:
  level:
    root: off
```

## Running
When compiling with `gradlew build` and executing the generated `jar`, we enter directly into a shell:

```
$ java -jar build/libs/shell-0.0.1.jar
shell:>
```

We even have some default commands:

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

## Adding commands
Adding commands is also simple, reflection does the magic:
```java
package com.lukidev.shell;

import org.springframework.shell.standard.ShellComponent;
import org.springframework.shell.standard.ShellMethod;
import org.springframework.shell.standard.ShellOption;

@ShellComponent
public class Commands {

    @ShellMethod("Returns the square of a number")
    public int square(
        @ShellOption(value = "-x", help = "Target") int x
    ) {
        return x * x;
    }

}
```

When recompiling and testing the `square` command, it works as expected:

```
shell:>square 25
625
```

A help option is also automatically generated:

```
shell:>square --help
NAME
       square - Returns the square of a number

SYNOPSIS
       square [-x int] --help 

OPTIONS
       -x int
       Target
       [Mandatory]

       --help or -h 
       help for square
       [Optional]
```

## Finishing
From here, you just need to use your creativity to better take advantage of the functionality. It's a rather simple and functional solution. Although I find it inadequate for simpler programs, I imagine it could be more useful in conjunction with other existing Spring Boot applications. In any case, it's a suggestion for those who didn't know about it.

Source code: https://github.com/1ukidev/shell

References:
- https://docs.spring.io/spring-shell/reference/getting-started.html

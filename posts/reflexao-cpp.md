---
date: "2026-07-17"
draft: false
title: "Reflexão no C++26"
toc: true
---

Com a chegada do C++26, as propostas sobre reflexão em tempo de compilação que vinham sendo discutidas a algum tempo (ex: [P2996](https://www.open-std.org/jtc1/sc22/wg21/docs/papers/2025/p2996r13.html), [P3096](https://www.open-std.org/jtc1/sc22/wg21/docs/papers/2025/p3096r12.pdf), [P3293](https://www.open-std.org/jtc1/sc22/wg21/docs/papers/2025/p3293r3.html), [P3394](https://www.open-std.org/jtc1/sc22/wg21/docs/papers/2025/p3394r4.html), [P3795](https://www.open-std.org/jtc1/sc22/wg21/docs/papers/2026/p3795r2.html)), finalmente estão se tornando realidade, criando uma nova forma de se programar na linguagem. Na data de escrita deste artigo apenas o [GCC 16](https://en.cppreference.com/cpp/compiler_support/26) tem implementado o suporte experimental. No Clang ainda segue como planejado. Vamos explorar alguns casos de uso dessa funcionalidade.

## Operadores novos
| Sintaxe | Nome | Significado |
| --- | --- | --- |
| `^^entidade` | Operador de reflexão | Converte uma entidade C++ em `std::meta::info`. |
| `[: reflexão :]` | Splice | Converte uma reflexão novamente em código ou entidade C++. |
| `obj.[: membro :]` | Splice de membro | Acessa o membro descrito pela reflexão. |
| `[: tipo :] variável` | Splice de tipo | Usa o tipo descrito pela reflexão. |
| `[: valor :]` | Splice de expressão | Produz o valor ou entidade refletida. |

## Obtendo o nome de um tipo
```c++
#include <meta>
#include <print>

struct Pessoa {
    int idade;
};

int main() {
    constexpr std::meta::info reflexao = ^^Pessoa;
    std::println("{}", std::meta::identifier_of(reflexao));
    return 0;
}
```

Saída:
```shell
Pessoa
```

## Percorrendo os campos de uma estrutura
```c++
#include <meta>
#include <print>

struct Pessoa {
    int idade;
    double altura;
    bool ativo;
};

int main() {
    constexpr auto contexto =
        std::meta::access_context::current();

    template for (
        constexpr auto membro :
        std::define_static_array(
            std::meta::nonstatic_data_members_of(^^Pessoa, contexto)
        )
    ) {
        std::println("{}", std::meta::identifier_of(membro));
    }

    return 0;
}
```

Saída:
```shell
idade
altura
ativo
```

## Mostrar o nome e o tipo de cada campo
```c++
#include <meta>
#include <print>

struct Produto {
    int codigo;
    double preco;
    bool disponivel;
};

int main() {
    constexpr auto contexto =
        std::meta::access_context::current();

    template for (
        constexpr auto membro :
        std::define_static_array(
            std::meta::nonstatic_data_members_of(^^Produto, contexto)
        )
    ) {
        constexpr auto tipo_do_membro =
            std::meta::type_of(membro);

        std::println(
            "{}: {}",
            std::meta::identifier_of(membro),
            std::meta::display_string_of(tipo_do_membro)
        );
    }

    return 0;
}
```

Saída:
```shell
codigo: int
preco: double
disponivel: bool
```

## Converter um enum para texto
```c++
#include <meta>
#include <print>
#include <string_view>
#include <type_traits>

enum class Cor {
    vermelho,
    verde,
    azul
};

template <typename E>
    requires std::is_enum_v<E>
constexpr std::string_view enum_para_texto(E valor) {
    template for (
        constexpr auto enumerador :
        std::define_static_array(std::meta::enumerators_of(^^E))
    ) {
        if (valor == [: enumerador :]) {
            return std::meta::identifier_of(enumerador);
        }
    }

    return "valor desconhecido";
}

int main() {
    std::println("{}", enum_para_texto(Cor::vermelho));
    std::println("{}", enum_para_texto(Cor::verde));
    std::println("{}", enum_para_texto(Cor::azul));
    return 0;
}
```

Saída:
```shell
vermelho
verde
azul
```

## Adicionando metadados tipados a elementos
```c++
#include <meta>
#include <print>

[[=42]]
int resposta;

consteval int valor_da_anotacao()
{
    auto anotacoes =
        std::meta::annotations_of(^^resposta);

    return std::meta::extract<int>(anotacoes[0]);
}

static_assert(valor_da_anotacao() == 42);

int main()
{
    constexpr int valor = valor_da_anotacao();
    std::println("Anotação: {}", valor);
    return 0;
}
```

Saída:
```shell
Anotação: 42
```

## Outros casos de uso
Além das demonstrações exibidas até agora, há uma variedade de outras possibilidades a se explorar. O Daniel Lemire fez uma ótima [publicação](https://lemire.me/blog/2025/06/22/c26-will-include-compile-time-reflection-why-should-you-care/) em seu blog demonstrando a importância da reflexão ao se trabalhar com JSON e SQL.

Referência: [cppreference](https://en.cppreference.com/cpp/meta/reflection)

---
date: "2025-06-10"
draft: false
title: "Os desafios de escrever uma API em C++"
tags: ["api", "c++"]
autonumber: true
toc: true
---

Nesses últimos meses eu fiquei de tirar um pouco do meu tempo para focar em um tipo de projeto não tão comum, uma API em C++, tanto para aprender mais sobre a linguagem e seus recursos mais modernos, quanto para ver o quão bom o resultado final ficaria. Assim surgiu o `efe` **(extremely fast ERP)**. Desenvolver uma do zero utilizando bibliotecas de mais baixo nível seria terrivelmente demorado, e eu não queria reinventar a roda, mas criar uma API com base no que há de melhor no ecossistema atualmente. Esse artigo é principalmente para quem tem mais conhecimento em C++ e tem curiosidade sobre frameworks web na linguagem, além de não representar completamente o nicho.

## Drogon
No mundo do C++, um framework tem chamado minha atenção e é dele que vou falar agora. Trata-se do [Drogon](https://github.com/drogonframework/drogon), um framework web construído com base no C++ moderno, e isso inclui funcionalidades que se beneficiam do C++17 e C++20. Abrindo o capô, temos o [TRANTOR](https://github.com/an-tao/trantor), uma biblioteca que fornece um [loop de eventos](https://pt.wikipedia.org/wiki/La%C3%A7o_de_eventos) multithread, com I/O não-bloqueante e de alta performance, para E/S de rede ([e sério, é bem rápido](https://www.techempower.com/benchmarks/#section=data-r21)).

Apesar de à primeira vista a curva de aprendizagem parecer um pouco hostil, eu prometo que não é tão ruim assim. Exemplo de um controlador simples:

```c++
// TestController.hpp

#pragma once

#include <drogon/HttpSimpleController.h>

using namespace drogon;

class TestController : public HttpSimpleController<TestController>
{
public:
    PATH_LIST_BEGIN
        PATH_ADD("/test", Get);
    PATH_LIST_END

    void asyncHandleHttpRequest(const HttpRequestPtr& req,
                                std::function<void (const HttpResponsePtr&)>&& callback) override;
};
```

```c++
// TestController.cpp

#include "TestController.hpp"

void TestController::asyncHandleHttpRequest(const HttpRequestPtr& req,
                                            std::function<void (const HttpResponsePtr&)>&& callback)
{
    auto resp = HttpResponse::newHttpResponse();
    resp->setBody("<p>Hello, World!</p>");
    callback(resp);
}
```

Tá bom, talvez seja um pouco verboso... bem, ninguém falou que ia ser fácil. Assim como outros frameworks, temos o conceito de controllers, que aqui são classes que irão cuidar da lógica por trás das rotas da API e, consequentemente, da resposta que o cliente vai receber.

Também temos total acesso ao banco de dados de forma síncrona, assíncrona e com corrotinas (C++20).

```c++
// Exemplo de uma função que busca um usuário pelo seu login.

// Síncrono (bloqueante)
std::optional<UsuarioEntity> findByLogin(const std::string& login)
{
    auto db = app().getFastDbClient();
    std::string sql = "SELECT * FROM usuario WHERE login = $1;";

    try {
        auto result = db->execSqlSync(sql, login);

        if (result.size() == 0)
            return std::nullopt;

        UsuarioEntity usuario;
        usuario.fromRowSet(result[0]);
        return usuario;
    } catch (const orm::DrogonDbException& e) {
        LOG_ERROR << e.base().what();
        return std::nullopt;
    }
}

// Assíncrono com std::future (bloqueante nesse contexto)
std::optional<UsuarioEntity> findByLogin(const std::string& login)
{
    auto db = app().getFastDbClient();
    std::string sql = "SELECT * FROM usuario WHERE login = $1;";
    auto result = db->execSqlAsyncFuture(sql, login);

    try {
        auto res = result.get();
        if (res.size() == 0)
            return std::nullopt;

        UsuarioEntity usuario;
        usuario.fromRowSet(res[0]);
        return usuario;
    } catch (const orm::DrogonDbException& e) {
        LOG_ERROR << e.base().what();
        return std::nullopt;
    }
}

// Assíncrono com corrotina (não-bloqueante)
Task<std::optional<UsuarioEntity>> findByLogin(const std::string& login)
{
    auto db = app().getFastDbClient();
    std::string sql = "SELECT * FROM usuario WHERE login = $1;";

    try {
        auto result = co_await db->execSqlCoro(sql, login);

        if (result.size() == 0)
            co_return std::nullopt;

        UsuarioEntity usuario;
        usuario.fromRowSet(result[0]);
        co_return usuario;
    } catch (const orm::DrogonDbException& e) {
        LOG_ERROR << e.base().what();
        co_return std::nullopt;
    }
}

```

Ao analisar esses códigos, é possível reparar em algo interessante: a versão com corrotina permite que a gente escrever a função de forma muito parecido ao jeito síncrono, mas aproveitando os benefícios do assíncrono. Sendo essa, a forma recomendada pelos próprios desenvolvedores do framework para projetos que podem utilizar o C++20.

Além do que foi dito anteriormente, ainda temos uma tentativa de ORM, sistema de templates, Redis, compressão e muitas outras coisas que podem ser aproveitadas no Drogon. Vale dar uma olhada no README do projeto.

## ORM
É sabido que o C++ não possui nada parecido com a conveniência da reflexão de linguagens como Java ou C# (apesar de a reflexão em tempo de compilação ser prevista no [C++26](https://isocpp.org/files/papers/P2996R4.html)). Isso dificulta a criação de ORMs mágicos, como a vista no Spring Boot, por exemplo. Ainda assim, é possível imitar usando alternativas que usam o que temos em mão.

O Drogon possui uma ferramenta CLI chamada `drogon_ctl` que consegue analisar uma tabela do banco de dados e transformá-la em uma classe pronta, com os campos e métodos que geralmente esperaríamos de algo do tipo. Apesar do truque ser bom, no fim acabei decidindo por não usar devido a complexidade das classes geradas. Eu precisava de algo mais simples e que fosse possível ter mais controle sobre o código. 

Por outro lado, eu perderia a capacidade de usar o `drogon::Mapper`, que me permitiria escrever consultas como:

```c++
Mapper<Usuarios> mp(db);
auto usuarios = mp.orderBy(Usuarios::Cols::_data_cadastro).limit(25).offset(0).findAll();
```

Nesse caso, a ideia foi criar uma classe que todas as outras entidades da API terão que herdar, iremos chamar de `Entity`. O objetivo é que todas as entidades tenham métodos que são indispensáveis para a sua natureza.

```c++
// Entity.hpp

#include "JSON.hpp"

#include <cstdint>
#include <drogon/orm/Row.h>
#include <json/value.h>
#include <string>
#include <unordered_map>

class Entity
{
public:
    virtual ~Entity() = default;

    // Retorna o nome da classe.
    virtual std::string getClassName() const = 0;

    // Retorna o nome da tabela no banco de dados.
    virtual std::string getTable() const = 0;

    // Retorna um mapa com os nomes das colunas e seus respectivos valores.
    virtual const std::unordered_map<std::string, std::string>& getColumns() const = 0;

    // Preenche a entidade com os valores do resultado de uma consulta.
    virtual void fromRowSet(const drogon::orm::Row& row) = 0;

    // Carrega as relações da entidade.
    virtual void loadRelations() {};

    // Retorna uma representação em string da entidade.
    virtual std::string toString() const = 0;

    // Retorna uma representação em JSON da entidade.
    virtual JSON toJSON() const = 0;

    std::int64_t id{};
};
```

Usando mais uma vez o usuário como exemplo, uma implementação simples se tornaria em algo como:

```c++
// UsuarioEntity.hpp

#include "Entity.hpp"
#include "JSON.hpp"

#include <drogon/orm/Row.h>
#include <string>
#include <unordered_map>

class UsuarioEntity final : public Entity
{
public:
    UsuarioEntity() = default;
    ~UsuarioEntity() = default;

    UsuarioEntity(const std::string& nome, const std::string& login, const std::string& senha)
        : nome(nome), login(login), senha(senha) {}

    std::string getClassName() const override { return "UsuarioEntity"; }
    std::string getTable() const override { return "usuario"; }

    const std::unordered_map<std::string, std::string>& getColumns() const override;
    void fromRowSet(const drogon::orm::Row& result) override;

    std::string toString() const override;
    JSON toJSON() const override;

    std::string nome;
    std::string login;
    std::string senha;

private:
    mutable std::unordered_map<std::string, std::string> columnsCache;
};
```

```c++
// UsuarioEntity.cpp

#include "UsuarioEntity.hpp"
#include "JSON.hpp"

#include <cstdint>
#include <drogon/orm/Field.h>
#include <drogon/orm/Row.h>
#include <string>
#include <unordered_map>

const std::unordered_map<std::string, std::string>& UsuarioEntity::getColumns() const
{
    columnsCache = {
        {"nome", nome},
        {"login", login},
        {"senha", senha}
    };
    return columnsCache;
}

void UsuarioEntity::fromRowSet(const drogon::orm::Row& row)
{
    if (row.size() > 0) {
        if (!row["id"].isNull())
            id = row["id"].as<std::int64_t>();

        if (!row["nome"].isNull())
            nome = row["nome"].as<std::string>();

        if (!row["login"].isNull())
            login = row["login"].as<std::string>();

        if (!row["senha"].isNull())
            senha = row["senha"].as<std::string>();
    }
}

std::string UsuarioEntity::toString() const
{
    return "UsuarioEntity[id=" + std::to_string(id) +
           ", nome=" + nome +
           ", login=" + login + ']';
}

JSON UsuarioEntity::toJSON() const
{
    JSON json;
    json["id"] = id;
    json["nome"] = nome;
    json["login"] = login;
    return json;
}
```

Com essa abstração pronta, agora temos uma base para tentar arranjar uma forma de realizar as operações no banco de dados. Podemos muito bem criar uma classe genérica chamada `DAO` com as funções mais essenciais de uma entidade, como `save`, `update`, `findById`...

```c++
// DAO.hpp

#pragma once

#include "Entity.hpp"

#include <cstdint>
#include <drogon/HttpAppFramework.h>
#include <drogon/orm/DbClient.h>
#include <drogon/orm/Exception.h>
#include <drogon/utils/coroutine.h>
#include <optional>
#include <string>
#include <trantor/utils/Logger.h>
#include <type_traits>
#include <utility>
#include <vector>

/* Podemos usar os concepts do C++20 para garantir
   que apenas nossas entidades possam herdar dessa classe. */
template <class T>
concept IsEntity = std::is_base_of_v<Entity, T>;

template <IsEntity T>
class DAO
{
public:
    virtual ~DAO() = default;

    /* Nessa API vamos dar ênfase nas funções que utilizam corrotinas.
       Também sinalizei utilizando o sufixo "Coro". */

    virtual drogon::Task<bool> saveCoro(T& entity)
    {
        const auto [sql, values] = buildInsertQuery(entity);

        try {
            auto result = co_await getDb()->execSqlCoro(sql, values);

            entity.id = result[0]["id"].template as<std::int64_t>();

            co_return true;
        } catch (const drogon::orm::DrogonDbException& e) {
            LOG_ERROR << e.base().what();
            co_return false;
        }
    }

    virtual drogon::Task<bool> updateCoro(T& entity)
    {
        const auto [sql, values] = buildUpdateQuery(entity);

        try {
            auto result = co_await getDb()->execSqlCoro(sql, values);

            if (result.affectedRows() == 0)
                co_return false;

            co_return true;
        } catch (const drogon::orm::DrogonDbException& e) {
            LOG_ERROR << e.base().what();
            co_return false;
        }
    }

    virtual drogon::Task<std::optional<T>> findByIdCoro(std::int64_t id)
    {
        T entity;
        std::string sql = "SELECT * FROM " + entity.getTable() + " WHERE id = $1;";

        try {
            auto result = co_await getDb()->execSqlCoro(sql, id);

            if (result.size() == 0)
                co_return std::nullopt;

            entity.fromRowSet(result[0]);
            co_return entity;
        } catch (const drogon::orm::DrogonDbException& e) {
            LOG_ERROR << e.base().what();
            co_return std::nullopt;
        }
    }

    // Outros métodos...

protected:
    inline drogon::orm::DbClientPtr getDb()
    {
        return drogon::app().getFastDbClient();
    }
}
```

Como podemos reparar, as queries de `saveCoro` e `updateCoro` estão sendo montadas, respectivamente, através dos métodos `buildInsertQuery` e `buildUpdateQuery`. Vamos dar uma olhada neles:

```c++
/* Aqui utilizei uma lógica bem simples, podemos aproveitar
   o método "getColumns" da entidade para criar automaticamente
   a query com as colunas e parâmetros já inseridos. Em ambos
   os métodos retornamos a query e os valores que estão na entidade. */

std::pair<std::string, std::vector<std::string>> buildInsertQuery(const T& entity)
{
    const auto& columns = entity.getColumns();

    std::string sql = "INSERT INTO " + entity.getTable() + " (";

    bool first = true;
    for (const auto& [column, _] : columns) {
        if (!first) sql += ", ";
        sql += column;
        first = false;
    }

    sql += ") VALUES (";
    first = true;
    for (size_t i = 0; i < columns.size(); ++i) {
        if (!first) sql += ", ";
        sql += '$' + std::to_string(i + 1);
        first = false;
    }

    std::vector<std::string> values;
    for (const auto& [_, value] : columns)
        values.push_back(value);

    sql += ") RETURNING id;";
    return {sql, values};
}

// O update segue com uma lógica semelhante...

std::pair<std::string, std::vector<std::string>> buildUpdateQuery(const T& entity)
{
    const auto& columns = entity.getColumns();

    std::string sql = "UPDATE " + entity.getTable() + " SET ";

    std::vector<std::string> values;
    size_t index = 1;
    for (const auto& [column, value] : columns) {
        if (index > 1) sql += ", ";
        sql += column + " = $" + std::to_string(index++);
        values.push_back(value);
    }

    sql += " WHERE id = $" + std::to_string(index);
    values.push_back(std::to_string(entity.id));

    return {sql, values};
}
```

Pronto, agora vamos tentar implementar essa classe.

```c++
#pragma once

#include "DAO.hpp"
#include "UsuarioEntity.hpp"

#include <drogon/plugins/Plugin.h>
#include <json/value.h>

class UsuarioDAO final : public DAO<UsuarioEntity>, public drogon::Plugin<UsuarioDAO>
{
public:
    UsuarioDAO() = default;
    ~UsuarioDAO() = default;

    virtual void initAndStart(const Json::Value&) override {};
    virtual void shutdown() override {};
};
```

Herdar de `drogon::Plugin<T>` vai fazer com que a classe seja inicializada de forma similar a um singleton, ao iniciar o programa, e assim nos possibilita pegar uma instância em qualquer parte dos controladores usando:

```c++
auto* dao = app().getPlugin<UsuarioDAO>();
```

Para além do construtor e destrutor, podemos customizar a inicialização e o desligamento da classe nos métodos `initAndStart` e `shutdown`.

## JSON

Nos códigos anteriores, talvez você tenha reparado na classe `JSON`, mas o que ela é? Ela é uma forma de criar uma classe de uso geral para tudo que envolve o JSON. Sua implementação pode ser algo tão simples quanto:

```c++
// JSON.hpp

#pragma once

#include <json/value.h>
#include <string>

enum class jt
{
    success = 0,
    error = 1
};

class JSON final
{
public:
    JSON() = default;
    ~JSON() = default;

    Json::Value& operator[](const std::string& key) {
        return value[key];
    }

    const Json::Value& operator[](const std::string& key) const {
        return value[key];
    }

    // Retorna uma representação em string do JSON.
    std::string toString() const;

    // Cria uma resposta JSON.
    static std::string createResponse(const std::string& msg,
                                      const jt type = jt::success);

private:
    // Aqui é onde os valores do JSON serão armazenados de fato.
    Json::Value value{Json::objectValue};
};
```

```c++
// JSON.cpp

#include "JSON.hpp"

#include <json/writer.h>
#include <string>

std::string JSON::toString() const
{
    Json::StreamWriterBuilder builder;
    return Json::writeString(builder, value);
}

std::string JSON::createResponse(const std::string& msg, const jt type)
{
    switch (type) {
        case jt::success:
            return "{\"success\":true,\"message\":\"" + msg + "\"}\n";
        case jt::error:
            return "{\"success\":false,\"message\":\"" + msg + "\"}\n";
        default:
            return "{\"success\":false,\"message\":\"Tipo de resposta inválido\"}\n";
    }
}
```

O método `createResponse` irá principalmente ajudar a criar respostas de sucesso e erro para os controladores da API.

## Controllers
Agora que finalmente temos toda essa base escrita, conseguimos começar a brincar de verdade com as rotas. Para isso, bora criar um controlador com corrotinas para o nosso usuário:

```c++
// UsuarioController.hpp

#pragma once

#include <drogon/HttpController.h>
#include <drogon/HttpResponse.h>
#include <drogon/HttpRequest.h>
#include <drogon/HttpTypes.h>
#include <drogon/utils/coroutine.h>

namespace efe::controllers
{
    using namespace drogon;

    class UsuarioController final : public HttpController<UsuarioController>
    {
    public:
        using Callback = std::function<void(const HttpResponsePtr&)>;

        METHOD_LIST_BEGIN
            METHOD_ADD(UsuarioController::saveUser, "", Post);
        METHOD_LIST_END

        Task<> saveUser(const HttpRequestPtr req, Callback callback);
    };
}
```

```c++
// UsuarioController.cpp

#include "JSON.hpp"
#include "UsuarioController.hpp"
#include "UsuarioDAO.hpp"
#include "UsuarioEntity.hpp"

#include <drogon/HttpRequest.h>
#include <drogon/HttpResponse.h>
#include <drogon/HttpTypes.h>
#include <drogon/utils/coroutine.h>
#include <string>

namespace efe::controllers
{
    Task<> UsuarioController::saveUser(const HttpRequestPtr req, Callback callback)
    {
        auto* dao = app().getPlugin<UsuarioDAO>();

        auto resp = HttpResponse::newHttpResponse();
        resp->setContentTypeCode(CT_APPLICATION_JSON);

        auto json = req->getJsonObject();
        auto nome = json->get("nome", "").asString();
        auto login = json->get("login", "").asString();
        auto senha = json->get("senha", "").asString();

        std::string faltando;
        if (nome.empty()) faltando += "nome, ";
        if (login.empty()) faltando += "login, ";
        if (senha.empty()) faltando += "senha, ";

        if (!faltando.empty()) {
            faltando = faltando.substr(0, faltando.size() - 2);
            std::string msg = "Campo(s) obrigatórios ausentes: " + faltando;
            resp->setStatusCode(k400BadRequest);
            resp->setBody(JSON::createResponse(msg, jt::error));
            callback(resp);
            co_return;
        }

        UsuarioEntity entity(nome, login, senha);
        bool ok = co_await dao->saveCoro(entity);

        resp->setStatusCode(ok ? k201Created : k500InternalServerError);
        resp->setBody(JSON::createResponse(
            ok ? "Salvo com sucesso" : "Erro interno ao salvar usuário",
            ok ? jt::success : jt::error
        ));
        callback(resp);
        co_return;
    }
}
```

Testando:

```bash
$ curl -X POST http://localhost:9999/efe/controllers/UsuarioController \
    -H "Content-Type: application/json" \
    -d '{"login": "admin", "nome": "Admin", "senha": "123456"}'

Salvo com sucesso

# É interessante notar que a rota acima é um tanto grande, isso se deve
# ao drogon::HttpController que estamos utilizando. Por padrão, todos os
# métodos que adicionamos neste tipo de controller seguirá esse padrão,
# de seguir o namespace e o nome da classe.
```

## Considerações finais
Infelizmente, programar a API dessa forma vai ter como efeito colateral muito código boilerplate e pode ficar constantemente vulnerável a bugs e falhas de segurança, o que pode se tornar um grande risco para projetos grandes. É interessante que você faça as coisas desse jeito somente se você realmente souber o que está fazendo e precisa de desempenho ao máximo. E ainda assim, é provável que não seja a melhor escolha, já que frameworks como o ASP.NET Core fornecem um bom nível de produtividade com um nível de desempenho consideravelmente alto.

Código-fonte: https://github.com/1ukidev/efe

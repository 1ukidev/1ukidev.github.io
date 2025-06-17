---
date: "2025-06-10"
draft: false
title: "The challenges of writing an API in C++"
tags: ["api", "c++"]
autonumber: true
toc: true
---

In recent months, I decided to take some time to focus on an uncommon type of project: an API in C++. This was both to learn more about the language and its more modern features, and to see how good the final result would be. That's how `efe` **(extremely fast ERP)** came to be. Developing one from scratch using lower-level libraries would be terribly time-consuming, and I didn't want to reinvent the wheel, but rather create an API based on the best the ecosystem currently has to offer. This article is primarily for those with more knowledge in C++ who are curious about web frameworks in the language, and doesn't completely represent the niche.

## Drogon
In the C++ world, one framework has caught my attention, and that's what I'm going to talk about now. It's [Drogon](https://github.com/drogonframework/drogon), a web framework built on modern C++, including features that benefit from C++17 and C++20. Under the hood, we have [TRANTOR](https://github.com/an-tao/trantor), a library that provides a multi-threaded [event loop](https://en.wikipedia.org/wiki/Event_loop) with non-blocking, high-performance I/O for network operations ([and seriously, it's quite fast](https://www.techempower.com/benchmarks/#section=data-r21)).

Although at first glance the learning curve might seem a bit hostile, I promise it's not that bad. Example of a simple controller:

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

Okay, maybe it's a bit verbose... well, nobody said it was going to be easy. Like other frameworks, we have the concept of controllers, which here are classes that will handle the logic behind the API routes and, consequently, the response the client will receive.

We also have full access to the database in synchronous, asynchronous, and coroutine (C++20) forms.

```c++
// Example of a function that searches for a user by their login.

// Synchronous (blocking)
std::optional<UserEntity> findByLogin(const std::string& login)
{
    auto db = app().getFastDbClient();
    std::string sql = "SELECT * FROM user WHERE login = $1;";

    try {
        auto result = db->execSqlSync(sql, login);

        if (result.size() == 0)
            return std::nullopt;

        UserEntity user;
        user.fromRowSet(result[0]);
        return user;
    } catch (const orm::DrogonDbException& e) {
        LOG_ERROR << e.base().what();
        return std::nullopt;
    }
}

// Asynchronous with std::future (blocking in this context)
std::optional<UserEntity> findByLogin(const std::string& login)
{
    auto db = app().getFastDbClient();
    std::string sql = "SELECT * FROM user WHERE login = $1;";
    auto result = db->execSqlAsyncFuture(sql, login);

    try {
        auto res = result.get();
        if (res.size() == 0)
            return std::nullopt;

        UserEntity user;
        user.fromRowSet(res[0]);
        return user;
    } catch (const orm::DrogonDbException& e) {
        LOG_ERROR << e.base().what();
        return std::nullopt;
    }
}

// Asynchronous with coroutines (non-blocking)
Task<std::optional<UserEntity>> findByLogin(const std::string& login)
{
    auto db = app().getFastDbClient();
    std::string sql = "SELECT * FROM user WHERE login = $1;";

    try {
        auto result = co_await db->execSqlCoro(sql, login);

        if (result.size() == 0)
            co_return std::nullopt;

        UserEntity user;
        user.fromRowSet(result[0]);
        co_return user;
    } catch (const orm::DrogonDbException& e) {
        LOG_ERROR << e.base().what();
        co_return std::nullopt;
    }
}

```

When analyzing these codes, it's possible to notice something interesting: the coroutine version allows us to write the function very similarly to the synchronous way, but taking advantage of the benefits of asynchronous programming. This is the recommended approach by the framework developers themselves for projects that can use C++20.

Beyond what was mentioned earlier, we still have an ORM attempt, template system, Redis, compression, and many other things that can be leveraged in Drogon. It's worth taking a look at the project's README.

## ORM
It's known that C++ doesn't have anything like the convenience of reflection found in languages like Java or C# (although compile-time reflection is planned for [C++26](https://isocpp.org/files/papers/P2996R4.html)). This makes it difficult to create magical ORMs, like those seen in Spring Boot, for example. Still, it's possible to mimic using alternatives that use what we have at hand.

Drogon has a CLI tool called `drogon_ctl` that can analyze a database table and transform it into a ready-made class, with the fields and methods we would generally expect from something of this type. Although the trick is good, in the end I decided not to use it due to the complexity of the generated classes. I needed something simpler that would allow more control over the code.

On the other hand, I would lose the ability to use `drogon::Mapper`, which would allow me to write queries like:

```c++
Mapper<Users> mp(db);
auto users = mp.orderBy(Users::Cols::_registration_date).limit(25).offset(0).findAll();
```

In this case, the idea was to create a class that all other API entities would have to inherit from, which we'll call `Entity`. The goal is for all entities to have methods that are indispensable to their nature.

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

    // Returns the class name.
    virtual std::string getClassName() const = 0;

    // Returns the table name in the database.
    virtual std::string getTable() const = 0;

    // Returns a map with column names and their respective values.
    virtual const std::unordered_map<std::string, std::string>& getColumns() const = 0;

    // Fills the entity with values from a query result.
    virtual void fromRowSet(const drogon::orm::Row& row) = 0;

    // Loads the entity's relations.
    virtual void loadRelations() {};

    // Returns a string representation of the entity.
    virtual std::string toString() const = 0;

    // Returns a JSON representation of the entity.
    virtual JSON toJSON() const = 0;

    std::int64_t id{};
};
```

Using the user as an example again, a simple implementation would become something like:

```c++
// UserEntity.hpp

#include "Entity.hpp"
#include "JSON.hpp"

#include <drogon/orm/Row.h>
#include <string>
#include <unordered_map>

class UserEntity final : public Entity
{
public:
    UserEntity() = default;
    ~UserEntity() = default;

    UserEntity(const std::string& name, const std::string& login, const std::string& password)
        : name(name), login(login), password(password) {}

    std::string getClassName() const override { return "UserEntity"; }
    std::string getTable() const override { return "user"; }

    const std::unordered_map<std::string, std::string>& getColumns() const override;
    void fromRowSet(const drogon::orm::Row& result) override;

    std::string toString() const override;
    JSON toJSON() const override;

    std::string name;
    std::string login;
    std::string password;

private:
    mutable std::unordered_map<std::string, std::string> columnsCache;
};
```

```c++
// UserEntity.cpp

#include "UserEntity.hpp"
#include "JSON.hpp"

#include <cstdint>
#include <drogon/orm/Field.h>
#include <drogon/orm/Row.h>
#include <string>
#include <unordered_map>

const std::unordered_map<std::string, std::string>& UserEntity::getColumns() const
{
    columnsCache = {
        {"name", name},
        {"login", login},
        {"password", password}
    };
    return columnsCache;
}

void UserEntity::fromRowSet(const drogon::orm::Row& row)
{
    if (row.size() > 0) {
        if (!row["id"].isNull())
            id = row["id"].as<std::int64_t>();

        if (!row["name"].isNull())
            name = row["name"].as<std::string>();

        if (!row["login"].isNull())
            login = row["login"].as<std::string>();

        if (!row["password"].isNull())
            password = row["password"].as<std::string>();
    }
}

std::string UserEntity::toString() const
{
    return "UserEntity[id=" + std::to_string(id) +
           ", name=" + name +
           ", login=" + login + ']';
}

JSON UserEntity::toJSON() const
{
    JSON json;
    json["id"] = id;
    json["name"] = name;
    json["login"] = login;
    return json;
}
```

With this abstraction ready, we now have a base to try to arrange a way to perform database operations. We can very well create a generic class called `DAO` with the most essential functions of an entity, like `save`, `update`, `findById`...

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

/* We can use C++20 concepts to ensure
   that only our entities can inherit from this class. */
template <class T>
concept IsEntity = std::is_base_of_v<Entity, T>;

template <IsEntity T>
class DAO
{
public:
    virtual ~DAO() = default;

    /* In this API we'll emphasize functions that use coroutines.
       I also signaled this using the "Coro" suffix. */

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

    // Other methods...

protected:
    inline drogon::orm::DbClientPtr getDb()
    {
        return drogon::app().getFastDbClient();
    }
}
```

As we can see, the queries for `saveCoro` and `updateCoro` are being built through the `buildInsertQuery` and `buildUpdateQuery` methods, respectively. Let's take a look at them:

```c++
/* Here I used very simple logic, we can leverage
   the entity's "getColumns" method to automatically create
   the query with columns and parameters already inserted. In both
   methods we return the query and the values that are in the entity. */

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

// The update follows similar logic...

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

Done, now let's try to implement this class.

```c++
#pragma once

#include "DAO.hpp"
#include "UserEntity.hpp"

#include <drogon/plugins/Plugin.h>
#include <json/value.h>

class UserDAO final : public DAO<UserEntity>, public drogon::Plugin<UserDAO>
{
public:
    UserDAO() = default;
    ~UserDAO() = default;

    virtual void initAndStart(const Json::Value&) override {};
    virtual void shutdown() override {};
};
```

Inheriting from `drogon::Plugin<T>` will make the class initialize similarly to a singleton when starting the program, and thus enables us to get an instance anywhere in the controllers using:

```c++
auto* dao = app().getPlugin<UserDAO>();
```

Beyond the constructor and destructor, we can customize the initialization and shutdown of the class in the `initAndStart` and `shutdown` methods.

## JSON

In the previous codes, you might have noticed the `JSON` class, but what is it? It's a way to create a general-purpose class for everything involving JSON. Its implementation can be something as simple as:

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

    // Returns a string representation of the JSON.
    std::string toString() const;

    // Creates a JSON response.
    static std::string createResponse(const std::string& msg,
                                      const jt type = jt::success);

private:
    // This is where the JSON values will actually be stored.
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
            return "{\"success\":false,\"message\":\"Invalid response type\"}\n";
    }
}
```

The `createResponse` method will mainly help create success and error responses for the API controllers.

## Controllers
Now that we finally have all this base written, we can start playing around with routes for real. For this, let's create a controller with coroutines for our user:

```c++
// UserController.hpp

#pragma once

#include <drogon/HttpController.h>
#include <drogon/HttpResponse.h>
#include <drogon/HttpRequest.h>
#include <drogon/HttpTypes.h>
#include <drogon/utils/coroutine.h>

namespace efe::controllers
{
    using namespace drogon;

    class UserController final : public HttpController<UserController>
    {
    public:
        using Callback = std::function<void(const HttpResponsePtr&)>;

        METHOD_LIST_BEGIN
            METHOD_ADD(UserController::saveUser, "", Post);
        METHOD_LIST_END

        Task<> saveUser(const HttpRequestPtr req, Callback callback);
    };
}
```

```c++
// UserController.cpp

#include "JSON.hpp"
#include "UserController.hpp"
#include "UserDAO.hpp"
#include "UserEntity.hpp"

#include <drogon/HttpRequest.h>
#include <drogon/HttpResponse.h>
#include <drogon/HttpTypes.h>
#include <drogon/utils/coroutine.h>
#include <string>

namespace efe::controllers
{
    Task<> UserController::saveUser(const HttpRequestPtr req, Callback callback)
    {
        auto* dao = app().getPlugin<UserDAO>();

        auto resp = HttpResponse::newHttpResponse();
        resp->setContentTypeCode(CT_APPLICATION_JSON);

        auto json = req->getJsonObject();
        auto name = json->get("name", "").asString();
        auto login = json->get("login", "").asString();
        auto password = json->get("password", "").asString();

        std::string missing;
        if (name.empty()) missing += "name, ";
        if (login.empty()) missing += "login, ";
        if (password.empty()) missing += "password, ";

        if (!missing.empty()) {
            missing = missing.substr(0, missing.size() - 2);
            std::string msg = "Required field(s) missing: " + missing;
            resp->setStatusCode(k400BadRequest);
            resp->setBody(JSON::createResponse(msg, jt::error));
            callback(resp);
            co_return;
        }

        UserEntity entity(name, login, password);
        bool ok = co_await dao->saveCoro(entity);

        resp->setStatusCode(ok ? k201Created : k500InternalServerError);
        resp->setBody(JSON::createResponse(
            ok ? "Saved successfully" : "Internal error saving user",
            ok ? jt::success : jt::error
        ));
        callback(resp);
        co_return;
    }
}
```

Testing:

```bash
$ curl -X POST http://localhost:9999/efe/controllers/UserController \
    -H "Content-Type: application/json" \
    -d '{"login": "admin", "name": "Admin", "password": "123456"}'

Saved successfully

# It's interesting to note that the route above is quite long, this is due
# to the drogon::HttpController we're using. By default, all methods
# we add to this type of controller will follow this pattern,
# following the namespace and class name.
```

## Final considerations
Unfortunately, programming the API this way will have as a side effect a lot of boilerplate code and can become constantly vulnerable to bugs and security flaws, which can become a major risk for large projects. It's interesting that you do things this way only if you really know what you're doing and need maximum performance. And even then, it's probably not the best choice, since frameworks like ASP.NET Core provide a good level of productivity with a considerably high level of performance.

Source code: https://github.com/1ukidev/efe

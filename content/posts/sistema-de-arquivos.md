---
date: "2025-01-18"
draft: false
title: "Criando um sistema de arquivos simples no Linux"
tags: ["linux", "fuse"]
---

Historicamente, em sistemas operacionais, os sistemas de arquivos sempre andaram junto ao kernel. No Linux, por exemplo, diferentes módulos foram criados para conseguir reconhecer e tratar os mais variados tipos deles. Observando dessa forma, logo imaginaríamos que desenvolver um filesystem do zero seria um processo lento e complicado, exigindo profundos conhecimentos do kernel e de estruturas de dados complexas.

Mas, será mesmo? Com essa dúvida, decidi me adentrar no assunto e tentei criar, da forma mais simples que consegui, o meu próprio sistema de arquivos (spoiler: deu certo, quer dizer, mais ou menos).

Antes de tudo, é interessante entender como, geralmente, nossos arquivos e pastas são tratados no alto nível da coisa. Assim que entramos em um gerenciador de arquivos há um nível interessante de abstração por baixo dos panos.

Cada sistema de arquivos tem suas peculiaridades na hora de tratar os dados. Alguns usam uma tabela de alocação (FAT), outros, uma árvore B (Btrfs). Concordamos que seria doloroso tentar tratar cada um desses individualmente e, por isso, foi criado o VFS, uma camada que todo filesystem precisa respeitar.

Ao realizar a seguinte chamada de sistema no Linux:
```c
int fd = open("arquivo.txt", O_RDONLY);
```
O VFS do kernel está basicamente cuidando de chamar o equivalente ao `open()` no sistema de arquivos subjacente.

Alguns outros exemplos de chamadas padronizadas pelo VFS: `open()`, `read()`, `write()`, `mkdir()`.

Com isso em mente, deduzi que, para continuar com a minha ideia, eu apenas precisava implementar essas mesmas chamadas a meu gosto, correto? E é bem por aí mesmo.

Neste ponto, eu poderia seguir entre dois caminhos diferentes: implementar a nível de kernel como um módulo (mais difícil) ou implementar a nível de usuário usando o FUSE (mais fácil). Por ora, o FUSE se mostrou um ótimo começo.

O [FUSE](https://github.com/libfuse/libfuse) é uma interface que possibilita implementarmos qualquer sistema de arquivos no userspace. Isso significa: sem a necessidade de usarmos root ou de instalar módulos ao kernel. De início, tudo que é necessário é termos o próprio FUSE instalado. Definitivamente, é um projeto bem legal.

O projeto é desenvolvido inteiramente em C e, consequentemente, a biblioteca fornecida também é em C (`<fuse.h>`). Até existem bindings para outras linguagens, como a de [Python](https://github.com/libfuse/python-fuse), mas decidi permanecer com o C, que irá fornecer todo o poder necessário para a brincadeira.

Ao começar a desenvolver, o que mais vai interessar será uma única `struct`, sim, apenas uma: a `fuse_operations`, que é composta exatamente de ponteiros para as funções que o VFS especifica.

Um preview do `fuse_operations`:
```c
struct fuse_operations {
    int (*getattr) (const char *, struct stat *, struct fuse_file_info *fi);
    int (*readlink) (const char *, char *, size_t);
    int (*mknod) (const char *, mode_t, dev_t);
    int (*mkdir) (const char *, mode_t);
    int (*unlink) (const char *);
    ...
};
```

Ótimo! Agora o trabalho será resumido em implementar as funções que eu quero. Antes, escolhi um nome para o sistema de arquivos: leofs. Bem criativo, eu sei. A partir de agora, irei seguir da seguinte forma: colocarei os códigos de quatros funções que foram implementadas (`getattr`, `readdir`, `open` e `read`), junto com comentários explicando o funcionamento.

```c
/* O getattr será chamado para visualizar os atributos dos arquivos
   e diretórios. Sim, aqueles mesmos que você vê no "ls -l". */
static int leofs_getattr(const char *path, struct stat *st)
{
    st->st_uid = getuid(); // Identificador do usuário que montou o sistema de arquivos.
    st->st_gid = getgid(); // Identificador do grupo do usuário que montou.

    st->st_atime = time(NULL); // Último acesso, no caso, o horário atual.
    st->st_mtime = time(NULL); // Última modificação, também o horário atual.

    if (strcmp(path, "/") == 0) {
        st->st_mode = S_IFDIR | 0755; // Define como diretório com permissões 0755.
        st->st_nlink = 2; // Número de links: 2 (padrão para diretórios).
    } else {
        st->st_mode = S_IFREG | 0644; // Define como arquivo regular com permissões 0644.
        st->st_nlink = 1; // Um único link.
        st->st_size = 1024; // Define o tamanho como 1024 bytes.
    }

    return 0;
}
```

```c
// O readdir será chamado para vermos o que tem em um diretório.
static int leofs_readdir(const char *path, void *buffer,
                         fuse_fill_dir_t filler, off_t offset,
                         struct fuse_file_info *fi)
{
    // Adiciona os diretórios padrão (. e ..)
    filler(buffer, ".", NULL, 0);
    filler(buffer, "..", NULL, 0);

    /* Adiciona o conteúdo do diretório raiz.
       Coloquei um arquivo chamado poema. */
    if (strcmp(path, "/") == 0)
        filler(buffer, "poema", NULL, 0);

    return 0;
}
```

```c
// O open será chamado para a abertura de arquivos.
static int leofs_open(const char *path, struct fuse_file_info *fi)
{
    if (strcmp(path, "/poema") != 0)
        return -ENOENT; // Retorna erro caso o arquivo não seja "poema".

    // É possível adicionar mais verificações adicionais aqui.

    return 0;
}
```

```c
// O read será chamado para lermos o conteúdo de um arquivo.
static int leofs_read(const char *path, char *buffer,
                      size_t size, off_t offset,
                      struct fuse_file_info *fi)
{
    char *text = NULL; // Ponteiro para armazenar o conteúdo do arquivo.

    // Verifica qual arquivo está sendo lido com base no caminho.
    if (strcmp(path, "/poema") == 0)
        // Define o conteúdo para o "poema".
        text = "Rosas são vermelhas\nVioletas são azuis\n";
    else
        return -ENOENT; // Retorna erro -ENOENT (arquivo não encontrado).

    // Calcula o tamanho total do conteúdo.
    size_t len = strlen(text);

    // Verifica se o deslocamento está além do final.
    if (offset >= len)
        return 0; // Retorna 0 para indicar que não há mais nada para ler.

    // Ajusta o tamanho solicitado para não ultrapassar o final do arquivo.
    if (offset + size > len)
        size = len - offset;

    // Copia o conteúdo do texto para o buffer, começando no deslocamento especificado.
    memcpy(buffer, text + offset, size);

    // Retorna o número de bytes efetivamente lidos.
    return size;
}
```

Por fim, criamos nossa `struct fuse_operations` com as funções acima e a `main`:

```c
static struct fuse_operations operations = {
    .getattr = leofs_getattr,
    .readdir = leofs_readdir,
    .read    = leofs_read
};

int main(int argc, char *argv[])
{
    return fuse_main(argc, argv, &operations, NULL);
}
```

E pronto! Agora temos um sistema de arquivos com poucas linhas de código. Agora é só compilar e testar!

Para montar, basta executar no shell:
```bash
$ ./leofs <ponto_de_montagem>
```

Ao entrar na pasta e rodar `ls`, temos a seguinte saída:
```bash
poema
```
Nosso arquivo `poema`, que adicionamos na função `leofs_readdir`, está aqui.

E ao rodar `cat poema`:
```bash
Rosas são vermelhas
Violetas são azuis
```
Temos exatamente o texto que adicionamos no `leofs_read` para o `poema`.

Caso a gente tente executar uma operação de uma função que não foi implementada, o VFS irá retornar um erro. Exemplo:
```bash
$ rm poema
rm: não foi possível remover 'poema': Função não implementada
```
Obviamente, o leofs não tem nenhuma utilidade na prática e é muito simples, mas, pessoalmente, foi útil para me aprofundar mais no assunto. Durante o artigo, omiti vários tópicos que poderiam ter sido abordados.

Espero que talvez sirva de começo para outras pessoas que nunca tiveram contato com o assunto. Veja mais exemplos de sistemas de arquivos criados com o FUSE em [awesome-fuse-fs](https://github.com/koding/awesome-fuse-fs).

Código-fonte: https://github.com/1ukidev/leofs

Referências:
- https://libfuse.github.io/doxygen/index.html
- https://www.maastaar.net/fuse/linux/filesystem/c/2016/05/21/writing-a-simple-filesystem-using-fuse

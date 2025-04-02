---
date: "2025-01-18"
draft: false
title: "Creating a simple file system in Linux"
tags: ["linux", "fuse"]
---

Historically, in operating systems, file systems have always been tied to the kernel. In Linux, for example, different modules were created to recognize and handle various types of them. Looking at it this way, we might imagine that developing a filesystem from scratch would be a slow and complicated process, requiring deep knowledge of the kernel and complex data structures.

But is that really the case? With this question in mind, I decided to dive into the subject and tried to create, in the simplest way I could, my own file system (spoiler: it worked, well, more or less).

First of all, it's interesting to understand how our files and folders are generally handled at the high level. As soon as we enter a file manager, there's an interesting level of abstraction happening behind the scenes.

Each file system has its peculiarities when handling data. Some use an allocation table (FAT), others a B-tree (Btrfs). We can agree that it would be painful to try to handle each of these individually, and that's why the VFS was created, a layer that every filesystem needs to respect.

When making the following system call in Linux:
```c
int fd = open("file.txt", O_RDONLY);
```
The kernel's VFS is basically taking care of calling the equivalent of `open()` in the underlying file system.

Some other examples of calls standardized by VFS: `open()`, `read()`, `write()`, `mkdir()`.

With this in mind, I deduced that to continue with my idea, I just needed to implement these same calls to my liking, right? And that's pretty much it.

At this point, I could follow one of two different paths: implement at the kernel level as a module (more difficult) or implement at the user level using FUSE (easier). For now, FUSE proved to be a great start.

[FUSE](https://github.com/libfuse/libfuse) is an interface that allows us to implement any file system in userspace. This means: without needing to use root or install modules to the kernel. Initially, all that's necessary is to have FUSE itself installed. It's definitely a cool project.

The project is developed entirely in C and, consequently, the library provided is also in C (`<fuse.h>`). There are bindings for other languages, such as [Python](https://github.com/libfuse/python-fuse), but I decided to stick with C, which will provide all the necessary power for this experiment.

When starting development, what will interest us most is a single `struct`, yes, just one: the `fuse_operations`, which is composed exactly of pointers to the functions that the VFS specifies.

A preview of `fuse_operations`:
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

Great! Now the work will be reduced to implementing the functions I want. First, I chose a name for the file system: leofs. Very creative, I know. From now on, I will proceed as follows: I'll show the code for four functions that were implemented (`getattr`, `readdir`, `open`, and `read`), along with comments explaining how they work.

```c
/* getattr will be called to view the attributes of files
   and directories. Yes, those same ones you see in "ls -l". */
static int leofs_getattr(const char *path, struct stat *st)
{
    st->st_uid = getuid(); // ID of the user who mounted the file system.
    st->st_gid = getgid(); // ID of the user's group who mounted it.

    st->st_atime = time(NULL); // Last access, in this case, the current time.
    st->st_mtime = time(NULL); // Last modification, also the current time.

    if (strcmp(path, "/") == 0) {
        st->st_mode = S_IFDIR | 0755; // Define as directory with 0755 permissions.
        st->st_nlink = 2; // Number of links: 2 (standard for directories).
    } else {
        st->st_mode = S_IFREG | 0644; // Define as regular file with 0644 permissions.
        st->st_nlink = 1; // A single link.
        st->st_size = 1024; // Define the size as 1024 bytes.
    }

    return 0;
}
```

```c
// readdir will be called to see what's in a directory.
static int leofs_readdir(const char *path, void *buffer,
                         fuse_fill_dir_t filler, off_t offset,
                         struct fuse_file_info *fi)
{
    // Add standard directories (. and ..)
    filler(buffer, ".", NULL, 0);
    filler(buffer, "..", NULL, 0);

    /* Add the contents of the root directory.
       I added a file called "poem". */
    if (strcmp(path, "/") == 0)
        filler(buffer, "poem", NULL, 0);

    return 0;
}
```

```c
// open will be called for opening files.
static int leofs_open(const char *path, struct fuse_file_info *fi)
{
    if (strcmp(path, "/poem") != 0)
        return -ENOENT; // Returns error if the file is not "poem".

    // It's possible to add more additional checks here.

    return 0;
}
```

```c
// read will be called to read the contents of a file.
static int leofs_read(const char *path, char *buffer,
                      size_t size, off_t offset,
                      struct fuse_file_info *fi)
{
    char *text = NULL; // Pointer to store the file content.

    // Check which file is being read based on the path.
    if (strcmp(path, "/poem") == 0)
        // Define the content for "poem".
        text = "Roses are red\nViolets are blue\n";
    else
        return -ENOENT; // Return error -ENOENT (file not found).

    // Calculate the total size of the content.
    size_t len = strlen(text);

    // Check if the offset is beyond the end.
    if (offset >= len)
        return 0; // Return 0 to indicate there's nothing more to read.

    // Adjust the requested size to not exceed the end of the file.
    if (offset + size > len)
        size = len - offset;

    // Copy the text content to the buffer, starting at the specified offset.
    memcpy(buffer, text + offset, size);

    // Return the number of bytes effectively read.
    return size;
}
```

Finally, we create our `struct fuse_operations` with the functions above:
```c
static struct fuse_operations operations = {
    .getattr = leofs_getattr,
    .readdir = leofs_readdir,
    .open    = leofs_open,
    .read    = leofs_read
};
```

And the `main`:
```c
int main(int argc, char *argv[])
{
    return fuse_main(argc, argv, &operations, NULL);
}
```

And done! Now we have a file system with just a few lines of code. Now we just need to compile and test it!

To mount it, just run in the shell:
```bash
$ ./leofs <mount_point>
```

When entering the folder and running `ls`, we get the following output:
```bash
poem
```
Our `poem` file, which we added in the `leofs_readdir` function, is here.

And when running `cat poem`:
```bash
Roses are red
Violets are blue
```
We have exactly the text that we added in `leofs_read` for `poem`.

If we try to execute an operation for a function that wasn't implemented, the VFS will return an error. Example:
```bash
$ rm poem
rm: could not remove 'poem': Function not implemented
```
Obviously, leofs has no practical utility and is very simple, but personally, it was useful for me to dive deeper into the subject. During the article, I omitted several topics that could have been addressed.

I hope this might serve as a starting point for other people who have never had contact with the subject. See more examples of file systems created with FUSE in [awesome-fuse-fs](https://github.com/koding/awesome-fuse-fs).

Source code: https://github.com/1ukidev/leofs

References:
- https://libfuse.github.io/doxygen/index.html
- https://www.maastaar.net/fuse/linux/filesystem/c/2016/05/21/writing-a-simple-filesystem-using-fuse

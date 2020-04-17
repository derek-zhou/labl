LABL, label your files freely
=============================

Labl is a command-line tool to add arbituary labels to files. Let's suppose you have a bunch of files, possibly in a git project, and you want to put short labels on some of them so you can easily search or manipulate. There are ways, but non of them are very convenient:

 * you can put label strings in the file's comment area.
 However, each type of file has a different comment syntax; some does not even have one
 * you can use exif tags
 Only for pictures or other media files
 * you can have a central database file about labels in a project
 What about renaming or moving files
 
Labl solves this problem in a simple yet effective way. All labels are just symlinks; so they reside outside the files, but associate with the files natually, and can be checked-in to git or other SCM. There is no database file to maintain. 

## Usage ##

If you use git, then you can skip the setup. Otherwise, you need to tell labl the root dir of your project:

    mkdir .labl

labl will auto create this dir if it detects a .git dir at the same lavel. All labl's data are stored here. There are only dirs and symlinks in the directory, and please check them in.

labl accepts several sub-commands, such as add/drop/grep etc, fairly straight forward, please check the manpages for details. A few sub-commands that are not so straight forward and worth mentioning here:

### labl pick ###

Show the list of existing labels in this project and let you pick interactively. You can add and drop multiple labels on a file in one go.

### labl export ###

Export to a flat file, in emacs's org format, about all labl's internal data. If you have emacs and understand org file's syntax, you can easily figure out what is going on inside labl.

### labl import ###

The reverse of an export. Take the flat org file and replace all labl's internal data, stored in the .labl dir as dirs and symlinks.

## mtime of a file ##

Whenever labl add or remove a label on a file, it will `touch` the file. labl will never alter the content of a file. The touching is a important message to the user that something does change, although no in the content, about this file. And the build script can rebuild correctly. However, since the content does not change, git or other SCM will not record the event of the file, so if you depend on the `touch` for your build, please do a full build after each `git pull` or similiar commands. It is a good habit anyway.

## limitation of label string ##

labl use the label strings as dir names, so pretty much anything can be there except `/` or `.`. However, just to make sure you are not shooting yourself in the foot, please try to avoid:

 * space, tab, new lines. Some shell scripts will break down the road for sure. 
 * : colons. This is because labl may try to export/import to org, and org use : as delimiters
 
On the other hand, non-ASCII characters, such as CJK characters, smiley faces are perfectly OK. 

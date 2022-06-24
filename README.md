# My opinionated tips about Git

## Show branches

You can show your branches with `git branch -l`. But if there are many branches, the output has a drawback. It is
not sorted by date.

`git branch --sort=-committerdate` this lists the branches with the most recent branches on top.

I have an alias in my .bashrc: `alias gbs="git branch --sort=-committerdate"`

## Switch branches

Often I want to switch between two branches. This is handy:

`git checkout -`

This switches to the previous branch. And to get back ... again `git checkout -`.

Like `cd -` in the bash shell.

## History for selection

I do 95% of my git actions on the command-line. But "history for selection" is super cool.
It is a feature of my IDE (PyCharm). I can select a region in the code and then I can
have a look at the history of this region.

On the command-line you can use `git blame some-file`

## git stash

`git stash` is like a backpack. 

Example: You started to code. Then you realize (before you commit) that you work on the master branch.
But you want to work in a feature-branch before first. Then you can `git stash` your uncommitted changes.
Then you checkout or create the branch you want to work on. After that you `git stash pop` and
take your changes out of your backpack. 




## `git diff` of pull-request

Imagine you work on a branch which is a pull-request.

You want to see all changes of your pull-request.

What was changed on the branch since the branch was created?

```
git diff main...
```

Unfortunately this does not show your local changes, which are not committed yet.

To see them, too:

```
git diff $(git merge-base main HEAD)
```

## Find removed code

You are looking for a variable/method/class name which was in the code once, but which
is no longer in the current code.

Which commit removed or renamed it?

`git log -G my_name`

Attention: `git log -G=foo` will search for `=foo` (and I guess that is not what you wanted).

## Find string in all branches

If you know a co-worker introduced a variable/method/class, but
it is not in your code, and `git log -G my_name` does not help,
then you can use `git log --all -G my_name`. This will search in 
all branches.

## Find branch which contains a commit

You found a commit (maybe via `git log -G ...`) and now you
want to know which branches contain this commit:

`git branch --contains 684d9cc74d2`


## I don't care much for the git tree

Many developers like to investigate the git tree.

I almost never do this.

If you avoid long running git branches, then it is even less important.

The native GUI `gitk` gives you a graphical overview.

## rebase vs merge

I don't care much. In the past there have been endless discussion about this.

Avoid long running branches and then it matters even less.


## git bisect

"git bisect" is a great tool in conjunction with unit tests. It is easy
to find the commit, which introduced an error. Unfortunately, it is not a
one-liner for now. You can use it like this:

``` {.sourceCode .shell}
user@host> git bisect start HEAD HEAD~10 


user@host> git bisect run py.test -k test_something
 ...
c8bed9b56861ea626833637e11a216555d7e7414 is the first bad commit
Author: ...
```

But if your pull-requests get tested before they get merged (Continous-Integration), then you
hardly need "git bisect".

## git bisect for lazy people

```
git log --oneline | cut -d' ' -f1| while read hash; do echo; echo =============== ; echo    $hash; echo =============== ; git checkout $hash; YOUR COMMAND TO CHECK IF TESTS PASS; if [ $? -eq 0 ]; then echo this is good: $hash; break; fi; done
```



## Merge several commits

Sometimes you want to merge small commits into one bigger commit. For example if you worked on a branch
which was not merged to main yet.

But be careful. This re-writes the git history. This means other people developing on this branch
will get trouble if you do this.

But if this branch is your Merge-Request (aka Pull-Request), and you know nobody else uses this branch,
then it is fine to do so:

```
git rebase -i HEAD~N
```

N is the number of commits you want to work on. If you are working on a branch which was branched of "main", and you want to
rebase all your changes: `git rebase -i main`

Interactive rebase asks you for every commit what you want to do.

More about rewriting the git history: [Git Book: Rewriting History](https://git-scm.com/book/en/v2/Git-Tools-Rewriting-History)

But you can't push the branch with the re-written history. You need
to use:

```
git push --force-with-lease
```

But overall: Don't do this to often. This is not very productive (compared to writing new code,
fixing old bugs or writing more detailed tests)

# List all files

Git directories often contain a lot of auto-created files. For example
files created during running tests.

If you want to use `grep` on all files which get tracked by git, you can use
this:

```
git ls-files | xargs -d'\n' grep -P '...'
```

# Architecture: Keep Backend and Frontend in one git Repo

If you split your code into two repos. One for the backend code, one for the frontend code,
then you will make your life harder. The problem is that often a frontend change needs a corresponding
change in the backend. Syncing the deployment of both changes is usualy easier if you have one
repo.

BTW, many big companies use a gigantic monorepo for all their code. [Wikipedia Monorepo](https://en.wikipedia.org/wiki/Monorepo)

# Autocompletion

If you configured auto-completion, then you can easy checkout a branch if you know the first characters of the branch name:

```
git checkout foo[TAB] 
 --->        foobar
```
 
# Show current branch (for loop)

show the current branch name: `git rev-parse --abbrev-ref HEAD`

Example: you are in a directory containing many git repos. You want to know which one is not on the "main" branch:

```
for repo in *; do (cd $repo; echo $repo $(git rev-parse --abbrev-ref HEAD) ); done| grep -v main
```
# Empty commit

Most web-GUIs of CI-systems have a "retry" button. But sometimes this does not work, or you don't want to leave your context.

```
git commit --allow-empty -m "Trigger CI"
```


# side by side diff

Imagine you want to see an old commit side-by-side.

You could do `git show 8d73caed`, but this would not be side-by-side.

```
git difftool 8d73caed~1 8d73caed
```

~1 means "commit before 8d73caed"

--> launches [meld](https://meldmerge.org/), if installed, or your
prefered diff-tool. See [git-difftool](https://git-scm.com/docs/git-difftool)

# Resolve, take theirs

You merged a branch into your branch, and now you have conflicts. You want
to discard your change, and take their changes:

```
git checkout --theirs path/to/file
```

# Related

* [Güttli's opinionated Programming Guidelines](https://github.com/guettli/programming-guidelines)
* [Güttli's opinionated Python Tips](https://github.com/guettli/python-tips)
* [Güttli working-out-loud](https://github.com/guettli/wol)





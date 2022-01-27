# My opinionated tips about Git

## Show branches

You can show your branches with `git branch -l`. But if there are many branches, the output has a drawback. It is
not sorted by date.

`git branch --sort=-committerdate` this lists the branches with the most recent branches on top.


## Switch branches

Often I want to switch between two branches. This is handy:

`git checkout -`

This switches to the previous branch. And to get back ... again `git checkout -`.

Like `cd -` in the bash shell.

## History for selection

I do 95% of my git actions on the command-line. But "history for selection" is super cool.
It is a feature of my IDE (PyCharm). I can select a region in the code and then I can
have a look at the history of this region.

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

`git log -S my_name`

## Find string in all branches

If you know a co-worker introduced a variable/method/class, but
it is not in your code, and `git log -S my_name` does not help,
then you can use `git log --all -S my_name`. This will search in 
all branches.

## Find branch which contains a commit

You found a commit (maybe via `git log -S ...`) and now you
want to know which branches contain this commit:

`git branch --contains 684d9cc74d2`


## I don't care for the git tree

Many developers like to investigate the git tree.

I almost never do this.

If you avoid long running git branches, then it is even less important.

## rebase vs merge

I don't care much. In the past there have been endless discussion about this.

Avoid long running branches and then it matters even less.


## Learn "git bisect"

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

But if your pull-requests get tested before they get merged, then you
hardly need "git bisect".

# Related

* [Güttli's opinionated Programming Guidelines](https://github.com/guettli/programming-guidelines)
* [Güttli's opinionated Python Tips](https://github.com/guettli/python-tips)
* [Güttli working-out-loud](https://github.com/guettli/wol)





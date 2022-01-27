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

## rebase vs merge

I don't care much. In the past there have been endless discussion about this.

Avoid long running branches and then it matters even less.



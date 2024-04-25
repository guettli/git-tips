# My opinionated tips about Git

## Show branches

You can show your branches with `git branch -l`. But if there are many branches, the output has a drawback. It is
not sorted by date.

`git branch --sort=-committerdate` this lists the branches with the most recent branches on top.

You can change the default sorting in you config like that:

```
git config --global branch.sort -committerdate
```

I have an alias in my .bashrc: `alias gbs="git branch --sort=-committerdate | fzf --header Checkout | tr '*' ' ' | xargs git switch`

## checkout --> switch+restore

In the past `git checkout` was used for different use-cases.

I think it is time to use the new commands: 

`git switch` to switch to a different branch

`git restore` to restore files

I avoid `git checkout`.

## Switch branches

Often I want to switch between two branches. This is handy:

`git switch -`

This switches to the previous branch. And to get back ... again `git switch -`.

Like `cd -` in the bash shell.


## History for selection

I do 95% of my git actions on the command-line. But "history for selection" is super cool.
It is a feature of IntelliJ-based IDEs. You can select a region in the code and then you can
have a look at the history of this region.

On the command-line you can use `git blame some-file`

## git stash

`git stash` is like a backpack. 

Example: You started to code. Then you realize (before you commit) that you work on the main branch.
But you want to work in a feature-branch before first. Then you can `git stash` your uncommitted changes.
Then you switch or create the branch you want to work on. After that you `git stash pop` and
take your changes out of your backpack. 




## `git diff` of pull-request

Imagine you work on a branch which is a pull-request.

You want to see all changes of your pull-request.

```
git diff main
```
Above command might show you a lot of changes which happend on the main branch 
since you created the branch. You don't want to see those changes.

What was changed on your branch since the branch was created?

```
git diff origin/main...
```

Unfortunately this does not show your local changes, which are not committed yet.

To see them, too:

```
git diff $(git merge-base main HEAD)
```

## Create a backup of a branch

```
# Create a new branch
git switch -c foobar-backup

# Switch back from "foobar-backup" to the previous branch
git switch -
```

You could use [tagging](https://git-scm.com/book/en/v2/Git-Basics-Tagging) for this, too. But I prefer above solution.

## Don't be afraid to to delete your local branch

Imagine you did some strange things on your local branch "foo",
and all you want is to get back to the "origin/foo" branch.

That's easy:

```
# create a backup of your current local branch
> git switch -c backup-of-foo

# delete the local copy of the branch.
> git branch -D foo

# switch to "origin/foo"
> git switch foo
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

## Hyperlink from git commit hash to preview

If I do `git log -Smysearchterm` in the vscode terminal, then I see 
a list of commits.

Now I would like to see a preview of these commits.

It is very easy, I was just not aware of that at the beginning.

Example:

```
commit 6ae936342d2c3c30fba47eec5a543ce6c53d0ebb
Author: foobar <foobar@example.com>
Date:   Wed Feb 14 01:54:04 2024 +0530
```

The commit hash "6ae936..." is a **hyperlink**.

You just need to click on it, and you can inspect the details of the commit.

## I don't care much for the git tree

Many developers like to investigate the git tree.

I almost never do this.

If you avoid long running git branches, then it is even less important.

The native GUI `gitk --all` gives you a graphical overview. Don't ask me why the `--all`
parameter is not the default. Without it, you won't see other branches.

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

This walks the git history down from the current commit to the older commits.

Copy and adapt for your needs.

```
#!/bin/bash

BRANCH=your_branch

set -euxo pipefail
log_report() {
    echo "Error on line $1"
} 
trap 'log_report $LINENO' ERR


git switch $BRANCH
git log --oneline | cut -d' ' -f1 | while read hash; 
    do
    echo
    echo    $hash;
    git switch -d $hash
    DO_SOMETHING
    if YOUR_COMMAND; then
        echo "this is good (the commit above this introduced the bug): $hash"
        break
    fi
    git restore .
    sleep 1
done
git switch $BRANCH
```

You need to adapt these parts:

* BRANCH
* DO_SOMETHING
* YOUR_COMMAND: Should return `0` if everything is fine.
* remove "sleep 1", if you need to walk back a lot of commits.

## Merge several commits into one commit

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
rebase all your changes: `git rebase -i $(git merge-base main @)`

Interactive rebase asks you for every commit what you want to do.

More about rewriting the git history: [Git Book: Rewriting History](https://git-scm.com/book/en/v2/Git-Tools-Rewriting-History)

But you can't push the branch with the re-written history. You need
to use:

```
git push --force-with-lease
```

But overall: Don't do this to often. This is not very productive (compared to writing new code,
fixing old bugs or writing more detailed tests)

# Squash all commits into a single commit

Pull-Requests in Kubernetes should be squashed. See [PR Guidelines](https://www.kubernetes.dev/docs/guide/pull-requests/#squashing).

`git rebase -i HEAD~N` works fine, except you merged the main branch into your branch after creating the branch. Then your branch will contain merge commits, and the normal procedure won't work.

You can use `git reset --soft`, and then create a new commit which contains all the changes between "main" and "your-pr-branch".

```
git switch main
git pull

git switch your-pr-branch

# create a backup, just in case something goes wrong
git switch your-pr-branch-backup

# switch back to your-pr-branch
git switch -

# If you want to copy commit messages from your branch,
# then copy them now. After the following command, you need
# to look into your backup branch.
git reset --soft $(git merge-base main HEAD)
git commit
git push --force-with-lease
```

# Change a git branch "inplace"

Imagine you developed your changes on a branch called "feature-foo". 
This branch was created from branch "feature-base".

Requirements change, and now you need to merge your changes into the main branch,
but not the changes from branch "feature-base".

You could create a new branch, but since the central git-UI (github/gitlab) already references
"feature-foo", you want to change the branch "inplace". 

This creates the patches in a directory:
```
git switch feature-foo
git format-patch feature-base -o ~/tmp/foo-patches
```

```
git reset --hard origin/main
patch -p0 < ~/tmp/foo-patches/000... (files one by one)
```

# Apply difference between two branches on a third branch

The above tip _Change a git branch "inplace"_ uses external patches.

This can be used to [Apply difference between two branches on a third branch](https://stackoverflow.com/questions/73279330)

# Restore a single file

Imagine you are working on a feature branch. But you want to restore one file to the original version of the main branch.

```
git restore -s main path/to/file
```
`s` like "source branch"

Source: https://stackoverflow.com/a/59756673/633961


# List all files

Git directories often contain a lot of auto-created files. For example
files created by tests.

If you want to use `grep` on all files which get tracked by git, you can use
this:

```
git ls-files | grep -vP 'exclude1|exclude2' | xargs -r -d'\n' grep -nP '...'
```

In detail:

* `git ls-files` list all files which are tracked in git.
* `grep -vP 'exclude1|exclude2'` (optional): exclude some lines from the stream of file names.
* `xargs -r -d'\n'` for every line in stdin stream do ...
* `grep -nP '...'` search in the file for a pattern. The `-n` displays the line number. This is handy if you start the command from the terminal of your IDE, then you can click on the output (like `myfile.go:42`) to jump to the matching line in your IDE.

You can give `ls-files` a glob expression. This matches the whole filename (including the parent directories).

Imagine you have a directory containing many git repos, and there are files in `REPO/foo/test_project_bar/settings.py`, you
can use grep like this:

```
for repo in *; do (cd "$repo"; git ls-files '*test_project*settings.py' |xargs -r -d'\n' grep RECAP ); done
```

Don't forget the `*` before "test_project".

If you add a comment at the end, you can easily find this command in your shell history (for example via `ctrl-r` (backward search)):

```
(cd ~/projects/; for repo in * ; do (
     cd "$repo"; git ls-files '*.my-extension' |
     xargs -r -d'\n' grep -P 'my-term' ) ;
 done) # grep over all repos
```

Once you executed this once, you can easily get back to this line by ctrl-r (search backwards in history) and then type “over all”

# Architecture: Keep Backend and Frontend in one git Repo

If you split your code into two repos. One for the backend code, one for the frontend code,
then you will make your life harder. The problem is that often a frontend change needs a corresponding
change in the backend. Syncing the deployment of both changes is usualy easier if you have one
repo.

BTW, many big companies use a gigantic monorepo for all their code. [Wikipedia Monorepo](https://en.wikipedia.org/wiki/Monorepo)

# Autocompletion

If you configured auto-completion, then you can easy switch a branch if you know the first characters of the branch name:

```
git switch foo[TAB] 
 --->        foobar
```
 
# Show current branch (for loop)

show the current branch name: `git rev-parse --abbrev-ref HEAD`

Example: you are in a directory containing many git repos. You want to know which one is not on the "main" branch:

```
for repo in *; do (cd "$repo"; echo $repo $(git rev-parse --abbrev-ref HEAD) ); done| grep -v main
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
git restore --theirs path/to/file
```

# After resolving conflict: git diff HEAD~1

After resolving a conflict by hand, `git diff HEAD~1` shows the file compared
to the previous version. Somehow `git diff` shows something else.

# git log over many git repos

You have a directory called "all-repos". This contains many git-repos. Now you want to use `git log -G FooBar` over all git repos. You only
want to search for commits which where done during the last 8 months and you
want to sort the result by the timestamp of the commit.


A bit ugly, but works:

```
for repo in *; do (cd "$repo"; git log -G FooBar --all --pretty="%ad %h in $repo by %an, %s" --date=iso --since=$(date -d "8 months ago" --iso)) ; done | sort -r| head
```

# Think outside the box

Your local git repo is just a simple directory. Sometimes it is easier to just use `cp -a my-repo my-repo2` to create
a copy of your git repo. 

Now you can checkout branch1 in one git repo, and branch2 in the second git repo.

Especialy if you are new to git, and unsure what will happen. Then
relax and create a copy of your git repo before you execute command which
make you feel uncomfortable.

# Merge-tool (Meld)

I like [Meld](https://meldmerge.org/), which is a visual diff and merge tool.

Imagine I changed several parts in a file. Now a realize that some parts are good, and should
stay. And some parts should get removed again.

I am on a feature-branch which was created from "main".

```
# Create a copy of the file
cp my-dir/my-file.xyz ~/tmp/

# restore the file to the original version
git restore -s main my-dir/my-file.xyz

meld my-dir/my-file.xyz ~/tmp/my-file.xyz
```

Now Meld opens and I can easily choose which parts I want to take into my branch, and which parts I don't need.


# show change of merge commit

This shows no changes for merge commits:
```
git show <commit-hash>
```

Use:
```
git show -m <commit-hash>
```
The output of above command has several parts. For each parent commit one part.

# Git pager

I use [delta](https://github.com/dandavison/delta) which shows `git diff` colorful, so that you can easily
spot small changes in long lines.

# revert a merge commit

You want to revert this merge commit:

```
commit 67181091ac5069fc78cc2e79cc5641ee43516eee (HEAD -> main, origin/main, origin/HEAD)
Merge: 90d4ee9c 14f8548e
Author: Some One <someone@example.com>

    Merge branch 'super-feature' into 'main'
```

A merge commit has two parents: 90d4ee9c and 14f8548e. You need to tell git which parent you want to choose.

If you want to keep 90d4ee9c you use `-m 1`. If you want to keep 14f8548e, you use `-m 2`.

This following line will keep 14f8548e and drop 90d4ee9c.

```
git revert 67181091 -m 2
```

Related [Stackoverflow Answer](https://stackoverflow.com/a/7100005/633961)


# cherry-pick -n

`git cherry-pick ...` creates a new commit automatically. Sometimes you don't want only some changes of the original commit.

You can use the option `-n` to only get the changes. Now you can modify the changes and commit manually.

# parent branch

Unfortunately it is not straight forward to find the branch name of the parent branch.

Example:

You created "feature-1" by branching off "main".

Then you create "feature-2" by branching off "feature-1" (because the second feature depends 
on a change which was done in feature-1).

Then for some weeks different things are more urgent, and now you are unsure
if you branched off main or from an other branch.

I stored this in my local script directory
```
#!/bin/bash
# parent-branch.sh
git show-branch -a 2>/dev/null \
| grep '\*' \
| grep -v `git rev-parse --abbrev-ref HEAD` \
| head -n1 \
| perl -ple 's/\[[A-Za-z]+-\d+\][^\]]+$//; s/^.*\[([^~^\]]+).*$/$1/'
```

Source: https://stackoverflow.com/a/74314172/633961

# delete merged branches

After some months there are too many old branches. Time to clean up.

This deletes all branches which are completely merged. This only deletes local branches.

```
❯ git branch --merged | grep -Pv '^\s*(\*|master|main|staging)' | xargs -r git branch -d
```

Unfortunately there will be several branches left which are not merged yet. No script can
decide if they can be deleted or not.

Use `branch -rd` to delete the remote branch, too.

# tig: text based GUI for git

[tig](https://jonas.github.io/tig/) is a text based GUI for git.

Much better than `git log` on the command line.

# ripgrep: recursive grep which respects .gitignore

[ripgrep](https://github.com/BurntSushi/ripgrep): recursive grep which respects .gitignore

Handy, if there are huge directories in you git-repo which you usualy want to skip.

# Undelete a branch

Imagine you accidentally deleted a branch:

```
❯ git branch -D foo-branch 
Deleted branch foo-branch (was d885d38).
```

Oh my god! What have I done?

Relax, you can easily create the branch again.

```
❯ git switch -d d885d38
❯ git switch -c foo-branch
```

# Feature branch, only one commit

For some git repos exists a policy that your feature branch
should contain only one commit before the branch can get merged.

Nevertheless I want to commit several times.

I could do `git rebase -i HEAD~N` before the PR gets merged,
but an alternative is this:

I use `--amend` to alter the previous commit. This
needs a force-push, because it rewrites the history.

```
git commit --amend . && git push --force-with-lease
```

# How to Use Multiple Git Configs on One Computer

Image you up to now had only a personal Github account.

Now you want to have two (on one computer): one for your personal
stuff and one for work related stuff. 

Create two gitconfig files:

```
cd $HOME
cp .gitconfig .gitconfig-personal
mv .gitconfig .gitconfig-work
```

```
# change email address to your address for work related mails

vi .gitconfig-work
```

vi .gitconfig
```
[includeIf "gitdir:~/personal/"]
  path = ~/.gitconfig-personal
[includeIf "gitdir:~/work/"]
  path = ~/.gitconfig-work
```


Source: [How to Use Multiple Git Configs on One Computer](https://www.freecodecamp.org/news/how-to-handle-multiple-git-configurations-in-one-machine/)

# vscode for selective application of changes

Imagine you want to take some changes of a different branch into your code.

If you care about the lines of code, not the commits, then you can use the following way to get the changed lines into your code.

Switch to your branch (the branch which should get updated).

In the vscode choose Branches, then "Compare with HEAD".

Then there is a new tab at the bottom: "Search & Compare".

Expand the part "N files changed".

Then choose the first file and use "Open Changes with Working File".

Now you can easily fetch the lines which you want to get into your code. 

You see a splitted windows. Your code is on the right side.

In the middle are arrow symbols to pick changes.

# pre-commit.com

I use [pre-commit.com](//pre-commit.com).

For example I use this to avoid committing, if there are untracked files:

```
# See https://pre-commit.com/hooks.html for more hooks
repos:
  - repo: local
    hooks:
      - id: no-untracked-files-in-git
        name: no-untracked-files-in-git
        language: system
        entry: "bash -c 'files=$(git ls-files --exclude-standard --others); echo $files; test -z \"$files\"'"
```

Related: https://stackoverflow.com/a/75543767/633961
 
# git subrepo

If you want to include code of a third-party into your git repo, you can "vendor" it via [git subrepo](https://github.com/ingydotnet/git-subrepo).

This is a handy tool, which in most cases better than git-submodules or git-subtree.

# Personal Notes per git Repo

I want to have personal notes per git repo which are not part of the git repo.

I use this pattern:

First I create a global git ignore:

```
git config --global core.excludesfile ~/.gitignore
```

Then I create ~/.gitignore, and add `me`:

```
me
```

If I want to save personal notes or scripts I create a symlink from the git repo a file in ~/docs:

```
mkdir ~/doc/COMPANY/some-git-repo
cd ~/COMPANY/some-git-repo
ln -s ~/doc/COMPANY/some-git-repo me
```

Now I can edit notes easily:

```
code me/foo.txt
```

But don't be careful. Don't increase the "bus factor" by building a single-person "information silo".


# Never commit a .envrc file

I use [direnv](https://direnv.net/) to manage environment variables. The tool direnv uses `.envrc` files to 
set environment variables.

In never want the `.envrc` file to be part of a git repo, because it usualy contains credentials (for example GITHUB_TOKEN).

To prevent accidental commits of .envrc files in all your Git repositories, you can set up a global .gitignore file like above,
and add `.envrc` to the file.


# Github: Tab width: 4

If you use tabs for indentation (for example in Golang), then you might want to
change the default tab width from 8 to 4: https://github.com/settings/appearance

# Which line ignores a file?

You have a file `foo/bar.baz` which gets somehow ignored by a line in a .gitignore.

But you are unsure which line is responsible for ignoring this file.

You can use `git check-ignore -v`:

```
❯ git check-ignore -v foo/bar.baz
.gitignore:23:foo/*.baz foo/bar.baz
```


# Related

* [Güttli's opinionated Programming Guidelines](https://github.com/guettli/programming-guidelines)
* [Güttli's opinionated Python Tips](https://github.com/guettli/python-tips)
* [Güttli working-out-loud](https://github.com/guettli/wol)





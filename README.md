# My opinionated tips about Git

This is not an introduction to Git. Just some hints about how I use `git`.

## How to use this Git Repo

This repo contains some scripts in the [scripts](scripts) directory.

I add that directory to `$PATH` so the scripts are available everywhere.

Most of them use the [Bash Strict Mode](https://github.com/guettli/bash-strict-mode).

## One directory per PR

Imagine you work on one Git repo and there are three PRs. These PRs stay open for several days, so
constantly running `git switch` gets annoying.

The solution is simple: create several copies of your Git repo. Imagine your repo is called `foo`.

Then check out that repo four times:

- foo-main
- foo-pr-one
- foo-pr-two
- foo-pr-three

If you use VS Code, you can give each directory a different border color:

```json
{
  "workbench.colorCustomizations": {
    "statusBar.background": "#00ff51",
    "titleBar.activeBackground": "#00ff51",
    "titleBar.inactiveBackground": "#00ff51"
  }
}
```

That makes it easier to switch between PRs.

If you have a train of PRs, I like this mnemonic to remember the order:

- First PR: light blue (like "baby")
- Second PR: yellow (like "youth")
- Third PR: purple (like elderly)

## `git checkout` -> `git switch` + `git restore`

In the past, `git checkout` was used for different use cases.

I think it is time to use the newer commands:

`git switch` to switch to a different branch

`git restore` to restore files

I avoid `git checkout`.

## Create a backup of a branch

```console
# Create a new branch
git switch -c foobar-backup

# Switch back from "foobar-backup" to the previous branch
git switch -
```

You could use [tagging](https://git-scm.com/book/en/v2/Git-Basics-Tagging) for this as well, but I
prefer this approach.

## Pull Requests

Git itself does not know about pull requests (PRs). That concept was added by platforms like
GitHub, GitLab, and Codeberg.

## Squash PRs

The easiest way to keep the Git history clean: Squash PRs. Create as many commits as you like in
your PR. Do not rebase in the PR, don't do force-pushes.

At the end, just squash the PR into a single commit.

## List branches

[git-list-branches.sh](scripts/git-list-branches.sh)

## Switch back to previous branch

Often I want to switch between two branches. This is handy:

`git switch -`

This switches to the previous branch. And to get back ... again `git switch -`.

Like `cd -` in the bash shell.

## Accidentally Commit on Branch Main

You accidentally created a commit on your local main branch. That was a mistake because every change
should be done via a pull request. You have not pushed your changes yet.

Solution: create a backup, delete your local `main`, and recreate it from `origin`.

```console
# Create a backup
git switch -c main--backup
git branch -D main
git switch main
```

## git stash

`git stash` is like a backpack.

Example: You started to code. Then you realize (before you commit) that you work on the main branch.
But you want to move that work onto a feature branch first. You can `git stash` your uncommitted
changes, switch to or create the branch you actually want, and then use `git stash pop` to bring
the changes back.

## Restore a single file

Imagine you are working on a feature branch. But you want to restore one file to the original
version of the main branch.

```console
git restore -s main path/to/file
```

`s` like "source branch"

## Restore interactively

Imagine you are working on a feature branch. But you want to restore some changes to the original
version of the main branch. You want to do that interactively because some changes in the file
should stay. Use `-p`:

```console
git restore -s main -p path/to/file
```

## `git diff` of pull-request

Imagine you work on a branch that backs a pull request.

You want to see all changes of your pull-request.

```console
git diff main
```

That command might show a lot of changes that happened on `main` since you created the branch. You
do not want to see those changes.

What was changed on your branch since the branch was created?

```console
git diff origin/main...
```

Unfortunately this does not show your local changes, which are not committed yet.

To see them, too:

```text
git diff $(git merge-base main HEAD)
```

### Show Changes to a single file

`git log foo.txt` shows you the commits which changes the file.

But it shows you only the commit message. If you want to see the changes which were done, you need
to use `-p` (like patch): `git log -p foo.txt`.

## Find removed code

You are looking for a variable/method/class name which was in the code once, but which is no longer
in the current code.

Which commit removed or renamed it?

`git log -G my_name`

Attention: `git log -G=foo` will search for `=foo` (and I guess that is not what you wanted).

## Find string in all branches

If you know a co-worker introduced a variable/method/class, but it is not in your code, and `git log
-G my_name` does not help, then you can use `git log --all -G my_name`. This will search in all
branches.

## Find branch which contains a commit

You found a commit (maybe via `git log -G ...`) and now you want to know which branches contain this
commit:

`git branch --contains 684d9cc74d2`

## I don't care much for the git tree

Many developers like to investigate the git tree.

I almost never do this.

If you avoid long running git branches, then you almost never need to inspect the git branch
history.

The native GUI `gitk --all` gives you a graphical overview. Don't ask me why the `--all` parameter
is not the default. Without it, you won't see other branches.

## rebase vs merge

I do not care much. In the past there have been endless discussions about this.

My way:

- In a PR, merge changes into the feature branch.
- Squash the PR when it gets merged to `main`.

## List all files

Git directories often contain a lot of auto-created files. For example files created by tests.

If you want to use `grep` on all files which get tracked by git, you can use this:

```console
git ls-files | grep -vP 'exclude1|exclude2' | xargs -r -d'\n' grep -nP '...'
```

In detail:

- `git ls-files` list all files which are tracked in git.
- `grep -vP 'exclude1|exclude2'` (optional): exclude some lines from the stream
  of file names.
- `xargs -r -d'\n'` for every line in stdin stream do ...
- `grep -nP '...'` search in the file for a pattern. The `-n` displays the line number. This is
  handy if you start the command from the terminal of your IDE, then you can click on the output
  (like `myfile.go:42`) to jump to the matching line in your IDE.

You can give `ls-files` a glob expression. This matches the whole filename (including the parent
directories).

Imagine you have a directory containing many git repos, and there are files in
`REPO/foo/test_project_bar/settings.py`, you can use grep like this:

```console
for repo in *; do (
  cd "$repo"
  git ls-files '*test_project*settings.py' | xargs -r -d'\n' grep RECAP
); done
```

Don't forget the `*` before "test_project".

If you add a comment at the end, you can easily find this command in your shell history (for example
via `ctrl-r` (backward search)):

```console
(cd ~/projects/; for repo in * ; do (
     cd "$repo"; git ls-files '*.my-extension' |
     xargs -r -d'\n' grep -P 'my-term' ) ;
 done) # grep over all repos
```

Once you executed this once, you can easily get back to this line by ctrl-r (search backwards in
history) and then type “over all”

## Autocompletion

If you configured auto-completion, you can easily get a list of branches if you know the first
characters of the branch name:

```console
git switch branch[TAB]
 --->        branch-foo
 --->        branch-bar
 --->        ...
```

## Solving Conflicts with `meld`

I am on a branch that was created from the main branch some hours ago.

Now I want to merge the new main branch into my branch again.

```console
❯ git merge main

Auto-merging internal/foo/api/v1beta1/mycrd_types.go
CONFLICT (content): Merge conflict in internal/foo/api/v1beta1/mycrd_types.go
```

I use `meld` for solving conflicts.

Be sure to set this option first:

```console
git config --global mergetool.meld.useAutoMerge true

git mergetool --tool=meld
```

Now a nice UI opens, and you will see three columns:

- On the left side, you see your original code (before starting the merge).
- In the middle, you see the result of the automatic merges done by Git.
- On the right side, you see "theirs" (new main branch).

The green and blue parts are automatically resolved. You do not modify these in most cases.

You will see conflicts marked with a red background. In the middle column of a conflict line, you
see `(??)`.

You can take the left (your side), the right side (theirs), or modify the code manually.

Finally, go to the middle column and press `Ctrl+S` to save your changes. Then close the UI. The UI
will reopen if there is a second file with a conflict.

I have tried several other tools, but `meld` (with useAutoMerge) is still my favorite.

## Solving Conflicts: Overview

Before solving a Git merge conflict, it is convenient to have an overview: what changed between the
base and the remote, and what changed between the base and your local version?

I found no tool which does this, so I use that small Bash script
[scripts/git-conflict-overview.sh](scripts/git-conflict-overview.sh).

Now I can choose the simpler change, then apply the more complex change to the file, and after
that I apply the simpler change by hand.

I use the above tool only to inspect the changes. To resolve the conflict by hand, I use
`git mergetool` with `meld`. See the next section.

## Search with Editor, not with your eyes

Not related to Git, but still helpful: do not search through code with your eyes all day. Use your
IDE.

For example, I mark a place with "ööö" (German umlauts) when I want to jump back to that point
later. Of course this should never be committed.

## git diff shows no changes?

Sometimes `git diff` shows no changes, although you expected to see changes.

It is likely that your changes are already staged (for example you resolved a merge conflict).

Run `git status` to see if you have staged changes.

You need to use `git diff --staged` to see your changes.

## Git pager

I use [delta](https://github.com/dandavison/delta), which shows `git diff` output with better
colors, so small changes in long lines are easier to spot.

## Automatically prune on fetch

```console
git config --global fetch.prune true
```

It sets a global Git config so every git fetch will prune stale remote-tracking branches—i.e., it
automatically deletes local refs like origin/foobar when they’ve been removed from the remote.

## How to Use Multiple Git Configs on One Computer

Imagine you have used only a personal GitHub account so far.

Now you want two identities on one computer: one for personal work and one for work-related repos.

Create two gitconfig files:

```console
cd $HOME
cp .gitconfig .gitconfig-personal
mv .gitconfig .gitconfig-work

# change the email address to your work address

vi .gitconfig-work
```

Then edit `.gitconfig`:

```ini
[includeIf "gitdir:~/personal/"]
  path = ~/.gitconfig-personal
[includeIf "gitdir:~/work/"]
  path = ~/.gitconfig-work
```

Source: [How to Use Multiple Git Configs on One
Computer](https://www.freecodecamp.org/news/how-to-handle-multiple-git-configurations-in-one-machine/)

## Pick some lines from another branch with `git difftool`

Imagine you want to take some changes of a different branch into your code.

If you care about the lines of code, not the commits, then you can use the following way to get the
changed lines into your code.

Switch to the branch that should be updated.

```console
git difftool other-branch -- your-file.txt
```

This will open `meld` and you can take some lines to your local version.

## pre-commit.com

I use [pre-commit.com](//pre-commit.com).

For example I use this to avoid committing, if there are untracked files:

```yaml
# See https://pre-commit.com/hooks.html for more hooks
repos:
  - repo: local
    hooks:
      - id: no-untracked-files-in-git
        name: no-untracked-files-in-git
        language: system
        entry: >-
          bash -c 'files=$(git ls-files --exclude-standard --others);
          echo $files; test -z "$files"'
```

Related: <https://stackoverflow.com/a/75543767/633961>

## gitleaks via pre-commit

This repository uses `gitleaks` in `.pre-commit-config.yaml`.

Why in `pre-commit` and not only in CI?

- The feedback is immediate. You notice accidental secrets before they leave your laptop.
- It is cheaper to fix. Amending a local commit is easier than cleaning up after a pushed secret.
- It protects all commits, not only the branch which later gets CI.

I use `gitleaks` here because it is a maintained general-purpose secret scanner and its license is
MIT, not AGPL.

## Public .envrc file, private .env file

I use [direnv](https://direnv.net/) to manage environments. `direnv` uses `.envrc` files to
set environment variables.

But for secrets I use `.env` files.

Example:

```bash
# shellcheck shell=bash

# .envrc file of direnv.
# If you use VS Code, please use the `direnv` extension.

# Use nix-direnv
# https://github.com/nix-community/nix-direnv
# Ensures that flake.nix gets evaluated.
use flake

PATH_add scripts
PATH_add node_modules/.bin

# Load variables from .env
dotenv_if_exists
```

I never want the `.env` file to be part of a Git repo, because it usually contains credentials (for
example `GITHUB_TOKEN`).

To prevent accidental commits of .env files in all your Git repositories, you can set up a global
.gitignore file like above, and add `.env` to the file.

## Long branch names are fine

I think it is perfectly fine to have long branch names like:

```text
tg/check-workspace-providers-on-create-of-apc--based-on-disallow-change-of-controlplane-location
```

## GitHub: Tab width: 4

If you use tabs for indentation (for example in Golang), then you might want to change the default
tab width from 8 to 4: <https://github.com/settings/appearance>

## GitHub: open PR in web UI

This command opens the current PR in your browser:

```console
gh pr view --web
```

## VS Code: autoFetch

I like the VS Code Git [`autoFetch`
setting](https://code.visualstudio.com/docs/sourcecontrol/overview#_remotes). This fetches the
latest changes from the remote every N seconds.

This is handy because I see `[behind]` if I use [my Starship prompt Git
config](#starship-prompt).

## Keep GitHub Action workflows simple

I prefer to keep GitHub Action workflows simple. I like that GitHub does CI for me, but third-party
GitHub Actions have the drawback that I often cannot reproduce them on my local machine.

There are tools like [act](https://github.com/nektos/act), but they often did not work for me.

Keep things simple by using a reliable Bash script in [Bash Strict
Mode](https://github.com/guettli/bash-strict-mode).

This works in GitHub CI and on my local Linux device.

## Starship Prompt

I use [Starship Prompt](https://starship.rs/config/#git-status) so I get notified in the prompt
when the Git status is not clean.

My config:

```toml
[git_status]
conflicted = ' conflicted'
ahead = ' ahead'
behind = ' behind'
diverged = ' diverged'
up_to_date = ''
stashed = ' stashes'
untracked = ' untracked'
```

This shows nothing when the Git state is clean and a readable warning when something is wrong.

## GitHub: Play a sound when a CI job is finished

Sometimes I need to wait until a GitHub CI job is finished. Waiting is not very productive, so I do
other things while waiting.

When the job is done, I want to get notified. This can be done like this:

```console
gh run watch; music
```

`gh run watch` gives you a list of jobs, and you can select one. When it is finished, the next
command runs. Use whatever command you want for that. For me, `music` is a small script that plays
a song I like.

## restore, revert, reset

These three commands all start with `re`, so new Git users often mix them up.

The order above is intentional. It goes from safer and more local to more dangerous:

- `restore`: restore **files**
- `revert`: reverse a **commit** by adding a new commit
- `reset`: re-set the **branch pointer**

Rough mental model:

- `restore` changes files in your working tree or index.
- `revert` keeps history intact and records a new commit that undoes an older one.
- `reset` moves `HEAD` and usually the current branch.

Examples:

```console
# Restore one file from main.
git restore -s main path/to/file

# Undo an old commit safely by creating a new commit.
# Both the old commit and the new undo commit stay in the history.
git revert <commit-hash>

# Move HEAD and the current branch back by one commit.
git reset --hard HEAD~1
```

If you are unsure, use `restore` for files and `revert` for published history.

Be careful with `reset`, especially after pushing. If unsure, use `revert`, not `reset`.

## ripgrep: recursive grep which respects .gitignore

[ripgrep](https://github.com/BurntSushi/ripgrep): recursive grep which respects .gitignore

Handy if there are huge directories in your Git repo that you usually want to skip.

## delete merged branches

After some months there are too many old branches. Time to clean up.

This deletes all branches that are fully merged. It only deletes local branches.

```console
❯ git branch --merged \
  | grep -Pv '^\s*(\*|master|main|staging)' \
  | xargs -r git branch -d
```

There will still be several branches left that are not merged yet. No script can decide whether
they can be deleted or not.

Use `branch -rd` to delete the remote branch, too.

## git bisect

`git bisect` is a great tool in combination with unit tests. It makes it easy to find the commit
that introduced a bug. Unfortunately, it is not a one-liner. You can use it like this:

```console
user@host> git bisect start HEAD HEAD~10


user@host> git bisect run py.test -k test_something
 ...
c8bed9b56861ea626833637e11a216555d7e7414 is the first bad commit
Author: ...
```

But if your pull requests get tested before they get merged in continuous integration, you hardly
need `git bisect`.

## git bisect for lazy people

This walks the git history down from the current commit to the older commits.

Copy and adapt for your needs.

```bash
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

- BRANCH
- DO_SOMETHING
- YOUR_COMMAND: Should return `0` if everything is fine.
- remove "sleep 1", if you need to walk back a lot of commits.

## Merge several commits into one commit

Sometimes you want to merge small commits into one bigger commit. For example if you worked on a
branch which was not merged to main yet.

But be careful. This re-writes the git history. This means other people developing on this branch
will get trouble if you do this.

But if this branch is your merge request (or pull request), and you know nobody else uses this
branch, then it is fine to do so:

```console
git rebase -i HEAD~N
```

`N` is the number of commits you want to work on. If you are working on a branch which was branched off
"main", and you want to rebase all your changes: `git rebase -i $(git merge-base main @)`

Interactive rebase asks you for every commit what you want to do.

More about rewriting the git history: [Git Book: Rewriting
History](https://git-scm.com/book/en/v2/Git-Tools-Rewriting-History)

But you cannot push the branch with the rewritten history. You need to use:

```console
git push --force-with-lease
```

But overall: do not do this too often. This is not very productive (compared to writing new code,
fixing old bugs or writing more detailed tests)

## Squash all commits into a single commit

Unfortunately, in Kubernetes-related projects, squash via GitHub (as explained above) is disabled.

See [PR Guidelines](https://www.kubernetes.dev/docs/guide/pull-requests/#squashing).

`git rebase -i HEAD~N` works fine, except when you merged the main branch into your branch after creating
the branch. Then your branch will contain merge commits, and the normal procedure won't work.

You can use `git reset --soft` and then create a new commit that contains all the changes between
"main" and "your-pr-branch".

```console
git switch main
git pull

git switch your-pr-branch

git merge main

# create a backup, just in case something goes wrong
git switch -c your-pr-branch-backup

# switch back to your-pr-branch
git switch -

# If you want to copy commit messages from your branch,
# then copy them now. After the following command, you need
# to look into your backup branch.
git reset --soft $(git merge-base main HEAD)
git commit
git push --force-with-lease
```

## Apply difference between two branches on a third branch

The above tip *Change a git branch "inplace"* uses external patches.

This can be used to [Apply difference between two branches on a third
branch](https://stackoverflow.com/questions/73279330)

## Empty commit

Most web-GUIs of CI-systems have a "retry" button. But sometimes this does not work, or you don't
want to leave your context.

```console
git commit --allow-empty -m "Trigger CI"
```

## Show one commit in difftool

Imagine you want to see an old commit side-by-side.

You could do `git show 8d73caed`, but this would not be side-by-side.

```console
git difftool 8d73caed~1 8d73caed
```

`~1` means "the commit before 8d73caed".

This launches [meld](https://meldmerge.org/) if it is installed, or your preferred diff tool. See
[git-difftool](https://git-scm.com/docs/git-difftool).

## Resolve, take theirs

You merged a branch into your branch, and now you have conflicts. You want to discard your change,
and take their changes:

```console
git restore --theirs path/to/file
```

## git log over many git repos

You have a directory called "all-repos". It contains many Git repos. Now you want to use
`git log -G FooBar` across all of them. You only want to search for commits that were created
during the last 8 months, and you want to sort the result by commit timestamp.

A bit ugly, but works:

```console
for repo in *; do (
  cd "$repo"
  git log -G FooBar --all --pretty="%ad %h in $repo by %an, %s" \
    --date=iso --since="$(date -d "8 months ago" --iso)"
); done | sort -r | head
```

## Merging some parts of a different branch

I like [Meld](https://meldmerge.org/), which is a visual diff and merge tool.

Imagine I changed several parts of a file. Now I realize that some parts are good and should stay,
while others should be removed again.

I am on a feature branch that was created from "main".

```console
# Create a copy of the file
cp my-dir/my-file.xyz ~/tmp/

# restore the file to the original version
git restore -s main my-dir/my-file.xyz

meld my-dir/my-file.xyz ~/tmp/my-file.xyz
```

Now Meld opens and I can easily choose which parts I want to take into my branch, and which parts I
don't need.

---

Imagine you created one PR containing several changes. Now you decide that you want to create three
PRs instead.

First, create a backup of your branch:

```console
git switch -c my-backup; git switch -
```

Create the branch for the first feature, create a copy of your whole directory, and switch the copy
to main:

```console
git switch -c feature-1
cd ..
cp -a myrepo myrepo-main
cd myrepo-main
git switch main
git pull
```

Now launch `meld`:

```console
cd ..
meld myrepo-main myrepo
```

Now you can easily remove all changes that belong to feature-2 and feature-3.

I tried that with VS Code, but `meld` is more usable for this. You can copy files between
both directories with the context menu.

You can accept (click on arrow) or reject (shift-click) single changes.

## Show change of merge commit

This shows no changes for merge commits:

```console
git show <commit-hash>
```

Use:

```console
git show -m <commit-hash>
```

The output of the command above has several parts: one part for each parent commit.

## cherry-pick -n

`git cherry-pick ...` creates a new commit automatically. Sometimes you don't want only some changes
of the original commit.

You can use the option `-n` to only get the changes. Now you can modify the changes and commit
manually.

## parent branch

Unfortunately, it is not straightforward to find the name of the parent branch.

Example:

You created "feature-1" by branching off "main".

Then you create "feature-2" by branching off "feature-1" (because the second feature depends on a
change which was done in feature-1).

Then other things are more urgent for a few weeks, and now you are unsure whether you branched off
`main` or another branch.

I stored this in my local script directory:

```bash
#!/bin/bash
# parent-branch.sh
git show-branch -a 2>/dev/null \
| grep '\*' \
| grep -v `git rev-parse --abbrev-ref HEAD` \
| head -n1 \
| perl -ple 's/\[[A-Za-z]+-\d+\][^\]]+$//; s/^.*\[([^~^\]]+).*$/$1/'
```

Source: <https://stackoverflow.com/a/74314172/633961>

## Undelete a branch

Imagine you accidentally deleted a branch:

```console
❯ git branch -D foo-branch
Deleted branch foo-branch (was d885d38).
```

Oh my god! What have I done?

Relax, you can easily create the branch again.

```console
❯ git switch -d d885d38
❯ git switch -c foo-branch
```

## Taskfile stamp files per task name

If several independent Taskfile tasks watch the same directory, they should not share a single stamp
file. [`scripts/git-worktree-has-changed.sh`](scripts/git-worktree-has-changed.sh) therefore
requires a task name before the path:

```yaml
version: "3"

tasks:
  lint:
    status:
      - bash ./scripts/git-worktree-has-changed.sh lint .
    cmds:
      - bash ./internal/lint.sh
      - bash ./scripts/git-worktree-has-changed.sh --touch-stamp lint .
```

The task name becomes part of the stamp filename in `.tmp/`. Non filename-safe characters get
replaced with underscores.

## Git submodules

I try to avoid Git submodules.

## Chain of branches: Add base branch to name of second branch

Sometimes you create a chain or train of branches. The first branch is still in
review, but you start to work on the next items in a second branch.

This gets confusing if you have several branches in this chain.

To make things easier to understand, I sometimes add the base branch name to the name of the second
branch.

First branch: `foo`

Then I call the second branch: `name-of-second-branch--based-on-foo`.

The third would be: `name-of-third-branch--based-on-name-of-second-branch`.

And so on.

## History for selection

I do 95% of my git actions on the command-line. But "history for selection" is super cool. It is a
feature of IntelliJ-based IDEs. You can select a region in the code and then you can have a look at
the history of this region.

On the command line you can use `git blame some-file`, but it is not as powerful as the
IntelliJ IDE solution.

I switched to VS Code several years ago, but still miss this feature.

If you know how to get that in VS Code, please tell me.

## Which line ignores a file?

You have a file `foo/bar.baz` that is being ignored by a line in a `.gitignore`.

But you are unsure which line is responsible for ignoring this file.

You can use `git check-ignore -v`:

```console
❯ git check-ignore -v foo/bar.baz
.gitignore:23:foo/*.baz foo/bar.baz
```

## Related

- [Güttli's opinionated Programming Guidelines](https://github.com/guettli/programming-guidelines)
- [Güttli's opinionated Python Tips](https://github.com/guettli/python-tips)
- [Güttli working-out-loud](https://github.com/guettli/wol)

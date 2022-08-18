<p align="center">
  <h1 align="center">🌱 refresh.nvim</h1>
</p>

<p align="center">
  Auto pull and push keeps you refreshed!
</p>

```
                     ┌────────────┐
               ┌─────┤  VimEnter  ◄─────┐
               │     └────────────┘     │
               │                        │
         ┌─────▼──────┐          ┌──────┴──────┐       ┌────────────┐
         │  register  │          │   ExitPre   ├───────►    push    │
         └─────┬──────┘          └──────▲──────┘       └────────────┘
               │                        │
               │                        │
        ┌──────▼──────┐          ┌──────┴─────┐
        │ BufWinEnter │          │   (edit)   │
        └──────┬──────┘          └──────▲─────┘
               │                        │
               │     ┌────────────┐     │
               └─────►    pull    ├─────┘
                     └────────────┘


powered by asciiflow.com
```

Note: still on alpha stage, public APIs might be changed.

## 💚 Motivation

I take personal notes related to my project with neovim, but it's in a different
repository from the project. So I have to run git add, commit, and push in both
repository, and it's a drag and forgettable.

This plugin watch a directory, and automatically run `git pull` and
`add`/`commit`/`push`. Additionally, it provides a removing empty files/dirs
option so as not to mess up the notes repository, or a branch validation option
not to pollute your github contributions graph.

## 🍀 Installation

[plenary.nvim](https://github.com/nvim-lua/plenary.nvim) is required.

with [packer.nvim](https://github.com/wbthomason/packer.nvim):

```lua
use {
  'shiradofu/refresh.nvim',
  requires = 'nvim-lua/plenary.nvim',
  run = './refresh.sh restart',
}
```

## 📗 Usage

### `refresh.register(dir, config)`

Basically, all you have to do is to register a directory:

```lua
local refresh = require('refresh')

-- By default, all keys are not set, which means they are disabled.
-- You have to explicitly add config to enable pull/delete_empty/push.

-- Dir must be a git repository root.
refresh.register('/some/dir', {
  pull = {
    -- If true, nothing would be echoed when succeeded.
    silent = true,
  },
  delete_empty = {
    -- Files included this will be deleted before auto-push if they are empty.
    -- File path can be relative to the registered dir.
    -- { '*' } means all files under the direcotry.
    -- 'SESSION' mesans files opened during the current session.
    files = { 'my-note.md' },
    -- files = { '*' },
    -- files = 'SESSION',
  },
  push = {
    -- Files included this will be git added, commited and pushed on ExitPre.
    -- File path can be relative to the registered dir.
    -- { '*' } means all files in the repository.
    -- 'SESSION' mesans files opened during the current session.
    files = { '*' },
    -- This return value is used as a commit message.
    -- This is optional. If omitted, ISO 8601 UTC datetime will be used.
    commit_msg = function()
      return os.date '!%Y-%m-%dT%TZ'
    end,
  },
  -- This is an option to avoid polluting your github contributions.
  -- Default is set to nil, and simply skip the branch validation.
  branch = 'main',
})
```

#### About `branch` option

If you enable auto-push, large number of commits might be created. This could
"pollute" your github contributions graph. You can avoid this by pushing commits
to **non-default branch**.

From GitHub
[Why are my contributions not showing up on my profile?](https://docs.github.com/en/account-and-profile/setting-up-and-managing-your-github-profile/managing-contribution-settings-on-your-profile/why-are-my-contributions-not-showing-up-on-my-profile#commits)
page:

> ### Commits
>
> Commits will appear on your contributions graph if they meet all of the
> following conditions:  
> ...
>
> - The commits were made:
>   - **In the repository's default branch**
>   - In the gh-pages branch (for repositories with project sites)

[emphasis mine]

`branch` option is for this, you'll get an error if you are trying working on
the wrong branch.

### `refresh.status(dir)`

This allows you to see the list of registered dirs and configs.

```lua
local refresh = require('refresh')

refresh.status('/some/dir') --> prints configs for '/some/dir'
refresh.status() --> prints all registered configs
```

`RefreshStatus` vim command is also available.

## 🍏 Integration

Originally, I develop this for
[lightnote.nvim](https://github.com/shiradofu/lightnote.nvim). (In fact, I was
creating single plugin which has these two features.) But I think this could be
used with other plugins or tools, such as:

- [nvim-neorg/neorg](https://github.com/nvim-neorg/neorg)
- [mattn/memo](https://github.com/mattn/memo)

(Actually I haven't use these tools, so I'm not sure it works very well or not.)

# cheat-cmds

cheat linux commands with (Obsidian) markdown file.

## Search

```bash
$ cheatcmd bun
───────┬─────────────────────────────────────────────────────────────
       │ STDIN
───────┼─────────────────────────────────────────────────────────────
   1   │ ## bundle
   2   │
   3   │ #bundle
   4   │
   5   │ ```bash
   6   │ # vendorのパス
   7   │ bundle config set --local path vendor/bundle
   8   │
   9   │ # install時のwith/without
  10   │ bundle config set --local without html develop
  11   │ ```
───────┴─────────────────────────────────────────────────────────────
```

## Add

```bash
echo "ruby -run -e httpd . --port 8080 --bind '*'" | cheatcmd
```

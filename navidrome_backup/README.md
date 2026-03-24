# navidrome_backup

Export Navidrome playlists from a SQLite database into Obsidian-friendly markdown files.

## Requirements

- Ruby
- Bundler

Install dependencies:

```sh
bundle install
```

## Usage

Run the exporter with the SQLite database path, an output directory, and one or more playlist name patterns.

```sh
bundle exec ruby backup_playlists.rb --db data/navidrome.db --out out あき
```

Arguments wrapped in `/.../` are treated as regular expressions:

```sh
bundle exec ruby backup_playlists.rb --db data/navidrome.db --out out '/^あ.*さん$/'
```

Add repeatable tags with `--tag`:

```sh
bundle exec ruby backup_playlists.rb --db data/navidrome.db --out out --tag music --tag backup あき 名演
bundle exec ruby backup_playlists.rb --db $NAS/prjs/navidrome/production/data/navidrome.db --tag music --tag 音楽 --tag 歌 --tag 歌枠 --out $OBSIDIAN/Projects/Music/Navidrome/ '/.*さん$/' 名演
```

This writes one markdown file per matched playlist under the output directory.

## Output format

Each generated file contains:

- the playlist name as the heading
- metadata for `song_count` and `created_at`
- Obsidian tags from `--tag` plus a required layered tag like `#navidromem/playlist_name`
- a markdown table with `title`, `album`, `artist`, and `path`

## Sample data

A sample database is included at `data/navidrome.db`.

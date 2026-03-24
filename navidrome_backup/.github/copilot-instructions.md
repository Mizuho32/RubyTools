# navidrome sqlite db backup

Backup specified navidrome playlist to obsidian markdown table.

input:
- sqlite path
- playlist name list (pattern strs)
- output dir path
output:
- markdown files under output dir

sample DB is located at ./data/navidrome.db
Implt it in Ruby.

## output file

playlist_name.md including list of:
- title
- album
- artist
- path

metadata:
- song_count
- created_at
- obsidian tags of #"user_defined_tags", ... + #navidromem/(playlist_name) (¢«must, layered tag)


## SQLITE structure

media_file: files
- title
- album
- artist
- path
- id

playlist: playlists table
- id (playlist id)
- name
- song_count
- created_at

playlist_tracks:
- playlist_id
- media_file_id

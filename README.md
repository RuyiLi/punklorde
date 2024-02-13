# Installation

1. Install nix. Alternatively, just install crystal and sqlite3 directly.
2. If using nix, run nix-shell.
3. Create an sqlite database file. Run the schema creation script (e.g. `sqlite3 punklorde.db` followed by `.read schema.sql`)
4. Run `crystal main.cr` to start the server. For production, run `crystal build main.cr` and run the produced binary as a daemon.

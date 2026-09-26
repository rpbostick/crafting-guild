# Plans and task files

`plans/<slug>/` holds the plans and builder task files for a project. They live here, not in the project repo, so the product repo stays free of process artifacts. A builder gets the task file's content in its prompt, so it never needs to read this directory.

Conventions:
- `plans/<slug>/<plan>.md` starts with an `**In flight right now**` block. Cold-start prints it.
- A task file is complete on its own: goal, files to touch, how to test, what to leave alone, done-when.

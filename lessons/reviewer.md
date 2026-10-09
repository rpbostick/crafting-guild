# Lessons: reviewer

Appended to every review prompt. Keep under 20 lines.

- A finding without a file and line is a suggestion.
- Do not block on wording, docstrings or style when the code is right. Those are suggestions.
- Check the test log committed on the branch against the counts claimed in the commit message.
- A test whose assertion cannot fail (asserting on a value it just set, or on a fixture that mirrors the code) is blocking under rule 2.
- Rule 18 (secrets, home paths, personal identifiers in tracked files) is always blocking.

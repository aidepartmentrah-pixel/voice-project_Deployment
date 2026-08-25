#!/bin/sh
# Refreshes the data snapshot + vector index ONCE at container startup, then
# starts the chat server. This is the entire v1 refresh mechanism -- no
# scheduler, no periodic re-run. Data goes stale until this container is
# restarted (`docker compose restart rag-chatbot`), which is a documented
# known limitation, not an oversight -- see documentation/RELEASE_NOTES.md.
#
# A failed refresh (eDelphyn/backend unreachable) does not stop the
# container from starting: the optional chat feature should surface a
# "nothing indexed yet" state through the UI rather than crash-loop the
# whole service over what is itself an optional external dependency.
set -e

echo "==> rag-chatbot: refreshing data snapshot + vector index (one-time, at startup)..."
if python refresh_data.py; then
  echo "==> rag-chatbot: data refresh complete."
else
  echo "==> rag-chatbot: WARNING -- data refresh failed (eDelphyn/backend unreachable?)." >&2
  echo "==> rag-chatbot: starting anyway; chat will run against whatever index (if any) exists." >&2
fi

exec python app.py

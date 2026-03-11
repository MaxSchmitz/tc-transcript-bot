#!/usr/bin/env python3
"""Query Grok via xai-sdk. Reads prompt from stdin, prints response to stdout."""
import os
import sys

from xai_sdk import Client
from xai_sdk.chat import user

api_key = os.environ.get("XAI_API_KEY") or os.environ.get("GROK_API_KEY")
if not api_key:
    print("Error: XAI_API_KEY or GROK_API_KEY must be set", file=sys.stderr)
    sys.exit(1)

model = sys.argv[1] if len(sys.argv) > 1 else "grok-4-1-fast-reasoning"
prompt = sys.stdin.read().strip()

if not prompt:
    print("Error: no prompt provided on stdin", file=sys.stderr)
    sys.exit(1)

client = Client(api_key=api_key)
chat = client.chat.create(model=model)
chat.append(user(prompt))
response = chat.sample()
print(response.content)

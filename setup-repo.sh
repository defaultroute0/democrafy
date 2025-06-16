#!/usr/bin/env bash

# Navigate to project root and initialize git
if [ ! -d .git ]; then
  git init
  git add .
  git commit -m "Initial commit: scaffold both iOS client and backend"
  echo "Git repository initialized successfully at $(pwd)"
else
  echo "Git repository already initialized."
fi
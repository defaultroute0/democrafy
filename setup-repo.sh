#!/usr/bin/env bash
set -e

echo "Creating project directories..."
mkdir -p OutloudDJ-iOS/{Models,Services,ViewModels,Views,Resources}
mkdir -p OutloudDJ-Backend
echo "Directories created."

echo "Writing AppEntry.swift..."
cat > OutloudDJ-iOS/AppEntry.swift << 'CODE'
import SwiftUI

@main
struct OutloudDJApp: App {
    @StateObject private var authService = SpotifyAuthService()
    @StateObject private var apiService: SpotifyAPIService
    @StateObject private var backendService = PartyBackendService(baseURL: URL(string: "https://YOUR_BACKEND_URL")!)

    init() {
        let auth = SpotifyAuthService()
        _authService = StateObject(wrappedValue: auth)
        _apiService = StateObject(wrappedValue: SpotifyAPIService(authService: auth))
    }

    var body: some Scene {
        WindowGroup {
            NavigationView {
                LobbyView()
            }
            .environmentObject(authService)
            .environmentObject(apiService)
            .environmentObject(backendService)
        }
    }
}
CODE
echo "AppEntry.swift written."

echo "Writing backend files..."
cat > OutloudDJ-Backend/package.json << 'BACK'
{
  "name": "outlouddj-backend",
  "version": "1.0.0",
  "main": "server.js",
  "scripts": { "start": "node server.js" },
  "dependencies": {
    "cors": "^2.8.5",
    "express": "^4.18.2",
    "uuid": "^9.0.0"
  }
}
BACK

cat > OutloudDJ-Backend/server.js << 'BACK'
const express = require('express');
const { v4: uuid } = require('uuid');
const cors = require('cors');

const app = express();
app.use(cors());
app.use(express.json());

const rooms = {}, suggestions = {};

app.post('/rooms', (req, res) => {
  const id = uuid();
  rooms[id] = { id, name: req.body.name, hostID: req.body.hostID || null };
  suggestions[id] = [];
  res.json(rooms[id]);
});
app.get('/rooms', (req, res) => res.json(Object.values(rooms)));
// …other endpoints as before…

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`Backend running on port ${PORT}`));
BACK

echo "Backend files written."

echo "Initializing git…"
git init
git add .
git commit -m "Initial scaffold: iOS client & Node backend"
echo "✔️  All set up in $(pwd)"

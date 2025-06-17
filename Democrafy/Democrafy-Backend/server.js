const express = require('express');
const { v4: uuid } = require('uuid');
const cors = require('cors');

const app = express();
app.use(cors());
app.use(express.json());

const rooms = {};
const suggestions = {};

app.post('/rooms', (req, res) => {
  const id = uuid();
  rooms[id] = { id, name: req.body.name, hostID: req.body.hostID || null };
  suggestions[id] = [];
  res.json(rooms[id]);
});

app.get('/rooms', (req, res) => res.json(Object.values(rooms)));

app.post('/rooms/:roomID/suggestions', (req, res) => {
  const { roomID } = req.params;
  const id = uuid();
  const item = { id, uri: req.body.uri, title: req.body.title, artist: req.body.artist, votes: 0, timestamp: new Date(), played: false };
  suggestions[roomID].push(item);
  res.json(item);
});

app.get('/rooms/:roomID/suggestions', (req, res) => {
  res.json(suggestions[req.params.roomID] || []);
});

app.post('/suggestions/:id/vote', (req, res) => {
  const { id } = req.params;
  let found;
  Object.values(suggestions).forEach(arr => arr.forEach(item => { if(item.id === id) found = item; }));
  if (found) { found.votes += Number(req.body.delta); return res.json({}); }
  res.status(404).json({ error: 'Not found' });
});

app.get('/rooms/:roomID/top', (req, res) => {
  const list = (suggestions[req.params.roomID] || []).filter(x => !x.played);
  const top = list.sort((a,b) => b.votes - a.votes || new Date(a.timestamp) - new Date(b.timestamp))[0] || null;
  res.json(top);
});

app.post('/suggestions/:id/played', (req, res) => {
  const { id } = req.params;
  Object.values(suggestions).forEach(arr => arr.forEach(item => { if(item.id === id) item.played = true; }));
  res.json({});
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`Backend running on port ${PORT}`));

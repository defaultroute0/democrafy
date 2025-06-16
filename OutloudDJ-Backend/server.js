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

const mongoose = require('mongoose');
const Profile = require('./backend/models/Profile');
require('dotenv').config({ path: './backend/.env' });
mongoose.connect(process.env.MONGO_URI, {
  useNewUrlParser: true,
  useUnifiedTopology: true
}).then(async () => {
  const profiles = await Profile.find({});
  console.log("PROFILES IN DB:", JSON.stringify(profiles, null, 2));
  mongoose.connection.close();
}).catch(err => {
  console.error(err);
});

const express = require("express");
const app = express();

app.use(express.json());

app.post("/payment", (req, res) => {
  res.json({ status: "success" });
});

app.listen(3000, () => {
  console.log("Mock API running on port 3000");
});

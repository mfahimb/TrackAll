const express = require("express");
const axios = require("axios");
const cors = require("cors");

const app = express();
app.use(cors());
app.use(express.json());

app.post("/login", async (req, res) => {
  try {
    const apiResponse = await axios.post(
      "http://hrisapi.prangroup.com:8083/v1/Login/HrisLogin",
      req.body,
      {
        headers: {
          "S_KEYL": "RxsJ4LQdkVFTv37rYfW9b6",
          "Authorization": "Basic YXV0aDoxMlByYW5AMTIzNDU2JA==",
        },
      }
    );
    res.json(apiResponse.data);
  } catch (error) {
    console.log(error.message);
    res.status(500).json({ error: "HRIS API failed" });
  }
});

const PORT = process.env.PORT || 3001;
app.listen(PORT, () => console.log(`Proxy Server running on ${PORT}`));

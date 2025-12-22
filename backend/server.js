const express = require("express");
const axios = require("axios");
const cors = require("cors");
const fs = require("fs");
const path = require("path");

const app = express();
app.use(cors());
app.use(express.json());

// ---------------------------
// LOGIN API (proxy to HRIS)
// ---------------------------
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
    console.error("Login API error:", error.message);
    res.status(500).json({ error: "HRIS API failed" });
  }
});

// ---------------------------
// NPT ENTRY (file-based storage)
// ---------------------------
const dataDir = path.join(__dirname, "data");
const nptFilePath = path.join(dataDir, "npt.json");

// Ensure data folder and file exist
if (!fs.existsSync(dataDir)) fs.mkdirSync(dataDir);
if (!fs.existsSync(nptFilePath)) fs.writeFileSync(nptFilePath, JSON.stringify([]));

// Load NPT data
function loadNptData() {
  try {
    const raw = fs.readFileSync(nptFilePath, "utf-8");
    return JSON.parse(raw);
  } catch (err) {
    console.error("Error loading NPT data:", err);
    return [];
  }
}

// Save NPT data
function saveNptData(data) {
  try {
    fs.writeFileSync(nptFilePath, JSON.stringify(data, null, 2), "utf-8");
  } catch (err) {
    console.error("Error saving NPT data:", err);
  }
}

// ---------------------------
// POST: Create NPT entry
// ---------------------------
app.post("/npt-entry", (req, res) => {
  try {
    const entries = loadNptData();

    const newEntry = {
      id: Date.now(), // numeric ID
      buildingSection: req.body.buildingSection || "",
      operationCategory: req.body.operationCategory || "",
      operation: req.body.operation || "",
      lineNo: req.body.lineNo || "",
      machineNo: req.body.machineNo || "",
      smv: req.body.smv || "",
      downtimeCause: req.body.downtimeCause || "",
      startTime: req.body.startTime || "",
      endTime: req.body.endTime || "",
      totalMinutes: req.body.totalMinutes || "",
      numOperators: req.body.numOperators || "",
      responsibleDept: req.body.responsibleDept || "",
      responsibleUser: req.body.responsibleUser || "",
      remarks: req.body.remarks || "",
      date: req.body.date || new Date().toISOString().split("T")[0],
    };

    entries.push(newEntry);
    saveNptData(entries);

    res.json({ success: true, message: "Saved successfully", data: newEntry });
  } catch (err) {
    console.error("POST /npt-entry error:", err);
    res.status(500).json({ success: false, message: "Failed to save entry" });
  }
});

// ---------------------------
// GET: Fetch all NPT entries
// ---------------------------
app.get("/npt-entry", (req, res) => {
  try {
    const entries = loadNptData().sort((a, b) => b.id - a.id);
    res.json({ success: true, data: entries });
  } catch (err) {
    console.error("GET /npt-entry error:", err);
    res.status(500).json({ success: false, data: [] });
  }
});

// ---------------------------
// PUT: Update NPT entry
// ---------------------------
app.put("/npt-entry/:id", (req, res) => {
  try {
    const entries = loadNptData();
    const id = parseInt(req.params.id);

    const index = entries.findIndex((item) => item.id === id);
    if (index === -1) {
      return res.status(404).json({ success: false, message: "Entry not found" });
    }

    // Update only provided fields
    entries[index] = {
      ...entries[index],
      ...req.body,
    };

    saveNptData(entries);

    res.json({ success: true, message: "Updated successfully", data: entries[index] });
  } catch (err) {
    console.error("PUT /npt-entry/:id error:", err);
    res.status(500).json({ success: false, message: "Failed to update entry" });
  }
});

// ---------------------------
// DELETE: Remove NPT entry
// ---------------------------
app.delete("/npt-entry/:id", (req, res) => {
  try {
    const id = parseInt(req.params.id);
    const entries = loadNptData();
    const filtered = entries.filter((item) => item.id !== id);

    if (filtered.length === entries.length) {
      return res.status(404).json({ success: false, message: "Entry not found" });
    }

    saveNptData(filtered);
    res.json({ success: true, message: "Deleted successfully" });
  } catch (err) {
    console.error("DELETE /npt-entry/:id error:", err);
    res.status(500).json({ success: false, message: "Failed to delete entry" });
  }
});

// ---------------------------
const PORT = process.env.PORT || 3001;
app.listen(PORT, () => console.log(`Proxy + NPT API running on port ${PORT}`));

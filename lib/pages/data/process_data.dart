// lib/data/process_data.dart
class ProcessData {
  // Map of section -> list of processes
  static Map<String, List<String>> sectionProcesses = {
    "Cutting": ["Cut OP1", "Cut OP2", "Cut OP3"],
    "Sewing": [
      "Neck piping",
      "Join Operations",
      "Basic Process",
      "Semi Critcal",
      "Critical",
      "Servising (Edge Securing)",
      "Panel side seam",
      "Plakect hole",
      "Join Operations",
      "Pocket Blind hem",
      "Join Operations",
      "Armhole topstitch",
      "Join Operations",
      "Pocket attach",
      "Top Stitch",
      "Side seam",
      "Side seam long sleeve",
      "Back neck binding",
      "Side seam Stripe",
      "Side seam",
      "Sleeve hem",
      "Top Stitch",
      "Sleeve cuff make & fold",
      "Sleeve hem",
      "Top Stitch",
      "Gazzet join",
      "Snap button",
      "Back neck binding-FOA",
      "Back Rise",
      "Back Rise",
      "Front Rise",
      "Front Rise",
      "V-Neck Topstitch",
      "Button attached",
      "KEY hole",
      "Back tape FOA",
      "Body hem",
      "Bottom Rib topstitch",
      "Neck Rib make",
      "Bottom Hole",
      "ARMHOLE ELASTIC TOPSTICH",
      "Bottom Binding",
      "LOCKING",
      "FOAM CUP TOPSTICH WITH PP",
      "Hook and Attaching",
      "Eylet Hole attached",
      "Waist Hole with fushing",
      "Waist Belt KAN",
      "BTN hole",
      "Normal Process",
      "Critical Process",
      "Pocket Hem"
    ],
    "Finishing": ["Finish OP1", "Finish OP2"],
  };

  // Get all sections
  static List<String> getSections() => sectionProcesses.keys.toList();

  // Get processes by section
  static List<String> getProcesses(String section) =>
      sectionProcesses[section] ?? [];
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trackall_app/pages/widgets/top_menu_bar.dart';
import 'package:trackall_app/services/lov_service.dart';

// =====================================================================
// PRODUCTION ENTRY PAGE
// Menu ID: 11
// Page Name: Production Entry
// Description: Record production quantities, bundle quantities, and rejections
// =====================================================================

class ProductionEntryPage extends StatefulWidget {
  const ProductionEntryPage({super.key});

  @override
  State<ProductionEntryPage> createState() => _ProductionEntryPageState();
}

class _ProductionEntryPageState extends State<ProductionEntryPage> {
  final LovService _lovService = LovService();

  // ===================== VALUES =====================
  String? itemId, itemLabel, jobNo, orderNo, articleNo;
  String? processId, processLabel, lineId, lineLabel;
  String? sizeId, size;
  String? remainingQty = "0";
  
  final TextEditingController productionQtyController = TextEditingController();
  int productionQtyValue = 0;
  String? productionQty;
  
  int bundleQtyValue = 1;
  String? bundleQty = "1";
  final TextEditingController bundleQtyController = TextEditingController(text: "1");
  
  int rejectQtyValue = 0;
  String? rejectQty = "0";
  final TextEditingController rejectQtyController = TextEditingController(text: "0");
  
  String? flag = "Internal";

  Map<String, String>? selectedItemMap;
  String? appUser;
  bool isLoading = false;

  // ===================== LOV LISTS =====================
  List<Map<String, String>> itemList = [];
  List<Map<String, String>> processList = [];
  List<Map<String, String>> lineList = [];
  List<Map<String, String>> sizeList = [];
  
  // ===================== PAGINATION STATES =====================
  int itemDisplayCount = 10;
  int processDisplayCount = 10;
  int lineDisplayCount = 10;
  int sizeDisplayCount = 10;
  
  final List<Map<String, String>> flagList = [
    {"id": "Internal", "label": "Internal"},
    {"id": "External", "label": "External"},
  ];

  @override
  void initState() {
    super.initState();
    _loadAppUser();
  }

  // ===================== LOADERS =====================
  Future<void> _loadAppUser() async {
    setState(() => isLoading = true);
    
    final prefs = await SharedPreferences.getInstance();
    final user = prefs.getString('userId') ?? "";
    
    setState(() {
      appUser = user;
    });
    
    debugPrint("✅ PRODUCTION PAGE LOGIN USER => $appUser");

    await Future.wait([
      _loadItems(),
    ]);
    
    setState(() => isLoading = false);
  }

  Future<void> _loadItems() async {
    try {
      final data = await _lovService.fetchQcLov(qryType: "QC_BII");
      
      setState(() {
        itemList = data;
        itemDisplayCount = 10;
      });
      debugPrint("✅ Items loaded: ${itemList.length}");
    } catch (e) {
      debugPrint("❌ Error loading items: $e");
      _showError("Failed to load items");
    }
  }

  Future<void> _loadProcess() async {
    if (itemId == null || itemId!.isEmpty) return;

    if (appUser == null || appUser!.isEmpty) {
      debugPrint("⚠️ Cannot load process: appUser is null");
      _showError("User not logged in");
      return;
    }

    setState(() => isLoading = true);

    try {
      debugPrint("🔄 Loading Process for itemId=$itemId, appUser=$appUser");

      final data = await _lovService.fetchQcLov(
        qryType: "QC_PROCESS",
        biiId: itemId,
        appUserId: appUser,
      );

      debugPrint("✅ Process loaded: ${data.length} items");

      setState(() {
        processList = data;
        processDisplayCount = 10;
        processId = null;
        processLabel = null;
        lineList.clear();
        lineId = null;
        lineLabel = null;
      });
    } catch (e) {
      debugPrint("❌ Error loading process: $e");
      _showError("Failed to load process list");
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _loadLine() async {
    if (processId == null || processId!.isEmpty) return;

    if (appUser == null || appUser!.isEmpty) {
      debugPrint("⚠️ Cannot load line: appUser is null");
      _showError("User not logged in");
      return;
    }

    setState(() => isLoading = true);

    try {
      debugPrint("🔄 Loading Line for processId=$processId, appUser=$appUser");

      final data = await _lovService.fetchQcLov(
        qryType: "QC_LINE",
        processId: processId,
        appUserId: appUser,
      );

      debugPrint("✅ Line loaded: ${data.length} items");

      setState(() {
        lineList = data;
        lineDisplayCount = 10;
        lineId = null;
        lineLabel = null;
      });
    } catch (e) {
      debugPrint("❌ Error loading line: $e");
      _showError("Failed to load line list");
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _loadSizes() async {
    if (itemId == null || itemId!.isEmpty) {
      debugPrint("⚠️ Cannot load sizes: itemId is null");
      return;
    }

    setState(() => isLoading = true);

    try {
      debugPrint("🔄 Loading Sizes for itemId=$itemId");

      final data = await _lovService.fetchQcLov(
        qryType: "QC_SIZE",
        biiId: itemId,
      );

      debugPrint("✅ Sizes loaded: ${data.length} items");

      data.sort((a, b) {
        final aSize = num.tryParse(a['label'] ?? '0') ?? 0;
        final bSize = num.tryParse(b['label'] ?? '0') ?? 0;
        return aSize.compareTo(bSize);
      });

      setState(() {
        sizeList = data;
        sizeDisplayCount = 10;
      });
    } catch (e) {
      debugPrint("❌ Error loading sizes: $e");
      _showError("Failed to load sizes");
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _loadJobNo() async {
    if (itemId == null || itemId?.isEmpty == true) {
      debugPrint("⚠️ Cannot load job: itemId is null");
      setState(() => jobNo = "");
      return;
    }

    setState(() => isLoading = true);

    try {
      debugPrint("🔄 Loading Job for itemId=$itemId");

      final data = await _lovService.fetchQcLov(
        qryType: "QC_JOB",
        biiId: itemId,
      );

      debugPrint("✅ Job data loaded: ${data.length} items");
      
      if (data.isNotEmpty) {
        setState(() {
          jobNo = data.first["label"] ?? data.first["JOB_NO"] ?? "";
        });
        
        debugPrint("✅ Job No set to: $jobNo");
      } else {
        debugPrint("⚠️ No job found for itemId=$itemId");
        setState(() => jobNo = "");
      }
    } catch (e) {
      debugPrint("❌ Error loading job: $e");
      setState(() => jobNo = "");
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _loadRemainingQty() async {
    if (itemId == null || itemId!.isEmpty) {
      debugPrint("⚠️ Cannot load remaining qty: itemId is missing");
      setState(() => remainingQty = "0");
      return;
    }
    
    if (processId == null || processId!.isEmpty) {
      debugPrint("⚠️ Cannot load remaining qty: processId is missing");
      setState(() => remainingQty = "0");
      return;
    }
    
    if (sizeId == null || sizeId!.isEmpty) {
      debugPrint("⚠️ Cannot load remaining qty: sizeId is missing");
      setState(() => remainingQty = "0");
      return;
    }

    setState(() => isLoading = true);

    try {
      debugPrint("🔄 Loading Remaining Qty for:");
      debugPrint("   itemId=$itemId");
      debugPrint("   processId=$processId");
      debugPrint("   sizeId=$sizeId");
      
      final remainingQtyStr = await _lovService.fetchRemainingQty(
        biiId: itemId!,
        processId: processId!,
        sizeId: sizeId!,
      );

      debugPrint("✅ API Response: Remaining Qty = $remainingQtyStr");

      setState(() {
        remainingQty = remainingQtyStr;
      });

    } catch (e) {
      debugPrint("❌ Error loading remaining qty: $e");
      setState(() => remainingQty = "0");
    } finally {
      setState(() => isLoading = false);
    }
  }

  // ===================== HELPERS =====================
  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ===================== SAVE =====================
  Future<void> _handleSave() async {
    if (itemId == null || itemId!.isEmpty) {
      _showError("Please select an item");
      return;
    }
    
    if (jobNo == null || jobNo!.isEmpty) {
      _showError("Job No is required. Please reselect the item.");
      return;
    }
    
    if (orderNo == null || orderNo!.isEmpty) {
      _showError("Order No is required. Please reselect the item.");
      return;
    }
    
    if (articleNo == null || articleNo!.isEmpty) {
      _showError("Article No is required. Please reselect the item.");
      return;
    }
    
    if (processId == null || processId!.isEmpty) {
      _showError("Please select a process");
      return;
    }
    
    if (lineId == null || lineId!.isEmpty) {
      _showError("Please select a line");
      return;
    }
    
    if (sizeId == null || sizeId!.isEmpty) {
      _showError("Please select a size");
      return;
    }
    
    if (productionQty == null || productionQty!.isEmpty) {
      _showError("Please enter production quantity");
      return;
    }
    
    final prodQtyValue = int.tryParse(productionQty!) ?? 0;
    if (prodQtyValue <= 0) {
      _showError("Production quantity must be greater than 0");
      return;
    }
    

// ✅ ADD THIS BLOCK 👇
final remainingValue = int.tryParse(remainingQty ?? "0") ?? 0;

if (prodQtyValue > remainingValue) {
  _showError(
    "Production qty cannot be greater than remaining qty ($remainingValue)",
  );
  return;
}


    debugPrint("=== PRODUCTION ENTRY SAVE DATA ===");
    debugPrint("Item ID: $itemId");
    debugPrint("Job No: $jobNo");
    debugPrint("Order No: $orderNo");
    debugPrint("Article No: $articleNo");
    debugPrint("Process ID: $processId");
    debugPrint("Line ID: $lineId");
    debugPrint("Size ID: $sizeId");
    debugPrint("Size: $size");
    debugPrint("Production Qty: $productionQty");
    debugPrint("Bundle Qty: $bundleQty");
    debugPrint("Reject Qty: $rejectQty");
    debugPrint("Flag: $flag");
    debugPrint("App User: $appUser");
    
    setState(() => isLoading = true);
    
    try {
      _showSuccess("Production Entry Saved Successfully");
      
      setState(() {
        productionQty = null;
        productionQtyValue = 0;
        productionQtyController.clear();
        bundleQtyValue = 1;
        bundleQty = "1";
        bundleQtyController.text = "1";
        rejectQtyValue = 0;
        rejectQty = "0";
        rejectQtyController.text = "0";
        flag = "Internal";
      });

    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      
      debugPrint("❌ Error in _handleSave: $e");
      _showError(e.toString());
    } finally {
      setState(() => isLoading = false);
    }
  }

  // ===================== UI =====================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F8),
      body: Stack(
        children: [
          Column(
            children: [
              const TopMenuBar(),
              Expanded(
                child: LayoutBuilder(builder: (context, constraints) {
                  final width = (constraints.maxWidth - 44) / 2;
                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _itemTableDropdown(context, "Item Description/ Color *", itemLabel, itemList, itemDisplayCount,
                            (id, label) async {
                          setState(() {
                            itemId = id;
                            itemLabel = label;

                            selectedItemMap = itemList.firstWhere(
                              (item) => item['id'] == id,
                              orElse: () => {},
                            );

                            orderNo = selectedItemMap?["BPO_PO_NO"] ?? "";
                            articleNo = selectedItemMap?["STYLE_NO"] ?? "";

                            processList.clear();
                            processId = null;
                            processLabel = null;

                            lineList.clear();
                            lineId = null;
                            lineLabel = null;

                            sizeList.clear();
                            sizeId = null;
                            size = null;
                          });

                          await _loadJobNo();
                          _loadProcess();
                          _loadSizes();
                        }, width),

                        _readOnly("Job No", jobNo, width),

                        _readOnly("Order No", orderNo, constraints.maxWidth - 32),

                        _readOnly("Article Name", articleNo, constraints.maxWidth - 32),

                        _modernDropdown(context, "Process Name *", processLabel, processList, processDisplayCount,
                            (id, label) {
                          setState(() {
                            processId = id;
                            processLabel = label;
                            lineList.clear();
                            lineId = null;
                            lineLabel = null;
                          });

                          _loadLine();
                        }, width),

                        _modernDropdown(context, "Line No/Machine No *", lineLabel, lineList, lineDisplayCount,
                            (id, label) {
                          setState(() {
                            lineId = id;
                            lineLabel = label;
                          });
                        }, width),

                        _modernDropdown(context, "Size *", size, sizeList, sizeDisplayCount,
                            (id, label) {
                          setState(() {
                            sizeId = id;
                            size = label;
                          });
                          
                          _loadRemainingQty();
                        }, width),

                        _readOnly("Remaining Qty", remainingQty ?? "0", width),

                        _quantityField("Production Qty *", productionQtyController, (v) {
                          setState(() {
                            productionQtyValue = int.tryParse(v) ?? 0;
                            productionQty = v.isEmpty ? null : v;
                          });
                        }, width),

                        SizedBox(
                          width: width,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Bundle Qty",
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                height: 36,
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: TextField(
                                  controller: bundleQtyController,
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: EdgeInsets.zero,
                                    hintText: "1",
                                    hintStyle: TextStyle(color: Colors.grey),
                                  ),
                                  onChanged: (v) {
                                    setState(() {
                                      bundleQtyValue = int.tryParse(v) ?? 1;
                                      bundleQty = v.isEmpty ? "1" : v;
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(
                          width: width,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Reject Qty",
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                height: 36,
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: TextField(
                                  controller: rejectQtyController,
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: EdgeInsets.zero,
                                    hintText: "0",
                                    hintStyle: TextStyle(color: Colors.grey),
                                  ),
                                  onChanged: (v) {
                                    setState(() {
                                      rejectQtyValue = int.tryParse(v) ?? 0;
                                      rejectQty = v.isEmpty ? "0" : v;
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),

                        _modernDropdown(context, "Flag", flag, flagList, flagList.length,
                            (id, label) {
                          setState(() {
                            flag = id;
                          });
                        }, width),

                        SizedBox(
                          width: constraints.maxWidth - 32,
                          child: ElevatedButton(
                            onPressed: isLoading ? null : _handleSave,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              backgroundColor: const Color(0xFF1A73E8),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              disabledBackgroundColor: Colors.grey,
                              elevation: 2,
                            ),
                            child: Text(
                              isLoading ? "LOADING..." : "SAVE",
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ],
          ),
          
          if (isLoading)
            Container(
              color: Colors.black26,
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1A73E8)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ===================== WIDGET HELPERS =====================

  Widget _quantityField(String label, TextEditingController controller, Function(String) onChanged, double width) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                hintText: "0",
                hintStyle: TextStyle(color: Colors.grey),
              ),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemTableDropdown(BuildContext context, String label, String? value, 
      List<Map<String, String>> list, int displayCount, void Function(String, String) onSelect, double width) {
    return SizedBox(
      width: width,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.black)),
        const SizedBox(height: 4),
        InkWell(
          onTap: () => _itemTableDialog(context, label, list, displayCount, onSelect),
          child: Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white, 
              borderRadius: BorderRadius.circular(8), 
              border: Border.all(color: Colors.grey.shade300), 
              boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 4, offset: Offset(0, 2))]
            ),
            child: Row(children: [
              Expanded(child: Text(value ?? "Select", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87), overflow: TextOverflow.ellipsis)),
              const Icon(Icons.arrow_drop_down, color: Colors.black87, size: 20),
            ]),
          ),
        ),
      ]),
    );
  }

  void _itemTableDialog(BuildContext context, String title,
      List<Map<String, String>> items, int displayCount, void Function(String, String) onSelect) {
    List<Map<String, String>> filtered = List.from(items);
    String currentSearch = "";
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16))
      ),
      builder: (context) {
        return StatefulBuilder(builder: (c, setS) {
          int currentDisplayCount = items.length < 10 ? items.length : 10;
          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              children: [
                Container(
                  width: 40, 
                  height: 4, 
                  decoration: BoxDecoration(
                    color: Colors.grey[300], 
                    borderRadius: BorderRadius.circular(2)
                  )
                ),
                const SizedBox(height: 12),
                
                Text(
                  "Select $title", 
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)
                ),
                const SizedBox(height: 12),
                
                Container(
                  height: 45,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F3F4), 
                    borderRadius: BorderRadius.circular(10), 
                    border: Border.all(color: Colors.grey.shade300)
                  ),
                  child: TextField(
                    autofocus: false,
                    onChanged: (v) => setS(() {
                      currentSearch = v.toLowerCase();
                      filtered = items.where((e) {
                        final itemDesc = (e["label"] ?? "").toLowerCase();
                        final orderNo = (e["BPO_PO_NO"] ?? "").toLowerCase();
                        final articleNo = (e["STYLE_NO"] ?? "").toLowerCase();
                        return itemDesc.contains(currentSearch) || 
                               orderNo.contains(currentSearch) || 
                               articleNo.contains(currentSearch);
                      }).toList();
                      currentDisplayCount = 10;
                    }),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search, color: Colors.black54), 
                      hintText: "Search by color, order no, or article...", 
                      border: InputBorder.none
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A73E8),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                  ),
                  child: Row(
                    children: const [
                      Expanded(
                        flex: 2,
                        child: Text(
                          "Color/Item Desc",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        flex: 1,
                        child: Text(
                          "Order No.",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        flex: 1,
                        child: Text(
                          "Article Name",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
                    ),
                    child: filtered.isEmpty
                        ? const Center(
                            child: Text(
                              "No items found",
                              style: TextStyle(fontSize: 14, color: Colors.grey),
                            ),
                          )
                        : StatefulBuilder(
                            builder: (context, setModalState) {
                              return ListView.builder(
                                itemCount: currentDisplayCount < filtered.length 
                                  ? currentDisplayCount + 1 
                                  : currentDisplayCount,
                                itemBuilder: (_, index) {
                                  if (index == currentDisplayCount && currentDisplayCount < filtered.length) {
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                                      child: Center(
                                        child: ElevatedButton(
                                          onPressed: () {
                                            setModalState(() {
                                              currentDisplayCount += 10;
                                            });
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF1A73E8),
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                            minimumSize: Size.zero,
                                          ),
                                          child: const Text(
                                            'Show More',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }

                                  final item = filtered[index];
                                  final itemDesc = item["label"] ?? "";
                                  final itemId = item["id"] ?? "";
                                  final orderNo = item["BPO_PO_NO"] ?? "-";
                                  final articleNo = item["STYLE_NO"] ?? "-";
                                  
                                  return InkWell(
                                    onTap: () {
                                      onSelect(itemId, itemDesc);
                                      Navigator.pop(context);
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                                      decoration: BoxDecoration(
                                        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              itemDesc,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.black87,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            flex: 1,
                                            child: Text(
                                              orderNo,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                                color: Colors.black87,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            flex: 1,
                                            child: Text(
                                              articleNo,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                                color: Colors.black87,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  void _searchDialog(BuildContext context, String title,
      List<Map<String, String>> items, int displayCount, void Function(String, String) onSelect) {
    List<Map<String, String>> filtered = List.from(items);
    String currentSearch = "";
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        return StatefulBuilder(builder: (c, setS) {
          int currentDisplayCount = items.length < 10 ? items.length : 10;
          return Container(
            height: MediaQuery.of(context).size.height * 0.80,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 12),
                Text("Select $title", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
                const SizedBox(height: 12),
                Container(
                  height: 45,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: const Color(0xFFF1F3F4), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade300)),
                  child: TextField(
                    autofocus: false,
                    onChanged: (v) => setS(() {
                      currentSearch = v;
                      filtered = items.where((e) => e["label"]!.toLowerCase().contains(v.toLowerCase())).toList();
                      currentDisplayCount = 10;
                    }),
                    decoration: const InputDecoration(prefixIcon: Icon(Icons.search, color: Colors.black54), hintText: "Search...", border: InputBorder.none),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.builder(
                    itemCount: currentDisplayCount < filtered.length 
                      ? currentDisplayCount + 1 
                      : currentDisplayCount,
                    itemBuilder: (context, index) {
                      if (index == currentDisplayCount && currentDisplayCount < filtered.length) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Center(
                            child: ElevatedButton(
                              onPressed: () {
                                setS(() {
                                  currentDisplayCount += 10;
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1A73E8),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                minimumSize: Size.zero,
                              ),
                              child: const Text(
                                'Show More',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ),
                        );
                      }

                      final item = filtered[index];
                      return ListTile(
                        title: Text(item["label"]!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        onTap: () {
                          onSelect(item["id"]!, item["label"]!);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  Widget _modernDropdown(BuildContext context, String label, String? value, List<Map<String, String>> list, int displayCount, void Function(String, String) onSelect, double width) {
    return SizedBox(
      width: width,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.black)),
        const SizedBox(height: 4),
        InkWell(
          onTap: () => _searchDialog(context, label, list, displayCount, onSelect),
          child: Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300), boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 4, offset: Offset(0, 2))]),
            child: Row(children: [
              Expanded(child: Text(value ?? "Select", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87), overflow: TextOverflow.ellipsis)),
              const Icon(Icons.arrow_drop_down, color: Colors.black87, size: 20),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _readOnly(String label, String? value, double width) {
    return SizedBox(
      width: width,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.black)),
        const SizedBox(height: 4),
        Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: const Color(0xFFE8EAED),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade400),
          ),
          child: Text(
            value ?? "-",
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ]),
    );
  }
}
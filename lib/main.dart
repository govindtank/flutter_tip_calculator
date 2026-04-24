import 'dart:convert'; // JSON serialization
import 'dart:io'; // For platform detection
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart'; // For sharing history
import 'package:shared_preferences/shared_preferences.dart'; // For persistence
import 'package:intl/intl.dart'; // For formatting
// --- Model for Calculation History ---
class Calculation {
  final double billAmount;
  final double tipPercentage;
  final int peopleCount;
  final double amountPerPerson;
  final DateTime timestamp; // Added date/time stamping

  Calculation({
    required this.billAmount,
    required this.tipPercentage,
    required this.peopleCount,
    required this.amountPerPerson,
    required this.timestamp,
  });
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tip Calculator',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const TipCalculatorScreen(),
    );
  }
}

class TipCalculatorScreen extends StatefulWidget {
  const TipCalculatorScreen({super.key});

  @override
  State<TipCalculatorScreen> createState() => _TipCalculatorScreenState();
}

class _TipCalculatorScreenState extends State<TipCalculatorScreen> {
  // --- Input Controllers and Variables ---
  final TextEditingController _billAmountController = TextEditingController();
  final TextEditingController _tipPercentageController = TextEditingController(text: '20'); 
  final TextEditingController _peopleCountController = TextEditingController(text: '1');

  // State management for history
  List<Calculation> _history = [];
  String _selectedCurrency = 'USD';
  
  // Number formatters
  final currencyFormatter = NumberFormat.currency(locale: 'en_US', symbol: '$');
  
  // --- Calculated Results ---
  double _tipAmount = 0.0;
  double _totalBill = 0.0;
  double _amountPerPerson = 0.0;

  @override
  void initState() {
    super.initState();
    _loadHistoryAndCalculate(); // Load history and run initial calculation
  }

  @override
  void dispose() {
    _billAmountController.dispose();
    _tipPercentageController.dispose();
    _peopleCountController.dispose();
    super.dispose();
  }

  // --- PERSISTENCE & LOGIC CORE ---

  // 1. Loads history from SharedPreferences and runs initial calculation
  Future<void> _loadHistoryAndCalculate() async {
    final prefs = await SharedPreferences.getInstance();
    final storedHistoryJson = prefs.getString('tip_calculator_history');
    
    if (storedHistoryJson != null) {
      try {
        final List<Map<String, dynamic>> historyList = jsonDecode(storedHistoryJson);
        _history = historyList.map((data) => Calculation(
          billAmount: data['bill'].toDouble(),
          tipPercentage: data['tip'].toDouble(),
          peopleCount: data['people'],
          amountPerPerson: data['ppl'].toDouble(),
          timestamp: DateTime.parse(data['timestamp']), // Parse timestamp from storage
        )).toList();
      } catch (e) {
        print('Error loading history: $e');
        _history = []; // Clear history on parse error
      }
    } else {
       _history = []; // Start fresh if no history found
    }

    // Run the calculation after loading state
    _calculateTip(); 
  }

  // 2. Core logic to calculate all values based on current input values
  void _calculateTip() {
    double billAmount = double.tryParse(_billAmountController.text) ?? 0.0;
    double tipPercent = double.tryParse(_tipPercentageController.text) ?? 0.0;
    int peopleCount = int.tryParse(_peopleCountController.text) ?? 1;

    // Calculation logic:
    _tipAmount = billAmount * (tipPercent / 100);
    _totalBill = billAmount + _tipAmount;
    
    if (peopleCount > 0) {
      _amountPerPerson = _totalBill / peopleCount;
    } else {
      _amountPerPerson = 0.0;
    }

    // Update state and save to history
    setState(() {
      final now = DateTime.now();
      final newCalculation = Calculation(
        billAmount: billAmount, 
        tipPercentage: tipPercent, 
        peopleCount: peopleCount, 
        amountPerPerson: _amountPerPerson,
        timestamp: now, // Store timestamp for history
      );
      _history.insert(0, newCalculation);
    });

    // Save the updated history to disk asynchronously
    _saveHistory();
  }

  Future<void> _saveHistory() async {
     final List<Map<String, dynamic>> historyList = _history.map((calc) => {
        'bill': calc.billAmount, 
        'tip': calc.tipPercentage, 
        'people': calc.peopleCount, 
        'ppl': calc.amountPerPerson,
        'timestamp': calc.timestamp.toIso8601String(), // Store timestamp in ISO format
      }).toList();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('tip_calculator_history', jsonEncode(historyList));
  }

  // Function to copy the final amount per person to clipboard
  void _copyAmountToClipboard() async {
    // Use NumberFormat for localized currency string generation
    final formatter = NumberFormat.currency(symbol: '', locale: 'en_US'); 
    final formattedString = formatter.format(_amountPerPerson);
    await Clipboard.setData(ClipboardData(text: formattedString));
    
    // Show snackbar with short animation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Copied to clipboard!'),
        duration: Duration(seconds: 1),
        behavior: MessageBehavior.transient,
      ),
    );
  }

  // Function to share history
  Future<void> _shareHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonHistory = jsonEncode(_history.map((h) => {
      'bill': h.billAmount, 
      'tip': h.tipPercentage, 
      'people': h.peopleCount, 
      'amountPerPerson': h.amountPerPerson,
      'timestamp': h.timestamp.toIso8601String(),
    }));

    if (Platform.isAndroid) {
      // Android - use Share.share
      await Share.share('Tip Calculator History:\n$jsonHistory');
    } else if (Platform.isIOS) {
      // iOS - use ActivityView
      await ActivityView.show(context, jsonHistory);
    } else {
      // Desktop fallback
      await Clipboard.setData(ClipboardData(text: 'Tip Calculator History:\n$jsonHistory'));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('History copied to clipboard. Share manually.')),
      );
    }
  }

  // Function to clear history
  Future<void> _clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('tip_calculator_history');
    
    // Update UI and recalculate
    setState(() {
      _history.clear();
    });
    
    _calculateTip();
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('History cleared.')),
    );
  }

  // Function to show history export options
  Future<void> _showExportOptions() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonHistory = jsonEncode(_history.map((h) => {
      'bill': h.billAmount, 
      'tip': h.tipPercentage, 
      'people': h.peopleCount, 
      'amountPerPerson': h.amountPerPerson,
      'timestamp': h.timestamp.toIso8601String(),
    }));

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export History'),
        content: const Text('Choose how to export your calculations:'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'clipboard'),
            child: const Text('Copy as JSON'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, 'csv'),
            child: const Text('Download CSV'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (result == 'clipboard') {
      await Clipboard.setData(ClipboardData(text: jsonHistory));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('JSON copied to clipboard.')),
      );
    } else if (result == 'csv') {
      // Create CSV content
      final csvHeader = '"Date","Bill Amount","Tip %","People","Amount Per Person"\n';
      final csvContent = '${csvHeader}' + _history.map((h) {
        final date = DateFormat('yyyy-MM-dd HH:mm').format(h.timestamp);
        return '"$date",${h.billAmount},${h.tipPercentage},${h.peopleCount},${h.amountPerPerson}\n';
      }).join();
      
      // Save to a temp file and offer share
      final file = File('${Directory.tmp.path}/tip_history.csv');
      await file.writeAsString(csvContent);
      
      if (Platform.isAndroid) {
        await Share.shareFileX(file.path, mimeType: 'text/csv', name: 'tip_history.csv');
      } else {
        await Clipboard.setData(ClipboardData(text: csvContent));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('CSV copied to clipboard. Share manually.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Set locale for number formatting (Polish/Intl implementation detail)
    return Builder(builder: (context) { 
      return Scaffold(
        appBar: AppBar(
          title: const Text('Tip Calculator'),
          backgroundColor: Theme.of(context).colorScheme.primary,
          elevation: 0,
        ),
        body: Column(
          children: [
            // --- Main Content Area (The calculator form) ---
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    // 1. Currency Selector/Header
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Calculate:', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                          DropdownButton<String>(
                            value: _selectedCurrency,
                            items: ['USD', 'EUR', 'GBP'].map((String value) {
                              return DropdownMenuItem<String>(value: value, child: Text(value));
                            }).toList(),
                            onChanged: (String? newValue) {
                              setState(() {
                                _selectedCurrency = newValue!;
                              });
                            },
                          ),
                        ],
                      ),
                    ),

                    // 2. Input Fields & Quick Selectors
                    Column(
                      children: <Widget>[
                        // Quick Tip Percentage Selector (Phase 3 Feature)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: Wrap(
                            spacing: 8.0,
                            runSpacing: 8.0,
                            children: [
                              Chip(
                                label: Text('10%'),
                                onSelected: (value) {
                                  _tipPercentageController.text = '10';
                                  _calculateTip();
                                },
                                selected: _tipPercentageController.text == '10',
                              ),
                              Chip(
                                label: Text('15%'),
                                onSelected: (value) {
                                  _tipPercentageController.text = '15';
                                  _calculateTip();
                                },
                                selected: _tipPercentageController.text == '15',
                              ),
                              Chip(
                                label: Text('20%', style: const TextStyle(fontWeight: FontWeight.bold)),
                                onSelected: (value) {
                                  _tipPercentageController.text = '20';
                                  _calculateTip();
                                },
                                selected: _tipPercentageController.text == '20',
                                backgroundColor: Colors.teal.withOpacity(0.15),
                              ),
                              Chip(
                                label: Text('25%'),
                                onSelected: (value) {
                                  _tipPercentageController.text = '25';
                                  _calculateTip();
                                },
                                selected: _tipPercentageController.text == '25',
                              ),
                              Chip(
                                label: Text('30%'),
                                onSelected: (value) {
                                  _tipPercentageController.text = '30';
                                  _calculateTip();
                                },
                                selected: _tipPercentageController.text == '30',
                              ),
                            ],
                          ),
                        ),

                        _buildInputField('Bill Amount', _billAmountController),
                        const SizedBox(height: 16.0),
                        _buildInputField('Tip Percentage (%)', _tipPercentageController),
                        const SizedBox(height: 24.0),

                        // People Count Input (Phase 2 Feature)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 32.0),
                          child: _buildInputField('Number of People', _peopleCountController, isInt: true),
                        ),

                        // 3. Results Section (The Core Output)
                        Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.3))
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                // Currency Header
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Results:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                    Text('$_selectedCurrency', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.grey[700])),
                                  ],
                                ),
                                
                                _buildResultRow('Tip Amount:', '$_tipAmount'.replaceAll(r'\\.', ','), isLarge: false),
                                const SizedBox(height: 12.0),

                                Divider(color: Colors.grey[400]),
                                Divider(),

                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                                  child: Text(
                                    'GRAND TOTAL:',
                                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.primary),
                                  ),
                                ),

                                _buildResultRow('TOTAL DUE:', '$_totalBill'.replaceAll(r'\.', ','), isTotal: true),
                                const SizedBox(height: 20.0),
                                
                                // Amount Per Person Box (Phase 2 Feature)
                                Container(
                                  padding: const EdgeInsets.all(15.0),
                                  decoration: BoxDecoration(
                                    color: Colors.teal[50],
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Column(
                                     children: <Widget>[
                                        Text('Split Among:', style: TextStyle(fontSize: 18, color: Colors.grey[700])),
                                        const SizedBox(height: 5),
                                        _buildResultRow('', '$_amountPerPerson'.replaceAll(r'\.', ','), isTotal: true)
                                     ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // --- Action Buttons (Enhanced UX) ---
             Padding(
               padding: const EdgeInsets.fromLTRB(24.0, 10.0, 24.0, 20.0),
               child: Row(
                 mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                 children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _copyAmountToClipboard,
                        icon: const Icon(Icons.content_copy, size: 24),
                        label: const Text('Copy Per Person', style: TextStyle(fontSize: 16)),
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 15.0),
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                     const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _clearHistory,
                        icon: const Icon(Icons.clear_all, size: 24),
                        label: const Text('Clear History', style: TextStyle(fontSize: 16)),
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 15.0),
                          backgroundColor: Colors.red[100],
                          foregroundColor: Colors.red,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                     const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _showExportOptions,
                        icon: const Icon(Icons.share, size: 24),
                        label: const Text('Export', style: TextStyle(fontSize: 16)),
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 15.0),
                          backgroundColor: Colors.blue[100],
                          foregroundColor: Colors.blue,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                 ],
               ),
             ),

          // --- Enhanced History Widget ---
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
              border: Border.all(color: Colors.grey[300]!)
            ),
            child: _history.isEmpty
              ? Center(child: Text('No history yet. Calculate a tip to see it here.', style: TextStyle(color: Colors.grey[600], fontStyle: FontStyle.italic)))
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        children: [
                          Icon(Icons.history, color: Colors.teal[700]),
                          SizedBox(width: 8),
                          Text('History ($_history.length items)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal[900])),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: EdgeInsets.zero, // No extra padding since we have header
                        itemCount: _history.length,
                        itemBuilder: (context, index) {
                          final calc = _history[index];
                          final formatter = NumberFormat('##0.00', 'en_US'); 
                          return ListTile(
                            leading: Icon(Icons.receipt, color: Colors.teal[700], size: 28),
                            title: Text(
                              '${formatter.format(calc.amountPerPerson)} $_selectedCurrency',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Bill: ${calc.billAmount} | Tip: ${calc.tipPercentage}% | People: ${calc.peopleCount}'),
                                Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Text(
                                    DateFormat('MMM dd, yyyy h:mm a').format(calc.timestamp),
                                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
          )
        ],
      );
    });
  }

  // Helper method to build a standardized input field (General Use)
  Widget _buildInputField(String label, TextEditingController controller, {bool isInt = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: TextField(
        controller: controller,
        keyboardType: isInt ? TextInputType.number : TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.attach_money),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
        ),
        onChanged: (value) {
          // Recalculate whenever the text changes
          _calculateTip();
        },
      ),
    );
  }

  // Helper method to build a result display row (Improved with optional params)
  Widget _buildResultRow(String label, String value, {bool isTotal = false, bool isLarge = true}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: isLarge ? 18 : 16, color: Colors.grey[700])),
          // Note: The displayed value here still uses String formatting from the calculation method, but the logic is robust.
          Text(value, style: TextStyle(fontSize: isTotal ? 24 : (isLarge ? 20 : 18), fontWeight: isTotal ? FontWeight.w900 : FontWeight.w600)),
        ],
      ),
    );
  }
}
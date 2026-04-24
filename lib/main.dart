import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart'; // For persistence
import 'package:intl/intl.dart'; // For formatting

// --- Model for Calculation History ---
class Calculation {
  final double billAmount;
  final double tipPercentage;
  final int peopleCount;
  final double amountPerPerson;

  Calculation({required this.billAmount, required this.tipPercentage, required this.peopleCount, required this.amountPerPerson});
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
      // Note: In a real app, we'd use JSON serialization/deserialization for Calculation objects. 
      // For this simulation, we assume successful parsing and cast to the list type.
      final List<Map<String, dynamic>> historyList = jsonDecode(storedHistoryJson);
      _history = historyList.map((data) => Calculation(
        billAmount: data['bill'],
        tipPercentage: data['tip'],
        peopleCount: data['people'],
        amountPerPerson: data['ppl']
      )).toList();
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
      final newCalculation = Calculation(
        billAmount: billAmount, 
        tipPercentage: tipPercent, 
        peopleCount: peopleCount, 
        amountPerPerson: _amountPerPerson
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
        'ppl': calc.amountPerPerson
      }).toList();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('tip_calculator_history', jsonEncode(historyList));
  }


  // Function to copy the final amount per person to clipboard
  void _copyAmountToClipboard() async {
    // Use NumberFormat for localized currency string generation
    final formatter = NumberFormat.currency(locale: 'en-US', symbol: ''); 
    final formattedString = formatter.format(_amountPerPerson);
    await Clipboard.setData(ClipboardData(text: '$formattedString $_selectedCurrency'));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied! Amount saved to clipboard.')),
    );
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

                    // 2. Input Fields
                    Column(
                      children: <Widget>[
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
                              children: <Widget>[
                                _buildResultRow('Tip Amount:', '$_tipAmount'.replaceAll(r'\.', ',')),
                                const SizedBox(height: 15.0),

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

            // --- Action Buttons (Polish/UX improvement) ---
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
                         onPressed: () {
                             // Clear all inputs and history for a fresh start
                             _billAmountController.clear();
                             _tipPercentageController.text = '20';
                             _peopleCountController.text = '1';
                             setState(() { _history.clear(); });
                             _calculateTip(); // Recalculate with default values
                         },
                         icon: const Icon(Icons.refresh, size: 24),
                         label: const Text('Clear All', style: TextStyle(fontSize: 16)),
                         style: ElevatedButton.styleFrom(
                           padding: EdgeInsets.symmetric(vertical: 15.0),
                           backgroundColor: Colors.grey[300],
                           foregroundColor: Colors.black,
                           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                         ),
                       ),
                     ),
                 ],
               ),
             ),

          // --- History Widget (Advanced Feature) ---
           Padding(
             padding: const EdgeInsets.fromLTRB(24.0, 10.0, 24.0, 20.0),
             child: Text('History', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
           ),
          Container(
            height: 150,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.vertical(top: Radius.circular(15))
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _history.length,
              itemBuilder: (context, index) {
                final calc = _history[index];
                // Use NumberFormat for consistent display in the history list too
                final formatter = NumberFormat('##0.00', 'en_US'); 
                return ListTile(
                  leading: const Icon(Icons.receipt_hoarder),
                  title: Text('${formatter.format(calc.amountPerPerson)} $_selectedCurrency'),
                  subtitle: Text('Bill: ${calc.billAmount} | Tip: ${calc.tipPercentage}% | People: ${calc.peopleCount}'),
                  trailing: Text(DateFormat('MMM dd, yyyy').format(DateTime.now()), style: TextStyle(fontSize: 12)), // Using current time as a placeholder for saved date
                );
              },
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

  // Helper method to build a result display row
  Widget _buildResultRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0)
      ..child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 18, color: Colors.grey[700])),
          // Note: The displayed value here still uses String formatting from the calculation method, but the logic is robust.
          Text(value, style: TextStyle(fontSize: isTotal ? 24 : 22, fontWeight: isTotal ? FontWeight.w900 : FontWeight.bold)),
        ],
      ),
    );
  }
}
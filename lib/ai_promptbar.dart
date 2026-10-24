import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'models/transaction.dart';
import 'package:flutter/services.dart' show rootBundle;

class AiPromptbar extends StatefulWidget {
  final Function(TransactionModel) onTransactionAdded;

  const AiPromptbar({super.key, required this.onTransactionAdded});

  @override
  _AIPromptBarState createState() => _AIPromptBarState();
}

class _AIPromptBarState extends State<AiPromptbar> {
  final TextEditingController _controller = TextEditingController();
  bool _isLoading = false;

  Future<String> getApiKey() async {
    try {
      String key = await rootBundle.loadString('config.txt');
      return key.trim();
    } catch (e) {
      print('Error loading config: $e');
      return '';
    }
  }

  void _processInput() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    try {
      String extractedKey = await getApiKey();
      
      if (extractedKey.isEmpty) {
        throw Exception("API key loaded from config.txt is empty.");
      }

      final model = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: extractedKey,
      );

      final prompt = '''
      Extract data from: "$text"
      Return ONLY a valid JSON object. Do not include any markdown formatting or preamble.
      Required Keys:
      "amount": (number),
      "currency": (3-letter ISO code, e.g. USD, EUR. default to "USD" if unclear),
      "type": ("income" or "expense"),
      "category": (string),
      "description": (string)
      ''';

      final response = await model.generateContent([Content.text(prompt)]);
      final responseText = response.text ?? '';

      final cleanJson = responseText
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();

      final Map<String, dynamic> parsedData = json.decode(cleanJson);

      final newTx = TransactionModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        description: parsedData['description'] ?? 'No description',
        category: parsedData['category'] ?? 'General',
        type: parsedData['type'] ?? 'expense',
        amount: (parsedData['amount'] ?? 0).toDouble(),
        currency: parsedData['currency'] ?? 'USD',
        timestamp: DateTime.now(),
      );

      widget.onTransactionAdded(newTx);
      _controller.clear();
    } catch (e) {
      print('Detailed Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Failed to process transaction.')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: TextField(
                controller: _controller,
                onSubmitted: (_) => _processInput(),
                decoration: const InputDecoration(
                  hintText: 'e.g., Spent 15 USD on coffee',
                  hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            height: 48,
            width: 48,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _processInput,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                elevation: 0,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
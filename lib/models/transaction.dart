class TransactionModel {
  final String id;
  final String description;
  final String category;
  final String type;
  final double amount;
  final String currency;
  final double? amountUsd;
  final DateTime? timestamp;

  TransactionModel({
    required this.id,
    required this.description,
    required this.category,
    required this.type,
    required this.amount,
    required this.currency,
    this.amountUsd,
    this.timestamp,
  });
}
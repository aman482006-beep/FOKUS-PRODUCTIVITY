/// A portfolio asset representing a transaction / holding in the portfolio tracker.
class PortfolioAsset {
  final String id;
  final String name;
  final String category; // 'Equity (Stocks)', 'Equity Options', 'Futures & Derivatives', 'Forex / Currencies', 'Bonds & Fixed Income', 'Mutual Funds & ETFs', 'Cryptocurrency', 'Real Estate & REITs', 'Commodities (Gold, Oil, etc.)', 'Cash & Cash Equivalents', 'Alternative Assets (Art, Collectibles)'
  final double buyPrice;
  final double quantity;
  final double currentPrice;
  final DateTime purchaseDate;
  final bool isSold;
  final double? sellPrice;
  final DateTime? sellDate;
  final String notes;

  PortfolioAsset({
    required this.id,
    required this.name,
    required this.category,
    required this.buyPrice,
    required this.quantity,
    required this.currentPrice,
    required this.purchaseDate,
    this.isSold = false,
    this.sellPrice,
    this.sellDate,
    this.notes = '',
  });

  /// The amount of capital currently invested (active positions only)
  double get invested => isSold ? 0.0 : buyPrice * quantity;

  /// The current market value of the asset (active positions only)
  double get currentValue => isSold ? 0.0 : currentPrice * quantity;

  /// Total profit or loss realized or unrealized
  double get profitLoss => isSold
      ? ((sellPrice ?? buyPrice) - buyPrice) * quantity
      : (currentPrice - buyPrice) * quantity;

  /// Realized profit or loss (closed positions only)
  double get realised => isSold ? ((sellPrice ?? buyPrice) - buyPrice) * quantity : 0.0;

  /// Paper profit or loss (active positions only)
  double get unrealised => isSold ? 0.0 : (currentPrice - buyPrice) * quantity;

  /// The profit or loss percentage w.r.t the invested capital
  double get profitLossPercent => invested > 0 ? (profitLoss / invested) * 100 : 0.0;

  /// Copy helper for editing assets
  PortfolioAsset copyWith({
    String? id,
    String? name,
    String? category,
    double? buyPrice,
    double? quantity,
    double? currentPrice,
    DateTime? purchaseDate,
    bool? isSold,
    double? sellPrice,
    DateTime? sellDate,
    String? notes,
  }) {
    return PortfolioAsset(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      buyPrice: buyPrice ?? this.buyPrice,
      quantity: quantity ?? this.quantity,
      currentPrice: currentPrice ?? this.currentPrice,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      isSold: isSold ?? this.isSold,
      sellPrice: sellPrice ?? this.sellPrice,
      sellDate: sellDate ?? this.sellDate,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'buyPrice': buyPrice,
        'quantity': quantity,
        'currentPrice': currentPrice,
        'purchaseDate': purchaseDate.toIso8601String(),
        'isSold': isSold,
        'sellPrice': sellPrice,
        'sellDate': sellDate?.toIso8601String(),
        'notes': notes,
      };

  factory PortfolioAsset.fromJson(Map<String, dynamic> json) => PortfolioAsset(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        category: json['category'] as String? ?? 'Equity (Stocks)',
        buyPrice: (json['buyPrice'] as num?)?.toDouble() ?? 0.0,
        quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
        currentPrice: (json['currentPrice'] as num?)?.toDouble() ?? 0.0,
        purchaseDate: json['purchaseDate'] != null
            ? DateTime.parse(json['purchaseDate'] as String)
            : DateTime.now(),
        isSold: json['isSold'] as bool? ?? false,
        sellPrice: (json['sellPrice'] as num?)?.toDouble(),
        sellDate: json['sellDate'] != null
            ? DateTime.parse(json['sellDate'] as String)
            : null,
        notes: json['notes'] as String? ?? '',
      );
}

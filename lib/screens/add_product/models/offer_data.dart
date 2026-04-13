class OfferData {
  final double? offerPrice;
  final String? offerStartDate;
  final String? offerEndDate;
  final bool offerEnabled;

  const OfferData({
    required this.offerPrice,
    required this.offerStartDate,
    required this.offerEndDate,
    required this.offerEnabled,
  });

  const OfferData.disabled()
    : offerPrice = null,
      offerStartDate = null,
      offerEndDate = null,
      offerEnabled = false;
}

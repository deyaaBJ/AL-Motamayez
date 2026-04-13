import '../models/offer_data.dart';
import 'date_helper.dart';

OfferData buildOfferData({
  required bool enabled,
  required String priceText,
  required DateTime? startDate,
  required DateTime? endDate,
  required double regularPrice,
}) {
  if (!enabled) {
    return const OfferData.disabled();
  }

  final offerPrice = double.tryParse(priceText.trim());
  if (offerPrice == null || offerPrice <= 0) {
    throw Exception('يرجى إدخال سعر عرض صحيح');
  }
  if (regularPrice <= 0) {
    throw Exception('يرجى إدخال السعر الأصلي أولاً');
  }
  if (offerPrice >= regularPrice) {
    throw Exception('سعر العرض يجب أن يكون أقل من السعر الأصلي');
  }
  if (startDate == null || endDate == null) {
    throw Exception('يرجى اختيار تاريخ بداية ونهاية للعرض');
  }
  if (endDate.isBefore(startDate)) {
    throw Exception('تاريخ نهاية العرض يجب أن يكون بعد تاريخ البداية');
  }

  return OfferData(
    offerPrice: offerPrice,
    offerStartDate: formatDateForStorage(startDate),
    offerEndDate: formatDateForStorage(endDate),
    offerEnabled: true,
  );
}

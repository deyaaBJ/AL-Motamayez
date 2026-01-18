import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:motamayez/components/base_layout.dart';
import 'package:motamayez/providers/auth_provider.dart';
import 'package:motamayez/providers/product_provider.dart';
import 'package:motamayez/providers/sales_provider.dart';
import 'package:motamayez/providers/settings_provider.dart';
import 'package:motamayez/widgets/PosCartAnimation.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  @override
  void initState() {
    super.initState();

    Provider.of<SalesProvider>(context, listen: false).loadTodaySalesCount();

    Provider.of<ProductProvider>(context, listen: false).loadTotalProducts();

    Future.microtask(() async {
      final settings = Provider.of<SettingsProvider>(context, listen: false);

      await settings.loadSettings();

      Provider.of<ProductProvider>(
        context,
        listen: false,
      ).loadStockCounts(settings.lowStockThreshold);
    });
  }

  @override
  Widget build(BuildContext context) {
    final role = Provider.of<AuthProvider>(context).role;

    return Directionality(
      textDirection: TextDirection.rtl, // 🔥 تحويل كل الواجهة للعربي
      child: BaseLayout(
        currentPage: 'home',
        showAppBar: false,
        child: _buildMainContent(context, role),
      ),
    );
  }

  Widget _buildMainContent(BuildContext context, String? role) {
    final salesProvider = Provider.of<SalesProvider>(context);
    final productProvider = Provider.of<ProductProvider>(context);
    Provider.of<SettingsProvider>(context);

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 25),
          color: Colors.transparent,
          child: Row(
            // لجعل المحاذاة صحيحة حسب اللغة (عربي/إنجليزي)
            textDirection: TextDirection.rtl,
            children: [
              Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start, // تعديل المحاذاة لتناسب العربية
                children: [
                  const Text(
                    "مرحباً بك مرة أخرى،",
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    "لوحة التحكم",
                    style: TextStyle(
                      color: Colors.grey.shade800,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const Spacer(), // يدفع العنصر التالي لأقصى الجهة الأخرى
              // 👇 هنا الأنيميشن الجديد بدلاً من أيقونة الإشعارات
              const BeautifulCartAnimation(color: Color(0xFF4A1C6D)),
            ],
          ),
        ),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end, // كل شيء على اليمين
              children: [
                // بطاقة الهيرو
                Container(
                  width: double.infinity,
                  height: 200,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8B5FBF), Color(0xFF4A1C6D)],
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                    ),
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6A3093).withOpacity(0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        left: -30,
                        top: -20,
                        child: Icon(
                          Icons.shopping_cart,
                          size: 150,
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(30),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start, // عربي
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              "جاهز للبيع؟",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              "ابدأ عملية بيع جديدة بسرعة وسهولة",
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                            const Spacer(),
                            ElevatedButton.icon(
                              onPressed:
                                  () => Navigator.pushNamed(context, '/pos'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFF4A1C6D),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 20,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              icon: const Icon(Icons.add),
                              label: const Text("فاتورة جديدة"),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // نظرة عامة اليوم
                const Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    "نظرة عامة اليوم",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),

                const SizedBox(height: 15),

                // الصف الأول من الكروت
                Row(
                  textDirection: TextDirection.rtl, // كل شيء من اليمين
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        "المبيعات",
                        "${salesProvider.todaySalesCount}",
                        Icons.receipt_long,
                        Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: _buildStatCard(
                        "المنتجات",
                        "${productProvider.totalProducts}",
                        Icons.inventory,
                        Colors.blue,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // الصف الثاني من الكروت
                Row(
                  textDirection: TextDirection.rtl, // كل شيء من اليمين
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        "المنتجات المنخفضة",
                        "${productProvider.lowStockCount}",
                        Icons.warning,
                        Colors.amber,
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: _buildStatCard(
                        "المنتجات غير المتوفرة",
                        "${productProvider.outOfStockCount}",
                        Icons.cancel,
                        Colors.red,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // 🔹 الأيقونة – أقصى اليمين (لأن الاتجاه RTL)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),

            const SizedBox(width: 15),

            // 🔥 النص – بجوار الأيقونة على اليسار (لأن الاتجاه RTL)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Cairo',
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    value,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Cairo',
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

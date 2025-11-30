import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopmate/components/base_layout.dart';
import 'package:shopmate/providers/auth_provider.dart';
import 'package:shopmate/providers/settings_provider.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () =>
          Provider.of<SettingsProvider>(context, listen: false).loadSettings(),
    );
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
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 25),
          color: Colors.transparent,
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.end, // 🔥 النص لليمين
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
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.notifications_none,
                  color: Color(0xFF6A3093),
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end, // 🔥 محتوى يمين
              children: [
                // بطاقة الهيرو
                Container(
                  width: double.infinity,
                  height: 200,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8B5FBF), Color(0xFF4A1C6D)],
                      begin: Alignment.topRight, // 🔥 عربي
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
                        left: -20, // 🔥 جهة اليسار بالعربي
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
                          crossAxisAlignment: CrossAxisAlignment.end, // عربي
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
                                  vertical: 12,
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

                const SizedBox(height: 30),

                const Text(
                  "نظرة عامة اليوم",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 15),

                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        "المبيعات",
                        "250 د.أ",
                        Icons.monetization_on,
                        Colors.green,
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: _buildStatCard(
                        "الطلبات",
                        "12",
                        Icons.receipt_long,
                        Colors.orange,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        "المنتجات",
                        "1,204",
                        Icons.inventory,
                        Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 15),
                    const Spacer(),
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
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        textDirection: TextDirection.rtl, // 🔥 أيقونة يمين ونص يسار
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                title,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

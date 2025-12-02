import 'package:flutter/material.dart';
import 'dart:math' as math;

class BeautifulCartAnimation extends StatefulWidget {
  final Color color;
  const BeautifulCartAnimation({Key? key, required this.color})
    : super(key: key);

  @override
  State<BeautifulCartAnimation> createState() => _BeautifulCartAnimationState();
}

class _BeautifulCartAnimationState extends State<BeautifulCartAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  List<Product> products = [];
  bool isCartFull = false;
  int productCount = 0;
  double previousProgress = 0.0;
  bool shouldReset = false;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 6000),
          )
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) {
              // إعادة التعيين عند اكتمال الدورة
              resetProducts();
            }
          })
          ..repeat();

    // إضافة بعض المنتجات بعد فترة
    addDelayedProducts();
  }

  void addDelayedProducts() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          if (products.length < 3) {
            products.add(
              Product(
                id: products.length + 1,
                icon: Icons.shopping_bag,
                color: Colors.blue,
                name: "حقيبة",
              ),
            );
            productCount = products.length;
            isCartFull = products.length >= 3;
          }
        });
      }
    });

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          if (products.length < 3) {
            products.add(
              Product(
                id: products.length + 1,
                icon: Icons.local_drink,
                color: Colors.green,
                name: "مشروب",
              ),
            );
            productCount = products.length;
            isCartFull = products.length >= 3;
          }
        });
      }
    });

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          if (products.length < 3) {
            products.add(
              Product(
                id: products.length + 1,
                icon: Icons.cake,
                color: Colors.orange,
                name: "كيك",
              ),
            );
            productCount = products.length;
            isCartFull = products.length >= 3;
          }
        });
      }
    });
  }

  void resetProducts() {
    if (mounted) {
      setState(() {
        products.clear();
        productCount = 0;
        isCartFull = false;

        // إضافة المنتجات مرة أخرى بعد التحديث
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            addDelayedProducts();
          }
        });
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      height: 70,
      decoration: BoxDecoration(
        // color: Colors.white,
        borderRadius: BorderRadius.circular(35),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Stack(
        children: [
          // الخط الأرضي
          Positioned(
            bottom: 15,
            left: 20,
            right: 20,
            child: Container(
              height: 3,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // العربة المتحركة
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final double progress = _controller.value;

              // الكشف عن إعادة التعيين عندما يعود التقدم إلى الصفر
              if (previousProgress > 0.95 && progress < 0.05) {
                Future.microtask(() {
                  if (mounted && !shouldReset) {
                    shouldReset = true;
                    resetProducts();
                  }
                });
              } else if (progress > 0.1) {
                shouldReset = false;
              }

              previousProgress = progress;

              // حركة بسيطة من اليسار إلى اليمين
              final double xPos = 30 + (260 * progress);

              // حركة خفيفة للأعلى والأسفل
              final double yPos = 10 * math.sin(progress * 4 * math.pi);

              // دوران خفيف
              final double rotation = 0.1 * math.sin(progress * 8 * math.pi);

              return Positioned(
                left: xPos,
                top: 15 + yPos,
                child: Transform.rotate(
                  angle: rotation,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        // عند الضغط على العربة، نضيف منتج جديد
                        if (products.length < 5) {
                          final newProduct = Product(
                            id: products.length + 1,
                            icon: Icons.card_giftcard,
                            color: Colors.purple,
                            name: "هدية",
                          );
                          products.add(newProduct);
                          productCount = products.length;
                          if (products.length >= 3) {
                            isCartFull = true;
                          }
                        }
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: widget.color,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: widget.color.withOpacity(0.5),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          const Icon(
                            Icons.shopping_cart_rounded,
                            color: Colors.white,
                            size: 28,
                          ),

                          // عداد المنتجات
                          if (productCount > 0)
                            Positioned(
                              top: -5,
                              right: 2,
                              child: Container(
                                padding: const EdgeInsets.all(5),
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.red,
                                ),
                                child: Text(
                                  '$productCount',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          // المنتجات المضافة
          ...products.asMap().entries.map((entry) {
            final index = entry.key;
            final product = entry.value;

            return Positioned(
              right: 20 + (index * 25),
              top: 10,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: product.color, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: product.color.withOpacity(0.3),
                      blurRadius: 5,
                    ),
                  ],
                ),
                child: Icon(product.icon, color: product.color, size: 18),
              ),
            );
          }),

          // نص توجيهي
          Positioned(
            left: 20,
            top: 25,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final double opacity =
                    0.7 + 0.3 * math.sin(_controller.value * 4 * math.pi);
                return Opacity(
                  opacity: opacity,
                  child: Text(
                    isCartFull ? "السلة ممتلئة!" : "انقر لإضافة منتج",
                    style: TextStyle(
                      color: widget.color,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class Product {
  final int id;
  final IconData icon;
  final Color color;
  final String name;

  Product({
    required this.id,
    required this.icon,
    required this.color,
    required this.name,
  });
}

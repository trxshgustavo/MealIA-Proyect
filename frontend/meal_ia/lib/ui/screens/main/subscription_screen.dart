import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/app_state.dart';
import '../theme/app_colors.dart';
import '../../../utils/screen_utils.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isAnnual = false;
  bool _isLoading = true;
  bool _isPurchasing = false;

  // In-App Purchase
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;
  List<ProductDetails> _products = [];
  
  // Define tus IDs de producto que debes crear en Play Store / App Store
  final Set<String> _kIds = <String>{'premium_monthly', 'premium_yearly'};

  // Colores locales
  final Color activeColor = AppColors.buttonDark;
  final Color darkText = AppColors.textDark;

  final List<Map<String, dynamic>> _slides = [
    {
      "title": "Libertad en tu cocina",
      "desc": "Genera menús ilimitados adaptados a lo que tienes en tu refrigerador.",
      "icon": Icons.kitchen_rounded,
    },
    {
      "title": "Nutrición Inteligente",
      "desc": "Seguimiento automático de macros y calorías para cumplir tus metas.",
      "icon": Icons.pie_chart_rounded,
    },
    {
      "title": "Modo Chef Pro",
      "desc": "Guarda recetas, crea listas de compras y cocina sin publicidad.",
      "icon": Icons.star_rounded,
    },
  ];

  @override
  void initState() {
    super.initState();
    final purchaseUpdated = _inAppPurchase.purchaseStream;
    _subscription = purchaseUpdated.listen((purchaseDetailsList) {
      _listenToPurchaseUpdated(purchaseDetailsList);
    }, onDone: () {
      _subscription.cancel();
    }, onError: (error) {
      // Manejar error en el stream
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error en la conexión con la tienda: $error"), backgroundColor: Colors.red),
        );
      }
    });

    _initStoreInfo();
  }

  Future<void> _initStoreInfo() async {
    final bool isAvailable = await _inAppPurchase.isAvailable();
    if (!isAvailable) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    ProductDetailsResponse productDetailResponse = await _inAppPurchase.queryProductDetails(_kIds);
    if (productDetailResponse.error != null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _products = productDetailResponse.productDetails;
      _isLoading = false;
    });
  }

  void _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) async {
    for (var purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        setState(() {
          _isPurchasing = true;
        });
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          setState(() {
            _isPurchasing = false;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Error al procesar el pago: ${purchaseDetails.error?.message}"), backgroundColor: Colors.red),
            );
          }
        } else if (purchaseDetails.status == PurchaseStatus.purchased || purchaseDetails.status == PurchaseStatus.restored) {
          // Pago exitoso en la tienda, actualizar backend
          bool success = await _verifyPurchaseOnBackend(purchaseDetails);
          if (success && mounted) {
            Navigator.pop(context); // Cerrar pantalla de suscripción
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("¡Suscripción Activada Exitosamente!"), backgroundColor: Colors.green),
            );
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Pago exitoso pero hubo un problema validando la cuenta."), backgroundColor: Colors.orange),
              );
            }
          }
          setState(() {
            _isPurchasing = false;
          });
        }
        
        // Es necesario completar la compra para que no quede bloqueada en la tienda
        if (purchaseDetails.pendingCompletePurchase) {
          await _inAppPurchase.completePurchase(purchaseDetails);
        }
      }
    }
  }

  Future<bool> _verifyPurchaseOnBackend(PurchaseDetails purchaseDetails) async {
    final appState = Provider.of<AppState>(context, listen: false);
    // Idealmente aquí enviarías purchaseDetails.verificationData al backend para validarlo con Google/Apple
    // Por ahora llamamos al endpoint existente para otorgar premium
    return await appState.upgradeSubscription();
  }

  @override
  void dispose() {
    _subscription.cancel();
    _pageController.dispose();
    super.dispose();
  }

  ProductDetails? _getSelectedProduct() {
    final targetId = _isAnnual ? 'premium_yearly' : 'premium_monthly';
    try {
      return _products.firstWhere((p) => p.id == targetId);
    } catch (e) {
      return null;
    }
  }

  void _startPurchase() {
    final product = _getSelectedProduct();
    if (product == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Producto no disponible en la tienda actualmente."), backgroundColor: Colors.orange),
      );
      return;
    }

    final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);
    
    // Subscriptions in App Store and Google Play are handled this way in in_app_purchase
    _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
  }

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = ScreenUtils.getResponsiveHorizontalPadding(context);
    final verticalPadding = ScreenUtils.getResponsiveVerticalPadding(context);

    // Obtener información del producto de la tienda, o mostrar un fallback
    final ProductDetails? product = _getSelectedProduct();
    final String price = product?.price ?? (_isAnnual ? "\$25.000" : "\$2.500");
    final String period = _isAnnual ? "/ año" : "/ mes";
    final String savings = _isAnnual ? "¡Ahorras un 17%!" : "Cancela cuando quieras";

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            Column(
              children: [
                // --- 1. SECCIÓN SUPERIOR (CARRUSEL) ---
                Expanded(
                  child: Stack(
                    children: [
                      Positioned(
                        top: -60.h,
                        right: -80.w,
                        child: Container(
                          width: 200.w,
                          height: 200.w,
                          decoration: BoxDecoration(
                            color: activeColor.withValues(alpha: 0.05),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      Column(
                        children: [
                          Expanded(
                            child: PageView.builder(
                              controller: _pageController,
                              onPageChanged: (index) => setState(() => _currentPage = index),
                              itemCount: _slides.length,
                              itemBuilder: (context, index) => _buildSlide(_slides[index]),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.only(bottom: 20.0.h),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                _slides.length,
                                (index) => AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  margin: EdgeInsets.symmetric(horizontal: 4.w),
                                  height: 6.h,
                                  width: _currentPage == index ? 24.w : 6.w,
                                  decoration: BoxDecoration(
                                    color: _currentPage == index ? activeColor : Colors.grey[300],
                                    borderRadius: BorderRadius.circular(3.r),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // --- 2. SECCIÓN INFERIOR (PAGO) ---
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.fromLTRB(horizontalPadding, verticalPadding, horizontalPadding, verticalPadding),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(30.r)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 30.r,
                        offset: Offset(0, -10.h),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildPricingToggle(),
                      SizedBox(height: 20.h),
                      
                      if (_isLoading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: CircularProgressIndicator(),
                        )
                      else
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: Column(
                            key: ValueKey<bool>(_isAnnual),
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    price,
                                    style: TextStyle(
                                      fontSize: 24.sp,
                                      fontWeight: FontWeight.w900,
                                      color: darkText,
                                      letterSpacing: -1,
                                    ),
                                  ),
                                  SizedBox(width: 4.w),
                                  Text(
                                    period,
                                    style: TextStyle(
                                      fontSize: 14.sp,
                                      color: Colors.grey[500],
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 5.h),
                              Text(
                                savings,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  color: _isAnnual ? Colors.green[600] : Colors.grey[400],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),

                      SizedBox(height: 20.h),

                      // Botón de Acción
                      SizedBox(
                        width: double.infinity,
                        height: 50.h,
                        child: ElevatedButton(
                          onPressed: (_isLoading || _isPurchasing) ? null : _startPurchase,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: activeColor,
                            elevation: 8,
                            shadowColor: activeColor.withValues(alpha: 0.3),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16.r),
                            ),
                          ),
                          child: _isPurchasing
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : Text(
                                  "Comenzar Ahora",
                                  style: TextStyle(
                                    fontSize: 15.sp,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),

                      SizedBox(height: 10.h),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.grey[500],
                        ),
                        child: Text(
                          "Seguir con el plan actual",
                          style: TextStyle(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey,
                            decorationColor: Colors.grey,
                          ),
                        ),
                      ),
                      
                      // Restore Purchases button (Apple requirement)
                      if (Platform.isIOS) ...[
                        SizedBox(height: 5.h),
                        TextButton(
                          onPressed: _isLoading || _isPurchasing ? null : () => _inAppPurchase.restorePurchases(),
                          child: Text(
                            "Restaurar compras",
                            style: TextStyle(
                              fontSize: 13.sp,
                              color: Colors.grey[600],
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ]
                    ],
                  ),
                ),
              ],
            ),
            
            // Loading Overlay si está procesando la compra
            if (_isPurchasing)
              Container(
                color: Colors.black.withValues(alpha: 0.3),
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPricingToggle() {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildToggleButton("Mensual", !_isAnnual),
          _buildToggleButton("Anual", _isAnnual),
        ],
      ),
    );
  }

  Widget _buildToggleButton(String text, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isAnnual = text == "Anual";
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10.r),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4.r,
                  ),
                ]
              : [],
        ),
        child: Text(
          text,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isSelected ? AppColors.textDark : Colors.grey[500],
          ),
        ),
      ),
    );
  }

  Widget _buildSlide(Map<String, dynamic> slide) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 40.w),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(25.w),
            decoration: BoxDecoration(
              color: activeColor.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(slide['icon'], size: 50.sp, color: activeColor),
          ),
          SizedBox(height: 12.h),
          Text(
            slide['title'],
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w900,
              color: darkText,
              letterSpacing: -0.5,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            slide['desc'],
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.sp,
              color: Colors.grey[600],
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

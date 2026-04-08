import 'dart:async';

import 'package:flutter/material.dart';
import 'package:motamayez/screens/auth/login.dart';
import 'package:motamayez/services/activation_service.dart';
import 'package:motamayez/widgets/whatsapp_support_button.dart';

class ActivationPage extends StatefulWidget {
  const ActivationPage({super.key});

  @override
  State<ActivationPage> createState() => _ActivationPageState();
}

class _ActivationPageState extends State<ActivationPage> {
  final TextEditingController _codeController = TextEditingController();
  final ActivationService _activationService = ActivationService();

  bool _loading = false;
  bool _sendingRequest = false;
  bool _checkingStatus = false;
  String? _error;
  String? _info;
  String? _requestId;
  String _requestStatus = 'idle';
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    _initializeActivationState();
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _initializeActivationState() async {
    final savedRequest = await _activationService.getSavedPendingRequest();

    if (!mounted) return;

    setState(() {
      _requestId = savedRequest?['requestId']?.toString();
      _requestStatus = savedRequest?['status']?.toString() ?? 'idle';

      final savedCode = savedRequest?['assignedCode']?.toString();
      if (savedCode != null && savedCode.isNotEmpty) {
        _codeController.text = savedCode;
      }
    });

    if (_requestId != null) {
      await _refreshRequestStatus(showLoader: false);
      _startStatusPolling();
    }
  }

  void _startStatusPolling() {
    _statusTimer?.cancel();

    if (_requestId == null ||
        _requestStatus == 'completed' ||
        _requestStatus == 'rejected') {
      return;
    }

    _statusTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _refreshRequestStatus(showLoader: false);
    });
  }

  Future<void> _sendRequest() async {
    setState(() {
      _sendingRequest = true;
      _error = null;
      _info = null;
    });

    final result = await _activationService.createActivationRequest();

    if (!mounted) return;

    setState(() {
      _sendingRequest = false;
    });

    if (result['success'] != true) {
      setState(() {
        _error = result['message']?.toString() ?? 'فشل إرسال طلب التفعيل';
      });
      return;
    }

    final status = result['status']?.toString() ?? 'pending';
    final assignedCode = result['assignedCode']?.toString();

    setState(() {
      _requestId = result['requestId']?.toString() ?? _requestId;
      _requestStatus = status;
      _info = result['message']?.toString() ?? 'تم إرسال طلب التفعيل بنجاح';

      if (assignedCode != null && assignedCode.isNotEmpty) {
        _codeController.text = assignedCode;
      }
    });

    if (status == 'already_activated') {
      setState(() {
        _info = 'تم التفعيل من قبل';
      });
      return;
    }

    _startStatusPolling();
  }

  Future<void> _refreshRequestStatus({bool showLoader = true}) async {
    if (_requestId == null) return;

    if (showLoader) {
      setState(() {
        _checkingStatus = true;
        _error = null;
      });
    }

    final result = await _activationService.getRequestStatus(
      requestId: _requestId,
    );

    if (!mounted) return;

    if (showLoader) {
      setState(() {
        _checkingStatus = false;
      });
    }

    if (result['success'] != true) {
      setState(() {
        _error = result['message']?.toString() ?? 'تعذر التحقق من حالة الطلب';
      });
      return;
    }

    final status = result['status']?.toString() ?? 'pending';
    final assignedCode = result['assignedCode']?.toString();
    final rejectionReason = result['rejectionReason']?.toString();

    setState(() {
      _requestStatus = status;

      if (assignedCode != null && assignedCode.isNotEmpty) {
        _codeController.text = assignedCode;
      }

      if (status == 'approved') {
        _info =
            'تمت الموافقة على الطلب. الآن يمكنك إدخال الكود والضغط على تفعيل.';
      } else if (status == 'pending') {
        _info = 'طلب التفعيل ما زال بانتظار الموافقة.';
      } else if (status == 'rejected') {
        _info =
            rejectionReason != null && rejectionReason.isNotEmpty
                ? 'تم رفض الطلب: $rejectionReason'
                : 'تم رفض طلب التفعيل.';
      } else if (status == 'completed') {
        _info = 'تم تفعيل البرنامج على هذا الجهاز.';
      }
    });

    if (status == 'completed') {
      _statusTimer?.cancel();
      setState(() {
        _info = 'تم تفعيل البرنامج على هذا الجهاز.';
      });
      return;
    }

    if (status == 'rejected') {
      _statusTimer?.cancel();
      setState(() {
        _requestId = null;
      });
      return;
    }

    _startStatusPolling();
  }

  Future<void> _activate() async {
    final code = _codeController.text.trim();

    if (_requestId == null) {
      setState(() {
        _error = 'أرسل طلب تفعيل أولًا قبل التفعيل';
      });
      return;
    }

    if (_requestStatus != 'approved') {
      setState(() {
        _error = 'لا يمكن تفعيل البرنامج قبل الموافقة على الطلب';
      });
      return;
    }

    if (code.isEmpty) {
      setState(() {
        _error = 'الرجاء إدخال كود التفعيل';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });

    final result = await _activationService.activateWithRequest(
      activationCode: code,
      requestId: _requestId,
    );

    if (!mounted) return;

    setState(() {
      _loading = false;
    });

    if (result['success'] == true) {
      setState(() {
        _requestStatus = 'completed';
        _info = result['message']?.toString() ?? 'تم التفعيل بنجاح';
      });
      _goToLogin();
      return;
    }

    setState(() {
      _error = result['message']?.toString() ?? 'فشلت عملية التفعيل';
    });
  }

  Future<void> _goToLogin() async {
    await Future.delayed(const Duration(milliseconds: 800));

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  String _statusText() {
    switch (_requestStatus) {
      case 'pending':
        return 'بانتظار موافقة الإدارة';
      case 'approved':
        return 'تمت الموافقة، الآن أدخل الكود';
      case 'rejected':
        return 'تم رفض الطلب';
      case 'completed':
        return 'تم التفعيل';
      default:
        return 'لم يتم إرسال طلب بعد';
    }
  }

  Color _statusColor() {
    switch (_requestStatus) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'completed':
        return Colors.teal;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final canEnterCode = _requestStatus == 'approved';
    final canSendRequest =
        !_sendingRequest &&
        _requestStatus != 'pending' &&
        _requestStatus != 'approved';

    return Scaffold(
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: const WhatsAppSupportButton(
        heroTag: 'activation_whatsapp_support',
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 104),
          child: SizedBox(
            width: 480,
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'تفعيل برنامج المتميز',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'اضغط على إرسال طلب تفعيل، وبعد موافقة الإدارة أدخل الكود ثم اضغط على تفعيل.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black54, height: 1.5),
                    ),
                    const SizedBox(height: 20),

                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: _statusColor().withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _statusColor().withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: _statusColor()),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _statusText(),
                              style: TextStyle(
                                color: _statusColor(),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 46,
                      child: ElevatedButton.icon(
                        onPressed: canSendRequest ? _sendRequest : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                          foregroundColor: Colors.white,
                        ),
                        icon:
                            _sendingRequest
                                ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                                : const Icon(Icons.send_rounded),
                        label: Text(
                          _requestId == null
                              ? 'إرسال طلب تفعيل'
                              : 'تم إرسال الطلب',
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed:
                          (_requestId == null || _checkingStatus)
                              ? null
                              : () => _refreshRequestStatus(),
                      icon:
                          _checkingStatus
                              ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : const Icon(Icons.refresh),
                      label: const Text('تحديث حالة الطلب'),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _codeController,
                      enabled: canEnterCode && !_loading,
                      decoration: InputDecoration(
                        labelText: 'كود التفعيل',
                        hintText:
                            canEnterCode
                                ? 'أدخل الكود الذي وصلك من الإدارة'
                                : 'حقل الكود يتفعل بعد الموافقة',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    if (_info != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          _info!,
                          style: const TextStyle(color: Colors.green),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _activate,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        child:
                            _loading
                                ? const CircularProgressIndicator(
                                  color: Colors.white,
                                )
                                : const Text('تفعيل'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

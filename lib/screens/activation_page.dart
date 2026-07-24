import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:motamayez/screens/auth/login.dart';
import 'package:motamayez/services/activation_service.dart';
import 'package:motamayez/widgets/whatsapp_support_button.dart';

class ActivationPage extends StatefulWidget {
  const ActivationPage({
    super.key,
    this.initialMessage,
    this.renewalMode = false,
  });

  final String? initialMessage;
  final bool renewalMode;

  @override
  State<ActivationPage> createState() => _ActivationPageState();
}

class _ActivationPageState extends State<ActivationPage> {
  final TextEditingController _codeController = TextEditingController();
  final ActivationService _activationService = ActivationService();

  bool _loading = false;
  bool _sendingRequest = false;
  bool _checkingStatus = false;
  bool _checkingServerActivation = false;
  bool _isAssignedCodeLocked = false;
  String? _error;
  String? _info;
  String? _requestId;
  String _requestStatus = 'idle';
  Timer? _statusTimer;

  bool get _hasActivationCode => _codeController.text.trim().isNotEmpty;

  bool get _isRequestReadyForActivation =>
      _requestStatus == 'approved' ||
      (_requestStatus == 'completed' && _hasActivationCode);

  bool get _canAttemptActivation =>
      _isRequestReadyForActivation || _hasActivationCode;

  bool _isInactiveRequestStatus(String? status) {
    final normalized = status?.trim().toLowerCase();
    return normalized == 'rejected' ||
        normalized == 'deactivated' ||
        normalized == 'revoked' ||
        normalized == 'expired' ||
        normalized == 'device_changed' ||
        normalized == 'not_activated';
  }

  @override
  void initState() {
    super.initState();
    _codeController.addListener(_handleCodeChanged);
    _initializeActivationState();
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _codeController.removeListener(_handleCodeChanged);
    _codeController.dispose();
    super.dispose();
  }

  void _handleCodeChanged() {
    if (!mounted) return;
    setState(() {});
  }

  String _normalizeText(String text) {
    if (!(text.contains('Ø') ||
        text.contains('Ù') ||
        text.contains('Ã') ||
        text.contains('Â'))) {
      return text;
    }

    try {
      return utf8.decode(latin1.encode(text));
    } catch (_) {
      return text;
    }
  }

  String _messageOrDefault(dynamic value, String fallback) {
    final raw = value?.toString().trim();
    if (raw == null || raw.isEmpty) {
      return fallback;
    }
    return _normalizeText(raw);
  }

  Future<void> _initializeActivationState() async {
    // نسح كل البيانات المحفوظة أولاً لـ fresh start
    final savedRequest = await _activationService.getSavedPendingRequest();
    final savedAssignedCode = savedRequest?['assignedCode']?.toString();

    if (!mounted) return;

    setState(() {
      _requestId = savedRequest?['requestId']?.toString();
      _requestStatus = savedRequest?['status']?.toString() ?? 'idle';
      // دائماً نسح الكود والـ locked status عند الفتح
      _codeController.clear();
      _isAssignedCodeLocked = false;
      if (savedAssignedCode != null && savedAssignedCode.isNotEmpty) {
        _applyAssignedCode(savedAssignedCode);
      }
      _error = null;
      _info = widget.initialMessage;
    });

    final activatedFromServer = await _checkServerActivationOnOpen();
    if (activatedFromServer) {
      return;
    }

    if (_requestId != null) {
      await _refreshRequestStatus(showLoader: false);
      _startStatusPolling();
    }
  }

  Future<bool> _checkServerActivationOnOpen() async {
    if (!mounted) return false;

    setState(() {
      _checkingServerActivation = true;
      _error = null;
      _info = widget.initialMessage ?? 'جاري فحص تفعيل الجهاز من السيرفر...';
    });

    final result = await _activationService.checkDeviceActivationOnServer();

    if (!mounted) return false;

    setState(() {
      _checkingServerActivation = false;
    });

    if (result['success'] == true && result['activated'] == true) {
      setState(() {
        _requestStatus = 'completed';
        _info = _messageOrDefault(
          result['message'],
          'تم تفعيل هذا الجهاز من السيرفر.',
        );
      });
      await _goToLogin();
      return true;
    }

    final requestId = result['requestId']?.toString();
    final assignedCode = result['assignedCode']?.toString();
    if (requestId != null && requestId.isNotEmpty) {
      setState(() {
        _requestId = requestId;
        _requestStatus = result['status']?.toString() ?? _requestStatus;
        _applyAssignedCode(assignedCode);
        _info = _messageOrDefault(
          result['message'],
          'تم العثور على تفعيل جاهز لهذا الجهاز.',
        );
      });

      if (_hasActivationCode) {
        await _activate();
        return true;
      }
      return false;
    }

    final status = result['status']?.toString();
    if (result['success'] == false &&
        status != 'offline' &&
        status != 'endpoint_not_found') {
      setState(() {
        _info = widget.initialMessage;
      });
    } else if (_info == 'جاري فحص تفعيل الجهاز من السيرفر...') {
      setState(() {
        _info = widget.initialMessage;
      });
    }

    return false;
  }

  void _startStatusPolling() {
    _statusTimer?.cancel();

    if (_requestId == null ||
        _requestStatus == 'completed' ||
        _isInactiveRequestStatus(_requestStatus)) {
      return;
    }

    _statusTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _refreshRequestStatus(showLoader: false);
    });
  }

  void _applyAssignedCode(String? assignedCode) {
    if (assignedCode == null || assignedCode.isEmpty) return;

    _codeController.text = assignedCode;
    _isAssignedCodeLocked = true;
  }

  Future<void> _sendRequest() async {
    setState(() {
      _sendingRequest = true;
      _error = null;
      _info = widget.initialMessage;
      _codeController.clear();
      _isAssignedCodeLocked = false;
    });

    final result = await _activationService.createActivationRequest();

    if (!mounted) return;

    setState(() {
      _sendingRequest = false;
    });

    if (result['success'] != true) {
      setState(() {
        _error = _messageOrDefault(
          result['message'],
          widget.renewalMode
              ? 'فشل إرسال طلب التجديد'
              : 'فشل إرسال طلب التفعيل',
        );
      });
      return;
    }

    final status = result['status']?.toString() ?? 'pending';
    final assignedCode = result['assignedCode']?.toString();

    setState(() {
      _requestId = result['requestId']?.toString() ?? _requestId;
      _requestStatus = status;
      _info = _messageOrDefault(
        result['message'],
        widget.renewalMode
            ? 'تم إرسال طلب التجديد بنجاح'
            : 'تم إرسال طلب التفعيل بنجاح',
      );
      _applyAssignedCode(assignedCode);
    });

    if (status == 'already_activated') {
      setState(() {
        _info = 'تم التفعيل من قبل';
      });
      return;
    }

    _startStatusPolling();
  }

  Future<void> _refreshRequestStatus({
    bool showLoader = true,
    bool applyAssignedCode = true,
  }) async {
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
        _error = _messageOrDefault(
          result['message'],
          'تعذر التحقق من حالة الطلب',
        );
      });
      return;
    }

    final status = result['status']?.toString() ?? 'pending';
    final assignedCode = result['assignedCode']?.toString();
    final rejectionReason = result['rejectionReason']?.toString();

    setState(() {
      _requestStatus = status;

      if (applyAssignedCode) {
        _applyAssignedCode(assignedCode);
      } else if (_codeController.text.trim().isEmpty) {
        _codeController.clear();
        _isAssignedCodeLocked = false;
      }

      if (status == 'approved') {
        _info = 'تمت الموافقة على الطلب. يمكنك الآن متابعة التفعيل.';
      } else if (status == 'pending') {
        _info = 'طلب التفعيل ما زال بانتظار الموافقة.';
      } else if (status == 'rejected') {
        _info =
            rejectionReason != null && rejectionReason.isNotEmpty
                ? 'تم رفض الطلب: ${_normalizeText(rejectionReason)}'
                : 'تم رفض طلب التفعيل.';
      } else if (status == 'completed') {
        _info =
            assignedCode != null && assignedCode.isNotEmpty
                ? 'تم استلام كود التفعيل. اضغط تفعيل لإكمال العملية.'
                : 'تمت الموافقة على الطلب. حدّث حالة الطلب لاستلام الكود.';
      }
    });

    if (status == 'completed') {
      _statusTimer?.cancel();
      if (_hasActivationCode) {
        await _activate();
      }
      return;
    }

    if (_isInactiveRequestStatus(status)) {
      _statusTimer?.cancel();
      setState(() {
        _requestId = null;
        _codeController.clear();
        _isAssignedCodeLocked = false;
      });
      return;
    }

    _startStatusPolling();
  }

  Future<void> _activate() async {
    final code = _codeController.text.trim();

    if (_requestId == null) {
      setState(() {
        _error =
            widget.renewalMode
                ? 'أرسل طلب تجديد أولًا قبل التفعيل'
                : 'أرسل طلب تفعيل أولًا قبل التفعيل';
      });
      return;
    }

    if (!_isRequestReadyForActivation && code.isEmpty) {
      setState(() {
        _error = 'لا يمكن التفعيل قبل الموافقة أو بدون كود تفعيل';
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
        _info = _messageOrDefault(result['message'], 'تم التفعيل بنجاح');
      });
      _goToLogin();
      return;
    }

    setState(() {
      _error = _messageOrDefault(result['message'], 'فشلت عملية التفعيل');
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
    if (_checkingServerActivation) {
      return 'جاري فحص التفعيل من السيرفر';
    }

    if (_requestStatus == 'completed') {
      return _hasActivationCode
          ? 'Activation code received, ready to activate'
          : 'Request approved, waiting for code';
    }

    switch (_requestStatus) {
      case 'pending':
        return 'بانتظار موافقة الإدارة';
      case 'approved':
        return 'تمت الموافقة، الكود جاهز للتفعيل';
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
    final canEnterCode =
        _requestStatus == 'approved' ||
        _requestStatus == 'completed' ||
        _hasActivationCode;
    final canSendRequest =
        !_sendingRequest &&
        !_checkingServerActivation &&
        _requestStatus != 'pending' &&
        _requestStatus != 'approved' &&
        _requestStatus != 'completed';

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
                    Text(
                      widget.renewalMode
                          ? 'تجديد اشتراك برنامج المتميز'
                          : 'تفعيل برنامج المتميز',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.renewalMode
                          ? 'أرسل طلب تجديد، وبعد موافقة الإدارة يمكنك إدخال الكود الجديد ثم الضغط على تفعيل.'
                          : 'أرسل طلب تفعيل، وبعد موافقة الإدارة يمكنك إدخال الكود ثم الضغط على تفعيل.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.black54,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),
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
                          _checkingServerActivation
                              ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: _statusColor(),
                                ),
                              )
                              : Icon(Icons.info_outline, color: _statusColor()),
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
                              ? widget.renewalMode
                                  ? 'إرسال طلب تجديد'
                                  : 'إرسال طلب تفعيل'
                              : 'تم إرسال الطلب',
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed:
                          (_requestId == null ||
                                  _checkingStatus ||
                                  _checkingServerActivation)
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
                      readOnly: _isAssignedCodeLocked,
                      obscureText: _isAssignedCodeLocked,
                      decoration: InputDecoration(
                        labelText: 'كود التفعيل',
                        hintText:
                            _isAssignedCodeLocked
                                ? 'تم استلام الكود وهو مخفي ومحمي من التعديل'
                                : canEnterCode
                                ? 'أدخل الكود الذي وصلك من الإدارة'
                                : 'أرسل الطلب أولًا ثم انتظر الموافقة',
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
                        onPressed:
                            (_loading ||
                                    _checkingServerActivation ||
                                    !_canAttemptActivation)
                                ? null
                                : _activate,
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

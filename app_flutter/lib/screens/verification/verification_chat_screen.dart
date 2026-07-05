import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../../api/api.dart';
import '../../session/user_session.dart';

class VerificationChatScreen extends StatefulWidget {
  final String reportId;
  final String reportName;
  final bool isAdmin;
  final String initialVerificationStatus;

  const VerificationChatScreen({
    super.key,
    required this.reportId,
    required this.reportName,
    required this.isAdmin,
    this.initialVerificationStatus = 'pending',
  });

  @override
  State<VerificationChatScreen> createState() => _VerificationChatScreenState();
}

class _VerificationChatScreenState extends State<VerificationChatScreen> {
  static const Color _primaryBlue = Color(0xFF2F89B8);

  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _picker = ImagePicker();

  bool _isLoading = true;
  bool _isSending = false;
  bool _isActionLoading = false;
  String? _error;
  String _verificationStatus = 'pending';
  List<Map<String, dynamic>> _messages = [];

  @override
  void initState() {
    super.initState();
    _verificationStatus = widget.initialVerificationStatus;
    _loadMessages();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Map<String, String> _buildHeaders() {
    final headers = <String, String>{'Content-Type': 'application/json'};
    final user = UserSession.current.value;
    final token = user?.token;
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    final userId = user?.id;
    if (userId != null && userId.isNotEmpty) {
      headers['X-User-Id'] = userId;
    }
    final email = user?.email ?? '';
    if (email.isNotEmpty) {
      headers['X-User-Email'] = email;
    }
    final role = user?.role ?? '';
    if (role.isNotEmpty) {
      headers['X-User-Role'] = role;
    }
    return headers;
  }

  Future<void> _loadMessages() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await http
          .get(
            Uri.parse(verificationMessagesUrl(widget.reportId)),
            headers: _buildHeaders(),
          )
          .timeout(const Duration(seconds: 12));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final status = decoded is Map ? decoded['verificationStatus'] : null;
        final data = decoded is Map ? decoded['data'] : null;
        setState(() {
          _verificationStatus = _safeString(status, _verificationStatus);
          _messages = _parseList(data);
          _isLoading = false;
        });
        _scrollToBottom();
      } else {
        final decoded = jsonDecode(response.body);
        setState(() {
          _error = decoded is Map
              ? _safeString(decoded['error'], 'Failed to load messages')
              : 'Failed to load messages';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Connection error: $e';
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _parseList(dynamic data) {
    if (data is List) {
      return data
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    return [];
  }

  String _safeString(dynamic value, [String fallback = '']) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return fallback;
    return text;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _sendMessage({String? imageDataUrl}) async {
    final text = _messageController.text.trim();
    if (text.isEmpty && imageDataUrl == null) return;

    setState(() => _isSending = true);

    try {
      final payload = <String, dynamic>{};
      if (text.isNotEmpty) payload['text'] = text;
      if (imageDataUrl != null) payload['image'] = imageDataUrl;

      final response = await http
          .post(
            Uri.parse(verificationMessagesUrl(widget.reportId)),
            headers: _buildHeaders(),
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 20));

      if (!mounted) return;

      if (response.statusCode == 201) {
        _messageController.clear();
        await _loadMessages();
      } else {
        final decoded = jsonDecode(response.body);
        _showSnack(
          decoded is Map
              ? _safeString(decoded['error'], 'Failed to send message')
              : 'Failed to send message',
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showSnack('Failed to send message: $e');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _pickAndSendImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    final photoBase64 = base64Encode(bytes);
    final photoDataUrl = 'data:image/jpeg;base64,$photoBase64';
    await _sendMessage(imageDataUrl: photoDataUrl);
  }

  Future<void> _requestEvidence() async {
    setState(() => _isActionLoading = true);
    try {
      final response = await http
          .post(
            Uri.parse(verificationRequestEvidenceUrl(widget.reportId)),
            headers: _buildHeaders(),
            body: jsonEncode({}),
          )
          .timeout(const Duration(seconds: 12));

      if (!mounted) return;

      if (response.statusCode == 201) {
        await _loadMessages();
        _showSnack('Evidence request sent');
      } else {
        final decoded = jsonDecode(response.body);
        _showSnack(
          decoded is Map
              ? _safeString(decoded['error'], 'Failed to request evidence')
              : 'Failed to request evidence',
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showSnack('Failed to request evidence: $e');
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _verifyReport() async {
    final note = await _showTextDialog(
      title: 'Verify Report',
      hint: 'Optional note for the reporter',
      confirmLabel: 'Verify',
    );
    if (note == null) return;

    setState(() => _isActionLoading = true);
    try {
      final response = await http
          .post(
            Uri.parse(verificationVerifyUrl(widget.reportId)),
            headers: _buildHeaders(),
            body: jsonEncode({'note': note}),
          )
          .timeout(const Duration(seconds: 12));

      if (!mounted) return;

      if (response.statusCode == 200) {
        await _loadMessages();
        _showSnack('Report verified');
      } else {
        final decoded = jsonDecode(response.body);
        _showSnack(
          decoded is Map
              ? _safeString(decoded['error'], 'Failed to verify report')
              : 'Failed to verify report',
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showSnack('Failed to verify report: $e');
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _rejectReport() async {
    final reason = await _showTextDialog(
      title: 'Reject Report',
      hint: 'Reason for rejection (required)',
      confirmLabel: 'Reject',
      required: true,
    );
    if (reason == null || reason.trim().isEmpty) return;

    setState(() => _isActionLoading = true);
    try {
      final response = await http
          .post(
            Uri.parse(verificationRejectUrl(widget.reportId)),
            headers: _buildHeaders(),
            body: jsonEncode({'reason': reason.trim()}),
          )
          .timeout(const Duration(seconds: 12));

      if (!mounted) return;

      if (response.statusCode == 200) {
        await _loadMessages();
        _showSnack('Report rejected');
      } else {
        final decoded = jsonDecode(response.body);
        _showSnack(
          decoded is Map
              ? _safeString(decoded['error'], 'Failed to reject report')
              : 'Failed to reject report',
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showSnack('Failed to reject report: $e');
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<String?> _showTextDialog({
    required String title,
    required String hint,
    required String confirmLabel,
    bool required = false,
  }) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: hint,
              border: const OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final value = controller.text.trim();
                if (required && value.isEmpty) return;
                Navigator.of(context).pop(value);
              },
              style: ElevatedButton.styleFrom(backgroundColor: _primaryBlue),
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );
    controller.dispose();
    return result;
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'verified':
        return Colors.green.shade700;
      case 'rejected':
        return Colors.red.shade700;
      case 'under_review':
        return Colors.blue.shade700;
      default:
        return Colors.orange.shade700;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'verified':
        return 'Verified';
      case 'rejected':
        return 'Rejected';
      case 'under_review':
        return 'Under Review';
      default:
        return 'Pending';
    }
  }

  bool get _canSendMessages {
    if (widget.isAdmin) return true;
    return _verificationStatus != 'verified';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.isAdmin ? 'Verification Chat' : 'Chat with Admin',
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              widget.reportName,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _statusColor(_verificationStatus).withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _statusLabel(_verificationStatus).toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: _statusColor(_verificationStatus),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (widget.isAdmin) _buildAdminActions(),
          Expanded(child: _buildMessageList()),
          if (_canSendMessages) _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildAdminActions() {
    final isVerified = _verificationStatus == 'verified';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      color: Colors.white,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: _isActionLoading ? null : _requestEvidence,
            icon: const Icon(Icons.upload_file_outlined, size: 18),
            label: const Text('Request Evidence'),
          ),
          ElevatedButton.icon(
            onPressed: _isActionLoading || isVerified ? null : _verifyReport,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.verified_outlined, size: 18),
            label: const Text('Verify'),
          ),
          OutlinedButton.icon(
            onPressed: _isActionLoading ? null : _rejectReport,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red.shade700,
            ),
            icon: const Icon(Icons.close, size: 18),
            label: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: Colors.red.shade400, size: 36),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _loadMessages,
                style: ElevatedButton.styleFrom(backgroundColor: _primaryBlue),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            widget.isAdmin
                ? 'No messages yet. Request evidence or start the conversation.'
                : 'No messages yet. Send photos or documents to verify your report.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadMessages,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        itemCount: _messages.length,
        itemBuilder: (context, index) {
          return _MessageBubble(message: _messages[index]);
        },
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        12,
        10,
        12,
        10 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: _isSending ? null : _pickAndSendImage,
            icon: const Icon(Icons.image_outlined, color: _primaryBlue),
            tooltip: 'Send image',
          ),
          Expanded(
            child: TextField(
              controller: _messageController,
              minLines: 1,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _isSending ? null : () => _sendMessage(),
            icon: _isSending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_rounded, color: _primaryBlue),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final Map<String, dynamic> message;

  const _MessageBubble({required this.message});

  String _safeString(dynamic value, [String fallback = '']) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return fallback;
    return text;
  }

  @override
  Widget build(BuildContext context) {
    final type = _safeString(message['type']);
    final senderRole = _safeString(message['senderRole']);
    final text = _safeString(message['text']);
    final imageUrl = _safeString(message['imageUrl']);
    final senderName = _safeString(message['senderName'], 'User');

    if (type == 'system' || senderRole == 'system') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.blueGrey.shade50,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade700),
            ),
          ),
        ),
      );
    }

    final isAdmin = senderRole == 'admin';
    final bubbleColor = isAdmin ? const Color(0xFF2F89B8) : Colors.white;
    final textColor = isAdmin ? Colors.white : Colors.black87;

    return Align(
      alignment: isAdmin ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isAdmin ? 4 : 16),
            bottomRight: Radius.circular(isAdmin ? 16 : 4),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              senderName,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: isAdmin ? Colors.white70 : Colors.grey.shade600,
              ),
            ),
            if (text.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(text, style: TextStyle(color: textColor, fontSize: 14)),
            ],
            if (imageUrl.isNotEmpty) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return SizedBox(
                      height: 120,
                      child: Center(
                        child: CircularProgressIndicator(
                          value: progress.expectedTotalBytes != null
                              ? progress.cumulativeBytesLoaded /
                                    progress.expectedTotalBytes!
                              : null,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (_, __, ___) => Container(
                    height: 80,
                    color: Colors.grey.shade200,
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

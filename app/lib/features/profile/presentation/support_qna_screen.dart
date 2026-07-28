import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupportQnaScreen extends StatefulWidget {
  const SupportQnaScreen({super.key});

  @override
  State<SupportQnaScreen> createState() => _SupportQnaScreenState();
}

class _SupportQnaScreenState extends State<SupportQnaScreen> with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  late TabController _tabController;
  bool _isLoading = true;
  List<Map<String, dynamic>> _messages = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadMessages();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final response = await _supabase
          .from('support_messages')
          .select('*')
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _messages = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }

      // Mark unread messages as read
      final hasUnread = _messages.any((m) => m['is_read'] == false);
      if (hasUnread) {
        await _supabase
            .from('support_messages')
            .update({'is_read': true})
            .eq('user_id', user.id)
            .eq('is_read', false);
      }
    } catch (e) {
      debugPrint('Error loading support messages: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _submitMessage(String type, String content, {String? imageUrl}) async {
    final user = _supabase.auth.currentUser;
    if (user == null || content.trim().isEmpty) return;

    try {
      await _supabase.from('support_messages').insert({
        'user_id': user.id,
        'message_type': type,
        'content': content.trim(),
        if (imageUrl != null) 'image_url': imageUrl,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              type == 'question'
                  ? 'Votre question a été envoyée au support !'
                  : 'Merci pour votre suggestion !',
            ),
            backgroundColor: const Color(0xFF22C55E),
          ),
        );
      }
      _loadMessages();
    } catch (e) {
      debugPrint('Error inserting support message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur technique lors de l\'envoi de votre message.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showNewMessageDialog() {
    final textController = TextEditingController();
    String selectedType = 'question';
    XFile? selectedImage;
    bool isUploading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                24.w,
                24.h,
                24.w,
                MediaQuery.of(context).viewInsets.bottom + 24.h,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Nouveau Message',
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      )
                    ],
                  ),
                  SizedBox(height: 16.h),
                  
                  // Toggle Type Selection
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setModalState(() => selectedType = 'question'),
                          child: Container(
                            padding: EdgeInsets.symmetric(vertical: 12.h),
                            decoration: BoxDecoration(
                              color: selectedType == 'question'
                                  ? const Color(0xFF0284C7).withOpacity(0.1)
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12.r),
                              border: Border.all(
                                color: selectedType == 'question'
                                    ? const Color(0xFF0284C7)
                                    : Colors.transparent,
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              children: [
                                Text('❓', style: TextStyle(fontSize: 20.sp)),
                                SizedBox(height: 4.h),
                                Text(
                                  'Poser une question',
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.bold,
                                    color: selectedType == 'question'
                                        ? const Color(0xFF0284C7)
                                        : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setModalState(() => selectedType = 'suggestion'),
                          child: Container(
                            padding: EdgeInsets.symmetric(vertical: 12.h),
                            decoration: BoxDecoration(
                              color: selectedType == 'suggestion'
                                  ? const Color(0xFF16A34A).withOpacity(0.1)
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12.r),
                              border: Border.all(
                                color: selectedType == 'suggestion'
                                    ? const Color(0xFF16A34A)
                                    : Colors.transparent,
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              children: [
                                Text('💡', style: TextStyle(fontSize: 20.sp)),
                                SizedBox(height: 4.h),
                                Text(
                                  'Faire une suggestion',
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.bold,
                                    color: selectedType == 'suggestion'
                                        ? const Color(0xFF16A34A)
                                        : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20.h),
                  
                  // Message Textarea
                  Text(
                    'Votre Message',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF334155),
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16.r),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: TextField(
                      controller: textController,
                      maxLines: 5,
                      style: TextStyle(fontSize: 14.sp, color: const Color(0xFF0F172A)),
                      decoration: InputDecoration(
                        hintText: selectedType == 'question'
                            ? 'Posez votre question en détail...'
                            : 'Proposez une idée ou une amélioration pour l\'application...',
                        hintStyle: TextStyle(
                          color: const Color(0xFF94A3B8),
                          fontSize: 13.sp,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(16.w),
                      ),
                    ),
                  ),
                  SizedBox(height: 16.h),
                  // Image Selection
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Capture d\'écran (Optionnel)',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF334155),
                        ),
                      ),
                      if (selectedImage == null)
                        TextButton.icon(
                          onPressed: () async {
                            try {
                              final picker = ImagePicker();
                              final XFile? pickedFile = await picker.pickImage(
                                source: ImageSource.gallery,
                                maxWidth: 1200,
                                maxHeight: 1200,
                                imageQuality: 85,
                              );
                              if (pickedFile != null) {
                                setModalState(() {
                                  selectedImage = pickedFile;
                                });
                              }
                            } catch (e) {
                              debugPrint('Error picking image: $e');
                            }
                          },
                          icon: const Icon(Icons.add_photo_alternate, color: Color(0xFFF97316), size: 20),
                          label: Text(
                            'Ajouter',
                            style: TextStyle(
                              color: const Color(0xFFF97316),
                              fontWeight: FontWeight.bold,
                              fontSize: 13.sp,
                            ),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  if (selectedImage != null)
                    Container(
                      height: 100.h,
                      width: 100.w,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(11.r),
                            child: Image.file(
                              File(selectedImage!.path),
                              width: 100.w,
                              height: 100.h,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: -8,
                            right: -8,
                            child: GestureDetector(
                              onTap: () {
                                setModalState(() {
                                  selectedImage = null;
                                });
                              },
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                padding: const EdgeInsets.all(4),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 14,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  SizedBox(height: 24.h),
                  
                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 50.h,
                    child: ElevatedButton(
                      onPressed: isUploading
                          ? null
                          : () async {
                              final text = textController.text.trim();
                              if (text.isEmpty) return;

                              setModalState(() {
                                isUploading = true;
                              });

                              String? uploadedImageUrl;
                              if (selectedImage != null) {
                                try {
                                  final user = _supabase.auth.currentUser;
                                  if (user != null) {
                                    final bytes = await selectedImage!.readAsBytes();
                                    final ext = selectedImage!.name.split('.').last;
                                    final fileName = '${user.id}_${DateTime.now().millisecondsSinceEpoch}.$ext';
                                    final filePath = 'support/$fileName';

                                    await _supabase.storage.from('cv_files').uploadBinary(
                                      filePath,
                                      bytes,
                                      fileOptions: const FileOptions(
                                        contentType: 'image/jpeg',
                                        upsert: true,
                                      ),
                                    );

                                    uploadedImageUrl = _supabase.storage.from('cv_files').getPublicUrl(filePath);
                                  }
                                } catch (e) {
                                  debugPrint('Error uploading support image: $e');
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Erreur lors de l\'envoi de l\'image : $e'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              }

                              await _submitMessage(selectedType, text, imageUrl: uploadedImageUrl);
                              
                              if (context.mounted) {
                                Navigator.pop(context);
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF97316),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14.r),
                        ),
                      ),
                      child: isUploading
                          ? const Center(
                              child: SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : Text(
                              'Envoyer le message',
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _formatDate(String isoString) {
    try {
      final date = DateTime.parse(isoString).toLocal();
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} à ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final questions = _messages.where((m) => m['message_type'] == 'question').toList();
    final suggestions = _messages.where((m) => m['message_type'] == 'suggestion').toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Suggestions & Questions',
          style: TextStyle(
            color: const Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
            fontSize: 18.sp,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFFF97316),
          unselectedLabelColor: const Color(0xFF64748B),
          indicatorColor: const Color(0xFFF97316),
          labelStyle: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold),
          unselectedLabelStyle: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.normal),
          tabs: [
            Tab(text: 'Questions (${questions.length})'),
            Tab(text: 'Suggestions (${suggestions.length})'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showNewMessageDialog,
        backgroundColor: const Color(0xFFF97316),
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          'Créer',
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFF97316)),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildMessageList(questions, 'question'),
                _buildMessageList(suggestions, 'suggestion'),
              ],
            ),
    );
  }

  Widget _buildMessageList(List<Map<String, dynamic>> items, String type) {
    if (items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadMessages,
        color: const Color(0xFFF97316),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    type == 'question' ? '❓' : '💡',
                    style: TextStyle(fontSize: 48.sp),
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    type == 'question'
                        ? 'Vous n\'avez posé aucune question.'
                        : 'Vous n\'avez fait aucune suggestion.',
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF475569),
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    type == 'question'
                        ? 'Cliquez sur Créer pour interpeller l\'équipe.'
                        : 'Partagez vos idées pour rendre l\'application meilleure !',
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadMessages,
      color: const Color(0xFFF97316),
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 80.h),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          final hasReply = item['admin_reply'] != null;

          return Container(
            margin: EdgeInsets.only(bottom: 16.h),
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(
                color: hasReply
                    ? const Color(0xFFE2E8F0)
                    : const Color(0xFFF97316).withOpacity(0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // User Message Date
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Mon message',
                      style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                    Text(
                      _formatDate(item['created_at']),
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
                // User Message Content
                Text(
                  item['content'] ?? '',
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: const Color(0xFF1E293B),
                    height: 1.4,
                  ),
                ),
                if (item['image_url'] != null && (item['image_url'] as String).isNotEmpty) ...[
                  SizedBox(height: 12.h),
                  GestureDetector(
                    onTap: () => _showFullScreenImage(context, item['image_url']),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12.r),
                      child: Image.network(
                        item['image_url'],
                        height: 180.h,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            height: 180.h,
                            color: const Color(0xFFF1F5F9),
                            child: const Center(
                              child: CircularProgressIndicator(color: Color(0xFFF97316)),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 60.h,
                            color: const Color(0xFFF1F5F9),
                            child: const Center(
                              child: Icon(Icons.broken_image, color: Colors.grey),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
                
                // Admin Reply Section
                if (hasReply) ...[
                  SizedBox(height: 16.h),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(color: const Color(0xFFFFEDD5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Réponse de l\'équipe',
                                  style: TextStyle(
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFFEA580C),
                                  ),
                                ),
                              ],
                            ),
                            if (item['replied_at'] != null)
                              Text(
                                _formatDate(item['replied_at']),
                                style: TextStyle(
                                  fontSize: 10.sp,
                                  color: const Color(0xFFC2410C).withOpacity(0.7),
                                ),
                              ),
                          ],
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          item['admin_reply'] ?? '',
                          style: TextStyle(
                            fontSize: 13.sp,
                            color: const Color(0xFF7C2D12),
                            height: 1.4,
                          ),
                        ),
                        if (item['admin_image_url'] != null && (item['admin_image_url'] as String).isNotEmpty) ...[
                          SizedBox(height: 10.h),
                          GestureDetector(
                            onTap: () => _showFullScreenImage(context, item['admin_image_url']),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10.r),
                              child: Image.network(
                                item['admin_image_url'],
                                height: 150.h,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Container(
                                    height: 150.h,
                                    color: const Color(0xFFFFEDD5),
                                    child: const Center(
                                      child: CircularProgressIndicator(color: Color(0xFFEA580C)),
                                    ),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    height: 50.h,
                                    color: const Color(0xFFFFEDD5),
                                    child: const Center(
                                      child: Icon(Icons.broken_image, color: Colors.grey),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ] else ...[
                  SizedBox(height: 12.h),
                  Row(
                    children: [
                      Container(
                        width: 6.r,
                        height: 6.r,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFF97316),
                        ),
                      ),
                      SizedBox(width: 6.w),
                      Text(
                        'En attente de réponse',
                        style: TextStyle(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFF97316),
                        ),
                      ),
                    ],
                  ),
                ]
              ],
            ),
          );
        },
      ),
    );
  }

  void _showFullScreenImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 20.h),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  );
                },
              ),
            ),
            Positioned(
              top: 10.h,
              right: 10.w,
              child: CircleAvatar(
                backgroundColor: Colors.black.withOpacity(0.5),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
